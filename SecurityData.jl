module SecurityData

using HTTP
using JSON
using DataFrames
using Logging
using Statistics
using Dates
using Gumbo
using Cascadia
using Query


export Security, fetchsecurity

struct Security
    isin::String
    name::Union{String,Missing}
    industry::Union{String,Missing}
    sector::Union{String,Missing}
    subsector::Union{String,Missing}
    country::Union{String,Missing}
    last_price::Union{Float64,Missing}
    change_abs::Union{Float64,Missing}
    last_closing_price::Union{Float64,Missing}
    currency::Union{String,Missing}
    price_earnings_ratio::Union{Float64,Missing}
    price_book_ratio::Union{Float64,Missing}
    dividend_return_ratio_last::Union{Float64,Missing}
    dividend_return_ratio_avg3::Union{Float64,Missing}
    outstanding_shares::Union{Int64,Missing}
    pl_data::DataFrame
    balance_data::DataFrame
    fundamental_data::DataFrame
end

struct DataRetrievalError <: Exception
    isin::String
    msg::String
    url
end

struct DataTransformationError <: Exception
    msg::String
end

ISODate = DateFormat("yyyy-mm-ddTHH:MM:SS")

function fetchsecurity(isin::String, exchangerates::Dict)::Union{Security,Nothing}
    price_earnings_ratio = price_book_ratio = dividend_return_ratio_last = dividend_return_ratio_avg3 = outstanding_shares = missing
    header = Dict()
    facts = Dict()
    pl_data = DataFrame()
    balance_data = DataFrame()
    fundamental_data = DataFrame()

    try
        @sync begin
        @async header = fetchheader(isin)
        @async facts = fetchfacts(isin)
        @async outstanding_shares = fetchos(isin)
        @async pl_data = fetchpl(isin, exchangerates)
        @async balance_data = fetchbalance(isin, exchangerates)
        @async fundamental_data = fetchfundamental(isin, exchangerates)
        end

        price_earnings_ratio, price_book_ratio, dividend_return_ratio_last, dividend_return_ratio_avg3 = calculatevalues(header["price"], fundamental_data, balance_data, outstanding_shares)
    catch e
        @warn "processing of ISIN: $isin failed"
        showerror(stdout, e)
        return nothing
    end
    
    return Security(isin, header["name"], facts["industry"], missing, missing, facts["country"], header["price"], header["change_abs"], header["close"], header["currency"], price_earnings_ratio, price_book_ratio, dividend_return_ratio_last, dividend_return_ratio_avg3, outstanding_shares, pl_data, balance_data, fundamental_data)
end

# header data (name and price)
function fetchheader(isin)::Union{Dict,Nothing}
    source = Dict()

    try
        res = HTTP.request("GET", "https://component-api.wertpapiere.ing.de/api/v1/components/instrumentheader/$isin")
        source = JSON.parse(res.body |> String, null=missing)
    catch
        throw(DataRetrievalError(isin, "header data for \"$isin\" couldn't be retrieved", "https://component-api.wertpapiere.ing.de/api/v1/components/instrumentheader/$isin"))
    end

    header = Dict()
    header["name"] = haskey(source, "name") ? source["name"] : missing
    header["price"] = haskey(source, "price") ? source["price"] : missing
    header["change_abs"] = haskey(source, "changeAbsolute") ? source["changeAbsolute"] : missing
    header["close"] = haskey(source, "close") ? source["close"] : missing
    header["bid_time"] = haskey(source, "bidDate") ? DateTime(source["bidDate"][1:19], ISODate) : missing
    header["currency"] = haskey(source, "currency") ? source["currency"] : missing
    header["wkn"] = haskey(source, "wkn") ? source["wkn"] : missing

    return header
end

# company facts
function fetchfacts(isin)::Union{Dict,Nothing}
    source = Dict()

    try
        res = HTTP.request("GET", "https://component-api.wertpapiere.ing.de/api/v1/share/facts/$isin")
        source = JSON.parse(res.body |> String, null=missing)
    catch
        throw(DataRetrievalError(isin, "facts for \"$isin\" couldn't be retrieved", "https://component-api.wertpapiere.ing.de/api/v1/share/facts/$isin"))
    end

    facts = Dict()
    facts["company_link"] = haskey(source, "companyLink") ? source["companyLink"] : missing
    facts["industry"] = try source["data"][1]["value"] catch; missing end
    facts["country"] = try source["data"][2]["value"] catch; missing end
    facts["employees"] = try parse(Int, replace(source["data"][3]["value"], "." => "")) catch; missing end

    return facts
end

