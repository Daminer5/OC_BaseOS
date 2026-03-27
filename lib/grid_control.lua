-- Big Reactors Grid Control
-- Coordinates multiple reactors and turbines for optimal grid performance

local BR_GridControl = {}
BR_GridControl.__index = BR_GridControl

function BR_GridControl.new()
  return setmetatable({
    reactors = {},
    turbines = {},
    grid_status = {},
    last_optimization = 0,
    optimization_interval = 600,  -- 10 minutes
    emergency_shutdown = false
  }, BR_GridControl)
end

-- =============================
-- Hardware Discovery
-- =============================

function BR_GridControl:discoverHardware()
  local component = require("component")

  self.reactors = {}
  self.turbines = {}

  -- Find all reactors
  for address, ctype in component.list("br_reactor") do
    local reactor_hw = require("hardware.br_reactor").new(address)
    local reactor_cal = require("reactor_calibration").new(reactor_hw)

    table.insert(self.reactors, {
      address = address,
      hardware = reactor_hw,
      calibration = reactor_cal,
      priority = 1,  -- Default priority
      status = "unknown"
    })

    print("BR-Grid: Discovered reactor " .. address:sub(1, 8))
  end

  -- Find all turbines
  for address, ctype in component.list("br_turbine") do
    local turbine_hw = require("hardware.br_turbine").new(address)
    local turbine_cal = require("turbine_calibration").new(turbine_hw)

    table.insert(self.turbines, {
      address = address,
      hardware = turbine_hw,
      calibration = turbine_cal,
      priority = 1,  -- Default priority
      status = "unknown"
    })

    print("BR-Grid: Discovered turbine " .. address:sub(1, 8))
  end

  print(string.format("BR-Grid: Discovery complete - %d reactors, %d turbines",
                     #self.reactors, #self.turbines))

  return #self.reactors > 0 or #self.turbines > 0
end

-- =============================
-- Grid Status Monitoring
-- =============================

function BR_GridControl:getGridStatus()
  local status = {
    timestamp = os.time(),
    reactors = {},
    turbines = {},
    total_power_output = 0,
    total_power_capacity = 0,
    total_fluid_storage = 0,
    efficiency = 0,
    health_score = 100
  }

  -- Collect reactor status
  for _, reactor in ipairs(self.reactors) do
    local hw_status = reactor.hardware:getStatus()
    local cal_status = reactor.calibration:getOptimalSettings()

    local reactor_status = {
      address = reactor.address,
      active = hw_status.state,
      temperature = hw_status.temperature,
      power_output = hw_status.throughput,
      control_rod_level = hw_status.custom.control_rod_level,
      fuel_amount = hw_status.custom.fuel_amount,
      optimal_rod_level = cal_status.rod_level,
      last_calibration = cal_status.last_calibration
    }

    table.insert(status.reactors, reactor_status)

    if hw_status.state then
      status.total_power_output = status.total_power_output + (hw_status.throughput or 0)
      status.total_power_capacity = status.total_power_capacity + 100000  -- Estimate
    end
  end

  -- Collect turbine status
  for _, turbine in ipairs(self.turbines) do
    local hw_status = turbine.hardware:getStatus()
    local cal_status = turbine.calibration:getOptimalSettings()

    local turbine_status = {
      address = turbine.address,
      active = hw_status.state,
      rotor_speed = hw_status.custom.rotor_speed,
      power_output = hw_status.throughput,
      fluid_amount = hw_status.custom.fluid_amount,
      fluid_capacity = hw_status.custom.fluid_capacity,
      efficiency = hw_status.efficiency,
      last_calibration = cal_status.last_calibration
    }

    table.insert(status.turbines, turbine_status)

    if hw_status.state then
      status.total_power_output = status.total_power_output - (hw_status.throughput or 0)  -- Net power
      status.total_fluid_storage = status.total_fluid_storage + (hw_status.custom.fluid_capacity or 0)
    end
  end

  -- Calculate overall efficiency
  if #status.reactors > 0 and #status.turbines > 0 then
    local reactor_efficiency = 0
    local turbine_efficiency = 0

    for _, r in ipairs(status.reactors) do
      reactor_efficiency = reactor_efficiency + (r.power_output or 0)
    end

    for _, t in ipairs(status.turbines) do
      turbine_efficiency = turbine_efficiency + (t.efficiency or 0)
    end

    reactor_efficiency = reactor_efficiency / #status.reactors
    turbine_efficiency = turbine_efficiency / #status.turbines

    status.efficiency = (reactor_efficiency + turbine_efficiency) / 2
  end

  self.grid_status = status
  return status
end

-- =============================
-- Grid Optimization
-- =============================

function BR_GridControl:optimizeGrid()
  print("BR-Grid: Starting grid optimization...")

  -- Step 1: Calibrate individual components
  for _, reactor in ipairs(self.reactors) do
    print("BR-Grid: Calibrating reactor " .. reactor.address:sub(1, 8))
    reactor.calibration:runFullCalibration()
  end

  for _, turbine in ipairs(self.turbines) do
    print("BR-Grid: Calibrating turbine " .. turbine.address:sub(1, 8))
    turbine.calibration:runFullCalibration()
  end

  -- Step 2: Balance power production and consumption
  self:balancePowerFlow()

  -- Step 3: Optimize for efficiency
  self:optimizeEfficiency()

  self.last_optimization = os.time()
  print("BR-Grid: Grid optimization complete")
end

function BR_GridControl:balancePowerFlow()
  local status = self:getGridStatus()

  -- Calculate power balance
  local reactor_output = 0
  for _, r in ipairs(status.reactors) do
    reactor_output = reactor_output + (r.power_output or 0)
  end

  local turbine_capacity = 0
  for _, t in ipairs(status.turbines) do
    local fluid_pct = (t.fluid_amount or 0) / (t.fluid_capacity or 1)
    turbine_capacity = turbine_capacity + (fluid_pct * 100000)  -- Rough estimate
  end

  local balance_ratio = turbine_capacity / math.max(reactor_output, 1)

  print(string.format("BR-Grid: Power balance - Reactors: %.0f RF/t, Turbines: %.0f RF/t capacity, Ratio: %.3f",
                     reactor_output, turbine_capacity, balance_ratio))

  -- Adjust reactor output based on turbine capacity
  if balance_ratio > 1.2 then
    -- Too much turbine capacity, reduce reactor output
    for _, reactor in ipairs(self.reactors) do
      local current_rod = reactor.hardware:getStatus().custom.control_rod_level or 50
      local new_rod = math.min(90, current_rod + 5)
      reactor.hardware:setControlRodLevel(new_rod)
      print(string.format("BR-Grid: Reduced reactor %s output (rod %d%% -> %d%%)",
                         reactor.address:sub(1, 8), current_rod, new_rod))
    end
  elseif balance_ratio < 0.8 then
    -- Not enough turbine capacity, increase reactor output
    for _, reactor in ipairs(self.reactors) do
      local current_rod = reactor.hardware:getStatus().custom.control_rod_level or 50
      local new_rod = math.max(10, current_rod - 5)
      reactor.hardware:setControlRodLevel(new_rod)
      print(string.format("BR-Grid: Increased reactor %s output (rod %d%% -> %d%%)",
                         reactor.address:sub(1, 8), current_rod, new_rod))
    end
  end
end

function BR_GridControl:optimizeEfficiency()
  -- Find the most efficient reactor and prioritize it
  local best_reactor = nil
  local best_efficiency = 0

  for _, reactor in ipairs(self.reactors) do
    local status = reactor.hardware:getStatus()
    if status.state and status.efficiency > best_efficiency then
      best_efficiency = status.efficiency
      best_reactor = reactor
    end
  end

  if best_reactor then
    print(string.format("BR-Grid: Prioritizing most efficient reactor %s (eff: %.3f)",
                       best_reactor.address:sub(1, 8), best_efficiency))

    -- Could implement load shifting logic here
    -- For now, just ensure the best reactor is running optimally
    best_reactor.calibration:adaptiveControl()
  end
end

-- =============================
-- Emergency Controls
-- =============================

function BR_GridControl:emergencyShutdown(reason)
  if self.emergency_shutdown then return end

  self.emergency_shutdown = true
  print("BR-Grid: EMERGENCY SHUTDOWN - " .. (reason or "Unknown reason"))

  -- Shutdown all reactors
  for _, reactor in ipairs(self.reactors) do
    reactor.hardware:setActive(false)
    print("BR-Grid: Shut down reactor " .. reactor.address:sub(1, 8))
  end

  -- Shutdown all turbines
  for _, turbine in ipairs(self.turbines) do
    turbine.hardware:setActive(false)
    print("BR-Grid: Shut down turbine " .. turbine.address:sub(1, 8))
  end

  -- Alert system
  local alerts = require("alerts")
  alerts.createAlert("br", "emergency_shutdown", alerts.SEVERITY.CRITICAL,
    "Big Reactors grid emergency shutdown: " .. (reason or "Unknown"),
    {reason = reason, timestamp = os.time()})
end

function BR_GridControl:checkSafety()
  local status = self:getGridStatus()
  local issues = {}

  -- Check reactor temperatures
  for _, reactor in ipairs(status.reactors) do
    if reactor.active and reactor.temperature > 1000 then
      table.insert(issues, "reactor_overheat_" .. reactor.address:sub(1, 8))
    end
  end

  -- Check turbine rotor speeds
  for _, turbine in ipairs(status.turbines) do
    if turbine.active and turbine.rotor_speed > 1950 then
      table.insert(issues, "turbine_overspeed_" .. turbine.address:sub(1, 8))
    end
  end

  -- Emergency shutdown if critical issues
  if #issues > 0 then
    self:emergencyShutdown("Safety violations: " .. table.concat(issues, ", "))
    return false
  end

  return true
end

-- =============================
-- Main Control Loop
-- =============================

function BR_GridControl:run()
  print("BR-Grid: Big Reactors Grid Control starting...")

  -- Initial hardware discovery
  if not self:discoverHardware() then
    print("BR-Grid: No Big Reactors hardware found, exiting")
    return
  end

  -- Initial optimization
  self:optimizeGrid()

  while true do
    -- Periodic optimization
    if os.time() - self.last_optimization >= self.optimization_interval then
      self:optimizeGrid()
    end

    -- Continuous safety monitoring
    if not self:checkSafety() then
      break  -- Emergency shutdown occurred
    end

    -- Adaptive control for all components
    for _, reactor in ipairs(self.reactors) do
      reactor.calibration:adaptiveControl()
    end

    os.sleep(30)  -- Check every 30 seconds
  end
end

-- =============================
-- API Functions
-- =============================

function BR_GridControl:getStatus()
  return self:getGridStatus()
end

function BR_GridControl:manualOptimize()
  self:optimizeGrid()
  return true
end

function BR_GridControl:setReactorPriority(address, priority)
  for _, reactor in ipairs(self.reactors) do
    if reactor.address == address then
      reactor.priority = priority
      return true
    end
  end
  return false
end

return BR_GridControl