"""Visualization Functions"""

import matplotlib.pyplot as plt
import seaborn as sns
import pandas as pd
import paxplot
import hiplot as hip
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
    df_system_load['DATE'] = pd.to_datetime(df_system_load['DATE'])

    # Plot
    fig, ax = plt.subplots(figsize=(4, 5))
    ax.plot(
        df_system_load['DATE'],
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
    df_hour_to_hour['DATE'] = pd.to_datetime(df_hour_to_hour['DATE'])
    df_hour_to_hour = pd.melt(
        df_hour_to_hour,
        id_vars='DATE',
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
        x='DATE',
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


def interactive_parallel(df_front):
    """Create interactive parallel plot

    Parameters
    ----------
    df_front : pandas.DataFrame
        Nondominated front

    Returns
    -------
    hiplot.experiment.Experiment
        Hiplot experiment
    """
    # Create Plot
    color_col = 'f_gen'
    exp = hip.Experiment.from_dataframe(df_front)
    exp.parameters_definition[color_col].colormap = 'interpolateViridis'
    exp.display_data(hip.Displays.TABLE).update({'hide': ['uid', 'from_uid']})

    return exp
