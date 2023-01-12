"""Hardcoded Visualization functions"""

import pandas as pd
import paxplot
import seaborn as sns
sns.reset_orig()


def average_parallel(runtime, df_policy_performance):
    """Summary plot for average scenario

    Parameters
    ----------
    runtime : postmocot.runtime.BorgRuntimeDiagnostic
        Runtime obeject for average scenario
    df_policy_performance : pandas.DataFrame
        Selected policies

    Returns
    -------
    paxplot.core.PaxFigure
        Plot
    """
    # Archive preparation
    df = pd.DataFrame(
        runtime.archive_objectives[runtime.nfe[-1]],
        columns=runtime.objective_names
    )
    df = df.drop(
        columns=['f_ENS', 'f_disvi_tot', 'f_w_with', 'f_w_con', 'f_w_emit']
    )

    # Judgement policy performance preparation
    df_policy_performance = df_policy_performance[
        df_policy_performance['scenario'] == 'average week'
    ]
    df_policy_performance = df_policy_performance[
        df.columns.tolist() + ['policy_label']
    ]

    # Column preparation
    df = df.rename(columns={
        'f_gen': r'$f_{gen}$ [\$]',
        'f_with_tot': '$f_{with,tot}$ [L]',
        'f_con_tot': '$f_{con,tot}$ [L]',
        'f_emit': '$f_{emit}$ [lbs]'
    })

    # Plotting
    paxfig = paxplot.pax_parallel(n_axes=len(df.columns))
    paxfig.plot(
        df_policy_performance.loc[
            :, df_policy_performance.columns != 'policy_label'
        ].to_numpy()
    )

    # Adding a colorbar
    paxfig.add_legend(labels=df_policy_performance['policy_label'].tolist())
    paxfig.axes[-1].get_legend().set_bbox_to_anchor((1.50, 0.5))

    # Limits
    paxfig.set_ticks(
        ax_idx=0,
        ticks=[1e6, 2e6, 3e6],
        labels=['1e6', '2e6', '3e6']
    )
    paxfig.set_ticks(
        ax_idx=1,
        ticks=[0, 5e9, 1e10],
        labels=['0', '5e9', '1e10']
    )
    paxfig.set_ticks(
        ax_idx=2,
        ticks=[0, 5e7, 1e8],
        labels=['0', '5e7', '1e8']
    )
    paxfig.set_ticks(
        ax_idx=3,
        ticks=[0, 5e7, 1e8],
        labels=['0', '5e7', '1e8']
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
    paxfig.set_size_inches(11, 3)

    return paxfig


def global_performance(
    df: pd.DataFrame,
    objective_cols: list,
    decision_cols: list,
    scenario_col: str,
    policy_col: str,
    policy_order: list,
    scenario_order: list,
    objective_order: list,
    policy_clean: list,
    scenario_clean: list,
    objective_clean: list,
    custom_pallete: list,
):
    """Plot of global perforamce

    Parameters
    ----------
    df : pd.DataFrame
        Performance dataframe
    objective_cols : list
        Objective column names
    decision_cols : list
        Decision column names
    scenario_col : str
        Name of scenario column
    policy_col : str
        Name of policy column
    policy_order : list
        Order of policies to plot
    scenario_order : list
        Order of scenarios to plot
    objective_order : list
        Order of objective to plot
    policy_clean : list
        Cleaned up policy names
    scenario_clean : list
        Cleaned up scenario names
    objective_clean : list
        Cleaned up objective names
    custom_pallete : list
        Custom color pallete for bars

    Returns
    -------
    seaborn.axisgrid.FacetGrid
        Plot of subsequent scenarios
    """
    # Setup
    sns.set()

    # Pivot data
    df_plot = df.drop(columns=decision_cols)
    df_plot = pd.melt(
        df_plot,
        value_vars=objective_cols,
        id_vars=[scenario_col, policy_col],
        var_name='obj',
        value_name='obj_value'
    )

    # Ording
    df_plot[policy_col] = pd.Categorical(
        df_plot[policy_col],
        policy_order
    )
    df_plot[scenario_col] = pd.Categorical(
        df_plot[scenario_col],
        scenario_order
    )
    df_plot['obj'] = pd.Categorical(
        df_plot['obj'],
        objective_order
    )
    df_plot = df_plot.sort_values(['obj', scenario_col, policy_col])

    # Rename
    df_plot['obj'] = df_plot['obj'].replace(
        dict(zip(objective_order, objective_clean))
    )
    df_plot[scenario_col] = df_plot[scenario_col].replace(
        dict(zip(scenario_order, scenario_clean))
    )
    df_plot[policy_col] = df_plot[policy_col].replace(
        dict(zip(policy_order, policy_clean))
    )

    # Plotting
    g = sns.FacetGrid(
        df_plot,
        row='obj',
        col=scenario_col,
        sharey='row',
        height=1.4,
        aspect=1.1,
        gridspec_kws={
            'wspace': 0.1,
            'hspace': 0.25
        }
    )
    g.map(
        sns.barplot,
        policy_col,
        'obj_value',
        policy_col,
        palette=custom_pallete,
        dodge=False
    )
    g.set_titles(
        template=""
    )
    y_labels = df_plot['obj'].unique().tolist()
    x_labels = df_plot[scenario_col].unique().tolist()
    for i, ax in enumerate(g.axes[:, 0]):
        ax.set_ylabel(y_labels[i])
    for i, ax in enumerate(g.axes[-1, :]):
        ax.set_xlabel(x_labels[i], rotation=0)
        ax.set_xticklabels('')
    g.add_legend(loc='right')
    g.figure.subplots_adjust(left=0.1, bottom=0.1, right=0.8, top=0.9)

    return g


def comparison(
    df: pd.DataFrame,
    objective_cols: list,
    decision_cols: list,
    scenario_col: str,
    policy_col: str,
    status_quo_policy: str,
    policy_order: list,
    scenario_order: list,
    objective_order: list,
    policy_clean: list,
    scenario_clean: list,
    objective_clean: list,
    custom_pallete: list,
    single_scenario: str,
):
    """
    Compare selected policies across scenarios relative to status quo


    Parameters
    ----------
    df : pd.DataFrame
        Performance dataframe
    objective_cols : list
        Objective column names
    decision_cols : list
        Decision column names
    scenario_col : str
        Name of scenario column
    policy_col : str
        Name of policy column
    status_quo_policy : str
        Name of status quo policy
    policy_order : list
        Order of policies to plot
    scenario_order : list
        Order of scenarios to plot
    objective_order : list
        Order of objective to plot
    policy_clean : list
        Cleaned up policy names
    scenario_clean : list
        Cleaned up scenario names
    objective_clean : list
        Cleaned up objective names
    custom_pallete : list
        Custom color pallete for bars
    single_scenario : str
        Single scenario cleaned name

    Returns
    -------
    seaborn.axisgrid.FacetGrid
        Plot of subsequent scenarios
    """
    # Setup
    sns.set()
    scenarios = df[scenario_col].unique().tolist()

    # Get relative performance
    df_ls = []

    for s in scenarios:
        # Get scenario
        df_temp = df[df[scenario_col] == s].copy()

        # Subtract from status quo
        status_quo = df_temp[df_temp[policy_col] == status_quo_policy]
        differences = \
            df_temp[objective_cols] - status_quo[objective_cols].to_numpy()
        df_temp[objective_cols] = differences

        # Store
        df_ls.append(df_temp)

    df_relative = pd.concat(df_ls)

    # Pivot data
    df_plot = df_relative.drop(columns=decision_cols)
    df_plot = df_plot[df_plot[policy_col] != status_quo_policy]
    df_plot = pd.melt(
        df_plot,
        value_vars=objective_cols,
        id_vars=[scenario_col, policy_col],
        var_name='obj',
        value_name='obj_value'
    )

    # Ording
    df_plot[policy_col] = pd.Categorical(
        df_plot[policy_col],
        policy_order
    )
    df_plot[scenario_col] = pd.Categorical(
        df_plot[scenario_col],
        scenario_order
    )
    df_plot['obj'] = pd.Categorical(
        df_plot['obj'],
        objective_order
    )
    df_plot = df_plot.sort_values(['obj', scenario_col, policy_col])

    # Rename
    df_plot['obj'] = df_plot['obj'].replace(
        dict(zip(objective_order, objective_clean))
    )
    df_plot[scenario_col] = df_plot[scenario_col].replace(
        dict(zip(scenario_order, scenario_clean))
    )
    df_plot[policy_col] = df_plot[policy_col].replace(
        dict(zip(policy_order, policy_clean))
    )

    # All scenarsio comparison
    g_compare = sns.FacetGrid(
        df_plot,
        row='obj',
        col=scenario_col,
        sharey='row',
        height=1.4,
        aspect=1.1,
        gridspec_kws={
            'wspace': 0.1,
            'hspace': 0.25
        }
    )
    g_compare.map(
        sns.barplot,
        policy_col,
        'obj_value',
        policy_col,
        palette=custom_pallete,
        dodge=False
    )
    g_compare.set_titles(
        template=""
    )
    y_labels = df_plot['obj'].unique().tolist()
    x_labels = df_plot[scenario_col].unique().tolist()
    for i, ax in enumerate(g_compare.axes[:, 0]):
        ax.set_ylabel(y_labels[i])
    for i, ax in enumerate(g_compare.axes[:, -1]):
        ax2 = ax.twinx()
        ax2.set_yticks([1, 0], ['Worse', 'Better'])
    for i, ax in enumerate(g_compare.axes[-1, :]):
        ax.set_xlabel(x_labels[i], rotation=0)
        ax.set_xticklabels('')
    for ax in g_compare.axes.flat:
        yabs_max = abs(max(ax.get_ylim(), key=abs))
        ax.set_ylim(ymin=-yabs_max, ymax=yabs_max)
    g_compare.add_legend(loc='right')
    g_compare.figure.subplots_adjust(left=0.15, bottom=0.1, right=0.75, top=0.9)

    # Single plot
    df_plot = df_plot[df_plot[scenario_col] == single_scenario]
    g_single = sns.FacetGrid(
        df_plot,
        row='obj',
        sharey='row',
        height=1.3,
        aspect=4.0,
        gridspec_kws={
            'wspace': 0.1,
            'hspace': 0.25
        }
    )
    g_single.map(
        sns.barplot,
        policy_col,
        'obj_value',
        policy_col,
        palette=custom_pallete,
        dodge=False
    )
    g_single.set_titles(
        template=""
    )
    g_single.set_xlabels('')
    y_labels = df_plot['obj'].unique().tolist()
    x_labels = df_plot[scenario_col].unique().tolist()
    for i, ax in enumerate(g_single.axes[:, 0]):
        ax.set_ylabel(y_labels[i])
        ax2 = ax.twinx()
        ax2.set_yticks([1, 0], ['Worse', 'Better'])
    for ax in g_single.axes.flat:
        yabs_max = abs(max(ax.get_ylim(), key=abs))
        ax.set_ylim(ymin=-yabs_max, ymax=yabs_max)
    g_single.figure.subplots_adjust(
        left=0.20, bottom=0.1, right=0.85, top=0.90
    )

    return g_compare, g_single
