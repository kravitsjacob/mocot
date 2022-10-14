"""Preprocessing python script"""


import pandapower
import os
import pandas as pd
import yaml
import datetime

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

    # Air temperature
    if not os.path.exists(paths['outputs']['air_temperature']):
        df_air = premocot.core.process_air_exogenous(
            paths['inputs']['air_temperature_dir']
        )
        df_air.to_csv(paths['outputs']['air_temperature'], index=False)

    # System-level loads
    if not os.path.exists(paths['outputs']['system_load']):
        df_system_load = premocot.core.process_system_load(
            paths['inputs']['eia_load_template_j_j'],
            paths['inputs']['eia_load_template_j_d']
        )
        df_system_load.to_csv(paths['outputs']['system_load'], index=False)

    # Hour-to-hour loads
    if not os.path.exists(paths['outputs']['hour_to_hour']):
        net = pandapower.converter.from_mpc(paths['inputs']['case'])
        df_synthetic_node_loads = pd.read_csv(
            paths['inputs']['synthetic_node_loads'],
            header=1,
            low_memory=False
        )
        df_hour_to_hour = premocot.core.process_hour_to_hour(
            df_synthetic_node_loads,
            net
        )
        df_hour_to_hour.to_csv(paths['outputs']['hour_to_hour'], index=False)

    # Exogenous scenario
    print_dates = 0
    if print_dates:
        df_water = pd.read_csv(paths['outputs']['water_temperature'])
        df_air = pd.read_csv(paths['outputs']['air_temperature'])
        df_system_load = pd.read_csv(paths['outputs']['system_load'])
        premocot.core.scenario_dates(df_water, df_air, df_system_load)

    # Generate exogenous inputs for each scenario
    generate = 0
    if generate:
        df_water = pd.read_csv(paths['outputs']['water_temperature'])
        df_air = pd.read_csv(paths['outputs']['air_temperature'])
        df_system_load = pd.read_csv(paths['outputs']['system_load'])
        df_hour_to_hour = pd.read_csv(paths['outputs']['hour_to_hour'])
        df_scenario_specs = pd.read_csv(paths['inputs']['scenario_specs'])
        net = pandapower.converter.from_mpc(paths['inputs']['case'])

        for (_, row) in df_scenario_specs.iterrows():
            # Process
            df_air_water, df_node_load = premocot.core.create_scenario_exogenous(  # noqa
                row['scenario_code'],
                pd.to_datetime(row['datetime_start']),
                pd.to_datetime(row['datetime_end']),
                df_water,
                df_air,
                df_system_load,
                df_hour_to_hour,
                net
            )

            if row['scenario_code'] == 6:
                data_cols = ['air_temperature', 'water_temperature']
                df_air_water[data_cols] = df_air_water[data_cols] * 1.15
                df_node_load['load_mw'] = df_node_load['load_mw'] * 1.15

            # Write
            path_to_air_water = paths['outputs']['air_water_template'].replace(
                '0', str(row['scenario_code'])
            )
            df_air_water.to_csv(path_to_air_water, index=False)
            path_to_node_load = paths['outputs']['node_load_template'].replace(
                '0', str(row['scenario_code'])
            )
            df_node_load.to_csv(path_to_node_load, index=False)

    # Scenario temperature figures
    if not os.path.exists(paths['outputs']['figures']['scenario_temperatures']):  # noqa
        # Import data
        multi_air_water = {}
        df_scenario_specs = pd.read_csv(paths['inputs']['scenario_specs'])
        for (_, row) in df_scenario_specs.iterrows():
            # Import files
            path_to_air_water = paths['outputs']['air_water_template'].replace(
                '0', str(row['scenario_code'])
            )
            df_air_water = pd.read_csv(path_to_air_water)

            # Store
            multi_air_water[row['name']] = df_air_water

        # Plot
        fig = premocot.viz.scenario_temperatures(multi_air_water)
        fig.savefig(paths['outputs']['figures']['scenario_temperatures'])

    # Scenario load figures
    if not os.path.exists(paths['outputs']['figures']['scenario_loads']):  # noqa
        # Import data
        multi_node_load = {}
        df_scenario_specs = pd.read_csv(paths['inputs']['scenario_specs'])
        for (_, row) in df_scenario_specs.iterrows():
            # Import files
            path_to_load = paths['outputs']['node_load_template'].replace(
                '0', str(row['scenario_code'])
            )
            df_node_load = pd.read_csv(path_to_load)

            # Store
            multi_node_load[row['name']] = df_node_load

        # Plot
        fig = premocot.viz.scenario_node_load(multi_node_load)
        fig.savefig(paths['outputs']['figures']['scenario_loads'])

    # Example figures (not connected to actual scenarios)
    # # Daily average air/water temperature
    if not os.path.exists(paths['outputs']['figures']['temperatures']):
        df_water = pd.read_csv(paths['outputs']['water_temperature'])
        df_air = pd.read_csv(paths['outputs']['air_temperature'])
        fig = premocot.viz.temperatures(df_water, df_air)
        fig.savefig(paths['outputs']['figures']['temperatures'])

    # # System hourly load data
    if not os.path.exists(paths['outputs']['figures']['system_load']):
        df_system_load = pd.read_csv(paths['outputs']['system_load'])
        fig = premocot.viz.system_load(df_system_load)
        fig.savefig(paths['outputs']['figures']['system_load'])

    # # System hourly load factors data
    if not os.path.exists(paths['outputs']['figures']['system_load_factor']):
        df_system_load = pd.read_csv(paths['outputs']['system_load'])
        fig = premocot.viz.system_load_factor(df_system_load)
        fig.savefig(paths['outputs']['figures']['system_load_factor'])

    # # Node hour-to-hour load factors data
    if not os.path.exists(paths['outputs']['figures']['hour_node_load']):
        df_hour_to_hour = pd.read_csv(paths['outputs']['hour_to_hour'])
        fig = premocot.viz.hour_node_load(df_hour_to_hour)
        fig.savefig(paths['outputs']['figures']['hour_node_load'])

    # # Node hourly load data
    if not os.path.exists(paths['outputs']['figures']['node_load']):
        df_water = pd.read_csv(paths['outputs']['water_temperature'])
        df_air = pd.read_csv(paths['outputs']['air_temperature'])
        df_system_load = pd.read_csv(paths['outputs']['system_load'])
        df_hour_to_hour = pd.read_csv(paths['outputs']['hour_to_hour'])
        net = pandapower.converter.from_mpc(paths['inputs']['case'])
        df_air_water, df_node_load = premocot.core.create_scenario_exogenous(
            row['scenario_code'],
            datetime.datetime(2019, 7, 1),
            datetime.datetime(2019, 7, 7),
            df_water,
            df_air,
            df_system_load,
            df_hour_to_hour,
            net
        )
        fig = premocot.viz.node_load(df_node_load)
        fig.savefig(paths['outputs']['figures']['node_load'])


if __name__ == '__main__':
    main()
