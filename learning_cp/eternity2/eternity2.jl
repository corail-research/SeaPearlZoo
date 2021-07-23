using SeaPearl
using SeaPearlExtras
using ReinforcementLearning
const RL = ReinforcementLearning
using LightGraphs
using Flux
using GeometricFlux
using Random


include("rewards.jl")
include("features.jl")

# -------------------
# Generator
# -------------------
eternity2_generator = SeaPearl.Eternity2Generator(6,6,6)
# -------------------
# Internal variables
# -------------------

SR = SeaPearl.DefaultStateRepresentation{EternityFeaturization, SeaPearl.DefaultTrajectoryState}
numInFeatures = SeaPearl.feature_length(SR)
numGlobalFeature = SeaPearl.global_feature_length(SR)
# -------------------
# Experience variables
# -------------------
nbEpisodes = 100
evalFreq = 30
nbInstances = 1
nbRandomHeuristics = 1

# -------------------
# Agent definition
# -------------------

include("agents.jl")

# -------------------
# Value Heuristic definition
# -------------------
learnedHeuristic=SeaPearl.LearnedHeuristic{SR, SeaPearl.DefaultReward2, SeaPearl.FixedOutput}(agent)
# Basic value-selection heuristic
selectMin(x::SeaPearl.IntVar; cpmodel=nothing) = SeaPearl.minimum(x.domain)
heuristic_min = SeaPearl.BasicHeuristic(selectMin)

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

valueSelectionArray = [learnedHeuristic, heuristic_min]
append!(valueSelectionArray, randomHeuristics)
# -------------------
# Variable Heuristic definition
# -------------------
variableSelection = SeaPearl.MinDomainVariableSelection{false}()

# -------------------
# -------------------
# Core function
# -------------------
# -------------------

function trytrain(nbEpisodes::Int)


    metricsArray, eval_metricsArray = SeaPearl.train!(
        valueSelectionArray=valueSelectionArray,
        generator=eternity2_generator,
        nbEpisodes=nbEpisodes,
        strategy=SeaPearl.DFSearch(),
        variableHeuristic=variableSelection,
        out_solver=false,
        verbose = true,
        evaluator=SeaPearl.SameInstancesEvaluator(valueSelectionArray,eternity2_generator; evalFreq = evalFreq, nbInstances = nbInstances),
        restartPerInstances = 1
    )

    return metricsArray, eval_metricsArray
end



# -------------------
# -------------------

metricsArray, eval_metricsArray = trytrain(nbEpisodes)
nothing
