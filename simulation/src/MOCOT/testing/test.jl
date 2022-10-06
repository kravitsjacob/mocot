using Revise
using Test
using DataFrames
using CSV
using XLSX
using PowerModels
using JuMP
using Ipopt

using MOCOT

@Test.testset "Fundamental Water Use Models" begin
    beta_with = MOCOT.once_through_withdrawal(
        eta_net=0.25,
        k_os=0.25,
        delta_t=5.0,
        beta_proc=200.0
    )
    @Test.test isapprox(beta_with, 34616.0, atol=1)
    beta_con = MOCOT.once_through_consumption(
        eta_net=0.25,
        k_os=0.25,
        delta_t=5.0,
        beta_proc=200.0
    )
    @Test.test isapprox(beta_con, 544.0, atol=1)
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

@Test.testset "Test for daily_water_use" begin
    air_temperature = 25.0
    water_temperature = 25.0

    # Once-through coal
    fuel = "coal"
    cool = "OC"
    beta_with, beta_con = MOCOT.water_use(air_temperature, water_temperature, fuel, cool, 0.32694518972786507)
    @Test.test isapprox(beta_with, 16929.0, atol=1)
    @Test.test isapprox(beta_con, 367.0, atol=1)

    # Recirculating coal
    fuel = "coal"
    cool = "RC"
    beta_with, beta_con = MOCOT.water_use(air_temperature, water_temperature, fuel, cool, 0.32694518972786507)
    @Test.test isapprox(beta_with, 2855.0, atol=1)
    @Test.test isapprox(beta_con, 2324.0, atol=1)

    # Recirculating nuclear
    fuel = "nuclear"
    cool = "RC"
    beta_with, beta_con = MOCOT.water_use(air_temperature, water_temperature, fuel, cool, 0.3236270511239685)
    @Test.test isapprox(beta_with, 3290.0, atol=1)
    @Test.test isapprox(beta_con, 2634.0, atol=1)
end

@Test.testset "Test for generator water use with thermal limits" begin
    # Setup    
    air_temperature = 25.0
    network_data = PowerModels.parse_file("simulation/src/MOCOT/testing/case_ACTIVSg200.m")
    obj_names = ["1", "2", "3", "4", "5", "7", "8", "9", "10", "11", "12", "13", "21", "26", "27", "28", "29", "30", "32", "33", "34", "35", "36", "45", "46", "6", "22", "23", "24", "25", "31", "14", "15", "16", "17", "18", "19", "20", "37", "38", "39", "40", "41", "42", "43", "44", "48", "49", "47"]

    # Add custom network properties
    network_data = MOCOT.add_prop!(
        network_data,
        "gen",
        "cus_heat_rate",
        obj_names,
        [0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.32694518972786507, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.42146871718856155, 0.3236270511239685]
    )
    network_data = MOCOT.add_prop!(
        network_data,
        "gen",
        "cus_fuel",
        obj_names,
        ["coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "coal", "wind", "wind", "wind", "wind", "wind", "wind", "ng", "ng", "ng", "ng", "ng", "ng", "ng", "ng", "ng", "ng", "ng", "ng", "ng", "ng", "ng", "ng", "ng", "nuclear"]
    )
    network_data = MOCOT.add_prop!(
        network_data,
        "gen",
        "cus_cool",
        obj_names,
        ["OC", "OC", "OC", "OC", "OC", "RI", "RI", "RI", "RI", "RI", "RI", "RI", "OC", "OC", "OC", "OC", "RC", "RC", "OC", "OC", "OC", "OC", "OC", "OC", "OC", "No Cooling System", "No Cooling System", "No Cooling System", "No Cooling System", "No Cooling System", "No Cooling System", "No Cooling System", "No Cooling System", "No Cooling System", "No Cooling System", "No Cooling System", "No Cooling System", "No Cooling System", "RI", "No Cooling System", "No Cooling System", "No Cooling System", "No Cooling System", "No Cooling System", "No Cooling System", "No Cooling System", "RI", "RI", "RC"]
    )

    # Set limits
    network_data["gen"]["1"]["cus_with_limit"] = 190000.0
    network_data["gen"]["1"]["cus_con_limit"] = 1200.0

    # Test for limits enforced
    water_temperature = 33.6
    gen_beta_with, gen_beta_con, gen_discharge_violation = MOCOT.gen_water_use(
        water_temperature,
        air_temperature,
        network_data
    )
    @Test.test isapprox(gen_discharge_violation["1"], 1.45, atol=1)
    @Test.test isapprox(gen_beta_with["1"], 190000.0, atol=1)
    @Test.test isapprox(gen_beta_con["1"], 1200.0, atol=1)

    # Test for limits not enforced
    water_temperature = 25.0
    gen_beta_with, gen_beta_con, gen_discharge_violation = MOCOT.gen_water_use(
        water_temperature,
        air_temperature,
        network_data
    )
    @Test.test isapprox(gen_discharge_violation["1"], 0.0, atol=1)
    @Test.test isapprox(gen_beta_with["1"], 16929.6, atol=1)
    @Test.test isapprox(gen_beta_con["1"], 367.3, atol=1)

end

@Test.testset "Test for add_linear_obj_terms!" begin
    # Setup
    linear_coef = Dict{String, Float64}(
        "1" => -1000000.0 * 2.0,
        "2" => -10000000.0 * 2.0
    )

    # Import static network
    h_total = 24
    network_data = PowerModels.parse_file("simulation/src/MOCOT/testing/case_ACTIVSg200.m")
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
    network_data = PowerModels.parse_file("simulation/src/MOCOT/testing/case_ACTIVSg200.m")
    
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
