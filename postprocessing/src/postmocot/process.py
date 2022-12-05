
import pandas as pd
import numpy as np


def is_pareto_efficient(costs, return_mask=True):
    """Find the pareto-efficient points
    https://stackoverflow.com/questions/51397669/imports-inside-package-now-that-init-py-is-optional
    Parameters
    ----------
    costs : array
        An (n_points, n_costs) array
    return_mask : bool, optional
        Return index of points, by default True
    Returns
    -------
    array
        An array of indices of pareto-efficient points.
    """
    is_efficient = np.arange(costs.shape[0])
    n_points = costs.shape[0]
    next_point_index = 0  # Next index in the is_efficient array to search for
    while next_point_index < len(costs):
        nondominated_point_mask = np.any(
            costs < costs[next_point_index], axis=1
        )
        nondominated_point_mask[next_point_index] = True

        # Remove dominated points
        is_efficient = is_efficient[nondominated_point_mask]
        costs = costs[nondominated_point_mask]
        next_point_index = np.sum(nondominated_point_mask[:next_point_index])+1
    if return_mask:
        is_efficient_mask = np.zeros(n_points, dtype=bool)
        is_efficient_mask[is_efficient] = True
        return is_efficient_mask
    else:
        return is_efficient


def get_nondomintated(df, objs, max_objs=None):
    """
    Get nondominate filtered DataFrame
    Parameters
    ----------
    df: DataFrame
        DataFrame for nondomination
    objs: list
        List of strings correspond to column names of objectives
    max_objs: list (Optional)
        List of objective to maximize

    Returns
    -------
    df_nondom: DataFrame
        Nondominatated DataFrame
    """
    # Get flip maximum objectives
    df_temp = df.copy()
    try:
        df_temp[max_objs] = -1.0*df_temp[max_objs]
    except KeyError:
        pass

    # Nondominated sorting
    nondom_idx = is_pareto_efficient(df_temp[objs].values, return_mask=False)
    df_nondom = df.iloc[nondom_idx].reset_index(drop=True)

    return df_nondom


def select_policies(runtime, df_judement):
    """Select policies based on objective performance

    Parameters
    ----------
    runtime : postmocot.runtime.BorgRuntimeDiagnostic
        Runtime object
    df_judement : pandas.DataFrame
        Policies based on judgement

    Returns
    -------
    pandas.DataFrame
        Selected policies
    """
    # Build archive
    df_objs = pd.DataFrame(
        runtime.archive_objectives[runtime.nfe[-1]],
        columns=runtime.objective_names
    )
    df_decs = pd.DataFrame(
        runtime.archive_decisions[runtime.nfe[-1]],
        columns=runtime.decision_names
    )
    df = pd.concat([df_decs, df_objs], axis=1)

    # Extracting policies
    df['policy_label'] = ''
    idx_compromise = df.iloc[(df['f_gen']-5186066.459283395).abs().argsort()[:1]].index[0]  # noqa
    df.at[idx_compromise, 'policy_label'] = 'water-emission policy'
    df = df[df['policy_label'] != '']
    df = df[runtime.decision_names + ['policy_label']]

    # Making judgement solutions
    row = pd.DataFrame({
        'w_with': [0.0],
        'w_con': [0.0],
        'w_emit': [0.0],
        'policy_label': 'status quo'
    })
    df = pd.concat([df, row], axis=0)
    row = pd.DataFrame({
        'w_with': df_judement['w_with'],
        'w_con': [0.0],
        'w_emit': [0.0],
        'policy_label': 'high water withdrawal penalty'
    })
    df = pd.concat([df, row], axis=0)
    row = pd.DataFrame({
        'w_with': [0.0],
        'w_con': df_judement['w_con'],
        'w_emit': [0.0],
        'policy_label': 'high water consumption penalty'
    })
    df = pd.concat([df, row], axis=0)
    row = pd.DataFrame({
        'w_with': [0.0],
        'w_con': [0.0],
        'w_emit': df_judement['w_emit'],
        'policy_label': 'high emission penalty'
    })
    df = pd.concat([df, row], axis=0)
    return df
