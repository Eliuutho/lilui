-- ═══════════════════════════════════════════════════════════════
-- LIL UI — Librería UI custom. Glass-morphism, gradient animado.
--
-- USO:
-- local UI = loadstring(game:HttpGet("https://keys.elxy.dev/lilui.lua"))()
-- local Window = UI:CreateWindow({ Title = "My Script", Author = "me" })
-- local Tab = Window:Tab({ Title = "Main" })
-- Tab:Section({ Title = "Section" })
-- Tab:Paragraph({ Title = "Info", Desc = "..." })
-- Tab:Button({ Title = "Click", Callback = function() end })
-- Tab:Toggle({ Title = "Switch", Value = false, Callback = function(v) end })
-- Tab:Slider({ Title = "Vol", Value = {Min=0, Max=100, Default=50}, Callback = function(v) end })
-- Tab:Colorpicker({ Title = "Color", Default = Color3.new(1,1,1), Callback = function(c) end })
-- Tab:Dropdown({ Title = "Pick", Values = {"a","b"}, Value = "a", Callback = function(v) end })
-- Tab:Keybind({ Title = "Bind", Value = "P", Callback = function(k) end })
-- UI:Notify({ Title = "Hello", Content = "World", Duration = 3 })
-- ═══════════════════════════════════════════════════════════════

return (function()

local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local RS = game:GetService("RunService")

-- Host GUI con fallback chain
local hostGui
do
    local fns = {
        function() return gethui and gethui() end,
        function() return (get_hidden_gui and get_hidden_gui()) end,
        function() return cloneref and cloneref(game:GetService("CoreGui")) end,
        function() return game:GetService("CoreGui") end,
    }
    for _, fn in ipairs(fns) do
        local ok, res = pcall(fn)
        if ok and res then hostGui = res; break end
    end
    if not hostGui then hostGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") end
end

local function rname()
    return string.format("_%x%x", math.random(1, 0x7FFFFFFF), math.random(1, 0x7FFFFFFF))
end

local function new(cls, props)
    local i = Instance.new(cls)
    i.Name = rname()
    -- Asignación robusta: si una propiedad no aplica a esta clase (ej. AutoButtonColor
    -- en TextBox), pcall absorbe el error y seguimos construyendo el resto.
    -- Sin esto, un solo property typo aborta la creación del widget y rompe en
    -- cascada todo el script de arriba a abajo.
    if props then
        for k, v in pairs(props) do
            local ok, err = pcall(function() i[k] = v end)
            if not ok and (rawget(getfenv(), "warn") or warn) then
                warn(("[LilUI] prop %q invalida en %s: %s"):format(tostring(k), cls, tostring(err)))
            end
        end
    end
    return i
end

-- ═══════════════════════════════════════════════════════════════
-- resolveImage: convierte una URL HTTPS o un URI Roblox en algo que
-- ImageLabel.Image pueda renderizar.
--
-- Roblox bloquea URLs externas en ImageLabel.Image — solo acepta:
--   rbxassetid://, rbxthumb://, rbxasset://, rbxhttp://, ?id=N
-- Por eso para URLs HTTP(S) tenemos que bajar el PNG, guardarlo en disco
-- del executor, y resolverlo a un URI local vía getcustomasset.
--
-- Cache: el archivo se nombra por hash de la URL, así múltiples logos no
-- colisionan y bajadas siguientes hacen hit en disco.
-- ═══════════════════════════════════════════════════════════════
local function _hashStr(s)
    local h = 5381
    for i = 1, #s do h = ((h * 33) + string.byte(s, i)) % 2147483647 end
    return string.format("%x", h)
end

local _imgCache = {}  -- url → resolved URI (memo en memoria por sesión)

-- Busca una función global en _G, getgenv(), o getfenv(). Los executors la
-- exponen en distintos lugares — esto cubre todos los casos comunes (Xeno,
-- Synapse, Wave, Krnl, Fluxus, AWP).
local function _findGlobalFn(name)
    local fn
    pcall(function() fn = _G[name] end);                           if type(fn) == "function" then return fn end
    pcall(function() fn = (getgenv and getgenv() or {})[name] end); if type(fn) == "function" then return fn end
    pcall(function() fn = (getfenv() or {})[name] end);             if type(fn) == "function" then return fn end
    return nil
end

local function _findGetAsset()
    return _findGlobalFn("getcustomasset")
        or _findGlobalFn("getsynasset")
        or _findGlobalFn("get_custom_asset")
        or (syn and type(syn.cached_asset) == "function" and syn.cached_asset)
        or nil
end

-- Resolve devuelve (uri, err). err es nil en éxito, o un string corto que
-- describe el motivo del fallo cuando uri=nil. Permite que el llamador
-- decida si loggear o silenciar.
local function resolveImage(src)
    if type(src) ~= "string" or #src == 0 then return nil, "empty_src" end
    -- Pass-through: URIs nativos de Roblox ya funcionan directo
    if src:match("^rbx") or src:match("^https://www%.roblox%.com") then return src end
    -- Cache en memoria para esta sesión
    if _imgCache[src] then return _imgCache[src] end

    if src:match("^https?://") then
        if not (writefile and isfile) then return nil, "no_writefile_or_isfile" end

        local fname = "lilui_img_" .. _hashStr(src) .. ".png"
        if not isfile(fname) then
            local ok, data = pcall(function() return game:HttpGet(src) end)
            if not ok then return nil, "httpget_error:" .. tostring(data) end
            if type(data) ~= "string" then return nil, "httpget_not_string" end
            if #data < 100 then return nil, "httpget_too_small:" .. tostring(#data) end
            local okw, werr = pcall(writefile, fname, data)
            if not okw then return nil, "writefile_error:" .. tostring(werr) end
        end

        local getAsset = _findGetAsset()
        if not getAsset then return nil, "no_getcustomasset_in_executor" end

        local ok2, uri = pcall(getAsset, fname)
        if not ok2 then return nil, "getcustomasset_error:" .. tostring(uri) end
        if type(uri) ~= "string" or #uri == 0 then return nil, "getcustomasset_returned_empty" end

        _imgCache[src] = uri
        return uri
    end

    -- Fallback: asumir que es un URI ya válido (ej. un usuario que lo pasa raw)
    return src
end

local C = {
    bg = Color3.fromRGB(10, 12, 18),
    bg2 = Color3.fromRGB(20, 24, 34),
    bg3 = Color3.fromRGB(32, 38, 52),
    line = Color3.fromRGB(60, 70, 92),
    text = Color3.fromRGB(248, 250, 255),
    dim = Color3.fromRGB(180, 190, 210),
    mute = Color3.fromRGB(120, 130, 155),
    accent = Color3.fromRGB(124, 96, 255),
    cyan = Color3.fromRGB(76, 201, 240),
    pink = Color3.fromRGB(236, 72, 153),
    acc2 = Color3.fromRGB(95, 65, 220),
    ok = Color3.fromRGB(78, 215, 140),
    err = Color3.fromRGB(255, 96, 122),
    warn = Color3.fromRGB(255, 185, 80),
}

local function makeRainbowGradient(parent, rotation)
    return new("UIGradient", {
        Parent = parent,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, C.cyan),
            ColorSequenceKeypoint.new(0.5, C.accent),
            ColorSequenceKeypoint.new(1, C.pink),
        }),
        Rotation = rotation or 0,
    })
