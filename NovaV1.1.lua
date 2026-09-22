-- NOVA V1.0
-- Full rewrite from FOSTOQA V5.0
-- Miku-themed UI (blue/dark-blue/violet/green)
-- Camera lock on orbit target head (independent system)
-- Keybind support with UI settings
-- Renamed: Nova

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local CoreGui          = game:GetService("CoreGui")
local HttpService      = game:GetService("HttpService")
local StarterGui       = game:GetService("StarterGui")

local gethui     = gethui     or function() return CoreGui end
local protectgui = protectgui or (syn and syn.protect_gui) or function() end

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera
local Mouse       = LocalPlayer:GetMouse()

-- ─── Color Theme (Hatsune Miku) ──────────────────────────────────────────────

local Theme = {
    Accent1    = Color3.fromRGB(57, 197, 187),   -- miku teal
    Accent2    = Color3.fromRGB(100, 149, 237),  -- cornflower blue
    Accent3    = Color3.fromRGB(138, 92, 246),   -- violet
    Accent4    = Color3.fromRGB(57, 255, 150),   -- mint green
    BG_Main    = Color3.fromRGB(8,  12, 22),     -- very dark navy
    BG_Panel   = Color3.fromRGB(12, 18, 32),     -- dark navy
    BG_Item    = Color3.fromRGB(16, 24, 44),     -- item row
    BG_Header  = Color3.fromRGB(10, 16, 28),     -- header
    Text_Main  = Color3.fromRGB(220, 235, 255),
    Text_Sub   = Color3.fromRGB(140, 165, 210),
    Toggle_Off = Color3.fromRGB(30,  38, 60),
    Danger     = Color3.fromRGB(220, 55, 80),
}

-- ─── Settings ────────────────────────────────────────────────────────────────

local Settings = {
    -- Aimbot
    Enabled           = true,
    AimKey            = Enum.UserInputType.MouseButton2,
    TargetPart        = "Head",
    FOV               = 120,
    Smoothness        = 0.15,
    AimSpeed          = 1.0,
    WallCheck         = true,
    SilentWallbang    = true,
    TeamCheck         = true,
    ShowFOV           = true,
    FOVColor          = Color3.fromRGB(57, 197, 187),
    -- Hitbox
    HitboxEnabled     = false,
    HitboxSize        = 8,
    -- Reach
    ReachEnabled      = false,
    ReachDistance     = 20,
    -- Movement
    FlyEnabled        = false,
    FlySpeed          = 50,
    NoclipEnabled     = false,
    SpeedEnabled      = false,
    SpeedMultiplier   = 2.5,
    InfJumpEnabled    = false,
    -- Orbit
    OrbitRadius       = 4,
    OrbitSpeed        = 1.8,
    OrbitCamLock      = true,   -- camera lock on orbit target head
    OrbitCamSmooth    = 0.35,
    -- Anti-AFK
    AntiAFKEnabled    = true,
    -- Remote Spy
    RemoteSpyEnabled  = false,
    -- ESP
    ESP_Enabled       = true,
    ESP_Boxes         = true,
    ESP_Names         = true,
    ESP_Health        = true,
    ESP_Distance      = true,
    ESP_MaxDistance   = 500,
    ESP_EnemyColor    = Color3.fromRGB(255, 60, 60),
    ESP_TeamColor     = Color3.fromRGB(57, 255, 150),
    -- Keybinds (stored as Enum.KeyCode or Enum.UserInputType)
    KB_ToggleGUI      = Enum.KeyCode.RightControl,
    KB_AimKey         = Enum.UserInputType.MouseButton2,
    KB_FlyToggle      = Enum.KeyCode.F,
    KB_NoclipToggle   = Enum.KeyCode.N,
    KB_SpeedToggle    = Enum.KeyCode.X,
    -- UI Theme (mutable for color picker)
    ThemeAccent       = Color3.fromRGB(57, 197, 187),
}

-- ─── State ───────────────────────────────────────────────────────────────────

local Aiming        = false
local ActiveSlider  = nil
local Connections   = {}
local ESP_Cache     = {}
local RemoteLog     = {}
local HitboxCache   = {}
local InfJumpConn   = nil
local OrigWalkSpeed = nil
local OrbitTarget   = nil
local OrbitAngle    = 0
local OrbitRows     = {}
local BindingSlot   = nil  -- currently being rebound keybind slot name

local _cache = { char = nil, part = nil, t = -1 }

-- ─── Raycast Params ──────────────────────────────────────────────────────────

local RayParams = RaycastParams.new()
pcall(function() RayParams.FilterType = Enum.RaycastFilterType.Exclude end)
if not RayParams.FilterType then
    pcall(function() RayParams.FilterType = Enum.RaycastFilterType.Blacklist end)
end
RayParams.IgnoreWater = true

-- ─── Core Logic ──────────────────────────────────────────────────────────────

local function IsEnemy(char)
    if not Settings.TeamCheck or not char then return true end
    local tp = Players:GetPlayerFromCharacter(char)
    if tp and LocalPlayer.Team and tp.Team then
        return LocalPlayer.Team ~= tp.Team
    end
    return true
end

local function IsVisible(part, char)
    if Settings.SilentWallbang then return true end
    if not Settings.WallCheck   then return true end
    RayParams.FilterDescendantsInstances = { LocalPlayer.Character, char }
    local res = workspace:Raycast(Camera.CFrame.Position, part.Position - Camera.CFrame.Position, RayParams)
    return res == nil
end

local function GetTarget()
    local now = tick()
    if _cache.t == now then return _cache.char, _cache.part end
    local mpos = UserInputService:GetMouseLocation()
    local bc, bp, bd = nil, nil, Settings.FOV
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl == LocalPlayer or not pl.Character then continue end
        local char = pl.Character
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 or not IsEnemy(char) then continue end
        local pn   = Settings.TargetPart
        local part = char:FindFirstChild(pn)
            or (pn == "Torso" and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart")))
            or char:FindFirstChild("Head")
        if not part then continue end
        local sp, on = Camera:WorldToViewportPoint(part.Position)
        if not on and not Settings.SilentWallbang then continue end
        local d = (Vector2.new(sp.X, sp.Y) - mpos).Magnitude
        if d <= bd and IsVisible(part, char) then bd = d; bc = char; bp = part end
    end
    _cache.char = bc; _cache.part = bp; _cache.t = now
    return bc, bp
end

-- ─── Hook Engine ─────────────────────────────────────────────────────────────

if hookmetamethod and getnamecallmethod then
    local oldNC
    oldNC = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args   = { ... }

        if Settings.SilentWallbang and (
            method == "Raycast" or
            method == "FindPartOnRay" or
            method == "FindPartOnRayWithIgnoreList"
        ) then
            local _, tp = GetTarget()
            if tp and tp:IsDescendantOf(workspace) then
                if method == "Raycast" and typeof(args[1]) == "Vector3" then
                    args[2] = (tp.Position - args[1]).Unit * 10000
                elseif typeof(args[1]) == "Ray" then
                    args[1] = Ray.new(args[1].Origin, (tp.Position - args[1].Origin).Unit * 10000)
                end
            end
        end

        if Settings.RemoteSpyEnabled and (
            method == "FireServer" or method == "InvokeServer" or
            method == "FireAllClients" or method == "FireClient"
        ) then
            local ok, name = pcall(function() return self.Name end)
            local entry = { Time = os.date("%H:%M:%S"), Remote = ok and name or "?", Method = method, Args = {} }
            for i, v in ipairs(args) do
                local s, r = pcall(function()
                    return typeof(v) == "table" and HttpService:JSONEncode(v) or tostring(v)
                end)
                entry.Args[i] = s and r or typeof(v)
            end
            table.insert(RemoteLog, 1, entry)
            if #RemoteLog > 200 then table.remove(RemoteLog) end
        end

        return oldNC(self, table.unpack(args))
    end)

    local oldIdx
    oldIdx = hookmetamethod(game, "__index", function(self, key)
        if Settings.SilentWallbang and self == Mouse and (key == "Hit" or key == "Target") then
            local _, tp = GetTarget()
            if tp then return key == "Hit" and tp.CFrame or tp end
        end
        return oldIdx(self, key)
    end)
