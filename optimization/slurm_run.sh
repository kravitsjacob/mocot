#!/bin/sh

#SBATCH --nodes=36
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=1
#SBATCH --switches=1
#SBATCH --constraint=ib
#SBATCH --job-name=gosox
#SBATCH --partition=amilan
#SBATCH --time=0-00:200:00
#SBATCH --mail-user=jakr3868@colorado.edu
#SBATCH --mail-type=ALL

# Setup
module purge
. optimization/slurm_config.sh

# Run analysis
mpiexec -n 16 --mca opal_common_ucx_opal_mem_hooks 1 ./optimization/optimization.exe $scenario_code
