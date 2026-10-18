-- مدير الجولة: البداية، الفيوزات، الأعمدة، الطيحة والإنقاذ، الفانوس، الفوز والخسارة

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage.Shared.Config)
local MapBuilder = require(script.Parent.MapBuilder)
local Lamp = require(script.Parent.Lamp)
local Jood = require(script.Parent.Jood)

Players.CharacterAutoLoads = false

-- إضاءة الليل (نكررها هنا احتياطاً)
Lighting.ClockTime = 0
Lighting.Brightness = 0.6 -- ضوء قمر خفيف
Lighting.Ambient = Color3.fromRGB(40, 40, 52)
Lighting.OutdoorAmbient = Color3.fromRGB(56, 56, 76)
Lighting.FogStart = 10
Lighting.FogEnd = 200
Lighting.FogColor = Color3.fromRGB(12, 12, 20)

---------------------------------------------------------------- الحالة المشتركة

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
local notifyEvent = Instance.new("RemoteEvent")
notifyEvent.Name = "Notify"
notifyEvent.Parent = remotes
local flashEvent = Instance.new("RemoteEvent")
flashEvent.Name = "ToggleFlash"
flashEvent.Parent = remotes

local state = Instance.new("Folder")
state.Name = "GameState"
state:SetAttribute("Phase", "Waiting")
state:SetAttribute("Countdown", 0)
state:SetAttribute("LampsOn", 0)
state:SetAttribute("LampsTotal", #Config.LampPositions)
state:SetAttribute("FinaleProgress", 0)
state:SetAttribute("Message", "")
state.Parent = ReplicatedStorage

local function phase(): string
	return state:GetAttribute("Phase")
end

local function notify(player: Player, text: string)
	notifyEvent:FireClient(player, text)
end

local function notifyAll(text: string)
	notifyEvent:FireAllClients(text)
end

---------------------------------------------------------------- الخريطة

local map = MapBuilder.build()
local lamps = {}
local fuses = Instance.new("Folder")
fuses.Name = "Fuses"
fuses.Parent = map.folder

local function rootOf(player: Player): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoidOf(player: Player): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function isActive(player: Player): boolean
	local hum = humanoidOf(player)
	return hum ~= nil
		and hum.Health > 0
		and not player:GetAttribute("Out")
		and rootOf(player) ~= nil
end

local function canAct(player: Player): boolean
	return isActive(player) and not player:GetAttribute("Downed")
end

local function activePlayers(): { Player }
	local list = {}
	for _, p in Players:GetPlayers() do
		if isActive(p) then
			table.insert(list, p)
		end
	end
	return list
end

local function countLampsOn(): number
	local n = 0
	for _, l in lamps do
		if l:IsOn() then
			n += 1
		end
	end
	return n
end

local lantern -- يُعرّف تحت

local function refreshLamps()
	state:SetAttribute("LampsOn", countLampsOn())
	if lantern then
		lantern.prompt.Enabled = phase() == "Play" and countLampsOn() == #lamps
	end
end

-- منطقة آمنة مؤقتة عند البداية (نار صغيرة)
local campfire = Instance.new("Part")
campfire.Name = "Campfire"
campfire.Anchored = true
campfire.CanCollide = false
campfire.Size = Vector3.new(2, 0.6, 2)
campfire.Position = map.lanternPosition + Vector3.new(0, 0.3, 6)
campfire.Material = Enum.Material.Neon
campfire.Color = Color3.fromRGB(255, 120, 40)
campfire.Parent = map.folder
local fireLight = Instance.new("PointLight")
fireLight.Color = Color3.fromRGB(255, 140, 60)
fireLight.Range = 26
fireLight.Brightness = 1.6
fireLight.Parent = campfire

local function setCampfire(on: boolean)
	campfire.Transparency = on and 0 or 1
	fireLight.Enabled = on
end

local function isLit(pos: Vector3): boolean
	for _, l in lamps do
		if l:IsLitAt(pos) then
			return true
		end
	end
	if phase() == "Grace" and (pos - campfire.Position).Magnitude < 22 then
		return true
	end
	return false
end

local function litCenterAt(pos: Vector3): Vector3?
	for _, l in lamps do
		if l:IsLitAt(pos) then
			return l.Position
		end
	end
	return nil
end

---------------------------------------------------------------- الفيوزات

local function spawnFuse(cf: CFrame)
	local fuse = Instance.new("Part")
	fuse.Name = "Fuse"
	fuse.Size = Vector3.new(0.8, 1.2, 0.8)
	fuse.CFrame = cf
	fuse.Anchored = true
	fuse.CanCollide = false
	fuse.Material = Enum.Material.Neon
	fuse.Color = Color3.fromRGB(255, 200, 60)
	fuse.Parent = fuses
	local glow = Instance.new("PointLight")
	glow.Color = fuse.Color
	glow.Range = 7
	glow.Brightness = 1
	glow.Parent = fuse
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "التقط الفيوز"
	prompt.ObjectText = "فيوز"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = fuse
	prompt.Triggered:Connect(function(player)
		if not canAct(player) or not fuse.Parent then
			return
		end
		if player:GetAttribute("HasFuse") then
			notify(player, "معك فيوز من قبل! ركّبه بعمود")
			return
		end
		player:SetAttribute("HasFuse", true)
		fuse:Destroy()
		notify(player, "لقيت فيوز ⚡ روح لعمود مطفأ")
	end)
end

local function dropFuse(player: Player)
	if player:GetAttribute("HasFuse") then
		player:SetAttribute("HasFuse", false)
		local root = rootOf(player)
		if root then
			spawnFuse(CFrame.new(root.Position.X, 0.8, root.Position.Z))
		end
	end
end

---------------------------------------------------------------- الأعمدة والفانوس

local lampCtx = {
	notify = notify,
	canAct = canAct,
	soloMode = function()
		return #activePlayers() <= 1
	end,
	takeFuse = function(player: Player)
		if player:GetAttribute("HasFuse") then
			player:SetAttribute("HasFuse", false)
			return true
		end
		return false
	end,
	onChanged = function()
		refreshLamps()
	end,
}

local lampFolder = Instance.new("Folder")
lampFolder.Name = "Lamps"
lampFolder.Parent = map.folder
for i, pos in map.lampPositions do
	lamps[i] = Lamp.new(i, pos, Config.DualLamps[i] == true, lampFolder, lampCtx)
end

do
	local model = Instance.new("Model")
	model.Name = "GreatLantern"
	model.Parent = map.folder
	local base = Instance.new("Part")
	base.Name = "Pedestal"
	base.Anchored = true
	base.Size = Vector3.new(5, 4, 5)
	base.Position = map.lanternPosition + Vector3.new(0, 2, 0)
	base.Color = Color3.fromRGB(112, 82, 56)
	base.Material = Enum.Material.Sandstone
	base.Parent = model
	local glass = Instance.new("Part")
	glass.Name = "Lantern"
	glass.Anchored = true
	glass.Size = Vector3.new(3, 5, 3)
	glass.Position = map.lanternPosition + Vector3.new(0, 6.5, 0)
	glass.Color = Color3.fromRGB(60, 50, 35)
	glass.Material = Enum.Material.Glass
	glass.Transparency = 0.2
	glass.Parent = model
	local cap = Instance.new("Part")
	cap.Name = "Cap"
	cap.Anchored = true
	cap.Size = Vector3.new(3.6, 0.6, 3.6)
	cap.Position = map.lanternPosition + Vector3.new(0, 9.3, 0)
	cap.Color = Color3.fromRGB(45, 45, 48)
	cap.Material = Enum.Material.Metal
	cap.Parent = model
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 140)
	light.Range = 60
	light.Brightness = 0
	light.Shadows = true
	light.Parent = glass
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "أشعل الفانوس"
	prompt.ObjectText = "الفانوس الكبير"
	prompt.HoldDuration = Config.LanternHold
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = base
	lantern = { glass = glass, light = light, prompt = prompt }
