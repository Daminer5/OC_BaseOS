-- Boot Service Kickstarter
-- Auto-starts node services at system boot
-- Runs as part of the boot sequence

local component = require("component")
local filesystem = require("filesystem")
local computer = require("computer")

local nodeTypeFile = "/etc/node_type"
local started = false

-- Try to load saved node type
local function getSavedNodeType()
  if filesystem.exists(nodeTypeFile) then
    local f = io.open(nodeTypeFile, "r")
    if f then
      local nodeType = f:read("*line"):gsub("^%s+|%s+$", "")
      f:close()
      if nodeType and nodeType ~= "" then
        return nodeType
      end
    end
  end
  return nil
end

-- Register to run at init time
require("event").listen("init", function()
  if started then return false end
  started = true
  
  local nodeType = getSavedNodeType()
  
  if nodeType then
    -- Use saved node type
    local shell = require("shell")
    shell.execute("kickstart.lua " .. nodeType)
  else
    -- No saved type, will be set on next explicit call or installation
    -- This is normal for fresh boots
  end
  
  return false
end)
