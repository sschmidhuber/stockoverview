module Scheduler

using Dates

function daily()
    last = today() - Dates.Day(1)
    
    function closure()
        date = today()
        if last < date
            last = date
            return true
        else
            return false
        end
    end

    return closure
end


function sunday()
    last = today() - Dates.Day(1)

    function closure()
        date = today()

        if dayofweek(date) == 7 && last < date
            last = date
            return true
        else
            return false            
        end
    end
    
    return closure
end

# executes func, if execution_test returns ture, execution_test is run after every test_interval
function start_task(func::Function, execution_test::Function, task_name = "unknown", test_interval::Int = 60 * 60)
    
    function closure()
        while true
            @info "evaluate execution of task: $task_name"
            if execution_test()
                @info "execute task: $task_name"
                try
                    func()
                catch e
                    @error "fatal error during exection of scheduled task: $task_name"
                    showerror(stdout, e)
                end
            end
            sleep(test_interval)
        end
    end

    task = Task(closure)
    schedule(task)
end

end # module