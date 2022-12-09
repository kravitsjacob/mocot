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

    # Simulation with average case
    (objectives, state, metrics) = MOCOT.borg_simulation_wrapper(0.0, 0.0, 0.0, 2, 0, 1)

    # Simulation with extreme load/climate
    (objectives, state, metrics) = MOCOT.borg_simulation_wrapper(0.0, 0.0, 0.0, 2, 0, 2)

    # Simulation with nuclear outage
    (objectives, state, metrics) = MOCOT.borg_simulation_wrapper(0.0, 0.0, 0.0, 2, 0, 3)

    # Simulation with line outage
    (objectives, state, metrics) = MOCOT.borg_simulation_wrapper(0.0, 0.0, 0.0, 2, 0, 4)

    # Objectives
    df_objs = DataFrames.DataFrame(objectives)

    # Power states
    df_power_states = MOCOT.pm_state_df(state, "power", "gen", ["pg"])

    # Discharge violation states
    df_discharge_violation_states = MOCOT.custom_state_df(state, "discharge_violation")

    # Discharge violation states
    df_capacity_reduction = MOCOT.custom_state_df(state, "capacity_reduction")

    # Metrics
    df_metrics = DataFrames.DataFrame(metrics)

end


main()
