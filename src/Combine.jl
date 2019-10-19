"""
`combine_bhv_log`
extract the events indexes from the log file and adds it to the Pokes files
"""

function combine_bhv_photo(DataIndex::DataFrames.AbstractDataFrame)
    rec = table()
    cam_dict = OrderedDict()
    for idx in 1:size(DataIndex,1)
        try
            pokes = table(Flipping.process_pokes(DataIndex[idx,:Bhv_Path]))
            events = observe_events(DataIndex[idx,:Log_Path])
            cam_session, framerate = adjust_matfile(DataIndex[idx,:Cam_Path])
            if length(pokes) == length(events)
                ongoing = join(pokes,events, lkey=:Poke, rkey = :Poke)#add indexes of In and Out
                #calculate how much to trim form the camera
                trim = range(Int64(ongoing[1].In - 2*framerate),step=1,stop = Int64(ongoing[end].Out+2*framerate))
                #correct In and Out for the trimming of the data
                ongoing = @apply ongoing begin
                    @transform  {In = :In - trim.start}
                    @transform  {Out = :Out - trim.start}
                end
                cam_session = cam_session[trim]
                cam_dict[DataIndex[idx,:Session]] = cam_session
                if isempty(rec)
                    rec = ongoing
                else
                    rec = merge(rec, ongoing)
                end
            else
                println("mismatch: Pokes = $(length(pokes)) and Events = $(length(events)) session = $(DataIndex[idx, :Session])")
                continue
            end
        catch e
            println("some error in $(DataIndex[idx,:Session])")
            #println(sprint(showerror, e))
        end
    end
    c = @transform_vec rec {Exp_Day = ProcessPhotometry.calendar(:Day)}
    cc = @apply c :Protocol flatten = true begin
         @transform_vec {Protocol_Day = calendar(:Day)}
     end
    return cc, cam_dict
end


"""
`save_bhv_photo`
"""

function save_bhv_photo(DataIndex::DataFrames.AbstractDataFrame)
    exp_dir = DataIndex[1,:Saving_Path]
    exp_name = splitdir(exp_dir)[end]

    pokes, cam_dict = combine_bhv_photo(DataIndex);
    saving_path = joinpath(exp_dir,"pokes_"*exp_name*".jld")
    BSON.@save saving_path pokes
    filetosave = joinpath(exp_dir,"pokes_"*exp_name*".csv")
    CSVFiles.save(filetosave,pokes)

    streaks = table(ProcessPhotometry.photo_streak(DataFrame(pokes)));
    dayly_vars_list = [:MouseID, :Gen, :Drug, :Day, :Daily_Session, :Box, :Stim_Day, :Condition, :Exp_Day,:Protocol_Day, :Area];
    session_vars = Flipping.by_summary(pokes,:Session,dayly_vars_list);
    streaks = join(streaks,session_vars;lkey = :Session, rkey = :Session)
    BSON.@save saving_path streaks
    simple = JuliaDB.select(streaks,JuliaDB.Not(:PokeSequence))
    filetosave = joinpath(exp_dir,"streaks_"*exp_name*".csv")
    CSVFiles.save(filetosave,simple)

    name_list = Vector{Symbol}(undef,0)
    for x in keys(cam_dict)
        ongoing = colnames(cam_dict[x])
        append!(name_list,ongoing)
    end
    cam_dict["trace_list"] = union(name_list)
    saving_path = joinpath(exp_dir,"cam_"*exp_name*".jld")
    BSON.@save saving_path cam_dict

    return pokes, streaks, cam_dict
end
