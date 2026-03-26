-- OC_BaseOS Quick Start Guide

## What is OC_BaseOS?

OC_BaseOS is a **distributed SCADA controller** for OpenComputers that manages multiple industrial 
devices (reactors, energy storage, item storage) across a network of computers. It features:

- **Automatic device detection** and monitoring
- **Real-time alerts** for critical conditions
- **Safe delta updates** with SHA1 validation
- **Distributed task execution** across node network
- **Dynamic auto-scaling** of monitoring duties
- **Touchscreen HMI dashboard** for visualization
- **Persistent node registry** with staleness tracking

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                  ORCHESTRATOR NODE                      │
│  - GitHub sync & manifest caching                       │
│  - Version management & delta serving                   │
│  - Dynamic task assignment & auto-scaling               │
│  - Central node registry                                │
└─────────────────────────────────────────────────────────┘
              │              │              │
         ┌────┘              │              └────┐
         │                   │                   │
    ┌────▼───────┐     ┌─────▼──────┐    ┌───────▼────┐
    │  MONITOR   │     │  DATABASE  │    │    HMI     │
    │   NODES    │     │   EXPORTER │    │ DASHBOARD  │
    ├────────────┤     ├────────────┤    ├────────────┤
    │ Reactor    │     │ InfluxDB   │    │ Touchscreen│
    │ Storage    │     │ Grafana    │    │ Multi-view │
    │ AE2        │     │ Timeseries │    │ Alerts     │
    └────────────┘     └────────────┘    └────────────┘
```

## Key Components

### 1. Node-Side Updater (`/lib/updater.lua`)
Safely manages software updates with delta detection and rollback:
```lua
local updater = require("updater")
updater.checkForUpdates(currentVersion, newVersion)
updater.getDelta(manifest)  -- Only changed files
updater.applyUpdate(manifest, newVersion)
```

### 2. Hardware Abstraction Layer (`/lib/hardware/`)
Normalized interface for all device types:
```lua
local device = require("hardware.br_reactor").new(address)
local status = device:getStatus()  -- Returns standardized format
-- {type, state, temperature, energy_stored, energy_capacity, efficiency, ...}
```

### 3. Task Modules (`/nodes/tasks/`)
Automated monitoring of devices:
- `reactor_monitor.lua` - Reactor temperature, fuel, output
- `storage_monitor.lua` - Energy storage levels and rates
- `ae2_monitor.lua` - AE2 network CPUs, channels, storage

### 4. Database System (`/lib/database.lua`)
Persistent node registry with queries:
```lua
local db = require("database")
db.load()
db.registerNode(node_id, type, tasks, version, hashes)
db.getOnlineNodes()  -- Get all responsive nodes
db.getStats()        -- {total, online, stale, offline}
```

### 5. Alert System (`/lib/alerts.lua`)
Threshold-based alerts with severity levels:
```lua
local alerts = require("alerts")
alerts.checkDeviceStatus(device_id, type, status)
alerts.broadcast(1235)  -- Send to HMI
```

### 6. Supervisor (`/lib/nodes/supervisor/Core.lua`)
Node runtime manager with error handling:
- Graceful config loading with fallback defaults
- Task module loading and error recovery
- Periodic heartbeat and status broadcasts
- Integration with database and alert system

### 7. Orchestrator (`/lib/nodes/orchestrator.lua`)
Central management node:
- GitHub polling for new versions
- Manifest & file caching
- Delta file serving to nodes
- Dynamic task assignment
- Auto-scaling based on node availability

### 8. HMI Dashboard (`/lib/nodes/hmi/dashboard.lua`)
Touchscreen visualization:
- Overview: node count, health, recent alerts
- Nodes: all nodes with version/status
- Devices: real-time energy/temperature/capacity
- Alerts: critical and warning alerts

## Quick Start

### Step 1: Set up Directories
```lua
local init = require("init")
init.createDirectoryStructure()
```

### Step 2: Deploy Orchestrator Node
Create a computer with modem and internet card, then:
```lua
-- /nodes/config/orchestrator.cfg
return {
  node_id = "orchestrator",
  node_type = "orchestrator",
  github_base = "https://raw.githubusercontent.com/Daminer5/OC_BaseOS/refs/heads/",
  branch = "dev",  -- switch to main for stable deployment
  sync_interval = 300,
  channel = 1234
}
```
Run: `SERVICE_NAME=orchestrator /lib/nodes/orchestrator.lua`

### Step 3: Deploy Monitor Node
Create a computer with modem and reactor (or storage/AE2), then:
```lua
-- /nodes/config/reactor_1.cfg
return {
  node_id = "reactor_1",
  node_type = "reactor",
  tasks = {"reactor_monitor"},
  version = "1.0.0",
  orchestrator_channel = 1234,
  heartbeat_interval = 30,
  status_broadcast_interval = 5
}
```
Run: `SERVICE_NAME=reactor_1 /lib/nodes/supervisor/Core.lua`

### Step 4: Deploy HMI Node
Create a computer with modem, GPU, screen, and keyboard:
```lua
-- /nodes/config/hmi_1.cfg
return {
  node_id = "hmi_1",
  node_type = "hmi",
  tasks = {"dashboard"},
  version = "1.0.0",
  orchestrator_channel = 1234
}
```
Run: `SERVICE_NAME=hmi_1 /lib/nodes/supervisor/Core.lua`

## Configuration

### Node Config Structure
Each node needs `/nodes/config/{SERVICE_NAME}.cfg`:

```lua
return {
  -- Identity
  node_id = "reactor_1",           -- Unique node identifier
  node_type = "reactor",           -- reactor, storage, hmi, db, etc
  
  -- Tasks
  tasks = {"reactor_monitor"},     -- List of tasks to run
  
  -- Versioning
  version = "1.0.0",              -- Current version
  include_updater = true,         -- Auto-update files
  
  -- Networking
  orchestrator_channel = 1234,    -- Main control channel
  status_broadcast_interval = 5,  -- Seconds between status broadcasts
  heartbeat_interval = 30,        -- Seconds between heartbeats
  
  -- Update tracking
  file_hashes = {}                -- SHA1 hashes for delta detection
}
```

### Device Thresholds
Customize alert thresholds in `/lib/alerts.lua`:

```lua
M.THRESHOLDS = {
  br_reactor = {
    temp_critical = 1200,    -- Celsius (in game)
    temp_warning = 1000,
    fuel_low = 0.1           -- 10% capacity
  },
  mek_energy = {
    capacity_critical = 0.05, -- 5% full
    capacity_warning = 0.2    -- 20% full
  },
  -- ... one entry per device type
}
```

## Monitoring

### View Node Status
```lua
local db = require("database")
db.load()
local stats = db.getStats()
print(string.format("Online: %d/%d, Stale: %d", stats.online, stats.total, stats.stale))
```

### View Alerts
```lua
local alerts = require("alerts")
local critical = alerts.getCriticalAlerts()
for _, alert in ipairs(critical) do
  print(alert.device_id .. ": " .. alert.message)
