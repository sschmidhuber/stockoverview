module DataRetrieval

using HTTP
using JSON
using LightXML
using DataFrames
using Dates

using ..Models

export fetchexchangerates, fetchsecurityheader

#=
options for retrieving data

    Euronext
    https://live.euronext.com/en/instrumentSearch/searchJSON?q=BE0974338700

    Yahoo Finance
    https://query2.finance.yahoo.com/v1/finance/search?q=BE0974338700

    inesting.com
    https://www.investing.com/equities/titan-cement-international-sa
    
=#


# TODO: fetch index data


# fetch currency exchange rates
function fetchexchangerates()
    rates = Dict{String,Float64}()
    res = HTTP.request("GET","https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml")
    doc = res.body |> String |> LightXML.parse_string
    cube = find_element(root(doc), "Cube") |> child_elements |> first
    date = parse(Date, attribute(cube, "time"; required=true))
    foreach(child_elements(cube)) do currency
        push!(rates, attribute(currency, "currency"; required=true) => parse(Float64, attribute(currency, "rate"; required=true)))
    end
    free(doc)

    return EuroExchangeRates(date, rates)
end


function fetchsecurityheader(isin::String)
    security = nothing
    try
        res = HTTP.request("GET", "https://component-api.wertpapiere.ing.de/api/v1/components/instrumentheader/$isin")
        source = JSON.parse(res.body |> String, null=missing)
        security = Security(isin, source["wkn"], source["name"], source["instrumentType"]["mainType"])
    catch
        @info "failed to retrieve security information for \"$isin\""
        security = Security(isin)
    end

    
    return security
end


end # module