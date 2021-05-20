baremodule EventTracker

export @recordinterval, @recordpoint

using EventTrackerBase:
    @recordinterval,
    @recordpoint,
    EVENT_INTERVAL,
    EVENT_POINT,
    Event,
    EventKind,
    Location,
    append_events!,
    append_locations!,
    clear

function summary end
function summary_dataframe end

function event_table end
function event_dataframe end
function location_table end
function location_dataframe end

function stacks end

module Implementations

using BangBang.Extras: modify!!
using DataFrames: DataFrame, combine, groupby, select!, Not, leftjoin
using RecipesBase: RecipesBase, @recipe, @series
using Statistics: mean
using StructArrays: StructVector
using Tables: Tables

using EventTrackerBase:
    EVENT_INTERVAL,
    EVENT_POINT,
    Event,
    EventID,
    Location,
    LocationID,
    TimeNS,
    append_events!,
    append_locations!

using ..EventTracker: EventTracker

include("utils.jl")
include("analysis.jl")
include("stacks.jl")
include("plots.jl")

end

Implementations.define_docstrings()

end  # module
