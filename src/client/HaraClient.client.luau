-- Arabic HUD, keyboard/touch/gamepad input and local-only presentation.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("HaraShared")
local event = shared:WaitForChild("HaraEvent")
local world = workspace:WaitForChild("Hara")
local joud = world:WaitForChild("Joud")

-- Build the embedded realistic character before constructing the jumpscare clone.
local loadingGui = Instance.new("ScreenGui")
loadingGui.Name = "JoudLoading"
loadingGui.ResetOnSpawn = false
loadingGui.IgnoreGuiInset = true
loadingGui.DisplayOrder = 100
local loadingLabel = Instance.new("TextLabel")
loadingLabel.Size = UDim2.fromScale(1, 1)
loadingLabel.BackgroundColor3 = Color3.fromRGB(8, 15, 20)
loadingLabel.TextColor3 = Color3.fromRGB(224, 211, 207)
loadingLabel.Font = Enum.Font.GothamMedium
loadingLabel.TextSize = 25
loadingLabel.TextWrapped = true
loadingLabel.Text = "جود — مجنونة الحارة\nتجهيز الحارة…"
loadingLabel.Parent = loadingGui
loadingGui.Parent = player:WaitForChild("PlayerGui")
-- كل مجسّم يتحمّل لحاله؛ لو فشل واحد يبقى الشكل المبسّط واللعب شغال
local joudReady, joudFailure = pcall(function()
    require(shared:WaitForChild("RealisticJoud")).Attach(joud, function(value)
        loadingLabel.Text = "جود — مجنونة الحارة\nتجهيز الحارة… " .. tostring(math.floor(value * 40)) .. "%"
    end)
end)
local restReady, restFailure = pcall(function()
    require(shared:WaitForChild("RestHouse")).Attach(world, function(value)
        loadingLabel.Text = "تجهيز الحارة والاستراحة… " .. tostring(math.floor(40 + value * 60)) .. "%"
    end)
end)
loadingGui:Destroy()
local appearanceReady = joudReady and restReady
if not joudReady then warn("Realistic Joud failed (simple look used). Enable Allow Mesh / Image APIs. " .. tostring(joudFailure)) end
if not restReady then warn("Rest house mesh failed (collision blocks shown). " .. tostring(restFailure)) end

local camera = workspace.CurrentCamera
local active, hidden, sprinting = false, false, false
local muted, reduced, lampOn = false, false, true
local hasRope, sweets = false, 0
local stamina, remaining, lives = 100, 600, 3
local menuMode = true
local catchingUntil, toastToken = 0, 0
local phase = "Idle"
local baseColor = Color3.fromRGB(230,228,217)
local accent = Color3.fromRGB(222,123,112)

local function new(class, parent, properties)
    local object = Instance.new(class)
    for key, value in pairs(properties or {}) do object[key] = value end
    object.Parent = parent
    return object
end
local gui = new("ScreenGui", player:WaitForChild("PlayerGui"), {
    Name = "HaraHUD", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 20})
local function text(parent, value, size, position, dimensions, align)
    return new("TextLabel", parent, {BackgroundTransparency = 1, Text = value,
        Font = Enum.Font.GothamMedium, TextColor3 = baseColor, TextSize = size,
        Position = position, Size = dimensions, TextWrapped = true,
        TextXAlignment = align or Enum.TextXAlignment.Center})
end
local function corner(parent, radius) new("UICorner", parent, {CornerRadius = UDim.new(0,radius or 12)}) end
local function button(parent, value, position, dimensions, callback)
    local b = new("TextButton", parent, {Text = value, Position = position, Size = dimensions,
        BackgroundColor3 = Color3.fromRGB(34,42,47), TextColor3 = baseColor,
        Font = Enum.Font.GothamMedium, TextSize = 17, AutoButtonColor = true, BorderSizePixel = 0})
    corner(b,12)
    b.Activated:Connect(callback)
    return b
