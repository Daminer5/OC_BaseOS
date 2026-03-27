-- DE Reactor Control and Safety
local component = require("component")
local computer = require("computer")
local modem = component.modem

local DE_Reactor = {}

-- Reactor defaults
DE_Reactor.minContainmentFloodWatts = 300000 -- 300kRF/t

function DE_Reactor.getStatus(address)
  if not component.isAvailable("de_reactor") then
    return nil, "no de_reactor component"
  end

  local reactor = component.de_reactor
  local ok, status = pcall(function()
    return {
      active = reactor.getActive(),
      energy_output = reactor.getEnergyProducedLastTick(),
      containment = reactor.getContainmentFieldEnergy(),
      fuel_amount = reactor.getFuelAmount(),
      max_fuel = reactor.getFuelAmountMax(),
      life = reactor.getLife(),
      control_redstone = reactor.getControlRodLevel(),
    }
  end)

  if not ok then return nil, "failed to query de_reactor" end
  return status
end

function DE_Reactor.setActive(state)
  if not component.isAvailable("de_reactor") then return false end
  local reactor = component.de_reactor
  local ok = pcall(function() reactor.setActive(state) end)
  return ok
end

function DE_Reactor.floodContainment(power)
  if not component.isAvailable("de_reactor") then return false end
  local reactor = component.de_reactor

  if type(power) ~= "number" then
    power = DE_Reactor.minContainmentFloodWatts
  end

  if power >= DE_Reactor.minContainmentFloodWatts then
    pcall(function() reactor.floodContainment(power) end)
    return true
  end

  return false
end

function DE_Reactor.autoScramCheck(supervisorOnline)
  if not supervisorOnline then
    -- On loss of supervisor comms
    DE_Reactor.setActive(false)
    return true
  end
  return false
end

return DE_Reactor