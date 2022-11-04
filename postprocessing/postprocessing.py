"""Figure creation in python"""

import yaml
import os
import pandas as pd

import postmocot


def main():
    # Setup
    runtime_objs = {}
    with open('paths.yml', 'r') as f:
        paths = yaml.safe_load(f)
    df_scenario_specs = pd.read_csv(paths['inputs']['scenario_specs'])

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

    # Create runtime objects
    for (_, row) in df_scenario_specs.iterrows():
        path = paths['outputs']['runtime_template'].replace(
            '0', str(row['scenario_code'])
        )
        runtime = postmocot.runtime.BorgRuntimeDiagnostic(
            path,
            n_decisions=len(decision_names),
            n_objectives=len(objective_names),
            n_metrics=len(metric_names),
        )
        runtime.set_decision_names(decision_names)
        runtime.set_objective_names(objective_names)
        runtime.set_metric_names(metric_names)
        runtime_objs[row['name']] = runtime

    runtime_multi = postmocot.runtime.BorgRuntimeAggregator(runtime_objs)

    # Hypervolume
    if not os.path.exists(paths['outputs']['figures']['hypervolume']):
        reference_point = [
            1e7,
            1e11,
            1e9,
            1e12,
            1e10,
            1e4,
            2.0,
        ]
        fig = runtime_multi.plot_hypervolume(reference_point)
        fig.savefig(paths['outputs']['figures']['hypervolume'])

    # Interactive parallel
    if not os.path.exists(paths['outputs']['figures']['interactive_parallel']):
        exp = runtime_multi.plot_interactive_front()
        exp.to_html(paths['outputs']['figures']['interactive_parallel'])

    # Select policies
    if not os.path.exists(paths['outputs']['selected_policies']):
        df = postmocot.process.select_policies(
            runtime_multi.runs['average week']
        )
        df.to_csv(paths['outputs']['selected_policies'], index=False)

    # Average scenario parallel
    if not os.path.exists(paths['outputs']['figures']['average_parallel']):
        df_policies = pd.read_csv(paths['outputs']['selected_policies'])
        fig = postmocot.viz.average_parallel(
            runtime_multi.runs['average week'],
            df_policies
        )
        fig.savefig(paths['outputs']['figures']['average_parallel'])

    # Comparison plot
    if not os.path.exists(paths['outputs']['figures']['compare']):
        df_policy_performance = pd.read_csv(
            paths['outputs']['selected_policy_performance']
        )
        fig = postmocot.viz.comparison(
            df_policy_performance,
            runtime_multi.runs['average week'].objective_names,
            runtime_multi.runs['average week'].decision_names
        )
        fig.savefig(paths['outputs']['figures']['compare'])


if __name__ == '__main__':
    main()
