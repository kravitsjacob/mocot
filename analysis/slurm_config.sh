#!/bin/bash

# Specify julia download location
export JULIA_DEPOT_PATH="/projects/jakr3868/.julia:$JULIA_DEPOT_PATH"

# Load modules
ml julia/1.6.6
ml intel/2022.1.2
ml impi/2021.5.0

# Create julia package
julia ./analysis/julia_config.jl