# Loading MOCOT as dev package

using Pkg
Pkg.develop(path="analysis")
Pkg.develop(path="src/julia/MOCOT")
Pkg.instantiate()