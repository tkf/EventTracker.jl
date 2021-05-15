module BlockLinkedLists

mutable struct Node{Block}
    block::Block
    i::Int
    prev::Union{Nothing,Node{Block}}
    next::Union{Nothing,Node{Block}}
end

mutable struct BlockLinkedList{T,Block<:AbstractVector{T},Constructor}
    constructor::Constructor
    blocksize::Int
    head::Node{Block}
    tail::Node{Block}
end

_typeof(::T) where {T} = T
_typeof(::Type{T}) where {T} = Type{T}

function BlockLinkedList(constructor, blocksize::Integer)
    block = constructor(undef, blocksize)
    node = Node(block, firstindex(block), nothing, nothing)
    return BlockLinkedList{eltype(block),typeof(block),_typeof(constructor)}(
        constructor,
        blocksize,
        node,
        node,
    )
end

"""
    alloclast!(list::BlockLinkedList{T}) -> reference::AbstractArray{T,0}

Allocate one element at the end of the `list` and return the `reference` to it
as a 0-dimensional vector.
"""
function alloclast!(lst::BlockLinkedList)
    node = lst.tail
    i = node.i
    if i <= lastindex(node.block)
        block = node.block
        node.i = i + 1
    else
        block = lst.constructor(undef, lst.blocksize)
        i = firstindex(block)
        prev = node
        node = Node(block, i + 1, prev, nothing)
        prev.next = node
        lst.tail = node
    end
    return view(block, i)
end

function Base.push!(lst::BlockLinkedList{T}, x) where {T}
    x = convert(T, x)
    ref = alloclast!(lst)
    ref[] = x
    return lst
end

Base.eltype(::Type{<:BlockLinkedList{T}}) where {T} = T
Base.IteratorEltype(::Type{<:BlockLinkedList}) = Base.HasEltype()
Base.IteratorSize(::Type{<:BlockLinkedList}) = Base.SizeUnknown()

function Base.iterate(lst::BlockLinkedList)
    return iterate(lst, (lst.head, firstindex(lst.head.block), lst.head.i))
end

function Base.iterate(::BlockLinkedList, (node, j, i))
    if j == i
        node = node.next
        node === nothing && return nothing
        j = firstindex(node.block)
        i = node.i
        j == i && return nothing
    end
    return (node.block[j], (node, j + 1, i))
end

end  # module
