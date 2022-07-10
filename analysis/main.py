"""Main analysis script"""


import configparser
import pandapower
import os
import pandas as pd

import wc


def main():
    # Inputs
    paths = configparser.ConfigParser()
    paths.read('analysis/config.ini')

    # Setting up grid
    if not os.path.exists(paths['outputs']['case']):
        net = pandapower.converter.from_mpc(paths['inputs']['matpowercase'])
        df_gen_info = pd.read_csv(paths['inputs']['geninfo'])
        net = wc.grid_setup(net, df_gen_info)
        pandapower.to_pickle(net, paths['outputs']['case'])
        print('Success: grid_setup')

    # Manual synthetic to real generator matching
    if not os.path.exists(paths['outputs']['case_match']):
        net = pandapower.from_pickle(paths['outputs']['case'])
        df_gen_matches = pd.read_csv(paths['inputs']['gen_matches'])
        net = wc.generator_match(net, df_gen_matches)
        pandapower.to_pickle(net, paths['outputs']['case_match'])
        print('Success: generator_match')

    # Importing EIA data
    if not os.path.exists(paths['outputs']['eia']):
        df_eia = wc.import_eia(paths['inputs']['eia_raw'])
        df_eia.to_hdf(paths['outputs']['eia'], key='df_eia', mode='w')
        print('Success: import_eia')

    # Synthetic grid cooling system information
    if not os.path.exists(paths['outputs']['gen_info_water']):
        df_eia = pd.read_hdf(paths['outputs']['eia'], 'df_eia')
        net = pandapower.from_pickle(paths['outputs']['case_match'])
        df_gen_info = wc.network_to_gen_info(net)
        df_gen_info_water = wc.get_cooling_system(df_eia, df_gen_info)
        df_gen_info_water.to_csv(paths['outputs']['gen_info_water'])
        print('Success: get_cooling_system')

    # Get regional (processed) EIA data
    if not os.path.exists(paths['outputs']['eia_region']):
        df_eia = pd.read_hdf(paths['outputs']['eia'], 'df_eia')
        df_eia_regional = wc.get_regional(df_eia)
        df_eia_regional.to_csv(paths['outputs']['eia_region'])
        print('Success: get_regional')

    # Water use sensitivities
    if not os.path.exists(paths['outputs']['rc_sensitivity']):
        df_gen_info_water = pd.read_csv(paths['outputs']['gen_info_water'])
        df_eia_heat_rates = pd.read_excel(
            paths['inputs']['eia_heat_rates'],
            skiprows=[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11],
            na_values=['Not Available', 'Not Applicable']
        )
        df_oc, df_rc = wc.water_use_sensitivies(
            df_gen_info_water,
            df_eia_heat_rates
        )
        g_oc, g_rc = wc.sensitivity(df_oc, df_rc)
        g_oc.savefig(paths['outputs']['oc_sensitivity'])
        g_rc.savefig(paths['outputs']['rc_sensitivity'])
        print('Success: water_use_sensitivies')

    df_exogenous = wc.process_exogenous(paths)
    fig = wc.raw_exogenous(df_exogenous)
    fig.savefig(paths['outputs']['raw_exogenous'])
    print('Success: raw_exogenous')


if __name__ == '__main__':
    main()
