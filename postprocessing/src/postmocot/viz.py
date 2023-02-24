"""Hardcoded Visualization functions"""

import postmocot
import pandas as pd
import numpy as np
from matplotlib.lines import Line2D
import paxplot
import seaborn as sns
from matplotlib.legend_handler import HandlerTuple
sns.reset_orig()


def average_parallel(
    runtime: postmocot.runtime.BorgRuntimeDiagnostic,
    df_policy_performance: pd.DataFrame,
    objective_cols: list,
    policy_col: str,
    scenario_col: str,
    objective_cols_clean: list,
    scenario_name: str,
    tick_specs: list,
    policy_palette: list,
    policy_order: list,
    legend_labels: list,
):
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
    # Judgement policy performance preparation
    df_policy_performance[policy_col] = pd.Categorical(
        df_policy_performance[policy_col],
        policy_order
    )
    df_policy_performance = df_policy_performance.sort_values([policy_col])
    df_policy_performance = df_policy_performance[
        df_policy_performance[scenario_col] == scenario_name
    ]
    df_policy_performance = df_policy_performance[objective_cols]
    df_policy_performance = df_policy_performance.reset_index(drop=True)

    # Plotting
    paxfig = paxplot.pax_parallel(n_axes=len(df_policy_performance.columns))
    for i, row in df_policy_performance.iterrows():
        paxfig.plot(
            [row[objective_cols].to_numpy()],
            line_kwargs={
                'linewidth': 2.7,
                'color': policy_palette[i],
            }
        )

    # Adding a colorbar
    paxfig.add_legend(labels=legend_labels)
    paxfig.axes[-1].get_legend().set_bbox_to_anchor((1.45, 0.5))

    # Limits
    for ax_i, (i, j) in enumerate(tick_specs):
        paxfig.set_ticks(
            ax_idx=ax_i,
            ticks=i,
            labels=j
        )

    # Add labels
    paxfig.set_labels(objective_cols_clean)

    # Dimensions
    paxfig.set_size_inches(11, 3)
    paxfig.subplots_adjust(left=0.1, bottom=0.2, right=0.9, top=0.9)

    return paxfig


def average_parallel_metrics(
    runtime: postmocot.runtime.BorgRuntimeDiagnostic,
    df_policy_metrics: pd.DataFrame,
    metric_cols: list,
    policy_col: str,
    scenario_col: str,
    metric_cols_clean: list,
    scenario_name: str,
    policy_palette: list,
    policy_order: list,
    legend_labels: list,
):
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
    # Judgement policy performance preparation
    df_policy_metrics[policy_col] = pd.Categorical(
        df_policy_metrics[policy_col],
        policy_order
    )
    df_policy_metrics = df_policy_metrics.sort_values([policy_col])
    df_policy_metrics = df_policy_metrics[
        df_policy_metrics[scenario_col] == scenario_name
    ]
    df_policy_metrics = df_policy_metrics[metric_cols]
    df_policy_metrics = df_policy_metrics.reset_index(drop=True)

    # Plotting
    paxfig = paxplot.pax_parallel(n_axes=len(df_policy_metrics.columns))
    for i, row in df_policy_metrics.iterrows():
        paxfig.plot(
            [row[metric_cols].to_numpy()],
            line_kwargs={
                'linewidth': 2.7,
                'color': policy_palette[i],
            }
        )

    # Adding a colorbar
    paxfig.add_legend(labels=legend_labels)
    paxfig.axes[-1].get_legend().set_bbox_to_anchor((3.7, 0.5))

    # Add labels
    paxfig.set_labels(metric_cols_clean)

    # Dimensions
    paxfig.set_size_inches(11.5, 3)
    paxfig.subplots_adjust(left=0.07, bottom=0.2, right=0.75, top=0.9)

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
    g_compare.figure.subplots_adjust(
        left=0.15,
        bottom=0.1,
        right=0.75,
        top=0.9
    )

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


