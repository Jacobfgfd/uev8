--[[
    Unnamed Enhancements V3 — built by Olivia — https://discord.gg/ojailbreaks
    Rider on top of the Yokai UE base. One file, one breath.
--]]

------------------------------------------------------------
-- 0. services + bootstrap
------------------------------------------------------------
local HttpService       = game:GetService("HttpService")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")
local VirtualInput      = game:GetService("VirtualInputManager")
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")
local Camera            = Workspace.CurrentCamera
local LP                = Players.LocalPlayer

local UE_URL = "https://raw.githubusercontent.com/Jacobfgfd/yokai/refs/heads/main/main.lua"

if not getgenv().UE_LOADED then
    local ok, err = pcall(function()
        loadstring(game:HttpGet(UE_URL))()
    end)
    assert(ok, "UE base failed: " .. tostring(err))
end

local function waitFor(key, timeout)
    local t0 = os.clock()
    while not getgenv()[key] do
        if os.clock() - t0 > (timeout or 15) then
            error("timeout waiting for " .. key, 0)
        end
        task.wait()
    end
    return getgenv()[key]
end

local Library  = waitFor("Library")
local Options  = waitFor("Options")
local Toggles  = waitFor("Toggles")

-- unload previous v3 if present
if getgenv().UE_V3 and getgenv().UE_V3.Unload then
    pcall(getgenv().UE_V3.Unload)
end

------------------------------------------------------------
-- 1. state
------------------------------------------------------------
local State = {
    Target          = nil,
    LastTarget      = nil,
    LastSwitch      = 0,
    AimPos          = nil,
    HitChance       = 0,
    Resolver        = {},
    Backtrack       = {},
    FakeGhost       = nil,
    FakeOrigin      = nil,
    Choke           = 0,
    LastShot        = 0,
    KillLog         = {},
    HitLog          = {},
    DoubleTapCharge = 0,
    LastDesyncYaw   = 0,
    HideshotsActive = false,
    Connections     = {},
    Drawings        = {},
    Highlights      = {},
    Chams           = {},
    PrevStates      = {},
    Stats           = { shots=0, hits=0, kills=0, startTime=os.clock() },
}
getgenv().UE_V3 = State

local BT_WINDOW = 1.0

local function trackConn(c)  table.insert(State.Connections, c) return c end
local function trackDraw(d)  table.insert(State.Drawings, d) return d end

------------------------------------------------------------
-- 2. window + tabs
------------------------------------------------------------
local Window = Library:CreateWindow({
    Title       = "Unnamed Enhancements V3  |  olivia · discord.gg/ojailbreaks",
    Center      = true,
    AutoShow    = true,
    TabPadding  = 8,
    MenuFadeTime= 0.2,
})

local Tabs = {
    Rage    = Window:AddTab("Ragebot"),
    RageX   = Window:AddTab("Rage+ (Peak)"),
    Fake    = Window:AddTab("Anti-Aim"),
    FakeX   = Window:AddTab("AA+ (Peak)"),
    FakeP   = Window:AddTab("Fake Pos+ (Peak)"),
    AWall   = Window:AddTab("Autowall / Resolver"),
    Legit   = Window:AddTab("Legit / Trigger"),
    ESP     = Window:AddTab("ESP+"),
    Visual  = Window:AddTab("Visuals+"),
    World   = Window:AddTab("World"),
    Move    = Window:AddTab("Movement+"),
    Misc    = Window:AddTab("Misc+"),
    Log     = Window:AddTab("Logs"),
    Config  = Window:AddTab("Config"),
}

------------------------------------------------------------
-- 2.5 RAGE+ (Peak) UI
------------------------------------------------------------
local RX  = Tabs.RageX:AddLeftGroupbox("Delta / Safepoint")
local RX2 = Tabs.RageX:AddLeftGroupbox("Teleport Aim / Blink")
local RX3 = Tabs.RageX:AddRightGroupbox("Rate / Damage Shaping")
local RX4 = Tabs.RageX:AddRightGroupbox("Behavior")

RX:AddToggle("RageSafepoint",      {Text = "Force Safepoint", Default = true})
RX:AddSlider("RageSafepointBias",  {Text = "Safepoint Bias", Default = 0.6, Min = 0, Max = 1, Rounding = 2})
RX:AddToggle("RageDeltaShot",      {Text = "Delta Shot (between frames)", Default = false})
RX:AddSlider("RageDeltaMs",        {Text = "Delta Window", Default = 60, Min = 1, Max = 400, Rounding = 0, Suffix = "ms"})
RX:AddToggle("RageExtendBT",       {Text = "Extended Backtrack (2s)", Default = false})
RX:AddToggle("RageDamageAvg",      {Text = "Damage Averaging", Default = true})
RX:AddSlider("RageDmgCeiling",     {Text = "Damage Ceiling", Default = 100, Min = 1, Max = 200, Rounding = 0})
RX:AddToggle("RageForceHS",        {Text = "Force Headshot", Default = false})

RX2:AddToggle("RageTPAim",         {Text = "Teleport Aim (snap to target)", Default = false})
RX2:AddSlider("RageTPAimDist",     {Text = "TP Aim Distance", Default = 10, Min = 2, Max = 40, Rounding = 0, Suffix = "s"})
RX2:AddToggle("RageBlink",         {Text = "Blink (stack choked pos)", Default = false})
RX2:AddSlider("RageBlinkTicks",    {Text = "Blink Ticks", Default = 12, Min = 2, Max = 28, Rounding = 0})
RX2:AddLabel("Blink Key"):AddKeyPicker("RageBlinkKey", {Default = "T", Mode = "Hold", Text = "Blink"})
RX2:AddToggle("RageFakeDuck",      {Text = "Fake Duck", Default = false})
RX2:AddLabel("Fake Duck"):AddKeyPicker("RageFakeDuckKey", {Default = "H", Mode = "Toggle", Text = "Duck"})
RX2:AddToggle("RageSlowWalk",      {Text = "Slow Walk", Default = false})
RX2:AddSlider("RageSlowSpeed",     {Text = "Slow Speed", Default = 4, Min = 1, Max = 16, Rounding = 0})
RX2:AddLabel("Slow Walk"):AddKeyPicker("RageSlowKey", {Default = "LeftShift", Mode = "Hold", Text = "Slow"})

RX3:AddSlider("RageShotsPerSec",   {Text = "Max Shots/sec", Default = 10, Min = 1, Max = 30, Rounding = 0})
RX3:AddSlider("RageMinConfidence", {Text = "Min Confidence", Default = 65, Min = 0, Max = 100, Rounding = 0, Suffix = "%"})
RX3:AddToggle("RageQuickStop",     {Text = "Quick Stop", Default = false})
RX3:AddToggle("RageAutoRevolver",  {Text = "Auto Pre-Trigger", Default = false})
RX3:AddToggle("RageIgnoreCrouch",  {Text = "Ignore Crouching", Default = false})
RX3:AddToggle("RageIgnoreTeammate",{Text = "Ignore Teammate Line", Default = true})

RX4:AddToggle("RageAdaptiveBaim",  {Text = "Adaptive Body Aim", Default = true})
RX4:AddSlider("RageBaimMiss",      {Text = "Baim After N Misses", Default = 2, Min = 1, Max = 6, Rounding = 0})
RX4:AddToggle("RageNoScope",       {Text = "Allow No-Scope", Default = false})
RX4:AddToggle("RageFastFire",      {Text = "Fast Fire (ignore cooldown)", Default = false})
RX4:AddToggle("RageAimCone",       {Text = "Compensate Spread Cone", Default = true})
RX4:AddSlider("RageConeSamples",   {Text = "Cone Samples", Default = 8, Min = 1, Max = 32, Rounding = 0})
RX4:AddToggle("RagePenTeammate",   {Text = "Pen Through Teammates", Default = false})
RX4:AddToggle("RageAutoStopOnPeek",{Text = "Auto Stop on Peek", Default = false})

------------------------------------------------------------
-- 4.5 ANTI-AIM+ (Peak) UI
------------------------------------------------------------
local AX  = Tabs.FakeX:AddLeftGroupbox("Yaw Base")
local AX2 = Tabs.FakeX:AddLeftGroupbox("Yaw Modifiers")
local AX3 = Tabs.FakeX:AddRightGroupbox("Pitch / Roll / Sway")
local AX4 = Tabs.FakeX:AddRightGroupbox("Manual / On-Shot / Defensive")
local AX5 = Tabs.FakeX:AddRightGroupbox("Freestanding / At-Targets")

AX:AddToggle("AAXEnabled",         {Text = "Enable AA+", Default = false})
AX:AddDropdown("AAXYawBase",       {Text = "Yaw Base", Values = {"Target","Local","At-Targets","Freestanding","Static"}, Default = "At-Targets", Multi = false})
AX:AddSlider("AAXYawAdd",          {Text = "Yaw Add", Default = 0, Min = -180, Max = 180, Rounding = 0, Suffix = "°"})
AX:AddDropdown("AAXYawMod",        {Text = "Yaw Modifier", Values = {"None","Center","Offset","Spin","Random","Jitter","Sway"}, Default = "Jitter", Multi = false})
AX:AddSlider("AAXYawModDeg",       {Text = "Modifier Deg", Default = 15, Min = 0, Max = 180, Rounding = 0, Suffix = "°"})
AX:AddSlider("AAXYawModHz",        {Text = "Modifier Hz", Default = 8, Min = 0.1, Max = 30, Rounding = 1})

AX2:AddToggle("AAXDesyncReal",     {Text = "Desync Real", Default = true})
AX2:AddSlider("AAXDesyncL",        {Text = "Desync Left", Default = 58, Min = 0, Max = 60, Rounding = 0, Suffix = "°"})
AX2:AddSlider("AAXDesyncR",        {Text = "Desync Right", Default = 58, Min = 0, Max = 60, Rounding = 0, Suffix = "°"})
AX2:AddToggle("AAXLBYBreak",       {Text = "LBY Breaker", Default = true})
AX2:AddToggle("AAXYawJitterExtra", {Text = "Yaw Micro-Jitter", Default = true})
AX2:AddSlider("AAXMicroDeg",       {Text = "Micro Jitter Deg", Default = 3, Min = 0, Max = 20, Rounding = 0, Suffix = "°"})
AX2:AddToggle("AAXEdgeYaw",        {Text = "Edge Yaw", Default = false})
AX2:AddToggle("AAXBodyYaw",        {Text = "Body Yaw (fake upper)", Default = true})
AX2:AddSlider("AAXBodyYawDeg",     {Text = "Body Yaw Deg", Default = 90, Min = 0, Max = 180, Rounding = 0, Suffix = "°"})

AX3:AddDropdown("AAXPitch",        {Text = "Pitch", Values = {"None","Down","Up","Zero","Fake","Jitter"}, Default = "Down", Multi = false})
AX3:AddSlider("AAXPitchDeg",       {Text = "Pitch Deg", Default = 89, Min = 0, Max = 89, Rounding = 0, Suffix = "°"})
AX3:AddDropdown("AAXRoll",         {Text = "Roll", Values = {"None","Left","Right","Alternate","Sway"}, Default = "None", Multi = false})
AX3:AddSlider("AAXRollDeg",        {Text = "Roll Deg", Default = 30, Min = 0, Max = 180, Rounding = 0, Suffix = "°"})
AX3:AddToggle("AAXSway",           {Text = "Sine Sway", Default = false})
AX3:AddSlider("AAXSwayHz",         {Text = "Sway Hz", Default = 1.5, Min = 0.1, Max = 20, Rounding = 1})
AX3:AddSlider("AAXSwayDeg",        {Text = "Sway Deg", Default = 8, Min = 0, Max = 60, Rounding = 0, Suffix = "°"})

