using Revise
using Test
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



# function test_reciruclating_withdrawal()
#     """
#     Test for test_reciruclating_withdrawal
#     """
#     beta_with = WaterPowerModels.recirculating_withdrawal(
#         eta_net=0.20,
#         k_os=0.25,
#         beta_proc=200,
#         eta_cc=5.0,
#         k_sens=0.15
#     )
#     @Test.test isapprox(beta_with, 4486, atol=1 )
# end


function main()
    @Test.testset "Water Models" begin
        # Water use models
        @Test.test isapprox(test_once_through_withdrawal(), 34616.0, atol=1 )
        @Test.test isapprox(test_once_through_consumption(), 544.0, atol=1 )
    end
end

main()