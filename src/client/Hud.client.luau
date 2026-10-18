-- واجهة اللاعب: الهدف، البطارية، الفيوز، الخطر، زر الكشاف، والتنبيهات

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local state = ReplicatedStorage:WaitForChild("GameState")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local notifyEvent = remotes:WaitForChild("Notify") :: RemoteEvent
local flashEvent = remotes:WaitForChild("ToggleFlash") :: RemoteEvent

local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

local gui = Instance.new("ScreenGui")
gui.Name = "JoodHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- طبقة الخطر الحمراء
local danger = Instance.new("Frame")
danger.Name = "Danger"
danger.Size = UDim2.fromScale(1, 1)
danger.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
danger.BackgroundTransparency = 1
danger.BorderSizePixel = 0
danger.ZIndex = 0
danger.Parent = gui

local function label(name: string, pos: UDim2, size: UDim2, textSize: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = pos
	l.Size = size
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.fromRGB(245, 235, 215)
	l.TextStrokeTransparency = 0.4
	l.FontFace = FONT
	l.TextSize = textSize
	l.TextWrapped = true
	l.Text = ""
	l.Parent = gui
	return l
end

local objective = label("Objective", UDim2.new(0.5, 0, 0, 46), UDim2.new(0.9, 0, 0, 34), 22)
local sub = label("Sub", UDim2.new(0.5, 0, 0, 82), UDim2.new(0.9, 0, 0, 26), 18)
sub.TextColor3 = Color3.fromRGB(255, 215, 110)
local big = label("Big", UDim2.new(0.5, 0, 0.38, 0), UDim2.new(0.9, 0, 0, 60), 34)
local toast = label("Toast", UDim2.new(0.5, 0, 0.62, 0), UDim2.new(0.9, 0, 0, 30), 20)
toast.TextTransparency = 1
toast.TextStrokeTransparency = 1

-- شريط البطارية
local batteryBack = Instance.new("Frame")
batteryBack.Name = "Battery"
batteryBack.AnchorPoint = Vector2.new(0.5, 1)
batteryBack.Position = UDim2.new(0.5, 0, 1, -24)
batteryBack.Size = UDim2.fromOffset(180, 12)
batteryBack.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
batteryBack.BackgroundTransparency = 0.3
batteryBack.BorderSizePixel = 0
batteryBack.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = batteryBack
local batteryFill = Instance.new("Frame")
batteryFill.Size = UDim2.fromScale(1, 1)
batteryFill.BackgroundColor3 = Color3.fromRGB(255, 220, 120)
batteryFill.BorderSizePixel = 0
batteryFill.Parent = batteryBack
corner:Clone().Parent = batteryFill
local batteryText = label("BatteryText", UDim2.new(0.5, 0, 1, -48), UDim2.fromOffset(200, 20), 14)
batteryText.Text = "🔦 الكشاف"

-- زر/مفتاح الكشاف (F في الكمبيوتر، زر على الجوال)
local function onFlash(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		flashEvent:FireServer()
	end
	return Enum.ContextActionResult.Sink
end
ContextActionService:BindAction("JoodFlash", onFlash, true, Enum.KeyCode.F, Enum.KeyCode.ButtonR1)
ContextActionService:SetTitle("JoodFlash", "كشاف")
ContextActionService:SetPosition("JoodFlash", UDim2.new(1, -150, 1, -150))

-- تنبيهات
local toastToken = 0
notifyEvent.OnClientEvent:Connect(function(text: string)
	toastToken += 1
	local token = toastToken
	toast.Text = text
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.4
	task.delay(3, function()
		if token == toastToken then
			local info = TweenInfo.new(0.6)
			TweenService:Create(toast, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end)

local function objectiveText(): (string, string)
	local phase = state:GetAttribute("Phase")
	local on = state:GetAttribute("LampsOn") or 0
	local total = state:GetAttribute("LampsTotal") or 6
	local cd = state:GetAttribute("Countdown") or 0
	if phase == "Waiting" then
		return "بانتظار اللاعبين...", ""
	elseif phase == "Intermission" then
		return "الجولة تبدأ بعد " .. cd, ""
	elseif phase == "Grace" then
		return "الحارة مظلمة... دوّروا الفيوزات في الدكاكين", "جود تطلع بعد " .. cd
	elseif phase == "Play" then
		if on >= total then
			return "كل الأعمدة شغالة! روحوا للفانوس الكبير في الساحة", ""
		end
		return "شغّلوا أعمدة الإنارة: " .. on .. " / " .. total, ""
	elseif phase == "Finale" then
		local p = math.floor((state:GetAttribute("FinaleProgress") or 0) * 100)
		return "دافعوا! خلّوا الأعمدة شغالة — الفانوس " .. p .. "%", "الأعمدة: " .. on .. " / " .. total
	end
	return "", ""
end

RunService.RenderStepped:Connect(function()
	local phase = state:GetAttribute("Phase")
	local main, second = objectiveText()
	objective.Text = main

	local extra = {}
	if second ~= "" then
		table.insert(extra, second)
	end
	if player:GetAttribute("HasFuse") then
		table.insert(extra, "معك فيوز ⚡")
	end
	sub.Text = table.concat(extra, "   •   ")

	if phase == "Win" or phase == "Lose" then
		big.Text = state:GetAttribute("Message") or ""
	elseif player:GetAttribute("Downed") then
		big.Text = "طحت! خلّ أحد ينقذك"
	elseif player:GetAttribute("Out") and phase ~= "Intermission" and phase ~= "Waiting" then
		big.Text = "طلعت من الجولة... انتظر الجولة الجاية"
	else
		big.Text = ""
	end

	local battery = player:GetAttribute("Battery") or 0
	batteryFill.Size = UDim2.fromScale(math.clamp(battery / 100, 0, 1), 1)
	batteryFill.BackgroundColor3 = battery < 25 and Color3.fromRGB(230, 80, 60) or Color3.fromRGB(255, 220, 120)
	batteryText.Text = player:GetAttribute("FlashOn") and "🔦 الكشاف شغال" or "🔦 الكشاف"

	-- قرب جود
	local alpha = 1
	local jood = workspace:FindFirstChild("Jood")
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if jood and root and jood.PrimaryPart then
		local d = (jood.PrimaryPart.Position - root.Position).Magnitude
		if d < 40 then
			local pulse = 0.5 + 0.5 * math.sin(os.clock() * (6 + (40 - d) / 4))
			alpha = 1 - (1 - d / 40) * (0.35 + 0.2 * pulse)
		end
	end
	danger.BackgroundTransparency = alpha
end)
