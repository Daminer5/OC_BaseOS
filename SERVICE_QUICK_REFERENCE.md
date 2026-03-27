# Service System Quick Reference

## Quick Start

### After Installation
Services start automatically and are configured for your hardware.

### Manual Startup
```bash
# Auto-detect and start services
kickstart.lua

# Start specific node type
kickstart.lua hmi
kickstart.lua supervisor
kickstart.lua br_reactor

# Manage specific services
svc start supervisor
svc stop hmi
svc restart breactor
svc status all
svc list
```

## Service Files

| File | Purpose |
|------|---------|
| `/bin/kickstart.lua` | Main service initialization |
| `/bin/svc.lua` | Service management utility |
| `/boot/95_services.lua` | Boot-time service startup |
| `/etc/rc.d/services.lua` | Service orchestration |
| `/etc/rc.d/*.lua` | Individual node service scripts |
| `/etc/node_type` | Saved node type configuration |

## Node Types

| Type | Hardware | Services |
|------|----------|----------|
| hmi | GPU + Screen | modem, monitor, hmi |
| supervisor | Any | modem, database, alerts, orchestrator |
| br_reactor | Big Reactor | modem, reactor, monitor |
| mekanism_reactor | Mekanism | modem, mekanism, monitor |
| ae_storage | AE2 System | modem, ae_monitor |
| exporter | Any | modem, exporter, monitor |
| worker | Modem | modem, worker |
| generic | Any | modem |

## Common Tasks

### View Node Type
```bash
cat /etc/node_type
```

### Change Node Type
```bash
# Edit node type file
edit /etc/node_type

# Restart services with new type
kickstart.lua <new-type>
```

### Check Service Status
```bash
svc status hmi
svc status supervisor
svc status breactor
```

### Restart All Services
```bash
svc reload
```

### View Service Logs
```bash
tail -n 50 /var/logs/service.log
cat /var/logs/system.log
```

## Service Priority Order

Services start in this priority (lower = first):

1. Modem (network)
2. Monitor (display)
3. Database
4. Alerts
5-9. Hardware services (reactors, storage, etc.)
10. User-facing (HMI, orchestrator)

## Troubleshooting

### Services won't start
```bash
# Check saved node type
cat /etc/node_type

# Run kickstarter manually
kickstart.lua

# Check for hardware
components
```

### Service crashed
```bash
# Restart specific service
svc restart <service>

# Check error logs
tail -n 100 /var/logs/service.log
```

### Manually start failed service
```bash
# Use shell to execute
lua
local shell = require("shell")
shell.execute("svc start hmi")
```

## Boot Sequence

1. System powers on
2. Firmware boots (00-80_*.lua)
3. Services boot file runs (95_services.lua)
4. Node type loaded from /etc/node_type
5. kickstart.lua executes with saved type
6. All services initialize in priority order
7. Shell/user interface starts
8. System ready

## Configuration Files

Created at:
- `/etc/node_type` - Current node type
- `/etc/<node-type>.cfg` - Node configuration (auto-generated)

## Integration Points

### Installation
- Runs automatically after `install.lua`
- Prompts for node type
- Saves configuration

### Boot
- Runs at init event (95_services.lua)
- Uses saved node type
- Starts all configured services

### Runtime
- `svc` utility for manual control
- RC system for service management
- Event-based shutdown/cleanup

## Environment Variables Set

After kickstarter runs:
- `_G.node_services_started` = true/false
- `_G.<nodetype>_node_running` = true (if running)

Check in code:
```lua
if _G.node_services_started then
  print("Services active")
end
```

## Performance Notes

- Services start in priority order (faster startup)
- Only required services start (minimal overhead)
- Hardware-based auto-detection (zero configuration)
- Graceful degradation (optional services fail silently)

## Future Enhancements

- [ ] Service inter-dependencies
- [ ] Service health monitoring
- [ ] Automatic restart on failure
- [ ] Performance metrics
- [ ] Service hot-reload
- [ ] Remote service management
- [ ] Service clustering
