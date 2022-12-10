# Functions for running at a daily-resolution simulation


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
