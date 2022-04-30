#! /usr/bin/env julia

module StockOverview

cd(@__DIR__)

include("service/Models.jl")

include("service/Scheduler.jl")
using .Scheduler

include("service/DataIngestion.jl")
using .DataIngestion

ENV["database"] = "production.sqlite"
include("persistence/DataAccess.jl")
using .DataAccess

export Model, Scheduler, DataIngestion, DataAccess

end # module