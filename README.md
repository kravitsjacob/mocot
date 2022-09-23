# mocot
Multi-Objective Coordination of Thermoelectric Water Use

# Python Preprocessing
1) Install the python package`$ pip install --editable src/python`
2) Run the analysis`$ python analysis/preprocessing.py`

# Julia Tests
1) Use julia environment (with package installed) and run test `$ julia --project=src/julia/MOCOT src/julia/MOCOT/testing/test.jl`

# Single Simulation Run (Debugging/Development)
* Activate julia `$ julia`
* Instantiate julia packages (analysis and MOCOT) `julia> include("analysis/julia_config.jl")`
* Activate analysis `julia> using Pkg; Pkg.activate("analysis")`

for every bug:
  * Run `using Infiltrator` to add debugging functionality.
  * Set breakpoint where appropriate using `@Infiltrator.infiltrate` be sure to `import Infiltrator` at the top of development packages. Note, it will throw a warning as it thinks you are adding a not-included dependency.
  * Evaluate using `include("analysis/single_simulation.jl")`

# Single Simulation Run in C (Debugging/Development)
* Download julia and make sure the path is reflected in `analysis/makefile`
* Activate julia `$ julia`
* Instantiate julia packages `julia> include("analysis/julia_config.jl")`
* Compile using `$ make single -C ./analysis`
* Run simulation using "all generators" scenario (code 1) `$ ./analysis/single_simulation.exe 1`

# Optimization on Unix-like
* Download julia and make sure the path is reflected in `analysis/makefile`
* Activate julia `$ julia`
* Instantiate julia packages `julia> include("analysis/julia_config.jl")`
* Compile using `$ make optimization -C ./analysis`
* Run optimization using "all generators" scenario (code 1) `$ mpiexec -n 2 ./analysis/optimization.exe 1`

# Optimization on Alpine

## Building MOCOT and Analysis projects
* Activate Alpine: `$ ml slurm/alpine`
* Go to compile node: `$ acompile`
* Change directory to mocot: `$ cd /projects/jakr3868/mocot`
* Configure slurm: `. analysis/slurm_config.sh` 
* Compile using `$ make slurm -C ./analysis`

## Running simulation
* Activate Alpine: `$ ml slurm/alpine`
* Change directory to analysis: `$ cd /projects/jakr3868/mocot/analysis`
* Submit the job: `$ sbatch slurm_run.sh`

# Notes on old commits/releases
Releases of week-01 to week-09 were regenerated due to migration away from git lfs. Thus, their release data all occur on the same day. 
