-- Joud / Majnoonat Al Hara. Server owns progression, interactions and AI.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local shared = ReplicatedStorage:WaitForChild("HaraShared")
local Config = require(shared:WaitForChild("Config"))
local Rules = require(shared:WaitForChild("Rules"))
local Fun = require(shared:WaitForChild("Fun"))
local Signs = require(shared:WaitForChild("Signs"))
local event = Instance.new("RemoteEvent")
event.Name = "HaraEvent"
event.Parent = shared

local world = workspace:WaitForChild("Hara")
local objects = world:WaitForChild("Interactables")
local joud = world:WaitForChild("Joud")
local jroot = joud:WaitForChild("HumanoidRootPart")
local jhuman = joud:WaitForChild("Humanoid")
local sessions = {}
local state = Rules.new(Config.FuseCount)
local roundToken = 0
local hideOwners = {}
local gateFrames = {}
local artTransparency = {}
local ai = {lastCalc = 0, pathToken = 0, index = 1, points = {}, patrol = 1,
    lastSeen = 0, busy = false, mood = "Idle", stunUntil = 0, tiedUntil = 0, rageUntil = 0}
local patrol = world.Markers.Patrol:GetChildren()
for _, marker in ipairs(world.Architecture.RestHouse.Patrol:GetChildren()) do
    table.insert(patrol, marker)
end
local okFun, funError = pcall(Fun.Build, world)
if not okFun then warn("[Fun] " .. tostring(funError)) end
local okSigns, signsError = pcall(Signs.Apply, world)
if not okSigns then warn("[Signs] " .. tostring(signsError)) end
table.sort(patrol, function(a,b) return a.Name < b.Name end)

-- Recreate cosmetic welds while the rig is anchored. This captures the authored
-- offsets even when an XML importer normalizes internal constraint properties.
for _, part in ipairs(joud:GetChildren()) do
    if part:IsA("BasePart") then
        local owner = part:FindFirstChild("AttachTo")
        if owner then
            local old = part:FindFirstChild("Attachment")
            if old then old:Destroy() end
            local weld = Instance.new("WeldConstraint")
            weld.Name = "Attachment"
            weld.Part0 = joud:WaitForChild(owner.Value)
            weld.Part1 = part
            weld.Parent = part
        end
    end
end
for _, p in ipairs(joud:GetDescendants()) do
    if p:IsA("BasePart") then p.Anchored = false end
end
jroot:SetNetworkOwner(nil)
jroot.Anchored = true
jhuman.WalkSpeed = 0
for _, part in ipairs(objects.ExitGate:GetDescendants()) do
    if part:IsA("BasePart") then gateFrames[part] = part.CFrame end
end
for _, group in ipairs({objects.Fuses, objects.Key}) do
    for _, part in ipairs(group:GetDescendants()) do
        if part:IsA("BasePart") then artTransparency[part] = part.Transparency end
    end
end

local function send(player, kind, payload)
    if player.Parent == Players then event:FireClient(player, kind, payload) end
end
local function toast(player, text) send(player, "Toast", text) end
local function announce(text) event:FireAllClients("Toast", text) end
local function broadcast() event:FireAllClients("State", Rules.snapshot(state, Config.RoundSeconds)) end
local function body(player)
    local character = player.Character
    if not character then return nil, nil end
    return character:FindFirstChild("HumanoidRootPart"), character:FindFirstChildOfClass("Humanoid")
end
local function inside(position, center, half)
    local d = position - center
    return math.abs(d.X) <= half.X and math.abs(d.Y) <= half.Y and math.abs(d.Z) <= half.Z
end
local function isSafe(position) return inside(position, Config.SafeCenter, Config.SafeHalf) end
local function rayClear(origin, destination, ignored)
    local delta = destination - origin
    if delta.Magnitude < 0.01 then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignored
    return workspace:Raycast(origin, delta, params) == nil
