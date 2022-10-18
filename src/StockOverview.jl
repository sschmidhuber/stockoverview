#! /usr/bin/env julia

module StockOverview

cd(@__DIR__)

using Logging
using Dates
if !isinteractive()
    mkpath("../logs")
    io = open("../logs/application.log", "a+", lock=true)
    global_logger(SimpleLogger(io))
    @info "application start -- $(now())"
end

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

DataIngestion.execute_datapipeline()

close(io)

end # module