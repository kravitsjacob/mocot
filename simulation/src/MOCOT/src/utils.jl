# Utilities


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


function pm_state_df(state, prop, obj_type, obj_props)
    """
    Extract states from day-resolution PowerModels multi-network data (at hourly-resolution)

    # Arguments
    - `state:: Dict{String, Dict}`: State dictionary
    - `prop:: String`: Property to query
    - `obj_type::String`: Type of object (e.g., "gen")
    - `obj_props::Array`: Object properties to extract
    """
    # Setup
    df = DataFrames.DataFrame()
    results = state[prop]

    for d in 1:length(results)-1

        # Extract day data
        day_results = results[string(d)]

        # Get results for that day
        df_day = multi_network_to_df(
            day_results["solution"]["nw"],
            obj_type,
            obj_props
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
    network_data:: Dict{String, Any},
    w_with:: Dict{String, Float64},
    w_con:: Dict{String, Float64},
)
    """
    Computing simulation objectives
    
    # Arguments
    - `state:: Dict{String, Dict}`: State dictionary
    - `network_data:: Dict{String, Any}`: PowerModels Network data
    - `w_with:: Dict{String, Float64}`: Withdrawal weights for each generator
    - `w_con:: Dict{String, Float64}`: Consumption weights for each generator
    """
    objectives = Dict{String, Float64}()

    # Static coefficients from network
    coef_tab = PowerModels.component_table(network_data, "gen", ["cost", "cus_emit"])
    df_coef = DataFrames.DataFrame(coef_tab, ["obj_name", "cost", "cus_emit"])
    reliability_gen_rows = in.(df_coef.obj_name, Ref(network_data["reliability_gen"]))
    df_coef = df_coef[.!reliability_gen_rows, :]
    df_coef[!, "obj_name"] = string.(df_coef[!, "obj_name"])
    df_coef[!, "cus_emit"] = float.(df_coef[!, "cus_emit"])
    df_coef[!, "c_per_mw2_pu"] = extract_from_array_column(df_coef[!, "cost"], 1)
    df_coef[!, "c_per_mw_pu"] = extract_from_array_column(df_coef[!, "cost"], 2)
    df_coef[!, "c"] = extract_from_array_column(df_coef[!, "cost"], 3)

    # States-dependent coefficients
    df_withdraw_states = MOCOT.custom_state_df(state, "withdraw_rate")
    df_consumption_states = MOCOT.custom_state_df(state, "consumption_rate")
    df_all_power_states = MOCOT.pm_state_df(state, "power", "gen", ["pg"])
    reliability_gen_rows = in.(df_all_power_states.obj_name, Ref(network_data["reliability_gen"]))
    df_reliability_states = df_all_power_states[reliability_gen_rows, :]
    df_power_states = df_all_power_states[.!reliability_gen_rows, :]
    df_discharge_violation_states = MOCOT.custom_state_df(state, "discharge_violation")

    # Round power output from solver
    df_power_states.pg = round.(df_power_states.pg, digits=7)

    # Compute cost objectives
    df_cost = DataFrames.leftjoin(
        df_power_states,
        df_coef,
        on = [:obj_name]
    )
    objectives["f_gen"] = DataFrames.sum(DataFrames.skipmissing(
        df_cost.c .+ df_cost.pg .* df_cost.c_per_mw_pu .+ df_cost.pg.^2 .* df_cost.c_per_mw2_pu
    ))

    # Compute water objectives
    df_water = DataFrames.leftjoin(
        df_power_states,
        df_withdraw_states,
        on = [:obj_name, :day]
    )
    df_water = DataFrames.leftjoin(
        df_water,
        df_consumption_states,
        on = [:obj_name, :day]
    )
    df_water[!, "hourly_withdrawal"] = df_water[!, "pg"] .* 100.0 .* df_water[!, "withdraw_rate"]  # Per unit conversion
    df_water[!, "hourly_consumption"] = df_water[!, "pg"] .* 100.0 .* df_water[!, "consumption_rate"]  # Per unit conversion
    df_daily = DataFrames.combine(
        DataFrames.groupby(df_water, [:day]),
        :hourly_withdrawal => sum,
        :hourly_consumption => sum
    )
    objectives["f_with_peak"] = DataFrames.maximum(df_daily.hourly_withdrawal_sum)
    objectives["f_con_peak"] = DataFrames.maximum(df_daily.hourly_consumption_sum)
    objectives["f_with_tot"] = DataFrames.sum(df_water[!, "hourly_withdrawal"])
    objectives["f_con_tot"] = DataFrames.sum(df_water[!, "hourly_consumption"])
    
    # Total costs
    df_with = DataFrames.stack(DataFrames.DataFrame(w_with))
    DataFrames.rename!(df_with, :variable => :obj_name, :value => :w_with)
    df_con = DataFrames.stack(DataFrames.DataFrame(w_con))
    DataFrames.rename!(df_con, :variable => :obj_name, :value => :w_con)
    df_water = DataFrames.leftjoin(
        df_water,
        df_with,
        on=[:obj_name]
    )
    df_water = DataFrames.leftjoin(
        df_water,
        df_con,
        on=[:obj_name]
    )
    withdrawal_cost = DataFrames.sum(df_water.hourly_withdrawal .* df_water.w_with)
    consumtion_cost = DataFrames.sum(df_water.hourly_consumption .* df_water.w_con)
    objectives["f_cos_tot"] =  objectives["f_gen"] + withdrawal_cost + consumtion_cost

    # Compute discharge violation objectives
    if length(df_discharge_violation_states[!, "discharge_violation"]) > 0
        df_discharge_violation_states = DataFrames.leftjoin(
            df_discharge_violation_states,
            df_water,
            on=[:obj_name, :day]
        )
        temperature = df_discharge_violation_states.discharge_violation
        discharge = df_discharge_violation_states.hourly_withdrawal - df_discharge_violation_states.hourly_consumption
        objectives["f_disvi_tot"] = DataFrames.sum(discharge .* temperature)
    else
        objectives["f_disvi_tot"] = 0.0
    end

    # Compute emission objectives
    df_emit = DataFrames.leftjoin(
        df_power_states,
        df_coef,
        on = [:obj_name]
    )
    df_emit[!, "hourly_emit"] = df_emit[!, "pg"] .* 100.0 .* df_emit[!, "cus_emit"]  # Per unit conversion
    objectives["f_emit"] = DataFrames.sum(df_emit[!, "hourly_emit"])

    # Compute reliability objectives
    objectives["f_ENS"] = DataFrames.sum(df_reliability_states[!, "pg"])

    return objectives
