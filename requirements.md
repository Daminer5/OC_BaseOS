# OC_BaseOS Node Hardware Requirements

This file lists hardware and connected devices required for each node type used by OC_BaseOS.

## orchestrator
- modem (required)
- filesystem (required)
- optional network card (for redundancy)
- no GPU/screen needed
- recommended: `/tmp`, `/cache`, `/var` available

## reactor (reactor_monitor)
- modem (required)
- one or more reactor-type blocks:
  - BigReactors_Reactor
  - MEKismFissionReactor
  - MEKismFusionReactor
- optional energy storage:
  - MEKismEnergyTank
  - EnderIOEnergyBank
  - ThermalExpansionEnergyCell
- recommended: energy sensor components in `hardware/` package

## storage (storage_monitor)
- modem (required)
- AE2 network presence (`me_` components) or inventory storage devices
- optional energy storage as above

## database
- modem (required)
- filesystem and persistent disk (`hard_drive`, `filesystem`, `archive`) 
- recommended: more than 1GB of disk space in OpenComputers (as available)

## hmi (dashboard)
- modem (required)
- GPU (`gpu` component)
- screen (`screen` component)
- keyboard (`keyboard` component)
- optional touchscreen support

## generic/worker
- modem (required)
- may run only monitoring tasks and join orchestrator

---

## note on auto-detection flow (install.lua)
- if hardware indicates reactor/AE2/HMI, script sets node type accordingly.
- if no local devices found, script queries channel `1234` for orchestrator/database/HMI announcements.
- non-detected nodes default to orchestrator if no orchestrator is present.
