-- جود: مجنونة الحارة — حركتها وملاحقتها للاعبين

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Jood = {}
Jood.__index = Jood

local SKIN = Color3.fromRGB(196, 190, 178)
local DRESS = Color3.fromRGB(14, 13, 16)

local function weldTo(part: BasePart, anchor: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0 = anchor
	w.Part1 = part
	w.Parent = part
end

local function fallbackRig(): Model
	-- نسخة احتياطية بسيطة لو ما قدرنا نسوي شخصية Roblox
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.Parent = model
	local body = Instance.new("Part")
	body.Name = "Torso"
	body.Size = Vector3.new(2, 4, 1.2)
	body.Color = DRESS
	body.Parent = model
	body.CFrame = root.CFrame * CFrame.new(0, -0.5, 0)
	weldTo(body, root)
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.4, 1.4, 1.4)
	head.Color = SKIN
	head.Parent = model
	head.CFrame = root.CFrame * CFrame.new(0, 2.2, 0)
	weldTo(head, root)
	local hum = Instance.new("Humanoid")
	hum.HipHeight = 2.5
	hum.Parent = model
	model.PrimaryPart = root
	return model
end

local function buildModel(): Model
	local ok, model = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		desc.HeadColor = SKIN
		desc.LeftArmColor = SKIN
		desc.RightArmColor = SKIN
		desc.TorsoColor = DRESS
		desc.LeftLegColor = DRESS
		desc.RightLegColor = DRESS
		desc.HeightScale = 1.1
		desc.WidthScale = 0.8
		desc.BodyTypeScale = 0
		desc.ProportionScale = 0
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[Jood] fallback rig:", model)
		model = fallbackRig()
	end
	model.Name = "Jood"

	local head = model:FindFirstChild("Head") :: BasePart
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart

	-- نشيل الوجه المبتسم
	for _, d in head:GetChildren() do
		if d:IsA("Decal") then
			d:Destroy()
		end
	end

	-- عيون حمراء تلمع
	for _, side in { -0.22, 0.22 } do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Size = Vector3.new(0.18, 0.12, 0.05)
		eye.Color = Color3.fromRGB(255, 30, 20)
		eye.Material = Enum.Material.Neon
		eye.CFrame = head.CFrame * CFrame.new(side, 0.12, -head.Size.Z / 2 - 0.01)
		eye.Parent = model
		weldTo(eye, head)
	end
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 40, 30)
	glow.Range = 8
	glow.Brightness = 1.5
	glow.Parent = head

	-- شعر أسود طويل
	local hair = Instance.new("Part")
	hair.Name = "Hair"
	hair.Size = Vector3.new(head.Size.X + 0.2, head.Size.Y * 2.2, 0.5)
	hair.Color = Color3.fromRGB(8, 8, 8)
	hair.Material = Enum.Material.Fabric
	hair.CFrame = head.CFrame * CFrame.new(0, -head.Size.Y * 0.5, head.Size.Z / 2 + 0.2)
	hair.Parent = model
	weldTo(hair, head)
	local fringe = Instance.new("Part")
	fringe.Name = "Fringe"
	fringe.Size = Vector3.new(head.Size.X + 0.2, 0.5, head.Size.Z + 0.3)
	fringe.Color = hair.Color
	fringe.Material = Enum.Material.Fabric
	fringe.CFrame = head.CFrame * CFrame.new(0, head.Size.Y / 2, 0)
	fringe.Parent = model
	weldTo(fringe, head)

	-- ثوب أسود طويل
	local robe = Instance.new("Part")
	robe.Name = "Robe"
	robe.Size = Vector3.new(2.4, 3.4, 1.6)
	robe.Color = DRESS
	robe.Material = Enum.Material.Fabric
	robe.CFrame = root.CFrame * CFrame.new(0, -1.6, 0)
	robe.Parent = model
	weldTo(robe, root)

	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.NameDisplayDistance = 0
	hum.BreakJointsOnDeath = false
	hum.MaxHealth = math.huge
	hum.Health = math.huge
	hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	model.PrimaryPart = root
	return model
end

--[[ ctx:
	speed() -> number
	litCenterAt(pos) -> Vector3?     مركز الضوء إذا جود داخله
	isLit(pos) -> bool
	findTarget(pos) -> (Player?, BasePart?)
	onCatch(player)
	wanderPoints: {Vector3}
]]
function Jood.new(spawnPos: Vector3, ctx)
	local self = setmetatable({}, Jood)
	self.ctx = ctx
	self.slowUntil = 0
	self.cooldownUntil = 0
	self.nextRetarget = 0
	self.nextPath = 0
	self.nextWander = 0
	self.running = true

	local model = buildModel()
	model:PivotTo(CFrame.new(spawnPos + Vector3.new(0, 4, 0)))
	model.Parent = workspace
	self.Model = model
	self.Root = model.PrimaryPart
	self.Humanoid = model:FindFirstChildOfClass("Humanoid")
	pcall(function()
		self.Root:SetNetworkOwner(nil)
	end)

	self.path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = false,
		Costs = { Light = math.huge },
	})

	self.rayParams = RaycastParams.new()
	self.rayParams.FilterType = Enum.RaycastFilterType.Exclude
	self.rayParams.RespectCanCollide = true

	task.spawn(function()
		while self.running and self.Model.Parent do
			local ok, err = pcall(function()
				self:_step()
			end)
			if not ok then
				warn("[Jood] step error:", err)
			end
			task.wait(0.1)
		end
	end)
	return self
