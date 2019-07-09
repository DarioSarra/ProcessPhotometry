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
    session_sig[:Frame] = collect(1:size(session_sig,1))
    session_ref = DataFrame(matvars["ref"]);
    names!(session_ref,[Symbol(i *"_ref") for i in labels],makeunique=true);
    session_ref[:Frame] = collect(1:size(session_ref,1));
    # join the signals and references in one dataframe
    pre_session=join(session_sig,session_ref;on = :Frame);
    session = table(pre_session)
    return session
end
##

"""
`save_cam_dict`
save a jld2 file cointainning all the camera session in a dictionary
"""
function save_cam_dict(DataIndex::DataFrames.AbstractDataFrame)
    saving_dir = DataIndex[1,:Saving_path]
    saving_path = joinpath(saving_dir,"camera_dict.jld2")
    cam_dict = OrderedDict(DataIndex[idx,:Session] => ProcessPhotometry.adjust_matfile( DataIndex[idx,:Cam_Path]) for idx = 1:size(DataIndex,2))
    @save saving_path cam_dict
    return cam_dict
end



"""
`erase_bumps`
use a derivative to correct unnatural change of signal due to fibre move
"""

function erase_bumps(vec::Array{Float64,1}; error = 3, grade = 1, start = 1)
    diff = vec - lag(vec,grade,default = NaN)
    lim0 = -error*NaNMath.std(diff[start:end])
    lim1 = error*NaNMath.std(diff[start:end])
    diff_filtered = [lim0 < val < lim1 ? val : 0.0 for val in diff]
    vec_smooth = cumsum(diff_filtered)
    vec_smooth = vec_smooth .+ mean(vec) .- mean(vec_smooth)
    return vec_smooth
end
