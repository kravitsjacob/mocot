# Functions for reading inputs

import CSV
import DataFrames
import XLSX

function read_inputs(
    gen_info_from_python_path:: String,
    eia_heat_rates_path:: String,
    air_water_path:: String,
    node_load_path:: String,
    case_path:: String,
    simulation_config_path:: String
)
    """
    Wrapper function for reading inputs
    
    # Arguments
    - `gen_info_from_python_path:: String`: Path to generation info generated from preprocessing
    - `eia_heat_rates_path:: String`: Path to eia heat rate information
    - `air_water_path:: String`: Path to air and water exogenous
    - `node_load_path:: String`: Path to node load exogenous
    - `case_path:: String`: Path to MATPOWER case
    - `simulation_config_path:: String`:: Path to simulation configuration file
    """
    # Reading inputs
    df_gen_info_python = DataFrames.DataFrame(
        CSV.File(gen_info_from_python_path)
    )
    df_eia_heat_rates = DataFrames.DataFrame(
        XLSX.readtable(eia_heat_rates_path, "Annual Data")
    )
    df_air_water = DataFrames.DataFrame(CSV.File(air_water_path))
    df_node_load = DataFrames.DataFrame(CSV.File(node_load_path))
    df_config = DataFrames.DataFrame(CSV.File(simulation_config_path))
    network_data = PowerModels.parse_file(case_path)

    # Generator information
    df_gen_info = MOCOT.get_gen_info(network_data, df_gen_info_python)

    inputs = (
        df_eia_heat_rates,
        df_air_water,
        df_node_load,
        network_data,
        df_gen_info,
        df_config
    )
    return inputs
end


function get_gen_info(
    network_data:: Dict,
    df_gen_info_python:: DataFrames.DataFrame
)
    """
    Get generator information by merging PowerModels and MATPOWER data

    # Arguments
    - `network_data:: Dict`: Network data 
    - `df_gen_info_python:: DataFrames.DataFrame`: Generator information from preprocessing
    """
    df_gen_info_pm = MOCOT.network_to_df(network_data, "gen", ["gen_bus"])
    df_gen_info = DataFrames.leftjoin(
        df_gen_info_pm,
        df_gen_info_python,
        on = :gen_bus => Symbol("MATPOWER Index")
    )
    return df_gen_info
end
