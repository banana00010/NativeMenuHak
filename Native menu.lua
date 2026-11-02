-- ==========================================================
-- Version number - 0.2.5a
-- Native Menu (fixed) - client-side script for your OWN game
-- Pair it with DevStats.server.lua (ServerScriptService) for the
-- Damage Multiplier and Attack Speed boxes. Those two values must
-- be applied by the server, so the client only asks for them.
-- ==========================================================

local Players = game:FindService("Players")
local RunService = game:FindService("RunService")
local UserInputService = game:FindService("UserInputService")
local ReplicatedStorage = game:FindService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local G = (getgenv and getgenv()) or _G
local runActive = true

-- Re-run safety: remove everything the previous run created
if G.NativeMenuCleanup then
    pcall(G.NativeMenuCleanup)
    G.NativeMenuCleanup = nil
end

-- ==========================================================
-- Settings (kept in getgenv so they survive a re-run)
-- ==========================================================

local function default(key, value)
    if G[key] == nil then
        G[key] = value
    end
end

default("SpeedEnabled", false)
default("WalkSpeedValue", 100)
default("JumpEnabled", false)
default("JumpHeightValue", 100)
default("InfiniteJumpEnabled", false)
default("NoClipEnabled", false)
default("ShiftLockEnabled", false)
default("FlySpeedValue", 75)
default("AimbotEnabled", false)
default("AimbotStrength", 5)
default("AimbotTeamCheck", true)
default("HighlightESPEnabled", true)
default("BoneESPEnabled", false)
default("NametagESPEnabled", false)
default("ArmorESPEnabled", false)
default("InvisibleEnabled", false)
default("MorphEnabled", false)
default("UnlimitedZoomEnabled", true)
G.FlyEnabled = false
local connections = {}
local togglers = {}

