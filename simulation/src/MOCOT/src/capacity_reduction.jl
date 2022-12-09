"""Capacity reduction models"""



function get_gen_capacity_reduction(
    network_data:: Dict,
    gen_delta_T:: Dict,
    Q:: Float64,
)
    """
    Get generator capacity reductions

    # Arguments
    - `network_data:: Float64`: Network data
    - `gen_delta_T:: Dict`: Generator delta temperature [C]
    - `Q:: Float64`: Flow [cmps]
    """
    gen_capacity_reduction = Dict()
    gen_capacity = Dict()

    for (obj_name, obj_props) in network_data["gen"]

        try
            # Cooling information
            cool = obj_props["cus_cool"]

            if cool == "No Cooling System"
                # No capacity impact
            else
                # Extract information
                delta_T = gen_delta_T[obj_name]
                KW = obj_props["pmax"] * 100  # Convert to MW
                eta_total = obj_props["cus_heat_rate"]
                eta_elec = obj_props["cus_heat_rate"]

                # Run water models
                if cool == "OC"
                    KW_updated = MOCOT.once_through_capacity(
                        KW=KW,
                        delta_T=delta_T,
                        Q=Q,
                        eta_total=eta_total,
                        eta_elec=eta_elec,
                    )
    
                elseif cool == "RC" || cool == "RI"
                    KW_updated = MOCOT.recirculating_capacity(
                        KW=KW,
                        delta_T=delta_T,
                        Q=Q,
                        eta_total=eta_total,
                        eta_elec=eta_elec,
                    )

                end

                # Store 
                gen_capacity_reduction[obj_name] = KW - KW_updated

                # Update 
                gen_capacity[obj_name] = KW_updated /100.0  # Convert to pu

            end
        
        catch  # Reliability generator
            # Skip as reliability generator
        end

    end

    return gen_capacity, gen_capacity_reduction
end