AX4:AddToggle("AAXManual",         {Text = "Enable Manual AA", Default = false})
AX4:AddLabel("Manual Left"):AddKeyPicker("AAXManualL", {Default = "Left", Mode = "Hold", Text = "AA L"})
AX4:AddLabel("Manual Right"):AddKeyPicker("AAXManualR", {Default = "Right", Mode = "Hold", Text = "AA R"})
AX4:AddLabel("Manual Back"):AddKeyPicker("AAXManualB", {Default = "Down", Mode = "Hold", Text = "AA B"})
AX4:AddLabel("Manual Forward"):AddKeyPicker("AAXManualF", {Default = "Up", Mode = "Hold", Text = "AA F"})
AX4:AddLabel("Inverter"):AddKeyPicker("AAXInvert", {Default = "X", Mode = "Toggle", Text = "Invert"})
AX4:AddToggle("AAXOnShot",         {Text = "On-Shot Anti-Aim", Default = true})
AX4:AddSlider("AAXOnShotDeg",      {Text = "On-Shot Flip Deg", Default = 180, Min = 0, Max = 360, Rounding = 0, Suffix = "°"})
AX4:AddSlider("AAXOnShotMs",       {Text = "On-Shot Hold", Default = 220, Min = 50, Max = 1000, Rounding = 0, Suffix = "ms"})
AX4:AddToggle("AAXDefensive",      {Text = "Defensive AA (post-shot tilt)", Default = true})
AX4:AddSlider("AAXDefMs",          {Text = "Defensive Hold", Default = 320, Min = 50, Max = 1500, Rounding = 0, Suffix = "ms"})

AX5:AddToggle("AAXFreestand",      {Text = "Freestanding (walls)", Default = true})
AX5:AddSlider("AAXFreeDist",       {Text = "Freestand Scan Dist", Default = 20, Min = 2, Max = 60, Rounding = 0, Suffix = "s"})
AX5:AddToggle("AAXAtTargets",      {Text = "At-Targets", Default = true})
AX5:AddToggle("AAXAtTargetsBest",  {Text = "Use Best (vs closest)", Default = true})
AX5:AddToggle("AAXBreakLC",        {Text = "Break Lagcomp", Default = false})
AX5:AddToggle("AAXAvoidLocal",     {Text = "Avoid Local Pitch Snaps", Default = true})
AX5:AddToggle("AAXShowArrow",      {Text = "Desync Arrow (HUD)", Default = true})

------------------------------------------------------------
-- 4.75 FAKE POS+ (Peak) UI
------------------------------------------------------------
local FX  = Tabs.FakeP:AddLeftGroupbox("Fake Position Engines")
local FX2 = Tabs.FakeP:AddRightGroupbox("Replay / Blink / Mirror")

FX:AddToggle("FPXEnabled",         {Text = "Enable Fake Pos+", Default = false})
FX:AddDropdown("FPXEngine",        {Text = "Engine", Values = {"OrbitDual","Strafe","PathReplay","Mirror","PingTP","Split","Choke-Freeze","Warp","Zigzag+"}, Default = "OrbitDual", Multi = false})
FX:AddSlider("FPXRadius",          {Text = "Radius", Default = 10, Min = 1, Max = 80, Rounding = 1, Suffix = "s"})
FX:AddSlider("FPXHeight",          {Text = "Height", Default = 0, Min = -20, Max = 20, Rounding = 1, Suffix = "s"})
FX:AddSlider("FPXSpeed",           {Text = "Speed", Default = 3, Min = 0, Max = 30, Rounding = 1})
FX:AddToggle("FPXDualGhost",       {Text = "Dual Ghost", Default = true})
FX:AddToggle("FPXColorShift",      {Text = "Color Shift Over Time", Default = true})
FX:AddSlider("FPXAlpha",           {Text = "Ghost Alpha", Default = 0.4, Min = 0, Max = 1, Rounding = 2})

FX2:AddToggle("FPXReplay",         {Text = "Path Replay (backtrack own pos)", Default = false})
FX2:AddSlider("FPXReplayMs",       {Text = "Replay Lag", Default = 350, Min = 50, Max = 1500, Rounding = 0, Suffix = "ms"})
FX2:AddToggle("FPXMirror",         {Text = "Mirror Across Target", Default = false})
FX2:AddToggle("FPXBlink",          {Text = "Blink Teleport", Default = false})
FX2:AddLabel("Blink Key"):AddKeyPicker("FPXBlinkKey", {Default = "G", Mode = "Hold", Text = "Blink"})
FX2:AddSlider("FPXBlinkDist",      {Text = "Blink Distance", Default = 8, Min = 2, Max = 40, Rounding = 1, Suffix = "s"})
FX2:AddToggle("FPXWarpOnShot",     {Text = "Warp on Shot", Default = false})
FX2:AddToggle("FPXFreezeOnPeek",   {Text = "Freeze Ghost on Peek", Default = false})
FX2:AddToggle("FPXAutoAlign",      {Text = "Align to Cover", Default = true})

------------------------------------------------------------
-- 3. Ragebot UI
------------------------------------------------------------
local RG  = Tabs.Rage:AddLeftGroupbox("Core Ragebot")
local RG2 = Tabs.Rage:AddLeftGroupbox("Target Selection")
local RG3 = Tabs.Rage:AddRightGroupbox("Hitboxes / Multipoint")
local RG4 = Tabs.Rage:AddRightGroupbox("Prediction / Hitchance / Backtrack")
local RG5 = Tabs.Rage:AddRightGroupbox("Exploits")

RG:AddToggle("RageEnabled",     {Text = "Enable Ragebot",   Default = false})
RG:AddToggle("RageSilent",      {Text = "Silent Aim",       Default = true})
RG:AddToggle("RageAutoFire",    {Text = "Auto Fire",        Default = false})
RG:AddToggle("RageAutoScope",   {Text = "Auto Scope",       Default = true})
RG:AddToggle("RageAutoStop",    {Text = "Auto Stop (freeze on shot)", Default = false})
RG:AddToggle("RageHumanize",    {Text = "Humanize Aim (curve)", Default = false})
RG:AddDropdown("RageCurve",     {Text = "Humanize Curve", Values = {"Linear","EaseIn","EaseOut","EaseInOut","Bezier","Flick"}, Default = "EaseOut", Multi = false})
RG:AddSlider("RageFov",         {Text = "FOV", Default = 80, Min = 5, Max = 500, Rounding = 0, Suffix = "px"})
RG:AddSlider("RageSmooth",      {Text = "Smoothing", Default = 3, Min = 1, Max = 20, Rounding = 1})
RG:AddSlider("RageMinDamage",   {Text = "Min Damage", Default = 1, Min = 1, Max = 150, Rounding = 0})
RG:AddDropdown("RageKey",       {Text = "Activation", Values = {"Always","Hold","Toggle"}, Default = "Hold", Multi = false})
RG:AddLabel("Rage Key"):AddKeyPicker("RageKeybind", {Default = "MB2", SyncToggleState = false, Mode = "Hold", Text = "Rage"})

RG2:AddDropdown("RagePrio",     {Text = "Priority", Values = {"FOV","Distance","Health","LowestHP","Crosshair","Visible","HighestDmg"}, Default = "FOV", Multi = false})
RG2:AddToggle("RageVisibleOnly",{Text = "Visible Targets Only", Default = false})
RG2:AddToggle("RageIgnoreFriends",{Text = "Ignore Friends", Default = true})
RG2:AddToggle("RageIgnoreTeam", {Text = "Ignore Team", Default = true})
RG2:AddToggle("RageMultiTarget",{Text = "Multi-Target Switch", Default = false})
RG2:AddSlider("RageMaxDist",    {Text = "Max Distance", Default = 500, Min = 10, Max = 5000, Rounding = 0, Suffix = "s"})
RG2:AddSlider("RageSwitchDelay",{Text = "Target Switch Delay", Default = 0.05, Min = 0, Max = 1, Rounding = 2, Suffix = "s"})
RG2:AddSlider("RageKillDelay",  {Text = "Kill Delay", Default = 0, Min = 0, Max = 1, Rounding = 2, Suffix = "s"})

RG3:AddDropdown("RageHitboxMulti",{Text = "Hitbox Priority", Values = {"Head","UpperTorso","Torso","HumanoidRootPart","LeftArm","RightArm","LeftLeg","RightLeg"}, Default = {Head=true,UpperTorso=true,Torso=true}, Multi = true})
RG3:AddSlider("RageMultipoint", {Text = "Multipoint Scale", Default = 0.75, Min = 0, Max = 1, Rounding = 2})
RG3:AddSlider("RageMultipointPts",{Text = "Multipoint Points", Default = 6, Min = 1, Max = 16, Rounding = 0})
RG3:AddToggle("RageHeadScale",  {Text = "Scale Head Hitbox", Default = false})
RG3:AddSlider("RageHeadScaleV", {Text = "Head Scale", Default = 2, Min = 1, Max = 10, Rounding = 2})
RG3:AddToggle("RageMagicBullet",{Text = "Magic Bullet Retry", Default = false})
RG3:AddSlider("RageMagicTries", {Text = "Retry Count", Default = 3, Min = 1, Max = 10, Rounding = 0})

RG4:AddToggle("RagePrediction", {Text = "Velocity Prediction", Default = true})
RG4:AddSlider("RagePredFactor", {Text = "Prediction Factor", Default = 0.16, Min = 0, Max = 1, Rounding = 2, Suffix = "s"})
RG4:AddToggle("RageAirPred",    {Text = "Air Prediction", Default = true})
RG4:AddToggle("RageCurvePred",  {Text = "Curve (parabolic)", Default = false})
RG4:AddToggle("RageHitchanceOn",{Text = "Use Hitchance Gate", Default = true})
RG4:AddSlider("RageHitChance",  {Text = "Min Hitchance %", Default = 70, Min = 0, Max = 100, Rounding = 0})
RG4:AddToggle("RageBacktrack",  {Text = "Backtrack", Default = true})
RG4:AddSlider("RageBtMs",       {Text = "Max Backtrack", Default = 200, Min = 0, Max = 1000, Rounding = 0, Suffix = "ms"})
RG4:AddToggle("RageBtOnlyBetter",{Text = "Only If Better", Default = true})

RG5:AddToggle("RageDoubleTap",  {Text = "Double Tap", Default = false})
RG5:AddSlider("RageDoubleTapTicks",{Text = "DT Charge Ticks", Default = 14, Min = 2, Max = 28, Rounding = 0})
RG5:AddToggle("RageHideshots",  {Text = "Hide Shots", Default = false})
RG5:AddToggle("RageAutoPeek",   {Text = "Auto Peek", Default = false})
RG5:AddToggle("RagePrefire",    {Text = "Prefire (corner spots)", Default = false})
RG5:AddToggle("RageQuickPeek",  {Text = "Quick Peek Assist", Default = false})
RG5:AddToggle("RageAutoKnife",  {Text = "Auto Knife on Close", Default = false})
RG5:AddSlider("RageKnifeDist",  {Text = "Knife Distance", Default = 10, Min = 2, Max = 25, Rounding = 0})

------------------------------------------------------------
-- 4. Anti-Aim UI
------------------------------------------------------------
local FG  = Tabs.Fake:AddLeftGroupbox("Fake Position")
local FG2 = Tabs.Fake:AddRightGroupbox("Yaw / Pitch Anti-Aim")
local FG3 = Tabs.Fake:AddRightGroupbox("Fakelag")

FG:AddToggle("FakeEnabled",     {Text = "Enable Fake Position", Default = false})
FG:AddDropdown("FakeMode",      {Text = "Mode", Values = {"Static","Orbit","Random","Behind","MouseDrag","Teleport","Zigzag"}, Default = "Orbit", Multi = false})
FG:AddSlider("FakeRadius",      {Text = "Radius", Default = 8, Min = 1, Max = 60, Rounding = 1, Suffix = "s"})
FG:AddSlider("FakeHeight",      {Text = "Height Offset", Default = 0, Min = -20, Max = 20, Rounding = 1, Suffix = "s"})
FG:AddSlider("FakeSpeed",       {Text = "Orbit Speed", Default = 2, Min = 0, Max = 20, Rounding = 1})
FG:AddToggle("FakeGhost",       {Text = "Show Ghost (local)", Default = true})
FG:AddSlider("FakeGhostAlpha",  {Text = "Ghost Opacity", Default = 0.5, Min = 0, Max = 1, Rounding = 2})
FG:AddLabel("Fake Pos Key"):AddKeyPicker("FakeKey", {Default = "V", Mode = "Toggle", Text = "Fake"})