end

-- ─── Hitbox ──────────────────────────────────────────────────────────────────

local function ApplyHitboxes()
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl == LocalPlayer or not pl.Character then continue end
        local head = pl.Character:FindFirstChild("Head")
        if not head then continue end
        if not HitboxCache[head] then HitboxCache[head] = head.Size end
        head.Size = Vector3.one * Settings.HitboxSize
    end
end

local function RestoreHitboxes()
    for part, sz in pairs(HitboxCache) do pcall(function() part.Size = sz end) end
    table.clear(HitboxCache)
end

-- ─── Reach ───────────────────────────────────────────────────────────────────

local function ApplyReach()
    if not LocalPlayer.Character then return end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ClickDetector") then
            obj.MaxActivationDistance = Settings.ReachDistance
        end
    end
end

-- ─── Speed ───────────────────────────────────────────────────────────────────

local function SetSpeed(on)
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if on then
        if not OrigWalkSpeed then OrigWalkSpeed = hum.WalkSpeed end
        hum.WalkSpeed = OrigWalkSpeed * Settings.SpeedMultiplier
    else
        if OrigWalkSpeed then hum.WalkSpeed = OrigWalkSpeed end
        OrigWalkSpeed = nil
    end
end

-- ─── Infinite Jump ───────────────────────────────────────────────────────────

local function EnableInfJump()
    if InfJumpConn then InfJumpConn:Disconnect() end
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    InfJumpConn = hum.StateChanged:Connect(function(_, new)
        if new == Enum.HumanoidStateType.Freefall then
            task.wait(0.1)
            hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
    table.insert(Connections, InfJumpConn)
end

local function DisableInfJump()
    if InfJumpConn then InfJumpConn:Disconnect(); InfJumpConn = nil end
end

-- ─── Anti-AFK ────────────────────────────────────────────────────────────────

task.spawn(function()
    while task.wait(25) do
        if not Settings.AntiAFKEnabled then continue end
        pcall(function()
            local vu = Instance.new("VirtualUser")
            vu.Parent = LocalPlayer
            vu:CaptureController()
            vu:ClickButton2(Vector2.zero)
            vu:Destroy()
        end)
    end
end)

-- ─── Teleport ────────────────────────────────────────────────────────────────

local function TeleportTo(pl)
    if not pl or not pl.Character then return end
    local tr = pl.Character:FindFirstChild("HumanoidRootPart")
    local mr = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if tr and mr then mr.CFrame = tr.CFrame + Vector3.new(3, 0, 0) end
end

-- ─── FOV Circle ──────────────────────────────────────────────────────────────

local FOVCircle
if Drawing then
    pcall(function()
        FOVCircle           = Drawing.new("Circle")
        FOVCircle.Thickness = 1.5
        FOVCircle.NumSides  = 64
        FOVCircle.Radius    = Settings.FOV
        FOVCircle.Filled    = false
        FOVCircle.Visible   = Settings.ShowFOV
        FOVCircle.Color     = Settings.FOVColor
    end)
end

-- ─── ESP ─────────────────────────────────────────────────────────────────────

local function CreateESP(char)
    if ESP_Cache[char] or not Drawing then return end
    pcall(function()
        local box  = Drawing.new("Square")
        box.Thickness = 1.5; box.Filled = false

        local nameL = Drawing.new("Text")
        nameL.Size  = 13; nameL.Center = true; nameL.Outline = true

        local distL = Drawing.new("Text")
        distL.Size  = 11; distL.Center = true; distL.Outline = true
        distL.Color = Color3.fromRGB(180, 200, 255)

        local hpBG  = Drawing.new("Square")
        hpBG.Filled = true; hpBG.Color = Color3.fromRGB(10, 12, 20)

        local hpBar = Drawing.new("Square")
        hpBar.Filled = true

        ESP_Cache[char] = { Box = box, Name = nameL, Dist = distL, HPBG = hpBG, HP = hpBar }
    end)
end

local function RemoveESP(char)
    local d = ESP_Cache[char]; if not d then return end
    pcall(function() for _, v in pairs(d) do v.Visible = false; v:Remove() end end)
    ESP_Cache[char] = nil
end

local function UpdateESP()
    if not Drawing then return end
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    for char, d in pairs(ESP_Cache) do
        local hum  = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")

        local function hide()
            d.Box.Visible = false; d.Name.Visible = false
            d.Dist.Visible = false; d.HPBG.Visible = false; d.HP.Visible = false
        end

        if not Settings.ESP_Enabled or not hum or hum.Health <= 0
            or not root or not char:IsDescendantOf(workspace)
        then hide() continue end

        local distVal = 0
        if myRoot then
            distVal = (myRoot.Position - root.Position).Magnitude
            if distVal > Settings.ESP_MaxDistance then hide() continue end
        end

        local rp, onScreen = Camera:WorldToViewportPoint(root.Position)
        if not onScreen then hide() continue end

        local head   = char:FindFirstChild("Head")
        local hp_top = Camera:WorldToViewportPoint(
            head and (head.Position + Vector3.new(0, 0.5, 0)) or (root.Position + Vector3.new(0, 3, 0))
        )
        local hp_bot = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
        local h      = math.abs(hp_top.Y - hp_bot.Y)
        local w      = h / 1.8
        local col    = IsEnemy(char) and Settings.ESP_EnemyColor or Settings.ESP_TeamColor

        d.Box.Size     = Vector2.new(w, h)
        d.Box.Position = Vector2.new(rp.X - w/2, rp.Y - h/2)
        d.Box.Color    = col
        d.Box.Visible  = Settings.ESP_Boxes

        local pl = Players:GetPlayerFromCharacter(char)
        d.Name.Text     = pl and pl.Name or char.Name
        d.Name.Position = Vector2.new(rp.X, rp.Y - h/2 - 16)
        d.Name.Color    = Theme.Text_Main
        d.Name.Visible  = Settings.ESP_Names

        d.Dist.Text     = math.floor(distVal) .. "m"
        d.Dist.Position = Vector2.new(rp.X, rp.Y + h/2 + 4)
        d.Dist.Visible  = Settings.ESP_Distance

        local hpct         = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
        d.HPBG.Size        = Vector2.new(4, h + 2)
        d.HPBG.Position    = Vector2.new(rp.X - w/2 - 6, rp.Y - h/2 - 1)
        d.HPBG.Visible     = Settings.ESP_Health
        d.HP.Size          = Vector2.new(2, h * hpct)
        d.HP.Position      = Vector2.new(rp.X - w/2 - 5, (rp.Y + h/2) - (h * hpct))
        d.HP.Color         = Color3.fromRGB(255,0,0):Lerp(Color3.fromRGB(57,255,150), hpct)
        d.HP.Visible       = Settings.ESP_Health
    end
end

-- ─── UI ──────────────────────────────────────────────────────────────────────

local Gui               = Instance.new("ScreenGui")
Gui.Name                = "NOVA_V1"
Gui.ResetOnSpawn        = false
Gui.DisplayOrder        = 999999999
Gui.ZIndexBehavior      = Enum.ZIndexBehavior.Sibling
protectgui(Gui)
if not pcall(function() Gui.Parent = gethui() end) then
    Gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- ── Window ────────────────────────────────────────────────────────────────────

local Win               = Instance.new("Frame")
Win.Size                = UDim2.new(0, 420, 0, 580)
Win.Position            = UDim2.new(0.5, -210, 0.5, -290)
Win.BackgroundColor3    = Theme.BG_Main
Win.BorderSizePixel     = 0
Win.Active              = true
Win.Draggable           = true
Win.Parent              = Gui
Instance.new("UICorner", Win).CornerRadius = UDim.new(0, 16)

-- gradient stroke — outer glow via UIStroke
local WinStroke         = Instance.new("UIStroke", Win)
WinStroke.Color         = Theme.Accent1
WinStroke.Thickness     = 1.8

-- inner glow frame (visual only)
local GlowFrame         = Instance.new("Frame", Win)
GlowFrame.Size          = UDim2.new(1, -4, 1, -4)
GlowFrame.Position      = UDim2.new(0, 2, 0, 2)
GlowFrame.BackgroundTransparency = 1
GlowFrame.BorderSizePixel = 0
Instance.new("UICorner", GlowFrame).CornerRadius = UDim.new(0, 14)
local GlowStroke        = Instance.new("UIStroke", GlowFrame)
GlowStroke.Color        = Theme.Accent3
GlowStroke.Thickness    = 0.8
GlowStroke.Transparency = 0.5

-- ── Header ────────────────────────────────────────────────────────────────────

local Head              = Instance.new("Frame", Win)
Head.Size               = UDim2.new(1, 0, 0, 50)
Head.BackgroundColor3   = Theme.BG_Header
Head.BorderSizePixel    = 0
Instance.new("UICorner", Head).CornerRadius = UDim.new(0, 16)

-- fix header bottom corners
local HeadFill          = Instance.new("Frame", Head)
HeadFill.Size           = UDim2.new(1, 0, 0.5, 0)
HeadFill.Position       = UDim2.new(0, 0, 0.5, 0)
HeadFill.BackgroundColor3 = Theme.BG_Header
HeadFill.BorderSizePixel  = 0

-- logo dot
local LogoDot           = Instance.new("Frame", Head)
LogoDot.Size            = UDim2.new(0, 10, 0, 10)
LogoDot.Position        = UDim2.new(0, 14, 0.5, -5)
LogoDot.BackgroundColor3 = Theme.Accent4
LogoDot.BorderSizePixel = 0
Instance.new("UICorner", LogoDot).CornerRadius = UDim.new(1, 0)

local TitleL            = Instance.new("TextLabel", Head)
TitleL.Size             = UDim2.new(1, -80, 1, 0)
TitleL.Position         = UDim2.new(0, 32, 0, 0)
TitleL.BackgroundTransparency = 1
TitleL.Text             = "NOVA  <font color=\"#39C5BB\">V1.0</font>"
TitleL.RichText         = true
TitleL.TextColor3       = Theme.Text_Main
TitleL.Font             = Enum.Font.GothamBold
TitleL.TextSize         = 15
TitleL.TextXAlignment   = Enum.TextXAlignment.Left

local SubL              = Instance.new("TextLabel", Head)
SubL.Size               = UDim2.new(1, -80, 0, 14)
SubL.Position           = UDim2.new(0, 32, 1, -16)
SubL.BackgroundTransparency = 1
SubL.Text               = "universal • miku edition"
SubL.TextColor3         = Theme.Text_Sub
SubL.Font               = Enum.Font.Gotham
SubL.TextSize           = 10
SubL.TextXAlignment     = Enum.TextXAlignment.Left

local MinBtn            = Instance.new("TextButton", Head)
MinBtn.Size             = UDim2.new(0, 28, 0, 28)
MinBtn.Position         = UDim2.new(1, -40, 0.5, -14)
MinBtn.BackgroundColor3 = Color3.fromRGB(35, 45, 70)
MinBtn.Text             = "−"
MinBtn.TextColor3       = Theme.Text_Main
MinBtn.Font             = Enum.Font.GothamBold
MinBtn.TextSize         = 16
MinBtn.AutoButtonColor  = false
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 7)

