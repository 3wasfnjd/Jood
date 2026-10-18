-- يبني الحارة بالكامل بالكود: أرضية، بيوت طين، دكاكين، ساحة، وسور

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local MapBuilder = {}

local COLORS = {
	Mud = Color3.fromRGB(139, 104, 72),
	MudDark = Color3.fromRGB(112, 82, 56),
	Ground = Color3.fromRGB(88, 70, 52),
	Wood = Color3.fromRGB(70, 45, 28),
	Window = Color3.fromRGB(12, 10, 9),
	Trunk = Color3.fromRGB(85, 62, 40),
	Leaf = Color3.fromRGB(38, 66, 34),
	Bench = Color3.fromRGB(120, 90, 62),
}

local function setMaterial(p: BasePart, material: Enum.Material)
	local ok = pcall(function()
		p.Material = material
	end)
	if not ok then
		p.Material = Enum.Material.Concrete
	end
end

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "Parent" and k ~= "Material" then
			(p :: any)[k] = v
		end
	end
	if props.Material then
		setMaterial(p, props.Material)
	end
	p.Parent = props.Parent
	return p
end

-- شرفات الطين النجدية فوق السطح
local function crenellations(parent: Instance, center: Vector3, size: number, top: number)
	local half = size / 2
	local step = 2.6
	local n = math.floor(size / step)
	for i = 0, n - 1 do
		if i % 2 == 0 then
			local offset = -half + step / 2 + i * step
			for _, pos in
				{
					Vector3.new(offset, 0, half - 0.5),
					Vector3.new(offset, 0, -half + 0.5),
					Vector3.new(half - 0.5, 0, offset),
					Vector3.new(-half + 0.5, 0, offset),
				}
			do
				part({
					Name = "Crenel",
					Size = Vector3.new(1.3, 1.6, 1.3),
					Position = Vector3.new(center.X + pos.X, top + 0.8, center.Z + pos.Z),
					Color = COLORS.MudDark,
					Material = Enum.Material.Sandstone,
					CanCollide = false,
					CastShadow = false,
					Parent = parent,
				})
			end
		end
	end
end

