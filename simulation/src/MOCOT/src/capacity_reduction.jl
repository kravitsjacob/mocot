"""Capacity reduction models"""


function once_through_capacity(;
    KW:: Float64,
    delta_T:: Float64,
    Q:: Float64,
    eta_total:: Float64,
    eta_elec:: Float64,
    alpha=0.01,
    lambda=1.0,
    gamma=0.02,
    rho_w=997.77,
    c_p=0.004184,
)
    """
    Once through capacity reduction model

    # Arguments
    - `KW:: Float64`: Capacity [MW]
    - `delta_T:: Float64`: Inlet outlet temperature difference [C]
    - `Q:: Float64`: Streamflow [cms]
    - `eta_total:: Float64`: Total efficiency
    - `eta_elec:: Float64`: Electric efficiency
    - `alpha=0.01`: Share of waste heat not discharged by cooling water
    - `lambda=1.0`: Correction factor accounting for the effects of reductions in efficiencies when power plants are operating at low capacities.
    - `gamma=0.02`: Maximum fraction of streamflow to be withdrawn for cooling of thermoelectric power.
    - `rho_w=997.77`: Water density [kg/cm]
    - `c_p=0.004184`: Heat capacity of water [MJ/kg-C]
    """
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
    
    return p_thermo_OC
end