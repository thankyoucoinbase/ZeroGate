--[[
    AK Admin - Clean Reconstruction
    Original: https://absent.wtf/AKADMIN.lua
    Discord: https://discord.gg/akadmin

    Reconstructed from deobfuscated bytecode analysis.
    Auth/whitelist is bypassed (placeholder for user to add later).
    Commands loaded from GitHub remote URL.
]]

------------------------------------------------------------
-- GUARD: prevent double execution
------------------------------------------------------------
if _G.AK_ADMIN_EXECUTED then return end
_G.AK_ADMIN_EXECUTED = true

------------------------------------------------------------
-- URLS
------------------------------------------------------------
local CMDS_URL        = "https://raw.githubusercontent.com/thankyoucoinbase/ZeroGate/refs/heads/main/cmds.lua"
local BASEPLATE_URL   = "https://ib2.dev/absent/lua/extendedbaseplate.lua"
local KEY_URL         = "https://absent.wtf/Mains/Key.json"
local WHITELIST_URL   = "https://absent.wtf/Mains/whitelist.json"
local HEADSHOT_URL    = "https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=420&height=420&format=png"
local INVENTORY_URL   = "https://inventory.roblox.com/v1/users/"
local DISCORD_URL     = "https://discord.gg/akadmin"

------------------------------------------------------------
-- SERVICES
------------------------------------------------------------
local cloneref = cloneref or function(x) return x end

local function getService(name)
    return cloneref(game:GetService(name))
end

local Players             = getService("Players")
local TweenService        = getService("TweenService")
local UserInputService    = getService("UserInputService")
local GuiService          = getService("GuiService")
local HttpService         = getService("HttpService")
local StarterGui          = getService("StarterGui")
local RunService          = getService("RunService")
local TeleportService     = getService("TeleportService")
local MarketplaceService  = getService("MarketplaceService")
local CoreGui             = getService("CoreGui")
local SoundService        = getService("SoundService")

local localPlayer = Players.LocalPlayer

------------------------------------------------------------
-- GLOBALS (cmds.lua expects these in _ENV)
------------------------------------------------------------
localPlayer         = localPlayer
userInputService    = UserInputService
guiService          = GuiService
userService         = getService("UserService")
starterGui          = StarterGui
runService          = RunService
teleportService     = TeleportService
avatarEditorService = getService("AvatarEditorService")
soundService        = SoundService

-- Tracking tables used by commands
hiddenPlayers         = {}
mutedPlayers          = {}
morphedPlayers        = {}
originalDescriptions  = {}
noclipConnections     = {}
seatState             = { hsc = nil, hst = nil, bsc = nil, bst = nil }

-- Join server limits
JOIN_USERINFO_MAX_PER_MIN = 250
JOIN_USERINFO_WINDOW      = 60
JOIN_MAX_VISIBLE          = 50

-- UI element refs (populated during UI build)
uiElements = {}

------------------------------------------------------------
-- QUEUE ON TELEPORT (re-execute on server hop)
------------------------------------------------------------
pcall(function()
    if queue_on_teleport or queueonteleport then
        local qot = queue_on_teleport or queueonteleport
        qot('loadstring(game:HttpGet("https://raw.githubusercontent.com/thankyoucoinbase/ZeroGate/refs/heads/main/AK-Admin-Loader.lua"))()')
    end
end)

------------------------------------------------------------
-- THEME (AK Admin blue glass style)
------------------------------------------------------------
local Theme = {
    bg        = Color3.fromRGB(22, 36, 58),
    bgDark    = Color3.fromRGB(16, 28, 48),
    panel     = Color3.fromRGB(28, 44, 68),
    surface   = Color3.fromRGB(34, 52, 78),
    surfHov   = Color3.fromRGB(42, 62, 92),
    border    = Color3.fromRGB(50, 72, 105),
    borderDim = Color3.fromRGB(38, 58, 88),
    accent    = Color3.fromRGB(80, 160, 255),
    accentDim = Color3.fromRGB(60, 120, 200),
    txt       = Color3.fromRGB(220, 230, 245),
    txtSub    = Color3.fromRGB(140, 165, 200),
    txtFaint  = Color3.fromRGB(90, 115, 155),
    white     = Color3.fromRGB(255, 255, 255),
    red       = Color3.fromRGB(220, 70, 70),
    green     = Color3.fromRGB(80, 220, 120),
    yellow    = Color3.fromRGB(220, 185, 50),
    -- transparencies
    bgT       = 0.12,
    panelT    = 0.08,
    surfaceT  = 0.25,
}

------------------------------------------------------------
-- EXECUTOR DETECTION
------------------------------------------------------------
local executorName = "Unknown"
local executorAccent = Theme.accent
do
    local ok, name = pcall(function()
        if identifyexecutor then return identifyexecutor() end
        return nil
    end)
    if ok and name then
        executorName = name
        local brandColors = {
            Delta     = Color3.fromRGB(160, 80, 255),
            Xeno      = Color3.fromRGB(255, 80, 200),
            Velocity  = Color3.fromRGB(220, 220, 235),
            Potassium = Color3.fromRGB(60, 210, 200),
            Solara    = Color3.fromRGB(255, 165, 50),
            Volt      = Color3.fromRGB(100, 180, 255),
            Wave      = Color3.fromRGB(100, 200, 255),
            Synapse   = Color3.fromRGB(255, 50, 50),
            Fluxus    = Color3.fromRGB(80, 160, 255),
            Zenith    = Color3.fromRGB(130, 200, 255),
        }
        for bname, color in pairs(brandColors) do
            if string.find(name, bname, 1, true) then
                executorAccent = color
                break
            end
        end
    end
end

------------------------------------------------------------
-- TWEEN PRESETS
------------------------------------------------------------
local Tweens = {
    fast    = TweenInfo.new(0.1,  Enum.EasingStyle.Quad,  Enum.EasingDirection.Out),
    med     = TweenInfo.new(0.2,  Enum.EasingStyle.Quad,  Enum.EasingDirection.Out),
    slide   = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    bounce  = TweenInfo.new(0.3,  Enum.EasingStyle.Back,  Enum.EasingDirection.Out),
    pulse   = TweenInfo.new(1.2,  Enum.EasingStyle.Sine,  Enum.EasingDirection.InOut, -1, true),
    notifIn = TweenInfo.new(0.5,  Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    notifOut= TweenInfo.new(0.4,  Enum.EasingStyle.Quart, Enum.EasingDirection.In),
}

------------------------------------------------------------
-- HELPER FUNCTIONS
------------------------------------------------------------
local function playTween(target, tweenInfo, goals)
    local tw = TweenService:Create(target, tweenInfo, goals)
    tw:Play()
    return tw
end

local function createElement(className, props)
    local inst = Instance.new(className)
    local parent = props.Parent
    props.Parent = nil
    for k, v in pairs(props) do
        inst[k] = v
    end
    if parent then
        inst.Parent = parent
    end
    return inst
end

local function addCorner(radius, parent)
    return createElement("UICorner", {
        CornerRadius = UDim.new(0, radius),
        Parent = parent,
    })
end

local function addStroke(color, transparency, parent, thickness)
    return createElement("UIStroke", {
        Color = color,
        Transparency = transparency or 0,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function addPadding(l, r, t, b, parent)
    return createElement("UIPadding", {
        PaddingLeft   = UDim.new(0, l),
        PaddingRight  = UDim.new(0, r),
        PaddingTop    = UDim.new(0, t),
        PaddingBottom = UDim.new(0, b),
        Parent = parent,
    })
end

local function addListLayout(dir, hAlign, vAlign, padding, parent)
    return createElement("UIListLayout", {
        FillDirection       = dir or Enum.FillDirection.Horizontal,
        HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Center,
        VerticalAlignment   = vAlign or Enum.VerticalAlignment.Center,
        SortOrder           = Enum.SortOrder.LayoutOrder,
        Padding             = UDim.new(0, padding or 0),
        Parent = parent,
    })
end

------------------------------------------------------------
-- SOUNDS
------------------------------------------------------------
local function makeSound(id, volume, speed)
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Volume = volume or 0.5
    s.PlaybackSpeed = speed or 1
    s.RollOffMaxDistance = 0
    s.Parent = SoundService
    return s
end

local sfxClick = makeSound("rbxassetid://6895079853", 0.3, 1.2)
local sfxOk    = makeSound("rbxassetid://6895079853", 0.3, 0.8)

local function playSfx(sound)
    pcall(function()
        SoundService:PlayLocalSound(sound)
    end)
end

------------------------------------------------------------
-- DESTROY PREVIOUS GUI
------------------------------------------------------------
for _, child in ipairs(CoreGui:GetChildren()) do
    if child.Name == "AKAdminGui" then
        child:Destroy()
    end
end
task.wait(0.05)

------------------------------------------------------------
-- STATE
------------------------------------------------------------
local commands = {}
local commandCount = 0
local windowVisible = true

------------------------------------------------------------
-- SCREEN GUI
------------------------------------------------------------
local screenGui = createElement("ScreenGui", {
    Name = "AKAdminGui",
    ResetOnSpawn = false,
    DisplayOrder = 52,
    IgnoreGuiInset = true,
    Parent = CoreGui,
})

------------------------------------------------------------
-- MAIN WINDOW (blue glass panel - 300x420)
------------------------------------------------------------
local WIN_W = 300
local WIN_H = 420
local TITLE_H = 42
local SEARCH_H = 36
local CORNER = 12

local mainFrame = createElement("Frame", {
    Name = "MainFrame",
    Size = UDim2.new(0, WIN_W, 0, WIN_H),
    Position = UDim2.new(0.5, -(WIN_W/2), 0.5, -(WIN_H/2)),
    BackgroundColor3 = Theme.bg,
    BackgroundTransparency = Theme.bgT,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Parent = screenGui,
})
addCorner(CORNER, mainFrame)
addStroke(Theme.border, 0.3, mainFrame, 1.5)

-- Gradient overlay for the glass effect
local gradient = createElement("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 55, 85)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(25, 42, 68)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 32, 55)),
    }),
    Rotation = 160,
    Parent = mainFrame,
})

