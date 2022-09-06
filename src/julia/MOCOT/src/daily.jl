# Functions for running at a daily-resolution simulation


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

function once_through_withdrawal_for_delta(;
    eta_net:: Float64,
    k_os:: Float64,
    beta_with_limit:: Float64,
    beta_proc:: Float64,
    rho_w=1.0,
    c_p=0.04184,
)
    """
    Once through withdrawal model solving for delta T

    # Arguments
    - `eta_net:: Float64`: Ratio of electricity generation rate to thermal input
    - `k_os:: Float64`: Thermal input lost to non-cooling system sinks
    - `beta_with_limit:: Float64`: Withdrawal limit
    - `beta_proc:: Float64`: Non-cooling rate in L/MWh
    - `rho_w=1.0`: Desnity of Water kg/L, by default 1.0
    - `c_p=0.04184`: Specific head of water in MJ/(kg-K), by default 0.04184
    """

    efficiency = 3600 * (1-eta_net-k_os) / eta_net
    physics = 1 / (rho_w*c_p)
    water_use = 1 / (beta_with_limit - beta_proc)
    delta_t = water_use * physics * efficiency

    return delta_t
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


function once_through_consumption_for_delta(;
    eta_net:: Float64,
    k_os:: Float64,
    beta_con_limit:: Float64,
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
    - `beta_con_limit:: Float64`: Consumption rate limit
    - `beta_proc:: Float64`: Non-cooling rate in L/MWh
    - `k_de:: Float64`: Downstream evaporation, by default 0.01
    - `rho_w:: Float64`: Desnity of Water kg/L, by default 1.0
    - `c_p:: Float64`: Specific heat of water in MJ/(kg-K), by default 0.04184
    """
    # Model

    efficiency = 3600 * (1-eta_net-k_os) / eta_net
    physics = k_de / (rho_w*c_p)
    water_use = 1 / (beta_con_limit - beta_proc)
    delta_t = water_use * physics * efficiency

    return delta_t
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


function themal_limits(
    beta_with:: Float64,
    beta_with_limit:: Float64,
    beta_con:: Float64,
    beta_con_limit:: Float64,
    k_os:: Float64,
    beta_proc:: Float64,
    eta_net:: Float64
)
    """
    Thermal discharge limits model

    # Arguments
    - `beta_with:: Float64`: Withdrawal rate in L/MWh
    - `beta_with_limit:: Float64`: Withdrawal limit in L/MWh
    - `beta_con:: Float64`: Consumption rate in L/MWh
    - `beta_con_limit:: Float64`: Consumption limit in L/MWh
    - `k_os:: Float64`: Thermal input lost to non-cooling system sinks
    - `beta_proc:: Float64`: Non-cooling rate in L/MWh
    - `eta_net:: Float64`: Ratio of electricity generation rate to thermal input
    """
    delta_t_con = 0.0
    delta_t_with = 0.0

    # Withdrawal limits
    if beta_with >= beta_with_limit
        beta_with = beta_with_limit

        # Solve for delta t
        delta_t_with = once_through_withdrawal_for_delta(
            eta_net=eta_net,
            k_os=k_os,
            beta_with_limit=beta_with,
            beta_proc=beta_proc
        )
    end

    # Consumption limits
    if beta_con >= beta_con_limit
        beta_con = beta_con_limit
        
        # Solve for delta t
        delta_t_con = once_through_consumption_for_delta(
            eta_net=eta_net,
            k_os=k_os,
            beta_con_limit=beta_con,
            beta_proc=beta_proc
        )
    end

    # Discharge temperature
    delta_t = max(delta_t_con, delta_t_with)

    return beta_with, beta_con, delta_t
end


function gen_water_use(
    water_temperature:: Float64,
    air_temperature:: Float64,
    network_data:: Dict
)
    """
    Run water use model for every generator
    
    # Arguments
    - `water_temperature:: Float64`: Water temperature in C
    - `air_temperature:: Float64`: Dry bulb temperature of inlet air C
    - `network_data:: Dict`: PowerModels network data
    """
    # Initialization
    gen_beta_with = Dict{String, Float64}()
    gen_beta_con = Dict{String, Float64}()
    gen_discharge_violation = Dict{String, Float64}()

    # Water use for each generator
    for (obj_name, obj_props) in network_data["gen"]
        cool = obj_props["cus_cool"]
        fuel = obj_props["cus_fuel"]
        eta_net = obj_props["cus_heat_rate"]

        beta_with, beta_con = MOCOT.water_use(
            water_temperature,
            air_temperature,
            fuel,
            cool,
            eta_net
        )

        if cool == "OC"
            delta_t = 0.0
            try
                k_os = get_k_os(fuel)
                beta_proc = get_beta_proc(fuel)
                beta_with, beta_con, delta_t = themal_limits(
                    beta_with,
                    obj_props["cus_with_limit"],
                    beta_con,
                    obj_props["cus_con_limit"],
                    k_os,
                    beta_proc,
                    eta_net
                )
            catch
                println("Missing water use rate limits for generator $obj_name")
            end
            gen_discharge_violation[obj_name] = delta_t
        end


        gen_beta_with[obj_name] = beta_with
        gen_beta_con[obj_name] = beta_con

    end

    return gen_beta_with, gen_beta_con, gen_discharge_violation
end


function water_use(
    water_temperature:: Float64,
    air_temperature:: Float64,
    fuel:: String,
    cool:: String,
    eta_net:: Float64
)
    """
    Water use model

    # Arguments
    - `water_temperature:: Float64`: Water temperature in C
    - `air_temperature:: Float64`: Dry bulb temperature of inlet air C
    - `fuel:: String`: Fuel type
    - `cool:: String`: Cooling system type
    - `eta_net:: Float64`: Ratio of electricity generation rate to thermal input
    """
    # Get coefficients
    k_os = get_k_os(fuel)
    beta_proc = get_beta_proc(fuel)

    # Run simulation
    if cool == "OC"
        # Delta t processing
        max_temp = 33.7
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
