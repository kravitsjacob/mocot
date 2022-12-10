"""WaterPowerModel"""


"""
A water extension of PowerModel
"""
struct WaterPowerModel
    "Generator names and objects"
    gens:: Dict
    "Network data from PowerModels.jl"
    network_data:: Dict
end