end

function get_metrics(
    state:: Dict{String, Dict},
    network_data:: Dict{String, Any},
)
    """
    Get metrics for simulation. Metrics are different than objectives as they do not
    inform the next set of objectives but rather just quantify an aspect of a given state.

    # Arguments
    - `state:: Dict{String, Dict}`: State dictionary
    - `network_data:: Dict`: PowerModels Network data
    """
    metrics = Dict{String, Float64}()
    
    # Power states
    df_power_states = MOCOT.pm_state_df(state, "power", "gen", ["pg"])

    # Add fuel types
    df_fuel = DataFrames.DataFrame(
        PowerModels.component_table(network_data, "gen", ["cus_fuel"]),
        [:obj_name, :cus_fuel]
    )
    df_fuel[!, :obj_name] = string.(df_fuel[!, :obj_name])
    df_fuel[!, :cus_fuel] = string.(df_fuel[!, :cus_fuel])
    df_power_states = DataFrames.leftjoin(                                                                                                                                                                    
        df_power_states,                                                                                                                                                                                      
        df_fuel,                                                                                                                                                                                              
        on=[:obj_name]                                                                                                                                                                                        
    )

    # Get total ouputs
    df_power_fuel = DataFrames.combine(
        DataFrames.groupby(df_power_states, [:cus_fuel]),
        :pg => sum,
    )
    coal_output = df_power_fuel[df_power_fuel.cus_fuel .== "coal",:].pg_sum
    ng_output = df_power_fuel[df_power_fuel.cus_fuel .== "ng",:].pg_sum
    wind_output = df_power_fuel[df_power_fuel.cus_fuel .== "wind",:].pg_sum
    nuclear_output = df_power_fuel[df_power_fuel.cus_fuel .== "nuclear",:].pg_sum

    # Populate metrics
    metrics["coal_output"] = coal_output
    metrics["ng_output"] = ng_output
    metrics["wind_output"] = wind_output
    metrics["nuclear_output"] = nuclear_output

    return metrics 
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
