"""Visualization Functions"""

import matplotlib.pyplot as plt
import seaborn as sns
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


def raw_exogenous(df_exogenous):
    """Plot of first 14 days of July 2019

    Parameters
    ----------
    df_exogenous : pandas.DataFrame
        Pandas exogenous inputs

    Returns
    -------
    matplotlib.figure.Figure
        Plot of temperature over time
    """
    # Subset data
    start = '2019-07-01'
    end = '2019-07-14'
    selection = \
        (df_exogenous['datetime'] > start) & (df_exogenous['datetime'] < end)
    df_exogenous = df_exogenous[selection]

    # Make plot
    fig, ax = plt.subplots()
    ax.plot(
        df_exogenous['datetime'],
        df_exogenous['air_temperature'],
        color=sns.color_palette()[0]
    )
    ax.plot(
        df_exogenous['datetime'],
        df_exogenous['water_temperature'],
        color=sns.color_palette()[1]
    )
    plt.xticks(rotation=45)
    plt.legend(['Air', 'Water'])
    plt.xticks(rotation=45)
    plt.ylabel(r'Average Temperature [$^\circ$C]')
    plt.tight_layout()

    return fig
