module TestStacks

using EventTracker.Implementations: EventID, IntervalTree, _interval_trees
using Test

const IntervalEntry = NamedTuple{(:eventid, :start, :stop),Tuple{EventID,Int64,Int64}}

function example_itnerval_trees()
    prev = Ref(UInt64(0))
    iota() = EventID(prev[] += 1)
    interval_data = [
        (iota(), 555_0000_000, 555_0000_100),
        (iota(), 555_0000_001, 555_0000_010),
        (iota(), 555_0000_002, 555_0000_003),
        (iota(), 555_0000_004, 555_0000_005),
        (iota(), 555_0000_006, 555_0000_009),
        (iota(), 555_0000_007, 555_0000_008),
        (iota(), 555_0000_020, 555_0000_099),
        (iota(), 555_0000_021, 555_0000_098),
        (iota(), 555_0000_022, 555_0000_097),
        (iota(), 555_0000_023, 555_0000_096),
    ]
    intervals = IntervalEntry.(interval_data)
    return _interval_trees(intervals)
end

function test_example()
    expected = [
        IntervalTree(
            EventID(0x001),
            [
                IntervalTree(
                    EventID(0x002),
                    [
                        IntervalTree(EventID(0x003), nothing, 0),
                        IntervalTree(EventID(0x004), nothing, 0),
                        IntervalTree(
                            EventID(0x005),
                            [IntervalTree(EventID(0x006), nothing, 0)],
                            1,
                        ),
                    ],
                    2,
                ),
                IntervalTree(
                    EventID(0x007),
                    [
                        IntervalTree(
                            EventID(0x008),
                            [
                                IntervalTree(
                                    EventID(0x009),
                                    [IntervalTree(EventID(0x00a), nothing, 0)],
                                    1,
                                ),
                            ],
                            2,
                        ),
                    ],
                    3,
                ),
            ],
            4,
        ),
    ]
    @test example_itnerval_trees() == expected
end

function withcontext(block)
    previd = Ref(UInt64(0))
    prevtime = Ref(0)
    newid() = EventID(previd[] += 1)
    newtime() = prevtime[] += 1
    intervals = IntervalEntry[]
    stack = [IntervalTree(EventID(0), [], -1)]

    function apply(f, args...; kwargs...)
        # Recording an interval
        eventid = newid()
        start = newtime()
        begin
            # Recording a frame in a stack
            push!(stack, IntervalTree(eventid, [], -1))
            begin
                y = f(apply, args...; kwargs...)
            end
            tree = pop!(stack)
            push!(stack[end].branches, IntervalTree(eventid, tree.branches))
        end
        stop = newtime()
        push!(intervals, (eventid = eventid, start = start, stop = stop))

        return y
    end

    let y = block(apply)
        @assert length(stack) == 1
        sort!(intervals; by = i -> i.start)
        return intervals, stack[end].branches, y
    end
end

just_apply(f, args...; kwargs...) = f(just_apply, args...; kwargs...)

function fib(apply, n)
    n <= 1 && return n
    a = apply(fib, n - 1)
    b = apply(fib, n - 2)
    return a + b
end

tarai(apply, x, y, z) =
    if y < x
        apply(
            tarai,
            apply(tarai, x - 1, y, z),
            apply(tarai, y - 1, z, x),
            apply(tarai, z - 1, x, y),
        )
    else
        y
    end

generate_fib(n) = withcontext(apply -> apply(fib, n))
generate_tarai(x, y, z) = withcontext(apply -> apply(tarai, x, y, z))


function test_fib(n)
    intervals, trees, result = generate_fib(n)
    @test result == just_apply(fib, n)
    @test _interval_trees(intervals) == trees
end

function test_fib()
    @testset for n in 0:10
        test_fib(n)
    end
end

function test_tarai(x, y, z)
    intervals, trees, result = generate_tarai(x, y, z)
    @test result == just_apply(tarai, x, y, z)
    @test _interval_trees(intervals) == trees
end

function test_tarai()
    @testset for x in 2:4
        test_tarai(x, 1, 10)
    end
end

end  # module
