local sha256 = require("ngos.lib.sha256")
local DIGEST_FILE = "/etc/system.digest"

local criticalFiles = {
    "/startup.lua",
    "/ngos/system/kernel.lua",
    "/ngos/system/security.lua",
    "/ngos/system/theme.lua",
    "/ngos/bin/desktop.lua",
    "/ngos/bin/store.lua",
    "/ngos/bin/settings.lua",
    "/ngos/bin/updater.lua",
    "/ngos/bin/gen_digest.lua"
}

term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1,1)
print("Generating System Digest...")

local digest = {}

for _, path in ipairs(criticalFiles) do
    write("Hashing " .. fs.getName(path) .. "... ")
    
    if fs.exists(path) then
        local f = fs.open(path, "rb")
        local content = f.readAll()
        f.close()
        
        local cleanContent = content:gsub("\r", "")
        digest[path] = sha256.hex(cleanContent)
        print("OK")
    else
        term.setTextColor(colors.red)
        print("MISSING")
        term.setTextColor(colors.white)
    end
end

local f = fs.open(DIGEST_FILE, "w")
f.write(textutils.serializeJSON(digest))
f.close()

term.setTextColor(colors.lime)
print("\nDigest saved to " .. DIGEST_FILE)
term.setTextColor(colors.white)
sleep(2)