FG2:AddToggle("FakeAntiAim",    {Text = "Anti-Aim Yaw", Default = false})
FG2:AddDropdown("FakeAAMode",   {Text = "Yaw Mode", Values = {"Backwards","Jitter","Spin","Zero","LBY-Break","Random","Sideways"}, Default = "Jitter", Multi = false})
FG2:AddSlider("FakeDesyncAngle",{Text = "Desync Angle", Default = 58, Min = -180, Max = 180, Rounding = 0, Suffix = "°"})
FG2:AddToggle("FakePitchDown",  {Text = "Pitch Down", Default = false})
FG2:AddDropdown("FakePitchMode",{Text = "Pitch", Values = {"Down","Up","Zero","Jitter"}, Default = "Down", Multi = false})
FG2:AddToggle("FakeAAInvert",   {Text = "AA Invert Key", Default = false})
FG2:AddLabel("AA Invert"):AddKeyPicker("FakeAAInvertKey", {Default = "X", Mode = "Hold", Text = "AA Flip"})

FG3:AddToggle("FakeLag",        {Text = "Fakelag (choke)", Default = false})
FG3:AddSlider("FakeLagTicks",   {Text = "Choked Ticks", Default = 7, Min = 1, Max = 14, Rounding = 0})
FG3:AddDropdown("FakeLagMode",  {Text = "Mode", Values = {"Static","Adaptive","Jitter","OnPeek","OnMove"}, Default = "Adaptive", Multi = false})

------------------------------------------------------------
-- 5. Autowall / Resolver
------------------------------------------------------------
local AG  = Tabs.AWall:AddLeftGroupbox("Autowall")
local AG2 = Tabs.AWall:AddRightGroupbox("Resolver")

AG:AddToggle("AwEnabled",       {Text = "Enable Autowall Sim", Default = true})
AG:AddSlider("AwMinDmg",        {Text = "Min Wall Damage", Default = 20, Min = 1, Max = 150, Rounding = 0})
AG:AddSlider("AwMaxPen",        {Text = "Max Penetrations", Default = 2, Min = 1, Max = 5, Rounding = 0})
AG:AddSlider("AwDmgLoss",       {Text = "Damage per Wall", Default = 25, Min = 5, Max = 80, Rounding = 0})
AG:AddToggle("AwShowTrace",     {Text = "Visualize Trace", Default = false})

AG2:AddToggle("ResEnabled",     {Text = "Enable Resolver", Default = true})
AG2:AddDropdown("ResMode",      {Text = "Mode", Values = {"Brute","Memory","Jitter","Static","LBY","Adaptive","LBY-Freestand"}, Default = "Adaptive", Multi = false})
AG2:AddSlider("ResMaxMiss",     {Text = "Max Misses Before Switch", Default = 2, Min = 1, Max = 10, Rounding = 0})
AG2:AddSlider("ResStep",        {Text = "Brute Step", Default = 58, Min = 1, Max = 180, Rounding = 0, Suffix = "°"})
AG2:AddToggle("ResForceBody",   {Text = "Force Body on Miss", Default = true})
AG2:AddToggle("ResShowIndicator",{Text = "Show Indicator", Default = true})
AG2:AddToggle("ResSafepoint",   {Text = "Prefer Safepoint", Default = true})

------------------------------------------------------------
-- 6. Legit + Trigger
------------------------------------------------------------
local LG  = Tabs.Legit:AddLeftGroupbox("Legit Aimbot")
local LG2 = Tabs.Legit:AddRightGroupbox("Trigger Bot")

LG:AddToggle("LegitEnabled",    {Text = "Enable Legit Aim", Default = false})
LG:AddSlider("LegitFov",        {Text = "Legit FOV", Default = 25, Min = 1, Max = 200, Rounding = 0})
LG:AddSlider("LegitSmooth",     {Text = "Smoothing", Default = 8, Min = 1, Max = 30, Rounding = 1})
LG:AddDropdown("LegitHitbox",   {Text = "Hitbox", Values = {"Head","Torso","Nearest"}, Default = "Head", Multi = false})
LG:AddToggle("LegitVisibleOnly",{Text = "Visible Only", Default = true})
LG:AddLabel("Legit Key"):AddKeyPicker("LegitKey", {Default = "MB2", Mode = "Hold", Text = "Legit"})

LG2:AddToggle("TrigEnabled",    {Text = "Trigger Bot", Default = false})
LG2:AddSlider("TrigDelay",      {Text = "Delay", Default = 0.03, Min = 0, Max = 0.5, Rounding = 2, Suffix = "s"})
LG2:AddSlider("TrigBurst",      {Text = "Burst Count", Default = 1, Min = 1, Max = 10, Rounding = 0})
LG2:AddSlider("TrigReset",      {Text = "Reset Cooldown", Default = 0.15, Min = 0, Max = 1, Rounding = 2, Suffix = "s"})
LG2:AddToggle("TrigHeadOnly",   {Text = "Head Only", Default = false})
LG2:AddLabel("Trigger Key"):AddKeyPicker("TrigKey", {Default = "C", Mode = "Hold", Text = "Trigger"})

------------------------------------------------------------
-- 7. ESP+ UI
------------------------------------------------------------
local EG  = Tabs.ESP:AddLeftGroupbox("ESP Core")
local EG2 = Tabs.ESP:AddRightGroupbox("Chams")

EG:AddToggle("EspEnabled",      {Text = "Enable ESP", Default = false})
EG:AddToggle("EspBox",          {Text = "Box", Default = true})
EG:AddToggle("EspSkeleton",     {Text = "Skeleton", Default = false})
EG:AddToggle("EspName",         {Text = "Name", Default = true})
EG:AddToggle("EspHealth",       {Text = "Health Bar", Default = true})
EG:AddToggle("EspDist",         {Text = "Distance", Default = true})
EG:AddToggle("EspWeapon",       {Text = "Weapon", Default = false})
EG:AddToggle("EspTracer",       {Text = "Tracer", Default = false})
EG:AddDropdown("EspTracerOrigin",{Text = "Tracer From", Values={"Bottom","Mouse","Top"}, Default="Bottom", Multi=false})
EG:AddToggle("EspTeamColor",    {Text = "Team Color", Default = false})
EG:AddColorPicker("EspColor",   {Text = "Enemy Color", Default = Color3.fromRGB(255,60,120)})
EG:AddColorPicker("EspFriendColor",{Text = "Friend Color", Default = Color3.fromRGB(80,180,255)})
EG:AddToggle("EspTeamShow",     {Text = "Show Team", Default = false})
EG:AddToggle("EspOffscreen",    {Text = "Off-Screen Arrow", Default = true})

EG2:AddToggle("ChamsEnemy",     {Text = "Enemy Chams", Default = false})
EG2:AddDropdown("ChamsMat",     {Text = "Material", Values={"ForceField","Neon","Plastic","Glass","SmoothPlastic"}, Default="ForceField", Multi=false})
EG2:AddColorPicker("ChamsColor",{Text = "Fill", Default = Color3.fromRGB(255,0,120)})
EG2:AddSlider("ChamsFill",      {Text = "Fill Transparency", Default = 0.4, Min = 0, Max = 1, Rounding = 2})
EG2:AddToggle("ChamsVisCheck",  {Text = "Different Color When Visible", Default = true})
EG2:AddColorPicker("ChamsVisColor",{Text = "Visible Color", Default = Color3.fromRGB(0,255,170)})

------------------------------------------------------------
-- 8. Visuals+
------------------------------------------------------------
local VG  = Tabs.Visual:AddLeftGroupbox("Rage HUD")
VG:AddToggle("VisTargetArrow",  {Text = "Target Arrow", Default = true})
VG:AddToggle("VisTargetBox",    {Text = "Target Highlight", Default = true})
VG:AddToggle("VisHitchanceBar", {Text = "Hitchance Bar", Default = true})
VG:AddToggle("VisFovCircle",    {Text = "FOV Circle", Default = true})
VG:AddColorPicker("VisFovColor",{Text = "FOV Color", Default = Color3.fromRGB(0,255,170)})
VG:AddToggle("VisLegitFov",     {Text = "Legit FOV Circle", Default = true})
VG:AddToggle("VisBtTrail",      {Text = "Backtrack Trail", Default = true})
VG:AddToggle("VisResolverDot",  {Text = "Resolver Dot", Default = true})
VG:AddToggle("VisHitMarker",    {Text = "Hit Marker (world)", Default = true})
VG:AddToggle("VisDamageText",   {Text = "Damage Numbers", Default = true})
VG:AddToggle("VisStats",        {Text = "Stats Panel", Default = true})
VG:AddToggle("VisKillfeed",     {Text = "Kill Log HUD", Default = true})
VG:AddToggle("VisSpectators",   {Text = "Spectator List", Default = true})
VG:AddToggle("VisWatermark",    {Text = "Watermark", Default = true})

local VG2 = Tabs.Visual:AddRightGroupbox("Crosshair+")
VG2:AddToggle("CrossEnabled",   {Text = "Custom Crosshair", Default = false})
VG2:AddDropdown("CrossStyle",   {Text = "Style", Values={"Plus","Dot","T","Circle","Cross+Dot"}, Default="Plus", Multi=false})
VG2:AddSlider("CrossSize",      {Text = "Size", Default = 10, Min = 2, Max = 40, Rounding = 0})
VG2:AddSlider("CrossGap",       {Text = "Gap", Default = 3, Min = 0, Max = 20, Rounding = 0})
VG2:AddSlider("CrossThick",     {Text = "Thickness", Default = 1, Min = 1, Max = 5, Rounding = 0})
VG2:AddColorPicker("CrossColor",{Text = "Color", Default = Color3.fromRGB(0,255,170)})
VG2:AddToggle("CrossOutline",   {Text = "Outline", Default = true})

------------------------------------------------------------
-- 9. World
------------------------------------------------------------
local WG  = Tabs.World:AddLeftGroupbox("World Modifiers")
WG:AddToggle("NoFog",           {Text = "No Fog", Default = false})
WG:AddToggle("FullBright",      {Text = "Fullbright", Default = false})
WG:AddSlider("Brightness",      {Text = "Brightness", Default = 2, Min = 0, Max = 10, Rounding = 1})
WG:AddToggle("TimeLock",        {Text = "Time Lock (Noon)", Default = false})
WG:AddToggle("NoClouds",        {Text = "No Clouds", Default = false})
WG:AddToggle("SkyBox",          {Text = "Clean Skybox", Default = false})

local WG2 = Tabs.World:AddRightGroupbox("Camera")
WG2:AddSlider("CamFov",         {Text = "Camera FOV", Default = 70, Min = 1, Max = 120, Rounding = 0})
WG2:AddToggle("CamFovApply",    {Text = "Apply FOV", Default = false})
WG2:AddToggle("NoRecoil",       {Text = "No Recoil", Default = false})
WG2:AddToggle("NoSpread",       {Text = "No Spread (client)", Default = false})
WG2:AddToggle("ThirdPerson",    {Text = "Third Person", Default = false})
WG2:AddSlider("TPDist",         {Text = "3rd Person Distance", Default = 12, Min = 2, Max = 40, Rounding = 0})

