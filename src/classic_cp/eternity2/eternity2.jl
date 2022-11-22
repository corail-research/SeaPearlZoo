using SeaPearl

"""
Proposition for using SeaPearl CP solver for the Eternity II puzzle
Reference https://en.wikipedia.org/wiki/Eternity_II_puzzle
"""

include("eternityIOmanager.jl")


struct OutputDataEternityII
    nb_sols ::Int
    orientation::Array{Int, 4} # dims = (nb_sols, n, m, 5) where five corresponds to (id, u,r, d, l) (u=upper edge, ...)
end


"""
    model_eternity2(input_file; order=[1,2,3,4], limit=nothing)

return the SeaPearl model for to the solve_eternity2 problem using SeaPearl.AllDifferent  and SeaPearl.TableConstraint (without solving it)

# Arguments
- `input_file`: file containing the pieces of the game as well as the dimensions
- 'order' : Vector, giving the order of edges for the IO manager. example : [1,4,2,3] means it is given as [up,down,left,right]
- 'limit' : Int, giving the number of solutions after which it will stop searching. if nothing given, it will lookk for all the solutions
"""
function model_eternity2(input_file; order=[1,2,3,4], limit=nothing)
    trailer = SeaPearl.Trailer()
    model = SeaPearl.CPModel(trailer)
    model.limit.numberOfSolutions = limit
    inputData = getEternityInputData(input_file;order=order)
    n = inputData.n
    m = inputData.m
    pieces = inputData.pieces

    table = Matrix{Int}(undef, 5, 4*n*m)

    maxi = maximum(pieces)

    for i = 1:n*m
        for k = 1:4
            table[1,4*(i-1) + k] = i
            for j = 2:5
                table[j,4*(i-1) + k] = pieces[i, (j+k+1)%4+1]
            end
        end
    end


    id = Matrix{SeaPearl.AbstractIntVar}(undef, n, m)
    u = Matrix{SeaPearl.AbstractIntVar}(undef, n, m) # up
    r = Matrix{SeaPearl.AbstractIntVar}(undef, n, m) # right
    d = Matrix{SeaPearl.AbstractIntVar}(undef, n, m) # down
    l = Matrix{SeaPearl.AbstractIntVar}(undef, n, m) # left

    for i = 1:n, j=1:m
        id[i,j] = SeaPearl.IntVar(1, n*m, "id_"*string(i)*string(j), trailer)
        SeaPearl.addVariable!(model, id[i,j]; branchable=true)
        u[i,j] = SeaPearl.IntVar(0, maxi, "u_"*string(i)*string(j), trailer)
        SeaPearl.addVariable!(model, u[i,j]; branchable=false)
        r[i,j] = SeaPearl.IntVar(0, maxi, "r_"*string(i)*string(j), trailer)
        SeaPearl.addVariable!(model, r[i,j]; branchable=false)
        d[i,j] = SeaPearl.IntVar(0, maxi, "d_"*string(i)*string(j), trailer)
        SeaPearl.addVariable!(model, d[i,j]; branchable=false)
        l[i,j] = SeaPearl.IntVar(0, maxi, "l_"*string(i)*string(j), trailer)
        SeaPearl.addVariable!(model, l[i,j]; branchable=false)

        vars = SeaPearl.AbstractIntVar[id[i,j], u[i,j], r[i,j],d[i,j], l[i,j]]
        push!(model.constraints, SeaPearl.TableConstraint(vars, table, trailer))

        if (j==m) push!(model.constraints, SeaPearl.EqualConstant(r[i,j], 0, trailer)) end
        if (j==1) push!(model.constraints, SeaPearl.EqualConstant(l[i,j], 0, trailer)) end
        if (i==1) push!(model.constraints, SeaPearl.EqualConstant(u[i,j], 0, trailer)) end
        if (i==n) push!(model.constraints, SeaPearl.EqualConstant(d[i,j], 0, trailer)) end
    end
    for i = 1:n, j=1:m
        if (j<m) push!(model.constraints, SeaPearl.Equal(r[i,j], l[i,j+1], trailer)) end
        if (i<n) push!(model.constraints, SeaPearl.Equal(d[i,j], u[i+1,j], trailer)) end
    end

    #breaking some symmetries

    #if count(==(2),count(==(0),pieces,dims=2))==4
        #index = findfirst(==(2),vec(count(==(0),pieces,dims=2)))
        #push!(model.constraints,SeaPearl.EqualConstant(id[1,1], index, trailer))
        #SeaPearl.assign!(id[1,1].domain, index)
    #end


    push!(model.constraints, SeaPearl.AllDifferent(id, trailer))
    model.adhocInfo = Dict([("n", n), ("m", m)])
    return model
