module WaterPowerModels

import PowerModels
import JuMP
import DataFrames


function time_series_loads!(network_data_multi::Dict)
    """
    Create a time series loads.

    # Arguments
    - `n::Dict`: multi network data
    """
    # Create load factors
    morning = repeat([0.9], 6)
    mid = repeat([1.2], 8)
    afternoon = repeat([1.6], 4)
    night = repeat([0.9], 6)
    load_factors = vcat(morning, mid, afternoon, night)

    # Apply load factors
    for (h, network_timeslice) in network_data_multi["nw"]
        for load in values(network_timeslice["load"])
            load["pd"] = load_factors[parse(Int64, h)] * load["pd"]
        end
    end

    return network_data_multi::Dict
end


function state_df(results, obj_type, props)
    """
    Extract states from day-resolution multi-network data (at hourly-resolution)

    # Arguments
    - `nw_data::Dict`: multi network data (e.g., network_data_multi["nw"])
    - `obj_type::String`: Type of object (e.g., "gen")
    - `props::Array`: Object properties to extract
    """

    # Initialization
    df = DataFrames.DataFrame()


    for d in 1:length(results)

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


function add_ramping_constraints!(pm, h_total)
    """
    Add generator ramping constraints to nuclear generator

    # Arguments
    - `pm`: Power model
    - `h_total::Int64`: Number of hours 
    """
    ramp_up = 1.0
    ramp_down = 1.0
    gen_name = 47

    begin
        # Ramping up
        JuMP.@constraint(
            pm.model,
            [h in 1:h_total-1],
            PowerModels.var(pm, h+1, :pg, gen_name) - PowerModels.var(pm, h, :pg, gen_name) <= ramp_up
        )
        # Ramping up
        JuMP.@constraint(
            pm.model,
            [h in 2:h_total],
            PowerModels.var(pm, h-1, :pg, gen_name) - PowerModels.var(pm, h, :pg, gen_name) <= ramp_down
        )
    end
    return pm
end


end # module
