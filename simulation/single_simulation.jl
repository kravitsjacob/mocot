# Evaluations of simulation, useful for debugging

# Dev packages
using Revise
using Infiltrator  # @Infiltrator.infiltrate

using YAML
using CSV
using DataFrames

using MOCOT


function main()
    # Setup
    paths = YAML.load_file("paths.yml")

    # Simulation with all generators
    (objectives, state) = MOCOT.borg_simulation_wrapper(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2, 1, 1)

    # Simulation with high water air and water tempeartures
    (objectives, state) = MOCOT.borg_simulation_wrapper(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2, 0, 5)

    # Simulation with high water air and water tempeartures with weights
    (objectives, state) = MOCOT.borg_simulation_wrapper(1000.0, 1000.0, 0.0, 0.0, 0.0, 0.0, 2, 0, 5)

    # Objectives
    df_objs = DataFrames.DataFrame(objectives)

    # Power states
    df_power_states = MOCOT.pm_state_df(state, "power", "gen", ["pg"])

    # Discharge violation states
    df_discharge_violation_states = MOCOT.custom_state_df(state, "discharge_violation")

    # Export as simulation progresses
    CSV.write(
        paths["outputs"]["objectives"],
        df_objs
    )
    CSV.write(
        paths["outputs"]["power_states"],
        df_power_states
    )
    CSV.write(
        paths["outputs"]["discharge_states"],
        df_discharge_violation_states
    )

end


main()
