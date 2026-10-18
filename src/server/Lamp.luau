-- عمود إنارة: حالاته وتفاعله مع اللاعبين
-- الحالات: Empty (يحتاج فيوز) / Switch (يحتاج مفتاحين) / On / Flicker / Broken

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Lamp = {}
Lamp.__index = Lamp

local WARM = Color3.fromRGB(255, 196, 120)
local OFF = Color3.fromRGB(40, 36, 30)
local POLE = Color3.fromRGB(45, 45, 48)

local function newPart(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

local function newPrompt(parent: Instance, action: string, object: string, hold: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

--[[ ctx:
	notify(player, text)
	canAct(player) -> bool        (حي وغير طايح)
	soloMode() -> bool
	takeFuse(player) -> bool      (يشيل الفيوز من اللاعب إذا معه)
	onChanged()
]]
function Lamp.new(index: number, position: Vector3, isDual: boolean, parent: Instance, ctx)
	local self = setmetatable({}, Lamp)
	self.Index = index
	self.Position = position
	self.IsDual = isDual
	self.ctx = ctx
	self.State = "Empty"
	self.leverTimes = {}
	self.flickerToken = 0

	local model = Instance.new("Model")
	model.Name = "Lamp" .. index
	model.Parent = parent
	self.Model = model

	newPart({
		Name = "Pole",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(14, 0.8, 0.8),
		CFrame = CFrame.new(position + Vector3.new(0, 7, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = POLE,
		Material = Enum.Material.Metal,
		Parent = model,
	})
	local head = newPart({
		Name = "Head",
		Size = Vector3.new(2.2, 1.6, 2.2),
		Position = position + Vector3.new(0, 14.6, 0),
		Color = OFF,
		Material = Enum.Material.Glass,
		CanCollide = false,
		Parent = model,
	})
	self.Head = head

	local light = Instance.new("PointLight")
	light.Color = WARM
	light.Range = Config.LampSafeRadius + 22
	light.Brightness = 2.2
	light.Shadows = true
	light.Enabled = false
	light.Parent = head
	self.Light = light

	local box = newPart({
		Name = "FuseBox",
		Size = Vector3.new(1.6, 2.4, 0.9),
		Position = position + Vector3.new(0, 3.2, 0.85),
		Color = Color3.fromRGB(90, 90, 70),
		Material = Enum.Material.DiamondPlate,
		Parent = model,
	})
	self.Box = box
	self.BoxPrompt = newPrompt(box, "ركّب الفيوز", "عمود إنارة", Config.FuseHold)
	self.BoxPrompt.Triggered:Connect(function(player)
		self:_onBox(player)
	end)

	-- علامة فوق العمود المطفأ تبان من بعيد
	local bb = Instance.new("BillboardGui")
	bb.Name = "Marker"
	bb.Size = UDim2.fromOffset(44, 44)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 400
	bb.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Text = "⚡"
	label.TextColor3 = Color3.fromRGB(255, 220, 90)
	label.Parent = bb
	self.Marker = bb
	self.MarkerLabel = label

	-- منطقة الضوء: جود تتجنبها في حساب الطريق
	local zone = newPart({
		Name = "LightZone",
		Size = Vector3.new(Config.LampSafeRadius * 2, 16, Config.LampSafeRadius * 2),
		Position = position + Vector3.new(0, 8, 0),
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CastShadow = false,
		Parent = nil,
	})
	local modifier = Instance.new("PathfindingModifier")
	modifier.Label = "Light"
	modifier.Parent = zone
	self.Zone = zone

	if isDual then
		self.Levers = {}
		for i, side in { -1, 1 } do
			local base = position + Vector3.new(side * 7, 0, 0)
			newPart({
				Name = "LeverBase" .. i,
				Size = Vector3.new(1.2, 3, 1.2),
				Position = base + Vector3.new(0, 1.5, 0),
				Color = POLE,
				Material = Enum.Material.Metal,
				Parent = model,
			})
			local handle = newPart({
				Name = "Lever" .. i,
				Size = Vector3.new(0.4, 1.8, 0.4),
				CFrame = CFrame.new(base + Vector3.new(0, 3.6, 0)) * CFrame.Angles(0, 0, math.rad(30)),
				Color = Color3.fromRGB(170, 40, 30),
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Parent = model,
			})
			local prompt = newPrompt(handle, "اسحب المفتاح", "مفتاح " .. i, Config.LeverHold)
			prompt.Enabled = false
			prompt.Triggered:Connect(function(player)
				self:_onLever(i, player)
			end)
			self.Levers[i] = { handle = handle, prompt = prompt, base = base }
		end
	end

	self:SetState("Empty")
	return self
end

function Lamp:IsOn(): boolean
	return self.State == "On" or self.State == "Flicker"
end

function Lamp:IsLitAt(point: Vector3): boolean
	if not self:IsOn() then
		return false
	end
	local d = Vector3.new(point.X - self.Position.X, 0, point.Z - self.Position.Z)
	return d.Magnitude <= Config.LampSafeRadius
end

function Lamp:SetState(state: string)
	self.State = state
	local on = state == "On" or state == "Flicker"
	self.Light.Enabled = on
	self.Head.Material = on and Enum.Material.Neon or Enum.Material.Glass
	self.Head.Color = on and Color3.fromRGB(255, 214, 150) or OFF
	self.Zone.Parent = on and self.Model or nil

	self.Marker.Enabled = not on
	self.MarkerLabel.TextColor3 = state == "Broken" and Color3.fromRGB(255, 70, 60) or Color3.fromRGB(255, 220, 90)

	local prompt = self.BoxPrompt
	if state == "Empty" then
		prompt.Enabled = true
		prompt.ActionText = "ركّب الفيوز"
		prompt.HoldDuration = Config.FuseHold
	elseif state == "Broken" then
		prompt.Enabled = true
		prompt.ActionText = "صلّح العمود"
		prompt.HoldDuration = Config.RepairHold
	else
		prompt.Enabled = false
	end

	if self.Levers then
		for _, lever in self.Levers do
			lever.prompt.Enabled = state == "Switch"
		end
	end

	if state ~= "Flicker" then
		self.flickerToken += 1
	end
	self.ctx.onChanged()
end

function Lamp:_onBox(player: Player)
	if not self.ctx.canAct(player) then
		return
	end
	if self.State == "Empty" then
		if not self.ctx.takeFuse(player) then
			self.ctx.notify(player, "تحتاج فيوز! دوّر في الدكاكين")
			return
		end
		if self.IsDual and not self.ctx.soloMode() then
			self:SetState("Switch")
			self.ctx.notify(player, "ركبت الفيوز. الحين اسحبوا المفتاحين مع بعض!")
		else
			self:SetState("On")
		end
	elseif self.State == "Broken" then
		self:SetState("On")
	end
end

function Lamp:_onLever(i: number, player: Player)
	if self.State ~= "Switch" or not self.ctx.canAct(player) then
		return
	end
	local now = os.clock()
	self.leverTimes[i] = { time = now, player = player }
	local other = self.leverTimes[i == 1 and 2 or 1]
	if self.ctx.soloMode() or (other and other.player ~= player and now - other.time <= Config.DualWindow) then
		self.leverTimes = {}
		self:SetState("On")
	else
		self.ctx.notify(player, "يحتاج واحد ثاني يسحب المفتاح الثاني بنفس الوقت")
	end
end

-- جود تطفي العمود: يرمش شوي ثم يخرب
function Lamp:Flicker()
	if self.State ~= "On" then
		return
	end
	self:SetState("Flicker")
	self.flickerToken += 1
	local token = self.flickerToken
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < Config.BreakWarning do
			if self.flickerToken ~= token then
				return
			end
			self.Light.Enabled = not self.Light.Enabled
			task.wait(0.08 + math.random() * 0.25)
		end
		if self.flickerToken == token and self.State == "Flicker" then
			self:SetState("Broken")
		end
	end)
end

function Lamp:Reset()
	self.leverTimes = {}
	self:SetState("Empty")
end

return Lamp
