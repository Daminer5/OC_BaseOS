-- BR Controller Task
-- Runs Big Reactors auto-calibration in OC_BaseOS node task framework

local BR_GridControl = require("grid_control")
local computer = require("computer")

local task = {}

local state = {
  grid = nil,
  last_run = 0,
  run_interval = 600,  -- 10 minutes
  warmup_time = 10,
  initialized = false
}

local function init()
  if state.initialized then return true end

  state.grid = BR_GridControl.new()
  local found = state.grid:discoverHardware()
  if not found then
    print("BR Controller: No Big Reactor hardware detected")
    return false
  end

  state.initialized = true
  state.last_run = computer.uptime() - state.run_interval
  print("BR Controller: Initialized with hardware discovered")
  return true
end

local function step()
  if not init() then
    return
  end

  local now = computer.uptime()
  -- periodic full optimization
  if now - state.last_run >= state.run_interval then
    state.grid:optimizeGrid()
    state.last_run = now
  end

  -- continuous local monitoring and safety checks
  state.grid:checkSafety()
  state.grid:balancePowerFlow()

  -- possibly publish status to orchestrator by sending local status event
  local status = state.grid:getStatus()
  if status then
    local component = require("component")
    local serialization = require("serialization")
    local modem = component.modem
    if not modem.isOpen(1234) then modem.open(1234) end
    modem.broadcast(1234, serialization.serialize({
      type = "br_status",
      timestamp = os.time(),
      status = status
    }))
  end
end

function task.run(cfg)
  if cfg and cfg.br then
    if cfg.br.run_interval then state.run_interval = cfg.br.run_interval end
    if cfg.br.warmup_time then state.warmup_time = cfg.br.warmup_time end
  end

  if not init() then
    return
  end

  -- Wait warmup after first init if configured
  if computer.uptime() - state.last_run < state.warmup_time then
    return
  end

  step()
end

return task