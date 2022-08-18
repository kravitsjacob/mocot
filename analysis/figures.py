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

    # Node hourly load data
    if not os.path.exists(paths['outputs']['figures']['node_load']):
        df_node_load = pd.read_csv(paths['outputs']['node_load'])
        fig = mocot.viz.node_load(df_node_load)
        fig.savefig(paths['outputs']['figures']['node_load'])

    # Generator output (no water weights)
    if not os.path.exists(paths['outputs']['figures']['no_water_weights']):
        df_gen_states = pd.read_csv(paths['outputs']['no_water_weights'])
        df_gen_info = pd.read_csv(paths['outputs']['gen_info_main'])
        df_system_load = pd.read_csv(paths['outputs']['system_load'])
        g = mocot.viz.gen_timeseries(
            df_gen_states,
            df_gen_info,
            df_system_load
        )
        g.savefig(paths['outputs']['figures']['no_water_weights'])

    # Generator output (withdrawal weight)
    if not os.path.exists(paths['outputs']['figures']['with_water_weights']):
        df_gen_states = pd.read_csv(paths['outputs']['with_water_weights'])
        df_gen_info = pd.read_csv(paths['outputs']['gen_info_main'])
        df_system_load = pd.read_csv(paths['outputs']['system_load'])
        g = mocot.viz.gen_timeseries(
            df_gen_states,
            df_gen_info,
            df_system_load
        )
        g.savefig(paths['outputs']['figures']['with_water_weights'])

    # Generator output (multi-weight)
    if not os.path.exists(paths['outputs']['figures']['multi_weights']):
        df_gen_no = pd.read_csv(paths['outputs']['no_water_weights'])
        df_gen_with = pd.read_csv(paths['outputs']['with_water_weights'])
        df_gen_info = pd.read_csv(paths['outputs']['gen_info_main'])
        df_system_load = pd.read_csv(paths['outputs']['system_load'])
        g = mocot.viz.multi_gen_timeseries(
            df_gen_no,
            df_gen_with,
            df_gen_info,
            df_system_load
        )
        g.savefig(paths['outputs']['figures']['multi_weights'])


if __name__ == '__main__':
    main()
