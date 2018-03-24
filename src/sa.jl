#
# Sensitivity analysis related types and functions
#

struct Sensitivity <: Wrapper
    pyo::PyObject
    
    function Sensitivity(pyo::PyObject)
        new(pyo)
    end
end

#function sa(m::Model, "reliability", policy=policy, method="morris", nsamples=1000, num_levels=4, grid_jump=2)

struct SAResult <: Wrapper
    pyo::PyObject   # a subclass of py dict

    function SAResult(pyo::PyObject)
        new(pyo)
    end
end

plot(sa::SAResult; kwargs...) = sa.pyo[:plot](kwargs...)

function plot_sobol(sa::SAResult; 
                    radSc=2.0, scaling=1, widthSc=0.5, STthick=1, varNameMult=1.3, 
                    colors=nothing, groups=nothing, gpNameMult=1.5, threshold="conf")

    fig = sa.pyo[:plot_sobol](radSc=radSc, scaling=scaling, widthSc=widthSc, 
                              STthick=STthick, varNameMult=varNameMult, 
                              colors=colors, groups=groups, gpNameMult=gpNameMult,
                              threshold=threshold)
    return fig
end

function oat(m::Model, response, policy=Dict(), nsamples=100, kwargs...)
    fig = pycall(rhodium.oat, PyObject, response, policy, nsamples=nsamples, kwargs...)
    return fig
end