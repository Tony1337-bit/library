--[[
============================================================================
 NOVA UI LIBRARY  v2.0.0

 A single-file, fluent Roblox/Luau UI library. Drop it into any executor,
 then build tabs/cards/toggles/actions, a top-right info stack, a sidebar
 and a draggable HUD watermark through one root object: `Nova`.

 The library chunk RETURNS `Nova` (so `loadstring(...)()` gives it back) and
 also exposes it on the environment as `NovaUI` when `getgenv` exists.

 ── QUICK START ──────────────────────────────────────────────────────────
   local Nova = NovaUI   -- or capture the loadstring return value

   Nova.createWindow()                        -- all window chrome (search, sidebar,
                                              -- footer, RightShift UI toggle)

   -- Tabs & cards -------------------------------------------------------
   local rage = Nova:create("Rage")           -- new tab (auto column balancing)
   rage:card("Fighting")
       :toggle("Attack Aura")                 -- plain toggle
       :toggle("Trigger Bot", "auto fires", false, "F1")   -- keybind badge
       :toggle("Aim Assist", nil, false, "F")              -- keyboard key
       :toggle("Tap Aim", nil, false, Enum.UserInputType.MouseButton2) -- mouse!
       :action("Print", "debug demo", function() print("hi") end)

   -- Switches / dropdowns / sliders ---------------------------------------
   rage:card("Options")
       :dropdown("Target Part", "pick an aim point", {"Head", "Torso", "Root"}, 1,
                 function(opt, idx) print("target", opt) end)
       :slider("Aim Speed", "how fast it locks", 0, 100, 50,
               function(v) print("speed", v) end, "%")

   Nova:select("Rage")                        -- open a tab programmatically

   -- Categories / sidebar ------------------------------------------------
   local sb = Nova:sidebar()
   sb:category("Aimbot")
   sb:tab("Rage", Nova.Icons.Combat, true)    -- (name, icon, defaultActive)

   -- Top-right info stack -------------------------------------------------
   local info = Nova:info()
   local GameLine    = info:line("Loading game...", true)   -- primary (bold)
   local VersionLine = info:line(Nova.Config.Version, false)

   -- HUD watermark pills ---------------------------------------------------
   local hud = Nova:hud()
   local top = hud:row("TopRow", 22, 1)
   local stats = top:pill(2)
   stats:icon(Nova.Icons.User, 1)
   local fps = stats:text("0 FPS", false, 5)   -- returns the TextLabel

   -- Theme ------------------------------------------------------------------
   Nova:setTheme({ Accent = Color3.fromRGB(80, 200, 255) })  -- before building

   -- Configs (create / save / load / delete / import / export) ---------------
   local cfg = Nova:createConfig("Main")      -- new (or existing) config
   cfg:save()                                 -- pull widget values -> disk
   cfg:load()                                 -- push saved values to widgets
   cfg:delete()                               -- remove the stored config
   local json = cfg:export()                  -- all values as a JSON string
   cfg:import(json)                           -- parse + apply a JSON string
   Nova:configNames()                         -- {"Main"}

   -- Teardown ----------------------------------------------------------------
   Nova:unload()   -- kills every tracked connection + destroys the GUI

 See the `RUN_EXAMPLE` block at the bottom for a complete, running demo.
============================================================================
--]]

-- Default configuration ----------------------------------------------
local Nova = {}
Nova.Version = "2.0.0"

Nova.Config = {
    GuiName      = "NovaUI",                       -- ScreenGui instance name
    LogoId       = "rbxassetid://139568612294283", -- window + HUD logo asset
    Version      = "v2.0.0",                       -- shown in the info stack
    FooterSub    = "",                             -- small footer caption
    HudSaveFile  = "NovaHudLayout.json",           -- where HUD positions persist
    ConfigFile   = "NovaConfigs.json",             -- where widget configs persist
    ToggleUiKey  = Enum.KeyCode.RightShift,        -- show/hide the window
    Parent       = nil,                            -- nil => gethui()/PlayerGui
}

-- Unified theme tokens (mutate before building)
Nova.Theme = {
    Background    = Color3.fromRGB(12, 9, 11),
    CardBg        = Color3.fromRGB(18, 13, 16),
    PillBg        = Color3.fromRGB(16, 12, 14),
    SidebarActive = Color3.fromRGB(27, 16, 19),
    Border        = Color3.fromRGB(36, 24, 28),
    BorderActive  = Color3.fromRGB(90, 36, 42),
    Accent        = Color3.fromRGB(246, 92, 82),
    AccentSoft    = Color3.fromRGB(255, 165, 155),
    AccentDark    = Color3.fromRGB(130, 40, 42),
    TextPrimary   = Color3.fromRGB(235, 235, 235),
    TextMuted     = Color3.fromRGB(120, 110, 115),
    TextDim       = Color3.fromRGB(72, 64, 68),
    Divider       = Color3.fromRGB(48, 36, 40),
    BadgeBg       = Color3.fromRGB(25, 18, 22),
    ToggleOff     = Color3.fromRGB(36, 28, 32),
    KnobOff       = Color3.fromRGB(78, 68, 73),
    KnobOn        = Color3.fromRGB(255, 255, 255),
}

-- Monochrome vector assets (exposed so examples can reuse them)
Nova.Icons = {
    Search   = "rbxassetid://7733911828",
    Chevron  = "rbxassetid://7733717447",
    More     = "rbxassetid://7734021300",
    Menu     = "rbxassetid://7733993211",
    Combat   = "rbxassetid://7734053426",
    Movement = "rbxassetid://7733799901",
    Visuals  = "rbxassetid://7733774602",
    Player   = "rbxassetid://7733954760",
    Misc     = "rbxassetid://7734056411",
    Presets  = "rbxassetid://7733964719",
    AutoBuy  = "rbxassetid://7733942651",
    Accounts = "rbxassetid://7733765307",
    User     = "rbxassetid://7733954760",
    Chart    = "rbxassetid://7733749837",
    Clock    = "rbxassetid://7733734762",
    Compass  = "rbxassetid://7733720755",
    Signal   = "rbxassetid://7734058495",
    Radar    = "rbxassetid://7734053426",
    Speed    = "rbxassetid://7733799901",
}

-- Services ------------------------------------------------------------
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local THEME = Nova.Theme
local ICONS = Nova.Icons

local TWEEN_FAST = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_SLOW = TweenInfo.new(0.35, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)

-- Internal (single-window) instance state ------------------------------
-- Engine-global connections (UserInputService / RunService) are NOT
-- descendants of the ScreenGui, so Destroy() won't disconnect them — each
-- has to be tracked here and explicitly torn down via Nova:unload().
local trackedConnections = {}
local function track(connection)
    table.insert(trackedConnections, connection)
    return connection
end

local ScreenGui = nil
local Main = nil
local GlowBackdrop = nil
local TopBar = nil
local SearchInput = nil
local InfoStack = nil
local ContentArea = nil
local Sidebar = nil
local HudLayout = {}

local tabPages = {}          -- name -> {Page, Col1, Col2}
local activePage = nil
local sidebarSelectors = {}  -- name -> selector fn (used by search too)
local activeSidebarTab = nil
local registeredRows = {}
local configBindings = {}  -- key -> {kind = "...", get = fn, set = fn}

local preSearchTab = nil
local ActiveDropdown = nil
local KeybindListening = nil
local isUIVisible = true

local function getParent()
    if Nova.Config.Parent then
        return Nova.Config.Parent
    end
    return (gethui and gethui()) or LocalPlayer:WaitForChild("PlayerGui")
end

-- HUD layout persistence -------------------------------------------------
local function loadHudLayout()
    local layout = {
        TopRow = {X = 16, Y = 48, Enabled = true},
        BottomRow = {X = 16, Y = 74, Enabled = true},
    }

    local ok, result = pcall(function()
        local file = Nova.Config.HudSaveFile
        if isfile and isfile(file) then
            return HttpService:JSONDecode(readfile(file))
        end
        return nil
    end)

    if ok and result then
        for rowName, data in pairs(result) do
            if layout[rowName] then
                layout[rowName].X = data.X or layout[rowName].X
                layout[rowName].Y = data.Y or layout[rowName].Y
                if data.Enabled ~= nil then
                    layout[rowName].Enabled = data.Enabled
                end
            end
        end
    end

    return layout
end

local function saveHudLayout()
    pcall(function()
        if writefile then
            local encoded = HttpService:JSONEncode(HudLayout)
            writefile(Nova.Config.HudSaveFile, encoded)
        end
    end)