------------------------------------------------------------
-- TITLE BAR
------------------------------------------------------------
local titleBar = createElement("Frame", {
    Name = "TitleBar",
    Size = UDim2.new(1, 0, 0, TITLE_H),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Parent = mainFrame,
})

-- AK Logo icon
local logoIcon = createElement("ImageLabel", {
    Name = "LogoIcon",
    Size = UDim2.new(0, 24, 0, 24),
    Position = UDim2.new(0, 12, 0.5, 0),
    AnchorPoint = Vector2.new(0, 0.5),
    BackgroundTransparency = 1,
    Image = "rbxassetid://132440478962916",
    ImageColor3 = Theme.accent,
    ScaleType = Enum.ScaleType.Fit,
    Parent = titleBar,
})

-- Title text
local titleLabel = createElement("TextLabel", {
    Name = "TitleLabel",
    Size = UDim2.new(1, -120, 1, 0),
    Position = UDim2.new(0, 42, 0, 0),
    BackgroundTransparency = 1,
    Text = "AK Commands",
    TextColor3 = Theme.txt,
    TextSize = 16,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = titleBar,
})

-- Settings button (gear)
local settingsBtn = createElement("ImageButton", {
    Name = "SettingsBtn",
    Size = UDim2.new(0, 20, 0, 20),
    Position = UDim2.new(1, -72, 0.5, 0),
    AnchorPoint = Vector2.new(0, 0.5),
    BackgroundTransparency = 1,
    Image = "rbxassetid://73577105416536",
    ImageColor3 = Theme.txtSub,
    AutoButtonColor = false,
    Parent = titleBar,
})
settingsBtn.MouseEnter:Connect(function()
    playTween(settingsBtn, Tweens.fast, { ImageColor3 = Theme.txt })
end)
settingsBtn.MouseLeave:Connect(function()
    playTween(settingsBtn, Tweens.fast, { ImageColor3 = Theme.txtSub })
end)

-- Minimize button
local minimizeBtn = createElement("TextButton", {
    Name = "MinimizeBtn",
    Size = UDim2.new(0, 20, 0, 20),
    Position = UDim2.new(1, -48, 0.5, 0),
    AnchorPoint = Vector2.new(0, 0.5),
    BackgroundTransparency = 1,
    Text = "-",
    TextColor3 = Theme.txtSub,
    TextSize = 18,
    Font = Enum.Font.GothamBold,
    AutoButtonColor = false,
    Parent = titleBar,
})
minimizeBtn.MouseEnter:Connect(function()
    playTween(minimizeBtn, Tweens.fast, { TextColor3 = Theme.txt })
end)
minimizeBtn.MouseLeave:Connect(function()
    playTween(minimizeBtn, Tweens.fast, { TextColor3 = Theme.txtSub })
end)

-- Close button
local closeBtn = createElement("TextButton", {
    Name = "CloseBtn",
    Size = UDim2.new(0, 20, 0, 20),
    Position = UDim2.new(1, -24, 0.5, 0),
    AnchorPoint = Vector2.new(0, 0.5),
    BackgroundTransparency = 1,
    Text = "X",
    TextColor3 = Theme.txtSub,
    TextSize = 14,
    Font = Enum.Font.GothamBold,
    AutoButtonColor = false,
    Parent = titleBar,
})
closeBtn.MouseEnter:Connect(function()
    playTween(closeBtn, Tweens.fast, { TextColor3 = Theme.red })
end)
closeBtn.MouseLeave:Connect(function()
    playTween(closeBtn, Tweens.fast, { TextColor3 = Theme.txtSub })
end)

-- Title separator line
createElement("Frame", {
    Name = "TitleSep",
    Size = UDim2.new(1, -24, 0, 1),
    Position = UDim2.new(0, 12, 0, TITLE_H),
    BackgroundColor3 = Theme.border,
    BackgroundTransparency = 0.5,
    BorderSizePixel = 0,
    Parent = mainFrame,
})

------------------------------------------------------------
-- SEARCH BAR
------------------------------------------------------------
local searchContainer = createElement("Frame", {
    Name = "SearchContainer",
    Size = UDim2.new(1, -24, 0, SEARCH_H),
    Position = UDim2.new(0, 12, 0, TITLE_H + 8),
    BackgroundColor3 = Theme.bgDark,
    BackgroundTransparency = 0.3,
    BorderSizePixel = 0,
    Parent = mainFrame,
})
addCorner(8, searchContainer)
addStroke(Theme.borderDim, 0.4, searchContainer)

-- Search icon
createElement("TextLabel", {
    Name = "SearchIcon",
    Size = UDim2.new(0, 24, 1, 0),
    Position = UDim2.new(0, 8, 0, 0),
    BackgroundTransparency = 1,
    Text = "Q",
    TextColor3 = Theme.txtFaint,
    TextSize = 14,
    Font = Enum.Font.GothamBold,
    Parent = searchContainer,
})

-- Search input
local searchInput = createElement("TextBox", {
    Name = "SearchInput",
    Size = UDim2.new(1, -40, 1, 0),
    Position = UDim2.new(0, 32, 0, 0),
    BackgroundTransparency = 1,
    Text = "",
    TextColor3 = Theme.txt,
    PlaceholderColor3 = Theme.txtFaint,
    PlaceholderText = "Search Commands (0)",
    TextSize = 13,
    Font = Enum.Font.GothamMedium,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
    Parent = searchContainer,
})

------------------------------------------------------------
-- COMMAND INPUT BAR (bottom of window)
------------------------------------------------------------
local CMD_INPUT_H = 34

local cmdInputBar = createElement("Frame", {
    Name = "CmdInputBar",
    Size = UDim2.new(1, -20, 0, CMD_INPUT_H),
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 10, 1, -8),
    BackgroundColor3 = Theme.bgDark,
    BackgroundTransparency = 0.3,
    BorderSizePixel = 0,
    ZIndex = 5,
    Parent = mainFrame,
})
addCorner(8, cmdInputBar)
addStroke(Theme.borderDim, 0.4, cmdInputBar)

createElement("TextLabel", {
    Name = "CmdPrefix",
    Size = UDim2.new(0, 18, 1, 0),
    Position = UDim2.new(0, 8, 0, 0),
    BackgroundTransparency = 1,
    Text = ">",
    TextColor3 = Theme.accent,
    TextSize = 14,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 6,
    Parent = cmdInputBar,
})

local cmdInput = createElement("TextBox", {
    Name = "CmdInput",
    Size = UDim2.new(1, -32, 1, 0),
    Position = UDim2.new(0, 26, 0, 0),
    BackgroundTransparency = 1,
    Text = "",
    TextColor3 = Theme.txt,
    PlaceholderColor3 = Theme.txtFaint,
    PlaceholderText = "Type a command...",
    TextSize = 13,
    Font = Enum.Font.GothamMedium,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
    ZIndex = 6,
    Parent = cmdInputBar,
})

------------------------------------------------------------
-- COMMAND SCROLL LIST
------------------------------------------------------------
local scrollTop = TITLE_H + SEARCH_H + 14
local scrollBottom = CMD_INPUT_H + 18

local cmdScroll = createElement("ScrollingFrame", {
    Name = "CmdScroll",
    Size = UDim2.new(1, -20, 1, -(scrollTop + scrollBottom)),
    Position = UDim2.new(0, 10, 0, scrollTop),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Theme.border,
    ScrollBarImageTransparency = 0.3,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    Parent = mainFrame,
})

addListLayout(
    Enum.FillDirection.Vertical,
    Enum.HorizontalAlignment.Center,
    nil,
    3,
    cmdScroll
)
addPadding(3, 3, 3, 3, cmdScroll)

