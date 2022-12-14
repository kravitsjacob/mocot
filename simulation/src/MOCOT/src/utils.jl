# Utilities

import DataFrames

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


function get_gen_prop_dataframe(model:: WaterPowerModel, props:: Vector{String})
    """
    Get generator properties as a DataFrame

    # Arguments
    - `model:: WaterPowerModel`: Water/power model
    - `props:: Vector{String}`: Properties of interest
    """
    # Setup
    cols = vcat("obj_name", props)
    gen_dict = Dict(cols .=> [[] for i in 1:length(cols)])

    for (gen_name, gen) in model.gens
        # Add generator name
        append!(gen_dict["obj_name"], [gen_name])

        # Add properties
        for p in props
            append!(gen_dict[p], [getfield(gen, Symbol(p))])
        end
    end

    return DataFrames.DataFrame(gen_dict)
    
end


function get_state_dataframe(state:: Dict{String, Dict}, prop:: String)
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


function get_powermodel_state_dataframe(
    state:: Dict{String, Dict},
    state_name:: String,
    obj_type:: String,
    obj_prop:: String
)
    """
    Extract states from day-resolution PowerModels multi-network data (at hourly-resolution)

    # Arguments
    - `state:: Dict{String, Dict}`: State dictionary
    - `state_name:: String`: Property to query
    - `obj_type::String`: Type of object (e.g., "gen")
    - `obj_prop::Array`: Object properties to extract
    """
    # Setup
    cols = vcat("obj_name", "day", "hour", obj_prop)
    parsed_dict = Dict(cols .=> [[] for i in 1:length(cols)])

    # Get daily states
    daily_dict = state[state_name]

    for d in 1:length(daily_dict)-1
        # Extract day data
        day_data = daily_dict[string(d)]

        for h in 1:length(day_data)
            # Extract hour data
            hour_data = day_data["solution"]["nw"][string(h)]

            for (obj_name, obj_dict) in hour_data[obj_type]
                # Extract object value
                prop_val = obj_dict[obj_prop]

                # Store
                append!(parsed_dict["day"], [string(d)])
                append!(parsed_dict["hour"], [string(h)])
                append!(parsed_dict["obj_name"], [obj_name])
                append!(parsed_dict[obj_prop], [prop_val])

            end

        end

    end

    return DataFrames.DataFrame(parsed_dict)
end


# function multi_network_to_df(multi_nw_data::Dict, obj_type::String, props::Array)
#     """
#     Extract object information from hourly-resolution multi network data

#     # Arguments
#     - `nw_data::Dict`: multi network data (e.g., network_data_multi["nw"])
#     - `obj_type::String`: Type of object (e.g., "gen")
#     - `props::Array`: Object properties to extract
#     """
#     # Initialization
#     df = DataFrames.DataFrame()

#     # Loop through hours
#     for h in 1:length(multi_nw_data)

#         # Extract network data
#         nw_data = multi_nw_data[string(h)]
        
#         # Convert to dataframe
#         df_temp = network_to_df(nw_data, obj_type, props)

#         # Add timestep
#         df_temp[:, "hour"] .= string(h)

#         # Append to network dataframe
#         DataFrames.append!(df, df_temp)
#     end
    
#     return df
# end


# function network_to_df(nw_data::Dict, obj_type::String, props::Array)
#     """
#     Extract dataframe from network

#     # Arguments
#     - `data::Dict`: Network data
#     - `obj_type::String`: Type of object (e.g., "gen")
#     - `props::Array`: Object properties to extract
#     """
#     # Dev note, potentially the same as Replace with PowerModels.component_table(pm.data["nw"][string(h)], "gen", ["pg"])

#     # Initialization
#     df = DataFrames.DataFrame()

#     # Loop each object
#     for (obj_name, obj_dict) in nw_data[obj_type]
#         # Get properties
#         filtered_obj_dict=Dict{String, Any}()
#         for prop in props
#             filtered_obj_dict[prop] = obj_dict[prop]
#         end

#         # Add name
#         filtered_obj_dict["obj_name"] = obj_name

#         # Object DataFrame
#         df_obj = DataFrames.DataFrame(filtered_obj_dict)

#         # Append to network dataframe
#         DataFrames.append!(df, df_obj)
#     end

#     return df
# end


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


# function add_prop!(network_data:: Dict, obj_type:: String, prop_name:: String, obj_names, prop_vals)
#     """
#     Add property to PowerModel

#     # Arguments
#     - `network_data:: Dict`: PowerModels network data
#     - `obj_type:: String`: Type of object in network data (e.g., "gen")
#     - `prop_name:: String`: Property name to add
#     - `obj_names`: Ordered iterable of object names in network_data
#     - `prop_vals`: Ordered iterable of property values
#     """
#     for (i, obj_name) in enumerate(obj_names)
#         network_data[obj_type][obj_name][prop_name] = prop_vals[i]
#     end

#     return network_data
# end


function create_decision_dict(w:: Float64, network_data:: Dict)
    """
    Create dictionary for decision weights
    
    # Arguments
    - `w:: Float64`: Weight to be applied
    - `network_data:: Dict`: PowerModels network data
    """
    w_dict = Dict{String, Float64}()

    # Loop through generators
    for (obj_name, obj_props) in network_data["gen"]
        w_dict[obj_name] = w
    end

    return w_dict
end