"""
`combine_bhv_log`
extract the events indexes from the log file and adds it to the Pokes files
"""

function combine_bhv_log(DataIndex)
    rec = table()
    for idx in 1:size(DataIndex,2)
        pokes = table(process_pokes(DataIndex[idx,:Bhv_Path]))
        events = observe_events(DataIndex[idx,:Log_Path])
        if length(pokes) == length(events)
            ongoing = join(pokes,events, lkey=:Poke, rkey = :Poke)
            if isempty(rec)
                rec = ongoing
            else
                rec = merge(rec, ongoing)
            end
        else
            println("mismatch: Pokes = $(length(pokes)) and Events = $(length(events)) session = $(DataIndex[idx, :Session])")
            continue
        end
    end
    return rec
end