------------------------------------------------------------
-- TOP-RIGHT STATUS BAR
------------------------------------------------------------
local SB_H = 42
local SB_ICON = 32
local SB_GAP = 6

local statusBar = createElement("Frame", {
    Name = "AKStatusBar",
    Size = UDim2.new(0, 0, 0, SB_H),
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -10, 0, 10),
    BackgroundTransparency = 1,
    AutomaticSize = Enum.AutomaticSize.X,
    Parent = screenGui,
})

addListLayout(
    Enum.FillDirection.Horizontal,
    Enum.HorizontalAlignment.Right,
    Enum.VerticalAlignment.Center,
    SB_GAP,
    statusBar
)

-- Icon button helper
local function makeStatusIcon(name, icon, layoutOrder, callback)
    local btn = createElement("ImageButton", {
        Name = name,
        Size = UDim2.new(0, SB_ICON, 0, SB_ICON),
        BackgroundColor3 = Theme.bg,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        Image = icon,
        ImageColor3 = Theme.txtSub,
        ScaleType = Enum.ScaleType.Fit,
        AutoButtonColor = false,
        LayoutOrder = layoutOrder,
        Parent = statusBar,
    })
    addCorner(8, btn)
    addPadding(6, 6, 6, 6, btn)

    btn.MouseEnter:Connect(function()
        playTween(btn, Tweens.fast, { ImageColor3 = Theme.white, BackgroundTransparency = 0.1 })
    end)
    btn.MouseLeave:Connect(function()
        playTween(btn, Tweens.fast, { ImageColor3 = Theme.txtSub, BackgroundTransparency = 0.25 })
    end)
    if callback then
        btn.MouseButton1Click:Connect(callback)
    end
    return btn
end

-- WiFi / connection icon
makeStatusIcon("WiFiBtn", "rbxassetid://6031094670", 1, function()
    showNotification("AK ADMIN", "Connected to server", 2)
end)

-- Tag selector icon (the bird/chicken)
local tagSelectorBtn = makeStatusIcon("TagBtn", "rbxassetid://6034287594", 2)

-- AK logo icon
local akLogoBtn = makeStatusIcon("AKLogoBtn", "rbxassetid://132440478962916", 3, function()
    windowVisible = not windowVisible
    mainFrame.Visible = windowVisible
end)
akLogoBtn.ImageColor3 = Theme.accent

-- Status info panel (right side)
local statusInfo = createElement("Frame", {
    Name = "StatusInfo",
    Size = UDim2.new(0, 140, 0, SB_H),
    BackgroundColor3 = Theme.bg,
    BackgroundTransparency = 0.25,
    BorderSizePixel = 0,
    LayoutOrder = 4,
    Parent = statusBar,
})
addCorner(8, statusInfo)

-- Green dot
local greenDot = createElement("Frame", {
    Name = "GreenDot",
    Size = UDim2.new(0, 8, 0, 8),
    Position = UDim2.new(0, 10, 0, 10),
    BackgroundColor3 = Theme.green,
    BorderSizePixel = 0,
    Parent = statusInfo,
})
addCorner(4, greenDot)
playTween(greenDot, Tweens.pulse, { BackgroundColor3 = Color3.fromRGB(130, 255, 160) })

-- "AK ACTIVE" label
createElement("TextLabel", {
    Name = "ActiveLabel",
    Size = UDim2.new(0, 80, 0, 14),
    Position = UDim2.new(0, 22, 0, 6),
    BackgroundTransparency = 1,
    Text = "AK ACTIVE",
    TextColor3 = Theme.txt,
    TextSize = 12,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = statusInfo,
})

-- FPS counter
local fpsLabel = createElement("TextLabel", {
    Name = "FPSLabel",
    Size = UDim2.new(0, 55, 0, 12),
    Position = UDim2.new(0, 10, 0, 24),
    BackgroundTransparency = 1,
    Text = "FPS: --",
    TextColor3 = Theme.txtFaint,
    TextSize = 11,
    Font = Enum.Font.GothamMedium,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = statusInfo,
})

-- Executor name label
createElement("TextLabel", {
    Name = "ExecLabel",
    Size = UDim2.new(0, 65, 0, 12),
    Position = UDim2.new(0, 68, 0, 24),
    BackgroundTransparency = 1,
    Text = executorName,
    TextColor3 = Theme.txtFaint,
    TextSize = 11,
    Font = Enum.Font.GothamMedium,
    TextXAlignment = Enum.TextXAlignment.Right,
    Parent = statusInfo,
})

-- Dropdown arrow
local dropArrow = createElement("TextButton", {
    Name = "DropArrow",
    Size = UDim2.new(1, -8, 0, 10),
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 4, 1, -2),
    BackgroundColor3 = Theme.border,
    BackgroundTransparency = 0.5,
    BorderSizePixel = 0,
    Text = "V",
    TextColor3 = Theme.txtFaint,
    TextSize = 8,
    Font = Enum.Font.GothamBold,
    AutoButtonColor = false,
    Parent = statusInfo,
})
addCorner(4, dropArrow)

-- FPS updater
task.spawn(function()
    local lastTime = tick()
    local frames = 0
    RunService.Heartbeat:Connect(function()
        frames = frames + 1
        local now = tick()
        if now - lastTime >= 1 then
            pcall(function()
                fpsLabel.Text = "FPS: " .. tostring(frames)
            end)
            frames = 0
            lastTime = now
        end
    end)
end)

------------------------------------------------------------
-- OVERHEAD TAG SYSTEM (PxTag-style with cross-client sync)
------------------------------------------------------------
local FULL_W, FULL_H = 200, 42
local MINI_W, MINI_H = 50, 50
local FULL_DIST, SHRINK_START = 30, 55
local BB_OFFSET = Vector3.new(0, 3.2, 0)
local AK_ANIM_ID = nil -- disabled: visible arm glitch
local AK_ANIM_SPEED = 1.42
local AK_TAG_ATTR = "AKTagIdx"

local function lerpN(a, b, t) return a + (b - a) * t end
local function lerpColor(a, b, t)
    return Color3.new(lerpN(a.R, b.R, t), lerpN(a.G, b.G, t), lerpN(a.B, b.B, t))
end

local TAG_PRESETS = {
    { name = "AK STAFF", label = "Staff",
      icon = "rbxassetid://6031280882",
      bg = Color3.fromRGB(8, 8, 10), gradA = Color3.fromRGB(28, 28, 34), gradB = Color3.fromRGB(8, 8, 10),
      border = Color3.fromRGB(180, 180, 190), borderB = Color3.fromRGB(100, 100, 110),
      namec = Color3.fromRGB(220, 220, 230), userc = Color3.fromRGB(140, 140, 155),
      spark = {Color3.fromRGB(180,180,190), Color3.fromRGB(220,220,230), Color3.fromRGB(160,160,175)},
    },
    { name = "AK ADMIN", label = "Admin",
      icon = "rbxassetid://6031094670",
      bg = Color3.fromRGB(2, 6, 18), gradA = Color3.fromRGB(8, 22, 60), gradB = Color3.fromRGB(2, 6, 18),
      border = Color3.fromRGB(70, 140, 255), borderB = Color3.fromRGB(30, 70, 200),
      namec = Color3.fromRGB(170, 210, 255), userc = Color3.fromRGB(90, 150, 255),
      spark = {Color3.fromRGB(70,140,255), Color3.fromRGB(120,180,255), Color3.fromRGB(160,210,255)},
    },
    { name = "AK VIP", label = "VIP",
      icon = "rbxassetid://6034287594",
      bg = Color3.fromRGB(12, 10, 2), gradA = Color3.fromRGB(50, 40, 5), gradB = Color3.fromRGB(12, 10, 2),
      border = Color3.fromRGB(255, 215, 0), borderB = Color3.fromRGB(180, 140, 0),
      namec = Color3.fromRGB(255, 240, 150), userc = Color3.fromRGB(210, 175, 40),
      spark = {Color3.fromRGB(255,215,0), Color3.fromRGB(255,240,100), Color3.fromRGB(255,180,30)},
    },
    { name = "AK USER", label = "User",
      icon = "rbxassetid://6034509993",
      bg = Color3.fromRGB(2, 10, 6), gradA = Color3.fromRGB(8, 40, 22), gradB = Color3.fromRGB(2, 10, 6),
      border = Color3.fromRGB(60, 200, 100), borderB = Color3.fromRGB(30, 130, 60),
      namec = Color3.fromRGB(160, 240, 190), userc = Color3.fromRGB(80, 180, 120),
      spark = {Color3.fromRGB(60,200,100), Color3.fromRGB(120,230,150), Color3.fromRGB(80,255,130)},
    },
    { name = "OWNER", label = "Owner",
      icon = "rbxassetid://6031094670",
      bg = Color3.fromRGB(12, 2, 2), gradA = Color3.fromRGB(50, 6, 6), gradB = Color3.fromRGB(12, 2, 2),
      border = Color3.fromRGB(255, 55, 55), borderB = Color3.fromRGB(190, 15, 15),
      namec = Color3.fromRGB(255, 120, 120), userc = Color3.fromRGB(220, 70, 70),
      spark = {Color3.fromRGB(255,50,50), Color3.fromRGB(255,120,80), Color3.fromRGB(255,80,40)},
      glitch = true,
    },
}

