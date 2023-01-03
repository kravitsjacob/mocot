"""Generator types and methods"""


"""
Thermoelectric generator with once-through cooling system
"""
mutable struct OnceThroughGenerator
    "Ratio of electricity generation rate to thermal input"
    eta_net:: Float64
    "Thermal input lost to non-cooling system sinks"
    k_os:: Float64
    "Non-cooling rate [L/MWh]"
    beta_proc:: Float64
    "Total efficiency"
    eta_total:: Float64
    "Electric efficiency"
    eta_elec:: Float64
    "Withdrawal limit in [L/MWh]"
    beta_with_limit:: Float64
    "Consumption limit in [L/MWh]"
    beta_con_limit:: Float64
    "Emission rate in [lbs/MWh]"
    emit_rate:: Float64
    "Ramp rate in [MW/hr]"
    ramp_rate:: Float64
    "Fuel type (only for metric aggregation)"
    fuel:: String
    "Cooling type (only for metric aggregation)"
    cool:: String
end


function new_once_through_generator()
    """
    Create new once through generator
    """
    gen = OnceThroughGenerator(
        NaN,
        NaN,
        NaN,
        NaN,
        NaN,
        NaN,
        NaN,
        NaN,
        NaN,
        "",
        "", 
    )

    return gen
end


function set_water_use_parameters!(
    gen:: OnceThroughGenerator,
    eta_net:: Float64,
    k_os:: Float64,
    beta_proc:: Float64,
)
    """
    Set parameters for water use models
    
    # Arguments
    - `gen:: OnceThroughGenerator`: Generator
    - `eta_net:: Float64`: Ratio of electricity generation rate to thermal input
    - `k_os:: Float64`: Thermal input lost to non-cooling system sinks
    - `beta_proc:: Float64`: Non-cooling rate [L/MWh]
    """
    gen.eta_net = eta_net
    gen.k_os = k_os
    gen.beta_proc = beta_proc

    return gen
end


function set_water_capacity_parameters!(
    gen:: OnceThroughGenerator,
    eta_total:: Float64,
    eta_elec:: Float64,
)
    """
    Set parameters for water-capacity models

    # Arguments
    - `gen:: OnceThroughGenerator`: Generator
    - `eta_total:: Float64`: Total efficiency
    - `eta_elec:: Float64`: Electric efficiency
    """
    gen.eta_total = eta_total
    gen.eta_elec = eta_elec
    
    return gen
end


function set_water_use_limits!(
    gen:: OnceThroughGenerator,
    beta_with_limit:: Float64,
    beta_con_limit:: Float64,
)
    """
    Set parameters for water-capacity models

    # Arguments
    - `gen:: OnceThroughGenerator`: Generator
    - `beta_with_limit:: Float64`: Withdrawal limit in [L/MWh]
    - `beta_con_limit:: Float64`: Consumption limit in [L/MWh]
    """
    gen.beta_with_limit = beta_with_limit
    gen.beta_con_limit = beta_con_limit
    
    return gen
end


function get_withdrawal(
    gen:: OnceThroughGenerator,
    delta_t:: Float64,
    rho_w=1.0,
    c_p=0.004184,
)
    """
    Once through withdrawal model

    # Arguments
    - `gen:: OnceThroughGenerator`: Generator
    - `delta_t:: Float64`: Inlet/outlet water temperature difference [C]
    - `rho_w=1.0`: Desnity of Water [kg/L], by default 1.0
    - `c_p=0.004184`: Specific head of water in [MJ/(kg-K)], by default 0.004184
    """
    # Unpack
    eta_net = gen.eta_net
    k_os = gen.k_os
    beta_proc = gen.beta_proc

    # Model
    efficiency = 3600.0 * (1.0-eta_net-k_os) / eta_net
    physics = 1.0 / (rho_w*c_p*delta_t)
    beta_with = efficiency * physics + beta_proc

    return beta_with
end


function get_consumption(
    gen:: OnceThroughGenerator,
    delta_t:: Float64,
    k_de=0.01,
    rho_w=1.0,
    c_p=0.04184,
)
    """
    Once through consumption model

    # Arguments
    - `gen:: OnceThroughGenerator`: Generator
    - `delta_t:: Float64`: Inlet/outlet water temperature difference [C]
    - `k_de:: Float64`: Downstream evaporation, by default 0.01
    - `rho_w:: Float64`: Desnity of Water [kg/L], by default 1.0
    - `c_p:: Float64`: Specific heat of water in [MJ/(kg-K)], by default 0.04184
    """
    # Unpack
    eta_net = gen.eta_net
    k_os = gen.k_os
    beta_proc = gen.beta_proc

    # Model
    efficiency = 3600 * (1-eta_net-k_os) / eta_net
    physics = k_de / (rho_w*c_p*delta_t)
    beta_con = efficiency * physics + beta_proc

    return beta_con
