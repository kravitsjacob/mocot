# mocot
Multi-Objective Coordination of Thermoelectric Water Use

# Python Preprocessing
1) Install the python package`$ pip install --editable src/python`
2) Run the analysis`$ python analysis/preprocessing.py`

# Julia Simulation
1) Use julia environment (with package installed) and run analysis`$ julia --project=analysis analysis/main.jl`

# Julia Tests
1) Use julia environment (with package installed) and run test `$ julia --project=src/julia/MOCOT src/julia/MOCOT/testing/test.jl`

# Debugging Julia
1) In terminal activate julia env `$ julia --project=analysis`
2) Run `using Infiltrator` to add debugging functionality.
3) Set breakpoint where appropriate using `@Infiltrator.infiltrate` be sure to `import Infiltrator` at the top of development packages. Note, it will throw a warning as it thinks you are adding a not-included dependency.
4) Evaluate using `include("analysis/main.jl")`

### Notes on old commits/releases
Releases of week-01 to week-09 were regenerated due to migration away from git lfs. Thus, their release data all occur on the same day. 
