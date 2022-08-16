"""Core functions"""


import os
import pandas as pd
import numpy as np


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
        (df_system_load['DATE'] > start) & (df_system_load['DATE'] < end)
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

    return df_system_load


def create_node_load(df_system_load, df_miso, net):

    # Initialization
    np.random.seed(1008)
    df_load_ls = []
    df_def_load = net.load[['bus', 'p_mw']]
    df_system_load['DATE'] = pd.to_datetime(df_system_load['DATE'])

    # To load factors
    median_load = df_miso['ActualLoad'].median()
    df_system_load['load_factor'] = df_system_load['ActualLoad']/median_load

    # For date in df_system_load
    for _, row in df_system_load.iterrows():
        # Create temporary dataframe
        df_temp = pd.DataFrame(df_def_load['bus'])
        df_temp['load_mw'] = df_def_load['p_mw'] * row['load_factor']
        df_temp['datetime'] = row['DATE']

        # Store in df list
        df_load_ls.append(df_temp)

    # Concat
    df_node_load = pd.concat(df_load_ls, axis=0, ignore_index=True)

    # Add some randomness by multiplying by normal distribution
    df_node_load['load_mw'] = df_node_load['load_mw'].apply(
        lambda x: x * np.random.uniform(low=0.9, high=1.1)
    )

    # Index
    df_node_load['hour_index'] = df_node_load['datetime'].dt.hour
    df_node_load['day_index'] = (
        df_node_load['datetime'] - df_node_load['datetime'][0]
    ).dt.days

    return df_node_load
