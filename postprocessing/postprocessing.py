"""Figure creation in python"""

import yaml
import os
import pandas as pd
import glob

import postmocot


def main():
    # Setup
    runtime_objs = {}
    with open('paths.yml', 'r') as f:
        paths = yaml.safe_load(f)
    df_scenario_specs = pd.read_csv(paths['inputs']['scenario_specs'])

    # Daily average air/water temperature
    if not os.path.exists(paths['outputs']['figures']['temperatures']):
        scenario_code = '1'
        path = paths['outputs']['air_water_template'].replace(
            '0', scenario_code
        )
        df_air_water = pd.read_csv(path)
        fig = postmocot.viz.temperatures(df_air_water)
        fig.savefig(paths['outputs']['figures']['temperatures'])

    # System hourly load data
    if not os.path.exists(paths['outputs']['figures']['system_load']):
        df_system_load = pd.read_csv(paths['outputs']['system_load'])
        fig = postmocot.viz.system_load(df_system_load)
        fig.savefig(paths['outputs']['figures']['system_load'])

    # System hourly load factors data
    if not os.path.exists(paths['outputs']['figures']['system_load_factor']):
        df_system_load = pd.read_csv(paths['outputs']['system_load'])
        fig = postmocot.viz.system_load_factor(df_system_load)
        fig.savefig(paths['outputs']['figures']['system_load_factor'])

    # Node hour-to-hour load factors data
    if not os.path.exists(paths['outputs']['figures']['hour_node_load']):
        df_hour_to_hour = pd.read_csv(paths['outputs']['hour_to_hour'])
        fig = postmocot.viz.hour_node_load(df_hour_to_hour)
        fig.savefig(paths['outputs']['figures']['hour_node_load'])

    # Node hourly load data
    if not os.path.exists(paths['outputs']['figures']['node_load']):
        scenario_code = '1'
        path = paths['outputs']['node_load_template'].replace(
            '0', scenario_code
        )
        df_node_load = pd.read_csv(path)
        fig = postmocot.viz.node_load(df_node_load)
        fig.savefig(paths['outputs']['figures']['node_load'])

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
    for (_, row) in df_scenario_specs.head(1).iterrows():
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
        fig = runtime_multi.plot_hypervolume()
        fig.savefig(paths['outputs']['figures']['hypervolume'])

    # Interactive parallel
    if not os.path.exists(paths['outputs']['figures']['interactive_parallel']):
        exp = runtime_multi.plot_interactive_front()
        exp.to_html(paths['outputs']['figures']['interactive_parallel'])


if __name__ == '__main__':
    main()
