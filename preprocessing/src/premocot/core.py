"""Core functions"""


import os
import pandas as pd
import numpy as np
import dataretrieval.nwis as nwis


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


def process_water_exogenous():
    """
    Import and water air temperature

    # Potential sources
    USGS 05558300 ILLINOIS RIVER AT HENRY, IL
    USGS 05578300 CLINTON LAKE NEAR LANE, IL
    USGS 05578100 SALT CREEK NEAR FARMER CITY, IL
    USGS 05578250 NORTH FORK SALT CREEK NEAR DE WITT, IL

    Returns
    -------
    pandas.DataFrame
        Cleaned exogenous data
    """
    df_water = pd.DataFrame()

    # Water temperature
    site = '05578100'
    df_raw = nwis.get_record(
        sites=site,
        service='dv',
        start='2016-01-01',
        end='2022-01-01',
        parameterCd='00010'
    )

    # Cleanup
    df_water['datetime'] = df_raw.index.to_list()
    df_water['water_temperature'] = df_raw['00010_Mean'].to_list()

    return df_water


def process_air_exogenous(path_to_dir):
    """
    Import and process air temperature


    Returns
    -------
    pandas.DataFrame
        Cleaned exogenous data
    """
    df_air = pd.DataFrame()
    df_raw = pd.DataFrame()
    df_ls = []
    file_template = '857101_39.81_-89.66_0000.csv'
    years = [
        '2015',
        '2016',
        '2017',
        '2018',
        '2019',
        '2020'
    ]

    # Import raw data
    for year in years:
        file_name = file_template.replace('0000', year)
        path_to_file = os.path.join(path_to_dir, file_name)
        df_temp = pd.read_csv(
            path_to_file,
            header=2
        )
        df_ls.append(df_temp)
    df_raw = pd.concat(df_ls)

    # Datetime combine
    df_raw['datetime'] = pd.to_datetime(
        df_raw[['Year', 'Month', 'Day', 'Hour', 'Minute']]
    )

    # Daily average
    df_raw = df_raw.resample('d', on='datetime').mean()

    # Cleanup
    df_air['datetime'] = df_raw.index.to_list()
    df_air['air_temperature'] = df_raw['Temperature'].to_list()

    return df_air


def process_system_load(df_miso):
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
    # Get first entry for dates
    df_miso['datetime'] = pd.to_datetime(df_miso['DATE'])
    df_miso = df_miso.drop('DATE', axis=1)
    df_miso = df_miso.groupby('datetime').first().reset_index()

    # Fill in all hours
    df_system_load = pd.DataFrame()
    df_system_load['datetime'] = pd.date_range(
        df_miso.iloc[0]['datetime'],
        df_miso.iloc[-2]['datetime'],
        freq='H'
    )

    # Join dataframes to get every hour
    df_system_load = pd.merge(
        df_system_load,
        df_miso[['datetime', 'ActualLoad']],
        how='left'
    )

    # Linearly interpolate missing data
    df_system_load = df_system_load.set_index('datetime')
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

    return df_system_load


def process_node_load(df_system_load, df_synthetic_node_loads, net):
    """
    Create node-level loads

    Parameters
    ----------
    df_system_load : pandas.DataFrame
        System-level loads
    df_synthetic_node_loads : pandas.DataFrame
        Synthetic node loads
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
    n_loads = len(df_def_load)
    df_system_load['datetime'] = pd.to_datetime(df_system_load['datetime'])
    df_system_load['Month'] = df_system_load['datetime'].dt.month
    df_system_load['Day'] = df_system_load['datetime'].dt.day
    df_system_load['Hour'] = df_system_load['datetime'].dt.hour

    # Leap year correction
    df_synthetic_node_loads['datetime'] = pd.to_datetime(
        df_synthetic_node_loads['Date'] + ' ' + df_synthetic_node_loads['Time']
    )
    df_synthetic_node_loads['Month'] = \
        df_synthetic_node_loads['datetime'].dt.month
    df_synthetic_node_loads['Day'] = df_synthetic_node_loads['datetime'].dt.day
    df_synthetic_node_loads['Hour'] = \
        df_synthetic_node_loads['datetime'].dt.hour
    df_synthetic_node_loads = pd.merge(
        df_system_load[['Month', 'Day', 'Hour']],
        df_synthetic_node_loads
    )

    # Relative hour-to-hour variation
    bus_start_idx = 8
    bus_end_idx = bus_start_idx + n_loads
    df_temp = df_synthetic_node_loads.iloc[
        :-1, bus_start_idx: bus_end_idx
    ]
    df_temp_shift = df_synthetic_node_loads.iloc[
        1:, bus_start_idx: bus_end_idx
    ]
    df_temp.index = range(1, len(df_temp) + 1)
    df_hour_to_hour = df_temp/df_temp_shift

    # Drop generator information
    df_hour_to_hour = df_hour_to_hour.iloc[
        :, :len(df_def_load) + 1  # Skip date
    ]

    # Apply node-load model
    for i, row in df_system_load.iterrows():

        # Create temporary dataframe
        df_temp = pd.DataFrame(df_def_load['bus'])

        # Indexing information
        df_temp['datetime'] = row['datetime']

        # Average magnitude of loads
        df_temp['load_mw'] = df_def_load['p_mw']

        # Applying system load factor
        df_temp['load_mw'] = df_temp['load_mw'] * row['load_factor']

        # Applying hour-to-hour
        hour_to_hour_factors = df_hour_to_hour.iloc[i-1, :].values
        df_temp['load_mw'] = df_def_load['p_mw'] * hour_to_hour_factors

        # Store in df list
        df_load_ls.append(df_temp)

    # Concat
    df_node_load = pd.concat(df_load_ls, axis=0, ignore_index=True)

    # Add back in date to hour-to-hour for plotting
    df_hour_to_hour['datetime'] = df_synthetic_node_loads['datetime']

    return df_node_load, df_hour_to_hour
