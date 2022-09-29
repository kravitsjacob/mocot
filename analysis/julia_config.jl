# Loading MOCOT as dev package

using Pkg
Pkg.develop(path="src/julia/MOCOT")
Pkg.develop(path="analysis")
Pkg.instantiate()