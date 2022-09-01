"""Figure creation in python"""

import yaml
import os
import pandas as pd

import mocot


def main():
    with open('analysis/paths.yml', 'r') as f:
        paths = yaml.safe_load(f)

    # Daily average air/water temperature
    if not os.path.exists(paths['outputs']['figures']['temperatures']):
        df_air_water = pd.read_csv(paths['outputs']['air_water'])
        fig = mocot.viz.temperatures(df_air_water)
        fig.savefig(paths['outputs']['figures']['temperatures'])

    # System hourly load data
    if not os.path.exists(paths['outputs']['figures']['system_load']):
        df_system_load = pd.read_csv(paths['outputs']['system_load'])
        fig = mocot.viz.system_load(df_system_load)
        fig.savefig(paths['outputs']['figures']['system_load'])

    # System hourly load factors data
    if not os.path.exists(paths['outputs']['figures']['system_load_factor']):
        df_system_load = pd.read_csv(paths['outputs']['system_load'])
        fig = mocot.viz.system_load_factor(df_system_load)
        fig.savefig(paths['outputs']['figures']['system_load_factor'])

    # Node hour-to-hour load factors data
    if not os.path.exists(paths['outputs']['figures']['hour_node_load']):
        df_hour_to_hour = pd.read_csv(paths['outputs']['hour_to_hour'])
        fig = mocot.viz.hour_node_load(df_hour_to_hour)
        fig.savefig(paths['outputs']['figures']['hour_node_load'])

    # Node hourly load data
    if not os.path.exists(paths['outputs']['figures']['node_load']):
        df_node_load = pd.read_csv(paths['outputs']['node_load'])
        fig = mocot.viz.node_load(df_node_load)
        fig.savefig(paths['outputs']['figures']['node_load'])

    # Normal objective performances
    if not os.path.exists(paths['outputs']['figures']['normal_parallel']):
        df_objs = pd.read_csv(paths["outputs"]["objectives"])
        fig = mocot.viz.normal_parallel(df_objs)
        fig.savefig(paths['outputs']['figures']['normal_parallel'])

    # No nuclear objective Performances
    if not os.path.exists(paths['outputs']['figures']['no_nuclear_parallel']):
        df_objs = pd.read_csv(paths["outputs"]["objectives"])
        fig = mocot.viz.no_nuclear_parallel(df_objs)
        fig.savefig(paths['outputs']['figures']['no_nuclear_parallel'])

    # Normal generator output
    if not os.path.exists(paths['outputs']['figures']['normal_output']):
        df_states = pd.read_csv(paths["outputs"]["states"])
        df_gen_info = pd.read_csv(paths['outputs']['gen_info_main'])
        df_system_load = pd.read_csv(paths['outputs']['system_load'])
        fig = mocot.viz.normal_gen_timeseries(
            df_states,
            df_gen_info,
            df_system_load
        )
        fig.savefig(paths['outputs']['figures']['normal_output'])

    # No nuclear generator output
    if not os.path.exists(paths['outputs']['figures']['no_nuclear_output']):
        df_states = pd.read_csv(paths["outputs"]["states"])
        df_gen_info = pd.read_csv(paths['outputs']['gen_info_main'])
        df_system_load = pd.read_csv(paths['outputs']['system_load'])
        fig = mocot.viz.nonuclear_gen_timeseries(
            df_states,
            df_gen_info,
            df_system_load
        )
        fig.savefig(paths['outputs']['figures']['no_nuclear_output'])


if __name__ == '__main__':
    main()
