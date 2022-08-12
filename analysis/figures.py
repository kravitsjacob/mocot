"""Figure creation in python"""

import yaml
import os
import pandas as pd

import mocot


def main():
    with open('analysis/paths.yml', 'r') as f:
        paths = yaml.safe_load(f)

    # Daily average air/water temperature
    if not os.path.exists(paths['outputs']['temperatures']):
        df_air_water = pd.read_csv(paths['outputs']['df_air_water'])
        fig = mocot.viz.temperatures(df_air_water)
        fig.savefig(paths['outputs']['temperatures'])

    # System hourly load data
    if not os.path.exists(paths['outputs']['system_load']):
        df_system_load = pd.read_csv(paths['outputs']['df_system_load'])
        fig = mocot.viz.system_load(df_system_load)
        fig.savefig(paths['outputs']['system_load'])

    # Node hourly load data
    if not os.path.exists(paths['outputs']['node_load']):
        df_node_load = pd.read_csv(paths['outputs']['df_node_load'])
        fig = mocot.viz.node_load(df_node_load)
        fig.savefig(paths['outputs']['node_load'])

    # Generator output (no water weights)
    if not os.path.exists(paths['outputs']['no_water_weights']):
        df_gen_states = pd.read_csv(paths['outputs']['df_no_water_weights'])
        df_gen_info_water = pd.read_csv(paths['outputs']['gen_info_water'])
        df_gen_info_pm = pd.read_csv(paths['outputs']['df_gen_info_pm'])
        df_node_load = pd.read_csv(paths['outputs']['df_node_load'])
        g = mocot.viz.gen_timeseries(
            df_gen_states,
            df_gen_info_water,
            df_gen_info_pm,
            df_node_load
        )
        g.savefig(paths['outputs']['no_water_weights'])
    
    # Generator output (withdrawal weight)
    if not os.path.exists(paths['outputs']['water_weights']):
        df_gen_states = pd.read_csv(paths['outputs']['df_water_weights'])
        df_gen_info_water = pd.read_csv(paths['outputs']['gen_info_water'])
        df_gen_info_pm = pd.read_csv(paths['outputs']['df_gen_info_pm'])
        df_node_load = pd.read_csv(paths['outputs']['df_node_load'])
        g = mocot.viz.gen_timeseries(
            df_gen_states,
            df_gen_info_water,
            df_gen_info_pm,
            df_node_load
        )
        g.savefig(paths['outputs']['water_weights'])


if __name__ == '__main__':
    main()
