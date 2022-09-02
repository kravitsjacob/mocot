using Revise

using YAML
using CSV
using DataFrames

using MOCOT


function main()
    # Import
    paths = YAML.load_file("analysis/paths.yml")
    (
        df_gen_info_water_ramp,
        df_eia_heat_rates,
        df_air_water,
        df_node_load,
        network_data,
        df_gen_info,
        df_config
    ) = MOCOT.read_inputs(
        paths["outputs"]["gen_info_water_ramp"], 
        paths["inputs"]["eia_heat_rates"],
        paths["outputs"]["air_water"],
        paths["outputs"]["node_load"],
        paths["inputs"]["case"],
        paths["inputs"]["simulation_config"]
    )

    # Add custom network properties
    network_data = MOCOT.add_prop!(
        network_data,
        "gen",
        "cus_ramp_rate",
        df_gen_info[!, "obj_name"],
        convert.(Float64, df_gen_info[!, "Ramp Rate (MW/hr)"])
    )
    network_data = MOCOT.add_prop!(
        network_data,
        "gen",
        "cus_fuel",
        df_gen_info[!, "obj_name"],
        convert.(String, df_gen_info[!, "MATPOWER Fuel"])
    )
    network_data = MOCOT.add_prop!(
        network_data,
        "gen",
        "cus_cool",
        df_gen_info[!, "obj_name"],
        convert.(String, df_gen_info[!, "923 Cooling Type"])
    )

    # Heat rates
    df_gen_info = transform!(
        df_gen_info,
        Symbol("MATPOWER Fuel") => ByRow(fuel -> MOCOT.get_eta_net(string(fuel), df_eia_heat_rates)) => "Heat Rate"
    )
    network_data = MOCOT.add_prop!(
        network_data,
        "gen",
        "cus_heat_rate",
        df_gen_info[!, "obj_name"],
        convert.(Float64, df_gen_info[!, "Heat Rate"])
    )

    # Exogenous parameters
    exogenous = MOCOT.get_exogenous(df_air_water, df_node_load)

    # Run simulation
    df_objs = DataFrames.DataFrame()
    df_states = DataFrames.DataFrame()
    for row in DataFrames.eachrow(df_config)

        # Output
        println(string(row["gen_scenario"]))
        println(string(row["dec_scenario"]))

        # Update generator status
        network_data = MOCOT.update_commit_status!(network_data, string(row["gen_scenario"]))

        # Simulation
        (objectives, state) = MOCOT.simulation(
            network_data,
            exogenous,
            df_node_load,
            w_with_coal=row["w_with_coal"],
            w_con_coal=row["w_con_coal"],
            w_with_ng=row["w_with_ng"],
            w_con_ng=row["w_con_ng"],
            w_with_nuc=row["w_with_nuc"],
            w_con_nuc=row["w_con_nuc"],
        )
        
        # Objectives
        df_temp_objs = DataFrames.DataFrame(objectives)
        df_temp_objs[!, "dec_scenario"] .= row.dec_scenario
        df_temp_objs[!, "gen_scenario"] .= row.gen_scenario

        # Generator states
        df_gen_states = MOCOT.pm_state_df(state["power"], "gen", ["pg"])
        df_gen_states[!, "dec_scenario"] .= row.dec_scenario
        df_gen_states[!, "gen_scenario"] .= row.gen_scenario

        # Store in dataframe
        DataFrames.append!(df_states, df_gen_states)
        DataFrames.append!(df_objs, df_temp_objs)
    end

    # Export
    CSV.write(
        paths["outputs"]["states"],
        df_states
    )
    CSV.write(
        paths["outputs"]["objectives"],
        df_objs
    )

    # Generator information export
    CSV.write(paths["outputs"]["gen_info_main"], df_gen_info)
 end
 

 main()