end

-- =============================================================================
-- Low-level widget builders
-- Internal. The public fluent API (Nova:hud() :info() :sidebar() :create())
-- is defined after these; each method only runs at call time, so the helpers
-- can be declared anywhere above the point they are actually used.
-- =============================================================================

function Nova.createWindow()
    -- Tear down any previous instance (gui hot-reload).
    if CoreGui:FindFirstChild(Nova.Config.GuiName) then
        CoreGui[Nova.Config.GuiName]:Destroy()
    end

    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = Nova.Config.GuiName
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = getParent()

    HudLayout = loadHudLayout()

    -- Window frame ----------------------------------------------------------
    -- CanvasGroup (not Frame): GroupTransparency cascades to every child, which
    -- is what makes the UI-toggle fades fade everything together.
    Main = Instance.new("CanvasGroup")
    Main.Name = "MainFrame"
    Main.Size = UDim2.new(0, 790, 0, 490)
    Main.Position = UDim2.new(0.5, -395, 0.5, -245)
    Main.BackgroundColor3 = THEME.Background
    Main.BorderSizePixel = 0
    Main.ClipsDescendants = false
    Main.Parent = ScreenGui

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 12)
    MainCorner.Parent = Main

    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = THEME.Border
    MainStroke.Thickness = 1.2
    MainStroke.Parent = Main

    -- Ambient backlight glow
    GlowBackdrop = Instance.new("ImageLabel")
    GlowBackdrop.Name = "GlowBackdrop"
    GlowBackdrop.BackgroundTransparency = 1
    GlowBackdrop.Position = UDim2.new(0, -45, 0, -45)
    GlowBackdrop.Size = UDim2.new(1, 90, 1, 90)
    GlowBackdrop.ZIndex = 0
    GlowBackdrop.Image = "rbxassetid://5028857084"
    GlowBackdrop.ImageColor3 = THEME.AccentDark
    GlowBackdrop.ImageTransparency = 0.83
    GlowBackdrop.ScaleType = Enum.ScaleType.Slice
    GlowBackdrop.SliceCenter = Rect.new(24, 24, 276, 276)
    GlowBackdrop.Parent = Main

    -- Dragging system --------------------------------------------------------
    do
        local dragging, dragStart, startPos
        Main.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = input.Position
                startPos = Main.Position
            end
        end)
        track(UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position - dragStart
                TweenService:Create(Main, TweenInfo.new(0.04), {
                    Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
                }):Play()
            end
        end))
        track(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end))
    end

    -- Top bar ---------------------------------------------------------------
    TopBar = Instance.new("Frame")
    TopBar.Size = UDim2.new(1, 0, 0, 56)
    TopBar.BackgroundTransparency = 1
    TopBar.Parent = Main

    -- Logo (holder + halo + shadow + main + gradient)
    local MainLogoHolder = Instance.new("Frame")
    MainLogoHolder.Name = "LogoHolder"
    MainLogoHolder.Size = UDim2.new(0, 64, 0, 64)
    MainLogoHolder.Position = UDim2.new(0, 52, 0, -4)
    MainLogoHolder.BackgroundTransparency = 1
    MainLogoHolder.Parent = TopBar

    local MainLogoHalo = Instance.new("ImageLabel")
    MainLogoHalo.Name = "Halo"
    MainLogoHalo.Size = UDim2.new(2.1, 0, 2.1, 0)
    MainLogoHalo.Position = UDim2.new(-0.55, 0, -0.55, 0)
    MainLogoHalo.BackgroundTransparency = 1
    MainLogoHalo.Image = "rbxassetid://5028857084"
    MainLogoHalo.ImageColor3 = THEME.Accent
    MainLogoHalo.ImageTransparency = 0.58
    MainLogoHalo.ZIndex = 1
    MainLogoHalo.Parent = MainLogoHolder

    local MainLogoShadow = Instance.new("ImageLabel")
    MainLogoShadow.Name = "LogoShadow"
    MainLogoShadow.Size = UDim2.new(1, 0, 1, 0)
    MainLogoShadow.Position = UDim2.new(0, 2, 0, 2)
    MainLogoShadow.BackgroundTransparency = 1
    MainLogoShadow.Image = Nova.Config.LogoId
    MainLogoShadow.ScaleType = Enum.ScaleType.Fit
    MainLogoShadow.ImageColor3 = Color3.fromRGB(50, 10, 14)
    MainLogoShadow.ImageTransparency = 0.2
    MainLogoShadow.ZIndex = 2
    MainLogoShadow.Parent = MainLogoHolder

    local MainLogoImg = Instance.new("ImageLabel")
    MainLogoImg.Name = "LogoMain"
    MainLogoImg.Size = UDim2.new(1, 0, 1, 0)
    MainLogoImg.Position = UDim2.new(0, 0, 0, 0)
    MainLogoImg.BackgroundTransparency = 1
    MainLogoImg.Image = Nova.Config.LogoId
    MainLogoImg.ScaleType = Enum.ScaleType.Fit
    MainLogoImg.ImageColor3 = Color3.fromRGB(255, 255, 255)
    MainLogoImg.ZIndex = 3
    MainLogoImg.Parent = MainLogoHolder

    local MainLogoGrad = Instance.new("UIGradient")
    MainLogoGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 175, 165)),
        ColorSequenceKeypoint.new(0.45, Color3.fromRGB(246, 92, 82)),
        ColorSequenceKeypoint.new(1.0, Color3.fromRGB(165, 32, 42))
    })
    MainLogoGrad.Rotation = -35
    MainLogoGrad.Parent = MainLogoImg

    -- Search bar ------------------------------------------------------------
    local SearchBox = Instance.new("Frame")
    SearchBox.Size = UDim2.new(0, 250, 0, 26)
    SearchBox.Position = UDim2.new(0, 185, 0, 15)
    SearchBox.BackgroundColor3 = THEME.CardBg
    SearchBox.BorderSizePixel = 0
    SearchBox.Parent = TopBar

    local SearchCorner = Instance.new("UICorner")
    SearchCorner.CornerRadius = UDim.new(0, 6)
    SearchCorner.Parent = SearchBox

    local SearchStroke = Instance.new("UIStroke")
    SearchStroke.Color = THEME.Border
    SearchStroke.Thickness = 0.8
    SearchStroke.Parent = SearchBox

    local SearchIcon = Instance.new("ImageLabel")
    SearchIcon.Size = UDim2.new(0, 13, 0, 13)
    SearchIcon.Position = UDim2.new(0, 9, 0.5, -6.5)
    SearchIcon.BackgroundTransparency = 1
    SearchIcon.Image = ICONS.Search
    SearchIcon.ImageColor3 = THEME.TextMuted
    SearchIcon.Parent = SearchBox

    SearchInput = Instance.new("TextBox")
    SearchInput.PlaceholderText = "Search something"
    SearchInput.PlaceholderColor3 = THEME.TextMuted
    SearchInput.TextColor3 = THEME.TextPrimary
    SearchInput.Font = Enum.Font.Gotham
    SearchInput.TextSize = 11
    SearchInput.Position = UDim2.new(0, 30, 0, 0)
    SearchInput.Size = UDim2.new(1, -36, 1, 0)
    SearchInput.BackgroundTransparency = 1
    SearchInput.TextXAlignment = Enum.TextXAlignment.Left
    SearchInput.Parent = SearchBox

    -- Top-right info stack (lines added via Nova:info())
    InfoStack = Instance.new("Frame")
    InfoStack.Name = "InfoStack"
    InfoStack.Size = UDim2.new(0, 170, 0, 40)
    InfoStack.Position = UDim2.new(1, -210, 0.5, -20)
    InfoStack.BackgroundTransparency = 1
    InfoStack.Parent = TopBar

    local InfoLayout = Instance.new("UIListLayout")
    InfoLayout.SortOrder = Enum.SortOrder.LayoutOrder
    InfoLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    InfoLayout.Padding = UDim.new(0, 1)
    InfoLayout.Parent = InfoStack

    -- Content area ----------------------------------------------------------
    ContentArea = Instance.new("Frame")
    ContentArea.Size = UDim2.new(1, -195, 1, -62)
    ContentArea.Position = UDim2.new(0, 182, 0, 54)
    ContentArea.BackgroundTransparency = 1
    ContentArea.Parent = Main

    -- Sidebar --------------------------------------------------------------- 
    Sidebar = Instance.new("Frame")
    Sidebar.Size = UDim2.new(0, 155, 1, -58)
    Sidebar.Position = UDim2.new(0, 14, 0, 54)
    Sidebar.BackgroundTransparency = 1
    Sidebar.Parent = Main

    local SideList = Instance.new("UIListLayout")
    SideList.Padding = UDim.new(0, 2)
    SideList.SortOrder = Enum.SortOrder.LayoutOrder
    SideList.Parent = Sidebar

    -- Footer watermark ------------------------------------------------------
    local Footer = Instance.new("Frame")
    Footer.Size = UDim2.new(0, 160, 0, 28)
    Footer.Position = UDim2.new(0, 18, 1, -38)
    Footer.BackgroundTransparency = 1
    Footer.Parent = Main

    local UserLabel = Instance.new("TextLabel")
    UserLabel.Size = UDim2.new(1, 0, 0, 13)
    UserLabel.BackgroundTransparency = 1
    UserLabel.Text = string.lower(LocalPlayer.Name)
    UserLabel.Font = Enum.Font.GothamBold
    UserLabel.TextSize = 10
    UserLabel.TextColor3 = THEME.TextMuted
    UserLabel.TextXAlignment = Enum.TextXAlignment.Left
    UserLabel.Parent = Footer

    local SubLabel = Instance.new("TextLabel")
    SubLabel.Size = UDim2.new(1, 0, 0, 11)
    SubLabel.Position = UDim2.new(0, 0, 0, 13)
    SubLabel.BackgroundTransparency = 1
    SubLabel.Text = Nova.Config.FooterSub
    SubLabel.Font = Enum.Font.Gotham
    SubLabel.TextSize = 7.5
    SubLabel.TextColor3 = THEME.TextDim
    SubLabel.TextXAlignment = Enum.TextXAlignment.Left
    SubLabel.Parent = Footer

    -- Cross-tab search filtering --------------------------------------------
    SearchInput:GetPropertyChangedSignal("Text"):Connect(function()
        local query = SearchInput.Text:lower()

        local cards = {}
        for _, item in ipairs(registeredRows) do
            cards[item.Card] = true
        end
        local allCards = {}
        for card in pairs(cards) do
            table.insert(allCards, card)
        end

        if query == "" then
            for _, item in ipairs(registeredRows) do
                item.Frame.Visible = true
            end
            for _, card in ipairs(allCards) do
                card.Visible = true
            end
            if preSearchTab and sidebarSelectors[preSearchTab] then
                sidebarSelectors[preSearchTab]()
            end
            preSearchTab = nil
            return
        end

        if not preSearchTab then
            for tabName, entry in pairs(tabPages) do
                if entry.Page.Visible then
                    preSearchTab = tabName
                    break
                end
            end
        end

        local cardHasMatch = {}
        local firstMatchTab = nil

        for _, item in ipairs(registeredRows) do
            local matches = string.find(item.Name, query, 1, true) ~= nil
            item.Frame.Visible = matches
            if matches then
                cardHasMatch[item.Card] = true
                if not firstMatchTab then
                    firstMatchTab = item.Tab
                end
            end
        end

        for _, card in ipairs(allCards) do
            card.Visible = cardHasMatch[card] == true
        end

        if firstMatchTab and sidebarSelectors[firstMatchTab] then
            sidebarSelectors[firstMatchTab]()
        end
    end)

    -- UI toggle hotkey (GUI only; HUD stays persistent) --------------------
    isUIVisible = true
    track(UserInputService.InputBegan:Connect(function(input, _gameProcessed)
        -- NOTE: gameProcessed deliberately ignored. Games that bind the toggle
        -- key (e.g. RightShift sprint) mark it processed, which would stop the
        -- window from ever hiding. A focused TextBox still wins (it is marked
        -- as processed), so search keeps working.
        if input.KeyCode == Nova.Config.ToggleUiKey then
            isUIVisible = not isUIVisible
            if isUIVisible then
                Main.Visible = true
                TweenService:Create(Main, TWEEN_SLOW, {
                    Position = UDim2.new(0.5, -395, 0.5, -245),
                    GroupTransparency = 0
                }):Play()
                TweenService:Create(GlowBackdrop, TWEEN_SLOW, {ImageTransparency = 0.83}):Play()
            else
                local hideTween = TweenService:Create(Main, TWEEN_SLOW, {
                    Position = UDim2.new(0.5, -395, 0.5, -215),
                    GroupTransparency = 1
                })
                TweenService:Create(GlowBackdrop, TWEEN_SLOW, {ImageTransparency = 1}):Play()
                hideTween:Play()
                hideTween.Completed:Connect(function()
                    if not isUIVisible then
                        Main.Visible = false
                    end
                end)
            end
        end
    end))

    return Nova
