# Module to adjust raw data from Photometry

module ProcessPhotometry

using Reexport
@reexport using Preprocess
@reexport using DSP
using DataArrays



export findframe, preprocess_photometry, isinbound,applyshifted,add_streakinfo,
compile_traces, add_StreakWindow, add_NormWindow,add_F0, add_NormTraces, add_CorrectedTrace,
renamefibers!, check_names!, fill_fluo, arrange_traces, calc_F0, Normalise_F0,Normalise_GLM,
Normalise_Reg


"""
`findframe`
convert the timestamp of an event from the national board in to the corrisponding frame for the camera
"""
findframe(event_index,timestamp,framerate) = Int64(round((timestamp[event_index]*framerate))+1)

findframe(event_index,framerate) = Int64(round((event_index/1000*framerate))+1)
"""
`preprocess_photometry`
construct a Dataframe with the signals and references from the different ROI's, using the
analog data of the national board istruments finds pokes events and locate them in the camera dataframe
"""
function preprocess_photometry(df)
    mat_filepath = df[1,:Cam_Path]
    analog_filepath = df[1,:Log_Path]
    preprocess_photometry(mat_filepath,analog_filepath)
end

function preprocess_photometry(mat_filepath::String,analog_filepath::String)
    #matvars read structures as a dictionary
    matvars=matread(mat_filepath);
    #since the camera alternates on 2 channels the frame rate is actually half
    framerate = (matvars["framerate"])/2;
    framerate
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
    session=join(session_sig,session_ref;on = :Frame);
    # take the timestamp and the analog signal from the national board to find the frame
    # corresponding to poke in
    csvvars=CSV.read(analog_filepath, header = 0, nullable = false);
    timestamp = csvvars[:Column1];
    analog = csvvars[:Column2];
    digital = analog.>mean(analog); #digital poke signal that is actually a boolean vector
    pokein_analog_idx = find(.!digital[1:end-1] .& digital[2:end]); # from false to true
    pokein_analog_idx= pokein_analog_idx.-100; #pokes are consider valid only after 100 ms so the actual time as to be redirived
    pokeout_analog_idx = find(digital[1:end-1] .& .!digital[2:end]); # from true to false;
    #list of idx for the camera frame corrisponding to a pokein
   pokein = []
   for x in pokein_analog_idx
       push!(pokein, findframe(x,framerate))
   end
   #list of idx for the camera frame corrisponding to a pokeout
   pokeout = []
   for x in pokeout_analog_idx
       push!(pokeout, findframe(x,framerate))
   end
   #control if there is overlapping of pokein on the next pokeout
   for i = 2:size(pokein,1)
       if pokein[i]==pokeout[i-1]+1 #if a pokein immediately follow previous pokeout
           pokeout[i-1] = pokeout[i-1]-1
       elseif pokein[i]==pokeout[i-1] #if a pokein same as pokeout
           pokeout[i-1] = pokeout[i-1]-2
       elseif pokeout[i]<pokein[i]
           println(analog_filepath," POKEOUT PRECEEDES POKEIN")
       end
   end

    session[:PokeIn]= false;
    session[:PokeIn][pokein] = true;
    # add pokes counter
    session[:PokeIn_n] = 0
    counter = 1
    for i in pokein
        session[:PokeIn_n][i] = counter
        counter = counter+1
    end

    session[:PokeOut]= false;
    session[:PokeOut][pokeout] = true;
    # add pokes counter
    session[:PokeOut_n] = 0
    counter = 1
    for i in pokeout
        session[:PokeOut_n][i] = counter
        counter = counter+1
    end
    session[:Pokes] = 0;
    for i = 1:maximum(session[:PokeOut_n])
        session[pokein[i]:pokeout[i],:Pokes] = 1;
    end
    session[:Interpoke]=0
    if size(session,1)>findlast(session[:PokeOut])+500
        finish = findlast(session[:PokeOut])+500;
        session = session[1:finish,:];
    end
    return session
