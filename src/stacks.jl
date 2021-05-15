# TODO: rename it to something since "Interval Tree" means a specific data structure.
# NestedIntervals? CallTree?
struct IntervalTree
    eventid::EventID
    branches::Union{Vector{IntervalTree},Nothing}
    height::Int  # TODO: maybe `level` is a better name (as its 0-origin)
end

IntervalTree(eventid::EventID) = IntervalTree(eventid, nothing, 0)

function IntervalTree(eventid::EventID, branches::Vector{IntervalTree})
    if isempty(branches)
        return IntervalTree(eventid)
    else
        return IntervalTree(eventid, branches, maximum(i -> i.height, branches) + 1)
    end
end

Base.:(==)(x::IntervalTree, y::IntervalTree) =
    isequal(x.eventid, y.eventid) &&
    isequal(x.height, y.height) &&
    isequal(x.branches, y.branches)

struct IntervalStacks
    trees::Vector{IntervalTree}
    points::Vector{EventID}
    events::Dict{EventID,Event}
    locations::Dict{UInt64,Location}
end

function interval_tree(etbl::AbstractVector{Event}, events::Dict{EventID,Event})
    intervals_data = StructVector(
        (
            approx_taskid = e.approx_taskid,
            eventid = e.eventid,
            start = e.start,
            stop = e.stop,
        ) for e in etbl if e.stop isa TimeNS
    )
    intervals_df = DataFrame(intervals_data; copycols = false)
    trees = IntervalTree[]
    for task in groupby(intervals_df, :approx_taskid)
        intervals = Tables.rowtable(task[:, [:eventid, :start, :stop]])
        sort!(intervals; by = i -> i.start)
        append!(trees, _interval_trees(intervals))
    end
    sort!(trees, by = t -> events[t.eventid].start)
    return trees
end

# Optimization ideas: It's straightforward to parallelize this.  Also, maybe
# galloping search is better than binary search.
function _interval_trees(intervals)
    length(intervals) == 1 && return [IntervalTree(intervals[1].eventid)]
    k1 = firstindex(intervals)
    trees = IntervalTree[]
    while true
        root = intervals[k1]
        offset = searchsortedlast(
            @view(intervals[k1:end]),
            (start = root.stop,),
            by = i -> i.start,
        )
        @assert offset > 0   # no time travel `start <= stop`
        k2 = k1 + offset - 1
        if offset == 1
            t = IntervalTree(root.eventid)
        else
            t = IntervalTree(root.eventid, _interval_trees(view(intervals, k1+1:k2)))
        end
        push!(trees, t)
        k2 == lastindex(intervals) && break
        k1 = k2 + 1
    end
    return trees
end

# [...](@ref EventTrackerBase.@recordinterval) didn't work somehow
"""
    EventTracker.stacks()

Analyze nestings of the recorded intervals to recover the "call trees" of the
functions instrumented with [`@recordinterval`](@ref
EventTracker.@recordinterval) macro.

Currently, the returned object only supports `Plots.plot` API.
"""
EventTracker.stacks
EventTracker.stacks() =
    EventTracker.stacks(EventTracker.event_table(), EventTracker.location_table())

function EventTracker.stacks(etbl::AbstractVector{Event}, ltbl::AbstractVector{Location})
    events = Dict{EventID,Event}(e.eventid => e for e in etbl)
    return IntervalStacks(
        interval_tree(etbl, events),
        EventID[e.eventid for e in etbl if e.eventkind === EVENT_POINT],
        events,
        Dict{UInt64,Location}(l.locationid => l for l in ltbl),
    )
end

function append_owntime!(table, stks::IntervalStacks)
    for tree in stks.trees
        append_owntime!(table, tree, stks.events)
    end
    return table
end

function duration_of(tree::IntervalTree, events::AbstractDict{EventID,Event})
    e = events[tree.eventid]
    return e.stop - e.start
end

function owntime_of(tree::IntervalTree, events::AbstractDict{EventID,Event})
    cumtime = duration_of(tree, events)
    tree.branches === nothing && return cumtime
    subtime = sum(tree.branches) do sub
        duration_of(sub, events)
    end
    return cumtime - subtime
end

function append_owntime!(table, tree::IntervalTree, events::AbstractDict{EventID,Event})
    push!(table, (eventid = tree.eventid, owntime = owntime_of(tree, events)))
    if tree.branches !== nothing
        for sub in tree.branches
            append_owntime!(table, sub, events)
        end
    end
    return table
end

const OwntimeAccumulatorDict = Dict{EventID,typeof((owntime = TimeNS(0), count = 0))}

struct OwntimeAccumulator
    dict::OwntimeAccumulatorDict
end
OwntimeAccumulator() = OwntimeAccumulator(OwntimeAccumulatorDict())

function Base.push!(acc::OwntimeAccumulator, row)
    dict, _ = modify!!(acc.dict, row.eventid) do entry
        if entry === nothing
            Some((owntime = row.owntime, count = 1))
        else
            v = something(entry)
            Some((owntime = row.owntime + v.owntime, count = v.count + 1))
        end
    end
    @assert dict === acc.dict
    return acc
end

function owntime_dict(stks::IntervalStacks)
    acc = append_owntime!(OwntimeAccumulator(), stks)
    return acc.dict
end

