"""
`observe_events`
identify all the pokes in and out and return a dataframe with the ordered index
of every poke and their side
"""
function observe_events(analog, converted_rate = 50, acquisition_rate = 1000)
    bin_size = acquisition_rate / converted_rate
    R_in = find_events(columns(analog,:R_b),:in) .÷ bin_size
    R_out = find_events(columns(analog,:R_b),:out) .÷ bin_size
     if length(R_in) != length(R_out)
        println("mismatch left: In are $(length(L_in)), Out are $(length(L_out))")
        return nothing
    end
    Rs = table((In = R_in, Out = R_out, Side = repeat(["R"],length(R_in))))

    L_in = find_events(columns(analog,:L_b),:in) .÷ bin_size
    L_out = find_events(columns(analog,:L_b),:out) .÷ bin_size
    if length(L_in)!=length(L_out)
        println("mismatch right: In are $(length(R_in)), Out are $(length(R_out))")
        return nothing
    end
    if (length(L_in) == 0) && (length(L_out)==0)
        rec_type = :one_dimensional_pokes_rec
    elseif (length(L_in) > 5 ) && (length(L_out) > 5)
        rec_type = :two_dimensional_pokes_rec
    else
        println("CHECK POKES TRACKING")
    end

    if rec_type == :two_dimensional_pokes_rec
        Ls = table((In = L_in, Out = L_out, Side = repeat(["L"],length(L_in))))
        events = sort(merge(Rs,Ls),:In)
    else
        events = Rs
    end

    events = @apply events begin
        @transform_vec {In = Int64.(:In)}
        @transform_vec {Out = Int64.(:Out)}
        @transform_vec {Poke = collect(1:length(:In))}
        @transform_vec {Streak = Flipping.count_sequence(:Side)}
        @transform {Poke_Dur = (:Out - :In) / converted_rate + 0.1}
        end
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
