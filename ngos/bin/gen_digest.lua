local component = require("component")
local fs = require("filesystem")
local serialization = require("serialization")
local term = require("term")

local gpu = component.gpu

local sha256 = dofile("/ngos/lib/sha256.lua")

local DIGEST_FILE = "/etc/system.digest"

local criticalFiles = {
    "/home/.shrc",
    "/ngos/system/kernel.lua",
    "/ngos/system/security.lua",
    "/ngos/system/theme.lua",
    "/ngos/bin/desktop.lua",
    "/ngos/bin/store.lua",
    "/ngos/bin/settings.lua",
    "/ngos/bin/updater.lua",
    "/ngos/bin/gen_digest.lua",
    "/ngos/lib/sha256.lua"
}

gpu.setBackground(0x000000)
term.clear()
gpu.setForeground(0xFFFFFF)
print("NgOS Security Manager")
print("Generating System Digest...")
print("============================")

local digest = {}

for _, path in ipairs(criticalFiles) do
    io.write("Hashing " .. fs.name(path) .. "... ")
    
    if fs.exists(path) then
        local f = io.open(path, "rb")
        local content = f:read("*a")
        f:close()
        
        local cleanContent = content:gsub("\r", ""):gsub("%s+$", "")
        digest[path] = sha256.hex(cleanContent)
        
        gpu.setForeground(0x00FF00)
        print("OK")
    else
        gpu.setForeground(0xFF0000)
        print("MISSING")
    end
    gpu.setForeground(0xFFFFFF)
end

local f = io.open(DIGEST_FILE, "w")
f:write(serialization.serialize(digest))
f:close()

gpu.setForeground(0x00FF00)
print("\nDigest saved to " .. DIGEST_FILE)
gpu.setForeground(0xFFFFFF)
os.sleep(2)