module EventTrackerBase

export @recordinterval, @recordpoint

using RecordArrays: RecordArrays, RecordVector

include("BlockLinkedLists.jl")
using .BlockLinkedLists: BlockLinkedList, alloclast!

include("recording.jl")
include("tables.jl")

function __init__()
    init_event_ids!()
    init_interval_record_stores!()
end

end
