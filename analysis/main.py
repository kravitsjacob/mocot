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
    path_to_matpowercase = os.path.join(
        path_to_io, config_inputs['inputs']['matpowercase']
    )
    path_to_geninfo = os.path.join(
        path_to_io, config_inputs['inputs']['geninfo']
    )
    path_to_gen_matches = os.path.join(
        path_to_io, config_inputs['inputs']['gen_matches']
    )
    path_to_eia_raw = os.path.join(
        path_to_io, config_inputs['inputs']['eia_raw']
    )

    # Paths for outputs
    path_to_case = os.path.join(path_to_io, config_inputs['outputs']['case'])
    path_to_case_match = os.path.join(
        path_to_io, config_inputs['outputs']['case_match']
    )
    path_to_eia = os.path.join(
        path_to_io, config_inputs['outputs']['eia']
    )

    # Store inputs
    inputs = {
        'path_to_matpowercase': path_to_matpowercase,
        'path_to_geninfo': path_to_geninfo,
        'path_to_case': path_to_case,
        'path_to_gen_matches': path_to_gen_matches,
        'path_to_case_match': path_to_case_match,
        'path_to_eia_raw': path_to_eia_raw,
        'path_to_eia': path_to_eia
    }

    return inputs


def main():

    # Inputs
    inputs = input_parse()

    # Setting up grid
    if not os.path.exists(inputs['path_to_case']):
        net = pandapower.converter.from_mpc(inputs['path_to_matpowercase'])
        df_gen_info = pd.read_csv(inputs['path_to_geninfo'])
        net = wc.grid_setup(net, df_gen_info)
        print('Success: grid_setup')
        pandapower.to_pickle(net, inputs['path_to_case'])

    # Manual synthetic to real generator matching
    if not os.path.exists(inputs['path_to_case_match']):
        net = pandapower.from_pickle(inputs['path_to_case'])
        df_gen_matches = pd.read_csv(inputs['path_to_gen_matches'])
        net = wc.generator_match(net, df_gen_matches)
        print('Success: generator_match')
        pandapower.to_pickle(net, inputs['path_to_case_match'])

    # Importing EIA data
    if not os.path.exists(inputs['path_to_eia']):
        df_eia = wc.import_eia(inputs['path_to_eia_raw'])
        print('Success: import_eia')
        df_eia.to_hdf(inputs['path_to_eia'], key='df_eia', mode='w')

    # Get regional (processed) EIA data

    # Synthetic grid cooling system information

    # Assign generator cooling systems


if __name__ == '__main__':
    main()
