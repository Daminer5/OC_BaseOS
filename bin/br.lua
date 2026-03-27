-- Big Reactors Control (BR) Main Runner
-- Command-line interface for BRCtrl auto-calibration system

local args = {...}

local function printUsage()
  print("Big Reactors Control (BR)")
  print("Usage: br <command>")
  print("")
  print("Commands:")
  print("  start          Start full grid control with auto-calibration")
  print("  calibrate      Run manual calibration on all components")
  print("  status         Show current grid status")
  print("  reactor        Reactor-specific commands")
  print("  turbine        Turbine-specific commands")
  print("  emergency      Emergency shutdown all reactors/turbines")
  print("  help           Show this help")
  print("")
  print("Examples:")
  print("  br start")
  print("  br calibrate")
  print("  br status")
end

local function startGridControl()
  print("BR: Starting Big Reactors Control...")

  local BR_GridControl = require("grid_control")
  local grid = BR_GridControl.new()

  -- Handle graceful shutdown
  local event = require("event")
  event.listen("interrupted", function()
    print("BR: Shutdown requested")
    grid:emergencyShutdown("manual_shutdown")
    os.exit()
  end)

  grid:run()
end

local function manualCalibrate()
  print("BR: Running manual calibration...")

  local BR_GridControl = require("grid_control")
  local grid = BR_GridControl.new()

  if grid:discoverHardware() then
    grid:manualOptimize()
    print("BR: Manual calibration complete")
  else
    print("BR: No hardware found")
  end
end

local function showStatus()
  local BR_GridControl = require("grid_control")
  local grid = BR_GridControl.new()

  if grid:discoverHardware() then
    local status = grid:getStatus()

    print("BR Grid Status:")
    print(string.format("  Reactors: %d", #status.reactors))
    print(string.format("  Turbines: %d", #status.turbines))
    print(string.format("  Total Power Output: %.0f RF/t", status.total_power_output))
    print(string.format("  Efficiency: %.1f%%", status.efficiency * 100))
    print(string.format("  Health Score: %d/100", status.health_score))

    print("\nReactors:")
    for _, reactor in ipairs(status.reactors) do
      print(string.format("  %s: %s, %.1f°C, %.0f RF/t",
                         reactor.address:sub(1, 8),
                         reactor.active and "ON" or "OFF",
                         reactor.temperature or 0,
                         reactor.power_output or 0))
    end

    print("\nTurbines:")
    for _, turbine in ipairs(status.turbines) do
      print(string.format("  %s: %s, %.1f RPM, %.0f RF/t",
                         turbine.address:sub(1, 8),
                         turbine.active and "ON" or "OFF",
                         turbine.rotor_speed or 0,
                         turbine.power_output or 0))
    end
  else
    print("BR: No Big Reactors hardware found")
  end
end

local function emergencyShutdown()
  print("BR: Initiating emergency shutdown...")

  local BR_GridControl = require("grid_control")
  local grid = BR_GridControl.new()

  if grid:discoverHardware() then
    grid:emergencyShutdown("command_line_shutdown")
    print("BR: Emergency shutdown complete")
  else
    print("BR: No hardware found to shut down")
  end
end

local function reactorCommands(subcmd)
  if subcmd == "calibrate" then
    print("BR: Calibrating reactors...")
    local BR_Reactor = require("lib.nodes.energy_generation.BR_Reactor")
    if BR_Reactor.init() then
      BR_Reactor.calibrate()
      print("BR: Reactor calibration complete")
    else
      print("BR: No reactor found")
    end
  elseif subcmd == "status" then
    local BR_Reactor = require("lib.nodes.energy_generation.BR_Reactor")
    if BR_Reactor.init() then
      local status = BR_Reactor.getStatus()
      if status then
        print("Reactor Status:")
        print(string.format("  Active: %s", status.state and "Yes" or "No"))
        print(string.format("  Temperature: %.1f°C", status.temperature or 0))
        print(string.format("  Power Output: %.0f RF/t", status.throughput or 0))
        print(string.format("  Control Rod: %d%%", status.custom.control_rod_level or 0))
        print(string.format("  Fuel: %.1f / %.1f", status.custom.fuel_amount or 0, status.custom.fuel_capacity or 0))
      end
    else
      print("BR: No reactor found")
    end
  else
    print("BR Reactor commands:")
    print("  br reactor calibrate    Calibrate reactor efficiency")
    print("  br reactor status       Show reactor status")
  end
end

local function turbineCommands(subcmd)
  if subcmd == "calibrate" then
    print("BR: Calibrating turbines...")
    local BR_Turbine = require("lib.nodes.energy_generation.BR_Turbine")
    if BR_Turbine.init() then
      BR_Turbine.calibrate()
      print("BR: Turbine calibration complete")
    else
      print("BR: No turbine found")
    end
  elseif subcmd == "status" then
    local BR_Turbine = require("lib.nodes.energy_generation.BR_Turbine")
    if BR_Turbine.init() then
      local status = BR_Turbine.getStatus()
      if status then
        print("Turbine Status:")
        print(string.format("  Active: %s", status.state and "Yes" or "No"))
        print(string.format("  Rotor Speed: %.1f RPM", status.custom.rotor_speed or 0))
        print(string.format("  Power Output: %.0f RF/t", status.throughput or 0))
        print(string.format("  Fluid: %.1f / %.1f mB", status.custom.fluid_amount or 0, status.custom.fluid_capacity or 0))
        print(string.format("  Efficiency: %.1f%%", status.efficiency * 100 or 0))
      end
    else
      print("BR: No turbine found")
    end
  elseif subcmd == "maintenance" then
    local BR_Turbine = require("lib.nodes.energy_generation.BR_Turbine")
    if BR_Turbine.init() then
      local maint = BR_Turbine.checkMaintenance()
      print("Turbine Maintenance Check:")
      print(string.format("  Needs Maintenance: %s", maint.needs_maintenance and "Yes" or "No"))
      if maint.issues then
        print("  Issues: " .. table.concat(maint.issues, ", "))
      end
      print(string.format("  Rotor Speed: %.1f RPM", maint.rotor_speed or 0))
      print(string.format("  Fluid Level: %.1f%%", maint.fluid_percentage * 100 or 0))
      print(string.format("  Shaft Damage: %.1f%%", maint.shaft_damage or 0))
    else
      print("BR: No turbine found")
    end
  else
    print("BR Turbine commands:")
    print("  br turbine calibrate    Calibrate turbine performance")
    print("  br turbine status       Show turbine status")
    print("  br turbine maintenance  Check turbine maintenance status")
  end
end

-- Main command processing
local command = args[1]

if not command then
  printUsage()
elseif command == "start" then
  startGridControl()
elseif command == "calibrate" then
  manualCalibrate()
elseif command == "status" then
  showStatus()
elseif command == "scram" then
  emergencyShutdown()
elseif command == "reactor" then
  reactorCommands(args[2])
elseif command == "turbine" then
  turbineCommands(args[2])
elseif command == "help" or command == "-h" or command == "--help" then
  printUsage()
else
  print("Unknown command: " .. command)
  printUsage()
end