local function track(connection)
    connections[#connections + 1] = connection
    return connection
end

-- Many games have 0 or 1 teams, where "same team" would wrongly mean everyone
local TeamsService = game:FindService("Teams")
local teamCount = #TeamsService:GetTeams()

local function updateTeamCount()
    teamCount = #TeamsService:GetTeams()
end

track(TeamsService.ChildAdded:Connect(updateTeamCount))
track(TeamsService.ChildRemoved:Connect(updateTeamCount))

local function SameTeam(player)
    return teamCount > 1
        and LocalPlayer.Team ~= nil
        and player.Team ~= nil
        and player.Team == LocalPlayer.Team
end

-- ==========================================================
-- Movement: speed / jump / noclip (all restore when turned off)
-- ==========================================================

-- ==========================================================
-- Movement: speed / jump / noclip / WASD instant start & stop
-- ==========================================================

local savedHumanoid = setmetatable({}, { __mode = "k" })
local savedCollide = setmetatable({}, { __mode = "k" })

local function restoreHumanoid(humanoid, saved)
    if saved.walk ~= nil then
        humanoid.WalkSpeed = saved.walk
        saved.walk = nil
    end
    if saved.jump ~= nil then
        humanoid.UseJumpPower = saved.useJump
        humanoid.JumpPower = saved.jump
        saved.jump = nil
    end
end

local function restoreCollisions()
    for part, wasCollidable in pairs(savedCollide) do
        if part.Parent then
            part.CanCollide = wasCollidable
        end
        savedCollide[part] = nil
    end
end

track(RunService.Stepped:Connect(function()
    local character = LocalPlayer.Character
    if not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")

    if humanoid then
        local saved = savedHumanoid[humanoid]
        if not saved then
            saved = {}
            savedHumanoid[humanoid] = saved
        end

        if G.SpeedEnabled then
            if saved.walk == nil then
                saved.walk = humanoid.WalkSpeed
            end
            humanoid.WalkSpeed = G.WalkSpeedValue

            -- Instant start and stop logic for all movement keys (W, A, S, D)
            if hrp and not UserInputService:GetFocusedTextBox() then
                local cam = workspace.CurrentCamera
                if cam then
                    local moveDir = Vector3.new(0, 0, 0)
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + cam.CFrame.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - cam.CFrame.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + cam.CFrame.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - cam.CFrame.RightVector end

                    local flatDir = Vector3.new(moveDir.X, 0, moveDir.Z)
                    if flatDir.Magnitude > 0 then
                        flatDir = flatDir.Unit * G.WalkSpeedValue
                        hrp.AssemblyLinearVelocity = Vector3.new(flatDir.X, hrp.AssemblyLinearVelocity.Y, flatDir.Z)
                    else
                        -- Instant stop: zero out horizontal velocity when no movement keys are pressed
                        hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
                    end
                end
            end
        elseif saved.walk ~= nil then
            humanoid.WalkSpeed = saved.walk
            saved.walk = nil
        end

        if G.JumpEnabled then
            if saved.jump == nil then
                saved.jump = humanoid.JumpPower
                saved.useJump = humanoid.UseJumpPower
            end
            humanoid.UseJumpPower = true
            humanoid.JumpPower = G.JumpHeightValue
        elseif saved.jump ~= nil then
            humanoid.UseJumpPower = saved.useJump
            humanoid.JumpPower = saved.jump
            saved.jump = nil
        end
    end

    if G.NoClipEnabled then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                if savedCollide[part] == nil then
                    savedCollide[part] = part.CanCollide
                end
                part.CanCollide = false
            end
        end
    elseif next(savedCollide) ~= nil then
        restoreCollisions()
    end
end))

track(UserInputService.JumpRequest:Connect(function()
    if not G.InfiniteJumpEnabled then
        return
    end

    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    if humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end))

-- ==========================================================
-- Invisibility
-- Hides every part, decal and accessory on your character and
-- the overhead name/health bar. Everything is restored when off.
-- Note: this is a client-side change, so other players only see
-- it if your game replicates it (e.g. via a server script).
-- ==========================================================

local invisSaved = setmetatable({}, { __mode = "k" })
local invisHumanoidSaved = setmetatable({}, { __mode = "k" })

local function restoreVisibility()
    for object, original in pairs(invisSaved) do
        if object.Parent then
            object.Transparency = original
        end
        invisSaved[object] = nil
    end

    for humanoid, displayType in pairs(invisHumanoidSaved) do
        if humanoid.Parent then
            humanoid.DisplayDistanceType = displayType
        end
        invisHumanoidSaved[humanoid] = nil
    end
end

track(RunService.RenderStepped:Connect(function()
    if not G.InvisibleEnabled then
        if next(invisSaved) ~= nil or next(invisHumanoidSaved) ~= nil then
            restoreVisibility()
        end
        return
    end

    local character = LocalPlayer.Character
    if not character then
        return
    end

    -- Runs every frame so accessories/tools added later are hidden too
    for _, object in ipairs(character:GetDescendants()) do
        if object:IsA("BasePart") or object:IsA("Decal") then
            if invisSaved[object] == nil then
                invisSaved[object] = object.Transparency
            end
            object.Transparency = 1
        end
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        if invisHumanoidSaved[humanoid] == nil then
            invisHumanoidSaved[humanoid] = humanoid.DisplayDistanceType
        end
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    end
end))

-- ==========================================================
-- Avatar morph
-- Fill in the catalog asset IDs below (as strings). Leave a field
-- as "" to skip it. IDs come from the number in a catalog item's URL.
-- Accessory fields accept several IDs separated by commas.
-- Turning the toggle off restores your original look.
-- ==========================================================

local MORPH = {
    HairAccessory = "87924232591985",    -- e.g. "1234567,7654321"
    FaceAccessory = "",
    HatAccessory = "126266405484254",
    NeckAccessory = "16988901927",
    ShouldersAccessory = "120579423084182",
    FrontAccessory = "18133081957",
    BackAccessory = "86231320427423",
    WaistAccessory = "74916992913611",
    Shirt = "123781839092808",
    Pants = "115841525903241",
    GraphicTShirt = "",
    Face = "",
}

local morphOriginal -- the description to restore
local SetStatus

local function reportMorphError(message)
    warn("Native menu could not update the avatar morph: " .. tostring(message))
    if SetStatus then
        SetStatus("Morph failed: " .. tostring(message))
    end
end

local function applyMorph(humanoid)
    local ok, current = pcall(function()
        return humanoid:GetAppliedDescription()
    end)
    if not ok then
        return false, current
    end
    if not current then
        return false, "Humanoid did not return an applied description"
    end

    if not morphOriginal then
        morphOriginal = current:Clone()
    end

    local description = current:Clone()
    local numericFields = {
        Shirt = true,
        Pants = true,
        GraphicTShirt = true,
        Face = true,
    }

    for field, value in pairs(MORPH) do
        if value ~= "" then
            if numericFields[field] then
                local numeric = tonumber(value)
                if not numeric then
                    return false, "Invalid asset ID for " .. field
                end
                description[field] = numeric
            else
                description[field] = value
            end
        end
    end

    local applied, applyError = pcall(function()
        humanoid:ApplyDescription(description)
    end)
    if not applied then
        return false, applyError
    end

    return true
end

local function revertMorph(humanoid)
    if morphOriginal then
        local applied, applyError = pcall(function()
            humanoid:ApplyDescription(morphOriginal)
        end)
        if not applied then
            return false, applyError
        end
        morphOriginal = nil
    end

    return true
end

local function toggleMorph(state)
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end

    task.spawn(function() -- ApplyDescription yields
        local ok, err
        if state then
            ok, err = applyMorph(humanoid)
        else
            ok, err = revertMorph(humanoid)
        end
        if not ok then
            reportMorphError(err)
        else
            SetStatus(state and "Avatar morph applied." or "Avatar morph reverted.")
        end
    end)
end

track(LocalPlayer.CharacterAdded:Connect(function(character)
    -- A new character starts from the default look, so forget the old snapshot
    morphOriginal = nil

    if G.MorphEnabled then
        local humanoid = character:WaitForChild("Humanoid", 5)
        if humanoid and G.MorphEnabled then
            task.wait(0.5)
            if runActive and G.MorphEnabled and LocalPlayer.Character == character then
                local ok, err = applyMorph(humanoid)
                if not ok then
                    reportMorphError(err)
                end
            end
        end
    end
end))

-- ==========================================================
-- Unlimited zoom
-- Allows the camera to zoom out as far as you want. The default max is 400.
-- ==========================================================

local zoomSaved

local function restoreZoom()
    if zoomSaved then
        LocalPlayer.CameraMaxZoomDistance = zoomSaved.max
        LocalPlayer.CameraMinZoomDistance = zoomSaved.min
        LocalPlayer.CameraMode = zoomSaved.mode
        zoomSaved = nil
    end
end

track(RunService.RenderStepped:Connect(function()
    if G.UnlimitedZoomEnabled then
        if not zoomSaved then
            zoomSaved = {
                max = LocalPlayer.CameraMaxZoomDistance,
                min = LocalPlayer.CameraMinZoomDistance,
                mode = LocalPlayer.CameraMode,
            }
        end
        LocalPlayer.CameraMaxZoomDistance = 100000
        LocalPlayer.CameraMinZoomDistance = -100000
        LocalPlayer.CameraMode = Enum.CameraMode.Classic
    else
        restoreZoom()
    end
end))

-- ==========================================================
-- Fly
--   W/A/S/D  move relative to where the camera looks
--   Space/E  up        Ctrl/Q  down        Shift  boost
--   F        toggle fly on/off
-- Movement eases in and out, and you hover when no key is held.
-- ==========================================================

local FLY_BOOST = 2

local flyConnection
local flyVelocity
local flyRoot
local flyHumanoid
local flyCurrent = Vector3.new(0, 0, 0)

local function faceCamera(hrp, cam)
    local look = cam.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)

    if flat.Magnitude > 0.001 then
        hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + flat)
    end
