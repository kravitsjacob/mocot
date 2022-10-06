import Dates
import CSV
import YAML
import PowerModels
import Memento

import MOCOT

# Dev packages
import Infiltrator  # @Infiltrator.infiltrate

include("preprocessing.jl")


function borg_simulation_wrapper(
    w_with_coal:: Float64=0.0,
    w_con_coal:: Float64=0.0,
    w_with_ng:: Float64=0.0,
    w_con_ng:: Float64=0.0,
    w_with_nuc:: Float64=0.0,
    w_con_nuc:: Float64=0.0,
    output_type=1,
    verbose_level=1,
    scenario_code=1,
)
    """
    Simulation wrapper for borg multi-objective MOEA
    
    # Arguments
    - `w_with_coal:: Float64`: Coal withdrawal weight
    - `w_con_coal:: Float64`: Coal consumption weight
    - `w_with_ng:: Float64`: Natural gas withdrawal weight
    - `w_con_ng:: Float64`: Natural gas consumption weight
    - `w_with_nuc:: Float64`: Nuclear withdrawal weight
    - `w_con_nuc:: Float64`: Nuclear consumption weight
    - `output_type:: Int64`: Return code. 1 is for standard Borg output. 2 is for returning states and objectives
    - `verbose_level:: Int64`: Level of stdout printing. Default is 1. Less is 0.
    - `scenario_code:: Int64`: Scenario code. See update_scenario! for codes
    """
    # Setup
    objective_array = Float64[]

    # Setting verbose
    logger = Memento.getlogger("PowerModels")
    if verbose_level == 1
        Memento.setlevel!(logger, "info")
    elseif verbose_level == 0
        Memento.setlevel!(logger, "error")
    end

    # Import
    paths = YAML.load_file("paths.yml")
    (
        df_scenario_specs,
        df_eia_heat_rates,
        df_air_water,
        df_node_load,
        network_data,
        df_gen_info,
        decision_names,
        objective_names
    ) = MOCOT.read_inputs(
        scenario_code,
        paths["inputs"]["scenario_specs"],
        paths["outputs"]["air_water_template"],
        paths["outputs"]["node_load_template"],       
        paths["outputs"]["gen_info_water_ramp_emit_waterlim"],
        paths["inputs"]["eia_heat_rates"],
        paths["inputs"]["case"],
        paths["inputs"]["decisions"],
        paths["inputs"]["objectives"],
    )

    # Preparing network
    network_data = MOCOT.add_custom_properties!(network_data, df_gen_info, df_eia_heat_rates)

    # Exogenous parameters
    specs = df_scenario_specs[df_scenario_specs.scenario_code .== scenario_code, :]
    start_date = specs.datetime_start[1]
    end_date = specs.datetime_end[1]
    exogenous = MOCOT.get_exogenous(
        start_date,
        end_date,
        df_air_water,
        df_node_load
    )

    # Update generator status
    network_data = MOCOT.update_scenario!(network_data, scenario_code)

    # Simulation
    (objectives, state) = MOCOT.simulation(
        network_data,
        exogenous,
        w_with_coal=w_with_coal,
        w_con_coal=w_con_coal,
        w_with_ng= w_with_ng,
        w_con_ng=w_con_ng,
        w_with_nuc=w_with_nuc,
        w_con_nuc= w_con_nuc,
        verbose_level=verbose_level
    )

    # Console feedback
    println("Scenario code: $scenario_code")
    println(Dict(
        "w_with_coal" => w_with_coal,
        "w_con_coal" => w_con_coal,
        "w_with_ng" => w_with_ng,
        "w_con_ng" => w_con_ng,
        "w_with_nuc" => w_with_nuc,
        "w_con_nuc" => w_con_nuc
    ))
    println(objectives)

    if output_type == 1  # "borg"
        for obj_name in objective_names
            append!(objective_array, objectives[obj_name])
        end
        
        return objective_array

    elseif  output_type == 2  # "all"

        # Generator information export
        CSV.write(paths["outputs"]["gen_info_main"], df_gen_info)

        return (objectives, state)

    end
end
