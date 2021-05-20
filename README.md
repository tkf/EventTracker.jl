# EventTracker

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://tkf.github.io/EventTracker.jl/dev)
[![GitHub Actions](https://github.com/tkf/EventTracker.jl/workflows/Run%20tests/badge.svg)](https://github.com/tkf/EventTracker.jl/actions?query=workflow%3ARun+tests)

EventTracker.jl is like
[TimerOutputs.jl](https://github.com/KristofferC/TimerOutputs.jl) but designed
to track all individual timings (events) in a thread-friendly manner.  It
supports exporting the measurements as accessible data formats from standard
data analysis packages such as DataFrames.jl and Tables.jl.  It is useful for
implementing custom performance analysis tool.

## Example

```julia
julia> using EventTracker

julia> function counter(n)
           if n > 0
               @recordinterval counter(n-1)
            else
               @recordpoint
               println("done!")
            end
       end;

julia> counter(11)
done!
```

``````julia
julia> df = EventTracker.summary_dataframe()
2×9 DataFrame
 Row │ ncalls  time              tag      line    file     _module  firstcall          eventkind       locationid
     │ Int64   Float64?          Union…?  Int64?  Union…?  Module?  UInt64             EventKin…       UInt64
─────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │     11        6.01317e-5                3  REPL[2]  Main     17718374492314440  EVENT_INTERVAL  139675751155888
   2 │      1  missing                         5  REPL[2]  Main     17718374492316350  EVENT_POINT     139675753020864
``````

## See also:

* [Profiling · The Julia Language](https://docs.julialang.org/en/v1/manual/profile/)
* [StopWatches.jl](https://github.com/tkf/StopWatches.jl):
   Simple intrusive time measurements
* [TimerOutputs.jl](https://github.com/KristofferC/TimerOutputs.jl):
  Formatted output of timed sections in Julia.
* [JuliaPerf/*.jl](https://github.com/JuliaPerf)
