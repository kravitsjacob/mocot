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

    # # Simulation with average
    # (objectives, state, metrics) = MOCOT.borg_simulation_wrapper(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1, 0, 1)

    # # Simulation with nuclear outage
    # (objectives, state, metrics) = MOCOT.borg_simulation_wrapper(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2, 0, 2)

    # # Simulation with high load
    # (objectives, state, metrics) = MOCOT.borg_simulation_wrapper(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2, 0, 3)

    # # Simulation with high standard deviation load   
    # (objectives, state, metrics) = MOCOT.borg_simulation_wrapper(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2, 0, 4)

    # # Simulation with high water air and water tempeartures
    # (objectives, state, metrics) = MOCOT.borg_simulation_wrapper(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2, 0, 5)

    # Simulation with high water air and water tempertures with weights
    (objectives, state, metrics) = MOCOT.borg_simulation_wrapper(1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 2, 0, 5)
    
    # Simulation with high water air and water tempertures with weights
    (objectives, state, metrics) = MOCOT.borg_simulation_wrapper(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2, 0, 6)

    # Objectives
    df_objs = DataFrames.DataFrame(objectives)

    # Power states
    df_power_states = MOCOT.pm_state_df(state, "power", "gen", ["pg"])

    # Discharge violation states
    df_discharge_violation_states = MOCOT.custom_state_df(state, "discharge_violation")

    # Metrics
    df_metrics = DataFrames.DataFrame(metrics)

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
    CSV.write(
        paths["outputs"]["metrics"],
        df_metrics
    )

end


main()