end


function get_delta(
    gen:: OnceThroughGenerator,
    beta_with:: Float64,
    rho_w=1.0,
    c_p=0.004184,
)
    """
    Once through withdrawal model solving for delta T

    # Arguments
    - `gen:: OnceThroughGenerator`: Generator
    - `beta_with:: Float64`: Withdrawal limit [L/MWh]
    - `rho_w=1.0`: Desnity of Water [kg/L], by default 1.0
    - `c_p=0.004184`: Specific head of water in [MJ/(kg-K)], by default 0.004184
    """
    # Unpack
    eta_net = gen.eta_net
    k_os = gen.k_os
    beta_proc = gen.beta_proc    

    # Model
    efficiency = 3600.0 * (1.0-eta_net-k_os) / eta_net
    physics = 1.0 / (rho_w*c_p)
    water_use = 1.0 / (beta_with - beta_proc)
    delta_t = water_use * physics * efficiency

    return delta_t
end


function get_capacity(
    gen:: OnceThroughGenerator,
    KW:: Float64,
    delta_T:: Float64,
    Q:: Float64,
    alpha=0.01,
    lambda=1.0,
    gamma=0.02,
    rho_w=997.77,
    c_p=0.004184,
)
    """
    Once through capacity reduction model

    # Arguments
    - `gen:: OnceThroughGenerator`: Generator
    - `KW:: Float64`: Current capacity [MW]
    - `delta_T:: Float64`: Inlet outlet temperature difference [C]
    - `Q:: Float64`: Streamflow [cms]
    - `alpha=0.01`: Share of waste heat not discharged by cooling water
    - `lambda=1.0`: Correction factor accounting for the effects of reductions in efficiencies when power plants are operating at low capacities.
    - `gamma=0.02`: Maximum fraction of streamflow to be withdrawn for cooling of thermoelectric power.
    - `rho_w=997.77`: Water density [kg/cm]
    - `c_p=0.004184`: Heat capacity of water [MJ/kg-C]
    """
    # Unpacking
    eta_total = gen.eta_total
    eta_elec = gen.eta_elec

    # Calculating q
    eta_term = (1.0-eta_total)/eta_elec
    q_OC = KW * eta_term * (1.0 - alpha) / (rho_w * c_p * max(delta_T, 0.0))

    # Numerator
    top_left = min( (gamma*Q), q_OC )
    top_right = max( delta_T, 0.0)
    top = top_left * rho_w * c_p * top_right

    # Denominator
    bottom = eta_term * lambda * (1.0 - alpha)

    # Compute capacity
    p_thermo_OC = top/bottom

    if p_thermo_OC/KW < 0.50
        lambda = 0.90
        p_thermo_OC = p_thermo_OC * lambda
    end

    return p_thermo_OC
end


get_water_use(
    gen:: OnceThroughGenerator,
    inlet_temperature:: Float64,
    regulatory_temperature:: Float64,
) = begin
    """
    Once through water use (withdrawal and consumption)

    # Arguments
    - `inlet_temperature:: Float64`: Inlet water temperature in [C]
    - `regulatory_temperature:: Float64`: Regulatory water temperature in [C]
    """

    # Initial violation test
    delta_t = 10.0
    if inlet_temperature + delta_t > regulatory_temperature  # Causes violation
        delta_t = regulatory_temperature - inlet_temperature  # Try to prevent
    end
    # Water models
    beta_with = MOCOT.get_withdrawal(
        gen,
        delta_t,
    )
    beta_con = MOCOT.get_consumption(
        gen,
        delta_t,
    )

    # If beta limits hit
    if (beta_with > gen.beta_with_limit) || (beta_con > gen.beta_con_limit)
        # Set to limits
        beta_with = gen.beta_with_limit
        beta_con = gen.beta_con_limit

        # Solve for temperature
        delta_t = MOCOT.get_delta(
            gen,
            beta_with
        )
    end

    return beta_with, beta_con, delta_t
end


