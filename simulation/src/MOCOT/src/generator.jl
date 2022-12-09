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
