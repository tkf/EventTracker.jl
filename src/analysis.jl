"""
    EventTracker.event_table()

Export tracked events as a table.
"""
EventTracker.event_table

"""
    EventTracker.location_table()

Export tracked locations as a table.
"""
EventTracker.location_table

"""
    EventTracker.event_dataframe(; owntime = false)

Export tracked events as a `DataFrame`. If `owntime = true` is passed, include
`owntime` column by analyzing the nesting of the intervals and compute the
during excluding the time spent in the sub-intervals.
"""
EventTracker.event_dataframe

"""
    EventTracker.location_dataframe()

Export tracked locations as a `DataFrame`.
"""
EventTracker.location_dataframe

EventTracker.event_table() = append_events!(StructVector{Event}(undef, 0))
EventTracker.location_table() = append_locations!(StructVector{Location}(undef, 0))

EventTracker.event_dataframe(; owntime::Bool = false) =
    _event_dataframe(EventTracker.event_table(), owntime)
EventTracker.location_dataframe() =
    DataFrame(EventTracker.location_table(); copycols = true)

function _event_dataframe(etbl, include_owntime::Bool, ltbl = nothing)
    edf = DataFrame(etbl; copycols = true)
    edf[!, :time] = (something.(edf.stop, missing) .- edf.start) ./ 1e9
    if include_owntime
        if ltbl === nothing
            ltbl = EventTracker.location_table()
        end
        stks = EventTracker.stacks(etbl, ltbl)
        event_to_owntime = owntime_dict(stks)
        edf[!, :owntime] = map(edf.eventid) do i
            v = get(event_to_owntime, i, nothing)
            v === nothing && return missing
            return v.owntime / 1e9
        end
    end
    return edf
end

function move_to_end!(cols, name)
    i = findfirst(==(name), cols)
    @assert i !== nothing
    deleteat!(cols, i)
    push!(cols, name)
end

"""
    EventTracker.summary_dataframe(; owntime = false)

Compute the summary of the events.

It computes the summary statistics of the events for each location and join the
location information.
"""
EventTracker.summary_dataframe
function EventTracker.summary_dataframe(; owntime::Bool = false, sortby = nothing)
    etbl = EventTracker.event_table()
    ltbl = EventTracker.location_table()
    edf = _event_dataframe(etbl, owntime, ltbl)
    ldf = DataFrame(ltbl; copycols = true)

    combine_spec = Pair[]
    append!(combine_spec, [
        :time => length => :ncalls,
        # average duration, including sub-calls:
        :time => mean => :time,
    ])
    if owntime
        push!(combine_spec, :owntime => mean => :owntime)
    end
    append!(
        combine_spec,
        [
            # sort by this to approximate call tree?
            :start => minimum => :firstcall,
            :eventkind => first => :eventkind,
        ],
    )
    summary_df = combine(groupby(edf, :locationid), combine_spec)
    summary_df = leftjoin(summary_df, ldf, on = :locationid)

    # Reorder columns so that important information comes first:
    cols = propertynames(summary_df)
    move_to_end!(cols, :firstcall)
    move_to_end!(cols, :eventkind)
    move_to_end!(cols, :locationid)
    summary_df = select!(summary_df, cols)

    if sortby !== nothing
        sort!(summary_df, sortby)
    end

    return summary_df
end

"""
    EventTracker.summary()

Compute and print the summary. Currently just pints
[`EventTracker.summary_dataframe`](@ref).
"""
EventTracker.summary
function EventTracker.summary(; kwargs...)
    summary_df = EventTracker.summary_dataframe(; kwargs...)
    display(summary_df)
end