end
"""
`check_names!`
check columns name and correct session with wrong labeling: 2 control instead than Left Right control
"""
function check_names!(traces)
    Cols = traces.colindex.names;
    Columns = string.(Cols);
    result = Columns[contains.(Columns,"_sig").|contains.(Columns,"_ref")]
    Adjust = result[contains.(result,"_1")]
    if !isempty(result[contains.(result,"_1")])
        if traces[1,:PLUGGED] == "LEFT"
            rename!(traces, :control_sig_1 => :RightNac_sig)
            rename!(traces, :control_ref_1 => :RightNac_ref)
        elseif traces[1,:PLUGGED] == "RIGHT"
            rename!(traces, :control_sig_1 => :LeftNac_sig)
            rename!(traces, :control_ref_1 => :LeftNac_ref)
        end
    end
    return traces
end
"""
`renamefibers!`
Look into which fiber is plugged and rename the column to indicate the the Nac fiber in the same way
"""
function renamefibers!(traces)
    if traces[1,:PLUGGED] == "LEFT"
        plugged = "Left"
        unplugged = "Right"
        #=variable to potentially edit in the future to check the second fibers
        in session where both were plugged=#
        newnames = ["Nac", "Out"]
    elseif traces[1,:PLUGGED] == "RIGHT"
        plugged = "Right"
        unplugged = "Left"
        newnames = ["Nac", "Out"]
    elseif traces[1,:PLUGGED] == "BOTH"
        plugged = "Right"
        unplugged = "Left"
        newnames = ["Nac", "Out"]
    end
    plu_unpl = [plugged, unplugged]
    before = Symbol[]
    for quale in plu_unpl
        for tipo in ["Nac_sig", "Nac_ref"]
            push!(before,Symbol(quale*tipo))
        end
    end
    after = Symbol[]
    #=this option take only the right signal for session in which both fibres were plugged=#
    for quale in newnames
        for tipo in ["_sig", "_ref"]
            push!(after,Symbol(quale*tipo))
        end
    end
    Renaming=DataFrame(Before=before,After=after)
    for i in 1:size(Renaming,1)
        rename!(traces,Renaming[i,:Before]=>Renaming[i,:After])
    end
    return traces
end

"""
`add_streakinfo`
Add information to a trace file about the frame of a streak start
"""
function add_streakinfo(traces::DataFrame,idx=1)
    #read the preprocessed poke file proceed per single session file
    bhv = FileIO.load(traces[idx,:Exp_Path]*"Bhv/"*traces[idx,:Session]*".csv")|>DataFrame
    #skips non matching file in terms of number of pokes
    if maximum(traces[:PokeOut_n]) != maximum(bhv[:Poke_n])
        println(traces[1,:Session], " non matching poke number")
        return nothing
    end
    ### FIRST POKE
    #get an array with the poke corresponding to the beginning of a streak
    #find the poke_n at which a streak start from the pokes Dataframe
    traces[:StreakStart] = false
    traces[:StreakIn_n] = 0
    streakstart=find(contains.(bhv[:StreakStart],"true"))
    #=set streakstart true and StreakStart_n = to counter
    for the pokeIn_n from the list of the behavior file=#
    c=1
    for i in streakstart
        traces[findfirst(traces[:PokeIn_n].==i),:StreakStart]=true
        traces[findfirst(traces[:PokeIn_n].==i),:StreakIn_n]=c
        c=c+1
    end
    ### LAST POKE
    traces[:StreakOut_n] = 0
    lastpokes = []
    by(bhv,:Streak_n) do dd
            #push the pokenumber of the last reward in a streak
            push!(lastpokes,dd[end,:Poke_n])
    end
    c=1
    for i in lastpokes
        traces[findfirst(traces[:PokeOut_n].==i),:StreakOut_n]=c
        c=c+1
    end
    ### LAST REWARD
    traces[:LastReward] = false
    traces[:LastRewardIn_n] = 0
    traces[:LastRewardOut_n] = 0
    lastrewards =[]
    by(bhv,:Streak_n) do dd
        idxR=findlast(contains.(dd[:Reward],"true"))#find the last in the streak
        if idxR!=0
            #push the pokenumber of the last reward in a streak
            push!(lastrewards,dd[idxR,:Poke_n])
        end
    end

    c=1
    for i in lastrewards
        traces[findfirst(traces[:PokeIn_n].==i),:LastReward]=true
        traces[findfirst(traces[:PokeIn_n].==i),:LastRewardIn_n]=c
        traces[findfirst(traces[:PokeOut_n].==i),:LastRewardOut_n]=c
        c=c+1
    end
    return traces
    #### need a way to check for files wrongly closed
end

