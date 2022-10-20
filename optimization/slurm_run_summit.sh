#!/bin/sh

#SBATCH --nodes=36
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=1
#SBATCH --switches=1
#SBATCH --job-name=gosox
#SBATCH --partition=shas
#SBATCH --qos=condo
#SBATCH --account=ucb-summit-jrk
#SBATCH --time=0-00:10:00
#SBATCH --mail-user=jakr3868@colorado.edu
#SBATCH --mail-type=ALL

# Setup
module purge
. optimization/slurm_config_summit.sh

# Run analysis
mpiexec -n 144 ./optimization/optimization.exe ${SLURM_ARRAY_TASK_ID}
