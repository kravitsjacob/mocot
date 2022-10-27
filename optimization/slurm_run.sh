#!/bin/sh

#SBATCH --nodes=4
#SBATCH --ntasks-per-node=16
#SBATCH --cpus-per-task=1
#SBATCH --switches=1
#SBATCH --constraint=ib
#SBATCH --job-name=gosox
#SBATCH --partition=amilan
#SBATCH --time=0-00:300:00
#SBATCH --mail-user=jakr3868@colorado.edu
#SBATCH --mail-type=ALL

# Setup
module purge
. optimization/slurm_config.sh

# Run analysis
mpiexec -n $SLURM_NTASKS --mca opal_common_ucx_opal_mem_hooks 1 ./optimization/optimization.exe ${SLURM_ARRAY_TASK_ID}
