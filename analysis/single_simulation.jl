# Single evaluation of simulation, useful for debugging

using Revise

using YAML
using CSV
using DataFrames
using Dates

using MOCOT


function main()
    # Import
    paths = YAML.load_file("analysis/paths.yml")
    (
        df_eia_heat_rates,
        df_air_water,
        df_node_load,
        network_data,
        df_gen_info,
        decision_names,
        objective_names
    ) = MOCOT.read_inputs(
        paths["outputs"]["gen_info_water_ramp_emit_waterlim"],
        paths["inputs"]["eia_heat_rates"],
        paths["outputs"]["air_water"],
        paths["outputs"]["node_load"],
        paths["inputs"]["case"],
        paths["inputs"]["decisions"],
        paths["inputs"]["objectives"]
    )

    # Preparing network
    network_data = MOCOT.add_custom_properties!(network_data, df_gen_info, df_eia_heat_rates)

    # Exogenous parameters
    exogenous = MOCOT.get_exogenous(
        Dates.DateTime(2019, 7, 1, 0),
        Dates.DateTime(2019, 7, 6, 23),
        df_air_water,
        df_node_load
    )

    # Update generator status
    network_data = MOCOT.update_commit_status!(network_data, "Normal")

    # Simulation
    df_objs = DataFrames.DataFrame()
    (objectives, state) = MOCOT.simulation(
        network_data,
        exogenous,
        objective_names,
        w_with_coal=1.0,
        w_con_coal=1.0,
        w_with_ng=1.0,
        w_con_ng=1.0,
        w_with_nuc=1.0,
        w_con_nuc=1.0
    )

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
    path_to_power = joinpath(
        paths["outputs"]["states"],
        "power_states.csv"
    )
    CSV.write(
        path_to_power,
        df_power_states
    )
    path_to_discharge = joinpath(
        paths["outputs"]["states"],
        "discharge_violation_states.csv"
    )
    CSV.write(
        path_to_discharge,
        df_discharge_violation_states
    )

    # Generator information export
    CSV.write(paths["outputs"]["gen_info_main"], df_gen_info)
end


main()
