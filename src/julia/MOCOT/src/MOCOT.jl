module MOCOT

import PowerModels
import JuMP
import DataFrames
import Statistics
import Ipopt
import Infiltrator
import CSV

include("read.jl")
include("utils.jl")
include("daily.jl")

function update_load!(network_data_multi::Dict, df_node_load:: DataFrames.DataFrame, d::Int)
    """
    Update loads for network data 

    # Arguments
    - `network_data_multi::Dict`: Multi network data
    - `df_node_load::DataFrames.DataFrame`: DataFrame of node-level loads
    - `d::Int`: Day index
    """
    for h in 1:length(network_data_multi["nw"])
        # Extract network data
        nw_data = network_data_multi["nw"][string(h)]

        for load in values(nw_data["load"])
            # Pandapower indexing
            pp_bus = load["load_bus"] - 1
            
            # Filters
            df_node_load_filter = df_node_load[in(d).(df_node_load.day_index), :]
            df_node_load_filter = df_node_load_filter[in(h).(df_node_load_filter.hour_index), :]
            df_node_load_filter = df_node_load_filter[in(pp_bus).(df_node_load_filter.bus), :]
            load_mw = df_node_load_filter[!, "load_mw"][1]
            load_pu = load_mw/100.0

            # Set load
            load["pd"] = load_pu
        end
    end

    return network_data_multi
end


function pm_state_df(results, obj_type, props)
    """
    Extract states from day-resolution powermodels multi-network data (at hourly-resolution)

    # Arguments
    - `nw_data::Dict`: multi network data (e.g., network_data_multi["nw"])
    - `obj_type::String`: Type of object (e.g., "gen")
    - `props::Array`: Object properties to extract
    """

    # Initialization
    df = DataFrames.DataFrame()

    for d in 1:length(results)-1

        # Extract day data
        day_results = results[string(d)]

        # Get results for that day
        df_day = multi_network_to_df(
            day_results["solution"]["nw"],
            obj_type,
            props
        )

        # Assign day
        df_day[:, "day"] .= string(d)

        # Append to state dataframe
        DataFrames.append!(df, df_day)
    end

    return df
end


function custom_state_df(state:: Dict{String, Dict}, prop:: String)
    """
    Extract states dataframe from day-resolution state dictionary

    # Arguments
    - `state:: Dict{String, Dict}`: State dictionary
    - `prop:: String`: Property to query
    """
    # Initialization
    df = DataFrames.DataFrame()

    prop_state = state[prop]

    for d in keys(prop_state)

        # Get data for one day
        df_day = DataFrames.stack(DataFrames.DataFrame(prop_state[string(d)]))

        # Cleaning data
        DataFrames.rename!(df_day, :variable => :obj_name, :value => Symbol(prop))

        # Assign day
        df_day[:, "day"] .= string(d)

        # Append to state dataframe
        DataFrames.append!(df, df_day)
    end

    return df
end


function multi_network_to_df(multi_nw_data::Dict, obj_type::String, props::Array)
    """
    Extract object information from hourly-resolution multi network data

    # Arguments
    - `nw_data::Dict`: multi network data (e.g., network_data_multi["nw"])
    - `obj_type::String`: Type of object (e.g., "gen")
    - `props::Array`: Object properties to extract
    """
    # Initialization
    df = DataFrames.DataFrame()

    # Loop through hours
    for h in 1:length(multi_nw_data)

        # Extract network data
        nw_data = multi_nw_data[string(h)]
        
        # Convert to dataframe
        df_temp = network_to_df(nw_data, obj_type, props)

        # Add timestep
        df_temp[:, "hour"] .= string(h)

        # Append to network dataframe
        DataFrames.append!(df, df_temp)
    end
    
    return df
end


