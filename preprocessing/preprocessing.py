"""Preprocessing python script"""


import pandapower
import os
import pandas as pd
import yaml

import premocot


def main():
    with open('paths.yml', 'r') as f:
        paths = yaml.safe_load(f)

    # Generator cooling systems information
    if not os.path.exists(paths['outputs']['gen_info_water']):
        # Generator information from previous study
        df_gen_info_matpower = pd.read_csv(
            paths['inputs']['gen_info_matpower']
        )
        df_gen_info_matches = pd.read_csv(paths['inputs']['gen_info_matches'])
        df_gen_info = pd.merge(df_gen_info_matpower, df_gen_info_matches)

        # Import EIA data
        df_eia = premocot.core.import_eia(paths['inputs']['eia_raw'])
        print('Success: import_eia')

        # Add cooling system information
        df_gen_info_water = premocot.core.get_cooling_system(
            df_eia, df_gen_info
        )
        df_gen_info_water.to_csv(
            paths['outputs']['gen_info_water'],
            index=False
        )
        print('Success: get_cooling_system')

    # Add ramping information
    if not os.path.exists(paths['outputs']['gen_info_water_ramp']):
        df_gen_info_ramp = pd.read_excel(paths['inputs']['gen_info_ramp'])
        df_gen_info_water = pd.read_csv(paths['outputs']['gen_info_water'])
        df_gen_info_water_ramp = pd.merge(
            left=df_gen_info_water,
            right=df_gen_info_ramp
        )
        drop_cols = [
            'Match Type',
            'Source'
        ]
        df_gen_info_water_ramp = df_gen_info_water_ramp.drop(drop_cols, axis=1)

        # Anonymous plant names
        powerworld_plants = \
            df_gen_info_water_ramp['POWERWORLD Plant Name'].unique()
        anonymous_plants = \
            [f'Plant {i}' for i in range(1, len(powerworld_plants) + 1)]
        d = dict(zip(powerworld_plants, anonymous_plants))
        df_gen_info_water_ramp['Plant Name'] = \
            df_gen_info_water_ramp['POWERWORLD Plant Name'].map(d)

        df_gen_info_water_ramp.to_csv(
            paths['outputs']['gen_info_water_ramp'],
            index=False
        )
        print('Success: Adding ramping information')

    # Add emission coefficients
    if not os.path.exists(paths['outputs']['gen_info_water_ramp_emit']):
        df_gen_info_water_ramp = pd.read_csv(
            paths['outputs']['gen_info_water_ramp'],
        )
        df_gen_info_emit = pd.read_csv(paths['inputs']['gen_info_emit'])
        df_gen_info_water_ramp_emit = pd.merge(
            df_gen_info_water_ramp,
            df_gen_info_emit,
        )
        df_gen_info_water_ramp_emit['Emission Rate lbs per MWh'] = \
            df_gen_info_water_ramp_emit['Emission Rate lbs per kWh']/1000.0
        df_gen_info_water_ramp_emit.to_csv(
            paths['outputs']['gen_info_water_ramp_emit'],
            index=False
        )
        print('Success: Adding emission information')

    # Add emission coefficients
    if not os.path.exists(
        paths['outputs']['gen_info_water_ramp_emit_waterlim']
    ):
        df_gen_info_water_ramp_emit = pd.read_csv(
            paths['outputs']['gen_info_water_ramp_emit']
        )
        df_gen_info_waterlim = pd.read_csv(
            paths['inputs']['gen_info_waterlim']
        )
        df_gen_info_water_ramp_emit_waterlim = pd.merge(
            df_gen_info_water_ramp_emit,
            df_gen_info_waterlim,
            how='left'
        )
        df_gen_info_water_ramp_emit_waterlim.to_csv(
            paths['outputs']['gen_info_water_ramp_emit_waterlim'],
            index=False
        )
        print('Success: Adding water use limits')

    # Water temperature
    if not os.path.exists(paths['outputs']['water_temperature']):
        df_water = premocot.core.process_water_exogenous()
        df_water.to_csv(paths['outputs']['water_temperature'], index=False)

    # System-level loads
    if not os.path.exists(paths['outputs']['system_load']):
        df_miso = pd.read_csv(paths['inputs']['miso_load'])
        df_system_load = premocot.core.process_system_load(
            df_miso
        )
        df_system_load.to_csv(paths['outputs']['system_load'], index=False)

    # Node-level loads
    if not os.path.exists(paths['outputs']['node_load']):
        net = pandapower.converter.from_mpc(paths['inputs']['case'])
        df_system_load = pd.read_csv(paths['outputs']['system_load'])
        df_synthetic_node_loads = pd.read_csv(
            paths['inputs']['synthetic_node_loads'],
            header=1,
            low_memory=False
        )
        df_node_load, df_hour_to_hour = premocot.core.process_node_load(
            df_system_load, df_synthetic_node_loads, net
        )
        df_hour_to_hour.to_csv(paths['outputs']['hour_to_hour'], index=False)
        df_node_load.to_csv(paths['outputs']['node_load'], index=False)


if __name__ == '__main__':
    main()
