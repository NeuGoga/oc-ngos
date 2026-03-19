local component = require("component")
local internet = require("internet")
local fs = require("filesystem")
local serialization = require("serialization")
local computer = require("computer")
local term = require("term")

local gpu = component.gpu

local REPO_BASE = "https://raw.githubusercontent.com/NeuGoga/oc-ngos/main/"
local MANIFEST_URL = REPO_BASE .. "os_manifest.tbl"

local function httpGet(url)
    local req_success, response = pcall(internet.request, url)
    if not req_success or not response then return nil end
    
    local data = ""
    while true do
        local chunk_success, chunk = pcall(response)
        
        if not chunk_success then 
            return nil
        end
        if not chunk then 
            break
        end
        
        data = data .. chunk
    end
    
    return data
end

gpu.setBackground(0x000000)
gpu.setForeground(0x00FFFF)
term.clear()
term.setCursor(1, 1)

print("Installing NgOS (OpenComputers)...")
print("==================================")

local dirs = {
    "/ngos/system",
    "/ngos/bin",
    "/ngos/lib",
    "/apps",
    "/apps/Store",
    "/apps/Settings",
    "/etc",
    "/media"
}

for _, d in ipairs(dirs) do
    if not fs.exists(d) then fs.makeDirectory(d) end
end

gpu.setForeground(0xAAAAAA)
io.write("Fetching file list... ")

local respStr = httpGet(MANIFEST_URL)
if not respStr then
    gpu.setForeground(0xFF0000)
    print("FAILED")
    print("Check internet card and connection.")
    return
end

local manifest = serialization.unserialize(respStr)
gpu.setForeground(0x00FF00)
print("OK")

print("Downloading System Files:")
for localPath, remoteUrl in pairs(manifest.files) do
    gpu.setForeground(0xFFFFFF)
    io.write(" > " .. fs.name(localPath) .. " ")
    
    local fileData = httpGet(remoteUrl)
    if fileData then
        local f = io.open(localPath, "w")
        f:write(fileData)
        f:close()
        
        gpu.setForeground(0x00FF00)
        print("OK")
    else
        gpu.setForeground(0xFF0000)
        print("ERR")
    end
end

gpu.setForeground(0xAAAAAA)
print("Configuring System...")

local info = {
    name = "NgOS",
    version = manifest.version or "1.0.0",
    channel = "Stable",
    installDate = os.time()
}
local f = io.open("/etc/os.info", "w")
f:write(serialization.serialize(info))
f:close()

gpu.setForeground(0xAAAAAA)
print("Setting up Default Theme...")

local defaultTheme = {
    name = "dark",
    quality = "low"
}
local fTheme = io.open("/etc/theme.cfg", "w")
fTheme:write(serialization.serialize(defaultTheme))
fTheme:close()

local function createLauncher(path, target)
    local f = io.open(path, "w")
    f:write('dofile("' .. target .. '")')
    f:close()
end
createLauncher("/apps/Store/app.lua", "/ngos/bin/store.lua")
createLauncher("/apps/Settings/app.lua", "/ngos/bin/settings.lua")

local autoBoot = io.open("/home/.shrc", "w")
autoBoot:write('os.execute("/ngos/system/kernel.lua")\n')
autoBoot:close()

local installerPath = os.getenv("_") or "/install.lua"
if fs.exists(installerPath) then fs.remove(installerPath) end

gpu.setForeground(0x00FFFF)
print("\nInstallation Complete!")
print("Rebooting in 3 seconds...")
os.sleep(3)
computer.shutdown(true)