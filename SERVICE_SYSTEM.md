# Service Kickstarter System Documentation

## Overview

The Service Kickstarter is a comprehensive service management system that automatically initializes and starts all necessary node services at boot time or after installation. It provides automatic hardware detection, node type identification, and service dependency management.

## Architecture

### Components

1. **kickstart.lua** - Main service initialization engine
   - Hardware detection
   - Node type identification and persistence
   - Service startup orchestration
   - Service priority management

2. **svc.lua** - Service management utility
   - Start/stop/restart individual services
   - Service status monitoring
   - List available services
   - Bulk service operations

3. **Service Control Scripts** (/etc/rc.d/)
   - `services.lua` - Main service orchestration
   - `hmi.lua` - HMI node services
   - `supervisor.lua` - Supervisor/orchestrator services
   - `breactor.lua` - Big Reactor services
   - `mekanism.lua` - Mekanism Reactor services
   - `ae2.lua` - AE2 Storage services
   - `exporter.lua` - Exporter services
   - `worker.lua` - Worker services

4. **Boot Integration** (/boot/95_services.lua)
   - Registers service startup at boot time
   - Uses saved node type configuration
   - Integrates with system boot sequence

## Service Architecture

### Service Types

Each service has the following properties:

```lua
{
  name = "Human Readable Name",
  priority = 1-10,              -- Startup priority (lower = earlier)
  check = function()             -- Pre-flight check
    return boolean
  end,
  init = function(config)        -- Initialization
    return boolean
  end,
  cleanup = function()           -- Cleanup on shutdown
  end
}
```

### Service Priority Levels

Services start in priority order:

1. **Priority 1-2**: Core infrastructure
   - Modem (network access)
   - Monitor/Display

2. **Priority 3-4**: Central services
   - Database
   - Alert system

3. **Priority 5-9**: Hardware and feature services
   - Reactor controllers
   - Storage monitors
   - Specialized services

4. **Priority 10**: User-facing services
   - HMI interface
   - Orchestrator

## Node Types

### HMI (Human Machine Interface)
- **Files**: `/lib/nodes/hmi.lua`, config `/lib/nodes/config/hmi.lua`
- **Services**: modem, monitor, hmi
- **Hardware**: GPU + Screen
- **Purpose**: Primary UI for system monitoring

### Supervisor/Orchestrator
- **Files**: Various supervisor components
- **Services**: modem, database, alerts, orchestrator
- **Purpose**: Central orchestration and coordination

### BR Reactor
- **Files**: `/lib/hardware/br_reactor.lua`
- **Services**: modem, reactor, monitor
- **Hardware**: Big Reactor component
- **Purpose**: Big Reactor control and monitoring

### Mekanism Reactor
- **Files**: `/lib/hardware/mekanism_*.lua`
- **Services**: modem, mekanism, monitor
- **Hardware**: Mekanism reactor components
- **Purpose**: Mekanism reactor control

### AE2 Storage
- **Files**: `/lib/hardware/ae2_monitor.lua`
- **Services**: modem, ae_monitor
- **Hardware**: Applied Energistics 2 system
- **Purpose**: AE2 network monitoring

### Exporter
- **Files**: `/lib/nodes/exporter.lua`
- **Services**: modem, exporter, monitor
- **Purpose**: Automated item/fluid export

### Worker
- **Files**: Configuration only
- **Services**: modem, worker
- **Purpose**: Generic distributed worker tasks

### Generic
- **Files**: Configuration only
- **Services**: modem
- **Purpose**: Fallback for unknown hardware

## Usage

### Post-Installation Startup

The kickstarter runs automatically after installation:

```bash
# During installation, will start services automatically
lua install.lua

# Or manually trigger with specific node type
kickstart.lua hmi
kickstart.lua supervisor
kickstart.lua br_reactor
```

### Boot-Time Startup

Services start automatically at boot if node type is saved:

```
1. System boots
2. Boot sequence runs (90_filesystem, 91_gpu, etc.)
3. 95_services.lua registers boot handler
4. At init event, kickstart.lua runs with saved node type
5. All services start based on node configuration
```

### Manual Service Management

Use `svc` utility to manage services:

```bash
# List all available services
svc list

# Start a service
svc start supervisor

# Stop a service
svc stop hmi

# Restart a service
svc restart breactor

# Check service status
svc status worker

# Reload all services
svc reload
```

### Service Control Scripts

Directly invoke service control:

```bash
# Interactive service management
rc services              # Start all services
rc supervisor start      # Start supervisor services
rc hmi restart           # Restart HMI services
```

## Configuration Files

### Node Type Configuration
- **Location**: `/etc/node_type`
- **Format**: Plain text (single line)
- **Content**: Node type identifier (e.g., "hmi", "supervisor")
- **Created**: During installation
- **Used**: At boot time to start appropriate services

