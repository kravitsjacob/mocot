using PowerModels
using WaterPowerModels
using Ipopt
using CSV
using JuMP


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


function main()
    # Initialization
    h_total = 24

    # Setting import paths
    paths = io()

    # Import static network
    network_data = PowerModels.parse_file(paths["inputs"]["case"])

    # Configure time-series properties
    network_data_multi = PowerModels.replicate(network_data, h_total)
    network_data_multi = WaterPowerModels.time_series_loads!(network_data_multi)

    # Create model
    pm = PowerModels.instantiate_model(
        network_data_multi,
        PowerModels.DCMPPowerModel,
        PowerModels.build_mn_opf
    )

    # Solve (no constraints)
    results_nc = PowerModels.optimize_model!(pm, optimizer=Ipopt.Optimizer)

    # Add ramping constraints
    pm = WaterPowerModels.add_ramping_constraints!(pm, h_total)

    # Solve (ramping constraints)
    results_ramp = PowerModels.optimize_model!(pm, optimizer=Ipopt.Optimizer)

    # Export
    df_load = WaterPowerModels.multi_network_to_df(network_data_multi["nw"], "load")
    CSV.write(paths["outputs"]["df_load"], df_load)
    df_gen = WaterPowerModels.multi_network_to_df(results_nc["solution"]["nw"], "gen")
    CSV.write(paths["outputs"]["df_gen_noramp"], df_gen)
    df_gen_info = WaterPowerModels.network_to_df(network_data, "gen")
    CSV.write(paths["outputs"]["df_gen_pminfo"], df_gen_info)
    df_gen_ramp = WaterPowerModels.multi_network_to_df(results_ramp["solution"]["nw"], "gen")
    CSV.write(paths["outputs"]["df_gen_ramp"], df_gen_ramp)

    formulation = JuMP.latex_formulation(pm.model)
    open(paths["outputs"]["formulation"], "w") do file
        write(file, string(formulation))
    end

 end
 

 main()