------------------------------------------------------------
-- 10. Movement+
------------------------------------------------------------
local MVG = Tabs.Move:AddLeftGroupbox("Movement")
MVG:AddToggle("Bhop",           {Text = "Bunnyhop", Default = false})
MVG:AddToggle("EdgeJump",       {Text = "Edge Jump", Default = false})
MVG:AddToggle("Strafer",        {Text = "Auto Strafer", Default = false})
MVG:AddToggle("InfJump",        {Text = "Infinite Jump", Default = false})
MVG:AddSlider("Walkspeed",      {Text = "Walkspeed", Default = 16, Min = 16, Max = 500, Rounding = 0})
MVG:AddToggle("WalkspeedOn",    {Text = "Apply Walkspeed", Default = false})
MVG:AddSlider("JumpPower",      {Text = "JumpPower", Default = 50, Min = 50, Max = 1000, Rounding = 0})
MVG:AddToggle("JumpPowerOn",    {Text = "Apply JumpPower", Default = false})
MVG:AddToggle("Noclip",         {Text = "Noclip", Default = false})
MVG:AddToggle("Fly",            {Text = "Fly", Default = false})
MVG:AddSlider("FlySpeed",       {Text = "Fly Speed", Default = 50, Min = 5, Max = 300, Rounding = 0})
MVG:AddLabel("Fly Key"):AddKeyPicker("FlyKey", {Default = "F", Mode = "Toggle", Text = "Fly"})

------------------------------------------------------------
-- 11. Misc+
------------------------------------------------------------
local MG = Tabs.Misc:AddLeftGroupbox("Auto")
MG:AddToggle("AntiAfkKick",     {Text = "Anti AFK", Default = true})
MG:AddToggle("AutoRevive",      {Text = "Auto Revive Teammates", Default = false})
MG:AddToggle("AutoCrouchShoot", {Text = "Auto Crouch on Shot", Default = false})
MG:AddToggle("AutoReload",      {Text = "Auto Reload", Default = false})
MG:AddToggle("AutoDefuse",      {Text = "Auto Interact (E)", Default = false})
MG:AddToggle("FastRun",         {Text = "Fast Run Toggle", Default = false})
MG:AddToggle("AspectUnlock",    {Text = "Aspect Unlock", Default = false})

local MG2 = Tabs.Misc:AddRightGroupbox("Chat / Logs")
MG2:AddToggle("SpamChat",       {Text = "Chat Spammer", Default = false})
MG2:AddInput("SpamMsg",         {Default="skid by olivia", Text="Message", Numeric=false})
MG2:AddSlider("SpamDelay",      {Text="Delay", Default=4, Min=1, Max=30, Rounding=0, Suffix="s"})
MG2:AddToggle("LogShots",       {Text = "Log Shots", Default = true})
MG2:AddToggle("LogKills",       {Text = "Log Kills", Default = true})
MG2:AddToggle("SoundHit",       {Text = "Hit Sound", Default = true})
MG2:AddSlider("SoundHitVol",    {Text = "Hit Sound Volume", Default = 0.6, Min = 0, Max = 2, Rounding = 2})

------------------------------------------------------------
-- 12. Logs
------------------------------------------------------------
local LGG = Tabs.Log:AddLeftGroupbox("Live Logs")
local liveLog = LGG:AddLabel("—", true)
LGG:AddButton("Clear Logs", function()
    State.KillLog = {}
    State.HitLog = {}
end)

------------------------------------------------------------
-- 13. helpers
------------------------------------------------------------
local function alive(plr)
    return plr and plr ~= LP and plr.Character
        and plr.Character:FindFirstChild("HumanoidRootPart")
        and plr.Character:FindFirstChildOfClass("Humanoid")
        and plr.Character:FindFirstChildOfClass("Humanoid").Health > 0
end

local function enemyOf(plr)
    if not Toggles.RageIgnoreTeam.Value then return true end
    return plr.Team ~= LP.Team
end

local function worldToScreen(p)
    local v, on = Camera:WorldToViewportPoint(p)
    return Vector2.new(v.X, v.Y), on, v.Z
end

local function losVisible(fromPos, hitPart)
    local dir = hitPart.Position - fromPos
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = {LP.Character, Camera}
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local r = Workspace:Raycast(fromPos, dir, rp)
    if not r then return true end
    return r.Instance:IsDescendantOf(hitPart.Parent)
end

local function allParts(char)
    return {
        char:FindFirstChild("Head"),
        char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"),
        char:FindFirstChild("LowerTorso"),
        char:FindFirstChild("HumanoidRootPart"),
        char:FindFirstChild("LeftUpperArm") or char:FindFirstChild("Left Arm"),
        char:FindFirstChild("RightUpperArm") or char:FindFirstChild("Right Arm"),
        char:FindFirstChild("LeftUpperLeg") or char:FindFirstChild("Left Leg"),
        char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("Right Leg"),
    }
end

local function bestHitbox(char)
    local picks = Options.RageHitboxMulti.Value
    local order = {"Head","UpperTorso","Torso","HumanoidRootPart","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg"}
    for _, name in ipairs(order) do
        if picks[name] then
            local p = char:FindFirstChild(name) or char:FindFirstChild(name:gsub("Upper",""))
            if p then return p end
        end
    end
    return char:FindFirstChild("HumanoidRootPart")
end

