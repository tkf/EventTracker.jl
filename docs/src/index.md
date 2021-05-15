# EventTracker.jl

See [Gallery](@ref) for examples.

## Recording API

Recording API is defined in EventTrackerBase.jl and re-exported from
EventTracker.jl.

```@docs
EventTrackerBase.@recordinterval
EventTrackerBase.@recordpoint
EventTrackerBase.clear
```

## Analysis API

```@docs
EventTracker.summary
EventTracker.summary_dataframe
EventTracker.event_dataframe
EventTracker.event_table
EventTracker.location_dataframe
EventTracker.location_table
EventTracker.stacks
```
