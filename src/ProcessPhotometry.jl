# Module to adjust raw data from Photometry

module ProcessPhotometry

using Reexport
@reexport using Flipping
@reexport using CSV
@reexport using MAT
@reexport using OrderedCollections
@reexport using Recombinase
@reexport using BSON
@reexport using StructArrays
@reexport using IndexedTables
@reexport using WeakRefStrings


include("Search_files.jl")
include("Mat_files.jl")
include("Log_files.jl")
include("Analyze_log.jl")
include("Combine.jl")

export create_cam_DataIndex, create_photometry_DataIndex
export adjust_matfile, save_cam_dict
export adjust_logfile
export observe_events, find_events, save_events_dict
export combine_bhv_log, save_bhv_photo

end#module
