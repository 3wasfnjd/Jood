-- لوحات الحارة بطابع سعودي: لوحات بيوت بأسماء العوائل، لوحات محلات قديمة،
-- ولوحات طرق زرقاء. تُطبّق وقت التشغيل على لوحات الماب الموجودة (Sign_*).
local Signs = {}

local FAMILIES = { "آل سعيد", "آل ناصر", "آل حمد", "آل راشد", "آل منصور", "آل فهد", "آل عمر", "آل خالد", "آل سالم" }
local DIGITS = { "٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩" }

local function arabicNumber(n: number): string
	local s = tostring(n)
	return (s:gsub("%d", function(d)
		return DIGITS[tonumber(d) + 1]
	end))
end

local GREEN = Color3.fromRGB(0, 108, 53) -- أخضر سعودي
local CREAM = Color3.fromRGB(240, 228, 200)
local SAND = Color3.fromRGB(214, 190, 150)
local BROWN = Color3.fromRGB(92, 58, 32)
local GOLD = Color3.fromRGB(201, 162, 77)
local ROAD_BLUE = Color3.fromRGB(22, 74, 150)
local WHITE = Color3.fromRGB(250, 250, 245)

-- محلات الحارة: اسم جديد + سطر صغير + ألوان
local SHOPS = {
	["بقالة آخر الليل"] = { "تموينات آخر الليل", "مفتوح ٢٤ ساعة", GREEN, WHITE },
	["المخبز القديم"] = { "مخبز الحارة", "تميس • صامولي • معمول", Color3.fromRGB(176, 38, 38), WHITE },
	["ورشة الحارة"] = { "ورشة أبو سعد", "كهرباء وسباكة", Color3.fromRGB(30, 30, 34), Color3.fromRGB(255, 196, 0) },
	["المستودع"] = { "مستودع الحارة", "للإيجار", Color3.fromRGB(70, 70, 70), WHITE },
	["الفصل القديم"] = { "مدرسة الحارة الابتدائية", "وزارة التعليم", GREEN, WHITE },
	["الاستراحة"] = { "استراحة عبدالله", "حياكم الله", GREEN, GOLD },
}

local function new(class: string, parent: Instance?, props)
	local o = Instance.new(class)
	for k, v in props do
		(o :: any)[k] = v
	end
	o.Parent = parent
	return o
end

local function label(parent: Instance, text: string, color: Color3, pos: UDim2, size: UDim2, bold: boolean?)
	return new("TextLabel", parent, {
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color,
		TextScaled = true,
		Font = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium,
		Position = pos,
		Size = size,
		ZIndex = 3,
	})
end

local function frame(parent: Instance, color: Color3, pos: UDim2, size: UDim2, radius: number?)
	local f = new("Frame", parent, {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Position = pos,
		Size = size,
		ZIndex = 2,
	})
	if radius then
		new("UICorner", f, { CornerRadius = UDim.new(0, radius) })
	end
	return f
end

local function reset(gui: SurfaceGui)
	gui:ClearAllChildren()
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0.25
	gui.Brightness = 1.4
end

-- لوحة بيت: يمين اسم العائلة على رخام كريمي بإطار نجدي، يسار رقم المبنى أخضر
local function housePlate(gui: SurfaceGui, family: string, number: number)
	reset(gui)
	local bg = frame(gui, BROWN, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 10)
	local marble = frame(bg, CREAM, UDim2.fromScale(0.03, 0.08), UDim2.fromScale(0.94, 0.84), 8)
	new("UIStroke", marble, { Color = GOLD, Thickness = 3 })
	new("UIGradient", marble, {
		Color = ColorSequence.new(CREAM, SAND),
		Rotation = 90,
	})
	local numBox = frame(marble, GREEN, UDim2.fromScale(0.03, 0.1), UDim2.fromScale(0.26, 0.8), 6)
	label(numBox, arabicNumber(number), WHITE, UDim2.fromScale(0.08, 0.05), UDim2.fromScale(0.84, 0.9), true)
	label(marble, "بيت " .. family, BROWN, UDim2.fromScale(0.32, 0.08), UDim2.fromScale(0.65, 0.6), true)
	label(marble, "حي الحارة القديمة", Color3.fromRGB(120, 95, 70), UDim2.fromScale(0.32, 0.66), UDim2.fromScale(0.65, 0.26))
