# OC_BaseOS

OpenComputers Base OS - A distributed SCADA controller for OpenComputers mod in Minecraft.

Repository: https://github.com/Daminer5/OC_BaseOS

## Overview

OC_BaseOS is a modular operating system designed for OpenComputers 1.7.10, functioning as a SCADA (Supervisory Control and Data Acquisition) controller. It manages sub-programs via configurations, auto-scales and auto-configures based on connected devices, and provides real-time monitoring, safe updates, and a touchscreen HMI dashboard.

The system is built in Lua and uses a layered architecture: Hardware → Device → Task → Orchestration → UI.

## Architecture

### Core Components

- **Boot System** (`/boot/`): Initializes the OS in stages (base, process, OS, I/O, components, devfs, rc, filesystem, GPU, keyboard, terminal, shell).
  - **NEW**: Service boot (`95_services.lua`) auto-starts node services based on saved configuration.
- **Binaries** (`/bin/`): Standard Unix-like utilities (ls, cd, grep, etc.) for system management.
  - **NEW**: `kickstart.lua` - Service initialization and orchestration engine.
  - **NEW**: `svc.lua` - Service management CLI utility.
- **Libraries** (`/lib/`): Core modules for filesystem, event handling, serialization, etc.
- **Nodes** (`/lib/nodes/`): Specialized components for monitoring, supervision, and UI.
  - **Updated**: All node types now have associated configuration files for auto-initialization.
- **Service Control** (`/etc/rc.d/`): Service startup scripts for each node type.
  - **NEW**: `services.lua`, `hmi.lua`, `supervisor.lua`, `breactor.lua`, `mekanism.lua`, `ae2.lua`, `exporter.lua`, `worker.lua`

### Architecture Layers

```
User Interface Layer
        ↓
Orchestration & Automation
        ↓
Service Layer (Auto-initialized)
        ↓
Task Monitoring
        ↓
Device Abstraction (HAL)
        ↓
Hardware (Components)
```

### System Initialization Flow

```
1. Boot Sequence (/boot/00-94_*.lua)
2. Service Boot Registration (95_services.lua)
3. Init Event → Load Node Type (/etc/node_type)
4. Execute Kickstarter → Start Services
5. Services Initialize (Priority-ordered)
6. System Ready (HMI/orchestration active)
```

## What's New: Service-Based Architecture

This update introduces a **Service Kickstarter System** - a comprehensive infrastructure for automatic node initialization:

### Key Features

✅ **Automatic Hardware Detection** - Identifies GPU, modem, reactors, and storage systems  
✅ **Zero-Configuration Setup** - Auto-recommends node type based on hardware  
✅ **Auto Service Startup** - Services initialize automatically at boot and after installation  
✅ **Service Management CLI** - `svc` utility for control and debugging  
✅ **Priority-Based Initialization** - Services start in optimal order  
✅ **Persistent Configuration** - Node type saved to `/etc/node_type`  
✅ **Graceful Degradation** - Optional services fail silently  
✅ **Boot Integration** - Full integration with system boot sequence  

### Benefits

- **Before**: Manual service startup, no hardware detection, no persistence
- **After**: Automatic detection → service initialization → persistent configuration → boot-time auto-start



## Subsystems

### 0. Service Kickstarter System (`/bin/kickstart.lua`)

**Purpose**: Automatically initializes and manages node services based on hardware and node type. Provides zero-configuration setup and automated service management.

**How it works**:
1. Detects installed hardware (GPU, modem, reactors, storage systems)
2. Recommends node type based on hardware
3. Loads configuration for node type
4. Initializes services in priority order
5. Handles graceful failures and timeouts
6. Registers shutdown cleanup

**Features**:
- Hardware auto-detection (GPU+Screen, Reactor, AE2, Storage, Modem)
- Node type persistence (`/etc/node_type`)
- Service priority-based startup (1-10, lower = earlier)
- Essential vs optional service distinction
- Configuration file support per node type
- Shutdown event integration

**Installation/Configuration**:
- Runs automatically during `install.lua`
- Runs automatically at boot via `/boot/95_services.lua`
- Manual trigger: `kickstart.lua [node-type]`
- Management: `svc` utility or `/etc/rc.d/` scripts

**Service Types Available**:
- Core: modem, monitor
- Storage: database
- Alerts: alerts
- Hardware: reactor, mekanism, ae_monitor
- User: hmi, orchestrator, exporter, worker

### 1. Service Management Utility (`/bin/svc.lua`)

**Purpose**: Command-line interface for service control and management.