end
local shade = new("Frame", gui, {Size = UDim2.fromScale(1,1), BackgroundColor3 = Color3.fromRGB(4,10,15),
    BackgroundTransparency = 0.32, BorderSizePixel = 0})
local panel = new("Frame", shade, {AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.fromScale(0.5,0.5),
    Size = UDim2.new(1,-32,0,440), BackgroundColor3 = Color3.fromRGB(13,22,28), BackgroundTransparency = 0.09, BorderSizePixel = 0})
new("UISizeConstraint", panel, {MaxSize = Vector2.new(580,440)})
local menuScale = new("UIScale", panel, {Scale = 1})
local function resizeMenu()
    menuScale.Scale = math.min(1, math.max(0.55, (camera.ViewportSize.Y - 44) / 440))
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(resizeMenu)
resizeMenu()
corner(panel,22)
new("UIStroke", panel, {Color = Color3.fromRGB(72,83,85), Transparency = 0.4, Thickness = 1})
text(panel,"ABODEN GAMES",11,UDim2.new(0,20,0,19),UDim2.new(1,-40,0,20)).TextColor3 = Color3.fromRGB(142,166,168)
text(panel,"جود",62,UDim2.new(0,20,0,40),UDim2.new(1,-40,0,80)).TextColor3 = accent
local heading = text(panel,"مجنونة الحارة",28,UDim2.new(0,20,0,118),UDim2.new(1,-40,0,42))
local intro = text(panel,"لا تطوّل في الظلام… هي تسمع الركض",17,UDim2.new(0,24,0,166),UDim2.new(1,-48,0,36))
local instructions = text(panel,"٣ قطع كهرباء ← المولد ← مفتاح بيت جود ← بوابة الهروب\nاختبئ إذا اقتربت • الساحة الزرقاء آمنة",16,
    UDim2.new(0,24,0,210),UDim2.new(1,-48,0,65))
local playButton = button(panel,"ادخل الحارة",UDim2.new(0,24,0,295),UDim2.new(1,-48,0,52),function()
    event:FireServer("Ready")
end)
-- لو المجسّمات المفصلة ما تحمّلت: اللعب يكمل بالشكل المبسّط، والتنبيه لصاحب اللعبة فقط
if not appearanceReady and (RunService:IsStudio() or (game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId)) then
    intro.Text = "تنبيه للمطوّر: الشكل المفصل ما تحمّل — فعّل Allow Mesh / Image APIs"
end
playButton.BackgroundColor3 = Color3.fromRGB(139,57,51)
local muteButton
muteButton = button(panel,"الصوت: شغّال",UDim2.new(0,24,0,362),UDim2.new(0.5,-30,0,40),function()
    muted = not muted
    muteButton.Text = muted and "الصوت: صامت" or "الصوت: شغّال"
end)
local reducedButton
reducedButton = button(panel,"المؤثرات: كاملة",UDim2.new(0.5,6,0,362),UDim2.new(0.5,-30,0,40),function()
    reduced = not reduced
    reducedButton.Text = reduced and "المؤثرات: مخففة" or "المؤثرات: كاملة"
end)
text(panel,"حارة مرعبة • ثلاث فرص • جولة ١٠ دقائق",12,UDim2.new(0,12,0,409),UDim2.new(1,-24,0,20)).TextColor3 = Color3.fromRGB(143,158,164)

local hud = new("Frame", gui, {Size = UDim2.fromScale(1,1), BackgroundTransparency = 1, Visible = false})
local top = new("Frame",hud,{Position=UDim2.new(0,12,0,10), Size=UDim2.new(1,-24,0,48),
    BackgroundColor3=Color3.fromRGB(7,16,22),BackgroundTransparency=0.2,BorderSizePixel=0})
