#! /usr/bin/env julia

include("DataUpdate.jl")

using Bukdu
using HttpCommon
using DataFrames
using SQLite
using StringBuilders
using Dates
using .DataUpdate

const dbfile = "data/DB.securities"
const update_interval = 60 * 60

struct StockOverviewController <: ApplicationController
    conn::Conn
end

# GET /securities
function securities(c::StockOverviewController)
    db = SQLite.DB(dbfile)
    df = DBInterface.execute(db, "SELECT * FROM Securities") |> DataFrame
    return render(HTML, renderHTML(df))
end


# GET /securities/metadata
function metadata(c::StockOverviewController)
    db = SQLite.DB(dbfile)
    rs = DBInterface.execute(db, "SELECT timestamp FROM Updates ORDER BY timestamp DESC LIMIT 1") |> DataFrame
    lastupdate = rs.timestamp |> first
    return render(JSON, Dict("interval" => update_interval, "lastupdate" => lastupdate))
end


routes() do
    plug(Plug.Static, at="/", from=normpath(@__DIR__, "public"))
    plug(Plug.Static, at="/", from=normpath(@__DIR__, "."))
    get("/securities", StockOverviewController, securities)
    get("/securities/metadata", StockOverviewController, metadata)
end


function renderHTML(df::DataFrame)::String
    #columns = ["security", "isin", "priceEarningsRatio", "priceBookRatio", "dividendReturnRatio", "revenue", "incomeNet", "country", "industry", "sector", "subsector", "price", "dividentPerShare", "year"]

    # pre processing
    replace!(df.country, "JE" => "Jersey", "US" => "United States", "IL" => "Israel", "PA" => "Panama", "BM" => "Bermudas", "CW" => "Curaçao", "CN" => "China", "JP" => "Japan", "LI" => "Liechtenstein", "GG" => "Guernsey")
    df.security = map(x -> escapeHTML(x), df.security)
    df.industry = map(x -> x === missing ? "" : escapeHTML(x), df.industry)
    df.sector = map(x -> x === missing ? "" : escapeHTML(x), df.sector)
    df.subsector = map(x -> x === missing ? "" : escapeHTML(x), df.subsector)
    df.dividendPerShare = map(x -> x === missing ? "" : round(x, digits=2), df.dividendPerShare)
    df.dividendReturnRatioLast = map(x -> x === missing ? "" : round(x, digits=2), df.dividendReturnRatioLast)
    df.priceBookRatio = map(x -> x === missing ? "" : round(x, digits=2), df.priceBookRatio)
    df.priceEarningsRatio = map(x -> x === missing ? "" : round(x, digits=2), df.priceEarningsRatio)
    df.price = map(x -> x === missing ? "" : round(x, digits=2), df.price)
    df.revenue = map(x -> x === missing ? "" : Int64(round(x, digits=0)), df.revenue)
    df.incomeNet = map(x -> x === missing ? "" : Int64(round(x, digits=0)), df.incomeNet)

    sb = StringBuilder()
    append!(sb, """<table id="dataframe" class="table table-striped table-bordered" cellspacing="0">
    <thead>
    <tr>
    <th>Company</th>
    <th>ISIN</th>
    <th>Price-earnings ratio</th>
    <th>Price-book ratio</th>
    <th>Dividend-return ratio</th>
    <th>Revenue</th>
    <th>Net income</th>
    <th>Country</th>
    <th>Industry</th>
    <th>Share price (EUR)</th>
    <th>Dividend per share (EUR)</th>
    <th>Annual report</th>
    </tr>
    </thead>
    <tbody>
    """)

    for i in 1:nrow(df)
        append!(sb, "<tr><td>$(df.security[i])</td><td><a href=\"$(df.url[i])\" target=\"_blank\">$(df.isin[i])</a></td>
        <td>$(df.priceEarningsRatio[i])</td><td>$(df.priceBookRatio[i])</td>
        <td>$(df.dividendReturnRatioLast[i])</td><td>$(df.revenue[i])</td>
        <td>$(df.incomeNet[i])</td><td>$(df.country[i])</td><td>$(df.industry[i])</td>
        <td>$(df.price[i])</td><td>$(df.dividendPerShare[i])</td><td>$(df.year[i])</td></tr>")
    end

    append!(sb, "</tbody></table>")

    return String(sb)
end # renderHTML

Bukdu.start(8000, host = "0.0.0.0")

if !isinteractive()
    while true
        update(dbfile, concurrent_execution = false)
        sleep(update_interval)
    end
end
