# Borg runtime statistics

import pandas as pd
import numpy as np
from more_itertools import consecutive_groups
import matplotlib.pyplot as plt
import seaborn as sns
import pygmo
import paxplot
import hiplot as hip
import os


class BorgRuntimeUtils:
    """
    Borg multi-objective algorithm runtime parsing utilities
    """
    def _parse_stats(self, df_raw):
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
        df_res['nfe_index'] = \
            [i for i in np.arange(0, len(df_res) // 13) for j in range(13)]

        # Parse Data Into Columns
        df_res = pd.pivot(
            df_res,
            columns='var',
            values='value',
            index='nfe_index'
        ).reset_index(drop=True)

        # Convert to Float
        df_res = df_res.astype(float)

        df_res.index = df_res['NFE'].astype(int)

        return df_res

    def _parse_archive(self, df, decision_names, objective_names):
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


class BorgRuntimeDiagnostic(BorgRuntimeUtils):
    """
    Borg multi-objective algorithm runtime diagnostics
    """
    def __init__(
        self,
        path_to_runtime,
        decision_names,
        objective_names,
        df_metrics,  # TODO update to add function
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
        df_metrics : pandas.DataFrame
            Dataframe of decisions and corresponding metrics
        """
        super().__init__()

        # Read input file
        df_raw = pd.read_table(
            path_to_runtime,
            names=['var', 'value'],
            sep="="
        )

        # General attributes
        self.decision_names = decision_names
        self.objective_names = objective_names
        self.metrics = df_metrics

        # Runtime statistics
        df_res = self._parse_stats(
            df_raw
        )
        self.nfe = df_res.index.to_list()
        self.archive_size = df_res['ArchiveSize'].to_dict()
        self.elapsed_time = df_res['ElapsedTime'].to_dict()
        self.improvements = df_res['Improvements'].to_dict()
        self.mutation_index = df_res['MutationIndex'].to_dict()
        self.population_size = df_res['PopulationSize'].to_dict()
        self.restarts = df_res['Restarts'].to_dict()
        self.pcx = df_res['PCX'].to_dict()
        self.de = df_res['DE'].to_dict()
        self.sbx = df_res['SBX'].to_dict()
        self.spx = df_res['SPX'].to_dict()
        self.um = df_res['UM'].to_dict()
        self.undx = df_res['UNDX'].to_dict()

        # Parsing archives
        parameters_ls, objectives_ls = self._parse_archive(
            df_raw,
            decision_names,
            objective_names
        )
        self.archive_decisions = dict(zip(self.nfe, parameters_ls))
        self.archive_objectives = dict(zip(self.nfe, objectives_ls))

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
        """
        Plot hypervolume over the search

        Returns
        -------
        matplotlib.figure.Figure
            Plot of improvments
        """
        # Get data
        df = pd.Series(self.hypervolume).to_frame().reset_index()

        # Plot
        fig = plt.figure()
        sns.lineplot(data=df, x='index', y=0)
        plt.ylabel('Hypervolume')
        plt.xlabel('Function Evaluations')

        return fig

    def plot_interactive_front(self):
        """
        Create interactive parallel plot

        Returns
        -------
        hiplot.experiment.Experiment
            Hiplot experiment
        """
        # Get final front
        nfe = self.nfe[-1]
        df_decs = pd.DataFrame(
            self.archive_decisions[nfe],
            columns=self.decision_names
        )
        df_objs = pd.DataFrame(
            self.archive_objectives[nfe],
            columns=self.objective_names
        )
        df_front = pd.concat([df_decs, df_objs], axis=1)

        # Create Plot
        cols = self.decision_names+self.objective_names
        cols.reverse()
        color_col = self.objective_names[0]
        exp = hip.Experiment.from_dataframe(df_front)
        exp.parameters_definition[color_col].colormap = 'interpolateViridis'
        exp.display_data(hip.Displays.PARALLEL_PLOT).update(
            {'order': cols}
        )
        exp.display_data(hip.Displays.TABLE).update(
            {'hide': ['uid', 'from_uid']}
        )

        return exp

    def plot_fronts(self, path_to_save_figs_dir='temp_animation'):
        """Create front images as save to directory for animation later.

        #TODO, this is hardcoded for a specific example

        Parameters
        ----------
        path_to_save_figs_dir : str
            Directory to save generated front figs
        """
        # Setup
        if not os.path.exists(path_to_save_figs_dir):
            os.makedirs(path_to_save_figs_dir)
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
            paxfig.axes[0].set_title('nfe: {}'.format(nfe))

            # Dimensions
            paxfig.set_size_inches(13, 3)

            # Save
            file_name = 'nfe_{}.png'.format(str(nfe).zfill(8))
            paxfig.savefig(
                os.path.join(path_to_save_figs_dir, file_name)
            )

            # Close figures
            plt.close()


class BorgRuntimeAggregator():
    """
    Agregate multiple runs of borg multi-objective algorithm runtime objects
    """
    def __init__(
        self,
        runtime_objs,
    ):
        """Initilization

        Parameters
        ----------
        runtime_objs : dict
            Dictionary with keys of run name and values being runtime
             objects
        """
        self.runs = runtime_objs

    def plot_hypervolume(self):
        """
        Plot hypervolume over the search

        Returns
        -------
        matplotlib.figure.Figure
            Plot of improvments
        """
        # Setup
        df_ls = []

        # Computing hypervolume
        for run_name, run_obj in self.runs.items():
            df_run = pd.DataFrame()
            reference_point = [1e12] * 9
            run_obj.compute_hypervolume(reference_point)
            df_run['hypervolume'] = pd.Series(run_obj.hypervolume)
            df_run['run_name'] = run_name
            df_run['nfe'] = df_run.index
            df_ls.append(df_run)
        df = pd.concat(df_ls)

        # Plotting
        fig, ax = plt.subplots()
        sns.lineplot(data=df, x='nfe', y='hypervolume', hue='run_name', ax=ax)
        plt.ylabel('Hypervolume')
        plt.xlabel('Function Evaluations')
        ax.legend(title='Run')

        return fig

    def plot_interactive_front(self):
        """
        Plot interactive front at final search

        Returns
        -------
        matplotlib.figure.Figure
            Plot of improvments
        """
        # Setup
        df_ls = []

        for run_name, run_obj in self.runs.items():
            # Extract total function evaluations
            nfe = run_obj.nfe[-1]

            # Get front
            df_decs = pd.DataFrame(
                run_obj.archive_decisions[nfe],
                columns=run_obj.decision_names
            )
            df_objs = pd.DataFrame(
                run_obj.archive_objectives[nfe],
                columns=run_obj.objective_names
            )
            df_front = pd.concat([df_decs, df_objs], axis=1)
            df_front['run_name'] = run_name

            # Get metrics
            df_front = pd.merge(
                df_front.round(8),
                run_obj.metrics.drop_duplicates().round(8),
                how='left'
            )

            # Store
            df_ls.append(df_front)

        # Making parent dataframe
        df = pd.concat(df_ls)

        # Create Plot
        cols = run_obj.decision_names + run_obj.objective_names + ['run_name']
        cols.reverse()
        color_col = 'run_name'
        exp = hip.Experiment.from_dataframe(df)
        exp.parameters_definition[color_col].colormap = 'schemeDark2'
        exp.display_data(hip.Displays.PARALLEL_PLOT).update(
            {'order': cols}
        )
        exp.display_data(hip.Displays.TABLE).update(
            {'hide': ['uid', 'from_uid']}
        )

        return exp
