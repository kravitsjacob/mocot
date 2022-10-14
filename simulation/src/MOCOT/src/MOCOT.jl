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

include("utils.jl")
include("daily.jl")
include("hourly.jl")
include("preprocessing.jl")


function simulation(
    network_data:: Dict,
    exogenous:: Dict,
    ;
    w_with_coal:: Float64=0.0,
    w_con_coal:: Float64=0.0,
    w_with_ng:: Float64=0.0,
    w_con_ng:: Float64=0.0,
    w_with_nuc:: Float64=0.0,
    w_con_nuc:: Float64=0.0,
    verbose_level:: Int64=1
)
    """
    Simulation of water and energy system

    # Arguments
    - `network_data:: Dict`: PowerModels network data
    - `exogenous:: Dict`: Exogenous parameter data [<parameter_name>][<timestep>]...[<timestep>]
    - `w_with_coal:: Float64`: Coal withdrawal weight
    - `w_con_coal:: Float64`: Coal consumption weight
    - `w_with_ng:: Float64`: Natural gas withdrawal weight
    - `w_con_ng:: Float64`: Natural gas consumption weight
    - `w_with_nuc:: Float64`: Nuclear withdrawal weight
    - `w_con_nuc:: Float64`: Nuclear consumption weight
    - `verbose_level:: Int64`: Level of output. Default is 1. Less is 0.
    """
    # Initialization
    d_total = length(exogenous["node_load"]) 
    h_total = length(exogenous["node_load"]["1"])
    state = Dict{String, Dict}()
    state["power"] = Dict("0" => Dict())
    state["withdraw_rate"] = Dict("0" => Dict{String, Float64}())
    state["consumption_rate"] = Dict("0" => Dict{String, Float64}())
    state["discharge_violation"] = Dict("0" => Dict{String, Float64}())

    # Processing decision vectors
    w_with = Dict{String, Float64}()
    w_con = Dict{String, Float64}()
    for (obj_name, obj_props) in network_data["gen"]
        try
            if obj_props["cus_fuel"] == "coal"
                w_with[obj_name] = w_with_coal
                w_con[obj_name] = w_con_coal
            elseif obj_props["cus_fuel"] == "ng"
                w_with[obj_name] = w_with_ng
                w_con[obj_name] = w_con_ng
            elseif obj_props["cus_fuel"] == "nuclear"
                w_with[obj_name] = w_with_nuc
                w_con[obj_name] = w_con_nuc
            else
                w_with[obj_name] = 0.0
                w_con[obj_name] = 0.0
            end
        catch
            try 
                # Check if reliabilty generator
                if obj_name not in network_data["reliability_gen"]
                    println("Weight not added for generator $obj_name")
                end
            catch
                # Skip adding weight as it's a reliability generator
            end
        end
    end

    # Adjust generator capacity
    network_data = update_all_gens!(network_data, "pmin", 0.0)

    # Add reliability generators
    voll = 330000.0  # $/pu for MISO
    network_data = add_reliability_gens!(network_data, voll)

    # Make multinetwork
    network_data_multi = PowerModels.replicate(network_data, h_total)

    # Initialize water use based on 25.0 C
    water_temperature = 25.0
    air_temperature = 25.0
    regulatory_temperature = 33.7  # For Illinois
    gen_beta_with, gen_beta_con = gen_water_use_wrapper(
        water_temperature,
        air_temperature,
        regulatory_temperature,
        network_data,
    )
    state["withdraw_rate"]["0"] = gen_beta_with
    state["consumption_rate"]["0"] = gen_beta_con

    # Simulation
    for d in 1:d_total
        println("Simulation Day: " * string(d))

        # Update loads
        network_data_multi = update_load!(
            network_data_multi,
            exogenous["node_load"][string(d)]
        )

        # Create power system model
        pm = PowerModels.instantiate_model(
            network_data_multi,
            PowerModels.DCPPowerModel,
            PowerModels.build_mn_opf
        )

        # Add ramp rates
        pm = add_within_day_ramp_rates!(pm)

        if d > 1
            pm = add_day_to_day_ramp_rates!(pm, state, d)
        end

        # Add water use terms
        pm = add_linear_obj_terms!(
            pm,
            multiply_dicts([state["withdraw_rate"][string(d-1)], w_with])
        )
        pm = add_linear_obj_terms!(
            pm,
            multiply_dicts([state["consumption_rate"][string(d-1)], w_con])
        )

        # Solve power system model
        if verbose_level == 1
            state["power"][string(d)] = PowerModels.optimize_model!(
                pm,
                optimizer=JuMP.optimizer_with_attributes(Ipopt.Optimizer)
            )
        elseif verbose_level == 0
            state["power"][string(d)] = PowerModels.optimize_model!(
                pm,
                optimizer=JuMP.optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0)
            )
        end

        # Water use
        gen_beta_with, gen_beta_con, gen_discharge_violation = gen_water_use_wrapper(
            exogenous["water_temperature"][string(d)],
            exogenous["air_temperature"][string(d)],
            regulatory_temperature,
            network_data,
        )
        state["discharge_violation"][string(d)] = gen_discharge_violation
        state["withdraw_rate"][string(d)] = gen_beta_with
        state["consumption_rate"][string(d)] = gen_beta_con
    end

    # Compute objectives
    objectives = get_objectives(state, network_data, w_with, w_con)

    # Compute metrics
    metrics = get_metrics(state, network_data)

    return (objectives, metrics, state)
