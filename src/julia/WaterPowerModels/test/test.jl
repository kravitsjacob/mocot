using Revise
using Test
using DataFrames
using XLSX
using Infiltrator
using WaterPowerModels


function test_once_through_withdrawal()
    """
    Test for once_through_withdrawal
    """
    beta_with = WaterPowerModels.once_through_withdrawal(
        eta_net=0.25,
        k_os=0.25,
        delta_t=5.0,
        beta_proc=200.0
    )
end

function test_once_through_consumption()
    """
    Test for once_through_consumption
    """
    beta_con = WaterPowerModels.once_through_consumption(
        eta_net=0.25,
        k_os=0.25,
        delta_t=5.0,
        beta_proc=200.0
    )
end

function test_reciruclating_withdrawal()
    """
    Test for test_reciruclating_withdrawal
    """
    beta_with = WaterPowerModels.recirculating_withdrawal(
        eta_net=0.20,
        k_os=0.25,
        beta_proc=200.0,
        eta_cc=5,
        k_sens=0.15
    )
end

function test_recirculating_consumption()
    """
    Test for recirculating_consumption
    """
    beta_con = WaterPowerModels.recirculating_consumption(
        eta_net=0.20,
        k_os=0.25,
        beta_proc=200.0,
        eta_cc=5,
        k_sens=0.15
    )
end

function main()
    @Test.testset "Fundamental Water Use Models" begin
        @Test.test isapprox(test_once_through_withdrawal(), 34616.0, atol=1)
        @Test.test isapprox(test_once_through_consumption(), 544.0, atol=1)
        @Test.test isapprox(test_reciruclating_withdrawal(), 4486.0, atol=1)
        @Test.test isapprox(test_recirculating_consumption(), 3629.0, atol=1)
    end

    @Test.testset "Test for daily_water_use" begin
        pg = 1.0
        exogenous_dict = Dict("air_temperature"=>25.0, "water_temperature"=>25.0)
        gen_info_dict = Dict("fuel_type"=>"coal", "cool"=>"OC")
        df_eia_heat_rates = DataFrames.DataFrame(XLSX.readtable("analysis/io/inputs/eia_heat_rates/Table_A6_Approximate_Heat_Rates_for_Electricity_-_and_Heat_Content_of_Electricity.xlsx", "Annual Data"))

        beta_with, beta_con = WaterPowerModels.daily_water_use(pg, exogenous_dict, gen_info_dict, df_eia_heat_rates)
        @Test.test isapprox(beta_with, 20992, atol=1)
        @Test.test isapprox(beta_con, 407, atol=1)
    end

    test_daily_water_use()
end

main()