end

function Jood:Slow(duration: number)
	self.slowUntil = math.max(self.slowUntil, os.clock() + duration)
end

function Jood:IsSlowed(): boolean
	return os.clock() < self.slowUntil
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function Jood:_clearLine(from: Vector3, to: Vector3): boolean
	local exclude = { self.Model }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	self.rayParams.FilterDescendantsInstances = exclude
	local dir = to - from
	return workspace:Raycast(from, dir, self.rayParams) == nil
end

function Jood:_moveTo(pos: Vector3)
	self.Humanoid:MoveTo(Vector3.new(pos.X, self.Root.Position.Y, pos.Z))
end

function Jood:_followPath(goal: Vector3, now: number)
	local needNew = not self.waypoints
		or now >= self.nextPath
		or (self.pathGoal and flat(goal - self.pathGoal).Magnitude > 10)
	if needNew then
		self.nextPath = now + 1
		self.pathGoal = goal
		local ok = pcall(function()
			self.path:ComputeAsync(self.Root.Position, goal)
		end)
		if ok and self.path.Status == Enum.PathStatus.Success then
			self.waypoints = self.path:GetWaypoints()
			self.wpIndex = 2
		else
			self.waypoints = nil
			self:_moveTo(goal)
			return
		end
	end
	local wps = self.waypoints
	if not wps then
		return
	end
	local wp = wps[self.wpIndex]
	if wp and flat(wp.Position - self.Root.Position).Magnitude < 3 then
		self.wpIndex += 1
		wp = wps[self.wpIndex]
	end
	if wp then
		self:_moveTo(wp.Position)
	else
		self.waypoints = nil
		self:_moveTo(goal)
	end
end

function Jood:_wander(now: number)
	if now >= self.nextWander or not self.wanderGoal then
		local pts = self.ctx.wanderPoints
		self.wanderGoal = pts[math.random(1, #pts)]
		self.nextWander = now + 10
		self.waypoints = nil
	end
	if flat(self.wanderGoal - self.Root.Position).Magnitude < 4 then
		self.nextWander = 0
		return
	end
	self:_followPath(self.wanderGoal, now)
end

function Jood:_step()
	local now = os.clock()
	local pos = self.Root.Position
	local speed = self.ctx.speed()
	if self:IsSlowed() then
		speed *= Config.FlashSlow
	end
	self.Humanoid.WalkSpeed = speed

	-- داخل الضوء؟ تهرب برا
	local center = self.ctx.litCenterAt(pos)
	if center then
		local away = flat(pos - center)
		if away.Magnitude < 0.5 then
			away = Vector3.new(1, 0, 0)
		end
		self:_moveTo(center + away.Unit * (Config.LampSafeRadius + 8))
		self.target = nil
		self.waypoints = nil
		return
	end

	if now < self.cooldownUntil then
		self:_wander(now)
		return
	end

	if now >= self.nextRetarget then
		self.nextRetarget = now + 0.5
		self.targetPlayer, self.target = self.ctx.findTarget(pos)
	end

	local tgt = self.target
	if tgt and tgt.Parent and not self.ctx.isLit(tgt.Position) then
		local dist = flat(tgt.Position - pos).Magnitude
		if dist <= Config.JoodCatchDistance then
			self.cooldownUntil = now + Config.JoodCatchCooldown
			self.target = nil
			self.ctx.onCatch(self.targetPlayer)
			return
		end
		if dist < 24 and self:_clearLine(pos, tgt.Position) then
			self.waypoints = nil
			self:_moveTo(tgt.Position)
		else
			self:_followPath(tgt.Position, now)
		end
	else
		self.target = nil
		self:_wander(now)
	end
end

-- الطرد: تختفي تدريجياً
function Jood:Banish()
	self.running = false
	self.Humanoid.WalkSpeed = 0
	local info = TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, d in self.Model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			TweenService:Create(d, info, { Transparency = 1 }):Play()
		elseif d:IsA("PointLight") then
			TweenService:Create(d, info, { Brightness = 0 }):Play()
		end
	end
	task.delay(3.2, function()
		self:Destroy()
	end)
end

function Jood:Destroy()
	self.running = false
	if self.Model then
		self.Model:Destroy()
	end
end

return Jood
