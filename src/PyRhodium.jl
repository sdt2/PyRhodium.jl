module PyRhodium

using PyCall
using PyPlot
using IterableTables
using NamedTuples
using Distributions
@pyimport rhodium

export Model, Parameter, Response, RealLever, IntegerLever, Constraint, Brush,
    optimize, scatter2d, setparameters, setlevers, setresponses,
    setconstraints, scatter3d, pairs, parallel_coordinates, apply,
    evaluate, setuncertainties, sample_lhs

py"""
from rhodium import *
class JuliaModel(Model):
    
    def __init__(self, function, **kwargs):
        super(JuliaModel, self).__init__(self._evaluate)
        self.j_function = function
        
    def _evaluate(self, **kwargs):
        result = self.j_function(**kwargs)
        return result
"""

struct Model
    _m

    function Model(f)
        return new(py"JuliaModel($f)")
    end
end

struct Parameter
    _p
    function Parameter(name::AbstractString)
        return new(rhodium.Parameter("pollution_limit"))
    end
    
end

struct Response
    _r

    function Response(name::AbstractString, kind::Symbol)
        kind in (:MAXIMIZE, :MINIMIZE, :INFO) || error("The kind argument must be either :MAXIMIZE or :MINIMIZE")

        return new(rhodium.Response(name, rhodium.Response[kind]))
    end
    
end

struct Lever
    _l
end

struct Constraint
    _c

    function Constraint(con::AbstractString)
        return new(rhodium.Constraint(con))
    end
end

struct Brush
    _b
    function Brush(def::AbstractString)
        return new(rhodium.Brush(def))
    end
end

struct DataSet
    _pydataset
end

struct Output{T}
    _m::Model
    _o
end

@generated function Base.getindex{T}(o::Output{T}, i::Int)
    constructor_call = Expr(:call, :($T))
    for (i,t) in enumerate(T.parameters)
        push!(constructor_call.args, :(o._o[i][$( String(fieldnames(T)[i]) )]))
    end

    quote        
        return $constructor_call
    end
end

function Base.length{T}(o::Output{T})
    return length(o._o)
end

function Base.eltype{T}(o::Output{T})
    return T
end

function Base.start{T}(iter::Output{T})
    return 1
end

@generated function convert_to_NT{T}(::Type{T}, d::Dict)
    constructor_call = Expr(:call, :($T))
    for (i,t) in enumerate(T.parameters)
        push!(constructor_call.args, :(d[$( String(fieldnames(T)[i]) )]))
    end

    quote        
        return $constructor_call
    end
end

@generated function Base.next{T}(o::Output{T}, state)
    constructor_call = Expr(:call, :($T))
    for (i,t) in enumerate(T.parameters)
        push!(constructor_call.args, :(source[i][$( String(fieldnames(T)[i]) )]))
    end

    quote
        i = state
        source = o._o
        a = $constructor_call
        return a, state+1
    end
end

function Base.done{T}(o::Output{T}, state)
    return state>length(o)
end

function setparameters(m::Model, parameters::Vector{Parameter})
    m._m[:parameters] = map(i->i._p, parameters)
    return nothing
end

function setparameters{T<:Union{Symbol,Pair{Symbol,Any}}}(m::Model, parameters::Vector{T})
    m._m[:parameters] = map(parameters) do i
        if isa(i, Symbol)
            return rhodium.Parameter(String(i))
        else
            return rhodium.Parameter(String(i.first), i.second)
        end
    end
    nothing
end

function setresponses(m::Model, responses::Vector{Response})
    m._m[:responses] = map(i->i._r, responses)
    return nothing
end

function setresponses(m::Model, responses::Vector{Pair{Symbol,Symbol}})
    m._m[:responses] = map(responses) do i        
        i.second in (:MAXIMIZE, :MINIMIZE, :INFO) || error("The kind argument must be either :MAXIMIZE or :MINIMIZE")
        return rhodium.Response(String(i.first), rhodium.Response[i.second])
    end
    nothing
end

function setlevers(m::Model, levers::Vector{Lever})
    m._m[:levers] = map(i->i._l, levers)
    return nothing
end

function setconstraints(m::Model, constraints::Vector{Constraint})
    m._m[:constraints] = map(i->i._c, constraints)
    return nothing
end

function setconstraints(m::Model, constraints::Vector{String})
    m._m[:constraints] = map(constraints) do i        
        return rhodium.Constraint(i)
    end
    nothing    
end

function setconstraints(m::Model, constraints::Vector{Any})
    m._m[:constraints] = map(i->i._c, constraints)
    return nothing
end

function IntegerLever(name::AbstractString, min, max; length=1)
    return Lever(rhodium.IntegerLever(name, min, max, length=length))
end

function RealLever(name::AbstractString, min, max; length=1)
    return Lever(rhodium.RealLever(name, min, max, length=length))
end