-- Shared table for cross-client detection (same as PxTag pattern)
if not shared.AKAdminUsers then shared.AKAdminUsers = {} end
shared.AKAdminUsers[localPlayer.UserId] = true

local currentTagPreset = nil
local activeTags = {} -- userId -> { bb, hbConn, stars }
local tagConns = {} -- connections to clean up

local function cleanupTag(userId)
    local t = activeTags[userId]
    if t then
        pcall(function() if t.hbConn then t.hbConn:Disconnect() end end)
        pcall(function() if t.bb then t.bb:Destroy() end end)
        activeTags[userId] = nil
    end
end

local function buildTag(hrp, player, preset)
    local userId = player.UserId
    cleanupTag(userId)

    local showName = preset.name
    local showUser = "@" .. player.Name
    local isOwner = preset.glitch
    local WHITE = Color3.fromRGB(255, 255, 255)

    -- Calculate width based on text
    local iconSz = FULL_H - 10
    local iconEnd = 3 + iconSz + 6
    local nameW = math.ceil(#showName * 7.5) + iconEnd + 14
    local userW = math.ceil(#showUser * 5.5) + iconEnd + 14
    local baseWidth = math.max(math.min(math.max(nameW, userW), 260), iconEnd + 40)

    -- BillboardGui on HumanoidRootPart
    local bb = Instance.new("BillboardGui")
    bb.Name = "AKTag"
    bb.Size = UDim2.new(0, 0, 0, 0)
    bb.StudsOffsetWorldSpace = BB_OFFSET
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.ResetOnSpawn = false
    bb.Parent = hrp

    -- Main tag frame
    local tf = Instance.new("Frame")
    tf.Name = "TagFrame"
    tf.Size = UDim2.new(1, 0, 0, FULL_H)
    tf.BackgroundColor3 = WHITE
    tf.BorderSizePixel = 0
    tf.ClipsDescendants = true
    tf.Parent = bb
    addCorner(10, tf)

    -- Background gradient
    local bgGrad = Instance.new("UIGradient")
    local sweepCol = lerpColor(preset.border, WHITE, 0.35)
    bgGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, preset.gradB),
        ColorSequenceKeypoint.new(0.3, lerpColor(preset.gradB, sweepCol, 0.04)),
        ColorSequenceKeypoint.new(0.5, lerpColor(preset.gradB, sweepCol, 0.38)),
        ColorSequenceKeypoint.new(0.7, lerpColor(preset.gradB, sweepCol, 0.04)),
        ColorSequenceKeypoint.new(1, preset.gradB),
    })
    bgGrad.Rotation = 45
    bgGrad.Offset = Vector2.new(1, 0)
    bgGrad.Parent = tf

    -- Border stroke
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = preset.border
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = tf

    -- Avatar frame (circular)
    local avFrame = Instance.new("Frame")
    avFrame.Size = UDim2.new(0, iconSz, 0, iconSz)
    avFrame.Position = UDim2.new(0, 3, 0.5, -(iconSz / 2))
    avFrame.BackgroundColor3 = preset.bg
    avFrame.BorderSizePixel = 0
    avFrame.ZIndex = 3
    avFrame.Parent = tf
    Instance.new("UICorner", avFrame).CornerRadius = UDim.new(1, 0)

    local avStroke = Instance.new("UIStroke")
    avStroke.Thickness = 1.5
    avStroke.Color = preset.border
    avStroke.Transparency = 0.3
    avStroke.Parent = avFrame

    -- Avatar image (headshot)
    local avImg = Instance.new("ImageLabel")
    avImg.Size = UDim2.new(1, 0, 1, 0)
    avImg.BackgroundTransparency = 1
    avImg.ZIndex = 4
    avImg.Image = string.format(HEADSHOT_URL, player.UserId)
    avImg.Parent = avFrame
    Instance.new("UICorner", avImg).CornerRadius = UDim.new(1, 0)

    -- Name label with gradient
    local nl = Instance.new("TextLabel")
    nl.Size = UDim2.new(1, -(iconEnd + 4), 0, math.floor(FULL_H / 2))
    nl.Position = UDim2.new(0, iconEnd, 0, 0)
    nl.BackgroundTransparency = 1
    nl.Font = Enum.Font.Code
    nl.TextSize = 13
    nl.TextXAlignment = Enum.TextXAlignment.Left
    nl.TextYAlignment = Enum.TextYAlignment.Center
    nl.TextStrokeTransparency = 0.85
    nl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nl.ZIndex = 5
    nl.TextColor3 = preset.namec
    nl.Text = showName
    nl.Parent = tf

    local nlGrad = Instance.new("UIGradient")
    local textMid = lerpColor(preset.namec, WHITE, 0.32)
    nlGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, preset.namec),
        ColorSequenceKeypoint.new(0.44, lerpColor(preset.namec, textMid, 0.5)),
        ColorSequenceKeypoint.new(0.5, textMid),
        ColorSequenceKeypoint.new(0.56, lerpColor(preset.namec, textMid, 0.5)),
        ColorSequenceKeypoint.new(1, preset.namec),
    })
    nlGrad.Rotation = 45
    nlGrad.Offset = Vector2.new(1, 0)
    nlGrad.Parent = nl

    -- Username label
    local ul = Instance.new("TextLabel")
    ul.Size = UDim2.new(1, -(iconEnd + 4), 0, math.floor(FULL_H / 2))
    ul.Position = UDim2.new(0, iconEnd, 0, math.floor(FULL_H / 2))
    ul.BackgroundTransparency = 1
    ul.Font = Enum.Font.Code
    ul.TextSize = 9
    ul.TextXAlignment = Enum.TextXAlignment.Left
    ul.TextYAlignment = Enum.TextYAlignment.Center
    ul.TextStrokeTransparency = 0.7
    ul.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    ul.ZIndex = 5
    ul.TextColor3 = preset.userc
    ul.Text = showUser
    ul.Parent = tf

    local ulGrad = Instance.new("UIGradient")
    local userMid = lerpColor(preset.userc, WHITE, 0.28)
    ulGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, preset.userc),
        ColorSequenceKeypoint.new(0.44, lerpColor(preset.userc, userMid, 0.5)),
        ColorSequenceKeypoint.new(0.5, userMid),
        ColorSequenceKeypoint.new(0.56, lerpColor(preset.userc, userMid, 0.5)),
        ColorSequenceKeypoint.new(1, preset.userc),
    })
    ulGrad.Rotation = 45
    ulGrad.Offset = Vector2.new(1, 0)
    ulGrad.Parent = ul

    -- Sparkle particles
    local stars = {}
    local sparkCount = isOwner and 18 or 12
    for i = 1, sparkCount do
        local ci = math.random(1, #preset.spark)
        local roll = math.random()
        local sym = roll < 0.55 and "\194\183" or roll < 0.85 and "\226\156\166" or "\226\152\133"
        local sz = math.random(9, 14)
        local star = Instance.new("TextLabel")
        star.BackgroundTransparency = 1
        star.Font = Enum.Font.Code
        star.TextSize = sz
        star.TextColor3 = preset.spark[ci]
        star.Text = sym
        star.TextXAlignment = Enum.TextXAlignment.Center
        star.TextYAlignment = Enum.TextYAlignment.Center
        star.Size = UDim2.new(0, sz + 4, 0, sz + 4)
        star.AnchorPoint = Vector2.new(0.5, 0.5)
        star.BorderSizePixel = 0
        star.ZIndex = 2
        star.TextTransparency = 1
        local rx = math.random(5, 95) / 100
        local ry = math.random(10, 90) / 100
        star.Position = UDim2.new(rx, 0, ry, 0)
        star.Parent = tf
        table.insert(stars, {
            L = star, bx = rx, by = ry, baseSize = sz,
            phase = math.random() * math.pi * 2,
            speed = 0.08 + math.random() * 0.18,
            driftX = (math.random() - 0.5) * 0.01,
            alpha = 0, life = math.random() * 2.5,
            maxLife = 1.5 + math.random() * 2.0,
            col = preset.spark[ci],
        })
    end

    -- Shine sweep frame (owners only)
    local shine = nil
    if isOwner then
        shine = Instance.new("Frame")
        shine.Name = "Shine"
        shine.Size = UDim2.new(0, 60, 1.6, 0)
        shine.Position = UDim2.new(-0.45, 0, -0.3, 0)
        shine.BackgroundColor3 = WHITE
        shine.BackgroundTransparency = 1
        shine.BorderSizePixel = 0
        shine.ZIndex = 8
        shine.Rotation = 22
        shine.Parent = bb
        local shGrad = Instance.new("UIGradient")
        shGrad.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.4, 0.38),
            NumberSequenceKeypoint.new(0.6, 0.38),
            NumberSequenceKeypoint.new(1, 1),
        })
        shGrad.Rotation = 90
        shGrad.Parent = shine
    end

    -- Per-frame animation
    local sweepT = math.random()
    local sweepSpeed = 0.18
    local shineTimer = 0
    local nextShine = math.random(4, 8)
    local glitchTimer, glitchOn = 0, false
    local nextGlitch = math.random(3, 6)

    local lerpT = 1
    local hbConn
    hbConn = RunService.Heartbeat:Connect(function(dt)
        if not tf or not tf.Parent then
            if hbConn then hbConn:Disconnect() end
            return
        end

        -- Distance-based scaling
        local myHRP = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
        local dist = myHRP and hrp.Parent and (myHRP.Position - hrp.Position).Magnitude or 0

        local targetT = dist < FULL_DIST and 1 or dist >= SHRINK_START and 0 or
            1 - (dist - FULL_DIST) / (SHRINK_START - FULL_DIST)
        lerpT = lerpN(lerpT, targetT, math.min(1, dt * 10))

        local curW = math.floor(lerpN(MINI_W, baseWidth, lerpT))
        local curH = math.floor(lerpN(MINI_H, FULL_H, lerpT))
        bb.Size = UDim2.new(0, curW, 0, curH)

        -- Show/hide text based on lerp
        nl.TextTransparency = 1 - lerpT
        ul.TextTransparency = 1 - lerpT

        -- Gradient sweep animation
        sweepT = sweepT + dt * sweepSpeed
        if sweepT > 2 then sweepT = sweepT - 2 end
        local offset = sweepT < 1 and (1 - sweepT * 2) or (-1 + (sweepT - 1) * 2)
        bgGrad.Offset = Vector2.new(offset, 0)
        nlGrad.Offset = Vector2.new(offset, 0)
        ulGrad.Offset = Vector2.new(offset, 0)

        -- Sparkle animation
        for _, s in ipairs(stars) do
            s.life = s.life + dt
            if s.life > s.maxLife then
                s.life = 0
                s.bx = math.random(5, 95) / 100
                s.by = math.random(10, 90) / 100
                s.alpha = 0
            end
            local frac = s.life / s.maxLife
            local a = frac < 0.2 and (frac / 0.2) or frac > 0.7 and (1 - (frac - 0.7) / 0.3) or 1
            s.alpha = a * lerpT
            s.L.TextTransparency = 1 - s.alpha * 0.6
            s.bx = s.bx + s.driftX * dt
            s.by = s.by - s.speed * dt
            if s.by < -0.1 then s.by = 1.1; s.bx = math.random(5, 95) / 100 end
            s.L.Position = UDim2.new(s.bx, 0, s.by, 0)
        end

        -- Shine (owner only)
        if shine then
            shineTimer = shineTimer + dt
            if shineTimer >= nextShine then
                shineTimer = 0
                nextShine = math.random(4, 8)
                shine.Position = UDim2.new(-0.45, 0, -0.3, 0)
                TweenService:Create(shine, TweenInfo.new(0.7, Enum.EasingStyle.Quad), {
                    Position = UDim2.new(1.45, 0, -0.3, 0)
                }):Play()
            end
        end

        -- Glitch (owner only)
        if isOwner then
            glitchTimer = glitchTimer + dt
            if glitchOn then
                if glitchTimer > 0.08 then
                    glitchOn = false
                    glitchTimer = 0
                    nextGlitch = math.random(3, 6)
                    nl.TextColor3 = preset.namec
                    stroke.Color = preset.border
                end
            else
                if glitchTimer > nextGlitch then
                    glitchOn = true
                    glitchTimer = 0
                    nl.TextColor3 = preset.borderB
                    stroke.Color = preset.borderB
                end
            end
        end
    end)

    activeTags[userId] = { bb = bb, hbConn = hbConn, stars = stars, presetIdx = nil }
    return bb
