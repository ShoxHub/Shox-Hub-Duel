_G.ShoxHub = _G.ShoxHub or {}
local ShoxHubState = _G.ShoxHub
if ShoxHubState.Running or _G.BloodHoundsRunning then
    warn("[ShoxHub] Eine Instanz läuft bereits. Bitte zuerst die bestehende Instanz beenden, bevor du erneut ausführst.")
    return
end
ShoxHubState.Running = true
ShoxHubState.Version     = "v1.9.11"
ShoxHubState.Connections = ShoxHubState.Connections or {}
ShoxHubState.Timers      = ShoxHubState.Timers      or {}

function ShoxHubState:Track(conn)
    if conn then
        table.insert(self.Connections, conn)
        -- v1.7.1: tote Verbindungen regelmäßig entfernen (kein Speicherwachstum)
        if #self.Connections > 150 then
            local alive = {}
            for _, c in ipairs(self.Connections) do
                local okc, con = pcall(function() return c.Connected end)
                if not okc or con then alive[#alive + 1] = c end
            end
            self.Connections = alive
        end
    end
    return conn
end

function ShoxHubState:Destroy()
    self.Running = false
    pcall(function() if ShoxSpinSet then ShoxSpinSet(false) end end)
    _G.InstaResetLoaded = nil -- v1.9.4: sonst bleibt nach Neustart die tote Insta-Reset-Instanz aktiv
    _G.InstaReset = nil
    _G.BloodHoundsRunning = false
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
    print("[ShoxHub " .. tostring(self.Version) .. "] Destroyed — Instanz freigegeben.")
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
local SHOX_UI_FONT = Enum.Font.GothamBlack  -- v1.9.2: zurueck auf GothamBlack (wie Mobile-Buttons)

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
-- v1.7.1: Proxy, damit ALLE Heartbeat/RenderStepped/Stepped-Verbindungen automatisch getrackt
-- und bei ShoxHubState:Destroy() getrennt werden (vorher nur 1 von ~34).
do
    local realRS = RunService
    local function wrapSignal(sig)
        return setmetatable({}, {__index = function(_, k)
            if k == "Connect" or k == "connect" then
                return function(_, fn) return ShoxHubState:Track(sig:Connect(fn)) end
            end
            local v = sig[k]
            if type(v) == "function" then return function(_, ...) return v(sig, ...) end end
            return v
        end})
    end
    local wrapped = {
        Heartbeat = wrapSignal(realRS.Heartbeat),
        RenderStepped = wrapSignal(realRS.RenderStepped),
        Stepped = wrapSignal(realRS.Stepped),
    }
    RunService = setmetatable({}, {__index = function(_, k)
        if wrapped[k] then return wrapped[k] end
        local v = realRS[k]
        if type(v) == "function" then return function(_, ...) return v(realRS, ...) end end
        return v
    end})
end
local UIS
do -- v1.9.4: UIS-Proxy, damit InputBegan/Ended/Changed bei Destroy getrennt werden
    local realUIS = game:GetService("UserInputService")
    local sigs = {}
    for _, n in ipairs({"InputBegan", "InputEnded", "InputChanged"}) do
        local sig = realUIS[n]
        sigs[n] = setmetatable({}, {__index = function(_, k)
            if k == "Connect" or k == "connect" then
                return function(_, fn) return ShoxHubState:Track(sig:Connect(fn)) end
            end
            local v = sig[k]
            if type(v) == "function" then return function(_, ...) return v(sig, ...) end end
            return v
        end})
    end
    UIS = setmetatable({}, {
        __index = function(_, k)
            if sigs[k] then return sigs[k] end
            local v = realUIS[k]
            if type(v) == "function" then return function(_, ...) return v(realUIS, ...) end end
            return v
        end,
        __newindex = function(_, k, v) realUIS[k] = v end,
    })
end
local TS = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local HS = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LP = Players.LocalPlayer
local camera = workspace.CurrentCamera
-- v1.8.0: CharacterAdded-Handler ueber den Connection-Manager (werden bei Destroy getrennt)
function ShoxCharAdded(fn) return ShoxHubState:Track(LP.CharacterAdded:Connect(fn)) end

-- v1.6.0: Warn-Throttling gegen Log-Spam aus Loops.
local _shoxWarnLast = {}
local function shoxWarn(key, msg, interval)
    interval = interval or 5
    local now = os.clock()
    if _shoxWarnLast[key] and now - _shoxWarnLast[key] < interval then return end
    _shoxWarnLast[key] = now
    warn("[ShoxHub][" .. tostring(key) .. "] " .. tostring(msg))
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
BAT_AIMBOT_SPEED = 60
MOBILE_PANEL_WIDTH = 128
MOBILE_PANEL_HEIGHT = 294
CONFIG_FILE = "FictionHub.json"
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
    -- v1.8.0: eine gemeinsame Erkennung (ShoxIsCarrying): reagiert sofort auf Attribut-Events und auf die Steal-Ausloesung
    local v = (ShoxIsCarrying and ShoxIsCarrying()) or false
    self._isCarrying = v
    return v
end

function CarrySystem:getActiveSpeed()
    if autoLeftEnabled == true or autoRightEnabled == true then
        return self.normalSpeed
    end
    -- v1.8.0: Lagger-Modi haben Vorrang (vorher hat Auto Carry den gewaehlten Lagger-Speed ueberschrieben)
    if self.laggerMode == 1 then return self.laggerSpeed end
    if self.laggerMode == 2 then return self.laggerCarrySpeed end
    if self.softStealEnabled then
        -- v1.9.10: Carry zuerst pruefen (sofort, ohne Animal-Scan), Reichweite danach
        local carrying = self:isCarrying()
        local dist = nil
        if not carrying then
            local _, d = self:getNearestSoftStealAnimal(self.softStealRadius)
            dist = d
        end
        -- Soft-Steal-Speed: in Reichweite eines Brainrots ODER sobald du eins traegst (egal wie weit weg)
        if carrying or (dist and dist <= self.softStealRadius) then
            self.softStealLatched = true
            return self.softStealSpeed
        end
        self.softStealLatched = false
    end
    if self.speedToggled then return self.carrySpeed end
    return self.normalSpeed
end

function CarrySystem:getStatus()
    if autoLeftEnabled == true or autoRightEnabled == true then
        return "NORMAL", self.normalSpeed
    end
    if self.laggerMode == 1 then return "LAGGER", self.laggerSpeed end
    if self.laggerMode == 2 then return "LAGGER CARRY", self.laggerCarrySpeed end
    if self.softStealEnabled then
        if self:isCarrying() then return "AUTO CARRY", self.softStealSpeed end
        local _, dist = self:getNearestSoftStealAnimal(self.softStealRadius)
        if dist and dist <= self.softStealRadius then
            return "AUTO CARRY", self.softStealSpeed
        end
    end
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
end

function CarrySystem:scanSoftStealAnimals()
    self._softStealAnimals = {}
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return end
    for _, plot in ipairs(plots:GetChildren()) do
        if plot:IsA("Model") then
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
        if now - (self._lastSoftStealScan or 0) >= 0.6 then
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

    -- v1.6.0 SH-06/07 Fix: Global Movement Lock
    if tick() < _globalMovementLock then
        local lv = self._lvBoost
        if lv then pcall(function() lv.PlaneVelocity = Vector2.zero; lv.Enabled = false end) end
        return
    end

    -- Only one system may write movement physics at a time.
    -- Auto Left/Right and the combat controllers own velocity while active.
    local externallyControlled =
        autoLeftEnabled == true or autoRightEnabled == true
        or autoBatEnabled == true
        or batDesyncTpEnabled == true or dropActive == true
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

    -- v1.7.1: CanCollide-Änderung gecacht/gedrosselt und nach der Wand wiederhergestellt
    if blocked then
        local ncNow = _tick()
        if ncNow - (self._ncTime or 0) > 0.25 then
            self._ncTime = ncNow
            self._ncSet = self._ncSet or setmetatable({}, {__mode = "k"})
            local ncSet = self._ncSet
            local function ncModel(model)
                for _, part in ipairs(model:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        ncSet[part] = true
                        part.CanCollide = false
                    end
                end
            end
            for _, model in ipairs(char:GetChildren()) do
                if model:IsA("Model") then ncModel(model) end
            end
            for _, name in ipairs({"Carrying","IsCarrying","Grabbed","Holding","StealHold","HasGrab"}) do
                local v = char:FindFirstChild(name)
                if v and v:IsA("ObjectValue") and v.Value and v.Value:IsA("Model") then ncModel(v.Value) end
            end
        end
        self._unblockedAt = nil
    elseif self._ncSet then
        self._unblockedAt = self._unblockedAt or _tick()
        if _tick() - self._unblockedAt > 0.6 then
            for part in pairs(self._ncSet) do
                if part.Parent then pcall(function() part.CanCollide = true end) end
            end
            self._ncSet = nil
            self._unblockedAt = nil
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

-- v1.9.10: alte BG-Asset-IDs entfernt. Nur noch deine 8 Bilder (eingebettet) + Off.
ShoxBgData = {
[==[
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
]==],
[==[
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
]==],
[==[
/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAA0JCgsKCA0LCgsODg0PEyAVExISEyccHhcgLikxMC4pLSwzOko+MzZGNywtQFdBRkxOUlNSMj5aYVpQYEpRUk//
2wBDAQ4ODhMREyYVFSZPNS01T09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0//wAARCAK0AUADASIAAhEBAxEB/8QA
GwAAAgMBAQEAAAAAAAAAAAAAAgMAAQQFBgf/xABDEAACAQIEAgcGBAQGAgMAAgMBAgADEQQSITFBUQUTImFxgZEyQlKhscEUI9HhM2Jy8AZDU4KS8RUkNGOi
JURzg5P/xAAVAQEBAAAAAAAAAAAAAAAAAAAAAf/EABQRAQAAAAAAAAAAAAAAAAAAAAD/2gAMAwEAAhEDEQA/APm4NSmbjzvxhM1OrcsCG5jf9/rBzPTG4dfW
EOqqbdluRgKekVGZSGTmPvyi5pKMhuCVbnwMFlVjZgKb8/dP6QESxoRLZWU2YWMGBtxgtjag5gH5RH+aPCaOkCBjb8DTU/8A5Eyk/mgwCqex5yJqGl1PYMGl
xgasMM2HseZHqJgnQwp7Lj4QD6azHXXJWdeRNoC5JJIEkkkgSSSSBJJJIHZ6GsmErOfeYDyAm3HMaHQtCmdGrk1X89vlaY+jkNTCpQXeq4X1/aN/xFVDYlkX
2aa5R/flA4adqpfvvDrdqovlDyZVQ8l+sqwNZCduPlAS9yxlKSCCDYwwC1z5xcDv9E9VjqVTDVCq1SLjNse4930nPxGDqYPGWUMtRDfI2/kdiO+Y0d6bB0JV
hqGE6FbpNsVh1pYtQxX2XEBgrChjaVZb2sLgz06ODTVh2qbC4InjWOaj2WzZePdNWH6Yr4bCNQQ630Pw+EI71aklUEroZz8RRzApVHgYnCdMdYwXFEA8Kg09
ZvbEUWBDVKbDuYQOOQ+GazXamdjykxGHXFrnQgVefB/0P1nSqUVYdggg8DMD0HpMTS2O6HjA5LKVYqwIINiDwgzrVFpYsWqXSqNAx3HjzHznOr0KlBstQb7E
ag+BhSpckqBcqSXAMMre0LHmP0kK8eHMbRctWKnQwHXq0gDfMh8wZZZKi2BynkdoCVLG6nKTuOBjOrWp7HYqfAdj4QF3KDLUF14d3hAZbag3XnDJIurCxG4M
DVT9jA0445qtE86KfSZjo3hCqVDUK391Qo8oA1MB3tq45C8qgtw55CMwY6ysEPvKRG4agwp17jUaQKw5C1NdjoYnFjtq/wASj1GkJdzLrjNhweKn+/tAySSS
QJJJJAkkkkCSSQ6K56yLzYD5wPQ9B07YnMdqKs3naw+pnN6SfrK7fzPadzDJ+GoY1zwfJ6XJnAftYmmDw1MICqbPYd/6RQ/Muo3O3jLrHtAcSsSWsbiFdOkq
YfoyqzgF27OvOcwCahV/FU1ps4V1Ol9A/nzmnD9GPVazXUD2iRtAx36pKZqUldXW4J0PKXfCv7JqUjyIzLOt0tg0Xoqn1Q/gHXnY7/O08/AeFCG6ujDuNr+R
guACCduYgKjObKpPgJopYW3aqvlHJdT+ggII5EGRWym9ppailSrlw6ktvl3HrFFFJsQUbjfYQCp4yrTPYYgcuE20+kwwtWT0mE0LC61KTeD/AKwepca5fQwO
mXw1fUOAeFza0hVwhV1FamdwZzBYHtC/lCLspBol056wG1cGGucM1/5G0YfrMbKVYhgQRuDNQxdUaOEfxGsJsUlUWq0S3zt57wMUk0mnQb2XZe5hFmkODgwF
SQ2pkC6kMvMQIEhBtLHUfSDJA1K6VFy1jccH4jxg1VamArgMvA93jEAlTcTRSqgJZlLUjuOKnmICGWx01HAyKO0O+Nqo1NdGzU39lhxi6Zs632uIFIxRwwNr
GerfDXTMBowvPK1VyVXXkSJ7/DURU6PovbdFPygeJC2qOvwkiXQtU6ykd2GnjGY5fw/SOIUj3jM98lcMNjAzneVHYpbViw2ftDz/AHvEwJJJJAkkkkCRuFNs
VSPJ1+sVG4cXrp43geprsf8AxGbjWdn/AOTW+k4J1xLHlTJ9Z38auXAYVP5UHyJnDC/nVvBF9bQjHXH5zchpEneMqtes5/mMXuYVaLczXSxFakAEqtYcDrM9
MaGHA2f+QrMjU3YFWFiDfWJHVDUJSHiSYkC8sLmPcIQwVWbQZVXwvLaqq2sud+BfW3lBsdlFzDSkF1Y6wp3R4P4rO5uxVvpE0KtaliS9FiGueF7+UI1OrF1N
m4Tb0BVpfjWD0wztqp5QjbkpVqStisFRNQjWy2mergcC+1Bk/padyotF+QPI6TJVwy+6YHGPRuFB0eqPSC2Boj2arjynRqUCIh6bDhAx/hkXaqx8QJjqitTe
zEAcCBoZ0mUxTjS1rwOeWe249Ioux3M01qIPs3Xu4TMyMNxCt3WUKx/OpZG+OnoZHwhYXpNTrDkey0zAiECRqCRAB6aIbOlWme+xgZaZOjsf9v7zT11Qixa4
5HWS4qaFSt/hNoGYqq73lZzmBGgGwm5Oia1bWkyeDG0h6HxyAk0CVHFWBHrAzo2RbEZqT7r/AHxEQRY+G02UaLuXp5dQuceUzkC9jsflAbVovVFauqnKjAE2
01nqeh/8Q4EYSjg6wqJURApYrddBPPUar1Oi62GpoSS4qkgXsALTBTbKWI3tYecDqf4kATphmQgioisCONxOaCWFjwEfjSXw2CqMdeqK+jERSi9NLA5ySO4i
BdQdZhg3Gm1j4H9wfWZpqw3bqmkdqoy+fD52mYixsYFSSSQJJJLtAqOwv/yF8D9DExmHcU66ORcA6+ED2dZDX6PoVKS5yqJUCjjYWInBw9Ml2zG96qjyF/0n
Vp4l+jUWlVVnwzdqjUXgDrJU6RwVU5m6lm5vTF4R5NiSx7zHUcLiKp7FCq3eFM756To0v4Qw6/0oBEVemajf5hPgIGJejMXbWiVH8xAhf+Oqj23Qed5KnSVV
v3MQ2Mc+8IGgYVE3cHwErKqCy3mQ4ljuTBNbxgaWYDYgfOJYseJiutj6OGxdfWlh6jDnlsPWAu2u0oAhgykgjiNJrOBqJ/8AIxFCj3F8x9BAKYNN8RWqn+RQ
o+cCDH45LAYl3UcGN/rH/wDmKwXVAp85lNbDL7FC/e7k/SLbED3KajwEK6FPphz/ABAPGO/H02GpFuc4pe+ppiDcE6j5wO71i1BdLHwN4tvCchCysGRrEcQY
4Yuuo1qX8QDA1uBxiHUA6GCcXUFrhGB4iU9exs9Nb+MIpkC7kH5GV1Z93W8zio1rXuO+EKlhbKNeUKZcg6wg0SCvP1mhKNN8uSrYngSNIDKWJekdAW8Zs6/H
Y1OqsOrPu5rCYKlGrRPtKw/l1l0q+JBApXF/hEDv0cJQ6H6NxOKxdVHxFWkaVJF2F9D4+M8qTfeauqetXJxeI6ogXzVQST3AC8y8dNoHV6IIpjE023qKiGx4
FxcTmKQ+bN435TZgi9JXqFCBbMCeNmB+0xmyVnG4uR84BsXqU0Qm+TsgcuP6x2ACVnNGoPdNufl3xTENUIGmYQrnD16VenoDZ17iNxAX2lq2B7anQjjaNxVB
6lU1qSEpU7YtwJ3HrebOlsGEZMXh/wCHVGcDlxMvo2pVqK1KiFJBzDMdAOOkDmU8NXqNlWk5PHS1o9MAL2qVRf4aYzH9J2GoU1H/ALVcv/Iug9JX4pKbCjha
IzHYAawM1HozYiiF76pufQROJrphzkoszEblQFUem87hSnhsG9TFV1651IBJ0XTgPvPONXopSVVQO497WxgJegShqqVtva+t4lVZjZQT4TQl3UvUJyX0UaXj
1fEEZcPQycggufXhA3YHG4lMEMNiMP1lNfZYmxA5cpmxPUsx0pJ/U4v8oDYbHOe0hB5Fsx+8R+Bqamqwp/1GBRWiP81PIGAy0Sf4voDDOGpLvi6fkCYP4e+z
m3MjeABSl/qGQUlY2VwfIxwpUqetRix5QvxZTSgip32uYFU+jq76sVpp8Tm0aKXRtD+LVqYhhwTQesyu9Sqb1GJ/qN4PZ2uSeQgbf/JClphMJRo/zFczepme
tjMXiP4tZ27idIvW9goHidZMj+86oO/SAORuLWkypxN4bU6SC7NUe/IWHqYp2QnsIVHebwDug2EMLVPs0WtztaMwdN1VqxzCmBsNMx/SDiqiuFVLdgdpviMC
BKgBLBABuS36Sfk27T0/JCf0jsc5w2AoYAHtfxq39RGg8h9ZzoDmWhwd/wDj+8Ahb9k+soKSL7DmYxFVHDVV7PI6XgDYozI4tpNNJRVy1HCkgBEQHe3E90RX
dHa6U+rXgN5eGqrTqEtsVIHcbQESSSQJJJJANKtRDdHZfAxoxdX3sr/1KDM8kB/4i+9Kn8x94VLEHrksiKMwvYfrM0saGB7Lpvo8Lh8PVTRKlNdeAYrY+v1E
8hUBuCd9jPerWXGf4aw1Qdr8vK3lpPFY5AtaoF2vmHnv84GYXI05R9Rs2G1Hstfwv+4iaT5Cbi4IIjKTjqmzC4YFT47j5iB08Bi1bB06OJOZKbHIbbXGoPcQ
Zjwf5GLqLnOUA9pddIro+uMPi6VRhdFcFh3To4sUR06OoYFKq6leZGsBRqPVfLRUrfiTdj5xlNK+HQsuSkTu7m58gJtp0Vpr2R4mJxNJqii3CEcysvWPmqVa
lQ82MS9MDVRtNNSmyntAiIchQeZ2hWugcO2DNFhlrU3LX+IcpswLVgCtCoHUjXLbOvKynT0nEr06tJh1ilSyhhfiOcqm5BuHII5QNuNfHGoy1vxCrwDXAmPJ
ZnuQdOE10+ksbTWy1iw75VbpCrVRlqU6VyLZsguPOAYTDYGldstbEkC3FU/UzG1WpUYkkm/GAG0OYXlFmbbaARKjc38IJc8ABKAPKGAD/lr/AMoCySdzCVrE
Ak27oeVf9P8A/Uq9MGxQ+sC2ZwLBrKeWgiyDxvGXpfAfWGjUb603PgIBU3NOiQrowcWYMPZlUXorTJairup3JO3hHCrhrFPw+Qke3Ua9vICBmwSBhmqOG5KB
+sBlXHirRNIKUBAvbWKoGlTrI7KzqmuUgAE9+u0rr6K/wsKD3uxMn4rEE2plafcigGAT4arXdqz9YzMblitgT4kwRSoUv4tZb8kGc+u0FqVZ+1XcjvqNb94B
6lNr1D6D9fpAetbMcuEoAH437Tep0EMU8PSvVxdU1X4U0Op8TwH924zI9d2XKLKvwqLCLGpgaalZsRd2RQFFgo0CjkP74wcNR6xi9QhKSasfsO+E4CUgvMXM
SlN3Rn91LXJgLkkkgSSSSBJJJIEkkkgen/wpjgadbo2qfau9K/PiPv5GI6VwJWi9YC5FXL5EX+04VGq9GslWkxV0IZSOBE9gK9LpfoLE1EAV7qaij3G127v1
geNtrCRrBgdjCqoVJvvxioBA2N5vwC58VRNtiT5Cc8bzpYTPQ/MCgkiwF9QIHcBEhVTOcuPS9mup5GPXEAjQwhtSiCJw61O3Sgp7DMNp2HxKohZjoJwcTiGq
4k1hZW4W4QrqdIYhK9BaVRB+XopvqJyerQtbMV8RKzs5JYgk8SZeUWteAQw99UrUz52lNSqqL9k+DQSptYcJXaG63gUS2xErORwHpCv/ACy7j+zAHOeQkzE+
6D5S9DykyjkIFlXABNKwOxy7y1SsxAWkSW2su8mZguW7gcgdIS16i2tUbQ3F+cAQWV8tQsljY2GohMUJ0rNb+Y/YSVqrYioajlcx3IFry6YolStVWB4Mn3H/
AFAoLTb/ADLnlaT8oA2VyRwNgYp0ynsnMOdpA/BhcfSAZZXFgoU95JgXekTYlSeUjAbg3HzEgc2sdR3wBJJNyZUIi4uPSDAkOmuZwIEfhf4h7rfUQGYki7eG
nrJU7GBCj32HoB+8vEJdHbitpOkBlFFRtlv8hAxySSQJJJJAkkkkCSSSQJO9/hLEin0g+FqH8vFIUIPPhOFaFRqPRrJVpmzowZT3iB0OksOcPjKlM8DOe621
E9H06FxeHw/SFIdmsoJ7jxHrOA4uphAJlANxvxMLO6bMbQV1W0q5GkKcK5Oja+MIOu6kqe4zNKgPeo7sFLE8JMNTWpXWmSO0wHleBTNiW5CP6P1xiG3sBm9F
JgXjcLToCgyObVaYfXheY8x5zf0kf/jofcoUx8r/AHmAQCDnneXm8YuaatDLSDgjQKSOOo3gKz959Jef+7QqNE1NSwRRux2EqpkFQikzOo4lbXgDnHFRJmQ+
7J5j0lekArpwJHnLuPi9YHC9pXlAZYH4TKy22uPAxYUnYE+AlnMu9xAPUcfUSiea38IIdhxhBxxHpAKpUFU3IUNzAtBy8x5iS6tx9ZLEbafOBGQqA4N1OxEE
gEXG/ERqVMp7S6HQ8jJUphCHQ3Q7HlARG0Gyv42HzkrUsgDjVTxEqgL1LHkfpA3MuZaq86YIicb2sPhX507ehImhSA1FzsRlMTXQ/gch3oVivkdR9IGGSSSB
JJJIEkkjsPTDEsxAC21O1ybD9fKAVKlTAz12buRdz4ngI1cStP8AhU6FPvK5z6m8RibLWempJVWIv8XfEwNjV3c3NdCfT7QSQf4qAjmJllgkbQPRdFMmI6Lx
OBzXyfm0wdwNiPoZxnGViDuDH9EVnw3SFGsykJmyvwup0MPpagcP0jUTgTA55FmJlNrGEXiypEARLMqEqlmA5wNdGiDQRToarb2vYAfrCwtFqFerTbV3plad
tcxYgC3rNeHo06mKTDu1iKXYF9SxPDvl06bri1pPUCMtyrc/DxgYulCBi6yg3CEIPIW+0w8DH4p87M/xuzRHu+MCp0cVSDU8PVJshpWY+BmBBdoypVZlWnmJ
VNoEqOahAAsi+yo/veOfB1qaXqLl42PCdLonovENkq06OeodVLeynee+aMVi8D0ax7S47GD/AP50z9zAw4PoZ6lL8RimFDDjd6htfwiukD0aFCYFarODrVJs
D5HX6TNjMficdV6zE1C54DYL4DhM1xygHcju+hlixPZ0PKBm7pe+0BgJU3XskTXSxdOqvV4lQw75hVyNGEIoDqptA04jo8gdZhznXlxEyU6YZ8jMF7yI6jia
uHbu5GamGHxoutkq/WBz3pZTbMDKAYbGaGo5XyVxlPxWvAcqtsqtl53+0BebWzCxlglNtVO44GO6oBcxAKW9oajwPIxTIyagXU+YMBlFlINJtUbbuMSVNOtl
PCWNtPSNLI6BnGo0J5QH0vzMIQN0NxCYdYrW/wA6nb/cuo+UVgHtUZDrcRtijlF3uHTxEDmSSSQJJNFHBYiuL06enNiAPnNH/hsaRotM9wqLA58fRINCqh3N
mHkf3h1uj8ZQF6uHqBedrj1EzLfN2d+6A1wahuxu/M8YsKxbKFJY8Lax9OmRY1Wyr46x5xiIuWiuUWtddCfFjr6WgIGEK265gh+Hdo9MPkF8gQfFUOX95nOK
qC/V2p3+Ea+u8SWLG7Ek98De1SigscRfupJ9zC6RxS4xKVUXzBArX3uNP0M5ygsdATHUl7FSmbXKkjxECA3EkXTbW0ZAE0wdtI3DJ+Zc8IIjsP7cIVjmP4g2
O06FPHJisIzVv/k0RcN8d9L+OuvrznPrrnqsbjc7+MZhqeVHNwb6ad2v6QrNX0KryEBtLDkITduse8wGN2J74BJorHutNOAw4q1S1S/VUxmcga2mcC1McyZ0
MK4o4mjhuB0qd5YW+hgM6S6er4mn+Gwo/D4YC2VTqw7zOPCdSjlTuDYwYEkkkgSSSSAwFW0fQ8DKs1MwqSEkHidpqSgrUszaLqEA948/AQMwZXFj6SFSpuhl
VKYRyoIJEpXI0OogaqeJzrkrjMOfESnpZRemc9M7iJsG1G8tHamd7fQwCCtTPWUHIHHmPES+sQ/xF6snivsnyl5gxDL2GHEQs6gdoFSdyBcHxH6QAajZMykM
OBXW0Uh1Nhe/CaECDVT50zf1UwKlNb5lI77Ai0ANaNRXB2IN+4zbUHWIGXcaiZa9Nwl21Ft/784eFq9kKTAwzpYDA5q9Fao1qOoA5AmF0TgQ6PjcQt6NI2VT
/mPy8BuZop42nh8fSxFZs+SoHKjc2N4G04ShQ6arYOup6tmKo19V5RGNw9fo9xeqGS9rk2ImPpXplsdjXxFOiKWY6a3InMqValVy9R2djxY3gdj/AMy1Efln
M3PhObXxdStVao2UM25VQIjUyoFkkm53lXhBXbYEw6uHqUQpcaMLgg3EBYUnuHfDApqLlsx5Wi7wkqugsrEA8OEAmctpoByjKJ7S2AuDc25cYvrM5saaEnkL
fSaEK0BoNfe1+UDKQVfwjb3l1FsoPwsVP2gDQleW0AxGUTaoJnD62MLPYXB2gWwDa5wO4m00KOqwZa9+R/vymMjMyDmBNmO/Lo0qWxtc/wB+kDGmmZuQ+sAD
jwjG0pKOLG/l/d5Si5VeZ1gaMLS6yui8EA9T/wBxLsy4lmJ7Qa/nNFOp1WG60aF6vyH/AHFY9QMUzDZ+0POBWPFsW7DZ7OPPWZ5pxHbw9CpxAKHy/wC5mgSS
SSBIdNczdwgTZQp5VzEa7Dx/vTzgMoUgxOc2UDM5HAch9JMXXKaABXIsAPcHAf3xjM4Smx9ymbk/E/6Cc12LuWbcwKvLXtG0Ohh6uIqBKKF2PKdJ+jcPgcgx
tRquIfUUKJ9kcyYHNYNTNmBEgqA6NNFW7oG1BvkYHXwmOxuRbaA2xXVT5SZwRY9k98AORt6QswI7QgUQCd7HnwjKLOKgR9VfTn6QNOBHnIDl2a3hA0qX6ooQ
SzGwF+P3mNSQdI5Gq1nUUzYg5sw0sed5eKpPRqq9ywcZgxG/OBdXG4itRp0C5WjTFkRdAP3iDpxuYZVCbip6iUKWZgOsSxO/KAsy1FyABqdpqqYMUwGGIouD
tqRM7LURs1iCDoRAeMBiDS610KU72139JofAKmCXEUiWIPbBnTpVRjMJmO9Vbnubj89fOK6NcHrKD7MNoHFq6dtCQrbjkYYxBCdW3aXkZdZepr1KTexe0zup
U2OvI84BVKYAzoboflFRtGr1b9pcyHRl5iONKnSfOjZwRdARt4wBpp1QufbO38sW730G31lu976+JgD4m25QHpd6Lod8oYeUS3aQNxjMOxNW5tc3AvzilazE
cDAGxOwkjE0JWWygjvga8FQFZqRYaAm57hvE4xzXxZtxNhNPR9RaeBxD+8BYeH/dpkpg9uod17I/qP8AZgBUAsWGw7K+EFTueQtDxFly0xwEXYhVHPWA+rc4
fDp/KW9TKqnrMMjcU0PhCr6dQP8A6l+8GnxU7NpApO1g6i/AwYfSZ5ow4tVam2zAqYLJT4MYCZIZUcDKCg+8B6wDw9M1KoAFzfTxmyo2Wy09bdlf1+plYKnk
pVK1wbCykczp+suhZsSXPs0wW9NBAXjOzlw6HRB2jzMVSodbkFPtsx2G8i56tRmFtTqTwjlK0rpTBZzobb+fIdwgbMPUfCHqcMq1cU5sMuqp+pnRZcP0Xgql
XGMKuMrKygbm5Gv/AH6TjYQYg1C1NyhG7A2AEfTp52zUiWLG3XMMzMeSDjAy5ib02ABKX9m1yOMz1BlfN36+BnUxOGp4WmwqvSpVj7jNnqse+2i+c5tbbxUQ
AydltLkespVVtrggXhFmyqwHgZaWLLVFhrZhAVbgGHrGUkWxzrqdjf8Au8q1Nb217zNFNA1EsfaY2WBavTpLbKDxCd/MymLVnDVgTnBsTtpwEa1OkMpr9mmo
0Ue1U7zyEHEVGqvTcjKtiEAFgByEDJb+Y+RBhAc7eYiCI2lTqE9kWvprA1Yakj4hadV8gI48PGBikGHqkUzmS+hHhGLSFNs1ZyGItb3j3W4RGKcl1AsMuyjh
+8A8PjKlE/lnTe37eU04XEKcSKlwLnUTm5x766wtDx9f1gbOk8prl1sQwmRdhTq6A6g8oxarAZagFReTb+RjBTpV8opn2SewdG8BAQtDIc1SxA2HxftBq1CS
ddTvCruwaxFiNLcogAsbCAQGY9wk9tgL2Et9AEXzjgfw3ZqUgysL35+ECNh1bWlWVrcDpM73LXO/Ga0pUXvWUkU11YHe/ATNU7Tk2AvrblAC5veOVgwiJY30
NoDUdsjU1uQzDQcYWIITLRUghPaI4tx/TygUS6uSh7QBsYZqU2wy08tmBJzc4At+YzMeO0KrY9SRsU+5iwCKeaNqfwMO3Isvzv8AeBWJNxQP/wBQ+pkHaEqr
/Bp390lfnf7wEa3jAcoPXKx0J38Ytyocg8Dymyl1dWlc1FWoouLm15hxDBqzMosCdoFFl5GTMOAg2l2Ubm/hA6aDL0XRPx1L+kWB1WEqFh7YUeRv+kdRH4jo
kLT9uk2a3dAr4pXSk1MgVAArKRy2PzhClpsFDVWNJCNFHtEdw4f3vHUKIqKTYUqI35nziqVKtXYsATrqzRuFpNiKrLUe1FNXJNhYQrTRpfiVuctLCUxftGwI
+Jjy+Z2Ez4vpYpmpdH3pqRlasRZ3HIfCvcPMmI6RxzYkijRBXDoeytrZj8R+w4CYspgXT7VVb847EcByUQKSHOL8dIRPW1SeBPygCSEJW+9riUWud/KbgMCj
FqhDE763jGxVFKYahSFiSLgAbQOelNnbKisW5Wm+itGhh82JZmOthTP3iqmJqKQi2RWUNcDU3mOo757VCSeZgaSwrVDkRUXjr9+Mbiw2amStgBYeUyIzIwZA
DbUTTVxlbGspqlbIMqhVAAEAfyKPsq9Q/wAq5R6nWA+IrWIpoKYPwjX1mo1f9MYYdzpY/OA9fGqLhFA5pTBHygZEFQXIuDxPGTqmPuOPAXjDj8T/AKzDwAEE
43FH/Pq+sAGpVBupPlF2dfdIj/xmL/1qvrJ+OxQ3rv5wApnMcug8dob0ypsykHv/AFl/jKp9sUn/AKkEL8RSbSphwP6HK/I6QK60OMmIU1ANAw0df1k6gU6T
1abCovBgNvEcJeTD1B2KzIeHWL9xJ1WIw560bfGhzKfGBMHhq1anUq0hdksAJoCLiKDBls1PV6fLvH6QaNYZg1I9TVBuMpsD4cvCblrDFVKRr4YCqr361ezc
AEkEQObjV6immHUAZdXtxb+9PKZFDO4UDMzGwHObukFysc57TojDzuT84zoigrPUqte9NSbn3dN/SBhehaoLnKhJFxrb9YJohffU+RF5tx3U1HRVuqdWpW24
uB6xQo1VsKNanVU7KdL+R+0BFNjTe4+cP8rIzdWxB5D7yj1LMVqI1FxobDT0mn8X/wCqtCo5YUtEIHCBz2Ys1z4W5RoN8O1M7q2YQKmQm6AiXTBLgDcj5wHI
FqIVb3luP6hEiixGbTLzlocrW4E3WaExVSinVL1b0jsHWBlKBffHzgkcSZqyK5/NQ078Va/yMpaCrqwJ/q0EDOtMubJc9/COWkiDM3aPy/eMLACw18tPSJqO
TxgDSr1aL5qbFSYyrUNY3qURmPvJpfymcbzTnvUUjQLa0Bd2XQNUAlajQlvAmdR3H4tXbVaKmoRzI2+dpyHZndnc3ZjcmAV/DzN5A52HyEAAk2AvHhRRF2sX
5coFMSq2v2iPQQggpYY1GGtTsoDy4mVSpmqS7kimurtz7h3mSv1lZ87AKLWVb7DlAzzTR1wr/wAtRT6xQpc2AjFKpTZbk5iDy2gPqIGoUCvt2IA+Kx28dYkh
XWzcOPKU9fNTWmVXKpJHPWV1rkki9zubQAVGquFXj8hNNIBFpA2BJJMzl3O7fODfm3oIHVFWm2zjwqLf5yiKQ1NK381JiJhDA8YQYjYkQjYDTf2cQfCqgb5j
WX1FQ+wQ3/8AirW+RmJjm335yAsPZc+cK0VKFdNWrV0/rDD5jSAPxY/hVGccxUzfKSnisRT9lj5GM/HK38eijHmV19YAjFVaYy4rCpVTm1MBh52hquBxOlMU
1Y+6zGkfXVfpGJiMOwsr1KfdmzD0P6y2pK4uDSfyyn9PnAzV8AaWoZ6d9utGh8GFwZnV62Ge4JS/FTofsZqrU7tY5lJ4E5b/AGmarSKfGl9wRcH0gEatOqPz
ECk+8gt6iWj1sO+em17AjnoRYxC2Vu1qv8p1munVpNSqIwZnXVGA3gBi8QmJpUCAc9NMrDwm6nVoUOicb1TXeqqjwv8AtOa6o3bQ2MtT2Ch8uUAqaLiMLfXr
KPLiv7TOco0BuPWWlR6FW6EgiXUq5nJWmovAC99r/STIx92F1j8LQS9Q7kjwgEKRJ7TAeMKonUlGBJ7V7kWidb3za+MhZj7RJ8TAdUXNUyKL8RaRHIBBO/EQ
GqZspGhAjXXNTSpcAvv3nvgX1pQdlQP5uMA1LnU3lMGptldWRu8Suy3AeUC83jLRQ57WnjBFO50MdTp1TopuO8aQE1qXVvp7J2myjkr4e1hnAt5yitJFtVrI
BxUdqCpoU1zpTqHgCeMCVGLJW5tSUf8A6F5lWiTq5yiac1WpfRaYtfs2ufOLFJybvYeLQCU0qY7FyeJg76pS8zrLJCbFR/Tb6mAz33sf6mvAsljozDwv+kAq
RtpLzc38lFpYamP8vMe8mAFhxe/cJCoHun/cbQ87HYZR3C0rL3fKAGY8LeQlWY738zG5fH1kyd4EBWTmwlhVvuT4COCX07TR6UKirmNNUX4qhtAz/hW92pTP
+6T8PiBst/BgZWTuEmX+X5wC6vEDeix8BLAqcabj/aYG3xCXmI99h5mAYDD3W9IQJ4oT5Wi8zf6j/wDIyF34VH/5QGZKbbqynvX9I1MKbXRyJiNWqP8AMb1k
FapxcmB0kwyggVaigE6kjMB32kQ0KKstSsGF9BzHhOXnZj2jfulDVoG18WlNv/WzgcRfT0MWcUH1qUkJ55bH1EzLoTzj1AdQYCy637JK/MQ0DEdlc1+Woguo
Q6b8gYSq6oKibbd4gP6ilUIQu1KoRoKgtr4zJVoVKTEMp0htWdtKjG3frGAqqhlrA62y63EDKLSwOTRtWmlyQbeEDq9QC65ecCzQqnLlGcngmtvSAEIcq11I
58J0MHSyUmqpjqNHhZjZvSZX6lGNqgc8wDAQoJO00Wz4ZKezBjBXElDdQB5CWa5fVm+cDRSq1cPSFJqq1Ke/VOmZfnt5TMwUsSEAvw4CUag8ZWZjsvrAu72t
oPCCwbvPiZZzblgBJlJF9SOZNhAFLK6moAVB1UG144sSLHblFhB4+G0u+UWY+cC7DkJMo5CUHU85DUUaG8C7DlLt3QetXgLwxnOoTTmTpAlpLGTPk9pl8lvB
OJf3ahHgsBopOdlPpCFI8WUeclDGolN1q0addmUqC99O+ZFcq4J4QN/4bLSFVs2QmwYLpfxMpChP5dIEDdnOgmevjKlZFpglaa7LfjzlNUZ1C7KOEBtTE1b5
aVSw5qoEQ7a3dizd5vBZwNF9YveBt7HGp8pf5X+ofSIklQ+1H/Ub0kth/jeIlwHZcLxzymXCkaGoIqSQEaWH4PU/4yuqofG//GVJCiyYf+cy7YYf5bn/AHQN
JLiAy+HAv+GY/wD+w/pFNVS9kpWHLNHopIFxYc4Yw+GQXZ2LH3RrAyGuwBCqq+G/rGJVGSwFxCqUaIJOaxtfKNbeJiEBA1EC2YX11EgFjdDb6SyARrAyldjC
HFQGAqJkb5GDWoEJ1ikFdo6hWVqfVV1DKNr8PPhFvemrJfMh9RCskKxMg9qxmilRpsTmqMCOCrf7wM1oaIpNrm/IC81VcEUPtgHkYF2p3WnVa3G2l4CyjKdB
lH82krKOJue6EQDvrJoIEAO+g79zISBqx175WYn2ZWUbsYFGoT7IkCe9UbKPUmRj8MtaZY3cnw4wIXHs0EyjnuxlpR+LU8hLLrTFgPIRZqsdtIGgKF+FfmZG
ZNyGeIFQ8QDDV1PGx74EeoHsuQAcwYuqoRso84ymM1UsfZXWJclnJ5wLNMimrnZiQPKCb3sd43ISBfSw0kUXsSLk6Ac4FKthdpHNhY+kfUUYf+LY1vg4J49/
dMhNzcwKkklwNEmkAAjVj5QiuWnnKaHQXgTTnLuJFyiiLgEklieQGwiCxJgPFzspPlLy1DtTb/iYFOpUsSaj2Gg7RhUyzlnJPwrr/fD6wCFKqRcUnPlK6ttb
5Bb4nAkqOtNjk32J7uUWlN6p0GnMwDCEkKDTJOwDRhwtYbhB/ujqSU8MmdjrzMqriMq5mGp2WAtqNfqwwGYAWIBuR32ihfe48o3C40rUIrgvTY623XvE04yg
EAqHtowutVNyOZ5/WBhlRr0nREci9N/YcbN+/dFwipJcqUS3EGxkLEA3AJ5iSXIpRANjtzEvrCp024iNRAzBW2MXXotQq2YabjvEA87OMzbmVLuLAAASpUQg
nY2ksOOskuQUdBtBILC20YoLHSU9RU0SxbnwEKJKYUXJsOfGNyUios5HeDaIUdkEkktrCVipva99ri5hDSB/rFv6lDfaLZVH+Sr+ClZf4ptlSC+Jqi1wBfaF
URh/foVk8G/UQan4fJ+UKubm5H2guGYB3ZjfYmFRUKOsYaDYczAtx1dMUh7Tat+kErk31J4CEboSTrUO/d+8pVZmsts1tb7AQLRalR1popao5sqjiZrZkwC5
aLK+JOjVRqE7k5n+b05xSFaNIuozNUuqE8ebW+QHjLwVFK2MRKvbudRfS0DHlJ1JsOZlXQeyL95/SHinFTE1GWwXMcoGwHCJgbEtiKZCU1FRRsq7iZ2UG2Ub
yUKr0KyVaZsyG4misVeqaiWswuIA01UN+YSWI7JtcX+8e1cdeUyhltZh8QtrGnDkYP8AENhXRSew97Bz3c5gsRULHRbXgVUsgKq17nfu4RMNgzAueJtKQZnC
8zAN+yip3XPnGMerpheIHzP9/KB/ExAvtf5SViWPjqYCw1jcgHxjhiXC+yBE3C7C5l20ub3gOpMWqddVNwusVUdqrl23Mt9EVRx7R+3998oC/Gw4mAPd9J1O
i8Qqg4PFsBRqHsFvcbn4HjOaamXSmLd/GBA72HQ4PFVMBibDD4g27QuEfgftMFegadZ6QUh0Nmpncd45j5zfh3HSvRbU6hviMOtieLJwPlt6RONDYvAJjLkY
jDEUqxG5+FoHP32kjEP4i9gBW4jg/wCh+sDeBUkkkIsHWaGZcRh8je2m0zyag3gAtwLHcaS5bCz35yQJLVSzWAkAJIA3Mj1Agy03F/eNoA1ammVPZ4nnEQxq
faHnCamV7W1+I1BhTKDqVytsLmUt1rZHOt94pGKOD7PI8o6uQ6rUFgy7gfIwIRY35MR9xH06Yd1pVSxpim7AA21Ckg/SLpENWysbBwNTwPCDWqF8tJCDkuMw
5QFUwzDKWsg1PdGs1gCBa2iDl3+MFbAaewD/AMjLVWqMdQLC7MdlECkQsSBYWFyx2URtNBVJRSVop2qj8T49/IQdajLRoDQnQHj3n+9INSsEZKVE3po1ybe2
3P8ASBWIrZ3JQWFracBwA7powR6mjXr7ZEsvidBMjHNVew0N4/Ft1WGp4ce0fzH+w9PrAxSSSQJGUjraCFJFzoOZjFUDmPqf0gbafSeL6qnh6hNXD0vZosbL
521ImXFVnxVdnyqL6kItgPAcoVZ+sqZKNyOZtf5TTRorTpEcSNTA5p3tCpaOW+EEwfelrojnutAOiLdo72MGobva8Ynsgdw+8MYdXNhiKN+97faBmHd6yzpx
mjEYSvQVXqICjey6kFT5jSZTAaq537gLnwAgZr7r6GPwtQUmYkAhlGh5XBP0gnEOrFXSm4BtZkH13gJsp2JHjIVIF9xzEeGw1TdXonmO0vodR85TYeoimpTI
dB7yG4HjxHnAvo/FtgsZTrrqFNmX4lO49J3qiU8P0mBmBwmNTITwsdVPrPN3U+0LHmJ3MMDjegHok3qYU9kjip1HobwOTXothsQ9Jx2kYqYxWOIvxrrv/wDY
Ofj9fHfX0r/7NLD44b16dn/rXQzlFiCHUkEcRwgP3FxtKjGYVafXqANbVVHA8/A/XygGBJdryhCEIhU5AbHeDN+HUPRAPAj6zLTos+JFFdy+X5wAPYpXJsW0
vyEQSimwUm01Y/KGoKAL5Mxt3k2+Vph31hR3LXtwkV2XUbcbSU2KXYcIZGRwyey2q/pAolXGwvK1A01H0jsVTQ5K1JcqVBew2Ujcf3ziVGbjoN2gWdRy4eMK
wAyg97NKbUgAW5QlUsQiW53O3eTAtVNRrCyqo1J2US3cECnSU5b9kcWPM98qo4CinTvlB83PMxi0zTQ7Gq2hIYDIOXjAIPRw9FqZzPVfSoQBYD4QfrM5pKoz
gmx2BGo8YYGXYovnmMdTo5l62qxSkD7Z3J5KOcAKFNEU16o/Lp8D7x4CZKtRqtRqjm7MbmNxVc1mCquSmmiINbd/eYtKZOp2gAASbARq07C51hgBRoPUSakw
BC63Y3MKWBDVOMA6FMIO+aR7B8JmWotrk2j2NqDnuMI5R3Mq/ZI5ySoVoJsgP8szx6jMoFr3EE0TyYeIgClV0BCnQ7jgZorYcNhVxVEXQnK4+FpnNMibujK9
KgMRRxRJoV6RU5Rcqw1U+v1gYlJ0HEbS2AqC4PaEFVa+nzjDTIsyst+V9oCSCDYy0d6bBkYqw4g2jsmYWYL5MIJoH3SPUQC62nV/jKEb40H1H6TodBE0Ok0p
MQaeJU07g6G+3zAnLNCp8N/AxmHqVcPVVwpsrBrEcRA6hp/+ljsKd8PVFZfA6H7TjsLMRPRVwv8A52sg9nE0SPVSR9J56rowPdAvD1OqckjMpFmXmOMcyZGK
XzAaqeY4GZU1a3MGPD3pLfdNvA/v9YFwhKPMSxCNmA7RenxO0gR8NjHBZRULZQxOgJFyfKX0ev5txva5jOmqRAFe+77c7r+0K5WKqiriKtRPY0VP6RoPkIiW
dEA56ygCYBD+GT3wkP5ZU7XuDyMgHZy2vreFl5wBtc2vpyhHQa7DhLtaA+pCiBFJOtr30A5xrnql6pdWJ7ZHE8vAfWMw1JzRqYimjMVYUqYAvd2v87A/KNr4
Op0bWyVsv4kAZ1OvVkjQeNoCsNQZ3CoQazMEHcTBFO61GBUimbGx+k6mCw1TA9E1+k2stSoCuGU8dgz+ABt4mctXVRUCA5agGnw90AOtA9hLnmZTNVqNdnzW
0udhIFAHOXvAqw8fpL3kkuBxtAu3OGlMsbKCYVJMwzWNuZ0HrGDFUaA0cseSfrA0UOj2NjUIHjpBxdPDU3H57kj3VAAHnMNbH1alwlkU8t/WZSSTcm8B1JS1
UA8OEZUrMrVEGqtp4QAxVw43G/eIDG7E84FGmRTz30vAHGNJ/Jy98UNDA04ZOselT+JwvrOy/QHSFO+XD1rdymcGi7K3ZJB3UjmNROwf8X/4iVjbpbEHxIP2
gU/R2NTRqNQeKxf4LEn/ACCf9s1J/jb/ABAv8TGJVHKpRRvtLqf4txGIQricFhTcWzUgaTfI2+UDG2CrL7eHVf6gBK/DWUs1KmFHEVB+stsf0XUW1To0q3xL
UJPziHfoxvYXEJ6GA16dBNKgVfGpAC4Ie8B4NM7nCk6VKx8V/eKPU8C/oIHTWlRYZkJYdzX/AFhdVgh2jiqlNhzCn5Tkh1U3UG/O8YuJrkhVquL6asTA7OIf
/wDmsFrchaYJ56TiV/b9frNrYjP0j1+bRDofAWEwObvrwgVS/iL4wrewOawAQrAw6mhA5KBAOmbp3iGNIumR1jAbGGTA6vR6immaxN9bcSeUX03VzpSbKyix
UqeDA6ysFjaVOtSzhsiamw420mnFp+PrV8Ja1YqlWiDxbKLr5/aEcBmTgp075Yswvp4RbAgkEEEbgy09oWhTVhQTCFzAkSCS5IGs0lBTGapf+kbn9IdOjRq0
s1LMtYDVCdDruPlAXRr1qNM06bkKTm0NtYTVS1RnIuWIJzdq5gsjrsmb+nWQJUI1Rh/tgMxWLxGMdXxNVqhRcq32UcgNgIk95jEpM/sq7eAjRhmVkBpqpfVc
xuTAzC59lSfAQ+qYC9RlQd5kqVXXNZjYG1gLTM1RjyHhA0N1ajQk950EX1qJ7K5jzO3pEk3lQHGo9Q3LHMNoDgEZ124jkYI0jlOZS/k4+8BEkJlytb0gwNB+
cWdD3fSNgsL7QDanpTe11bQzMylWKncG000K+TsVNUvp3SY5B1gqpqr/AFgZ1+cJxcXgDnDBuLjeAuSEw4iDAkkkkCSSSwCdhAqGgsb8eEtUA1Yy7gt2YBXt
pwESe+GxAFhBsPGBBYsL7QmJY34sYKrmPIDczo4LDouExHSGIBCU1y0FI9tzoPIbwMNP+L6w2O8GkCGN+AjaSZ6g5CBtw+AdujquIqPkWmmZVtvM+JxJfFLW
DkMiqMw5gTbicV/6Qwo0AGaoe4bDzM5AykdvbeBtxD0ccwquVp1T7Rto/f3GDRw6U1OdEZuB6wTCzGo23gOUZTp62AuTA0slPN7SjuTtH9IL1EQZaQ14tufX
hLysnZRQX4ngIJpoovWfbWw/SAnVtvlrH4fB1ajgjs7kMxtsLwqVRLXCrTHxNqQJVXHdmoKerVFy5zuF428YDKFUvTaotUtkuXVkBNuB8OcB8VWFLrEZSL2N
kAyzFSqvRqLUpsVZdjNBenUJeiBTZhZ6Z9k+H6QCxlSoautRihAIF9LTp4YGt0bhXOrYZ3onuDdofQzmYpD1FBiLErY+U04DFvQUp1eaniAqsfhYHQwMtZbv
WHI3/v1mObXNsY5b2SbH0mWopSoVO4MAJJJIEhU3KMCNeY5iDJAfVSygjUWup5iImii2aiyHde0v3iWFmIgPklvlVrEi8qECy38YBZlUpfsngYyUbHQwpOxl
24qYZQjbUcjAItzBgWCDvoZCv/crQygSNjAvL3yWXnLzX3UGS45H1gTwWXZ+OkrMO+Vccj6wIR3yE6WEl/LylAQJ4yxrvoIS0i23oNYYCWFkZjzY2HpAPCLR
eqv4hwlFdWF9W9Js6T6TGNFKnTpinh6AsqAWBPhOfkAOpuJShV1Yi8AxcDX2mNzNVBcgsurWv3DvMxioAb8eEjViyZSbLyHHxgPZ0am5Z7kMCR8R/aZmLVG0
vb6QQAToD4CPVfK2/dAqnT4AXJmhTk7NMXY7t+kJaPZWxtcamMqFcNS7Nsx2hGeoxp9m935cFiNajWGoHzMjk7e828ur+Sgpj2z7Xd3QpdV7my7CLkkgSSSS
BrpHrMA68abZh4GHhHARltc5lI9QYnBH87qztVBT12+cFARWQbagH1gaMbZMU4O3CIq2qIHG40aMx758WwHA2gIMhvuDoRAzyRjpr2YuBJJJIB0mysT3SVNx
IBlGu5lO2YwHYpSHB7pnnQxDriMwcCnVvqOF+fnMBBBIO4gS55mVLCljYAkngBLKFXyuCLb6awICw2MPMbdpbiMpVKKp20u3OC1VCdBaAHYPdJ1fIgyFkPum
UMh4sIFFGHCVqI5abt7DEwupr/DfygJUr75byEaPw3vNW8gJOqq/B8pDTqDdQPKBD+HOiLVvzJEDIfd274eSoeIHpKNM8Xv4QKsQO0+nKUagG2sZTwxqEhQW
NucQwKsQRYjhAjOTxgy5ACTYCBUJULEAC5PCPXDFQGrXF9kG5nWwHRaIn4jHEUqQ1yk2uO/ugL6JwLIGxtVc1OkCVUe+eQ7ufdC6XpL+EoVghD1S1RteZNvp
85or9IvWy4eioBqHLSQC1lvpf6yunaqKtPD0/YQBfEAQOdTZs1l1YgAXmaprUZrlgDYE8Y1XKUWqH237K93OLVc7hF0A4nh3wiktTU1n1N+yDxP7TMxLMSTc
nUmMr1A72W4RdFH3ioVJJJIEkkhKpbwgXSbJVVx7pBmuqO11q5SGOdip2t9PCZRqcq6cO8x9LDVKjFFClx7hIDHwHPugIzZnLMdSbxgNxAUKrFXQseGtpM1M
bI4/3ftAZxvp5xTCNWnUbRb34jlAdMrEEg2gKv3CXZrXtpNC0WVQ7FaanYtufAbwHamdGqu/+394CQbEXF+6aFq0jvQQeAMWBSvoTfvELutA24uhZ8tbRhs4
2Yd8yfhyDuCOYM9R0lg7C9gytqCNQe8GcGtRyE5TbuMICkTSN1JB5wWw61KRdW/MvqDsRAJaUpYcYUVX8N1S9hkqLoQOMzEpwUnxMe3aFjFmmIC83IAeUsVX
AsG+UI0jwldS1uXjAsYh+OU+KiEMQeNOmfIiB1TW3HrKyd49YDRXTjS9Gl9bRPxr5AxFh3mWEY7IYDw1M7VB5i0jMq7keRvFZG42EsIPGAynjGosGpAXHOJI
eq5ZtSdzHrSVdWIX6xqsAbUkueZgJp4QkZqjZV75rw9LM2TC07n4yNo2jhC1nxL2HKdJuqwdHNXHVqBcUhox8eQ+f1gJo4anhFas1qtUbu/sqfue6c1sSMQ9
d61V3ZVzJ8JN7feJ6Q6RqYxso7FIaKg0AgUxkwyk/wCY1/Jf3+kDo9DUr4qpiW1FBbKebHQfc+UydJ1esxOQHbczpgfgOikVtHI6xv6iNB5D6zgMS7sb3JMA
gxax4DQQqrdXSyD2nGvcP3loFUFm9lN+/kJndi7lmNyTeAMkkkCSSQ0TMbnQDcwIq31O31jqVOpXfqqIF7XY3sFHHXgO+HSoPXbKllAFySdEXiSeUrEYhFpf
hsLcUb9piLNVPM93IfeBdStTwymnhDmbZq1rE9y8h8z8pkBIN+MqSBqqt+Jpdcf4q/xP5h8X6wDUQsHK2cDXkxi6VQ0qgYcNwdiOUc1JTUTKTkcix7r2t4iA
wYl6OHanYB6hu2mwtpNHQHR69K9INQqVxRC0nqZ22BUXHztMOMbPi6rc3NvDYQcPWehVFSmxB2NuI4iBMQlSnWdK1+sU2NzeKnaxZwOMoU8t0qhbZ9we4ici
rTak1mHnwMAIxScu8XCHswOj0f0vWwq9UTmpHdG2/abKr4bFrek+Rj7rThOpVrGElQroRdeRgbatNkNmEURIrh7dW9z8Lmx9djLOYHK6kHkRYwAlQ7Xg2hFS
S7SpRVgeEmUcpclpBALbCTXnLtLCwBsJevCGqg8QO8mGOrFspznu2gDToF2nQw9BUUP2QPjbRR4cz4TMlVRmF17IzW3+W3reJq4qpVcAEi5te9zbx/SBuq9J
08K4WgGapfWs/tD+ke79ZkxfWDpGrSqOzasov3jT7TBUOaox750MeSy4XGL/AJlNbn+ZdD9IVzQCTYakzsYbDCt0mtFhejhkGfvtuPNtJlwFJT0gXYfl0Qap
8BqPtOnS/wDR6MNWp/Gr/mNz12Hzv5wMnTWKNStkBvY695nPRbeMosalUsxvaMUimAze9p4DiYC6z3si+yvzMTDqIUcg8DAgSSSSBaqWYAbma8PRNaqtOnsO
O3iTEKMqXG5HoJprv+Fw/wCGQ2quL1TyHBf1gDi8SmX8Phj+UD2m2NQjj4ch95jkkgSSSSBJqwZNQ9TxJzJ/UP1H2mWFTdqdRXQ2ZSCD3wGYgEYhxzYkTVV6
PL0jWwhLqB2095TKx2Q4oVkFkcCoo7juPI3EI162HrLiqJs40bkw4QMCsVOhmxcXSankrUFb5TbisJR6Twj9IdHrlqpriKA3H8w7pxIGl6NNwWolgOTa284k
6WlAlRa5uZRN4DRr2G3G36RRFiRHWpG3bcW5r+8t1pvYiqM1tbqYGeGKtQKFzEqNgdbQjRPuujeDfrBNKoupQ25wH0sSo0qoCOYG0106mAde07BvT6zlSQOm
y4Uns17f1D9IJw7NrTHWDmgvOdLDEbEjwgbvw9b/AEan/EydRVA1pMPEWmPranxt6wSSdyTA1sCu5Uf7hA6xBu/kBM0kB5rIPZp3PNjFtUZjqfKBJAfhzanV
5kAfO/2hL7a+ZgUf4bHvH3hr7Q8DAzTq4IfjOia+G3qUG61PA6H7es5U19GYk4XHUqgBK3ysvMHQiB2OhsIKmCq1ao7NQhD3qNbeZsJh6ZxZrVyoNwp4cTO1
0pWTA4MUKWnId5/7+c8/gqC4mtUq12yUKK5qjfQDvJgZV7Oh0A3j8cih1enfq3QFe4cvW4meu6PVY01KpfQE3PnNFJxWwZpNvTJI8D+/1gLYZ6Svx9k/aIIt
H0xZmpt7LafpFOMrWMAIdJDUqqi7sbQSLa8Js6KAOJqMd0ouw8bQCp5EtUNiEBcjw0A9ZhZmdizG7E3JPEx7OSjjiVX5TPAkkkkCSSSQJJJLVSxsIGqqf/Tw
vO7Dyv8A9yqWIZQVIDId1IvAYdhBfbRR95qqYYU8LQrU2z06i2Jt7LjdT/exgKwWMqdH41cThT7J2OzDiDLx9XD1sbUr0KBoU3NxTLXtAtM7m7mBRNyTCpoX
OxIGpgiNLFKSohsSbsR8hALJc/xLeIMvqGPslH8DG0/wVZ8qrXosdrMHH2gtRBuaNenVtwPZb0P2MBZpMN0IlrSc6op8mEtK7rpe/cdY5Xo1tHGRjxEBLow/
iMpPfqYHVBhoreI1ElVcjlbg980UKtWoMnWIgA3I1MDG1Mjvg2M0l86NmAzKd4kMx2MBckPMb6gHyljId1t4QCw9A1iSWyoNzO8v+GMQKKuy00LC4WoxzWmJ
KuGXoilSp3GJSsXLFdCCBbXy2jMR/iLpQqE69gvDNqYBN0DWz5Wphb+8CbTndIdG4no9wK6EK3stwPnNOH6V6Ur4hKVKqz1HYBVtuZ1emcbmwOKwGKZarUwr
U6gI0bS/lvA83SPYI75fDygUjw74wAta3IwM86XQeHFXHCq4vToDO19r8B6/Sc6dxx/4/o1cMNK1Xt1e7u9PvAydK4s4jEEgki9hE1BUTDrhycqk5/E98QKh
FUVRup7M7RSl0nhmr0uzU/zKfJuY8YHBIsbGMoVOrqhjquzDujK1FlcpU0caAnjM5BU2IsRA0Yherq66jnzEGsLoG47Ews3W4cD3k08uH6ekCm2ZShgLBtG4
eoKVYMCQCCrDuOkCmqlirnLfY8jLpoWLAjbvgQg03s2tuIk6tX1RgDyMsKwF1IZZOwfaUqYAGlUG6HxAg2PIzQEYapVHrDDV/jB84GQKTwMIU2PD1mnNW4sg
8SJRduOIVfDX6QEdWF9onwAhLmcinTQm/uqLky74cG5NSqf+IkbEvlKUwtNDuE0v4ncwDcLQU5mDVjpYG4T9T9IWAxa0S9GuC2Gq6OBup4MO8ftMckDo4mg1
BrEhlIzI67MOYnPj6det+GbD5r0zrYi+XmRyispNtNzYQLpUmqMAPMngOcvs3yqTbnzmior0sODT4kZiNxxUfeZxcrUqMdTx7yYAIxR1Ybg3jK4CYg29m9x4
RRUqbMCI7Eaik3OmP0+0AqtMKG04BhFrqCd+fP8AeaqmWpVYUzdFpMb27rzCCQbg2MDQrA9mpryMUd7E28ZYIYcr/Iymva53GhgFT9moO77yUlvtxMGmdH8I
2m4p2uLnlA0phVYC4mfEUOrci45gx7YhjpRH+4wUoPXqBXropPFjpAyK5Umxji4emOz4qdj4HhOif8O490z4YUcSOVJxf0nMdKtCo1Kqjow3RxYiBowmIGGp
u2FUnEP2cze4vd398yVaha4LXJN2PMyA2a5vbmIbqKmxBbcEe9+8BSce4XmrC64imDsbg+cy07hwOekbRc0qna0y/KBowVBaeKq1qw/LwxvY8WvoPv5QMbVe
o2Zz26mvgIzG1bYskWKNaoADpcgG8xVKjOxdzdmgCx4DYRuExVTCVxVpnbccCOURJA9I1PD9JYfraQ14jiD/AH/fLkYnDNSOWqCV4ONbfqInCYqphauemfEH
Yiego1aHSFK62DcVbTXv5Hv2MDzoDUXDHVTpcbESnGSpz+862I6OZWbqdCPapsPt95iqUb0yhRkqILhTxHdAzVBezjYy1WmyXJIPlaFRo1KqFUQsb8O4XPyg
5aY3YfWBVyrdloea+6j1lXpfF/8AmX+X8Y81gSw7xKKg8jCyKfZZD5yyjDgYC+rHC4glGBtG3PGWDpa48DAzkEbi0qPZdRkB713hdSjHKSEce62nzgZpI6rQ
anvb1vFWPjAfRAemyr7Q7VviAhYVOtqgudBv4QujaBr12A4KZVECnTqsNzTPzt+sC6dTrRWJ3Zgw7t4Fr4QnnUUfIysKQpu22ZQYxaVRFeiwtZszH4bafOBn
RmByhwB/NtHtTZlUsaJAFhZvtEurD2hfvi/CBtNRsPhaiugFSuAB3JfXwuRaYYYY3XMMwGgBmk4mjYZMHSRhxGY39SYCaNJnByqWPIfWCdyOYjHqVKpuFy94
0gEWYDlAFdCwvea6OHAw7YzEaU75UHxGZsNTFWulMtlDEAtyHEzR0jivxVYJQUjD0hkpKOXPxMDNUqs500XkIuMFGofdt4masFh1XFUnr60wwLBdyO6AODp4
gVB+G6wVSbBkNrd06ON6ZOIojCY5UxhpiwxB0cHkDxHjNFCkRgamHohKb1GN6zN2sp4AcLxSdCYVNa2MQ9wgcaqlrFTdTqp5/vG01VcPTrL7QJuDxE7OPwnR
a9FlcLUviVYMADm8b20Gk4at+UE4C5gFjaAp5KyG6OSAe8fsRDrVqNektUMKeItlqKV0fkw7+YmjEU8v+G6Lv7VTFMVvvYKAftOTA04jEU6hHVUhTHvAcT+n
dM5NzcypIEkkkgSMo1noVA9M2PyI5GLkgem6NxtPHgUag/MUXXXtL4HiJrCUVqFa7CyG5OW5H98/nPIU3am4dGKspuCNxOlW6RbF4Zc4/Pp7OOI4g90DTUo/
h2OJwbaI+dFvqOamcnFU1Wpnp/w31Xu7vKW1RyS6MQ25EukwqKaVQ2Dag8jAzSQnUoxVhYg2IgwJCV2X2WI8DBkgOWuf8xQw9DHLSSuP/Xbtf6bb+XOY5YJB
uIDw2VrNf9JpqKMRhS2nWU+PMS8Jl6QvQqW/EEdh/iPf3yqAakalNwQerOnlAwhbtYkDvjqq0aYATtnnEmUdIHR6LaogqPQNNqosQjHVwNwJkVwzOoFg17Dl
EAkG4hFyzlmNydzAbTQdVd/ZBuf0m3FfkYGmh/iVT1j/AGE571SUCAm17+coOzElmJNtCTeAw1AaBVtGXVD3cREkg7ixlMbnQWEqAdMgNrNAtMkbScggHaBo
Ag4mi1GsA+hKg28ZpwT4davWYhwAuoXe5iukK6V8W1SmzMp4sLcIGSkcuZuQh/iaoFlYKLbKLRY9i1wLmWCQSVNvAQISxPvMY2nTrP7CP62gZ1drsajHxjV6
njRqH/dAcmAxj65af+6qP1jB0Vj7XRaJ/pdSYhTh1/yv+QvN2CbAVGAd8PRb+em/1WBkahi8M2bE06iKAbE7E2sJmoo2IrpQpi5c2mvpbGNUf8OjsaNM6dti
pPMZtbTT0LSXB0anSVZSxRSaa921/WwgJ6frJ19LBUiDTwiZNOLHVv08pyYbFqtUsdWY3NucYuFckZyEv8W/pARJN64SkvtMzH0jB1SexTUeUDnLTdvZVj4C
EaTj2hl8Taaa9d27Ck242hVsEcLTVsVlpOwzBGN3twNuHnAxZf5hLCpxf5RhekPiMmejxVoFAUBuWb5Q+tUCyIAJaphX0NUp/Up+0b/4ys6lsMVrgf6bZiPL
eBkZ9LWkzbW05yMrIcrqRaDbiIGh16+j1g9tBr3rz8plj6FQ06gZeexkxVIU6gZL9W4zL+nltARJJJAkkkkBuGc08TTdTYqwM6/StRHxj1EsCaPbHJtQZy8B
ROIx+HojepUVfUzT0jUV8Vinp+zUrNl8Ln9oGHc6amMr0DRZVLAuRcgcO6MwSZsQoVczb67DvMqqTTLMWzVHJseQ5+cBBULcHUiS16ZPIweHjGVRkRU47mAq
a1/B1FF89JvUTJJAkk2UOj6lZ8qvT01Y3uEHMzVRwtAsQl+rX2qjbnw5QObToVaptTRmmj8AaaZ69QIOQFzOgcQijq6CE8lUfMzPUw7uesxNQIO83PygYnKA
2phjbS7QMrHhNDvRp/w0Ld7D7RDO9S+thyGggU1hpx5CWiu5/LS/zgqhMIIq/wARvIQGphq1Q2NSmp76g09JHw6o2U4qmT/LmP2hrWNsmHpDxYfaNoUAr9ZW
sz72O0BFfD1MMFJrrmYAhQSGAO1xaVfE9V1jUy9MGxYrcDzm+riEapnqumc+82pkqVkdLYfEkH3mysB68oGFatGoMrrbuOonSrY4HoyphkpMWrsobLsFXZRO
c9OnWuEK9aOKAgN+hiqdQo2R72MBxZqa2Xq6I5A3YxStUDXBY99pdRjT9hVtztAGKrqezWdfBrQHio4F2U5fitpJUbskiHhulKtOov4lFxNK/aR9CR/UNYrF
vTOIqjDhlo5zkVjcgX0B8oB9Huq42jVqqGCNmIOxtqPtMtetUxFZ61Zy9R2LMx3JMJWKMLwKq5WuNjqIASSSQJCV2RgyMVYbEGxEZh8NUxBbLYKouzMbAQWp
W9lg3dxgb6XSvWgU+kqIxSbZ/Zqr4Nx87wsR0YrYc4zo2r+Iw49sWs9PuZeHjsZypowWMr4HELXw1Qo405gjiCOI7oChx+YmukPxFBqB9q90P837jTxAmzHY
ahj8G3SnRydWadvxWHGvVk+8vNT8tpy6b5WBgKOhlTTigHPXL73teP7/AKzNAkkkJFLsAIGnA5qbHELoy6J/Uf0EXWPbCLqFFhNlGmGsg0RBb+++ISmKbkgh
jey98Boy4XDlT7TC9Q/RZhZmqVCWOpMPEVMzZQbgbnmecWNFvxMA6di+Y7LrAZs7ljxhHs07c94uBckOnRepqBoNydhCKqpsDc90Dv10Bp/hMIiKSc1YqLIt
u/kJk7BPVUjdV3qMPoOELE4vE0cN+GqU0zMASyPc+BnO/EFFIsQ1+MI6BrU6SkUxlHE8T5zDiMS1TRducQGzas3lLAzHx2EoAi+rHT6ywxtYZPSVWPbIGw0g
ohY6SKaK9RdAFA/phddm9qkp/wBtoogpwt3mQFjsCfKA41yFsqsvnEmoT7V/I2l3fivylXPFflAJWp3uwJPAHaG7dkF7uOCrooibod1I8DCWwN1a0AWqswts
vIaCHcVV19ob/rDJDe2L98E0db0zfuMBlNRVpEW/MXQjmJmdSrEHhNFFitZW2J0Pj/3GYlco61VHnw/swMyJbtN5Ayi1zf5yiSxudfGS0CE6b3hBgVyt5GDa
S0AWUqbGWilmCjcws2liLiEiEbcRvyEB6VghRaYzIh0FtGPEn+9oCIWxDqugzaetpaAZlA2vYQ8IwesRz+faEDNiFy13Fra7RUdiyTi6pbfOYmBq6Nx1Xo/G
JiKQDWuro3s1FOhU9xEb0lh6VDGE4UlsNWUVKJO+U8D3g3B8Jgj+tZ8OiHXq2JXwPD5QBD20OoOhHOAV5aiMRFqMVvYnYyjSdKgVha+x4QBWmTvoO+aKSEdm
ktzxMUWA04iacNWC6HbnAeaTCllvYDczG75VLjjonhzmrE1etZcPTO+rnu5TBXcPU7PsjQQFgXMMDM2g7gIOy95mnDoQM4GoNk/q/beAmsLPkHu6Hx4xlOiE
Aer/AMYxUUNfe2g/WVVIUZnPgOcAKtRnGuijYDaILHhpIzFjcwYGg5qNQqrhspt3GAbs56zW/GMCpe67S4CxTsd9IxDlJb4QTJK4fKEZ5rSsKWGFOil6jaux
HoBMhFiRN1CjmpKwp0zcbtWA+UKyNe92JJMJFTdn8hNVREpNZ/wgPK7Nb0EHrqQ2OH8qRP1gT8QFp5Va/INqBE9Yp9rKfBbfSG9dSLZ1HhStFNUze+f+NoBH
IeDDxF4PVhvZ18P0gXHxfKTTg3ygXZ12N5a1NeRlhjxKsO+XkD7DXlx/eARFxfnrNdO1dWQ2/MFx3E/vaZEBFIcbNb1H7RtB8pHcflAyG6mzDXleTOeFrTRj
hkxTEAWfteu/zvM4YDdR5QBvLXU2JtJm8PSQEX1EB4ogi5fQamXwtaxPygplOw0Gp0jKZAvVfULw5nhAg0qMNurQk+O33hYGneujng1vQXlHIaLFCe2wBv6m
Mw9lou2osh17zpAwVGz1GY+8SYMe1IgXUhl5jWBkvAXGU1Nj4SwtuEuxOmw5QBW4FxvOhSfPTBmK2ktHdQVU2BgHXSmKnZ0PEDaA5CXy+UsCCi9dWC+6IBj8
nDFj7dTQeEzKLnXYRuJfPVIHsroIsjZfWASKajiwuSbATflCrodFGVTzPE/aKwtPKmf3m7KfczQ6AEAmyqtyeQgJYqiF29kaAczymGo5qOWb/qHiK3WvoLKN
FHIRUCSSSQG0iQxUxszg2YGaIFScDJLHEd0qEVB2vGGuIdKXVpZebDeVUGl4uRVSSSQJJJJAkkkkCSwxGxlSQNVOoXouGAzAqb/L7yr5WU99jAoexV/pH1Et
xcGBpxNmp0mO9iJkcaR7kthFYbq1/X/qZ2YDSAFpYHHhCCg6w1F2HIamBYGVQvE6mMq9kLTsNNTpxl4dDUqFtLKLknaUtRDWC0+0Se07D1sIEqCyU1tY2JPn
Dt/6lswGd+fAf9xbsXcmBjDaqKY2pjL58fneAYoVSb07se7eKa4azqVYb6WMWjvTYMjFSNiDO1hOksHj1GF6bS19ExlNe3TP8w94QOSG5+sKP6QwNXo/EmlU
KOpAZKiG61EOzKeUzrppw4QCtJbWWJJUUxssNPycM1Q+020UB1lUKNvtCxbZqgpjZfrIpC6a+kZQpmrUCjjx5d8C2YgDYTdQpFaYUDt1Pkv7wNmCoCtULnSj
SW57lH6zB0jiAzmmmmt28eA8p2OlWXovo2ng1t19Wz1O7kJ5om5uYFSSSQJJJJAJlsdI2m118ICgbkEqBrbnBvY3BgPlqbMIKNmWXCIyWBsbjiOIiCI6oSrL
UHEaymUVFzJvuRCk7iVDUC8p1ynugDJJJAkkkkCSSSQHUNqn9H3EM8YFD2ah/lH1EMwCodqi6d2nlr+szuNpowxy17Ha4/v5xNZcrFeTEQJT1EPZe8yqWiFj
4DzhoM9Sx0A3gDWbJTWmD7Wp+0qhojNxOg+8ByatUkDc6CPYBAEHujXvMAqNg5qNtTGY/b52mNiWJJNydTNNc9XQVOLnMfDhMsCSSSQNtDEGphfwlU5lQl6V
/dPEDuI+YETa1x8Ji6Ry1FbkRHOLVSO63p/1AsQajWHfCG0UQalQKIQ7DgU6bVW8pnJOpPtNH4hgFFMbDeJpqWa9r8hzMKfhqQJu/srq32E9B0JQQdb0litK
VAXHeeAnLw2GetWp4SkLszdo8z+03/4lxSYbD0uicMezTF6hHEwOF0hi3x2MqYiodXOncJmkkgSSSSBJJJID11QX4y8istjoeBhILlQfP0vBarasQ4uNu8eE
BYvTexjZTqCLHUHUESlv7J3EAiM1MjiNREoxRriPU2IPrAqU7MbQLdRUGdPa3IHHvgizrYykco1xp9oyotx1tMbe0o4d/hAQylTrBj9HWx2+kUyFfDnAGSSS
BJJJIDqA/LqHwHzhmVQH/r1D/Oo+sswKXSsO/STGfxv6u16ymOVlbkYeKF2ptzFvQwKAApju185Z7GHZuLHKPqZdrlKY1vqYWIpjrqdEmyooLeJ1/SAvDplH
WHyhKLkljoNTDbXQCw5RNdso6seJgKqOajljx+UCSSBJJJIFqLsB3zQ9zVJO12AiqAvWXkDcxqA1OrHEsTApjZbyUBlVqh32EvEALVKLqBKrdlFp8t/GAtiX
bxmqgopp1vLRO884rD0i7W2vqTyE24ek2KxVOnSXQsEQQOv0cF6K6MqdI1gOuqDLRB+s8tXqtXrNUdizMbkmdf8AxFi+sxRoo5NKj+WnlufOcSBJJJIEkkkg
SSSSBspj823iPkZmrfxW8ZrTTFC/x/eLrYcs56s5mAGZOI0+cAKDZvyzx9k8j+8sjXbUf3aI1E05usTPx2bx5wKlnVL8V0MqWpsddjoYQBF/GSm5psLfP6Si
SjlW8jLIBEKuqmS1Sn7DcOR5QcwKkjXmDDpPlJRxdWGo5jn4wK1Pq23uDqCOIgAUuLpqOI4iBLBsbg2jTZh2x/uEBMkYaZ90giV1b/DAbS/gAc3v6D94RlBS
qIraHU/36SzACp7Ea3bwwPFT+32EWRcWjsIqu4pObKxsTy/u0IRSZlqZlOvEnaaSwq1nqW7Tm/hM4YPdQQBfQE2sJtxOIwaADDU8oA2zZiT3naFIqsKS348J
iJJNzuZdR2qMWaDAkkkkCSSSQG0RZKj8hlHif2vNOEFlaqRpTXTxMS4y0adPi3aPnt8vrNFUdXgUQaGobmAil26hbfj4wW7VQ8bfOHQOSnUbbS0ZRUUafWv7
XuD7wLcihS6u/bbVz9p2OhF/D4fEY9hb8NRJX+ttB6CcBb1awX4jaehx7fhf8M0EGjYqo1Zv6Rov2gebxD56p1vaKlneVAkkkkCSSSQJJJJA21f4xI46jzEr
HaYnOvvAMLSVPcbmo+Wn2l4vWhRa17XX0gL65Kmldc3840b9/OFSo2a9FhVQ6Mo0a3h+ky3MvNxGh7oGllKOQdx84JlrUNWmc5u68TxH7Su6BTrnT+ZfpEqx
WPBsb+sXWWzXGx2gXcPsbHhGIRUTqX017J5H9Jm2jL51ze8NxzEAGQqxUixGkaq5Ra8O/Wpm3dRr3jnBgCyG91NoGZgbZo07RHGA+nci5N4UFNFHhCgVLU5X
BEqQyoXiFy1SR7LdoRU1VB1lD+ZNfLjMsipJJJAkkkkCRtCmKlTtaIBdj3CKmlh1NEU/eezP3DgPv6QLW9fEXO7H0mupQNdKjE2C6rfYRXR1PNULHgCY/GVL
AYenufa8IHPoVQrWqLmXe1+MZUc1buTsRLakCw10UWFou2QuvAi4gHhQTiCRuLkTuf4yPUVsPgl2oUUT5XP1E5XQydZ0hSQ+9URfVhNv+Nqmf/E+MHwuR/fp
A4EkkkCSSSQJJJJAkkkkDYdaS9xI+8tu3g3FrlSG+x+0FdVYef2+8PDlS+VzZW7JPIGEY8t9t+RlEEbidep0LUqgvgatLFoP9BrsPFT2h6TnPSrUmKOpuNwR
r6QpdNijBhuDtHsADp7JF18JnNuIsY+kc9Arxp9oeHH9fWBJCM65eO6ySQhFuayxdbOI/ftf8h94XVggra14Ui5RlqU9j8u6MNjZl9lvlFDsMUfY6HuhIcjG
m2xgEdjERpWoxyBST3S1VEYDR348h+sAxppJJKhEkkklFo2VrxVenka6+y23d3RkIEMpR/ZPykVkkh1KZptY+R5wIEkkjKVPPdmNkXc/bxgFQQAda4uFOgPv
H9ILEu2ZjcsbmFVqZyABZRoAOAlU9XueGsDoYZ1oYd6jb3sO+YHquzM19TuYTMWAUtZVi89r2HhAOkxU3J0Muo1yCPCKBMs7QNnRFUUOkaFQ7LVQnyYTV/jD
T/FXSA/+y/qAZyASDcaGdDp/EDGdIjGD/wDsUqbn+rKAfmDA5kkkkCSSSQJJJJAkkkkDUh/MXv09ZBfMRxgObC44G8Y/tZhx1gZyzK+ZSQdwRwm5OmsaFCV3
XEoPdxCCp8zqPWZKy6XHA/XWJgdUY3o6t/8AIwD0jxahV0/4tf6w6NPog1FdMfUpWOq1sOdRxF1J+k48kDZWQUqzIrB1U9lhsw4HzEEy0PWYZT71M5T4Hb53
HmIJNhfhsYEBINx/3H0ch7LOqjgWNvKJkADDKeMIZjadN0FalUV2XSpl+RmUdtLe8u3hG0z1Fazg5G7Ljui6iGjWK8QdO+FMVy+HZLm+/jAojssx8BKPYcMv
stqIScbbA6QDlS5IRUks2AuxsIdI0nRyWKsouAeMBckJyqkZwVuLg7yFTlDCxU8RtCpcMuVxdfmIipSKa7rwIjZYJG0BaUrLnqnKnDm3hBqVC9gBlUbKOEc6
iqSxJzHmd4hqbKbEQDRLUy7eAEunpSdvASlXMNT2RvAJ7IHCBM1vGDJJAsHWXBlgwL4xqt1lLqWOoN0J4HiPOJl3gCQQSCLESo0sHtm3HHjByX9lgfkYASQz
Tf4TJ1b/AAmAEkPq/iZR53l9gbAse+AKqW2EIZU27Tc+AlnMw10X5QqdPPtoOcCVPZMMa0lJ3ECp7Bm7FoFrCko/h0kU+OW8DKF6wFBuwIHiNR95kmyk5p1F
YC5UhgPDWD0jRWhjHVP4bdtDzU6iBlkkkgPwjAVsjGy1BkPdfY+toZBuVYWOxHKZZsqnPlq/6i3Pjsfnr5wE029xvKMImrCfh66Ng8UVpZ2zUa5/y3PBv5Tb
XlvzmerTq4eu+HxKGnWpnKymADFioBsbbXi6mYkE3sNBeNIkgKNOoAAwsLxgFhaXvJAkvRVLNsPnIoubRWJe75BsvzMBbuXa5lXMkl4EzE7mPoEo1xUUX3B2
PjEXj8NXWm3bpqy32Igaq2HK01rIPy3242PjEWnQwlU1rpVOTCWdUFuJ1HobTIaZvtCFWhBCRYajkYYpmMSkxPZBPgIGV6XNWHgdIkoRp9p1Q9Ogb12S3wnU
+gmfE4zBuw6nCuBxJe1/KFYTf+xKAmnNhm2Z1/qW/wBISoP8upTPg1oGUKSba38JfVv8J85rIrgaqfS8U2YnW4gIymVYxhQ8zJkPMwAsZMph5O+Tq4AAHnLt
zYQskmTuECgE4v6SwyL7NMnvMIacBLv3CAp3ZzqPQQTfjeONzxHpK6tT70BtNQ9Wmp2LgH1j6jFumMRfi5HztJJAzv2X04GPx4DdHYSofaU1KYP8oOn1kkgc
2SSSBJqpG+EN/dqaeYN/oJJIAP7HkftOsw/G/wCGTisRrXwlVaCVOJQqSAedrad0kkDmISyAmWZJIFS5JIQxNFZhuFJEyBAd7ySQq8oDWtGLTUiSSAYpL3wh
TQH2RJJCNdJAVDEk22HATbRwdJ1LNmJ8ZJIHLxeLahVKUqVId5W5+cyVMVXqiz1WI5A2HoJJIUiSSSBJJJIBKzL7LEeBjBiKw/zGPjrJJAv8TU4hD4qIdOrn
OtNPK8kkDStJG4W8DLbDUwNL+skkBZpKOcA0wOckkIEqJVpJIFSSSSj/2Q==
]==],
[==[
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
]==],
[==[
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
yR7rrGtRRB//2Q==
]==],
[==[
/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAA0JCgsKCA0LCgsODg0PEyAVExISEyccHhcgLikxMC4pLSwzOko+MzZGNywtQFdBRkxOUlNSMj5aYVpQYEpRUk//
2wBDAQ4ODhMREyYVFSZPNS01T09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0//wAARCAKWAUADASIAAhEBAxEB/8QA
GwAAAgMBAQEAAAAAAAAAAAAAAgMAAQQFBgf/xAA2EAACAgEEAQMDAwQBBAICAwABAgARAwQSITFBE1FhBSJxFDKBI0KRobFSwdHhBhUWJEOS8f/EABUBAQEA
AAAAAAAAAAAAAAAAAAAB/8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAwDAQACEQMRAD8A9Z+JB+ZYYVuA/MS4LN9pgOC+ZZSZzvArmR8uQiieJUNBUmiaMLb1
8zHZuMxvR74kUx1ZW+4Q8bg8MaHiCdSFUirNVz1KxFMisDSkcgwCZyrVQ/5jQLTcPHYmdsbKAewfaQMw4uA+Q8S8TblNrcF8iAGhZ8CBY5EkVjyNuFgGPq1D
AcQA2yAUYUkCGSXJAkIQZIBSShLgQyjUkowITx9tGWGvof5gddQaoyhm+r3DqEKPUgKt2e5CtDg/4kF1JJyaMggSXJJAkkkkCSShJcC6kqSSBJJRZQe5FYMa
EDIAa4PHmGErkdxYJhbiCCSSJUHXPMhxqf3SCnvk/mUQygEjg9GRQZMaKpJNTOxAP2tf8Rrgv3FlAIAsd0tCV6NSbeYaY1K2z1A04MxP7m4AgZXxsSao/HmJ
YUaU2PeDRgMDUftJqPQjKhViOrBk07Ky0QpI6BhNjxbr3ML8AdQATFfR5HYmi9mIhwfaKx8O1WRCYqV2kHkWeYAqQ181+fMIgiAFCn7xH8Ou5evb2gLBrxcl
gtQELbJt8iAMkpPtyW0I7bO03UCpLkJHVyEEGBLkkqT8mBKlVLND+5efmWBYsciANQl44kqSEET7Sgb4kkhVqAoq5TeOeAZLqU3UCBwRcoZb8QR3L4B4gMBt
Qerl8eIsNzzC+0cgk3KguZUSSbon5jmsY6PdSKBkscS8f2tzFoShvuPSmF1UDGClHuLfIP7YZH2mIIMqHB12WMlH2qGM6lNm2xd9zNtMNFoyKe6rt3IePIMS
Y3IKJAJqDtgLIlVG7ZW2AuWLhbZYBBgUlgzQ1ZGscEAce8FSrLTCMTb4HMCgSgsj8xORrs81NJeyKF+8XkAUEAckQFYtTt4Ybl9jNG4dpdDngcTKuC+2Agtj
YGhZEDU+RcimmJrkgcGEhClGBJPtMuNBW43Y8Q23UGIoeIGlSFyFXb7Sb64Mv0V7BJvxEpnJUo43Cv8AEga33EkgQGbKViBypo3D2lgKomr4MVmdyu9BtXyR
5MLCUyEU2x4EqU62KmimIO5T8N4Ji2FfuRhAyFaMfjZBjA8nuW+Oxa8j3iuFvdYAgaNvt55gOyoObiTqaNLdfMHNqPVABA49oDRnxk0dwHvUaK7YUpFqRMAa
a9MWZDQsLyAYDCCCQZVRzsjjcvBrn5i1G4EqbruABUSbbhGVArbK21ClwBK2IQJYbSOZKk8wF7ISWrS/MKrgZLNcSBQeDLAhASoSVIkUUY4i5WzmAZAc3uN1
zB9M3LQc8wyIUsoRKqGzBVLHoRa5g/ITjrnxIJUlTQcKnD6iE8diKIgCBLDGSpYSBYJrg1GVaBiLB8zJmZlNeIWDMUeweoGhRiYWGN3yKlvj2MQw5EMZF37j
sA965kyOj46D1UBQLq39McdniEcfqN9qIGoXzEepjFDcSff2jseZeRxuHXPBgEuCw14qYexlEgoEcUR0a5lfrhf3Cx7DsSm1i+lewE357EBerOxyvQ/6bmQ5
DcPK+TO25ufA+IGLF6mTYWCE9WPMB2HUMAF3ELd8TqgqcW7lgaFicjAEDkZLBHHuLmsHUAn0yvV/Yf8AiA92TEAjGr+P9zPqSqYtpAYsftcf7lOjFtzPu3c3
HsmL0CgIyMBa/EDmhGYEqpIHZEGp0cOJwQ6Ot/nqDqdKWzn0kVRQ81Z/EDEo95r02QI68gTOylTTCiISA3cDVkXIOmDKb48/iZtzA0bE1gs2FVKEG7sDv5hZ
13UChJ94Gb1X2Vf8wlyjaN/d0DFtn9K0UAnozOcnPUDpMqhQ27g9eZfp8CiDYuI0uZv2iyParjkLDLtZgKNV7wJsPwZVe5AmZxkTKQ9hvzHYz6qDGwO6/tb/
AMwGFDVjke8DI2xAxB56i2fIgKX8HiAchorXB7EAwssjxC4IsccyfmVAjcO6MIAe0go+ZKN8XAhWU7BRbGgIQNiwQfxM2rdeEvkHmRWd8ru5okL7fEZhLjgE
88RagXRNfE1419HIp4IPIPgiBvw1kwNanhaMy0I/Fq8GPEw+4N+JjfOlWobdcAc77BSnmJXM4PccVTMg+7a9+eqmfJjbHkKN2PaAbixfkwVsGxIrGq8RqgMQ
MQJbyYC2JvmUWaqvibNygDFnx38ngr+IrNo2D/0D6qHojsfmBjJMm4wmUgkEEEe8qoA2feSzLqSBVmVZhCWCDwQIAqSDNWPUDGKUd/8AULiCB4gwNL6hm9h+
BLxuoPNzNCBgdTDlxOtlORwTGuiMgYtVDszlY8u35+IRyMVI3GBsy5sDZN1qxqjxcMZMCgMoUGqIA8TmhaPdxvqgJt2g/MDYNYofkUnv5mbVawsKxsQp79zE
ndkJPRPiIdSrURAq+eYSsATahvzFy4DFcg8EibMOqfhXO4fIuY8eLJkBKKSB2faacWmyG7oMBYBgdHL6OVMYyHocG+amY4HV9h/g+8QjFjZua8uTbpQVWhfB
9jArLhORNwX7xwee/wD3MmxroA37QVyMpsMQZqy6gHTqe8h4v2gUFG0bZDZHMFCa48SM1Eg9iEKOU48hWHjyhsoLkAHiKdN7cmKzg49q7r4sfEK0hlxo/wB6
ccATBkYB7DA3F5HsVFkwNGMi+TOpuxDRIu5CSeD5E4imaMbdQNrafIWrEyPxYo8mIZHVirqVI8GPx5MQ2kbgR3Uc+fDk2K6Ma8k81Ay4xRBjc4TKEN06ivyI
eTAPQ9bCWte1P/My5WL4yKq4AZnXG1Yjz55uoGLIxyAsbrwYsrUlcQOxqNZgbEq5E3mr75H4Mw49UyPakgXYqZRcLGLaB1MOX9XlGPILGRdp469jFPplODcq
kMp/zB0mU4W3LwfedRHTIi7ztau4HDdGUjcCLFi4FTsajDidgmXhwOx1MuXQOrAYyGsXXmBgqXUf+nyH+2VkwNjPIvi7EBMkLbCCGiQCQO4CwIVCXUuoAGWG
llZW0wLJkBMrbxKowHK3tIwvsRakgxpqru4CWQeJFxlmpRZjWxsED+LqCthrF2IDGBSkU1Qo+LjFyMiAKSD5MQ7ksSeTK3moHSxZsXp/1Hv5MRtw5G2HJkAs
10RMO4wg5EDZk0bAFsTb68f+JlYsLU2K8Ga9DnZn9N62sK9ql6rGj5924jjm4B5BjKfYUDjrmYsus5/crGuwJWfKi43QAG1qc0tUDemUlS18CZs+c5GJHED1
605xBRy1lv8AtEkwC3S0G4gWBfkmhFQxA24tIcuJnxuGZe1PEAAq+1uD1zFplZVKgkA9yA23yYGwo2Ej1FIsWPmCrndGsVz6UljtfEvHyPaJwqSbokCBuXPh
2rjdTRH3G5nyZFClVVfyRzBzKFYUb4gsvkwFEQ1UHuA+VQaXmCchHMBx2VVQAQp4ihks8yFuYGvE9g9Ax+FnYhR4mPEd6/uFgdEVxOwceNNIrJZ3D93v+YE3
JmIDtT9bvBh50Y7WDUOiPYzNiTc9GxN5VgQSQVIG5TAU+JsmJebyDz7iJXg0TR8ibHH2k4DY6NTPmzocQBQlvceICPTTeQyqLhLj9Nj9tA8ETOmSjZstfnqb
MGpGS1YDcT4HcDn5UC5GUAgA8XBAnTfAuZSaYbWPff4iW0yFTsJ3DkfMDKcYKWARXcDZNKq1UILYiouAjbJtjNsuoCdstV5jCtybagNUK+MKxo3EsoQkLzCE
s8wEFZRWaAolFBcDPtk2zQUEsIu3vmAlCUIK9iEzs37mJhbZWyAKaXTmt2Zg4PIPR/8AEDU/TQ5DaV0J/uUtX+JnDkTTpXOTKE6uBzM+HJgynHlXaw8XcCdn
63pzWLOoBULsY+x8XOQRACWDIZUAweZqwZSgAFDm+pkEYjVA2+tbMSAS0n6hkfcvBI5oTLu5gs9mA85ias8DqKyOzNdmBcl3AE3Lsy5IEEvzKlwHYp1tHqAv
2PZQ+PacdDRmhX444gdgHT47Ayjn+Y7MT6fq4z0Ae+CJxkJYidHErppHDAi/eBeDMdxCqFs2RKz/AKcZgFH3E831EoKYH2iXJ3WeTA2HTYKoFgx9jdfEz50/
TNtY23xLwZ0D/e235idWQMrffu5/d7wHabVNj3AjcD4PgzUv3AMqgN/0gzlLlCfcOTJj1DLkLBqJgdYfdwRUFkUtt3AH2uLy69Ci7BZI5uJTWAEVjQnyYDHQ
KSDYI9xF7D3Rqav1StjJLBOaB/5mPJqchc7XIW+AvAgGfsCkoQL7ImpFxZlAC/cLoH/iDomXIpVyDuFUT3NWLDjxNt3fNN4MDm5sRxZCKIB5Fxc6eoUsrFUD
FTYB54mYYWdFYYgT7BqgZZYBJ4mp8DKqlUBPTLd8/Ex5szOaCqou6UQGemQQCQL9zKZSpphRiLJm3CjZdKxK3t5B/wCYCKl1CqpVwOSTzUdgba6t7GZ+e4xS
YR2UyUDtyBw3YMZp0Q2gVCNvTDgzkY3KsCDOnpXNqx5MK8/q8Rwah8bbbVq+02Imeg+t6ZX0q5MeMbvUskfInO0OgbJnU5U/pjk31Ay4MOTO4TEhY/Hj8zR+
h1Iy+n6R3Vfx/mdZcmHTjZiClQelFRuPKX+6qEDg59PlwEDKm2+ovYS1LyTPR63Fhy4QMpFg2sw4iuGwiILPLVzA5+TSajEqtkxMFbo+IraQLINT0nq4smIo
7AKw2sv/AHErEMFEA89crfEDzkkbqcJ0+pyYSb2NV+8XUCqhBeZAIYECwojkW+ooV7zViZVAN9wOlocKY09R1BPv7R+a8iAr/ImFdQffj4heq/8Ab1AaqoAT
ZsTFmBBjDm2mqi8rqy8wMjg3BLHz4hufaJYwJulbuYFyXCHpkA7F/FxxO/7sSmlW256mIGMxZGVvsYgnjiFaSwZVAFV3z2ZAwB7i+hQh4n2EnapJFci4DsW8
klVb7RZ+B7zaubAzKWy5CTweJz8+pyZhTngQEPMDvYnJyspC14IPYitajYXGZQSp7B8Gc3FkKuCOxOrp9X6nGSq9qgYt+WxkNizwYTMucbcws3w44I/8zqHE
jKLFi7mDLhzLk3Pt5PFdQMeTT5ML7WH4I6MbpspRx4F8zUUbNi2Hh0/b8xemx7mO9ePEAyqs1AKVJ4ic2MI5Hi+Ieo/p9Ec+BM2Ni2Tsc+8DlqsdixhnAY0P
eJDQlygmj1KOgmDDkwWl2p7ruC2oXT/ZQZq/x+YsawY8RXGvNcHqjM+n9Pdvy/cb/aepB0cOufINjqjL+I3V4zk07ZcbN9vO0jx5laVsOQekmMYyTYK9AzWf
SyaZ8WTJtYDaxHYgcPGRdmaBmtwT0PEf/wDWq6lsGpDV3axP6DUq9bNwPlTYgBnyuzUx4HiVdKLHJjv0GZ/27DzyN3UJtBnQ8ruHusDKLua9JiJdSxpb5/Ep
MBLBQLJmf6kdXgBVUfHhH2lx/ff/AGgc/U5jn1OTKf72JiwYMsQDBhXK2rsFN93tK2mBdmMRqioQPMI2I52yxlYeYhW4kJgO3luzL7EQD8xgbioVT1XEzPce
xim5gK5khVKIgDCU0RKqSuYGwDi5Rb2kR1deOPiDfMAhIfiVuqVvPtAbhtnC7gCTXM6enwhcwVsi7x4E44Ju/MehPdwO++QjGdwI2/4mZdYAp3AEe0BM2/Qs
G5YcWfaZAobIFYkAmjUDZjyZWX1gyBRzV1/qUfqKHJtXGNvkzm5nYFkDHZfUWCe75gdkY8WfJau5HtUB9CGN4sgA6oc8zn4NQ2G2VyG8CuDK9b//ACBzzcMI
wCuynafJHBmjKukRB6Xqs13bkde3Edi11UCiFQK2kWK9oGJms8CBzc6x0uHVadm0+IJkB3AA9jyJl2ac5rVDtv8AbfECaTMUe2PXU1fUXIdcqEbcwvro+YGf
Qctl0xGwLuK3yPgTHkzO2FcZNqpsQDXM6g0xF+0emvzBr3G6qc+zfcYsDtF8j4sWo06ksvD1Ft9QyHo7eepi0+c4nB5I9rqTEtnzA6zMBpRqb5A+81c5P1XV
nJWHHkVsZAZq5sztaZQ2jOE0SwII/M5mX6I64LRi+XjjgD5gcWSj7TqH6NmVhvyIq/8AV3/qOfBnwaYDC27Gve3sfMDnafT+ofvYoPHHc6Gt0OfHpg6fcnG5
a+4TKO7nQ0mfLaoXO3x8QOGZazt/UtHhzZEyK+3IRyoH7vmFi+m6fEVIZyx7LdQMuLS4VxocgZn7Iuh+IH1FMOJcKY025Ktvx4m/Gm/NyQFB5Mz/AFnEG250
YFVrHXmBzAYVyY8TOL4VbqzOjifTYkP9FCa+0+b94GEY8jftRjxfUW06OHI+TUpvZjzxz1H6zSYsuZcrHYG+1to5LQOLUqp0Nd9POmdTiLPjY0OLI/MxFSGI
IojwYFLjB5PUsY6N1GLW2SAv8CQAxlSwICtplge8bUAgwICBCD1BqTgQHLlI8mT1CejEwxAtuezBAAlyoBACQqJBLMDnMxY2TDQwak/EDpaTUtg5Wiam9Ew6
nTPtwKMgBI2ijc4eJuRc7OBmwIhJWm5FHkfxAyafVthe/wCCDFtkxHU5HXECrHhW8RmTRZWZzgV3VRe4irmLm4HU0bad0bDmxqEbkEDkGO1P01Ct6cENVgeG
/wDc5eG9wndw5Q2DGhuiasH4gcKiGIIII7B8TfgxoqgO4XJd7W4sfmK1w9TUtkQWAAGPzF+lkQISP3jj5gdnTEDaxXhjVg+YzKmRuyAnsp5mLQ6hrKZHBUeG
h6jIMWoYgkkgEX1AvPibGgy4iXVf3KfEHSagluUFfAh6XWAWuTox36ZUzB8TBFYcju4CdVo0yKxVEVhypUVY9pkwDGKJY/x7TpDbgXa7XzxQ6nPz6cYCCrbs
bcg1/qAv1XDMSdzMf3EcwmyuF3EniUTjU/cefYRgx4tWhVGOMr5JsGBnGUuQOh7TZn9I6E489dce4PvMWbT5tM33rQ8MOookk3cAbIUDwBUi1J2eZAV6sXAf
gG7IAvc2anIy48RYdncre0xYb9Qbe/E1atCy4gAfsWiD4JgNTVMyP972Fu5YT9XePVYgD4YCiJjxqQa6HmaTq0wsib94vryIHPyYGwuyEHhiOfb3izwZr+pZ
8bkMh+49/icx3JgNLAeZXqL7zMxlboGxWBHBl/mZUeuoz1LgOsSttxQaMRoBEcSgI2gyxZAUwL8QGepC8WxswGK0ha4sGElbhuuvNQMskhEggNxC2AsC/Jmr
DmXHkFNzf7v/AFMQhqaMDtYjnSsqNuX3XkD8xutwafUaV85TZlUdr5/M5mm1DYwQGIBq6nUXIMuLbifGA/DBh5gc/S6Y5DuJ2oOCZpyafLgpkO4eGEsYv07/
ANX7kq/tML9Ui7kB3KffxAxqCWo8fmdTGQNOq5KYDq5jfJ6igcd3car/AG1A05tKr5seRRSnvaP9zNrjSriai6MefibdNk3qFPjqc/XjZq3HNGiLgJXudfBn
VwoFEgUfecYmO0rlchFbgRTD4gdTMjZCD2kRr09PAhF0D/uPxZV9OkPCnmONOCrAFT/uB5x2smUj7GDHwfEPV4jp87Y25rkH3EzloGx9blO62sN2CJj381uo
Si3EAwCzZQQoQcjgt/1fxM5Ykxh5i2ECw7AUGIH5mz6dqUwZWOXcVYd90feYI3DjfK+1BZ/NQOrqdemRWXEgF9N5nNZq8wjiONtuQgfAIM14MgATGqKQGuyA
STA5rubi7JM7Ws+j22bJhJUAblQCx8icYIwvg8Czx1A0YdFqc+Pfjx7lN1yOYnFp3zZQiLZ8/H5nUw52wooU0QAIT6ktl3bVW/YVAQfo2cIWXJjYgE7VuzMf
pZQ+w43D1e3bzU7uPUIqbm7quDFZdWTkscAcACBzW0epx4zkfA4UdmosWKJBozoHVOHJxsRNujf1lbDlplYVR8CBxt4Aiy+6Vmxthyvje9ymvzF3AbBJlKYY
EAL+IawgsLZAySSyIBNQClgxYNwqgOVq8xi5SPMzjuFcDYdQf7bAqu4G72mcEwlJJgaUcjzNmA7pgUTXgpeYHS067uuDMX1Fi2sYeFAWbdPkAFxf1LF6ipmR
DuPDV7QOcORNGiV/W+w0wBMQsdhco1qaPUDdldvQBFKb+8VX4labLT/cf8xWZwwTa10tEwAeYDfqmmOpUZcLAtjBta7E4LWD7T0umYDirJ8zn/WtNiRW1A3B
2cA88df+oHJLGS4stIGgM8QZLsQbgFUNQVHELCF2knu+PiTI0AT3NOmJXIpXsGxF4lNeqQCqnkSMVXIfTJK3xcDrNmypscEqCPfgytVqbX7VUMRTGuanOOqf
YFJsDqD6xPfMA4pid0MsCL6i+zAssZfqeI0YMT4yfWphzRXv8Rv6JNgPrAs3KkDv4r3gZgT4jcYYt33IMZHHkQ8Z2sLEDfq9F+p0uPE+Wswsoff4nAzYMmHI
ceVCrDwZ6vGyZMSEUeOx4M4n1bKubWnZRCDbY8mBzaIhrLYcSlFQGLCgiEIGANcoxfUINAMAwhKBsSQClqsoCMA4gVUJeDLCWYe2hALGfEchN0ItBQjcYthA
24rA95vwk0ARYmPEVx4y+Toc/mZs/wBSyOWXGQqHjrmA04sZzkFuCxoIOob6NsbgAgqemPEw48tfdfPiTJkZ2LFiSYG4ac7iq5EYjwD3A2m6IIIiNNmbFkDA
X8TpOozf1UI+R7QD0ykANUzfVtHn1KIuAKVUliC1G5qx5tiFT34nN+qa3JjvBjcWy/e3kfEDilaseY3TDGrE5sYcEeTVRdQhA0avJhyKgx4lTbd0JjMNuYFQ
G6dgHII7jtlmZ8R2uDXxN1cQEm1B2mr4PzFkGo9hcDbRgINiRbvmNZRKqoFbuJQbmXXEgEA1YzTpnPqoQaIPczATXpcGVv6iodo8wNmo075nfJjcM3/T0amC
yHKsKINETrNjZHGRQSvmuxMX1DEVzjMCSuXkfB9oGjQZ9lIbN+I7X40yaPKcaWe/sHJImPRKGyLzTX3OjmyHCRtFbuTA82eRBqdL6jp12jUIu3caYDq/eYKg
DLEICSoHLIMsDiHUlQIOpRJuEeBBPJgECajFaosQwOIDlcmESYteIasL5gHi+5wt1ZqzN2NBjylCymvKmxOUz25I4EnqH3IgbNbqAzkIftHAmMZeYt3swRzA
1rlHQmrCysKbgzmrcehIEDoqoBFG50sD+mg8hvE4+FjYm/GSKNwNuTFusqRMuq+npqAGFLkrsDg/maMDhrU+fMmpyHCoNwOAdBqd7KMLHaaNQl0Gc4jkCXRo
r/d/ibWL58hbEjWe65hKuTHlpr3Xf5gcl8bKdrKQR4IixjZ3CqpZj0B5notTo11iJkZ9rKCCQLuY202LToxSy18MeDUDnHS5cdequwnkA9x4PiXkJZiSSSfJ
g1UC4JEl0ZC0ACJR7lywLgAVlVHbZCsBZNvYAHwJpx5SMZG47vHMWiqHBddy+11N+lOJ2GN8OMKRV1yP5gXoc5V6YkgipqzqGxZldQMa2QfmY8GJ8eoCEfcD
5nQZfUTIP7Wargc6vRKFWs1f4nQyU2nDAcNyL95k1GDblUVS0Bu95swqBgUEkgHsiBzfqJfGVxX9jANMM1/VDkOqvJVV9tHipjuBcuVclwMFGXUaFlOICzUq
pTAygT5gGKjFAihGrAhNwblmSoAGVDMGoFBbhAVItxlWOIEUWI5F5ikmjHQNwH4kJmxVY9cxeEqyigLm3AlNzxUAcCMMlsCABZgZkyZc4BUsvYqb3AbG1NtJ
FXMpGTCoXcaHRgFh0wxfeLDDsXxL1WP1ArKCxXwIlcjI24En+Y7FnLkKVHPmAk6g4l2Om0j3mLLmDGgLHvOrnwDMhR7sftacnJiOLIUb9w9oCiIJ4jagOICi
LgkGMqSAAXmGBIBCECVLqXLAgDtjMZKtYlVJA6OHPuINDdVXNZL7wK4rucvSvtfnkTp48o2WeAIHLyvkbIVyWCCePabdI6tj2PZLTA5L5Gc9sbmrSkIr5Guk
F8QOf9V3LrChIoAbR7CYwYefK2fM2V+2P+IuAQMu4MuAndKPMAmWJRCIO2Mq5e2QAqmEBUMUOzBY35gSURIIVGoAGWAJVSCwYBUBJvAgM3MAwH7wIxLbkTKI
3Fk2sOYHZ0i5E/Y+Mn2vub1yHKrAisiiczFq8VDJsVX6avPzU6C6jA+2m+8rR2wFHIT5jMeZqAamX5mTUI2F6PIPR94Ayt4MDo5Fx5XJR1B9pnYFGo8ERWNi
WHvNGpJGQWvO3mBq0+QOleRB1aDJiKEjceR7zEjUbU1Dzanbp1pjuB4JgLAwg0yWPfdzK1WnCKHx2UPBvxM2TK2TKXJq666mrTZVAK5CCh4IPmBiZZW2djHj
0+3eiAA8GLfTacsQVOMDpg3cDl1J5mp9Kw5xMMoBo7fESyFWIYEEeDAAGGJVSxAKpe3iUDLBgHhH3Te6/wD6b17RGjx733EcCdBl+wgDuByALNTY9Yvp2XdS
/ae/MpNNsyDefx8zN9ZyFcaYgCAeWNcH2gciQGURJAMSwL6gC45RS3Rgc+5A1GLuSUM38y/VMSTKuRDGcmUGMXcvdCn43ox4a/MxAwlciBq28yEcRSZI4EGA
kizKjil9SjhPdwFSwvPEOqHMrdUBiXNOBmDKQaImZWBE1acruthY/MDs6tBm0QPbLRBB8zPg0iPjFuRk8jxAxapFXYcYa+7m4IjouTHSmuhAwshxOUbgialf
HmVVckMBW7zG58C58YPAbw1TFlxtp8n3WV8N7wGZ8WNMig2Aw8GYNXeLKU37gOQZeo1DO5Nmib2zJkYsbMBga4W6JUioQMDdhyt6D0pNUT8R65mGa8ijaeCB
U5gM04mZEP2AhxQuA8YX3uFNqvZB8QtQoyj1EayqgFT3+YjEThzCyRR5InRXHjOU7WH3LytePiBzKlETfl0iBAVcAjgk9GZ8mndAWBVlHZUwM9GTkQpdQDxO
wPBm7DmN1uNV5mAD2mrS4mY2bA94GtchZLrriZvqGN82NMYFk2f5m3GqhaEhUM3IuuoHGT6W70GZUH+TA1v05dNhDK243yTO06ixt4P+pzvqmRMmlFq6kPSm
uPzA4wNSzlYjbfHtBaAYGCyJe6QKY3BgORjVUOTCFXJOvp9Djy7ldaUdER6/SMZcb7Kf4MK4Mk9Fk+j4EDNhx7yRwruaE5+X6RqFyttVVTsfdcDnQrhZcGTE
LZTtut3iLuAYNRqPzEQgYGrePeRsgA7mbfJdwG77g9mCOoQgMQ0eY5SYgRiwNmmKtkUP1c3nP6WQjCePFzlIwEcjcwOni1LEEMfxHapWbHjIVn9wJm0uLdyf
4m5m2IoPHNQPPZSd5Bs1xzFNOj9T07LqDlCfYwB3Dq/MwEcwBXGztSiz7QmVkNOpB+ZBwYT80SbMCLNWBWdgFPR/xMyzXiz7CNoFQNv6Mu1tk5r2k/T5UUOr
7mXxEfrXJ44m7DkOXEKb7+yIGDM5ZubB8iHpX/rgHo8GaNYrHBuKg0e/ImbTMEyhyLqAvPi9HKUux2PxF3OhrkGXGmTGCxuuPac+AxOxOlv9PFj5FeZy1NGa
ELZFIFkKLqB0MeRW6hA8tyLE52LIVN+0aM5ux3A1iq+7uRgjYyr0Vbj8zOuYN+7uNR8bmhVwFHQYP05xqq3/ANVCz+Z5zKhTIysu0g8j2nqyduTnpv8Amcz6
tolKtqMfBAthXBHn+YCv/qNIpAG80KNt/ubF0unCkLiRQfYVEjIfPmEMhgN9FVFY9q+3EvYRQJv5iWykCCc4X7nYADsmA93CLuJNeYD50XEz3wFucv6h9Uxt
p3xaeyzfaWripxvVcoU3ttPi4B6nVZNQ5LsdpNhfAiQYJliAYMsGBJcA4QgCEDAMQxFAy90BojFMQrRqmA0dzRiqwT1Myma9IxD2OeOquBtw5tlEEke0fmJK
o6k0SbBlDnGNyEYzR4/tMvdhRAVJLDoGA/PuOlZVQsSlAD3nAyIyOVdSrDwROp+qdvtHjmOy6Ua3EhZqZSaMDhgAn5+Ie2+VBM6iaUpp0UpbqxIYGqixoyjA
JlDX46gJxaFsyApk58/aZeXRZcSb0t1Hf2kEfxNa6psIIda2mv5hp9Rxs33Bh+IHKW7mzTOUyK3tNmbTY9QobHSk9GuIvT4zp3rKg58wNGorLpm5rz+ZzkPM
6eTEmauaIHE5u0q5U9g1A14M20UbrxMepCrqXC8C4aZ8eNwWBavaZmYsST2TcC7mnRZAmfk0CK/My3LBgdBtKbtW+w+fMptK/wD/ABsG/wBRK529Psk1RN+I
WLMVYMDzABlyA0VYH8ShkKngmaxqXJviozPgGVAFIXmzAXh1BcKpFkeZX1ZXfSfZVBgWHvE4rxsQfwY9dWqjkcQMdRuNOOYYw31JnP6fTvk72i6gcX6pmdc7
Ykc0ByBML5XdQruxA6BMvIz5HZ8htmNmMw6U5wwRgGAsA+feBmglAeeo5sLLiGXjaTXfMXAAKPMsoK4hVCrqAkgi+JKmzT5DhybhR9wR3EZUX1CyKFVjYUdC
AnqWDNOHT+oDbAeIjLjONyrCjAly4AMIQGLH4wCRfUzrHJ2OagbTp1OP1cbCr5W+R/5mrSjHjHqc1VHgdzFieuI4uANt/MA3ykZSwuva4PrExRa4BsGBt07H
fxxfc69nDhJXkAXODiyhPBv3E34NWFWsg3BvmAf6ph5qC+Utk9cChYuo3H6aKwyYgUPv3LZEG19Pt23RB8GBi1jDJk9Rb5AsH3iU7E16/FTq9UzfuHzMwFQN
mPVFEVOgDc6KZUyjwZxK3ETXp2bHW0c1A6Kqh5Eya7Ai4y62GPPwZpUkhCTTH/chZjlKmtpHR8wOHckZqsXo52X+08r8iKuBdy7gXJcBlwlPMVLDUYHRxhdo
o2Y5MlGc9MpWq4jky333AbrW2ouQLyTRM5r5iZv1L79A4JogivmcuoHoca2LmD6kurZHxYsG5COWB8e1e86SEHqHA8UV+KlqxQ2pIPuJ6fX6DHql3gbco6I8
/BnK1H0+sW5U2sB1d3A5eQ2oXmuzFVGkStsAJdkqB4HULbKqBQkPMuSA3BlGIN9tlhQ+PmZtSSzbj2fMZKcBlIgZhDEoQoEBjUMeh02THtyYgh/6lNGZq2k1
yIGhW4hFriFaHcBu6WDE7qlh4DQYavRiQ1wlNGxA3DVP6Rxsx74v2l48hsC+LmMMSeTdzTp79RSRuAPUDZr3JOM7iVYWB7VxMwM0atGLpjFbFH2n3iGRsYp1
q/eBYIj1zFANpmPdzGIGY0oJMDbi1LcBzfN3C1WQLqAxJ5UHgXMQNS8mY5GtgOqgbCuLWgBgUKjhgf8AtMGpwNp8gUkMCLUjzH6RmGYbPP8AxL+qg78R8FTX
+YGG5Y7lSQDPUHzK3cSXAMfmNx5NpuJUkHjuEEYLdEgd/EDRlyH9KdvIY8/ExEwmcbaEUTA9EcwHUYmTcASe5zd5j8bHbxA3XFZaKsG8iXjJ28xepYhfzxxA
8tlWnI+YE6S/S9TnYtaKPBY9yD6XlxavGuQB8fBLDr8QObUqp1fqmhx4sQz6dCq3TKOh8zlmAEksyoFXBduCIVQGgLhA0QZVQgOYBFibJNk83KuSpdQLBl3K
Al1AksSpYgEsaDFiEIDFPM34QmNSMu5G7HEwIOZrLs9X4AFwNW8NlBskdx2f0mw0SARyIrRorG3NAf7hfUcSqq5UoXwRAw+Y7CGNlTW0dxFxiOQCAxF9wCMm
3mQQxA16XEwAZQOeCRM/1Qr+pUKbIWiPaa9GeG+JWq0q6kl1aslVXgwOTJBkuBcq5JRgEDDbPkZAjOSIkmVcAiYJMkqB6D9OnJbH14BqGMATnGbH/SYWJtw7
6jAACT7wEZs64iFJoyi+4cyavS+r/UxnblAoE9EfMTTIu1mBPxAM5aMA5WduTxAY8QbowNebBjz6X0s17TzwebisWg0asrJhG5eiTcEZWrviEmQg3cBer+l6
fPudbx5D5HV/icXWaN9K1MbB6PvPToSwJPUzfUsOHJo2fMpIxqSCDyDA8sYJhmARAGpYkqSAUkG5YMAhLlAy4EkEuSAUJeYEfhbYLH7jAZh6IoEmaca1w10f
aIT3mrDlBNMIGzSemGCgnn3EDXkBNgFi+Lj8eFdyPjPB5EyahMmfKzIGdQaHwIGSrNCak0ZKblyAkcsv/iAmFgxLgrXuJWXJs/a1QNeFMW4qqg3x9xhanTBF
D4xQ6I7qcwZbYTs6UDLpmUsSD/qBjXIy3Rq+DHYHYutHm41m9G12Lx7iEGXIN6JTLXQ7gcTU0NTlC/t3mv8AMVc6X1HSF9QcibVtbN+85hBBoioBXKJgyQLk
lXKgXcomVKJgelxZVB2qoCx4cFitciYMB5HwY0ZA+UkNVcD5EA31BRiG78iZjlDmqqM1JHrAEeOZF9M/2j/EBDWOaNRuDY5NgfzG/Y42lvjiV6HpNwbBgZsg
Kmr4hYzceUVqvkXGrhxDkDuAWJ7pQOJepxjLpsmK63rV1ci0o9pfqKPMDlfUNPptN9PdRhG5lABA5v8AM4Wxq3bTRNXXmevZkygq62pFEHzFLh0+EIiIAF6g
eSZSrUwIPsRUqp6bP9N0eoLGmTI5vcDfM87kTZkZLB2kix5gAuNm/bR/mVtMZjIDAkXUZmyo2MIikc2TARLuVJAK5cC4VwCEahqJEYsDQGZzRY/A9o5UIPER
imtMijsfiB1cAH6UB2K2PHiIy51wDYj/ALR37zHk1ZZuDQ9vaZ8mTdzAfkz+obLEn5icn3CI30Y3HkB7gUoozdi1uRFCrQA+JjJEgaB2lzYtSn3cN8QULYcp
W+pzMOQg2LnUIGYrlxm74P5gPy4l1GPmxYnD1OkzYnf7GZVP7gJ38YKpRriRyAhvojxA8ymLLkBOPG7Ad0Lh/pdQUZ/RcKoJJIqdhHTFi9PCtAGyZF1Dbrb7
rFVA8/JO6dLpdQxL4trEV9vE5Wr0mTTu32k4w1Bq7gZrk7kqaNMgXIGfHuX2MDs5Mfp6bcpiENOpI4M05iP0f/EwB66gNdw+Ynpbr+JbsP7eokNLu4D8BG6z
NOpLEKVsgd1MIdUFnkyHV5CeDQ9hA0KHuipBmgOFAXixE6fUbz954jvsyEUYEysCl+ZnDc8x+VBY9qi3wlU33ANKIuJyODk9xK5PEPHi+4WQYAaljh0GbLzw
tCuwTxc8wZ6j6tlXH9NyKVJDfYK955gwBkhou6/gQDAklEngXJCxuUJKmiRUAYQlQhAsCMUQBCBgNU1D3cRIMK4BkwCxuVcnECjzLQ0ZUggNBuEDzUWty7ru
A/HxN+HV+lhK8brsTmK8YDcDofqnYr91zoBw+PcSK8zjY+PM3YVL6YhCLLc37QGHamnc13MyPuJ46FzR6DsP3gAdj3jUxKqkilLfzAVhvcCO4H1UOdKw3Vj7
PH+o4rsYfdcZmxrnwFGJCt2R3A80iWwE171WqbqPxfTSuf8ArUcYs8eY/P8AT8WXGDgAxOvR8H8wGaxVGnUixR/zOfOnl2vhKE/+pj3jFQUD/EAExZHXcq2P
zIUZK3ioQz0CZny5i7WYF5Gs9xVm5RJMgga8OZVBGzg+5mkanEqA7funNBqUWJ8wOsuqxvQYfio/IynGASAJxcb1HPlYqBuBEDaRtPvDUMDfE5nrN1ZqacGY
hhZ4gP1el/W6b0/UKUbFdX8zzmp0ubS5NmZdp8HwfxPV7wKK/mL1+NM+gyhwDSFgfY1A8kCQeJRkqVAkkkq4BS4Mu4BAwgYu5dwGAwrit0K4B3IIIhCBcYoi
4YgEa8SVcgUmGEPtAoACNT8SlQ9EGbsWnAauDxASiira47G9EC6EDIRuIBggwNx1Jo/MX6hJEpEBxE3yJeJAcguBpUluSLjsfA5ivUGMVUFc/PUBmblbTmva
ViuuRDDAi5RII4MDFkdVBBE57vzxHajNu4HiZSbgXvMq5LlVAKXdSgDJUCXJLHUriBFuGAZFqGBcAQvM0YULMFHZiws3abHS+oe4D2UekPjqFjIKFHFg9gxg
2lYrIQrrA5eq+hWxfTOAO9jf9jOLlwZcQBy4nQN1uFXPX+uo4EDU4seswNgyDg9H2PvA8dJGajDk0+Z8OUUyn/PzE3AKXAuXAu5AZVyCAUJTF3zDUwGgwlgr
CEAqhAcwRGAQDU1NGFhuAiEHM343xlQCoseYGzCuxboXKz5AFLEAeLEytqCBtBi2yb+zAUx+6Glk0O4JFx+mYI1kXANQwHMYrBPu8w8zbqCr3zxF+jkq9v8A
mALOWNmFjomyDQ9oOJ8IenO7/gRpwpkP9DIAT/aYCm1D7+OK8SjqHDe1+I39I/nIu78cRbabJuJAUt/0kwOcTcEyGVAlQhBhCAY6gnuS5YFwBJMgFiNoSwsB
a3NGNTUiY+ZrxYxY4gDhwbmBYcTeAoFHgQCCpBXoCDnIKBr5Hj3gOIpbU2Jk1OX7lEZhyHhfFzPqgVzUeuxADcSbmrTtbC5jBszXpto5aBxP/kOIrr/Uo06D
n5E5NT1v1nCmX6fkYYwzoLUgcjnmeVaAMkuQQJUvbJfMuAO2QWIUggEjRoMQeIaNAeDGKYpTGIeYDkjAxHmLUy7hBlrkHcEQxCjEfh2g2zUIGHAWYWaEvOFX
IFsD/tA2pkx+HPXkTJq9WpU48Z/JHmZMmegVAH5uZ7LMK7PAEBqsQY/FlZSGU0Yl8GXER6iEXz7yA1A3LrH6bn+ZuUplxhh45BnGU8zq6UBUrnnuBw5JJBAg
hSgJYgWIYlDqS4BXCUwAZYMDTi5mzEQo5NTNogHfaRd/6mvLhIo3xAr1CQQDDyYy2IAVQkGFR01GWoZGomxARjB3hRB1rq2VQvO0czWmMDIWBmPUabIhsAsp
8gQM4MfiPImf4M0YexA1aosuizMjBWCGifxPHGeyzYE1GmOJyQrd0auc7N9C055TK6fHcDzpEqegf6BiY/09QwFeRfMwZfo2sXNsRN6k0HsAfz7QObfMK47V
aLUaQj18RUHphyD/ADM8A5YgCXcA6sSAVIvMaoECIY5IIQdxiChAMS5Ufiw76Y8LfmAWDAHUliQK4lbQDwbmj9OyLvV7W6I9pmbiyIBNnGJe+fExPlLOW8nu
VkYs0pEJgVyZs0JCOXYWQKH5mcLHI5Ra9zA7GB0yYwGAsTHrNE65N2FSynwB1M+POQbBI/BnR02esZLHiruBy04bkTedSMaqEoNVEzLq9QMmUuqBfx5mfkwB
IINEdSCb2+mvtyMcoZ7sUO/zI/05gqnG4J83xAxCWBDzYMmBgMgAvog9wBAKoJhSjAg7hqIAhrA6GgoE+81kk4RfJJmPTBRiJ/u6mxWraBVQI4vb7mUzHeEP
iMNEiwbEsrdGAvK+wge4hYcm7i5n1bf1APYQMRJYfmAWuxU4yAd9xenXnibiQeDzECsOSh13AbkO3EPzEeqd4JMvLlDigIgmvMBr5SrUaI9o3Hl3CiK+ZiOT
sUILZWPF8QOk2PFqMLYsgVlYURPJ/UNE2i1HpswYEblI9p6HTN/UEX9Y+nrqMbajGrHMoAof3CB5oLC2wipVirAgg0QfENYAqpEcqylqMBgUBRjBKEYB9hoW
bgDN2mZBi25evFTCZYYjzA6u/GiWHu/E42bKSzAHi5Hym+zMrNzA2YQtFmI4lHInQFe8w7yPMJWgasmRb+3gQN5J7igbhKYDg804tW+NNoIodcTFCUwGlrhK
airhA1A9Bk4JghhdExWbUAAgC5kbMWMDdlfEw2sAw+Yk6XTObUFfgGYyaM0YH3EDoiAb6BCP6bEH55ExOjIxVxRE66njnuZ9djDIMnkcH8QOfUNVPsZVR+PI
EQj3gRCUHNiOTMREZMhc2ZQgdHFqN7EEdxiZbbqc5SR1NGNia/5gFqVJyk1weoeLFtWzwascRgNEA8xoYXAzYyfMvUg7UIPEbkSzYicrD0qPfiAgHgxTtLLR
bm4AlpAbgGWvcDTp32tfmahqbI4/MwLHYVLuAIHP+vbBrEZf3HGC3+eJzQ03/W8GTHqVyu5dcgocVtrxObAarwg0TLBgaFf5jkejcyKLjgKEBjN2YlspBIhE
3FN1CKZ7imPNwiDUBgYULdw16izGJ1AZLFyhCHcCc+YQlkXIFMA1MYoBiwKjB8QNLG5Qm/V6Xc5fGQL8TAwKmmBB9oFnmFjNMIAjFgbkyWkMuNhLDgDmZsRJ
+2VnzLsONQb8wMsuVJAh4PEJTBliA5BZm7AlLuP8TFhPM6IYMlD2gW33LY7ilc3IGIgj93EDSrgiBlUZMbKpF+IlshU0JePJR5gYnVkYqwoiAep08uIZ8ZHG
7wZzWUqxB4I7gLMvYyqGKmjLqMTIyigeIFICeAOZ0MCDHiBPZ7lJRCuQN3/MNmXrkVA4/wD8hP8AUwC+NpNfzOPPR/UPpza3KjrlCqFogi6/E5Wb6TqkyuqI
XVem4FiBhEICDyDR4kBqA5aEMmIDcwi+1bMBl8RZYExRyWZA0DSpXs1Uz5X3OWkYkpQMSYEJhoYomEpgPUxgMSDDBgNEYsSGhqYDxUMVFKbhwO4hLYzZ8TJm
0rud4Nn2mtaWyOpSuN3xA520g0wII94Sia9SFO01z7wUKkUVEA8GLgNEazAMTBl/a3+jNaNQ4i9Yd2nPwRA58kkkC5JIa8QLSwZuxZAii5mWmWj3Ka1aruBt
3hjLZABazKjmafU/pfiApl5uAbuAc1wlYGBowMd0z63FsylgOG5/mORgtGH+o+BA5sPEhZwomvLpxlx78agN5AgY9OQpa+QLqA1gyMtcjxLbKDe4UTFDKzUA
OvaBkJ3Ue4D8ebkA9Rpbdxdc8zCA6sDtPuOJNZqn0+nfMF+6wFB6swOBrN/6zMHfewcgt7zPZh5S5yscl7ybaxRuBuqAS3Ayv4kOSop2s3AINC3TPvk33A0b
+IBbmKswg0Arlq0BhIsDQphgxKmMU8QGgw1MTcZiP3i+r8wNGPuMewtwVA5oiUXB4viVHbx5eIRIYDxMuI8xx4G4dSKvOaA9opfFQcjgmUjQNdELxE6jJ9mw
ee49GBXuZtQPv64gZ5IVSoFS7lS4BBo3deM89REtTAfirtjQHvByZNx468RbNYAHQgk8QCuoStEmGncB+4mTdzKHEpjA16fKQwF8GOumJAmbSryWNcR+4OOO
DAYFxt/aLk2oGJoXM/qemD7xDahi/Jgb2cCQhCQ20E/iYfVvkmH642Eh+R494DdRptPq0rPjDfPRH8zh636JmxOW049XHV/I/wDM6yZb8zZjcNXMDwmQe0Sb
nq/rX03SnBk1K/0siiztHDH5HvPMMsBNSoy6FQCLMCoQNQOpCYBl5A3EVCEo0KZs0+1gQSBx2Zzw0YrEdGQaCNvB8eZatxQi97EAHmuBJRWA9XI8wg9zPuMg
cyo76GjDytagXLxIreeYGag3EighrFw1gPxtZqOKb1oxeBfJjro0YGFhRo+IMZlN5G/MCBUkuVAsCzUhJFrxKkgSV3IxFdQbgXUNIAMIMBAYWkLQeCOIJMqN
GPIR5qGMwXqZQYSpkyfsUmRRPmtrNQT6ZBO8jg8fMVkV0YKysCfBEWWN0YBeo3VwgxvuJJ5hKYGpDU2YWJIAmFDNmFlRGJ7IoQH6jGc2lzY0IDOpUTx2XAyZ
Ww5PtdTR5nscTcWTOb9e0uPJpTqV+3JjIJ+QYHlnx0e7ggVNO2xzEZFIaAvJBIhEXDXgQM5JlqZeRRdiAO4DljAYlTGAyocsYASOOamffQmnTYNTmQ5MGF8i
qaJUXIqjwOe5VEixL1CZcbBc6MjHoMKMHcwx14H+jA9HiPdwcv7uP5jlVSKEU4pyCbgCoj1QcQEqPUXANBJtJBswlFdyXAzZMJXkcxVH2m7gyjjUiqEDDKmp
9OLtZQwHihz8wMpkuaG0rEk2AJWHGoYhgrfmBmJkXvmb30mJmsAr8CY82M4nI7HgwHHEj4lIpT5k/ROa2Ohv+Ij1ftC+xuOx5jVg9QKGDKnDIZHQhboD89xz
aw7NvZ95mbMWJ+YExhSxD38VNeLLjQgEUo8CYd0u4HWTUY381Ur08Bc5DjUluyROUr1NWHUnhWoj5gNOh0oNfd//AGmTVaUadgyElD79gzpna3Hv7RGrxjLp
hV7gbFj/AFA56tQmkZwMW0Dn3mS6kDQNuPMb5mhl9TE68Wykc9TDh7s+P9zah4gePyEoSrdgkGK77jfrDhfq2oUUBu8fiZkyCATL5gwy4qLLXAFhF1zDY3KV
Gdwq8sxoCBBH4MT5soRByfJ6E6I+if8A67Fc+7KBYG3j8f8AuJ+lnYuRmT93AJ8QNun0iaTOMjhMn21Ro8+9eJvxagepuJ22bJE5+QsfvJJB8wsRs8mB6DNh
w6rAd+MZFcUT0anJ1Og0ulWsYu+wxsiaceoXGg25OR4mbPkGVyxPcBivQkJJNmCOIQ5gGgmhQRXEViWzNiilgLY1xAuHkixAIH5lhoFyrgO3yB4q5LgaFa+J
k1FY8tL55mjCfuEw6hwc7kGxfBgasWoG2nF/MccmJiLUEHsGc0NfmMXsQG6nRJYOFqLdA9TDyrU3YPM62RN2JDu5WYNZh9I+oOmP+4CWKUxBI9hF7jF5HJYk
mzB3QHhoV8RKtcO4B3DQ8xIPMYpqB2MLF8QNURxLygjEPtJN80LmDHqCFAuacepLEC+YGFsY3mgQL6qCce38TrMqZwD5/wCYnYACtXAzIV2AAStflzYvp2bL
gQNkRbFnoeT/ABIeHI9oOq1mPSaPJkzLuTaRt/6r4geIfIz5GdzbMbJ9zLGSoon2g3A1DJJviA3EsNAfulb+YrdBLQj0Wl1WZNOuXklgaJ94nFaIoIo+a94j
6fqFyYhj/uUf5ml+IVoObGcW37rHQgjJZsgD8CZoV1A1eqPBk9YATKGl7oHXjcaM3QiQZowNTCBoRCo/EaGlqQRxBb7TzAXk7MCQtZMq4EJg3KYwSYDLhAFj
xEXNGI+3cB+JdqE+ZytYyjOQoqhz8zrOp9I81YnNy4Rly0GO4cEmBmV6MeuWUdDmCMeCR0Ae4gGuPMDcNQfLGE2qUptYBl+Zz90otAmXaT9q7RFQieYJPMAh
xCBgXLBgMBhgxQMIGA5TDViDxEBoxWuB0tMWKLY4vuMZhuJEXoiCtH+JVfcwHV8QKyIpF1z7znfXdC+q+mkYApbGd9E1YHc6TftkUbgR4IqB85PvBnptV/8A
F3otp8wbzTeYn/8AGcx0gf1gM/JZCOK8AH3geel8g9Hn4nS/+l1iMPWx7U3UTfj3E9HiyrjRUWiqgBQQOIHkf02oGMZDgybD0dphZ9JnwIr5UpW9jc9ecm6/
mYM6HMu1kr3BFwPMqSrAg0ROnp3dqUKaqzZ6jB9Lyu75MKKF3cIfI88/9o8Y1xqFCgEdwBAqQyyag9niBJLl1BYQO2UocRmOxBxP4PIjxt3GuoDcRIl5m4Hz
CwVK1Kf3L1/xARJKkgUYMOpa4yYAou4/M06dCHFjiKC7DyJsxci4B5AWQhe64mVNM1sSfu7r3ml3C9xIynftBsA8GAH9MfZkLA+fiYc+nxKhKOdx6s3H/UGI
yoa7Xv3isWaiAQCD4gc8miQTJcdrMHp5dy8qT/iZoBE3KkkgQS5UuAQMsGDUkBgPMYncSp5jscDqaNbWyaELIoxvQNiZcDvuCqaszRluzffUCi1mh1CBANRI
auIQMBxe+BKi177jVq4CNXhGTHfNjqpwAzY9Rkx5CSAbDAcGeqG0iZs+lx5L+2r9oHMwkcRpUH938QTibESNpAl48eQsCPHPMDM7tj4FcdzJkYu5YmyfM7Gb
SDIoBFE+RMeo0Dpygse18wMNX3LCiWQV4YEH5kuBYUR2PCO+/wAxC8makYBRZhGlRQuPQcA+8kkKeDXUYpJUi/EkkDNLAuSSA3GojlHNSSQKK7nqOQ7eBJJA
OgQfmZmw+m4o8SSQEa9AcK5P7ganOBNySQJkyM1biTXUzv3JJAES7kkgQQhJJAsSSSQDQ/ddXGoeZJIGrAaabchsE/EkkDGTzKLGSSASMbjAxuSSA9DGeJJI
CcgBBBigADQEkkArkKgySQMmo0GPJlDFmG7ihORrMX6fUtjBsDqSSAONtpurjQTtNe8kkD//2Q==
]==],
[==[
/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAA0JCgsKCA0LCgsODg0PEyAVExISEyccHhcgLikxMC4pLSwzOko+MzZGNywtQFdBRkxOUlNSMj5aYVpQYEpRUk//
2wBDAQ4ODhMREyYVFSZPNS01T09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0//wAARCAKyAUADASIAAhEBAxEB/8QA
GwAAAgMBAQEAAAAAAAAAAAAAAwQBAgUABgf/xAA7EAACAgIBAwMDAQUIAQMFAQAAAQIDBBEhEjFhBUFREyIycQYUI4GxJDNCUmJykaHBNHPRFUNEY/Dx/8QA
FwEBAQEBAAAAAAAAAAAAAAAAAQACA//EABsRAQEBAQADAQAAAAAAAAAAAAABETECIUES/9oADAMBAAIRAxEAPwAkYhYxIigsUKV6OAU4DfTwUnAtRCcAE4D0
4C84iCkogpRG5RBSiQKuIOUBpxKOIov0kqIXoJUSSiiXjEsol4xJJhEPCJSMQ8EBFrQ1XEDWhqtER6ojtMewtUh2hGTDMVqJmeoPhmtr7DI9Q7Moq8znd2Y1
5s53dmNf3ZuMUlMFINMFIWQ2VLsjQhUukQkXSIpig0EUig0EBEriN1RAVocpiBM0w7GjjwFaIdjTxq+wUw3jV9jWx69IVxau3BoRSjEzWlpNJC9szrLBWywC
xoINFA4INBGqyuokShwEii7jtASFkBecTQsgKziIJyiClEbnEE4iCriUcRlxKOJIDoJUAsY86LdBIFRLqIToJUSSsYhoIqohYokNWhqtC1Y1WBM1IeoQlUO0
hTDevsMj1BcM2FzEzM+PDKGvKZq5ZjXrlm/nQ5Zi3x5ZuOdZ00CkhmyICSEBNEaCNEaIKpFkiUi8USTFBoIpFB64kRqojtMOwvTE0KIdgMNY8Oxr4lW9cCWL
Vtrg3cWlQhtma1B6oKEeSttpW23QpZZsGlrLBecys7AE7CAUA8BWDGIMaDMAqW0Bgw8QIVkBWyI/OO0K2RKIlOIKURmaBSQgBxKOIdoq0IL9OnsMobWyGg2P
Hri17okF0E9Ay6n8EfT8EgOktFBOg7pJJgMQAxWgsGBN1scqYhXIaqkBjRg9oTzI7TD1z4K3rqiReZzq+5h5MOWenza+5hZVXLNRisayPIvKI/bWLSiaZLNH
dIVxI6SQaReKLKJeMSToRGa4lYQGqqwItMDTxqttC+PVtrg28DF390lpIDDOFj6XVJcDVtyXCBW3RhHpj2FJ279zLQs7d+4CdgKVoGdogSdgvZYDnaLzsIG4
SGISEYTDwmJPQkMVyEYTGa5mSb7oXtiGhLaK2rgkQsQGQxahaYhRlWRJkdQhzCY16x71Nx64601vWwTZVsk11m4U/wA6rIPxpllLCs/DIin8TWhbHxf3jGjZ
FeH+qKzwZL2ZE7+59a3XKM1/pkmCnjzj3i1/IReNZB7W0/BeGTmVcRtnr4fKJDfTa9iUtFY+pT7XUQl5XDLrKxbO/XW/K2iS8ZaDwmBUIy5rnGf6M7mL5BH6
7AzntGdCzQaNvkDoeVDezGyqu5t2SUkIZFexgrz11XIpOs2b6uRKyo0zjNcCOgclUV+kQLKASFYZVhIVkVa6xymrfsTTS21wa+JhxhFWXPUfj5ApwMNy+6XE
V7j9uRGEeivhIVuy010w4ivYVlcRMTt37gZWC8rQM7SRidvkBO3yLzu8gpW+SA07QE7PIKVgKcxDShMYhMzoWB4WAmjCYxXYZsLPIxXZ5ItSqYdvcTOrsG67
NozjQNyE7B+7lGfd3GACcgfUdYwLlyIFcirkD6ijmSen/ZXJrdt2LbrUl1w/Vd/+v6Hop0Y8vg+c4+TLHyIXQfMHs316s2k1ILDK3rMCmX4tCV3pi9kKV+qv
/MNV+pKXdh7JK309r2E7MSUfY9BHJhYuSs6q5otGPNOqUXtbQSOTfBactr4fJr24kX2FLMTXsa0YXjlxf5x0/AaN0ZfjJMXnjtewGVUkSaH1fkpOaaElZZHv
z+pP1d9+CxatbFMVsrQaUwcpbJFpVg3X4GtNvhNlljyfM2oL/UyRNVcjWPiTtf2x4+Q0XjU/Nkv+EVszZSXStRj8IgchGjEXtZZ/0gNuVKx7bEJXb9wcrvJI
5K7yBld5FZXeQUrRxaalcBlaLytBuwkPK0HKwBKwo5kBpWApTBuYOUyTSjMLCwRUwsZiWhCzyHhaZsbAsLATWrtGqrjHhb5Ga7fIYWv19URO9dzqrvJNr6kB
Z9rF5SGLloUmxZd1FZSKNkbFJci0chxSW+wFlJb1wSPQyn8jVWW/kwlYw9dpYnpaMx8cmlTlbS5PKU3v5NLHvfHIWGV6KNvUiJNMSot2u4zvaMtKTjF+wvOE
Q02LWTEByriBlCJadgGdghLikDlFez0UlaCld5JLzlbH8ZPXgWnbNP7t/wAyZXA5XCEO4o7is7IvukBlKPsQFdoN2gZS8lHIkM7CjsAuRVyFCuZRzKNlWyS7
kVciOTulv2JKuRRsPGicuyDV+n3WdoMkEpF1MWUiykSNxsCxsElMupkj8bBiu0zY2BYWAWtXcNQt2jHrtGq7fIE1dHa2hC1aY6p9SAXQ3yiBGRCZecQYpzKt
BNHdJIlcume/ZnQkMXVdcGvf2FYrTEHKps0MezsZdQ/j90BbmLPsaVb3Ex8V9jWo7Ga1EWrgSt4NG1cGfeu5RUlbIWsmHuErWIVnYBlYVnIDKQheVgOVgOUi
rYhZzKOZBGiTm2QXUdlo1N+xIHTJUGxuOO37DFWG5exJnKlsLHGb9jbx/S5Ta+02MT0P/FNaXkLTjytPp05viLNPH9DnJbktLyejnHEwo8JNoxc/1Z8qD0g2
05It+54eKtzak0KZHqVdS1VFIy8nOnNvcmZ9lzb7jg0opFlIFslM0wMpF1IAmWTAmIyCRmLKRdSIm4TGa7DPjINCZJqVWDCakjNqsHKpgVbaxeUdM0dKSA2U
++iRWKL9JKjphox2SA6PApkUdM+pLhmp9M6VKnFpruUWMuuI/jx5QJUOE9NDlFfYlD+LHsa1C4EMavsalUdIzWorauDOv9zRu7GbkPuSrPv9xG0dvYhazTJa
bAyCzBSIKMjRYlRFKqOwkawkIbGqqd+wEvCjfsNVYrfsPUYu2uDVxcHeuA04zcb09y1wbOH6TvW4mrh4CWtoen0UQ4M2tSEoYlONDcktmf6h6iq4uMXon1LN
fPJ5fOyXJvkZBarn58pt/cY11zb7l77NvuJzkbYqs5gpSJkwUmQDJTIJQhZEplUSiK6ZdMGiyZIWLCxkAQSLAmq5jlMzOgxmqQJq1S3oYUU0IUTNGnlA0DZR
7pFYR0zQUNopKjXKJAxgEVQWuHsHjWSJTx+pbS5ReijnsPRqCQqSlv2LVicersPKOonVV6R1r0jLRW+Xczb5dxzIn3M2+YilLpCNrGbpCdjNMgzYJlpMo2QS
gkECQaskZphs0sanbXAlj90bGHFPQNQ9iY29cG7hYi0uBPBrT0buNBRiZbc4qqBj+oZOt8mlm2dMdHmvULd75KBlZ97bfJh5E22zQzJ7bMq58m4xaWsYvMNM
BMQFIGwkgbII0dov0naEK6J0W0doihFkdonRJKLooi6JCRYaEhdBYMCfpnpo1MWezFqkaOLPTQGN2qPVEKqwOHPaRoqva2ZaJunT2gtcdjCh7EOvpfUuxJ0Y
FujQSGmtnSAurt6F0y7ez+AV8+5Wx8CttjS1sQBfPuZ18xi+wz7piAbZCtkglkxachCkmU2dJlNiBEw9bFUw1bJNLHfKNrBfKMHHlyjawZcozWo9Ng+xtQlq
BiYHsa+9VGGyGfZ3PN50+WbPqFnc85m2cs1GazMmXLM61jd8uWJWM2xQJgZBZApEApA2FZSSFL6O0F6TukkHo7RfpO0SU0dovo7RJVFkdolIklBIlEXRIeDH
MeWmhGA1S+wFv4NnKPQYyU4I8thT5R6f0+W0jFbgs69HJDk69x3oVnHTAgyXQ9rsUlIJJ8aYrY+l69hCtkxS2QSyYpbMQWyeOV2M22ZoWSM7Jh3cf+BBayQC
TLTYGTEIbK7ObIJLJhoMBENWSO475NzA7oxMZbaPRel1NtBWo9H6dDhD2VYoV6KYdarp6mZ/qWUueTm2zvUL+XyYGVZtvkbzcjbfJkX2bbNyMWgXS5FZsJZL
YGTNMqSByLsoxAbKSQVoq0CNuDXdFXEflWmuwCdbREs4kdIZxIcSQOjtBHEjRJTR2i2jtCkIsjtEpEl4DNXsLxGKgTTxHyj0vpsux5jF7o9H6a+xmtR6SuPV
WJ5ENDuNzBAsqHcw3WVZwK2vaaG7loStZpknbJptClsxrI5XHcz7ZCyFZMWnIvZIXnIUBfXv7o9/gUY82CspU1uPcQUO0WcGnposoklYoZqhyVrr2P41Dk1w
SHwqXKS4PYej4b4bXBm+k+nuUlwen+zDx9cb0YtbkVzsiNNXQn2PLZ+V1N8jPqWb1N6Z5/Jv23yMgtDyLdt8iNky9k9i8maZVkwbLMrokoyGgmiNCA9FXEL0
nOIFp7OcdopGQRMEBOv4BuOvYc1spKHsxiJuJHSMShoo4kgdEaCuJHSSD0SkX0SkSdFB6lyDihiqPJI7irlHovTl2MLFjyj0Pp8exmtR6LE/BEZUeC+ItQOy
fxMNsbIXLM+73NLIXLM65dzUZpG0zshc7NG0SvXDFlm2MBJh7lpi0jQVCQ7g9BYAl5Y8bV8S+QSxpRlpocpNCmmNqSa/mRZ1GK21wb3pvprlJPpGMD05SkuD
0FVdWJVt63oza1I6mqvDp29b0Y3qfqG9pMt6l6jvaTPN5WS5N8lIrUZWQ5N8mdZPZayzYCT2bYVkyjLaO0SU0d0hFEsoEgek7pDqBb6ZIv0EdA19M76ZIOLC
xYJIuiQ65J1spBhYgQ3H57Ap16/Qc6dlXD5XA6CTiR0jM6ul+CnSSB6SVEL0EqBJSERqqHJEKxumoCZxa+UehwIdjKxKuUb+DXrRmtRqULUEDyJcBl9sBS+X
cy0Qv9zOuH7n3ELjUZJWoTtXcdsFbEIZd0eWhWUdMeyI6lsBKG+RZLaCQRboCRgSEpRp4q5QjVDk0sWHKCmNzAlprT0/ZlfVrbqo9U19r7SXYthQfBt149d9
EqroKcJLTTMtvnWVkuTfJnWWbZv/ALS+g2+mzd9G7MV+/vDw/wD5PNSZuOdc3sqTolIUhRLKJeMQkYEg1Auqw0awsawJdVl1X4Go1BI1EsJqon6XgeVJZUeA
WMJRLKJdRLqJpBpBYdyVAuogl4rZfo2VgtDEFtAi7rTWmuAMqmnpmg69lZU7WhRBVl41jKq8BI1eCQNdQ9RT24Jqp8Ghj0duAtI2JTyuDbxa9JCmLT24NOCU
YmK3I62WoiF8u4xdMQumSL2yE7WHskK2M0yXsF5h5sBIQTyY7WxeMR25bixZLUhCVTsvGh/A5h1K2XR790aNfp8m/wAQtMjMpoba4NTFx3tcDtHpz44NKjEh
WtyaC0yKYePpLg0XZGqArblV1R1Foysv1He+QJvOzIzi4vTi1pp9meH9V9OhXZK3FX8N94f5f08GrkZrbfIhbkdXuajNYyiEjAYnWpS6or+R0azTKkIBoVl4
QDwrAqQrDwqCwrGIVeAIEagsafA1CrwGjSRwpGnwXVHgdjT4Cxp8Bpx4lRLqBFcvZjEYmmA1EsoBFEuogg1ALBaLqBdQIrQjtF/pHVrTGoR6kSKur31+peFP
gbVXgJXTzr/gtWB00c9jRop7cHU0j1NWjNrUglMEkWsnpHSkorQpdYBUumJWzL22CdkzQVskLTkWsmLzmTKs5AmzpyBOQpaXKYrN6kMJid70xB3DvddkZp8x
ez0lXqMHBSWjxddumORyWobTDFK9W/VElw0L2+qtr8jzUst/IKWU/kvydbV/qLl7mfdlt+5nTyG/cG7Wxwaane2yik5MDBOTNn0v0uzImvt4+SQWJiTuktI0
8j0Vxx/qxaU1/g+TS3jem1dMdSmvcx8z1aU29SAlIQ5GK4CccyP1Ny7PuzTp1JJp7TJL11jNdZ1UBuusDFYVDEKi9dYdQ0gaCVaRz1EtOWhW23QJ4WMhiqzQ
jGYaEzo5tOGpLgLGInTZ2W+RyqafcCJGISMCYLYaMSSkYB6lpnQiHhDaAiQhsPGr47rsRQudMdrgBdTBOKYZyUUCcvptr2YGy0Cvbb5ErbCLbfIpbaaGuts8
illh1lgrZYLK05i85lZ2AJzJLymD6gcplVLkgZixTL4f8w8JAMxfbvyMVKdemMVWdS6diTfJeuepCFrJuMmn7A3Y2EyY7amvcAk2SXUmw1Vbm+xFNLk1wek9
F9Id01KS+1cthaZFfRvR5XNTmtQXds1M/wBRowafoY2lruzvV/UasKj93oaWuG0eLy8yVk22wk024cy/UJWybchGV7b7ikrd+5XrNYzpv6r+R/071F41ijPc
qn3Xx+hjqQSMgT6BjShbXGdclKMltND9UDxHovqssG1QnuVEnyvjyj3mJKF1UbKpKUJLaa9zFjcGhDg6fCDKOkAv4BondMz77BrIl3MzIn3GM146MwsZiSmE
jM6MNCuzQ/Rb1pc6ku3kxoTGardPaYFu0XJvT4kPVvZi1z+rDqj+SHMTKT1Cx6+GB1qqIWvhgapdk/8A/Q6+UBMRj7oepfVEQqn7DNU+mXhgU5H4mfbaaOSt
w2jGyJdMmUVUttFLLPJFtgrZYaZWssFp2FbJi87BC07AMplZTBSmSXczlID1ExfJI3WycldVbB1MZceqOvlMkx5Lk6PcLbW1JkRg9iBox+pU4/zRFWO2+wzj
1N+xr4GD9WUWl3DTivpPpcrpx+09Dn31+mYX0q9KWuWN00wwMRzaXVrg8V6/6g7bZLfBme61fTL9SzJXWSbezLnPbJusbYBs25r9RZMCmEiSFiFiCghiuJEW
tG/6D6rZ6faoT3LHk/uj8eUYtUByqAUx9KpshdTGyqSlCS2mvcBkLueb9E9RswZ/TnuVEnzH/L5R6W1xsrU4NSjJbTXuYxvdZGU+5k5D7mvlLuZGT3YwV4VS
CRmLKRdSNuZuMw0JiUZBYzItPHvcJJpmlNKUFdX29zBrmavp+RqXRJ/bIC1MLM1qFnK/oa1Vnbnfw/k85fB02bX4vsO4OX/gm+P6Bhlbilp7QeFm0IRs9m9h
I2aYUtSE1OtxfcyPUIOMmN1XaaZGdBWVdSCGvOXS0xSyYzlJxkzPskbYVnMBOZ05AZSIJlIG5ENlGxS+y8WB2XgyRupmhjrqnBfL0Z1Ro4z04v4kn/2BDycV
qb4KV4zb7Hqb8BWLqS4YKr077uwacJYOD1NcG96XTHGznTYuLV1Qfld0NYGAopSkjvU6nZDVL6ba/vg/hoNPCH7R5vRBwi+yPnufa5TbbPQ+s5v7xDr7N918
P3R5TJluTNRm0vN8g9kyZU0ytELAFENBAhq0N1RAVRH6IbIjU1j1NXgrRV2NGinwZOIpqNbBulTH6ctut+3wCpo8DtWOFagWVHhtGNlLlnoLqJKttcpexiZc
eWUVfNUy6YFMumdHMZMJGQBMJFgjMJDmPZpoz4MZqlyRemoSysXof5RXAjuVVji+GgnpdrjOPIz6rjcK+C4fcCPhZXXFQk/0HVM85Ra4yXJsU3KyG98ruFMP
wt0N1WqUXFvhmUph6rdMCW9Uo6ZNpGFctHrMiKvpfyebzKnCb4GCsybAyYe1ci8jTKjZXZLKElkEgCQSBI3UaFHMWvBnVGjjMC9p6XdC3GrUv8qNKumve+Dy
WBlOqEVvtwa1fqX2/kYxvW5bdCqtmTXkfVyZ8/4X/QRy/UOqL5FvS8j6mZNb/wAEv6CHmvV7NZNmvxk+fD+TBvfLNP1Sz+0zT+TKte+Tcc6AyDmchQkQ9aAw
QzUuSRqiPY1MavehLGhvRs4lW9cGa1DWNT24NXHo7cA8SjeuDXpqUI7Zi1qRFNCS2wzcYIDbeo8IRuyvJE/PISMjPhGTc4Lh918FLMryAlleRgtfMUWTKlkd
HJdBIg0XiRFixip8i8Q9fcC18Cepo9RCpZGG4tb4PJYb+5HsvSfuqSM1qPK5FTovlF+zD4l3TJGl69hdM/qRRjV7TEcbO98rsy8ZaFsWfVDpfddg+tATlVvy
KeoY6lHqiWi9B01OPSwLy2RXpic0b2fj6baRj2w02aYpOSKhZIG0KQi8Cmi8e5IzUzQx2Z1Y9QwphuVjgn+uzo5jS7lL+a/5f0MuVrTJNO7LbXca/Z27r9TU
d/lFr/o87K5v3NP9mbdesU795aLFGX6w+nMsXlmY5Gv+0MOj1G1f6mYr7izUyXx2IXclPa0yVHkUvBDlMeRatD2PHlAWhiV70b+DTvRl4NW2j03p9HbgzWoe
xaVGO2dkXqK0mEumqq9IxsrI5fJmNVORk8vkQtyPIG+/nuJWXeTWM6Ynf5BO5t9xZzbYamtzZB4tIsjtEpG2EoIiqReKIrxGK0BihipcgWhhr7key9EX2o8l
hQ+5Hs/RoaSMeTXiY9Wxfq4zeudHj7aHCxrR9EnWrKnFnlsvD/tE467clKfKMrHTjJM0Oja/UmvEafYaVDVfbsOjCfTolPQayvQGS0BRdBWw17mHmUOMnwbX
VpgcqpWQ2u4wPNWQ5ASRpZNLi3wJTiaZB0Wj3OaORIascpYnAbqYI6+a+fZmJkpwskvhm3X90NfK0ZfqMPv6vlFFWe5Gh6JZ0eo1S+JIzmuRrAl0ZMH8Mao0
f2wp6PUpyS4lyeZkuT237V0/WxsbJS/KtbPGzjplOK9CQWPK5KqIWERAtceTRxa9tClEeUn2/obGHTyuApjV9Np21wemxYKurbMz0yjtwamTNV16OdbhHOv7
8mJk3cvkazLttmRfZts1IKHbYLSltnTkRBdTEDUwcpI1KoKqG2BxKdLbLZNulpAXhUiyRKiWUTbCEgkUckEjECmERyiG2gVcHs0cWnbXBI96fTuS4PZemV9E
E2YXpmK9rg9LUlXXoxW4ajPnRneo1xryK7mvt3qX6MJ9fU+5bOSuw34Mxqix9PjrfB0sKKi9CuJ6i/3SuMn90F0v+QeOen7iGXdU4OUGuYvQlatbNbPlGUlb
H34Zk3MQVmUU/Zk2MXlLTEIyqVOO0ZF1Ti3wbMLN8MBlUKS2hDElEroZtrcWCcRDoDNQCK5D1gT1LAZ9XVW38Pf/ACFqYW2HXDXytFFXnJR0wmPxYmFuq6Zv
grXHUhD11tf77+zUfeVTPFX0uM2tHuf2bkrcazGl2nE8/wCrYLqyJrXuEpsYHQEhAO6XvsFqp57CFsarb00bnp9brlGNn4viMv8AwxbBxXKS4PVen+nRsqcL
Ipxa00FpkOYVSrq2xTPu7l3dPBf7rfLqrfFVr/ozOzbNtmZGmdlWbbM22W2xrIlyxGfLNMqd2N4tXVJAK4bZq4dWlvRVQWSVdejMybOWaGVLSMm+XcIa8+ol
lEKoBI1mmQowDV1t+wauhv2HaMRya4JA49DbXBuYGHtrgth4HZtG3j1QqijNrUg2JSqopsJdcku4Gd6S4Er8jvyZaGnf93c0MW36tMoP3R5yd/Pcf9Myf4iW
ywSl7LHTkWQ/mdHKafcp6x/Dzt+zZnOxqWjQbayPqRcW+4ndMVrv0+5e6e+V7ktUnIXnImcwMpEE9emHrsUlpibZMJ6ZIXJx98oz51tM16pqS0wV+PvlCmWo
hq0TKtp9i0Ikh6hpLqhoXrQ3WuATMzKvu6ku/IrGHJs31dSa15Ql9LUuwppehWOq+L37m36zgRyIq6C7rZgYS6Jpnr8CcbsdQnyZrU48TbgOMvxL4+DJyXB6
/I9MUpbSL4vpcU9tFqxm+memvhtG90xop17jEKoUw4XYz86/voCzvULI2KUZrafdGHbOUfsm21/hk/6M0Mqe2zMve9pmozSlz5FtbYxNez/kysYbYhfGr3JG
vXDorFsOnbXA9YumAGMzKfcy7/c08nuzMu9xgqsMGbfYZq9Pl7oJDK0GjmEhKPT4ruP1UVVr2M9Zj+Sf3pv3AtdXQguCssnyZX7w/kh3+Sw6fsyPIrbfv3Fp
XeQM7SwaLO3nuNen36ujz7mTKzkNiW6tX6kG5+0K+2u1e6Max71L5Rt+tfxPSKZ/HBhV/fip/HBQ10ZaYwpdVbXuuRXQap6kvhkA5yBNhbY6k0BaFIbO2cQS
Gqnpj1U1NaZmxGKptMEPdj+6Fvp6ZpUzU1pkW4/uiJOuI3Ugar0xiqJJ04bjv4FrKedo04w2gbq5cf8AglhWiGmbnp9jg0jNhXpjtKaW0FMehqsU4rYxFxSM
ei3SDvIeu4EfKv0mkzGyrN7GLrdmffLYgne+4haO2ik47EFnHYWqv7kn79mXjXtjlFG1praY6MHxatLsTkLhjFEXDUJ+/wCMvnx+oPJj3MtMbJXLM25dzVyF
3M66Pc1GSSk0EU2DUSyQgVTfyXU38gkiyQEVWE/UBHEl3MFKZzYORBzlyGxpfehZjGMvvRF6nMXX+zyfwzz+D91dkPhnpLI7/Z1/qebwOMicflBDRegmMRp1
csrGvkgDdDaUhZxNJ17g18C0qxRRxO6Rh1lXAkDovHgt0kqJIamemaFM1JaZmw4GqZ6Am50e6IhDTDUTTWmGdXugKK47LW0trqj3RepaehpV7RIjCCnFSQem
GuDnD6N3P4SfPgZVetNdiIbg4PaOc+BpR6lpgLaWuwItOQtZyNTgwMqxBKcdgnXsedR0aeewrCtdPI/j0a9i9VHgchWooNUgU64utxkuGIXN7cJ8v2f+Zf8A
yaFstGdk6ktPj4fwSZ2RHuZ10e5pWPq2n+S7iNy7iyRUCygHVZdVii3QT0DP0zvpki/SVcRp1lXWSKOJRxGpVlHWSL9I1iV7sXBWNW2afp2M5Wx4KqN6+vo/
Z/R5PC4zkvl6Paeqx+n6MoHi6PtzYP8A1BDW3GvqhF/KIVWp6HcWrqpXhtf9k21dNi4BFPpaATp57Gs6dregVlPPYtOMmVQOVRpyp8ApU+BGM51legdlV4Bu
skXUQsOCeg5IkZpno0aLE+GZUHoapnoDGn0e8Ril74Ypj3ezGlxygIt1Ksg1oBjycJOqz27MbrmmgWTV1Lqjw12ZIRLRbhrTFqb+pdMuGuGEcvgk6dCfYDLH
57B1YT9Re5Ip9DwXjR4GOuJWVqXYkhQUUUsmkis7vIpZd5JOusEbpl7bRO2wQFc98ruuwrY1KO//AOQSyYrOenv/AJNMm1UEVQyqgiq8AcJ/SJ+l4HlST9Hw
SZ7q8FXT4NL6Bzo8FqxlSp8FfoP4Nb938HLF2+xasZtWM2+xvek4X3ptEY2Htrg3sShU17a5C0yMz9oWo4ygvZHi4L+0J+T1fr9vXtHl4r+Kv1GCvXemV9as
j8S3/wAhM2roipeSnpE9W2/pFjWc1KoErXWpVpg51La/XRfGsX0URZNNNA0DPH8AJ4/gb+smjuuLJMydHgBOrwbEoRkAso+BDJlWDcTQspa9gEq/AgskEi9H
OOipI3VZr3H6LuNMyIy0Hrs0BbKlrlBlNSRm03+RhT90wLsitp9cO/8AUHG/aDfUTXIpfBp9cP5r5EDfV8kO3yJ/V8lXaS067vIOV3kTdwOV3klpqd3kWst8
gJ3eQE7fIgWy0VssKTtF52CE2WC85kTmAnMk9vGoIqQ8YoLGKMNllSXVPgajFBFFFqwkqPBb938DyhEuoRDThBY3gLXic9h1Rii6cUSVx8aMOWjsq9Qg0mRZ
f0rhmXl373yMFZXqc+uTMiMf4i/U0cuXU2Jwj96NMt30+fTdPzCI3bZ1Qa2ZmPPpyJf7EMSs4fIFem3Sa2TK0SjZqTOlYSHdunohX+RSyzjYP6vksWtKN/kN
G9PuZCt8hI3eSxa1WozQvbSBhfr3GYXqS5JEp16Ayiak4RmuBWypokS7EqWi8oaBtaEDws0M1XeTPT0XjPQHWp175RVz3wxSFvkI57RJS6PLlH+a+RaUmMuQ
vbHe2u/9RFAlNgpWE2C82IWlYAnYRJgpMk6c/IGUzpMFJkkSkBnIvIFIQ+jRmEjMUjIIpHN0NxsLqwUUiykS04rS6tElMnrLEd+t5KSu8ijmUlYyxaNbd5EL
7N7LzmLWPYilbntsFCP3BZoiC+4QMpdOS/8AYgn1BactZL/2nOZJZz+4iVgCc+SjmSHc9pgHZyVVn3IBZLpk0QMqwurBH6hdWCj8bfIaF3kzVZ5CRs8gda9W
R5GVONi5MWFvkYrv17hh07bT8Cs62hmq/fDCShGa2iTNlHRUasq0BlAQopBI2A2tEEjHVspIomW3skFZHfbuKWQ78D0og5wUu/ckzZxASQ/ZXzprn+ovOsQT
kgckMygClAQWkgckMSiDlEk9tFhIgYsLFmGxkWSKxCIC7R2i6RPSSCaKNDDiUcSRaSATQ5KICcRBOaKxXIacSiWiBex/2iX+0HKRMnvIs/QHJilZyBSmTNgJ
SILOfJGTLtL5QJyJsfVjb94sYg+sspi3WcpiDisCRsElMvGwCfjYGhaZ8bAsbCTSruHKsjRjwsD12gW3GcbFz3B2U/AnVdr3HKr0+GBLyhoG4mg4RmtoDOrX
sSwpokM4FekQqQ4l+kskRLzrTWmha2px78r5NHp2VlWWjGPOoDOs1bMdrmK2vgWnUmuBDNlADOBoTqATrJN+Mw0ZmfGwNGwyWhGYWMzPjb5Cxt8kT8ZhYyTE
I2hY2gTqIcQMLQ0Zpkg5RATiNtbAziSJWRAtaGrELzWkxDOXN1r/AEKTLU8ytf8AqIsQgtYLzGZi0xAUmXpfVCcPlA5E0S6bYkiknqTRXqL5kei6SF9iB1Mu
pivUWUyRuMwsZiUZhIz8kj0LPIeFhnxmGhMC0oWeRmu3yZcLPIeFhJsVX+RuM4zXPcxa7Ruq7yZalPSq+AbrLVXb4YZdMlwSK9B3SMuBXoJA9J3SF6TukkC4
ALcdS5jxL5HdEOOyTHnXp9M10v8A6YCynwbNlUZLTW0JW0Tq5h98fh90OjGfG0LG0zlaEVohoxtCRu8marS6t8kmpG7yEjd5MpXeQkbvIHWxC7yMV3eTFhf5
GKr/ACGHW5CzaJktoQov8jsJdUQIFiFbuIS/QdsQll8UzfgYGZi81zfzImaJwl/Z9/MmXsQglYheaHLIi04iCk0DT1JBpoDJEkepR5jP5RntmrlR68KMv8pk
sQ7ZPUU2RskMpF4yF0y6kSMxmGjMTjIJGRI7CYeFghGYaEyTRhYMV2GbCYeFgFq12jVV3kyK7Bmu0DrZhapLkJpPsZldvkaruAmOkhxJjNMtwwITiQ0FaKtE
gWikohWijJPDKwurBNTLKZ0czitLK0TUyVMkeVvksrfIipllYSaEbvIxXd5MqNgaFoFuY9/K5NfFt2jy9F3JtYN22uQplas1szvUn040zS7x2ZXrL6cZr5YQ
0thR/ssS9iLYkdY0UWsjwIKWRFrIj848C9kCTPsiLyQ9ZEXnEQ6EevFnExZrTZu4y5lH5RjZUOi6a+GMFLMgllRC2yUymyUSFTLxYFMumBHjILGQsmXiyRuM
w8JiMZBoyJH4WDELDOhMPCwC0q7Bmu0y4WDELALVruGIWmVCwYhYB1pKaZzYpCwKp7JLsGy2yGBfNOospAUyyZ1cheolSBJltghVIspAdkpkTCkEjMWTLxkS
P0z5NfAt+5GDXLk08Kf3IDHsMd9VSMf1966I/LNb059VSMX119WdXDyZjVMYsf4ES84fawmLD+Av1YWcPtZKEnDcQE4D0YbgCnWIZllYtZA07KxSysgWx1q6
PngyvU4dOQ38o2FHpmn5EfWa/vjL9V/2MFYzRVhJIozQVOJOJJRZMoiyJLpl0waLIiLFhYyAJl0wRiMg0ZisWEiyRyExiExGMg0JET8Jh4WGfCYxCYI/CwNG
wQhMPGYE6pk9QtGYSMgL5wiUdolI6OaUSQkW0ScWRVIskBWReJRBIokNX3NLC/NGbWuTVwI7mgMew9KX8Hb+DA9Sl9T1dL4Z6PDj9PDcn8HmJP6nqjfkzGq9
BhQ3jp+WHlX9rL+n17xIvyxiVf2sKYy6obg/1KzrGceO+teSbKyTLtrFLKzWsrE7YDorLnDTFPV4bpUv9X9UjTtgJ+pQ6sOXjpf9TUZrzUkDaDzXIJo0ypo4
to7RJUknROiTkSiCyJLIuiiLICIgkWCQSJIWLCxYGISJIxFhoSFosNBgTUJBoyFYMNFgjMZBYyF4sLFkXhNFtF+knpNMKJE6CKJPSRD0SkEUSVEkqkXjEsoB
YQJJqjybvpNDnbHgzKKm2uD1noGHypSRm1qRp5TVHp7Xbg8jh/fmSl5PR/tBco40kn24POel82N+UPwfXs/Tklhw/mHnrpYjiW9NCXw2Fldtdzm2BjP77F5D
S5QpTPVk/wBQ/XsUHZAUtgPPkBbEky7oCWbHeJb4in/2zUuiI5Md49y//X/5NRmvKWLlgWhm1csC0bZC0dovo7RBTR2i+jtEldE6LaJSJISLJEpFkgLki6IS
LpElohIlIoLFElohoA4oLBERYBoAooNFAhYhYA4INBAXkfpnfTNWeE17A3jNexpnGf8ATJUB393fwSqH8EiarLqocjjv4Cxxm/YCSjV4D1UNvsP1YbeuDSxP
TnJr7S1YV9PwHOa4PWV1xw8TfZ6IwcKNEOqSQn6rl9T+nFmOtcY/r17ePHn8mJekrhP5kd67Zu2FX+WPIT0qP21+ZGvjP1sq3p2t9md9fyJZNnRfJeQau8hj
Wna7NTkGjYZsbOWGhYS1pQlstJbQtTMaXKAkr49zPuX8K7/2v/JqZC4Zm2/3eR/7f/kYzXlbV9zAuI1avuYFxNsg6I0F6TukkFonpCdJPSKC6SyiXUSVEEoo
llEuollEkqol1Esol1EkqohFEmMQkYgnRiFhE6MQ0YEXRiGjEiMQ0IAUwiHhEiEA8IESFU4z7h1j12djLqm0O03Ne5DRngJ9kR/9PfwM1ZA5XdFhpZsfT38D
NXp3g0YWw+EGjdBfBacL0enJa2jQrprpW+NgHlJLhit+Zw+QRjOzVCDUWYUJvIzFvsntlczJct8lcd/Rwr8h/HSjUjOsb1C362bZL5Zq+mx19BfzMTmVu/ln
oMGOrqV8JDRAvVJdOZIUVg162unL38mapEjkZh65iMZcIYqkCalEuxo1cxMnHfY1aOYma3AslcMyrf7nJf8ApSNfK/FmRb/6XJfzJIYK87avuYFxG7I8sE4m
2AOk7pDdB3QSB6CekN0EqBIHpJUAygWUCQKgXUAygWUAQSgXUAqgEVZEGMAsYBY1hI1kg4wCxgEjWFhWBUjANCASFYaFYaVIVjNdZaFZadka1pdwLx8GMVy0
LRQWJtg7XZoYhd5M+MgsZgdaUb/IRZD+TNVhP1PJYtPTyH8it17fuBlYBlJsklt2TSXuOesNY+DVjLvrqkT6PjK7I65r7IcsS9Xu+vlzl7b4EEMeHVbFfLPR
Yi/ti8PRj+n19WRHw9mzhc5O/IVQD1+H8Tq+JNGKej9br6o2eJJnnunkYquvYPU+QLXIesk0MZ8o18bsY+N7Gzi9kZrUUzPxZj2f+gm/81hrZ71BmXctenVr
5k2UVYs48lHAalAp0GmQOg7oD9Hgt0Ei6gSoDCrLKskXVZZVjCrLqskXVZeNYdVl1WBBVZdVh41hFWSAjX4CRrDxrCRrDTgUaw0Kwsaw0KyWBQrDxgorbOlK
Fa5Fbb5Teo9iQtt6X2wB1wlN7Z1VLk9s0KKfAF4lRLJF1Esom2FUi6J6SdEkbO2To7pJKNk1wcpJF4w2zV9Jwuuz6k19seQI0orA9L1/9yxc/oeat+6bZt+s
5H1bXFfiuEZChuQwU16dX09c37RNHAj/ABUAx4dGJv3kxzAj/EQUwT1Kvqstj/mhs83KvUtHrM5KOVVJ9nwzCyqOi+S17lFSUo/cErXJecPvZaEeRBrHXKNf
F7GVQuUa2N+JmtQt6k/sYjkrWJTH/Tsb9SfDQvlr7a4/EEMFZjgd0B3E7pJA9B3QH6SVAkCoFlAMoF1AkCoFlAMoF1ANWAqBdQDKBeMCOBRrCRrCxgEjWSCj
WFjWX1GK22CtyowWoghtRgttgLcpLiInZkSm+GdXW5PkcWrOUrGM00F6aB6qrQapFaadaGklFFdqKKSmDTyHQT0DH0/BP0zbBfoJ6Bj6fglV+CRboJVexpU+
BinFcmuC1AYuI7JpaNfJlHDxfpQ4bXIamqGLV1P8tGRn3OybDpZmQ+ubZFVe5Iu47Y1iU9Vi4FkayPTXXD4Q1gx+5ALfusY5hx5QVqCeqQ3XGS7rkQyq1Z02
JfktmvmQ6ql+hm4/3Vyrl3g+P0KJm2V/cysYcj1tXPYD0aYjE0rTNPH/ABM+uPI9S9RAks97nryVy1/E18JI7K5uS8k5PNsiRTpJ6S+jtCFVElRLFtAlVEuo
nIukRcol1E5IttLuSSohFEDLIhBC9ma/YkfcoQXLAWZkY9jNnkSl7lUpTfuWLTFuVKb4ZSKlNlqqG+6HqcfXsIApo33Q9TRr2C11aGIpRM61iK61FchHJIpK
YKUyS8pgpTKSmDlMlpT6XglVDqq8FlR4EYRVXgvGjwPxx/AaGP4DThKrGbfYfqphTHb7hVGNaFMm59kSL5uR1bSZk2fcxq5ttgOjbNRmhQhtmhjV9Fcp+AVV
W2uB2yPRWoICVS3IfxY60KwhyaGLAKoPfHdaMez+Bkxn/hfDNyyO4GZl09cZL3KJSVakuOReVeg2HY5R6H+Ufb5QaVakuqPKFElHTDweonSr0yOyJE7OcmP+
46/+9l+pz/8AVQ/3HX/3kv1FBEHNlWyC6ZKYF2xXuDle/bgkc6ku5DuhH3M+V7+QTtk+xYtaMstLsAnlN+4qlKQWFLZYtQ7JSJjCUhmvH8DNeP4JFa6N+w3V
j9uBmFKXsHjBINOB10pewxCCRG0iHMCL1JFJWAnYDc/JIaUwcpgnMo5iBJTBuZRyK7JNyKXwEil8HHARIpfBf2OOJA3Gdkd2ccSJT7lV3OONMm8f8kGv/M44
CrX3NHFOOAwzP8RG7uzjiDM7Zy1xyaEP7+a9tJnHDUHb3AS7M44CS/8AyYf7iMj+9l+pxxoAMFYccQAYKfc44gqEgl8HHCjEEvgbrS+DjgJmtL4DxS+DjgIq
7HHHElGUZxxFRg2ccQVZVnHEEFTjiT//2Q==
]==],
[==[
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
]==]
}
ShoxBgCache = {}
ShoxBgImgs = {} -- v1.9.11: stark (vorher weak -> Roblox leerte die Liste, nur Buttons mit paintFloatingBtn zogen nach)

function ShoxB64Decode(str)
    str = str:gsub("%s", "")
    local fns = {}
    pcall(function() if crypt and crypt.base64decode then fns[#fns+1] = crypt.base64decode end end)
    pcall(function() if crypt and crypt.base64 and crypt.base64.decode then fns[#fns+1] = crypt.base64.decode end end)
    pcall(function() if base64_decode then fns[#fns+1] = base64_decode end end)
    pcall(function() if base64 and base64.decode then fns[#fns+1] = base64.decode end end)
    for _, f in ipairs(fns) do
        local ok, out = pcall(f, str)
        if ok and type(out) == "string" and out:sub(1, 2) == "\255\216" then return out end
    end
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local map = {}
    for i = 1, 64 do map[alphabet:byte(i)] = i - 1 end
    local out, n = {}, 0
    local len = #str
    for i = 1, len, 4 do
        local a, b, c, d = str:byte(i, i + 3)
        local v = (map[a] or 0) * 262144 + (map[b] or 0) * 4096 + (map[c] or 0) * 64 + (map[d] or 0)
        n = n + 1
        out[n] = string.char(math.floor(v / 65536) % 256, math.floor(v / 256) % 256, v % 256)
    end
    local res = table.concat(out)
    if str:sub(-2) == "==" then res = res:sub(1, -3) elseif str:sub(-1) == "=" then res = res:sub(1, -2) end
    return res
end

-- liefert eine Asset-URL (getcustomasset) fuer Bild i oder nil, wenn der Executor kein writefile/getcustomasset kann
function ShoxBgAsset(i)
    local c = ShoxBgCache[i]
    if c ~= nil then return c or nil end
    ShoxBgCache[i] = false
    local data = ShoxBgData[i]
    local assetFn = getcustomasset or getsynasset or getasset
    if not data or type(assetFn) ~= "function" or type(writefile) ~= "function" then return nil end
    local path = "ShoxHub/bg_v1910_" .. i .. ".jpg"
    pcall(function() if makefolder and not (isfolder and isfolder("ShoxHub")) then makefolder("ShoxHub") end end)
    local have = false
    pcall(function() have = isfile and isfile(path) and #readfile(path) > 1000 end)
    if not have then
        local okW = pcall(function() writefile(path, ShoxB64Decode(data)) end)
        if not okW then return nil end
    end
    local okA, asset = pcall(assetFn, path)
    if okA and type(asset) == "string" and asset ~= "" then
        ShoxBgCache[i] = asset
        return asset
    end
    return nil
end

BACKGROUND_IMAGES = { { label = "Off", id = nil } }
for i = 1, #ShoxBgData do
    table.insert(BACKGROUND_IMAGES, setmetatable({ label = "BG " .. i, key = i }, {
        __index = function(t, k) if k == "id" then return ShoxBgAsset(rawget(t, "key")) end end
    }))
end
backgroundSelectorLabel = nil
backgroundImage = nil
backgroundImagePB = nil

function ShoxBgTune(img)
    if not img or not img.Parent then return end
    local cfg = BACKGROUND_IMAGES[backgroundIndex]
    local id = cfg and cfg.id
    if not id or id == "" then
        img.ImageTransparency = 1
        return
    end
    if img.Image ~= id then img.Image = id end
    local t = _clamp(backgroundImageTransparency or 0.35, 0, 1)
    if img:GetAttribute("ShoxActive") == true then t = t + (1 - t) * 0.55 end
    img.ImageTransparency = t
end

-- haengt ein Hintergrundbild unter ein Frame/Button (Form/Style bleiben, nur Bild + Rundung dazu)
function ShoxBgAttach(frame, radius, z)
    if not frame then return nil end
    local old = frame:FindFirstChild("ShoxBgImg")
    if old then return old end
    local img = Instance.new("ImageLabel")
    img.Name = "ShoxBgImg"
    img.BackgroundTransparency = 1
    img.BorderSizePixel = 0
    img.Size = UDim2.new(1, 0, 1, 0)
    img.Position = UDim2.new(0, 0, 0, 0)
    img.ScaleType = Enum.ScaleType.Crop
    img.Image = ""
    img.ImageTransparency = 1
    img.ZIndex = z or 1
    Instance.new("UICorner", img).CornerRadius = UDim.new(0, radius or 0)
    img.Parent = frame
    ShoxBgImgs[img] = true
    pcall(function() game:GetService("CollectionService"):AddTag(img, "ShoxBgImg") end)
    ShoxBgTune(img)
    return img
end

function applyBackground(index)
    backgroundIndex = _clamp(index or 1, 1, #BACKGROUND_IMAGES)
    local cfg = BACKGROUND_IMAGES[backgroundIndex]
    if not cfg then return end
    -- v1.9.11: ALLE Bilder sofort (Hauptfenster, Auto-Steal-Leiste, Mobile-Buttons, Insta-Reset): Registry + Tag-Suche
    local seen = {}
    local function tuneOne(img)
        if not img or seen[img] then return end
        seen[img] = true
        if img.Parent then pcall(ShoxBgTune, img) else ShoxBgImgs[img] = nil end
    end
    for img in pairs(ShoxBgImgs) do tuneOne(img) end
    pcall(function()
        for _, img in ipairs(game:GetService("CollectionService"):GetTagged("ShoxBgImg")) do
            if img:IsA("ImageLabel") then tuneOne(img) end
        end
    end)
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
function _shoxLayoutResetOnce()
    if _G._shoxLayoutChecked then return end
    _G._shoxLayoutChecked = true
    pcall(function()
        local flag = "ShoxHub_layout_v170.flag"
        if isfile and writefile and not isfile(flag) then
            savedButtonPositions = {}
            savedMobilePanelPos = nil
            savedProgressBarPos = nil
            writefile(flag, "1")
            if saveAllSettings then pcall(saveAllSettings) end
        end
    end)
end
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
-- v1.8.0: Bat Bypass entfernt (im Bat Aimbot aufgegangen)
_G.AceCurrentSpeedMode = _G.AceCurrentSpeedMode or "Normal"

useCarrySystem = false
lastMoveDir = _V3zero

-- TP Bat legacy vars (compat)
tpBatVersion = 1
tpBatVersionLabel = nil
tpBatVersionPill = nil
tpBatDistanceBox = nil

local CoreGui = game:GetService("CoreGui")

katanaSkinEnabled = false
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
ShoxCharAdded(function(character)
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
    -- v1.7.1: SetNetworkOwner ist clientseitig nicht möglich (entfernt)
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
    if batDesyncTpEnabled or autoBatEnabled or dropActive == true then return end
    if dir and dir.Magnitude > 0.05 then
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
        local function s(obj,id) if obj and obj.AnimationId ~= id then obj.AnimationId = id end end
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

-- v1.7.2: Ping (gecacht), Ziel-Part-Cache und Hold-Dauer-Helfer fuer Auto Steal / Body Lock
function ShoxGetPingSec()
    local now = os.clock()
    if now - (ShoxPingT or 0) > 0.5 then
        ShoxPingT = now
        pcall(function()
            ShoxPingV = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
        end)
    end
    return ShoxPingV or 0.05
end

ShoxStealPartCache = setmetatable({}, {__mode = "k"})
function ShoxStealTargetPart(prompt)
    local c = ShoxStealPartCache[prompt]
    if c and c.Parent then return c end
    local tp = prompt.Parent and prompt.Parent.Parent
    local part = tp and (tp:IsA("BasePart") and tp or tp:FindFirstChildWhichIsA("BasePart", true))
    ShoxStealPartCache[prompt] = part
    return part
end

local function getAutoGrabStopTime(durOverride)
    local dur = durOverride or (Steal and Steal.StealDuration) or 1.3
    -- v1.7.3: Varianten unterscheiden sich jetzt wirklich (Stopp-Punkt, Radius, Timeout)
    if autoStealVariant == 2 then return dur * 0.60 end
    if autoStealVariant == 3 then return dur * 0.85 end
    return dur
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

function ShoxMyPlotRaw(plotName)
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

-- v1.8.0: Ergebnis 3s cachen (vorher GetDescendants() pro Plot bei JEDEM Scan)
ShoxMyPlotCache = {}
local function isMyPlotByName(plotName)
    local c = ShoxMyPlotCache[plotName]
    local nowC = os.clock()
    if c and nowC - c.t < 3 then return c.v end
    local v = ShoxMyPlotRaw(plotName) == true
    ShoxMyPlotCache[plotName] = {t = nowC, v = v}
    return v
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
    if cached.valid and cached.position and _tick() - cached.time < 0.08
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

-- v1.7.1: Fallback, wenn getconnections fehlt (prompt:Fire() existiert nicht)
function ShoxFirePrompt(prompt, hadTriggers)
    if hadTriggers then return end
    if type(fireproximityprompt) == "function" then
        pcall(fireproximityprompt, prompt)
    else
        pcall(function()
            prompt:InputHoldBegin()
            task.wait((prompt.HoldDuration or 0) + 0.05)
            prompt:InputHoldEnd()
        end)
    end
end

local function executeSteal(prompt, podName)
    if isStealing then return end
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
            -- v1.9.6: Ablauf 1:1 wie Clean Hub (Hold bis Pausenpunkt -> Warten bis <= 9 Studs -> Rest fuellen -> ausloesen)
            for _, f in ipairs(data.hold) do task.spawn(f) end
            local startTime = _tick()
            local stealDuration = Steal.StealDuration * (((autoLeftEnabled or autoRightEnabled) and (tonumber(_G.ShoxAPStealScale) or 0.7)) or 1) -- v1.9.8
            local promptFired = stealDuration * (autoStealVariant == 2 and 0.8 or (autoStealVariant == 3 and 0.9 or 0.73))
            local function resetBar()
                if progressFill then progressFill.Size = UDim2.new(0, 0, 1, 0) end
                if progressPct then progressPct.Text = "0%" end
            end
            -- Phase 1: Hold bis zum Pausenpunkt
            while isStealing and Steal.AutoStealEnabled do
                local elapsed = _tick() - startTime
                if elapsed >= promptFired then break end
                local progress = _clamp(elapsed / stealDuration, 0, 1)
                if progressFill then progressFill.Size = UDim2.new(progress, 0, 1, 0) end
                if progressPct then progressPct.Text = _floor(progress * 100) .. "%" end
                local targetPart = ShoxStealTargetPart(prompt)
                if not targetPart then break end
                local char = LP.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp and (hrp.Position - targetPart.Position).Magnitude > Steal.StealRadius then break end
                task.wait()
            end
            local stopProgress = _clamp(promptFired / stealDuration, 0, 1)
            if progressFill then progressFill.Size = UDim2.new(stopProgress, 0, 1, 0) end
            if progressPct then progressPct.Text = _floor(stopProgress * 100) .. "%" end
            -- Phase 2: warten, bis du nah genug am Brainrot bist
            local phase2Timeout = math.max(2.99 - promptFired - math.max(stealDuration - promptFired, 0), 0.05)
            local phase2Start = _tick()
            local exitTo = nil
            while true do
                if isStealing and Steal.AutoStealEnabled then
                    if _tick() - phase2Start >= phase2Timeout then
                        exitTo = 2
                        break
                    end
                    local targetPart = ShoxStealTargetPart(prompt)
                    if not targetPart then
                        exitTo = 3
                        break
                    end
                    local char = LP.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local mag = (hrp.Position - targetPart.Position).Magnitude
                        -- v1.9.10: Auto L/R -> Ankunft vorausberechnen: ist der 9-Studs-Radius in (Fuellzeit * 0.8) erreicht, jetzt fuellen
                        local early = false
                        if autoLeftEnabled or autoRightEnabled then
                            local vel = hrp.AssemblyLinearVelocity
                            local hs = _sqrt(vel.X * vel.X + vel.Z * vel.Z)
                            if hs > 5 then
                                early = (mag - 9) / hs <= math.max(stealDuration - promptFired, 0.05) * 0.8
                            end
                        end
                        if mag <= 9 or early then
                            exitTo = 1
                            break
                        elseif mag > Steal.StealRadius then
                            break
                        end
                    end
                    task.wait()
                else
                    exitTo = 1
                    break
                end
            end
            if exitTo == 1 then
                if isStealing and Steal.AutoStealEnabled then
                    local fillStart = _tick()
                    local fillDuration = math.max(stealDuration - promptFired, 0.05)
                    local completed = false
                    while isStealing and Steal.AutoStealEnabled do
                        local fp = _clamp((_tick() - fillStart) / fillDuration, 0, 1)
                        local totalProgress = stopProgress + fp * (1 - stopProgress)
                        if progressFill then progressFill.Size = UDim2.new(totalProgress, 0, 1, 0) end
                        if progressPct then progressPct.Text = _floor(totalProgress * 100) .. "%" end
                        if fp >= 1 then completed = true; break end
                        task.wait()
                    end
                    if completed and isStealing and Steal.AutoStealEnabled then
                        if ShoxMarkStealStart then ShoxMarkStealStart() end
                        if ShoxCarryLatch then ShoxCarryLatch(14) end
                        if ShoxCarryDebugRun then ShoxCarryDebugRun() end
                        pcall(function()
                            for _, f in ipairs(data.trigger) do task.spawn(f) end
                            local remote = ReplicatedStorage:FindFirstChild("StealAnimal")
                            if remote and podName and remote:IsA("RemoteEvent") then
                                remote:FireServer(podName)
                            end
                            ShoxFirePrompt(prompt, #data.trigger > 0)
                        end)
                    end
                end
                resetBar()
            elseif exitTo == 2 then
                resetBar()
                data.ready = true
                isStealing = false
                task.wait()
                local newPrompt, newName = findNearestPrompt()
                if newPrompt then
                    executeSteal(newPrompt, newName)
                    recursionStarted = isStealing
                end
                return
            else
                resetBar()
            end
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
        if ShoxIsCarrying and ShoxIsCarrying() then return end -- v1.7.3: nichts versuchen, waehrend du traegst
        -- v1.7.2: kurzer Cooldown zwischen Versuchen (kein Spam pro Frame)
        local nowS = os.clock()
        if nowS - (ShoxStealLastTry or 0) < (autoStealVariant == 3 and 0.04 or 0.05) then return end -- v1.9.10: schnelleres Re-Try
        local p, n = findNearestPrompt()
        if p then ShoxStealLastTry = nowS; executeSteal(p, n) end
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
function ShoxGetGroundHit(char, root)
    -- v1.7.1: RaycastParams + Ignore-Liste gecacht (vorher jedes Mal neu gebaut)
    local now = os.clock()
    if not ShoxGroundParams then
        ShoxGroundParams = RaycastParams.new()
        ShoxGroundParams.FilterType = Enum.RaycastFilterType.Exclude
        ShoxGroundParams.IgnoreWater = true
        pcall(function() ShoxGroundParams.RespectCanCollide = true end)
        ShoxGroundChar, ShoxGroundT = nil, 0
    end
    if ShoxGroundChar ~= char or now - ShoxGroundT > 1 then
        ShoxGroundChar, ShoxGroundT = char, now
        local ignore = {char}
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character and p.Character ~= char then table.insert(ignore, p.Character) end
        end
        ShoxGroundParams.FilterDescendantsInstances = ignore
    end
    return workspace:Raycast(root.Position, Vector3.new(0, -2000, 0), ShoxGroundParams)
end

function ShoxGetStandOffset(humanoid, root)
    local hip = math.max(0, humanoid.HipHeight)
    if humanoid.RigType == Enum.HumanoidRigType.R6 then
        return 3 + hip + 0.05
    end
    return hip + (root.Size.Y * 0.5) + 0.05
end

-- v1.8.0: TP Down nach S2-Vorbild: festes Ziel-Y, KEIN Raycast, keine Fall-Velocity-Bedingung.
-- ShoxTPDownGroundY = Y der HumanoidRootPart am Boden (S2 nutzt -7.00). Im Spiel pruefen: _G.ShoxATPDebug = true
ShoxTPDownGroundY = -7.00

-- v1.9.5: TP Down behaelt das horizontale Tempo (nur Y-Velocity auf 0). Ziel-Y kommt aus dem Boden-Raycast,
-- Y=-7 nur als Fallback wenn kein Boden gefunden wird. Nur wenn wirklich Hoehe ueber dem Boden da ist.
function doTpDown()
    pcall(function()
        local char = LP.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local targetY = ShoxTPDownGroundY
        local hit = ShoxGetGroundHit(char, root)
        if hit then
            local off = hum and ShoxGetStandOffset(hum, root) or 3
            targetY = hit.Position.Y + off
            if root.Position.Y - targetY < 1.5 then return end -- schon am Boden
        end
        local lv = root.AssemblyLinearVelocity
        root.CFrame = _CFnew(root.Position.X, targetY, root.Position.Z) * CFrame.Angles(0, select(2, root.CFrame:ToEulerAnglesYXZ()), 0)
        root.AssemblyLinearVelocity = _V3new(lv.X, 0, lv.Z)
    end)
end

-- MIRROR TP DOWN
-- ═══════════════════════════════════════════════════════════════
do
    local MIRROR_TP_DROP_THRESHOLD = 3
    local MIRROR_TP_DOWN_Y         = ShoxTPDownGroundY
    local mirrorTPPreviousY        = {}
    local mirrorTPLastTeleport     = 0
    local mirrorTPCharOf           = {}

    -- Keep cleanup in the same lexical scope as the per-player history table.
    Players.PlayerRemoving:Connect(function(player)
        mirrorTPPreviousY[player.UserId] = nil
    end)

    local function mirrorTPAimbotActive()
        return (_G.AmbitiousNormalAimbotOn == true)
            or (_G.AmbitiousTPBatOn == true)
            or (_G.AlvaroTP and _G.AlvaroTP.on == true)
            or (autoBatEnabled == true)
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
        -- v1.7.1: horizontales Tempo behalten (vorher komplett auf 0 -> Stopp)
        pcall(function()
            local lv = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = Vector3.new(lv.X, 0, lv.Z)
        end)
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
                    -- v1.7.1: Respawn/neuer Charakter des Gegners löst keinen falschen TP mehr aus
                    if mirrorTPCharOf[player.UserId] ~= character then
                        mirrorTPCharOf[player.UserId] = character
                        previousY = nil
                    end
                    if previousY
                       and previousY - currentY >= MIRROR_TP_DROP_THRESHOLD
                       and root.AssemblyLinearVelocity.Y < -20 then
                        pcall(mirrorTPTeleportDown)
                        table.clear(mirrorTPPreviousY)
                        return
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
    -- v1.9.5: gleiche Regeln wie ShoxHubIsCarrying: nur Attribut "Stealing" und explizite Marker, kein Namens-Match
    local ok, val = pcall(function() return LP:GetAttribute("Stealing") end)
    if ok and val == true then return true end
    local char = LP.Character
    if not char then return false end
    local ok3, val3 = pcall(function() return char:GetAttribute("Stealing") end)
    if ok3 and val3 == true then return true end
    for _, name in ipairs({"Carrying","IsCarrying","Grabbed","Holding","StealHold","HasGrab"}) do
        local v = char:FindFirstChild(name)
        if v then
            if v:IsA("BoolValue") and v.Value == true then return true end
            if v:IsA("ObjectValue") and v.Value ~= nil then return true end
            if v:IsA("StringValue") and v.Value ~= "" then return true end
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
_G.AmbitiousSafeModeMonitorConnection = RunService.Heartbeat:Connect(function(dt)
    _G._shoxSMAcc = (_G._shoxSMAcc or 0) + (dt or 0.016)
    if _G._shoxSMAcc < 0.2 then return end -- v1.7.0: statt jedes Frame nur 5x pro Sekunde
    _G._shoxSMAcc = 0
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
                    if not ShoxCachedCM then
                        local PM = LP.PlayerScripts:FindFirstChild("PlayerModule")
                        local cms = PM and PM:FindFirstChild("ControlModule")
                        if cms then ShoxCachedCM = require(cms) end
                    end
                    if ShoxCachedCM then ShoxCachedCM:Enable() end
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
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
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
    local velocity
    local ok = pcall(function() velocity = root.AssemblyLinearVelocity end)
    if not ok or typeof(velocity) ~= "Vector3" then return end
    if velocity.Magnitude <= AntiFlingShieldModule.velocityThreshold then return end
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
    -- v1.7.0: Drawing-Linien liegen immer ueber jedem GUI -> waehrend des Intros komplett verstecken
    if ShoxIntro and ShoxIntro.Running then
        for _, lines in pairs(espTracerCache) do
            for _, ln in ipairs(lines) do pcall(function() ln.Visible = false end) end
        end
        return
    end
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

-- v1.7.2: Body Lock Einstellungen / Carry-Erkennung
bodyLockOffWhileCarry = true
bodyLockCarrySetVisual = nil
ShoxBLTarget = nil
ShoxBLPickT = 0
ShoxCarryCache = {t = 0, v = false}
ShoxCarryPendingUntil = 0

-- v1.8.0: wird beim Ausloesen des Steals aufgerufen -> Carry gilt sofort (bis das Attribut "Stealing" repliziert ist)
function ShoxMarkStealStart(secs)
    ShoxCarryPendingUntil = os.clock() + (tonumber(secs) or 0.9)
    ShoxCarryCache.t = 0
end

function ShoxIsCarrying()
    local now = os.clock()
    if now - ShoxCarryCache.t < 0.016 then return ShoxCarryCache.v end -- v1.9.10: pro Frame statt 50ms
    ShoxCarryCache.t = now
    local v = false
    local char = LP.Character
    if LP:GetAttribute("Stealing") == true or (char and char:GetAttribute("Stealing") == true) then
        v = true
    elseif char then
        for _, n in ipairs({"Carrying","IsCarrying","Grabbed","Holding","StealHold","HasGrab"}) do
            local m = char:FindFirstChild(n)
            if m and ((m:IsA("BoolValue") and m.Value == true)
                or (m:IsA("ObjectValue") and m.Value ~= nil)
                or (m:IsA("StringValue") and m.Value ~= "")) then
                v = true
                break
            end
        end
        if not v then
            for _, ch in ipairs(char:GetChildren()) do
                if ch:IsA("Model") and ch:GetAttribute("IsCarried") == true then v = true; break end
            end
        end
    end
    if v then
        ShoxCarryPendingUntil = 0 -- echt bestaetigt
    elseif now < ShoxCarryPendingUntil then
        v = true
    end
    ShoxCarryCache.v = v
    return v
end

-- v1.9.2: Carry-Latch. Nach dem Steal-Fire gilt "Brainrot getragen" feste Zeit, egal was die geratene Erkennung sagt.
ShoxCarryLatchUntil = 0
function ShoxCarryLatch(secs) ShoxCarryLatchUntil = os.clock() + (tonumber(secs) or 14) end
function ShoxCarryLatched() return os.clock() < ShoxCarryLatchUntil end

-- v1.9.2: Debug: _G.ShoxCarryDebug = true -> beim Steal werden Attribute/Kinder vorher/nachher verglichen (warn)
function ShoxCarrySnap()
    local s = {lp = {}, ch = {}, kids = {}}
    pcall(function()
        for k, v in pairs(LP:GetAttributes()) do s.lp[k] = v end
        local c = LP.Character
        if c then
            for k, v in pairs(c:GetAttributes()) do s.ch[k] = v end
            for _, o in ipairs(c:GetChildren()) do s.kids[o.Name .. ":" .. o.ClassName] = true end
        end
    end)
    return s
end
function ShoxCarryDebugRun()
    if not _G.ShoxCarryDebug then return end
    local a = ShoxCarrySnap()
    task.delay(1.2, function()
        local b = ShoxCarrySnap()
        for k, v in pairs(b.lp) do if a.lp[k] ~= v then warn("[ShoxCarry] Spieler-Attribut " .. k .. ": " .. tostring(a.lp[k]) .. " -> " .. tostring(v)) end end
        for k, v in pairs(a.lp) do if b.lp[k] == nil then warn("[ShoxCarry] Spieler-Attribut weg: " .. k .. " (war " .. tostring(v) .. ")") end end
        for k, v in pairs(b.ch) do if a.ch[k] ~= v then warn("[ShoxCarry] Char-Attribut " .. k .. ": " .. tostring(a.ch[k]) .. " -> " .. tostring(v)) end end
        for k, v in pairs(a.ch) do if b.ch[k] == nil then warn("[ShoxCarry] Char-Attribut weg: " .. k .. " (war " .. tostring(v) .. ")") end end
        for k in pairs(b.kids) do if not a.kids[k] then warn("[ShoxCarry] Char neues Kind: " .. k) end end
        for k in pairs(a.kids) do if not b.kids[k] then warn("[ShoxCarry] Char Kind weg: " .. k) end end
        warn("[ShoxCarry] Dump Ende (Carry gerade: " .. tostring(ShoxIsCarrying and ShoxIsCarrying()) .. ")")
    end)
end

-- Attribut-Events: Cache sofort verwerfen, damit Carry nicht bis zu 0.1s zu spaet erkannt wird
do
    local function bump() ShoxCarryCache.t = 0 end
    ShoxHubState:Track(LP:GetAttributeChangedSignal("Stealing"):Connect(bump))
    local function hook(c)
        if c then ShoxHubState:Track(c:GetAttributeChangedSignal("Stealing"):Connect(bump)) end
    end
    hook(LP.Character)
    ShoxCharAdded(hook)
end

function _blValidTarget(tRoot)
    if not tRoot or not tRoot.Parent then return false end
    local h = tRoot.Parent:FindFirstChildOfClass("Humanoid")
    return h ~= nil and h.Health > 0
end

ShoxBLHeld = false

function ShoxBLRelease(hum)
    if ShoxBLHeld and hum then hum.AutoRotate = true end
    ShoxBLHeld = false
    ShoxBLTarget = nil
end

function ShoxBLFlatDist(a, b)
    local dx, dz = a.X - b.X, a.Z - b.Z
    return _sqrt(dx * dx + dz * dz)
end

-- v1.7.3: Body Lock neu: horizontale Reichweite, sticky Ziel, schnelle aber weiche Drehung,
-- AutoRotate wird nur zurueckgesetzt wenn WIR es ausgeschaltet haben.
local function _bodyLockTick(dt)
    dt = dt or 0.016
    local char = LP.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then return end

    if bodyLockOffWhileCarry == true and ShoxIsCarrying() then
        ShoxBLRelease(hum)
        return
    end

    local st = hum:GetState()
    if hum.Sit or hum.PlatformStand or st == Enum.HumanoidStateType.Physics
       or st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.FallingDown then
        ShoxBLRelease(hum)
        return
    end

    local range = tonumber(bodyLockRange) or 20
    local now = os.clock()
    local rpos = root.Position
    local cur = ShoxBLTarget
    if cur and ((not _blValidTarget(cur)) or ShoxBLFlatDist(cur.Position, rpos) > range * 1.15) then
        cur = nil
    end
    if (not cur) or now - ShoxBLPickT > 0.2 then
        ShoxBLPickT = now
        local best, bestD = nil, _huge
        local plist = _GetPlayersCached()
        for i = 1, #plist do
            local plr = plist[i]
            if plr ~= LP then
                local c = plr.Character
                local tr = c and c:FindFirstChild("HumanoidRootPart")
                if tr and _blValidTarget(tr) then
                    local d = ShoxBLFlatDist(tr.Position, rpos)
                    if d <= range and _abs(tr.Position.Y - rpos.Y) < 60 and d < bestD then
                        best, bestD = tr, d
                    end
                end
            end
        end
        if best and best ~= cur then
            if not cur then
                cur = best
            elseif bestD < ShoxBLFlatDist(cur.Position, rpos) * 0.7 then
                cur = best
            end
        end
    end
    ShoxBLTarget = cur
    if not cur then
        ShoxBLRelease(hum)
        return
    end

    if hum.AutoRotate then hum.AutoRotate = false end
    ShoxBLHeld = true

    local tv = cur.AssemblyLinearVelocity
    local flatV = _V3new(tv.X, 0, tv.Z)
    if flatV.Magnitude > 60 then flatV = flatV.Unit * 60 end
    local lead = math.min(ShoxGetPingSec() * 0.5, 0.1) + 0.04
    local fx = (cur.Position.X + flatV.X * lead) - rpos.X
    local fz = (cur.Position.Z + flatV.Z * lead) - rpos.Z
    if (fx * fx + fz * fz) < 0.25 then return end

    local goalYaw = math.atan2(-fx, -fz)
    local _, curYaw = root.CFrame:ToEulerAnglesYXZ()
    local dYaw = (goalYaw - curYaw + math.pi) % (2 * math.pi) - math.pi
    if _abs(dYaw) < 0.01 then return end
    local alpha = _clamp(1 - math.exp(-28 * dt), 0.35, 1)
    root.CFrame = CFrame.new(rpos) * CFrame.Angles(0, curYaw + dYaw * alpha, 0)
    root.AssemblyAngularVelocity = _V3zero
end

function startBodyLock()
    if _bodyLockConn then _bodyLockConn:Disconnect() end
    _bodyLockConn = RunService.Heartbeat:Connect(function(dt)
        if not bodyLockEnabled or _blSuppressCount > 0 then return end
        local ok, err = xpcall(_bodyLockTick, debug.traceback, dt)
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

ShoxCharAdded(function()
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
    speedLabel.Font = Enum.Font.GothamBold
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

-- v1.8.0: Wegpunkt-Check ohne Verfehlen (bei 60 Studs/s und 30 FPS sind es 2 Studs pro Frame; "< 1" wurde oft uebersprungen)
ShoxAPDist = {}
function ShoxAPReached(key, root, tgt, dt, spd)
    local d = (tgt - root.Position).Magnitude
    local last = ShoxAPDist[key]
    ShoxAPDist[key] = d
    local step = (tonumber(spd) or 0) * (tonumber(dt) or 0.016)
    if d < math.max(1, step * 1.25) then ShoxAPDist[key] = nil; return true end
    if last and d > last + 0.05 and last < math.max(3, step * 2) then ShoxAPDist[key] = nil; return true end
    return false
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
    _unsuppressBodyLock(true)
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
    _suppressBodyLock()
    if alConn then alConn:Disconnect() end
    alPhase = 1
    ShoxCarryLatchUntil = 0
    table.clear(ShoxAPDist)
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
        if alPhase == 1 then
            local tgt = _V3new(AP.L1.X, root.Position.Y, AP.L1.Z)
            if ShoxAPReached("L1", root, tgt, dt, spd) then
                alPhase = 2
                local d = AP.L2 - root.Position
                local mv = _V3new(d.X, 0, d.Z)
                if mv.Magnitude > 0.001 then mv = mv.Unit else mv = _V3zero end
                hum:Move(mv, false)
                root.AssemblyLinearVelocity = _V3new(mv.X * spd, root.AssemblyLinearVelocity.Y, mv.Z * spd)
                return
            end
            local d = AP.L1 - root.Position
            local mv = _V3new(d.X, 0, d.Z)
            if mv.Magnitude > 0.001 then mv = mv.Unit else mv = _V3zero end
            hum:Move(mv, false)
            root.AssemblyLinearVelocity = _V3new(mv.X * spd, root.AssemblyLinearVelocity.Y, mv.Z * spd)
        elseif alPhase == 2 then
            local tgt = _V3new(AP.L2.X, root.Position.Y, AP.L2.Z)
            if ShoxAPReached("L2", root, tgt, dt, spd) then
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
            root.AssemblyLinearVelocity = _V3new(mv.X * spd, root.AssemblyLinearVelocity.Y, mv.Z * spd)
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
    _unsuppressBodyLock(true)
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
    _suppressBodyLock()
    if arConn then arConn:Disconnect() end
    arPhase = 1
    ShoxCarryLatchUntil = 0
    table.clear(ShoxAPDist)
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
        if arPhase == 1 then
            local tgt = _V3new(AP.R1.X, root.Position.Y, AP.R1.Z)
            if ShoxAPReached("R1", root, tgt, dt, spd) then
                arPhase = 2
                local d = AP.R2 - root.Position
                local mv = _V3new(d.X, 0, d.Z)
                if mv.Magnitude > 0.001 then mv = mv.Unit else mv = _V3zero end
                hum:Move(mv, false)
                root.AssemblyLinearVelocity = _V3new(mv.X * spd, root.AssemblyLinearVelocity.Y, mv.Z * spd)
                return
            end
            local d = AP.R1 - root.Position
            local mv = _V3new(d.X, 0, d.Z)
            if mv.Magnitude > 0.001 then mv = mv.Unit else mv = _V3zero end
            hum:Move(mv, false)
            root.AssemblyLinearVelocity = _V3new(mv.X * spd, root.AssemblyLinearVelocity.Y, mv.Z * spd)
        elseif arPhase == 2 then
            local tgt = _V3new(AP.R2.X, root.Position.Y, AP.R2.Z)
            if ShoxAPReached("R2", root, tgt, dt, spd) then
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
            root.AssemblyLinearVelocity = _V3new(mv.X * spd, root.AssemblyLinearVelocity.Y, mv.Z * spd)
        end
    end)
end

function getClosestTarget()
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

function trySwing()
    pcall(function()
        local char = LP.Character
        if not char then return end
        local currentTool = char:FindFirstChildOfClass("Tool")
        if currentTool and not isBatTool(currentTool) then return end
        local bat = findBat()
        if bat then
            if bat.Parent ~= char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then pcall(function() hum:EquipTool(bat) end) end
            end
            pcall(function() bat:Activate() end)
        end
    end)
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
        root.AssemblyLinearVelocity = _V3new(0, -0.1, 0)
        root.AssemblyAngularVelocity = _V3zero
    end
    _prevAutoRotate = nil
    lastMoveDir = _V3zero
    if ShoxBatResetTarget then ShoxBatResetTarget() end
    _unsuppressBodyLock(true)
end

-- v1.9.4: BAT AIMBOT = Clean-Hub Bat Bypass (Ping-Vorhalt, Beschleunigung, Luft-Vorhersage) in EINEM Modul.
-- Nur dieses eine System schreibt Velocity/AngularVelocity solange autoBatEnabled an ist
-- (CarrySystem, Auto TP Down, Body Lock, Auto L/R sind in dieser Zeit gesperrt).
ShoxBatLaggerSpeed = 40
ShoxBatCfg = {
    ACTIVATE_DISTANCE = 13, MIN_FOLLOW_DISTANCE = 1, PREDICTION_TIME = 0.22, PREDICT_AHEAD = 3,
    MAX_VELOCITY_CHANGE = 150, VELOCITY_SMOOTHING = 0.2, MAX_HORIZONTAL_VELOCITY = 80,
    SERVER_TICKRATE = 1 / 60, MIN_PING = 0.03, MAX_PING = 0.25, ACCEL_WEIGHT = 0.3,
    DIR_CHANGE_TIME = 0.12, QUICK_MULT = 1.5, GRAVITY = 196.2, AIR_CONTROL = 0.8, MIN_AIRBORNE = 0.08,
}
ShoxBatPing = {sec = 0.1, ms = 0, at = 0}
ShoxBatZ = nil

function ShoxBatResetTarget()
    ShoxBatZ = {
        target = nil, lastPos = nil, vel = _V3zero, smooth = _V3zero,
        velHist = {}, accHist = {}, airHist = {},
        prevDir = nil, lastDirT = 0, airT = 0, lastHit = 0,
    }
end
ShoxBatResetTarget()

function ShoxBatAvg(list)
    local n = #list
    if n == 0 then return _V3zero end
    local sum = _V3zero
    for i = 1, n do sum = sum + list[i] end
    return sum / n
end

function ShoxBatPush(list, value, maxN)
    list[#list + 1] = value
    if #list > maxN then table.remove(list, 1) end
end

function ShoxBatSamplePing(now)
    if now - ShoxBatPing.at < 0.5 then return end
    ShoxBatPing.at = now
    local ok, value = pcall(function()
        return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if ok and type(value) == "number" then ShoxBatPing.ms = math.floor(value) end
    ShoxBatPing.sec = _clamp(ShoxBatPing.ms / 1000, ShoxBatCfg.MIN_PING, ShoxBatCfg.MAX_PING)
end

function ShoxBatStep(dt)
    if not autoBatEnabled then return end
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then return end
    local Z, C = ShoxBatZ, ShoxBatCfg
    local now = _tick()
    ShoxBatSamplePing(now)
    hum.AutoRotate = false

    -- Bat sicher in der Hand haben (findBat equipt aus dem Rucksack)
    local tool = char:FindFirstChildOfClass("Tool")
    if not (tool and isBatTool(tool)) then
        local bat = findBat()
        if bat then
            if bat.Parent ~= char then pcall(function() hum:EquipTool(bat) end) end
            tool = bat
        end
    end

    local target = getClosestTarget()
    local tchar = target and target.Parent
    local thum = tchar and tchar:FindFirstChildOfClass("Humanoid")
    if not target or not thum or thum.Health <= 0 then
        ShoxBatResetTarget()
        return
    end
    if Z.target ~= target then
        ShoxBatResetTarget()
        Z = ShoxBatZ
        Z.target = target
    end

    local targetPos = target.Position
    local safeDt = math.max(tonumber(dt) or (1 / 60), 1 / 240)

    -- Gegner-Geschwindigkeit aus Positionsdifferenz, Ausreisser gefiltert
    if Z.lastPos then
        local raw = (targetPos - Z.lastPos) / safeDt
        local delta = raw - Z.vel
        if delta.Magnitude > C.MAX_VELOCITY_CHANGE then
            raw = Z.vel + delta.Unit * C.MAX_VELOCITY_CHANGE
        end
        local horiz = _V3new(raw.X, 0, raw.Z)
        if horiz.Magnitude > C.MAX_HORIZONTAL_VELOCITY then
            horiz = horiz.Unit * C.MAX_HORIZONTAL_VELOCITY
            raw = _V3new(horiz.X, raw.Y, horiz.Z)
        end
        ShoxBatPush(Z.accHist, (raw - Z.vel) / safeDt, 4)
        ShoxBatPush(Z.velHist, raw, 8)
        Z.vel = raw
        Z.smooth = Z.smooth:Lerp(raw, C.VELOCITY_SMOOTHING)
    end
    Z.lastPos = targetPos

    local airborne = thum.FloorMaterial == Enum.Material.Air
    Z.airT = airborne and (Z.airT + safeDt) or 0
    if airborne and Z.airT >= C.MIN_AIRBORNE then
        ShoxBatPush(Z.airHist, Z.vel, 6)
    elseif not airborne then
        Z.airHist = {}
    end

    local predVel = Z.smooth
    if airborne and #Z.airHist > 0 then
        local a = ShoxBatAvg(Z.airHist)
        predVel = _V3new(a.X, Z.vel.Y, a.Z) * C.AIR_CONTROL
    end

    -- schnelle Richtungswechsel erkennen -> mehr Vorhalt
    local quickTurn = false
    local hv = _V3new(Z.vel.X, 0, Z.vel.Z)
    if hv.Magnitude > 5 then
        local dir = hv.Unit
        if Z.prevDir and Z.prevDir:Dot(dir) < 0.5 then
            quickTurn = now - Z.lastDirT < C.DIR_CHANGE_TIME
            Z.lastDirT = now
        end
        Z.prevDir = dir
    end

    local delay = ShoxBatPing.sec + C.SERVER_TICKRATE
    if quickTurn then delay = delay * C.QUICK_MULT end

    local predicted = targetPos + predVel * delay
    predicted = predicted + ShoxBatAvg(Z.accHist) * C.ACCEL_WEIGHT * (delay * delay * 0.5)
    local pt = C.PREDICTION_TIME * 1.1
    predicted = predicted + predVel * pt
    if airborne then
        predicted = predicted + _V3new(0, -0.5 * C.GRAVITY * pt * pt, 0)
    end
    local flat = _V3new(predVel.X, 0, predVel.Z)
    if flat.Magnitude > 1 then predicted = predicted + flat.Unit * C.PREDICT_AHEAD end

    local toTarget = predicted - root.Position
    -- Ausrichtung zum Vorhalt-Punkt
    if toTarget.Magnitude > 0.01 then
        local axis = root.CFrame.LookVector:Cross(toTarget.Unit)
        local angle = math.asin(_clamp(axis.Magnitude, -1, 1))
        root.AssemblyAngularVelocity = axis.Magnitude > 0.01 and (axis.Unit * angle * 80) or _V3zero
    end

    -- Schlag
    if tool and isBatTool(tool) and (targetPos - root.Position).Magnitude <= C.ACTIVATE_DISTANCE
       and now - Z.lastHit >= 0.3 then
        Z.lastHit = now
        pcall(function() tool:Activate() end)
    end

    -- Verfolgen (im Lagger-Modus langsamer, wie Clean Hub)
    local speed = tonumber(BAT_AIMBOT_SPEED) or 60
    if CarrySystem and CarrySystem.laggerMode ~= 0 then speed = math.min(speed, ShoxBatLaggerSpeed) end
    -- v1.9.4-hotfix2: 1:1 wie Clean Hub (Dead-Zone auf Vorhalt-Punkt, voller Speed)
    if toTarget.Magnitude > C.MIN_FOLLOW_DISTANCE then
        root.AssemblyLinearVelocity = toTarget.Unit * speed
    else
        root.AssemblyLinearVelocity = _V3new(0, root.AssemblyLinearVelocity.Y * 0.5, 0)
    end
end

function startAimbotAdapt()
    if _aimbotConn then return end
    _suppressBodyLock()
    local hum0 = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum0 then
        if _prevAutoRotate == nil then _prevAutoRotate = hum0.AutoRotate end
        hum0.AutoRotate = false
    end
    -- v1.9.5: alte Schleife (Zielhoehe +3.7, yVel>=13, Lerp 0.8 = Schleudern) entfernt; nur noch ShoxBatStep.
    ShoxBatResetTarget()
    _aimbotConn = RunService.RenderStepped:Connect(function(dt)
        ShoxBatStep(dt)
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
    autoBatEnabled = true
    if autoBatSetVisual then autoBatSetVisual(true) end
    if mobSetAutoBat then mobSetAutoBat(true) end
    startAimbotAdapt()
end

-- ═══════════════════════════════════════════════════════════════
-- v1.8.0: Bat Bypass entfernt (Modul, Compat-Wrapper, Toggle, Keybind, Config). Alles im Bat Aimbot.

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
local _tpBatMaxRange    = 100

-- v1.9.5: gecachte Liste der Charakter-Teile (statt GetDescendants pro Frame). Neu aufgebaut bei Charakterwechsel / alle 3s.
ShoxTPBatPartsChar, ShoxTPBatPartsList, ShoxTPBatPartsAt = nil, {}, 0
function ShoxTPBatSetNoCollide(char)
    if not char then return end
    local now = os.clock()
    if ShoxTPBatPartsChar ~= char or now - ShoxTPBatPartsAt > 3 then
        ShoxTPBatPartsChar, ShoxTPBatPartsAt = char, now
        ShoxTPBatPartsList = {}
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then ShoxTPBatPartsList[#ShoxTPBatPartsList + 1] = part end
        end
    end
    ShoxTPBatFlipped = ShoxTPBatFlipped or {}
    for _, part in ipairs(ShoxTPBatPartsList) do
        if part.Parent and part.CanCollide then
            ShoxTPBatFlipped[part] = true
            part.CanCollide = false
        end
    end
end
-- v1.9.8: beim Ausschalten von TP Bat wieder normal kollidieren
function ShoxTPBatRestoreCollide()
    local fl = ShoxTPBatFlipped
    ShoxTPBatFlipped = {}
    if not fl then return end
    for part in pairs(fl) do
        if part and part.Parent and part.Name ~= "Handle" then pcall(function() part.CanCollide = true end) end
    end
end

-- ANTI-DIE (aus dem Clean Hub; der Lagger-Teil ist bewusst NICHT uebernommen)
local _tpBatAntiDieThread = nil

local function tpBatStartAntiDie()
    if _tpBatAntiDieThread then return end
    _tpBatAntiDieThread = task.spawn(function()
        while batDesyncTpEnabled do
            pcall(function()
                local char = LP.Character
                if not char then task.wait(0.1) return end
                local hum  = char:FindFirstChildOfClass("Humanoid")
                local root = char:FindFirstChild("HumanoidRootPart")
                if hum then
                    if hum.Health <= 0 then
                        hum.Health = hum.MaxHealth
                    end
                    if hum.PlatformStand then hum.PlatformStand = false end
                    if hum.Sit then hum.Sit = false end
                    local st = hum:GetState()
                    if st == Enum.HumanoidStateType.Physics
                       or st == Enum.HumanoidStateType.Ragdoll
                       or st == Enum.HumanoidStateType.FallingDown then
                        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                        hum:ChangeState(Enum.HumanoidStateType.Running)
                    end
                end
                if root and sethiddenproperty then
                    pcall(sethiddenproperty, root, "PhysicsRepRootPart", nil)
                end
                ShoxTPBatSetNoCollide(char)
            end)
            task.wait(0.1)
        end
        _tpBatAntiDieThread = nil
    end)
end

local function tpBatStopAntiDie()
    if _tpBatAntiDieThread then
        pcall(task.cancel, _tpBatAntiDieThread)
        _tpBatAntiDieThread = nil
    end
end

-- BAT
local function tpBatGetBat()
    local character = LP.Character
    if not character then return nil end
    for _, tool in ipairs(character:GetChildren()) do
        if tool:IsA("Tool") then
            local name = tool.Name:lower()
            if name:find("bat") or name:find("slap") then return tool end
        end
    end
    local backpack = LP:FindFirstChild("Backpack")
    if not backpack then return nil end
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            local name = tool.Name:lower()
            if name:find("bat") or name:find("slap") then
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                if humanoid then pcall(function() humanoid:EquipTool(tool) end) end
                return tool
            end
        end
    end
    return nil
end

local function tpBatHit()
    if _tpBatHitCooldown then return end
    _tpBatHitCooldown = true
    pcall(function()
        local bat = tpBatGetBat()
        if not bat then return end
        bat:Activate()
        local remote = bat:FindFirstChildWhichIsA("RemoteEvent")
        if remote then remote:FireServer() end
    end)
    task.delay(0.08, function() _tpBatHitCooldown = false end)
end

-- TARGETING
local function tpBatClosestPlayer(root)
    local closest, distance = nil, math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        local character  = player ~= LP and player.Character
        local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid   = character and character:FindFirstChildOfClass("Humanoid")
        if targetRoot and humanoid and humanoid.Health > 0 then
            local candidateDistance = (root.Position - targetRoot.Position).Magnitude
            if candidateDistance < distance then
                closest, distance = player, candidateDistance
            end
        end
    end
    return closest, distance
end

-- TELEPORT (v1.9.5: SetNetworkOwner + task.wait() entfernt, wirkt vom Client nicht und erzeugte ueberlappende Threads)
local function tpBatNetworkOwnerTeleport(root, targetRoot)
    local targetPosition = targetRoot.Position + _V3new(0, 0.9, 0)
    root.CFrame = _CFnew(targetPosition)
    root.AssemblyLinearVelocity = targetRoot.AssemblyLinearVelocity
end

-- UPDATE LOOP
ShoxTPBatLastTP, ShoxTPBatLastAnim = 0, 0
local function tpBatUpdate()
    if not batDesyncTpEnabled then return end
    local character = LP.Character
    local root      = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid then return end
    local now = os.clock()

    -- Animationen nur alle 0.5s stoppen (vorher jeden Frame)
    if now - ShoxTPBatLastAnim >= 0.5 then
        ShoxTPBatLastAnim = now
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if animator then
            pcall(function()
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do track:Stop() end
            end)
        end
    end

    local bat = tpBatGetBat()
    if bat and bat.Parent ~= character then
        pcall(function() humanoid:EquipTool(bat) end)
    end

    local target, distance = tpBatClosestPlayer(root)
    if not target or distance > _tpBatMaxRange then return end
    local targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    -- Teleport gedrosselt (max ~30x pro Sekunde), Tempo des Gegners wird uebernommen
    if now - ShoxTPBatLastTP >= 0.033 then
        ShoxTPBatLastTP = now
        tpBatNetworkOwnerTeleport(root, targetRoot)
    end

    local camera = workspace.CurrentCamera
    if camera then
        camera.CFrame = _CFnew(camera.CFrame.Position, targetRoot.Position)
    end
    tpBatHit()

    ShoxTPBatSetNoCollide(character)
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

    -- Anti-Die aus dem Clean Hub (kein Lagger)
    tpBatStartAntiDie()

    if batDesyncTpSetVisual then batDesyncTpSetVisual(true) end
    updateTpBatButtonVisual(true)
end

function stopAlvaroTP()
    batDesyncTpEnabled = false
    if ShoxTPBatRestoreCollide then ShoxTPBatRestoreCollide() end
    _G.AlvaroTP.on     = false

    if batDesyncTpConn then
        batDesyncTpConn:Disconnect()
        batDesyncTpConn = nil
    end
    _G.AlvaroTP.conn            = nil
    _G.AlvaroTP.hittingCooldown = false
    _tpBatHitCooldown           = false

    tpBatStopAntiDie()

    local meRoot = _G.AlvaroTP.hrp
    if meRoot and meRoot.Parent then
        pcall(function()
            if meRoot.SetNetworkOwner then meRoot:SetNetworkOwner(LP) end
        end)
    end

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
_G.AlvaroTP._charConn = ShoxCharAdded(function(char)
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
        ShoxDropToken = (ShoxDropToken or 0) + 1
        local dropToken = ShoxDropToken
        if dropBrainrotSetVisual then dropBrainrotSetVisual(true) end
        if mobSetDropBR then mobSetDropBR(true) end
        local wasAutoBat = false
        if autoBatEnabled then
            wasAutoBat = true
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
                    local rp = RaycastParams.new()
                    rp.FilterDescendantsInstances = {c}
                    rp.FilterType = Enum.RaycastFilterType.Exclude
                    local rr = workspace:Raycast(r.Position, _V3new(0, -2000, 0), rp)
                    if rr then
                        local off = (h and h.HipHeight or 2) + (r.Size.Y / 2)
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
            while dropActive and ShoxDropToken == dropToken and (_tick() - startTime) < 0.25 do
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
            if ShoxDropToken == dropToken then finishDrop(flingThread) end
        end)
        table.insert(dropConnections, flingThread)
        task.delay(0.35, function()
            if dropActive and ShoxDropToken == dropToken then finishDrop(flingThread) end
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

-- v1.7.2: "Auto [select] after drop": schaltet nach dem Drop die gewaehlte Funktion ein
AUTO_AFTER_DROP_OPTIONS = {"Off", "Auto Bat", "TP Bat", "Auto Left", "Auto Right"}
autoAfterDrop = autoAfterDrop or "Off"
autoAfterDropLabel = nil

function ShoxAfterDrop()
    local sel = autoAfterDrop
    if not ShoxHubState.Running or sel == nil or sel == "Off" then return end
    task.wait(0.12)
    if dropActive then return end
    pcall(function()
        if sel == "Auto Bat" then
            if not autoBatEnabled then
                enableAutoBat()
                if autoBatSetVisual then autoBatSetVisual(true) end
                if mobSetAutoBat then mobSetAutoBat(true) end
            end
        elseif sel == "TP Bat" then
            if not batDesyncTpEnabled then
                toggleBatDesyncTp()
                if batDesyncTpSetVisual then batDesyncTpSetVisual(batDesyncTpEnabled) end
                if mobSetTpBat then mobSetTpBat(batDesyncTpEnabled) end
            end
        elseif sel == "Auto Left" then
            if not autoLeftEnabled then
                autoLeftEnabled = true
                startAutoLeft()
                if autoLeftSetVisual then autoLeftSetVisual(true) end
                if mobSetAutoLeft then mobSetAutoLeft(true) end
            end
        elseif sel == "Auto Right" then
            if not autoRightEnabled then
                autoRightEnabled = true
                startAutoRight()
                if autoRightSetVisual then autoRightSetVisual(true) end
                if mobSetAutoRight then mobSetAutoRight(true) end
            end
        end
    end)
end

do
    local prevDrop = false
    RunService.Heartbeat:Connect(function()
        local cur = (dropActive == true)
        if prevDrop and not cur then task.spawn(ShoxAfterDrop) end
        prevDrop = cur
    end)
end

-- Anti-Lag (v1.7.0 schlank): nur lokale visuelle Effekte, nichts wird geloescht.
local ShoxAL = {
    mat = setmetatable({}, {__mode = "k"}),
    refl = setmetatable({}, {__mode = "k"}),
    en = setmetatable({}, {__mode = "k"}),
    tr = setmetatable({}, {__mode = "k"}),
    lightConn = nil, scanGen = 0, kindCache = {}, q = {}, qh = 1, qt = 0, worker = nil,
}

ShoxAL.shadow = setmetatable({}, {__mode = "k"})
ShoxAL.acc = setmetatable({}, {__mode = "k"})
ShoxAL.expl = setmetatable({}, {__mode = "k"})
ShoxAL.animConn = setmetatable({}, {__mode = "k"})
-- Pro ClassName nur 1x IsA pruefen (vorher ~15 IsA-Aufrufe pro neuem Objekt)
function ShoxAL.kind(obj)
    local cn = obj.ClassName
    local k = ShoxAL.kindCache[cn]
    if k == nil then
        if obj:IsA("BasePart") then k = "part"
        elseif obj:IsA("Decal") or obj:IsA("Texture") then k = "image"
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam")
            or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles")
            or obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") or obj:IsA("Highlight") then k = "effect"
        elseif obj:IsA("Animator") then k = "anim"
        elseif obj:IsA("Explosion") then k = "expl"
        elseif obj:IsA("PostEffect") then k = "post"
        else k = false end
        ShoxAL.kindCache[cn] = k
    end
    return k
end

local function applyAntiLagDerender(obj)
    pcall(function()
        if not obj then return end
        local kind = ShoxAL.kind(obj)
        if not kind then return end
        if obj:GetAttribute("_AmbitiousHubSky") ~= nil then return end
        if kind == "part" then
            if ShoxAL.mat[obj] == nil then
                ShoxAL.mat[obj] = obj.Material
                ShoxAL.refl[obj] = obj.Reflectance
            end
            if obj.Material ~= Enum.Material.SmoothPlastic then obj.Material = Enum.Material.SmoothPlastic end
            if obj.Reflectance ~= 0 then obj.Reflectance = 0 end
            if obj.CastShadow then
                if ShoxAL.shadow[obj] == nil then ShoxAL.shadow[obj] = true end
                obj.CastShadow = false
            end
            -- Accessories/Huete lokal unsichtbar (nur Client, nichts wird geloescht)
            local par = obj.Parent
            if par and par:IsA("Accessory") and ShoxAL.acc[obj] == nil then
                ShoxAL.acc[obj] = true
                obj.LocalTransparencyModifier = 1
            end
        elseif kind == "anim" then
            -- fremde Animationen stoppen; EIGENER Charakter bleibt unberuehrt
            local ch = LP.Character
            if ch and obj:IsDescendantOf(ch) then return end
            for _, tr in ipairs(obj:GetPlayingAnimationTracks()) do pcall(function() tr:Stop(0) end) end
            if not ShoxAL.animConn[obj] then
                ShoxAL.animConn[obj] = obj.AnimationPlayed:Connect(function(tr)
                    if antiLagEnabled then pcall(function() tr:Stop(0) end) end
                end)
            end
        elseif kind == "expl" then
            if ShoxAL.expl[obj] == nil then ShoxAL.expl[obj] = obj.Visible end
            obj.Visible = false
        elseif kind == "image" then
            if ShoxAL.tr[obj] == nil then ShoxAL.tr[obj] = obj.Transparency end
            obj.Transparency = 1
        elseif kind == "post" then
            if obj.Parent == Lighting and skyTheme ~= "Off" then return end
            if ShoxAL.en[obj] == nil then ShoxAL.en[obj] = obj.Enabled end
            obj.Enabled = false
        else
            if ShoxAL.en[obj] == nil then ShoxAL.en[obj] = obj.Enabled end
            obj.Enabled = false
        end
    end)
end

-- Neue Objekte werden in eine Warteschlange gelegt und gedrosselt abgearbeitet,
-- damit Spawns (Effekte, Projektile) keinen Frame-Spike mehr ausloesen.
function ShoxAL.enqueue(obj)
    ShoxAL.qt = ShoxAL.qt + 1
    ShoxAL.q[ShoxAL.qt] = obj
    if not ShoxAL.worker then
        ShoxAL.worker = task.spawn(function()
            while antiLagEnabled and ShoxAL.qh <= ShoxAL.qt do
                local n = 0
                while ShoxAL.qh <= ShoxAL.qt and n < 80 do
                    local o = ShoxAL.q[ShoxAL.qh]
                    ShoxAL.q[ShoxAL.qh] = nil
                    ShoxAL.qh = ShoxAL.qh + 1
                    if o and o.Parent then applyAntiLagDerender(o) end
                    n = n + 1
                end
                task.wait()
            end
            ShoxAL.q, ShoxAL.qh, ShoxAL.qt = {}, 1, 0
            ShoxAL.worker = nil
        end)
    end
end

function enableAntiLag()
    antiLagEnabled = true
    removeAccessoriesEnabled = true -- Kompatibilitaet mit vorhandenen Toggle-Stellen; loescht nichts.

    pcall(function()
        local rs = settings().Rendering
        if ShoxAL.origQL == nil then ShoxAL.origQL = rs.QualityLevel; ShoxAL.origMesh = rs.MeshPartDetailLevel end
        rs.QualityLevel = 1
        rs.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Disabled
    end)

    -- v1.9.0: Lighting (Originalwerte merken)
    pcall(function()
        if not ShoxAL.lt then
            ShoxAL.lt = {GlobalShadows = Lighting.GlobalShadows, FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
                EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale, EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale}
        end
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 1e10
        if ShoxAL.lt.ShadowSoftness == nil then ShoxAL.lt.ShadowSoftness = Lighting.ShadowSoftness end
        Lighting.ShadowSoftness = 0
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
    end)

    -- v1.9.6: Terrain-Deko/Wasser (Originalwerte merken) und Atmosphere aus
    pcall(function()
        local T = workspace:FindFirstChildOfClass("Terrain")
        if T then
            if not ShoxAL.terr then
                ShoxAL.terr = {}
                for _, k in ipairs({"Decoration", "WaterWaveSize", "WaterWaveSpeed", "WaterReflectance"}) do
                    pcall(function() ShoxAL.terr[k] = T[k] end)
                end
            end
            for k, v in pairs({Decoration = false, WaterWaveSize = 0, WaterWaveSpeed = 0, WaterReflectance = 0}) do
                pcall(function() T[k] = v end)
            end
        end
        local atm = Lighting:FindFirstChildOfClass("Atmosphere")
        if atm then
            if ShoxAL.atmDensity == nil then ShoxAL.atmDensity = atm.Density end
            atm.Density = 0
        end
    end)

    if antiLagDescConn then antiLagDescConn:Disconnect() end
    antiLagDescConn = workspace.DescendantAdded:Connect(function(obj)
        if antiLagEnabled then ShoxAL.enqueue(obj) end
    end)

    if ShoxAL.lightConn then ShoxAL.lightConn:Disconnect() end
    ShoxAL.lightConn = Lighting.DescendantAdded:Connect(function(obj)
        if antiLagEnabled then ShoxAL.enqueue(obj) end
    end)

    ShoxAL.scanGen = ShoxAL.scanGen + 1
    local scanGeneration = ShoxAL.scanGen
    task.spawn(function()
        local roots = {workspace, Lighting}
        for _, root in ipairs(roots) do
            if not antiLagEnabled or scanGeneration ~= ShoxAL.scanGen then return end
            local pending = root:GetChildren()
            local cursor = 1
            while cursor <= #pending do
                if not antiLagEnabled or scanGeneration ~= ShoxAL.scanGen then return end
                local obj = pending[cursor]
                pending[cursor] = false
                cursor = cursor + 1
                if obj then
                    applyAntiLagDerender(obj)
                    local children = obj:GetChildren()
                    for i = 1, #children do pending[#pending + 1] = children[i] end
                end
                if cursor % 250 == 0 then task.wait() end
            end
        end
    end)
end

function disableAntiLag()
    antiLagEnabled = false
    ShoxAL.scanGen = ShoxAL.scanGen + 1
    removeAccessoriesEnabled = false
    -- v1.8.0: Qualitaet/Mesh-Detail wiederherstellen (vorher blieb alles auf Stufe 1)
    if ShoxAL.origQL ~= nil then
        pcall(function()
            local rs = settings().Rendering
            rs.QualityLevel = ShoxAL.origQL
            if ShoxAL.origMesh ~= nil then rs.MeshPartDetailLevel = ShoxAL.origMesh end
        end)
        ShoxAL.origQL, ShoxAL.origMesh = nil, nil
    end

    if antiLagDescConn then antiLagDescConn:Disconnect(); antiLagDescConn = nil end
    if ShoxAL.lightConn then ShoxAL.lightConn:Disconnect(); ShoxAL.lightConn = nil end
    ShoxAL.q, ShoxAL.qh, ShoxAL.qt = {}, 1, 0
    if ShoxAL.lt then
        pcall(function() for k, v in pairs(ShoxAL.lt) do Lighting[k] = v end end)
        ShoxAL.lt = nil
    end
    if ShoxAL.terr then
        pcall(function()
            local T = workspace:FindFirstChildOfClass("Terrain")
            if T then for k, v in pairs(ShoxAL.terr) do pcall(function() T[k] = v end) end end
        end)
        ShoxAL.terr = nil
    end
    if ShoxAL.atmDensity ~= nil then
        pcall(function()
            local atm = Lighting:FindFirstChildOfClass("Atmosphere")
            if atm then atm.Density = ShoxAL.atmDensity end
        end)
        ShoxAL.atmDensity = nil
    end
    for an, c in pairs(ShoxAL.animConn) do pcall(function() c:Disconnect() end); ShoxAL.animConn[an] = nil end
    for obj in pairs(ShoxAL.shadow) do pcall(function() obj.CastShadow = true end); ShoxAL.shadow[obj] = nil end
    for obj in pairs(ShoxAL.acc) do pcall(function() obj.LocalTransparencyModifier = 0 end); ShoxAL.acc[obj] = nil end
    for obj, v in pairs(ShoxAL.expl) do pcall(function() obj.Visible = v end); ShoxAL.expl[obj] = nil end

    for obj, mat in pairs(ShoxAL.mat) do
        if obj and obj.Parent then
            pcall(function()
                obj.Material = mat
                obj.Reflectance = ShoxAL.refl[obj] or 0
            end)
        end
        ShoxAL.mat[obj] = nil
        ShoxAL.refl[obj] = nil
    end
    for obj, v in pairs(ShoxAL.en) do
        if obj and obj.Parent then pcall(function() obj.Enabled = v end) end
        ShoxAL.en[obj] = nil
    end
    for obj, v in pairs(ShoxAL.tr) do
        if obj and obj.Parent then pcall(function() obj.Transparency = v end) end
        ShoxAL.tr[obj] = nil
    end
end

-- v1.9.11: Anti Bat = Orvyn Anti Bat (Impuls-Kern 1:1) + Ragdoll-Recovery.
ShoxAntiBatEnabled = false
ShoxAntiBatConn = nil
ShoxAntiBatRecConn = nil
ShoxAntiBatBusy = false
ShoxAntiBatBusyAt = 0
ShoxAntiBatSetVisual = nil

function ShoxAntiBatStop()
    if ShoxAntiBatConn then ShoxAntiBatConn:Disconnect(); ShoxAntiBatConn = nil end
    if ShoxAntiBatRecConn then ShoxAntiBatRecConn:Disconnect(); ShoxAntiBatRecConn = nil end
    ShoxAntiBatBusy = false
end

function ShoxAntiBatStart()
    ShoxAntiBatStop()
    -- Teil 1: Impuls wie Orvyn: X/Z auf 1000, nach RenderStepped wird dein echtes X/Z-Tempo zurueckgesetzt.
    -- Root wird jeden Frame neu geholt (laeuft nach Respawn weiter), Y bleibt unangetastet (Infinity Jump geht weiter).
    -- Laeuft immer, auch bei Auto Left/Right. Busy verhindert nur, dass zwei Impulse ueberlappen (sonst bliebe 1000 stehen).
    ShoxAntiBatConn = RunService.Heartbeat:Connect(function()
        if not ShoxAntiBatEnabled then return end
        if ShoxAntiBatBusy and os.clock() - ShoxAntiBatBusyAt < 0.25 then return end
        local char = LP.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root or not root.Parent then return end
        ShoxAntiBatBusy = true
        ShoxAntiBatBusyAt = os.clock()
        local origXZ = _V3new(root.Velocity.X, 0, root.Velocity.Z)
        root.Velocity = _V3new(1000, root.Velocity.Y, 1000)
        RunService.RenderStepped:Wait()
        if root and root.Parent then
            root.Velocity = _V3new(origXZ.X, root.Velocity.Y, origXZ.Z)
        end
        ShoxAntiBatBusy = false
    end)
    -- Teil 2: Ragdoll/Physics-Recovery (Clean + Orvyn): Steuerung zurueck, Gelenke an
    local lastMotor = 0
    ShoxAntiBatRecConn = RunService.Heartbeat:Connect(function()
        if not ShoxAntiBatEnabled then return end
        local char = LP.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if hum then
            local st = hum:GetState()
            if st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Ragdoll
                or st == Enum.HumanoidStateType.FallingDown then
                hum:ChangeState(Enum.HumanoidStateType.Running)
                local cam = workspace.CurrentCamera
                if cam then cam.CameraSubject = hum end
                pcall(function()
                    local pm = LP:FindFirstChild("PlayerScripts") and LP.PlayerScripts:FindFirstChild("PlayerModule")
                    local cm = pm and pm:FindFirstChild("ControlModule")
                    if cm then require(cm):Enable() end
                end)
                if root then
                    root.Velocity = _V3new(0, 0, 0)
                    root.RotVelocity = _V3new(0, 0, 0)
                end
            end
        end
        local now = os.clock()
        if now - lastMotor >= 0.3 then
            lastMotor = now
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("Motor6D") and not d.Enabled then d.Enabled = true end
            end
        end
    end)
end

function ShoxAntiBatSet(on)
    ShoxAntiBatEnabled = on and true or false
    if ShoxAntiBatEnabled then ShoxAntiBatStart() else ShoxAntiBatStop() end
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
    do local bgi = btnFrame:FindFirstChild("ShoxBgImg"); if bgi then bgi:SetAttribute("ShoxActive", active and true or false); ShoxBgTune(bgi) end end
    local bg = btnFrame:FindFirstChild("BtnGrad")
    local label = btnFrame:FindFirstChild("TextLabel")
    local stroke = btnFrame:FindFirstChildOfClass("UIStroke")
    local accent = btnFrame:FindFirstChild("Accent")
    local theme = getThemeColor()
    local h, sat = theme:ToHSV()
    local bright = Color3.fromHSV(h, math.clamp(sat * 0.8, 0, 1), 1)
    btnFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)

    if active then
        if bg then
            bg.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, bright),
                ColorSequenceKeypoint.new(1.00, theme),
            })
        end
        if label then label.TextColor3 = Color3.fromRGB(12, 12, 16) end
        if stroke then
            stroke.Color = bright
            stroke.Thickness = 2
            stroke.Transparency = 0
        end
        if accent then accent.BackgroundColor3 = Color3.fromRGB(12, 12, 16) end
    else
        if bg then
            bg.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(26, 26, 36)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(10, 10, 15)),
            })
        end
        if label then label.TextColor3 = Color3.fromRGB(255, 255, 255) end
        if stroke then
            stroke.Color = theme
            stroke.Thickness = 1.4
            stroke.Transparency = 0.35
        end
        if accent then accent.BackgroundColor3 = theme end
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
            if p ~= LP and noPlayerCollisionEnabled then -- v1.9.8: nur mit Toggle
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
           and not dropActive and not batDesyncTpEnabled
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

        if speedLabel and os.clock() - (ShoxSpeedLblT or 0) > 0.1 then
            ShoxSpeedLblT = os.clock()
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
end


function stopAllBackgroundTasks()
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
        antiBat = ShoxAntiBatEnabled,
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
        instaResetKey = {kb = KB.InstaReset.kb and KB.InstaReset.kb.Name, gp = KB.InstaReset.gp and KB.InstaReset.gp.Name},
        instaResetFloatingPos = instaResetFloatingPos,
        bodyLockEnabled = bodyLockEnabled,
        bodyLockRange = bodyLockRange,
        bodyLockOffWhileCarry = bodyLockOffWhileCarry,
        autoAfterDrop = autoAfterDrop,
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
    CarrySystem:setLaggerSpeed(LAGGER_SPEED)
    CarrySystem:setLaggerCarrySpeed(LAGGER_CARRY_SPEED)
    CONFIG.STEAL_RANGE = readNumber(data.stealRadius, CONFIG.STEAL_RANGE, 1, 500)
    if radInput then radInput.Text = tostring(CONFIG.STEAL_RANGE) end
    uiLocked = data.lockUI == true
    editModeEnabled = false
    mobileButtonsLocked = data.mobileButtonsLocked == true
    if data.antiRagdollMode then
        antiRagdollMode = data.antiRagdollMode
    else
        antiRagdollMode = data.antiRagdoll and "v2" or "off"
    end
    antiDieEnabled = data.antiDieEnabled or false
    ShoxAntiBatEnabled = data.antiBat == true
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

    katanaSkinEnabled = false
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
    ShoxHubAutoTPDownHeight = math.clamp(tonumber(data.shoxHubAutoTPDownHeight) or ShoxHubAutoTPDownHeight, 1, 500)
    if ShoxHubAutoTPDownHeightBox then ShoxHubAutoTPDownHeightBox.Text = tostring(ShoxHubAutoTPDownHeight) end
    ShoxHubShowE01Warning = data.shoxHubShowE01Warning == true
    if ShoxHubAutoTPDownSetVisual then ShoxHubAutoTPDownSetVisual(ShoxHubAutoTPDown) end
    if ShoxHubShowE01WarningSetVisual then ShoxHubShowE01WarningSetVisual(ShoxHubShowE01Warning) end
    tpBatVersion = 1

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
    lk(KB.InstaReset, data.instaResetKey)
    if type(data.mobileButtonPositions) == "table" then savedButtonPositions = data.mobileButtonPositions end
    do -- v1.7.2: neues Raster (Insta Reset neben Drop): alte Standardpositionen mitziehen
        local oldOrder = {DropBR=0, TPBat=1, AutoLeft=2, AutoBat=3, AutoRight=4, TpDown=5, Carry=6, Lagger1=7, Lagger2=8}
        if savedButtonPositions and not savedButtonPositions.InstaReset then
            for nm, o in pairs(oldOrder) do
                local sp = savedButtonPositions[nm]
                if type(sp) == "table" and sp.X == (o % 3) * 68 and sp.Y == math.floor(o / 3) * 68 then
                    local nx, ny = getDefaultButtonPosition(nm)
                    savedButtonPositions[nm] = {X = nx, Y = ny}
                end
            end
        end
    end
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
    if data.bodyLockOffWhileCarry ~= nil then
        bodyLockOffWhileCarry = (data.bodyLockOffWhileCarry == true)
        if bodyLockCarrySetVisual then bodyLockCarrySetVisual(bodyLockOffWhileCarry) end
    end
    if type(data.autoAfterDrop) == "string" then
        local okOpt = false
        for _, o in ipairs(AUTO_AFTER_DROP_OPTIONS) do if o == data.autoAfterDrop then okOpt = true end end
        autoAfterDrop = okOpt and data.autoAfterDrop or "Off"
        if autoAfterDropLabel then autoAfterDropLabel.Text = autoAfterDrop end
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
    if savedBatAimbotSpeed == 50 or savedBatAimbotSpeed == 90 or savedBatAimbotSpeed == 58 then
        BAT_AIMBOT_SPEED = 60
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
        warn("[ShoxHub] loadAllSettings partial failure: " .. tostring(loadErr))
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
    if ShoxSetLockBtnsVisual then ShoxSetLockBtnsVisual(false) end
    if ShoxHideMasterVisual then ShoxHideMasterVisual(false) end
    for _, f in pairs(ShoxHideItemVisuals or {}) do pcall(f) end
    safeSet(setInstaGrab, false)
    safeSet(batDesyncTpSetVisual, false)
    safeSet(setESPVIsual, false)
    safeSet(bodyLockSetVisual, false)
    safeSet(setNeonWeatherVisual, false)
    safeSet(setAntiDieVisual, false)
    safeSet(ShoxAntiBatSetVisual, false)
    ShoxAntiBatSet(false)
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
    bodyLockOffWhileCarry = true
    if bodyLockCarrySetVisual then bodyLockCarrySetVisual(true) end
    autoAfterDrop = "Off"
    if autoAfterDropLabel then autoAfterDropLabel.Text = "Off" end
    tpBatVersion = 1
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
    applyBackground(1)
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

-- v1.9.9: Spin (Speed-Tab). Dreht den Charakter im Uhrzeigersinn, Bewegung/Speed bleiben unberuehrt (Speed laeuft ueber MoveDirection).
ShoxSpinEnabled = false
ShoxSpinConn = nil
ShoxSpinOwnsAR = false
ShoxSpinRadPerSec = 26
function ShoxSpinSet(on)
    ShoxSpinEnabled = (on == true)
    if ShoxSpinConn then pcall(function() ShoxSpinConn:Disconnect() end); ShoxSpinConn = nil end
    if not ShoxSpinEnabled then
        if ShoxSpinOwnsAR then
            ShoxSpinOwnsAR = false
            pcall(function()
                local c = LP.Character
                local h = c and c:FindFirstChildOfClass("Humanoid")
                if h then h.AutoRotate = true end
            end)
        end
        return
    end
    ShoxSpinConn = RunService.Heartbeat:Connect(function(dt)
        local c = LP.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if not hrp or not h or h.Health <= 0 then return end
        if h.AutoRotate then h.AutoRotate = false; ShoxSpinOwnsAR = true end
        hrp.CFrame = hrp.CFrame * CFrame.Angles(0, -ShoxSpinRadPerSec * math.min(dt, 0.1), 0)
    end)
    ShoxHubState:Track(ShoxSpinConn)
end

-- v1.9.9: Reset Positions. Bugs davor: Auto-Steal-Bar ging nach UNTEN (1,-60) statt auf die Default-Position,
-- gespeicherte Positionen wurden nur bei vorhandenem MobilePanel geloescht, und es wurde nie gespeichert
-- (beim naechsten Start kamen die alten Positionen zurueck).
function resetFloatingPositions()
    pcall(function()
        local container = MobilePanel and MobilePanel:FindFirstChild("FloatingPanel")
        if container then
            container.AnchorPoint = Vector2.new(1, 0)
            container.Position = UDim2.new(1, -8, 0, 40)
            local bc = container:FindFirstChild("ButtonsContainer")
            if bc then
                for _, btn in ipairs(bc:GetChildren()) do
                    if btn:IsA("GuiObject") then
                        local defX, defY = getDefaultButtonPosition(btn.Name)
                        btn.Position = UDim2.new(0, defX, 0, defY)
                    end
                end
            end
        end
    end)
    pcall(function()
        if instaResetFloatingButton and instaResetFloatingButton:FindFirstChild("Frame") then
            instaResetFloatingButton.Frame.Position = UDim2.new(0.5, 90, 0, 10)
        end
    end)
    pcall(function()
        if pbFrame then pbFrame.Position = UDim2.new(0.5, -118, 0, 56) end
    end)
    savedMobilePanelPos = nil
    savedButtonPositions = {}
    savedProgressBarPos = nil
    instaResetFloatingPos = nil
    if not _isResetting then pcall(saveAllSettings) end
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
        pcall(ShoxAntiBatStop)
        if antiFlingEnabled then AntiFlingShieldModule.stop() end
        stopUnwalk()
        disableAutoBat()
        if batDesyncTpEnabled then stopBatDesyncTp() end
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
        CarrySystem:setLaggerSpeed(LAGGER_SPEED)
        CarrySystem:setLaggerCarrySpeed(LAGGER_CARRY_SPEED)
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
        bodyLockOffWhileCarry = true
        autoAfterDrop = "Off"
        BAT_AIMBOT_SPEED = 60
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
        katanaSkinEnabled = false
        minecraftBatSkinEnabled = false
        minecraftBatSkinColorMode = "Default"
        MinecraftBatSkin.State.enabled = false
        MinecraftBatSkin.State.colorMode = "Default"
        pcall(MinecraftBatSkin.Remove)
        floatingButtonScale = 1
        if batDesyncTpEnabled then stopBatDesyncTp() end
        tpBatVersion = 1
        currentAnimPack = "Off"
        stopAnimPack()
        currentOutfitIndex = 1
        currentColorTheme = "Monochrome"
        selectedColor = COLOR_THEMES["Monochrome"]
        backgroundIndex = 1
        backgroundImageTransparency = 0.35
        applyBackground(1)
        if ShoxBgOpacitySet then ShoxBgOpacitySet(65) end
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
        DropBR = 0, InstaReset = 1, TPBat = 2, AutoLeft = 3, AutoBat = 4, AutoRight = 5,
        TpDown = 6, Carry = 7, Lagger1 = 8, Lagger2 = 9
    }
    local order = orderMap[btnName] or 0
    local row = _floor(order / 3)
    local col = order % 3
    return col * (BTN_W + GAP), row * (BTN_H + GAP)
end

_G.AmbitiousHideMobileButtons = _G.AmbitiousHideMobileButtons == true
_G.AmbitiousMobileHideList    = type(_G.AmbitiousMobileHideList) == "table" and _G.AmbitiousMobileHideList or {}

function _G.AmbitiousMobileHideIncluded(key)
    -- v1.9.10: Liste leer -> Master versteckt ALLE Buttons (vorher: nichts, deshalb ging Hide "gar nicht").
    -- Sobald du einzelne Buttons anfasst, gilt deine Auswahl.
    local list = _G.AmbitiousMobileHideList
    if next(list) == nil then return true end
    return list[key] == true
end

function _G.AmbitiousApplyMobileButtonsHidden()
    local hideAll = (_G.AmbitiousHideMobileButtons == true)
    local panels = {
        "FictionHubMobilePanel",
        "TpBatButton",
        "InstaResetButton",
    }
    local keyByPanel = {
        TpBatButton      = "tpBat",
        InstaResetButton = "instaReset",
    }
    for _, name in ipairs(panels) do
        local sg = nil
        if name == "FictionHubMobilePanel" and MobilePanel and MobilePanel.Parent then sg = MobilePanel end
        if not sg then pcall(function() sg = game:GetService("CoreGui"):FindFirstChild(name) end) end
        if not sg then
            local pg = LP:FindFirstChildOfClass("PlayerGui")
            sg = pg and pg:FindFirstChild(name) or nil
        end
        if not sg and gethui then
            pcall(function() sg = gethui():FindFirstChild(name) end)
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
                        InstaReset = "instaReset",
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
            _G.InstaResetBusy = true
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
                _G.InstaResetBusy = false
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

        ShoxCharAdded(function()
            stopResetSequence = true
            if resetThread then pcall(task.cancel, resetThread); resetThread = nil end
            resetCooldown    = false
            _G.InstaResetBusy = false
            currentResetChar = nil
            cameraLocked     = false
        end)

        task.spawn(function()
            while ShoxHubState.Running do
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
    local ROW_BORDER = Color3.fromRGB(71,71,71)
    local WHITE = Color3.fromRGB(255,255,255)
    local GRAY = Color3.fromRGB(60,60,60)
    local INP = Color3.fromRGB(15,15,15)
    local OFF = Color3.fromRGB(26, 26, 26)
    local TAB_ACTIVE = SILVER
    local TAB_INACT = SILVER_DARK
    local SECT_LBL = SILVER
    local HOV = Color3.fromRGB(25,25,25)
    local DOT_ON = SILVER
    local ON_COLOR = SILVER
    local STROKE_COLOR = Color3.fromRGB(50,50,50)
    local GUI_W, GUI_H = 330, 500
    -- v1.9.9: gleicher Verlauf wie Mobile-Buttons und Steal-Bar
    local MOB_GRAD = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(71, 71, 71)),
        ColorSequenceKeypoint.new(0.35, Color3.fromRGB(29, 29, 29)),
        ColorSequenceKeypoint.new(0.70, Color3.fromRGB(10, 10, 10)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(0, 0, 0)),
    })

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
    main.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    main.BackgroundTransparency = 0
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 16)
    do -- v1.9.1: Verlauf wie die Mobile-Buttons
        local mg = Instance.new("UIGradient", main)
        mg.Rotation = 90
        mg.Color = MOB_GRAD
    end
    do -- v1.7.2: dezenter Fensterrahmen (neutral)
        local mainStroke = Instance.new("UIStroke", main)
        mainStroke.Color = Color3.fromRGB(71, 71, 71)
        mainStroke.Thickness = 1.2
        mainStroke.Transparency = 0.35
    end

    ShoxBgAttach(main, 16, 1)
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
    titleImage.TextColor3 = Color3.fromRGB(225, 225, 225)
    titleImage.Font = SHOX_UI_FONT
    titleImage.TextScaled = true
    titleImage.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    titleImage.TextStrokeTransparency = 1
    titleImage.ZIndex = 21
    local titleConstraint = Instance.new("UITextSizeConstraint", titleImage)
    titleConstraint.MaxTextSize = 54
    titleConstraint.MinTextSize = 22
    do
        local ta = Instance.new("Frame", titleFrame)
        ta.Name = "TitleAccent"
        ta.AnchorPoint = Vector2.new(0.5, 1)
        ta.Position = UDim2.new(0.5, 0, 1, -4)
        ta.Size = UDim2.new(0.42, 0, 0, 3)
        ta.BackgroundColor3 = getThemeColor()
        ta.BorderSizePixel = 0
        ta.ZIndex = 21
        Instance.new("UICorner", ta).CornerRadius = UDim.new(1, 0)
    end

    local closeBtn = Instance.new("TextButton", main)
    closeBtn.Size = UDim2.new(0, 32, 0, 32)
    closeBtn.Position = UDim2.new(1, -42, 0, 8)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.BackgroundTransparency = 0.05
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "−"
    closeBtn.TextColor3 = WHITE
    closeBtn.Font = SHOX_UI_FONT
    closeBtn.TextSize = 26
    closeBtn.AutoButtonColor = false
    closeBtn.ZIndex = 200
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 10)
    do
        local cg = Instance.new("UIGradient", closeBtn); cg.Rotation = 90; cg.Color = MOB_GRAD
        local cs = Instance.new("UIStroke", closeBtn); cs.Color = Color3.fromRGB(71, 71, 71); cs.Thickness = 1; cs.Transparency = 0.45
    end

    closeBtn.MouseEnter:Connect(function()
        TS:Create(closeBtn, TweenInfo.new(0.12), {TextColor3 = Color3.fromRGB(20, 20, 20), BackgroundColor3 = getThemeColor()}):Play()
    end)
    closeBtn.MouseLeave:Connect(function()
        TS:Create(closeBtn, TweenInfo.new(0.12), {TextColor3 = WHITE, BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
    end)

    miniBtn = Instance.new("TextButton", gui)
    miniBtn.Size = UDim2.new(0, 160, 0, 42)
    miniBtn.Position = UDim2.new(0, 16, 0, 58)
    miniBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    miniBtn.BackgroundTransparency = 0
    miniBtn.BorderSizePixel = 0
    miniBtn.ClipsDescendants = true
    miniBtn.Text = ""
    miniBtn.TextColor3 = Color3.fromRGB(211, 211, 211)
    miniBtn.Font = SHOX_UI_FONT
    miniBtn.TextSize = 16
    miniBtn.ZIndex = 20
    miniBtn.Visible = false
    Instance.new("UICorner", miniBtn).CornerRadius = UDim.new(1, 0)
    do
        local mgd = Instance.new("UIGradient", miniBtn); mgd.Rotation = 90; mgd.Color = MOB_GRAD
        local mst = Instance.new("UIStroke", miniBtn); mst.Color = Color3.fromRGB(71, 71, 71); mst.Thickness = 1; mst.Transparency = 0.45
    end

    local miniTitleImage = Instance.new("TextLabel", miniBtn)
    miniTitleImage.Name = "MiniTitleImage"
    miniTitleImage.AnchorPoint = Vector2.new(0.5, 0.5)
    miniTitleImage.Size = UDim2.new(0.88, 0, 0.88, 0)
    miniTitleImage.Position = UDim2.new(0.5, 0, 0.5, 0)
    miniTitleImage.BackgroundTransparency = 1
    miniTitleImage.Text = "SHOX"
    miniTitleImage.TextColor3 = Color3.fromRGB(225, 225, 225)
    miniTitleImage.Font = SHOX_UI_FONT
    miniTitleImage.TextScaled = true
    miniTitleImage.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    miniTitleImage.TextStrokeTransparency = 1
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

    local function ShoxTargetScale() return math.max((tonumber(uiScaleValue) or 100) / 100, 0.2) end

    showGui = function()
        if not main or not miniBtn or not mainUIScale then return end
        local generation = cancelSlideTween()
        isMainSliding = true
        main.Position = mainOriginalPos
        mainUIScale.Scale = 0.02
        main.Visible = true
        miniBtn.Visible = false
        local tween = TS:Create(mainUIScale, TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = ShoxTargetScale()})
        slideTween = tween
        tween.Completed:Connect(function()
            if generation ~= slideTweenGeneration or slideTween ~= tween then return end
            slideTween = nil
            isMainSliding = false
            mainUIScale.Scale = ShoxTargetScale()
        end)
        tween:Play()
    end

    hideGui = function()
        if not main or not miniBtn or not mainUIScale then return end
        if not main.Visible then
            cancelSlideTween()
            isMainSliding = false
            miniBtn.Visible = true
            return
        end
        local generation = cancelSlideTween()
        isMainSliding = true
        local tween = TS:Create(mainUIScale, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Scale = 0.02})
        slideTween = tween
        tween.Completed:Connect(function(playbackState)
            if generation ~= slideTweenGeneration or slideTween ~= tween then return end
            slideTween = nil
            if playbackState == Enum.PlaybackState.Completed then
                main.Visible = false
                mainUIScale.Scale = ShoxTargetScale()
                miniBtn.Size = UDim2.new(0, 70, 0, 18)
                miniBtn.Visible = true
                TS:Create(miniBtn, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 160, 0, 42)}):Play()
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

    local function paintTab(b, active)
        local g = b:FindFirstChildOfClass("UIGradient")
        local st = b:FindFirstChildOfClass("UIStroke")
        if active then
            if g then g.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 255, 255)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(190, 190, 190)),
            }) end
            b.TextColor3 = Color3.fromRGB(12, 12, 16)
            if st then st.Color = Color3.fromRGB(255, 255, 255); st.Thickness = 2; st.Transparency = 0 end
        else
            if g then g.Color = MOB_GRAD end
            b.TextColor3 = Color3.fromRGB(235, 235, 235)
            if st then st.Color = ROW_BORDER; st.Thickness = 1; st.Transparency = 0.45 end
        end
    end

    local tabs = {"Combat", "Speed", "Visual", "Settings", "Keybinds"}
    tabButtons = {}
    contentPages = {}

    for i, name in ipairs(tabs) do
        local btn = Instance.new("TextButton", tabBar)
        btn.Size = UDim2.new(0.19, 0, 1, -6)
        btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        btn.BackgroundTransparency = 0.05
        btn.BorderSizePixel = 0
        btn.Text = name
        btn.TextColor3 = TAB_INACT
        btn.Font = SHOX_UI_FONT
        btn.TextSize = 12
        btn.AutoButtonColor = false
        btn.ZIndex = 11
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)
        local tg = Instance.new("UIGradient", btn); tg.Rotation = 90; tg.Color = MOB_GRAD
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
        page.ScrollBarImageColor3 = Color3.fromRGB(31, 31, 31)
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
            for _, b in ipairs(tabButtons) do paintTab(b, false) end
            paintTab(btn, true)
        end)

        table.insert(tabButtons, btn)
    end

    for _, b in ipairs(tabButtons) do paintTab(b, b == tabButtons[1]) end

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
        l.TextColor3 = Color3.fromRGB(200, 200, 200)
        l.Font = Enum.Font.GothamBold
        l.TextSize = 13
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextStrokeColor3 = Color3.fromRGB(60,60,60)
        l.TextStrokeTransparency = 1
        l.ZIndex = 8
        local line = Instance.new("Frame", f)
        line.Size = UDim2.new(1, -24, 0, 1.5)
        line.Position = UDim2.new(0, 12, 1, -4)
        line.BackgroundColor3 = Color3.fromRGB(201, 201, 201)
        line.BackgroundTransparency = 0.6
        line.BorderSizePixel = 0
        line.ZIndex = 8
        local sa = Instance.new("Frame", f)
        sa.Size = UDim2.new(0, 34, 0, 3)
        sa.Position = UDim2.new(0, 12, 1, -5)
        sa.BackgroundColor3 = getThemeColor()
        sa.BorderSizePixel = 0
        sa.ZIndex = 9
        Instance.new("UICorner", sa).CornerRadius = UDim.new(1, 0)
        return f
    end

    local function mkRow(page, h)
        local f = Instance.new("Frame", page)
        f.Size = UDim2.new(1, -4, 0, h or 38)
        f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        f.BackgroundTransparency = 0.12
        f.BorderSizePixel = 0
        f.LayoutOrder = getNextOrder(page)
        f.ZIndex = 7
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 14)
        local rg = Instance.new("UIGradient", f)
        rg.Rotation = 90
        rg.Color = MOB_GRAD
        local rowStroke = Instance.new("UIStroke", f)
        rowStroke.Color = ROW_BORDER
        rowStroke.Thickness = 1
        rowStroke.Transparency = 0.45
        f.MouseEnter:Connect(function()
            TS:Create(rowStroke, TweenInfo.new(0.12), {Color = Color3.fromRGB(221, 221, 221), Transparency = 0.1}):Play()
        end)
        f.MouseLeave:Connect(function()
            TS:Create(rowStroke, TweenInfo.new(0.12), {Color = ROW_BORDER, Transparency = 0.45}):Play()
        end)
        return f
    end

    local function mkLabel(row, txt)
        local l = Instance.new("TextLabel", row)
        l.Size = UDim2.new(0.55, 0, 1, 0)
        l.Position = UDim2.new(0, 10, 0, 0)
        l.BackgroundTransparency = 1
        l.Text = txt
        l.TextColor3 = Color3.fromRGB(205, 205, 205)
        l.Font = SHOX_UI_FONT
        l.TextSize = 12
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
        dot.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
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
            BackgroundColor3 = on and Color3.fromRGB(255,255,255) or Color3.fromRGB(18, 18, 18),
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
        container.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
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
        glow.BackgroundColor3 = Color3.fromRGB(221, 221, 221)
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
            d.BackgroundColor3 = Color3.fromRGB(151, 151, 151)
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
                d.BackgroundColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(151, 151, 151)
                d.Size = active and UDim2.new(0, 10, 0, 5) or UDim2.new(0, 5, 0, 5)
            end
        end

        local function refreshDotsAnimated()
            local activeDot = math.clamp(math.floor(((currentIdx - 1) / math.max(#options - 1, 1)) * (#dots - 1) + 1.5), 1, #dots)
            for i, d in ipairs(dots) do
                local active = (i == activeDot)
                TS:Create(d, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {
                    BackgroundColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(151, 151, 151),
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
            TS:Create(contStroke, TweenInfo.new(0.12), {Color = Color3.fromRGB(221, 221, 221), Transparency = 0}):Play()
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
    do local row = mkRow(speedPage, 38); mkLabel(row, "Lagger Normal");   laggerBox  = mkBox(row, LAGGER_SPEED, 50, 56, function(v) if v > 0 and v <= 500 then LAGGER_SPEED = v; CarrySystem:setLaggerSpeed(v); if carrySysLaggerBox then carrySysLaggerBox.Text = tostring(v) end; saveAllSettings() end end) end
    do local row = mkRow(speedPage, 38); mkLabel(row, "Lagger Carry");    lagger2Box = mkBox(row, LAGGER_CARRY_SPEED, 50, 56, function(v) if v > 0 and v <= 500 then LAGGER_CARRY_SPEED = v; CarrySystem:setLaggerCarrySpeed(v); if carrySysLaggerCarryBox then carrySysLaggerCarryBox.Text = tostring(v) end; saveAllSettings() end end) end

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
        clk.MouseButton1Click:Connect(function() doTpDown(true) end)
        local actLbl = Instance.new("TextLabel", row)
        actLbl.Size = UDim2.new(0, 70, 1, 0)
        actLbl.Position = UDim2.new(1, -78, 0, 0)
        actLbl.BackgroundTransparency = 1
        actLbl.Text = "ACTIVATE"
        actLbl.TextColor3 = Color3.fromRGB(231, 231, 231)
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
        mkLabel(row, "TP Down Y (Welt-Y)")
        ShoxHubAutoTPDownHeightBox = mkBox(row, ShoxHubAutoTPDownHeight, 50, 56, function(value)
            ShoxHubAutoTPDownHeight = math.clamp(_floor((tonumber(value) or 20) + 0.5), 1, 500)
            if ShoxHubAutoTPDownHeightBox then ShoxHubAutoTPDownHeightBox.Text = tostring(ShoxHubAutoTPDownHeight) end
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

    mkSect(speedPage, "Spin")
    ShoxSpinSetVisual = mkToggle(speedPage, "Spin Clockwise", function(on)
        ShoxSpinSet(on)
    end)
    do
        local row = mkRow(speedPage, 38)
        mkLabel(row, "Spin Speed")
        mkBox(row, ShoxSpinRadPerSec, 50, 56, function(v)
            if v > 0 and v <= 100 then ShoxSpinRadPerSec = v end
        end)
    end

    local combatPage = contentPages["Combat"]

    mkSect(combatPage, "Bat Aimbot")
    autoBatSetVisual = mkToggle(combatPage, "Bat Aimbot", function(on)
        if on then enableAutoBat() else disableAutoBat() end
        if mobSetAutoBat then mobSetAutoBat(on) end
    end)
    do local row = mkRow(combatPage, 38); mkLabel(row, "Bat Aimbot Speed"); batSpeedBox = mkBox(row, BAT_AIMBOT_SPEED, 50, 56, function(v) if v > 0 and v <= 200 then BAT_AIMBOT_SPEED = v; saveAllSettings() end end) end

    batDesyncTpSetVisual = mkToggle(combatPage, "TP BAT", function(on)
        if on then
            if not batDesyncTpEnabled then toggleBatDesyncTp() end
        else
            if batDesyncTpEnabled then toggleBatDesyncTp() end
        end
    end)
    if batDesyncTpSetVisual then batDesyncTpSetVisual(batDesyncTpEnabled) end

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
                saveAllSettings()
            end
        end)
    end

    bodyLockCarrySetVisual = mkToggle(combatPage, "Auto Off While Carry", function(on)
        bodyLockOffWhileCarry = on
        saveAllSettings()
    end)
    if bodyLockCarrySetVisual then bodyLockCarrySetVisual(bodyLockOffWhileCarry == true) end

    do
        local row = mkRow(combatPage, 38)
        mkLabel(row, "Auto After Drop")
        autoAfterDropLabel = mkNeoSelector(row, autoAfterDrop, AUTO_AFTER_DROP_OPTIONS, function(selected)
            autoAfterDrop = selected
            saveAllSettings()
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

    ShoxAntiBatSetVisual = mkToggle(combatPage, "Anti Bat", function(on)
        ShoxAntiBatSet(on)
        saveAllSettings()
    end)

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
        previewPlaceholder.Font = Enum.Font.GothamBlack
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

    do -- v1.9.10: Sichtbarkeit der Hintergrundbilder (Fenster, Steal-Bar, Mobile-Buttons)
        local row = mkRow(visualPage, 38)
        mkLabel(row, "Background Visibility")
        ShoxBgOpacitySet = mkSlider(row, 0, 100, _floor((1 - backgroundImageTransparency) * 100 + 0.5), function(v)
            backgroundImageTransparency = 1 - (tonumber(v) or 65) / 100
            applyBackground(backgroundIndex)
            ShoxBgSaveT = os.clock()
            task.delay(0.6, function()
                if os.clock() - (ShoxBgSaveT or 0) >= 0.55 then pcall(saveAllSettings) end
            end)
        end)
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
        info.TextColor3 = Color3.fromRGB(198, 198, 198)
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
        ShoxSetLockBtnsVisual = mkToggle(configPage, "Lock Buttons", function(on)
            mobileButtonsLocked = (on == true)
            _isDraggingButton = false
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
        ShoxSetLockBtnsVisual(mobileButtonsLocked)
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
        ShoxHideMasterVisual = function(s) sv(s) end
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

        ShoxHideItemVisuals = {}
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
            lbl.TextColor3 = Color3.fromRGB(236, 236, 236)
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
            dot.BackgroundColor3 = startOn and Color3.fromRGB(255,255,255) or Color3.fromRGB(18, 18, 18)
            dot.BorderSizePixel = 0
            dot.ZIndex = 9
            Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

            local clk = Instance.new("TextButton", track)
            clk.Size = UDim2.new(1,0,1,0)
            clk.BackgroundTransparency = 1
            clk.Text = ""
            clk.AutoButtonColor = false
            clk.ZIndex = 10
            ShoxHideItemVisuals[item.key] = function() animPill(track, dot, _G.AmbitiousMobileHideIncluded(item.key)) end
            clk.MouseButton1Click:Connect(function()
                local on = not _G.AmbitiousMobileHideIncluded(item.key)
                if next(_G.AmbitiousMobileHideList) == nil then
                    for _, it in ipairs(HIDE_BUTTONS_ITEMS) do _G.AmbitiousMobileHideList[it.key] = true end
                end
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
        arrowBtn.TextColor3 = Color3.fromRGB(221, 221, 221)
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
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(79, 79, 79)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(22, 22, 22)),
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
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(89, 89, 89)),
            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(57, 57, 57)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(27, 27, 27)),
        })

        local delStroke = Instance.new("UIStroke", delBtn)
        delStroke.Color = Color3.fromRGB(172, 172, 172)
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
                    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(121, 121, 121)),
                    ColorSequenceKeypoint.new(0.50, Color3.fromRGB(85, 85, 85)),
                    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(40, 40, 40)),
                })
                task.delay(2, function()
                    if delBtn and delBtn.Parent and deleteState == 1 then
                        deleteState = 0
                        delLbl.Text = originalDeleteText
                        delGrad.Color = ColorSequence.new({
                            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(89, 89, 89)),
                            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(57, 57, 57)),
                            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(27, 27, 27)),
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
                            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(89, 89, 89)),
                            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(57, 57, 57)),
                            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(27, 27, 27)),
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
    addKeybindRow(keyPage, "Insta Reset", KB.InstaReset)
    addKeybindRow(keyPage, "TP Down", KB.TPFloor)
    addKeybindRow(keyPage, "Drop Brainrot", KB.DropBrainrot)
    addKeybindRow(keyPage, "Hide GUI", KB.GuiHide)

    local spacer = Instance.new("Frame", keyPage)
    spacer.Size = UDim2.new(1, 0, 0, 16)
    spacer.BackgroundTransparency = 1
    spacer.LayoutOrder = getNextOrder(keyPage)
    spacer.ZIndex = 7

    _shoxLayoutResetOnce()
    pbFrame = Instance.new("Frame", gui)
    pbFrame.Size = UDim2.new(0, 236, 0, 46)
    pbFrame.Position = UDim2.new(0.5, -118, 0, 56)
    pbFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
    pbFrame.BackgroundTransparency = 0
    pbFrame.BorderSizePixel = 0
    pbFrame.Active = true
    pbFrame.Selectable = false
    pbFrame.ClipsDescendants = true
    pbFrame.Visible = CONFIG.AUTO_STEAL_ENABLED
    pbFrame.ZIndex = 10

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
    ShoxBgAttach(pbFrame, 14, 10)
    do -- v1.9.1: gleicher Stil wie die Mobile-Buttons
        local pg = Instance.new("UIGradient", pbFrame)
        pg.Rotation = 90
        pg.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(71, 71, 71)),
            ColorSequenceKeypoint.new(0.35, Color3.fromRGB(29, 29, 29)),
            ColorSequenceKeypoint.new(0.70, Color3.fromRGB(10, 10, 10)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(0, 0, 0)),
        })
    end
    local pbStroke = Instance.new("UIStroke", pbFrame)
    pbStroke.Name = "PBStroke"
    pbStroke.Color = Color3.fromRGB(71, 71, 71)
    pbStroke.Thickness = 1
    pbStroke.Transparency = 0.45

    fpsNeon = Instance.new("TextLabel", pbFrame)
    fpsNeon.Name = "FPSNeon"
    fpsNeon.Size = UDim2.new(1, -20, 0, 12)
    fpsNeon.Position = UDim2.new(0, 12, 0, 4)
    fpsNeon.BackgroundTransparency = 1
    fpsNeon.Text = "--FPS · --ms"
    fpsNeon.TextColor3 = Color3.fromRGB(170, 170, 170)
    fpsNeon.Font = SHOX_UI_FONT
    fpsNeon.TextSize = 10
    fpsNeon.TextXAlignment = Enum.TextXAlignment.Left
    fpsNeon.TextStrokeTransparency = 1
    fpsNeon.ZIndex = 13

    local progressRow = Instance.new("Frame", pbFrame)
    progressRow.Name = "ProgressRow"
    progressRow.Size = UDim2.new(1, -24, 0, 14)
    progressRow.Position = UDim2.new(0, 12, 0, 22)
    progressRow.BackgroundTransparency = 1
    progressRow.ZIndex = 11

    local fillRegion = Instance.new("Frame", progressRow)
    fillRegion.Name = "FillRegion"
    fillRegion.Size = UDim2.new(1, 0, 1, 0)
    fillRegion.BackgroundColor3 = Color3.fromRGB(21, 21, 21)
    fillRegion.BackgroundTransparency = 0.25
    fillRegion.BorderSizePixel = 0
    fillRegion.ClipsDescendants = true
    fillRegion.ZIndex = 12
    Instance.new("UICorner", fillRegion).CornerRadius = UDim.new(0, 7)

    progressFill = Instance.new("Frame", fillRegion)
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.Position = UDim2.new(0, 0, 0, 0)
    progressFill.BackgroundColor3 = getThemeColor()
    progressFill.BorderSizePixel = 0
    progressFill.ZIndex = 13
    Instance.new("UICorner", progressFill).CornerRadius = UDim.new(0, 7)

    local fillGrad = Instance.new("UIGradient", progressFill)
    fillGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(190, 190, 190)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 255, 255)),
    })
    fillGrad.Rotation = 0

    progressPct = Instance.new("TextLabel", fillRegion)
    progressPct.Size = UDim2.new(1, 0, 1, 0)
    progressPct.Position = UDim2.new(0, 0, 0, 0)
    progressPct.BackgroundTransparency = 1
    progressPct.Text = "0%"
    progressPct.TextColor3 = Color3.fromRGB(235,235,235)
    progressPct.Font = SHOX_UI_FONT
    progressPct.TextSize = 10
    progressPct.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    progressPct.TextStrokeTransparency = 0.6
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
                -- v1.7.0: fpsSum war nie deklariert -> Fehler in jedem Frame (Log-Spam, Lag)
                fpsAvg = fpsAvg + (math.clamp(1 / dt, 1, 240) - fpsAvg) * 0.05
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
    _shoxLayoutResetOnce()
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
    local COLUMNS = 3
    local ROWS = 4
    local PANEL_W = BTN_W * COLUMNS + GAP * (COLUMNS - 1)
    local PANEL_H = BTN_H * ROWS + GAP * (ROWS - 1)

    local container = Instance.new("Frame", panel)
    container.Name = "FloatingPanel"
    container.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
    container.AnchorPoint = Vector2.new(1, 0)
    local mpp = savedMobilePanelPos
    if type(mpp) == "table" then
        container.Position = UDim2.new(tonumber(mpp.XScale) or 1, tonumber(mpp.XOffset) or -8, tonumber(mpp.YScale) or 0, tonumber(mpp.YOffset) or 110)
    else
        container.Position = UDim2.new(1, -8, 0, 40)
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
    local INACTIVE_BG = Color3.fromRGB(8, 8, 8)

    local buttons = {}
    local buttonNames = {"DropBR", "InstaReset", "TPBat", "AutoLeft", "AutoBat", "AutoRight", "TpDown", "Carry", "Lagger1", "Lagger2"}
    local buttonTexts = {"DROP\nBR", "INSTA\nRESET", "TP\nBAT", "AUTO\nLEFT", "BAT\nAIMBOT", "AUTO\nRIGHT", "TP\nDOWN", "CARRY\nSPD", "LAGGER\nNORMAL", "LAGGER\nCARRY"}

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
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 14)
        ShoxBgAttach(btn, 14, 10)

        local bgGrad = Instance.new("UIGradient", btn)
        bgGrad.Name = "BtnGrad"
        bgGrad.Rotation = 90
        bgGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(71, 71, 71)),
            ColorSequenceKeypoint.new(0.35, Color3.fromRGB(29, 29, 29)),
            ColorSequenceKeypoint.new(0.70, Color3.fromRGB(10, 10, 10)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(0, 0, 0)),
        })

        local stroke = Instance.new("UIStroke", btn)
        stroke.Color = Color3.fromRGB(71, 71, 71)
        stroke.Thickness = 1
        stroke.Transparency = 0.45
        stroke.Name = "NormalStroke"

        local accent = Instance.new("Frame", btn)
        accent.Name = "Accent"
        accent.AnchorPoint = Vector2.new(0.5, 1)
        accent.Position = UDim2.new(0.5, 0, 1, -5)
        accent.Size = UDim2.new(0.42, 0, 0, 3)
        accent.BorderSizePixel = 0
        accent.ZIndex = 12
        Instance.new("UICorner", accent).CornerRadius = UDim.new(1, 0)

        local label = Instance.new("TextLabel", btn)
        label.Name = "TextLabel"
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.Font = Enum.Font.GothamBlack
        label.TextSize = 11
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
        local dragInput = nil

        local function onInputBegan(input)
            if mobileButtonsLocked then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                hasMoved = false
                dragStart = input.Position
                startPos = btn.Position
                dragInput = input
                _isDraggingButton = true
            end
        end

        -- v1.9.10: Move kommt global (btn.InputChanged feuert bei Touch nur ueber dem Button -> Buttons liessen sich
        -- kaum verschieben, wirkte wie "gelockt"). Gleiches Muster wie beim Insta-Reset-Button.
        local function onInputChanged(input)
            if not dragging or mobileButtonsLocked then return end
            local isMove = (input.UserInputType == Enum.UserInputType.MouseMovement)
                or (input.UserInputType == Enum.UserInputType.Touch and input == dragInput)
            if isMove then
                local delta = input.Position - dragStart
                if delta.Magnitude > 7 and not hasMoved then
                    hasMoved = true
                    suppressNextActivate = true -- sofort sperren: Activated darf nach dem Ziehen nicht ausloesen
                end
                if hasMoved then
                    -- v1.7.4: auf den Bildschirm clampen (nicht auf die enge Container-Box)
                    local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
                    local sc = math.max(containerScale.Scale, 0.01)
                    local ap = btnContainer.AbsolutePosition
                    local x = math.clamp(startPos.X.Offset + delta.X / sc, -ap.X / sc, (vp.X - ap.X - btn.AbsoluteSize.X) / sc)
                    local y = math.clamp(startPos.Y.Offset + delta.Y / sc, -ap.Y / sc, (vp.Y - ap.Y - btn.AbsoluteSize.Y) / sc)
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
                        task.delay(0.3, function() suppressNextActivate = false end)
                        pcall(saveAllSettings)
                    end
                    dragging = false
                    hasMoved = false
                    dragStart = nil
                    startPos = nil
                    dragInput = nil
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
        local globalInputChanged = UIS.InputChanged:Connect(onInputChanged)
        btn.InputEnded:Connect(onInputEnded)

        -- A finger may be released outside the button, so GuiObject.InputEnded alone is insufficient.
        local globalInputEnded = UIS.InputEnded:Connect(onInputEnded)
        local globalTouchEnded = UIS.TouchEnded:Connect(onInputEnded)
        btn.Destroying:Connect(function()
            if globalInputEnded then globalInputEnded:Disconnect(); globalInputEnded = nil end
            if globalTouchEnded then globalTouchEnded:Disconnect(); globalTouchEnded = nil end
            if globalInputChanged then globalInputChanged:Disconnect(); globalInputChanged = nil end
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
        elseif name == "InstaReset" then
            callback = function(setActive)
                setActive(true)
                if _G.InstaReset and _G.InstaReset.Trigger then pcall(_G.InstaReset.Trigger) end
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
                doTpDown(true)
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
        container.Position = UDim2.new(1, -8, 0, 40)
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
    btnFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
    btnFrame.BorderSizePixel  = 0
    btnFrame.ZIndex           = 20
    Instance.new("UICorner", btnFrame).CornerRadius = UDim.new(0, 10)
    ShoxBgAttach(btnFrame, 10, 20)

    local bgGrad = Instance.new("UIGradient", btnFrame)
    bgGrad.Name = "BtnGrad"
    bgGrad.Rotation = 90
    bgGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(71, 71, 71)),
        ColorSequenceKeypoint.new(0.35, Color3.fromRGB(29, 29, 29)),
        ColorSequenceKeypoint.new(0.70, Color3.fromRGB(10, 10, 10)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(0, 0, 0)),
    })

    local stroke = Instance.new("UIStroke", btnFrame)
    stroke.Color = Color3.fromRGB(71, 71, 71)
    stroke.Thickness = 1
    stroke.Transparency = 0.45

    local label = Instance.new("TextLabel", btnFrame)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "INSTA\nRESET"
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.GothamBlack
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
        if hasMoved and not (uiLocked or mobileButtonsLocked) then
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
            elseif not (uiLocked or mobileButtonsLocked) and hasMoved then
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
    -- v1.7.4: Schalter-Visuals mit geladenem Zustand synchronisieren
    if ShoxSetLockBtnsVisual then ShoxSetLockBtnsVisual(mobileButtonsLocked) end
    if ShoxHideMasterVisual then ShoxHideMasterVisual(_G.AmbitiousHideMobileButtons == true) end
    for _, f in pairs(ShoxHideItemVisuals or {}) do pcall(f) end
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

    if ShoxAntiBatEnabled then
        if ShoxAntiBatSetVisual then ShoxAntiBatSetVisual(true) end
        ShoxAntiBatSet(true)
    else
        if ShoxAntiBatSetVisual then ShoxAntiBatSetVisual(false) end
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

    applyBackground(backgroundIndex)
    if ShoxBgOpacitySet then ShoxBgOpacitySet(_floor((1 - backgroundImageTransparency) * 100 + 0.5)) end
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
                container.Position = UDim2.new(1, -8, 0, 40)
            end
            container.Visible = true
            MobilePanel.Enabled = true
            local btnCont = container:FindFirstChild("ButtonsContainer")
            if btnCont then
                local keyByButton = {InstaReset="instaReset", TpDown="tp", TPBat="tpBat", AutoBat="aimbot", AutoLeft="autoLeft", AutoRight="autoRight", DropBR="drop", Carry="carry", Lagger1="laggerNormal", Lagger2="laggerCarry"}
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

