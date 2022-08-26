# Functions for hourly-resolution model


function add_water_terms!(
    pm,
    beta_dict:: Dict{String, Float64},
    w:: Dict{String, Float64},
)
    """
    Add water use terms to objective function
    
    # Arguments
    `pm:: Any`: Any PowerModel
    `beta_dict:: Dict{String, Float64}`: Dictionary of beta values
    `w:: Dict{String, Float64}`: Weight for water use
    """
    # Setup
    water_terms = 0.0
    nw_data = pm.data["nw"]

    # Loop through hours
    for h in 1:length(nw_data)
        for (gen_name, beta_val) in beta_dict
            gen_index = parse(Int64, gen_name)
            gen_water_term = w[gen_name] * beta_val * PowerModels.var(
                pm, h, :pg, gen_index
            )
            water_terms = water_terms + gen_water_term
        end
    end
    
    # Update objective function
    current_objective = JuMP.objective_function(pm.model)
    new_objective = @JuMP.expression(pm.model, current_objective + water_terms)
    JuMP.set_objective_function(pm.model, new_objective)

    return pm
end


function add_within_day_ramp_rates!(
    pm,
    gen_ramp:: Dict{String, Float64},
)
    """
    Add hourly ramp rates to model

    # Arguments
    `pm:: Any`: Any PowerModel
    `gen_ramp:: Dict{String, Float64}`: Dictionary ramp values for each generator
    """
    h_total = length(pm.data["nw"])

    for gen_name in keys(gen_ramp)
        # Extract ramp rates to pu
        ramp = gen_ramp[gen_name]/100.0 
        
        gen_index = parse(Int, gen_name)
        # Ramping up
        JuMP.@constraint(
            pm.model,
            [h in 2:h_total],
            PowerModels.var(pm, h-1, :pg, gen_index) - PowerModels.var(pm, h, :pg, gen_index) <= ramp
        )
        # Ramping down
        JuMP.@constraint(
            pm.model,
            [h in 2:h_total],
            PowerModels.var(pm, h, :pg, gen_index) - PowerModels.var(pm, h-1, :pg, gen_index) <= ramp
        )
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
    end
    return pm
end
