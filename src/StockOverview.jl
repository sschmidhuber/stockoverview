#! /usr/bin/env julia

module StockOverview

cd(@__DIR__)

include("service/Model.jl")
using .Model

include("service/Scheduler.jl")
using .Scheduler

include("service/DataIngestion.jl")
using .DataIngestion

if haskey(ENV, "database") == false
    ENV["database"] = "production.sqlite"
end
include("persistence/DataAccess.jl")
using .DataAccess

export Model, Scheduler, DataIngestion, DataAccess

end # module