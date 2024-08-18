"""
    rmtemp()

    Remove temporary files in current working directory
"""
function rmtemp()
    @chain readdir(pwd()) begin
        filter(x -> startswith(x, "jl_"),_)
        rm.(_)
    end
end

@testset "Scheduler" begin
    @info "-- test scheduler --"
    rmtemp()
    func = () -> mktemp(pwd())
    Scheduler.addjob(func)
    Scheduler.start()
    sleep(1)
    @test Scheduler.status() |> istaskstarted == true
    sleep(60)
    Scheduler.stop()

    # count temporary test files
    tmpfiles = @chain readdir(pwd()) begin
       filter(x -> startswith(x, "jl_"),_)
       isempty(_) ? 0 : length(_)
    end
    rmtemp()
    @test 1 <= tmpfiles <= 2
    @test Scheduler.status() |> istaskdone == true
end
