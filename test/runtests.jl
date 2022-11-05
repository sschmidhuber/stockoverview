using Test
using Dates

cd(@__DIR__)

include("../src/logic/Model.jl")
using .Model

ENV["database"] = "test.sqlite"
include("../src/data/DBAccess.jl")
using .DBAccess

include("../src/logic/DataRetrieval.jl")
using .DataRetrieval

include("../src/data/DataIngestion.jl")
using .DataIngestion

include("../src/logic/Service.jl")
using .Service

@testset "StockOverview" begin

@testset "Data Retrieval" begin
    security = DataRetrieval.fetchsecurityheader("DE0008404005")
    @test security isa Model.Security
    @test security.name == "Allianz"
    security = DataIngestion.fetchsecurityheader("invalid ISIN")
    @test security isa Model.Security
    @test security.name === missing

    exchangerates = DataRetrieval.fetchexchangerates()
    @test exchangerates isa Model.EuroExchangeRates
    # set offset for weekend days, because no new exchange rates are expected on those days
    if dayofweek(today()) == 6
        offset = 1
    elseif dayofweek(today()) == 7
        offset = 2
    else
        offset = 0 
    end
    @test exchangerates.date == today() - Day(offset)
    @test exchangerates.rates["JPY"] > 1
    @test exchangerates.rates["GBP"] < 1
end
end
