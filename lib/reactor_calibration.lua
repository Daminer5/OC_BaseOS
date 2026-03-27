-- Big Reactors Reactor Calibration
-- Advanced calibration functions for Big Reactors passive reactors

local BR_Reactor_Calibration = {}
BR_Reactor_Calibration.__index = BR_Reactor_Calibration

function BR_Reactor_Calibration.new(reactor_device)
  return setmetatable({
    reactor = reactor_device,
    calibration_data = {},
    optimal_rod_level = 50,  -- Default starting point
    last_calibration = 0,
    calibration_history = {}
  }, BR_Reactor_Calibration)
end

-- =============================
-- Efficiency Calibration
-- =============================

function BR_Reactor_Calibration:calibrateEfficiency()
  print("BR-Reactor: Starting efficiency calibration...")

  local results = {}
  local test_levels = {10, 20, 30, 40, 50, 60, 70, 80, 90}

  for _, rod_level in ipairs(test_levels) do
    self.reactor:setControlRodLevel(rod_level)
    os.sleep(30)  -- Wait for stabilization

    local status = self.reactor:getStatus()
    if status.state then
      local efficiency = status.efficiency or 0
      local power_output = status.throughput or 0
      local temperature = status.temperature or 0
      local fuel_consumption = status.custom.fuel_amount or 0

      -- Calculate efficiency score (power per fuel unit)
      local efficiency_score = power_output / math.max(fuel_consumption, 1)

      table.insert(results, {
        rod_level = rod_level,
        efficiency = efficiency,
        power_output = power_output,
        temperature = temperature,
        fuel_consumption = fuel_consumption,
        efficiency_score = efficiency_score
      })

      print(string.format("Rod %d%%: Eff=%.3f, Power=%.0f RF/t, Temp=%.1f°C",
                         rod_level, efficiency, power_output, temperature))
    end
  end

  -- Find optimal rod level
  table.sort(results, function(a, b) return a.efficiency_score > b.efficiency_score end)
  local optimal = results[1]

  if optimal then
    self.optimal_rod_level = optimal.rod_level
    self.reactor:setControlRodLevel(optimal.rod_level)

    table.insert(self.calibration_history, {
      timestamp = os.time(),
      optimal_rod_level = optimal.rod_level,
      efficiency_score = optimal.efficiency_score,
      power_output = optimal.power_output,
      temperature = optimal.temperature
    })

    print(string.format("Optimal rod level: %d%% (Efficiency score: %.3f)",
                       optimal.rod_level, optimal.efficiency_score))

    return optimal
  end

  return nil
end

-- =============================
-- Temperature Control Calibration
-- =============================

function BR_Reactor_Calibration:calibrateTemperature(target_temp)
  target_temp = target_temp or 850  -- Default target temperature

  print("BR-Reactor: Starting temperature calibration (target: " .. target_temp .. "°C)...")

  -- Binary search for optimal rod level to achieve target temperature
  local min_rod = 10
  local max_rod = 90
  local best_rod = 50
  local best_diff = math.huge

  for iteration = 1, 8 do  -- 8 iterations for good precision
    local test_rod = math.floor((min_rod + max_rod) / 2)

    self.reactor:setControlRodLevel(test_rod)
    os.sleep(20)  -- Wait for temperature stabilization

    local status = self.reactor:getStatus()
    if status.state then
      local current_temp = status.temperature or 0
      local temp_diff = math.abs(current_temp - target_temp)

      if temp_diff < best_diff then
        best_diff = temp_diff
        best_rod = test_rod
      end

      -- Adjust search bounds
      if current_temp < target_temp then
        max_rod = test_rod - 1  -- Too cold, need less control rods
      else
        min_rod = test_rod + 1  -- Too hot, need more control rods
      end

      print(string.format("Iteration %d: Rod %d%% -> Temp %.1f°C (diff: %.1f°C)",
                         iteration, test_rod, current_temp, temp_diff))
    end
  end

  -- Apply best setting
  self.reactor:setControlRodLevel(best_rod)
  self.optimal_rod_level = best_rod

  print(string.format("Temperature calibration complete. Optimal rod level: %d%%", best_rod))

  return {
    rod_level = best_rod,
    target_temperature = target_temp,
    final_temperature = best_diff
  }