end

-- =============================================================================
-- Raw widget builders (internal engine)
-- =============================================================================

local Widgets = {}

function Widgets.createHudRow(name, height, order)
    local row = Instance.new("Frame")
    row.Name = name
    row.Size = UDim2.new(0, 0, 0, height)
    row.AutomaticSize = Enum.AutomaticSize.X
    row.Position = UDim2.new(0, HudLayout[name].X, 0, HudLayout[name].Y)
    row.BackgroundTransparency = 1
    row.Visible = HudLayout[name].Enabled
    row.LayoutOrder = order
    row.Active = true -- required for InputBegan/dragging to fire on a transparency=1 frame
    row.Parent = ScreenGui

    HudLayout[name].Frame = row

    local hLayout = Instance.new("UIListLayout")
    hLayout.FillDirection = Enum.FillDirection.Horizontal
    hLayout.SortOrder = Enum.SortOrder.LayoutOrder
    hLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    hLayout.Padding = UDim.new(0, 5)
    hLayout.Parent = row

    do
        local dragging, dragStart, startPos
        row.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = row.Position
            end
        end)
        track(UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                row.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end))
        track(UserInputService.InputEnded:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch) then
                dragging = false
                HudLayout[name].X = row.Position.X.Offset
                HudLayout[name].Y = row.Position.Y.Offset
                saveHudLayout()
            end
        end))
    end

    return row
end

function Widgets.createHudPill(parent, order)
    local pill = Instance.new("Frame")
    pill.AutomaticSize = Enum.AutomaticSize.X
    pill.Size = UDim2.new(0, 0, 1, 0)
    pill.BackgroundColor3 = THEME.PillBg
    pill.BorderSizePixel = 0
    pill.LayoutOrder = order
    pill.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = pill

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.Border
    stroke.Thickness = 1
    stroke.Parent = pill

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 6)
    pad.PaddingRight = UDim.new(0, 6)
    pad.Parent = pill

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 5)
    layout.Parent = pill

    return pill
end

function Widgets.addHudDivider(parent, order)
    local div = Instance.new("Frame")
    div.Size = UDim2.new(0, 1, 0, 10)
    div.BackgroundColor3 = THEME.Divider
    div.BorderSizePixel = 0
    div.LayoutOrder = order
    div.Parent = parent
end

function Widgets.addHudText(parent, text, isMuted, order)
    local lbl = Instance.new("TextLabel")
    lbl.AutomaticSize = Enum.AutomaticSize.X
    lbl.Size = UDim2.new(0, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 10.5
    lbl.TextColor3 = isMuted and THEME.TextMuted or THEME.TextPrimary
    lbl.LayoutOrder = order
    lbl.Parent = parent
    return lbl
end

function Widgets.addHudSmallIcon(parent, iconId, order)
    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0, 11, 0, 11)
    icon.BackgroundTransparency = 1
    icon.Image = iconId
    icon.ScaleType = Enum.ScaleType.Fit
    icon.ImageColor3 = THEME.Accent
    icon.LayoutOrder = order
    icon.Parent = parent
    return icon
end

function Widgets.addInfoLine(text, order, isPrimary)
    local lbl = Instance.new("TextLabel")
    lbl.Name = "Line" .. order
    lbl.Size = UDim2.new(1, 0, 0, 12)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.Font = isPrimary and Enum.Font.GothamBold or Enum.Font.Gotham
    lbl.TextSize = isPrimary and 11 or 9.5
    lbl.TextColor3 = isPrimary and THEME.TextPrimary or THEME.TextMuted
    lbl.TextXAlignment = Enum.TextXAlignment.Right
    lbl.LayoutOrder = order
    lbl.Parent = InfoStack
    return lbl
end

