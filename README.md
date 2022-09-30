# mocot
Multi-Objective Coordination of Thermoelectric Water Use

# Python Preprocessing
1) Install the python package `$ pip install --editable ./preprocessing/.`
2) Run the analysis`$ python preprocessing/preprocessing.py`

# Single Simulation Run (Debugging/Development)
1) Activate julia `$ julia`
2) Activate analysis `julia> using Pkg; Pkg.activate("simulation")`
3) Instantiate julia packages (analysis and MOCOT) `julia> include("simulation/julia_config.jl")`

for every bug:
  * Run `using Infiltrator` to add debugging functionality.
  * Set breakpoint where appropriate using `@Infiltrator.infiltrate` be sure to `import Infiltrator` at the top of development packages. Note, it will throw a warning as it thinks you are adding a not-included dependency.
  * Evaluate using `include("simulation/single_simulation.jl")`

# Single Simulation Run in C (Debugging/Development)
1) Download julia and make sure the path is reflected in `optimization/makefile`
2) Activate julia `$ julia simulation/julia_config.jl`
3) Compile using `$ make single -C ./optimization`
4) Run simulation using "all generators" scenario (code 1) `$ ./optimization/single_simulation.exe 1`

# Optimization on Unix-like
1) Download julia and make sure the path is reflected in `optimization/makefile`
2) Activate julia `$ julia simulation/julia_config.jl`
3) Compile using `$ make optimization -C ./optimization`
4) Run optimization using "all generators" scenario (code 1) `$ mpiexec -n 2 ./optimization/optimization.exe 1`

# Optimization on Alpine

## Building MOCOT and Analysis projects
1) Activate Alpine: `$ ml slurm/alpine`
2) Go to compile node: `$ acompile`
3) Change directory to mocot: `$ cd /projects/jakr3868/mocot`
4) Configure slurm: `. optimization/slurm_config.sh` 
5) Compile using `$ make slurm -C ./optimization`

## Running optimization
1) Activate Alpine: `$ ml slurm/alpine`
2) Change directory to mocot: `$ cd /projects/jakr3868/mocot`
3) Submit the job using "all generators" scenario (code 1): `$ sbatch --export=scenario_code=1 optimization/slurm_run.sh`

# Python Postprocessing
1) Install the python package `$ pip install --editable ./postprocessing/.`
2) Install the conda packages `$ conda install -c conda-forge pygmo` 
3) Run the analysis`$ python postprocessing/postprocessing.py`

# Notes on old commits/releases
Releases of week-01 to week-09 were regenerated due to migration away from git lfs. Thus, their release data all occur on the same day. 
