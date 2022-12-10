"""Water/power system simulation"""


struct WaterPowerSimulation
    "WaterPowerModel"
    model:: WaterPowerModel
    "Exogenous parameters"
    exogenous:: Dict
    "State parameters"
    state:: Dict
end

