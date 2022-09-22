module MOCOT


import PowerModels
import JuMP
import DataFrames
import Statistics
import Ipopt

# Dev packages
import Infiltrator  # @Infiltrator.infiltrate

include("utils.jl")
include("daily.jl")
include("hourly.jl")


function simulation(
    network_data:: Dict,
    exogenous:: Dict,
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
    - `network_data:: Dict`: PowerModels network data
    - `exogenous:: Dict`: Exogenous parameter data [<parameter_name>][<timestep>]...[<timestep>]
    - `w_with_coal:: Float64`: Coal withdrawal weight
    - `w_con_coal:: Float64`: Coal consumption weight
    - `w_with_ng:: Float64`: Natural gas withdrawal weight
    - `w_con_ng:: Float64`: Natural gas consumption weight
    - `w_with_nuc:: Float64`: Nuclear withdrawal weight
    - `w_con_nuc:: Float64`: Nuclear consumption weight
    """
    # Initialization
    d_total = length(exogenous["node_load"]) 
    h_total = length(exogenous["node_load"]["1"])
    state = Dict{String, Dict}()
    state["power"] = Dict("0" => Dict())
    state["withdraw_rate"] = Dict("0" => Dict{String, Float64}())
    state["consumption_rate"] = Dict("0" => Dict{String, Float64}())
    state["discharge_violation"] = Dict("0" => Dict{String, Float64}())

    # Processing decision vectors
    w_with = Dict{String, Float64}()
    w_con = Dict{String, Float64}()
    for (obj_name, obj_props) in network_data["gen"]
        try
            if obj_props["cus_fuel"] == "coal"
                w_with[obj_name] = w_with_coal
                w_con[obj_name] = w_con_coal
            elseif obj_props["cus_fuel"] == "ng"
                w_with[obj_name] = w_with_ng
                w_con[obj_name] = w_con_ng
            elseif obj_props["cus_fuel"] == "nuclear"
                w_with[obj_name] = w_with_nuc
                w_con[obj_name] = w_con_nuc
            else
                w_with[obj_name] = 0.0
                w_con[obj_name] = 0.0
            end
        catch
            try 
                # Check if reliabilty generator
                if obj_name not in network_data["reliability_gen"]
                    println("Weight not added for generator $obj_name")
                end
            catch
                # Skip adding weight as it's a reliability generator
            end
        end
    end

    # Adjust generator capacity
    network_data = MOCOT.update_all_gens!(network_data, "pmin", 0.0)

    # Add reliability generators
    voll = 330000.0  # $/pu for MISO
    network_data = MOCOT.add_reliability_gens!(network_data, voll)

    # Make multinetwork
    network_data_multi = PowerModels.replicate(network_data, h_total)

    # Initialize water use based on 25.0 C
    water_temperature = 25.0
    air_temperature = 25.0
    gen_beta_with, gen_beta_con = gen_water_use(
        water_temperature,
        air_temperature,
        network_data,
    )
    state["withdraw_rate"]["0"] = gen_beta_with
    state["consumption_rate"]["0"] = gen_beta_con

    # Simulation
    for d in 1:d_total
        println("Simulation Day: " * string(d))

        # Update loads
        network_data_multi = update_load!(
            network_data_multi,
            exogenous["node_load"][string(d)]
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
            multiply_dicts([state["withdraw_rate"][string(d-1)], w_with])
        )
        pm = add_linear_obj_terms!(
            pm,
            multiply_dicts([state["consumption_rate"][string(d-1)], w_con])
        )

        # Solve power system model
        state["power"][string(d)] = PowerModels.optimize_model!(
            pm,
            optimizer=JuMP.optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0)
        )

        # Water use
        gen_beta_with, gen_beta_con, gen_discharge_violation = gen_water_use(
            exogenous["water_temperature"][string(d)],
            exogenous["air_temperature"][string(d)],
            network_data,
        )
        state["discharge_violation"][string(d)] = gen_discharge_violation
        state["withdraw_rate"][string(d)] = gen_beta_with
        state["consumption_rate"][string(d)] = gen_beta_con
    end

    # Compute objectives
    objectives = get_objectives(state, network_data, w_with, w_con)

    # Console feedback
    println(Dict(
        "w_with_coal" => w_with_coal,
        "w_con_coal" => w_con_coal,
        "w_with_ng" => w_with_ng,
        "w_con_ng" => w_con_ng,
        "w_with_nuc" => w_with_nuc,
        "w_con_nuc" => w_con_nuc
    ))
    println(objectives)

    return (objectives, state)
end

end # module
