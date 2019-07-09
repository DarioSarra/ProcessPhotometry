"""
`adjust_logfile`
"""
function adjust_logfile(analog_filepath)
    analog = JuliaDB.loadtable(analog_filepath,header_exists = false, datacols = 1:4, colnames = [:timestamp,:R_p,:L_p,:Rew])
    analog = @apply analog begin
        @transform {R_b = :R_p > 4.9}
        @transform {L_b = :L_p > 4.9}
        @transform {Rew_b = :Rew < -4.9}
        @transform_vec {Frame_log = collect(1:length(:R_p))}
    end
        return analog
end

function adjust_logfile(analog_filepath, converted_rate, acquisition_rate) # option to compress before finding events
    analog = JuliaDB.loadtable(analog_filepath,header_exists = false, datacols = 1:4, colnames = [:timestamp,:R_p,:L_p,:Rew])
    bin_size = acquisition_rate / converted_rate
    analog = @apply analog begin
        @transform_vec {Frame = collect(1:length(:R_p))}
        @byrow! :Frame = Int64(round(:Frame / bin_size))
        summarize(mean, _, :Frame)
        @transform {R_b = :R_p > 4.7}
        @transform {L_b = :L_p > 4.7}
        @transform {Rew_b = :Rew < -4.7}
    end
    if columns(analog,:timestamp)[converted_rate+1] < 1
        println("something is off with time conversion")
        return nothing
    else
        return analog
    end
end
# analog = CSV.read(analog_filepath,header=false) |> DataFrame
# analog = analog[:,1:6];
# names!(analog,[:timestamp,:R_p,:L_p,:Rew,:SideHigh,:Protocol])
# analog[:Rew] = analog[:Rew] .* -1
# short = DataFrame()
# for name in names(analog)
#     short[name] = compress_squarewave(analog[name],converted_rate,acquisition_rate)
#     if name != :timestamp
#         short[name] = short[name] .> maximum(short[Symbol(name)]) - 1.0 #convert to boolean
#     end
# end
# if short[converted_rate+1,:timestamp] < 1
#     println("something is off in the sampling rate conversion")
# end
# return short



"""
`compress_squarewave`
collapse from millisecond rate to the a chosen rate
"""
function compress_squarewave(analogs,converted_rate,acquisition_rate)
    long = Float64.(analogs)
    # calculates how many elements are in a bin
    bin_size = Int64(round(acquisition_rate/converted_rate))
    short = []
    #loop at the first element of every bin except the last
    for i = 1:bin_size:size(long,1) - bin_size
        converted_bin_size = mean(long[i:i+bin_size-1])
        push!(short,converted_bin_size)
    end
    lastrange = size(long,1) - bin_size:size(long,1)
    last_converted_bin_size = mean(long[lastrange])
    push!(short,last_converted_bin_size)
    return short
end