# number of outstanding shares
function fetchos(isin)::Int
    html = nothing
    outstanding_shares = 0

    try
        res = HTTP.request("GET", "https://www.onvista.de/aktien/$isin")
        html = parsehtml(res.body |> String)
    catch
    throw(DataRetrievalError(isin, "number of outstanding shares couldn't be retrieved", "https://www.onvista.de/aktien/$isin"))
    end

    try
        metrics_container = sel".kennzahlen-container"
        metrics_html = eachmatch(metrics_container, html.root) |> first

        market_table = sel".MARKT"
        market_html = eachmatch(market_table, metrics_html) |> first

        tabledata = sel"td"
        outstanding_shares = parse(Int, replace(replace(eachmatch(tabledata, market_html)[2].children[1].text, "." => ""), " Stk" => ""))
    catch
        throw(DataRetrievalError(isin, "error while parsing HTML response", "https://www.onvista.de/aktien/$isin"))
        end

    return outstanding_shares
end

# profit and loss
function fetchpl(isin::String, exchangerates::Dict)::DataFrame
    source = Dict()

    try
        res = HTTP.request("GET", "https://component-api.wertpapiere.ing.de/api/v1/share/incomestatement/$isin")
        source = JSON.parse(res.body |> String, null=missing)
    catch
        throw(DataRetrievalError(isin, "profit and loss data retrieval failed", "https://component-api.wertpapiere.ing.de/api/v1/share/incomestatement/$isin"))
    end

    df = DataFrame(year=[], revenue=[], result_of_operations=[], income_after_tax=[], currency=[])
    currency = haskey(source, "currencyIsoCode") ? source["currencyIsoCode"] : missing

        foreach(source["items"]) do item
        year = haskey(item, "year") ? parse(Int, item["year"]) : missing
        revenue = haskey(item, "turnover") ? item["turnover"] * 1_000_000 : missing
        result_of_operations = haskey(item, "resultOfOperations") ? item["resultOfOperations"] * 1_000_000 : missing
        income_after_tax = haskey(item, "incomeAfterTax") ? item["incomeAfterTax"] * 1_000_000 : missing
        
        push!(df, (year, revenue, result_of_operations, income_after_tax, currency))
    end

    # convert to EUR
    try
        df = df |> 
            @mutate(revenue = _.currency == "EUR" ? _.revenue : _.revenue / exchangerates[_.currency]) |>
            @mutate(result_of_operations = _.currency == "EUR" ? _.result_of_operations : _.result_of_operations / exchangerates[_.currency]) |>
            @mutate(income_after_tax = _.currency == "EUR" ? _.income_after_tax : _.income_after_tax / exchangerates[_.currency]) |>
            @mutate(currency = "EUR") |>
            DataFrame
    catch
        throw(DataTransformationError("currency conversion of balance data failed"))
    end
    
    return df
end


# balance
function fetchbalance(isin::String, exchangerates::Dict)::DataFrame
    source = Dict()

    try
        res = HTTP.request("GET", "https://component-api.wertpapiere.ing.de/api/v1/share/companybalancesheet/$isin")
        source = JSON.parse(res.body |> String, null=missing)
    catch
        throw(DataRetrievalError(isin, "balance data retrieval failed", "https://component-api.wertpapiere.ing.de/api/v1/share/companybalancesheet/$isin"))
    end

    df = DataFrame(year=[], current_assets=[], capital_assets=[], equity=[], equity_ratio=[], total_liabilities=[], liabilities_ratio=[], total_assets=[], currency=[])
    currency = haskey(source, "currencyIsoCode") ? source["currencyIsoCode"] : missing

        foreach(source["items"]) do item
        year = haskey(item, "year") ? parse(Int, item["year"]) : missing
        current_assets = haskey(item, "currentAssets") ? item["currentAssets"] * 1_000_000 : missing
        capital_assets = haskey(item, "capitalAssets") ? item["capitalAssets"] * 1_000_000 : missing
        equity = haskey(item, "equity") ? item["equity"] * 1_000_000 : missing
        equity_ratio = haskey(item, "equityRatio") ? item["equityRatio"] : missing
        total_liabilities = haskey(item, "totalLiabilities") ? item["totalLiabilities"] * 1_000_000 : missing
        liabilities_ratio = haskey(item, "liabilitiesRatio") ? item["liabilitiesRatio"] : missing
        total_assets = haskey(item, "totalAssets") ? item["totalAssets"] * 1_000_000 : missing
        
        push!(df, (year, current_assets, capital_assets, equity, equity_ratio, total_liabilities, liabilities_ratio, total_assets, currency))
    end

    # convert to EUR
    try
        df = df |> 
            @mutate(current_assets = _.currency == "EUR" ? _.current_assets : _.current_assets / exchangerates[_.currency]) |>
            @mutate(capital_assets = _.currency == "EUR" ? _.capital_assets : _.capital_assets / exchangerates[_.currency]) |>
            @mutate(equity = _.currency == "EUR" ? _.equity : _.equity / exchangerates[_.currency]) |>
            @mutate(total_liabilities = _.currency == "EUR" ? _.total_liabilities : _.total_liabilities / exchangerates[_.currency]) |>
            @mutate(total_assets = _.currency == "EUR" ? _.total_assets : _.total_assets / exchangerates[_.currency]) |>
            @mutate(currency = "EUR") |>
            DataFrame
    catch
        throw(DataTransformationError("currency conversion of balance data failed"))
    end
    
    return df