end

-- لوحة محل قديمة: خلفية ملونة، كتابة كبيرة، وسطر صغير
local function shopSign(gui: SurfaceGui, title: string, sub: string, bgColor: Color3, fg: Color3)
	reset(gui)
	gui.LightInfluence = 0 -- تضيء مثل لوحات المحلات بالليل
	local bg = frame(gui, bgColor, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 6)
	new("UIStroke", bg, { Color = fg, Thickness = 4 })
	label(bg, title, fg, UDim2.fromScale(0.05, 0.06), UDim2.fromScale(0.9, 0.6), true)
	label(bg, sub, fg, UDim2.fromScale(0.15, 0.66), UDim2.fromScale(0.7, 0.28))
end

-- لوحة طريق سعودية: أزرق وإطار أبيض
local function roadSign(gui: SurfaceGui, text: string)
	reset(gui)
	gui.LightInfluence = 0
	local bg = frame(gui, ROAD_BLUE, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 8)
	local inner = frame(bg, ROAD_BLUE, UDim2.fromScale(0.03, 0.1), UDim2.fromScale(0.94, 0.8), 6)
	new("UIStroke", inner, { Color = WHITE, Thickness = 3 })
	label(inner, text, WHITE, UDim2.fromScale(0.04, 0.08), UDim2.fromScale(0.92, 0.84), true)
end

local function spookyPlate(gui: SurfaceGui, title: string, sub: string, color: Color3)
	reset(gui)
	gui.LightInfluence = 0.6
	local bg = frame(gui, Color3.fromRGB(28, 22, 22), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 6)
	new("UIStroke", bg, { Color = Color3.fromRGB(80, 20, 20), Thickness = 3 })
	label(bg, title, color, UDim2.fromScale(0.05, 0.06), UDim2.fromScale(0.9, 0.62), true)
	label(bg, sub, Color3.fromRGB(170, 150, 150), UDim2.fromScale(0.1, 0.68), UDim2.fromScale(0.8, 0.26))
end

function Signs.Apply(world: Instance)
	for _, gui in world:GetDescendants() do
		if gui:IsA("SurfaceGui") and gui.Name == "Lettering" then
			local textLabel = gui:FindFirstChildWhichIsA("TextLabel", true)
			local text = textLabel and textLabel.Text or ""
			local houseNo = tonumber(text:match("^منزل%s*(%d+)$") or "")
			local ok, err = pcall(function()
				if houseNo then
					housePlate(gui, FAMILIES[(houseNo - 1) % #FAMILIES + 1], houseNo * 3 + 7)
				elseif SHOPS[text] then
					local s = SHOPS[text]
					shopSign(gui, s[1], s[2], s[3], s[4])
				elseif text == "بيت جود" then
					spookyPlate(gui, "بيت جود", "لا تقرّب…", Color3.fromRGB(220, 40, 40))
				elseif text == "بيت مهجور" then
					spookyPlate(gui, "بيت مهجور", "ممنوع الدخول", Color3.fromRGB(200, 170, 120))
				elseif text == "بيت ٧" then
					housePlate(gui, "آل سالم", 7)
				elseif text ~= "" then
					local display = text
					if text == "← الاستراحة" then
						display = "← استراحة عبدالله"
					end
					roadSign(gui, display)
				end
			end)
			if not ok then
				warn("[Signs] " .. text .. ": " .. tostring(err))
			end
		end
	end
end

return Signs
