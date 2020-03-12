include("SecurityData.jl")

using DataFrames
using CSV
using SQLite
using HTTP
using LightXML
using Logging
using .SecurityData
import Base.push!


function update(concurrent_execution = true)
    @info "read \"Securities.csv\" file"
    securities = CSV.read("Securities.csv")
    @info "$(nrow(securities)) ISINs"
    df = DataFrame(
        security = String[],
        isin = String[],
        priceEarningsRatio = [],
        priceBookRatio = [],
        dividendReturnRatioLast = [],
        dividendReturnRatioAvg3 = [],
        dividendReturnRatioAvg5 = [],
        dividendPerShare = [],
        revenue = [],
        incomeNet = [],
        year = [],
        industry = [],
        sector = [],
        subsector = [],
        country = [],
        price = [],
        currency = String[],
        url = String[],
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
            push!(df, security)
        end
    else
        # fetch sequential
        foreach(securities.ISIN) do isin
            security = fetchsecurity(isin, exchangerates)
            push!(df, security)
        end
    end

    db = SQLite.DB("DB.securities")
    SQLite.drop!(db, "Securities")
    df |> SQLite.load!(db, "Securities")
end

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
    if security.name === missing
        @info "$(security.isin) : no data found"
    else
        @info "$(security.isin) : $(security.name) => $(security.last_price) $(security.currency)"

        if security.histkeydata |> nrow != 0
            push!(df, [
            security.name,
            security.isin,
            security.price_earnings_ratio,
            security.histkeydata.priceBookRatio |> first,
            security.dividend_return_ratio_last,
            security.dividend_return_ratio_avg3,
            security.dividend_return_ratio_avg5,
            security.histkeydata.dividendPerShare |> first,
            security.histkeydata.revenue |> first,
            security.histkeydata.incomeNet |> first,
            security.histkeydata.year |> first,
            security.industry,
            security.sector,
            security.subsector,
            security.country,
            security.last_price,
            security.currency,
            "https://wertpapiere.ing.de/Investieren/Aktie/$(security.isin)"]);
        else
            @warn "$(security.isin) : no hist data found, skip $(security.name)"
        end
    end
end
