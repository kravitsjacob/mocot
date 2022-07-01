"""Visualization Functions"""

import matplotlib.pyplot as plt
import seaborn as sns


def sensitivity(df_oc, df_rc):
    
    # Once-through
    df_oc_plot = df_oc
    df_oc_plot['Fuel/Cooling'] = \
        df_oc['Fuel Type'] + '/' + df_oc['Cooling System Type']
    df_oc_plot = df_oc.melt(
        value_vars=['Withdrawal Rate [L/MWh]', 'Consumption Rate [L/MWh]'],
        id_vars=['Change in Temperature [K]', 'Fuel/Cooling']
    )

    g_oc = sns.FacetGrid(
        df_oc_plot,
        row='variable',
        hue='Fuel/Cooling',
        sharex='col',
        sharey=False,
        aspect=2
    )
    g_oc.map(sns.lineplot, 'Change in Temperature [K]', 'value', marker='o',)
    g_oc.add_legend()
    g_oc.axes[0, 0].set_title(' ')
    g_oc.axes[0, 0].set_ylabel('Withdrawal Rate [L/MWh]')
    g_oc.axes[1, 0].set_title(' ')
    g_oc.axes[1, 0].set_ylabel('Consumption Rate [L/MWh]')
    g_oc.axes[1, 0].set_xlabel('Change in Water Temperature [C]')
    plt.show()

    # Recirculating
    a = 1

    return g_oc