corner(top)
local timerLabel=text(top,"10:00",22,UDim2.new(0,12,0,0),UDim2.new(0.25,-12,1,0),Enum.TextXAlignment.Left)
local lifeLabel=text(top,"٣ فرص",14,UDim2.new(0.25,0,0,0),UDim2.new(0.25,0,1,0))
text(top,"مجنونة الحارة",17,UDim2.new(0.5,0,0,0),UDim2.new(0.5,-14,1,0),Enum.TextXAlignment.Right)
local objectiveBox=new("Frame",hud,{Position=UDim2.new(0.5,0,0,68),AnchorPoint=Vector2.new(0.5,0),
    Size=UDim2.new(1,-40,0,48),BackgroundColor3=Color3.fromRGB(7,16,22),BackgroundTransparency=0.27,BorderSizePixel=0})
new("UISizeConstraint",objectiveBox,{MaxSize=Vector2.new(580,48)})
corner(objectiveBox)
local objective=text(objectiveBox,"اجمع قطع الكهرباء: ٠ / ٣",16,UDim2.new(0,10,0,0),UDim2.new(1,-20,1,0))
local danger=text(hud,"",17,UDim2.new(0.15,0,0.25,0),UDim2.new(0.7,0,0,32))
danger.TextColor3=accent
local reticle=text(hud,"·",26,UDim2.new(0.5,-10,0.5,-15),UDim2.fromOffset(20,30))
local bar=new("Frame",hud,{Position=UDim2.new(0.5,-80,1,-52),Size=UDim2.fromOffset(160,6),
    BackgroundColor3=Color3.fromRGB(38,48,55),BorderSizePixel=0})
corner(bar,3)
local barFill=new("Frame",bar,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(147,200,202),BorderSizePixel=0})
corner(barFill,3)
local keyboardHint=text(hud,"F كشاف   •   Shift ركض   •   E تفاعل",12,UDim2.new(0.5,-180,1,-34),UDim2.fromOffset(360,23))
keyboardHint.Visible=not UserInputService.TouchEnabled

local function setSprint(on)
    sprinting = on
    event:FireServer("Sprint",on)
end
local flashButton=button(hud,"كشاف",UDim2.new(1,-186,0.66,0),UDim2.fromOffset(76,48),function() lampOn=not lampOn end)
local runButton=button(hud,"ركض",UDim2.new(1,-98,0.66,0),UDim2.fromOffset(76,48),function() setSprint(not sprinting) end)
flashButton.Visible=UserInputService.TouchEnabled
runButton.Visible=UserInputService.TouchEnabled
local settingsButton=button(hud,"الصوت",UDim2.new(1,-86,0,124),UDim2.fromOffset(72,34),function()
    muted=not muted
    muteButton.Text=muted and "الصوت: صامت" or "الصوت: شغّال"
end)
local hideShade=new("Frame",hud,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=0.06,
    BorderSizePixel=0,Visible=false,ZIndex=5})
local hideTitle=text(hideShade,"أنت مختبئ",28,UDim2.new(0,20,0.36,0),UDim2.new(1,-40,0,60))
hideTitle.ZIndex=6
local hideTimer=text(hideShade,"",18,UDim2.new(0,20,0.51,0),UDim2.new(1,-40,0,35))
hideTimer.ZIndex=6
local leaveButton=button(hideShade,"اخرج من المخبأ",UDim2.new(0.5,-105,0.65,0),UDim2.fromOffset(210,52),function() event:FireServer("LeaveHide") end)
leaveButton.ZIndex=6

local notice=text(gui,"",19,UDim2.new(0.1,0,0.76,0),UDim2.new(0.8,0,0,74))
notice.ZIndex=30
notice.TextStrokeTransparency=0.5
local scare=new("Frame",gui,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(13,7,15),BorderSizePixel=0,Visible=false,ZIndex=40})
local viewport=new("ViewportFrame",scare,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=41,
    Ambient=Color3.fromRGB(110,90,100),LightColor=Color3.fromRGB(235,170,160),LightDirection=Vector3.new(-1,-0.5,-2)})
