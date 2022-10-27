# Loading MOCOT as dev package

using Pkg
try
    Pkg.develop(path="simulation/src/MOCOT")
catch LoadError
    println("Skip adding MOCOT as currently in project")
end

Pkg.instantiate()