end

local function stopFly()
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end

    if flyVelocity then
        flyVelocity:Destroy()
        flyVelocity = nil
    end

    if flyRoot and flyRoot.Parent then
        flyRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    end
    flyRoot = nil

    if flyHumanoid and flyHumanoid.Parent then
        flyHumanoid.PlatformStand = false
    end
    flyHumanoid = nil

    flyCurrent = Vector3.new(0, 0, 0)
end

local function readFlyInput(cam)
    local dir = Vector3.new(0, 0, 0)

    if UserInputService:GetFocusedTextBox() then
        return dir, false
    end

    local function down(key)
        return UserInputService:IsKeyDown(key)
    end

    if down(Enum.KeyCode.W) then
        dir = dir + cam.CFrame.LookVector
    end
    if down(Enum.KeyCode.S) then
        dir = dir - cam.CFrame.LookVector
    end
    if down(Enum.KeyCode.D) then
        dir = dir + cam.CFrame.RightVector
    end
    if down(Enum.KeyCode.A) then
        dir = dir - cam.CFrame.RightVector
    end
    if down(Enum.KeyCode.Space) or down(Enum.KeyCode.E) then
        dir = dir + Vector3.new(0, 1, 0)
    end
    if down(Enum.KeyCode.LeftControl) or down(Enum.KeyCode.Q) then
        dir = dir - Vector3.new(0, 1, 0)
    end

    return dir, down(Enum.KeyCode.LeftShift)
end

local function startFly()
    stopFly()

    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not hrp then
        return
    end

    local bv = Instance.new("BodyVelocity")
    bv.Name = "NativeFlyBV"
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp

    flyVelocity = bv
    flyRoot = hrp

    -- Stops the falling/standing animation from fighting the flight
    if humanoid then
        flyHumanoid = humanoid
        humanoid.PlatformStand = true
    end

    flyConnection = RunService.RenderStepped:Connect(function(dt)
        if not hrp.Parent or not bv.Parent then
            stopFly()
            return
        end

        local cam = workspace.CurrentCamera
        if not cam then
            return
        end

        faceCamera(hrp, cam)

        local dir, boosting = readFlyInput(cam)
        local target = Vector3.new(0, 0, 0)

        if dir.Magnitude > 0 then
            local speed = G.FlySpeedValue * (boosting and FLY_BOOST or 1)
            target = dir.Unit * speed
        end

        -- Ease toward the target so starting and stopping feel smooth
        local alpha = 1 - math.exp(-dt * 10)
        flyCurrent = flyCurrent:Lerp(target, alpha)
        bv.Velocity = flyCurrent
    end)
end

local function toggleFly(state)
    if state then
        startFly()
    else
        stopFly()
    end
end

track(LocalPlayer.CharacterAdded:Connect(function(character)
    if G.FlyEnabled then
        character:WaitForChild("HumanoidRootPart", 5)
        if runActive and G.FlyEnabled then
            startFly()
        end
    end
end))

-- ==========================================================
-- Shift lock (own implementation, works in any game)
-- Hold Left Alt to free the cursor so you can use the menu.
-- ==========================================================

local lockHumanoid
local lockOffset
local lockAutoRotate
local lockMouseActive = false

local function releaseShiftLock()
    if lockHumanoid then
        if lockHumanoid.Parent then
            lockHumanoid.AutoRotate = lockAutoRotate
            lockHumanoid.CameraOffset = lockOffset
        end
        lockHumanoid = nil
    end

    if lockMouseActive then
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        lockMouseActive = false
    end
end

