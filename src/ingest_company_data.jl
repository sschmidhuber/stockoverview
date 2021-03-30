#! /usr/bin/env -S julia --threads=auto

#=
    initialize DB with master data
=#

using CSV
using DataFrames
using StringBuilders
using LightXML

include("service/Model.jl")
using .Model

include("persistance/DataAccess.jl")
using .DataAccess


# TODO: download source files, extract, cleanup

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


function init_has_isin()
    @info "load ISIN mapping file"
    df = CSV.read("../data/ISIN_LEI_20210314.csv", DataFrame)
    leis = deepcopy(df.LEI)
    unique!(leis)
    df = nothing

    function has_isin(company::Company)
        company.lei in leis
    end

    return has_isin
end


function init_process_record()
    companies = Vector{Company}()
    has_isin = init_has_isin()
    xml2company = init_xml2company()
    lk = ReentrantLock()
    company_counter = 0

    function process_record(input::String) 
        company = xml2company(input)

        if has_isin(company)
            lock(lk) do 
                push!(companies, company)

                if length(companies) == 5000
                    DataAccess.load_companies(companies)
                    company_counter += 5000
                    @info string(company_counter) * " companies stored to DB"
                    empty!(companies)
                end                
            end
        end
    end

    function flush()
        DataAccess.insert_companies(companies)
        company_counter += length(companies)
        @info string(company_counter) * " companies stored to DB"
    end

    return process_record, flush
end


function read_source_file(file::String, open_tag::String, close_tag::String)
    @info "read source file"
    element = false
    sb = nothing
    record_counter = 0
    process_record, flush = init_process_record()

    open(file) do io
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
    SOURCE_FILE = "../data/20210314-gleif-concatenated-file-lei2.xml"
    OPEN_TAG = "<lei:LEIRecord>"
    CLOSE_TAG = "</lei:LEIRecord>"

    read_source_file(SOURCE_FILE, OPEN_TAG, CLOSE_TAG)
    @info "successfully completed"
end

main()