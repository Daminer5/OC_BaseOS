-- Big Reactors Turbine Calibration
-- Advanced calibration functions for Big Reactors turbines

local BR_Turbine_Calibration = {}
BR_Turbine_Calibration.__index = BR_Turbine_Calibration

function BR_Turbine_Calibration.new(turbine_device)
  return setmetatable({
    turbine = turbine_device,
    calibration_data = {},
    optimal_active = true,
    last_calibration = 0,
    calibration_history = {}
  }, BR_Turbine_Calibration)
end

-- =============================
-- Rotor Speed Calibration
-- =============================

function BR_Turbine_Calibration:calibrateRotorSpeed(target_speed)
  target_speed = target_speed or 1800  -- Default target rotor speed (RPM)

  print("BR-Turbine: Starting rotor speed calibration (target: " .. target_speed .. " RPM)...")

  -- Ensure turbine is active
  self.turbine:setActive(true)
  os.sleep(10)  -- Wait for startup

  -- Monitor rotor speed over time
  local measurements = {}
  local start_time = computer.uptime()

  -- Collect data for 2 minutes
  while computer.uptime() - start_time < 120 do
    local status = self.turbine:getStatus()
    if status.state then
      table.insert(measurements, {
        rotor_speed = status.custom.rotor_speed or 0,
        energy_output = status.throughput or 0,
        fluid_amount = status.custom.fluid_amount or 0,
        fluid_capacity = status.custom.fluid_capacity or 1,
        efficiency = status.efficiency or 0
      })
    end
    os.sleep(2)
  end

  if #measurements == 0 then
    print("BR-Turbine: No valid measurements collected")
    return nil
  end

  -- Calculate averages
  local avg_rotor_speed = 0
  local avg_energy_output = 0
  local avg_fluid_pct = 0
  local avg_efficiency = 0

  for _, m in ipairs(measurements) do
    avg_rotor_speed = avg_rotor_speed + m.rotor_speed
    avg_energy_output = avg_energy_output + m.energy_output
    avg_fluid_pct = avg_fluid_pct + (m.fluid_amount / math.max(m.fluid_capacity, 1))
    avg_efficiency = avg_efficiency + m.efficiency
  end

  avg_rotor_speed = avg_rotor_speed / #measurements
  avg_energy_output = avg_energy_output / #measurements
  avg_fluid_pct = avg_fluid_pct / #measurements
  avg_efficiency = avg_efficiency / #measurements

  -- Calculate performance score
  local speed_deviation = math.abs(avg_rotor_speed - target_speed) / target_speed
  local fluid_factor = avg_fluid_pct
  local efficiency_factor = avg_efficiency

  local performance_score = (1 - speed_deviation) * fluid_factor * efficiency_factor * 100

  print(string.format("BR-Turbine: Calibration results - Rotor: %.1f RPM, Power: %.0f RF/t, Fluid: %.1f%%, Eff: %.3f, Score: %.1f",
                     avg_rotor_speed, avg_energy_output, avg_fluid_pct * 100, avg_efficiency, performance_score))

  local result = {
    rotor_speed = avg_rotor_speed,
    energy_output = avg_energy_output,
    fluid_percentage = avg_fluid_pct,
    efficiency = avg_efficiency,
    performance_score = performance_score,
    target_speed = target_speed,
    speed_deviation = speed_deviation
  }

  table.insert(self.calibration_history, {
    timestamp = os.time(),
    result = result
  })

  return result
end

-- =============================
-- Fluid Flow Optimization
-- =============================

