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

    # Paths for outputs
    case = os.path.join(path_to_io, config_inputs['outputs']['case'])
    case_match = os.path.join(
        path_to_io, config_inputs['outputs']['case_match']
    )
    eia = os.path.join(
        path_to_io, config_inputs['outputs']['eia']
    )

    # Store inputs
    paths = {
        'matpowercase': matpowercase,
        'geninfo': geninfo,
        'case': case,
        'gen_matches': gen_matches,
        'case_match': case_match,
        'eia_raw': eia_raw,
        'eia': eia
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
        print('Success: grid_setup')
        pandapower.to_pickle(net, paths['case'])

    # Manual synthetic to real generator matching
    if not os.path.exists(paths['case_match']):
        net = pandapower.from_pickle(paths['case'])
        df_gen_matches = pd.read_csv(paths['gen_matches'])
        net = wc.generator_match(net, df_gen_matches)
        print('Success: generator_match')
        pandapower.to_pickle(net, paths['case_match'])

    # Importing EIA data
    if not os.path.exists(paths['eia']):
        df_eia = wc.import_eia(paths['eia_raw'])
        print('Success: import_eia')
        df_eia.to_hdf(paths['eia'], key='df_eia', mode='w')

    # Get regional (processed) EIA data

    # Synthetic grid cooling system information

    # Assign generator cooling systems


if __name__ == '__main__':
    main()
