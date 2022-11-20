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
include("Model.jl")
using .Model

include("persistence/DBAccess.jl")
using .DBAccess

include("persistence/FSAccess.jl")
using .FSAccess

include("service/DataRetrieval.jl")
using .DataRetrieval

include("service/DataIngestion.jl")
using .DataIngestion

include("service/Scheduler.jl")
using .Scheduler

include("service/Service.jl")
using .Service

include("presentation/View.jl")
using .View

# DataIngestion.execute_datapipeline()

@warn "==== application end -- $(now()) ===="

end # module