function network_to_df(nw_data::Dict, obj_type::String, props::Array)
    """
    Extract dataframe from network

    # Arguments
    - `data::Dict`: Network data
    - `obj_type::String`: Type of object (e.g., "gen")
    - `props::Array`: Object properties to extract
    """
    # Dev note, potentially the same as Replace with PowerModels.component_table(pm.data["nw"][string(h)], "gen", ["pg"])

    # Initialization
    df = DataFrames.DataFrame()

    # Loop each object
    for (obj_name, obj_dict) in nw_data[obj_type]
        # Get properties
        filtered_obj_dict=Dict{String, Any}()
        for prop in props
            filtered_obj_dict[prop] = obj_dict[prop]
        end

        # Add name
        filtered_obj_dict["obj_name"] = obj_name

        # Object DataFrame
        df_obj = DataFrames.DataFrame(filtered_obj_dict)

        # Append to network dataframe
        DataFrames.append!(df, df_obj)
    end

    return df
end


function add_water_terms!(
    pm,
    beta_dict:: Dict{String, Float64},
    w:: Float64,
)
    """
    Add water use terms to objective function
    
    # Arguments
    `pm:: Any`: Any PowerModel
    `beta_dict:: Dict{String, Float64}`: Dictionary of beta values
    `w:: Float64`: Weight for water use
    """
    # Setup
    water_terms = 0.0
    nw_data = pm.data["nw"]

    # Loop through hours
    for h in 1:length(nw_data)
        for (gen_name, beta_val) in beta_dict
            gen_index = parse(Int64, gen_name)
            gen_water_term = w * beta_val * PowerModels.var(
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


function simulation(
    network_data:: Dict,
    df_gen_info:: DataFrames.DataFrame,
    df_eia_heat_rates:: DataFrames.DataFrame, 
    df_air_water:: DataFrames.DataFrame,
    df_node_load:: DataFrames.DataFrame,
    ;
    w_with_coal:: Float64=0.0,
    w_con_coal:: Float64=0.0,
    w_with_ng:: Float64=0.0,
    w_con_ng:: Float64=0.0,
    w_with_nuc:: Float64=0.0,
    w_con_nuc:: Float64=0.0,
)
    """
    Simulation of water and energy system

    # Arguments
    - `network_data:: Dict`: PowerModels Network data
    - `df_gen_info:: DataFrames.DataFrame`: Generator information
    - `df_eia_heat_rates:: DataFrames.DataFrame`: EIA heat rates
    - `df_air_water:: DataFrames.DataFrame`: Exogenous air and water temperatures
    - `df_node_load:: DataFrames.DataFrame`: Node-level loads
    - `w_with_coal:: Float64`: Coal withdrawal weight
    - `w_con_coal:: Float64`: Coal consumption weight
    - `w_with_ng:: Float64`: Natural gas withdrawal weight
    - `w_con_ng:: Float64`: Natural gas consumption weight
    - `w_with_nuc:: Float64`: Nuclear withdrawal weight
    - `w_con_nuc:: Float64`: Nuclear consumption weight
    """
    # Initialization
    d_total = trunc(Int64, maximum(df_node_load[!, "day_index"])) 
    h_total = trunc(Int64, maximum(df_node_load[!, "hour_index"]))
    state = Dict{String, Dict}()
    state["power"] = Dict("0" => Dict())
    state["withdraw_rate"] = Dict("0" => Dict{String, Float64}())
    state["consumption_rate"] = Dict("0" => Dict{String, Float64}())

    # Prepare generator ramping
    gen_ramp = Dict{String, Float64}()
    for row in DataFrames.eachrow(df_gen_info)
        gen_ramp[string(row["obj_name"])] = float(row["Ramp Rate (MW/hr)"])
    end

    # Commit all generators
    network_data = set_all_gens!(network_data, "gen_status", 1)
    network_data = set_all_gens!(network_data, "pmin", 0.0)

    # Make multinetwork
    network_data_multi = PowerModels.replicate(network_data, h_total)

    # Initialize water use based on 25.0 C
    water_temperature = 25.0
    air_temperature = 25.0
    gen_beta_with, gen_beta_con = gen_water_use(
        water_temperature,
        air_temperature,
        df_gen_info,
        df_eia_heat_rates
    )
    state["withdraw_rate"]["0"] = gen_beta_with
    state["consumption_rate"]["0"] = gen_beta_con

    # Simulation
    for d in 1:d_total
        # Update loads
        network_data_multi = MOCOT.update_load!(
            network_data_multi,
            df_node_load,
            d
        )

        # Create power system model
        pm = PowerModels.instantiate_model(
            network_data_multi,
            PowerModels.DCPPowerModel,
            PowerModels.build_mn_opf
        )

        # Add ramp rates
        pm = add_within_day_ramp_rates!(pm, gen_ramp)
        
        if d > 1
            pm = add_day_to_day_ramp_rates!(pm, gen_ramp, state, d)
        end

        # Add water use penalities
        pm = MOCOT.add_water_terms!(
            pm,
            state["withdraw_rate"][string(d-1)],
            w_with
        )
        pm = MOCOT.add_water_terms!(
            pm,
            state["consumption_rate"][string(d-1)],
            w_con
        )

        # Solve power system model
        state["power"][string(d)] = PowerModels.optimize_model!(pm, optimizer=Ipopt.Optimizer)

        # Exogenous air and water temperatures
        filter_air_water = df_air_water[in([d]).(df_air_water.day_index), :]
        air_temperature = filter_air_water[!, "air_temperature"][1]
        water_temperature = filter_air_water[!, "water_temperature"][1]

        # Water use
        gen_beta_with, gen_beta_con = MOCOT.gen_water_use(
            water_temperature,
            air_temperature,
            df_gen_info,
            df_eia_heat_rates
        )
        state["withdraw_rate"][string(d)] = gen_beta_with
        state["consumption_rate"][string(d)] = gen_beta_con
    end

    # Compute objectives
    objectives = get_objectives(state, network_data)

    return (objectives, state)
end

function get_objectives(
    state:: Dict{String, Dict},
    network_data:: Dict{String, Any}
)
    """
    Computing simulation objectives
    
    # Arguments
    - `state:: Dict{String, Dict}`: State dictionary
    - `network_data:: Dict`: PowerModels Network data
    """
    objectives = Dict{String, Float64}()

    # Cost coefficients
    cost_tab = PowerModels.component_table(network_data, "gen", ["cost"])
    df_cost = DataFrames.DataFrame(cost_tab, ["obj_name", "cost"])
    df_cost[!, "obj_name"] = string.(df_cost[!, "obj_name"])
    df_cost[!, "c_per_mw2_pu"] = extract_from_array_column(df_cost[!, "cost"], 1)
    df_cost[!, "c_per_mw_pu"] = extract_from_array_column(df_cost[!, "cost"], 2)
    df_cost[!, "c"] = extract_from_array_column(df_cost[!, "cost"], 3)

    # Organize states
    df_withdraw = MOCOT.custom_state_df(state, "withdraw_rate")
    df_consumption = MOCOT.custom_state_df(state, "consumption_rate")
    df_gen_states = MOCOT.pm_state_df(state["power"], "gen", ["pg"])

    # Combine into one dataframe
    df = DataFrames.leftjoin(
        df_gen_states,
        df_withdraw,
        on = [:obj_name, :day]
    )
    df = DataFrames.leftjoin(
        df,
        df_consumption,
        on = [:obj_name, :day]
    )
    df = DataFrames.leftjoin(
        df,
        df_cost,
        on = [:obj_name]
    )

    # Compute cost objectives
    objectives["f_gen"] = DataFrames.sum(DataFrames.skipmissing(
        df.c .+ df.pg .* df.c_per_mw_pu .+ df.pg.^2 .* df.c_per_mw2_pu
    ))

    # Compute water objectives
    objectives["f_with"] = DataFrames.sum(df[!, "pg"] .* 100.0 .* df[!, "withdraw_rate"])  # Per unit conversion
    objectives["f_con"] = DataFrames.sum(df[!, "pg"] .* 100.0 .* df[!, "consumption_rate"])  # Per unit conversion

    return objectives
end

function extract_from_array_column(array_col, i:: Int)
    """
    Extract elements from a DataFrame column of arrays

    # Arguments
    - `array_col`: DataFrame column of array (e.g., df.col)
    - `i:: Int`: Index to retrieve
    """
    extract = map(eachrow(array_col)) do row
        try
            row[1][i]
        catch
            missing
        end
    end

    return extract
end

end # module