**How it works**: Loads service scripts from `/etc/rc.d/`, executes requested commands, handles errors.

**Usage**:
```bash
svc list                    # List all services
svc start <service>        # Start service
svc stop <service>         # Stop service
svc restart <service>      # Restart service
svc status [service]       # Check status
svc reload                 # Reload all services
```

**Installation/Configuration**: Included automatically with base install.

### 2. Updater (`/lib/updater.lua`)
**Purpose**: Manages safe, delta-based software updates with SHA1 validation and rollback capabilities. Ensures system integrity during updates.

**How it works**: Downloads update manifests, verifies hashes, applies patches, and can revert if issues occur. Supports distributed updates across nodes.

**Installation/Configuration**:
- Deploy `updater.lua` to each node.
- Configure update server URL in `updater.cfg`.
- Run `updater.update()` to check and apply updates.

### 3. Hardware Abstraction Layer (HAL) (`/lib/hardware/`)
**Purpose**: Provides unified interfaces to hardware components (reactors, turbines, storage systems) from mods like Big Reactors, Mekanism, Thermal Expansion, etc.

**How it works**: `hal.lua` detects and abstracts hardware; device-specific wrappers (e.g., `br_reactor.lua`) handle mod-specific APIs.

**Installation/Configuration**:
- Ensure OpenComputers components (modem, GPU, etc.) are installed on computers.
- Place hardware wrappers in `/lib/hardware/`.
- HAL auto-detects on boot; configure device addresses in `hal.lua` if needed.

### 4. Tasks/Monitors (`/nodes/tasks/`)
**Purpose**: Background monitoring modules for specific systems (reactors, storage, AE2 networks).

**How it works**: Each task (e.g., `reactor_monitor.lua`) polls hardware, collects metrics, and reports to the database/alerts system.

**Installation/Configuration**:
- Deploy task scripts to monitor nodes.
- Configure thresholds and intervals in task configs.
- Start via orchestrator or manually with `require("nodes.tasks.reactor_monitor").start()`.

### 5. Database (`/lib/database.lua`)
**Purpose**: Centralized registry for nodes, configurations, and metrics with persistence and staleness detection.

**How it works**: Stores node info, handles queries, and cleans up stale entries. Uses filesystem for persistence.

**Installation/Configuration**:
- Deploy to central database node.
- Configure storage path in `database.lua`.
- Access via `require("database").register_node()`.

### 6. Supervisor (`/lib/nodes/supervisor/Core.lua`)
**Purpose**: Enhanced runtime supervisor for process management, error handling, and system health.

**How it works**: Monitors processes, restarts failed ones, and provides system diagnostics.

**Installation/Configuration**:
- Deploy to supervisor nodes.
- Configure process lists in `Core.lua`.
- Start with `supervisor.start()`.

### 7. Alerts (`/lib/alerts.lua`)
**Purpose**: Threshold-based alert system with severity levels for proactive monitoring.

**How it works**: Checks metrics against thresholds, triggers alerts (logs, notifications), and escalates based on severity.

**Installation/Configuration**:
- Deploy to alert nodes.
- Define thresholds in `alerts.lua` or config files.
- Integrate with tasks via `alerts.check_threshold()`.

### 8. HMI (Human-Machine Interface) (`/lib/nodes/hmi/`)
**Purpose**: Touchscreen dashboard for real-time visualization and control.

**How it works**: `dashboard.lua` renders multi-view UI; `widgets.lua` provides components; `hmi_window.lua` offers console debug mode.

**Installation/Configuration**:
- Deploy to HMI nodes with GPU and touchscreen.
- Configure views in `dashboard.lua`.
- For debugging, use `hmi_window.lua` in VS Code.

### 9. Orchestrator (`/lib/nodes/orchestrator.lua`)
**Purpose**: Auto-scaling and configuration management for distributed systems.

**How it works**: Detects devices, assigns tasks, balances load, and manages node lifecycles.

**Installation/Configuration**:
- Deploy to orchestrator node.
- Configure auto-scaling rules in `orchestrator.lua`.
- Start with `orchestrator.run()`.

## Node Types & Services

OC_BaseOS supports 8 specialized node types, each with tailored services and configurations:

### Node Types