track(RunService.RenderStepped:Connect(function()
    if not G.ShiftLockEnabled then
        releaseShiftLock()
        return
    end

    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local cam = workspace.CurrentCamera

    if not (humanoid and hrp and cam) then
        return
    end

    -- Free the cursor while Alt is held or a textbox is being used
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
        or UserInputService:GetFocusedTextBox() then
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        lockMouseActive = false
        return
    end

    if lockHumanoid ~= humanoid then
        if lockHumanoid and lockHumanoid.Parent then
            lockHumanoid.AutoRotate = lockAutoRotate
            lockHumanoid.CameraOffset = lockOffset
        end
        lockHumanoid = humanoid
        lockOffset = humanoid.CameraOffset
        lockAutoRotate = humanoid.AutoRotate
    end

    lockMouseActive = true
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    humanoid.AutoRotate = false
    humanoid.CameraOffset = Vector3.new(1.75, 0, 0)

    faceCamera(hrp, cam)
end))

-- ==========================================================
-- Aimbot
-- ==========================================================

-- Head is preferred, but some games rename/remove it or stream it in late,
-- so fall back to the root part, then any part of the character.
local function getAdornee(character)
    local head = character:FindFirstChild("Head")
    if head and head:IsA("BasePart") then
        return head, true
    end

    local fallback = character:FindFirstChild("HumanoidRootPart")
        or character.PrimaryPart
        or character:FindFirstChildWhichIsA("BasePart", true)

    return fallback, false
end

local function getClosestTarget()
    local camera = workspace.CurrentCamera
    if not camera then
        return nil
    end

    local closestPart = nil
    local shortestDistance = math.huge
    local mouseLocation = UserInputService:GetMouseLocation()

    for _, player in ipairs(Players:GetPlayers()) do
        local skip = player == LocalPlayer
            or (G.AimbotTeamCheck and SameTeam(player))

        if not skip and player.Character then
            -- Same part lookup as the ESP, so anyone the ESP sees can be targeted
            local aimPart = getAdornee(player.Character)
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            local alive = humanoid == nil or humanoid.Health > 0

            if aimPart and alive then
                local screenPos, onScreen = camera:WorldToViewportPoint(aimPart.Position)

                if onScreen then
                    local distance = (Vector2.new(screenPos.X, screenPos.Y) - mouseLocation).Magnitude

                    if distance < shortestDistance then
                        shortestDistance = distance
                        closestPart = aimPart
                    end
                end
            end
        end
    end

    return closestPart
end

-- Bound just after the default camera update so the game's camera script
-- can't overwrite our change in the same frame.
RunService:BindToRenderStep(
    "NativeAimbot",
    Enum.RenderPriority.Camera.Value + 1,
    function()
        if not G.AimbotEnabled or G.AimbotStrength <= 0 then
            return
        end

        local camera = workspace.CurrentCamera
        local part = getClosestTarget()

        if part and camera then
            local targetCFrame = CFrame.new(camera.CFrame.Position, part.Position)
            local alpha = math.clamp(G.AimbotStrength / 100, 0, 1)
            camera.CFrame = camera.CFrame:Lerp(targetCFrame, alpha)
        end
    end
)

-- ==========================================================
-- ESP (everything it creates is tracked and cleaned up)
-- ==========================================================

local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "NativeESP"
ESPFolder.Parent = workspace

local ESPData = {}
local playerConns = {}

local R15_BONES = {
    { "Head", "UpperTorso" },
    { "UpperTorso", "LowerTorso" },
    { "UpperTorso", "LeftUpperArm" },
    { "LeftUpperArm", "LeftLowerArm" },
    { "LeftLowerArm", "LeftHand" },
    { "UpperTorso", "RightUpperArm" },
    { "RightUpperArm", "RightLowerArm" },
    { "RightLowerArm", "RightHand" },
    { "LowerTorso", "LeftUpperLeg" },
    { "LeftUpperLeg", "LeftLowerLeg" },
    { "LeftLowerLeg", "LeftFoot" },
    { "LowerTorso", "RightUpperLeg" },
    { "RightUpperLeg", "RightLowerLeg" },
    { "RightLowerLeg", "RightFoot" },
}

local R6_BONES = {
    { "Head", "Torso" },
    { "Torso", "Left Arm" },
    { "Torso", "Right Arm" },
    { "Torso", "Left Leg" },
    { "Torso", "Right Leg" },
}

local function ESPColor(player)
    if SameTeam(player) then
        return Color3.fromRGB(70, 170, 255)
    end
    return Color3.fromRGB(255, 70, 70)
end

local function ClearPlayerESP(player)
    local data = ESPData[player]
    if not data then
        return
    end
    ESPData[player] = nil

    for _, connection in ipairs(data.conns) do
        connection:Disconnect()
    end
    for _, instance in ipairs(data.extras) do
        instance:Destroy()
    end
    data.container:Destroy()
end

local function CreateBone(data, part0, part1, color)
    if not part0 or not part1 then
        return
    end

    local attachment0 = Instance.new("Attachment")
    attachment0.Name = "ESP_Attachment0"
    attachment0.Parent = part0

    local attachment1 = Instance.new("Attachment")
    attachment1.Name = "ESP_Attachment1"
    attachment1.Parent = part1

    -- Attachments live on the character, so remember them to destroy later
    table.insert(data.extras, attachment0)
    table.insert(data.extras, attachment1)

    local beam = Instance.new("Beam")
    beam.Name = "ESP_Bone"
    beam.Attachment0 = attachment0
    beam.Attachment1 = attachment1
    beam.Color = ColorSequence.new(color)
    beam.Width0 = 0.04
    beam.Width1 = 0.04
    beam.FaceCamera = true
    beam.LightEmission = 1
    beam.LightInfluence = 0
    beam.Transparency = NumberSequence.new(0)
    beam.Parent = data.container