end


function borg_simulation_wrapper(
    w_with_coal:: Float64=0.0,
    w_con_coal:: Float64=0.0,
    w_with_ng:: Float64=0.0,
    w_con_ng:: Float64=0.0,
    w_with_nuc:: Float64=0.0,
    w_con_nuc:: Float64=0.0,
    return_type=1,
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
    - `return_type:: Int64`: Return code. 1 is for standard Borg output. 2 is for returning states, objectives, and metrics
    - `verbose_level:: Int64`: Level of stdout printing. Default is 1. Less is 0.
    - `scenario_code:: Int64`: Scenario code. See update_scenario! for codes
    """
    # Setup
    objective_metric_array = Float64[]

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
        objective_names,
        metric_names
    ) = read_inputs(
        scenario_code,
        paths["inputs"]["scenario_specs"],
        paths["outputs"]["air_water_template"],
        paths["outputs"]["node_load_template"],       
        paths["outputs"]["gen_info_water_ramp_emit_waterlim"],
        paths["inputs"]["eia_heat_rates"],
        paths["inputs"]["case"],
        paths["inputs"]["decisions"],
        paths["inputs"]["objectives"],
        paths["inputs"]["metrics"],        
    )

    # Preparing network
    network_data = add_custom_properties!(network_data, df_gen_info, df_eia_heat_rates)

    # Exogenous parameters
    specs = df_scenario_specs[df_scenario_specs.scenario_code .== scenario_code, :]
    start_date = specs.datetime_start[1]
    end_date = specs.datetime_end[1]
    exogenous = get_exogenous(
        start_date,
        end_date,
        df_air_water,
        df_node_load
    )

    # Update generator status
    network_data = update_scenario!(network_data, scenario_code)

    # Simulation
    (objectives, metrics, state) = simulation(
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
    decisions = Dict(
        "w_with_coal" => w_with_coal,
        "w_con_coal" => w_con_coal,
        "w_with_ng" => w_with_ng,
        "w_con_ng" => w_con_ng,
        "w_with_nuc" => w_with_nuc,
        "w_con_nuc" => w_con_nuc
    )
    println("Scenario code: $scenario_code")
    println(decisions)
    println(objectives)
    println(metrics)

    if return_type == 1  # "borg"
        # Collect objectives
        for obj_name in objective_names
            append!(objective_metric_array, objectives[obj_name])
        end

        # Collect metrics
        for m_name in metric_names
            try
                append!(objective_metric_array, metrics[m_name])
            catch
                append!(objective_metric_array, 0.0)
            end
        end

        return objective_metric_array

    elseif return_type == 2  # "all"

        # Generator information export
        CSV.write(paths["outputs"]["gen_info_main"], df_gen_info)

        return (objectives, state, metrics)

    end
end

end # module
