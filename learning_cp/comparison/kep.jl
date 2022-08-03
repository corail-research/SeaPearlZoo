include("../common/experiment.jl")
include("../common/utils.jl")
include("comparison.jl")

function experiment_representation(n_nodes, density, n_episodes, n_instances; n_layers_graph=2, n_eval=10, eval_timeout=60)
    """
    Compare three agents:
        - an agent with the default representation and default features;
        - an agent with the default representation and chosen features;
        - an agent with the heterogeneous representation and chosen features.
    """
    kep_generator = SeaPearl.KepGenerator(n_nodes, density)
    SR_default = SeaPearl.DefaultStateRepresentation{SeaPearl.DefaultFeaturization,SeaPearl.DefaultTrajectoryState}
    SR_heterogeneous = SeaPearl.HeterogeneousStateRepresentation{SeaPearl.DefaultFeaturization,SeaPearl.HeterogeneousTrajectoryState}

    agent_default_default = get_default_agent(;
        capacity=2000,
        decay_steps=2000,
        ϵ_stable=0.01,
        batch_size=16,
        update_horizon=8,
        min_replay_history=256,
        update_freq=1,
        target_update_freq=8,
        feature_size=3,
        conv_size=8,
        dense_size=16,
        output_size=2,
        n_layers_graph=n_layers_graph,
        n_layers_node=2,
        n_layers_output=2
    )
    learned_heuristic_default_default = SeaPearl.SimpleLearnedHeuristic{SR_default,SeaPearl.GeneralReward,SeaPearl.FixedOutput}(agent_default_default)

    chosen_features = Dict(
        "constraint_type" => true,
        "variable_initial_domain_size" => true,
        "values_raw" => true,
    )

    agent_default_chosen = get_default_agent(;
        capacity=2000,
        decay_steps=2000,
        ϵ_stable=0.01,
        batch_size=16,
        update_horizon=8,
        min_replay_history=256,
        update_freq=1,
        target_update_freq=8,
        feature_size=11,
        conv_size=8,
        dense_size=16,
        output_size=2,
        n_layers_graph=n_layers_graph,
        n_layers_node=2,
        n_layers_output=2
    )
    learned_heuristic_default_chosen = SeaPearl.SimpleLearnedHeuristic{SR_default,SeaPearl.GeneralReward,SeaPearl.FixedOutput}(agent_default_chosen; chosen_features=chosen_features)

    agent_heterogeneous = get_heterogeneous_agent(;
        capacity=2000,
        decay_steps=2000,
        ϵ_stable=0.01,
        batch_size=16,
        update_horizon=8,
        min_replay_history=256,
        update_freq=1,
        target_update_freq=8,
        feature_size=[1, 6, 1],
        conv_size=8,
        dense_size=16,
        output_size=2,
        n_layers_graph=n_layers_graph,
        n_layers_node=2,
        n_layers_output=2
    )
    learned_heuristic_heterogeneous = SeaPearl.SimpleLearnedHeuristic{SR_heterogeneous,SeaPearl.GeneralReward,SeaPearl.FixedOutput}(agent_heterogeneous; chosen_features=chosen_features)


    # Basic value-selection heuristic
    selectMin(x::SeaPearl.IntVar; cpmodel=nothing) = SeaPearl.minimum(x.domain)
    heuristic_min = SeaPearl.BasicHeuristic(selectMin)

    learnedHeuristics = OrderedDict(
        "defaultdefault" => learned_heuristic_default_default,
        "defaultchosen" => learned_heuristic_default_chosen,
        "heterogeneous" => learned_heuristic_heterogeneous,
    )
    basicHeuristics = OrderedDict(
        "random" => SeaPearl.RandomHeuristic()
    )

    # -------------------
    # Variable Heuristic definition
    # -------------------
    variableHeuristic = SeaPearl.MinDomainVariableSelection{false}()


    metricsArray, eval_metricsArray = trytrain(
        nbEpisodes=n_episodes,
        evalFreq=Int(floor(n_episodes / n_eval)),
        nbInstances=n_instances,
        restartPerInstances=1,
        generator=kep_generator,
        variableHeuristic=variableHeuristic,
        learnedHeuristics=learnedHeuristics,
        basicHeuristics=basicHeuristics;
        out_solver=true,
        verbose=true,
        nbRandomHeuristics=0,
        exp_name="kep_representation_" * string(n_episodes) * "_" * string(n_nodes) * "_",
        eval_timeout=eval_timeout
    )
end

###############################################################################
######### Experiment Type 3
#########  
######### 
###############################################################################

