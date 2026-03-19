local component = require("component")
local computer = require("computer")
local fs = require("filesystem")

local gpu = component.gpu
local w, h = gpu.getResolution()

local sec = dofile("/ngos/system/security.lua")
local themeLib = dofile("/ngos/system/theme.lua")

local currentStyle = themeLib.currentName or "dark"
local currentQuality = themeLib.currentQuality or "low"

local hitboxes = {}

local function drawButton(x, y, text, isSelected, onClick, overrideBg)
    local T = _G.ngos.theme
    local bg = overrideBg or (isSelected and T.accent or T.header)
    local fg = isSelected and T.bg or T.text
    
    gpu.setBackground(bg)
    gpu.setForeground(fg)
    local btnText = " " .. text .. " "
    gpu.set(x, y, btnText)
    
    table.insert(hitboxes, {
        x1 = x, x2 = x + #btnText - 1,
        y1 = y, y2 = y,
        action = onClick
    })
    return x + #btnText + 1
end

local function draw()
    hitboxes = {}
    local T = _G.ngos.theme
    
    gpu.setBackground(T.bg)
    gpu.fill(1, 1, w, h, " ")
    
    gpu.setBackground(T.bg)
    gpu.setForeground(T.accent)
    gpu.set(2, 1, "System Settings")

    gpu.setForeground(T.text)
    gpu.set(3, 3, "1. System Updates")
    drawButton(4, 4, "Check for Updates", false, function()
        if fs.exists("/ngos/bin/updater.lua") then
            dofile("/ngos/bin/updater.lua")
            draw()
        else
            gpu.setBackground(T.warn)
            gpu.setForeground(T.black)
            gpu.set(25, 4, " Updater not installed! ")
            os.sleep(1.5)
            draw()
        end
    end)

    local secStatus = sec.isEnabled() and "Enabled" or "Disabled"
    gpu.setBackground(T.bg)
    gpu.setForeground(T.text)
    gpu.set(3, 6, "2. Secure Boot (Status: " .. secStatus .. ")")
    
    local secText = sec.isEnabled() and "Disable Protection" or "Enable Protection"
    drawButton(4, 7, secText, false, function()
        if sec.isEnabled() then 
            sec.disableProtection() 
        else 
            sec.enableProtection() 
        end
        draw()
    end)

    local depth = gpu.maxDepth()
    local tierStr = (depth >= 8) and "Tier 3 (24-bit)" or (depth == 4 and "Tier 2 (16-color)" or "Tier 1 (B&W)")
    
    gpu.setBackground(T.bg)
    gpu.setForeground(T.text)
    gpu.set(3, 9, "3. Theme & Display [Hardware: " .. tierStr .. "]")
    
    gpu.set(4, 10, "Style:")
    local nx = 11
    nx = drawButton(nx, 10, "Dark", currentStyle == "dark", function() changeTheme("dark", currentQuality) end)
    nx = drawButton(nx, 10, "Light", currentStyle == "light", function() changeTheme("light", currentQuality) end)
    drawButton(nx, 10, "Ocean", currentStyle == "ocean", function() changeTheme("ocean", currentQuality) end)
    
    gpu.setBackground(T.bg)
    gpu.setForeground(T.text)
    gpu.set(4, 12, "Quality:")
    nx = drawButton(13, 12, "Low (16-color)", currentQuality == "low", function() changeTheme(currentStyle, "low") end)
    
    if depth >= 8 then
        drawButton(nx, 12, "High (24-bit)", currentQuality == "high", function() changeTheme(currentStyle, "high") end)
    else
        gpu.setBackground(T.bg)
        gpu.setForeground(T.gray)
        gpu.set(nx, 12, "[High (Requires T3 Screen)]")
    end

    drawButton(3, 15, "Reboot PC", false, function() 
        gpu.setBackground(0x000000)
        gpu.fill(1, 1, w, h, " ")
        computer.shutdown(true) 
    end, T.err)
end

function changeTheme(newStyle, newQuality)
    themeLib.save(newStyle, newQuality)
    
    currentStyle = themeLib.currentName
    currentQuality = themeLib.currentQuality
    draw()
end

draw()

while true do
    local eventData = { coroutine.yield() }
    local ev = eventData[1]
    
    if ev == "touch" then
        local x, y = eventData[3], eventData[4]
        
        for _, box in ipairs(hitboxes) do
            if x >= box.x1 and x <= box.x2 and y >= box.y1 and y <= box.y2 then
                gpu.setBackground(_G.ngos.theme.warn)
                gpu.setForeground(_G.ngos.theme.black)
                gpu.set(box.x1, box.y1, string.rep(" ", box.x2 - box.x1 + 1))
                os.sleep(0.1)
                
                box.action()
                break
            end
        end
    end
end