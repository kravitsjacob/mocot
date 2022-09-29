# Loading MOCOT as dev package

using Pkg
Pkg.develop(path="simulation/src/MOCOT")
Pkg.instantiate()