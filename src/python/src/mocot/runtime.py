# Borg runtime statistics

import pandas as pd
import numpy as np
from more_itertools import consecutive_groups


class BorgRuntimeDiagnostic:
    """
    Borg multi-objective algorithm runtime diagnostics
    """
    def __init__(
        self,
        path_to_runtime,
        decision_names,
        objective_names
    ):
        """
        Parsing runtime file and assigning parameters

        Parameters
        ----------
        path_to_runtime : str
            Path to Borg runtime file
        decision_names : list
            List of decision names
        objective_names : list
            List of objective names
        """
        # Read input file
        df_raw = pd.read_table(
            path_to_runtime,
            names=['var', 'value'],
            sep="="
        )

        # Runtime statistics
        df_res = parse_stats(
            df_raw
        )
        self.NFE = df_res['NFE'].tolist()
        self.archive_size = df_res['ArchiveSize'].to_dict()
        self.elapsed_time = df_res['ElapsedTime'].to_dict()
        self.improvements = df_res['Improvements'].to_dict()
        self.mutation_index = df_res['MutationIndex'].to_dict()
        self.population_size = df_res['PopulationSize'].to_dict()
        self.restarts = df_res['Restarts'].to_dict()
        self.PCX = df_res['PCX'].to_dict()
        self.DE = df_res['DE'].to_dict()
        self.SBX = df_res['SBX'].to_dict()
        self.SPX = df_res['SPX'].to_dict()
        self.UM = df_res['UM'].to_dict()
        self.UNDX = df_res['UNDX'].to_dict()

        # Parsing archives
        parameters_ls, objectives_ls = parse_archive(
            df_raw,
            decision_names,
            objective_names
        )
        self.decision_names = decision_names
        self.objective_names = objective_names
        self.archive_decisions = dict(zip(self.NFE, parameters_ls))
        self.archive_objectives = dict(zip(self.NFE, objectives_ls))


def parse_archive(df, decision_names, objective_names):
    """Convert archive data to dataframes

    Parameters
    ----------
    df : pandas.DataFrame
        Raw runtime pandas dataframe
    decision_names : list
        Decision names
    objective_names : list
        Objective names

    Returns
    -------
    pandas.DataFrame
        Processed archive
    """
    # Extract Archive Prints
    df_temp = df[np.isnan(df['value'])]
    df_temp = df_temp[df_temp['var'] != '#']

    # Separate Based on Deliminators
    df_temp = df_temp['var'].str.split(' ', expand=True).astype(float)
    df_temp.columns = decision_names + objective_names

    # Convert Negative Objectives to Positive Ones (Important for Hypervolume) TODO: makes this more generic in future versions  # noqa
    df_temp[df_temp.columns[df_temp.dtypes != np.object]] = \
        df_temp[df_temp.columns[df_temp.dtypes != np.object]].abs()

    # Create Lists of Lists
    df_temp['decisions'] = df_temp[decision_names].values.tolist()
    df_temp['objectives'] = df_temp[objective_names].values.tolist()

    # Decisions
    df_param = df_temp['decisions']
    parameters_ls = [
        df_param.loc[i].tolist()
        for i in consecutive_groups(df_param.index)
    ]

    # Objectives
    df_obj = df_temp['objectives']
    objectives_ls = [
        df_obj.loc[i].tolist()
        for i in consecutive_groups(df_obj.index)
    ]

    return parameters_ls, objectives_ls


def parse_stats(df_raw):
    """
    Convert Borg MOEA runtime file to pandas DataFrame

    Parameters
    ----------
    path : str
        Path to Borg MOEA runtime file
    decision_names : list
        Decision names
    objective_names : list
        Objective names

    Returns
    -------
    pandas.DataFrame
        Parsed runtime file
    """
    # Omit Population Prints
    df_res = df_raw[-np.isnan(df_raw['value'])]

    # Replace //
    df_res = pd.DataFrame(
        [df_res['var'].str.replace('//', ''), df_res['value']]
    ).T

    # Add index
    df_res['NFE_index'] = \
        [i for i in np.arange(0, len(df_res) // 13) for j in range(13)]

    # Parse Data Into Columns
    df_res = pd.pivot(
        df_res,
        columns='var',
        values='value',
        index='NFE_index'
    ).reset_index(drop=True)

    # Convert to Float
    df_res = df_res.astype(float)

    df_res.index = df_res['NFE']

    return df_res
