_G.unpack = _G.unpack or table.unpack

package.path = package.path .. ";/?.lua;/ngos/system/?.lua;/ngos/lib/?.lua"

local computer = require("computer")
local component = require("component")
local fs = require("filesystem")
local serialization = require("serialization")

local gpu = component.gpu
local w, h = gpu.getResolution()

package.path = package.path .. ";/?.lua"

_G.ngos = {}

local function loadOSVersion()
    if fs.exists("/etc/os.info") then
        local f = io.open("/etc/os.info", "r")
        local content = f:read("*a")
        f:close()
        local data = serialization.unserialize(content)
        return data and data.version or "Unknown"
    end
    return "Dev Build"
end

_G.ngos.version = loadOSVersion()

local themeLib = dofile("/ngos/system/theme.lua")
themeLib.load()
_G.ngos.themeLib = themeLib
_G.ngos.theme = themeLib.colors 

local sec = dofile("/ngos/system/security.lua")
sec.checkIntegrity()
sec.bootLogin()

local processes = {}
local pidCounter = 1
local activeProcess = nil
local isTaskSwitcherOpen = false
local desktopRoutine = nil

local function getAppName(path)
    local parts = {}
    for part in path:gmatch("[^/]+") do
        table.insert(parts, part)
    end

    local fileName = parts[#parts] or "Unknown"

    if fileName == "app.lua" and #parts >= 2 then
        return parts[#parts - 1]
    end

    return fileName:gsub("%.lua$", "")
end

local function killProcess(proc)
    for i, p in ipairs(processes) do
        if p == proc then
            table.remove(processes, i);
            break
        end
    end
    if activeProcess == proc then
        activeProcess = nil
    end
end

local function drawOverlay()
    local T = _G.ngos.theme

    if activeProcess then
        gpu.setBackground(T.warn)
        gpu.setForeground(T.black)
        gpu.set(w - 1, 1, "_")

        gpu.setBackground(T.err)
        gpu.setForeground(T.white)
        gpu.set(w, 1, "X")
    elseif #processes > 0 and not isTaskSwitcherOpen then
        gpu.setBackground(T.accent)
        gpu.setForeground(T.white)
        gpu.set(w, 1, "^")
    end

    if isTaskSwitcherOpen then
        local boxW = 24
        local boxH = #processes + 2
        local startX = math.floor((w - boxW) / 2)
        local startY = math.floor((h - boxH) / 2)

        gpu.setBackground(T.header)
        gpu.fill(startX, startY, boxW, boxH, " ")

        gpu.setBackground(T.accent)
        gpu.setForeground(T.bg)
        local title = " Running Apps"
        gpu.set(startX, startY, title .. string.rep(" ", boxW - string.len(title) - 1))

        gpu.setBackground(T.err)
        gpu.setForeground(T.white)
        gpu.set(startX + boxW - 1, startY, "X")

        for i, proc in ipairs(processes) do
            local lineY = startY + i
            gpu.setBackground(T.header)
            gpu.setForeground(T.text)

            gpu.set(startX + 1, lineY, getAppName(proc.path))

            gpu.setForeground(T.warn)
            gpu.set(startX + boxW - 2, lineY, "x")
        end
    end
end

local function loadDesktop()
    local path = "/ngos/bin/desktop.lua"
    if not fs.exists(path) then
        return nil
    end

    local env = setmetatable({
        _G = _G
    }, {
        __index = _G
    })

    local fn, err = loadfile(path, "t", env)

    if not fn then
        gpu.set(1, 20, "Load Error: " .. tostring(err))
        return nil
    end

    return coroutine.create(fn)
end

local function launchApp(path)
    local myPid = pidCounter
    pidCounter = pidCounter + 1

    local env = setmetatable({
        _G = _G,
        require = require,
        os = os,
        io = io,
        table = table,
        math = math,
        string = string,
        component = component,
        computer = computer,
        ngos = _G.ngos
    }, {
        __index = _G
    })

    local fn, err = loadfile(path, "t", env)

    if not fn then
        return nil, err
    end

    local proc = {
        pid = myPid,
        routine = coroutine.create(fn),
        path = path
    }
    table.insert(processes, proc)
    return proc
end

desktopRoutine = loadDesktop()

gpu.setBackground(_G.ngos.theme.bg)
gpu.fill(1, 1, w, h, " ")

if desktopRoutine then
    local ok, err = coroutine.resume(desktopRoutine)
    if not ok then
        gpu.set(1, 1, "Desktop Error: " .. tostring(err))
    end
end

while true do
    drawOverlay()
    local eventData = {computer.pullSignal(0.1)}
    local ev = eventData[1]
    local handled = false

    if ev == "touch" then
        local x, y = eventData[3], eventData[4]

        if isTaskSwitcherOpen then
            local boxW = 24
            local boxH = #processes + 2
            local startX = math.floor((w - boxW) / 2)
            local startY = math.floor((h - boxH) / 2)

            if x >= startX and x <= startX + boxW and y >= startY and y <= startY + boxH then
                if y == startY and x >= startX + boxW - 1 then
                    isTaskSwitcherOpen = false
                    gpu.setBackground(_G.ngos.theme.bg)
                    gpu.fill(1, 1, w, h, " ")
                    if activeProcess then coroutine.resume(activeProcess.routine, "refresh")
                    elseif desktopRoutine then coroutine.resume(desktopRoutine, "refresh") end
                else
                    local row = y - startY
                    if row > 0 and row <= #processes then
                        local proc = processes[row]
                        if x >= startX + boxW - 2 then
                            killProcess(proc)
                            if #processes == 0 then
                                isTaskSwitcherOpen = false
                            end
                            gpu.setBackground(_G.ngos.theme.bg)
                            gpu.fill(1, 1, w, h, " ")

                            if activeProcess then coroutine.resume(activeProcess.routine, "refresh")
                            elseif desktopRoutine then coroutine.resume(desktopRoutine, "refresh") end
                        else
                            isTaskSwitcherOpen = false
                            activeProcess = proc
                            gpu.setBackground(_G.ngos.theme.bg)
                            gpu.fill(1, 1, w, h, " ")
                            coroutine.resume(activeProcess.routine, "refresh")
                        end
                    end
                end
                handled = true
            else
                isTaskSwitcherOpen = false
                gpu.setBackground(_G.ngos.theme.bg)
                gpu.fill(1, 1, w, h, " ")

                if activeProcess then coroutine.resume(activeProcess.routine, "refresh")
                elseif desktopRoutine then coroutine.resume(desktopRoutine, "refresh") end

                handled = true
            end

        elseif y == 1 then
            if x == w and activeProcess then
                killProcess(activeProcess)
                gpu.setBackground(_G.ngos.theme.bg)
                gpu.fill(1, 1, w, h, " ")
                if desktopRoutine then
                    coroutine.resume(desktopRoutine, "refresh")
                end
                handled = true

            elseif x == w - 1 and activeProcess then
                activeProcess = nil
                gpu.setBackground(_G.ngos.theme.bg)
                gpu.fill(1, 1, w, h, " ")
                if desktopRoutine then
                    coroutine.resume(desktopRoutine, "refresh")
                end
                handled = true

            elseif x == w and not activeProcess and #processes > 0 then
                isTaskSwitcherOpen = true
                handled = true
            end
        end

    elseif ev == "ngos_launch" then
        isTaskSwitcherOpen = false
        local proc = launchApp(eventData[2])
        if proc then
            activeProcess = proc
            gpu.setBackground(_G.ngos.theme.bg)
            gpu.fill(1, 1, w, h, " ")
            
            local ok, err = coroutine.resume(activeProcess.routine)
            if not ok then
                gpu.setBackground(_G.ngos.theme.err)
                gpu.fill(1, 1, w, h, " ")
                gpu.setForeground(_G.ngos.theme.white)
                gpu.set(1, 1, "Launch Error: " .. tostring(err))
                os.sleep(3)
                killProcess(activeProcess)
                gpu.setBackground(_G.ngos.theme.bg)
                gpu.fill(1, 1, w, h, " ")
                if desktopRoutine then
                    coroutine.resume(desktopRoutine, "refresh")
                end
            end
        end
        handled = true
    end

    if not handled and ev then
        if activeProcess then
            local ok, err = coroutine.resume(activeProcess.routine, table.unpack(eventData))

            if not ok or coroutine.status(activeProcess.routine) == "dead" then
                if not ok then
                    gpu.setBackground(themeLib.colors.err)
                    gpu.fill(1, 1, w, h, " ")
                    gpu.setForeground(themeLib.colors.white)
                    gpu.set(1, 1, "App Crashed: " .. tostring(err))
                    os.sleep(3)
                end
                killProcess(activeProcess)
                gpu.setBackground(_G.ngos.theme.bg)
                gpu.fill(1, 1, w, h, " ")
                if desktopRoutine then
                    coroutine.resume(desktopRoutine, "refresh")
                end
            end
        else
            if desktopRoutine then
                local ok, err = coroutine.resume(desktopRoutine, table.unpack(eventData))
                if not ok then
                    gpu.set(1, 1, "Desktop Error: " .. tostring(err))
                end
            end
        end
    end
end