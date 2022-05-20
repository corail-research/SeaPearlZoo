include("../common/experiment.jl")
include("../common/utils.jl")
include("comparison.jl")

###############################################################################
######### Experiment Type 1
#########  
######### 
###############################################################################

function experiment_representation_nqueens(board_size, n_episodes, n_instances; n_layers_graph=2, n_eval=10, reward=SeaPearl.GeneralReward)
    """
    Compare three agents:
        - an agent with the default representation and default features;
        - an agent with the default representation and chosen features;
        - an agent with the heterogeneous representation and chosen features.
    """
    nqueens_generator = SeaPearl.NQueensGenerator(board_size)

    expParameters = Dict(
        :generatorParameters => Dict(
            :boardSize => board_size,
        ),
    )

    experiment_representation(board_size, n_episodes, n_instances;
        chosen_features=nothing,
        feature_sizes = [3, 12, [2, 6, 1]], 
        output_size = board_size, 
        generator = nqueens_generator, 
        expParameters = expParameters, 
        basicHeuristics=nothing, 
        n_layers_graph=n_layers_graph, 
        n_eval=n_eval, 
        reward=reward, 
        type="nqueens", 
    )
end

for n in 5:5
    experiment_representation_nqueens(n, 1001, 10, n_layers_graph=3)
end

###############################################################################
######### Experiment Type 2
#########  
######### 
###############################################################################

function experiment_heterogeneous_n_conv(board_size, n_episodes, n_instances; n_eval=10)
    """
    Compares the impact of the number of convolution layers for the heterogeneous representation.
    """
    nqueens_generator = SeaPearl.ClusterizedGraphColoringGenerator(board_size)
    SR_heterogeneous = SeaPearl.HeterogeneousStateRepresentation{SeaPearl.DefaultFeaturization,SeaPearl.HeterogeneousTrajectoryState}

    chosen_features = Dict(
        "constraint_type" => true,
        "variable_initial_domain_size" => true,
        "values_onehot" => true,
    )

    expParameters = Dict(
        :generatorParameters => Dict(
            :boardSize => board_size,
        ),
    )

    experiment_n_conv(board_size, n_episodes, n_instances;
        n_eval=n_eval,
        generator=nqueens_generator,
        SR=SR_heterogeneous,
        chosen_features=chosen_features,
        feature_size=[1, 2, board_size],
        type="heterogeneous")
end

function experiment_default_chosen_n_conv(n_nodes, n_min_color, density, n_episodes, n_instances; n_eval=10)
    """
    Compares the impact of the number of convolution layers for the default representation.
    """
    nqueens_generator = SeaPearl.ClusterizedGraphColoringGenerator(n_nodes, n_min_color, density)
    SR_default = SeaPearl.DefaultStateRepresentation{SeaPearl.DefaultFeaturization,SeaPearl.DefaultTrajectoryState}

    chosen_features = Dict(
        "constraint_type" => true,
        "variable_initial_domain_size" => true,
        "values_onehot" => true,
    )

    expParameters = Dict(
        :generatorParameters => Dict(
            :boardSize => board_size,
        ),
    )

    experiment_n_conv(n_nodes, n_min_color, density, n_episodes, n_instances;
        n_eval=n_eval,
        generator=nqueens_generator,
        SR=SR_default,
        chosen_features=chosen_features,
        feature_size=6 + n_nodes,
        type="default_chosen")
end

function experiment_default_default_n_conv(board_size, n_episodes, n_instances; n_eval=10)
    """
    Compares the impact of the number of convolution layers for the default representation.
    """
    nqueens_generator = SeaPearl.ClusterizedGraphColoringGenerator(board_size)
    SR_default = SeaPearl.DefaultStateRepresentation{SeaPearl.DefaultFeaturization,SeaPearl.DefaultTrajectoryState}
    
    expParameters = Dict(
        :generatorParameters => Dict(
            :boardSize => board_size,
        ),
    )

    experiment_n_conv(n_nodes, n_min_color, density, n_episodes, n_instances;
        n_eval=n_eval,
        generator=nqueens_generator,
        SR=SR_default,
        feature_size=3,
        chosen_features=nothing,
        type="default_default")
end

# println("start experiment_1")
# experiment_heterogeneous_n_conv(10, 5, 0.95, 1001, 1)
# println("end experiment_1")

# experiment_default_chosen_n_conv(10, 5, 0.95, 1001, 10)
# experiment_default_default_n_conv(10, 5, 0.95, 1001, 10)

###############################################################################
######### Experiment Type 3
#########  
######### 
###############################################################################

function experiment_chosen_features_heterogeneous_nqueens(board_size, n_episodes, n_instances; n_eval=10)
    """
    Compares the impact of the number of convolution layers for the heterogeneous representation.
    """
    nqueens_generator = SeaPearl.NQueensGenerator(board_size)

    chosen_features_list = [
        [
            Dict(
                "constraint_type" => true,
                "variable_initial_domain_size" => true,
                "values_onehot" => true,
            ), 
            [1, 5, board_size]
        ],
        [
            Dict(
                "constraint_type" => true,
                "variable_initial_domain_size" => true,
                "values_raw" => true,
            ), 
            [1, 5, 1]
        ],
        [
            Dict(
                "constraint_type" => true,
                "variable_initial_domain_size" => true,
                "variable_domain_size" => true,
                "values_onehot" => true,
            ), 
            [2, 5, board_size]
        ],
        [
            Dict(
                "constraint_activity" => true,
                "constraint_type" => true,
                "variable_initial_domain_size" => true,
                "values_onehot" => true,
            ), 
            [1, 6, board_size]
        ],
        [
            Dict(
                "constraint_activity" => true,
                "constraint_type" => true,
                "variable_initial_domain_size" => true,
                "variable_domain_size" => true,
                "values_raw" => true,
            ), 
            [2, 6, 1]
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
            [3, 7, 1]
        ],
    ]

    expParameters = Dict(
        :generatorParameters => Dict(
            :boardSize => board_size,
        ),
    )

    experiment_chosen_features_heterogeneous(board_size, n_episodes, n_instances;
        n_eval=n_eval,
        generator=nqueens_generator,
        chosen_features_list=chosen_features_list,
        type="nqueens",
        output_size=board_size,
        expParameters=expParameters)
end

# experiment_chosen_features_heterogeneous_nqueens(20, 3001, 10)
# println("end")
nothing