-- ── Bubble ────────────────────────────────────────────────────────────────────

local Bubble            = Instance.new("TextButton", Gui)
Bubble.Size             = UDim2.new(0, 48, 0, 48)
Bubble.Position         = UDim2.new(0, 16, 0.5, 0)
Bubble.BackgroundColor3 = Theme.Accent1
Bubble.Text             = "N"
Bubble.TextColor3       = Color3.fromRGB(255, 255, 255)
Bubble.Font             = Enum.Font.GothamBold
Bubble.TextSize         = 20
Bubble.Active           = true
Bubble.Draggable        = true
Bubble.Visible          = false
Instance.new("UICorner", Bubble).CornerRadius = UDim.new(1, 0)
local BubStroke         = Instance.new("UIStroke", Bubble)
BubStroke.Color         = Theme.Accent4
BubStroke.Thickness     = 1.5

MinBtn.MouseButton1Click:Connect(function() Win.Visible = false; Bubble.Visible = true end)
Bubble.MouseButton1Click:Connect(function() Win.Visible = true; Bubble.Visible = false end)

-- ── Tab Bar ───────────────────────────────────────────────────────────────────

local TabBar            = Instance.new("Frame", Win)
TabBar.Size             = UDim2.new(1, -16, 0, 32)
TabBar.Position         = UDim2.new(0, 8, 0, 56)
TabBar.BackgroundTransparency = 1

local TBL               = Instance.new("UIListLayout", TabBar)
TBL.FillDirection       = Enum.FillDirection.Horizontal
TBL.SortOrder           = Enum.SortOrder.LayoutOrder
TBL.Padding             = UDim.new(0, 3)

-- ── Content ───────────────────────────────────────────────────────────────────

local Content           = Instance.new("Frame", Win)
Content.Size            = UDim2.new(1, -16, 1, -108)
Content.Position        = UDim2.new(0, 8, 0, 96)
Content.BackgroundTransparency = 1

local TABS = { "Combat", "Move", "Visual", "Utils", "Remote", "DEX", "Settings" }
local TabBtns  = {}
local Panels   = {}

for i, name in ipairs(TABS) do
    local btn               = Instance.new("TextButton", TabBar)
    btn.Size                = UDim2.new(0, 54, 1, 0)
    btn.BackgroundColor3    = Theme.BG_Item
    btn.Text                = name
    btn.TextColor3          = Theme.Text_Sub
    btn.Font                = Enum.Font.GothamBold
    btn.TextSize            = 9
    btn.AutoButtonColor     = false
    btn.LayoutOrder         = i
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
    TabBtns[name] = btn

    local panel             = Instance.new("ScrollingFrame", Content)
    panel.Size              = UDim2.new(1, 0, 1, 0)
    panel.BackgroundTransparency = 1
    panel.BorderSizePixel   = 0
    panel.ScrollBarThickness = 3
    panel.ScrollBarImageColor3 = Theme.Accent1
    panel.Visible           = false
    Panels[name]            = panel

    local lay               = Instance.new("UIListLayout", panel)
    lay.SortOrder           = Enum.SortOrder.LayoutOrder
    lay.Padding             = UDim.new(0, 5)
    lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        panel.CanvasSize = UDim2.new(0, 0, 0, lay.AbsoluteContentSize.Y + 8)
    end)
end

local function SwitchTab(name)
    for n, btn in pairs(TabBtns) do
        local active = n == name
        btn.BackgroundColor3 = active and Theme.Accent1 or Theme.BG_Item
        btn.TextColor3       = active and Color3.fromRGB(8,12,22) or Theme.Text_Sub
    end
    for n, panel in pairs(Panels) do panel.Visible = n == name end
end

for name, btn in pairs(TabBtns) do
    btn.MouseButton1Click:Connect(function() SwitchTab(name) end)
end
SwitchTab("Combat")

-- ─── UI Component Builders ───────────────────────────────────────────────────

local function Section(tab, text)
    local f             = Instance.new("Frame", Panels[tab])
    f.Size              = UDim2.new(1, -4, 0, 26)
    f.BackgroundColor3  = Color3.fromRGB(14, 20, 38)
    f.BorderSizePixel   = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 7)
    local accent        = Instance.new("Frame", f)
    accent.Size         = UDim2.new(0, 3, 0.6, 0)
    accent.Position     = UDim2.new(0, 0, 0.2, 0)
    accent.BackgroundColor3 = Theme.Accent1
    accent.BorderSizePixel  = 0
    Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 2)
    local l             = Instance.new("TextLabel", f)
    l.Size              = UDim2.new(1, -16, 1, 0)
    l.Position          = UDim2.new(0, 12, 0, 0)
    l.BackgroundTransparency = 1
    l.Text              = text
    l.TextColor3        = Theme.Accent1
    l.Font              = Enum.Font.GothamBold
    l.TextSize          = 10
    l.TextXAlignment    = Enum.TextXAlignment.Left
