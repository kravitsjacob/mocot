using Revise

using YAML
using CSV
using XLSX
using DataFrames
using PowerModels

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

    # Simulation with no water weights
    (objectives, state) = MOCOT.simulation(
        network_data,
        df_gen_info, 
        df_eia_heat_rates, 
        df_air_water,
        df_node_load,
        w_with_coal=0.0,
        w_con_coal=0.0,
        w_with_ng=0.0,
        w_con_ng=0.0,
        w_with_nuc=0.0,
        w_con_nuc=0.0,
    )
    CSV.write(
        paths["outputs"]["obj_no_water_weights"],
        DataFrames.DataFrame(objectives)
    )
    df_gen_states = MOCOT.pm_state_df(state["power"], "gen", ["pg"])
    CSV.write(paths["outputs"]["no_water_weights"], df_gen_states)

    # Simulation with no water weights
    (objectives, state) = MOCOT.simulation(
        network_data,
        df_gen_info, 
        df_eia_heat_rates, 
        df_air_water,
        df_node_load,
        w_with=1.0,
        w_con=0.0,
    )
    CSV.write(
        paths["outputs"]["obj_with_water_weights"],
        DataFrames.DataFrame(objectives)
    )
    df_gen_states = MOCOT.pm_state_df(state["power"], "gen", ["pg"])
    CSV.write(paths["outputs"]["with_water_weights"], df_gen_states)

    # Generator information export
    CSV.write(paths["outputs"]["gen_info_main"], df_gen_info)
 end
 

 main()
