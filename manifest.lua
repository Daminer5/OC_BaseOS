return {
  -- Common files installed on all nodes
  common = {
    "init.lua",
    "lib/init.lua",
    "lib/event.lua",
    "lib/filesystem.lua",
    "lib/internet.lua",
    "lib/io.lua",
    "lib/process.lua",
    "lib/sh.lua",
    "lib/shell.lua",
    "lib/term.lua",
    "lib/text.lua",
    "lib/serialization.lua",
    "lib/keyboard.lua",
    "lib/uuid.lua",
    "lib/updater.lua",
    "lib/updater.cfg",
    "boot/00_base.lua",
    "boot/01_process.lua",
    "boot/02_os.lua",
    "boot/03_io.lua",
    "boot/04_component.lua",
    "boot/10_devfs.lua",
    "boot/89_rc.lua",
    "boot/90_filesystem.lua",
    "boot/91_gpu.lua",
    "boot/92_keyboard.lua",
    "boot/93_term.lua",
    "boot/94_shell.lua",
    "etc/motd",
    "etc/profile.lua",
    "etc/rc.cfg",
    "bin/cat.lua",
    "bin/cd.lua",
    "bin/clear.lua",
    "bin/cp.lua",
    "bin/date.lua",
    "bin/echo.lua",
    "bin/find.lua",
    "bin/grep.lua",
    "bin/head.lua",
    "bin/hostname.lua",
    "bin/ls.lua",
    "bin/mkdir.lua",
    "bin/mv.lua",
    "bin/pwd.lua",
    "bin/rc.lua",
    "bin/rm.lua",
    "bin/set.lua",
    "bin/sh.lua",
    "bin/source.lua",
    "bin/time.lua",
    "bin/touch.lua",
    "bin/uptime.lua",
    "bin/which.lua"
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