-- ==========================================================
-- Version number - 0.3.4
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

-- Tables are copied so a reset never hands back the live (edited) table
local function copyValue(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for k, v in pairs(value) do
        copy[k] = v
    end
    return copy
end

-- ----------------------------------------------------------
-- Saved settings (workspace/NativeMenu/settings.json)
-- Needs an executor with readfile / writefile; without them the menu simply
-- keeps its settings for the current session only.
-- ----------------------------------------------------------
local Persist = {}
do
    local HttpService = game:GetService("HttpService")
    local FILE = "NativeMenu/settings.json"

    -- Saved on top of the defaults: things that are not plain settings
    Persist.extra = { "Playlist", "PerfPos", "Spotify", "PointerOffset" }
    Persist.supported = type(writefile) == "function"
        and type(readfile) == "function"
        and type(isfile) == "function"
    Persist.lastJson = nil

    function Persist.read()
        if not Persist.supported then
            return nil
        end

        local ok, data = pcall(function()
            if not isfile(FILE) then
                return nil
            end
            return HttpService:JSONDecode(readfile(FILE))
        end)

        if ok and type(data) == "table" then
            return data
        end
        return nil
    end

    function Persist.save()
        if not Persist.supported then
            return
        end

        local out = {}
        for key in pairs(DEFAULTS) do
            out[key] = G[key]
        end
        for _, key in ipairs(Persist.extra) do
            out[key] = G[key]
        end

        local ok, json = pcall(function()
            return HttpService:JSONEncode(out)
        end)
        if not ok or json == Persist.lastJson then
            return
        end

        pcall(function()
            if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("NativeMenu") then
                makefolder("NativeMenu")
            end
            writefile(FILE, json)
        end)
        Persist.lastJson = json
    end

    Persist.data = Persist.read()
end

for _, key in ipairs(Persist.extra) do
    if G[key] == nil and Persist.data and Persist.data[key] ~= nil then
        G[key] = Persist.data[key]
    end
end

local function default(key, value)
    DEFAULTS[key] = value
    if G[key] == nil then
        -- A saved value is only used when it has the same type as the default
        local stored = Persist.data and Persist.data[key]
        if stored ~= nil and type(stored) == type(value) then
            G[key] = stored
        else
            G[key] = copyValue(value)
        end
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
default("UnlimitedZoomEnabled", true)

-- Menu / customization settings
default("ThemeName", "Graphite")
default("MenuOpacity", 0.8)
-- Keybinds: action id -> key name (see the Keybinds section further down)
default("Binds", { Menu = "RightShift", FlyEnabled = "F" })

-- One-time carry-over of the old menu key / fly key settings
if not G.BindsMigrated then
    G.BindsMigrated = true
    if type(G.MenuHotkey) == "string" then
        G.Binds.Menu = G.MenuHotkey
    end
    if type(G.FlyHotkey) == "string" then
        G.Binds.FlyEnabled = G.FlyHotkey
    end
end
default("ServerHopPreferFriends", false)
default("ToastsEnabled", true)


-- Advanced settings (unlocked from the settings page)
default("AdvancedUnlocked", false)
default("InstantMoveEnabled", true)
default("FlyBoost", 3)
default("FlySmoothing", 10)
default("AimPart", "Head")
default("AimFOV", 0)

-- 0.3.4 additions ------------------------------------------------
default("CameraFOVEnabled", false)
default("CameraFOVValue", 90)
default("GravityEnabled", false)
default("GravityValue", 196)
default("AntiAFKEnabled", false)
default("ShowAimFOVCircle", false)
default("PointerAutoCalibrate", true)
default("SpotifyVolume", 50)

-- ESP style
default("ESPEnemyColor", { 255, 70, 70 })
default("ESPTeamColor", { 70, 170, 255 })
default("ESPFillTransparency", 0.8)
default("ESPOutlineTransparency", 0)
default("ESPMaxDistance", 0) -- 0 = no limit
default("ESPShowDistance", true)

-- Interface
default("CustomTheme", { h = 0.62, s = 0.6, v = 0.85 })
default("UIScale", 1)
default("TooltipsEnabled", true)
default("TooltipDelay", 1)
default("SfxEnabled", true)
default("SfxVolume", 0.5)
default("ToastDuration", 3)
default("Collapsed", { ["Settings/KEYBINDS"] = true })

-- Performance stats overlay
default("PerfEnabled", false)
default("PerfFPS", true)
default("PerfPing", true)
default("PerfFrameTime", false)
default("PerfMemory", true)
default("PerfPlayers", false)
default("PerfClock", false)
default("PerfPosition", false)
default("PerfSpeed", false)
default("PerfGraph", false)
default("PerfColorCode", true)
default("PerfAccentLabels", true)
default("PerfLayout", "Vertical")
default("PerfCorner", "Top Left")
default("PerfScale", 1)
default("PerfOpacity", 0.35)
default("PerfInterval", 0.5)

-- Music player (the playlist itself is never reset by "Reset all settings")
default("MusicVolume", 0.5)
default("MusicShuffle", false)
default("MusicLoop", "All")
if type(G.Playlist) ~= "table" then
    G.Playlist = {}
end
if type(G.PointerOffset) ~= "number" then
    G.PointerOffset = 0
end
if type(G.Spotify) ~= "table" then
    G.Spotify = {}
end
for id, keyName in pairs(G.Binds) do
    if type(keyName) ~= "string" then
        G.Binds[id] = nil
    end
end

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

do
-- States where something else is driving the character; instant move stays out of them
local INSTANT_MOVE_SKIP = {
    [Enum.HumanoidStateType.Seated] = true,
    [Enum.HumanoidStateType.Climbing] = true,
    [Enum.HumanoidStateType.Swimming] = true,
    [Enum.HumanoidStateType.Flying] = true,
    [Enum.HumanoidStateType.PlatformStanding] = true,
    [Enum.HumanoidStateType.Ragdoll] = true,
    [Enum.HumanoidStateType.FallingDown] = true,
    [Enum.HumanoidStateType.Physics] = true,
    [Enum.HumanoidStateType.Dead] = true,
}
local instantDriving = false -- true while instant move pushed the character last frame

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

            -- Instant start and stop. Uses the humanoid's own move direction (keyboard,
            -- gamepad or touch) and stays out of the way whenever something else is
            -- driving the character: flying, sitting, climbing, swimming, ragdolls...
            local driving = false
            if G.InstantMoveEnabled and hrp and not G.FlyEnabled
                and not humanoid.Sit and not hrp.Anchored
                and not INSTANT_MOVE_SKIP[humanoid:GetState()] then
                local moveDir = humanoid.MoveDirection
                local velocity = hrp.AssemblyLinearVelocity

                if moveDir.Magnitude > 0.05 then
                    local flat = moveDir.Unit * G.WalkSpeedValue
                    hrp.AssemblyLinearVelocity = Vector3.new(flat.X, velocity.Y, flat.Z)
                    driving = true
                elseif instantDriving and humanoid.FloorMaterial ~= Enum.Material.Air then
                    -- Keys just released on the ground: stop once, then leave physics alone
                    -- (so knockback, conveyors and moving platforms still work)
                    hrp.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
                end
            end
            instantDriving = driving
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

end

-- ==========================================================
-- Invisibility
-- Hides every part, decal and accessory on your character and
-- the overhead name/health bar. Everything is restored when off.
-- Note: this is a client-side change, so other players only see
-- it if your game replicates it (e.g. via a server script).
-- ==========================================================

local restoreVisibility
do
local invisSaved = setmetatable({}, { __mode = "k" })
local invisHumanoidSaved = setmetatable({}, { __mode = "k" })

function restoreVisibility()
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

end

local SetStatus

-- ==========================================================
-- Unlimited zoom
-- Allows the camera to zoom out as far as you want. The default max is 400.
-- ==========================================================

local restoreZoom
do
local zoomSaved

function restoreZoom()
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
        if LocalPlayer.CameraMaxZoomDistance ~= 100000 then
            LocalPlayer.CameraMaxZoomDistance = 100000
        end
        if LocalPlayer.CameraMinZoomDistance ~= 0.5 then
            LocalPlayer.CameraMinZoomDistance = 0.5
        end
        if LocalPlayer.CameraMode ~= Enum.CameraMode.Classic then
            LocalPlayer.CameraMode = Enum.CameraMode.Classic
        end
    else
        restoreZoom()
    end
end))

end

-- ==========================================================
-- Fly
--   W/A/S/D  move relative to where the camera looks
--   Space/E  up        Ctrl/Q  down        Shift  boost
--   F        toggle fly on/off (rebindable in settings)
-- Movement eases in and out, and you hover when no key is held.
-- Boost multiplier and smoothing are in the advanced settings.
-- ==========================================================

local function faceCamera(hrp, cam)
    local look = cam.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)

    if flat.Magnitude > 0.001 then
        hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + flat)
    end
end

local stopFly, toggleFly
do
local flyConnection
local flyVelocity
local flyRoot
local flyHumanoid
local flyCurrent = Vector3.new(0, 0, 0)

function stopFly()
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

function toggleFly(state)
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

end

-- ==========================================================
-- Shift lock (own implementation, works in any game)
-- Hold Left Alt to free the cursor so you can use the menu.
-- ==========================================================

local releaseShiftLock
do
local lockHumanoid
local lockOffset
local lockAutoRotate
local lockMouseActive = false

function releaseShiftLock()
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

end

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

do
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

end

-- ==========================================================
-- ESP (everything it creates is tracked and cleaned up)
-- ==========================================================

local ESPFolder, ESPData, playerConns, ClearPlayerESP, RefreshESP, UntrackESPPlayer, applyESPStyle
local espWatchdogActive, espWatchdogThread
do
ESPFolder = Instance.new("Folder")
ESPFolder.Name = "NativeESP"
ESPFolder.Parent = workspace

ESPData = {}
playerConns = {}
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

local function rgbToColor3(rgb)
    return Color3.fromRGB(rgb[1] or 255, rgb[2] or 255, rgb[3] or 255)
end

local function ESPColor(player)
    if SameTeam(player) then
        return rgbToColor3(G.ESPTeamColor)
    end
    return rgbToColor3(G.ESPEnemyColor)
end

function ClearPlayerESP(player)
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

local function nameText(player, humanoid, distance)
    local text = player.DisplayName .. " (@" .. player.Name .. ")"
    local second = {}
    if humanoid then
        second[#second + 1] = "HP: " .. math.floor(humanoid.Health)
    end
    if distance and G.ESPShowDistance then
        second[#second + 1] = math.floor(distance) .. " studs"
    end
    if #second > 0 then
        text = text .. "\n" .. table.concat(second, "  |  ")
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
    label.Text = nameText(player, humanoid, data.distance)
    label.Parent = gui

    data.label = label
    data.humanoid = humanoid

    if humanoid then
        table.insert(data.conns, humanoid.HealthChanged:Connect(function()
            if label.Parent then
                label.Text = nameText(player, humanoid, data.distance)
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
        highlight.FillTransparency = G.ESPFillTransparency
        highlight.OutlineTransparency = G.ESPOutlineTransparency
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

function RefreshESP()
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

function UntrackESPPlayer(player)
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
espWatchdogActive = true

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

-- Recolours / restyles existing ESP without rebuilding it (used by the settings sliders)
function applyESPStyle()
    for player, data in pairs(ESPData) do
        local color = ESPColor(player)

        for _, child in ipairs(data.container:GetChildren()) do
            if child:IsA("Highlight") then
                child.FillColor = color
                child.OutlineColor = color
                child.FillTransparency = G.ESPFillTransparency
                child.OutlineTransparency = G.ESPOutlineTransparency
            elseif child:IsA("Beam") then
                child.Color = ColorSequence.new(color)
            elseif child.Name == "ESP_Nametag" then
                local label = child:FindFirstChildOfClass("TextLabel")
                if label then
                    label.TextColor3 = color
                end
            end
        end
    end
end

-- Distance loop: updates the distance on nametags and hides ESP beyond the max distance
task.spawn(function()
    while runActive do
        task.wait(0.25)
        if not runActive then
            break
        end

        local myCharacter = LocalPlayer.Character
        local myRoot = myCharacter and myCharacter:FindFirstChild("HumanoidRootPart")
        local maxDistance = G.ESPMaxDistance

        for player, data in pairs(ESPData) do
            local character = data.character
            local theirRoot = character
                and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
            local distance = (myRoot and theirRoot) and (myRoot.Position - theirRoot.Position).Magnitude or nil
            data.distance = distance

            local show = not (maxDistance > 0 and distance ~= nil and distance > maxDistance)
            if data.shown ~= show then
                data.shown = show
                for _, child in ipairs(data.container:GetChildren()) do
                    if child:IsA("Highlight") or child:IsA("Beam") or child:IsA("BillboardGui") then
                        child.Enabled = show
                    end
                end
            end

            if data.label and data.label.Parent then
                data.label.Text = nameText(player, data.humanoid, distance)
            end
        end
    end
end)

end

-- ==========================================================
-- Camera FOV, gravity and anti-AFK
-- ==========================================================

local restoreMisc
do
local fovSaved, gravitySaved

function restoreMisc()
    local camera = workspace.CurrentCamera
    if fovSaved and camera then
        camera.FieldOfView = fovSaved
    end
    fovSaved = nil

    if gravitySaved then
        workspace.Gravity = gravitySaved
        gravitySaved = nil
    end
end

track(RunService.RenderStepped:Connect(function()
    local camera = workspace.CurrentCamera

    if G.CameraFOVEnabled and camera then
        if not fovSaved then
            fovSaved = camera.FieldOfView
        end
        camera.FieldOfView = G.CameraFOVValue
    elseif fovSaved then
        if camera then
            camera.FieldOfView = fovSaved
        end
        fovSaved = nil
    end

    if G.GravityEnabled then
        if not gravitySaved then
            gravitySaved = workspace.Gravity
        end
        workspace.Gravity = G.GravityValue
    elseif gravitySaved then
        workspace.Gravity = gravitySaved
        gravitySaved = nil
    end
end))

track(LocalPlayer.Idled:Connect(function()
    if not G.AntiAFKEnabled then
        return
    end

    pcall(function()
        local virtualUser = game:GetService("VirtualUser")
        virtualUser:CaptureController()
        virtualUser:ClickButton2(Vector2.new())
    end)
end))

end

-- ==========================================================
-- Server hop
-- Joins a random public server of this game (never the current one).
-- With "Prefer friends' servers" on, it joins a friend's server first.
-- ==========================================================

local serverHop
do
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

function serverHop()
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
        local fetchFailed = false

        for page = 1, pagesToCheck do
            local body, err = fetchServerPage(cursor)
            if not body then
                SetStatus("Server hop: " .. err, "warn")
                fetchFailed = true
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

        if not target then
            if not fetchFailed then
                SetStatus("Server hop: no other joinable servers found.", "warn")
            end
            serverHopBusy = false
            return
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
end

-- ==========================================================
-- GUI (0.3.4)
--   Tabs: MOVE / COMBAT / VISUALS / PLAYERS / MUSIC
--   Click the logo (N) to open the settings page.
-- ==========================================================

local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local StatsService = game:GetService("Stats")

-- Module tables (filled in further down)
local Sfx, Tip, Sliders, Search, Wheel, Perf, PL, Music = {}, {}, {}, {}, {}, {}, {}, {}
local Spotify, Pointer = {}, {}

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
    {
        name = "Ocean",
        Background = Color3.fromRGB(14, 28, 40),
        Header = Color3.fromRGB(20, 42, 58),
        Surface = Color3.fromRGB(28, 56, 76),
        Accent = Color3.fromRGB(30, 134, 180),
        Border = Color3.fromRGB(48, 88, 112),
    },
    {
        name = "Sunset",
        Background = Color3.fromRGB(34, 24, 20),
        Header = Color3.fromRGB(52, 36, 28),
        Surface = Color3.fromRGB(68, 46, 36),
        Accent = Color3.fromRGB(200, 98, 44),
        Border = Color3.fromRGB(110, 76, 58),
    },
    {
        name = "Rose",
        Background = Color3.fromRGB(34, 20, 28),
        Header = Color3.fromRGB(52, 28, 42),
        Surface = Color3.fromRGB(68, 38, 56),
        Accent = Color3.fromRGB(196, 78, 132),
        Border = Color3.fromRGB(112, 66, 90),
    },
    {
        name = "Mint",
        Background = Color3.fromRGB(18, 32, 32),
        Header = Color3.fromRGB(26, 48, 48),
        Surface = Color3.fromRGB(34, 62, 62),
        Accent = Color3.fromRGB(44, 158, 138),
        Border = Color3.fromRGB(58, 98, 96),
    },
    {
        name = "Slate",
        Background = Color3.fromRGB(28, 32, 38),
        Header = Color3.fromRGB(40, 46, 54),
        Surface = Color3.fromRGB(52, 60, 70),
        Accent = Color3.fromRGB(100, 120, 148),
        Border = Color3.fromRGB(76, 86, 100),
    },
    {
        name = "Amber",
        Background = Color3.fromRGB(32, 28, 16),
        Header = Color3.fromRGB(50, 44, 22),
        Surface = Color3.fromRGB(66, 58, 30),
        Accent = Color3.fromRGB(184, 134, 24),
        Border = Color3.fromRGB(108, 96, 52),
    },
    {
        name = "Ink",
        Background = Color3.fromRGB(10, 10, 12),
        Header = Color3.fromRGB(20, 20, 24),
        Surface = Color3.fromRGB(30, 30, 36),
        Accent = Color3.fromRGB(70, 76, 92),
        Border = Color3.fromRGB(50, 50, 58),
    },
    {
        name = "Plum",
        Background = Color3.fromRGB(30, 18, 34),
        Header = Color3.fromRGB(46, 26, 52),
        Surface = Color3.fromRGB(62, 36, 70),
        Accent = Color3.fromRGB(160, 66, 182),
        Border = Color3.fromRGB(100, 62, 110),
    },
    {
        name = "Cobalt",
        Background = Color3.fromRGB(16, 20, 40),
        Header = Color3.fromRGB(24, 32, 64),
        Surface = Color3.fromRGB(32, 44, 88),
        Accent = Color3.fromRGB(56, 86, 224),
        Border = Color3.fromRGB(56, 70, 122),
    },
}

-- Custom theme: built from one colour picked on the colour wheel
local function customTheme()
    local custom = G.CustomTheme
    local h = math.clamp(custom.h or 0.62, 0, 1)
    local s = math.clamp(custom.s or 0.6, 0, 1)
    local v = math.clamp(custom.v or 0.85, 0, 1)

    return {
        name = "Custom",
        Background = Color3.fromHSV(h, s * 0.55, 0.09 + v * 0.07),
        Header = Color3.fromHSV(h, s * 0.55, 0.15 + v * 0.09),
        Surface = Color3.fromHSV(h, s * 0.5, 0.21 + v * 0.11),
        Accent = Color3.fromHSV(h, s, math.clamp(v, 0.35, 0.92)),
        Border = Color3.fromHSV(h, s * 0.4, 0.29 + v * 0.13),
    }
end

local function findTheme(name)
    if name == "Custom" then
        return customTheme()
    end

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
    Warn = Color3.fromRGB(255, 200, 90),
}

local function loadThemeColors(name)
    local theme = findTheme(name)
    G.ThemeName = theme.name
    UI_COLORS.Background = theme.Background
    UI_COLORS.Header = theme.Header
    UI_COLORS.Surface = theme.Surface
    UI_COLORS.Accent = theme.Accent
    UI_COLORS.Border = theme.Border

    -- Text drawn on top of the accent colour flips to dark when the accent is bright
    local accent = theme.Accent
    local luminance = 0.299 * accent.R + 0.587 * accent.G + 0.114 * accent.B
    UI_COLORS.OnAccent = luminance > 0.62 and Color3.fromRGB(20, 22, 28) or UI_COLORS.Text
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
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = instance
    return corner
end

local function addStroke(instance, colorKey, transparency, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = thickness or 1
    stroke.Transparency = transparency or 0
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = instance
    themeBind(stroke, "Color", colorKey or "Border")
    return stroke
end

local function tween(instance, seconds, goal)
    local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(instance, info, goal):Play()
end

local function toHex(color)
    return string.format("#%02x%02x%02x",
        math.floor(color.R * 255 + 0.5),
        math.floor(color.G * 255 + 0.5),
        math.floor(color.B * 255 + 0.5))
end

-- ----------------------------------------------------------
-- Pointer
-- GetMouseLocation() and GUI positions can differ by a few pixels vertically
-- (top bar / inset differences between executors and Roblox versions).
-- Pointer.get() returns the cursor in GUI space. The offset is measured
-- automatically each time the cursor enters or leaves one of the menu's
-- buttons (the real hit-test), and can also be set by hand in Settings.
-- ----------------------------------------------------------

Pointer.last = Vector2.new(0, 0)

function Pointer.get()
    local raw = UserInputService:GetMouseLocation()
    return Vector2.new(raw.X, raw.Y + (G.PointerOffset or 0))
end

function Pointer.sample(button, kind)
    if not G.PointerAutoCalibrate then
        return
    end

    local raw = UserInputService:GetMouseLocation()
    local dy = raw.Y - Pointer.last.Y
    if math.abs(dy) < 1 then
        return
    end

    local position, size = button.AbsolutePosition, button.AbsoluteSize
    -- Only use vertical crossings (not the left / right edges)
    if raw.X < position.X + 6 or raw.X > position.X + size.X - 6 then
        return
    end

    -- Entering while moving down (or leaving while moving up) crosses the top edge
    local crossedTop = (kind == "enter" and dy > 0) or (kind == "leave" and dy < 0)
    local edge = crossedTop and position.Y or (position.Y + size.Y)
    local measured = edge + dy / 2 - raw.Y

    if math.abs(measured) > 120 then
        return
    end

    local current = G.PointerOffset or 0
    G.PointerOffset = math.floor((current + (measured - current) * 0.3) * 10 + 0.5) / 10
end

function Pointer.watch(button)
    track(button.MouseEnter:Connect(function()
        Pointer.sample(button, "enter")
    end))
    track(button.MouseLeave:Connect(function()
        Pointer.sample(button, "leave")
    end))
end

track(RunService.RenderStepped:Connect(function()
    Pointer.last = UserInputService:GetMouseLocation()
end))

-- ----------------------------------------------------------
-- Root GUI
-- ----------------------------------------------------------

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SolaraNativeMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
local defaultFrameSize = UDim2.fromOffset(380, 520)
MainFrame.Size = defaultFrameSize
MainFrame.Position = UDim2.new(0.1, 0, 0.2, 0)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui
themeBind(MainFrame, "BackgroundColor3", "Background")
addCorner(MainFrame, 12)

local MainScale = Instance.new("UIScale")
MainScale.Scale = math.clamp(G.UIScale, 0.7, 1.5)
MainScale.Parent = MainFrame

addStroke(MainFrame, "Border", 0.2, 1)

local HeaderPanel = Instance.new("Frame")
HeaderPanel.Name = "HeaderPanel"
HeaderPanel.Size = UDim2.new(1, 0, 0, 44)
HeaderPanel.BorderSizePixel = 0
HeaderPanel.Parent = MainFrame
themeBind(HeaderPanel, "BackgroundColor3", "Header")
addCorner(HeaderPanel, 12)

do
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 205, 205))
    gradient.Rotation = 90
    gradient.Parent = HeaderPanel
end

-- Drag handle: sits under the title text and the logo, not under the three window buttons
local DragArea = Instance.new("TextButton")
DragArea.Name = "DragArea"
DragArea.Position = UDim2.new(0, 48, 0, 0)
DragArea.Size = UDim2.new(1, -150, 1, 0)
DragArea.BackgroundTransparency = 1
DragArea.AutoButtonColor = false
DragArea.Text = ""
DragArea.Parent = HeaderPanel

do
local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Position = UDim2.new(0, 52, 0, 7)
Title.Size = UDim2.new(1, -160, 0, 16)
Title.BackgroundTransparency = 1
Title.Text = "NATIVE"
Title.TextColor3 = UI_COLORS.Text
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = HeaderPanel

local VersionLabel = Instance.new("TextLabel")
VersionLabel.Name = "Version"
VersionLabel.Position = UDim2.new(0, 52, 0, 23)
VersionLabel.Size = UDim2.new(1, -160, 0, 13)
VersionLabel.BackgroundTransparency = 1
VersionLabel.Text = "v0.3.4"
VersionLabel.TextColor3 = UI_COLORS.MutedText
VersionLabel.Font = Enum.Font.Gotham
VersionLabel.TextSize = 10
VersionLabel.TextXAlignment = Enum.TextXAlignment.Left
VersionLabel.Parent = HeaderPanel

end

-- The logo is a button: click it to open or close the settings page
local LogoButton = Instance.new("TextButton")
LogoButton.Name = "Logo"
LogoButton.Position = UDim2.new(0, 12, 0, 7)
LogoButton.Size = UDim2.fromOffset(30, 30)
LogoButton.BorderSizePixel = 0
LogoButton.Text = "N"
LogoButton.Font = Enum.Font.GothamBlack
LogoButton.TextSize = 17
LogoButton.AutoButtonColor = false
LogoButton.Parent = HeaderPanel
themeBind(LogoButton, "BackgroundColor3", "Accent")
themeBind(LogoButton, "TextColor3", "OnAccent")
addCorner(LogoButton, 9)

do
local LogoPadding = Instance.new("UIPadding")
LogoPadding.PaddingRight = UDim.new(0, 2)
LogoPadding.Parent = LogoButton

end

local LogoStroke = Instance.new("UIStroke")
LogoStroke.Color = UI_COLORS.Text
LogoStroke.Thickness = 2
LogoStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
LogoStroke.Enabled = false
LogoStroke.Parent = LogoButton

local function makeTitleButton(text, xOffset, colorKey)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 26, 0, 26)
    button.Position = UDim2.new(1, xOffset, 0, 9)
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = UI_COLORS.Text
    button.Font = Enum.Font.GothamBold
    button.TextSize = 13
    button.AutoButtonColor = true
    button.Parent = HeaderPanel
    themeBind(button, "BackgroundColor3", colorKey)
    addCorner(button, 8)
    return button
