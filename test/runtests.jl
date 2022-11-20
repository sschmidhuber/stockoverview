using Test
using Dates

cd(@__DIR__)

include("../src/Model.jl")
using .Model

ENV["database"] = "test.sqlite"
include("../src/persistence/DBAccess.jl")
using .DBAccess

include("../src/persistence/FSAccess.jl")
using .FSAccess

include("../src/service/DataRetrieval.jl")
using .DataRetrieval

include("../src/service/DataIngestion.jl")
using .DataIngestion

include("../src/service/Service.jl")
using .Service

@testset "StockOverview" begin

@testset "Data Retrieval" begin
    security = DataRetrieval.fetch_security("DE0008404005")
    @test security isa Model.Security
    @test security.name == "Allianz"
    @test security.symbol == "ALV.DE"
    @test security.outstanding > 400_000_000 && security.outstanding < 500_000_000
    security = DataIngestion.fetch_security("invalid ISIN")
    @test security isa Model.Security
    @test security.name === missing

    exchangerates = DataRetrieval.fetch_exchangerates()
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
