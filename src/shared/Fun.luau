-- أشياء فريحية في الحارة: نطّاطات، بالونات، وزينة إنارة في الاستراحة.
-- تُبنى من الخادم وقت التشغيل. النطّ نفسه يصير عند اللاعب (HaraClient) لأن جسمه يتحرك من جهازه.
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Fun = {}

-- مواقع فُحصت مقابل كتل التصادم في الاستراحة (بعيدة عن الجدران والممر)
local TRAMPOLINES = {
	Vector3.new(-225, 0.2, 12),
	Vector3.new(-245, 0.2, 14),
	Vector3.new(-235, 0.2, 25),
}
local BALLOONS = {
	Vector3.new(-14, 0.2, 128), -- طرف الساحة الآمنة
	Vector3.new(14, 0.2, 128),
	Vector3.new(-174, 0.2, 15), -- داخل بوابة الاستراحة
	Vector3.new(-174, 0.2, -15),
	Vector3.new(-215, 0.2, -20),
}
local LIGHT_ROW = { from = Vector3.new(-170, 10.5, 0), to = Vector3.new(-254, 10.5, 0) }

local PARTY = {
	Color3.fromRGB(255, 80, 120),
	Color3.fromRGB(255, 200, 40),
	Color3.fromRGB(70, 200, 120),
	Color3.fromRGB(80, 160, 255),
	Color3.fromRGB(190, 110, 255),
}

local function part(props): Part
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

local function trampoline(parent: Instance, pos: Vector3, color: Color3)
	local model = Instance.new("Model")
	model.Name = "Trampoline"
	model.Parent = parent
	local up = CFrame.Angles(0, 0, math.rad(90))
	part({
		Name = "Frame",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 9, 9),
		CFrame = CFrame.new(pos + Vector3.new(0, 0.6, 0)) * up,
		Color = Color3.fromRGB(30, 50, 90),
		Material = Enum.Material.Metal,
		Parent = model,
	})
	local pad = part({
		Name = "Pad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 7.6, 7.6),
		CFrame = CFrame.new(pos + Vector3.new(0, 1.3, 0)) * up,
		Color = color,
		Material = Enum.Material.Neon,
		Parent = model,
	})
	pad:SetAttribute("Bounce", 55)
	CollectionService:AddTag(pad, "JoodTrampoline")
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 12
	light.Brightness = 0.8
	light.Parent = pad
end

local function balloons(parent: Instance, base: Vector3, seed: number)
	local rng = Random.new(seed)
	local model = Instance.new("Model")
	model.Name = "Balloons"
	model.Parent = parent
	for i = 1, 5 do
		local offset = Vector3.new(rng:NextNumber(-1.6, 1.6), rng:NextNumber(7, 10), rng:NextNumber(-1.6, 1.6))
		local top = base + offset
		local ball = part({
			Name = "Balloon",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.2, 2.2, 2.2),
			Position = top,
			Color = PARTY[(i - 1) % #PARTY + 1],
			Material = Enum.Material.SmoothPlastic,
			Reflectance = 0.15,
			CanCollide = false,
			CastShadow = false,
			Parent = model,
		})
		local mid = (top + base) / 2
		part({
			Name = "String",
			Size = Vector3.new(0.06, (top - base).Magnitude - 1.1, 0.06),
			CFrame = CFrame.lookAt(mid, top) * CFrame.Angles(math.rad(90), 0, 0),
			Color = Color3.fromRGB(230, 230, 230),
			CanCollide = false,
			CastShadow = false,
			Parent = model,
		})
		TweenService:Create(
			ball,
			TweenInfo.new(1.6 + i * 0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Position = top + Vector3.new(0, 0.6, 0) }
		):Play()
	end
	part({
		Name = "Weight",
		Size = Vector3.new(0.8, 0.6, 0.8),
		Position = base + Vector3.new(0, 0.3, 0),
		Color = Color3.fromRGB(200, 40, 60),
		CanCollide = false,
		Parent = model,
	})
end

local function stringLights(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "StringLights"
	model.Parent = parent
	local a, b = LIGHT_ROW.from, LIGHT_ROW.to
	local length = (b - a).Magnitude
	local count = math.floor(length / 3)
	for i = 0, count do
		local t = i / count
		local sag = math.sin(t * math.pi * 4) ^ 2 * 1.2 -- تتدلّى بين الأعمدة
		local pos = a:Lerp(b, t) - Vector3.new(0, sag, 0)
		local color = PARTY[i % #PARTY + 1]
		local bulb = part({
			Name = "Bulb",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.6, 0.6, 0.6),
			Position = pos,
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
			Parent = model,
		})
		if i % 6 == 0 then
			local light = Instance.new("PointLight")
			light.Color = color
			light.Range = 16
			light.Brightness = 0.7
			light.Parent = bulb
		end
	end
end

function Fun.Build(world: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Fun"
	folder.Parent = world
	for i, pos in TRAMPOLINES do
		trampoline(folder, pos, PARTY[(i - 1) % #PARTY + 1])
	end
	for i, pos in BALLOONS do
		balloons(folder, pos, i * 31)
	end
	stringLights(folder)
	return folder
end

return Fun
