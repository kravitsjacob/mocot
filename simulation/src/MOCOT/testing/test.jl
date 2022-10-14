using Revise
using Test
using DataFrames
using CSV
using XLSX
using PowerModels
using JuMP
using Ipopt

using MOCOT

# Global vars
network_data_raw = PowerModels.parse_file("simulation/src/MOCOT/testing/case_ACTIVSg200.m")


function create_custom_test_network(network_data)
    """
    Add custom properties to testing network

    # Arguments
    - `network_data:: Dict`: PowerModels network data
    """
    # Setup
    obj_names = ["1", "2", "3", "4", "5", "7", "8", "9", "10", "11", "12", "13", "21", "26", "27", "28", "29", "30", "32", "33", "34", "35", "36", "45", "46", "6", "22", "23", "24", "25", "31", "14", "15", "16", "17", "18", "19", "20", "37", "38", "39", "40", "41", "42", "43", "44", "48", "49", "47"]

    # Ramp rate
    network_data = MOCOT.add_prop!(
        network_data,
        "gen",
        "cus_ramp_rate",
        obj_names,
        [163.07999999999998, 163.07999999999998, 163.07999999999998, 163.07999999999998, 326.52, 169.2, 1005.12, 1005.12, 1005.12, 1005.12, 1005.12, 1005.12, 647.9999999999999, 4681.8, 4681.8, 4681.8, 16070.399999999998, 16070.399999999998, 194.4, 2779.92, 2779.92, 2779.92, 2779.92, 630.0, 957.6, 420.0, 420.0, 420.0, 420.0, 420.0, 420.0, 48.0, 28.8, 216.0, 216.0, 38.400000000000006, 60.0, 75.6, 1663.1999999999998, 144.00000000000003, 312.0, 112.8, 112.8, 112.8, 112.8, 112.8, 810.0, 810.0, 113.83]
    )

    # Fuel types
    network_data = MOCOT.add_prop!(
        network_data,
        "gen",
        "cus_fuel",
        obj_names,
        ["coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "wind", "wind", "wind", "wind", "wind", "wind", "ng", "ng", "ng", "ng", "ng", "ng", "ng", "ng", "ng", "ng", "ng", "ng", "ng", "ng", "ng", "ng", "ng", "nuclear"]
    )

    # Cooling type
    network_data = MOCOT.add_prop!(
        network_data,
        "gen",
        "cus_cool",
        obj_names,
        ["OC", "OC", "OC", "OC", "OC", "RI", "RI", "RI", "RI", "RI", "RI", "RI", "OC", "OC", "OC", "OC", "RC", "RC", "OC", "OC", "OC", "OC", "OC", "OC", "OC", "No Cooling System", "No Cooling System", "No Cooling System", "No Cooling System", "No Cooling System", "No Cooling System", "No Cooling System", "No Cooling System", "No Cooling System", "No Cooling System", "No Cooling System", "No Cooling System", "No Cooling System", "RI", "No Cooling System", "No Cooling System", "No Cooling System", "No Cooling System", "No Cooling System", "No Cooling System", "No Cooling System", "RI", "RI", "RC"]
    )

    # Emissions coefficient
    network_data = MOCOT.add_prop!(
        network_data,
        "gen",
        "cus_emit",
        obj_names,
        [0.0022299999999999, 0.0022299999999999, 0.0022299999999999, 0.0022299999999999, 0.0022299999999999, 0.0022299999999999, 0.0022299999999999, 0.0022299999999999, 0.0022299999999999, 0.0022299999999999, 0.0022299999999999, 0.0022299999999999, 0.0022299999999999, 0.0022299999999999, 0.0022299999999999, 0.0022299999999999, 0.0022299999999999, 0.0022299999999999, 0.0022299999999999, 0.0022299999999999, 0.0022299999999999, 0.0022299999999999, 0.0022299999999999, 0.0022299999999999, 0.0022299999999999, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.00091, 0.00091, 0.00091, 0.00091, 0.00091, 0.00091, 0.00091, 0.00091, 0.00091, 0.00091, 0.00091, 0.00091, 0.00091, 0.00091, 0.00091, 0.00091, 0.00091, 0.0]
    )

    # Withdrawal limit
    network_data = MOCOT.add_prop!(
        network_data,
        "gen",
        "cus_with_limit",
        obj_names,
        [190000.0, 190000.0, 190000.0, 190000.0, 190000.0, missing, missing, missing, missing, missing, missing, missing, 190000.0, 190000.0, 190000.0, 190000.0, missing, missing, 190000.0, 190000.0, 190000.0, 190000.0, 190000.0, 190000.0, 190000.0, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing]
    )

    # Consumption limit
    network_data = MOCOT.add_prop!(
        network_data,
        "gen",
        "cus_con_limit",
        obj_names,
        [1200.0, 1200.0, 1200.0, 1200.0, 1200.0, missing, missing, missing, missing, missing, missing, missing, 1200.0, 1200.0, 1200.0, 1200.0, missing, missing, 1200.0, 1200.0, 1200.0, 1200.0, 1200.0, 1200.0, 1200.0, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing]
    )

    # Heat rates
    network_data = MOCOT.add_prop!(
        network_data,
        "gen",
        "cus_heat_rate",
        obj_names,
        [0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0, 0, 0, 0, 0, 0, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.3236270511239685]
    )

    return network_data
end


@Test.testset "Fundamental Water Use Models" begin
    beta_with = MOCOT.once_through_withdrawal(
        eta_net=0.25,
        k_os=0.25,
        delta_t=5.0,
        beta_proc=200.0
    )
    @Test.test isapprox(beta_with, 344368.3, atol=1)
    beta_con = MOCOT.once_through_consumption(
        eta_net=0.25,
        k_os=0.25,
        delta_t=5.0,
        beta_proc=200.0
    )
    @Test.test isapprox(beta_con, 544.2, atol=1)
    beta_with = MOCOT.recirculating_withdrawal(
        eta_net=0.20,
        k_os=0.25,
        beta_proc=200.0,
        eta_cc=5,
        k_sens=0.15
    )
    @Test.test isapprox(beta_with, 4486.0, atol=1)
    beta_con = MOCOT.recirculating_consumption(
        eta_net=0.20,
        k_os=0.25,
        beta_proc=200.0,
        eta_cc=5,
        k_sens=0.15
    )
    @Test.test isapprox(beta_con, 3629.0, atol=1)
end


@Test.testset "Test for once_through_water_use" begin
    # Setup
    beta_with_limit=190000.0
    beta_con_limit=400.0
    regulatory_temperature = 33.7
    k_os = 0.12
    beta_proc = 200.0
    eta_net = 0.33

    # Cold case 
    inlet_temperature = 21.0
    beta_with, beta_con, delta_t = MOCOT.once_through_water_use(
        inlet_temperature,
        regulatory_temperature,
        k_os,
        beta_proc,
        eta_net,
        beta_with_limit,
        beta_con_limit
    )
    @Test.test isapprox(beta_with, 143603.4, atol=1)
    @Test.test isapprox(beta_con, 343.4, atol=1)
    @Test.test isapprox(delta_t, 10.0, atol=1)

    # Delta t but no limit
    inlet_temperature = 25.0
    beta_with, beta_con, delta_t = MOCOT.once_through_water_use(
        inlet_temperature,
        regulatory_temperature,
        k_os,
        beta_proc,
        eta_net,
        beta_with_limit,
        beta_con_limit
    )
    @Test.test isapprox(beta_with, 165031.5, atol=1)
    @Test.test isapprox(beta_con, 364.8, atol=1)
    @Test.test isapprox(delta_t, 8.7, atol=1)

    # Delta with limits (temperature violations)
    inlet_temperature = 27.0
    beta_with, beta_con, delta_t = MOCOT.once_through_water_use(
        inlet_temperature,
        regulatory_temperature,
        k_os,
        beta_proc,
        eta_net,
        beta_with_limit,
        beta_con_limit
    )
    @Test.test isapprox(beta_with, 190000.0, atol=1)
    @Test.test isapprox(beta_con, 400.0, atol=1)
    @Test.test isapprox(delta_t, 7.6, atol=1)
end


@Test.testset "Test for recirculating_water_use" begin
    # Setup
    air_temperature=25.0
    k_os = 0.20
    beta_proc = 10.0
    eta_net = 0.33

    # Cold case 
    beta_with, beta_con = MOCOT.recirculating_water_use(
        air_temperature,
        eta_net, 
        k_os, 
        beta_proc,
    )
    @Test.test isapprox(beta_with, 2245.7, atol=1)
    @Test.test isapprox(beta_con, 1798.6, atol=1)
end


@Test.testset "Test for add_linear_obj_terms!" begin
    # Setup
    linear_coef = Dict{String, Float64}(
        "1" => -1000000.0 * 2.0,
        "2" => -10000000.0 * 2.0
    )

    # Import static network
    h_total = 24
    network_data = network_data_raw
    network_data_multi = PowerModels.replicate(network_data, h_total)

    # Create power system model
    pm = PowerModels.instantiate_model(
        network_data_multi,
        PowerModels.DCPPowerModel,
        PowerModels.build_mn_opf
    )

    # Add water terms
    pm = MOCOT.add_linear_obj_terms!(
        pm,
        linear_coef,
    )

    # Tests
    test_var = PowerModels.var(pm, 1, :pg, 1)
    linear_terms = JuMP.objective_function(pm.model).aff.terms

    @Test.test isapprox(linear_terms[PowerModels.var(pm, 1, :pg, 1)], -1.9981e6, atol=1)
    @Test.test isapprox(linear_terms[PowerModels.var(pm, 24, :pg, 1)], -1.9981e6, atol=1)
    @Test.test isapprox(linear_terms[PowerModels.var(pm, 1, :pg, 2)], -1.99981e7, atol=1)
    @Test.test isapprox(linear_terms[PowerModels.var(pm, 24, :pg, 2)], -1.99981e7, atol=1)
end


@Test.testset "multiply_dicts" begin
    # Setup
    a = Dict{String, Float64}(
        "1" => 5.0,
        "2" => 6.0
    )
    b = Dict{String, Float64}(
        "1" => 10.0,
        "2" => 20.0
    )
    test_dict = MOCOT.multiply_dicts([a, b])

    @Test.test isequal(test_dict["1"], 50.0)
    @Test.test isequal(test_dict["2"], 120.0)
end


@Test.testset "add_reliability_gens!" begin
    # Setup
    network_data = network_data_raw
    
    # Add really big load
    network_data["load"]["1"]["pd"] = 100000.0

    # Adjust generator capacity
    network_data = MOCOT.update_all_gens!(network_data, "pmin", 0.0)

    # Add reliability
    voll = 330000.0  # $/pu for MISO
    network_data = MOCOT.add_reliability_gens!(network_data, voll)

    # Solve OPF
    pm = PowerModels.instantiate_model(
        network_data,
        PowerModels.DCPPowerModel,
        PowerModels.build_mn_opf
    )
    results = PowerModels.optimize_model!(
        pm,
        optimizer=Ipopt.Optimizer
    )

    # Test the reliability of load 1 (relability generator 10001)
    @Test.test isapprox(results["solution"]["gen"]["1001"]["pg"], 99998.99, atol=1)

    # Test if generators were stored
    @Test.test isequal(length(network_data["reliability_gen"]), 108)
end


@Test.testset "Test for generator water use with thermal limits" begin
    # Setup
    air_temperature = 25.0
    regulatory_temperature = 33.7
    network_data = create_custom_test_network(network_data_raw)

    # Set limits
    network_data["gen"]["1"]["cus_with_limit"] = 190000.0
    network_data["gen"]["1"]["cus_con_limit"] = 400.0

    # No violations
    inlet_temperature = 25.0
    gen_beta_with, gen_beta_con, gen_discharge_violation = MOCOT.gen_water_use_wrapper(
        inlet_temperature,
        air_temperature,
        regulatory_temperature,
        network_data
    )
    @Test.test isapprox(gen_beta_with["1"], 167495.7, atol=1)
    @Test.test isapprox(gen_beta_con["1"], 367.2, atol=1)

    # Discharge temperature violation
    inlet_temperature = 27.0
    gen_beta_with, gen_beta_con, gen_discharge_violation = MOCOT.gen_water_use_wrapper(
        inlet_temperature,
        air_temperature,
        regulatory_temperature,
        network_data
    )
    @Test.test isapprox(gen_beta_with["1"], 190000.0, atol=1)
    @Test.test isapprox(gen_beta_con["1"], 400.0, atol=1)
    @Test.test isapprox(gen_discharge_violation["1"], 0.968, atol=1)
end


@Test.testset "Impact of weights" begin
    # Setup


    # # No weights
    # MOCOT.simulation(
    #     network_data,
    #     exogenous,
    #     w_with_coal=0.0,
    #     w_con_coal=0.0,
    #     w_with_ng=0.0,
    #     w_con_ng=0.0,
    #     w_with_nuc=0.0,
    #     w_con_nuc=0.0,
    #     verbose_level=1
    # )

end