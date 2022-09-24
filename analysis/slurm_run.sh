#!/bin/sh

#SBATCH --ntasks=4
#SBATCH --cpus-per-task=1
#SBATCH --switches=1
#SBATCH --constraint=ib
#SBATCH --job-name=gosox
#SBATCH --partition=amilan
#SBATCH --time=0-00:20:00
#SBATCH --mail-user=jakr3868@colorado.edu
#SBATCH --mail-type=ALL

# Setup
module purge
cd ..
. analysis/slurm_config.sh

# Run analysis
mpiexec -n 4 ./analysis/optimization.exe $scenario_code
