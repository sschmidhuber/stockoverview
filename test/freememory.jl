using Pkg
Pkg.activate(".")
using Parquet
using DataFrames

cd(joinpath(@__DIR__,".."))



checkmem = `free -h`

function loaddata()
    parquet1 = read_parquet("data/source/2022-11-27/company_data_snappy.parquet")
    parquet2 = read_parquet("data/source/2022-11-28/company_data_snappy.parquet")
    parquet3 = read_parquet("data/source/2022-11-29/company_data_snappy.parquet")
    parquet4 = read_parquet("data/source/2022-12-01/company_data_snappy.parquet")

    df1 = parquet1 |> DataFrame
    df2 = parquet2 |> DataFrame
    df3 = parquet3 |> DataFrame
    df4 = parquet4 |> DataFrame

    return nothing
end

run(checkmem)
loaddata()
run(checkmem)
GC.gc()
run(checkmem);