end

-- ═══ ICONS (Lucide lazy-load) ═══
local ICONS_URL = (getgenv and getgenv().LILUI_ICONS_URL)
    or "https://raw.githubusercontent.com/Eliuutho/lilui/main/icons.lua"

local iconsData = nil

local function getIcon(name)
    if not name then return nil end
    if not iconsData then
        local ok, result = pcall(function()
            return loadstring(game:HttpGet(ICONS_URL))()
        end)
        if not ok or type(result) ~= "table" then return nil end
        iconsData = result
    end
    local set = iconsData["48px"]
    if not set then return nil end
    local data = set[string.lower(name)]
    if not data then return nil end
    return {
        Image = "rbxassetid://" .. data[1],
        ImageRectSize = Vector2.new(data[2][1], data[2][2]),
        ImageRectOffset = Vector2.new(data[3][1], data[3][2]),
    }
end

local function applyIconToImageLabel(img, iconName)
    local d = getIcon(iconName)
    if not d then return false end
    img.Image = d.Image
    img.ImageRectSize = d.ImageRectSize
    img.ImageRectOffset = d.ImageRectOffset
    return true
end

local function corner(p, r) return new("UICorner", {CornerRadius = UDim.new(0, r or 8), Parent = p}) end
local function stroke(p, col, t) return new("UIStroke", {Color = col or C.line, Thickness = t or 1, Transparency = 0.3, Parent = p}) end

local function text(parent, str, opts)
    opts = opts or {}
    return new("TextLabel", {
        Parent = parent,
        BackgroundTransparency = 1,
        Text = str or "",
        Font = opts.font or Enum.Font.Gotham,
        TextSize = opts.size or 13,
        TextColor3 = opts.color or C.text,
        TextXAlignment = opts.align or Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, opts.size or 13),
    })
end

local function tween(o, t, props)
    return TS:Create(o, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
end

-- Helpers de color para Colorpicker
local function clamp(x, mn, mx) return math.max(mn, math.min(mx, x)) end

-- Convierte HSV -> Color3 (h,s,v en 0..1)
local function hsv(h, s, v)
    return Color3.fromHSV(h, s, v)
end

-- ═══ NOTIFY ═══
local notifyHost, notifyStack
local function ensureNotify()
    if notifyHost then return end
    notifyHost = new("ScreenGui", {Parent = hostGui, DisplayOrder = 999999, IgnoreGuiInset = true, ResetOnSpawn = false})
    notifyStack = new("Frame", {
        Parent = notifyHost,
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -16, 1, -16),
        Size = UDim2.new(0, 300, 0, 600),
    })
    new("UIListLayout", {Parent = notifyStack, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder})
end

local function notify(opts)
    ensureNotify()
    local toast = new("Frame", {
        Parent = notifyStack,
        BackgroundColor3 = C.bg2,
        BackgroundTransparency = 0.05,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ClipsDescendants = true,
    })
    corner(toast, 10)
    local s = new("UIStroke", {Parent = toast, Color = Color3.new(1, 1, 1), Thickness = 1, Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, LineJoinMode = Enum.LineJoinMode.Round})
    makeRainbowGradient(s, 0)
    new("UIPadding", {Parent = toast, PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14)})
    new("UIListLayout", {Parent = toast, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder})
    local t = text(toast, opts.Title or "", {font = Enum.Font.GothamBold, size = 13}); t.LayoutOrder = 1
    if opts.Content and #tostring(opts.Content) > 0 then
        local d = text(toast, tostring(opts.Content), {size = 11, color = C.dim}); d.LayoutOrder = 2
    end
    toast.BackgroundTransparency = 1
    tween(toast, 0.2, {BackgroundTransparency = 0.05}):Play()
    task.delay(opts.Duration or 3, function()
        tween(toast, 0.25, {BackgroundTransparency = 1}):Play()
        task.wait(0.25); toast:Destroy()
    end)
end

