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
    if not os.path.exists(paths['outputs']['figures']['average_parallel']):
        df_policy_performance = pd.read_csv(
            paths['outputs']['selected_policy_performance']
        )
        fig = postmocot.viz.average_parallel(
            runtime,
            df_policy_performance
        )
        fig.savefig(paths['outputs']['figures']['average_parallel'])

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
                'Reliability\n[MW]',
            ],
            custom_pallete=[
                sns.color_palette('tab10')[0],
                sns.color_palette('gray')[1],
                sns.color_palette('gray')[3],
                sns.color_palette('gray')[-1],
                sns.color_palette('tab10')[2],
            ]
        )
        fig.savefig(paths['outputs']['figures']['compare_global'])

    # Comparison plot
    if not os.path.exists(paths['outputs']['figures']['compare_all']):
        df_policy_performance = pd.read_csv(
            paths['outputs']['selected_policy_performance']
        )
        fig_compare, fig_single = postmocot.viz.comparison(
            df_policy_performance,
            runtime.objective_names,
            runtime.decision_names
        )
        fig_compare.savefig(paths['outputs']['figures']['compare_all'])
        fig_single.savefig(paths['outputs']['figures']['compare_single'])


if __name__ == '__main__':
    main()
