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

    # # Temporary code for metrics (TODO switch to constraints)
    # for (_, row) in df_scenario_specs.iterrows():
    #     df_ls = []
    #     in_path = 'C:/Users/kravi/Desktop/mocot/io/outputs/states/scenario_0_metrics-*.csv'  # noqa
    #     in_path = in_path.replace(
    #         '0', str(row['scenario_code'])
    #     )

    #     # Read into single dataframe
    #     for file in glob.glob(in_path):
    #         df_ls.append(pd.read_csv(file))
    #     df = pd.concat(df_ls)

    #     # Writing
    #     out_path = paths['outputs']['runtime_template'].replace(
    #         '0', str(row['scenario_code'])
    #     )
    #     out_path = out_path.replace('runtime.txt', 'metrics.csv')
    #     df.to_csv(out_path, index=False)

    # Parameter names
    objective_names = pd.read_csv(
        paths['inputs']['objectives']
    ).columns.tolist()
    decision_names = pd.read_csv(
        paths['inputs']['decisions']
    ).columns.tolist()

    # Create runtime objects
    for (_, row) in df_scenario_specs.iterrows():
        path = paths['outputs']['runtime_template'].replace(
            '0', str(row['scenario_code'])
        )
        path_metrics = 'io/outputs/states/scenario_0_metrics.csv'
        path_metrics = path_metrics.replace('0', str(row['scenario_code']))
        df_metrics = pd.read_csv(path_metrics)
        runtime = postmocot.runtime.BorgRuntimeDiagnostic(
            path,
            decision_names,
            objective_names,
            df_metrics
        )
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
