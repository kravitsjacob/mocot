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

# Julia Simulation on Alpine

## Building MOCOT and Analysis projects
This process is only needed if projects aren't installed. Note, I had to delete the manifest.toml files for MOCOT and analysis projects for this to work.
* Activate Alpine: `$ ml slurm/alpine`
* Go to compile node: `$ acompile`
* Change julia download location: `$ export JULIA_DEPOT_PATH="/projects/jakr3868/.julia:$JULIA_DEPOT_PATH"`
* Load julia: `$ ml julia/1.6.6`
* Change directory to mocot: `$ cd /projects/jakr3868/mocot`
* Run julia: `$ julia`
* Importing Pkg: `julia> using Pkg`
* Activate MOCOT: `julia> Pkg.activate("src/julia/MOCOT")`
* Instantiate MOCOT `julia> Pkg.instantiate()`
* Activate analysis: `julia> Pkg.activate("analysis")`
* Add MOCOT as a dev package: `julia> Pkg.develop(path="/projects/jakr3868/mocot/src/julia/MOCOT")`
* Instantiate analysis `julia> Pkg.instantiate()`

## Running simulation
* Activate Alpine: `$ ml slurm/alpine`
* Change directory to analysis: `$ cd /projects/jakr3868/mocot/analysis`
* Submit the job: `$ sbatch slurm_run.sh`

# Notes on old commits/releases
Releases of week-01 to week-09 were regenerated due to migration away from git lfs. Thus, their release data all occur on the same day. 
