"""Hardcoded Visualization functions"""

import pandas as pd
import paxplot
import seaborn as sns
sns.reset_orig()


def average_parallel(runtime):
    """Summary plot for average scenario

    Parameters
    ----------
    runtime : postmocot.runtime.BorgRuntimeDiagnostic
        Runtime obeject for average scenario

    Returns
    -------
    paxplot.core.PaxFigure
        Plot
    """

    # Data preparation
    df = pd.DataFrame(
        runtime.archive_objectives[runtime.nfe[-1]],
        columns=runtime.objective_names
    )
    df = df.drop(columns=['f_ENS', 'f_disvi_tot', 'f_weight_tot'])
    df = df.rename(columns={
        'f_gen': 'Generation Cost [$]',
        'f_with_tot': 'Water Withdrawal [L]',
        'f_con_tot': 'Water Consumption [L]',
        'f_emit': 'Emissions [lbs]'
    })

    # Selecting a few solutions
    df_label = df.copy()
    df_label['label'] = ''
    df_label.at[df_label['Generation Cost [$]'].idxmin(), 'label'] = 'No Policy'  # noqa
    df_label.at[df_label['Emissions [lbs]'].idxmin(), 'label'] = 'Emissions-Only Policy'  # noqa
    df_label.at[df_label['Water Withdrawal [L]'].idxmin(), 'label'] = 'Withdrawal-Only Policy'  # noqa
    df_label.at[df_label['Water Consumption [L]'].idxmin(), 'label'] = 'Consumption-Only Policy'  # noqa
    idx_compromise = df_label.iloc[(df_label['Generation Cost [$]']-4644519).abs().argsort()[:1]].index[0]  # noqa
    df_label.at[idx_compromise, 'label'] = 'Informed Policy'
    df_label = df_label[df_label['label'] != '']

    # Plotting
    paxfig = paxplot.pax_parallel(n_axes=len(df.columns))
    paxfig.plot(df_label.loc[:, df_label.columns != 'label'].to_numpy())

    # Adding a colorbar
    paxfig.add_legend(labels=df_label['label'].tolist())
    paxfig.axes[-1].get_legend().set_bbox_to_anchor((1.50, 0.5))

    # Limits
    paxfig.set_ticks(
        ax_idx=0,
        ticks=[4e6, 5e6, 6e6, 7e6],
        labels=['4e6', '5e6', '6e6', '7e6']
    )
    paxfig.set_ticks(
        ax_idx=1,
        ticks=[0, 1e10, 2e10],
        labels=['0', '1e10', '2e10']
    )
    paxfig.set_ticks(
        ax_idx=2,
        ticks=[0, 1e8, 2e8, 3e8],
        labels=['0', '1e8', '2e8', '3e8']
    )
    paxfig.set_ticks(
        ax_idx=3,
        ticks=[0, 1e8, 2e8, 3e8],
        labels=['0', '1e8', '2e8', '3e8']
    )

    # Add labels
    paxfig.set_labels(df.columns)

    # Add remaining solutions
    paxfig.plot(
        df.to_numpy(),
        line_kwargs={'alpha': 0.5, 'color': 'grey', 'zorder': 0}
    )

    # Dimensions
    paxfig.set_size_inches(10, 3)

    return paxfig
