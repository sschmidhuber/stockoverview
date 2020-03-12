module SecurityData

using HTTP
using JSON
using DataFrames
using Logging
using Statistics


export Security, fetchsecurity

struct Security
    isin::String
    name::Union{String, Missing}
    industry::Union{String, Missing}
    sector::Union{String, Missing}
    subsector::Union{String, Missing}
    country::Union{String, Missing}
    last_price::Union{Float64, Missing}
    change_abs::Union{Float64, Missing}
    last_closing_price::Union{Float64, Missing}
    currency::Union{String, Missing}
    price_earnings_ratio::Union{Float64, Missing}
    dividend_return_ratio_last::Union{Float64, Missing}
    dividend_return_ratio_avg3::Union{Float64, Missing}
    dividend_return_ratio_avg5::Union{Float64, Missing}
    outstanding_shares::Union{Int, Missing}
    histkeydata::DataFrame
end


function fetchsecurity(isin::String, exchangerates::Dict{String,Float64}; language::String = "en")::Security
    last_price = change_abs = last_closing_price = outstanding_shares = missing
    name = industry = sector = subsector = country = currency = ""
    histkeydata = DataFrame()

    @sync begin
        @async last_price, change_abs, last_closing_price, currency = fetchprice(isin)
        @async name = fetchname(isin)
        @async industry, sector, subsector, country = fetchmasterdata(isin, language)
        @async histkeydata = fetchkeydata(isin, exchangerates)
        @async outstanding_shares = fetchequitydata(isin)
    end

    price_earnings_ratio, dividend_return_ratio_last, dividend_return_ratio_avg3, dividend_return_ratio_avg5 = calculatevalues(last_price, outstanding_shares, histkeydata)

    return Security(isin, name, industry, sector, subsector, country, last_price, change_abs, last_closing_price, currency, price_earnings_ratio, dividend_return_ratio_last, dividend_return_ratio_avg3, dividend_return_ratio_avg5, outstanding_shares, histkeydata)
end

function fetchname(isin::String)::Union{String,Missing}
    news = Dict()

    try
        res = HTTP.request("GET", "https://api.boerse-frankfurt.de/data/instrument_news?isin=$isin&limit=0&newsType=ALL");
        news = JSON.parse(res.body |> String, null=missing)
    catch e
        return missing
    end
    name = try news["instrumentName"]["translations"]["others"] catch; try news["instrumentName"]["originalValue"] catch; missing end end

    return name
end

function fetchprice(isin::String)::Tuple
    pricedata = Dict()
    try
        res = HTTP.request("GET","https://component-api.wertpapiere.ing.de/api/v1/components/instrumentheader/$isin")
        pricedata = JSON.parse(res.body |> String, null=missing)

        return (
            pricedata["price"],
            pricedata["changeAbsolute"],
            pricedata["close"],
            pricedata["currency"],
        )
    catch e
        return (missing, missing, missing, missing)
    end
end

function fetchmasterdata(isin::String, language::String)::Tuple
    masterdata = nothing
    try
        res = HTTP.request("GET", "https://api.boerse-frankfurt.de/data/equity_master_data?isin=$isin")
        masterdata = JSON.parse(res.body |> String, null=missing)
    catch e
        return missing, missing, missing, missing
    end

    industry = try masterdata["industrySector"]["translations"][language] catch; missing end
    sector = try masterdata["sector"]["translations"][language] catch; try masterdata["sector"]["originalValue"] catch; missing end end
    subsector = try masterdata["subsector"]["translations"][language] catch; try masterdata["subsector"]["originalValue"] catch; missing end end
    country = try masterdata["originCountry"]["translations"][language] catch; try masterdata["originCountry"]["originalValue"] catch; missing end end

    return (industry, sector, subsector, country)
end

