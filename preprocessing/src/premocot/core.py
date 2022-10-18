"""Core functions"""


import os
import pandas as pd
import numpy as np
import dataretrieval.nwis as nwis
import warnings
import datetime


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
    # Import all dataframes
    print('Importing EIA water data from {}'.format(path_to_eia))

    # Import Dataframe
    df = pd.read_excel(path_to_eia, header=2)

    # Replace space values with nan values
    df = df.replace(r'^\s*$', np.nan, regex=True)

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
    timestamps = pd.to_datetime(df_raw.index).tz_localize(None).to_list()
    df_water['datetime'] = timestamps
    df_water['water_temperature'] = df_raw['00010_Mean'].to_list()

    # Missing values
    df_water = fill_datetime(df_water, 'D')

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

    # Missing values
    df_air = fill_datetime(df_air, 'D')

    return df_air


def process_system_load(eia_load_template_j_j, eia_load_template_j_d):
    """
    Clean system-level miso data includes interpolating missing values

    Parameters
    ----------
    eia_load_template_j_j : str
        Path to EIA load data for January to June
    eia_load_template_j_d : str
        Path to EIA load data for July to December

    Returns
    -------
    pandas.DataFrame
        Parsed data
    """
    df_system_load = pd.DataFrame()
    df_ls = []
    years = [
        '2016',
        '2017',
        '2018',
        '2019',
        '2020',
        '2021'
    ]

    # Import
    cols = [
        'Balancing Authority',
        'Data Date',
        'Hour Number',
        'Demand (MW)'
    ]
    for year in years:
        # January to June
        url_1 = eia_load_template_j_j.replace('0000', year)
        df_temp = pd.read_csv(url_1, usecols=cols, thousands=',')
        df_temp = df_temp[df_temp['Balancing Authority'] == 'MISO']
        df_ls.append(df_temp)

        # July to December
        url_2 = eia_load_template_j_d.replace('0000', year)
        df_temp = pd.read_csv(url_2, usecols=cols, thousands=',')
        df_temp = df_temp[df_temp['Balancing Authority'] == 'MISO']
        df_ls.append(df_temp)

        print('success: Imported load for year {}'.format(year))

    df_raw = pd.concat(df_ls)
    df_raw['datetime'] = \
        pd.to_datetime(df_raw['Data Date']) +\
        pd.to_timedelta(df_raw['Hour Number'], unit='hour')

    # Cleanup
    df_system_load['datetime'] = df_raw['datetime'].to_list()
    df_system_load['load'] = df_raw['Demand (MW)'].to_list()

    # Add load factors
    avg_load = df_system_load['load'].mean()
    df_system_load['load_factor'] = df_system_load['load']/avg_load

    # Nan missing values
    df_system_load = fill_datetime(df_system_load, 'H')

    return df_system_load


def fill_datetime(df, freq):
    """
    Fill missing datetime values

    Parameters
    ----------
    df : pandas.DataFrame
        DataFrame to fill
    freq : str
        Frequency to fill

    Returns
    -------
    pandas.DataFrame
        Filled DataFrame
    """
    # Fill in all hours
    df_datetime_fill = pd.DataFrame({
        'datetime': pd.date_range(
            df.iloc[0]['datetime'],
            df.iloc[-1]['datetime'],
            freq=freq
        )
    })

    # Join dataframes to fill
    df = pd.merge(
        df_datetime_fill,
        df,
        how='left'
    )

    return df


def process_hour_to_hour(df_synthetic_node_loads, net):
    """
    Processing hour-to-hour node load factors

    Parameters
    ----------
    df_synthetic_node_loads : pandas.DataFrame
        Synthetic node loads
    net : pandapower.network
        Network

    Returns
    -------
    pandas.DataFrame
        Hour-to-hour variations
    """
    n_loads = len(net.load)

    # Type parsing
    df_synthetic_node_loads['datetime'] = pd.to_datetime(
        df_synthetic_node_loads['Date'] + ' ' + df_synthetic_node_loads['Time']
    )
    df_synthetic_node_loads['month'] = \
        df_synthetic_node_loads['datetime'].dt.month
    df_synthetic_node_loads['day'] = df_synthetic_node_loads['datetime'].dt.day
    df_synthetic_node_loads['hour'] = \
        df_synthetic_node_loads['datetime'].dt.hour

    # Relative hour-to-hour variation
    bus_start_idx = 5
    bus_end_idx = bus_start_idx + n_loads
    df_temp = df_synthetic_node_loads.iloc[
        :-1, bus_start_idx: bus_end_idx
    ]
    df_temp_shift = df_synthetic_node_loads.iloc[
        1:, bus_start_idx: bus_end_idx
    ]
    df_temp.index = range(1, len(df_temp) + 1)
    df_hour_to_hour = df_temp_shift/df_temp

    # Add month and day
    df_hour_to_hour['month'] = df_synthetic_node_loads['month']
    df_hour_to_hour['day'] = df_synthetic_node_loads['day']
    df_hour_to_hour['hour'] = df_synthetic_node_loads['hour']

    return df_hour_to_hour


def process_wind_capacity_factors(path_to_dir):
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

    # Get wind capacity factors
    wind_mean = df_raw['Wind Speed'].mean()
    df_raw['Wind Capacity Factor'] = df_raw['Wind Speed'] / wind_mean

    # Cleanup
    df_air['datetime'] = df_raw['datetime'] - datetime.timedelta(minutes=30)
    df_air['wind_capacity_factor'] = df_raw['Wind Capacity Factor'].to_list()

    return df_air


