using WaterPowerModels

using PowerModels
using Ipopt
using CSV
using JuMP
using YAML
using JLD2
using Statistics
using DataFrames
using XLSX

function main()
    # Initialization
    paths = YAML.load_file("analysis/paths.yml")
    power_results = Dict{String, Dict}()
    with_results = Dict{String, Dict}()
    con_results = Dict{String, Dict}()
    df_gen_info_water = DataFrames.DataFrame(CSV.File(paths["outputs"]["gen_info_water"]))
    df_eia_heat_rates = DataFrames.DataFrame(XLSX.readtable(paths["inputs"]["eia_heat_rates"], "Annual Data"))
    df_air_water = DataFrames.DataFrame(CSV.File(paths["outputs"]["df_air_water"]))

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

    # Initialize water use based on 25.0 C
    gen_beta_with = Dict{String, Dict}()
    gen_beta_con = Dict{String, Dict}()

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
        
        # Add penalties based on gen_beta_with and gen_beta_con
        current_objective = JuMP.objective_function(pm.model)
        a = -9999999.99999999999999 * PowerModels.var(pm, 1, :pg, 47)
        new_objective = @expression(pm.model, current_objective + a)
        set_objective_function(pm.model, new_objective)

        # Function
        # model = pm.model
        # add_water_terms!(model, beta_dict, w)

        # initialize empty water_terms
            # For h in hour
                # for g in generators
                    # Create beta term
                    # Apply weight
                    # Add to water_terms
        # Get current objectives
        # Create new objective
        # Set objective on model



        # Solve power system model
        day_results = PowerModels.optimize_model!(pm, optimizer=Ipopt.Optimizer)
        
        # Group generators
        df_gen_pg = WaterPowerModels.multi_network_to_df(
            day_results["solution"]["nw"],
            "gen",
            ["pg"]
        )
        df_gen_pg = DataFrames.combine(
            DataFrames.groupby(df_gen_pg, :obj_name),
            :pg => Statistics.mean
        )

        # Exogenous air and water temperatures
        d_pp = d - 1
        air_water = df_air_water[in([d_pp]).(df_air_water.Column1), :]
        air_temperature = air_water[!, "air_temperature"][1]
        water_temperature = air_water[!, "water_temperature"][1]

        # Water use
        gen_beta_with = Dict()
        gen_beta_con = Dict()
        for row in DataFrames.eachrow(df_gen_pg)
            # Get generator information
            gen_name = row["obj_name"]
            gen_info = df_gen_info[in([gen_name]).(df_gen_info.obj_name), :]
            fuel = string(gen_info[!, "MATPOWER Fuel"][1])
            cool = string(gen_info[!, "923 Cooling Type"][1])
            beta_with, beta_con = WaterPowerModels.daily_water_use(
                water_temperature,
                air_temperature,
                fuel,
                cool,
                df_eia_heat_rates
            )
            gen_beta_with[gen_name] = beta_with
            gen_beta_con[gen_name] = beta_con   
        end

        # Store results for that day
        power_results[string(d)] = day_results
        with_results[string(d)] = gen_beta_with
        con_results[string(d)] = gen_beta_con

    end
    # Checkpoint
    JLD2.save(paths["outputs"]["results"], power_results)
    power_results = JLD2.load(paths["outputs"]["results"])

    # Store states
    df_gen_states = WaterPowerModels.state_df(power_results, "gen", ["pg"])
    CSV.write(paths["outputs"]["df_gen_states"], df_gen_states)

    # Static network information
    CSV.write(paths["outputs"]["df_gen_info_pm"], df_gen_info_pm)

 end
 

 main()