end
local function canInteract(player, part, distance)
    local session = sessions[player]
    local root, human = body(player)
    if not session or not session.active or session.hidden or not Rules.isRunning(state) then return false end
    if not root or not human or human.Health <= 0 or os.clock() < (session.capturedUntil or 0) then return false end
    if (root.Position - part.Position).Magnitude > (distance or 11) then return false end
    return rayClear(root.Position + Vector3.new(0,1,0), part.Position,
        {player.Character, part.Parent, joud, world.Markers})
end
local function showCollectible(model, visible)
    for _, item in ipairs(model:GetDescendants()) do
        if item:IsA("BasePart") then item.Transparency = visible and (artTransparency[item] or 0) or 1 end
        if item:IsA("Light") or item:IsA("ProximityPrompt") then item.Enabled = visible end
    end
end
local function profile(player)
    local s = sessions[player]
    if not s then return end
    send(player, "Profile", {active = s.active, lives = math.max(0, Config.MaxCatches - s.catches),
        stamina = math.floor(s.stamina), hidden = s.hidden ~= nil,
        hideSeconds = s.hidden and math.max(0, math.ceil(s.hideUntil - os.clock())) or 0,
        rope = player:GetAttribute("HasRope") == true, sweets = s.sweets or 0})
end
local function leaveHide(player, silent)
    local s = sessions[player]
    if not s or not s.hidden then return end
    local locker = s.hidden
    hideOwners[locker] = nil
    s.hidden = nil
    s.hideCooldown = os.clock() + 2
    local root = body(player)
    if root then
        root.CFrame = locker.Exit.CFrame
        root.Anchored = false
    end
    if not silent then toast(player, "طلعت من المخبأ… انتبه") end
    profile(player)
end

---------------------------------------------------------------- الحبل والحلاوة
local pickups = Instance.new("Folder")
pickups.Name = "Pickups"
pickups.Parent = world
local rope = {part = nil, holder = nil, nextSpawn = math.huge, bands = {}}
local spots = {}
for _, marker in ipairs(patrol) do table.insert(spots, marker.Position) end

local function clearRopePickup()
    if rope.part then rope.part:Destroy(); rope.part = nil end
end

local function dropRope(player)
    if rope.holder == player then
        rope.holder = nil
        player:SetAttribute("HasRope", false)
        rope.nextSpawn = os.clock() + Config.RopeRespawn
    end
end

local function spawnRope()
    clearRopePickup()
    local candidates = {}
    for _, p in ipairs(spots) do
        if (p - jroot.Position).Magnitude > 40 and not isSafe(p) then table.insert(candidates, p) end
    end
    if #candidates == 0 then candidates = spots end
    local p = candidates[math.random(1, #candidates)]
    local coil = Instance.new("Part")
    coil.Name = "Rope"
    coil.Shape = Enum.PartType.Cylinder
    coil.Size = Vector3.new(0.9, 2.8, 2.8)
    coil.CFrame = CFrame.new(p.X, 0.7, p.Z) * CFrame.Angles(0, 0, math.rad(90))
    coil.Color = Color3.fromRGB(196, 150, 92)
    coil.Material = Enum.Material.Fabric
    coil.Anchored, coil.CanCollide = true, false
    local glow = Instance.new("PointLight")
    glow.Color, glow.Range, glow.Brightness = Color3.fromRGB(255, 210, 140), 10, 1.2
    glow.Parent = coil
    local tag = Instance.new("BillboardGui")
    tag.Size, tag.StudsOffset, tag.AlwaysOnTop, tag.MaxDistance = UDim2.fromOffset(90, 36), Vector3.new(0, 3, 0), true, 70
    tag.Parent = coil
    local t = Instance.new("TextLabel")
    t.Size, t.BackgroundTransparency, t.TextScaled = UDim2.fromScale(1, 1), 1, true
    t.Text, t.TextColor3, t.TextStrokeTransparency = "🪢 حبل", Color3.fromRGB(255, 230, 170), 0.4
    t.Parent = tag
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText, prompt.ObjectText = "خذ الحبل", "حبل"
    prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 0.3, 9, false
    prompt.Parent = coil
    prompt.Triggered:Connect(function(player)
        if rope.part ~= coil or rope.holder or not canInteract(player, coil, 10) then return end
        rope.holder = player
        player:SetAttribute("HasRope", true)
        clearRopePickup()
        toast(player, "معك حبل! قرّب من جود واضغط Q أو زر «اربط»")
        for other in pairs(sessions) do
            if other ~= player then toast(other, player.DisplayName .. " أخذ الحبل 🪢") end
        end
    end)
    coil.Parent = pickups
    rope.part = coil
    announce("ظهر حبل في مكان ما بالحارة 🪢")
end

local function setRopeBands(on)
    for _, b in ipairs(rope.bands) do b:Destroy() end
    rope.bands = {}
    if not on then return end
    for i, y in ipairs({-1.4, 0.2, 1.8}) do
        local band = Instance.new("Part")
        band.Name = "RopeBand" .. i
        band.Shape = Enum.PartType.Cylinder
        band.Size = Vector3.new(0.35, 3.1, 3.1)
        band.CFrame = jroot.CFrame * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90))
        band.Color = Color3.fromRGB(196, 150, 92)
        band.Material = Enum.Material.Fabric
        band.CanCollide, band.CanQuery, band.CanTouch, band.Massless = false, false, false, true
        local weld = Instance.new("WeldConstraint")
        weld.Part0, weld.Part1 = jroot, band
        weld.Parent = band
        band.Parent = joud
        table.insert(rope.bands, band)
    end
