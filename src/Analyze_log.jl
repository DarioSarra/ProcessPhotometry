"""
`observe_events`
identify all the pokes in and out and return a dataframe with the ordered index
of every poke and their side
"""
function observe_events(log ::DataFrames.AbstractDataFrame)
    R_in = find_events(log[:R_p],:in)
    R_out = find_events(log[:R_p],:out)
    if length(R_in) == length(R_out)
        events = DataFrame(In = R_in,Out = R_out)
    else
        error("Mismatch!! In events n = $(length(R_in)), Out events n = $(length(R_out))")
    end
    L_in= find_events(log[:L_p],:in)
    L_out = find_events(log[:L_p],:out)
    if (length(L_in) == 0) && (length(L_out)==0)
        rec_type = :one_dimensional_pokes_rec
    elseif (length(L_in) > 5 ) && (length(L_out) > 5)
        rec_type = :two_dimensional_pokes_rec
    else
        println("CHECK POKES TRACKING")
    end

    if rec_type == :two_dimensional_pokes_rec
        events[:Side] = "R"
        append!(events,DataFrame(In = L_in, Out = L_out, Side = repeat(["L"],size(L_in,1))))
        sort!(events,:In)
        events[:Streak] = Flipping.count_sequence(events[:Side])
    end
    events[:Poke] = collect(1:size(events,1))
    return events
end


"""
`find_events`
return the index of a squarewave signal either begins or ends
"""
function find_events(squarewave,which)
    digital_trace = Bool.(squarewave)
    if which == :in
        indexes = findall(.!digital_trace[1:end-1] .& digital_trace[2:end])
    elseif which == :out
        indexes = findall(digital_trace[1:end-1] .& .!digital_trace[2:end])
    end
    return indexes
end
