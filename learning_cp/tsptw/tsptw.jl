using SeaPearl
using SeaPearlExtras
using ReinforcementLearning
const RL = ReinforcementLearning
using Flux
using GeometricFlux
using JSON
using BSON: @load, @save
using Random
using Dates

# -------------------
# Generator
# -------------------
n_city = 5
grid_size = 10
max_tw_gap = 0
max_tw = 100
tsptw_generator = SeaPearl.TsptwGenerator(n_city, grid_size, max_tw_gap, max_tw, true)

# -------------------
# Representation
# -------------------

SR = SeaPearl.TsptwStateRepresentation{SeaPearl.TsptwFeaturization, SeaPearl.TsptwTrajectoryState}

# -------------------
# Internal variables
# -------------------
numInFeatures=SeaPearl.feature_length(SR)

# -------------------
# Experience variables
# -------------------
nbEpisodes = 5
evalFreq = 200
nbInstances = 10
nbRandomHeuristics = 1
restartPerInstances = 1

# -------------------
# Agent definition
# -------------------

include("agents.jl")

# -------------------
# Value Heuristic definition
# -------------------
heuristic_used = "simple"
rewardType = SeaPearl.TsptwReward

if heuristic_used == "simple"
    learnedHeuristic = SeaPearl.SimpleLearnedHeuristic{SR, rewardType, SeaPearl.VariableOutput}(agent)

# SupevisedLEarnedHeuristic is not compatible with TsptwStateRepresentation yet

#=elseif heuristic_used == "supervised"
    eta_init = .9
    eta_stable = .1
    warmup_steps = 300
    decay_steps = 700

    learnedHeuristic = SeaPearl.SupervisedLearnedHeuristic{SR, rewardType, SeaPearl.VariableOutput}(
        agent;
        eta_init=eta_init, 
        eta_stable=eta_stable, 
        warmup_steps=warmup_steps, 
        decay_steps=decay_steps,
        rng=MersenneTwister(1234)
    ) =#
end

include("nearest_heuristic.jl")
nearest_heuristic = SeaPearl.BasicHeuristic(select_nearest_neighbor) # Basic value-selection heuristic

function select_random_value(x::SeaPearl.IntVar; cpmodel=nothing)
    selected_number = rand(1:length(x.domain))
    i = 1
    for value in x.domain
        if i == selected_number
            return value
        end
        i += 1
    end
    @assert false "This should not happen"
end

randomHeuristics = []
for i in 1:nbRandomHeuristics
    push!(randomHeuristics, SeaPearl.BasicHeuristic(select_random_value))
end

valueSelectionArray = [learnedHeuristic, nearest_heuristic]
append!(valueSelectionArray, randomHeuristics)

# -------------------
# Variable Heuristic definition
# -------------------
struct TsptwVariableSelection{TakeObjective} <: SeaPearl.AbstractVariableSelection{TakeObjective} end
TsptwVariableSelection(;take_objective=false) = TsptwVariableSelection{take_objective}()
function (::TsptwVariableSelection{false})(cpmodel::SeaPearl.CPModel; rng=nothing)
    for i in 1:length(keys(cpmodel.variables))
        if haskey(cpmodel.variables, "a_"*string(i)) && !SeaPearl.isbound(cpmodel.variables["a_"*string(i)])
            return cpmodel.variables["a_"*string(i)]
        end
    end
end
variableSelection = TsptwVariableSelection()

# -------------------
# -------------------
# Core function
# -------------------
# -------------------
function trytrain(nbEpisodes::Int)
    
    experienceTime = now()
    dir = mkdir(string("exp_",Base.replace("$(round(experienceTime, Dates.Second(3)))",":"=>"-")))
    expParameters = Dict(
            :experimentParameters => Dict(
                :nbEpisodes => nbEpisodes,
                :restartPerInstances => restartPerInstances,
                :evalFreq => evalFreq,
                :nbInstances => nbInstances
            ),
            :generatorParameters => Dict(
                :instance => "tsptw",
                :n_city => n_city,
                :grid_size => grid_size,
                :max_tw_gap => max_tw_gap,
                :max_tw => max_tw
            ),
            :learnedHeuristic => Dict(
                :learnedHeuristicType => typeof(learnedHeuristic),
                :eta_init => hasproperty(learnedHeuristic, :eta_init) ? learnedHeuristic.eta_init : nothing,
                :eta_stable => hasproperty(learnedHeuristic, :eta_stable) ? learnedHeuristic.eta_stable : nothing,
                :warmup_steps => hasproperty(learnedHeuristic, :warmup_steps) ? learnedHeuristic.warmup_steps : nothing,
                :decay_steps => hasproperty(learnedHeuristic, :decay_steps) ? learnedHeuristic.decay_steps : nothing,
                :rng => hasproperty(learnedHeuristic, :rng) ? Dict(:rngType => typeof(learnedHeuristic.rng), :seed => learnedHeuristic.rng.seed) : nothing
            ),
            :nbRandomHeuristics => nbRandomHeuristics,
            :learnerParameters => Dict(
                :model => string(agent.policy.learner.approximator.model),
                :gamma => agent.policy.learner.sampler.γ,
                :batch_size => agent.policy.learner.sampler.batch_size,
                :update_horizon => agent.policy.learner.sampler.n,
                :min_replay_history => agent.policy.learner.min_replay_history,
                :update_freq => agent.policy.learner.update_freq,
                :target_update_freq => agent.policy.learner.target_update_freq
            ),
            :explorerParameters => Dict(
                :ϵ_stable => agent.policy.explorer.ϵ_stable,
                :decay_steps => agent.policy.explorer.decay_steps
            ),
            :trajectoryParameters => Dict(
                :trajectoryType => typeof(agent.trajectory),
                :capacity => trajectory_capacity
            ),
            :reward => rewardType    
    )
    open(dir*"/params.json", "w") do file
        JSON.print(file, expParameters)
    end

    metricsArray, eval_metricsArray=SeaPearl.train!(
    valueSelectionArray=valueSelectionArray,
    generator=tsptw_generator,
    nbEpisodes=nbEpisodes,
    strategy=SeaPearl.DFSearch(),
    variableHeuristic=variableSelection,
    out_solver=true,
    verbose = false,
    evaluator=SeaPearl.SameInstancesEvaluator(valueSelectionArray,tsptw_generator; evalFreq=evalFreq, nbInstances=nbInstances),
    restartPerInstances=1
)
    trained_weights = params(agent.policy.learner.approximator.model)
    @save dir*"/model_weights_tsptw"*string(n_city)*".bson" trained_weights

    SeaPearlExtras.storedata(metricsArray[1]; filename=dir*"/tsptw_$(n_city)_training")
    SeaPearlExtras.storedata(eval_metricsArray[:,1]; filename=dir*"/tsptw_$(n_city)_trained")
    SeaPearlExtras.storedata(eval_metricsArray[:,2]; filename=dir*"/tsptw_$(n_city)_nearest")
    for i = 1:nbRandomHeuristics
        SeaPearlExtras.storedata(eval_metricsArray[:,i+2]; filename=dir*"/tsptw_$(n_city)_random$(i)")
    end

    return metricsArray, eval_metricsArray
end


metricsArray, eval_metricsArray = trytrain(nbEpisodes)
nothing
