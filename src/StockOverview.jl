#! /usr/bin/env julia

module StockOverview

export Model, Scheduler, DataRetrieval, DBAccess, DataIngestion

using LoggingExtras
using Dates

ENV["database"] = "stockoverview.db"
cd(@__DIR__)

# setup file logger in non-interactive execution
if !isinteractive()
    mkpath("../logs")
    io = open("../logs/application.log", "a+")
    logger = FormatLogger(io) do io, args
        println(io, args.level, ": ", args.message, "  (", args._module, ":", args.line, ")")
    end
    logger = MinLevelLogger(logger, Logging.Info)
    global_logger(logger)
    @warn "==== application start -- $(now()) ===="
end

# load local modules
include("service/Model.jl")
using .Model

include("service/Scheduler.jl")
using .Scheduler

include("service/DataRetrieval.jl")
using .DataRetrieval

include("persistence/DBAccess.jl")
using .DBAccess

include("persistence/DataIngestion.jl")
using .DataIngestion

include("ui/Dashboard.jl")
using .Dashboard

# DataIngestion.execute_datapipeline()

@warn "==== application end -- $(now()) ===="

end # module