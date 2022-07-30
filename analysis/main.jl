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

    # Setting import paths
    paths = io()

 end
 

 main()
