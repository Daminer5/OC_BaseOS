return {
  -- Common files installed on all nodes
  common = {
    "/lib/updater.lua",
    "/lib/updater.cfg",
    "/lib/hardware/hal.lua",
    "/lib/node_comm.lua",
  },

  -- Node-specific files
  nodes = {
    hmi = {
      "/lib/nodes/hmi.lua",
      "/lib/nodes/config/hmi.lua"
    },
    supervisor = {
      "/lib/nodes/supervisor/core.lua",
      "/lib/nodes/orchestrator.lua",
      "/lib/nodes/config/orchestrator.lua",
      "/lib/database.lua",
      "/lib/nodes/config/database.lua",
      "/lib/alerts.lua",
      "/lib/nodes/config/alerts.lua"
    },
    br_reactor = {
      "/lib/hardware/br_reactor.lua",
      "/lib/nodes/config/br_reactor.lua"
    },
    mekanism_reactor = {
      "/lib/hardware/mekanism_reactor.lua",
      "/lib/nodes/energy_generation/MEK_Fission.lua",
      "/lib/nodes/energy_generation/MEK_Fusion.lua",
      "/lib/nodes/config/mekanism_reactor.lua"
    },
    ae_storage = {
      "/lib/hardware/ae2_monitor.lua",
      "/lib/nodes/config/ae_storage.lua"
    },
    exporter = {
      "/lib/nodes/exporter.lua",
      "/lib/nodes/config/exporter.lua"
    },
    worker = {
      "/lib/nodes/config/worker.lua"
    },
    generic = {
      "/lib/nodes/config/generic.lua"
    }
  }
}