local worldModel=new("WorldModel",viewport,{})
local portrait=joud:Clone()
for _, item in ipairs(portrait:GetDescendants()) do
    if item:IsA("BasePart") then item.Anchored=true end
    if item:IsA("BillboardGui") or item:IsA("Script") then item:Destroy() end
end
portrait.Parent=worldModel
portrait:PivotTo(CFrame.new(0,3.2,0))
local portraitCamera=new("Camera",viewport,{FieldOfView=37,CFrame=CFrame.lookAt(Vector3.new(0,4.8,-7.5),Vector3.new(0,4.5,0))})
viewport.CurrentCamera=portraitCamera
local caughtText=text(scare,"لقيتك…",34,UDim2.new(0,0,0.8,0),UDim2.new(1,0,0,60))
caughtText.ZIndex=42
caughtText.TextColor3=accent

local sounds=new("Folder",SoundService,{Name="HaraLocalAudio"})
local wind=new("Sound",sounds,{Name="LowWind",SoundId="rbxasset://sounds/action_falling.mp3",Looped=true,Volume=0.07,PlaybackSpeed=0.42})
local thud=new("Sound",sounds,{Name="CatchThud",SoundId="rbxasset://sounds/action_jump_land.mp3",Volume=0.45,PlaybackSpeed=0.55})
local steps=new("Sound",joud:WaitForChild("Head"),{Name="JoudFootsteps",SoundId="rbxasset://sounds/action_footsteps_plastic.mp3",
    Looped=true,Volume=0.5,PlaybackSpeed=0.8,RollOffMaxDistance=50,RollOffMinDistance=5})
local heartbeat=new("Sound",sounds,{Name="Pulse",SoundId="rbxasset://sounds/action_jump_land.mp3",Volume=0.15,PlaybackSpeed=0.48})
wind:Play()
steps:Play()
local lampPart=new("Part",workspace,{Name="LocalFlashlight",Size=Vector3.new(0.1,0.1,0.1),Anchored=true,
    Transparency=1,CanCollide=false,CanTouch=false,CanQuery=false})
local light=new("SpotLight",lampPart,{Face=Enum.NormalId.Front,Angle=62,Range=55,Brightness=2.4,Shadows=true,
    Color=Color3.fromRGB(230,239,225),Enabled=false})

local function showToast(value)
    toastToken=toastToken+1
    local token=toastToken
    notice.Text=value
    notice.TextTransparency=0
    task.delay(4,function()
        if token==toastToken then TweenService:Create(notice,TweenInfo.new(0.6),{TextTransparency=1}):Play() end
    end)
end
local function showMenu(result)
    active,hidden,sprinting=false,false,false
    menuMode=true
    hud.Visible=false
    shade.Visible=true
    player.CameraMode=Enum.CameraMode.Classic
    UserInputService.MouseBehavior=Enum.MouseBehavior.Default
    if result then
        heading.Text=result.win and "طلعت من الحارة" or "جود كانت أسرع"
        intro.Text=result.text
        instructions.Text="انتظر نهاية الجولة لتبدأ من جديد"
        playButton.Text="الجولة التالية"
    end