end

local function removeTag()
    cleanupTag(localPlayer.UserId)
    currentTagPreset = nil
    pcall(function()
        local char = localPlayer.Character
        if char then char:SetAttribute(AK_TAG_ATTR, 0) end
    end)
end

local function applyTag(preset)
    removeTag()
    local char = localPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    buildTag(hrp, localPlayer, preset)
    currentTagPreset = preset

    local tagIndex = 0
    for i, p in ipairs(TAG_PRESETS) do
        if p.name == preset.name then tagIndex = i; break end
    end
    pcall(function() char:SetAttribute(AK_TAG_ATTR, tagIndex) end)
    -- Store for respawn
    if activeTags[localPlayer.UserId] then
        activeTags[localPlayer.UserId].presetIdx = tagIndex
    end
end

-- Apply remote player's tag
local function applyRemoteTag(player, presetIndex)
    cleanupTag(player.UserId)
    if presetIndex == 0 or not presetIndex then return end
    local preset = TAG_PRESETS[presetIndex]
    if not preset then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    buildTag(hrp, player, preset)
    if activeTags[player.UserId] then
        activeTags[player.UserId].presetIdx = presetIndex
    end
end

-- Cross-client detection: watch for attribute + animation signal
local function watchPlayer(player)
    if player == localPlayer then return end

    local function onChar(char)
        task.wait(0.3)
        -- Check attribute
        local idx = char:GetAttribute(AK_TAG_ATTR)
        if idx and idx > 0 then
            applyRemoteTag(player, idx)
        end
        char:GetAttributeChangedSignal(AK_TAG_ATTR):Connect(function()
            applyRemoteTag(player, char:GetAttribute(AK_TAG_ATTR) or 0)
        end)

        -- (animation signal removed — attribute-only cross-client detection)
    end

    if player.Character then task.spawn(onChar, player.Character) end
    player.CharacterAdded:Connect(function(c) task.spawn(onChar, c) end)
end

for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
Players.PlayerAdded:Connect(watchPlayer)

-- Own respawn
localPlayer.CharacterAdded:Connect(function(char)
    if currentTagPreset then
        local saved = currentTagPreset
        task.wait(0.5)
        local hrp = char:WaitForChild("HumanoidRootPart", 5)
        if hrp then
            buildTag(hrp, localPlayer, saved)
            currentTagPreset = saved
            local idx = 0
            for i, p in ipairs(TAG_PRESETS) do
                if p.name == saved.name then idx = i; break end
            end
            pcall(function() char:SetAttribute(AK_TAG_ATTR, idx) end)
            if activeTags[localPlayer.UserId] then
                activeTags[localPlayer.UserId].presetIdx = idx
            end
        end
    end
    -- (animation signal disabled — uses attribute-only detection)
end)

-- Remote tag respawn
Players.PlayerRemoving:Connect(function(player)
    cleanupTag(player.UserId)
    if shared.AKAdminUsers then shared.AKAdminUsers[player.UserId] = nil end
end)

-- (animation signal removed — attribute-only cross-client detection)

------------------------------------------------------------
-- TAG SELECTOR DROPDOWN (opens from bird icon)
------------------------------------------------------------
local tagDropdown = createElement("Frame", {
    Name = "TagDropdown",
    Size = UDim2.new(0, 160, 0, 0),
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 1, 4),
    BackgroundColor3 = Theme.bg,
    BackgroundTransparency = 0.1,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Visible = false,
    ZIndex = 20,
    Parent = tagSelectorBtn,
})
addCorner(8, tagDropdown)
addStroke(Theme.border, 0.3, tagDropdown)

local tagListLayout = addListLayout(
    Enum.FillDirection.Vertical,
    Enum.HorizontalAlignment.Center,
    nil,
    3,
    tagDropdown
)
addPadding(4, 4, 4, 4, tagDropdown)

