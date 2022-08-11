using WaterPowerModels

using PowerModels
using Ipopt
using CSV
using JuMP
using YAML
using JLD2
using Statistics
using DataFrames

function main()
    # Initialization
    paths = YAML.load_file("analysis/paths.yml")
    results = Dict{String, Dict}()
    df_gen_info_water = DataFrames.DataFrame(CSV.File(paths["outputs"]["gen_info_water"]))

    # Import static network
    h_total = 24
    d_total = 7
    network_data = PowerModels.parse_file(paths["inputs"]["case"])
    network_data_multi = PowerModels.replicate(network_data, h_total)

    # Static network information
    df_gen_info_pm = WaterPowerModels.network_to_df(network_data, "gen", ["gen_bus"])
    df_gen_info = DataFrames.leftjoin(
        df_gen_info_pm,
        df_gen_info_water,
        on = :gen_bus => Symbol("MATPOWER Index")
    )

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
        
        # Water use
        df_gen_pg = WaterPowerModels.multi_network_to_df(
            day_results["solution"]["nw"],
            "gen",
            ["pg"]
        )
        df_gen_pg = DataFrames.combine(
            DataFrames.groupby(df_gen_pg, :obj_name),
            :pg => Statistics.mean
        )
        for row in DataFrames.eachrow(df_gen_pg)
            @infiltrate
            daily_water_use(
                water_temperature:: Float64,
                air_temperature:: Float64,
                fuel:: String,
                cool:: String,
                df_eia_heat_rates:: DataFrames.DataFrame
            )
            
        end

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
    CSV.write(paths["outputs"]["df_gen_info_pm"], df_gen_info_pm)

 end
 

 main()
