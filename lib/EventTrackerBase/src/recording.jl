const TimeNS = typeof(time_ns())
const TIME_NOT_AVAILABLE = typemax(TimeNS)
const TIME_MISSING = TIME_NOT_AVAILABLE - 1
# TODO: use a wrapper type instead of the manual sentinel values

@inline function interpret_time(x::TimeNS)
    if x === TIME_NOT_AVAILABLE
        return nothing
    elseif x === TIME_MISSING
        return missing
    else
        return x
    end
end

const NOTAG = Symbol("")

"""
A mutable object whose identity (pointer) identifies a location.
"""
mutable struct LocationProxy
    line::LineNumberNode
    _module::Module
    tag::Symbol
end

macro location()
    QuoteNode(LocationProxy(__source__, __module__, NOTAG))
end

# Used in test:
_check_location1() = @location
_check_location2() = @location
_check_location3() = @location

event_id_counters(n = Threads.nthreads()) = RecordArrays.unsafe_zeros(UInt, n)

const EVENT_IDS_REF = Ref{typeof(event_id_counters())}()

function init_event_ids!()
    EVENT_IDS_REF[] = event_id_counters()
end

init_event_ids!()
atexit() do
    EVENT_IDS_REF[] = event_id_counters(0)
end

@inline event_id_ref(tid) = view(EVENT_IDS_REF[], tid)

struct RawEventID
    threadid::typeof(Threads.threadid())
    localid::UInt
end

function event_id()
    tid = Threads.threadid()
    ref = event_id_ref(tid)
    lid = ref[] += 1
    return RawEventID(tid, lid)
end

struct IntervalRecord
    location::UInt
    event::RawEventID
    approx_taskid::UInt
    start::TimeNS
    stop::TimeNS
end
# TODO: move `tag` here (requires GC object support in RecordArrays)

function interval_record_stores(blocksize = 2^8)
    BlockLinkedList(RecordVector{IntervalRecord}, blocksize)
end

const INTERVAL_RECORD_STORES = typeof(interval_record_stores())[]

function init_interval_record_stores!()
    empty!(INTERVAL_RECORD_STORES)
    append!(
        INTERVAL_RECORD_STORES,
        (interval_record_stores() for _ in 1:Threads.nthreads()),
    )
end

init_interval_record_stores!()
atexit() do
    empty!(INTERVAL_RECORD_STORES)
end

function interval_begin(location, event)
    handle = alloclast!(INTERVAL_RECORD_STORES[Threads.threadid()])
    handle.location[] = UInt(pointer_from_objref(location))
    handle.event[] = event
    handle.approx_taskid[] = UInt(pointer_from_objref(current_task()))
    handle.start[] = time_ns()
    handle.stop[] = TIME_MISSING
    return handle
end
# `approx_taskid` is only an approximation of task identity since the same
# memory location can be reused. Note that `objectid` has the same problem (and
# also a few ns slower).

function interval_end!(handle)
    handle.stop[] = time_ns()
end

function _record_point(location, event)
    handle = interval_begin(location, event)
    handle.stop[] = TIME_NOT_AVAILABLE
    return handle
end

const RawHandle = let
    location = @location
    event = event_id()
    handle = interval_begin(location, event)
    typeof(handle)
end

"""
    @recordinterval(tag, code) -> handle
    @recordinterval(code) -> handle

Record the start and stop times for executing `code`.

`tag` must be a literal symbol; i.e., `@recordinterval :my_tag ...` instead of
`@recordinterval my_tag ...`.

# Examples

```jldoctest
julia> using EventTrackerBase

julia> @recordinterval begin
           sleep(0.01)
           a = 1
       end;

julia> a
1
```

The timing can now be printed with `using EventTracker` then
`EventTracker.summary()`.
"""
macro recordinterval(tag::QuoteNode, code)
    tag.value isa Symbol || error("`tag` must be a symbol; got: $(tag.value)")
    return recordinterval_impl(__source__, __module__, tag.value, code)
end

macro recordinterval(code)
    return recordinterval_impl(__source__, __module__, NOTAG, code)
end

macro recordinterval(tag::Symbol, code)
    error("use `@recordinterval :$tag ...`")
end

"""
    @recordpoint(tag) -> handle
    @recordpoint() -> handle

Record the times this part of code is executed.
"""
macro recordpoint(tag::QuoteNode)
    tag.value isa Symbol || error("`tag` must be a symbol; got: $(tag.value)")
    return recordpoint_impl(__source__, __module__, tag.value)
end

macro recordpoint()
    return recordpoint_impl(__source__, __module__, NOTAG)
end

macro recordpoint(tag::Symbol)
    error("use `@recordpoint :$tag`")
end


struct RecordHandle
    __handle::RawHandle
    __location::LocationProxy
    __event::RawEventID
end

# Rooting is probably unnecessary and is done by the compiler automatically
# already. But maybe it's also nice to iterate over instrumented locations
# anyway?
# (TODO: Iteration over instrumented location won't work for precompiled
# locations. It's possible to support it by injecting `__init__` function that
# populates `LOCATIONS_ROOT` upon import.)
const LOCATIONS_ROOT = LocationProxy[]

function recordinterval_impl(__source__, __module__, tag::Symbol, code)
    # Injecting `location` objection in the AST so that the compiler will root
    # it (I guess?).
    location = LocationProxy(__source__, __module__, tag)
    # So, this is probably not needed (but see above):
    push!(LOCATIONS_ROOT, location)
    return quote
        local location = $(QuoteNode(location))
        local event = $event_id()
        local handle = $interval_begin(location, event)
        $(esc(Expr(:block, __source__, code)))
        $interval_end!(handle)
        $RecordHandle(handle, location, event)
    end
end

function recordpoint_impl(__source__, __module__, tag::Symbol)
    location = LocationProxy(__source__, __module__, tag)
    push!(LOCATIONS_ROOT, location)
    return quote
        local location = $(QuoteNode(location))
        local event = $event_id()
        local handle = $_record_point(location, event)
        $RecordHandle(handle, location, event)
    end
end

"""
    EventTracker.clear()

Clear all records. The caller must ensure that no recordings are happening
concurrently.
"""
function clear()
    init_interval_record_stores!()
    return
end
