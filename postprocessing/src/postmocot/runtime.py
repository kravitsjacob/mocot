# Borg runtime statistics

import pandas as pd
import numpy as np
from more_itertools import consecutive_groups
import matplotlib.pyplot as plt
import seaborn as sns
import pygmo
import paxplot
import os


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

    def compute_hypervolume(self, reference_point):
        """Compute hypervolumes

        Parameters
        ----------
        reference_point : list
            Reference point for hypervolume calculation. Length must be same
             as objectives
        """
        # Setup
        hypervolume_dict = {}

        for nfe, objs in self.archive_objectives.items():
            # Compute hypervolume
            hv = pygmo.hypervolume(objs)
            hv_val = hv.compute(ref_point=reference_point)

            # Store value
            hypervolume_dict[nfe] = hv_val

        self.hypervolume = hypervolume_dict

    def plot_improvements(self):
        """
        Plot improvments over the search

        Returns
        -------
        matplotlib.figure.Figure
            Plot of improvments
        """
        # Get data
        df = pd.Series(self.improvements).to_frame().reset_index()

        # Plot
        fig = plt.figure()
        sns.lineplot(data=df, x='index', y=0)
        plt.ylabel('Improvments')
        plt.xlabel('Function Evaluations')

        return fig

    def plot_hypervolume(self):
        # Get data
        df = pd.Series(self.hypervolume).to_frame().reset_index()

        # Plot
        fig = plt.figure()
        sns.lineplot(data=df, x='index', y=0)
        plt.ylabel('Hypervolume')
        plt.xlabel('Function Evaluations')

        return fig

    def plot_fronts(self, path_to_save_figs_dir):
        """Create front images as save to directory for animation later.

        #TODO, this is hardcoded for a specific example

        Parameters
        ----------
        path_to_save_figs_dir : str
            Directory to save generated front figs
        """
        # Setup
        sns.reset_orig()

        for nfe, objs in self.archive_objectives.items():
            # Plotting
            paxfig = paxplot.pax_parallel(n_axes=len(objs[0]))
            paxfig.plot(objs)

            # Adding a colorbar
            color_col = 0
            paxfig.add_colorbar(
                ax_idx=color_col,
                cmap='viridis',
                colorbar_kwargs={'label': self.objective_names[color_col]}
            )

            # Limits
            paxfig.set_even_ticks(
                ax_idx=0, n_ticks=5, minimum=0.0, maximum=1e7
            )
            paxfig.set_even_ticks(
                ax_idx=1, n_ticks=5, minimum=0.0, maximum=1e9
            )
            paxfig.set_even_ticks(
                ax_idx=2, n_ticks=5, minimum=0.0, maximum=1e9
            )
            paxfig.set_even_ticks(
                ax_idx=3, n_ticks=5, minimum=0.0, maximum=1e8
            )
            paxfig.set_even_ticks(
                ax_idx=4, n_ticks=5, minimum=0.0, maximum=1e10
            )
            paxfig.set_even_ticks(
                ax_idx=5, n_ticks=5, minimum=0.0, maximum=1e9
            )
            paxfig.set_even_ticks(
                ax_idx=7, n_ticks=5, minimum=0.0, maximum=3e2
            )
            paxfig.set_even_ticks(
                ax_idx=8, n_ticks=5, minimum=0.0, maximum=1e0
            )

            # Add labels
            paxfig.set_labels(self.objective_names)
            paxfig.axes[0].set_title('NFE: {}'.format(nfe))

            # Dimensions
            paxfig.set_size_inches(13, 3)

            # Save
            file_name = 'NFE_{}.png'.format(str(nfe).zfill(8))
            paxfig.savefig(
                os.path.join(path_to_save_figs_dir, file_name)
            )

            # Close figures
            plt.close()


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
