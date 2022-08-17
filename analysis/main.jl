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
    df_gen_info_water_ramp = DataFrames.DataFrame(
        CSV.File(paths["outputs"]["gen_info_water_ramp"])
    )
    df_eia_heat_rates = DataFrames.DataFrame(
        XLSX.readtable(paths["inputs"]["eia_heat_rates"], "Annual Data")
    )
    df_air_water = DataFrames.DataFrame(CSV.File(paths["outputs"]["air_water"]))
    df_node_load = DataFrames.DataFrame(CSV.File(paths["outputs"]["node_load"]))
    network_data = PowerModels.parse_file(paths["inputs"]["case"])

    # Initialization
    df_gen_info = MOCOT.get_gen_info(network_data, df_gen_info_water_ramp)

    # Simulation with no water weights
    state = MOCOT.simulation(
        network_data,
        df_gen_info, 
        df_eia_heat_rates, 
        df_air_water,
        df_node_load,
        w_with=0.0,
        w_con=0.0,
    )
    df_gen_states = MOCOT.state_df(state["power"], "gen", ["pg"])
    CSV.write(paths["outputs"]["no_water_weights"], df_gen_states)

 end
 

 main()
