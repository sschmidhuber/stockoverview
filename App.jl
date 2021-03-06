#! /usr/bin/env julia

include("DataUpdate.jl")

using Bukdu
using DataFrames
using Redis
using JSON
using StringBuilders
using Formatting
using Printf
using Statistics
using Dates
using UUIDs
using .DataUpdate

const update_interval = 60 * 60

struct AppController <: ApplicationController
    conn::Conn
end

struct SecurityFilter
    id::UUID
    options::Dict
end

SecurityFilter(dict::Dict) = SecurityFilter(uuid1(),dict)

# GET /securities
function get_securities(c::AppController)
    redis = RedisConnection()
    securities::Union{String,Nothing} = get(redis, "dataframe:securities")
    lastupdate = get(redis, "timestamp:last.data.update")

    # get filter if there is any
    filter_options::Union{String,Nothing} = haskey(c.params, "filter") ? get(redis, "dict:filter:" * c.params["filter"]) : nothing
    if filter_options !== nothing expire(redis, "dict:filter:" * c.params["filter"], 60*60*24*30) end

    disconnect(redis)

    filter = filter_options !== nothing ? SecurityFilter(c.params["filter"] |> UUID, JSON.Parser.parse(filter_options)) : nothing
    df = securities !== nothing ? dataframe(securities) : nothing

    if df === nothing || nrow(df) == 0
        @warn "no security data found"
        c.conn.request.response.status = 404
        return render(JSON, "error" => "no security data found")
    end
    if filter === nothing
        filtered_df = df
    else
        filtered_df = apply(df, filter)
    end
    
    res = Dict()
    res["rows"] = preparedata(filtered_df)
    res["cols"] = ["Company", "ISIN", "Price-earnings ratio", "Price-book ratio", "Dividend-return ratio", "Dividend-return ratio (Avg 3)", "Revenue", "Result of operations", "Income after tax", "Country", "Industry", "Share price (EUR)", "Annual report"]
    res["metadata"] = Dict("interval" => update_interval, "lastupdate" => lastupdate, "nrow" => nrow(filtered_df), "filtered" => filter !== nothing)
    vals = Dict()
    vals["revenue"] = [Int64(floor(df.revenue |> skipmissing |> minimum, digits=0)), Int64(ceil(df.revenue |> skipmissing |> maximum, digits=0))]
    vals["resultOfOperations"] = [Int64(floor(df.resultOfOperations |> skipmissing |> minimum, digits=0)), Int64(ceil(df.resultOfOperations |> skipmissing |> maximum, digits=0))]
    vals["incomeAfterTax"] = [Int64(floor(df.incomeAfterTax |> skipmissing |> minimum, digits=0)), Int64(ceil(df.incomeAfterTax |> skipmissing |> maximum, digits=0))]
    vals["priceEarningsRatio"] = [floor(df.priceEarningsRatio |> skipmissing |> minimum, digits=2), ceil(df.priceEarningsRatio |> skipmissing |> maximum, digits=2)]
    vals["priceBookRatio"] = [floor(df.priceBookRatio |> skipmissing |> minimum, digits=2), ceil(df.priceBookRatio |> skipmissing |> maximum, digits=2)]
    vals["industry"] = df.industry |> skipmissing |> unique |> Base.sort
    vals["country"] = df.country |> skipmissing |> unique |> Base.sort
    res["values"] = vals
    render(JSON, res)
end # get_securities

# GET /securities/metadata
function get_metadata(c::AppController)
    redis = RedisConnection()
    securities::Union{String,Nothing} = get(redis, "dataframe:securities")
    lastupdate = get(redis, "timestamp:last.data.update")
    disconnect(redis)

    df = securities !== nothing ? dataframe(securities) : nothing

    if df === nothing
        @warn "no security data found"
        c.conn.request.response.status = 404
        return render(JSON, "error" => "no security data found")
    end

    render(JSON, Dict("interval" => update_interval, "lastupdate" => lastupdate, "nrow" => nrow(df)))
end

# POST /filters
function post_filters(c::AppController)
    dict = Dict()
    foreach(x -> push!(dict, x), c.params)
    filter = SecurityFilter(dict)

    if !isvalid(filter)
        @warn "invalid filter definition $(filter.options)"
        c.conn.request.response.status = 400
        return render(JSON, "error" => "invalid filter definition")
    end

    redis = RedisConnection()
    set(redis, "dict:filter:" * string(filter.id), filter.options |> json)
    expire(redis, "dict:filter:" * string(filter.id), 60*60*24*30)
    disconnect(redis)

    render(JSON, "filterId" => filter.id |> string)
end

# TODO fix access to files outside public folder

