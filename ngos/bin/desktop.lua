local component = require("component")
local computer = require("computer")
local fs = require("filesystem")

local gpu = component.gpu
local w, h = gpu.getResolution()

local T = _G.ngos.theme

local apps = {}

local function loadApps()
    apps = {}
    if not fs.exists("/apps") then return end
    
    for file in fs.list("/apps") do
        if file:sub(-1) == "/" then
            local appName = file:sub(1, -2)
            local execPath = "/apps/" .. file .. "app.lua"
            
            if fs.exists(execPath) then
                table.insert(apps, {
                    name = appName,
                    path = execPath,
                    icon = string.sub(appName, 1, 1):upper()
                })
            end
        end
    end
end

local function drawDesktop()
    gpu.setBackground(T.bg)
    gpu.fill(1, 1, w, h, " ")

    gpu.setBackground(T.header)
    gpu.fill(1, 1, w, 1, " ")
    
    gpu.setForeground(T.headerText)
    gpu.set(2, 1, "NgOS " .. tostring(_G.ngos.version))
    
    gpu.setForeground(T.gray)
    local timeStr = os.date("%H:%M")
    gpu.set(w - 10, 1, timeStr)

    local startX = 4
    local startY = 4
    local iconSpacingX = 12
    local iconSpacingY = 5

    for i, app in ipairs(apps) do
        gpu.setBackground(T.accent)
        gpu.setForeground(T.bg)
        gpu.set(startX + 1, startY, " " .. app.icon .. " ")
        
        gpu.setBackground(T.bg)
        gpu.setForeground(T.text)
        
        local displayName = app.name
        if #displayName > 8 then displayName = displayName:sub(1, 6) .. ".." end
        
        gpu.set(startX, startY + 1, displayName)

        app.hitbox = {
            minX = startX,
            maxX = startX + 5,
            minY = startY,
            maxY = startY + 1
        }

        startX = startX + iconSpacingX
        if startX + 8 > w then
            startX = 4
            startY = startY + iconSpacingY
        end
    end
end

loadApps()
drawDesktop()

while true do
    local eventData = { coroutine.yield() }
    local ev = eventData[1]

    if ev == "touch" then
        local x, y = eventData[3], eventData[4]
        
        for _, app in ipairs(apps) do
            if x >= app.hitbox.minX and x <= app.hitbox.maxX and 
               y >= app.hitbox.minY and y <= app.hitbox.maxY then
                
                gpu.setBackground(T.warn)
                gpu.setForeground(T.black)
                gpu.set(app.hitbox.minX + 1, app.hitbox.minY, " " .. app.icon .. " ")
                os.sleep(0.1)
                
                computer.pushSignal("ngos_launch", app.path)
            end
        end
        
    elseif ev == "refresh" then
        loadApps()
        drawDesktop()
    end
end