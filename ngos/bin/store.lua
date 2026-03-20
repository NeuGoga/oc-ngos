local component = require("component")
local computer = require("computer")
local fs = require("filesystem")
local serialization = require("serialization")
local internet = require("internet")

local gpu = component.gpu
local w, h = gpu.getResolution()
local T = _G.ngos.theme

local STORE_MANIFEST_URL = "https://raw.githubusercontent.com/NeuGoga/oc-ngos-apps/main/apps.tbl"

local availableApps = {}
local installedApps = {}

local selectedSection = "available"
local selectedIndex = 1

local scrollOffsetAvailable = 0
local scrollOffsetInstalled = 0

local statusMessage = "Fetching app list..."
local hitboxes = {}

local sha256 = dofile("/ngos/lib/sha256.lua")

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

local INSTALLED_FILE = "/etc/installed.tbl"

local function loadInstalledData()
    if not fs.exists(INSTALLED_FILE) then return {} end
    local f = io.open(INSTALLED_FILE, "r")
    local data = serialization.unserialize(f:read("*a")) or {}
    f:close()
    return data
end

local function saveInstalledData(data)
    local f = io.open(INSTALLED_FILE, "w")
    f:write(serialization.serialize(data))
    f:close()
end

local function updateInstalledApps()
    local installedData = loadInstalledData()
    installedApps = {}
    for name, info in pairs(installedData) do
        if fs.exists("/apps/" .. name .. "/app.lua") then
            table.insert(installedApps, info)
        end
    end
end

local function loadAvailableApps()
    local resp = httpGet(STORE_MANIFEST_URL)
    if resp then
        local remoteApps = serialization.unserialize(resp)
        local installedData = loadInstalledData()
        
        availableApps = {}
        for _, app in ipairs(remoteApps) do
            if not installedData[app.name] then
                table.insert(availableApps, app)
            end
        end
        statusMessage = "Loaded " .. #availableApps .. " available apps."
    end
end

local function verifyApp(app)
    statusMessage = tostring(app.name or "Unknown") .. ": Verifying..."
    redrawAll()
    
    local manifestData = httpGet(app.manifest)
    if not manifestData then 
        statusMessage = "Error: No manifest"
        return false 
    end
    
    local appManifest = serialization.unserialize(manifestData)
    if not appManifest or not appManifest.files then
        statusMessage = "Error: Invalid manifest"
        return false
    end

    local errors = 0
    for localPath, fileInfo in pairs(appManifest.files) do
        local fullPath = "/apps/" .. app.name .. "/" .. localPath
        
        if not fs.exists(fullPath) then 
            statusMessage = "Missing file: " .. tostring(localPath or "???")
            errors = errors + 1
            break
        end
        
        local f = io.open(fullPath, "rb")
        local content = f and f:read("*a") or ""
        if f then f:close() end
        
        local cleanContent = content:gsub("\r", ""):gsub("%s+$", "")
        
        if sha256.hex(cleanContent) ~= fileInfo.sha256 then
            statusMessage = "Hash mismatch: " .. tostring(localPath or "???")
            errors = errors + 1
            break
        end
    end
    
    if errors == 0 then
        statusMessage = tostring(app.name or "App") .. ": Verified OK!"
        return true
    end
    return false
end