def scenario_dates(df_water, df_air, df_system_load, df_hour_to_hour):
    """
    Get dates of scenarios based on statistics

    Parameters
    ----------
    df_water : pandas.DataFrame
        Water exogenous dataframe
    df_air : pandas.DataFrame
        Air exogenous dataframe
    df_system_load : pandas.DataFrame
        System load exogenous dataframe
    df_hour_to_hour : pandas.DataFrame
        Hour-to-hour exogenous dataframe

    Returns
    -------
    int
        Success status
    """

    df_water.index = df_water['datetime']
    df_air.index = df_air['datetime']
    df_system_load.index = df_system_load['datetime']

    # Average week
    df_rolling = df_system_load['load'].rolling(7).mean()
    avg_load = df_rolling.mean()
    avg_week = abs(df_rolling - avg_load).idxmin()
    print('Avg week: {}'.format(avg_week))

    # High 7-day load
    print('high load: {}'.format(df_rolling.idxmax()))

    # High water temperature
    df_rolling = df_water['water_temperature'].rolling(7).mean()
    print('high water temperature: {}'.format(df_rolling.idxmax()))

    # High air temperature
    df_rolling = df_air['air_temperature'].rolling(7).mean()
    print('high air temperature: {}'.format(df_rolling.idxmax()))

    # High 7-day standard deviation
    df_rolling = df_hour_to_hour.iloc[:, :-3]
    df_rolling = df_rolling.rolling(7).std()
    idx = df_rolling.iloc[:].sum(axis=1).idxmax()
    print('high standard devaiation of load: Month {}, Day {}'.format(
        df_hour_to_hour['month'][idx],
        df_hour_to_hour['day'][idx],
        )
    )

    return 0


def create_scenario_exogenous(
    scenario_code,
    datetime_start,
    datetime_end,
    hour_to_hour_start,
    df_water,
    df_air,
    df_wind_cf,
    df_system_load,
    df_hour_to_hour,
    net
):
    """
    Create exogenous parameters for a given scenario

    Parameters
    ----------
    scenario_code : int
        Scenario code
    datetime_start : datetime.datetime
        Start of scenario
    datetime_end : datetime.datetime
        End of scenario
    hour_to_hour_start : datetime.datetime
        Start of hour to hour variation information
    df_water : pandas.DataFrame
        Water temperature
    df_air : pandas.DataFrame
        Air temperature
    df_wind_cf : pandas.DataFrame
        Wind capacity factors
    df_system_load : pandas.DataFrame
        System load variablity
    df_hour_to_hour : pandas.DataFrame
        Hour-to-hour node variability
    net : pandapower.network
        Network

    Returns
    -------
    tuple
        Tuple of air/water temperature dataframe and node load dataframe
    """
    df_air_water = pd.DataFrame()
    df_node_load = pd.DataFrame()
    df_load_ls = []
    df_def_load = net.load[['bus', 'p_mw']]
    df_system_load['datetime'] = pd.to_datetime(df_system_load['datetime'])

    # Filter air water
    df_air_water = pd.merge(
        df_air,
        df_water
    )
    df_air_water['datetime'] = pd.to_datetime(df_air_water['datetime'])
    condition = \
        (df_air_water['datetime'] >= datetime_start) & \
        (df_air_water['datetime'] <= datetime_end)
    df_air_water = df_air_water[condition]

    # Wind capacity
    df_wind_cf['datetime'] = pd.to_datetime(df_wind_cf['datetime'])
    condition = \
        (df_wind_cf['datetime'] >= datetime_start) & \
        (df_wind_cf['datetime'] <= datetime_end)
    df_wind_cf = df_wind_cf[condition]

    # Node load
    condition = \
        (df_system_load['datetime'] >= datetime_start) & \
        (df_system_load['datetime'] <= datetime_end)
    df_system_load = df_system_load[condition]
    df_system_load = df_system_load.reset_index(drop=True)
    for i, row in df_system_load.iterrows():
        # Create temporary dataframe
        df_temp = pd.DataFrame(df_def_load['bus'])

        # Indexing information
        df_temp['datetime'] = row['datetime']

        # Average magnitude of loads
        df_temp['load_mw'] = df_def_load['p_mw']

        # Applying system load factor
        df_temp['load_mw'] = df_temp['load_mw'] * row['load_factor']

        # Applying hour-to-hour (time doesn't have to be same as scenario)
        time_delta = datetime.timedelta(hours=i)
        month = (hour_to_hour_start + time_delta).month
        day = (hour_to_hour_start + time_delta).day
        hour = (hour_to_hour_start + time_delta).hour
        condition = \
            (df_hour_to_hour['month'] == month) & \
            (df_hour_to_hour['day'] == day) & \
            (df_hour_to_hour['hour'] == hour)
        date_col_idx = -3
        hour_to_hour_factors = \
            df_hour_to_hour[condition].values[0][:date_col_idx]
        df_temp['load_mw'] = df_temp['load_mw'] * hour_to_hour_factors

        # Store in df list
        df_load_ls.append(df_temp)

    # Concat
    df_node_load = pd.concat(df_load_ls, axis=0, ignore_index=True)

    # Feedback
    print('Lenth of air/water dataframe {}'.format(len(df_air_water)))
    if df_air_water.isna().any().any():
        warnings.warn(
            'Null value encountered in air/water scenario {}'.format(
                scenario_code
            )
        )
    print('Lenth of wind cf dataframe {}'.format(len(df_wind_cf)))
    if df_wind_cf.isna().any().any():
        warnings.warn(
            'Null value encountered in node load scenario {}'.format(
                scenario_code
            )
        )
    print('Lenth of node load dataframe {}'.format(len(df_node_load)))
    if df_node_load.isna().any().any():
        warnings.warn(
            'Null value encountered in node load scenario {}'.format(
                scenario_code
            )
        )

    return df_air_water, df_wind_cf, df_node_load
