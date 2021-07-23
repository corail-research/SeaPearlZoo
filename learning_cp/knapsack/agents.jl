# Model definition
approximator_GNN = GeometricFlux.GraphConv(64 => 64, Flux.σ)
target_approximator_GNN = GeometricFlux.GraphConv(64 => 64)
gnnlayers = 5

approximator_model = SeaPearl.CPNN(
    graphChain = Flux.Chain(
        GeometricFlux.GraphConv(numInFeatures => 64, Flux.leakyrelu),
        vcat([[approximator_GNN, SeaPearl.GraphNorm(64, Flux.leakyrelu)] for i = 1:gnnlayers]...)...
    ),
    nodeChain = Flux.Chain(
        Flux.Dense(64, 32, Flux.leakyrelu),
        Flux.Dense(32, 32, Flux.leakyrelu),
        Flux.Dense(32, 16, Flux.leakyrelu),
    ),
    outputChain = Flux.Dense(16, 2),
)
target_approximator_model = SeaPearl.CPNN(
    graphChain = Flux.Chain(
        GeometricFlux.GraphConv(numInFeatures => 64, Flux.leakyrelu),
        vcat([[approximator_GNN, SeaPearl.GraphNorm(64, Flux.leakyrelu)] for i = 1:gnnlayers]...)...
    ),
    nodeChain = Flux.Chain(
        Flux.Dense(64, 32, Flux.leakyrelu),
        Flux.Dense(32, 32, Flux.leakyrelu),
        Flux.Dense(32, 16, Flux.leakyrelu),
    ),
    outputChain = Flux.Dense(16, 2),
) |> gpu


filename = "model_weights_knapsack"*string(knapsack_generator.nb_items)*".bson"
if isfile(filename)
    println("Parameters loaded from ", filename)
    @load filename trained_weights
    Flux.loadparams!(approximator_model, trained_weights)
    Flux.loadparams!(target_approximator_model, trained_weights)
end

# Agent definition
agent = RL.Agent(
    policy = RL.QBasedPolicy(
        learner = RL.DQNLearner(
            approximator = RL.NeuralNetworkApproximator(
                model = approximator_model,
                optimizer = ADAM(0.0005f0)
            ),
            target_approximator = RL.NeuralNetworkApproximator(
                model = target_approximator_model,
                optimizer = ADAM(0.0005f0)
            ),
            loss_func = Flux.Losses.huber_loss,
            stack_size = nothing,
            γ = 0.99f0,
            batch_size = 32,
            update_horizon = 15,
            min_replay_history = 32,
            update_freq = 8,
            target_update_freq = 128,
        ), 
        explorer = RL.EpsilonGreedyExplorer(
            ϵ_stable = 0.001,
            kind = :exp,
            ϵ_init = 1.0,
            warmup_steps = 0,
            decay_steps = 5000,
            step = 1,
            is_break_tie = false, 
            #is_training = true,
            rng = MersenneTwister(33)
        )
    ),
    trajectory = RL.CircularArraySARTTrajectory(
        capacity = 128,
        state = SeaPearl.DefaultTrajectoryState[] => (),
    )
)
