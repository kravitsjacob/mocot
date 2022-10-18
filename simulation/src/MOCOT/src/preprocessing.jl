# Functions for preprocessing

import CSV
import DataFrames
import XLSX
import Dates
import DelimitedFiles
import PowerModels
import Statistics


function read_inputs(
    scenario_code:: Int64,
    scenario_specs_path:: String,
    air_water_template:: String,
    wind_capacity_factor_template:: String,
    node_load_template:: String,
    gen_info_from_python_path:: String,
    eia_heat_rates_path:: String,
    case_path:: String,
    decisions_path:: String,
    objectives_path:: String,
    metrics_path:: String
)
    """
    Wrapper function for reading inputs
    
    # Arguments
    - `scenario_code:: Int64`: Scenario code
    - `scenario_specs_path:: String`: Path to scenario specification
    - `air_water_template:: String`: Template to air water temperature exogenous data
    - `wind_capacity_factor_template:: String`: Template to wind capacity factor
    - `node_load_template:: String`: Template to node exogenous data
    - `gen_info_from_python_path:: String`: Path to generation info generated from preprocessing
    - `eia_heat_rates_path:: String`: Path to eia heat rate information
    - `case_path:: String`: Path to MATPOWER case
    - `decisions_path:: String`: Path to decision names
    - `objectives_path:: String`: Path to objective names
    - `metrics_path:: String`: Path to objective names
    """
    # Reading inputs
    df_scenario_specs = DataFrames.DataFrame(
        CSV.File(scenario_specs_path, dateformat="yyyy-mm-dd HH:MM:SS")
    )
    df_gen_info_python = DataFrames.DataFrame(
        CSV.File(gen_info_from_python_path)
    )
    df_eia_heat_rates = DataFrames.DataFrame(
        XLSX.readtable(eia_heat_rates_path, "Annual Data")
    )
    network_data = PowerModels.parse_file(case_path)

    # Exogenous parameters
    air_water_path = replace(air_water_template, "0" => scenario_code)
    df_air_water = DataFrames.DataFrame(CSV.File(air_water_path))
    wind_cf_path = replace(wind_capacity_factor_template, "0" => scenario_code)
    df_wind_cf = DataFrames.DataFrame(
        CSV.File(wind_cf_path, dateformat="yy-mm-dd HH:MM:SS"),
    )
    node_load_path = replace(node_load_template, "0" => scenario_code)
    df_node_load = DataFrames.DataFrame(
        CSV.File(node_load_path, dateformat="yy-mm-dd HH:MM:SS")
    )

    # Parameter names
    decision_names = vec(DelimitedFiles.readdlm(decisions_path, ',', String))
    objective_names = vec(DelimitedFiles.readdlm(objectives_path, ',', String))
    metric_names = vec(DelimitedFiles.readdlm(metrics_path, ',', String))

    # Generator information
    df_gen_info = get_gen_info(network_data, df_gen_info_python)

    inputs = (
        df_scenario_specs,
        df_eia_heat_rates,
        df_air_water,
        df_wind_cf,
        df_node_load,
        network_data,
        df_gen_info,
        decision_names,
        objective_names,
        metric_names
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
        convert.(Float64, df_gen_info[!, "Ramp Rate (MW/hr)"]) / 100.0  # convert to pu/hr
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
        convert.(Float64, df_gen_info[!, "Emission Rate lbs per MWh"]) * 100.0  # convert to lbs / pu
    )

    # Withdrawal limit
    network_data = MOCOT.add_prop!(
        network_data,
        "gen",
        "cus_with_limit",
        df_gen_info[!, "obj_name"],
        df_gen_info[!, "Withdrawal Limit [L/MWh]"] * 100.0  # convert to L / pu
    )

    # Consumption limit
    network_data = MOCOT.add_prop!(
        network_data,
        "gen",
        "cus_con_limit",
        df_gen_info[!, "obj_name"],
        df_gen_info[!, "Consumption Limit [L/MWh]"] * 100.0  # convert to L / pu
    )

    # Heat rates
    df_gen_info = DataFrames.transform!(
        df_gen_info,
        Symbol("MATPOWER Fuel") => DataFrames.ByRow(fuel -> get_eta_net(string(fuel), df_eia_heat_rates)) => "Heat Rate"
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


function get_eta_net(fuel:: String, df_eia_heat_rates:: DataFrames.DataFrame)
    """
    Get net efficiency of plant
    
    # Arguments
    `fuel:: String`: Fuel code
    `df_eia_heat_rates:: DataFrames.DataFrame`: DataFrame of eia heat rates
    """
    if fuel == "coal"
        col_name = "Electricity Net Generation, Coal Plants Heat Rate"
    elseif fuel == "ng"
        col_name = "Electricity Net Generation, Natural Gas Plants Heat Rate"
    elseif fuel == "nuclear"
        col_name = "Electricity Net Generation, Nuclear Plants Heat Rate"
    elseif fuel == "wind"
        col_name = "Wind"
    end

    if col_name != "Wind"
        # Median heat rate
        eta_net = Statistics.median(skipmissing(df_eia_heat_rates[!, col_name]))

        # Convert to ratio
        eta_net = 3412.0/eta_net
    else
        eta_net = 0
    end

    return eta_net
end


function add_air_water!(
    exogenous:: Dict{String, Any},
    df_air_water:: DataFrames.DataFrame,
    start_date:: Dates.DateTime,
    end_date:: Dates.DateTime
)
    """
    Add air and water temperatures to exogenous parameters in the proper format

    # Arguments
    - `exogenous:: Dict{String, Any}`: Exogenous parameter data [<parameter_name>][<timestep>]...[<timestep>]
    - `df_air_water::DataFrames.DataFrame`: Node load dataframe
    - `start_date:: Dates.DateTime`: Start time for simulation
    - `end_date:: Dates.DateTime`: End time for simulation
    """

    # Filter dataframe
    date_filter = end_date .>= df_air_water.datetime .>= start_date
    df_air_water_filter = df_air_water[date_filter, :]

    # Get index values
    df_air_water_filter[!, "day_delta"] = df_air_water_filter.datetime .- df_air_water_filter.datetime[1]
    df_air_water_filter[!, "day_index"] = Dates.value.(df_air_water_filter.day_delta) .+ 1

    # Exogenous formatting
    water_temperature = Dict{String, Float64}()
    air_temperature = Dict{String, Float64}()
    for row in eachrow(df_air_water_filter)
        water_temperature[string(row["day_index"])] = row["water_temperature"]
        air_temperature[string(row["day_index"])] = row["air_temperature"]
    end
    exogenous["water_temperature"] = water_temperature
    exogenous["air_temperature"] = air_temperature

    return exogenous
end


function add_node_loads!(
    exogenous:: Dict{String, Any},
    df_node_load::DataFrames.DataFrame,
    start_date:: Dates.DateTime,
    end_date:: Dates.DateTime
)
    """
    Add node loads to exogenous parameters in the proper format

    # Arguments
    - `exogenous:: Dict{String, Any}`: Exogenous parameter data [<parameter_name>][<timestep>]...[<timestep>]
    - `df_node_load::DataFrames.DataFrame`: Node load dataframe
    - `start_date:: Dates.DateTime`: Start time for simulation
    - `end_date:: Dates.DateTime`: End time for simulation
    """

    ## Filter dataframes
    date_filter = end_date .>= df_node_load.datetime .>= start_date
    df_node_load_filter = df_node_load[date_filter, :]

    ## Get index values
    df_node_load_filter[!, "hour_delta"] = Dates.Hour.(df_node_load_filter.datetime .- df_node_load_filter.datetime[1])
    df_node_load_filter[!, "day_index"] = floor.(Int64, Dates.value.(df_node_load_filter.hour_delta)/24 .+ 1.0)
    df_node_load_filter[!, "hour_index"] = Dates.value.(@.Dates.Hour(df_node_load_filter.datetime)) .+ 1

    ## Days
    d_nodes = Dict{String, Any}()
    for d in DataFrames.unique(df_node_load_filter[!, "day_index"])
        df_d = df_node_load_filter[in(d).(df_node_load_filter.day_index), :]

        ## Hours
        h_nodes = Dict{String, Any}()
        for h in DataFrames.unique(df_node_load_filter[!, "hour_index"])
            df_hour = df_d[in(h).(df_d.hour_index), :]
            ## Nodes
            nodes = Dict{String, Any}()
            for row in eachrow(df_hour)
                ## Pandapower indexing
                pandapower_bus = row["bus"]

                ## PowerModels indexing
                powermodels_bus = row["bus"] + 1

                nodes[string(powermodels_bus)] = row["load_mw"] / 100.0 # convert to pu
            end
            h_nodes[string(trunc(Int, h))] = nodes
        end
        d_nodes[string(trunc(Int, d))] = h_nodes
    end
    exogenous["node_load"] = d_nodes

    return exogenous
end


function get_exogenous(
    start_date:: Dates.DateTime,
    end_date:: Dates.DateTime,
    df_air_water:: DataFrames.DataFrame,
    df_node_load:: DataFrames.DataFrame
)
    """
    Format exogenous parameters

    # Arguments
    - `start_date:: Dates.DateTime`: Start time for simulation
    - `end_date:: Dates.DateTime`: End time for simulation
    - `df_air_water:: DataFrames.DataFrame`: Air and water temperature dataframe
    - `df_node_load:: DataFrames.DataFrame`: Node-level load dataframe
    """
    exogenous = Dict{String, Any}()

    # Air and water temperatures
    exogenous = add_air_water!(exogenous, df_air_water, start_date, end_date)

    # Node loads
    exogenous = add_node_loads!(exogenous, df_node_load, start_date, end_date)

    return exogenous

end


function update_scenario!(network_data, scenario_code:: Int64)
    """
    Update network based on scenario

    # Arguments
    - `network_data::Dict`: Network data (e.g., network_data_multi["nw"])
    - `scenario_code:: Int64`: Scenario code. 1 for all generators. 2 for no nuclear.
    """
    if scenario_code == 1  # "All generators"
        network_data = MOCOT.update_all_gens!(network_data, "gen_status", 1)
    elseif scenario_code == 2  # "No nuclear"
        network_data = MOCOT.update_all_gens!(network_data, "gen_status", 1)
        network_data["gen"]["47"]["gen_status"]=0
    else
        network_data = MOCOT.update_all_gens!(network_data, "gen_status", 1)
    end

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
