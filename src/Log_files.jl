export adjust_logfile

"""
`adjust_logfile`
"""
function adjust_logfile(analog_filepath, converted_rate = 50, acquisition_rate = 1000)
    analog = FileIO.load(analog_filepath,header_exists=false) |> DataFrame
    analog = analog[:,1:6];
    names!(analog,[:timestamp,:R_p,:L_p,:Rew,:SideHigh,:Protocol])
    analog[:Rew] = analog[:Rew] .* -1
    short = DataFrame()
    for name in names(analog)
        short[name] = compress_squarewave(analog[name],converted_rate,acquisition_rate)
        if name != :timestamp
            short[name] = short[name] .> maximum(short[Symbol(name)]) - 1.0 #convert to boolean
        end
    end
    if short[converted_rate+1,:timestamp] < 1
        println("something is off in the sampling rate conversion")
    end
    return short
end




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
