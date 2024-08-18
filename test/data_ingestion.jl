function prepare_test_data(ingest_date)
    isins = String[]
    leis = String[]
    rng = MersenneTwister(datetime2unix(now()) |> round |> Int)
    changes = 3
    securities = Parquet.read_parquet("security_data.parquet") |> DataFrame
    rows = rand(rng, 1:nrow(securities), changes)
    foreach(rows) do row
        securities[row,:name] = "Company Name $row"
        securities[row,:type] = "Share"
        push!(isins, securities[row,:isin])
    end

    companies = Parquet.read_parquet("company_data.parquet") |> DataFrame
    rows = rand(rng, 1:nrow(companies), changes)
    foreach(rows) do row
        companies[row,:name] = "Company Name $row"
        companies[row,:country] = "DE"
        push!(leis, companies[row,:lei])
    end
    
    mapping = Parquet.read_parquet("isin_mapping.parquet") |> DataFrame
    if changes > 0
        for i in 1:changes
            push!(mapping, (LEI=leis[i], ISIN=isins[i]))
        end
    end

    mkpath("../data/source/$ingest_date")
    mkpath("../data/prepared/$ingest_date")

    Parquet.write_parquet("../data/prepared/$ingest_date/security_data.parquet", securities)
    Parquet.write_parquet("../data/source/$ingest_date/company_data.parquet", companies)
    Parquet.write_parquet("../data/source/$ingest_date/isin_mapping.parquet", mapping)
end

function remove_testdata(ingest_date)
    rm("../data/raw/$ingest_date"; force=true, recursive=true)
    rm("../data/source/$ingest_date"; force=true, recursive=true)
    rm("../data/prepared/$ingest_date"; force=true, recursive=true)    
end

@testset "Data Ingestion" begin
    @info "-- test data ingestion --"
    ingest_date = today()
    prepare_test_data(ingest_date)

    DataIngestion.download_raw_data(ingest_date)
    @test isfile("../data/raw/$ingest_date/company_data.zip")
    @test isfile("../data/raw/$ingest_date/ISIN_mapping.zip")

    securities, companies = DataIngestion.filter_and_join(ingest_date)
    @test securities isa DataFrame
    @test companies isa DataFrame
    with_logger(debug) do
        DataIngestion.write_to_db(securities, companies)
    end
    remove_testdata(ingest_date)
end