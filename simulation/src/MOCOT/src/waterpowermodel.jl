"""WaterPowerModel"""


"""
A water extension of PowerModel
"""
struct WaterPowerModel
    "Generator names and objects"
    gens:: Dict
    "Network data from PowerModels.jl"
    network_data:: Dict
end


function create_reliabilty_network(model:: WaterPowerModel, voll:: Float64)
    """
    Add fake generators at every load to model relaibility. Generators with
    more than 1000 name are reliability generators.

    # Arguments
    - `model:: WaterPowerModel`: Water power model
    - `voll:: Float64`: Value of loss of load in pu
    """
    network_data_copy = deepcopy(model.network_data)

    # Starting index for reliability generators
    reliability_start = 1000
    reliability_gen_ls = String[]

    for (obj_name, obj_props) in network_data_copy["load"]
        # Generator name
        reliability_gen_name = string(obj_props["index"] + reliability_start)
        append!(reliability_gen_ls, [reliability_gen_name])

        # Generator properties
        network_data_copy["gen"][reliability_gen_name] = Dict(
            "gen_bus" => obj_props["load_bus"],
            "cost" => [0.0, voll, 0.0],
            "gen_status" => 1,
            "pmin" => 0.0,
            "pmax" => 1e10,
            "model" => 2
        )
    end

    return network_data_copy
end


function water_use_wrapper(
    model:: WaterPowerModel,
    inlet_temperature:: Float64,
    air_temperature:: Float64,
    regulatory_temperature:: Float64,
)
    """
    Run water use model for every generator
    
    # Arguments
    - `model:: WaterPowerModel`: Water and power model
    - `water_temperature:: Float64`: Water temperature in C
    - `air_temperature:: Float64`: Dry bulb temperature of inlet air C
    - `regulatory_temperature:: Float64`: Regulatory discharge tempearture in C
    """
    # Initialization
    gen_beta_with = Dict{String, Float64}()
    gen_beta_con = Dict{String, Float64}()
    gen_delta_t = Dict{String, Float64}()
    gen_discharge_violation = Dict{String, Float64}()

    # Water use for each generator
    for (gen_name, gen) in model.gens
        if typeof(gen) == OnceThroughGenerator

            # Run water simulation
            beta_with, beta_con, delta_t = MOCOT.get_water_use(
                gen,
                inlet_temperature,
                regulatory_temperature,
            )

            # Compute violation
            outlet_temperature = inlet_temperature + delta_t
            violation = outlet_temperature - regulatory_temperature
            if violation > 0.0
                gen_discharge_violation[gen_name] = violation
            end
        elseif typeof(gen) == RecirculatingGenerator
            # Run water simulation
            beta_with, beta_con = MOCOT.get_water_use(
                gen,
                air_temperature
            )
            
            # # Assume reciruclating systems do not violate
            delta_t = regulatory_temperature - inlet_temperature # C

        elseif typeof(gen) == NoCoolingGenerator
            beta_with = 0.0
            beta_con = 0.0
            delta_t = 0.0
        end

        # Store
        gen_beta_with[gen_name] = beta_with  # [L/MWh]
        gen_beta_con[gen_name] = beta_con  # [L/MWh]
        gen_delta_t[gen_name] = delta_t  # [C]
    end

    return gen_beta_with, gen_beta_con, gen_discharge_violation, gen_delta_t
end


function get_capacity_wrapper(
    model:: WaterPowerModel,
    gen_delta_T:: Dict,
    Q:: Float64,
)
    """
    Get generator capacity reductions

    # Arguments
    - `network_data:: Float64`: Network data
    - `gen_delta_T:: Dict`: Generator delta temperature [C]
    - `Q:: Float64`: Flow [cmps]
    """
    gen_capacity_reduction = Dict()
    gen_capacity = Dict()

    for (gen_name, gen) in model.gens
        if typeof(gen) == NoCoolingGenerator
            # No capacity impact
        else
            # Extract information
            delta_T = gen_delta_T[gen_name]
            KW = model.network_data["gen"][gen_name]["pmax"] * 100  # Convert to MW

            # Run water models
            if typeof(gen) == OnceThroughGenerator
                KW_updated = MOCOT.get_capacity(
                    gen,
                    KW,
                    delta_T,
                    Q,
                )

            elseif typeof(gen) == RecirculatingGenerator
                KW_updated = MOCOT.get_capacity(
                    gen,
                    KW,
                    delta_T,
                    Q,
                )

            end

            # Store 
            gen_capacity_reduction[gen_name] = KW - KW_updated  # [MW]
            gen_capacity[gen_name] = KW_updated  # [MW]

        end

    end

    return gen_capacity, gen_capacity_reduction
end
