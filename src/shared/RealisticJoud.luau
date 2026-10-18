-- Self-contained NPC presentation. Geometry and texture bytes are embedded
-- under HaraShared/JoudEmbeddedAssets. No asset IDs or HTTP downloads are used.
local AssetService = game:GetService("AssetService")
local EncodingService = game:GetService("EncodingService")
local RunService = game:GetService("RunService")
local M = {}
local keepAlive = {}

local function readBlob(folder, entry)
    local pieces = table.create(entry.chunks)
    for i = 1, entry.chunks do
        local chunk = folder:WaitForChild(string.format("%04d", i), 60)
        assert(chunk and chunk:IsA("StringValue"), "Missing embedded character chunk")
        pieces[i] = chunk.Value
    end
    local compressed = EncodingService:Base64Decode(buffer.fromstring(table.concat(pieces)))
    local decoded = EncodingService:DecompressBuffer(compressed, Enum.CompressionAlgorithm.Zstd)
    assert(buffer.len(decoded) == entry.bytes, "Embedded character size mismatch")
    return decoded
end

-- Kept separate from placement so binary decoding and topology can be checked.
function M.BuildFromBuffers(vertices, indices, pixels, spec, progress)
    assert(buffer.len(vertices) == spec.vertexCount * 32, "Invalid vertex buffer")
    assert(buffer.len(indices) == spec.triangleCount * 6, "Invalid index buffer")
    assert(buffer.len(pixels) == spec.textureSize * spec.textureSize * 4, "Invalid pixel buffer")
    local mesh = AssetService:CreateEditableMesh()
    assert(mesh, "EditableMesh memory budget unavailable")
    local image, part
    local ok, failure = pcall(function()
        local vertexIds = table.create(spec.vertexCount)
        local normalIds = table.create(spec.vertexCount)
        local uvIds = table.create(spec.vertexCount)
        for i = 1, spec.vertexCount do
            local offset = (i - 1) * 32
            vertexIds[i] = mesh:AddVertex(Vector3.new(
                buffer.readf32(vertices, offset), buffer.readf32(vertices, offset + 4),
                buffer.readf32(vertices, offset + 8)))
            normalIds[i] = mesh:AddNormal(Vector3.new(
                buffer.readf32(vertices, offset + 12), buffer.readf32(vertices, offset + 16),
                buffer.readf32(vertices, offset + 20)))
            uvIds[i] = mesh:AddUV(Vector2.new(
                buffer.readf32(vertices, offset + 24), buffer.readf32(vertices, offset + 28)))
            if i % 384 == 0 then
                if progress then progress(0.1 + 0.35 * i / spec.vertexCount) end
                task.wait()
            end
        end
        for i = 1, spec.triangleCount do
            local offset = (i - 1) * 6
            local a = buffer.readu16(indices, offset) + 1
            local b = buffer.readu16(indices, offset + 2) + 1
            local c = buffer.readu16(indices, offset + 4) + 1
            assert(vertexIds[a] and vertexIds[b] and vertexIds[c], "Invalid triangle index")
            local face = mesh:AddTriangle(vertexIds[a], vertexIds[b], vertexIds[c])
            mesh:SetFaceNormals(face, {normalIds[a], normalIds[b], normalIds[c]})
            mesh:SetFaceUVs(face, {uvIds[a], uvIds[b], uvIds[c]})
            if i % 384 == 0 then
                if progress then progress(0.45 + 0.35 * i / spec.triangleCount) end
                task.wait()
            end
        end
        image = AssetService:CreateEditableImage({Size = Vector2.new(spec.textureSize, spec.textureSize)})
        assert(image, "EditableImage memory budget unavailable")
        image:WritePixelsBuffer(Vector2.zero, Vector2.new(spec.textureSize, spec.textureSize), pixels)
        if progress then progress(0.9) end
        part = AssetService:CreateMeshPartAsync(Content.fromObject(mesh), {
            CollisionFidelity = Enum.CollisionFidelity.Box,
        })
        part.Name = "RealisticAppearance"
        part.TextureContent = Content.fromObject(image)
        part.Size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
        part.DoubleSided = true
        part.Material = Enum.Material.SmoothPlastic
        part.Color = Color3.new(1, 1, 1)
        part.Transparency = 0
        part.Anchored = true
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = false
        part.CastShadow = true
        part.Massless = true
    end)
    if not ok then
        if part then part:Destroy() end
        if image then image:Destroy() end
        mesh:Destroy()
        error(failure, 0)
    end
    return part, mesh, image
end

function M.Attach(joud, progress)
    local existing = joud:FindFirstChild("RealisticAppearance")
    if existing then return existing end
    local assets = script.Parent:WaitForChild("JoudEmbeddedAssets")
    local spec = require(assets:WaitForChild("Manifest"))
    if progress then progress(0.02) end
    local vertices = readBlob(assets:WaitForChild("Vertices"), spec.blobs.vertices)
    local indices = readBlob(assets:WaitForChild("Triangles"), spec.blobs.triangles)
    local pixels = readBlob(assets:WaitForChild("Texture"), spec.blobs.texture)
    local visual, mesh, image = M.BuildFromBuffers(vertices, indices, pixels, spec, progress)
    local root = joud:WaitForChild("HumanoidRootPart")
    local offset = CFrame.new(0, -3 + spec.size[2] / 2, 0)
    visual.CFrame = root.CFrame * offset
    -- Only hide the old appearance once the complete textured replacement exists.
    -- The server's R6 rig remains responsible for navigation and captures.
    for _, obj in ipairs(joud:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Decal") or obj:IsA("Texture") then
            obj.Transparency = 1
        end
    end
    visual.Parent = joud
    local nameplate = joud:FindFirstChild("Nameplate", true)
    if nameplate and nameplate:IsA("BillboardGui") then
        nameplate.StudsOffset = Vector3.new(0, spec.size[2] - 4.05, 0)
    end
    local connection
    connection = RunService.PreRender:Connect(function()
        if not visual.Parent or not root.Parent then
            connection:Disconnect()
            return
        end
        local t = os.clock()
        local velocity = root.AssemblyLinearVelocity
        local moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 0.6
        local hunt = joud:GetAttribute("Mood") == "Hunt"
        local lift = moving and math.sin(t * (hunt and 5 or 2.4)) * 0.035 or 0
        local lean = moving and (hunt and -0.035 or -0.015) or 0
        visual.CFrame = root.CFrame * CFrame.new(0, lift, 0) * offset
            * CFrame.Angles(lean, 0, math.sin(t * 0.9) * 0.008)
    end)
    keepAlive[joud] = {mesh = mesh, image = image, part = visual, connection = connection}
    if progress then progress(1) end
    return visual
end

return M