end

local function CreateSkeleton(player, character, data)
    if not G.BoneESPEnabled then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end

    local color = ESPColor(player)
    local bones = (humanoid.RigType == Enum.HumanoidRigType.R15) and R15_BONES or R6_BONES

    for _, bone in ipairs(bones) do
        CreateBone(
            data,
            character:FindFirstChild(bone[1]),
            character:FindFirstChild(bone[2]),
            color
        )
    end
end

local function nameText(player, humanoid)
    local text = player.DisplayName .. " (@" .. player.Name .. ")"
    if humanoid then
        text = text .. "\nHP: " .. math.floor(humanoid.Health)
    end
    return text
end

local function CreateNametag(player, character, data)
    if not G.NametagESPEnabled then
        return
    end

    local adornee, isHead = getAdornee(character)
    if not adornee then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")

    -- Remembered so the watchdog can rebuild once the missing piece appears
    data.adornee = adornee
    data.usedFallback = not isHead
    data.hadHumanoid = humanoid ~= nil

    local gui = Instance.new("BillboardGui")
    gui.Name = "ESP_Nametag"
    gui.Adornee = adornee
    gui.Size = UDim2.new(0, 200, 0, 50)
    gui.StudsOffset = Vector3.new(0, 3, 0)
    gui.AlwaysOnTop = true
    gui.Parent = data.container

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.TextColor3 = ESPColor(player)
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.Text = nameText(player, humanoid)
    label.Parent = gui

    if humanoid then
        table.insert(data.conns, humanoid.HealthChanged:Connect(function()
            if label.Parent then
                label.Text = nameText(player, humanoid)
            end
        end))
    end
end

local function CreateArmorESP(player, character, data)
    if not G.ArmorESPEnabled then
        return
    end

    local adornee = getAdornee(character)
    if not adornee then
        return
    end

    local armor = {}

    for _, object in ipairs(character:GetChildren()) do
        if object:IsA("Accessory") then
            table.insert(armor, object.Name)
        end
    end

    -- Also lists a custom "Armor" folder if your game uses one
    local armorFolder = character:FindFirstChild("Armor")
    if armorFolder then
        for _, object in ipairs(armorFolder:GetChildren()) do
            table.insert(armor, object.Name)
        end
    end

    if #armor == 0 then
        return
    end

    local gui = Instance.new("BillboardGui")
    gui.Name = "ESP_Armor"
    gui.Adornee = adornee
    gui.Size = UDim2.new(0, 200, 0, 80)
    gui.StudsOffset = Vector3.new(0, 4.5, 0)
    gui.AlwaysOnTop = true
    gui.Parent = data.container

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.TextColor3 = Color3.fromRGB(255, 210, 70)
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.GothamBold
    label.TextSize = 11
    label.Text = "ARMOR\n" .. table.concat(armor, "\n")
    label.Parent = gui
end

local function CreatePlayerESP(player)
    if not runActive or player == LocalPlayer then
        return
    end

    ClearPlayerESP(player)

    local character = player.Character
    if not character or not character.Parent then
        return
    end

    if not (G.HighlightESPEnabled or G.BoneESPEnabled or G.NametagESPEnabled or G.ArmorESPEnabled) then
        return
    end

    local container = Instance.new("Folder")
    container.Name = player.Name .. "_ESP"
    container.Parent = ESPFolder

    local data = { container = container, extras = {}, conns = {}, character = character }
    ESPData[player] = data

    if G.HighlightESPEnabled then
        local highlight = Instance.new("Highlight")
        highlight.Name = "ESP_Highlight"
        highlight.Adornee = character
        highlight.FillColor = ESPColor(player)
        highlight.OutlineColor = ESPColor(player)
        highlight.FillTransparency = 0.8
        highlight.OutlineTransparency = 0
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = container
    end

    CreateSkeleton(player, character, data)
    CreateNametag(player, character, data)
    CreateArmorESP(player, character, data)
end

local function RefreshESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            CreatePlayerESP(player)
        end
    end
end

local function TrackESPPlayer(player)
    if player == LocalPlayer or playerConns[player] then
        return
    end

    local conns = {}
    playerConns[player] = conns

    conns[#conns + 1] = player.CharacterAdded:Connect(function(character)
        character:WaitForChild("Head", 5)
        if not runActive or not player.Parent or player.Character ~= character then
            return
        end

        task.wait(0.5) -- let the limbs load so the skeleton is complete

        if runActive and player.Parent and player.Character == character then
            CreatePlayerESP(player)
        end
    end)

    conns[#conns + 1] = player.CharacterRemoving:Connect(function()
        ClearPlayerESP(player)
    end)

    -- Colors depend on teams, so rebuild when a team changes
    conns[#conns + 1] = player:GetPropertyChangedSignal("Team"):Connect(function()
        CreatePlayerESP(player)
    end)

    if player.Character then
        task.defer(CreatePlayerESP, player)
    end
end

local function UntrackESPPlayer(player)
    ClearPlayerESP(player)

    local conns = playerConns[player]
    if conns then
        for _, connection in ipairs(conns) do
            connection:Disconnect()
        end
        playerConns[player] = nil
    end
end

for _, player in ipairs(Players:GetPlayers()) do
    TrackESPPlayer(player)
