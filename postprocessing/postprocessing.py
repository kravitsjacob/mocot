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

    # Average scenario parallel
    if not os.path.exists(paths['outputs']['figures']['compare_parallel']):
        df_policy_performance = pd.read_csv(
            paths['outputs']['selected_policy_performance']
        )
        fig = postmocot.viz.average_parallel(
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
                '\nWater\nWithdrawal\n[Gallon]',
                '\nWater\nConsumption\n[Gallon]',
                '\nEmissions\n[lbs]',
            ],
            scenario_name='average week',
            policy_order=[
                'status quo',
                'high water withdrawal penalty',
                'high water consumption penalty',
                'high emission penalty',
                'water-emission policy',
            ],
            plotting_specs={
                'tick_specs': [
                    [[1.5e6, 2.3e6], ['\n1.5e6\n(Better)', '2.5e6\n(Worse)\n']],  # noqa
                    [[9.5e7, 5.7e9], ['\n9.5e7\n(Better)',  '5.7e9\n(Worse)\n']],  # noqa
                    [[1.9e7, 1.0e8], ['\n1.9e7\n(Better)',  '1.0e8\n(Worse)\n']],  # noqa
                    [[2.4e7, 9.8e7], ['\n2.4e7\n(Better)', '9.8e7\n(Worse)\n']]
                ],
                'policy_palette': [
                    sns.color_palette()[4],
                    sns.color_palette('gray')[2],
                    sns.color_palette('gray')[3],
                    sns.color_palette('gray')[5],
                    sns.color_palette()[2],
                ],
                'legend_labels': [
                    'Status Quo',
                    'High Water Withdrawal Penalty',
                    'High Water Consumption Penalty',
                    'High Emissions Penalty',
                    'Water-Emissions',
                ],
                'legend_title': 'Policy',
            },
        )
        fig.savefig(paths['outputs']['figures']['compare_parallel'])

    # Average scenario parallel metrics
    if not os.path.exists(
        paths['outputs']['figures']['compare_parallel_metrics']
    ):
        df_policy_metrics = pd.read_csv(
            paths['outputs']['selected_policy_metrics']
        )
        fig = postmocot.viz.average_parallel_metrics(
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
            policy_order=[
                'status quo',
                'high water withdrawal penalty',
                'high water consumption penalty',
                'high emission penalty',
                'water-emission policy',
            ],
            plotting_specs={
                'policy_palette': [
                    sns.color_palette()[4],
                    sns.color_palette('gray')[2],
                    sns.color_palette('gray')[3],
                    sns.color_palette('gray')[5],
                    sns.color_palette()[2],
                ],
                'legend_labels': [
                    'Status Quo',
                    'High Water Withdrawal Penalty',
                    'High Water Consumption Penalty',
                    'High Emissions Penalty',
                    'Water-Emissions',
                ],
                'legend_title': 'Policy',
            }
        )
        fig.savefig(paths['outputs']['figures']['compare_parallel_metrics'])

    # Global plot
    if not os.path.exists(paths['outputs']['figures']['compare_global']):
        df_policy_performance = pd.read_csv(
            paths['outputs']['selected_policy_performance']
        )
        fig = postmocot.viz.global_performance(
            df=df_policy_performance,
            objective_cols=objective_names[:-3],
            decision_cols=decision_names,
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
                'Status Quo',
                'High\nWater\nWithdrawal\nPenalty\n',
                'High\nWater\nConsumption\nPenalty\n',
                'High\nEmissions\nPenalty\n',
                'Water-Emissions',
            ],
            scenario_clean=[
                'Average\nWeek',
                'Extreme\nLoad/Climate',
                'Nuclear\nOutage',
                'Critical\nLine\noutage',
                'Avoid\nTemperature\nViolation',
            ],
            objective_clean=[
                'Cost\n[\$]',
                'Water\nWithdrawal\n[Gallon]',
                'Water\nConsumption\n[Gallon]',
                'Discharge\nViolations\n[Gallon $^\circ$C]',
                'Emissions\n[lbs]',
                'Energy\nNot\nSupplied\n[MWh]',
            ],
            plotting_specs={
                'custom_pallete': [
                    sns.color_palette()[4],
                    sns.color_palette('gray')[2],
                    sns.color_palette('gray')[3],
                    sns.color_palette('gray')[5],
                    sns.color_palette()[2],
                ],
                'legend_title': 'Policy',
                'x_title': 'Scenario',
                'y_title': 'Objective',
            }
        )
        fig.savefig(paths['outputs']['figures']['compare_global'])

    # Comparison plot with global and average week relative difference
    if not os.path.exists(
        paths['outputs']['figures']['compare_global_average_relative']
    ):
        df_policy_performance = pd.read_csv(
            paths['outputs']['selected_policy_performance']
        )
        fig = postmocot.viz.global_average_relative_performance(
            df=df_policy_performance,
            objective_cols=objective_names[:-3],
            decision_cols=decision_names,
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
                'Status\nQuo',
                'High\nWater\nWithdrawal\nPenalty\n',
                'High\nWater\nConsumption\nPenalty\n',
                'High\nEmissions\nPenalty\n',
                'Water-Emissions',
            ],
            average_scenario_clean='Average\nweek',
            scenario_clean=[
                'Average\nweek',
                'Extreme\nload/climate',
                'Nuclear\noutage',
                'Critical\nLine\noutage',
                'Avoid\ntemperature\nviolation',
            ],
            objective_clean=[
                'Cost\n[\$]',
                'Water\nWithdrawal\n[Gallon]',
                'Water\nConsumption\n[Gallon]',
                'Discharge\nViolations\n[Gallon $^\circ$C]',
                'Emissions\n[lbs]',
                'Energy\nNot\nSupplied\n[MWh]',
            ],
            plotting_specs={
                'custom_policy_pallete': [
                    sns.color_palette()[4],
                    sns.color_palette('gray')[2],
                    sns.color_palette('gray')[3],
                    sns.color_palette('gray')[5],
                    sns.color_palette()[2],
                ],
                'custom_scenario_markers': [
                    'v',
                    's',
                    'X',
                    'D',
                ],
                'x_title': 'Policy',
                'y_title': 'Objective',
                'legend_title': 'Scenario',
            }
        )
        fig.savefig(
            paths['outputs']['figures']['compare_global_average_relative']
        )

    # Comparison plot with global and status quo relative difference
    if not os.path.exists(
        paths['outputs']['figures']['compare_global_status_quo_relative']
    ):
        df_policy_performance = pd.read_csv(
            paths['outputs']['selected_policy_performance']
        )
        fig = postmocot.viz.global_status_quo_relative_performance(
            df=df_policy_performance,
            objective_cols=objective_names[:-3],
            decision_cols=decision_names,
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
                'Status\nQuo',
                'High\nWater\nWithdrawal\nPenalty\n',
                'High\nWater\nConsumption\nPenalty\n',
                'High\nEmissions\nPenalty\n',
                'Water-Emissions',
            ],
            status_quo_policy_clean='Status\nQuo',
            scenario_clean=[
                'Average\nWeek',
                'Extreme\nLoad/Climate',
                'Nuclear\nOutage',
                'Critical\nLine\nOutage',
                'Avoid\nTemperature\nViolation',
            ],
            objective_clean=[
                'Cost\n[\$]',
                'Water\nWithdrawal\n[Gallon]',
                'Water\nConsumption\n[Gallon]',
                'Discharge\nViolations\n[Gallon $^\circ$C]',
                'Emissions\n[lbs]',
                'Energy\nNot\nSupplied\n[MWh]',
            ],
            plotting_specs={
                'custom_pallete': [
                    sns.color_palette('gray')[2],
                    sns.color_palette('gray')[3],
                    sns.color_palette('gray')[5],
                    sns.color_palette()[2],
                ],
                'status_quo_color': sns.color_palette()[4],
                'x_title': 'Scenario',
                'y_title': 'Objective',
                'legend_title': 'Policy',
            }
        )
        fig.savefig(
            paths['outputs']['figures']['compare_global_status_quo_relative']
        )


if __name__ == '__main__':
    main()
