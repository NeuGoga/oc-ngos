local component = require("component")
local computer = require("computer")
local fs = require("filesystem")
local serialization = require("serialization")
local internet = require("internet")
local term = require("term")

local gpu = component.gpu
local w, h = gpu.getResolution()

local REPO_BASE = "https://raw.githubusercontent.com/NeuGoga/oc-ngos/main/"
local MANIFEST_URL = REPO_BASE .. "os_manifest.tbl"
local VERSION_FILE = "/etc/os.info"

local T = _G.ngos.theme

local function httpGet(url)
    local success, response = pcall(internet.request, url)
    if not success or not response then return nil end
    
    local data = ""
    while true do
        local chunk_success, chunk = pcall(response)
        if not chunk_success then return nil end
        if not chunk then break end
        data = data .. chunk
    end
    return data
end

local function header()
    gpu.setBackground(T.bg)
    gpu.fill(1, 1, w, h, " ")
    gpu.setForeground(T.accent)
    gpu.set(2, 1, "NgOS System Updater")
    gpu.setForeground(T.gray)
    gpu.set(2, 2, string.rep("-", w - 4))
end

header()

local currentVer = _G.ngos.version or "Unknown"

gpu.setForeground(T.text)
gpu.set(2, 4, "Current Version: " .. currentVer)
gpu.setForeground(T.gray)
gpu.set(2, 5, "Checking remote server...")

local respStr = httpGet(MANIFEST_URL)
if not respStr then
    gpu.setForeground(T.err)
    gpu.set(2, 7, "Error: Could not connect to GitHub.")
    gpu.set(2, 8, "Press any key to exit.")
    coroutine.yield("key_down")
    return
end

local manifest = serialization.unserialize(respStr)
if not manifest or not manifest.version then
    gpu.setForeground(T.err)
    gpu.set(2, 7, "Error: Invalid manifest data.")
    os.sleep(2)
    return
end

local forceUpdate = false
if manifest.version == currentVer then
    gpu.setForeground(T.accent)
    gpu.set(2, 7, "System is up to date!")
    gpu.setForeground(T.gray)
    gpu.set(2, 8, "Remote: v" .. manifest.version)
    
    gpu.setForeground(T.text)
    gpu.set(2, 10, "Force update anyway? (y/n): ")
    term.setCursor(30, 10)
    local input = term.read():gsub("\n", "")
    
    if string.lower(input) ~= "y" then return end
    forceUpdate = true
else
    gpu.setForeground(T.accent)
    gpu.set(2, 7, "New version found: v" .. manifest.version)
    gpu.setForeground(T.text)
    gpu.set(2, 9, "Press [Enter] to install...")
    term.read()
end

header()
gpu.setForeground(T.accent)
gpu.set(2, 4, "Updating to v" .. manifest.version .. "...")

local currentY = 6
for localPath, remoteUrl in pairs(manifest.files) do
    gpu.setForeground(T.gray)
    gpu.set(3, currentY, "> " .. fs.name(localPath))
    
    local fileData = httpGet(remoteUrl)
    if fileData then
        local dir = fs.path(localPath)
        if not fs.exists(dir) then fs.makeDirectory(dir) end
        
        local f = io.open(localPath, "w")
        f:write(fileData)
        f:close()
        
        gpu.setForeground(0x00FF00)
        gpu.set(w - 10, currentY, "[OK]")
    else
        gpu.setForeground(0xFF0000)
        gpu.set(w - 10, currentY, "[ERR]")
    end
    
    currentY = currentY + 1
    if currentY > h - 2 then currentY = 6 end 
end

local infoData = {
    name = "NgOS",
    version = manifest.version,
    channel = "Stable",
    updated = os.time()
}

local f = io.open(VERSION_FILE, "w")
f:write(serialization.serialize(infoData))
f:close()

gpu.setForeground(0x00FF00)
gpu.set(2, currentY + 1, "Update Complete!")

if fs.exists("/ngos/bin/gen_digest.lua") then
    gpu.setForeground(T.gray)
    gpu.set(2, currentY + 2, "Updating Security Digest...")
    dofile("/ngos/bin/gen_digest.lua")
end

gpu.setForeground(T.text)
gpu.set(2, currentY + 4, "System will reboot in 3 seconds.")
os.sleep(3)
computer.shutdown(true)