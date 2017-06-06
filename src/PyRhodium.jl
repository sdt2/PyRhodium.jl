module PyRhodium

using PyCall
using PyPlot
@pyimport rhodium

export Model, Parameter, Response, RealLever, optimize, scatter2d, setparameters,
    setlevers, setresponses

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
        kind in (:MAXIMIZE, :MINIMIZE) || error("The kind argument must be either :MAXIMIZE or :MINIMIZE")

        return new(rhodium.Response(name, rhodium.Response[kind]))
    end
    
end

struct Lever
    _l
end

struct Output
    _m::Model
    _o
end

function Base.length(o::Output)
    return length(o._o)
end

function setparameters(m::Model, parameters::Vector{Parameter})
    m._m[:parameters] = map(i->i._p, parameters)
    return nothing
end

function setresponses(m::Model, responses::Vector{Response})
    m._m[:responses] = map(i->i._r, responses)
    return nothing
end

function setlevers(m::Model, levers::Vector{Lever})
    m._m[:levers] = map(i->i._l, levers)
    return nothing
end


function RealLever(name::AbstractString, min, max; length=0)
    return Lever(rhodium.RealLever(name, min, max, length=length))
end

function optimize(m::Model, algorithm, trials)
    output = Output(m, pycall(rhodium.optimize, PyObject, m._m, algorithm, trials))
end

function scatter2d(o::Output)
    return rhodium.scatter2d(o._m._m, o._o)
end

end # module