"""
Thermoelectric generator with reciruclating cooling system
"""
mutable struct RecirculatingGenerator
    "Ratio of electricity generation rate to thermal input"
    eta_net:: Float64
    "Thermal input lost to non-cooling system sinks"
    k_os:: Float64
    "Non-cooling rate [L/MWh]"
    beta_proc:: Float64
    "Number of cooling cycles between 2 and 10"
    eta_cc:: Int64
    "Blowdown discharge fraction. Plants in water abundant areas are able to legally discharge most of their cooling tower blowndown according to Rutberg et al. 2011"
    k_bd:: Float64
    "Total efficiency"
    eta_total:: Float64
    "Electric efficiency"
    eta_elec:: Float64
    "Emission rate in [lbs/MWh]"
    emit_rate:: Float64
    "Ramp rate in [MW/hr]"
    ramp_rate:: Float64
    "Fuel type (only for metric aggregation)"
    fuel:: String
    "Cooling type (only for metric aggregation)"
    cool:: String
end


function new_recirculating_generator()
    """
    Create new recirculating generator
    """
    gen = RecirculatingGenerator(
        NaN,
        NaN,
        NaN,
        0,
        NaN,
        NaN,
        NaN,
        NaN,
        NaN,
        "",
        "", 
    )

    return gen
end


function set_water_use_parameters!(
    gen:: RecirculatingGenerator,
    eta_net:: Float64,
    k_os:: Float64,
    beta_proc:: Float64,
    eta_cc:: Int64,
    k_bd:: Float64,
)
    """
    Set parameters for water use models
    
    # Arguments
    - `gen:: OnceThroughGenerator`: Generator
    - `eta_net:: Float64`: Ratio of electricity generation rate to thermal input
    - `k_os:: Float64`: Thermal input lost to non-cooling system sinks
    - `beta_proc:: Float64`: Non-cooling rate [L/MWh]
    - `eta_cc:: Int64`: Number of cooling cycles between 2 and 10
    - `k_bd:: Float64`: Blowdown discharge fraction. Plants in water abundant areas are able to legally discharge most of their cooling tower blowndown according to Rutberg et al. 2011
    """
    gen.eta_net = eta_net
    gen.k_os = k_os
    gen.beta_proc = beta_proc
    gen.eta_cc = eta_cc
    gen.k_bd = k_bd

    return gen
end


function set_water_capacity_parameters!(
    gen:: RecirculatingGenerator,
    eta_total:: Float64,
    eta_elec:: Float64,
)
    """
    Set parameters for water-capacity models

    # Arguments
    - `gen:: RecirculatingGenerator`: Generator
    - `eta_total:: Float64`: Total efficiency
    - `eta_elec:: Float64`: Electric efficiency
    """
    gen.eta_total = eta_total
    gen.eta_elec = eta_elec
    
    return gen
end


function set_water_use_limits!(
    gen:: RecirculatingGenerator,
    beta_with_limit:: Float64,
    beta_con_limit:: Float64,
)
    """
    Set parameters for water-capacity models

    # Arguments
    - `gen:: OnceThroughGenerator`: Generator
    - `beta_with_limit:: Float64`: Withdrawal limit in [L/MWh]
    - `beta_con_limit:: Float64`: Consumption limit in [L/MWh]
    """
    gen.beta_with_limit = beta_with_limit
    gen.beta_con_limit = beta_con_limit
    
    return gen
end


get_withdrawal(
    gen:: RecirculatingGenerator,
    k_sens:: Float64,
    h_fg=2.454,
    rho_w=1.0,
) = begin
    """
    Recirculating withdrawal model

    # Arguments
    - `gen:: RecirculatingGenerator`: Generator
    - `k_sens:: Float64`: Heat load rejected
    - `h_fg:: Float64`: Latent heat of vaporization of water, by default 2.454 [MJ/kg]
    - `rho_w:: Float64`: Desnity of Water [kg/L], by default 1.0
    """
    # Unpack
    eta_net = gen.eta_net
    k_os = gen.k_os
    beta_proc = gen.beta_proc
    eta_cc = gen.eta_cc

    # Model
    efficiency = 3600 * (1-eta_net-k_os) / eta_net
    physics = (1 - k_sens) / (rho_w * h_fg)
    blowdown = 1 + 1 / (eta_cc - 1)
    beta_with = efficiency * physics * blowdown + beta_proc

    return beta_with
end


