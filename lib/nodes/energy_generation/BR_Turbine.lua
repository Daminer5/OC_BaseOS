-- Big Reactors Turbine Control Node
-- Advanced turbine control with BR auto-calibration integration

local component = require("component")
local BR_Turbine_HW = require("hardware.br_turbine")
local BR_Turbine_Calibration = require("turbine_calibration")

local BR_Turbine = {}

function BR_Turbine.init()
  -- Find turbine hardware
  local turbine_address = nil
  for address, ctype in component.list("br_turbine") do
    turbine_address = address
    break  -- Use first turbine found
  end

  if not turbine_address then
    print("BR_Turbine: No Big Reactor turbine found")
    return false
  end

  -- Initialize hardware and calibration
  local turbine_hw = BR_Turbine_HW.new(turbine_address)
  BR_Turbine.calibration = BR_Turbine_Calibration.new(turbine_hw)
  BR_Turbine.hardware = turbine_hw

  print("BR_Turbine: Initialized with turbine " .. turbine_address:sub(1, 8))
  return true
end

function BR_Turbine.run()
  if not BR_Turbine.hardware then
    print("BR_Turbine: Not initialized")
    return
  end

  print("BR_Turbine: Starting control loop with auto-calibration...")

  local last_calibration = 0
  local calibration_interval = 1800  -- 30 minutes

  while true do
    -- Periodic auto-calibration
    if os.time() - last_calibration >= calibration_interval then
      print("BR_Turbine: Running auto-calibration...")
      BR_Turbine.calibration:runFullCalibration()
      last_calibration = os.time()
    end

    -- Status monitoring and maintenance checks
    local status = BR_Turbine.hardware:getStatus()
    if status.state then
      -- Maintenance monitoring
      local maintenance = BR_Turbine.calibration:checkMaintenance()
      if maintenance.needs_maintenance then
        print("BR_Turbine: Maintenance required: " .. table.concat(maintenance.issues, ", "))
        -- Could send alerts here
      end

      -- Occasional status reporting
      if math.random() < 0.01 then  -- ~1% chance each iteration
        print(string.format("BR_Turbine: Rotor=%.1f RPM, Power=%.0f RF/t, Fluid=%.1f%%",
                           status.custom.rotor_speed or 0, status.throughput or 0,
                           ((status.custom.fluid_amount or 0) / (status.custom.fluid_capacity or 1)) * 100))
      end
    end

    os.sleep(15)  -- Control loop every 15 seconds
  end
end

function BR_Turbine.getStatus()
  if not BR_Turbine.hardware then return nil end
  return BR_Turbine.hardware:getStatus()
end

function BR_Turbine.calibrate()
  if not BR_Turbine.calibration then return false end
  return BR_Turbine.calibration:runFullCalibration()
end

function BR_Turbine.setActive(state)
  if not BR_Turbine.hardware then return false end
  return BR_Turbine.hardware:setActive(state)
end

function BR_Turbine.checkMaintenance()
  if not BR_Turbine.calibration then return {needs_maintenance = true} end
  return BR_Turbine.calibration:checkMaintenance()
end

return BR_Turbine