end

local function Toggle(tab, text, state, cb)
    local f             = Instance.new("Frame", Panels[tab])
    f.Size              = UDim2.new(1, -4, 0, 36)
    f.BackgroundColor3  = Theme.BG_Item
    f.BorderSizePixel   = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 9)

    local l             = Instance.new("TextLabel", f)
    l.Size              = UDim2.new(1, -60, 1, 0)
    l.Position          = UDim2.new(0, 12, 0, 0)
    l.BackgroundTransparency = 1
    l.Text              = text
    l.TextColor3        = Theme.Text_Main
    l.Font              = Enum.Font.GothamMedium
    l.TextSize          = 12
    l.TextXAlignment    = Enum.TextXAlignment.Left

    local sw            = Instance.new("TextButton", f)
    sw.Size             = UDim2.new(0, 40, 0, 22)
    sw.Position         = UDim2.new(1, -48, 0.5, -11)
    sw.BackgroundColor3 = state and Theme.Accent1 or Theme.Toggle_Off
    sw.Text             = ""
    sw.AutoButtonColor  = false
    Instance.new("UICorner", sw).CornerRadius = UDim.new(1, 0)

    local knob          = Instance.new("Frame", sw)
    knob.Size           = UDim2.new(0, 16, 0, 16)
    knob.Position       = state and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob.BorderSizePixel  = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local cur = state
    sw.MouseButton1Click:Connect(function()
        cur = not cur
        TweenService:Create(sw,   TweenInfo.new(0.15), { BackgroundColor3 = cur and Theme.Accent1 or Theme.Toggle_Off }):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), { Position = cur and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8) }):Play()
        cb(cur)
    end)
    return sw, knob
end

local function Slider(tab, text, min, max, default, decimals, cb)
    local f             = Instance.new("Frame", Panels[tab])
    f.Size              = UDim2.new(1, -4, 0, 52)
    f.BackgroundColor3  = Theme.BG_Item
    f.BorderSizePixel   = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 9)

    local l             = Instance.new("TextLabel", f)
    l.Size              = UDim2.new(0, 160, 0, 22)
    l.Position          = UDim2.new(0, 12, 0, 4)
    l.BackgroundTransparency = 1
    l.Text              = text
    l.TextColor3        = Theme.Text_Main
    l.Font              = Enum.Font.GothamMedium
    l.TextSize          = 12
    l.TextXAlignment    = Enum.TextXAlignment.Left

    local vl            = Instance.new("TextLabel", f)
    vl.Size             = UDim2.new(0, 80, 0, 22)
    vl.Position         = UDim2.new(1, -88, 0, 4)
    vl.BackgroundTransparency = 1
    vl.Text             = decimals and string.format("%.2f", default) or tostring(default)
    vl.TextColor3       = Theme.Accent4
    vl.Font             = Enum.Font.GothamBold
    vl.TextSize         = 12
    vl.TextXAlignment   = Enum.TextXAlignment.Right

    local track         = Instance.new("TextButton", f)
    track.Size          = UDim2.new(1, -24, 0, 6)
    track.Position      = UDim2.new(0, 12, 0, 36)
    track.BackgroundColor3 = Color3.fromRGB(28, 36, 60)
    track.Text          = ""
    track.AutoButtonColor = false
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill          = Instance.new("Frame", track)
    fill.Size           = UDim2.new(math.clamp((default-min)/(max-min),0,1), 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent2
    fill.BorderSizePixel  = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    -- thumb dot
    local thumb         = Instance.new("Frame", track)
    thumb.Size          = UDim2.new(0, 12, 0, 12)
    thumb.AnchorPoint   = Vector2.new(0.5, 0.5)
    local ratio0        = math.clamp((default-min)/(max-min), 0, 1)
    thumb.Position      = UDim2.new(ratio0, 0, 0.5, 0)
    thumb.BackgroundColor3 = Theme.Accent1
    thumb.BorderSizePixel  = 0
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)

    local function upd(pos)
        local bw = track.AbsoluteSize.X
        if bw <= 0 then return end
        local r   = math.clamp((pos.X - track.AbsolutePosition.X) / bw, 0, 1)
        local raw = min + r * (max - min)
        local val = math.clamp(decimals and raw or math.floor(raw + 0.5), min, max)
        fill.Size    = UDim2.new((val-min)/(max-min), 0, 1, 0)
        thumb.Position = UDim2.new((val-min)/(max-min), 0, 0.5, 0)
        vl.Text      = decimals and string.format("%.2f", val) or tostring(val)
        cb(val)
    end

    local sd = { Bar = track, Update = upd }
    track.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch
        then
            ActiveSlider = sd
            Panels[tab].ScrollingEnabled = false
            upd(inp.Position)
        end
    end)
end

local function Dropdown(tab, text, opts, default, cb)
    local f             = Instance.new("Frame", Panels[tab])
    f.Size              = UDim2.new(1, -4, 0, 36)
    f.BackgroundColor3  = Theme.BG_Item
    f.BorderSizePixel   = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 9)

    local l             = Instance.new("TextLabel", f)
    l.Size              = UDim2.new(0, 140, 1, 0)
    l.Position          = UDim2.new(0, 12, 0, 0)
    l.BackgroundTransparency = 1
    l.Text              = text
    l.TextColor3        = Theme.Text_Main
    l.Font              = Enum.Font.GothamMedium
    l.TextSize          = 12
    l.TextXAlignment    = Enum.TextXAlignment.Left

    local db            = Instance.new("TextButton", f)
    db.Size             = UDim2.new(0, 120, 0, 24)
    db.Position         = UDim2.new(1, -128, 0.5, -12)
    db.BackgroundColor3 = Color3.fromRGB(20, 28, 50)
    db.Text             = default
    db.TextColor3       = Theme.Accent4
    db.Font             = Enum.Font.GothamBold
    db.TextSize         = 11
    db.AutoButtonColor  = false
    Instance.new("UICorner", db).CornerRadius = UDim.new(0, 7)
    local dbStroke      = Instance.new("UIStroke", db)
    dbStroke.Color      = Theme.Accent2
    dbStroke.Thickness  = 1

    local idx = 1
    for i, v in ipairs(opts) do if v == default then idx = i break end end
    db.MouseButton1Click:Connect(function()
        idx     = idx % #opts + 1
        db.Text = opts[idx]
        cb(opts[idx])
    end)
end

local function Button(tab, text, cb)
    local btn           = Instance.new("TextButton", Panels[tab])
    btn.Size            = UDim2.new(1, -4, 0, 34)
    btn.BackgroundColor3 = Theme.Accent2
    btn.Text            = text
    btn.TextColor3      = Color3.fromRGB(8, 12, 22)
    btn.Font            = Enum.Font.GothamBold
    btn.TextSize        = 12
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 9)
    btn.MouseButton1Click:Connect(cb)
    btn.MouseButton1Down:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = Theme.Accent3 }):Play()
    end)
    btn.MouseButton1Up:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = Theme.Accent2 }):Play()
    end)
    return btn
end

-- ─── Keybind Row (Settings Tab) ──────────────────────────────────────────────
-- Tracks which label to update when rebinding
local KeybindLabels = {}

