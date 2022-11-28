module Scheduler

using Dates
import Base.match

export schedulejob, start_scheduler

mutable struct Job
    func::Function
    lastexecution::Union{String,Nothing}
    minute::Union{Int,AbstractRange}
    hour::Union{Int,AbstractRange}
    dayofweek::Union{Int,AbstractRange}
    dayofmonth::Union{Int,AbstractRange}
end

Job(func, minute, hour, dayofweek, dayofmonth) = Job(func, nothing, minute, hour, dayofweek, dayofmonth)


const interval = 20 # interval between cheicking if a task execution is scheduled
const jobs = Vector{Job}()


"""
    schedulejob(func::Task, minute::Union{Int,AbstractRange} = 0:59, hour::Union{Int,AbstractRange} = 0:23, day_of_week::Union{Int,AbstractRange} = 1:7, day_of_month::Union{Int,AbstractRange} = 1:31)

Schedule a function for execution at specified time.
"""
function schedulejob(func::Function; minute::Union{Int,AbstractRange} = 0:59, hour::Union{Int,AbstractRange} = 0:23, day_of_week::Union{Int,AbstractRange} = 1:7, day_of_month::Union{Int,AbstractRange} = 1:31)
    if inrange(minute, 0:59) && inrange(hour, 0:23) && inrange(day_of_week, 1:7) && inrange(day_of_month, 1:31)
        push!(jobs, Job(func, minute, hour, day_of_week, day_of_month))
    else
        @warn "couldn't schedule func at minute: $minute, hour: $hour, day of week: $day_of_week, day of month: $day_of_month"
    end
end


"""
    inrange(x, range)

Check if x is within the bounds of range.
"""
function inrange(x, range)
    minimum(x) >= minimum(range) && maximum(x) <= maximum(range)
end


"""
    match(timestamp, job::Job)

Returns true if the timestamp matches the scheduled job, otherwise false.
"""
function match(timestamp, job::Job)
    minute(timestamp) ∈ job.minute && hour(timestamp) ∈ job.hour && dayofweek(timestamp) ∈ job.dayofweek && dayofmonth(timestamp) ∈ job.dayofmonth
end


"""
    period_id(timestamp)

returns a string ID, representing the given timestamp
"""
function period_id(timestamp)
    return "$(minute(timestamp))-$(hour(timestamp))-$(dayofweek(timestamp))-$(dayofmonth(timestamp))"    
end


"""
    start_scheduler()

start the scheduler
"""
function start_scheduler()
    while true
        current_time = now()
        @info "check at: $current_time"
        foreach(jobs) do job
            if match(current_time, job)
                current_period = period_id(current_time)
                if job.lastexecution != current_period
                    @info "execute $(nameof(job.func))"
                    job.lastexecution = current_period
                    @async job.func()
                end
            end
        end

        sleep(interval)
    end
end


end # module