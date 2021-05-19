using Documenter
using EventTracker
using EventTrackerBase

makedocs(
    sitename = "EventTracker",
    format = Documenter.HTML(),
    modules = [EventTracker, EventTrackerBase],
    checkdocs = :export,  # `:all` contains many false-positives
    strict = true,
)

deploydocs(
    repo = "github.com/tkf/EventTracker.jl",
    push_preview = true,
)
