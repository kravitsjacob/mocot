"""Figure creation in python"""

import yaml
import os
import pandas as pd

import wc


def main():
    with open('analysis/paths.yml', 'r') as f:
        paths = yaml.safe_load(f)

    # Power simulation simulation inputs
    if not os.path.exists(paths['outputs']['loads']):
        df_load = pd.read_csv(paths['outputs']['df_load'])
        fig = wc.viz.loads(df_load)
        fig.savefig(paths['outputs']['loads'])

    # Power simulation simulation no ramping limits
    if not os.path.exists(paths['outputs']['gen_noramp']):
        df_gen_info_water = pd.read_csv(paths['outputs']['gen_info_water'])
        df_gen_pminfo = pd.read_csv(paths['outputs']['df_gen_pminfo'])
        df_gen = pd.read_csv(paths['outputs']['df_gen_noramp'])
        g = wc.viz.gen_timeseries(df_gen, df_gen_pminfo, df_gen_info_water)
        g.savefig(paths['outputs']['gen_noramp'])

    # Power simulation simulation with ramping limits
    if not os.path.exists(paths['outputs']['gen_ramp']):
        df_gen_info_water = pd.read_csv(paths['outputs']['gen_info_water'])
        df_gen_pminfo = pd.read_csv(paths['outputs']['df_gen_pminfo'])
        df_gen = pd.read_csv(paths['outputs']['df_gen_ramp'])
        g = wc.viz.gen_timeseries(df_gen, df_gen_pminfo, df_gen_info_water)
        g.savefig(paths['outputs']['gen_ramp'])


if __name__ == '__main__':
    main()
