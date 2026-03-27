-- Big Reactors Control (BR) - Auto Calibration System
-- Automatically calibrates Big Reactors reactor and turbine systems for optimal efficiency

local component = require("component")
local computer = require("computer")
local event = require("event")

local BR = {}

-- Configuration
BR.config = {
  calibration_interval = 300,  -- 5 minutes between calibrations
  stability_window = 60,       -- 1 minute stability check
  efficiency_tolerance = 0.05, -- 5% efficiency change threshold
  temperature_target = 800,    -- Target reactor temperature (Celsius)
  max_control_rod_level = 90,  -- Maximum control rod insertion (%)
  min_control_rod_level = 10,  -- Minimum control rod insertion (%)
  calibration_steps = 10,      -- Number of calibration steps
  rotor_speed_target = 1800,   -- Target turbine rotor speed (RPM)
}

-- State tracking
BR.state = {
  last_calibration = 0,
  is_calibrating = false,
  calibration_data = {},
  optimal_settings = {},
  reactors = {},
  turbines = {}
}

-- =============================
-- Hardware Detection
-- =============================

function BR:scanHardware()
  self.state.reactors = {}
  self.state.turbines = {}

  -- Find reactors
  for address, ctype in component.list("br_reactor") do
    local reactor = require("hardware.br_reactor").new(address)
    if reactor then
      table.insert(self.state.reactors, {
        address = address,
        device = reactor,
        current_rod_level = reactor:getStatus().custom.control_rod_level or 50
      })
    end
  end

  -- Find turbines
  for address, ctype in component.list("br_turbine") do
    local turbine = require("hardware.br_turbine").new(address)
    if turbine then
      table.insert(self.state.turbines, {
        address = address,
        device = turbine,
        current_active = turbine:getStatus().state
      })
    end
  end

  return #self.state.reactors > 0 or #self.state.turbines > 0
end

-- =============================
-- Reactor Calibration
-- =============================

function BR:calibrateReactor(reactor_info)
  local reactor = reactor_info.device
  local results = {}

  print("BR: Starting reactor calibration for " .. reactor_info.address)

  -- Test different control rod levels
  for step = 1, self.config.calibration_steps do
    local rod_level = self.config.min_control_rod_level +
                     ((self.config.max_control_rod_level - self.config.min_control_rod_level) *
                      (step - 1) / (self.config.calibration_steps - 1))

    -- Set control rod level
    reactor:setControlRodLevel(math.floor(rod_level))

    -- Wait for stabilization
    os.sleep(self.config.stability_window)

    -- Measure performance
    local status = reactor:getStatus()
    if status.state then
      local efficiency = status.efficiency or 0
      local temperature = status.temperature or 0
      local energy_output = status.throughput or 0

      table.insert(results, {
        rod_level = rod_level,
        efficiency = efficiency,
        temperature = temperature,
        energy_output = energy_output,
        score = self:calculateReactorScore(efficiency, temperature, energy_output)
      })

      print(string.format("BR: Rod %.1f%% -> Eff: %.3f, Temp: %.1f°C, Power: %.0f RF/t",
                         rod_level, efficiency, temperature, energy_output))
    end
  end

  -- Find optimal settings
  table.sort(results, function(a, b) return a.score > b.score end)
  local optimal = results[1]

  if optimal then
    print(string.format("BR: Optimal reactor settings - Rod: %.1f%%, Score: %.3f",
                       optimal.rod_level, optimal.score))

    -- Apply optimal settings
    reactor:setControlRodLevel(math.floor(optimal.rod_level))

    return {
      rod_level = optimal.rod_level,
      efficiency = optimal.efficiency,
      temperature = optimal.temperature,
      energy_output = optimal.energy_output,
      score = optimal.score
    }
  end

  return nil
end

function BR:calculateReactorScore(efficiency, temperature, energy_output)
  -- Score based on efficiency, temperature stability, and energy output
  local temp_penalty = math.abs(temperature - self.config.temperature_target) / 1000
  local efficiency_score = efficiency * 1000
  local output_score = energy_output / 100

  return efficiency_score + output_score - temp_penalty
