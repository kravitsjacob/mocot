#!/bin/bash

#SBATCH --nodes=1
#SBATCH --output=run.out
#SBATCH --job-name=gosox
#SBATCH --partition=amilan
#SBATCH --time=0-00:600:00
#SBATCH --mail-user=jacob.kravits@colorado.edu
#SBATCH --mail-type=END

# Setup
module purge
export JULIA_DEPOT_PATH="/projects/jakr3868/.julia:$JULIA_DEPOT_PATH"
ml julia/1.6.6

# Run analysis
cd ..
julia --project=analysis analysis/main.jl
