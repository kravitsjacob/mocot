"""Core functions"""


import sympy.physics.units as u
import os
import pandas as pd
import numpy as np


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
        getattr(net, gen_type)['MATPOWER Index'] = \
            getattr(net, gen_type)['bus'] + 1

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


def generator_match(net, df_gen_matches):
    """Match synthetic generators to EIA generators with anonymous power plant
     names

    Parameters
    ----------
    net : pandapowerNet
        Pandapower network to add information
    df_gen_matches : DataFrame
        Manually created dataframe of matched generator

    Returns
    -------
    pandapowerNet
        Pandapower network with added information
    """
    # Anonymous plant names
    powerworld_plants = df_gen_matches['POWERWORLD Plant Name'].unique()
    anonymous_plants = \
        [f'Plant {i}' for i in range(1, len(powerworld_plants) + 1)]
    d = dict(zip(powerworld_plants, anonymous_plants))
    df_gen_matches['Plant Name'] = \
        df_gen_matches['POWERWORLD Plant Name'].map(d)

    # Add generator information
    net = add_gen_info_to_network(df_gen_matches, net)

    return net


def import_eia(path_to_eia):
    """Import and aggregate EIA thermoelectric data

    Parameters
    ----------
    path_to_eia : str
        Path to EIA data

    Returns
    -------
    DataFrame
        DataFrame of EIA data
    """
    # Local Vars
    years = ['2019', '2018', '2017', '2016', '2015', '2014']
    df_list = []

    # Import all dataframes
    for i in years:
        path = os.path.join(path_to_eia, 'cooling_detail_' + i + '.xlsx')
        print(i)

        # Import Dataframe
        df_temp = pd.read_excel(path, header=2)

        # Replace space values with nan values
        df_temp = df_temp.replace(r'^\s*$', np.nan, regex=True)
        df_list.append(df_temp)

    # Concat Dataframes into Single Dataframe
    df = pd.concat(df_list)
    return df


def get_cooling_system(df_eia, df_gen_info):
    """Get cooling system information of synthetic generators

    Parameters
    ----------
    df_eia : DataFrame
        DataFrame of EIA data from `import_eia`
    df_gen_info : DataFrame
        DataFrame of only the pandapower generators

    Returns
    -------
    DataFrame
        DataFrame of only the pandapower generators with cooling system
         information
    """
    # Matches from manual analysis of EIA dataset
    df_eia = df_eia.drop_duplicates(subset='Plant Name', keep='first')
    df_gen_info['923 Cooling Type'] = df_gen_info.merge(
        df_eia,
        right_on='Plant Name',
        left_on='EIA Plant Name',
        how='left'
    )['923 Cooling Type']
    # Wind is assumed to not use water
    df_gen_info.loc[
        df_gen_info['MATPOWER Fuel'] == 'wind', '923 Cooling Type'
        ] = 'No Cooling System'
    # Assume Small Capacity Natural Gas Turbines Don't Have Cooling System
    df_gen_info.loc[
        (df_gen_info['MATPOWER Type'] == 'GT') &
        (df_gen_info['MATPOWER Fuel'] == 'ng') &
        (df_gen_info['MATPOWER Capacity (MW)'] < 30),
        '923 Cooling Type'
    ] = 'No Cooling System'
    # One off matching based on searching
    df_gen_info.loc[
        df_gen_info['EIA Plant Name'] == 'Interstate', '923 Cooling Type'
    ] = 'RI'  # Based on regional data availability
    df_gen_info.loc[
        df_gen_info['EIA Plant Name'] == 'Gibson City Energy Center LLC',
        '923 Cooling Type'
    ] = 'RI'  # Based on regional data availability
    df_gen_info.loc[
        df_gen_info['EIA Plant Name'] == 'Rantoul', '923 Cooling Type'
    ] = 'OC'
    df_gen_info.loc[
        df_gen_info['EIA Plant Name'] == 'Tuscola Station', '923 Cooling Type'
    ] = 'OC'
    df_gen_info.loc[
        df_gen_info['EIA Plant Name'] == 'E D Edwards', '923 Cooling Type'
    ] = 'OC'

    return df_gen_info


def network_to_gen_info(net):
    """Convert pandapower network to generator information DataFrame.

    Parameters
    ----------
    net : pandapowerNet
        Pandapower network to convert

    Returns
    -------
    DataFrame
        DataFrame of only the pandapower generators
    """
    # Initialize local vars
    gen_types = ['gen', 'sgen', 'ext_grid']
    df_gen_info = pd.DataFrame()

    # Convert generator information dataframe
    for gen_type in gen_types:
        df_gen_info = pd.concat([df_gen_info, getattr(net, gen_type)])

    df_gen_info = df_gen_info.reset_index(drop=True)  # Eliminate duplicated

    return df_gen_info


