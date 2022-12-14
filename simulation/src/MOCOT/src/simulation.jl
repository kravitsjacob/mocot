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
    "Multi-timestep pm data for each day"
    multi_pm:: Dict
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
        simulation.multi_network_data[string(d)] = simulation.multi_network_data["raw"]

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

        # Instantiate model
        simulation.multi_pm[string(d)] = PowerModels.instantiate_model(
            simulation.multi_network_data[string(d)],
            PowerModels.DCPPowerModel,
            PowerModels.build_mn_opf
        )

        # Add ramp rates
        simulation = add_within_day_ramp_rates!(simulation, d)
        if d > 1
            pm = add_day_to_day_ramp_rates!(simulation, d)
        end

        # Add water use terms
        simulation = add_linear_obj_terms!(
            simulation,
            d,
            multiply_dicts([simulation.state["withdraw_rate"][string(d-1)], w_with_dict])
        )
        simulation = add_linear_obj_terms!(
            simulation,
            d,
            multiply_dicts([simulation.state["consumption_rate"][string(d-1)], w_con_dict])
        )

        # Add emission terms
        emit_rate_dict = Dict(gen_name => gen.emit_rate for (gen_name, gen) in simulation.model.gens)
        simulation = add_linear_obj_terms!(
            simulation,
            d,
            multiply_dicts([emit_rate_dict, w_emit_dict])
        )

        # Solve power system model
        if verbose_level == 1
            simulation.state["power"][string(d)] = PowerModels.optimize_model!(
                simulation.multi_pm[string(d)],
                optimizer=JuMP.optimizer_with_attributes(Ipopt.Optimizer)
            )
        elseif verbose_level == 0
            simulation.state["power"][string(d)] = PowerModels.optimize_model!(
                simulation.multi_pm[string(d)],
                optimizer=JuMP.optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0)
            )
        end

        # Water use
        gen_beta_with, gen_beta_con, gen_discharge_violation, gen_delta_t = water_use_wrapper(
            simulation.model,
            simulation.exogenous["water_temperature"][string(d)],
            simulation.exogenous["air_temperature"][string(d)],
            regulatory_temperature,
        )
        simulation.state["withdraw_rate"][string(d)] = gen_beta_with
        simulation.state["consumption_rate"][string(d)] = gen_beta_con
        simulation.state["discharge_violation"][string(d)] = gen_discharge_violation
        gen_capacity, gen_capacity_reduction = get_capacity_wrapper(
            simulation.model,
            gen_delta_t,
            simulation.exogenous["water_flow"][string(d)],
        )
        simulation.state["capacity_reduction"][string(d)] = gen_capacity_reduction 
        simulation.state["capacity"][string(d)] = gen_capacity

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


function add_within_day_ramp_rates!(simulation:: WaterPowerSimulation, day:: Int64)
    """
    Add hourly ramp rates to model

    # Arguments
    - `simulation:: WaterPowerSimulation`: Simulation data
    - `day:: Int64`: Day of simulation
    """
    h_total = length(simulation.multi_network_data[string(day)])
    for (gen_name, gen) in simulation.model.gens
        # Extract generator information
        ramp = gen.ramp_rate
        obj_index = parse(Int, gen_name)

        try
            # Ramping up
            JuMP.@constraint(
                simulation.multi_pm[string(day)].model,
                [h in 2:h_total],
                PowerModels.var(simulation.multi_pm[string(day)], h-1, :pg, obj_index) - PowerModels.var(simulation.multi_pm[string(day)], h, :pg, obj_index) <= ramp
            )
            # Ramping down
            JuMP.@constraint(
                simulation.multi_pm[string(day)].model,
                [h in 2:h_total],
                PowerModels.var(simulation.multi_pm[string(day)], h, :pg, obj_index) - PowerModels.var(simulation.multi_pm[string(day)], h-1, :pg, obj_index) <= ramp
            )
        catch
            println(
                """
                Ramping constraint for generator $obj_index was specified but the corresponding decision variable was not found.
                """
            )
        end
    end

    return simulation
end


function add_day_to_day_ramp_rates!(simulation:: WaterPowerSimulation, day:: Int64)
    """
    Add day-to-day ramp rates to model

    # Arguments
    - `simulation:: WaterPowerSimulation`: Simulation data
    - `day:: Int64`: Day of simulation
    """
    h = 1
    h_previous = 24
    results_previous_day = simulation.state["power"][string(day-1)]["solution"]["nw"]
    results_previous_hour = results_previous_day[string(h_previous)]
    
    for (gen_name, gen) in simulation.model.gens
        # Extract generator information
        ramp = gen.ramp_rate
        obj_index = parse(Int, gen_name)

        try
            # Previous power output
            pg_previous = results_previous_hour["gen"][gen_name]["pg"]

            # Ramping up
            obj_index = parse(Int, gen_name)
            JuMP.@constraint(
                simulation.multi_pm[string(day)].model,
                pg_previous - PowerModels.var(simulation.multi_pm[string(day)], h, :pg, obj_index) <= ramp
            )

            # Ramping down
            JuMP.@constraint(
                simulation.multi_pm[string(day)].model,
                PowerModels.var(simulation.multi_pm[string(day)], h, :pg, obj_index) - pg_previous <= ramp
            )
        catch
            println(
                """
                Day-to-day ramping constraint for generator $gen_name was specified but the corresponding decision variable was not found.
                """
            )
        end
    end

    return simulation
end


function add_linear_obj_terms!(
    simulation:: WaterPowerSimulation,
    day:: Int64,
    linear_coef:: Dict{String, Float64},
)
    """
    Add linear objective function terms
    
    # Arguments
    - `simulation:: WaterPowerSimulation`: Simulation data
    - `day:: Int64`: Day of simulation
    - `linear_coef:: Dict{String, Float64}`: Dictionary generator names and coefficients
    """
    # Setup
    terms = 0.0
    # Loop through hours
    for h in 1:length(simulation.multi_pm[string(day)].data["nw"])
        for (gen_name, coef) in linear_coef
            gen_index = parse(Int64, gen_name)
            try
                gen_term = coef * PowerModels.var(
                    simulation.multi_pm[string(day)], h, :pg, gen_index
                )
                terms = terms + gen_term
            catch
                println(
                    """
                    Linear term for generator $gen_name was specified but the corresponding decision variable was not found.
                    """
                )
            end
        end
    end
    
    # Update objective function
    current_objective = JuMP.objective_function(simulation.multi_pm[string(day)].model)
    new_objective = @JuMP.expression(simulation.multi_pm[string(day)].model, current_objective + terms)
    JuMP.set_objective_function(simulation.multi_pm[string(day)].model, new_objective)

    return simulation
end