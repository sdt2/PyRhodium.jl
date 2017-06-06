using PyCall
using Conda

Conda.add("pip")
Conda.add("seaborn")
Conda.add("scikit-learn")
Conda.add("qt")

pip = joinpath(Conda.SCRIPTDIR, "pip")
run(`$pip install --no-deps mpldatacursor`)
run(`$pip install --no-deps pydotplus`)
run(`$pip install --no-deps SAlib`)
run(`$pip install --no-deps git+https://github.com/Project-Platypus/PRIM.git\#egg=prim`)
run(`$pip install --no-deps git+https://github.com/Project-Platypus/Platypus.git\#egg=platypus`)
run(`$pip install --no-deps git+https://github.com/Project-Platypus/Rhodium.git\#egg=rhodium`)