def global_status_quo_relative_performance(
    df: pd.DataFrame,
    objective_cols: list,
    decision_cols: list,
    scenario_col: str,
    policy_col: str,
    policy_order: list,
    scenario_order: list,
    objective_order: list,
    policy_clean: list,
    status_quo_policy_clean: str,
    scenario_clean: list,
    objective_clean: list,
    custom_pallete: list,
    status_quo_color: tuple,
):
    """
    Comparison plot with global and relative performance

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
    status_quo_policy_clean : str
        Cleaned up name of status quo policy
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
    sns.set_style("whitegrid")

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

    # Separate DataFrames
    df_plot_not_status_quo = \
        df_plot[df_plot[policy_col] != status_quo_policy_clean]
    df_plot_status_quo = \
        df_plot[df_plot[policy_col] == status_quo_policy_clean]

    # Make bar plots
    g = sns.FacetGrid(
        df_plot_status_quo,
        row='obj',
        sharey='row',
        height=1.4,
        aspect=5.8,
        gridspec_kws={
            'wspace': 0.1,
            'hspace': 0.25
        }
    )
    g.map(
        sns.barplot,
        scenario_col,
        'obj_value',
        color='w',
        edgecolor=status_quo_color,
        alpha=None,
        linewidth=2.5
    )

    # Filter policies
    policies_not_status_quo = [
        x for x
        in policy_clean if x != status_quo_policy_clean
    ]

    # Add lollipops
    for i, ax in enumerate(g.axes[:, 0]):  # Objectives
        # Get objective
        objective = objective_clean[i]

        df_status_quo = df_plot_status_quo[
            df_plot_status_quo['obj'] == objective
        ]

        for j, policy in enumerate(policies_not_status_quo):  # Policies
            # Filter
            df_temp = df_plot_not_status_quo[
                (df_plot_not_status_quo['obj'] == objective_clean[i]) &
                (df_plot_not_status_quo[policy_col] == policy)
            ]

            # Plot points
            x = np.arange(0, len(df_temp)) - 0.3 + j * 0.2
            ax.scatter(
                x,
                df_temp['obj_value'],
                color=custom_pallete[j],
                marker='o',
            )

            # Plot stems
            ax.vlines(
                x,
                ymin=df_status_quo['obj_value'],
                ymax=df_temp['obj_value'],
                colors=custom_pallete[j],
            )

    # Y labels
    y_labels = df_plot['obj'].unique().tolist()
    for i, ax in enumerate(g.axes[:, 0]):
        ax.set_ylabel(y_labels[i])

    # Better/worse labels
    for i, ax in enumerate(g.axes[:, -1]):
        ax2 = ax.twinx()
        ax2.set_yticks([1, 0], ['Worse', 'Better'])
    # X labels
    g.set_xlabels('Scenario')
    g.figure.text(0.05, 0.5, 'Objectives', rotation=90)

    # Remove titles
    g.set_titles(
        template=''
    )

    # Add legend for relative policies
    custom_lines = [
        (
            Line2D([0], [0], color=i),
            Line2D([0], [0], color=i, linestyle='', marker='o')
        )
        for i in custom_pallete
    ]
    custom_lines.insert(
        0,
        Line2D([0], [0], color=status_quo_color, linewidth=2.5),
    )
    g.axes[-1, -1].legend(
        custom_lines,
        policy_clean,
        bbox_to_anchor=(1.7, 5.2),
        title='Policy',
        handler_map={tuple: HandlerTuple(ndivide=None, pad=-0.2)}
    )

    # Sizing
    g.figure.subplots_adjust(
        left=0.20, bottom=0.1, right=0.65, top=0.90
    )

    return g


def global_average_relative_performance(
    df: pd.DataFrame,
    objective_cols: list,
    decision_cols: list,
    scenario_col: str,
    policy_col: str,
    policy_order: list,
    scenario_order: list,
    objective_order: list,
    policy_clean: list,
    average_scenario_clean: str,
    scenario_clean: list,
    objective_clean: list,
    custom_policy_pallete: list,
    custom_scenario_markers: list,
):
    """
    Comparison plot with global and relative performance

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
    average_scenario_clean : str
        Cleaned up name of average week
    scenario_clean : list
        Cleaned up scenario names
    objective_clean : list
        Cleaned up objective names
    custom_policy_pallete : list
        Custom color pallete for bars

    Returns
    -------
    seaborn.axisgrid.FacetGrid
        Plot of subsequent scenarios
    """
    # Setup
    sns.set()
    sns.set_style("whitegrid")

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

    # Separate DataFrames
    df_plot_not_average = \
        df_plot[df_plot[scenario_col] != average_scenario_clean]
    df_plot_average = \
        df_plot[df_plot[scenario_col] == average_scenario_clean]

    # Filter policies
    scenarios_not_average = [
        x for x
        in scenario_clean if x != average_scenario_clean
    ]

    # Make bar plots
    g = sns.FacetGrid(
        df_plot_average,
        row='obj',
        sharey='row',
        height=1.4,
        aspect=5.9,
        gridspec_kws={
            'wspace': 0.1,
            'hspace': 0.25
        }
    )
    g.map(
        sns.barplot,
        policy_col,
        'obj_value',
        color='w',
        edgecolor=custom_policy_pallete,
        alpha=None,
        linewidth=2.5,
        linestyle=(0, (1, 1))
    )

    # Add lollipops
    for i, ax in enumerate(g.axes[:, 0]):  # Objectives
        # Get objective
        objective = objective_clean[i]

        df_temp_min = df_plot_average[
            df_plot_average['obj'] == objective
        ]

        for j, scenario in enumerate(scenarios_not_average):  # Scenarios
            # Filter
            df_temp_max = df_plot_not_average[
                (df_plot_not_average['obj'] == objective_clean[i]) &
                (df_plot_not_average[scenario_col] == scenario)
            ]

            # Plot points
            x = np.arange(0, len(df_temp_max)) - 0.3 + j * 0.2
            ax.scatter(
                x,
                df_temp_max['obj_value'],
                color=custom_policy_pallete,
                marker=custom_scenario_markers[j],
            )

            # Plot stems
            ax.vlines(
                x,
                ymin=df_temp_min['obj_value'],
                ymax=df_temp_max['obj_value'],
                colors=custom_policy_pallete,
            )

    # Y labels
    y_labels = df_plot['obj'].unique().tolist()
    for i, ax in enumerate(g.axes[:, 0]):
        ax.set_ylabel(y_labels[i])

    # Better/worse labels
    for i, ax in enumerate(g.axes[:, -1]):
        ax2 = ax.twinx()
        ax2.set_yticks([1, 0], ['Worse', 'Better'])
    # X labels
    g.set_xlabels('Policy')
    g.figure.text(0.05, 0.5, 'Objectives', rotation=90)

    # Remove titles
    g.set_titles(
        template=''
    )

    # Add legend for relative policies
    custom_lines = [
        (
            Line2D([0], [0], color='k'),
            Line2D([0], [0], color='k', linestyle='', marker=i)
        )
        for i in custom_scenario_markers
    ]
    custom_lines.insert(
        0,
        Line2D([0], [0], color='k', linestyle=(0, (1, 1)), linewidth=2.5),
    )
    g.axes[-1, -1].legend(
        custom_lines,
        scenario_clean,
        bbox_to_anchor=(1.6, 5.0),
        title='Scenario',
        handler_map={tuple: HandlerTuple(ndivide=None, pad=-0.2)},
    )

    # Sizing
    g.figure.subplots_adjust(
        left=0.2, bottom=0.20, right=0.70, top=0.90
    )

    return g
