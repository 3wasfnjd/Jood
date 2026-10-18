-- Loads the user's original rest-house geometry. Server Parts own collision.
local AssetService = game:GetService("AssetService")
local EncodingService = game:GetService("EncodingService")
local M = {}
local keepAlive

local function readBlob(folder, spec)
    local chunks = table.create(spec.chunks)
    for i = 1, spec.chunks do
        local value = folder:WaitForChild(string.format("%04d", i), 60)
        assert(value and value:IsA("StringValue"), "Missing rest-house payload")
        chunks[i] = value.Value
    end
    local compressed = EncodingService:Base64Decode(buffer.fromstring(table.concat(chunks)))
    local data = EncodingService:DecompressBuffer(compressed, Enum.CompressionAlgorithm.Zstd)
    assert(buffer.len(data) == spec.bytes, "Rest-house payload size mismatch")
    return data
end

function M.BuildGroup(vertices, triangles, spec, texture)
    assert(buffer.len(vertices) == spec.vertexCount * 44, "Invalid rest-house vertices")
    assert(buffer.len(triangles) == spec.triangleCount * 6, "Invalid rest-house faces")
    local mesh = AssetService:CreateEditableMesh()
    assert(mesh, "Rest-house mesh memory budget unavailable")
    local part
    local ok, failure = pcall(function()
        local vids, nids, uids, cids = {}, {}, {}, {}
        for i = 1, spec.vertexCount do
            local o = (i - 1) * 44
            vids[i] = mesh:AddVertex(Vector3.new(buffer.readf32(vertices,o),buffer.readf32(vertices,o+4),buffer.readf32(vertices,o+8)))
            nids[i] = mesh:AddNormal(Vector3.new(buffer.readf32(vertices,o+12),buffer.readf32(vertices,o+16),buffer.readf32(vertices,o+20)))
            uids[i] = mesh:AddUV(Vector2.new(buffer.readf32(vertices,o+24),buffer.readf32(vertices,o+28)))
            cids[i] = mesh:AddColor(Color3.new(buffer.readf32(vertices,o+32),buffer.readf32(vertices,o+36),buffer.readf32(vertices,o+40)),1)
            if i % 512 == 0 then task.wait() end
        end
        for i = 1, spec.triangleCount do
            local o = (i - 1) * 6
            local a,b,c = buffer.readu16(triangles,o)+1,buffer.readu16(triangles,o+2)+1,buffer.readu16(triangles,o+4)+1
            assert(vids[a] and vids[b] and vids[c], "Invalid rest-house triangle index")
            local f = mesh:AddTriangle(vids[a],vids[b],vids[c])
            mesh:SetFaceNormals(f,{nids[a],nids[b],nids[c]})
            mesh:SetFaceUVs(f,{uids[a],uids[b],uids[c]})
            mesh:SetFaceColors(f,{cids[a],cids[b],cids[c]})
            if i % 512 == 0 then task.wait() end
        end
        mesh:RemoveUnused()
        part = AssetService:CreateMeshPartAsync(Content.fromObject(mesh),{CollisionFidelity=Enum.CollisionFidelity.Box})
        part.Name = spec.name
        part.Size = Vector3.new(spec.size[1],spec.size[2],spec.size[3])
        part.Material = spec.material == "Metal" and Enum.Material.Metal or Enum.Material.SmoothPlastic
        part.Color = Color3.new(1,1,1)
        part.DoubleSided = true
        part.Anchored = true
        part.CanCollide,part.CanTouch,part.CanQuery = false,false,false
        part.CastShadow = true
        if spec.textured then part.TextureContent = Content.fromObject(texture) end
    end)
    if not ok then
        if part then part:Destroy() end
        mesh:Destroy()
        error(failure,0)
    end
    return part,mesh
end

function M.Attach(world, progress)
    local model = world:WaitForChild("Architecture"):WaitForChild("RestHouse")
    if model:FindFirstChild("RestHouseVisual") then return end
    local origin = model:WaitForChild("EntranceOrigin")
    local assets = script.Parent:WaitForChild("RestHouseEmbeddedAssets")
    local spec = require(assets:WaitForChild("RestHouseManifest"))
    local image, visual
    local meshes = {}
    local ok, failure = pcall(function()
        local pixels = readBlob(assets:WaitForChild("Texture"),spec.texture)
        image = AssetService:CreateEditableImage({Size=Vector2.new(spec.textureSize,spec.textureSize)})
        assert(image,"Rest-house texture memory budget unavailable")
        image:WritePixelsBuffer(Vector2.zero,Vector2.new(spec.textureSize,spec.textureSize),pixels)
        visual = Instance.new("Model")
        visual.Name = "RestHouseVisual"
        for i,group in ipairs(spec.groups) do
            local folder = assets:WaitForChild(group.name)
            local vertices = readBlob(folder:WaitForChild("Vertices"),group.vertices)
            local indices = readBlob(folder:WaitForChild("Triangles"),group.triangles)
            local part,mesh = M.BuildGroup(vertices,indices,group,image)
            table.insert(meshes,mesh)
            part.Parent = visual
            part.CFrame = origin.CFrame * CFrame.new(group.center[1],group.center[2],group.center[3])
            if progress then progress(i/#spec.groups) end
        end
    end)
    if not ok then
        if visual then visual:Destroy() end
        for _,mesh in ipairs(meshes) do mesh:Destroy() end
        if image then image:Destroy() end
        error(failure,0)
    end
    visual.Parent = model
    for _,part in ipairs(model:WaitForChild("Colliders"):GetChildren()) do
        if part:IsA("BasePart") then part.Transparency = 1 end
    end
    keepAlive = {visual=visual,meshes=meshes,image=image}
end
return M
