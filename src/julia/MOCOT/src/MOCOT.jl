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
include("hourly.jl")


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
    w_with = Dict{String, Float64}()
    w_con = Dict{String, Float64}()
    for row in DataFrames.eachrow(df_gen_info)
        gen_ramp[string(row["obj_name"])] = float(row["Ramp Rate (MW/hr)"])
        if row["MATPOWER Fuel"] == "coal"
            w_with[string(row["obj_name"])] = w_with_coal
            w_con[string(row["obj_name"])] = w_con_coal
        elseif row["MATPOWER Fuel"] == "ng"
            w_with[string(row["obj_name"])] = w_with_ng
            w_con[string(row["obj_name"])] = w_con_ng
        elseif row["MATPOWER Fuel"] == "nuclear"
            w_with[string(row["obj_name"])] = w_with_nuc
            w_con[string(row["obj_name"])] = w_con_nuc
        else
            w_with[string(row["obj_name"])] = 0.0
            w_con[string(row["obj_name"])] = 0.0
        end
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
        network_data_multi = update_load!(
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
        pm = add_water_terms!(
            pm,
            state["withdraw_rate"][string(d-1)],
            w_with
        )
        pm = add_water_terms!(
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
        gen_beta_with, gen_beta_con = gen_water_use(
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