### Node-Specific Configs
- **Location**: `/etc/<node-type>.cfg`
- **Format**: Lua table serialization
- **Created**: By individual node setup
- **Used**: By kickstarter to configure services

Example:
```
/etc/hmi.cfg
/etc/supervisor.cfg
/etc/br_reactor.cfg
/etc/mekanism_reactor.cfg
/etc/ae_storage.cfg
/etc/exporter.cfg
/etc/worker.cfg
/etc/generic.cfg
```

## Hardware Detection

The kickstarter automatically detects:

- **Modem**: Network connectivity
- **GPU + Screen**: Display capability
- **Reactor components**: Big Reactor or Mekanism reactors
- **AE2 systems**: Applied Energistics 2 ME systems
- **Storage systems**: EnderIO, Thermal, or other storage mods

### Detection Priority

Services are started in this priority order when auto-detecting:

1. GPU + Screen → HMI
2. Reactor presence → Reactor controller
3. AE2 presence → Storage monitor
4. Network only → Worker
5. Default → Generic

## Error Handling

### Essential vs Optional Services

- **Essential services**: If they fail, the node aborts startup
- **Optional services**: If they fail, startup continues with warning

Current essential services:
- Modem (network required for most nodes)
- Database (for supervisor nodes)

### Service Failure Recovery

If a service fails:

1. Check logs in `/var/logs/`
2. Verify hardware is present
3. Run `svc restart <service>`
4. Check service configuration files

## Logging

Services log to:

- **Console**: Real-time output during startup
- **Files**: `/var/logs/service.log` (if logging enabled)

Log levels:
- INFO: Standard operations
- DEBUG: Detailed diagnostic info
- WARN: Non-critical issues
- ERROR: Critical failures

## Files Modified

### New Files Created

1. `/bin/kickstart.lua` - Main kickstarter engine
2. `/bin/svc.lua` - Service management utility
3. `/boot/95_services.lua` - Boot-time service startup
4. `/etc/rc.d/services.lua` - Main service orchestration
5. `/etc/rc.d/hmi.lua` - HMI service control
6. `/etc/rc.d/supervisor.lua` - Supervisor service control
7. `/etc/rc.d/breactor.lua` - Big Reactor service control
8. `/etc/rc.d/mekanism.lua` - Mekanism service control
9. `/etc/rc.d/ae2.lua` - AE2 service control
10. `/etc/rc.d/exporter.lua` - Exporter service control
11. `/etc/rc.d/worker.lua` - Worker service control

### Modified Files

1. `/install.lua` - Added kickstarter call after installation

## Service Startup Flow

```
System Boot
    ↓
Boot Sequence (00-94_*.lua)
    ↓
95_services.lua registers event listener
    ↓
Init Event Fires
    ↓
95_services.lua loads saved node type
    ↓
Executes: kickstart.lua <node-type>
    ↓
kickstart.lua:
  1. Loads node configuration
  2. Sorts services by priority
  3. Starts services in order:
     - Check prerequisites
     - Initialize service
     - Handle failures
  4. Logs results
  ↓
Services Running
    ↓
System Ready
```

## Troubleshooting

### Services Not Starting

1. Check if node_type is saved:
   ```bash
   cat /etc/node_type
   ```

2. Run kickstarter manually:
   ```bash
   kickstart.lua
   ```

3. Check for hardware:
   ```bash
   components
   ```

4. View logs:
   ```bash
   tail -n 50 /var/logs/service.log
   ```

### Service Crashes

1. Check service status:
   ```bash
   svc status <service>
   ```

2. Restart service:
   ```bash
   svc restart <service>
   ```

3. Check hardware configuration:
   ```bash
   cat /etc/<node-type>.cfg
   ```

### Manual Service Startup

If automatic startup fails:

```bash
# Load shell
lua
local shell = require("shell")

# Run kickstarter
shell.execute("kickstart.lua hmi")

# Or run specific service
shell.execute("svc start hmi")
```

## Advanced Usage

### Custom Node Configuration

Create `/etc/custom.cfg`:

```lua
{
  display = {
    width = 160,
    height = 50,
    refresh_rate = 1,
  },
  modem = {
    port = 2000,
  },
}
```

### Service Monitoring

Check service status in Lua:

```lua
if _G.node_services_started then
  print("Services running")
else
  print("Services not running")
end
```

### Programmatic Service Control

```lua
local shell = require("shell")
local result = shell.execute("svc start hmi")
if result == 0 then
  print("Service started successfully")
end
```

## Configuration Schema

### Node Service Configuration

```lua
{
  name = "Display Name",
  essential = true/false,
  services = {
    "service1",
    "service2",
  },
  timeout = 30,
  description = "Node description",
}
```

## See Also

- [Node Architecture](NODE_GENERATION_REPORT.md)
- [Installation Guide](IMPLEMENTATION_GUIDE.lua)
- [System Boot Process](boot/README.md)
- [Service Management](bin/svc.lua)
