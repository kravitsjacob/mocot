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

    # Interactive parallel plot 1
    if not os.path.exists(paths['outputs']['figures']['interactive_parallel_1']):
        objective_names = pd.read_csv(
            paths['inputs']['objectives']
        ).columns.tolist()
        decision_names = pd.read_csv(
            paths['inputs']['decisions']
        ).columns.tolist()
        df_front = pd.read_table(
            paths['outputs']['front_1'],
            sep=' ',
            names=decision_names+objective_names
        )
        exp = mocot.viz.interactive_parallel(df_front)
        exp.to_html(paths['outputs']['figures']['interactive_parallel_1'])

    # Interactive parallel plot 2
    if not os.path.exists(paths['outputs']['figures']['interactive_parallel_2']):
        objective_names = pd.read_csv(
            paths['inputs']['objectives']
        ).columns.tolist()
        decision_names = pd.read_csv(
            paths['inputs']['decisions']
        ).columns.tolist()
        df_front = pd.read_table(
            paths['outputs']['front_2'],
            sep=' ',
            names=decision_names+objective_names
        )
        exp = mocot.viz.interactive_parallel(df_front)
        exp.to_html(paths['outputs']['figures']['interactive_parallel_2'])

    # Runtime stats plots 1
    if not os.path.exists(paths['outputs']['figures']['improvements_1']):
        objective_names = pd.read_csv(
            paths['inputs']['objectives']
        ).columns.tolist()
        decision_names = pd.read_csv(
            paths['inputs']['decisions']
        ).columns.tolist()
        runtime = mocot.runtime.BorgRuntimeDiagnostic(
            paths['outputs']['runtime_1'],
            decision_names,
            objective_names
        )

        # Improvements
        if not os.path.exists(paths['outputs']['figures']['improvements_1']):
            fig = runtime.plot_improvements()
            fig.savefig(
                paths['outputs']['figures']['improvements_1']
            )

        # Hypervolume
        if not os.path.exists(paths['outputs']['figures']['hypervolume_1']):
            runtime.compute_hypervolume(
                reference_point=[1e12] * 9
            )
            fig = runtime.plot_hypervolume()
            fig.savefig(
                paths['outputs']['figures']['hypervolume_1']
            )

        # Front animation
        if not os.path.exists(paths['outputs']['figures']['front_animation_1']):
            runtime.plot_fronts(
                paths['outputs']['figures']['front_animation_dir']
            )
            # Requires imagemagick http://www.imagemagick.org/script/download.php  # noqa
            os.system("magick convert -delay 10 -loop 0 analysis/io/outputs/figures/front_animation/*.png {}".format(paths['outputs']['figures']['front_animation_1']))  # noqa

    # Runtime stats plots 2
    if not os.path.exists(paths['outputs']['figures']['improvements_2']):
        objective_names = pd.read_csv(
            paths['inputs']['objectives']
        ).columns.tolist()
        decision_names = pd.read_csv(
            paths['inputs']['decisions']
        ).columns.tolist()
        runtime = mocot.runtime.BorgRuntimeDiagnostic(
            paths['outputs']['runtime_2'],
            decision_names,
            objective_names
        )

        # Improvements
        if not os.path.exists(paths['outputs']['figures']['improvements_2']):
            fig = runtime.plot_improvements()
            fig.savefig(
                paths['outputs']['figures']['improvements_2']
            )

        # Hypervolume
        if not os.path.exists(paths['outputs']['figures']['hypervolume_2']):
            runtime.compute_hypervolume(
                reference_point=[1e12] * 9
            )
            fig = runtime.plot_hypervolume()
            fig.savefig(
                paths['outputs']['figures']['hypervolume_2']
            )

        # Front animation
        if not os.path.exists(paths['outputs']['figures']['front_animation_2']):
            runtime.plot_fronts(
                paths['outputs']['figures']['front_animation_dir']
            )
            # Requires imagemagick http://www.imagemagick.org/script/download.php  # noqa
            os.system("magick convert -delay 10 -loop 0 analysis/io/outputs/figures/front_animation/*.png {}".format(paths['outputs']['figures']['front_animation_2']))  # noqa


if __name__ == '__main__':
    main()
