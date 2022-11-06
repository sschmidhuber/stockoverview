module DataRetrieval

using ..Model
using DataFrames
using Dates
using HTTP
using JSON
using LightXML

export fetchexchangerates, fetchsecurity

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

"""
    fetchsecurity(isin::String)::Security

Fetch security master data of a security identified by its ISIN. A valid security type will be
returned, even if no data can't be found.
"""
function fetchsecurity(isin::String)::Security
    symbol, wkn, name, type, outstanding = nothing, nothing, nothing, nothing, nothing
    try
        res = HTTP.get("https://component-api.wertpapiere.ing.de/api/v1/components/instrumentheader/$isin")
        source = JSON.parse(res.body |> String, null=missing)
        wkn, name, type = source["wkn"], source["name"], source["instrumentType"]["mainType"]
    catch
        @debug "failed to retrieve security information for \"$isin\" from ING (https://component-api.wertpapiere.ing.de/api/v1/components/instrumentheader/$isin)"
        return Security(isin)
    end

    try
        res = HTTP.get("https://query2.finance.yahoo.com/v1/finance/search?q=$isin")
        source = JSON.parse(res.body |> String, null=missing)
        symbol = source["quotes"][1]["symbol"]
    catch
        @debug "failed to retrieve security information for \"$isin\" from yahoo (https://query2.finance.yahoo.com/v1/finance/search?q=$isin)"
        return Security(isin, wkn, name, type)
    end

    try
        res = HTTP.get("https://query2.finance.yahoo.com/v7/finance/quote?symbols=$symbol&fields=messageBoardId,longName,shortName,marketCap,underlyingSymbol,underlyingExchangeSymbol,headSymbolAsString,regularMarketPrice,regularMarketChange,regularMarketChangePercent,regularMarketVolume")
        source = JSON.parse(res.body |> String, null=missing)
        outstanding = source["quoteResponse"]["result"][1]["sharesOutstanding"]
    catch
        @debug "failed to retrieve security information for \"$symbol\" from yahoo (https://query2.finance.yahoo.com/v7/finance/quote?symbols=$symbol&fields=messageBoardId,longName,shortName,marketCap,underlyingSymbol,underlyingExchangeSymbol,headSymbolAsString,regularMarketPrice,regularMarketChange,regularMarketChangePercent,regularMarketVolume)"
        return Security(isin, wkn, name, type)
    end


    return Security(isin, symbol, wkn, missing, name, type, missing, outstanding)
end


end # module