local tagDropOpen = false
local TAG_ENTRY_H = 30
local TAG_DROP_H = (#TAG_PRESETS + 1) * (TAG_ENTRY_H + 3) + 8

-- Build tag preset entries
for i, preset in ipairs(TAG_PRESETS) do
    local tagEntry = createElement("TextButton", {
        Name = preset.name,
        Size = UDim2.new(1, 0, 0, TAG_ENTRY_H),
        BackgroundColor3 = preset.color,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = i,
        ZIndex = 21,
        Parent = tagDropdown,
    })
    addCorner(6, tagEntry)

    createElement("ImageLabel", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new(0, 6, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Image = preset.icon,
        ImageColor3 = Theme.white,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 22,
        Parent = tagEntry,
    })

    createElement("TextLabel", {
        Size = UDim2.new(1, -26, 1, 0),
        Position = UDim2.new(0, 24, 0, 0),
        BackgroundTransparency = 1,
        Text = preset.name,
        TextColor3 = Theme.white,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 22,
        Parent = tagEntry,
    })

    tagEntry.MouseEnter:Connect(function()
        playTween(tagEntry, Tweens.fast, { BackgroundTransparency = 0.2 })
    end)
    tagEntry.MouseLeave:Connect(function()
        playTween(tagEntry, Tweens.fast, { BackgroundTransparency = 0.4 })
    end)
    tagEntry.MouseButton1Click:Connect(function()
        playSfx(sfxClick)
        applyTag(preset)
        showNotification("AK ADMIN", "Tag set: " .. preset.name, 2)
        -- close dropdown
        tagDropOpen = false
        playTween(tagDropdown, Tweens.slide, { Size = UDim2.new(0, 160, 0, 0) })
        task.delay(0.25, function() tagDropdown.Visible = false end)
    end)
end

-- "Remove Tag" entry
local removeEntry = createElement("TextButton", {
    Name = "RemoveTag",
    Size = UDim2.new(1, 0, 0, TAG_ENTRY_H),
    BackgroundColor3 = Theme.red,
    BackgroundTransparency = 0.5,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    LayoutOrder = #TAG_PRESETS + 1,
    ZIndex = 21,
    Parent = tagDropdown,
})
addCorner(6, removeEntry)
createElement("TextLabel", {
    Size = UDim2.new(1, -8, 1, 0),
    Position = UDim2.new(0, 8, 0, 0),
    BackgroundTransparency = 1,
    Text = "Remove Tag",
    TextColor3 = Theme.white,
    TextSize = 12,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 22,
    Parent = removeEntry,
})
removeEntry.MouseEnter:Connect(function()
    playTween(removeEntry, Tweens.fast, { BackgroundTransparency = 0.3 })
end)
removeEntry.MouseLeave:Connect(function()
    playTween(removeEntry, Tweens.fast, { BackgroundTransparency = 0.5 })
end)
removeEntry.MouseButton1Click:Connect(function()
    playSfx(sfxClick)
    removeTag()
    showNotification("AK ADMIN", "Tag removed", 2)
    tagDropOpen = false
    playTween(tagDropdown, Tweens.slide, { Size = UDim2.new(0, 160, 0, 0) })
    task.delay(0.25, function() tagDropdown.Visible = false end)
end)

-- Toggle dropdown on bird icon click
tagSelectorBtn.MouseButton1Click:Connect(function()
    playSfx(sfxClick)
    tagDropOpen = not tagDropOpen
    if tagDropOpen then
        tagDropdown.Visible = true
        playTween(tagDropdown, Tweens.slide, { Size = UDim2.new(0, 160, 0, TAG_DROP_H) })
    else
        playTween(tagDropdown, Tweens.slide, { Size = UDim2.new(0, 160, 0, 0) })
        task.delay(0.25, function() tagDropdown.Visible = false end)
    end
end)

------------------------------------------------------------
-- DRAGGING
------------------------------------------------------------
do
    local isDragging = false
    local dragStart = nil
    local startPos = nil

    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            dragStart = input.Position
            startPos = mainFrame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    isDragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

------------------------------------------------------------
-- MINIMIZE / CLOSE
------------------------------------------------------------
local isMinimized = false

minimizeBtn.MouseButton1Click:Connect(function()
    playSfx(sfxClick)
    isMinimized = not isMinimized
    if isMinimized then
        searchContainer.Visible = false
        cmdScroll.Visible = false
        cmdInputBar.Visible = false
        playTween(mainFrame, Tweens.slide, {
            Size = UDim2.new(0, WIN_W, 0, TITLE_H + 4),
        })
        minimizeBtn.Text = "+"
    else
        playTween(mainFrame, Tweens.slide, {
            Size = UDim2.new(0, WIN_W, 0, WIN_H),
        })
        task.delay(0.15, function()
            searchContainer.Visible = true
            cmdScroll.Visible = true
            cmdInputBar.Visible = true
        end)
        minimizeBtn.Text = "-"
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    playSfx(sfxClick)
    windowVisible = false
    mainFrame.Visible = false
end)

------------------------------------------------------------
-- F6 KEYBIND (toggle window)
------------------------------------------------------------
local TOGGLE_KEY = Enum.KeyCode.F6

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == TOGGLE_KEY then
        windowVisible = not windowVisible
        mainFrame.Visible = windowVisible
        if windowVisible and isMinimized then
            isMinimized = false
            mainFrame.Size = UDim2.new(0, WIN_W, 0, WIN_H)
            minimizeBtn.Text = "-"
        end
    end
end)