end


# fundamental data
    function fetchfundamental(isin::String, exchangerates::Dict)::DataFrame
    source = Dict()

    try
        res = HTTP.request("GET", "https://component-api.wertpapiere.ing.de/api/v1/share/fundamentalanalysis/$isin")
source = JSON.parse(res.body |> String, null=missing)
    catch
        throw(DataRetrievalError(isin, "fundamental data retrieval failed", "https://component-api.wertpapiere.ing.de/api/v1/share/fundamentalanalysis/$isin"))
    end

    df = DataFrame(year=[], dividend_per_share=[], dividend_yield=[], basic_earnings_per_share=[], currency=[], estimated=[])
    currency_historic = haskey(source, "historicCurrencyIsoCode") ? source["historicCurrencyIsoCode"] : missing
    currency_estimated = haskey(source, "estimatedCurrencyIsoCode") ? source["estimatedCurrencyIsoCode"] : missing

    try
        foreach(source["items"]) do item
            year = haskey(item, "year") ? item["year"] : missing
            estimated = haskey(item, "hasOnlyEstimatedItems") && item["hasOnlyEstimatedItems"] == true
            dividend_per_share = haskey(item["dividendPerShare"], "value") ? item["dividendPerShare"]["value"] : missing
            dividend_yield = haskey(item["dividendYield"], "value") ? item["dividendYield"]["value"] : missing
            basic_earnings_per_share = haskey(item["basicEarningsPerShare"], "value") ? item["basicEarningsPerShare"]["value"] : missing
            
            push!(df, (year, dividend_per_share, dividend_yield, basic_earnings_per_share, (estimated ? currency_estimated : currency_historic), estimated))
        end
    catch
        throw(DataRetrievalError(isin, "parsing fundemental response JSON failed", "https://component-api.wertpapiere.ing.de/api/v1/share/fundamentalanalysis/$isin"))
    end

    # convert to EUR
    try
        df = df |> 
            @mutate(dividend_per_share = _.currency == "EUR" ? _.dividend_per_share : _.dividend_per_share / exchangerates[_.currency]) |>
            @mutate(basic_earnings_per_share = _.currency == "EUR" ? _.basic_earnings_per_share : _.basic_earnings_per_share / exchangerates[_.currency]) |>
            @mutate(currency = "EUR") |>
            DataFrame
    catch
        throw(DataTransformationError("currency conversion of fundamental data failed"))
    end
    
    return df
end


function calculatevalues(price, fundamental_data::DataFrame, balance_data::DataFrame, outstanding_shares::Int)
    # filter and sort data data frames
    fundamental_hist = fundamental_data |> @filter(_.estimated == false) |> @orderby_descending(_.year) |> DataFrame
    balance_data = balance_data |> @orderby_descending(_.year) |> DataFrame

    # check for missing data
    if price === missing || nrow(fundamental_data) == 0
        return missing, missing, missing, missing
    end

    # trailing price earnings ratio
    earnings_per_share = (fundamental_hist |> @orderby_descending(_.year) |> @take(1) |> @select(:basic_earnings_per_share) |> DataFrame)[1,1]
    price_earnings_ratio = earnings_per_share <= 0 ? missing : round(price / earnings_per_share, digits=2)

    # price book ratio
    price_book_ratio = missing
    try
        price_book_ratio = price / ((balance_data[1,:total_assets] - balance_data[1,:total_liabilities]) / outstanding_shares)
    catch
        @warn "price boot ratio calculation failed"
    end    

    # dividend metrics
    try
        dividend_last = fundamental_hist[1,:dividend_per_share]
        dividend_avg3 = fundamental_hist[1:3,:dividend_per_share] |> mean

        dividend_yield_ratio_last = dividend_last === missing ? missing : round(dividend_last / price * 100, digits=2)
        dividend_yield_ratio_avg3 = dividend_avg3 === missing ? missing : round(dividend_avg3 / price * 100, digits=2)

        return price_earnings_ratio, price_book_ratio, dividend_yield_ratio_last, dividend_yield_ratio_avg3
    catch e
        return price_earnings_ratio, price_book_ratio, missing, missing
    end
end

end # module end
