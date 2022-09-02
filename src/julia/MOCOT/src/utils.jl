# Utilities

function update_commit_status!(network_data, gen_scenario:: String)
    """
    Update the commit status of generators in network data

    # Arguments
    - `network_data::Dict`: Network data (e.g., network_data_multi["nw"])
    - `gen_scenario:: String`: Generator scenario
    """
    if gen_scenario == "Normal"
        network_data = update_all_gens!(network_data, "gen_status", 1)
    elseif gen_scenario == "No Nuclear"
        network_data = update_all_gens!(network_data, "gen_status", 1)
        network_data["gen"]["47"]["gen_status"]=0
    end
    return network_data
end


function update_all_gens!(nw_data, prop:: String, val)
    """
    Change property on all generators in a network

    # Arguments
    - `nw_data::Dict`: Network data
    - `prop:: String`: Generator property name
    - `val`: Value to set
    """
    for gen_dict in values(nw_data["gen"])
        gen_dict[prop] = val
    end
    return nw_data
end


function pm_state_df(results, obj_type, props)
    """
    Extract states from day-resolution powermodels multi-network data (at hourly-resolution)

    # Arguments
    - `nw_data::Dict`: multi network data (e.g., network_data_multi["nw"])
    - `obj_type::String`: Type of object (e.g., "gen")
    - `props::Array`: Object properties to extract
    """

    # Initialization
    df = DataFrames.DataFrame()

    for d in 1:length(results)-1

        # Extract day data
        day_results = results[string(d)]

        # Get results for that day
        df_day = multi_network_to_df(
            day_results["solution"]["nw"],
            obj_type,
            props
        )

        # Assign day
        df_day[:, "day"] .= string(d)

        # Append to state dataframe
        DataFrames.append!(df, df_day)
    end

    return df
end


function custom_state_df(state:: Dict{String, Dict}, prop:: String)
    """
    Extract states dataframe from day-resolution state dictionary

    # Arguments
    - `state:: Dict{String, Dict}`: State dictionary
    - `prop:: String`: Property to query
    """
    # Initialization
    df = DataFrames.DataFrame()

    prop_state = state[prop]

    for d in keys(prop_state)

        # Get data for one day
        df_day = DataFrames.stack(DataFrames.DataFrame(prop_state[string(d)]))

        # Cleaning data
        DataFrames.rename!(df_day, :variable => :obj_name, :value => Symbol(prop))

        # Assign day
        df_day[:, "day"] .= string(d)

        # Append to state dataframe
        DataFrames.append!(df, df_day)
    end

    return df
end


function multi_network_to_df(multi_nw_data::Dict, obj_type::String, props::Array)
    """
    Extract object information from hourly-resolution multi network data

    # Arguments
    - `nw_data::Dict`: multi network data (e.g., network_data_multi["nw"])
    - `obj_type::String`: Type of object (e.g., "gen")
    - `props::Array`: Object properties to extract
    """
    # Initialization
    df = DataFrames.DataFrame()

    # Loop through hours
    for h in 1:length(multi_nw_data)

        # Extract network data
        nw_data = multi_nw_data[string(h)]
        
        # Convert to dataframe
        df_temp = network_to_df(nw_data, obj_type, props)

        # Add timestep
        df_temp[:, "hour"] .= string(h)

        # Append to network dataframe
        DataFrames.append!(df, df_temp)
    end
    
    return df
end


function network_to_df(nw_data::Dict, obj_type::String, props::Array)
    """
    Extract dataframe from network

    # Arguments
    - `data::Dict`: Network data
    - `obj_type::String`: Type of object (e.g., "gen")
    - `props::Array`: Object properties to extract
    """
    # Dev note, potentially the same as Replace with PowerModels.component_table(pm.data["nw"][string(h)], "gen", ["pg"])

    # Initialization
    df = DataFrames.DataFrame()

    # Loop each object
    for (obj_name, obj_dict) in nw_data[obj_type]
        # Get properties
        filtered_obj_dict=Dict{String, Any}()
        for prop in props
            filtered_obj_dict[prop] = obj_dict[prop]
        end

        # Add name
        filtered_obj_dict["obj_name"] = obj_name

        # Object DataFrame
        df_obj = DataFrames.DataFrame(filtered_obj_dict)

        # Append to network dataframe
        DataFrames.append!(df, df_obj)
    end

    return df
end