"""
`add_StreakWindow`
Identifies the window of a streak following those rules:
1 Calculates travel duration between streaks
2 Assignes the first half to the previous and the second to the following streaks
3 If the half travel duration is shorter than 2 seconds the previous streaks ends 100 ms after last poke out
  and the rest of the time is assigned to the following streak
4 The first streak starts 5 second before the first poke,
  if there is not enough time it takes all the previous data
5 The last streak ends after 5 seconds from the last poke
  or take all the data if the remaining time is shorter than that
 These values are preassigned but can modifyied trough direct call of the function
"""
function add_StreakWindow(traces,framerate = 50, u_time = 5, l_time = 2, ex_time=0.1)
    #upper frame limit for the begin of a streak
    u_frame= u_time*framerate
    #lower frame limit for the begin of a streak
    l_frame = l_time*framerate
    #lower frame limit for the begin of a streak when there are less than 2 second interval
    ex_frame = ex_time*framerate
    traces[:StreakWindow_n]=0
    c=1
    inizio=find(traces[:StreakStart])
    fine = [findprev(traces[:PokeOut], i) for i in inizio]
    push!(fine,findlast(traces[:PokeOut]))
    shift!(fine)
    for i = 1:size(inizio,1)
        traces[inizio[i]:fine[i],:StreakWindow_n] = c
        c=c+1
    end
    traces[:TrialWindow_n]=0
    StreakIn = copy(inizio)
    StreakOut = copy(fine)
    #particular case begin session
    if inizio[1]>u_frame
        StreakIn[1]=inizio[1]-u_frame
    else
        StreakIn[1]=1
    end
    #particular case end session
    if size(traces,1)-fine[end]>u_frame
        StreakOut[end] = fine[end] + u_frame
    else
        StreakOut[end] = size(traces,1)
    end
    #loop for value in the session
    for i =2:size(StreakIn,1)
        differenza = inizio[i]-fine[i-1]
        #= Since the minimum travel time in this dataframe is 0.71 s some interval are shorter than 2 seconds
        when the interval between 2 streaks is lower than 2 seconds, the following streak is initiated
        100 ms after the last poke of the previous streak =#
        if differenza < l_frame
            StreakOut[i-1] = fine[i-1] + ex_frame
            StreakIn[i]= StreakOut[i-1]+1
            #= Since StreakOut is initiated as a copy of fine,
            which is the idx of last pokeout of a streak it doesn't have to be modified
            when the interval between 2 streaks is lower than the minimum 2 seconds=#
        else
            StreakIn[i] = inizio[i] - round(Int64,differenza/2)
            StreakOut[i-1] = StreakIn[i]-1
        end
    end
    c=1
    for i = 1:size(inizio,1)
        traces[StreakIn[i]:StreakOut[i],:TrialWindow_n] = c
        c=c+1
    end
    return traces
end
"""
`normalization_window`
add a Boolean array to indicate what frame to use for normalisation for each trial
"""
function add_NormWindow(traces,framerate = 50,F0_span=1,F0_start=0.5)
    traces[:Baseline] = false
    F0_span_frame = Int64(F0_span*framerate)
    F0_start_frame = Int64(F0_start*framerate)
    by(traces,:TrialWindow_n) do dd
        firstpoke=findfirst(dd[:PokeIn])
        #jump out TrialWindow_n = 0 which is non relevant data
        if firstpoke==0
            return
        end
        #jump Streaks in which the interpoke time is too high meaning the animal is doing something else in between pokes
        ins=find(dd[:PokeIn])
        outs=find(dd[:PokeOut])
        if size(ins,1)!=size(outs,1)
            println(dd[1,:Session]," ",dd[1,:TrialWindow_n])
            println("mismatch poke in and poke out: IN=",size(ins,1)," Out=",size(outs,1))
        end
        if size(ins,1)>1 #if a streak has only one poke it can't calculate interpoke interval
            difference= ins[2:end]-outs[1:end-1]
            if maximum(difference)>2*framerate #skip streaks with interpoke > 2seconds
                return
            end
        end
        if firstpoke > F0_span_frame + F0_start_frame
            End=firstpoke-F0_start_frame
            Start=End-F0_span_frame
            elseif firstpoke > F0_start_frame
            Start=1
            End = firstpoke-F0_start_frame
            else
            return
        end
        dd[Start:End,:Baseline] = true
        return
    end
    traces
