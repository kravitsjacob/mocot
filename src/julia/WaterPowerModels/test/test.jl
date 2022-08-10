using Revise
using Test
using DataFrames
using XLSX
using Infiltrator
using WaterPowerModels


@Test.testset "Fundamental Water Use Models" begin
    beta_with = WaterPowerModels.once_through_withdrawal(
        eta_net=0.25,
        k_os=0.25,
        delta_t=5.0,
        beta_proc=200.0
    )
    @Test.test isapprox(beta_with, 34616.0, atol=1)
    beta_con = WaterPowerModels.once_through_consumption(
        eta_net=0.25,
        k_os=0.25,
        delta_t=5.0,
        beta_proc=200.0
    )
    @Test.test isapprox(beta_con, 544.0, atol=1)
    beta_with = WaterPowerModels.recirculating_withdrawal(
        eta_net=0.20,
        k_os=0.25,
        beta_proc=200.0,
        eta_cc=5,
        k_sens=0.15
    )
    @Test.test isapprox(beta_with, 4486.0, atol=1)
    beta_con = WaterPowerModels.recirculating_consumption(
        eta_net=0.20,
        k_os=0.25,
        beta_proc=200.0,
        eta_cc=5,
        k_sens=0.15
    )
    @Test.test isapprox(beta_con, 3629.0, atol=1)
end

@Test.testset "Test for daily_water_use" begin
    pg = 1.0
    df_eia_heat_rates = DataFrames.DataFrame(XLSX.readtable("analysis/io/inputs/eia_heat_rates/Table_A6_Approximate_Heat_Rates_for_Electricity_-_and_Heat_Content_of_Electricity.xlsx", "Annual Data"))
    air_temperature = 25.0
    water_temperature = 25.0

    # Once-through coal
    fuel = "coal"
    cool = "OC"
    beta_with, beta_con = WaterPowerModels.daily_water_use(pg, air_temperature, water_temperature, fuel, cool, df_eia_heat_rates)
    @Test.test isapprox(beta_with, 20992, atol=1)
    @Test.test isapprox(beta_con, 407, atol=1)

    # Recirculating coal
    fuel = "coal"
    cool = "RC"
    beta_with, beta_con = WaterPowerModels.daily_water_use(pg, air_temperature, water_temperature, fuel, cool, df_eia_heat_rates)
    @Test.test isapprox(beta_with, 2855.0, atol=1)
    @Test.test isapprox(beta_con, 2324.0, atol=1)

    # Recirculating nuclear
    fuel = "nuclear"
    cool = "RC"
    beta_with, beta_con = WaterPowerModels.daily_water_use(pg, air_temperature, water_temperature, fuel, cool, df_eia_heat_rates)
    @Test.test isapprox(beta_with, 3290.0, atol=1)
    @Test.test isapprox(beta_con, 2634.0, atol=1)
end
