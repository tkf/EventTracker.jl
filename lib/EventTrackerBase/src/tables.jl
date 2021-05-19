@enum EventKind EVENT_INTERVAL EVENT_POINT

struct EventID
    value::UInt64
end

# TODO: wrap?
const LocationID = UInt64

struct Event
    eventkind::EventKind
    # RawEventID
    eventid::EventID  # mixing localid + threadid
    threadid::typeof(Threads.threadid())
    # LocationProxy
    locationid::UInt64
    # IntervalRecord
    approx_taskid::UInt
    start::TimeNS
    stop::Union{TimeNS,Nothing,Missing}
end

struct Location
    # LocationProxy
    locationid::UInt64
    tag::Union{Symbol,Nothing}
    line::Int
    file::Union{Symbol,Nothing}
    _module::Module
end

event_table() = append_events!(Event[])

location_table() = append_locations!(Location[])

function foreach_event(f, record_stores = INTERVAL_RECORD_STORES)
    for records in record_stores
        node = records.head
        block = node.block
        while true
            bound = node.i - 1
            node = node.next
            if node === nothing
                for i in 1:bound
                    x = @inbounds block[i]
                    f(x)
                end
                break
            end
            for i in eachindex(block)
                x = @inbounds block[i]
                f(x)
            end
            block = node.block
        end
    end
end

function eventkind_from_stop(stop::TimeNS)
    if stop === TIME_NOT_AVAILABLE
        return EVENT_POINT
    else
        return EVENT_INTERVAL
    end
end

EventKind(record::IntervalRecord) = eventkind_from_stop(record.stop)

# TODO: is it better to do this inside RawEventID (and get rid of it)?
function EventID(event::RawEventID)
    threadid = event.threadid
    localid = event.localid
    upper = bswap(UInt64(threadid - 1))
    lower = localid % UInt64
    return EventID(upper | lower)
end

function Event(record::IntervalRecord)
    Event(
        EventKind(record),
        EventID(record.event),
        record.event.threadid,
        record.location,
        record.approx_taskid,
        record.start,
        interpret_time(record.stop),
    )
end

function append_events!(table)
    foreach_event() do x
        push!(table, Event(x))
    end
    return table
end

function Location(record::IntervalRecord)
    local location
    GC.@preserve LOCATIONS_ROOT let uints
        uints = unsafe_wrap(Array, Ptr{UInt}(pointer(LOCATIONS_ROOT)), size(LOCATIONS_ROOT))
        # @assert record.location in uints
        location = unsafe_pointer_to_objref(Ptr{Cvoid}(record.location))::LocationProxy
    end
    return Location(
        record.location,
        location.tag === NOTAG ? nothing : location.tag,
        location.line.line,
        location.line.file,
        location._module,
    )
end

"""
    EventTracker.append_locations!(table)
"""
function append_locations!(table)
    seen = Set{UInt}()
    foreach_event() do record::IntervalRecord
        n0 = length(seen)
        push!(seen, record.location)
        n0 == length(seen) && return  # a bit faster than `in`
        push!(table, Location(record))
    end
    return table
end
