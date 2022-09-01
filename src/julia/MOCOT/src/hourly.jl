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
    `pm:: Any`: Any PowerModel
    """
    multi_network_data = pm.data["nw"]
    h_total = length(multi_network_data)
    
    for (obj_name, obj_props) in multi_network_data["1"]["gen"]
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
    end

    return pm
end


function add_day_to_day_ramp_rates!(
    pm,
    gen_ramp:: Dict{String, Float64},
    state:: Dict{String, Dict},
    d:: Int64,
)
    """
    Add day-to-day ramp rates to model

    # Arguments
    `pm:: Any`: Any PowerModel
    `gen_ramp:: Dict{String, Float64}`: Dictionary ramp values for each generator
    `state:: Dict{String, Dict}`: Current state dictionary
    `d:: Int64`: Current day index
    """
    h = 1
    h_previous = 24
    results_previous_day = state["power"][string(d-1)]["solution"]["nw"]
    results_previous_hour = results_previous_day[string(h_previous)]

    for gen_name in keys(gen_ramp)
        # Extract ramp rates to pu
        ramp = gen_ramp[gen_name]/100.0 

        try
            # Previous power output
            pg_previous = results_previous_hour["gen"][gen_name]["pg"]

            # Ramping up
            gen_index = parse(Int, gen_name)
            JuMP.@constraint(
                pm.model,
                pg_previous - PowerModels.var(pm, h, :pg, gen_index) <= ramp
            )

            # Ramping down
            JuMP.@constraint(
                pm.model,
                PowerModels.var(pm, h, :pg, gen_index) - pg_previous <= ramp
            )
        catch
            println(
                """
                Day-to-day ramping constraint for generator $gen_name was specified but the corresponding decision variable was not found.
                """
            )
        end
    end
    return pm
end
