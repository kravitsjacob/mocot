"""Water/power system simulation"""

"""
Water and power simulation
"""
mutable struct WaterPowerSimulation
    "WaterPowerModel"
    model:: WaterPowerModel
    "Exogenous parameters"
    exogenous:: Dict{String, Dict}
    "State parameters"
    state:: Dict{String, Dict}
end


function new_simulation(model:: WaterPowerModel, exogenous:: Dict)
    """
    New water/power simulation
    """
    simulation = WaterPowerSimulation(model, exogenous, Dict{String, Dict}())

    # Set defaults
    simulation.state["multi_network_data"] = Dict("0" => Dict{String, Any}())
    simulation.state["pm"] = Dict{String, PowerModels.DCPPowerModel}()
    simulation.state["results"] = Dict("0" => Dict{String, Any}())
    simulation.state["withdraw_rate"] = Dict("0" => Dict{String, Float64}())  # [L/pu]
    simulation.state["consumption_rate"] = Dict("0" => Dict{String, Float64}())  # [L/pu]
    simulation.state["discharge_violation"] = Dict("0" => Dict{String, Float64}())  # [C]
    simulation.state["capacity_reduction"] = Dict("0" => Dict{String, Float64}())  # [MW]
    simulation.state["capacity"] = Dict("0" => Dict{String, Float64}())  # [MW]

    return simulation
end


