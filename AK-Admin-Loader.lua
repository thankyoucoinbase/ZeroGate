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
-- COMMAND SCROLL LIST
------------------------------------------------------------
local scrollTop = TITLE_H + SEARCH_H + 20

local cmdScroll = createElement("ScrollingFrame", {
    Name = "CmdScroll",
    Size = UDim2.new(1, -20, 1, -(scrollTop + 8)),
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
    4,
    cmdScroll
)
addPadding(2, 2, 2, 2, cmdScroll)

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
        playTween(mainFrame, Tweens.slide, {
            Size = UDim2.new(0, WIN_W, 0, TITLE_H + 4),
        })
        minimizeBtn.Text = "+"
    else
        playTween(mainFrame, Tweens.slide, {
            Size = UDim2.new(0, WIN_W, 0, WIN_H),
        })
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
    for _, child in ipairs(cmdScroll:GetChildren()) do
        if child:IsA("Frame") then
            if query == "" then
                child.Visible = true
            else
                child.Visible = string.find(string.lower(child.Name), query, 1, true) ~= nil
            end
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
-- COMMAND ENTRY BUILDER (populate scroll list)
------------------------------------------------------------
local function buildCmdEntry(name, description)
    local entry = createElement("Frame", {
        Name = name,
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Theme.surface,
        BackgroundTransparency = Theme.surfaceT,
        BorderSizePixel = 0,
        Parent = cmdScroll,
    })
    addCorner(8, entry)
    addStroke(Theme.borderDim, 0.6, entry)

    -- Command name
    local cmdLabel = createElement("TextLabel", {
        Size = UDim2.new(1, -16, 0, 18),
        Position = UDim2.new(0, 10, 0, description and 4 or 9),
        BackgroundTransparency = 1,
        Text = "!" .. name,
        TextColor3 = Theme.txt,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = entry,
    })

    -- Description (if provided)
    if description and description ~= "" then
        createElement("TextLabel", {
            Size = UDim2.new(1, -16, 0, 14),
            Position = UDim2.new(0, 10, 0, 20),
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

    -- Hover effect
    entry.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            playTween(entry, Tweens.fast, {
                BackgroundColor3 = Theme.surfHov,
                BackgroundTransparency = 0.15,
            })
        end
    end)
    entry.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            playTween(entry, Tweens.fast, {
                BackgroundColor3 = Theme.surface,
                BackgroundTransparency = Theme.surfaceT,
            })
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

    -- Register commands into UI + command table
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
