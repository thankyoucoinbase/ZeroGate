--[[
    AK Admin - Clean Reconstruction
    Original: https://absent.wtf/AKADMIN.lua
    Discord: https://discord.gg/akadmin

    Reconstructed from deobfuscated bytecode analysis.
    Auth/whitelist is bypassed (placeholder for user to add later).
    Commands loaded from original remote URL.
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
        qot('loadstring(game:HttpGet("https://absent.wtf/AKADMIN.lua"))()')
    end
end)

------------------------------------------------------------
-- THEME
------------------------------------------------------------
local Theme = {
    black     = Color3.fromRGB(0, 0, 0),
    bg        = Color3.fromRGB(6, 6, 8),
    panel     = Color3.fromRGB(10, 10, 13),
    surface   = Color3.fromRGB(16, 16, 20),
    line      = Color3.fromRGB(30, 30, 38),
    btn       = Color3.fromRGB(20, 20, 26),
    btnHov    = Color3.fromRGB(30, 30, 38),
    accent    = Color3.fromRGB(255, 255, 255),
    accentDim = Color3.fromRGB(140, 140, 155),
    txt       = Color3.fromRGB(230, 230, 235),
    txtSub    = Color3.fromRGB(120, 120, 130),
    txtFaint  = Color3.fromRGB(55, 55, 65),
    green     = Color3.fromRGB(80, 220, 120),
    red       = Color3.fromRGB(220, 70, 70),
    yellow    = Color3.fromRGB(220, 185, 50),
    white     = Color3.fromRGB(255, 255, 255),
    -- transparencies
    bgT       = 0,
    panelT    = 0,
    surfaceT  = 0.15,
    lineT     = 0,
}

------------------------------------------------------------
-- EXECUTOR ACCENT COLOR (per-executor branding)
------------------------------------------------------------
local executorAccent = Theme.green
do
    local ok, execName = pcall(function()
        if identifyexecutor then return identifyexecutor() end
        return nil
    end)
    if ok and execName then
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
        }
        for name, color in pairs(brandColors) do
            if string.find(execName, name, 1, true) then
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
    cbSlide = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    intro   = TweenInfo.new(1.1,  Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
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

local function addStroke(color, transparency, parent)
    return createElement("UIStroke", {
        Color = color,
        Transparency = transparency,
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
-- LAYOUT CONSTANTS
------------------------------------------------------------
local BAR_H    = 32
local BTN_W    = 56
local BTN_H    = 10
local CORNER_R = 8
local CORNER_S = 6
local CORNER_XS = 4
local PAD      = 6

-- Category tab icons and names
local TABS = {
    { icon = "rbxassetid://132440478962916", name = "cmds",  order = 1 },
    { icon = "rbxassetid://73577105416536",  name = "bar",   order = 2 },
    { icon = "rbxassetid://99892550804409",  name = "tags",  order = 3 },
    { icon = "rbxassetid://84437305519060",  name = "join",  order = 4 },
    { icon = "rbxassetid://101119408272746", name = "auto",  order = 5 },
}

------------------------------------------------------------
-- MAIN SCREEN GUI
------------------------------------------------------------
local screenGui = createElement("ScreenGui", {
    Name = "AKAdminGui",
    ResetOnSpawn = false,
    DisplayOrder = 52,
    IgnoreGuiInset = true,
    Parent = CoreGui,
})

------------------------------------------------------------
-- STATE
------------------------------------------------------------
local commands = {}
local isBarOpen = false
local currentTab = "cmds"
local cmdBarFocused = false

------------------------------------------------------------
-- MAIN PANEL
------------------------------------------------------------
local panelWidth = 350
local panelHeight = BAR_H

local mainPanel = createElement("Frame", {
    Name = "MainPanel",
    Size = UDim2.new(0, panelWidth, 0, panelHeight),
    Position = UDim2.new(1, -(panelWidth + 8), 1, -(BAR_H + 8)),
    BackgroundColor3 = Theme.panel,
    BackgroundTransparency = Theme.panelT,
    BorderSizePixel = 0,
    ZIndex = 5,
    Parent = screenGui,
})
addCorner(CORNER_R, mainPanel)
addStroke(Theme.line, 0, mainPanel)

------------------------------------------------------------
-- STARTER GUI (intro white flash overlay)
------------------------------------------------------------
local starterOverlay = createElement("Frame", {
    Name = "StarterOverlay",
    Size = UDim2.new(0, 0, 1, 0),
    BackgroundColor3 = Theme.white,
    BackgroundTransparency = 0.85,
    BorderSizePixel = 0,
    ZIndex = 10,
    Parent = mainPanel,
})
addCorner(CORNER_R, starterOverlay)

-- Intro animation: expand overlay then fade out
local introTween = playTween(starterOverlay, Tweens.intro, {
    Size = UDim2.new(1, 0, 1, 0),
})
introTween.Completed:Connect(function()
    playTween(starterOverlay, Tweens.med, {
        BackgroundTransparency = 1,
    }).Completed:Connect(function()
        starterOverlay:Destroy()
    end)
end)

------------------------------------------------------------
-- COMMAND BAR LABEL (text at top)
------------------------------------------------------------
local barLabel = createElement("TextLabel", {
    Name = "BarLabel",
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "AK ADMIN",
    TextColor3 = Theme.txtSub,
    TextSize = 11,
    Font = Enum.Font.GothamBold,
    ZIndex = 6,
    Parent = mainPanel,
})

------------------------------------------------------------
-- STATUS BAR CONTAINER
------------------------------------------------------------
local statusContainer = createElement("Frame", {
    Name = "StatusContainer",
    Size = UDim2.new(1, 0, 0, 13),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    LayoutOrder = 1,
    Parent = mainPanel,
})
addListLayout(
    Enum.FillDirection.Horizontal,
    Enum.HorizontalAlignment.Left,
    nil,
    4,
    statusContainer
)

-- Green status dot (pulsing)
local greenDot = createElement("Frame", {
    Name = "GreenDot",
    Size = UDim2.new(0, 5, 0, 5),
    BackgroundColor3 = Theme.green,
    BorderSizePixel = 0,
    LayoutOrder = 1,
    Parent = statusContainer,
})
addCorner(10, greenDot)
playTween(greenDot, Tweens.pulse, {
    BackgroundColor3 = Color3.fromRGB(130, 255, 160),
})

-- Connected label
createElement("TextLabel", {
    Name = "ConnectedLabel",
    Size = UDim2.new(0, 44, 1, 0),
    BackgroundTransparency = 1,
    Text = "Connected",
    TextColor3 = Theme.green,
    TextSize = 11,
    Font = Enum.Font.GothamMedium,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = 2,
    Parent = statusContainer,
})

-- Separator line
createElement("Frame", {
    Size = UDim2.new(0, 1, 0, 9),
    BackgroundColor3 = Theme.line,
    BorderSizePixel = 0,
    LayoutOrder = 3,
    Parent = statusContainer,
})

-- Yellow dot
local yellowDot = createElement("Frame", {
    Name = "YellowDot",
    Size = UDim2.new(0, 5, 0, 5),
    BackgroundColor3 = Theme.yellow,
    BorderSizePixel = 0,
    LayoutOrder = 4,
    Parent = statusContainer,
})
addCorner(10, yellowDot)

-- Info label
createElement("TextLabel", {
    Name = "InfoLabel",
    Size = UDim2.new(0, 52, 1, 0),
    BackgroundTransparency = 1,
    Text = "Press F6",
    TextColor3 = Theme.yellow,
    TextSize = 11,
    Font = Enum.Font.GothamMedium,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = 5,
    Parent = statusContainer,
})

------------------------------------------------------------
-- EXPANDABLE PANEL (slides down)
------------------------------------------------------------
local expandPanel = createElement("Frame", {
    Name = "ExpandPanel",
    Size = UDim2.new(1, 0, 0, 0),
    Position = UDim2.new(0, 0, 0, BAR_H),
    BackgroundColor3 = Theme.bg,
    BackgroundTransparency = Theme.bgT,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 4,
    Parent = mainPanel,
})
addCorner(CORNER_R, expandPanel)

------------------------------------------------------------
-- TAB BAR
------------------------------------------------------------
local tabBar = createElement("Frame", {
    Name = "TabBar",
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Parent = expandPanel,
})
addListLayout(
    Enum.FillDirection.Horizontal,
    Enum.HorizontalAlignment.Center,
    Enum.VerticalAlignment.Center,
    4,
    tabBar
)
addPadding(PAD, PAD, 0, 0, tabBar)

local tabButtons = {}
for _, tabInfo in ipairs(TABS) do
    local tabBtn = createElement("ImageButton", {
        Name = tabInfo.name,
        Size = UDim2.new(0, 28, 0, 28),
        BackgroundColor3 = Theme.btn,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Image = tabInfo.icon,
        ImageColor3 = Theme.txtSub,
        ScaleType = Enum.ScaleType.Fit,
        LayoutOrder = tabInfo.order,
        AutoButtonColor = false,
        Parent = tabBar,
    })
    addCorner(CORNER_S, tabBtn)

    tabBtn.MouseEnter:Connect(function()
        playTween(tabBtn, Tweens.fast, { BackgroundColor3 = Theme.btnHov })
    end)
    tabBtn.MouseLeave:Connect(function()
        playTween(tabBtn, Tweens.fast, { BackgroundColor3 = Theme.btn })
    end)
    tabBtn.MouseButton1Click:Connect(function()
        playSfx(sfxClick)
        currentTab = tabInfo.name
        for _, btn in pairs(tabButtons) do
            local isActive = btn.Name == tabInfo.name
            playTween(btn, Tweens.fast, {
                ImageColor3 = isActive and Theme.accent or Theme.txtSub,
            })
        end
    end)
    tabButtons[tabInfo.name] = tabBtn
end

-- Activate default tab
if tabButtons["cmds"] then
    tabButtons["cmds"].ImageColor3 = Theme.accent
end

------------------------------------------------------------
-- TAB SEPARATOR
------------------------------------------------------------
createElement("Frame", {
    Name = "TabSep",
    Size = UDim2.new(1, -12, 0, 1),
    Position = UDim2.new(0, 6, 0, 30),
    BackgroundColor3 = Theme.line,
    BorderSizePixel = 0,
    Parent = expandPanel,
})

------------------------------------------------------------
-- COMMAND LIST SCROLL
------------------------------------------------------------
local cmdScroll = createElement("ScrollingFrame", {
    Name = "CmdScroll",
    Size = UDim2.new(1, 0, 1, -34),
    Position = UDim2.new(0, 0, 0, 34),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = Theme.line,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    Parent = expandPanel,
})
addListLayout(
    Enum.FillDirection.Vertical,
    Enum.HorizontalAlignment.Center,
    nil,
    2,
    cmdScroll
)
addPadding(PAD, PAD, 4, 4, cmdScroll)

------------------------------------------------------------
-- COMMAND INPUT (TextBox in the bar)
------------------------------------------------------------
local cmdPrefix = createElement("TextLabel", {
    Name = "CmdPrefix",
    Size = UDim2.new(0, 20, 1, 0),
    Position = UDim2.new(0, 8, 0, 0),
    BackgroundTransparency = 1,
    Text = ">",
    TextColor3 = Theme.green,
    TextSize = 14,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 7,
    Parent = mainPanel,
})

local cmdInput = createElement("TextBox", {
    Name = "CmdInput",
    Size = UDim2.new(1, -90, 1, 0),
    Position = UDim2.new(0, 30, 0, 0),
    BackgroundTransparency = 1,
    Text = "",
    TextColor3 = Theme.txt,
    PlaceholderColor3 = Theme.txtSub,
    PlaceholderText = "Type a command...",
    TextSize = 13,
    Font = Enum.Font.GothamMedium,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
    ZIndex = 7,
    Parent = mainPanel,
})

------------------------------------------------------------
-- TOGGLE BUTTON (expand/collapse panel)
------------------------------------------------------------
local toggleBtn = createElement("TextButton", {
    Name = "ToggleBtn",
    Size = UDim2.new(0, 52, 0, 22),
    Position = UDim2.new(1, -58, 0.5, 0),
    AnchorPoint = Vector2.new(0, 0.5),
    BackgroundColor3 = Theme.btn,
    BackgroundTransparency = 0,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Text = "cmds",
    TextColor3 = Theme.txtSub,
    TextSize = 10,
    Font = Enum.Font.GothamBold,
    ZIndex = 7,
    Parent = mainPanel,
})
addCorner(CORNER_S, toggleBtn)

------------------------------------------------------------
-- PANEL EXPAND / COLLAPSE LOGIC
------------------------------------------------------------
local EXPAND_H = 260

local function expandBar()
    if isBarOpen then return end
    isBarOpen = true
    playSfx(sfxClick)
    playTween(mainPanel, Tweens.slide, {
        Size = UDim2.new(0, panelWidth, 0, BAR_H + EXPAND_H),
        Position = UDim2.new(1, -(panelWidth + 8), 1, -(BAR_H + EXPAND_H + 8)),
    })
    playTween(expandPanel, Tweens.slide, {
        Size = UDim2.new(1, 0, 0, EXPAND_H),
    })
    playTween(toggleBtn, Tweens.fast, {
        BackgroundColor3 = Theme.surface,
    })
end

local function collapseBar()
    if not isBarOpen then return end
    isBarOpen = false
    playSfx(sfxClick)
    playTween(mainPanel, Tweens.slide, {
        Size = UDim2.new(0, panelWidth, 0, BAR_H),
        Position = UDim2.new(1, -(panelWidth + 8), 1, -(BAR_H + 8)),
    })
    playTween(expandPanel, Tweens.slide, {
        Size = UDim2.new(1, 0, 0, 0),
    })
    playTween(toggleBtn, Tweens.fast, {
        BackgroundColor3 = Theme.btn,
    })
end

toggleBtn.MouseButton1Click:Connect(function()
    if isBarOpen then
        collapseBar()
    else
        expandBar()
    end
end)

toggleBtn.MouseEnter:Connect(function()
    if not isBarOpen then
        playTween(toggleBtn, Tweens.fast, { BackgroundColor3 = Theme.btnHov })
    end
end)
toggleBtn.MouseLeave:Connect(function()
    if not isBarOpen then
        playTween(toggleBtn, Tweens.fast, { BackgroundColor3 = Theme.btn })
    end
end)

------------------------------------------------------------
-- F6 KEYBIND (focus the command input)
------------------------------------------------------------
local TOGGLE_KEY = Enum.KeyCode.F6

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == TOGGLE_KEY then
        if cmdBarFocused then
            cmdInput:ReleaseFocus()
        else
            cmdInput:CaptureFocus()
        end
    end
end)

cmdInput.Focused:Connect(function()
    cmdBarFocused = true
    playTween(cmdPrefix, Tweens.fast, { TextColor3 = executorAccent })
end)

cmdInput:GetPropertyChangedSignal("Text"):Connect(function()
    -- future: live command suggestions / filtering
end)

------------------------------------------------------------
-- NOTIFICATION SYSTEM
------------------------------------------------------------
local notifYOffset = 0

local function showNotification(title, body, duration)
    duration = duration or 4

    local playerGui = localPlayer:WaitForChild("PlayerGui")

    -- Find or create notification container
    local notifGui = playerGui:FindFirstChild("AKAdminNotificationGui")
    if not notifGui then
        notifGui = createElement("ScreenGui", {
            Name = "AKAdminNotificationGui",
            ResetOnSpawn = false,
            Parent = playerGui,
        })
    end

    -- Calculate Y offset for stacking
    local yPos = notifYOffset
    notifYOffset = notifYOffset + 70

    local notifFrame = createElement("Frame", {
        Name = "Notification",
        Size = UDim2.new(0, 320, 0, 60),
        Position = UDim2.new(1, 10, 0, yPos),
        BackgroundColor3 = Theme.black,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        ZIndex = 100,
        Parent = notifGui,
    })
    addCorner(12, notifFrame)

    -- Avatar image (direct URL, no yielding)
    local avatarImg = createElement("ImageLabel", {
        Name = "Avatar",
        Size = UDim2.new(0, 44, 0, 44),
        Position = UDim2.new(0, 8, 0, 8),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Image = string.format(HEADSHOT_URL, localPlayer.UserId),
        ZIndex = 101,
        Parent = notifFrame,
    })
    addCorner(8, avatarImg)

    -- Title
    createElement("TextLabel", {
        Name = "Title",
        Size = UDim2.new(0, 250, 0, 16),
        Position = UDim2.new(0, 60, 0, 8),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = Theme.white,
        TextTransparency = 0.5,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = title,
        ZIndex = 101,
        Parent = notifFrame,
    })

    -- Body
    createElement("TextLabel", {
        Name = "Body",
        Size = UDim2.new(0, 250, 0, 28),
        Position = UDim2.new(0, 60, 0, 24),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = Theme.white,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        Text = body,
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
-- COMMAND ENTRY BUILDER (populate scroll list)
------------------------------------------------------------
local function buildCmdEntry(name, description)
    local entry = createElement("Frame", {
        Name = name,
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = Theme.surface,
        BackgroundTransparency = Theme.surfaceT,
        BorderSizePixel = 0,
        Parent = cmdScroll,
    })
    addCorner(CORNER_XS, entry)

    createElement("TextLabel", {
        Size = UDim2.new(0, 80, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1,
        Text = "!" .. name,
        TextColor3 = Theme.accent,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = entry,
    })

    if description then
        createElement("TextLabel", {
            Size = UDim2.new(1, -96, 1, 0),
            Position = UDim2.new(0, 92, 0, 0),
            BackgroundTransparency = 1,
            Text = description,
            TextColor3 = Theme.txtFaint,
            TextSize = 10,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = entry,
        })
    end

    entry.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            playTween(entry, Tweens.fast, { BackgroundTransparency = 0 })
        end
    end)
    entry.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            playTween(entry, Tweens.fast, { BackgroundTransparency = Theme.surfaceT })
        end
    end)

    return entry
end

------------------------------------------------------------
-- COMMAND EXECUTION
------------------------------------------------------------
local function executeCommand(text)
    if text == "" then return end

    -- Strip leading/trailing whitespace
    text = text:match("^%s*(.-)%s*$") or text

    -- Parse command and args
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

    -- Execute with pcall
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

-- Handle command input
cmdInput.FocusLost:Connect(function(enterPressed)
    cmdBarFocused = false
    playTween(cmdPrefix, Tweens.fast, { TextColor3 = Theme.green })

    if enterPressed and cmdInput.Text ~= "" then
        local text = cmdInput.Text
        cmdInput.Text = ""
        playSfx(sfxOk)
        executeCommand(text)
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
    -- cmds.lua's internal VM tries to concatenate the descendants arg with strings.
    -- We wrap the descendants table so it supports concatenation via __concat.
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
    -- Copy array entries so ipairs/iteration works
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

    -- Build integrity key from workspace state
    local hashStr = tostring(#rawDescendants) .. ":" .. tostring(serverTime) .. ":0"
    local hash = computeHash(hashStr)

    -- Load commands from GitHub or local fallback
    local function registerCmds(result)
        if type(result) == "table" then
            local count = 0
            for name, handler in pairs(result) do
                local cmdKey = "!" .. name
                if type(handler) == "function" then
                    commands[cmdKey] = handler
                    commands[name] = handler
                    buildCmdEntry(name)
                    count = count + 1
                elseif type(handler) == "table" and handler.fn then
                    commands[cmdKey] = handler.fn
                    commands[name] = handler.fn
                    buildCmdEntry(name, handler.desc or "")
                    count = count + 1
                end
            end
            return count
        end
        return 0
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
                showNotification("AK ADMIN", count .. " commands loaded (remote)", 3)
            elseif type(result) == "function" then
                local fnResult = result(descendants, serverTime, hash)
                count = registerCmds(fnResult)
                if count > 0 then cmdsLoaded = true end
            end
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
        showNotification("AK ADMIN", "No commands loaded. Place AKAdmin_cmds.lua in scripts folder.", 5)
    end

    -- Also try loading extended baseplate prompt
    pcall(function()
        local bpSource = game:HttpGet(BASEPLATE_URL)
        if bpSource and bpSource ~= "" then
            local bpFn = loadstring(bpSource)
            if bpFn then bpFn() end
        end
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
-- WELCOME MESSAGE SETUP (TextChatService integration)
------------------------------------------------------------
pcall(function()
    local textChatService = getService("TextChatService")
    local channels = textChatService:WaitForChild("TextChannels", 10)
    if channels then
        local general = channels:FindFirstChild("RBXGeneral")
        if general then
            general.MessageReceived:Connect(function(msg)
                -- Future: handle chat commands here
            end)
        end
    end
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

print("[AK Admin] Loaded successfully. Press F6 to focus the command bar.")
print("[AK Admin] Discord: " .. DISCORD_URL)