routes() do
    plug(Plug.Static, at="/", from=normpath(@__DIR__, "public"))
    plug(Plug.Static, at="/", from=normpath(@__DIR__, "."))
    get("/securities", AppController, get_securities)
    get("/securities/metadata", AppController, get_metadata)
    post("/filters", AppController, post_filters)
end


# transform raw JSON string to DataFrame
function dataframe(json::String)
    df = JSON.Parser.parse(json; null = missing) |> DataFrame
    return df
end    


function preparedata(dataframe::DataFrame)
    df = deepcopy(dataframe)
    df.dividendReturnRatioLast = map(x -> x === missing ? "" : Printf.@sprintf("%.2f", round(x, digits=2)), df.dividendReturnRatioLast)
    df.dividendReturnRatioAvg3 = map(x -> x === missing ? "" : Printf.@sprintf("%.2f", round(x, digits=2)), df.dividendReturnRatioAvg3)
    df.priceBookRatio = map(x -> x === missing ? "" : Printf.@sprintf("%.2f", round(x, digits=2)), df.priceBookRatio)
    df.priceEarningsRatio = map(x -> x === missing ? "" : Printf.@sprintf("%.2f", round(x, digits=2)), df.priceEarningsRatio)
    df.price = map(x -> x === missing ? "" : Printf.@sprintf("%.2f", round(x, digits=2)), df.price)
    df.revenue = map(x -> x === missing ? "" : format(Int64(round(x, digits=0)), commas=true), df.revenue)
    df.resultOfOperations = map(x -> x === missing ? "" : format(Int64(round(x, digits=0)), commas=true), df.resultOfOperations)
    df.incomeAfterTax = map(x -> x === missing ? "" : format(Int64(round(x, digits=0)), commas=true), df.incomeAfterTax)

    # transform names to hyperlinks
    df.security = map(row -> """<a href="$(row.url)" target="_blank">$(row.security)</a>""", eachrow(df))

    # put columns in correct sequence
    df = df[:,[:security, :isin, :priceEarningsRatio, :priceBookRatio, :dividendReturnRatioLast, :dividendReturnRatioAvg3, :revenue, :resultOfOperations, :incomeAfterTax, :country, :industry, :price, :year]]

    data = map(eachrow(df)) do row
        collect(row)
    end
end

# apply security filter to security data frame
function apply(securities::DataFrame, filter::SecurityFilter)
    df = deepcopy(securities)
    apply!(df, filter)
    return df
end

# apply security filter to security data frame
function apply!(securities::DataFrame, filter::SecurityFilter)
    # filter categories
    mapping_categorical = Dict("country" => :country, "industry" => :industry)
    for (k,v) in mapping_categorical
        if haskey(filter.options, k)
            filter!(row -> row[v] in filter.options[k], securities)
        end
    end

    # filter intervals
    mapping_intervals = Dict("revenue" => :revenue, "resultOfOperations" => :resultOfOperations, "incomeAfterTax" => :incomeAfterTax, "priceEarningsRatio" => :priceEarningsRatio, "priceBookRatio" => :priceBookRatio)
    for (k,v) in mapping_intervals
        if haskey(filter.options, k)
            filter!(row -> row[v] !== missing ? row[v] >= filter.options[k][1] && row[v] <= filter.options[k][2] : false, securities)
        end
    end


    dfcopy = copy(securities)   # this is used to calculate the quantile of different values

    # get lower than quantile
    mapping_percentiles = Dict("pPer" => :priceEarningsRatio, "pPbr" => :priceBookRatio)
    for (k,v) in mapping_percentiles
        if haskey(filter.options, k) && length(dfcopy[!,v] |> skipmissing |> collect) > 0
            threshold = quantile(dfcopy[!,v] |> skipmissing, filter.options[k])
            filter!(row -> row[v] !== missing ? row[v] <= threshold : false, securities)
        end
    end

    # get higher than quantile
    mapping_percentiles = Dict("pDrrl" => :dividendReturnRatioLast, "pDrr3" => :dividendReturnRatioAvg3)
    for (k,v) in mapping_percentiles
        if haskey(filter.options, k) && length(dfcopy[!,v] |> skipmissing |> collect) > 0
            threshold = quantile(dfcopy[!,v] |> skipmissing, 1 - filter.options[k])
            filter!(row -> row[v] !== missing ? row[v] >= threshold : false, securities)
        end
    end
end


# security filter validation
function isvalid(filter::SecurityFilter)::Bool
    dict = filter.options
    if keys(dict) |> length == 0
        return false
    end

    intervals = ["revenue", "resultOfOperations", "incomeAfterTax"]
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

    percentiles = ["pPer", "pPbr", "pDrrl", "pDrr3"]
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


# start server and trigger data updates
if !isinteractive()
    Bukdu.start(8000, host = "0.0.0.0")
    while true
        @info "start data update"
        update_db()
        @info "data update completed"
        sleep(update_interval)
    end
end
