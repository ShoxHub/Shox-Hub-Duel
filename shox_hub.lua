_G.ShoxHub = _G.ShoxHub or {}
local ShoxHubState = _G.ShoxHub
if ShoxHubState.Running or _G.BloodHoundsRunning then
    warn("[ShoxHub] Eine Instanz läuft bereits. Bitte zuerst die bestehende Instanz beenden, bevor du erneut ausführst.")
    return
end
ShoxHubState.Running = true
ShoxHubState.Version     = "v1.6.2"
ShoxHubState.Connections = ShoxHubState.Connections or {}
ShoxHubState.Timers      = ShoxHubState.Timers      or {}

function ShoxHubState:Track(conn)
    if conn then table.insert(self.Connections, conn) end
    return conn
end

function ShoxHubState:Destroy()
    self.Running = false
    _G.BloodHoundsRunning = false
    if type(shoxIntroFinish) == "function" then pcall(shoxIntroFinish) end
    if type(stopAllBackgroundTasks) == "function" then pcall(stopAllBackgroundTasks) end
    for _, conn in ipairs(self.Connections) do pcall(function() conn:Disconnect() end) end
    self.Connections = {}
    for _, t in ipairs(self.Timers) do pcall(task.cancel, t) end
    self.Timers = {}
    local names = {"FictionHub", "FictionHubMobilePanel", "ShoxHubIntro", "ShoxCodeSniperIntro", "TpBatButton", "BatV2Button", "InstaResetButton", "ShoxHubE01Warning"}
    local parents = { game:GetService("CoreGui") }
    local lp = game:GetService("Players").LocalPlayer
    local pg = lp and lp:FindFirstChildOfClass("PlayerGui")
    if pg then table.insert(parents, pg) end
    for _, name in ipairs(names) do
        for _, parent in ipairs(parents) do
            local gui = parent:FindFirstChild(name)
            if gui then pcall(function() gui:Destroy() end) end
        end
    end
    print("[ShoxHub v1.7.0] Destroyed — Instanz freigegeben.")
end

_G.BloodHoundsRunning = true

repeat task.wait() until game:IsLoaded()

-- ============================================================
-- SHox Code Sniper style intro (visual/audio only; no Code Sniper hooks)
-- ============================================================
local ShoxHubPlayers = game:GetService("Players")
local ShoxHubTweenService = game:GetService("TweenService")
local ShoxHubRunService = game:GetService("RunService")
local ShoxHubSoundService = game:GetService("SoundService")
local ShoxHubHttpService = game:GetService("HttpService")
local ShoxHubPlayer = ShoxHubPlayers.LocalPlayer

-- v1.6.0: Unified font matches CTD intro brand (GothamBlack).
local SHOX_UI_FONT = Enum.Font.GothamBlack

local ShoxIntro = {
    Running = true,
    Letters = {"S", "H", "O", "X", "H", "U", "B"},
    Beats = {
        {0.05, 1, "a"}, {0.52, 1, "b"}, {0.84, 0.6}, {1.28, 0.9},
        {1.58, 0.5}, {1.88, 0.9}, {2.11, 0.6}, {2.48, 2.2, "drop"},
        {3.15, 1}, {3.74, 1}, {4.34, 1.2}, {4.75, 1.7, "end"},
    },
    IntroUrl = "https://files.catbox.moe/ocdxaf.ogg",
    Dir = "CodeSniper",
    MusicDir = "CodeSniper/music",
}
local ShoxIntroGui, ShoxIntroSound, ShoxIntroHeartbeat

local function shoxIntroMake(className, props, parent)
    local obj = Instance.new(className)
    for k, v in pairs(props) do obj[k] = v end
    if parent then obj.Parent = parent end
    return obj
end

local function shoxIntroTween(obj, props, duration, style, direction)
    if not obj or not obj.Parent then return nil end
    local tween = ShoxHubTweenService:Create(
        obj,
        TweenInfo.new(duration or 0.25, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out),
        props
    )
    tween:Play()
    return tween
end

local function shoxIntroParent()
    local ok, hui = pcall(function() return gethui and gethui() end)
    if ok and hui then return hui end
    local pg = ShoxHubPlayer:FindFirstChildOfClass("PlayerGui")
    return pg or game:GetService("CoreGui")
end

local function shoxIntroFinish()
    ShoxIntro.Running = false
    if ShoxIntroHeartbeat then ShoxIntroHeartbeat:Disconnect(); ShoxIntroHeartbeat = nil end
    if ShoxIntroSound then
        pcall(function()
            ShoxIntroSound:Stop()
            ShoxIntroSound:Destroy()
        end)
        ShoxIntroSound = nil
    end
    if ShoxIntroGui then
        local gui = ShoxIntroGui
        ShoxIntroGui = nil
        shoxIntroTween(gui:FindFirstChild("IntroBG"), {BackgroundTransparency = 1}, 0.25)
        for _, obj in ipairs(gui:GetDescendants()) do
            if obj:IsA("TextLabel") then
                shoxIntroTween(obj, {TextTransparency = 1}, 0.2)
            elseif obj:IsA("Frame") and obj.Name ~= "IntroBG" then
                shoxIntroTween(obj, {BackgroundTransparency = 1}, 0.2)
            end
        end
        task.delay(0.28, function()
            if gui and gui.Parent then gui:Destroy() end
        end)
    end
end

local function shoxIntroSpark(stage, letters, count, wide, accent)
    for _ = 1, count do
        local angle = math.random() * math.pi * 2
        local distance = (wide and 260 or 130) * (0.4 + math.random() * 0.8)
        local x = letters[math.random(1, #letters)].x
        local particle = shoxIntroMake("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, x, 0.5, -10),
            Size = UDim2.fromOffset(6, 6),
            Rotation = math.random(0, 90),
            BackgroundColor3 = accent,
            BorderSizePixel = 0,
        }, stage)
        shoxIntroTween(particle, {
            Position = UDim2.new(0.5, x + math.cos(angle) * distance, 0.5, -10 + math.sin(angle) * distance),
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(2, 2),
        }, 0.55)
        task.delay(0.6, function()
            if particle and particle.Parent then particle:Destroy() end
        end)
    end
end

local function shoxIntroRing(stage, accent, thickness)
    local ring = shoxIntroMake("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, -10),
        Size = UDim2.fromOffset(40, 40),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, stage)
    shoxIntroMake("UICorner", {CornerRadius = UDim.new(1, 0)}, ring)
    local stroke = shoxIntroMake("UIStroke", {Thickness = thickness, Color = accent}, ring)
    shoxIntroTween(ring, {Size = UDim2.fromOffset(820, 820)}, 0.7)
    shoxIntroTween(stroke, {Transparency = 1}, 0.7)
    task.delay(0.8, function()
        if ring and ring.Parent then ring:Destroy() end
    end)
end

local function shoxIntroPlay()
    -- v1.6.0: Pure Black & White Intro exact match.
    local accent = Color3.fromRGB(255, 255, 255)
    local subColor = Color3.fromRGB(200, 200, 200)
    local introParent = shoxIntroParent()
    pcall(function()
        local old = introParent:FindFirstChild("ShoxHubIntro") or introParent:FindFirstChild("ShoxCodeSniperIntro")
        if old then old:Destroy() end
    end)
    local gui = shoxIntroMake("ScreenGui", {
        Name = "ShoxHubIntro",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 2000005,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, introParent)
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
    ShoxIntroGui = gui

    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    local base = math.clamp(math.min(viewport.X * 0.6 / 376, viewport.Y * 0.4 / 80), 0.5, 3)
    local bg = shoxIntroMake("Frame", {
        Name = "IntroBG", Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0, Active = false,
    }, gui)
    shoxIntroTween(bg, {BackgroundTransparency = 0}, 0.3)

    local stage = shoxIntroMake("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Active = false,
    }, gui)
    local stageScale = shoxIntroMake("UIScale", {Scale = base}, stage)
    local letters = {}
    for i, character in ipairs(ShoxIntro.Letters) do
        local x = -163 + (i - 1) * 50 + (i >= 5 and 26 or 0)
        local wrap = shoxIntroMake("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, x, 0.5, -10),
            Size = UDim2.fromOffset(50, 80),
            BackgroundTransparency = 1, BorderSizePixel = 0, Active = false,
        }, stage)
        local letterScale = shoxIntroMake("UIScale", {Scale = 1}, wrap)
        local label = shoxIntroMake("TextLabel", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            Text = character, Font = Enum.Font.GothamBlack, TextSize = 76,
            TextColor3 = accent, TextTransparency = 1, Active = false,
        }, wrap)
        letters[i] = {w = wrap, us = letterScale, lb = label, x = x, hit = -10, amp = 0, rev = math.huge}
    end

    local line = shoxIntroMake("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 52),
        Size = UDim2.fromOffset(0, 4), BackgroundColor3 = accent, BorderSizePixel = 0,
    }, stage)
    local subtitle = shoxIntroMake("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 80),
        Size = UDim2.fromOffset(376, 22), BackgroundTransparency = 1,
        Text = "discord.gg/EA7xS26mA9", Font = SHOX_UI_FONT,
        TextSize = 17, TextColor3 = subColor, TextTransparency = 1,
    }, stage)
    local flash = shoxIntroMake("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = accent,
        BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 5, Active = false,
    }, gui)
    local skip = shoxIntroMake("TextButton", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14),
        Size = UDim2.fromOffset(78, 32), BackgroundColor3 = Color3.fromRGB(20, 20, 20),
        Text = "Skip", TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = SHOX_UI_FONT, TextSize = 14, AutoButtonColor = false,
        BorderSizePixel = 0, ZIndex = 10, Active = true,
    }, gui)
    shoxIntroMake("UICorner", {CornerRadius = UDim.new(0, 9)}, skip)
    shoxIntroMake("UIStroke", {Color = accent, Thickness = 1, Transparency = 0.55}, skip)
    skip.Activated:Connect(function() shoxIntroFinish() end)

    local timeline, beatIndex = 0, 1
    local pulse, shake, flashAlpha, underline, subtitleAlpha = 0, 0, 0, 0, 0
    local startedAt = os.clock()
    local audioStarted = false

    local function fireBeat(beat)
        local strength, kind = beat[2], beat[3]
        pulse = math.max(pulse, 0.05 + 0.06 * strength)
        shake = math.max(shake, 6 * strength)
        flashAlpha = math.max(flashAlpha, math.min(0.1 * strength, 0.35))
        local first, last, amplitude = 1, #letters, 0.3 * strength
        if kind == "a" then first, last, amplitude = 1, 4, 1.6
        elseif kind == "b" then first, last, amplitude = 5, 7, 1.6 end
        for i = first, last do
            local entry = letters[i]
            entry.hit = timeline + (i - first) * 0.035
            entry.amp = amplitude
            if amplitude > 1 then entry.rev = entry.hit end
        end
        if kind == "drop" then
            pulse, shake, flashAlpha = 0.35, 26, 0.75
            shoxIntroRing(stage, accent, 6)
            task.delay(0.12, function() if ShoxIntro.Running then shoxIntroRing(stage, accent, 3) end end)
            shoxIntroSpark(stage, letters, 24, true, accent)
        elseif kind == "end" then
            pulse, shake, flashAlpha = 0.3, 20, 0.6
            shoxIntroRing(stage, accent, 5)
            shoxIntroSpark(stage, letters, 18, true, accent)
        else
            shoxIntroSpark(stage, letters, math.floor(4 * strength) + 2, false, accent)
        end
    end

    local sound = ShoxIntroSound
    local fadeStart, fadeEnd = 4.95, 5.5
    ShoxIntroHeartbeat = ShoxHubRunService.Heartbeat:Connect(function(dt)
        if not ShoxIntro.Running then return end
        if sound and sound.IsPlaying then
            audioStarted = true
            timeline = sound.TimePosition
        elseif audioStarted then
            timeline = timeline + dt
        else
            timeline = timeline + dt
            if os.clock() - startedAt > 8 then
                shoxIntroFinish()
                return
            end
        end
        while ShoxIntro.Beats[beatIndex] and timeline >= ShoxIntro.Beats[beatIndex][1] do
            fireBeat(ShoxIntro.Beats[beatIndex])
            beatIndex = beatIndex + 1
        end
        local fade = math.clamp((timeline - fadeStart) / (fadeEnd - fadeStart), 0, 1)
        pulse = pulse * math.exp(-dt * 7)
        shake = shake * math.exp(-dt * 9)
        flashAlpha = flashAlpha * math.exp(-dt * 8)
        local shakeNow = shake > 0.3 and shake or 0
        stage.Position = UDim2.new(0.5, (math.random() - 0.5) * 2 * shakeNow, 0.5, (math.random() - 0.5) * 2 * shakeNow)
        stage.Rotation = (math.random() - 0.5) * 0.3 * shakeNow
        stageScale.Scale = base * (1 + pulse) * (1 + fade * 0.5)
        flash.BackgroundTransparency = 1 - flashAlpha
        bg.BackgroundTransparency = fade
        for i, entry in ipairs(letters) do
            local age = timeline - entry.hit
            entry.lb.TextTransparency = (timeline >= entry.rev) and fade or 1
            local damp = age >= 0 and math.exp(-age * 5.5) or 0
            entry.w.Position = UDim2.new(0.5, entry.x, 0.5, -10 - (age >= 0 and math.abs(math.sin(age * 12)) * 22 * damp or 0))
            entry.w.Rotation = age >= 0 and math.sin(age * 10) * 7 * damp * (i % 2 == 0 and 1 or -1) or 0
            entry.us.Scale = 1 + (age >= 0 and entry.amp * math.exp(-age * 8) or 0)
        end
        if timeline >= 0.84 then underline = math.min(1, underline + dt * 3.5) end
        line.Size = UDim2.fromOffset(376 * underline, 4)
        line.BackgroundTransparency = fade
        if timeline >= 3.15 then subtitleAlpha = math.min(1, subtitleAlpha + dt * 5) end
        subtitle.TextTransparency = math.max(1 - subtitleAlpha, fade)
        skip.BackgroundTransparency = fade
        skip.TextTransparency = fade
        if timeline >= fadeEnd then shoxIntroFinish() end
    end)
end

local function shoxIntroLoadAudio()
    local folder = ShoxIntro.MusicDir
    pcall(function() if makefolder then makefolder(ShoxIntro.Dir) end end)
    pcall(function() if makefolder then makefolder(folder) end end)
    local path = folder .. "/intro.ogg"
    local mp3Path = folder .. "/intro.mp3"
    local assetFn = getcustomasset or getsynasset or getasset
    if type(assetFn) == "function" and isfile then
        for _, candidate in ipairs({path, mp3Path}) do
            local okFile, exists = pcall(isfile, candidate)
            if okFile and exists then
                local okAsset, asset = pcall(assetFn, candidate)
                if okAsset and type(asset) == "string" then return asset end
            end
        end
    end
    local rq = request or http_request or (syn and syn.request)
    local body
    if type(rq) == "function" then
        local okReq, response = pcall(rq, {Url = ShoxIntro.IntroUrl, Method = "GET"})
        if okReq and type(response) == "table" and response.StatusCode == 200 then body = response.Body end
    end
    if type(body) ~= "string" or #body < 1000 then
        local okHttp, response = pcall(function() return game:HttpGet(ShoxIntro.IntroUrl) end)
        if okHttp and type(response) == "string" and #response > 1000 then body = response end
    end
    if type(body) == "string" and #body > 1000 and writefile and type(assetFn) == "function" then
        local extension = body:sub(1, 4) == "OggS" and "ogg" or "mp3"
        local savePath = folder .. "/intro." .. extension
        local okWrite = pcall(writefile, savePath, body)
        if okWrite then
            local okAsset, asset = pcall(assetFn, savePath)
            if okAsset and type(asset) == "string" then return asset end
        end
    end
    return nil
end

task.spawn(function()
    local asset = nil
    pcall(function() asset = shoxIntroLoadAudio() end)
    if not ShoxIntro.Running then return end
    if asset then
        local sound = Instance.new("Sound")
        sound.Name = "ShoxCodeSniperIntroAudio"
        sound.SoundId = asset
        sound.Volume = 0.6
        sound.Looped = false
        sound.Parent = ShoxHubSoundService
        ShoxIntroSound = sound
        pcall(function() sound:Play() end)
    end
    shoxIntroPlay()
end)


-- Intro is self-cleaning; the existing ShoxHub UI remains unchanged below.
-- ============================================================
-- FIN INTRO
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local HS = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LP = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- v1.6.0: Warn-Throttling gegen Log-Spam aus Loops.
local _shoxWarnLast = {}
local function shoxWarn(key, msg, interval)
    interval = interval or 5
    local now = os.clock()
    if _shoxWarnLast[key] and now - _shoxWarnLast[key] < interval then return end
    _shoxWarnLast[key] = now
    warn("[ShoxHub v1.6.0][" .. tostring(key) .. "] " .. tostring(msg))
end

local _tick          = tick
local _clamp         = math.clamp
local _floor         = math.floor
local _abs           = math.abs
local _huge          = math.huge
local _sqrt          = math.sqrt
local _V3new         = Vector3.new
local _V3zero        = Vector3.zero
local _CFnew         = CFrame.new
local _CFlookAt      = CFrame.lookAt
local _RayParams_new = RaycastParams.new

local _GetPlayersCached
do
    local cache, cacheTime = nil, 0
    _GetPlayersCached = function()
        local now = _tick()
        if cache and now - cacheTime < 0.03 then return cache end
        cache = Players:GetPlayers()
        cacheTime = now
        return cache
    end
end

local function waitForCharReady(char, timeout)
    timeout = timeout or 5
    local deadline = _tick() + timeout
    while true do
        if (not char) or (not char.Parent) then char = LP.Character end
        local ready = char and char.Parent
            and char:FindFirstChild("HumanoidRootPart")
            and char:FindFirstChildOfClass("Humanoid")
        if ready and (char == LP.Character or not LP.Character) then break end
        if _tick() > deadline then return false end
        task.wait(0.05)
    end
    return true
end

NS = 60
_globalMovementLock = 0 -- v1.6.2: global, damit CarrySystem/_applyVelocitySpeed die Variable vor Zeile ~3000 sehen
CS = 30
LAGGER_SPEED = 15
LAGGER_CARRY_SPEED = 24.5
MEDUSA_COOLDOWN = 25
BAT_AIMBOT_SPEED = 90
BYPASS_AIMBOT_SPEED = 60
MOBILE_PANEL_WIDTH = 128
MOBILE_PANEL_HEIGHT = 294
CONFIG_FILE = "FictionHub.json"
BAT_V2_HIT_DIST = 4.5
_isDraggingButton = false

backgroundIndex = 1
backgroundImageTransparency = 0.35
floatingButtonScale = 1
progressBarScale = 1
_floatingUIScales = {}

local CarrySystem = {
    normalSpeed = NS,
    carrySpeed = CS,
    laggerSpeed = LAGGER_SPEED,
    laggerCarrySpeed = LAGGER_CARRY_SPEED,
    speedToggled = false,
    laggerMode = 0,
    softStealEnabled = false,
    softStealRadius = 10,
    softStealSpeed = 30,
    softStealLatched = false,
    _isCarrying = false,
    _lastCarryCheck = 0,
    _lvBoost = nil,
    _lvAtt = nil,
    _blockedTime = 0,
    _maxForce = 2200,
    _freeForce = 500,
    _heartbeatConn = nil,
    _softStealScanner = nil,
    _lastSoftStealScan = 0,
    _softStealAnimals = {},
    _softStealScanning = false,
    _state = nil,
    _dropInProgress = false,
    _batAimbotToggled = false,
    _rayParams = nil,
    _rayFilter = nil,
    _rayFilterTime = 0,
}

function CarrySystem:isCarrying()
    local now = _tick()
    if now - (self._lastCarryCheck or 0) < 0.1 then
        return self._isCarrying
    end
    self._lastCarryCheck = now
    local char = LP.Character
    if not char then self._isCarrying = false; return false end
    -- Carry state is detected only from explicit game attributes/values.
    -- WalkSpeed is not a reliable carrying signal and caused false positives.
    local byAttr = false
    local ok, v = pcall(function() return LP:GetAttribute("Stealing") end)
    if ok and v == true then byAttr = true end
    local ok2, v2 = pcall(function() return char:GetAttribute("Stealing") end)
    if ok2 and v2 == true then byAttr = true end
    if not byAttr then
        for _, name in ipairs({"Carrying","IsCarrying","Grabbed","Holding","StealHold","HasGrab"}) do
            local obj = char:FindFirstChild(name)
            if obj then
                if (obj:IsA("BoolValue") and obj.Value) or
                   (obj:IsA("ObjectValue") and obj.Value) or
                   (obj:IsA("StringValue") and obj.Value ~= "") then
                    byAttr = true; break
                end
            end
        end
    end
    self._isCarrying = byAttr
    return self._isCarrying
end

function CarrySystem:getActiveSpeed()
    if autoLeftEnabled == true or autoRightEnabled == true then
        return self.normalSpeed
    end
    if self.softStealEnabled then
        local _, dist = self:getNearestSoftStealAnimal(self.softStealRadius)
        local inRange = dist and dist <= self.softStealRadius
        if inRange then
            self.softStealLatched = true
            return self.softStealSpeed
        end
        if self.softStealLatched and self:isCarrying() then
            return self.softStealSpeed
        else
            self.softStealLatched = false
        end
    end
    if self.laggerMode == 1 then return self.laggerSpeed end
    if self.laggerMode == 2 then return self.laggerCarrySpeed end
    if self.speedToggled then return self.carrySpeed end
    return self.normalSpeed
end

function CarrySystem:getStatus()
    if autoLeftEnabled == true or autoRightEnabled == true then
        return "NORMAL", self.normalSpeed
    end
    if self.softStealEnabled then
        local _, dist = self:getNearestSoftStealAnimal(self.softStealRadius)
        local inRange = dist and dist <= self.softStealRadius
        if inRange or (self.softStealLatched and self:isCarrying()) then
            return "AUTO CARRY", self.softStealSpeed
        end
    end
    if self.laggerMode == 1 then return "LAGGER", self.laggerSpeed end
    if self.laggerMode == 2 then return "LAGGER CARRY", self.laggerCarrySpeed end
    if self.speedToggled then return "CARRY", self.carrySpeed end
    return "NORMAL", self.normalSpeed
end

local function destroyLV()
    if CarrySystem._lvBoost and CarrySystem._lvBoost.Parent then pcall(function() CarrySystem._lvBoost:Destroy() end) end
    if CarrySystem._lvAtt and CarrySystem._lvAtt.Parent then pcall(function() CarrySystem._lvAtt:Destroy() end) end
    CarrySystem._lvBoost = nil; CarrySystem._lvAtt = nil
end

local function setupLV(hrp)
    if CarrySystem._lvBoost and CarrySystem._lvBoost.Parent == hrp then return end
    destroyLV()
    local att = Instance.new("Attachment"); att.Parent = hrp
    local lv = Instance.new("LinearVelocity")
    lv.Name = "CarryBoostLV"
    lv.Attachment0 = att
    lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
    lv.PrimaryTangentAxis = _V3new(1,0,0)
    lv.SecondaryTangentAxis = _V3new(0,0,1)
    lv.MaxForce = CarrySystem._maxForce
    lv.PlaneVelocity = Vector2.zero
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.Parent = hrp
    CarrySystem._lvAtt = att
    CarrySystem._lvBoost = lv
    pcall(function() hrp:SetNetworkOwner(LP) end)
end

function CarrySystem:scanSoftStealAnimals()
    self._softStealAnimals = {}
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return end
    for _, plot in ipairs(plots:GetChildren()) do
        if plot:IsA("Model") and not isMyPlotByName(plot.Name) then
            local podiums = plot:FindFirstChild("AnimalPodiums")
            if podiums then
                for _, podium in ipairs(podiums:GetChildren()) do
                    if podium:IsA("Model") then
                        local base = podium:FindFirstChild("Base")
                        local spawn = base and base:FindFirstChild("Spawn")
                        if spawn then
                            table.insert(self._softStealAnimals, {
                                plot = plot.Name,
                                slot = podium.Name,
                                worldPosition = spawn.Position,
                                uid = plot.Name .. "_" .. podium.Name,
                            })
                        end
                    end
                end
            end
        end
    end
end

function CarrySystem:startSoftStealScanner()
    if self._softStealScanner then return end
    self._softStealScanning = true
    self:scanSoftStealAnimals()
    self._lastSoftStealScan = 0
    self._softStealScanner = RunService.Heartbeat:Connect(function()
        if not self._softStealScanning then return end
        local now = _tick()
        if now - (self._lastSoftStealScan or 0) >= 1.25 then
            self._lastSoftStealScan = now
            self:scanSoftStealAnimals()
        end
    end)
end

function CarrySystem:stopSoftStealScanner()
    self._softStealScanning = false
    if self._softStealScanner then
        self._softStealScanner:Disconnect()
        self._softStealScanner = nil
    end
end

function CarrySystem:getNearestSoftStealAnimal(radius)
    local char = LP.Character
    local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso"))
    if not root then return nil, _huge end
    local best, bestDist = nil, _huge
    local animals = self._softStealAnimals
    local rpos = root.Position
    for i = 1, #animals do
        local data = animals[i]
        if data.worldPosition then
            local dx = rpos.X - data.worldPosition.X
            local dy = rpos.Y - data.worldPosition.Y
            local dz = rpos.Z - data.worldPosition.Z
            local dist = _sqrt(dx*dx + dy*dy + dz*dz)
            if dist < bestDist then
                best = data; bestDist = dist
            end
        end
    end
    if radius and bestDist > radius then return nil, bestDist end
    return best, bestDist
end

function CarrySystem:updateMovement(dt)
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    -- v1.7.0 SH-06/07 Fix: Global Movement Lock
    if tick() < _globalMovementLock then
        local lv = self._lvBoost
        if lv then pcall(function() lv.PlaneVelocity = Vector2.zero; lv.Enabled = false end) end
        return
    end

    -- Only one system may write movement physics at a time.
    -- Auto Left/Right and the combat controllers own velocity while active.
    local batBypass = _G.SnowVS and _G.SnowVS.BatBypass
    local externallyControlled =
        autoLeftEnabled == true or autoRightEnabled == true
        or autoBatEnabled == true or autoBatV2Enabled == true
        or batDesyncTpEnabled == true or dropActive == true
        or (batBypass and batBypass.Enabled == true)
    if externallyControlled then
        local lv = self._lvBoost
        if lv then
            pcall(function()
                lv.PlaneVelocity = Vector2.zero
                lv.Enabled = false
            end)
        end
        self._blockedTime = 0
        return
    end

    local speed = self:getActiveSpeed()
    local moveDir = hum.MoveDirection
    local moving = moveDir.Magnitude > 0.1

    local wallNormalFlat = nil
    if moving then
        if not self._rayParams then
            self._rayParams = _RayParams_new()
            self._rayParams.FilterType = Enum.RaycastFilterType.Exclude
            self._rayFilter = {}
            self._rayFilterTime = 0
        end
        local now = _tick()
        if now - self._rayFilterTime > 1 then
            self._rayFilterTime = now
            local filter = self._rayFilter
            while #filter > 0 do filter[#filter] = nil end
            filter[1] = char
            local plist = _GetPlayersCached()
            for i = 1, #plist do
                local p = plist[i]
                if p.Character then
                    filter[#filter + 1] = p.Character
                end
            end
            self._rayParams.FilterDescendantsInstances = filter
        else
            local filter = self._rayFilter
            local found = false
            for i = 1, #filter do
                if filter[i] == char then found = true; break end
            end
            if not found then
                filter[1] = char
                self._rayParams.FilterDescendantsInstances = filter
            end
        end
        local flatDir = _V3new(moveDir.X, 0, moveDir.Z).Unit
        local hit = Workspace:Raycast(hrp.Position + _V3new(0,1,0), flatDir * 2.5, self._rayParams)
        if hit and hit.Instance and hit.Instance.CanCollide then
            local nf = _V3new(hit.Normal.X, 0, hit.Normal.Z)
            if nf.Magnitude > 0.7 then wallNormalFlat = nf.Unit end
        end
    end

    local blocked = wallNormalFlat ~= nil

    if blocked then
        for _, model in ipairs(char:GetChildren()) do
            if model:IsA("Model") then
                for _, part in ipairs(model:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
                end
            end
        end
        for _, name in ipairs({"Carrying","IsCarrying","Grabbed","Holding","StealHold","HasGrab"}) do
            local v = char:FindFirstChild(name)
            if v and v:IsA("ObjectValue") and v.Value and v.Value:IsA("Model") then
                for _, part in ipairs(v.Value:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
                end
            end
        end
    end

    local state = hum:GetState()
    local ragdolled = state == Enum.HumanoidStateType.Physics
                   or state == Enum.HumanoidStateType.Ragdoll
                   or state == Enum.HumanoidStateType.FallingDown
    local moverBlocked = ragdolled or self._dropInProgress or self._batAimbotToggled

    if not moverBlocked then
        if not CarrySystem._lvBoost or CarrySystem._lvBoost.Parent ~= hrp then setupLV(hrp) end
        local lv = CarrySystem._lvBoost
        if lv then
            if not lv.Enabled then lv.Enabled = true end
            if moveDir.Magnitude > 0.1 then
                local flat = _V3new(moveDir.X, 0, moveDir.Z).Unit
                if wallNormalFlat then
                    local wanted = flat * speed
                    local along = wanted - wallNormalFlat * wanted:Dot(wallNormalFlat)
                    if along.Magnitude < 0.5 then
                        lv.PlaneVelocity = Vector2.zero
                    else
                        lv.PlaneVelocity = Vector2.new(along.X, along.Z)
                    end
                else
                    lv.PlaneVelocity = Vector2.new(flat.X * speed, flat.Z * speed)
                end
            else
                lv.PlaneVelocity = Vector2.zero
            end
            if blocked then
                self._blockedTime = self._blockedTime + (dt or 0.016)
            else
                self._blockedTime = 0
            end
            if self._blockedTime > 0.35 then
                if lv.MaxForce ~= self._freeForce then lv.MaxForce = self._freeForce end
            elseif lv.MaxForce ~= self._maxForce then
                lv.MaxForce = self._maxForce
            end
        end
    elseif CarrySystem._lvBoost then
        CarrySystem._lvBoost.PlaneVelocity = Vector2.zero
        if CarrySystem._lvBoost.Enabled then CarrySystem._lvBoost.Enabled = false end
    end
end

function CarrySystem:start()
    if self._heartbeatConn then return end
    self._heartbeatConn = RunService.Heartbeat:Connect(function(dt) self:updateMovement(dt) end)
    if self.softStealEnabled then self:startSoftStealScanner() end
    print("[CarrySystem] Activado")
end

function CarrySystem:stop()
    if self._heartbeatConn then
        self._heartbeatConn:Disconnect()
        self._heartbeatConn = nil
    end
    self:stopSoftStealScanner()
    destroyLV()
    self.softStealLatched = false
    print("[CarrySystem] Desactivado")
end

local function _safeCarryNumber(value, fallback, minimum, maximum)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge then return fallback end
    return _clamp(n, minimum, maximum)
end
function CarrySystem:setNormalSpeed(v) self.normalSpeed = _safeCarryNumber(v, self.normalSpeed, 1, 500) end
function CarrySystem:setCarrySpeed(v) self.carrySpeed = _safeCarryNumber(v, self.carrySpeed, 1, 500) end
function CarrySystem:setLaggerSpeed(v) self.laggerSpeed = _safeCarryNumber(v, self.laggerSpeed, 0.1, 500) end
function CarrySystem:setLaggerCarrySpeed(v) self.laggerCarrySpeed = _safeCarryNumber(v, self.laggerCarrySpeed, 0.1, 500) end
function CarrySystem:setSoftStealSpeed(v) self.softStealSpeed = _safeCarryNumber(v, self.softStealSpeed, 1, 500) end
function CarrySystem:setSoftStealRadius(v) self.softStealRadius = _safeCarryNumber(v, self.softStealRadius, 1, 200) end

function CarrySystem:toggleCarryMode() self.speedToggled = not self.speedToggled end
function CarrySystem:setLaggerMode(mode)
    if mode == 0 then self.laggerMode = 0
    elseif mode == 1 then self.laggerMode = 1
    elseif mode == 2 then self.laggerMode = 2 end
end
function CarrySystem:toggleLaggerMode()
    if self.laggerMode == 0 then self.laggerMode = 1
    elseif self.laggerMode == 1 then self.laggerMode = 2
    else self.laggerMode = 0 end
end
function CarrySystem:setSoftStealEnabled(enabled)
    self.softStealEnabled = enabled
    if enabled then self:startSoftStealScanner()
    else self:stopSoftStealScanner(); self.softStealLatched = false end
end
function CarrySystem:toggleSoftSteal() self:setSoftStealEnabled(not self.softStealEnabled) end
function CarrySystem:isRunning() return self._heartbeatConn ~= nil end
function CarrySystem:getCurrentSpeed() return self:getActiveSpeed() end

-- ShoxHub V29 safe stability audit; monochrome palette. Legacy theme names remain loadable,
-- but every saved theme resolves to the requested black/white appearance.
local MONO = Color3.fromRGB(245, 245, 245)
local COLOR_THEMES = {
    ["Monochrome"] = MONO,
    ["Black"] = MONO, ["White"] = MONO,
    ["Blue"] = MONO, ["Lava"] = MONO, ["Neutral"] = MONO,
}

currentColorTheme = "Monochrome"
selectedColor = MONO
local function normalizeShoxTheme(name)
    return "Monochrome"
end

function getThemeColor() return selectedColor end

local _lastThemeUpdate = 0
local espHighlightCache, espBillboardCache, espTracerCache = {}, {}, {}
local _lastThemeColor = nil

function applyColorTheme(themeName)
    local color = COLOR_THEMES[themeName]
    if not color then return end
    currentColorTheme = themeName
    selectedColor = color
    updateAllUIThemeColors(color)
    saveAllSettings()
end

function updateAllUIThemeColors(color)
    local now = _tick()
    if color == _lastThemeColor and now - _lastThemeUpdate < 0.1 then return end
    local oldColor = _lastThemeColor
    _lastThemeUpdate = now
    _lastThemeColor = color

    if progressFill then
        progressFill.BackgroundColor3 = color
        local fs = progressFill:FindFirstChild("FillStroke")
        if fs then fs.Color = color end
        local grad = progressFill:FindFirstChildOfClass("UIGradient")
        if grad then
            grad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, color:Lerp(Color3.new(1,1,1), 0.25)),
                ColorSequenceKeypoint.new(0.50, color),
                ColorSequenceKeypoint.new(1.00, color:Lerp(Color3.new(1,1,1), 0.55)),
            })
        end
    end
    if pbFrame then
        local pr = pbFrame:FindFirstChild("ProgressRow")
        if pr then
            local fr = pr:FindFirstChild("FillRegion")
            if fr then
                local s = fr:FindFirstChild("FillRegionStroke")
                if s then s.Color = color end
            end
        end
        local discordLabel = pbFrame:FindFirstChild("DiscordLabel")
        if discordLabel then discordLabel.TextColor3 = color end
        local fpsNeon = pbFrame:FindFirstChild("FPSNeon")
        if fpsNeon then fpsNeon.TextColor3 = color end
    end
    local function searchAndUpdateText(parent)
        for _, child in ipairs(parent:GetDescendants()) do
            if child:IsA("TextLabel") then
                if child.Text:find("discord.gg", 1, true) or child.Text:find("Spd:", 1, true) or child.Name == "DiscordText" or
                   child.Name == "FictionHubSpeedIndicator" or child.Text:find("FPS") or child.Text:find("speed") then
                    child.TextColor3 = color
                end
            end
            if child:IsA("UIStroke") then
                if oldColor and child.Color == oldColor then child.Color = color end
            elseif child:IsA("Frame") or child:IsA("TextButton") or child:IsA("ImageButton") then
                local old = child.BackgroundColor3
                if (oldColor and old == oldColor) or old == Color3.fromRGB(120, 120, 130) then
                    child.BackgroundColor3 = color
                end
                if child:IsA("TextButton") then
                    if oldColor and child.TextColor3 == oldColor then child.TextColor3 = color end
                end
            end
        end
    end
    if gui then searchAndUpdateText(gui) end
    if batV2FloatingButton then
        paintFloatingBtn(batV2FloatingButton:FindFirstChild("Frame"), autoBatV2Enabled)
    end
    for _, tab in ipairs(tabButtons or {}) do
        if tab and tab.Parent and oldColor and tab.TextColor3 == oldColor then tab.TextColor3 = color end
    end
    for _, hl in pairs(espHighlightCache) do
        if hl then hl.FillColor = color; hl.OutlineColor = color end
    end
    for _, lines in pairs(espTracerCache) do
        if lines then
            for _, ln in ipairs(lines) do
                if ln then ln.Color = color end
            end
        end
    end
    for _, bb in pairs(espBillboardCache) do
        if bb then
            local img = bb:FindFirstChildOfClass("ImageLabel")
            if img then
                local stroke = img:FindFirstChildOfClass("UIStroke")
                if stroke then stroke.Color = color end
            end
        end
    end
    if main then
        local titleFrame = main:FindFirstChild("TitleFrame")
        if titleFrame then
            for _, child in ipairs(titleFrame:GetDescendants()) do
                if child:IsA("UIStroke") and child.Color == color then
                    child.Color = color
                end
            end
        end
    end
    if miniBtn then
        miniBtn.TextColor3 = color
    end

    local pGui = LP:FindFirstChild("PlayerGui")
    if pGui then
        local bb = pGui:FindFirstChild("RagCountdownBillboard")
        if bb then
            local lbl = bb:FindFirstChildOfClass("TextLabel")
            if lbl then
                lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
                local grad = lbl:FindFirstChildOfClass("UIGradient")
                if grad then
                    grad.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 200, 210)),
                        ColorSequenceKeypoint.new(0.3, Color3.new(1, 1, 1)),
                        ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
                        ColorSequenceKeypoint.new(0.7, Color3.new(1, 1, 1)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 210)),
                    })
                end
            end
        end
    end

    if MobilePanel then
        local container = MobilePanel:FindFirstChild("FloatingPanel")
        if container then
            local btnContainer = container:FindFirstChild("ButtonsContainer")
            if btnContainer then
                for _, btn in ipairs(btnContainer:GetChildren()) do
                    if btn:IsA("TextButton") and btn:FindFirstChild("BtnGrad") then
                        paintFloatingBtn(btn, btn:GetAttribute("MobActive") == true)
                    end
                end
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- OUTFITS
-- ═══════════════════════════════════════════════════════════════
local ECLIPSE_SKIN_PRESETS = {
    V1 = { shirt = 74707712629633, pants = 12405320750, hair = 140188532534398 },
    V2 = { shirt = 101796619834594, pants = 18975891159, hair = 115520061093937 },
    V3 = { shirt = 18552805597,   pants = 5414143509,  hair = 84008082880128  },
}

local function eclipseAssetUrl(id)
    return "http://www.roblox.com/asset/?id=" .. tostring(id)
end

local TAG = "LocalOutfit_"

local function loadObjects(id)
    local ok, res = pcall(function()
        return game:GetObjects("rbxassetid://" .. tostring(id))
    end)
    if ok and typeof(res) == "table" and #res > 0 then return res end
    ok, res = pcall(function()
        return game:GetService("InsertService"):LoadAsset(id)
    end)
    if ok and res then return { res } end
    return nil
end

local function collectParts(objs)
    local out = {}
    for _, o in ipairs(objs) do
        if o:IsA("BasePart") then out[#out + 1] = o end
        for _, d in ipairs(o:GetDescendants()) do
            if d:IsA("BasePart") then out[#out + 1] = d end
        end
    end
    return out
end

local function findAtt(char, name)
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("Attachment") and p.Name == name and p.Parent:IsA("BasePart") then
            return p
        end
    end
end

local _shoxOriginalAccessoryTransparency = setmetatable({}, {__mode = "k"})
local function restoreNoOutfitAccessoryTransparency(char)
    if not char then return end
    for accessory, transparency in pairs(_shoxOriginalAccessoryTransparency) do
        if accessory and accessory.Parent == char then
            local handle = accessory:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") and transparency ~= nil then
                pcall(function() handle.Transparency = transparency end)
            end
            _shoxOriginalAccessoryTransparency[accessory] = nil
        end
    end
end

local function applyNoOutfit(char)
    if not char then char = LP.Character end
    if not char then return end
    for _, d in ipairs(char:GetChildren()) do
        if d.Name:sub(1, #TAG) == TAG then pcall(function() d:Destroy() end) end
    end
    local oldAcc = char:FindFirstChild("AuFfitAccessory")
    if oldAcc then pcall(function() oldAcc:Destroy() end) end
    local oldKorblox = char:FindFirstChild("Korblox_RightLeg")
    if oldKorblox then pcall(function() oldKorblox:Destroy() end) end
    for _, d in ipairs(char:GetChildren()) do
        if d:IsA("CharacterMesh") and d.BodyPart == Enum.BodyPart.Head then
            pcall(function() d:Destroy() end)
        end
    end
    local head = char:FindFirstChild("Head")
    if head then
        head.Transparency = 0
        head.CanCollide = true
        head.LocalTransparencyModifier = 0
        local face = head:FindFirstChild("face")
        if face then face.Transparency = 0 end
        local sm = head:FindFirstChildWhichIsA("SpecialMesh")
        if sm then pcall(function() sm:Destroy() end) end
    end
    pcall(function()
        local neck = char:FindFirstChild("Neck")
        if neck then neck.Enabled = true end
    end)
    for _, partName in ipairs({"RightUpperLeg", "RightLowerLeg", "RightFoot"}) do
        local limb = char:FindFirstChild(partName)
        if limb then limb.Transparency = 0 end
    end
    local shirt = char:FindFirstChildWhichIsA("Shirt")
    if shirt then pcall(function() shirt:Destroy() end) end
    local pants = char:FindFirstChildWhichIsA("Pants")
    if pants then pcall(function() pants:Destroy() end) end
    for _, a in ipairs(char:GetChildren()) do
        if a:IsA("Accessory") then
            local h = a:FindFirstChild("Handle")
            if h and h:IsA("BasePart") then
                if _shoxOriginalAccessoryTransparency[a] == nil then
                    _shoxOriginalAccessoryTransparency[a] = h.Transparency
                end
                h.Transparency = 0
            end
        end
    end
end

local OUTFITS = {
    {
        accessory = 10159600649,
        offset = _V3new(0, 1, -0.2),
        shirt = "http://www.roblox.com/asset/?id=9683332638",
        pants = "http://www.roblox.com/asset/?id=93182020184041",
        headMesh = "http://www.roblox.com/asset/?id=134079402",
        headTexture = "http://www.roblox.com/asset/?id=133940918",
        korblox = "none",
        label = "Outfit 1",
        headlessKorblox = true,
    },
    {
        accessory = 1744060292,
        offset = _V3new(0, 1.3, -0.2),
        shirt = "http://www.roblox.com/asset/?id=9683332638",
        pants = "http://www.roblox.com/asset/?id=93182020184041",
        headMesh = "http://www.roblox.com/asset/?id=134079402",
        headTexture = "http://www.roblox.com/asset/?id=133940918",
        korblox = "none",
        label = "Outfit 2",
        headlessKorblox = true,
    },
    {
        accessory = 121097973925756,
        offset = _V3new(0, 0.9, 0),
        shirt = eclipseAssetUrl(ECLIPSE_SKIN_PRESETS.V1.shirt),
        pants = eclipseAssetUrl(ECLIPSE_SKIN_PRESETS.V1.pants),
        headMesh = "http://www.roblox.com/asset/?id=134079402",
        headTexture = "http://www.roblox.com/asset/?id=133940918",
        korblox = "none",
        label = "Eclipse V1",
        headlessKorblox = true,
    },
    {
        accessory = 10159600649,
        offset = _V3new(0, 1, -0.2),
        shirt = eclipseAssetUrl(ECLIPSE_SKIN_PRESETS.V2.shirt),
        pants = eclipseAssetUrl(ECLIPSE_SKIN_PRESETS.V2.pants),
        headMesh = "http://www.roblox.com/asset/?id=134079402",
        headTexture = "http://www.roblox.com/asset/?id=133940918",
        korblox = "none",
        label = "Eclipse V2",
        headlessKorblox = true,
    },
    {
        accessory = 1744060292,
        offset = _V3new(0, 1.3, -0.2),
        shirt = eclipseAssetUrl(ECLIPSE_SKIN_PRESETS.V3.shirt),
        pants = eclipseAssetUrl(ECLIPSE_SKIN_PRESETS.V3.pants),
        headMesh = "http://www.roblox.com/asset/?id=134079402",
        headTexture = "http://www.roblox.com/asset/?id=133940918",
        korblox = "none",
        label = "Eclipse V3",
        headlessKorblox = true,
    },
    {
        label = "NO",
        customApply = applyNoOutfit,
    },
}
local currentOutfitIndex = 1
local outfitSelectorLabel = nil

BACKGROUND_IMAGES = {
    { label = "Off",  id = nil },
    { label = "BG 1",  id = "rbxassetid://77785523954153" },
    { label = "BG 2",  id = "rbxassetid://122815453745063" },
    { label = "BG 3",  id = "rbxassetid://77581705786454" },
    { label = "BG 4",  id = "rbxassetid://86508089972764" },
    { label = "BG 5",  id = "rbxassetid://99747773532595" },
    { label = "BG 6",  id = "rbxassetid://139362780018712" },
    { label = "BG 7",  id = "rbxassetid://81570223894096" },
    { label = "BG 8",  id = "rbxassetid://94047991986188" },
    { label = "BG 9",  id = "rbxassetid://118783198922289" },
    { label = "BG 10", id = "rbxassetid://101833990704596" },
    { label = "BG 11", id = "rbxassetid://109527418380162" },
}
backgroundSelectorLabel = nil
backgroundImage = nil
backgroundImagePB = nil

function applyBackground(index)
    backgroundIndex = _clamp(index or 1, 1, #BACKGROUND_IMAGES)
    local cfg = BACKGROUND_IMAGES[backgroundIndex]
    if not cfg then return end
    local targetImg = cfg.id or ""
    local targetTrans = cfg.id and backgroundImageTransparency or 1
    if backgroundImage and backgroundImage.Parent then
        backgroundImage.Image = targetImg
        backgroundImage.ImageTransparency = targetTrans
    end
    if backgroundImagePB and backgroundImagePB.Parent then
        backgroundImagePB.Image = targetImg
        backgroundImagePB.ImageTransparency = targetImg ~= "" and math.min(targetTrans + 0.15, 1) or 1
    end
    if backgroundSelectorLabel then
        backgroundSelectorLabel.Text = cfg.label
    end
end

local function loadObjectsStd(id)
    local ok, res = pcall(function() return game:GetObjects("rbxassetid://" .. tostring(id)) end)
    if ok and typeof(res) == "table" and #res > 0 then return res end
    ok, res = pcall(function() return game:GetService("InsertService"):LoadAsset(id) end)
    if ok and res then return {res} end
    return nil
end

local function applyHeadlessKorblox(char)
    if not char then return end
    pcall(function() LP.CharacterAvatarType = Enum.AvatarType.R6 end)
    local head = char:FindFirstChild("Head")
    if head then
        head.Transparency = 1
        head.CanCollide = false
        head.LocalTransparencyModifier = 1
        local face = head:FindFirstChild("face")
        if face then face.Transparency = 1 end
    end
    pcall(function()
        local neck = char:FindFirstChild("Neck")
        if neck then neck.Enabled = false end
    end)
    for _, v in pairs(char:GetChildren()) do
        if v:IsA("Accessory") then
            local w = v:FindFirstChildWhichIsA("Weld") or v:FindFirstChildWhichIsA("WeldConstraint") or v:FindFirstChildWhichIsA("Motor6D")
            if w then
                local p0, p1 = w.Part0, w.Part1
                if (p0 and p0.Name == "Head") or (p1 and p1.Name == "Head") then
                    v:Destroy()
                end
            end
        end
    end
    local rightLegConfig = {
        id = "rbxassetid://139607718",
        targetBodyPart = "RightUpperLeg",
        partsToHide = {"RightUpperLeg", "RightLowerLeg", "RightFoot"},
        scale = _V3new(1, 1, 1),
        offset = _CFnew(0, 0, 0)
    }
    local targetPart = char:FindFirstChild(rightLegConfig.targetBodyPart)
    if targetPart then
        local oldAsset = char:FindFirstChild("Korblox_RightLeg")
        if oldAsset then oldAsset:Destroy() end
        local success, objects = pcall(function() return game:GetObjects(rightLegConfig.id) end)
        if success and objects and #objects > 0 then
            local assetModel = objects[1]
            assetModel.Name = "Korblox_RightLeg"
            local mainMesh = assetModel:IsA("BasePart") and assetModel or assetModel:FindFirstChildWhichIsA("BasePart", true)
            if mainMesh then
                mainMesh.Size = mainMesh.Size * rightLegConfig.scale
                mainMesh.CanCollide = false
                mainMesh.CFrame = targetPart.CFrame * rightLegConfig.offset
                local weld = Instance.new("WeldConstraint")
                weld.Part0 = targetPart
                weld.Part1 = mainMesh
                weld.Parent = mainMesh
                assetModel.Parent = char
                for _, partName in ipairs(rightLegConfig.partsToHide) do
                    local limb = char:FindFirstChild(partName)
                    if limb and limb:IsA("BasePart") then limb.Transparency = 1 end
                end
            else
                pcall(function() assetModel:Destroy() end)
            end
        end
    end
end

function applyOutfitByIndex(index)
    local cfg = OUTFITS[index]
    if not cfg then return end
    local char = LP.Character
    if not char then return end
    if index ~= #OUTFITS then restoreNoOutfitAccessoryTransparency(char) end
    if cfg.customApply then
        cfg.customApply(char)
        if outfitSelectorLabel then outfitSelectorLabel.Text = cfg.label end
        return
    end
    char:WaitForChild("Head", 5)
    local head = char:FindFirstChild("Head")
    if not head then return end
    for _, d in ipairs(char:GetChildren()) do
        if d:IsA("CharacterMesh") and d.BodyPart == Enum.BodyPart.Head then
            pcall(function() d:Destroy() end)
        end
    end
    local done = false
    if head:IsA("MeshPart") then
        done = pcall(function()
            head.MeshId = cfg.headMesh
            if cfg.headTexture then head.TextureID = cfg.headTexture end
        end)
    end
    if not done then
        local sm = head:FindFirstChildWhichIsA("SpecialMesh") or Instance.new("SpecialMesh")
        sm.Parent = head
        sm.MeshType = Enum.MeshType.FileMesh
        sm.MeshId = cfg.headMesh
        sm.TextureId = cfg.headTexture or ""
    end
    if cfg.shirt then
        local s = char:FindFirstChildWhichIsA("Shirt") or Instance.new("Shirt")
        s.Name = "Shirt"
        s.ShirtTemplate = cfg.shirt
        s.Parent = char
    end
    if cfg.pants then
        local p = char:FindFirstChildWhichIsA("Pants") or Instance.new("Pants")
        p.Name = "Pants"
        p.PantsTemplate = cfg.pants
        p.Parent = char
    end
    local old = char:FindFirstChild("AuFfitAccessory")
    if old then old:Destroy() end
    if cfg.accessory and head then
        local objs = loadObjectsStd(cfg.accessory)
        if objs then
            local handle
            for _, o in ipairs(objs) do
                if o:IsA("BasePart") then handle = o; break end
                local f = o:FindFirstChildWhichIsA("BasePart", true)
                if f then handle = f; break end
            end
            if handle then
                local h = handle:Clone()
                h.Name = "AuFfitAccessory"
                h.CanCollide = false
                h.Anchored = false
                h.Massless = true
                h.Parent = char
                local weld = Instance.new("Weld")
                weld.Part0 = head
                weld.Part1 = h
                weld.C0 = _CFnew(cfg.offset)
                weld.Parent = h
            end
            for _, o in ipairs(objs) do pcall(function() o:Destroy() end) end
        end
    end
    if cfg.headlessKorblox then
        applyHeadlessKorblox(char)
    else
        if char then
            local head2 = char:FindFirstChild("Head")
            if head2 then
                head2.Transparency = 0
                head2.CanCollide = true
                head2.LocalTransparencyModifier = 0
                local face2 = head2:FindFirstChild("face")
                if face2 then face2.Transparency = 0 end
            end
            pcall(function()
                local neck = char:FindFirstChild("Neck")
                if neck then neck.Enabled = true end
            end)
            for _, partName in ipairs({"RightUpperLeg", "RightLowerLeg", "RightFoot"}) do
                local limb = char:FindFirstChild(partName)
                if limb then limb.Transparency = 0 end
            end
            local oldKorblox = char:FindFirstChild("Korblox_RightLeg")
            if oldKorblox then oldKorblox:Destroy() end
        end
    end
    if outfitSelectorLabel then outfitSelectorLabel.Text = cfg.label end
end

speedMode = false
antiRagdollMode = "off"
antiDieEnabled = false
antiFlingEnabled = false
jumpEnabled = false
laggerToggled = false
laggerCarryToggled = false
medusaCounterEnabled = false
batCounterEnabled = false
unwalkEnabled = false
autoLeftEnabled = false
autoRightEnabled = false
autoBatEnabled = false
dropMode = 1
antiLagEnabled = false
removeAccessoriesEnabled = false
stretchEnabled = false
stretchFOV = 120
uiLocked = false
editModeEnabled = false
mobileButtonsLocked = false
uiScaleValue = 78
espEnabled = false

antiKickEnabled = false
setSafeModeVisual = nil

mirrorTPDownEnabled = false
mirrorTPDownSetVisual = nil

infJumpEnabled = false
infJumpMode    = "HOLD"

bodyLockEnabled = false
bodyLockRange = 20
bodyLockRangeBox = nil
local bodyLockSetVisual = nil
_bodyLockConn = nil
_blSuppressCount = 0
_blWasEnabled = false
_blRestoreTimer = nil

savedProgressBarPos = nil
savedButtonPositions = {}
savedMobilePanelPos = nil
batV2FloatingPos = nil
instaResetFloatingPos = nil
instaResetFloatingButton = nil

neonWeatherEnabled = false
skyTheme = "Off"
skySelectorLabel = nil
_originalLighting = nil
_neonCreatedColorCorrection = nil
_neonCreatedBloom = nil
setNeonWeatherVisual = nil

currentAnimPack = "Off"
originalTryardAnims = nil
tryardHeartbeatConn = nil
animSelectorLabel = nil

-- ═══════════════════════════════════════════════════════════════
-- BAT BYPASS (antes Anti Bypass Aimbot) — Persecución con predicción de ping
-- ═══════════════════════════════════════════════════════════════
autoBatV2Enabled      = false
autoBatV2SetVisual    = nil

selectedAimbotMode    = "Normal"
autoSwingEnabled      = false

_G.AceAntiBypassAimbotSpeed       = _G.AceAntiBypassAimbotSpeed or 60
_G.AceAntiBypassLaggerAimbotSpeed = _G.AceAntiBypassLaggerAimbotSpeed or 40
_G.AceAntiBypassAimbotOn          = _G.AceAntiBypassAimbotOn or false
_G.AceNormalAimbotOn              = _G.AceNormalAimbotOn or false
_G.AceCurrentSpeedMode            = _G.AceCurrentSpeedMode or "Normal"



_G.AceAntiBypassSlapList = _G.AceAntiBypassSlapList or {
    "Bat", "Slap", "Iron Slap", "Gold Slap", "Diamond Slap",
    "Emerald Slap", "Ruby Slap", "Dark Matter Slap",
    "Flame Slap", "Nuclear Slap", "Galaxy Slap", "Glitched Slap"
}

-- Resolve the Safe Mode function at call time; its implementation is defined later.
_G.AceSafeModeTryStart = function(...)
    local safeModeStart = _G.AmbitiousSafeModeTryStart
    if type(safeModeStart) ~= "function" then return false end
    return safeModeStart(...)
end
_G.AceStopAutoTPForAction   = _G.AceStopAutoTPForAction   or function()
    if batDesyncTpEnabled and type(stopBatDesyncTp) == "function" then
        stopBatDesyncTp()
    end
end
_G.AceStopNormalAimbot      = _G.AceStopNormalAimbot      or function()
    if autoBatEnabled and type(disableAutoBat) == "function" then
        disableAutoBat()
    end
end

useCarrySystem = false
lastMoveDir = _V3zero

-- TP Bat legacy vars (compat)
tpBatVersion = 1
tpBatVersionLabel = nil
tpBatVersionPill = nil
tpBatDistanceBox = nil
_G.__tpBatV2Distance = 8

local CoreGui = game:GetService("CoreGui")

katanaSkinEnabled = false

local KatanaSkin = (function()
    local Players       = game:GetService("Players")
    local InsertService = game:GetService("InsertService")
    local Lighting2     = game:GetService("Lighting")
    local ReplicatedStorage2 = game:GetService("ReplicatedStorage")
    local LocalPlayer   = Players.LocalPlayer

    local KC = {
        red  = Color3.new(0.784314, 0, 0),
        red2 = Color3.new(1, 0.392157, 0.392157),
        gold = Color3.new(1, 0.72549, 0.196078),
    }

    local State = {
        Skin = "KATANA",
        SkinOrder = { "KATANA", "NONE" },
        LastBat = nil,
        LastAppliedSkin = nil,
        OriginalKatanaTemplate = nil,
        ExactTemplates = {},
        ExactTemplateSearched = {},
        ExactAssetIds = { KATANA = "" },
        Original = {},
    }

    local function findBatForKatanaSkin()
        local char = LocalPlayer.Character
        if char then
            local t = char:FindFirstChild("Bat")
            if t and t:IsA("Tool") then return t end
        end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp then
            local t = bp:FindFirstChild("Bat")
            if t and t:IsA("Tool") then return t end
        end
        return nil
    end

    local function setPartSafe(part)
        if not part or not part:IsA("BasePart") then return end
        part.Anchored    = false
        part.CanCollide  = false
        part.CanTouch    = false
        part.CanQuery    = false
        part.Massless    = true
    end

    local function weldToHandle(part, handle)
        if not part or not handle or not part:IsA("BasePart") or not handle:IsA("BasePart") then return end
        setPartSafe(part)
        local w = Instance.new("WeldConstraint")
        w.Name   = "FlowerSkin_AssetWeld"
        w.Part0  = handle
        w.Part1  = part
        w.Parent = part
    end

    local function rememberOriginal(tool)
        if not tool then return end
        local handle = tool:FindFirstChild("Handle")
        local slash  = tool:FindFirstChild("Slash")
        State.Original[tool] = State.Original[tool] or {}
        local o = State.Original[tool]
        if handle and handle:IsA("BasePart") and not o.Handle then
            o.Handle = {
                Transparency = handle.Transparency,
                LocalTransparencyModifier = handle.LocalTransparencyModifier,
                CastShadow = handle.CastShadow,
            }
        end
        if slash and slash:IsA("Sound") and not o.SlashSoundId then
            o.SlashSoundId = slash.SoundId
        end
    end

    local function captureKatanaTemplate()
        if State.OriginalKatanaTemplate then return end
        local function scan(container)
            if not container then return end
            local bat = container:FindFirstChild("Bat")
            if not bat then return end
            local folder = bat:FindFirstChild("FlowerSkin_KatanaRealistic")
            local asset  = folder and folder:FindFirstChild("FlowerSkin_AssetKatana")
            if asset then State.OriginalKatanaTemplate = asset:Clone() end
        end
        scan(LocalPlayer:FindFirstChildOfClass("Backpack"))
        scan(LocalPlayer.Character)
    end

    local function hideOriginalHandle(tool, hidden)
        local handle = tool and tool:FindFirstChild("Handle")
        if not handle or not handle:IsA("BasePart") then return end
        rememberOriginal(tool)
        if hidden then
            handle.LocalTransparencyModifier = 1
            handle.Transparency = 1
            handle.CastShadow = false
        else
            local o = State.Original[tool] and State.Original[tool].Handle
            handle.LocalTransparencyModifier = o and o.LocalTransparencyModifier or 0
            handle.Transparency = o and o.Transparency or 0
            handle.CastShadow = o and o.CastShadow
            if handle.CastShadow == nil then handle.CastShadow = true end
        end
    end

    local function setSlashSound(tool, soundId)
        rememberOriginal(tool)
        local slash = tool and tool:FindFirstChild("Slash")
        if slash and slash:IsA("Sound") then
            slash.SoundId = soundId or ((State.Original[tool] and State.Original[tool].SlashSoundId) or slash.SoundId)
        end
    end

    local function removeSkin(tool)
        if not tool then return end
        local oldFolder = tool:FindFirstChild("FlowerSkin_KatanaRealistic")
        if oldFolder then oldFolder:Destroy() end
        local oldLoose = tool:FindFirstChild("FlowerSkin_AssetKatana")
        if oldLoose then oldLoose:Destroy() end
        hideOriginalHandle(tool, false)
        setSlashSound(tool, nil)
    end

    local function addRedVFX(parentPart)
        if not parentPart or not parentPart:IsA("BasePart") then return end
        local existing = parentPart:FindFirstChild("FlowerSkin_ExtraRedVFX")
        if existing then existing:Destroy() end

        local top = Instance.new("Attachment")
        top.Name = "FlowerSkin_ExtraRedVFX"
        top.Position = Vector3.new(0, parentPart.Size.Y * 0.5, 0)
        top.Parent = parentPart

        local bottom = Instance.new("Attachment")
        bottom.Name = "FlowerSkin_ExtraRedVFX_End"
        bottom.Position = Vector3.new(0, -parentPart.Size.Y * 0.5, 0)
        bottom.Parent = parentPart

        local trail = Instance.new("Trail")
        trail.Name = "FlowerSkin_ExtraRedVFX"
        trail.Attachment0 = top
        trail.Attachment1 = bottom
        trail.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, KC.red2),
            ColorSequenceKeypoint.new(1, Color3.new(0.54902, 0, 0)),
        })
        trail.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.35),
            NumberSequenceKeypoint.new(1, 1),
        })
        trail.Lifetime = 0.18
        trail.LightEmission = 0.55
        trail.Parent = parentPart

        local emitter = Instance.new("ParticleEmitter")
        emitter.Name = "FlowerSkin_ExtraRedVFX"
        emitter.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(0.784314, 0, 0)),
            ColorSequenceKeypoint.new(1, KC.red2),
        })
        emitter.LightEmission = 0.55
        emitter.Rate = 14
        emitter.Lifetime = NumberRange.new(0.25, 0.45)
        emitter.Speed = NumberRange.new(0.2, 0.7)
        emitter.SpreadAngle = Vector2.new(12, 12)
        emitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.08),
            NumberSequenceKeypoint.new(1, 0),
        })
        emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        emitter.Parent = parentPart
    end

    local function newPart(parent, name, size, offset, color, material)
        local p = Instance.new("Part")
        p.Name = name
        p.Size = size
        p.Color = color
        p.Material = material or Enum.Material.Neon
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        setPartSafe(p)
        p.Parent = parent
        return p, offset or CFrame.identity
    end

    local EXACT_TEMPLATE_NAMES = {
        KATANA = { "FlowerSkin_AssetKatana", "Katana", "FlowerSkin_KatanaRealistic" },
    }

    local function isScriptObject(inst)
        return inst:IsA("Script") or inst:IsA("LocalScript") or inst:IsA("ModuleScript")
    end

    local function stripScripts(root)
        if not root then return end
        if isScriptObject(root) then root:Destroy(); return end
        for _, inst in ipairs(root:GetDescendants()) do
            if isScriptObject(inst) then inst:Destroy() end
        end
    end

    local function hasAnyBasePart(root)
        if not root then return false end
        if root:IsA("BasePart") then return true end
        return root:FindFirstChildWhichIsA("BasePart", true) ~= nil
    end

    local function isGeneratedProxy(root)
        local ok, v = pcall(function() return root:GetAttribute("CursedBatSkinsGenerated") end)
        return ok and v == true
    end

    local function usableTemplate(root)
        if not root or isGeneratedProxy(root) then return nil end
        if root:IsA("Model") or root:IsA("Tool") or root:IsA("Folder") or root:IsA("BasePart") then
            if hasAnyBasePart(root) then return root end
        end
        return nil
    end

    local function findUsableNamed(root, names)
        if not root then return nil end
        for _, name in ipairs(names) do
            if root.Name == name then
                local d = usableTemplate(root)
                if d then return d end
            end
        end
        for _, name in ipairs(names) do
            local found = root:FindFirstChild(name, true)
            local u = usableTemplate(found)
            if u then return u end
        end
        return nil
    end

    local function assetTextFromId(assetId)
        local raw = tostring(assetId or ""):gsub("%s+", "")
        if raw == "" then return nil end
        if raw:match("^rbxassetid://") or raw:match("^rbxasset://") then return raw end
        if raw:match("^%d+$") then return "rbxassetid://" .. raw end
        return raw
    end

    local function loadExactTemplateFromAssetId(skinName)
        local assetText = assetTextFromId(State.ExactAssetIds[skinName])
        if not assetText then return nil end
        local loaded = {}
        pcall(function() loaded = game:GetObjects(assetText) end)
        if #loaded == 0 then
            local id = tostring(assetText):match("(%d+)")
            if id then
                pcall(function()
                    table.insert(loaded, InsertService:LoadAsset(tonumber(id)))
                end)
            end
        end
        local names = EXACT_TEMPLATE_NAMES[skinName] or {}
        for _, root in ipairs(loaded) do
            local exact = findUsableNamed(root, names) or usableTemplate(root)
            if exact then
                local clone = exact:Clone()
                stripScripts(clone)
                return clone
            end
        end
        return nil
    end

    local function findExactTemplateInGame(skinName)
        local names = EXACT_TEMPLATE_NAMES[skinName]
        if not names then return nil end
        local containers = {
            LocalPlayer.Character,
            LocalPlayer:FindFirstChildOfClass("Backpack"),
            ReplicatedStorage2,
            Lighting2,
            workspace,
        }
        for _, container in ipairs(containers) do
            local source = findUsableNamed(container, names)
            if source then
                local clone = source:Clone()
                stripScripts(clone)
                return clone
            end
        end
        return nil
    end

    local function getExactTemplate(skinName)
        if skinName == "KATANA" and State.OriginalKatanaTemplate then
            return State.OriginalKatanaTemplate
        end
        if State.ExactTemplates[skinName] then return State.ExactTemplates[skinName] end
        if State.ExactTemplateSearched[skinName] then return nil end
        State.ExactTemplateSearched[skinName] = true
        local loaded = loadExactTemplateFromAssetId(skinName) or findExactTemplateInGame(skinName)
        if loaded then State.ExactTemplates[skinName] = loaded end
        return loaded
    end

    local function containerToModel(clone, folder)
        if clone:IsA("Model") then
            clone.Name = "FlowerSkin_AssetKatana"
            clone.Parent = folder
            return clone
        end
        if clone:IsA("BasePart") then
            local model = Instance.new("Model")
            model.Name = "FlowerSkin_AssetKatana"
            model.Parent = folder
            clone.Parent = model
            return model
        end
        if clone:IsA("Tool") or clone:IsA("Folder") then
            local nested = clone:FindFirstChild("FlowerSkin_AssetKatana")
                or clone:FindFirstChildWhichIsA("Model")
                or clone:FindFirstChildWhichIsA("BasePart")
            if nested and nested.Parent == clone then
                nested.Parent = nil
                clone:Destroy()
                return containerToModel(nested, folder)
            end
            local model = Instance.new("Model")
            model.Name = "FlowerSkin_AssetKatana"
            model.Parent = folder
            for _, child in ipairs(clone:GetChildren()) do
                if not isScriptObject(child) then child.Parent = model end
            end
            clone:Destroy()
            return model
        end
        return nil
    end

    local function applyExactMesh(tool, skinName)
        local handle = tool and tool:FindFirstChild("Handle")
        if not handle or not handle:IsA("BasePart") then return false end
        local template = getExactTemplate(skinName)
        if not template then return false end

        local folder = Instance.new("Folder")
        folder.Name = "FlowerSkin_KatanaRealistic"
        folder.Parent = tool

        local model = containerToModel(template:Clone(), folder)
        if not model or not hasAnyBasePart(model) then
            folder:Destroy()
            return false
        end
        stripScripts(model)
        pcall(function() model:SetAttribute("CursedBatSkinsExactMesh", true) end)

        local firstPart
        for _, inst in ipairs(model:GetDescendants()) do
            if inst:IsA("BasePart") then
                firstPart = firstPart or inst
                setPartSafe(inst)
            end
        end
        if not firstPart then folder:Destroy(); return false end

        if model:IsA("Model") then
            model.PrimaryPart = model.PrimaryPart or firstPart
            pcall(function() model:PivotTo(handle.CFrame) end)
        end
        for _, inst in ipairs(model:GetDescendants()) do
            if inst:IsA("BasePart") then weldToHandle(inst, handle) end
        end

        local vfxPart = model:FindFirstChild("SharpParts", true)
            or model:FindFirstChild("WeaponPart", true)
            or model:FindFirstChild("Handle", true)
            or firstPart
        if vfxPart and not vfxPart:FindFirstChild("FlowerSkin_ExtraRedVFX") then
            addRedVFX(vfxPart)
        end
        return true
    end

    local function buildProxyModel(tool, skinName)
        local handle = tool and tool:FindFirstChild("Handle")
        if not handle or not handle:IsA("BasePart") then return nil end

        local folder = Instance.new("Folder")
        folder.Name = "FlowerSkin_KatanaRealistic"
        folder.Parent = tool

        local model = Instance.new("Model")
        model.Name = "FlowerSkin_AssetKatana"
        model:SetAttribute("CursedBatSkinsGenerated", true)
        model.Parent = folder

        local parts = {}
        local function add(name, size, offset, color, material)
            local part, cfOffset = newPart(model, name, size, offset, color, material)
            part.CFrame = handle.CFrame * cfOffset
            weldToHandle(part, handle)
            table.insert(parts, part)
            return part
        end

        if skinName == "KATANA" then
            add("Handle2", Vector3.new(0.22, 1.0, 0.22), CFrame.new(0, -0.85, 0), Color3.new(0.04, 0.04, 0.045), Enum.Material.Metal)
            local sharp = add("SharpParts", Vector3.new(0.22, 3.35, 0.12), CFrame.new(0, 1.05, 0), KC.red2, Enum.Material.Neon)
            add("WeaponPart", Vector3.new(0.3, 2.7, 0.08), CFrame.new(0.08, 1.15, 0), KC.red, Enum.Material.Neon)
            add("NeonAccent", Vector3.new(0.75, 0.12, 0.42), CFrame.new(0, -0.28, 0), KC.gold, Enum.Material.Neon)
            addRedVFX(sharp)
        end
        model.PrimaryPart = parts[1]
        return model
    end

    local SKIN_SOUND_IDS = {
        KATANA = "rbxassetid://111808555599832",
    }

    local function applySkin(skinName)
        if skinName ~= "KATANA" and skinName ~= "NONE" then return false end
        captureKatanaTemplate()
        local tool = findBatForKatanaSkin()
        if not tool then
            -- NONE must also clean up the previously applied tool if it is
            -- temporarily outside Character/Backpack but still exists.
            local previousBat = State.LastBat
            if skinName == "NONE" and previousBat and previousBat.Parent then
                pcall(function() removeSkin(previousBat) end)
            end
            State.LastBat = nil
            State.LastAppliedSkin = nil
            return false
        end
        rememberOriginal(tool)
        removeSkin(tool)
        if skinName == "NONE" then
            State.LastBat = tool
            State.LastAppliedSkin = "NONE"
            return true
        end
        hideOriginalHandle(tool, true)
        setSlashSound(tool, SKIN_SOUND_IDS[skinName])
        if not applyExactMesh(tool, skinName) then
            buildProxyModel(tool, skinName)
        end
        local handle = tool:FindFirstChild("Handle")
        if handle then
            local fire = handle:FindFirstChildOfClass("Fire") or handle:FindFirstChild("Fire")
            if fire and fire:IsA("Fire") then
                fire.Enabled = true
                fire.Color = KC.red
                fire.SecondaryColor = KC.red2
            end
        end
        State.LastBat = tool
        State.LastAppliedSkin = skinName
        return true
    end

    return {
        State = State,
        ApplySkin = applySkin,
        SetExactAssetId = function(assetId)
            State.ExactAssetIds.KATANA = tostring(assetId or "")
            State.ExactTemplateSearched.KATANA = nil
            State.ExactTemplates.KATANA = nil
        end,
    }
end)()

_G.CursedBatKatana = KatanaSkin

task.spawn(function()
    while true do
        if katanaSkinEnabled then
            local bat
            local c = LP.Character
            if c then
                local t = c:FindFirstChild("Bat")
                if t and t:IsA("Tool") then bat = t end
            end
            if not bat then
                local bp = LP:FindFirstChildOfClass("Backpack")
                if bp then
                    local t = bp:FindFirstChild("Bat")
                    if t and t:IsA("Tool") then bat = t end
                end
            end
            if bat and (bat ~= KatanaSkin.State.LastBat or KatanaSkin.State.LastAppliedSkin ~= "KATANA") then
                pcall(function() KatanaSkin.ApplySkin("KATANA") end)
            end
        end
        task.wait(0.5)
    end
end)

minecraftBatSkinEnabled = false
minecraftBatSkinColorMode = "Default"
MinecraftBatSetVisual = nil
MinecraftBatColorSelector = nil

local MinecraftBatSkin = (function()
    local MB_ASSET_ID = "rbxassetid://18566246244"
    local MB_POS_OFFSET = _CFnew(-0.02, -0.52, -0.2)
    local MB_ROT_OFFSET = CFrame.Angles(math.rad(45), math.rad(0), math.rad(5))
    local MB_SCALE = 2

    local MB_COLORS = {
        ["Default"]       = nil,
        ["Abyss Blue"]    = Color3.fromRGB(0, 40, 150),
        ["Venom Green"]   = Color3.fromRGB(20, 255, 50),
        ["Royal Gold"]    = Color3.fromRGB(255, 200, 0),
        ["Velvet Rose"]   = Color3.fromRGB(220, 20, 100),
        ["Crimson Night"] = Color3.fromRGB(90, 0, 20),
    }

    local State = {
        enabled = false,
        colorMode = "Default",
        cachedVisualPart = nil,
        rgbConnection = nil,
    }

    local okLoad, objects = pcall(function() return game:GetObjects(MB_ASSET_ID) end)
    if okLoad and objects and #objects > 0 then
        local model = objects[1]
        State.cachedVisualPart = model:IsA("BasePart") and model
            or model:FindFirstChildWhichIsA("BasePart", true)
    end

    local function mbSetColor(visual, color)
        if not visual or not color then return end
        visual.Color = color
        if visual:IsA("UnionOperation") then
            pcall(function() visual.UsePartColor = true end)
        end
        local sm = visual:FindFirstChildWhichIsA("SpecialMesh")
        if sm then
            sm.VertexColor = Vector3.new(color.R, color.G, color.B)
        end
    end

    local function mbFindBat()
        local char = LP.Character
        if char then
            local t = char:FindFirstChild("Bat")
            if t and t:IsA("Tool") then return t end
        end
        local bp = LP:FindFirstChildOfClass("Backpack")
        if bp then
            local t = bp:FindFirstChild("Bat")
            if t and t:IsA("Tool") then return t end
        end
        return nil
    end

    local function mbRemoveVisual(tool)
        if not tool then return end
        local old = tool:FindFirstChild("CustomUnionVisual")
        if old then pcall(function() old:Destroy() end) end
        local handle = tool:FindFirstChild("Handle")
        if handle then
            handle.Transparency = 0
            for _, child in ipairs(handle:GetChildren()) do
                if child:IsA("SpecialMesh") or child:IsA("Mesh") or child:IsA("Decal") then
                    pcall(function() child.Transparency = 0 end)
                end
            end
        end
    end

    local function mbApplyVisual(tool)
        if not tool or tool.Name ~= "Bat" or not State.cachedVisualPart then return end
        local handle = tool:WaitForChild("Handle", 2)
        if not handle then return end

        local oldVisual = tool:FindFirstChild("CustomUnionVisual")
        if oldVisual then oldVisual:Destroy() end

        handle.Transparency = 1
        for _, child in ipairs(handle:GetChildren()) do
            if child:IsA("SpecialMesh") or child:IsA("Mesh") or child:IsA("Decal") then
                pcall(function() child.Transparency = 1 end)
            end
        end

        local newVisual = State.cachedVisualPart:Clone()
        newVisual.Name = "CustomUnionVisual"
        newVisual.CanCollide = false
        newVisual.Massless = true
        newVisual.Anchored = false

        local tempModel = Instance.new("Model")
        newVisual.Parent = tempModel
        tempModel.PrimaryPart = newVisual
        pcall(function() tempModel:ScaleTo(MB_SCALE) end)
        newVisual.Parent = nil
        tempModel:Destroy()

        if State.colorMode == "RGB" then
            mbSetColor(newVisual, Color3.fromHSV(tick() % 3 / 3, 1, 1))
        elseif MB_COLORS[State.colorMode] then
            mbSetColor(newVisual, MB_COLORS[State.colorMode])
        end

        for _, child in ipairs(newVisual:GetChildren()) do
            if child:IsA("Weld") or child:IsA("WeldConstraint") then child:Destroy() end
        end

        newVisual.CFrame = handle.CFrame * MB_POS_OFFSET * MB_ROT_OFFSET
        newVisual.Parent = tool

        local weld = Instance.new("WeldConstraint")
        weld.Part0 = handle
        weld.Part1 = newVisual
        weld.Parent = newVisual
    end

    local function mbStartRGB()
        if State.rgbConnection then return end
        State.rgbConnection = RunService.RenderStepped:Connect(function()
            if not State.enabled or State.colorMode ~= "RGB" then return end
            local tool = mbFindBat()
            if not tool then return end
            local visual = tool:FindFirstChild("CustomUnionVisual")
            if visual then
                mbSetColor(visual, Color3.fromHSV(tick() % 3 / 3, 1, 1))
            end
        end)
    end

    local function mbStopRGB()
        if State.rgbConnection then
            State.rgbConnection:Disconnect()
            State.rgbConnection = nil
        end
    end

    return {
        State   = State,
        Colors  = MB_COLORS,
        FindBat = mbFindBat,
        Apply   = function()
            if not State.enabled then return end
            local tool = mbFindBat()
            if tool then mbApplyVisual(tool) end
            if State.colorMode == "RGB" then mbStartRGB() end
        end,
        Remove  = function()
            mbStopRGB()
            local char = LP.Character
            if char then
                local t = char:FindFirstChild("Bat")
                if t then mbRemoveVisual(t) end
            end
            local bp = LP:FindFirstChildOfClass("Backpack")
            if bp then
                local t = bp:FindFirstChild("Bat")
                if t then mbRemoveVisual(t) end
            end
        end,
        SetColorMode = function(mode)
            State.colorMode = mode
            if not State.enabled then return end
            if mode == "RGB" then mbStartRGB() else mbStopRGB() end
            local tool = mbFindBat()
            if tool then mbApplyVisual(tool) end
        end,
    }
end)()

task.spawn(function()
    while true do
        if minecraftBatSkinEnabled then
            MinecraftBatSkin.State.enabled = true
            local tool = MinecraftBatSkin.FindBat()
            if tool and not tool:FindFirstChild("CustomUnionVisual") then
                pcall(MinecraftBatSkin.Apply)
            end
        else
            MinecraftBatSkin.State.enabled = false
        end
        task.wait(0.5)
    end
end)

_G.AmbitiousNormalInfJump = _G.AmbitiousNormalInfJump or {
    holdPressed = false, holdActive = false,
    controllerActive = false, mobilePressed = false, mobileActive = false,
    hooked = setmetatable({}, {__mode = "k"})
}
_G.AmbitiousNormalInfJump.hooked = setmetatable(_G.AmbitiousNormalInfJump.hooked or {}, {__mode = "k"})
for hookedButton in pairs(_G.AmbitiousNormalInfJump.hooked) do
    if not hookedButton or not hookedButton.Parent then _G.AmbitiousNormalInfJump.hooked[hookedButton] = nil end
end

function _G._jumpEnsureProxy()
    local char = LP.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

function _G.AmbitiousApplyNormalInfJumpBoost(boost)
    if not infJumpEnabled then return end
    local char = LP.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    local proxy = _G._jumpEnsureProxy()
    if not proxy then return end
    local curVel = proxy.Velocity
    proxy.Velocity = _V3new(curVel.X, boost or 50, curVel.Z)
end

function _G.AmbitiousStopNormalInfJumpHoldState()
    local S = _G.AmbitiousNormalInfJump
    S.holdPressed = false
    S.holdActive = false
    S.controllerActive = false
    S.mobilePressed = false
    S.mobileActive = false
end

UIS.JumpRequest:Connect(function()
    -- Roblox handles the native jump. Only add the optional boost here;
    -- never write Humanoid.Jump from a second competing input handler.
    if infJumpEnabled then
        _G.AmbitiousApplyNormalInfJumpBoost(50)
    end
end)

UIS.InputBegan:Connect(function(input)
    if UIS:GetFocusedTextBox() then return end
    local S = _G.AmbitiousNormalInfJump

    if input.UserInputType == Enum.UserInputType.Keyboard
       and input.KeyCode == Enum.KeyCode.Space then
        if infJumpMode == "MANUAL" then return end
        S.holdPressed = true
        task.delay(0.12, function()
            if _G.AmbitiousNormalInfJump.holdPressed and infJumpEnabled then
                _G.AmbitiousNormalInfJump.holdActive = true
                _G.AmbitiousApplyNormalInfJumpBoost(50)
            end
        end)
    elseif input.KeyCode == Enum.KeyCode.ButtonA
       and input.UserInputType.Name:match("^Gamepad") then
        if infJumpMode ~= "MANUAL" then S.controllerActive = true end
    end
end)

UIS.InputEnded:Connect(function(input)
    local S = _G.AmbitiousNormalInfJump
    if input.UserInputType == Enum.UserInputType.Keyboard
       and input.KeyCode == Enum.KeyCode.Space then
        S.holdPressed = false
        S.holdActive  = false
    end
    if input.KeyCode == Enum.KeyCode.ButtonA
       and input.UserInputType.Name:match("^Gamepad") then
        S.controllerActive = false
    end
end)

function _G.AmbitiousHookNormalInfMobileJumpButton(obj)
    local S = _G.AmbitiousNormalInfJump
    if not obj or obj.Name ~= "JumpButton"
       or not obj:IsA("GuiButton") or S.hooked[obj] then return end
    S.hooked[obj] = true
    -- Activated fires reliably for Roblox's built-in mobile jump button.
    obj.Activated:Connect(function()
        -- Do not take over Roblox's built-in jump action.
        if infJumpEnabled then
            _G.AmbitiousApplyNormalInfJumpBoost(50)
        end
    end)
    obj.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch
           or not infJumpEnabled then return end
        if infJumpMode == "MANUAL" then return end
        S.mobilePressed = true
        task.delay(0.12, function()
            if S.mobilePressed and infJumpEnabled then
                S.mobileActive = true
                _G.AmbitiousApplyNormalInfJumpBoost(50)
            end
        end)
    end)
    obj.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            S.mobilePressed = false
            S.mobileActive  = false
        end
    end)
end

do
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if pg then
        for _, obj in ipairs(pg:GetDescendants()) do
            _G.AmbitiousHookNormalInfMobileJumpButton(obj)
        end
        LP.ChildAdded:Connect(function(child)
            if child:IsA("PlayerGui") then
                task.defer(function()
                    for _, obj in ipairs(child:GetDescendants()) do
                        _G.AmbitiousHookNormalInfMobileJumpButton(obj)
                    end
                    child.DescendantAdded:Connect(function(obj)
                        task.defer(_G.AmbitiousHookNormalInfMobileJumpButton, obj)
                    end)
                end)
            end
        end)
        pg.DescendantAdded:Connect(function(obj)
            task.defer(_G.AmbitiousHookNormalInfMobileJumpButton, obj)
        end)
        -- v1.6.0 SH-24 Fix: Redundante 5-Sekunden-Polling-Schleife entfernt.
    end
end

RunService.Heartbeat:Connect(function()
    local S = _G.AmbitiousNormalInfJump
    if infJumpEnabled and infJumpMode == "HOLD"
       and (S.holdActive or S.mobileActive or S.controllerActive) then
        _G.AmbitiousApplyNormalInfJumpBoost(50)
    end
end)

function _G.setInfJumpInternal(on)
    infJumpEnabled = on and true or false
    if not infJumpEnabled then
        _G.AmbitiousStopNormalInfJumpHoldState()
        -- Disabling the optional boost must not cancel native jump/fall momentum.
    end
end

InfiniteJump = {
    start = function() _G.setInfJumpInternal(true)  end,
    stop  = function() _G.setInfJumpInternal(false) end,
    isRunning = function() return infJumpEnabled == true end,
    setJumpPower = function() end,
}

-- Restore Roblox's native player controls after ShoxHub initializes.
-- This does not replace the native mobile JumpButton or synthesize jump input.
local function _shoxRestoreNativeJumpControls(character)
    task.defer(function()
        pcall(function()
            local playerScripts = LP:FindFirstChild("PlayerScripts")
            local playerModule = playerScripts and playerScripts:FindFirstChild("PlayerModule")
            if playerModule then
                local controlModuleScript = playerModule:FindFirstChild("ControlModule")
                if controlModuleScript then
                    local controlModule = require(controlModuleScript)
                    if controlModule and type(controlModule.Enable) == "function" then
                        controlModule:Enable()
                    end
                end
            end
        end)

        local char = character or LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Parent and hum.Health > 0 then
            pcall(function()
                hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
            end)
            pcall(function()
                hum:SetStateEnabled(Enum.HumanoidStateType.Landed, true)
            end)
        end
    end)
end

_shoxRestoreNativeJumpControls(LP.Character)
LP.CharacterAdded:Connect(function(character)
    task.wait(0.25)
    _shoxRestoreNativeJumpControls(character)
end)

local function getCharParts()
    local char = LP.Character
    if not char then return nil, nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return nil, nil end
    return hum, root
end

local function claimOwnership(root)
    pcall(function() root:SetNetworkOwner(LP) end)
end

function getActiveMoveSpeed()
    if CarrySystem then
        return CarrySystem:getActiveSpeed()
    end
    if laggerCarryToggled then return LAGGER_CARRY_SPEED
    elseif laggerToggled then return LAGGER_SPEED
    elseif speedMode then return CS
    else return NS end
end

-- No velocity metatable hooks are installed; Roblox jump/physics velocity stays native.

local function _isRagdollState(hum)
    if not hum then return true end
    local st = hum:GetState()
    return hum.PlatformStand
        or st == Enum.HumanoidStateType.Physics
        or st == Enum.HumanoidStateType.Ragdoll
        or st == Enum.HumanoidStateType.FallingDown
end

local function _applyVelocitySpeed(dir, speed, hrp)
    if not hrp or not hrp.Parent then return end
    if tick() < _globalMovementLock then return end
    if autoBatV2Enabled or batDesyncTpEnabled or autoBatEnabled then return end
    if dir and dir.Magnitude > 0.05 then
        pcall(function()
            if hrp.SetNetworkOwner then hrp:SetNetworkOwner(LP) end
        end)
        local unit = dir.Unit
        local vy = hrp.AssemblyLinearVelocity.Y
        hrp.AssemblyLinearVelocity = _V3new(unit.X * speed, vy, unit.Z * speed)
    else
        local vy = hrp.AssemblyLinearVelocity.Y
        hrp.AssemblyLinearVelocity = _V3new(0, vy, 0)
    end
end

function getAutoPathSpeed()
    -- Auto Left/Right are normal-speed automation; Lagger is a separate manual mode.
    return NS
end

ANIM_PACKS = {
    ["Zombie"] = { idle1="rbxassetid://616158929", idle2="rbxassetid://616160636", walk="rbxassetid://616168032", run="rbxassetid://616163682", jump="rbxassetid://616161997", fall="rbxassetid://616157476", climb="rbxassetid://616156119", swim="rbxassetid://616165109", swimidle="rbxassetid://616166655" },
    ["Ninja"] = { idle1="rbxassetid://656117400", idle2="rbxassetid://656117400", walk="rbxassetid://656121766", run="rbxassetid://656118852", jump="rbxassetid://656117878", fall="rbxassetid://656115606", climb="rbxassetid://656114359", swim="rbxassetid://656117400", swimidle="rbxassetid://656117400" },
    ["Knight"] = { idle1="rbxassetid://657595757", idle2="rbxassetid://657595757", walk="rbxassetid://657552124", run="rbxassetid://657564596", jump="rbxassetid://658409194", fall="rbxassetid://657600338", climb="rbxassetid://658360781", swim="rbxassetid://657595757", swimidle="rbxassetid://657595757" },
    ["Elder"] = { idle1="rbxassetid://845397899", idle2="rbxassetid://845397899", walk="rbxassetid://845403856", run="rbxassetid://845386501", jump="rbxassetid://845398858", fall="rbxassetid://845397673", climb="rbxassetid://845392038", swim="rbxassetid://845397899", swimidle="rbxassetid://845397899" },
    ["Levitate"] = { idle1="rbxassetid://616006778", idle2="rbxassetid://616006778", walk="rbxassetid://616013216", run="rbxassetid://616013216", jump="rbxassetid://616008936", fall="rbxassetid://616005863", climb="rbxassetid://616003713", swim="rbxassetid://616006778", swimidle="rbxassetid://616006778" },
    ["Astronaut"] = { idle1="rbxassetid://891621366", idle2="rbxassetid://891621366", walk="rbxassetid://891636393", run="rbxassetid://891636393", jump="rbxassetid://891627522", fall="rbxassetid://891617961", climb="rbxassetid://891609353", swim="rbxassetid://891621366", swimidle="rbxassetid://891621366" },
    ["Pirate"] = { idle1="rbxassetid://750781874", idle2="rbxassetid://750781874", walk="rbxassetid://750785693", run="rbxassetid://750783738", jump="rbxassetid://750782230", fall="rbxassetid://750780242", climb="rbxassetid://750779899", swim="rbxassetid://750781874", swimidle="rbxassetid://750781874" },
    ["Toy"] = { idle1="rbxassetid://782841498", idle2="rbxassetid://782841498", walk="rbxassetid://782843345", run="rbxassetid://782842708", jump="rbxassetid://782847020", fall="rbxassetid://782846423", climb="rbxassetid://782843869", swim="rbxassetid://782841498", swimidle="rbxassetid://782841498" },
    ["Vampire"] = { idle1="rbxassetid://1083445855", idle2="rbxassetid://1083445855", walk="rbxassetid://1083473930", run="rbxassetid://1083462077", jump="rbxassetid://1083455352", fall="rbxassetid://1083443587", climb="rbxassetid://1083439238", swim="rbxassetid://1083445855", swimidle="rbxassetid://1083445855" },
    ["Werewolf"] = { idle1="rbxassetid://1083195517", idle2="rbxassetid://1083195517", walk="rbxassetid://1083178339", run="rbxassetid://1083216690", jump="rbxassetid://1083218792", fall="rbxassetid://1083189019", climb="rbxassetid://1083182000", swim="rbxassetid://1083195517", swimidle="rbxassetid://1083195517" },
    ["Rthro"] = { idle1="rbxassetid://2510196951", idle2="rbxassetid://2510196951", walk="rbxassetid://2510202577", run="rbxassetid://2510198475", jump="rbxassetid://2510197830", fall="rbxassetid://2510195892", climb="rbxassetid://2510192778", swim="rbxassetid://2510196951", swimidle="rbxassetid://2510196951" },
    ["Stylish"] = { idle1="rbxassetid://616136790", idle2="rbxassetid://616136790", walk="rbxassetid://616146177", run="rbxassetid://616140816", jump="rbxassetid://616139451", fall="rbxassetid://616134815", climb="rbxassetid://616133594", swim="rbxassetid://616136790", swimidle="rbxassetid://616136790" },
}

ANIM_PACK_ORDER = {{"Off", "Off"}, {"Zombie", "Zombie"}, {"Ninja", "Ninja"}, {"Knight", "Knight"}, {"Elder", "Elder"}, {"Levitate", "Levitate"}, {"Astronaut", "Astronaut"}, {"Pirate", "Pirate"}, {"Toy", "Toy"}, {"Vampire", "Vampire"}, {"Werewolf", "Werewolf"}, {"Rthro", "Rthro"}, {"Stylish", "Stylish"}}

local function isPackAnim(id)
    for _, pack in pairs(ANIM_PACKS) do
        for _, v in pairs(pack) do
            if v == id then return true end
        end
    end
    return false
end

local function saveOriginalAnims(char)
    local animate = char:FindFirstChild("Animate")
    if not animate then return end
    local function g(obj) return obj and obj.AnimationId or nil end
    local ids = {
        idle1 = g(animate.idle and animate.idle.Animation1),
        idle2 = g(animate.idle and animate.idle.Animation2),
        walk  = g(animate.walk and animate.walk.WalkAnim),
        run   = g(animate.run  and animate.run.RunAnim),
        jump  = g(animate.jump and animate.jump.JumpAnim),
        fall  = g(animate.fall and animate.fall.FallAnim),
        climb = g(animate.climb and animate.climb.ClimbAnim),
        swim  = g(animate.swim and animate.swim.Swim),
        swimidle = g(animate.swimidle and animate.swimidle.SwimIdle),
    }
    if not isPackAnim(ids.walk) then originalTryardAnims = ids end
end

local function applyAnimPack(packName)
    currentAnimPack = packName
    if animSelectorLabel then animSelectorLabel.Text = packName end
    if packName == "Off" then
        if originalTryardAnims and LP.Character then
            local character = LP.Character
            local animate = character and character:FindFirstChild("Animate")
            if animate then
                local function s(obj,id) if obj then obj.AnimationId = id end end
                s(animate.idle and animate.idle.Animation1, originalTryardAnims.idle1)
                s(animate.idle and animate.idle.Animation2, originalTryardAnims.idle2)
                s(animate.walk and animate.walk.WalkAnim, originalTryardAnims.walk)
                s(animate.run  and animate.run.RunAnim,   originalTryardAnims.run)
                s(animate.jump and animate.jump.JumpAnim, originalTryardAnims.jump)
                s(animate.fall and animate.fall.FallAnim, originalTryardAnims.fall)
                s(animate.climb and animate.climb.ClimbAnim, originalTryardAnims.climb)
                s(animate.swim and animate.swim.Swim, originalTryardAnims.swim)
                s(animate.swimidle and animate.swimidle.SwimIdle, originalTryardAnims.swimidle)
            end
        end
        if tryardHeartbeatConn then tryardHeartbeatConn:Disconnect(); tryardHeartbeatConn = nil end
        return
    end
    local pack = ANIM_PACKS[packName]
    if not pack then return end
    if tryardHeartbeatConn then tryardHeartbeatConn:Disconnect() end
    tryardHeartbeatConn = RunService.Heartbeat:Connect(function()
        local c = LP.Character
        if not c then return end
        local animate = c:FindFirstChild("Animate")
        if not animate then return end
        local function s(obj,id) if obj then obj.AnimationId = id end end
        s(animate.idle and animate.idle.Animation1, pack.idle1)
        s(animate.idle and animate.idle.Animation2, pack.idle2)
        s(animate.walk and animate.walk.WalkAnim, pack.walk)
        s(animate.run  and animate.run.RunAnim,   pack.run)
        s(animate.jump and animate.jump.JumpAnim, pack.jump)
        s(animate.fall and animate.fall.FallAnim, pack.fall)
        s(animate.climb and animate.climb.ClimbAnim, pack.climb)
        s(animate.swim and animate.swim.Swim, pack.swim)
        s(animate.swimidle and animate.swimidle.SwimIdle, pack.swimidle)
    end)
end

local function startAnimPack(packName)
    local char = LP.Character
    if char then
        saveOriginalAnims(char)
        applyAnimPack(packName)
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            for _, track in ipairs(hum:GetPlayingAnimationTracks()) do track:Stop(0) end
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end
    else
        applyAnimPack(packName)
    end
    currentAnimPack = packName
end

local function stopAnimPack()
    currentAnimPack = "Off"
    if animSelectorLabel then animSelectorLabel.Text = "Off" end
    applyAnimPack("Off")
end

-- ═══════════════════════════════════════════════════════════════
-- KEYBINDS: TPBat en X, DropBrainrot en J (liberamos X)
-- ═══════════════════════════════════════════════════════════════
DEFAULT_KB = {
    DropBrainrot = {kb = Enum.KeyCode.J, gp = nil},
    AutoLeft     = {kb = Enum.KeyCode.Z, gp = nil},
    AutoRight    = {kb = Enum.KeyCode.C, gp = nil},
    AutoBat      = {kb = Enum.KeyCode.E, gp = nil},
    TPFloor      = {kb = Enum.KeyCode.F, gp = nil},
    GuiHide      = {kb = Enum.KeyCode.LeftControl, gp = nil},
    CarryToggle  = {kb = Enum.KeyCode.Q, gp = nil},
    LaggerMode   = {kb = Enum.KeyCode.R, gp = nil},
    TPBat        = {kb = Enum.KeyCode.X, gp = nil},
    BatV2        = {kb = Enum.KeyCode.V, gp = nil},
    InstaReset   = {kb = Enum.KeyCode.H, gp = nil},
}

KB = {
    DropBrainrot = {kb = DEFAULT_KB.DropBrainrot.kb, gp = DEFAULT_KB.DropBrainrot.gp},
    AutoLeft     = {kb = DEFAULT_KB.AutoLeft.kb, gp = DEFAULT_KB.AutoLeft.gp},
    AutoRight    = {kb = DEFAULT_KB.AutoRight.kb, gp = DEFAULT_KB.AutoRight.gp},
    AutoBat      = {kb = DEFAULT_KB.AutoBat.kb, gp = DEFAULT_KB.AutoBat.gp},
    TPFloor      = {kb = DEFAULT_KB.TPFloor.kb, gp = DEFAULT_KB.TPFloor.gp},
    GuiHide      = {kb = DEFAULT_KB.GuiHide.kb, gp = DEFAULT_KB.GuiHide.gp},
    CarryToggle  = {kb = DEFAULT_KB.CarryToggle.kb, gp = DEFAULT_KB.CarryToggle.gp},
    LaggerMode   = {kb = DEFAULT_KB.LaggerMode.kb, gp = DEFAULT_KB.LaggerMode.gp},
    TPBat        = {kb = DEFAULT_KB.TPBat.kb, gp = DEFAULT_KB.TPBat.gp},
    BatV2        = {kb = DEFAULT_KB.BatV2.kb, gp = DEFAULT_KB.BatV2.gp},
    InstaReset   = {kb = DEFAULT_KB.InstaReset.kb, gp = DEFAULT_KB.InstaReset.gp},
}

_isResetting = false
_lastSavedJSON = nil
_isLoading = false

CONFIG = {
    AUTO_STEAL_ENABLED = false,
    STEAL_RANGE = 61,
}

local plots = workspace:WaitForChild("Plots")
local stealConnection = nil

local Steal = {
    AutoStealEnabled = false,
    StealRadius = CONFIG.STEAL_RANGE,
    StealDuration = 1.3,
    StealDelay = 0.25,
    Data = {}
}

local isStealing = false
local autoGrabSetDelayRadius = 9
local autoGrabStopTime = 0.96
local autoGrabStopEnabled = true

autoStealVariant = 1

AUTO_STEAL_VARIANT_NAMES = { "Normal", "Semi", "Semi Normal" }

local function autoStealVariantName(n)
    n = _clamp(tonumber(n) or 1, 1, #AUTO_STEAL_VARIANT_NAMES)
    return AUTO_STEAL_VARIANT_NAMES[n]
end

local function autoStealVariantFromName(name)
    for i, v in ipairs(AUTO_STEAL_VARIANT_NAMES) do
        if v == tostring(name) then return i end
    end
    return 1
end

local function getAutoGrabStopTime()
    local dur = (Steal and Steal.StealDuration) or 1.3
    if autoStealVariant == 2 then return dur * 0.80 end
    if autoStealVariant == 3 then return dur * 0.90 end
    return dur * 0.73
end

local _plotsCache = nil
local _plotsCacheTime = 0
local function getPlotsRoot()
    local now = _tick()
    if _plotsCache and now - _plotsCacheTime < 2 and _plotsCache.Parent then
        return _plotsCache
    end
    _plotsCache = workspace:FindFirstChild("Plots")
    _plotsCacheTime = now
    return _plotsCache
end

local function isMyPlotByName(plotName)
    local plotsRoot = getPlotsRoot()
    if not plotsRoot then return false end
    local plot = plotsRoot:FindFirstChild(plotName)
    if not plot then return false end
    local sign = plot:FindFirstChild("PlotSign")
    if sign then
        local yb = sign:FindFirstChild("YourBase")
        if yb and yb:IsA("BillboardGui") and yb.Enabled then
            return true
        end
        for _, desc in ipairs(sign:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Text:find(LP.Name, 1, true) then
                return true
            end
        end
    end
    return false
end

local _nearestPromptCache = { time = 0, prompt = nil, name = nil, position = nil, valid = false }
local function findNearestPrompt()
    local char = LP.Character
    if not char then return nil, nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil, nil end
    local plotsRoot = getPlotsRoot()
    if not plotsRoot then return nil, nil end
    local nearestPrompt, nearestDist, nearestName = nil, _huge, nil
    local rpos = root.Position
    local cached = _nearestPromptCache
    if cached.valid and cached.position and _tick() - cached.time < 0.12
       and (rpos - cached.position).Magnitude < 4 then
        if cached.prompt and cached.prompt.Parent then
            return cached.prompt, cached.name
        elseif cached.prompt == nil then
            return nil, nil
        end
        -- A destroyed cached prompt is stale; continue with a fresh scan.
    end
    for _, plot in ipairs(plotsRoot:GetChildren()) do
        if isMyPlotByName(plot.Name) then continue end
        local pods = plot:FindFirstChild("AnimalPodiums")
        if not pods then continue end
        for _, pod in ipairs(pods:GetChildren()) do
            pcall(function()
                local base = pod:FindFirstChild("Base")
                local spawn = base and base:FindFirstChild("Spawn")
                if spawn then
                    local sp = spawn.Position
                    local dx = sp.X - rpos.X
                    local dy = sp.Y - rpos.Y
                    local dz = sp.Z - rpos.Z
                    local dist = _sqrt(dx*dx + dy*dy + dz*dz)
                    if dist < nearestDist and dist <= Steal.StealRadius then
                        local att = spawn:FindFirstChild("PromptAttachment")
                        if att then
                            for _, child in ipairs(att:GetChildren()) do
                                if child:IsA("ProximityPrompt") and child.ActionText and child.ActionText:find("Steal") then
                                    nearestPrompt = child
                                    nearestDist = dist
                                    nearestName = pod.Name
                                    break
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
    _nearestPromptCache.time = _tick()
    _nearestPromptCache.prompt = nearestPrompt
    _nearestPromptCache.name = nearestName
    _nearestPromptCache.position = rpos
    _nearestPromptCache.valid = true
    return nearestPrompt, nearestName
end

local function executeSteal(prompt, podName)
    if isStealing then return end
    if ShoxHubIsCarrying() then return end
    if type(Steal.Data) == "table" then
        pcall(function()
            local mt = getmetatable(Steal.Data) or {}
            mt.__mode = "k"
            setmetatable(Steal.Data, mt)
        end)
    end
    if math.random(30) == 1 then
        for p in pairs(Steal.Data) do
            if not p.Parent then Steal.Data[p] = nil end
        end
    end
    if not Steal.Data[prompt] then
        Steal.Data[prompt] = { hold = {}, trigger = {}, ready = true }
        pcall(function()
            if getconnections then
                for _, c in ipairs(getconnections(prompt.PromptButtonHoldBegan)) do
                    if c.Function then table.insert(Steal.Data[prompt].hold, c.Function) end
                end
                for _, c in ipairs(getconnections(prompt.Triggered)) do
                    if c.Function then table.insert(Steal.Data[prompt].trigger, c.Function) end
                end
            end
        end)
    end
    local data = Steal.Data[prompt]
    if not data.ready then return end
    data.ready = false
    isStealing = true
    if progressFill then progressFill.Size = UDim2.new(0, 0, 1, 0) end
    if progressPct then progressPct.Text = "0%" end
    task.spawn(function()
        local recursionStarted = false
        local workerOk, workerErr = xpcall(function()
        for _, f in ipairs(data.hold) do task.spawn(f) end
        local startTime = _tick()
        local duration = Steal.StealDuration
        local stopTime = getAutoGrabStopTime()
        local promptFired = false
        if autoGrabStopEnabled then
            while isStealing and Steal.AutoStealEnabled do
                local elapsed = _tick() - startTime
                if elapsed >= stopTime then break end
                local progress = _clamp(elapsed / duration, 0, 1)
                if progressFill then progressFill.Size = UDim2.new(progress, 0, 1, 0) end
                if progressPct then progressPct.Text = _floor(progress * 100) .. "%" end
                local targetParent = prompt.Parent and prompt.Parent.Parent
                local targetPart = targetParent and (targetParent:IsA("BasePart") and targetParent or targetParent:FindFirstChildWhichIsA("BasePart", true))
                if not targetPart then break end
                local char = LP.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp and (hrp.Position - targetPart.Position).Magnitude > Steal.StealRadius then break end
                task.wait()
            end
            local stopProgress = _clamp(stopTime / duration, 0, 1)
            if progressFill then progressFill.Size = UDim2.new(stopProgress, 0, 1, 0) end
            if progressPct then progressPct.Text = _floor(stopProgress * 100) .. "%" end
            local phase2Timeout = math.max(2.99 - stopTime - math.max(duration - stopTime, 0), 0.05)
            if phase2Timeout > 5 then phase2Timeout = 5 end
            local phase2Start = _tick()
            while isStealing and Steal.AutoStealEnabled do
                if _tick() - phase2Start >= phase2Timeout then
                    if progressFill then progressFill.Size = UDim2.new(0, 0, 1, 0) end
                    if progressPct then progressPct.Text = "0%" end
                    data.ready = true
                    isStealing = false
                    task.wait()
                    local newPrompt, newName = findNearestPrompt()
                    if newPrompt then
                        executeSteal(newPrompt, newName)
                        recursionStarted = isStealing
                    end
                    return
                end
                local targetParent = prompt.Parent and prompt.Parent.Parent
                local targetPart = targetParent and (targetParent:IsA("BasePart") and targetParent or targetParent:FindFirstChildWhichIsA("BasePart", true))
                if not targetPart then
                    isStealing = false
                    if progressFill then progressFill.Size = UDim2.new(0, 0, 1, 0) end
                    if progressPct then progressPct.Text = "0%" end
                    data.ready = true
                    return
                end
                local char = LP.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local dist = (hrp.Position - targetPart.Position).Magnitude
                    if dist <= autoGrabSetDelayRadius then
                        break
                    elseif dist > Steal.StealRadius then
                        isStealing = false
                        if progressFill then progressFill.Size = UDim2.new(0, 0, 1, 0) end
                        if progressPct then progressPct.Text = "0%" end
                        data.ready = true
                        return
                    end
                end
                task.wait()
            end
            if isStealing and Steal.AutoStealEnabled then
                local fillStart = _tick()
                local fillDuration = math.max(duration - stopTime, 0.05)
                while true do
                    local fp = _clamp((_tick() - fillStart) / fillDuration, 0, 1)
                    local totalProgress = stopProgress + fp * (1 - stopProgress)
                    if progressFill then progressFill.Size = UDim2.new(totalProgress, 0, 1, 0) end
                    if progressPct then progressPct.Text = _floor(totalProgress * 100) .. "%" end
                    if fp >= 1 and not promptFired then
                        promptFired = true
                        pcall(function()
                            for _, f in ipairs(data.trigger) do task.spawn(f) end
                            if prompt then
                                if fireproximityprompt then
                                    fireproximityprompt(prompt)
                                else
                                    prompt:InputHoldBegin()
                                    task.wait(prompt.HoldDuration)
                                    prompt:InputHoldEnd()
                                end
                            end
                        end)
                        break
                    end
                    task.wait()
                end
            end
        else
            while isStealing and Steal.AutoStealEnabled do
                local elapsed = _tick() - startTime
                local progress = _clamp(elapsed / duration, 0, 1)
                if progressFill then progressFill.Size = UDim2.new(progress, 0, 1, 0) end
                if progressPct then progressPct.Text = _floor(progress * 100) .. "%" end
                local targetParent = prompt.Parent and prompt.Parent.Parent
                local targetPart = targetParent and (targetParent:IsA("BasePart") and targetParent or targetParent:FindFirstChildWhichIsA("BasePart", true))
                if not targetPart then break end
                local char = LP.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp and (hrp.Position - targetPart.Position).Magnitude > Steal.StealRadius then break end
                if elapsed >= duration and not promptFired then
                    promptFired = true
                    pcall(function()
                        for _, f in ipairs(data.trigger) do task.spawn(f) end
                        if prompt then prompt:Fire() end
                    end)
                    break
                end
                task.wait()
            end
        end
        if progressFill then progressFill.Size = UDim2.new(0, 0, 1, 0) end
        if progressPct then progressPct.Text = "0%" end
        end, function(err) return tostring(err) end)
        if not recursionStarted then
            data.ready = true
            isStealing = false
        end
        if not workerOk then
            data.ready = true
            if not recursionStarted then isStealing = false end
            warn("[ShoxHub] Auto-Steal worker recovered: " .. tostring(workerErr))
        end
    end)
end

function startAutoSteal()
    if stealConnection then
        local connected = false
        pcall(function() connected = stealConnection.Connected == true end)
        if connected then
            Steal.StealRadius = CONFIG.STEAL_RANGE
            Steal.AutoStealEnabled = true
            CONFIG.AUTO_STEAL_ENABLED = true
            return true
        end
        pcall(function() stealConnection:Disconnect() end)
        stealConnection = nil
    end
    Steal.StealRadius = CONFIG.STEAL_RANGE
    Steal.AutoStealEnabled = true
    CONFIG.AUTO_STEAL_ENABLED = true
    stealConnection = RunService.Heartbeat:Connect(function()
        if not Steal.AutoStealEnabled or isStealing then return end
        local p, n = findNearestPrompt()
        if p then executeSteal(p, n) end
    end)
    return true
end

function stopAutoSteal()
    if stealConnection then
        stealConnection:Disconnect()
        stealConnection = nil
    end
    isStealing = false
    Steal.AutoStealEnabled = false
    CONFIG.AUTO_STEAL_ENABLED = false
    if progressFill then
        TS:Create(progressFill, TweenInfo.new(0.2), { Size = UDim2.new(0, 0, 1, 0) }):Play()
    end
    if progressPct then progressPct.Text = "0%" end
end

medusaDebounce = false
medusaLastUsed = 0
dropActive = false
lastDropTime = 0
lastMoveDir = _V3new(0,0,0)
origFOV = nil
origFOVMode = nil
_customFovBound = false
fovEnabled = false
fovValue = 70
customFovConn = nil
setFovVisual = nil
fovSliderSet = nil

_anyKeyListening = false
_activeKeyCapture = nil
_aimbotConn = nil
_prevAutoRotate = nil
tpBatConn = nil
tpBatPrevAutoRotate = nil
TP_BAT_SWING_CD = 0.08
batV2FloatingButton = nil

enemySpeedConn = nil
movementLoop = nil
steppedConn = nil
alConn = nil
arConn = nil
infJumpConn = nil
stretchConn = nil
stretchFovConn = nil
medusaResetConns = {}
dropConnections = {}
enemySpeedLabels = {}
Conns = {autoSteal = nil, batCounter = nil, anchor = {}, progress = nil, autoLeft = nil, autoRight = nil}
keyButtonRefs = {}
progressFill = nil
progressPct = nil
progressRadLbl = nil
pbFrame = nil
speedLabel = nil
modeValLbl = nil
normalBox, carryBox, laggerBox, lagger2Box, radInput, batSpeedBox, uiScaleBox = nil, nil, nil, nil, nil, nil, nil
modeSelectBtn, dropModeBtnRef = nil, nil
setJumpToggleState = nil
autoBatSetVisual, autoLeftSetVisual, autoRightSetVisual, setBatCounterVisual, setMedusaVisual = nil, nil, nil, nil, nil
setAntiRagVisual, setJumpVisual, setUnwalkVisual, setAntiLagVisual, setLockUIVisual, setInstaGrab = nil, nil, nil, nil, nil, nil
setAntiDieVisual = nil
setEditModeVisual = nil
setESPVIsual = nil
mobSetAutoBat, mobSetAutoLeft, mobSetAutoRight, mobSetDropBR, mobSetTpDown, mobSetCarry, mobSetLagger1, mobSetLagger2 = nil, nil, nil, nil, nil, nil, nil, nil
autoBatV2SetVisual = nil
miniBtn, main, gui = nil, nil, nil
MobilePanel = nil
instaResetFloatingButton = nil
showGui = nil
hideGui = nil
mainUIScale = nil
animSelectorLabel = nil
pbScale = nil
tabButtons = nil

carrySystemToggleSetter = nil
autoStealVariantLabel = nil
carrySysNormalBox = nil
carrySysCarryBox = nil
carrySysLaggerBox = nil
carrySysLaggerCarryBox = nil
carrySysSoftStealSpeedBox = nil
carrySysSoftStealRadiusBox = nil

setSafeModeVisual           = nil
mirrorTPDownSetVisual       = nil
infJumpSetVisual            = nil
infJumpModeSetVisual        = nil

-- ═══════════════════════════════════════════════════════════════
-- NUEVOS MÓDULOS: NO PLAYER COLLISION + NO CAMERA COLLISION
-- ═══════════════════════════════════════════════════════════════
noPlayerCollisionEnabled = false
setNoPlayerCollisionVisual = nil
noCamCollisionEnabled = false
setNoCamCollisionVisual = nil

GAMEPAD_KEYS = {
    [Enum.KeyCode.ButtonA] = true, [Enum.KeyCode.ButtonB] = true,
    [Enum.KeyCode.ButtonX] = true, [Enum.KeyCode.ButtonY] = true,
    [Enum.KeyCode.ButtonL1] = true, [Enum.KeyCode.ButtonR1] = true,
    [Enum.KeyCode.ButtonL2] = true, [Enum.KeyCode.ButtonR2] = true,
    [Enum.KeyCode.ButtonL3] = true, [Enum.KeyCode.ButtonR3] = true,
    [Enum.KeyCode.ButtonStart] = true, [Enum.KeyCode.ButtonSelect] = true,
    [Enum.KeyCode.DPadUp] = true, [Enum.KeyCode.DPadDown] = true,
    [Enum.KeyCode.DPadLeft] = true, [Enum.KeyCode.DPadRight] = true,
}

MOVE_KEYS = {
    [Enum.KeyCode.W] = true, [Enum.KeyCode.A] = true,
    [Enum.KeyCode.S] = true, [Enum.KeyCode.D] = true,
    [Enum.KeyCode.Up] = true, [Enum.KeyCode.Left] = true,
    [Enum.KeyCode.Down] = true, [Enum.KeyCode.Right] = true,
}

BAT_COUNTER_SLAP_LIST = {
    "Bat", "Slap", "Iron Slap", "Gold Slap", "Diamond Slap",
    "Emerald Slap", "Ruby Slap", "Dark Matter Slap", "Flame Slap",
    "Nuclear Slap", "Galaxy Slap", "Glitched Slap"
}

AP = {
    L1 = _V3new(-476.48, -6.28, 92.73),
    L2 = _V3new(-483.12, -4.95, 94.80),
    L_FACE = _V3new(-482.25, -4.96, 92.09),
    R1 = _V3new(-476.16, -6.52, 25.62),
    R2 = _V3new(-483.06, -5.03, 25.48),
    R_FACE = _V3new(-482.06, -6.93, 35.47),
}

function isGamepadInput(inp)
    return inp and inp.UserInputType and inp.UserInputType.Name:match("^Gamepad") ~= nil
end

function isBindableInput(inp)
    if not inp or inp.KeyCode == Enum.KeyCode.Unknown then return false end
    if inp.UserInputType == Enum.UserInputType.Keyboard then return true end
    return isGamepadInput(inp) and GAMEPAD_KEYS[inp.KeyCode] == true
end

function kbMatch(entry, kc)
    return kc and (kc == entry.kb or (entry.gp and kc == entry.gp))
end



-- v1.6.2: gemeinsame Boden-Erkennung (nur solide Teile, keine Spieler, kein Wasser)
local function ShoxHubIsCarrying()
    local ShoxHubCharacter = LP.Character
    if not ShoxHubCharacter then return false end

    local okPlayer, playerStealing = pcall(function()
        return LP:GetAttribute("Stealing")
    end)
    if okPlayer and playerStealing == true then return true end

    local okCharacter, characterStealing = pcall(function()
        return ShoxHubCharacter:GetAttribute("Stealing")
    end)
    if okCharacter and characterStealing == true then return true end

    for _, markerName in ipairs({"Carrying", "IsCarrying", "Grabbed", "Holding", "StealHold", "HasGrab"}) do
        local marker = ShoxHubCharacter:FindFirstChild(markerName)
        if marker then
            if (marker:IsA("BoolValue") and marker.Value == true)
                or (marker:IsA("ObjectValue") and marker.Value ~= nil)
                or (marker:IsA("StringValue") and marker.Value ~= "") then
                return true
            end
        end
    end
    return false
end

function canTeleportNow()
    if ShoxHubIsCarrying() then return false end
    if autoLeftEnabled or autoRightEnabled or dropActive then return false end
    return true
end

function ShoxGetGroundHit(char, root)
    local ignore = {char}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and p.Character ~= char then table.insert(ignore, p.Character) end
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore
    params.IgnoreWater = true
    pcall(function() params.RespectCanCollide = true end)
    return workspace:Raycast(root.Position, Vector3.new(0, -2000, 0), params)
end

function ShoxGetStandOffset(humanoid, root)
    local hip = math.max(0, humanoid.HipHeight)
    if humanoid.RigType == Enum.HumanoidRigType.R6 then
        return 3 + hip + 0.05
    end
    return hip + (root.Size.Y * 0.5) + 0.05
end

local function doTpDown()
    local ok, err = pcall(function()
        if not canTeleportNow() then return end
        local char = LP.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not root or not humanoid or humanoid.Health <= 0 then return end

        local hit = ShoxGetGroundHit(char, root)
        if not hit then return end

        local targetY = hit.Position.Y + ShoxGetStandOffset(humanoid, root)
        if root.Position.Y - targetY < 3 then return end -- schon am Boden

        local yaw = select(2, root.CFrame:ToEulerAnglesYXZ())
        root.CFrame = _CFnew(root.Position.X, targetY, root.Position.Z)
            * CFrame.Angles(0, yaw, 0)
        root.AssemblyLinearVelocity = _V3zero
        root.AssemblyAngularVelocity = _V3zero
        _globalMovementLock = tick() + 0.3 -- SH-06/07 Lock
    end)
    if not ok then shoxWarn("TP_DOWN", "Failed: " .. tostring(err)) end
end

-- ═══════════════════════════════════════════════════════════════
-- MIRROR TP DOWN
-- ═══════════════════════════════════════════════════════════════
do
    local MIRROR_TP_DROP_THRESHOLD = 3
    local MIRROR_TP_DOWN_Y         = -7.00
    local mirrorTPPreviousY        = {}
    local mirrorTPLastTeleport     = 0

    -- Keep cleanup in the same lexical scope as the per-player history table.
    Players.PlayerRemoving:Connect(function(player)
        mirrorTPPreviousY[player.UserId] = nil
    end)

    local function mirrorTPAimbotActive()
        return (_G.AmbitiousNormalAimbotOn == true)
            or (_G.AmbitiousBatAimbotV2On == true)
            or (_G.AmbitiousTPBatOn == true)
            or (_G.AlvaroTP and _G.AlvaroTP.on == true)
            or (autoBatEnabled == true)
            or (autoBatV2Enabled == true)
            or (batDesyncTpEnabled == true)
    end

    local function mirrorTPTeleportDown()
        local character = LP.Character
        local root      = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
        if not root or not humanoid or humanoid.Health <= 0 then return end
        local now = _tick()
        if now - mirrorTPLastTeleport < 0.08 then return end
        mirrorTPLastTeleport = now
        local _, yaw = root.CFrame:ToEulerAnglesYXZ()
        local hit = ShoxGetGroundHit(character, root)
        if not hit then return end
        local ty = hit.Position.Y + ShoxGetStandOffset(humanoid, root)
        if root.Position.Y - ty < 3 then return end
        root.CFrame = _CFnew(root.Position.X, ty, root.Position.Z)
                   * CFrame.Angles(0, yaw, 0)
        root.Velocity = _V3zero
        pcall(function() root.AssemblyLinearVelocity = _V3zero end)
    end

    RunService.Heartbeat:Connect(function()
        if not mirrorTPDownEnabled or not mirrorTPAimbotActive() then
            table.clear(mirrorTPPreviousY)
            return
        end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LP and player.Character then
                local character = player.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")
                if root then
                    local currentY  = root.Position.Y
                    local previousY = mirrorTPPreviousY[player.UserId]
                    if previousY
                       and previousY - currentY >= MIRROR_TP_DROP_THRESHOLD then
                        local isAimbotTarget = false
                        if _G.SnowVS and _G.SnowVS.BatBypass and _G.SnowVS.BatBypass.Z and _G.SnowVS.BatBypass.Z.targetPlayer == player then
                            isAimbotTarget = true
                        end
                        if autoBatEnabled or autoBatV2Enabled or isAimbotTarget then
                            pcall(mirrorTPTeleportDown)
                            table.clear(mirrorTPPreviousY)
                            return
                        end
                    end
                    mirrorTPPreviousY[player.UserId] = currentY
                end
            end
        end
    end)

    function _G.AmbitiousSetMirrorTPDown(enabled)
        mirrorTPDownEnabled = enabled == true
        if not mirrorTPDownEnabled then table.clear(mirrorTPPreviousY) end
        if mirrorTPDownSetVisual then
            mirrorTPDownSetVisual(mirrorTPDownEnabled)
        end
        pcall(saveAllSettings)
    end
end

-- ═══════════════════════════════════════════════════════════════
-- SAFE MODE
-- ═══════════════════════════════════════════════════════════════
function _G.AmbitiousSafeModeGetCountdownLabel()
    local ok, label = pcall(function()
        return LP.PlayerGui
          and LP.PlayerGui:FindFirstChild("DuelsMachineTopFrame")
          and LP.PlayerGui.DuelsMachineTopFrame:FindFirstChild("DuelsMachineTopFrame")
          and LP.PlayerGui.DuelsMachineTopFrame.DuelsMachineTopFrame:FindFirstChild("Timer")
          and LP.PlayerGui.DuelsMachineTopFrame.DuelsMachineTopFrame.Timer:FindFirstChild("Label")
    end)
    return (ok and label) or nil
end

function _G.AmbitiousSafeModeCountdownNumber(text)
    local t = tostring(text or ""):upper():gsub("^%s+", ""):gsub("%s+$", "")
    if t == "GO" or t == "START" or t == "READY" then return true end
    local n = tonumber(t)
    return n ~= nil and n >= 0 and n <= 10
end

function _G.AmbitiousSafeModeCountdownValue()
    local label = _G.AmbitiousSafeModeGetCountdownLabel()
    if not label then return nil end
    local t = tostring(label.Text or ""):upper():gsub("^%s+", ""):gsub("%s+$", "")
    if t == "GO" or t == "START" or t == "READY" then return 0 end
    local n = tonumber(t)
    if n ~= nil and n >= 0 and n <= 10 then return n end
    return nil
end

function _G.AmbitiousSafeModeInDuelCountdown()
    local label = _G.AmbitiousSafeModeGetCountdownLabel()
    return label and _G.AmbitiousSafeModeCountdownNumber(label.Text) or false
end

_G.AmbitiousSafeModeBlockedTools = {
    bat=true, slap=true, sword=true, gun=true, pistol=true, rifle=true,
    medusa=true, hammer=true, axe=true, knife=true, katana=true, blade=true, fist=true,
}

function _G.AmbitiousSafeModeIsCarryableTool(tool)
    if not tool or not tool:IsA("Tool") then return false end
    local name = tool.Name:lower()
    for word in pairs(_G.AmbitiousSafeModeBlockedTools) do
        if name:find(word, 1, true) then return false end
    end
    return true
end

function _G.AmbitiousSafeModeHoldingBrainrot()
    local ok, val = pcall(function() return LP:GetAttribute("Stealing") end)
    if ok and val == true then return true end
    local char = LP.Character
    if not char then return false end
    local ok3, val3 = pcall(function() return char:GetAttribute("Stealing") end)
    if ok3 and val3 == true then return true end
    for _, name in ipairs({"Carrying","IsCarrying","Grabbed","Holding","StealHold","HasGrab"}) do
        local v = char:FindFirstChild(name, true)
        if v then
            if v:IsA("BoolValue")   and v.Value then return true end
            if v:IsA("ObjectValue") and v.Value then return true end
            if v:IsA("StringValue") then
                local state = v.Value:lower()
                if state == "true" or state == "1" or state == "carrying"
                   or state == "holding" or state == "stealing" then return true end
            end
        end
    end
    -- Do not infer carrying from arbitrary model names such as "AnimalSlot"
    -- or "AnimalPodium"; only trust an explicit carried-state attribute.
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Model") and child:GetAttribute("IsCarried") == true then
            return true
        end
        local name = child.Name:lower()
        if name:find("brainrot", 1, true) or name:find("animal", 1, true) then
            if child:FindFirstChildWhichIsA("BasePart") then
                return true
            end
        end
    end
    return false
end

function _G.AmbitiousSafeModeIsLocked()
    if not antiKickEnabled then return false end
    return _G.AmbitiousSafeModeInDuelCountdown()
        or _G.AmbitiousSafeModeHoldingBrainrot()
end

function _G.AmbitiousSafeModeForceStop(reason)
    local stopped = false
    if autoBatEnabled and disableAutoBat then disableAutoBat(); stopped = true end
    if autoBatV2Enabled and disableBatV2 then disableBatV2(); stopped = true end
    if batDesyncTpEnabled and stopBatDesyncTp then stopBatDesyncTp(); stopped = true end
    if autoLeftEnabled then
        autoLeftEnabled = false
        if autoLeftSetVisual then autoLeftSetVisual(false) end
        stopAutoLeft()
        stopped = true
    end
    if autoRightEnabled then
        autoRightEnabled = false
        if autoRightSetVisual then autoRightSetVisual(false) end
        stopAutoRight()
        stopped = true
    end
    if stopped then
        print("[SafeMode]", reason or "LOCK")
    end
end

function _G.AmbitiousSafeModeTryStart()
    if _G.AmbitiousSafeModeIsLocked and _G.AmbitiousSafeModeIsLocked() then
        _G.AmbitiousSafeModeForceStop("SAFE MODE LOCK")
        return false
    end
    return true
end

-- Replace a previous monitor on script re-execution. A boolean-only guard
-- would leave the old Heartbeat closure bound to stale local state.
if _G.AmbitiousSafeModeMonitorConnection then
    pcall(function() _G.AmbitiousSafeModeMonitorConnection:Disconnect() end)
    _G.AmbitiousSafeModeMonitorConnection = nil
end
local _smAcc = 0
_G.AmbitiousSafeModeMonitorConnection = RunService.Heartbeat:Connect(function(dt)
    _smAcc = _smAcc + (dt or 0)
    if _smAcc < 0.2 then return end
    _smAcc = 0
    if antiKickEnabled
       and _G.AmbitiousSafeModeIsLocked
       and _G.AmbitiousSafeModeIsLocked() then
        _G.AmbitiousSafeModeForceStop("SAFE MODE LOCK")
    end
end)
_G.AmbitiousSafeModeMonitorStarted = true

local AntiRagdollV1 = {}
AntiRagdollV1.__index = AntiRagdollV1

local BOOST_SPEED = 400
local AR_DEFAULT_SPEED = 16

local stateV1 = {
    active = false,
    isBoosting = false,
    cachedChar = nil,
    ragdollConnections = {},
    _lastBoostTime = 0,
}

local function getAntiRagdollRecoverySpeed()
    if laggerCarryToggled then return LAGGER_CARRY_SPEED
    elseif laggerToggled then return LAGGER_SPEED
    elseif speedMode then return CS
    else return NS end
end

local function disconnectAllV1()
    for _, conn in ipairs(stateV1.ragdollConnections) do
        pcall(function() conn:Disconnect() end)
    end
    stateV1.ragdollConnections = {}
end

local function cacheCharacterV1()
    local char = LP.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return false end
    stateV1.cachedChar = { character = char, humanoid = hum, root = root }
    return true
end

local function isRagdolledV1()
    if not stateV1.cachedChar or not stateV1.cachedChar.humanoid then return false end
    local hum = stateV1.cachedChar.humanoid
    if not hum.Parent then return false end
    local st = hum:GetState()
    local ragdollStates = {
        [Enum.HumanoidStateType.Physics] = true,
        [Enum.HumanoidStateType.Ragdoll] = true,
        [Enum.HumanoidStateType.FallingDown] = true,
    }
    return ragdollStates[st] or false
end

local function forceExitRagdollV1()
    if not stateV1.cachedChar or not stateV1.cachedChar.humanoid or not stateV1.cachedChar.root then return end
    local hum = stateV1.cachedChar.humanoid
    local root = stateV1.cachedChar.root
    if not hum.Parent or not root.Parent then return end
    -- RagdollEndTime is server-owned in the target experience. A LocalScript
    -- cannot authoritatively update that server state, so do not write a
    -- misleading client-only attribute here. Local recovery continues below.
    for _, descendant in ipairs(stateV1.cachedChar.character:GetDescendants()) do
        if descendant:IsA("BallSocketConstraint") or
           (descendant:IsA("Attachment") and descendant.Name:find("RagdollAttachment")) then
            pcall(function() descendant:Destroy() end)
        end
    end
    local spd = getAntiRagdollRecoverySpeed()
    if not stateV1.isBoosting then
        stateV1.isBoosting = true
        stateV1._lastBoostTime = _tick()
    end
    pcall(function() hum.WalkSpeed = spd end)
    if hum.Health > 0 then
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
    end
    pcall(function() root.Anchored = false end)
end

local function heartbeatLoopV1()
    while stateV1.active do
        task.wait(0.05)
        if isRagdolledV1() then
            forceExitRagdollV1()
        elseif stateV1.isBoosting then
            local elapsed = _tick() - (stateV1._lastBoostTime or 0)
            if elapsed > 0.35 or not isRagdolledV1() then
                stateV1.isBoosting = false
                if stateV1.cachedChar and stateV1.cachedChar.humanoid then
                    pcall(function()
                        stateV1.cachedChar.humanoid.WalkSpeed = getAntiRagdollRecoverySpeed()
                    end)
                end
            end
        end
    end
end

function AntiRagdollV1.start()
    if stateV1.active then return end
    AntiRagdollV1.stop()
    if not cacheCharacterV1() then
        warn("[AntiRagdollV1] No se pudo cachear el personaje")
        return
    end
    stateV1.active = true
    stateV1.isBoosting = false
    local camConn = RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        if cam and stateV1.cachedChar and stateV1.cachedChar.humanoid then
            cam.CameraSubject = stateV1.cachedChar.humanoid
        end
    end)
    table.insert(stateV1.ragdollConnections, camConn)
    local respawnConn = LP.CharacterAdded:Connect(function()
        stateV1.isBoosting = false
        task.wait(0.5)
        cacheCharacterV1()
    end)
    table.insert(stateV1.ragdollConnections, respawnConn)
    task.spawn(heartbeatLoopV1)
    print("[AntiRagdollV1] Activado")
end

function AntiRagdollV1.stop()
    stateV1.active = false
    if stateV1.isBoosting and stateV1.cachedChar and stateV1.cachedChar.humanoid then
        pcall(function()
            stateV1.cachedChar.humanoid.WalkSpeed = getAntiRagdollRecoverySpeed()
        end)
    end
    stateV1.isBoosting = false
    disconnectAllV1()
    stateV1.cachedChar = nil
    print("[AntiRagdollV1] Desactivado")
end

function AntiRagdollV1.isRunning() return stateV1.active end

local AntiRagdollV2 = {
    Enabled = false,
    Connection = nil,
    ResetCooldown = 0,
}

local function startAntiRagdollV2()
    if AntiRagdollV2.Connection then return end
    AntiRagdollV2.Enabled = true
    AntiRagdollV2.Connection = RunService.Heartbeat:Connect(function()
        if not AntiRagdollV2.Enabled then return end
        local char = LP.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if not hum or not root then return end
        if hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead then return end
        local state = hum:GetState()
        local now = _tick()
        if state == Enum.HumanoidStateType.Physics or
           state == Enum.HumanoidStateType.Ragdoll or
           state == Enum.HumanoidStateType.FallingDown then
            if now - AntiRagdollV2.ResetCooldown > 0.15 then
                AntiRagdollV2.ResetCooldown = now
                pcall(function()
                    if hum:GetState() == Enum.HumanoidStateType.GettingUp then return end
                    if hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead then return end
                    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                    root.Velocity = _V3zero
                    root.RotVelocity = _V3zero
                    root.AssemblyLinearVelocity = _V3zero
                    root.AssemblyAngularVelocity = _V3zero
                    for _, obj in ipairs(char:GetDescendants()) do
                        if obj:IsA("Motor6D") then obj.Enabled = true end
                        if obj:IsA("Constraint") then obj.Enabled = true end
                    end
                    workspace.CurrentCamera.CameraSubject = hum
                    local PM = LP.PlayerScripts:FindFirstChild("PlayerModule")
                    if PM then
                        local CM = require(PM:FindFirstChild("ControlModule"))
                        if CM then CM:Enable() end
                    end
                    hum.AutoRotate = true
                    hum.PlatformStand = false
                    hum.Sit = false
                end)
            end
        end
    end)
end

local function stopAntiRagdollV2()
    AntiRagdollV2.Enabled = false
    if AntiRagdollV2.Connection then
        AntiRagdollV2.Connection:Disconnect()
        AntiRagdollV2.Connection = nil
    end
    AntiRagdollV2.ResetCooldown = 0
end

function setAntiRagdollMode(mode)
    if AntiRagdollV1.isRunning() then AntiRagdollV1.stop() end
    if AntiRagdollV2.Enabled then stopAntiRagdollV2() end
    antiRagdollMode = mode
    if mode == "v1" then AntiRagdollV1.start()
    elseif mode == "v2" then startAntiRagdollV2() end
    if _G.updateAntiRagdollUI then _G.updateAntiRagdollUI(mode) end
    saveAllSettings()
end

local AntiDieModule = {
    enabled      = false,
    heartConn    = nil,
    deathConns   = {},
    charConn     = nil,
    humanoid     = nil,
    originalByHumanoid = setmetatable({}, {__mode = "k"}),
}

local function disconnectAntiDieAll()
    for _, c in ipairs(AntiDieModule.deathConns) do
        pcall(function() c:Disconnect() end)
    end
    AntiDieModule.deathConns = {}
    if AntiDieModule.heartConn then
        pcall(function() AntiDieModule.heartConn:Disconnect() end)
        AntiDieModule.heartConn = nil
    end
end

local function protectAntiDieChar(char)
    if not char then return end
    local hum = char:WaitForChild("Humanoid", 5)
    if not hum then return end

    if not AntiDieModule.originalByHumanoid[hum] then
        local ok, snapshot = pcall(function()
            return {
                MaxHealth = hum.MaxHealth,
                Health = hum.Health,
                BreakJointsOnDeath = hum.BreakJointsOnDeath,
                DeadEnabled = hum:GetStateEnabled(Enum.HumanoidStateType.Dead),
            }
        end)
        if ok then AntiDieModule.originalByHumanoid[hum] = snapshot end
    end
    -- Keep health within the Humanoid's legitimate MaxHealth range.
    hum.Health = hum.MaxHealth
    pcall(function()
        hum.BreakJointsOnDeath = false
    end)
    AntiDieModule.humanoid = hum

    table.insert(AntiDieModule.deathConns, hum.StateChanged:Connect(function(_, new)
        if not AntiDieModule.enabled then return end
        if new == Enum.HumanoidStateType.Dead then
            hum.Health = hum.MaxHealth
            pcall(function()
                hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
            end)
        end
    end))

    table.insert(AntiDieModule.deathConns, hum:GetPropertyChangedSignal("Health"):Connect(function()
        if AntiDieModule.enabled and hum.Health < hum.MaxHealth then
            hum.Health = hum.MaxHealth
        end
    end))

    if AntiDieModule.heartConn then
        pcall(function() AntiDieModule.heartConn:Disconnect() end)
    end
    AntiDieModule.heartConn = RunService.Heartbeat:Connect(function()
        if AntiDieModule.enabled and hum and hum.Parent and hum.Health < hum.MaxHealth then
            hum.Health = hum.MaxHealth
        end
    end)
end

local function activateOnCharacter(char)
    if not AntiDieModule.enabled then return end
    protectAntiDieChar(char or LP.Character)
end

function AntiDieModule.start()
    AntiDieModule.enabled = true
    disconnectAntiDieAll()
    protectAntiDieChar(LP.Character)

    if AntiDieModule.charConn then
        pcall(function() AntiDieModule.charConn:Disconnect() end)
    end
    AntiDieModule.charConn = LP.CharacterAdded:Connect(function(char)
        if not AntiDieModule.enabled then return end
        task.wait(0.1)
        disconnectAntiDieAll()
        protectAntiDieChar(char)
    end)
    print("[AntiDie] Activado (Envy logic)")
end

function AntiDieModule.stop()
    AntiDieModule.enabled = false
    disconnectAntiDieAll()
    if AntiDieModule.charConn then
        pcall(function() AntiDieModule.charConn:Disconnect() end)
        AntiDieModule.charConn = nil
    end

    local char = LP.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        local snapshot = AntiDieModule.originalByHumanoid[hum]
        pcall(function()
            local deadEnabled = true
            if snapshot and snapshot.DeadEnabled ~= nil then
                deadEnabled = snapshot.DeadEnabled
            end
            hum:SetStateEnabled(Enum.HumanoidStateType.Dead, deadEnabled)
            if snapshot then
                hum.MaxHealth = snapshot.MaxHealth
                hum.Health = math.clamp(snapshot.Health, 0, snapshot.MaxHealth)
                hum.BreakJointsOnDeath = snapshot.BreakJointsOnDeath
            end
        end)
        AntiDieModule.originalByHumanoid[hum] = nil
    end
    AntiDieModule.humanoid = nil
    print("[AntiDie] Desactivado")
end

_G.AntiDie = AntiDieModule

local AntiFlingShieldModule = {
    enabled = false,
    loop = nil,
    velocityThreshold = 80,
}

local function stabilizeRoot(root)
    if not root or not root.Parent then return end
    if batDesyncTpEnabled then return end
    if dropActive or tick() < _globalMovementLock then return end
    local velocity
    local ok = pcall(function() velocity = root.AssemblyLinearVelocity end)
    if not ok or typeof(velocity) ~= "Vector3" then return end
    local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
    local threshold = math.max(80, (NS or 60) * 1.6)
    if horizontal.Magnitude <= threshold then return end
    local stabilized = _V3new(0, velocity.Y, 0)
    pcall(function() root.AssemblyLinearVelocity = stabilized end)
    pcall(function() root.AssemblyAngularVelocity = _V3zero end)
end

function AntiFlingShieldModule.start()
    AntiFlingShieldModule.enabled = true
    if AntiFlingShieldModule.loop then AntiFlingShieldModule.loop:Disconnect() end
    AntiFlingShieldModule.loop = RunService.Heartbeat:Connect(function()
        if not AntiFlingShieldModule.enabled then return end
        local char = LP.Character
        stabilizeRoot(char and char:FindFirstChild("HumanoidRootPart"))
    end)
    print("[AntiFlingShield] Activado (interno)")
end

function AntiFlingShieldModule.stop()
    AntiFlingShieldModule.enabled = false
    if AntiFlingShieldModule.loop then
        AntiFlingShieldModule.loop:Disconnect()
        AntiFlingShieldModule.loop = nil
    end
    print("[AntiFlingShield] Desactivado (interno)")
end

_G.AntiFlingShield = AntiFlingShieldModule

do
    local _ragCountdownRunning = false
    local function _getRagBillboard()
        local char = LP.Character
        if not char then return nil, nil end
        local head = char:FindFirstChild("Head")
        if not head then return nil, nil end
        local pGui = LP.PlayerGui
        local existing = pGui:FindFirstChild("RagCountdownBillboard")
        if existing then existing:Destroy() end
        local bb = Instance.new("BillboardGui")
        bb.Name = "RagCountdownBillboard"
        bb.Size = UDim2.new(0, 84, 0, 42)
        bb.StudsOffset = _V3new(0, 7.0, 0)
        bb.AlwaysOnTop = true
        bb.Adornee = head
        bb.Parent = pGui
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.AnchorPoint = Vector2.new(0.5, 0.5)
        lbl.Position = UDim2.new(0.5, 0, 0.5, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = SHOX_UI_FONT
        lbl.TextScaled = true
        lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        lbl.TextStrokeTransparency = 1
        lbl.Text = ""
        lbl.Parent = bb
        local grad = Instance.new("UIGradient", lbl)
        grad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 200, 210)),
            ColorSequenceKeypoint.new(0.3, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(0.7, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 210)),
        })
        grad.Rotation = 45
        grad.Offset = Vector2.new(0,0)
        return bb, lbl
    end

    local function _ragPunch(lbl, text)
        if not (lbl and lbl.Parent) then return end
        lbl.Text = text
    end

    local function _startRagCountdown()
        if _ragCountdownRunning then return end
        _ragCountdownRunning = true
        task.spawn(function()
            local bb, lbl = _getRagBillboard()
            if not bb then _ragCountdownRunning = false; return end
            local timeLeft = 2.5
            local step = 0.1
            while timeLeft > 0 and bb.Parent do
                _ragPunch(lbl, string.format("%.1f", timeLeft))
                task.wait(step)
                timeLeft = timeLeft - step
            end
            if bb and bb.Parent then
                _ragPunch(lbl, "READY!")
                task.wait(0.5)
                if bb and bb.Parent then bb:Destroy() end
            end
            _ragCountdownRunning = false
        end)
    end

    local _wasRagdolled = false
    RunService.Heartbeat:Connect(function()
        local char = LP.Character
        if not char then _wasRagdolled = false; return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then _wasRagdolled = false; return end
        local st = hum:GetState()
        local inRag = st == Enum.HumanoidStateType.Physics
                   or st == Enum.HumanoidStateType.Ragdoll
                   or st == Enum.HumanoidStateType.FallingDown
        if inRag and not _wasRagdolled then
            _wasRagdolled = true
            _startRagCountdown()
        elseif not inRag then
            _wasRagdolled = false
        end
    end)
end

espHighlightCache = espHighlightCache or {}
espBillboardCache = espBillboardCache or {}
espTracerCache = espTracerCache or {}
local espConn = nil
local _espLastRun = 0
profileImageCache = {}

local function clearESP()
    for plr in pairs(espHighlightCache) do
        pcall(function() espHighlightCache[plr]:Destroy() end)
    end
    for plr in pairs(espBillboardCache) do
        pcall(function() espBillboardCache[plr]:Destroy() end)
    end
    for plr in pairs(espTracerCache) do
        for _, ln in ipairs(espTracerCache[plr]) do
            pcall(function() ln.Visible = false; ln:Destroy() end)
        end
    end
    espHighlightCache = {}
    espBillboardCache = {}
    espTracerCache = {}
end

local function makeESPTracers()
    if not (Drawing and type(Drawing.new) == "function") then return nil end
    local color = getThemeColor()
    local outer = Drawing.new("Line")
    outer.Color = color
    outer.Thickness = 2.2
    outer.Transparency = 0.90
    outer.Visible = false
    local mid = Drawing.new("Line")
    mid.Color = color
    mid.Thickness = 1.2
    mid.Transparency = 0.74
    mid.Visible = false
    local core = Drawing.new("Line")
    core.Color = color
    core.Thickness = 0.6
    core.Transparency = 0.10
    core.Visible = false
    return {outer, mid, core}
end

local function updateESP()
    local now = _tick()
    if now - _espLastRun < 0.05 then return end
    _espLastRun = now
    if not espEnabled then clearESP(); return end
    local myChar = LP.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local myPos = myRoot.Position
    local myScreenPos, myOnScreen = camera:WorldToViewportPoint(myPos)
    local myVec = Vector2.new(myScreenPos.X, myScreenPos.Y)
    local currentPlayers = _GetPlayersCached()
    local plrSet = {}
    for _, p in ipairs(currentPlayers) do plrSet[p] = true end
    for plr in pairs(espHighlightCache) do
        if not plrSet[plr] then
            pcall(function() espHighlightCache[plr]:Destroy() end)
            espHighlightCache[plr] = nil
        end
    end
    for plr in pairs(espBillboardCache) do
        if not plrSet[plr] then
            pcall(function() espBillboardCache[plr]:Destroy() end)
            espBillboardCache[plr] = nil
        end
    end
    for plr in pairs(espTracerCache) do
        if not plrSet[plr] then
            for _, ln in ipairs(espTracerCache[plr]) do
                pcall(function() ln.Visible = false; ln:Destroy() end)
            end
            espTracerCache[plr] = nil
        end
    end
    local color = getThemeColor()
    for _, plr in ipairs(currentPlayers) do
        if plr == LP then continue end
        local char = plr.Character
        if not char then
            if espHighlightCache[plr] then
                pcall(function() espHighlightCache[plr]:Destroy() end)
                espHighlightCache[plr] = nil
            end
            if espBillboardCache[plr] then
                pcall(function() espBillboardCache[plr]:Destroy() end)
                espBillboardCache[plr] = nil
            end
            if espTracerCache[plr] then
                for _, ln in ipairs(espTracerCache[plr]) do
                    pcall(function() ln.Visible = false end)
                end
            end
            continue
        end
        local tRoot = char:FindFirstChild("HumanoidRootPart")
        local tHead = char:FindFirstChild("Head")
        local tHum = char:FindFirstChildOfClass("Humanoid")
        local alive = tRoot and tHead and tHum and tHum.Health > 0
        if alive then
            local hl = espHighlightCache[plr]
            if not hl or not hl.Parent or hl.Parent ~= char then
                if hl then pcall(function() hl:Destroy() end) end
                hl = Instance.new("Highlight")
                hl.Name = "FictionHubESP"
                hl.FillColor = color
                hl.FillTransparency = 0.72
                hl.OutlineColor = color
                hl.OutlineTransparency = 0.05
                hl.Adornee = char
                hl.Parent = char
                espHighlightCache[plr] = hl
            end
            local bb = espBillboardCache[plr]
            if not bb or not bb.Parent then
                if bb then pcall(function() bb:Destroy() end) end
                bb = Instance.new("BillboardGui")
                bb.Name = "ProfilePic"
                bb.Size = UDim2.new(0, 56, 0, 56)
                bb.StudsOffset = _V3new(0, 3.8, 0)
                bb.Adornee = tHead
                bb.AlwaysOnTop = true
                bb.Parent = tHead
                local img = Instance.new("ImageLabel", bb)
                img.Size = UDim2.new(1, -6, 1, -6)
                img.Position = UDim2.new(0, 3, 0, 3)
                img.BackgroundTransparency = 1
                img.Image = "rbxassetid://0"
                img.ScaleType = Enum.ScaleType.Fit
                local circle = Instance.new("UICorner", img)
                circle.CornerRadius = UDim.new(1, 0)
                local stroke = Instance.new("UIStroke", img)
                stroke.Color = color
                stroke.Thickness = 1.5
                espBillboardCache[plr] = bb
                task.spawn(function()
                    local userId = plr.UserId
                    local url = profileImageCache[userId]
                    if not url then
                        local success, u = pcall(function()
                            return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
                        end)
                        if success and u and u ~= "" then
                            url = u
                            profileImageCache[userId] = url
                        else
                            url = "rbxassetid://0"
                        end
                    end
                    if img then img.Image = url end
                end)
            else
                if bb.Adornee ~= tHead then bb.Adornee = tHead end
                bb.Enabled = true
            end
            local lines = espTracerCache[plr]
            if not lines then
                lines = makeESPTracers()
                espTracerCache[plr] = lines or {}
            end
            if lines and #lines > 0 then
                local destPos = tRoot.Position
                local pos, onScreen = camera:WorldToViewportPoint(destPos)
                if onScreen and pos.Z > 0 and myOnScreen then
                    local tVec = Vector2.new(pos.X, pos.Y)
                    for _, ln in ipairs(lines) do
                        ln.From = myVec
                        ln.To = tVec
                        ln.Visible = true
                    end
                else
                    for _, ln in ipairs(lines) do ln.Visible = false end
                end
            end
        else
            if espHighlightCache[plr] then
                pcall(function() espHighlightCache[plr]:Destroy() end)
                espHighlightCache[plr] = nil
            end
            if espBillboardCache[plr] then
                pcall(function() espBillboardCache[plr]:Destroy() end)
                espBillboardCache[plr] = nil
            end
            if espTracerCache[plr] then
                for _, ln in ipairs(espTracerCache[plr]) do
                    pcall(function() ln.Visible = false end)
                end
            end
        end
    end
end

local function startESPLoop()
    if espConn then espConn:Disconnect() end
    espConn = RunService.RenderStepped:Connect(updateESP)
end

local function stopESPLoop()
    if espConn then espConn:Disconnect(); espConn = nil end
    clearESP()
end

function toggleESP(on)
    espEnabled = on
    if on then startESPLoop() else stopESPLoop() end
    if setESPVIsual then setESPVIsual(on) end
end

local _enemySpeedAcc = 0
function updateEnemySpeedLabels()
    _enemySpeedAcc = _enemySpeedAcc + 1
    if _enemySpeedAcc < 6 then return end
    _enemySpeedAcc = 0
    local color = getThemeColor()
    local players = _GetPlayersCached()
    for i = 1, #players do
        local player = players[i]
        if player ~= LP then
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local v = hrp.AssemblyLinearVelocity
                local speed = _sqrt(v.X*v.X + v.Z*v.Z)
                local label = enemySpeedLabels[player]
                if not label then
                    local head = char:FindFirstChild("Head")
                    if head then
                        local bb = Instance.new("BillboardGui")
                        bb.Size = UDim2.new(0, 100, 0, 25)
                        bb.StudsOffset = _V3new(0, 5.5, 0)
                        bb.AlwaysOnTop = true
                        bb.Name = "EnemySpeedGui"
                        bb.Parent = head
                        local tl = Instance.new("TextLabel", bb)
                        tl.Size = UDim2.new(1, 0, 1, 0)
                        tl.BackgroundTransparency = 1
                        tl.TextColor3 = color
                        tl.Font = SHOX_UI_FONT
                        tl.TextScaled = true
                        tl.TextStrokeTransparency = 1
                        tl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                        enemySpeedLabels[player] = tl
                        label = tl
                    end
                elseif label.Parent and label.Parent.Parent ~= char then
                    local head = char:FindFirstChild("Head")
                    if head then label.Parent.Parent = head end
                end
                if label then
                    label.Text = string.format("%.1f", speed)
                    if label.TextColor3 ~= color then label.TextColor3 = color end
                end
            else
                local label = enemySpeedLabels[player]
                if label and label.Parent and label.Parent.Parent then label.Parent.Parent = nil end
                enemySpeedLabels[player] = nil
            end
        end
    end
end

Players.PlayerRemoving:Connect(function(player)
    local label = enemySpeedLabels[player]
    if label then
        pcall(function()
            local billboard = label.Parent
            if billboard then billboard:Destroy() end
        end)
    end
    enemySpeedLabels[player] = nil
end)

function startEnemySpeed()
    if enemySpeedConn then enemySpeedConn:Disconnect() end
    enemySpeedConn = RunService.Heartbeat:Connect(updateEnemySpeedLabels)
end

function stopEnemySpeed()
    if enemySpeedConn then enemySpeedConn:Disconnect(); enemySpeedConn = nil end
end

local function getClosestTargetBody()
    local char = LP.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local rpos = root.Position
    local closest, minDist = nil, _huge
    local plist = _GetPlayersCached()
    for i = 1, #plist do
        local plr = plist[i]
        if plr ~= LP then
            local c = plr.Character
            if c then
                local tRoot = c:FindFirstChild("HumanoidRootPart")
                if tRoot then
                    local hum = c:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        local dx = tRoot.Position.X - rpos.X
                        local dy = tRoot.Position.Y - rpos.Y
                        local dz = tRoot.Position.Z - rpos.Z
                        local d = dx*dx + dy*dy + dz*dz
                        if d < minDist then minDist = d; closest = tRoot end
                    end
                end
            end
        end
    end
    return closest
end

local function _bodyLockTick()
    local char = LP.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local target = getClosestTargetBody()
    if not target then
        if not hum.AutoRotate then hum.AutoRotate = true end
        return
    end

    local offset = target.Position - root.Position
    if offset.Magnitude > bodyLockRange then
        if not hum.AutoRotate then hum.AutoRotate = true end
        return
    end
    if hum.AutoRotate then hum.AutoRotate = false end

    local targetVelocity = target.AssemblyLinearVelocity
    local speed = math.min(targetVelocity.Magnitude, 55)
    local smoothedTargetVelocity = targetVelocity.Magnitude > 55 and targetVelocity.Unit * speed or targetVelocity
    local predictTime = _clamp(smoothedTargetVelocity.Magnitude / 100, 0.06, 0.25)
    local predicted = target.Position + smoothedTargetVelocity * predictTime
    local flatTarget = _V3new(predicted.X, root.Position.Y, predicted.Z)
    local flatDirection = flatTarget - root.Position
    if flatDirection.Magnitude <= 0.1 then return end

    -- Rotate on the horizontal plane only; avoid writing AngularVelocity every frame.
    local goal = CFrame.lookAt(root.Position, flatTarget)
    root.CFrame = root.CFrame:Lerp(goal, 0.25)
end

function startBodyLock()
    if _bodyLockConn then _bodyLockConn:Disconnect() end
    _bodyLockConn = RunService.Heartbeat:Connect(function()
        if not bodyLockEnabled or _blSuppressCount > 0 then return end
        local ok, err = xpcall(_bodyLockTick, debug.traceback)
        if not ok then
            warn("[ShoxHub] Body Lock tick recovered: " .. tostring(err))
        end
    end)
end

function stopBodyLock()
    if _bodyLockConn then
        _bodyLockConn:Disconnect()
        _bodyLockConn = nil
    end
    local c = LP.Character
    local root = c and c:FindFirstChild("HumanoidRootPart")
    if root then
        root.AssemblyAngularVelocity = _V3zero
        -- Preserve the Humanoid's current jump/fall velocity when stopping the lock.
    end
    local hum2 = c and c:FindFirstChildOfClass("Humanoid")
    if hum2 then hum2.AutoRotate = true end
end

function _suppressBodyLock()
    if _blSuppressCount > 0 then return end
    _blSuppressCount = _blSuppressCount + 1
    if _blSuppressCount == 1 and bodyLockEnabled then
        _blWasEnabled = true
        stopBodyLock()
        if bodyLockSetVisual then bodyLockSetVisual(false) end
        if _blRestoreTimer then
            task.cancel(_blRestoreTimer)
            _blRestoreTimer = nil
        end
    end
end

function _unsuppressBodyLock(delayed)
    if _blSuppressCount > 0 then
        _blSuppressCount = _blSuppressCount - 1
    end
    if _blSuppressCount == 0 and _blWasEnabled then
        _blWasEnabled = false
        if _blRestoreTimer then
            pcall(task.cancel, _blRestoreTimer)
            _blRestoreTimer = nil
        end
        local function restore()
            _blRestoreTimer = nil
            if bodyLockEnabled then
                startBodyLock()
                if bodyLockSetVisual then bodyLockSetVisual(true) end
            end
        end
        if delayed then
            _blRestoreTimer = task.delay(1, restore)
        else
            restore()
        end
    end
end

LP.CharacterAdded:Connect(function()
    if stopBatCounter then pcall(stopBatCounter) end
    _blSuppressCount = 0
    _blWasEnabled = false
    if _blRestoreTimer then
        pcall(task.cancel, _blRestoreTimer)
        _blRestoreTimer = nil
    end
    task.defer(function()
        if bodyLockEnabled then
            startBodyLock()
            if bodyLockSetVisual then bodyLockSetVisual(true) end
        end
    end)
end)

function setupSpeedIndicator(char)
    local head = char:WaitForChild("Head", 5)
    if not head then return end

    local oldBB = head:FindFirstChild("FictionHubSpeedIndicator")
    if oldBB then oldBB:Destroy() end
    local oldDiscord = head:FindFirstChild("DiscordText")
    if oldDiscord then oldDiscord:Destroy() end

    local bb = Instance.new("BillboardGui", head)
    bb.Name = "FictionHubSpeedIndicator"
    bb.Size = UDim2.new(0, 240, 0, 46)
    bb.StudsOffset = _V3new(0, 2.35, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0

    speedLabel = Instance.new("TextLabel", bb)
    speedLabel.Name = "Speed"
    speedLabel.Size = UDim2.new(1, 0, 0, 24)
    speedLabel.Position = UDim2.new(0, 0, 0, 0)
    speedLabel.BackgroundTransparency = 1
    speedLabel.Text = "0 speed"
    speedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    speedLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    speedLabel.TextStrokeTransparency = 0.08
    speedLabel.Font = SHOX_UI_FONT
    speedLabel.TextSize = 18
    speedLabel.TextXAlignment = Enum.TextXAlignment.Center
    speedLabel.ZIndex = 10
end

local unwalkSavedAnimate = nil

function startUnwalk()
    local c = LP.Character
    if not c then return end
    local hum = c:FindFirstChildOfClass("Humanoid")
    if hum then
        for _, t in ipairs(hum:GetPlayingAnimationTracks()) do pcall(function() t:Stop() end) end
    end
    local anim = c:FindFirstChild("Animate")
    if anim then
        unwalkSavedAnimate = anim:Clone()
        anim:Destroy()
    end
end

function stopUnwalk()
    local c = LP.Character
    if c then
        local existing = c:FindFirstChild("Animate")
        if not existing then
            local src = game:GetService("StarterPlayer"):FindFirstChildOfClass("StarterCharacterScripts")
            local starterAnim = src and src:FindFirstChild("Animate")
            if starterAnim then
                starterAnim:Clone().Parent = c
            elseif unwalkSavedAnimate then
                unwalkSavedAnimate:Clone().Parent = c
            end
        end
    end
    unwalkSavedAnimate = nil
end

function refreshSpeedModeLabel()
    if modeValLbl then
        if CarrySystem then
            local status = CarrySystem:getStatus()
            modeValLbl.Text = status
        else
            if laggerCarryToggled then modeValLbl.Text = "Lagger Carry"
            elseif laggerToggled then modeValLbl.Text = "Lagger"
            elseif speedMode then modeValLbl.Text = "Carry"
            else modeValLbl.Text = "Normal" end
        end
    end
    if laggerCarryToggled then _G.AceCurrentSpeedMode = "Lagger Carry"
    elseif laggerToggled then _G.AceCurrentSpeedMode = "Lagger"
    elseif speedMode then _G.AceCurrentSpeedMode = "Carry"
    else _G.AceCurrentSpeedMode = "Normal" end

    if setCarryModeVisual then setCarryModeVisual(speedMode) end
    if setLaggerModeVisual then setLaggerModeVisual(laggerToggled) end
    if setLaggerCarryVisual then setLaggerCarryVisual(laggerCarryToggled) end

    if CarrySystem then
        CarrySystem.speedToggled = speedMode
        if laggerCarryToggled then
            CarrySystem:setLaggerMode(2)
        elseif laggerToggled then
            CarrySystem:setLaggerMode(1)
        else
            CarrySystem:setLaggerMode(0)
        end
    end
end

function resetMovementState()
    refreshSpeedModeLabel()
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
    end
    if mobSetCarry then mobSetCarry(speedMode) end
    if setLaggerModeVisual then setLaggerModeVisual(laggerToggled) end
    if setLaggerCarryVisual then setLaggerCarryVisual(laggerCarryToggled) end
    if CarrySystem then
        CarrySystem.speedToggled = speedMode
        if laggerCarryToggled then
            CarrySystem:setLaggerMode(2)
        elseif laggerToggled then
            CarrySystem:setLaggerMode(1)
        else
            CarrySystem:setLaggerMode(0)
        end
    end
end

function toggleCarryMode()
    if laggerToggled or laggerCarryToggled then
        laggerToggled = false; laggerCarryToggled = false; speedMode = true
    else speedMode = not speedMode end
    resetMovementState()
end

function toggleLaggerMode()
    if laggerCarryToggled then laggerCarryToggled = false end
    speedMode = false; laggerToggled = not laggerToggled
    resetMovementState()
end
function toggleLaggerCarryMode()
    if laggerToggled then laggerToggled = false end
    speedMode = false; laggerCarryToggled = not laggerCarryToggled
    resetMovementState()
end

function toggleLaggerCycle()
    if speedMode then
        speedMode = false
        laggerToggled = true
        laggerCarryToggled = false
    elseif laggerToggled then
        speedMode = false
        laggerToggled = false
        laggerCarryToggled = true
    else
        speedMode = true
        laggerToggled = false
        laggerCarryToggled = false
    end
    resetMovementState()
end

local function applyAutoPathVelocity(root, direction, requestedSpeed, dt)
    if not root or not root.Parent then return end
    if tick() < _globalMovementLock then return end
    local flat = _V3new(direction.X, 0, direction.Z)
    if flat.Magnitude < 0.001 then return end

    -- Follow the configured normal speed (NS=60); the previous hard 30 cap
    -- silently halved Auto Left/Right speed even when Lagger mode was disabled.
    local normalCap = math.max(tonumber(NS) or 60, 1)
    local speed = math.clamp(tonumber(requestedSpeed) or normalCap, 1, normalCap)
    local current = root.AssemblyLinearVelocity
    local desiredX = flat.Unit.X * speed
    local desiredZ = flat.Unit.Z * speed
    local safeDt = math.clamp(tonumber(dt) or (1 / 60), 1 / 240, 0.1)
    local alpha = 1 - math.exp(-safeDt * 24)

    local targetVel = _V3new(desiredX, 0, desiredZ)
    local smoothed = _V3new(current.X, 0, current.Z):Lerp(targetVel, alpha)
    if smoothed.Magnitude > 0.001 then
        smoothed = smoothed.Unit * speed
    else
        smoothed = targetVel
    end
    root.AssemblyLinearVelocity = _V3new(smoothed.X, current.Y, smoothed.Z)
end

function stopAutoLeft()
    autoLeftEnabled = false
    if alConn then alConn:Disconnect(); alConn = nil end
    alPhase = 1
    local char = LP.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if hum then hum:Move(_V3zero, false) end
        if root then
            local velocity = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = _V3new(0, velocity.Y, 0)
        end
    end
    if autoLeftSetVisual then autoLeftSetVisual(false) end
    if mobSetAutoLeft then mobSetAutoLeft(false) end
    if _alSuppressed then _alSuppressed = false; _unsuppressBodyLock(true) end
end

function startAutoLeft()
    if not _G.AmbitiousSafeModeTryStart() then
        autoLeftEnabled = false
        if autoLeftSetVisual then autoLeftSetVisual(false) end
        return
    end
    if autoRightEnabled then
        autoRightEnabled = false
        stopAutoRight()
        if autoRightSetVisual then autoRightSetVisual(false) end
        if mobSetAutoRight then mobSetAutoRight(false) end
    end
    if dropActive then stopDropBrainrot() end
    disableAllAimbots()
    if not _alSuppressed then _alSuppressed = true; _suppressBodyLock() end
    if alConn then alConn:Disconnect() end
    alPhase = 1
    local startedAt = os.clock()
    local routeLength = (AP.L1 - (LP.Character and LP.Character:GetPivot().Position or AP.L1)).Magnitude + (AP.L2 - AP.L1).Magnitude
    local routeTimeout = math.clamp(routeLength / math.max(math.abs(tonumber(NS) or 0), 1) * 3 + 8, 12, 180)
    alConn = RunService.Heartbeat:Connect(function(dt)
        if not autoLeftEnabled then return end
        if os.clock() - startedAt > routeTimeout then
            autoLeftEnabled = false
            stopAutoLeft()
            return
        end
        local char = LP.Character
        if not char or not char.Parent then
            autoLeftEnabled = false
            stopAutoLeft()
            return
        end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then return end
        local spd = math.max(0, tonumber(NS) or 0)
        local reach = math.max(1, spd * dt * 1.5)
        if alPhase == 1 then
            local tgt = _V3new(AP.L1.X, root.Position.Y, AP.L1.Z)
            if (tgt - root.Position).Magnitude < reach then
                alPhase = 2
                local d = AP.L2 - root.Position
                local mv = _V3new(d.X, 0, d.Z)
                if mv.Magnitude > 0.001 then mv = mv.Unit else mv = _V3zero end
                hum:Move(mv, false)
                applyAutoPathVelocity(root, mv, spd, dt)
                return
            end
            local d = AP.L1 - root.Position
            local mv = _V3new(d.X, 0, d.Z)
            if mv.Magnitude > 0.001 then mv = mv.Unit else mv = _V3zero end
            hum:Move(mv, false)
            applyAutoPathVelocity(root, mv, spd, dt)
        elseif alPhase == 2 then
            local tgt = _V3new(AP.L2.X, root.Position.Y, AP.L2.Z)
            if (tgt - root.Position).Magnitude < reach then
                hum:Move(_V3zero, false)
                local currentVelocity = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = _V3new(0, currentVelocity.Y, 0)
                autoLeftEnabled = false
                if alConn then alConn:Disconnect(); alConn = nil end
                alPhase = 1
                if autoLeftSetVisual then autoLeftSetVisual(false) end
                if mobSetAutoLeft then mobSetAutoLeft(false) end
                _unsuppressBodyLock(true)
                local facePos = _V3new(AP.L_FACE.X, root.Position.Y, AP.L_FACE.Z)
                if (facePos - root.Position).Magnitude > 0.01 then
                    root.CFrame = _CFnew(root.Position, facePos)
                end
                return
            end
            local d = AP.L2 - root.Position
            local mv = _V3new(d.X, 0, d.Z)
            if mv.Magnitude > 0.001 then mv = mv.Unit else mv = _V3zero end
            hum:Move(mv, false)
            applyAutoPathVelocity(root, mv, spd, dt)
        end
    end)
end

function stopAutoRight()
    autoRightEnabled = false
    if arConn then arConn:Disconnect(); arConn = nil end
    arPhase = 1
    local char = LP.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if hum then hum:Move(_V3zero, false) end
        if root then
            local velocity = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = _V3new(0, velocity.Y, 0)
        end
    end
    if autoRightSetVisual then autoRightSetVisual(false) end
    if mobSetAutoRight then mobSetAutoRight(false) end
    if _arSuppressed then _arSuppressed = false; _unsuppressBodyLock(true) end
end

function startAutoRight()
    if not _G.AmbitiousSafeModeTryStart() then
        autoRightEnabled = false
        if autoRightSetVisual then autoRightSetVisual(false) end
        return
    end
    if autoLeftEnabled then
        autoLeftEnabled = false
        stopAutoLeft()
        if autoLeftSetVisual then autoLeftSetVisual(false) end
        if mobSetAutoLeft then mobSetAutoLeft(false) end
    end
    if dropActive then stopDropBrainrot() end
    disableAllAimbots()
    if not _arSuppressed then _arSuppressed = true; _suppressBodyLock() end
    if arConn then arConn:Disconnect() end
    arPhase = 1
    local startedAt = os.clock()
    local routeLength = (AP.R1 - (LP.Character and LP.Character:GetPivot().Position or AP.R1)).Magnitude + (AP.R2 - AP.R1).Magnitude
    local routeTimeout = math.clamp(routeLength / math.max(math.abs(tonumber(NS) or 0), 1) * 3 + 8, 12, 180)
    arConn = RunService.Heartbeat:Connect(function(dt)
        if not autoRightEnabled then return end
        if os.clock() - startedAt > routeTimeout then
            autoRightEnabled = false
            stopAutoRight()
            return
        end
        local char = LP.Character
        if not char or not char.Parent then
            autoRightEnabled = false
            stopAutoRight()
            return
        end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then return end
        local spd = math.max(0, tonumber(NS) or 0)
        local reach = math.max(1, spd * dt * 1.5)
        if arPhase == 1 then
            local tgt = _V3new(AP.R1.X, root.Position.Y, AP.R1.Z)
            if (tgt - root.Position).Magnitude < reach then
                arPhase = 2
                local d = AP.R2 - root.Position
                local mv = _V3new(d.X, 0, d.Z)
                if mv.Magnitude > 0.001 then mv = mv.Unit else mv = _V3zero end
                hum:Move(mv, false)
                applyAutoPathVelocity(root, mv, spd, dt)
                return
            end
            local d = AP.R1 - root.Position
            local mv = _V3new(d.X, 0, d.Z)
            if mv.Magnitude > 0.001 then mv = mv.Unit else mv = _V3zero end
            hum:Move(mv, false)
            applyAutoPathVelocity(root, mv, spd, dt)
        elseif arPhase == 2 then
            local tgt = _V3new(AP.R2.X, root.Position.Y, AP.R2.Z)
            if (tgt - root.Position).Magnitude < reach then
                hum:Move(_V3zero, false)
                local currentVelocity = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = _V3new(0, currentVelocity.Y, 0)
                autoRightEnabled = false
                if arConn then arConn:Disconnect(); arConn = nil end
                arPhase = 1
                if autoRightSetVisual then autoRightSetVisual(false) end
                if mobSetAutoRight then mobSetAutoRight(false) end
                _unsuppressBodyLock(true)
                local facePos = _V3new(AP.R_FACE.X, root.Position.Y, AP.R_FACE.Z)
                if (facePos - root.Position).Magnitude > 0.01 then
                    root.CFrame = _CFnew(root.Position, facePos)
                end
                return
            end
            local d = AP.R2 - root.Position
            local mv = _V3new(d.X, 0, d.Z)
            if mv.Magnitude > 0.001 then mv = mv.Unit else mv = _V3zero end
            hum:Move(mv, false)
            applyAutoPathVelocity(root, mv, spd, dt)
        end
    end)
end

function getClosestTarget()
    local char = LP.Character
    if not char or not char.Parent then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    local ownHumanoid = char:FindFirstChildOfClass("Humanoid")
    if not root or not ownHumanoid or ownHumanoid.Health <= 0 then return nil end

    local rpos = root.Position
    local closest, minDistSq = nil, _huge
    local plist = _GetPlayersCached()
    for i = 1, #plist do
        local plr = plist[i]
        -- This is intentionally player-vs-player target selection: every other
        -- living player is eligible, regardless of the game's Remote/object names.
        if plr ~= LP and plr.Parent == Players then
            local targetCharacter = plr.Character
            if targetCharacter and targetCharacter.Parent then
                local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
                local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
                if targetRoot and targetHumanoid and targetHumanoid.Health > 0 then
                    local offset = targetRoot.Position - rpos
                    local distanceSq = offset:Dot(offset)
                    if distanceSq < minDistSq then
                        minDistSq = distanceSq
                        closest = targetRoot
                    end
                end
            end
        end
    end
    return closest
end

local _nextBatSwingAt = 0
function trySwing()
    local now = _tick()
    if now < _nextBatSwingAt then return end
    local ok = pcall(function()
        local char = LP.Character
        if not char or not char.Parent then return end
        local bat = findBat()
        if not bat or not bat:IsA("Tool") then return end
        if bat.Parent ~= char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum:EquipTool(bat) end) end
            return
        end
        bat:Activate()
        _nextBatSwingAt = now + 0.1
    end)
    if not ok then _nextBatSwingAt = now + 0.2 end
end

function stopAimbotAdapt()
    if _aimbotConn then
        pcall(function() _aimbotConn:Disconnect() end)
        _aimbotConn = nil
    end
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.AutoRotate = (_prevAutoRotate == nil) and true or _prevAutoRotate
        hum.PlatformStand = false
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
    end
    if root then
        local velocity = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = _V3new(velocity.X, velocity.Y, velocity.Z)
        root.AssemblyAngularVelocity = _V3zero
    end
    _prevAutoRotate = nil
    lastMoveDir = _V3zero
    _unsuppressBodyLock(true)
end

function startAimbotAdapt()
    if _aimbotConn then return end
    _suppressBodyLock()
    local hum0 = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum0 then
        if _prevAutoRotate == nil then _prevAutoRotate = hum0.AutoRotate end
        hum0.AutoRotate = false
    end
    _aimbotConn = RunService.RenderStepped:Connect(function(dt)
        if not autoBatEnabled then return end
        local char = LP.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then return end
        if not char:FindFirstChildOfClass("Tool") then
            local bat = findBat()
            if bat then pcall(function() hum:EquipTool(bat) end) end
        end
        local target = getClosestTarget()
        if not target then return end
        local targetVel = target.AssemblyLinearVelocity
        local myPos = root.Position
        local targetPos = target.Position
        local predictPos = targetPos + targetVel * 0.14
        predictPos = predictPos + target.CFrame.LookVector * 0.3
        local direction = predictPos - myPos
        local flatDir = _V3new(direction.X, 0, direction.Z)
        if flatDir.Magnitude > 0 then flatDir = flatDir.Unit else flatDir = _V3new(0,0,0) end
        local desiredHeight = targetPos.Y + 3.7
        local yVel = (desiredHeight - myPos.Y) * 19.5 + targetVel.Y * 0.8
        if hum.FloorMaterial ~= Enum.Material.Air then yVel = math.max(yVel, 0) end
        yVel = _clamp(yVel, -35, 45)
        local desiredVel = _V3new(flatDir.X * BAT_AIMBOT_SPEED, yVel, flatDir.Z * BAT_AIMBOT_SPEED)
        local currentVelocity = root.AssemblyLinearVelocity
        local safeDt = math.clamp(tonumber(dt) or (1 / 60), 1 / 240, 0.1)
        local alpha = 1 - math.exp(-safeDt * 22)
        local nextVelocity = currentVelocity:Lerp(desiredVel, alpha)
        local velocityDelta = nextVelocity - currentVelocity
        local maxDelta = 420 * safeDt
        if velocityDelta.Magnitude > maxDelta then
            nextVelocity = currentVelocity + velocityDelta.Unit * maxDelta
        end
        local flatNext = _V3new(nextVelocity.X, 0, nextVelocity.Z)
        local flatDesired = _V3new(desiredVel.X, 0, desiredVel.Z)
        if flatNext.Magnitude > 0.1 and flatDesired.Magnitude > 0.1 then
            flatNext = flatNext.Unit * flatDesired.Magnitude
            nextVelocity = _V3new(flatNext.X, nextVelocity.Y, flatNext.Z)
        end
        root.AssemblyLinearVelocity = nextVelocity
        local speed3 = targetVel.Magnitude
        local predictTime = _clamp(speed3 / 150, 0.05, 0.2)
        local predictedPos = targetPos + targetVel * predictTime
        local toPredict = predictedPos - myPos
        if toPredict.Magnitude > 0.1 then
            local goalCF = _CFlookAt(myPos, predictedPos)
            local diffCF = root.CFrame:Inverse() * goalCF
            local rx, ry, rz = diffCF:ToEulerAnglesXYZ()
            rx = _clamp(rx, -2.5, 2.5)
            ry = _clamp(ry, -2.5, 2.5)
            rz = _clamp(rz, -2.5, 2.5)
            root.AssemblyAngularVelocity = root.CFrame:VectorToWorldSpace(_V3new(rx * 42, ry * 42, rz * 42))
        end
        local distToTarget = (root.Position - target.Position).Magnitude
        if distToTarget <= 8 then trySwing() end
    end)
end

function disableAutoBat()
    autoBatEnabled = false
    if autoBatSetVisual then autoBatSetVisual(false) end
    if mobSetAutoBat then mobSetAutoBat(false) end
    stopAimbotAdapt()
end

function enableAutoBat()
    if not _G.AmbitiousSafeModeTryStart() then
        autoBatEnabled = false
        if autoBatSetVisual then autoBatSetVisual(false) end
        return
    end
    if autoLeftEnabled then
        autoLeftEnabled = false
        if autoLeftSetVisual then autoLeftSetVisual(false) end
        stopAutoLeft()
    end
    if autoRightEnabled then
        autoRightEnabled = false
        if autoRightSetVisual then autoRightSetVisual(false) end
        stopAutoRight()
    end
    if batDesyncTpEnabled then toggleBatDesyncTp() end
    if autoBatV2Enabled then disableBatV2() end
    autoBatEnabled = true
    if autoBatSetVisual then autoBatSetVisual(true) end
    if mobSetAutoBat then mobSetAutoBat(true) end
    startAimbotAdapt()
end

-- ═══════════════════════════════════════════════════════════════
-- BAT BYPASS — Persecución autónoma con predicción de ping
-- (Reemplaza el módulo Anti Bypass anterior. Antes BAT V2.)
-- ═══════════════════════════════════════════════════════════════

BAT_V2_SPEED           = BAT_V2_SPEED           or 55
BAT_V2_HIT_DIST        = BAT_V2_HIT_DIST        or 4.5
BAT_V2_LEAD_STUDS      = BAT_V2_LEAD_STUDS      or 3
BAT_V2_BODY_LOCK_RANGE = BAT_V2_BODY_LOCK_RANGE or 60

local SnowVS = _G.SnowVS or {}
_G.SnowVS = SnowVS

SnowVS.BatBypass = SnowVS.BatBypass or {}
-- Alias legado para no romper referencias externas existentes
SnowVS.AimbotBypassV2 = SnowVS.BatBypass

local BB = SnowVS.BatBypass

BB.Enabled    = BB.Enabled    or false
BB.Connection = BB.Connection or nil

BB.Z = BB.Z or {
    targetPlayer          = nil,
    lastTargetPos         = nil,
    targetVelocity        = Vector3.zero,
    smoothedVelocity      = Vector3.zero,
    velocityHistory       = {},
    accelerationHistory   = {},
    aerialVelocityHistory = {},
    previousDirection     = nil,
    lastDirectionChangeTime = 0,
    airborneTime          = 0,
    lastActivationTime    = 0,
    currentPing           = 0.1,
    realPingMs            = 0,
}

BB.ZCFG = BB.ZCFG or {
    FOLLOW_SPEED                    = BAT_V2_SPEED,
    ACTIVATE_DISTANCE               = BAT_V2_HIT_DIST,
    MIN_FOLLOW_DISTANCE             = 1,
    PREDICTION_TIME                 = 0.22,
    PREDICT_AHEAD                   = BAT_V2_LEAD_STUDS,
    MAX_VELOCITY_CHANGE             = 150,
    VELOCITY_SMOOTHING              = 0.2,
    MAX_HORIZONTAL_VELOCITY         = 80,
    SERVER_TICKRATE                 = 1 / 60,
    MIN_PING_COMPENSATION           = 0.03,
    MAX_PING_COMPENSATION           = 0.25,
    ACCELERATION_PREDICTION_WEIGHT  = 0.3,
    DIRECTION_CHANGE_DETECTION_TIME = 0.12,
    QUICK_DIRECTION_CHANGE_MULTIPLIER = 1.5,
    GRAVITY                         = 196.2,
    AIR_CONTROL_FACTOR              = 0.8,
    MIN_AIRBORNE_TIME               = 0.08,
}

local function bbAverageVector(history)
    if #history == 0 then return Vector3.zero end
    local total = Vector3.zero
    for _, v in ipairs(history) do total += v end
    return total / #history
end

local function bbPushHistory(history, value, maximum)
    table.insert(history, value)
    if #history > maximum then table.remove(history, 1) end
end

function BB.FindBat()
    local char = LP.Character
    if not char then return nil end
    local equipped = char:FindFirstChildOfClass("Tool")
    if equipped then
        local n = equipped.Name:lower()
        if n:find("bat", 1, true) or n:find("slap", 1, true) then
            return equipped
        end
    end
    local bp = LP:FindFirstChildOfClass("Backpack")
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") then
                local n = tool.Name:lower()
                if n:find("bat", 1, true) or n:find("slap", 1, true) then
                    return tool
                end
            end
        end
    end
    return nil
end

local function bbResetTarget()
    local Z = BB.Z
    Z.targetPlayer          = nil
    Z.lastTargetPos         = nil
    Z.targetVelocity        = Vector3.zero
    Z.smoothedVelocity      = Vector3.zero
    Z.velocityHistory       = {}
    Z.accelerationHistory   = {}
    Z.aerialVelocityHistory = {}
    Z.previousDirection     = nil
    Z.airborneTime          = 0
end

local function bbNearestTarget(root)
    local nearest, nearestDistance = nil, math.huge
    for _, candidate in ipairs(_GetPlayersCached()) do
        if candidate ~= LP and candidate.Character then
            local targetCharacter = candidate.Character
            local targetRoot     = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
            local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
            if targetRoot and targetHumanoid and targetHumanoid.Health > 0 then
                local distance = (root.Position - targetRoot.Position).Magnitude
                if distance < nearestDistance then
                    nearest, nearestDistance = candidate, distance
                end
            end
        end
    end
    local current = BB.Z and BB.Z.targetPlayer
    if current and current ~= LP and current.Character then
        local currentChar = current.Character
        local currentRoot = currentChar:FindFirstChild("HumanoidRootPart")
        local currentHumanoid = currentChar:FindFirstChildOfClass("Humanoid")
        if currentRoot and currentHumanoid and currentHumanoid.Health > 0 then
            local currentDistance = (root.Position - currentRoot.Position).Magnitude
            if currentDistance <= nearestDistance * 1.15 + 2 then
                return current
            end
        end
    end
    return nearest
end

local function bbRotateRoot(root, direction, dt)
    if direction.Magnitude < 0.01 then return end
    local axis = root.CFrame.LookVector:Cross(direction.Unit)
    local angle = math.asin(math.clamp(axis.Magnitude, -1, 1))
    local angular = axis.Magnitude > 0.01 and axis.Unit * math.min(angle * 10, 8) or Vector3.zero
    root.AssemblyAngularVelocity = root.AssemblyAngularVelocity:Lerp(angular, math.min(math.max((tonumber(dt) or (1/60)) * 15, 0), 1))
end

local function bbSamplePing()
    local ok, value = pcall(function()
        return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    local Z = BB.Z
    if ok and type(value) == "number" then Z.realPingMs = math.floor(value) end
    Z.currentPing = math.clamp(
        Z.realPingMs / 1000,
        BB.ZCFG.MIN_PING_COMPENSATION,
        BB.ZCFG.MAX_PING_COMPENSATION
    )
end

BB.PingLoopStarted = BB.PingLoopStarted or false
BB.PingLoopGeneration = BB.PingLoopGeneration or 0
local function bbStartPingLoop()
    if BB.PingLoopStarted then return end
    BB.PingLoopGeneration = BB.PingLoopGeneration + 1
    local generation = BB.PingLoopGeneration
    BB.PingLoopStarted = true
    task.spawn(function()
        while BB.PingLoopStarted and BB.Enabled and generation == BB.PingLoopGeneration do
            pcall(bbSamplePing)
            task.wait(0.5)
        end
        if generation == BB.PingLoopGeneration then
            BB.PingLoopStarted = false
        end
    end)
end

-- Stubs para compatibilidad con la API antigua (Body Lock ya no se usa aparte)
function BB.StartBodyLock() end
function BB.StopBodyLock()  end

function BB.Stop()
    local Z = BB.Z
    BB.Enabled = false
    BB.PingLoopGeneration = (BB.PingLoopGeneration or 0) + 1
    BB.PingLoopStarted = false
    if BB.Connection then
        BB.Connection:Disconnect()
        BB.Connection = nil
    end
    local char     = LP.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    local root     = char and char:FindFirstChild("HumanoidRootPart")
    if humanoid then humanoid.AutoRotate = true end
    if root     then root.AssemblyAngularVelocity = Vector3.zero end
    bbResetTarget()
    Z.lastActivationTime = 0
    if BB.BodyLockSuppressed then
        BB.BodyLockSuppressed = false
        _unsuppressBodyLock(true)
    end
end

function BB.Start()
    if BB.Connection then return end

    local char     = LP.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    local root     = char and char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root then return end

    BB.Enabled = true
    bbStartPingLoop()
    humanoid.AutoRotate = false
    if not BB.BodyLockSuppressed then
        BB.BodyLockSuppressed = true
        _suppressBodyLock()
    end

    local bat = BB.FindBat()
    if bat and bat.Parent ~= char then
        pcall(function() humanoid:EquipTool(bat) end)
    end

    BB.Connection = RunService.RenderStepped:Connect(function(dt)
        if not BB.Enabled then BB.Stop(); return end
        local Z     = BB.Z
        local ZCFG  = BB.ZCFG

        -- Refresca velocidad según modo actual (Normal/Lagger/Lagger Carry)
        if _G.AceGetAntiBypassAimbotSpeed then
            ZCFG.FOLLOW_SPEED = _G.AceGetAntiBypassAimbotSpeed()
        end

        local currentChar     = LP.Character
        local currentRoot     = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
        local currentHumanoid = currentChar and currentChar:FindFirstChildOfClass("Humanoid")
        if not currentRoot or not currentHumanoid or currentHumanoid.Health <= 0 then return end

        currentHumanoid.AutoRotate = false
        root, humanoid = currentRoot, currentHumanoid

        bat = currentChar:FindFirstChildOfClass("Tool") or BB.FindBat()
        if bat and bat.Parent ~= currentChar then
            pcall(currentHumanoid.EquipTool, currentHumanoid, bat)
        end

        Z.targetPlayer  = bbNearestTarget(root)
        local targetChar = Z.targetPlayer and Z.targetPlayer.Character
        local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
        local targetHumanoid = targetChar and targetChar:FindFirstChildOfClass("Humanoid")
        if not targetRoot or not targetHumanoid or targetHumanoid.Health <= 0 then
            bbResetTarget(); return
        end

        local targetPos = targetRoot.Position
        local safeDt    = math.max(dt, 1 / 240)

        -- Estima velocidad del rival filtrando outliers
        if Z.lastTargetPos then
            local rawVelocity   = (targetPos - Z.lastTargetPos) / safeDt
            local velocityDelta = rawVelocity - Z.targetVelocity
            if velocityDelta.Magnitude > ZCFG.MAX_VELOCITY_CHANGE then
                rawVelocity = Z.targetVelocity + velocityDelta.Unit * ZCFG.MAX_VELOCITY_CHANGE
            end
            local horizontal = Vector3.new(rawVelocity.X, 0, rawVelocity.Z)
            if horizontal.Magnitude > ZCFG.MAX_HORIZONTAL_VELOCITY then
                horizontal  = horizontal.Unit * ZCFG.MAX_HORIZONTAL_VELOCITY
                rawVelocity = Vector3.new(horizontal.X, rawVelocity.Y, horizontal.Z)
            end
            bbPushHistory(Z.accelerationHistory, (rawVelocity - Z.targetVelocity) / safeDt, 4)
            bbPushHistory(Z.velocityHistory,     rawVelocity, 8)
            Z.targetVelocity = rawVelocity
            local velocityAlpha = 1 - math.exp(-safeDt * 12)
            Z.smoothedVelocity = Z.smoothedVelocity:Lerp(rawVelocity, velocityAlpha)
        end
        Z.lastTargetPos = targetPos

        -- Estado aéreo
        local airborne = targetHumanoid.FloorMaterial == Enum.Material.Air
        Z.airborneTime = airborne and (Z.airborneTime + safeDt) or 0
        if airborne and Z.airborneTime >= ZCFG.MIN_AIRBORNE_TIME then
            bbPushHistory(Z.aerialVelocityHistory, Z.targetVelocity, 6)
        elseif not airborne then
            Z.aerialVelocityHistory = {}
        end

        local predictionVelocity = Z.smoothedVelocity
        if airborne and #Z.aerialVelocityHistory > 0 then
            local aerial = bbAverageVector(Z.aerialVelocityHistory)
            predictionVelocity = Vector3.new(aerial.X, Z.targetVelocity.Y, aerial.Z) * ZCFG.AIR_CONTROL_FACTOR
        end

        -- Detecta cambios bruscos de dirección
        local quickTurn = false
        local horizontalVelocity = Vector3.new(Z.targetVelocity.X, 0, Z.targetVelocity.Z)
        if horizontalVelocity.Magnitude > 5 then
            local direction = horizontalVelocity.Unit
            if Z.previousDirection and Z.previousDirection:Dot(direction) < 0.5 then
                quickTurn = tick() - Z.lastDirectionChangeTime < ZCFG.DIRECTION_CHANGE_DETECTION_TIME
                Z.lastDirectionChangeTime = tick()
            end
            Z.previousDirection = direction
        end

        local serverDelay = Z.currentPing + ZCFG.SERVER_TICKRATE
        if quickTurn then serverDelay *= ZCFG.QUICK_DIRECTION_CHANGE_MULTIPLIER end

        local predictionTime = ZCFG.PREDICTION_TIME * 1.1
        local predicted = targetPos + predictionVelocity * (serverDelay + predictionTime)
        local acceleration = bbAverageVector(Z.accelerationHistory)
        -- Clamp noisy frame-to-frame acceleration so one spike cannot launch prediction far away.
        local accelerationMagnitude = acceleration.Magnitude
        if accelerationMagnitude > 120 then
            acceleration = acceleration.Unit * 120
        end
        predicted += acceleration * ZCFG.ACCELERATION_PREDICTION_WEIGHT * (serverDelay * serverDelay * 0.5)
        if airborne then
            local totalPredictionTime = serverDelay + predictionTime
            predicted += Vector3.new(0, -0.5 * ZCFG.GRAVITY * totalPredictionTime * totalPredictionTime, 0)
        end

        local flatPrediction = Vector3.new(predictionVelocity.X, 0, predictionVelocity.Z)
        if flatPrediction.Magnitude > 1 then
            predicted += flatPrediction.Unit * ZCFG.PREDICT_AHEAD
        end

        local toTarget = predicted - root.Position
        bbRotateRoot(root, toTarget, dt)

        if (targetPos - root.Position).Magnitude <= ZCFG.ACTIVATE_DISTANCE
        and tick() - Z.lastActivationTime >= 0.3 then
            if bat then pcall(bat.Activate, bat) end
            Z.lastActivationTime = tick()
        end

        local currentVelocity = root.AssemblyLinearVelocity
        if toTarget.Magnitude > ZCFG.MIN_FOLLOW_DISTANCE then
            local followSpeed = math.clamp(tonumber(ZCFG.FOLLOW_SPEED) or 30, 1, 80)
            local desiredVelocity = toTarget.Unit * followSpeed
            local moveAlpha = 1 - math.exp(-safeDt * 10)
            local nextVelocity = currentVelocity:Lerp(desiredVelocity, moveAlpha)
            local velocityDelta = nextVelocity - currentVelocity
            local maxDelta = 180 * safeDt
            if velocityDelta.Magnitude > maxDelta then
                nextVelocity = currentVelocity + velocityDelta.Unit * maxDelta
            end
            local flatNext = Vector3.new(nextVelocity.X, 0, nextVelocity.Z)
            local flatDesired = Vector3.new(desiredVelocity.X, 0, desiredVelocity.Z)
            if flatNext.Magnitude > 0.1 and flatDesired.Magnitude > 0.1 then
                flatNext = flatNext.Unit * flatDesired.Magnitude
                nextVelocity = Vector3.new(flatNext.X, nextVelocity.Y, flatNext.Z)
            end
            root.AssemblyLinearVelocity = nextVelocity
        else
            root.AssemblyLinearVelocity = Vector3.new(
                currentVelocity.X * 0.5,
                currentVelocity.Y,
                currentVelocity.Z * 0.5
            )
        end
    end)
end

function BB.Toggle()
    if BB.Enabled then BB.Stop() else BB.Start() end
end

-- ═══════════════════════════════════════════════════════════════
-- Compat wrappers (API externa usada por UI / config / visuales)
-- ═══════════════════════════════════════════════════════════════

local function _aceSafeSave()
    if type(saveAllSettings) == "function" then pcall(saveAllSettings) end
end

local function _aceCurrentSpeedMode()
    if laggerCarryToggled then return "Lagger Carry" end
    if laggerToggled      then return "Lagger" end
    if speedMode          then return "Carry"  end
    return "Normal"
end

_G.AceGetAntiBypassAimbotSpeed = function()
    local mode = _aceCurrentSpeedMode()
    if mode == "Lagger" or mode == "Lagger Carry" then
        return tonumber(_G.AceAntiBypassLaggerAimbotSpeed) or 40
    end
    return tonumber(_G.AceAntiBypassAimbotSpeed) or 60
end

_G.AceRefreshAimbotVisual = function()
    if _G.AceAimbotSetVisual then
        _G.AceAimbotSetVisual(_G.AceAntiBypassAimbotOn == true)
    end
end

_G.AceStartAntiBypassAimbot = function()
    if _G.AceSafeModeTryStart and not _G.AceSafeModeTryStart() then
        return false
    end
    if _G.AceStopAutoTPForAction then _G.AceStopAutoTPForAction() end
    if _G.AceStopNormalAimbot    then _G.AceStopNormalAimbot()    end

    selectedAimbotMode = "Bat Bypass"
    _G.AceAntiBypassAimbotOn = true
    SnowVS.BatBypass.ZCFG.FOLLOW_SPEED = _G.AceGetAntiBypassAimbotSpeed()
    SnowVS.BatBypass.Start()

    if _G.AceRefreshAimbotVisual then _G.AceRefreshAimbotVisual() end
    _aceSafeSave()
    return true
end

_G.AceStopAntiBypassAimbot = function(keepVisual)
    SnowVS.BatBypass.Stop()
    _G.AceAntiBypassAimbotOn = false
    if keepVisual ~= false and _G.AceRefreshAimbotVisual then
        _G.AceRefreshAimbotVisual()
    end
    _aceSafeSave()
end

_G.AceToggleSelectedAimbot = function()
    if selectedAimbotMode == "Bat Bypass" then
        if _G.AceAntiBypassAimbotOn then
            _G.AceStopAntiBypassAimbot()
        else
            _G.AceStartAntiBypassAimbot()
        end
    end
    if _G.AceRefreshAimbotVisual then _G.AceRefreshAimbotVisual() end
    _aceSafeSave()
end

_G.AceAntiBypassStart = _G.AceStartAntiBypassAimbot
_G.AceAntiBypassStop  = _G.AceStopAntiBypassAimbot

function enableBatV2()
    selectedAimbotMode = "Bat Bypass"
    local ok = _G.AceStartAntiBypassAimbot()
    if ok ~= false then
        autoBatV2Enabled = true
        if autoBatV2SetVisual then autoBatV2SetVisual(true) end
        if batV2FloatingButton then
            local btnFrame = batV2FloatingButton:FindFirstChild("Frame")
            if btnFrame then paintFloatingBtn(btnFrame, true) end
        end
    end
end

function disableBatV2()
    _G.AceStopAntiBypassAimbot()
    autoBatV2Enabled = false
    if autoBatV2SetVisual then autoBatV2SetVisual(false) end
    if batV2FloatingButton then
        local btnFrame = batV2FloatingButton:FindFirstChild("Frame")
        if btnFrame then paintFloatingBtn(btnFrame, false) end
    end
end

function toggleBatV2()
    if autoBatV2Enabled then disableBatV2() else enableBatV2() end
end

_G.AceAntiBypassSaveToConfig = function(t)
    t = t or {}
    t.selectedAimbotMode              = selectedAimbotMode
    t.ANTI_BYPASS_AIMBOT_SPEED        = _G.AceAntiBypassAimbotSpeed
    t.ANTI_BYPASS_LAGGER_AIMBOT_SPEED = _G.AceAntiBypassLaggerAimbotSpeed
    t.antiBypassAimbotEnabled         = _G.AceAntiBypassAimbotOn == true
    return t
end

_G.AceAntiBypassLoadFromConfig = function(data)
    if type(data) ~= "table" then return end
    selectedAimbotMode = data.selectedAimbotMode or selectedAimbotMode
    -- Migración de configs antiguas "Anti Bypass" → "Bat Bypass"
    if selectedAimbotMode == "Anti Bypass" then
        selectedAimbotMode = "Bat Bypass"
    end
    if selectedAimbotMode ~= "Bat Bypass" then
        selectedAimbotMode = "Normal"
    end
    _G.AceAntiBypassAimbotSpeed =
        tonumber(data.ANTI_BYPASS_AIMBOT_SPEED) or _G.AceAntiBypassAimbotSpeed or 60

    if data.ANTI_BYPASS_LAGGER_AIMBOT_SPEED == nil
       or tonumber(data.ANTI_BYPASS_LAGGER_AIMBOT_SPEED) == 58 then
        _G.AceAntiBypassLaggerAimbotSpeed = 40
    else
        _G.AceAntiBypassLaggerAimbotSpeed =
            tonumber(data.ANTI_BYPASS_LAGGER_AIMBOT_SPEED) or 40
    end

    _G.AceAntiBypassAimbotOn = data.antiBypassAimbotEnabled == true
end

-- ═══════════════════════════════════════════════════════════════
-- TP BAT — Network Owner Teleport + Anti-Die + Lagger
-- TP Bat is available from the main combat toggle, keybind, and mobile quick-access button.
-- ═══════════════════════════════════════════════════════════════
batDesyncTpEnabled = false
batDesyncTpConn    = nil
batDesyncTpSetVisual = nil
mobSetTpBat = nil
local _tpBatUnwalkForced = false
local _tpBatBodyLockSuppressed = false

-- Compat externa (UI, safe mode, teclas, carga de config, etc.)
_G.AlvaroTP = _G.AlvaroTP or {
    conn           = nil,
    on             = false,
    h              = nil,
    hrp            = nil,
    hittingCooldown= false,
    _charConn      = nil,
}

local _tpBatHitCooldown = false

-- ──────────────────────────────────────────────────────────────
-- ANTI-DIE (integrado al TP BAT); el lagger no soportado está deshabilitado.
-- ──────────────────────────────────────────────────────────────
local _tpBatAntiDieThread = nil
local _tpBatLagThread     = nil

-- TP Bat must not fake health or force local Humanoid states.
-- A client cannot provide authoritative death protection.
local function tpBatStartAntiDie()
    return
end

local function tpBatStopAntiDie()
    if _tpBatAntiDieThread then
        pcall(task.cancel, _tpBatAntiDieThread)
        _tpBatAntiDieThread = nil
    end
end

-- The former lag payload spammed SetPlayerBlockList with oversized nested
-- tables. It is disabled because it is unsupported and can destabilize servers.
local function tpBatSetKBPS(_v)
    -- NetworkClient:SetOutgoingKBPSLimit is not a supported client method.
end

local function tpBatFireLagPayload()
    -- Deliberately no-op; never send server-disruptive payloads.
end

local function tpBatStartLagger()
    -- Intentionally disabled together with the unsupported lag payload.
    return
end

local function tpBatStopLagger()
    if _tpBatLagThread then
        pcall(task.cancel, _tpBatLagThread)
        _tpBatLagThread = nil
    end
    tpBatSetKBPS(0)
end

-- ══════════════════════════════════════════════════════
-- BAT
-- ══════════════════════════════════════════════════════
local function tpBatGetBat()
    local character = LP.Character
    if not character then return nil end
    local function score(tool)
        if not tool or not tool:IsA("Tool") then return 0 end
        local name = tool.Name:lower()
        if name == "bat" then return 100 end
        if name:find("bat", 1, true) then return 90 end
        if name:find("slap", 1, true) then return 70 end
        return 0
    end
    local best, bestScore = nil, 0
    local okChar, equipped = pcall(function() return character:GetChildren() end)
    if okChar then
        for _, tool in ipairs(equipped) do
            local candidateScore = score(tool)
            if candidateScore > bestScore then best, bestScore = tool, candidateScore end
        end
    end
    if best then return best end
    local backpack = LP:FindFirstChild("Backpack")
    if not backpack then return nil end
    local okBackpack, tools = pcall(function() return backpack:GetChildren() end)
    if not okBackpack then return nil end
    for _, tool in ipairs(tools) do
        local candidateScore = score(tool)
        if candidateScore > bestScore then best, bestScore = tool, candidateScore end
    end
    if best then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then pcall(function() humanoid:EquipTool(best) end) end
    end
    return best
end

local function tpBatHit()
    if _tpBatHitCooldown then return end
    _tpBatHitCooldown = true
    pcall(function()
        local bat = tpBatGetBat()
        if not bat then return end
        bat:Activate()
    end)
    task.delay(0.14, function() _tpBatHitCooldown = false end)
end

-- ══════════════════════════════════════════════════════
-- TARGETING
-- ══════════════════════════════════════════════════════
local function tpBatPlayerHasBat(player)
    if not player or player == LP then return false end

    local function hasBat(container)
        if not container then return false end
        for _, item in ipairs(container:GetChildren()) do
            local toolName = item:IsA("Tool") and item.Name:lower() or ""
            local hasBaseballBatName = toolName == "bat"
                or toolName:find("baseball bat", 1, true) ~= nil
                or toolName:find("baseballbat", 1, true) ~= nil
                or toolName:match("%f[%a]bat%f[%A]") ~= nil
            if hasBaseballBatName then return true end
        end
        return false
    end

    local character = player.Character
    local backpack = player:FindFirstChildOfClass("Backpack")
        or player:FindFirstChild("Backpack")
    return hasBat(character) or hasBat(backpack)
end

local function tpBatClosestPlayer(root)
    local closest, distance = nil, math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player ~= LP and player.Character
        local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if targetRoot and humanoid and humanoid.Health > 0
            and tpBatPlayerHasBat(player) then
            local candidateDistance = (root.Position - targetRoot.Position).Magnitude
            if candidateDistance < distance and candidateDistance <= 80 then
                closest, distance = player, candidateDistance
            end
        end
    end
    return closest, distance
end

local function tpBatFollowTarget(root, targetRoot)
    if not root or not root.Parent or not targetRoot or not targetRoot.Parent then
        return false
    end
    local offsetCF = CFrame.new(0, 1.2, -2.5)
    root.CFrame = targetRoot.CFrame * offsetCF
    root.AssemblyLinearVelocity = targetRoot.AssemblyLinearVelocity
    return true
end

local function tpBatUpdate()
    if not batDesyncTpEnabled then return end
    if tick() < _globalMovementLock then return end
    if not canTeleportNow() then return end
    local character = LP.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then return end

    local bat = tpBatGetBat()
    if not bat then return end
    if bat.Parent ~= character then
        pcall(function() humanoid:EquipTool(bat) end)
    end

    local target = tpBatClosestPlayer(root)
    if not target then return end

    local targetCharacter = target.Character
    local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
    local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
    if not targetRoot or not targetHumanoid or targetHumanoid.Health <= 0 then return end

    -- Follow the eligible target's current position on each Heartbeat.
    -- When no eligible target exists, remain at the last position.
    if not tpBatFollowTarget(root, targetRoot) then return end
    tpBatHit()
end

function startAlvaroTP()
    if batDesyncTpConn then
        batDesyncTpConn:Disconnect()
        batDesyncTpConn = nil
    end

    batDesyncTpEnabled = true
    _G.AlvaroTP.on     = true
    _G.AlvaroTP.conn   = nil
    _tpBatHitCooldown  = false

    local char = LP.Character
    if char then
        _G.AlvaroTP.h   = char:FindFirstChildOfClass("Humanoid")
        _G.AlvaroTP.hrp = char:FindFirstChild("HumanoidRootPart")
    end

    batDesyncTpConn  = RunService.Heartbeat:Connect(tpBatUpdate)
    _G.AlvaroTP.conn = batDesyncTpConn

    -- No client-side health manipulation or unsupported lag payload is started.
    tpBatStartLagger()

    if batDesyncTpSetVisual then batDesyncTpSetVisual(true) end
    updateTpBatButtonVisual(true)
end

function stopAlvaroTP()
    batDesyncTpEnabled = false
    _G.AlvaroTP.on     = false

    if batDesyncTpConn then
        batDesyncTpConn:Disconnect()
        batDesyncTpConn = nil
    end
    _G.AlvaroTP.conn            = nil
    _G.AlvaroTP.hittingCooldown = false
    _tpBatHitCooldown           = false

    -- Clean up any legacy worker; no network ownership is changed by TP Bat.
    tpBatStopAntiDie()
    tpBatStopLagger()

    if batDesyncTpSetVisual then batDesyncTpSetVisual(false) end
    updateTpBatButtonVisual(false)
end

function toggleAlvaroTP()
    if batDesyncTpEnabled then stopAlvaroTP() else startAlvaroTP() end
end

UIS.InputBegan:Connect(function(inp, gp)
    if gp then return end
    if _G.AlvaroTP.on then
        if inp.KeyCode == Enum.KeyCode.LeftShift or inp.KeyCode == Enum.KeyCode.RightShift then
            pcall(function()
                UIS.MouseBehavior = Enum.MouseBehavior.Default
            end)
        end
    end
end)

-- Reenganche al respawn (guarda referencias de HRP/Humanoid)
if _G.AlvaroTP._charConn then
    pcall(function() _G.AlvaroTP._charConn:Disconnect() end)
    _G.AlvaroTP._charConn = nil
end
local function tpBatSetupChar(char)
    task.wait(0.15)
    _G.AlvaroTP.h   = char and char:FindFirstChildOfClass("Humanoid") or nil
    _G.AlvaroTP.hrp = char and char:FindFirstChild("HumanoidRootPart") or nil
    if batDesyncTpEnabled and not batDesyncTpConn then
        startAlvaroTP()
    end
end
_G.AlvaroTP._charConn = LP.CharacterAdded:Connect(function(char)
    pcall(function() tpBatSetupChar(char) end)
end)
if LP.Character then
    task.spawn(function() pcall(function() tpBatSetupChar(LP.Character) end) end)
end

function startBatDesyncTp()
    if not _G.AmbitiousSafeModeTryStart() then return end
    if bodyLockEnabled and not _tpBatBodyLockSuppressed then
        _suppressBodyLock()
        _tpBatBodyLockSuppressed = true
    end
    if not unwalkEnabled then
        startUnwalk()
        unwalkEnabled = true
        _tpBatUnwalkForced = true
        if setUnwalkVisual then setUnwalkVisual(true) end
    end
    startAlvaroTP()
end

function stopBatDesyncTp()
    stopAlvaroTP()
    if _tpBatUnwalkForced then
        stopUnwalk()
        unwalkEnabled = false
        _tpBatUnwalkForced = false
        if setUnwalkVisual then setUnwalkVisual(false) end
    end
    if _tpBatBodyLockSuppressed then
        _tpBatBodyLockSuppressed = false
        _unsuppressBodyLock(true)
    end
end

function toggleBatDesyncTp()
    if batDesyncTpEnabled then
        stopBatDesyncTp()
    else
        disableAllAimbots()
        if autoLeftEnabled then
            autoLeftEnabled = false; stopAutoLeft()
            if autoLeftSetVisual then autoLeftSetVisual(false) end
            if mobSetAutoLeft then mobSetAutoLeft(false) end
        end
        if autoRightEnabled then
            autoRightEnabled = false; stopAutoRight()
            if autoRightSetVisual then autoRightSetVisual(false) end
            if mobSetAutoRight then mobSetAutoRight(false) end
        end
        startBatDesyncTp()
    end
    saveAllSettings()
end

function setTPBatVersion(_) end

function updateTpBatButtonVisual(state)
    if batDesyncTpSetVisual then batDesyncTpSetVisual(state) end
    if mobSetTpBat then mobSetTpBat(state) end
end

_G.AlvaroTPBat = {
    toggle    = toggleAlvaroTP,
    start     = startAlvaroTP,
    stop      = stopAlvaroTP,
    getStatus = function() return _G.AlvaroTP.on end,
}

-- ────────────────────────────────────────────────────────────────

function findBat()
    local char = LP.Character
    if not char then return nil end
    for _, name in ipairs(BAT_COUNTER_SLAP_LIST) do
        local t = char:FindFirstChild(name)
        if t and t:IsA("Tool") then return t end
    end
    local bp = LP:FindFirstChildOfClass("Backpack")
    if bp then
        for _, name in ipairs(BAT_COUNTER_SLAP_LIST) do
            local t = bp:FindFirstChild(name)
            if t and t:IsA("Tool") then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then pcall(function() hum:EquipTool(t) end) end
                return t
            end
        end
    end
    for _, ch in ipairs(char:GetChildren()) do
        if ch:IsA("Tool") and (ch.Name:lower():find("bat") or ch.Name:lower():find("slap")) then
            return ch
        end
    end
    return nil
end

function isBatTool(tool)
    if not tool then return false end
    for _, name in ipairs(BAT_COUNTER_SLAP_LIST) do
        if tool.Name == name then return true end
    end
    return tool.Name:lower():find("bat") or tool.Name:lower():find("slap")
end

function findBatForCounter()
    local char = LP.Character
    if not char then return nil end
    local backpack = LP:FindFirstChildOfClass("Backpack")
    for _, name in ipairs(BAT_COUNTER_SLAP_LIST) do
        local tool = char:FindFirstChild(name) or (backpack and backpack:FindFirstChild(name))
        if tool then return tool end
    end
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") and (child.Name:lower():find("bat") or child.Name:lower():find("slap")) then
            return child
        end
    end
    if backpack then
        for _, child in ipairs(backpack:GetChildren()) do
            if child:IsA("Tool") and (child.Name:lower():find("bat") or child.Name:lower():find("slap")) then
                return child
            end
        end
    end
    return nil
end

function swingBatForCounter(bat, character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if bat.Parent ~= character and humanoid then
        pcall(function() humanoid:EquipTool(bat) end)
        task.wait(0.05)
    end
    local remote = bat:FindFirstChildOfClass("RemoteEvent") or bat:FindFirstChildOfClass("RemoteFunction")
    if remote and remote:IsA("RemoteEvent") then
        pcall(function() remote:FireServer() end)
        task.wait(0.1)
        pcall(function() remote:FireServer() end)
    else
        pcall(function() bat:Activate() end)
        task.wait(0.1)
        pcall(function() bat:Activate() end)
    end
end

batCounterDebounce = false

function stopBatCounter()
    if Conns.batCounter then
        Conns.batCounter:Disconnect()
        Conns.batCounter = nil
    end
    batCounterDebounce = false
end

function startBatCounter()
    if Conns.batCounter then return end
    Conns.batCounter = RunService.Heartbeat:Connect(function()
        if not batCounterEnabled then
            stopBatCounter()
            return
        end
        if batCounterDebounce then return end
        local character = LP.Character
        if not character then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        local state = humanoid:GetState()
        if state == Enum.HumanoidStateType.Physics or state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown then
            batCounterDebounce = true
            _suppressBodyLock()
            task.spawn(function()
                local ok, err = xpcall(function()
                    task.wait(0.15)
                    if not batCounterEnabled or LP.Character ~= character or not character.Parent then return end
                    local currentHumanoid = character:FindFirstChildOfClass("Humanoid")
                    if not currentHumanoid then return end
                    local currentState = currentHumanoid:GetState()
                    local stillRagdolled = currentState == Enum.HumanoidStateType.Physics
                        or currentState == Enum.HumanoidStateType.Ragdoll
                        or currentState == Enum.HumanoidStateType.FallingDown
                    if stillRagdolled then
                        local bat = findBatForCounter()
                        if bat then swingBatForCounter(bat, character) end
                        task.wait(0.3)
                    end
                end, function(e) return tostring(e) end)
                batCounterDebounce = false
                pcall(_unsuppressBodyLock, true)
                if not ok then warn("[ShoxHub] Bat Counter recovered: " .. tostring(err)) end
            end)
        end
    end)
end

function findMedusa()
    local c = LP.Character
    if not c then return nil end

    -- Match Medusa as a standalone word only. Generic "head"/"stone"
    -- substrings incorrectly selected unrelated tools such as Headless Knight
    -- and Whetstone.
    local function isMedusaTool(tool)
        if not tool or not tool:IsA("Tool") then return false end
        local name = tool.Name:lower()
        return name:match("%f[%a]medusa%f[%A]") ~= nil
    end

    for _, tool in ipairs(c:GetChildren()) do
        if isMedusaTool(tool) then return tool end
    end

    local backpack = LP:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if isMedusaTool(tool) then return tool end
        end
    end
    return nil
end

function useMedusaCounter()
    if medusaDebounce then return end
    if _tick() - medusaLastUsed < MEDUSA_COOLDOWN then return end
    local c = LP.Character
    if not c then return end
    medusaDebounce = true
    local med = findMedusa()
    if not med then medusaDebounce = false; return end
    if med.Parent ~= c then
        local hum2 = c:FindFirstChildOfClass("Humanoid")
        if hum2 then hum2:EquipTool(med) end
    end
    pcall(function() med:Activate() end)
    medusaLastUsed = _tick()
    medusaDebounce = false
end

function onAnchorChanged(part)
    return part:GetPropertyChangedSignal("Anchored"):Connect(function()
        if medusaCounterEnabled and part.Anchored and part.Transparency == 1 then useMedusaCounter() end
    end)
end

function setupMedusaCounter(char)
    for _, c in pairs(Conns.anchor) do pcall(function() c:Disconnect() end) end
    Conns.anchor = {}
    if not char or not medusaCounterEnabled then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            table.insert(Conns.anchor, onAnchorChanged(part))
        end
    end
    table.insert(Conns.anchor, char.DescendantAdded:Connect(function(part)
        if part:IsA("BasePart") then
            table.insert(Conns.anchor, onAnchorChanged(part))
        end
    end))
end

function stopMedusaCounter()
    for _, c in pairs(Conns.anchor) do pcall(function() c:Disconnect() end) end
    Conns.anchor = {}
end

local DROP_ASCEND_DURATION = 0.22
local DROP_ASCEND_SPEED = 60
local _dropConn = nil

function stopDropBrainrot()
    dropActive = false
    if _dropConn then
        _dropConn:Disconnect()
        _dropConn = nil
    end
    for _, t in ipairs(dropConnections) do
        if type(t) == "thread" then pcall(task.cancel, t)
        elseif type(t) == "RBXScriptConnection" then pcall(t.Disconnect, t) end
    end
    dropConnections = {}
    local c = LP.Character
    if c then
        local root = c:FindFirstChild("HumanoidRootPart")
        if root then root.AssemblyLinearVelocity = _V3zero end
    end
    if dropBrainrotSetVisual then dropBrainrotSetVisual(false) end
    if mobSetDropBR then mobSetDropBR(false) end
end

function runDropBrainrot()
    if dropActive then return end
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end
    if dropMode == 1 then
        local speedH = 0
        if root then
            local vel = root.AssemblyLinearVelocity
            speedH = _V3new(vel.X, 0, vel.Z).Magnitude
        end
        local cooldown = (speedH > 5) and 0.6 or 0.25
        if _tick() - lastDropTime < cooldown then return end
        lastDropTime = _tick()
        dropActive = true
        if dropBrainrotSetVisual then dropBrainrotSetVisual(true) end
        if mobSetDropBR then mobSetDropBR(true) end
        local wasAutoBat = autoBatEnabled
        if autoBatEnabled then
            disableAutoBat()
            if autoBatSetVisual then autoBatSetVisual(false) end
            if mobSetAutoBat then mobSetAutoBat(false) end
        end
        local function finishDrop(threadRef)
            if threadRef and dropConnections then
                for i = #dropConnections, 1, -1 do
                    if dropConnections[i] == threadRef then
                        table.remove(dropConnections, i)
                        break
                    end
                end
            end
            dropActive = false
            local c = LP.Character
            if c then
                local r = c:FindFirstChild("HumanoidRootPart")
                local h = c:FindFirstChildOfClass("Humanoid")
                if r then
                    r.AssemblyLinearVelocity = _V3zero
                    r.AssemblyAngularVelocity = _V3zero
                    if r.Position.Y < -100 then
                        r.CFrame = _CFnew(r.Position.X, 5, r.Position.Z)
                    end
                    local rr = ShoxGetGroundHit(c, r)
                    if rr then
                        local off = ShoxGetStandOffset(h, r)
                        r.CFrame = _CFnew(r.Position.X, rr.Position.Y + off, r.Position.Z)
                    end
                    if h and h.Health > 0 then h:ChangeState(Enum.HumanoidStateType.Running) end
                end
            end
            if wasAutoBat then
                enableAutoBat()
                if autoBatSetVisual then autoBatSetVisual(true) end
                if mobSetAutoBat then mobSetAutoBat(true) end
            end
            if dropBrainrotSetVisual then dropBrainrotSetVisual(false) end
            if mobSetDropBR then mobSetDropBR(false) end
        end
        local flingThread = nil
        flingThread = task.spawn(function()
            local startTime = _tick()
            while dropActive and (_tick() - startTime) < 0.25 do
                RunService.Heartbeat:Wait()
                local c = LP.Character
                local r = c and c:FindFirstChild("HumanoidRootPart")
                if not r then break end
                local vel = r.AssemblyLinearVelocity
                vel = _V3new(0, vel.Y, 0)
                -- The former 10,000-stud/s impulse caused severe server correction/lagback.
                r.AssemblyLinearVelocity = _V3new(
                    vel.X,
                    math.clamp(vel.Y + 60, -60, 60),
                    vel.Z
                )
                RunService.RenderStepped:Wait()
                if r and r.Parent then r.AssemblyLinearVelocity = vel end
                RunService.Stepped:Wait()
                if r and r.Parent then r.AssemblyLinearVelocity = vel + _V3new(0, 0.1, 0) end
            end
            finishDrop(flingThread)
        end)
        table.insert(dropConnections, flingThread)
        task.delay(0.35, function()
            if dropActive then finishDrop(flingThread) end
        end)
        return
    end
    dropActive = true
    if dropBrainrotSetVisual then dropBrainrotSetVisual(true) end
    if mobSetDropBR then mobSetDropBR(true) end
    local t0 = _tick()
    if _dropConn then _dropConn:Disconnect() end
    _dropConn = RunService.Heartbeat:Connect(function()
        local c = LP.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if not r then
            if _dropConn then _dropConn:Disconnect(); _dropConn = nil end
            dropActive = false
            if dropBrainrotSetVisual then dropBrainrotSetVisual(false) end
            if mobSetDropBR then mobSetDropBR(false) end
            return
        end
        if not dropActive then
            if _dropConn then _dropConn:Disconnect(); _dropConn = nil end
            if dropBrainrotSetVisual then dropBrainrotSetVisual(false) end
            if mobSetDropBR then mobSetDropBR(false) end
            return
        end
        if _tick() - t0 >= DROP_ASCEND_DURATION then
            if _dropConn then _dropConn:Disconnect(); _dropConn = nil end
            pcall(function()
                local rp = RaycastParams.new()
                rp.FilterDescendantsInstances = {c}
                rp.FilterType = Enum.RaycastFilterType.Exclude
                local rr = workspace:Raycast(r.Position, _V3new(0, -3000, 0), rp)
                -- Keep the Humanoid reference in the enclosing pcall scope;
                -- declaring it inside `if rr` made the state reset unreachable.
                local hum2 = c:FindFirstChildOfClass("Humanoid")
                if rr then
                    local off = ((hum2 and hum2.HipHeight) or 2) + (r.Size.Y / 2)
                    r.CFrame = _CFnew(r.Position.X, rr.Position.Y + off, r.Position.Z)
                    r.AssemblyLinearVelocity = _V3zero
                    r.AssemblyAngularVelocity = _V3zero
                end
                if hum2 and hum2.Health > 0 then hum2:ChangeState(Enum.HumanoidStateType.Running) end
            end)
            dropActive = false
            if dropBrainrotSetVisual then dropBrainrotSetVisual(false) end
            if mobSetDropBR then mobSetDropBR(false) end
            return
        end
        local lv = r.AssemblyLinearVelocity
        r.AssemblyLinearVelocity = _V3new(lv.X, DROP_ASCEND_SPEED, lv.Z)
    end)
end

function executeDropWithToggle(setVisual)
    if dropActive then
        -- A caller may already have switched the UI on before discovering
        -- that a drop is in progress. Keep the visual state in sync.
        if setVisual then pcall(setVisual, false) end
        return
    end
    task.spawn(function()
        if setVisual then setVisual(true) end
        runDropBrainrot()
        while dropActive do task.wait() end
        task.wait(0.1)
        if setVisual then setVisual(false) end
    end)
end

-- Anti-Lag: nur visuelle Effekte deaktivieren, niemals Spielobjekte verändern/löschen.
local antiLagOriginalProperties = setmetatable({}, {__mode = "k"})
local antiLagLightingConn = nil
local antiLagScanGeneration = 0

local function applyAntiLagDerender(obj)
    pcall(function()
        if not obj or obj:GetAttribute("_AmbitiousHubSky") ~= nil then return end

        local isPart = obj:IsA("BasePart")
        local isSurfaceImage = obj:IsA("Decal") or obj:IsA("Texture")
        local isEffect =
            obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam")
            or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles")
            or obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight")
            or obj:IsA("BlurEffect") or obj:IsA("SunRaysEffect")
            or obj:IsA("ColorCorrectionEffect") or obj:IsA("BloomEffect")
            or obj:IsA("DepthOfFieldEffect") or obj:IsA("BrightnessEffect")
            or obj:IsA("DitheringEffect")

        if not isPart and not isSurfaceImage and not isEffect then return end
        if isEffect and obj:IsA("PostEffect") and obj.Parent == Lighting and skyTheme ~= "Off" then
            return
        end

        -- Save each eligible object's original look once so Anti-Lag can be toggled off.
        local props = antiLagOriginalProperties[obj]
        if props == nil then
            props = {}
            antiLagOriginalProperties[obj] = props
        end

        -- Reduce map surface detail locally without deleting or moving instances.
        if isPart then
            if props.Material == nil then props.Material = obj.Material end
            if props.Reflectance == nil then props.Reflectance = obj.Reflectance end
            obj.Material = Enum.Material.SmoothPlastic
            obj.Reflectance = 0
        elseif isSurfaceImage then
            if props.Transparency == nil then props.Transparency = obj.Transparency end
            obj.Transparency = 1
        else
            if props.Enabled == nil then props.Enabled = obj.Enabled end
            obj.Enabled = false
        end
    end)
end

function enableAntiLag()
    antiLagEnabled = true
    removeAccessoriesEnabled = true -- Kompatibilität mit vorhandenen Toggle-/UI-Stellen; löscht nichts.

    pcall(function()
        settings().Rendering.QualityLevel = 1
        settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Disabled
    end)

    -- Subscribe first so new effects are covered while the initial scan yields.
    if antiLagDescConn then antiLagDescConn:Disconnect() end
    antiLagDescConn = workspace.DescendantAdded:Connect(function(obj)
        if antiLagEnabled then applyAntiLagDerender(obj) end
    end)

    if antiLagLightingConn then antiLagLightingConn:Disconnect() end
    antiLagLightingConn = Lighting.DescendantAdded:Connect(function(obj)
        if antiLagEnabled then applyAntiLagDerender(obj) end
    end)

    -- A full GetDescendants pass can hitch badly on large maps. Spread work
    -- over frames and invalidate an unfinished scan if Anti-Lag is switched off.
    antiLagScanGeneration = antiLagScanGeneration + 1
    local scanGeneration = antiLagScanGeneration
    task.spawn(function()
        local roots = {workspace, Lighting}
        for _, root in ipairs(roots) do
            if not antiLagEnabled or scanGeneration ~= antiLagScanGeneration then return end
            -- Walk incrementally instead of allocating one huge GetDescendants array.
            local pending = root:GetChildren()
            local cursor = 1
            while cursor <= #pending do
                if not antiLagEnabled or scanGeneration ~= antiLagScanGeneration then return end
                local obj = pending[cursor]
                cursor = cursor + 1
                applyAntiLagDerender(obj)
                local children = obj:GetChildren()
                for _, child in ipairs(children) do
                    pending[#pending + 1] = child
                end
                if cursor % 180 == 0 then task.wait() end
            end
        end
    end)
end

function disableAntiLag()
    antiLagEnabled = false
    antiLagScanGeneration = antiLagScanGeneration + 1
    removeAccessoriesEnabled = false

    if antiLagDescConn then
        antiLagDescConn:Disconnect()
        antiLagDescConn = nil
    end
    if antiLagLightingConn then
        antiLagLightingConn:Disconnect()
        antiLagLightingConn = nil
    end

    -- Restore original visual properties for effects, map parts and textures.
    for obj, props in pairs(antiLagOriginalProperties) do
        if obj and obj.Parent then
            pcall(function()
                if props.Enabled ~= nil then obj.Enabled = props.Enabled end
                if props.Material ~= nil then obj.Material = props.Material end
                if props.Reflectance ~= nil then obj.Reflectance = props.Reflectance end
                if props.Transparency ~= nil then obj.Transparency = props.Transparency end
            end)
        end
        antiLagOriginalProperties[obj] = nil
    end
end

CUSTOM_FOV_BIND = "FictionHubCustomFOV"

function enableCustomFov()
    local cam = workspace.CurrentCamera
    if cam and origFOV == nil then
        origFOV = cam.FieldOfView
        pcall(function() origFOVMode = cam.FieldOfViewMode end)
    end
    fovEnabled = true
    if cam then
        pcall(function() cam.FieldOfViewMode = Enum.FieldOfViewMode.Diagonal end)
        pcall(function() cam.FieldOfView = fovValue end)
    end
    if customFovConn then customFovConn:Disconnect(); customFovConn = nil end
    if _customFovBound then return end
    local prio = 200
    pcall(function() prio = Enum.RenderPriority.Camera.Value + 10 end)
    local ok = pcall(function()
        RunService:BindToRenderStep(CUSTOM_FOV_BIND, prio, function()
            if not fovEnabled then return end
            local c = workspace.CurrentCamera
            if c and c.FieldOfView ~= fovValue then
                c.FieldOfView = fovValue
            end
        end)
    end)
    if ok then
        _customFovBound = true
    else
        customFovConn = RunService.RenderStepped:Connect(function()
            if not fovEnabled then
                if customFovConn then customFovConn:Disconnect(); customFovConn = nil end
                return
            end
            local c = workspace.CurrentCamera
            if c then c.FieldOfView = fovValue end
        end)
    end
end

function disableCustomFov()
    fovEnabled = false
    if _customFovBound then
        pcall(function() RunService:UnbindFromRenderStep(CUSTOM_FOV_BIND) end)
        _customFovBound = false
    end
    if customFovConn then customFovConn:Disconnect(); customFovConn = nil end
    local cam = workspace.CurrentCamera
    if cam then
        if origFOVMode ~= nil then
            pcall(function() cam.FieldOfViewMode = origFOVMode end)
        end
        pcall(function() cam.FieldOfView = origFOV or 70 end)
    end
end

function applyStretchFOV(val)
    local cam = workspace.CurrentCamera
    if cam then pcall(function() cam.FieldOfView = val end) end
end

function enableStretch()
    if stretchConn then return end
    stretchEnabled = true
    local cam = workspace.CurrentCamera
    if not cam then return end
    origFOV = cam.FieldOfView or 70
    applyStretchFOV(stretchFOV)
    stretchConn = RunService.RenderStepped:Connect(function()
        if not stretchEnabled then
            stretchConn:Disconnect()
            stretchConn = nil
            return
        end
        local c = workspace.CurrentCamera
        if c then c.CFrame = c.CFrame * _CFnew(0,0,0,1,0,0,0,0.7,0,0,0,1) end
    end)
    if stretchFovConn then stretchFovConn:Disconnect() end
    stretchFovConn = RunService.RenderStepped:Connect(function()
        if stretchEnabled then applyStretchFOV(stretchFOV)
        else stretchFovConn:Disconnect(); stretchFovConn = nil end
    end)
end

function disableStretch()
    stretchEnabled = false
    if stretchConn then stretchConn:Disconnect(); stretchConn = nil end
    if stretchFovConn then stretchFovConn:Disconnect(); stretchFovConn = nil end
    local cam = workspace.CurrentCamera
    if cam then pcall(function() cam.FieldOfView = origFOV or 70 end) end
end

local function saveLightingState()
    if _originalLighting then return end
    _originalLighting = {
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        GlobalShadows = Lighting.GlobalShadows,
        FogEnd = Lighting.FogEnd,
        FogStart = Lighting.FogStart,
        FogColor = Lighting.FogColor,
        Ambient = Lighting.Ambient,
        ColorCorrection = nil,
        Bloom = nil,
    }
    for _, e in ipairs(Lighting:GetChildren()) do
        if e:IsA("ColorCorrectionEffect") then
            _originalLighting.ColorCorrection = {
                Enabled = e.Enabled,
                Brightness = e.Brightness,
                Contrast = e.Contrast,
                Saturation = e.Saturation,
                TintColor = e.TintColor,
            }
        elseif e:IsA("BloomEffect") then
            _originalLighting.Bloom = {
                Enabled = e.Enabled,
                Intensity = e.Intensity,
                Size = e.Size,
                Threshold = e.Threshold,
            }
        end
    end
end

local function restoreLightingState()
    if not _originalLighting then return end
    local old = _originalLighting
    Lighting.Brightness = old.Brightness
    Lighting.ClockTime = old.ClockTime
    Lighting.OutdoorAmbient = old.OutdoorAmbient
    Lighting.GlobalShadows = old.GlobalShadows
    Lighting.FogEnd = old.FogEnd
    Lighting.FogStart = old.FogStart
    Lighting.FogColor = old.FogColor
    Lighting.Ambient = old.Ambient
    if old.ColorCorrection then
        local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
        if cc then
            cc.Enabled = old.ColorCorrection.Enabled
            cc.Brightness = old.ColorCorrection.Brightness
            cc.Contrast = old.ColorCorrection.Contrast
            cc.Saturation = old.ColorCorrection.Saturation
            cc.TintColor = old.ColorCorrection.TintColor
        end
    elseif _neonCreatedColorCorrection and _neonCreatedColorCorrection.Parent then
        _neonCreatedColorCorrection:Destroy()
    end
    if old.Bloom then
        local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
        if bloom then
            bloom.Enabled = old.Bloom.Enabled
            bloom.Intensity = old.Bloom.Intensity
            bloom.Size = old.Bloom.Size
            bloom.Threshold = old.Bloom.Threshold
        end
    elseif _neonCreatedBloom and _neonCreatedBloom.Parent then
        _neonCreatedBloom:Destroy()
    end
    _neonCreatedColorCorrection = nil
    _neonCreatedBloom = nil
    _originalLighting = nil
end

SKY_PRESETS_LIST = {"Off","Night","Aurora","Sunset","Galaxy","Cyber","Sakura","Pink Night","Blood Moon","Emerald Dawn","Volcanic","Arctic","Midnight Ocean","Vaporwave","Toxic","Solar Eclipse","Hellscape","Heaven","Storm","Sunrise","Deep Space","Lavender Dream","Inferno","Mint Sky"}

SKY_PRESETS = {
    ["Off"]={kind="off"},
    ["Night"]={clock=22,brightness=2,ambient={110,100,130},outAmb={120,110,140},sky={stars=4000,moon=18,sun=0,moonTex=true},atm={dens=0.45,color={120,60,180},decay={60,20,100},glare=0.5,haze=1.2}},
    ["Aurora"]={clock=14,brightness=3,ambient={150,120,150},outAmb={160,130,150},atm={dens=0.55,color={255,80,200},decay={255,20,150},glare=2.5,haze=3},clouds={cover=0.7,dens=0.7,color={255,240,250}}},
    ["Sunset"]={clock=17.2,brightness=2.5,ambient={170,120,100},outAmb={180,130,110},sky={stars=0,sun=25,moon=0},atm={dens=0.5,color={255,130,60},decay={255,80,30},glare=2,haze=2.5},clouds={cover=0.55,dens=0.55,color={255,200,140}}},
    ["Galaxy"]={clock=0,brightness=1.5,ambient={70,60,100},outAmb={80,70,110},sky={stars=10000,moon=30,sun=0},atm={dens=0.15,color={40,20,80},decay={20,10,50},glare=0.3,haze=0.5}},
    ["Cyber"]={clock=21,brightness=2.2,ambient={90,130,170},outAmb={100,140,180},sky={stars=2000,moon=12},atm={dens=0.4,color={0,200,255},decay={150,0,255},glare=2,haze=2},clouds={cover=0.4,dens=0.6,color={100,200,255}}},
    ["Sakura"]={clock=11,brightness=3.5,ambient={170,150,160},outAmb={180,160,170},sky={sun=8},atm={dens=0.3,color={255,200,220},decay={255,170,200},glare=1,haze=1.5},clouds={cover=0.6,dens=0.4,color={255,250,252}}},
    ["Pink Night"]={clock=23,brightness=2.2,ambient={120,60,110},outAmb={140,70,120},sky={stars=5000,moon=22,sun=0,moonTex=true},atm={dens=0.5,color={255,80,180},decay={140,30,100},glare=0.7,haze=1.4},clouds={cover=0.3,dens=0.5,color={180,90,150}}},
    ["Blood Moon"]={clock=22.5,brightness=1.8,ambient={130,70,70},outAmb={150,80,80},sky={stars=1500,moon=28,sun=0,moonTex=true},atm={dens=0.45,color={220,80,80},decay={120,40,40},glare=1.0,haze=1.5},clouds={cover=0.45,dens=0.55,color={120,60,60}}},
    ["Emerald Dawn"]={clock=6.5,brightness=2.8,ambient={130,170,140},outAmb={140,180,150},sky={sun=18,moon=0,stars=0},atm={dens=0.4,color={80,200,140},decay={40,150,90},glare=1.8,haze=2.2},clouds={cover=0.5,dens=0.5,color={200,255,220}}},
    ["Volcanic"]={clock=19,brightness=2.2,ambient={180,110,80},outAmb={200,120,90},sky={stars=200,sun=12,moon=0},atm={dens=0.55,color={255,110,60},decay={180,70,40},glare=2.0,haze=2.2},clouds={cover=0.65,dens=0.7,color={120,70,50}}},
    ["Arctic"]={clock=9,brightness=3.2,ambient={200,220,235},outAmb={210,230,245},sky={sun=10,stars=0,moon=0},atm={dens=0.3,color={180,220,255},decay={140,200,240},glare=1.5,haze=1.8},clouds={cover=0.7,dens=0.6,color={250,253,255}}},
    ["Midnight Ocean"]={clock=1.5,brightness=1.7,ambient={60,90,130},outAmb={70,100,140},sky={stars=6000,moon=24,sun=0,moonTex=true},atm={dens=0.5,color={20,60,140},decay={10,30,90},glare=0.6,haze=1.5}},
    ["Vaporwave"]={clock=19.5,brightness=2.4,ambient={180,120,200},outAmb={190,130,210},sky={stars=1000,moon=14},atm={dens=0.45,color={255,100,220},decay={120,60,255},glare=2.2,haze=2.4},clouds={cover=0.55,dens=0.55,color={200,150,255}}},
    ["Toxic"]={clock=13,brightness=2.5,ambient={140,180,80},outAmb={150,190,90},atm={dens=0.45,color={100,220,40},decay={60,150,20},glare=1.5,haze=1.8},clouds={cover=0.55,dens=0.55,color={180,255,120}}},
    ["Solar Eclipse"]={clock=12,brightness=1.2,ambient={70,60,80},outAmb={80,70,90},sky={stars=3500,sun=22,moon=0},atm={dens=0.4,color={255,180,90},decay={50,40,60},glare=2.0,haze=1.5}},
    ["Hellscape"]={clock=18,brightness=2.2,ambient={200,100,80},outAmb={220,110,90},sky={stars=100,sun=30,moon=0},atm={dens=0.6,color={255,90,60},decay={140,50,40},glare=2.2,haze=2.4},clouds={cover=0.8,dens=0.8,color={90,50,40}}},
    ["Heaven"]={clock=12,brightness=4,ambient={240,235,210},outAmb={250,245,220},sky={sun=16,moon=0,stars=0},atm={dens=0.25,color={255,250,220},decay={255,240,200},glare=3,haze=1.5},clouds={cover=0.85,dens=0.5,color={255,255,255}}},
    ["Storm"]={clock=15,brightness=1.6,ambient={105,105,125},outAmb={115,115,135},sky={stars=0,sun=6,moon=0},atm={dens=0.55,color={90,100,130},decay={55,65,90},glare=0.5,haze=2.2},clouds={cover=0.85,dens=0.75,color={70,75,90}}},
    ["Sunrise"]={clock=6.2,brightness=2.8,ambient={220,180,130},outAmb={230,190,140},sky={sun=22,stars=0,moon=0},atm={dens=0.45,color={255,180,100},decay={255,140,80},glare=2.4,haze=2.2},clouds={cover=0.4,dens=0.4,color={255,220,180}}},
    ["Deep Space"]={clock=0,brightness=1,ambient={30,25,50},outAmb={40,35,60},sky={stars=15000,moon=0,sun=0},atm={dens=0.08,color={15,5,40},decay={5,0,20},glare=0.2,haze=0.3}},
    ["Lavender Dream"]={clock=18.5,brightness=2.6,ambient={180,160,220},outAmb={190,170,230},sky={stars=800,moon=16,sun=0},atm={dens=0.4,color={200,160,255},decay={160,120,220},glare=1.4,haze=1.8},clouds={cover=0.55,dens=0.5,color={220,200,255}}},
    ["Inferno"]={clock=17.5,brightness=2.4,ambient={220,140,90},outAmb={235,150,100},sky={sun=26,moon=0,stars=0},atm={dens=0.5,color={255,130,70},decay={200,80,40},glare=2.2,haze=2.2},clouds={cover=0.6,dens=0.6,color={200,110,80}}},
    ["Mint Sky"]={clock=10,brightness=3.2,ambient={180,230,210},outAmb={190,240,220},sky={sun=10},atm={dens=0.32,color={150,255,210},decay={100,220,180},glare=1.6,haze=1.6},clouds={cover=0.55,dens=0.45,color={240,255,250}}},
}

local function _vC3(t) return Color3.fromRGB(t[1], t[2], t[3]) end

local _shoxOriginalLighting = nil
local function _shoxCaptureLighting()
    if _shoxOriginalLighting then return end
    local ok, snapshot = pcall(function()
        return {
            ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness,
            OutdoorAmbient = Lighting.OutdoorAmbient, Ambient = Lighting.Ambient,
            FogStart = Lighting.FogStart, FogEnd = Lighting.FogEnd, FogColor = Lighting.FogColor,
            ColorShift_Top = Lighting.ColorShift_Top, ColorShift_Bottom = Lighting.ColorShift_Bottom,
            GlobalShadows = Lighting.GlobalShadows,
        }
    end)
    if ok then _shoxOriginalLighting = snapshot end
end

local function _shoxRestoreLighting()
    if not _shoxOriginalLighting then return end
    for property, value in pairs(_shoxOriginalLighting) do
        pcall(function() Lighting[property] = value end)
    end
end

function _v4mpClearSky()
    for _, child in ipairs(Lighting:GetChildren()) do
        if child:GetAttribute("_AdaptDuelsSky") then
            pcall(function() child:Destroy() end)
        end
    end
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        for _, child in ipairs(terrain:GetChildren()) do
            if child:GetAttribute("_AdaptDuelsSky") then
                pcall(function() child:Destroy() end)
            end
        end
    end
end

function applyCustomSky(mode)
    -- The Neon Weather and custom-sky systems use different snapshots.
    -- Restore Neon first, then capture the true baseline for the sky preset.
    if neonWeatherEnabled then
        pcall(function() toggleNeonWeather(false) end)
        neonWeatherEnabled = false
        _shoxOriginalLighting = nil
    end
    _shoxCaptureLighting()
    _v4mpClearSky()
    local preset = SKY_PRESETS[mode]
    if not preset or preset.kind == "off" then
        _shoxRestoreLighting()
        _shoxOriginalLighting = nil
        skyTheme = "Off"
        return
    end
    Lighting.FogStart = 0
    Lighting.FogEnd = 100000
    Lighting.FogColor = Color3.fromRGB(200,200,200)
    Lighting.ColorShift_Top = Color3.fromRGB(0,0,0)
    Lighting.ColorShift_Bottom = Color3.fromRGB(0,0,0)
    Lighting.GlobalShadows = true
    Lighting.ClockTime = preset.clock or 14
    Lighting.Brightness = preset.brightness or 2
    if preset.outAmb then Lighting.OutdoorAmbient = _vC3(preset.outAmb) end
    if preset.ambient then Lighting.Ambient = _vC3(preset.ambient) end
    if preset.sky then
        local skyInst = Instance.new("Sky")
        skyInst:SetAttribute("_AdaptDuelsSky", true)
        if preset.sky.stars then skyInst.StarCount = preset.sky.stars end
        if preset.sky.moon then skyInst.MoonAngularSize = preset.sky.moon end
        if preset.sky.sun then skyInst.SunAngularSize = preset.sky.sun end
        if preset.sky.moonTex then skyInst.MoonTextureId = "rbxasset://sky/moon.jpg" end
        skyInst.Parent = Lighting
    end
    if preset.atm then
        local atm = Instance.new("Atmosphere")
        atm:SetAttribute("_AdaptDuelsSky", true)
        atm.Density = preset.atm.dens or 0.3
        atm.Color = _vC3(preset.atm.color)
        atm.Decay = _vC3(preset.atm.decay)
        atm.Glare = preset.atm.glare or 1
        atm.Haze = preset.atm.haze or 1
        atm.Parent = Lighting
    end
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if preset.clouds and terrain then
        local clouds = Instance.new("Clouds")
        clouds:SetAttribute("_AdaptDuelsSky", true)
        clouds.Cover = preset.clouds.cover or 0.5
        clouds.Density = preset.clouds.dens or 0.5
        clouds.Color = _vC3(preset.clouds.color)
        clouds.Parent = terrain
    end
    skyTheme = mode
end

local function applyNeonWeather()
    if not neonWeatherEnabled then
        restoreLightingState()
        return
    end
    if not _originalLighting then saveLightingState() end
    Lighting.Brightness = 2.2
    Lighting.ClockTime = 20
    Lighting.OutdoorAmbient = Color3.fromRGB(60, 80, 120)
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 800
    Lighting.FogStart = 0
    Lighting.FogColor = Color3.fromRGB(60, 120, 200)
    Lighting.Ambient = Color3.fromRGB(60, 90, 140)
    local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
    if not cc then
        cc = Instance.new("ColorCorrectionEffect")
        cc.Name = "ShoxHubNeonColorCorrection"
        _neonCreatedColorCorrection = cc
        cc.Parent = Lighting
    end
    cc.Enabled = true
    cc.Brightness = 0.1
    cc.Contrast = 0.08
    cc.Saturation = 0.08
    cc.TintColor = Color3.fromRGB(200, 200, 210)
    local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
    if not bloom then
        bloom = Instance.new("BloomEffect")
        bloom.Name = "ShoxHubNeonBloom"
        _neonCreatedBloom = bloom
        bloom.Parent = Lighting
    end
    bloom.Enabled = true
    bloom.Intensity = 0.4
    bloom.Size = 20
    bloom.Threshold = 0.9
end

function toggleNeonWeather(state)
    local requestedState
    if state == nil then
        requestedState = not neonWeatherEnabled
    else
        requestedState = state == true
    end

    -- These effects are mutually exclusive so each system can restore the
    -- original Lighting snapshot without overwriting the other effect.
    if requestedState and skyTheme ~= "Off" then
        pcall(function() applyCustomSky("Off") end)
        _originalLighting = nil
    end

    neonWeatherEnabled = requestedState
    applyNeonWeather()
    if setNeonWeatherVisual then setNeonWeatherVisual(neonWeatherEnabled) end
end

function paintFloatingBtn(btnFrame, active)
    if not btnFrame then return end
    local bg = btnFrame:FindFirstChild("BtnGrad")
    local label = btnFrame:FindFirstChild("TextLabel")
    local stroke = btnFrame:FindFirstChildOfClass("UIStroke")
    btnFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)

    if active then
        if bg then
            bg.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 255, 255)),
                ColorSequenceKeypoint.new(0.35, Color3.fromRGB(248, 248, 252)),
                ColorSequenceKeypoint.new(0.70, Color3.fromRGB(225, 225, 235)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(195, 195, 208)),
            })
        end
        if label then label.TextColor3 = Color3.fromRGB(15, 15, 18) end
        if stroke then
            stroke.Color = Color3.fromRGB(255, 255, 255)
            stroke.Thickness = 1.8
            stroke.Transparency = 0.05
        end
    else
        if bg then
            bg.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(70, 70, 78)),
                ColorSequenceKeypoint.new(0.35, Color3.fromRGB(28, 28, 34)),
                ColorSequenceKeypoint.new(0.70, Color3.fromRGB(10, 10, 14)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(0, 0, 0)),
            })
        end
        if label then label.TextColor3 = Color3.fromRGB(255, 255, 255) end
        if stroke then
            stroke.Color = Color3.fromRGB(70, 70, 78)
            stroke.Thickness = 1
            stroke.Transparency = 0.45
        end
    end
end

function applyFloatingButtonScale()
    for _, uiScale in ipairs(_floatingUIScales) do
        if uiScale and uiScale.Parent then
            uiScale.Scale = floatingButtonScale
        end
    end
end

local function drag(f)
    local dn, ds, sp, di = false, nil, nil, nil
    local endConn = nil
    local function stopDrag()
        dn = false
        di = nil
        if endConn then
            endConn:Disconnect()
            endConn = nil
        end
        pcall(saveAllSettings)
    end
    f.InputBegan:Connect(function(i)
        if uiLocked then return end
        if _isDraggingButton then return end
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            -- A click on a child control should remain a click, not start a panel drag.
            local guiService = game:GetService("GuiService")
            local ok, underPointer = pcall(function()
                return guiService:GetGuiObjectsAtPosition(i.Position.X, i.Position.Y)
            end)
            if ok and underPointer then
                for _, target in ipairs(underPointer) do
                    if target ~= f and target:IsDescendantOf(f) then
                        local current = target
                        while current and current ~= f do
                            if current:IsA("GuiButton") or current:IsA("TextBox") then
                                return
                            end
                            current = current.Parent
                        end
                    end
                end
            end
            dn = true; ds = i.Position; sp = f.Position
            if endConn then endConn:Disconnect() end
            endConn = i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then stopDrag() end
            end)
        end
    end)
    f.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            stopDrag()
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            stopDrag()
        end
    end)
    f.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then di = i end
    end)
    UIS.InputChanged:Connect(function(i)
        if i == di and dn then
            if uiLocked then stopDrag(); return end
            if _isDraggingButton then return end
            if not ds or not sp then return end
            local nX = sp.X.Offset + (i.Position.X - ds.X)
            local nY = sp.Y.Offset + (i.Position.Y - ds.Y)
            f.Position = UDim2.new(sp.X.Scale, nX, sp.Y.Scale, nY)
        end
    end)
end

function setupMovementAndIndicators(char)
    if steppedConn then steppedConn:Disconnect(); steppedConn = nil end
    if movementLoop then movementLoop:Disconnect(); movementLoop = nil end

    local ccAcc = 0
    steppedConn = RunService.Heartbeat:Connect(function(dt)
        ccAcc = ccAcc + dt
        if ccAcc < 0.2 then return end -- SH-23 Fix
        ccAcc = 0
        local plist = _GetPlayersCached()
        for i = 1, #plist do
            local p = plist[i]
            if p ~= LP then
                local ch = p.Character
                if ch then
                    local parts = ch:GetChildren()
                    for j = 1, #parts do
                        local part = parts[j]
                        if part:IsA("BasePart") and part.CanCollide then
                            part.CanCollide = false
                        end
                    end
                end
            end
        end
    end)

    movementLoop = RunService.RenderStepped:Connect(function()
        local char2 = LP.Character
        if not char2 then return end
        local hum = char2:FindFirstChildOfClass("Humanoid")
        local hrp = char2:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then return end

        if not autoBatEnabled and not autoLeftEnabled and not autoRightEnabled
           and not autoBatV2Enabled and not batDesyncTpEnabled
           and not useCarrySystem then
            if _isRagdollState(hum) then
                lastMoveDir = _V3zero
            else
                local md = hum.MoveDirection
                local spd = getActiveMoveSpeed()
                local dir = nil
                if md.Magnitude > 0 then
                    lastMoveDir = md
                    dir = md
                elseif lastMoveDir.Magnitude > 0 then
                    local anyKey = false
                    for key in pairs(MOVE_KEYS) do
                        if UIS:IsKeyDown(key) then dir = lastMoveDir; anyKey = true; break end
                    end
                    if not anyKey then lastMoveDir = _V3zero end
                end
                _applyVelocitySpeed(dir, spd, hrp)
            end
        end

        if speedLabel then
            -- v1.6.0 SH-02 Fix: Zeigt die echte physikalische Velocity
            local v = hrp.AssemblyLinearVelocity
            local s = _sqrt(v.X*v.X + v.Z*v.Z)
            if s < 0.05 then s = 0 end
            speedLabel.Text = string.format("%.1f speed", s)
        end
    end)
    setupSpeedIndicator(char)
    startEnemySpeed()
end

function toggleLockUI(state)
    if state == nil then uiLocked = not uiLocked else uiLocked = state end
    if uiLocked and editModeEnabled then
        editModeEnabled = false
        if setEditModeVisual then setEditModeVisual(false) end
    end
    if setLockUIVisual then setLockUIVisual(uiLocked) end
end

function toggleEditMode(state)
    if state == nil then state = not editModeEnabled end
    if state and uiLocked then state = false end
    editModeEnabled = state
    if setEditModeVisual then setEditModeVisual(state) end
end

function disableAllAimbots()
    if autoBatEnabled then
        disableAutoBat()
        if autoBatSetVisual then autoBatSetVisual(false) end
        if mobSetAutoBat then mobSetAutoBat(false) end
    end
    if batDesyncTpEnabled then stopBatDesyncTp() end
    if autoBatV2Enabled then
        disableBatV2()
        if autoBatV2SetVisual then autoBatV2SetVisual(false) end
        if batV2FloatingButton then
            local btnFrame = batV2FloatingButton:FindFirstChild("Frame")
            if btnFrame then paintFloatingBtn(btnFrame, false) end
        end
    end
end


function stopAllBackgroundTasks()
    if CarrySystem then pcall(function() CarrySystem:stop() end) end
    if movementLoop then movementLoop:Disconnect(); movementLoop = nil end
    if steppedConn then steppedConn:Disconnect(); steppedConn = nil end
    stopEnemySpeed()
    if stretchEnabled then disableStretch() end
    if stretchConn then stretchConn:Disconnect(); stretchConn = nil end
    if stretchFovConn then stretchFovConn:Disconnect(); stretchFovConn = nil end
    if AntiRagdollV1.isRunning() then AntiRagdollV1.stop() end
    if AntiRagdollV2.Enabled then stopAntiRagdollV2() end
    if antiDieEnabled then AntiDieModule.stop() end
    if antiFlingEnabled then AntiFlingShieldModule.stop() end
    stopBatCounter()
    stopMedusaCounter()
    stopAutoSteal()
    disableAutoBat()
    if batDesyncTpEnabled then stopBatDesyncTp() end
    if autoBatV2Enabled then disableBatV2() end
    stopAutoLeft()
    stopAutoRight()
    if unwalkEnabled and not _tpBatUnwalkForced then stopUnwalk() end
    if antiLagEnabled then disableAntiLag() end
    if espEnabled then toggleESP(false) end
    if dropActive then stopDropBrainrot() end
    if bodyLockEnabled then stopBodyLock() end
    _blSuppressCount = 0
    _blWasEnabled = false
    if _blRestoreTimer then
        pcall(task.cancel, _blRestoreTimer)
        _blRestoreTimer = nil
    end
    if _bodyLockConn then
        _bodyLockConn:Disconnect()
        _bodyLockConn = nil
    end
    for _, t in ipairs(dropConnections) do
        if type(t) == "thread" then pcall(task.cancel, t)
        elseif type(t) == "RBXScriptConnection" then pcall(t.Disconnect, t) end
    end
    dropConnections = {}
    dropActive = false
    alPhase = 1
    arPhase = 1
    lastDropTime = 0
    medusaDebounce = false
    medusaLastUsed = 0
end

-- ═══════════════════════════════════════════════════════════════════════════
-- NO PLAYER COLLISION
-- ═══════════════════════════════════════════════════════════════════════════
_G.NoPlayerCollisionState = _G.NoPlayerCollisionState or {}

do
    local NPC = _G.NoPlayerCollisionState
    NPC.connections = NPC.connections or {}
    NPC.parts       = NPC.parts or {}
    NPC.charConns   = NPC.charConns or {}
    NPC.running     = NPC.running or false

    local SELF_VERIFY_INTERVAL = 1

    local function isOn() return NPC.running == true end

    local function lockPart(part, killTouch)
        if not part or not part:IsA("BasePart") then return end
        if NPC.parts[part] then return end
        local e = {cc = part.CanCollide, ct = part.CanTouch}
        NPC.parts[part] = e
        pcall(function() part.CanCollide = false end)
        if killTouch then pcall(function() part.CanTouch = false end) end
        e.conn = part:GetPropertyChangedSignal("CanCollide"):Connect(function()
            if not isOn() then return end
            if part.CanCollide then pcall(function() part.CanCollide = false end) end
        end)
        e.destroy = part.AncestryChanged:Connect(function()
            if part:IsDescendantOf(game) then return end
            if e.conn then pcall(function() e.conn:Disconnect() end) end
            if e.destroy then pcall(function() e.destroy:Disconnect() end) end
            NPC.parts[part] = nil
        end)
    end

    local function unlockPart(part)
        local e = NPC.parts[part]
        if not e then return end
        if e.conn then pcall(function() e.conn:Disconnect() end) end
        if e.destroy then pcall(function() e.destroy:Disconnect() end) end
        NPC.parts[part] = nil
        if part and part.Parent then
            pcall(function() part.CanCollide = e.cc end)
            pcall(function() part.CanTouch = e.ct end)
        end
    end

    local function reassert(char, isSelf)
        if not char then return end
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("BasePart") and NPC.parts[obj] then
                if not (isSelf and obj.Name == "HumanoidRootPart") then
                    if obj.CanCollide then pcall(function() obj.CanCollide = false end) end
                end
            end
        end
    end

    local hookHumanoid
    hookHumanoid = function(hum, char, isSelf)
        if not NPC.charConns[char] then NPC.charConns[char] = {} end
        table.insert(NPC.charConns[char], hum.StateChanged:Connect(function()
            if not isOn() then return end
            task.defer(function() if isOn() and char.Parent then reassert(char, isSelf) end end)
        end))
        table.insert(NPC.charConns[char], hum:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
            if not isOn() then return end
            task.defer(function() if isOn() and char.Parent then reassert(char, isSelf) end end)
        end))
    end

    local function hookCharacter(char, isSelf)
        if not char then return end
        if NPC.charConns[char] then return end
        NPC.charConns[char] = {}

        local function handle(obj)
            if not isOn() then return end
            if not obj:IsA("BasePart") then return end
            if isSelf and obj.Name == "HumanoidRootPart" then return end
            lockPart(obj, not isSelf)
        end

        for _, obj in ipairs(char:GetDescendants()) do handle(obj) end
        table.insert(NPC.charConns[char], char.DescendantAdded:Connect(handle))

        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then
            local hc
            hc = char.ChildAdded:Connect(function(c)
                if c:IsA("Humanoid") then
                    hc:Disconnect()
                    hookHumanoid(c, char, isSelf)
                end
            end)
            table.insert(NPC.charConns[char], hc)
        else
            hookHumanoid(hum, char, isSelf)
        end
        table.insert(NPC.charConns[char], char.AncestryChanged:Connect(function(_, parent)
            if parent == nil then
                for _, c in ipairs(NPC.charConns[char] or {}) do pcall(function() c:Disconnect() end) end
                NPC.charConns[char] = nil
            end
        end))
    end

    local function ownedByOtherPlayer(part)
        local root = part.AssemblyRootPart
        if not root then return false end
        local model = root:FindFirstAncestorOfClass("Model")
        if not model then return false end
        local plr = Players:GetPlayerFromCharacter(model)
        return plr ~= nil and plr ~= LP
    end

    local function hookWorkspacePart(obj)
        if not isOn() then return end
        if not obj:IsA("BasePart") then return end
        if NPC.parts[obj] then return end
        task.defer(function()
            if not isOn() then return end
            if not obj.Parent then return end
            if ownedByOtherPlayer(obj) then lockPart(obj, true) end
        end)
    end

    local function startCore()
        if NPC.running then return end
        NPC.running = true

        for _, c in ipairs(NPC.connections or {}) do pcall(function() c:Disconnect() end) end
        NPC.connections = {}
        local function track(c) table.insert(NPC.connections, c) end

        local function watchPlayer(plr)
            if plr == LP then return end
            if plr.Character then hookCharacter(plr.Character, false) end
            track(plr.CharacterAdded:Connect(function(char)
                if isOn() then hookCharacter(char, false) end
            end))
        end
        for _, plr in ipairs(Players:GetPlayers()) do watchPlayer(plr) end
        track(Players.PlayerAdded:Connect(watchPlayer))

        if LP.Character then hookCharacter(LP.Character, true) end
        track(LP.CharacterAdded:Connect(function(char)
            if isOn() then hookCharacter(char, true) end
        end))

        for _, obj in ipairs(Workspace:GetChildren()) do hookWorkspacePart(obj) end
        track(Workspace.DescendantAdded:Connect(hookWorkspacePart))

        if SELF_VERIFY_INTERVAL > 0 then
            local acc = 0
            track(RunService.Heartbeat:Connect(function(dt)
                if not isOn() then return end
                acc = acc + (dt or 0)
                if acc < SELF_VERIFY_INTERVAL then return end
                acc = 0
                for _, plr in ipairs(Players:GetPlayers()) do
                    local char = plr.Character
                    if char then
                        local isSelf = (plr == LP)
                        reassert(char, isSelf)
                        for _, obj in ipairs(char:GetDescendants()) do
                            if obj:IsA("BasePart") and not NPC.parts[obj] then
                                if not (isSelf and obj.Name == "HumanoidRootPart") then
                                    lockPart(obj, not isSelf)
                                end
                            end
                        end
                    end
                end
            end))
        end
    end

    local function stopCore()
        -- Clean stale state even if a previous execution already flipped running=false.
        NPC.running = false

        for _, c in ipairs(NPC.connections or {}) do pcall(function() c:Disconnect() end) end
        NPC.connections = {}

        for char, conns in pairs(NPC.charConns) do
            for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
            NPC.charConns[char] = nil
        end

        local partsToUnlock = {}
        for part in pairs(NPC.parts) do
            table.insert(partsToUnlock, part)
        end
        for _, part in ipairs(partsToUnlock) do
            unlockPart(part)
        end
        NPC.parts = {}
    end

    function _G.SetNoPlayerCollision(on)
        on = on and true or false
        noPlayerCollisionEnabled = on
        if on then startCore() else stopCore() end
    end
end

function setNoPlayerCollision(on)
    on = on and true or false
    noPlayerCollisionEnabled = on
    if on then
        if _G.SetNoPlayerCollision then _G.SetNoPlayerCollision(true) end
    else
        if _G.SetNoPlayerCollision then _G.SetNoPlayerCollision(false) end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- NO CAMERA COLLISION
-- ═══════════════════════════════════════════════════════════════════════════
_G._NoCamCollision = _G._NoCamCollision or {
    targetZoom = 10,
    currentZoom = 10,
    zoomConn = nil,
    watchConns = {},
    resync = true,
}

function enableNoCamCollision()
    noCamCollisionEnabled = true
    local NC = _G._NoCamCollision
    local cam0 = workspace.CurrentCamera
    NC.targetZoom  = math.clamp(10, LP.CameraMinZoomDistance, LP.CameraMaxZoomDistance)
    NC.currentZoom = NC.targetZoom
    NC.resync = true

    if NC.zoomConn then NC.zoomConn:Disconnect() end
    NC.zoomConn = UIS.InputChanged:Connect(function(input, gameProcessed)
        if not noCamCollisionEnabled then return end
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            local curMin = LP.CameraMinZoomDistance
            local curMax = LP.CameraMaxZoomDistance
            NC.targetZoom = math.clamp(NC.targetZoom - (input.Position.Z * 4), curMin, curMax)
        end
    end)

    for _, c in ipairs(NC.watchConns or {}) do pcall(function() c:Disconnect() end) end
    NC.watchConns = {}
    local function askResync() NC.resync = true end
    table.insert(NC.watchConns, LP:GetPropertyChangedSignal("CameraMinZoomDistance"):Connect(askResync))
    table.insert(NC.watchConns, LP:GetPropertyChangedSignal("CameraMaxZoomDistance"):Connect(askResync))
    table.insert(NC.watchConns, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(askResync))
    table.insert(NC.watchConns, LP.CharacterAdded:Connect(askResync))
    if cam0 then
        table.insert(NC.watchConns, cam0:GetPropertyChangedSignal("CameraType"):Connect(askResync))
        table.insert(NC.watchConns, cam0:GetPropertyChangedSignal("CameraSubject"):Connect(askResync))
    end

    pcall(function() RunService:UnbindFromRenderStep("FictionNoCamCollision") end)
    RunService:BindToRenderStep("FictionNoCamCollision", Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
        if not noCamCollisionEnabled then return end
        local cam = workspace.CurrentCamera
        if not cam then return end
        if cam.CameraType == Enum.CameraType.Scriptable then NC.resync = true return end
        if cam.CameraSubject == nil then NC.resync = true return end

        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then NC.resync = true return end

        local curMin = LP.CameraMinZoomDistance
        local curMax = LP.CameraMaxZoomDistance
        if curMax <= 1 then NC.resync = true return end

        local realZoom = (cam.CFrame.Position - cam.Focus.Position).Magnitude
        if realZoom < 0.6 then NC.resync = true return end

        if NC.resync or realZoom > NC.currentZoom + 0.5 then
            NC.targetZoom  = math.clamp(realZoom, curMin, curMax)
            NC.currentZoom = NC.targetZoom
            NC.resync = false
        end

        NC.targetZoom  = math.clamp(NC.targetZoom, curMin, curMax)
        NC.currentZoom = NC.currentZoom + (NC.targetZoom - NC.currentZoom) * math.min(deltaTime * 15, 1)
        cam.CFrame = cam.Focus * cam.CFrame.Rotation * _CFnew(0, 0, NC.currentZoom)
    end)
end

function disableNoCamCollision()
    noCamCollisionEnabled = false
    pcall(function() RunService:UnbindFromRenderStep("FictionNoCamCollision") end)
    if _G._NoCamCollision.zoomConn then _G._NoCamCollision.zoomConn:Disconnect(); _G._NoCamCollision.zoomConn = nil end
    for _, c in ipairs(_G._NoCamCollision.watchConns or {}) do pcall(function() c:Disconnect() end) end
    _G._NoCamCollision.watchConns = {}
end

-- ═══════════════════════════════════════════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════════════════════════════════════════
ShoxHubAutoTPDown = ShoxHubAutoTPDown == true
ShoxHubAutoTPDownHeight = tonumber(ShoxHubAutoTPDownHeight) or 20
ShoxHubShowE01Warning = ShoxHubShowE01Warning == true
function buildConfigTable()
    local config = {
        schemaVersion = 2, -- v1.6.0
        normalSpeed = NS,
        carrySpeed = CS,
        laggerSpeed1 = LAGGER_SPEED,
        laggerSpeed2 = LAGGER_CARRY_SPEED,
        stealRadius = CONFIG.STEAL_RANGE,
        antiRagdollMode = antiRagdollMode,
        antiDieEnabled = antiDieEnabled,
        autoSteal = CONFIG.AUTO_STEAL_ENABLED,
        medusaCounter = medusaCounterEnabled,
        batCounter = batCounterEnabled,
        laggerToggled = laggerToggled,
        laggerCarryToggled = laggerCarryToggled,
        carryMode = speedMode,
        batAimbotSpeed = BAT_AIMBOT_SPEED,
        dropMode = dropMode,
        stretchEnabled = stretchEnabled,
        stretchFOV = stretchFOV,
        fovEnabled = fovEnabled,
        fovValue = fovValue,
        uiScale = uiScaleValue,
        animPack = currentAnimPack,
        espEnabled = espEnabled,
        antiLag = antiLagEnabled,
        tpBatEnabled = batDesyncTpEnabled,
        neonWeather = neonWeatherEnabled,
        skyTheme = skyTheme,
        autoBatV2Enabled = autoBatV2Enabled,
        selectedAimbotMode              = selectedAimbotMode,
        ANTI_BYPASS_AIMBOT_SPEED        = _G.AceAntiBypassAimbotSpeed,
        ANTI_BYPASS_LAGGER_AIMBOT_SPEED = _G.AceAntiBypassLaggerAimbotSpeed,
        antiBypassAimbotEnabled         = _G.AceAntiBypassAimbotOn == true,
        katanaSkinEnabled = katanaSkinEnabled,
        minecraftBatSkinEnabled = minecraftBatSkinEnabled,
        minecraftBatSkinColorMode = minecraftBatSkinColorMode,
        shoxHubAutoTPDown = ShoxHubAutoTPDown,
        shoxHubAutoTPDownHeight = ShoxHubAutoTPDownHeight,
        shoxHubShowE01Warning = ShoxHubShowE01Warning,
        -- TP Bat may temporarily force Unwalk for its own movement setup.
        -- Do not persist that temporary state as the user's preference.
        unwalk = unwalkEnabled and not _tpBatUnwalkForced,
        holdJumpEnabled = infJumpEnabled,
        holdJumpMode    = infJumpMode,
        mirrorTPDown    = mirrorTPDownEnabled,
        safeMode        = antiKickEnabled,
        noPlayerCollision = noPlayerCollisionEnabled == true,
        noCamCollision    = noCamCollisionEnabled == true,
        hideMobileButtons = _G.AmbitiousHideMobileButtons == true,
        mobileHideList  = _G.AmbitiousMobileHideList,
        mobileButtonPositions = (function() local copy = {}; for k, v in pairs(savedButtonPositions or {}) do copy[k] = v end; return copy end)(),
        mobileButtonsLocked = mobileButtonsLocked,
        dropBrainrotKey = {kb = KB.DropBrainrot.kb and KB.DropBrainrot.kb.Name, gp = KB.DropBrainrot.gp and KB.DropBrainrot.gp.Name},
        autoLeftKey = {kb = KB.AutoLeft.kb and KB.AutoLeft.kb.Name, gp = KB.AutoLeft.gp and KB.AutoLeft.gp.Name},
        autoRightKey = {kb = KB.AutoRight.kb and KB.AutoRight.kb.Name, gp = KB.AutoRight.gp and KB.AutoRight.gp.Name},
        autoBatKey = {kb = KB.AutoBat.kb and KB.AutoBat.kb.Name, gp = KB.AutoBat.gp and KB.AutoBat.gp.Name},
        tpFloorKey = {kb = KB.TPFloor.kb and KB.TPFloor.kb.Name, gp = KB.TPFloor.gp and KB.TPFloor.gp.Name},
        carryToggleKey = {kb = KB.CarryToggle.kb and KB.CarryToggle.kb.Name, gp = KB.CarryToggle.gp and KB.CarryToggle.gp.Name},
        laggerModeKey = {kb = KB.LaggerMode.kb and KB.LaggerMode.kb.Name, gp = KB.LaggerMode.gp and KB.LaggerMode.gp.Name},
        tpBatKey = {kb = KB.TPBat.kb and KB.TPBat.kb.Name, gp = KB.TPBat.gp and KB.TPBat.gp.Name},
        batV2Key = {kb = KB.BatV2.kb and KB.BatV2.kb.Name, gp = KB.BatV2.gp and KB.BatV2.gp.Name},
        instaResetKey = {kb = KB.InstaReset.kb and KB.InstaReset.kb.Name, gp = KB.InstaReset.gp and KB.InstaReset.gp.Name},
        batV2FloatingPos = batV2FloatingPos,
        instaResetFloatingPos = instaResetFloatingPos,
        bodyLockEnabled = bodyLockEnabled,
        bodyLockRange = bodyLockRange,
        progressBarPos = savedProgressBarPos,
        progressBarScale = progressBarScale,
        lockUI = uiLocked,
        editMode = editModeEnabled,
        floatingButtonScale = floatingButtonScale,
        outfitIndex = currentOutfitIndex,
        backgroundIndex = backgroundIndex,
        backgroundImageTransparency = backgroundImageTransparency,
        themeColor = currentColorTheme,
        useCarrySystem = useCarrySystem,
        autoStealVariant = autoStealVariant,
        carrySysNormal = CarrySystem.normalSpeed,
        carrySysCarry = CarrySystem.carrySpeed,
        carrySysLagger = CarrySystem.laggerSpeed,
        carrySysLaggerCarry = CarrySystem.laggerCarrySpeed,
        carrySysSoftStealSpeed = CarrySystem.softStealSpeed,
        carrySysSoftStealRadius = CarrySystem.softStealRadius,
    }
    if pbFrame then
        config.progressBarPos = {
            XScale = pbFrame.Position.X.Scale,
            XOffset = pbFrame.Position.X.Offset,
            YScale = pbFrame.Position.Y.Scale,
            YOffset = pbFrame.Position.Y.Offset
        }
    end
    if MobilePanel and MobilePanel:FindFirstChild("FloatingPanel") then
        local container = MobilePanel:FindFirstChild("FloatingPanel")
        config.mobilePanelPos = {
            XScale = container.Position.X.Scale,
            XOffset = container.Position.X.Offset,
            YScale = container.Position.Y.Scale,
            YOffset = container.Position.Y.Offset
        }
    end
    return config
end

-- JSON-safe conversion for Roblox datatypes. Settings are plain data only;
-- instances/connections/functions are intentionally rejected instead of crashing saves.
local function ShoxHubToJSON(value, seen)
    local valueType = typeof(value)
    if valueType == "Vector2" then return {__shoxType="Vector2", X=value.X, Y=value.Y} end
    if valueType == "Vector3" then return {__shoxType="Vector3", X=value.X, Y=value.Y, Z=value.Z} end
    if valueType == "Color3" then return {__shoxType="Color3", R=value.R, G=value.G, B=value.B} end
    if valueType == "CFrame" then return {__shoxType="CFrame", Components={value:GetComponents()}} end
    if valueType == "UDim" then return {__shoxType="UDim", Scale=value.Scale, Offset=value.Offset} end
    if valueType == "UDim2" then return {__shoxType="UDim2", X={Scale=value.X.Scale, Offset=value.X.Offset}, Y={Scale=value.Y.Scale, Offset=value.Y.Offset}} end
    if valueType == "EnumItem" then return {__shoxType="EnumItem", EnumType=tostring(value.EnumType), Name=value.Name} end
    if valueType == "nil" or valueType == "string" or valueType == "number" or valueType == "boolean" then return value end
    if valueType ~= "table" then return nil end
    seen = seen or {}
    if seen[value] then return nil end
    seen[value] = true
    local result = {}
    for key, child in pairs(value) do
        local safeKey = (type(key) == "string" or type(key) == "number") and key or nil
        if safeKey ~= nil then result[safeKey] = ShoxHubToJSON(child, seen) end
    end
    seen[value] = nil
    return result
end

local _saveSettingsPending = false
local _saveSettingsPendingJSON = nil
local _saveSettingsLast = 0
local _saveSettingsTask = nil

local function cancelPendingSettingsSave()
    if _saveSettingsTask then
        pcall(task.cancel, _saveSettingsTask)
        _saveSettingsTask = nil
    end
    _saveSettingsPending = false
    _saveSettingsPendingJSON = nil
end

function saveAllSettings()
    if _isResetting then return true end

    -- Keep config construction inside the protected block as well: malformed
    -- runtime state must not break the UI callback that requested a save.
    local encodeOk, json = pcall(function()
        local config = buildConfigTable()
        config.themeColor = normalizeShoxTheme(currentColorTheme)
        return HS:JSONEncode(ShoxHubToJSON(config))
    end)
    if not encodeOk or type(json) ~= "string" then return false end
    if json == _lastSavedJSON then
        cancelPendingSettingsSave()
        return true
    end

    local now = os.clock()
    if now - _saveSettingsLast < 0.25 then
        _saveSettingsPending = true
        _saveSettingsPendingJSON = json -- latest immutable snapshot wins

        -- Replace the previous timer instead of allowing multiple delayed writes.
        if _saveSettingsTask then
            pcall(task.cancel, _saveSettingsTask)
            _saveSettingsTask = nil
        end

        local scheduledTask
        scheduledTask = task.delay(0.3, function()
            if _saveSettingsTask ~= scheduledTask then return end
            _saveSettingsTask = nil
            if not _saveSettingsPending then return end

            local snapshotJson = _saveSettingsPendingJSON
            _saveSettingsPending = false
            _saveSettingsPendingJSON = nil
            if _isResetting or type(snapshotJson) ~= "string" then return end

            local okWrite = pcall(function()
                writefile(CONFIG_FILE, snapshotJson)
            end)
            if okWrite then
                _lastSavedJSON = snapshotJson
                _saveSettingsLast = os.clock()
            end
        end)
        _saveSettingsTask = scheduledTask
        return true
    end

    -- A fresh immediate write supersedes any older queued snapshot.
    cancelPendingSettingsSave()
    local success = pcall(function()
        writefile(CONFIG_FILE, json)
    end)
    if success then
        _lastSavedJSON = json
        _saveSettingsLast = now
    end
    return success
end

function loadAllSettings()
    if not isfile or not isfile(CONFIG_FILE) then return false end
    local success, data = pcall(function() return HS:JSONDecode(readfile(CONFIG_FILE)) end)
    if not success or type(data) ~= "table" then return false end
    _isLoading = true

    local loadOk, loadErr = pcall(function()
        local schemaVersion = tonumber(data.schemaVersion) or 1
        if schemaVersion < 2 and data.themeColor == nil then
            data.themeColor = "Monochrome"
        end

    -- JSON values are user-editable; never let strings/NaN-like values enter
    -- movement calculations. Keep the last known-good defaults on invalid data.
    local function readNumber(value, fallback, minimum, maximum)
        local number = tonumber(value)
        if not number or number ~= number or number == math.huge or number == -math.huge then
            return fallback
        end
        return math.clamp(number, minimum, maximum)
    end
    NS = readNumber(data.normalSpeed, NS, 1, 500)
    CS = readNumber(data.carrySpeed, CS, 1, 500)
    LAGGER_SPEED = readNumber(data.laggerSpeed1, LAGGER_SPEED, 1, 500)
    LAGGER_CARRY_SPEED = readNumber(data.laggerSpeed2, LAGGER_CARRY_SPEED, 1, 500)
    CONFIG.STEAL_RANGE = readNumber(data.stealRadius, CONFIG.STEAL_RANGE, 1, 500)
    if radInput then radInput.Text = tostring(CONFIG.STEAL_RANGE) end
    uiLocked = data.lockUI == true
    editModeEnabled = data.editMode == true
    mobileButtonsLocked = data.mobileButtonsLocked == true
    if data.antiRagdollMode then
        antiRagdollMode = data.antiRagdollMode
    else
        antiRagdollMode = data.antiRagdoll and "v2" or "off"
    end
    antiDieEnabled = data.antiDieEnabled or false
    antiFlingEnabled = data.antiFlingEnabled or false
    CONFIG.AUTO_STEAL_ENABLED = data.autoSteal or false
    medusaCounterEnabled = data.medusaCounter or false
    batCounterEnabled = data.batCounter or false
    unwalkEnabled = data.unwalk or false
    antiLagEnabled = data.antiLag or false
    laggerToggled = data.laggerToggled or false
    speedMode = data.carryMode or false
    laggerCarryToggled = data.laggerCarryToggled or false

    uiScaleValue = readNumber(data.uiScale, uiScaleValue or 78, 50, 150)
    if mainUIScale then mainUIScale.Scale = uiScaleValue / 100 end
    progressBarScale = readNumber(data.progressBarScale, progressBarScale or 1, 0.5, 2)
    if pbScale then pbScale.Scale = progressBarScale end
    espEnabled = data.espEnabled or false
    if espEnabled then toggleESP(true) else toggleESP(false) end
    -- Load the persisted theme (older/invalid values fall back safely).
    currentColorTheme = normalizeShoxTheme(data.themeColor)
    selectedColor = COLOR_THEMES[currentColorTheme]
    updateAllUIThemeColors(selectedColor)

    _G.AceAntiBypassLoadFromConfig(data)
    autoBatV2Enabled = _G.AceAntiBypassAimbotOn == true
    if autoBatV2Enabled then
        task.defer(function()
            enableBatV2()
            if autoBatV2SetVisual then autoBatV2SetVisual(true) end
        end)
    else
        if autoBatV2SetVisual then autoBatV2SetVisual(false) end
    end

    katanaSkinEnabled = data.katanaSkinEnabled or false
    minecraftBatSkinEnabled = data.minecraftBatSkinEnabled or false
    minecraftBatSkinColorMode = data.minecraftBatSkinColorMode or "Default"
    if MinecraftBatSetVisual then MinecraftBatSetVisual(minecraftBatSkinEnabled) end
    if MinecraftBatColorSelector then MinecraftBatColorSelector.Text = minecraftBatSkinColorMode end
    if minecraftBatSkinEnabled then
        MinecraftBatSkin.State.enabled = true
        MinecraftBatSkin.SetColorMode(minecraftBatSkinColorMode)
        task.defer(function() pcall(MinecraftBatSkin.Apply) end)
    else
        MinecraftBatSkin.State.enabled = false
        task.defer(function() pcall(MinecraftBatSkin.Remove) end)
    end
    ShoxHubAutoTPDown = data.shoxHubAutoTPDown == true
    ShoxHubAutoTPDownHeight = math.clamp(tonumber(data.shoxHubAutoTPDownHeight) or ShoxHubAutoTPDownHeight, 0, 500)
    if ShoxHubAutoTPDownHeightBox then ShoxHubAutoTPDownHeightBox.Text = tostring(ShoxHubAutoTPDownHeight) end
    ShoxHubShowE01Warning = data.shoxHubShowE01Warning == true
    if ShoxHubAutoTPDownSetVisual then ShoxHubAutoTPDownSetVisual(ShoxHubAutoTPDown) end
    if ShoxHubShowE01WarningSetVisual then ShoxHubShowE01WarningSetVisual(ShoxHubShowE01Warning) end
    if katanaSkinEnabled then
        task.defer(function() pcall(function() KatanaSkin.ApplySkin("KATANA") end) end)
    end
    tpBatVersion = 1
    _G.__tpBatV2Distance = 8

    infJumpEnabled      = data.holdJumpEnabled == true
    infJumpMode         = (data.holdJumpMode == "MANUAL") and "MANUAL" or "HOLD"
    -- Explicitly stop stale hold/mobile/controller state when the saved toggle is off.
    if _G.setInfJumpInternal then
        _G.setInfJumpInternal(infJumpEnabled)
    elseif not infJumpEnabled and _G.AmbitiousStopNormalInfJumpHoldState then
        _G.AmbitiousStopNormalInfJumpHoldState()
    end
    mirrorTPDownEnabled = data.mirrorTPDown == true
    antiKickEnabled     = data.safeMode == true

    noPlayerCollisionEnabled = data.noPlayerCollision == true
    noCamCollisionEnabled    = data.noCamCollision == true
    -- Always synchronize runtime state with the config, including OFF;
    -- otherwise a previous injected session can leave collision disabled.
    if _G.SetNoPlayerCollision then
        _G.SetNoPlayerCollision(noPlayerCollisionEnabled)
    end
    if noCamCollisionEnabled then
        enableNoCamCollision()
    end
    if setNoPlayerCollisionVisual then
        setNoPlayerCollisionVisual(noPlayerCollisionEnabled)
    end
    if setNoCamCollisionVisual then
        setNoCamCollisionVisual(noCamCollisionEnabled)
    end

    _G.AmbitiousHideMobileButtons = data.hideMobileButtons == true
    _G.AmbitiousMobileHideList    = (type(data.mobileHideList) == "table") and data.mobileHideList or {}

    local tpBatStateLoaded = data.tpBatEnabled or false
    if tpBatStateLoaded then
        task.defer(function()
            startBatDesyncTp()
            if batDesyncTpSetVisual then batDesyncTpSetVisual(true) end
        end)
    else
        if batDesyncTpSetVisual then batDesyncTpSetVisual(false) end
    end
    -- Restore Neon Weather first because disabling it restores the captured
    -- Lighting state. Apply the saved Sky preset afterwards so it is not erased.
    neonWeatherEnabled = data.neonWeather == true
    pcall(toggleNeonWeather, neonWeatherEnabled)

    local requestedSky = data.skyTheme
    if type(requestedSky) ~= "string" or (requestedSky ~= "Off" and SKY_PRESETS[requestedSky] == nil) then
        requestedSky = "Off"
    end
    skyTheme = requestedSky
    pcall(applyCustomSky, skyTheme)
    if skySelectorLabel then skySelectorLabel.Text = skyTheme end
    if data.animPack and ANIM_PACKS[data.animPack] then
        startAnimPack(data.animPack)
    else
        currentAnimPack = "Off"
        stopAnimPack()
    end
    local function lk(e, d)
        if not d then return end
        if d.kb and Enum.KeyCode[d.kb] then e.kb = Enum.KeyCode[d.kb] end
        if d.gp and Enum.KeyCode[d.gp] then e.gp = Enum.KeyCode[d.gp] end
    end
    lk(KB.DropBrainrot, data.dropBrainrotKey)
    lk(KB.AutoLeft, data.autoLeftKey)
    lk(KB.AutoRight, data.autoRightKey)
    lk(KB.AutoBat, data.autoBatKey)
    lk(KB.TPFloor, data.tpFloorKey)
    lk(KB.CarryToggle, data.carryToggleKey)
    lk(KB.LaggerMode, data.laggerModeKey)
    lk(KB.TPBat, data.tpBatKey)
    lk(KB.BatV2, data.batV2Key)
    lk(KB.InstaReset, data.instaResetKey)
    if type(data.mobileButtonPositions) == "table" then savedButtonPositions = data.mobileButtonPositions end
    do
        local oldDefaults = {
            AutoLeft = {68, 0}, AutoBat = {0, 78}, AutoRight = {68, 78},
            TpDown = {0, 156}, Carry = {68, 156}, Lagger1 = {0, 234}, Lagger2 = {68, 234},
        }
        for buttonName, oldPos in pairs(oldDefaults) do
            local saved = savedButtonPositions and savedButtonPositions[buttonName]
            if type(saved) == "table" and saved.X == oldPos[1] and saved.Y == oldPos[2] then
                local newX, newY = getDefaultButtonPosition(buttonName)
                savedButtonPositions[buttonName] = {X = newX, Y = newY}
            end
        end
    end
    if type(data.mobilePanelPos) == "table" then savedMobilePanelPos = data.mobilePanelPos end
    if type(data.batV2FloatingPos) == "table" then batV2FloatingPos = data.batV2FloatingPos end
    if type(data.instaResetFloatingPos) == "table" then instaResetFloatingPos = data.instaResetFloatingPos end
    if type(data.progressBarPos) == "table" then savedProgressBarPos = data.progressBarPos end
    if data.bodyLockEnabled ~= nil then
        bodyLockEnabled = data.bodyLockEnabled
        if bodyLockEnabled then
            task.defer(function()
                if bodyLockSetVisual then bodyLockSetVisual(true) end
                startBodyLock()
            end)
        end
    end
    if data.bodyLockRange ~= nil then
        bodyLockRange = readNumber(data.bodyLockRange, bodyLockRange or 20, 5, 200)
        if bodyLockRangeBox then bodyLockRangeBox.Text = tostring(bodyLockRange) end
    end
    dropMode = (data.dropMode == 2) and 2 or 1
    stretchEnabled = data.stretchEnabled or false
    fovValue = readNumber(data.fovValue, fovValue or 70, 20, 120)
    fovEnabled = data.fovEnabled or false
    if fovSliderSet then fovSliderSet(fovValue) end
    if fovEnabled then enableCustomFov() end
    if setFovVisual then setFovVisual(fovEnabled) end
    stretchFOV = readNumber(data.stretchFOV, stretchFOV or 120, 1, 200)
    local savedBatAimbotSpeed = tonumber(data.batAimbotSpeed)
    -- Migrate the previous built-in default (58) to the faster V30 default.
    -- Other saved values remain user-configurable, within the UI-supported range.
    if savedBatAimbotSpeed == 58 then
        BAT_AIMBOT_SPEED = 90
    elseif savedBatAimbotSpeed then
        BAT_AIMBOT_SPEED = readNumber(savedBatAimbotSpeed, BAT_AIMBOT_SPEED, 1, 200)
    end
    floatingButtonScale = readNumber(data.floatingButtonScale, floatingButtonScale or 1, 0.5, 2)
    local savedOutfitIndex = readNumber(data.outfitIndex, 0, 0, #OUTFITS)
    savedOutfitIndex = math.floor(savedOutfitIndex)
    if savedOutfitIndex >= 1 and savedOutfitIndex <= #OUTFITS then
        currentOutfitIndex = savedOutfitIndex
        task.defer(function()
            pcall(function() applyOutfitByIndex(currentOutfitIndex) end)
            if outfitSelectorLabel then
                outfitSelectorLabel.Text = OUTFITS[currentOutfitIndex].label
            end
        end)
    end

    if data.backgroundIndex then
        backgroundIndex = math.floor(readNumber(data.backgroundIndex, backgroundIndex, 1, #BACKGROUND_IMAGES) + 0.5)
    end
    if data.backgroundImageTransparency ~= nil then
        backgroundImageTransparency = readNumber(data.backgroundImageTransparency, backgroundImageTransparency, 0, 1)
    end

    useCarrySystem = data.useCarrySystem or false
    autoStealVariant = math.floor(_clamp(readNumber(data.autoStealVariant, autoStealVariant or 1, 1, 3), 1, 3))
    if autoStealVariantLabel then
        autoStealVariantLabel.Text = autoStealVariantName(autoStealVariant)
    end
    CarrySystem.normalSpeed = readNumber(data.carrySysNormal, NS, 1, 500)
    local savedBaseCarry = tonumber(data.carrySpeed)
    local savedSystemCarry = tonumber(data.carrySysCarry)
    local loadedCarrySpeed = savedBaseCarry or savedSystemCarry or CS
    if loadedCarrySpeed <= 0 then loadedCarrySpeed = CS end
    -- v15 shipped with 29 as the default; migrate that legacy default to 30.
    if loadedCarrySpeed == 29 then loadedCarrySpeed = 30 end
    CS = _clamp(loadedCarrySpeed, 1, 500)
    CarrySystem.carrySpeed = CS
    if carryBox then carryBox.Text = tostring(CS) end
    if carrySysCarryBox then carrySysCarryBox.Text = tostring(CS) end
    CarrySystem.laggerSpeed = readNumber(data.carrySysLagger, LAGGER_SPEED, 0.1, 500)
    CarrySystem.laggerCarrySpeed = readNumber(data.carrySysLaggerCarry, LAGGER_CARRY_SPEED, 0.1, 500)
    CarrySystem.softStealSpeed = readNumber(data.carrySysSoftStealSpeed, CarrySystem.softStealSpeed or 30, 1, 500)
    CarrySystem.softStealRadius = readNumber(data.carrySysSoftStealRadius, CarrySystem.softStealRadius or 10, 1, 200)
    if useCarrySystem then
        CarrySystem:start()
        CarrySystem.speedToggled = speedMode
        if laggerCarryToggled then
            CarrySystem:setLaggerMode(2)
        elseif laggerToggled then
            CarrySystem:setLaggerMode(1)
        else
            CarrySystem:setLaggerMode(0)
        end
    else
        CarrySystem:stop()
    end

    autoBatEnabled = false
    autoLeftEnabled = false
    autoRightEnabled = false
    if dropModeBtnRef then dropModeBtnRef.Text = dropMode == 1 and "Fling" or "Jump Drop" end
    refreshSpeedModeLabel()

    if unwalkEnabled then
        task.defer(function()
            startUnwalk()
            if setUnwalkVisual then setUnwalkVisual(true) end
        end)
    else
        if setUnwalkVisual then setUnwalkVisual(false) end
    end

    local cacheOk, cacheJson = pcall(function()
        return HS:JSONEncode(ShoxHubToJSON(buildConfigTable()))
    end)
    _lastSavedJSON = cacheOk and cacheJson or nil
    end) -- pcall(loadAllSettings)

    _isLoading = false
    if not loadOk then
        warn("[ShoxHub v1.6.0] loadAllSettings partial failure: " .. tostring(loadErr))
        return false
    end
    return true
end

local contentPages = nil

function forceResetUI()
    currentColorTheme = normalizeShoxTheme(currentColorTheme)
    selectedColor = COLOR_THEMES[currentColorTheme]
    if normalBox then normalBox.Text = tostring(NS) end
    if carryBox then carryBox.Text = tostring(CS) end
    if radInput then radInput.Text = tostring(CONFIG.STEAL_RANGE) end
    if laggerBox then laggerBox.Text = tostring(LAGGER_SPEED) end
    if lagger2Box then lagger2Box.Text = tostring(LAGGER_CARRY_SPEED) end
    if batSpeedBox then batSpeedBox.Text = tostring(BAT_AIMBOT_SPEED) end
    if uiScaleBox then uiScaleBox.Text = tostring(uiScaleValue) end
    if dropModeBtnRef then dropModeBtnRef.Text = dropMode == 1 and "Fling" or "Jump Drop" end
    if bodyLockRangeBox then bodyLockRangeBox.Text = tostring(bodyLockRange) end
    if carrySysNormalBox then carrySysNormalBox.Text = tostring(CarrySystem.normalSpeed) end
    if carrySysCarryBox then carrySysCarryBox.Text = tostring(CarrySystem.carrySpeed) end
    if carrySysLaggerBox then carrySysLaggerBox.Text = tostring(CarrySystem.laggerSpeed) end
    if carrySysLaggerCarryBox then carrySysLaggerCarryBox.Text = tostring(CarrySystem.laggerCarrySpeed) end
    if carrySysSoftStealSpeedBox then carrySysSoftStealSpeedBox.Text = tostring(CarrySystem.softStealSpeed) end
    if carrySysSoftStealRadiusBox then carrySysSoftStealRadiusBox.Text = tostring(CarrySystem.softStealRadius) end
    if carrySystemToggleSetter then carrySystemToggleSetter(useCarrySystem) end
    local function safeSet(fn, val) if fn then fn(val) end end
    safeSet(autoBatSetVisual, false)
    safeSet(autoLeftSetVisual, false)
    safeSet(autoRightSetVisual, false)
    safeSet(setBatCounterVisual, false)
    safeSet(setMedusaVisual, false)
    safeSet(setUnwalkVisual, false)
    safeSet(setAntiLagVisual, false)
    safeSet(setLockUIVisual, false)
    safeSet(setEditModeVisual, false)
    safeSet(setInstaGrab, false)
    safeSet(batDesyncTpSetVisual, false)
    safeSet(setESPVIsual, false)
    safeSet(bodyLockSetVisual, false)
    safeSet(setNeonWeatherVisual, false)
    safeSet(autoBatV2SetVisual, false)
    safeSet(setAntiDieVisual, false)
    safeSet(MinecraftBatSetVisual, false)
    safeSet(setSafeModeVisual, false)
    safeSet(mirrorTPDownSetVisual, false)
    safeSet(infJumpSetVisual, false)
    safeSet(infJumpModeSetVisual, nil)
    noPlayerCollisionEnabled = false
    noCamCollisionEnabled = false
    if _G.SetNoPlayerCollision then _G.SetNoPlayerCollision(false) end
    disableNoCamCollision()
    safeSet(setNoPlayerCollisionVisual, false)
    safeSet(setNoCamCollisionVisual, false)
    if _G.stretchToggleSetter then _G.stretchToggleSetter(false) end
    safeSet(mobSetAutoBat, false)
    safeSet(mobSetAutoLeft, false)
    safeSet(mobSetAutoRight, false)
    safeSet(mobSetDropBR, false)
    safeSet(mobSetTpDown, false)
    safeSet(mobSetCarry, false)
    safeSet(mobSetLagger1, false)
    safeSet(mobSetLagger2, false)
    autoStealVariant = 1
    if autoStealVariantLabel then autoStealVariantLabel.Text = autoStealVariantName(1) end
    tpBatVersion = 1
    _G.__tpBatV2Distance = 8
    minecraftBatSkinEnabled = false
    minecraftBatSkinColorMode = "Default"
    MinecraftBatSkin.State.enabled = false
    MinecraftBatSkin.State.colorMode = "Default"
    pcall(MinecraftBatSkin.Remove)
    if MinecraftBatColorSelector then MinecraftBatColorSelector.Text = "Default" end
    refreshSpeedModeLabel()
    updateProgressBarVisibility()
    disableAntiLag()
    toggleNeonWeather(false)
    skyTheme = "Off"
    pcall(applyCustomSky, "Off")
    if skySelectorLabel then skySelectorLabel.Text = "Off" end
    disableBatV2()
    if antiDieEnabled then
        AntiDieModule.stop()
        antiDieEnabled = false
    end
    if antiFlingEnabled then
        AntiFlingShieldModule.stop()
        antiFlingEnabled = false
    end
    for _, ref in ipairs(keyButtonRefs) do
        local entry = ref.entry
        local label = (entry.gp and entry.gp.Name) or (entry.kb and entry.kb.Name) or "None"
        ref.btn.Text = label
    end
    local savedTheme = normalizeShoxTheme(currentColorTheme)
    currentColorTheme = savedTheme
    selectedColor = COLOR_THEMES[savedTheme]
    updateAllUIThemeColors(selectedColor)
    backgroundIndex = 1
    if backgroundImage then
        applyBackground(1)
    end
    if contentPages and contentPages["Visual"] then
        local vPage = contentPages["Visual"]
        for _, child in ipairs(vPage:GetChildren()) do
            if child:IsA("Frame") and child:FindFirstChild("BackgroundPreview") then
                local previewImage = child.BackgroundPreview:FindFirstChild("PreviewImage")
                local previewPlaceholder = child.BackgroundPreview:FindFirstChild("PreviewPlaceholder")
                if previewImage then previewImage.Image = "" end
                if previewPlaceholder then previewPlaceholder.Visible = true end
                break
            end
        end
    end
    if miniBtn then miniBtn.TextColor3 = Color3.fromRGB(210, 210, 220) end
    local pGui = LP:FindFirstChild("PlayerGui")
    if pGui then
        local bb = pGui:FindFirstChild("RagCountdownBillboard")
        if bb then
            local lbl = bb:FindFirstChildOfClass("TextLabel")
            if lbl then lbl.TextColor3 = Color3.fromRGB(255, 255, 255) end
        end
    end
    if MobilePanel then
        local container = MobilePanel:FindFirstChild("FloatingPanel")
        if container then
            local btnContainer = container:FindFirstChild("ButtonsContainer")
            if btnContainer then
                for _, btn in ipairs(btnContainer:GetChildren()) do
                    if btn:IsA("TextButton") then
                        local label = btn:FindFirstChildOfClass("TextLabel")
                        if label then
                            local isActive = btn.BackgroundColor3 == selectedColor
                            if not isActive then label.TextColor3 = selectedColor end
                        end
                    end
                end
            end
        end
    end
    saveAllSettings()
end

function resetFloatingPositions()
    if MobilePanel and MobilePanel:FindFirstChild("FloatingPanel") then
        local container = MobilePanel:FindFirstChild("FloatingPanel")
        container.AnchorPoint = Vector2.new(1, 0)
        container.Position = UDim2.new(1, -8, 0, 110)
        savedMobilePanelPos = nil
        savedButtonPositions = {}
        if container:FindFirstChild("ButtonsContainer") then
            for _, btn in ipairs(container.ButtonsContainer:GetChildren()) do
                if btn:IsA("TextButton") and btn.Name then
                    local defX, defY = getDefaultButtonPosition(btn.Name)
                    btn.Position = UDim2.new(0, defX, 0, defY)
                end
            end
        end
    end
    if batV2FloatingButton and batV2FloatingButton:FindFirstChild("Frame") then
        local btnFrame = batV2FloatingButton:FindFirstChild("Frame")
        btnFrame.Position = UDim2.new(0.5, -50, 0, 10)
        batV2FloatingPos = nil
    end
    if instaResetFloatingButton and instaResetFloatingButton:FindFirstChild("Frame") then
        instaResetFloatingButton.Frame.Position = UDim2.new(0.5, 90, 0, 10)
        instaResetFloatingPos = nil
    end
    if pbFrame then
        pbFrame.Position = UDim2.new(0.5, -130, 1, -60)
        savedProgressBarPos = nil
    end
    savedMobilePanelPos = nil
        batV2FloatingPos = nil
end

function resetToFactoryDefaults()
    _isResetting = true
    -- Cancel any deferred pre-reset snapshot so it cannot overwrite factory defaults.
    cancelPendingSettingsSave()
    local ok, err = pcall(function()
        stopAllBackgroundTasks()
        stopAutoSteal()
        stopBatCounter()
            stopMedusaCounter()
        if AntiRagdollV1.isRunning() then AntiRagdollV1.stop() end
        if AntiRagdollV2.Enabled then stopAntiRagdollV2() end
        if antiDieEnabled then AntiDieModule.stop() end
        if antiFlingEnabled then AntiFlingShieldModule.stop() end
        stopUnwalk()
        disableAutoBat()
        if batDesyncTpEnabled then stopBatDesyncTp() end
        disableBatV2()
        stopBodyLock()
        if espEnabled then toggleESP(false) end
        if stretchEnabled then disableStretch() end
        if antiLagEnabled then disableAntiLag() end
        if dropActive then stopDropBrainrot() end
        toggleNeonWeather(false)
        skyTheme = "Off"
        pcall(applyCustomSky, "Off")
        if skySelectorLabel then skySelectorLabel.Text = "Off" end
        if antiDieEnabled then
            AntiDieModule.stop()
            antiDieEnabled = false
        end
        if antiFlingEnabled then
            AntiFlingShieldModule.stop()
            antiFlingEnabled = false
        end
        noPlayerCollisionEnabled = false
        noCamCollisionEnabled = false
        if _G.SetNoPlayerCollision then _G.SetNoPlayerCollision(false) end
        disableNoCamCollision()
        if setNoPlayerCollisionVisual then setNoPlayerCollisionVisual(false) end
        if setNoCamCollisionVisual then setNoCamCollisionVisual(false) end
        NS = 60
        CS = 30
        LAGGER_SPEED = 15
        LAGGER_CARRY_SPEED = 24.5
        CONFIG.STEAL_RANGE = 61
        speedMode = false
        laggerToggled = false
        laggerCarryToggled = false
        antiRagdollMode = "off"
        antiDieEnabled = false
        antiFlingEnabled = false
        medusaCounterEnabled = false
        batCounterEnabled = false
        autoBatEnabled = false
        autoLeftEnabled = false
        autoRightEnabled = false
        unwalkEnabled = false
        antiLagEnabled = false
        uiLocked = false
        mobileButtonsLocked = false
        editModeEnabled = false
        CONFIG.AUTO_STEAL_ENABLED = false
        autoStealVariant = 1
        BAT_AIMBOT_SPEED = 90
        dropMode = 1
        stretchEnabled = false
        stretchFOV = 120
        fovValue = 70
        disableCustomFov()
        if fovSliderSet then fovSliderSet(70) end
        if setFovVisual then setFovVisual(false) end
        uiScaleValue = 78
        if mainUIScale then mainUIScale.Scale = 1 end
        progressBarScale = 1
        if pbScale then pbScale.Scale = progressBarScale end
        espEnabled = false
        bodyLockEnabled = false
        bodyLockRange = 20
        autoBatV2Enabled = false
        katanaSkinEnabled = false
        pcall(function() KatanaSkin.ApplySkin("NONE") end)
        minecraftBatSkinEnabled = false
        minecraftBatSkinColorMode = "Default"
        MinecraftBatSkin.State.enabled = false
        MinecraftBatSkin.State.colorMode = "Default"
        pcall(MinecraftBatSkin.Remove)
        floatingButtonScale = 1
        if batDesyncTpEnabled then stopBatDesyncTp() end
        tpBatVersion = 1
        _G.__tpBatV2Distance = 8
        currentAnimPack = "Off"
        stopAnimPack()
        currentOutfitIndex = 1
        currentColorTheme = "Monochrome"
        selectedColor = COLOR_THEMES["Monochrome"]
        backgroundIndex = 1
        backgroundImageTransparency = 0.35
        applyBackground(1)
        for key, val in pairs(DEFAULT_KB) do
            if KB[key] then
                KB[key].kb = val.kb
                KB[key].gp = val.gp
            end
        end
        useCarrySystem = false
        CarrySystem:stop()
        CarrySystem.normalSpeed = NS
        CarrySystem.carrySpeed = CS
        CarrySystem.laggerSpeed = LAGGER_SPEED
        CarrySystem.laggerCarrySpeed = LAGGER_CARRY_SPEED
        CarrySystem.softStealSpeed = 30
        CarrySystem.softStealRadius = 10
        CarrySystem.speedToggled = false
        CarrySystem.laggerMode = 0
        CarrySystem.softStealEnabled = false
        infJumpEnabled      = false
        infJumpMode         = "HOLD"
        mirrorTPDownEnabled = false
        ShoxHubAutoTPDown = false
        ShoxHubAutoTPDownHeight = 20
        ShoxHubShowE01Warning = false
        antiKickEnabled     = false
        _G.AmbitiousHideMobileButtons = false
        _G.AmbitiousMobileHideList = {}
        if _G.AmbitiousApplyMobileButtonsHidden then _G.AmbitiousApplyMobileButtonsHidden() end
        if isfile and isfile(CONFIG_FILE) then
            pcall(delfile, CONFIG_FILE)
        end
        resetFloatingPositions()
        forceResetUI()
        updateProgressBarVisibility()
        refreshSpeedModeLabel()
        _lastSavedJSON = nil
    end)
    _isResetting = false
    if ok then saveAllSettings() end
    if not ok then warn("[resetToFactoryDefaults]", err) end
    return ok
end

function updateProgressBarVisibility()
    if pbFrame then pbFrame.Visible = CONFIG.AUTO_STEAL_ENABLED end
end

function applyShimmerToText(obj, speed)
    speed = speed or 0.8
    local color = getThemeColor()
    local grad = Instance.new("UIGradient", obj)
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, color),
        ColorSequenceKeypoint.new(0.3, Color3.fromRGB(200,200,200)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255,255,255)),
        ColorSequenceKeypoint.new(0.7, Color3.fromRGB(200,200,200)),
        ColorSequenceKeypoint.new(1, color),
    })
    grad.Rotation = 45
    grad.Offset = Vector2.new(0,0)
    task.spawn(function()
        local t = 0
        while grad and grad.Parent do
            t = t + 0.02
            grad.Offset = Vector2.new(math.sin(t * speed) * 0.4, 0)
            task.wait(0.04)
        end
    end)
    return grad
end

function getDefaultButtonPosition(btnName)
    local BTN_W, BTN_H = 60, 60
    local GAP = 8
    local orderMap = {
        DropBR = 0, TPBat = 1, AutoLeft = 2, AutoBat = 3, AutoRight = 4,
        TpDown = 5, Carry = 6, Lagger1 = 7, Lagger2 = 8
    }
    local order = orderMap[btnName] or 0
    local row = _floor(order / 2)
    local col = order % 2
    return col * (BTN_W + GAP), row * (BTN_H + GAP + 10)
end

_G.AmbitiousHideMobileButtons = _G.AmbitiousHideMobileButtons == true
_G.AmbitiousMobileHideList    = type(_G.AmbitiousMobileHideList) == "table" and _G.AmbitiousMobileHideList or {}

function _G.AmbitiousMobileHideIncluded(key)
    -- Missing entries are opt-out: enabling the master switch must not hide
    -- every mobile control before the user has selected individual buttons.
    return _G.AmbitiousMobileHideList[key] == true
end

function _G.AmbitiousApplyMobileButtonsHidden()
    local hideAll = (_G.AmbitiousHideMobileButtons == true)
    local panels = {
        "FictionHubMobilePanel",
        "TpBatButton",
        "BatV2Button",
        "InstaResetButton",
    }
    local keyByPanel = {
        TpBatButton      = "tpBat",
        BatV2Button      = "batV2",
        InstaResetButton = "instaReset",
    }
    for _, name in ipairs(panels) do
        local sg = game:GetService("CoreGui"):FindFirstChild(name)
        if not sg then
            local pg = LP:FindFirstChildOfClass("PlayerGui")
            sg = pg and pg:FindFirstChild(name) or nil
        end
        if sg then
            local key = keyByPanel[name]
            if key then
                sg.Enabled = not (hideAll and _G.AmbitiousMobileHideIncluded(key))
            else
                local cont = sg:FindFirstChild("FloatingPanel")
                local btnCont = cont and cont:FindFirstChild("ButtonsContainer")
                if btnCont then
                    local btnToKey = {
                        TpDown    = "tp",
                        TPBat     = "tpBat",
                        AutoBat   = "aimbot",
                        AutoLeft  = "autoLeft",
                        AutoRight = "autoRight",
                        DropBR    = "drop",
                        Carry     = "carry",
                        Lagger1   = "laggerNormal",
                        Lagger2   = "laggerCarry",
                    }
                    for _, btn in ipairs(btnCont:GetChildren()) do
                        if btn:IsA("TextButton") then
                            local k = btnToKey[btn.Name] or btn.Name
                            btn.Visible = not (hideAll and _G.AmbitiousMobileHideIncluded(k))
                        end
                    end
                end
            end
        end
    end
end

local HIDE_BUTTONS_ITEMS = {
    { key = "drop",         label = "Drop BR" },
    { key = "tpBat",        label = "TP Bat" },
    { key = "aimbot",       label = "Bat Aimbot" },
    { key = "batV2",        label = "Bat Bypass" },
    { key = "instaReset",   label = "Insta Reset" },
    { key = "tp",           label = "TP Down" },
    { key = "autoLeft",     label = "Auto Left" },
    { key = "autoRight",    label = "Auto Right" },
    { key = "carry",        label = "Carry Speed" },
    { key = "laggerNormal", label = "Lagger Normal" },
    { key = "laggerCarry",  label = "Lagger Carry" },
}

do
    print("[IR] 1. inicio")

    if _G.InstaResetLoaded then
        print("[IR] ya cargado")
    else
        _G.InstaResetLoaded = true

        local resetCooldown          = false
        local resetThread            = nil
        local currentResetChar       = nil
        local resetSuccessful        = false
        local stopResetSequence      = false
        local cameraLocked           = false
        local lockedCameraCFrame     = nil
        local _lastInstaResetRequest = 0

        print("[IR] 2. servicios OK, LP =", LP and LP.Name)

        local function instaResetFast()
            if resetCooldown then return end
            resetCooldown     = true
            resetSuccessful   = false
            stopResetSequence = false
            cameraLocked      = false

            local character = LP.Character
            if not character then resetCooldown = false return end
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if not humanoid then resetCooldown = false return end

            local cam = workspace.CurrentCamera
            if cam then
                lockedCameraCFrame = cam.CFrame
                cameraLocked       = true
                cam.CFrame         = lockedCameraCFrame
            end

            currentResetChar = character
            local isRespawning = false

            resetThread = task.spawn(function()
                local attempts          = 0
                local maxAttempts       = 40
                local originalHipHeight = humanoid.HipHeight

                while character and character.Parent and humanoid and humanoid.Health > 0
                      and not isRespawning and not stopResetSequence do
                    if LP.Character ~= character then
                        isRespawning = true
                        break
                    end
                    pcall(function()
                        humanoid.HipHeight  = 1e30
                        humanoid.AutoRotate = true
                        local rootPart = character:FindFirstChild("HumanoidRootPart")
                        if rootPart then rootPart.CanCollide = false end
                        for _, part in ipairs(character:GetChildren()) do
                            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                                part.CanCollide = false
                            end
                        end
                    end)

                    if not character or not character.Parent or not humanoid
                       or humanoid.Health <= 0 or LP.Character ~= character then
                        resetSuccessful = true
                        break
                    end

                    attempts = attempts + 1
                    if attempts >= maxAttempts then break end
                    task.wait(0.05)
                end

                if not resetSuccessful then
                    if character and character.Parent and humanoid
                       and humanoid.Health > 0 and not isRespawning then
                        pcall(function() humanoid.Health = 0 end)
                        task.wait(0.1)
                        if not character.Parent or humanoid.Health <= 0 then
                            resetSuccessful = true
                        end
                    end
                end

                if not resetSuccessful and character and character.Parent and humanoid then
                    pcall(function()
                        humanoid.HipHeight = originalHipHeight
                        local rootPart = character:FindFirstChild("HumanoidRootPart")
                        if rootPart then rootPart.CanCollide = true end
                        for _, part in ipairs(character:GetChildren()) do
                            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                                part.CanCollide = true
                            end
                        end
                    end)
                end

                cameraLocked      = false
                resetCooldown     = false
                resetThread       = nil
                currentResetChar  = nil
                stopResetSequence = false
            end)
        end

        local function instaReset()
            local now = os.clock()
            if now - _lastInstaResetRequest < 0.75 then return end
            _lastInstaResetRequest = now
            instaResetFast()
        end

        print("[IR] 3. función lista")

        LP.CharacterAdded:Connect(function()
            stopResetSequence = true
            if resetThread then pcall(task.cancel, resetThread); resetThread = nil end
            resetCooldown    = false
            currentResetChar = nil
            cameraLocked     = false
        end)

        task.spawn(function()
            while true do
                task.wait(0.016)
                local cam = workspace.CurrentCamera
                if cameraLocked and lockedCameraCFrame and cam then
                    cam.CFrame = lockedCameraCFrame
                end
            end
        end)

        print("[IR] 4. loop cámara iniciado")

        _G.InstaReset = { Trigger = instaReset }
    end
end

function buildGui()
    local SILVER = Color3.fromRGB(245, 245, 245)
    local SILVER_DARK = Color3.fromRGB(125, 125, 125)
    local SILVER_LIGHT = Color3.fromRGB(255, 255, 255)
    local BG = Color3.fromRGB(0,0,0)
    local BG2 = Color3.fromRGB(10,10,10)
    local ROW_BG = Color3.fromRGB(10,10,10)
    local ROW_BORDER = Color3.fromRGB(50,50,50)
    local WHITE = Color3.fromRGB(255,255,255)
    local GRAY = Color3.fromRGB(60,60,60)
    local INP = Color3.fromRGB(15,15,15)
    local OFF = Color3.fromRGB(25,25,30)
    local TAB_ACTIVE = SILVER
    local TAB_INACT = SILVER_DARK
    local SECT_LBL = SILVER
    local HOV = Color3.fromRGB(25,25,25)
    local DOT_ON = SILVER
    local ON_COLOR = SILVER
    local STROKE_COLOR = Color3.fromRGB(50,50,50)
    local GUI_W, GUI_H = 330, 500

    local old = game:GetService("CoreGui"):FindFirstChild("FictionHub")
    if old then old:Destroy() end
    local pg = LP:FindFirstChild("PlayerGui")
    if pg then local o = pg:FindFirstChild("FictionHub"); if o then o:Destroy() end end

    gui = Instance.new("ScreenGui")
    gui.Name = "FictionHub"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 2000000
    gui.IgnoreGuiInset = true
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
    local guiOk = pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if not guiOk then gui.Parent = LP:WaitForChild("PlayerGui") end

    main = Instance.new("Frame", gui)
    main.Size = UDim2.new(0, GUI_W, 0, GUI_H)
    main.Position = UDim2.new(0, 20, 0, 2)
    main.BackgroundColor3 = Color3.fromRGB(5, 5, 8)
    main.BackgroundTransparency = 0
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 18)

    backgroundImage = Instance.new("ImageLabel", main)
    backgroundImage.Name = "BackgroundImage"
    backgroundImage.Size = UDim2.new(1, 0, 1, 0)
    backgroundImage.Position = UDim2.new(0, 0, 0, 0)
    backgroundImage.BackgroundTransparency = 1
    backgroundImage.BorderSizePixel = 0
    backgroundImage.Image = ""
    backgroundImage.ScaleType = Enum.ScaleType.Stretch
    backgroundImage.ImageTransparency = 1
    backgroundImage.ZIndex = 1
    Instance.new("UICorner", backgroundImage).CornerRadius = UDim.new(0, 18)

    mainUIScale = Instance.new("UIScale", main)
    mainUIScale.Scale = uiScaleValue / 100

    local titleFrame = Instance.new("Frame", main)
    titleFrame.Name = "TitleFrame"
    titleFrame.Size = UDim2.new(1, -24, 0, 116)
    titleFrame.Position = UDim2.new(0, 12, 0, 6)
    titleFrame.BackgroundTransparency = 1
    titleFrame.ZIndex = 20

    local titleImage = Instance.new("TextLabel", titleFrame)
    titleImage.Name = "TitleImage"
    titleImage.AnchorPoint = Vector2.new(0.5, 0.5)
    titleImage.Size = UDim2.new(1, 0, 1, 0)
    titleImage.Position = UDim2.new(0.5, 0, 0.5, 0)
    titleImage.BackgroundTransparency = 1
    titleImage.Text = "SHOX"
    titleImage.TextColor3 = Color3.fromRGB(245, 245, 250)
    titleImage.Font = SHOX_UI_FONT
    titleImage.TextScaled = true
    titleImage.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    titleImage.TextStrokeTransparency = 0.12
    titleImage.ZIndex = 21
    local titleConstraint = Instance.new("UITextSizeConstraint", titleImage)
    titleConstraint.MaxTextSize = 54
    titleConstraint.MinTextSize = 22

    local closeBtn = Instance.new("TextButton", main)
    closeBtn.Size = UDim2.new(0, 32, 0, 32)
    closeBtn.Position = UDim2.new(1, -42, 0, 8)
    closeBtn.BackgroundColor3 = Color3.fromRGB(30,30,35)
    closeBtn.BackgroundTransparency = 0.6
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "−"
    closeBtn.TextColor3 = WHITE
    closeBtn.Font = SHOX_UI_FONT
    closeBtn.TextSize = 26
    closeBtn.AutoButtonColor = false
    closeBtn.ZIndex = 200
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

    closeBtn.MouseEnter:Connect(function()
        TS:Create(closeBtn, TweenInfo.new(0.12), {TextColor3 = Color3.fromRGB(20,20,24), BackgroundColor3 = getThemeColor()}):Play()
    end)
    closeBtn.MouseLeave:Connect(function()
        TS:Create(closeBtn, TweenInfo.new(0.12), {TextColor3 = WHITE, BackgroundColor3 = Color3.fromRGB(30,30,35)}):Play()
    end)

    miniBtn = Instance.new("TextButton", gui)
    miniBtn.Size = UDim2.new(0, 160, 0, 42)
    miniBtn.Position = UDim2.new(0, 16, 0, 58)
    miniBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    miniBtn.BackgroundTransparency = 0
    miniBtn.BorderSizePixel = 0
    miniBtn.ClipsDescendants = true
    miniBtn.Text = ""
    miniBtn.TextColor3 = Color3.fromRGB(210, 210, 220)
    miniBtn.Font = SHOX_UI_FONT
    miniBtn.TextSize = 16
    miniBtn.ZIndex = 20
    miniBtn.Visible = false
    Instance.new("UICorner", miniBtn).CornerRadius = UDim.new(1, 0)

    local miniTitleImage = Instance.new("TextLabel", miniBtn)
    miniTitleImage.Name = "MiniTitleImage"
    miniTitleImage.AnchorPoint = Vector2.new(0.5, 0.5)
    miniTitleImage.Size = UDim2.new(0.88, 0, 0.88, 0)
    miniTitleImage.Position = UDim2.new(0.5, 0, 0.5, 0)
    miniTitleImage.BackgroundTransparency = 1
    miniTitleImage.Text = "SHOX"
    miniTitleImage.TextColor3 = Color3.fromRGB(245, 245, 250)
    miniTitleImage.Font = SHOX_UI_FONT
    miniTitleImage.TextScaled = true
    miniTitleImage.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    miniTitleImage.TextStrokeTransparency = 0.12
    miniTitleImage.ZIndex = 21
    local miniTitleConstraint = Instance.new("UITextSizeConstraint", miniTitleImage)
    miniTitleConstraint.MaxTextSize = 28
    miniTitleConstraint.MinTextSize = 16

    local slideTween = nil
    local slideTweenGeneration = 0
    local mainOriginalPos = main.Position
    local isMainSliding = false
    main:GetPropertyChangedSignal("Position"):Connect(function()
        if main and main.Visible and not isMainSliding then mainOriginalPos = main.Position end
    end)

    local function cancelSlideTween()
        -- Invalidate completion callbacks before cancelling: Tween.Completed also
        -- fires for Cancelled tweens, and an old callback must not undo a newer action.
        slideTweenGeneration = slideTweenGeneration + 1
        local previousTween = slideTween
        slideTween = nil
        if previousTween then pcall(function() previousTween:Cancel() end) end
        return slideTweenGeneration
    end

    showGui = function()
        if not main or not miniBtn then return end
        local generation = cancelSlideTween()
        isMainSliding = true
        main.Visible = true
        miniBtn.Visible = false
        main.Position = UDim2.new(0, -GUI_W - 20, 0, 2)
        local tween = TS:Create(main, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = mainOriginalPos})
        slideTween = tween
        tween.Completed:Connect(function(playbackState)
            if generation ~= slideTweenGeneration or slideTween ~= tween then return end
            slideTween = nil
            isMainSliding = false
        end)
        tween:Play()
    end

    hideGui = function()
        if not main or not miniBtn then return end
        if not main.Visible then
            cancelSlideTween()
            isMainSliding = false
            miniBtn.Visible = true
            return
        end
        local generation = cancelSlideTween()
        isMainSliding = true
        local targetPos = UDim2.new(0, -GUI_W - 20, 0, 2)
        local tween = TS:Create(main, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = targetPos})
        slideTween = tween
        tween.Completed:Connect(function(playbackState)
            if generation ~= slideTweenGeneration or slideTween ~= tween then return end
            slideTween = nil
            if playbackState == Enum.PlaybackState.Completed then
                main.Visible = false
                miniBtn.Visible = true
            end
            isMainSliding = false
        end)
        tween:Play()
    end

    closeBtn.MouseButton1Click:Connect(hideGui)
    miniBtn.MouseButton1Click:Connect(showGui)

    local tabBar = Instance.new("Frame", main)
    tabBar.Size = UDim2.new(1, -32, 0, 34)
    local tabsDivider = Instance.new("Frame", main)
    tabsDivider.Name = "TabsDivider"
    tabsDivider.Size = UDim2.new(1, -32, 0, 1)
    tabsDivider.Position = UDim2.new(0, 16, 0, 128)
    tabsDivider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    tabsDivider.BackgroundTransparency = 0.25
    tabsDivider.BorderSizePixel = 0
    tabsDivider.ZIndex = 11

    tabBar.Position = UDim2.new(0, 16, 0, 136)
    tabBar.BackgroundTransparency = 1
    tabBar.ZIndex = 10

    local tabLayout = Instance.new("UIListLayout", tabBar)
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    tabLayout.Padding = UDim.new(0, 4)

    local tabContent = Instance.new("Frame", main)
    tabContent.Size = UDim2.new(1, -16, 1, -184)
    tabContent.Position = UDim2.new(0, 8, 0, 176)
    tabContent.BackgroundTransparency = 1
    tabContent.ClipsDescendants = true
    tabContent.ZIndex = 5

    local tabs = {"Combat", "Speed", "Visual", "Settings", "Keybinds"}
    tabButtons = {}
    contentPages = {}

    for i, name in ipairs(tabs) do
        local btn = Instance.new("TextButton", tabBar)
        btn.Size = UDim2.new(0.19, 0, 1, -6)
        btn.BackgroundColor3 = Color3.fromRGB(18,18,22)
        btn.BackgroundTransparency = 0.35
        btn.BorderSizePixel = 0
        btn.Text = name
        btn.TextColor3 = TAB_INACT
        btn.Font = SHOX_UI_FONT
        btn.TextSize = 12
        btn.AutoButtonColor = false
        btn.ZIndex = 11
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
        local stroke = Instance.new("UIStroke", btn)
        stroke.Color = ROW_BORDER
        stroke.Thickness = 1

        local page = Instance.new("ScrollingFrame", tabContent)
        page.Size = UDim2.new(1, 0, 1, 0)
        page.Position = UDim2.new(0, 0, 0, 0)
        page.BackgroundColor3 = Color3.fromRGB(5,5,5)
        page.BackgroundTransparency = 0.6
        page.BorderSizePixel = 0
        page.ClipsDescendants = true
        page.ScrollBarThickness = 2
        page.ScrollBarImageColor3 = Color3.fromRGB(30,30,35)
        page.ScrollBarImageTransparency = 0.3
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.ScrollingDirection = Enum.ScrollingDirection.Y
        page.ZIndex = 6
        Instance.new("UICorner", page).CornerRadius = UDim.new(0, 16)
        page.Visible = (i == 1)

        local layout = Instance.new("UIListLayout", page)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 6)
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

        local padding = Instance.new("UIPadding", page)
        padding.PaddingLeft = UDim.new(0, 8)
        padding.PaddingRight = UDim.new(0, 8)
        padding.PaddingTop = UDim.new(0, 6)
        padding.PaddingBottom = UDim.new(0, 20)

        contentPages[name] = page

        btn.MouseButton1Click:Connect(function()
            for _, pg in pairs(contentPages) do pg.Visible = false end
            page.Visible = true
            for _, b in ipairs(tabButtons) do
                b.TextColor3 = TAB_INACT
                b.BackgroundColor3 = Color3.fromRGB(18,18,22)
            end
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.BackgroundColor3 = Color3.fromRGB(30,30,35)
        end)

        table.insert(tabButtons, btn)
    end

    if tabButtons[1] then
        tabButtons[1].TextColor3 = Color3.fromRGB(255, 255, 255)
        tabButtons[1].BackgroundColor3 = Color3.fromRGB(30,30,35)
    end

    local pageCounters = {}

    local function getNextOrder(page)
        if not pageCounters[page] then pageCounters[page] = 0 end
        pageCounters[page] = pageCounters[page] + 1
        return pageCounters[page]
    end

    local function mkSect(page, txt)
        local f = Instance.new("Frame", page)
        f.Size = UDim2.new(1, 0, 0, 26)
        f.BackgroundTransparency = 1
        f.BorderSizePixel = 0
        f.LayoutOrder = getNextOrder(page)
        f.ZIndex = 7
        local l = Instance.new("TextLabel", f)
        l.Size = UDim2.new(1, -16, 1, 0)
        l.Position = UDim2.new(0, 8, 0, 0)
        l.BackgroundTransparency = 1
        l.Text = txt:upper()
        l.TextColor3 = Color3.fromRGB(230, 230, 235)
        l.Font = SHOX_UI_FONT
        l.TextSize = 15
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextStrokeColor3 = Color3.fromRGB(60,60,60)
        l.TextStrokeTransparency = 1
        l.ZIndex = 8
        local line = Instance.new("Frame", f)
        line.Size = UDim2.new(1, -24, 0, 1.5)
        line.Position = UDim2.new(0, 12, 1, -4)
        line.BackgroundColor3 = Color3.fromRGB(200, 200, 210)
        line.BackgroundTransparency = 0.6
        line.BorderSizePixel = 0
        line.ZIndex = 8
        return f
    end

    local function mkRow(page, h)
        local f = Instance.new("Frame", page)
        f.Size = UDim2.new(1, -4, 0, h or 38)
        f.BackgroundColor3 = ROW_BG
        f.BackgroundTransparency = 0.7
        f.BorderSizePixel = 0
        f.LayoutOrder = getNextOrder(page)
        f.ZIndex = 7
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)
        local rowStroke = Instance.new("UIStroke", f)
        rowStroke.Color = ROW_BORDER
        rowStroke.Thickness = 1
        rowStroke.Transparency = 0.5
        f.MouseEnter:Connect(function()
            TS:Create(f, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(28,28,28)}):Play()
        end)
        f.MouseLeave:Connect(function()
            TS:Create(f, TweenInfo.new(0.1), {BackgroundColor3 = ROW_BG}):Play()
        end)
        return f
    end

    local function mkLabel(row, txt)
        local l = Instance.new("TextLabel", row)
        l.Size = UDim2.new(0.55, 0, 1, 0)
        l.Position = UDim2.new(0, 10, 0, 0)
        l.BackgroundTransparency = 1
        l.Text = txt
        l.TextColor3 = Color3.fromRGB(235, 235, 240)
        l.Font = SHOX_UI_FONT
        l.TextSize = 11
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextTruncate = Enum.TextTruncate.AtEnd
        l.TextStrokeColor3 = Color3.fromRGB(0,0,0)
        l.TextStrokeTransparency = 1
        l.ZIndex = 8
        return l
    end

    local function mkPill(row, offset)
        local pill = Instance.new("Frame", row)
        pill.Name = "Track"
        pill.Size = UDim2.new(0, 34, 0, 18)
        pill.AnchorPoint = Vector2.new(0.5, 0.5)
        pill.Position = UDim2.new(1, -(offset or 48), 0.5, 0)
        pill.BackgroundColor3 = Color3.fromRGB(255,255,255)
        pill.BackgroundTransparency = 0.2
        pill.BorderSizePixel = 0
        pill.ZIndex = 8
        Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 9)
        local stroke = Instance.new("UIStroke", pill)
        stroke.Color = ROW_BORDER
        stroke.Thickness = 1
        stroke.Transparency = 0.45
        stroke.Name = "PillStroke"

        local dot = Instance.new("Frame", pill)
        dot.Name = "Knob"
        dot.Size = UDim2.new(0, 13, 0, 13)
        dot.AnchorPoint = Vector2.new(0, 0)
        dot.Position = UDim2.new(0, 3, 0.5, -6)
        dot.BackgroundColor3 = Color3.fromRGB(18,18,22)
        dot.BorderSizePixel = 0
        dot.ZIndex = 9
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

        local shine = Instance.new("Frame", dot)
        shine.Name = "Shine"
        shine.Size = UDim2.new(1, -4, 0, 4)
        shine.Position = UDim2.new(0, 2, 0, 2)
        shine.BackgroundColor3 = WHITE
        shine.BackgroundTransparency = 0.72
        shine.BorderSizePixel = 0
        shine.ZIndex = 10
        Instance.new("UICorner", shine).CornerRadius = UDim.new(0, 4)

        return pill, dot
    end

    local function animPill(pill, dot, on)
        local stroke = pill:FindFirstChildOfClass("UIStroke")
        local c = getThemeColor()
        local info = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TS:Create(dot, info, {
            Position = on and UDim2.new(1, -16, 0.5, -6) or UDim2.new(0, 3, 0.5, -6),
            BackgroundColor3 = on and Color3.fromRGB(255,255,255) or Color3.fromRGB(18,18,22),
        }):Play()
        TS:Create(pill, info, {
            BackgroundColor3 = on and c or Color3.fromRGB(255,255,255),
            BackgroundTransparency = on and 0 or 0.2,
        }):Play()
        if stroke then
            TS:Create(stroke, info, {
                Color = on and c or ROW_BORDER,
                Transparency = on and 0.2 or 0.45,
                Thickness = on and 1.5 or 1,
            }):Play()
        end
    end

    local function mkSlider(row, minV, maxV, default, cb)
        local W = 118
        local track = Instance.new("Frame", row)
        track.Size = UDim2.new(0, W, 0, 4)
        track.Position = UDim2.new(1, -(W + 44), 0.5, -2)
        track.BackgroundColor3 = INP
        track.BackgroundTransparency = 0.3
        track.BorderSizePixel = 0
        track.ZIndex = 8
        Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

        local fill = Instance.new("Frame", track)
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.BackgroundColor3 = getThemeColor()
        fill.BorderSizePixel = 0
        fill.ZIndex = 9
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

        local knob = Instance.new("Frame", track)
        knob.Size = UDim2.new(0, 13, 0, 13)
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.Position = UDim2.new(0, 0, 0.5, 0)
        knob.BackgroundColor3 = WHITE
        knob.BorderSizePixel = 0
        knob.ZIndex = 11
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
        local kStroke = Instance.new("UIStroke", knob)
        kStroke.Color = getThemeColor()
        kStroke.Thickness = 2

        local valLabel = Instance.new("TextLabel", row)
        valLabel.Size = UDim2.new(0, 34, 0, 20)
        valLabel.Position = UDim2.new(1, -38, 0.5, -10)
        valLabel.BackgroundTransparency = 1
        valLabel.Text = tostring(default)
        valLabel.TextColor3 = WHITE
        valLabel.Font = SHOX_UI_FONT
        valLabel.TextSize = 11
        valLabel.TextXAlignment = Enum.TextXAlignment.Right
        valLabel.ZIndex = 9

        local hit = Instance.new("TextButton", row)
        hit.Size = UDim2.new(0, W + 16, 0, 26)
        hit.Position = UDim2.new(1, -(W + 52), 0.5, -13)
        hit.BackgroundTransparency = 1
        hit.Text = ""
        hit.AutoButtonColor = false
        hit.ZIndex = 12

        local current = default

        local function render(a)
            a = _clamp(a, 0, 1)
            fill.Size = UDim2.new(a, 0, 1, 0)
            knob.Position = UDim2.new(a, 0, 0.5, 0)
            fill.BackgroundColor3 = getThemeColor()
            kStroke.Color = getThemeColor()
        end

        local function applyFromX(px)
            local left = track.AbsolutePosition.X
            local width = track.AbsoluteSize.X
            if width <= 0 then width = W end
            if left <= 0 then return end
            local a = (px - left) / width
            a = _clamp(a, 0, 1)
            local v = _floor(minV + (maxV - minV) * a + 0.5)
            current = v
            valLabel.Text = tostring(v)
            render(a)
            if cb then pcall(cb, v) end
        end

        local dragging = false

        hit.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                _isDraggingButton = true
                applyFromX(i.Position.X)
            end
        end)

        hit.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging = false
                _isDraggingButton = false
            end
        end)

        UIS.InputChanged:Connect(function(i)
            if not dragging then return end
            if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
                applyFromX(i.Position.X)
            end
        end)

        UIS.InputEnded:Connect(function(i)
            if not dragging then return end
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging = false
                _isDraggingButton = false
            end
        end)

        local function setValue(v)
            v = _clamp(tonumber(v) or minV, minV, maxV)
            current = v
            valLabel.Text = tostring(v)
            render((v - minV) / (maxV - minV))
        end

        setValue(default)
        return setValue
    end

    local function mkToggle(page, txt, cb)
        local row = mkRow(page, 38)
        mkLabel(row, txt)
        local pill, dot = mkPill(row, 48)
        local on = false
        local function sv(s) on = s; animPill(pill, dot, s) end
        local clk = Instance.new("TextButton", pill)
        clk.Size = UDim2.new(1,0,1,0)
        clk.BackgroundTransparency = 1
        clk.Text = ""
        clk.AutoButtonColor = false
        clk.ZIndex = 10
        clk.MouseButton1Click:Connect(function()
            on = not on
            sv(on)
            pcall(cb, on)
        end)
        return sv
    end

    local function mkBox(parent, default, w, xOff, cb)
        local tb = Instance.new("TextBox", parent)
        local bw = w or 50
        local xo = math.max(xOff or 56, bw + 12)
        tb.Size = UDim2.new(0, bw, 0, 24)
        tb.Position = UDim2.new(1, -xo, 0.5, -12)
        tb.BackgroundColor3 = INP
        tb.BackgroundTransparency = 0.7
        tb.BorderSizePixel = 0
        tb.Text = tostring(default)
        tb.TextColor3 = WHITE
        tb.Font = SHOX_UI_FONT
        tb.TextSize = 11
        tb.ClearTextOnFocus = false
        tb.ZIndex = 8
        Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 6)
        local bs = Instance.new("UIStroke", tb)
        bs.Color = ROW_BORDER
        bs.Thickness = 1.2
        bs.Transparency = 0.25
        local lastValidValue = tonumber(default) or 0
        tb.Focused:Connect(function()
            TS:Create(bs, TweenInfo.new(0.12), {Color = getThemeColor(), Transparency = 0}):Play()
            -- Select the existing value so it can be replaced in one action.
            task.defer(function()
                if tb.Parent and tb:IsFocused() then
                    tb.SelectionStart = 1
                    tb.CursorPosition = #tb.Text + 1
                end
            end)
        end)
        tb.FocusLost:Connect(function()
            TS:Create(bs, TweenInfo.new(0.12), {Color = ROW_BORDER, Transparency = 0.25}):Play()
            if cb then
                local n = tonumber(tb.Text)
                if n and n == n and n ~= math.huge and n ~= -math.huge then
                    lastValidValue = n
                    cb(n)
                    if not _isLoading and not _isResetting and saveAllSettings then
                        pcall(saveAllSettings)
                    end
                else
                    tb.Text = tostring(lastValidValue)
                end
            end
        end)
        return tb
    end

    local function mkKeyButton(parent, kbEntry)
        local btn = Instance.new("TextButton", parent)
        btn.Size = UDim2.new(0, 80, 0, 24)
        btn.Position = UDim2.new(1, -88, 0.5, -12)
        btn.BackgroundColor3 = INP
        btn.BackgroundTransparency = 0.5
        btn.BorderSizePixel = 0
        local function getLabel() return (kbEntry.gp and kbEntry.gp.Name) or (kbEntry.kb and kbEntry.kb.Name) or "None" end
        btn.Text = getLabel()
        btn.TextColor3 = WHITE
        btn.Font = SHOX_UI_FONT
        btn.TextSize = 9
        btn.ZIndex = 8
        btn.AutoButtonColor = false
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        local bs = Instance.new("UIStroke", btn)
        bs.Color = ROW_BORDER
        bs.Thickness = 1
        local li = false; local lc; local pv = btn.Text; local listenStart = 0
        local captureTimeout = nil
        local function stopCapture(restoreText)
            li = false
            if lc then lc:Disconnect(); lc = nil end
            if captureTimeout then
                local timeoutThread = captureTimeout
                captureTimeout = nil
                pcall(task.cancel, timeoutThread)
            end
            if _activeKeyCapture == stopCapture then _activeKeyCapture = nil; _anyKeyListening = false end
            if restoreText and btn.Parent then btn.Text = pv end
            if btn.Parent then btn.TextColor3 = WHITE end
        end
        btn.Activated:Connect(function()
            if li then stopCapture(true); return end
            if _activeKeyCapture and _activeKeyCapture ~= stopCapture then
                pcall(_activeKeyCapture, true)
            end
            pv = btn.Text; li = true; _anyKeyListening = true; _activeKeyCapture = stopCapture
            listenStart = _tick(); btn.Text = "..."; btn.TextColor3 = WHITE
            lc = UIS.InputBegan:Connect(function(inp)
                if not li then return end
                if inp.KeyCode == Enum.KeyCode.Escape then stopCapture(true); return end
                local isGp = isGamepadInput(inp)
                if isGp and _tick()-listenStart < 0.15 then return end
                if not isBindableInput(inp) then return end
                btn.Text = inp.KeyCode.Name; pv = inp.KeyCode.Name
                if isGp then kbEntry.gp = inp.KeyCode; kbEntry.kb = nil else kbEntry.kb = inp.KeyCode; kbEntry.gp = nil end
                stopCapture(false)
            end)
            captureTimeout = task.delay(15, function()
                captureTimeout = nil
                if li then stopCapture(true) end
            end)
        end)
        btn.Destroying:Connect(function() if li then stopCapture(false) end end)
        table.insert(keyButtonRefs, {btn = btn, entry = kbEntry})
        return btn
    end

    local function mkNeoSelector(parent, defaultText, options, cb)
        local container = Instance.new("Frame", parent)
        container.Size = UDim2.new(0, 175, 0, 30)
        container.Position = UDim2.new(1, -183, 0.5, -15)
        container.BackgroundColor3 = Color3.fromRGB(18,18,22)
        container.BackgroundTransparency = 0.35
        container.BorderSizePixel = 0
        container.ZIndex = 8
        Instance.new("UICorner", container).CornerRadius = UDim.new(1, 0)

        local contStroke = Instance.new("UIStroke", container)
        contStroke.Color = ROW_BORDER
        contStroke.Thickness = 1
        contStroke.Transparency = 0.35

        local glow = Instance.new("Frame", container)
        glow.Size = UDim2.new(0, 3, 0.55, 0)
        glow.Position = UDim2.new(0, 6, 0.225, 0)
        glow.BackgroundColor3 = Color3.fromRGB(220, 220, 230)
        glow.BorderSizePixel = 0
        glow.ZIndex = 9
        Instance.new("UICorner", glow).CornerRadius = UDim.new(1, 0)

        local label = Instance.new("TextLabel", container)
        label.Size = UDim2.new(1, -80, 1, 0)
        label.Position = UDim2.new(0, 14, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = tostring(defaultText)
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.Font = SHOX_UI_FONT
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.ZIndex = 9

        local dotsRow = Instance.new("Frame", container)
        dotsRow.Size = UDim2.new(0, 70, 0, 6)
        dotsRow.Position = UDim2.new(1, -76, 0.5, -3)
        dotsRow.BackgroundTransparency = 1
        dotsRow.ZIndex = 9

        local dotsLayout = Instance.new("UIListLayout", dotsRow)
        dotsLayout.FillDirection = Enum.FillDirection.Horizontal
        dotsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
        dotsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        dotsLayout.Padding = UDim.new(0, 3)

        local MAX_DOTS = 8
        local dots = {}
        local dotCount = math.min(#options, MAX_DOTS)
        for i = 1, dotCount do
            local d = Instance.new("Frame", dotsRow)
            d.Size = UDim2.new(0, 5, 0, 5)
            d.BackgroundColor3 = Color3.fromRGB(150, 150, 160)
            d.BorderSizePixel = 0
            d.ZIndex = 10
            Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
            dots[i] = d
        end

        local currentIdx = 1
        for i, opt in ipairs(options) do
            if tostring(opt) == tostring(defaultText) then currentIdx = i; break end
        end

        local leftZone = Instance.new("TextButton", container)
        leftZone.Size = UDim2.new(0.5, 0, 1, 0)
        leftZone.Position = UDim2.new(0, 0, 0, 0)
        leftZone.BackgroundTransparency = 1
        leftZone.Text = ""
        leftZone.AutoButtonColor = false
        leftZone.ZIndex = 11

        local rightZone = Instance.new("TextButton", container)
        rightZone.Size = UDim2.new(0.5, 0, 1, 0)
        rightZone.Position = UDim2.new(0.5, 0, 0, 0)
        rightZone.BackgroundTransparency = 1
        rightZone.Text = ""
        rightZone.AutoButtonColor = false
        rightZone.ZIndex = 11

        local function refreshDotsSilent()
            local activeDot = (#options <= MAX_DOTS) and currentIdx or math.clamp(math.floor(((currentIdx - 1) / math.max(#options - 1, 1)) * (dotCount - 1) + 1.5), 1, dotCount)
            for i, d in ipairs(dots) do
                local active = (i == activeDot)
                d.BackgroundColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 160)
                d.Size = active and UDim2.new(0, 10, 0, 5) or UDim2.new(0, 5, 0, 5)
            end
        end

        local function refreshDotsAnimated()
            local activeDot = math.clamp(math.floor(((currentIdx - 1) / math.max(#options - 1, 1)) * (#dots - 1) + 1.5), 1, #dots)
            for i, d in ipairs(dots) do
                local active = (i == activeDot)
                TS:Create(d, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {
                    BackgroundColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 160),
                    Size = active and UDim2.new(0, 10, 0, 5) or UDim2.new(0, 5, 0, 5),
                }):Play()
            end
        end

        local function setTextAnimated(newText)
            local tweenOut = TS:Create(label, TweenInfo.new(0.10), {
                TextTransparency = 1,
                Position = UDim2.new(0, 22, 0, 0),
            })
            tweenOut:Play()
            tweenOut.Completed:Connect(function()
                label.Text = newText
                label.Position = UDim2.new(0, 4, 0, 0)
                TS:Create(label, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    TextTransparency = 0,
                    Position = UDim2.new(0, 14, 0, 0),
                }):Play()
            end)
        end

        local function step(dir)
            currentIdx = currentIdx + dir
            if currentIdx < 1 then currentIdx = #options end
            if currentIdx > #options then currentIdx = 1 end
            setTextAnimated(tostring(options[currentIdx]))
            refreshDotsAnimated()
            if cb then pcall(cb, options[currentIdx], currentIdx) end
        end

        leftZone.MouseButton1Click:Connect(function() step(-1) end)
        rightZone.MouseButton1Click:Connect(function() step(1) end)

        container.MouseEnter:Connect(function()
            TS:Create(contStroke, TweenInfo.new(0.12), {Color = Color3.fromRGB(220, 220, 230), Transparency = 0}):Play()
            TS:Create(glow, TweenInfo.new(0.12), {Size = UDim2.new(0, 4, 0.7, 0)}):Play()
        end)
        container.MouseLeave:Connect(function()
            TS:Create(contStroke, TweenInfo.new(0.12), {Color = ROW_BORDER, Transparency = 0.35}):Play()
            TS:Create(glow, TweenInfo.new(0.12), {Size = UDim2.new(0, 3, 0.55, 0)}):Play()
        end)

        refreshDotsSilent()

        local proxy = {}
        local labelProperties = {
            Text = true, TextColor3 = true, Font = true, TextSize = true,
            TextXAlignment = true, TextYAlignment = true, TextWrapped = true,
            TextScaled = true, TextTruncate = true, TextTransparency = true,
            TextStrokeColor3 = true, TextStrokeTransparency = true,
        }
        setmetatable(proxy, {
            __index = function(_, k)
                if k == "Parent" then return container end
                if labelProperties[k] then return label[k] end
                return container[k]
            end,
            __newindex = function(_, k, v)
                if k == "Text" then
                    local newText = tostring(v)
                    for i, opt in ipairs(options) do
                        if tostring(opt) == newText then
                            currentIdx = i
                            refreshDotsSilent()
                            break
                        end
                    end
                    label.Text = newText
                elseif labelProperties[k] then
                    label[k] = v
                else
                    container[k] = v
                end
            end,
        })
        return proxy
    end

    local function addKeybindRow(page, labelText, kbEntry)
        local row = mkRow(page, 36)
        mkLabel(row, labelText)
        mkKeyButton(row, kbEntry)
    end

    local speedPage = contentPages["Speed"]

    mkSect(speedPage, "Base Speeds")
    do
        local row = mkRow(speedPage, 38)
        mkLabel(row, "Normal Speed")
        normalBox = mkBox(row, NS, 50, 56, function(v)
            if v > 0 and v <= 500 then
                NS = v
                CarrySystem:setNormalSpeed(v)
                if carrySysNormalBox then carrySysNormalBox.Text = tostring(v) end
                saveAllSettings()
            end
        end)
    end
    do
        local row = mkRow(speedPage, 38)
        mkLabel(row, "Carry Speed")
        carryBox = mkBox(row, CS, 50, 56, function(v)
            if v > 0 and v <= 500 then
                CS = v
                CarrySystem:setCarrySpeed(v)
                if carrySysCarryBox then carrySysCarryBox.Text = tostring(v) end
                saveAllSettings()
            end
        end)
    end
    do local row = mkRow(speedPage, 38); mkLabel(row, "Lagger Normal");   laggerBox  = mkBox(row, LAGGER_SPEED, 50, 56, function(v) if v > 0 and v <= 500 then LAGGER_SPEED = v end end) end
    do local row = mkRow(speedPage, 38); mkLabel(row, "Lagger Carry");    lagger2Box = mkBox(row, LAGGER_CARRY_SPEED, 50, 56, function(v) if v > 0 and v <= 500 then LAGGER_CARRY_SPEED = v end end) end

    do
        local row = mkRow(speedPage, 38)
        mkLabel(row, "Current Mode")
        local initModeText = "Normal"
        if laggerCarryToggled then initModeText = "Lagger Carry"
        elseif laggerToggled then initModeText = "Lagger"
        elseif speedMode then initModeText = "Carry" end
        modeValLbl = mkNeoSelector(row, initModeText, {"Normal", "Carry", "Lagger", "Lagger Carry"}, function(selected)
            speedMode = false
            laggerToggled = false
            laggerCarryToggled = false
            if selected == "Carry" then
                speedMode = true
            elseif selected == "Lagger" then
                laggerToggled = true
            elseif selected == "Lagger Carry" then
                laggerCarryToggled = true
            end
            resetMovementState()
            if mobSetCarry then mobSetCarry(speedMode) end
            if mobSetLagger1 then mobSetLagger1(laggerToggled) end
            if mobSetLagger2 then mobSetLagger2(laggerCarryToggled) end
        end)
    end

    mkSect(speedPage, "Auto Carry System")
    carrySystemToggleSetter = mkToggle(speedPage, "Auto Carry", function(on)
        useCarrySystem = on
        if on then
            CarrySystem:start()
            CarrySystem.speedToggled = speedMode
            if laggerCarryToggled then
                CarrySystem:setLaggerMode(2)
            elseif laggerToggled then
                CarrySystem:setLaggerMode(1)
            else
                CarrySystem:setLaggerMode(0)
            end
            CarrySystem:setSoftStealEnabled(true)
        else
            CarrySystem:stop()
            CarrySystem:setSoftStealEnabled(false)
        end
        saveAllSettings()
    end)

    do local row = mkRow(speedPage, 38); mkLabel(row, "Normal Speed");       carrySysNormalBox          = mkBox(row, CarrySystem.normalSpeed, 50, 56, function(v) if v > 0 and v <= 500 then CarrySystem:setNormalSpeed(v); saveAllSettings() end end) end
    do
        local row = mkRow(speedPage, 38)
        mkLabel(row, "Carry Speed")
        carrySysCarryBox = mkBox(row, CarrySystem.carrySpeed, 50, 56, function(v)
            if v > 0 and v <= 500 then
                CS = v
                CarrySystem:setCarrySpeed(v)
                if carryBox then carryBox.Text = tostring(v) end
                saveAllSettings()
            end
        end)
    end
    do local row = mkRow(speedPage, 38); mkLabel(row, "Lagger Speed");       carrySysLaggerBox          = mkBox(row, CarrySystem.laggerSpeed, 50, 56, function(v) if v > 0 and v <= 500 then CarrySystem:setLaggerSpeed(v); saveAllSettings() end end) end
    do local row = mkRow(speedPage, 38); mkLabel(row, "Lagger Carry Spd");   carrySysLaggerCarryBox     = mkBox(row, CarrySystem.laggerCarrySpeed, 50, 56, function(v) if v > 0 and v <= 500 then CarrySystem:setLaggerCarrySpeed(v); saveAllSettings() end end) end
    do local row = mkRow(speedPage, 38); mkLabel(row, "Soft Steal Speed");   carrySysSoftStealSpeedBox  = mkBox(row, CarrySystem.softStealSpeed, 50, 56, function(v) if v > 0 and v <= 500 then CarrySystem:setSoftStealSpeed(v); saveAllSettings() end end) end
    do local row = mkRow(speedPage, 38); mkLabel(row, "Soft Steal Radius");  carrySysSoftStealRadiusBox = mkBox(row, CarrySystem.softStealRadius, 50, 56, function(v) if v > 0 then CarrySystem:setSoftStealRadius(v); saveAllSettings() end end) end

    mkSect(speedPage, "Auto Movement")
    autoLeftSetVisual = mkToggle(speedPage, "Auto Left", function(on)
        autoLeftEnabled = on
        if on then startAutoLeft() else stopAutoLeft() end
        if mobSetAutoLeft then mobSetAutoLeft(on) end
    end)
    autoRightSetVisual = mkToggle(speedPage, "Auto Right", function(on)
        autoRightEnabled = on
        if on then startAutoRight() else stopAutoRight() end
        if mobSetAutoRight then mobSetAutoRight(on) end
    end)

    mkSect(speedPage, "Teleport")
    do
        local row = mkRow(speedPage, 38)
        mkLabel(row, "TP Down")
        local clk = Instance.new("TextButton", row)
        clk.Size = UDim2.new(0.58, 0, 1, 0)
        clk.BackgroundTransparency = 1
        clk.Text = ""
        clk.AutoButtonColor = false
        clk.ZIndex = 8
        clk.MouseButton1Click:Connect(function() doTpDown() end)
        local actLbl = Instance.new("TextLabel", row)
        actLbl.Size = UDim2.new(0, 70, 1, 0)
        actLbl.Position = UDim2.new(1, -78, 0, 0)
        actLbl.BackgroundTransparency = 1
        actLbl.Text = "ACTIVATE"
        actLbl.TextColor3 = Color3.fromRGB(230, 230, 235)
        actLbl.Font = SHOX_UI_FONT
        actLbl.TextSize = 9
        actLbl.TextXAlignment = Enum.TextXAlignment.Right
        actLbl.ZIndex = 8
    end
    ShoxHubAutoTPDownSetVisual = mkToggle(speedPage, "Auto TP Down", function(on)
        ShoxHubAutoTPDown = on
        saveAllSettings()
    end)
    do
        local row = mkRow(speedPage, 38)
        mkLabel(row, "TP Down Height")
        ShoxHubAutoTPDownHeightBox = mkBox(row, ShoxHubAutoTPDownHeight, 50, 56, function(value)
            ShoxHubAutoTPDownHeight = math.clamp(value, 0, 500)
            saveAllSettings()
        end)
    end

    mirrorTPDownSetVisual = mkToggle(speedPage, "Mirror TP Down", function(on)
        _G.AmbitiousSetMirrorTPDown(on)
    end)

    infJumpSetVisual = mkToggle(speedPage, "Hold Jump", function(on)
        _G.setInfJumpInternal(on)
        saveAllSettings()
    end)
    do
        local row = mkRow(speedPage, 38)
        mkLabel(row, "Jump Mode")
        infJumpModeSetVisual = mkNeoSelector(row, infJumpMode, {"HOLD", "MANUAL"}, function(selected)
            if selected ~= "MANUAL" then selected = "HOLD" end
            infJumpMode = selected
            if infJumpMode == "MANUAL" then
                _G.AmbitiousStopNormalInfJumpHoldState()
            end
            saveAllSettings()
        end)
    end

    local combatPage = contentPages["Combat"]

    mkSect(combatPage, "Bat Aimbot")
    autoBatSetVisual = mkToggle(combatPage, "Bat Aimbot", function(on)
        if on then enableAutoBat() else disableAutoBat() end
        if mobSetAutoBat then mobSetAutoBat(on) end
    end)
    do local row = mkRow(combatPage, 38); mkLabel(row, "Bat Aimbot Speed"); batSpeedBox = mkBox(row, BAT_AIMBOT_SPEED, 50, 56, function(v) if v > 0 and v <= 200 then BAT_AIMBOT_SPEED = v end end) end

    batDesyncTpSetVisual = mkToggle(combatPage, "TP BAT", function(on)
        if on then
            if not batDesyncTpEnabled then toggleBatDesyncTp() end
        else
            if batDesyncTpEnabled then toggleBatDesyncTp() end
        end
    end)
    if batDesyncTpSetVisual then batDesyncTpSetVisual(batDesyncTpEnabled) end

    autoBatV2SetVisual = mkToggle(combatPage, "Bat Bypass", function(on)
        if on then enableBatV2() else disableBatV2() end
    end)
    if autoBatV2SetVisual then autoBatV2SetVisual(autoBatV2Enabled) end
    _G.AceAimbotSetVisual = autoBatV2SetVisual

    -- Auto Steal belongs with combat/gameplay actions, not general Settings.
    mkSect(combatPage, "Auto Steal")
    setInstaGrab = mkToggle(combatPage, "Auto Steal", function(on)
        CONFIG.AUTO_STEAL_ENABLED = on
        if on then pcall(startAutoSteal) else stopAutoSteal() end
        updateProgressBarVisibility()
    end)

    do
        local row = mkRow(combatPage, 38)
        mkLabel(row, "Steal Radius")
        radInput = mkBox(row, CONFIG.STEAL_RANGE, 50, 56, function(v)
            if v and v >= 5 and v <= 300 then
                CONFIG.STEAL_RANGE = _floor(v+0.5)
                Steal.StealRadius = CONFIG.STEAL_RANGE
                radInput.Text = tostring(CONFIG.STEAL_RANGE)
                saveAllSettings()
            end
        end)
    end

    do
        local row = mkRow(combatPage, 38)
        mkLabel(row, "Steal Version")
        autoStealVariantLabel = mkNeoSelector(row, autoStealVariantName(autoStealVariant), AUTO_STEAL_VARIANT_NAMES, function(selected)
            autoStealVariant = autoStealVariantFromName(selected)
            saveAllSettings()
        end)
    end


    mkSect(combatPage, "Counters")
    setBatCounterVisual = mkToggle(combatPage, "Bat Counter", function(on)
        batCounterEnabled = on
        if on then startBatCounter() else stopBatCounter() end
    end)

    setMedusaVisual = mkToggle(combatPage, "Medusa Counter", function(on)
        medusaCounterEnabled = on
        if on then
            if LP.Character then setupMedusaCounter(LP.Character) else stopMedusaCounter() end
        else
            stopMedusaCounter()
        end
        if setMedusaVisual then setMedusaVisual(on) end
    end)

    mkSect(combatPage, "Defense")
    bodyLockSetVisual = mkToggle(combatPage, "Body Lock", function(on)
        bodyLockEnabled = on
        if on then
            if _blSuppressCount == 0 then
                startBodyLock()
            else
                -- A suppression owner (e.g. TP Bat) must restore the newly enabled lock.
                _blWasEnabled = true
            end
        else
            _blWasEnabled = false
            stopBodyLock()
        end
    end)
    do
        local row = mkRow(combatPage, 38)
        mkLabel(row, "Body Lock Range")
        bodyLockRangeBox = mkBox(row, bodyLockRange, 50, 56, function(v)
            if v and v > 0 then
                bodyLockRange = _clamp(_floor(v), 5, 200)
                if bodyLockRangeBox then bodyLockRangeBox.Text = tostring(bodyLockRange) end
            end
        end)
    end

    setSafeModeVisual = mkToggle(combatPage, "Safe Mode", function(on)
        antiKickEnabled = on
        if on and _G.AmbitiousSafeModeForceStop then
            _G.AmbitiousSafeModeForceStop("SAFE MODE")
        end
        saveAllSettings()
    end)

    setNoPlayerCollisionVisual = mkToggle(combatPage, "No Player Collision", function(on)
        setNoPlayerCollision(on)
        saveAllSettings()
    end)
    if setNoPlayerCollisionVisual then setNoPlayerCollisionVisual(noPlayerCollisionEnabled) end

    mkSect(combatPage, "Survival")
    do
        local row = mkRow(combatPage, 38)
        mkLabel(row, "Anti Ragdoll")

        local initialLabel = "Off"
        if antiRagdollMode == "v1" then initialLabel = "V1"
        elseif antiRagdollMode == "v2" then initialLabel = "V2" end

        local antiRagdollSelector = mkNeoSelector(row, initialLabel, {"Off", "V1", "V2"}, function(selected)
            local mode = selected:lower()
            setAntiRagdollMode(mode)
        end)

        _G.updateAntiRagdollUI = function(mode)
            local label = "Off"
            if mode == "v1" then label = "V1"
            elseif mode == "v2" then label = "V2" end
            if antiRagdollSelector then antiRagdollSelector.Text = label end
        end

        _G.updateAntiRagdollUI(antiRagdollMode)
    end

    setUnwalkVisual = mkToggle(combatPage, "Unwalk", function(on)
        unwalkEnabled = on
        if on then startUnwalk() else stopUnwalk() end
        saveAllSettings()
    end)

    setAntiDieVisual = mkToggle(combatPage, "Anti Die", function(on)
        antiDieEnabled = on
        if on then AntiDieModule.start() else AntiDieModule.stop() end
        saveAllSettings()
    end)
    if setAntiDieVisual then setAntiDieVisual(antiDieEnabled) end

    mkSect(combatPage, "Drop")
    dropBrainrotSetVisual = mkToggle(combatPage, "Drop Brainrot", function(on)
        if on then
            executeDropWithToggle(function(v)
                dropBrainrotSetVisual(v)
                if mobSetDropBR then mobSetDropBR(v) end
            end)
        end
    end)
    setDropVisual = dropBrainrotSetVisual

    do
        local row = mkRow(combatPage, 38)
        mkLabel(row, "Drop Mode")
        dropModeBtnRef = mkNeoSelector(row, dropMode == 1 and "Fling" or "Jump Drop", {"Fling", "Jump Drop"}, function(sel)
            if dropActive then stopDropBrainrot() end
            dropMode = (sel == "Fling") and 1 or 2
        end)
    end

    local visualPage = contentPages["Visual"]

    mkSect(visualPage, "Interface")
    setEditModeVisual = mkToggle(visualPage, "Edit Button", function(on)
        toggleEditMode(on)
        if on and uiLocked then
            editModeEnabled = false
            setEditModeVisual(false)
        end
    end)
    if setEditModeVisual then setEditModeVisual(editModeEnabled) end

    setLockUIVisual = mkToggle(visualPage, "Lock UI", function(on)
        toggleLockUI(on)
        if on and editModeEnabled then
            editModeEnabled = false
            if setEditModeVisual then setEditModeVisual(false) end
        end
    end)

    setESPVIsual = mkToggle(visualPage, "Player ESP", function(on) toggleESP(on) end)

    mkSect(visualPage, "Camera")
    setFovVisual = mkToggle(visualPage, "FOV", function(on)
        if on then enableCustomFov() else disableCustomFov() end
    end)
    if setFovVisual then setFovVisual(fovEnabled) end

    do
        local row = mkRow(visualPage, 38)
        mkLabel(row, "FOV Value")
        fovSliderSet = mkSlider(row, 20, 120, fovValue, function(v)
            fovValue = v
            if not fovEnabled then
                enableCustomFov()
                if setFovVisual then setFovVisual(true) end
            end
            local cam = workspace.CurrentCamera
            if cam then pcall(function() cam.FieldOfView = fovValue end) end
        end)
    end

    setNoCamCollisionVisual = mkToggle(visualPage, "No Cam Collision", function(on)
        if on then
            enableNoCamCollision()
        else
            disableNoCamCollision()
        end
        saveAllSettings()
    end)
    if setNoCamCollisionVisual then setNoCamCollisionVisual(noCamCollisionEnabled) end

    do
        local row = mkRow(visualPage, 38)
        mkLabel(row, "Stretch Rez")
        local stretchPill, stretchDot = mkPill(row, 48)
        local stretchOn = false
        local function setStretch(s)
            stretchOn = s
            animPill(stretchPill, stretchDot, s)
            if s then enableStretch() else disableStretch() end
            stretchEnabled = s
        end
        local stretchClk = Instance.new("TextButton", stretchPill)
        stretchClk.Size = UDim2.new(1,0,1,0)
        stretchClk.BackgroundTransparency = 1
        stretchClk.Text = ""
        stretchClk.AutoButtonColor = false
        stretchClk.ZIndex = 10
        stretchClk.MouseButton1Click:Connect(function() setStretch(not stretchOn) end)
        _G.stretchToggleSetter = setStretch
    end

    mkSect(visualPage, "Performance")
    setAntiLagVisual = mkToggle(visualPage, "Anti Lag", function(on)
        if on then enableAntiLag() else disableAntiLag() end
    end)
    ShoxHubShowE01WarningSetVisual = mkToggle(visualPage, "Show E01 Warning", function(on)
        ShoxHubShowE01Warning = on
        saveAllSettings()
    end)

    mkSect(visualPage, "Environment")
    do
        local row = mkRow(visualPage, 38)
        mkLabel(row, "Sky Theme")
        skySelectorLabel = mkNeoSelector(row, skyTheme, SKY_PRESETS_LIST, function(selected)
            skyTheme = selected
            pcall(applyCustomSky, selected)
            pcall(saveAllSettings)
        end)
    end

    mkSect(visualPage, "Personalización")

    local katanaSkinSetVisual = mkToggle(visualPage, "Bat Skin", function(on)
        katanaSkinEnabled = on
        if on then
            pcall(function() KatanaSkin.ApplySkin("KATANA") end)
        else
            pcall(function() KatanaSkin.ApplySkin("NONE") end)
        end
        saveAllSettings()
    end)
    if katanaSkinSetVisual then katanaSkinSetVisual(katanaSkinEnabled) end

    MinecraftBatSetVisual = mkToggle(visualPage, "Minecraft Bat", function(on)
        minecraftBatSkinEnabled = on
        MinecraftBatSkin.State.enabled = on
        if on then
            pcall(MinecraftBatSkin.Apply)
        else
            pcall(MinecraftBatSkin.Remove)
        end
        saveAllSettings()
    end)
    if MinecraftBatSetVisual then MinecraftBatSetVisual(minecraftBatSkinEnabled) end

    do
        local row = mkRow(visualPage, 38)
        mkLabel(row, "MC Bat Color")
        local mcColorOptions = {
            "Default", "Abyss Blue", "Venom Green",
            "Royal Gold", "Velvet Rose", "Crimson Night", "RGB"
        }
        MinecraftBatColorSelector = mkNeoSelector(row, minecraftBatSkinColorMode, mcColorOptions,
            function(selected)
                minecraftBatSkinColorMode = selected
                MinecraftBatSkin.SetColorMode(selected)
                saveAllSettings()
            end)
    end

    do
        local row = mkRow(visualPage, 38)
        mkLabel(row, "Anim Pack")
        local options = {}
        for _, entry in ipairs(ANIM_PACK_ORDER) do
            table.insert(options, entry[2])
        end
        animSelectorLabel = mkNeoSelector(row, currentAnimPack, options, function(selected)
            if selected == "Off" then
                stopAnimPack()
            else
                startAnimPack(selected)
            end
        end)
    end

    do
        local row = mkRow(visualPage, 38)
        mkLabel(row, "Outfit")
        local options = {}
        for _, o in ipairs(OUTFITS) do table.insert(options, o.label) end
        outfitSelectorLabel = mkNeoSelector(row, OUTFITS[currentOutfitIndex].label, options, function(selected)
            for i, o in ipairs(OUTFITS) do
                if o.label == selected then
                    currentOutfitIndex = i
                    pcall(function() applyOutfitByIndex(currentOutfitIndex) end)
                    saveAllSettings()
                    break
                end
            end
        end)
    end

    do
        local row = mkRow(visualPage, 56)
        mkLabel(row, "Background")

        local previewFrame = Instance.new("Frame", row)
        previewFrame.Name = "BackgroundPreview"
        previewFrame.Size = UDim2.new(0, 56, 0, 44)
        previewFrame.Position = UDim2.new(1, -250, 0.5, -22)
        previewFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
        previewFrame.BackgroundTransparency = 0.15
        previewFrame.BorderSizePixel = 0
        previewFrame.ClipsDescendants = true
        previewFrame.ZIndex = 8
        Instance.new("UICorner", previewFrame).CornerRadius = UDim.new(0, 8)

        local previewStroke = Instance.new("UIStroke", previewFrame)
        previewStroke.Color = ROW_BORDER
        previewStroke.Thickness = 1.2
        previewStroke.Transparency = 0.35

        local previewImage = Instance.new("ImageLabel", previewFrame)
        previewImage.Name = "PreviewImage"
        previewImage.Size = UDim2.new(1, 0, 1, 0)
        previewImage.Position = UDim2.new(0, 0, 0, 0)
        previewImage.BackgroundTransparency = 1
        previewImage.Image = ""
        previewImage.ScaleType = Enum.ScaleType.Crop
        previewImage.ZIndex = 9
        Instance.new("UICorner", previewImage).CornerRadius = UDim.new(0, 8)

        local previewPlaceholder = Instance.new("TextLabel", previewFrame)
        previewPlaceholder.Name = "PreviewPlaceholder"
        previewPlaceholder.Size = UDim2.new(1, 0, 1, 0)
        previewPlaceholder.BackgroundTransparency = 1
        previewPlaceholder.Text = "OFF"
        previewPlaceholder.TextColor3 = Color3.fromRGB(160, 160, 170)
        previewPlaceholder.Font = SHOX_UI_FONT
        previewPlaceholder.TextSize = 12
        previewPlaceholder.ZIndex = 10

        local function updateBackgroundPreview(idx)
            local cfg = BACKGROUND_IMAGES[idx]
            if not cfg or not cfg.id or cfg.id == "" then
                previewImage.Image = ""
                previewPlaceholder.Visible = true
                previewStroke.Color = ROW_BORDER
            else
                previewImage.Image = cfg.id
                previewPlaceholder.Visible = false
                previewStroke.Color = getThemeColor()
            end
        end

        local function animatePreview()
            previewFrame.Size = UDim2.new(0, 56, 0, 44)
            TS:Create(previewFrame, TweenInfo.new(0.15, Enum.EasingStyle.Back), {
                Size = UDim2.new(0, 60, 0, 47),
            }):Play()
            task.delay(0.15, function()
                TS:Create(previewFrame, TweenInfo.new(0.15), {
                    Size = UDim2.new(0, 56, 0, 44),
                }):Play()
            end)
        end

        previewFrame.MouseEnter:Connect(function()
            TS:Create(previewStroke, TweenInfo.new(0.12), {
                Color = getThemeColor(),
                Transparency = 0.05,
            }):Play()
        end)
        previewFrame.MouseLeave:Connect(function()
            local cfg = BACKGROUND_IMAGES[backgroundIndex]
            local isOff = (not cfg) or (not cfg.id) or (cfg.id == "")
            TS:Create(previewStroke, TweenInfo.new(0.12), {
                Color = isOff and ROW_BORDER or getThemeColor(),
                Transparency = isOff and 0.35 or 0.2,
            }):Play()
        end)

        local options = {}
        for _, bg in ipairs(BACKGROUND_IMAGES) do
            table.insert(options, bg.label)
        end

        backgroundSelectorLabel = mkNeoSelector(row, BACKGROUND_IMAGES[backgroundIndex].label, options, function(selected)
            for i, bg in ipairs(BACKGROUND_IMAGES) do
                if bg.label == selected then
                    applyBackground(i)
                    updateBackgroundPreview(i)
                    animatePreview()
                    saveAllSettings()
                    break
                end
            end
        end)

        if backgroundSelectorLabel then
            local selContainer = backgroundSelectorLabel.Parent
            if selContainer and selContainer:IsA("Frame") then
                selContainer.Size = UDim2.new(0, 175, 0, 30)
                selContainer.Position = UDim2.new(1, -183, 0.5, -15)
            end
        end

        updateBackgroundPreview(backgroundIndex)
    end

    local configPage = contentPages["Settings"]

    mkSect(configPage, "Intro")
    do
        local row = mkRow(configPage, 38)
        mkLabel(row, "ShoxHub Intro")
        local info = Instance.new("TextLabel", row)
        info.BackgroundTransparency = 1
        info.Size = UDim2.new(0, 175, 1, 0)
        info.Position = UDim2.new(1, -183, 0, 0)
        info.Font = SHOX_UI_FONT
        info.TextSize = 11
        info.TextXAlignment = Enum.TextXAlignment.Right
        info.TextColor3 = Color3.fromRGB(170, 205, 235)
        info.Text = "SHOXHUB animation"
    end

    mkSect(configPage, "UI Settings")
    do
        local row = mkRow(configPage, 38)
        mkLabel(row, "UI Scale")
        uiScaleBox = mkBox(row, uiScaleValue, 50, 56, function(v)
            local n = _clamp(_floor(v+0.5), 50, 150)
            uiScaleValue = n
            if mainUIScale then mainUIScale.Scale = n/100 end
            saveAllSettings()
        end)
    end

    do
        local row = mkRow(configPage, 38)
        mkLabel(row, "Float Scale")
        local box = mkBox(row, _floor(floatingButtonScale * 100), 50, 56, function(v)
            local val = _clamp(v, 50, 200)
            floatingButtonScale = val / 100
            applyFloatingButtonScale()
            saveAllSettings()
        end)
    end

    do
        local row = mkRow(configPage, 38)
        mkLabel(row, "Steal Bar Scale")
        local box = mkBox(row, _floor(progressBarScale * 100), 50, 56, function(v)
            local val = _clamp(v, 50, 200)
            progressBarScale = val / 100
            if pbScale then pbScale.Scale = progressBarScale end
            saveAllSettings()
        end)
    end

    mkSect(configPage, "Mobile Buttons")

    do
        local setMobileButtonsLocked = mkToggle(configPage, "Lock Buttons", function(on)
            mobileButtonsLocked = (on == true)
            if MobilePanel and MobilePanel:FindFirstChild("FloatingPanel") then
                local frame = MobilePanel.FloatingPanel:FindFirstChild("ButtonsContainer")
                if frame then
                    for _, button in ipairs(frame:GetChildren()) do
                        if button:IsA("TextButton") then
                            button:SetAttribute("CanMove", not mobileButtonsLocked)
                        end
                    end
                end
            end
            saveAllSettings()
        end)
        setMobileButtonsLocked(mobileButtonsLocked)
    end

    do
        local rowHMB = mkRow(configPage, 38)
        mkLabel(rowHMB, "Hide Mobile Buttons")
        local pill, dot = mkPill(rowHMB, 48)
        local onState = (_G.AmbitiousHideMobileButtons == true)
        local function sv(s)
            onState = s
            animPill(pill, dot, s)
        end
        sv(onState)
        local clk = Instance.new("TextButton", pill)
        clk.Size = UDim2.new(1,0,1,0)
        clk.BackgroundTransparency = 1
        clk.Text = ""
        clk.AutoButtonColor = false
        clk.ZIndex = 10
        clk.MouseButton1Click:Connect(function()
            onState = not onState
            _G.AmbitiousHideMobileButtons = onState
            sv(onState)
            _G.AmbitiousApplyMobileButtonsHidden()
            saveAllSettings()
        end)
    end

    do
        local ROW_H = 34
        local GAP = 6
        local HOLDER_H = #HIDE_BUTTONS_ITEMS * ROW_H + (#HIDE_BUTTONS_ITEMS - 1) * GAP + 8

        local rowArrow = mkRow(configPage, 38)
        mkLabel(rowArrow, "Buttons to Hide")

        local listHolder = Instance.new("Frame", configPage)
        listHolder.Name = "HideButtonsList"
        listHolder.BackgroundTransparency = 1
        listHolder.Size = UDim2.new(1, -4, 0, HOLDER_H)
        listHolder.LayoutOrder = getNextOrder(configPage)
        listHolder.ZIndex = 7
        listHolder.ClipsDescendants = true
        listHolder.Visible = false

        local listLayout = Instance.new("UIListLayout", listHolder)
        listLayout.Padding = UDim.new(0, GAP)
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

        local listPad = Instance.new("UIPadding", listHolder)
        listPad.PaddingTop = UDim.new(0, 4)

        for i, item in ipairs(HIDE_BUTTONS_ITEMS) do
            local r = Instance.new("Frame", listHolder)
            r.Name = "HideOpt_" .. item.key
            r.BackgroundColor3 = ROW_BG
            r.BackgroundTransparency = 0.7
            r.Size = UDim2.new(1, -4, 0, 34)
            r.BorderSizePixel = 0
            r.LayoutOrder = i
            r.ZIndex = 7
            Instance.new("UICorner", r).CornerRadius = UDim.new(0, 9)
            local rStroke = Instance.new("UIStroke", r)
            rStroke.Color = ROW_BORDER
            rStroke.Thickness = 1
            rStroke.Transparency = 0.5

            local lbl = Instance.new("TextLabel", r)
            lbl.BackgroundTransparency = 1
            lbl.Text = item.label
            lbl.TextColor3 = Color3.fromRGB(235, 235, 240)
            lbl.Font = SHOX_UI_FONT
            lbl.TextSize = 11
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Position = UDim2.new(0, 12, 0, 0)
            lbl.Size = UDim2.new(1, -70, 1, 0)
            lbl.ZIndex = 8

            local startOn = _G.AmbitiousMobileHideIncluded(item.key)

            local track = Instance.new("Frame", r)
            track.Name = "Track"
            track.Size = UDim2.new(0, 34, 0, 18)
            track.AnchorPoint = Vector2.new(0.5, 0.5)
            track.Position = UDim2.new(1, -48, 0.5, 0)
            track.BackgroundColor3 = Color3.fromRGB(255,255,255)
            track.BackgroundTransparency = startOn and 0 or 0.2
            track.BorderSizePixel = 0
            track.ZIndex = 8
            Instance.new("UICorner", track).CornerRadius = UDim.new(0, 9)
            local trackStroke = Instance.new("UIStroke", track)
            trackStroke.Color = ROW_BORDER
            trackStroke.Thickness = 1
            trackStroke.Transparency = 0.45

            local dot = Instance.new("Frame", track)
            dot.Name = "Knob"
            dot.Size = UDim2.new(0, 13, 0, 13)
            dot.AnchorPoint = Vector2.new(0, 0)
            dot.Position = startOn and UDim2.new(1, -16, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
            dot.BackgroundColor3 = startOn and Color3.fromRGB(255,255,255) or Color3.fromRGB(18,18,22)
            dot.BorderSizePixel = 0
            dot.ZIndex = 9
            Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

            local clk = Instance.new("TextButton", track)
            clk.Size = UDim2.new(1,0,1,0)
            clk.BackgroundTransparency = 1
            clk.Text = ""
            clk.AutoButtonColor = false
            clk.ZIndex = 10
            clk.MouseButton1Click:Connect(function()
                local on = not _G.AmbitiousMobileHideIncluded(item.key)
                _G.AmbitiousMobileHideList[item.key] = on
                animPill(track, dot, on)
                _G.AmbitiousApplyMobileButtonsHidden()
                saveAllSettings()
            end)
        end

        local arrowBtn = Instance.new("TextButton", rowArrow)
        arrowBtn.Size = UDim2.new(0, 28, 0, 24)
        arrowBtn.Position = UDim2.new(1, -38, 0.5, -12)
        arrowBtn.BackgroundColor3 = Color3.fromRGB(15,15,15)
        arrowBtn.Text = "▼"
        arrowBtn.TextColor3 = Color3.fromRGB(220,220,230)
        arrowBtn.Font = SHOX_UI_FONT
        arrowBtn.TextSize = 14
        arrowBtn.AutoButtonColor = false
        arrowBtn.ZIndex = 8
        Instance.new("UICorner", arrowBtn).CornerRadius = UDim.new(0, 6)
        local ex = false
        arrowBtn.MouseButton1Click:Connect(function()
            ex = not ex
            listHolder.Visible = ex
            arrowBtn.Text = ex and "▲" or "▼"
        end)
    end

    mkSect(configPage, "UI Theme")
    do
        local row = mkRow(configPage, 42)
        local info = Instance.new("TextLabel", row)
        info.BackgroundTransparency = 1
        info.Position = UDim2.new(0, 10, 0, 0)
        info.Size = UDim2.new(1, -20, 1, 0)
        info.Font = SHOX_UI_FONT
        info.TextSize = 12
        info.TextXAlignment = Enum.TextXAlignment.Left
        info.TextColor3 = Color3.fromRGB(245, 245, 245)
        info.Text = "BLACK & WHITE  •  FIXED ACCENT"
        info.ZIndex = 8
    end

    mkSect(configPage, "Config Management")

    do
        local row = mkRow(configPage, 44)
        row.Size = UDim2.new(1, 0, 0, 44)
        local saveBtn = Instance.new("TextButton", row)
        saveBtn.Size = UDim2.new(1, -20, 0.82, 0)
        saveBtn.Position = UDim2.new(0, 10, 0.09, 0)
        saveBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        saveBtn.BorderSizePixel = 0
        saveBtn.Text = ""
        saveBtn.AutoButtonColor = false
        saveBtn.ZIndex = 8
        Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(1, 0)

        local saveGrad = Instance.new("UIGradient", saveBtn)
        saveGrad.Rotation = 90
        saveGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(245, 245, 245)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(95, 95, 95)),
        })

        local saveStroke = Instance.new("UIStroke", saveBtn)
        saveStroke.Color = Color3.fromRGB(220, 220, 220)
        saveStroke.Thickness = 1.5
        saveStroke.Transparency = 0.35

        local saveLbl = Instance.new("TextLabel", saveBtn)
        saveLbl.Size = UDim2.new(1, 0, 1, 0)
        saveLbl.BackgroundTransparency = 1
        saveLbl.Text = "SAVE CONFIG"
        saveLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        saveLbl.Font = SHOX_UI_FONT
        saveLbl.TextSize = 13
        saveLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        saveLbl.TextStrokeTransparency = 0.55
        saveLbl.ZIndex = 9

        saveBtn.MouseEnter:Connect(function()
            TS:Create(saveBtn, TweenInfo.new(0.14, Enum.EasingStyle.Quad), {
                Size = UDim2.new(1, -12, 0.92, 0),
                Position = UDim2.new(0, 6, 0.04, 0),
            }):Play()
            TS:Create(saveStroke, TweenInfo.new(0.14), {Transparency = 0.05}):Play()
        end)
        saveBtn.MouseLeave:Connect(function()
            TS:Create(saveBtn, TweenInfo.new(0.14, Enum.EasingStyle.Quad), {
                Size = UDim2.new(1, -20, 0.82, 0),
                Position = UDim2.new(0, 10, 0.09, 0),
            }):Play()
            TS:Create(saveStroke, TweenInfo.new(0.14), {Transparency = 0.35}):Play()
        end)
        saveBtn.MouseButton1Click:Connect(function()
            local ok = saveAllSettings()
            saveLbl.Text = ok and "SAVED ✓" or "ERROR"
            task.delay(1.2, function()
                if saveLbl and saveLbl.Parent then saveLbl.Text = "SAVE CONFIG" end
            end)
        end)
    end

    do
        local row = mkRow(configPage, 44)
        row.Size = UDim2.new(1, 0, 0, 44)
        local resetPosBtn = Instance.new("TextButton", row)
        resetPosBtn.Size = UDim2.new(1, -20, 0.82, 0)
        resetPosBtn.Position = UDim2.new(0, 10, 0.09, 0)
        resetPosBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        resetPosBtn.BorderSizePixel = 0
        resetPosBtn.Text = ""
        resetPosBtn.AutoButtonColor = false
        resetPosBtn.ZIndex = 8
        Instance.new("UICorner", resetPosBtn).CornerRadius = UDim.new(1, 0)

        local resetGrad = Instance.new("UIGradient", resetPosBtn)
        resetGrad.Rotation = 90
        resetGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(65, 95, 35)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(18, 25, 14)),
        })

        local resetStroke = Instance.new("UIStroke", resetPosBtn)
        resetStroke.Color = Color3.fromRGB(220, 220, 220)
        resetStroke.Thickness = 1.5
        resetStroke.Transparency = 0.35

        local resetLbl = Instance.new("TextLabel", resetPosBtn)
        resetLbl.Size = UDim2.new(1, 0, 1, 0)
        resetLbl.BackgroundTransparency = 1
        resetLbl.Text = "RESET POSITIONS"
        resetLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        resetLbl.Font = SHOX_UI_FONT
        resetLbl.TextSize = 13
        resetLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        resetLbl.TextStrokeTransparency = 0.55
        resetLbl.ZIndex = 9

        resetPosBtn.MouseEnter:Connect(function()
            TS:Create(resetPosBtn, TweenInfo.new(0.14, Enum.EasingStyle.Quad), {
                Size = UDim2.new(1, -12, 0.92, 0),
                Position = UDim2.new(0, 6, 0.04, 0),
            }):Play()
            TS:Create(resetStroke, TweenInfo.new(0.14), {Transparency = 0.05}):Play()
        end)
        resetPosBtn.MouseLeave:Connect(function()
            TS:Create(resetPosBtn, TweenInfo.new(0.14, Enum.EasingStyle.Quad), {
                Size = UDim2.new(1, -20, 0.82, 0),
                Position = UDim2.new(0, 10, 0.09, 0),
            }):Play()
            TS:Create(resetStroke, TweenInfo.new(0.14), {Transparency = 0.35}):Play()
        end)

        local resetDebounce = false
        resetPosBtn.MouseButton1Click:Connect(function()
            if resetDebounce then return end
            resetDebounce = true
            resetFloatingPositions()
            resetLbl.Text = "RESET ✓"
            task.delay(1.2, function()
                if resetLbl and resetLbl.Parent then
                    resetLbl.Text = "RESET POSITIONS"
                    resetDebounce = false
                end
            end)
        end)
    end

    do
        local row = mkRow(configPage, 44)
        row.Size = UDim2.new(1, 0, 0, 44)
        local delBtn = Instance.new("TextButton", row)
        delBtn.Size = UDim2.new(1, -20, 0.82, 0)
        delBtn.Position = UDim2.new(0, 10, 0.09, 0)
        delBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        delBtn.BorderSizePixel = 0
        delBtn.Text = ""
        delBtn.AutoButtonColor = false
        delBtn.ZIndex = 8
        Instance.new("UICorner", delBtn).CornerRadius = UDim.new(1, 0)

        local delGrad = Instance.new("UIGradient", delBtn)
        delGrad.Rotation = 90
        delGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(180, 45, 80)),
            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(120, 25, 55)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(60, 10, 30)),
        })

        local delStroke = Instance.new("UIStroke", delBtn)
        delStroke.Color = Color3.fromRGB(255, 130, 170)
        delStroke.Thickness = 1.5
        delStroke.Transparency = 0.35

        local delLbl = Instance.new("TextLabel", delBtn)
        delLbl.Size = UDim2.new(1, 0, 1, 0)
        delLbl.BackgroundTransparency = 1
        delLbl.Text = "DELETE SETTINGS"
        delLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        delLbl.Font = SHOX_UI_FONT
        delLbl.TextSize = 13
        delLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        delLbl.TextStrokeTransparency = 0.55
        delLbl.ZIndex = 9

        delBtn.MouseEnter:Connect(function()
            TS:Create(delBtn, TweenInfo.new(0.14, Enum.EasingStyle.Quad), {
                Size = UDim2.new(1, -12, 0.92, 0),
                Position = UDim2.new(0, 6, 0.04, 0),
            }):Play()
            TS:Create(delStroke, TweenInfo.new(0.14), {Transparency = 0.05}):Play()
        end)
        delBtn.MouseLeave:Connect(function()
            TS:Create(delBtn, TweenInfo.new(0.14, Enum.EasingStyle.Quad), {
                Size = UDim2.new(1, -20, 0.82, 0),
                Position = UDim2.new(0, 10, 0.09, 0),
            }):Play()
            TS:Create(delStroke, TweenInfo.new(0.14), {Transparency = 0.35}):Play()
        end)

        local deleteState = 0
        local originalDeleteText = "DELETE SETTINGS"
        local delDebounce = false
        delBtn.MouseButton1Click:Connect(function()
            if delDebounce then return end
            if deleteState == 0 then
                deleteState = 1
                delLbl.Text = "CONFIRM?"
                delGrad.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(230, 70, 100)),
                    ColorSequenceKeypoint.new(0.50, Color3.fromRGB(180, 40, 70)),
                    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(90, 15, 40)),
                })
                task.delay(2, function()
                    if delBtn and delBtn.Parent and deleteState == 1 then
                        deleteState = 0
                        delLbl.Text = originalDeleteText
                        delGrad.Color = ColorSequence.new({
                            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(180, 45, 80)),
                            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(120, 25, 55)),
                            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(60, 10, 30)),
                        })
                    end
                end)
            elseif deleteState == 1 then
                delDebounce = true
                local success = pcall(resetToFactoryDefaults)
                delLbl.Text = success and "DELETED ✓" or "ERROR"
                deleteState = 0
                task.delay(1.5, function()
                    if delLbl and delLbl.Parent then
                        delLbl.Text = originalDeleteText
                        delGrad.Color = ColorSequence.new({
                            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(180, 45, 80)),
                            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(120, 25, 55)),
                            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(60, 10, 30)),
                        })
                        delDebounce = false
                    end
                end)
            end
        end)
    end

    local keyPage = contentPages["Keybinds"]
    mkSect(keyPage, "Keybinds")
    addKeybindRow(keyPage, "Carry Mode", KB.CarryToggle)
    addKeybindRow(keyPage, "Lagger Mode", KB.LaggerMode)
    addKeybindRow(keyPage, "Auto Left", KB.AutoLeft)
    addKeybindRow(keyPage, "Auto Right", KB.AutoRight)
    addKeybindRow(keyPage, "Auto Bat", KB.AutoBat)
    addKeybindRow(keyPage, "TP BAT", KB.TPBat)
    addKeybindRow(keyPage, "Bat Bypass", KB.BatV2)
    addKeybindRow(keyPage, "Insta Reset", KB.InstaReset)
    addKeybindRow(keyPage, "TP Down", KB.TPFloor)
    addKeybindRow(keyPage, "Drop Brainrot", KB.DropBrainrot)
    addKeybindRow(keyPage, "Hide GUI", KB.GuiHide)

    local spacer = Instance.new("Frame", keyPage)
    spacer.Size = UDim2.new(1, 0, 0, 16)
    spacer.BackgroundTransparency = 1
    spacer.LayoutOrder = getNextOrder(keyPage)
    spacer.ZIndex = 7

    pbFrame = Instance.new("Frame", gui)
    pbFrame.Size = UDim2.new(0, 260, 0, 64)
    pbFrame.Position = UDim2.new(0.5, -130, 1, -60)
    pbFrame.BackgroundColor3 = Color3.fromRGB(10,10,10)
    pbFrame.BackgroundTransparency = 0
    pbFrame.BorderSizePixel = 0
    pbFrame.Active = true
    pbFrame.Selectable = false
    pbFrame.ClipsDescendants = true
    pbFrame.Visible = CONFIG.AUTO_STEAL_ENABLED
    pbFrame.ZIndex = 10

    backgroundImagePB = Instance.new("ImageLabel", pbFrame)
    backgroundImagePB.Name = "BackgroundImagePB"
    backgroundImagePB.Size = UDim2.new(1, 0, 1, 0)
    backgroundImagePB.Position = UDim2.new(0, 0, 0, 0)
    backgroundImagePB.BackgroundTransparency = 1
    backgroundImagePB.BorderSizePixel = 0
    backgroundImagePB.Image = ""
    backgroundImagePB.ScaleType = Enum.ScaleType.Crop
    backgroundImagePB.ImageTransparency = 1
    backgroundImagePB.ZIndex = 1
    Instance.new("UICorner", backgroundImagePB).CornerRadius = UDim.new(0, 14)

    pbScale = Instance.new("UIScale", pbFrame)
    pbScale.Scale = progressBarScale

    if savedProgressBarPos then
        pbFrame.Position = UDim2.new(
            savedProgressBarPos.XScale or 0.5,
            savedProgressBarPos.XOffset or -130,
            savedProgressBarPos.YScale or 1,
            savedProgressBarPos.YOffset or -60
        )
    end

    local corner = Instance.new("UICorner", pbFrame)
    corner.CornerRadius = UDim.new(0, 14)

    fpsNeon = Instance.new("TextLabel", pbFrame)
    fpsNeon.Name = "FPSNeon"
    fpsNeon.Size = UDim2.new(1, -20, 0, 14)
    fpsNeon.Position = UDim2.new(0, 12, 0, 6)
    fpsNeon.BackgroundTransparency = 1
    fpsNeon.Text = "--FPS · --ms"
    fpsNeon.TextColor3 = Color3.fromRGB(210, 210, 220)
    fpsNeon.Font = SHOX_UI_FONT
    fpsNeon.TextSize = 11
    fpsNeon.TextXAlignment = Enum.TextXAlignment.Left
    fpsNeon.TextStrokeTransparency = 1
    fpsNeon.ZIndex = 13

    local progressRow = Instance.new("Frame", pbFrame)
    progressRow.Name = "ProgressRow"
    progressRow.Size = UDim2.new(1, -24, 0, 14)
    progressRow.Position = UDim2.new(0, 12, 0, 28)
    progressRow.BackgroundTransparency = 1
    progressRow.ZIndex = 11

    local fillRegion = Instance.new("Frame", progressRow)
    fillRegion.Name = "FillRegion"
    fillRegion.Size = UDim2.new(1, 0, 1, 0)
    fillRegion.BackgroundColor3 = Color3.fromRGB(20,20,25)
    fillRegion.BackgroundTransparency = 0.25
    fillRegion.BorderSizePixel = 0
    fillRegion.ClipsDescendants = true
    fillRegion.ZIndex = 12
    Instance.new("UICorner", fillRegion).CornerRadius = UDim.new(0, 7)

    progressFill = Instance.new("Frame", fillRegion)
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.Position = UDim2.new(0, 0, 0, 0)
    progressFill.BackgroundColor3 = Color3.fromRGB(210, 210, 220)
    progressFill.BorderSizePixel = 0
    progressFill.ZIndex = 13
    Instance.new("UICorner", progressFill).CornerRadius = UDim.new(0, 7)

    local fillGrad = Instance.new("UIGradient", progressFill)
    fillGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(150, 150, 160)),
        ColorSequenceKeypoint.new(0.50, Color3.fromRGB(210, 210, 220)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(230, 230, 235)),
    })
    fillGrad.Rotation = 0

    progressPct = Instance.new("TextLabel", fillRegion)
    progressPct.Size = UDim2.new(1, 0, 1, 0)
    progressPct.Position = UDim2.new(0, 0, 0, 0)
    progressPct.BackgroundTransparency = 1
    progressPct.Text = "0%"
    progressPct.TextColor3 = Color3.fromRGB(255,255,255)
    progressPct.Font = SHOX_UI_FONT
    progressPct.TextSize = 10
    progressPct.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    progressPct.TextStrokeTransparency = 0.3
    progressPct.ZIndex = 16

    drag(pbFrame)

    task.spawn(function()
        local lastFrame = _tick()
        local fpsSamples = {}
        local fpsAvg = 60
        local fpsConnection = RunService.RenderStepped:Connect(function()
            local now = _tick()
            local dt = now - lastFrame
            lastFrame = now
            if dt > 0 then
                table.insert(fpsSamples, math.clamp(1 / dt, 1, 240))
                if #fpsSamples > 30 then table.remove(fpsSamples, 1) end
                local removed = table.remove(fpsSamples, 1)
                    fpsSum = fpsSum - (removed or 0)
                    fpsAvg = fpsSum / #fpsSamples
            end
        end)
        while fpsNeon and fpsNeon.Parent and pbFrame and pbFrame.Parent do
            local ping = 0
            pcall(function() ping = LP:GetNetworkPing() * 1000 end)
            if fpsNeon and fpsNeon.Parent then
                fpsNeon.Text = string.format("%dFPS · %dms", _floor(fpsAvg + 0.5), _floor(ping + 0.5))
            end
            task.wait(0.75)
        end
        if fpsConnection then fpsConnection:Disconnect() end
    end)

    drag(main)
end

function createMobilePanel()
    local panel = Instance.new("ScreenGui")
    panel.Name = "FictionHubMobilePanel"
    panel.ResetOnSpawn = false
    panel.IgnoreGuiInset = true
    panel.DisplayOrder = -1 -- Keep Roblox TouchGui (especially JumpButton) above hub controls.
    panel.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    -- Keep this touch-control ScreenGui in PlayerGui so Roblox TouchGui can
    -- remain above it in the same display-order stack.
    local okPanel = pcall(function() panel.Parent = LP:WaitForChild("PlayerGui") end)
    if not okPanel then
        panel.Parent = game:GetService("CoreGui")
    end

    local BTN_W, BTN_H = 60, 60
    local GAP = 8
    local COLUMNS = 2
    local ROWS = 5
    local PANEL_W = BTN_W * COLUMNS + GAP * (COLUMNS - 1)
    local PANEL_H = BTN_H * ROWS + (GAP + 10) * (ROWS - 1)

    local container = Instance.new("Frame", panel)
    container.Name = "FloatingPanel"
    container.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
    container.AnchorPoint = Vector2.new(1, 0)
    local mpp = savedMobilePanelPos
    if type(mpp) == "table" then
        container.Position = UDim2.new(tonumber(mpp.XScale) or 1, tonumber(mpp.XOffset) or -8, tonumber(mpp.YScale) or 0, tonumber(mpp.YOffset) or 110)
    else
        container.Position = UDim2.new(1, -8, 0, 110)
    end
    container.BackgroundTransparency = 1
    container.BorderSizePixel = 0
    container.Active = false
    container.Selectable = false
    container.ClipsDescendants = false

    local containerScale = Instance.new("UIScale", container)
    containerScale.Scale = floatingButtonScale
    table.insert(_floatingUIScales, containerScale)

    local btnContainer = Instance.new("Frame", container)
    btnContainer.Name = "ButtonsContainer"
    btnContainer.Size = UDim2.new(1, 0, 1, 0)
    btnContainer.BackgroundTransparency = 1
    btnContainer.BorderSizePixel = 0
    btnContainer.Active = false
    btnContainer.Selectable = false
    btnContainer.ClipsDescendants = false

    local WHITE = Color3.fromRGB(255, 255, 255)
    local INACTIVE_BG = Color3.fromRGB(8,8,10)

    local buttons = {}
    local buttonNames = {"DropBR", "TPBat", "AutoLeft", "AutoBat", "AutoRight", "TpDown", "Carry", "Lagger1", "Lagger2"}
    local buttonTexts = {"DROP\nBR", "TP\nBAT", "AUTO\nLEFT", "BAT\nAIMBOT", "AUTO\nRIGHT", "TP\nDOWN", "CARRY\nSPD", "LAGGER\nNORMAL", "LAGGER\nCARRY"}

    local function createButton(name, text, order, isToggle, callback)
        local btn = Instance.new("TextButton", btnContainer)
        btn.Name = name
        btn.Size = UDim2.new(0, BTN_W, 0, BTN_H)
        btn.BackgroundColor3 = INACTIVE_BG
        btn.BorderSizePixel = 0
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.ZIndex = 10

        local defX, defY = getDefaultButtonPosition(name)
        local savedPos = savedButtonPositions and savedButtonPositions[name]
        if savedPos and type(savedPos.X) == "number" and type(savedPos.Y) == "number" then
            btn.Position = UDim2.fromOffset(savedPos.X, savedPos.Y)
        else
            btn.Position = UDim2.fromOffset(defX, defY)
        end

        btn.BackgroundColor3 = INACTIVE_BG
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

        local bgGrad = Instance.new("UIGradient", btn)
        bgGrad.Name = "BtnGrad"
        bgGrad.Rotation = 90
        bgGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(70, 70, 78)),
            ColorSequenceKeypoint.new(0.35, Color3.fromRGB(28, 28, 34)),
            ColorSequenceKeypoint.new(0.70, Color3.fromRGB(10, 10, 14)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(0, 0, 0)),
        })

        local stroke = Instance.new("UIStroke", btn)
        stroke.Color = Color3.fromRGB(70,70,78)
        stroke.Thickness = 1
        stroke.Transparency = 0.45
        stroke.Name = "NormalStroke"

        local label = Instance.new("TextLabel", btn)
        label.Name = "TextLabel"
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.Font = SHOX_UI_FONT
        label.TextSize = 10
        label.TextWrapped = true
        label.ZIndex = 11

        local active = false
        local function setActive(state)
            active = state
            btn:SetAttribute("MobActive", state and true or false)
            paintFloatingBtn(btn, state)
        end
        setActive(false)

        local dragging = false
        local hasMoved = false
        local suppressNextActivate = false
        local dragStart = nil
        local startPos = nil

        local function onInputBegan(input)
            if mobileButtonsLocked then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                hasMoved = false
                dragStart = input.Position
                startPos = btn.Position
                _isDraggingButton = true
            end
        end

        local function onInputChanged(input)
            if not dragging or mobileButtonsLocked then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                local delta = input.Position - dragStart
                if delta.Magnitude > 7 then hasMoved = true end
                if hasMoved then
                    local parentSize = btnContainer.AbsoluteSize
                    local maxX = math.max(0, parentSize.X - btn.AbsoluteSize.X)
                    local maxY = math.max(0, parentSize.Y - btn.AbsoluteSize.Y)
                    local x = math.clamp(startPos.X.Offset + delta.X, 0, maxX)
                    local y = math.clamp(startPos.Y.Offset + delta.Y, 0, maxY)
                    btn.Position = UDim2.fromOffset(x, y)
                end
            end
        end

        local function onInputEnded(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if dragging then
                    if hasMoved then
                        savedButtonPositions[name] = {X = btn.Position.X.Offset, Y = btn.Position.Y.Offset}
                        suppressNextActivate = true
                        task.delay(0.2, function() suppressNextActivate = false end)
                        pcall(saveAllSettings)
                    end
                    dragging = false
                    hasMoved = false
                    dragStart = nil
                    startPos = nil
                    _isDraggingButton = false
                end
            end
        end

        btn.Active = true
        btn.Selectable = true
        label.Active = false
        btn:SetAttribute("CanMove", not mobileButtonsLocked)
        btn.Activated:Connect(function()
            if suppressNextActivate then return end
            if callback then callback(setActive, active) end
        end)

        btn.InputBegan:Connect(onInputBegan)
        btn.InputChanged:Connect(onInputChanged)
        btn.InputEnded:Connect(onInputEnded)

        -- A finger may be released outside the button, so GuiObject.InputEnded alone is insufficient.
        local globalInputEnded = UIS.InputEnded:Connect(onInputEnded)
        local globalTouchEnded = UIS.TouchEnded:Connect(onInputEnded)
        btn.Destroying:Connect(function()
            if globalInputEnded then globalInputEnded:Disconnect(); globalInputEnded = nil end
            if globalTouchEnded then globalTouchEnded:Disconnect(); globalTouchEnded = nil end
            dragging = false
            _isDraggingButton = false
        end)

        buttons[name] = {btn = btn, setActive = setActive, label = label}
        return setActive
    end

    for i, name in ipairs(buttonNames) do
        local text = buttonTexts[i]
        local callback
        if name == "DropBR" then
            callback = function(setActive)
                if autoBatEnabled then return end
                setActive(true)
                executeDropWithToggle(function(v)
                    if dropBrainrotSetVisual then dropBrainrotSetVisual(v) end
                end)
                task.delay(0.3, function() setActive(false) end)
            end
        elseif name == "TPBat" then
            callback = function(setActive)
                toggleBatDesyncTp()
                setActive(batDesyncTpEnabled)
            end
        elseif name == "AutoLeft" then
            callback = function(setActive)
                autoLeftEnabled = not autoLeftEnabled
                setActive(autoLeftEnabled)
                if autoLeftEnabled then startAutoLeft() else stopAutoLeft() end
                if autoLeftSetVisual then autoLeftSetVisual(autoLeftEnabled) end
            end
        elseif name == "AutoBat" then
            callback = function(setActive)
                if not autoBatEnabled then enableAutoBat() else disableAutoBat() end
                setActive(autoBatEnabled)
            end
        elseif name == "AutoRight" then
            callback = function(setActive)
                autoRightEnabled = not autoRightEnabled
                setActive(autoRightEnabled)
                if autoRightEnabled then startAutoRight() else stopAutoRight() end
                if autoRightSetVisual then autoRightSetVisual(autoRightEnabled) end
            end
        elseif name == "TpDown" then
            callback = function(setActive)
                doTpDown()
                setActive(true)
                task.delay(0.2, function() setActive(false) end)
            end
        elseif name == "Carry" then
            callback = function(setActive)
                if not speedMode then
                    speedMode = true; laggerToggled = false; laggerCarryToggled = false; setActive(true)
                    if buttons.Lagger1 and buttons.Lagger1.setActive then buttons.Lagger1.setActive(false) end
                    if buttons.Lagger2 and buttons.Lagger2.setActive then buttons.Lagger2.setActive(false) end
                else
                    speedMode = false; setActive(false)
                end
                refreshSpeedModeLabel()
            end
        elseif name == "Lagger1" then
            callback = function(setActive)
                if speedMode then speedMode = false; if mobSetCarry then mobSetCarry(false) end end
                if not laggerToggled then
                    laggerToggled = true; laggerCarryToggled = false; setActive(true)
                    if buttons.Lagger2 and buttons.Lagger2.setActive then buttons.Lagger2.setActive(false) end
                else
                    laggerToggled = false; setActive(false)
                end
                refreshSpeedModeLabel()
            end
        elseif name == "Lagger2" then
            callback = function(setActive)
                if speedMode then speedMode = false; if mobSetCarry then mobSetCarry(false) end end
                if not laggerCarryToggled then
                    laggerCarryToggled = true; laggerToggled = false; setActive(true)
                    if buttons.Lagger1 and buttons.Lagger1.setActive then buttons.Lagger1.setActive(false) end
                else
                    laggerCarryToggled = false; setActive(false)
                end
                refreshSpeedModeLabel()
            end
        end
        mobSetAutoBat = buttons.AutoBat and buttons.AutoBat.setActive
        mobSetAutoLeft = buttons.AutoLeft and buttons.AutoLeft.setActive
        mobSetAutoRight = buttons.AutoRight and buttons.AutoRight.setActive
        mobSetDropBR = buttons.DropBR and buttons.DropBR.setActive
        mobSetTpDown = buttons.TpDown and buttons.TpDown.setActive
        mobSetCarry = buttons.Carry and buttons.Carry.setActive
        mobSetLagger1 = buttons.Lagger1 and buttons.Lagger1.setActive
        mobSetLagger2 = buttons.Lagger2 and buttons.Lagger2.setActive

        local setActive = createButton(name, text, i-1, true, callback)
        if name == "TPBat" then mobSetTpBat = setActive end
        if name == "AutoBat" then mobSetAutoBat = setActive end
        if name == "AutoLeft" then mobSetAutoLeft = setActive end
        if name == "AutoRight" then mobSetAutoRight = setActive end
        if name == "DropBR" then mobSetDropBR = setActive end
        if name == "TpDown" then mobSetTpDown = setActive end
        if name == "Carry" then mobSetCarry = setActive end
        if name == "Lagger1" then mobSetLagger1 = setActive end
        if name == "Lagger2" then mobSetLagger2 = setActive end
    end

    if buttons.TPBat and buttons.TPBat.setActive then buttons.TPBat.setActive(batDesyncTpEnabled) end
    if buttons.AutoBat and buttons.AutoBat.setActive then buttons.AutoBat.setActive(autoBatEnabled) end
    if buttons.AutoLeft and buttons.AutoLeft.setActive then buttons.AutoLeft.setActive(autoLeftEnabled) end
    if buttons.AutoRight and buttons.AutoRight.setActive then buttons.AutoRight.setActive(autoRightEnabled) end
    if buttons.Carry and buttons.Carry.setActive then buttons.Carry.setActive(speedMode) end
    if buttons.Lagger1 and buttons.Lagger1.setActive then buttons.Lagger1.setActive(laggerToggled) end
    if buttons.Lagger2 and buttons.Lagger2.setActive then buttons.Lagger2.setActive(laggerCarryToggled) end

    -- Preserve the restored/saved position; only use the default if no position exists.
    container.AnchorPoint = Vector2.new(1, 0)
    if not savedMobilePanelPos then
        container.Position = UDim2.new(1, -8, 0, 110)
    end
    container.Visible = true
    panel.Enabled = true

    local draggingPanel = false
    local dragStartPos = nil
    local dragStartMousePos = nil
    local function startDragPanel(input)
        if uiLocked or _isDraggingButton or editModeEnabled then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingPanel = true
            dragStartPos = container.Position
            dragStartMousePos = input.Position
        end
    end
    local function onDragPanel(input)
        if not draggingPanel or uiLocked then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if dragStartPos and dragStartMousePos then
                local delta = input.Position - dragStartMousePos
                local newX = dragStartPos.X.Offset + delta.X
                local newY = dragStartPos.Y.Offset + delta.Y
                container.Position = UDim2.new(dragStartPos.X.Scale, newX, dragStartPos.Y.Scale, newY)
            end
        end
    end
    local function endDragPanel()
        if draggingPanel then
            draggingPanel = false
            savedMobilePanelPos = {
                XScale = container.Position.X.Scale,
                XOffset = container.Position.X.Offset,
                YScale = container.Position.Y.Scale,
                YOffset = container.Position.Y.Offset
            }
            pcall(saveAllSettings)
        end
        dragStartPos = nil
        dragStartMousePos = nil
    end
    -- The panel itself stays anchored; individual buttons are movable when Lock Buttons is off.

    _G.AmbitiousApplyMobileButtonsHidden()
    return panel
end

function createBatV2FloatingButton()
    local panel = Instance.new("ScreenGui")
    panel.Name = "BatV2Button"
    panel.ResetOnSpawn = false
    panel.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    panel.DisplayOrder = 2000003
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(panel) end end)
    local okPanel = pcall(function() panel.Parent = game:GetService("CoreGui") end)
    if not okPanel then panel.Parent = LP:WaitForChild("PlayerGui") end

    local btnFrame = Instance.new("Frame", panel)
    btnFrame.Size = UDim2.new(0, 60, 0, 60)
    btnFrame.Name = "Frame"
    if batV2FloatingPos then
        btnFrame.Position = UDim2.new(batV2FloatingPos.XScale or 0.5,
                                      batV2FloatingPos.XOffset or -50,
                                      batV2FloatingPos.YScale or 0,
                                      batV2FloatingPos.YOffset or 10)
    else
        btnFrame.Position = UDim2.new(0.5, -50, 0, 10)
    end
    btnFrame.BackgroundColor3 = Color3.fromRGB(8,8,10)
    btnFrame.BackgroundTransparency = 0
    btnFrame.BorderSizePixel = 0
    btnFrame.ZIndex = 20
    Instance.new("UICorner", btnFrame).CornerRadius = UDim.new(0, 10)

    local bgGrad = Instance.new("UIGradient", btnFrame)
    bgGrad.Name = "BtnGrad"
    bgGrad.Rotation = 90
    bgGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(70, 70, 78)),
        ColorSequenceKeypoint.new(0.35, Color3.fromRGB(28, 28, 34)),
        ColorSequenceKeypoint.new(0.70, Color3.fromRGB(10, 10, 14)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(0, 0, 0)),
    })

    local stroke = Instance.new("UIStroke", btnFrame)
    stroke.Color = Color3.fromRGB(70,70,78)
    stroke.Thickness = 1
    stroke.Transparency = 0.45
    local label = Instance.new("TextLabel", btnFrame)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "BAT\nBYPASS"
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = SHOX_UI_FONT
    label.TextSize = 10
    label.TextWrapped = true
    label.ZIndex = 21

    local uiScale = Instance.new("UIScale", btnFrame)
    uiScale.Scale = floatingButtonScale
    table.insert(_floatingUIScales, uiScale)

    local function setActive(state)
        paintFloatingBtn(btnFrame, state)
    end

    local dragging = false; local hasMoved = false; local dragStart, startPos
    btnFrame.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true; hasMoved = false; dragStart = inp.Position; startPos = btnFrame.Position
        end
    end)
    btnFrame.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
            local delta = inp.Position - dragStart
            if delta.Magnitude > 5 then hasMoved = true end
            if hasMoved and not uiLocked then
                btnFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                              startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end
    end)
    btnFrame.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                if not hasMoved then
                    setActive(not autoBatV2Enabled)
                    toggleBatV2()
                elseif not uiLocked and hasMoved then
                    batV2FloatingPos = {
                        XScale = btnFrame.Position.X.Scale,
                        XOffset = btnFrame.Position.X.Offset,
                        YScale = btnFrame.Position.Y.Scale,
                        YOffset = btnFrame.Position.Y.Offset
                    }
                    pcall(saveAllSettings)
                end
                dragging = false; hasMoved = false
            end
        end
    end)

    batV2FloatingButton = panel
    return panel
end

function createInstaResetFloatingButton()
    local panel = Instance.new("ScreenGui")
    panel.Name = "InstaResetButton"
    panel.ResetOnSpawn = false
    panel.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    panel.DisplayOrder = 2000004
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(panel) end end)
    local okPanel = pcall(function() panel.Parent = game:GetService("CoreGui") end)
    if not okPanel then panel.Parent = LP:WaitForChild("PlayerGui") end

    local btnFrame = Instance.new("Frame", panel)
    btnFrame.Size = UDim2.new(0, 60, 0, 60)
    btnFrame.Name = "Frame"
    if instaResetFloatingPos then
        btnFrame.Position = UDim2.new(instaResetFloatingPos.XScale or 0.5,
                                      instaResetFloatingPos.XOffset or 90,
                                      instaResetFloatingPos.YScale or 0,
                                      instaResetFloatingPos.YOffset or 10)
    else
        btnFrame.Position = UDim2.new(0.5, 90, 0, 10)
    end
    btnFrame.BackgroundColor3 = Color3.fromRGB(8,8,10)
    btnFrame.BorderSizePixel  = 0
    btnFrame.ZIndex           = 20
    Instance.new("UICorner", btnFrame).CornerRadius = UDim.new(0, 10)

    local bgGrad = Instance.new("UIGradient", btnFrame)
    bgGrad.Name = "BtnGrad"
    bgGrad.Rotation = 90
    bgGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(70, 70, 78)),
        ColorSequenceKeypoint.new(0.35, Color3.fromRGB(28, 28, 34)),
        ColorSequenceKeypoint.new(0.70, Color3.fromRGB(10, 10, 14)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(0, 0, 0)),
    })

    local stroke = Instance.new("UIStroke", btnFrame)
    stroke.Color = Color3.fromRGB(70,70,78)
    stroke.Thickness = 1
    stroke.Transparency = 0.45

    local label = Instance.new("TextLabel", btnFrame)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "INSTA\nRESET"
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = SHOX_UI_FONT
    label.TextSize = 11
    label.TextWrapped = true
    label.ZIndex = 21

    local uiScale = Instance.new("UIScale", btnFrame)
    uiScale.Scale = floatingButtonScale
    table.insert(_floatingUIScales, uiScale)

    local dragging, hasMoved, dragStart, startPos, activeInput
    local RESET_TAP_THRESHOLD = 12

    local function pointInside(pos)
        local ap = btnFrame.AbsolutePosition
        local as = btnFrame.AbsoluteSize
        return pos.X >= ap.X and pos.X <= ap.X + as.X
           and pos.Y >= ap.Y and pos.Y <= ap.Y + as.Y
    end

    local function setActive(state)
        if state then
            TS:Create(btnFrame, TweenInfo.new(0.05), {BackgroundColor3 = Color3.fromRGB(255,255,255)}):Play()
            TS:Create(label,    TweenInfo.new(0.05), {TextColor3       = Color3.fromRGB(0,0,0)}):Play()
        else
            paintFloatingBtn(btnFrame, false)
        end
    end

    btnFrame.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            if activeInput then return end
            activeInput = inp
            dragging    = true
            hasMoved    = false
            dragStart   = inp.Position
            startPos    = btnFrame.Position
        end
    end)

    UIS.InputChanged:Connect(function(inp)
        if not dragging or not activeInput then return end
        local isTouchMove = activeInput.UserInputType == Enum.UserInputType.Touch and inp == activeInput
        local isMouseMove = activeInput.UserInputType == Enum.UserInputType.MouseButton1
                            and inp.UserInputType == Enum.UserInputType.MouseMovement
        if not isTouchMove and not isMouseMove then return end
        local delta = inp.Position - dragStart
        if delta.Magnitude > RESET_TAP_THRESHOLD then hasMoved = true end
        if hasMoved and not uiLocked then
            btnFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    UIS.InputEnded:Connect(function(inp)
        if inp ~= activeInput then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1
        and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        if dragging then
            local delta = inp.Position - dragStart
            local validTap = not hasMoved
                             and delta.Magnitude <= RESET_TAP_THRESHOLD
                             and pointInside(inp.Position)
            if validTap then
                print("[IR] tap → instaReset()")
                setActive(true)
                if _G.InstaReset and _G.InstaReset.Trigger then
                    _G.InstaReset.Trigger()
                end
                task.delay(0.2, function() setActive(false) end)
            elseif not uiLocked and hasMoved then
                instaResetFloatingPos = {
                    XScale  = btnFrame.Position.X.Scale,
                    XOffset = btnFrame.Position.X.Offset,
                    YScale  = btnFrame.Position.Y.Scale,
                    YOffset = btnFrame.Position.Y.Offset,
                }
                pcall(saveAllSettings)
            end
            dragging    = false
            hasMoved    = false
            activeInput = nil
        end
    end)

    instaResetFloatingButton = panel
    return panel
end


function updateUIFromLoaded()
    task.wait()
    if normalBox then normalBox.Text = tostring(NS) end
    if carryBox then carryBox.Text = tostring(CS) end
    if radInput then radInput.Text = tostring(CONFIG.STEAL_RANGE) end
    if laggerBox then laggerBox.Text = tostring(LAGGER_SPEED) end
    if lagger2Box then lagger2Box.Text = tostring(LAGGER_CARRY_SPEED) end
    if batSpeedBox then batSpeedBox.Text = tostring(BAT_AIMBOT_SPEED) end
    if uiScaleBox then uiScaleBox.Text = tostring(uiScaleValue) end
    if dropModeBtnRef then dropModeBtnRef.Text = dropMode == 1 and "Fling" or "Jump Drop" end
    if bodyLockRangeBox then bodyLockRangeBox.Text = tostring(bodyLockRange) end
    if carrySysNormalBox then carrySysNormalBox.Text = tostring(CarrySystem.normalSpeed) end
    if carrySysCarryBox then carrySysCarryBox.Text = tostring(CarrySystem.carrySpeed) end
    if carrySysLaggerBox then carrySysLaggerBox.Text = tostring(CarrySystem.laggerSpeed) end
    if carrySysLaggerCarryBox then carrySysLaggerCarryBox.Text = tostring(CarrySystem.laggerCarrySpeed) end
    if carrySysSoftStealSpeedBox then carrySysSoftStealSpeedBox.Text = tostring(CarrySystem.softStealSpeed) end
    if carrySysSoftStealRadiusBox then carrySysSoftStealRadiusBox.Text = tostring(CarrySystem.softStealRadius) end
    if carrySystemToggleSetter then carrySystemToggleSetter(useCarrySystem) end
    if autoStealVariantLabel then autoStealVariantLabel.Text = autoStealVariantName(autoStealVariant or 1) end
    refreshSpeedModeLabel()

    if infJumpSetVisual then infJumpSetVisual(infJumpEnabled) end
    if infJumpModeSetVisual then infJumpModeSetVisual.Text = infJumpMode end
    if mirrorTPDownSetVisual then mirrorTPDownSetVisual(mirrorTPDownEnabled) end
    if setSafeModeVisual then setSafeModeVisual(antiKickEnabled) end
    if setNoPlayerCollisionVisual then setNoPlayerCollisionVisual(noPlayerCollisionEnabled) end
    if setNoCamCollisionVisual then setNoCamCollisionVisual(noCamCollisionEnabled) end

    for _, ref in ipairs(keyButtonRefs) do
        local entry = ref.entry
        local label = (entry.gp and entry.gp.Name) or (entry.kb and entry.kb.Name) or "None"
        ref.btn.Text = label
    end

    if savedProgressBarPos and pbFrame then
        pbFrame.Position = UDim2.new(
            savedProgressBarPos.XScale or 0.5,
            savedProgressBarPos.XOffset or -130,
            savedProgressBarPos.YScale or 1,
            savedProgressBarPos.YOffset or -60
        )
    end

    applyFloatingButtonScale()

    if uiLocked and setLockUIVisual then setLockUIVisual(true) end
    if editModeEnabled and setEditModeVisual then setEditModeVisual(true) end

    if _G.updateAntiRagdollUI then _G.updateAntiRagdollUI(antiRagdollMode) end
    if antiRagdollMode == "v1" then
        AntiRagdollV1.start()
    elseif antiRagdollMode == "v2" then
        startAntiRagdollV2()
    end

    if antiDieEnabled then
        if setAntiDieVisual then setAntiDieVisual(true) end
        AntiDieModule.start()
    else
        if setAntiDieVisual then setAntiDieVisual(false) end
    end

    if CONFIG.AUTO_STEAL_ENABLED and setInstaGrab then setInstaGrab(true); pcall(startAutoSteal) end

    if medusaCounterEnabled then
        if setMedusaVisual then setMedusaVisual(true) end
        if LP.Character then setupMedusaCounter(LP.Character) end
    else
        if setMedusaVisual then setMedusaVisual(false) end
        stopMedusaCounter()
    end

    if batCounterEnabled and setBatCounterVisual then
        setBatCounterVisual(true)
        startBatCounter()
    end
    if unwalkEnabled and setUnwalkVisual then
        setUnwalkVisual(true)
        task.spawn(function() task.wait(0.5); startUnwalk() end)
    end
    if antiLagEnabled then
        if setAntiLagVisual then setAntiLagVisual(true) end
        enableAntiLag()
    else
        if setAntiLagVisual then setAntiLagVisual(false) end
        disableAntiLag()
    end
    if espEnabled then
        toggleESP(true)
        if setESPVIsual then setESPVIsual(true) end
    else
        toggleESP(false)
        if setESPVIsual then setESPVIsual(false) end
    end

    if batDesyncTpEnabled then
        if batDesyncTpSetVisual then batDesyncTpSetVisual(true) end
        if mobSetTpBat then mobSetTpBat(true) end
        if not _G.AlvaroTP.on then startBatDesyncTp() end
        updateTpBatButtonVisual(true)
    else
        if batDesyncTpSetVisual then batDesyncTpSetVisual(false) end
        if mobSetTpBat then mobSetTpBat(false) end
        updateTpBatButtonVisual(false)
    end

    if autoBatV2Enabled then
        if autoBatV2SetVisual then autoBatV2SetVisual(true) end
        if batV2FloatingButton then
            local btnFrame = batV2FloatingButton:FindFirstChild("Frame")
            if btnFrame then paintFloatingBtn(btnFrame, true) end
        end
    else
        if autoBatV2SetVisual then autoBatV2SetVisual(false) end
        if batV2FloatingButton then
            local btnFrame = batV2FloatingButton:FindFirstChild("Frame")
            if btnFrame then paintFloatingBtn(btnFrame, false) end
        end
    end

    if neonWeatherEnabled then
        applyNeonWeather()
        if setNeonWeatherVisual then setNeonWeatherVisual(true) end
    else
        restoreLightingState()
        if setNeonWeatherVisual then setNeonWeatherVisual(false) end
    end

    if stretchEnabled then
        enableStretch()
        if _G.stretchToggleSetter then _G.stretchToggleSetter(true) end
    else
        if _G.stretchToggleSetter then _G.stretchToggleSetter(false) end
    end

    if setFovVisual then setFovVisual(fovEnabled) end
    if fovSliderSet then fovSliderSet(fovValue) end

    if mobSetAutoBat then mobSetAutoBat(autoBatEnabled) end
    if mobSetAutoLeft then mobSetAutoLeft(autoLeftEnabled) end
    if mobSetAutoRight then mobSetAutoRight(autoRightEnabled) end
    if mobSetCarry then mobSetCarry(speedMode) end
    if mobSetLagger1 then mobSetLagger1(laggerToggled) end
    if mobSetLagger2 then mobSetLagger2(laggerCarryToggled) end

    if bodyLockEnabled and bodyLockSetVisual then
        if _blSuppressCount == 0 then
            bodyLockSetVisual(true)
            startBodyLock()
        else
            bodyLockSetVisual(false)
        end
    end

    if MinecraftBatSetVisual then MinecraftBatSetVisual(minecraftBatSkinEnabled) end
    if MinecraftBatColorSelector then MinecraftBatColorSelector.Text = minecraftBatSkinColorMode end
    if minecraftBatSkinEnabled then
        MinecraftBatSkin.State.enabled = true
        pcall(MinecraftBatSkin.Apply)
    end

    updateProgressBarVisibility()
    startEnemySpeed()

    toggleLockUI(uiLocked)

    pcall(function() applyOutfitByIndex(currentOutfitIndex) end)
    if outfitSelectorLabel then
        outfitSelectorLabel.Text = OUTFITS[currentOutfitIndex].label
    end

    if backgroundImage then
        applyBackground(backgroundIndex)
    end
    if contentPages and contentPages["Visual"] then
        local vPage = contentPages["Visual"]
        for _, child in ipairs(vPage:GetChildren()) do
            if child:IsA("Frame") and child:FindFirstChild("BackgroundPreview") then
                local prevFrame = child.BackgroundPreview
                local previewImage = prevFrame:FindFirstChild("PreviewImage")
                local previewPlaceholder = prevFrame:FindFirstChild("PreviewPlaceholder")
                local cfg = BACKGROUND_IMAGES[backgroundIndex]
                if previewImage then
                    if cfg and cfg.id and cfg.id ~= "" then
                        previewImage.Image = cfg.id
                        if previewPlaceholder then previewPlaceholder.Visible = false end
                    else
                        previewImage.Image = ""
                        if previewPlaceholder then previewPlaceholder.Visible = true end
                    end
                end
                break
            end
        end
    end

    if MobilePanel then
        local container = MobilePanel:FindFirstChild("FloatingPanel")
        if container then
            container.AnchorPoint = Vector2.new(1, 0)
            local mpp = savedMobilePanelPos
            if type(mpp) == "table" then
                container.Position = UDim2.new(tonumber(mpp.XScale) or 1, tonumber(mpp.XOffset) or -8, tonumber(mpp.YScale) or 0, tonumber(mpp.YOffset) or 110)
            else
                container.Position = UDim2.new(1, -8, 0, 110)
            end
            container.Visible = true
            MobilePanel.Enabled = true
            local btnCont = container:FindFirstChild("ButtonsContainer")
            if btnCont then
                local keyByButton = {TpDown="tp", TPBat="tpBat", AutoBat="aimbot", AutoLeft="autoLeft", AutoRight="autoRight", DropBR="drop", Carry="carry", Lagger1="laggerNormal", Lagger2="laggerCarry"}
                for _, btn in ipairs(btnCont:GetChildren()) do
                    if btn:IsA("TextButton") then
                        local defX, defY = getDefaultButtonPosition(btn.Name)
                        local savedPos = savedButtonPositions and savedButtonPositions[btn.Name]
                        if type(savedPos) == "table" and type(savedPos.X) == "number" and type(savedPos.Y) == "number" then
                            btn.Position = UDim2.fromOffset(savedPos.X, savedPos.Y)
                        else
                            btn.Position = UDim2.fromOffset(defX, defY)
                        end
                        local hideKey = keyByButton[btn.Name] or btn.Name
                        btn.Visible = not (_G.AmbitiousHideMobileButtons == true and _G.AmbitiousMobileHideIncluded and _G.AmbitiousMobileHideIncluded(hideKey))
                    end
                end
            end
        end
    end


    if batV2FloatingButton and batV2FloatingPos then
        local bf = batV2FloatingButton:FindFirstChild("Frame")
        if bf then
            bf.Position = UDim2.new(
                batV2FloatingPos.XScale or 0.5,
                batV2FloatingPos.XOffset or -50,
                batV2FloatingPos.YScale or 0,
                batV2FloatingPos.YOffset or 10
            )
        end
    end

    if instaResetFloatingButton and instaResetFloatingPos then
        local bf = instaResetFloatingButton:FindFirstChild("Frame")
        if bf then
            bf.Position = UDim2.new(
                instaResetFloatingPos.XScale or 0.5,
                instaResetFloatingPos.XOffset or 90,
                instaResetFloatingPos.YScale or 0,
                instaResetFloatingPos.YOffset or 10
            )
        end
    end
end

-- Defaults were normalized in the CONFIG section above. Do not overwrite
-- values loaded or supplied earlier in this execution here.
ShoxHubAutoTPLastAt = 0
ShoxHubE01StartedAt = nil
ShoxHubE01Gui = nil

RunService.Heartbeat:Connect(function()
    if not ShoxHubAutoTPDown then return end
    if autoLeftEnabled == true or autoRightEnabled == true or dropActive == true then return end
    if ShoxHubIsCarrying() then return end
    local ShoxHubCharacter = LP.Character
    local ShoxHubRoot = ShoxHubCharacter and ShoxHubCharacter:FindFirstChild("HumanoidRootPart")
    local ShoxHubHumanoid = ShoxHubCharacter and ShoxHubCharacter:FindFirstChildOfClass("Humanoid")
    if ShoxHubRoot and ShoxHubHumanoid and ShoxHubHumanoid.FloorMaterial == Enum.Material.Air and os.clock() - ShoxHubAutoTPLastAt >= 0.35 then
        local hit = ShoxGetGroundHit(ShoxHubCharacter, ShoxHubRoot)
        local groundY = hit and hit.Position.Y or ShoxHubRoot.Position.Y
        local heightAboveGround = ShoxHubRoot.Position.Y - groundY
        if heightAboveGround >= ShoxHubAutoTPDownHeight then
            ShoxHubAutoTPLastAt = os.clock()
            doTpDown()
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if not ShoxHubShowE01Warning or not ShoxHubIsCarrying() then
        if ShoxHubE01Gui then ShoxHubE01Gui.Enabled = false end
        ShoxHubE01StartedAt = nil
        return
    end
    ShoxHubE01StartedAt = ShoxHubE01StartedAt or tick()
    local ShoxHubProgress = math.clamp((tick() - ShoxHubE01StartedAt) / 2.6, 0, 1)
    if ShoxHubE01Gui and not ShoxHubE01Gui.Parent then ShoxHubE01Gui = nil end
    if not ShoxHubE01Gui then
        ShoxHubE01Gui = Instance.new("ScreenGui")
        ShoxHubE01Gui.Name = "ShoxHubE01Warning"
        ShoxHubE01Gui.ResetOnSpawn = false
        ShoxHubE01Gui.IgnoreGuiInset = true
        ShoxHubE01Gui.DisplayOrder = 1000006
        ShoxHubE01Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        ShoxHubE01Gui.Parent = LP:WaitForChild("PlayerGui")
        local ShoxHubBar = Instance.new("Frame", ShoxHubE01Gui)
        ShoxHubBar.Name = "Bar"
        ShoxHubBar.AnchorPoint = Vector2.new(.5, 0)
        ShoxHubBar.Position = UDim2.new(.5, 0, 0, 18)
        ShoxHubBar.Size = UDim2.new(0, 300, 0, 36)
        ShoxHubBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        ShoxHubBar.BackgroundTransparency = .34
        ShoxHubBar.BorderSizePixel = 0
        ShoxHubBar.ClipsDescendants = true
        Instance.new("UICorner", ShoxHubBar).CornerRadius = UDim.new(1, 0)
        local ShoxHubTrack = Instance.new("Frame", ShoxHubBar)
        ShoxHubTrack.Name = "Track"
        ShoxHubTrack.Position = UDim2.new(0, 3, 0, 3)
        ShoxHubTrack.Size = UDim2.new(1, -6, 1, -6)
        ShoxHubTrack.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        ShoxHubTrack.BackgroundTransparency = .48
        ShoxHubTrack.BorderSizePixel = 0
        ShoxHubTrack.ClipsDescendants = true
        Instance.new("UICorner", ShoxHubTrack).CornerRadius = UDim.new(1, 0)
        local ShoxHubFill = Instance.new("Frame", ShoxHubTrack)
        ShoxHubFill.Name = "Fill"
        ShoxHubFill.Size = UDim2.new(0, 0, 1, 0)
        ShoxHubFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        ShoxHubFill.BackgroundTransparency = .48
        ShoxHubFill.BorderSizePixel = 0
        Instance.new("UICorner", ShoxHubFill).CornerRadius = UDim.new(1, 0)
        local ShoxHubLabel = Instance.new("TextLabel", ShoxHubBar)
        ShoxHubLabel.Name = "Label"
        ShoxHubLabel.Size = UDim2.new(1, -16, 1, 0)
        ShoxHubLabel.Position = UDim2.new(0, 8, 0, 0)
        ShoxHubLabel.BackgroundTransparency = 1
        ShoxHubLabel.Font = SHOX_UI_FONT
        ShoxHubLabel.TextSize = 14
        ShoxHubLabel.TextStrokeTransparency = .18
        ShoxHubLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        ShoxHubLabel.ZIndex = 2
    end
    local gui = ShoxHubE01Gui
    if not gui or not gui.Parent then
        ShoxHubE01Gui = nil
        ShoxHubE01StartedAt = nil
        return
    end
    local bar = gui:FindFirstChild("Bar")
    local label = bar and bar:FindFirstChild("Label")
    local track = bar and bar:FindFirstChild("Track")
    local fill = track and track:FindFirstChild("Fill")
    if not (bar and label and fill) then
        pcall(function() gui:Destroy() end)
        ShoxHubE01Gui = nil
        ShoxHubE01StartedAt = nil
        return
    end
    gui.Enabled = true
    local ShoxHubFinished = ShoxHubProgress >= 1
    label.Text = ShoxHubFinished and "STEAL" or "DONT STEAL"
    label.TextColor3 = ShoxHubFinished and Color3.fromRGB(245, 245, 245) or Color3.fromRGB(180, 180, 180)
    fill.Size = UDim2.new(ShoxHubProgress, 0, 1, 0)
end)

LP.CharacterAdded:Connect(function()
    if ShoxHubE01Gui then
        pcall(function() ShoxHubE01Gui:Destroy() end)
    end
    ShoxHubE01Gui = nil
    ShoxHubE01StartedAt = nil
end)

local _buildGuiOk, _buildGuiErr = pcall(buildGui)
if not _buildGuiOk then
    warn("[ShoxHub] buildGui failed: " .. tostring(_buildGuiErr))
end

-- Preserve loaded mobile-button visibility and per-button positions across launches.
local _mobilePanelOk, _mobilePanelResult = pcall(createMobilePanel)
if _mobilePanelOk then
    MobilePanel = _mobilePanelResult
else
    warn("[ShoxHub] createMobilePanel failed: " .. tostring(_mobilePanelResult))
end

-- Remove detached legacy floating buttons; their features remain available through the main UI/keybinds.
for _, legacyName in ipairs({"TpBatButton", "BatV2Button", "InstaResetButton"}) do
    for _, parent in ipairs({game:GetService("CoreGui"), LP:FindFirstChildOfClass("PlayerGui")}) do
        local oldGui = parent and parent:FindFirstChild(legacyName)
        if oldGui then oldGui:Destroy() end
    end
end
batV2FloatingButton = nil
instaResetFloatingButton = nil

-- ═══════════════════════════════════════════════════════════════════════════
-- LAST POSITION MARKER
-- ═══════════════════════════════════════════════════════════════════════════
local LastPosMarker = (function()
    local LPM_Players    = game:GetService("Players")
    local LPM_RunService = game:GetService("RunService")
    local LPM_Workspace  = game:GetService("Workspace")
    local LPM_LP         = LPM_Players.LocalPlayer

    local COLOR_MARKER           = Color3.fromRGB(180, 180, 190)
    local COLOR_MARKER_GLOW      = Color3.fromRGB(170, 170, 180)
    local COLOR_OUTLINE          = Color3.fromRGB(230, 230, 235)
    local COLOR_TEXT             = Color3.fromRGB(230, 230, 235)
    local COLOR_TEXT_STROKE      = Color3.fromRGB(30, 30, 35)
    local COLOR_HANDLE_ADORNMENT = Color3.fromRGB(200, 200, 210)

    local LPM_MIN_X, LPM_MAX_X = -536.2, -422
    local LPM_MIN_Y, LPM_MAX_Y = -10, 75
    local LPM_MIN_Z, LPM_MAX_Z = -71.8, 192.9

    local MARKER_GROUND_Y = -7
    local LOOKBACK        = 0.2
    local INTERVAL        = 1 / 60

    local state = {
        marker          = nil,
        markerLocked    = false,
        markerTarget    = nil,
        samples         = {},
        conn            = nil,
        playerRemovingConn = nil,
        acc             = 0,
    }

    state.playerRemovingConn = LPM_Players.PlayerRemoving:Connect(function(player)
        state.samples[player] = nil
        if state.markerTarget == player then
            state.markerTarget = nil
            state.markerLocked = false
        end
    end)

    local function finiteVector(v)
        return v ~= nil
            and v.X == v.X and v.Y == v.Y and v.Z == v.Z
            and math.abs(v.X) < 1e7
            and math.abs(v.Y) < 1e7
            and math.abs(v.Z) < 1e7
    end

    local function isInsideMap(pos)
        if not pos then return false end
        return pos.X >= LPM_MIN_X and pos.X <= LPM_MAX_X
           and pos.Y >= LPM_MIN_Y and pos.Y <= LPM_MAX_Y
           and pos.Z >= LPM_MIN_Z and pos.Z <= LPM_MAX_Z
    end

    local function getSnapshotBeforeExit(sample, now)
        if not sample or not sample.history or #sample.history == 0 then return nil end
        local cutoff  = now - LOOKBACK
        local picked  = nil
        for _, entry in ipairs(sample.history) do
            if entry.time <= cutoff then picked = entry else break end
        end
        return picked or sample.history[1]
    end

    local function clearLastTargetMarker()
        state.markerLocked = false
        local m = state.marker
        if not m then return end
        pcall(function()
            m.Transparency = 1
            local sph = m:FindFirstChild("AlwaysOnTopSphere")
            if sph then sph.Visible = false end
            local hl = m:FindFirstChild("LastPositionHighlight")
            if hl then hl.Enabled = false end
            local bb = m:FindFirstChild("LastPositionLabel")
            if bb then bb.Enabled = false end
        end)
    end

    local function updateLastTargetMarker(targetCFrame)
        if state.markerLocked then return end
        if not targetCFrame or not isInsideMap(targetCFrame.Position) then return end

        local groundCFrame = CFrame.new(
            targetCFrame.Position.X,
            MARKER_GROUND_Y,
            targetCFrame.Position.Z
        ) * targetCFrame.Rotation

        local marker = state.marker
        if not marker or not marker.Parent then
            marker = Instance.new("Part")
            marker.Name            = "ShoxHubLastPosition"
            marker.Shape           = Enum.PartType.Ball
            marker.Size            = Vector3.new(3, 3, 3)
            marker.Color           = COLOR_MARKER
            marker.Material        = Enum.Material.Neon
            marker.Anchored        = true
            marker.CanCollide      = false
            marker.CanTouch        = false
            marker.CanQuery        = false
            marker.CastShadow      = false
            marker.Parent          = LPM_Workspace

            local sphere = Instance.new("SphereHandleAdornment")
            sphere.Name        = "AlwaysOnTopSphere"
            sphere.Adornee     = marker
            sphere.Radius      = 1.55
            sphere.Color3      = COLOR_HANDLE_ADORNMENT
            sphere.Transparency= 0.05
            sphere.AlwaysOnTop = true
            sphere.Visible     = true
            sphere.ZIndex      = 10
            sphere.Parent      = marker

            local hl = Instance.new("Highlight")
            hl.Name                = "LastPositionHighlight"
            hl.Adornee             = marker
            hl.FillColor           = COLOR_MARKER
            hl.FillTransparency    = 0.15
            hl.OutlineColor        = COLOR_OUTLINE
            hl.OutlineTransparency = 0
            hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Enabled             = true
            hl.Parent              = marker

            local bb = Instance.new("BillboardGui")
            bb.Name        = "LastPositionLabel"
            bb.Size        = UDim2.new(0, 110, 0, 20)
            bb.StudsOffset = Vector3.new(0, 2.1, 0)
            bb.AlwaysOnTop = true
            bb.Adornee     = marker
            bb.Parent      = marker

            local label = Instance.new("TextLabel")
            label.Size                   = UDim2.fromScale(1, 1)
            label.BackgroundTransparency = 1
            label.Text                   = "ultima posicion"
            label.TextColor3             = COLOR_TEXT
            label.TextStrokeColor3       = COLOR_TEXT_STROKE
            label.TextStrokeTransparency = 0.25
            label.TextSize               = 11
            label.Font                   = SHOX_UI_FONT
            label.Parent                 = bb

            state.marker = marker
        end

        marker.Transparency = 0
        local sph = marker:FindFirstChild("AlwaysOnTopSphere"); if sph then sph.Visible = true end
        local hl  = marker:FindFirstChild("LastPositionHighlight"); if hl  then hl.Enabled = true end
        local bb  = marker:FindFirstChild("LastPositionLabel");     if bb  then bb.Enabled = true end
        marker.CFrame = groundCFrame
        state.markerLocked = true
    end

    local function targetAlive(player, myRoot)
        if not player or player.Parent ~= LPM_Players then return false end
        local character = player.Character
        if not character or not character.Parent then return false end
        local r = character:FindFirstChild("HumanoidRootPart")
        local h = character:FindFirstChildOfClass("Humanoid")
        if not r or not h or h.Health <= 0 or not finiteVector(r.Position) then return false end
        return isInsideMap(r.Position)
    end

    local function monitorLastTarget()
        local myChar = LPM_LP.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end

        local tracked = state.markerTarget
        if tracked and tracked.Parent == LPM_Players then
            local tChar = tracked.Character
            local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
            local tHum  = tChar and tChar:FindFirstChildOfClass("Humanoid")
            local sample = state.samples[tracked] or {}
            state.samples[tracked] = sample

            if tRoot and tHum and tHum.Health > 0 and finiteVector(tRoot.Position) then
                if isInsideMap(tRoot.Position) then
                    local now = tick()
                    if state.markerLocked then sample.history = {} end
                    sample.history = sample.history or {}
                    table.insert(sample.history, {
                        time         = now,
                        safePosition = tRoot.Position,
                        safeCFrame   = tRoot.CFrame,
                    })
                    while sample.history[1] and now - sample.history[1].time > (LOOKBACK + 0.25) do
                        table.remove(sample.history, 1)
                    end
                    sample.safePosition = tRoot.Position
                    sample.safeCFrame   = tRoot.CFrame
                    clearLastTargetMarker()
                else
                    local snap = getSnapshotBeforeExit(sample, tick())
                    updateLastTargetMarker((snap and snap.safeCFrame) or sample.safeCFrame)
                end
            end

            if (tHum and tHum.Health <= 0)
               or (not tRoot and not sample.safeCFrame) then
                state.markerTarget = nil
                clearLastTargetMarker()
            else
                return
            end
        end

        local closest, closestDist = nil, math.huge
        for _, p in ipairs(LPM_Players:GetPlayers()) do
            if p ~= LPM_LP and targetAlive(p, myRoot) then
                local targetCharacter = p.Character
                local r = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
                if r then
                local d = (r.Position - myRoot.Position).Magnitude
                if d < closestDist then closest, closestDist = p, d end
                end
            end
        end

        if closest then
            state.markerTarget = closest
            local closestCharacter = closest.Character
            local r = closestCharacter and closestCharacter:FindFirstChild("HumanoidRootPart")
            if not r then state.markerTarget = nil; return end
            state.samples[closest] = {
                safePosition = r.Position,
                safeCFrame   = r.CFrame,
                history      = { { time = tick(), safePosition = r.Position, safeCFrame = r.CFrame } },
            }
        end
    end

    local api = {}

    function api.GetMarkerCFrame()
        local m = state.marker
        if state.markerLocked and m and m.Parent and m.Transparency < 1 then
            local tracked = state.markerTarget
            local tRoot = tracked and tracked.Character and tracked.Character:FindFirstChild("HumanoidRootPart")
            if tRoot and isInsideMap(tRoot.Position) then
                clearLastTargetMarker()
                return nil
            end
            return m.CFrame
        end
        return nil
    end

    function api.ForceMarker(player, fallbackCFrame)
        if player and player.Parent == LPM_Players then state.markerTarget = player end
        local sample = player and state.samples[player]
        local snap   = getSnapshotBeforeExit(sample, tick())
        local remembered = (snap and snap.safeCFrame) or (sample and sample.safeCFrame)
        if not remembered and fallbackCFrame and isInsideMap(fallbackCFrame.Position) then
            remembered = fallbackCFrame
        end
        if remembered then updateLastTargetMarker(remembered) end
        return api.GetMarkerCFrame()
    end

    function api.SetTarget(player)
        if player and player ~= LPM_LP and player.Parent == LPM_Players then
            state.markerTarget = player
        end
    end

    function api.Clear()
        state.markerTarget = nil
        clearLastTargetMarker()
    end

    function api.Destroy()
        api.Stop()
        if state.playerRemovingConn then
            state.playerRemovingConn:Disconnect()
            state.playerRemovingConn = nil
        end
        table.clear(state.samples)
        if state.marker and state.marker.Parent then
            pcall(function() state.marker:Destroy() end)
        end
        state.marker = nil
    end

    function api.Start()
        if state.conn then return state.conn end
        state.conn = LPM_RunService.Heartbeat:Connect(function(dt)
            state.acc = state.acc + (dt or 0)
            if state.acc < INTERVAL then return end
            state.acc = state.acc % INTERVAL
            monitorLastTarget()
        end)
        return state.conn
    end

    function api.Stop()
        if state.conn then
            state.conn:Disconnect()
            state.conn = nil
        end
    end

    api.IsInsideMap = isInsideMap
    return api
end)()

_G.ShoxHubLastPosMarker = LastPosMarker
LastPosMarker.Start()

if loadAllSettings() then
    updateUIFromLoaded()
end

if useCarrySystem then
    CarrySystem:start()
    CarrySystem.speedToggled = speedMode
    if laggerCarryToggled then
        CarrySystem:setLaggerMode(2)
    elseif laggerToggled then
        CarrySystem:setLaggerMode(1)
    else
        CarrySystem:setLaggerMode(0)
    end
    CarrySystem:setSoftStealEnabled(true)
end

if LP.Character then
    task.wait(0.1)
    if waitForCharReady(LP.Character, 5) then
        setupMovementAndIndicators(LP.Character)
        if currentAnimPack ~= "Off" then
            startAnimPack(currentAnimPack)
        end
        pcall(function() applyOutfitByIndex(currentOutfitIndex) end)
        if katanaSkinEnabled then
            task.wait(0.6)
            pcall(function() KatanaSkin.ApplySkin("KATANA") end)
        end
        if minecraftBatSkinEnabled then
            task.wait(0.6)
            pcall(function() MinecraftBatSkin.Apply() end)
        end
    end
end

local _respawnQueue = 0
LP.CharacterAdded:Connect(function(char)
    local ok, err = xpcall(function()
        _respawnQueue = _respawnQueue + 1
        local myId = _respawnQueue

        if stealConnection then stealConnection:Disconnect(); stealConnection = nil end
        isStealing = false
        stopAutoLeft()
        stopAutoRight()
        stopBatCounter()
            stopMedusaCounter()
        if not _tpBatUnwalkForced then stopUnwalk() end
        stopDropBrainrot()
        if autoBatEnabled then disableAutoBat() end
        if batDesyncTpEnabled then stopBatDesyncTp() end
        if autoBatV2Enabled then disableBatV2() end
        if bodyLockEnabled then stopBodyLock() end

        local deadline = _tick() + 5
        while (not char.Parent) or (not char:FindFirstChild("HumanoidRootPart"))
              or (not char:FindFirstChildOfClass("Humanoid")) do
            if _tick() > deadline then return end
            if myId ~= _respawnQueue then return end
            task.wait(0.05)
        end

        -- Velocity metatable hooks were intentionally removed; no respawn hook setup is needed.
        setupMovementAndIndicators(char)

        if antiRagdollMode == "v1" then AntiRagdollV1.start()
        elseif antiRagdollMode == "v2" then startAntiRagdollV2() end

        if AntiDieModule.enabled then task.defer(function() activateOnCharacter(char) end) end
        if CONFIG.AUTO_STEAL_ENABLED then pcall(startAutoSteal) end
        if batDesyncTpEnabled then task.defer(startBatDesyncTp) end
        if autoBatV2Enabled then task.defer(enableBatV2) end
        if bodyLockEnabled and _blSuppressCount == 0 then startBodyLock() end

        if medusaCounterEnabled then
            setupMedusaCounter(char)
            if setMedusaVisual then setMedusaVisual(true) end
        else
            stopMedusaCounter()
            if setMedusaVisual then setMedusaVisual(false) end
        end

        if batCounterEnabled then startBatCounter() end
        if unwalkEnabled and not _tpBatUnwalkForced then startUnwalk() end

        if currentAnimPack ~= "Off" then
            task.wait(0.3)
            startAnimPack(currentAnimPack)
        end

        updateProgressBarVisibility()
        refreshSpeedModeLabel()

        pcall(function() applyOutfitByIndex(currentOutfitIndex) end)
        if outfitSelectorLabel then
            outfitSelectorLabel.Text = OUTFITS[currentOutfitIndex].label
        end

        if katanaSkinEnabled then
            task.wait(1)
            pcall(function() KatanaSkin.ApplySkin("KATANA") end)
        end
        if minecraftBatSkinEnabled then
            task.wait(0.6)
            pcall(function() MinecraftBatSkin.Apply() end)
        end
    end, function(message)
        return tostring(message)
    end)
    if not ok then
        warn("[ShoxHub] CharacterAdded setup failed: " .. tostring(err))
    end
end)

local lastLaggerToggle = 0
local LAGGER_COOLDOWN = 0.3

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        task.delay(0.3, function() _isDraggingButton = false end)
    end
end)

UIS.InputBegan:Connect(function(input, gpe)
    if _anyKeyListening then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        if gpe or UIS:GetFocusedTextBox() then return end
    elseif not isGamepadInput(input) then
        return
    end
    if not isBindableInput(input) then return end

    local kc = input.KeyCode
    if not kc then return end

    if kbMatch(KB.LaggerMode, kc) then
        if _tick() - lastLaggerToggle >= LAGGER_COOLDOWN then
            lastLaggerToggle = _tick()
            toggleLaggerCycle()
        end
        return
    end
    if kbMatch(KB.CarryToggle, kc) then toggleCarryMode(); return end
    if kbMatch(KB.DropBrainrot, kc) then
        if not dropActive then
            if dropBrainrotSetVisual then dropBrainrotSetVisual(true) end
            executeDropWithToggle(dropBrainrotSetVisual)
        end
        return
    end
    if kbMatch(KB.TPFloor, kc) then doTpDown(); return end
    if kbMatch(KB.InstaReset, kc) then
        if _G.InstaReset and _G.InstaReset.Trigger then
            _G.InstaReset.Trigger()
        end
        return
    end
    if kbMatch(KB.AutoLeft, kc) then
        autoLeftEnabled = not autoLeftEnabled
        if autoLeftEnabled then startAutoLeft() else stopAutoLeft() end
        if autoLeftSetVisual then autoLeftSetVisual(autoLeftEnabled) end
        if mobSetAutoLeft then mobSetAutoLeft(autoLeftEnabled) end
        return
    end
    if kbMatch(KB.AutoRight, kc) then
        autoRightEnabled = not autoRightEnabled
        if autoRightEnabled then startAutoRight() else stopAutoRight() end
        if autoRightSetVisual then autoRightSetVisual(autoRightEnabled) end
        if mobSetAutoRight then mobSetAutoRight(autoRightEnabled) end
        return
    end
    if kbMatch(KB.AutoBat, kc) then
        if not autoBatEnabled then
            enableAutoBat()
            if autoBatSetVisual then autoBatSetVisual(true) end
            if mobSetAutoBat then mobSetAutoBat(true) end
        else
            disableAutoBat()
            if autoBatSetVisual then autoBatSetVisual(false) end
            if mobSetAutoBat then mobSetAutoBat(false) end
        end
        return
    end
    if kbMatch(KB.TPBat, kc) then
        toggleBatDesyncTp()
        if batDesyncTpSetVisual then batDesyncTpSetVisual(batDesyncTpEnabled) end
        return
    end
    if kbMatch(KB.BatV2, kc) then
        toggleBatV2()
        if autoBatV2SetVisual then autoBatV2SetVisual(autoBatV2Enabled) end
        if batV2FloatingButton then
            local btnFrame = batV2FloatingButton:FindFirstChild("Frame")
            if btnFrame then paintFloatingBtn(btnFrame, autoBatV2Enabled) end
        end
        return
    end
    if kbMatch(KB.GuiHide, kc) then
        if main then
            if main.Visible then hideGui() else showGui() end
        end
        return
    end

end)


-- ═══════════════════════════════════════════════════════════════
-- ShoxHub v1.6.0 — Global Destroy (Architecture Master)
-- ═══════════════════════════════════════════════════════════════
_G.ShoxHubDestroy = function() ShoxHubState:Destroy() end
print("[ShoxHub v1.7.0] Loaded. Ultimate Bugfix Active. Version: " .. tostring(ShoxHubState.Version))