def get_regional(df):
    """Get regional thermoelectric data

    Parameters
    ----------
    df : DataFrame
        DataFrame of EIA data from `import_eia`

    Returns
    -------
    DataFrame
        Filtered DataFrame with only the regional data from the input DataFrame
    """
    # Convert units
    df['Withdrawal Rate (Gallon/kWh)'] = \
        df['Water Withdrawal Volume (Million Gallons)'].astype('float64') / \
        df['Gross Generation from Steam Turbines (MWh)'].astype('float64')*1000
    df['Consumption Rate (Gallon/kWh)'] = \
        df['Water Consumption Volume (Million Gallons)'].astype('float64') /\
        df['Gross Generation from Steam Turbines (MWh)'].astype('float64')*1000

    # Substitute simple fuel types
    df['Fuel Type'] = df['Generator Primary Technology'].replace(
        {'Nuclear': 'nuclear',
         'Natural Gas Steam Turbine': 'ng',
         'Conventional Steam Coal': 'coal',
         'Natural Gas Fired Combined Cycle': 'ng',
         'Petroleum Liquids': np.nan})
    df = df[df['Fuel Type'].notna()]

    # Filter to only Illinois plants
    df = df[df['State'].isin(['IL'])]

    # Filter to only cooling systems in synthetic region (Hardcoded)
    df = df[
        ((df['Fuel Type'] == 'coal') & (df['923 Cooling Type'] == 'RI')) |
        ((df['Fuel Type'] == 'coal') & (df['923 Cooling Type'] == 'RC')) |
        ((df['Fuel Type'] == 'coal') & (df['923 Cooling Type'] == 'OC')) |
        ((df['Fuel Type'] == 'nuclear') & (df['923 Cooling Type'] == 'RC')) |
        ((df['Fuel Type'] == 'ng') & (df['923 Cooling Type'] == 'RI'))
    ]

    # Filter based on real values
    df = df[df['Withdrawal Rate (Gallon/kWh)'].notna()]
    df = df[np.isfinite(df['Withdrawal Rate (Gallon/kWh)'])]
    df = df[df['Consumption Rate (Gallon/kWh)'].notna()]
    df = df[np.isfinite(df['Consumption Rate (Gallon/kWh)'])]

    # Filter based on values that aren't zero
    df = df[df['Withdrawal Rate (Gallon/kWh)'] != 0.0]
    df = df[df['Consumption Rate (Gallon/kWh)'] != 0.0]

    # Filter generators that reported less than 50% of the observations
    df.set_index(
        ['Plant Name', 'Generator ID', 'Boiler ID', 'Cooling ID'],
        inplace=True
    )
    df['Observations'] = 1
    df_sum = df.groupby(
        ['Plant Name', 'Generator ID', 'Boiler ID', 'Cooling ID']
    ).sum()
    df = df.loc[df_sum[df_sum['Observations'] > 36].index]
    df = df.reset_index()

    # Iglewicz B and Hoaglin D (1993) Page 11 Modified Z-Score Filtering
    df_median = df.groupby(
        ['Plant Name', 'Generator ID', 'Boiler ID', 'Cooling ID']
    ).median()
    df = df.reset_index()
    df[
        [
            'Withdrawal Rate (Gallon/kWh) Median',
            'Consumption Rate (Gallon/kWh) Median'
        ]
    ] = df.join(
        df_median,
        on=['Plant Name', 'Generator ID', 'Boiler ID', 'Cooling ID'],
        rsuffix=' Median'
    )[
        [
            'Withdrawal Rate (Gallon/kWh) Median',
            'Consumption Rate (Gallon/kWh) Median'
        ]
    ]
    df['Withdrawal Rate (Gallon/kWh) Absolute Difference'] = (df['Withdrawal Rate (Gallon/kWh)'] - df['Withdrawal Rate (Gallon/kWh) Median']).abs()  # noqa More readable on one line
    df['Consumption Rate (Gallon/kWh) Absolute Difference'] = (df['Consumption Rate (Gallon/kWh)'] - df['Consumption Rate (Gallon/kWh) Median']).abs()  # noqa More readable on one line
    df_mad = df.groupby(
        ['Plant Name', 'Generator ID', 'Boiler ID', 'Cooling ID']
    ).median()
    df = df.reset_index()
    df[[
        'Withdrawal Rate (Gallon/kWh) MAD',
        'Consumption Rate (Gallon/kWh) MAD'
    ]] = df.join(
        df_mad,
        on=['Plant Name', 'Generator ID', 'Boiler ID', 'Cooling ID'],
        rsuffix=' MAD'
    )[[
        'Withdrawal Rate (Gallon/kWh) Absolute Difference MAD',
        'Consumption Rate (Gallon/kWh) Absolute Difference MAD'
    ]]
    df['Withdrawal Rate (Gallon/kWh) Modified Z Score'] = (0.6745 * (df['Withdrawal Rate (Gallon/kWh)'] - df['Withdrawal Rate (Gallon/kWh) Median'])/df['Withdrawal Rate (Gallon/kWh) MAD']).abs()  # noqa More readable on one line
    df['Consumption Rate (Gallon/kWh) Modified Z Score'] = (0.6745 * (df['Consumption Rate (Gallon/kWh)'] - df['Consumption Rate (Gallon/kWh) Median'])/df['Consumption Rate (Gallon/kWh) MAD']).abs()  # noqa More readable on one line
    df = df[
        (df['Consumption Rate (Gallon/kWh) Modified Z Score'] < 3.5) &
        (df['Withdrawal Rate (Gallon/kWh) Modified Z Score'] < 3.5)
    ]

    return df


def water_use_sensitivies(df_gen_info_water):
    # Unique fuel/cooling combinations
    df_fuel_cool = df_gen_info_water.groupby(
        ['MATPOWER Fuel', '923 Cooling Type']
    ).size().reset_index()

    for i, row in df_fuel_cool.iterrows():
        fuel = row['MATPOWER Fuel']
        cool = row['923 Cooling Type']
        if cool != 'No Cooling System':
            k_os = get_k_os(fuel)
            a = 1

    return 0


def get_k_os(fuel: str):
    """Get other sinks fraction from DOE-NETL reference models

    Parameters
    ----------
    fuel : str
        fuel code
    """
    if fuel == 'coal':
        k_os = 0.12
    elif fuel == 'ng':
        k_os = 0.20
    elif fuel == 'nuclear':
        k_os = 0

    return k_os
