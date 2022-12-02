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
include("capacity_reduction.jl")


function simulation(
    network_data:: Dict,
    exogenous:: Dict,
    voll:: Float64=330000.0,
    ;
    w_with:: Float64=0.0,
    w_con:: Float64=0.0,
    w_emit:: Float64=0.0,
    verbose_level:: Int64=1
)
    """
    Simulation of water and energy system

    # Arguments
    - `network_data:: Dict`: PowerModels network data
    - `exogenous:: Dict`: Exogenous parameter data [<parameter_name>][<timestep>]...[<timestep>]
    - `voll:: Float64`: Value of lost load, Default is 330000.0. [dollar/pu]
    - `w_with:: Float64`: Coal withdrawal weight [dollar/L]
    - `w_con:: Float64`: Coal consumption weight [dollar/L]
    - `w_emit:: Float64`: Emission withdrawal weight [dollar/lb]
    - `verbose_level:: Int64`: Level of output. Default is 1. Less is 0.
    """
    # Initialization
    d_total = length(exogenous["node_load"]) 
    h_total = length(exogenous["node_load"]["1"])
    state = Dict{String, Dict}()
    state["power"] = Dict("0" => Dict())  # [pu]
    state["withdraw_rate"] = Dict("0" => Dict{String, Float64}())  # [L/pu]
    state["consumption_rate"] = Dict("0" => Dict{String, Float64}())  # [L/pu]
    state["discharge_violation"] = Dict("0" => Dict{String, Float64}())  # [C]
    state["capacity_reduction"] = Dict("0" => Dict{String, Float64}())  # [MW]

    # Add reliability generators
    network_data = add_reliability_gens!(network_data, voll)

    # Processing decision vectors
    w_with_dict = create_decision_dict(w_with, network_data)  # [dollar/L]
    w_con_dict = create_decision_dict(w_con, network_data)  # [dollar/L]
    w_emit_dict = create_decision_dict(w_emit, network_data)  # [dollar/lb]

    # Adjust generator minimum capacity
    network_data = update_all_gens!(network_data, "pmin", 0.0)

    # Make multinetwork
    network_data_multi = PowerModels.replicate(network_data, h_total)

    # Initialize water use based on 20.0 C
    water_temperature = 20.0
    air_temperature = 20.0
    Q = 1400.0 # cmps
    regulatory_temperature = 32.2  # For Illinois
    gen_beta_with, gen_beta_con, gen_discharge_violation, gen_delta_t = gen_water_use_wrapper(  # [L/pu], [C]
        water_temperature,
        air_temperature,
        regulatory_temperature,
        network_data,
    )
    gen_capacity, gen_capacity_reduction = get_gen_capacity_reduction(network_data, gen_delta_t, Q)
    state["capacity_reduction"]["0"] = gen_capacity_reduction    
    state["discharge_violation"]["0"] = gen_discharge_violation
    state["withdraw_rate"]["0"] = gen_beta_with
    state["consumption_rate"]["0"] = gen_beta_con

    # Simulation
    for d in 1:d_total
        println("Simulation Day: " * string(d))

        # Update generator capacity
        network_data_multi = update_gen_capacity!(
            network_data_multi,
            gen_capacity
        )

        # Update loads
        network_data_multi = update_load!(
            network_data_multi,
            exogenous["node_load"][string(d)]
        )

        # Adjust wind generator capacity
        network_data_multi = update_wind_capacity!(
            network_data_multi,
            exogenous["wind_capacity_factor"][string(d)]
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
            multiply_dicts([state["withdraw_rate"][string(d-1)], w_with_dict])
        )
        pm = add_linear_obj_terms!(
            pm,
            multiply_dicts([state["consumption_rate"][string(d-1)], w_con_dict])
        )

        # Add emission terms
        df_emit = DataFrames.DataFrame(
            PowerModels.component_table(network_data, "gen", ["cus_emit"]),
            [:obj_name , :cus_emit]
        )
        df_emit = DataFrames.filter(
            :cus_emit => x -> !any(f -> f(x), (ismissing, isnothing, isnan)),
            df_emit
        )
        emit_rate_dict = Dict(Pair.(string.(df_emit.obj_name), df_emit.cus_emit))
        pm = add_linear_obj_terms!(
            pm,
            multiply_dicts([emit_rate_dict, w_emit_dict])
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
        gen_beta_with, gen_beta_con, gen_discharge_violation, gen_delta_t = gen_water_use_wrapper(
            exogenous["water_temperature"][string(d)],
            exogenous["air_temperature"][string(d)],
            regulatory_temperature,
            network_data,
        )
        gen_capacity, gen_capacity_reduction = get_gen_capacity_reduction(
            network_data,
            gen_delta_t,
            exogenous["water_flow"][string(d)]
        )
        state["capacity_reduction"][string(d)] = gen_capacity_reduction    
        state["discharge_violation"][string(d)] = gen_discharge_violation
        state["withdraw_rate"][string(d)] = gen_beta_with
        state["consumption_rate"][string(d)] = gen_beta_con

    end

    # Compute objectives
    objectives = get_objectives(state, network_data, w_with, w_con, w_emit)

    # Compute metrics
    metrics = get_metrics(state, network_data)

    return (objectives, metrics, state)
end


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
        df_wind_cf,
        df_node_load
    )
    @Infiltrator.infiltrate

    # Update generator status
    network_data = update_scenario!(network_data, scenario_code)

    # Simulation
    (objectives, metrics, state) = simulation(
        network_data,
        exogenous,
        w_with=w_with,
        w_con=w_con,
        w_emit= w_emit,
        verbose_level=verbose_level
    )

    # Console feedback
    decisions = Dict(
        "w_with" => w_with,
        "w_con" => w_con,
        "w_emit" => w_emit,
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

        return (objectives, state, metrics)

    end
end

end # module
