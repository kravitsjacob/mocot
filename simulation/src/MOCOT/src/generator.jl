"""Generator types and methods"""


"""
Thermoelectric generator with once-through cooling system
"""
struct OnceThroughGenerator
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
end


get_withdrawal(
    gen:: OnceThroughGenerator,
    delta_t:: Float64,
    rho_w=1.0,
    c_p=0.004184,
) = begin
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


"""
Thermoelectric generator with reciruclating cooling system
"""
struct RecirculatingGenerator
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
