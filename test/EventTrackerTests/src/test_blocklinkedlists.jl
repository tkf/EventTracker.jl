module TestBlockLinkedLists

using EventTrackerBase.BlockLinkedLists: BlockLinkedList, alloclast!
using Test

function test_push_collect(xs)
    lst = foldl(push!, xs; init = BlockLinkedList(Vector{eltype(xs)}, 4))
    @test collect(lst) == collect(xs)
end

function test_push_collect()
    @testset "$label" for (label, xs) in [
        "1:3" => 1:3,
        "1:8" => 1:8,
        "1:9" => 1:9,
        "1:10" => 1:10,
        "a-to-z" => sprint(io -> foreach(x -> print(io, x), 'a':'z')),
    ]
        test_push_collect(xs)
    end
end

end  # module
