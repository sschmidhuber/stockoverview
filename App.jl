#! /usr/bin/env julia

include("DataUpdate.jl")

using Bukdu
using HttpCommon
using DataFrames
using SQLite
using StringBuilders
using Dates
using .DataUpdate

const dbfile = "data/DB.sqlite"
const update_interval = 60 * 60

struct StockOverviewController <: ApplicationController
    conn::Conn
end

# GET /securities
function securities(c::StockOverviewController)
    db = SQLite.DB(dbfile)
    df = DBInterface.execute(db, "SELECT * FROM Securities") |> DataFrame
    res = Dict()
    res["rows"] = preparedata(df)
    res["cols"] = ["Company", "ISIN", "Price-earnings ratio", "Price-book ratio", "Dividend-return ratio", "Dividend-return ratio (Avg 3)", "Dividend-return ratio (Avg 5)", "Revenue", "Net income", "Country", "Industry", "Sector", "Sub sector", "Share price (EUR)", "Dividend per share (EUR)", "Annual report"]
    return render(JSON, res)
end


# GET /securities/metadata
function metadata(c::StockOverviewController)
    db = SQLite.DB(dbfile)
    rs = DBInterface.execute(db, "SELECT timestamp FROM Updates ORDER BY timestamp DESC LIMIT 1") |> DataFrame
    lastupdate = rs.timestamp |> first
    return render(JSON, Dict("interval" => update_interval, "lastupdate" => lastupdate))
end

# TODO fix access to files outside public folder

routes() do
    plug(Plug.Static, at="/", from=normpath(@__DIR__, "public"))
    plug(Plug.Static, at="/", from=normpath(@__DIR__, "."))
    get("/securities", StockOverviewController, securities)
    get("/securities/metadata", StockOverviewController, metadata)
end


function preparedata(df::DataFrame)
    replace!(df.country, "JE" => "Jersey", "US" => "United States", "IL" => "Israel", "PA" => "Panama", "BM" => "Bermudas", "CW" => "Curaçao", "CN" => "China", "JP" => "Japan", "LI" => "Liechtenstein", "GG" => "Guernsey")
    df.dividendPerShare = map(x -> x === missing ? "" : round(x, digits=2), df.dividendPerShare)
    df.dividendReturnRatioLast = map(x -> x === missing ? "" : round(x, digits=2), df.dividendReturnRatioLast)
    df.priceBookRatio = map(x -> x === missing ? "" : round(x, digits=2), df.priceBookRatio)
    df.priceEarningsRatio = map(x -> x === missing ? "" : round(x, digits=2), df.priceEarningsRatio)
    df.price = map(x -> x === missing ? "" : round(x, digits=2), df.price)
    df.revenue = map(x -> x === missing ? "" : Int64(round(x, digits=0)), df.revenue)
    df.incomeNet = map(x -> x === missing ? "" : Int64(round(x, digits=0)), df.incomeNet)

    # transform ISINs to hyperlinks
    df.isin = map(row -> """<a href="$(row.url)" target="_blank">$(row.isin)</a>""", eachrow(df))

    # remove url and currency columns
    df = df[:,1:end-2]

    data = map(eachrow(df)) do row
        collect(row)
    end
end




if !isinteractive()
    Bukdu.start(8000, host = "0.0.0.0")
    while true
        @info "start data update"
        update(dbfile, concurrent_execution = false)
        @info "data update completed"
        sleep(update_interval)
    end
end
