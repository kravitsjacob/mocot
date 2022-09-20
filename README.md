# mocot
Multi-Objective Coordination of Thermoelectric Water Use

# Python Preprocessing
1) Install the python package`$ pip install --editable src/python`
2) Run the analysis`$ python analysis/preprocessing.py`

# Julia Tests
1) Use julia environment (with package installed) and run test `$ julia --project=src/julia/MOCOT src/julia/MOCOT/testing/test.jl`

# Debugging Julia
1) In terminal activate julia env `$ julia --project=analysis`
2) Importing Pkg: `julia> using Pkg`
4) Add MOCOT as a dev package: `julia> Pkg.develop(path="src/julia/MOCOT")`
5) Instantiate environment `julia> Pkg.instantiate()`
3) Run `using Infiltrator` to add debugging functionality.
4) Set breakpoint where appropriate using `@Infiltrator.infiltrate` be sure to `import Infiltrator` at the top of development packages. Note, it will throw a warning as it thinks you are adding a not-included dependency.
5) Evaluate using `include("analysis/single_simulation.jl")`

# Julia Simulation on Windows Subsystem for Linux (WSL)
1) Download julia to WSL and make sure the path is reflected in `analysis/makefile`
2) Run julia, making sure the path is correct: `$ /bin/julia/julia-1.8.1/bin/julia`
3) Importing Pkg: `julia> using Pkg`
4) Add MOCOT as a dev package: `julia> Pkg.develop(path="src/julia/MOCOT")`
5) Instantiate environment `julia> Pkg.instantiate()`
6) Compile using `$ make -C ./analysis`
7) Run using `$ mpiexec -n 2 ./analysis/main.exe`

# Julia Simulation on Alpine

## Building MOCOT and Analysis projects
1) Activate Alpine: `$ ml slurm/alpine`
2) Go to compile node: `$ acompile`
3) Change directory to mocot: `$ cd /projects/jakr3868/mocot`
4) Configure slurm: `. analysis/slurm_config.sh` 
5) Compile using `$ make alpine -C ./analysis`

## Running simulation
* Activate Alpine: `$ ml slurm/alpine`
* Change directory to analysis: `$ cd /projects/jakr3868/mocot/analysis`
* Submit the job: `$ sbatch slurm_run.sh`

# Notes on old commits/releases
Releases of week-01 to week-09 were regenerated due to migration away from git lfs. Thus, their release data all occur on the same day. 
