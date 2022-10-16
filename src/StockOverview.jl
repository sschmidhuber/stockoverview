#! /usr/bin/env julia

module StockOverview

cd(@__DIR__)

include("service/Models.jl")

include("service/Scheduler.jl")
using .Scheduler

include("service/DataRetrieval.jl")
using .DataRetrieval

ENV["database"] = "production.sqlite"
include("persistence/DBAccess.jl")
using .DBAccess

include("persistence/DataIngestion.jl")
using .DataIngestion

export Model, Scheduler, DataRetrieval, DBAccess, DataIngestion

end # module