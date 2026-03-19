local component = require("component")
local fs = require("filesystem")
local serialization = require("serialization")
local gpu = component.gpu

local theme = {}
theme.colors = {}

local palettes = {
    high = {
        dark = {
            bg = 0x1E1E2E, header = 0x11111B, headerText = 0xCBA6F7,
            accent = 0x89B4FA, text = 0xCDD6F4, warn = 0xF9E2AF,
            err = 0xF38BA8, black = 0x000000, white = 0xFFFFFF, gray = 0x45475A
        },
        light = {
            bg = 0xEFF1F5, header = 0xDCE0E8, headerText = 0x1E66F5,
            accent = 0x7287FD, text = 0x4C4F69, warn = 0xDF8E1D,
            err = 0xD20F39, black = 0x000000, white = 0xFFFFFF, gray = 0x9CA0B0
        },
        ocean = {
            bg = 0x0F1C2E, header = 0x07111A, headerText = 0x00FFFF,
            accent = 0x3A86FF, text = 0xE0FBFC, warn = 0xFFD166,
            err = 0xEF476F, black = 0x000000, white = 0xFFFFFF, gray = 0x3D5A80
        }
    },
    low = {
        dark = {
            bg = 0x000000, header = 0x333333, headerText = 0x00FFFF,
            accent = 0x0000FF, text = 0xFFFFFF, warn = 0xFFFF00,
            err = 0xFF0000, black = 0x000000, white = 0xFFFFFF, gray = 0x555555
        },
        light = {
            bg = 0xFFFFFF, header = 0xCCCCCC, headerText = 0x0000FF,
            accent = 0x3333FF, text = 0x000000, warn = 0xFF9900,
            err = 0xFF0000, black = 0x000000, white = 0xFFFFFF, gray = 0x999999
        },
        ocean = {
            bg = 0x000000, header = 0x333333, headerText = 0x00FFFF,
            accent = 0x0000FF, text = 0xFFFFFF, warn = 0xFFFF00,
            err = 0xFF0000, black = 0x000000, white = 0xFFFFFF, gray = 0x555555
        }
    }
}

function theme.load()
    local cfg = { name = "dark", quality = "low" } 
    
    if fs.exists("/etc/theme.cfg") then
        local f = io.open("/etc/theme.cfg", "r")
        local data = serialization.unserialize(f:read("*a"))
        f:close()
        if data then
            cfg.name = data.name or cfg.name
            cfg.quality = data.quality or cfg.quality
        end
    end

    local screenDepth = gpu.maxDepth()
    
    local useHigh = (cfg.quality == "high") and (screenDepth > 4)
    local activeCategory = useHigh and palettes.high or palettes.low
    
    local activePalette = activeCategory[cfg.name] or activeCategory["dark"]

    for k, v in pairs(activePalette) do
        theme.colors[k] = v
    end
    
    theme.currentName = cfg.name
    theme.currentQuality = useHigh and "high" or "low"
end

function theme.save(newName, newQuality)
    local cfg = { name = newName, quality = newQuality }
    local f = io.open("/etc/theme.cfg", "w")
    f:write(serialization.serialize(cfg))
    f:close()
    theme.load()
end

return theme