end
event.OnClientEvent:Connect(function(kind,data)
    if kind=="State" then
        phase=data.stage
        remaining=data.seconds
        local objectives={
            Fuses="اجمع قطع الكهرباء: "..data.count.." / "..data.required,
            Generator="شغّل المولد خلف الورشة • الركن الشمالي الشرقي",
            Key="خذ المفتاح من بيت جود • البيت الوردي آخر الحارة",
            Gate="افتح البوابة الحديدية في نهاية الشارع",
            Escape="البوابة مفتوحة… اخرج من الحارة!",
            Idle="اجمع قطع الكهرباء: ٠ / ٣",Ended="انتهت الجولة"}
        objective.Text=objectives[phase] or ""
        if phase=="Idle" then
            heading.Text="مجنونة الحارة"
            intro.Text="لا تطوّل في الظلام… هي تسمع الركض"
            instructions.Text="٣ قطع كهرباء ← المولد ← مفتاح بيت جود ← بوابة الهروب\nاختبئ إذا اقتربت • الساحة الزرقاء آمنة"
            playButton.Text="ادخل الحارة"
            if not active then showMenu() end
        end
    elseif kind=="Started" then
        active,menuMode=true,false
        shade.Visible=false
        hud.Visible=true
        camera.CameraType=Enum.CameraType.Custom
        player.CameraMode=Enum.CameraMode.LockFirstPerson
    elseif kind=="Profile" then
        active=data.active
        stamina,lives,hidden=data.stamina,data.lives,data.hidden
        if stamina<2 then sprinting=false end
        hideShade.Visible=hidden
        hideTimer.Text="باقي "..data.hideSeconds.." ثانية • E للخروج"
        hasRope=data.rope==true
        sweets=data.sweets or 0
        lifeLabel.Text="الفرص: "..lives.." / 3"..(sweets>0 and ("   🍬 "..sweets) or "")
    elseif kind=="Toast" then showToast(data)
    elseif kind=="Caught" then
        setSprint(false)
        hidden=false
        catchingUntil=os.clock()+1.35
        scare.Visible=not reduced
        if reduced then showToast("جود لقتك… رجوع للساحة") end
        if not muted then thud:Play() end
        task.delay(1.35,function() scare.Visible=false end)
    elseif kind=="Finish" then
        if data and data.win and not reduced then
            local character=player.Character
            local root=character and character:FindFirstChild("HumanoidRootPart")
            if root then
                local confetti=new("ParticleEmitter",root,{Rate=0,Lifetime=NumberRange.new(1.5,2.6),
                    Speed=NumberRange.new(18,32),SpreadAngle=Vector2.new(60,60),Rotation=NumberRange.new(0,360),
                    RotSpeed=NumberRange.new(-200,200),Acceleration=Vector3.new(0,-30,0),
                    Size=NumberSequence.new(0.35),LightEmission=0.6,
                    Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255,80,120)),
                        ColorSequenceKeypoint.new(0.5,Color3.fromRGB(255,210,50)),ColorSequenceKeypoint.new(1,Color3.fromRGB(80,200,255))})})
                confetti:Emit(120)
                task.delay(4,function() confetti:Destroy() end)
            end
        end
        showMenu(data)
    elseif kind=="Cue" then
        if not muted then
            thud.PlaybackSpeed = (data=="tied" and 1.4) or (data=="untied" and 0.4) or 0.55
            thud:Play()
        end
    end
end)

ContextActionService:BindAction("HaraSprint",function(_, inputState)
    if inputState==Enum.UserInputState.Begin and active then setSprint(true)
    elseif inputState==Enum.UserInputState.End or inputState==Enum.UserInputState.Cancel then setSprint(false) end
    return Enum.ContextActionResult.Pass
end,false,Enum.KeyCode.LeftShift,Enum.KeyCode.ButtonL3)
ContextActionService:BindAction("HaraLamp",function(_,inputState)
    if inputState==Enum.UserInputState.Begin and active then lampOn=not lampOn end
    return Enum.ContextActionResult.Pass
end,false,Enum.KeyCode.F,Enum.KeyCode.ButtonY)
ContextActionService:BindAction("HaraLeaveHide",function(_,inputState)
    if inputState==Enum.UserInputState.Begin and hidden then event:FireServer("LeaveHide"); return Enum.ContextActionResult.Sink end
    return Enum.ContextActionResult.Pass
end,false,Enum.KeyCode.E,Enum.KeyCode.ButtonB)
UserInputService.WindowFocusReleased:Connect(function() if sprinting then setSprint(false) end end)

-- الحبل: Q في الكيبورد، X في اليد، وزر «اربط» على الجوال
local function useRope()
    if active and hasRope and not hidden then event:FireServer("Rope") end