function experiment_chosen_features_heterogeneous_kep(n_nodes, density, n_episodes, n_instances; n_eval=10, eval_timeout=60)
    """
    Compares the impact of the number of convolution layers for the heterogeneous representation.
    """
    kep_generator = SeaPearl.KepGenerator(n_nodes, density)

    chosen_features_list = [
        [
            Dict(
                "constraint_type" => true,
                "variable_initial_domain_size" => true,
                "values_onehot" => true,
            ), 
            [1, 6, 2]
        ],
        [
            Dict(
                "constraint_type" => true,
                "variable_initial_domain_size" => true,
                "values_raw" => true,
            ), 
            [1, 6, 1]
        ],
        [
            Dict(
                "constraint_type" => true,
                "variable_initial_domain_size" => true,
                "variable_domain_size" => true,
                "values_onehot" => true,
            ), 
            [2, 6, 2]
        ],
        [
            Dict(
                "constraint_activity" => true,
                "constraint_type" => true,
                "variable_initial_domain_size" => true,
                "values_onehot" => true,
            ), 
            [1, 7, 2]
        ],
        [
            Dict(
                "constraint_activity" => true,
                "constraint_type" => true,
                "variable_initial_domain_size" => true,
                "variable_domain_size" => true,
                "values_raw" => true,
            ), 
            [2, 7, 1]
        ],
        [
            Dict(
                "constraint_activity" => true,
                "constraint_type" => true,
                "nb_not_bounded_variable" => true,
                "variable_initial_domain_size" => true,
                "variable_domain_size" => true,
                "variable_is_bound" => true,
                "values_raw" => true,
            ), 
            [3, 8, 1]
        ],
    ]


    experiment_chosen_features_heterogeneous(n_nodes, n_episodes, n_instances;
        n_eval=n_eval,
        generator=kep_generator,
        chosen_features_list=chosen_features_list,
        type="kep",
        output_size=2,
        eval_timeout=eval_timeout)
