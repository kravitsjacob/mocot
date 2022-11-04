"""Hardcoded Visualization functions"""

import pandas as pd
import paxplot
import seaborn as sns
sns.reset_orig()


def average_parallel(runtime, df_policies):
    """Summary plot for average scenario

    Parameters
    ----------
    runtime : postmocot.runtime.BorgRuntimeDiagnostic
        Runtime obeject for average scenario
    df_policies : pandas.DataFrame
        Selected policies

    Returns
    -------
    paxplot.core.PaxFigure
        Plot
    """

    # Data preparation
    df = pd.DataFrame(
        runtime.archive_objectives[runtime.nfe[-1]],
        columns=runtime.objective_names
    )
    df = df.drop(columns=['f_ENS', 'f_disvi_tot', 'f_weight_tot'])
    df = df.rename(columns={
        'f_gen': 'Generation Cost [$]',
        'f_with_tot': 'Water Withdrawal [L]',
        'f_con_tot': 'Water Consumption [L]',
        'f_emit': 'Emissions [lbs]'
    })
    df_policies = df_policies.drop(
        columns=[
            'w_with',
            'w_con',
            'w_emit',
            'f_ENS',
            'f_disvi_tot',
            'f_weight_tot'
        ]
    )

    # Plotting
    paxfig = paxplot.pax_parallel(n_axes=len(df.columns))
    paxfig.plot(
        df_policies.loc[:, df_policies.columns != 'policy_label'].to_numpy()
    )

    # Adding a colorbar
    paxfig.add_legend(labels=df_policies['policy_label'].tolist())
    paxfig.axes[-1].get_legend().set_bbox_to_anchor((1.50, 0.5))

    # Limits
    paxfig.set_ticks(
        ax_idx=0,
        ticks=[4e6, 5e6, 6e6, 7e6],
        labels=['4e6', '5e6', '6e6', '7e6']
    )
    paxfig.set_ticks(
        ax_idx=1,
        ticks=[0, 1e10, 2e10],
        labels=['0', '1e10', '2e10']
    )
    paxfig.set_ticks(
        ax_idx=2,
        ticks=[0, 1e8, 2e8, 3e8],
        labels=['0', '1e8', '2e8', '3e8']
    )
    paxfig.set_ticks(
        ax_idx=3,
        ticks=[0, 1e8, 2e8, 3e8],
        labels=['0', '1e8', '2e8', '3e8']
    )

    # Add labels
    paxfig.set_labels(df.columns)

    # Add remaining solutions
    paxfig.plot(
        df.to_numpy(),
        line_kwargs={
            'alpha': 0.1,
            'linewidth': 0.5,
            'color': 'grey',
            'zorder': 0
        }
    )

    # Dimensions
    paxfig.set_size_inches(10, 3)

    return paxfig


def comparison(
    df,
    objectives,
    decisions,
):
    """
    Compare selected policies across scenarios relative to status quo

    Parameters
    ----------
    df : pandas.DataFrame
        Policy performance dataframe

    Returns
    -------
    seaborn.axisgrid.FacetGrid
        Plot of subsequent scenarios
    """
    sns.set()
    scenarios = df['scenario'].unique().tolist()
    policies = df['policy_label'].unique().tolist()

    # Get relative performance
    df_ls = []

    for s in scenarios:
        # Get scenario
        df_temp = df[df['scenario'] == s].copy()

        # Subtract from status quo
        status_quo = df_temp[df_temp['policy_label'] == 'status quo']
        differences = df_temp[objectives] - status_quo[objectives].to_numpy()
        df_temp[objectives] = differences

        # Store
        df_ls.append(df_temp)

    df_relative = pd.concat(df_ls)

    # Prepare data
    df_plot = df_relative.copy()
    df_plot = df_plot[df_plot['policy_label'] != 'status quo']
    df_plot = df_plot.drop(columns=decisions)
    df_plot = pd.melt(
        df_plot,
        value_vars=objectives,
        id_vars=['scenario', 'policy_label'],
        var_name='obj',
        value_name='obj_value'
    )
    df_plot = df_plot[df_plot['obj'] != 'f_weight_tot']

    # Make plot
    g = sns.FacetGrid(
        df_plot,
        row='obj',
        col='scenario',
        sharey='row',
        height=1.0,
        aspect=0.9,
        gridspec_kws={
            'wspace': 0.1,
            'hspace': 0.1
        }
    )
    g.set_titles(
        template=""
    )
    g.map(
        sns.barplot,
        'policy_label',
        'obj_value',
        'policy_label',
        palette=sns.color_palette('tab10')
    )
    g.add_legend()

    return g
