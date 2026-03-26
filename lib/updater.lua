-- Node-Side Updater Module
-- Handles delta updates, SHA1 validation, and safe file swapping
local component = require("component")
local serialization = require("serialization")
local filesystem = require("filesystem")
local computer = require("computer")

local updater_cfg_path = "/lib/updater.cfg"
local updater_cfg = {
  repo = "https://raw.githubusercontent.com/Daminer5/OC_BaseOS/refs/heads/",
  branch = "dev"
}

if filesystem.exists(updater_cfg_path) then
  local ok, fn = pcall(loadfile, updater_cfg_path)
  if ok and fn then
    local success, result = pcall(fn)
    if success and type(result) == "table" then
      for k,v in pairs(result) do updater_cfg[k] = v end
    end
  end
end

local modem = component.modem
local sha1_available, sha1 = pcall(require, "sha1")

local M = {}
M.UPDATER_REPO = updater_cfg.repo
M.BRANCH = updater_cfg.branch or "dev"
M.GITHUB_BASE = (M.UPDATER_REPO:gsub("/+$", "")) .. "/" .. M.BRANCH

-- =============================
-- Constants & Configuration
-- =============================
M.STAGING_DIR = "/tmp/update_staging"
M.BACKUP_DIR = "/tmp/update_backup"
M.MANIFEST_CACHE = "/cache/manifest.lua"
M.VERSION_FILE = "/cache/version.txt"

-- =============================
-- Utility Functions
-- =============================

local function ensureDir(path)
  if not filesystem.exists(path) then
    filesystem.makeDirectory(path)
  end
end

local function readFile(path)
  if not filesystem.exists(path) then return nil end
  local f = io.open(path, "r")
  if not f then return nil end
  local data = f:read("*a")
  f:close()
  return data
end

local function writeFile(path, data)
  ensureDir(path:match("(.*/)[^/]*$") or "/")
  local f = io.open(path, "w")
  if not f then return false end
  f:write(data)
  f:close()
  return true
end