end
###############################################################################
######### Experiment Type 4
#########  
######### 
###############################################################################
function experiment_nn_heterogeneous_kep(n_nodes, density, n_episodes, n_instances; n_layers_graph=3, n_eval=10, eval_timeout=600, reward=SeaPearl.GeneralReward, pool = SeaPearl.sumPooling())
    """
    Compare agents with different Fullfeatured CPNN pipeline
    """

    kep_generator =  SeaPearl.KepGenerator(n_nodes, density)

    expParameters = Dict(
        :generatorParameters => Dict(
            :nbNodes => n_nodes,
            :density => density
        ),
        :pooling => string(pool)
    )

    # Basic value-selection heuristic
    selectMax(x::SeaPearl.IntVar; cpmodel=nothing) = SeaPearl.maximum(x.domain)
    heuristic_max = SeaPearl.BasicHeuristic(selectMax)
    basicHeuristics = OrderedDict(
        "max" => heuristic_max
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

    experiment_nn_heterogeneous(n_nodes, n_episodes, n_instances;
    #chosen_features=chosen_features,
    feature_size = [5, 8, 1], #[2, 7, 1], 
    output_size = 2, 
    generator = kep_generator, 
    n_layers_graph = n_layers_graph, 
    n_eval = n_eval, 
    reward = reward, 
    type = "kep",
    c=2.0,
    basicHeuristics=basicHeuristics,
    pool = pool
)
end 
###############################################################################
######### Simple KEP experiment
#########  
######### 
###############################################################################

function simple_experiment_kep(n_nodes, density, n_episodes, n_instances; chosen_features=nothing, feature_size=nothing, n_eval=10, n_nodes_eva = n_nodes, density_eva = density,n_layers_graph=3, reward = SeaPearl.GeneralReward, c=2.0, trajectory_capacity=2000, pool = SeaPearl.meanPooling(), nbRandomHeuristics = 1, eval_timeout = 60, restartPerInstances = 10, seedEval = nothing)
    """
    Runs a single experiment on KEP
    """
    reward = SeaPearl.GeneralReward
    generator = SeaPearl.KepGenerator(n_nodes, density)
    n_step_per_episode = Int(n_nodes/2)

    if isnothing(chosen_features)
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
    feature_size = [5, 8, 1]

    end
    rngExp = MersenneTwister(seedEval)
    init = Flux.glorot_uniform(MersenneTwister(seedEval))

    SR_heterogeneous = SeaPearl.HeterogeneousStateRepresentation{SeaPearl.DefaultFeaturization,SeaPearl.HeterogeneousTrajectoryState}

    trajectory_capacity = 500*n_step_per_episode
    update_horizon = Int(round(n_step_per_episode//2))
    learnedHeuristics = OrderedDict{String,SeaPearl.LearnedHeuristic}()
    
    agent_24= get_heterogeneous_agent(;
    get_heterogeneous_trajectory = () -> get_heterogeneous_slart_trajectory(capacity=trajectory_capacity, n_actions=2),        
    get_explorer = () -> get_epsilon_greedy_explorer(Int(floor(n_episodes*n_step_per_episode*0.75)), 0.05; rng = rngExp ),
    batch_size=16,
    update_horizon=update_horizon,
    min_replay_history=Int(round(16*n_step_per_episode//2)),
    update_freq=1,
    target_update_freq=7*n_step_per_episode,
    get_heterogeneous_nn = () -> get_heterogeneous_fullfeaturedcpnn(
        feature_size=feature_size,
        conv_size=8,
        dense_size=16,
        output_size=1,
        n_layers_graph=24,
        n_layers_node=3,
        n_layers_output=2, 
        pool=pool,
        σ=NNlib.leakyrelu,
        init = init,
        device = cpu
    ),
    γ = 0.99f0
    )
    agent_6 = get_heterogeneous_agent(;
    get_heterogeneous_trajectory = () -> get_heterogeneous_slart_trajectory(capacity=trajectory_capacity, n_actions=2),        
    get_explorer = () -> get_epsilon_greedy_explorer(Int(floor(n_episodes*n_step_per_episode*0.75)), 0.05; rng = rngExp ),
    batch_size=16,
    update_horizon=update_horizon,
    min_replay_history=Int(round(16*n_step_per_episode//2)),
    update_freq=1,
    target_update_freq=7*n_step_per_episode,
    get_heterogeneous_nn = () -> get_heterogeneous_fullfeaturedcpnn(
        feature_size=feature_size,
        conv_size=8,
        dense_size=16,
        output_size=1,
        n_layers_graph=6,
        n_layers_node=3,
        n_layers_output=2, 
        pool=pool,
        σ=NNlib.leakyrelu,
        init = init,
        device = cpu
    ),
    γ = 0.99f0
    )
    agent_cpu = get_heterogeneous_agent(;
    get_heterogeneous_trajectory = () -> get_heterogeneous_slart_trajectory(capacity=trajectory_capacity, n_actions=2),        
    get_explorer = () -> get_epsilon_greedy_explorer(Int(floor(n_episodes*n_step_per_episode*0.75)), 0.05; rng = rngExp ),
    batch_size=64,
    update_horizon=update_horizon,
    min_replay_history=Int(round(16*n_step_per_episode//2)),
    update_freq=4,
    target_update_freq=7*n_step_per_episode,
    get_heterogeneous_nn = () -> get_heterogeneous_fullfeaturedcpnn(
        feature_size=feature_size,
        conv_size=8,
        dense_size=16,
        output_size=1,
        n_layers_graph=24,
        n_layers_node=2,
        n_layers_output=2, 
        pool=SeaPearl.meanPooling(),
        σ=NNlib.leakyrelu,
        init = init, 
        device = cpu
    ),
    γ = 0.99f0
    )
    agent_gpu = get_heterogeneous_agent(;
    get_heterogeneous_trajectory = () -> get_heterogeneous_slart_trajectory(capacity=trajectory_capacity, n_actions=2),        
    get_explorer = () -> get_epsilon_greedy_explorer(Int(floor(n_episodes*n_step_per_episode*0.75)), 0.05; rng = rngExp ),
    batch_size=64,
    update_horizon=update_horizon,
    min_replay_history=Int(round(16*n_step_per_episode//2)),
    update_freq=4,
    target_update_freq=7*n_step_per_episode,
    get_heterogeneous_nn = () -> get_heterogeneous_fullfeaturedcpnn(
        feature_size=feature_size,
        conv_size=8,
        dense_size=16,
        output_size=1,
        n_layers_graph=24,
        n_layers_node=2,
        n_layers_output=2, 
        pool=SeaPearl.meanPooling(),
        σ=NNlib.leakyrelu,
        init = init, 
        device = gpu
    ),
    γ = 0.99f0
    )

    learned_heuristic_24 = SeaPearl.SimpleLearnedHeuristic{SR_heterogeneous,reward,SeaPearl.FixedOutput}(agent_24; chosen_features=chosen_features)
    learned_heuristic_6 = SeaPearl.SimpleLearnedHeuristic{SR_heterogeneous,reward,SeaPearl.FixedOutput}(agent_6; chosen_features=chosen_features)
    learned_heuristic_cpu = SeaPearl.SimpleLearnedHeuristic{SR_heterogeneous,reward,SeaPearl.FixedOutput}(agent_cpu; chosen_features=chosen_features)
    learned_heuristic_gpu = SeaPearl.SimpleLearnedHeuristic{SR_heterogeneous,reward,SeaPearl.FixedOutput}(agent_gpu; chosen_features=chosen_features)
      
    learnedHeuristics["cpu"] = learned_heuristic_cpu
    learnedHeuristics["gpu"] = learned_heuristic_gpu
    #learnedHeuristics["24layer"] = learned_heuristic_24
     
    selectMax(x::SeaPearl.IntVar; cpmodel=nothing) = SeaPearl.maximum(x.domain)
    heuristic_max = SeaPearl.BasicHeuristic(selectMax)
    basicHeuristics = OrderedDict(
        "expert_max" => heuristic_max
    )

    variableHeuristic = SeaPearl.MinDomainVariableSelection{false}()

    metricsArray, eval_metricsArray = trytrain(
        nbEpisodes=n_episodes,
        evalFreq=Int(floor(n_episodes / n_eval)),
        nbInstances=n_instances,
        restartPerInstances=restartPerInstances,
        generator=generator,
        variableHeuristic=variableHeuristic,
        learnedHeuristics=learnedHeuristics,
        basicHeuristics=basicHeuristics;
        out_solver=true,
        verbose=true,
        nbRandomHeuristics=0,
        exp_name= "kep_"*string(n_nodes)*"_"*string(density)*"_"* string(n_episodes),
        eval_timeout=eval_timeout
    )
    nothing

end