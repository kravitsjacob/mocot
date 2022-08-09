using WaterPowerModels

using PowerModels
using Ipopt
using CSV
using JuMP
using YAML
using JLD2
using DataFrames

function main()
    # Paths
    paths = YAML.load_file("analysis/paths.yml")
    results = Dict{String, Dict}()

    # Import static network
    h_total = 24
    d_total = 7
    network_data = PowerModels.parse_file(paths["inputs"]["case"])
    network_data_multi = PowerModels.replicate(network_data, h_total)

    # Exogenous imports
    df_node_load = DataFrames.DataFrame(CSV.File(paths["outputs"]["df_node_load"]))

    for d in 1:d_total
        # Update loads
        network_data_multi = WaterPowerModels.update_load!(
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

    # Static network information
    df_gen_info_pm = WaterPowerModels.network_to_df(network_data, "gen", ["gen_bus"])
    CSV.write(paths["outputs"]["df_gen_info_pm"], df_gen_info_pm)

 end
 

 main()