end

-- Left to right: minimize, reset window, close
local CloseButton = makeTitleButton("X", -36, "Surface")
CloseButton.BackgroundColor3 = Color3.fromRGB(165, 62, 78)
themed[#themed] = nil -- the close button keeps its red in every theme
local ResetButton = makeTitleButton("R", -66, "Surface")
local MinimizeButton = makeTitleButton("-", -96, "Surface")
Pointer.watch(CloseButton)
Pointer.watch(ResetButton)
Pointer.watch(MinimizeButton)
Pointer.watch(DragArea)
Pointer.watch(LogoButton)

-- Body holds the tab bar, the search bar, the pages and the footer (hidden when minimized)
local Body = Instance.new("Frame")
Body.Name = "Body"
Body.Position = UDim2.new(0, 0, 0, 44)
Body.Size = UDim2.new(1, 0, 1, -44)
Body.BackgroundTransparency = 1
Body.BorderSizePixel = 0
Body.Parent = MainFrame

local ResizeHandle = Instance.new("TextButton")
ResizeHandle.Name = "ResizeHandle"
ResizeHandle.Size = UDim2.new(0, 20, 0, 20)
ResizeHandle.Position = UDim2.new(1, -22, 1, -22)
ResizeHandle.BackgroundTransparency = 1
ResizeHandle.BorderSizePixel = 0
ResizeHandle.Text = "//"
ResizeHandle.TextColor3 = UI_COLORS.MutedText
ResizeHandle.Font = Enum.Font.GothamBold
ResizeHandle.TextSize = 12
ResizeHandle.ZIndex = 10
ResizeHandle.Parent = MainFrame

-- ----------------------------------------------------------
-- Window drag / resize / sliders / colour wheel: one shared input handler
-- ----------------------------------------------------------

local expandedSize = MainFrame.Size
local minimized = false
local drag = nil   -- { input, startPointer, startFramePos, startGuiPos, target }
local resize = nil -- { input, startPointer, startSize }

local function isPress(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

local function pointerOf(input)
    return Vector2.new(input.Position.X, input.Position.Y)
end

-- target is the GuiObject being moved (the main window or the stats overlay)
local function beginDrag(input, target, onMove)
    drag = {
        input = input,
        startPointer = pointerOf(input),
        startAbs = target.AbsolutePosition,
        target = target,
        onMove = onMove,
    }
end

track(DragArea.InputBegan:Connect(function(input)
    if isPress(input) then
        beginDrag(input, MainFrame, function(x, y)
            MainFrame.Position = UDim2.fromOffset(x, y)
        end)
    end
end))

track(ResizeHandle.InputBegan:Connect(function(input)
    if isPress(input) then
        resize = {
            input = input,
            startPointer = pointerOf(input),
            startSize = MainFrame.AbsoluteSize,
        }
    end
end))

track(UserInputService.InputChanged:Connect(function(input)
    local moving = input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch

    if not moving then
        return
    end

    if Sliders.active then
        Sliders.active()
    end

    if drag then
        local isMouseDrag = drag.input.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement
        local isTouchDrag = drag.input.UserInputType == Enum.UserInputType.Touch
            and input == drag.input

        if isMouseDrag or isTouchDrag then
            local delta = pointerOf(input) - drag.startPointer
            local desired = drag.startAbs + delta
            local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
            local size = drag.target.AbsoluteSize

            if viewport then
                desired = Vector2.new(
                    math.clamp(desired.X, 0, math.max(0, viewport.X - size.X)),
                    math.clamp(desired.Y, 0, math.max(0, viewport.Y - size.Y))
                )
            end

            drag.onMove(desired.X, desired.Y)
        end
    end

    if resize then
        local isMouseMove = resize.input.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement
        local isTouchMove = resize.input.UserInputType == Enum.UserInputType.Touch
            and input == resize.input

        if isMouseMove or isTouchMove then
            local delta = pointerOf(input) - resize.startPointer
            local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
            local maxWidth = viewport and viewport.X - MainFrame.AbsolutePosition.X or 2000
            local maxHeight = viewport and viewport.Y - MainFrame.AbsolutePosition.Y or 2000
            local scale = MainScale.Scale

            local width = math.clamp(resize.startSize.X + delta.X, 300 * scale, math.max(300 * scale, maxWidth))
            local height = math.clamp(resize.startSize.Y + delta.Y, 320 * scale, math.max(320 * scale, maxHeight))

            expandedSize = UDim2.fromOffset(width / scale, height / scale)
            MainFrame.Size = expandedSize
        end
    end
end))

track(UserInputService.InputEnded:Connect(function(input)
    if drag and (input == drag.input
        or (drag.input.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseButton1)) then
        drag = nil
    end

    if resize and (input == resize.input
        or (resize.input.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseButton1)) then
        resize = nil
    end

    if Sliders.active and isPress(input) then
        Sliders.active = nil
        local release = Sliders.release
        Sliders.release = nil
        if release then
            release()
        end
    end
end))

track(MinimizeButton.MouseButton1Click:Connect(function()
    minimized = not minimized
    Body.Visible = not minimized
    ResizeHandle.Visible = not minimized
    MainFrame.Size = minimized
        and UDim2.fromOffset(expandedSize.X.Offset, 44)
        or expandedSize
    MinimizeButton.Text = minimized and "+" or "-"
end))

-- Resets size, position and the minimized state (also in the settings page)
local function resetWindow()
    expandedSize = defaultFrameSize
    minimized = false
    Body.Visible = true
    ResizeHandle.Visible = true
    MainFrame.Size = defaultFrameSize
    MainFrame.Position = UDim2.new(0.1, 0, 0.2, 0)
    MinimizeButton.Text = "-"
end

track(ResetButton.MouseButton1Click:Connect(resetWindow))

-- Close removes the menu and undoes everything (fly, noclip, speed, ESP...)
track(CloseButton.MouseButton1Click:Connect(function()
    if G.NativeMenuCleanup then
        G.NativeMenuCleanup()
        G.NativeMenuCleanup = nil
    end
end))

local function applyOpacity()
    local transparency = 1 - math.clamp(G.MenuOpacity, 0.3, 1)
    MainFrame.BackgroundTransparency = transparency
    HeaderPanel.BackgroundTransparency = transparency
end

-- ----------------------------------------------------------
-- Sound effects
-- The ids below are Roblox's built-in client sounds. Swap any of them for
-- your own "rbxassetid://..." if you prefer something else.
-- ----------------------------------------------------------

do
local SFX = {
    click = { id = "rbxasset://sounds/button.wav", speed = 1.0, volume = 0.55 },
    on = { id = "rbxasset://sounds/switch.wav", speed = 1.2, volume = 0.6 },
    off = { id = "rbxasset://sounds/switch.wav", speed = 0.85, volume = 0.6 },
    tick = { id = "rbxasset://sounds/button.wav", speed = 1.7, volume = 0.25 },
    notify = { id = "rbxasset://sounds/electronicpingshort.wav", speed = 1.0, volume = 0.6 },
    warn = { id = "rbxasset://sounds/snap.mp3", speed = 0.9, volume = 0.6 },
    open = { id = "rbxasset://sounds/electronicpingshort.wav", speed = 1.35, volume = 0.45 },
    close = { id = "rbxasset://sounds/electronicpingshort.wav", speed = 0.8, volume = 0.45 },
}

Sfx.sounds = {}
Sfx.lastTick = 0

for name, spec in pairs(SFX) do
    local sound = Instance.new("Sound")
    sound.Name = "Sfx_" .. name
    sound.SoundId = spec.id
    sound.Parent = ScreenGui
    Sfx.sounds[name] = sound
end

function Sfx.play(name)
    if not G.SfxEnabled then
        return
    end

    local sound = Sfx.sounds[name]
    local spec = SFX[name]
    if not sound then
        return
    end

    -- Slider ticks are throttled so dragging doesn't machine-gun the sound
    if name == "tick" then
        local now = os.clock()
        if now - Sfx.lastTick < 0.06 then
            return
        end
        Sfx.lastTick = now
    end

    pcall(function()
        sound.Volume = spec.volume * G.SfxVolume
        sound.PlaybackSpeed = spec.speed
        sound.TimePosition = 0
        sound:Play()
    end)
end

end

-- ----------------------------------------------------------
-- Toast notifications (top right of the screen, stack up to 4)
-- ----------------------------------------------------------

do
local ToastHolder = Instance.new("Frame")
ToastHolder.Name = "Toasts"
ToastHolder.AnchorPoint = Vector2.new(1, 0)
ToastHolder.Position = UDim2.new(1, -14, 0, 46)
ToastHolder.Size = UDim2.new(0, 290, 0, 300)
ToastHolder.BackgroundTransparency = 1
ToastHolder.Active = false
ToastHolder.ZIndex = 60
ToastHolder.Parent = ScreenGui

do
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.Parent = ToastHolder
end

local toastCounter = 0
local activeToasts = {}

local function dismissToast(toast)
    if not toast.frame.Parent then
        return
    end

    for index, other in ipairs(activeToasts) do
        if other == toast then
            table.remove(activeToasts, index)
            break
        end
    end

    tween(toast.frame, 0.2, { BackgroundTransparency = 1 })
    tween(toast.label, 0.2, { TextTransparency = 1 })
    tween(toast.bar, 0.2, { BackgroundTransparency = 1 })
    task.delay(0.25, function()
        if toast.frame.Parent then
            toast.frame:Destroy()
        end
    end)
end

SetStatus = function(text, kind)
    if G.ToastsEnabled == false then
        return
    end

    toastCounter = toastCounter + 1
    local warn = kind == "warn"
    Sfx.play(warn and "warn" or "notify")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 0)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.LayoutOrder = toastCounter
    frame.ZIndex = 61
    frame.Parent = ToastHolder
    addCorner(frame, 9)
    themeBind(frame, "BackgroundColor3", "Header")
    frame.BackgroundTransparency = 1

    local stroke = addStroke(frame, "Border", 0.3, 1)

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 4, 1, -12)
    bar.Position = UDim2.new(0, 6, 0, 6)
    bar.BorderSizePixel = 0
    bar.BackgroundColor3 = warn and UI_COLORS.Warn or UI_COLORS.Accent
    bar.BackgroundTransparency = 1
    bar.ZIndex = 62
    bar.Parent = frame
    addCorner(bar, 2)

    local label = Instance.new("TextLabel")
    label.Position = UDim2.new(0, 18, 0, 0)
    label.Size = UDim2.new(1, -26, 0, 0)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = UI_COLORS.Text
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTransparency = 1
    label.ZIndex = 62
    label.Parent = frame

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 9)
    padding.PaddingBottom = UDim.new(0, 9)
    padding.Parent = label

    local toast = { frame = frame, label = label, bar = bar }
    activeToasts[#activeToasts + 1] = toast

    tween(frame, 0.2, { BackgroundTransparency = 0.05 })
    tween(label, 0.2, { TextTransparency = 0 })
    tween(bar, 0.2, { BackgroundTransparency = 0 })

    while #activeToasts > 4 do
        dismissToast(activeToasts[1])
    end

    task.delay(math.clamp(G.ToastDuration, 1, 15), function()
        if frame.Parent then
            dismissToast(toast)
        end
    end)
end

end

-- ----------------------------------------------------------
-- Dynamic hover tooltips
-- Hover a setting for longer than the delay (1 second by default) and a
-- tooltip follows the cursor. Text can be a string or a function, so it can
-- show live values. Hit-testing is done by rectangle, so it also works for
-- rows that contain buttons.
-- ----------------------------------------------------------

Tip.targets = {}
Tip.current = nil
Tip.hoverStart = 0
Tip.visible = false
Tip.suppressed = false
Tip.accum = 0

Tip.frame = Instance.new("Frame")
Tip.frame.Name = "Tooltip"
Tip.frame.Visible = false
Tip.frame.BorderSizePixel = 0
Tip.frame.ZIndex = 100
Tip.frame.Active = false
Tip.frame.Parent = ScreenGui
themeBind(Tip.frame, "BackgroundColor3", "Header")
addCorner(Tip.frame, 8)
addStroke(Tip.frame, "Accent", 0.2, 1)

Tip.label = Instance.new("TextLabel")
Tip.label.BackgroundTransparency = 1
Tip.label.Position = UDim2.new(0, 8, 0, 6)
Tip.label.Size = UDim2.new(1, -16, 1, -12)
Tip.label.Font = Enum.Font.Gotham
Tip.label.TextSize = 11
Tip.label.TextWrapped = true
Tip.label.TextXAlignment = Enum.TextXAlignment.Left
Tip.label.TextYAlignment = Enum.TextYAlignment.Top
Tip.label.ZIndex = 101
Tip.label.Parent = Tip.frame
themeBind(Tip.label, "TextColor3", "Text")

function Tip.add(object, text)
    Tip.targets[#Tip.targets + 1] = { object = object, text = text }
end

-- True when the object and every ancestor is visible and the pointer is inside any scrolling area it sits in
function Tip.reachable(object, pointer)
    local parent = object
    while parent and parent ~= ScreenGui do
        if parent:IsA("GuiObject") then
            if not parent.Visible then
                return false
            end
            if parent:IsA("ScrollingFrame") then
                local p, s = parent.AbsolutePosition, parent.AbsoluteSize
                if pointer.X < p.X or pointer.X > p.X + s.X or pointer.Y < p.Y or pointer.Y > p.Y + s.Y then
                    return false
                end
            end
        end
        parent = parent.Parent
    end
    return parent == ScreenGui
end

function Tip.hide()
    if Tip.visible then
        Tip.visible = false
        Tip.frame.Visible = false
    end
end

function Tip.resolveText(target)
    local text = target.text
    if type(text) == "function" then
        local ok, value = pcall(text)
        text = ok and value or nil
    end
    return text
end

function Tip.show(target, pointer)
    local text = Tip.resolveText(target)
    if not text or text == "" then
        Tip.hide()
        return
    end

    if Tip.label.Text ~= text then
        Tip.label.Text = text
        local measured = TextService:GetTextSize(text, 11, Enum.Font.Gotham, Vector2.new(230, 10000))
        Tip.frame.Size = UDim2.fromOffset(math.ceil(measured.X) + 18, math.ceil(measured.Y) + 14)
    end

    local size = Tip.frame.AbsoluteSize
    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
    local x = pointer.X + 16
    local y = pointer.Y + 20

    if x + size.X > viewport.X - 4 then
        x = pointer.X - size.X - 12
    end
    if y + size.Y > viewport.Y - 4 then
        y = pointer.Y - size.Y - 12
    end

    Tip.frame.Position = UDim2.fromOffset(math.max(x, 4), math.max(y, 4))

    if not Tip.visible then
        Tip.visible = true
        Tip.frame.Visible = true
        Tip.frame.BackgroundTransparency = 1
        tween(Tip.frame, 0.15, { BackgroundTransparency = 0.03 })
    end
end

track(RunService.RenderStepped:Connect(function(dt)
    if not G.TooltipsEnabled or not MainFrame.Visible or Sliders.active or drag or resize then
        Tip.hide()
        Tip.current = nil
        return
    end

    local pointer = Pointer.get()

    -- Hit test ten times a second
    Tip.accum = Tip.accum + dt
    if Tip.accum >= 0.1 then
        Tip.accum = 0

        local best, bestArea
        for index = #Tip.targets, 1, -1 do
            local target = Tip.targets[index]
            local object = target.object

            if not object.Parent then
                table.remove(Tip.targets, index)
            else
                local p, s = object.AbsolutePosition, object.AbsoluteSize
                if pointer.X >= p.X and pointer.X <= p.X + s.X
                    and pointer.Y >= p.Y and pointer.Y <= p.Y + s.Y
                    and Tip.reachable(object, pointer) then
                    local area = s.X * s.Y
                    if not best or area < bestArea then
                        best, bestArea = target, area
                    end
                end
            end
        end

        if best ~= Tip.current then
            Tip.current = best
            Tip.hoverStart = os.clock()
            Tip.suppressed = false
            Tip.hide()
        end
    end

    local current = Tip.current
    if current and not Tip.suppressed and os.clock() - Tip.hoverStart >= G.TooltipDelay then
        Tip.show(current, pointer)
    end
end))

-- A click hides the tooltip until the pointer moves to a different setting
track(UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        Tip.suppressed = true
        Tip.hide()
    end
end))

-- ----------------------------------------------------------
-- Tabs and pages
-- ----------------------------------------------------------

local pages = {}
local tabButtons = {}
local activePage = "Move"
local lastMainPage = "Move"

local function refreshTabs()
    for name, button in pairs(tabButtons) do
        local active = activePage == name
        button.BackgroundColor3 = active and UI_COLORS.Accent or UI_COLORS.Surface
        button.TextColor3 = active and UI_COLORS.OnAccent or UI_COLORS.MutedText
    end

    LogoStroke.Enabled = activePage == "Settings"
end

themeHooks[#themeHooks + 1] = refreshTabs

local TabBar = Instance.new("Frame")
TabBar.Name = "TabBar"
TabBar.Position = UDim2.new(0, 10, 0, 8)
TabBar.Size = UDim2.new(1, -20, 0, 30)
TabBar.BackgroundTransparency = 1
TabBar.BorderSizePixel = 0
TabBar.Parent = Body

-- Search bar: filters settings on most tabs, players on PLAYERS, tracks on MUSIC
local SearchFrame = Instance.new("Frame")
SearchFrame.Name = "SearchBar"
SearchFrame.Position = UDim2.new(0, 10, 0, 44)
SearchFrame.Size = UDim2.new(1, -20, 0, 30)
SearchFrame.BorderSizePixel = 0
SearchFrame.Parent = Body
themeBind(SearchFrame, "BackgroundColor3", "Surface")
addCorner(SearchFrame, 9)
addStroke(SearchFrame, "Border", 0.5, 1)

local SearchBox = Instance.new("TextBox")
SearchBox.Name = "SearchBox"
SearchBox.Position = UDim2.new(0, 12, 0, 0)
SearchBox.Size = UDim2.new(1, -44, 1, 0)
SearchBox.BackgroundTransparency = 1
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 12
SearchBox.Text = ""
SearchBox.PlaceholderText = "Search settings..."
SearchBox.ClearTextOnFocus = false
SearchBox.TextXAlignment = Enum.TextXAlignment.Left
SearchBox.Parent = SearchFrame
themeBind(SearchBox, "TextColor3", "Text")
themeBind(SearchBox, "PlaceholderColor3", "MutedText")

local SearchClear = Instance.new("TextButton")
SearchClear.Position = UDim2.new(1, -28, 0, 5)
SearchClear.Size = UDim2.fromOffset(20, 20)
SearchClear.BackgroundTransparency = 1
SearchClear.Text = "x"
SearchClear.Font = Enum.Font.GothamBold
SearchClear.TextSize = 13
SearchClear.Visible = false
SearchClear.Parent = SearchFrame
themeBind(SearchClear, "TextColor3", "MutedText")

track(SearchClear.MouseButton1Click:Connect(function()
    SearchBox.Text = ""
end))

local function newPage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name .. "Page"
    page.Position = UDim2.new(0, 10, 0, 82)
    page.Size = UDim2.new(1, -20, 1, -108)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.ScrollingDirection = Enum.ScrollingDirection.Y
    page.ScrollBarThickness = 3
    page.ScrollBarImageTransparency = 0.3
    page.Visible = false
    page.Parent = Body
    themeBind(page, "ScrollBarImageColor3", "Accent")

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page

    local padding = Instance.new("UIPadding")
    padding.PaddingRight = UDim.new(0, 8)
    padding.PaddingTop = UDim.new(0, 2)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.Parent = page

    pages[name] = page
    return page
end

local pageMove = newPage("Move")
local pageCombat = newPage("Combat")
local pageVisuals = newPage("Visuals")
local pagePlayers = newPage("Players")
local pageMusic = newPage("Music")
local pageSpotify = newPage("Spotify")
local pageSettings = newPage("Settings")
local pageSearch = newPage("Search")

local SEARCH_PLACEHOLDERS = {
    Players = "Search players...",
    Music = "Search playlist...",
    Spotify = "Search Spotify, then press Enter...",
}

local function showPage(name)
    activePage = name
    if name ~= "Settings" and name ~= "Search" then
        lastMainPage = name
    end

    for pageName, page in pairs(pages) do
        page.Visible = pageName == name
    end

    SearchBox.PlaceholderText = SEARCH_PLACEHOLDERS[name] or "Search settings..."
    refreshTabs()
end

-- Tab and logo clicks go through here so a leftover search never hides the page you asked for
local function gotoPage(name)
    if SearchBox.Text ~= "" then
        SearchBox.Text = ""
    end
    showPage(name)
end

do
local tabNames = { "Move", "Combat", "Visuals", "Players", "Music", "Spotify" }

for index, name in ipairs(tabNames) do
    local button = Instance.new("TextButton")
    button.Name = name .. "Tab"
    button.Size = UDim2.new(1 / #tabNames, -4, 1, 0)
    button.Position = UDim2.new((index - 1) / #tabNames, 2, 0, 0)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamBold
    button.TextSize = 9
    button.Text = string.upper(name)
    button.AutoButtonColor = false
    button.Parent = TabBar
    addCorner(button, 8)

    tabButtons[name] = button
    Pointer.watch(button)
    track(button.MouseButton1Click:Connect(function()
        Sfx.play("click")
        gotoPage(name)
    end))
end

end

-- Footer: shows the current hide/show key
do
local FooterLabel = Instance.new("TextLabel")
FooterLabel.Name = "Footer"
FooterLabel.Position = UDim2.new(0, 12, 1, -22)
FooterLabel.Size = UDim2.new(1, -48, 0, 16)
FooterLabel.BackgroundTransparency = 1
FooterLabel.Font = Enum.Font.Gotham
FooterLabel.TextSize = 10
FooterLabel.TextXAlignment = Enum.TextXAlignment.Left
FooterLabel.Parent = Body
themeBind(FooterLabel, "TextColor3", "MutedText")

local function refreshFooter()
    local menuKey = G.Binds.Menu
    FooterLabel.Text = (menuKey and ("[" .. menuKey .. "] hide / show menu") or "menu key not set")
        .. "  |  logo = settings"
end

refreshFooter()
refreshers[#refreshers + 1] = refreshFooter
end

-- ==========================================================
-- Widgets (each one is added to whatever currentParent is)
-- ==========================================================

local currentParent
local currentPageName = "Move"
local currentSection
local inAdvanced = false
local orderCounters = setmetatable({}, { __mode = "k" })
local allSections = {}

local function beginPage(parent, pageName)
    currentParent = parent
    currentPageName = pageName
    currentSection = nil
end

local function nextOrder()
    orderCounters[currentParent] = (orderCounters[currentParent] or 0) + 1
    return orderCounters[currentParent]
end

-- ----------------------------------------------------------
-- Search: every searchable row is registered; a query moves the matching
-- rows onto the Search page and puts them back when the query is cleared.
-- ----------------------------------------------------------

Search.items = {}
Search.moved = {}
Search.page = pageSearch

Search.status = Instance.new("TextLabel")
Search.status.Size = UDim2.new(1, 0, 0, 22)
Search.status.BackgroundTransparency = 1
Search.status.Font = Enum.Font.GothamBold
Search.status.TextSize = 11
Search.status.TextXAlignment = Enum.TextXAlignment.Left
Search.status.LayoutOrder = 1
Search.status.Parent = pageSearch
themeBind(Search.status, "TextColor3", "MutedText")

local function applySectionVisibility(section)
    for _, row in ipairs(section.rows) do
        if not Search.moved[row] then
            row.Visible = not section.collapsed
        end
    end
end

function Search.restore()
    for row, item in pairs(Search.moved) do
        Search.moved[row] = nil
        if row.Parent then
            row.Parent = item.orig
            row.LayoutOrder = item.order
            row.Visible = not (item.section and item.section.collapsed)
        end
    end
end

function Search.run(query)
    Search.restore()

    local byLabel, byKeyword = {}, {}
    for _, item in ipairs(Search.items) do
        local hidden = item.advanced and not G.AdvancedUnlocked
        if item.row.Parent and not hidden then
            if string.find(item.label, query, 1, true) then
                byLabel[#byLabel + 1] = item
            elseif string.find(item.keywords, query, 1, true) then
                byKeyword[#byKeyword + 1] = item
            end
        end
    end

    local count = 0
    for _, list in ipairs({ byLabel, byKeyword }) do
        for _, item in ipairs(list) do
            count = count + 1
            Search.moved[item.row] = item
            item.row.Parent = pageSearch
            item.row.LayoutOrder = count + 1
            item.row.Visible = true
        end
    end

    Search.status.Text = count > 0
        and (count .. (count == 1 and " result" or " results"))
        or "No settings match \"" .. query .. "\""

    showPage("Search")
end

track(SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local query = string.lower(string.match(SearchBox.Text, "^%s*(.-)%s*$"))
    SearchClear.Visible = SearchBox.Text ~= ""

    if activePage == "Players" then
        PL.filter(query)
    elseif activePage == "Music" then
        Music.filter(query)
    elseif activePage == "Spotify" then
        -- Spotify searches when you press Enter (see the Spotify tab)
    elseif query == "" then
        Search.restore()
        if activePage == "Search" then
            showPage(lastMainPage)
        end
    else
        Search.run(query)
    end
end))

-- Registers a row with the current section (collapsing) and with the search index
local function adopt(row, label, options)
    options = options or {}

    if currentSection and not options.nosection then
        currentSection.rows[#currentSection.rows + 1] = row
        if currentSection.collapsed then
            row.Visible = false
        end
    end

    if label and not options.nosearch then
        Search.items[#Search.items + 1] = {
            row = row,
            label = string.lower(label),
            keywords = string.lower(options.keywords or ""),
            orig = row.Parent,
            order = row.LayoutOrder,
            section = (currentSection and not options.nosection) and currentSection or nil,
            advanced = inAdvanced,
        }
    end
end

local function newCard(height, label, options)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, height)
    row.BorderSizePixel = 0
    row.LayoutOrder = nextOrder()
    row.Parent = currentParent
    themeBind(row, "BackgroundColor3", "Surface")
    addCorner(row, 9)
    adopt(row, label, options)
    return row
end

local function newPlainRow(height, options)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, height)
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.LayoutOrder = nextOrder()
    row.Parent = currentParent
    adopt(row, nil, options)
    return row
end

local function newLabel(parent, text, size, colorKey, font)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Text = text
    label.Font = font or Enum.Font.Gotham
    label.TextSize = size or 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.Parent = parent
    themeBind(label, "TextColor3", colorKey or "Text")
    return label
end

local function newButton(parent, size, position, colorKey)
    local button = Instance.new("TextButton")
    button.Size = size
    button.Position = position or UDim2.new(0, 0, 0, 0)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamBold
    button.TextSize = 12
    button.AutoButtonColor = false
    button.Parent = parent
    themeBind(button, "BackgroundColor3", colorKey or "Header")
    themeBind(button, "TextColor3", "Text")
    addCorner(button, 7)

    -- hover feedback
    local base = colorKey or "Header"
    track(button.MouseEnter:Connect(function()
        tween(button, 0.12, { BackgroundColor3 = UI_COLORS.Border })
    end))
    track(button.MouseLeave:Connect(function()
        tween(button, 0.12, { BackgroundColor3 = UI_COLORS[base] })
    end))
    return button
end

local function newBox(parent, size, position)
    local box = Instance.new("TextBox")
    box.Size = size
    box.Position = position or UDim2.new(0, 0, 0, 0)
    box.BorderSizePixel = 0
    box.Font = Enum.Font.GothamBold
    box.TextSize = 12
    box.Text = ""
    box.ClearTextOnFocus = false
    box.Parent = parent
    themeBind(box, "BackgroundColor3", "Header")
    themeBind(box, "TextColor3", "Text")
    themeBind(box, "PlaceholderColor3", "MutedText")
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

-- Collapsible category header
local function CreateSection(text)
    local key = currentPageName .. "/" .. text
    local section = { key = key, rows = {}, collapsed = G.Collapsed[key] == true }
    allSections[#allSections + 1] = section

    local header = Instance.new("TextButton")
    header.Size = UDim2.new(1, 0, 0, 26)
    header.BackgroundTransparency = 1
    header.Text = ""
    header.AutoButtonColor = false
    header.LayoutOrder = nextOrder()
    header.Parent = currentParent

    local chevron = Instance.new("TextLabel")
    chevron.Position = UDim2.new(0, 2, 0, 0)
    chevron.Size = UDim2.new(0, 16, 1, 0)
    chevron.BackgroundTransparency = 1
    chevron.Text = ">"
    chevron.Font = Enum.Font.GothamBold
    chevron.TextSize = 11
    chevron.Rotation = section.collapsed and 0 or 90
    chevron.Parent = header
    themeBind(chevron, "TextColor3", "Accent")

    local label = newLabel(header, string.upper(text), 11, "MutedText", Enum.Font.GothamBold)
    label.Position = UDim2.new(0, 20, 0, 0)
    label.Size = UDim2.new(1, -20, 1, 0)

    section.chevron = chevron

    track(header.MouseButton1Click:Connect(function()
        section.collapsed = not section.collapsed
        G.Collapsed[key] = section.collapsed
        tween(chevron, 0.15, { Rotation = section.collapsed and 0 or 90 })
        applySectionVisibility(section)
        Sfx.play("click")
    end))

    currentSection = section
    return section
end

local function CreateHint(text, height)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, height or 30)
    label.BackgroundTransparency = 1
    label.Text = text
    label.Font = Enum.Font.Gotham
    label.TextSize = 10
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.LayoutOrder = nextOrder()
    label.Parent = currentParent
    themeBind(label, "TextColor3", "MutedText")
    adopt(label, nil, {})
    return label
end

-- ==========================================================
-- Keybinds
-- Every toggle and bindable button registers an "action" here. Keys are
-- stored in G.Binds (action id -> key name). The settings page lists one
-- row per action, warns about conflicts, and the hotkey handler at the
-- bottom of the script fires the bound actions.
-- ==========================================================

local Keys = {
    actions = {},
    order = {},
    capture = nil, -- set while a keybind button is waiting for a key press
    warnColor = Color3.fromRGB(255, 200, 90),
    -- Keys the menu already uses itself (flying, shift lock)
    reserved = {
        W = "movement / fly forward",
        A = "movement / fly left",
        S = "movement / fly back",
        D = "movement / fly right",
        Space = "jumping / fly up",
        E = "fly up",
        Q = "fly down",
        LeftControl = "fly down",
        LeftShift = "fly boost",
        LeftAlt = "freeing the cursor (Shift Lock)",
    },
}

function Keys.register(id, label, run)
    if not Keys.actions[id] then
        Keys.order[#Keys.order + 1] = id
    end
    Keys.actions[id] = { label = label, run = run }
end

-- Labels of the OTHER actions bound to the same key as this one
function Keys.conflicts(id)
    local keyName = G.Binds[id]
    local found = {}

    if keyName then
        for _, otherId in ipairs(Keys.order) do
            if otherId ~= id and G.Binds[otherId] == keyName then
                found[#found + 1] = Keys.actions[otherId].label
            end
        end
    end

    return found
end

-- One line per shared key, e.g. "[X]: Speed, Noclip"
function Keys.conflictSummary()
    local byKey, keyOrder = {}, {}

    for _, id in ipairs(Keys.order) do
        local keyName = G.Binds[id]
        if keyName then
            if not byKey[keyName] then
                byKey[keyName] = {}
                keyOrder[#keyOrder + 1] = keyName
            end
            table.insert(byKey[keyName], Keys.actions[id].label)
        end
    end

    local lines = {}
    for _, keyName in ipairs(keyOrder) do
        if #byKey[keyName] > 1 then
            lines[#lines + 1] = "[" .. keyName .. "]: " .. table.concat(byKey[keyName], ", ")
        end
    end

    return lines
end

-- Runs every action bound to this key (pcall so one bad action can't block the rest)
function Keys.fire(keyName)
    for _, id in ipairs(Keys.order) do
        if G.Binds[id] == keyName then
            local action = Keys.actions[id]
            local ok, err = pcall(action.run)
            if not ok then
                SetStatus(action.label .. " failed: " .. tostring(err), "warn")
            end
        end
    end
end

-- Settings row: "Speed | [X]". Click the key button, then press a key.
function Keys.createRow(id)
    local action = Keys.actions[id]
    local row = newCard(32, nil, { nosearch = true, nosection = true })

    local label = newLabel(row, action.label, 12, "Text")
    label.Position = UDim2.new(0, 12, 0, 0)
    label.Size = UDim2.new(0.55, -12, 1, 0)

    local button = newButton(row, UDim2.new(0.45, -42, 0, 24), UDim2.new(0.55, 0, 0, 4))

    -- Small "x" that removes the key from this action
    local clear = newButton(row, UDim2.fromOffset(26, 24), UDim2.new(1, -36, 0, 4))
    clear.Text = "x"

    local function unbind()
        Keys.capture = nil
        if G.Binds[id] then
            G.Binds[id] = nil
            SetStatus(action.label .. " keybind cleared.")
        end
        runRefreshers()
    end

    track(clear.MouseButton1Click:Connect(function()
        Sfx.play("click")
        unbind()
    end))
    -- Right-clicking the key button clears it too
    track(button.MouseButton2Click:Connect(function()
        Sfx.play("click")
        unbind()
    end))
    Tip.add(clear, "Remove this keybind.")

    local function refresh()
        local keyName = G.Binds[id]
        button.Text = keyName or "None"

        if #Keys.conflicts(id) > 0 then
            button.TextColor3 = Keys.warnColor
        elseif keyName then
            button.TextColor3 = UI_COLORS.Text
        else
            button.TextColor3 = UI_COLORS.MutedText
        end
    end

    refresh()
    refreshers[#refreshers + 1] = refresh

    track(button.MouseButton1Click:Connect(function()
        Sfx.play("click")
        runRefreshers() -- puts any other row that was waiting back to normal
        button.Text = "press a key..."

        Keys.capture = function(keyCode)
            if keyCode == Enum.KeyCode.Escape then
                -- cancelled, nothing changes
            elseif keyCode == Enum.KeyCode.Backspace or keyCode == Enum.KeyCode.Delete then
                G.Binds[id] = nil
                SetStatus(action.label .. " keybind cleared.")
            elseif keyCode ~= Enum.KeyCode.Unknown then
                local keyName = keyCode.Name
                G.Binds[id] = keyName

                local others = Keys.conflicts(id)
                if #others > 0 then
                    SetStatus("Conflict: [" .. keyName .. "] also bound to "
                        .. table.concat(others, ", "), "warn")
                elseif Keys.reserved[keyName] then
                    SetStatus("Heads up: [" .. keyName .. "] is also used for "
                        .. Keys.reserved[keyName], "warn")
                else
                    SetStatus(action.label .. " bound to [" .. keyName .. "].")
                end
            end

            runRefreshers()
        end
    end))
end

-- Line at the top of the keybind list: lists every shared key, or says all clear
function Keys.createSummary()
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 0)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 11
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.LayoutOrder = nextOrder()
    label.Parent = currentParent

    local function refresh()
        local lines = Keys.conflictSummary()

        if #lines > 0 then
            label.Text = "Conflicting keybinds (all of them fire):\n" .. table.concat(lines, "\n")
            label.TextColor3 = Keys.warnColor
        else
            label.Text = "No keybind conflicts."
            label.TextColor3 = UI_COLORS.MutedText
        end
    end

    refresh()
    refreshers[#refreshers + 1] = refresh
end

Keys.register("Menu", "Hide / show menu", function()
    MainFrame.Visible = not MainFrame.Visible
    Sfx.play(MainFrame.Visible and "open" or "close")
    if not MainFrame.Visible then
        Tip.hide()
    end
end)

-- ==========================================================
-- Widget constructors
-- ==========================================================

local function makeSwitch(parent)
    local track = Instance.new("Frame")
    track.AnchorPoint = Vector2.new(1, 0.5)
    track.Position = UDim2.new(1, -10, 0.5, 0)
    track.Size = UDim2.fromOffset(38, 20)
    track.BorderSizePixel = 0
    track.Parent = parent
    addCorner(track, 10)

    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.Position = UDim2.new(0, 3, 0.5, 0)
    knob.Size = UDim2.fromOffset(14, 14)
    knob.BorderSizePixel = 0
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.Parent = track
    addCorner(knob, 7)

    return track, knob
end

local function paintSwitch(trackFrame, knob, on, animate)
    local color = on and UI_COLORS.Accent or UI_COLORS.Header
    local position = on and UDim2.new(0, 21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)

    if animate then
        tween(trackFrame, 0.15, { BackgroundColor3 = color })
        tween(knob, 0.15, { Position = position })
    else
        trackFrame.BackgroundColor3 = color
        knob.Position = position
    end
end

local function keyChipText(key)
    local keyName = G.Binds[key]
    return keyName and ("[" .. keyName .. "]") or ""
end

local function CreateToggle(text, key, callback, tip, noBind)
    local row = newCard(36, text, { keywords = tip })

    local label = newLabel(row, text, 12, "Text")
    label.Position = UDim2.new(0, 12, 0, 0)
    label.Size = UDim2.new(1, -120, 1, 0)

    local chip = newLabel(row, "", 10, "MutedText")
    chip.AnchorPoint = Vector2.new(1, 0.5)
    chip.Position = UDim2.new(1, -56, 0.5, 0)
    chip.Size = UDim2.fromOffset(60, 16)
    chip.TextXAlignment = Enum.TextXAlignment.Right

    local trackFrame, knob = makeSwitch(row)

    local hit = Instance.new("TextButton")
    hit.Size = UDim2.new(1, 0, 1, 0)
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.ZIndex = 3
    hit.Parent = row

    local function render()
        paintSwitch(trackFrame, knob, G[key], false)
    end

    local function refreshChip()
        chip.Text = keyChipText(key)
    end

    render()
    refreshChip()
    togglers[key] = render
    refreshers[#refreshers + 1] = refreshChip

    local function flip()
        G[key] = not G[key]
        paintSwitch(trackFrame, knob, G[key], true)
        Sfx.play(G[key] and "on" or "off")

        if callback then
            callback(G[key])
        end
    end

    if not noBind then
        Keys.register(key, text, flip)
    end
    track(hit.MouseButton1Click:Connect(flip))

    Tip.add(row, function()
        local lines = { tip or ("Turns " .. text .. " on or off.") }
        lines[#lines + 1] = "Now: " .. (G[key] and "ON" or "OFF")
        if not noBind then
            local keyName = G.Binds[key]
            lines[#lines + 1] = keyName and ("Key: " .. keyName) or "No key bound (settings > keybinds)"
        end
        return table.concat(lines, "\n")
    end)
end

-- A slider with a number box. opts: min, max (slider range), hardMin, hardMax (typed limits),
-- step, percent, decimals, toggleKey (adds an ON/OFF switch), autoEnable, callback, tip, suffix
local function CreateSlider(text, valueKey, opts)
    local minV, maxV = opts.min, opts.max
    local step = opts.step or 1
    local hardMin = opts.hardMin or minV
    local hardMax = opts.hardMax or maxV
    local toggleKey = opts.toggleKey

    local row = newCard(56, text, { keywords = opts.tip })

    local label = newLabel(row, text, 12, "Text")
    label.Position = UDim2.new(0, 12, 0, 6)
    label.Size = UDim2.new(1, toggleKey and -170 or -90, 0, 22)

    local boxRight = toggleKey and -56 or -10
    local box = newBox(row, UDim2.fromOffset(62, 22), UDim2.new(1, boxRight - 62, 0, 6))
    box.TextSize = 11

    if toggleKey then
        local trackFrame, knob = makeSwitch(row)
        trackFrame.AnchorPoint = Vector2.new(1, 0)
        trackFrame.Position = UDim2.new(1, -10, 0, 7)

        local hit = Instance.new("TextButton")
        hit.AnchorPoint = Vector2.new(1, 0)
        hit.Position = UDim2.new(1, -4, 0, 2)
        hit.Size = UDim2.fromOffset(50, 30)
        hit.BackgroundTransparency = 1
        hit.Text = ""
        hit.ZIndex = 3
        hit.Parent = row

        togglers[toggleKey] = function()
            paintSwitch(trackFrame, knob, G[toggleKey], false)
        end
        togglers[toggleKey]()

        local function flip()
            G[toggleKey] = not G[toggleKey]
            paintSwitch(trackFrame, knob, G[toggleKey], true)
            Sfx.play(G[toggleKey] and "on" or "off")
            if opts.toggleCallback then
                opts.toggleCallback(G[toggleKey])
            end
        end

        Keys.register(toggleKey, text, flip)
        track(hit.MouseButton1Click:Connect(flip))
    end

    -- Slider bar
    local hitBar = Instance.new("TextButton")
    hitBar.Position = UDim2.new(0, 12, 0, 32)
    hitBar.Size = UDim2.new(1, -24, 0, 20)
    hitBar.BackgroundTransparency = 1
    hitBar.Text = ""
    hitBar.ZIndex = 2
    hitBar.Parent = row

    local bar = Instance.new("Frame")
    bar.AnchorPoint = Vector2.new(0, 0.5)
    bar.Position = UDim2.new(0, 0, 0.5, 0)
    bar.Size = UDim2.new(1, 0, 0, 6)
    bar.BorderSizePixel = 0
    bar.Parent = hitBar
    themeBind(bar, "BackgroundColor3", "Header")
    addCorner(bar, 3)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    themeBind(fill, "BackgroundColor3", "Accent")
    addCorner(fill, 3)

    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0, 0, 0.5, 0)
    knob.Size = UDim2.fromOffset(14, 14)
    knob.BorderSizePixel = 0
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.Parent = bar
    addCorner(knob, 7)
    addStroke(knob, "Accent", 0, 2)

    local function format(value)
        if opts.percent then
            return math.floor(value * 100 + 0.5) .. "%"
        end
        if step >= 1 then
            return tostring(math.floor(value + 0.5))
        end
        local decimals = opts.decimals or (step < 0.1 and 2 or 1)
        return string.format("%." .. decimals .. "f", value)
    end

    local function refresh()
        local value = G[valueKey]
        local alpha = math.clamp((value - minV) / (maxV - minV), 0, 1)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        box.Text = format(value) .. (opts.suffix or "")
    end

    local function commit(value, fromUser)
        G[valueKey] = value
        if fromUser and opts.autoEnable and toggleKey and not G[toggleKey] then
            enable(toggleKey)
            if opts.toggleCallback then
                opts.toggleCallback(true)
            end
        end
        refresh()
        if opts.callback then
            opts.callback(value)
        end
    end

    refresh()
    refreshers[#refreshers + 1] = refresh

    local function updateFromPointer()
        local pointer = Pointer.get()
        local position, size = bar.AbsolutePosition, bar.AbsoluteSize
        if size.X <= 0 then
            return
        end

        local alpha = math.clamp((pointer.X - position.X) / size.X, 0, 1)
        local raw = minV + alpha * (maxV - minV)
        local snapped = minV + math.floor((raw - minV) / step + 0.5) * step
        snapped = math.floor(snapped * 1000000 + 0.5) / 1000000
        snapped = math.clamp(snapped, minV, maxV)

        if snapped ~= G[valueKey] then
            Sfx.play("tick")
            commit(snapped, true)
        end
    end

    track(hitBar.InputBegan:Connect(function(input)
        if isPress(input) then
            Sliders.active = updateFromPointer
            updateFromPointer()
        end
    end))

    track(box.FocusLost:Connect(function()
        local num = tonumber((string.gsub(box.Text, "[%%%s]", "")))
        if num and num == num then
            if opts.percent and num > 1 then
                num = num / 100
            end
            commit(clampWithNotice(num, hardMin, hardMax, text), true)
        elseif box.Text ~= "" then
            SetStatus(text .. ": enter a number", "warn")
        end
        refresh()
    end))

    Tip.add(row, function()
        local lines = { opts.tip or text }
        lines[#lines + 1] = "Now: " .. format(G[valueKey]) .. (opts.suffix or "")
        lines[#lines + 1] = "Drag the bar, or type a value"
            .. ((hardMax ~= maxV or hardMin ~= minV) and (" (up to " .. format(hardMax) .. ")") or "")
        return table.concat(lines, "\n")
    end)
end

-- A button that cycles through a fixed list of options
local function CreateChoice(text, key, options, tip, callback)
    local row = newCard(36, text, { keywords = tip })

    local label = newLabel(row, text, 12, "Text")
    label.Position = UDim2.new(0, 12, 0, 0)
    label.Size = UDim2.new(0.5, -12, 1, 0)

    local chip = newButton(row, UDim2.new(0.5, -10, 0, 24), UDim2.new(0.5, 0, 0, 6))

    local function refresh()
        chip.Text = tostring(G[key])
    end

    refresh()
    refreshers[#refreshers + 1] = refresh

    track(chip.MouseButton1Click:Connect(function()
        local nextIndex = 1
        for index, option in ipairs(options) do
            if option == G[key] then
                nextIndex = index % #options + 1
            end
        end
        G[key] = options[nextIndex]
        Sfx.play("click")
        refresh()
        if callback then
            callback(G[key])
        end
    end))

    Tip.add(row, function()
        return (tip or text) .. "\nNow: " .. tostring(G[key]) .. "\nClick to cycle through the options."
    end)
end

-- Pass an actionId to make the button bindable to a key in the settings
local function CreateButton(text, callback, actionId, tip)
    local row = newCard(34, text, { keywords = tip })

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 1, 0)
    button.BackgroundTransparency = 1
    button.Font = Enum.Font.GothamBold
    button.TextSize = 12
    button.Text = text
    button.Parent = row
    themeBind(button, "TextColor3", "Text")

    track(button.MouseEnter:Connect(function()
        tween(row, 0.12, { BackgroundColor3 = UI_COLORS.Border })
    end))
    track(button.MouseLeave:Connect(function()
        tween(row, 0.12, { BackgroundColor3 = UI_COLORS.Surface })
    end))

    local function run()
        Sfx.play("click")
        callback()
    end

    if actionId then
        Keys.register(actionId, text, callback)
    end

    track(button.MouseButton1Click:Connect(run))

    Tip.add(row, function()
        local lines = { tip or text }
        if actionId then
            local keyName = G.Binds[actionId]
            lines[#lines + 1] = keyName and ("Key: " .. keyName) or "No key bound (settings > keybinds)"
        end
        return table.concat(lines, "\n")
    end)
end

-- Colour setting: a swatch that opens the colour wheel. The value is stored as {r, g, b} (0-255).
local function CreateColorRow(text, key, tip, onChange)
    local row = newCard(36, text, { keywords = tip })

    local label = newLabel(row, text, 12, "Text")
    label.Position = UDim2.new(0, 12, 0, 0)
    label.Size = UDim2.new(1, -90, 1, 0)

    local swatch = Instance.new("TextButton")
    swatch.AnchorPoint = Vector2.new(1, 0.5)
    swatch.Position = UDim2.new(1, -10, 0.5, 0)
    swatch.Size = UDim2.fromOffset(52, 22)
    swatch.BorderSizePixel = 0
    swatch.Text = ""
    swatch.AutoButtonColor = false
    swatch.Parent = row
    addCorner(swatch, 7)
    addStroke(swatch, "Border", 0, 1)

    local function refresh()
        local rgb = G[key]
        swatch.BackgroundColor3 = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
    end

    refresh()
    refreshers[#refreshers + 1] = refresh

    track(swatch.MouseButton1Click:Connect(function()
        Sfx.play("click")
        local rgb = G[key]
        Wheel.open(text, Color3.fromRGB(rgb[1], rgb[2], rgb[3]), function(color)
            G[key] = {
                math.floor(color.R * 255 + 0.5),
                math.floor(color.G * 255 + 0.5),
                math.floor(color.B * 255 + 0.5),
            }
            refresh()
            if onChange then
                onChange(color)
            end
        end, key)
    end))

    Tip.add(row, (tip or text) .. "\nClick to open the colour wheel.")
end

-- ==========================================================
-- Colour wheel (used by the custom theme "+" and the ESP colours)
-- The wheel is built from coloured spokes, so it needs no image assets.
-- ==========================================================

do
    local RADIUS = 78
    local SPOKES = 120
    local PANEL_W, PANEL_H = 240, 292

    Wheel.h, Wheel.s, Wheel.v = 0, 0, 1
    Wheel.id = nil
    Wheel.callback = nil
    Wheel.isOpen = false

    local panel = Instance.new("Frame")
    panel.Name = "ColorPanel"
    panel.Size = UDim2.fromOffset(PANEL_W, PANEL_H)
    panel.Visible = false
    panel.BorderSizePixel = 0
    panel.ZIndex = 20
    panel.Parent = ScreenGui
    themeBind(panel, "BackgroundColor3", "Background")
    addCorner(panel, 12)
    addStroke(panel, "Accent", 0.25, 1)
    Wheel.panel = panel

    local titleLabel = newLabel(panel, "Colour", 12, "Text", Enum.Font.GothamBold)
    titleLabel.Position = UDim2.new(0, 14, 0, 10)
    titleLabel.Size = UDim2.new(1, -56, 0, 22)

    local closeButton = Instance.new("TextButton")
    closeButton.Position = UDim2.new(1, -32, 0, 10)
    closeButton.Size = UDim2.fromOffset(22, 22)
    closeButton.BorderSizePixel = 0
    closeButton.Text = "x"
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 12
    closeButton.Parent = panel
    themeBind(closeButton, "BackgroundColor3", "Surface")
    themeBind(closeButton, "TextColor3", "Text")
    addCorner(closeButton, 7)

    local holder = Instance.new("Frame")
    holder.Position = UDim2.new(0.5, -RADIUS, 0, 42)
    holder.Size = UDim2.fromOffset(RADIUS * 2, RADIUS * 2)
    holder.BackgroundTransparency = 1
    holder.Parent = panel

    for index = 0, SPOKES - 1 do
        local angle = index / SPOKES * 360
        local radians = math.rad(angle)

        local spoke = Instance.new("Frame")
        spoke.AnchorPoint = Vector2.new(0.5, 0.5)
        spoke.Size = UDim2.fromOffset(RADIUS, 7)
        spoke.Position = UDim2.fromOffset(
            RADIUS + math.cos(radians) * RADIUS / 2,
            RADIUS + math.sin(radians) * RADIUS / 2
        )
        spoke.Rotation = angle
        spoke.BorderSizePixel = 0
        spoke.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        spoke.Parent = holder

        local gradient = Instance.new("UIGradient")
        gradient.Color = ColorSequence.new(
            Color3.fromRGB(255, 255, 255),
            Color3.fromHSV(index / SPOKES, 1, 1)
        )
        gradient.Parent = spoke
    end

    -- Darkens the wheel as the brightness goes down
    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 2
    overlay.Parent = holder
    addCorner(overlay, RADIUS)

    local marker = Instance.new("Frame")
    marker.AnchorPoint = Vector2.new(0.5, 0.5)
    marker.Size = UDim2.fromOffset(14, 14)
    marker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    marker.BorderSizePixel = 0
    marker.ZIndex = 3
    marker.Parent = holder
    addCorner(marker, 7)
    do
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(0, 0, 0)
        stroke.Thickness = 2
        stroke.Parent = marker
    end

    local wheelHit = Instance.new("TextButton")
    wheelHit.Size = UDim2.new(1, 0, 1, 0)
    wheelHit.BackgroundTransparency = 1
    wheelHit.Text = ""
    wheelHit.ZIndex = 4
    wheelHit.Parent = holder

    -- Brightness bar
    local brightTrack = Instance.new("Frame")
    brightTrack.Position = UDim2.new(0, 20, 0, 42 + RADIUS * 2 + 14)
    brightTrack.Size = UDim2.new(1, -40, 0, 14)
    brightTrack.BorderSizePixel = 0
    brightTrack.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    brightTrack.Parent = panel
    addCorner(brightTrack, 7)

    local brightGradient = Instance.new("UIGradient")
    brightGradient.Parent = brightTrack

    local brightKnob = Instance.new("Frame")
    brightKnob.AnchorPoint = Vector2.new(0.5, 0.5)
    brightKnob.Size = UDim2.fromOffset(12, 20)
    brightKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    brightKnob.BorderSizePixel = 0
    brightKnob.ZIndex = 3
    brightKnob.Parent = brightTrack
    addCorner(brightKnob, 5)
    do
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(0, 0, 0)
        stroke.Thickness = 2
        stroke.Parent = brightKnob
    end

    local brightHit = Instance.new("TextButton")
    brightHit.Position = UDim2.new(0, 14, 0, 42 + RADIUS * 2 + 8)
    brightHit.Size = UDim2.new(1, -28, 0, 26)
    brightHit.BackgroundTransparency = 1
    brightHit.Text = ""
    brightHit.ZIndex = 4
    brightHit.Parent = panel

    -- Preview + hex
    local previewY = 42 + RADIUS * 2 + 40

    local preview = Instance.new("Frame")
    preview.Position = UDim2.new(0, 20, 0, previewY)
    preview.Size = UDim2.fromOffset(40, 28)
    preview.BorderSizePixel = 0
    preview.Parent = panel
    addCorner(preview, 8)
    addStroke(preview, "Border", 0, 1)

    local hexBox = newBox(panel, UDim2.fromOffset(92, 28), UDim2.new(0, 68, 0, previewY))
    hexBox.PlaceholderText = "RRGGBB"
    hexBox.TextSize = 12

    local doneButton = newButton(panel, UDim2.fromOffset(56, 28), UDim2.new(1, -76, 0, previewY), "Accent")
    doneButton.Text = "DONE"
    themeBind(doneButton, "TextColor3", "OnAccent")

    function Wheel.render()
        local radians = Wheel.h * math.pi * 2
        local distance = Wheel.s * RADIUS
        marker.Position = UDim2.fromOffset(
            RADIUS + math.cos(radians) * distance,
            RADIUS + math.sin(radians) * distance
        )

        overlay.BackgroundTransparency = Wheel.v
        brightGradient.Color = ColorSequence.new(
            Color3.fromRGB(0, 0, 0),
            Color3.fromHSV(Wheel.h, Wheel.s, 1)
        )
        brightKnob.Position = UDim2.new(Wheel.v, 0, 0.5, 0)

        local color = Color3.fromHSV(Wheel.h, Wheel.s, Wheel.v)
        preview.BackgroundColor3 = color
        if not hexBox:IsFocused() then
            hexBox.Text = string.upper(string.sub(toHex(color), 2))
        end
    end

    function Wheel.emit()
        if Wheel.callback then
            Wheel.callback(Color3.fromHSV(Wheel.h, Wheel.s, Wheel.v), Wheel.h, Wheel.s, Wheel.v)
        end
    end

    function Wheel.place()
        local position, size = MainFrame.AbsolutePosition, MainFrame.AbsoluteSize
        local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)

        local x = position.X + size.X + 10
        if x + PANEL_W > viewport.X then
            x = position.X - PANEL_W - 10
        end
        x = math.clamp(x, 0, math.max(0, viewport.X - PANEL_W))
        local y = math.clamp(position.Y, 0, math.max(0, viewport.Y - PANEL_H))

        panel.Position = UDim2.fromOffset(x, y)
    end

    function Wheel.close()
        Wheel.isOpen = false
        Wheel.id = nil
        Wheel.callback = nil
        panel.Visible = false
    end

    function Wheel.open(title, color, callback, id, hsv)
        if Wheel.isOpen and Wheel.id == id then
            Wheel.close()
            return
        end

        Wheel.id = id
        Wheel.callback = nil -- no output while the starting colour is loaded
        titleLabel.Text = title

        if hsv then
            Wheel.h, Wheel.s, Wheel.v = hsv.h, hsv.s, hsv.v
        else
            Wheel.h, Wheel.s, Wheel.v = color:ToHSV()
        end

        Wheel.isOpen = true
        panel.Visible = true
        Wheel.place()
        Wheel.render()
        Wheel.callback = callback
    end

    local function updateWheel()
        local pointer = Pointer.get()
        local center = wheelHit.AbsolutePosition + wheelHit.AbsoluteSize / 2
        local offset = pointer - center
        local radius = wheelHit.AbsoluteSize.X / 2
        if radius <= 0 then
            return
        end

        Wheel.h = (math.deg(math.atan2(offset.Y, offset.X)) % 360) / 360
        Wheel.s = math.clamp(offset.Magnitude / radius, 0, 1)
        Wheel.render()
        Wheel.emit()
    end

    local function updateBrightness()
        local pointer = Pointer.get()
        local position, size = brightTrack.AbsolutePosition, brightTrack.AbsoluteSize
        if size.X <= 0 then
            return
        end

        Wheel.v = math.clamp((pointer.X - position.X) / size.X, 0, 1)
        Wheel.render()
        Wheel.emit()
    end

    track(wheelHit.InputBegan:Connect(function(input)
        if isPress(input) then
            Sliders.active = updateWheel
            updateWheel()
        end
    end))

    track(brightHit.InputBegan:Connect(function(input)
        if isPress(input) then
            Sliders.active = updateBrightness
            updateBrightness()
        end
    end))

    track(hexBox.FocusLost:Connect(function()
        local text = string.gsub(hexBox.Text, "[^%x]", "")
        if #text == 6 then
            local r = tonumber(string.sub(text, 1, 2), 16)
            local g = tonumber(string.sub(text, 3, 4), 16)
            local b = tonumber(string.sub(text, 5, 6), 16)
            Wheel.h, Wheel.s, Wheel.v = Color3.fromRGB(r, g, b):ToHSV()
            Wheel.render()
            Wheel.emit()
        else
            Wheel.render()
            if hexBox.Text ~= "" then
                SetStatus("Hex colour needs 6 digits, like 4F7CFF.", "warn")
            end
        end
    end))

    track(closeButton.MouseButton1Click:Connect(Wheel.close))
    track(doneButton.MouseButton1Click:Connect(function()
        Sfx.play("click")
        Wheel.close()
    end))

    track(RunService.RenderStepped:Connect(function()
        if Wheel.isOpen then
            panel.Visible = MainFrame.Visible
            Wheel.place()
        end
    end))
end

-- ==========================================================
-- Performance stats overlay (own customisation in the settings page)
-- ==========================================================

do
    Perf.keys = {
        FPS = "PerfFPS",
        Ping = "PerfPing",
        FrameTime = "PerfFrameTime",
        Memory = "PerfMemory",
        Players = "PerfPlayers",
        Clock = "PerfClock",
        Position = "PerfPosition",
        Speed = "PerfSpeed",
    }
    Perf.order = { "FPS", "Ping", "FrameTime", "Memory", "Players", "Clock", "Position", "Speed" }
    Perf.names = {
        FPS = "FPS", Ping = "PING", FrameTime = "FRAME", Memory = "MEM",
        Players = "PLRS", Clock = "TIME", Position = "POS", Speed = "SPD",
    }
    Perf.labels = {}
    Perf.frames = 0
    Perf.elapsed = 0
    Perf.history = {}
    Perf.GRAPH_BARS = 40

    local frame = Instance.new("Frame")
    frame.Name = "PerfHUD"
    frame.AutomaticSize = Enum.AutomaticSize.XY
    frame.Size = UDim2.fromOffset(0, 0)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Visible = false
    frame.ZIndex = 5
    frame.Parent = ScreenGui
    themeBind(frame, "BackgroundColor3", "Background")
    addCorner(frame, 9)
    addStroke(frame, "Border", 0.5, 1)
    Perf.frame = frame

    Perf.scale = Instance.new("UIScale")
    Perf.scale.Parent = frame

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 7)
    padding.PaddingBottom = UDim.new(0, 7)
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)
    padding.Parent = frame

    Perf.layout = Instance.new("UIListLayout")
    Perf.layout.Padding = UDim.new(0, 2)
    Perf.layout.SortOrder = Enum.SortOrder.LayoutOrder
    Perf.layout.VerticalAlignment = Enum.VerticalAlignment.Center
    Perf.layout.Parent = frame

    for index, key in ipairs(Perf.order) do
        local label = Instance.new("TextLabel")
        label.AutomaticSize = Enum.AutomaticSize.XY
        label.Size = UDim2.fromOffset(0, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.Code
        label.TextSize = 13
        label.RichText = true
        label.Text = ""
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.LayoutOrder = index
        label.ZIndex = 6
        label.Parent = frame
        Perf.labels[key] = label
    end

    -- Frame-rate graph
    Perf.graph = Instance.new("Frame")
    Perf.graph.Size = UDim2.fromOffset(Perf.GRAPH_BARS * 3, 26)
    Perf.graph.BackgroundTransparency = 1
    Perf.graph.LayoutOrder = 20
    Perf.graph.ZIndex = 6
    Perf.graph.Parent = frame

    Perf.bars = {}
    for index = 1, Perf.GRAPH_BARS do
        local bar = Instance.new("Frame")
        bar.AnchorPoint = Vector2.new(0, 1)
        bar.Position = UDim2.new((index - 1) / Perf.GRAPH_BARS, 0, 1, 0)
        bar.Size = UDim2.new(1 / Perf.GRAPH_BARS, -1, 0, 1)
        bar.BorderSizePixel = 0
        bar.ZIndex = 7
        bar.Parent = Perf.graph
        Perf.bars[index] = bar
        Perf.history[index] = 0
    end

    local CORNERS = {
        ["Top Left"] = { Vector2.new(0, 0), UDim2.new(0, 12, 0, 46) },
        ["Top Right"] = { Vector2.new(1, 0), UDim2.new(1, -12, 0, 46) },
        ["Bottom Left"] = { Vector2.new(0, 1), UDim2.new(0, 12, 1, -12) },
        ["Bottom Right"] = { Vector2.new(1, 1), UDim2.new(1, -12, 1, -12) },
    }
    Perf.cornerNames = { "Top Left", "Top Right", "Bottom Left", "Bottom Right" }

    function Perf.apply()
        frame.Visible = G.PerfEnabled == true
        frame.BackgroundTransparency = 1 - math.clamp(G.PerfOpacity, 0, 1)
        Perf.scale.Scale = math.clamp(G.PerfScale, 0.5, 2.5)

        if G.PerfLayout == "Horizontal" then
            Perf.layout.FillDirection = Enum.FillDirection.Horizontal
            Perf.layout.Padding = UDim.new(0, 14)
        else
            Perf.layout.FillDirection = Enum.FillDirection.Vertical
            Perf.layout.Padding = UDim.new(0, 2)
        end

        for key, label in pairs(Perf.labels) do
            label.Visible = G[Perf.keys[key]] == true
        end
        Perf.graph.Visible = G.PerfGraph == true

        if G.PerfPos then
            frame.AnchorPoint = Vector2.new(0, 0)
            frame.Position = UDim2.fromOffset(G.PerfPos.x, G.PerfPos.y)
        else
            local corner = CORNERS[G.PerfCorner] or CORNERS["Top Right"]
            frame.AnchorPoint = corner[1]
            frame.Position = corner[2]
        end
    end

    local function readPing()
        local ok, value = pcall(function()
            return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        return ok and value or nil
    end

    local function readMemory()
        local ok, value = pcall(function()
            return StatsService:GetTotalMemoryUsageMb()
        end)
        return ok and value or nil
    end

    -- Colour by threshold: lower is better when "lower" is true
    local function rate(value, good, warn, lower)
        local isGood, isWarn
        if lower then
            isGood, isWarn = value <= good, value <= warn
        else
            isGood, isWarn = value >= good, value >= warn
        end
        if isGood then
            return UI_COLORS.Enabled
        elseif isWarn then
            return UI_COLORS.Warn
        end
        return UI_COLORS.Disabled
    end

    local function setLabel(key, valueText, valueColor)
        local labelColor = G.PerfAccentLabels and UI_COLORS.Accent or UI_COLORS.MutedText
        local color = (G.PerfColorCode and valueColor) or UI_COLORS.Text
        Perf.labels[key].Text = string.format(
            '<font color="%s">%s</font> <font color="%s">%s</font>',
            toHex(labelColor), Perf.names[key], toHex(color), valueText
        )
    end

    function Perf.render(fps, frameTimeMs)
        if G.PerfFPS then
            setLabel("FPS", string.format("%d", math.floor(fps + 0.5)), rate(fps, 55, 30, false))
        end

        if G.PerfPing then
            local ping = readPing()
            if ping then
                setLabel("Ping", string.format("%d ms", math.floor(ping + 0.5)), rate(ping, 100, 200, true))
            else
                setLabel("Ping", "n/a", nil)
            end
        end

        if G.PerfFrameTime then
            setLabel("FrameTime", string.format("%.1f ms", frameTimeMs), rate(frameTimeMs, 18, 34, true))
        end

        if G.PerfMemory then
            local memory = readMemory()
            if memory then
                setLabel("Memory", string.format("%d MB", math.floor(memory + 0.5)), rate(memory, 2000, 4000, true))
            else
                setLabel("Memory", "n/a", nil)
            end
        end

        if G.PerfPlayers then
            setLabel("Players", #Players:GetPlayers() .. "/" .. Players.MaxPlayers, nil)
        end

        if G.PerfClock then
            setLabel("Clock", os.date("%H:%M:%S"), nil)
        end

        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")

        if G.PerfPosition then
            if root then
                local p = root.Position
                setLabel("Position", string.format("%d, %d, %d", math.floor(p.X), math.floor(p.Y), math.floor(p.Z)), nil)
            else
                setLabel("Position", "n/a", nil)
            end
        end

        if G.PerfSpeed then
            if root then
                setLabel("Speed", string.format("%.1f st/s", root.AssemblyLinearVelocity.Magnitude), nil)
            else
                setLabel("Speed", "n/a", nil)
            end
        end

        if G.PerfGraph then
            table.remove(Perf.history, 1)
            table.insert(Perf.history, fps)

            for index, bar in ipairs(Perf.bars) do
                local value = Perf.history[index] or 0
                local height = math.clamp(value / 120, 0.04, 1)
                bar.Size = UDim2.new(1 / Perf.GRAPH_BARS, -1, height, 0)
                bar.BackgroundColor3 = rate(value, 55, 30, false)
            end
        end
    end

    track(RunService.RenderStepped:Connect(function(dt)
        Perf.frames = Perf.frames + 1
        Perf.elapsed = Perf.elapsed + dt

        if Perf.elapsed >= math.max(G.PerfInterval, 0.1) then
            local fps = Perf.frames / Perf.elapsed
            local frameTime = Perf.elapsed / Perf.frames * 1000
            Perf.frames = 0
            Perf.elapsed = 0

            if G.PerfEnabled then
                Perf.render(fps, frameTime)
            end
        end
    end))

    -- Drag the overlay anywhere; the spot is remembered until you pick a corner
    track(frame.InputBegan:Connect(function(input)
        if isPress(input) then
            beginDrag(input, frame, function(x, y)
                G.PerfPos = { x = x, y = y }
                frame.AnchorPoint = Vector2.new(0, 0)
                frame.Position = UDim2.fromOffset(x, y)
            end)
        end
    end))

    Perf.apply()
end

-- ==========================================================
-- Players tab: searchable player cards with avatar, distance, health and
-- one-click teleport / view
-- ==========================================================

PL.cards = {}
PL.thumbs = {}
PL.query = ""
PL.sort = "Name"
PL.viewing = nil

local function localRoot()
    local character = LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function teleportToPlayer(target)
    if not target or target.Parent ~= Players then
        SetStatus("That player has left the game.", "warn")
        return
    end

    local myCharacter = LocalPlayer.Character
    local myRoot = myCharacter and myCharacter:FindFirstChild("HumanoidRootPart")
    if not myRoot then
        SetStatus("Your character isn't loaded yet.", "warn")
        return
    end

    local theirCharacter = target.Character
    local theirRoot = theirCharacter
        and (theirCharacter:FindFirstChild("HumanoidRootPart") or theirCharacter.PrimaryPart)
    if not theirRoot then
        SetStatus(target.DisplayName .. " has no character right now.", "warn")
        return
    end

    -- Land 3 studs behind them, facing the same way
    myCharacter:PivotTo(theirRoot.CFrame * CFrame.new(0, 0, 3))
    myRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    SetStatus("Teleported to " .. target.DisplayName .. ".")
end

function PL.stopView()
    PL.viewing = nil

    local camera = workspace.CurrentCamera
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if camera and humanoid then
        camera.CameraSubject = humanoid
    end

    for _, card in pairs(PL.cards) do
        card.viewButton.Text = "VIEW"
    end
end

function PL.view(target)
    if PL.viewing == target then
        PL.stopView()
        SetStatus("Stopped viewing.")
        return
    end

    local camera = workspace.CurrentCamera
    local character = target and target.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not (camera and humanoid) then
        SetStatus((target and target.DisplayName or "That player") .. " has no character right now.", "warn")
        return
    end

    PL.stopView()
    PL.viewing = target
    camera.CameraSubject = humanoid
    if PL.cards[target] then
        PL.cards[target].viewButton.Text = "STOP"
    end
    SetStatus("Viewing " .. target.DisplayName .. ". Click STOP to go back.")
end

local function distanceTo(player)
    local myRoot = localRoot()
    local character = player.Character
    local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
    if myRoot and root then
        return (myRoot.Position - root.Position).Magnitude
    end
    return nil
end

function PL.nearest()
    local best, bestDistance
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local distance = distanceTo(player)
            if distance and (not bestDistance or distance < bestDistance) then
                best, bestDistance = player, distance
            end
        end
    end

    if best then
        teleportToPlayer(best)
    else
        SetStatus("No other player with a character to teleport to.", "warn")
    end
end

function PL.random()
    local choices = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and distanceTo(player) then
            choices[#choices + 1] = player
        end
    end

    if #choices > 0 then
        teleportToPlayer(choices[math.random(1, #choices)])
    else
        SetStatus("No other player with a character to teleport to.", "warn")
    end
end

function PL.layout()
    local list = {}
    for player, card in pairs(PL.cards) do
        list[#list + 1] = { player = player, card = card }
    end

    table.sort(list, function(a, b)
        if PL.sort == "Distance" then
            local da, db = a.card.distance or math.huge, b.card.distance or math.huge
            if da ~= db then
                return da < db
            end
        end
        return string.lower(a.player.DisplayName) < string.lower(b.player.DisplayName)
    end)

    local query = PL.query
    local visible = 0
    for rank, entry in ipairs(list) do
        entry.card.frame.LayoutOrder = rank + 1
        local player = entry.player
        local match = query == ""
            or string.find(string.lower(player.DisplayName), query, 1, true) ~= nil
            or string.find(string.lower(player.Name), query, 1, true) ~= nil
        entry.card.frame.Visible = match
        if match then
            visible = visible + 1
        end
    end

    PL.empty.Visible = visible == 0
    PL.empty.Text = (#list == 0) and "No other players in this server"
        or "No player matches \"" .. query .. "\""
    PL.count.Text = #list .. (#list == 1 and " other player" or " other players")
end

function PL.filter(query)
    PL.query = query
    PL.layout()
end

function PL.refreshCard(player, card)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local distance = distanceTo(player)
    card.distance = distance

    card.sub.Text = "@" .. player.Name .. "  |  "
        .. (distance and (math.floor(distance) .. " studs") or "no character")

    local fraction = humanoid and math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1) or 0
    card.hpFill.Size = UDim2.new(fraction, 0, 1, 0)
    card.hpFill.BackgroundColor3 = Color3.fromHSV(fraction * 0.33, 0.75, 0.9)

    if player.Team then
        card.teamDot.Visible = true
        card.teamDot.BackgroundColor3 = player.TeamColor.Color
    else
        card.teamDot.Visible = false
    end
end

function PL.addCard(player)
    if player == LocalPlayer or PL.cards[player] then
        return
    end

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 58)
    frame.BorderSizePixel = 0
    frame.Parent = PL.list
    themeBind(frame, "BackgroundColor3", "Surface")
    addCorner(frame, 9)

    local avatar = Instance.new("ImageLabel")
    avatar.Position = UDim2.fromOffset(9, 9)
    avatar.Size = UDim2.fromOffset(40, 40)
    avatar.BorderSizePixel = 0
    avatar.ScaleType = Enum.ScaleType.Crop
    avatar.Parent = frame
    themeBind(avatar, "BackgroundColor3", "Header")
    addCorner(avatar, 20)

    local teamDot = Instance.new("Frame")
    teamDot.Position = UDim2.fromOffset(38, 38)
    teamDot.Size = UDim2.fromOffset(12, 12)
    teamDot.BorderSizePixel = 0
    teamDot.Visible = false
    teamDot.ZIndex = 3
    teamDot.Parent = frame
    addCorner(teamDot, 6)
    addStroke(teamDot, "Surface", 0, 2)

    local nameLabel = newLabel(frame, player.DisplayName, 12, "Text", Enum.Font.GothamBold)
    nameLabel.Position = UDim2.new(0, 58, 0, 9)
    nameLabel.Size = UDim2.new(1, -176, 0, 16)

    local sub = newLabel(frame, "", 10, "MutedText")
    sub.Position = UDim2.new(0, 58, 0, 26)
    sub.Size = UDim2.new(1, -176, 0, 14)

    local hpBack = Instance.new("Frame")
    hpBack.Position = UDim2.new(0, 58, 0, 45)
    hpBack.Size = UDim2.new(1, -176, 0, 4)
    hpBack.BorderSizePixel = 0
    hpBack.Parent = frame
    themeBind(hpBack, "BackgroundColor3", "Header")
    addCorner(hpBack, 2)

    local hpFill = Instance.new("Frame")
    hpFill.Size = UDim2.new(1, 0, 1, 0)
    hpFill.BorderSizePixel = 0
    hpFill.Parent = hpBack
    addCorner(hpFill, 2)

    local tpButton = newButton(frame, UDim2.fromOffset(50, 26), UDim2.new(1, -112, 0.5, -13), "Accent")
    tpButton.Text = "TP"
    themeBind(tpButton, "TextColor3", "OnAccent")

    local viewButton = newButton(frame, UDim2.fromOffset(50, 26), UDim2.new(1, -58, 0.5, -13), "Header")
    viewButton.Text = "VIEW"

    local card = {
        frame = frame, sub = sub, hpFill = hpFill, teamDot = teamDot,
        viewButton = viewButton, distance = nil,
    }
    PL.cards[player] = card

    -- Connections on these buttons die with the card, so they are connected directly
    tpButton.MouseButton1Click:Connect(function()
        Sfx.play("click")
        teleportToPlayer(player)
    end)
    viewButton.MouseButton1Click:Connect(function()
        Sfx.play("click")
        PL.view(player)
    end)

    Tip.add(frame, function()
        local distance = card.distance
        return player.DisplayName .. " (@" .. player.Name .. ")\n"
            .. (distance and (math.floor(distance) .. " studs away") or "No character right now")
            .. "\nTP = teleport next to them, VIEW = spectate them."
    end)

    task.spawn(function()
        local content = PL.thumbs[player.UserId]
        if not content then
            local ok, result = pcall(function()
                return Players:GetUserThumbnailAsync(
                    player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
            end)
            if ok then
                content = result
                PL.thumbs[player.UserId] = content
            end
        end
        if content and avatar.Parent then
            avatar.Image = content
        end
    end)

    PL.refreshCard(player, card)
    PL.layout()
end

function PL.removeCard(player)
    local card = PL.cards[player]
    if not card then
        return
    end

    if PL.viewing == player then
        PL.stopView()
    end

    PL.cards[player] = nil
    card.frame:Destroy()
    PL.layout()
end

function PL.build()
    beginPage(pagePlayers, "Players")
    CreateSection("PLAYER LIST")

    local header = newCard(40, nil, { nosearch = true })
    PL.count = newLabel(header, "", 12, "Text", Enum.Font.GothamBold)
    PL.count.Position = UDim2.new(0, 12, 0, 0)
    PL.count.Size = UDim2.new(0.5, -12, 1, 0)

    local sortButton = newButton(header, UDim2.new(0.5, -10, 0, 26), UDim2.new(0.5, 0, 0, 7))
    sortButton.Text = "Sort: " .. PL.sort
    track(sortButton.MouseButton1Click:Connect(function()
        PL.sort = PL.sort == "Name" and "Distance" or "Name"
        sortButton.Text = "Sort: " .. PL.sort
        Sfx.play("click")
        for player, card in pairs(PL.cards) do
            PL.refreshCard(player, card)
        end
        PL.layout()
    end))
    Tip.add(header, "Sort the list by name or by how close each player is to you.")

    local actions = newCard(36, nil, { nosearch = true })
    local function actionButton(text, index, callback, tip)
        local button = newButton(actions, UDim2.new(1 / 3, -8, 0, 26), UDim2.new((index - 1) / 3, 6, 0, 5))
        button.Text = text
        track(button.MouseButton1Click:Connect(function()
            Sfx.play("click")
            callback()
        end))
        Tip.add(button, tip)
    end
    actionButton("NEAREST", 1, PL.nearest, "Teleport next to the closest player.")
    actionButton("RANDOM", 2, PL.random, "Teleport next to a random player.")
    actionButton("STOP VIEW", 3, function()
        if PL.viewing then
            PL.stopView()
            SetStatus("Stopped viewing.")
        end
    end, "Return the camera to your own character.")

    PL.list = Instance.new("Frame")
    PL.list.Name = "PlayerCards"
    PL.list.Size = UDim2.new(1, 0, 0, 0)
    PL.list.AutomaticSize = Enum.AutomaticSize.Y
    PL.list.BackgroundTransparency = 1
    PL.list.BorderSizePixel = 0
    PL.list.LayoutOrder = nextOrder()
    PL.list.Parent = currentParent
    adopt(PL.list, nil, {})

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 6)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = PL.list

    PL.empty = newLabel(PL.list, "", 11, "MutedText")
    PL.empty.Size = UDim2.new(1, 0, 0, 40)
    PL.empty.LayoutOrder = 1
    PL.empty.TextXAlignment = Enum.TextXAlignment.Center

    for _, player in ipairs(Players:GetPlayers()) do
        PL.addCard(player)
    end
    PL.layout()

    track(Players.PlayerAdded:Connect(PL.addCard))
    track(Players.PlayerRemoving:Connect(PL.removeCard))

    -- Keep distances and health current while the tab is open; keep the spectate camera attached
    task.spawn(function()
        while runActive do
            task.wait(0.4)
            if not runActive then
                break
            end

            if PL.viewing then
                local character = PL.viewing.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                local camera = workspace.CurrentCamera
                if humanoid and camera and camera.CameraSubject ~= humanoid then
                    camera.CameraSubject = humanoid
                end
            end

            if activePage == "Players" and MainFrame.Visible then
                for player, card in pairs(PL.cards) do
                    PL.refreshCard(player, card)
                end
                if PL.sort == "Distance" then
                    PL.layout()
                end
            end
        end
    end)

    -- Respawning puts the camera back on you, so the view is dropped
    track(LocalPlayer.CharacterAdded:Connect(function()
        if PL.viewing then
            PL.stopView()
        end
    end))
end

-- ==========================================================
-- Music tab: playlist, controls, progress bar and a small visualiser.
-- Tracks are audio asset IDs, or .mp3/.ogg files in workspace/NativeMenu/Music
-- (needs an executor with listfiles + getcustomasset).
-- ==========================================================

Music.BARS = 30
Music.barLevels = {}
Music.failStreak = 0
Music.index = nil
Music.token = 0
Music.items = {}
Music.query = ""

Music.sound = Instance.new("Sound")
Music.sound.Name = "NativeMusic"
Music.sound.Volume = G.MusicVolume
Music.sound.Parent = ScreenGui

-- mp4 / webm files can't be loaded into a Sound, so they play through a tiny
-- invisible VideoFrame (its audio track is what you hear).
Music.video = Instance.new("VideoFrame")
Music.video.Name = "NativeMusicVideo"
Music.video.Size = UDim2.fromOffset(2, 2)
Music.video.Position = UDim2.new(0, 0, 1, -2)
Music.video.BackgroundTransparency = 1
Music.video.BorderSizePixel = 0
Music.video.Volume = G.MusicVolume
Music.video.Parent = ScreenGui

Music.active = Music.sound
Music.videoPaused = false

local VIDEO_EXTENSIONS = { mp4 = true, webm = true, mov = true, m4v = true }

local function isVideoFile(path)
    local extension = string.lower(string.match(tostring(path), "%.(%w+)$") or "")
    return VIDEO_EXTENSIONS[extension] == true
end

function Music.isPlaying()
    if Music.active == Music.video then
        return Music.video.Playing == true
    end
    return Music.sound.IsPlaying
end

function Music.isPaused()
    if Music.active == Music.video then
        return Music.videoPaused and not Music.video.Playing
    end
    return Music.sound.IsPaused
end

function Music.pause()
    if Music.active == Music.video then
        Music.video:Pause()
        Music.videoPaused = true
    else
        Music.sound:Pause()
    end
end

function Music.resume()
    if Music.active == Music.video then
        Music.video:Play()
        Music.videoPaused = false
    else
        Music.sound:Resume()
    end
end

-- Stops whichever backend is active
function Music.haltAll()
    Music.sound:Stop()
    Music.video:Pause()
    Music.video.TimePosition = 0
    Music.videoPaused = false
end

local function formatTime(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function Music.applyVolume()
    local volume = math.clamp(G.MusicVolume, 0, 1)
    Music.sound.Volume = volume
    Music.video.Volume = volume
end

local function resolveTrack(entry)
    if entry.file then
        if not getcustomasset then
            return nil, "local files need an executor with getcustomasset"
        end
        local ok, asset = pcall(getcustomasset, entry.file)
        if ok and asset then
            return asset
        end
        return nil, "could not load " .. tostring(entry.file)
    end

    local id = string.match(tostring(entry.id or ""), "%d+")
    if id then
        return "rbxassetid://" .. id
    end
    return nil, "that track has no valid ID"
end

function Music.refreshUI()
    if not Music.title then
        return
    end

    local entry = Music.index and G.Playlist[Music.index]
    local playing, paused = Music.isPlaying(), Music.isPaused()

    if entry then
        Music.title.Text = entry.name
        Music.sub.Text = "Track " .. Music.index .. " of " .. #G.Playlist
            .. (isVideoFile(entry.file) and "  |  video file" or "")
            .. (playing and "  |  playing" or (paused and "  |  paused" or "  |  stopped"))
    else
        Music.title.Text = "Nothing playing"
        Music.sub.Text = #G.Playlist == 0 and "Add a track below to get started" or "Press PLAY to start the playlist"
    end

    Music.playButton.Text = playing and "PAUSE" or "PLAY"

    Music.shuffleButton.TextColor3 = G.MusicShuffle and UI_COLORS.Enabled or UI_COLORS.MutedText
    Music.loopButton.Text = "LOOP " .. string.upper(G.MusicLoop)
    Music.loopButton.TextColor3 = G.MusicLoop == "Off" and UI_COLORS.MutedText or UI_COLORS.Enabled

    for index, item in ipairs(Music.items) do
        local current = index == Music.index
        item.name.TextColor3 = current and UI_COLORS.Accent or UI_COLORS.Text
        item.name.Font = current and Enum.Font.GothamBold or Enum.Font.Gotham
    end
end

function Music.stop()
    Music.token = Music.token + 1
    Music.haltAll()
    Music.refreshUI()
end

function Music.play(index)
    local entry = G.Playlist[index]
    if not entry then
        return
    end

    local asset, problem = resolveTrack(entry)
    if not asset then
        SetStatus("Music: " .. problem, "warn")
        return
    end

    Music.token = Music.token + 1
    local token = Music.token
    Music.index = index

    Music.haltAll()
    local sound
    if entry.file and isVideoFile(entry.file) then
        sound = Music.video
        Music.active = sound
        sound.Video = asset
    else
        sound = Music.sound
        Music.active = sound
        sound.SoundId = asset
    end
    sound.Looped = G.MusicLoop == "One"
    sound.TimePosition = 0
    sound:Play()
    Music.refreshUI()

    -- A track that never loads (private audio, bad ID) is skipped instead of hanging
    task.delay(8, function()
        if runActive and token == Music.token and not sound.IsLoaded then
            Music.failStreak = Music.failStreak + 1
            SetStatus("Couldn't load \"" .. entry.name .. "\" (private or invalid audio).", "warn")
            if Music.failStreak < #G.Playlist then
                Music.step(1, true)
            else
                Music.stop()
            end
        end
    end)
end

function Music.step(direction, auto)
    local count = #G.Playlist
    if count == 0 then
        return
    end

    local index = Music.index
    if G.MusicShuffle and direction > 0 and count > 1 then
        repeat
            index = math.random(1, count)
        until index ~= Music.index
    else
        index = (index or 0) + direction
        if index > count then
            if G.MusicLoop == "All" or not auto then
                index = 1
            else
                Music.stop()
                return
            end
        elseif index < 1 then
            index = count
        end
    end

    Music.play(index)
end

function Music.toggle()
    if not Music.index then
        if #G.Playlist == 0 then
            SetStatus("The playlist is empty - add a track first.", "warn")
            return
        end
        Music.play(1)
    elseif Music.isPlaying() then
        Music.pause()
    elseif Music.isPaused() then
        Music.resume()
    else
        Music.play(Music.index)
    end

    Music.refreshUI()
end

for _, backend in ipairs({ Music.sound, Music.video }) do
    track(backend.Ended:Connect(function()
        if runActive and Music.active == backend then
            Music.step(1, true)
        end
    end))

    track(backend.Loaded:Connect(function()
        Music.failStreak = 0
        Music.refreshUI()
    end))
end

function Music.filter(query)
    Music.query = query
    for index, item in ipairs(Music.items) do
        local entry = G.Playlist[index]
        item.frame.Visible = query == "" or (entry ~= nil and string.find(string.lower(entry.name), query, 1, true) ~= nil)
    end
end

function Music.rebuild()
    for _, item in ipairs(Music.items) do
        item.frame:Destroy()
    end
    Music.items = {}

    Music.emptyLabel.Visible = #G.Playlist == 0

    for index, entry in ipairs(G.Playlist) do
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 30)
        frame.BorderSizePixel = 0
        frame.LayoutOrder = index + 1
        frame.Parent = Music.list
        themeBind(frame, "BackgroundColor3", "Surface")
        addCorner(frame, 8)

        local number = newLabel(frame, tostring(index), 10, "MutedText")
        number.Position = UDim2.new(0, 10, 0, 0)
        number.Size = UDim2.new(0, 20, 1, 0)

        local nameButton = Instance.new("TextButton")
        nameButton.Position = UDim2.new(0, 32, 0, 0)
        nameButton.Size = UDim2.new(1, -66, 1, 0)
        nameButton.BackgroundTransparency = 1
        nameButton.Font = Enum.Font.Gotham
        nameButton.TextSize = 12
        nameButton.Text = entry.name
        nameButton.TextXAlignment = Enum.TextXAlignment.Left
        nameButton.TextTruncate = Enum.TextTruncate.AtEnd
        nameButton.Parent = frame
        themeBind(nameButton, "TextColor3", "Text")

        local removeButton = newButton(frame, UDim2.fromOffset(24, 22), UDim2.new(1, -30, 0.5, -11), "Header")
        removeButton.Text = "x"

        nameButton.MouseButton1Click:Connect(function()
            Sfx.play("click")
            Music.play(index)
        end)

        removeButton.MouseButton1Click:Connect(function()
            Sfx.play("click")
            table.remove(G.Playlist, index)

            if Music.index == index then
                Music.stop()
                Music.index = nil
            elseif Music.index and Music.index > index then
                Music.index = Music.index - 1
            end

            Music.rebuild()
        end)

        Tip.add(frame, function()
            return entry.name .. "\n" .. (entry.file and "Local file" or ("Audio ID " .. tostring(entry.id)))
                .. "\nClick the name to play, x to remove."
        end)

        Music.items[index] = { frame = frame, name = nameButton }
    end

    Music.filter(Music.query)
    Music.refreshUI()
end

function Music.addTrack(idText, nameText)
    local id = string.match(idText or "", "%d+")
    if not id then
        SetStatus("Enter a numeric audio ID.", "warn")
        return false
    end

    local name = string.match(nameText or "", "^%s*(.-)%s*$")
    if name == "" then
        name = "Track " .. id
    end

    table.insert(G.Playlist, { name = name, id = id })
    Music.rebuild()
    SetStatus("Added \"" .. name .. "\" to the playlist.")
    return true
end

function Music.scanLocal()
    if not (listfiles and getcustomasset and isfolder and makefolder) then
        SetStatus("Local files need an executor with listfiles / getcustomasset.", "warn")
        return
    end

    local folder = "NativeMenu/Music"
    pcall(function()
        if not isfolder("NativeMenu") then
            makefolder("NativeMenu")
        end
        if not isfolder(folder) then
            makefolder(folder)
        end
    end)

    local ok, files = pcall(listfiles, folder)
    if not ok or type(files) ~= "table" then
        SetStatus("Couldn't read workspace/" .. folder, "warn")
        return
    end

    local known = {}
    for _, entry in ipairs(G.Playlist) do
        if entry.file then
            known[entry.file] = true
        end
    end

    local added = 0
    for _, path in ipairs(files) do
        local extension = string.lower(string.match(path, "%.(%w+)$") or "")
        if (extension == "mp3" or extension == "ogg" or extension == "wav" or VIDEO_EXTENSIONS[extension]) and not known[path] then
            local name = string.match(path, "([^/\\]+)%.%w+$") or path
            table.insert(G.Playlist, { name = name, file = path })
            added = added + 1
        end
    end

    Music.rebuild()
    if added > 0 then
        SetStatus("Added " .. added .. (added == 1 and " local track." or " local tracks."))
    else
        SetStatus("No new .mp3 / .ogg / .wav / .mp4 files in workspace/" .. folder, "warn")
    end
end

function Music.build()
    beginPage(pageMusic, "Music")

    CreateSection("NOW PLAYING")
    local card = newCard(156, nil, { nosearch = true })

    Music.title = newLabel(card, "Nothing playing", 13, "Text", Enum.Font.GothamBold)
    Music.title.Position = UDim2.new(0, 12, 0, 8)
    Music.title.Size = UDim2.new(1, -24, 0, 18)

    Music.sub = newLabel(card, "", 10, "MutedText")
    Music.sub.Position = UDim2.new(0, 12, 0, 27)
    Music.sub.Size = UDim2.new(1, -24, 0, 14)

    -- Visualiser
    local visualiser = Instance.new("Frame")
    visualiser.Position = UDim2.new(0, 12, 0, 46)
    visualiser.Size = UDim2.new(1, -24, 0, 30)
    visualiser.BackgroundTransparency = 1
    visualiser.Parent = card

    Music.bars = {}
    for index = 1, Music.BARS do
        local bar = Instance.new("Frame")
        bar.AnchorPoint = Vector2.new(0, 1)
        bar.Position = UDim2.new((index - 1) / Music.BARS, 0, 1, 0)
        bar.Size = UDim2.new(1 / Music.BARS, -2, 0.06, 0)
        bar.BorderSizePixel = 0
        bar.Parent = visualiser
        themeBind(bar, "BackgroundColor3", "Accent")
        addCorner(bar, 2)
        Music.bars[index] = bar
        Music.barLevels[index] = 0
    end

    -- Progress bar (drag to seek)
    local progressHit = Instance.new("TextButton")
    progressHit.Position = UDim2.new(0, 12, 0, 80)
    progressHit.Size = UDim2.new(1, -24, 0, 18)
    progressHit.BackgroundTransparency = 1
    progressHit.Text = ""
    progressHit.Parent = card

    local progressBar = Instance.new("Frame")
    progressBar.AnchorPoint = Vector2.new(0, 0.5)
    progressBar.Position = UDim2.new(0, 0, 0.5, 0)
    progressBar.Size = UDim2.new(1, 0, 0, 5)
    progressBar.BorderSizePixel = 0
    progressBar.Parent = progressHit
    themeBind(progressBar, "BackgroundColor3", "Header")
    addCorner(progressBar, 3)

    Music.progressFill = Instance.new("Frame")
    Music.progressFill.Size = UDim2.new(0, 0, 1, 0)
    Music.progressFill.BorderSizePixel = 0
    Music.progressFill.Parent = progressBar
    themeBind(Music.progressFill, "BackgroundColor3", "Accent")
    addCorner(Music.progressFill, 3)

    Music.progressKnob = Instance.new("Frame")
    Music.progressKnob.AnchorPoint = Vector2.new(0.5, 0.5)
    Music.progressKnob.Position = UDim2.new(0, 0, 0.5, 0)
    Music.progressKnob.Size = UDim2.fromOffset(12, 12)
    Music.progressKnob.BorderSizePixel = 0
    Music.progressKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Music.progressKnob.Parent = progressBar
    addCorner(Music.progressKnob, 6)

    Music.timeLeft = newLabel(card, "0:00", 10, "MutedText")
    Music.timeLeft.Position = UDim2.new(0, 12, 0, 99)
    Music.timeLeft.Size = UDim2.fromOffset(60, 12)

    Music.timeRight = newLabel(card, "0:00", 10, "MutedText")
    Music.timeRight.Position = UDim2.new(1, -72, 0, 99)
    Music.timeRight.Size = UDim2.fromOffset(60, 12)
    Music.timeRight.TextXAlignment = Enum.TextXAlignment.Right

    local function seek()
        local length = Music.active.TimeLength
        if length <= 0 then
            return
        end
        local pointer = Pointer.get()
        local position, size = progressBar.AbsolutePosition, progressBar.AbsoluteSize
        local alpha = math.clamp((pointer.X - position.X) / math.max(size.X, 1), 0, 1)
        Music.active.TimePosition = alpha * length
    end

    track(progressHit.InputBegan:Connect(function(input)
        if isPress(input) then
            Sliders.active = seek
            seek()
        end
    end))

    -- Controls
    local controls = Instance.new("Frame")
    controls.Position = UDim2.new(0, 12, 0, 118)
    controls.Size = UDim2.new(1, -24, 0, 28)
    controls.BackgroundTransparency = 1
    controls.Parent = card

    local function controlButton(index, text, colorKey, callback)
        local button = newButton(controls, UDim2.new(0.2, -4, 1, 0), UDim2.new((index - 1) * 0.2, 2, 0, 0), colorKey)
        button.Text = text
        button.TextSize = 10
        track(button.MouseButton1Click:Connect(function()
            Sfx.play("click")
            callback()
        end))
        return button
    end

    Music.shuffleButton = controlButton(1, "SHUFFLE", "Header", function()
        G.MusicShuffle = not G.MusicShuffle
        Music.refreshUI()
    end)
    controlButton(2, "<<", "Header", function()
        Music.step(-1, false)
    end)
    Music.playButton = controlButton(3, "PLAY", "Accent", Music.toggle)
    themeBind(Music.playButton, "TextColor3", "OnAccent")
    controlButton(4, ">>", "Header", function()
        Music.step(1, false)
    end)
    Music.loopButton = controlButton(5, "LOOP ALL", "Header", function()
        local modes = { "Off", "All", "One" }
        local nextIndex = 1
        for index, mode in ipairs(modes) do
            if mode == G.MusicLoop then
                nextIndex = index % #modes + 1
            end
        end
        G.MusicLoop = modes[nextIndex]
        Music.sound.Looped = G.MusicLoop == "One"
        Music.video.Looped = G.MusicLoop == "One"
        Music.refreshUI()
    end)

    Tip.add(Music.shuffleButton, "Shuffle: pick a random next track.")
    Tip.add(Music.loopButton, function()
        return "Loop mode: " .. G.MusicLoop .. "\nOff = stop at the end, All = repeat the playlist, One = repeat this track."
    end)
    Tip.add(Music.playButton, "Play or pause. Can be bound to a key in settings.")

    CreateSlider("Volume", "MusicVolume", {
        min = 0, max = 1, step = 0.01, percent = true,
        callback = Music.applyVolume,
        tip = "Music volume (separate from the menu sound effects).",
    })

    CreateButton("Play / pause", Music.toggle, "MusicToggle", "Play or pause the music.")
    CreateButton("Next track", function() Music.step(1, false) end, "MusicNext", "Skip to the next track.")
    CreateButton("Previous track", function() Music.step(-1, false) end, "MusicPrev", "Go back one track.")

    -- Add tracks
    CreateSection("ADD TRACKS")
    local addCard = newCard(86, nil, { nosearch = true })

    local idBox = newBox(addCard, UDim2.new(0.36, -10, 0, 26), UDim2.new(0, 10, 0, 8))
    idBox.PlaceholderText = "Audio ID"
    local nameBox = newBox(addCard, UDim2.new(0.4, -8, 0, 26), UDim2.new(0.36, 4, 0, 8))
    nameBox.PlaceholderText = "Name (optional)"
    local addButton = newButton(addCard, UDim2.new(0.24, -10, 0, 26), UDim2.new(0.76, 4, 0, 8), "Accent")
    addButton.Text = "ADD"
    themeBind(addButton, "TextColor3", "OnAccent")

    local hint = Instance.new("TextLabel")
    hint.Position = UDim2.new(0, 10, 0, 40)
    hint.Size = UDim2.new(1, -20, 0, 42)
    hint.BackgroundTransparency = 1
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 10
    hint.TextWrapped = true
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.TextYAlignment = Enum.TextYAlignment.Top
    hint.Text = "Paste the number from a Roblox audio link. Audio you can't use in-game won't load. "
        .. "Local files (.mp3 .ogg .wav .mp4 .webm): put them in workspace/NativeMenu/Music, then press Scan."
    hint.Parent = addCard
    themeBind(hint, "TextColor3", "MutedText")

    local function submit()
        if Music.addTrack(idBox.Text, nameBox.Text) then
            idBox.Text = ""
            nameBox.Text = ""
        end
    end

    track(addButton.MouseButton1Click:Connect(function()
        Sfx.play("click")
        submit()
    end))
    track(idBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            submit()
        end
    end))
    Tip.add(addCard, "Add a track by audio asset ID. Press Enter in the ID box or click ADD.")

    CreateButton("Scan local files", Music.scanLocal, nil,
        "Adds every .mp3 / .ogg / .wav / .mp4 / .webm in workspace/NativeMenu/Music (needs listfiles + getcustomasset). Video files play their audio.")

    -- Playlist
    CreateSection("PLAYLIST")

    Music.list = Instance.new("Frame")
    Music.list.Name = "Playlist"
    Music.list.Size = UDim2.new(1, 0, 0, 0)
    Music.list.AutomaticSize = Enum.AutomaticSize.Y
    Music.list.BackgroundTransparency = 1
    Music.list.BorderSizePixel = 0
    Music.list.LayoutOrder = nextOrder()
    Music.list.Parent = currentParent
    adopt(Music.list, nil, {})

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 5)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = Music.list

    Music.emptyLabel = newLabel(Music.list, "The playlist is empty.", 11, "MutedText")
    Music.emptyLabel.Size = UDim2.new(1, 0, 0, 30)
    Music.emptyLabel.LayoutOrder = 1
    Music.emptyLabel.TextXAlignment = Enum.TextXAlignment.Center

    local clearArmed = 0
    CreateButton("Clear playlist", function()
        if #G.Playlist == 0 then
            return
        end
        if os.clock() - clearArmed > 3 then
            clearArmed = os.clock()
            SetStatus("Click \"Clear playlist\" again within 3 seconds to confirm.", "warn")
            return
        end
        clearArmed = 0
        Music.stop()
        Music.index = nil
        G.Playlist = {}
        Music.rebuild()
        SetStatus("Playlist cleared.")
    end, nil, "Removes every track from the playlist (asks you to click twice).")

    Music.rebuild()

    -- Progress bar + visualiser, only while the tab is showing
    track(RunService.RenderStepped:Connect(function(dt)
        if activePage ~= "Music" or not MainFrame.Visible then
            return
        end

        local sound = Music.active
        local length = sound.TimeLength
        local position = sound.TimePosition
        local alpha = length > 0 and math.clamp(position / length, 0, 1) or 0

        Music.progressFill.Size = UDim2.new(alpha, 0, 1, 0)
        Music.progressKnob.Position = UDim2.new(alpha, 0, 0.5, 0)
        Music.timeLeft.Text = formatTime(position)
        Music.timeRight.Text = formatTime(length)

        local level = 0
        if Music.isPlaying() then
            -- VideoFrames have no loudness reading, so videos get a steady synthetic level
            level = sound == Music.video and 0.55 or math.clamp(sound.PlaybackLoudness / 450, 0, 1)
        end
        local now = os.clock()
        local smoothing = math.clamp(dt * 14, 0, 1)

        for index, bar in ipairs(Music.bars) do
            local wave = 0.55 + 0.45 * math.sin(now * 6 + index * 0.9)
            local target = level * wave
            Music.barLevels[index] = Music.barLevels[index] + (target - Music.barLevels[index]) * smoothing
            bar.Size = UDim2.new(1 / Music.BARS, -2, math.max(Music.barLevels[index], 0.06), 0)
        end
    end))
end

-- ==========================================================
-- Spotify tab
-- Uses the Spotify Web API through your executor's HTTP request function.
-- Login is the "PKCE" flow, so no client secret and no server are needed:
-- you create a free app on developer.spotify.com, paste its Client ID, open
-- the login link, then paste back the address you were redirected to.
-- Reading what's playing works for everyone; controlling playback needs
-- Spotify Premium and an active Spotify app (phone, PC...).
-- ==========================================================

do
    local HttpService = game:GetService("HttpService")

    local REDIRECT_URI = "http://127.0.0.1:8888/callback"
    local SCOPES = "user-read-playback-state user-modify-playback-state user-read-currently-playing"
    local API = "https://api.spotify.com/v1"

    Spotify.data = G.Spotify -- { clientId, refresh, verifier, name }
    Spotify.accessToken = nil
    Spotify.expiresAt = 0
    Spotify.state = nil        -- last /me/player reply (table) or nil
    Spotify.stateTime = 0
    Spotify.busy = false
    Spotify.artCache = {}
    Spotify.artUrl = nil
    Spotify.seekAlpha = nil
    Spotify.lastVolumeSend = 0

    -- ------------------------------------------------------
    -- Small helpers: SHA-256 + base64url (needed for PKCE)
    -- ------------------------------------------------------

    local K = {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    }

    function Spotify.sha256(message)
        local bxor, band, bnot, rrotate, rshift =
            bit32.bxor, bit32.band, bit32.bnot, bit32.rrotate, bit32.rshift
        local MOD = 4294967296

        local H = {
            0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
            0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
        }

        local length = #message
        message = message .. "\128" .. string.rep("\0", (55 - length) % 64) .. string.pack(">I8", length * 8)

        for chunk = 1, #message, 64 do
            local w = {}
            for i = 0, 15 do
                w[i] = string.unpack(">I4", message, chunk + i * 4)
            end
            for i = 16, 63 do
                local s0 = bxor(rrotate(w[i - 15], 7), rrotate(w[i - 15], 18), rshift(w[i - 15], 3))
                local s1 = bxor(rrotate(w[i - 2], 17), rrotate(w[i - 2], 19), rshift(w[i - 2], 10))
                w[i] = (w[i - 16] + s0 + w[i - 7] + s1) % MOD
            end

            local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
            for i = 0, 63 do
                local S1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
                local ch = bxor(band(e, f), band(bnot(e), g))
                local t1 = (h + S1 + ch + K[i + 1] + w[i]) % MOD
                local S0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
                local maj = bxor(band(a, b), band(a, c), band(b, c))
                local t2 = (S0 + maj) % MOD
                h, g, f, e, d, c, b, a = g, f, e, (d + t1) % MOD, c, b, a, (t1 + t2) % MOD
            end

            H[1] = (H[1] + a) % MOD
            H[2] = (H[2] + b) % MOD
            H[3] = (H[3] + c) % MOD
            H[4] = (H[4] + d) % MOD
            H[5] = (H[5] + e) % MOD
            H[6] = (H[6] + f) % MOD
            H[7] = (H[7] + g) % MOD
            H[8] = (H[8] + h) % MOD
        end

        return string.pack(">I4I4I4I4I4I4I4I4", H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8])
    end

    local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

    function Spotify.base64url(data)
        local out = {}
        for i = 1, #data, 3 do
            local a, b, c = string.byte(data, i, i + 2)
            local n = a * 65536 + (b or 0) * 256 + (c or 0)
            local c1 = math.floor(n / 262144) % 64
            local c2 = math.floor(n / 4096) % 64
            local c3 = math.floor(n / 64) % 64
            local c4 = n % 64
            out[#out + 1] = string.sub(B64, c1 + 1, c1 + 1) .. string.sub(B64, c2 + 1, c2 + 1)
            if b then
                out[#out + 1] = string.sub(B64, c3 + 1, c3 + 1)
            end
            if c then
                out[#out + 1] = string.sub(B64, c4 + 1, c4 + 1)
            end
        end
        return table.concat(out)
    end

    local VERIFIER_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"

    local function randomVerifier()
        local out = {}
        for _ = 1, 64 do
            local index = math.random(1, #VERIFIER_CHARS)
            out[#out + 1] = string.sub(VERIFIER_CHARS, index, index)
        end
        return table.concat(out)
    end

    local function form(fields)
        local parts = {}
        for key, value in pairs(fields) do
            parts[#parts + 1] = HttpService:UrlEncode(key) .. "=" .. HttpService:UrlEncode(tostring(value))
        end
        return table.concat(parts, "&")
    end

    -- ------------------------------------------------------
    -- HTTP
    -- ------------------------------------------------------

    local function httpRequest(options)
        local send = (syn and syn.request) or (http and http.request) or http_request or request
            or (fluxus and fluxus.request)
        if not send then
            return nil, "your executor has no HTTP request function"
        end

        local ok, response = pcall(send, options)
        if not ok then
            return nil, tostring(response)
        end
        return response
    end

    local function decode(body)
        if type(body) ~= "string" or body == "" then
            return nil
        end
        local ok, data = pcall(function()
            return HttpService:JSONDecode(body)
        end)
        return ok and data or nil
    end

    local function storeTokens(data)
        Spotify.accessToken = data.access_token
        Spotify.expiresAt = os.time() + (data.expires_in or 3600)
        if data.refresh_token then
            Spotify.data.refresh = data.refresh_token
        end
    end

    -- Returns true when a fresh access token is available
    function Spotify.ensureToken(force)
        if not force and Spotify.accessToken and os.time() < Spotify.expiresAt - 30 then
            return true
        end
        if not Spotify.data.refresh or not Spotify.data.clientId then
            return false
        end

        local response, err = httpRequest({
            Url = "https://accounts.spotify.com/api/token",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/x-www-form-urlencoded" },
            Body = form({
                grant_type = "refresh_token",
                refresh_token = Spotify.data.refresh,
                client_id = Spotify.data.clientId,
            }),
        })

        if not response then
            SetStatus("Spotify: " .. tostring(err), "warn")
            return false
        end

        local data = decode(response.Body)
        if response.StatusCode == 200 and data and data.access_token then
            storeTokens(data)
            return true
        end

        if response.StatusCode == 400 or response.StatusCode == 401 then
            SetStatus("Spotify login expired. Please connect again.", "warn")
            Spotify.disconnect(true)
        end
        return false
    end

    -- Returns data, statusCode
    function Spotify.api(method, path, body)
        if not Spotify.ensureToken(false) then
            return nil, 0
        end

        local function send()
            return httpRequest({
                Url = API .. path,
                Method = method,
                Headers = {
                    ["Authorization"] = "Bearer " .. Spotify.accessToken,
                    ["Content-Type"] = "application/json",
                },
                Body = body and HttpService:JSONEncode(body) or "",
            })
        end

        local response, err = send()
        if response and response.StatusCode == 401 and Spotify.ensureToken(true) then
            response, err = send()
        end

        if not response then
            SetStatus("Spotify: " .. tostring(err), "warn")
            return nil, 0
        end

        local data = decode(response.Body)
        return data, response.StatusCode
    end

    -- Explains the common errors in plain words
    local function explain(data, status)
        if status == 403 then
            SetStatus("Spotify says no: controlling playback needs Premium.", "warn")
        elseif status == 404 then
            SetStatus("No active Spotify device. Open Spotify and start a song first.", "warn")
        elseif status == 429 then
            SetStatus("Spotify is rate limiting requests. Wait a moment.", "warn")
        elseif status >= 400 then
            local message = data and data.error and data.error.message
            SetStatus("Spotify error " .. status .. (message and (": " .. tostring(message)) or ""), "warn")
        end
    end

    -- ------------------------------------------------------
    -- Login / logout
    -- ------------------------------------------------------

    function Spotify.isConnected()
        return Spotify.data.refresh ~= nil
    end

    function Spotify.startLogin()
        local clientId = Spotify.data.clientId
        if not clientId or clientId == "" then
            SetStatus("Paste your Spotify Client ID and press Save first.", "warn")
            return
        end

        Spotify.data.verifier = randomVerifier()
        local challenge = Spotify.base64url(Spotify.sha256(Spotify.data.verifier))

        local url = "https://accounts.spotify.com/authorize?response_type=code"
            .. "&client_id=" .. HttpService:UrlEncode(clientId)
            .. "&scope=" .. HttpService:UrlEncode(SCOPES)
            .. "&redirect_uri=" .. HttpService:UrlEncode(REDIRECT_URI)
            .. "&code_challenge_method=S256&code_challenge=" .. challenge

        Spotify.loginUrl = url
        if setclipboard then
            pcall(setclipboard, url)
            SetStatus("Login link copied. Paste it into your browser and approve.")
        else
            SetStatus("Your executor can't copy to the clipboard. Copy the link from the box below.", "warn")
            if Spotify.urlBox then
                Spotify.urlBox.Text = url
            end
        end
    end

    function Spotify.connect(text)
        text = tostring(text or "")
        local err = string.match(text, "[?&]error=([^&#%s]+)")
        if err then
            SetStatus("Spotify login was cancelled (" .. err .. ").", "warn")
            return
        end

        local code = string.match(text, "[?&]code=([^&#%s]+)")
            or string.match(text, "^%s*([%w%-_%.~]+)%s*$")
        if not code or #code < 20 then
            SetStatus("Paste the full address you were redirected to (it contains code=...).", "warn")
            return
        end
        if not Spotify.data.verifier then
            SetStatus("Press \"Copy login link\" first, then paste the address you land on.", "warn")
            return
        end

        task.spawn(function()
            local response, requestError = httpRequest({
                Url = "https://accounts.spotify.com/api/token",
                Method = "POST",
                Headers = { ["Content-Type"] = "application/x-www-form-urlencoded" },
                Body = form({
                    grant_type = "authorization_code",
                    code = code,
                    redirect_uri = REDIRECT_URI,
                    client_id = Spotify.data.clientId,
                    code_verifier = Spotify.data.verifier,
                }),
            })

            if not response then
                SetStatus("Spotify: " .. tostring(requestError), "warn")
                return
            end

            local data = decode(response.Body)
            if response.StatusCode == 200 and data and data.access_token then
                storeTokens(data)
                Spotify.data.verifier = nil

                local profile = Spotify.api("GET", "/me")
                Spotify.data.name = profile and (profile.display_name or profile.id) or nil
                SetStatus("Spotify connected" .. (Spotify.data.name and (" as " .. Spotify.data.name) or "") .. ".")
                Spotify.refreshState()
                Spotify.refreshUI()
            else
                local reason = data and (data.error_description or data.error) or ("HTTP " .. tostring(response.StatusCode))
                SetStatus("Spotify login failed: " .. tostring(reason), "warn")
            end
        end)
    end

    function Spotify.disconnect(silent)
        Spotify.data.refresh = nil
        Spotify.data.verifier = nil
        Spotify.data.name = nil
        Spotify.accessToken = nil
        Spotify.state = nil
        Spotify.refreshUI()
        if not silent then
            SetStatus("Spotify disconnected.")
        end
    end

    -- ------------------------------------------------------
    -- Playback state + controls
    -- ------------------------------------------------------

    function Spotify.refreshState()
        if Spotify.busy or not Spotify.isConnected() then
            return
        end
        Spotify.busy = true

        local data, status = Spotify.api("GET", "/me/player?additional_types=track,episode")
        Spotify.busy = false

        if status == 200 and data then
            Spotify.state = data
            Spotify.stateTime = os.clock()
            local deviceVolume = data.device and data.device.volume_percent
            if deviceVolume and deviceVolume ~= G.SpotifyVolume and not Sliders.active then
                G.SpotifyVolume = deviceVolume
                runRefreshers()
            end
        elseif status == 204 then
            Spotify.state = nil
        end

        Spotify.showState()
    end

    local function command(method, path, body, refreshAfter)
        task.spawn(function()
            local data, status = Spotify.api(method, path, body)
            if status >= 400 then
                explain(data, status)
            end
            if refreshAfter ~= false then
                task.wait(0.4)
                Spotify.refreshState()
            end
        end)
    end

    function Spotify.togglePlay()
        local state = Spotify.state
        if state and state.is_playing then
            command("PUT", "/me/player/pause")
        else
            command("PUT", "/me/player/play")
        end
    end

    function Spotify.next()
        command("POST", "/me/player/next")
    end

    function Spotify.previous()
        command("POST", "/me/player/previous")
    end

    function Spotify.toggleShuffle()
        local on = Spotify.state and Spotify.state.shuffle_state
        command("PUT", "/me/player/shuffle?state=" .. (on and "false" or "true"))
    end

    function Spotify.cycleRepeat()
        local current = Spotify.state and Spotify.state.repeat_state or "off"
        local nextMode = current == "off" and "context" or (current == "context" and "track" or "off")
        command("PUT", "/me/player/repeat?state=" .. nextMode)
    end

    function Spotify.seekTo(alpha)
        local item = Spotify.state and Spotify.state.item
        if not item or not item.duration_ms then
            return
        end
        local position = math.floor(alpha * item.duration_ms)
        Spotify.state.progress_ms = position
        Spotify.stateTime = os.clock()
        command("PUT", "/me/player/seek?position_ms=" .. position)
    end

    local volumeToken = 0
    function Spotify.sendVolume(value)
        -- Wait until the slider has been still for a moment before calling the API
        volumeToken = volumeToken + 1
        local token = volumeToken
        task.delay(0.35, function()
            if token == volumeToken then
                command("PUT", "/me/player/volume?volume_percent=" .. math.floor(value + 0.5), nil, false)
            end
        end)
    end

    function Spotify.search(query)
        query = string.match(query or "", "^%s*(.-)%s*$")
        if query == "" then
            return
        end
        if not Spotify.isConnected() then
            SetStatus("Connect Spotify first.", "warn")
            return
        end

        task.spawn(function()
            local data, status = Spotify.api("GET", "/search?type=track&limit=8&q=" .. HttpService:UrlEncode(query))
            if status ~= 200 or not data or not data.tracks then
                explain(data, status or 0)
                return
            end
            Spotify.showResults(data.tracks.items or {})
        end)
    end

    function Spotify.playUri(uri)
        command("PUT", "/me/player/play", { uris = { uri } })
    end

    -- ------------------------------------------------------
    -- Album art (downloaded once, shown through getcustomasset)
    -- ------------------------------------------------------

    function Spotify.loadArt(url)
        if not url or url == Spotify.artUrl then
            return
        end
        Spotify.artUrl = url

        local cached = Spotify.artCache[url]
        if cached then
            Spotify.art.Image = cached
            return
        end

        if not (writefile and getcustomasset) then
            Spotify.art.Image = ""
            return
        end

        task.spawn(function()
            local response = httpRequest({ Url = url, Method = "GET" })
            if not (response and response.StatusCode == 200 and response.Body) then
                return
            end

            local name = string.gsub(string.sub(url, -24), "[^%w]", "")
            local path = "NativeMenu/art_" .. name .. ".jpg"
            local ok, asset = pcall(function()
                if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("NativeMenu") then
                    makefolder("NativeMenu")
                end
                writefile(path, response.Body)
                return getcustomasset(path)
            end)

            if ok and asset then
                Spotify.artCache[url] = asset
                if Spotify.artUrl == url then
                    Spotify.art.Image = asset
                end
            end
        end)
    end

    -- ------------------------------------------------------
    -- UI
    -- ------------------------------------------------------

    function Spotify.refreshUI()
        if not Spotify.setupHolder then
            return
        end
        local connected = Spotify.isConnected()
        Spotify.setupHolder.Visible = not connected
        Spotify.playerHolder.Visible = connected
        Spotify.account.Text = connected
            and ("Connected" .. (Spotify.data.name and (" as " .. Spotify.data.name) or ""))
            or "Not connected"
        if not connected then
            Spotify.showState()
        end
    end

    function Spotify.showState()
        if not Spotify.title then
            return
        end

        local state = Spotify.state
        local item = state and state.item

        if item then
            Spotify.title.Text = item.name or "Unknown"

            local artists = {}
            if item.artists then
                for _, artist in ipairs(item.artists) do
                    artists[#artists + 1] = artist.name
                end
            elseif item.show then
                artists[1] = item.show.name
            end
            Spotify.artist.Text = table.concat(artists, ", ")

            local album = item.album or item.show
            Spotify.album.Text = album and album.name or ""
            Spotify.device.Text = state.device and ("on " .. state.device.name) or ""

            local images = album and album.images
            if images and #images > 0 then
                Spotify.loadArt(images[#images > 1 and #images - 1 or 1].url)
            end
        else
            Spotify.title.Text = "Nothing playing"
            Spotify.artist.Text = Spotify.isConnected()
                and "Open Spotify on any device and start a song."
                or ""
            Spotify.album.Text = ""
            Spotify.device.Text = ""
        end

        local playing = state and state.is_playing
        Spotify.playButton.Text = playing and "PAUSE" or "PLAY"
        Spotify.shuffleButton.TextColor3 = (state and state.shuffle_state) and UI_COLORS.Enabled or UI_COLORS.MutedText

        local repeatState = state and state.repeat_state or "off"
        Spotify.repeatButton.Text = repeatState == "track" and "REPEAT 1" or "REPEAT"
        Spotify.repeatButton.TextColor3 = repeatState == "off" and UI_COLORS.MutedText or UI_COLORS.Enabled

    end

    function Spotify.showResults(items)
        for _, child in ipairs(Spotify.results:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end

        Spotify.resultsEmpty.Visible = #items == 0
        Spotify.resultsEmpty.Text = "No tracks found."

        for index, item in ipairs(items) do
            local artists = {}
            for _, artist in ipairs(item.artists or {}) do
                artists[#artists + 1] = artist.name
            end

            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(1, 0, 0, 38)
            frame.BorderSizePixel = 0
            frame.LayoutOrder = index + 1
            frame.Parent = Spotify.results
            themeBind(frame, "BackgroundColor3", "Surface")
            addCorner(frame, 8)

            local name = newLabel(frame, item.name, 12, "Text", Enum.Font.GothamBold)
            name.Position = UDim2.new(0, 10, 0, 4)
            name.Size = UDim2.new(1, -70, 0, 16)

            local by = newLabel(frame, table.concat(artists, ", "), 10, "MutedText")
            by.Position = UDim2.new(0, 10, 0, 20)
            by.Size = UDim2.new(1, -70, 0, 14)

            local play = newButton(frame, UDim2.fromOffset(46, 24), UDim2.new(1, -54, 0.5, -12), "Accent")
            play.Text = "PLAY"
            themeBind(play, "TextColor3", "OnAccent")
            play.TextSize = 10

            play.MouseButton1Click:Connect(function()
                Sfx.play("click")
                Spotify.playUri(item.uri)
            end)
        end
    end

    function Spotify.build()
        beginPage(pageSpotify, "Spotify")

        -- Holder frames let the whole "set up" or "player" block be shown or hidden at once
        local function newHolder()
            local holder = Instance.new("Frame")
            holder.Size = UDim2.new(1, 0, 0, 0)
            holder.AutomaticSize = Enum.AutomaticSize.Y
            holder.BackgroundTransparency = 1
            holder.BorderSizePixel = 0
            holder.LayoutOrder = nextOrder()
            holder.Parent = currentParent
            adopt(holder, nil, { nosection = true })

            local layout = Instance.new("UIListLayout")
            layout.Padding = UDim.new(0, 6)
            layout.SortOrder = Enum.SortOrder.LayoutOrder
            layout.Parent = holder
            return holder
        end

        local statusCard = newCard(34, nil, { nosearch = true, nosection = true })
        Spotify.account = newLabel(statusCard, "", 12, "Text", Enum.Font.GothamBold)
        Spotify.account.Position = UDim2.new(0, 12, 0, 0)
        Spotify.account.Size = UDim2.new(1, -24, 1, 0)

        Spotify.setupHolder = newHolder()
        Spotify.playerHolder = newHolder()

        -- ---------- setup ----------
        beginPage(Spotify.setupHolder, "Spotify")

        CreateHint("1. Open developer.spotify.com/dashboard, create an app, and add this Redirect URI:\n"
            .. REDIRECT_URI .. "\n2. Paste the app's Client ID below and press SAVE.\n"
            .. "3. Press COPY LOGIN LINK, open it in your browser and approve.\n"
            .. "4. The next page won't load - that's normal. Copy its full address, paste it below, press CONNECT.", 104)

        local idCard = newCard(40, nil, { nosearch = true, nosection = true })
        local idBox = newBox(idCard, UDim2.new(1, -92, 0, 26), UDim2.new(0, 8, 0, 7))
        idBox.PlaceholderText = "Client ID"
        idBox.Text = Spotify.data.clientId or ""
        idBox.TextSize = 11
        local idSave = newButton(idCard, UDim2.fromOffset(70, 26), UDim2.new(1, -78, 0, 7), "Accent")
        idSave.Text = "SAVE"
        themeBind(idSave, "TextColor3", "OnAccent")
        track(idSave.MouseButton1Click:Connect(function()
            Sfx.play("click")
            local text = string.match(idBox.Text, "^%s*(.-)%s*$")
            if text == "" then
                SetStatus("Paste the Client ID from your Spotify app first.", "warn")
                return
            end
            Spotify.data.clientId = text
            SetStatus("Client ID saved.")
        end))

        CreateButton("Copy login link", Spotify.startLogin, nil,
            "Creates a Spotify login link and copies it. Open it in your browser.")

        local urlCard = newCard(40, nil, { nosearch = true, nosection = true })
        Spotify.urlBox = newBox(urlCard, UDim2.new(1, -92, 0, 26), UDim2.new(0, 8, 0, 7))
        Spotify.urlBox.PlaceholderText = "Paste the redirected address here"
        Spotify.urlBox.TextSize = 11
        local connectButton = newButton(urlCard, UDim2.fromOffset(70, 26), UDim2.new(1, -78, 0, 7), "Accent")
        connectButton.Text = "CONNECT"
        connectButton.TextSize = 10
        themeBind(connectButton, "TextColor3", "OnAccent")
        track(connectButton.MouseButton1Click:Connect(function()
            Sfx.play("click")
            Spotify.connect(Spotify.urlBox.Text)
        end))
        track(Spotify.urlBox.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                Spotify.connect(Spotify.urlBox.Text)
            end
        end))

        CreateHint("Your login is stored in workspace/NativeMenu/settings.json so you stay connected after a restart. "
            .. "Press DISCONNECT in the player view to remove it.", 40)

        -- ---------- player ----------
        beginPage(Spotify.playerHolder, "Spotify")

        local card = newCard(176, nil, { nosearch = true, nosection = true })

        Spotify.art = Instance.new("ImageLabel")
        Spotify.art.Position = UDim2.fromOffset(12, 12)
        Spotify.art.Size = UDim2.fromOffset(72, 72)
        Spotify.art.BorderSizePixel = 0
        Spotify.art.ScaleType = Enum.ScaleType.Crop
        Spotify.art.Parent = card
        themeBind(Spotify.art, "BackgroundColor3", "Header")
        addCorner(Spotify.art, 8)

        Spotify.title = newLabel(card, "Nothing playing", 13, "Text", Enum.Font.GothamBold)
        Spotify.title.Position = UDim2.new(0, 96, 0, 12)
        Spotify.title.Size = UDim2.new(1, -108, 0, 18)

        Spotify.artist = newLabel(card, "", 11, "MutedText")
        Spotify.artist.Position = UDim2.new(0, 96, 0, 32)
        Spotify.artist.Size = UDim2.new(1, -108, 0, 14)

        Spotify.album = newLabel(card, "", 10, "MutedText")
        Spotify.album.Position = UDim2.new(0, 96, 0, 49)
        Spotify.album.Size = UDim2.new(1, -108, 0, 13)

        Spotify.device = newLabel(card, "", 10, "Accent")
        Spotify.device.Position = UDim2.new(0, 96, 0, 65)
        Spotify.device.Size = UDim2.new(1, -108, 0, 13)

        -- Progress bar (drag to seek, sends the seek when you let go)
        local progressHit = Instance.new("TextButton")
        progressHit.Position = UDim2.new(0, 12, 0, 94)
        progressHit.Size = UDim2.new(1, -24, 0, 18)
        progressHit.BackgroundTransparency = 1
        progressHit.Text = ""
        progressHit.Parent = card

        local progressBar = Instance.new("Frame")
        progressBar.AnchorPoint = Vector2.new(0, 0.5)
        progressBar.Position = UDim2.new(0, 0, 0.5, 0)
        progressBar.Size = UDim2.new(1, 0, 0, 5)
        progressBar.BorderSizePixel = 0
        progressBar.Parent = progressHit
        themeBind(progressBar, "BackgroundColor3", "Header")
        addCorner(progressBar, 3)

        Spotify.progressFill = Instance.new("Frame")
        Spotify.progressFill.Size = UDim2.new(0, 0, 1, 0)
        Spotify.progressFill.BorderSizePixel = 0
        Spotify.progressFill.Parent = progressBar
        themeBind(Spotify.progressFill, "BackgroundColor3", "Accent")
        addCorner(Spotify.progressFill, 3)

        Spotify.progressKnob = Instance.new("Frame")
        Spotify.progressKnob.AnchorPoint = Vector2.new(0.5, 0.5)
        Spotify.progressKnob.Position = UDim2.new(0, 0, 0.5, 0)
        Spotify.progressKnob.Size = UDim2.fromOffset(12, 12)
        Spotify.progressKnob.BorderSizePixel = 0
        Spotify.progressKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Spotify.progressKnob.Parent = progressBar
        addCorner(Spotify.progressKnob, 6)

        Spotify.timeLeft = newLabel(card, "0:00", 10, "MutedText")
        Spotify.timeLeft.Position = UDim2.new(0, 12, 0, 113)
        Spotify.timeLeft.Size = UDim2.fromOffset(60, 12)

        Spotify.timeRight = newLabel(card, "0:00", 10, "MutedText")
        Spotify.timeRight.Position = UDim2.new(1, -72, 0, 113)
        Spotify.timeRight.Size = UDim2.fromOffset(60, 12)
        Spotify.timeRight.TextXAlignment = Enum.TextXAlignment.Right

        local function seekPreview()
            local pointer = Pointer.get()
            local position, size = progressBar.AbsolutePosition, progressBar.AbsoluteSize
            Spotify.seekAlpha = math.clamp((pointer.X - position.X) / math.max(size.X, 1), 0, 1)
        end

        track(progressHit.InputBegan:Connect(function(input)
            if isPress(input) and Spotify.state and Spotify.state.item then
                Sliders.active = seekPreview
                Sliders.release = function()
                    local alpha = Spotify.seekAlpha
                    Spotify.seekAlpha = nil
                    if alpha then
                        Spotify.seekTo(alpha)
                    end
                end
                seekPreview()
            end
        end))

        local controls = Instance.new("Frame")
        controls.Position = UDim2.new(0, 12, 0, 136)
        controls.Size = UDim2.new(1, -24, 0, 28)
        controls.BackgroundTransparency = 1
        controls.Parent = card

        local function controlButton(index, text, colorKey, callback)
            local button = newButton(controls, UDim2.new(0.2, -4, 1, 0), UDim2.new((index - 1) * 0.2, 2, 0, 0), colorKey)
            button.Text = text
            button.TextSize = 10
            track(button.MouseButton1Click:Connect(function()
                Sfx.play("click")
                callback()
            end))
            return button
        end

        Spotify.shuffleButton = controlButton(1, "SHUFFLE", "Header", Spotify.toggleShuffle)
        controlButton(2, "<<", "Header", Spotify.previous)
        Spotify.playButton = controlButton(3, "PLAY", "Accent", Spotify.togglePlay)
        themeBind(Spotify.playButton, "TextColor3", "OnAccent")
        controlButton(4, ">>", "Header", Spotify.next)
        Spotify.repeatButton = controlButton(5, "REPEAT", "Header", Spotify.cycleRepeat)

        Tip.add(card, "Spotify now playing. Controls need Spotify Premium and an open Spotify app.")

        CreateSlider("Spotify volume", "SpotifyVolume", {
            min = 0, max = 100, step = 1, suffix = "%",
            callback = Spotify.sendVolume,
            tip = "Volume of the Spotify device that is playing (not the menu).",
        })

        Keys.register("SpotifyToggle", "Spotify: play / pause", Spotify.togglePlay)
        Keys.register("SpotifyNext", "Spotify: next track", Spotify.next)
        Keys.register("SpotifyPrev", "Spotify: previous track", Spotify.previous)

        CreateButton("Disconnect Spotify", function()
            Spotify.disconnect(false)
        end, nil, "Logs out and removes the saved login.")

        CreateSection("SEARCH RESULTS")
        CreateHint("Type in the search bar at the top and press Enter.", 18)

        Spotify.results = Instance.new("Frame")
        Spotify.results.Size = UDim2.new(1, 0, 0, 0)
        Spotify.results.AutomaticSize = Enum.AutomaticSize.Y
        Spotify.results.BackgroundTransparency = 1
        Spotify.results.BorderSizePixel = 0
        Spotify.results.LayoutOrder = nextOrder()
        Spotify.results.Parent = currentParent
        adopt(Spotify.results, nil, {})

        local resultsLayout = Instance.new("UIListLayout")
        resultsLayout.Padding = UDim.new(0, 5)
        resultsLayout.SortOrder = Enum.SortOrder.LayoutOrder
        resultsLayout.Parent = Spotify.results

        Spotify.resultsEmpty = newLabel(Spotify.results, "", 11, "MutedText")
        Spotify.resultsEmpty.Size = UDim2.new(1, 0, 0, 24)
        Spotify.resultsEmpty.LayoutOrder = 1
        Spotify.resultsEmpty.Visible = false

        -- Progress bar + time, extrapolated between polls
        track(RunService.RenderStepped:Connect(function()
            if activePage ~= "Spotify" or not MainFrame.Visible or not Spotify.isConnected() then
                return
            end

            local state = Spotify.state
            local item = state and state.item
            local duration = item and item.duration_ms or 0
            local progress = state and state.progress_ms or 0
            if state and state.is_playing then
                progress = progress + (os.clock() - Spotify.stateTime) * 1000
            end
            progress = math.clamp(progress, 0, math.max(duration, 1))

            local alpha = duration > 0 and progress / duration or 0
            if Spotify.seekAlpha then
                alpha = Spotify.seekAlpha
                progress = alpha * duration
            end

            Spotify.progressFill.Size = UDim2.new(alpha, 0, 1, 0)
            Spotify.progressKnob.Position = UDim2.new(alpha, 0, 0.5, 0)
            Spotify.timeLeft.Text = formatTime(progress / 1000)
            Spotify.timeRight.Text = formatTime(duration / 1000)
        end))

        -- Poll Spotify only while the tab is open
        task.spawn(function()
            while runActive do
                task.wait(2)
                if not runActive then
                    break
                end
                if activePage == "Spotify" and MainFrame.Visible and Spotify.isConnected() then
                    Spotify.refreshState()
                end
            end
        end)

        -- Enter in the search bar runs a Spotify search on this tab
        track(SearchBox.FocusLost:Connect(function(enterPressed)
            if enterPressed and activePage == "Spotify" then
                Spotify.search(SearchBox.Text)
            end
        end))

        Spotify.refreshUI()
        Spotify.showState()
        beginPage(pageSettings, "Settings")
    end
end

-- ==========================================================
-- Theme picker (14 presets + a "+" that opens the colour wheel)
-- ==========================================================

local function setTheme(name)
    loadThemeColors(name)
    applyTheme()
    runRefreshers()
end

local function CreateThemePicker()
    local PER_ROW = 5
    local cells = {}

    for _, theme in ipairs(THEMES) do
        cells[#cells + 1] = theme
    end
    cells[#cells + 1] = "custom" -- the last slot is the "+" button

    for rowStart = 1, #cells, PER_ROW do
        local row = newPlainRow(34, { nosearch = true })

        for column = 1, PER_ROW do
            local cell = cells[rowStart + column - 1]
            if cell then
                local button = Instance.new("TextButton")
                button.Size = UDim2.new(1 / PER_ROW, -4, 1, 0)
                button.Position = UDim2.new((column - 1) / PER_ROW, 2, 0, 0)
                button.BorderSizePixel = 0
                button.Font = Enum.Font.GothamBold
                button.AutoButtonColor = false
                button.Parent = row
                addCorner(button, 8)

                local stroke = Instance.new("UIStroke")
                stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                stroke.Parent = button

                if cell == "custom" then
                    -- "+" : colour follows the current theme
                    button.Text = "+"
                    button.TextSize = 22
                    themeBind(button, "BackgroundColor3", "Surface")
                    themeBind(button, "TextColor3", "Accent")

                    local function refreshPlus()
                        local active = G.ThemeName == "Custom"
                        stroke.Thickness = active and 2 or 1
                        stroke.Color = active and UI_COLORS.Text or UI_COLORS.Accent
                    end
                    refreshPlus()
                    refreshers[#refreshers + 1] = refreshPlus
                    themeHooks[#themeHooks + 1] = refreshPlus

                    track(button.MouseButton1Click:Connect(function()
                        Sfx.play("click")
                        Wheel.open("Custom theme", nil, function(_, h, s, v)
                            G.CustomTheme = { h = h, s = s, v = v }
                            setTheme("Custom")
                        end, "theme", G.CustomTheme)
                    end))

                    Tip.add(button, "Custom theme\nPick any colour on the wheel and the whole menu follows it.")
                else
                    button.Text = cell.name
                    button.TextSize = 9
                    button.BackgroundColor3 = cell.Accent
                    button.TextColor3 = Color3.fromRGB(255, 255, 255)
                    stroke.Color = Color3.fromRGB(255, 255, 255)
                    stroke.Thickness = 2
                    stroke.Enabled = G.ThemeName == cell.name

                    refreshers[#refreshers + 1] = function()
                        stroke.Enabled = G.ThemeName == cell.name
                    end

                    track(button.MouseButton1Click:Connect(function()
                        Sfx.play("click")
                        setTheme(cell.name)
                    end))
                end
            end
        end
    end
end

-- ==========================================================
-- Aim FOV circle (drawn around the cursor while Target Lock is on)
-- ==========================================================

do
local FOVCircle = Instance.new("Frame")
FOVCircle.Name = "AimFOVCircle"
FOVCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FOVCircle.BackgroundTransparency = 1
FOVCircle.BorderSizePixel = 0
FOVCircle.Visible = false
FOVCircle.Active = false
FOVCircle.ZIndex = 2
FOVCircle.Parent = ScreenGui
addCorner(FOVCircle, 100000)
addStroke(FOVCircle, "Accent", 0.1, 1.5)

track(RunService.RenderStepped:Connect(function()
    local show = G.ShowAimFOVCircle and G.AimbotEnabled and G.AimFOV > 0
    FOVCircle.Visible = show == true

    if show then
        local pointer = Pointer.get()
        FOVCircle.Size = UDim2.fromOffset(G.AimFOV * 2, G.AimFOV * 2)
        FOVCircle.Position = UDim2.fromOffset(pointer.X, pointer.Y)
    end
end))

end

-- ==========================================================
-- Reset all settings (every default registered at the top)
-- ==========================================================

local AdvancedFrame

local function resetAllSettings()
    for key, value in pairs(DEFAULTS) do
        G[key] = copyValue(value)
    end
    G.PerfPos = nil
    Keys.capture = nil
    Wheel.close()

    G.FlyEnabled = false
    stopFly()

    MainScale.Scale = math.clamp(G.UIScale, 0.7, 1.5)
    loadThemeColors(G.ThemeName)
    applyTheme()
    applyOpacity()
    applyESPStyle()
    RefreshESP()
    Perf.apply()
    Music.applyVolume()
    Music.refreshUI()

    for _, section in ipairs(allSections) do
        section.collapsed = G.Collapsed[section.key] == true
        section.chevron.Rotation = section.collapsed and 0 or 90
        applySectionVisibility(section)
    end

    AdvancedFrame.Visible = G.AdvancedUnlocked
    runRefreshers()
    SetStatus("All settings reset to defaults.")
end

-- ==========================================================
-- MOVE tab
-- ==========================================================

beginPage(pageMove, "Move")

CreateSection("MOVEMENT")
CreateSlider("Speed", "WalkSpeedValue", {
    min = 0, max = 500, hardMax = 1000000, step = 1,
    toggleKey = "SpeedEnabled", autoEnable = true,
    tip = "Walk speed. The slider goes to 500; type a bigger number if you really want it.",
})
CreateSlider("Jump Power", "JumpHeightValue", {
    min = 0, max = 500, hardMax = 1000000, step = 1,
    toggleKey = "JumpEnabled", autoEnable = true,
    tip = "How high you jump. The slider goes to 500; type a bigger number if you need it.",
})
CreateToggle("Infinite Jump", "InfiniteJumpEnabled", nil, "Jump again in mid-air as often as you like.")
CreateToggle("Noclip", "NoClipEnabled", nil, "Walk through walls and parts. Your collisions come back when you turn it off.")

CreateSection("FLIGHT")
CreateSlider("Fly", "FlySpeedValue", {
    min = 0, max = 500, hardMax = 1000000, step = 1,
    toggleKey = "FlyEnabled", toggleCallback = toggleFly,
    tip = "Fly speed. Switch fly on with the toggle or its key (F by default).",
})
CreateHint("WASD move | Space/E up | Ctrl/Q down | Shift boost | fly key toggles (F by default).", 40)

CreateSection("WORLD")
CreateSlider("Gravity", "GravityValue", {
    min = 0, max = 400, hardMin = 0, hardMax = 100000, step = 1,
    toggleKey = "GravityEnabled", autoEnable = true,
    tip = "World gravity. The normal Roblox value is about 196. Restored when you turn it off.",
})

CreateSection("TELEPORT")
CreateButton("Open player list", function()
    gotoPage("Players")
end, nil, "Jump to the PLAYERS tab: search, see distances, teleport or spectate.")
CreateButton("Teleport to nearest player", PL.nearest, "TPNearest", "Teleports you next to the closest player.")
CreateButton("Teleport to random player", PL.random, "TPRandom", "Teleports you next to a random player.")

CreateSection("SERVER")
CreateToggle("Prefer friends' servers", "ServerHopPreferFriends", nil,
    "Server hop tries to join a server one of your friends is in first.")
CreateButton("Server hop", serverHop, "ServerHop", "Joins a different public server of this game.")

CreateSection("UTILITY")
CreateToggle("Anti-AFK", "AntiAFKEnabled", nil, "Stops Roblox from kicking you for being idle for 20 minutes.")

-- ==========================================================
-- COMBAT tab
-- ==========================================================

beginPage(pageCombat, "Combat")

CreateSection("TARGET LOCK")
CreateToggle("Target Lock", "AimbotEnabled", nil, "Pulls the camera toward the closest player to your cursor.")
CreateToggle("Skip Teammates", "AimbotTeamCheck", nil, "Ignores players on your team (only in games that have teams).")
CreateSlider("Aim strength", "AimbotStrength", {
    min = 0, max = 100, step = 1,
    tip = "0 = off, 100 = instant snap. Lower values pull the camera more gently.",
})
CreateToggle("Show FOV circle", "ShowAimFOVCircle", nil,
    "Draws the Aim FOV area around your cursor. Set the size with \"Aim FOV\" in the advanced settings (double-click the logo).")

-- ==========================================================
-- VISUALS tab
-- ==========================================================

beginPage(pageVisuals, "Visuals")

CreateSection("ESP")
CreateToggle("Highlight ESP", "HighlightESPEnabled", RefreshESP, "Outlines and tints every player, even through walls.")
CreateToggle("Skeleton ESP", "BoneESPEnabled", RefreshESP, "Draws lines along each player's skeleton.")
CreateToggle("Nametag ESP", "NametagESPEnabled", RefreshESP, "Shows name, health and distance above each player.")
CreateToggle("Armor ESP", "ArmorESPEnabled", RefreshESP, "Lists the accessories / armor each player is wearing.")

CreateSection("ESP STYLE")
CreateColorRow("Enemy colour", "ESPEnemyColor", "Colour used for players that are not on your team.", applyESPStyle)
CreateColorRow("Team colour", "ESPTeamColor", "Colour used for your teammates.", applyESPStyle)
CreateSlider("Fill transparency", "ESPFillTransparency", {
    min = 0, max = 1, step = 0.05, decimals = 2, callback = applyESPStyle,
    tip = "How see-through the highlight fill is. 1 = only the outline.",
})
CreateSlider("Outline transparency", "ESPOutlineTransparency", {
    min = 0, max = 1, step = 0.05, decimals = 2, callback = applyESPStyle,
    tip = "How see-through the highlight outline is.",
})
CreateSlider("Max distance", "ESPMaxDistance", {
    min = 0, max = 2000, hardMax = 100000, step = 10, suffix = " st",
    tip = "ESP is hidden for players farther away than this. 0 = no limit.",
})
CreateToggle("Show distance", "ESPShowDistance", nil, "Adds the distance in studs to the nametags.")

CreateSection("CAMERA")
CreateToggle("Unlimited Zoom", "UnlimitedZoomEnabled", nil, "Lets the camera zoom out as far as you want.")
CreateToggle("Shift Lock", "ShiftLockEnabled", nil, "Locks the cursor to the centre and turns your character with the camera.")
CreateSlider("Field of view", "CameraFOVValue", {
    min = 30, max = 120, hardMin = 1, hardMax = 120, step = 1,
    toggleKey = "CameraFOVEnabled", autoEnable = true,
    tip = "Camera field of view in degrees. Your original value comes back when it is off.",
})
CreateHint("Hold Left Alt to free the cursor and use the menu while Shift Lock is on.", 26)

CreateSection("YOUR CHARACTER")
CreateToggle("Invisibility", "InvisibleEnabled", nil, "Hides your own character (only on your screen unless the game replicates it).")

-- ==========================================================
-- PLAYERS and MUSIC tabs
-- ==========================================================

PL.build()
Music.build()
Spotify.build()

-- ==========================================================
-- SETTINGS page (click the logo)
-- ==========================================================

beginPage(pageSettings, "Settings")

CreateSection("APPEARANCE")
CreateThemePicker()
CreateSlider("Menu opacity", "MenuOpacity", {
    min = 0.3, max = 1, step = 0.05, percent = true, callback = applyOpacity,
    tip = "How see-through the menu background is.",
})
CreateSlider("Menu size", "UIScale", {
    min = 0.7, max = 1.5, step = 0.05, percent = true,
    callback = function(value)
        MainScale.Scale = value
    end,
    tip = "Scales the whole menu. Useful on very large or very small screens.",
})

CreateSection("INTERFACE")
CreateToggle("Tooltips", "TooltipsEnabled", nil, "Hover a setting for a moment to see what it does.", true)
CreateSlider("Tooltip delay", "TooltipDelay", {
    min = 0.2, max = 3, step = 0.1, suffix = " s",
    tip = "How long you hover before a tooltip appears.",
})
CreateToggle("Sound effects", "SfxEnabled", nil, "Click, toggle and notification sounds.", true)
CreateSlider("Effects volume", "SfxVolume", {
    min = 0, max = 1, step = 0.05, percent = true,
    tip = "Volume of the menu sound effects.",
})
CreateToggle("Notifications", "ToastsEnabled", nil, "Small pop-ups in the top right corner.", true)
CreateSlider("Notification time", "ToastDuration", {
    min = 1, max = 10, step = 0.5, suffix = " s",
    tip = "How long a notification stays on screen.",
})

CreateToggle("Auto-calibrate cursor", "PointerAutoCalibrate", nil,
    "Measures the cursor position error automatically while you move over the menu buttons.", true)
CreateSlider("Cursor offset (px)", "PointerOffset", {
    min = -80, max = 80, step = 1, suffix = " px",
    tip = "If the menu reacts a few pixels above or below your cursor, adjust this. Auto-calibrate also changes it.",
})

CreateSection("PERFORMANCE STATS")
CreateToggle("Show stats overlay", "PerfEnabled", Perf.apply,
    "A small overlay with live performance numbers. Drag it anywhere on screen.")
CreateToggle("FPS", "PerfFPS", Perf.apply, "Frames per second.", true)
CreateToggle("Ping", "PerfPing", Perf.apply, "Round-trip time to the server.", true)
CreateToggle("Frame time", "PerfFrameTime", Perf.apply, "Milliseconds per frame.", true)
CreateToggle("Memory", "PerfMemory", Perf.apply, "Memory used by the game client.", true)
CreateToggle("Players", "PerfPlayers", Perf.apply, "Players in the server / max players.", true)
CreateToggle("Clock", "PerfClock", Perf.apply, "Your local time.", true)
CreateToggle("Position", "PerfPosition", Perf.apply, "Your character's X, Y, Z.", true)
CreateToggle("Speed", "PerfSpeed", Perf.apply, "How fast your character is moving (studs per second).", true)
CreateToggle("FPS graph", "PerfGraph", Perf.apply, "A small history graph of your frame rate.", true)
CreateToggle("Colour-coded values", "PerfColorCode", Perf.apply,
    "Green / yellow / red depending on how good the number is.", true)
CreateToggle("Accent labels", "PerfAccentLabels", Perf.apply, "Colours the stat names with the theme colour.", true)
CreateChoice("Layout", "PerfLayout", { "Vertical", "Horizontal" }, "Stack the stats in a column or a row.", Perf.apply)
CreateChoice("Corner", "PerfCorner", Perf.cornerNames, "Snap the overlay to a screen corner.", function()
    G.PerfPos = nil
    Perf.apply()
end)
CreateSlider("Overlay size", "PerfScale", {
    min = 0.6, max = 2, step = 0.05, percent = true, callback = Perf.apply,
    tip = "Scales the stats overlay.",
})
CreateSlider("Overlay background", "PerfOpacity", {
    min = 0, max = 1, step = 0.05, percent = true, callback = Perf.apply,
    tip = "How solid the overlay background is. 0% = text only.",
})
CreateSlider("Update interval", "PerfInterval", {
    min = 0.1, max = 2, step = 0.1, suffix = " s", callback = Perf.apply,
    tip = "How often the numbers refresh.",
})
CreateButton("Reset overlay position", function()
    G.PerfPos = nil
    Perf.apply()
    SetStatus("Stats overlay snapped back to its corner.")
end, nil, "Puts the overlay back in the selected corner after you dragged it.")

CreateSection("KEYBINDS")
CreateHint("Click a key button, then press a key. Use the x (or right-click, Backspace, Delete) to clear; Escape cancels.", 26)

-- The rows are added further down, once every toggle has registered its action
do
    local frame = Instance.new("Frame")
    frame.Name = "Keybinds"
    frame.Size = UDim2.new(1, 0, 0, 0)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.LayoutOrder = nextOrder()
    frame.Parent = pageSettings
    adopt(frame, nil, {})

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = frame

    Keys.frame = frame
end

CreateSection("GENERAL")
CreateButton("Reset window", resetWindow, nil, "Puts the menu back to its default size and position.")
CreateButton("Reset all settings", resetAllSettings, nil, "Restores every setting to its default. Your playlist is kept.")

-- Secret section: double-click the logo to show or hide it
AdvancedFrame = Instance.new("Frame")
AdvancedFrame.Name = "Advanced"
AdvancedFrame.Size = UDim2.new(1, 0, 0, 0)
AdvancedFrame.AutomaticSize = Enum.AutomaticSize.Y
AdvancedFrame.BackgroundTransparency = 1
AdvancedFrame.BorderSizePixel = 0
AdvancedFrame.LayoutOrder = nextOrder()
AdvancedFrame.Visible = G.AdvancedUnlocked
AdvancedFrame.Parent = pageSettings

do
    local advancedLayout = Instance.new("UIListLayout")
    advancedLayout.Padding = UDim.new(0, 6)
    advancedLayout.SortOrder = Enum.SortOrder.LayoutOrder
    advancedLayout.Parent = AdvancedFrame
end

beginPage(AdvancedFrame, "Settings")
inAdvanced = true

CreateSection("ADVANCED")
CreateToggle("Instant WASD start/stop", "InstantMoveEnabled", nil,
    "With Speed on, you reach full speed instantly and stop instantly.")
CreateSlider("Fly boost (x)", "FlyBoost", {
    min = 1, max = 20, hardMax = 100, step = 1,
    tip = "How much faster flying gets while Shift is held.",
})
CreateSlider("Fly smoothing", "FlySmoothing", {
    min = 1, max = 30, hardMax = 100, step = 1,
    tip = "Higher = snappier turns and stops, lower = floatier.",
})
CreateChoice("Aim part", "AimPart", { "Head", "Root" }, "Which body part Target Lock aims at.")
CreateSlider("Aim FOV (px)", "AimFOV", {
    min = 0, max = 1000, hardMax = 5000, step = 5,
    tip = "Only players within this many pixels of your cursor can be targeted. 0 = no limit.",
})
CreateHint("Double-click the logo to hide this section again.", 26)

inAdvanced = false

-- Keybind rows: built last so every toggle above has registered its action
beginPage(Keys.frame, "Settings")
Keys.createSummary()
for _, id in ipairs(Keys.order) do
    Keys.createRow(id)
end
CreateButton("Clear all keybinds", function()
    for id in pairs(G.Binds) do
        G.Binds[id] = nil
    end
    Keys.capture = nil
    runRefreshers()
    SetStatus("All keybinds cleared.")
end, nil, "Removes every keybind, including the menu key.")
beginPage(pageSettings, "Settings")

-- ==========================================================
-- Logo button: settings page + secret unlock
-- ==========================================================

local logoClicks = {}

track(LogoButton.MouseButton1Click:Connect(function()
    local now = os.clock()
    local recent = {}

    logoClicks[#logoClicks + 1] = now
    for _, clickTime in ipairs(logoClicks) do
        if now - clickTime <= 0.6 then
            recent[#recent + 1] = clickTime
        end
    end
    logoClicks = recent

    if #logoClicks >= 2 then
        logoClicks = {}
        G.AdvancedUnlocked = not G.AdvancedUnlocked
        AdvancedFrame.Visible = G.AdvancedUnlocked
        gotoPage("Settings")
        Sfx.play(G.AdvancedUnlocked and "on" or "off")
        SetStatus(G.AdvancedUnlocked and "Advanced settings unlocked." or "Advanced settings hidden.")
        return
    end

    Sfx.play("click")
    if activePage == "Settings" then
        gotoPage(lastMainPage)
    else
        gotoPage("Settings")
    end
end))

-- ==========================================================
-- Hotkeys (every toggle and bindable button can be bound in settings)
-- ==========================================================

track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end

    -- A keybind button is waiting for the next key press
    if Keys.capture then
        local handler = Keys.capture
        Keys.capture = nil
        handler(input.KeyCode)
        return
    end

    if gameProcessed or UserInputService:GetFocusedTextBox() then
        return
    end

    Keys.fire(input.KeyCode.Name)
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

-- Settings are written to disk every couple of seconds when something changed
task.spawn(function()
    while runActive do
        task.wait(2)
        if not runActive then
            break
        end
        Persist.save()
    end
end)

-- Start on the Move tab with the saved theme and opacity applied
applyOpacity()
showPage("Move")
Sfx.play("open")

-- ==========================================================
-- Cleanup (called automatically if you run the script again)
-- ==========================================================

G.NativeMenuCleanup = function()
    pcall(Persist.save)
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
    pcall(PL.stopView)
    pcall(Music.haltAll)
    restoreMisc()

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

    for humanoidInstance, saved in pairs(savedHumanoid) do
        if humanoidInstance.Parent then
            restoreHumanoid(humanoidInstance, saved)
        end
    end
    restoreCollisions()
    restoreZoom()
    restoreVisibility()
    releaseShiftLock()

    ESPFolder:Destroy()
    ScreenGui:Destroy()
end
