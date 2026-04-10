-- AK Admin Commands Module (Full Implementation)
-- Called as: loadstring(source)(descendants, serverTime, hash)
-- Returns a table mapping command_name -> {fn=function, desc=string}

return (function(descendants, serverTime, hash)

    ---------------------------------------------------------------------------
    -- Services
    ---------------------------------------------------------------------------
    local Services = {}
    Services.Players = game:GetService("Players")
    Services.RunService = game:GetService("RunService")
    Services.UserInputService = game:GetService("UserInputService")
    Services.TweenService = game:GetService("TweenService")
    Services.StarterGui = game:GetService("StarterGui")
    Services.HttpService = game:GetService("HttpService")
    Services.Workspace = game:GetService("Workspace")
    Services.Lighting = game:GetService("Lighting")
    Services.ReplicatedStorage = game:GetService("ReplicatedStorage")
    Services.TextChatService = game:GetService("TextChatService")
    Services.TeleportService = game:GetService("TeleportService")
    Services.SoundService = game:GetService("SoundService")
    Services.GuiService = game:GetService("GuiService")

    local localPlayer = Services.Players.LocalPlayer
    local camera = Services.Workspace.CurrentCamera

    ---------------------------------------------------------------------------
    -- Helper Functions
    ---------------------------------------------------------------------------

    local function notify(title, text)
        pcall(function()
            Services.StarterGui:SetCore("SendNotification", {
                Title = title or "AK Admin",
                Text = text or "",
                Duration = 4
            })
        end)
    end

    local function splitArgs(str)
        if type(str) == "table" then return str end
        local args = {}
        if not str or str == "" then return args end
        for word in string.gmatch(tostring(str), "%S+") do
            table.insert(args, word)
        end
        return args
    end

    local function getChar()
        return localPlayer.Character
    end

    local function getRoot()
        local char = getChar()
        return char and char:FindFirstChild("HumanoidRootPart")
    end

    local function getHumanoid()
        local char = getChar()
        return char and char:FindFirstChildOfClass("Humanoid")
    end

    local function getPlayerByName(name)
        if not name or name == "" then return nil end
        name = string.lower(name)
        if name == "me" then return localPlayer end
        for _, player in ipairs(Services.Players:GetPlayers()) do
            if string.lower(player.Name) == name or string.lower(player.DisplayName) == name then
                return player
            end
        end
        for _, player in ipairs(Services.Players:GetPlayers()) do
            if string.find(string.lower(player.Name), name, 1, true) or
               string.find(string.lower(player.DisplayName), name, 1, true) then
                return player
            end
        end
        return nil
    end

    local function getnearest(player)
        if not player or not player.Character then return nil end
        local root = player.Character:FindFirstChild("HumanoidRootPart")
        if not root then return nil end
        local nearest, nearestDist = nil, math.huge
        for _, other in ipairs(Services.Players:GetPlayers()) do
            if other ~= player and other.Character then
                local otherRoot = other.Character:FindFirstChild("HumanoidRootPart")
                if otherRoot then
                    local dist = (root.Position - otherRoot.Position).Magnitude
                    if dist < nearestDist then
                        nearest = other
                        nearestDist = dist
                    end
                end
            end
        end
        return nearest
    end

    local function getfurthest(player)
        if not player or not player.Character then return nil end
        local root = player.Character:FindFirstChild("HumanoidRootPart")
        if not root then return nil end
        local furthest, furthestDist = nil, 0
        for _, other in ipairs(Services.Players:GetPlayers()) do
            if other ~= player and other.Character then
                local otherRoot = other.Character:FindFirstChild("HumanoidRootPart")
                if otherRoot then
                    local dist = (root.Position - otherRoot.Position).Magnitude
                    if dist > furthestDist then
                        furthest = other
                        furthestDist = dist
                    end
                end
            end
        end
        return furthest
    end

    local function checkIfDead(player)
        if not player or not player.Character then return true end
        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return true end
        return humanoid.Health <= 0
    end

    local function resolveTargets(arg)
        if not arg or arg == "" then return {} end
        arg = string.lower(arg)
        if arg == "me" then
            return { localPlayer }
        elseif arg == "all" then
            return Services.Players:GetPlayers()
        elseif arg == "others" then
            local targets = {}
            for _, p in ipairs(Services.Players:GetPlayers()) do
                if p ~= localPlayer then
                    table.insert(targets, p)
                end
            end
            return targets
        elseif arg == "nearest" then
            local n = getnearest(localPlayer)
            return n and { n } or {}
        elseif arg == "furthest" then
            local f = getfurthest(localPlayer)
            return f and { f } or {}
        else
            local player = getPlayerByName(arg)
            return player and { player } or {}
        end
    end

    local function sendChat(msg)
        pcall(function()
            local tcs = Services.TextChatService
            local channels = tcs:FindFirstChild("TextChannels")
            if channels then
                local rbxGeneral = channels:FindFirstChild("RBXGeneral")
                if rbxGeneral then
                    rbxGeneral:SendAsync(msg)
                    return
                end
            end
            -- Fallback legacy chat
            local chatRemote = Services.ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
            if chatRemote then
                local sayMsg = chatRemote:FindFirstChild("SayMessageRequest")
                if sayMsg then
                    sayMsg:FireServer(msg, "All")
                end
            end
        end)
    end

    ---------------------------------------------------------------------------
    -- Commands Table
    ---------------------------------------------------------------------------
    local commands = {}

    ---------------------------------------------------------------------------
    -- MOVEMENT COMMANDS
    ---------------------------------------------------------------------------

    commands["bring"] = {
        fn = function(args)
            local targets = resolveTargets(splitArgs(args)[1])
            if #targets == 0 then notify("AK Admin", "Player not found") return end
            pcall(function()
                setsimulationradius(math.huge)
            end)
            local myRoot = getRoot()
            if not myRoot then notify("AK Admin", "No character") return end
            for _, target in ipairs(targets) do
                pcall(function()
                    if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                        local tRoot = target.Character.HumanoidRootPart
                        tRoot.CFrame = myRoot.CFrame * CFrame.new(0, 0, -3)
                    end
                end)
            end
            notify("AK Admin", "Brought player(s)")
        end,
        desc = "bring [player] - teleport target to you"
    }

    commands["call"] = {
        fn = function(args)
            commands["bring"].fn(args)
        end,
        desc = "call [player] - same as bring"
    }

    commands["gokutp"] = {
        fn = function(args)
            local targets = resolveTargets(splitArgs(args)[1])
            if #targets == 0 then notify("AK Admin", "Player not found") return end
            local myRoot = getRoot()
            if not myRoot then return end
            pcall(function()
                local tRoot = targets[1].Character:FindFirstChild("HumanoidRootPart")
                if tRoot then
                    myRoot.CFrame = tRoot.CFrame * CFrame.new(0, 0, -3)
                end
            end)
            notify("AK Admin", "Teleported to " .. targets[1].Name)
        end,
        desc = "gokutp [player] - instant teleport to target"
    }

    commands["ftap"] = {
        fn = function(args)
            local targets = resolveTargets(splitArgs(args)[1])
            if #targets == 0 then notify("AK Admin", "Player not found") return end
            local myRoot = getRoot()
            if not myRoot then return end
            pcall(function()
                local tRoot = targets[1].Character:FindFirstChild("HumanoidRootPart")
                if tRoot then
                    myRoot.CFrame = tRoot.CFrame * CFrame.new(0, 0, -2)
                    task.wait(0.1)
                    -- Fling after teleport
                    myRoot.AssemblyLinearVelocity = Vector3.new(math.random(-500, 500), 500, math.random(-500, 500))
                    myRoot.AssemblyAngularVelocity = Vector3.new(0, 9e8, 0)
                    task.wait(0.3)
                    myRoot.AssemblyLinearVelocity = Vector3.zero
                    myRoot.AssemblyAngularVelocity = Vector3.zero
                end
            end)
            notify("AK Admin", "Fling-TP'd " .. targets[1].Name)
        end,
        desc = "ftap [player] - fling teleport to target"
    }

    commands["ftp"] = {
        fn = function(args)
            local targets = resolveTargets(splitArgs(args)[1])
            if #targets == 0 then notify("AK Admin", "Player not found") return end
            local myRoot = getRoot()
            if not myRoot then return end
            pcall(function()
                local tRoot = targets[1].Character:FindFirstChild("HumanoidRootPart")
                if tRoot then
                    myRoot.CFrame = tRoot.CFrame
                    task.wait(0.15)
                    myRoot.AssemblyLinearVelocity = (tRoot.Position - myRoot.Position).Unit * 300 + Vector3.new(0, 200, 0)
                    myRoot.AssemblyAngularVelocity = Vector3.new(math.random(-100, 100), math.huge, math.random(-100, 100))
                    task.wait(0.5)
                    myRoot.AssemblyLinearVelocity = Vector3.zero
                    myRoot.AssemblyAngularVelocity = Vector3.zero
                end
            end)
            notify("AK Admin", "FTP'd " .. targets[1].Name)
        end,
        desc = "ftp [player] - fling teleport variant"
    }

    commands["tprj"] = {
        fn = function(args)
            local players = Services.Players:GetPlayers()
            local others = {}
            for _, p in ipairs(players) do
                if p ~= localPlayer then table.insert(others, p) end
            end
            if #others == 0 then notify("AK Admin", "No other players") return end
            local target = others[math.random(1, #others)]
            local myRoot = getRoot()
            if not myRoot then return end
            pcall(function()
                local tRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                if tRoot then
                    myRoot.CFrame = tRoot.CFrame * CFrame.new(0, 0, -5)
                end
            end)
            notify("AK Admin", "Teleported to " .. target.Name)
        end,
        desc = "tprj - teleport to random player"
    }

    commands["stalk"] = {
        fn = function(args)
            local targetName = splitArgs(args)[1]
            if not targetName then notify("AK Admin", "Specify a player") return end
            local target = getPlayerByName(targetName)
            if not target then notify("AK Admin", "Player not found") return end
            if getgenv().AKAdmin_Stalk then
                getgenv().AKAdmin_Stalk = false
                notify("AK Admin", "Stalk disabled")
                return
            end
            getgenv().AKAdmin_Stalk = true
            notify("AK Admin", "Stalking " .. target.Name)
            task.spawn(function()
                while getgenv().AKAdmin_Stalk do
                    pcall(function()
                        local myRoot = getRoot()
                        local tRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                        if myRoot and tRoot then
                            myRoot.CFrame = tRoot.CFrame * CFrame.new(0, 0, -5)
                        end
                    end)
                    task.wait(0.1)
                end
            end)
        end,
        desc = "stalk [player] - continuously follow a player (toggle)"
    }

    ---------------------------------------------------------------------------
    -- COMBAT COMMANDS
    ---------------------------------------------------------------------------

    commands["fling"] = {
        fn = function(args)
            local targets = resolveTargets(splitArgs(args)[1])
            if #targets == 0 then notify("AK Admin", "Player not found") return end
            local myRoot = getRoot()
            if not myRoot then return end
            pcall(function()
                local tRoot = targets[1].Character:FindFirstChild("HumanoidRootPart")
                if not tRoot then return end
                local origCFrame = myRoot.CFrame
                myRoot.CFrame = tRoot.CFrame * CFrame.new(0, 0, -1)
                task.wait()
                myRoot.AssemblyAngularVelocity = Vector3.new(0, 9e8, 0)
                myRoot.AssemblyLinearVelocity = Vector3.new(9e5, 9e5, 9e5)
                if firetouchinterest then
                    firetouchinterest(myRoot, tRoot, 0)
                    task.wait(0.1)
                    firetouchinterest(myRoot, tRoot, 1)
                end
                task.wait(0.4)
                myRoot.AssemblyAngularVelocity = Vector3.zero
                myRoot.AssemblyLinearVelocity = Vector3.zero
                myRoot.CFrame = origCFrame
            end)
            notify("AK Admin", "Flung " .. targets[1].Name)
        end,
        desc = "fling [player] - fling target player"
    }

    commands["touchfling"] = {
        fn = function(args)
            local targets = resolveTargets(splitArgs(args)[1])
            if #targets == 0 then notify("AK Admin", "Player not found") return end
            local myRoot = getRoot()
            if not myRoot then return end
            pcall(function()
                local tRoot = targets[1].Character:FindFirstChild("HumanoidRootPart")
                if not tRoot then return end
                local origCFrame = myRoot.CFrame
                myRoot.AssemblyAngularVelocity = Vector3.new(0, 9e8, 0)
                myRoot.AssemblyLinearVelocity = Vector3.new(9e5, 9e5, 9e5)
                if firetouchinterest then
                    for i = 1, 5 do
                        myRoot.CFrame = tRoot.CFrame
                        firetouchinterest(myRoot, tRoot, 0)
                        task.wait()
                        firetouchinterest(myRoot, tRoot, 1)
                    end
                end
                task.wait(0.3)
                myRoot.AssemblyAngularVelocity = Vector3.zero
                myRoot.AssemblyLinearVelocity = Vector3.zero
                myRoot.CFrame = origCFrame
            end)
            notify("AK Admin", "Touch-flung " .. targets[1].Name)
        end,
        desc = "touchfling [player] - firetouchinterest fling"
    }

    commands["uafling"] = {
        fn = function(args)
            local targets = resolveTargets(splitArgs(args)[1])
            if #targets == 0 then notify("AK Admin", "Player not found") return end
            pcall(function()
                local tRoot = targets[1].Character:FindFirstChild("HumanoidRootPart")
                if not tRoot then return end
                for _, obj in ipairs(Services.Workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and not obj.Anchored and obj.Parent ~= getChar() then
                        obj.AssemblyLinearVelocity = (tRoot.Position - obj.Position).Unit * 500
                        obj.AssemblyAngularVelocity = Vector3.new(math.random(-50, 50), math.random(-50, 50), math.random(-50, 50))
                    end
                end
            end)
            notify("AK Admin", "UA-flung at " .. targets[1].Name)
        end,
        desc = "uafling [player] - fling unanchored parts at target"
    }

    commands["dropkick"] = {
        fn = function(args)
            local targets = resolveTargets(splitArgs(args)[1])
            if #targets == 0 then notify("AK Admin", "Player not found") return end
            local myRoot = getRoot()
            if not myRoot then return end
            pcall(function()
                local tRoot = targets[1].Character:FindFirstChild("HumanoidRootPart")
                if not tRoot then return end
                local origCFrame = myRoot.CFrame
                -- TP above target
                myRoot.CFrame = tRoot.CFrame * CFrame.new(0, 15, 0)
                task.wait(0.1)
                -- Slam down with high velocity
                myRoot.AssemblyLinearVelocity = Vector3.new(0, -800, 0)
                myRoot.AssemblyAngularVelocity = Vector3.new(math.huge, 0, 0)
                if firetouchinterest then
                    task.wait(0.2)
                    firetouchinterest(myRoot, tRoot, 0)
                    task.wait(0.1)
                    firetouchinterest(myRoot, tRoot, 1)
                end
                task.wait(0.5)
                myRoot.AssemblyLinearVelocity = Vector3.zero
                myRoot.AssemblyAngularVelocity = Vector3.zero
                myRoot.CFrame = origCFrame
            end)
            notify("AK Admin", "Dropkicked " .. targets[1].Name)
        end,
        desc = "dropkick [player] - drop kick target"
    }

    commands["trip"] = {
        fn = function(args)
            local targets = resolveTargets(splitArgs(args)[1])
            if #targets == 0 then notify("AK Admin", "Player not found") return end
            pcall(function()
                setsimulationradius(math.huge)
            end)
            pcall(function()
                local hum = targets[1].Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.PlatformStand = true
                    task.delay(2, function()
                        pcall(function()
                            hum.PlatformStand = false
                        end)
                    end)
                end
            end)
            notify("AK Admin", "Tripped " .. targets[1].Name)
        end,
        desc = "trip [player] - ragdoll target briefly"
    }

    commands["flip"] = {
        fn = function(args)
            local targets = resolveTargets(splitArgs(args)[1])
            if #targets == 0 then notify("AK Admin", "Player not found") return end
            pcall(function()
                setsimulationradius(math.huge)
            end)
            pcall(function()
                local tRoot = targets[1].Character:FindFirstChild("HumanoidRootPart")
                if tRoot then
                    tRoot.CFrame = tRoot.CFrame * CFrame.Angles(math.rad(180), 0, 0)
                end
            end)
            notify("AK Admin", "Flipped " .. targets[1].Name)
        end,
        desc = "flip [player] - rotate target upside down"
    }

    commands["ball"] = {
        fn = function(args)
            local targets = resolveTargets(splitArgs(args)[1])
            if #targets == 0 then notify("AK Admin", "Player not found") return end
            local myRoot = getRoot()
            if not myRoot then return end
            pcall(function()
                local tRoot = targets[1].Character:FindFirstChild("HumanoidRootPart")
                if not tRoot then return end
                local ball = Instance.new("Part")
                ball.Shape = Enum.PartType.Ball
                ball.Size = Vector3.new(4, 4, 4)
                ball.BrickColor = BrickColor.new("Really red")
                ball.Material = Enum.Material.Neon
                ball.CFrame = myRoot.CFrame * CFrame.new(0, 2, -3)
                ball.Anchored = false
                ball.CanCollide = true
                ball.Parent = Services.Workspace
                local direction = (tRoot.Position - ball.Position).Unit
                ball.AssemblyLinearVelocity = direction * 600
                ball.AssemblyAngularVelocity = Vector3.new(0, 9e6, 0)
                task.delay(5, function()
                    pcall(function() ball:Destroy() end)
                end)
            end)
            notify("AK Admin", "Ball flung at " .. targets[1].Name)
        end,
        desc = "ball [player] - fling ball at target"
    }

    commands["domainexpansion"] = {
        fn = function(args)
            local targets = resolveTargets(splitArgs(args)[1])
            if #targets == 0 then notify("AK Admin", "Player not found") return end
            local myRoot = getRoot()
            if not myRoot then return end
            pcall(function()
                local tRoot = targets[1].Character:FindFirstChild("HumanoidRootPart")
                if not tRoot then return end
                -- Create purple sphere visual
                local sphere = Instance.new("Part")
                sphere.Shape = Enum.PartType.Ball
                sphere.Size = Vector3.new(1, 1, 1)
                sphere.BrickColor = BrickColor.new("Royal purple")
                sphere.Material = Enum.Material.ForceField
                sphere.Transparency = 0.3
                sphere.Anchored = true
                sphere.CanCollide = false
                sphere.CFrame = myRoot.CFrame
                sphere.Parent = Services.Workspace
                -- Expand the sphere
                task.spawn(function()
                    for i = 1, 40 do
                        sphere.Size = Vector3.new(i * 3, i * 3, i * 3)
                        sphere.CFrame = myRoot.CFrame
                        task.wait(0.03)
                    end
                    task.wait(0.5)
                    sphere:Destroy()
                end)
                -- Fling after brief delay
                task.wait(0.5)
                local origCFrame = myRoot.CFrame
                myRoot.CFrame = tRoot.CFrame * CFrame.new(0, 0, -1)
                task.wait()
                myRoot.AssemblyAngularVelocity = Vector3.new(0, 9e8, 0)
                myRoot.AssemblyLinearVelocity = Vector3.new(9e5, 9e5, 9e5)
                if firetouchinterest then
                    firetouchinterest(myRoot, tRoot, 0)
                    task.wait(0.15)
                    firetouchinterest(myRoot, tRoot, 1)
                end
                task.wait(0.4)
                myRoot.AssemblyAngularVelocity = Vector3.zero
                myRoot.AssemblyLinearVelocity = Vector3.zero
                myRoot.CFrame = origCFrame
            end)
            notify("AK Admin", "Domain Expansion on " .. targets[1].Name)
        end,
        desc = "domainexpansion [player] - fancy fling with visual"
    }

    commands["aimlock"] = {
        fn = function(args)
            if getgenv().AKAdmin_Aimlock then
                getgenv().AKAdmin_Aimlock = false
                notify("AK Admin", "Aimlock disabled")
                return
            end
            local targetName = splitArgs(args)[1]
            if not targetName then notify("AK Admin", "Specify a player") return end
            local target = getPlayerByName(targetName)
            if not target then notify("AK Admin", "Player not found") return end
            getgenv().AKAdmin_Aimlock = true
            notify("AK Admin", "Aimlock on " .. target.Name)
            task.spawn(function()
                while getgenv().AKAdmin_Aimlock do
                    pcall(function()
                        if target.Character and target.Character:FindFirstChild("Head") then
                            local headPos = target.Character.Head.Position
                            camera.CFrame = CFrame.lookAt(camera.CFrame.Position, headPos)
                        end
                    end)
                    task.wait()
                end
            end)
        end,
        desc = "aimlock [player] - lock camera to target (toggle)"
    }

    commands["swordreach"] = {
        fn = function(args)
            local studs = tonumber(splitArgs(args)[1]) or 100
            pcall(function()
                local char = getChar()
                if not char then return end
                for _, tool in ipairs(localPlayer.Backpack:GetChildren()) do
                    if tool:IsA("Tool") then
                        local handle = tool:FindFirstChild("Handle")
                        if handle then
                            handle.Size = Vector3.new(studs, 1, 1)
                            handle.Massless = true
                            handle.Transparency = 1
                        end
                    end
                end
                -- Also check equipped tools
                for _, tool in ipairs(char:GetChildren()) do
                    if tool:IsA("Tool") then
                        local handle = tool:FindFirstChild("Handle")
                        if handle then
                            handle.Size = Vector3.new(studs, 1, 1)
                            handle.Massless = true
                            handle.Transparency = 1
                        end
                    end
                end
            end)
            notify("AK Admin", "Sword reach set to " .. tostring(studs))
        end,
        desc = "swordreach [studs] - extend melee reach"
    }

    ---------------------------------------------------------------------------
    -- CHARACTER COMMANDS
    ---------------------------------------------------------------------------

    commands["re"] = {
        fn = function(args)
            pcall(function()
                local char = getChar()
                if char then
                    char:BreakJoints()
                end
            end)
            notify("AK Admin", "Respawning...")
        end,
        desc = "re - respawn character"
    }

    commands["voidre"] = {
        fn = function(args)
            pcall(function()
                local root = getRoot()
                if root then
                    root.CFrame = CFrame.new(root.Position.X, -500, root.Position.Z)
                end
            end)
            notify("AK Admin", "Void respawn...")
        end,
        desc = "voidre - respawn via void"
    }

    commands["invis"] = {
        fn = function(args)
            -- Real invis: save pos, die, on respawn move new char to camera
            -- and use the network-owned character with all parts invisible.
            -- Other players can't see you because your parts have Transparency=1
            -- but you still exist server-side for interactions.
            if getgenv().AKAdmin_Invis then
                -- Toggle off: reset transparency
                getgenv().AKAdmin_Invis = false
                pcall(function()
                    local char = getChar()
                    if char then
                        for _, part in ipairs(char:GetDescendants()) do
                            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                                part.Transparency = 0
                            elseif part:IsA("Decal") then
                                part.Transparency = 0
                            end
                        end
                        -- Restore accessories
                        for _, acc in ipairs(char:GetChildren()) do
                            if acc:IsA("Accessory") then
                                local handle = acc:FindFirstChild("Handle")
                                if handle then handle.Transparency = 0 end
                            end
                        end
                    end
                end)
                notify("AK Admin", "Visible again")
                return
            end
            getgenv().AKAdmin_Invis = true
            pcall(function()
                local char = getChar()
                if not char then return end
                local root = char:FindFirstChild("HumanoidRootPart")
                if not root then return end
                -- Method: Make all visible parts transparent
                -- HumanoidRootPart is already invisible by default (Transparency=1)
                -- This makes you invisible to other players because character
                -- parts are replicated with their Transparency values.
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.Transparency = 1
                    elseif part:IsA("Decal") then
                        part.Transparency = 1
                    end
                end
                -- Hide accessories
                for _, acc in ipairs(char:GetChildren()) do
                    if acc:IsA("Accessory") then
                        local handle = acc:FindFirstChild("Handle")
                        if handle then handle.Transparency = 1 end
                    end
                end
                -- Hide face
                local head = char:FindFirstChild("Head")
                if head then
                    for _, d in ipairs(head:GetChildren()) do
                        if d:IsA("Decal") or d:IsA("Texture") then
                            d.Transparency = 1
                        end
                    end
                end
            end)
            notify("AK Admin", "Invisible (toggle again to undo)")
        end,
        desc = "invis - make character invisible (toggle)"
    }

    commands["reanim"] = {
        fn = function(args)
            -- Real reanim: kill real char, build fake visible char from it,
            -- control fake while dead real char replicates server-side.
            if getgenv().AKAdmin_Reanim then
                -- Toggle off: destroy fake, reset
                getgenv().AKAdmin_Reanim = false
                pcall(function()
                    if getgenv().AKAdmin_ReanimFake then
                        getgenv().AKAdmin_ReanimFake:Destroy()
                        getgenv().AKAdmin_ReanimFake = nil
                    end
                    if getgenv().AKAdmin_ReanimConns then
                        for _, c in ipairs(getgenv().AKAdmin_ReanimConns) do
                            pcall(function() c:Disconnect() end)
                        end
                        getgenv().AKAdmin_ReanimConns = nil
                    end
                end)
                -- Respawn to get a fresh real character
                pcall(function() localPlayer.Character:BreakJoints() end)
                notify("AK Admin", "Reanim disabled")
                return
            end

            getgenv().AKAdmin_Reanim = true
            getgenv().AKAdmin_ReanimConns = {}
            notify("AK Admin", "Reanim starting...")

            task.spawn(function()
                local realChar = localPlayer.Character
                if not realChar then notify("AK Admin", "No character") return end
                local realRoot = realChar:FindFirstChild("HumanoidRootPart")
                local realHum = realChar:FindFirstChildOfClass("Humanoid")
                if not realRoot or not realHum then return end

                -- Store spawn position to bring real char back later
                local spawnCF = realRoot.CFrame

                -- Step 1: Clone the character to make the fake (visible) one
                -- We need to clone BEFORE killing so we get all parts/accessories
                realChar.Archivable = true
                local fakeChar = realChar:Clone()
                realChar.Archivable = false

                -- Clean up scripts/localscripts in fake (they'd error)
                for _, obj in ipairs(fakeChar:GetDescendants()) do
                    if obj:IsA("BaseScript") then
                        obj:Destroy()
                    end
                end

                -- Remove Animator from fake humanoid (we animate manually)
                local fakeHum = fakeChar:FindFirstChildOfClass("Humanoid")
                if fakeHum then
                    local fakeAnimator = fakeHum:FindFirstChildOfClass("Animator")
                    if fakeAnimator then fakeAnimator:Destroy() end
                    -- Disable fake humanoid states so it doesn't interfere
                    fakeHum.BreakJointsOnDeath = false
                end

                local fakeRoot = fakeChar:FindFirstChild("HumanoidRootPart")
                if not fakeRoot then
                    notify("AK Admin", "Reanim failed: no root in clone")
                    getgenv().AKAdmin_Reanim = false
                    return
                end

                -- Step 2: Parent fake to workspace (NOT under Players)
                fakeChar.Name = localPlayer.Name .. "_reanim"
                fakeChar.Parent = Services.Workspace

                -- Position fake where real char was
                fakeRoot.CFrame = spawnCF

                -- Step 3: Kill the real character
                -- The dead real char stays in workspace - the server still tracks it
                realHum.Health = 0

                -- Wait for death to process
                task.wait(0.2)

                -- Step 4: Make real character invisible
                -- The real char is dead but we keep it around for server replication
                -- Hide all visual parts
                local function hideReal()
                    pcall(function()
                        for _, part in ipairs(realChar:GetDescendants()) do
                            if part:IsA("BasePart") then
                                part.Transparency = 1
                                part.CanCollide = false
                            elseif part:IsA("Decal") or part:IsA("Texture") then
                                part.Transparency = 1
                            elseif part:IsA("ParticleEmitter") or part:IsA("BillboardGui")
                                or part:IsA("SurfaceGui") or part:IsA("Fire")
                                or part:IsA("Smoke") or part:IsA("Sparkles") then
                                pcall(function() part.Enabled = false end)
                            end
                        end
                    end)
                end
                hideReal()

                -- Step 5: Set up camera to follow fake character
                pcall(function()
                    camera.CameraSubject = fakeHum or fakeChar
                end)

                -- Step 6: Sync loop - move real char's root to follow fake char
                -- This is the key: when we move the fake, the real (dead) char
                -- follows along. The server sees the real char moving, so
                -- interactions (touch, proximity) happen through the real char.
                --
                -- Also sync fake char's limb CFrames from user input movement.

                -- Make fake root unanchored and add movement forces
                local fakeBV = Instance.new("BodyVelocity")
                fakeBV.MaxForce = Vector3.new(math.huge, 0, math.huge)
                fakeBV.Velocity = Vector3.zero
                fakeBV.Parent = fakeRoot

                local fakeBG = Instance.new("BodyGyro")
                fakeBG.MaxTorque = Vector3.new(0, math.huge, 0)
                fakeBG.P = 1e4
                fakeBG.Parent = fakeRoot

                -- Gravity still applies on Y so fake walks on ground naturally

                -- Movement input -> fake character velocity
                -- Since fake humanoid isn't connected to PlayerModule,
                -- read WASD input directly via UserInputService
                local walkSpeed = 16

                local stepConn = Services.RunService.Heartbeat:Connect(function()
                    if not getgenv().AKAdmin_Reanim then return end

                    pcall(function()
                        local moveDir = Vector3.zero
                        local camCF = camera.CFrame
                        local look = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z).Unit
                        local right = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z).Unit

                        if Services.UserInputService:IsKeyDown(Enum.KeyCode.W) then
                            moveDir = moveDir + look
                        end
                        if Services.UserInputService:IsKeyDown(Enum.KeyCode.S) then
                            moveDir = moveDir - look
                        end
                        if Services.UserInputService:IsKeyDown(Enum.KeyCode.A) then
                            moveDir = moveDir - right
                        end
                        if Services.UserInputService:IsKeyDown(Enum.KeyCode.D) then
                            moveDir = moveDir + right
                        end

                        -- Apply to BodyVelocity
                        if moveDir.Magnitude > 0 then
                            fakeBV.Velocity = moveDir.Unit * walkSpeed
                            -- Face movement direction
                            fakeBG.CFrame = CFrame.lookAt(fakeRoot.Position, fakeRoot.Position + moveDir)
                        else
                            fakeBV.Velocity = Vector3.zero
                        end

                        -- Sync real char root to fake char root
                        -- Real char is dead but we CFrame it to match fake
                        if realRoot and realRoot.Parent and fakeRoot and fakeRoot.Parent then
                            realRoot.CFrame = fakeRoot.CFrame
                            realRoot.AssemblyLinearVelocity = Vector3.zero
                            realRoot.AssemblyAngularVelocity = Vector3.zero
                        end

                        -- Keep real char hidden (respawn scripts might re-show parts)
                        hideReal()
                    end)
                end)
                table.insert(getgenv().AKAdmin_ReanimConns, stepConn)

                -- Handle real character being removed/respawned
                local charConn
                charConn = localPlayer.CharacterAdded:Connect(function(newChar)
                    if not getgenv().AKAdmin_Reanim then
                        charConn:Disconnect()
                        return
                    end
                    -- New real char spawned - hide it and sync to fake
                    task.wait(0.3)
                    realChar = newChar
                    realRoot = newChar:WaitForChild("HumanoidRootPart", 5)
                    realHum = newChar:WaitForChild("Humanoid", 5)
                    if realRoot and realHum then
                        -- Kill it again
                        task.wait(0.1)
                        realHum.Health = 0
                        task.wait(0.2)
                        hideReal()
                        -- Set camera back to fake
                        pcall(function()
                            camera.CameraSubject = fakeHum or fakeChar
                        end)
                    end
                end)
                table.insert(getgenv().AKAdmin_ReanimConns, charConn)

                -- Handle jumping on fake
                local jumpConn
                jumpConn = Services.UserInputService.JumpRequest:Connect(function()
                    if not getgenv().AKAdmin_Reanim then return end
                    pcall(function()
                        if fakeHum and fakeHum:GetState() ~= Enum.HumanoidStateType.Freefall then
                            fakeRoot.AssemblyLinearVelocity = fakeRoot.AssemblyLinearVelocity + Vector3.new(0, 50, 0)
                        end
                    end)
                end)
                table.insert(getgenv().AKAdmin_ReanimConns, jumpConn)

                getgenv().AKAdmin_ReanimFake = fakeChar

                notify("AK Admin", "Reanim active - type !reanim again to disable")
            end)
        end,
        desc = "reanim - reanimate (toggle): fake visible char + dead real char for server-side replication"
    }

    commands["speed"] = {
        fn = function(args)
            local val = tonumber(splitArgs(args)[1]) or 50
            pcall(function()
                local hum = getHumanoid()
                if hum then
                    hum.WalkSpeed = val
                end
            end)
            notify("AK Admin", "Speed set to " .. tostring(val))
        end,
        desc = "speed [value] - set walkspeed"
    }

    commands["sfly"] = {
        fn = function(args)
            if getgenv().AKAdmin_Fly then
                getgenv().AKAdmin_Fly = false
                pcall(function()
                    if getgenv().AKAdmin_FlyBV then getgenv().AKAdmin_FlyBV:Destroy() end
                    if getgenv().AKAdmin_FlyBG then getgenv().AKAdmin_FlyBG:Destroy() end
                end)
                notify("AK Admin", "Fly disabled")
                return
            end
            local flySpeed = tonumber(splitArgs(args)[1]) or 50
            getgenv().AKAdmin_Fly = true
            notify("AK Admin", "Fly enabled (speed: " .. flySpeed .. ")")
            task.spawn(function()
                local root = getRoot()
                if not root then return end
                local hum = getHumanoid()
                if hum then hum.PlatformStand = true end
                local bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bv.Velocity = Vector3.zero
                bv.Parent = root
                getgenv().AKAdmin_FlyBV = bv
                local bg = Instance.new("BodyGyro")
                bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                bg.P = 9e4
                bg.Parent = root
                getgenv().AKAdmin_FlyBG = bg
                while getgenv().AKAdmin_Fly do
                    pcall(function()
                        local moveDir = Vector3.zero
                        local camCF = camera.CFrame
                        local look = camCF.LookVector
                        local right = camCF.RightVector
                        if Services.UserInputService:IsKeyDown(Enum.KeyCode.W) then
                            moveDir = moveDir + look
                        end
                        if Services.UserInputService:IsKeyDown(Enum.KeyCode.S) then
                            moveDir = moveDir - look
                        end
                        if Services.UserInputService:IsKeyDown(Enum.KeyCode.A) then
                            moveDir = moveDir - right
                        end
                        if Services.UserInputService:IsKeyDown(Enum.KeyCode.D) then
                            moveDir = moveDir + right
                        end
                        if Services.UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                            moveDir = moveDir + Vector3.new(0, 1, 0)
                        end
                        if Services.UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                            moveDir = moveDir - Vector3.new(0, 1, 0)
                        end
                        if moveDir.Magnitude > 0 then
                            bv.Velocity = moveDir.Unit * flySpeed
                        else
                            bv.Velocity = Vector3.zero
                        end
                        bg.CFrame = camCF
                    end)
                    task.wait()
                end
                pcall(function()
                    bv:Destroy()
                    bg:Destroy()
                    if hum then hum.PlatformStand = false end
                end)
            end)
        end,
        desc = "sfly [speed] - server-side fly (toggle)"
    }

    commands["walkonair"] = {
        fn = function(args)
            if getgenv().AKAdmin_WalkOnAir then
                getgenv().AKAdmin_WalkOnAir = false
                notify("AK Admin", "Walk on air disabled")
                return
            end
            getgenv().AKAdmin_WalkOnAir = true
            notify("AK Admin", "Walk on air enabled")
            task.spawn(function()
                while getgenv().AKAdmin_WalkOnAir do
                    pcall(function()
                        local root = getRoot()
                        if root then
                            local part = Instance.new("Part")
                            part.Size = Vector3.new(5, 0.5, 5)
                            part.Transparency = 1
                            part.Anchored = true
                            part.CanCollide = true
                            part.CFrame = root.CFrame * CFrame.new(0, -3, 0)
                            part.Name = "AKAdmin_AirPart"
                            part.Parent = Services.Workspace
                            task.delay(1.5, function()
                                pcall(function() part:Destroy() end)
                            end)
                        end
                    end)
                    task.wait(0.3)
                end
                -- Cleanup remaining parts
                pcall(function()
                    for _, p in ipairs(Services.Workspace:GetChildren()) do
                        if p.Name == "AKAdmin_AirPart" then p:Destroy() end
                    end
                end)
            end)
        end,
        desc = "walkonair - walk on invisible platforms (toggle)"
    }

    commands["changetor15"] = {
        fn = function(args)
            pcall(function()
                local hum = getHumanoid()
                if not hum then return end
                -- Try ApplyDescription first (works in some contexts)
                local ok = pcall(function()
                    local desc = Services.Players:GetHumanoidDescriptionFromUserId(localPlayer.UserId)
                    if desc then
                        desc.BodyTypeScale = 0.3
                        hum:ApplyDescription(desc)
                    end
                end)
                if not ok then
                    -- Fallback: check current rig type
                    if hum.RigType == Enum.HumanoidRigType.R15 then
                        notify("AK Admin", "Already R15")
                    else
                        notify("AK Admin", "Cannot change rig type client-side in this game. Try !re first.")
                    end
                end
            end)
            notify("AK Admin", "Changed to R15")
        end,
        desc = "changetor15 - switch to R15 rig"
    }

    commands["changetor6"] = {
        fn = function(args)
            pcall(function()
                local hum = getHumanoid()
                if not hum then return end
                local ok = pcall(function()
                    local desc = Services.Players:GetHumanoidDescriptionFromUserId(localPlayer.UserId)
                    if desc then
                        desc.BodyTypeScale = 0
                        hum:ApplyDescription(desc)
                    end
                end)
                if not ok then
                    if hum.RigType == Enum.HumanoidRigType.R6 then
                        notify("AK Admin", "Already R6")
                    else
                        notify("AK Admin", "Cannot change rig type client-side in this game. Try !re first.")
                    end
                end
            end)
            notify("AK Admin", "Changed to R6")
        end,
        desc = "changetor6 - switch to R6 rig"
    }

    commands["reverse"] = {
        fn = function(args)
            if getgenv().AKAdmin_Reverse then
                getgenv().AKAdmin_Reverse = false
                notify("AK Admin", "Reverse disabled")
                return
            end
            getgenv().AKAdmin_Reverse = true
            notify("AK Admin", "Reverse enabled")
            task.spawn(function()
                while getgenv().AKAdmin_Reverse do
                    pcall(function()
                        local hum = getHumanoid()
                        local root = getRoot()
                        if hum and root then
                            local moveDir = hum.MoveDirection
                            if moveDir.Magnitude > 0 then
                                root.CFrame = root.CFrame + (-moveDir * hum.WalkSpeed * 0.03)
                            end
                        end
                    end)
                    task.wait()
                end
            end)
        end,
        desc = "reverse - invert movement direction (toggle)"
    }

    ---------------------------------------------------------------------------
    -- ANIMATION COMMANDS
    ---------------------------------------------------------------------------

    commands["animcopy"] = {
        fn = function(args)
            local targetName = splitArgs(args)[1]
            if not targetName then notify("AK Admin", "Specify a player") return end
            local target = getPlayerByName(targetName)
            if not target then notify("AK Admin", "Player not found") return end
            if getgenv().AKAdmin_AnimCopy then
                getgenv().AKAdmin_AnimCopy = false
                notify("AK Admin", "Anim copy disabled")
                return
            end
            getgenv().AKAdmin_AnimCopy = true
            notify("AK Admin", "Copying animations from " .. target.Name)
            task.spawn(function()
                while getgenv().AKAdmin_AnimCopy do
                    pcall(function()
                        local tChar = target.Character
                        if not tChar then return end
                        local tHum = tChar:FindFirstChildOfClass("Humanoid")
                        if not tHum then return end
                        local tAnimator = tHum:FindFirstChildOfClass("Animator")
                        if not tAnimator then return end
                        local myHum = getHumanoid()
                        if not myHum then return end
                        local myAnimator = myHum:FindFirstChildOfClass("Animator")
                        if not myAnimator then
                            myAnimator = Instance.new("Animator")
                            myAnimator.Parent = myHum
                        end
                        -- Stop current animations
                        for _, track in ipairs(myAnimator:GetPlayingAnimationTracks()) do
                            track:Stop()
                        end
                        -- Play target's animations
                        for _, track in ipairs(tAnimator:GetPlayingAnimationTracks()) do
                            local anim = Instance.new("Animation")
                            anim.AnimationId = track.Animation.AnimationId
                            local newTrack = myAnimator:LoadAnimation(anim)
                            newTrack:Play()
                            newTrack:AdjustSpeed(track.Speed)
                        end
                    end)
                    task.wait(0.5)
                end
            end)
        end,
        desc = "animcopy [player] - continuously copy animations (toggle)"
    }

    commands["animlogger"] = {
        fn = function(args)
            if getgenv().AKAdmin_AnimLogger then
                getgenv().AKAdmin_AnimLogger = false
                notify("AK Admin", "Anim logger disabled")
                return
            end
            getgenv().AKAdmin_AnimLogger = true
            notify("AK Admin", "Anim logger enabled - check console")
            task.spawn(function()
                while getgenv().AKAdmin_AnimLogger do
                    pcall(function()
                        for _, player in ipairs(Services.Players:GetPlayers()) do
                            if player.Character then
                                local hum = player.Character:FindFirstChildOfClass("Humanoid")
                                if hum then
                                    local animator = hum:FindFirstChildOfClass("Animator")
                                    if animator then
                                        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                                            local id = track.Animation.AnimationId
                                            local key = player.Name .. "_" .. id
                                            if not getgenv().AKAdmin_LoggedAnims then
                                                getgenv().AKAdmin_LoggedAnims = {}
                                            end
                                            if not getgenv().AKAdmin_LoggedAnims[key] then
                                                getgenv().AKAdmin_LoggedAnims[key] = true
                                                print("[AnimLog] " .. player.Name .. " playing: " .. id)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end)
                    task.wait(0.5)
                end
            end)
        end,
        desc = "animlogger - log all animation IDs to console (toggle)"
    }

    commands["animrecorder"] = {
        fn = function(args)
            if getgenv().AKAdmin_AnimRecorder then
                getgenv().AKAdmin_AnimRecorder = false
                -- Output recorded animations
                local recorded = getgenv().AKAdmin_RecordedAnims or {}
                local output = "Recorded Animations:\n"
                for i, id in ipairs(recorded) do
                    output = output .. i .. ": " .. id .. "\n"
                end
                print(output)
                notify("AK Admin", "Recorder stopped. " .. #recorded .. " anims recorded (see console)")
                return
            end
            getgenv().AKAdmin_AnimRecorder = true
            getgenv().AKAdmin_RecordedAnims = {}
            notify("AK Admin", "Recording animations... type again to stop")
            task.spawn(function()
                while getgenv().AKAdmin_AnimRecorder do
                    pcall(function()
                        local myHum = getHumanoid()
                        if myHum then
                            local animator = myHum:FindFirstChildOfClass("Animator")
                            if animator then
                                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                                    local id = track.Animation.AnimationId
                                    local found = false
                                    for _, rec in ipairs(getgenv().AKAdmin_RecordedAnims) do
                                        if rec == id then found = true break end
                                    end
                                    if not found then
                                        table.insert(getgenv().AKAdmin_RecordedAnims, id)
                                    end
                                end
                            end
                        end
                    end)
                    task.wait(0.2)
                end
            end)
        end,
        desc = "animrecorder - record self animations (toggle)"
    }

    commands["caranimations"] = {
        fn = function(args)
            pcall(function()
                local char = getChar()
                if not char then return end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if not hum then return end
                -- Find VehicleSeat and trigger sitting animation exploit
                hum.Sit = true
                task.wait(0.1)
                hum.Sit = false
                -- Force car idle animation
                local animator = hum:FindFirstChildOfClass("Animator")
                if not animator then
                    animator = Instance.new("Animator")
                    animator.Parent = hum
                end
                local anim = Instance.new("Animation")
                anim.AnimationId = "rbxassetid://5918726674" -- car idle animation
                local track = animator:LoadAnimation(anim)
                track:Play()
            end)
            notify("AK Admin", "Car animations applied")
        end,
        desc = "caranimations - apply vehicle seat animation exploits"
    }

    commands["emotes"] = {
        fn = function(args)
            local emoteName = splitArgs(args)[1]
            if not emoteName then notify("AK Admin", "Specify emote name or ID") return end
            pcall(function()
                local hum = getHumanoid()
                if not hum then return end
                local animator = hum:FindFirstChildOfClass("Animator")
                if not animator then
                    animator = Instance.new("Animator")
                    animator.Parent = hum
                end
                -- Check if it's an ID
                local id = tonumber(emoteName)
                if id then
                    local anim = Instance.new("Animation")
                    anim.AnimationId = "rbxassetid://" .. tostring(id)
                    local track = animator:LoadAnimation(anim)
                    track:Play()
                else
                    -- Try built-in emotes
                    local emoteMap = {
                        wave = "rbxassetid://507770239",
                        point = "rbxassetid://507770453",
                        dance = "rbxassetid://507771019",
                        dance2 = "rbxassetid://507776043",
                        dance3 = "rbxassetid://507777268",
                        laugh = "rbxassetid://507770818",
                        cheer = "rbxassetid://507770677"
                    }
                    local animId = emoteMap[string.lower(emoteName)]
                    if animId then
                        local anim = Instance.new("Animation")
                        anim.AnimationId = animId
                        local track = animator:LoadAnimation(anim)
                        track:Play()
                    else
                        notify("AK Admin", "Unknown emote: " .. emoteName)
                    end
                end
            end)
        end,
        desc = "emotes [name/id] - play emote"
    }

    commands["ugcemotes"] = {
        fn = function(args)
            local emoteName = splitArgs(args)[1]
            if not emoteName then notify("AK Admin", "Specify UGC emote name or ID") return end
            pcall(function()
                local hum = getHumanoid()
                if not hum then return end
                local animator = hum:FindFirstChildOfClass("Animator")
                if not animator then
                    animator = Instance.new("Animator")
                    animator.Parent = hum
                end
                local id = tonumber(emoteName)
                if id then
                    local anim = Instance.new("Animation")
                    anim.AnimationId = "rbxassetid://" .. tostring(id)
                    local track = animator:LoadAnimation(anim)
                    track:Play()
                    notify("AK Admin", "Playing UGC emote " .. tostring(id))
                else
                    notify("AK Admin", "Provide a valid animation ID")
                end
            end)
        end,
        desc = "ugcemotes [id] - play UGC catalog emote"
    }

    commands["hug"] = {
        fn = function(args)
            local targets = resolveTargets(splitArgs(args)[1])
            if #targets == 0 then notify("AK Admin", "Player not found") return end
            pcall(function()
                local myRoot = getRoot()
                local tRoot = targets[1].Character:FindFirstChild("HumanoidRootPart")
                if myRoot and tRoot then
                    myRoot.CFrame = tRoot.CFrame * CFrame.new(0, 0, -2)
                    -- Play hug animation
                    local hum = getHumanoid()
                    if hum then
                        local animator = hum:FindFirstChildOfClass("Animator")
                        if not animator then
                            animator = Instance.new("Animator")
                            animator.Parent = hum
                        end
                        local anim = Instance.new("Animation")
                        anim.AnimationId = "rbxassetid://5915693819" -- hug emote
                        local track = animator:LoadAnimation(anim)
                        track:Play()
                    end
                end
            end)
            notify("AK Admin", "Hugging " .. targets[1].Name)
        end,
        desc = "hug [player] - TP to target and hug"
    }

    commands["jerk"] = {
        fn = function(args)
            local targets = resolveTargets(splitArgs(args)[1])
            if #targets == 0 then notify("AK Admin", "Player not found") return end
            pcall(function()
                local myRoot = getRoot()
                local tRoot = targets[1].Character:FindFirstChild("HumanoidRootPart")
                if myRoot and tRoot then
                    myRoot.CFrame = tRoot.CFrame * CFrame.new(0, 0, -2)
                    local hum = getHumanoid()
                    if hum then
                        local animator = hum:FindFirstChildOfClass("Animator")
                        if not animator then
                            animator = Instance.new("Animator")
                            animator.Parent = hum
                        end
                        local anim = Instance.new("Animation")
                        anim.AnimationId = "rbxassetid://4689362868" -- jerk R15 anim
                        local track = animator:LoadAnimation(anim)
                        track:Play()
                    end
                end
            end)
            notify("AK Admin", "Jerking at " .. targets[1].Name)
        end,
        desc = "jerk [player] - TP and play jerk animation"
    }

    commands["kidnap"] = {
        fn = function(args)
            local targets = resolveTargets(splitArgs(args)[1])
            if #targets == 0 then notify("AK Admin", "Player not found") return end
            if getgenv().AKAdmin_Kidnap then
                getgenv().AKAdmin_Kidnap = false
                pcall(function()
                    if getgenv().AKAdmin_KidnapWeld then
                        getgenv().AKAdmin_KidnapWeld:Destroy()
                    end
                end)
                notify("AK Admin", "Kidnap released")
                return
            end
            getgenv().AKAdmin_Kidnap = true
            pcall(function()
                local myRoot = getRoot()
                local tRoot = targets[1].Character:FindFirstChild("HumanoidRootPart")
                if myRoot and tRoot then
                    myRoot.CFrame = tRoot.CFrame * CFrame.new(0, 0, -1.5)
                    local weld = Instance.new("WeldConstraint")
                    weld.Part0 = myRoot
                    weld.Part1 = tRoot
                    weld.Parent = myRoot
                    getgenv().AKAdmin_KidnapWeld = weld
                end
            end)
            notify("AK Admin", "Kidnapping " .. targets[1].Name .. " (toggle to release)")
        end,
        desc = "kidnap [player] - weld self to target (toggle)"
    }

    commands["limborbit"] = {
        fn = function(args)
            local targets = resolveTargets(splitArgs(args)[1])
            if #targets == 0 then notify("AK Admin", "Player not found") return end
            if getgenv().AKAdmin_Orbit then
                getgenv().AKAdmin_Orbit = false
                notify("AK Admin", "Orbit disabled")
                return
            end
            getgenv().AKAdmin_Orbit = true
            local target = targets[1]
            notify("AK Admin", "Orbiting " .. target.Name)
            task.spawn(function()
                local angle = 0
                local radius = 10
                while getgenv().AKAdmin_Orbit do
                    pcall(function()
                        local myRoot = getRoot()
                        local tRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                        if myRoot and tRoot then
                            angle = angle + 5
                            if angle >= 360 then angle = 0 end
                            local rad = math.rad(angle)
                            local x = tRoot.Position.X + math.cos(rad) * radius
                            local z = tRoot.Position.Z + math.sin(rad) * radius
                            local y = tRoot.Position.Y
                            myRoot.CFrame = CFrame.lookAt(Vector3.new(x, y, z), tRoot.Position)
                        end
                    end)
                    task.wait(0.03)
                end
            end)
        end,
        desc = "limborbit [player] - orbit around target (toggle)"
    }

    commands["facebang"] = {
        fn = function(args)
            local targets = resolveTargets(splitArgs(args)[1])
            if #targets == 0 then notify("AK Admin", "Player not found") return end
            if getgenv().AKAdmin_Facebang then
                getgenv().AKAdmin_Facebang = false
                notify("AK Admin", "Facebang stopped")
                return
            end
            getgenv().AKAdmin_Facebang = true
            local target = targets[1]
            notify("AK Admin", "Facebanging " .. target.Name)
            task.spawn(function()
                local hum = getHumanoid()
                local animator = hum and hum:FindFirstChildOfClass("Animator")
                if not animator then
                    animator = Instance.new("Animator")
                    animator.Parent = hum
                end
                local anim = Instance.new("Animation")
                anim.AnimationId = "rbxassetid://4689362868"
                local track = animator:LoadAnimation(anim)
                track:Play()
                track.Looped = true
                while getgenv().AKAdmin_Facebang do
                    pcall(function()
                        local myRoot = getRoot()
                        local tRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                        if myRoot and tRoot then
                            myRoot.CFrame = tRoot.CFrame * CFrame.new(0, 0, -1.5)
                        end
                    end)
                    task.wait(0.05)
                end
                pcall(function() track:Stop() end)
            end)
        end,
        desc = "facebang [player] - face target and animate (toggle)"
    }

    commands["facebangweld"] = {
        fn = function(args)
            local targets = resolveTargets(splitArgs(args)[1])
            if #targets == 0 then notify("AK Admin", "Player not found") return end
            if getgenv().AKAdmin_FacebangWeld then
                getgenv().AKAdmin_FacebangWeld = false
                pcall(function()
                    if getgenv().AKAdmin_FBWeld then getgenv().AKAdmin_FBWeld:Destroy() end
                end)
                notify("AK Admin", "Facebang weld stopped")
                return
            end
            getgenv().AKAdmin_FacebangWeld = true
            local target = targets[1]
            pcall(function()
                local myRoot = getRoot()
                local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
                if myRoot and tRoot then
                    myRoot.CFrame = tRoot.CFrame * CFrame.new(0, 0, -1.5)
                    local weld = Instance.new("WeldConstraint")
                    weld.Part0 = myRoot
                    weld.Part1 = tRoot
                    weld.Parent = myRoot
                    getgenv().AKAdmin_FBWeld = weld
                    -- Play animation
                    local hum = getHumanoid()
                    if hum then
                        local animator = hum:FindFirstChildOfClass("Animator")
                        if not animator then
                            animator = Instance.new("Animator")
                            animator.Parent = hum
                        end
                        local anim = Instance.new("Animation")
                        anim.AnimationId = "rbxassetid://4689362868"
                        local track = animator:LoadAnimation(anim)
                        track:Play()
                        track.Looped = true
                    end
                end
            end)
            notify("AK Admin", "Facebang welded to " .. target.Name .. " (toggle)")
        end,
        desc = "facebangweld [player] - weld to face and animate (toggle)"
    }

    ---------------------------------------------------------------------------
    -- ANTI COMMANDS
    ---------------------------------------------------------------------------

    commands["antiafk"] = {
        fn = function(args)
            if getgenv().AKAdmin_AntiAFK then
                getgenv().AKAdmin_AntiAFK = false
                notify("AK Admin", "Anti-AFK disabled")
                return
            end
            getgenv().AKAdmin_AntiAFK = true
            notify("AK Admin", "Anti-AFK enabled")
            pcall(function()
                local vu = game:GetService("VirtualUser")
                localPlayer.Idled:Connect(function()
                    if getgenv().AKAdmin_AntiAFK then
                        vu:CaptureController()
                        vu:ClickButton2(Vector2.new())
                    end
                end)
            end)
        end,
        desc = "antiafk - prevent AFK kick (toggle)"
    }

    commands["antifling"] = {
        fn = function(args)
            if getgenv().AKAdmin_AntiFling then
                getgenv().AKAdmin_AntiFling = false
                notify("AK Admin", "Anti-fling disabled")
                return
            end
            getgenv().AKAdmin_AntiFling = true
            notify("AK Admin", "Anti-fling enabled")
            task.spawn(function()
                while getgenv().AKAdmin_AntiFling do
                    pcall(function()
                        local root = getRoot()
                        if root then
                            local vel = root.AssemblyLinearVelocity
                            if vel.Magnitude > 200 then
                                root.AssemblyLinearVelocity = Vector3.zero
                                root.AssemblyAngularVelocity = Vector3.zero
                            end
                        end
                    end)
                    task.wait(0.05)
                end
            end)
        end,
        desc = "antifling - counter flings (toggle)"
    }

    commands["antisit"] = {
        fn = function(args)
            if getgenv().AKAdmin_AntiSit then
                getgenv().AKAdmin_AntiSit = false
                if getgenv().AKAdmin_AntiSitConn then
                    pcall(function() getgenv().AKAdmin_AntiSitConn:Disconnect() end)
                end
                notify("AK Admin", "Anti-sit disabled")
                return
            end
            getgenv().AKAdmin_AntiSit = true
            notify("AK Admin", "Anti-sit enabled")
            task.spawn(function()
                while getgenv().AKAdmin_AntiSit do
                    pcall(function()
                        local hum = getHumanoid()
                        if hum and hum.Sit then
                            hum.Sit = false
                            hum:ChangeState(Enum.HumanoidStateType.Running)
                        end
                    end)
                    task.wait(0.1)
                end
            end)
        end,
        desc = "antisit - prevent being seated (toggle)"
    }

    commands["antislide"] = {
        fn = function(args)
            if getgenv().AKAdmin_AntiSlide then
                getgenv().AKAdmin_AntiSlide = false
                notify("AK Admin", "Anti-slide disabled")
                return
            end
            getgenv().AKAdmin_AntiSlide = true
            notify("AK Admin", "Anti-slide enabled")
            task.spawn(function()
                local lastPos = nil
                while getgenv().AKAdmin_AntiSlide do
                    pcall(function()
                        local root = getRoot()
                        local hum = getHumanoid()
                        if root and hum then
                            local state = hum:GetState()
                            if state == Enum.HumanoidStateType.Freefall then
                                -- Check if sliding (moving horizontally while falling)
                                if lastPos then
                                    local hDist = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(lastPos.X, 0, lastPos.Z)).Magnitude
                                    if hDist > 5 and hum.MoveDirection.Magnitude < 0.1 then
                                        root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
                                    end
                                end
                            end
                            lastPos = root.Position
                        end
                    end)
                    task.wait(0.1)
                end
            end)
        end,
        desc = "antislide - prevent sliding (toggle)"
    }

    commands["antivcban"] = {
        fn = function(args)
            if getgenv().AKAdmin_AntiVCBan then
                getgenv().AKAdmin_AntiVCBan = false
                notify("AK Admin", "Anti-VC ban disabled")
                return
            end
            getgenv().AKAdmin_AntiVCBan = true
            notify("AK Admin", "Anti-VC ban enabled (client-side only)")
        end,
        desc = "antivcban - anti voice chat ban (toggle)"
    }

    commands["antivoid"] = {
        fn = function(args)
            if getgenv().AKAdmin_AntiVoid then
                getgenv().AKAdmin_AntiVoid = false
                notify("AK Admin", "Anti-void disabled")
                return
            end
            getgenv().AKAdmin_AntiVoid = true
            getgenv().AKAdmin_SafePos = getRoot() and getRoot().Position or Vector3.new(0, 10, 0)
            notify("AK Admin", "Anti-void enabled")
            task.spawn(function()
                while getgenv().AKAdmin_AntiVoid do
                    pcall(function()
                        local root = getRoot()
                        if root then
                            if root.Position.Y > -50 then
                                getgenv().AKAdmin_SafePos = root.Position
                            end
                            if root.Position.Y < -100 then
                                root.CFrame = CFrame.new(getgenv().AKAdmin_SafePos)
                                root.AssemblyLinearVelocity = Vector3.zero
                            end
                        end
                    end)
                    task.wait(0.1)
                end
            end)
        end,
        desc = "antivoid - prevent void death (toggle)"
    }

    commands["antiall"] = {
        fn = function(args)
            commands["antiafk"].fn("")
            commands["antifling"].fn("")
            commands["antisit"].fn("")
            commands["antislide"].fn("")
            commands["antivoid"].fn("")
            commands["antivcban"].fn("")
            notify("AK Admin", "All anti-features toggled")
        end,
        desc = "antiall - toggle all anti-features"
    }

    ---------------------------------------------------------------------------
    -- UTILITY COMMANDS
    ---------------------------------------------------------------------------

    commands["admincheck"] = {
        fn = function(args)
            local knownAdmins = {"Adonis", "Kohls", "HD Admin", "Basic Admin", "Cmdr", "SimpleAdmin", "Person299"}
            local found = {}
            pcall(function()
                for _, desc in ipairs(Services.Workspace:GetDescendants()) do
                    for _, name in ipairs(knownAdmins) do
                        if string.find(string.lower(desc.Name), string.lower(name), 1, true) then
                            table.insert(found, desc.Name .. " (" .. desc.ClassName .. ")")
                        end
                    end
                end
                -- Check ServerScriptService (limited visibility from client)
                local sss = game:FindFirstChild("ServerScriptService")
                if sss then
                    for _, child in ipairs(sss:GetChildren()) do
                        for _, name in ipairs(knownAdmins) do
                            if string.find(string.lower(child.Name), string.lower(name), 1, true) then
                                table.insert(found, child.Name .. " (ServerScript)")
                            end
                        end
                    end
                end
            end)
            if #found > 0 then
                local msg = "Found admin scripts:\n"
                for _, f in ipairs(found) do
                    msg = msg .. "- " .. f .. "\n"
                end
                print(msg)
                notify("AK Admin", #found .. " admin script(s) found (see console)")
            else
                notify("AK Admin", "No known admin scripts found")
            end
        end,
        desc = "admincheck - scan for admin scripts"
    }

    commands["chatlogs"] = {
        fn = function(args)
            if getgenv().AKAdmin_ChatLogs then
                getgenv().AKAdmin_ChatLogs = false
                notify("AK Admin", "Chat logs disabled")
                return
            end
            getgenv().AKAdmin_ChatLogs = true
            notify("AK Admin", "Chat logs enabled - check console")
            pcall(function()
                local tcs = Services.TextChatService
                local channels = tcs:FindFirstChild("TextChannels")
                if channels then
                    for _, channel in ipairs(channels:GetChildren()) do
                        if channel:IsA("TextChannel") then
                            channel.MessageReceived:Connect(function(msg)
                                if getgenv().AKAdmin_ChatLogs then
                                    local sender = msg.TextSource and msg.TextSource.Name or "Unknown"
                                    print("[ChatLog] " .. sender .. ": " .. msg.Text)
                                end
                            end)
                        end
                    end
                end
                -- Legacy chat fallback
                local chatEvents = Services.ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
                if chatEvents then
                    local onMsg = chatEvents:FindFirstChild("OnMessageDoneFiltering")
                    if onMsg then
                        onMsg.OnClientEvent:Connect(function(data)
                            if getgenv().AKAdmin_ChatLogs then
                                print("[ChatLog] " .. tostring(data.FromSpeaker) .. ": " .. tostring(data.Message))
                            end
                        end)
                    end
                end
            end)
        end,
        desc = "chatlogs - log all messages to console (toggle)"
    }

    commands["chatcolorchanger"] = {
        fn = function(args)
            local colorName = splitArgs(args)[1]
            if not colorName then notify("AK Admin", "Specify a color (red, blue, green, etc.)") return end
            local colorMap = {
                red = Color3.fromRGB(255, 0, 0),
                blue = Color3.fromRGB(0, 0, 255),
                green = Color3.fromRGB(0, 255, 0),
                yellow = Color3.fromRGB(255, 255, 0),
                purple = Color3.fromRGB(128, 0, 128),
                pink = Color3.fromRGB(255, 105, 180),
                orange = Color3.fromRGB(255, 165, 0),
                white = Color3.fromRGB(255, 255, 255),
                black = Color3.fromRGB(0, 0, 0),
                cyan = Color3.fromRGB(0, 255, 255)
            }
            local color = colorMap[string.lower(colorName)] or Color3.fromRGB(255, 255, 255)
            pcall(function()
                -- Use TeamColor approach or BillboardGui nametag
                local char = getChar()
                if char then
                    local head = char:FindFirstChild("Head")
                    if head then
                        -- Remove existing
                        local existing = head:FindFirstChild("AKAdmin_NameColor")
                        if existing then existing:Destroy() end
                        local bb = Instance.new("BillboardGui")
                        bb.Name = "AKAdmin_NameColor"
                        bb.Adornee = head
                        bb.Size = UDim2.new(5, 0, 1, 0)
                        bb.StudsOffset = Vector3.new(0, 2, 0)
                        bb.AlwaysOnTop = true
                        bb.Parent = head
                        local label = Instance.new("TextLabel")
                        label.Size = UDim2.new(1, 0, 1, 0)
                        label.BackgroundTransparency = 1
                        label.Text = localPlayer.DisplayName
                        label.TextColor3 = color
                        label.TextScaled = true
                        label.Font = Enum.Font.GothamBold
                        label.Parent = bb
                    end
                end
            end)
            notify("AK Admin", "Chat color set to " .. colorName)
        end,
        desc = "chatcolorchanger [color] - change name color"
    }

    commands["rizzlines"] = {
        fn = function(args)
            local lines = {
                "Are you a magician? Because whenever I look at you, everyone else disappears.",
                "Do you have a map? I just got lost in your eyes.",
                "Are you a parking ticket? Because you've got 'fine' written all over you.",
                "Is your name Google? Because you have everything I've been searching for.",
                "Do you believe in love at first sight, or should I walk by again?",
                "If you were a vegetable, you'd be a cute-cumber.",
                "Are you a campfire? Because you're hot and I want s'more.",
                "Do you have a Band-Aid? Because I just scraped my knee falling for you.",
                "Is there an airport nearby, or is that just my heart taking off?",
                "Are you a time traveler? Because I can see you in my future.",
                "If beauty were time, you'd be an eternity.",
                "I must be a snowflake, because I've fallen for you.",
                "Are you made of copper and tellurium? Because you're Cu-Te.",
                "Do you have a sunburn, or are you always this hot?",
                "I'm not a photographer, but I can picture us together."
            }
            local line = lines[math.random(1, #lines)]
            sendChat(line)
            notify("AK Admin", "Sent: " .. string.sub(line, 1, 40) .. "...")
        end,
        desc = "rizzlines - send a random pickup line in chat"
    }

    commands["spotify"] = {
        fn = function(args)
            pcall(function()
                -- Check for existing GUI
                local pg = localPlayer:FindFirstChild("PlayerGui")
                if not pg then return end
                local existing = pg:FindFirstChild("AKAdmin_Spotify")
                if existing then existing:Destroy() return end
                -- Create music player GUI
                local gui = Instance.new("ScreenGui")
                gui.Name = "AKAdmin_Spotify"
                gui.ResetOnSpawn = false
                gui.Parent = pg
                local frame = Instance.new("Frame")
                frame.Size = UDim2.new(0, 300, 0, 180)
                frame.Position = UDim2.new(0.5, -150, 0.5, -90)
                frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                frame.BorderSizePixel = 0
                frame.Parent = gui
                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(0, 8)
                corner.Parent = frame
                local title = Instance.new("TextLabel")
                title.Size = UDim2.new(1, 0, 0, 30)
                title.BackgroundTransparency = 1
                title.Text = "AK Music Player"
                title.TextColor3 = Color3.fromRGB(30, 215, 96)
                title.Font = Enum.Font.GothamBold
                title.TextSize = 16
                title.Parent = frame
                local input = Instance.new("TextBox")
                input.Size = UDim2.new(0.8, 0, 0, 30)
                input.Position = UDim2.new(0.1, 0, 0, 40)
                input.PlaceholderText = "Enter Sound ID..."
                input.Text = ""
                input.TextColor3 = Color3.fromRGB(255, 255, 255)
                input.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                input.Font = Enum.Font.Gotham
                input.TextSize = 14
                input.ClearTextOnFocus = false
                input.Parent = frame
                local inputCorner = Instance.new("UICorner")
                inputCorner.CornerRadius = UDim.new(0, 4)
                inputCorner.Parent = input
                local sound = Instance.new("Sound")
                sound.Name = "AKAdmin_Music"
                sound.Parent = Services.SoundService
                sound.Volume = 0.5
                sound.Looped = true
                local playBtn = Instance.new("TextButton")
                playBtn.Size = UDim2.new(0.35, 0, 0, 30)
                playBtn.Position = UDim2.new(0.1, 0, 0, 85)
                playBtn.Text = "Play"
                playBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                playBtn.BackgroundColor3 = Color3.fromRGB(30, 215, 96)
                playBtn.Font = Enum.Font.GothamBold
                playBtn.TextSize = 14
                playBtn.Parent = frame
                local playCorner = Instance.new("UICorner")
                playCorner.CornerRadius = UDim.new(0, 4)
                playCorner.Parent = playBtn
                local stopBtn = Instance.new("TextButton")
                stopBtn.Size = UDim2.new(0.35, 0, 0, 30)
                stopBtn.Position = UDim2.new(0.55, 0, 0, 85)
                stopBtn.Text = "Stop"
                stopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                stopBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
                stopBtn.Font = Enum.Font.GothamBold
                stopBtn.TextSize = 14
                stopBtn.Parent = frame
                local stopCorner = Instance.new("UICorner")
                stopCorner.CornerRadius = UDim.new(0, 4)
                stopCorner.Parent = stopBtn
                local closeBtn = Instance.new("TextButton")
                closeBtn.Size = UDim2.new(0, 25, 0, 25)
                closeBtn.Position = UDim2.new(1, -30, 0, 5)
                closeBtn.Text = "X"
                closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
                closeBtn.Font = Enum.Font.GothamBold
                closeBtn.TextSize = 14
                closeBtn.Parent = frame
                local closeCorner = Instance.new("UICorner")
                closeCorner.CornerRadius = UDim.new(0, 4)
                closeCorner.Parent = closeBtn
                -- Volume slider label
                local volLabel = Instance.new("TextLabel")
                volLabel.Size = UDim2.new(0.8, 0, 0, 20)
                volLabel.Position = UDim2.new(0.1, 0, 0, 125)
                volLabel.BackgroundTransparency = 1
                volLabel.Text = "Volume: 50%"
                volLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
                volLabel.Font = Enum.Font.Gotham
                volLabel.TextSize = 12
                volLabel.Parent = frame
                -- Connections
                playBtn.MouseButton1Click:Connect(function()
                    local id = tonumber(input.Text)
                    if id then
                        sound.SoundId = "rbxassetid://" .. tostring(id)
                        sound:Play()
                    end
                end)
                stopBtn.MouseButton1Click:Connect(function()
                    sound:Stop()
                end)
                closeBtn.MouseButton1Click:Connect(function()
                    sound:Stop()
                    sound:Destroy()
                    gui:Destroy()
                end)
                -- Make draggable
                local dragging, dragInput, dragStart, startPos
                frame.InputBegan:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = true
                        dragStart = inp.Position
                        startPos = frame.Position
                        inp.Changed:Connect(function()
                            if inp.UserInputState == Enum.UserInputState.End then
                                dragging = false
                            end
                        end)
                    end
                end)
                frame.InputChanged:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseMovement then
                        dragInput = inp
                    end
                end)
                Services.UserInputService.InputChanged:Connect(function(inp)
                    if inp == dragInput and dragging then
                        local delta = inp.Position - dragStart
                        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
                    end
                end)
            end)
            notify("AK Admin", "Music player opened")
        end,
        desc = "spotify - open music player GUI"
    }

    commands["skymaster"] = {
        fn = function(args)
            local preset = splitArgs(args)[1] or "night"
            pcall(function()
                -- Remove existing sky
                for _, child in ipairs(Services.Lighting:GetChildren()) do
                    if child:IsA("Sky") then child:Destroy() end
                end
                local presets = {
                    night = {ClockTime = 0, Ambient = Color3.fromRGB(30, 30, 50)},
                    day = {ClockTime = 14, Ambient = Color3.fromRGB(180, 180, 180)},
                    sunset = {ClockTime = 18, Ambient = Color3.fromRGB(200, 100, 50)},
                    midnight = {ClockTime = 0, Ambient = Color3.fromRGB(10, 10, 30)},
                    dawn = {ClockTime = 6, Ambient = Color3.fromRGB(150, 120, 100)},
                    noon = {ClockTime = 12, Ambient = Color3.fromRGB(200, 200, 200)},
                    dark = {ClockTime = 0, Ambient = Color3.fromRGB(0, 0, 0)},
                    red = {ClockTime = 18, Ambient = Color3.fromRGB(255, 0, 0)}
                }
                local p = presets[string.lower(preset)]
                if p then
                    Services.Lighting.ClockTime = p.ClockTime
                    Services.Lighting.Ambient = p.Ambient
                else
                    Services.Lighting.ClockTime = 0
                    Services.Lighting.Ambient = Color3.fromRGB(30, 30, 50)
                end
            end)
            notify("AK Admin", "Skybox set to " .. preset)
        end,
        desc = "skymaster [preset] - change lighting/sky"
    }

    commands["shaders"] = {
        fn = function(args)
            local preset = splitArgs(args)[1] or "cinematic"
            pcall(function()
                -- Remove existing effects
                for _, child in ipairs(Services.Lighting:GetChildren()) do
                    if child:IsA("PostEffect") and string.find(child.Name, "AKAdmin") then
                        child:Destroy()
                    end
                end
                if string.lower(preset) == "off" or string.lower(preset) == "none" then
                    notify("AK Admin", "Shaders removed")
                    return
                end
                local presetData = {}
                presetData["cinematic"] = function()
                    local cc = Instance.new("ColorCorrectionEffect")
                    cc.Name = "AKAdmin_CC"
                    cc.Brightness = 0.05
                    cc.Contrast = 0.2
                    cc.Saturation = -0.1
                    cc.TintColor = Color3.fromRGB(255, 240, 220)
                    cc.Parent = Services.Lighting
                    local bloom = Instance.new("BloomEffect")
                    bloom.Name = "AKAdmin_Bloom"
                    bloom.Intensity = 0.3
                    bloom.Size = 24
                    bloom.Threshold = 0.9
                    bloom.Parent = Services.Lighting
                end
                presetData["neon"] = function()
                    local cc = Instance.new("ColorCorrectionEffect")
                    cc.Name = "AKAdmin_CC"
                    cc.Brightness = 0.1
                    cc.Contrast = 0.4
                    cc.Saturation = 0.5
                    cc.Parent = Services.Lighting
                    local bloom = Instance.new("BloomEffect")
                    bloom.Name = "AKAdmin_Bloom"
                    bloom.Intensity = 0.8
                    bloom.Size = 40
                    bloom.Threshold = 0.6
                    bloom.Parent = Services.Lighting
                end
                presetData["horror"] = function()
                    local cc = Instance.new("ColorCorrectionEffect")
                    cc.Name = "AKAdmin_CC"
                    cc.Brightness = -0.1
                    cc.Contrast = 0.3
                    cc.Saturation = -0.8
                    cc.TintColor = Color3.fromRGB(200, 200, 255)
                    cc.Parent = Services.Lighting
                end
                presetData["warm"] = function()
                    local cc = Instance.new("ColorCorrectionEffect")
                    cc.Name = "AKAdmin_CC"
                    cc.Brightness = 0.05
                    cc.Contrast = 0.1
                    cc.Saturation = 0.1
                    cc.TintColor = Color3.fromRGB(255, 220, 180)
                    cc.Parent = Services.Lighting
                    local sun = Instance.new("SunRaysEffect")
                    sun.Name = "AKAdmin_Sun"
                    sun.Intensity = 0.1
                    sun.Spread = 0.5
                    sun.Parent = Services.Lighting
                end
                presetData["vaporwave"] = function()
                    local cc = Instance.new("ColorCorrectionEffect")
                    cc.Name = "AKAdmin_CC"
                    cc.Brightness = 0.05
                    cc.Contrast = 0.2
                    cc.Saturation = 0.4
                    cc.TintColor = Color3.fromRGB(255, 150, 255)
                    cc.Parent = Services.Lighting
                    local bloom = Instance.new("BloomEffect")
                    bloom.Name = "AKAdmin_Bloom"
                    bloom.Intensity = 0.5
                    bloom.Size = 30
                    bloom.Threshold = 0.7
                    bloom.Parent = Services.Lighting
                end
                local fn = presetData[string.lower(preset)]
                if fn then
                    fn()
                else
                    -- Default to cinematic
                    presetData["cinematic"]()
                end
            end)
            notify("AK Admin", "Shaders: " .. preset)
        end,
        desc = "shaders [preset] - apply visual effects"
    }

    commands["pinghop"] = {
        fn = function(args)
            -- Roblox API doesn't expose ping per-server, so we hop to
            -- the least populated server (fewer players = usually less lag)
            local maxPlayers = tonumber(splitArgs(args)[1]) or 10
            notify("AK Admin", "Finding server with <" .. maxPlayers .. " players...")
            task.spawn(function()
                pcall(function()
                    local placeId = game.PlaceId
                    local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
                    local response = game:HttpGet(url)
                    local data = Services.HttpService:JSONDecode(response)
                    if data and data.data then
                        for _, server in ipairs(data.data) do
                            if server.playing and server.playing > 0
                               and server.playing <= maxPlayers
                               and server.playing < server.maxPlayers
                               and server.id ~= game.JobId then
                                Services.TeleportService:TeleportToPlaceInstance(placeId, server.id)
                                notify("AK Admin", "Hopping to server (" .. server.playing .. " players)")
                                return
                            end
                        end
                        -- Fallback: any server with fewer players than current
                        for _, server in ipairs(data.data) do
                            if server.playing and server.playing < server.maxPlayers and server.id ~= game.JobId then
                                Services.TeleportService:TeleportToPlaceInstance(placeId, server.id)
                                notify("AK Admin", "Hopping to available server")
                                return
                            end
                        end
                    end
                    notify("AK Admin", "No suitable server found")
                end)
            end)
        end,
        desc = "pinghop [max_players] - hop to low-population server"
    }

    commands["positionsaver"] = {
        fn = function(args)
            local split = splitArgs(args)
            local action = split[1]
            local name = split[2]
            if not getgenv().AKAdmin_SavedPositions then
                getgenv().AKAdmin_SavedPositions = {}
            end
            if not action then
                notify("AK Admin", "Usage: positionsaver save/load/list [name]")
                return
            end
            action = string.lower(action)
            if action == "save" then
                local root = getRoot()
                if not root then notify("AK Admin", "No character") return end
                local saveName = name or "default"
                getgenv().AKAdmin_SavedPositions[saveName] = root.CFrame
                notify("AK Admin", "Saved position: " .. saveName)
            elseif action == "load" then
                local saveName = name or "default"
                local saved = getgenv().AKAdmin_SavedPositions[saveName]
                if saved then
                    local root = getRoot()
                    if root then
                        root.CFrame = saved
                        notify("AK Admin", "Loaded position: " .. saveName)
                    end
                else
                    notify("AK Admin", "No saved position: " .. saveName)
                end
            elseif action == "list" then
                local list = ""
                for k, _ in pairs(getgenv().AKAdmin_SavedPositions) do
                    list = list .. k .. ", "
                end
                if list == "" then
                    notify("AK Admin", "No saved positions")
                else
                    notify("AK Admin", "Saved: " .. list)
                end
            end
        end,
        desc = "positionsaver [save/load/list] [name]"
    }

    commands["mobileshiftlock"] = {
        fn = function(args)
            pcall(function()
                local success, _ = pcall(function()
                    local playerModule = localPlayer.PlayerScripts:FindFirstChild("PlayerModule")
                    if playerModule then
                        local camModule = require(playerModule):GetCameras()
                        if camModule then
                            camModule:SetShiftLock(true)
                        end
                    end
                end)
                if not success then
                    -- Alternative method
                    Services.UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
                    local settings = UserSettings()
                    local gameSettings = settings:GetService("UserGameSettings")
                    gameSettings.RotationType = Enum.RotationType.CameraRelative
                end
            end)
            notify("AK Admin", "Shift lock enabled")
        end,
        desc = "mobileshiftlock - enable shift lock on mobile"
    }

    commands["infbaseplate"] = {
        fn = function(args)
            pcall(function()
                local existing = Services.Workspace:FindFirstChild("AKAdmin_Baseplate")
                if existing then existing:Destroy() end
                local plate = Instance.new("Part")
                plate.Name = "AKAdmin_Baseplate"
                plate.Size = Vector3.new(10000, 1, 10000)
                plate.Position = Vector3.new(0, -0.5, 0)
                plate.Anchored = true
                plate.Transparency = 0.8
                plate.Material = Enum.Material.SmoothPlastic
                plate.BrickColor = BrickColor.new("Medium stone grey")
                plate.CanCollide = true
                plate.Parent = Services.Workspace
            end)
            notify("AK Admin", "Infinite baseplate created")
        end,
        desc = "infbaseplate - create massive baseplate"
    }

    commands["naturaldisastergodmode"] = {
        fn = function(args)
            pcall(function()
                local char = getChar()
                if not char then return end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.MaxHealth = math.huge
                    hum.Health = math.huge
                end
                -- Add ForceField
                local existing = char:FindFirstChild("AKAdmin_FF")
                if not existing then
                    local ff = Instance.new("ForceField")
                    ff.Name = "AKAdmin_FF"
                    ff.Visible = false
                    ff.Parent = char
                end
            end)
            notify("AK Admin", "Godmode enabled for Natural Disaster Survival")
        end,
        desc = "naturaldisastergodmode - godmode for NDS"
    }

    commands["autoclick"] = {
        fn = function(args)
            local cps = tonumber(splitArgs(args)[1]) or 20
            if getgenv().AKAdmin_AutoClick then
                getgenv().AKAdmin_AutoClick = false
                notify("AK Admin", "Auto-click disabled")
                return
            end
            getgenv().AKAdmin_AutoClick = true
            notify("AK Admin", "Auto-click enabled at " .. cps .. " CPS")
            task.spawn(function()
                local delay = 1 / cps
                while getgenv().AKAdmin_AutoClick do
                    pcall(function()
                        -- Use VirtualInputManager if available
                        local vim = game:GetService("VirtualInputManager")
                        vim:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                        vim:SendMouseButtonEvent(0, 0, 0, false, game, 0)
                    end)
                    task.wait(delay)
                end
            end)
        end,
        desc = "autoclick [cps] - auto click at CPS (toggle)"
    }

    commands["aitools"] = {
        fn = function(args)
            pcall(function()
                local iyUrl = "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"
                loadstring(game:HttpGet(iyUrl))()
            end)
            notify("AK Admin", "AI Tools (InfiniteYield) loaded")
        end,
        desc = "aitools - load InfiniteYield admin"
    }

    commands["ad"] = {
        fn = function(args)
            local adMessages = {
                "[AK Admin] The best free admin panel! Join our Discord for updates!",
                "[AK Admin] Try !sfly, !fling, !esp and 70+ more commands!",
                "[AK Admin] AK Admin - Powered by Volt Executor"
            }
            local msg = adMessages[math.random(1, #adMessages)]
            sendChat(msg)
            notify("AK Admin", "Ad sent!")
        end,
        desc = "ad - send AK Admin advertisement"
    }

    commands["shlowest"] = {
        fn = function(args)
            notify("AK Admin", "Finding lowest population server...")
            task.spawn(function()
                pcall(function()
                    local placeId = game.PlaceId
                    local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
                    local response = game:HttpGet(url)
                    local data = Services.HttpService:JSONDecode(response)
                    if data and data.data then
                        local best = nil
                        local bestPlayers = math.huge
                        for _, server in ipairs(data.data) do
                            if server.playing and server.playing < bestPlayers and server.playing > 0 and server.id ~= game.JobId then
                                best = server
                                bestPlayers = server.playing
                            end
                        end
                        if best then
                            notify("AK Admin", "Hopping to server with " .. best.playing .. " players")
                            Services.TeleportService:TeleportToPlaceInstance(placeId, best.id)
                        else
                            notify("AK Admin", "No suitable server found")
                        end
                    end
                end)
            end)
        end,
        desc = "shlowest - hop to lowest population server"
    }

    commands["shmost"] = {
        fn = function(args)
            notify("AK Admin", "Finding most populated server...")
            task.spawn(function()
                pcall(function()
                    local placeId = game.PlaceId
                    local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Desc&limit=100"
                    local response = game:HttpGet(url)
                    local data = Services.HttpService:JSONDecode(response)
                    if data and data.data then
                        local best = nil
                        local bestPlayers = 0
                        for _, server in ipairs(data.data) do
                            if server.playing and server.playing > bestPlayers and server.playing < server.maxPlayers and server.id ~= game.JobId then
                                best = server
                                bestPlayers = server.playing
                            end
                        end
                        if best then
                            notify("AK Admin", "Hopping to server with " .. best.playing .. " players")
                            Services.TeleportService:TeleportToPlaceInstance(placeId, best.id)
                        else
                            notify("AK Admin", "No suitable server found")
                        end
                    end
                end)
            end)
        end,
        desc = "shmost - hop to most populated server"
    }

    commands["ownercmdbar"] = {
        fn = function(args)
            pcall(function()
                loadstring(game:HttpGet("https://ib2.dev/absent/lua/ownercmdbar.lua"))()
            end)
            notify("AK Admin", "Owner command bar loaded")
        end,
        desc = "ownercmdbar - load owner command bar"
    }

    ---------------------------------------------------------------------------
    -- INLINE COMMANDS
    ---------------------------------------------------------------------------

    commands["iy"] = {
        fn = function(args)
            pcall(function()
                loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
            end)
            notify("AK Admin", "InfiniteYield loaded")
        end,
        desc = "iy - load InfiniteYield"
    }

    commands["esp"] = {
        fn = function(args)
            if getgenv().AKAdmin_ESP then
                getgenv().AKAdmin_ESP = false
                -- Clean up
                pcall(function()
                    for _, player in ipairs(Services.Players:GetPlayers()) do
                        if player.Character then
                            local hl = player.Character:FindFirstChild("AKAdmin_ESP")
                            if hl then hl:Destroy() end
                        end
                    end
                end)
                if getgenv().AKAdmin_ESPConn then
                    pcall(function() getgenv().AKAdmin_ESPConn:Disconnect() end)
                end
                notify("AK Admin", "ESP disabled")
                return
            end
            getgenv().AKAdmin_ESP = true
            notify("AK Admin", "ESP enabled")
            local function applyESP(player)
                if player == localPlayer then return end
                pcall(function()
                    if player.Character and not player.Character:FindFirstChild("AKAdmin_ESP") then
                        local highlight = Instance.new("Highlight")
                        highlight.Name = "AKAdmin_ESP"
                        highlight.FillTransparency = 0.5
                        highlight.OutlineTransparency = 0
                        highlight.FillColor = Color3.fromRGB(255, 0, 0)
                        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                        highlight.Parent = player.Character
                    end
                end)
            end
            for _, player in ipairs(Services.Players:GetPlayers()) do
                applyESP(player)
                pcall(function()
                    player.CharacterAdded:Connect(function()
                        if getgenv().AKAdmin_ESP then
                            task.wait(0.5)
                            applyESP(player)
                        end
                    end)
                end)
            end
            getgenv().AKAdmin_ESPConn = Services.Players.PlayerAdded:Connect(function(player)
                if not getgenv().AKAdmin_ESP then return end
                player.CharacterAdded:Connect(function()
                    if getgenv().AKAdmin_ESP then
                        task.wait(0.5)
                        applyESP(player)
                    end
                end)
                applyESP(player)
            end)
        end,
        desc = "esp - toggle ESP highlights on all players"
    }

    commands["godmode"] = {
        fn = function(args)
            pcall(function()
                local hum = getHumanoid()
                if hum then
                    hum.MaxHealth = math.huge
                    hum.Health = math.huge
                end
            end)
            notify("AK Admin", "Godmode enabled")
        end,
        desc = "godmode - set infinite health"
    }

    commands["antiaim"] = {
        fn = function(args)
            if getgenv().AKAdmin_AntiAim then
                getgenv().AKAdmin_AntiAim = false
                notify("AK Admin", "Anti-aim disabled")
                return
            end
            getgenv().AKAdmin_AntiAim = true
            notify("AK Admin", "Anti-aim enabled")
            task.spawn(function()
                while getgenv().AKAdmin_AntiAim do
                    pcall(function()
                        local root = getRoot()
                        if root then
                            root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(math.random(0, 360)), 0)
                        end
                    end)
                    task.wait(0.05)
                end
            end)
        end,
        desc = "antiaim - randomize rotation rapidly (toggle)"
    }

    commands["antikidnap"] = {
        fn = function(args)
            if getgenv().AKAdmin_AntiKidnap then
                getgenv().AKAdmin_AntiKidnap = false
                notify("AK Admin", "Anti-kidnap disabled")
                return
            end
            getgenv().AKAdmin_AntiKidnap = true
            notify("AK Admin", "Anti-kidnap enabled")
            task.spawn(function()
                local lastPos = nil
                while getgenv().AKAdmin_AntiKidnap do
                    pcall(function()
                        local root = getRoot()
                        if root then
                            if lastPos and (root.Position - lastPos).Magnitude > 50 then
                                root.CFrame = CFrame.new(lastPos)
                                root.AssemblyLinearVelocity = Vector3.zero
                            end
                            lastPos = root.Position
                        end
                    end)
                    task.wait(0.1)
                end
            end)
        end,
        desc = "antikidnap - detect large teleports and TP back (toggle)"
    }

    commands["colbring"] = {
        fn = function(args)
            local targets = resolveTargets(splitArgs(args)[1])
            if #targets == 0 then notify("AK Admin", "Player not found") return end
            pcall(function()
                setsimulationradius(math.huge)
            end)
            local myRoot = getRoot()
            if not myRoot then return end
            for _, target in ipairs(targets) do
                pcall(function()
                    if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                        local tRoot = target.Character.HumanoidRootPart
                        tRoot.CFrame = myRoot.CFrame * CFrame.new(0, 0, -3)
                        -- Add highlight effect
                        local existing = target.Character:FindFirstChild("AKAdmin_ColBring")
                        if existing then existing:Destroy() end
                        local hl = Instance.new("Highlight")
                        hl.Name = "AKAdmin_ColBring"
                        hl.FillColor = Color3.fromRGB(0, 255, 0)
                        hl.OutlineColor = Color3.fromRGB(255, 255, 0)
                        hl.FillTransparency = 0.3
                        hl.Parent = target.Character
                        task.delay(3, function()
                            pcall(function() hl:Destroy() end)
                        end)
                    end
                end)
            end
            notify("AK Admin", "Color-brought player(s)")
        end,
        desc = "colbring [player] - bring with highlight effect"
    }

    ---------------------------------------------------------------------------
    -- ALIASES
    ---------------------------------------------------------------------------
    commands["possaver"] = commands["positionsaver"]
    commands["chatcolor"] = commands["chatcolorchanger"]
    commands["caranims"] = commands["caranimations"]
    commands["autoclicker"] = commands["autoclick"]
    commands["facebang2"] = commands["facebangweld"]
    commands["shiftlock"] = commands["mobileshiftlock"]
    commands["r6"] = commands["changetor6"]
    commands["r15"] = commands["changetor15"]

    ---------------------------------------------------------------------------
    -- Store references for the loader
    ---------------------------------------------------------------------------
    getgenv().AKAdmin_Commands = commands
    getgenv().AKAdmin_Helpers = {
        getnearest = getnearest,
        getfurthest = getfurthest,
        checkIfDead = checkIfDead,
        getPlayerByName = getPlayerByName,
        notify = notify,
        resolveTargets = resolveTargets,
        splitArgs = splitArgs,
        getChar = getChar,
        getRoot = getRoot,
        getHumanoid = getHumanoid,
        sendChat = sendChat
    }
    getgenv().AKAdmin_Descendants = descendants
    getgenv().AKAdmin_ServerTime = serverTime
    getgenv().AKAdmin_Hash = hash

    ---------------------------------------------------------------------------
    -- Return command table
    ---------------------------------------------------------------------------
    return commands
end)(...)
