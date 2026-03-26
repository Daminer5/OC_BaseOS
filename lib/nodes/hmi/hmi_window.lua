-- HMI debug window script
-- Use this to test HMI output in a local Lua console window.

local sleep
if package.loaded.socket then
  sleep = function(s) require("socket").sleep(s) end
else
  sleep = function(s)
    if package.config:sub(1,1) == "\\" then
      os.execute("timeout /t " .. tonumber(s) .. " /nobreak >nul")
    else
      os.execute("sleep " .. tonumber(s))
    end
  end
end

local function clearScreen()
  if package.config:sub(1,1) == "\\" then
    os.execute("cls")
  else
    os.execute("clear")
  end
end

local function drawBorder(width, height)
  local line = string.rep("=", width)
  print(line)
  for i = 1, height-2 do
    print("|" .. string.rep(" ", width-2) .. "|")
  end
  print(line)
end

local function actionForNode(node)
  local status = node.status or "offline"
  local color = "[OFFLINE]"
  if status == "online" then color = "[ONLINE]" end
  if status == "stale" then color = "[STALE]" end
  return string.format("%s %-12s v%-7s %s", color, node.node_id, node.version or "n/a", table.concat(node.tasks or {"none"}, ","))
end

local function getNodeList()
  local db
  local ok
  ok, db = pcall(require, "database")
  if ok and db then
    pcall(db.load)
    return db.getAllNodes() or {}
  end

  -- fallback mocked nodes when database module is unavailable
  return {
    {node_id="reactor_1", node_type="reactor", status="online", version="1.0.0", tasks={"reactor_monitor"}},
    {node_id="storage_1", node_type="storage", status="online", version="1.0.1", tasks={"storage_monitor"}},
    {node_id="ae2_1", node_type="ae2", status="stale", version="1.0.0", tasks={"ae2_monitor"}}
  }
end

local function drawHMIScreen(iteration)
  clearScreen()
  local width = 90
  local height = 18

  print(string.format("OC_BaseOS HMI DEBUG WINDOW (iteration %d)", iteration))
  print(string.rep("=", width))
  print(string.format("%-20s | %-8s | %-8s | %-16s | %s", "NODE", "TYPE", "STATUS", "VERSION", "TASKS"))
  print(string.rep("-", width))

  local nodes = getNodeList()
  for _, node in ipairs(nodes) do
    local status = node.status or "offline"
    local line = string.format("%-20s | %-8s | %-8s | %-16s | %s", node.node_id or "?", node.node_type or "?", status, node.version or "?", table.concat(node.tasks or {}, ","))
    print(line)
  end

  print(string.rep("=", width))
  print("Press Ctrl+C to stop. Refreshes every 2 seconds.")
end

local function run()
  local iteration = 0
  while true do
    iteration = iteration + 1
    drawHMIScreen(iteration)
    sleep(2)
  end
end

return {run = run}