end

local function untie(token)
    if token ~= roundToken or ai.tiedUntil == 0 or not Rules.isRunning(state) then return end
    ai.tiedUntil = 0
    setRopeBands(false)
    -- تتحرر وتروح لآخر مكان أقرب لاعب
    local best, bestDistance
    for player, s in pairs(sessions) do
        local r = body(player)
        if s.active and not s.hidden and r and not isSafe(r.Position) then
            local d = (r.Position - jroot.Position).Magnitude
            if not bestDistance or d < bestDistance then best, bestDistance = r.Position, d end
        end
    end
    if best then ai.lastKnown, ai.lastSeen = best, os.clock() + 2 end
    ai.rageUntil = os.clock() + Config.RageSeconds
    ai.lastCalc = 0
    joud:SetAttribute("Mood", "Search")
    announce("جود تحررت… وتدوّر عليكم! 😱")
    event:FireAllClients("Cue", "untied")
end

local function useRope(player)
    local s = sessions[player]
    if not s or not s.active or s.hidden or rope.holder ~= player or not Rules.isRunning(state) then return end
    if os.clock() < ai.tiedUntil then toast(player, "جود مربوطة أصلاً… استغل الوقت"); return end
    local root = body(player)
    if not root then return end
    if (root.Position - jroot.Position).Magnitude > Config.RopeRange then
        toast(player, "قرّب أكثر من جود عشان تربطها"); return
    end
    if not rayClear(root.Position + Vector3.new(0, 1, 0), jroot.Position, {player.Character, joud, world.Markers, pickups}) then
        toast(player, "فيه شي بينك وبينها"); return
    end
    rope.holder = nil
    player:SetAttribute("HasRope", false)
    rope.nextSpawn = os.clock() + Config.RopeSeconds + Config.RopeRespawn
    ai.tiedUntil = os.clock() + Config.RopeSeconds
    ai.target, ai.lastKnown, ai.goal, ai.points = nil, nil, nil, {}
    ai.pathToken = ai.pathToken + 1
    ai.busy = false
    jhuman:Move(Vector3.zero)
    jhuman.WalkSpeed = 0
    jhuman:MoveTo(jroot.Position)
    joud:SetAttribute("Mood", "Tied")
    setRopeBands(true)
    announce(player.DisplayName .. " ربط جود! عندكم " .. Config.RopeSeconds .. " ثواني 🏃")
    event:FireAllClients("Cue", "tied")
    local token = roundToken
    task.delay(Config.RopeSeconds, function() untie(token) end)
