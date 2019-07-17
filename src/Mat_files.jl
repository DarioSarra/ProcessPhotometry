"""
`erase_bumps`
use a derivative to correct unnatural change of signal due to fibre move
"""

function erase_bumps(vec::Array{Float64,1}; error = 5, start = 1)
    diff = vec - lag(vec,default = NaN)
    limit = error*NaNMath.std(diff[start:end])
    diff_filtered = [-limit < val < limit ? val : 0.0 for val in diff]
    vec_smooth = cumsum(diff_filtered)
    vec_smooth = vec_smooth .+ mean(vec) .- mean(vec_smooth)
    return vec_smooth
end



"""
`adjust_matfile`
read a matlab file from the photometry set up and turn it in a DataFrame
adjusting the fiber names
"""
function adjust_matfile(mat_filepath)
    #matvars read structures as a dictionary
    matvars = matread(mat_filepath);
    #since the camera alternates on 2 channels the frame rate is actually half
    framerate = (matvars["framerate"])/2;
    #this labels are set at the moment of the acquisition
    labels = vec(matvars["labels"]);
    #DataFrame is the functions that understands the difference between rows and columns
    #as indicated in the dictionary made by matread, deviding correctly different fibers
    session_sig = DataFrame(matvars["sig"]);
    names!(session_sig,[Symbol(i *"_sig") for i in labels],makeunique=true);
    for name in names(session_sig)
        session_sig[name] = erase_bumps(session_sig[name])
    end
    session_sig[:Frame] = collect(1:size(session_sig,1))
    session_ref = DataFrame(matvars["ref"]);
    names!(session_ref,[Symbol(i *"_ref") for i in labels],makeunique=true);
    for name in names(session_ref)
        session_ref[name] = erase_bumps(session_ref[name])
    end
    session_ref[:Frame] = collect(1:size(session_ref,1));
    # join the signals and references in one dataframe
    pre_session= join(session_sig,session_ref;on = :Frame);
    session = table(pre_session)
    return session, framerate
end
##

"""
`save_cam_dict`
save a BSON file cointainning all the camera session in a dictionary
"""
function save_cam_dict(DataIndex::DataFrames.AbstractDataFrame)
    exp_dir = DataIndex[1,:Saving_path]
    exp_name = splitdir(exp_dir)[end]
    saving_path = joinpath(exp_dir,exp_name*"_camera.jld")
    cam_dict = OrderedDict(DataIndex[idx,:Session] => ProcessPhotometry.adjust_matfile( DataIndex[idx,:Cam_Path]) for idx = 1:size(DataIndex,2))
    name_list = Vector{Symbol}(undef,0)
    for x in keys(cam_dict)
        ongoing = colnames(cam_dict[x])
        append!(name_list,ongoing)
    end
    cam_dict["trace_list"] = union(name_list)
    BSON.@save saving_path cam_dict
    return cam_dict
end
