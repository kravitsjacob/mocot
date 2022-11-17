# Evaluations of simulation, useful for debugging

# Dev packages
using Revise
using Infiltrator  # @Infiltrator.infiltrate

using YAML
using CSV
using DataFrames

using MOCOT


function main()
    # Setup
    paths = YAML.load_file("paths.yml")

    # Reading policy configurations
    df_policies = DataFrames.DataFrame(
        CSV.File(paths["outputs"]["selected_policies"])
    )
    df_scenario_specs = DataFrames.DataFrame(
        CSV.File(
            paths["inputs"]["scenario_specs"],
            dateformat="yyyy-mm-dd HH:MM:SS"
        )
    ) 

    # Average scenario done
    df_scenario_performance = DataFrames.copy(df_policies)
    df_scenario_performance[!, "scenario"] .= "average week"

    # Simulate policies on all scenarios except average
    for scen_row in eachrow(df_scenario_specs[2:nrow(df_scenario_specs), :])
        scenario_name = scen_row["name"]
        scenario_code = scen_row["scenario_code"]

        # Run each simulation
        for pol_row in eachrow(df_policies)
            w_with = pol_row["w_with"]
            w_con = pol_row["w_con"]
            w_emit = pol_row["w_emit"]
            (objectives, state, metrics) = MOCOT.borg_simulation_wrapper(
                w_with,
                w_con,
                w_emit,
                2,
                0,
                scenario_code
            )

            # Storing
            df_temp = DataFrames.DataFrame(
                objectives
            )
            df_temp[:, "w_with"] .= pol_row["w_with"]        
            df_temp[:, "w_con"] .= pol_row["w_con"]     
            df_temp[:, "w_emit"] .= pol_row["w_emit"]         
            df_temp[:, "policy_label"] .= pol_row["policy_label"]
            df_temp[:, "scenario"] .= scenario_name
            DataFrames.append!(df_scenario_performance, df_temp)

            # Write as simulation occurs
            CSV.write(
                paths["outputs"]["selected_policy_performance"],
                df_scenario_performance
            )

        end

    end

end


main()