function Widgets.createTabPage(tabName)
    local page = Instance.new("Frame")
    page.Name = tabName:gsub("%s+", "") .. "Page"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.Parent = ContentArea

    local col1 = Instance.new("ScrollingFrame")
    col1.Name = "Col1"
    col1.Size = UDim2.new(0.485, 0, 1, 0)
    col1.BackgroundTransparency = 1
    col1.ScrollBarThickness = 0
    col1.Parent = page

    local col2 = Instance.new("ScrollingFrame")
    col2.Name = "Col2"
    col2.Size = UDim2.new(0.485, 0, 1, 0)
    col2.Position = UDim2.new(0.515, 0, 0, 0)
    col2.BackgroundTransparency = 1
    col2.ScrollBarThickness = 0
    col2.Parent = page

    for _, col in ipairs({col1, col2}) do
        local l = Instance.new("UIListLayout")
        l.Padding = UDim.new(0, 12)
        l.SortOrder = Enum.SortOrder.LayoutOrder
        l.Parent = col
    end

    tabPages[tabName] = {Page = page, Col1 = col1, Col2 = col2}
    return col1, col2
end

function Widgets.addCategory(name, order)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.LayoutOrder = order
    lbl.BackgroundTransparency = 1
    lbl.Text = "   " .. name:upper()
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 9
    lbl.TextColor3 = THEME.TextDim
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = Sidebar
end

function Widgets.addSidebarItem(name, iconId, isDefaultActive, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -4, 0, 29)
    btn.LayoutOrder = order
    btn.BackgroundColor3 = isDefaultActive and THEME.SidebarActive or THEME.Background
    btn.BackgroundTransparency = isDefaultActive and 0 or 1
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = Sidebar

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = isDefaultActive and THEME.BorderActive or Color3.fromRGB(0, 0, 0)
    stroke.Transparency = isDefaultActive and 0 or 1
    stroke.Thickness = 1
    stroke.Parent = btn

    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0, 14, 0, 14)
    icon.Position = UDim2.new(0, 9, 0.5, -7)
    icon.BackgroundTransparency = 1
    icon.Image = iconId
    icon.ImageColor3 = isDefaultActive and THEME.Accent or THEME.TextMuted
    icon.Parent = btn

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -32, 1, 0)
    title.Position = UDim2.new(0, 30, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = name
    title.Font = Enum.Font.GothamMedium
    title.TextSize = 11
    title.TextColor3 = isDefaultActive and THEME.TextPrimary or THEME.TextMuted
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = btn

    -- If no default-active button exists yet, keep the first one as fallback so
    -- hover handlers never index a nil activeSidebarTab.
    if isDefaultActive then
        activeSidebarTab = {Btn = btn, Icon = icon, Title = title, Stroke = stroke}
    elseif not activeSidebarTab then
        activeSidebarTab = {Btn = btn, Icon = icon, Title = title, Stroke = stroke}
    end

    btn.MouseEnter:Connect(function()
        if activeSidebarTab.Btn ~= btn then
            TweenService:Create(title, TWEEN_FAST, {TextColor3 = THEME.TextPrimary}):Play()
            TweenService:Create(icon, TWEEN_FAST, {ImageColor3 = THEME.TextPrimary}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if activeSidebarTab.Btn ~= btn then
            TweenService:Create(title, TWEEN_FAST, {TextColor3 = THEME.TextMuted}):Play()
            TweenService:Create(icon, TWEEN_FAST, {ImageColor3 = THEME.TextMuted}):Play()
        end
    end)

    -- Shared select logic, reused by the click handler AND cross-tab search.
    local function selectThisTab()
        if activeSidebarTab.Btn == btn then return end

        TweenService:Create(activeSidebarTab.Btn, TWEEN_FAST, {BackgroundTransparency = 1}):Play()
        TweenService:Create(activeSidebarTab.Stroke, TWEEN_FAST, {Transparency = 1}):Play()
        TweenService:Create(activeSidebarTab.Icon, TWEEN_FAST, {ImageColor3 = THEME.TextMuted}):Play()
        TweenService:Create(activeSidebarTab.Title, TWEEN_FAST, {TextColor3 = THEME.TextMuted}):Play()

        TweenService:Create(btn, TWEEN_FAST, {BackgroundTransparency = 0, BackgroundColor3 = THEME.SidebarActive}):Play()
        TweenService:Create(stroke, TWEEN_FAST, {Transparency = 0, Color = THEME.BorderActive}):Play()
        TweenService:Create(icon, TWEEN_FAST, {ImageColor3 = THEME.Accent}):Play()
        TweenService:Create(title, TWEEN_FAST, {TextColor3 = THEME.TextPrimary}):Play()

        activeSidebarTab = {Btn = btn, Icon = icon, Title = title, Stroke = stroke}

        local entry = tabPages[name]
        if entry then
            if activePage then
                activePage.Page.Visible = false
            end
            entry.Page.Visible = true
            activePage = entry
        end
    end

    btn.MouseButton1Click:Connect(selectThisTab)
    sidebarSelectors[name] = selectThisTab
end

function Widgets.createCard(parent, titleText, order)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = THEME.CardBg
    card.BorderSizePixel = 0
    card.LayoutOrder = order
    card.Parent = parent

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = card

    local s = Instance.new("UIStroke")
    s.Color = THEME.Border
    s.Thickness = 0.8
    s.Parent = card

    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, 11)
    p.PaddingBottom = UDim.new(0, 13)
    p.PaddingLeft = UDim.new(0, 12)
    p.PaddingRight = UDim.new(0, 12)
    p.Parent = card

    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 10)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = card

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 18)
    header.BackgroundTransparency = 1
    header.LayoutOrder = 0
    header.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = titleText
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextColor3 = THEME.TextPrimary
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0, 12, 0, 12)
    icon.Position = UDim2.new(1, -12, 0.5, -6)
    icon.BackgroundTransparency = 1
    icon.Image = ICONS.Chevron
    icon.ImageColor3 = THEME.Accent
    icon.Parent = header

    return card
end

-- Keybind modal + row dropdown ---------------------------------------------
local function openKeybindModal(targetBadge, featureName)
    if KeybindListening then KeybindListening:Disconnect() end

    targetBadge.Text = "..."
    targetBadge.TextColor3 = THEME.Accent

    KeybindListening = track(UserInputService.InputBegan:Connect(function(input, _processed)
        -- NOTE: processed deliberately ignored so keys the game uses (QWERTY,
        -- movement, abilities) can still be bound — otherwise only F-keys would
        -- work. Mouse buttons are bindable too and show as MouseButton1/2/3.
        if input.UserInputType == Enum.UserInputType.Keyboard then
            local keyName = input.KeyCode.Name
            if keyName == "Escape" then
                targetBadge.Text = "-"
            else
                targetBadge.Text = keyName
            end
            targetBadge.TextColor3 = THEME.TextMuted
            KeybindListening:Disconnect()
            KeybindListening = nil
        elseif input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.MouseButton2
            or input.UserInputType == Enum.UserInputType.MouseButton3 then
            targetBadge.Text = input.UserInputType.Name
            targetBadge.TextColor3 = THEME.TextMuted
            KeybindListening:Disconnect()
            KeybindListening = nil
        end
    end))
end

local function toggleDropdown(parentRow, badgeLabel, featureName)
    if ActiveDropdown then
        ActiveDropdown:Destroy()
        ActiveDropdown = nil
        return
    end

    local drop = Instance.new("Frame")
    drop.Name = "Dropdown"
    drop.Size = UDim2.new(0, 115, 0, 58)
    drop.Position = UDim2.new(1, -120, 1, 3)
    drop.BackgroundColor3 = Color3.fromRGB(24, 18, 20)
    drop.ZIndex = 30
    drop.Parent = parentRow

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = drop

    local s = Instance.new("UIStroke")
    s.Color = THEME.Border
    s.Thickness = 1
    s.Parent = drop

    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 1)
    list.Parent = drop

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 3)
    pad.PaddingBottom = UDim.new(0, 3)
    pad.PaddingLeft = UDim.new(0, 5)
    pad.PaddingRight = UDim.new(0, 5)
    pad.Parent = drop

    local function addOption(name, onClick)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 24)
        btn.BackgroundTransparency = 1
        btn.Text = " " .. name
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 10.5
        btn.TextColor3 = THEME.TextPrimary
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.ZIndex = 31
        btn.Parent = drop

        btn.MouseEnter:Connect(function() btn.TextColor3 = THEME.Accent end)
        btn.MouseLeave:Connect(function() btn.TextColor3 = THEME.TextPrimary end)
        btn.MouseButton1Click:Connect(function()
            drop:Destroy()
            ActiveDropdown = nil
            if onClick then onClick() end
        end)
    end

    addOption("Bind Key", function()
        openKeybindModal(badgeLabel, featureName)
    end)
    addOption("Reset Value", function()
        badgeLabel.Text = "-"
    end)

    ActiveDropdown = drop
