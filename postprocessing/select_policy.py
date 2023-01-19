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

    # Interactive parallel
    if not os.path.exists(paths['outputs']['figures']['interactive_parallel']):
        exp = runtime.plot_interactive_front()
        exp.to_html(paths['outputs']['figures']['interactive_parallel'])

    # Hypervolume
    if not os.path.exists(paths['outputs']['figures']['hypervolume']):
        reference_point = [
            1e7,
            1e11,
            1e9,
            1e12,
            1e10,
            1e4,
            0.5,
            0.5,
            0.5
        ]
        fig = runtime.plot_hypervolume(reference_point)
        fig.savefig(paths['outputs']['figures']['hypervolume'])

    # Select policies
    if not os.path.exists(paths['outputs']['selected_policies']):
        df_judgement = pd.read_csv(paths['outputs']['judgement_policies'])

        # Select policy
        df = postmocot.process.select_policies(
            runtime,
            closest_cost=1595155.0634075487,
            cost_col='f_gen',
            policy_name='water-emission policy',
            policy_col='policy_label'
        )

        # Making judgement solutions
        row = pd.DataFrame({
            'w_with': [0.0],
            'w_con': [0.0],
            'w_emit': [0.0],
            'policy_label': 'status quo'
        })
        df = pd.concat([df, row], axis=0)
        row = pd.DataFrame({
            'w_with': df_judgement['w_with'],
            'w_con': [0.0],
            'w_emit': [0.0],
            'policy_label': 'high water withdrawal penalty'
        })
        df = pd.concat([df, row], axis=0)
        row = pd.DataFrame({
            'w_with': [0.0],
            'w_con': df_judgement['w_con'],
            'w_emit': [0.0],
            'policy_label': 'high water consumption penalty'
        })
        df = pd.concat([df, row], axis=0)
        row = pd.DataFrame({
            'w_with': [0.0],
            'w_con': [0.0],
            'w_emit': df_judgement['w_emit'],
            'policy_label': 'high emission penalty'
        })
        df = pd.concat([df, row], axis=0)

        # Export
        df.to_csv(paths['outputs']['selected_policies'], index=False)


if __name__ == '__main__':
    main()
