module DataIngestion

using ..DBAccess
using ..DataRetrieval
using ..FSAccess
using ..Model
using Chain
using DataFrames
using DataFramesMeta
using Dates
using LightXML
using LoggingExtras
using StringBuilders
using TOML

export execute_datapipeline


const RETENTION_LIMIT = parse(Int,ENV["retention_limit"])


"""
    execute_datapipeline()
    
Run the data pipeline from raw to prepared layer.
"""
function execute_datapipeline()
    ingest_date = today()
    local logger
    local loglevel
    if !isinteractive()
        mkpath("../logs/datapipeline")
        io = open("../logs/datapipeline/$ingest_date.log", "w+")
        dateformat = DateFormat("yyyy-mm-dd -- HH:MM:SS")
        logger = FormatLogger(io) do io, args
            println(io, args.level, " -- ", Dates.format(now(), dateformat), ": ", args.message, "  (", args._module, ":", args.line, ")")
        end
        try
            config = TOML.parsefile("../config/stockoverview.toml")
            if config["datapipeline"]["loglevel"] == "DEBUG"
                loglevel = Logging.Debug
            else
                loglevel = Logging.Info                
            end
        catch e
            @warn "failed to read config"
            loglevel = Logging.Debug
        end
        logger = MinLevelLogger(logger, loglevel)
    else
        logger = current_logger()
    end
    
    with_logger(logger) do
        start = now()
        local time_elapsed
        @info "execute data pipeline for ingest date: $ingest_date -- $start"
        try
            download_raw_data(ingest_date)
            extract_raw_data(ingest_date)
            transform_company_data(ingest_date)
            transform_isin_mapping(ingest_date)
            remove_raw_data(ingest_date)
            prepare_security_data(ingest_date)
            # update company data: countries, normalize names,...
            securities, companies = filter_and_join(ingest_date)
            write_to_db(securities, companies)
            cleanup(RETENTION_LIMIT)
            ## in spereate function
            # update security and company data in DB based on timestamps
            # score security priority (marketcap, data quality, trading volume)
        catch e
            showerror(stderr, e)
            time_elapsed = canonicalize(now() - start)
            @error "pipeline execution aborted after: $time_elapsed -- $(now())"

            return nothing
        end
        
        time_elapsed = canonicalize(now() - start)
        @info "pipeline execution completed in: $time_elapsed -- $(now())"
    end
end


"""
    download_raw_data()
    
Download and store raw company and ISIN data from data providers to raw layer.
    
Already existing files will be overwritten.
"""
function download_raw_data(ingest_date::Date)
    @info "download raw data"

    # download raw files
    LEI_zip = download_company_data(ingest_date)
    if isnothing(LEI_zip) || !isfile(LEI_zip)
        @error "invlid LEI zip file: $LEI_zip"
        throw(ErrorException("LEI download failed"))
    end
    ISIN_mapping_zip = download_isin_mapping(ingest_date)
    if isnothing(ISIN_mapping_zip) || !isfile(ISIN_mapping_zip)
        @error "invlid ISIN mapping zip file: $ISIN_mapping_zip"
        throw(ErrorException("ISIN mapping download failed"))
    end

    # copy temporary files to raw layer
    if isfile(LEI_zip) && isfile(ISIN_mapping_zip)
        @info "move files to raw data layer for further processing"
    else
        @error "file validation failed"
        throw(ErrorException("file download failed"))
    end
    tmp_to_raw(LEI_zip, "company_data.zip", ingest_date)
    tmp_to_raw(ISIN_mapping_zip, "ISIN_mapping.zip", ingest_date)
end


"""
    xml2tuple(xml::String)::NamedTuple
"""
function xml2tuple(xml::String)::NamedTuple
    doc = parse_string(xml)
    lei = find_element(root(doc), "LEI") |> content
    entity = find_element(root(doc), "Entity")
    name_element = find_element(entity, "LegalName")
    name = name_element === nothing ? "" : content(name_element)
    legal_address = find_element(entity, "LegalAddress")
    address = ""
    first_address_line = find_element(legal_address, "FirstAddressLine")
    additional_address_line = find_element(legal_address, "AdditionalAddressLine")
    if additional_address_line === nothing
        address = first_address_line === nothing ? "" : content(first_address_line)
    else
        address = content(first_address_line) * "\n" * content(additional_address_line)        
    end
    city_element = find_element(legal_address, "City")
    city = city_element === nothing ? "" : content(city_element)
    country_element = find_element(legal_address, "Country")
    country = ""
    if country_element !== nothing
        country = content(country_element)   
    end
    postal_code_element = find_element(legal_address, "PostalCode")
    postal_code = postal_code_element === nothing ? "" : content(postal_code_element)
    free(doc)

    return (lei=lei, name=name, address=address, city=city, postal_code=postal_code, country=country)