function run_simulation(
    simulation:: WaterPowerSimulation,
    voll:: Float64=330000.0,
    ;
    w_with:: Float64=0.0,
    w_con:: Float64=0.0,
    w_emit:: Float64=0.0,
    verbose_level:: Int64=1,
    scenario_code:: Int64=1,
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
    - `scenario_code:: Int64`: Scenario code for simulation. Default is 1.
    """
    # Initialization
    exogenous = simulation.exogenous
    model = simulation.model
    state = simulation.state
    d_total = length(exogenous["node_load"])
    h_total = length(exogenous["node_load"]["1"])

    # Processing decision vectors
    w_with_dict = create_decision_dict(w_with, model.network_data)  # [dollar/L]
    w_con_dict = create_decision_dict(w_con, model.network_data)  # [dollar/L]
    w_emit_dict = create_decision_dict(w_emit, model.network_data)  # [dollar/lb]

    # Emission rate dictionary
    emit_rate_dict = Dict(gen_name => gen.emit_rate for (gen_name, gen) in model.gens)  # [MW/hr]

    # Initialize water use based on 20.0 [C]
    water_temperature = 20.0  # [C]
    air_temperature = 20.0  # [C]
    Q = 1400.0 # cmps
    regulatory_temperature = 32.2  # For Illinois
    (
        gen_beta_with,
        gen_beta_con,
        gen_discharge_violation,
        gen_capacity_reduction,
        gen_capacity
    ) = water_models_wrapper(
        model,
        water_temperature,
        air_temperature,
        regulatory_temperature,
        Q,
        scenario_code,
    )
    state["withdraw_rate"]["0"] = gen_beta_with
    state["consumption_rate"]["0"] = gen_beta_con
    state["discharge_violation"]["0"] = gen_discharge_violation
    state["capacity_reduction"]["0"] = gen_capacity_reduction 
    state["capacity"]["0"] = gen_capacity

    # Add reliability generators
    temp_network_data = create_reliabilty_network(model, voll)

    # Make multinetwork
    simulation = create_default_multi_network!(simulation, temp_network_data)
    
    # Simulation
    for d in 1:d_total
        println("Simulation Day: " * string(d))
        # Store updated multi_network_data
        state["multi_network_data"][string(d)] = state["multi_network_data"]["default"]

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
        state["pm"][string(d)] = PowerModels.instantiate_model(
            state["multi_network_data"][string(d)],
            PowerModels.DCPPowerModel,
            PowerModels.build_mn_opf
        )

        # Add ramp rates
        simulation = add_within_day_ramp_rates!(simulation, d)
        if d > 1
            pm = add_day_to_day_ramp_rates!(simulation, d)
        end

        # Add withdrawal terms
        w_with_terms = multiply_dicts([state["withdraw_rate"][string(d-1)], w_with_dict])  # [L/MWh] * [dollar/L]
        map!(x -> x * 100.0, values(w_with_terms)) # [dollar/pu]
        simulation = add_linear_obj_terms!(
            simulation,
            d,
            w_with_terms
        )
    
        # Add consumption terms
        w_con_terms = multiply_dicts([state["consumption_rate"][string(d-1)], w_con_dict])  # [L/MWh] * [dollar/L] * 1 [hr]
        map!(x -> x * 100.0, values(w_con_terms)) # [dollar/pu]
        simulation = add_linear_obj_terms!(
            simulation,
            d,
            w_con_terms
        )

        # Add emission terms
        w_emit_terms = multiply_dicts([emit_rate_dict, w_emit_dict])  # [lbs/MWh] * [dollar/lbs] * 1 [hr]
        map!(x -> x * 100.0, values(w_emit_terms)) # [dollar/pu]
        simulation = add_linear_obj_terms!(
            simulation,
            d,
            w_emit_terms
        )

        # Solve power system model
        if verbose_level == 1
            state["results"][string(d)] = PowerModels.optimize_model!(
                state["pm"][string(d)],
                optimizer=JuMP.optimizer_with_attributes(Ipopt.Optimizer)
            )
        elseif verbose_level == 0
            state["results"][string(d)] = PowerModels.optimize_model!(
                state["pm"][string(d)],
                optimizer=JuMP.optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0)
            )
        end

        # Water use
        (
            gen_beta_with,
            gen_beta_con,
            gen_discharge_violation,
            gen_capacity_reduction,
            gen_capacity
        ) = water_models_wrapper(
            model,
            exogenous["water_temperature"][string(d)],
            exogenous["air_temperature"][string(d)],
            regulatory_temperature,
            exogenous["water_flow"][string(d)],
            scenario_code,
        )
        state["withdraw_rate"][string(d)] = gen_beta_with
        state["consumption_rate"][string(d)] = gen_beta_con
        state["discharge_violation"][string(d)] = gen_discharge_violation
        state["capacity_reduction"][string(d)] = gen_capacity_reduction 
        state["capacity"][string(d)] = gen_capacity

    end

    # Compute objectives
    objectives = get_objectives(simulation, w_with, w_con, w_emit)

    # Compute metrics
    metrics = get_metrics(simulation)

    return (objectives, metrics, state)
end


function create_default_multi_network!(simulation:: WaterPowerSimulation, network_data:: Dict, h_total=24)
    """
    Create the default multi-timestep network

    # Arguments
    - `simulation:: WaterPowerSimulation`: Simulation data
    - `network_data:: Dict`: PowerModels network data
    - `h_total=24`: Total timesteps to replicate [hour]
    """
    simulation.state["multi_network_data"]["default"] = PowerModels.replicate(network_data, h_total)

    return simulation
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
        for (h, network_data) in simulation.state["multi_network_data"]["default"]["nw"]
            simulation.state["multi_network_data"][string(day)]["nw"][h]["gen"][gen_name]["pmax"] = new_capacity / 100.0  # convert to [pu]
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
    for (h, network_data) in simulation.state["multi_network_data"][string(day)]["nw"]
        # Looping over loads
        for (load_name, load_dict) in network_data["load"]
            # Extracting load bus
            bus = string(load_dict["load_bus"])

            # Extracting load value
            load_value = simulation.exogenous["node_load"][string(day)][h][bus]

            # Set load
            simulation.state["multi_network_data"][string(day)]["nw"][string(h)]["load"][load_name]["pd"] = load_value / 100.0  # Convert to [pu]
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
            # Extract average capacity
            avg_capacity = simulation.model.network_data["gen"][gen_name]["pmax"]

            # Loop through all hours
            for h in 1:length(simulation.state["multi_network_data"][string(day)])
                # Extract wind capacity factor
                wind_cf = simulation.exogenous["wind_capacity_factor"][string(day)][string(h)]
                
                # Update
                simulation.state["multi_network_data"][string(day)]["nw"][string(h)]["gen"][gen_name]["pmax"] = avg_capacity * wind_cf
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
    h_total = length(simulation.state["multi_network_data"][string(day)])
    for (gen_name, gen) in simulation.model.gens
        # Extract generator information
        ramp = gen.ramp_rate
        obj_index = parse(Int, gen_name)

        try
            # Ramping up
            JuMP.@constraint(
                simulation.state["pm"][string(day)].model,
                [h in 2:h_total],
                PowerModels.var(simulation.state["pm"][string(day)], h-1, :pg, obj_index) - PowerModels.var(simulation.state["pm"][string(day)], h, :pg, obj_index) <= ramp / 100.0  # Convert to [pu/hr]
            )
            # Ramping down
            JuMP.@constraint(
                simulation.state["pm"][string(day)].model,
                [h in 2:h_total],
                PowerModels.var(simulation.state["pm"][string(day)], h, :pg, obj_index) - PowerModels.var(simulation.state["pm"][string(day)], h-1, :pg, obj_index) <= ramp / 100.0  # Convert to [pu/hr]
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
    results_previous_day = simulation.state["results"][string(day-1)]["solution"]["nw"]
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
                simulation.state["pm"][string(day)].model,
                pg_previous - PowerModels.var(simulation.state["pm"][string(day)], h, :pg, obj_index) <= ramp / 100.0  # Convert to [pu/hr]
            )

            # Ramping down
            JuMP.@constraint(
                simulation.state["pm"][string(day)].model,
                PowerModels.var(simulation.state["pm"][string(day)], h, :pg, obj_index) - pg_previous <= ramp / 100.0  # Convert to [pu/hr]
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
    for h in 1:length(simulation.state["pm"][string(day)].data["nw"])
        for (gen_name, coef) in linear_coef
            gen_index = parse(Int64, gen_name)
            try
                gen_term = coef * PowerModels.var(
                    simulation.state["pm"][string(day)], h, :pg, gen_index
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
    current_objective = JuMP.objective_function(simulation.state["pm"][string(day)].model)
    new_objective = @JuMP.expression(simulation.state["pm"][string(day)].model, current_objective + terms)
    JuMP.set_objective_function(simulation.state["pm"][string(day)].model, new_objective)

    return simulation
end


function get_objectives(
    simulation:: WaterPowerSimulation,
    w_with:: Float64,
    w_con:: Float64,
    w_emit:: Float64,
)
    """
    Computing simulation objectives
    
    # Arguments
    - `simulation:: WaterPowerSimulation`: Water/power simulation
    - `w_with:: Float64`: Withdrawal weight [dollar/L]
    - `w_con:: Float64`: Consumption weight [dollar/L]
    - `w_emit`:: Emission weight [dollar/lbs]
    """
    objectives = Dict{String, Float64}()

    # Cost coefficients
    df_cost_coef = DataFrames.DataFrame(
        PowerModels.component_table(simulation.model.network_data, "gen", ["cost"]),
        ["obj_name", "cost"]
    )
    df_cost_coef[!, "obj_name"] = string.(df_cost_coef[!, "obj_name"])
    df_cost_coef[!, "c_per_mw2"] = extract_from_array_column(df_cost_coef[!, "cost"], 1) / 100.0  # Convert to [dollar/MW]
    df_cost_coef[!, "c_per_mw"] = extract_from_array_column(df_cost_coef[!, "cost"], 2) / 100.0^2 # Convert to [dollar/MW^2]
    df_cost_coef[!, "c"] = extract_from_array_column(df_cost_coef[!, "cost"], 3)

    # Emission coefficients
    df_emit_coef = get_gen_prop_dataframe(simulation.model, ["emit_rate"])

    # States-dependent coefficients
    df_withdraw_states = MOCOT.get_state_dataframe(simulation.state, "withdraw_rate")
    df_consumption_states = MOCOT.get_state_dataframe(simulation.state, "consumption_rate")
    df_discharge_violation_states = MOCOT.get_state_dataframe(simulation.state, "discharge_violation")
    df_all_power_states = MOCOT.get_powermodel_state_dataframe(simulation.state, "results", "gen", "pg")
    df_all_power_states.pg = df_all_power_states.pg * 100.0  # Convert to [MW]
    df_all_power_states.pg = round.(df_all_power_states.pg, digits=7)
    gen_rows = in.(string.(df_all_power_states.obj_name), Ref(keys(simulation.model.gens)))
    df_power_states = df_all_power_states[gen_rows, :]
    df_reliability_states = df_all_power_states[.!gen_rows, :]

    # Compute cost objectives
    df_cost = DataFrames.leftjoin(
        df_power_states,
        df_cost_coef,
        on = [:obj_name]
    )
    objectives["f_gen"] = DataFrames.sum(DataFrames.skipmissing(
        df_cost.c .+ df_cost.pg .* df_cost.c_per_mw .+ df_cost.pg.^2 .* df_cost.c_per_mw2
    ))

    # Compute water objectives
    df_water = DataFrames.leftjoin(
        df_power_states,
        df_withdraw_states,
        on = [:obj_name, :day]
    )
    df_water = DataFrames.leftjoin(
        df_water,
        df_consumption_states,
        on = [:obj_name, :day]
    )
    df_water[!, "hourly_withdrawal"] = df_water[!, "pg"] .* df_water[!, "withdraw_rate"]
    df_water[!, "hourly_consumption"] = df_water[!, "pg"] .* df_water[!, "consumption_rate"]
    objectives["f_with_tot"] = DataFrames.sum(df_water[!, "hourly_withdrawal"])
    objectives["f_con_tot"] = DataFrames.sum(df_water[!, "hourly_consumption"])
    
    # Compute discharge violation objectives
    if length(df_discharge_violation_states[!, "discharge_violation"]) > 0
        df_discharge_violation_states = DataFrames.leftjoin(
            df_discharge_violation_states,
            df_water,
            on=[:obj_name, :day]
        )
        temperature = df_discharge_violation_states.discharge_violation
        discharge = df_discharge_violation_states.hourly_withdrawal - df_discharge_violation_states.hourly_consumption
        objectives["f_disvi_tot"] = DataFrames.sum(discharge .* temperature)
    else
        objectives["f_disvi_tot"] = 0.0
    end

    # Compute emission objectives
    df_emit = DataFrames.leftjoin(
        df_power_states,
        df_emit_coef,
        on = [:obj_name]
    )
    df_emit[!, "hourly_emit"] = df_emit[!, "pg"] .* df_emit[!, "emit_rate"]
    objectives["f_emit"] = DataFrames.sum(df_emit[!, "hourly_emit"])

    # Compute reliability objectives
    objectives["f_ENS"] = DataFrames.sum(df_reliability_states[!, "pg"])

    # Total weights
    objectives["f_w_with"] = w_with
    objectives["f_w_con"] = w_con
    objectives["f_w_emit"] = w_emit

    return objectives
end


function get_metrics(
    simulation:: WaterPowerSimulation,
)
    """
    Get metrics for simulation. Metrics are different than objectives as they do not
    inform the next set of objectives but rather just quantify an aspect of a given state.

    # Arguments
    - `simulation:: WaterPowerSimulation`: Water/power simulation
    """
    metrics = Dict{String, Float64}()
    
    # Coefficients
    df_fuel_coef = get_gen_prop_dataframe(simulation.model, ["fuel"])
    df_cool_coef = get_gen_prop_dataframe(simulation.model, ["cool"])

    # Power states
    df_all_power_states = MOCOT.get_powermodel_state_dataframe(simulation.state, "results", "gen", "pg")
    gen_rows = in.(string.(df_all_power_states.obj_name), Ref(keys(simulation.model.gens)))
    df_power_states = df_all_power_states[gen_rows, :]

    # Get total fuel ouputs
    df_power_fuel = DataFrames.leftjoin(                                                                                                                                                                    
        df_power_states,                                                                                                                                                                                      
        df_fuel_coef,                                                                                                                                                                                              
        on=[:obj_name]                                                                                                                                                                                        
    )
    df_power_fuel = DataFrames.combine(
        DataFrames.groupby(df_power_fuel, [:fuel]),
        :pg => sum,
    )
    df_power_fuel = df_power_fuel[df_power_fuel.fuel .!= "NaN",:]
    for row in DataFrames.eachrow(df_power_fuel)
        metrics[row["fuel"] * "_output"] = row["pg_sum"]
    end

    # Get total cooling ouputs
    df_power_cool = DataFrames.leftjoin(                                                                                                                                                                    
        df_power_states,                                                                                                                                                                                      
        df_cool_coef,                                                                                                                                                                                              
        on=[:obj_name]                                                                                                                                                                                        
    )
    df_power_cool = DataFrames.combine(
        DataFrames.groupby(df_power_cool, [:cool]),
        :pg => sum,
    )
    df_power_cool = df_power_cool[df_power_cool.cool .!= "NaN",:]
    for row in DataFrames.eachrow(df_power_cool)
        metrics[row["cool"] * "_output"] = row["pg_sum"]
    end

    return metrics 
end