------------------------------------------------------------
-- SEARCH FILTERING
------------------------------------------------------------
searchInput:GetPropertyChangedSignal("Text"):Connect(function()
    local query = string.lower(searchInput.Text)
    local catHasVisible = {}

    -- First pass: show/hide command entries
    for _, child in ipairs(cmdScroll:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "" then
            local n = child.Name
            if string.sub(n, 1, 4) ~= "CAT_" then
                if query == "" then
                    child.Visible = true
                    local cat = _G._AK_CMD_CATS and _G._AK_CMD_CATS[n]
                    if cat then catHasVisible["CAT_" .. cat] = true end
                else
                    local vis = string.find(string.lower(n), query, 1, true) ~= nil
                    child.Visible = vis
                    if vis then
                        local cat = _G._AK_CMD_CATS and _G._AK_CMD_CATS[n]
                        if cat then catHasVisible["CAT_" .. cat] = true end
                    end
                end
            end
        end
    end

    -- Second pass: show/hide category headers
    for _, child in ipairs(cmdScroll:GetChildren()) do
        if child:IsA("Frame") and string.sub(child.Name, 1, 4) == "CAT_" then
            child.Visible = (query == "") or (catHasVisible[child.Name] == true)
        end
    end
end)

------------------------------------------------------------
-- NOTIFICATION SYSTEM
------------------------------------------------------------
local notifYOffset = 0

local function showNotification(title, body, duration)
    duration = duration or 4

    local playerGui = localPlayer:WaitForChild("PlayerGui")

    local notifGui = playerGui:FindFirstChild("AKAdminNotificationGui")
    if not notifGui then
        notifGui = createElement("ScreenGui", {
            Name = "AKAdminNotificationGui",
            ResetOnSpawn = false,
            Parent = playerGui,
        })
    end

    local yPos = notifYOffset
    notifYOffset = notifYOffset + 70

    local notifFrame = createElement("Frame", {
        Name = "Notification",
        Size = UDim2.new(0, 320, 0, 60),
        Position = UDim2.new(1, 10, 0, yPos),
        BackgroundColor3 = Theme.bgDark,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        ZIndex = 100,
        Parent = notifGui,
    })
    addCorner(12, notifFrame)
    addStroke(Theme.border, 0.3, notifFrame)

    -- Avatar image
    local avatarImg = createElement("ImageLabel", {
        Name = "Avatar",
        Size = UDim2.new(0, 44, 0, 44),
        Position = UDim2.new(0, 8, 0, 8),
        BackgroundColor3 = Theme.surface,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        ImageTransparency = 0,
        ScaleType = Enum.ScaleType.Crop,
        ZIndex = 101,
        Parent = notifFrame,
    })
    addCorner(22, avatarImg)

    pcall(function()
        avatarImg.Image = string.format(HEADSHOT_URL, localPlayer.UserId)
    end)

    -- Title
    createElement("TextLabel", {
        Size = UDim2.new(1, -64, 0, 20),
        Position = UDim2.new(0, 60, 0, 8),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.accent,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 101,
        Parent = notifFrame,
    })

    -- Body
    createElement("TextLabel", {
        Size = UDim2.new(1, -64, 0, 20),
        Position = UDim2.new(0, 60, 0, 28),
        BackgroundTransparency = 1,
        Text = body,
        TextColor3 = Theme.txtSub,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 101,
        Parent = notifFrame,
    })

    -- Slide in
    local slideIn = playTween(notifFrame, Tweens.notifIn, {
        Position = UDim2.new(1, -330, 0, yPos),
    })

    -- Auto dismiss
    task.delay(duration, function()
        local slideOut = playTween(notifFrame, Tweens.notifOut, {
            Position = UDim2.new(1, 10, 0, yPos),
        })
        slideOut.Completed:Connect(function()
            notifFrame:Destroy()
            notifYOffset = math.max(0, notifYOffset - 70)
        end)
    end)
end

------------------------------------------------------------
-- COMMAND CATEGORY SYSTEM (PxTag-style organized layout)
------------------------------------------------------------
local CAT_COLORS = {
    Teleport   = Color3.fromRGB(80, 220, 120),
    Combat     = Color3.fromRGB(220, 70, 70),
    Movement   = Color3.fromRGB(80, 160, 255),
    Character  = Color3.fromRGB(180, 100, 255),
    Animation  = Color3.fromRGB(255, 180, 50),
    Social     = Color3.fromRGB(255, 100, 180),
    Protection = Color3.fromRGB(50, 200, 200),
    Utility    = Color3.fromRGB(220, 185, 50),
    Server     = Color3.fromRGB(160, 160, 175),
    Other      = Color3.fromRGB(120, 140, 170),
}

local CAT_ORDER = {
    "Teleport", "Combat", "Movement", "Character",
    "Animation", "Social", "Protection", "Utility", "Server", "Other",
}

local CMD_CATEGORIES = {
    bring = "Teleport", call = "Teleport", gokutp = "Teleport",
    ftap = "Teleport", ftp = "Teleport", tprj = "Teleport", colbring = "Teleport",

    fling = "Combat", touchfling = "Combat", uafling = "Combat",
    dropkick = "Combat", trip = "Combat", flip = "Combat", ball = "Combat",
    domainexpansion = "Combat", aimlock = "Combat", swordreach = "Combat",

    stalk = "Movement", speed = "Movement", sfly = "Movement",
    walkonair = "Movement", reverse = "Movement",

    re = "Character", voidre = "Character", invis = "Character",
    reanim = "Character", changetor15 = "Character", changetor6 = "Character",

    animcopy = "Animation", animlogger = "Animation", animrecorder = "Animation",
    caranimations = "Animation", emotes = "Animation", ugcemotes = "Animation",

    hug = "Social", jerk = "Social", kidnap = "Social",
    limborbit = "Social", facebang = "Social", facebangweld = "Social",

    antiafk = "Protection", antifling = "Protection", antisit = "Protection",
    antislide = "Protection", antivcban = "Protection", antivoid = "Protection",
    antiall = "Protection", antiaim = "Protection", antikidnap = "Protection",

    admincheck = "Utility", chatlogs = "Utility", chatcolorchanger = "Utility",
    rizzlines = "Utility", spotify = "Utility", skymaster = "Utility",
    shaders = "Utility", pinghop = "Utility", positionsaver = "Utility",
    mobileshiftlock = "Utility", infbaseplate = "Utility", autoclick = "Utility",
    esp = "Utility", godmode = "Utility",

    naturaldisastergodmode = "Server", aitools = "Server", ad = "Server",
    shlowest = "Server", shmost = "Server", ownercmdbar = "Server", iy = "Server",
}

-- Expose for search filter
_G._AK_CMD_CATS = CMD_CATEGORIES

local catLayoutOrder = 0

------------------------------------------------------------
-- CATEGORY HEADER BUILDER
------------------------------------------------------------
local function buildCatHeader(title, accentColor)
    catLayoutOrder = catLayoutOrder + 1
    local header = createElement("Frame", {
        Name = "CAT_" .. title,
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundColor3 = accentColor,
        BackgroundTransparency = 0.88,
        BorderSizePixel = 0,
        LayoutOrder = catLayoutOrder,
        Parent = cmdScroll,
    })
    addCorner(5, header)

    -- Accent bar on left
    local bar = createElement("Frame", {
        Size = UDim2.new(0, 3, 0, 14),
        Position = UDim2.new(0, 4, 0.5, -7),
        BackgroundColor3 = accentColor,
        BorderSizePixel = 0,
        Parent = header,
    })
    addCorner(2, bar)

    createElement("TextLabel", {
        Size = UDim2.new(1, -18, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = string.upper(title),
        TextColor3 = accentColor,
        TextSize = 10,
        Font = Enum.Font.Code,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header,
    })

    return header
end

------------------------------------------------------------
-- COMMAND ENTRY BUILDER (PxTag-style rows)
------------------------------------------------------------
local function buildCmdEntry(name, description, accentColor)
    catLayoutOrder = catLayoutOrder + 1
    accentColor = accentColor or Theme.accent

    -- Parse desc format: "cmdname [args] - description text"
    local cmdSyntax = "!" .. name
    local cleanDesc = description or ""
    if description and description ~= "" then
        local before, after = description:match("^(.-)%s*%-%s*(.+)$")
        if before and after then
            local args = before:match("^%S+%s+(.+)$")
            if args then
                cmdSyntax = "!" .. name .. " " .. args
            end
            cleanDesc = after
        end
    end

    local hasDesc = cleanDesc ~= ""
    local entryH = hasDesc and 36 or 28

    local entry = createElement("Frame", {
        Name = name,
        Size = UDim2.new(1, 0, 0, entryH),
        BackgroundColor3 = Theme.bgDark,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        LayoutOrder = catLayoutOrder,
        ClipsDescendants = true,
        Parent = cmdScroll,
    })
    addCorner(5, entry)

    -- Left accent bar
    local accentBar = createElement("Frame", {
        Name = "Accent",
        Size = UDim2.new(0, 3, 1, -8),
        Position = UDim2.new(0, 0, 0, 4),
        BackgroundColor3 = accentColor,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        Parent = entry,
    })
    addCorner(2, accentBar)

    -- Command syntax in Code font
    createElement("TextLabel", {
        Size = UDim2.new(1, -16, 0, 15),
        Position = UDim2.new(0, 10, 0, hasDesc and 3 or 6),
        BackgroundTransparency = 1,
        Text = cmdSyntax,
        TextColor3 = Theme.txt,
        TextSize = 12,
        Font = Enum.Font.Code,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = entry,
    })

    -- Description
    if hasDesc then
        createElement("TextLabel", {
            Size = UDim2.new(1, -16, 0, 13),
            Position = UDim2.new(0, 10, 0, 19),
            BackgroundTransparency = 1,
            Text = cleanDesc,
            TextColor3 = Theme.txtFaint,
            TextSize = 10,
            Font = Enum.Font.Code,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = entry,
        })
    end

    -- Hover effect
    entry.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            playTween(entry, Tweens.fast, { BackgroundTransparency = 0.05 })
            playTween(accentBar, Tweens.fast, { BackgroundTransparency = 0 })
        end
    end)
    entry.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            playTween(entry, Tweens.fast, { BackgroundTransparency = 0.2 })
            playTween(accentBar, Tweens.fast, { BackgroundTransparency = 0.4 })
        end
    end)

    -- Click to execute or fill input bar
    local clickBtn = createElement("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 3,
        Parent = entry,
    })
    clickBtn.MouseButton1Click:Connect(function()
        playSfx(sfxClick)
        local cmdFunc = commands[name] or commands["!" .. name]
        if cmdFunc then
            local ok, err = pcall(cmdFunc, {}, "")
            if ok then
                showNotification("AK ADMIN", "Executed: !" .. name, 2)
            else
                showNotification("Error", "!" .. name .. " failed: " .. tostring(err), 3)
            end
        else
            cmdInput.Text = "!" .. name .. " "
            cmdInput:CaptureFocus()
        end
    end)

    return entry
end

------------------------------------------------------------
-- COMMAND EXECUTION (via chat or F6 command bar)
------------------------------------------------------------
local function executeCommand(text)
    if text == "" then return end

    text = text:match("^%s*(.-)%s*$") or text

    local parts = {}
    for word in text:gmatch("%S+") do
        table.insert(parts, word)
    end
    if #parts == 0 then return end

    local rawCmd = parts[1]
    local cmdName = rawCmd:lower()

    -- Try with and without "!" prefix
    local cmdFunc = commands[cmdName]
        or commands["!" .. cmdName]
        or commands[rawCmd]
        or commands["!" .. rawCmd]
    if not cmdFunc then
        showNotification("AK ADMIN", "Unknown command: " .. cmdName, 3)
        return
    end

    local args = {}
    for i = 2, #parts do
        table.insert(args, parts[i])
    end

    local ok, err = pcall(cmdFunc, args, table.concat(args, " "))
    if not ok then
        warn("[AK Admin] COMMAND ERROR: " .. cmdName .. " - " .. tostring(err))
        showNotification("Error", "Command failed: " .. cmdName, 3)
        return false
    end
    return true
end

------------------------------------------------------------
-- COMMAND INPUT BAR HANDLER
------------------------------------------------------------
cmdInput.FocusLost:Connect(function(enterPressed)
    if enterPressed and cmdInput.Text ~= "" then
        local text = cmdInput.Text
        cmdInput.Text = ""
        playSfx(sfxOk)
        executeCommand(text)
    end
end)

------------------------------------------------------------
-- CHAT COMMAND HOOK (! prefix in chat)
------------------------------------------------------------
pcall(function()
    local textChatService = getService("TextChatService")
    local channels = textChatService:WaitForChild("TextChannels", 10)
    if channels then
        local general = channels:FindFirstChild("RBXGeneral")
        if general then
            general:ConnectLocal(function(msg)
                if msg and msg.Text then
                    local text = msg.Text
                    if text:sub(1, 1) == "!" then
                        executeCommand(text)
                    end
                end
            end)
        end
    end
end)

------------------------------------------------------------
-- AUTH BYPASS / PLACEHOLDER
------------------------------------------------------------
-- The original AK Admin checks Key.json and whitelist.json
-- User will add their own auth system later.
-- For now, proceed directly to loading commands.

