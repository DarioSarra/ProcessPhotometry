# Module to adjust raw data from Photometry

module ProcessPhotometry

using Reexport
@reexport using Flipping
@reexport using CSV
@reexport using MAT
#@reexport using DSP

include("search_files.jl")
include("Mat_files.jl")
include("Log_files.jl")
include("Analyze_log.jl")

export create_cam_DataIndex, create_photometry_DataIndex
export adjust_matfile
export adjust_logfile
export observe_events, find_events

end#module
