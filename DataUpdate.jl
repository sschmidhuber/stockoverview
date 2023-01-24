module DataUpdate

include("SecurityData.jl")

using DataFrames
using CSV
using Redis
using JSON
using HTTP
using LightXML
using Logging
using Dates
using .SecurityData
import Base.push!

export update_db, fetchexchangerates


function update_db(concurrent_execution = false)
    local path
    if isinteractive()
        path = "data/Securities_test.csv"
        @info "TEST MODE: read \"$path\""
    else
        path = "data/Securities.csv"
        @info "read \"$path\""
    end
    securities = CSV.read(path, DataFrame)
    @info "$(nrow(securities)) ISINs"

    df = DataFrame(
        security = String[],
        isin = String[],
        priceEarningsRatio = [],
        priceBookRatio = [],
        dividendReturnRatioLast = [],
        dividendReturnRatioAvg3 = [],
        revenue = [],
        resultOfOperations = [],
        incomeAfterTax = [],
        country = [],
        industry = [],
        price = [],
        year = [],
        url = String[],
        currency = [],
    )

    @info "get currency exchange rates"
    exchangerates = fetchexchangerates()

    @info "fetch security data"
    if concurrent_execution
        # schedule tasks
        tasks = map(securities.ISIN) do isin
            sleep(0.01)  # giving the scheduler some time to breath
            @async fetchsecurity(isin, exchangerates)
        end

        # fetch results
        foreach(tasks) do task
            security = fetch(task)
            if security !== nothing
                push!(df, security)
            end
        end
    else
        # fetch sequential
        foreach(securities.ISIN) do isin
            @info isin
            security = fetchsecurity(isin, exchangerates)
            if security !== nothing
                push!(df, security)
            end
            sleep(0.3) # to ensure low request frequency on server
        end
    end

    @info "$(nrow(df)) securities fetched"
    # map and transform values
    #replace!(df.country, "JE" => "Jersey", "US" => "United States", "IL" => "Israel", "PA" => "Panama", "BM" => "Bermudas", "CW" => "Curaçao", "CN" => "China", "JP" => "Japan", "LI" => "Liechtenstein", "GG" => "Guernsey", "LR" => "Liberia")

    @info "store security data to DB"
    redis = RedisConnection()
    set(redis, "dataframe:securities", df |> json)
    set(redis, "timestamp:last.data.update", Dates.format(now(Dates.UTC), "yyyy-mm-ddTHH:MM:SS") * "Z")
    disconnect(redis)
    @info "update completed"
end # function update


function fetchexchangerates()::Dict{String,Float64}
    exchangerates = Dict{String,Float64}()
    res = HTTP.request("GET","https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml")
    xml = res.body |> String |> LightXML.parse_string
    cube = find_element(root(xml), "Cube") |> child_elements |> first |> child_elements
    foreach(cube) do currency
        push!(exchangerates, attribute(currency, "currency"; required=true) => parse(Float64, attribute(currency, "rate"; required=true)))
    end

    return exchangerates
end


function push!(df::DataFrame, security::Security)
    if security.name !== missing
        if security.pl_data |> nrow != 0
            push!(df, [
            security.name,
            security.isin,
            security.price_earnings_ratio,
            security.price_book_ratio,
            security.dividend_return_ratio_last,
            security.dividend_return_ratio_avg3,
            security.pl_data.revenue |> first,
            security.pl_data.result_of_operations |> first,
            security.pl_data.income_after_tax |> first,
            security.country,
            security.industry,
            security.last_price,
            security.pl_data.year |> first,
            "https://wertpapiere.ing.de/Investieren/Aktie/$(security.isin)",
            security.currency
            ])
        end
    end
end
end # module end
