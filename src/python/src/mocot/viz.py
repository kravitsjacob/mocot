"""Visualization Functions"""

import matplotlib.pyplot as plt
import seaborn as sns
import pandas as pd
import paxplot
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


def normal_parallel(
    df_objs
):
    """Objective parallel plots for normal scenarios

    Parameters
    ----------
    df_objs : pandas.DataFrame
        Objectives dataframe

    Returns
    -------
    PaxFigure
        Parallel plot
    """
    # Filter
    df_objs = df_objs[df_objs['gen_scenario'] == 'Normal']

    # Prepare data
    df_objs = df_objs.rename(
        {
            'f_con_peak': '$f_{con,peak}$ [L]',
            'f_con_tot': '$f_{con,tot}$ [L]',
            'f_gen': '$f_{gen}$ [\$]',  # noqa
            'f_with_peak': '$f_{with,peak}$ [L]',
            'f_with_tot': '$f_{with,tot}$ [L]'
        },
        axis=1
    )
    df_objs['dec_scenario'] = df_objs['dec_scenario'].replace({
        'High w_with_coal': 'High $w_{with,coal}$',
        'High w_con_coal': 'High $w_{con,coal}$',
        'High w_with_ng': 'High $w_{with,ng}$',
        'High w_con_ng': 'High $w_{con,ng}$',
        'High w_with_nuc': 'High $w_{with,nuc}$',
        'High w_con_nuc': 'High $w_{con,nuc}$'
    })
    df_data = df_objs.iloc[:, :-2]
    df_data.insert(0, 'Decision Label', df_objs['dec_scenario'])
    cols = df_data.columns

    # Create figure
    sns.reset_orig()
    paxfig = paxplot.pax_parallel(n_axes=len(cols))
    paxfig.plot(df_data.to_numpy())

    # Axes
    paxfig.set_lim(
        ax_idx=1,
        bottom=1.0e7,
        top=5.0e7
    )
    paxfig.set_ticks(
        ax_idx=1,
        ticks=[1e7, 2e7, 3e7, 4e7, 5e7],
        labels=['1e7', '2e7', '3e7', '4e7', '5e7']
    )
    paxfig.set_lim(
        ax_idx=2,
        bottom=0.0e8,
        top=4.0e8
    )
    paxfig.set_ticks(
        ax_idx=2,
        ticks=[0.0e8, 1e8, 2e8, 3e8, 4e8],
        labels=['0', '1e8', '2e8', '3e8', '4e8']
    )
    paxfig.set_lim(
        ax_idx=3,
        bottom=5.0e6,
        top=7.0e6
    )
    paxfig.set_ticks(
        ax_idx=3,
        ticks=[4.0e6, 5.0e6, 6.0e6, 7.0e6],
        labels=['4.0e6', '5.0e6', '6.0e6', '7.0e6']
    )
    paxfig.set_lim(
        ax_idx=4,
        bottom=0,
        top=6e8
    )
    paxfig.set_ticks(
        ax_idx=4,
        ticks=[0, 2e8, 4e8, 6e8],
        labels=['0', '2e8', '4e8', '6e8']
    )
    paxfig.set_lim(
        ax_idx=5,
        bottom=0,
        top=4e9
    )
    paxfig.set_ticks(
        ax_idx=5,
        ticks=[0, 1e9, 2e9, 3e9, 4e9],
        labels=['0', '1e9', '2e9', '3e9', '4e9']
    )

    # Add labels
    paxfig.set_labels(cols)

    # Dimensions
    paxfig.set_size_inches(8.5, 4)

    return paxfig


