#!/bin/sh

#SBATCH --nodes=4
#SBATCH --ntasks-per-node=16
#SBATCH --cpus-per-task=1
#SBATCH --switches=1
#SBATCH --job-name=gosox
#SBATCH --partition=shas
#SBATCH --qos=condo
#SBATCH --account=ucb-summit-jrk
#SBATCH --time=0-00:300:00
#SBATCH --mail-user=jakr3868@colorado.edu
#SBATCH --mail-type=ALL

# Setup
module purge
. optimization/slurm_config_summit.sh

# Run analysis
mpirun -np $SLURM_NTASKS ./optimization/optimization.exe ${SLURM_ARRAY_TASK_ID}