-- v1.9.4-hotfix3: Exact Clean Hub match, no locks
RunService.Heartbeat:Connect(function()
    if not ShoxHubAutoTPDown then return end
    local ch = LP.Character
    local root = ch and ch:FindFirstChild("HumanoidRootPart")
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if root and hum and hum.FloorMaterial == Enum.Material.Air
       and root.Position.Y >= ShoxHubAutoTPDownHeight
       and tick() - ShoxHubAutoTPLastAt >= 0.35 then
        ShoxHubAutoTPLastAt = tick()
        doTpDown()
    end
end)

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

    -- Use explicit carry markers; broad name fragments such as "animal" or
    -- "steal" can match unrelated accessories and trigger a false warning.
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

ShoxCharAdded(function()
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
        if minecraftBatSkinEnabled then
            task.wait(0.6)
            pcall(function() MinecraftBatSkin.Apply() end)
        end
    end
end

local _respawnQueue = 0
ShoxCharAdded(function(char)
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
    if not ShoxHubState.Running then return end
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
    if kbMatch(KB.TPFloor, kc) then doTpDown(true); return end
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
    if kbMatch(KB.GuiHide, kc) then
        if main then
            if main.Visible then hideGui() else showGui() end
        end
        return
    end

end)


-- ═══════════════════════════════════════════════════════════════
-- ShoxHub — Global Destroy
-- ═══════════════════════════════════════════════════════════════
-- v1.9.4-hotfix3: SELF-DIAGNOSTICS
task.spawn(function()
    local diag = { network = false, compiler = false, details = {} }
    local okC, errC = pcall(function()
        if type(loadstring) ~= "function" then error("loadstring() fehlt") end
        local chunk, perr = loadstring("return 1 + 1")
        if type(chunk) ~= "function" then error("loadstring kompilierte nicht: " .. tostring(perr)) end
        if chunk() ~= 2 then error("loadstring lieferte falsches Ergebnis") end
        return true
    end)
    diag.compiler = okC
    if not okC then diag.details.compiler = tostring(errC) end
    -- v1.9.5: kein Netzwerkcall mehr (jsdelivr entfernt). Es wird nur geprueft, ob HttpGet existiert.
    local okN, errN = pcall(function()
        if type(game.HttpGet) ~= "function" then error("game:HttpGet() fehlt") end
        return true
    end)
    diag.network = okN
    if not okN then diag.details.network = tostring(errN) end
    ShoxHubState.Diagnostics = diag
    _G.ShoxHub.Diagnostics = diag
    print(("[ShoxHub %s] Netzwerk: %s | Lua-Compiler: %s"):format(
        tostring(ShoxHubState.Version),
        diag.network  and "OK" or ("FEHLER (" .. tostring(diag.details.network)  .. ")"),
        diag.compiler and "OK" or ("FEHLER (" .. tostring(diag.details.compiler) .. ")")
    ))
end)

_G.ShoxHubDestroy = function() ShoxHubState:Destroy() end
print("[ShoxHub] Loaded. Version: " .. tostring(ShoxHubState.Version))
