using Test
using Dates
using Logging
using Chain
using Parquet
using DataFrames
using Random

cd(@__DIR__)

include("../src/Model.jl")
using .Model

ENV["database"] = "test.sqlite"
ENV["retention_limit"] = 5
include("../src/persistence/DBAccess.jl")
using .DBAccess

include("../src/persistence/FSAccess.jl")
using .FSAccess

include("../src/service/DataRetrieval.jl")
using .DataRetrieval

include("../src/service/DataIngestion.jl")
using .DataIngestion

include("../src/service/Scheduler.jl")
using .Scheduler

include("../src/service/Service.jl")
using .Service

debug =  ConsoleLogger(stderr, Debug)
#disable_logging(Info)

@testset "Stock Overview" begin
    include("data_retrieval.jl")
    include("data_ingestion.jl")
    #include("scheduler.jl")
end;