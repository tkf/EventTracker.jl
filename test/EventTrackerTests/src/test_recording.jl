module TestRecording

using EventTracker
using EventTracker: EVENT_INTERVAL, EVENT_POINT, EventKind
using EventTrackerBase: LocationProxy, RecordHandle, EventTrackerBase
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
    handle = @recordinterval :record_once begin
        y = 1
    end
    return y, handle
end

function test_record_once()
    y, handle = record_once()
    @test y == 1
    @test handle isa RecordHandle
    @test EventKind(handle) === EVENT_INTERVAL
end

function no_tag()
    handle = @recordinterval y = 1
    return y, handle
end

function test_no_tag()
    y, handle = no_tag()
    @test y == 1
    @test handle isa RecordHandle
end

record_point_once() = @recordpoint

function test_record_point_once()
    handle = record_point_once()
    @test handle isa RecordHandle
    @test EventKind(handle) === EVENT_POINT
end

function test_record_in_spawn()
    tasks = map(1:10) do i
        Threads.@spawn begin
            handle = @recordinterval :record_in_spawn begin
                y = i * 10
            end
            return (y == i * 10), handle
        end
    end
    results = fetch.(tasks)
    @test all(first, results)
    @test all(handle isa RecordHandle for (_, handle) in results)
end

end  # module