local function KeybindRow(tab, label, settingKey, displayName)
    local f             = Instance.new("Frame", Panels[tab])
    f.Size              = UDim2.new(1, -4, 0, 36)
    f.BackgroundColor3  = Theme.BG_Item
    f.BorderSizePixel   = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 9)

    local l             = Instance.new("TextLabel", f)
    l.Size              = UDim2.new(0, 160, 1, 0)
    l.Position          = UDim2.new(0, 12, 0, 0)
    l.BackgroundTransparency = 1
    l.Text              = label
    l.TextColor3        = Theme.Text_Main
    l.Font              = Enum.Font.GothamMedium
    l.TextSize          = 12
    l.TextXAlignment    = Enum.TextXAlignment.Left

    local function EnumName(e)
        if not e then return "None" end
        local s = tostring(e)
        return s:match("%.([^%.]+)$") or s
    end

    local kb            = Instance.new("TextButton", f)
    kb.Size             = UDim2.new(0, 130, 0, 24)
    kb.Position         = UDim2.new(1, -138, 0.5, -12)
    kb.BackgroundColor3 = Color3.fromRGB(20, 28, 50)
    kb.Text             = EnumName(Settings[settingKey])
    kb.TextColor3       = Theme.Accent1
    kb.Font             = Enum.Font.GothamBold
    kb.TextSize         = 11
    kb.AutoButtonColor  = false
    Instance.new("UICorner", kb).CornerRadius = UDim.new(0, 7)
    local kbStroke      = Instance.new("UIStroke", kb)
    kbStroke.Color      = Theme.Accent2
    kbStroke.Thickness  = 1

    KeybindLabels[settingKey] = kb

    local listening = false
    kb.MouseButton1Click:Connect(function()
        if listening then return end
        listening   = true
        BindingSlot = settingKey
        kb.Text     = "[ press key ]"
        kb.TextColor3 = Theme.Accent4
        kbStroke.Color = Theme.Accent4
    end)

    return kb
end

-- ─── Color Picker Row (Settings Tab) ─────────────────────────────────────────

local function ColorRow(tab, label, default, cb)
    local f             = Instance.new("Frame", Panels[tab])
    f.Size              = UDim2.new(1, -4, 0, 36)
    f.BackgroundColor3  = Theme.BG_Item
    f.BorderSizePixel   = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 9)

    local l             = Instance.new("TextLabel", f)
    l.Size              = UDim2.new(0, 160, 1, 0)
    l.Position          = UDim2.new(0, 12, 0, 0)
    l.BackgroundTransparency = 1
    l.Text              = label
    l.TextColor3        = Theme.Text_Main
    l.Font              = Enum.Font.GothamMedium
    l.TextSize          = 12
    l.TextXAlignment    = Enum.TextXAlignment.Left

    -- hue slider
    local hueTrack      = Instance.new("TextButton", f)
    hueTrack.Size       = UDim2.new(0, 120, 0, 16)
    hueTrack.Position   = UDim2.new(1, -138, 0.5, -8)
    hueTrack.Text       = ""
    hueTrack.AutoButtonColor = false
    hueTrack.BorderSizePixel = 0
    Instance.new("UICorner", hueTrack).CornerRadius = UDim.new(0, 4)

    -- rainbow gradient
    local uig           = Instance.new("UIGradient", hueTrack)
    uig.Color           = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 0,   0)),
        ColorSequenceKeypoint.new(0.17,Color3.fromRGB(255, 255, 0)),
        ColorSequenceKeypoint.new(0.33,Color3.fromRGB(0,   255, 0)),
        ColorSequenceKeypoint.new(0.50,Color3.fromRGB(0,   255, 255)),
        ColorSequenceKeypoint.new(0.67,Color3.fromRGB(0,   0,   255)),
        ColorSequenceKeypoint.new(0.83,Color3.fromRGB(255, 0,   255)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(255, 0,   0)),
    })

    local preview       = Instance.new("Frame", f)
    preview.Size        = UDim2.new(0, 16, 0, 16)
    preview.Position    = UDim2.new(1, -18, 0.5, -8)
    preview.BackgroundColor3 = default
    preview.BorderSizePixel  = 0
    Instance.new("UICorner", preview).CornerRadius = UDim.new(0, 4)

    local function pickHue(pos)
        local bw = hueTrack.AbsoluteSize.X
        if bw <= 0 then return end
        local r   = math.clamp((pos.X - hueTrack.AbsolutePosition.X) / bw, 0, 1)
        local h   = r * 360
        local c   = Color3.fromHSV(h/360, 0.85, 0.95)
        preview.BackgroundColor3 = c
        cb(c)
    end

    local sd = { Bar = hueTrack, Update = pickHue }
    hueTrack.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch
        then
            ActiveSlider = sd
            Panels[tab].ScrollingEnabled = false
            pickHue(inp.Position)
        end
    end)
end

-- ─── Combat Tab ──────────────────────────────────────────────────────────────

Section("Combat", "AIMBOT")
Toggle("Combat", "Enable Aimlock",   Settings.Enabled,        function(v) Settings.Enabled = v end)
Dropdown("Combat", "Lock Part",      {"Head","Torso","HumanoidRootPart"}, Settings.TargetPart, function(v) Settings.TargetPart = v end)
Slider("Combat", "Aim Speed",        0.1, 5.0, Settings.AimSpeed,    true,  function(v) Settings.AimSpeed = v end)
Slider("Combat", "FOV Size",         30,  400, Settings.FOV,         false, function(v) Settings.FOV = v end)
Slider("Combat", "Smoothness",       0.01, 0.95, Settings.Smoothness, true, function(v) Settings.Smoothness = v end)
Toggle("Combat", "Silent Wallbang",  Settings.SilentWallbang, function(v) Settings.SilentWallbang = v end)
Toggle("Combat", "Wall Check",       Settings.WallCheck,      function(v) Settings.WallCheck = v end)
Toggle("Combat", "Team Check",       Settings.TeamCheck,      function(v) Settings.TeamCheck = v end)
Toggle("Combat", "Show FOV Ring",    Settings.ShowFOV,        function(v) Settings.ShowFOV = v end)

Section("Combat", "HITBOX EXPANDER")
Toggle("Combat", "Hitbox Expander",  Settings.HitboxEnabled,  function(v)
    Settings.HitboxEnabled = v
    if not v then RestoreHitboxes() end
end)
Slider("Combat", "Hitbox Size",      2, 30, Settings.HitboxSize, false, function(v)
    Settings.HitboxSize = v
    if Settings.HitboxEnabled then RestoreHitboxes(); ApplyHitboxes() end
end)

Section("Combat", "REACH")
Toggle("Combat", "Enable Reach",     Settings.ReachEnabled,   function(v)
    Settings.ReachEnabled = v
    if v then ApplyReach() end
end)
Slider("Combat", "Reach Distance",   5, 100, Settings.ReachDistance, false, function(v)
    Settings.ReachDistance = v
    if Settings.ReachEnabled then ApplyReach() end
end)

-- ─── Movement Tab ────────────────────────────────────────────────────────────

Section("Move", "SPEED")
Toggle("Move", "Speed Hack",       Settings.SpeedEnabled,   function(v) Settings.SpeedEnabled = v; SetSpeed(v) end)
Slider("Move", "Speed Multiplier", 1.0, 10.0, Settings.SpeedMultiplier, true, function(v)
    Settings.SpeedMultiplier = v
    if Settings.SpeedEnabled then SetSpeed(true) end
end)

Section("Move", "FLY")
Toggle("Move", "Enable Fly",  Settings.FlyEnabled,    function(v) Settings.FlyEnabled = v end)
Slider("Move", "Fly Speed",   10, 300, Settings.FlySpeed, false, function(v) Settings.FlySpeed = v end)

Section("Move", "MISC")
Toggle("Move", "Noclip",       Settings.NoclipEnabled,  function(v) Settings.NoclipEnabled = v end)
Toggle("Move", "Infinite Jump", Settings.InfJumpEnabled, function(v)
    Settings.InfJumpEnabled = v
    if v then EnableInfJump() else DisableInfJump() end
end)

Section("Move", "TELEPORT")

local SearchFrame       = Instance.new("Frame", Panels["Move"])
SearchFrame.Size        = UDim2.new(1, -4, 0, 34)
SearchFrame.BackgroundColor3 = Theme.BG_Item
SearchFrame.BorderSizePixel  = 0
Instance.new("UICorner", SearchFrame).CornerRadius = UDim.new(0, 9)
local SearchStroke      = Instance.new("UIStroke", SearchFrame)
SearchStroke.Color      = Theme.Accent2
SearchStroke.Thickness  = 1

