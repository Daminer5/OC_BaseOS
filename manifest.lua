return {
  -- Common files installed on all nodes
  common = {
    "/lib/updater.lua",
    "/lib/updater.cfg",
    "/lib/hardware/hal.lua",
    "/lib/node_comm.lua",
    "/bin/kickstart.lua",
    "/bin/svc.lua",
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
      "/lib/hardware/br_turbine.lua",
      "/lib/nodes/config/br_reactor.lua",
      "/lib/nodes/config/example.br.reactor.cfg",
      "/lib/nodes/tasks/br_controller.lua",
      "/lib/nodes/energy_generation/BR_Reactor.lua",
      "/lib/nodes/energy_generation/BR_Turbine.lua",
      "/lib/config/br_turbine.lua",
      "/lib/auto_calibration.lua",
      "/lib/reactor_calibration.lua",
      "/lib/turbine_calibration.lua",
      "/lib/grid_control.lua",
      "/bin/brgc.lua"
    },
    mekanism_fusion_reactor = {
      "/lib/hardware/mekanism_reactor.lua",
      "/lib/nodes/energy_generation/MEK_Fusion.lua",
      "/lib/nodes/config/mekanism_reactor.lua"
    },
    mekanism_fission_reactor = {
      "/lib/hardware/mekanism_reactor.lua",
      "/lib/nodes/energy_generation/MEK_Fission.lua",
      "/lib/nodes/config/mekanism_reactor.lua"
    },
    mekanism_turbine = {
      "/lib/hardware/mekanism_turbine.lua",
      "/lib/nodes/energy_generation/MEK_Turbine.lua",
      "/lib/nodes/config/mekanism_turbine.lua"
    },
    rc_fusion_reactor = {
      "/lib/hardware/rc_fusion_reactor.lua",
      "/lib/nodes/energy_generation/RC_Fusion.lua",
      "/lib/nodes/config/rc_fusion_reactor.lua"
    },
    rc_turbine = {
      "/lib/hardware/rc_turbine.lua",
      "/lib/nodes/energy_generation/RC_Turbine.lua",
      "/lib/nodes/config/rc_turbine.lua"
    },
    de_reactor = {
      "/lib/hardware/de_reactor.lua",
      "/lib/nodes/energy_generation/DE_Reactor.lua",
      "/lib/nodes/config/de_reactor.lua"
    },
    ae_storage = {
      "/lib/hardware/ae2_monitor.lua",
      "/lib/nodes/config/ae_storage.lua"
    },
    energy_storage = {
      "/lib/hardware/energy_storage.lua",
      "/lib/nodes/config/energy_storage.lua"
      "/lib/nodes/energy_storage/Enderio_Energy.lua",
      "/lib/nodes/config/Enderio_Energy.lua",
      "/lib/nodes/energy_storage/MEK_Energy.lua",
      "/lib/nodes/config/MEK_Energy.lua",
      "/lib/nodes/energy_storage/ThermalEx_Energy.lua",
      "/lib/nodes/config/ThermalEx_Energy.lua",
      "/lib/nodes/energy_storage/DE_Energy.lua",
      "/lib/nodes/config/DE_Energy.lua"
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
