module DataUpdate

include("SecurityData.jl")

using DataFrames
using CSV
using SQLite
using HTTP
using LightXML
using Logging
using Dates
using .SecurityData
import Base.push!

export update


function update(db::String; concurrent_execution = true)
    @info "read \"Securities.csv\" file"
    securities = CSV.read("data/Securities.csv")
    @info "$(nrow(securities)) ISINs"
    df = DataFrame(
        security = String[],
        isin = String[],
        priceEarningsRatio = [],
        priceBookRatio = [],
        dividendReturnRatioLast = [],
        dividendReturnRatioAvg3 = [],
        dividendReturnRatioAvg5 = [],
        revenue = [],
        incomeNet = [],
        country = [],
        industry = [],
        sector = [],
        subsector = [],
        price = [],
        dividendPerShare = [],
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
            push!(df, security)
        end
    else
        # fetch sequential
        foreach(securities.ISIN) do isin
            security = fetchsecurity(isin, exchangerates)
            push!(df, security)
            sleep(1) # to ensure little load on requested servers
        end
    end

    db = SQLite.DB(db)
    tables = SQLite.tables(db)
    if !(isempty(tables)) && findfirst(x -> x == "Securities", tables.name) != nothing
        DBInterface.execute(db, "DELETE FROM Securities")
    end
    df |> SQLite.load!(db, "Securities")
    updates = DataFrame(timestamp = [Dates.format(now(Dates.UTC), "yyyy-mm-ddTHH:MM:SS") * "Z"])
    updates |> SQLite.load!(db, "Updates")
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
        if security.histkeydata |> nrow != 0
            push!(df, [
            security.name,
            security.isin,
            security.price_earnings_ratio,
            security.histkeydata.priceBookRatio |> first,
            security.dividend_return_ratio_last,
            security.dividend_return_ratio_avg3,
            security.dividend_return_ratio_avg5,
            security.histkeydata.revenue |> first,
            security.histkeydata.incomeNet |> first,
            security.country,
            security.industry,
            security.sector,
            security.subsector,
            security.last_price,
            security.histkeydata.dividendPerShare |> first,
            security.histkeydata.year |> first,
            "https://wertpapiere.ing.de/Investieren/Aktie/$(security.isin)",
            security.currency
            ])
        end
    end
end
end # module end
