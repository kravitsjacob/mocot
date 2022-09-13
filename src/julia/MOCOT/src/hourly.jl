# Functions for hourly-resolution multinetwork PowerModel model


function add_linear_obj_terms!(
    pm,
    linear_coef:: Dict{String, Float64},
)
    """
    Add linear objective function terms
    
    # Arguments
    `pm:: Any`: Any PowerModel
    `linear_coef:: Dict{String, Float64}`: Dictionary generator names and coefficients
    """
    # Setup
    terms = 0.0
    nw_data = pm.data["nw"]
    # Loop through hours
    for h in 1:length(nw_data)
        for (gen_name, coef) in linear_coef
            gen_index = parse(Int64, gen_name)
            try
                gen_term = coef * PowerModels.var(
                    pm, h, :pg, gen_index
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
    current_objective = JuMP.objective_function(pm.model)
    new_objective = @JuMP.expression(pm.model, current_objective + terms)
    JuMP.set_objective_function(pm.model, new_objective)

    return pm
end


function add_within_day_ramp_rates!(pm)
    """
    Add hourly ramp rates to model

    # Arguments
    `pm:: Any`: PowerModel with custom ramp rate defined
    """
    network_data_multi = pm.data["nw"]
    h_total = length(network_data_multi)

    for (obj_name, obj_props) in network_data_multi["1"]["gen"]
        try
            # Extract ramp rates to pu
            ramp = obj_props["cus_ramp_rate"]/100.0 
            
            obj_index = parse(Int, obj_name)
            try
                # Ramping up
                JuMP.@constraint(
                    pm.model,
                    [h in 2:h_total],
                    PowerModels.var(pm, h-1, :pg, obj_index) - PowerModels.var(pm, h, :pg, obj_index) <= ramp
                )
                # Ramping down
                JuMP.@constraint(
                    pm.model,
                    [h in 2:h_total],
                    PowerModels.var(pm, h, :pg, obj_index) - PowerModels.var(pm, h-1, :pg, obj_index) <= ramp
                )
            catch
                println(
                    """
                    Ramping constraint for generator $obj_index was specified but the corresponding decision variable was not found.
                    """
                )
            end
        catch
            try 
                # Check if reliabilty generator
                if obj_name not in network_data["reliability_gen"]
                    println("Ramping constraints not added for generator $obj_name")
                end
            catch
                # Skip adding ramp constraints as it's a reliability generator
            end
        end
    end

    return pm
end


function add_day_to_day_ramp_rates!(
    pm,
    state:: Dict{String, Dict},
    d:: Int64,
)
    """
    Add day-to-day ramp rates to model

    # Arguments
    `pm:: Any`: PowerModel with custom ramp rate defined
    `state:: Dict{String, Dict}`: Current state dictionary
    `d:: Int64`: Current day index
    """
    h = 1
    h_previous = 24
    results_previous_day = state["power"][string(d-1)]["solution"]["nw"]
    results_previous_hour = results_previous_day[string(h_previous)]
    network_data_multi = pm.data["nw"]
    
    for (obj_name, obj_props) in network_data_multi["1"]["gen"]
        # Extract ramp rates to pu
        ramp = obj_props["cus_ramp_rate"]/100.0 

        try
            # Previous power output
            pg_previous = results_previous_hour["gen"][obj_name]["pg"]

            # Ramping up
            obj_index = parse(Int, obj_name)
            JuMP.@constraint(
                pm.model,
                pg_previous - PowerModels.var(pm, h, :pg, obj_index) <= ramp
            )

            # Ramping down
            JuMP.@constraint(
                pm.model,
                PowerModels.var(pm, h, :pg, obj_index) - pg_previous <= ramp
            )
        catch
            println(
                """
                Day-to-day ramping constraint for generator $obj_name was specified but the corresponding decision variable was not found.
                """
            )
        end
    end
    return pm
end


function update_load!(network_data_multi::Dict, day_loads:: Dict)
    """
    Update loads for network data 

    # Arguments
    - `network_data_multi::Dict`: Multi network data
    - `day_loads:: Dict`: Loads for one day with buses as keys and loads as values
    """
    # Looping over hours
    for (h, network_data) in network_data_multi["nw"]

        # Looping over loads
        for load in values(network_data["load"])
            # Extracting load
            bus = string(load["load_bus"])
            load_mw = day_loads[h][bus]
            load_pu = load_mw/100.0

            # Set load
            load["pd"] = load_pu
        end
    end

    return network_data_multi
end


function add_reliability_gens!(network_data:: Dict)
    """
    Add fake generators at every load to model relaibility. Generators with
    more than 1000 name are reliability generators.

    # Arguments
    - `network_data:: Dict`: PowerModels network data
    """
    # Starting index for reliability generators
    reliability_start = 1000
    reliability_gen_ls = String[]

    for (obj_name, obj_props) in network_data["load"]
        # Generator name
        reliability_gen_name = string(obj_props["index"] + reliability_start)
        append!(reliability_gen_ls, [reliability_gen_name])

        # Generator properties
        network_data["gen"][reliability_gen_name] = Dict(
            "gen_bus" => obj_props["load_bus"],
            "cost" => [0.0, 1.0e10, 0.0],
            "gen_status" => 1,
            "pmin" => 0.0,
            "pmax" => 1e10,
            "model" => 2
        )
    end

    # Add to reliability generator list
    network_data["reliability_gen"] = reliability_gen_ls

    return network_data
end