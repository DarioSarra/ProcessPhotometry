"""
`combine_bhv_log`
extract the events indexes from the log file and adds it to the Pokes files
"""

function combine_bhv_log(DataIndex::DataFrames.AbstractDataFrame)
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


"""
`combine_bhv_cam`
"""

function combine_bhv_cam(DataIndex::DataFrames.AbstractDataFrame)
    exp_dir = DataIndex[1,:Saving_path]
    exp_name = splitdir(exp_dir)[end]
    saving_path = joinpath(exp_dir,"photo_pokes_"*exp_name*".jld")
    cam_dict = save_cam_dict(DataIndex)
    rec = combine_bhv_log(DataIndex);
    pokes = @transform rec {Traces = colnames(cam_dict[:Session])}
    BSON.@save saving_path pokes
    return pokes, cam_dict
end
