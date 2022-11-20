module FSAccess

using ..Model
using CSV
using DataFrames
using Dates
using Parquet
using Query

export tmp_to_raw, extract_raw_data, remove_raw_data, getfile, getfirstfile, getlastingestdate, read_parquet, write_parquet, read_csv, cleanup

const RETENTION_LIMIT = 5
const PATHS = ("../data/raw", "../data/source", "../data/prepared")
const COMPRESSION = :zstd


"""
    tmp_to_raw(file::AbstractString, newfilename::AbstractString, ingest_date::Date)

Move temporary file to raw data layer.
"""
function tmp_to_raw(file::AbstractString, newfilename::AbstractString, ingest_date::Date)
    mkpath("../data/raw/$ingest_date")
    mv(file, "../data/raw/$ingest_date/$newfilename"; force=true)
end


"""
    extract_raw_data(ingest_date::Date)

Extract zip files in raw layer.
"""
function extract_raw_data(ingest_date::Date)
    @info "extract raw data"
    directory = "../data/raw/$ingest_date"
    extract_lei = `unzip -o -qq $directory/company_data.zip -d $directory`
    run(extract_lei)
    extract_isin = `unzip -o -qq $directory/ISIN_mapping.zip -d $directory`
    run(extract_isin)
end


"""
    remove_raw_data(ingest_date::Date)

Remove raw data of given ingest date to reduce disk utilization.
"""
function remove_raw_data(ingest_date::Date)
    @info "remove raw data"
    path = "$(PATHS[Int(raw)])/$ingest_date"
    rm(path, recursive=true)
end


"""
    getfirstfile(extension::AbstractString, layer::DataLayer, ingest_date::Date)

Returns the filename of the first file of given data layer and ingest date, with the specified file extension.

Extensions without dot and case sensitive, e.g. "csv".
"""
function getfirstfile(extension::AbstractString, layer::DataLayer, ingest_date::Date)
    directory = "$(PATHS[Int(layer)])/$ingest_date"
    readdir(directory) |> files -> filter(file -> endswith(file, extension), files) |> first
end


"""
    getlastingestdate(layer::DataLayer)::Date

Return last ingestion date of given data layer.
"""
function getlastingestdate(layer::DataLayer)::Date
    path = "$(PATHS[Int(layer)])"
    readdir(path) |> last |> Date
end


"""
    getfile(filename::AbstractString, layer::DataLayer, ingest_date::Date)::String

Return path to file of given file name, data layer and ingest date.
"""
function getfile(filename::AbstractString, layer::DataLayer, ingest_date::Date)::String
    if isfile("$(PATHS[Int(layer)])/$ingest_date/$filename")
        return "$(PATHS[Int(layer)])/$ingest_date/$filename"
    else
        @warn "file not found: $(PATHS[Int(layer)])/$ingest_date/$filename"
        return nothing
    end
end


"""
    read_parquet(filename::AbstractString, layer::DataLayer, ingest_date::Date)::DataFrame

Read parquet file from specified layer.
"""
function read_parquet(filename::AbstractString, layer::DataLayer, ingest_date::Date)::DataFrame
    path = "$(PATHS[Int(layer)])/$ingest_date/$filename"
    Parquet.read_parquet(path) |> DataFrame
end


"""
    write_parquet

Write parquet file to specified data layer.
"""
function write_parquet(df::DataFrame, filename::AbstractString, layer::DataLayer, ingest_date::Date)
    path = "$(PATHS[Int(layer)])/$ingest_date"
    mkpath(path)
    Parquet.write_parquet("$path/$filename", df, compression_codec=:zstd)
end


"""
    read_csv(filename::AbstractString, layer::DataLayer, ingest_date::Date)::DataFrame

Read CSV file from specified data layer.
"""
function read_csv(filename::AbstractString, layer::DataLayer, ingest_date::Date)::DataFrame
    path = "$(PATHS[Int(layer)])/$ingest_date"
    CSV.read("$path/$filename", DataFrame, stringtype=String)
end


"""
    cleanup()

Remove logs, files and directories, exceeding the retention limit. The retention limit represents the number of
past pipeline runs.
"""
function cleanup()
    @info "cleanup old logs, files and directories"
    logs = readdir("../logs/datapipeline") |> @orderby_descending(_) |> @drop(retention_limit)
    if length(logs) > 0
        for logfile in logs
            rm("../logs/datapipeline/$logfile")
        end
    end

    source_dirs = readdir(PATHS[Int(source)]) |> @orderby_descending(_) |> @drop(retention_limit)
    if length(source_dirs) > 0
        for dir in source_dirs
            rm("$(PATHS[Int(source)])/$dir", recursive=true)
        end
    end

    prepared_dirs = readdir(PATHS[Int(prepared)]) |> @orderby_descending(_) |> @drop(retention_limit)
    if length(prepared_dirs) > 0
        for dir in prepared_dirs
            rm("$(PATHS[Int(prepared)])/$dir", recursive=true)
        end
    end
end

end # module