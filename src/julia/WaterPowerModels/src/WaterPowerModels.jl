module WaterPowerModels

import PowerModels
import JuMP
import DataFrames
import Infiltrator  # For debugging only


function update_load!(network_data_multi::Dict, df_node_load::DataFrames.DataFrame, d::Int)
    """
    Update loads for network data 

    # Arguments
    - `network_data_multi::Dict`: Multi network data
    - `df_node_load::DataFrames.DataFrame`: DataFrame of node-level loads
    - `d::Int`: Day index
    """
    for h in 1:length(network_data_multi)
        # Extract network data
        nw_data = network_data_multi["nw"][string(h)]

        for load in values(nw_data["load"])
            # Pandapower indexing
            pp_d = d-1
            pp_bus = load["load_bus"] - 1
            
            # Filters
            df_node_load_filter = df_node_load[in(pp_d).(df_node_load.day_index), :]
            df_node_load_filter = df_node_load_filter[in(h).(df_node_load_filter.hour_index), :]
            df_node_load_filter = df_node_load_filter[in(pp_bus).(df_node_load_filter.bus), :]
            load_mw = df_node_load_filter[!, "load_mw"][1]
            load_pu = load_mw/100.0

            # Set load
            load["pd"] = load_pu
        end
    end

    return network_data_multi
end

function time_series_loads!(network_data_multi::Dict)
    """
    Create a time series loads.

    # Arguments
    - `network_data_multi::Dict`: multi network data
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


function once_through_withdrawal(;
    eta_net:: Float64,
    k_os:: Float64,
    delta_t:: Float64,
    beta_proc:: Float64,
    rho_w=1.0,
    c_p=0.04184,
)
    """
    Once through withdrawal model

    # Arguments
    - `eta_net:: Float64`: Ratio of electricity generation rate to thermal input
    - `k_os:: Float64`: Thermal input lost to non-cooling system sinks
    - `delta_t:: Float64`: Inlet/outlet water temperature difference in C
    - `beta_proc:: Float64`: Non-cooling rate in L/MWh
    - `rho_w=1.0`: Desnity of Water kg/L, by default 1.0
    - `c_p=0.04184`: Specific head of water in MJ/(kg-K), by default 0.04184
    """
    efficiency = 3600 * (1-eta_net-k_os) / eta_net
    physics = 1 / (rho_w*c_p*delta_t)
    beta_with = efficiency * physics + beta_proc

    return beta_with
end


function once_through_consumption(;
    eta_net:: Float64,
    k_os:: Float64,
    delta_t:: Float64,
    beta_proc:: Float64,
    k_de=0.01,
    rho_w=1.0,
    c_p=0.04184,
)
    """
    Once through consumption model

    # Arguments
    - `eta_net:: Float64`: Ratio of electricity generation rate to thermal input
    - `k_os:: Float64`: Thermal input lost to non-cooling system sinks
    - `delta_t:: Float64`: Inlet/outlet water temperature difference in C
    - `beta_proc:: Float64`: Non-cooling rate in L/MWh
    - `k_de:: Float64`: Downstream evaporation, by default 0.01
    - `rho_w:: Float64`: Desnity of Water kg/L, by default 1.0
    - `c_p:: Float64`: Specific heat of water in MJ/(kg-K), by default 0.04184
    """
    # Model
    efficiency = 3600 * (1-eta_net-k_os) / eta_net
    physics = k_de / (rho_w*c_p*delta_t)
    beta_con = efficiency * physics + beta_proc

    return beta_con
end

function recirculating_withdrawal(;
    eta_net:: Float64,
    k_os:: Float64,
    beta_proc:: Float64,
    eta_cc:: Int64,
    k_sens:: Float64,
    h_fg=2.454,
    rho_w=1.0,
)
    """
    Recirculating withdrawal model

    # Arguments
    `eta_net:: Float64`: Ratio of electricity generation rate to thermal input
    `k_os:: Float64`: Thermal input lost to non-cooling system sinks
    `beta_proc:: Float64`: Non-cooling rate in L/MWh
    `eta_cc:: Int64`: Number of cooling cycles between 2 and 10
    `k_sens:: Float64`: Heat load rejected
    `h_fg:: Float64`: Latent heat of vaporization of water, by default 2.454 MJ/kg
    `rho_w:: Float64`: Desnity of Water kg/L, by default 1.0
    """
    # Model
    efficiency = 3600 * (1-eta_net-k_os) / eta_net
    physics = (1 - k_sens) / (rho_w * h_fg)
    blowdown = 1 + 1 / (eta_cc - 1)
    beta_with = efficiency * physics * blowdown + beta_proc

    return beta_with
end

function recirculating_consumption(;
    eta_net:: Float64,
    k_os:: Float64,
    beta_proc:: Float64,
    eta_cc:: Int64,
    k_sens:: Float64,
    k_bd=1.0,
    h_fg=2.454,
    rho_w=1.0
)
    """
    Recirculating consumption model

    # Arguments
    eta_net:: Float64`: Ratio of electricity generation rate to thermal input
    k_os:: Float64`: Thermal input lost to non-cooling system sinks
    beta_proc:: Float64`: Non-cooling rate in L/MWh
    eta_cc:: Int64`: Number of cooling cycles between 2 and 10
    k_sens:: Float64`: Heat load rejected
    k_bd:: Float64`: Blowdown discharge fraction. Plants in water abundant areas
    are able to legally discharge most of their cooling tower blowndown according
    to Rutberg et al. 2011.
    h_fg:: Float64`: Latent heat of vaporization of water, default 2.454 MJ/kg
    rho_w:: Float64`: Desnity of Water kg/L, by default 1.0
    """
    # Model
    efficiency = 3600 * (1-eta_net-k_os) / eta_net
    physics = (1 - k_sens) / (rho_w * h_fg)
    blowdown = 1 + (1 - k_bd) / (eta_cc - 1)
    beta_con = efficiency * physics * blowdown + beta_proc

    return beta_con
end

end # module
