#
# Sensitivity analysis related types and functions
#

struct Sensitivity <: Wrapper
    pyo::PyObject
    
    function Sensitivity(pyo::PyObject)
        new(pyo)
    end
end

struct SAResult  <: Wrapper
    pyo::PyObject

    function SAResult(pyo::PyObject)
        new(pyo)
    end
end

# Create a Python class that can store the SAResult (a subclass of dict) in 
# an instance var so we can access it without conversion. Otherwise, PyCall 
# converts it to a Dict and we can't use it as an argument to the plot routines
# that are methods of rhodium.SARsult.
py"""
import rhodium

class SAResultContainer(object):
    def __init__(self, sa_result):
        self.sa_result = sa_result

def my_sa(*args, **kwargs):
    sa_result = rhodium.sa(*args, **kwargs)
    return SAResultContainer(sa_result)
"""

function sa(m::Model, response; policy=Dict(), method="sobol", nsamples=1000, kwargs...)
    my_sa = py"my_sa"
    pyo = my_sa(m.pyo, response; policy=policy, method=method, nsamples=nsamples, kwargs...)
    return SAResult(pyo["sa_result"])   # access without conversion
end

function plot(sar::SAResult; kwargs...)
    return rhodium.SAResult[:plot](sar.pyo; kwargs...)
end

function plot_sobol(sar::SAResult; 
                    radSc=2.0, scaling=1, widthSc=0.5, STthick=1, varNameMult=1.3, 
                    colors=nothing, groups=nothing, gpNameMult=1.5, threshold="conf")

    fig = rhodium.SAResult[:plot_sobol](sar.pyo; radSc=radSc, scaling=scaling, widthSc=widthSc, 
                               STthick=STthick, varNameMult=varNameMult, 
                               colors=colors, groups=groups, gpNameMult=gpNameMult,
                               threshold=threshold)
    return fig
end

function oat(m::Model, response; policy=Dict(), nsamples::Int=100, kwargs...)
    fig = rhodium.oat(m.pyo, response; policy=policy, nsamples=nsamples, kwargs...)
    return fig
end