end

"""
    model_eternity2_fast(input_file; order=[1,2,3,4], limit=nothing)

return the SeaPearl model for to the solve_eternity2 problem, using SeaPearl.AllDifferent  and SeaPearl.TableConstraint (without solving it). It uses less variables than v1. To be used with print_fast

# Arguments
- `input_file`: file containing the pieces of the game as well as the dimensions
- 'order' : Vector, giving the order of edges for the IO manager. example : [1,4,2,3] means it is given as [up,down,left,right]
- 'limit' : Int, giving the number of solutions after which it will stop searching. if nothing given, it will lookk for all the solutions
"""
function model_eternity2_fast(input_file; order=[1,2,3,4], limit=nothing)
    trailer = SeaPearl.Trailer()
    model = SeaPearl.CPModel(trailer)
    model.limit.numberOfSolutions = limit
    inputData = getEternityInputData(input_file;order=order)
    n = inputData.n
    m = inputData.m
    pieces = inputData.pieces

    table = Matrix{Int}(undef, 5, 4*n*m)

    maxi = maximum(pieces)

    for i = 1:n*m
        for k = 1:4
            table[1,4*(i-1) + k] = i
            for j = 2:5
                table[j,4*(i-1) + k] = pieces[i, (j+k+1)%4+1]
            end
        end
    end


    id = Matrix{SeaPearl.AbstractIntVar}(undef, n, m)
    u = Matrix{SeaPearl.AbstractIntVar}(undef, n, m)#up
    r = Matrix{SeaPearl.AbstractIntVar}(undef, n, m)#right
    d = Matrix{SeaPearl.AbstractIntVar}(undef, n, m)#down
    l = Matrix{SeaPearl.AbstractIntVar}(undef, n, m)#left
    src_v = Matrix{SeaPearl.AbstractIntVar}(undef,n,m+1) #horizontal edges
    src_h = Matrix{SeaPearl.AbstractIntVar}(undef,n+1,m) #vertical edges

    for i = 1:n
        src_v[i,m+1] = SeaPearl.IntVar(0, maxi, "src_v"*string(i)*string(m+1), trailer)
        SeaPearl.addVariable!(model, src_v[i,m+1]; branchable=false)
    end
    for j =1:m
        src_h[n+1,j] = SeaPearl.IntVar(0, maxi, "src_h"*string(n+1)*string(j), trailer)
        SeaPearl.addVariable!(model, src_h[n+1,j]; branchable=false)
    end


    for i = 1:n, j=1:m
        id[i,j] = SeaPearl.IntVar(1, n*m, "id_"*string(i)*string(j), trailer)
        SeaPearl.addVariable!(model, id[i,j]; branchable=true)

        src_v[i,j] = SeaPearl.IntVar(0, maxi, "src_v"*string(i)*string(j), trailer)
        SeaPearl.addVariable!(model, src_v[i,j]; branchable=false)
        src_h[i,j] = SeaPearl.IntVar(0, maxi, "src_h"*string(i)*string(j), trailer)
        SeaPearl.addVariable!(model, src_h[i,j]; branchable=false)
    end

    for i = 1:n, j=1:m
        u[i,j] = src_h[i,j]
        d[i,j] = src_h[i+1,j]
        l[i,j] = src_v[i,j]
        r[i,j] = src_v[i,j+1]

        vars = SeaPearl.AbstractIntVar[id[i,j], u[i,j], r[i,j],d[i,j], l[i,j]]
        push!(model.constraints, SeaPearl.TableConstraint(vars, table, trailer))

        if (j==m) push!(model.constraints, SeaPearl.EqualConstant(r[i,j], 0, trailer)) end
        if (j==1) push!(model.constraints, SeaPearl.EqualConstant(l[i,j], 0, trailer)) end
        if (i==1) push!(model.constraints, SeaPearl.EqualConstant(u[i,j], 0, trailer)) end
        if (i==n) push!(model.constraints, SeaPearl.EqualConstant(d[i,j], 0, trailer)) end
    end

    #breaking some symmetries

    #if count(==(2),count(==(0),pieces,dims=2))==4
        #index = findfirst(==(2),vec(count(==(0),pieces,dims=2)))
        #push!(model.constraints,SeaPearl.EqualConstant(id[1,1], index, trailer))
        #SeaPearl.assign!(id[1,1].domain, index)
    #end


    push!(model.constraints, SeaPearl.AllDifferent(id, trailer))
    model.adhocInfo = Dict([("n", n), ("m", m)])
    return model
