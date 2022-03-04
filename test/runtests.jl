using Test
using Dates

ENV["database"] = "test.sqlite"

using StockOverview

@testset "Data Access" begin
    file = DataAccess.getdbfile()
    @test isfile(file)
end

@testset "Data Ingestion" begin
    security = DataIngestion.fetchsecurityheader("DE0008404005")
    @test security isa Model.Security
    @test security.name == "Allianz"
    security = DataIngestion.fetchsecurityheader("invalid ISIN")
    @test security isa Model.Security
    @test security.name === missing

    exchangerates = DataIngestion.fetchexchangerates()
    @test exchangerates isa Model.EuroExchangeRates
    @test exchangerates.date == today()
    @test exchangerates.rates["JPY"] > 1
    @test exchangerates.rates["GBP"] < 1
end