end
"""
`add_F0`
1 Set F0 from -1.5 to -0.5 seconds before the first PokeIn of the streaks
2 If there are less than 1.5 seconds before the Poke in it takes everything before -0.5
"""
function add_F0(traces,fiber)
    sig=Symbol("$(fiber)")
    traces[Symbol("F0_$(fiber)")] = DataArray(Float64, size(traces,1))
    by(traces,:TrialWindow_n) do dd
        Start = findfirst(dd[:Baseline])
        End =findlast(dd[:Baseline])
        if Start==0
            return
        else
        F0_sig=mean(dd[Start:End,sig])
        dd[Symbol("F0_$(fiber)")] = F0_sig
        end
    end
    return traces
end
"""
`add_NormTraces`
using F0 values calculates the normalised signal and reference
"""
function add_NormTraces(traces, fiber)
    norm = Symbol("Norm_$(fiber)")
    F0 = Symbol("F0_$(fiber)")
    channel = Symbol(fiber)
    traces[norm]= (traces[channel].-traces[F0])./traces[F0]
    return traces
end
"""
`add_CorrectedTrace`
using GLM calculates the regressed signal over the reference and subtract it to the signal
"""
function add_CorrectedTrace(traces, fiber)
    name=replace("$(fiber)","_sig","")
    trial_window = traces[:TrialWindow_n]
    sig = traces[Symbol("Norm_$(fiber)")]
    ref = traces[Symbol(replace("Norm_$(fiber)","sig","ref"))]
    pokes = traces[:Pokes]
    #remove missings
    filter = .!ismissing.(sig)
    #regression
    intercept, slope = linreg(collect(skipmissing(ref)),collect(skipmissing(sig)))
    traces[Symbol("Corrected_$(name)")] = (sig.- ref*slope)
    # prov = DataFrame(TrialWindow_n = trial_window, Sig=sig,Ref = ref,Pokes = smooth3)
    # OLS = lm(@formula(Sig ~ 0 + Ref), prov[filter,:])
    # prediction = predict(OLS, prov)
    # traces[Symbol("Corrected_$(name)")] = sig.- prediction
    #convolve pokes
    # gbinh = 500;
    # distr=gaussian(2gbinh,0.01);
    # smooth1 = conv(distr,pokes)
    # smooth2 = smooth1./sum(distr)#convulution change the scale so it is needed to renormalise to preserve the average
    # smooth3 = smooth2[gbinh:end-gbinh] # convulution shifts data depending on gaussian binsize
    # OLS_conv = lm(@formula(Sig ~ 0 + Ref*Pokes), prov[filter,:])
    # prediction_conv = predict(OLS_conv, prov)
    # traces[Symbol("Convolved_$(name)")] = sig.- prediction_conv
    return traces
end


"""
`compile_traces`
Function with 2 methods
Using a DataIndex of the sessions call preprocess_photometry to join Matlab and Log filetosave
It can be run on a specific session as with a string as second argument
or over all the sessions in the DataIndex
"""
function compile_traces(DataIndex::DataFrame,Session::String)#"NB5_170527"
    idx=findfirst(DataIndex[:Session].==Session)
    columns_list= [:Exp_Path,:MouseID, :Day, :Session, :PLUGGED]
    m = DataIndex[idx,:Cam_Path]
    l= DataIndex[idx,:Log_Path]
    traces = preprocess_photometry(m,l)
    for s in columns_list
        if s in names(DataIndex)
            traces[s] = DataIndex[idx, s]
        end
    end
    ###check columns name and correct session with wrong labeling: 2 control instead than Left Right control
    check_names!(traces)
    #Assignes new name to columns in order to identify the plugged fiber in a general way
    renamefibers!(traces)
    Cols = traces.colindex.names;
    Columns = string.(Cols);
    result = Columns[contains.(Columns,"_sig").|contains.(Columns,"_ref")]
    #if maximum(traces[:PokeIn_n]) !=
    traces = add_streakinfo(traces)
    if traces == nothing
        return
    end
    traces = add_StreakWindow(traces)
    traces = add_NormWindow(traces)
    # Cols = traces.colindex.names;
    # Columns = string.(Cols);
    # result = Columns[contains.(Columns,"_sig").|contains.(Columns,"_ref")]
    for fiber in result
        traces = add_F0(traces,fiber)
        traces = add_NormTraces(traces, fiber)
    end
    result = Columns[contains.(Columns,"_sig")]
    println("corrected_"*traces[1,:Session])
    for fiber in result
        traces = add_CorrectedTrace(traces,fiber)
    end
    CSV.write(traces[1,:Exp_Path]*"Cam/traces_"*traces[1,:Session]*".csv",traces)
    return traces
