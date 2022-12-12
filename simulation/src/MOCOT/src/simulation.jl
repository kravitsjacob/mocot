"""Water/power system simulation"""

"""
Water and power simulation
"""
mutable struct WaterPowerSimulation
    "WaterPowerModel"
    model:: WaterPowerModel
    "Exogenous parameters"
    exogenous:: Dict
    "State parameters"
    state:: Dict
end


function run_simulation(
    simulation:: WaterPowerSimulation,
    voll:: Float64=330000.0,
    ;
    w_with:: Float64=0.0,
    w_con:: Float64=0.0,
    w_emit:: Float64=0.0,
    verbose_level:: Int64=1,
)
    """
    Simulation of water and energy system

    # Arguments
    - `simulation:: WaterPowerSimulation`: Simulation
    - `voll:: Float64`: Value of lost load, Default is 330000.0. [dollar/pu]
    - `w_with:: Float64`: Coal withdrawal weight [dollar/L]
    - `w_con:: Float64`: Coal consumption weight [dollar/L]
    - `w_emit:: Float64`: Emission withdrawal weight [dollar/lb]
    - `verbose_level:: Int64`: Level of output. Default is 1. Less is 0.
    """
    # Initialization
    d_total = length(simulation.exogenous["node_load"]) 
    h_total = length(simulation.exogenous["node_load"]["1"])
    simulation.state["power"] = Dict("0" => Dict())  # [pu]
    simulation.state["withdraw_rate"] = Dict("0" => Dict{String, Float64}())  # [L/pu]
    simulation.state["consumption_rate"] = Dict("0" => Dict{String, Float64}())  # [L/pu]
    simulation.state["discharge_violation"] = Dict("0" => Dict{String, Float64}())  # [C]
    simulation.state["capacity_reduction"] = Dict("0" => Dict{String, Float64}())  # [MW]

    # Add reliability generators
    simulation.model = add_reliability_gens!(simulation.model, voll)

    # # Processing decision vectors
    # w_with_dict = create_decision_dict(w_with, network_data)  # [dollar/L]
    # w_con_dict = create_decision_dict(w_con, network_data)  # [dollar/L]
    # w_emit_dict = create_decision_dict(w_emit, network_data)  # [dollar/lb]

    # # Make multinetwork
    # network_data_multi = PowerModels.replicate(network_data, h_total)

    # # Initialize water use based on 20.0 C
    # water_temperature = 20.0
    # air_temperature = 20.0
    # Q = 1400.0 # cmps
    # regulatory_temperature = 32.2  # For Illinois
    # gen_beta_with, gen_beta_con, gen_discharge_violation, gen_delta_t = gen_water_use_wrapper(  # [L/pu], [C]
    #     water_temperature,
    #     air_temperature,
    #     regulatory_temperature,
    #     network_data,
    # )
    # gen_capacity, gen_capacity_reduction = get_gen_capacity_reduction(network_data, gen_delta_t, Q)
    # state["capacity_reduction"]["0"] = gen_capacity_reduction    
    # state["discharge_violation"]["0"] = gen_discharge_violation
    # state["withdraw_rate"]["0"] = gen_beta_with
    # state["consumption_rate"]["0"] = gen_beta_con

    # # Simulation
    # for d in 1:d_total
    #     println("Simulation Day: " * string(d))

    #     # Update generator capacity
    #     network_data_multi = update_gen_capacity!(
    #         network_data_multi,
    #         gen_capacity
    #     )

    #     # Update loads
    #     network_data_multi = update_load!(
    #         network_data_multi,
    #         exogenous["node_load"][string(d)]
    #     )

    #     # Adjust wind generator capacity
    #     network_data_multi = update_wind_capacity!(
    #         network_data_multi,
    #         exogenous["wind_capacity_factor"][string(d)]
    #     )

    #     # Create power system model
    #     pm = PowerModels.instantiate_model(
    #         network_data_multi,
    #         PowerModels.DCPPowerModel,
    #         PowerModels.build_mn_opf
    #     )

    #     # Add ramp rates
    #     pm = add_within_day_ramp_rates!(pm)

    #     if d > 1
    #         pm = add_day_to_day_ramp_rates!(pm, state, d)
    #     end

    #     # Add water use terms
    #     pm = add_linear_obj_terms!(
    #         pm,
    #         multiply_dicts([state["withdraw_rate"][string(d-1)], w_with_dict])
    #     )
    #     pm = add_linear_obj_terms!(
    #         pm,
    #         multiply_dicts([state["consumption_rate"][string(d-1)], w_con_dict])
    #     )

    #     # Add emission terms
    #     df_emit = DataFrames.DataFrame(
    #         PowerModels.component_table(network_data, "gen", ["cus_emit"]),
    #         [:obj_name , :cus_emit]
    #     )
    #     df_emit = DataFrames.filter(
    #         :cus_emit => x -> !any(f -> f(x), (ismissing, isnothing, isnan)),
    #         df_emit
    #     )
    #     emit_rate_dict = Dict(Pair.(string.(df_emit.obj_name), df_emit.cus_emit))
    #     pm = add_linear_obj_terms!(
    #         pm,
    #         multiply_dicts([emit_rate_dict, w_emit_dict])
    #     )

    #     # Solve power system model
    #     if verbose_level == 1
    #         state["power"][string(d)] = PowerModels.optimize_model!(
    #             pm,
    #             optimizer=JuMP.optimizer_with_attributes(Ipopt.Optimizer)
    #         )
    #     elseif verbose_level == 0
    #         state["power"][string(d)] = PowerModels.optimize_model!(
    #             pm,
    #             optimizer=JuMP.optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0)
    #         )
    #     end

    #     # Water use
    #     gen_beta_with, gen_beta_con, gen_discharge_violation, gen_delta_t = gen_water_use_wrapper(
    #         exogenous["water_temperature"][string(d)],
    #         exogenous["air_temperature"][string(d)],
    #         regulatory_temperature,
    #         network_data,
    #     )
    #     gen_capacity, gen_capacity_reduction = get_gen_capacity_reduction(
    #         network_data,
    #         gen_delta_t,
    #         exogenous["water_flow"][string(d)]
    #     )
    #     state["capacity_reduction"][string(d)] = gen_capacity_reduction    
    #     state["discharge_violation"][string(d)] = gen_discharge_violation
    #     state["withdraw_rate"][string(d)] = gen_beta_with
    #     state["consumption_rate"][string(d)] = gen_beta_con

    # end

    # # Compute objectives
    # objectives = get_objectives(state, network_data, w_with, w_con, w_emit)

    # # Compute metrics
    # metrics = get_metrics(state, network_data)

    return (objectives, metrics, state)
end
