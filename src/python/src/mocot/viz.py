"""Visualization Functions"""

import matplotlib.pyplot as plt
import matplotlib
import seaborn as sns
import pandas as pd
sns.set()


def temperatures(df_exogenous):
    """Plot of first 7 days of July 2019

    Parameters
    ----------
    df_exogenous : pandas.DataFrame
        Pandas exogenous inputs

    Returns
    -------
    matplotlib.figure.Figure
        Plot of temperature over time
    """
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
    df_system_load['DATE'] = pd.to_datetime(df_system_load['DATE'])

    # Plot
    fig, ax = plt.subplots()
    ax.plot(
        df_system_load['DATE'],
        df_system_load['ActualLoad']
    )
    plt.xticks(rotation=45)
    plt.xticks(rotation=45)
    plt.ylabel(r'Load [MW]')
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

    fig, ax = plt.subplots()
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
    plt.xticks(rotation=45)
    plt.tight_layout()

    return fig


def gen_timeseries(
    df_gen_states,
    df_gen_info,
    df_node_load
):
    """Plot generator timeseries power output

    Parameters
    ----------
    df_gen_states : pandas.DataFrame
        Generator output DataFrame
    df_gen_info : pandas.DataFrame
        Generator information DataFrame
    df_node_load : pandas.DataFrame
        Loads (just for datetime)

    Returns
    -------
    seaborn.axisgrid.FacetGrid
        Plots of once-through
    """
    # Add generator information
    df_gen_states = pd.merge(
        df_gen_states,
        df_gen_info,
        left_on='obj_name',
        right_on='obj_name',
        how='left'
    )

    # Add datetime
    df_node_load['datetime'] = pd.to_datetime(df_node_load['datetime'])
    df_node_load['pm_hour'] = df_node_load['hour_index']
    df_node_load['pm_day'] = df_node_load['day_index']
    mergecols = [
        'datetime',
        'pm_hour',
        'pm_day'
    ]
    df_gen_states = pd.merge(
        df_gen_states,
        df_node_load[mergecols],
        left_on=['hour', 'day'],
        right_on=['pm_hour', 'pm_day'],
        how='left'
    )

    # Create labels
    df_gen_states['Fuel/Cooling'] = \
        df_gen_states['MATPOWER Fuel'] + \
        '/' \
        + df_gen_states['923 Cooling Type']

    # Round generator output
    df_gen_states['pg'] = df_gen_states['pg'].round(3)

    # Plot
    g = sns.FacetGrid(
        df_gen_states,
        row='Fuel/Cooling',
        sharey=False,
        sharex=True,
        aspect=4.5,
        height=2.0,
    )
    g = g.map_dataframe(
        sns.lineplot,
        x='datetime',
        y='pg',
        hue='Plant Name',
        style='Plant Name',
        units='obj_name',
        estimator=None,
        lw=0.5,
    )
    for ax in g.axes:
        ax[0].legend(loc='center', bbox_to_anchor=(1.2, 0.5))
    g.set_axis_labels(y_var='Power Output [p.u.]', x_var='')
    plt.xticks(rotation=90)
    plt.tight_layout()

    return g