end

function compile_traces(DataIndex::DataFrame)
    by(DataIndex,:Session) do dd
        compile_traces(DataIndex,dd[1,:Session])
        return
    end
end
"""
`arrange_traces`
"""
function arrange_traces(DataIndex::DataFrame,Session::String)#"NB5_170527"
    idx=findfirst(DataIndex[:Session].==Session)
    columns_list= [:Exp_Path,:MouseID, :Day, :Session, :PLUGGED]
    m = DataIndex[idx,:Cam_Path]
    l= DataIndex[idx,:Log_Path]
    traces = preprocess_photometry(m,l)
    for s in columns_list
        if s in names(DataIndex)
            traces[s] = DataIndex[idx, s]
        end
    end
    ###check columns name and correct session with wrong labeling: 2 control instead than Left Right control
    check_names!(traces)
    #Assignes new name to columns in order to identify the plugged fiber in a general way
    renamefibers!(traces)
    Cols = traces.colindex.names;
    Columns = string.(Cols);
    result = Columns[contains.(Columns,"_sig").|contains.(Columns,"_ref")]
    #if maximum(traces[:PokeIn_n]) !=
    traces = add_streakinfo(traces)
    if traces == nothing
        return
    end
    traces = add_StreakWindow(traces)
    traces = add_NormWindow(traces)
    # Cols = traces.colindex.names;
    # Columns = string.(Cols);
    # result = Columns[contains.(Columns,"_sig").|contains.(Columns,"_ref")]
    CSV.write(traces[1,:Exp_Path]*"Cam/simpletrace_"*traces[1,:Session]*".csv",traces)
    return traces
end

function arrange_traces(DataIndex::DataFrame)
    by(DataIndex,:Session) do dd
        arrange_traces(DataIndex,dd[1,:Session])
        return
    end
end

"""
'prep_fluo'
initiate dataframe for shiftedarrays photometry
"""
function prep_fluo(trace)
    Cols = trace.colindex.names;
    Columns = string.(Cols);
# If is processing simple traces will only find _sig and _ref
    result = Columns[(contains.(Columns,"_sig").|contains.(Columns,"_ref")
        .|contains.(Columns,"Corrected").|contains.(Columns,"Convolved")).& .!contains.(Columns,"F0")]
    lista = convert.(Symbol,result)
    push!(lista,:Pokes);
    push!(lista,:Baseline)
    fluo = DataFrame()
    for i in [:MouseID, :Day, :Session, :PLUGGED, :Exp_Path]
        fluo[i] = fill(trace[1,i],maximum(trace[:TrialWindow_n]))
    end
    trials = sort(union(trace[:StreakIn_n]))
    shift!(trials)
    fluo[:Streak_n] = trials
    for i in [:StreakIn_n, :StreakOut_n, :LastRewardIn_n, :LastRewardOut_n]
        fluo[i] = fill(0,maximum(trace[:TrialWindow_n]))
    end
    for i in lista
        fluo[i]=Array{Any}(maximum(trace[:TrialWindow_n]))
    end
    return fluo, lista
end

"""
`fill_fluo`
rearrange traces file in shiftedarrays fluorescence
"""

function fill_fluo(trace)#it work only for one session at the time
    fluo, lista = prep_fluo(trace)
    by(trace,:TrialWindow_n)  do dd2 # Trial window is a vector of continous index of the trial ongoing
        if dd2[1,:TrialWindow_n] == 0 # trial window is 0 during traveling
            return
        else
            streak = dd2[1,:TrialWindow_n]  # Trial window value is equal to the streak count
            event = findfirst(dd2[:StreakIn_n]) # this would be the default shift
            fine = findfirst(dd2[:StreakOut_n]) # this cut the array at the last poke out
            for i in [:StreakIn_n, :StreakOut_n, :LastRewardIn_n, :LastRewardOut_n]
