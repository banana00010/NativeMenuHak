-- ==========================================================
-- Version number - 0.3.0
-- Native Menu (fixed) - client-side script for your OWN game
-- ==========================================================

local Players = game:FindService("Players")
local RunService = game:FindService("RunService")
local UserInputService = game:FindService("UserInputService")
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

local DEFAULTS = {} -- remembered so "Reset all settings" can restore them

local function default(key, value)
    DEFAULTS[key] = value
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

-- Menu / customization settings
default("ThemeName", "Graphite")
default("MenuOpacity", 0.8)
default("MenuHotkey", "RightShift")
default("FlyHotkey", "F")
default("ServerHopPreferFriends", false)
default("ToastsEnabled", true)


-- Advanced settings (unlocked from the settings page)
default("AdvancedUnlocked", false)
default("InstantMoveEnabled", true)
default("FlyBoost", 3)
default("FlySmoothing", 10)
default("AimPart", "Head")
default("AimFOV", 0)

G.FlyEnabled = false
local connections = {}
local togglers = {}

local function track(connection)
    connections[#connections + 1] = connection
    return connection
end

-- Many games have 0 or 1 teams, where "same team" would wrongly mean everyone.
-- FindService returns nil when a game has no Teams service, so handle that.
local TeamsService = game:FindService("Teams")
local teamCount = 0

local function updateTeamCount()
    teamCount = TeamsService and #TeamsService:GetTeams() or 0
end

updateTeamCount()

if TeamsService then
    track(TeamsService.ChildAdded:Connect(updateTeamCount))
    track(TeamsService.ChildRemoved:Connect(updateTeamCount))
end

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
            if G.InstantMoveEnabled and hrp and not UserInputService:GetFocusedTextBox() then
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
--   F        toggle fly on/off (rebindable in settings)
-- Movement eases in and out, and you hover when no key is held.
-- Boost multiplier and smoothing are in the advanced settings.
-- ==========================================================

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
            local speed = G.FlySpeedValue * (boosting and G.FlyBoost or 1)
            target = dir.Unit * speed
        end

        -- Ease toward the target so starting and stopping feel smooth
        local alpha = 1 - math.exp(-dt * G.FlySmoothing)
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

-- Aim part is selectable in the advanced settings ("Head" or "Root")
local function getAimPart(character)
    if G.AimPart == "Root" then
        local root = character:FindFirstChild("HumanoidRootPart")
        if root then
            return root
        end
    end

    return getAdornee(character)
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
            local aimPart = getAimPart(player.Character)
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            local alive = humanoid == nil or humanoid.Health > 0

            if aimPart and alive then
                local screenPos, onScreen = camera:WorldToViewportPoint(aimPart.Position)

                if onScreen then
                    local distance = (Vector2.new(screenPos.X, screenPos.Y) - mouseLocation).Magnitude

                    -- AimFOV of 0 means no limit
                    if (G.AimFOV <= 0 or distance <= G.AimFOV) and distance < shortestDistance then
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
local highlightWarned = false

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

        local active = 0
        for _ in pairs(ESPData) do
            active = active + 1
        end
        if active > 31 and not highlightWarned and SetStatus then
            highlightWarned = true
            SetStatus("Roblox only draws about 31 highlights at once; extra players may have no outline.", "warn")
        end
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
-- Server hop
-- Joins a random public server of this game (never the current one).
-- With "Prefer friends' servers" on, it joins a friend's server first.
-- ==========================================================

local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local SERVER_HOP_MAX_PAGES = 5 -- 100 servers per page, only used when preferring friends
local serverHopBusy = false

local function fetchServerPage(cursor)
    local url = "https://games.roblox.com/v1/games/" .. game.PlaceId
        .. "/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true"

    if cursor then
        url = url .. "&cursor=" .. HttpService:UrlEncode(cursor)
    end

    local okRequest, response = pcall(function()
        return game:HttpGet(url)
    end)
    if not okRequest then
         if tostring(response):find("429") then
            return nil, "Roblox rate limit hit - wait a minute and try again"
        end
        return nil, "request failed (" .. tostring(response) .. ")"
    end

    local okDecode, body = pcall(function()
        return HttpService:JSONDecode(response)
    end)
    if not okDecode or type(body) ~= "table" then
        return nil, "unreadable response (rate limited?)"
    end

    return body
end

-- Friends who are in a DIFFERENT server of this same game: jobId -> name
local function getFriendServers()
    local result = {}
    local count = 0

    local ok, friends = pcall(function()
        return LocalPlayer:GetFriendsOnline(200)
    end)
    if not ok or type(friends) ~= "table" then
        return result, count, false
    end

    for _, friend in ipairs(friends) do
        if friend.PlaceId == game.PlaceId
            and type(friend.GameId) == "string"
            and friend.GameId ~= ""
            and friend.GameId ~= game.JobId then
            result[friend.GameId] = friend.DisplayName or friend.UserName or "a friend"
            count = count + 1
        end
    end

    return result, count, true
end

local function serverHop()
    if serverHopBusy then
        SetStatus("Server hop is already running...")
        return
    end
    serverHopBusy = true

    task.spawn(function() -- HttpGet yields, so keep it off the UI thread
        local preferFriends = G.ServerHopPreferFriends
        local friendServers, friendCount, friendsOk = {}, 0, true
        if preferFriends then
            friendServers, friendCount, friendsOk = getFriendServers()
        end
        local hitPageCap = false
        local pagesToCheck = preferFriends and SERVER_HOP_MAX_PAGES or 1

        local candidates = {}
        local friendTarget, friendName
        local cursor

        for page = 1, pagesToCheck do
            local body, err = fetchServerPage(cursor)
            if not body then
                SetStatus("Server hop: " .. err, "warn")
                break
            end

            if type(body.data) == "table" then
                for _, server in ipairs(body.data) do
                    if type(server) == "table"
                        and type(server.id) == "string"
                        and tonumber(server.playing)
                        and tonumber(server.maxPlayers)
                        and server.playing < server.maxPlayers
                        and server.id ~= game.JobId then
                        candidates[#candidates + 1] = server.id

                        if friendServers[server.id] and not friendTarget then
                            friendTarget = server.id
                            friendName = friendServers[server.id]
                        end
                    end
                end
            end

            cursor = body.nextPageCursor
            if friendTarget or type(cursor) ~= "string" then
                break
            end

            if page == pagesToCheck then
                hitPageCap = true
            end

            task.wait(0.4) -- stay under Roblox's rate limit
        end

        if not runActive then
            serverHopBusy = false
            return
        end

        local target = friendTarget
        if target then
            SetStatus("Joining " .. friendName .. "'s server...")
        elseif #candidates > 0 then
            target = candidates[math.random(1, #candidates)]
            if preferFriends then
                local reason
                if not friendsOk then
                    reason = "Couldn't read your friends list"
                elseif friendCount == 0 then
                    reason = "No friends are in another server of this game"
                elseif hitPageCap then
                    reason = "Your friends' servers weren't in the first "
                        .. (SERVER_HOP_MAX_PAGES * 100) .. " servers"
                else
                    reason = "Your friends' servers are full or private"
                end
                SetStatus(reason .. ". Joining a random one...", "warn")
            else
                SetStatus("Joining a random server...")
            end
        end

        local ok, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, target, LocalPlayer)
        end)
        if not ok then
            SetStatus("Teleport failed: " .. tostring(err), "warn")
        end

        task.delay(8, function()
            serverHopBusy = false
        end)
    end)
end

track(TeleportService.TeleportInitFailed:Connect(function(player, _, message)
    if player == LocalPlayer then
        SetStatus("Teleport failed: " .. tostring(message), "warn")
        serverHopBusy = false
    end
end))

-- ==========================================================
-- GUI
--   Tabs: MOVE / COMBAT / VISUALS
--   Click the logo (N) to open the settings page.
-- ==========================================================

local THEMES = {
    {
        name = "Midnight",
        Background = Color3.fromRGB(18, 24, 36),
        Header = Color3.fromRGB(28, 38, 55),
        Surface = Color3.fromRGB(34, 45, 64),
        Accent = Color3.fromRGB(68, 105, 190),
        Border = Color3.fromRGB(59, 76, 102),
    },
    {
        name = "Graphite",
        Background = Color3.fromRGB(24, 24, 27),
        Header = Color3.fromRGB(36, 36, 40),
        Surface = Color3.fromRGB(46, 46, 52),
        Accent = Color3.fromRGB(96, 104, 122),
        Border = Color3.fromRGB(70, 70, 78),
    },
    {
        name = "Violet",
        Background = Color3.fromRGB(26, 20, 38),
        Header = Color3.fromRGB(40, 30, 58),
        Surface = Color3.fromRGB(52, 40, 76),
        Accent = Color3.fromRGB(124, 82, 226),
        Border = Color3.fromRGB(85, 66, 120),
    },
    {
        name = "Forest",
        Background = Color3.fromRGB(18, 30, 26),
        Header = Color3.fromRGB(26, 44, 38),
        Surface = Color3.fromRGB(34, 58, 50),
        Accent = Color3.fromRGB(44, 150, 106),
        Border = Color3.fromRGB(58, 94, 80),
    },
    {
        name = "Crimson",
        Background = Color3.fromRGB(32, 20, 22),
        Header = Color3.fromRGB(50, 28, 32),
        Surface = Color3.fromRGB(66, 38, 44),
        Accent = Color3.fromRGB(190, 62, 84),
        Border = Color3.fromRGB(110, 62, 70),
    },
}

local function findTheme(name)
    for _, theme in ipairs(THEMES) do
        if theme.name == name then
            return theme
        end
    end
    return THEMES[1]
end

local UI_COLORS = {
    Text = Color3.fromRGB(235, 240, 248),
    MutedText = Color3.fromRGB(153, 167, 188),
    Enabled = Color3.fromRGB(94, 220, 174),
    Disabled = Color3.fromRGB(235, 128, 137),
}

local function loadThemeColors(name)
    local theme = findTheme(name)
    G.ThemeName = theme.name
    UI_COLORS.Background = theme.Background
    UI_COLORS.Header = theme.Header
    UI_COLORS.Surface = theme.Surface
    UI_COLORS.Accent = theme.Accent
    UI_COLORS.Border = theme.Border
end

loadThemeColors(G.ThemeName)

-- Everything that uses a theme color is registered here so a theme
-- change can recolor the whole menu without rebuilding it.
local themed = {}
local themeHooks = {}
local refreshers = {}

local function themeBind(instance, property, colorKey)
    instance[property] = UI_COLORS[colorKey]
    themed[#themed + 1] = { instance, property, colorKey }
    return instance
end

local function applyTheme()
    for _, entry in ipairs(themed) do
        local instance = entry[1]
        if instance.Parent then
            instance[entry[2]] = UI_COLORS[entry[3]]
        end
    end

    for _, hook in ipairs(themeHooks) do
        hook()
    end

    for _, render in pairs(togglers) do
        render()
    end
end

local function runRefreshers()
    for _, refresh in ipairs(refreshers) do
        refresh()
    end

    for _, render in pairs(togglers) do
        render()
    end
end

local function addCorner(instance, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 7)
    corner.Parent = instance
    return corner
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SolaraNativeMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
local defaultFrameSize = UDim2.fromOffset(300, 440)
MainFrame.Size = defaultFrameSize
MainFrame.Position = UDim2.new(0.1, 0, 0.2, 0)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui
themeBind(MainFrame, "BackgroundColor3", "Background")
addCorner(MainFrame, 10)

local FrameStroke = Instance.new("UIStroke")
FrameStroke.Transparency = 0.25
FrameStroke.Thickness = 1
FrameStroke.Parent = MainFrame
themeBind(FrameStroke, "Color", "Border")

local HeaderPanel = Instance.new("Frame")
HeaderPanel.Name = "HeaderPanel"
HeaderPanel.Size = UDim2.new(1, 0, 0, 40)
HeaderPanel.BorderSizePixel = 0
HeaderPanel.Parent = MainFrame
themeBind(HeaderPanel, "BackgroundColor3", "Header")
addCorner(HeaderPanel, 10)

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Position = UDim2.new(0, 44, 0, 0)
Title.Size = UDim2.new(1, -144, 0, 40)
Title.BackgroundTransparency = 1
Title.Text = "NATIVE  v0.3.0"
Title.TextColor3 = UI_COLORS.Text
Title.Font = Enum.Font.GothamBold
Title.TextSize = 11
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Active = true
Title.Parent = HeaderPanel

-- The logo is a button: click it to open or close the settings page
local LogoButton = Instance.new("TextButton")
LogoButton.Name = "Logo"
LogoButton.Position = UDim2.new(0, 12, 0, 7)
LogoButton.Size = UDim2.fromOffset(26, 26)
LogoButton.BorderSizePixel = 0
LogoButton.Text = "N"
LogoButton.TextColor3 = UI_COLORS.Text
LogoButton.Font = Enum.Font.GothamBlack
LogoButton.TextSize = 16
LogoButton.Parent = HeaderPanel
themeBind(LogoButton, "BackgroundColor3", "Accent")
addCorner(LogoButton, 7)

local LogoPadding = Instance.new("UIPadding")
LogoPadding.PaddingRight = UDim.new(0, 2)
LogoPadding.Parent = LogoButton

local LogoStroke = Instance.new("UIStroke")
LogoStroke.Color = UI_COLORS.Text
LogoStroke.Thickness = 2
LogoStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
LogoStroke.Enabled = false
LogoStroke.Parent = LogoButton

local StatusToast = Instance.new("TextLabel")
StatusToast.Name = "StatusToast"
StatusToast.Position = UDim2.new(0, 0, 0, -34)
StatusToast.Size = UDim2.new(1, 0, 0, 28)
StatusToast.BorderSizePixel = 0
StatusToast.TextColor3 = UI_COLORS.Text
StatusToast.Font = Enum.Font.Gotham
StatusToast.TextSize = 11
StatusToast.TextWrapped = true
StatusToast.Visible = false
StatusToast.Parent = MainFrame
themeBind(StatusToast, "BackgroundColor3", "Header")
addCorner(StatusToast, 7)

-- Body holds the tab bar, the pages and the footer (hidden when minimized)
local Body = Instance.new("Frame")
Body.Name = "Body"
Body.Position = UDim2.new(0, 0, 0, 40)
Body.Size = UDim2.new(1, 0, 1, -40)
Body.BackgroundTransparency = 1
Body.BorderSizePixel = 0
Body.Parent = MainFrame

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

local function makeTitleButton(text, xOffset, colorKey)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 28, 0, 28)
    button.Position = UDim2.new(1, xOffset, 0, 6)
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = UI_COLORS.Text
    button.Font = Enum.Font.GothamBold
    button.TextSize = 15
    button.Parent = HeaderPanel
    themeBind(button, "BackgroundColor3", colorKey)
    addCorner(button, 7)

    return button
end

-- Left to right: minimize, reset, close
local CloseButton = makeTitleButton("×", -34, "Surface")
CloseButton.BackgroundColor3 = Color3.fromRGB(155, 65, 78)
themed[#themed] = nil -- the close button keeps its red in every theme
local ResetButton = makeTitleButton("↺", -66, "Accent")
local MinimizeButton = makeTitleButton("−", -98, "Surface")

local ResizeHandle = Instance.new("TextButton")
ResizeHandle.Name = "ResizeHandle"
ResizeHandle.Size = UDim2.new(0, 20, 0, 20)
ResizeHandle.Position = UDim2.new(1, -22, 1, -22)
ResizeHandle.BorderSizePixel = 0
ResizeHandle.Text = "↘"
ResizeHandle.TextColor3 = UI_COLORS.Text
ResizeHandle.Font = Enum.Font.GothamBold
ResizeHandle.TextSize = 14
ResizeHandle.ZIndex = 10
ResizeHandle.Parent = MainFrame
themeBind(ResizeHandle, "BackgroundColor3", "Surface")
addCorner(ResizeHandle, 6)

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
    local height = math.clamp(resizeStartSize.Y + delta.Y, 260, math.max(260, maxHeight))

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
    Body.Visible = not minimized
    ResizeHandle.Visible = not minimized
    MainFrame.Size = minimized
        and UDim2.fromOffset(expandedSize.X.Offset, 40)
        or expandedSize
    MinimizeButton.Text = minimized and "+" or "−"
end))

-- Resets size, position and the minimized state (also in the settings page)
local function resetWindow()
    expandedSize = defaultFrameSize
    minimized = false
    Body.Visible = true
    ResizeHandle.Visible = true
    MainFrame.Size = defaultFrameSize
    MainFrame.Position = UDim2.new(0.1, 0, 0.2, 0)
    MinimizeButton.Text = "−"
end

track(ResetButton.MouseButton1Click:Connect(resetWindow))

-- Close removes the menu and undoes everything (fly, noclip, speed, ESP...)
track(CloseButton.MouseButton1Click:Connect(function()
    if G.NativeMenuCleanup then
        G.NativeMenuCleanup()
        G.NativeMenuCleanup = nil
    end
end))

local statusToastId = 0
SetStatus = function(text, kind)
    if G.ToastsEnabled == false then
        return
    end

    statusToastId = statusToastId + 1
    local currentToastId = statusToastId
    StatusToast.Text = text
    StatusToast.TextColor3 = kind == "warn" and Color3.fromRGB(255, 200, 90) or UI_COLORS.Text
    StatusToast.Visible = true
    task.delay(3, function()
        if currentToastId == statusToastId and StatusToast.Parent then
            StatusToast.Visible = false
        end
    end)
end

local function applyOpacity()
    local transparency = 1 - math.clamp(G.MenuOpacity, 0.3, 1)
    MainFrame.BackgroundTransparency = transparency
    HeaderPanel.BackgroundTransparency = transparency
end

-- ==========================================================
-- Tabs and pages
-- ==========================================================

local pages = {}
local tabButtons = {}
local activePage = "Move"
local lastMainPage = "Move"

local function refreshTabs()
    for name, button in pairs(tabButtons) do
        local active = activePage == name
        button.BackgroundColor3 = active and UI_COLORS.Accent or UI_COLORS.Surface
        button.TextColor3 = active and UI_COLORS.Text or UI_COLORS.MutedText
    end

    LogoStroke.Enabled = activePage == "Settings"
end

themeHooks[#themeHooks + 1] = refreshTabs

local function showPage(name)
    activePage = name
    if name ~= "Settings" then
        lastMainPage = name
    end

    for pageName, page in pairs(pages) do
        page.Visible = pageName == name
    end

    refreshTabs()
end

local TabBar = Instance.new("Frame")
TabBar.Name = "TabBar"
TabBar.Position = UDim2.new(0, 10, 0, 6)
TabBar.Size = UDim2.new(1, -20, 0, 28)
TabBar.BackgroundTransparency = 1
TabBar.BorderSizePixel = 0
TabBar.Parent = Body

local tabNames = { "Move", "Combat", "Visuals" }

for index, name in ipairs(tabNames) do
    local button = Instance.new("TextButton")
    button.Name = name .. "Tab"
    button.Size = UDim2.new(1 / #tabNames, -4, 1, 0)
    button.Position = UDim2.new((index - 1) / #tabNames, 2, 0, 0)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamBold
    button.TextSize = 11
    button.Text = string.upper(name)
    button.Parent = TabBar
    addCorner(button, 7)

    tabButtons[name] = button
    track(button.MouseButton1Click:Connect(function()
        showPage(name)
    end))
end

local function newPage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name .. "Page"
    page.Position = UDim2.new(0, 10, 0, 42)
    page.Size = UDim2.new(1, -20, 1, -70)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.ScrollingDirection = Enum.ScrollingDirection.Y
    page.ScrollBarThickness = 4
    page.Visible = false
    page.Parent = Body

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page

    local padding = Instance.new("UIPadding")
    padding.PaddingRight = UDim.new(0, 8)
    padding.PaddingTop = UDim.new(0, 2)
    padding.Parent = page

    pages[name] = page
    return page
end

local pageMove = newPage("Move")
local pageCombat = newPage("Combat")
local pageVisuals = newPage("Visuals")
local pageSettings = newPage("Settings")

-- Footer: shows the current hide/show key
local FooterLabel = Instance.new("TextLabel")
FooterLabel.Name = "Footer"
FooterLabel.Position = UDim2.new(0, 12, 1, -22)
FooterLabel.Size = UDim2.new(1, -48, 0, 16)
FooterLabel.BackgroundTransparency = 1
FooterLabel.TextColor3 = UI_COLORS.MutedText
FooterLabel.Font = Enum.Font.Gotham
FooterLabel.TextSize = 10
FooterLabel.TextXAlignment = Enum.TextXAlignment.Left
FooterLabel.Parent = Body

local function refreshFooter()
    FooterLabel.Text = "[" .. tostring(G.MenuHotkey) .. "] hide / show menu   ·   logo = settings"
end

refreshFooter()
refreshers[#refreshers + 1] = refreshFooter

-- ==========================================================
-- Widgets (each one is added to whatever currentParent is)
-- ==========================================================

local currentParent
local orderCounters = setmetatable({}, { __mode = "k" })

local function nextOrder()
    orderCounters[currentParent] = (orderCounters[currentParent] or 0) + 1
    return orderCounters[currentParent]
end

local function newRow(height)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, height)
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.LayoutOrder = nextOrder()
    row.Parent = currentParent
    return row
end

local function newButton(parent, size, position)
    local button = Instance.new("TextButton")
    button.Size = size
    button.Position = position or UDim2.new(0, 0, 0, 0)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.Gotham
    button.TextSize = 13
    button.TextColor3 = UI_COLORS.Text
    button.Parent = parent
    themeBind(button, "BackgroundColor3", "Surface")
    addCorner(button, 7)
    return button
end

local function newBox(parent, size, position)
    local box = Instance.new("TextBox")
    box.Size = size
    box.Position = position or UDim2.new(0, 0, 0, 0)
    box.BorderSizePixel = 0
    box.Font = Enum.Font.Gotham
    box.TextSize = 13
    box.TextColor3 = UI_COLORS.Text
    box.PlaceholderColor3 = UI_COLORS.MutedText
    box.Text = ""
    box.Parent = parent
    themeBind(box, "BackgroundColor3", "Surface")
    addCorner(box, 7)
    return box
end

-- Typing a value turns the matching feature on so it takes effect
local function enable(key)
    G[key] = true
    if togglers[key] then
        togglers[key]()
    end
end

-- Clamps a typed value and tells the user when a limit changed it
local function clampWithNotice(value, minV, maxV, label)
    local clamped = math.clamp(value, minV, maxV)

    if clamped ~= value then
        local which = value > maxV and "max" or "min"
        SetStatus(label .. ": " .. which .. " is " .. tostring(clamped)
            .. " (you typed " .. tostring(value) .. ")", "warn")
    end

    return clamped
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
    label.Parent = currentParent
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
    label.Parent = currentParent
end

local function bindToggleText(button, text, key)
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
end

local function CreateToggle(text, key, callback)
    local row = newRow(32)
    local button = newButton(row, UDim2.new(1, 0, 1, 0))
    bindToggleText(button, text, key)

    track(button.MouseButton1Click:Connect(function()
        G[key] = not G[key]
        togglers[key]()

        if callback then
            callback(G[key])
        end
    end))
end

-- A toggle and its number box side by side, e.g. "Speed: ON | 100"
local function CreateToggleValue(text, key, valueKey, minV, maxV, autoEnable, callback)
    local row = newRow(32)
    local button = newButton(row, UDim2.new(0.56, -3, 1, 0))
    bindToggleText(button, text, key)

    local box = newBox(row, UDim2.new(0.44, -3, 1, 0), UDim2.new(0.56, 3, 0, 0))

    local function refreshBox()
        box.Text = tostring(G[valueKey])
    end

    refreshBox()
    refreshers[#refreshers + 1] = refreshBox

    track(button.MouseButton1Click:Connect(function()
        G[key] = not G[key]
        togglers[key]()

        if callback then
            callback(G[key])
        end
    end))

    track(box.FocusLost:Connect(function()
        local num = tonumber(box.Text)
        if num and num == num then
            G[valueKey] = math.clamp(num, minV, maxV)
            if autoEnable then
                enable(key)
            end
        end
        refreshBox()
    end))
end

-- A label with a number box: "Aim strength | 5"
local function CreateValueRow(text, valueKey, minV, maxV, callback)
    local row = newRow(32)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.58, -3, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = UI_COLORS.Text
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local box = newBox(row, UDim2.new(0.42, -3, 1, 0), UDim2.new(0.58, 3, 0, 0))

    local function refreshBox()
        box.Text = tostring(G[valueKey])
    end

    refreshBox()
    refreshers[#refreshers + 1] = refreshBox

    track(box.FocusLost:Connect(function()
        local num = tonumber(box.Text)
        if num and num == num then
            G[valueKey] = clampWithNotice(num, minV, maxV, text)
            if callback then
                callback(G[valueKey])
            end
        elseif box.Text ~= "" then
            SetStatus(text .. ": enter a number", "warn")
        end
        refreshBox()
    end))
end

-- A button that cycles through a fixed list of options
local function CreateChoice(text, key, options)
    local row = newRow(32)
    local button = newButton(row, UDim2.new(1, 0, 1, 0))

    local function refresh()
        button.Text = text .. ": " .. tostring(G[key])
    end

    refresh()
    refreshers[#refreshers + 1] = refresh

    track(button.MouseButton1Click:Connect(function()
        local nextIndex = 1
        for index, option in ipairs(options) do
            if option == G[key] then
                nextIndex = index % #options + 1
            end
        end
        G[key] = options[nextIndex]
        refresh()
    end))
end

local function CreateButton(text, callback)
    local row = newRow(32)
    local button = newButton(row, UDim2.new(1, 0, 1, 0))
    button.Text = text
    track(button.MouseButton1Click:Connect(callback))
end

-- Keybinds: click, then press the key you want (Escape cancels)
local captureHandler

local function keyFromName(name)
    local ok, keyCode = pcall(function()
        return Enum.KeyCode[name]
    end)

    if ok then
        return keyCode
    end
    return nil
end

local function CreateKeybind(text, key, otherKey)
    local row = newRow(32)
    local button = newButton(row, UDim2.new(1, 0, 1, 0))

    local function refresh()
        button.Text = text .. ": " .. tostring(G[key])
    end

    refresh()
    refreshers[#refreshers + 1] = refresh

    track(button.MouseButton1Click:Connect(function()
        button.Text = text .. ": press a key..."

        captureHandler = function(keyCode)
            if keyCode ~= Enum.KeyCode.Escape and keyCode ~= Enum.KeyCode.Unknown then
                if G[otherKey] == keyCode.Name then
                    SetStatus("That key is already used by another action.")
                else
                    G[key] = keyCode.Name
                end
            end
            runRefreshers()
        end
    end))
end

local function CreateOpacityRow()
    local row = newRow(32)

    local minus = newButton(row, UDim2.new(0, 36, 1, 0))
    minus.Text = "−"

    local plus = newButton(row, UDim2.new(0, 36, 1, 0), UDim2.new(1, -36, 0, 0))
    plus.Text = "+"

    local label = Instance.new("TextLabel")
    label.Position = UDim2.new(0, 42, 0, 0)
    label.Size = UDim2.new(1, -84, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = UI_COLORS.Text
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.Parent = row

    local function refresh()
        label.Text = "Opacity: " .. math.floor(G.MenuOpacity * 100 + 0.5) .. "%"
        applyOpacity()
    end

    local function step(amount)
        local value = math.floor(G.MenuOpacity * 10 + 0.5) / 10 + amount
        G.MenuOpacity = math.clamp(math.floor(value * 10 + 0.5) / 10, 0.3, 1)
        refresh()
    end

    refresh()
    refreshers[#refreshers + 1] = refresh

    track(minus.MouseButton1Click:Connect(function()
        step(-0.1)
    end))
    track(plus.MouseButton1Click:Connect(function()
        step(0.1)
    end))
end

local function setTheme(name)
    loadThemeColors(name)
    applyTheme()
    runRefreshers()
end

local function CreateThemePicker()
    local row = newRow(32)
    local count = #THEMES

    for index, theme in ipairs(THEMES) do
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1 / count, -4, 1, 0)
        button.Position = UDim2.new((index - 1) / count, 2, 0, 0)
        button.BackgroundColor3 = theme.Accent
        button.BorderSizePixel = 0
        button.Text = theme.name
        button.Font = Enum.Font.GothamBold
        button.TextSize = 9
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.Parent = row
        addCorner(button, 6)

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(255, 255, 255)
        stroke.Thickness = 2
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Enabled = G.ThemeName == theme.name
        stroke.Parent = button

        refreshers[#refreshers + 1] = function()
            stroke.Enabled = G.ThemeName == theme.name
        end

        track(button.MouseButton1Click:Connect(function()
            setTheme(theme.name)
        end))
    end
end

-- ==========================================================
-- Reset all settings (every default registered at the top)
-- ==========================================================

local AdvancedFrame

local function resetAllSettings()
    local wasMorph = G.MorphEnabled

    for key, value in pairs(DEFAULTS) do
        G[key] = value
    end

    G.FlyEnabled = false
    stopFly()

    if wasMorph then
        toggleMorph(false)
    end

    setTheme(G.ThemeName)
    applyOpacity()
    AdvancedFrame.Visible = G.AdvancedUnlocked
    runRefreshers()
    SetStatus("All settings reset to defaults.")
end

-- ==========================================================
-- MOVE tab
-- ==========================================================

currentParent = pageMove

CreateSection("MOVEMENT")
CreateToggleValue("Speed", "SpeedEnabled", "WalkSpeedValue", 0, 1000000, true)
CreateToggleValue("Jump Power", "JumpEnabled", "JumpHeightValue", 0, 1000000, true)
CreateToggle("Infinite Jump", "InfiniteJumpEnabled")
CreateToggle("Noclip", "NoClipEnabled")

CreateSection("FLIGHT")
CreateToggleValue("Fly", "FlyEnabled", "FlySpeedValue", 0, 1000000, false, toggleFly)
CreateHint("WASD move · Space/E up · Ctrl/Q down · Shift boost · fly key toggles (F by default).", 40)

CreateSection("CAMERA")
CreateToggle("Unlimited Zoom", "UnlimitedZoomEnabled")
CreateToggle("Shift Lock", "ShiftLockEnabled")
CreateHint("Hold Left Alt to free the cursor and use the menu.", 26)
CreateSection("SERVER")
CreateToggle("Prefer friends' servers", "ServerHopPreferFriends")
CreateButton("Server hop", serverHop)

-- ==========================================================
-- COMBAT tab
-- ==========================================================

currentParent = pageCombat

CreateSection("TARGET LOCK")
CreateToggle("Target Lock", "AimbotEnabled")
CreateToggle("Skip Teammates", "AimbotTeamCheck")
CreateValueRow("Aim strength", "AimbotStrength", 0, 100)
CreateHint("0 = off, 100 = instant snap. Lower values pull the camera more gently.", 30)

-- ==========================================================
-- VISUALS tab
-- ==========================================================

currentParent = pageVisuals

CreateSection("ESP")
CreateToggle("Highlight ESP", "HighlightESPEnabled", RefreshESP)
CreateToggle("Skeleton ESP", "BoneESPEnabled", RefreshESP)
CreateToggle("Nametag ESP", "NametagESPEnabled", RefreshESP)
CreateToggle("Armor ESP", "ArmorESPEnabled", RefreshESP)

CreateSection("YOUR CHARACTER")
CreateToggle("Invisibility", "InvisibleEnabled")
CreateToggle("Avatar Morph", "MorphEnabled", toggleMorph)
CreateHint("Morph uses the asset IDs in the MORPH table near the top of the script.", 40)

-- ==========================================================
-- SETTINGS page (click the logo)
-- ==========================================================

currentParent = pageSettings

CreateSection("APPEARANCE")
CreateThemePicker()
CreateOpacityRow()

CreateSection("CONTROLS")
CreateKeybind("Menu key", "MenuHotkey", "FlyHotkey")
CreateKeybind("Fly key", "FlyHotkey", "MenuHotkey")

CreateSection("GENERAL")
CreateToggle("Notifications", "ToastsEnabled")
CreateButton("Reset window", resetWindow)
CreateButton("Reset all settings", resetAllSettings)

-- Secret section: click the logo 5 times quickly to show or hide it
AdvancedFrame = Instance.new("Frame")
AdvancedFrame.Name = "Advanced"
AdvancedFrame.Size = UDim2.new(1, 0, 0, 0)
AdvancedFrame.AutomaticSize = Enum.AutomaticSize.Y
AdvancedFrame.BackgroundTransparency = 1
AdvancedFrame.BorderSizePixel = 0
AdvancedFrame.LayoutOrder = nextOrder()
AdvancedFrame.Visible = G.AdvancedUnlocked
AdvancedFrame.Parent = pageSettings

local advancedLayout = Instance.new("UIListLayout")
advancedLayout.Padding = UDim.new(0, 8)
advancedLayout.SortOrder = Enum.SortOrder.LayoutOrder
advancedLayout.Parent = AdvancedFrame

currentParent = AdvancedFrame

CreateSection("ADVANCED")
CreateToggle("Instant WASD start/stop", "InstantMoveEnabled")
CreateValueRow("Fly boost (x)", "FlyBoost", 1, 100)
CreateValueRow("Fly smoothing", "FlySmoothing", 1, 100)
CreateHint("Fly smoothing: higher = snappier turns and stops, lower = floatier.", 26)
CreateChoice("Aim part", "AimPart", { "Head", "Root" })
CreateValueRow("Aim FOV (px)", "AimFOV", 0, 5000)
CreateHint("Aim FOV limits targets to this distance from your cursor. 0 = no limit.", 26)
CreateHint("Click the logo 5 times quickly to hide this section again.", 26)

-- ==========================================================
-- Logo button: settings page + secret unlock
-- ==========================================================

local logoClicks = {}

track(LogoButton.MouseButton1Click:Connect(function()
    local now = os.clock()
    local recent = {}

    logoClicks[#logoClicks + 1] = now
    for _, clickTime in ipairs(logoClicks) do
        if now - clickTime <= 2 then
            recent[#recent + 1] = clickTime
        end
    end
    logoClicks = recent

    if #logoClicks >= 5 then
        logoClicks = {}
        G.AdvancedUnlocked = not G.AdvancedUnlocked
        AdvancedFrame.Visible = G.AdvancedUnlocked
        showPage("Settings")
        SetStatus(G.AdvancedUnlocked and "Advanced settings unlocked." or "Advanced settings hidden.")
        return
    end

    if activePage == "Settings" then
        showPage(lastMainPage)
    else
        showPage("Settings")
    end
end))

-- ==========================================================
-- Hotkeys (menu key and fly key are rebindable in settings)
-- ==========================================================

track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end

    -- A keybind button is waiting for the next key press
    if captureHandler then
        local handler = captureHandler
        captureHandler = nil
        handler(input.KeyCode)
        return
    end

    if gameProcessed or UserInputService:GetFocusedTextBox() then
        return
    end

    if input.KeyCode == keyFromName(G.MenuHotkey) then
        MainFrame.Visible = not MainFrame.Visible
    elseif input.KeyCode == keyFromName(G.FlyHotkey) then
        G.FlyEnabled = not G.FlyEnabled
        if togglers.FlyEnabled then
            togglers.FlyEnabled()
        end
        toggleFly(G.FlyEnabled)
    end
end))

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

-- Start on the Move tab with the saved theme and opacity applied
applyOpacity()
showPage("Move")

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