local function installApp(app)
    statusMessage = "Fetching manifest for " .. app.name .. "..."
    redrawAll()
    
    local manifestData = httpGet(app.manifest)
    if not manifestData then 
        statusMessage = "Failed to fetch manifest."
        redrawAll(); os.sleep(2); return 
    end
    
    local appManifest = serialization.unserialize(manifestData)
    if not appManifest or not appManifest.files then
        statusMessage = "Invalid app manifest!"
        redrawAll(); os.sleep(2); return
    end
    
    local appDir = "/apps/" .. app.name
    if not fs.exists(appDir) then fs.makeDirectory(appDir) end
    
    for localPath, fileInfo in pairs(appManifest.files) do
        statusMessage = "Downloading " .. fs.name(localPath) .. "..."
        redrawAll()
        
        local fileData = httpGet(fileInfo.url)
        if fileData then
            if sha256 and fileInfo.sha256 and fileInfo.sha256 ~= "" then
                local cleanContent = fileData:gsub("\r", ""):gsub("%s+$", "")
                if sha256.hex(cleanContent) ~= fileInfo.sha256 then
                    statusMessage = "Hash mismatch on " .. fs.name(localPath) .. "!"
                    redrawAll(); os.sleep(2); return
                end
            end
            
            local fullPath = appDir .. "/" .. localPath
            local dir = fs.path(fullPath)
            if not fs.exists(dir) then fs.makeDirectory(dir) end
            
            local f = io.open(fullPath, "w")
            f:write(fileData)
            f:close()
        else
            statusMessage = "Failed to download " .. fs.name(localPath)
            redrawAll(); os.sleep(2); return
        end
    end
    
    local installedData = loadInstalledData()
    installedData[app.name] = app
    saveInstalledData(installedData)
    
    statusMessage = app.name .. " installed!"
    updateInstalledApps()
    loadAvailableApps()
    redrawAll()
end

local function uninstallApp(app)
    local appDir = "/apps/" .. app.name
    if fs.exists(appDir) then
        fs.remove(appDir)
    end
    
    local installedData = loadInstalledData()
    installedData[app.name] = nil
    saveInstalledData(installedData)
    
    updateInstalledApps()
    loadAvailableApps()
    redrawAll()
end

