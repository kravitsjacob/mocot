#!/bin/bash

# Specify julia download location
export JULIA_DEPOT_PATH="/projects/jakr3868/.julia:$JULIA_DEPOT_PATH"

# MPI passing environmental vars
export SLURM_EXPORT_ENV=ALL

# Load modules
ml julia/1.8.1
ml gcc/11.2.0
ml openmpi

# Instantiate julia packages
julia ./analysis/julia_config.jl