function fetchkeydata(isin::String, exchangerates::Dict{String,Float64}, years::Int = 6)::DataFrame
    try
        res = HTTP.request("GET", "https://api.boerse-frankfurt.de/data/historical_key_data?isin=$isin&limit=$years")
        payload = JSON.parse(res.body |> String, null=missing)
        data = payload["data"]

        # check latest dataset
        latest = data |> first
        if latest["priceEarningsRatio"] === missing || latest["salesRevenue"] === missing || latest["incomeAfterTax"] === missing || latest["incomeNet"] === missing
            popfirst!(data)
        end

        currency = (data |> first)["currencyCode"]
        exchangerate = currency == "EUR" ? 1 : exchangerates[currency]

        df = DataFrame()
        df.year = map(x -> x["year"], data)
        df.priceEarningsRatio = map(x -> x["priceEarningsRatio"], data)
        df.priceBookRatio = map(x -> x["priceBookRatio"], data)
        df.euqityRatio = map(x -> x["equityRatio"], data)
        df.dividendPerShare = map(x -> x["dividendPerShare"] / exchangerate, data)
        df.dividendReturnRatio = map(x -> x["dividendReturnRatio"], data)
        df.deptEquityRatio = map(x -> x["debtEquityRatio"], data)
        df.bookValuePerShare = map(x -> x["bookvaluePerShare"], data)
        df.currency = map(x -> x["currencyCode"], data)
        df.revenue = map(x -> x["salesRevenue"] / exchangerate, data)
        df.ebit = map(x -> x["incomeOperating"] / exchangerate, data)
        df.ebt = map(x -> x["incomeBeforeTax"] / exchangerate, data)
        df.incomeAfterTax = map(x -> x["incomeAfterTax"] / exchangerate, data)
        df.incomeNet = map(x -> x["incomeNet"] / exchangerate, data)
        df.employees = map(x -> x["employees"], data)
        df.expensesPerEmployee = map(x -> x["expensesPerEmployee"] / exchangerate, data)

        return df
    catch e
        return DataFrame()
    end
end


function fetchequitydata(isin::String)::Union{Int,Missing}
    equitydata = nothing
    try
        res = HTTP.request("GET", "https://api.boerse-frankfurt.de/data/equity_key_data?isin=$isin")
        equitydata = JSON.parse(res.body |> String, null=missing)
    catch e
        return missing
    end

    return equitydata["numberOfShares"]
end


function calculatevalues(price, outstanding_shares, histkeydata::DataFrame)
    # check for missing data
    if price === missing || outstanding_shares === missing || nrow(histkeydata) == 0
        return missing, missing, missing, missing
    end

    # if data for the latest year is still missing, remove latest row
    if histkeydata.dividendPerShare |> first === missing || histkeydata.incomeAfterTax |> first === missing
        histkeydata = histkeydata[2:end,:]
    end
    if nrow(histkeydata) == 0
        return missing, missing, missing, missing
    end

    price_earnings_ratio = missing

    income = histkeydata[1,:incomeAfterTax]
    if income !== missing
        win_per_share = income / outstanding_shares
        price_earnings_ratio = round(price / win_per_share, digits=2)
    end

    try
        dividend_last = histkeydata[1,:dividendPerShare]
        dividend_avg3 = histkeydata[1:3,:dividendPerShare] |> mean
        dividend_avg5 = histkeydata[1:5,:dividendPerShare] |> mean

        dividend_return_ratio_last = dividend_last === missing ? missing : round(dividend_last / price * 100, digits=2)
        dividend_return_ratio_avg3 = dividend_avg3 === missing ? missing : round(dividend_avg3 / price * 100, digits=2)
        dividend_return_ratio_avg5 = dividend_avg5 === missing ? missing : round(dividend_avg5 / price * 100, digits=2)

        return price_earnings_ratio, dividend_return_ratio_last, dividend_return_ratio_avg3, dividend_return_ratio_avg5
    catch e
        return price_earnings_ratio, missing, missing, missing
    end

end

end