end

"""
    model_eternity2_rotation(input_file; order=[1,2,3,4], limit=nothing)

return the SeaPearl model for to the solve_eternity2 problem, using SeaPearl.AllDifferent  and SeaPearl.TableConstraint (without solving it). This time, it branches on id+orientation, which could be more conveninent for learning, but it adds variables.

# Arguments
- `input_file`: file containing the pieces of the game as well as the dimensions
- 'order' : Vector, giving the order of edges for the IO manager. example : [1,4,2,3] means it is given as [up,down,left,right]
- 'limit' : Int, giving the number of solutions after which it will stop searching. if nothing given, it will lookk for all the solutions
"""
function model_eternity2_rotation(input_file; order=[1,2,3,4], limit=nothing)
    trailer = SeaPearl.Trailer()
    model = SeaPearl.CPModel(trailer)
    model.limit.numberOfSolutions = limit
    inputData = getEternityInputData(input_file;order=order)
    n = inputData.n
    m = inputData.m
    pieces = inputData.pieces

    table = Matrix{Int}(undef, 6, 4*n*m) #n*m pieces with for different orientation, 6 for orientation + id + u + r + d +

    maxi = maximum(pieces)
    orientation = Matrix{SeaPearl.AbstractIntVar}(undef, n,m)


    for i = 1:n*m
        for k = 1:4
            table[1,4*(i-1) + k] = i
            table[6,4*(i-1) + k] = 4*(i-1) + k
            for j = 2:5
                table[j,4*(i-1) + k] = pieces[i, (j+k+1)%4+1]
            end
        end
    end


    id = Matrix{SeaPearl.AbstractIntVar}(undef, n, m)
    u = Matrix{SeaPearl.AbstractIntVar}(undef, n, m)#up
    r = Matrix{SeaPearl.AbstractIntVar}(undef, n, m)#right
    d = Matrix{SeaPearl.AbstractIntVar}(undef, n, m)#down
    l = Matrix{SeaPearl.AbstractIntVar}(undef, n, m)#left

    src_v = Matrix{SeaPearl.AbstractIntVar}(undef,n,m+1) #vertical edges
    src_h = Matrix{SeaPearl.AbstractIntVar}(undef,n+1,m) #horizontal edges

    for i = 1:n
        src_v[i,m+1] = SeaPearl.IntVar(0, maxi, "src_v"*string(i)*string(m+1), trailer)
        SeaPearl.addVariable!(model, src_v[i,m+1]; branchable=false)
    end
    for j =1:m
        src_h[n+1,j] = SeaPearl.IntVar(0, maxi, "src_h"*string(n+1)*string(j), trailer)
        SeaPearl.addVariable!(model, src_h[n+1,j]; branchable=false)
    end


    for i = 1:n, j=1:m
        orientation[i,j] = SeaPearl.IntVar(1, 4*n*m, "orientation_"*string(i)*string(j), trailer)
        SeaPearl.addVariable!(model, orientation[i,j]; branchable=true)
        id[i,j] = SeaPearl.IntVar(1, n*m, "id_"*string(i)*string(j), trailer)
        SeaPearl.addVariable!(model, id[i,j]; branchable=false)
        src_v[i,j] = SeaPearl.IntVar(0, maxi, "src_v"*string(i)*string(j), trailer)
        SeaPearl.addVariable!(model, src_v[i,j]; branchable=false)
        src_h[i,j] = SeaPearl.IntVar(0, maxi, "src_h"*string(i)*string(j), trailer)
        SeaPearl.addVariable!(model, src_h[i,j]; branchable=false)
    end

    for i = 1:n, j=1:m
        u[i,j] = src_h[i,j]
        d[i,j] = src_h[i+1,j]
        l[i,j] = src_v[i,j]
        r[i,j] = src_v[i,j+1]

        vars = SeaPearl.AbstractIntVar[id[i,j], u[i,j], r[i,j],d[i,j], l[i,j], orientation[i,j]]
        push!(model.constraints, SeaPearl.TableConstraint(vars, table, trailer))

        if (j==m) push!(model.constraints, SeaPearl.EqualConstant(r[i,j], 0, trailer)) end
        if (j==1) push!(model.constraints, SeaPearl.EqualConstant(l[i,j], 0, trailer)) end
        if (i==1) push!(model.constraints, SeaPearl.EqualConstant(u[i,j], 0, trailer)) end
        if (i==n) push!(model.constraints, SeaPearl.EqualConstant(d[i,j], 0, trailer)) end
    end

    push!(model.constraints, SeaPearl.AllDifferent(id, trailer))
    model.adhocInfo = Dict([("n", n), ("m", m)])
    return model
