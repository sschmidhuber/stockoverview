#! /usr/bin/env julia

include("DataUpdate.jl")

using Bukdu
using HttpCommon
using DataFrames
using SQLite
using JSON
using StringBuilders
using Formatting
using Printf
using Dates
using UUIDs
using .DataUpdate

const dbfile = "data/DB.sqlite"
const update_interval = 60 * 60

struct AppController <: ApplicationController
    conn::Conn
end

struct SecurityFilter
    id::UUID
    filter::Dict
end

SecurityFilter(dict::Dict) = SecurityFilter(uuid1(),dict)

# GET /securities
function get_securities(c::AppController)
    db = SQLite.DB(dbfile)
    securities = DBInterface.execute(db, "SELECT * FROM Securities") |> DataFrame
    updates = DBInterface.execute(db, "SELECT timestamp FROM Updates ORDER BY timestamp DESC LIMIT 1") |> DataFrame
    DBInterface.close!(db)
    lastupdate = updates.timestamp |> first
    res = Dict()
    res["rows"] = preparedata(securities)
    res["cols"] = ["Company", "ISIN", "Price-earnings ratio", "Price-book ratio", "Dividend-return ratio", "Dividend-return ratio (Avg 3)", "Dividend-return ratio (Avg 5)", "Revenue", "Net income", "Country", "Industry", "Sector", "Sub sector", "Share price (EUR)", "Dividend per share (EUR)", "Annual report"]
    res["metadata"] = Dict("interval" => update_interval, "lastupdate" => lastupdate, "nrow" => nrow(securities))
    vals = Dict()
    vals["revenue"] = [Int64(round(securities.revenue |> skipmissing |> minimum, digits=0)), Int64(round(securities.revenue |> skipmissing |> maximum, digits=0))]
    vals["incomeNet"] = [Int64(round(securities.incomeNet |> skipmissing |> minimum, digits=0)), Int64(round(securities.incomeNet |> skipmissing |> maximum, digits=0))]
    vals["industry"] = securities.industry |> skipmissing |> unique |> sort
    vals["sector"] = securities.sector |> skipmissing |> unique |> sort
    vals["subsector"] = securities.subsector |> skipmissing |> unique |> sort
    vals["country"] = securities.country |> skipmissing |> unique |> sort
    res["values"] = vals
    render(JSON, res)
end

# POST /filters
function post_filters(c::AppController)
    dict = Dict()
    foreach(x -> push!(dict, x), c.params)
    filter = SecurityFilter(dict)
    if !isvalid(filter)
        c.conn.request.response.status = 400
        return render(JSON, "error" => "invalid filter definition")
    end
    db = SQLite.DB(dbfile)
    df = DataFrame(id = [filter.id |> string], date = [today() |> string], filter = [filter.filter |> json])
    df |> SQLite.load!(db, "SecurityFilters")
    DBInterface.close!(db)
    render(JSON, "filter-id" => filter.id |> string)
end

# TODO fix access to files outside public folder

routes() do
    plug(Plug.Static, at="/", from=normpath(@__DIR__, "public"))
    plug(Plug.Static, at="/", from=normpath(@__DIR__, "."))
    get("/securities", AppController, get_securities)
    post("/filters", AppController, post_filters)
end


function preparedata(dataframe::DataFrame)
    df = deepcopy(dataframe)
    df.dividendPerShare = map(x -> x === missing ? "" : Printf.@sprintf("%.2f", round(x, digits=2)), df.dividendPerShare)
    df.dividendReturnRatioLast = map(x -> x === missing ? "" : Printf.@sprintf("%.2f", round(x, digits=2)), df.dividendReturnRatioLast)
    df.priceBookRatio = map(x -> x === missing ? "" : Printf.@sprintf("%.2f", round(x, digits=2)), df.priceBookRatio)
    df.priceEarningsRatio = map(x -> x === missing ? "" : Printf.@sprintf("%.2f", round(x, digits=2)), df.priceEarningsRatio)
    df.price = map(x -> x === missing ? "" : Printf.@sprintf("%.2f", round(x, digits=2)), df.price)
    df.revenue = map(x -> x === missing ? "" : format(Int64(round(x, digits=0)), commas=true), df.revenue)
    df.incomeNet = map(x -> x === missing ? "" : format(Int64(round(x, digits=0)), commas=true), df.incomeNet)

    # transform ISINs to hyperlinks
    df.isin = map(row -> """<a href="$(row.url)" target="_blank">$(row.isin)</a>""", eachrow(df))

    # remove url and currency columns
    df = df[:,1:end-2]

    data = map(eachrow(df)) do row
        collect(row)
    end
end

# security filter validation
function isvalid(securityfilter::SecurityFilter)::Bool
    dict = securityfilter.filter

    intervals = ["revenue", "incomeNet"]
    interval_check = map(intervals) do i
        if haskey(dict, i) && !isinterval(dict[i])
            return false
        else
            return true
        end
    end
    if any(x -> x == false, interval_check)
        return false
    end

    percentiles = ["p-per", "p-pbr", "p-drrl", "p-drr3", "p-drr5"]
    percentile_check = map(percentiles) do p
        if haskey(dict, p) && !ispercentile(dict[p])
            return false
        else
            return true
        end
    end
    if any(x -> x == false, percentile_check)
        return false
    end

    return true
end

isinterval(i) = i isa Array && length(i) == 2 && i[1] isa Number && i[2] isa Number && i[1] <= i[2]
ispercentile(p) = p isa Float64 && p >= 0.01 && p <= 0.99


if !isinteractive()
    Bukdu.start(8000, host = "0.0.0.0")
    while true
        @info "start data update"
        update_db(dbfile, concurrent_execution = true)
        @info "data update completed"
        sleep(update_interval)
    end
end
