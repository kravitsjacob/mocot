"""Main analysis script"""


import pandapower
import os
import pandas as pd
import yaml

import wc


def main():
    # Inputs
    with open('analysis/paths.yml', 'r') as f:
        paths = yaml.safe_load(f)

    # Add generator information from MATPOWER to pandapower network
    if not os.path.exists(paths['outputs']['case']):
        net = pandapower.converter.from_mpc(paths['inputs']['case'])
        df_gen_info = pd.read_csv(paths['inputs']['gen_info'])
        net = wc.core.grid_setup(net, df_gen_info)
        pandapower.to_pickle(net, paths['outputs']['case'])
        print('Success: grid_setup')

    # Manual synthetic to real generator matching
    if not os.path.exists(paths['outputs']['case_match']):
        net = pandapower.from_pickle(paths['outputs']['case'])
        df_gen_matches = pd.read_csv(paths['inputs']['gen_matches'])
        net = wc.core.generator_match(net, df_gen_matches)
        pandapower.to_pickle(net, paths['outputs']['case_match'])
        print('Success: generator_match')

    # Synthetic grid cooling system information
    if not os.path.exists(paths['outputs']['gen_info_water']):
        df_eia = wc.core.import_eia(paths['inputs']['eia_raw'])
        df_eia.to_hdf(paths['outputs']['eia'], key='df_eia', mode='w')
        print('Success: import_eia')
        net = pandapower.from_pickle(paths['outputs']['case_match'])
        df_gen_info = wc.core.network_to_gen_info(net)
        df_gen_info_water = wc.core.get_cooling_system(df_eia, df_gen_info)
        df_gen_info_water.to_csv(paths['outputs']['gen_info_water'])
        print('Success: get_cooling_system')

    # Power simulation simulation inputs
    if not os.path.exists(paths['outputs']['loads']):
        df_load = pd.read_csv(paths['outputs']['df_load'])
        fig = wc.loads(df_load)
        fig.savefig(paths['outputs']['loads'])

    # Power simulation simulation no ramping limits
    if not os.path.exists(paths['outputs']['gen_noramp']):
        df_gen_info_water = pd.read_csv(paths['outputs']['gen_info_water'])
        df_gen_pminfo = pd.read_csv(paths['outputs']['df_gen_pminfo'])
        df_gen = pd.read_csv(paths['outputs']['df_gen_noramp'])
        g = wc.gen_timeseries(df_gen, df_gen_pminfo, df_gen_info_water)
        g.savefig(paths['outputs']['gen_noramp'])

    # Power simulation simulation with ramping limits
    if not os.path.exists(paths['outputs']['gen_ramp']):
        df_gen_info_water = pd.read_csv(paths['outputs']['gen_info_water'])
        df_gen_pminfo = pd.read_csv(paths['outputs']['df_gen_pminfo'])
        df_gen = pd.read_csv(paths['outputs']['df_gen_ramp'])
        g = wc.gen_timeseries(df_gen, df_gen_pminfo, df_gen_info_water)
        g.savefig(paths['outputs']['gen_ramp'])


if __name__ == '__main__':
    main()