end

-- =============================
-- Fuel Efficiency Calibration
-- =============================

function BR_Reactor_Calibration:calibrateFuelEfficiency()
  print("BR-Reactor: Starting fuel efficiency calibration...")

  -- Monitor fuel consumption over time at different rod levels
  local fuel_data = {}
  local test_levels = {30, 50, 70}

  for _, rod_level in ipairs(test_levels) do
    self.reactor:setControlRodLevel(rod_level)

    -- Monitor for 2 minutes
    local start_fuel = self.reactor:getStatus().custom.fuel_amount or 0
    local start_time = os.time()
    local power_samples = {}

    for i = 1, 60 do  -- 60 samples over 2 minutes
      os.sleep(2)
      local status = self.reactor:getStatus()
      if status.state then
        table.insert(power_samples, status.throughput or 0)
      end
    end

    local end_fuel = self.reactor:getStatus().custom.fuel_amount or 0
    local fuel_used = start_fuel - end_fuel

    -- Calculate average power output
    local total_power = 0
    for _, power in ipairs(power_samples) do
      total_power = total_power + power
    end
    local avg_power = total_power / #power_samples

    -- Calculate fuel efficiency (RF per fuel unit)
    local fuel_efficiency = avg_power / math.max(fuel_used, 0.1)

    table.insert(fuel_data, {
      rod_level = rod_level,
      fuel_used = fuel_used,
      avg_power = avg_power,
      fuel_efficiency = fuel_efficiency
    })

    print(string.format("Rod %d%%: Fuel used=%.2f, Avg power=%.0f RF/t, Efficiency=%.1f RF/fuel",
                       rod_level, fuel_used, avg_power, fuel_efficiency))
  end

  -- Find optimal fuel efficiency
  table.sort(fuel_data, function(a, b) return a.fuel_efficiency > b.fuel_efficiency end)
  local optimal = fuel_data[1]

  if optimal then
    self.reactor:setControlRodLevel(optimal.rod_level)
    self.optimal_rod_level = optimal.rod_level

    print(string.format("Fuel efficiency calibration complete. Optimal rod level: %d%% (%.1f RF/fuel)",
                       optimal.rod_level, optimal.fuel_efficiency))

    return optimal
  end

  return nil
end

-- =============================
-- Adaptive Control
-- =============================

function BR_Reactor_Calibration:adaptiveControl()
  local status = self.reactor:getStatus()
  if not status.state then return false end

  local current_temp = status.temperature or 0
  local current_rod = status.custom.control_rod_level or 50
  local target_temp = 850  -- Target temperature

  -- Simple PID-like control for temperature
  local temp_error = target_temp - current_temp
  local adjustment = temp_error * 0.1  -- Proportional gain

  -- Limit adjustment rate
  adjustment = math.max(-5, math.min(5, adjustment))

  local new_rod_level = math.max(10, math.min(90, current_rod + adjustment))

  if math.abs(new_rod_level - current_rod) > 0.5 then
    self.reactor:setControlRodLevel(math.floor(new_rod_level))
    return true
  end

  return false
end

-- =============================
-- API Functions
-- =============================

function BR_Reactor_Calibration:getOptimalSettings()
  return {
    rod_level = self.optimal_rod_level,
    last_calibration = self.last_calibration,
    calibration_history = self.calibration_history
  }
end

function BR_Reactor_Calibration:runFullCalibration()
  self.last_calibration = os.time()

  print("BR-Reactor: Running full calibration sequence...")

  -- Step 1: Efficiency calibration
  local efficiency_result = self:calibrateEfficiency()

  -- Step 2: Temperature fine-tuning
  local temp_result = self:calibrateTemperature()

  -- Step 3: Fuel efficiency optimization
  local fuel_result = self:calibrateFuelEfficiency()

  return {
    efficiency = efficiency_result,
    temperature = temp_result,
    fuel = fuel_result,
    timestamp = os.time()
  }
end

return BR_Reactor_Calibration