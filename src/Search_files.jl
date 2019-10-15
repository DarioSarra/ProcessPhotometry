"""
'create_cam_DataIndex'
given the path of the folder containing the Camera files create a DataFrame
with the session informations
"""

function create_cam_DataIndex(Camera_path::String)
    camera = DataFrame(Cam_Path = get_data(Camera_path,:cam))
    camera[:Cam_Session] = [split(t,"/")[end] for t in camera[:Cam_Path]]
    #extract date and mouse ID per session using get_mousedate (it works with a full path)
    # compose logAI file name from mat file
    camera[:Log_Session]=[replace(f, ".mat"=>"_logAI.csv") for f in camera[:Cam_Session]];
    camera[:Log_Path]=[replace(f, ".mat"=>"_logAI.csv") for f in camera[:Cam_Path]];
    #Identifies information from file name using get_mousedate function in a for loop
    camera[:MouseID] = String.([split(t,"_")[1] for t in camera[:Cam_Session]])
    camera[:Area] = String.([split(t,"_")[2] for t in camera[:Cam_Session]])
    camera[:Day] = String.([match.(r"\d{8}",t).match for t in camera[:Cam_Path]])
    dformat = Dates.DateFormat("yyyymmdd")
    camera[:Day] = Date.(camera[:Day],dformat)
    camera[:Period] = String.([match.(r"[a-z]{1}",t).match for t in camera[:Cam_Session]])
    return camera
end

"""
'create_photometry_DataIndex'
given the path of the folder containing the Camera files create a DataFrame
with the session informations
"""

function create_photometry_DataIndex(Directory_path::String, Exp_type::String,
    Exp_name::String, Mice_suffix::String; bad_days = Date(2014-01-01):Day(1):Date(2014-01-02); run_task = "run_task_photo")

    Camera_path = joinpath(Directory_path,run_task,Exp_name,"Cam")
    Behavior_path = joinpath(Directory_path,run_task,"raw_data")
    saving_path = joinpath(Directory_path,"Datasets",Exp_type,Exp_name)

    camera = create_cam_DataIndex(Camera_path)

    exp_days = minimum(camera[:Day]):Day(1):maximum(camera[:Day])
    good_days = [day for day in exp_days if ! (day in bad_days)];
    camera=camera[[(d in good_days) for d in camera[:Day]],:];

    behavior = Flipping.find_behavior(Directory_path, Exp_type,Exp_name, Mice_suffix)
    DataFrames.rename!(behavior,:Session=>:Bhv_Session)
    dformat = Dates.DateFormat("yyyymmdd")
    behavior[:Day] = Date.(behavior[:Day],dformat)
    behavior = behavior[[(bho in good_days) for bho in behavior[:Day]],:];

    println("accordance between cam and behavior dates");
    println(sort(union(behavior[:Day])) == sort(union(camera[:Day])));
    if sort(union(behavior[:Day])) != sort(union(camera[:Day]))
        println(symdiff(sort(union(camera[:Day])),sort(union(behavior[:Day]))))
    end

    DataIndex = join(camera, behavior, on = [:MouseID, :Day, :Period], kind = :inner, makeunique = true)
    DataIndex[:Saving_path] = saving_path
    DataIndex[:Exp_Path]= replace(Camera_path,"Cam/"=>"")
    DataIndex[:Exp_Name]= String(split(DataIndex[1,:Exp_Path],"/")[end-1])
    DataIndex[:Session] = [replace(t,".csv"=>"") for t in DataIndex[:Bhv_Session]]
    return DataIndex
end