| Type                 | Hardware          | Purpose                              | Services                              |
|----------------------|-------------------|--------------------------------------|---------------------------------------|
| **hmi**              | GPU + Touchscreen | Human-Machine Interface dashboard    | modem, monitor, hmi                   |
| **supervisor**       | Any               | Central orchestration & coordination | modem, database, alerts, orchestrator |
| **br_reactor**       | Big Reactor       | Reactor control & monitoring         | modem, reactor, monitor               |
| **mekanism_reactor** | Mekanism Reactor  | Mekanism reactor control             | modem, mekanism, monitor              |
| **ae_storage**       | AE2 ME System     | Storage monitoring & inventory       | modem, ae_monitor                     |
| **exporter**         | Any               | InfluxDB exporter                    | modem, exporter, monitor              |
| **worker**           | Modem             | Distributed task execution           | modem, worker                         |
| **generic**          | Any               | Fallback/generic configuration       | modem                                 |

### Service System

Each node type has a set of required services that auto-initialize:

- **modem**: Network communication (~1-2s)
- **monitor**: Display/GPU setup (~0.5s)
- **database**: Central metric storage (~2-3s)
- **alerts**: Alert system initialization (~1s)
- **reactor**: Hardware control interfaces (~1-2s per reactor)
- **hmi**: User dashboard interface (~2-3s)
- **orchestrator**: System coordination (~2s)

Services start in **priority order** (lower = first) for optimal initialization time.

## Service Kickstarter System

The Service Kickstarter automatically initializes and starts all required services based on your node type. This runs:
- **After installation** (detects hardware → starts services)
- **At system boot** (uses saved node type → auto-starts services)
- **On manual request** (via `svc` utility or `kickstart.lua`)

### Automatic Node Detection

The system auto-detects hardware and recommends a node type:

1. **GPU + Screen** → HMI (user interface node)
2. **Reactor present** → br_reactor or mekanism_reactor
3. **AE2 present** → ae_storage
4. **Modem only** → worker
5. **Default** → generic

### Service Management

Use the `svc` utility to manage services:

```bash
# List all available services
svc list

# Start/stop/restart a service
svc start supervisor
svc stop hmi
svc restart breactor

# Check service status
svc status worker

# Reload all services
svc reload
```

Or directly run kickstarter:

```bash
# Auto-detect and start
kickstart.lua

# Start specific node type
kickstart.lua hmi
kickstart.lua supervisor
kickstart.lua br_reactor
```

## Installation

1. **Prerequisites**:
   - Minecraft with OpenComputers 1.7.10 mod.
   - Computers with required components (modem for networking, GPU/screen for HMI).

2. **Deploy Code**:
   - Run the installer: `lua install.lua` or `lua install.lua <branch> <path>`
   - Optionally specify: `lua install.lua dev /` (branch and install path)
   - The installer will:
     - Download manifest from GitHub
     - Detect your hardware
     - Recommend a node type (confirm or override)
     - Download node-specific files
     - Save your node type to `/etc/node_type`
     - **Automatically start services**

3. **Boot** (Automatic):
   - OS initializes via `/boot/` scripts
   - Service system loads saved node type from `/etc/node_type`
   - All required services auto-start based on your node type
   - System ready for operation within seconds

4. **Configuration**:
   - Edit config files: `/etc/<node-type>.cfg`
   - View/change node type: `cat /etc/node_type` or `edit /etc/node_type`
   - Restart services after config changes: `svc reload` or `kickstart.lua`

## Usage

### Post-Installation

After running `install.lua`:

1. **Services Started**: All services for your node type automatically initialize
2. **Node Type Saved**: Configuration saved to `/etc/node_type` for future boots
3. **System Ready**: All hardware interfaces initialized and ready
4. **Check Status**: View running services with `svc status`

### Quick Start Examples

**HMI Node** (User Interface):
```bash
# Automatically configured for GPU+Screen systems
# Dashboard displays all system metrics
# Services: modem, monitor, hmi

# Check status
svc status hmi

# Restart if needed
svc restart hmi
```

**Supervisor Node** (Central Orchestration):
```bash
# Central coordination point for entire system
# Services: modem, database, alerts, orchestrator

svc start supervisor
svc status supervisor
```

**Reactor Node** (Big Reactor):
```bash
# Controls and monitors Big Reactor installations
# Services: modem, reactor, monitor

svc start breactor

# View system logs for reactor status
tail -n 20 /var/logs/service.log
```

**Worker Node** (Distributed Tasks):
```bash
# Distributed task execution
# Services: modem, worker
# Registers with orchestrator for task assignment

svc start worker
```

### Monitoring

**View Active Services**:
```bash
svc list              # Show all available services
svc status            # Check all service status
svc status hmi        # Check specific service
```

