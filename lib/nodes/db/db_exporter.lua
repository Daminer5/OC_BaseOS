local http = require("component").internet
local serialization = require("serialization")
local cfg = require("config_exporter")
local computer = require("computer")

-- load dynamic DB (or orchestrator registry file)
local function loadNodes()
  local f = io.open("/cache/node_registry.lua", "r")
  if not f then return {} end
  local data = f:read("*a")
  f:close()
  local chunk, err = load(data)
  if not chunk then
    return {}
  end
  local ok, tbl = pcall(chunk)
  if ok and type(tbl) == "table" then
    return tbl
  end
  return {}
end

local function postToInflux(payload)
  local handle = http.request(cfg.influx_url, payload, {["Content-Type"]="text/plain"})
  if handle then for _ in handle do end end
end

local function formatNode(node_id, node)
  local up_to_date = node.version == node.latest_version and 1 or 0
  local stale = (os.time() - (node.last_seen or 0)) > 60 and 1 or 0
  local correct_files, total_files = 0, 0
  for f,h in pairs(node.file_hashes or {}) do
    total_files = total_files + 1
    if h == (node.manifest_hashes or {})[f] then correct_files = correct_files + 1 end
  end

  return table.concat({
    string.format("node_status,node=%s version=\"%s\",up_to_date=%d,stale=%d,uptime=%d",
      node_id, node.version or "unknown", up_to_date, stale, node.uptime or 0),
    string.format("node_files,node=%s total=%d,correct=%d", node_id, total_files, correct_files)
  }, "\n")
end

while true do
  local nodes = loadNodes()
  local payload = {}
  for node_id, node in pairs(nodes) do
    table.insert(payload, formatNode(node_id, node))
  end
  if #payload > 0 then postToInflux(table.concat(payload,"\n")) end
  os.sleep(cfg.export_interval)
end