local SearchBox         = Instance.new("TextBox", SearchFrame)
SearchBox.Size          = UDim2.new(1, -16, 1, -8)
SearchBox.Position      = UDim2.new(0, 8, 0, 4)
SearchBox.BackgroundTransparency = 1
SearchBox.Text          = ""
SearchBox.PlaceholderText = "🔍  Search player..."
SearchBox.PlaceholderColor3 = Theme.Text_Sub
SearchBox.TextColor3    = Theme.Text_Main
SearchBox.Font          = Enum.Font.GothamMedium
SearchBox.TextSize      = 12
SearchBox.TextXAlignment = Enum.TextXAlignment.Left
SearchBox.ClearTextOnFocus = false

local TPList            = Instance.new("Frame", Panels["Move"])
TPList.Size             = UDim2.new(1, -4, 0, 10)
TPList.BackgroundTransparency = 1
TPList.BorderSizePixel  = 0
local TPListLayout      = Instance.new("UIListLayout", TPList)
TPListLayout.SortOrder  = Enum.SortOrder.LayoutOrder
TPListLayout.Padding    = UDim.new(0, 4)
TPListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    TPList.Size = UDim2.new(1, -4, 0, TPListLayout.AbsoluteContentSize.Y)
end)

-- ── Orbit: camera lock on target head ────────────────────────────────────────
-- Camera lock is its own pass in RenderStepped — runs regardless of aimbot state.
-- When OrbitTarget exists and OrbitCamLock is on, the camera lerps toward
-- the head position independently of the aimbot RMB gating.

local function SetOrbitTarget(player)
    OrbitTarget = player
    for pl, data in pairs(OrbitRows) do
        if data.AutoBtn then
            local isTarget = (pl == player)
            data.AutoBtn.BackgroundColor3 = isTarget
                and Color3.fromRGB(220, 60, 60)
                or  Theme.Accent2
            data.AutoBtn.Text = isTarget and "■ STOP" or "⟳ AUTO"
        end
    end
end

local function BuildTPRow(player)
    if OrbitRows[player] then return end

    local row               = Instance.new("Frame", TPList)
    row.Size                = UDim2.new(1, 0, 0, 32)
    row.BackgroundTransparency = 1
    row.BorderSizePixel     = 0
    row.Name                = player.Name

    local tpBtn             = Instance.new("TextButton", row)
    tpBtn.Size              = UDim2.new(0.60, -2, 1, 0)
    tpBtn.Position          = UDim2.new(0, 0, 0, 0)
    tpBtn.BackgroundColor3  = Color3.fromRGB(20, 32, 58)
    tpBtn.Text              = "⬆  " .. player.Name
    tpBtn.TextColor3        = Theme.Text_Main
    tpBtn.Font              = Enum.Font.GothamMedium
    tpBtn.TextSize          = 11
    tpBtn.AutoButtonColor   = false
    Instance.new("UICorner", tpBtn).CornerRadius = UDim.new(0, 7)
    local tpStroke          = Instance.new("UIStroke", tpBtn)
    tpStroke.Color          = Theme.Accent2
    tpStroke.Thickness      = 0.8
    tpBtn.MouseButton1Click:Connect(function() TeleportTo(player) end)
    tpBtn.MouseButton1Down:Connect(function()
        TweenService:Create(tpBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(30, 48, 80) }):Play()
    end)
    tpBtn.MouseButton1Up:Connect(function()
        TweenService:Create(tpBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(20, 32, 58) }):Play()
    end)

    local camBtn            = Instance.new("TextButton", row)
    camBtn.Size             = UDim2.new(0.20, -2, 1, 0)
    camBtn.Position         = UDim2.new(0.60, 2, 0, 0)
    camBtn.BackgroundColor3 = Theme.Accent3
    camBtn.Text             = "📷"
    camBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    camBtn.Font             = Enum.Font.GothamBold
    camBtn.TextSize         = 14
    camBtn.AutoButtonColor  = false
    Instance.new("UICorner", camBtn).CornerRadius = UDim.new(0, 7)
    -- one-shot camera snap to player head (no orbit needed)
    camBtn.MouseButton1Click:Connect(function()
        if not player.Character then return end
        local head = player.Character:FindFirstChild("Head")
        if head then
            Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, head.Position)
        end
    end)

    local autoBtn           = Instance.new("TextButton", row)
    autoBtn.Size            = UDim2.new(0.20, -2, 1, 0)
    autoBtn.Position        = UDim2.new(0.80, 2, 0, 0)
    autoBtn.BackgroundColor3 = Theme.Accent2
    autoBtn.Text            = "⟳ AUTO"
    autoBtn.TextColor3      = Color3.fromRGB(8, 12, 22)
    autoBtn.Font            = Enum.Font.GothamBold
    autoBtn.TextSize        = 10
    autoBtn.AutoButtonColor = false
    Instance.new("UICorner", autoBtn).CornerRadius = UDim.new(0, 7)
    autoBtn.MouseButton1Click:Connect(function()
        if OrbitTarget == player then
            SetOrbitTarget(nil)
        else
            SetOrbitTarget(player)
        end
    end)

    OrbitRows[player] = { Row = row, TPBtn = tpBtn, CamBtn = camBtn, AutoBtn = autoBtn }
end

local function RefreshTPList()
    local query = SearchBox.Text:lower()
    for pl, data in pairs(OrbitRows) do
        local match = query == "" or pl.Name:lower():find(query, 1, true)
        data.Row.Visible = match ~= nil
    end
end

Section("Move", "ORBIT SETTINGS")
Slider("Move", "Orbit Radius",     1, 20,  Settings.OrbitRadius,    false, function(v) Settings.OrbitRadius = v end)
Slider("Move", "Orbit Speed",      0.5, 8, Settings.OrbitSpeed,     true,  function(v) Settings.OrbitSpeed = v end)
Toggle("Move", "Orbit Cam Lock",   Settings.OrbitCamLock,           function(v) Settings.OrbitCamLock = v end)
Slider("Move", "Cam Lock Smooth",  0.05, 1.0, Settings.OrbitCamSmooth, true, function(v) Settings.OrbitCamSmooth = v end)

for _, pl in ipairs(Players:GetPlayers()) do
    if pl ~= LocalPlayer then BuildTPRow(pl) end
end

Players.PlayerAdded:Connect(function(pl)
    BuildTPRow(pl)
    RefreshTPList()
end)

Players.PlayerRemoving:Connect(function(pl)
    if OrbitTarget == pl then SetOrbitTarget(nil) end
    if OrbitRows[pl] then
        pcall(function() OrbitRows[pl].Row:Destroy() end)
        OrbitRows[pl] = nil
    end
end)

SearchBox:GetPropertyChangedSignal("Text"):Connect(RefreshTPList)

-- ─── Visual Tab ──────────────────────────────────────────────────────────────

Section("Visual", "ESP")
Toggle("Visual", "Master ESP",       Settings.ESP_Enabled,    function(v) Settings.ESP_Enabled = v end)
Toggle("Visual", "ESP Boxes",        Settings.ESP_Boxes,      function(v) Settings.ESP_Boxes = v end)
Toggle("Visual", "ESP Names",        Settings.ESP_Names,      function(v) Settings.ESP_Names = v end)
Toggle("Visual", "ESP Health",       Settings.ESP_Health,     function(v) Settings.ESP_Health = v end)
Toggle("Visual", "ESP Distance",     Settings.ESP_Distance,   function(v) Settings.ESP_Distance = v end)
Slider("Visual", "ESP Max Distance", 200, 1000, Settings.ESP_MaxDistance, false, function(v)
    Settings.ESP_MaxDistance = v
end)

-- ─── Utils Tab ───────────────────────────────────────────────────────────────

Section("Utils", "ANTI-AFK")
Toggle("Utils", "Anti-AFK",          Settings.AntiAFKEnabled, function(v) Settings.AntiAFKEnabled = v end)

Section("Utils", "SAVE INSTANCE")
Button("Utils", "Save Workspace", function()
    task.spawn(function()
        if not saveinstance then return end
        pcall(function()
            local p = saveinstance(workspace, { SavePlayers = false, SaveScripts = false })
            StarterGui:SetCore("SendNotification", { Title = "Nova", Text = "Saved: " .. tostring(p), Duration = 5 })
        end)
    end)
end)
Button("Utils", "Save Full Game", function()
    task.spawn(function()
        if not saveinstance then return end
        pcall(function() saveinstance(game, { SavePlayers = false, SaveScripts = true }) end)
    end)
end)

