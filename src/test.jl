using PyCall
include("lake.jl")

@pyimport pandas as pd

# This is just a copy of the offending (or offended ;~) function in Platypus's PRIM,
# with a couple of print statements added.
py"""
import numpy as np
import numpy.lib.recfunctions as recfunctions

def make_box(x):
    '''
    Make a box that encompasses all the data

    Parameters
    ----------
    x : structured numpy array
    '''
    print "\nmake_box(%s):\n" % x

    # get the types in the order they appear in the numpy array
    types = [(v[1], k, v[0].name) for k, v in six.iteritems(x.dtype.fields)]
    types = sorted(types)
    print "types: ", types

    # convert any bool types to object to store set(False, True)
    ntypes = [(k, 'object' if t == 'bool' else t) for (_, k, t) in types]
    print "ntypes: ", ntypes

    # create box limits
    box = np.zeros((2, ), ntypes)
    print "box: ", box

    names = recfunctions.get_names(x.dtype)
    print "names: ", names

    for name in names:
        dtype = box.dtype.fields.get(name)[0]
        values = x[name]

        if isinstance(values, np.ma.MaskedArray):
            values = values.compressed()

        if dtype == 'object':
            try:
                values = set(values)
                box[name][:] = values
            except TypeError as e:
                logging.getLogger(__name__).warning("{} has unhashable values".format(name))
                raise e
        else:
            box[name][0] = np.min(values, axis=0)
            box[name][1] = np.max(values, axis=0)

    return box
"""

#
# Duplicate the guts of the Prim constructor to setup data structs to debug make_box.
#
function test(x, y; include=nothing, coi=nothing)
    df = DataFrame(x)

    if include != nothing
        if ! (include isa AbstractArray)
            include = [include]
        end

        colnames = [Symbol(name) for name in include]
        df = df[colnames]
    end
    
    dict = Dict(k => df[k] for k in names(df))
    pandasDF = pd.DataFrame(dict)

    # Convert y into Vector{Bool} by matching category of interest
    # Note that classification and coi can be strings or symbols,
    # as long as they're consistent (i.e., 'in' and '==' work.)
    if coi != nothing
        if coi isa AbstractArray
            y = [value in coi for value in y]
        else
            y = (y .== coi)
        end
    end

    recs = py"$pandasDF.to_records(index=False)"
    pycall(py"make_box", PyObject, recs)
end

test(results, classification, include=uncertainties, coi="Reliable")

# The call to make_box fails at the line:
#    box = np.zeros((2, ), ntypes)

# This works
@pyimport numpy as np
println("1:", np.zeros((2,), ntypes))

# This works
py"""
import numpy as np
ntypes = [('b', 'float64'), ('delta', 'float64'), ('mean', 'float64'), ('q', 'float64'), ('stdev', 'float64')]
print "2:", np.zeros((2,),  ntypes)
"""

# This fails, apparently due to the unicode strings.
py"""
import numpy as np
ntypes = [(u'b', 'float64'), (u'delta', 'float64'), (u'mean', 'float64'), (u'q', 'float64'), (u'stdev', 'float64')]
print "3:", np.zeros((2,),  ntypes)
"""