function BR_Turbine_Calibration:optimizeFluidFlow()
  print("BR-Turbine: Starting fluid flow optimization...")

  -- Monitor fluid consumption and power output relationship
  local flow_data = {}
  local start_time = computer.uptime()

  -- Ensure turbine is active
  self.turbine:setActive(true)
  os.sleep(5)

  local initial_fluid = self.turbine:getStatus().custom.fluid_amount or 0

  -- Monitor for 3 minutes
  while computer.uptime() - start_time < 180 do
    local status = self.turbine:getStatus()
    if status.state then
      local current_fluid = status.custom.fluid_amount or 0
      local fluid_used = initial_fluid - current_fluid

      table.insert(flow_data, {
        time = computer.uptime() - start_time,
        rotor_speed = status.custom.rotor_speed or 0,
        energy_output = status.throughput or 0,
        fluid_used = fluid_used,
        fluid_amount = current_fluid,
        fluid_capacity = status.custom.fluid_capacity or 1
      })
    end
    os.sleep(5)
  end

  -- Analyze fluid efficiency
  if #flow_data > 1 then
    local total_energy = 0
    local total_fluid_used = 0

    for i = 2, #flow_data do
      local dt = flow_data[i].time - flow_data[i-1].time
      local avg_power = (flow_data[i].energy_output + flow_data[i-1].energy_output) / 2
      total_energy = total_energy + (avg_power * dt)
      total_fluid_used = flow_data[i].fluid_used
    end

    local fluid_efficiency = total_energy / math.max(total_fluid_used, 1)  -- RF per fluid unit

    print(string.format("BR-Turbine: Fluid efficiency analysis - Total energy: %.0f RF, Fluid used: %.1f, Efficiency: %.1f RF/fluid",
                       total_energy, total_fluid_used, fluid_efficiency))

    return {
      total_energy_produced = total_energy,
      total_fluid_consumed = total_fluid_used,
      fluid_efficiency = fluid_efficiency,
      flow_data = flow_data
    }
  end

  return nil
end

-- =============================
-- Load Balancing
-- =============================

function BR_Turbine_Calibration:balanceLoad(reactor_output)
  -- Adjust turbine operation based on reactor output
  local status = self.turbine:getStatus()
  if not status.state then return false end

  local current_output = status.throughput or 0
  local fluid_pct = (status.custom.fluid_amount or 0) / (status.custom.fluid_capacity or 1)

  -- Simple load balancing logic
  if reactor_output > current_output * 1.2 and fluid_pct > 0.8 then
    -- Reactor producing more than turbine can handle, turbine is well-supplied
    print("BR-Turbine: Load balanced - reactor output matches turbine capacity")
    return true
  elseif reactor_output < current_output * 0.8 then
    -- Turbine producing more than reactor, may need to reduce turbine activity
    print("BR-Turbine: Load imbalance detected - reducing turbine output")
    -- Could implement turbine throttling here if available
    return false
  end

  return true
end

-- =============================
-- Maintenance Checks
-- =============================

function BR_Turbine_Calibration:checkMaintenance()
  local status = self.turbine:getStatus()
  if not status.state then return {needs_maintenance = true, reason = "turbine_offline"} end

  local issues = {}

  -- Check rotor speed
  local rotor_speed = status.custom.rotor_speed or 0
  if rotor_speed < 500 then
    table.insert(issues, "low_rotor_speed")
  elseif rotor_speed > 1950 then
    table.insert(issues, "high_rotor_speed")
  end

  -- Check fluid levels
  local fluid_pct = (status.custom.fluid_amount or 0) / (status.custom.fluid_capacity or 1)
  if fluid_pct < 0.1 then
    table.insert(issues, "low_fluid_level")
  end

  -- Check shaft damage
  local shaft_damage = status.custom.shaft_damage or 0
  if shaft_damage > 50 then
    table.insert(issues, "high_shaft_damage")
  end

  return {
    needs_maintenance = #issues > 0,
    issues = issues,
    rotor_speed = rotor_speed,
    fluid_percentage = fluid_pct,
    shaft_damage = shaft_damage
  }
end

-- =============================
-- API Functions
-- =============================

function BR_Turbine_Calibration:getOptimalSettings()
  return {
    active = self.optimal_active,
    last_calibration = self.last_calibration,
    calibration_history = self.calibration_history
  }
end

function BR_Turbine_Calibration:runFullCalibration()
  self.last_calibration = os.time()

  print("BR-Turbine: Running full calibration sequence...")

  -- Step 1: Rotor speed calibration
  local speed_result = self:calibrateRotorSpeed()

  -- Step 2: Fluid flow optimization
  local fluid_result = self:optimizeFluidFlow()

  -- Step 3: Maintenance check
  local maintenance_result = self:checkMaintenance()

  return {
    rotor_speed = speed_result,
    fluid_flow = fluid_result,
    maintenance = maintenance_result,
    timestamp = os.time()
  }
end

return BR_Turbine_Calibration