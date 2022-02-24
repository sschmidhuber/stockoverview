#! /usr/bin/env -S julia --threads=auto

#=
    initialize DB with master data
=#

using CSV
using DataFrames
using StringBuilders
using LightXML
using Dates
using Downloads
using HTTP
using JSON
using Query

include("service/Model.jl")
using .Model

include("service/DataIngestion.jl")
using .DataIngestion

include("persistence/DataAccess.jl")
using .DataAccess


function download_source_data()
    @info "download source data"
    working_date = Dates.format(today() - Dates.Day(1), DateFormat("yyyymmdd"))
    lei_url = "https://leidata.gleif.org/api/v1/concatenated-files/lei2/$working_date/zip"

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

    # download source files
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
    
    return LEI_zip, ISIN_mapping_zip
end


function extract_source_data(LEI_zip, ISIN_mapping_zip)
    @info "extract source data"
    LEI_xml, ISIN_mapping_csv = nothing, nothing

    extract_lei = `unzip -o -qq $LEI_zip`
    run(extract_lei)
    extract_isin = `unzip -o -qq $ISIN_mapping_zip`
    run(extract_isin)

    try
        LEI_xml = readdir() |> @filter(x -> contains(x, r".+-gleif-concatenated-file-lei2.xml")) |> first
        ISIN_mapping_csv = readdir() |> @filter(x -> contains(x, r"ISIN_LEI_.+.csv")) |> first
    catch e
        showerror(stderr, e)
        println("failed to extract source files")
        exit(1)
    end


    return LEI_xml, ISIN_mapping_csv    
end


# retrieve security information
function retrieve_security_information(ISIN_mapping_csv)
    @info "check ISINs for available information"
    securities = DataAccess.get_securities()
    checked_isins = securities.isin
    df = CSV.read(ISIN_mapping_csv, DataFrame)
    isins = setdiff(df.ISIN, checked_isins)

    @info "$(length(checked_isins)) ISINs already checked, $(length(isins)) to be processed"    

    foreach(isins) do isin
        security = DataIngestion.fetchsecurityheader(String(isin))
        DataAccess.insert_security(security)

        sleep(0.3)
    end
end


# clean up temporary files
function cleanup(LEI_zip, ISIN_mapping_zip, LEI_xml, ISIN_mapping_csv)
    @info "remove temporary files"
    rm(LEI_zip)
    rm(ISIN_mapping_zip)
    rm(LEI_xml)
    rm(ISIN_mapping_csv)
end


# parse XML representation and return company struct
function init_xml2company()
    @info "load country code mapping file"
    df = CSV.read("../data/country_codes.csv", DataFrame)

    function xml2company(xml::String)::Company
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
            code = content(country_element)
            if code in df.Code
                country = df[df.Code .== code,:Name] |> only
            else
                country = code
            end            
        end
        postal_code_element = find_element(legal_address, "PostalCode")
        postal_code = postal_code_element === nothing ? "" : content(postal_code_element)

        location = Location(address, city, country, postal_code)
        free(doc)
        return Company(lei, name, location)
    end

    return xml2company
end


# return true if a given LEI is found in ISIN mapping file
function init_has_isin(ISIN_mapping_csv::String)
    @info "load ISIN mapping file"
    df = CSV.read(ISIN_mapping_csv, DataFrame)
    leis = deepcopy(df.LEI)
    unique!(leis)
    df = nothing

    function has_isin(company::Company)
        company.lei in leis
    end

    return has_isin
end


function init_process_record(ISIN_mapping_csv::String)
    companies = Vector{Company}()
    has_isin = init_has_isin(ISIN_mapping_csv)
    xml2company = init_xml2company()
    lk = ReentrantLock()
    company_counter = 0

    function process_record(input::String) 
        company = xml2company(input)

        if has_isin(company)
            lock(lk) do 
                push!(companies, company)

                #=
                if length(companies) == 1000
                    DataAccess.insert_update_company(companies)
                    company_counter += 1000
                    @info string(company_counter) * " companies stored to DB"
                    empty!(companies)
                end          
                =#
            end
        end
    end

    function flush()
        @info "write " * string(length(companies)) * " records to DB"
        DataAccess.insert_company(companies)
        #company_counter += length(companies)
        #@info string(company_counter) * " companies stored to DB"
    end

    return process_record, flush
end


function read_source_file(LEI_xml::String, ISIN_mapping_csv::String)
    @info "read source file"
    open_tag = "<lei:LEIRecord>"
    close_tag = "</lei:LEIRecord>"
    element = false
    sb = nothing
    record_counter = 0
    process_record, flush = init_process_record(ISIN_mapping_csv)

    open(LEI_xml) do io
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
                Threads.@spawn process_record(lei_record)
                
                record_counter += 1
                if record_counter % 10_000 == 0 && record_counter > 0
                    @info string(record_counter) * " records processed"
                end
            elseif stripped != open_tag && stripped != close_tag && element
                append!(sb, line)
            end
        end
    end
    
    @info string(record_counter) * " records processed"
    flush()
end


function main()
    working_directory = pwd()
    cd(@__DIR__)

    # LEI_zip, ISIN_mapping_zip = download_source_data()
    #LEI_xml, ISIN_mapping_csv = "20220121-gleif-concatenated-file-lei2.xml", "ISIN_LEI_20220122.csv" #extract_source_data(LEI_zip, ISIN_mapping_zip)
    #read_source_file(LEI_xml, ISIN_mapping_csv)    
    #cleanup(LEI_zip, ISIN_mapping_zip, LEI_xml, ISIN_mapping_csv)

    retrieve_security_information("ISIN_LEI_20220122.csv")

    cd(working_directory)
    @info "successfully completed"
end

main()