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


function network_to_df(data::Dict, obj_name::String)
    """
    Extract object from network

    # Arguments
    - `data::Dict`: Network data
    - `obj_name::String`: Name of object
    """
    # Initialization
    df = DataFrames.DataFrame()

    # Loop each object
    for (obj_name, obj_dict) in data[obj_name]
        # Drop multi-entry TODO flatten
        delete!(obj_dict, "source_id")
        delete!(obj_dict, "cost")

        # Object DataFrame
        df_obj = DataFrames.DataFrame(obj_dict)

        # Assign name
        df_obj[:, "name"] .= obj_name

        # Append to network dataframe
        DataFrames.append!(df, df_obj)
    end

    return df
end


function multi_network_to_df(nw_data::Dict, obj_name::String)
    """
    Extract object from multi network

    # Arguments
    - `nw_data::Dict`: multi network data (network_data_multi["nw"])
    - `obj_name::Dict`: multi network data
    """
    # TODO should call network_to_df
    # Initialization
    df = DataFrames.DataFrame()

    # Loop through hours
    for h in 1:length(nw_data)

        # Loop each object in the hour
        for (obj_name, obj_dict) in nw_data[string(h)][obj_name]
            # Drop source_id
            delete!(obj_dict, "source_id")

            # Object DataFrame
            df_obj = DataFrames.DataFrame(obj_dict)

            # Assign name
            df_obj[:, "name"] .= obj_name

            # Assign hour
            df_obj[:, "hour"] .= h

            # Append to network dataframe
            DataFrames.append!(df, df_obj)
        end
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
