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
    df_system_load
):
    """Plot generator timeseries power output

    Parameters
    ----------
    df_gen_states : pandas.DataFrame
        Generator output DataFrame
    df_gen_info : pandas.DataFrame
        Generator information DataFrame
    df_system_load : pandas.DataFrame
        System loads

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
    df_system_load['DATE'] = pd.to_datetime(df_system_load['DATE'])
    df_system_load = df_system_load.rename(
        {'hour_index': 'hour', 'day_index': 'day'},
        axis=1
    )
    mergecols = [
        'DATE',
        'hour',
        'day',
    ]
    df_gen_states = pd.merge(
        df_gen_states,
        df_system_load[mergecols],
        left_on=['hour', 'day'],
        right_on=['hour', 'day'],
        how='left'
    )

    # Create labels
    df_gen_states['Fuel/Cooling'] = \
        df_gen_states['MATPOWER Fuel'] + \
        '/' \
        + df_gen_states['923 Cooling Type']

    # Add loads
    df_system_load = df_system_load.rename({'ActualLoad': 'pg'}, axis=1)
    df_system_load['Plant Name'] = 'System Load'
    df_system_load['Fuel/Cooling'] = 'System Load'
    df_system_load['obj_name'] = 'System Load'
    df_system_load['pg'] = df_system_load['pg']/100.0
    df_gen_states = pd.concat([df_gen_states, df_system_load])

    # Round generator output
    df_gen_states['pg'] = df_gen_states['pg'].round(3)

    # Plot
    g = sns.FacetGrid(
        df_gen_states,
        row='Fuel/Cooling',
        sharey=False,
        sharex=True,
        aspect=5.0,
        height=1.7,
    )
    g = g.map_dataframe(
        sns.lineplot,
        x='DATE',
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


def multi_gen_timeseries(
    df_gen_no,
    df_gen_with,
    df_gen_info,
    df_system_load
):
    """Plot generator timeseries power output

    Parameters
    ----------
    df_gen_no : pandas.DataFrame
        Generator output DataFrame with no water weights
    df_gen_with : pandas.DataFrame
        Generator output DataFrame with water weights
    df_gen_info : pandas.DataFrame
        Generator information DataFrame
    df_system_load : pandas.DataFrame
        System loads

    Returns
    -------
    seaborn.axisgrid.FacetGrid
        Plots of once-through
    """
    # Combine with/without
    df_gen_no['Type'] = 'No Water Weight'
    df_gen_with['Type'] = 'High Withdrawal Weight'
    df_gen_states = pd.concat(
        [df_gen_no, df_gen_with],
        axis=0
    )

    # Add generator information
    df_gen_states = pd.merge(
        df_gen_states,
        df_gen_info,
        left_on='obj_name',
        right_on='obj_name',
        how='left'
    )

    # Add datetime
    df_system_load['DATE'] = pd.to_datetime(df_system_load['DATE'])
    df_system_load = df_system_load.rename(
        {'hour_index': 'hour', 'day_index': 'day'},
        axis=1
    )
    mergecols = [
        'DATE',
        'hour',
        'day',
    ]
    df_gen_states = pd.merge(
        df_gen_states,
        df_system_load[mergecols],
        left_on=['hour', 'day'],
        right_on=['hour', 'day'],
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
        col='Type',
        sharey='row',
        sharex=True,
        aspect=6.0,
        height=1.3,
    )
    g = g.map_dataframe(
        sns.lineplot,
        x='DATE',
        y='pg',
        hue='Plant Name',
        style='Plant Name',
        units='obj_name',
        estimator=None,
        lw=0.5,
    )
    for ax in g.axes:
        ax[0].legend(loc='center', bbox_to_anchor=(1.2, 0.5))
    g.set_axis_labels(y_var='Power [p.u.]', x_var='')
    for axes in g.axes.flat:
        _ = axes.set_xticklabels(axes.get_xticklabels(), rotation=90)
    plt.tight_layout()

    return g
