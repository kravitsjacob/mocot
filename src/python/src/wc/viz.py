"""Visualization Functions"""

import matplotlib.pyplot as plt
import matplotlib
import seaborn as sns
import pandas as pd
sns.set()


def sensitivity(df_oc, df_rc):
    """Sensitivity analysis plotting

    Parameters
    ----------
    df_oc : pandas.DataFrame
        Once-through information
    df_rc : pandas.DataFrame
        Recirculating information

    Returns
    -------
    seaborn.axisgrid.FacetGrid
        Plots of once-through
    seaborn.axisgrid.FacetGrid
        Plots of recirculating
    """
    # Once-through
    df_oc_plot = df_oc
    df_oc_plot['Fuel/Cooling'] = \
        df_oc['Fuel Type'] + '/' + df_oc['Cooling System Type']
    df_oc_plot = df_oc.melt(
        value_vars=['Withdrawal Rate [L/MWh]', 'Consumption Rate [L/MWh]'],
        id_vars=['Change in Temperature [K]', 'Fuel/Cooling']
    )
    g_oc = sns.FacetGrid(
        df_oc_plot,
        row='variable',
        hue='Fuel/Cooling',
        sharex='col',
        sharey=False,
        aspect=2
    )
    g_oc.map(sns.lineplot, 'Change in Temperature [K]', 'value', marker='o',)
    g_oc.add_legend()
    g_oc.axes[0, 0].set_title(' ')
    g_oc.axes[0, 0].set_ylabel('Withdrawal Rate [L/MWh]')
    g_oc.axes[1, 0].set_title(' ')
    g_oc.axes[1, 0].set_ylabel('Consumption Rate [L/MWh]')
    g_oc.axes[1, 0].set_xlabel('Change in Water Temperature [C]')

    # Recirculating
    df_rc_plot = df_rc
    df_rc_plot['Fuel/Cooling'] = \
        df_rc['Fuel Type'] + '/' + df_rc['Cooling System Type']
    df_rc_plot = df_rc_plot.melt(
        value_vars=['Withdrawal Rate [L/MWh]', 'Consumption Rate [L/MWh]'],
        id_vars=['Inlet Air Temperature [C]', 'Fuel/Cooling']
    )
    g_rc = sns.FacetGrid(
        df_rc_plot,
        row='variable',
        hue='Fuel/Cooling',
        sharex='col',
        sharey=False,
        aspect=2
    )
    g_rc.map(sns.lineplot, 'Inlet Air Temperature [C]', 'value', marker='o',)
    g_rc.add_legend()
    g_rc.axes[0, 0].set_title(' ')
    g_rc.axes[0, 0].set_ylabel('Withdrawal Rate [L/MWh]')
    g_rc.axes[1, 0].set_title(' ')
    g_rc.axes[1, 0].set_ylabel('Consumption Rate [L/MWh]')
    g_rc.axes[1, 0].set_xlabel('Inlet Air Temperature [C]')

    return g_oc, g_rc


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


def time_series(df_water_use):
    """Time series water use

    Parameters
    ----------
    df_water_use : pandas.DataFrame
        Dataframe of water use

    Returns
    -------
    seaborn.axisgrid.FacetGrid
        Plots of once-through
    """
    # Create labels
    df_water_use['Fuel/Cooling'] = \
        df_water_use['Fuel Type'] + '/' + df_water_use['Cooling Type']

    # Once-through
    g_with = sns.FacetGrid(
        df_water_use,
        row='Fuel/Cooling',
        sharex=True,
        sharey=True,
        margin_titles=True,
        aspect=3.5,
        height=2.5
    )
    g_with = g_with.map_dataframe(
        sns.lineplot,
        x='datetime',
        y='Withdrawal [L/h]',
        hue='Plant Name',
        style='Plant Name'
    )
    for ax in g_with.axes:
        ax[0].legend(loc='center', bbox_to_anchor=(1.2, 0.5))
    g_with.set_axis_labels(x_var='')
    plt.xticks(rotation=45)
    plt.tight_layout()

    # Once-through
    g_con = sns.FacetGrid(
        df_water_use,
        row='Fuel/Cooling',
        sharex='col',
        sharey=True,
        margin_titles=True,
        aspect=3.5,
        height=2.5
    )
    g_con.map_dataframe(
        sns.lineplot,
        x='datetime',
        y='Consumption [L/h]',
        hue='Plant Name',
        style='Plant Name'
    )
    for ax in g_con.axes:
        ax[0].legend(loc='center', bbox_to_anchor=(1.2, 0.5))
    g_con.set_axis_labels(x_var='')
    plt.xticks(rotation=45)
    plt.tight_layout()

    return g_with, g_con


def loads(df_loads):
    """Plot load timeseries

    Parameters
    ----------
    df_loads : pandas.DataFrame
        DataFrame of loads

    Returns
    -------
    matplotlib.figure.Figure
        Plot of loads
    """
    fig, ax = plt.subplots()
    palette = sns.color_palette(['black'], len(df_loads['index'].unique()))
    sns.lineplot(
        data=df_loads,
        x='hour',
        y='pd',
        hue='index',
        palette=palette,
        legend=False,
        lw=0.5,
        alpha=0.5,
        ax=ax
    )
    plt.xlabel('Hour')
    plt.ylabel('Power [p.u.]')

    return fig


def gen_timeseries(df_gen, df_gen_pminfo, df_gen_info_water):
    """Plot generator timeseries power output

    Parameters
    ----------
    df_gen : pandas.DataFrame
        Generator output DataFrame
    df_gen_pminfo : pandas.DataFrame
        Generator PowerModel information DataFrame
    df_gen_info_water : pandas.DataFrame
        Generator water information DataFrame

    Returns
    -------
    seaborn.axisgrid.FacetGrid
        Plots of once-through
    """
    # Get powermodels information
    df_gen = pd.merge(
        df_gen,
        df_gen_pminfo[['name', 'gen_bus']],
        left_on='name',
        right_on='name',
        how='left'
    )

    # Get water information
    mergecols = [
        'MATPOWER Index',
        'MATPOWER Fuel',
        '923 Cooling Type',
        'Plant Name'
    ]
    df_gen = pd.merge(
        df_gen,
        df_gen_info_water[mergecols],
        left_on='gen_bus',
        right_on='MATPOWER Index',
        how='left'
    )

    # Create labels
    df_gen['Fuel/Cooling'] = \
        df_gen['MATPOWER Fuel'] + '/' + df_gen['923 Cooling Type']

    # Plot
    g = sns.FacetGrid(
        df_gen,
        row='Fuel/Cooling',
        sharey=False,
        sharex=True,
        aspect=4.5,
        height=2.0,
    )
    g = g.map_dataframe(
        sns.lineplot,
        x='hour',
        y='pg',
        hue='Plant Name',
        style='Plant Name',
        units='name',
        estimator=None,
        lw=0.5,
    )
    for ax in g.axes:
        ax[0].legend(loc='center', bbox_to_anchor=(1.2, 0.5))
    g.set_axis_labels(x_var='Hour', y_var='Power Output [p.u.]')
    plt.tight_layout()

    return g
