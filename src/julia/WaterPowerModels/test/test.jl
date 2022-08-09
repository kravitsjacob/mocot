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
    Test.@test isapprox(beta_with, 34616.0, atol=1 )

end


function main()
    # Water use models
    test_once_through_withdrawal()

end

main()