-- ─── Remote Spy Tab ──────────────────────────────────────────────────────────

Section("Remote", "REMOTE SPY")
Toggle("Remote", "Enable Remote Spy", Settings.RemoteSpyEnabled, function(v) Settings.RemoteSpyEnabled = v end)
Button("Remote", "Clear Log", function() table.clear(RemoteLog) end)

local RLogFrame         = Instance.new("ScrollingFrame", Panels["Remote"])
RLogFrame.Size          = UDim2.new(1, -4, 0, 250)
RLogFrame.BackgroundColor3 = Color3.fromRGB(10, 14, 24)
RLogFrame.BorderSizePixel  = 0
RLogFrame.ScrollBarThickness = 3
RLogFrame.ScrollBarImageColor3 = Theme.Accent1
Instance.new("UICorner", RLogFrame).CornerRadius = UDim.new(0, 9)
local RLogLayout        = Instance.new("UIListLayout", RLogFrame)
RLogLayout.SortOrder    = Enum.SortOrder.LayoutOrder
RLogLayout.Padding      = UDim.new(0, 2)
RLogLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    RLogFrame.CanvasSize = UDim2.new(0, 0, 0, RLogLayout.AbsoluteContentSize.Y + 6)
end)

local RLogRows = {}
task.spawn(function()
    local last = 0
    while task.wait(0.25) do
        if #RemoteLog == last then continue end
        last = #RemoteLog
        for _, r in ipairs(RLogRows) do r:Destroy() end
        table.clear(RLogRows)
        for i = 1, math.min(50, #RemoteLog) do
            local e   = RemoteLog[i]
            local row = Instance.new("TextLabel", RLogFrame)
            row.Size  = UDim2.new(1, -6, 0, 18)
            row.BackgroundTransparency = 1
            row.Text  = string.format("[%s] %s → %s | %s", e.Time, e.Remote, e.Method, table.concat(e.Args, ", "))
            row.TextColor3 = Theme.Accent4
            row.Font  = Enum.Font.Code
            row.TextSize = 9
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.TextTruncate   = Enum.TextTruncate.AtEnd
            row.LayoutOrder    = i
            table.insert(RLogRows, row)
        end
    end
end)

-- ─── DEX Tab ─────────────────────────────────────────────────────────────────

Section("DEX", "INSTANCE EXPLORER")

local DEXFrame          = Instance.new("ScrollingFrame", Panels["DEX"])
DEXFrame.Size           = UDim2.new(1, -4, 0, 320)
DEXFrame.BackgroundColor3 = Color3.fromRGB(10, 14, 24)
DEXFrame.BorderSizePixel  = 0
DEXFrame.ScrollBarThickness = 3
DEXFrame.ScrollBarImageColor3 = Theme.Accent1
Instance.new("UICorner", DEXFrame).CornerRadius = UDim.new(0, 9)
local DEXLayout         = Instance.new("UIListLayout", DEXFrame)
DEXLayout.SortOrder     = Enum.SortOrder.LayoutOrder
DEXLayout.Padding       = UDim.new(0, 1)
DEXLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    DEXFrame.CanvasSize = UDim2.new(0, 0, 0, DEXLayout.AbsoluteContentSize.Y + 6)
end)

local function DEXBuild(root, depth)
    if depth > 3 then return end
    local ok, children = pcall(function() return root:GetChildren() end)
    if not ok then return end
    for _, child in ipairs(children) do
        local row           = Instance.new("TextButton", DEXFrame)
        row.Size            = UDim2.new(1, 0, 0, 18)
        row.BackgroundTransparency = 1
        row.Text            = string.rep("  ", depth) .. "▶ [" .. child.ClassName .. "] " .. child.Name
        row.TextColor3      = Theme.Accent2
        row.Font            = Enum.Font.Code
        row.TextSize        = 10
        row.TextXAlignment  = Enum.TextXAlignment.Left
        row.LayoutOrder     = depth * 10000 + #DEXFrame:GetChildren()
        local exp = false
        row.MouseButton1Click:Connect(function()
            exp = not exp
            row.Text = string.rep("  ", depth) .. (exp and "▼" or "▶") .. " [" .. child.ClassName .. "] " .. child.Name
            if exp then DEXBuild(child, depth + 1) end
        end)
    end
end

local function DEXClear()
    for _, c in ipairs(DEXFrame:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
end

Button("DEX", "Explore Workspace",         function() DEXClear(); DEXBuild(workspace, 0) end)
Button("DEX", "Explore LocalPlayer",       function() DEXClear(); DEXBuild(LocalPlayer, 0) end)
Button("DEX", "Explore ReplicatedStorage", function()
    DEXClear()
    local ok, rs = pcall(function() return game:GetService("ReplicatedStorage") end)
    if ok and rs then DEXBuild(rs, 0) end
end)

-- ─── Settings Tab ────────────────────────────────────────────────────────────

Section("Settings", "KEYBINDS")
KeybindRow("Settings", "Toggle GUI",     "KB_ToggleGUI",    "RightControl")
KeybindRow("Settings", "Aim Key",        "KB_AimKey",       "MouseButton2")
KeybindRow("Settings", "Fly Toggle",     "KB_FlyToggle",    "F")
KeybindRow("Settings", "Noclip Toggle",  "KB_NoclipToggle", "N")
KeybindRow("Settings", "Speed Toggle",   "KB_SpeedToggle",  "X")

Section("Settings", "UI COLOR")
ColorRow("Settings", "Accent Color", Theme.Accent1, function(c)
    -- live-update accent across window stroke and tab active state
    Theme.Accent1 = c
    WinStroke.Color = c
    BubStroke.Color = c
    LogoDot.BackgroundColor3 = c
    SearchStroke.Color = c
    if FOVCircle then FOVCircle.Color = c end
    Settings.FOVColor = c
end)
ColorRow("Settings", "FOV Ring Color",  Settings.FOVColor, function(c)
    Settings.FOVColor = c
    if FOVCircle then FOVCircle.Color = c end
end)
ColorRow("Settings", "ESP Enemy Color", Settings.ESP_EnemyColor, function(c) Settings.ESP_EnemyColor = c end)
ColorRow("Settings", "ESP Team Color",  Settings.ESP_TeamColor,  function(c) Settings.ESP_TeamColor  = c end)

Section("Settings", "MISC")
Toggle("Settings", "Always On Top", true, function(v)
    Gui.DisplayOrder = v and 999999999 or 10
end)

-- ─── Keybind capture (global InputBegan) ─────────────────────────────────────

local function EnumName(e)
    if not e then return "None" end
    local s = tostring(e)
    return s:match("%.([^%.]+)$") or s
end

table.insert(Connections, UserInputService.InputBegan:Connect(function(inp, gp)
    -- Rebind capture — runs regardless of gameProcessed
    if BindingSlot then
        local isKC  = inp.UserInputType == Enum.UserInputType.Keyboard
        local isMB  = inp.UserInputType == Enum.UserInputType.MouseButton1
                   or inp.UserInputType == Enum.UserInputType.MouseButton2
                   or inp.UserInputType == Enum.UserInputType.MouseButton3

        if isKC or isMB then
            local newVal = isKC and inp.KeyCode or inp.UserInputType

            -- Escape cancels the rebind
            if isKC and inp.KeyCode == Enum.KeyCode.Escape then
                if KeybindLabels[BindingSlot] then
                    local lbl = KeybindLabels[BindingSlot]
                    lbl.Text      = EnumName(Settings[BindingSlot])
                    lbl.TextColor3 = Theme.Accent1
                    local s = lbl:FindFirstChildOfClass("UIStroke")
                    if s then s.Color = Theme.Accent2 end
                end
                BindingSlot = nil
                return
            end

            Settings[BindingSlot] = newVal

            -- Sync AimKey if it was the aim slot
            if BindingSlot == "KB_AimKey" then
                Settings.AimKey = newVal
            end

            if KeybindLabels[BindingSlot] then
                local lbl = KeybindLabels[BindingSlot]
                lbl.Text       = EnumName(newVal)
                lbl.TextColor3 = Theme.Accent1
                local s = lbl:FindFirstChildOfClass("UIStroke")
                if s then s.Color = Theme.Accent2 end
            end
            BindingSlot = nil
            return
        end
    end

    if gp then return end

    -- Toggle GUI
    if inp.UserInputType == Enum.UserInputType.Keyboard
        and inp.KeyCode == Settings.KB_ToggleGUI
    then
        Win.Visible = not Win.Visible
        Bubble.Visible = not Win.Visible
        return
    end

    -- Fly toggle (keyboard shortcut)
    if inp.UserInputType == Enum.UserInputType.Keyboard
        and inp.KeyCode == Settings.KB_FlyToggle
    then
        Settings.FlyEnabled = not Settings.FlyEnabled
        return
    end

    -- Noclip toggle
    if inp.UserInputType == Enum.UserInputType.Keyboard
        and inp.KeyCode == Settings.KB_NoclipToggle
    then
        Settings.NoclipEnabled = not Settings.NoclipEnabled
        return
    end

    -- Speed toggle
    if inp.UserInputType == Enum.UserInputType.Keyboard
        and inp.KeyCode == Settings.KB_SpeedToggle
    then
        Settings.SpeedEnabled = not Settings.SpeedEnabled
        SetSpeed(Settings.SpeedEnabled)
        return
    end

    -- Aim key (mouse)
    if inp.UserInputType == Settings.AimKey then Aiming = true end
end))

-- ─── Unload Button ───────────────────────────────────────────────────────────

local UnloadBtn         = Instance.new("TextButton", Win)
UnloadBtn.Size          = UDim2.new(1, -16, 0, 32)
UnloadBtn.Position      = UDim2.new(0, 8, 1, -40)
UnloadBtn.BackgroundColor3 = Theme.Danger
UnloadBtn.Text          = "⏏  Unload Nova"
UnloadBtn.TextColor3    = Color3.fromRGB(255, 255, 255)
UnloadBtn.Font          = Enum.Font.GothamBold
UnloadBtn.TextSize      = 12
UnloadBtn.AutoButtonColor = false
Instance.new("UICorner", UnloadBtn).CornerRadius = UDim.new(0, 9)

UnloadBtn.MouseButton1Down:Connect(function()
    TweenService:Create(UnloadBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(150, 30, 45) }):Play()
end)
UnloadBtn.MouseButton1Click:Connect(function()
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    table.clear(Connections)
    for char in pairs(ESP_Cache) do RemoveESP(char) end
    RestoreHitboxes()
    SetSpeed(false)
    DisableInfJump()
    SetOrbitTarget(nil)
    if FOVCircle then pcall(function() FOVCircle.Visible = false; FOVCircle:Remove() end) end
    Gui:Destroy()
end)