end

-- =============================
-- Turbine Calibration
-- =============================

function BR:calibrateTurbine(turbine_info)
  local turbine = turbine_info.device

  print("BR: Starting turbine calibration for " .. turbine_info.address)

  -- Ensure turbine is active
  turbine:setActive(true)
  os.sleep(5)  -- Wait for startup

  -- Monitor turbine performance over time
  local measurements = {}
  local start_time = computer.uptime()

  while computer.uptime() - start_time < self.config.stability_window do
    local status = turbine:getStatus()
    if status.state then
      table.insert(measurements, {
        rotor_speed = status.custom.rotor_speed or 0,
        energy_output = status.throughput or 0,
        efficiency = status.efficiency or 0,
        fluid_amount = status.custom.fluid_amount or 0,
        fluid_capacity = status.custom.fluid_capacity or 1
      })
    end
    os.sleep(2)
  end

  -- Calculate averages
  if #measurements > 0 then
    local avg_rotor_speed = 0
    local avg_energy_output = 0
    local avg_efficiency = 0
    local avg_fluid_pct = 0

    for _, m in ipairs(measurements) do
      avg_rotor_speed = avg_rotor_speed + m.rotor_speed
      avg_energy_output = avg_energy_output + m.energy_output
      avg_efficiency = avg_efficiency + m.efficiency
      avg_fluid_pct = avg_fluid_pct + (m.fluid_amount / m.fluid_capacity)
    end

    avg_rotor_speed = avg_rotor_speed / #measurements
    avg_energy_output = avg_energy_output / #measurements
    avg_efficiency = avg_efficiency / #measurements
    avg_fluid_pct = avg_fluid_pct / #measurements

    print(string.format("BR: Turbine performance - Rotor: %.1f RPM, Power: %.0f RF/t, Eff: %.3f, Fluid: %.1f%%",
                       avg_rotor_speed, avg_energy_output, avg_efficiency, avg_fluid_pct * 100))

    return {
      rotor_speed = avg_rotor_speed,
      energy_output = avg_energy_output,
      efficiency = avg_efficiency,
      fluid_percentage = avg_fluid_pct,
      score = self:calculateTurbineScore(avg_rotor_speed, avg_energy_output, avg_efficiency)
    }
  end

  return nil
end

function BR:calculateTurbineScore(rotor_speed, energy_output, efficiency)
  -- Score based on rotor speed target, energy output, and efficiency
  local speed_penalty = math.abs(rotor_speed - self.config.rotor_speed_target) / 100
  local output_score = energy_output / 100
  local efficiency_score = efficiency * 1000

  return output_score + efficiency_score - speed_penalty
end

-- =============================
-- Grid Balancing
-- =============================

function BR:balanceGrid()
  if #self.state.reactors == 0 or #self.state.turbines == 0 then
    return false
  end

  print("BR: Starting grid balancing...")

  -- Calculate total reactor output capacity
  local total_reactor_output = 0
  for _, reactor in ipairs(self.state.reactors) do
    local status = reactor.device:getStatus()
    if status.state then
      total_reactor_output = total_reactor_output + (status.throughput or 0)
    end
  end

  -- Calculate total turbine consumption capacity
  local total_turbine_capacity = 0
  for _, turbine in ipairs(self.state.turbines) do
    local status = turbine.device:getStatus()
    if status.state then
      -- Estimate turbine capacity based on fluid levels and rotor speed
      local fluid_pct = (status.custom.fluid_amount or 0) / (status.custom.fluid_capacity or 1)
      local capacity_factor = math.min(fluid_pct, (status.custom.rotor_speed or 0) / 2000)
      total_turbine_capacity = total_turbine_capacity + (capacity_factor * 100000)  -- Rough estimate
    end
  end

  -- Adjust reactor output to match turbine capacity
  local balance_ratio = total_turbine_capacity / math.max(total_reactor_output, 1)

  print(string.format("BR: Grid balance - Reactors: %.0f RF/t, Turbines: %.0f RF/t capacity, Ratio: %.3f",
                     total_reactor_output, total_turbine_capacity, balance_ratio))

  -- Adjust control rods based on balance ratio
  for _, reactor in ipairs(self.state.reactors) do
    local current_rod = reactor.current_rod_level
    local adjustment = 0

    if balance_ratio > 1.1 then
      -- Too much turbine capacity, reduce reactor output
      adjustment = 5  -- Insert more control rods
    elseif balance_ratio < 0.9 then
      -- Not enough turbine capacity, increase reactor output
      adjustment = -5  -- Withdraw control rods
    end

    if adjustment ~= 0 then
      local new_rod_level = math.max(self.config.min_control_rod_level,
                                   math.min(self.config.max_control_rod_level,
                                           current_rod + adjustment))
      reactor.device:setControlRodLevel(math.floor(new_rod_level))
      reactor.current_rod_level = new_rod_level

      print(string.format("BR: Adjusted reactor %s rod level to %.1f%%",
                         reactor.address:sub(1, 8), new_rod_level))
    end
  end

  return true
