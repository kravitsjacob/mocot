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

    # Interactive parallel plot
    if not os.path.exists(paths['outputs']['figures']['interactive_parallel']):
        objective_names = pd.read_csv(
            paths['inputs']['objectives']
        ).columns.tolist()
        decision_names = pd.read_csv(
            paths['inputs']['decisions']
        ).columns.tolist()
        df_front = pd.read_table(
            paths['outputs']['front'],
            sep=' ',
            names=decision_names+objective_names
        )
        exp = mocot.viz.interactive_parallel(df_front)
        exp.to_html(paths['outputs']['figures']['interactive_parallel'])

    # Runtime stats plots
    if not os.path.exists(paths['outputs']['figures']['progressarchiveratio']):
        objective_names = pd.read_csv(
            paths['inputs']['objectives']
        ).columns.tolist()
        decision_names = pd.read_csv(
            paths['inputs']['decisions']
        ).columns.tolist()
        df = mocot.core.runtime_to_df(
            paths['outputs']['runtime'], decision_names, objective_names
        )

        # Operators
        fig = mocot.viz.operator_plotter(df)
        fig.savefig(paths['outputs']['figures']['operator'])

        # Archive size and archive/population ratio
        fig = mocot.viz.progress_archive_size_pop_ratio_plotter(df)
        fig.savefig(
            paths['outputs']['figures']['progressarchiveratio']
        )


if __name__ == '__main__':
    main()
