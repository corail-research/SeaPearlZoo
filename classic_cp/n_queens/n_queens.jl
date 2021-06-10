using SeaPearl

struct OutputDataQueens
    nb_sols ::Int
    indices ::Matrix{Int}
end

"""
    struct MostCenteredVariableSelection{TakeObjective}

VariableSelection heuristic that selects the legal (ie. among the not bounded ones) most centered Queen.
"""
struct MostCenteredVariableSelection{TakeObjective} <: SeaPearl.AbstractVariableSelection{TakeObjective} end
###constructor###
MostCenteredVariableSelection(;take_objective = true) = MostCenteredVariableSelection{take_objective}()

function (::MostCenteredVariableSelection{false})(cpmodel::SeaPearl.CPModel)::SeaPearl.AbstractIntVar
    selectedVar = nothing
    n = length(cpmodel.variables)
    sorted_dict = sort(collect(SeaPearl.branchable_variables(cpmodel)),by = x -> abs(n/2-parse(Int, match(r"[0-9]*$", x[1]).match)),rev=true)
    while !isempty(sorted_dict)
        selectedVar = pop!(sorted_dict)[2]
        if !(selectedVar == cpmodel.objective) && !SeaPearl.isbound(selectedVar)
            break
        end
    end

    if SeaPearl.isnothing(selectedVar) && !SeaPearl.isbound(cpmodel.objective)
        return cpmodel.objective
    end
    return selectedVar
end

function (::MostCenteredVariableSelection{true})(cpmodel::SeaPearl.CPModel)::SeaPearl.AbstractIntVar
    selectedVar = nothing
    n = length(cpmodel.variables)
    sorted_dict = sort(collect(SeaPearl.branchable_variables(cpmodel)),by = x -> abs(n/2-parse(Int, match(r"[0-9]*$", x[1]).match)),rev=true)
    while true
        selectedVar= pop!(sorted_dict)[2]
        if !SeaPearl.isbound(selectedVar)
            break
        end
    end

    return selectedVar
end

"""
    model_queens(board_size::Int; benchmark=false, variableSelection=SeaPearl.MinDomainVariableSelection{false}(), valueSelection=SeaPearl.BasicHeuristic())

return the SeaPearl model for to the N-Queens problem, using SeaPearl.MinDomainVariableSelection heuristique
and  SeaPearl.AllDifferent (without solving it)

# Arguments
- `board_size::Int`: dimension of the board
- 'variableSelection': SeaPearl variable selection. By default: SeaPearl.MinDomainVariableSelection{false}() can be set to MostCenteredVariableSelection{false}()
- 'valueSelection': SeaPearl value selection. By default: =SeaPearl.BasicHeuristic()
"""
function model_queens(board_size::Int; benchmark=false, variableSelection=SeaPearl.MinDomainVariableSelection{false}(), valueSelection=SeaPearl.BasicHeuristic())
    trailer = SeaPearl.Trailer()
    model = SeaPearl.CPModel(trailer)

    rows = Vector{SeaPearl.AbstractIntVar}(undef, board_size)
    for i = 1:board_size
        rows[i] = SeaPearl.IntVar(1, board_size, "row_"*string(i), trailer)
        SeaPearl.addVariable!(model, rows[i]; branchable=true)
    end

    rows_plus = Vector{SeaPearl.AbstractIntVar}(undef, board_size)
    for i = 1:board_size
        rows_plus[i] = SeaPearl.IntVarViewOffset(rows[i], i, rows[i].id*"+"*string(i))
    end

    rows_minus = Vector{SeaPearl.AbstractIntVar}(undef, board_size)
    for i = 1:board_size
        rows_minus[i] = SeaPearl.IntVarViewOffset(rows[i], -i, rows[i].id*"-"*string(i))
    end

    push!(model.constraints, SeaPearl.AllDifferent(rows, trailer))
    push!(model.constraints, SeaPearl.AllDifferent(rows_plus, trailer))
    push!(model.constraints, SeaPearl.AllDifferent(rows_minus, trailer))

    return model
end

"""
    solve_queens(board_size::Int; benchmark=false, variableSelection=SeaPearl.MinDomainVariableSelection{false}(), valueSelection=SeaPearl.BasicHeuristic())

Solve the SeaPearl model for to the N-Queens problem, using SeaPearl.MinDomainVariableSelection heuristique
and  SeaPearl.AllDifferent, and the function model_queens.

# Arguments
- `board_size::Int`: dimension of the board
- 'variableSelection': SeaPearl variable selection. By default: SeaPearl.MinDomainVariableSelection{false}()
- 'valueSelection': SeaPearl value selection. By default: =SeaPearl.BasicHeuristic()
"""
function solve_queens(board_size::Int; benchmark=false, variableSelection=SeaPearl.MinDomainVariableSelection{false}(), valueSelection=SeaPearl.BasicHeuristic())
    model = model_queens(board_size::Int; benchmark=false, variableSelection=SeaPearl.MinDomainVariableSelection{false}(), valueSelection=SeaPearl.BasicHeuristic())
    status = @time SeaPearl.solve!(model; variableHeuristic=variableSelection, valueSelection=valueSelection)
    return model