-- ═══ WINDOW ═══
local function makeWindow(opts)
    opts = opts or {}
    local self = {}
    local windowConns = {}

    local screen = new("ScreenGui", {
        Parent = hostGui,
        DisplayOrder = 9999,
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })

    local wrapper = new("Frame", {
        Parent = screen,
        Position = UDim2.new(0.5, -280, 0.5, -200),
        Size = UDim2.fromOffset(560, 400),
        BackgroundTransparency = 1,
    })

    local root = new("Frame", {
        Parent = wrapper,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = C.bg,
        BackgroundTransparency = 0.08,
        ClipsDescendants = true,
        BorderSizePixel = 0,
    })
    corner(root, 20)

    local mainStroke = new("UIStroke", {
        Parent = root,
        Color = Color3.new(1, 1, 1),
        Thickness = 2,
        Transparency = 0.1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        LineJoinMode = Enum.LineJoinMode.Round,
    })
    local strokeGradient = makeRainbowGradient(mainStroke, 0)
    task.spawn(function()
        while screen.Parent do
            local t = TS:Create(strokeGradient, TweenInfo.new(8, Enum.EasingStyle.Linear), {Rotation = 360})
            t:Play()
            t.Completed:Wait()
            if strokeGradient.Parent then strokeGradient.Rotation = 0 end
        end
    end)

    local titleBar = new("Frame", {Parent = root, BackgroundColor3 = C.bg2, BackgroundTransparency = 0.25, Size = UDim2.new(1, 0, 0, 38), BorderSizePixel = 0})
    corner(titleBar, 20)
    local titleBarMask = new("Frame", {Parent = titleBar, BackgroundColor3 = C.bg2, BackgroundTransparency = 0.25, Position = UDim2.new(0, 0, 1, -20), Size = UDim2.new(1, 0, 0, 20), BorderSizePixel = 0})
    local accentLine = new("Frame", {Parent = titleBar, BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, BackgroundTransparency = 0.2})
    makeRainbowGradient(accentLine, 0)

    -- Logo opcional en el title bar (a la izquierda del Title).
    -- Acepta URL HTTPS o URI Roblox; resolveImage maneja la descarga + cache
    -- + getcustomasset internamente para URLs externas.
    local titleX = 16
    if opts.Icon and type(opts.Icon) == "string" and #opts.Icon > 0 then
        local resolved, err = resolveImage(opts.Icon)
        if resolved then
            local logo = new("ImageLabel", {
                Parent = titleBar,
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(10, 7),
                Size = UDim2.fromOffset(24, 24),
                Image = resolved,
                ScaleType = Enum.ScaleType.Fit,
            })
            corner(logo, 6)
            titleX = 40
        elseif warn then
            -- Diagnóstico visible en consola para saber por qué no cargó el logo.
            warn(string.format("[LilUI] Window Icon no se pudo cargar: %s (URL: %s)",
                tostring(err), tostring(opts.Icon)))
        end
    end

    local title = text(titleBar, opts.Title or "lil ui", {font = Enum.Font.GothamBold, size = 13})
    title.Position = UDim2.fromOffset(titleX, 0)
    title.Size = UDim2.new(1, -100 - (titleX - 16), 1, 0)
    title.TextYAlignment = Enum.TextYAlignment.Center

    if opts.Author then
        local author = text(titleBar, opts.Author, {size = 10, color = C.mute})
        author.Position = UDim2.fromOffset(titleX + 8 + (#(opts.Title or "") * 7), 2)
        author.Size = UDim2.new(0, 100, 1, 0)
        author.TextYAlignment = Enum.TextYAlignment.Center
    end

    local minBtn = new("TextButton", {Parent = titleBar, BackgroundColor3 = C.bg3, BackgroundTransparency = 0.4, Position = UDim2.new(1, -56, 0, 10), Size = UDim2.fromOffset(20, 18), Text = "−", TextColor3 = C.dim, Font = Enum.Font.GothamBold, TextSize = 14, AutoButtonColor = false})
    corner(minBtn, 5)
    local closeBtn = new("TextButton", {Parent = titleBar, BackgroundColor3 = C.bg3, BackgroundTransparency = 0.4, Position = UDim2.new(1, -32, 0, 10), Size = UDim2.fromOffset(20, 18), Text = "×", TextColor3 = C.dim, Font = Enum.Font.GothamBold, TextSize = 14, AutoButtonColor = false})
    corner(closeBtn, 5)
    for _, b in ipairs({minBtn, closeBtn}) do
        local origin = (b == closeBtn) and C.err or C.accent
        b.MouseEnter:Connect(function() tween(b, 0.1, {BackgroundColor3 = origin, BackgroundTransparency = 0.2, TextColor3 = C.text}):Play() end)
        b.MouseLeave:Connect(function() tween(b, 0.1, {BackgroundColor3 = C.bg3, BackgroundTransparency = 0.4, TextColor3 = C.dim}):Play() end)
    end

    local sidebarBg = new("Frame", {Parent = root, BackgroundColor3 = C.bg2, BackgroundTransparency = 0.35, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(0, 130, 1, -38), BorderSizePixel = 0})
    corner(sidebarBg, 20)
    new("Frame", {Parent = root, BackgroundColor3 = C.bg2, BackgroundTransparency = 0.35, Position = UDim2.fromOffset(0, 38), Size = UDim2.fromOffset(130, 20), BorderSizePixel = 0})
    new("Frame", {Parent = root, BackgroundColor3 = C.bg2, BackgroundTransparency = 0.35, Position = UDim2.fromOffset(110, 38), Size = UDim2.new(0, 20, 1, -38), BorderSizePixel = 0})

    local sidebar = new("Frame", {Parent = root, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(0, 130, 1, -38), BorderSizePixel = 0})
    new("UIPadding", {Parent = sidebar, PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)})
    new("UIListLayout", {Parent = sidebar, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder})
    new("Frame", {Parent = root, BackgroundColor3 = C.line, BackgroundTransparency = 0.5, Position = UDim2.fromOffset(130, 38), Size = UDim2.new(0, 1, 1, -58), BorderSizePixel = 0})

    local content = new("Frame", {Parent = root, BackgroundTransparency = 1, Position = UDim2.fromOffset(131, 38), Size = UDim2.new(1, -131, 1, -38)})

    local dragging, dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = wrapper.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    table.insert(windowConns, UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            if not wrapper or not wrapper.Parent then return end
            local d = input.Position - dragStart
            wrapper.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))

    local tabs = {}
    local activeTab

    closeBtn.MouseButton1Click:Connect(function() screen.Enabled = false end)
    minBtn.MouseButton1Click:Connect(function() screen.Enabled = false end)

    function self:Tab(o)
        o = o or {}
        local tab = {}
        local idx = #tabs + 1

        local btn = new("TextButton", {Parent = sidebar, BackgroundColor3 = C.bg3, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), Text = "", AutoButtonColor = false, LayoutOrder = idx})
        corner(btn, 6)

        local hasIcon = false
        if o.Icon then
            local iconImg = new("ImageLabel", {
                Parent = btn, BackgroundTransparency = 1,
                Position = UDim2.fromOffset(10, 8),
                Size = UDim2.fromOffset(16, 16),
                ImageColor3 = C.dim,
            })
            if applyIconToImageLabel(iconImg, o.Icon) then
                hasIcon = true
                iconImg.Name = "_tabicon"
            else
                iconImg:Destroy()
            end
        end

        local textX = hasIcon and 32 or 12
        local bl = text(btn, o.Title or "Tab", {size = 12})
        bl.Position = UDim2.fromOffset(textX, 0)
        bl.Size = UDim2.new(1, -textX, 1, 0)
        bl.TextYAlignment = Enum.TextYAlignment.Center
        bl.TextColor3 = C.dim

        local indicator = new("Frame", {Parent = btn, BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(0, 6), Size = UDim2.fromOffset(3, 20), BorderSizePixel = 0, BackgroundTransparency = 1})
        corner(indicator, 2)
        makeRainbowGradient(indicator, 90)

        local scroll = new("ScrollingFrame", {
            Parent = content,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = C.line,
            ScrollBarImageTransparency = 0.5,
            Visible = false,
        })
        new("UIPadding", {Parent = scroll, PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 24), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16)})
        new("UIListLayout", {Parent = scroll, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})

        local function selectThis()
            for _, t in ipairs(tabs) do
                t.scroll.Visible = false
                tween(t.bl, 0.15, {TextColor3 = C.dim}):Play()
                tween(t.btn, 0.15, {BackgroundTransparency = 1}):Play()
                tween(t.ind, 0.15, {BackgroundTransparency = 1}):Play()
                local ti = t.btn:FindFirstChild("_tabicon")
                if ti then tween(ti, 0.15, {ImageColor3 = C.dim}):Play() end
            end
            scroll.Visible = true
            tween(bl, 0.15, {TextColor3 = C.text}):Play()
            tween(btn, 0.15, {BackgroundTransparency = 0.5}):Play()
            tween(indicator, 0.15, {BackgroundTransparency = 0}):Play()
            local mi = btn:FindFirstChild("_tabicon")
            if mi then tween(mi, 0.15, {ImageColor3 = C.text}):Play() end
            activeTab = tab
        end

        btn.MouseButton1Click:Connect(selectThis)
        btn.MouseEnter:Connect(function() if activeTab ~= tab then tween(btn, 0.1, {BackgroundTransparency = 0.8}):Play() end end)
        btn.MouseLeave:Connect(function() if activeTab ~= tab then tween(btn, 0.1, {BackgroundTransparency = 1}):Play() end end)

        tab.scroll = scroll; tab.btn = btn; tab.bl = bl; tab.ind = indicator; tab.select = selectThis
        tabs[idx] = tab

        local order = 0
        local function nx() order = order + 1; return order end

        function tab:Section(o2)
            local f = new("Frame", {Parent = scroll, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = nx()})
            local t = text(f, string.upper(o2.Title or ""), {font = Enum.Font.GothamBold, size = 11, color = C.mute})
            t.Size = UDim2.new(1, 0, 1, 0)
            return f
        end

        function tab:Paragraph(o2)
            local s2 = {}
            local card = new("Frame", {Parent = scroll, BackgroundColor3 = C.bg2, BackgroundTransparency = 0.25, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nx()})
            corner(card, 8); stroke(card, C.line)
            new("UIPadding", {Parent = card, PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)})
            new("UIListLayout", {Parent = card, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder})
            local tL = text(card, o2.Title or "", {font = Enum.Font.GothamBold, size = 13}); tL.LayoutOrder = 1
            local dL = text(card, o2.Desc or "", {font = Enum.Font.Gotham, size = 12, color = C.dim}); dL.LayoutOrder = 2
            function s2:SetTitle(x) tL.Text = tostring(x or "") end
            function s2:SetDesc(x) dL.Text = tostring(x or "") end
            return s2
        end

        -- ═══ PLAYERCARD ═══
        -- Tarjeta con avatar + título + subtítulo. Perfecto para mostrar "tu cuenta"
        -- en una pestaña de créditos. Usa rbxthumb:// que carga sin yield.
        -- API: tab:PlayerCard({ UserId = 123, Title = "DisplayName", Subtitle = "@user | ID: 123" })
        function tab:PlayerCard(o2)
            local s2 = {}
            local card = new("Frame", {
                Parent = scroll,
                BackgroundColor3 = C.bg2,
                BackgroundTransparency = 0.25,
                Size = UDim2.new(1, 0, 0, 56),  -- altura fija para acomodar el avatar
                LayoutOrder = nx(),
            })
            corner(card, 8); stroke(card, C.line)
            new("UIPadding", {Parent = card, PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 12)})

            -- Avatar (rbxthumb URI carga sin necesidad de yield/HTTP)
            local AVATAR_SIZE = 40
            local userId = tonumber(o2.UserId) or 1
            local avatar = new("ImageLabel", {
                Parent = card,
                BackgroundColor3 = C.bg3,
                BackgroundTransparency = 0.3,
                Position = UDim2.fromOffset(0, 0),
                Size = UDim2.fromOffset(AVATAR_SIZE, AVATAR_SIZE),
                Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId) .. "&w=150&h=150",
                ScaleType = Enum.ScaleType.Fit,
            })
            corner(avatar, AVATAR_SIZE / 2)  -- circular
            stroke(avatar, C.accent, 1)

            -- Contenedor de texto a la derecha del avatar
            local txt = new("Frame", {
                Parent = card,
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(AVATAR_SIZE + 12, 0),
                Size = UDim2.new(1, -(AVATAR_SIZE + 12), 1, 0),
            })
            new("UIListLayout", {Parent = txt, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center})

            local tL = text(txt, o2.Title or "Player", {font = Enum.Font.GothamBold, size = 14}); tL.LayoutOrder = 1
            local dL = text(txt, o2.Subtitle or "", {font = Enum.Font.Gotham, size = 12, color = C.dim}); dL.LayoutOrder = 2

            function s2:SetTitle(x) tL.Text = tostring(x or "") end
            function s2:SetSubtitle(x) dL.Text = tostring(x or "") end
            function s2:SetUserId(id)
                userId = tonumber(id) or 1
                avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId) .. "&w=150&h=150"
            end
            return s2
        end

        function tab:Button(o2)
            local btn2 = new("TextButton", {Parent = scroll, BackgroundColor3 = C.bg2, BackgroundTransparency = 0.25, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = "", AutoButtonColor = false, LayoutOrder = nx()})
            corner(btn2, 8); stroke(btn2, C.line)
            new("UIPadding", {Parent = btn2, PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)})
            new("UIListLayout", {Parent = btn2, Padding = UDim.new(0, 2)})
            local tL = text(btn2, o2.Title or "Button", {font = Enum.Font.GothamBold, size = 13}); tL.LayoutOrder = 1
            if o2.Desc and #o2.Desc > 0 then local dL = text(btn2, o2.Desc, {font = Enum.Font.Gotham, size = 12, color = C.dim}); dL.LayoutOrder = 2 end
            btn2.MouseEnter:Connect(function() tween(btn2, 0.1, {BackgroundColor3 = C.bg3, BackgroundTransparency = 0.15}):Play() end)
            btn2.MouseLeave:Connect(function() tween(btn2, 0.1, {BackgroundColor3 = C.bg2, BackgroundTransparency = 0.25}):Play() end)
            btn2.MouseButton1Click:Connect(function() if o2.Callback then task.spawn(function() pcall(o2.Callback) end) end end)
            return btn2
        end

        -- ═══ INPUT ═══
        -- Caja de texto editable. Callback se dispara al perder foco con Enter
        -- (o explícitamente cuando el user clickea fuera). Útil para pegar keys,
        -- nombres, URLs, etc.
        -- API: o2.Title, o2.Desc, o2.Placeholder, o2.Default, o2.Callback(text)
        --      obj.Value (string actual), obj:Set(text), obj:Clear()
        function tab:Input(o2)
            local s2 = {}
            local current = tostring(o2.Default or "")
            local hasDesc = o2.Desc and #tostring(o2.Desc) > 0
            local padY = hasDesc and 9 or 7

            local card = new("Frame", {Parent = scroll, BackgroundColor3 = C.bg2, BackgroundTransparency = 0.25, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nx()})
            corner(card, 8); stroke(card, C.line)
            new("UIPadding", {Parent = card, PaddingTop = UDim.new(0, padY), PaddingBottom = UDim.new(0, padY), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)})
            new("UIListLayout", {Parent = card, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})

            local tL = text(card, o2.Title or "Input", {font = Enum.Font.GothamBold, size = 13}); tL.LayoutOrder = 1
            if hasDesc then
                local dL = text(card, tostring(o2.Desc), {font = Enum.Font.Gotham, size = 12, color = C.dim}); dL.LayoutOrder = 2
            end

            local box = new("TextBox", {
                Parent = card,
                BackgroundColor3 = C.bg3,
                BackgroundTransparency = 0.3,
                Size = UDim2.new(1, 0, 0, 30),
                Font = Enum.Font.Code,
                TextSize = 13,
                TextColor3 = C.text,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center,
                PlaceholderText = tostring(o2.Placeholder or ""),
                PlaceholderColor3 = C.mute,
                Text = current,
                ClearTextOnFocus = false,
                LayoutOrder = 3,
            })
            corner(box, 6)
            -- Capturamos la stroke para poder cambiar su Color en focus sin
            -- crear strokes apilados (stroke() crea un Instance nuevo cada vez).
            local boxStroke = stroke(box, C.line)
            new("UIPadding", {Parent = box, PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)})

            local function commit(text)
                current = text or ""
                s2.Value = current
                if o2.Callback then task.spawn(function() pcall(o2.Callback, current) end) end
            end

            box.Focused:Connect(function()
                tween(box, 0.1, {BackgroundTransparency = 0.15}):Play()
                pcall(function() boxStroke.Color = C.accent end)
            end)
            box.FocusLost:Connect(function(enter)
                tween(box, 0.1, {BackgroundTransparency = 0.3}):Play()
                pcall(function() boxStroke.Color = C.line end)
                commit(box.Text)
            end)

            s2.Value = current
            function s2:Set(t)
                current = tostring(t or "")
                box.Text = current
                self.Value = current
            end
            function s2:Clear()
                self:Set("")
            end
            return s2
        end

        -- ═══ TOGGLE ═══
        -- Switch on/off animado. Callback recibe boolean.
        -- API: obj.Value (boolean actual), obj:Set(bool) para setear programáticamente
        function tab:Toggle(o2)
            local s2 = {}
            local state = o2.Value == true
            local hasDesc = o2.Desc and #tostring(o2.Desc) > 0

            -- Padding adaptivo: cuando NO hay desc, el contenido es chico → reducimos
            -- el padding vertical para que la fila quede compacta (sin espacios muertos).
            -- Cuando SÍ hay desc, mantenemos el padding original.
            local padY = hasDesc and 9 or 6

            local card = new("Frame", {
                Parent = scroll,
                BackgroundColor3 = C.bg2,
                BackgroundTransparency = 0.25,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = nx(),
            })
            corner(card, 8); stroke(card, C.line)
            new("UIPadding", {Parent = card, PaddingTop = UDim.new(0, padY), PaddingBottom = UDim.new(0, padY), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)})

            -- Lado izquierdo: title + desc
            local left = new("Frame", {
                Parent = card,
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(0, 0),
                Size = UDim2.new(1, -54, 1, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
            })
            new("UIListLayout", {Parent = left, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder})
            local tL = text(left, o2.Title or "Toggle", {font = Enum.Font.GothamBold, size = 13}); tL.LayoutOrder = 1
            if hasDesc then
                local dL = text(left, tostring(o2.Desc), {font = Enum.Font.Gotham, size = 12, color = C.dim}); dL.LayoutOrder = 2
            end

            -- Switch (track + knob). Centrado verticalmente para que se alinee con
            -- el título tanto en filas con desc como sin desc.
            local track = new("TextButton", {
                Parent = card,
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, 0, 0.5, 0),
                Size = UDim2.fromOffset(44, 22),
                BackgroundColor3 = C.bg3,
                BackgroundTransparency = 0.2,
                Text = "",
                AutoButtonColor = false,
            })
            corner(track, 11)
            stroke(track, C.line)

            local knob = new("Frame", {
                Parent = track,
                BackgroundColor3 = C.dim,
                Position = UDim2.fromOffset(2, 2),
                Size = UDim2.fromOffset(18, 18),
                BorderSizePixel = 0,
            })
            corner(knob, 9)

            local function applyVisual(animated)
                local tweenTime = animated and 0.15 or 0
                if state then
                    tween(track, tweenTime, {BackgroundColor3 = C.accent, BackgroundTransparency = 0.05}):Play()
                    tween(knob, tweenTime, {Position = UDim2.fromOffset(24, 2), BackgroundColor3 = C.text}):Play()
                else
                    tween(track, tweenTime, {BackgroundColor3 = C.bg3, BackgroundTransparency = 0.2}):Play()
                    tween(knob, tweenTime, {Position = UDim2.fromOffset(2, 2), BackgroundColor3 = C.dim}):Play()
                end
            end

            applyVisual(false)

            local function fire()
                if o2.Callback then task.spawn(function() pcall(o2.Callback, state) end) end
            end

            track.MouseButton1Click:Connect(function()
                state = not state
                s2.Value = state
                applyVisual(true)
                fire()
            end)

            -- Hover en el track
            track.MouseEnter:Connect(function()
                tween(track, 0.1, {BackgroundTransparency = state and 0 or 0.1}):Play()
            end)
            track.MouseLeave:Connect(function()
                tween(track, 0.1, {BackgroundTransparency = state and 0.05 or 0.2}):Play()
            end)

            s2.Value = state
            function s2:Set(v, suppressCallback)
                local newState = (v == true)
                if newState == state then return end
                state = newState
                self.Value = state
                applyVisual(true)
                -- Por defecto :Set dispara el callback.
                -- Pasar suppressCallback=true para seteo silencioso.
                if not suppressCallback then fire() end
            end
            -- Alias retrocompatible
            function s2:Toggle()
                state = not state
                self.Value = state
                applyVisual(true)
                fire()
            end

            return s2
        end

        -- ═══ SLIDER ═══
        -- Deslizador numérico. Value puede ser:
        --   - tabla {Min=n, Max=n, Default=n}
        --   - número (usado como Default con Min=0 Max=100)
        function tab:Slider(o2)
            local s2 = {}
            local v = o2.Value or {}
            local minV, maxV, defV
            if type(v) == "table" then
                minV = v.Min or 0
                maxV = v.Max or 100
                defV = v.Default or v.Value or minV
            else
                minV = 0; maxV = 100; defV = tonumber(v) or 0
            end
            local current = clamp(defV, minV, maxV)
            local isInt = math.floor(minV) == minV and math.floor(maxV) == maxV

            local card = new("Frame", {
                Parent = scroll,
                BackgroundColor3 = C.bg2,
                BackgroundTransparency = 0.25,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = nx(),
            })
            corner(card, 8); stroke(card, C.line)
            new("UIPadding", {Parent = card, PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)})
            new("UIListLayout", {Parent = card, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})

            -- Header con title + valor actual (editable). Altura 24 para que el TextBox
            -- de 22px renderice completo (antes era 18 y se cortaba arriba/abajo).
            local header = new("Frame", {Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 1})
            local tL = text(header, o2.Title or "Slider", {font = Enum.Font.GothamBold, size = 13})
            tL.Size = UDim2.new(1, -78, 1, 0); tL.TextYAlignment = Enum.TextYAlignment.Center

            -- valLbl es un TextBox editable: click → editar → Enter para guardar.
            -- IMPORTANTE: NO incluir AutoButtonColor — es solo de TextButton, en TextBox
            -- tira error y aborta la construcción del slider (rompe el track + todo el
            -- script después). Pase eso antes y se rompió la UI.
            local valLbl = new("TextBox", {
                Parent = header,
                BackgroundColor3 = C.bg3,
                BackgroundTransparency = 0.4,
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, 0, 0.5, 0),
                Size = UDim2.fromOffset(72, 22),
                Font = Enum.Font.GothamBold,
                TextSize = 13,
                TextColor3 = C.accent,
                TextXAlignment = Enum.TextXAlignment.Center,
                TextYAlignment = Enum.TextYAlignment.Center,
                Text = tostring(current),
                ClearTextOnFocus = false,  -- preservar el valor actual al focar para editarlo
                PlaceholderText = "",
                TextEditable = true,
            })
            corner(valLbl, 5); stroke(valLbl, C.line, 1)

            if o2.Desc and #tostring(o2.Desc) > 0 then
                local dL = text(card, tostring(o2.Desc), {font = Enum.Font.Gotham, size = 12, color = C.dim}); dL.LayoutOrder = 2
            end

            -- Track del slider
            local trackContainer = new("Frame", {
                Parent = card,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 18),
                LayoutOrder = 3,
            })
            local track = new("Frame", {
                Parent = trackContainer,
                BackgroundColor3 = C.bg3,
                BackgroundTransparency = 0.2,
                Position = UDim2.new(0, 0, 0.5, -3),
                Size = UDim2.new(1, 0, 0, 6),
                BorderSizePixel = 0,
            })
            corner(track, 3)

            local fill = new("Frame", {
                Parent = track,
                BackgroundColor3 = C.accent,
                Size = UDim2.new(0, 0, 1, 0),
                BorderSizePixel = 0,
            })
            corner(fill, 3)
            makeRainbowGradient(fill, 0)

            local knob = new("Frame", {
                Parent = trackContainer,
                BackgroundColor3 = C.text,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0, 0, 0.5, 0),
                Size = UDim2.fromOffset(14, 14),
                BorderSizePixel = 0,
            })
            corner(knob, 7)
            stroke(knob, C.accent, 1)

            local editing = false
            local function refreshVisual()
                local t = (current - minV) / (maxV - minV)
                t = clamp(t, 0, 1)
                fill.Size = UDim2.new(t, 0, 1, 0)
                knob.Position = UDim2.new(t, 0, 0.5, 0)
                -- No sobreescribimos el TextBox mientras el user está escribiendo
                if not editing then
                    if isInt then
                        valLbl.Text = tostring(math.floor(current + 0.5))
                    else
                        valLbl.Text = string.format("%.2f", current)
                    end
                end
            end
            refreshVisual()

            -- Hover visual del TextBox (indica que es clickeable)
            valLbl.MouseEnter:Connect(function()
                if not editing then
                    tween(valLbl, 0.1, {BackgroundTransparency = 0.2}):Play()
                end
            end)
            valLbl.MouseLeave:Connect(function()
                if not editing then
                    tween(valLbl, 0.1, {BackgroundTransparency = 0.4}):Play()
                end
            end)

            valLbl.Focused:Connect(function()
                editing = true
                tween(valLbl, 0.1, {BackgroundTransparency = 0.1}):Play()
            end)

            -- FocusLost recibe `enterPressed` (true si fue por Enter, false si por click
            -- afuera o Escape). En ambos casos parseamos. Si el input es inválido,
            -- restauramos el último valor válido.
            valLbl.FocusLost:Connect(function(enterPressed)
                editing = false
                tween(valLbl, 0.1, {BackgroundTransparency = 0.4}):Play()
                local typed = valLbl.Text and valLbl.Text:gsub("[^%-%d%.]", "") or ""
                local nv = tonumber(typed)
                if nv then
                    nv = clamp(nv, minV, maxV)
                    if isInt then nv = math.floor(nv + 0.5) end
                    if nv ~= current then
                        current = nv
                        s2.Value = current
                        refreshVisual()
                        if o2.Callback then task.spawn(function() pcall(o2.Callback, current) end) end
                    else
                        refreshVisual()  -- normaliza el texto (ej. user tipeó "10.0", muestra "10")
                    end
                else
                    refreshVisual()  -- input inválido, restaurar
                end
            end)

            local function setFromX(mouseX)
                local trackAbsX = track.AbsolutePosition.X
                local trackW = track.AbsoluteSize.X
                if trackW <= 0 then return end
                local t = clamp((mouseX - trackAbsX) / trackW, 0, 1)
                local newVal = minV + (maxV - minV) * t
                if isInt then newVal = math.floor(newVal + 0.5) end
                if newVal ~= current then
                    current = newVal
                    s2.Value = current
                    refreshVisual()
                    if o2.Callback then task.spawn(function() pcall(o2.Callback, current) end) end
                end
            end

            local draggingSlider = false
            trackContainer.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    draggingSlider = true
                    setFromX(input.Position.X)
                end
            end)
            table.insert(windowConns, UIS.InputChanged:Connect(function(input)
                if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    setFromX(input.Position.X)
                end
            end))
            table.insert(windowConns, UIS.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    draggingSlider = false
                end
            end))

            s2.Value = current
            function s2:Set(v)
                local nv = tonumber(v)
                if not nv then return end
                current = clamp(nv, minV, maxV)
                if isInt then current = math.floor(current + 0.5) end
                self.Value = current
                refreshVisual()
            end

            return s2
        end

        -- ═══ COLORPICKER ═══
        -- Picker visual de color en HSV (cuadro saturación/valor + slider hue)
        function tab:Colorpicker(o2)
            local s2 = {}
            local current = o2.Default or o2.Value or Color3.new(1, 0, 1)
            local h, s, v = Color3.toHSV(current)

            local card = new("Frame", {
                Parent = scroll,
                BackgroundColor3 = C.bg2,
                BackgroundTransparency = 0.25,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = nx(),
            })
            corner(card, 8); stroke(card, C.line)
            new("UIPadding", {Parent = card, PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)})
            new("UIListLayout", {Parent = card, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})

            -- Header: title + preview cuadrado del color
            local header = new("TextButton", {
                Parent = card,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 24),
                Text = "",
                AutoButtonColor = false,
                LayoutOrder = 1,
            })
            local tL = text(header, o2.Title or "Color", {font = Enum.Font.GothamBold, size = 13})
            tL.Size = UDim2.new(1, -38, 1, 0); tL.TextYAlignment = Enum.TextYAlignment.Center

            local preview = new("Frame", {
                Parent = header,
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, 0, 0.5, 0),
                Size = UDim2.fromOffset(28, 18),
                BackgroundColor3 = current,
                BorderSizePixel = 0,
            })
            corner(preview, 5)
            stroke(preview, C.line)

            if o2.Desc and #tostring(o2.Desc) > 0 then
                local dL = text(card, tostring(o2.Desc), {font = Enum.Font.Gotham, size = 12, color = C.dim}); dL.LayoutOrder = 2
            end

            -- Container del picker (se muestra al hacer click en el header)
            local pickerContainer = new("Frame", {
                Parent = card,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Visible = false,
                LayoutOrder = 3,
            })
            new("UIListLayout", {Parent = pickerContainer, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})

            -- SV box (cuadro de saturación x valor)
            local svBox = new("Frame", {
                Parent = pickerContainer,
                BackgroundColor3 = hsv(h, 1, 1),
                Size = UDim2.new(1, 0, 0, 110),
                BorderSizePixel = 0,
                LayoutOrder = 1,
            })
            corner(svBox, 6)
            stroke(svBox, C.line)

            -- Gradiente blanco (saturación horizontal)
            local satGrad = new("Frame", {
                Parent = svBox,
                BackgroundColor3 = Color3.new(1, 1, 1),
                Size = UDim2.new(1, 0, 1, 0),
                BorderSizePixel = 0,
            })
            corner(satGrad, 6)
            new("UIGradient", {
                Parent = satGrad,
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                    ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
                }),
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(1, 1),
                }),
            })

            -- Gradiente negro (valor vertical)
            local valGrad = new("Frame", {
                Parent = svBox,
                BackgroundColor3 = Color3.new(0, 0, 0),
                Size = UDim2.new(1, 0, 1, 0),
                BorderSizePixel = 0,
            })
            corner(valGrad, 6)
            new("UIGradient", {
                Parent = valGrad,
                Rotation = 90,
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.new(0, 0, 0)),
                    ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)),
                }),
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 1),
                    NumberSequenceKeypoint.new(1, 0),
                }),
            })

            -- Cursor SV (círculo pequeño)
            local svCursor = new("Frame", {
                Parent = svBox,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(s, 0, 1 - v, 0),
                Size = UDim2.fromOffset(10, 10),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
            })
            stroke(svCursor, Color3.new(1, 1, 1), 2)
            corner(svCursor, 5)

            -- Hue bar
            local hueBar = new("Frame", {
                Parent = pickerContainer,
                Size = UDim2.new(1, 0, 0, 14),
                BorderSizePixel = 0,
                BackgroundTransparency = 0,
                LayoutOrder = 2,
            })
            corner(hueBar, 4)
            stroke(hueBar, C.line)
            new("UIGradient", {
                Parent = hueBar,
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0.000, Color3.fromRGB(255, 0, 0)),
                    ColorSequenceKeypoint.new(0.167, Color3.fromRGB(255, 255, 0)),
                    ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0, 255, 0)),
                    ColorSequenceKeypoint.new(0.500, Color3.fromRGB(0, 255, 255)),
                    ColorSequenceKeypoint.new(0.667, Color3.fromRGB(0, 0, 255)),
                    ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255, 0, 255)),
                    ColorSequenceKeypoint.new(1.000, Color3.fromRGB(255, 0, 0)),
                }),
            })

            local hueCursor = new("Frame", {
                Parent = hueBar,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(h, 0, 0.5, 0),
                Size = UDim2.fromOffset(4, 18),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BorderSizePixel = 0,
            })
            corner(hueCursor, 2)

            local function updateColor(fireCb)
                current = hsv(h, s, v)
                svBox.BackgroundColor3 = hsv(h, 1, 1)
                svCursor.Position = UDim2.new(s, 0, 1 - v, 0)
                hueCursor.Position = UDim2.new(h, 0, 0.5, 0)
                preview.BackgroundColor3 = current
                s2.Value = current
                if fireCb and o2.Callback then
                    task.spawn(function() pcall(o2.Callback, current) end)
                end
            end

            -- Drag para SV box
            local draggingSV = false
            svBox.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    draggingSV = true
                end
            end)
            table.insert(windowConns, UIS.InputChanged:Connect(function(input)
                if draggingSV and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    local pos = svBox.AbsolutePosition
                    local size = svBox.AbsoluteSize
                    if size.X <= 0 or size.Y <= 0 then return end
                    s = clamp((input.Position.X - pos.X) / size.X, 0, 1)
                    v = clamp(1 - (input.Position.Y - pos.Y) / size.Y, 0, 1)
                    updateColor(true)
                end
            end))

            -- Drag para hue bar
            local draggingHue = false
            hueBar.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    draggingHue = true
                    local pos = hueBar.AbsolutePosition
                    local size = hueBar.AbsoluteSize
                    h = clamp((input.Position.X - pos.X) / size.X, 0, 1)
                    updateColor(true)
                end
            end)
            table.insert(windowConns, UIS.InputChanged:Connect(function(input)
                if draggingHue and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    local pos = hueBar.AbsolutePosition
                    local size = hueBar.AbsoluteSize
                    if size.X <= 0 then return end
                    h = clamp((input.Position.X - pos.X) / size.X, 0, 1)
                    updateColor(true)
                end
            end))

            table.insert(windowConns, UIS.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    draggingSV = false; draggingHue = false
                end
            end))

            local open = false
            header.MouseButton1Click:Connect(function()
                open = not open
                pickerContainer.Visible = open
            end)

            s2.Value = current
            function s2:Set(c)
                if typeof(c) ~= "Color3" then return end
                h, s, v = Color3.toHSV(c)
                updateColor(false)
            end

            return s2
        end

        function tab:Dropdown(o2)
            local s2 = {}
            local values = o2.Values or {}
            local current = o2.Value or values[1] or ""
            local open = false

            local container = new("Frame", {Parent = scroll, BackgroundColor3 = C.bg2, BackgroundTransparency = 0.25, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nx()})
            corner(container, 8); stroke(container, C.line)
            new("UIPadding", {Parent = container, PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)})
            new("UIListLayout", {Parent = container, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})

            local tL = text(container, o2.Title or "Dropdown", {font = Enum.Font.GothamBold, size = 13}); tL.LayoutOrder = 1
            if o2.Desc and #o2.Desc > 0 then local dL = text(container, o2.Desc, {font = Enum.Font.Gotham, size = 12, color = C.dim}); dL.LayoutOrder = 2 end

            local headerBtn = new("TextButton", {Parent = container, BackgroundColor3 = C.bg3, BackgroundTransparency = 0.15, Size = UDim2.new(1, 0, 0, 32), Text = "", AutoButtonColor = false, LayoutOrder = 3})
            corner(headerBtn, 6); stroke(headerBtn, C.line)
            local hL = text(headerBtn, tostring(current), {size = 13, font = Enum.Font.GothamSemibold}); hL.Position = UDim2.fromOffset(12, 0); hL.Size = UDim2.new(1, -32, 1, 0); hL.TextYAlignment = Enum.TextYAlignment.Center; hL.TextTruncate = Enum.TextTruncate.AtEnd
            local arrow = text(headerBtn, "▼", {size = 10, color = C.dim, align = Enum.TextXAlignment.Center}); arrow.Position = UDim2.new(1, -22, 0, 0); arrow.Size = UDim2.fromOffset(16, 28); arrow.TextYAlignment = Enum.TextYAlignment.Center

            local listFrame = new("Frame", {Parent = container, BackgroundColor3 = C.bg, BackgroundTransparency = 0.3, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, LayoutOrder = 4})
            corner(listFrame, 6); stroke(listFrame, C.line)
            new("UIPadding", {Parent = listFrame, PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4)})

            local scrollList = new("ScrollingFrame", {Parent = listFrame, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0), BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = C.line, AutomaticSize = Enum.AutomaticSize.Y})
            new("UIListLayout", {Parent = scrollList, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder})

            local function rebuild()
                for _, c in ipairs(scrollList:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
                local maxShow = 7
                for i, val in ipairs(values) do
                    local item = new("TextButton", {Parent = scrollList, BackgroundColor3 = C.bg2, BackgroundTransparency = 0.3, Size = UDim2.new(1, -4, 0, 32), Text = "", AutoButtonColor = false, LayoutOrder = i})
                    corner(item, 6)
                    local iL = text(item, tostring(val), {size = 13, font = Enum.Font.GothamSemibold})
                    iL.Position = UDim2.fromOffset(12, 0)
                    iL.Size = UDim2.new(1, -12, 1, 0)
                    iL.TextYAlignment = Enum.TextYAlignment.Center
                    iL.TextTruncate = Enum.TextTruncate.AtEnd
                    iL.TextColor3 = C.text
                    item.MouseEnter:Connect(function()
                        tween(item, 0.1, {BackgroundColor3 = C.bg3, BackgroundTransparency = 0.05}):Play()
                        tween(iL, 0.1, {TextColor3 = C.accent}):Play()
                    end)
                    item.MouseLeave:Connect(function()
                        tween(item, 0.1, {BackgroundColor3 = C.bg2, BackgroundTransparency = 0.3}):Play()
                        tween(iL, 0.1, {TextColor3 = C.text}):Play()
                    end)
                    item.MouseButton1Click:Connect(function()
                        current = val; hL.Text = tostring(val); listFrame.Visible = false; open = false; arrow.Text = "▼"
                        s2.Value = val
                        if o2.Callback then task.spawn(function() pcall(o2.Callback, val) end) end
                    end)
                end
                scrollList.Size = UDim2.new(1, 0, 0, math.min(#values, maxShow) * 34)
            end

            headerBtn.MouseButton1Click:Connect(function()
                open = not open; listFrame.Visible = open; arrow.Text = open and "▲" or "▼"
            end)

            rebuild()

            s2.Value = current
            function s2:Refresh(newVals)
                values = newVals or {}
                if not table.find(values, current) then
                    current = values[1] or ""
                    hL.Text = tostring(current)
                    s2.Value = current
                end
                rebuild()
            end
            s2.SetValues = s2.Refresh
            function s2:Set(v)
                if table.find(values, v) then
                    current = v
                    hL.Text = tostring(v)
                    s2.Value = v
                end
            end

            return s2
        end

        -- ═══ KEYBIND ═══
        function tab:Keybind(o2)
            local s2 = {}
            local current = o2.Value or ""
            local listening = false
            local hasDesc = o2.Desc and #tostring(o2.Desc) > 0

            -- Padding adaptivo: si no hay desc, fila compacta para no malgastar
            -- espacio vertical (igual patrón que aplicamos a Toggle).
            local padY = hasDesc and 9 or 5

            local card = new("Frame", {Parent = scroll, BackgroundColor3 = C.bg2, BackgroundTransparency = 0.25, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nx()})
            corner(card, 8); stroke(card, C.line)
            new("UIPadding", {Parent = card, PaddingTop = UDim.new(0, padY), PaddingBottom = UDim.new(0, padY), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)})

            local left = new("Frame", {Parent = card, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -84, 1, 0), AutomaticSize = Enum.AutomaticSize.Y})
            new("UIListLayout", {Parent = left, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder})
            local tL = text(left, o2.Title or "Keybind", {font = Enum.Font.GothamBold, size = 13}); tL.LayoutOrder = 1
            if hasDesc then local dL = text(left, tostring(o2.Desc), {font = Enum.Font.Gotham, size = 12, color = C.dim}); dL.LayoutOrder = 2 end

            -- Botón centrado verticalmente al contenido (en vez de pegado arriba).
            -- Bajamos de 26→22 px y centramos para que la fila quede más compacta.
            local kbtn = new("TextButton", {Parent = card, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(72, 22), BackgroundColor3 = C.bg3, BackgroundTransparency = 0.2, Text = current, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.text, AutoButtonColor = false})
            corner(kbtn, 5); stroke(kbtn, C.line)

            -- Flag publica: scripts pueden chequear obj.IsListening para
            -- skipear sus listeners globales mientras el user re-asigna teclas.
            -- Esto evita el bug donde la nueva tecla matchea con el nuevo
            -- valor que LilUI acaba de setear y ejecuta acciones no deseadas.
            s2.IsListening = false

            -- Cooldown post-listen para suprimir el race-condition: a veces
            -- el InputBegan global del consumidor llega DESPUES que LilUI
            -- procesa la tecla. Exponemos un timestamp para que el consumidor
            -- decida si ignorar inputs muy frescos despues de un rebind.
            s2.LastBindTs = 0

            kbtn.MouseButton1Click:Connect(function()
                listening = true; s2.IsListening = true; kbtn.Text = "..."
                tween(kbtn, 0.1, {BackgroundColor3 = C.accent, BackgroundTransparency = 0.1}):Play()
            end)

            table.insert(windowConns, UIS.InputBegan:Connect(function(input)
                if not listening then return end
                if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
                local n = input.KeyCode and input.KeyCode.Name
                if not n or n == "Unknown" then return end
                current = n; kbtn.Text = n
                s2.Value = n
                tween(kbtn, 0.1, {BackgroundColor3 = C.bg3, BackgroundTransparency = 0.2}):Play()
                listening = false
                s2.IsListening = false
                s2.LastBindTs = tick()  -- marca para suprimir el siguiente input
                if o2.Callback then task.spawn(function() pcall(o2.Callback, n) end) end
            end))

            s2.Value = current
            function s2:Set(k)
                current = tostring(k or "None")
                kbtn.Text = current
                self.Value = current
            end

            return s2
        end

        return tab
    end

    function self:SelectTab(i) if tabs[i] then tabs[i].select() end end

    function self:Toggle() screen.Enabled = not screen.Enabled end

    function self:Destroy()
        for _, c in ipairs(windowConns) do pcall(function() c:Disconnect() end) end
        windowConns = {}
        pcall(function() screen:Destroy() end)
        pcall(function() if notifyHost then notifyHost:Destroy(); notifyHost = nil; notifyStack = nil end end)
    end

    function self:SetVisible(v) screen.Enabled = v end

    return self
end

return {
    CreateWindow = function(_, opts) return makeWindow(opts) end,
    Notify = function(_, opts) notify(opts or {}) end,
    _version = "1.1.0",
}

end)()