end

-- =============================
-- Main Calibration Loop
-- =============================

function BR:startCalibration()
  if self.state.is_calibrating then
    print("BR: Calibration already in progress")
    return false
  end

  self.state.is_calibrating = true
  print("BR: Starting auto-calibration sequence...")

  -- Scan for hardware
  if not self:scanHardware() then
    print("BR: No Big Reactors hardware found")
    self.state.is_calibrating = false
    return false
  end

  -- Calibrate individual components
  self.state.optimal_settings = {}

  -- Calibrate reactors
  for _, reactor_info in ipairs(self.state.reactors) do
    local optimal = self:calibrateReactor(reactor_info)
    if optimal then
      self.state.optimal_settings[reactor_info.address] = optimal
    end
  end

  -- Calibrate turbines
  for _, turbine_info in ipairs(self.state.turbines) do
    local optimal = self:calibrateTurbine(turbine_info)
    if optimal then
      self.state.optimal_settings[turbine_info.address] = optimal
    end
  end

  -- Balance the grid
  self:balanceGrid()

  self.state.last_calibration = computer.uptime()
  self.state.is_calibrating = false

  print("BR: Auto-calibration complete")
  return true
end

function BR:run()
  print("BR: Big Reactors Grid Control starting...")

  while true do
    local now = computer.uptime()

    -- Periodic calibration
    if now - self.state.last_calibration >= self.config.calibration_interval then
      self:startCalibration()
    end

    -- Continuous monitoring and adjustment
    self:continuousAdjustment()

    os.sleep(10)  -- Check every 10 seconds
  end
end

function BR:continuousAdjustment()
  -- Quick adjustments for stability
  for _, reactor in ipairs(self.state.reactors) do
    local status = reactor.device:getStatus()
    if status.state then
      local temperature = status.temperature or 0
      local current_rod = reactor.current_rod_level

      -- Temperature control
      if temperature > self.config.temperature_target + 50 then
        -- Too hot, insert more control rods
        local new_rod = math.min(self.config.max_control_rod_level, current_rod + 2)
        if new_rod ~= current_rod then
          reactor.device:setControlRodLevel(math.floor(new_rod))
          reactor.current_rod_level = new_rod
        end
      elseif temperature < self.config.temperature_target - 50 then
        -- Too cold, withdraw control rods
        local new_rod = math.max(self.config.min_control_rod_level, current_rod - 2)
        if new_rod ~= current_rod then
          reactor.device:setControlRodLevel(math.floor(new_rod))
          reactor.current_rod_level = new_rod
        end
      end
    end
  end
end

-- =============================
-- API Functions
-- =============================

function BR:getStatus()
  return {
    is_calibrating = self.state.is_calibrating,
    last_calibration = self.state.last_calibration,
    reactor_count = #self.state.reactors,
    turbine_count = #self.state.turbines,
    optimal_settings = self.state.optimal_settings
  }
end

function BR:manualCalibrate()
  return self:startCalibration()
end

function BR:setConfig(new_config)
  for k, v in pairs(new_config) do
    if self.config[k] ~= nil then
      self.config[k] = v
    end
  end
  return true
end

return BR