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
                '\nCost\n[\$]',
                '\nWithdrawal\n[Gallon]',
                '\nConsumption\n[Gallon]',
                '\nEmissions\n[lbs]',
            ],
            scenario_name='average week',
            tick_specs=[
                [[1.5e6, 2.3e6], ['\n1.5e6\n(better)', '2.5e6\n(worse)\n']],
                [[9.5e7, 5.7e9], ['\n9.5e7\n(better)',  '5.7e9\n(worse)\n']],
                [[1.9e7, 1.0e8], ['\n1.9e7\n(better)',  '1.0e8\n(worse)\n']],
                [[2.4e7, 9.8e7], ['\n2.4e7\n(better)', '9.8e7\n(worse)\n']]
            ],
            policy_palette=[
                sns.color_palette()[4],
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
                'water-emission policy',
            ],
        )
        fig.savefig(paths['outputs']['figures']['compare_parallel'])

    # Average scenario parallel metrics
    if not os.path.exists(paths['outputs']['figures']['compare_parallel_metrics']):
        df_policy_metrics = pd.read_csv(
            paths['outputs']['selected_policy_metrics']
        )
        fig = postmocot.viz.average_parallel_metrics(
            runtime=runtime,
            df_policy_metrics=df_policy_metrics,
            metric_cols=[
                'No Cooling System_output',
                'OC_output',
                'RC_output',
                'RI_output',
                'coal_output',
                'ng_output',
                'nuclear_output',
                'wind_output',
            ],
            policy_col='policy_label',
            scenario_col='scenario',
            metric_cols_clean=[
                'No\nCooling',
                'Once-through\nCooling',
                'Recirculating\nCooling',
                'Recirculating\nInduced\nCooling',
                'Coal',
                'Natural Gas',
                'Nuclear',
                'Wind',
            ],
            scenario_name='average week',
            policy_palette=[
                sns.color_palette()[4],
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
                'water-emission policy',
            ],
        )
        fig.savefig(paths['outputs']['figures']['compare_parallel_metrics'])

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
                'Energy\nNot\nSupplied\n[MWh]',
            ],
            custom_pallete=[
                sns.color_palette()[4],
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
                'Energy\nNot\nSupplied\n[MWh]',
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
                'Reliability\n[MWh]',
            ],
            custom_pallete=[
                sns.color_palette('gray')[1],
                sns.color_palette('gray')[3],
                sns.color_palette('gray')[-1],
                sns.color_palette()[2],
            ],
            status_quo_color=sns.color_palette()[4],

        )
        fig.savefig(paths['outputs']['figures']['compare_global_relative'])


if __name__ == '__main__':
    main()
