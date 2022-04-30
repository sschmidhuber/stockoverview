using Test
using Dates

cd(@__DIR__)

include("../src/service/Models.jl")

ENV["database"] = "test.sqlite"
include("../src/persistence/DataAccess.jl")
using .DataAccess

include("../src/service/DataIngestion.jl")
using .DataIngestion

@testset "StockOverview" begin
@testset "Data Access" begin
    file = DataAccess.getdbfile()
    @test isfile(file)
end

@testset "Data Ingestion" begin
    security = DataIngestion.fetchsecurityheader("DE0008404005")
    @test security isa Models.Security
    @test security.name == "Allianz"
    security = DataIngestion.fetchsecurityheader("invalid ISIN")
    @test security isa Models.Security
    @test security.name === missing

    exchangerates = DataIngestion.fetchexchangerates()
    @test exchangerates isa Models.EuroExchangeRates
    # set offset for weekend days, because not new exchange rates are expected on those days
    if dayofweek(today()) == 6
        offset = 1
    elseif dayofweek(today()) == 7
        offset = 2
    else
        offset = 0 
    end
    @test exchangerates.date == today() - offset
    @test exchangerates.rates["JPY"] > 1
    @test exchangerates.rates["GBP"] < 1
end
end