end
```

### View Device Status
```lua
local devices = {}  -- Populated by tasks broadcasting status
-- Check modem message history on orchestrator channel 1234
```

## Networking

### Message Types

**Channel 1234** (orchestrator_channel):
- `register` - Node announces itself
- `heartbeat` - Keep-alive with version
- `node_status` - Periodic status broadcast
- `reactor_status` - Reactor monitoring data
- `storage_status` - Energy storage data
- `ae2_status` - AE2 network data
- `version_announce` - Orchestrator broadcasts current version
- `delta_request` - Request changed files
- `delta_response` - File data from orchestrator
- `manifest_request` - Request file list
- `manifest_response` - File manifest

**Channel 1235** (hmi_channel):
- `alerts` - Alert system broadcasts

## Extending the System

### Add New Device Type
1. Create `/lib/hardware/{device_name}.lua` wrapper
2. Implement: `new(address)`, `getStatus()`, `setActive()`
3. Update task module to detect device
4. Add thresholds to `/lib/alerts.lua`

### Add New Task
1. Create `/nodes/tasks/{task_name}.lua`
2. Implement: `run(cfg)` function that polls devices
3. Broadcast status via modem
4. Add to config: `tasks = {"task_name"}`

### Custom Auto-Scaling
Modify `assignTasks()` in `/lib/nodes/orchestrator.lua` to:
- Define task priority rules
- Set node affinity rules
- Implement load balancing

## Troubleshooting

### Node Not Connecting
- Check modem is open on channel 1234
- Verify network distance (signal loss)
- Check config file exists: `/nodes/config/{SERVICE_NAME}.cfg`
- Verify SERVICE_NAME environment variable set

### Tasks Not Running
- Check task file exists: `/nodes/tasks/{task_name}.lua`
- Verify task exports `{run = function(cfg)...end}`
- Check supervisor console for load errors
- Task modules must be on same computer as devices

### Devices Not Detected
- Verify component attached to computer
- Check component type name in task module
- Use `M.detectDevices()` to list available components

### Updates Not Applying
- Verify GitHub URL in config is correct
- Check `/cache` directory writable
- Verify manifest.lua has correct SHA1 hashes
- Check updater logs in `/tmp`

## Performance Tips

1. **Reduce broadcast frequency** if network congested
2. **Adjust monitor intervals** per task type
3. **Stale timeout** of 60s may be too short for slow networks
4. **Alert consolidation** to prevent spam
5. **Local caching** of device status on monitor nodes

## Security Considerations

- Modem broadcasts visible to all nodes (no authentication)
- Update server URL stored in plaintext config
- Use VPN/firewall for network isolation if needed
- Keep GitHub repo private for proprietary setups
- Monitor orchestrator logs for unauthorized nodes

## Resources

- Implementation Guide: `IMPLEMENTATION_GUIDE.lua`
- API Reference: Consult `/lib/*.lua` source files
- Examples: Config examples in `/nodes/config/`
- Testing: Use `local init = require("init"); init.runFullTest()`

---

**Version**: 1.0.0  
**Target**: OpenComputers 1.7.10  
**License**: Check LICENSE file
