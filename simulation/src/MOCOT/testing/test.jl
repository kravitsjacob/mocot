using Infiltrator
using Revise
using Test
using DataFrames
using CSV
using XLSX
using PowerModels
using JuMP
using Ipopt
using JLD2

using MOCOT


@Test.testset "Fundamental Water Use Models" begin
    gen = MOCOT.OnceThroughGenerator(
        0.25,
        0.25,
        200.0,
        0.0,
        0.0,
    )
    beta_with = MOCOT.get_withdrawal(
        gen,
        5.0,
    )
    @Test.test isapprox(beta_with, 344368.3, atol=1)
    beta_con = MOCOT.get_consumption(
        gen,
        5.0,
    )
    @Test.test isapprox(beta_con, 544.2, atol=1)
    gen = MOCOT.RecirculatingGenerator(
        0.20,
        0.25,
        200.0,
        5,
        1.0,
        0.0,
        0.0,
    )
    beta_with = MOCOT.get_withdrawal(
        gen,
        0.15,
    )
    @Test.test isapprox(beta_with, 4486.0, atol=1)
    beta_con = MOCOT.get_consumption(
        gen,
        0.15,
    )
    @Test.test isapprox(beta_con, 3629.0, atol=1)
end


@Test.testset "Fundamental Capacity Reduction Models" begin
    gen = MOCOT.OnceThroughGenerator(
        0.0,
        0.0,
        0.0,
        0.5,
        0.5,
    )
    p_thermo_OC = MOCOT.get_capacity(
        gen,
        400.0,
        5.0,
        621.712,
    )
    @Test.test isapprox(p_thermo_OC, 262.2, atol=1)

    gen = MOCOT.RecirculatingGenerator(
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.5,
        0.5,
    )
    p_thermo_RC = MOCOT.get_capacity(
        gen,    
        400.0,
        5.0,
        621.712,
    )
    @Test.test isapprox(p_thermo_RC, 400.0, atol=1)
end


# @Test.testset "Test for once_through_water_use" begin
#     # Setup
#     beta_with_limit=190000.0
#     beta_con_limit=400.0
#     regulatory_temperature = 33.7
#     k_os = 0.12
#     beta_proc = 200.0
#     eta_net = 0.33

#     # Cold case 
#     inlet_temperature = 21.0
#     beta_with, beta_con, delta_t = MOCOT.once_through_water_use(
#         inlet_temperature,
#         regulatory_temperature,
#         k_os,
#         beta_proc,
#         eta_net,
#         beta_with_limit,
#         beta_con_limit
#     )
#     @Test.test isapprox(beta_with, 143603.4, atol=1)
#     @Test.test isapprox(beta_con, 343.4, atol=1)
#     @Test.test isapprox(delta_t, 10.0, atol=1)

#     # Delta t but no limit
#     inlet_temperature = 25.0
#     beta_with, beta_con, delta_t = MOCOT.once_through_water_use(
#         inlet_temperature,
#         regulatory_temperature,
#         k_os,
#         beta_proc,
#         eta_net,
#         beta_with_limit,
#         beta_con_limit
#     )
#     @Test.test isapprox(beta_with, 165031.5, atol=1)
#     @Test.test isapprox(beta_con, 364.8, atol=1)
#     @Test.test isapprox(delta_t, 8.7, atol=1)

#     # Delta with limits (temperature violations)
#     inlet_temperature = 27.0
#     beta_with, beta_con, delta_t = MOCOT.once_through_water_use(
#         inlet_temperature,
#         regulatory_temperature,
#         k_os,
#         beta_proc,
#         eta_net,
#         beta_with_limit,
#         beta_con_limit
#     )
#     @Test.test isapprox(beta_with, 190000.0, atol=1)
#     @Test.test isapprox(beta_con, 400.0, atol=1)
#     @Test.test isapprox(delta_t, 7.6, atol=1)
# end


