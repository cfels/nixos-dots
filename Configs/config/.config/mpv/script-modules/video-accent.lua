local function extract(frame)
    if type(frame) ~= "table" or frame.format ~= "bgr0" or type(frame.data) ~= "string"
        or not frame.w or not frame.h or not frame.stride or frame.w < 1 or frame.h < 1
        or frame.stride < frame.w * 4 or #frame.data < frame.stride * frame.h then
        return nil
    end

    -- A small grid and coarse color buckets keep sampling independent of video resolution.
    local buckets = {}
    local best
    for row = 0, 17 do
        local y = math.floor((row + 0.5) * frame.h / 18)
        for column = 0, 31 do
            local x = math.floor((column + 0.5) * frame.w / 32)
            local b, g, r = frame.data:byte(y * frame.stride + x * 4 + 1, y * frame.stride + x * 4 + 3)
            local high, low = math.max(r, g, b), math.min(r, g, b)
            -- Ignore letterboxing and white highlights; favor colors over gray backgrounds.
            if high >= 32 and low <= 224 then
                local key = math.floor(r / 32) * 64 + math.floor(g / 32) * 8 + math.floor(b / 32)
                local bucket = buckets[key]
                if not bucket then
                    bucket = {r = 0, g = 0, b = 0, count = 0, weight = 0}
                    buckets[key] = bucket
                end
                bucket.r = bucket.r + r
                bucket.g = bucket.g + g
                bucket.b = bucket.b + b
                bucket.count = bucket.count + 1
                bucket.weight = bucket.weight + 0.2 + (high - low) / high
            end
        end
    end
    for _, bucket in pairs(buckets) do
        if not best or bucket.weight > best.weight then best = bucket end
    end
    if not best then return nil end

    local r, g, b = best.r / best.count, best.g / best.count, best.b / best.count
    local high = math.max(r, g, b)
    -- Keep the accent readable against the dark glass without changing its hue.
    local scale = math.max(170, math.min(235, high)) / high
    r, g, b = r * scale, g * scale, b * scale
    local function color(factor, white)
        return string.format("#%02X%02X%02X", math.floor(r * factor + white + 0.5),
            math.floor(g * factor + white + 0.5), math.floor(b * factor + white + 0.5))
    end
    local accent = color(1, 0)
    return {
        seekbarfg_color = accent,
        seekbarbg_color = color(0.4, 0),
        seek_handle_color = accent,
        seek_handle_border_color = color(0.65, 255 * 0.35),
    }
end

return extract
