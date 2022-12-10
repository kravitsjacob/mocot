module MOCOT


import PowerModels
import JuMP
import DataFrames
import Statistics
import Ipopt
import Memento
import Dates
import CSV
import YAML


# Dev packages
import Infiltrator  # @Infiltrator.infiltrate

include("generator.jl")
include("waterpowermodel.jl")
include("simulation.jl")
include("utils.jl")
include("preprocessing.jl")

# include("daily.jl")
# include("hourly.jl")
# include("capacity_reduction.jl")


function borg_simulation_wrapper(
    w_with:: Float64=0.0,
    w_con:: Float64=0.0,
    w_emit:: Float64=0.0,
    return_type=1,
    verbose_level=1,
    scenario_code=1,
)
    """
    Simulation wrapper for borg multi-objective MOEA
    
    # Arguments
    - `w_with:: Float64`: Coal withdrawal weight [dollar/L]
    - `w_con:: Float64`: Coal consumption weight [dollar/L]
    - `w_emit:: Float64`: Emission withdrawal weight [dollar/lb]
    - `return_type:: Int64`: Return code. 1 is for standard Borg output. 2 is for returning states, objectives, and metrics
    - `verbose_level:: Int64`: Level of stdout printing. Default is 1. Less is 0.
    - `scenario_code:: Int64`: Scenario code. See update_scenario! for codes
    """
    # # Setup
    # objective_metric_array = Float64[]

    # # Setting verbose
    # logger = Memento.getlogger("PowerModels")
    # if verbose_level == 1
    #     Memento.setlevel!(logger, "info")
    # elseif verbose_level == 0
    #     Memento.setlevel!(logger, "error")
    # end

    # Import
    paths = YAML.load_file("paths.yml")
    (
        df_scenario_specs,
        df_eia_heat_rates,
        df_air_water,
        df_wind_cf,
        df_node_load,
        network_data,
        df_gen_info,
        decision_names,
        objective_names,
        metric_names
    ) = read_inputs(
        scenario_code,
        paths["inputs"]["scenario_specs"],
        paths["outputs"]["air_water_template"],
        paths["outputs"]["wind_capacity_factor_template"],
        paths["outputs"]["node_load_template"],       
        paths["outputs"]["gen_info_main"],
        paths["inputs"]["eia_heat_rates"],
        paths["inputs"]["case"],
        paths["inputs"]["decisions"],
        paths["inputs"]["objectives"],
        paths["inputs"]["metrics"],        
    )

    # Create model
    model = create_model_from_dataframes(
        network_data,
        scenario_code,
        df_gen_info,
        df_eia_heat_rates,
    )

    # Create simulation
    simulation = create_simulation_from_dataframes(
        model,
        scenario_code,
        df_scenario_specs,
        df_air_water,
        df_wind_cf,
        df_node_load,
    )

    # Run simulation
    (objectives, metrics, state) = run_simulation(
        simulation,
        w_with=w_with,
        w_con=w_con,
        w_emit= w_emit,
        verbose_level=verbose_level
    )

    # # Console feedback
    # decisions = Dict(
    #     "w_with" => w_with,
    #     "w_con" => w_con,
    #     "w_emit" => w_emit,
    # )
    # println("Scenario code: $scenario_code")
    # println(decisions)
    # println(objectives)
    # println(metrics)

    # if return_type == 1  # "borg"
    #     # Collect objectives
    #     for obj_name in objective_names
    #         append!(objective_metric_array, objectives[obj_name])
    #     end

    #     # Collect metrics
    #     for m_name in metric_names
    #         try
    #             append!(objective_metric_array, metrics[m_name])
    #         catch
    #             append!(objective_metric_array, 0.0)
    #         end
    #     end

    #     return objective_metric_array

    # elseif return_type == 2  # "all"

    #     return (objectives, state, metrics)

    # end
end


end # module
