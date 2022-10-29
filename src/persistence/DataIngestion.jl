module DataIngestion

using ..DataRetrieval
using ..DBAccess
using ..Model
using CSV
using DataFrames
using Dates
using Downloads
using HTTP
using JSON
using LightXML
using LoggingExtras
using Parquet
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
        #transform_company_data(ingest_date)
        #transform_isin_mapping(ingest_date)
        #remove_raw_data(ingest_date)
        prepare_security_data(ingest_date)
        securities, companies = filter_and_join(ingest_date)

        # write security and company data to DB
        # houskeeping
            # remove raw data
            # keep 10 days of source and prepared data

        

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
    mkpath("../data/raw/$ingest_date")
    mv(LEI_zip, "../data/raw/$ingest_date/company_data.zip"; force=true)
    mv(ISIN_mapping_zip, "../data/raw/$ingest_date/ISIN_mapping.zip"; force=true)
end


"""
    extract_raw_data()

Extract zip files in raw layer.
"""
function extract_raw_data(ingest_date::Date)
    @info "extract raw data"
    directory = "../data/raw/$ingest_date"
    extract_lei = `unzip -o -qq $directory/company_data.zip -d $directory`
    run(extract_lei)
    extract_isin = `unzip -o -qq $directory/ISIN_mapping.zip -d $directory`
    run(extract_isin)
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
    getfirstfile(directory, extension)

Returns the filename of the first file in the given directory, with the specified file extension.

Extensions without dot and case sensitive, e.g. "csv".
"""
function getfirstfile(directory, extension)
    readdir(directory) |> @filter(endswith(_, extension)) |> first
end


"""
    transform_company_data(ingest_date::Date)

Transform raw company data to relational representation and store as Parquet file in source layer.
"""
function transform_company_data(ingest_date::Date)
    @info "transform company data"
    xmlfile = getfirstfile("../data/raw/$ingest_date", "xml")
    open_tag = "<lei:LEIRecord xmlns:lei=\"http://www.gleif.org/data/schema/leidata/2016\">"
    close_tag = "</lei:LEIRecord>"
    element = false
    sb = nothing
    record_counter = 0
    df = DataFrame()

    open("../data/raw/$ingest_date/$xmlfile") do io
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

    mkpath("../data/source/$ingest_date")
    write_parquet("../data/source/$ingest_date/company_data.parquet", df, compression_codec=:zstd)
end


"""
    transform_isin_mapping(ingest_date::Date)

Transform ISIN mapping to Parquet format and store in source layer.
"""
function transform_isin_mapping(ingest_date::Date)
    @info "transform ISIN mapping"
    rawdir = "../data/raw/$ingest_date"
    sourcedir = "../data/source/$ingest_date"
    mkpath(sourcedir)

    csvfile = getfirstfile(rawdir, "csv")
    df = CSV.read("$rawdir/$csvfile", DataFrame, stringtype=String)
    write_parquet("$sourcedir/isin_mapping.parquet", df, compression_codec=:zstd)
end

"""
    remove_raw_data(ingest_date::Date)

Remove raw data of given ingest date to reduce disk utilization.
"""
function remove_raw_data(ingest_date::Date)
    @info "remove raw data"
    rm("../data/raw/$ingest_date", recursive=true)
end


"""
    prepare_security_data(ingest_date::Date)

Fetch and store security data in prepared layer. Incrementally, based on the latest
available data.
"""
function prepare_security_data(ingest_date::Date)
    @info "prepare security data"
    isin_mapping = read_parquet("../data/source/$ingest_date/isin_mapping.parquet") |> DataFrame
    latest_ingest_date = readdir("../data/prepared") |> last
    securities = read_parquet("../data/prepared/$latest_ingest_date/security_data.parquet") |> DataFrame
    new_securities = setdiff(isin_mapping.ISIN, securities.isin)
    @info "$(length(new_securities)) new securities identified"

    #=foreach(new_securities) do isin
        security = fetchsecurityheader(isin)
        push!(securities, security)
    end=#

    mkpath("../data/prepared/$ingest_date")
    write_parquet("../data/prepared/$ingest_date/security_data.parquet", securities, compression_codec=:zstd)
end


"""
    filter_and_join(ingest_date::Date)

Filter and join security and company data. Returns a Tuple of DataFrames, securities and companies.
Results are not persisted.
"""
function filter_and_join(ingest_date::Date)
    securities = read_parquet("../data/prepared/$ingest_date/security_data.parquet") |> DataFrame
    isin_mapping = read_parquet("../data/source/$ingest_date/isin_mapping.parquet") |> DataFrame
    companies = read_parquet("../data/source/$ingest_date/company_data.parquet") |> DataFrame
    
    securities = securities |>
        @filter(_.type == "Share") |>
        @join(isin_mapping, _.isin, _.ISIN, {_.isin, _.wkn, _.name, _.type, __.LEI}) |>
        @rename(:LEI => :lei) |>
        DataFrame
    
    companies = companies |>
        @filter(_.lei ∈ securities.lei) |>
        DataFrame

    return securities, companies
end



end # module