local function house(parent: Instance, center: Vector3, height: number, doorDir: Vector3, rng: Random)
	local model = Instance.new("Model")
	model.Name = "House"
	model.Parent = parent

	local size = 13
	part({
		Name = "Body",
		Size = Vector3.new(size, height, size),
		Position = center + Vector3.new(0, height / 2, 0),
		Color = rng:NextNumber() < 0.5 and COLORS.Mud or COLORS.MudDark,
		Material = Enum.Material.Sandstone,
		Parent = model,
	})
	crenellations(model, center, size, height)

	-- باب خشب باتجاه الزقاق
	local face = center + doorDir * (size / 2 + 0.15)
	local doorCF = CFrame.lookAt(face + Vector3.new(0, 3.5, 0), face + Vector3.new(0, 3.5, 0) + doorDir)
	part({
		Name = "Door",
		Size = Vector3.new(4, 7, 0.3),
		CFrame = doorCF,
		Color = COLORS.Wood,
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	-- شبابيك صغيرة عالية
	for _, side in { -3.5, 3.5 } do
		local right = doorCF.RightVector * side
		part({
			Name = "Window",
			Size = Vector3.new(1.6, 1.6, 0.3),
			CFrame = doorCF + right + Vector3.new(0, height - 7, 0),
			Color = COLORS.Window,
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		})
	end
end

-- دكان مفتوح على الزقاق، فيه مكان للفيوز
local function shop(parent: Instance, center: Vector3, openDir: Vector3): CFrame
	local model = Instance.new("Model")
	model.Name = "Shop"
	model.Parent = parent

	local size, height, t = 13, 11, 1
	local cf = CFrame.lookAt(center, center + openDir) -- LookVector = جهة الفتحة
	local function wall(localPos: Vector3, wallSize: Vector3)
		part({
			Name = "Wall",
			Size = wallSize,
			CFrame = cf * CFrame.new(localPos),
			Color = COLORS.Mud,
			Material = Enum.Material.Sandstone,
			Parent = model,
		})
	end
	wall(Vector3.new(0, height / 2, size / 2 - t / 2), Vector3.new(size, height, t)) -- الخلف
	wall(Vector3.new(-size / 2 + t / 2, height / 2, 0), Vector3.new(t, height, size)) -- يسار
	wall(Vector3.new(size / 2 - t / 2, height / 2, 0), Vector3.new(t, height, size)) -- يمين
	wall(Vector3.new(0, height + t / 2, 0), Vector3.new(size, t, size)) -- سقف
	wall(Vector3.new(0, height - 1.5, -size / 2 + t / 2), Vector3.new(size, 3, t)) -- عتبة فوق الفتحة
	crenellations(model, center, size, height + t)

	-- رف خشب في الخلف
	part({
		Name = "Counter",
		Size = Vector3.new(8, 3, 2.5),
		CFrame = cf * CFrame.new(0, 1.5, size / 2 - 2.5),
		Color = COLORS.Wood,
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})

	-- مكان الفيوز فوق الرف
	return cf * CFrame.new(0, 3.6, size / 2 - 2.5)
end

local function palm(parent: Instance, pos: Vector3)
	local model = Instance.new("Model")
	model.Name = "Palm"
	model.Parent = parent
	part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(16, 1.4, 1.4),
		CFrame = CFrame.new(pos + Vector3.new(0, 8, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = COLORS.Trunk,
		Material = Enum.Material.Wood,
		Parent = model,
	})
	for i = 0, 5 do
		local yaw = math.rad(i * 60)
		part({
			Name = "Frond",
			Size = Vector3.new(1.2, 0.3, 7),
			CFrame = CFrame.new(pos + Vector3.new(0, 16, 0))
				* CFrame.Angles(0, yaw, 0)
				* CFrame.Angles(math.rad(25), 0, 0)
				* CFrame.new(0, 0, -3.2),
			Color = COLORS.Leaf,
			Material = Enum.Material.Grass,
			CanCollide = false,
			Parent = model,
		})
	end
end

local function bench(parent: Instance, cf: CFrame)
	part({
		Name = "Dakka",
		Size = Vector3.new(8, 1.6, 2.6),
		CFrame = cf * CFrame.new(0, 0.8, 0),
		Color = COLORS.Bench,
		Material = Enum.Material.Sandstone,
		Parent = parent,
	})
end

--[[ يرجع:
	folder, lampPositions, fuseSpots (CFrames), lanternPosition,
	spawnPoints (CFrames), joodSpawns (Vector3), wanderPoints (Vector3)
]]
function MapBuilder.build()
	local old = workspace:FindFirstChild("Hara")
	if old then
		old:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "Hara"
	folder.Parent = workspace

	local rng = Random.new(Config.MapSeed)
	local half = Config.MapHalf

	part({
		Name = "Ground",
		Size = Vector3.new(half * 2 + 4, 2, half * 2 + 4),
		Position = Vector3.new(0, -1, 0),
		Color = COLORS.Ground,
		Material = Enum.Material.Ground,
		Parent = folder,
	})

	-- السور الخارجي
	for _, w in
		{
			{ Vector3.new(0, 12, half + 1), Vector3.new(half * 2 + 4, 24, 2) },
			{ Vector3.new(0, 12, -half - 1), Vector3.new(half * 2 + 4, 24, 2) },
			{ Vector3.new(half + 1, 12, 0), Vector3.new(2, 24, half * 2 + 4) },
			{ Vector3.new(-half - 1, 12, 0), Vector3.new(2, 24, half * 2 + 4) },
		}
	do
		part({
			Name = "OuterWall",
			Position = w[1],
			Size = w[2],
			Color = COLORS.MudDark,
			Material = Enum.Material.Sandstone,
			Parent = folder,
		})
	end

	local houses = Instance.new("Folder")
	houses.Name = "Houses"
	houses.Parent = folder

	local fuseSpots = {}

	for _, bx in Config.BlockCenters do
		for _, bz in Config.BlockCenters do
			local isCenter = math.abs(bx) < 30 and math.abs(bz) < 30
			if not isCenter then
				-- أي بيت في هذا البلوك يصير دكان؟
				local shopSlot = rng:NextInteger(1, 4)
				local slot = 0
				for _, sx in { -7, 7 } do
					for _, sz in { -7, 7 } do
						slot += 1
						local c = Vector3.new(bx + sx, 0, bz + sz)
						local xDir = Vector3.new(math.sign(sx), 0, 0)
						local zDir = Vector3.new(0, 0, math.sign(sz))
						if slot == shopSlot then
							local spot = shop(houses, c, xDir)
							table.insert(fuseSpots, spot)
						else
							local dir = rng:NextNumber() < 0.5 and xDir or zDir
							house(houses, c, rng:NextInteger(12, 22), dir, rng)
						end
					end
				end
			end
		end
	end

	-- الساحة: نخل ودكات
	local square = Instance.new("Folder")
	square.Name = "Square"
	square.Parent = folder
	for _, p in
		{
			Vector3.new(-24, 0, -24),
			Vector3.new(24, 0, -24),
			Vector3.new(-24, 0, 24),
			Vector3.new(24, 0, 24),
		}
	do
		palm(square, p)
	end
	for _, b in
		{
			CFrame.new(0, 0, -16),
			CFrame.new(0, 0, 16),
			CFrame.new(-16, 0, 0) * CFrame.Angles(0, math.rad(90), 0),
			CFrame.new(16, 0, 0) * CFrame.Angles(0, math.rad(90), 0),
		}
	do
		bench(square, b)
	end

	-- نقاط البداية حول الفانوس
	local spawnPoints = {}
	for i = 0, 7 do
		local a = math.rad(i * 45)
		local p = Vector3.new(math.cos(a) * 9, 3, math.sin(a) * 9)
		table.insert(spawnPoints, CFrame.lookAt(p, Vector3.new(0, 3, 0)))
	end

	-- نقاط تجول جود: كل تقاطعات الأزقة
	local wanderPoints = {}
	for _, x in Config.Alleys do
		for _, z in Config.Alleys do
			if not (math.abs(x) < 30 and math.abs(z) < 30) then
				table.insert(wanderPoints, Vector3.new(x, 0, z))
			end
		end
	end

	return {
		folder = folder,
		lampPositions = Config.LampPositions,
		fuseSpots = fuseSpots,
		lanternPosition = Vector3.new(0, 0, 0),
		spawnPoints = spawnPoints,
		joodSpawns = {
			Vector3.new(-80, 0, 40),
			Vector3.new(80, 0, -40),
			Vector3.new(40, 0, 80),
			Vector3.new(-40, 0, -80),
		},
		wanderPoints = wanderPoints,
	}
end

return MapBuilder
