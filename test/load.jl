try
    using EventTrackerTests
    true
catch
    false
end || begin
    push!(LOAD_PATH, joinpath(@__DIR__, "EventTrackerTests"))
    using EventTrackerTests
end
