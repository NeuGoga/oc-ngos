local fs = require("filesystem")
local serialization = require("serialization")
local computer = require("computer")
local component = require("component")
local term = require("term")

local gpu = component.gpu

local sha256 = dofile("/ngos/lib/sha256.lua")

local DIGEST_FILE = "/etc/system.digest"
local CONFIG_FILE = "/etc/security.cfg"

local security = {}

local function loadConfig()
    if fs.exists(CONFIG_FILE) then
        local f = io.open(CONFIG_FILE, "r")
        local data = serialization.unserialize(f:read("*a"))
        f:close()
        return data or { enabled = false, hash = nil }
    end
    return { enabled = false, hash = nil }
end

local function saveConfig(data)
    local f = io.open(CONFIG_FILE, "w")
    f:write(serialization.serialize(data))
    f:close()
end

local function drawBox(title, message, isError)
    gpu.setBackground(0x000000)
    local w, h = gpu.getResolution()
    gpu.fill(1, 1, w, h, " ")
    
    local bx, by = math.floor(w/4), math.floor(h/3)
    local bw, bh = math.floor(w/2), 6
    
    local boxColor = isError and 0xFF0000 or 0x00FFFF
    
    gpu.setBackground(boxColor)
    gpu.fill(bx, by, bw, bh, " ")
    
    gpu.setBackground(0x000000)
    gpu.fill(bx+1, by+1, bw-2, bh-2, " ")
    
    gpu.setForeground(boxColor)
    gpu.set(bx+2, by, " " .. title .. " ")
    
    gpu.setForeground(0xFFFFFF)
    gpu.set(bx+2, by+2, message)
    
    return bx+2, by+4
end

local function readPassword(x, y)
    local input = ""
    while true do
        gpu.setBackground(0x000000)
        gpu.setForeground(0xFFFFFF)
        gpu.set(x, y, string.rep("*", #input) .. "  ")
        
        local evData = { computer.pullSignal() }
        if evData[1] == "key_down" then
            local char = evData[3]
            local code = evData[4]
            
            if code == 28 then
                return input
            elseif code == 14 then
                if #input > 0 then
                    input = input:sub(1, -2)
                end
            elseif char >= 32 and char <= 126 then
                if #input < 20 then
                    input = input .. string.char(char)
                end
            end
        end
    end
end

function security.isEnabled()
    local cfg = loadConfig()
    return cfg.enabled
end

function security.checkIntegrity()
    gpu.setBackground(0x000000)
    local w, h = gpu.getResolution()
    gpu.fill(1, 1, w, h, " ")
    term.setCursor(1,1)
    
    gpu.setForeground(0xFFFFFF)
    print("NgOS Boot Guard")
    print("Verifying System Integrity...")
    
    if not fs.exists(DIGEST_FILE) then
        gpu.setForeground(0xFFAA00)
        print("System Digest missing.")
        print("Initializing security...")
        
        if fs.exists("/ngos/bin/gen_digest.lua") then
            dofile("/ngos/bin/gen_digest.lua")
            os.sleep(1)
            
            gpu.setBackground(0x000000)
            gpu.fill(1, 1, w, h, " ")
            term.setCursor(1,1)
            gpu.setForeground(0xFFFFFF)
            print("NgOS Boot Guard")
        else
            gpu.setForeground(0xFF0000)
            print("Error: Generator not found.")
            os.sleep(2)
            return true
        end
    end
    
    local f = io.open(DIGEST_FILE, "r")
    local knownHashes = serialization.unserialize(f:read("*a"))
    f:close()
    
    local errors = 0
    
    for path, expectedHash in pairs(knownHashes) do
        io.write(" " .. fs.name(path) .. " ")
        
        if not fs.exists(path) then
            gpu.setForeground(0xFF0000)
            print("[MISSING]")
            errors = errors + 1
        else
            local f2 = io.open(path, "rb")
            local content = f2:read("*a")
            f2:close()
            
            local cleanContent = content:gsub("\r", "")
            local actualHash = sha256.hex(cleanContent)
            
            if actualHash == expectedHash then
                gpu.setForeground(0x00FF00)
                print("[OK]")
            else
                gpu.setForeground(0xFF0000)
                print("[MODIFIED]")
                errors = errors + 1
            end
        end
        gpu.setForeground(0xFFFFFF)
    end
    
    if errors > 0 then
        print("\n" .. errors .. " integrity violations found.")
        print("System may be compromised.")
        io.write("Press Enter to continue anyway... ")
        io.read()
        return false
    end
    
    os.sleep(0.5)
    return true
end

function security.bootLogin()
    local cfg = loadConfig()
    if not cfg.enabled or not cfg.hash then return true end
    
    while true do
        local ix, iy = drawBox("Protected Boot", "Enter Password:", false)
        term.setCursor(ix, iy)
        
        local input = readPassword(ix, iy)
        
        if sha256.hex(input) == cfg.hash then
            return true
        else
            drawBox("Access Denied", "Incorrect Password.", true)
            os.sleep(1)
        end
    end
end

function security.enableProtection()
    local cfg = loadConfig()
    
    while true do
        local ix, iy = drawBox("Security Setup", "Create Password:", false)
        term.setCursor(ix, iy)
        local p1 = readPassword(ix, iy)
        
        local ix2, iy2 = drawBox("Security Setup", "Confirm Password:", false)
        term.setCursor(ix2, iy2)
        local p2 = readPassword(ix2, iy2)
        
        if p1 == p2 and #p1 > 0 then
            cfg.hash = sha256.hex(p1)
            cfg.enabled = true
            saveConfig(cfg)
            drawBox("Success", "Protection Enabled.", false)
            os.sleep(1)
            return true
        else
            drawBox("Error", "Passwords did not match.", true)
            os.sleep(1)
        end
    end
end

function security.disableProtection()
    local cfg = loadConfig()
    if not cfg.enabled then return true end
    
    local attempts = 0
    while attempts < 3 do
        local ix, iy = drawBox("Security Check", "Enter current password:", false)
        term.setCursor(ix, iy)
        local input = readPassword(ix, iy)
        
        if sha256.hex(input) == cfg.hash then
            cfg.enabled = false
            cfg.hash = nil
            saveConfig(cfg)
            drawBox("Success", "Protection Disabled.", false)
            os.sleep(1)
            return true
        else
            drawBox("Error", "Incorrect Password.", true)
            os.sleep(1)
            attempts = attempts + 1
        end
    end
    return false
end

return security