function setuncertainties(m::Model, uncertainties::Vector{Pair{Symbol,T}} where T)
    m._m[:uncertainties] = map(uncertainties) do i
        if isa(i.second, Distributions.Uniform{Float64})
            rhodium.UniformUncertainty(string(i.first), i.second.a, i.second.b)
        else
            error("This distribution type is currently not supported by Rhodium")
        end
    end
    return nothing
end

function sample_lhs(m::Model, nsamples::Int)
    py_output = pycall(rhodium.sample_lhs, PyAny, m._m, nsamples)

    first_el = py_output[1]
    names = Symbol.(collect(keys(first_el)))
    types = typeof.(collect(values(first_el)))

    col_expressions = Array{Expr,1}()
    for i in 1:length(names)
        etype = types[i]
    push!(col_expressions, Expr(:(::), names[i], etype))
    end
    t_expr = NamedTuples.make_tuple(col_expressions)
        
    t = eval(t_expr)

    output = [t(values(i)...) for i in py_output]

    return output
end


function optimize(m::Model, algorithm, trials)
    py_output = pycall(rhodium.optimize, PyObject, m._m, algorithm, trials)

    t2 = :(Output{Any})
    if length(py_output) > 0
        first_el = py_output[1]
        names = Symbol.(collect(keys(first_el)))
        types = typeof.(collect(values(first_el)))


        col_expressions = Array{Expr,1}()
        for i in 1:length(names)
            etype = types[i]
            push!(col_expressions, Expr(:(::), names[i], etype))
        end
        t_expr = NamedTuples.make_tuple(col_expressions)
        
        t2.args[2] = t_expr
    end

    t = eval(t2)

    output = t(m, py_output)

    return output
end

function evaluate(m::Model, policy::Dict{Symbol,T} where T)
    py_output = pycall(rhodium.evaluate, PyDict, m._m, policy)

    names = [convert(Symbol,i) for i in keys(py_output)]
    types = [typeof(i) for i in values(py_output)]

    col_expressions = Array{Expr,1}()
    for i in 1:length(names)
        etype = types[i]
        push!(col_expressions, Expr(:(::), names[i], etype))
    end
    t_expr = NamedTuples.make_tuple(col_expressions)
    t = eval(t_expr)

    output = t(values(py_output)...)

    return output
end

function evaluate(m::Model, policy::NamedTuple)
    return evaluate(m, Dict(k=>v for (k,v) in zip(keys(policy), values(policy))))
end

function evaluate(m::Model, policies::Vector{Dict{Symbol,T}} where T)
    py_output = pycall(rhodium.evaluate, PyObject, m._m, policies)

    ds = DataSet(py_output)

    # println("WORKED")

    # first_el = py_output[1]
    # names = Symbol.(collect(keys(first_el)))
    # types = typeof.(collect(values(first_el)))

    # col_expressions = Array{Expr,1}()
    # for i in 1:length(names)
    #     etype = types[i]
    # push!(col_expressions, Expr(:(::), names[i], etype))
    # end
    # t_expr = NamedTuples.make_tuple(col_expressions)
        
    # t = eval(t_expr)

    # output = [t(values(i)...) for i in py_output]    

    return ds
end

function apply(results::DataSet, criterion)
    asdf = results._pydataset[:apply](criterion)

    return asdf
end

function evaluate(m::Model, policies::Vector{T} where T<:NamedTuple)
    output = evaluate(m, [Dict(k=>v for (k,v) in zip(keys(policy), values(policy))) for policy in policies])

    return output
end


function Base.findmax{T}(o::Output{T}, key::Symbol)
    res = o._o[:find_max](String(key))
    return convert_to_NT(T, res)
end

function Base.findmin{T}(o::Output{T}, key::Symbol)
    res = o._o[:find_min](String(key))
    return convert_to_NT(T, res)
end

function Base.find{T}(o::Output{T}, expr; inverse=false)
    res = o._o[:find](expr, inverse=inverse)
    return convert_to_NT.(T, res)
end

function apply{T}(o::Output{T}, expr; update=false)
    res = o._o[:apply](expr, update=update)
    return res
end

function scatter2d(o::Output; brush=nothing, kwargs...)
    if brush!=nothing
        push!(kwargs, (:brush, map(i->i._b, brush)))
    end
    return rhodium.scatter2d(o._m._m, o._o; kwargs...)
end

function scatter3d(o::Output; brush=nothing, kwargs...)
    if brush!=nothing
        push!(kwargs, (:brush, map(i->i._b, brush)))
    end
    return rhodium.scatter3d(o._m._m, o._o; kwargs...)
end

function pairs(o::Output; brush=nothing, kwargs...)
    if brush!=nothing
        push!(kwargs, (:brush, map(i->i._b, brush)))
    end
    return rhodium.pairs(o._m._m, o._o; kwargs...)
end

function parallel_coordinates(o::Output; brush=nothing, kwargs...)
    if brush!=nothing
        push!(kwargs, (:brush, map(i->i._b, brush)))
    end
    return rhodium.parallel_coordinates(o._m._m, o._o; kwargs...)
end

end # module