get_consumption(
    gen:: RecirculatingGenerator,
    k_sens:: Float64,
    h_fg=2.454,
    rho_w=1.0,
) = begin
    """
    Recirculating consumption model

    # Arguments
    - `gen:: RecirculatingGenerator`: Generator
    - `k_sens:: Float64`: Heat load rejected
    - `h_fg:: Float64`: Latent heat of vaporization of water, default 2.454 [MJ/kg]
    - `rho_w:: Float64`: Desnity of Water [kg/L], by default 1.0
    """
    # Unpack
    eta_net = gen.eta_net
    k_os = gen.k_os
    beta_proc = gen.beta_proc
    eta_cc = gen.eta_cc
    k_bd = gen.k_bd

    # Model
    efficiency = 3600 * (1-eta_net-k_os) / eta_net
    physics = (1 - k_sens) / (rho_w * h_fg)
    blowdown = 1 + (1 - k_bd) / (eta_cc - 1)
    beta_con = efficiency * physics * blowdown + beta_proc

    return beta_con
end


function get_capacity(
    gen:: RecirculatingGenerator,
    KW:: Float64,
    delta_T:: Float64,
    Q:: Float64,
    alpha=0.01,
    beta=0.986,
    omega=0.95,
    lambda=1.0,
    gamma=0.02,
    EZ=3.0,
    rho_w=997.77,
    c_p=0.004184,
)
    """
    Recirculating capacity reduction model

    # Arguments
    - `gen:: RecirculatingGenerator`: Generator
    - `KW:: Float64`: Capacity [MW]
    - `delta_T:: Float64`: Inlet outlet temperature difference [C]
    - `Q:: Float64`: Streamflow [cmps]
    - `alpha=0.01`: Share of waste heat not discharged by cooling water
    - `beta=0.986`: Share of waste heat released into the air
    - `omega=0.95`: Correction factor accounting for effects of changes in air temperature and humidity within a year
    - `lambda=1.0`: Correction factor accounting for the effects of reductions in efficiencies when power plants are operating at low capacities.
    - `gamma=0.02`: Maximum fraction of streamflow to be withdrawn for cooling of thermoelectric power.
    - `EZ=3.0`: Densification factor accounting for replacement of water in cooling towers to avoid high salinity levels   
    - `rho_w=997.77`: Water density [kg/cm]
    - `c_p=0.004184`: Heat capacity of water [MJ/kg-C]
    """
    # Unpacking
    eta_total = gen.eta_total
    eta_elec = gen.eta_elec

    # Calculating q
    eta_term = (1.0-eta_total)/eta_elec
    eff_term = (1.0-alpha) * (1.0-beta) * omega * EZ
    q_RC = KW * eta_term * eff_term / (rho_w * c_p * max(delta_T, 0.0))

    # Numerator
    top_left = min( (gamma*Q), q_RC )
    top_right = max( delta_T, 0.0)
    top = top_left * rho_w * c_p * top_right

    # Denominator
    bottom = eta_term * lambda * eff_term

    # Compute capacity
    p_thermo_RC = top/bottom

    if p_thermo_RC/KW < 0.50
        lambda = 0.90
        p_thermo_RC = p_thermo_RC * lambda
    end

    return p_thermo_RC
end


get_water_use(
    gen,
    air_temperature,
) = begin
    """
    Recirculating water use (withdrawal and consumption)

    # Arguments
    - `gen:: RecirculatingGenerator`: Generator
    - `air_temperature:: Float64`: Air temperature in C
    """
    # Get k_sens
    k_sens = get_k_sens(air_temperature)

    # Water models
    beta_with = get_withdrawal(
        gen,
        k_sens,
    )
    beta_con = get_consumption(
        gen,
        k_sens,
    )

    return beta_with, beta_con
end


function get_k_sens(t_inlet:: Float64)
    """
    Get heat load rejected through convection

    # Arguments
    `t_inlet:: Float64`: Dry bulb temperature of inlet air [C]
    """
    term_1 = -0.000279*t_inlet^3
    term_2 = 0.00109*t_inlet^2
    term_3 = -0.345*t_inlet
    k_sens = term_1 + term_2 + term_3 + 26.7
    k_sens = k_sens/100  # Convert to ratio
    return k_sens
end


"""
Thermoelectric generator with no cooling system
"""
struct NoCoolingGenerator
    "Emission rate in [lbs/MWh]"
    emit_rate:: Float64
    "Ramp rate in [MW/hr]"
    ramp_rate:: Float64
    "Fuel type (only for metric aggregation)"
    fuel:: String
    "Cooling type (only for metric aggregation)"
    cool:: String
end