end

"""
    solve_eternity2(input_file; order=[1,2,3,4], variableSelection=SeaPearl.MinDomainVariableSelection{false}(), valueSelection=SeaPearl.BasicHeuristic(), limit=nothing)

Solve the SeaPearl model for to the eternity2 problem, using SeaPearl.MinDomainVariableSelection heuristique
and  SeaPearl.AllDifferent and SeaPearl.TableConstraint, and the function model_AIS

# Arguments
- 'input_file': String; path to the data
- 'order' : Vector, giving the order of edges for the IO manager. example : [1,4,2,3] means it is given as [up,down,left,right]
- 'variableSelection': SeaPearl variable selection. By default: SeaPearl.MinDomainVariableSelection{false}()
- 'valueSelection': SeaPearl value selection. By default: =SeaPearl.BasicHeuristic()
- 'limit' : Int, giving the number of solutions after which it will stop searching. if nothing given, it will lookk for all the solutions
- 'model' : Function; model to use, defaults to model_eternity2_fast
"""
function solve_eternity2(
        input_file; 
        order=[1, 2, 3, 4], 
        variableSelection=SeaPearl.MinDomainVariableSelection{false}(), 
        valueSelection=SeaPearl.BasicHeuristic(), 
        limit=1, 
        model=model_eternity2_fast
    )
    model = model(input_file; order=order, limit)
    status = @time SeaPearl.solve!(model; variableHeuristic=variableSelection, valueSelection=valueSelection)
    return model
end

"""
    solve_eternity2(model::SeaPearl.CPModel;benchmark=false, variableSelection=SeaPearl.MinDomainVariableSelection{false}(), valueSelection=SeaPearl.BasicHeuristic())

Solve the SeaPearl model for to the eternity2 problem, using an existing model (from model_eternity2)

# Arguments
- `model::SeaPearl.CPModel`: model (from model_AIS)
- 'variableSelection': SeaPearl variable selection. By default: SeaPearl.MinDomainVariableSelection{false}()
- 'valueSelection': SeaPearl value selection. By default: =SeaPearl.BasicHeuristic()
"""
function solve_eternity2(model::SeaPearl.CPModel; variableSelection=SeaPearl.MinDomainVariableSelection{false}(), valueSelection=SeaPearl.BasicHeuristic())
    status = @time SeaPearl.solve!(model; variableHeuristic=variableSelection, valueSelection=valueSelection)
    return model
end

"""
    outputFromSeaPearl(model::SeaPearl.CPModel; optimality=false)

Return the results of the eternity2 problem as type OutputDataEternity, taking the solved model as argument

# Arguments
- `model::SeaPearl.CPModel`: needs the model to be already solved (by solve_eternity2)
"""
function outputFromSeaPearl(model::SeaPearl.CPModel)
    solutions = model.statistics.solutions
    nb_sols = length(solutions)
    n = model.adhocInfo["n"]
    m = model.adhocInfo["m"]
    orientation = Array{Int, 4}(undef, nb_sols, n,m,5)
    for (ind,sol) in enumerate(solutions)
        for i in 1:n, j in 1:m
            orientation[ind, i, j,1]= sol["id_"*string(i)*string(j)]
            orientation[ind, i, j, 2] = sol["u_"*string(i)*string(j)]
            orientation[ind, i, j, 3] = sol["r_"*string(i)*string(j)]
            orientation[ind, i, j, 4] = sol["d_"*string(i)*string(j)]
            orientation[ind, i, j, 5] = sol["l_"*string(i)*string(j)]
        end
    end
    return OutputDataEternityII(nb_sols, orientation)
end

function outputFromSeaPearl_fast_orientation(model::SeaPearl.CPModel; optimality=false)
    solutions = model.statistics.solutions
    nb_sols = length(solutions)
    n = model.adhocInfo["n"]
    m = model.adhocInfo["m"]
    orientation = Array{Int, 4}(undef, nb_sols, n,m,5)
    for (ind,sol) in enumerate(solutions)
        for i in 1:n, j in 1:m
            orientation[ind, i, j,1]= sol["id_"*string(i)*string(j)]
            orientation[ind, i, j, 2] = sol["src_h"*string(i)*string(j)]
            orientation[ind, i, j, 3] = sol["src_v"*string(i)*string(j+1)]
            orientation[ind, i, j, 4] = sol["src_h"*string(i+1)*string(j)]
            orientation[ind, i, j, 5] = sol["src_v"*string(i)*string(j)]
        end
    end
    return OutputDataEternityII(nb_sols, orientation)
end