end

function Widgets.addToggle(card, name, description, defaultState, keybindDefault, callback)
    local row = Instance.new("Frame")
    row.Name = name
    row.Size = UDim2.new(1, 0, 0, description and 30 or 21)
    row.BackgroundTransparency = 1
    row.Parent = card

    -- Resolve which tab this row lives under (for cross-tab search).
    local ownerTab = nil
    for tabName, entry in pairs(tabPages) do
        if row:IsDescendantOf(entry.Page) then
            ownerTab = tabName
            break
        end
    end

    table.insert(registeredRows, {Frame = row, Name = name:lower(), Tab = ownerTab, Card = card})

    local textContainer = Instance.new("Frame")
    textContainer.Size = UDim2.new(1, -80, 1, 0)
    textContainer.BackgroundTransparency = 1
    textContainer.Parent = row

    local rowTitle = Instance.new("TextLabel")
    rowTitle.Size = UDim2.new(1, 0, 0, 14)
    rowTitle.BackgroundTransparency = 1
    rowTitle.Text = name
    rowTitle.Font = Enum.Font.GothamMedium
    rowTitle.TextSize = 11
    rowTitle.TextColor3 = THEME.TextPrimary
    rowTitle.TextXAlignment = Enum.TextXAlignment.Left
    rowTitle.Parent = textContainer

    if description then
        local rowDesc = Instance.new("TextLabel")
        rowDesc.Size = UDim2.new(1, 0, 0, 12)
        rowDesc.Position = UDim2.new(0, 0, 0, 14)
        rowDesc.BackgroundTransparency = 1
        rowDesc.Text = description
        rowDesc.Font = Enum.Font.Gotham
        rowDesc.TextSize = 9
        rowDesc.TextColor3 = THEME.TextMuted
        rowDesc.TextXAlignment = Enum.TextXAlignment.Left
        rowDesc.Parent = textContainer
    end

    -- Keybind badge (accepts a string key name OR a UserInputType for mouse)
    local keyLabel = nil
    if keybindDefault ~= nil then
        keyLabel = typeof(keybindDefault) == "EnumItem"
            and keybindDefault.Name
            or tostring(keybindDefault)
    end

    local badge = Instance.new("TextLabel")
    badge.Size = UDim2.new(0, 18, 0, 14)
    badge.Position = UDim2.new(1, -76, 0.5, -7)
    badge.BackgroundColor3 = THEME.BadgeBg
    badge.Text = keyLabel or ""
    badge.Visible = (keybindDefault ~= nil)
    badge.Font = Enum.Font.GothamBold
    badge.TextSize = 8.5
    badge.TextColor3 = THEME.TextMuted
    badge.Parent = row

    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 3)
    bc.Parent = badge

    local bs = Instance.new("UIStroke")
    bs.Color = THEME.Border
    bs.Thickness = 0.8
    bs.Parent = badge

    local optBtn = Instance.new("ImageButton")
    optBtn.Size = UDim2.new(0, 13, 0, 13)
    optBtn.Position = UDim2.new(1, -52, 0.5, -6.5)
    optBtn.BackgroundTransparency = 1
    optBtn.Image = ICONS.More
    optBtn.ImageColor3 = THEME.TextDim
    optBtn.Parent = row

    optBtn.MouseEnter:Connect(function()
        TweenService:Create(optBtn, TWEEN_FAST, {ImageColor3 = THEME.TextPrimary}):Play()
    end)
    optBtn.MouseLeave:Connect(function()
        TweenService:Create(optBtn, TWEEN_FAST, {ImageColor3 = THEME.TextDim}):Play()
    end)
    optBtn.MouseButton1Click:Connect(function()
        badge.Visible = true
        toggleDropdown(row, badge, name)
    end)

    local switch = Instance.new("TextButton")
    switch.Size = UDim2.new(0, 32, 0, 16)
    switch.Position = UDim2.new(1, -32, 0.5, -8)
    switch.BackgroundColor3 = defaultState and THEME.Accent or THEME.ToggleOff
    switch.Text = ""
    switch.AutoButtonColor = false
    switch.Parent = row

    local sCorner = Instance.new("UICorner")
    sCorner.CornerRadius = UDim.new(1, 0)
    sCorner.Parent = switch

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.Position = defaultState and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
    knob.BackgroundColor3 = defaultState and THEME.KnobOn or THEME.KnobOff
    knob.BorderSizePixel = 0
    knob.Parent = switch

    local kCorner = Instance.new("UICorner")
    kCorner.CornerRadius = UDim.new(1, 0)
    kCorner.Parent = knob

    local isToggled = defaultState
    local savedKey = keyLabel or "-"

    local function setToggle(state)
        isToggled = state and true or false

        local targetColor = isToggled and THEME.Accent or THEME.ToggleOff
        local targetKnobColor = isToggled and THEME.KnobOn or THEME.KnobOff
        local targetPos = isToggled and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)

        TweenService:Create(switch, TWEEN_FAST, {BackgroundColor3 = targetColor}):Play()
        TweenService:Create(knob, TWEEN_FAST, {BackgroundColor3 = targetKnobColor, Position = targetPos}):Play()

        if callback then
            callback(isToggled)
        end
    end

    switch.MouseButton1Click:Connect(function()
        setToggle(not isToggled)
    end)

    configBindings[name:lower()] = {
        kind = "toggle",
        get = function()
            return {enabled = isToggled, key = savedKey}
        end,
        set = function(value)
            local enabled = type(value) == "table" and value.enabled or value
            local key = type(value) == "table" and value.key or savedKey
            if key and key ~= "-" then
                savedKey = key
                badge.Text = key
                badge.Visible = true
            end
            setToggle(enabled)
        end,
    }
end

-- Generic options menu (used by dropdowns; reuse ActiveDropdown slot)
local function openOptionsMenu(parentRow, badgeLabel, options, currentIndex, onSelect)
    if ActiveDropdown then
        ActiveDropdown:Destroy()
        ActiveDropdown = nil
    end

    local maxShow = 6
    local drop = Instance.new("Frame")
    drop.Name = "Dropdown"
    drop.Size = UDim2.new(0, 115, 0, math.min(#options, maxShow) * 24 + 8)
    drop.Position = UDim2.new(1, -120, 1, 3)
    drop.BackgroundColor3 = Color3.fromRGB(24, 18, 20)
    drop.ZIndex = 30
    drop.Parent = parentRow

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = drop

    local s = Instance.new("UIStroke")
    s.Color = THEME.Border
    s.Thickness = 1
    s.Parent = drop

    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 1)
    list.Parent = drop

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 3)
    pad.PaddingBottom = UDim.new(0, 3)
    pad.PaddingLeft = UDim.new(0, 5)
    pad.PaddingRight = UDim.new(0, 5)
    pad.Parent = drop

    for i, opt in ipairs(options) do
        local isCurrent = (i == currentIndex)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 24)
        btn.BackgroundTransparency = 1
        btn.Text = " " .. opt
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 10.5
        btn.TextColor3 = isCurrent and THEME.Accent or THEME.TextPrimary
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.ZIndex = 31
        btn.Parent = drop

        btn.MouseEnter:Connect(function() btn.TextColor3 = THEME.Accent end)
        btn.MouseLeave:Connect(function()
            btn.TextColor3 = isCurrent and THEME.Accent or THEME.TextPrimary
        end)
        btn.MouseButton1Click:Connect(function()
            drop:Destroy()
            ActiveDropdown = nil
            if onSelect then
                onSelect(opt, i)
            end
        end)
    end

    ActiveDropdown = drop
end

