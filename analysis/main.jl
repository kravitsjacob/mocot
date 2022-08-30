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
        df_gen_info
    ) = MOCOT.read_inputs(
        paths["outputs"]["gen_info_water_ramp"], 
        paths["inputs"]["eia_heat_rates"],
        paths["outputs"]["air_water"],
        paths["outputs"]["node_load"],
        paths["inputs"]["case"]
    )

    # Simulation
    df_config = DataFrames.DataFrame(CSV.File(paths["inputs"]["simulation_config"]))
    df_objs = DataFrames.DataFrame()
    df_states = DataFrames.DataFrame()
    for row in DataFrames.eachrow(df_config)
        # Simulation
        (objectives, state) = MOCOT.simulation(
            network_data,
            df_gen_info, 
            df_eia_heat_rates, 
            df_air_water,
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
