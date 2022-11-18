"""Selecting policies based on engineering judgement"""

# Dev packages
using Revise
using Infiltrator  # @Infiltrator.infiltrate

using YAML
using CSV
using DataFrames
using MOCOT


function find_engineering_judgement_weight(
    left_start:: Float64,
    right_start:: Float64,
    simulation,
    search_epsilon=0.0005,
    objective_epsilon=10,
)
    """
    Simple algorithm that mimics the process of manually checking

    # Arguments
    - `left_start:: Float64`: Left starting guess
    - `right_start:: Float64`: Right starting guess
    - `simulation`: Single argument function
    - `search_epsilon:: Float64`: Search tollerance, dictates end of search
    - `objective_epsilon:: Float64`: Equality tollerance
    """
    # Initialization
    left_val = left_start
    right_val = right_start
    left_obj_val = simulation(left_val)
    right_obj_val = simulation(right_val)

    while right_val - left_val > search_epsilon
        # Bisect
        bisect_val = bisect(left_val, right_val)
        bisect_obj_val = simulation(bisect_val)

        # Bisect lays on minimum
        if abs(bisect_obj_val - right_obj_val) < objective_epsilon
            right_val = bisect_val
            right_obj_val = bisect_obj_val

        # Bisect lays above minimum
        elseif bisect_obj_val > right_obj_val
            left_val = bisect_val
            left_obj_val = bisect_obj_val
        end

        println("Right value $right_val")
        println("Right objective value $right_obj_val")
        println("Left value $left_val")
        println("Left objective value $left_obj_val")
    end

    return right_val

end


function bisect(left_val, right_val)
    """
    Bisect values

    # Arguments
    - `left_val:: Float64`: Left value
    - `right_val:: Float64`: Right value
    """
    return (left_val+right_val)/2.0
end


function main()
    # Setup
    paths = YAML.load_file("paths.yml")

    # Find engineering judgement w_with
    w_with = find_engineering_judgement_weight(
        0.034,
        0.036,
        function (x)
            (objectives, state, metrics) = MOCOT.borg_simulation_wrapper(x, 0.0, 0.0, 2, 0, 1)
            return objectives["f_with_tot"]
        end
    )

    # Find engineering judgement w_con
    w_con = find_engineering_judgement_weight(
        0.009,
        0.010,
        function (x)
            (objectives, state, metrics) = MOCOT.borg_simulation_wrapper(0.0, x, 0.0, 2, 0, 1)
            return objectives["f_con_tot"]
        end
    )

    # Find engineering judgement w_emit
    w_emit = find_engineering_judgement_weight(
        0.004,
        0.006,
        function (x)
            (objectives, state, metrics) = MOCOT.borg_simulation_wrapper(0.0, 0.0, x, 2, 0, 1)
            return objectives["f_emit"]
        end
    )

    # Export
    df = DataFrames.DataFrame(Dict(
        "w_with"=>w_with,
        "w_con"=>w_con,
        "w_emit"=>w_emit,
    ))
    CSV.write(
        paths["outputs"]["judgement_policies"],
        df
    )

end


main()
