# Evaluations of simulation, useful for debugging

# Dev packages
using Revise
using Infiltrator  # @Infiltrator.infiltrate

using DataFrames

using MOCOT


function main()
    # Simulation with average case
    (objectives, metrics, state) = MOCOT.borg_simulation_wrapper(0.0, 0.0, 0.0, 2, 0, 1)

    # # Simulation with extreme load/climate
    # (objectives, metrics, state) = MOCOT.borg_simulation_wrapper(0.0, 0.0, 0.0, 2, 0, 2)

    # # Simulation with nuclear outage
    # (objectives, metrics, state) = MOCOT.borg_simulation_wrapper(0.0, 0.0, 0.0, 2, 0, 3)

    # # Simulation with line outage
    # (objectives, metrics, state) = MOCOT.borg_simulation_wrapper(0.0, 0.0, 0.0, 2, 0, 4)

    # Objectives
    df_objs = DataFrames.DataFrame(objectives)

    # Metrics
    df_metrics = DataFrames.DataFrame(metrics)

    # Power states
    df_power_states = MOCOT.get_powermodel_state_dataframe(state, "results", "gen", "pg")

    # Discharge violation states
    df_discharge_violation_states = MOCOT.get_state_dataframe(state, "discharge_violation")

    # Discharge violation states
    df_capacity_reduction = MOCOT.get_state_dataframe(state, "capacity_reduction")


end


main()
