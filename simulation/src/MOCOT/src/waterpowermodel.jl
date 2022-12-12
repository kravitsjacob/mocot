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


function add_reliability_gens!(model:: WaterPowerModel, voll:: Float64)
    """
    Add fake generators at every load to model relaibility. Generators with
    more than 1000 name are reliability generators.

    # Arguments
    - `model:: WaterPowerModel`: Water power model
    - `voll:: Float64`: Value of loss of load in pu
    """
    # Starting index for reliability generators
    reliability_start = 1000
    reliability_gen_ls = String[]

    for (obj_name, obj_props) in model.network_data["load"]
        # Generator name
        reliability_gen_name = string(obj_props["index"] + reliability_start)
        append!(reliability_gen_ls, [reliability_gen_name])

        # Generator properties
        model.network_data["gen"][reliability_gen_name] = Dict(
            "gen_bus" => obj_props["load_bus"],
            "cost" => [0.0, voll, 0.0],
            "gen_status" => 1,
            "pmin" => 0.0,
            "pmax" => 1e10,
            "model" => 2
        )
    end

    # Add to reliability generator list
    model.network_data["reliability_gen"] = reliability_gen_ls

    return model
end