# @Test.testset "Test for recirculating_water_use" begin
#     # Setup
#     air_temperature=25.0
#     k_os = 0.20
#     beta_proc = 10.0
#     eta_net = 0.33

#     # Cold case 
#     beta_with, beta_con = MOCOT.recirculating_water_use(
#         air_temperature,
#         eta_net, 
#         k_os, 
#         beta_proc,
#     )
#     @Test.test isapprox(beta_with, 2245.7, atol=1)
#     @Test.test isapprox(beta_con, 1798.6, atol=1)
# end


# @Test.testset "Test for adding wind capacity" begin
#     # Import static network
#     d_total = 3
#     h_total = 24
#     network_data = create_custom_test_network(network_data_raw)
#     exogenous = exogenous_raw
#     network_data_multi = PowerModels.replicate(network_data, h_total)

#     # Save original value
#     orig_cap = network_data_multi["nw"]["1"]["gen"]["6"]["pmax"]

#     # Adjust wind generator capacity
#     network_data_multi = MOCOT.update_wind_capacity!(
#         network_data_multi,
#         exogenous["wind_capacity_factor"]["1"]
#     )

#     # New value
#     new_cap = network_data_multi["nw"]["1"]["gen"]["6"]["pmax"]
    
#     @test isapprox(
#         orig_cap*exogenous["wind_capacity_factor"]["1"]["1"],
#         new_cap,
#         atol=-1
#     )
# end


# @Test.testset "Test for add_linear_obj_terms!" begin
#     # Setup
#     linear_coef = Dict{String, Float64}(
#         "1" => -1000000.0 * 2.0,
#         "2" => -10000000.0 * 2.0
#     )

#     # Import static network
#     h_total = 24
#     network_data = network_data_raw
#     network_data_multi = PowerModels.replicate(network_data, h_total)

#     # Create power system model
#     pm = PowerModels.instantiate_model(
#         network_data_multi,
#         PowerModels.DCPPowerModel,
#         PowerModels.build_mn_opf
#     )

#     # Add water terms
#     pm = MOCOT.add_linear_obj_terms!(
#         pm,
#         linear_coef,
#     )

#     # Tests
#     test_var = PowerModels.var(pm, 1, :pg, 1)
#     linear_terms = JuMP.objective_function(pm.model).aff.terms

#     @Test.test isapprox(linear_terms[PowerModels.var(pm, 1, :pg, 1)], -1.9981e6, atol=1)
#     @Test.test isapprox(linear_terms[PowerModels.var(pm, 24, :pg, 1)], -1.9981e6, atol=1)
#     @Test.test isapprox(linear_terms[PowerModels.var(pm, 1, :pg, 2)], -1.99981e7, atol=1)
#     @Test.test isapprox(linear_terms[PowerModels.var(pm, 24, :pg, 2)], -1.99981e7, atol=1)
# end


# @Test.testset "multiply_dicts" begin
#     # Setup
#     a = Dict{String, Float64}(
#         "1" => 5.0,
#         "2" => 6.0
#     )
#     b = Dict{String, Float64}(
#         "1" => 10.0,
#         "2" => 20.0
#     )
#     test_dict = MOCOT.multiply_dicts([a, b])

#     @Test.test isequal(test_dict["1"], 50.0)
#     @Test.test isequal(test_dict["2"], 120.0)
# end


# @Test.testset "add_reliability_gens!" begin
#     # Setup
#     network_data = network_data_raw
    
#     # Add really big load
#     network_data["load"]["1"]["pd"] = 100000.0

#     # Adjust generator capacity
#     network_data = MOCOT.update_all_gens!(network_data, "pmin", 0.0)

#     # Add reliability
#     voll = 330000.0  # $/pu for MISO
#     network_data = MOCOT.add_reliability_gens!(network_data, voll)

