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
    morning = repeat([0.5], 6)
    mid = repeat([0.9], 6)
    afternoon = repeat([1.4], 6)
    night = repeat([0.5], 6)
    load_factors = vcat(morning, mid, afternoon, night)

    # Apply load factors
    for (h, network_timeslice) in network_data_multi["nw"]
        for load in values(network_timeslice["load"])
            load["pd"] = load_factors[parse(Int64, h)] * load["pd"]
        end
    end

    return network_data_multi
end


function multi_network_to_df(network_data_multi::Dict, obj_name::String)
    """
    Extract object from multi network

    # Arguments
    - `network_data_multi::Dict`: multi network data
    - `obj_name::Dict`: multi network data
    """
    # Initialization
    df = DataFrame()

    # Loop through hours
    for h in 1:length(network_data_multi["nw"])

        # Loop each load in the hour
        for (obj_name, obj_dict) in network_data_multi["nw"][string(h)][obj_name]
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
    pm3 = PowerModels.instantiate_model(
        network_data_multi,
        PowerModels.DCMPPowerModel,
        PowerModels.build_mn_opf
    )

    # Solve
    results = PowerModels.optimize_model!(pm3, optimizer=Ipopt.Optimizer)

    # Output
    println(string(results["solution"]["nw"]["1"]["gen"]["4"]["pg"]))
    println(string(results["solution"]["nw"]["2"]["gen"]["4"]["pg"]))
    println(string(results["solution"]["nw"]["3"]["gen"]["4"]["pg"]))

    # Export
    df_load = multi_network_to_df(network_data_multi, "load")
    CSV.write(paths["outputs"]["df_load"], df_load)

    formulation = JuMP.latex_formulation(pm3.model)
    open("formulaton.txt", "w") do file
        write(file, string(formulation))

    JuMP.objective_function_type(pm3.model)
    end
 end
 

 main()
