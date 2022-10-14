"""Visualization Functions"""

import matplotlib.pyplot as plt
import seaborn as sns
import pandas as pd
import datetime
import matplotlib.dates as mdates
sns.set()


def scenario_temperatures(multi_air_water):
    """Scenario temperatures plot

    Parameters
    ----------
    multi_air_water : dict
        Dictionary of dataframes with keys being scenario name and value being
         the dataframe

    Returns
    -------
    matplotlib.figure.Figure
        Plot of temperatures over time
    """
    df_ls = []
    for scenario_name, df_air_water in multi_air_water.items():
        df_air_water['scenario_name'] = scenario_name

        # Store
        df_ls.append(df_air_water)

    # Making parent dataframe
    df = pd.concat(df_ls)
    df = pd.melt(
        df,
        id_vars=['datetime', 'scenario_name'],
        var_name='temperature_type',
        value_name='temperature'
    )

    g = sns.FacetGrid(
        df,
        col="scenario_name",
        sharex=False,
        aspect=0.7,
        height=3.5,
        gridspec_kws={
            'wspace': 0.05
        }
    )
    g.map_dataframe(
        sns.lineplot,
        x='datetime',
        y='temperature',
        style='temperature_type',
        drawstyle='steps-post',
    )
    g.set_titles(col_template="{col_name}")
    g.add_legend()
    for ax in g.axes.flat:
        ax.tick_params(axis='x', rotation=90)
        ax.set_xlabel('')
    g.figure.subplots_adjust(bottom=0.3)

    return g


def temperatures(df_water, df_air):
    """Plot of first 7 days of July 2019

    Parameters
    ----------
    df_water : pandas.DataFrame
        Water temperature inputs
    df_air : pandas.DataFrame
        Air temperature inputs

    Returns
    -------
    matplotlib.figure.Figure
        Plot of temperature over time
    """
    # Parse dates
    df_exogenous = pd.merge(df_air, df_water)
    df_exogenous['datetime'] = pd.to_datetime(df_exogenous['datetime'])

    # Filter
    cond1 = (df_exogenous['datetime'] >= datetime.datetime(2019, 7, 1))
    cond2 = (df_exogenous['datetime'] <= datetime.datetime(2019, 7, 7))
    df_exogenous = df_exogenous[cond1 & cond2]

    fig, ax = plt.subplots()
    ax.plot(
        df_exogenous['datetime'],
        df_exogenous['air_temperature'],
        color=sns.color_palette()[0],
        drawstyle='steps-post'
    )
    ax.plot(
        df_exogenous['datetime'],
        df_exogenous['water_temperature'],
        color=sns.color_palette()[1],
        drawstyle='steps-post'
    )
    plt.xticks(rotation=45)
    plt.legend(['Air', 'Water'])
    plt.xticks(rotation=45)
    plt.ylabel(r'Average Temperature [$^\circ$C]')
    plt.tight_layout()

    return fig


def system_load(df_system_load):
    """Basic plot of system-level loading

    Parameters
    ----------
    df_system_load : pandas.DataFrame
        System loading

    Returns
    -------
    matplotlib.figure.Figure
        Plot of system loading
    """
    # Parse dates
    df_system_load['datetime'] = pd.to_datetime(df_system_load['datetime'])

    # Filter
    cond1 = (df_system_load['datetime'] >= datetime.datetime(2019, 7, 1))
    cond2 = (df_system_load['datetime'] <= datetime.datetime(2019, 7, 7))
    df_system_load = df_system_load[cond1 & cond2]

    # Plot
    fig, ax = plt.subplots()
    ax.plot(
        df_system_load['datetime'],
        df_system_load['load']
    )
    plt.xticks(rotation=90)
    plt.ylabel(r'Load [MW]')
    plt.tight_layout()

    return fig


def system_load_factor(df_system_load):
    """Basic plot of system-level loading

    Parameters
    ----------
    df_system_load : pandas.DataFrame
        System loading

    Returns
    -------
    matplotlib.figure.Figure
        Plot of system loading
    """
    # Parse dates
    df_system_load['datetime'] = pd.to_datetime(df_system_load['datetime'])

    # Filter
    cond1 = (df_system_load['datetime'] >= datetime.datetime(2019, 7, 1))
    cond2 = (df_system_load['datetime'] <= datetime.datetime(2019, 7, 7))
    df_system_load = df_system_load[cond1 & cond2]

    # Plot
    fig, ax = plt.subplots(figsize=(4, 5))
    ax.plot(
        df_system_load['datetime'],
        df_system_load['load_factor']
    )
    plt.xticks(rotation=90)
    plt.ylabel(r'$f_{sys}$')
    plt.tight_layout()

    return fig


def hour_node_load(df_hour_to_hour):
    """
    Hourly node-level load data

    Parameters
    ----------
    df_hour_to_hour : pandas.DataFrame
        Node-level hour-to-hour load factor data

    Returns
    -------
    matplotlib.figure.Figure
        Plot of node-level loading
    """
    # Setup
    date_cols = ['year', 'month', 'day', 'hour']
    df_hour_to_hour['year'] = 2020  # Fake year to make datetime
    df_hour_to_hour['datetime'] = pd.to_datetime(
        df_hour_to_hour[date_cols]
    )
    df_hour_to_hour = df_hour_to_hour.drop(columns=date_cols)

    # Filter
    cond1 = (df_hour_to_hour['datetime'] >= datetime.datetime(2020, 7, 1))
    cond2 = (df_hour_to_hour['datetime'] <= datetime.datetime(2020, 7, 7))
    df_hour_to_hour = df_hour_to_hour[cond1 & cond2]

    df_hour_to_hour = pd.melt(
        df_hour_to_hour,
        id_vars='datetime',
        var_name='bus',
        value_name='load_factor'
    )

    fig, ax = plt.subplots(figsize=(4, 5))
    palette = sns.color_palette(
        ['black'],
        len(df_hour_to_hour['bus'].unique())
    )
    sns.lineplot(
        data=df_hour_to_hour,
        x='datetime',
        y='load_factor',
        hue='bus',
        palette=palette,
        legend=False,
        lw=0.4,
        alpha=0.2,
        ax=ax
    )
    plt.xlabel('')
    plt.ylabel('$f_{var}$')
    plt.xticks(rotation=90)
    myFmt = mdates.DateFormatter('%m-%d')
    ax.xaxis.set_major_formatter(myFmt)
    plt.tight_layout()

    return fig


def node_load(df_node_load):
    """
    Hourly node-level load data

    Parameters
    ----------
    df_node_load : pandas.DataFrame
        Node-level data

    Returns
    -------
    matplotlib.figure.Figure
        Plot of node-level loading
    """
    # Parse dates
    df_node_load['datetime'] = pd.to_datetime(df_node_load['datetime'])

    # Filter
    cond1 = (df_node_load['datetime'] >= datetime.datetime(2019, 7, 1))
    cond2 = (df_node_load['datetime'] <= datetime.datetime(2019, 7, 7))
    df_node_load = df_node_load[cond1 & cond2]

    fig, ax = plt.subplots(figsize=(4, 5))
    palette = sns.color_palette(['black'], len(df_node_load['bus'].unique()))
    sns.lineplot(
        data=df_node_load,
        x='datetime',
        y='load_mw',
        hue='bus',
        palette=palette,
        legend=False,
        lw=0.4,
        alpha=0.2,
        ax=ax
    )
    plt.xlabel('')
    plt.ylabel('Power [MW]')
    plt.xticks(rotation=90)
    plt.tight_layout()

    return fig
