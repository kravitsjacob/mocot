"""Figure creation in python"""

import seaborn as sns
import yaml
import os
import pandas as pd

import postmocot


def main():
    # Setup
    with open('paths.yml', 'r') as f:
        paths = yaml.safe_load(f)

    # Parameter names
    objective_names = pd.read_csv(
        paths['inputs']['objectives']
    ).columns.tolist()
    decision_names = pd.read_csv(
        paths['inputs']['decisions']
    ).columns.tolist()
    metric_names = pd.read_csv(
        paths['inputs']['metrics']
    ).columns.tolist()

    # Create runtime object
    path = paths['outputs']['runtime_1']
    runtime = postmocot.runtime.BorgRuntimeDiagnostic(
        path,
        n_decisions=len(decision_names),
        n_objectives=len(objective_names),
        n_metrics=len(metric_names),
    )
    runtime.set_decision_names(decision_names)
    runtime.set_objective_names(objective_names)
    runtime.set_metric_names(metric_names)

    # Average scenario parallel
    if not os.path.exists(paths['outputs']['figures']['compare_parallel']):
        df_policy_performance = pd.read_csv(
            paths['outputs']['selected_policy_performance']
        )
        fig = postmocot.viz.average_parallel(
            runtime=runtime,
            df_policy_performance=df_policy_performance,
            objective_cols=[
                'f_gen',
                'f_with_tot',
                'f_con_tot',
                'f_emit',
            ],
            policy_col='policy_label',
            scenario_col='scenario',
            objective_cols_clean=[
                'Cost\n[\$]',
                'Withdrawal\n[Gallon]',
                'Consumption\n[Gallon]',
                'Emissions\n[lbs]',
            ],
            scenario_name='average week',
            tick_specs=[
                [[1.5e6, 2.3e6], ['1.5e6', '2.5e6']],
                [[9.5e7, 5.7e9], ['9.5e7',  '5.7e9']],
                [[1.9e7, 1.3e8], ['1.9e7',  '1.3e8']],
                [[2.4e7, 9.8e7], ['2.4e7', '9.8e7']]
            ],
            policy_palette=[
                sns.color_palette()[3],
                sns.color_palette('gray')[1],
                sns.color_palette('gray')[3],
                sns.color_palette('gray')[-1],
                sns.color_palette()[2],
            ],
            policy_order=[
                'status quo',
                'high water withdrawal penalty',
                'high water consumption penalty',
                'high emission penalty',
                'water-emission policy',
            ],
            legend_labels=[
                'status quo',
                'high water withdrawal penalty',
                'high water consumption penalty',
                'high emission penalty',
                'selected water-emission policy',
                'unselected water-emission policy',
            ],
            unselected_color=sns.color_palette()[2],
        )
        fig.savefig(paths['outputs']['figures']['compare_parallel'])

    # Global plot
    if not os.path.exists(paths['outputs']['figures']['compare_global']):
        df_policy_performance = pd.read_csv(
            paths['outputs']['selected_policy_performance']
        )
        fig = postmocot.viz.global_performance(
            df=df_policy_performance,
            objective_cols=runtime.objective_names[:-3],
            decision_cols=runtime.decision_names,
            scenario_col='scenario',
            policy_col='policy_label',
            policy_order=[
                'status quo',
                'high water withdrawal penalty',
                'high water consumption penalty',
                'high emission penalty',
                'water-emission policy',
            ],
            scenario_order=[
                'average week',
                'extreme load/climate',
                'nuclear outage',
                'line outage',
                'avoid temperature violation',
            ],
            objective_order=[
                'f_gen',
                'f_with_tot',
                'f_con_tot',
                'f_disvi_tot',
                'f_emit',
                'f_ENS',
            ],
            policy_clean=[
                'status quo',
                'high\nwater\nwithdrawal\npenalty\n',
                'high\nwater\nconsumption\npenalty\n',
                'high\nemission\npenalty\n',
                'water-emission\npolicy\n',
            ],
            scenario_clean=[
                'Average\nweek',
                'Extreme\nload/climate',
                'Nuclear\noutage',
                'Line\noutage',
                'Avoid\ntemperature\nviolation',
            ],
            objective_clean=[
                'Cost\n[\$]',
                'Withdrawal\n[Gallon]',
                'Consumption\n[Gallon]',
                'Discharge\nViolations\n[Gallon $^\circ$C]',
                'Emissions\n[lbs]',
                'Reliability\n[MWh]',
            ],
            custom_pallete=[
                sns.color_palette()[3],
                sns.color_palette('gray')[1],
                sns.color_palette('gray')[3],
                sns.color_palette('gray')[-1],
                sns.color_palette()[2],
            ]
        )
        fig.savefig(paths['outputs']['figures']['compare_global'])

    # Comparison plot
    if not os.path.exists(paths['outputs']['figures']['compare_relative']):
        df_policy_performance = pd.read_csv(
            paths['outputs']['selected_policy_performance']
        )
        fig_compare, fig_single = postmocot.viz.comparison(
            df=df_policy_performance,
            objective_cols=runtime.objective_names[:-3],
            decision_cols=runtime.decision_names,
            scenario_col='scenario',
            policy_col='policy_label',
            status_quo_policy='status quo',
            policy_order=[
                'high water withdrawal penalty',
                'high water consumption penalty',
                'high emission penalty',
                'water-emission policy',
            ],
            scenario_order=[
                'average week',
                'extreme load/climate',
                'nuclear outage',
                'line outage',
                'avoid temperature violation',
            ],
            objective_order=[
                'f_gen',
                'f_with_tot',
                'f_con_tot',
                'f_disvi_tot',
                'f_emit',
                'f_ENS',
            ],
            policy_clean=[
                'high\nwater\nwithdrawal\npenalty\n',
                'high\nwater\nconsumption\npenalty\n',
                'high\nemission\npenalty\n',
                'water-emission\npolicy\n',
            ],
            scenario_clean=[
                'Average\nweek',
                'Extreme\nload/climate',
                'Nuclear\noutage',
                'Line\noutage',
                'Avoid\ntemperature\nviolation',
            ],
            objective_clean=[
                'Cost\n[\$]',
                'Withdrawal\n[Gallon]',
                'Consumption\n[Gallon]',
                'Discharge\nViolations\n[Gallon $^\circ$C]',
                'Emissions\n[lbs]',
                'Reliability\n[MW]',
            ],
            custom_pallete=[
                sns.color_palette('gray')[1],
                sns.color_palette('gray')[3],
                sns.color_palette('gray')[-1],
                sns.color_palette()[2],
            ],
            single_scenario='Extreme\nload/climate',
        )
        fig_compare.savefig(paths['outputs']['figures']['compare_relative'])
        fig_single.savefig(paths['outputs']['figures']['compare_single'])

    # Comparison plot with global and relative difference
    if not os.path.exists(
        paths['outputs']['figures']['compare_global_relative']
    ):
        df_policy_performance = pd.read_csv(
            paths['outputs']['selected_policy_performance']
        )
        fig = postmocot.viz.global_relative_performance(
            df=df_policy_performance,
            objective_cols=runtime.objective_names[:-3],
            decision_cols=runtime.decision_names,
            scenario_col='scenario',
            policy_col='policy_label',
            policy_order=[
                'status quo',
                'high water withdrawal penalty',
                'high water consumption penalty',
                'high emission penalty',
                'water-emission policy',
            ],
            scenario_order=[
                'average week',
                'extreme load/climate',
                'nuclear outage',
                'line outage',
                'avoid temperature violation',
            ],
            objective_order=[
                'f_gen',
                'f_with_tot',
                'f_con_tot',
                'f_disvi_tot',
                'f_emit',
                'f_ENS',
            ],
            policy_clean=[
                'status\nquo',
                'high\nwater\nwithdrawal\npenalty\n',
                'high\nwater\nconsumption\npenalty\n',
                'high\nemission\npenalty\n',
                'water-emission\npolicy\n',
            ],
            status_quo_policy_clean='status\nquo',
            scenario_clean=[
                'Average\nweek',
                'Extreme\nload/climate',
                'Nuclear\noutage',
                'Line\noutage',
                'Avoid\ntemperature\nviolation',
            ],
            objective_clean=[
                'Cost\n[\$]',
                'Withdrawal\n[Gallon]',
                'Consumption\n[Gallon]',
                'Discharge\nViolations\n[Gallon $^\circ$C]',
                'Emissions\n[lbs]',
                'Reliability\n[MW]',
            ],
            custom_pallete=[
                sns.color_palette('gray')[1],
                sns.color_palette('gray')[3],
                sns.color_palette('gray')[-1],
                sns.color_palette()[2],
            ],
            status_quo_color=sns.color_palette()[3],

        )
    fig.savefig(paths['outputs']['figures']['compare_global_relative'])


if __name__ == '__main__':
    main()
