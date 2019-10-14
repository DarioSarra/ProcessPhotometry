function photo_streak(df)
    dayly_vars_list = [:MouseID, :Gen, :Drug, :Day, :Daily_Session, :Box, :Stim_Day, :Condition, :Exp_Day,:Protocol_Day, :Area, :Session];
    booleans=[:Reward,:Side,:SideHigh,:Stim,:Wall,:Correct,:Stim_Day]#columns to convert to Bool
    for x in booleans
        df[!,x] = eltype(df[!,x]) == Bool ? df[!,x] : occursin.("true",df[!,x])
    end
    streak_table = by(df, [:Session,:Streak]) do dd
        dt = DataFrame(
        Num_pokes = size(dd,1),
        Num_Rewards = length(findall(dd[!,:Reward].==1)),
        Start_Reward = dd[1,:Reward],
        Last_Reward = findlast(dd[!,:Reward] .== 1).== nothing ? 0 : findlast(dd[!,:Reward] .== 1),
        Prev_Reward = findlast(dd[!,:Reward] .== 1).== nothing ? 0 : findprev(dd[!,:Reward] .==1, findlast(dd[!,:Reward] .==1)-1),
        Trial_duration = (dd[end,:PokeOut]-dd[1,:PokeIn]),
        Start = (dd[1,:PokeIn]),
        Stop = (dd[end,:PokeOut]),
        Pre_Interpoke = size(dd,1) > 1 ? maximum(skipmissing(dd[!,:Pre_Interpoke])) : missing,
        Post_Interpoke = size(dd,1) > 1 ? maximum(skipmissing(dd[!,:Post_Interpoke])) : missing,
        PokeSequence = [SVector{size(dd,1),Bool}(dd[!,:Reward])],
        Stim = dd[1,:Stim],
        StimFreq = dd[1,:StimFreq],
        Wall = dd[1,:Wall],
        Protocol = dd[1,:Protocol],
        Correct_start = dd[1,:Correct],
        Correct_leave = !dd[end,:Correct],
        Block = dd[1,:Block],
        Streak_within_Block = dd[1,:Streak_within_Block],
        Side = dd[1,:Side],
        ReverseStreak = dd[1,:ReverseStreak]
        )

        return dt
    end
    ##
    streak_table[!,:Prev_Reward] = [x .== nothing ? 0 : x for x in streak_table[!,:Prev_Reward]]
    streak_table[!,:AfterLast] = streak_table[!,:Num_pokes] .- streak_table[!,:Last_Reward]
    streak_table[!,:BeforeLast] = streak_table[!,:Last_Reward] .- streak_table[!,:Prev_Reward].-1
    prov = lead(streak_table[!,:Start],default = 0.0) .- streak_table[!,:Stop]
    streak_table[!,:Travel_to]  = [x.< 0 ? 0.0 : x for x in prov]
    frames = by(df, [:Session,:Streak]) do dd
        dt = DataFrame(
            In = dd[1,:In],
            Out = dd[end,:Out],
            LR_In = findlast(dd[!,:Reward]) == nothing ? missing : dd[findlast(dd[!,:Reward]),:In],
            LR_Out = findlast(dd[!,:Reward]) == nothing ? missing : dd[findlast(dd[!,:Reward]),:Out]
            )
            return dt
    end
    final = join(streak_table, frames, on = [:Session,:Streak])
end

function checktype(v::AbstractArray)
    eltype(v) == Bool ? v : occursin(r"ue","True")
end

function checktype(t::IndexedTables.AbstractIndexedTable,booleans::AbstractArray)
    for x in booleans
        println(x)
        t = setcol(t,x,checktype((column(t,x))))
    end
    return t
end

function photo_streak2(df)
    dayly_vars_list = [:MouseID, :Gen, :Drug, :Day, :Daily_Session, :Box, :Stim_Day, :Condition, :ExpDay, :Area, :Session];
    booleans=[:Reward,:Side,:SideHigh,:Stim,:Wall,:Correct,:Stim_Day]#columns to convert to Bool
    for x in booleans
        @with df cols(x) eltype(cols(x)) == Bool ? cols(x) : occursin.(cols(x),"true")
        df[!,x] = eltype(df[!,x]) == Bool ? df[!,x] : occursin.(df[!,x],"true")
    end
    streak_table = by(df, [:Session,:Streak]) do dd
        dt = DataFrame(
        Num_pokes = size(dd,1),
        Num_Rewards = length(findall(dd[!,:Reward].==1)),
        Start_Reward = dd[1,:Reward],
        Last_Reward = findlast(dd[!,:Reward] .== 1).== nothing ? 0 : findlast(dd[!,:Reward] .== 1),
        Prev_Reward = findlast(dd[!,:Reward] .== 1).== nothing ? 0 : findprev(dd[!,:Reward] .==1, findlast(dd[!,:Reward] .==1)-1),
        Trial_duration = (dd[end,:PokeOut]-dd[1,:PokeIn]),
        Start = (dd[1,:PokeIn]),
        Stop = (dd[end,:PokeOut]),
        Pre_Interpoke = size(dd,1) > 1 ? maximum(skipmissing(dd[!,:Pre_Interpoke])) : missing,
        Post_Interpoke = size(dd,1) > 1 ? maximum(skipmissing(dd[!,:Post_Interpoke])) : missing,
        PokeSequence = [SVector{size(dd,1),Bool}(dd[!,:Reward])],
        Stim = dd[1,:Stim],
        StimFreq = dd[1,:StimFreq],
        Wall = dd[1,:Wall],
        Protocol = dd[1,:Protocol],
        Correct_start = dd[1,:Correct],
        Correct_leave = !dd[end,:Correct],
        Block = dd[1,:Block],
        Streak_within_Block = dd[1,:Streak_within_Block],
        Side = dd[1,:Side],
        ReverseStreak = dd[1,:ReverseStreak]
        )
        for s in dayly_vars_list
            if s in names(df)
                dt[!,s] .= df[1, s]
            end
        end
        return dt
    end
    ##
    streak_table[!,:Prev_Reward] = [x .== nothing ? 0 : x for x in streak_table[!,:Prev_Reward]]
    streak_table[!,:AfterLast] = streak_table[!,:Num_pokes] .- streak_table[!,:Last_Reward]
    streak_table[!,:BeforeLast] = streak_table[!,:Last_Reward] .- streak_table[!,:Prev_Reward].-1
    prov = lead(streak_table[!,:Start],default = 0.0) .- streak_table[!,:Stop]
    streak_table[!,:Travel_to]  = [x.< 0 ? 0.0 : x for x in prov]
    frames = by(df, [:Session,:Streak]) do dd
        dt = DataFrame(
            In = dd[1,:In],
            Out = dd[end,:Out],
            LR_In = findlast(dd[!,:Reward]) == nothing ? NaN : dd[findlast(dd[!,:Reward]),:In],
            LR_Out = findlast(dd[!,:Reward]) == nothing ? NaN : dd[findlast(dd[!,:Reward]),:Out]
            )
            return dt
    end
    final = join(streak_table, frames, on = [:Session,:Streak])
end
