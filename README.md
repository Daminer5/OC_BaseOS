# OC_BaseOS

OpenComputers Base OS - A distributed SCADA controller for OpenComputers mod in Minecraft.

Repository: https://github.com/Daminer5/OC_BaseOS

## Overview

OC_BaseOS is a modular operating system designed for OpenComputers 1.7.10, functioning as a SCADA (Supervisory Control and Data Acquisition) controller. It manages sub-programs via configurations, auto-scales and auto-configures based on connected devices, and provides real-time monitoring, safe updates, and a touchscreen HMI dashboard.

The system is built in Lua and uses a layered architecture: Hardware → Device → Task → Orchestration → UI.

## Architecture

### Core Components

- **Boot System** (`/boot/`): Initializes the OS in stages (base, process, OS, I/O, components, devfs, rc, filesystem, GPU, keyboard, terminal, shell).
- **Binaries** (`/bin/`): Standard Unix-like utilities (ls, cd, grep, etc.) for system management.
- **Libraries** (`/lib/`): Core modules for filesystem, event handling, serialization, etc.
- **Nodes** (`/lib/nodes/`): Specialized components for monitoring, supervision, and UI.

## Subsystems

### 1. Updater (`/lib/updater.lua`)
**Purpose**: Manages safe, delta-based software updates with SHA1 validation and rollback capabilities. Ensures system integrity during updates.

**How it works**: Downloads update manifests, verifies hashes, applies patches, and can revert if issues occur. Supports distributed updates across nodes.

**Installation/Configuration**:
- Deploy `updater.lua` to each node.
- Configure update server URL in `updater.cfg`.
- Run `updater.update()` to check and apply updates.

### 2. Hardware Abstraction Layer (HAL) (`/lib/hardware/`)
**Purpose**: Provides unified interfaces to hardware components (reactors, turbines, storage systems) from mods like Big Reactors, Mekanism, Thermal Expansion, etc.

**How it works**: `hal.lua` detects and abstracts hardware; device-specific wrappers (e.g., `br_reactor.lua`) handle mod-specific APIs.

**Installation/Configuration**:
- Ensure OpenComputers components (modem, GPU, etc.) are installed on computers.
- Place hardware wrappers in `/lib/hardware/`.
- HAL auto-detects on boot; configure device addresses in `hal.lua` if needed.

### 3. Tasks/Monitors (`/nodes/tasks/`)
**Purpose**: Background monitoring modules for specific systems (reactors, storage, AE2 networks).

**How it works**: Each task (e.g., `reactor_monitor.lua`) polls hardware, collects metrics, and reports to the database/alerts system.

**Installation/Configuration**:
- Deploy task scripts to monitor nodes.
- Configure thresholds and intervals in task configs.
- Start via orchestrator or manually with `require("nodes.tasks.reactor_monitor").start()`.

### 4. Database (`/lib/database.lua`)
**Purpose**: Centralized registry for nodes, configurations, and metrics with persistence and staleness detection.

**How it works**: Stores node info, handles queries, and cleans up stale entries. Uses filesystem for persistence.

**Installation/Configuration**:
- Deploy to central database node.
- Configure storage path in `database.lua`.
- Access via `require("database").register_node()`.

### 5. Supervisor (`/lib/nodes/supervisor/Core.lua`)
**Purpose**: Enhanced runtime supervisor for process management, error handling, and system health.

**How it works**: Monitors processes, restarts failed ones, and provides system diagnostics.

**Installation/Configuration**:
- Deploy to supervisor nodes.
- Configure process lists in `Core.lua`.
- Start with `supervisor.start()`.

### 6. Alerts (`/lib/alerts.lua`)
**Purpose**: Threshold-based alert system with severity levels for proactive monitoring.

**How it works**: Checks metrics against thresholds, triggers alerts (logs, notifications), and escalates based on severity.

**Installation/Configuration**:
- Deploy to alert nodes.
- Define thresholds in `alerts.lua` or config files.
- Integrate with tasks via `alerts.check_threshold()`.

### 7. HMI (Human-Machine Interface) (`/lib/nodes/hmi/`)
**Purpose**: Touchscreen dashboard for real-time visualization and control.

**How it works**: `dashboard.lua` renders multi-view UI; `widgets.lua` provides components; `hmi_window.lua` offers console debug mode.

**Installation/Configuration**:
- Deploy to HMI nodes with GPU and touchscreen.
- Configure views in `dashboard.lua`.
- For debugging, use `hmi_window.lua` in VS Code.

### 8. Orchestrator (`/lib/nodes/orchestrator.lua`)
**Purpose**: Auto-scaling and configuration management for distributed systems.

**How it works**: Detects devices, assigns tasks, balances load, and manages node lifecycles.

**Installation/Configuration**:
- Deploy to orchestrator node.
- Configure auto-scaling rules in `orchestrator.lua`.
- Start with `orchestrator.run()`.

## Installation

1. **Prerequisites**:
   - Minecraft with OpenComputers 1.7.10 mod.
   - Computers with required components (modem for networking, GPU/screen for HMI).

2. **Deploy Code**:
   - Transfer files via floppy disk or network (use `wget` or `pastebin`).
   - Place in root filesystem of OpenComputers.

3. **Boot**:
   - Run `init.lua` to initialize the OS.
   - For specific subsystems, require and start modules (e.g., `require("nodes.orchestrator").run()`).

4. **Configuration**:
   - Edit config files (e.g., `updater.cfg`, `rc.cfg`).
   - Set node roles and addresses in database.

## Usage

- **Monitoring**: Tasks collect data; view via HMI or query database.
- **Control**: Use HMI for manual overrides; orchestrator handles automation.
- **Updates**: Run updater periodically.
- **Debugging**: Use VS Code with `.vscode/launch.json` for local testing; deploy to OC for full validation.

## Debugging

- Local: Use "Debug HMI (window)" in VS Code for console output.
- In-Game: Export install; log via `print` or screen output.
- Logs: Check `/logs/` for runtime issues.

## Contributing

- Fork the repo, make changes, submit PRs.
- Follow modular structure; test in OpenComputers environment.

## License

See LICENSE file.

