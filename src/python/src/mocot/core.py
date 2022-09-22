"""Core functions"""


import os
import pandas as pd
import numpy as np
from more_itertools import consecutive_groups


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


def process_air_water_exogenous(paths):
    """Import and process air and water exogenous sources

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

    # Daily average
    df_exogenous = df_exogenous.resample('d', on='datetime').mean()
    df_exogenous = df_exogenous.reset_index()

    return df_exogenous


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
    df_hour_to_hour['datetime'] = df_node_load['datetime']

    return df_node_load, df_hour_to_hour


def archive_to_df(df, decision_names, objective_names):
    """Convert archive data to dataframes

    Parameters
    ----------
    df : pandas.DataFrame
        Raw runtime pandas dataframe
    decision_names : list
        Decision names
    objective_names : list
        Objective names

    Returns
    -------
    pandas.DataFrame
        Processed archive
    """
    # Extract Archive Prints
    df_temp = df[np.isnan(df['value'])]
    df_temp = df_temp[df_temp['var'] != '#']

    # Separate Based on Deliminators
    df_temp = df_temp['var'].str.split(' ', expand=True).astype(float)
    df_temp.columns = decision_names + objective_names

    # Convert Negative Objectives to Positive Ones (Important for Hypervolume) TODO: makes this more generic in future versions  # noqa
    df_temp[df_temp.columns[df_temp.dtypes != np.object]] = \
        df_temp[df_temp.columns[df_temp.dtypes != np.object]].abs()

    # Create Lists of Lists
    df_temp['Archive'] = df_temp.values.tolist()
    df_temp['Parameters'] = df_temp[decision_names].values.tolist()
    df_temp['Objectives'] = df_temp[objective_names].values.tolist()

    # Archive
    df_arc = df_temp['Archive']
    archive_ls = [
        df_arc.loc[i].tolist()
        for i in consecutive_groups(df_arc.index)
    ]
    df_arc = pd.DataFrame({'Archive': archive_ls})

    # Objectives
    df_obj = df_temp['Objectives']
    objectives_ls = [
        df_obj.loc[i].tolist()
        for i in consecutive_groups(df_obj.index)
    ]
    df_obj = pd.DataFrame({'Objectives': objectives_ls})

    # Parameters
    df_param = df_temp['Parameters']
    parameters_ls = [
        df_param.loc[i].tolist()
        for i in consecutive_groups(df_param.index)
    ]
    df_param = pd.DataFrame({'Parameters': parameters_ls})

    return df_arc, df_obj, df_param


def runtime_to_df(path, decision_names, objective_names):
    """
    Convert Borg MOEA runtime file to pandas DataFrame

    Parameters
    ----------
    path : str
        Path to Borg MOEA runtime file
    decision_names : list
        Decision names
    objective_names : list
        Objective names

    Returns
    -------
    pandas.DataFrame
        Parsed runtime file
    """
    # Convert to Dataframe
    df_raw = pd.read_table(path, names=['var', 'value'], sep="=")

    # Format Archive Prints to List of Lists
    df_arc, df_obj, df_param = archive_to_df(
        df_raw,
        decision_names,
        objective_names
    )

    # Omit Population Prints
    df_res = df_raw[-np.isnan(df_raw['value'])]

    # Replace //
    df_res = pd.DataFrame(
        [df_res['var'].str.replace('//', ''), df_res['value']]
    ).T

    # Add index
    df_res['NFE_index'] = \
        [i for i in np.arange(0, len(df_res) // 13) for j in range(13)]

    # Parse Data Into Columns
    df_res = pd.pivot(
        df_res,
        columns='var',
        values='value',
        index='NFE_index'
    ).reset_index(drop=True)

    # Convert to Float
    df_res = df_res.astype(float)

    # Merge DataFrames
    df_res = pd.concat([df_res, df_arc, df_obj, df_param], axis=1)

    # Population to archive ratio
    df_res['PopulationToArchiveRatio'] = \
        df_res['PopulationSize'] / df_res['ArchiveSize']

    return df_res