def no_nuclear_parallel(
    df_objs
):
    """Objective parallel plots for no nuclear scenarios

    Parameters
    ----------
    df_objs : pandas.DataFrame
        Objectives dataframe

    Returns
    -------
    PaxFigure
        Parallel plot
    """
    # Filter
    df_objs = df_objs[df_objs['gen_scenario'] == 'No Nuclear']

    # Prepare data
    df_objs = df_objs.rename(
        {
            'f_con_peak': '$f_{con,peak}$ [L]',
            'f_con_tot': '$f_{con,tot}$ [L]',
            'f_gen': '$f_{gen}$ [\$]',  # noqa
            'f_with_peak': '$f_{with,peak}$ [L]',
            'f_with_tot': '$f_{with,tot}$ [L]'
        },
        axis=1
    )
    df_objs['dec_scenario'] = df_objs['dec_scenario'].replace({
        'High w_with_coal': 'High $w_{with,coal}$',
        'High w_con_coal': 'High $w_{con,coal}$',
        'High w_with_ng': 'High $w_{with,ng}$',
        'High w_con_ng': 'High $w_{con,ng}$',
        'High w_with_nuc': 'High $w_{with,nuc}$',
        'High w_con_nuc': 'High $w_{con,nuc}$'
    })
    df_data = df_objs.iloc[:, :-2]
    df_data.insert(0, 'Decision Label', df_objs['dec_scenario'])
    cols = df_data.columns

    # Create figure
    sns.reset_orig()
    paxfig = paxplot.pax_parallel(n_axes=len(cols))
    paxfig.plot(df_data.to_numpy())

    # Axes
    paxfig.set_lim(
        ax_idx=1,
        bottom=1.0e7,
        top=5.0e7
    )
    paxfig.set_ticks(
        ax_idx=1,
        ticks=[1e7, 2e7, 3e7, 4e7, 5e7],
        labels=['1e7', '2e7', '3e7', '4e7', '5e7']
    )
    paxfig.set_lim(
        ax_idx=2,
        bottom=0.0e8,
        top=4.0e8
    )
    paxfig.set_ticks(
        ax_idx=2,
        ticks=[0.0e8, 1e8, 2e8, 3e8, 4e8],
        labels=['0', '1e8', '2e8', '3e8', '4e8']
    )
    paxfig.set_lim(
        ax_idx=3,
        bottom=5.0e6,
        top=7.0e6
    )
    paxfig.set_ticks(
        ax_idx=3,
        ticks=[4.0e6, 5.0e6, 6.0e6, 7.0e6],
        labels=['4.0e6', '5.0e6', '6.0e6', '7.0e6']
    )
    paxfig.set_lim(
        ax_idx=4,
        bottom=0,
        top=6e8
    )
    paxfig.set_ticks(
        ax_idx=4,
        ticks=[0, 2e8, 4e8, 6e8],
        labels=['0', '2e8', '4e8', '6e8']
    )
    paxfig.set_lim(
        ax_idx=5,
        bottom=0,
        top=4e9
    )
    paxfig.set_ticks(
        ax_idx=5,
        ticks=[0, 1e9, 2e9, 3e9, 4e9],
        labels=['0', '1e9', '2e9', '3e9', '4e9']
    )

    # Add labels
    paxfig.set_labels(cols)

    # Dimensions
    paxfig.set_size_inches(8.5, 4)

    return paxfig


def normal_gen_timeseries(
    df_states,
    df_gen_info,
    df_system_load
):
    """Plot generator timeseries power output

    Parameters
    ----------
    df_states : pandas.DataFrame
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
    # Filter scenario
    df_states = df_states[df_states['gen_scenario'] == 'Normal']

    # Add generator information
    df_gen_states = pd.merge(
        df_states,
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
        col='dec_scenario',
        sharey='row',
        sharex=True,
        aspect=0.9,
        height=1.8,
        gridspec_kws={
            'wspace': 0.05,
            'hspace': 0.10
        }
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
    row_titles = [
        'coal/OC',
        'coal/RC',
        'ng/None',
        'Coal/RI',
        'wind/None',
        'ng/RI',
        'nuclear/RC'
    ]
    for i, ax in enumerate(g.axes):
        for ax_row in ax:
            ax_row.set_title('')
        ax[-1].legend(
            loc='center',
            bbox_to_anchor=(1.55, 0.5),
            title=row_titles[i]
        )
    g.set_axis_labels(y_var='', x_var='')
    g.axes[3, 0].set_ylabel('Power [p.u.]')
    col_titles = [
        'No weights',
        'High $w_{with,coal}$',
        'High $w_{con,coal}$',
        'High $w_{with,ng}$',
        'High $w_{con,ng}$',
        'High $w_{with,nuc}$',
        'High $w_{con,nuc}$'
    ]
    for i, ax in enumerate(g.axes[0]):
        ax.set_title(col_titles[i])
    for ax in g.axes[-1]:
        ax.tick_params(axis='x', rotation=90)
    g.figure.subplots_adjust(right=0.87)

    return g


def nonuclear_gen_timeseries(
    df_states,
    df_gen_info,
    df_system_load
):
    """Plot generator timeseries power output

    Parameters
    ----------
    df_states : pandas.DataFrame
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
    # Filter scenario
    df_states = df_states[df_states['gen_scenario'] == 'No Nuclear']

    # Add generator information
    df_gen_states = pd.merge(
        df_states,
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
        col='dec_scenario',
        sharey='row',
        sharex=True,
        aspect=0.9,
        height=1.9,
        gridspec_kws={
            'wspace': 0.05,
            'hspace': 0.10
        }
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
    row_titles = [
        'coal/OC',
        'coal/RC',
        'ng/None',
        'Coal/RI',
        'wind/None',
        'ng/RI',
    ]
    for i, ax in enumerate(g.axes):
        for ax_row in ax:
            ax_row.set_title('')
        ax[-1].legend(
            loc='center',
            bbox_to_anchor=(1.55, 0.5),
            title=row_titles[i]
        )
    g.set_axis_labels(y_var='', x_var='')
    g.axes[3, 0].set_ylabel('Power [p.u.]')
    col_titles = [
        'No weights',
        'High $w_{with,coal}$',
        'High $w_{con,coal}$',
        'High $w_{with,ng}$',
        'High $w_{con,ng}$',
    ]
    for i, ax in enumerate(g.axes[0]):
        ax.set_title(col_titles[i])
    for ax in g.axes[-1]:
        ax.tick_params(axis='x', rotation=90)
    g.figure.subplots_adjust(right=0.85)

    return g
