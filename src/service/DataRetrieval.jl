module DataRetrieval

using ..Model
using DataFrames
using Dates
using HTTP
using JSON
using LightXML

export fetch_exchangerates, fetch_security, fetch_securityheader

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
function fetch_exchangerates()
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
function fetch_security(isin::String)::Security
    symbol, wkn, name, type, outstanding = nothing, nothing, nothing, nothing, nothing
    
    securityheader = fetch_securityheader(isin)
    wkn, name, type = securityheader.wkn, securityheader.name, securityheader.type

    try
        res = HTTP.get("https://query2.finance.yahoo.com/v1/finance/search?q=$isin"; connect_timeout=3, readtimeout=3)
        source = JSON.parse(res.body |> String, null=missing)
        symbol = source["quotes"][1]["symbol"]
    catch
        @debug "failed to retrieve security information for \"$isin\" from yahoo (https://query2.finance.yahoo.com/v1/finance/search?q=$isin)"
        return Security(isin, wkn, name, type)
    end

    try
        res = HTTP.get("https://query2.finance.yahoo.com/v7/finance/quote?symbols=$symbol&fields=messageBoardId,longName,shortName,marketCap,underlyingSymbol,underlyingExchangeSymbol,headSymbolAsString,regularMarketPrice,regularMarketChange,regularMarketChangePercent,regularMarketVolume"; connect_timeout=3, readtimeout=3)
        source = JSON.parse(res.body |> String, null=missing)
        outstanding = source["quoteResponse"]["result"][1]["sharesOutstanding"]
    catch
        @debug "failed to retrieve security information for \"$symbol\" from yahoo (https://query2.finance.yahoo.com/v7/finance/quote?symbols=$symbol&fields=messageBoardId,longName,shortName,marketCap,underlyingSymbol,underlyingExchangeSymbol,headSymbolAsString,regularMarketPrice,regularMarketChange,regularMarketChangePercent,regularMarketVolume)"
        return Security(isin, wkn, name, type)
    end


    return Security(isin, symbol, wkn, missing, name, type, missing, outstanding)
end


"""
    fetchsecurityheader(isin::String)::NamedTuple

Returns security isin, wkn, name and type of a given ISIN as NamedTuple. If data can't be retrieved
Missing values are returned.
"""
function fetch_securityheader(isin::String)::NamedTuple
    wkn, name, type = nothing, nothing, nothing
    try
        res = HTTP.get("https://component-api.wertpapiere.ing.de/api/v1/components/instrumentheader/$isin"; connect_timeout=3, readtimeout=3)
        source = JSON.parse(res.body |> String, null=missing)
        wkn, name, type = source["wkn"], source["name"], source["instrumentType"]["mainType"]
    catch
        @debug "failed to retrieve security information for \"$isin\" from ING (https://component-api.wertpapiere.ing.de/api/v1/components/instrumentheader/$isin)"
        return (isin=isin, wkn=missing, name=missing, type=missing)
    end

    return (isin=isin, wkn=wkn, name=name, type=type)
end


end # module