-- Pure game rules. No Roblox services; also exercised by tests/rules_test.lua.
local Rules = {}

function Rules.new(required)
    return {stage = "Idle", fuses = {}, count = 0, required = required or 3,
        powered = false, hasKey = false, gateOpen = false, elapsed = 0}
end

function Rules.start(s)
    if s.stage ~= "Idle" then return false end
    s.stage = "Fuses"
    return true
end

function Rules.collect(s, id)
    if s.stage ~= "Fuses" or type(id) ~= "string" or s.fuses[id] then return false end
    s.fuses[id] = true
    s.count = s.count + 1
    if s.count >= s.required then s.stage = "Generator" end
    return true
end

function Rules.power(s)
    if s.stage ~= "Generator" or s.count < s.required then return false end
    s.powered = true
    s.stage = "Key"
    return true
end

function Rules.key(s)
    if s.stage ~= "Key" or not s.powered then return false end
    s.hasKey = true
    s.stage = "Gate"
    return true
end

function Rules.gate(s)
    if s.stage ~= "Gate" or not s.hasKey then return false end
    s.gateOpen = true
    s.stage = "Escape"
    return true
end

function Rules.isRunning(s)
    return s.stage ~= "Idle" and s.stage ~= "Ended"
end

function Rules.tick(s, dt, limit)
    if not Rules.isRunning(s) then return false end
    s.elapsed = s.elapsed + math.max(0, dt)
    if s.elapsed >= limit then
        s.stage = "Ended"
        s.reason = "timeout"
        return true
    end
    return false
end

function Rules.finish(s, reason)
    if s.stage == "Idle" or s.stage == "Ended" then return false end
    s.stage = "Ended"
    s.reason = reason
    return true
end

function Rules.snapshot(s, limit)
    return {stage = s.stage, count = s.count, required = s.required,
        powered = s.powered, gateOpen = s.gateOpen,
        seconds = math.max(0, math.ceil(limit - s.elapsed))}
end

return Rules
