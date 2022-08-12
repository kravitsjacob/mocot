"""Preprocessing python script"""


import pandapower
import os
import pandas as pd
import yaml

import mocot


def main():
    with open('analysis/paths.yml', 'r') as f:
        paths = yaml.safe_load(f)

    # Add generator information from MATPOWER to pandapower network
    if not os.path.exists(paths['outputs']['case']):
        net = pandapower.converter.from_mpc(paths['inputs']['case'])
        df_gen_info = pd.read_csv(paths['inputs']['gen_info'])
        net = mocot.core.grid_setup(net, df_gen_info)
        pandapower.to_pickle(net, paths['outputs']['case'])
        print('Success: grid_setup')

    # Manual synthetic to real generator matching
    if not os.path.exists(paths['outputs']['case_match']):
        net = pandapower.from_pickle(paths['outputs']['case'])
        df_gen_matches = pd.read_csv(paths['inputs']['gen_matches'])
        net = mocot.core.generator_match(net, df_gen_matches)
        pandapower.to_pickle(net, paths['outputs']['case_match'])
        print('Success: generator_match')

    # Add cooling systems to synthetic grid
    if not os.path.exists(paths['outputs']['gen_info_water']):
        df_eia = mocot.core.import_eia(paths['inputs']['eia_raw'])
        df_eia.to_hdf(paths['outputs']['eia'], key='df_eia', mode='w')
        print('Success: import_eia')
        net = pandapower.from_pickle(paths['outputs']['case_match'])
        df_gen_info = mocot.core.network_to_gen_info(net)
        df_gen_info_water = mocot.core.get_cooling_system(df_eia, df_gen_info)
        df_gen_info_water.to_csv(paths['outputs']['gen_info_water'])
        print('Success: get_cooling_system')

    # Water and air temperature
    if not os.path.exists(paths['outputs']['df_air_water']):
        df_air_water = mocot.core.process_exogenous(paths)
        df_air_water.to_csv(paths['outputs']['df_air_water'])

    # System-level loads
    if not os.path.exists(paths['outputs']['df_system_load']):
        df_miso = pd.read_csv(paths['inputs']['miso_load'])
        df_system_load = mocot.core.clean_system_load(df_miso)
        df_system_load.to_csv(paths['outputs']['df_system_load'])

    # Node-level loads
    if not os.path.exists(paths['outputs']['df_node_load']):
        net = pandapower.from_pickle(paths['outputs']['case_match'])
        df_system_load = pd.read_csv(
            paths['outputs']['df_system_load'],
            index_col=0
        )
        df_miso = pd.read_csv(paths['inputs']['miso_load'])
        df_node_load = mocot.core.create_node_load(df_system_load, df_miso, net)
        df_node_load.to_csv(paths['outputs']['df_node_load'])


if __name__ == '__main__':
    main()
