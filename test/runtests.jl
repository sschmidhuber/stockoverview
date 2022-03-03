using StockOverview
using Test
using Dates


@testset "Data Ingestion" begin
    security = DataIngestion.fetchsecurityheader("DE0008404005")
    @test security isa Model.Security
    @test security.name == "Allianz"
    security = DataIngestion.fetchsecurityheader("vinvalid ISIN")
    @test security isa Model.Security
    @test security.name === missing

    exchangerates = DataIngestion.fetchexchangerates()
    @test exchangerates isa Model.EuroExchangeRates
    @test exchangerates.date == today()
    @test exchangerates.rates["JPY"] > 1
    @test exchangerates.rates["GBP"] < 1
end