function Widgets.addDropdown(card, name, description, options, defaultIndex, callback)
    options = options or {}
    defaultIndex = defaultIndex or 1

    local row = Instance.new("Frame")
    row.Name = name
    row.Size = UDim2.new(1, 0, 0, description and 30 or 21)
    row.BackgroundTransparency = 1
    row.Parent = card

    local ownerTab = nil
    for tabName, entry in pairs(tabPages) do
        if row:IsDescendantOf(entry.Page) then
            ownerTab = tabName
            break
        end
    end

    table.insert(registeredRows, {Frame = row, Name = name:lower(), Tab = ownerTab, Card = card})

    local textContainer = Instance.new("Frame")
    textContainer.Size = UDim2.new(1, -80, 1, 0)
    textContainer.BackgroundTransparency = 1
    textContainer.Parent = row

    local rowTitle = Instance.new("TextLabel")
    rowTitle.Size = UDim2.new(1, 0, 0, 14)
    rowTitle.BackgroundTransparency = 1
    rowTitle.Text = name
    rowTitle.Font = Enum.Font.GothamMedium
    rowTitle.TextSize = 11
    rowTitle.TextColor3 = THEME.TextPrimary
    rowTitle.TextXAlignment = Enum.TextXAlignment.Left
    rowTitle.Parent = textContainer

    if description then
        local rowDesc = Instance.new("TextLabel")
        rowDesc.Size = UDim2.new(1, 0, 0, 12)
        rowDesc.Position = UDim2.new(0, 0, 0, 14)
        rowDesc.BackgroundTransparency = 1
        rowDesc.Text = description
        rowDesc.Font = Enum.Font.Gotham
        rowDesc.TextSize = 9
        rowDesc.TextColor3 = THEME.TextMuted
        rowDesc.TextXAlignment = Enum.TextXAlignment.Left
        rowDesc.Parent = textContainer
    end

    local selectedIndex = defaultIndex

    local badge = Instance.new("TextButton")
    badge.Size = UDim2.new(0, 48, 0, 14)
    badge.Position = UDim2.new(1, -54, 0.5, -7)
    badge.BackgroundColor3 = THEME.BadgeBg
    badge.Text = options[selectedIndex] or "-"
    badge.Font = Enum.Font.GothamBold
    badge.TextSize = 8.5
    badge.TextColor3 = THEME.TextMuted
    badge.AutoButtonColor = false
    badge.Parent = row

    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 3)
    bc.Parent = badge

    local bs = Instance.new("UIStroke")
    bs.Color = THEME.Border
    bs.Thickness = 0.8
    bs.Parent = badge

    local chevron = Instance.new("ImageLabel")
    chevron.Size = UDim2.new(0, 8, 0, 8)
    chevron.Position = UDim2.new(1, -19, 0.5, -4)
    chevron.BackgroundTransparency = 1
    chevron.Image = ICONS.Chevron
    chevron.ImageColor3 = THEME.TextDim
    chevron.Parent = badge

    local function selectOption(opt, index)
        selectedIndex = index
        badge.Text = opt
        if callback then
            callback(opt, index)
        end
    end

    badge.MouseButton1Click:Connect(function()
        openOptionsMenu(row, badge, options, selectedIndex, selectOption)
    end)

    configBindings[name:lower()] = {
        kind = "dropdown",
        get = function()
            return options[selectedIndex] or ""
        end,
        set = function(value)
            for i, opt in ipairs(options) do
                if tostring(opt) == tostring(value) then
                    selectOption(opt, i)
                    return
                end
            end
            selectOption(options[defaultIndex] or "", defaultIndex)
        end,
    }
end

function Widgets.addSlider(card, name, description, min, max, default, callback, suffix)
    min = min or 0
    max = max or 100
    suffix = suffix or ""
    default = math.clamp(default or min, min, max)
    local value = default

    local row = Instance.new("Frame")
    row.Name = name
    row.Size = UDim2.new(1, 0, 0, description and 44 or 34)
    row.BackgroundTransparency = 1
    row.Parent = card

    local ownerTab = nil
    for tabName, entry in pairs(tabPages) do
        if row:IsDescendantOf(entry.Page) then
            ownerTab = tabName
            break
        end
    end

    table.insert(registeredRows, {Frame = row, Name = name:lower(), Tab = ownerTab, Card = card})

    local textContainer = Instance.new("Frame")
    textContainer.Size = UDim2.new(1, -120, 1, 0)
    textContainer.BackgroundTransparency = 1
    textContainer.Parent = row

    local rowTitle = Instance.new("TextLabel")
    rowTitle.Size = UDim2.new(1, 0, 0, 14)
    rowTitle.BackgroundTransparency = 1
    rowTitle.Text = name
    rowTitle.Font = Enum.Font.GothamMedium
    rowTitle.TextSize = 11
    rowTitle.TextColor3 = THEME.TextPrimary
    rowTitle.TextXAlignment = Enum.TextXAlignment.Left
    rowTitle.Parent = textContainer

    if description then
        local rowDesc = Instance.new("TextLabel")
        rowDesc.Size = UDim2.new(1, 0, 0, 12)
        rowDesc.Position = UDim2.new(0, 0, 0, 14)
        rowDesc.BackgroundTransparency = 1
        rowDesc.Text = description
        rowDesc.Font = Enum.Font.Gotham
        rowDesc.TextSize = 9
        rowDesc.TextColor3 = THEME.TextMuted
        rowDesc.TextXAlignment = Enum.TextXAlignment.Left
        rowDesc.Parent = textContainer
    end

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0, 46, 0, 14)
    valueLabel.Position = UDim2.new(1, -46, 0, description and 0 or 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(value) .. suffix
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 10
    valueLabel.TextColor3 = THEME.TextPrimary
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -14, 0, 5)
    track.Position = UDim2.new(0, 4, 0, description and 30 or 22)
    track.BackgroundColor3 = THEME.ToggleOff
    track.BorderSizePixel = 0
    track.Parent = row

    local tCorner = Instance.new("UICorner")
    tCorner.CornerRadius = UDim.new(1, 0)
    tCorner.Parent = track

    local fill = Instance.new("Frame")
    fill.BorderSizePixel = 0
    fill.BackgroundColor3 = THEME.Accent
    fill.Parent = track

    local fCorner = Instance.new("UICorner")
    fCorner.CornerRadius = UDim.new(1, 0)
    fCorner.Parent = fill

    local knob = Instance.new("TextButton")
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.BackgroundColor3 = THEME.KnobOn
    knob.Text = ""
    knob.BorderSizePixel = 0
    knob.AutoButtonColor = false
    knob.Parent = track

    local kCorner = Instance.new("UICorner")
    kCorner.CornerRadius = UDim.new(1, 0)
    kCorner.Parent = knob

    local function applyValue(v, fromUser)
        value = math.clamp(v, min, max)
        if (max - min) > 100 then
            value = math.floor(value + 0.5)
        end

        local frac = (value - min) / (max - min)
        fill.Size = UDim2.new(frac, 0, 1, 0)
        knob.Position = UDim2.new(frac, -6, 0.5, -6)
        valueLabel.Text = tostring(value) .. suffix

        if fromUser and callback then
            callback(value)
        end
    end

    applyValue(default, false)

    do
        local dragging = false
        knob.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
            end
        end)
        track(UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local trackPos = track.AbsolutePosition
                local trackWidth = track.AbsoluteSize.X
                local frac = (input.Position.X - trackPos.X) / math.max(trackWidth, 1)
                applyValue(min + math.clamp(frac, 0, 1) * (max - min), true)
            end
        end))
        track(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end))
    end

    configBindings[name:lower()] = {
        kind = "slider",
        get = function()
            return value
        end,
        set = function(v)
            if type(v) == "number" then
                applyValue(v, true)
            end
        end,
    }
end

function Widgets.addActionButton(card, label, description, onClick)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, description and 40 or 30)
    row.BackgroundTransparency = 1
    row.Parent = card

    if description then
        local desc = Instance.new("TextLabel")
        desc.Size = UDim2.new(1, 0, 0, 12)
        desc.BackgroundTransparency = 1
        desc.Text = description
        desc.Font = Enum.Font.Gotham
        desc.TextSize = 9
        desc.TextColor3 = THEME.TextMuted
        desc.TextXAlignment = Enum.TextXAlignment.Left
        desc.Parent = row
    end

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 26)
    btn.Position = UDim2.new(0, 0, 0, description and 14 or 0)
    btn.BackgroundColor3 = THEME.Accent
    btn.Text = label
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.AutoButtonColor = false
    btn.Parent = row

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = btn

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TWEEN_FAST, {BackgroundColor3 = THEME.AccentSoft}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TWEEN_FAST, {BackgroundColor3 = THEME.Accent}):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        if onClick then onClick() end
    end)

    return row
end

-- =============================================================================
-- Public fluent builders
-- =============================================================================

local Hud = {}
Hud.__index = Hud

local HudRow = {}
HudRow.__index = HudRow

local HudPill = {}
HudPill.__index = HudPill

local Info = {}
Info.__index = Info

local Sidebar = {}
Sidebar.__index = Sidebar

local Tab = {}
Tab.__index = Tab

local Card = {}
Card.__index = Card

-- HUD -------------------------------------------------------------------
function Nova:hud()
    return setmetatable({}, Hud)
end

function Hud:row(name, height, order)
    local frame = Widgets.createHudRow(name, height, order)
    return setmetatable({Frame = frame, Name = name}, HudRow)