**Service Logs**:
```bash
# Real-time startup output
kickstart.lua

# Historical logs (if configured)
cat /var/logs/service.log
tail -f /var/logs/service.log  # Follow logs
```

**Check Node Configuration**:
```bash
# View current node type
cat /etc/node_type

# Edit if needed
edit /etc/node_type

# Apply changes
kickstart.lua
```

### Service Management

**Restart Services**:
```bash
# Individual service
svc restart supervisor

# All services
svc reload

# All services + new node type
kickstart.lua <new-type>
```

**Manual Service Control**:
```bash
# Start via rc system
rc services

# Stop services (graceful shutdown)
svc stop supervisor

# Individual service control
rc hmi start
rc hmi stop
rc hmi restart
```

### Control & Automation

- **HMI**: Use touchscreen dashboard for real-time monitoring and manual control
- **Orchestrator**: Automatically manages node lifecycle and load balancing
- **Monitors**: Tasks collect metrics and report to database
- **Alerts**: Threshold-based notifications for critical events
- **Exporter**: Automated item/fluid movement between systems

## Boot Process

The system boots in stages:

```
1. Firmware loads (/boot/00_base.lua - 94_*.lua)
   ├─ Core libraries (process, OS, I/O, components)
   ├─ Device filesystem (/dev)
   ├─ Real filesystem
   ├─ GPU/display
   ├─ Keyboard
   └─ Terminal & Shell

2. Service Boot (/boot/95_services.lua) - NEW
   ├─ Register boot event handler
   └─ Wait for init event

3. Init Event Fires
   ├─ Load saved node type from /etc/node_type
   ├─ Execute kickstart.lua with node type
   └─ Services initialize in priority order

4. Shell Ready
   ├─ User can interact with system
   └─ Services running in background
```

At any point, services can be restarted or modified via the `svc` utility.

## Configuration Files

### Node Type Definition
- **File**: `/etc/node_type`
- **Content**: Single line with node type name (e.g., "hmi", "supervisor")
- **Created**: During installation
- **Used**: At boot time to determine which services to start

### Node-Specific Configuration
- **Location**: `/etc/<node-type>.cfg`
- **Format**: Lua configuration
- **Examples**:
  - `/etc/hmi.cfg` - HMI dashboard settings
  - `/etc/supervisor.cfg` - Orchestrator settings
  - `/etc/br_reactor.cfg` - Big Reactor parameters
  - `/etc/mekanism_reactor.cfg` - Mekanism settings
  - `/etc/ae_storage.cfg` - AE2 storage config

### Updater Configuration
- **File**: `/lib/updater.cfg`
- **Options**:
  - `branch`: Git branch (dev, main, stable)
  - `repo`: GitHub repository URL

## Debugging

### Service Startup Issues

**View Service Startup Log**:
```lua
kickstart.lua              -- Run manually to see detailed output
svc status all            -- Check if services loaded
svc list                  -- List available services
```

**Debug Specific Service**:
```bash
svc start hmi --debug
svc restart supervisor
tail -n 100 /var/logs/service.log
```

**Check Hardware**:
```bash
# List all components
components

# Check specific component
components | grep GPU
components | grep Reactor
```

### Manual Service Initialization

If automatic startup fails:

```lua
-- Load kickstarter manually
local kickstart = require("kickstart")

-- Start specific node type
kickstart.lua hmi

-- Or start specific service
local shell = require("shell")
shell.execute("svc start supervisor")
```

### In-Game Debugging

- Local: Use "Debug HMI (window)" in VS Code for console output
- In-Game: Export install; check logs via `cat /var/logs/system.log`
- Services: Check status with `svc status`
- Processes: View running processes with `ps`

### Check System Health

```bash
# View node type
cat /etc/node_type

# Check available services
svc list

# Monitor resource usage
free                      # Memory
df                        # Disk
ps                        # Processes

# View alerts
cat /var/logs/alerts.log

# Network status (if applicable)
# Check modem with component API
```

## System Files & Structure

### New Files Created (Service Kickstarter System)

**Core Service Engine**:
- `/bin/kickstart.lua` - Main service initialization and orchestration engine (330+ lines)
- `/bin/svc.lua` - Service management CLI utility (180+ lines)
- `/boot/95_services.lua` - Boot-time service startup integration

**Service Control Scripts** (`/etc/rc.d/`):
- `services.lua` - Main service orchestration script
- `hmi.lua` - HMI node service controller
- `supervisor.lua` - Supervisor/orchestrator service controller
- `breactor.lua` - Big Reactor service controller
- `mekanism.lua` - Mekanism Reactor service controller
- `ae2.lua` - AE2 Storage service controller
- `exporter.lua` - Exporter service controller
- `worker.lua` - Worker node service controller