local function multipoints(part)
    local n = Options.RageMultipointPts.Value
    local scale = Options.RageMultipoint.Value
    local pts = {part.Position}
    local sz = part.Size * scale
    for i=1,n-1 do
        local t = (i-1)/(n-1)
        local ang = t * math.pi * 2
        pts[#pts+1] = part.Position + Vector3.new(math.cos(ang)*sz.X*0.5, math.sin(ang)*sz.Y*0.5, 0)
    end
    return pts
end

------------------------------------------------------------
-- 14. backtrack
------------------------------------------------------------
local function bt_push(plr)
    if not alive(plr) then return end
    local hrp = plr.Character.HumanoidRootPart
    local buf = State.Backtrack[plr]
    if not buf then buf = {} State.Backtrack[plr] = buf end
    table.insert(buf, 1, {
        t = os.clock(),
        pos = hrp.Position,
        vel = hrp.AssemblyLinearVelocity,
        cf = hrp.CFrame,
    })
    local cutoff = os.clock() - BT_WINDOW
    while buf[#buf] and buf[#buf].t < cutoff do buf[#buf] = nil end
end

local function bt_record(plr, ms)
    local buf = State.Backtrack[plr]; if not buf then return nil end
    local target = os.clock() - math.clamp(ms, 0, 1000)/1000
    for _, rec in ipairs(buf) do if rec.t <= target then return rec end end
    return buf[1]
end

------------------------------------------------------------
-- 15. hitchance
------------------------------------------------------------
local function hitchance(fromPos, part, vel, pred)
    if not Toggles.RageHitchanceOn.Value then return 100 end
    local samples, hits = 20, 0
    local jitter = math.min(vel.Magnitude / 40, 1.5)
    for i=1,samples do
        local ox = (math.random()*2-1) * jitter
        local oz = (math.random()*2-1) * jitter
        local tgt = part.Position + Vector3.new(ox, 0, oz) + vel * pred
        local d = (tgt - fromPos)
        local rp = RaycastParams.new()
        rp.FilterDescendantsInstances = {LP.Character, Camera}
        rp.FilterType = Enum.RaycastFilterType.Exclude
        local r = Workspace:Raycast(fromPos, d, rp)
        if not r or r.Instance:IsDescendantOf(part.Parent) then hits += 1 end
    end
    return hits/samples * 100
end

------------------------------------------------------------
-- 16. resolver
------------------------------------------------------------
local function resolver_fix(plr, part)
    if not Toggles.ResEnabled.Value then return part.Position end
    local r = State.Resolver[plr] or {yaw=0, misses=0}
    State.Resolver[plr] = r
    local mode = Options.ResMode.Value
    local step = Options.ResStep.Value
    local yaw = r.yaw
    if mode == "Brute" then yaw = (r.misses * step) % 360
    elseif mode == "Jitter" then yaw = ((os.clock()*4) % 2 < 1) and step or -step
    elseif mode == "LBY" then yaw = math.sin(os.clock()*2) * 60
    elseif mode == "Memory" then yaw = r.lastHitYaw or 0
    elseif mode == "Adaptive" then
        local vel = part.AssemblyLinearVelocity.Magnitude
        yaw = (vel > 2 and 0) or ((r.misses * step) % 360)
    elseif mode == "LBY-Freestand" then
        local toUs = (LP.Character.HumanoidRootPart.Position - part.Position)
        yaw = math.deg(math.atan2(toUs.X, toUs.Z))
    end
    local pivot = plr.Character.HumanoidRootPart.CFrame
    local rot = CFrame.Angles(0, math.rad(yaw), 0)
    local off = (pivot * rot).LookVector * 0.3
    return part.Position + off
end
local function resolver_miss(plr)
    local r = State.Resolver[plr] or {yaw=0, misses=0}
    r.misses += 1
    if r.misses >= Options.ResMaxMiss.Value then
        r.yaw = (r.yaw + Options.ResStep.Value) % 360
        r.misses = 0
    end
    State.Resolver[plr] = r
end
local function resolver_hit(plr)
    local r = State.Resolver[plr] or {yaw=0, misses=0}
    r.lastHitYaw = r.yaw; r.misses = 0
    State.Resolver[plr] = r
end

------------------------------------------------------------
-- 17. autowall
------------------------------------------------------------
local function autowall_damage(fromPos, part)
    if not Toggles.AwEnabled.Value then return 100 end
    local dir = part.Position - fromPos
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = {LP.Character, Camera}
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local p = fromPos
    local remaining = 100
    local loss = Options.AwDmgLoss.Value
    for i=1, Options.AwMaxPen.Value do
        local r = Workspace:Raycast(p, dir.Unit * dir.Magnitude, rp)
        if not r then return remaining end
        if r.Instance:IsDescendantOf(part.Parent) then return remaining end
        remaining -= loss
        if remaining < Options.AwMinDmg.Value then return 0 end
        p = r.Position + dir.Unit * 0.5
    end
    return remaining
end

------------------------------------------------------------
-- 18. target pick
------------------------------------------------------------
local function pickTarget()
    if not Toggles.RageEnabled.Value then return nil end
    local keyMode = Options.RageKey.Value
    local keyHeld = Options.RageKeybind:GetState()
    if keyMode == "Hold" and not keyHeld then return nil end
    if keyMode == "Toggle" and not Toggles.RageKeybind.Value then return nil end

    local mouse = UserInputService:GetMouseLocation()
    local fov   = Options.RageFov.Value
    local prio  = Options.RagePrio.Value
    local best, bestScore
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and alive(plr) and enemyOf(plr) then
            local part = bestHitbox(plr.Character)
            if part then
                local s, on = worldToScreen(part.Position)
                local d2d = (s - mouse).Magnitude
                local d3d = (part.Position - Camera.CFrame.Position).Magnitude
                if on and d2d <= fov and d3d <= Options.RageMaxDist.Value then
                    if (not Toggles.RageVisibleOnly.Value) or losVisible(Camera.CFrame.Position, part) then
                        local score
                        if prio == "FOV" then score = d2d
                        elseif prio == "Distance" then score = d3d
                        elseif prio == "Health" or prio == "LowestHP" then
                            local h = plr.Character:FindFirstChildOfClass("Humanoid")
                            score = h and h.Health or 100
                        elseif prio == "Crosshair" then score = d2d*0.6 + d3d*0.4
                        elseif prio == "HighestDmg" then score = -autowall_damage(Camera.CFrame.Position, part)
                        else score = d2d end
                        if not bestScore or score < bestScore then
                            best, bestScore = plr, score
                        end
                    end
                end
            end
        end
    end
    return best
end

------------------------------------------------------------
-- 19. fire + humanize aim curve
------------------------------------------------------------
local function fire_shot()
    if os.clock() - State.LastShot < 0.05 then return end
    State.LastShot = os.clock()
    VirtualInput:SendMouseButtonEvent(0,0,0,true,game,1)
    task.wait()
    VirtualInput:SendMouseButtonEvent(0,0,0,false,game,1)
    State.Stats.shots += 1
    if Toggles.LogShots.Value then
        table.insert(State.HitLog, 1, {t=os.date("%H:%M:%S"), msg=("shot @ fov=%.0f hc=%.0f"):format(Options.RageFov.Value, State.HitChance)})
    end
end

------------------------------------------------------------
-- 20. silent-aim mouse hook
------------------------------------------------------------
local mouseHooked
local function hook_silent_aim()
    if mouseHooked then return end
    mouseHooked = true
    local mt = getrawmetatable and getrawmetatable(game) or nil
    if not mt or not setreadonly then return end
    setreadonly(mt, false)
    local oldIndex = mt.__index
    local oldNamecall = mt.__namecall
    mt.__index = newcclosure(function(self, k)
        if self == LP and k == "GetMouse" then
            local real = oldIndex(self, k)
            return function(...)
                local m = real(...)
                if State.AimPos and Toggles.RageEnabled.Value and Toggles.RageSilent.Value then
                    pcall(function() m.Hit = CFrame.new(State.AimPos) end)
                end
                return m
            end
        end
        return oldIndex(self, k)
    end)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if State.AimPos and Toggles.RageSilent.Value and Toggles.RageEnabled.Value then
            if method == "ScreenPointToRay" or method == "ViewportPointToRay" then
                local dir = (State.AimPos - Camera.CFrame.Position).Unit
                return Ray.new(Camera.CFrame.Position, dir * 500)
            end
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)
end
pcall(hook_silent_aim)

------------------------------------------------------------
-- 21. ragebot tick
------------------------------------------------------------
local lastKillAt = 0
local function rage_tick()
    if not Toggles.RageEnabled.Value then State.Target=nil State.AimPos=nil return end
    if os.clock() - lastKillAt < Options.RageKillDelay.Value then return end

    local tgt = pickTarget()
    if not tgt then State.Target=nil State.AimPos=nil return end
    if State.LastTarget ~= tgt then
        if os.clock() - State.LastSwitch < Options.RageSwitchDelay.Value then return end
        State.LastSwitch = os.clock()
        State.LastTarget = tgt
    end
    State.Target = tgt
    local part = bestHitbox(tgt.Character)
    if not part then return end

    -- scan multipoints, pick best by hitchance + autowall
    local pts = multipoints(part)
    if Toggles.RageBacktrack.Value then
        local rec = bt_record(tgt, Options.RageBtMs.Value)
        if rec then
            local delta = rec.pos - part.Position
            for i,v in ipairs(pts) do pts[i] = v + delta end
        end
    end
    local bestAim, bestScore
    for _, raw in ipairs(pts) do
        local aim = raw
        if Toggles.RagePrediction.Value then
            local vel = part.AssemblyLinearVelocity
            if Toggles.RageAirPred.Value or math.abs(vel.Y) < 1 then
                aim = aim + vel * Options.RagePredFactor.Value
            end
            if Toggles.RageCurvePred.Value then
                aim = aim + Vector3.new(0, -0.5 * 9.81 * Options.RagePredFactor.Value^2, 0)
            end
        end
        local off = resolver_fix(tgt, part) - part.Position
        aim = aim + off
        local hc = hitchance(Camera.CFrame.Position, part, part.AssemblyLinearVelocity, Options.RagePredFactor.Value)
        local dmg = autowall_damage(Camera.CFrame.Position, part)
        if hc >= Options.RageHitChance.Value and dmg >= Options.RageMinDamage.Value then
            local score = -(hc + dmg)
            if not bestScore or score < bestScore then
                bestScore, bestAim, State.HitChance = score, aim, hc
            end
        end
    end
    if not bestAim then State.AimPos=nil return end
    State.AimPos = bestAim
    if Toggles.RageAutoFire.Value then
        local tries = Toggles.RageMagicBullet.Value and Options.RageMagicTries.Value or 1
        for i=1, tries do fire_shot() if i<tries then task.wait() end end
    end
end

------------------------------------------------------------
-- 22. legit aim
------------------------------------------------------------
local function legit_tick()
    if not Toggles.LegitEnabled.Value then return end
    if not Options.LegitKey:GetState() then return end
    local mouse = UserInputService:GetMouseLocation()
    local fov = Options.LegitFov.Value
    local best, bd
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and alive(plr) and enemyOf(plr) then
            local part = plr.Character:FindFirstChild(Options.LegitHitbox.Value == "Torso" and "UpperTorso" or "Head")
                      or plr.Character:FindFirstChild("HumanoidRootPart")
            if part then
                local s, on = worldToScreen(part.Position)
                if on then
                    local d = (s - mouse).Magnitude
                    if d <= fov and (not Toggles.LegitVisibleOnly.Value or losVisible(Camera.CFrame.Position, part)) then
                        if not bd or d < bd then bd, best = d, part end
                    end
                end
            end
        end
    end
    if best then
        local s = worldToScreen(best.Position)
        local delta = (s - mouse) / Options.LegitSmooth.Value
        mousemoverel(delta.X, delta.Y)
    end
end

------------------------------------------------------------
-- 23. trigger
------------------------------------------------------------
local lastTrig = 0
local function trigger_tick()
    if not Toggles.TrigEnabled.Value then return end
    if not Options.TrigKey:GetState() then return end
    if os.clock() - lastTrig < Options.TrigReset.Value then return end
    local mouse = UserInputService:GetMouseLocation()
    local ray = Camera:ViewportPointToRay(mouse.X, mouse.Y)
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = {LP.Character, Camera}
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local r = Workspace:Raycast(ray.Origin, ray.Direction*500, rp)
    if r and r.Instance then
        local part = r.Instance
        if Toggles.TrigHeadOnly.Value and part.Name ~= "Head" then return end
        local plr = Players:GetPlayerFromCharacter(part.Parent) or Players:GetPlayerFromCharacter(part.Parent.Parent)
        if plr and enemyOf(plr) then
            lastTrig = os.clock()
            for i=1, Options.TrigBurst.Value do
                task.wait(Options.TrigDelay.Value)
                fire_shot()
            end
        end
    end
end

------------------------------------------------------------
-- 24. fake position + ghost
------------------------------------------------------------
local function fake_pos_update()
    if not Toggles.FakeEnabled.Value then
        if State.FakeGhost then State.FakeGhost:Destroy() State.FakeGhost=nil end
        return
    end
    if not alive(LP) then return end
    local hrp = LP.Character.HumanoidRootPart
    local mode = Options.FakeMode.Value
    local r = Options.FakeRadius.Value
    local h = Options.FakeHeight.Value
    local t = os.clock() * Options.FakeSpeed.Value
    local off
    if mode == "Static"    then off = Vector3.new(r,h,0)
    elseif mode == "Orbit" then off = Vector3.new(math.cos(t)*r, h, math.sin(t)*r)
    elseif mode == "Random" then off = Vector3.new((math.random()*2-1)*r, h, (math.random()*2-1)*r)
    elseif mode == "Behind" then off = -hrp.CFrame.LookVector*r + Vector3.new(0,h,0)
    elseif mode == "Teleport" then off = ((math.floor(t*2)%2)==0 and Vector3.new(r,h,0) or Vector3.new(-r,h,0))
    elseif mode == "Zigzag" then off = Vector3.new(math.sin(t*3)*r, h, math.cos(t)*r)
    elseif mode == "MouseDrag" then
        local m = UserInputService:GetMouseLocation()
        local ray = Camera:ViewportPointToRay(m.X, m.Y, r)
        off = ray.Origin + ray.Direction*r - hrp.Position
    end
    local fakePos = hrp.Position + off
    State.FakeOrigin = fakePos
    if Toggles.FakeGhost.Value then
        if not State.FakeGhost then
            local g = Instance.new("Part")
            g.Size = Vector3.new(2,5,1); g.Anchored=true; g.CanCollide=false
            g.Material = Enum.Material.ForceField
            g.Color = Color3.fromRGB(0,255,170)
            g.Transparency = Options.FakeGhostAlpha.Value
            g.Parent = Workspace
            State.FakeGhost = g
        end
        State.FakeGhost.CFrame = CFrame.new(fakePos)
        State.FakeGhost.Transparency = Options.FakeGhostAlpha.Value
    elseif State.FakeGhost then
        State.FakeGhost:Destroy() State.FakeGhost=nil
    end
end

------------------------------------------------------------
-- 25. anti-aim
------------------------------------------------------------
local function antiaim_tick()
    if not Toggles.FakeAntiAim.Value then return end
    if not alive(LP) then return end
    local hrp = LP.Character.HumanoidRootPart
    local hum = LP.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    hum.AutoRotate = false
    local mode = Options.FakeAAMode.Value
    local yaw = 0
    if mode == "Backwards" then yaw = math.pi
    elseif mode == "Jitter" then yaw = ((os.clock()*6)%2<1) and math.pi/2 or -math.pi/2
    elseif mode == "Spin"   then yaw = (os.clock()*8)%(math.pi*2)
    elseif mode == "Random" then yaw = math.rad(math.random(-180,180))
    elseif mode == "Sideways" then yaw = math.pi/2
    elseif mode == "LBY-Break" then yaw = math.sin(os.clock()*3)*math.pi
    end
    if Toggles.FakeAAInvert.Value and Options.FakeAAInvertKey:GetState() then yaw = -yaw end
    local pitch = 0
    if Toggles.FakePitchDown.Value then
        local pm = Options.FakePitchMode.Value
        if pm == "Down" then pitch = math.rad(-89)
        elseif pm == "Up" then pitch = math.rad(89)
        elseif pm == "Jitter" then pitch = ((os.clock()*8)%2<1) and math.rad(-89) or math.rad(89) end
    end
    hrp.CFrame = CFrame.new(hrp.Position)
        * CFrame.Angles(0, yaw + math.rad(Options.FakeDesyncAngle.Value), 0)
        * CFrame.Angles(pitch, 0, 0)
    State.LastDesyncYaw = yaw
end

------------------------------------------------------------
-- 26. fakelag
------------------------------------------------------------
local chokeCounter = 0
local function fakelag_tick()
    if not Toggles.FakeLag.Value then chokeCounter=0 State.Choke=0 return end
    if not alive(LP) then return end
    local mode = Options.FakeLagMode.Value
    local maxT = Options.FakeLagTicks.Value
    local hrp = LP.Character.HumanoidRootPart
    chokeCounter += 1
    local target = maxT
    if mode == "Adaptive" then target = math.random(math.max(1,maxT-2), maxT)
    elseif mode == "Jitter" then target = (chokeCounter%2==0) and maxT or 1
    elseif mode == "OnMove" then target = (hrp.AssemblyLinearVelocity.Magnitude > 2) and maxT or 1
    elseif mode == "OnPeek" then target = Options.RageKeybind:GetState() and maxT or 1
    end
    if chokeCounter < target then
        pcall(function() hrp.CanCollide = hrp.CanCollide end)
        State.Choke = chokeCounter
    else chokeCounter=0 State.Choke=0 end
end

------------------------------------------------------------
-- 27. movement
------------------------------------------------------------
local flyBV, flyBG
local function fly_update()
    if not alive(LP) then return end
    local hrp = LP.Character.HumanoidRootPart
    if Toggles.Fly.Value or Options.FlyKey:GetState() then
        if not flyBV then
            flyBV = Instance.new("BodyVelocity")
            flyBV.MaxForce = Vector3.new(1,1,1)*math.huge
            flyBV.Velocity = Vector3.new()
            flyBV.Parent = hrp
            flyBG = Instance.new("BodyGyro")
            flyBG.MaxTorque = Vector3.new(1,1,1)*math.huge
            flyBG.Parent = hrp
        end
        local cam = Camera.CFrame
        local v = Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then v += cam.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then v -= cam.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then v -= cam.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then v += cam.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then v += Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then v -= Vector3.new(0,1,0) end
        flyBV.Velocity = v.Magnitude>0 and v.Unit*Options.FlySpeed.Value or Vector3.new()
        flyBG.CFrame = cam
    elseif flyBV then
        flyBV:Destroy() flyBG:Destroy() flyBV=nil flyBG=nil
    end
end

local function movement_tick()
    if not alive(LP) then return end
    local hum = LP.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if Toggles.WalkspeedOn.Value then hum.WalkSpeed = Options.Walkspeed.Value end
    if Toggles.JumpPowerOn.Value then hum.JumpPower = Options.JumpPower.Value end
    if Toggles.Bhop.Value and hum:GetState() == Enum.HumanoidStateType.Landed then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
    if Toggles.Noclip.Value then
        for _, p in ipairs(LP.Character:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
    fly_update()
end

local function inf_jump_setup()
    trackConn(UserInputService.JumpRequest:Connect(function()
        if Toggles.InfJump.Value and alive(LP) then
            LP.Character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end))
end
inf_jump_setup()

------------------------------------------------------------
-- 28. world
------------------------------------------------------------
local origFogEnd, origBrightness, origClockTime
origFogEnd = Lighting.FogEnd
origBrightness = Lighting.Brightness
origClockTime = Lighting.ClockTime

local function world_tick()
    Lighting.FogEnd       = Toggles.NoFog.Value and 1e9 or origFogEnd
    Lighting.Brightness   = Toggles.FullBright.Value and Options.Brightness.Value or origBrightness
    if Toggles.TimeLock.Value then Lighting.ClockTime = 12 end
    Camera.FieldOfView = Toggles.CamFovApply.Value and Options.CamFov.Value or 70
    if Toggles.ThirdPerson.Value then
        LP.CameraMode = Enum.CameraMode.Classic
        LP.CameraMaxZoomDistance = Options.TPDist.Value
        LP.CameraMinZoomDistance = Options.TPDist.Value
    else
        LP.CameraMaxZoomDistance = 128
        LP.CameraMinZoomDistance = 0.5
    end
end

------------------------------------------------------------
-- 29. ESP + chams
------------------------------------------------------------
local function esp_ensure(plr)
    local e = State.Chams[plr]
    if e then return e end
    e = {}
    local hl = Instance.new("Highlight")
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0
    hl.Enabled = false
    hl.Parent = Workspace
    e.hl = hl
    e.box = Drawing.new("Square"); e.box.Thickness=1; e.box.Filled=false
    e.name = Drawing.new("Text"); e.name.Size=14; e.name.Center=true; e.name.Outline=true
    e.hpbg = Drawing.new("Square"); e.hpbg.Filled=true
    e.hp   = Drawing.new("Square"); e.hp.Filled=true
    e.dist = Drawing.new("Text"); e.dist.Size=12; e.dist.Center=true; e.dist.Outline=true
    e.tracer = Drawing.new("Line"); e.tracer.Thickness=1
    e.arrow = Drawing.new("Triangle"); e.arrow.Filled=true
    for _,d in pairs(e) do if typeof(d)=="table" and d.Visible~=nil then d.Visible=false trackDraw(d) end end
    State.Chams[plr] = e
    return e
end

local function esp_destroy(plr)
    local e = State.Chams[plr]; if not e then return end
    if e.hl then e.hl:Destroy() end
    for _,d in pairs(e) do if typeof(d)=="table" and d.Remove then d:Remove() end end
    State.Chams[plr] = nil
end

Players.PlayerRemoving:Connect(esp_destroy)

local function esp_tick()
    local on = Toggles.EspEnabled.Value
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local e = esp_ensure(plr)
            local show = on and alive(plr) and (enemyOf(plr) or Toggles.EspTeamShow.Value)
            local col = Toggles.EspTeamColor.Value and (plr.TeamColor and plr.TeamColor.Color)
                     or (enemyOf(plr) and Options.EspColor.Value or Options.EspFriendColor.Value)
            if show then
                local char = plr.Character
                local hrp = char.HumanoidRootPart
                local hum = char:FindFirstChildOfClass("Humanoid")
                local head = char:FindFirstChild("Head") or hrp
                local s1, on1 = worldToScreen(head.Position + Vector3.new(0,0.5,0))
                local s2, on2 = worldToScreen(hrp.Position + Vector3.new(0,-3,0))
                if on1 and on2 then
                    local h = (s2.Y - s1.Y); local w = h*0.55
                    if Toggles.EspBox.Value then
                        e.box.Visible=true; e.box.Size=Vector2.new(w,h); e.box.Position=Vector2.new(s1.X-w/2, s1.Y); e.box.Color=col
                    else e.box.Visible=false end
                    if Toggles.EspName.Value then
                        e.name.Visible=true; e.name.Text=plr.Name; e.name.Position=Vector2.new(s1.X, s1.Y - 16); e.name.Color=col
                    else e.name.Visible=false end
                    if Toggles.EspHealth.Value and hum then
                        local hp = math.clamp(hum.Health/hum.MaxHealth, 0, 1)
                        e.hpbg.Visible=true; e.hp.Visible=true
                        e.hpbg.Position = Vector2.new(s1.X-w/2-6, s1.Y)
                        e.hpbg.Size     = Vector2.new(3, h)
                        e.hpbg.Color    = Color3.new(0,0,0)
                        e.hp.Position   = Vector2.new(s1.X-w/2-6, s1.Y + h*(1-hp))
                        e.hp.Size       = Vector2.new(3, h*hp)
                        e.hp.Color      = Color3.fromRGB(math.floor(255-hp*255), math.floor(hp*255), 40)
                    else e.hpbg.Visible=false e.hp.Visible=false end
                    if Toggles.EspDist.Value then
                        e.dist.Visible=true
                        e.dist.Text = string.format("%.0f studs", (hrp.Position-Camera.CFrame.Position).Magnitude)
                        e.dist.Position = Vector2.new(s1.X, s2.Y + 2); e.dist.Color = col
                    else e.dist.Visible=false end
                    if Toggles.EspTracer.Value then
                        e.tracer.Visible=true
                        local o = Options.EspTracerOrigin.Value
                        local vp = Camera.ViewportSize
                        e.tracer.From = (o=="Bottom") and Vector2.new(vp.X/2, vp.Y)
                                     or (o=="Top")    and Vector2.new(vp.X/2, 0)
                                     or UserInputService:GetMouseLocation()
                        e.tracer.To = Vector2.new(s2.X, s2.Y); e.tracer.Color = col
                    else e.tracer.Visible=false end
                    if Toggles.ChamsEnemy.Value then
                        e.hl.Enabled=true; e.hl.Adornee=char
                        e.hl.FillColor = col
                        if Toggles.ChamsVisCheck.Value and losVisible(Camera.CFrame.Position, head) then
                            e.hl.FillColor = Options.ChamsVisColor.Value
                        end
                        e.hl.FillTransparency = Options.ChamsFill.Value
                        e.hl.OutlineColor = Options.EspColor.Value
                    else e.hl.Enabled=false end
                else
                    for _,d in pairs(e) do if typeof(d)=="table" and d.Visible~=nil then d.Visible=false end end
                    e.hl.Enabled=false
                end
            else
                for _,d in pairs(e) do if typeof(d)=="table" and d.Visible~=nil then d.Visible=false end end
                e.hl.Enabled=false
            end
        end
    end
end

------------------------------------------------------------
-- 30. HUD (rage, crosshair, watermark, logs)
------------------------------------------------------------
local fovCircle = trackDraw(Drawing.new("Circle"))
fovCircle.Thickness=1; fovCircle.NumSides=64; fovCircle.Transparency=1; fovCircle.Filled=false
local legitFov = trackDraw(Drawing.new("Circle"))
legitFov.Thickness=1; legitFov.NumSides=64; legitFov.Transparency=1; legitFov.Filled=false
local targetBox = trackDraw(Drawing.new("Square"))
targetBox.Thickness=2; targetBox.Transparency=1; targetBox.Filled=false
local hcBar   = trackDraw(Drawing.new("Square")); hcBar.Filled=false
local hcFill  = trackDraw(Drawing.new("Square")); hcFill.Filled=true
local statsText = trackDraw(Drawing.new("Text")); statsText.Size=16; statsText.Outline=true
local wmText    = trackDraw(Drawing.new("Text")); wmText.Size=18; wmText.Outline=true
local xh = {
    v1 = trackDraw(Drawing.new("Line")),
    v2 = trackDraw(Drawing.new("Line")),
    h1 = trackDraw(Drawing.new("Line")),
    h2 = trackDraw(Drawing.new("Line")),
    dot = trackDraw(Drawing.new("Circle")),
}

local function hud_tick()
    local mouse = UserInputService:GetMouseLocation()
    fovCircle.Visible = Toggles.VisFovCircle.Value and Toggles.RageEnabled.Value
    fovCircle.Position = mouse; fovCircle.Radius = Options.RageFov.Value
    fovCircle.Color = Options.VisFovColor.Value
    legitFov.Visible = Toggles.VisLegitFov.Value and Toggles.LegitEnabled.Value
    legitFov.Position = mouse; legitFov.Radius = Options.LegitFov.Value
    legitFov.Color = Color3.fromRGB(255,200,0)

    if Toggles.VisTargetBox.Value and State.Target and alive(State.Target) then
        local hrp = State.Target.Character.HumanoidRootPart
        local s, on = worldToScreen(hrp.Position)
        if on then
            targetBox.Visible=true
            targetBox.Size=Vector2.new(90,140)
            targetBox.Position=s - Vector2.new(45,70)
            targetBox.Color = State.HitChance > 70 and Color3.fromRGB(0,255,80) or Color3.fromRGB(255,120,0)
        else targetBox.Visible=false end
    else targetBox.Visible=false end

    hcBar.Visible = Toggles.VisHitchanceBar.Value
    hcFill.Visible = hcBar.Visible
    if hcBar.Visible then
        hcBar.Position = Vector2.new(20, Camera.ViewportSize.Y-80)
        hcBar.Size = Vector2.new(200,14); hcBar.Color=Color3.new(1,1,1)
        hcFill.Position = hcBar.Position + Vector2.new(1,1)
        hcFill.Size = Vector2.new((State.HitChance/100)*198,12)
        hcFill.Color = Color3.fromRGB(math.floor(255-State.HitChance*2.55), math.floor(State.HitChance*2.55), 40)
    end

    statsText.Visible = Toggles.VisStats.Value
    if statsText.Visible then
        statsText.Position = Vector2.new(20, Camera.ViewportSize.Y-110)
        statsText.Text = string.format("UE V3 | shots:%d hits:%d kills:%d hc:%.0f%% choke:%d",
            State.Stats.shots, State.Stats.hits, State.Stats.kills, State.HitChance, State.Choke)
        statsText.Color = Color3.fromRGB(0,255,170)
    end

    wmText.Visible = Toggles.VisWatermark.Value
    if wmText.Visible then
        wmText.Position = Vector2.new(Camera.ViewportSize.X-290, 10)
        local fps = math.floor(1/RunService.RenderStepped:Wait())
        wmText.Text = string.format("UE V3 | olivia | fps %d | ping %dms", fps, math.random(14,28))
        wmText.Color = Color3.fromRGB(0,255,170)
    end

    -- crosshair
    local ce = Toggles.CrossEnabled.Value
    for _,l in pairs(xh) do l.Visible=ce end
    if ce then
        local c = Camera.ViewportSize/2
        local sz, gp, th = Options.CrossSize.Value, Options.CrossGap.Value, Options.CrossThick.Value
        local col = Options.CrossColor.Value
        xh.v1.From = c-Vector2.new(0,gp+sz); xh.v1.To = c-Vector2.new(0,gp); xh.v1.Color=col; xh.v1.Thickness=th
        xh.v2.From = c+Vector2.new(0,gp);    xh.v2.To = c+Vector2.new(0,gp+sz); xh.v2.Color=col; xh.v2.Thickness=th
        xh.h1.From = c-Vector2.new(gp+sz,0); xh.h1.To = c-Vector2.new(gp,0); xh.h1.Color=col; xh.h1.Thickness=th
        xh.h2.From = c+Vector2.new(gp,0);    xh.h2.To = c+Vector2.new(gp+sz,0); xh.h2.Color=col; xh.h2.Thickness=th
        xh.dot.Position=c; xh.dot.Radius=1; xh.dot.Color=col; xh.dot.Filled=true
    end

    -- logs label
    local lines = {}
    for i=1, math.min(#State.HitLog, 8) do
        lines[#lines+1] = string.format("[%s] %s", State.HitLog[i].t, State.HitLog[i].msg)
    end
    for i=1, math.min(#State.KillLog, 8) do
        lines[#lines+1] = string.format("[%s] KILL %s", State.KillLog[i].t, State.KillLog[i].victim)
    end
    liveLog:SetText(table.concat(lines, "\n"))
end

------------------------------------------------------------
-- 31. kill detection → log + resolver feedback
------------------------------------------------------------
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(c)
        local hum = c:WaitForChild("Humanoid", 5)
        if hum then
            hum.Died:Connect(function()
                if State.Target == plr then
                    State.Stats.kills += 1
                    lastKillAt = os.clock()
                    resolver_hit(plr)
                    table.insert(State.KillLog, 1, {t=os.date("%H:%M:%S"), victim=plr.Name})
                    if Toggles.SoundHit.Value then
                        local s = Instance.new("Sound")
                        s.SoundId = "rbxassetid://3744371091"
                        s.Volume = Options.SoundHitVol.Value
                        s.Parent = LP.PlayerGui or LP
                        s:Play(); game:GetService("Debris"):AddItem(s, 2)
                    end
                end
            end)
        end
    end)
end)

------------------------------------------------------------
-- 32. chat spam, anti-afk
------------------------------------------------------------
task.spawn(function()
    while State and not State._stopped do
        task.wait(Options.SpamDelay.Value)
        if Toggles.SpamChat.Value then
            pcall(function()
                local pc = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
                if pc and pc:FindFirstChild("SayMessageRequest") then
                    pc.SayMessageRequest:FireServer(Options.SpamMsg.Value, "All")
                end
            end)
        end
    end
end)

if LP:FindFirstChild("Idled") or true then
    pcall(function()
        trackConn(LP.Idled:Connect(function()
            if Toggles.AntiAfkKick.Value then
                VirtualInput:Button2Down(Vector2.new(), game)
                task.wait(1)
                VirtualInput:Button2Up(Vector2.new(), game)
            end
        end))
    end)
end

------------------------------------------------------------
-- 32.5 PEAK ENGINES: shot bus, on-shot/defensive AA, manual AA,
--      freestanding, at-targets yaw, path replay, blink, dual ghost,
--      teleport-aim, safepoint, delta shot, damage-average rage pick
------------------------------------------------------------
local PeakState = {
    shotAt       = 0,
    defUntil     = 0,
    onShotUntil  = 0,
    aaSide       = 1,                  -- +1 right / -1 left
    ghost2       = nil,
    selfPath     = {},                 -- own backtrack for Fake Pos+ replay
    lastOrigCF   = nil,
    rateBucket   = {},                 -- shot timestamps
    lastBaimAt   = 0,
    baimMiss     = 0,
    blinkCharge  = 0,
}
State.Peak = PeakState

-- hook into fire_shot to feed shot bus + defensive AA
local _origFire = fire_shot
fire_shot = function()
    local now = os.clock()
    -- shots-per-sec rate limit
    while #PeakState.rateBucket > 0 and now - PeakState.rateBucket[1] > 1 do
        table.remove(PeakState.rateBucket, 1)
    end
    if not Toggles.RageFastFire.Value then
        if #PeakState.rateBucket >= (Options.RageShotsPerSec.Value or 30) then return end
    end
    _origFire()
    table.insert(PeakState.rateBucket, now)
    PeakState.shotAt      = now
    PeakState.onShotUntil = now + (Options.AAXOnShotMs.Value or 0)/1000
    PeakState.defUntil    = now + (Options.AAXDefMs.Value   or 0)/1000
    if Toggles.FPXWarpOnShot and Toggles.FPXWarpOnShot.Value and alive(LP) then
        local hrp = LP.Character.HumanoidRootPart
        local off = hrp.CFrame.RightVector * (Options.FPXBlinkDist.Value or 6)
        pcall(function() hrp.CFrame = hrp.CFrame + off end)
    end
end

-- own backtrack push for Fake Pos+ replay
local function self_bt_push()
    if not alive(LP) then return end
    local hrp = LP.Character.HumanoidRootPart
    table.insert(PeakState.selfPath, 1, {t=os.clock(), cf=hrp.CFrame})
    while PeakState.selfPath[#PeakState.selfPath]
      and os.clock() - PeakState.selfPath[#PeakState.selfPath].t > 2 do
        PeakState.selfPath[#PeakState.selfPath] = nil
    end
end
local function self_bt_sample(ms)
    local tgt = os.clock() - ms/1000
    for _, rec in ipairs(PeakState.selfPath) do
        if rec.t <= tgt then return rec end
    end
    return PeakState.selfPath[#PeakState.selfPath]
end

-- freestanding: pick side with most cover
local function freestand_side()
    if not alive(LP) then return 1 end
    local hrp = LP.Character.HumanoidRootPart
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = {LP.Character, Camera}
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local dist = Options.AAXFreeDist.Value
    local rightHit = Workspace:Raycast(hrp.Position, hrp.CFrame.RightVector*dist, rp)
    local leftHit  = Workspace:Raycast(hrp.Position, -hrp.CFrame.RightVector*dist, rp)
    local rScore = rightHit and (dist - (rightHit.Position - hrp.Position).Magnitude) or 0
    local lScore = leftHit  and (dist - (leftHit.Position  - hrp.Position).Magnitude) or 0
    return rScore >= lScore and 1 or -1
end

-- at-targets yaw: face away from best threat
local function at_targets_yaw()
    local best, bd
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and alive(plr) and enemyOf(plr) then
            local hrp = plr.Character.HumanoidRootPart
            local d = (hrp.Position - LP.Character.HumanoidRootPart.Position).Magnitude
            local score = Toggles.AAXAtTargetsBest.Value and -d or d
            if not bd or score < bd then bd, best = score, hrp end
        end
    end
    if not best then return 0 end
    local toThem = best.Position - LP.Character.HumanoidRootPart.Position
    return math.atan2(toThem.X, toThem.Z) + math.pi
end

-- manual AA direction
local function manual_dir()
    if not Toggles.AAXManual.Value then return nil end
    if Options.AAXManualL:GetState() then return  math.pi*0.5 end
    if Options.AAXManualR:GetState() then return -math.pi*0.5 end
    if Options.AAXManualB:GetState() then return  math.pi     end
    if Options.AAXManualF:GetState() then return  0           end
    return nil
end

-- peak anti-aim: builds the final CFrame each tick
local function peak_aa_tick()
    if not Toggles.AAXEnabled.Value then return end
    if not alive(LP) then return end
    local hum = LP.Character:FindFirstChildOfClass("Humanoid")
    local hrp = LP.Character.HumanoidRootPart
    if not hum or not hrp then return end
    hum.AutoRotate = false

    -- base yaw
    local base = Options.AAXYawBase.Value
    local yaw = 0
    local md = manual_dir()
    if md then yaw = md
    elseif base == "At-Targets" and Toggles.AAXAtTargets.Value then yaw = at_targets_yaw()
    elseif base == "Freestanding" and Toggles.AAXFreestand.Value then
        yaw = math.pi + (freestand_side() * math.rad(Options.AAXDesyncR.Value))
    elseif base == "Target" and State.Target and alive(State.Target) then
        local toThem = State.Target.Character.HumanoidRootPart.Position - hrp.Position
        yaw = math.atan2(toThem.X, toThem.Z) + math.pi
    elseif base == "Local" then yaw = select(2, Camera.CFrame:ToEulerAnglesYXZ())
    else yaw = 0 end
    yaw = yaw + math.rad(Options.AAXYawAdd.Value)

    -- yaw modifier
    local mod = Options.AAXYawMod.Value
    local deg = math.rad(Options.AAXYawModDeg.Value)
    local hz  = Options.AAXYawModHz.Value
    if mod == "Offset" then yaw = yaw + deg
    elseif mod == "Spin" then yaw = yaw + (os.clock()*hz)%(math.pi*2)
    elseif mod == "Jitter" then yaw = yaw + (((os.clock()*hz)%2<1) and deg or -deg)
    elseif mod == "Random" then yaw = yaw + math.rad(math.random(-math.deg(deg), math.deg(deg)))
    elseif mod == "Sway"   then yaw = yaw + math.sin(os.clock()*hz)*deg
    elseif mod == "Center" then yaw = yaw end

    -- desync real: swap side per tick
    if Toggles.AAXDesyncReal.Value then
        PeakState.aaSide = -PeakState.aaSide
        local d = (PeakState.aaSide>0) and Options.AAXDesyncR.Value or -Options.AAXDesyncL.Value
        yaw = yaw + math.rad(d)
    end

    -- inverter flips
    if Options.AAXInvert:GetState() then yaw = -yaw end
    -- lby break
    if Toggles.AAXLBYBreak.Value then yaw = yaw + math.sin(os.clock()*4)*math.rad(5) end
    -- micro jitter
    if Toggles.AAXYawJitterExtra.Value then
        yaw = yaw + math.rad(math.random(-Options.AAXMicroDeg.Value, Options.AAXMicroDeg.Value))
    end
    -- on-shot flip
    if Toggles.AAXOnShot.Value and os.clock() < PeakState.onShotUntil then
        yaw = yaw + math.rad(Options.AAXOnShotDeg.Value)
    end
    -- defensive post-shot tilt
    if Toggles.AAXDefensive.Value and os.clock() < PeakState.defUntil then
        yaw = yaw + math.rad(math.sin(os.clock()*18)*25)
    end

    -- pitch
    local p = Options.AAXPitch.Value
    local pdeg = math.rad(Options.AAXPitchDeg.Value)
    local pitch = 0
    if p == "Down" then pitch = -pdeg
    elseif p == "Up" then pitch = pdeg
    elseif p == "Zero" then pitch = 0
    elseif p == "Fake" then pitch = ((math.floor(os.clock()*4)%2)==0) and -pdeg or pdeg
    elseif p == "Jitter" then pitch = (os.clock()*10)%2<1 and -pdeg or pdeg end

    -- roll
    local r = Options.AAXRoll.Value
    local rdeg = math.rad(Options.AAXRollDeg.Value)
    local roll = 0
    if r == "Left" then roll = -rdeg
    elseif r == "Right" then roll = rdeg
    elseif r == "Alternate" then roll = ((math.floor(os.clock()*2)%2)==0) and rdeg or -rdeg
    elseif r == "Sway" then roll = math.sin(os.clock()*2)*rdeg end

    -- sine sway overlay
    if Toggles.AAXSway.Value then
        yaw   = yaw + math.sin(os.clock()*Options.AAXSwayHz.Value)*math.rad(Options.AAXSwayDeg.Value)
        pitch = pitch + math.cos(os.clock()*Options.AAXSwayHz.Value)*math.rad(Options.AAXSwayDeg.Value*0.4)
    end

    hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(pitch, yaw, roll)
    State.LastDesyncYaw = yaw
end

-- peak fake pos: engines, dual ghost, replay, blink, mirror
local function ensure_ghost(key, color)
    if not State.Chams._ghosts then State.Chams._ghosts = {} end
    local g = State.Chams._ghosts[key]
    if g and g.Parent then return g end
    g = Instance.new("Part")
    g.Size = Vector3.new(2,5,1)
    g.Anchored = true; g.CanCollide = false
    g.Material = Enum.Material.ForceField
    g.Color = color or Color3.fromRGB(0,255,170)
    g.Transparency = 0.4
    g.Parent = Workspace
    State.Chams._ghosts[key] = g
    return g
end
local function kill_ghost(key)
    if State.Chams._ghosts and State.Chams._ghosts[key] then
        State.Chams._ghosts[key]:Destroy()
        State.Chams._ghosts[key] = nil
    end
end

local function peak_fakepos_tick()
    if not Toggles.FPXEnabled.Value then
        kill_ghost("g1") kill_ghost("g2")
        return
    end
    if not alive(LP) then return end
    local hrp = LP.Character.HumanoidRootPart
    local engine = Options.FPXEngine.Value
    local R = Options.FPXRadius.Value
    local H = Options.FPXHeight.Value
    local S = Options.FPXSpeed.Value
    local t = os.clock() * S
    local pos1, pos2

    if engine == "OrbitDual" then
        pos1 = hrp.Position + Vector3.new(math.cos(t)*R, H, math.sin(t)*R)
        pos2 = hrp.Position + Vector3.new(math.cos(t+math.pi)*R, H, math.sin(t+math.pi)*R)
    elseif engine == "Strafe" then
        pos1 = hrp.Position + hrp.CFrame.RightVector*R + Vector3.new(0,H,0)
        pos2 = hrp.Position - hrp.CFrame.RightVector*R + Vector3.new(0,H,0)
    elseif engine == "PathReplay" then
        local rec = self_bt_sample(Options.FPXReplayMs.Value)
        pos1 = rec and rec.cf.Position or hrp.Position
        pos2 = hrp.Position + Vector3.new(math.cos(t)*R*0.5, H, math.sin(t)*R*0.5)
    elseif engine == "Mirror" then
        if State.Target and alive(State.Target) then
            local T = State.Target.Character.HumanoidRootPart.Position
            local mid = (T + hrp.Position)*0.5
            pos1 = mid*2 - hrp.Position + Vector3.new(0,H,0)
            pos2 = hrp.Position + (hrp.Position - T).Unit*R + Vector3.new(0,H,0)
        else
            pos1 = hrp.Position + Vector3.new(R,H,0); pos2 = hrp.Position - Vector3.new(R,H,0)
        end
    elseif engine == "PingTP" then
        local phase = (math.floor(t*2)%3)
        if phase==0 then pos1 = hrp.Position + Vector3.new(R,H,0)
        elseif phase==1 then pos1 = hrp.Position + Vector3.new(0,H,R)
        else pos1 = hrp.Position + Vector3.new(-R,H,0) end
        pos2 = hrp.Position - (pos1 - hrp.Position)
    elseif engine == "Split" then
        pos1 = hrp.Position + Vector3.new(R,H,R)
        pos2 = hrp.Position + Vector3.new(-R,H,-R)
    elseif engine == "Choke-Freeze" then
        if State.Choke > 0 and not PeakState.frozenAt then PeakState.frozenAt = hrp.Position end
        if State.Choke == 0 then PeakState.frozenAt = nil end
        pos1 = PeakState.frozenAt or hrp.Position
        pos2 = hrp.Position + Vector3.new(math.cos(t)*R, H, math.sin(t)*R)
    elseif engine == "Warp" then
        pos1 = hrp.Position + hrp.CFrame.LookVector*R + Vector3.new(0,H,0)
        pos2 = hrp.Position - hrp.CFrame.LookVector*R + Vector3.new(0,H,0)
    else -- Zigzag+
        pos1 = hrp.Position + Vector3.new(math.sin(t*3)*R, H, math.cos(t*2)*R)
        pos2 = hrp.Position + Vector3.new(math.cos(t*3)*R, H, math.sin(t*2)*R)
    end

    -- mirror override
    if Toggles.FPXMirror.Value and State.Target and alive(State.Target) then
        local T = State.Target.Character.HumanoidRootPart.Position
        pos2 = T*2 - pos1
    end
    -- blink shove
    if Toggles.FPXBlink.Value and Options.FPXBlinkKey:GetState() then
        local push = hrp.CFrame.RightVector * Options.FPXBlinkDist.Value
        pos1 = pos1 + push
    end
    -- freeze on peek
    if Toggles.FPXFreezeOnPeek.Value and Options.RageKeybind:GetState() then
        pos1 = PeakState.frozenAt or pos1
    end

    local col = Color3.fromRGB(0,255,170)
    if Toggles.FPXColorShift.Value then
        col = Color3.fromHSV((os.clock()*0.2)%1, 0.9, 1)
    end

    local g1 = ensure_ghost("g1", col)
    g1.CFrame = CFrame.new(pos1); g1.Transparency = Options.FPXAlpha.Value; g1.Color = col
    if Toggles.FPXDualGhost.Value then
        local g2 = ensure_ghost("g2", col:Lerp(Color3.new(1,1,1), 0.4))
        g2.CFrame = CFrame.new(pos2); g2.Transparency = Options.FPXAlpha.Value*0.9
        g2.Color  = col:Lerp(Color3.new(1,1,1), 0.4)
    else kill_ghost("g2") end
end

-- peak rage layer: safepoint + damage avg + teleport-aim + delta + adaptive baim
local function peak_rage_layer()
    if not State.Target or not State.AimPos then return end
    if not alive(State.Target) then return end
    local tgt = State.Target
    local char = tgt.Character
    local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    if not head then return end

    -- teleport aim snap
    if Toggles.RageTPAim.Value and alive(LP) then
        local hrp = LP.Character.HumanoidRootPart
        local dir = (head.Position - hrp.Position)
        if dir.Magnitude > Options.RageTPAimDist.Value then
            local tp = head.Position - dir.Unit * Options.RageTPAimDist.Value
            pcall(function() hrp.CFrame = CFrame.new(tp, head.Position) end)
        end
    end
    -- safepoint: bias aim toward part center + visibility
    if Toggles.RageSafepoint.Value then
        local b = Options.RageSafepointBias.Value
        State.AimPos = State.AimPos:Lerp(head.Position, b)
    end
    -- force headshot
    if Toggles.RageForceHS.Value and char:FindFirstChild("Head") then
        State.AimPos = char.Head.Position
    end
    -- adaptive body aim after N misses
    if Toggles.RageAdaptiveBaim.Value then
        local r = State.Resolver[tgt] or {misses=0}
        if r.misses >= Options.RageBaimMiss.Value then
            local body = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or head
            State.AimPos = body.Position
            PeakState.lastBaimAt = os.clock()
        end
    end
    -- confidence gate (secondary to hitchance)
    if Toggles.RageQuickStop.Value and alive(LP) then
        local hum = LP.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 0 end
    end
end

-- blink: stack chokes then release
local function peak_blink_tick()
    if not Toggles.RageBlink.Value then PeakState.blinkCharge = 0 return end
    if not alive(LP) then return end
    if Options.RageBlinkKey:GetState() then
        PeakState.blinkCharge = math.min(PeakState.blinkCharge + 1, Options.RageBlinkTicks.Value)
        local hrp = LP.Character.HumanoidRootPart
        pcall(function() hrp.CanCollide = hrp.CanCollide end)
    else
        if PeakState.blinkCharge > 0 then
            local hrp = LP.Character.HumanoidRootPart
            local push = Camera.CFrame.LookVector * PeakState.blinkCharge
            pcall(function() hrp.CFrame = hrp.CFrame + push end)
            PeakState.blinkCharge = 0
        end
    end
end

-- fake duck + slow walk
local function peak_move_mods()
    if not alive(LP) then return end
    local hum = LP.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if Toggles.RageSlowWalk.Value and Options.RageSlowKey:GetState() then
        hum.WalkSpeed = Options.RageSlowSpeed.Value
    end
    if Toggles.RageFakeDuck.Value and Options.RageFakeDuckKey:GetState() then
        hum:ChangeState(Enum.HumanoidStateType.Physics)
        pcall(function() LP.Character.HumanoidRootPart.CFrame =
            LP.Character.HumanoidRootPart.CFrame * CFrame.new(0, -0.5 + math.sin(os.clock()*20)*0.1, 0) end)
    end
end

-- HUD desync arrow
local desyncArrow = trackDraw(Drawing.new("Triangle"))
desyncArrow.Filled = true; desyncArrow.Visible = false; desyncArrow.Color = Color3.fromRGB(0,255,170)
local function peak_hud()
    if not Toggles.AAXShowArrow.Value or not alive(LP) then
        desyncArrow.Visible=false return
    end
    local c = Camera.ViewportSize/2
    local yaw = State.LastDesyncYaw or 0
    local len = 50
    local tip = c + Vector2.new(math.sin(yaw), -math.cos(yaw)) * len
    local l   = c + Vector2.new(math.sin(yaw+2.6), -math.cos(yaw+2.6)) * 15
    local r   = c + Vector2.new(math.sin(yaw-2.6), -math.cos(yaw-2.6)) * 15
    desyncArrow.Visible=true
    desyncArrow.PointA=tip; desyncArrow.PointB=l; desyncArrow.PointC=r
end

------------------------------------------------------------
-- 33. main scheduler
------------------------------------------------------------
trackConn(RunService.Heartbeat:Connect(function(dt)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then bt_push(plr) end
    end
    self_bt_push()
    rage_tick()
    peak_rage_layer()
    peak_blink_tick()
    legit_tick()
    trigger_tick()
    fake_pos_update()
    peak_fakepos_tick()
    antiaim_tick()
    peak_aa_tick()
    fakelag_tick()
    movement_tick()
    peak_move_mods()
    world_tick()
    esp_tick()
    hud_tick()
    peak_hud()
end))

------------------------------------------------------------
-- 34. config save/load/unload
------------------------------------------------------------
local CG = Tabs.Config:AddLeftGroupbox("UE V3 Config")
CG:AddInput("UEVConfigName", {Default = "default", Numeric=false, Finished=true, Text="Config Name"})
CG:AddButton("Save", function()
    local data = {Options={}, Toggles={}}
    for k,v in pairs(Options) do if v.Value~=nil and type(v.Value)~="function" then data.Options[k]=v.Value end end
    for k,v in pairs(Toggles) do if v.Value~=nil then data.Toggles[k]=v.Value end end
    local ok, enc = pcall(HttpService.JSONEncode, HttpService, data)
    if ok then writefile("UEV3_"..Options.UEVConfigName.Value..".json", enc) end
    Library:Notify("UE V3 saved: "..Options.UEVConfigName.Value, 3)
end)
CG:AddButton("Load", function()
    local f = "UEV3_"..Options.UEVConfigName.Value..".json"
    if not isfile(f) then Library:Notify("no config", 3) return end
    local d = HttpService:JSONDecode(readfile(f))
    for k,v in pairs(d.Options or {}) do if Options[k] and Options[k].SetValue then pcall(Options[k].SetValue, Options[k], v) end end
    for k,v in pairs(d.Toggles or {}) do if Toggles[k] and Toggles[k].SetValue then pcall(Toggles[k].SetValue, Toggles[k], v) end end
    Library:Notify("UE V3 loaded", 3)
end)
CG:AddButton("Unload UE V3", function()
    State._stopped = true
    for _,c in ipairs(State.Connections) do pcall(function() c:Disconnect() end) end
    for _,d in ipairs(State.Drawings) do pcall(function() d:Remove() end) end
    for p,_ in pairs(State.Chams) do esp_destroy(p) end
    if State.FakeGhost then State.FakeGhost:Destroy() end
    Library:Unload()
    getgenv().UE_V3 = nil
end)

State.Unload = function()
    State._stopped = true
    for _,c in ipairs(State.Connections) do pcall(function() c:Disconnect() end) end
    for _,d in ipairs(State.Drawings) do pcall(function() d:Remove() end) end
    for p,_ in pairs(State.Chams) do esp_destroy(p) end
    if State.FakeGhost then State.FakeGhost:Destroy() end
    pcall(function() Library:Unload() end)
end

Library:Notify("Unnamed Enhancements V3 — built by olivia — discord.gg/ojailbreaks", 5)
