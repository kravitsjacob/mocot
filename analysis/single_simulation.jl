# Single evaluation of simulation, useful for debugging

# Dev packages
using Revise
import Infiltrator  # @Infiltrator.infiltrate

using YAML
using CSV
using DataFrames

using analysis
using MOCOT


function main()
    # Setup
    paths = YAML.load_file("analysis/paths.yml")

    # Simulation
    (objectives, state) = analysis.borg_simulation_wrapper(0.1, 0.2, 0.3, 0.4, 0.5, 0.6, "all")

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
