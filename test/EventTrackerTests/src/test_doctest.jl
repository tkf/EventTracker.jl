module TestDoctest

import EventTracker
import EventTrackerBase
using Documenter: doctest
using Test

function test_eventtracker()
    doctest(EventTracker; manual = false)
end

function test_eventtrackerbase()
    doctest(EventTrackerBase; manual = false)
end

end  # module
