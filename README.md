# EventTracker

EventTracker.jl is like
[TimerOutputs.jl](https://github.com/KristofferC/TimerOutputs.jl) but designed
to track all individual timings (events) in a thread-friendly manner.  It
supports exporting data as accessible data formats from common packages
DataFrames.jl and Tables.jl.  It is useful for implementing custom performance
analysis tool.
