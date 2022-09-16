# Functions for preprocessing

import CSV
import DataFrames
import XLSX

function read_inputs(
    gen_info_from_python_path:: String,
    eia_heat_rates_path:: String,
    air_water_path:: String,
    node_load_path:: String,
    case_path:: String,
)
    """
    Wrapper function for reading inputs
    
    # Arguments
    - `gen_info_from_python_path:: String`: Path to generation info generated from preprocessing
    - `eia_heat_rates_path:: String`: Path to eia heat rate information
    - `air_water_path:: String`: Path to air and water exogenous
    - `node_load_path:: String`: Path to node load exogenous
    - `case_path:: String`: Path to MATPOWER case
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
    network_data = PowerModels.parse_file(case_path)

    # Generator information
    df_gen_info = MOCOT.get_gen_info(network_data, df_gen_info_python)

    inputs = (
        df_eia_heat_rates,
        df_air_water,
        df_node_load,
        network_data,
        df_gen_info
    )
    return inputs
end


function add_custom_properties!(
    network_data:: Dict,
    df_gen_info:: DataFrames.DataFrame,
    df_eia_heat_rates:: DataFrames.DataFrame
)
    """
    Add custom properties to the network

    # Arguments
    - `network_data:: Dict`: PowerModels network data
    - `df_gen_info:: DataFrames.DataFrame`: Generator information
    - `df_eia_heat_rates:: DataFrames.DataFrame`: EIA heat rate information
    """
    # Ramp rate
    network_data = MOCOT.add_prop!(
        network_data,
        "gen",
        "cus_ramp_rate",
        df_gen_info[!, "obj_name"],
        convert.(Float64, df_gen_info[!, "Ramp Rate (MW/hr)"])
    )

    # Fuel types
    network_data = MOCOT.add_prop!(
        network_data,
        "gen",
        "cus_fuel",
        df_gen_info[!, "obj_name"],
        convert.(String, df_gen_info[!, "MATPOWER Fuel"])
    )

    # Cooling type
    network_data = MOCOT.add_prop!(
        network_data,
        "gen",
        "cus_cool",
        df_gen_info[!, "obj_name"],
        convert.(String, df_gen_info[!, "923 Cooling Type"])
    )

    # Emissions coefficient
    network_data = MOCOT.add_prop!(
        network_data,
        "gen",
        "cus_emit",
        df_gen_info[!, "obj_name"],
        convert.(Float64, df_gen_info[!, "Emission Rate lbs per MWh"])
    )

    # Withdrawal limit
    network_data = MOCOT.add_prop!(
        network_data,
        "gen",
        "cus_with_limit",
        df_gen_info[!, "obj_name"],
        df_gen_info[!, "Withdrawal Limit [L/MWh]"]
    )

    # Consumption limit
    network_data = MOCOT.add_prop!(
        network_data,
        "gen",
        "cus_con_limit",
        df_gen_info[!, "obj_name"],
        df_gen_info[!, "Consumption Limit [L/MWh]"]
    )

    # Heat rates
    df_gen_info = DataFrames.transform!(
        df_gen_info,
        Symbol("MATPOWER Fuel") => DataFrames.ByRow(fuel -> MOCOT.get_eta_net(string(fuel), df_eia_heat_rates)) => "Heat Rate"
    )
    network_data = MOCOT.add_prop!(
        network_data,
        "gen",
        "cus_heat_rate",
        df_gen_info[!, "obj_name"],
        convert.(Float64, df_gen_info[!, "Heat Rate"])
    )

    return network_data
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
