# Functions for running at a daily-resolution simulation


function get_k_os(fuel:: String)
    """
    Get other sinks fraction from DOE-NETL reference models

    # Arguments
    `fuel:: String`: Fuel code
    """
    if fuel == "coal"
        k_os = 0.12
    elseif fuel == "ng"
        k_os = 0.20
    elseif fuel == "nuclear"
        k_os = 0.0
    elseif fuel == "wind"
        k_os = 0.0
    end

    return k_os
end


function get_beta_proc(fuel:: String)
    """
    Get water withdrawal from non-cooling processes in [L/MWh] based on DOE-NETL model

    # Arguments
    `fuel:: String`: Fuel code
    """
    if fuel == "coal"
        beta_proc = 200.0
    else
        beta_proc = 10.0
    end

    return beta_proc
end


function get_k_sens(t_inlet:: Float64)
    """
    Get heat load rejected through convection

    # Arguments
    `t_inlet:: Float64`: Dry bulb temperature of inlet air [C]
    """
    term_1 = -0.000279*t_inlet^3
    term_2 = 0.00109*t_inlet^2
    term_3 = -0.345*t_inlet
    k_sens = term_1 + term_2 + term_3 + 26.7
    k_sens = k_sens/100  # Convert to ratio
    return k_sens
end


function recirculating_water_use(
    air_temperature,
    eta_net, 
    k_os, 
    beta_proc, 
    eta_cc=5
)
    """
    Recirculating water use (withdrawal and consumption)

    # Arguments
    - `air_temperature:: Float64`: Air temperature in C
    - `eta_net:: Float64`: Ratio of electricity generation rate to thermal input
    - `k_os:: Float64`: Thermal input lost to non-cooling system sinks
    - `beta_proc:: Float64`: Non-cooling rate in [L/MWh]
    - `eta_cc:: Int64`: Number of cooling cycles between 2 and 10
    """
    # Get k_sens
    k_sens = get_k_sens(air_temperature)

    # Water models
    beta_with = recirculating_withdrawal(
        eta_net=eta_net, 
        k_os=k_os, 
        beta_proc=beta_proc, 
        eta_cc=eta_cc, 
        k_sens=k_sens
    )
    beta_con = recirculating_consumption(
        eta_net=eta_net,
        k_os=k_os,
        beta_proc=beta_proc,
        eta_cc=eta_cc,
        k_sens=k_sens,
    )

    return beta_with, beta_con
end

function gen_water_use_wrapper(
    inlet_temperature:: Float64,
    air_temperature:: Float64,
    regulatory_temperature:: Float64,
    network_data:: Dict
)
    """
    Run water use model for every generator
    
    # Arguments
    - `water_temperature:: Float64`: Water temperature in C
    - `air_temperature:: Float64`: Dry bulb temperature of inlet air C
    - `regulatory_temperature:: Float64`: Regulatory discharge tempearture in C
    - `network_data:: Dict`: PowerModels network data
    """
    # Initialization
    gen_beta_with = Dict{String, Float64}()
    gen_beta_con = Dict{String, Float64}()
    gen_delta_t = Dict{String, Float64}()
    gen_discharge_violation = Dict{String, Float64}()

    # Water use for each generator
    for (obj_name, obj_props) in network_data["gen"]
        try
            # Get generator information
            cool = obj_props["cus_cool"]
            fuel = obj_props["cus_fuel"]
            eta_net = obj_props["cus_heat_rate"]

            # Get coefficients
            k_os = get_k_os(fuel)
            beta_proc = get_beta_proc(fuel)

            # Run water models
            if cool == "OC"

                # Defaults (No limits set)
                beta_with_limit = 1.0e10
                beta_con_limit = 1.0e10

                # Extract properties
                try
                    beta_with_limit = obj_props["cus_with_limit"] / 100.0 # Convert to L/MWh
                    beta_con_limit = obj_props["cus_con_limit"] / 100.0 # Convert to L/MWh
                catch
                    println("No water use limits specified for generator $obj_name, setting to infinity")
                end

                # Run water simulation
                beta_with, beta_con, delta_t = MOCOT.once_through_water_use(
                    inlet_temperature,
                    regulatory_temperature,
                    k_os,
                    beta_proc,
                    eta_net,
                    beta_with_limit,
                    beta_con_limit
                )

                # Store violation
                outlet_temperature = inlet_temperature + delta_t
                violation = outlet_temperature - regulatory_temperature
                if violation > 0.0
                    gen_discharge_violation[obj_name] = violation
                end
            elseif cool == "RC" || cool == "RI"
                # Run water simulation
                beta_with, beta_con = MOCOT.recirculating_water_use(
                    air_temperature,
                    eta_net, 
                    k_os, 
                    beta_proc,
                )
                
                # Assume reciruclating systems do not violate
                delta_t = regulatory_temperature - inlet_temperature # C
            elseif cool == "No Cooling System"
                beta_with = 0.0
                beta_con = 0.0
            end

            # Store
            gen_beta_with[obj_name] = beta_with * 100 # Convert to L/pu
            gen_beta_con[obj_name] = beta_con * 100 # Convert to L/pu
            gen_delta_t[obj_name] = delta_t  # C
        catch
            # Check if reliabilty generator
            try
                if obj_name not in network_data["reliability_gen"]
                    println("Water use not computed for generator $obj_name")
                end
            catch
                # Skip water use as it's a relaibility generator
            end
        end
    end

    return gen_beta_with, gen_beta_con, gen_discharge_violation, gen_delta_t
end
