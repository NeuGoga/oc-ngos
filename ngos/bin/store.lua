local component = require("component")
local computer = require("computer")
local fs = require("filesystem")
local serialization = require("serialization")
local internet = require("internet")

local gpu = component.gpu
local w, h = gpu.getResolution()

local T = _G.ngos.theme

local STORE_MANIFEST_URL = "https://raw.githubusercontent.com/NeuGoga/oc-ngos-apps/main/apps.tbl"


local apps = {}
local selectedAppIndex = 1
local statusMessage = "Fetching app list..."
local hitboxes = {}

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

local function loadApps()
    local resp = httpGet(STORE_MANIFEST_URL)
    if resp then
        local manifest = serialization.unserialize(resp)
        if manifest and manifest.apps then
            apps = manifest.apps
            statusMessage = "Loaded " .. #apps .. " apps."
            return
        end
    end
end

local function installApp(app)
    statusMessage = "Installing " .. app.name .. "..."
    redrawAll()
    
    local appDir = "/apps/" .. app.name
    if not fs.exists(appDir) then fs.makeDirectory(appDir) end
    
    for localPath, remoteUrl in pairs(app.files) do
        local fileData = httpGet(remoteUrl)
        if fileData then
            local dir = fs.path(localPath)
            if not fs.exists(dir) then fs.makeDirectory(dir) end
            
            local f = io.open(localPath, "w")
            f:write(fileData)
            f:close()
        else
            statusMessage = "Failed to download " .. fs.name(localPath)
            redrawAll()
            os.sleep(2)
            return
        end
    end
    
    statusMessage = app.name .. " installed successfully!"
    computer.pushSignal("ngos_app_installed") 
    redrawAll()
end

local function uninstallApp(app)
    local appDir = "/apps/" .. app.name
    if fs.exists(appDir) then
        fs.remove(appDir)
        statusMessage = app.name .. " uninstalled."
    end
    redrawAll()
end

local function drawButton(x, y, width, text, bg, fg, action)
    gpu.setBackground(bg)
    gpu.setForeground(fg)
    
    local padding = math.max(0, math.floor((width - #text) / 2))
    local btnStr = string.rep(" ", padding) .. text .. string.rep(" ", width - #text - padding)
    
    gpu.set(x, y, btnStr)
    
    table.insert(hitboxes, { x1 = x, x2 = x + width - 1, y1 = y, y2 = y, action = action })
end

function redrawAll()
    hitboxes = {}
    
    gpu.setBackground(T.bg)
    gpu.fill(1, 1, w, h, " ")
    
    gpu.setBackground(T.header)
    gpu.fill(1, 1, w, 1, " ")
    gpu.setForeground(T.headerText)
    gpu.set(2, 1, "NgOS App Store")
    
    local listWidth = math.floor(w / 3)
    gpu.setBackground(T.gray)
    gpu.fill(1, 2, listWidth, h - 2, " ")
    
    for i, app in ipairs(apps) do
        local y = 2 + i
        if i == selectedAppIndex then
            gpu.setBackground(T.accent)
            gpu.setForeground(T.bg)
        else
            gpu.setBackground(T.gray)
            gpu.setForeground(T.white)
        end
        
        local displayName = " " .. app.name
        gpu.set(1, y, displayName .. string.rep(" ", listWidth - #displayName))
        
        table.insert(hitboxes, {
            x1 = 1, x2 = listWidth, y1 = y, y2 = y,
            action = function() selectedAppIndex = i; redrawAll() end
        })
    end
    
    local detailsX = listWidth + 2
    local activeApp = apps[selectedAppIndex]
    
    if activeApp then
        gpu.setBackground(T.bg)
        gpu.setForeground(T.accent)
        gpu.set(detailsX, 3, activeApp.name)
        
        gpu.setForeground(T.gray)
        gpu.set(detailsX, 4, "Version: " .. activeApp.version)
        
        gpu.setForeground(T.text)
        local descY = 6
        for line in activeApp.description:gmatch("([^\n]+)") do
            gpu.set(detailsX, descY, line)
            descY = descY + 1
        end
        
        local isInstalled = fs.exists("/apps/" .. activeApp.name .. "/app.lua")
        if isInstalled then
            drawButton(detailsX, descY + 2, 14, "Uninstall", T.err, T.white, function() uninstallApp(activeApp) end)
            drawButton(detailsX + 16, descY + 2, 14, "Reinstall", T.warn, T.black, function() installApp(activeApp) end)
        else
            drawButton(detailsX, descY + 2, 14, "Install", T.accent, T.bg, function() installApp(activeApp) end)
        end
    end
    
    gpu.setBackground(T.header)
    gpu.fill(1, h, w, 1, " ")
    gpu.setForeground(T.text)
    gpu.set(2, h, statusMessage)
end

redrawAll()
loadApps()
redrawAll()

while true do
    local eventData = { coroutine.yield() }
    local ev = eventData[1]
    
    if ev == "touch" then
        local x, y = eventData[3], eventData[4]
        for _, box in ipairs(hitboxes) do
            if x >= box.x1 and x <= box.x2 and y >= box.y1 and y <= box.y2 then
                gpu.setBackground(T.warn)
                gpu.set(box.x1, box.y1, string.rep(" ", box.x2 - box.x1 + 1))
                os.sleep(0.05)
                
                box.action()
                break
            end
        end
        
    elseif ev == "refresh" then
        redrawAll()
    end
end