"""Selecting a line for line outage scenario"""

using Infiltrator
using DataFrames
using PowerModels
using Ipopt
using JuMP
using YAML
using MOCOT

function main()
    # Import
    paths = YAML.load_file("paths.yml")
    (
        df_scenario_specs,
        df_eia_heat_rates,
        df_air_water,
        df_wind_cf,
        df_node_load,
        network_data,
        df_gen_info,
        decision_names,
        objective_names,
        metric_names
    ) = MOCOT.read_inputs(
        1,
        paths["inputs"]["scenario_specs"],
        paths["outputs"]["air_water_template"],
        paths["outputs"]["wind_capacity_factor_template"],
        paths["outputs"]["node_load_template"],       
        paths["outputs"]["gen_info_water_ramp_emit_waterlim"],
        paths["inputs"]["eia_heat_rates"],
        paths["inputs"]["case"],
        paths["inputs"]["decisions"],
        paths["inputs"]["objectives"],
        paths["inputs"]["metrics"],        
    )

    # Run powerflow
    pm = PowerModels.instantiate_model(
        network_data,
        PowerModels.DCPPowerModel,
        PowerModels.build_mn_opf
    )
    results = PowerModels.optimize_model!(
        pm,
        optimizer=JuMP.optimizer_with_attributes(Ipopt.Optimizer)
    )
    println("Original powerflow results")
    println(results["objective"])
    println(PowerModels.component_table(results["solution"], "gen", ["pg"]))


    # Remove line
    @Infiltrator.infiltrate
    df = DataFrames.DataFrame(
        PowerModels.component_table(
            results["solution"], "branch", ["pt", "pf"]
        ),
        :auto
    )
    println(sort(abs.(df), [:x2]))

    delete!(network_data["branch"], "158")

    # Run powerflow
    pm = PowerModels.instantiate_model(
        network_data,
        PowerModels.DCPPowerModel,
        PowerModels.build_mn_opf
    )
    results = PowerModels.optimize_model!(
        pm,
        optimizer=JuMP.optimizer_with_attributes(Ipopt.Optimizer)
    )
    println("Updated powerflow results")
    println(results["objective"])
    println(PowerModels.component_table(results["solution"], "gen", ["pg"]))

    return 0
end


main()
