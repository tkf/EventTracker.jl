module _Plots
using Requires: @require

abstract type AbstractShimFunction{name} <: Function end
(::AbstractShimFunction)(_args...; _kwargs...) = error("please import Plots")

struct ShimFunction{name} <: AbstractShimFunction{name} end

macro shim(name::Symbol)
    esc(:(const $name = ShimFunction{$(QuoteNode(name))}()))
end

@shim grid

function __init__()
    @require Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80" begin
        (::ShimFunction{name})(args...; kwargs...) where {name} =
            getfield(Plots, name)(args...; kwargs...)
    end
end

end  # module _Plots


struct IntervalsPlotter
    stks::IntervalStacks
end

struct PointsPlotter
    stks::IntervalStacks
end


@recipe function _(stks::IntervalStacks)
    link := :x
    layout := _Plots.grid(2, 1; heights = [0.9, 0.1])

    @series begin
        subplot := 1
        IntervalsPlotter(stks)
    end

    @series begin
        subplot := 2
        yguide --> "Pt."
        PointsPlotter(stks)
    end
end

function time_converter(stks::IntervalStacks)
    t0 = time_ns()
    if !isempty(stks.trees)
        t0 = stks.events[stks.trees[1].eventid].start
    end
    astime(t) = (t - t0) / 1e9
    return astime
end

@recipe function _(pltr::IntervalsPlotter)
    stks = pltr.stks

    data = plot_data(stks)
    for (x, y, c) in zip(data.xs, data.ys, data.cs)
        # y = y .+ (rand() .- 0.5)
        @series begin
            seriestype := :line
            x := x
            y := y
            fillrange := y[1] + 1
            fillcolor := c
            linecolor := :white
            # linestyle := :dot
            # linewidth := 4
            label := nothing
            ()
        end
    end
    @series begin
        seriestype := :scatter
        x := data.root.xs
        y := data.root.ys
        # markersize := 2
        # markershape := :x
        markercolor := :white
        markerstrokecolor := :black
        label := nothing
        ()
    end

    @series begin
        yguide --> "Intervals"
        label := nothing
        ()
    end
end

@recipe function _(pltr::PointsPlotter)
    stks = pltr.stks
    astime = time_converter(stks)
    times = [astime(stks.events[i].start) for i in stks.points]

    seriestype := :vline
    y := times
    xguide --> "Time [Sec]"
    yguide --> "Points"
    yticks := nothing
    label --> nothing
    ()
end


function plot_data(stks::IntervalStacks)
    astime = time_converter(stks)

    # TODO: use matrix?
    xs = Vector{Float64}[]
    ys = Vector{Float64}[]
    cs = Int[]
    data = (; xs = xs, ys = ys, cs = cs, root = (; xs = Float64[], ys = Float64[]))

    colormap = Dict{UInt64,Int}()
    function getcolor(event)
        # k = hash(event.approx_taskid, event.locationid)
        # k = event.locationid
        k = event.approx_taskid
        get!(colormap, k) do
            length(colormap) + 1
        end
    end

    function add(tree, y0)
        event = stks.events[tree.eventid]
        color = getcolor(event)
        start = astime(event.start)
        stop = astime(event.stop)
        push!(xs, [start, stop])
        push!(ys, [y0, y0])
        push!(cs, color)
        tree.branches === nothing && return
        for b in tree.branches
            add(b, y0 + 1)
        end
    end

    # Edges of the "staircase":
    rights = TimeNS[typemin(TimeNS)]
    tops = Int[0]
    # h = 0
    for tree in stks.trees
        # add(tree, h)
        # h += tree.height + 2
        # continue

        # @show rights, tops
        event = stks.events[tree.eventid]
        i = searchsortedlast(rights, event.start)
        if tree.height + 2 < tops[i]
            y0 = 0
            j = searchsortedfirst(rights, event.stop)
            if j > length(rights)
                tops[j-1] = tree.height + 2
            end
            rights[j-1] = event.stop
            deleteat!(rights, 2:j-2)
            deleteat!(tops, 2:j-2)
            # @show isnothing(tree.branches), astime(event.start), astime(event.stop)
        else
            y0 = tops[end]
            if event.stop < rights[end]
                tops[end] += tree.height + 2
            else
                push!(rights, event.stop)
                push!(tops, tops[end] + tree.height + 2)
            end
        end
        add(tree, y0)
        push!(data.root.xs, astime(event.start))
        push!(data.root.ys, y0)
    end

    return data
end
