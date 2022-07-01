"""Main analysis script"""


import configparser
import pandapower
import os
import pandas as pd

import wc


def input_parse():
    # Local vars
    config_inputs = configparser.ConfigParser()
    config_inputs.read('analysis/config.ini')

    # Paths for main io
    path_to_io = config_inputs['main']['io']

    # Paths for inputs
    matpowercase = os.path.join(
        path_to_io, config_inputs['inputs']['matpowercase']
    )
    geninfo = os.path.join(
        path_to_io, config_inputs['inputs']['geninfo']
    )
    gen_matches = os.path.join(
        path_to_io, config_inputs['inputs']['gen_matches']
    )
    eia_raw = os.path.join(
        path_to_io, config_inputs['inputs']['eia_raw']
    )
    eia_heat_rates = os.path.join(
        path_to_io, config_inputs['inputs']['eia_heat_rates']
    )

    # Paths for outputs
    case = os.path.join(path_to_io, config_inputs['outputs']['case'])
    case_match = os.path.join(
        path_to_io, config_inputs['outputs']['case_match']
    )
    eia = os.path.join(
        path_to_io, config_inputs['outputs']['eia']
    )
    eia_region = os.path.join(
        path_to_io, config_inputs['outputs']['eia_region']
    )
    gen_info_water = os.path.join(
        path_to_io, config_inputs['outputs']['gen_info_water']
    )

    # Store inputs
    paths = {
        'matpowercase': matpowercase,
        'geninfo': geninfo,
        'case': case,
        'gen_matches': gen_matches,
        'case_match': case_match,
        'eia_raw': eia_raw,
        'eia': eia,
        'eia_region': eia_region,
        'gen_info_water': gen_info_water,
        'eia_heat_rates': eia_heat_rates
    }

    return paths


def main():
    # Inputs
    paths = input_parse()

    # Setting up grid
    if not os.path.exists(paths['case']):
        net = pandapower.converter.from_mpc(paths['matpowercase'])
        df_gen_info = pd.read_csv(paths['geninfo'])
        net = wc.grid_setup(net, df_gen_info)
        pandapower.to_pickle(net, paths['case'])
        print('Success: grid_setup')

    # Manual synthetic to real generator matching
    if not os.path.exists(paths['case_match']):
        net = pandapower.from_pickle(paths['case'])
        df_gen_matches = pd.read_csv(paths['gen_matches'])
        net = wc.generator_match(net, df_gen_matches)
        pandapower.to_pickle(net, paths['case_match'])
        print('Success: generator_match')

    # Importing EIA data
    if not os.path.exists(paths['eia']):
        df_eia = wc.import_eia(paths['eia_raw'])
        df_eia.to_hdf(paths['eia'], key='df_eia', mode='w')
        print('Success: import_eia')

    # Synthetic grid cooling system information
    if not os.path.exists(paths['gen_info_water']):
        df_eia = pd.read_hdf(paths['eia'], 'df_eia')
        net = pandapower.from_pickle(paths['case_match'])
        df_gen_info = wc.network_to_gen_info(net)
        df_gen_info_water = wc.get_cooling_system(df_eia, df_gen_info)
        df_gen_info_water.to_csv(paths['gen_info_water'])
        print('Success: get_cooling_system')

    # Get regional (processed) EIA data
    if not os.path.exists(paths['eia_region']):
        df_eia = pd.read_hdf(paths['eia'], 'df_eia')
        df_eia_regional = wc.get_regional(df_eia)
        df_eia_regional.to_csv(paths['eia_region'])
        print('Success: get_regional')

    # Water use sensitivities
    df_gen_info_water = pd.read_csv(paths['gen_info_water'])
    df_eia_heat_rates = pd.read_excel(
        paths['eia_heat_rates'],
        skiprows=[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11],
        na_values=['Not Available', 'Not Applicable']
    )
    df_oc, df_rc = wc.water_use_sensitivies(
        df_gen_info_water,
        df_eia_heat_rates
    )
    wc.sensitivity(df_oc, df_rc)


if __name__ == '__main__':
    main()
