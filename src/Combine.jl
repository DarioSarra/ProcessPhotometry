"""
`combine_bhv_log`
extract the events indexes from the log file and adds it to the Pokes files
"""

function combine_bhv_photo(DataIndex::DataFrames.AbstractDataFrame)
    rec = table()
    for idx in 1:size(DataIndex,2)
        pokes = table(process_pokes(DataIndex[idx,:Bhv_Path]))
        events = observe_events(DataIndex[idx,:Log_Path])
        cam_session, framerate = adjust_matfile(DataIndex[idx,:Cam_Path])
        trim = pokes[1,:In]-1*framerate:pokes[end,:Out]+1*framerate
        cam_session = cam_session[trim,:]
        cam_dict = OrderedDict(DataIndex[idx,:Session] => cam_session)
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
    return rec, cam_dict
end


"""
`combine_bhv_cam`
"""

function save_bhv_photo(DataIndex::DataFrames.AbstractDataFrame)
    exp_dir = DataIndex[1,:Saving_path]
    exp_name = splitdir(exp_dir)[end]
    saving_path = joinpath(exp_dir,"photo_pokes_"*exp_name*".jld")
    rec, cam_dict = combine_bhv_photo(DataIndex);
    #pokes = @transform rec {Traces = colnames(cam_dict[:Session])}
    BSON.@save saving_path pokes
    saving_path = joinpath(exp_dir,"cam"*exp_name*".jld")
    BSON.@save saving_path cam_dict
    return pokes, cam_dict
end
