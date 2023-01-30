using Revise
using LoggingExtras
using Dates

ENV["database"] = "test.sqlite"
ENV["retention_limit"] = 5
cd(joinpath(@__DIR__, "..", "src"))

include("../src/Model.jl")
using .Model

include("../src/persistence/FSAccess.jl")
using .FSAccess

includet("../src/persistence/DBAccess.jl")
using .DBAccess

include("../src/service/Scheduler.jl")
using .Scheduler

include("../src/service/DataRetrieval.jl")
using .DataRetrieval

includet("../src/service/DataIngestion.jl")
using .DataIngestion
#include("../src/service/Service.jl")

ingest_date = Date("2022-11-30")
