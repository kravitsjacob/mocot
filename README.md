# water-coordinate
Multi-Objective Coordination of Thermoelectric Water Use

# Running Python Components
1) Install the python package`$ pip install --editable src/python`
2) Run the analysis`$ python analysis/main.py`

# Running Julia Components
1) Use julia environment (with package installed) and run analysis`$ julia --project=analysis/julia_env analysis/main.jl`

# Debugging Julia
1) In terminal activate julia env `$ julia --project=analysis/julia_env`
2) Run `using Infiltrator` and `using Revise` to add debugging functionality and ensure the development dependencies are recompiled.
3) Set breakpoint where appropriate using `@Infiltrator.infiltrate` be sure to `import Infiltrator` at the top of development packages. Note, it will throw a warning as it thinks you are adding a not-included dependency.
4) Evaluate using `include("analysis/main.jl")`
