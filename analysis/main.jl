using PowerModels
using Ipopt
using JuMP
using DataFrames
using CSV


function io()
    """
    Populate inputs and ouputs for analysis.
    """
    # Initialization
    paths = Dict{String, Dict}()
    inputs = Dict{String, String}()
    outputs = Dict{String, String}()

    # Path setting
    inputs["case"] = "analysis/io/inputs/ACTIVSg200/case_ACTIVSg200.m"
    outputs["df_load"] = "analysis/io/outputs/power_system/loads.csv"
    outputs["df_gen_noramp"] = "analysis/io/outputs/power_system/df_gen_noramp.csv"
    outputs["df_gen_pminfo"] = "analysis/io/outputs/power_system/df_gen_pminfo.csv"
    outputs["df_gen_ramp"] = "analysis/io/outputs/power_system/df_gen_ramp.csv"
    outputs["formulation"] = "analysis/io/outputs/power_system/formulation.txt"

    # Assign
    paths["inputs"] = inputs
    paths["outputs"] = outputs

    return paths
end 


function time_series_loads!(network_data_multi::Dict)
    """
    Create a time series loads.

    # Arguments
    - `n::Dict`: multi network data
    """
    # Create load factors
    morning = repeat([0.9], 6)
    mid = repeat([1.2], 8)
    afternoon = repeat([1.6], 4)
    night = repeat([0.9], 6)
    load_factors = vcat(morning, mid, afternoon, night)

    # Apply load factors
    for (h, network_timeslice) in network_data_multi["nw"]
        for load in values(network_timeslice["load"])
            load["pd"] = load_factors[parse(Int64, h)] * load["pd"]
        end
    end

    return network_data_multi::Dict
end


function network_to_df(data::Dict, obj_name::String)
    """
    Extract object from network

    # Arguments
    - `data::Dict`: Network data
    - `obj_name::String`: Name of object
    """
    # Initialization
    df = DataFrame()

    # Loop each object
    for (obj_name, obj_dict) in data[obj_name]
        # Drop multi-entry TODO flatten
        delete!(obj_dict, "source_id")
        delete!(obj_dict, "cost")

        # Object DataFrame
        df_obj = DataFrames.DataFrame(obj_dict)

        # Assign name
        df_obj[:, "name"] .= obj_name

        # Append to network dataframe
        DataFrames.append!(df, df_obj)
    end

    return df
end


function multi_network_to_df(nw_data::Dict, obj_name::String)
    """
    Extract object from multi network

    # Arguments
    - `nw_data::Dict`: multi network data (network_data_multi["nw"])
    - `obj_name::Dict`: multi network data
    """
    # TODO should call network_to_df
    # Initialization
    df = DataFrame()

    # Loop through hours
    for h in 1:length(nw_data)

        # Loop each object in the hour
        for (obj_name, obj_dict) in nw_data[string(h)][obj_name]
            # Drop source_id
            delete!(obj_dict, "source_id")

            # Object DataFrame
            df_obj = DataFrames.DataFrame(obj_dict)

            # Assign name
            df_obj[:, "name"] .= obj_name

            # Assign hour
            df_obj[:, "hour"] .= h

            # Append to network dataframe
            DataFrames.append!(df, df_obj)
        end
    end
    
    return df

end


function add_ramping_constraints!(pm, h_total)
    """
    Add generator ramping constraints to nuclear generator

    # Arguments
    - `pm`: Power model
    - `h_total::Int64`: Number of hours 
    """
    ramp_up = 1.0
    ramp_down = 1.0
    gen_name = 47

    begin
        # Ramping up
        JuMP.@constraint(
            pm.model,
            [h in 1:h_total-1],
            var(pm, h+1, :pg, gen_name) - var(pm, h, :pg, gen_name) <= ramp_up
        )
        # Ramping up
        JuMP.@constraint(
            pm.model,
            [h in 2:h_total],
            var(pm, h-1, :pg, gen_name) - var(pm, h, :pg, gen_name) <= ramp_down
        )
    end
    return pm
end


function main()
    # Initialization
    h_total = 24

    # Setting import paths
    paths = io()

    # Import static network
    network_data = PowerModels.parse_file(paths["inputs"]["case"])

    # Configure time-series properties
    network_data_multi = PowerModels.replicate(network_data, h_total)
    network_data_multi = time_series_loads!(network_data_multi)

    # Create model
    pm = PowerModels.instantiate_model(
        network_data_multi,
        PowerModels.DCMPPowerModel,
        PowerModels.build_mn_opf
    )

    # Solve (no constraints)
    results_nc = PowerModels.optimize_model!(pm, optimizer=Ipopt.Optimizer)

    # Add ramping constraints
    pm = add_ramping_constraints!(pm, h_total)

    # Solve (ramping constraints)
    results_ramp = PowerModels.optimize_model!(pm, optimizer=Ipopt.Optimizer)

    # Export
    df_load = multi_network_to_df(network_data_multi["nw"], "load")
    CSV.write(paths["outputs"]["df_load"], df_load)
    df_gen = multi_network_to_df(results_nc["solution"]["nw"], "gen")
    CSV.write(paths["outputs"]["df_gen_noramp"], df_gen)
    df_gen_info = network_to_df(network_data, "gen")
    CSV.write(paths["outputs"]["df_gen_pminfo"], df_gen_info)
    df_gen_ramp = multi_network_to_df(results_ramp["solution"]["nw"], "gen")
    CSV.write(paths["outputs"]["df_gen_ramp"], df_gen_ramp)

    formulation = JuMP.latex_formulation(pm.model)
    open(paths["outputs"]["formulation"], "w") do file
        write(file, string(formulation))
    end

 end
 

 main()
