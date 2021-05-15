module TestAnalysis

using EventTracker
using Plots
using Test

function test_smoke()
    @test EventTracker.summary_dataframe() isa Any
    stks = EventTracker.stacks()
    @test show(devnull, "image/png", plot(stks)) isa Any
end

end  # module