end

track(Players.PlayerAdded:Connect(TrackESPPlayer))
track(Players.PlayerRemoving:Connect(UntrackESPPlayer))
track(LocalPlayer:GetPropertyChangedSignal("Team"):Connect(RefreshESP))

-- Watchdog: once a second, rebuild ESP that is missing or went stale
-- (character swapped, Head/Humanoid streamed in late, adornee destroyed).
local espWatchdogActive = true
local espWatchdogThread

espWatchdogThread = task.spawn(function()
    while espWatchdogActive do
        task.wait(1)
        if not runActive then
            break
        end

        local anyEnabled = G.HighlightESPEnabled or G.BoneESPEnabled
            or G.NametagESPEnabled or G.ArmorESPEnabled

        if anyEnabled then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    local character = player.Character
                    local data = ESPData[player]

                    if character and character.Parent then
                        local stale = data == nil
                            or data.character ~= character
                            or (data.adornee ~= nil and not data.adornee:IsDescendantOf(workspace))
                            or (data.usedFallback and character:FindFirstChild("Head") ~= nil)
                            or (data.hadHumanoid == false
                                and character:FindFirstChildOfClass("Humanoid") ~= nil)

                        if stale then
                            CreatePlayerESP(player)
                        end
                    end
                end
            end
        end
    end
end)

-- ==========================================================
-- GUI
-- ==========================================================

local UI_COLORS = {
    Background = Color3.fromRGB(18, 24, 36),
    Header = Color3.fromRGB(28, 38, 55),
    Surface = Color3.fromRGB(34, 45, 64),
    Accent = Color3.fromRGB(68, 105, 190),
    Border = Color3.fromRGB(59, 76, 102),
    Text = Color3.fromRGB(235, 240, 248),
    MutedText = Color3.fromRGB(153, 167, 188),
    Enabled = Color3.fromRGB(94, 220, 174),
    Disabled = Color3.fromRGB(235, 128, 137),
}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SolaraNativeMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
local defaultFrameSize = UDim2.fromOffset(260, 420)
MainFrame.Size = defaultFrameSize
MainFrame.Position = UDim2.new(0.1, 0, 0.2, 0)
MainFrame.BackgroundColor3 = UI_COLORS.Background
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

local FrameStroke = Instance.new("UIStroke")
FrameStroke.Color = UI_COLORS.Border
FrameStroke.Transparency = 0.25
FrameStroke.Thickness = 1
FrameStroke.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Position = UDim2.new(0, 12, 0, 0)
Title.Size = UDim2.new(1, -24, 0, 40)
Title.BackgroundColor3 = UI_COLORS.Header
Title.Text = "Native Menu  |  v0.2.5"
Title.TextColor3 = UI_COLORS.Text
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Active = true
Title.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 10)
TitleCorner.Parent = Title

local Container = Instance.new("ScrollingFrame")
Container.Size = UDim2.new(1, -20, 1, -50)
Container.Position = UDim2.new(0, 10, 0, 45)
Container.BackgroundTransparency = 1
Container.BorderSizePixel = 0
Container.CanvasSize = UDim2.new(0, 0, 0, 0)
Container.AutomaticCanvasSize = Enum.AutomaticSize.Y
Container.ScrollBarThickness = 4
Container.Parent = MainFrame

local expandedSize = MainFrame.Size
local dragInput
local dragStartPosition
local dragStartFramePosition
local dragStartGuiPosition

track(Title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
        dragStartPosition = Vector2.new(input.Position.X, input.Position.Y)
        dragStartFramePosition = MainFrame.AbsolutePosition
        dragStartGuiPosition = MainFrame.Position
    end
end))

local function makeTitleButton(text, xOffset, color)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 28, 0, 28)
    button.Position = UDim2.new(1, xOffset, 0, 6)
    button.BackgroundColor3 = color
    button.Text = text
    button.TextColor3 = UI_COLORS.Text
    button.Font = Enum.Font.GothamBold
    button.TextSize = 15
    button.Parent = MainFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = button

    return button
end

local CloseButton = makeTitleButton("×", -34, Color3.fromRGB(155, 65, 78))
local MinimizeButton = makeTitleButton("−", -66, UI_COLORS.Surface)

local ResizeHandle = Instance.new("TextButton")
ResizeHandle.Name = "ResizeHandle"
ResizeHandle.Size = UDim2.new(0, 20, 0, 20)
ResizeHandle.Position = UDim2.new(1, -22, 1, -22)
ResizeHandle.BackgroundColor3 = UI_COLORS.Surface
ResizeHandle.Text = "↘"
ResizeHandle.TextColor3 = UI_COLORS.Text
ResizeHandle.Font = Enum.Font.GothamBold
ResizeHandle.TextSize = 14
ResizeHandle.ZIndex = 10
ResizeHandle.Parent = MainFrame

local resizeInput
local resizeStartPosition
local resizeStartSize

track(ResizeHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        resizeInput = input
        resizeStartPosition = Vector2.new(input.Position.X, input.Position.Y)
        resizeStartSize = MainFrame.AbsoluteSize
    end
end))