#     # Solve OPF
#     pm = PowerModels.instantiate_model(
#         network_data,
#         PowerModels.DCPPowerModel,
#         PowerModels.build_mn_opf
#     )
#     results = PowerModels.optimize_model!(
#         pm,
#         optimizer=Ipopt.Optimizer
#     )

#     # Test the reliability of load 1 (relability generator 10001)
#     @Test.test isapprox(results["solution"]["gen"]["1001"]["pg"], 99998.99, atol=1)

#     # Test if generators were stored
#     @Test.test isequal(length(network_data["reliability_gen"]), 108)
# end


# @Test.testset "Test for generator water use with thermal limits" begin
#     # Setup
#     air_temperature = 25.0
#     regulatory_temperature = 33.7
#     network_data = create_custom_test_network(network_data_raw)

#     # Set limits
#     network_data["gen"]["1"]["cus_with_limit"] = 19000000.0
#     network_data["gen"]["1"]["cus_con_limit"] = 40000.0

#     # No violations
#     inlet_temperature = 25.0
#     gen_beta_with, gen_beta_con, gen_discharge_violation = MOCOT.gen_water_use_wrapper(
#         inlet_temperature,
#         air_temperature,
#         regulatory_temperature,
#         network_data
#     )
#     @Test.test isapprox(gen_beta_with["1"], 1.674957060861525e7, atol=1)
#     @Test.test isapprox(gen_beta_con["1"], 36729.5, atol=1)

#     # Discharge temperature violation
#     inlet_temperature = 27.0
#     gen_beta_with, gen_beta_con, gen_discharge_violation = MOCOT.gen_water_use_wrapper(
#         inlet_temperature,
#         air_temperature,
#         regulatory_temperature,
#         network_data
#     )
#     @Test.test isapprox(gen_beta_with["1"], 19000000.0, atol=1)
#     @Test.test isapprox(gen_beta_con["1"], 40000.0, atol=1)
#     @Test.test isapprox(gen_discharge_violation["1"], 0.968, atol=1)
# end


# @Test.testset "Impact of weights" begin
#     # Setup
#     network_data = create_custom_test_network(network_data_raw)
#     exogenous = exogenous_raw

#     # No weights
#     (objectives_no_weight, metrics, state) = MOCOT.simulation(
#         network_data,
#         exogenous,
#         w_with=0.0,
#         w_con=0.0,
#         w_emit=0.0,
#         verbose_level=1
#     )

#     # Withdrawal weights
#     (objectives_with_weight, metrics, state) = MOCOT.simulation(
#         network_data,
#         exogenous,
#         w_with=0.1,
#         w_con=0.0,
#         w_emit=0.0,
#         verbose_level=1
#     )

#     # Emission weights
#     (objectives_emit_weight, metrics, state) = MOCOT.simulation(
#         network_data,
#         exogenous,
#         w_with=0.0,
#         w_con=0.0,
#         w_emit=0.1,
#         verbose_level=1
#     )

#     # Test for reduced withdrawal
#     @Test.test objectives_with_weight["f_with_tot"] < objectives_no_weight["f_with_tot"]

#     # Test for reduced emissions
#     @Test.test objectives_emit_weight["f_emit"] < objectives_no_weight["f_emit"]

#     # Test for increased cost
#     @Test.test objectives_with_weight["f_gen"] > objectives_no_weight["f_gen"]

#     # Test for increased cost
#     @Test.test objectives_emit_weight["f_gen"] > objectives_no_weight["f_gen"]

# end


# @Test.testset "Water weight impact ENS" begin
#     # Setup
#     network_data = create_custom_test_network(network_data_raw)
#     exogenous = exogenous_raw

#     # No weights
#     (objectives_weights, metrics, state) = MOCOT.simulation(
#         network_data,
#         exogenous,
#         w_with=5.0,
#         w_con=0.0,
#         w_emit=0.0,
#         verbose_level=1
#     )

#     # Test for increased ENS
#     @Test.test objectives_weights["f_ENS"] > 0.1

# end
