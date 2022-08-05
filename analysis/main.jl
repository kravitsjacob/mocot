using WaterPowerModels

using PowerModels
using Ipopt
using CSV
using JuMP
using YAML
using JLD2

function main()
    # Paths
    paths = YAML.load_file("analysis/paths.yml")
    results = Dict{String, Dict}()

    # Import static network
    h_total = 24
    d_total = 7
    network_data = PowerModels.parse_file(paths["inputs"]["case"])
    network_data_multi = PowerModels.replicate(network_data, h_total)
    
    for d in 1:d_total

        # Create power system model
        pm = PowerModels.instantiate_model(
            network_data_multi,
            PowerModels.DCPPowerModel,
            PowerModels.build_mn_opf
        )

        # Solve power system model
        day_results = PowerModels.optimize_model!(pm, optimizer=Ipopt.Optimizer)
        
        # Store results for that day
        results[string(d)] = day_results

    end

    # Checkpoint
    JLD2.save(paths["outputs"]["results"], results)
    results = JLD2.load(paths["outputs"]["results"])

    # Store states
    df_gen_states = WaterPowerModels.state_df(results, "gen", ["pg"])
    CSV.write(paths["outputs"]["df_gen_states"], df_gen_states)

 end
 

 main()
