"""Core functions"""


import sympy.physics.units as u


def once_through_withdrawal(
    eta_net: float,
    k_os: float,
    delta_t: float,
    beta_proc: float,
    rho_w=1.0,
    c_p=0.04184,
):
    """Once through withdrawal model

    Parameters
    ----------
    eta_net : float
        Ratio of electricity generation rate to thermal input
    k_os : float
        Thermal input lost to non-cooling system sinks
    delta_t : float
        Inlet/outlet water temperature difference in C
    beta_proc : float
        Non-cooling rate in L/MWh
    rho_w : float, optional
        Desnity of Water kg/L, by default 1.0
    c_p : float, optional
        Specific head of water in MJ/(kg-K), by default 0.04184

    Returns
    -------
    _type_
        _description_
    """
    # Setting units
    rho_w = rho_w * u.kg/u.L
    c_p = c_p * u.J/(u.kg * u.K)  # Mega
    delta_t = delta_t * u.K
    beta_proc = beta_proc * u.L/(u.W*u.h)  # 1/Mega

    # Model
    efficiency = 3600 * u.s/u.h * (1-eta_net-k_os) / eta_net
    physics = 1 / (rho_w*c_p*delta_t)
    beta_with = efficiency * physics + beta_proc

    # Unit conversion
    beta_with = u.convert_to(beta_with, u.L/(u.W*u.h))
    beta_with = beta_with.as_coeff_Mul()[0]

    return beta_with


def grid_setup(net, df_gen_info):
    """Basic setup of PandaPower grid to incorporate dataframe of information

    Parameters
    ----------
    net : pandapowerNet
        Pandapower network to add information
    df_gen_info : DataFrame
        DataFrame of only the pandapower generators

    Returns
    -------
    pandapowerNet
        Pandapower network with added information
    """
    # Initialize local vars
    gen_types = ['gen', 'sgen', 'ext_grid']

    # Add pandapower index
    for gen_type in gen_types:
        getattr(net, gen_type)['MATPOWER Index'] = getattr(net, gen_type)['bus'] + 1

    # Add generator information
    net = add_gen_info_to_network(df_gen_info, net)

    return net


def add_gen_info_to_network(df_gen_info, net):
    """Add the information in `df_gen_info` to `net`

    Parameters
    ----------
    df_gen_info : DataFrame
        DataFrame of only the pandapower generators
    net : pandapowerNet
        Pandapower network to add information

    Returns
    -------
    pandapowerNet
        Pandapower network with added information
    """
    # Initialize local vars
    gen_types = ['gen', 'sgen', 'ext_grid']

    # Add information
    for gen_type in gen_types:
        setattr(net, gen_type, getattr(net, gen_type).merge(df_gen_info))

    return net
