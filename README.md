# mocot
Multi-Objective Coordination of Thermoelectric Water Use

# Python Preprocessing
1) Install the python package `$ pip install --editable ./preprocessing/.`
2) Run the analysis`$ python preprocessing/preprocessing.py`

# Simulation Tests
1) Activate julia `$ julia --project=simulation/src/MOCOT`
2) Instantiate julia packages `julia> include("simulation/julia_config.jl")`
3) Run tests `julia> include("simulation/src/MOCOT/testing/test.jl")`

# Single Simulation Run (Debugging/Development)
1) Activate julia `$ julia --project=simulation/src/MOCOT`
2) Instantiate julia packages `julia> include("simulation/julia_config.jl")`

for every bug:
  * Run `using Infiltrator` to add debugging functionality.
  * Set breakpoint where appropriate using `@Infiltrator.infiltrate` be sure to `import Infiltrator` at the top of development packages. Note, it will throw a warning as it thinks you are adding a not-included dependency.
  * Evaluate using `include("simulation/single_simulation.jl")`

# Single Simulation Run in C (Debugging/Development)
1) Download julia and make sure the path is reflected in `optimization/makefile`
2) Activate julia `$ julia simulation/julia_config.jl`
3) Compile using `$ make single -C ./optimization`
4) Run simulation using "all generators" scenario (code 1) `$ ./optimization/single_simulation.exe 1`

# Informal (Engineering Judgement) Optimization
1) Activate julia `$ julia --project=simulation/src/MOCOT`
2) Instantiate julia packages `julia> include("simulation/julia_config.jl")`
3) Run postprocessing `julia> include("optimization/engineering_judgement.jl")`

# Optimization on Unix-like
1) Place borg files in `optimization/src/borg`. We used a modified version of the algorithm where we disable the constraint functionality to isntead pass our metrics during the optimization. We do this by 
* Commenting lines 506-510 and 617-620 in borg.c to disable constraint evaluation.
* Adding the following lines to line 1811 in borg.c to add constraint printing to archive append.
```
		for (j=0; j<solution->problem->numberOfConstraints; j++) {
			if (j > 0 || solution->problem->numberOfConstraints > 0) {
				fprintf(file, " ");
			}

			fprintf(file, "%.*g", BORG_DIGITS, solution->constraints[j]);
		}
```
2) Download julia and make sure the path is reflected in `optimization/makefile`
3) Activate julia `$ julia simulation/julia_config.jl`
4) Compile using `$ make optimization -C ./optimization`
5) Run optimization using "all generators" scenario (code 1) `$ mpiexec -n 2 ./optimization/optimization.exe 1`

# Optimization on Summit/Alpine

## Building MOCOT project
1) Activate slurm: `$ ml slurm/alpine`
	* Summit equivalent: `$ ml slurm/summit`
2) Go to compile node: `$ acompile`
	* Summit equivalent: `$ ssh scompile` 
3) Change directory to mocot: `$ cd /projects/jakr3868/mocot`
4) Configure slurm: `$ . optimization/slurm_config.sh` 
	* Summit equivalent: `$ . optimization/slurm_config_summit.sh` 
5) Compile using `$ make slurm -C ./optimization`

## Running optimization
1) Activate slurm: `$ ml slurm/alpine`
	* Summit equivalent: `$ ml slurm/summit`
2) Change directory to mocot: `$ cd /projects/jakr3868/mocot`
3) Submit the job for all scenarios: `$ sbatch --array=1-7 optimization/slurm_run.sh`
	* Summit equivalent: `$ sbatch --array=1-7 optimization/slurm_run_summit.sh` 

# Python Postprocessing
1) Install the python package `$ pip install --editable ./postprocessing/.`
2) Install the conda packages `$ conda install -c conda-forge pygmo` 
3) Run the analysis`$ python postprocessing/postprocessing.py`

# Julia Postprocessing
1) Activate julia `$ julia --project=simulation/src/MOCOT`
2) Instantiate julia packages `julia> include("simulation/julia_config.jl")`
3) Run postprocessing `julia> include("postprocessing/run_scenarios.jl")`

# Notes on old commits/releases
Releases of week-01 to week-09 were regenerated due to migration away from git lfs. Thus, their release data all occur on the same day. 