end

local function setLanternProgress(p: number)
	state:SetAttribute("FinaleProgress", p)
	lantern.light.Brightness = p * 4
	lantern.light.Range = 20 + p * 60
	if p > 0 then
		lantern.glass.Material = Enum.Material.Neon
		lantern.glass.Color = Color3.fromRGB(60, 50, 35):Lerp(Color3.fromRGB(255, 220, 150), p)
	else
		lantern.glass.Material = Enum.Material.Glass
		lantern.glass.Color = Color3.fromRGB(60, 50, 35)
	end
end

lantern.prompt.Triggered:Connect(function(player)
	if not canAct(player) or phase() ~= "Play" or countLampsOn() < #lamps then
		return
	end
	lantern.prompt.Enabled = false
	state:SetAttribute("Phase", "Finale")
	setLanternProgress(0.01)
	notifyAll("الفانوس اشتعل! دافعوا عنه وخلّوا الأعمدة شغالة!")
end)

---------------------------------------------------------------- اللاعبين: الكشاف والطيحة

local downTokens: { [Player]: any } = {}

local function setFlash(player: Player, on: boolean)
	player:SetAttribute("FlashOn", on)
	local root = rootOf(player)
	local light = root and root:FindFirstChild("Flashlight") :: SpotLight?
	if light then
		light.Enabled = on
	end
