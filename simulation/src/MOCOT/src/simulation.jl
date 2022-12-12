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
    "Multi-timestep network data for each day"
    multi_network_data:: Dict
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
    simulation.state["capacity"] = Dict("0" => Dict{String, Float64}())  # [MW]

    # Add reliability generators
    simulation.model = add_reliability_gens!(simulation.model, voll)

    # Processing decision vectors
    w_with_dict = create_decision_dict(w_with, simulation.model.network_data)  # [dollar/L]
    w_con_dict = create_decision_dict(w_con, simulation.model.network_data)  # [dollar/L]
    w_emit_dict = create_decision_dict(w_emit, simulation.model.network_data)  # [dollar/lb]

    # Initialize water use based on 20.0 C
    water_temperature = 20.0
    air_temperature = 20.0
    Q = 1400.0 # cmps
    regulatory_temperature = 32.2  # For Illinois
    gen_beta_with, gen_beta_con, gen_discharge_violation, gen_delta_t = water_use_wrapper(
        simulation.model,
        water_temperature,
        air_temperature,
        regulatory_temperature,
    )
    simulation.state["withdraw_rate"]["0"] = gen_beta_with
    simulation.state["consumption_rate"]["0"] = gen_beta_con
    simulation.state["discharge_violation"]["0"] = gen_discharge_violation
    gen_capacity, gen_capacity_reduction = get_capacity_wrapper(simulation.model, gen_delta_t, Q)
    simulation.state["capacity_reduction"]["0"] = gen_capacity_reduction 
    simulation.state["capacity"]["0"] = gen_capacity   

    # Make multinetwork
    simulation.multi_network_data["raw"] = PowerModels.replicate(simulation.model.network_data, h_total)

    # Simulation
    for d in 1:d_total
        println("Simulation Day: " * string(d))

        # Store updated multi_network_data
        simulation.multi_network_data["1"] = simulation.multi_network_data["raw"]

        # Update generator capacity
        simulation = update_gen_capacity!(
            simulation,
            d,
        )

        # Update loads
        simulation = update_load!(
            simulation,
            d,
        )

        # Adjust wind generator capacity
        simulation = update_wind_capacity!(
            simulation,
            d,
        )

        @Infiltrator.infiltrate
        # Create power system model
        pm = PowerModels.instantiate_model(
            network_data_multi,
            PowerModels.DCPPowerModel,
            PowerModels.build_mn_opf
        )

        @Infiltrator.infiltrate

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

    end

    # # Compute objectives
    # objectives = get_objectives(state, network_data, w_with, w_con, w_emit)

    # # Compute metrics
    # metrics = get_metrics(state, network_data)

    return (objectives, metrics, state)
end


function update_gen_capacity!(simulation:: WaterPowerSimulation, day:: Int64)
    """
    Update loads for network data 

    # Arguments
    - `simulation:: WaterPowerSimulation`: Simulation data
    - `day:: Int64`: Day of simulation
    """
    # Looping of generators
    for (gen_name, new_capacity) in simulation.state["capacity"][string(day-1)]
        # Looping over hours
        for (h, network_data) in simulation.multi_network_data["1"]["nw"]
            simulation.multi_network_data[string(day)]["nw"][h]["gen"][gen_name]["pmax"] = new_capacity
        end
    end

    return simulation
end


function update_load!(simulation:: WaterPowerSimulation, day:: Int64)
    """
    Update loads for network data 

    # Arguments
    - `simulation:: WaterPowerSimulation`: Simulation data
    - `day:: Int64`: Day of simulation
    """
    # Looping over hours
    for (h, network_data) in simulation.multi_network_data[string(day)]["nw"]
        # Looping over loads
        for (load_name, load_dict) in network_data["load"]
            # Extracting load bus
            bus = string(load_dict["load_bus"])

            # Extracting load value
            load_value = simulation.exogenous["node_load"][string(day)][h][bus]

            # Set load
            simulation.multi_network_data[string(day)]["nw"][string(h)]["load"][load_name]["pd"] = load_value
        end
    end

    return simulation
end


function update_wind_capacity!(simulation:: WaterPowerSimulation, day:: Int64)
    """
    Update generator wind capacity

    # Arguments
    - `simulation:: WaterPowerSimulation`: Simulation data
    - `day:: Int64`: Day of simulation
    """
    # Loop through generators
    for (gen_name, gen) in simulation.model.gens
        if gen.fuel == "wind"
            # Loop through all hours
            for h in 1:length(simulation.multi_network_data[string(day)])
                # Extract wind capacity factor
                wind_cf = simulation.exogenous["wind_capacity_factor"][string(day)][string(h)]
                
                # Extract average capacity
                avg_capacity = simulation.multi_network_data[string(day)]["nw"][string(h)]["gen"][gen_name]["pmax"]

                # Update
                simulation.multi_network_data[string(day)]["nw"][string(h)]["gen"][gen_name]["pmax"] = avg_capacity * wind_cf
            end
        end
    end

    return simulation
end