end

local function spawnSweets()
    for _, old in ipairs(pickups:GetChildren()) do
        if old.Name == "Sweet" then old:Destroy() end
    end
    local pool = table.clone(spots)
    for i = 1, math.min(Config.SweetCount, #pool) do
        local p = table.remove(pool, math.random(1, #pool))
        local sweet = Instance.new("Part")
        sweet.Name = "Sweet"
        sweet.Shape = Enum.PartType.Ball
        sweet.Size = Vector3.new(1.1, 1.1, 1.1)
        sweet.Position = Vector3.new(p.X + math.random(-3, 3), 1.6, p.Z + math.random(-3, 3))
        sweet.Color = ({Color3.fromRGB(255, 90, 150), Color3.fromRGB(255, 200, 50), Color3.fromRGB(90, 210, 255)})[i % 3 + 1]
        sweet.Material = Enum.Material.Neon
        sweet.Anchored, sweet.CanCollide = true, false
        local glow = Instance.new("PointLight")
        glow.Color, glow.Range, glow.Brightness = sweet.Color, 6, 0.8
        glow.Parent = sweet
        local prompt = Instance.new("ProximityPrompt")
        prompt.ActionText, prompt.ObjectText = "كُل الحلاوة", "🍬"
        prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 0, 8, false
        prompt.Parent = sweet
        prompt.Triggered:Connect(function(player)
            local s = sessions[player]
            if not sweet.Parent or not s or not s.active or s.hidden then return end
            sweet:Destroy()
            s.stamina = math.min(100, s.stamina + Config.SweetStamina)
            s.sweets = (s.sweets or 0) + 1
            toast(player, "🍬 حلاوة! طاقة الركض +" .. Config.SweetStamina)
            profile(player)
        end)
        sweet.Parent = pickups
    end
end

local function resetRopeAndSweets()
    clearRopePickup()
    if rope.holder then rope.holder:SetAttribute("HasRope", false); rope.holder = nil end
    setRopeBands(false)
    ai.tiedUntil, ai.rageUntil = 0, 0
    rope.nextSpawn = math.huge
    spawnSweets()
end

local resetRound
local function finishRound(reason, alreadyEnded)
    if not alreadyEnded and not Rules.finish(state, reason) then return end
    local thisToken = roundToken
    jhuman:Move(Vector3.zero)
    jhuman.WalkSpeed = 0
    jroot.Anchored = true
    ai.pathToken = ai.pathToken + 1
    ai.points = {}
    ai.target = nil
    if ai.blocked then ai.blocked:Disconnect(); ai.blocked = nil end
    for player, s in pairs(sessions) do
        leaveHide(player, true)
        if s.active then
            s.active = false
            local root, human = body(player)
            if root then root.Anchored = false end
            if human then human.WalkSpeed = Config.WalkSpeed end
            send(player, "Finish", {win = reason == "escaped", text = reason == "timeout" and "انتهى الوقت… الحارة احتفظت بسرّها" or "انتهت الجولة"})
        end
        profile(player)
    end
    broadcast()
    task.delay(Config.ResetDelay, function()
        if thisToken == roundToken then resetRound() end
    end)
end

local function checkRoundComplete()
    if not Rules.isRunning(state) then return end
    local active, escaped = 0, 0
    for _, s in pairs(sessions) do
        if s.active then active = active + 1 end
        if s.escaped then escaped = escaped + 1 end
    end
    if active == 0 then finishRound(escaped > 0 and "escaped" or "caught") end
end

resetRound = function()
    roundToken = roundToken + 1
    state = Rules.new(Config.FuseCount)
    for player, s in pairs(sessions) do
        leaveHide(player, true)
        s.active, s.escaped, s.catches, s.stamina, s.sprinting = false, false, 0, 100, false
        s.capturedUntil = 0
        s.sweets = 0
        local root = body(player)
        if root then root.CFrame = CFrame.new(Config.Spawn); root.Anchored = true end
        profile(player)
    end
    for _, fuse in ipairs(objects.Fuses:GetChildren()) do showCollectible(fuse, true) end
    showCollectible(objects.Key, false)
    objects.Generator.Switch.ProximityPrompt.Enabled = true
    objects.Generator.Status.Color = Color3.fromRGB(135,34,32)
    objects.GateControl.ProximityPrompt.Enabled = true
    for part, frame in pairs(gateFrames) do
        part.CFrame = frame
        part.CanCollide = true
    end
    for _, light in ipairs(world.PowerLights:GetDescendants()) do
        if light:IsA("Light") then light.Enabled = false end
    end
    jroot.Anchored = true
    joud:PivotTo(CFrame.new(Config.JoudSpawn))
    ai.target, ai.goal, ai.lastKnown = nil, nil, nil
    ai.points, ai.index, ai.busy = {}, 1, false
    ai.patrol, ai.lastCalc, ai.lastSeen, ai.stunUntil = 1, 0, 0, 0
    ai.pathToken = ai.pathToken + 1
    ai.mood = "Idle"
    joud:SetAttribute("Mood", "Idle")
    resetRopeAndSweets()
    broadcast()
end

for _, fuse in ipairs(objects.Fuses:GetChildren()) do
    fuse.Core.ProximityPrompt.Triggered:Connect(function(player)
        if not canInteract(player, fuse.Core) then return end
        if Rules.collect(state, fuse.Name) then
            showCollectible(fuse, false)
            announce("قطعة كهرباء " .. state.count .. " / " .. Config.FuseCount)
            if state.stage == "Generator" then announce("اكتملت القطع • شغّل المولد خلف الورشة") end
            broadcast()
        end
    end)
end
objects.Generator.Switch.ProximityPrompt.Triggered:Connect(function(player)
    if not canInteract(player, objects.Generator.Switch) then return end
    if not Rules.power(state) then toast(player, "المولد يحتاج ثلاث قطع كهرباء"); return end
    objects.Generator.Switch.ProximityPrompt.Enabled = false
    objects.Generator.Status.Color = Color3.fromRGB(115,232,174)
    showCollectible(objects.Key, true)
    for _, light in ipairs(world.PowerLights:GetDescendants()) do
        if light:IsA("Light") then light.Enabled = true end
    end
    announce("اشتغل المولد… المفتاح في بيت جود")
    event:FireAllClients("Cue", "power")
    broadcast()
end)
objects.Key.Core.ProximityPrompt.Triggered:Connect(function(player)
    if not canInteract(player, objects.Key.Core) then return end
    if Rules.key(state) then
        showCollectible(objects.Key, false)
        announce("معك المفتاح • افتح بوابة نهاية الحارة")
        broadcast()
    end
end)
objects.GateControl.ProximityPrompt.Triggered:Connect(function(player)
    if not canInteract(player, objects.GateControl) then return end
    if not Rules.gate(state) then toast(player, "تحتاج مفتاح بيت جود أولًا"); return end
    objects.GateControl.ProximityPrompt.Enabled = false
    for part, frame in pairs(gateFrames) do
        part.CanCollide = false
        TweenService:Create(part, TweenInfo.new(2.5, Enum.EasingStyle.Quad), {CFrame = frame + Vector3.new(0,16,0)}):Play()
    end
    announce("البوابة مفتوحة… اركض للخارج!")
    event:FireAllClients("Cue", "gate")
    broadcast()
end)
for _, locker in ipairs(objects.Lockers:GetChildren()) do
    locker.Door.ProximityPrompt.Triggered:Connect(function(player)
        if not canInteract(player, locker.Door, 10) then return end
        local s = sessions[player]
        if hideOwners[locker] then toast(player, "المخبأ مشغول"); return end
        if os.clock() < (s.hideCooldown or 0) then return end
        local root, human = body(player)
        s.hidden, s.hideUntil, s.sprinting = locker, os.clock() + Config.HideSeconds, false
        hideOwners[locker] = player
        root.CFrame = locker.Slot.CFrame
        root.Anchored = true
        human.WalkSpeed = 0
        profile(player)
        toast(player, "اهدأ… المخبأ يحميك لفترة قصيرة")
    end)
end

local function caught(player)
    local s = sessions[player]
    if not s or not s.active then return end
    s.catches = s.catches + 1
    s.sprinting = false
    s.capturedUntil = os.clock() + 1.5
    s.graceUntil = os.clock() + 1.5 + Config.RespawnGrace
    ai.stunUntil = os.clock() + 2
    ai.target, ai.lastKnown, ai.goal = nil, nil, nil
    ai.points = {}
    ai.pathToken = ai.pathToken + 1
    ai.busy, ai.lastSeen = false, 0
    jhuman:MoveTo(jroot.Position)
    leaveHide(player, true)
    dropRope(player)
    local root = body(player)
    if root then root.Anchored = true end
    send(player, "Caught", Config.MaxCatches - s.catches)
    profile(player)
    local token = roundToken
    task.delay(1.4, function()
        if token ~= roundToken or not sessions[player] then return end
        local r, h = body(player)
        if r then r.CFrame = CFrame.new(Config.Spawn); r.Anchored = false end
        if h then h.WalkSpeed = Config.WalkSpeed end
        if s.catches >= Config.MaxCatches then
            s.active = false
            send(player, "Finish", {win = false, text = "جود لقتك ثلاث مرات… جرّب في الجولة الجاية"})
            checkRoundComplete()
        else
            toast(player, "رجعت للساحة الآمنة • باقي " .. (Config.MaxCatches - s.catches) .. " فرص")
        end
        profile(player)
    end)
end

local function setupCharacter(player, character)
    local root = character:WaitForChild("HumanoidRootPart", 12)
    local human = character:WaitForChild("Humanoid", 12)
    if not root or not human or not sessions[player] then return end
    local s = sessions[player]
    leaveHide(player, true)
    root.CFrame = CFrame.new(Config.Spawn)
    root.Anchored = not s.active
    human.WalkSpeed = Config.WalkSpeed
    human.JumpPower = 38
    s.graceUntil = os.clock() + Config.RespawnGrace
    human.Died:Connect(function()
        if s.hidden then hideOwners[s.hidden] = nil; s.hidden = nil end
        dropRope(player)
        if s.active then
            s.catches = s.catches + 1
            s.sprinting = false
            if s.catches >= Config.MaxCatches then
                s.active = false
                send(player, "Finish", {win = false, text = "انتهت فرصك في هذه الجولة"})
                checkRoundComplete()
            end
        end
    end)
end
local function onPlayer(player)
    sessions[player] = {active = false, escaped = false, catches = 0, stamina = 100,
        sprinting = false, graceUntil = 0, lastActions = {}}
    player.CharacterAdded:Connect(function(character) setupCharacter(player, character) end)
    if player.Character then task.spawn(setupCharacter, player, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do onPlayer(player) end
Players.PlayerRemoving:Connect(function(player)
    local s = sessions[player]
    if s and s.hidden then hideOwners[s.hidden] = nil end
    dropRope(player)
    sessions[player] = nil
    checkRoundComplete()
end)

event.OnServerEvent:Connect(function(player, action, value)
    local s = sessions[player]
    if not s or type(action) ~= "string" then return end
    if action ~= "Sync" and action ~= "Ready" and action ~= "Sprint" and action ~= "LeaveHide" and action ~= "Rope" then return end
    local now = os.clock()
    -- Never discard a sprint-release packet; rapid taps must not latch sprint on.
    if not (action == "Sprint" and value == false) and now - (s.lastActions[action] or -10) < 0.12 then return end
    s.lastActions[action] = now
    if action == "Sync" then
        send(player, "State", Rules.snapshot(state, Config.RoundSeconds)); profile(player)
    elseif action == "Ready" then
        if s.active then return end
        if state.stage == "Ended" then toast(player, "لحظات… نجهّز الجولة التالية"); return end
        if s.catches >= Config.MaxCatches or s.escaped then toast(player, "انتظر نهاية الجولة الحالية"); return end
        local activeCount = 0
        for _, other in pairs(sessions) do if other.active then activeCount = activeCount + 1 end end
        if activeCount >= Config.MaxActivePlayers then toast(player, "الجولة مكتملة: ستة لاعبين"); return end
        local root, human = body(player)
        if not root or not human or human.Health <= 0 then return end
        if state.stage == "Idle" then
            Rules.start(state)
            rope.nextSpawn = os.clock() + Config.RopeFirstDelay
            jroot.Anchored = false
            jroot:SetNetworkOwner(nil)
        end
        s.active, s.stamina, s.graceUntil = true, 100, now + Config.InitialGrace
        root.CFrame = CFrame.new(Config.Spawn)
        root.Anchored = false
        human.WalkSpeed = Config.WalkSpeed
        send(player, "Started", true)
        toast(player, "ثلاث قطع كهرباء… ثم المولد… ثم مفتاح بيت جود")
        broadcast(); profile(player)
    elseif action == "Sprint" then
        if type(value) == "boolean" then s.sprinting = value and s.active and not s.hidden end
    elseif action == "LeaveHide" then
        leaveHide(player)
    elseif action == "Rope" then
        useRope(player)
    end
end)

local function requestPath(goal)
    if ai.busy then return end
    ai.busy = true
    ai.lastCalc = os.clock()
    ai.pathToken = ai.pathToken + 1
    local token, origin = ai.pathToken, jroot.Position
    task.spawn(function()
        local path = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 6.1,
            AgentCanJump = true, WaypointSpacing = 4})
        local ok = pcall(function() path:ComputeAsync(origin, goal) end)
        if token ~= ai.pathToken then return end
        ai.busy = false
        if ai.blocked then ai.blocked:Disconnect(); ai.blocked = nil end
        if ok and path.Status == Enum.PathStatus.Success then
            ai.points, ai.index = path:GetWaypoints(), 2
            ai.blocked = path.Blocked:Connect(function(index)
                if index >= ai.index then ai.lastCalc = 0 end
            end)
        else
            ai.points = {}
            if ai.mood == "Patrol" then ai.patrol = ai.patrol % #patrol + 1 end
        end
    end)
end

local function updateAI(now)
    if not Rules.isRunning(state) or now < ai.stunUntil or now < ai.tiedUntil then
        jhuman:Move(Vector3.zero)
        if now < ai.tiedUntil then jhuman.WalkSpeed = 0 end
        return
    end
    local nearest, nearestDistance, heardPosition = nil, Config.SightRange, nil
    for player, s in pairs(sessions) do
        local root, human = body(player)
        if s.active and not s.hidden and now > s.graceUntil and root and human and human.Health > 0 and not isSafe(root.Position) then
            local offset = root.Position - jroot.Position
            local distance = offset.Magnitude
            local inCone = distance < 16 or (distance > 0 and jroot.CFrame.LookVector:Dot(offset.Unit) > -0.12)
            local sees = distance < Config.SightRange and inCone and rayClear(
                joud.Head.Position, root.Position, {joud, player.Character, world.Markers})
            if sees and distance < nearestDistance then nearest, nearestDistance = player, distance end
            local velocity = root.AssemblyLinearVelocity
            if s.sprinting and Vector3.new(velocity.X,0,velocity.Z).Magnitude > 2 and distance < Config.HearingRange then heardPosition = root.Position end
        end
    end
    if nearest then
        local root = body(nearest)
        ai.target, ai.lastSeen, ai.lastKnown = nearest, now, root.Position
        ai.mood = "Hunt"
        if nearestDistance < Config.CatchDistance then caught(nearest); return end
    elseif now - ai.lastSeen < 3.5 and ai.lastKnown then
        ai.mood = "Search"
    elseif heardPosition then
        ai.target, ai.lastKnown, ai.lastSeen = nil, heardPosition, now - 1.5
        ai.mood = "Search"
    else
        ai.target, ai.lastKnown = nil, nil
        ai.mood = "Patrol"
    end
    joud:SetAttribute("Mood", ai.mood)
    jhuman.WalkSpeed = (ai.mood == "Hunt" and Config.ChaseSpeed or Config.PatrolSpeed)
        + (now < ai.rageUntil and Config.RageSpeedBonus or 0)
    local goal = ai.lastKnown
    if not goal then
        goal = patrol[ai.patrol].Position
        if (jroot.Position - goal).Magnitude < 6 then
            ai.patrol = ai.patrol % #patrol + 1
            goal = patrol[ai.patrol].Position
        end
    end
    if not ai.goal or (goal-ai.goal).Magnitude > 7 or now-ai.lastCalc > 1.6 then
        ai.goal = goal
        requestPath(goal)
    end
    local waypoint = ai.points[ai.index]
    if waypoint then
        if (Vector3.new(jroot.Position.X,0,jroot.Position.Z) - Vector3.new(waypoint.Position.X,0,waypoint.Position.Z)).Magnitude < 2.7 then
            ai.index = ai.index + 1
            waypoint = ai.points[ai.index]
        end
        if waypoint then
            if waypoint.Action == Enum.PathWaypointAction.Jump then jhuman.Jump = true end
            jhuman:MoveTo(waypoint.Position)
        end
    elseif rayClear(jroot.Position, goal, {joud, world.Markers}) then
        jhuman:MoveTo(goal)
    else
        jhuman:MoveTo(jroot.Position)
    end
    if jroot.Position.Y < -15 then
        joud:PivotTo(CFrame.new(Config.JoudSpawn))
        ai.points, ai.lastCalc = {}, 0
    end
end

resetRound()
local aiAccumulator, networkAccumulator, timerAccumulator = 0, 0, 0
RunService.Heartbeat:Connect(function(dt)
    local now = os.clock()
    if Rules.tick(state, dt, Config.RoundSeconds) then finishRound("timeout", true) end
    for player, s in pairs(sessions) do
        local root, human = body(player)
        if s.active and root and human then
            if s.hidden then
                if now >= s.hideUntil then leaveHide(player) end
            elseif now >= (s.capturedUntil or 0) then
                local velocity = root.AssemblyLinearVelocity
                local moving = Vector3.new(velocity.X,0,velocity.Z).Magnitude > 1
                local sprint = s.sprinting and s.stamina > 1 and moving
                if s.stamina <= 1 then s.sprinting = false end
                s.stamina = math.clamp(s.stamina + (sprint and -Config.StaminaDrain or Config.StaminaRecovery) * dt, 0, 100)
                human.WalkSpeed = sprint and Config.SprintSpeed or Config.WalkSpeed
                if state.gateOpen and inside(root.Position, Config.ExitCenter, Config.ExitHalf) then
                    s.active, s.escaped, s.sprinting = false, true, false
                    dropRope(player)
                    human.WalkSpeed = Config.WalkSpeed
                    send(player, "Finish", {win = true, text = "هربت من الحارة… لكن جود ما نسيتك"})
                    profile(player)
                    checkRoundComplete()
                end
            end
        end
    end
    aiAccumulator = aiAccumulator + dt
    networkAccumulator = networkAccumulator + dt
    timerAccumulator = timerAccumulator + dt
    if aiAccumulator >= 0.2 then aiAccumulator = 0; updateAI(now) end
    if Rules.isRunning(state) and not rope.part and not rope.holder and now >= rope.nextSpawn and now >= ai.tiedUntil then
        spawnRope()
    end
    if networkAccumulator >= 0.3 then
        networkAccumulator = 0
        for player in pairs(sessions) do profile(player) end
    end
    if timerAccumulator >= 1 then timerAccumulator = 0; broadcast() end
end)
