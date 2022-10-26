#! /usr/bin/env julia

module StockOverview

cd(@__DIR__)

using LoggingExtras
using Dates
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

# DataIngestion.execute_datapipeline()

@warn "==== application end -- $(now()) ===="
close(io)

end # module