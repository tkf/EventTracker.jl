module TestRecording

using EventTracker
using EventTracker: EVENT_INTERVAL, EVENT_POINT
using EventTrackerBase: LocationProxy, EventTrackerBase
using Test

function test_location_hack()
    swb = EventTrackerBase
    @test swb._check_location1() ===  swb._check_location1()::LocationProxy
    @test swb._check_location2() ===  swb._check_location2()::LocationProxy
    @test swb._check_location3() ===  swb._check_location3()::LocationProxy
    @test Base.PkgId(swb._check_location1()._module) === Base.PkgId(swb)
    @test swb._check_location1().tag === swb.NOTAG
    @test swb._check_location1().line.line + 1 == swb._check_location2().line.line
end

function record_once()
    ans = @recordinterval :record_once begin
        y = 1
    end
    return (ans, y)
end

function test_record_once()
    @test record_once() == (1, 1)
end

function no_tag()
    ans = @recordinterval y = 1
    return (ans, y)
end

function test_no_tag()
    @test no_tag() == (1, 1)
end

record_point_once() = @recordpoint

function test_record_point_once()
    @test record_point_once() === nothing
end

function test_record_in_spawn()
    tasks = map(1:10) do i
        Threads.@spawn begin
            ans = @recordinterval :record_in_spawn begin
                y = i * 10
            end
            return (ans, y)
        end
    end
    results = fetch.(tasks)
    @test first.(results) == (1:10) .* 10
    @test last.(results) == (1:10) .* 10
end

end  # module
