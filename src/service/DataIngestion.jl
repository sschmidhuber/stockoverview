module DataIngestion

using ..DataRetrieval
using ..DBAccess
using ..Model
using ..FSAccess
using DataFrames
using Dates
using Downloads
using HTTP
using JSON
using LightXML
using LoggingExtras
using ThreadsX
using Query
using StringBuilders

export execute_datapipeline

const RETENTION_LIMIT = 5


"""
    execute_datapipeline()
    
Run the data pipeline from raw to prepared layer.
"""
function execute_datapipeline()
    ingest_date = today()
    local logger
    if !isinteractive()
        mkpath("../logs/datapipeline")
        io = open("../logs/datapipeline/$ingest_date.log", "w+")
        logger = FormatLogger(io) do io, args
            println(io, args.level, ": ", args.message, "  (", args._module, ":", args.line, ")")
        end
        logger = MinLevelLogger(logger, Logging.Info)
    else
        logger = current_logger()
    end
    
    with_logger(logger) do
        start = now()
        @info "execute data pipeline for ingest date: $ingest_date -- $start"
        #download_raw_data(ingest_date)
        #extract_raw_data(ingest_date)
        transform_company_data(ingest_date)
        transform_isin_mapping(ingest_date)
        remove_raw_data(ingest_date)
        prepare_security_data(ingest_date)
        securities, companies = filter_and_join(ingest_date)
        write_to_db(securities, companies)
        cleanup(RETENTION_LIMIT)        

        ## in spereate function
        # update security and company data in DB based on timestamps
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
    data_date = Dates.format(ingest_date - Day(1), DateFormat("yyyymmdd"))
    lei_url = "https://leidata.gleif.org/api/v1/concatenated-files/lei2/$data_date/zip"

    # retrieve ISIN-LEI mapping URL
    isin_mapping_url = nothing
    try
        res = HTTP.request("GET", "https://isinmapping.gleif.org/api/v2/isin-lei")
        source = JSON.parse(res.body |> String, null=missing)
        isin_mapping_url = source["data"][1]["attributes"]["downloadLink"]
    catch e
        showerror(stderr, e)
        println("failed to retrieve \"isin_mapping_url\"")
        exit(1)
    end

    # download raw files
    LEI_zip = nothing
    try
        LEI_zip = Downloads.download(lei_url)
    catch e
        showerror(stderr, e)
        println("failed to download LEI file")
        exit(1)
    end

    ISIN_mapping_zip = nothing
    try
        ISIN_mapping_zip = Downloads.download(isin_mapping_url)
    catch e
        showerror(stderr, e)
        println("failed to download ISIN mapping file")
        exit(1)
    end

    # copy temporary files to raw layer
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
                #if record_counter % 100_000 == 0 && record_counter > 0
                #    @info string(record_counter) * " records processed"
                #end
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
    isin_mapping = read_parquet("isin_mapping.parquet", source, ingest_date)
    latest_ingest_date = getlastingestdate(prepared)
    securities = read_parquet("security_data.parquet", prepared, latest_ingest_date)
    new_securities = setdiff(isin_mapping.ISIN, securities.isin)
    @info "$(length(new_securities)) new securities identified"

    batchsize = 1_000
    counter = 0
    progress = 0
    foreach(first(new_securities, batchsize)) do isin
        securityheader = fetch_securityheader(isin)
        push!(securities, (securityheader.isin, securityheader.wkn, securityheader.name, securityheader.type))
        if(securityheader.type !== missing && securityheader.type == "Share")
            @info "$(securityheader.isin): $(securityheader.name)"
        end
        sleep(0.3)
        counter += 1
        newprogress = round(Int, counter/batchsize*100)
        if newprogress > progress
            @info "fetching security information completed to $newprogress %"
            progress = newprogress
        end
    end


    #=foreach(new_securities) do isin
        security = fetch_security(isin)
        push!(securities, security)
        sleep(0.3)
    end=#

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
    isin_mapping = read_parquet("isin_mapping.parquet", source, ingest_date)
    companies = read_parquet("company_data.parquet", source, ingest_date)
    
    securities = securities |>
        @filter(_.type == "Share") |>
        @join(isin_mapping, _.isin, _.ISIN, {_.isin, _.wkn, _.name, _.type, __.LEI}) |>
        @rename(:LEI => :lei) |>
        DataFrame
    
    predicate = ThreadsX.map(lei -> lei ∈ securities.lei, companies.lei)
    companies = companies[predicate,:]

    return securities, companies
end


"""
    write_to_db

Writecompany and security data to DB.
"""
function write_to_db(securities::DataFrame, companies::DataFrame)
    @info "write $(nrow(securities)) securities and $(nrow(companies)) companies to DB"
    company_entities = ThreadsX.map(eachrow(companies)) do r
        Company(r.lei, r.name, r.address, r.city, r.postal_code, r.country)
    end

    security_entities = ThreadsX.map(eachrow(securities)) do r
        Security(r.isin, r.wkn, r.lei, r.name, r.type)
    end

    company_records = insert_update_company(company_entities)
    security_records = insert_update_security(security_entities)

    @info "$company_records of $(nrow(companies)) company records successfully inserted/updated"
    @info "$security_records of $(nrow(securities)) security records successfully inserted/updated"
end


"""
    cleanup

Remove logs, files and directories, above than retention limit. The retention limit represents the number of
past pipeline runs.
"""
function cleanup(retention_limit)
    @info "cleanup old logs, files and directories"
    logs = readdir("../logs/datapipeline") |> @orderby_descending(_) |> @drop(retention_limit)
    if length(logs) > 0
        for logfile in logs
            rm("../logs/datapipeline/$logfile")
        end
    end

    source = readdir("../data/source") |> @orderby_descending(_) |> @drop(retention_limit)
    if length(source) > 0
        for dir in source
            rm("../data/source/$dir", recursive=true)
        end
    end

    prepared = readdir("../data/prepared") |> @orderby_descending(_) |> @drop(retention_limit)
    if length(prepared) > 0
        for dir in prepared
            rm("../data/prepared/$dir", recursive=true)
        end
    end
end

end # module