# those vector are always 0 excluded the exact frame of the event where they have the value of the streak count
                fluo[streak,i] = findfirst(dd2[i])
            end
            for i in lista
                fluo[streak,i] = ShiftedArray(dd2[1:fine,i], - event) #shifts have to have the negative sign to move forward
            end
        end
    end;
    for i in lista
    #the Column it's initiated as Any[] so it needs to be reconverted to ShiftedArray
        fluo[i] = convert(Array{typeof(fluo[i][1])}, fluo[i])
    end;
    return fluo
end

"""
`calc_F0`
"""
function calc_F0(data::AbstractDataFrame,WHAT::Symbol,start = -100, finish = -50)
    Fzeroes=[]
    for trials = 1:size(data,1)
        if data[trials,WHAT].shifts[1] == 0
            F0 = missing
            push!(Fzeroes,F0)
        else
            v = skipmissing(data[trials,WHAT][start:finish])
            F0 = isempty(v) ? missing : mean(v)#if there are only missing value return missing else the mean
            push!(Fzeroes,F0)
        end

    end
    return Fzeroes
end
"""
`Normalise_F0`
"""
function  Normalise_F0(data::AbstractDataFrame,WHAT::Symbol;start = -100, finish = -50)
    F0_norm =  Array{ShiftedArrays.ShiftedArray{Float64,Missings.Missing,1,Array{Float64,1}}}(size(data,1))
    Fzeroes = calc_F0(data,WHAT,start,finish)
    for i = 1:size(data,1)
        subtract = (data[i,WHAT].parent) - Fzeroes[i]
        value = subtract/Fzeroes[i]
        shift = data[i,WHAT].shifts[1]#shifts is a Tuples need to be indexed
        if typeof(value)== DataArrays.DataArray{Float64,1}
            println("i = ",i)
            println("shift = ", shift)
            println(value,typeof(value))
            convert(Array{Float64,1},value)
        end
        F0_norm[i] = ShiftedArray(value,shift)
    end
    return F0_norm
end
"""
`Normalise_GLM`
"""
function  Normalise_GLM(data::AbstractDataFrame,signal::Symbol,regressor::Symbol)
    prov = DataFrame()
    sig_vector = Union{Float64,Missing}[]
    ref_vector = Union{Float64,Missing}[]
    for i = 1:size(data,1)
        append!(sig_vector, data[i,signal].parent)
        append!(ref_vector, data[i,regressor].parent)
    end;
    prov = DataFrame(Sig=sig_vector,Ref = ref_vector)
    filter = .!ismissing.(sig_vector)
    OLS = lm(@formula(Sig ~ 0 + Ref), prov[filter,:])
    coefficient = coef(OLS)
    prov = DataFrame(Sig=sig_vector,Ref = ref_vector)
    filter = .!ismissing.(sig_vector)
    OLS = lm(@formula(Sig ~ 0 + Ref), prov[filter,:])
    coefficient = coef(OLS)
    Reg_norm =  Array{Any}(size(data,1))
    for i in 1:size(data,1)
        value = @.(data[i,signal].parent-data[i,regressor].parent*coefficient)
        shift = data[i,signal].shifts[1]
        Reg_norm[i] = ShiftedArray(value,shift)
    end;
    return Reg_norm
end
"""
`Normalise_Reg`
"""
function  Normalise_Reg(data::AbstractDataFrame,WHAT::Symbol)
    col_sig = WHAT
    col_ref = Symbol(replace(String(WHAT),"sig","ref"))
    sig_shifted = Normalise_F0(data,col_sig)
    ref_shifted = Normalise_F0(data,col_ref)
    sig_vector = sig_shifted[1].parent
    ref_vector = ref_shifted[1].parent
    for i = 2:size(sig_shifted,1)
        sig_vector = vcat(sig_vector,sig_shifted[i].parent)
        ref_vector = vcat(ref_vector,ref_shifted[i].parent)
    end
    intercept, slope = linreg(collect(skipmissing(ref_vector)),collect(skipmissing(sig_vector)))
    Reg_norm =  Array{ShiftedArray}(size(data,1))
    for i in 1:size(data,1)
        value = @.(sig_shifted[i].parent-ref_shifted[i].parent*slope)
        shift = data[i,WHAT].shifts[1]
        Reg_norm[i] = ShiftedArray(value,shift)
    end
    return Reg_norm
end



end#module end