end

function HudRow:pill(order)
    return setmetatable({Frame = Widgets.createHudPill(self.Frame, order)}, HudPill)
end

function HudPill:divider(order)
    Widgets.addHudDivider(self.Frame, order)
    return self
end

function HudPill:icon(iconId, order)
    Widgets.addHudSmallIcon(self.Frame, iconId, order)
    return self
end

-- leaf helper: returns the created TextLabel (keep for live updates)
function HudPill:text(label, muted, order)
    return Widgets.addHudText(self.Frame, label, muted, order)
end

-- HUD row visibility (persisted to disk) --------------------------------
function Nova:hudRowEnabled(name)
    return HudLayout[name] and HudLayout[name].Enabled or true
end

function Nova:setHudRowEnabled(name, enabled)
    if not HudLayout[name] then return end
    HudLayout[name].Enabled = enabled
    if HudLayout[name].Frame then
        HudLayout[name].Frame.Visible = enabled
    end
    saveHudLayout()
end

-- Top-right info stack ---------------------------------------------------
function Nova:info()
    return setmetatable({Order = 0}, Info)
end

-- leaf helper: returns the created TextLabel (e.g. GameLine for updates)
function Info:line(text, isPrimary)
    self.Order = self.Order + 1
    return Widgets.addInfoLine(text, self.Order, isPrimary)
end

-- Sidebar ----------------------------------------------------------------
function Nova:sidebar()
    return setmetatable({Order = 0}, Sidebar)
end

function Sidebar:category(name)
    self.Order = self.Order + 1
    Widgets.addCategory(name, self.Order)
    return self
end

function Sidebar:tab(name, iconId, defaultActive)
    self.Order = self.Order + 1
    Widgets.addSidebarItem(name, iconId, defaultActive, self.Order)
    return self
end

-- Content tabs / cards ----------------------------------------------------
function Nova:create(name)
    local col1, col2 = Widgets.createTabPage(name)
    return setmetatable({
        TabName = name,
        Cols = {
            {Frame = col1, Count = 0},
            {Frame = col2, Count = 0},
        },
    }, Tab)
end

-- each card lands in whichever column currently has fewer cards
function Tab:card(label, value)
    local a, b = self.Cols[1], self.Cols[2]
    local col = a.Count <= b.Count and a or b
    col.Count = col.Count + 1
    return setmetatable({Frame = Widgets.createCard(col.Frame, label, col.Count)}, Card)
end

function Card:toggle(name, description, defaultState, keybindDefault, callback)
    Widgets.addToggle(self.Frame, name, description, defaultState, keybindDefault, callback)
    return self
end

function Card:action(label, description, onClick)
    Widgets.addActionButton(self.Frame, label, description, onClick)
    return self
end

function Card:dropdown(name, description, options, defaultIndex, callback)
    Widgets.addDropdown(self.Frame, name, description, options, defaultIndex, callback)
    return self
end

function Card:slider(name, description, min, max, default, callback, suffix)
    Widgets.addSlider(self.Frame, name, description, min, max, default, callback, suffix)
    return self
end

-- Public helpers ------------------------------------------------------------
function Nova:select(tabName)
    local selector = sidebarSelectors[tabName]
    if selector then
        selector()
        return
    end
    -- Fallback: show the page directly even if it has no sidebar button.
    local entry = tabPages[tabName]
    if entry then
        if activePage then
            activePage.Page.Visible = false
        end
        entry.Page.Visible = true
        activePage = entry
    end
end

function Nova:setTheme(patch)
    for k, v in pairs(patch or {}) do
        Nova.Theme[k] = v
    end
end

-- Config system (create/load/save/delete/import/export) --------------------
local function readConfigStore()
    local ok, data = pcall(function()
        if isfile and isfile(Nova.Config.ConfigFile) then
            return HttpService:JSONDecode(readfile(Nova.Config.ConfigFile))
        end
        return nil
    end)
    return (ok and type(data) == "table") and data or {}
end

local function writeConfigStore(store)
    pcall(function()
        if writefile then
            writefile(Nova.Config.ConfigFile, HttpService:JSONEncode(store))
        end
    end)
end

local function captureWidgetValues()
    local values = {}
    for key, binding in pairs(configBindings) do
        values[key] = binding.get()
    end
    return values
end

local function applyConfigValues(values)
    for key, value in pairs(values or {}) do
        local binding = configBindings[key]
        if binding then
            pcall(binding.set, value)
        end
    end
end

local ConfigHandle = {}
ConfigHandle.__index = ConfigHandle

function Nova:createConfig(name)
    return setmetatable({Name = name}, ConfigHandle)
end

function Nova:configNames()
    local names = {}
    for name in pairs(readConfigStore()) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

function ConfigHandle:save()
    local store = readConfigStore()
    store[self.Name] = captureWidgetValues()
    writeConfigStore(store)
    return self
end

function ConfigHandle:load()
    local values = readConfigStore()[self.Name]
    if values then
        applyConfigValues(values)
    end
    return self
end

function ConfigHandle:delete()
    local store = readConfigStore()
    store[self.Name] = nil
    writeConfigStore(store)
    return self
end

function ConfigHandle:export()
    local values = readConfigStore()[self.Name] or captureWidgetValues()
    return HttpService:JSONEncode(values)
end

function ConfigHandle:import(json)
    local ok, values = pcall(function()
        return HttpService:JSONDecode(json)
    end)
    if not ok or type(values) ~= "table" then
        error("NovaConfig: import failed, invalid JSON")
    end
    local store = readConfigStore()
    store[self.Name] = values
    writeConfigStore(store)
    applyConfigValues(values)
    return self
end

-- Register an external connection so Nova:unload() tears it down too.
function Nova:track(connection)
    return track(connection)
end

