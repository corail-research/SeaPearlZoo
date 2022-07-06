include("../common/experiment.jl")
include("../common/utils.jl")
include("comparison.jl")

###############################################################################
######### Simple jobshop experiment
#########  
######### 
###############################################################################

function simple_experiment_jobshop(n_machines, n_jobs, max_time, n_episodes, n_instances, chosen_features, feature_size; n_eval=10, eval_timeout=60)
    """
    Runs a single experiment on the jobshop scheduling problem
    """
    n_step_per_episode = n_machines*n_jobs
    reward = SeaPearl.GeneralReward
    generator = SeaPearl.JobShopGenerator(n_machines, n_jobs, max_time)
    SR_heterogeneous = SeaPearl.HeterogeneousStateRepresentation{SeaPearl.DefaultFeaturization,SeaPearl.HeterogeneousTrajectoryState}
    trajectory_capacity = 800*n_step_per_episode
    update_horizon = Int(round(n_step_per_episode//2))
    learnedHeuristics = OrderedDict{String,SeaPearl.LearnedHeuristic}()
    agent = get_heterogeneous_agent(;
            get_heterogeneous_trajectory = () -> get_heterogeneous_slart_trajectory(capacity=trajectory_capacity, n_actions=max_time),        
            get_explorer = () -> get_epsilon_greedy_explorer(500*n_step_per_episode, 0.01),
            batch_size=16,
            update_horizon=update_horizon,
            min_replay_history=Int(round(16*n_step_per_episode//2)),
            update_freq=4,
            target_update_freq=7*n_step_per_episode,
            get_heterogeneous_nn = () -> get_heterogeneous_fullfeaturedcpnn(
                feature_size=feature_size,
                conv_size=8,
                dense_size=16,
                output_size=1,
                n_layers_graph=4,
                n_layers_node=2,
                n_layers_output=2,
                pool=SeaPearl.meanPooling()
            )
        )
    learned_heuristic = SeaPearl.SimpleLearnedHeuristic{SR_heterogeneous,reward,SeaPearl.FixedOutput}(agent; chosen_features=chosen_features)
    learnedHeuristics["learning"] = learned_heuristic
    variableHeuristic = SeaPearl.MinDomainVariableSelection{true}()
    selectMin(x::SeaPearl.IntVar; cpmodel=nothing) = SeaPearl.minimum(x.domain)
    heuristic_min = SeaPearl.BasicHeuristic(selectMin)
    basicHeuristics = OrderedDict(
        "min" => heuristic_min
    )

    metricsArray, eval_metricsArray = trytrain(
        nbEpisodes=n_episodes,
        evalFreq=Int(floor(n_episodes / n_eval)),
        nbInstances=n_instances,
        restartPerInstances=1,
        eval_strategy = SeaPearl.ILDSearch(2),
        generator=generator,
        variableHeuristic=variableHeuristic,
        learnedHeuristics=learnedHeuristics,
        basicHeuristics=basicHeuristics;
        out_solver=true,
        verbose=true,
        nbRandomHeuristics=0,
        exp_name= "jobshop_"*string(n_machines)*"_"*string(n_jobs)*"_" * string(max_time),
        eval_timeout=eval_timeout
    )
    nothing

end

###############################################################################
######### Experiment Type 1
#########  
######### 
###############################################################################
"""
Compares HGT and HeterogeneousGraphConv.
"""

function experiment_hgt_vs_graphconv_jobshop(chosen_features, n_machines, n_jobs, max_time, n_episodes, n_instances; n_eval=10)
    """
    Compares the impact of the number of convolution layers for the heterogeneous representation.
    """
    generator = SeaPearl.JobShopGenerator(n_machines, n_jobs, max_time)

    experiment_hgt_vs_graphconv(
        n_machines*n_jobs,
        n_machines*n_jobs,
        n_episodes,
        n_instances,
        1;
        output_size = max_time, 
        generator = generator,
        chosen_features = chosen_features, 
        type = "jobshop_"*string(n_machines)*"_"*string(n_jobs)*"_"*string(max_time)
        )
end


###############################################################################
######### Experiment Type 2
#########  
######### 
###############################################################################
"""
Compares different Reward on JobShop
"""

function experiment_different_reward_jobshop(n_machines, n_jobs, max_time, n_episodes, n_instances; n_layers_graph=3, n_eval=10, pool = SeaPearl.meanPooling())
    """
    Compare three agents:
        - an agent with the default representation and default features;
        - an agent with the default representation and chosen features;
        - an agent with the heterogeneous representation and chosen features.
    """
    generator = SeaPearl.JobShopGenerator(n_machines, n_jobs, max_time)
    selectMin(x::SeaPearl.IntVar; cpmodel=nothing) = SeaPearl.minimum(x.domain)
    heuristic_min = SeaPearl.BasicHeuristic(selectMin)
    basicHeuristics = OrderedDict(
        "min" => heuristic_min
    )
    chosen_features = Dict(
        "variable_is_bound" => true,
        "variable_assigned_value" => true,
        "variable_initial_domain_size" => true,
        "variable_domain_size" => true,
        "variable_is_objective" => true,
        "constraint_activity" => true,
        "constraint_type" => true,
        "nb_not_bounded_variable" => true,
        "values_raw" => true,
    )

    experiment_reward(n_machines*n_jobs, n_episodes, n_instances;
        chosen_features=chosen_features,
        feature_size = [5, 9, 1], 
        output_size = max_time, 
        generator = generator, 
        basicHeuristics = basicHeuristics, 
        n_layers_graph = n_layers_graph, 
        n_eval = n_eval, 
        type = "jobshop",
        c=2.0,
        pool = pool
    # Basic value-selection heuristic
###############################################################################
######### Experiment Type 6
#########  
######### 
###############################################################################

function experiment_nn_heterogeneous_jobshop(chosen_features, feature_size, n_machines, n_jobs, max_time, n_episodes, n_instances; n_eval=10)
    """
    Compares the impact of the number of convolution layers for the heterogeneous representation.
    """
    generator = SeaPearl.JobShopGenerator(n_machines, n_jobs, max_time)

    selectMin(x::SeaPearl.IntVar; cpmodel=nothing) = SeaPearl.minimum(x.domain)
    heuristic_min = SeaPearl.BasicHeuristic(selectMin)
    basicHeuristics = OrderedDict(
        "min" => heuristic_min
    )

    experiment_nn_heterogeneous(
        n_machines*n_jobs, 
        Int(round(n_machines*n_jobs*0.5)),
        n_episodes, 
        n_instances; 
        feature_size=feature_size, 
        output_size=max_time, 
        n_eval=n_eval, 
        generator=generator, 
        type = "jobshop_"*string(n_machines)*"_"*string(n_jobs)*"_"*string(max_time), 
        eval_timeout=60, 
        chosen_features=chosen_features, 
        basicHeuristics=basicHeuristics, 
        reward=SeaPearl.GeneralReward, 
        n_layers_graph=4, 
        decay_steps=Int(round(600*n_machines*n_jobs*0.5)), 
        trajectory_capacity=Int(round(1200*n_machines*n_jobs*0.5)),
        update_horizon=Int(round(n_machines*n_jobs*0.25)),
        pool=SeaPearl.sumPooling()
    )
end