-- ─── Global Input (slider + aim key release) ─────────────────────────────────

table.insert(Connections, UserInputService.InputChanged:Connect(function(inp)
    if ActiveSlider and (
        inp.UserInputType == Enum.UserInputType.MouseMovement or
        inp.UserInputType == Enum.UserInputType.Touch
    ) then ActiveSlider.Update(inp.Position) end
end))

table.insert(Connections, UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch
    then
        if ActiveSlider then
            ActiveSlider = nil
            for _, p in pairs(Panels) do p.ScrollingEnabled = true end
        end
    end
    if inp.UserInputType == Settings.AimKey then Aiming = false end
end))

-- ─── Noclip ──────────────────────────────────────────────────────────────────

table.insert(Connections, RunService.Stepped:Connect(function()
    if not Settings.NoclipEnabled or not LocalPlayer.Character then return end
    for _, p in ipairs(LocalPlayer.Character:GetDescendants()) do
        if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
    end
end))

-- ─── ESP Hooks ───────────────────────────────────────────────────────────────

for _, pl in ipairs(Players:GetPlayers()) do
    if pl ~= LocalPlayer then
        if pl.Character then CreateESP(pl.Character) end
        table.insert(Connections, pl.CharacterAdded:Connect(CreateESP))
    end
end

table.insert(Connections, Players.PlayerAdded:Connect(function(pl)
    table.insert(Connections, pl.CharacterAdded:Connect(CreateESP))
end))

table.insert(Connections, Players.PlayerRemoving:Connect(function(pl)
    if pl.Character then RemoveESP(pl.Character) end
end))

table.insert(Connections, LocalPlayer.CharacterAdded:Connect(function()
    OrigWalkSpeed = nil
    task.wait(1)
    if Settings.SpeedEnabled   then SetSpeed(true)   end
    if Settings.InfJumpEnabled then EnableInfJump()  end
    if Settings.ReachEnabled   then ApplyReach()     end
end))

-- ─── Main Loop ───────────────────────────────────────────────────────────────

table.insert(Connections, RunService.RenderStepped:Connect(function(dt)
    _cache.t = -1

    local mpos = UserInputService:GetMouseLocation()

    -- FOV circle
    if FOVCircle then
        FOVCircle.Position = mpos
        FOVCircle.Radius   = Settings.FOV
        FOVCircle.Visible  = Settings.ShowFOV and Settings.Enabled
        FOVCircle.Color    = Settings.FOVColor
    end

    UpdateESP()

    if Settings.HitboxEnabled then ApplyHitboxes() end
    if Settings.ReachEnabled  then ApplyReach()    end

    -- Fly
    if Settings.FlyEnabled and LocalPlayer.Character then
        local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            local mv = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W)         then mv += Camera.CFrame.LookVector  end
            if UserInputService:IsKeyDown(Enum.KeyCode.S)         then mv -= Camera.CFrame.LookVector  end
            if UserInputService:IsKeyDown(Enum.KeyCode.A)         then mv -= Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D)         then mv += Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space)     then mv += Vector3.new(0,1,0)        end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then mv -= Vector3.new(0,1,0)        end
            if mv.Magnitude > 0 then root.CFrame += mv.Unit * (Settings.FlySpeed * dt) end
            root.AssemblyLinearVelocity = Vector3.zero
        end
    end

    -- ── ORBIT PASS ─────────────────────────────────────────────────────────
    -- Moves localplayer in a circle around the target.
    if OrbitTarget and OrbitTarget.Character then
        local orbitRoot = OrbitTarget.Character:FindFirstChild("HumanoidRootPart")
        local myRoot    = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if orbitRoot and myRoot then
            OrbitAngle = OrbitAngle + dt * Settings.OrbitSpeed
            local offset = Vector3.new(
                math.cos(OrbitAngle) * Settings.OrbitRadius,
                0.5,
                math.sin(OrbitAngle) * Settings.OrbitRadius
            )
            myRoot.CFrame = CFrame.new(orbitRoot.Position + offset)
            myRoot.AssemblyLinearVelocity = Vector3.zero
        end
    end

    -- ── ORBIT CAMERA LOCK ────────────────────────────────────────────────
    if Settings.OrbitCamLock and OrbitTarget and OrbitTarget.Character then
        local head = OrbitTarget.Character:FindFirstChild("Head")
        if head then
            local lookTarget = CFrame.lookAt(Camera.CFrame.Position, head.Position)
            local alpha      = math.clamp((1 - Settings.OrbitCamSmooth) * (dt * 60), 0.01, 1)
            Camera.CFrame    = Camera.CFrame:Lerp(lookTarget, alpha)
        end
    end

    -- ── AIMBOT PASS (RMB / KB_AimKey gated) ─────────────────────────────
    if Settings.Enabled and Aiming then
        local _, tp = GetTarget()
        if tp then
            local lookTarget = CFrame.lookAt(Camera.CFrame.Position, tp.Position)
            local alpha      = math.clamp((1 - Settings.Smoothness) * (dt * 60) * Settings.AimSpeed, 0.01, 1)
            Camera.CFrame    = Camera.CFrame:Lerp(lookTarget, alpha)
        end
    end
end))