------------------------------------------------------------
-- LOAD COMMANDS FROM REMOTE
------------------------------------------------------------
task.spawn(function()
    -- Gather workspace info (original passes these to cmds.lua)
    local rawDescendants = workspace:GetDescendants()
    local serverTime = 0
    pcall(function()
        serverTime = math.floor(workspace:GetServerTimeNow())
    end)
    if serverTime == 0 then
        serverTime = math.floor(tick())
    end

    -- The original loader's VM environment had custom concat handling.
    local descendants = setmetatable({}, {
        __concat = function(a, b)
            if type(a) == "table" then
                return tostring(#rawDescendants) .. tostring(b)
            else
                return tostring(a) .. tostring(#rawDescendants)
            end
        end,
        __len = function()
            return #rawDescendants
        end,
        __index = rawDescendants,
        __tostring = function()
            return tostring(#rawDescendants)
        end,
    })
    for i, v in ipairs(rawDescendants) do
        descendants[i] = v
    end

    -- Polynomial rolling hash (replicates original exactly)
    local function computeHash(str)
        local h = 0
        for i = 1, #str do
            h = (h * 31 + string.byte(str, i)) % 1242112432421243
        end
        return h
    end

    local hashStr = tostring(#rawDescendants) .. ":" .. tostring(serverTime) .. ":0"
    local hash = computeHash(hashStr)

    -- Register commands into UI + command table (categorized PxTag-style)
    local function registerCmds(result)
        if type(result) ~= "table" then return 0 end

        local count = 0
        local categorized = {}
        for _, cat in ipairs(CAT_ORDER) do categorized[cat] = {} end

        -- First pass: register all commands and sort into categories
        for name, handler in pairs(result) do
            local cmdKey = "!" .. name
            local fn, desc
            if type(handler) == "function" then
                fn = handler; desc = ""
            elseif type(handler) == "table" and handler.fn then
                fn = handler.fn; desc = handler.desc or ""
            end
            if fn then
                commands[cmdKey] = fn
                commands[name] = fn
                local cat = CMD_CATEGORIES[name] or "Other"
                if not categorized[cat] then categorized[cat] = {} end
                table.insert(categorized[cat], { name = name, desc = desc })
                count = count + 1
            end
        end

        -- Sort each category alphabetically
        for _, cat in ipairs(CAT_ORDER) do
            if categorized[cat] then
                table.sort(categorized[cat], function(a, b) return a.name < b.name end)
            end
        end

        -- Second pass: build categorized UI
        catLayoutOrder = 0
        for _, cat in ipairs(CAT_ORDER) do
            local entries = categorized[cat]
            if entries and #entries > 0 then
                buildCatHeader(cat, CAT_COLORS[cat])
                for _, e in ipairs(entries) do
                    buildCmdEntry(e.name, e.desc, CAT_COLORS[cat])
                end
            end
        end

        return count
    end

    local cmdsLoaded = false

    -- Try remote cmds.lua from GitHub first
    if not cmdsLoaded then
        local ok, result = pcall(function()
            local source = game:HttpGet(CMDS_URL)
            if not source or source == "" then
                error("Failed to download cmds.lua")
            end
            local cmdsFunc, loadErr = loadstring(source)
            if not cmdsFunc then
                error("Failed to parse cmds.lua: " .. tostring(loadErr))
            end
            return cmdsFunc(descendants, serverTime, hash)
        end)

        if ok and result then
            local count = registerCmds(result)
            if count > 0 then
                cmdsLoaded = true
                commandCount = count
                searchInput.PlaceholderText = "Search Commands (" .. count .. ")"
                showNotification("AK ADMIN", count .. " commands loaded", 3)
            elseif type(result) == "function" then
                local fnResult = result(descendants, serverTime, hash)
                count = registerCmds(fnResult)
                if count > 0 then
                    cmdsLoaded = true
                    commandCount = count
                    searchInput.PlaceholderText = "Search Commands (" .. count .. ")"
                end
            end
        else
            warn("[AK Admin] Remote load failed: " .. tostring(result))
        end
    end

    -- Fallback: try local file
    if not cmdsLoaded then
        pcall(function()
            if readfile then
                local localSource = readfile("AKAdmin_cmds.lua")
                if localSource and localSource ~= "" then
                    local fn = loadstring(localSource)
                    if fn then
                        local localResult = fn(descendants, serverTime, hash)
                        local count = registerCmds(localResult)
                        if count > 0 then
                            cmdsLoaded = true
                            commandCount = count
                            searchInput.PlaceholderText = "Search Commands (" .. count .. ")"
                            showNotification("AK ADMIN", count .. " commands loaded (local)", 3)
                            print("[AK Admin] Loaded " .. count .. " commands from local AKAdmin_cmds.lua")
                        end
                    end
                end
            end
        end)
    end

    if not cmdsLoaded then
        warn("[AK Admin] Failed to load commands from any source")
        showNotification("AK ADMIN", "No commands loaded. Check console.", 5)
    end

    -- Inline baseplate extend prompt (replaces remote ib2.dev version)
    pcall(function()
        if _G.bp then return end
        _G.bp = true

        local bpGui = createElement("ScreenGui", {
            Name = "BaseplatePrompt",
            ResetOnSpawn = false,
            IgnoreGuiInset = true,
            Parent = CoreGui,
        })

        local bpFrame = createElement("Frame", {
            Size = UDim2.new(0, 320, 0, 90),
            Position = UDim2.new(0, 20, 1, 20),
            BackgroundColor3 = Theme.bg,
            BackgroundTransparency = 0.15,
            BorderSizePixel = 0,
            Parent = bpGui,
        })
        addCorner(12, bpFrame)
        addStroke(Theme.border, 0.3, bpFrame)

        createElement("TextLabel", {
            Size = UDim2.new(1, -10, 0, 18),
            Position = UDim2.new(0, 5, 0, 5),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            TextColor3 = Theme.txtFaint,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "AK ADMIN",
            Parent = bpFrame,
        })

        createElement("TextLabel", {
            Size = UDim2.new(1, -20, 0, 30),
            Position = UDim2.new(0, 10, 0, 25),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = Theme.txt,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            Text = "Would you like to extend the baseplate?",
            Parent = bpFrame,
        })

        local btnContainer = createElement("Frame", {
            Size = UDim2.new(1, -20, 0, 22),
            Position = UDim2.new(0, 10, 1, -30),
            BackgroundTransparency = 1,
            Parent = bpFrame,
        })
        addListLayout(Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center, 8, btnContainer)

        -- Yes button FIRST (left side)
        local yesBtn = createElement("TextButton", {
            Size = UDim2.new(0, 60, 0, 22),
            BackgroundColor3 = Theme.green,
            BackgroundTransparency = 0.3,
            BorderSizePixel = 0,
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextColor3 = Theme.white,
            Text = "Yes",
            AutoButtonColor = false,
            LayoutOrder = 1,
            Parent = btnContainer,
        })
        addCorner(6, yesBtn)

        -- No button SECOND (right side)
        local noBtn = createElement("TextButton", {
            Size = UDim2.new(0, 60, 0, 22),
            BackgroundColor3 = Theme.bgDark,
            BackgroundTransparency = 0.3,
            BorderSizePixel = 0,
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextColor3 = Theme.txt,
            Text = "No",
            AutoButtonColor = false,
            LayoutOrder = 2,
            Parent = btnContainer,
        })
        addCorner(6, noBtn)

        -- Slide in
        playTween(bpFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 20, 1, -110),
        })

        local function closeBp()
            local out = playTween(bpFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Position = UDim2.new(0, 20, 1, 20),
            })
            out.Completed:Wait()
            bpGui:Destroy()
        end

        yesBtn.MouseButton1Click:Connect(function()
            for _, d in ipairs(workspace:GetDescendants()) do
                if d.Name == "Baseplate" and d:IsA("BasePart") then
                    local y = d.Size.Y
                    local bg = math.max(d.Size.X, d.Size.Z)
                    d.Size = Vector3.new(math.max(bg * 4, 2048), y, math.max(bg * 4, 2048))
                    break
                end
            end
            closeBp()
        end)

        noBtn.MouseButton1Click:Connect(function()
            closeBp()
        end)
    end)
end)

------------------------------------------------------------
-- WELCOME NOTIFICATION
------------------------------------------------------------
task.delay(1, function()
    showNotification(
        "AK ADMIN",
        "@" .. localPlayer.Name .. " Executed AK ADMIN",
        5
    )
end)

------------------------------------------------------------
-- CONFIG PERSISTENCE (if executor supports file system)
------------------------------------------------------------
pcall(function()
    if writefile and readfile and isfolder and makefolder then
        if not isfolder("AKAdmin") then
            makefolder("AKAdmin")
        end
    end
end)

------------------------------------------------------------
-- CLEANUP ON PLAYER LEAVING
------------------------------------------------------------
Players.PlayerRemoving:Connect(function(plr)
    if plr == localPlayer then
        pcall(function()
            if screenGui then screenGui:Destroy() end
        end)
    end
end)

print("[AK Admin] Loaded successfully. Press F6 to toggle the command window.")
print("[AK Admin] Use !command in chat or F6 command window.")
print("[AK Admin] Discord: " .. DISCORD_URL)
