local bit = bit32 or require("bit")
local band, bor, bxor = bit.band, bit.bor, bit.bxor
local rshift, lshift, rrotate = bit.rshift, bit.lshift, bit.rrotate

if not rrotate then
    rrotate = function(x, n)
        return bor(rshift(x, n), lshift(x, 32 - n))
    end
end

local K = {
   0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
   0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
   0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
   0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
   0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
   0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
   0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
   0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
}

local function preproc(msg, len_in_bits)
    local extra = 64 - ((#msg + 9) % 64)
    local len_bytes = math.floor(extra) % 64
    
    msg = msg .. "\128" .. string.rep("\0", len_bytes)

    local high = math.floor(len_in_bits / 4294967296)
    local low = len_in_bits % 4294967296
    
    for i = 3, 0, -1 do
        msg = msg .. string.char(band(rshift(high, i*8), 0xFF))
    end
    
    for i = 3, 0, -1 do
        msg = msg .. string.char(band(rshift(low, i*8), 0xFF))
    end
    
    return msg
end

local function digest(msg)
    local H = {
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    }

    msg = preproc(msg, #msg * 8)

    local W = {}
    
    for i = 1, #msg, 64 do
        local chunk = msg:sub(i, i + 63)
        
        for j = 0, 15 do
            local pos = j * 4 + 1
            local a, b, c, d = string.byte(chunk, pos, pos + 3)
            W[j] = bor(lshift(a, 24), lshift(b, 16), lshift(c, 8), d)
        end
        
        for j = 16, 63 do
            local s0 = bxor(rrotate(W[j-15], 7), rrotate(W[j-15], 18), rshift(W[j-15], 3))
            local s1 = bxor(rrotate(W[j-2], 17), rrotate(W[j-2], 19), rshift(W[j-2], 10))
            W[j] = (W[j-16] + s0 + W[j-7] + s1) % 4294967296
        end

        local a, b, c, d, e, f, g, h = unpack(H)

        for j = 0, 63 do
            local S1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
            local ch = bxor(band(e, f), band(bxor(e, 0xFFFFFFFF), g))
            local temp1 = (h + S1 + ch + K[j+1] + W[j]) % 4294967296
            local S0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
            local maj = bxor(band(a, b), band(a, c), band(b, c))
            local temp2 = (S0 + maj) % 4294967296

            h = g
            g = f
            f = e
            e = (d + temp1) % 4294967296
            d = c
            c = b
            b = a
            a = (temp1 + temp2) % 4294967296
        end

        H[1] = (H[1] + a) % 4294967296
        H[2] = (H[2] + b) % 4294967296
        H[3] = (H[3] + c) % 4294967296
        H[4] = (H[4] + d) % 4294967296
        H[5] = (H[5] + e) % 4294967296
        H[6] = (H[6] + f) % 4294967296
        H[7] = (H[7] + g) % 4294967296
        H[8] = (H[8] + h) % 4294967296
    end

    local result = ""
    for i = 1, 8 do
        result = result .. string.format("%08x", H[i])
    end
    return result
end

return { hex = digest }