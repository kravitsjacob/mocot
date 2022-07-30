using PowerModels
using Ipopt
using JuMP


function io()
    """
    Inputs and ouputs for analysis
    """
    # Initialization
    paths = Dict{String, Dict}()
    inputs = Dict{String, String}()
    outputs = Dict{String, String}()

    # Path setting
    inputs["case"] = "analysis/io/inputs/ACTIVSg200/case_ACTIVSg200.m"

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

    network_data_multi["nw"]["1"]["load"]["1"]["pd"] = 2.0

    # Create model
    pm3 = PowerModels.instantiate_model(
        network_data_multi,
        PowerModels.DCMPPowerModel,
        PowerModels.build_mn_opf
    )


    # Solve
    results = PowerModels.optimize_model!(pm3, optimizer=Ipopt.Optimizer)
    println(string(results["solution"]["nw"]["1"]["gen"]["4"]["pg"]))
    println(string(results["solution"]["nw"]["2"]["gen"]["4"]["pg"]))
    println(string(results["solution"]["nw"]["3"]["gen"]["4"]["pg"]))

    formulation = JuMP.latex_formulation(pm3.model)
    open("formulaton.txt", "w") do file
        write(file, string(formulation))
    JuMP.objective_function_type(pm3.model)
    end
 end
 

 main()