local function sha1Hash(data)
  if not sha1_available then
    -- Fallback: simple length-based checksum (not cryptographically secure)
    return string.format("%08x", #data)
  end
  return sha1.sha1(data)
end

local function fileHash(path)
  local data = readFile(path)
  if not data then return nil end
  return sha1Hash(data)
end

local function deleteDir(path)
  if not filesystem.exists(path) then return true end
  local ok, err = pcall(function()
    for file in filesystem.list(path) do
      local fullpath = path .. "/" .. file
      if filesystem.isDirectory(fullpath) then
        deleteDir(fullpath)
      else
        filesystem.remove(fullpath)
      end
    end
    filesystem.remove(path)
  end)
  return ok
end

-- =============================
-- Manifest Handling
-- =============================

function M.loadManifest()
  local data = readFile(M.MANIFEST_CACHE)
  if not data then return nil end
  
  local ok, manifest = pcall(load, "return " .. data)
  if not ok or type(manifest) ~= "table" then
    return nil
  end
  return manifest
end

function M.getCurrentVersion()
  return readFile(M.VERSION_FILE) or "0.0.0"
end

-- =============================
-- Delta Detection
-- =============================

function M.getDelta(manifest)
  -- Compare local file hashes with manifest hashes
  -- Return list of files that need updating
  if not manifest or not manifest.files then
    return {}
  end
  
  local delta = {}
  for filepath, expectedHash in pairs(manifest.files) do
    local localHash = fileHash(filepath)
    if localHash ~= expectedHash then
      table.insert(delta, filepath)
    end
  end
  
  return delta
end

-- =============================
-- Update Download & Staging
-- =============================

function M.stageFile(filepath, data)
  -- Stage file in temporary directory
  local stagePath = M.STAGING_DIR .. filepath
  return writeFile(stagePath, data)
end

function M.validateStagedFiles(manifest)
  -- Verify all staged files match manifest hashes
  if not manifest or not manifest.files then
    return false
  end
  
  for filepath, expectedHash in pairs(manifest.files) do
    local stagePath = M.STAGING_DIR .. filepath
    local stagedData = readFile(stagePath)
    
    if not stagedData then
      return false, "Missing staged file: " .. filepath
    end
    
    local actualHash = sha1Hash(stagedData)
    if actualHash ~= expectedHash then
      return false, "Hash mismatch for " .. filepath .. 
                    " (expected " .. expectedHash .. ", got " .. actualHash .. ")"
    end
  end
  
  return true
end

-- =============================
-- Safe File Swap
-- =============================

function M.backupFiles(manifest)
  -- Backup current files before swapping
  if not manifest or not manifest.files then
    return true
  end
  
  ensureDir(M.BACKUP_DIR)
  
  for filepath, _ in pairs(manifest.files) do
    if filesystem.exists(filepath) then
      local backupPath = M.BACKUP_DIR .. filepath
      local fileData = readFile(filepath)
      if fileData then
        writeFile(backupPath, fileData)
      end
    end
  end
  
  return true
end

function M.swapStagedFiles(manifest)
  -- Atomic swap: move staged files to their actual locations
  if not manifest or not manifest.files then
    return true
  end
  
  for filepath, _ in pairs(manifest.files) do
    local stagePath = M.STAGING_DIR .. filepath
    if filesystem.exists(stagePath) then
      -- Create parent directory if needed
      local parentDir = filepath:match("(.*/)[^/]*$")
      if parentDir then ensureDir(parentDir) end
      
      -- Read staged file and write to actual location
      local data = readFile(stagePath)
      if not data then
        return false, "Failed to read staged file: " .. stagePath
      end
      
      if not writeFile(filepath, data) then
        return false, "Failed to write file: " .. filepath
      end
    end
  end
  
  return true
end

function M.restoreBackup(manifest)
  -- Restore from backup in case of failure
  if not manifest or not manifest.files then
    return true
  end
  
  for filepath, _ in pairs(manifest.files) do
    local backupPath = M.BACKUP_DIR .. filepath
    if filesystem.exists(backupPath) then
      local data = readFile(backupPath)
      if data then
        writeFile(filepath, data)
      end
    end
  end
  
  return true
end

-- =============================
-- Main Update Flow
-- =============================

function M.checkForUpdates(currentVersion, newVersion)
  -- Returns true if update is needed
  if not newVersion or newVersion == currentVersion then
    return false
  end
  return true
end

function M.prepareUpdate(manifest)
  -- Clear staging area
  deleteDir(M.STAGING_DIR)
  ensureDir(M.STAGING_DIR)
  
  -- Backup current files
  if not M.backupFiles(manifest) then
    return false, "Failed to backup files"
  end
  
  return true
end

function M.applyUpdate(manifest, newVersion)
  -- Final step: swap files and update version
  
  -- Validate staged files
  local ok, err = M.validateStagedFiles(manifest)
  if not ok then
    return false, "Validation failed: " .. err
  end
  
  -- Swap staged to live
  local ok, err = M.swapStagedFiles(manifest)
  if not ok then
    return false, "Swap failed: " .. err
  end
  
  -- Update version file
  if not writeFile(M.VERSION_FILE, newVersion) then
    return false, "Failed to write version file"
  end
  
  -- Clean up staging and backup
  deleteDir(M.STAGING_DIR)
  deleteDir(M.BACKUP_DIR)
  
  return true
end

function M.rollback()
  -- Restore from backup after failed update
  local manifest = M.loadManifest()
  if not manifest then
    return false, "No manifest available for rollback"
  end
  
  local ok, err = M.restoreBackup(manifest)
  if not ok then
    return false, "Rollback failed: " .. err
  end
  
  -- Clean up staging
  deleteDir(M.STAGING_DIR)
  
  return true
end

-- =============================
-- Integration Point
-- =============================

function M.update(orchestrator_addr, orchestrator_channel)
  -- Request manifest and delta from orchestrator
  -- Download changed files
  -- Stage and validate
  -- Swap files
  -- Return status
  
  if not modem.isOpen(orchestrator_channel) then
    modem.open(orchestrator_channel)
  end
  
  local currentVersion = M.getCurrentVersion()
  local manifest = M.loadManifest()
  
  if not manifest then
    return false, "No manifest available"
  end
  
  -- Calculate delta
  local delta = M.getDelta(manifest)
  
  if #delta == 0 then
    return true, "Already up to date"
  end
  
  -- Prepare staging area
  local ok, err = M.prepareUpdate(manifest)
  if not ok then
    return false, "Preparation failed: " .. err
  end
  
  return true, "Ready to apply update (" .. #delta .. " files)"
end

return M
