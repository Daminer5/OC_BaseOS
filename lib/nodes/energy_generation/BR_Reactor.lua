-- Big Reactors Reactor Control Node
-- Advanced reactor control with BR auto-calibration integration

local component = require("component")
local BR_Reactor_HW = require("hardware.br_reactor")
local BR_Reactor_Calibration = require("reactor_calibration")

local BR_Reactor = {}

function BR_Reactor.init()
  -- Find reactor hardware
  local reactor_address = nil
  for address, ctype in component.list("br_reactor") do
    reactor_address = address
    break  -- Use first reactor found
  end

  if not reactor_address then
    print("BR_Reactor: No Big Reactor found")
    return false
  end

  -- Initialize hardware and calibration
  local reactor_hw = BR_Reactor_HW.new(reactor_address)
  BR_Reactor.calibration = BR_Reactor_Calibration.new(reactor_hw)
  BR_Reactor.hardware = reactor_hw

  print("BR_Reactor: Initialized with reactor " .. reactor_address:sub(1, 8))
  return true
end

function BR_Reactor.run()
  if not BR_Reactor.hardware then
    print("BR_Reactor: Not initialized")
    return
  end

  print("BR_Reactor: Starting control loop with auto-calibration...")

  local last_calibration = 0
  local calibration_interval = 1800  -- 30 minutes

  while true do
    -- Periodic auto-calibration
    if os.time() - last_calibration >= calibration_interval then
      print("BR_Reactor: Running auto-calibration...")
      BR_Reactor.calibration:runFullCalibration()
      last_calibration = os.time()
    end

    -- Continuous adaptive control
    BR_Reactor.calibration:adaptiveControl()

    -- Status monitoring
    local status = BR_Reactor.hardware:getStatus()
    if status.state then
      -- Could send status updates to orchestrator here
      -- For now, just print occasional status
      if math.random() < 0.01 then  -- ~1% chance each iteration
        print(string.format("BR_Reactor: Temp=%.1f°C, Power=%.0f RF/t, Rod=%d%%",
                           status.temperature or 0, status.throughput or 0,
                           status.custom.control_rod_level or 0))
      end
    end

    os.sleep(10)  -- Control loop every 10 seconds
  end
end

function BR_Reactor.getStatus()
  if not BR_Reactor.hardware then return nil end
  return BR_Reactor.hardware:getStatus()
end

function BR_Reactor.calibrate()
  if not BR_Reactor.calibration then return false end
  return BR_Reactor.calibration:runFullCalibration()
end

function BR_Reactor.setActive(state)
  if not BR_Reactor.hardware then return false end
  return BR_Reactor.hardware:setActive(state)
end

function BR_Reactor.setControlRodLevel(level)
  if not BR_Reactor.hardware then return false end
  return BR_Reactor.hardware:setControlRodLevel(level)
end

return BR_Reactor