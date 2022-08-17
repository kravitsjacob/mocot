module MOCOT

import PowerModels
import JuMP
import DataFrames
import Statistics
import Ipopt
import Infiltrator


function get_gen_info(
    network_data:: Dict,
    df_gen_info_water_ramp:: DataFrames.DataFrame
)
    """
    Get generator information by merging PowerModels and MATPOWER data

    # Arguments
    - `network_data:: Dict`: Network data 
    - `df_gen_info_water_ramp:: DataFrames.DataFrame`: Generator information from preprocessing
    """
    df_gen_info_pm = MOCOT.network_to_df(network_data, "gen", ["gen_bus"])
    df_gen_info = DataFrames.leftjoin(
        df_gen_info_pm,
        df_gen_info_water_ramp,
        on = :gen_bus => Symbol("MATPOWER Index")
    )
    return df_gen_info
end

function update_load!(network_data_multi::Dict, df_node_load:: DataFrames.DataFrame, d::Int)
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
            pp_bus = load["load_bus"] - 1
            
            # Filters
            df_node_load_filter = df_node_load[in(d).(df_node_load.day_index), :]
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

function get_k_os(fuel:: String)
    """
    Get other sinks fraction from DOE-NETL reference models

    # Arguments
    `fuel:: String`: Fuel code
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

function get_beta_proc(fuel:: String)
    """
    Get water withdrawal from non-cooling processes in [L/MWh] based on DOE-NETL model

    # Arguments
    `fuel:: String`: Fuel code
    """
    if fuel == "coal"
        beta_proc = 200.0
    else
        beta_proc = 10.0
    end

    return beta_proc
end

function get_k_sens(t_inlet:: Float64)
    """
    Get heat load rejected through convection

    # Arguments
    `t_inlet:: Float64`: Dry bulb temperature of inlet air C
    """
    term_1 = -0.000279*t_inlet^3
    term_2 = 0.00109*t_inlet^2
    term_3 = -0.345*t_inlet
    k_sens = term_1 + term_2 + term_3 + 26.7
    k_sens = k_sens/100  # Convert to ratio
    return k_sens
end


function gen_water_use(
    water_temperature:: Float64,
    air_temperature:: Float64,
    df_gen_info:: DataFrames.DataFrame,
    df_eia_heat_rates:: DataFrames.DataFrame
)
    """
    Run water use model for every generator
    
    # Arguments
    - `water_temperature:: Float64`: Water temperature in C
    - `air_temperature:: Float64`: Dry bulb temperature of inlet air C
    - `df_gen_info:: DataFrames.DataFrame`: Generator information
    - `df_eia_heat_rates:: DataFrames.DataFrame`: DataFrame of eia heat rates
    """
    # Initialization
    gen_beta_with = Dict{String, Float64}()
    gen_beta_con = Dict{String, Float64}()

    # Water use for each generator
    for row in DataFrames.eachrow(df_gen_info)
        obj_name = row["obj_name"]
        fuel =  string(row["MATPOWER Fuel"])
        cool = string(row["923 Cooling Type"])
        beta_with, beta_con = MOCOT.water_use(
            water_temperature,
            air_temperature,
            fuel,
            cool,
            df_eia_heat_rates
        )
        gen_beta_with[obj_name] = beta_with
        gen_beta_con[obj_name] = beta_con   
    end

    return gen_beta_with, gen_beta_con
end


function water_use(
    water_temperature:: Float64,
    air_temperature:: Float64,
    fuel:: String,
    cool:: String,
    df_eia_heat_rates:: DataFrames.DataFrame
)
    """
    Water use model

    # Arguments
    `water_temperature:: Float64`: Water temperature in C
    `air_temperature:: Float64`: Dry bulb temperature of inlet air C
    `fuel:: String`: Fuel type
    `cool:: String`: Cooling system type
    `df_eia_heat_rates:: DataFrames.DataFrame`: DataFrame of eia heat rates
    """
    # Get coefficients
    k_os = get_k_os(fuel)
    eta_net = get_eta_net(fuel, df_eia_heat_rates)
    beta_proc = get_beta_proc(fuel)

    # Run simulation
    if cool == "OC"
        # Delta t processing
        max_temp = 32.0
        delta_t = max_temp - water_temperature

        # Water models
        beta_with = once_through_withdrawal(
            eta_net=eta_net,
            k_os=k_os,
            delta_t=delta_t,
            beta_proc=beta_proc
        )
        beta_con = once_through_consumption(
            eta_net=eta_net,
            k_os=k_os,
            delta_t=delta_t,
            beta_proc=beta_proc
        )

    elseif cool == "RC" || cool == "RI"
        eta_cc = 5
        # Get k_sens
        k_sens = get_k_sens(air_temperature)

        # Water models
        beta_with = recirculating_withdrawal(
            eta_net=eta_net, 
            k_os=k_os, 
            beta_proc=beta_proc, 
            eta_cc=eta_cc, 
            k_sens=k_sens
        )
        beta_con = recirculating_consumption(
            eta_net=eta_net,
            k_os=k_os,
            beta_proc=beta_proc,
            eta_cc=eta_cc,
            k_sens=k_sens,
        )

    elseif cool == "No Cooling System"
        beta_with = 0.0
        beta_con = 0.0
    
    end

    return beta_with, beta_con
end

function add_water_terms!(
    pm,
    beta_dict:: Dict{String, Float64},
    w:: Float64,
)
    """
    Add water use terms to objective function
    
    # Arguments
    `pm:: Any`: Any PowerModel
    `beta_dict:: Dict{String, Float64}`: Dictionary of beta values
    `w:: Float64`: Weight for water use
    """
    # Setup
    water_terms = 0.0
    nw_data = pm.data["nw"]

    # Loop through hours
    for h in 1:length(nw_data)
        for (gen_name, beta_val) in beta_dict
            gen_index = parse(Int64, gen_name)
            gen_water_term = w * beta_val * PowerModels.var(
                pm, h, :pg, gen_index
            )
            water_terms = water_terms + gen_water_term
        end
    end
    
    # Update objective function
    current_objective = JuMP.objective_function(pm.model)
    new_objective = @JuMP.expression(pm.model, current_objective + water_terms)
    JuMP.set_objective_function(pm.model, new_objective)

    return pm
end

function add_ramp_rates!(
    pm,
    gen_ramp:: Dict{String, Float64},
)
    """
    Add ramp rates to model

    # Arguments
    `pm:: Any`: Any PowerModel
    `gen_ramp:: Dict{String, Float64}`: Dictionary ramp values for each generator
    """
    nw_data = pm.data["nw"]
    h_total = length(nw_data)

    for gen_name in keys(gen_ramp)
        # Extract ramp rates to pu
        ramp = gen_ramp[gen_name]/100.0 
        
        gen_index = parse(Int, gen_name)
        # Ramping up
        JuMP.@constraint(
            pm.model,
            [h in 1:h_total-1],
            PowerModels.var(pm, h+1, :pg, gen_index) - PowerModels.var(pm, h, :pg, gen_index) <= ramp
        )
        # Ramping down
        JuMP.@constraint(
            pm.model,
            [h in 1:h_total-1],
            PowerModels.var(pm, h+1, :pg, gen_index) - PowerModels.var(pm, h, :pg, gen_index) >= -1.0 * ramp
        )
    end

    return pm
end

function set_all_gens!(nw_data, prop:: String, val)
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


function simulation(
    network_data:: Dict,
    df_gen_info:: DataFrames.DataFrame,
    df_eia_heat_rates:: DataFrames.DataFrame, 
    df_air_water:: DataFrames.DataFrame,
    df_node_load:: DataFrames.DataFrame,
    ;
    w_with:: Float64=0.0,
    w_con:: Float64=0.0,
)
    """
    Simulation of water and energy system

    # Arguments
    - `network_data:: Dict`: PowerModels Network data
    - `df_gen_info:: DataFrames.DataFrame`: Generator information
    - `df_eia_heat_rates:: DataFrames.DataFrame`: EIA heat rates
    - `df_air_water:: DataFrames.DataFrame`: Exogenous air and water temperatures
    - `df_node_load:: DataFrames.DataFrame`: Node-level loads
    - `w_with:: Float64=0.0`: Withdrawal weight
    - `w_con:: Float64=0.0`: Consumption weight
    """
    # Initialization
    h_total = 24
    d_total = 7
    state = Dict{String, Dict}()
    state["power"] = Dict("0" => Dict())
    state["withdraw_rate"] = Dict("0" => Dict{String, Float64}())
    state["consumption_rate"] = Dict("0" => Dict{String, Float64}())

    # Prepare generator ramping
    gen_ramp = Dict{String, Float64}()
    for row in DataFrames.eachrow(df_gen_info)
        gen_ramp[string(row["obj_name"])] = float(row["Ramp Rate (MW/hr)"])
    end

    # Commit all generators
    network_data = MOCOT.set_all_gens!(network_data, "gen_status", 1)
    network_data = MOCOT.set_all_gens!(network_data, "pmin", 0.0)

    # Make multinetwork
    network_data_multi = PowerModels.replicate(network_data, h_total)

    # Initialize water use based on 25.0 C
    water_temperature = 25.0
    air_temperature = 25.0
    gen_beta_with, gen_beta_con = MOCOT.gen_water_use(
        water_temperature,
        air_temperature,
        df_gen_info,
        df_eia_heat_rates
    )
    state["withdraw_rate"]["0"] = gen_beta_with
    state["consumption_rate"]["0"] = gen_beta_con

    # Simulation
    for d in 1:d_total
        # Update loads
        # TODO port to constraint version
        network_data_multi = MOCOT.update_load!(
            network_data_multi,
            df_node_load,
            d
        )

        # Create power system model
        # TODO move to outside the loop
        pm = PowerModels.instantiate_model(
            network_data_multi,
            PowerModels.DCPPowerModel,
            PowerModels.build_mn_opf
        )

        # Add ramp rates
        pm = add_ramp_rates!(pm, gen_ramp)

        # Add water use penalities
        pm = MOCOT.add_water_terms!(
            pm,
            state["withdraw_rate"][string(d-1)],
            w_with
        )
        pm = MOCOT.add_water_terms!(
            pm,
            state["consumption_rate"][string(d-1)],
            w_con
        )

        # Solve power system model
        state["power"][string(d)] = PowerModels.optimize_model!(pm, optimizer=Ipopt.Optimizer)

        # Exogenous air and water temperatures
        filter_air_water = df_air_water[in([d]).(df_air_water.day_index), :]
        air_temperature = filter_air_water[!, "air_temperature"][1]
        water_temperature = filter_air_water[!, "water_temperature"][1]

        # Water use
        gen_beta_with, gen_beta_con = MOCOT.gen_water_use(
            water_temperature,
            air_temperature,
            df_gen_info,
            df_eia_heat_rates
        )
        state["withdraw_rate"][string(d)] = gen_beta_with
        state["consumption_rate"][string(d)] = gen_beta_con
    end

    return state
end

end # module
