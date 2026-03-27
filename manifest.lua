return {
  -- Common files installed on all nodes
  common = {
    "lib/updater.lua",
    "lib/updater.cfg",
  },

  -- Node-specific files
  nodes = {
    hmi = {
      "lib/nodes/hmi.lua",
      "lib/nodes/config/hmi.lua"
    },
    orchestrator = {
      "lib/nodes/orchestrator.lua",
      "lib/nodes/config/orchestrator.lua"
    },
    br_reactor = {
      "lib/hardware/br_reactor.lua",
      "lib/nodes/config/br_reactor.lua"
    },
    ae_storage = {
      "lib/hardware/ae2_monitor.lua",
      "lib/nodes/config/ae_storage.lua"
    },
    exporter = {
      "lib/nodes/exporter.lua",
      "lib/nodes/config/exporter.lua"
    },
    database = {
      "lib/database.lua",
      "lib/nodes/config/database.lua"
    },
    worker = {
      "lib/nodes/config/worker.lua"
    },
    generic = {
      "lib/nodes/config/generic.lua"
    }
  }
}