track(UserInputService.InputChanged:Connect(function(input)
    if dragInput then
        local isMouseDrag = dragInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement
        local isTouchDrag = dragInput.UserInputType == Enum.UserInputType.Touch
            and input == dragInput

        if isMouseDrag or isTouchDrag then
            local pointer = Vector2.new(input.Position.X, input.Position.Y)
            local delta = pointer - dragStartPosition
            local desiredPosition = dragStartFramePosition + delta
            local position = desiredPosition
            local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
            if viewport then
                position = Vector2.new(
                    math.clamp(position.X, 0, math.max(0, viewport.X - MainFrame.AbsoluteSize.X)),
                    math.clamp(position.Y, 0, math.max(0, viewport.Y - MainFrame.AbsoluteSize.Y))
                )
            end
            local correction = position - desiredPosition
            MainFrame.Position = UDim2.new(
                dragStartGuiPosition.X.Scale,
                dragStartGuiPosition.X.Offset + delta.X + correction.X,
                dragStartGuiPosition.Y.Scale,
                dragStartGuiPosition.Y.Offset + delta.Y + correction.Y
            )
        end
    end

    if not resizeInput then
        return
    end

    local isMouseMove = resizeInput.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseMovement
    local isTouchMove = resizeInput.UserInputType == Enum.UserInputType.Touch
        and input == resizeInput
    if not (isMouseMove or isTouchMove) then
        return
    end

    local pointer = Vector2.new(input.Position.X, input.Position.Y)
    local delta = pointer - resizeStartPosition
    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
    local maxWidth = viewport and viewport.X - MainFrame.AbsolutePosition.X or 1000
    local maxHeight = viewport and viewport.Y - MainFrame.AbsolutePosition.Y or 1000
    local width = math.clamp(resizeStartSize.X + delta.X, 260, math.max(260, maxWidth))
    local height = math.clamp(resizeStartSize.Y + delta.Y, 220, math.max(220, maxHeight))

    expandedSize = UDim2.fromOffset(width, height)
    MainFrame.Size = expandedSize
end))

track(UserInputService.InputEnded:Connect(function(input)
    if dragInput and (
        input == dragInput
        or (dragInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseButton1)
    ) then
        dragInput = nil
        dragStartPosition = nil
        dragStartFramePosition = nil
        dragStartGuiPosition = nil
    end

    if resizeInput and (
        (resizeInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseButton1)
            or input == resizeInput
    ) then
        resizeInput = nil
        resizeStartPosition = nil
        resizeStartSize = nil
    end
end))

local minimized = false

track(MinimizeButton.MouseButton1Click:Connect(function()
    minimized = not minimized
    Container.Visible = not minimized
    ResizeHandle.Visible = not minimized
    MainFrame.Size = minimized
        and UDim2.fromOffset(expandedSize.X.Offset, 40)
        or expandedSize
    MinimizeButton.Text = minimized and "+" or "−"
end))

-- Close removes the menu and undoes everything (fly, noclip, speed, ESP...)
track(CloseButton.MouseButton1Click:Connect(function()
    if G.NativeMenuCleanup then
        G.NativeMenuCleanup()
        G.NativeMenuCleanup = nil
    end
end))

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 8)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Parent = Container

local layoutIndex = 0
local function nextOrder()
    layoutIndex = layoutIndex + 1
    return layoutIndex
end

local StatusLabel

SetStatus = function(text)
    if StatusLabel then
        StatusLabel.Text = text
    end
end

local function CreateSection(text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = UI_COLORS.MutedText
    label.Font = Enum.Font.GothamBold
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.LayoutOrder = nextOrder()
    label.Parent = Container
end

local function CreateHint(text, height)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, height or 30)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = UI_COLORS.MutedText
    label.Font = Enum.Font.Gotham
    label.TextSize = 10
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.LayoutOrder = nextOrder()
    label.Parent = Container
end

local function CreateToggle(text, key, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 35)
    button.BackgroundColor3 = UI_COLORS.Surface
    button.Font = Enum.Font.Gotham
    button.TextSize = 13
    button.LayoutOrder = nextOrder()
    button.Parent = Container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = button

    local function render()
        if G[key] then
            button.Text = text .. ": ON"
            button.TextColor3 = UI_COLORS.Enabled
        else
            button.Text = text .. ": OFF"
            button.TextColor3 = UI_COLORS.Disabled
        end
    end

    render()
    togglers[key] = render

    track(button.MouseButton1Click:Connect(function()
        G[key] = not G[key]
        render()

        if callback then
            callback(G[key])
        end
    end))
end

local function CreateButton(text, callback, backgroundColor)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 35)
    button.BackgroundColor3 = backgroundColor or UI_COLORS.Surface
    button.Text = text
    button.TextColor3 = UI_COLORS.Text
    button.Font = Enum.Font.Gotham
    button.TextSize = 13
    button.LayoutOrder = nextOrder()
    button.Parent = Container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = button

    track(button.MouseButton1Click:Connect(callback))
end

local function CreateTextBox(placeholder, callback)
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 0, 35)
    box.BackgroundColor3 = UI_COLORS.Surface
    box.PlaceholderText = placeholder
    box.Text = ""
    box.TextColor3 = UI_COLORS.Text
    box.PlaceholderColor3 = UI_COLORS.MutedText
    box.Font = Enum.Font.Gotham
    box.TextSize = 13
    box.LayoutOrder = nextOrder()
    box.Parent = Container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = box

    track(box.FocusLost:Connect(function()
        local num = tonumber(box.Text)
        if num then
            callback(num)
        end
    end))