function Nova:unload()
    for _, connection in ipairs(trackedConnections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    trackedConnections = {}

    if ActiveDropdown then
        ActiveDropdown:Destroy()
        ActiveDropdown = nil
    end

    if ScreenGui then
        ScreenGui:Destroy()
        ScreenGui = nil
    end
end

if getgenv then
    getgenv().NovaUI = Nova
end

--[[
============================================================================
 EXAMPLE / DEMO
 Set RUN_EXAMPLE = false to ship the library without this demo menu.
 ============================================================================
--]]

local RUN_EXAMPLE = true

if RUN_EXAMPLE and getgenv then
    -- Ottawa your window + HUD exactly like the classic build:
    --   HUD rows (persisted + draggable), window chrome, sidebar, tabs.

    local Demo = {}
    local NovaUI = Nova

    ---------------------------------------------------------------
    -- 1. HUD WATERMARK (top-left, persistent under the UI toggle)
    ---------------------------------------------------------------
    local hud = NovaUI:hud()

    local topHud    = hud:row("TopRow", 22, 1)
    local bottomHud = hud:row("BottomRow", 22, 2)
    local TopHudRow = topHud.Frame
    local BottomHudRow = bottomHud.Frame

    -- Brand pill (logo + name)
    local brand = topHud:pill(1)
    local HudLogoWrap = Instance.new("Frame")
    HudLogoWrap.Size = UDim2.new(0, 20, 0, 20)
    HudLogoWrap.BackgroundTransparency = 1
    HudLogoWrap.LayoutOrder = 1
    HudLogoWrap.Parent = brand.Frame

    local HudLogoGlow = Instance.new("ImageLabel")
    HudLogoGlow.Size = UDim2.new(2, 0, 2, 0)
    HudLogoGlow.Position = UDim2.new(-0.5, 0, -0.5, 0)
    HudLogoGlow.BackgroundTransparency = 1
    HudLogoGlow.Image = "rbxassetid://5028857084"
    HudLogoGlow.ImageColor3 = NovaUI.Theme.Accent
    HudLogoGlow.ImageTransparency = 0.65
    HudLogoGlow.ZIndex = 1
    HudLogoGlow.Parent = HudLogoWrap

    local HudBrandLogo = Instance.new("ImageLabel")
    HudBrandLogo.Size = UDim2.new(1.35, 0, 1.35, 0)
    HudBrandLogo.Position = UDim2.new(-0.175, 0, -0.175, 0)
    HudBrandLogo.BackgroundTransparency = 1
    HudBrandLogo.Image = NovaUI.Config.LogoId
    HudBrandLogo.ScaleType = Enum.ScaleType.Fit
    HudBrandLogo.ImageColor3 = Color3.fromRGB(255, 255, 255)
    HudBrandLogo.ZIndex = 2
    HudBrandLogo.Parent = HudLogoWrap

    local HudLogoGrad = Instance.new("UIGradient")
    HudLogoGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.0, NovaUI.Theme.AccentSoft),
        ColorSequenceKeypoint.new(0.45, NovaUI.Theme.Accent),
        ColorSequenceKeypoint.new(1.0, Color3.fromRGB(165, 32, 42))
    })
    HudLogoGrad.Rotation = -35
    HudLogoGrad.Parent = HudBrandLogo

    brand:divider(2)
    local HudBrandText = brand:text("pasta", false, 3)

    local HudBrandGrad = Instance.new("UIGradient")
    HudBrandGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.0, NovaUI.Theme.AccentSoft),
        ColorSequenceKeypoint.new(1.0, NovaUI.Theme.Accent)
    })
    HudBrandGrad.Parent = HudBrandText

    -- Stats pill: username / fps / time
    local stats = topHud:pill(2)
    stats:icon(NovaUI.Icons.User, 1)
    stats:text(string.lower(LocalPlayer.Name), false, 2)
    stats:divider(3)

    stats:icon(NovaUI.Icons.Chart, 4)
    local FpsLabel = stats:text("0 Fps", false, 5)
    stats:divider(6)

    stats:icon(NovaUI.Icons.Clock, 7)
    local TimeLabel = stats:text("00:00:00", false, 8)

    -- Position / ping / ticks / speed pills
    local pos = bottomHud:pill(1)
    pos:icon(NovaUI.Icons.Compass, 1)
    pos:divider(2)
    local PosLabel = pos:text("0, 0, 0", false, 3)

    local ping = bottomHud:pill(2)
    ping:icon(NovaUI.Icons.Signal, 1)
    ping:divider(2)
    local PingLabel = ping:text("0 Ping", false, 3)

    local tick = bottomHud:pill(3)
    tick:icon(NovaUI.Icons.Radar, 1)
    tick:divider(2)
    local TickLabel = tick:text("20.0 Ticks", false, 3)

    local speed = bottomHud:pill(4)
    speed:icon(NovaUI.Icons.Speed, 1)
    speed:divider(2)
    local SpeedLabel = speed:text("0.0 Bps", false, 3)

    -- Live runtime updates (example of driving labels yourself)
    local fpsCounter, lastFpsCheck = 0, os.clock()
    local lastPosition = Vector3.zero
    local lastPosTime = os.clock()

    NovaUI:track(RunService.RenderStepped:Connect(function()
        fpsCounter = fpsCounter + 1
        local now = os.clock()

        if now - lastFpsCheck >= 1 then
            FpsLabel.Text = string.format("%d Fps", fpsCounter)
            fpsCounter = 0
            lastFpsCheck = now
        end

        TimeLabel.Text = os.date("%H:%M:%S")

        local pingStat = Stats.Network.ServerStatsItem:FindFirstChild("Data Ping")
        if pingStat then
            local ok, value = pcall(function() return pingStat:GetValue() end)
            if ok then
                PingLabel.Text = string.format("%d Ping", math.floor(value))
            end
        end

        local character = LocalPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local hrp = character.HumanoidRootPart
            local currentPos = hrp.Position
            PosLabel.Text = string.format("%d, %d, %d", math.floor(currentPos.X), math.floor(currentPos.Y), math.floor(currentPos.Z))

            local deltaTime = now - lastPosTime
            if deltaTime >= 0.1 then
                local dist = (Vector3.new(currentPos.X, 0, currentPos.Z) - Vector3.new(lastPosition.X, 0, lastPosition.Z)).Magnitude
                local bps = dist / deltaTime
                SpeedLabel.Text = string.format("%.1f Bps", bps)

                lastPosition = currentPos
                lastPosTime = now
            end
        else
            PosLabel.Text = "0, 0, 0"
            SpeedLabel.Text = "0.0 Bps"
        end
    end))

    ---------------------------------------------------------------
    -- 2. MAIN WINDOW
    ---------------------------------------------------------------
    NovaUI.createWindow()

    -- Top-right info stack: game name / username / version
    local topInfo = NovaUI:info()
    local GameLine = topInfo:line("Loading game...", true)
    local UserLine = topInfo:line(string.lower(LocalPlayer.Name), false)
    local VersionLine = topInfo:line(NovaUI.Config.Version, false)

    task.spawn(function()
        local ok, info = pcall(function()
            return MarketplaceService:GetProductInfo(game.PlaceId)
        end)
        if ok and info and info.Name then
            GameLine.Text = info.Name
        else
            GameLine.Text = "Unknown Game"
        end
    end)

    -- Sidebar: categories + tab buttons
    local sb = NovaUI:sidebar()
    sb:category("Aimbot")
    sb:tab("Legit", NovaUI.Icons.Combat, true)
    sb:tab("Rage", NovaUI.Icons.Chevron, false)
    sb:tab("Visuals", NovaUI.Icons.Visuals, false)
    sb:tab("Player", NovaUI.Icons.Player, false)
    sb:tab("Misc", NovaUI.Icons.Misc, false)
    sb:category("Manager")
    sb:tab("Presets", NovaUI.Icons.Presets, false)
    sb:tab("Auto Buy", NovaUI.Icons.AutoBuy, false)
    sb:tab("Accounts", NovaUI.Icons.Accounts, false)

    -- Content: Rage tab
    local rage = NovaUI:create("Rage")
    rage:card("Fighting")
        :toggle("Attack Aura")
        :toggle("No Velocity")
        :toggle("Trigger Bot")
        :toggle("Aim Assist", nil, false, "F1")
        :toggle("Auto Explosion")
    rage:card("Base")
        :toggle("Auto Swap", nil, true)
        :toggle("Item Release")
    rage:card("Tools")
        :toggle("Sprint Reset")
        :toggle("Tape Mouse")
        :toggle("Aim Assist", "Helps to Focus on Entities")
        :toggle("Web Trap")
    rage:card("Other")
        :toggle("No Slot Change")
        :toggle("Anti Bot")
        :toggle("No Friend Damage", nil, true)
    rage:card("Options")
        :dropdown("Target Part", "Which part aimbot targets", {"Head", "Torso", "Root"}, 1, function(opt)
            print("Target part ->", opt)
        end)
        :dropdown("Aimbot Mode", nil, {"Silent", "Visible", "Off", "Assist"}, 1, function(opt)
            print("Aimbot mode ->", opt)
        end)
        :slider("Speed", "Aimbot smoothing speed", 1, 100, 50, function(v)
            print("Speed ->", v)
        end)

    -- Legit tab (empty: show how a blank page looks)
    NovaUI:create("Legit")

    -- Placeholder tabs
    for _, tabName in ipairs({"Visuals", "Player", "Presets", "Auto Buy", "Accounts"}) do
        NovaUI:create(tabName):card(tabName):toggle("Coming Soon")
    end

    -- Misc: HUD visibility toggles (persisted via the library)
    local misc = NovaUI:create("Misc")
    misc:card("HUD")
        :toggle("Top Row", "Brand, username, FPS, time", NovaUI:hudRowEnabled("TopRow"), nil, function(isOn)
            NovaUI:setHudRowEnabled("TopRow", isOn)
        end)
        :toggle("Bottom Row", "Position, ping, ticks, speed", NovaUI:hudRowEnabled("BottomRow"), nil, function(isOn)
            NovaUI:setHudRowEnabled("BottomRow", isOn)
        end)
    misc:card("Config")
        :action("Save Config", "Pushes every widget value to NovaConfigs.json", function()
            NovaUI:createConfig("Main"):save()
            print("Config saved:", NovaUI:configNames()[1])
        end)
        :action("Load Config", "Applies the saved 'Main' config back to the UI", function()
            NovaUI:createConfig("Main"):load()
            print("Config loaded")
        end)
        :action("Export Config", "Prints the current config as a JSON string", function()
            print(NovaUI:createConfig("Main"):export())
        end)
        :action("Import Config", "Applies a hard-coded JSON string", function()
            NovaUI:createConfig("Main"):import(
                '{"target part":"Torso","speed":75,"attack aura":true}'
            )
            print("Config imported")
        end)
        :action("Delete Config", "Removes 'Main' from the config file", function()
            NovaUI:createConfig("Main"):delete()
            print("Config deleted")
        end)
    misc:card("Danger Zone")
        :action("Unload Script", "Fully removes the UI and stops all running loops", function()
            NovaUI:unload()
        end)

    -- Open the sidebar's default-active tab (Legit).
    NovaUI:select("Legit")
end

return Nova
