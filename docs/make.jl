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

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#