end

-- Should set the player atutribe to true so i never die

-- task.spawn(function()
--   while true do
--     if LocalPlayer then
--       LocalPlayer:SetAttribute("Alive", true)
--       LocalPlayer:SetAttribute("HasDied", false)
--     end
--     task.wait(1)
--   end
-- end)


-- Typing a value turns the matching feature on so it takes effect
local function enable(key)
    G[key] = true
    if togglers[key] then
        togglers[key]()
    end
end



-- Movement
CreateSection("MOVEMENT")

CreateButton("↺  Reset GUI size", function()
    expandedSize = defaultFrameSize
    minimized = false
    Container.Visible = true
    ResizeHandle.Visible = true
    MainFrame.Size = defaultFrameSize
    MinimizeButton.Text = "−"
end, UI_COLORS.Accent)

CreateToggle("Unlimited Zoom", "UnlimitedZoomEnabled", nil)

CreateToggle("Speed", "SpeedEnabled", nil)
CreateTextBox("WalkSpeed (default 100)", function(val)
    G.WalkSpeedValue = math.clamp(val, 0)
    enable("SpeedEnabled")
end)

CreateToggle("Jump Power", "JumpEnabled", nil)
CreateTextBox("Jump Power (default 100)", function(val)
    G.JumpHeightValue = math.clamp(val, 0)
    enable("JumpEnabled")
end)

CreateToggle("Infinite Jump", "InfiniteJumpEnabled", nil)
CreateToggle("Noclip", "NoClipEnabled", nil)

CreateToggle("Shift Lock", "ShiftLockEnabled", nil)
CreateHint("Hold Left Alt to free the cursor and use the menu.", 26)

CreateToggle("Fly", "FlyEnabled", toggleFly)
CreateTextBox("Fly speed (default 75)", function(val)
    G.FlySpeedValue = math.clamp(val, 0)
end)
CreateHint("Fly: WASD move, Space/E up, Ctrl/Q down, Shift boost, F toggles fly.", 40)

CreateToggle("Invisibility", "InvisibleEnabled", nil)                                     --invisible button shit toggle make code
CreateToggle("Avatar Morph", "MorphEnabled", toggleMorph)
CreateHint("Morph uses the asset IDs in the MORPH table near the top of the script.", 40)

-- Aimbot
CreateSection("AIMBOT")

CreateToggle("Target Lock", "AimbotEnabled", nil)
CreateToggle("Skip Teammates", "AimbotTeamCheck", nil)
CreateTextBox("Aim strength (default 5; 0 = off, 100 = snap)", function(val)
    G.AimbotStrength = math.clamp(val, 0, 100)
end)

-- ESP
CreateSection("ESP")

CreateToggle("Highlight ESP", "HighlightESPEnabled", RefreshESP)
CreateToggle("Skeleton ESP", "BoneESPEnabled", RefreshESP)
CreateToggle("Nametag ESP", "NametagESPEnabled", RefreshESP)
CreateToggle("Armor ESP", "ArmorESPEnabled", RefreshESP)


-- Server stats
CreateTextBox("Damage multiplier (client-only visual)", function(val)
    G.LocalDamageMult = val  -- stores in your global table
    
    -- Sets attribute locally (only works if YOUR game code reads this attribute on the client)
    local character = LocalPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:SetAttribute("ClientDamageMultiplier", val)
        end
    end
    SetStatus("Local damage mult set to: " .. val .. " (visual only)")
end)

CreateTextBox("Attack speed (default 1)", function(val)
    -- keep your existing attack speed code here
end)


StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, 36)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = ""
StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 11
StatusLabel.TextWrapped = true
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.LayoutOrder = nextOrder()
StatusLabel.Parent = Container

-- F toggles fly (ignored while typing in a box or the chat)
track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or UserInputService:GetFocusedTextBox() then
        return
    end

    if input.KeyCode == Enum.KeyCode.F then
        G.FlyEnabled = not G.FlyEnabled
        if togglers.FlyEnabled then
            togglers.FlyEnabled()
        end
        toggleFly(G.FlyEnabled)
    end
end))

-- ==========================================================
-- Cleanup (called automatically if you run the script again)
-- ==========================================================

G.NativeMenuCleanup = function()
    runActive = false
    espWatchdogActive = false
    if espWatchdogThread then
        task.cancel(espWatchdogThread)
        espWatchdogThread = nil
    end
    pcall(function()
        RunService:UnbindFromRenderStep("NativeAimbot")
    end)
    G.FlyEnabled = false
    stopFly()

-- Undo the avatar morph before connections are dropped
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid and morphOriginal then
        revertMorph(humanoid)
    end
    G.MorphEnabled = false
    -- dick fart
    
    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    for player in pairs(playerConns) do
        UntrackESPPlayer(player)
    end

    for player in pairs(ESPData) do
        ClearPlayerESP(player)
    end

    for humanoid, saved in pairs(savedHumanoid) do
        if humanoid.Parent then
            restoreHumanoid(humanoid, saved)
        end
    end
    restoreCollisions()
    restoreZoom()
    restoreVisibility()
    releaseShiftLock()

    ESPFolder:Destroy()
    ScreenGui:Destroy()
end