**Node Configuration Files** (`/lib/nodes/config/`):
- `hmi.lua` - HMI node configuration
- `orchestrator.lua` - Orchestrator configuration
- `database.lua` - Database configuration
- `alerts.lua` - Alerts system configuration
- `br_reactor.lua` - Big Reactor configuration
- `mekanism_reactor.lua` - Mekanism configuration
- `ae_storage.lua` - AE2 storage configuration
- `exporter.lua` - Exporter configuration
- `worker.lua` - Worker configuration
- `generic.lua` - Generic node configuration

**Node Implementation Files** (`/lib/nodes/`):
- `hmi.lua` - HMI node implementation
- `exporter.lua` - Exporter node implementation

**Documentation**:
- `SERVICE_SYSTEM.md` - Comprehensive service system documentation
- `SERVICE_QUICK_REFERENCE.md` - Quick reference guide
- `NODE_GENERATION_REPORT.md` - Node architecture report

### Modified Files

**System Installation**:
- `/install.lua` - Updated to call kickstarter after installation and save node type

**Boot Sequence**:
- `/boot/95_services.lua` - Added boot-time service startup hook

### File Organization

```
Root
├── /bin/
│   ├── kickstart.lua          (NEW) - Service engine
│   ├── svc.lua                (NEW) - Service CLI
│   ├── ... (standard Unix utilities)
│
├── /boot/
│   ├── 00_base.lua through 94_*.lua
│   └── 95_services.lua        (NEW) - Service boot hook
│
├── /etc/
│   ├── rc.d/
│   │   ├── services.lua       (NEW)
│   │   ├── hmi.lua            (NEW)
│   │   ├── supervisor.lua     (NEW)
│   │   ├── breactor.lua       (NEW)
│   │   ├── mekanism.lua       (NEW)
│   │   ├── ae2.lua            (NEW)
│   │   ├── exporter.lua       (NEW)
│   │   ├── worker.lua         (NEW)
│   │   └── example.lua        (existing)
│   ├── node_type              (NEW - created at install)
│   └── ... (config files)
│
├── /lib/
│   ├── nodes/
│   │   ├── hmi.lua            (NEW)
│   │   ├── exporter.lua       (NEW)
│   │   ├── orchestrator.lua   (existing)
│   │   └── config/
│   │       ├── hmi.lua        (NEW)
│   │       ├── orchestrator.lua (NEW)
│   │       ├── database.lua   (NEW)
│   │       ├── alerts.lua     (NEW)
│   │       ├── br_reactor.lua (NEW)
│   │       ├── mekanism_reactor.lua (NEW)
│   │       ├── ae_storage.lua (NEW)
│   │       ├── exporter.lua   (NEW)
│   │       ├── worker.lua     (NEW)
│   │       └── generic.lua    (NEW)
│   ├── hardware/ (existing hardware modules)
│   └── ... (core libraries)
│
└── /install.lua (MODIFIED) - Call kickstarter
```

## What Changed: Before vs After

### Before Service System

```lua
-- Manual setup required
local hmi = require("lib/nodes/hmi")
hmi.init()
hmi.start()

-- Manual hardware configuration
local hal = require("lib/hardware/hal")
hal.configure({...})

-- Individual module loading
local db = require("lib/database")
local alerts = require("lib/alerts")
```

### After Service System

```bash
# Installation with auto-start
lua install.lua

# Boot sequence
# [boot] → [services auto-start] → [ready]

# Service management
svc list
svc start supervisor
svc status hmi

# Done! Services initialized automatically
```

### Key Changes

| Aspect                 | Before                 | After                             |
|------------------------|------------------------|-----------------------------------|
| **Setup**              | Manual module loading  | Auto hardware detection           |
| **Configuration**      | Create config manually | Saved at `/etc/node_type`         |
| **Boot**               | Manual service start   | Auto-start via 95_services.lua    |
| **Service Control**    | None available         | `svc` utility                     |
| **Hardware Detection** | None                   | Auto detects GPU, modem, reactors |
| **Error Handling**     | Manual try/catch       | Essential vs optional services    |
| **Persistence**        | No configuration saved | Node type persists across boots   |

## Contributing

- Fork the repo, make changes, submit PRs.
- Follow modular structure; test in OpenComputers environment.
- For service system changes, ensure backward compatibility with boot sequence.
- Test both auto-detect and manual node type initialization.

## License

See LICENSE file.

