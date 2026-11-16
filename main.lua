--[[
    Unnamed Enhancements V4 — standalone
    Built by Olivia — https://discord.gg/ojailbreaks
    Single-file. No external UI library required.
    loadstring(game:HttpGet("..."))()
--]]

-------------------------------------------------
-- 0. kill previous instance cleanly
-------------------------------------------------
if getgenv().UEV4 and getgenv().UEV4.Unload then
    pcall(getgenv().UEV4.Unload)
end

local HttpService      = game:GetService("HttpService")
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")
local Workspace        = game:GetService("Workspace")
local VirtualInput     = game:GetService("VirtualInputManager")
local CoreGui          = game:GetService("CoreGui")
local Camera           = Workspace.CurrentCamera
local LP               = Players.LocalPlayer

local V4 = {
    Opt    = {},                  -- { key = value }
    Tog    = {},                  -- { key = bool }
    Keys   = {},                  -- { key = { k = Enum.KeyCode or "MB1"/"MB2", mode = "Hold"|"Toggle"|"Always", state = false } }
    Conns  = {},
    Draws  = {},
    Ghosts = {},
    ESP    = {},
    State  = {
        target       = nil,
        aimPos       = nil,
        hitChance    = 0,
        lastShot     = 0,
        lastSwitch   = 0,
        shotsBucket  = {},
        lastKillAt   = 0,
        desyncYaw    = 0,
        onShotUntil  = 0,
        defUntil     = 0,
        aaSide       = 1,
        resolver     = {},
        backtrack    = {},
        selfPath     = {},
        stats        = {shots=0, hits=0, kills=0, start=os.clock()},
        chokeCounter = 0,
        choke        = 0,
    }
}
getgenv().UEV4 = V4

local function addConn(c) table.insert(V4.Conns, c) return c end
local function addDraw(d) table.insert(V4.Draws, d) return d end

-------------------------------------------------
-- 1. theme + ui factory (pure roblox gui)
-------------------------------------------------
local THEME = {
    bg       = Color3.fromRGB(14,14,18),
    panel    = Color3.fromRGB(20,20,26),
    panel2   = Color3.fromRGB(26,26,34),
    stroke   = Color3.fromRGB(45,45,58),
    text     = Color3.fromRGB(235,235,240),
    sub      = Color3.fromRGB(150,150,165),
    accent   = Color3.fromRGB(190,100,255),  -- violet
    accent2  = Color3.fromRGB(255,80,180),   -- pink
    good     = Color3.fromRGB(80,230,160),
    bad      = Color3.fromRGB(255,90,110),
    font     = Enum.Font.GothamSemibold,
    fontBold = Enum.Font.GothamBold,
    fontMono = Enum.Font.Code,
}

local function new(cls, props)
    local i = Instance.new(cls)
    for k,v in pairs(props or {}) do i[k] = v end
    return i
end
local function corner(p, r) new("UICorner",{CornerRadius=UDim.new(0,r or 6),Parent=p}) end
local function stroke(p, c, t) new("UIStroke",{Color=c or THEME.stroke,Thickness=t or 1,Parent=p,ApplyStrokeMode=Enum.ApplyStrokeMode.Border}) end
local function pad(p, n)  new("UIPadding",{PaddingLeft=UDim.new(0,n),PaddingRight=UDim.new(0,n),PaddingTop=UDim.new(0,n),PaddingBottom=UDim.new(0,n),Parent=p}) end

-- parent to CoreGui or PlayerGui w/ fallback
local function parentGui(gui)
    gui.Name = "UEV4_"..math.random(100000,999999)
    local ok = pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(gui) end
        if gethui then gui.Parent = gethui()
        else gui.Parent = CoreGui end
    end)
    if not ok then gui.Parent = LP:WaitForChild("PlayerGui") end
end

local Screen = new("ScreenGui",{IgnoreGuiInset=true,ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
parentGui(Screen)

-- root window
local Root = new("Frame",{
    Size=UDim2.fromOffset(820,540),
    Position=UDim2.new(0.5,-410,0.5,-270),
    BackgroundColor3=THEME.bg,
    BorderSizePixel=0, Parent=Screen,
})
corner(Root,10); stroke(Root, THEME.accent, 1)

local titleBar = new("Frame",{Size=UDim2.new(1,0,0,42),BackgroundColor3=THEME.panel,BorderSizePixel=0,Parent=Root})
corner(titleBar,10)
new("Frame",{Size=UDim2.new(1,0,0,18),Position=UDim2.new(0,0,1,-18),BackgroundColor3=THEME.panel,BorderSizePixel=0,Parent=titleBar})
local titleTxt = new("TextLabel",{
    Size=UDim2.new(1,-20,1,0), Position=UDim2.new(0,16,0,0),
    BackgroundTransparency=1, Text="Unnamed Enhancements V4   •   built by olivia   •   discord.gg/ojailbreaks",
    TextColor3=THEME.text, Font=THEME.fontBold, TextSize=14, TextXAlignment=Enum.TextXAlignment.Left, Parent=titleBar,
})
local accentLine = new("Frame",{
    Size=UDim2.new(1,-20,0,2), Position=UDim2.new(0,10,1,-2),
    BackgroundColor3=THEME.accent, BorderSizePixel=0, Parent=titleBar,
})
-- accent gradient
local grad = new("UIGradient",{
    Color=ColorSequence.new{
        ColorSequenceKeypoint.new(0, THEME.accent),
        ColorSequenceKeypoint.new(1, THEME.accent2),
    },
    Parent=accentLine,
})

-- draggable
local dragging, dragStart, startPos
titleBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging=true; dragStart=i.Position; startPos=Root.Position
        i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dragging=false end end)
    end
end)
addConn(UserInputService.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
        local d = i.Position - dragStart
        Root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
    end
end))

-- tab bar (left)
local tabBar = new("Frame",{
    Size=UDim2.new(0,160,1,-52), Position=UDim2.new(0,8,0,46),
    BackgroundColor3=THEME.panel, BorderSizePixel=0, Parent=Root,
})
corner(tabBar,8)
local tabList = new("UIListLayout",{Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder,Parent=tabBar})
pad(tabBar,8)

-- content area (right)
local content = new("Frame",{
    Size=UDim2.new(1,-180,1,-52), Position=UDim2.new(0,172,0,46),
    BackgroundColor3=THEME.panel, BorderSizePixel=0, Parent=Root,
})
corner(content,8); pad(content,10)

local pages = {}
local currentPage
local function newTab(name)
    local btn = new("TextButton",{
        Size=UDim2.new(1,0,0,30), BackgroundColor3=THEME.panel2,
        Text=name, TextColor3=THEME.sub, Font=THEME.font, TextSize=13,
        AutoButtonColor=false, BorderSizePixel=0, Parent=tabBar,
    })
    corner(btn,6)
    local page = new("ScrollingFrame",{
        Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
        ScrollBarThickness=4, ScrollBarImageColor3=THEME.accent,
        CanvasSize=UDim2.new(0,0,0,0), Visible=false, Parent=content,
        AutomaticCanvasSize=Enum.AutomaticSize.Y,
    })
    local pageGrid = new("UIListLayout",{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder,Parent=page,FillDirection=Enum.FillDirection.Horizontal,Wraps=true})
    pages[name] = page
    btn.MouseButton1Click:Connect(function()
        for n,p in pairs(pages) do p.Visible = (n==name) end
        for _,c in ipairs(tabBar:GetChildren()) do
            if c:IsA("TextButton") then c.BackgroundColor3=THEME.panel2; c.TextColor3=THEME.sub end
        end
        btn.BackgroundColor3 = THEME.accent
        btn.TextColor3 = Color3.new(1,1,1)
        currentPage = page
    end)
    return page, btn
end

local function newSection(page, title)
    local box = new("Frame",{
        Size=UDim2.new(0.5,-6,0,0), BackgroundColor3=THEME.panel2, BorderSizePixel=0,
        AutomaticSize=Enum.AutomaticSize.Y, Parent=page,
    })
    corner(box,8); stroke(box,THEME.stroke,1); pad(box,10)
    new("TextLabel",{Size=UDim2.new(1,0,0,18),BackgroundTransparency=1,Text=title,Font=THEME.fontBold,TextSize=13,TextColor3=THEME.accent,TextXAlignment=Enum.TextXAlignment.Left,Parent=box})
    local col = new("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,Position=UDim2.new(0,0,0,22),BackgroundTransparency=1,Parent=box})
    new("UIListLayout",{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder,Parent=col})
    return col
end

-------------------------------------------------
-- 2. widget factories
-------------------------------------------------
local function row(parent, h) return new("Frame",{Size=UDim2.new(1,0,0,h or 22),BackgroundTransparency=1,Parent=parent}) end

local function Toggle(parent, key, text, default)
    V4.Tog[key] = default and true or false
    local r = row(parent, 22)
    new("TextLabel",{Size=UDim2.new(1,-40,1,0),BackgroundTransparency=1,Text=text,Font=THEME.font,TextSize=12,TextColor3=THEME.text,TextXAlignment=Enum.TextXAlignment.Left,Parent=r})
    local sw = new("TextButton",{Size=UDim2.fromOffset(32,16),Position=UDim2.new(1,-32,0.5,-8),BackgroundColor3=THEME.panel,BorderSizePixel=0,Text="",AutoButtonColor=false,Parent=r})
    corner(sw,8); stroke(sw,THEME.stroke,1)
    local knob = new("Frame",{Size=UDim2.fromOffset(12,12),Position=UDim2.fromOffset(2,2),BackgroundColor3=THEME.sub,BorderSizePixel=0,Parent=sw})
    corner(knob,8)
    local function paint()
        if V4.Tog[key] then
            sw.BackgroundColor3 = THEME.accent
            TweenService:Create(knob,TweenInfo.new(0.12),{Position=UDim2.fromOffset(18,2),BackgroundColor3=Color3.new(1,1,1)}):Play()
        else
            sw.BackgroundColor3 = THEME.panel
            TweenService:Create(knob,TweenInfo.new(0.12),{Position=UDim2.fromOffset(2,2),BackgroundColor3=THEME.sub}):Play()
        end
    end
    sw.MouseButton1Click:Connect(function() V4.Tog[key] = not V4.Tog[key]; paint() end)
    paint()
    return sw
end

local function Slider(parent, key, text, default, min, max, step, suffix)
    V4.Opt[key] = default
    local box = new("Frame",{Size=UDim2.new(1,0,0,36),BackgroundTransparency=1,Parent=parent})
    local lab = new("TextLabel",{Size=UDim2.new(1,-50,0,14),BackgroundTransparency=1,Text=text,Font=THEME.font,TextSize=12,TextColor3=THEME.text,TextXAlignment=Enum.TextXAlignment.Left,Parent=box})
    local val = new("TextLabel",{Size=UDim2.new(0,50,0,14),Position=UDim2.new(1,-50,0,0),BackgroundTransparency=1,Text=tostring(default)..(suffix or ""),Font=THEME.fontMono,TextSize=12,TextColor3=THEME.accent,TextXAlignment=Enum.TextXAlignment.Right,Parent=box})
    local bar = new("Frame",{Size=UDim2.new(1,0,0,8),Position=UDim2.new(0,0,0,20),BackgroundColor3=THEME.panel,BorderSizePixel=0,Parent=box})
    corner(bar,4)
    local fill = new("Frame",{Size=UDim2.new((default-min)/(max-min),0,1,0),BackgroundColor3=THEME.accent,BorderSizePixel=0,Parent=bar})
    corner(fill,4)
    local dragging=false
    local function setFromX(x)
        local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local v = min + (max-min)*rel
        if step then v = math.floor(v/step+0.5)*step end
        v = math.clamp(v, min, max)
        V4.Opt[key] = v
        fill.Size = UDim2.new((v-min)/(max-min),0,1,0)
        if step and step >= 1 then val.Text = tostring(math.floor(v))..(suffix or "")
        else val.Text = string.format("%.2f",v)..(suffix or "") end
    end
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging=true; setFromX(i.Position.X)
        end
    end)
    addConn(UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then setFromX(i.Position.X) end
    end))
    addConn(UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging=false end
    end))
