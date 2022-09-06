#!/bin/bash

#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --output=run.out
#SBATCH --job-name=gosox
#SBATCH --partition=amilan
#SBATCH --time=0-00:03:00
#SBATCH --mail-user=jacob.kravits@colorado.edu
#SBATCH --mail-type=END

# Setup
module purge
ml julia/1.6.6

# Run analysis
cd ..
julia --project=analysis analysis/main.jl