end


"""
    transform_company_data(ingest_date::Date)

Transform raw company data to relational representation and store as Parquet file in source layer.
"""
function transform_company_data(ingest_date::Date)
    @info "transform company data"
    open_tag = "<lei:LEIRecord xmlns:lei=\"http://www.gleif.org/data/schema/leidata/2016\">"
    close_tag = "</lei:LEIRecord>"
    element = false
    sb = nothing
    record_counter = 0
    df = DataFrame()
    filename = getfirstfile("xml", raw, ingest_date)

    open(getfile(filename, raw, ingest_date)) do io
        while !eof(io)
            line = readline(io; keep=true)
            stripped = strip(line)
            if stripped == open_tag && !element
                element = true
                sb = StringBuilder()
                append!(sb, "<lei:LEIRecord xmlns:lei=\"http://www.gleif.org/data/schema/leidata/2016\">\n")
            elseif stripped == close_tag && element
                append!(sb, line)
                element = false
                lei_record = String(sb)
                push!(df, xml2tuple(lei_record))                
                record_counter += 1
            elseif stripped != open_tag && stripped != close_tag && element
                append!(sb, line)
            end
        end
    end
    @info string(record_counter) * " records processed"

    write_parquet(df, "company_data.parquet", source, ingest_date)
 end


"""
    transform_isin_mapping(ingest_date::Date)

Transform ISIN mapping to Parquet format and store in source layer.
"""
function transform_isin_mapping(ingest_date::Date)
    @info "transform ISIN mapping"
    filename = getfirstfile("csv", raw, ingest_date)
    df = read_csv(filename, raw, ingest_date)
    write_parquet(df, "isin_mapping.parquet", source, ingest_date)
end


"""
    prepare_security_data(ingest_date::Date)

Fetch and store security data in prepared layer. Incrementally, based on the latest
available data.
"""
function prepare_security_data(ingest_date::Date)
    @info "prepare security data"
    BATCH_SIZE = 50_000   # maximum number of new security records to be processed per pipeline execution

    isins = (read_parquet("isin_mapping.parquet", source, ingest_date)).ISIN
    latest_ingest_date = getlastingestdate(prepared)
    securities = read_parquet("security_data.parquet", prepared, latest_ingest_date)
    setdiff!(isins, securities.isin)
    @info "$(length(isins)) new securities identified"

    if length(isins) > BATCH_SIZE
        @info "number of new securities exceeds batch size, therefore only first $BATCH_SIZE securities will be processed in current pipeline run"
        isins = isins[1:BATCH_SIZE]
    end

    foreach(isins) do isin
        securityheader = fetch_securityheader(isin)
        push!(securities, (securityheader.isin, securityheader.wkn, securityheader.name, securityheader.type))
        if(securityheader.type !== missing && securityheader.type == "Share")
            @info "$(securityheader.isin): $(securityheader.name)"
        end
        sleep(0.3)
    end

    write_parquet(securities, "security_data.parquet", prepared, ingest_date)
end


"""
    filter_and_join(ingest_date::Date)

Filter and join security and company data. Returns a Tuple of DataFrames, securities and companies.
Results are not persisted.
"""
function filter_and_join(ingest_date::Date)
    @info "filter and join security and company data"
    securities = read_parquet("security_data.parquet", prepared, ingest_date)
    securities = securities[securities.type .=== "Share",:]
    isin_mapping = read_parquet("isin_mapping.parquet", source, ingest_date)
    
    securities = @chain securities begin
        leftjoin(isin_mapping, on = :isin => :ISIN)
        rename(:LEI => :lei)
    end

    isin_mapping = nothing
    
    companies = read_parquet("company_data.parquet", source, ingest_date)
    companies = @chain companies begin
        rightjoin(securities, on = :lei; matchmissing = :notequal, makeunique=true)
        @select(:lei, :name, :address, :city, :postal_code, :country)
        dropmissing(:lei)
    end

    return securities, companies
end


"""
    write_to_db

Writecompany and security data to DB.
"""
function write_to_db(securities::DataFrame, companies::DataFrame)
    @info "write $(nrow(securities)) securities and $(nrow(companies)) companies to DB"
    company_entities = map(x -> Company(x.lei, x.name, x.address, x.city, x.postal_code, x.country), eachrow(companies))
    security_entities = map(x -> Security(x.isin, x.wkn, x.lei, x.name, x.type), eachrow(securities))

    company_records = insert_update_company(company_entities)
    security_records = insert_update_security(security_entities)

    @info "$company_records of $(nrow(companies)) company records updated / inserted"
    @info "$security_records of $(nrow(securities)) security records updated / inserted"
end

end # module