end

local function Dropdown(parent, key, text, values, default)
    V4.Opt[key] = default
    local box = new("Frame",{Size=UDim2.new(1,0,0,38),BackgroundTransparency=1,Parent=parent})
    new("TextLabel",{Size=UDim2.new(1,0,0,14),BackgroundTransparency=1,Text=text,Font=THEME.font,TextSize=12,TextColor3=THEME.text,TextXAlignment=Enum.TextXAlignment.Left,Parent=box})
    local btn = new("TextButton",{Size=UDim2.new(1,0,0,20),Position=UDim2.new(0,0,0,16),BackgroundColor3=THEME.panel,BorderSizePixel=0,Text="  "..default.." ▾",Font=THEME.font,TextSize=12,TextColor3=THEME.text,TextXAlignment=Enum.TextXAlignment.Left,AutoButtonColor=false,Parent=box})
    corner(btn,4); stroke(btn,THEME.stroke,1)
    local list = new("Frame",{Size=UDim2.new(1,0,0,0),Position=UDim2.new(0,0,1,2),BackgroundColor3=THEME.panel,BorderSizePixel=0,Visible=false,ZIndex=20,Parent=btn,AutomaticSize=Enum.AutomaticSize.Y})
    corner(list,4); stroke(list,THEME.accent,1)
    new("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Parent=list})
    for _,v in ipairs(values) do
        local it = new("TextButton",{Size=UDim2.new(1,0,0,20),BackgroundColor3=THEME.panel2,BorderSizePixel=0,Text="  "..v,Font=THEME.font,TextSize=12,TextColor3=THEME.text,TextXAlignment=Enum.TextXAlignment.Left,AutoButtonColor=false,ZIndex=21,Parent=list})
        it.MouseEnter:Connect(function() it.BackgroundColor3 = THEME.accent end)
        it.MouseLeave:Connect(function() it.BackgroundColor3 = THEME.panel2 end)
        it.MouseButton1Click:Connect(function()
            V4.Opt[key] = v; btn.Text = "  "..v.." ▾"; list.Visible=false
        end)
    end
    btn.MouseButton1Click:Connect(function() list.Visible = not list.Visible end)
end

local function Keybind(parent, key, text, defaultKey, defaultMode)
    V4.Keys[key] = {k=defaultKey, mode=defaultMode or "Hold", state=false, toggleOn=false}
    local box = new("Frame",{Size=UDim2.new(1,0,0,22),BackgroundTransparency=1,Parent=parent})
    new("TextLabel",{Size=UDim2.new(1,-120,1,0),BackgroundTransparency=1,Text=text,Font=THEME.font,TextSize=12,TextColor3=THEME.text,TextXAlignment=Enum.TextXAlignment.Left,Parent=box})
    local kbtn = new("TextButton",{Size=UDim2.fromOffset(60,18),Position=UDim2.new(1,-120,0.5,-9),BackgroundColor3=THEME.panel,Text=tostring(defaultKey),Font=THEME.fontMono,TextSize=11,TextColor3=THEME.accent,BorderSizePixel=0,AutoButtonColor=false,Parent=box})
    corner(kbtn,4); stroke(kbtn,THEME.stroke,1)
    local mbtn = new("TextButton",{Size=UDim2.fromOffset(54,18),Position=UDim2.new(1,-56,0.5,-9),BackgroundColor3=THEME.panel,Text=V4.Keys[key].mode,Font=THEME.font,TextSize=11,TextColor3=THEME.sub,BorderSizePixel=0,AutoButtonColor=false,Parent=box})
    corner(mbtn,4); stroke(mbtn,THEME.stroke,1)
    local picking=false
    kbtn.MouseButton1Click:Connect(function() picking=true; kbtn.Text="..." end)
    addConn(UserInputService.InputBegan:Connect(function(i,gpe)
        if picking then
            if i.UserInputType==Enum.UserInputType.Keyboard then V4.Keys[key].k = i.KeyCode
            elseif i.UserInputType==Enum.UserInputType.MouseButton1 then V4.Keys[key].k = "MB1"
            elseif i.UserInputType==Enum.UserInputType.MouseButton2 then V4.Keys[key].k = "MB2"
            end
            kbtn.Text = tostring(V4.Keys[key].k):gsub("Enum.KeyCode.","")
            picking=false
            return
        end
        if gpe then return end
        local k = V4.Keys[key]
        local match = (k.k == "MB1" and i.UserInputType==Enum.UserInputType.MouseButton1)
                   or (k.k == "MB2" and i.UserInputType==Enum.UserInputType.MouseButton2)
                   or (typeof(k.k)=="EnumItem" and i.KeyCode == k.k)
        if match then
            if k.mode=="Hold" then k.state=true
            elseif k.mode=="Toggle" then k.toggleOn = not k.toggleOn; k.state=k.toggleOn end
        end
    end))
    addConn(UserInputService.InputEnded:Connect(function(i)
        local k = V4.Keys[key]
        local match = (k.k == "MB1" and i.UserInputType==Enum.UserInputType.MouseButton1)
                   or (k.k == "MB2" and i.UserInputType==Enum.UserInputType.MouseButton2)
                   or (typeof(k.k)=="EnumItem" and i.KeyCode == k.k)
        if match and k.mode=="Hold" then k.state=false end
    end))
    mbtn.MouseButton1Click:Connect(function()
        local order = {Hold="Toggle", Toggle="Always", Always="Hold"}
        V4.Keys[key].mode = order[V4.Keys[key].mode]
        mbtn.Text = V4.Keys[key].mode
        V4.Keys[key].state = (V4.Keys[key].mode=="Always")
    end)
end

local function ColorBox(parent, key, text, default)
    V4.Opt[key] = default
    local box = new("Frame",{Size=UDim2.new(1,0,0,22),BackgroundTransparency=1,Parent=parent})
    new("TextLabel",{Size=UDim2.new(1,-30,1,0),BackgroundTransparency=1,Text=text,Font=THEME.font,TextSize=12,TextColor3=THEME.text,TextXAlignment=Enum.TextXAlignment.Left,Parent=box})
    local sw = new("Frame",{Size=UDim2.fromOffset(22,14),Position=UDim2.new(1,-22,0.5,-7),BackgroundColor3=default,BorderSizePixel=0,Parent=box})
    corner(sw,3); stroke(sw,THEME.stroke,1)
    -- cycle presets on click (keeps it tiny)
    local presets = {default, Color3.fromRGB(255,80,180), Color3.fromRGB(80,230,160), Color3.fromRGB(255,220,80), Color3.fromRGB(255,255,255), Color3.fromRGB(0,200,255)}
    local idx=1
    local btn = new("TextButton",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",Parent=sw})
    btn.MouseButton1Click:Connect(function()
        idx = idx%#presets+1; V4.Opt[key]=presets[idx]; sw.BackgroundColor3=presets[idx]
    end)
end

local function Button(parent, text, cb)
    local b = new("TextButton",{Size=UDim2.new(1,0,0,24),BackgroundColor3=THEME.accent,BorderSizePixel=0,Text=text,Font=THEME.fontBold,TextSize=12,TextColor3=Color3.new(1,1,1),AutoButtonColor=true,Parent=parent})
    corner(b,6)
    b.MouseButton1Click:Connect(cb)
end

local function Label(parent, text)
    return new("TextLabel",{Size=UDim2.new(1,0,0,14),BackgroundTransparency=1,Text=text,Font=THEME.font,TextSize=11,TextColor3=THEME.sub,TextXAlignment=Enum.TextXAlignment.Left,Parent=parent})
end

-------------------------------------------------
-- 3. tabs + controls
-------------------------------------------------
local pRage  = newTab("RAGEBOT")
local pRageX = newTab("RAGE+ PEAK")
local pAA    = newTab("ANTI-AIM")
local pAAX   = newTab("AA+ PEAK")
local pFake  = newTab("FAKE POS")
local pAwall = newTab("AUTOWALL / RESOLVER")
local pLegit = newTab("LEGIT / TRIGGER")
local pESP   = newTab("ESP+")
local pVis   = newTab("VISUALS+")
local pWorld = newTab("WORLD")
local pMove  = newTab("MOVEMENT")
local pMisc  = newTab("MISC")
local pCfg   = newTab("CONFIG")

-- ===== RAGE =====
do
    local s = newSection(pRage, "Core")
    Toggle(s,"RageEnabled","Enable Ragebot", false)
    Toggle(s,"RageSilent","Silent Aim", true)
    Toggle(s,"RageAutoFire","Auto Fire", false)
    Toggle(s,"RageAutoStop","Auto Stop", false)
    Toggle(s,"RageAutoScope","Auto Scope", true)
    Slider(s,"RageFov","FOV", 80, 5, 500, 1, "px")
    Slider(s,"RageMaxDist","Max Distance", 500, 10, 5000, 10, "s")
    Slider(s,"RageMinDmg","Min Damage", 1, 1, 150, 1)
    Dropdown(s,"RageKeyMode","Activation", {"Always","Hold","Toggle"}, "Hold")
    Keybind(s,"RageKey","Rage Key", "MB2", "Hold")

    local s2 = newSection(pRage, "Target Selection")
    Dropdown(s2,"RagePrio","Priority", {"FOV","Distance","Health","LowestHP","Crosshair","HighestDmg"}, "FOV")
    Toggle(s2,"RageVisibleOnly","Visible Only", false)
    Toggle(s2,"RageIgnoreTeam","Ignore Team", true)
    Toggle(s2,"RageIgnoreFriends","Ignore Friends", true)
    Slider(s2,"RageSwitch","Switch Delay", 0.05, 0, 1, 0.01, "s")
    Slider(s2,"RageKillDelay","Kill Delay", 0, 0, 1, 0.01, "s")

    local s3 = newSection(pRage, "Hitbox / Multipoint")
    Dropdown(s3,"RageHitbox","Primary Hitbox", {"Head","UpperTorso","Torso","HumanoidRootPart","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg","Nearest"}, "Head")
    Slider(s3,"RageMultipoint","Multipoint Scale", 0.75, 0, 1, 0.05)
    Slider(s3,"RageMultiPts","Multipoint Count", 6, 1, 16, 1)
    Toggle(s3,"RageHeadScale","Head Scale", false)
    Slider(s3,"RageHeadScaleV","Head Scale Value", 2, 1, 10, 0.1)
    Toggle(s3,"RageMagicBullet","Magic Bullet Retry", false)
    Slider(s3,"RageMagicTries","Retry Count", 3, 1, 10, 1)

    local s4 = newSection(pRage, "Prediction / Hitchance / Backtrack")
    Toggle(s4,"RagePred","Velocity Prediction", true)
    Slider(s4,"RagePredFactor","Prediction Factor", 0.16, 0, 1, 0.01, "s")
    Toggle(s4,"RageAirPred","Air Prediction", true)
    Toggle(s4,"RageCurvePred","Parabolic Curve", false)
    Toggle(s4,"RageHcGate","Use Hitchance Gate", true)
    Slider(s4,"RageHc","Min Hitchance", 70, 0, 100, 1, "%")
    Toggle(s4,"RageBT","Backtrack", true)
    Slider(s4,"RageBTms","Backtrack Max", 200, 0, 1000, 10, "ms")
end

-- ===== RAGE+ PEAK =====
do
    local s = newSection(pRageX, "Delta / Safepoint")
    Toggle(s,"RageSafepoint","Force Safepoint", true)
    Slider(s,"RageSPBias","Safepoint Bias", 0.6, 0, 1, 0.05)
    Toggle(s,"RageDeltaShot","Delta Shot", false)
    Slider(s,"RageDeltaMs","Delta Window", 60, 1, 400, 1, "ms")
    Toggle(s,"RageForceHS","Force Headshot", false)
    Toggle(s,"RageDamageAvg","Damage Averaging", true)
    Slider(s,"RageDmgCeil","Damage Ceiling", 100, 1, 200, 1)

    local s2 = newSection(pRageX, "Teleport / Blink / Duck")
    Toggle(s2,"RageTPAim","Teleport Aim", false)
    Slider(s2,"RageTPDist","TP Distance", 10, 2, 40, 1, "s")
    Toggle(s2,"RageBlink","Blink (choke stack)", false)
    Slider(s2,"RageBlinkTicks","Blink Ticks", 12, 2, 28, 1)
    Keybind(s2,"RageBlinkKey","Blink Key", Enum.KeyCode.T, "Hold")
    Toggle(s2,"RageFakeDuck","Fake Duck", false)
    Keybind(s2,"RageDuckKey","Duck Key", Enum.KeyCode.H, "Toggle")
    Toggle(s2,"RageSlow","Slow Walk", false)
    Slider(s2,"RageSlowSpd","Slow Speed", 4, 1, 16, 1)
    Keybind(s2,"RageSlowKey","Slow Key", Enum.KeyCode.LeftShift, "Hold")

    local s3 = newSection(pRageX, "Rate / Damage Shaping")
    Slider(s3,"RageSPS","Max Shots/sec", 10, 1, 30, 1)
    Slider(s3,"RageConf","Min Confidence", 65, 0, 100, 1, "%")
    Toggle(s3,"RageQuickStop","Quick Stop", false)
    Toggle(s3,"RageAutoPreTrig","Auto Pre-Trigger", false)
    Toggle(s3,"RageIgnoreCrouch","Ignore Crouching", false)

    local s4 = newSection(pRageX, "Behavior")
    Toggle(s4,"RageAdaptiveBaim","Adaptive Body Aim", true)
    Slider(s4,"RageBaimMiss","Baim After Misses", 2, 1, 6, 1)
    Toggle(s4,"RageNoScope","Allow No-Scope", false)
    Toggle(s4,"RageFastFire","Fast Fire (no CD)", false)
    Toggle(s4,"RageAimCone","Compensate Spread Cone", true)
    Slider(s4,"RageConeSamp","Cone Samples", 8, 1, 32, 1)
    Toggle(s4,"RageAutoStopPeek","Auto Stop on Peek", false)
    Toggle(s4,"RageAutoKnife","Auto Knife on Close", false)
    Slider(s4,"RageKnifeDist","Knife Distance", 10, 2, 25, 1)
end

-- ===== ANTI-AIM (base) =====
do
    local s = newSection(pAA, "Yaw")
    Toggle(s,"AAEnabled","Enable Anti-Aim", false)
    Dropdown(s,"AAYawMode","Yaw Mode", {"Backwards","Jitter","Spin","Zero","Sideways","Random","LBY-Break"}, "Jitter")
    Slider(s,"AADesync","Desync Angle", 58, -180, 180, 1, "°")
    Keybind(s,"AAInvert","Invert Key", Enum.KeyCode.X, "Toggle")

    local s2 = newSection(pAA, "Pitch")
    Toggle(s2,"AAPitchOn","Enable Pitch", false)
    Dropdown(s2,"AAPitch","Pitch", {"Down","Up","Zero","Jitter"}, "Down")

    local s3 = newSection(pAA, "Fakelag")
    Toggle(s3,"FakeLag","Fakelag", false)
    Slider(s3,"FakeLagT","Choke Ticks", 7, 1, 14, 1)
    Dropdown(s3,"FakeLagMode","Mode", {"Static","Adaptive","Jitter","OnPeek","OnMove"}, "Adaptive")
end

-- ===== AA+ PEAK =====
do
    local s = newSection(pAAX, "Yaw Base")
    Toggle(s,"AAXOn","Enable AA+", false)
    Dropdown(s,"AAXBase","Yaw Base", {"Target","Local","At-Targets","Freestanding","Static"}, "At-Targets")
    Slider(s,"AAXYawAdd","Yaw Add", 0, -180, 180, 1, "°")
    Dropdown(s,"AAXMod","Yaw Modifier", {"None","Center","Offset","Spin","Random","Jitter","Sway"}, "Jitter")
    Slider(s,"AAXModDeg","Modifier Deg", 15, 0, 180, 1, "°")
    Slider(s,"AAXModHz","Modifier Hz", 8, 0.1, 30, 0.1)

    local s2 = newSection(pAAX, "Desync / Body")
    Toggle(s2,"AAXDesyncReal","Desync Real", true)
    Slider(s2,"AAXDesyncL","Desync Left", 58, 0, 60, 1, "°")
    Slider(s2,"AAXDesyncR","Desync Right", 58, 0, 60, 1, "°")
    Toggle(s2,"AAXLBY","LBY Breaker", true)
    Toggle(s2,"AAXMicro","Micro Jitter", true)
    Slider(s2,"AAXMicroDeg","Micro Deg", 3, 0, 20, 1, "°")
    Toggle(s2,"AAXBodyYaw","Body Yaw (fake upper)", true)
    Slider(s2,"AAXBodyDeg","Body Yaw Deg", 90, 0, 180, 1, "°")
    Toggle(s2,"AAXEdgeYaw","Edge Yaw", false)

    local s3 = newSection(pAAX, "Pitch / Roll / Sway")
    Dropdown(s3,"AAXPitch","Pitch", {"None","Down","Up","Zero","Fake","Jitter"}, "Down")
    Slider(s3,"AAXPitchDeg","Pitch Deg", 89, 0, 89, 1, "°")
    Dropdown(s3,"AAXRoll","Roll", {"None","Left","Right","Alternate","Sway"}, "None")
    Slider(s3,"AAXRollDeg","Roll Deg", 30, 0, 180, 1, "°")
    Toggle(s3,"AAXSway","Sine Sway", false)
    Slider(s3,"AAXSwayHz","Sway Hz", 1.5, 0.1, 20, 0.1)
    Slider(s3,"AAXSwayDeg","Sway Deg", 8, 0, 60, 1, "°")

    local s4 = newSection(pAAX, "Manual / On-Shot / Defensive")
    Toggle(s4,"AAXManual","Enable Manual", false)
    Keybind(s4,"AAXML","Manual Left", Enum.KeyCode.Left, "Hold")
    Keybind(s4,"AAXMR","Manual Right", Enum.KeyCode.Right, "Hold")
    Keybind(s4,"AAXMB","Manual Back", Enum.KeyCode.Down, "Hold")
    Keybind(s4,"AAXMF","Manual Forward", Enum.KeyCode.Up, "Hold")
    Keybind(s4,"AAXFlip","Inverter", Enum.KeyCode.X, "Toggle")
    Toggle(s4,"AAXOnShot","On-Shot AA", true)
    Slider(s4,"AAXOSDeg","On-Shot Flip", 180, 0, 360, 1, "°")
    Slider(s4,"AAXOSms","On-Shot Hold", 220, 50, 1000, 10, "ms")
    Toggle(s4,"AAXDef","Defensive AA", true)
    Slider(s4,"AAXDefMs","Defensive Hold", 320, 50, 1500, 10, "ms")

    local s5 = newSection(pAAX, "Freestanding / At-Targets / HUD")
    Toggle(s5,"AAXFree","Freestanding", true)
    Slider(s5,"AAXFreeDist","Freestand Scan", 20, 2, 60, 1, "s")
    Toggle(s5,"AAXAtTgt","At-Targets", true)
    Toggle(s5,"AAXAtBest","Use Best vs Closest", true)
    Toggle(s5,"AAXArrow","Desync Arrow HUD", true)
end

-- ===== FAKE POS =====
do
    local s = newSection(pFake, "Engine")
    Toggle(s,"FPOn","Enable Fake Position", false)
    Dropdown(s,"FPEngine","Engine", {"Static","Orbit","OrbitDual","Random","Behind","MouseDrag","Teleport","Zigzag","PathReplay","Mirror","PingTP","Split","Choke-Freeze","Warp"}, "OrbitDual")
    Slider(s,"FPRadius","Radius", 10, 1, 80, 1, "s")
    Slider(s,"FPHeight","Height", 0, -20, 20, 0.5, "s")
    Slider(s,"FPSpeed","Speed", 3, 0, 30, 0.1)
    Toggle(s,"FPDual","Dual Ghost", true)
    Toggle(s,"FPColor","Color Shift", true)
    Slider(s,"FPAlpha","Ghost Alpha", 0.4, 0, 1, 0.05)
    Keybind(s,"FPKey","Toggle Key", Enum.KeyCode.V, "Toggle")

    local s2 = newSection(pFake, "Replay / Mirror / Blink / Warp")
    Slider(s2,"FPReplayMs","Replay Lag", 350, 50, 1500, 10, "ms")
    Toggle(s2,"FPBlink","Blink Teleport", false)
    Keybind(s2,"FPBlinkKey","Blink Key", Enum.KeyCode.G, "Hold")
    Slider(s2,"FPBlinkDist","Blink Distance", 8, 2, 40, 1, "s")
    Toggle(s2,"FPWarpShot","Warp On Shot", false)
    Toggle(s2,"FPFreezePeek","Freeze on Peek", false)
    Toggle(s2,"FPAlignCover","Align to Cover", true)
end

-- ===== AUTOWALL / RESOLVER =====
do
    local s = newSection(pAwall, "Autowall")
    Toggle(s,"AwOn","Enable", true)
    Slider(s,"AwMin","Min Wall Dmg", 20, 1, 150, 1)
    Slider(s,"AwPen","Max Penetrations", 2, 1, 5, 1)
    Slider(s,"AwLoss","Damage Per Wall", 25, 5, 80, 1)
    Toggle(s,"AwTrace","Visualize Trace", false)

    local s2 = newSection(pAwall, "Resolver")
    Toggle(s2,"ResOn","Enable", true)
    Dropdown(s2,"ResMode","Mode", {"Brute","Memory","Jitter","Static","LBY","Adaptive","LBY-Freestand"}, "Adaptive")
    Slider(s2,"ResMax","Max Misses", 2, 1, 10, 1)
    Slider(s2,"ResStep","Brute Step", 58, 1, 180, 1, "°")
    Toggle(s2,"ResForceBody","Force Body on Miss", true)
    Toggle(s2,"ResSafe","Prefer Safepoint", true)
    Toggle(s2,"ResIndicator","Show Indicator", true)
end

-- ===== LEGIT / TRIGGER =====
do
    local s = newSection(pLegit, "Legit Aim")
    Toggle(s,"LegitOn","Enable", false)
    Slider(s,"LegitFov","FOV", 25, 1, 200, 1, "px")
    Slider(s,"LegitSmooth","Smoothing", 8, 1, 30, 0.5)
    Dropdown(s,"LegitHB","Hitbox", {"Head","Torso","Nearest"}, "Head")
    Toggle(s,"LegitVis","Visible Only", true)
    Keybind(s,"LegitKey","Legit Key", "MB2", "Hold")

    local s2 = newSection(pLegit, "Trigger Bot")
    Toggle(s2,"TrigOn","Enable", false)
    Slider(s2,"TrigDelay","Delay", 0.03, 0, 0.5, 0.01, "s")
    Slider(s2,"TrigBurst","Burst Count", 1, 1, 10, 1)
    Slider(s2,"TrigReset","Reset Cooldown", 0.15, 0, 1, 0.01, "s")
    Toggle(s2,"TrigHeadOnly","Head Only", false)
    Keybind(s2,"TrigKey","Trigger Key", Enum.KeyCode.C, "Hold")
end

-- ===== ESP+ =====
do
    local s = newSection(pESP, "Core")
    Toggle(s,"EspOn","Enable ESP", false)
    Toggle(s,"EspBox","Box", true)
    Toggle(s,"EspName","Name", true)
    Toggle(s,"EspHealth","Health Bar", true)
    Toggle(s,"EspDist","Distance", true)
    Toggle(s,"EspTracer","Tracer", false)
    Dropdown(s,"EspTracerO","Tracer Origin", {"Bottom","Mouse","Top"}, "Bottom")
    Toggle(s,"EspOffscreen","Off-Screen Arrow", true)
    Toggle(s,"EspTeamShow","Show Team", false)
    Toggle(s,"EspTeamColor","Use Team Color", false)
    ColorBox(s,"EspColor","Enemy Color", Color3.fromRGB(255,60,120))
    ColorBox(s,"EspFriendColor","Friend Color", Color3.fromRGB(80,180,255))

    local s2 = newSection(pESP, "Chams")
    Toggle(s2,"ChamsOn","Enable Chams", false)
    ColorBox(s2,"ChamsColor","Fill Color", Color3.fromRGB(255,0,120))
    Slider(s2,"ChamsFill","Fill Transparency", 0.4, 0, 1, 0.05)
    Toggle(s2,"ChamsVisCheck","Visible-Check Color", true)
    ColorBox(s2,"ChamsVisColor","Visible Color", Color3.fromRGB(80,230,160))
end

-- ===== VISUALS+ =====
do
    local s = newSection(pVis, "HUD")
    Toggle(s,"VisFov","FOV Circle", true)
    ColorBox(s,"VisFovColor","FOV Color", Color3.fromRGB(190,100,255))
    Toggle(s,"VisLegitFov","Legit FOV Circle", true)
    Toggle(s,"VisTargetBox","Target Highlight", true)
    Toggle(s,"VisHcBar","Hitchance Bar", true)
    Toggle(s,"VisStats","Stats Panel", true)
    Toggle(s,"VisWater","Watermark", true)

    local s2 = newSection(pVis, "Crosshair")
    Toggle(s2,"XhOn","Enable Crosshair", false)
    Dropdown(s2,"XhStyle","Style", {"Plus","Dot","T","Circle","Cross+Dot"}, "Plus")
    Slider(s2,"XhSize","Size", 10, 2, 40, 1)
    Slider(s2,"XhGap","Gap", 3, 0, 20, 1)
    Slider(s2,"XhThick","Thickness", 1, 1, 5, 1)
    ColorBox(s2,"XhColor","Color", Color3.fromRGB(190,100,255))
end

-- ===== WORLD =====
do
    local s = newSection(pWorld, "World")
    Toggle(s,"NoFog","No Fog", false)
    Toggle(s,"FullBright","Fullbright", false)
    Slider(s,"Bright","Brightness", 2, 0, 10, 0.1)
    Toggle(s,"TimeLock","Time Lock (Noon)", false)

    local s2 = newSection(pWorld, "Camera")
    Toggle(s2,"CamFovOn","Apply Camera FOV", false)
    Slider(s2,"CamFov","Camera FOV", 70, 1, 120, 1)
    Toggle(s2,"ThirdP","Third Person", false)
    Slider(s2,"TPDist","3rd Person Distance", 12, 2, 40, 1)
end

-- ===== MOVEMENT =====
do
    local s = newSection(pMove, "Movement")
    Toggle(s,"Bhop","Bunnyhop", false)
    Toggle(s,"EdgeJump","Edge Jump", false)
    Toggle(s,"Strafer","Auto Strafer", false)
    Toggle(s,"InfJump","Infinite Jump", false)
    Toggle(s,"WsOn","Apply Walkspeed", false)
    Slider(s,"Ws","Walkspeed", 16, 16, 500, 1)
    Toggle(s,"JpOn","Apply JumpPower", false)
    Slider(s,"Jp","JumpPower", 50, 50, 1000, 1)
    Toggle(s,"Noclip","Noclip", false)

    local s2 = newSection(pMove, "Fly")
    Toggle(s2,"Fly","Fly", false)
    Slider(s2,"FlySpd","Fly Speed", 50, 5, 300, 1)
    Keybind(s2,"FlyKey","Fly Key", Enum.KeyCode.F, "Toggle")
end

-- ===== MISC =====
do
    local s = newSection(pMisc, "Automation")
    Toggle(s,"AntiAfk","Anti AFK", true)
    Toggle(s,"AutoReload","Auto Reload", false)
    Toggle(s,"AutoInteract","Auto Interact (E)", false)
    Toggle(s,"HitSound","Hit Sound", true)
    Slider(s,"HitVol","Hit Sound Volume", 0.6, 0, 2, 0.05)

    local s2 = newSection(pMisc, "Menu")
    Keybind(s2,"MenuKey","Toggle Menu", Enum.KeyCode.RightShift, "Hold")
    Slider(s2,"MenuAlpha","Menu Opacity", 1, 0.2, 1, 0.05)
end

-- ===== CONFIG =====
do
    local s = newSection(pCfg, "Config")
    local nameBox = new("TextBox",{Size=UDim2.new(1,0,0,22),BackgroundColor3=THEME.panel,BorderSizePixel=0,Text="default",Font=THEME.fontMono,TextSize=12,TextColor3=THEME.text,PlaceholderText="config name",Parent=s})
    corner(nameBox,4); stroke(nameBox,THEME.stroke,1)
    Button(s,"💾 Save", function()
        local data = {Opt={},Tog={}}
        for k,v in pairs(V4.Opt) do if typeof(v)~="Color3" and type(v)~="function" then data.Opt[k]=v end end
        for k,v in pairs(V4.Tog) do data.Tog[k]=v end
        local ok,enc = pcall(function() return HttpService:JSONEncode(data) end)
        if ok and writefile then pcall(writefile, "UEV4_"..nameBox.Text..".json", enc) end
    end)
    Button(s,"📂 Load", function()
        local f = "UEV4_"..nameBox.Text..".json"
        if isfile and isfile(f) then
            local d = HttpService:JSONDecode(readfile(f))
            for k,v in pairs(d.Opt or {}) do V4.Opt[k]=v end
            for k,v in pairs(d.Tog or {}) do V4.Tog[k]=v end
        end
    end)
    Button(s,"🗑  Unload", function() V4.Unload() end)

    local s2 = newSection(pCfg, "About")
    Label(s2,"Unnamed Enhancements V4")
    Label(s2,"Built by Olivia")
    Label(s2,"discord.gg/ojailbreaks")
end

-- open first tab
for _,c in ipairs(tabBar:GetChildren()) do
    if c:IsA("TextButton") then
        c.BackgroundColor3 = THEME.accent; c.TextColor3=Color3.new(1,1,1); pages["RAGEBOT"].Visible=true; currentPage=pages["RAGEBOT"]
        break
    end
end

-------------------------------------------------
-- 4. ENGINES
-------------------------------------------------
local O, T, K, S = V4.Opt, V4.Tog, V4.Keys, V4.State

local function alive(p)
    return p and p ~= LP and p.Character
        and p.Character:FindFirstChild("HumanoidRootPart")
        and p.Character:FindFirstChildOfClass("Humanoid")
        and p.Character:FindFirstChildOfClass("Humanoid").Health > 0
end
local function enemyOf(p) if not T.RageIgnoreTeam then return true end return p.Team ~= LP.Team end
local function w2s(pos)
    local v,on = Camera:WorldToViewportPoint(pos); return Vector2.new(v.X,v.Y), on, v.Z
end
local function los(from, hitPart)
    local dir = hitPart.Position - from
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = {LP.Character, Camera}
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local r = Workspace:Raycast(from, dir, rp)
    if not r then return true end
    return r.Instance:IsDescendantOf(hitPart.Parent)
end
local function bestHitbox(char)
    local name = O.RageHitbox or "Head"
    if name == "Nearest" then
        local m = UserInputService:GetMouseLocation()
        local best, bd
        for _,n in ipairs({"Head","UpperTorso","Torso","HumanoidRootPart"}) do
            local p = char:FindFirstChild(n)
            if p then local s,on = w2s(p.Position); if on then local d=(s-m).Magnitude; if not bd or d<bd then bd,best=d,p end end end
        end
        return best
    end
    return char:FindFirstChild(name) or char:FindFirstChild("HumanoidRootPart")
end
local function multipoints(part)
    local n=O.RageMultiPts or 6; local sc=O.RageMultipoint or 0.75
    local pts={part.Position}
    local sz=part.Size*sc
    for i=1,n-1 do
        local t=(i-1)/(n-1); local a=t*math.pi*2
        pts[#pts+1]=part.Position+Vector3.new(math.cos(a)*sz.X*0.5, math.sin(a)*sz.Y*0.5, 0)
    end
    return pts
end
local function bt_push(p)
    if not alive(p) then return end
    local hrp=p.Character.HumanoidRootPart
    local buf=S.backtrack[p] or {}; S.backtrack[p]=buf
    table.insert(buf,1,{t=os.clock(),pos=hrp.Position,vel=hrp.AssemblyLinearVelocity,cf=hrp.CFrame})
    local cutoff=os.clock()-1.0
    while buf[#buf] and buf[#buf].t<cutoff do buf[#buf]=nil end
end
local function bt_sample(p,ms)
    local buf=S.backtrack[p]; if not buf then return nil end
    local tgt=os.clock()-math.clamp(ms,0,1000)/1000
    for _,r in ipairs(buf) do if r.t<=tgt then return r end end
    return buf[1]
end
local function self_bt_push()
    if not alive(LP) then return end
    table.insert(S.selfPath,1,{t=os.clock(),cf=LP.Character.HumanoidRootPart.CFrame})
    while S.selfPath[#S.selfPath] and os.clock()-S.selfPath[#S.selfPath].t>2 do S.selfPath[#S.selfPath]=nil end
end
local function self_bt(ms)
    local tgt=os.clock()-ms/1000
    for _,r in ipairs(S.selfPath) do if r.t<=tgt then return r end end
    return S.selfPath[#S.selfPath]
end

local function hitchance(from, part, vel, pred)
    if not T.RageHcGate then return 100 end
    local n,hits=16,0
    local j=math.min(vel.Magnitude/40,1.5)
    for i=1,n do
        local ox=(math.random()*2-1)*j; local oz=(math.random()*2-1)*j
        local tgt=part.Position+Vector3.new(ox,0,oz)+vel*pred
        local d=tgt-from
        local rp=RaycastParams.new(); rp.FilterDescendantsInstances={LP.Character,Camera}; rp.FilterType=Enum.RaycastFilterType.Exclude
        local r=Workspace:Raycast(from,d,rp)
        if not r or r.Instance:IsDescendantOf(part.Parent) then hits+=1 end
    end
    return hits/n*100
end
local function autowall(from, part)
    if not T.AwOn then return 100 end
    local dir=part.Position-from
    local rp=RaycastParams.new(); rp.FilterDescendantsInstances={LP.Character,Camera}; rp.FilterType=Enum.RaycastFilterType.Exclude
    local p=from; local rem=100; local loss=O.AwLoss or 25
    for i=1,O.AwPen do
        local r=Workspace:Raycast(p,dir.Unit*dir.Magnitude,rp)
        if not r then return rem end
        if r.Instance:IsDescendantOf(part.Parent) then return rem end
        rem-=loss
        if rem<O.AwMin then return 0 end
        p=r.Position+dir.Unit*0.5
    end
    return rem
end
local function resolver_fix(p, part)
    if not T.ResOn then return part.Position end
    local r=S.resolver[p] or {yaw=0,misses=0}; S.resolver[p]=r
    local mode=O.ResMode; local step=O.ResStep
    local yaw=r.yaw
    if mode=="Brute" then yaw=(r.misses*step)%360
    elseif mode=="Jitter" then yaw=((os.clock()*4)%2<1) and step or -step
    elseif mode=="LBY" then yaw=math.sin(os.clock()*2)*60
    elseif mode=="Memory" then yaw=r.lastHit or 0
    elseif mode=="Adaptive" then
        local v=part.AssemblyLinearVelocity.Magnitude
        yaw=(v>2 and 0) or ((r.misses*step)%360)
    elseif mode=="LBY-Freestand" then
        local to=LP.Character.HumanoidRootPart.Position-part.Position
        yaw=math.deg(math.atan2(to.X,to.Z))
    end
    local off=(p.Character.HumanoidRootPart.CFrame*CFrame.Angles(0,math.rad(yaw),0)).LookVector*0.3
    return part.Position+off
end
local function resolver_miss(p)
    local r=S.resolver[p] or {yaw=0,misses=0}
    r.misses+=1; if r.misses>=O.ResMax then r.yaw=(r.yaw+O.ResStep)%360; r.misses=0 end
    S.resolver[p]=r
end
local function resolver_hit(p)
    local r=S.resolver[p] or {yaw=0,misses=0}; r.lastHit=r.yaw; r.misses=0; S.resolver[p]=r
end

local function pickTarget()
    if not T.RageEnabled then return nil end
    local km = O.RageKeyMode
    if km=="Hold" and not K.RageKey.state then return nil end
    if km=="Toggle" and not K.RageKey.state then return nil end
    local m=UserInputService:GetMouseLocation()
    local fov=O.RageFov; local prio=O.RagePrio
    local best,bs
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP and alive(p) and enemyOf(p) then
            local part=bestHitbox(p.Character)
            if part then
                local s,on=w2s(part.Position)
                local d2=(s-m).Magnitude; local d3=(part.Position-Camera.CFrame.Position).Magnitude
                if on and d2<=fov and d3<=O.RageMaxDist then
                    if (not T.RageVisibleOnly) or los(Camera.CFrame.Position,part) then
                        local sc
                        if prio=="FOV" then sc=d2
                        elseif prio=="Distance" then sc=d3
                        elseif prio=="Health" or prio=="LowestHP" then
                            local h=p.Character:FindFirstChildOfClass("Humanoid"); sc=h and h.Health or 100
                        elseif prio=="Crosshair" then sc=d2*0.6+d3*0.4
                        elseif prio=="HighestDmg" then sc=-autowall(Camera.CFrame.Position,part)
                        else sc=d2 end
                        if not bs or sc<bs then best,bs=p,sc end
                    end
                end
            end
        end
    end
    return best
end

local function fire_shot()
    local now=os.clock()
    while #S.shotsBucket>0 and now-S.shotsBucket[1]>1 do table.remove(S.shotsBucket,1) end
    if not T.RageFastFire and #S.shotsBucket>=O.RageSPS then return end
    if now-S.lastShot<0.05 then return end
    S.lastShot=now
    pcall(function()
        VirtualInput:SendMouseButtonEvent(0,0,0,true,game,1)
        task.wait()
        VirtualInput:SendMouseButtonEvent(0,0,0,false,game,1)
    end)
    table.insert(S.shotsBucket,now)
    S.stats.shots+=1
    S.onShotUntil = now + (O.AAXOSms or 0)/1000
    S.defUntil    = now + (O.AAXDefMs or 0)/1000
    if T.FPWarpShot and alive(LP) then
        local hrp=LP.Character.HumanoidRootPart
        pcall(function() hrp.CFrame = hrp.CFrame + hrp.CFrame.RightVector*(O.FPBlinkDist or 6) end)
    end
end

-- silent aim via mouse hook
do
    local mt = getrawmetatable and getrawmetatable(game) or nil
    if mt and setreadonly then
        setreadonly(mt,false)
        local oldIndex=mt.__index; local oldNc=mt.__namecall
        mt.__index = newcclosure(function(self,k)
            if self==LP and k=="GetMouse" then
                local real=oldIndex(self,k)
                return function(...)
                    local m=real(...)
                    if S.aimPos and T.RageEnabled and T.RageSilent then
                        pcall(function() m.Hit=CFrame.new(S.aimPos) end)
                    end
                    return m
                end
            end
            return oldIndex(self,k)
        end)
        mt.__namecall = newcclosure(function(self,...)
            local method=getnamecallmethod()
            if S.aimPos and T.RageSilent and T.RageEnabled then
                if method=="ScreenPointToRay" or method=="ViewportPointToRay" then
                    local dir=(S.aimPos-Camera.CFrame.Position).Unit
                    return Ray.new(Camera.CFrame.Position, dir*500)
                end
            end
            return oldNc(self,...)
        end)
        setreadonly(mt,true)
    end
end

local function rage_tick()
    if not T.RageEnabled then S.target=nil; S.aimPos=nil; return end
    if os.clock()-S.lastKillAt<O.RageKillDelay then return end
    local tgt=pickTarget()
    if not tgt then S.target=nil; S.aimPos=nil; return end
    if S.target~=tgt then
        if os.clock()-S.lastSwitch<O.RageSwitch then return end
        S.lastSwitch=os.clock()
    end
    S.target=tgt
    local part=bestHitbox(tgt.Character); if not part then return end
    local pts=multipoints(part)
    if T.RageBT then
        local rec=bt_sample(tgt,O.RageBTms)
        if rec then local delta=rec.pos-part.Position; for i,v in ipairs(pts) do pts[i]=v+delta end end
    end
    local bestAim, bestSc
    for _,raw in ipairs(pts) do
        local aim=raw
        if T.RagePred then
            local vel=part.AssemblyLinearVelocity
            if T.RageAirPred or math.abs(vel.Y)<1 then aim=aim+vel*O.RagePredFactor end
            if T.RageCurvePred then aim=aim+Vector3.new(0,-0.5*9.81*O.RagePredFactor^2,0) end
        end
        local off=resolver_fix(tgt,part)-part.Position
        aim=aim+off
        local hc=hitchance(Camera.CFrame.Position,part,part.AssemblyLinearVelocity,O.RagePredFactor)
        local dmg=autowall(Camera.CFrame.Position,part)
        if hc>=O.RageHc and dmg>=O.RageMinDmg then
            local sc=-(hc+dmg)
            if not bestSc or sc<bestSc then bestSc,bestAim,S.hitChance=sc,aim,hc end
        end
    end
    if not bestAim then S.aimPos=nil return end
    -- safepoint
    if T.RageSafepoint then
        local head=tgt.Character:FindFirstChild("Head") or part
        bestAim = bestAim:Lerp(head.Position, O.RageSPBias)
    end
    if T.RageForceHS and tgt.Character:FindFirstChild("Head") then bestAim=tgt.Character.Head.Position end
    if T.RageAdaptiveBaim then
        local r=S.resolver[tgt] or {misses=0}
        if r.misses>=O.RageBaimMiss then
            local body=tgt.Character:FindFirstChild("UpperTorso") or tgt.Character:FindFirstChild("Torso") or part
            bestAim=body.Position
        end
    end
    S.aimPos=bestAim
    if T.RageAutoFire then
        local tries = T.RageMagicBullet and O.RageMagicTries or 1
        for i=1,tries do fire_shot(); if i<tries then task.wait() end end
    end
end

-- anti-aim engines
local function at_targets_yaw()
    local best,bd
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP and alive(p) and enemyOf(p) then
            local hrp=p.Character.HumanoidRootPart
            local d=(hrp.Position-LP.Character.HumanoidRootPart.Position).Magnitude
            local sc=T.AAXAtBest and -d or d
            if not bd or sc<bd then bd,best=sc,hrp end
        end
    end
    if not best then return 0 end
    local to=best.Position-LP.Character.HumanoidRootPart.Position
    return math.atan2(to.X,to.Z)+math.pi
end
local function freestand_side()
    if not alive(LP) then return 1 end
    local hrp=LP.Character.HumanoidRootPart
    local rp=RaycastParams.new(); rp.FilterDescendantsInstances={LP.Character,Camera}; rp.FilterType=Enum.RaycastFilterType.Exclude
    local d=O.AAXFreeDist
    local rH=Workspace:Raycast(hrp.Position,hrp.CFrame.RightVector*d,rp)
    local lH=Workspace:Raycast(hrp.Position,-hrp.CFrame.RightVector*d,rp)
    local rS=rH and (d-(rH.Position-hrp.Position).Magnitude) or 0
    local lS=lH and (d-(lH.Position-hrp.Position).Magnitude) or 0
    return rS>=lS and 1 or -1
end
local function manual_dir()
    if not T.AAXManual then return nil end
    if K.AAXML.state then return math.pi*0.5 end
    if K.AAXMR.state then return -math.pi*0.5 end
    if K.AAXMB.state then return math.pi end
    if K.AAXMF.state then return 0 end
    return nil
end
local function aa_base_tick()
    if not T.AAEnabled then return end
    if not alive(LP) then return end
    local hrp=LP.Character.HumanoidRootPart
    local hum=LP.Character:FindFirstChildOfClass("Humanoid"); if not hum then return end
    hum.AutoRotate=false
    local yaw=0; local m=O.AAYawMode
    if m=="Backwards" then yaw=math.pi
    elseif m=="Jitter" then yaw=((os.clock()*6)%2<1) and math.pi/2 or -math.pi/2
    elseif m=="Spin" then yaw=(os.clock()*8)%(math.pi*2)
    elseif m=="Zero" then yaw=0
    elseif m=="Sideways" then yaw=math.pi/2
    elseif m=="Random" then yaw=math.rad(math.random(-180,180))
    elseif m=="LBY-Break" then yaw=math.sin(os.clock()*3)*math.pi end
    if K.AAInvert and K.AAInvert.state then yaw=-yaw end
    yaw=yaw+math.rad(O.AADesync)
    local pitch=0
    if T.AAPitchOn then
        local p=O.AAPitch
        if p=="Down" then pitch=math.rad(-89)
        elseif p=="Up" then pitch=math.rad(89)
        elseif p=="Zero" then pitch=0
        elseif p=="Jitter" then pitch=((os.clock()*10)%2<1) and math.rad(-89) or math.rad(89) end
    end
    hrp.CFrame=CFrame.new(hrp.Position)*CFrame.Angles(pitch,yaw,0)
    S.desyncYaw=yaw
end
local function aax_tick()
    if not T.AAXOn then return end
    if not alive(LP) then return end
    local hrp=LP.Character.HumanoidRootPart
    local hum=LP.Character:FindFirstChildOfClass("Humanoid"); if not hum then return end
    hum.AutoRotate=false
    local base=O.AAXBase; local yaw=0
    local md=manual_dir()
    if md then yaw=md
    elseif base=="At-Targets" and T.AAXAtTgt then yaw=at_targets_yaw()
    elseif base=="Freestanding" and T.AAXFree then yaw=math.pi+freestand_side()*math.rad(O.AAXDesyncR)
    elseif base=="Target" and S.target and alive(S.target) then
        local to=S.target.Character.HumanoidRootPart.Position-hrp.Position
        yaw=math.atan2(to.X,to.Z)+math.pi
    elseif base=="Local" then yaw=select(2,Camera.CFrame:ToEulerAnglesYXZ())
    else yaw=0 end
    yaw=yaw+math.rad(O.AAXYawAdd)
    local mod=O.AAXMod; local deg=math.rad(O.AAXModDeg); local hz=O.AAXModHz
    if mod=="Offset" then yaw+=deg
    elseif mod=="Spin" then yaw+=(os.clock()*hz)%(math.pi*2)
    elseif mod=="Jitter" then yaw+=((os.clock()*hz)%2<1) and deg or -deg
    elseif mod=="Random" then yaw+=math.rad(math.random(-math.deg(deg),math.deg(deg)))
    elseif mod=="Sway" then yaw+=math.sin(os.clock()*hz)*deg end
    if T.AAXDesyncReal then
        S.aaSide=-S.aaSide
        local d = (S.aaSide>0) and O.AAXDesyncR or -O.AAXDesyncL
        yaw+=math.rad(d)
    end
    if K.AAXFlip and K.AAXFlip.state then yaw=-yaw end
    if T.AAXLBY then yaw+=math.sin(os.clock()*4)*math.rad(5) end
    if T.AAXMicro then yaw+=math.rad(math.random(-O.AAXMicroDeg,O.AAXMicroDeg)) end
    if T.AAXOnShot and os.clock()<S.onShotUntil then yaw+=math.rad(O.AAXOSDeg) end
    if T.AAXDef and os.clock()<S.defUntil then yaw+=math.rad(math.sin(os.clock()*18)*25) end
    local p=O.AAXPitch; local pd=math.rad(O.AAXPitchDeg); local pitch=0
    if p=="Down" then pitch=-pd
    elseif p=="Up" then pitch=pd
    elseif p=="Zero" then pitch=0
    elseif p=="Fake" then pitch=((math.floor(os.clock()*4)%2)==0) and -pd or pd
    elseif p=="Jitter" then pitch=(os.clock()*10)%2<1 and -pd or pd end
    local r=O.AAXRoll; local rd=math.rad(O.AAXRollDeg); local roll=0
    if r=="Left" then roll=-rd
    elseif r=="Right" then roll=rd
    elseif r=="Alternate" then roll=((math.floor(os.clock()*2)%2)==0) and rd or -rd
    elseif r=="Sway" then roll=math.sin(os.clock()*2)*rd end
    if T.AAXSway then
        yaw+=math.sin(os.clock()*O.AAXSwayHz)*math.rad(O.AAXSwayDeg)
        pitch+=math.cos(os.clock()*O.AAXSwayHz)*math.rad(O.AAXSwayDeg*0.4)
    end
    hrp.CFrame=CFrame.new(hrp.Position)*CFrame.Angles(pitch,yaw,roll)
    S.desyncYaw=yaw
end

-- fake position engines
local function ghost(key,color)
    local g=V4.Ghosts[key]
    if g and g.Parent then return g end
    g=Instance.new("Part"); g.Size=Vector3.new(2,5,1); g.Anchored=true; g.CanCollide=false
    g.Material=Enum.Material.ForceField; g.Color=color or Color3.fromRGB(190,100,255); g.Transparency=0.4
    g.Parent=Workspace; V4.Ghosts[key]=g; return g
end
local function killGhost(k) if V4.Ghosts[k] then V4.Ghosts[k]:Destroy(); V4.Ghosts[k]=nil end end

local function fakepos_tick()
    if not T.FPOn then killGhost("g1") killGhost("g2") return end
    if not alive(LP) then return end
    local hrp=LP.Character.HumanoidRootPart
    local e=O.FPEngine; local R=O.FPRadius; local H=O.FPHeight; local t=os.clock()*O.FPSpeed
    local p1,p2
    if e=="Static" then p1=hrp.Position+Vector3.new(R,H,0); p2=hrp.Position-Vector3.new(R,H,0)
    elseif e=="Orbit" then p1=hrp.Position+Vector3.new(math.cos(t)*R,H,math.sin(t)*R); p2=p1
    elseif e=="OrbitDual" then p1=hrp.Position+Vector3.new(math.cos(t)*R,H,math.sin(t)*R); p2=hrp.Position+Vector3.new(math.cos(t+math.pi)*R,H,math.sin(t+math.pi)*R)
    elseif e=="Random" then p1=hrp.Position+Vector3.new((math.random()*2-1)*R,H,(math.random()*2-1)*R); p2=hrp.Position-Vector3.new((math.random()*2-1)*R,H,(math.random()*2-1)*R)
    elseif e=="Behind" then p1=hrp.Position-hrp.CFrame.LookVector*R+Vector3.new(0,H,0); p2=p1
    elseif e=="Teleport" then p1=hrp.Position+(((math.floor(t*2)%2)==0) and Vector3.new(R,H,0) or Vector3.new(-R,H,0)); p2=p1
    elseif e=="Zigzag" then p1=hrp.Position+Vector3.new(math.sin(t*3)*R,H,math.cos(t)*R); p2=p1
    elseif e=="PathReplay" then local rec=self_bt(O.FPReplayMs); p1=rec and rec.cf.Position or hrp.Position; p2=hrp.Position+Vector3.new(math.cos(t)*R*0.5,H,math.sin(t)*R*0.5)
    elseif e=="Mirror" then if S.target and alive(S.target) then local Tp=S.target.Character.HumanoidRootPart.Position; p1=Tp*2-hrp.Position+Vector3.new(0,H,0); p2=hrp.Position+(hrp.Position-Tp).Unit*R+Vector3.new(0,H,0) else p1=hrp.Position+Vector3.new(R,H,0); p2=hrp.Position-Vector3.new(R,H,0) end
    elseif e=="PingTP" then local ph=(math.floor(t*2)%3); p1=(ph==0) and hrp.Position+Vector3.new(R,H,0) or (ph==1) and hrp.Position+Vector3.new(0,H,R) or hrp.Position-Vector3.new(R,H,0); p2=hrp.Position-(p1-hrp.Position)
    elseif e=="Split" then p1=hrp.Position+Vector3.new(R,H,R); p2=hrp.Position+Vector3.new(-R,H,-R)
    elseif e=="Choke-Freeze" then p1=S.frozenAt or hrp.Position; p2=hrp.Position+Vector3.new(math.cos(t)*R,H,math.sin(t)*R)
    elseif e=="Warp" then p1=hrp.Position+hrp.CFrame.LookVector*R+Vector3.new(0,H,0); p2=hrp.Position-hrp.CFrame.LookVector*R+Vector3.new(0,H,0)
    elseif e=="MouseDrag" then local m=UserInputService:GetMouseLocation(); local ray=Camera:ViewportPointToRay(m.X,m.Y,R); p1=ray.Origin+ray.Direction*R; p2=p1 end
    if T.FPBlink and K.FPBlinkKey.state then p1=p1+hrp.CFrame.RightVector*O.FPBlinkDist end
    local col=Color3.fromRGB(190,100,255)
    if T.FPColor then col=Color3.fromHSV((os.clock()*0.2)%1,0.9,1) end
    local g1=ghost("g1",col); g1.CFrame=CFrame.new(p1); g1.Transparency=O.FPAlpha; g1.Color=col
    if T.FPDual and p2 then local g2=ghost("g2",col:Lerp(Color3.new(1,1,1),0.4)); g2.CFrame=CFrame.new(p2); g2.Transparency=O.FPAlpha*0.9 else killGhost("g2") end
end

-- fakelag
local function fakelag_tick()
    if not T.FakeLag then S.chokeCounter=0; S.choke=0; return end
    if not alive(LP) then return end
    local m=O.FakeLagMode; local maxT=O.FakeLagT; local hrp=LP.Character.HumanoidRootPart
    S.chokeCounter+=1
    local target=maxT
    if m=="Adaptive" then target=math.random(math.max(1,maxT-2),maxT)
    elseif m=="Jitter" then target=(S.chokeCounter%2==0) and maxT or 1
    elseif m=="OnMove" then target=(hrp.AssemblyLinearVelocity.Magnitude>2) and maxT or 1
    elseif m=="OnPeek" then target=K.RageKey.state and maxT or 1 end
    if S.chokeCounter<target then pcall(function() hrp.CanCollide=hrp.CanCollide end); S.choke=S.chokeCounter
    else S.chokeCounter=0; S.choke=0 end
end

-- legit + trigger
local function legit_tick()
    if not T.LegitOn then return end
    if not K.LegitKey.state then return end
    local m=UserInputService:GetMouseLocation()
    local best,bd
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP and alive(p) and enemyOf(p) then
            local part=p.Character:FindFirstChild(O.LegitHB=="Torso" and "UpperTorso" or "Head") or p.Character:FindFirstChild("HumanoidRootPart")
            if part then local s,on=w2s(part.Position); if on then local d=(s-m).Magnitude; if d<=O.LegitFov and (not T.LegitVis or los(Camera.CFrame.Position,part)) then if not bd or d<bd then bd,best=d,part end end end end
        end
    end
    if best and mousemoverel then
        local s=w2s(best.Position); local dx=(s-m)/O.LegitSmooth
        mousemoverel(dx.X,dx.Y)
    end
end
local lastTrig=0
local function trigger_tick()
    if not T.TrigOn then return end
    if not K.TrigKey.state then return end
    if os.clock()-lastTrig<O.TrigReset then return end
    local m=UserInputService:GetMouseLocation()
    local ray=Camera:ViewportPointToRay(m.X,m.Y)
    local rp=RaycastParams.new(); rp.FilterDescendantsInstances={LP.Character,Camera}; rp.FilterType=Enum.RaycastFilterType.Exclude
    local r=Workspace:Raycast(ray.Origin,ray.Direction*500,rp)
    if r and r.Instance then
        local part=r.Instance
        if T.TrigHeadOnly and part.Name~="Head" then return end
        local p=Players:GetPlayerFromCharacter(part.Parent) or Players:GetPlayerFromCharacter(part.Parent.Parent)
        if p and enemyOf(p) then lastTrig=os.clock(); for i=1,O.TrigBurst do task.wait(O.TrigDelay); fire_shot() end end
    end
end

-- movement + fly
local flyBV, flyBG
local function fly_update()
    if not alive(LP) then return end
    local hrp=LP.Character.HumanoidRootPart
    local on = T.Fly or K.FlyKey.state
    if on then
        if not flyBV then
            flyBV=Instance.new("BodyVelocity"); flyBV.MaxForce=Vector3.new(1,1,1)*1e9; flyBV.Velocity=Vector3.new(); flyBV.Parent=hrp
            flyBG=Instance.new("BodyGyro"); flyBG.MaxTorque=Vector3.new(1,1,1)*1e9; flyBG.Parent=hrp
        end
        local c=Camera.CFrame; local v=Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then v+=c.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then v-=c.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then v-=c.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then v+=c.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then v+=Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then v-=Vector3.new(0,1,0) end
        flyBV.Velocity = v.Magnitude>0 and v.Unit*O.FlySpd or Vector3.new()
        flyBG.CFrame = c
    elseif flyBV then flyBV:Destroy(); flyBG:Destroy(); flyBV=nil; flyBG=nil end
end
local function move_tick()
    if not alive(LP) then return end
    local hum=LP.Character:FindFirstChildOfClass("Humanoid"); if not hum then return end
    if T.WsOn then hum.WalkSpeed=O.Ws end
    if T.JpOn then hum.JumpPower=O.Jp end
    if T.Bhop and hum:GetState()==Enum.HumanoidStateType.Landed then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    if T.Noclip then for _,p in ipairs(LP.Character:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end
    fly_update()
end
addConn(UserInputService.JumpRequest:Connect(function()
    if T.InfJump and alive(LP) then LP.Character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping) end
end))

-- world
local origFog = Lighting.FogEnd; local origBr = Lighting.Brightness
local function world_tick()
    Lighting.FogEnd = T.NoFog and 1e9 or origFog
    Lighting.Brightness = T.FullBright and O.Bright or origBr
    if T.TimeLock then Lighting.ClockTime=12 end
    Camera.FieldOfView = T.CamFovOn and O.CamFov or 70
    if T.ThirdP then LP.CameraMode=Enum.CameraMode.Classic; LP.CameraMaxZoomDistance=O.TPDist; LP.CameraMinZoomDistance=O.TPDist
    else LP.CameraMaxZoomDistance=128; LP.CameraMinZoomDistance=0.5 end
end

-- esp
local function esp_ensure(p)
    local e=V4.ESP[p]; if e then return e end
    e={}
    local hl=Instance.new("Highlight"); hl.FillTransparency=0.5; hl.Enabled=false; hl.Parent=Workspace; e.hl=hl
    e.box=addDraw(Drawing.new("Square")); e.box.Thickness=1; e.box.Filled=false
    e.name=addDraw(Drawing.new("Text")); e.name.Size=14; e.name.Center=true; e.name.Outline=true
    e.hpbg=addDraw(Drawing.new("Square")); e.hpbg.Filled=true
    e.hp  =addDraw(Drawing.new("Square")); e.hp.Filled=true
    e.dist=addDraw(Drawing.new("Text")); e.dist.Size=12; e.dist.Center=true; e.dist.Outline=true
    e.tracer=addDraw(Drawing.new("Line")); e.tracer.Thickness=1
    for _,d in pairs(e) do if typeof(d)=="table" and d.Visible~=nil then d.Visible=false end end
    V4.ESP[p]=e; return e
end
local function esp_destroy(p)
    local e=V4.ESP[p]; if not e then return end
    if e.hl then e.hl:Destroy() end
    for _,d in pairs(e) do if typeof(d)=="table" and d.Remove then d:Remove() end end
    V4.ESP[p]=nil
end
addConn(Players.PlayerRemoving:Connect(esp_destroy))
local function esp_tick()
    local on=T.EspOn
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP then
            local e=esp_ensure(p)
            local show = on and alive(p) and (enemyOf(p) or T.EspTeamShow)
            local col = T.EspTeamColor and (p.TeamColor and p.TeamColor.Color) or (enemyOf(p) and O.EspColor or O.EspFriendColor)
            if show then
                local char=p.Character; local hrp=char.HumanoidRootPart; local head=char:FindFirstChild("Head") or hrp
                local hum=char:FindFirstChildOfClass("Humanoid")
                local s1,on1=w2s(head.Position+Vector3.new(0,0.5,0))
                local s2,on2=w2s(hrp.Position+Vector3.new(0,-3,0))
                if on1 and on2 then
                    local h=s2.Y-s1.Y; local w=h*0.55
                    if T.EspBox then e.box.Visible=true; e.box.Size=Vector2.new(w,h); e.box.Position=Vector2.new(s1.X-w/2,s1.Y); e.box.Color=col else e.box.Visible=false end
                    if T.EspName then e.name.Visible=true; e.name.Text=p.Name; e.name.Position=Vector2.new(s1.X,s1.Y-16); e.name.Color=col else e.name.Visible=false end
                    if T.EspHealth and hum then
                        local hp=math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
                        e.hpbg.Visible=true; e.hp.Visible=true
                        e.hpbg.Position=Vector2.new(s1.X-w/2-6,s1.Y); e.hpbg.Size=Vector2.new(3,h); e.hpbg.Color=Color3.new(0,0,0)
                        e.hp.Position=Vector2.new(s1.X-w/2-6,s1.Y+h*(1-hp)); e.hp.Size=Vector2.new(3,h*hp)
                        e.hp.Color=Color3.fromRGB(math.floor(255-hp*255),math.floor(hp*255),40)
                    else e.hpbg.Visible=false; e.hp.Visible=false end
                    if T.EspDist then e.dist.Visible=true; e.dist.Text=string.format("%.0fs",(hrp.Position-Camera.CFrame.Position).Magnitude); e.dist.Position=Vector2.new(s1.X,s2.Y+2); e.dist.Color=col else e.dist.Visible=false end
                    if T.EspTracer then
                        e.tracer.Visible=true; local o=O.EspTracerO; local vp=Camera.ViewportSize
                        e.tracer.From = (o=="Bottom") and Vector2.new(vp.X/2,vp.Y) or (o=="Top") and Vector2.new(vp.X/2,0) or UserInputService:GetMouseLocation()
                        e.tracer.To=Vector2.new(s2.X,s2.Y); e.tracer.Color=col
                    else e.tracer.Visible=false end
                    if T.ChamsOn then
                        e.hl.Enabled=true; e.hl.Adornee=char; e.hl.FillColor=col
                        if T.ChamsVisCheck and los(Camera.CFrame.Position,head) then e.hl.FillColor=O.ChamsVisColor end
                        e.hl.FillTransparency=O.ChamsFill
                    else e.hl.Enabled=false end
                else for _,d in pairs(e) do if typeof(d)=="table" and d.Visible~=nil then d.Visible=false end end; e.hl.Enabled=false end
            else for _,d in pairs(e) do if typeof(d)=="table" and d.Visible~=nil then d.Visible=false end end; e.hl.Enabled=false end
        end
    end
end

-- HUD
local fovCircle=addDraw(Drawing.new("Circle")); fovCircle.Thickness=1; fovCircle.NumSides=64; fovCircle.Filled=false
local legitFov=addDraw(Drawing.new("Circle")); legitFov.Thickness=1; legitFov.NumSides=64; legitFov.Filled=false
local tgtBox=addDraw(Drawing.new("Square")); tgtBox.Thickness=2; tgtBox.Filled=false
local hcBar=addDraw(Drawing.new("Square")); hcBar.Filled=false
local hcFill=addDraw(Drawing.new("Square")); hcFill.Filled=true
local statsTx=addDraw(Drawing.new("Text")); statsTx.Size=14; statsTx.Outline=true
local wmTx=addDraw(Drawing.new("Text")); wmTx.Size=16; wmTx.Outline=true
local arrow=addDraw(Drawing.new("Triangle")); arrow.Filled=true; arrow.Color=Color3.fromRGB(190,100,255)
local xh={v1=addDraw(Drawing.new("Line")),v2=addDraw(Drawing.new("Line")),h1=addDraw(Drawing.new("Line")),h2=addDraw(Drawing.new("Line")),dot=addDraw(Drawing.new("Circle"))}

local function hud_tick()
    local m=UserInputService:GetMouseLocation()
    fovCircle.Visible = T.VisFov and T.RageEnabled
    fovCircle.Position=m; fovCircle.Radius=O.RageFov; fovCircle.Color=O.VisFovColor
    legitFov.Visible = T.VisLegitFov and T.LegitOn
    legitFov.Position=m; legitFov.Radius=O.LegitFov; legitFov.Color=Color3.fromRGB(255,200,0)
    if T.VisTargetBox and S.target and alive(S.target) then
        local hrp=S.target.Character.HumanoidRootPart; local s,on=w2s(hrp.Position)
        if on then tgtBox.Visible=true; tgtBox.Size=Vector2.new(90,140); tgtBox.Position=s-Vector2.new(45,70); tgtBox.Color = S.hitChance>70 and Color3.fromRGB(80,230,160) or Color3.fromRGB(255,160,60)
        else tgtBox.Visible=false end
    else tgtBox.Visible=false end
    hcBar.Visible=T.VisHcBar; hcFill.Visible=T.VisHcBar
    if T.VisHcBar then
        hcBar.Position=Vector2.new(20,Camera.ViewportSize.Y-80); hcBar.Size=Vector2.new(200,14); hcBar.Color=Color3.new(1,1,1)
        hcFill.Position=hcBar.Position+Vector2.new(1,1); hcFill.Size=Vector2.new((S.hitChance/100)*198,12)
        hcFill.Color=Color3.fromRGB(math.floor(255-S.hitChance*2.55),math.floor(S.hitChance*2.55),40)
    end
    statsTx.Visible=T.VisStats
    if T.VisStats then statsTx.Position=Vector2.new(20,Camera.ViewportSize.Y-110); statsTx.Text=string.format("UE V4 | shots:%d hits:%d kills:%d hc:%.0f%% choke:%d",S.stats.shots,S.stats.hits,S.stats.kills,S.hitChance,S.choke); statsTx.Color=Color3.fromRGB(190,100,255) end
    wmTx.Visible=T.VisWater
    if T.VisWater then wmTx.Position=Vector2.new(Camera.ViewportSize.X-280,10); wmTx.Text="UE V4 | olivia | discord.gg/ojailbreaks"; wmTx.Color=Color3.fromRGB(190,100,255) end
    arrow.Visible = T.AAXArrow and (T.AAEnabled or T.AAXOn)
    if arrow.Visible then
        local c=Camera.ViewportSize/2; local y=S.desyncYaw or 0
        local tip=c+Vector2.new(math.sin(y),-math.cos(y))*50
        local l=c+Vector2.new(math.sin(y+2.6),-math.cos(y+2.6))*15
        local r=c+Vector2.new(math.sin(y-2.6),-math.cos(y-2.6))*15
        arrow.PointA=tip; arrow.PointB=l; arrow.PointC=r
    end
    local xe=T.XhOn
    for _,l in pairs(xh) do l.Visible=xe end
    if xe then
        local c=Camera.ViewportSize/2
        local sz=O.XhSize; local gp=O.XhGap; local th=O.XhThick; local col=O.XhColor
        xh.v1.From=c-Vector2.new(0,gp+sz); xh.v1.To=c-Vector2.new(0,gp); xh.v1.Color=col; xh.v1.Thickness=th
        xh.v2.From=c+Vector2.new(0,gp); xh.v2.To=c+Vector2.new(0,gp+sz); xh.v2.Color=col; xh.v2.Thickness=th
        xh.h1.From=c-Vector2.new(gp+sz,0); xh.h1.To=c-Vector2.new(gp,0); xh.h1.Color=col; xh.h1.Thickness=th
        xh.h2.From=c+Vector2.new(gp,0); xh.h2.To=c+Vector2.new(gp+sz,0); xh.h2.Color=col; xh.h2.Thickness=th
        xh.dot.Position=c; xh.dot.Radius=1; xh.dot.Color=col; xh.dot.Filled=true
    end
end

-- kill detection
addConn(Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function(c)
        local hum=c:WaitForChild("Humanoid",5); if not hum then return end
        hum.Died:Connect(function()
            if S.target==p then
                S.stats.kills+=1; S.lastKillAt=os.clock(); resolver_hit(p)
                if T.HitSound then local s=Instance.new("Sound"); s.SoundId="rbxassetid://3744371091"; s.Volume=O.HitVol; s.Parent=LP.PlayerGui or LP; s:Play(); game:GetService("Debris"):AddItem(s,2) end
            end
        end)
    end)
end))

-- anti afk
pcall(function()
    addConn(LP.Idled:Connect(function()
        if T.AntiAfk then VirtualInput:Button2Down(Vector2.new(),game); task.wait(1); VirtualInput:Button2Up(Vector2.new(),game) end
    end))
end)

-- menu toggle hotkey
addConn(UserInputService.InputBegan:Connect(function(i,gpe)
    if gpe then return end
    if K.MenuKey and typeof(K.MenuKey.k)=="EnumItem" and i.KeyCode==K.MenuKey.k then
        Root.Visible = not Root.Visible
    end
end))

-- scheduler
addConn(RunService.Heartbeat:Connect(function()
    for _,p in ipairs(Players:GetPlayers()) do if p~=LP then bt_push(p) end end
    self_bt_push()
    rage_tick()
    legit_tick()
    trigger_tick()
    fakepos_tick()
    aa_base_tick()
    aax_tick()
    fakelag_tick()
    move_tick()
    world_tick()
    esp_tick()
    hud_tick()
end))

-------------------------------------------------
-- 5. unload
-------------------------------------------------
V4.Unload = function()
    for _,c in ipairs(V4.Conns) do pcall(function() c:Disconnect() end) end
    for _,d in ipairs(V4.Draws) do pcall(function() d:Remove() end) end
    for k,_ in pairs(V4.Ghosts) do V4.Ghosts[k]:Destroy() end
    for p,_ in pairs(V4.ESP) do esp_destroy(p) end
    if flyBV then flyBV:Destroy() end
    if flyBG then flyBG:Destroy() end
    Lighting.FogEnd=origFog; Lighting.Brightness=origBr
    Camera.FieldOfView=70
    Screen:Destroy()
    getgenv().UEV4 = nil
end
