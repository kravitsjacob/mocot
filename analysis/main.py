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

    # Paths for outputs
    path_to_case = os.path.join(path_to_io, config_inputs['outputs']['case'])

    # # Paths for manual_files
    # path_to_gen_matches = os.path.join(path_to_data, config_inputs['MANUAL FILES']['gen_matches'])
    # path_to_operational_scenarios = os.path.join(path_to_data, config_inputs['MANUAL FILES']['operational_scenarios'])

    # # Paths for figures/tables
    # path_to_figures = os.path.join(path_to_data, config_inputs['FIGURES']['figures'])
    # path_to_tables = os.path.join(path_to_data, config_inputs['FIGURES']['tables'])

    # # Paths for external Inputs
    # path_to_eia_raw = os.path.join(path_to_data, config_inputs['EXTERNAL INPUTS']['EIA_raw'])
    # path_to_load = os.path.join(path_to_data, config_inputs['EXTERNAL INPUTS']['load'])

    # # Paths for checkpoints
    # path_to_matpowercase = os.path.join(path_to_data, config_inputs['CHECKPOINTS']['matpowercase'])
    # path_to_geninfo = os.path.join(path_to_data, config_inputs['CHECKPOINTS']['geninfo'])

    # path_to_case_match = os.path.join(path_to_data, config_inputs['CHECKPOINTS']['case_match'])
    # path_to_case_match_water = os.path.join(path_to_data, config_inputs['CHECKPOINTS']['case_match_water'])
    # path_to_case_match_water_optimize = os.path.join(
    #     path_to_data, config_inputs['CHECKPOINTS']['case_match_water_optimize']
    # )
    # path_to_eia = os.path.join(path_to_data, config_inputs['CHECKPOINTS']['EIA'])
    # path_to_hnwc = os.path.join(path_to_data, config_inputs['CHECKPOINTS']['hnwc'])
    # path_to_uniform_sa = os.path.join(path_to_data, config_inputs['CHECKPOINTS']['uniform_sa'])
    # path_to_nonuniform_sa = os.path.join(path_to_data, config_inputs['CHECKPOINTS']['nonuniform_sa'])
    # path_to_nonuniform_sa_sobol = os.path.join(path_to_data, config_inputs['CHECKPOINTS']['nonuniform_sa_sobol'])

    # Store inputs
    inputs = {
        'path_to_matpowercase': path_to_matpowercase,
        'path_to_geninfo': path_to_geninfo,
        'path_to_case': path_to_case
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
        pandapower.to_pickle(net, inputs['path_to_case'])  # Save checkpoint

    # # Manual generator matching
    # if not os.path.exists(inputs['path_to_case_match']):
    #     net = pandapower.from_pickle(inputs['path_to_case'])  # Load previous checkpoint
    #     df_gen_matches = pd.read_csv(inputs['path_to_gen_matches'])
    #     net = analysis.generator_match(net, df_gen_matches)
    #     print('Success: generator_match')
    #     pandapower.to_pickle(net, inputs['path_to_case_match'])  # Save checkpoint

    # # Cooling system information
    # if not os.path.exists(inputs['path_to_case_match_water']):
    #     # Import EIA data
    #     if os.path.exists(inputs['path_to_eia']):
    #         df_eia = pd.read_hdf(inputs['path_to_eia'], 'df_eia')  # Load checkpoint
    #     else:
    #         df_eia = analysis.import_eia(inputs['path_to_eia_raw'])
    #         print('Success: import_eia')
    #         df_eia.to_hdf(inputs['path_to_eia'], key='df_eia', mode='w')  # Save checkpoint

    #     net = pandapower.from_pickle(inputs['path_to_case_match'])  # Load previous checkpoint
    #     net, df_hnwc, df_region, df_gen_info = analysis.cooling_system_information(net, df_eia)
    #     print('Success: cooling_system_information')
    #     pandapower.to_pickle(net, inputs['path_to_case_match_water'])  # Save checkpoint
    #     df_hnwc.to_csv(inputs['path_to_hnwc'], index=False)  # Save checkpoint
    



if __name__ == '__main__':
    main()