end

local function markOut(player: Player)
	downTokens[player] = nil
	dropFuse(player)
	player:SetAttribute("Downed", false)
	player:SetAttribute("Out", true)
	setFlash(player, false)
end

local function revive(player: Player)
	downTokens[player] = nil
	player:SetAttribute("Downed", false)
	local hum = humanoidOf(player)
	if hum then
		hum.Sit = false
		hum.WalkSpeed = Config.PlayerWalkSpeed
		hum.JumpPower = 50
		hum.JumpHeight = 7.2
	end
	local root = rootOf(player)
	local prompt = root and root:FindFirstChild("RevivePrompt")
	if prompt then
		prompt:Destroy()
	end
	notify(player, "رجعت! انتبه منها")
end

local function downPlayer(player: Player)
	if player:GetAttribute("Downed") or not isActive(player) then
		return
	end
	player:SetAttribute("Downed", true)
	dropFuse(player)
	setFlash(player, false)
	local hum = humanoidOf(player) :: Humanoid
	local root = rootOf(player) :: BasePart
	hum.WalkSpeed = 0
	hum.JumpPower = 0
	hum.JumpHeight = 0
	hum.Sit = true

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RevivePrompt"
	prompt.ActionText = "أنقذ " .. player.DisplayName
	prompt.ObjectText = "طايح!"
	prompt.HoldDuration = Config.ReviveHold
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(rescuer)
		if rescuer ~= player and canAct(rescuer) and player:GetAttribute("Downed") then
			revive(player)
			notify(rescuer, "أنقذت " .. player.DisplayName .. " 💪")
		end
	end)

	local token = {}
	downTokens[player] = token
	task.delay(Config.BleedOut, function()
		if downTokens[player] == token and player:GetAttribute("Downed") then
			markOut(player)
			local h = humanoidOf(player)
			if h then
				h.Health = 0
			end
		end
	end)
	notifyAll(player.DisplayName .. " طاح! أنقذوه قبل " .. Config.BleedOut .. " ثانية")
end