end

"""
    solve_queens(model::SeaPearl.CPModel)

Solve the SeaPearl model for to the N-Queens problem, using an existing model

# Arguments
- `model::SeaPearl.CPModel`: model (from model_queens)
- 'variableSelection': SeaPearl variable selection. By default: SeaPearl.MinDomainVariableSelection{false}().
- 'valueSelection': SeaPearl value selection. By default: =SeaPearl.BasicHeuristic().
"""
function solve_queens(model::SeaPearl.CPModel; variableSelection=SeaPearl.MinDomainVariableSelection{false}(), valueSelection=SeaPearl.BasicHeuristic())
    status = @time SeaPearl.solve!(model; variableHeuristic=variableSelection, valueSelection=valueSelection)
    return model
end

"""
    outputFromSeaPearl(model::SeaPearl.CPModel; optimality=false)

Shows the results of the N-Queens problem as type OutputDataQueens.

# Arguments
- `model::SeaPearl.CPModel`: needs the model to be already solved (by solve_queens)
"""
function outputFromSeaPearl(model::SeaPearl.CPModel; optimality=false)
    solutions = model.statistics.solutions
    nb_sols = length(solutions)
    n = length(model.variables)
    indices = Matrix{Int}(undef, n, nb_sols)
    for (key,sol) in solutions
        for i in 1:n
            indices[i, key]= sol["row_"*string(i)]
        end
    end
    return OutputDataQueens(nb_sols, indices)
end

"""
    print_queens(model::SeaPearl.CPModel; nb_sols=typemax(Int))

Print at max nb_sols solutions to the N-queens problems.

# Arguments
- `model::SeaPearl.CPModel`: needs the model to be already solved (by solve_queens)
- 'nb_sols::Int' : maximum number of solutions to print
"""
function print_queens(model::SeaPearl.CPModel; nb_sols=typemax(Int))
    variables = model.variables
    solutions = model.statistics.solutions
    board_size = length(model.variables)
    count = 0
    println("The solver found "*string(length(solutions))*" solutions to the "*string(board_size)*"-queens problem. Let's show them.")
    println()
    for key in keys(solutions)
        if(count >= nb_sols)
            break
        end
        println("Solution "*string(count+1))
        count +=1
        sol = solutions[key]
        for i in 1:board_size
            ind_queen = sol["row_"*string(i)]
            for j in 1:board_size
                if (j==ind_queen) print("Q ") else print("_ ") end
            end
            println()
        end
        println()
    end
end

"""
    print_queens(board_size::Int; nb_sols=typemax(Int), benchmark=false, variableSelection=SeaPearl.MinDomainVariableSelection{false}(), valueSelection=SeaPearl.BasicHeuristic())

Print at max nb_sols solutions to the N-queens problems, N givern as the board_size entry.

# Arguments
- `board_size::Int`: dimension of the board
- 'nb_sols::Int' : maximum number of solutions to print
- 'variableSelection': SeaPearl variable selection. By default: SeaPearl.MinDomainVariableSelection{false}()
- 'valueSelection': SeaPearl value selection. By default: =SeaPearl.BasicHeuristic()
"""
function print_queens(board_size::Int; nb_sols=typemax(Int), benchmark=false, variableSelection=SeaPearl.MinDomainVariableSelection{false}(), valueSelection=SeaPearl.BasicHeuristic())
    model = solve_queens(board_size; variableSelection=variableSelection, valueSelection=valueSelection)
    variables = model.variables
    solutions = model.statistics.solutions
    count = 0
    println("The solver found "*string(length(solutions))*" solutions to the "*string(board_size)*"-queens problem. Let's show them.")
    println()
    for key in keys(solutions)
        if(count >= nb_sols)
            break
        end
        println("Solution "*string(count+1))
        count +=1
        sol = solutions[key]
        for i in 1:board_size
            ind_queen = sol["row_"*string(i)]
            for j in 1:board_size
                if (j==ind_queen) print("Q ") else print("_ ") end
            end
            println()
        end
        println()
    end
end

"""
    nb_solutions_queens(board_size::Int; benchmark=false, variableSelection=SeaPearl.MinDomainVariableSelection{false}(), valueSelection=SeaPearl.BasicHeuristic())::Int

return the number of solutions for to the N-Queens problem, using SeaPearl.MinDomainVariableSelection heuristique
and  SeaPearl.AllDifferent.

# Arguments
- `board_size::Int`: dimension of the board
- 'variableSelection': SeaPearl variable selection. By default: SeaPearl.MinDomainVariableSelection{false}()
- 'valueSelection': SeaPearl value selection. By default: =SeaPearl.BasicHeuristic()
"""
function nb_solutions_queens(board_size::Int; benchmark=false, variableSelection=SeaPearl.MinDomainVariableSelection{false}(), valueSelection=SeaPearl.BasicHeuristic())::Int
    return(length(solve_queens(board_size; variableSelection=variableSelection, valueSelection=valueSelection).statistics.solutions))
end
