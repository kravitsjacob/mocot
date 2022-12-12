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
    df_gen_info_path:: String,
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
    df_gen_info = DataFrames.DataFrame(
        CSV.File(df_gen_info_path)
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


function create_model_from_dataframes(
    network_data:: Dict,
    scenario_code:: Int64,
    df_gen_info:: DataFrames.DataFrame,
    df_eia_heat_rates:: DataFrames.DataFrame,
)
    """
    Create WaterPowerModel from dataframes

    # Arguments
    - `network_data:: Dict`: PowerModels network data
    - `scenario_code:: Int64`: Numeric scenario code
    - `df_gen_info:: DataFrames.DataFrame`: Generator information
    - `df_eia_heat_rates:: DataFrames.DataFrame`: Energy information heat rates table
    """
    # Create generators
    gen_dict = Dict()
    for row in eachrow(df_gen_info)
        # All-generator properties
        emit_rate = row["Emission Rate lbs per kWh"] * 100.0  # convert to lbs / pu
        ramp_rate = row["Ramp Rate (MW/hr)"] / 100.0  # convert to pu/hr
        fuel = row["MATPOWER Fuel"]
        cool = row["923 Cooling Type"]

        if row["923 Cooling Type"] == "No Cooling System"
            gen_dict[string(row["obj_name"])] = NoCoolingGenerator(
                emit_rate,
                ramp_rate,
                fuel,
                cool,
            )
        elseif row["923 Cooling Type"] == "RC" || row["923 Cooling Type"] == "RI"
            # Unpack
            eta_net = get_eta_net(string(row["MATPOWER Fuel"]), df_eia_heat_rates)
            k_os = get_k_os(string(row["MATPOWER Fuel"]))
            beta_proc = get_beta_proc(string(row["MATPOWER Fuel"]))
            eta_cc = 5
            k_bd = 1.0
            eta_total = eta_net
            eta_elec = eta_net

            # Store
            gen_dict[string(row["obj_name"])] = MOCOT.RecirculatingGenerator(
                eta_net,
                k_os,
                beta_proc,
                eta_cc,
                k_bd,
                eta_total,
                eta_elec,
                emit_rate,
                ramp_rate,
                fuel,
                cool,
            )

        elseif row["923 Cooling Type"] == "OC"
            # Unpack
            eta_net = get_eta_net(string(row["MATPOWER Fuel"]), df_eia_heat_rates)
            k_os = get_k_os(string(row["MATPOWER Fuel"]))
            beta_proc = get_beta_proc(string(row["MATPOWER Fuel"]))
            eta_total = eta_net
            eta_elec = eta_net
            beta_with_limit = row["Withdrawal Limit [L/MWh]"] / 100.0 # Convert to L/MWh
            beta_con_limit = row["Consumption Limit [L/MWh]"] / 100.0 # Convert to L/MWh

            # Store
            gen_dict[string(row["obj_name"])] = MOCOT.OnceThroughGenerator(
                eta_net,
                k_os,
                beta_proc,
                eta_total,
                eta_elec,
                beta_with_limit,
                beta_con_limit,
                emit_rate,
                ramp_rate,
                fuel,
                cool
            )
        end
    end

    # Network-specific updates scenario
    network_data = MOCOT.update_all_gens!(network_data, "gen_status", 1)
    network_data = MOCOT.update_all_gens!(network_data, "pmin", 0.0)
    if scenario_code == 3  # Nuclear outage
        network_data["gen"]["47"]["gen_status"] = 0
    elseif scenario_code == 4  # Line outage
        delete!(network_data["branch"], "158")
    end

    # Create model
    model = WaterPowerModel(gen_dict, network_data)
    
    return model
end


function get_eta_net(fuel:: String, df_eia_heat_rates:: DataFrames.DataFrame)
    """
    Get net efficiency of plant
    
    # Arguments
    - `fuel:: String`: Fuel code
    - `df_eia_heat_rates:: DataFrames.DataFrame`: DataFrame of eia heat rates
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


function get_k_os(fuel:: String)
    """
    Get other sinks fraction from DOE-NETL reference models

    # Arguments
    - `fuel:: String`: Fuel code
    """
    if fuel == "coal"
        k_os = 0.12
    elseif fuel == "ng"
        k_os = 0.20
    elseif fuel == "nuclear"
        k_os = 0.0
    elseif fuel == "wind"
        k_os = 0.0
    end

    return k_os
end


function get_beta_proc(fuel:: String)
    """
    Get water withdrawal from non-cooling processes in [L/MWh] based on DOE-NETL model

    # Arguments
    - `fuel:: String`: Fuel code
    """
    if fuel == "coal"
        beta_proc = 200.0
    else
        beta_proc = 10.0
    end

    return beta_proc
end


function create_simulation_from_dataframes(
    model:: WaterPowerModel,
    scenario_code:: Int64,
    df_scenario_specs:: DataFrames.DataFrame,
    df_air_water:: DataFrames.DataFrame,
    df_wind_cf:: DataFrames.DataFrame,
    df_node_load:: DataFrames.DataFrame,
)
    """
    Create simulation from dataframes

    # Arguments
    - `model:: WaterPowerModel`: System model
    - `scenario_code:: Int64`: Numeric scenario code
    - `df_scenario_specs:: DataFrames.DataFrame`: Scenario specifications
    - `df_air_water:: DataFrames.DataFrame`: Air and water temperature dataframe
    - `df_wind_cf:: DataFrames.DataFrame`: Wind capacity factor dataframes
    - `df_node_load:: DataFrames.DataFrame`: Node-level load dataframe
    """
    # Exogenous parameters
    specs = df_scenario_specs[df_scenario_specs.scenario_code .== scenario_code, :]
    start_date = specs.datetime_start[1]
    end_date = specs.datetime_end[1]
    exogenous = get_exogenous(
        start_date,
        end_date,
        df_air_water,
        df_wind_cf,
        df_node_load
    )

    # States
    state = Dict()

    # Store
    simulation = MOCOT.WaterPowerSimulation(
        model,
        exogenous,
        state,
    )

    return simulation
end


function get_exogenous(
    start_date:: Dates.DateTime,
    end_date:: Dates.DateTime,
    df_air_water:: DataFrames.DataFrame,
    df_wind_cf:: DataFrames.DataFrame,
    df_node_load:: DataFrames.DataFrame
)
    """
    Format exogenous parameters

    # Arguments
    - `start_date:: Dates.DateTime`: Start time for simulation
    - `end_date:: Dates.DateTime`: End time for simulation
    - `df_air_water:: DataFrames.DataFrame`: Air and water temperature dataframe
    - `df_wind_cf:: DataFrames.DataFrame`: Wind capacity factor dataframes
    - `df_node_load:: DataFrames.DataFrame`: Node-level load dataframe
    """
    exogenous = Dict{String, Any}()

    # Air and water temperatures
    exogenous = add_air_water!(exogenous, df_air_water, start_date, end_date)

    # Wind capacity factors
    exogenous = add_wind_cf!(exogenous, df_wind_cf, start_date, end_date)    

    # Node loads
    exogenous = add_node_loads!(exogenous, df_node_load, start_date, end_date)

    return exogenous

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
    water_flow = Dict{String, Float64}()
    air_temperature = Dict{String, Float64}()
    for row in eachrow(df_air_water_filter)
        water_temperature[string(row["day_index"])] = row["water_temperature"]
        air_temperature[string(row["day_index"])] = row["air_temperature"]
        water_flow[string(row["day_index"])] = row["water_flow"] * 0.001  # Convert to [cmps]
    end
    exogenous["water_temperature"] = water_temperature
    exogenous["air_temperature"] = air_temperature
    exogenous["water_flow"] = water_flow

    return exogenous
end


function add_wind_cf!(
    exogenous:: Dict{String, Any},
    df_wind_cf::DataFrames.DataFrame,
    start_date:: Dates.DateTime,
    end_date:: Dates.DateTime
)
    """
    Add wind capacity factors to exogenous parameters in the proper format

    # Arguments
    - `exogenous:: Dict{String, Any}`: Exogenous parameter data [<parameter_name>][<timestep>]...[<timestep>]
    - `df_wind_cf:: DataFrames.DataFrame`: Wind capacity dataframe
    - `start_date:: Dates.DateTime`: Start time for simulation
    - `end_date:: Dates.DateTime`: End time for simulation
    """

    ## Filter dataframes
    date_filter = end_date .>= df_wind_cf.datetime .>= start_date
    df_wind_cf_filter = df_wind_cf[date_filter, :]

    ## Get index values
    df_wind_cf_filter[!, "hour_delta"] = Dates.Hour.(df_wind_cf_filter.datetime .- df_wind_cf_filter.datetime[1])
    df_wind_cf_filter[!, "day_index"] = floor.(Int64, Dates.value.(df_wind_cf_filter.hour_delta)/24 .+ 1.0)
    df_wind_cf_filter[!, "hour_index"] = Dates.value.(@.Dates.Hour(df_wind_cf_filter.datetime)) .+ 1

    ## Days
    days = Dict{String, Any}()
    for d in DataFrames.unique(df_wind_cf_filter[!, "day_index"])
        df_d = df_wind_cf_filter[in(d).(df_wind_cf_filter.day_index), :]

        ## Hours
        hours = Dict{String, Any}()
        for h in DataFrames.unique(df_d[!, "hour_index"])
            df_hour = df_d[in(h).(df_d.hour_index), :]
            hours[string(trunc(Int, h))] = df_hour.wind_capacity_factor[1]
        end

        days[string(trunc(Int, d))] = hours

    end

    exogenous["wind_capacity_factor"] = days

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


function update_scenario!(network_data, scenario_code:: Int64)
    """
    Update network based on scenario

    # Arguments
    - `network_data::Dict`: Network data (e.g., network_data_multi["nw"])
    - `scenario_code:: Int64`: Scenario code. 1 for all generators. 2 for no nuclear.
    """
    if scenario_code == 3  # "Nuclear outage"
        network_data = MOCOT.update_all_gens!(network_data, "gen_status", 1)
        network_data["gen"]["47"]["gen_status"] = 0
    else  # "All generators"
        network_data = MOCOT.update_all_gens!(network_data, "gen_status", 1)
    end

    return network_data
end
