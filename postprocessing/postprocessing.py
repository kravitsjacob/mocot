"""Figure creation in python"""

import yaml
import os
import pandas as pd

import postmocot


def main():
    with open('paths.yml', 'r') as f:
        paths = yaml.safe_load(f)

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

    # Runtime stats plots

    objective_names = pd.read_csv(
        paths['inputs']['objectives']
    ).columns.tolist()
    decision_names = pd.read_csv(
        paths['inputs']['decisions']
    ).columns.tolist()
    scenario_code = '1'
    path = paths['outputs']['runtime_template'].replace(
        '0', scenario_code
    )
    runtime = postmocot.runtime.BorgRuntimeDiagnostic(
        path,
        decision_names,
        objective_names
    )

    # Interactive parallel
    if not os.path.exists(paths['outputs']['figures']['interactive_parallel']):
        exp = runtime.plot_interactive_front()
        exp.to_html(paths['outputs']['figures']['interactive_parallel'])

    # Improvements
    if not os.path.exists(paths['outputs']['figures']['improvements']):
        fig = runtime.plot_improvements()
        fig.savefig(
            paths['outputs']['figures']['improvements']
        )

    # Hypervolume
    if not os.path.exists(paths['outputs']['figures']['hypervolume']):
        runtime.compute_hypervolume(
            reference_point=[1e12] * 9
        )
        fig = runtime.plot_hypervolume()
        fig.savefig(
            paths['outputs']['figures']['hypervolume']
        )

    # Front animation
    if not os.path.exists(
        paths['outputs']['figures']['front_animation']
    ):
        runtime.plot_fronts('temp')
        # Requires imagemagick http://www.imagemagick.org/script/download.php  # noqa
        os.system("magick convert -delay 10 -loop 0 temp/*.png {}".format(paths['outputs']['figures']['front_animation']))  # noqa


if __name__ == '__main__':
    main()
