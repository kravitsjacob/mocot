#!/bin/bash

#SBATCH --nodes=2
#SBATCH --ntasks-per-node=12
#SBATCH --cpus-per-task=1
#SBATCH --output=output.txt
#SBATCH --error=error.txt
#SBATCH --job-name=gosox
#SBATCH --partition=amilan
#SBATCH --time=0-00:40:00
#SBATCH --mail-user=jakr3868@colorado.edu
#SBATCH --mail-type=ALL

# Setup
module purge
cd ..
. analysis/slurm_config.sh

# Run analysis
mpiexec -n 24 ./analysis/main.exe
