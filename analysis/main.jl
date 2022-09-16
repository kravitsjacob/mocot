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
        df_gen_info
    ) = MOCOT.read_inputs(
        paths["outputs"]["gen_info_water_ramp_emit_waterlim"],
        paths["inputs"]["eia_heat_rates"],
        paths["outputs"]["air_water"],
        paths["outputs"]["node_load"],
        paths["inputs"]["case"]
    )

    # Preparing network
    network_data = MOCOT.add_custom_properties!(network_data, df_gen_info, df_eia_heat_rates)

    # Exogenous parameters
    exogenous = MOCOT.get_exogenous(
        Dates.DateTime(2019, 7, 1, 0),
        Dates.DateTime(2019, 7, 7, 23),
        df_air_water,
        df_node_load
    )

    # # Debugging
    # exogenous["node_load"] = Dict(
    #     "1" =>  exogenous["node_load"]["1"],
    #     "2" =>  exogenous["node_load"]["2"],
    #     "3" =>  exogenous["node_load"]["3"]
    # )
    # df_dec_exog = df_dec_exog[1:2, :]

    # Run simulation
    df_objs = DataFrames.DataFrame()
    for row in DataFrames.eachrow(df_dec_exog)

        # Output
        println(string(row["gen_scenario"]))
        println(string(row["dec_label"]))

        # Update generator status
        network_data = MOCOT.update_commit_status!(network_data, string(row["gen_scenario"]))

        # Simulation
        (objectives, state) = MOCOT.simulation(
            network_data,
            exogenous,
            w_with_coal=row["w_with_coal"],
            w_con_coal=row["w_con_coal"],
            w_with_ng=row["w_with_ng"],
            w_con_ng=row["w_con_ng"],
            w_with_nuc=row["w_with_nuc"],
            w_con_nuc=row["w_con_nuc"]
        )

        # Objectives
        df_temp_objs = DataFrames.DataFrame(objectives)
        df_temp_objs[!, "dec_label"] .= row.dec_label
        df_temp_objs[!, "gen_scenario"] .= row.gen_scenario

        # Power states
        df_power_states = MOCOT.pm_state_df(state, "power", "gen", ["pg"])
        df_power_states[!, "dec_label"] .= row.dec_label
        df_power_states[!, "gen_scenario"] .= row.gen_scenario

        # Discharge violation states
        df_discharge_violation_states = MOCOT.custom_state_df(state, "discharge_violation")
        df_discharge_violation_states[!, "dec_label"] .= row.dec_label
        df_discharge_violation_states[!, "gen_scenario"] .= row.gen_scenario

        # Store in dataframe
        DataFrames.append!(df_objs, df_temp_objs)

        # Export as simulation progresses
        CSV.write(
            paths["outputs"]["objectives"],
            df_objs
        )
        path_to_power = joinpath(
            paths["outputs"]["states"],
            row.gen_scenario * "_" * row.dec_label * "_"  * "power_states.csv"
        )
        CSV.write(
            path_to_power,
            df_power_states
        )
        path_to_discharge = joinpath(
            paths["outputs"]["states"],
            row.gen_scenario * "_" * row.dec_label * "_"  * "discharge_violation_states.csv"
        )
        CSV.write(
            path_to_discharge,
            df_discharge_violation_states
        )

    end

    # Generator information export
    CSV.write(paths["outputs"]["gen_info_main"], df_gen_info)
end


main()