function get_objectives(
    state:: Dict{String, Dict},
    network_data:: Dict{String, Any}
)
    """
    Computing simulation objectives
    
    # Arguments
    - `state:: Dict{String, Dict}`: State dictionary
    - `network_data:: Dict`: PowerModels Network data
    """
    objectives = Dict{String, Float64}()

    # Static coefficients from network
    cost_tab = PowerModels.component_table(network_data, "gen", ["cost", "cus_emit"])
    df_cost = DataFrames.DataFrame(cost_tab, ["obj_name", "cost", "cus_emit"])
    df_cost[!, "obj_name"] = string.(df_cost[!, "obj_name"])
    df_cost[!, "cus_emit"] = float.(df_cost[!, "cus_emit"])
    df_cost[!, "c_per_mw2_pu"] = extract_from_array_column(df_cost[!, "cost"], 1)
    df_cost[!, "c_per_mw_pu"] = extract_from_array_column(df_cost[!, "cost"], 2)
    df_cost[!, "c"] = extract_from_array_column(df_cost[!, "cost"], 3)

    # States-dependent coefficients
    df_withdraw = MOCOT.custom_state_df(state, "withdraw_rate")
    df_consumption = MOCOT.custom_state_df(state, "consumption_rate")
    df_gen_states = MOCOT.pm_state_df(state["power"], "gen", ["pg"])
    df = DataFrames.leftjoin(
        df_gen_states,
        df_withdraw,
        on = [:obj_name, :day]
    )
    df = DataFrames.leftjoin(
        df,
        df_consumption,
        on = [:obj_name, :day]
    )
    df = DataFrames.leftjoin(
        df,
        df_cost,
        on = [:obj_name]
    )

    # Compute cost objectives
    objectives["f_gen"] = DataFrames.sum(DataFrames.skipmissing(
        df.c .+ df.pg .* df.c_per_mw_pu .+ df.pg.^2 .* df.c_per_mw2_pu
    ))

    # Compute water objectives
    df[!, "hourly_withdrawal"] = df[!, "pg"] .* 100.0 .* df[!, "withdraw_rate"]  # Per unit conversion
    df[!, "hourly_consumption"] = df[!, "pg"] .* 100.0 .* df[!, "consumption_rate"]  # Per unit conversion
    df_daily = DataFrames.combine(
        DataFrames.groupby(df, [:day]),
        :hourly_withdrawal => sum,
        :hourly_consumption => sum
    )
    objectives["f_with_peak"] = DataFrames.maximum(df_daily.hourly_withdrawal_sum)
    objectives["f_con_peak"] = DataFrames.maximum(df_daily.hourly_consumption_sum)
    objectives["f_with_tot"] = DataFrames.sum(df[!, "hourly_withdrawal"])
    objectives["f_con_tot"] = DataFrames.sum(df[!, "hourly_consumption"])

    # Compute emission objectives
    df[!, "hourly_emit"] = df[!, "pg"] .* 100.0 .* df[!, "cus_emit"]  # Per unit conversion
    objectives["f_emit"] = DataFrames.sum(df[!, "hourly_emit"])

    return objectives
end


function extract_from_array_column(array_col, i:: Int)
    """
    Extract elements from a DataFrame column of arrays

    # Arguments
    - `array_col`: DataFrame column of array (e.g., df.col)
    - `i:: Int`: Index to retrieve
    """
    extract = map(eachrow(array_col)) do row
        try
            row[1][i]
        catch
            missing
        end
    end

    return extract
end


function multiply_dicts(dict_array:: Array)
    """
    Multiply corresponding entries in two dictionaries

    # Arguments
    - `dict_array:: Array`: Array of dictionaries with matching indices
    """
    # Setup
    result = Dict{String, Float64}()
    ref_dict = dict_array[1]

    # Multiplying corresponding entries
    for (key, val) in ref_dict
        for dict_entry in dict_array[2:end]
            val = val * dict_entry[key]
        end
        result[key] = val
    end

    return result
end


function add_prop!(network_data:: Dict, obj_type:: String, prop_name:: String, obj_names, prop_vals)
    """
    Add property to PowerModel

    # Arguments
    - `network_data:: Dict`: PowerModels network data
    - `obj_type:: String`: Type of object in network data (e.g., "gen")
    - `prop_name:: String`: Property name to add
    - `obj_names`: Ordered iterable of object names in network_data
    - `prop_vals`: Ordered iterable of property values
    """
    for (i, obj_name) in enumerate(obj_names)
        network_data[obj_type][obj_name][prop_name] = prop_vals[i]
    end

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


function get_exogenous(df_air_water:: DataFrames.DataFrame, df_node_load:: DataFrames.DataFrame)
    """
    Format exogenous parameters

    # Arguments
    - `df_air_water:: DataFrames.DataFrame`: Air and water temperature dataframe
    - `df_node_load:: DataFrames.DataFrame`: Node-level load dataframe
    """
    exogenous = Dict{String, Any}()

    # Air and water temperatures
    water_temperature = Dict{String, Float64}()
    air_temperature = Dict{String, Float64}()
    for row in eachrow(df_air_water)
        water_temperature[string(row["day_index"])] = row["water_temperature"]
        air_temperature[string(row["day_index"])] = row["air_temperature"]
    end
    exogenous["water_temperature"] = water_temperature
    exogenous["air_temperature"] = air_temperature

    # Node loads

    # Days
    d_nodes = Dict{String, Any}()
    for d in DataFrames.unique(df_node_load[!, "day_index"])
        df_d = df_node_load[in(d).(df_node_load.day_index), :]

        # Hours
        h_nodes = Dict{String, Any}()
        for h in DataFrames.unique(df_node_load[!, "hour_index"])
            df_hour = df_d[in(h).(df_d.hour_index), :]

            # Nodes
            nodes = Dict{String, Any}()
            for row in eachrow(df_hour)
                # Pandapower indexing
                pandapower_bus = row["bus"]

                # PowerModels indexing
                powermodels_bus = row["bus"] + 1

                nodes[string(powermodels_bus)] = row["load_mw"]
            end
            h_nodes[string(trunc(Int, h))] = nodes
        end
        d_nodes[string(trunc(Int, d))] = h_nodes
    end
    exogenous["node_load"] = d_nodes

    return exogenous

end