end
ContextActionService:BindAction("HaraRope",function(_,inputState)
    if inputState==Enum.UserInputState.Begin and hasRope then useRope(); return Enum.ContextActionResult.Sink end
    return Enum.ContextActionResult.Pass
end,false,Enum.KeyCode.Q,Enum.KeyCode.ButtonX)
local ropeButton=button(hud,"🪢 اربط",UDim2.new(1,-186,0.66,-58),UDim2.fromOffset(164,48),useRope)
ropeButton.BackgroundColor3=Color3.fromRGB(140,98,46)
ropeButton.Visible=false
local ropeHint=text(hud,"",14,UDim2.new(0.5,-160,1,-78),UDim2.fromOffset(320,22))
ropeHint.TextColor3=Color3.fromRGB(240,205,140)

-- وضع الجوال: واجهة أصغر وأقل عشان ساحة اللعب تبان
if UserInputService.TouchEnabled then
    top.Size=UDim2.fromOffset(176,30)
    top.Position=UDim2.new(1,-184,0,6)
    for _,c in ipairs(top:GetChildren()) do
        if c:IsA("TextLabel") and c~=timerLabel and c~=lifeLabel then c.Visible=false end
    end
    timerLabel.TextSize=16
    timerLabel.Position=UDim2.new(0,8,0,0)
    timerLabel.Size=UDim2.new(0.38,-8,1,0)
    lifeLabel.TextSize=11
    lifeLabel.Position=UDim2.new(0.38,0,0,0)
    lifeLabel.Size=UDim2.new(0.62,-6,1,0)
    objectiveBox.Position=UDim2.new(0.5,0,0,6)
    objectiveBox.Size=UDim2.new(0.4,0,0,30)
    objective.TextSize=13
    danger.TextSize=14
    danger.Position=UDim2.new(0.25,0,0,40)
    danger.Size=UDim2.new(0.5,0,0,22)
    notice.TextSize=14
    notice.Position=UDim2.new(0.25,0,0,62)
    notice.Size=UDim2.new(0.5,0,0,34)
    settingsButton.Visible=false
    -- أزرار صغيرة تحت في نص الشاشة
    flashButton.Size=UDim2.fromOffset(58,38)
    flashButton.Position=UDim2.new(0.5,-62,1,-48)
    flashButton.TextSize=14
    runButton.Size=UDim2.fromOffset(58,38)
    runButton.Position=UDim2.new(0.5,4,1,-48)
    runButton.TextSize=14
    ropeButton.Size=UDim2.fromOffset(120,34)
    ropeButton.Position=UDim2.new(0.5,-60,1,-98)
    ropeButton.TextSize=14
    bar.Position=UDim2.new(0.5,-60,1,-58)
    bar.Size=UDim2.fromOffset(120,5)
    ropeHint.Visible=false
end

-- النطّاطات في الاستراحة: النطّ يصير من جهاز اللاعب نفسه
local CollectionService=game:GetService("CollectionService")
local lastBounce=0
local function hookTrampoline(pad)
    if not pad:IsA("BasePart") then return end
    pad.Touched:Connect(function(hit)
        local character=player.Character
        if not character or not hit:IsDescendantOf(character) then return end
        local now=os.clock()
        if now-lastBounce<0.45 then return end
        lastBounce=now
        local root=character:FindFirstChild("HumanoidRootPart")
        if root then
            local v=root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity=Vector3.new(v.X,pad:GetAttribute("Bounce") or 55,v.Z)
            if not muted then thud.PlaybackSpeed=1.8; thud:Play() end
        end
    end)
end
for _,pad in ipairs(CollectionService:GetTagged("JoodTrampoline")) do hookTrampoline(pad) end
CollectionService:GetInstanceAddedSignal("JoodTrampoline"):Connect(hookTrampoline)

local joints={}
for _, instance in ipairs(joud:GetDescendants()) do
    if instance:IsA("Motor6D") then joints[instance.Name]=instance end
