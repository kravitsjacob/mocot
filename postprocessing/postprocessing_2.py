"""Figure creation in python"""

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
