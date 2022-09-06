"""Core functions"""


import os
from typing import Dict
import pandas as pd
import numpy as np
import itertools


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


def process_exogenous(paths):
    """Import and process exogenous sources

    Parameters
    ----------
    paths : configparser.ConfigParser
        IO paths

    Returns
    -------
    pandas.DataFrame
        Cleaned exogenous data
    """
    # Water temperature
    df_water_temperature = pd.read_table(
        paths['inputs']['usgs_temperature_data'],
        skiprows=[i for i in range(0, 29)] + [30],
        low_memory=False,
        parse_dates=[2]
    )
    condition = \
        (df_water_temperature['datetime'] > '2019') & \
        (df_water_temperature['datetime'] < '2020')
    df_water_temperature = df_water_temperature[condition]
    df_water_temperature['water_temperature'] = df_water_temperature.iloc[:, 4]

    headers = [
        line.split() for i,
        line in enumerate(open(paths['inputs']['noaa_temperature_headers']))
        if i == 1
    ]
    df_air_temperature = pd.read_table(
        paths['inputs']['noaa_temperature_data'],
        delim_whitespace=True,
        names=headers[0],
        parse_dates={'datetime': [1, 2]}
    )
    condition = \
        (df_air_temperature['datetime'] > '2019') & \
        (df_air_temperature['datetime'] < '2020')
    df_air_temperature = df_air_temperature[condition]
    df_air_temperature['air_temperature'] = df_air_temperature['T_HR_AVG']

    # Joining
    df_exogenous = pd.merge(
        df_air_temperature[['datetime', 'air_temperature']],
        df_water_temperature[['datetime', 'water_temperature']],
        how='left',
        on='datetime'
    )

    # Subset data
    start = '2019-07-01'
    end = '2019-07-08'
    selection = \
        (df_exogenous['datetime'] > start) & (df_exogenous['datetime'] < end)
    df_exogenous = df_exogenous[selection]

    # Daily average
    df_exogenous = df_exogenous.resample('d', on='datetime').mean()
    df_exogenous = df_exogenous.reset_index()

    # Index
    df_exogenous['day_index'] = (
        df_exogenous['datetime'] - df_exogenous['datetime'][0]
    ).dt.days + 1

    return df_exogenous


def clean_system_load(df_miso):
    """
    Clean system-level miso data includes interpolating missing values

    Parameters
    ----------
    df_miso : pandas.DataFrame
        MISO loads

    Returns
    -------
    pandas.DataFrame
        Parsed data
    """
    # Parse types
    df_system_load = df_miso.copy()
    df_system_load['DATE'] = pd.to_datetime(df_system_load['DATE'])

    # Selection
    start = '2019-07-01'
    end = '2019-07-08'
    selection = \
        (df_system_load['DATE'] >= start) & (df_system_load['DATE'] < end)
    df_system_load = df_system_load[selection]

    # Linearly interpolate missing data
    df_system_load = df_system_load.set_index('DATE')
    df_ff = df_system_load.fillna(method='ffill')
    df_bf = df_system_load.fillna(method='bfill')
    df_system_load = df_system_load.where(
        df_system_load.notnull(),
        other=(df_ff + df_bf)/2
    )
    df_system_load = df_system_load.reset_index()

    # Add load factors
    avg_load = df_miso['ActualLoad'].mean()
    df_system_load['load_factor'] = df_system_load['ActualLoad']/avg_load

    # Index
    df_system_load['hour_index'] = df_system_load['DATE'].dt.hour + 1.0
    df_system_load['day_index'] = (
        df_system_load['DATE'] - df_system_load['DATE'][0]
    ).dt.days + 1

    return df_system_load


def create_node_load(df_system_load, df_synthetic_node_loads, df_miso, net):
    """
    Create node-level loads

    Parameters
    ----------
    df_system_load : pandas.DataFrame
        System-level loads
    df_synthetic_node_loads : pandas.DataFrame
        Synthetic node loads
    df_miso : pandas.DataFrame
        Miso loads (for datetime)
    net : pandapower.network
        Network

    Returns
    -------
    pandas.DataFrame
        Node loads
    """
    # Initialization
    df_load_ls = []
    df_def_load = net.load[['bus', 'p_mw']]
    df_system_load['DATE'] = pd.to_datetime(df_system_load['DATE'])
    df_miso['DATE'] = pd.to_datetime(df_miso['DATE'])

    # Relative hour-to-hour variation
    df_temp = df_synthetic_node_loads.iloc[0:-1, 5:-1]
    df_temp_shift = df_synthetic_node_loads.iloc[1:, 5:-1]
    df_temp.index = range(1, len(df_temp) + 1)
    df_hour_to_hour = df_temp/df_temp_shift

    # Filter by dates
    df_hour_to_hour.insert(0, 'DATE', df_miso['DATE'])
    start = '2019-07-01'
    end = '2019-07-08'
    selection = \
        (df_hour_to_hour['DATE'] >= start) & (df_hour_to_hour['DATE'] < end)
    df_hour_to_hour = df_hour_to_hour[selection]

    # Drop generators
    df_hour_to_hour = df_hour_to_hour.iloc[
        :, :len(df_def_load) + 1  # Skip date
    ]

    # Apply node-load model
    for i, row in df_system_load.iterrows():

        # Create temporary dataframe
        df_temp = pd.DataFrame(df_def_load['bus'])

        # Indexing information
        df_temp['datetime'] = row['DATE']
        df_temp['day_index'] = row['day_index']
        df_temp['hour_index'] = row['hour_index']

        # Average magnitude of loads
        df_temp['load_mw'] = df_def_load['p_mw']

        # Applying system load factor
        df_temp['load_mw'] = df_temp['load_mw'] * row['load_factor']

        # Applying hour-to-hour
        hour_to_hour_factors = df_hour_to_hour.iloc[i, 1:].values  # Skip date
        df_temp['load_mw'] = df_def_load['p_mw'] * hour_to_hour_factors

        # Store in df list
        df_load_ls.append(df_temp)

    # Concat
    df_node_load = pd.concat(df_load_ls, axis=0, ignore_index=True)

    return df_node_load, df_hour_to_hour


def grid_sample(grid_specs: Dict):
    """
    Pandas-based grid sampling function
    Parameters
    ----------
    gridspecs: Dict
        Grid specifications, must have the form of
        {
            'var_1': {'min': float, 'max': float, 'steps': int},
            'var_2': {'min': float, 'max': float, 'steps': int},
        }
        These reflect the variable names, minimum value of grid sampling,
        maximum value of grid sampling, and number of steps respectively.

    Returns
    -------
    df_grid: DataFrame
        Dataframe of grid sampling. Will have columns of names specified in
        'var' list
    """
    # Get linear spaces
    linspace_list = []
    var_names = []
    for var_name, var_specs in grid_specs.items():
        linspace_list.append(
            np.linspace(
                var_specs['min'],
                var_specs['max'],
                int(var_specs['steps'])
            )
        )
        var_names.append(var_name)

    # Create dataframe
    df_grid = pd.DataFrame(
        list(itertools.product(*linspace_list)),
        columns=var_names
    )

    return df_grid