local function setupCharacter(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	local root = char:WaitForChild("HumanoidRootPart") :: BasePart
	hum.WalkSpeed = Config.PlayerWalkSpeed
	player:SetAttribute("Downed", false)
	player:SetAttribute("HasFuse", false)
	player:SetAttribute("Battery", 100)
	player:SetAttribute("FlashOn", false)

	local spot = Instance.new("SpotLight")
	spot.Name = "Flashlight"
	spot.Face = Enum.NormalId.Front
	spot.Angle = 50
	spot.Range = Config.FlashRange + 10
	spot.Brightness = 3
	spot.Color = Color3.fromRGB(255, 244, 220)
	spot.Shadows = true
	spot.Enabled = false
	spot.Parent = root

	-- ثبات الجلسة وهو طايح
	hum:GetPropertyChangedSignal("Sit"):Connect(function()
		if player:GetAttribute("Downed") and not hum.Sit then
			hum.Sit = true
		end
	end)
	hum.Died:Connect(function()
		if not player:GetAttribute("Out") then
			markOut(player)
		end
	end)
end

local function onPlayerAdded(player: Player)
	player:SetAttribute("Out", false)
	player.CharacterAdded:Connect(function(char)
		setupCharacter(player, char)
	end)
	-- لو دخل والجولة شغالة: يدخل معهم
	local ph = phase()
	if ph == "Grace" or ph == "Play" or ph == "Finale" then
		player:LoadCharacter()
		task.wait()
		local sp = map.spawnPoints[math.random(1, #map.spawnPoints)]
		if player.Character then
			player.Character:PivotTo(sp)
		end
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	downTokens[player] = nil
end)

flashEvent.OnServerEvent:Connect(function(player)
	if not canAct(player) then
		return
	end
	local on = not player:GetAttribute("FlashOn")
	if on and (player:GetAttribute("Battery") or 0) <= 1 then
		notify(player, "البطارية خلصت! قف تحت عمود شغال تشحن")
		return
	end
	setFlash(player, on)
end)

---------------------------------------------------------------- جود

local jood = nil

local joodCtx = {
	wanderPoints = map.wanderPoints,
	speed = function()
		if phase() == "Finale" then
			return Config.JoodSpeedFinale
		end
		return Config.JoodSpeedBase + Config.JoodSpeedPerLamp * countLampsOn()
	end,
	litCenterAt = litCenterAt,
	isLit = isLit,
	findTarget = function(pos: Vector3)
		local best, bestRoot, bestDist = nil, nil, Config.JoodSenseRange
		for _, p in activePlayers() do
			if not p:GetAttribute("Downed") then
				local r = rootOf(p)
				if r and not isLit(r.Position) then
					local d = (r.Position - pos).Magnitude
					if d < bestDist then
						best, bestRoot, bestDist = p, r, d
					end
				end
			end
		end
		return best, bestRoot
	end,
	onCatch = function(player: Player?)
		if player and canAct(player) then
			downPlayer(player)
		end
	end,
}

local flashParams = RaycastParams.new()
flashParams.FilterType = Enum.RaycastFilterType.Exclude
flashParams.RespectCanCollide = true

local function updateFlashlights(dt: number)
	for _, p in activePlayers() do
		local battery = p:GetAttribute("Battery") or 0
		local root = rootOf(p)
		if p:GetAttribute("FlashOn") and root then
			battery = math.max(0, battery - Config.BatteryDrain * dt)
			if battery <= 0 then
				setFlash(p, false)
				notify(p, "البطارية خلصت!")
			elseif jood and jood.Root then
				local origin = root.Position + Vector3.new(0, 1.5, 0)
				local to = jood.Root.Position - origin
				if to.Magnitude > 0.1 and to.Magnitude <= Config.FlashRange then
					local dot = math.clamp(root.CFrame.LookVector:Dot(to.Unit), -1, 1)
					if math.deg(math.acos(dot)) <= Config.FlashAngle then
						local exclude = { jood.Model }
						for _, q in Players:GetPlayers() do
							if q.Character then
								table.insert(exclude, q.Character)
							end
						end
						flashParams.FilterDescendantsInstances = exclude
						if workspace:Raycast(origin, to, flashParams) == nil then
							jood:Slow(0.35)
						end
					end
				end
			end
		elseif root then
			local rate = isLit(root.Position) and Config.BatteryRechargeLight or Config.BatteryRechargeDark
			battery = math.min(100, battery + rate * dt)
		end
		p:SetAttribute("Battery", battery)
	end
end

---------------------------------------------------------------- دورة الجولة

local function resetRound()
	if jood then
		jood:Destroy()
		jood = nil
	end
	fuses:ClearAllChildren()
	for _, l in lamps do
		l:Reset()
	end
	setLanternProgress(0)
	lantern.prompt.Enabled = false
	state:SetAttribute("Message", "")
	for _, p in Players:GetPlayers() do
		downTokens[p] = nil
		p:SetAttribute("Out", false)
		p:SetAttribute("Downed", false)
		p:SetAttribute("HasFuse", false)
	end
end

local function spawnEveryone()
	local pts = map.spawnPoints
	for i, p in Players:GetPlayers() do
		task.spawn(function()
			p:LoadCharacter()
			local char = p.Character
			if char then
				char:PivotTo(pts[(i - 1) % #pts + 1])
			end
		end)
	end
end

local function breakInterval(): number
	if phase() == "Finale" then
		return Config.BreakIntervalFinale
	end
	return math.max(Config.BreakIntervalMin, Config.BreakIntervalBase - Config.BreakIntervalPerLamp * countLampsOn())
end

local function breakRandomLamp()
	local on = {}
	for _, l in lamps do
		if l.State == "On" then
			table.insert(on, l)
		end
	end
	if #on > 0 then
		on[math.random(1, #on)]:Flicker()
		notifyAll("جود تطفي عمود! 😱")
	end
end

local function countdown(phaseName: string, seconds: number)
	state:SetAttribute("Phase", phaseName)
	for t = seconds, 1, -1 do
		state:SetAttribute("Countdown", t)
		task.wait(1)
	end
	state:SetAttribute("Countdown", 0)
end

local function endRound(won: boolean)
	state:SetAttribute("Phase", won and "Win" or "Lose")
	if won then
		state:SetAttribute("Message", "طردتوا جود من الحارة! 🎉")
		setLanternProgress(1)
		if jood then
			jood:Banish()
			jood = nil
		end
	else
		state:SetAttribute("Message", "جود أخذتكم كلكم... الحارة لها 👁")
	end
	task.wait(Config.EndScreenTime)
end

local function playRound()
	resetRound()
	-- الفيوزات في الدكاكين
	for _, cf in map.fuseSpots do
		spawnFuse(cf)
	end
	spawnEveryone()
	setCampfire(true)
	countdown("Grace", Config.Grace)
	setCampfire(false)

	state:SetAttribute("Phase", "Play")
	refreshLamps()
	local spawnPos = map.joodSpawns[math.random(1, #map.joodSpawns)]
	jood = Jood.new(spawnPos, joodCtx)
	notifyAll("جود طلعت... 👁")

	local nextBreak = os.clock() + breakInterval()
	local last = os.clock()
	while true do
		task.wait(0.1)
		local now = os.clock()
		local dt = now - last
		last = now

		if #Players:GetPlayers() == 0 then
			return
		end

		updateFlashlights(dt)

		-- خسارة: ما بقى أحد واقف
		local standing = 0
		for _, p in activePlayers() do
			if not p:GetAttribute("Downed") then
				standing += 1
			end
		end
		if standing == 0 then
			-- الطايحين يطلعون
			for _, p in Players:GetPlayers() do
				if p:GetAttribute("Downed") then
					markOut(p)
				end
			end
			endRound(false)
			return
		end

		if now >= nextBreak then
			breakRandomLamp()
			nextBreak = now + breakInterval()
		end

		if phase() == "Finale" then
			local p = state:GetAttribute("FinaleProgress")
			if countLampsOn() >= Config.FinaleMinLamps then
				p = math.min(1, p + dt / Config.FinaleTime)
				setLanternProgress(p)
			end
			if p >= 1 then
				endRound(true)
				return
			end
		end
	end
end

while true do
	if #Players:GetPlayers() == 0 then
		state:SetAttribute("Phase", "Waiting")
		Players.PlayerAdded:Wait()
	end
	countdown("Intermission", Config.Intermission)
	if #Players:GetPlayers() > 0 then
		playRound()
	end
end
