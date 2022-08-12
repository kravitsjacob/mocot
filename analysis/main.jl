using Revise

using YAML
using CSV
using XLSX
using DataFrames

using MOCOT


function main()
    # Initialization
    paths = YAML.load_file("analysis/paths.yml")
    df_gen_info_water = DataFrames.DataFrame(CSV.File(paths["outputs"]["gen_info_water"]))
    df_eia_heat_rates = DataFrames.DataFrame(XLSX.readtable(paths["inputs"]["eia_heat_rates"], "Annual Data"))
    df_air_water = DataFrames.DataFrame(CSV.File(paths["outputs"]["df_air_water"]))
    df_node_load = DataFrames.DataFrame(CSV.File(paths["outputs"]["df_node_load"]))
    network_data = PowerModels.parse_file(paths["inputs"]["case"])

    # Simulation with no water weights
    power_results, with_results, con_results, df_gen_info_pm = MOCOT.simulation(
        df_gen_info_water, 
        df_eia_heat_rates, 
        df_air_water,
        df_node_load,
        network_data,
        w_with=0.0,
        w_con=0.0,
    )
    df_gen_states = MOCOT.state_df(power_results, "gen", ["pg"])
    CSV.write(paths["outputs"]["df_no_water_weights"], df_gen_states)

    # Simulation with withdrawal weight
    power_results, with_results, con_results, df_gen_info_pm = MOCOT.simulation(
        df_gen_info_water, 
        df_eia_heat_rates, 
        df_air_water,
        df_node_load,
        network_data,
        w_with=1.0,
        w_con=0.0,
    )
    df_gen_states = MOCOT.state_df(power_results, "gen", ["pg"])
    CSV.write(paths["outputs"]["df_water_weights"], df_gen_states)

    # Static network information
    CSV.write(paths["outputs"]["df_gen_info_pm"], df_gen_info_pm)

 end
 

 main()
