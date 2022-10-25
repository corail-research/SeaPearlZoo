# Model definition
approximator_GNN = SeaPearl.GraphConv(16 => 16, Flux.leakyrelu)
target_approximator_GNN = SeaPearl.GraphConv(16 => 16, Flux.leakyrelu)
gnnlayers = 2

approximator_model = SeaPearl.CPNN(
    graphChain = Flux.Chain(
        SeaPearl.GraphConv(numInFeatures => 16, Flux.leakyrelu),
        [approximator_GNN for i = 1:gnnlayers]...
    ),
    nodeChain = Flux.Chain(
        Flux.Dense(16, 32, Flux.leakyrelu),
        Flux.Dense(32, 16, Flux.leakyrelu),
    ),
    outputChain = Flux.Dense(16, 2),
)
target_approximator_model = SeaPearl.CPNN(
    graphChain = Flux.Chain(
        SeaPearl.GraphConv(numInFeatures => 16, Flux.leakyrelu),
        [target_approximator_GNN for i = 1:gnnlayers]...
    ),
    nodeChain = Flux.Chain(
        Flux.Dense(16, 32, Flux.leakyrelu),
        Flux.Dense(32, 16, Flux.leakyrelu),
    ),
    outputChain = Flux.Dense(16, 2),
) |> gpu


agent = RL.Agent(
    policy = RL.QBasedPolicy(
        learner = RL.DQNLearner(
            approximator = RL.NeuralNetworkApproximator(
                model = approximator_model,
                optimizer = ADAM()
            ),
            target_approximator = RL.NeuralNetworkApproximator(
                model = target_approximator_model,
                optimizer = ADAM()
            ),
            loss_func = Flux.Losses.huber_loss,
            γ = 0.9f0,
            batch_size = 8, #32,
            update_horizon = 10, #what if the number of nodes in a episode is smaller
            min_replay_history = 8,
            update_freq = 8,
            target_update_freq = 100,
        ),
        explorer = RL.EpsilonGreedyExplorer(
            ϵ_stable = 0.01,
            #kind = :exp,
            decay_steps = nbEpisodes,
            step = 1,
            #rng = rng
        )
    ),
    trajectory = RL.CircularArraySLARTTrajectory(
        capacity = 1000,
        state = SeaPearl.DefaultTrajectoryState[] => (),
        legal_actions_mask = Vector{Bool} => (2, ),
    )
)