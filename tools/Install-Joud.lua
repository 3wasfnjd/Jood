-- Run in Roblox Studio's Command Bar, in EDIT mode.
-- Select the imported Joud-Realistic Model first.
-- Built for the Joud-Hara map. Creates an untouched backup before editing.
local HEIGHT_METERS = 1.70
local FACING_DEGREES = 180 -- glTF front is +Z; Roblox characters look toward -Z.
local HEIGHT_STUDS = HEIGHT_METERS / 0.28

local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Stop Play before installing Joud.")
local Selection = game:GetService("Selection")
local selected = Selection:Get()
assert(#selected == 1 and selected[1]:IsA("Model"),
    "Select the imported character Model in Explorer, then run again.")
local source = selected[1]
local world = workspace:FindFirstChild("Hara")
local joud = world and world:FindFirstChild("Joud")
assert(joud and joud:IsA("Model"), "Expected Workspace > Hara > Joud.")
assert(source ~= joud and not source:IsDescendantOf(joud) and not joud:IsDescendantOf(source),
    "Select the newly imported character, not the original Joud or the Hara map.")
local root = joud:FindFirstChild("HumanoidRootPart")
assert(root and root:IsA("BasePart") and joud:FindFirstChildOfClass("Humanoid"),
    "Joud needs her original HumanoidRootPart and Humanoid.")
assert(source:FindFirstChildWhichIsA("MeshPart", true), "The selected model has no MeshParts.")
assert(source.Archivable and joud.Archivable, "Enable Archivable on both models first.")
local _, originalSize = source:GetBoundingBox()
assert(originalSize.Y > 0.001, "The imported model has no measurable height.")

local history = game:GetService("ChangeHistoryService")
history:SetWaypoint("Before realistic Joud installation")
local backups = game:GetService("ServerStorage"):FindFirstChild("JoudAppearanceBackups")
if not backups then
    backups = Instance.new("Folder")
    backups.Name = "JoudAppearanceBackups"
    backups.Parent = game:GetService("ServerStorage")
end
local backup = joud:Clone()
backup.Name = "JoudBeforeRealistic_" .. tostring(DateTime.now().UnixTimestampMillis)
backup.Parent = backups

-- Prepare the clone before touching the existing appearance.
local visual = source:Clone()
visual.Name = "RealisticAppearance"
for _, obj in ipairs(visual:GetDescendants()) do
    if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript")
        or obj:IsA("Humanoid") or obj:IsA("AnimationController")
        or obj:IsA("JointInstance") or obj:IsA("WeldConstraint")
        or obj:IsA("RigidConstraint") then
        obj:Destroy()
    elseif obj:IsA("BasePart") then
        obj.Anchored = true
        obj.CanCollide = false
        obj.CanTouch = false
        obj.CanQuery = false
        obj.Massless = true
    end
end
visual:ScaleTo(visual:GetScale() * HEIGHT_STUDS / originalSize.Y)
local box, size = visual:GetBoundingBox()
local boxToPivot = box:ToObjectSpace(visual:GetPivot())
-- Original R6 feet are three studs below HumanoidRootPart.
local destination = root.CFrame * CFrame.new(0, -3 + size.Y / 2, 0)
    * CFrame.Angles(0, math.rad(FACING_DEGREES), 0)
visual:PivotTo(destination * boxToPivot)

local main, largest = nil, -1
for _, obj in ipairs(visual:GetDescendants()) do
    if obj:IsA("MeshPart") then
        local volume = obj.Size.X * obj.Size.Y * obj.Size.Z
        if volume > largest then main, largest = obj, volume end
    end
end
assert(main, "Could not find the imported visible mesh.")
visual.PrimaryPart = main
for _, obj in ipairs(visual:GetDescendants()) do
    if obj:IsA("BasePart") and obj ~= main then
        local weld = Instance.new("WeldConstraint")
        weld.Name = "AppearanceAttachment"
        weld.Part0, weld.Part1 = main, obj
        weld.Parent = obj
    end
end

local previous = joud:FindFirstChild("RealisticAppearance")
if previous then previous:Destroy() end
local previousMotor = root:FindFirstChild("JoudAppearanceMotor")
if previousMotor then previousMotor:Destroy() end
-- Preserve the original moving rig and collision body for the map's AI.
for _, obj in ipairs(joud:GetDescendants()) do
    if obj:IsA("BasePart") or obj:IsA("Decal") or obj:IsA("Texture") then
        if obj:GetAttribute("JoudOriginalTransparency") == nil then
            obj:SetAttribute("JoudOriginalTransparency", obj.Transparency)
        end
        obj.Transparency = 1
    end
end
visual.Parent = joud
local presentation = Instance.new("Motor6D")
presentation.Name = "JoudAppearanceMotor"
presentation.Part0, presentation.Part1 = root, main
presentation.C0 = root.CFrame:ToObjectSpace(main.CFrame)
presentation.C1 = CFrame.identity
presentation.Parent = root
for _, obj in ipairs(visual:GetDescendants()) do
    if obj:IsA("BasePart") then obj.Anchored = false end
end
root.Anchored = true
joud:SetAttribute("VisualHeightStuds", HEIGHT_STUDS)
joud:SetAttribute("VisualHeightMeters", HEIGHT_METERS)
joud:SetAttribute("AppearanceVersion", "realistic-ghost-1")
local label = joud:FindFirstChild("Nameplate", true)
if label and label:IsA("BillboardGui") then
    label.StudsOffset = Vector3.new(0, HEIGHT_STUDS - 4.5 + 0.45, 0)
end

local starter = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local oldMotion = starter:FindFirstChild("JoudRealisticMotion")
if oldMotion then oldMotion:Destroy() end
local motion = Instance.new("LocalScript")
motion.Name = "JoudRealisticMotion"
motion.Source = [==[
-- Gentle apparition sway. The existing server still owns pursuit and catches.
local RunService = game:GetService("RunService")
local joud = workspace:WaitForChild("Hara"):WaitForChild("Joud")
local root = joud:WaitForChild("HumanoidRootPart")
local motor = root:WaitForChild("JoudAppearanceMotor")
local visual = joud:WaitForChild("RealisticAppearance")
local base = motor.C0
RunService.PreSimulation:Connect(function()
    if not motor.Parent or not visual.Parent then return end
    local t = os.clock()
    local moving = Vector3.new(root.AssemblyLinearVelocity.X, 0,
        root.AssemblyLinearVelocity.Z).Magnitude > 0.6
    local hunt = joud:GetAttribute("Mood") == "Hunt"
    local lift = moving and 0.035 * math.sin(t * (hunt and 5 or 2.4)) or 0
    local lean = moving and (hunt and -0.035 or -0.015) or 0
    motor.C0 = CFrame.new(0, lift, 0) * base
        * CFrame.Angles(lean, 0, math.sin(t * 0.9) * 0.008)
end)
]==]
motion.Parent = starter

-- Keep the separate imported source in ServerStorage so it does not appear twice.
source.Name = "JoudImportedSource_" .. tostring(DateTime.now().UnixTimestampMillis)
source.Parent = backups
history:SetWaypoint("Realistic Joud installed")
Selection:Set({joud})
print(string.format("Joud installed at %.2f meters / %.3f studs. Original saved under ServerStorage > JoudAppearanceBackups. Test Play before publishing.", HEIGHT_METERS, HEIGHT_STUDS))