local function drawButton(x, y, width, text, bg, fg, action)
    gpu.setBackground(bg)
    gpu.setForeground(fg)
    
    local padding = math.max(0, math.floor((width - #text) / 2))
    local btnStr = string.rep(" ", padding) .. text .. string.rep(" ", width - #text - padding)
    
    gpu.set(x, y, btnStr)
    
    table.insert(hitboxes, { x1 = x, x2 = x + width - 1, y1 = y, y2 = y, action = action })
    return x + width + 1
end

function redrawAll()
    statusMessage = tostring(statusMessage or "")
    hitboxes = {}
    
    gpu.setBackground(T.bg)
    gpu.fill(1, 1, w, h, " ")
    
    gpu.setBackground(T.header)
    gpu.fill(1, 1, w, 1, " ")
    gpu.setForeground(T.headerText)
    gpu.set(2, 1, "NgOS App Store")
    
    local listWidth = math.floor(w / 3)
    local middleLineY = math.floor(h / 2)
    local availableAppsListHeight = middleLineY - 3
    local installedAppsListHeight = h - middleLineY - 2

    gpu.setBackground(T.gray)
    gpu.fill(1, 2, listWidth, middleLineY - 2, " ")
    gpu.setForeground(T.white)
    gpu.set(2, 2, " Available Apps:")

    local currentList = availableApps
    local currentOffset = scrollOffsetAvailable
    local maxScroll = math.max(0, #currentList - availableAppsListHeight)
    
    for i = 1, availableAppsListHeight do
        local appIndex = i + currentOffset
        local y = 2 + i
        if currentList[appIndex] then
            local app = currentList[appIndex]
            gpu.setBackground((selectedSection == "available" and selectedIndex == appIndex) and T.accent or T.gray)
            gpu.setForeground((selectedSection == "available" and selectedIndex == appIndex) and T.bg or T.white)
            gpu.set(1, y, " " .. app.name .. string.rep(" ", listWidth - #app.name - 1))
            table.insert(hitboxes, {
                x1 = 1, x2 = listWidth, y1 = y, y2 = y,
                action = function() selectedSection = "available"; selectedIndex = appIndex; redrawAll() end
            })
        else
            gpu.setBackground(T.gray)
            gpu.set(1, y, string.rep(" ", listWidth))
        end
    end

    if #currentList > availableAppsListHeight then
        local arrowX = listWidth - 3
        drawButton(arrowX, 2, 2, "^", T.gray, T.white, function() 
            scrollOffsetAvailable = math.max(0, scrollOffsetAvailable - 1)
            redrawAll() 
        end)
        drawButton(arrowX, middleLineY - 2, 2, "v", T.gray, T.white, function() 
            scrollOffsetAvailable = math.min(maxScroll, scrollOffsetAvailable + 1)
            redrawAll() 
        end)
    end
    
    gpu.setBackground(T.header)
    gpu.fill(1, middleLineY, listWidth, 1, " ")
    gpu.setForeground(T.headerText)
    gpu.set(2, middleLineY, " Installed Apps:")

    gpu.setBackground(T.gray)
    gpu.fill(1, middleLineY + 1, listWidth, h - (middleLineY + 1) - 1, " ")
    
    currentList = installedApps
    currentOffset = scrollOffsetInstalled
    maxScroll = math.max(0, #currentList - installedAppsListHeight)

    for i = 1, installedAppsListHeight do
        local appIndex = i + currentOffset
        local y = middleLineY + 1 + i
        if currentList[appIndex] then
            local app = currentList[appIndex]
            gpu.setBackground((selectedSection == "installed" and selectedIndex == appIndex) and T.accent or T.gray)
            gpu.setForeground((selectedSection == "installed" and selectedIndex == appIndex) and T.bg or T.white)
            gpu.set(1, y, " " .. app.name .. string.rep(" ", listWidth - #app.name - 1))
            table.insert(hitboxes, {
                x1 = 1, x2 = listWidth, y1 = y, y2 = y,
                action = function() selectedSection = "installed"; selectedIndex = appIndex; redrawAll() end
            })
        else
            gpu.setBackground(T.gray)
            gpu.set(1, y, string.rep(" ", listWidth))
        end
    end

    if #currentList > installedAppsListHeight then
        local arrowX = listWidth - 3
        drawButton(arrowX, middleLineY + 1, 2, "^", T.gray, T.white, function() 
            scrollOffsetInstalled = math.max(0, scrollOffsetInstalled - 1)
            redrawAll() 
        end)
        drawButton(arrowX, h - 2, 2, "v", T.gray, T.white, function() 
            scrollOffsetInstalled = math.min(maxScroll, scrollOffsetInstalled + 1)
            redrawAll() 
        end)
    end

    local detailsX = listWidth + 2
    local activeApp = (selectedSection == "available") and availableApps[selectedIndex] or installedApps[selectedIndex]
    
    if activeApp then
        gpu.setBackground(T.bg)
        gpu.setForeground(T.accent)
        gpu.set(detailsX, 3, activeApp.name)
        
        if selectedSection == "installed" then
            gpu.setForeground(T.gray)
            gpu.set(detailsX, 4, "Version: (Local)") 
            gpu.setForeground(T.text)
            gpu.set(detailsX, 6, "App is installed.")
        else
            gpu.setForeground(T.gray)
            gpu.set(detailsX, 4, "Version: " .. (activeApp.version or "N/A")) 
            
            gpu.setForeground(T.text)
            local descY = 6
            local descText = activeApp.desc or "No description."
            for line in descText:gmatch("([^\n]+)") do
                gpu.set(detailsX, descY, line)
                descY = descY + 1
            end
        end
        
        gpu.setForeground(T.text)
        
        local descY = 6 
        local descText = activeApp.desc or "No description."
        for line in descText:gmatch("([^\n]+)") do
            gpu.set(detailsX, descY, line)
            descY = descY + 1
        end

        local buttonY = math.max(descY + 2, middleLineY + 3)

        local isActuallyInstalled = fs.exists("/apps/" .. activeApp.name .. "/app.lua")
        if selectedSection == "installed" or isActuallyInstalled then
            drawButton(detailsX, buttonY, 14, "Verify", T.accent, T.bg, function() 
                local ok, msg = verifyApp(activeApp)
                statusMessage = msg
                redrawAll()
            end)
            drawButton(detailsX + 16, buttonY, 14, "Uninstall", T.err, T.white, function() uninstallApp(activeApp); redrawAll() end)
        else
            drawButton(detailsX, buttonY, 14, "Install", T.accent, T.bg, function() installApp(activeApp); redrawAll() end)
        end
    end
    
    gpu.setBackground(T.header)
    gpu.fill(1, h, w, 1, " ")
    gpu.setForeground(T.text)
    gpu.set(2, h, statusMessage)
end

redrawAll()
loadAvailableApps()
updateInstalledApps()
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
        loadAvailableApps()
        updateInstalledApps()
        redrawAll()
    end
end