import ArgParse.ArgParseSettings
import ArgParse.@add_arg_table
import ArgParse.parse_args
using CSV, DataFrames
using Random

function parse_commandline()
    """
    Parse the command line arguments and return a dictionary containing the values
    """
    s = ArgParseSettings()

    @add_arg_table s begin
        "--random_seed", "-s"
            help = "seed to intialize the random number generator"
            arg_type = Int
            default = 0
            required = false
        "--time_limit", "-t"
            help = "total CPU time (in seconds) allowed"
            arg_type = Int
            default = 1000000
            required = false
        "--memory_limit", "-m"
            help = "total amount of memory (in MiB) allowed"
            arg_type = Int
            default = 1000000
            required = false
        "--nb_core", "-c"
            help = "number of processing units allocated"
            arg_type = Int
            default = Base.Sys.CPU_THREADS
            required = false
        "--nbEpisodes", "-e"
            help = "number of episodes of training the agent"
            arg_type = Int
            default = 100
            required = false
        "--restartPerInstances"
            help = "number of restart per instance"
            arg_type = Int
            default = 10
            required = false
        "--nbInstances"
            help = "number of instances"
            arg_type = Int
            default = 10
            required = false
        "--nbRandomHeuristics"
            help = "number of random heuristics"
            arg_type = Int
            default = 1
            required = false
        "--nbNewVertices"
            help = "number of new vertices added at the original graph"
            arg_type = Int
            default = 10
            required = false
        "--nbInitialVertices"
            help = "number of vertice or the original graph"
            arg_type = Int
            default = 4
            required = false
        "--save_model"
            help = "save the model"
            arg_type = Bool
            default = false
            required = false
        "--csv_path"
            help = "name of the csv file path for saving performance, if not found, nothing is saved"
            arg_type = String
            required = false
    end
    return parse_args(s)
end

function set_settings()
    """
    Main function of the script
    """
    parsed_args = parse_commandline()

    random_seed = parsed_args["random_seed"]
    time_limit = parsed_args["time_limit"]
    memory_limit = parsed_args["memory_limit"]
    nb_core = parsed_args["nb_core"]
    nb_episodes = parsed_args["nbEpisodes"]
    restart_per_instances = parsed_args["restartPerInstances"]
    nb_instances = parsed_args["nbInstances"]
    nb_random_heuristics = parsed_args["nbRandomHeuristics"]
    nb_new_vertices = parsed_args["nbNewVertices"]
    nb_initial_vertices = parsed_args["nbInitialVertices"]
    save_model = parsed_args["save_model"]
    csv_path = parsed_args["csv_path"]

    eval_freq = ceil(nb_episodes/10)

    if isnothing(csv_path)
        csv_path = ""
        save_performance = false
    else
        save_performance = true
    end

    # @eval(Base.Sys, CPU_THREADS=$nb_core)

    Random.seed!(random_seed)

    mis_settings = MisExperimentSettings(nb_episodes, restart_per_instances, eval_freq, nb_instances, nb_random_heuristics, nb_new_vertices, nb_initial_vertices)
    instance_generator = SeaPearl.MaximumIndependentSetGenerator(mis_settings.nbNewVertices, mis_settings.nbInitialVertices)

    return mis_settings, instance_generator, csv_path, save_model
end