end
local pulseTime=0
local function animate(t)
    local speed=joud.HumanoidRootPart.AssemblyLinearVelocity.Magnitude
    local walking=speed>0.6
    local stride=walking and math.sin(t*(joud:GetAttribute("Mood")=="Hunt" and 10 or 6))*0.65 or 0
    if joints["Left Hip"] then joints["Left Hip"].Transform=CFrame.Angles(stride,0,0) end
    if joints["Right Hip"] then joints["Right Hip"].Transform=CFrame.Angles(-stride,0,0) end
    if joints["Left Shoulder"] then joints["Left Shoulder"].Transform=CFrame.Angles(-stride,0,-0.1) end
    if joints["Right Shoulder"] then joints["Right Shoulder"].Transform=CFrame.Angles(stride,0,0.1) end
    if joints.Neck then joints.Neck.Transform=CFrame.Angles(0,math.sin(t*0.65)*0.1,-0.12+math.sin(t)*0.025) end
    steps.Volume=muted and 0 or (walking and 0.45 or 0)
    steps.PlaybackSpeed=joud:GetAttribute("Mood")=="Hunt" and 1.35 or 0.75
end
RunService.PreSimulation:Connect(function() animate(os.clock()) end)
RunService:BindToRenderStep("HaraPresentation",Enum.RenderPriority.Camera.Value+1,function(dt)
    local t=os.clock()
    if menuMode then
        camera.CameraType=Enum.CameraType.Scriptable
        camera.CFrame=CFrame.lookAt(Vector3.new(12+math.sin(t*0.08)*3,8,86),Vector3.new(-8,5,40))
    end
    light.Enabled=active and lampOn and not hidden
    lampPart.CFrame=camera.CFrame
    wind.Volume=muted and 0 or 0.065
    local character=player.Character
    local root=character and character:FindFirstChild("HumanoidRootPart")
    local distance=root and (root.Position-joud.HumanoidRootPart.Position).Magnitude or 999
    local threat=active and not hidden and joud:GetAttribute("Mood")=="Hunt" and distance<48
    local tied=joud:GetAttribute("Mood")=="Tied"
    danger.Text=(active and tied and "جود مربوطة! اهربوا 🏃") or (threat and "لا تلتفت… اركض!") or ""
    ropeButton.Visible=active and hasRope and not hidden and UserInputService.TouchEnabled
    ropeHint.Text=(active and hasRope and not hidden) and (UserInputService.TouchEnabled and "معك حبل 🪢 قرّب من جود واضغط «اربط»" or "معك حبل 🪢 قرّب من جود واضغط Q") or ""
    barFill.Size=UDim2.fromScale(stamina/100,1)
    barFill.BackgroundColor3=stamina<25 and accent or Color3.fromRGB(147,200,202)
    runButton.Text=sprinting and "اهدأ" or "ركض"
    flashButton.Text=lampOn and "كشاف ✓" or "كشاف"
    timerLabel.Text=string.format("%02d:%02d",math.floor(remaining/60),remaining%60)
    timerLabel.TextColor3=remaining<60 and accent or baseColor
    local targetFov=active and sprinting and 78 or 70
    camera.FieldOfView=camera.FieldOfView+(targetFov-camera.FieldOfView)*math.min(1,dt*5)
    if threat and not muted and t>pulseTime then
        heartbeat.Volume=math.clamp((48-distance)/48,0.05,0.3)
        heartbeat:Play()
        pulseTime=t+0.62
    end
    if catchingUntil>t and not reduced then
        local z=-7.5+(1-(catchingUntil-t)/1.35)*1.5
        portraitCamera.CFrame=CFrame.lookAt(Vector3.new(0,4.8,z),Vector3.new(0,4.5,0))
    end
end)
player.CharacterAdded:Connect(function()
    if active then player.CameraMode=Enum.CameraMode.LockFirstPerson end
end)
event:FireServer("Sync")
