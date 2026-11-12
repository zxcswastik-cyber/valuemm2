-- MM2 CARBON X | Read-Only Trading Companion
local ok, failure = xpcall(function()
    local MM2_UNIVERSE_ID = 66654135
    local MAIN_PLACE_ID = 142823291
    if tonumber(game.GameId) ~= MM2_UNIVERSE_ID and tonumber(game.PlaceId) ~= MAIN_PLACE_ID then
        warn("[Carbon X] Unsupported experience: " .. tostring(game.GameId))
        return
    end

    local Players = game:GetService("Players")
    local HttpService = game:GetService("HttpService")
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local GuiService = game:GetService("GuiService")

    local player = Players.LocalPlayer
    if not player then return end
    local playerGui = player:WaitForChild("PlayerGui")

    local env = (type(getgenv) == "function" and getgenv()) or _G
    for _, fnName in ipairs({"MM2CarbonCleanup", "MM2ValueDeskCleanup", "MM2TradeValuesCleanup"}) do
        if type(env[fnName]) == "function" then
            pcall(env[fnName])
            env[fnName] = nil
        end
    end

    for _, name in ipairs({
        "MM2CarbonTradeV5", "MM2CarbonTradeV6", "MM2CarbonTradeV7",
        "MM2CarbonTradeV8", "MM2CarbonXV9", "MM2CarbonXV10", "MM2CarbonX", "MM2CarbonXError"
    }) do
        local old = playerGui:FindFirstChild(name)
        if old then pcall(function() old:Destroy() end) end
    end

    for _, desc in ipairs(playerGui:GetDescendants()) do
        if desc.Name == "CarbonXValueTag" then
            pcall(function() desc:Destroy() end)
        end
    end

    local Config = {
        URL_SUPREME = "https://raw.githubusercontent.com/yanaa-12/mm2-trading/main/docs/data/latest.csv",
        URL_META = "https://raw.githubusercontent.com/yanaa-12/mm2-trading/main/docs/data/meta.json",
        URL_MM2 = "https://raw.githubusercontent.com/timez170/mm2-values/main/values.json",
        OFFICIAL_SITE = "https://supremevalues.com/mm2/trading",
        JOIN_PREFIX = "https://www.roblox.com/games/142823291/Murder-Mystery-2?privateServerLinkCode=",
        RELOAD_URL = "https://raw.githubusercontent.com/zxcswastik-cyber/valuemm2/main/MM2_CARBON_X_V9.lua",
        PRICE_CACHE = "MM2CarbonX_prices.json",
        CONFIG_FILE = "MM2CarbonX_settings.json",
        HISTORY_FILE = "MM2CarbonX_history.json",
        SIGHTINGS_FILE = "MM2CarbonX_sightings.json",
        TOGGLE_KEY = Enum.KeyCode.RightShift
    }

    -- Tonal Elevation Palette
    local Palette = {
        canvas = Color3.fromRGB(16, 17, 20),
        sidebar = Color3.fromRGB(20, 22, 26),
        surface = Color3.fromRGB(26, 29, 34),
        elevated = Color3.fromRGB(34, 38, 45),
        hover = Color3.fromRGB(41, 46, 54),
        hairline = Color3.fromRGB(42, 47, 55),
        focus = Color3.fromRGB(110, 122, 138),

        text = Color3.fromRGB(240, 242, 245),
        subtext = Color3.fromRGB(145, 153, 165),
        muted = Color3.fromRGB(96, 103, 114),

        accent = Color3.fromRGB(238, 240, 244),
        accentFg = Color3.fromRGB(16, 17, 20),

        pos = Color3.fromRGB(72, 208, 148),
        posBg = Color3.fromRGB(22, 45, 36),
        neg = Color3.fromRGB(236, 106, 106),
        negBg = Color3.fromRGB(49, 25, 28),
        warn = Color3.fromRGB(232, 186, 104),
        warnBg = Color3.fromRGB(47, 38, 22)
    }

    local State = {
        alive = true,
        conns = {},
        tabConns = {},
        tradeConns = {},
        created = {},
        badges = setmetatable({}, {__mode = "k"}),
        trackedPlayers = setmetatable({}, {__mode = "k"}),
        screenSize = Vector2.new(1280, 720),

        currentTab = "Trade",
        tradeActive = false,
        latestTrade = nil,
        lastTradeSnapshot = nil,
        activeTradeScreen = nil,
        activeOur = nil,
        activeTheirs = nil,
        scheduled = false,
        firstOpen = false,
        prevOther = "",
        warningUntil = 0,
        pendingSuccessId = 0,
        toastId = 0,
        hudCollapsed = false,
        statusText = "Initializing",

        valueSearch = "",
        valueFilter = "All",
        compareA = "Harvester",
        compareB = "Elderwood Scythe",
        invQuery = "",
        invQty = "1",
        serverCategory = "ANY",
        serverPage = 1,
        selectedUrl = ""
    }

    local Data = {
        index = {},
        itemsList = {},
        loaded = false,
        loading = false,
        supremeStamp = "—",
        mm2Stamp = "—",
        supremeStale = true,
        mm2Stale = true,
        lastError = nil,
        listeners = {},
        history = {},
        sightings = {},
        serverStamp = "Fallback directory",
        servers = {
            {number=1,category="ANY",label="Any Ages #1",code="52535878618270720473578279303178"},
            {number=2,category="ANY",label="Any Ages #2",code="54799769711405621473213998836440"},
            {number=3,category="ANY",label="Any Ages #3",code="61933501992546440005599366103766"},
            {number=4,category="ANY",label="Any Ages #4",code="13113133940613962370826214325476"},
            {number=5,category="ANY",label="Any Ages #5",code="63049112374788245951787857306877"},
            {number=6,category="ANY",label="Any Ages #6",code="24132143599835760760738116757946"},
            {number=7,category="ANY",label="Any Ages #7",code="00831528706129916784486944219884"},
            {number=8,category="ANY",label="Any Ages #8",code="84950241111058864425231954137537"},
            {number=9,category="ANY",label="Any Ages #9",code="94528216659379516128229796412065"},
            {number=10,category="ANY",label="Any Ages #10",code="83790563227803528593126440666166"},
            {number=11,category="ANY",label="Any Ages #11",code="96307194810632098115459270158670"},
            {number=12,category="ANY",label="Any Ages #12",code="46966801033871232814565308127808"},
            {number=56,category="AGE",label="9–15 Years #56",code="90246163478876606479670100047019"},
            {number=57,category="AGE",label="9–15 Years #57",code="83367765949007168971266059380186"},
            {number=58,category="AGE",label="9–15 Years #58",code="30573624551302812150126292321731"},
            {number=59,category="AGE",label="9–15 Years #59",code="35628184866192837925469885558481"},
            {number=60,category="AGE",label="9–15 Years #60",code="17302568250702812171846186180666"},
            {number=61,category="AGE",label="9–15 Years #61",code="67302018046903083244956932774414"},
            {number=62,category="AGE",label="9–15 Years #62",code="23017297771776532094192413007181"},
            {number=63,category="AGE",label="15–18 Years #63",code="62640428440367202194173423300127"},
            {number=64,category="AGE",label="15–18 Years #64",code="70528245225099173571462694452389"},
            {number=65,category="AGE",label="15–18 Years #65",code="61839134489251782547262022500361"},
            {number=66,category="AGE",label="15–18 Years #66",code="56578360603812889488354049946918"},
            {number=67,category="AGE",label="15–18 Years #67",code="88336436079327296139003254015359"},
            {number=68,category="AGE",label="18+ Years #68",code="13720925908611970994877786967354"},
            {number=69,category="AGE",label="18+ Years #69",code="96212030266726595022139730075451"},
            {number=70,category="AGE",label="18+ Years #70",code="44443435410913097512979994755706"},
            {number=71,category="HIGH",label="High Tier #71",code="86053937594456769453175779520624"},
            {number=72,category="HIGH",label="High Tier #72",code="79970604585271130742500141932895"},
            {number=73,category="HIGH",label="High Tier #73",code="32229212437077888033955527706962"},
            {number=74,category="HIGH",label="High Tier #74",code="97947436549877227046710097012666"},
            {number=75,category="HIGH",label="High Tier #75",code="35319767785001568708602910095273"}
        }
    }

    local Prefs = {
        animations = true,
        lowPower = false,
        compact = false,
        showTags = true,
        autoQueue = false,
        favs = {},
        recent = {},
        wishlist = {},
        myItems = {},
        hudX = 16,
        hudY = 82,
        btnX = -1,
        btnY = 82
    }

    local UI = {}

    -- Helpers
    local function trim(s)
        return tostring(s or ""):match("^%s*(.-)%s*$")
    end

    local function normalize(s)
        local clean = trim(s):lower()
        clean = clean:gsub("^c%.%s*", "chroma ")
        clean = clean:gsub("^c%s+", "chroma ")
        return clean:gsub("[^%w]", "")
    end

    local function parseNum(v)
        if type(v) == "string" then v = v:gsub(",", "") end
        local n = tonumber(v)
        if n and n >= 0 and n < 10000000000 and n == n then return n end
        return nil
    end

    local function formatVal(n)
        if type(n) ~= "number" then return "—" end
        local absN = math.abs(n)
        local sign = n < 0 and "-" or ""
        local intPart, fracPart
        if absN == math.floor(absN) then
            intPart = string.format("%.0f", absN)
            fracPart = ""
        else
            local s = string.format("%.1f", absN)
            intPart, fracPart = s:match("^(%d+)(%.%d+)$")
        end
        intPart = intPart:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        return sign .. intPart .. fracPart
    end

    local function attach(signal, fn, bucket)
        local okConn, conn = pcall(function() return signal:Connect(fn) end)
        if not okConn or not conn then return nil end
        local bag = bucket or State.conns
        bag[#bag + 1] = conn
        return conn
    end

    local function disconnectBag(bag)
        for i = #bag, 1, -1 do
            pcall(function() bag[i]:Disconnect() end)
            bag[i] = nil
        end
    end

    local function track(obj)
        State.created[#State.created + 1] = obj
        return obj
    end

    local function readJson(s)
        if type(s) ~= "string" or s == "" then return nil end
        local okDec, res = pcall(function() return HttpService:JSONDecode(s) end)
        return okDec and type(res) == "table" and res or nil
    end

    -- File Persistence
    local Store = {}
    function Store.read(path)
        if type(readfile) ~= "function" then return nil end
        if type(isfile) == "function" then
            local okEx, exists = pcall(isfile, path)
            if not okEx or not exists then return nil end
        end
        local okRead, raw = pcall(readfile, path)
        return okRead and readJson(raw) or nil
    end

    function Store.write(path, data)
        if type(writefile) ~= "function" then return false end
        return pcall(function() writefile(path, HttpService:JSONEncode(data)) end)
    end

    function Store.savePrefs()
        Store.write(Config.CONFIG_FILE, Prefs)
    end

    function Store.addHistory(entry)
        table.insert(Data.history, 1, entry)
        while #Data.history > 100 do table.remove(Data.history) end
        Store.write(Config.HISTORY_FILE, Data.history)
    end

    do
        local saved = Store.read(Config.CONFIG_FILE)
        if type(saved) == "table" then
            for k, v in pairs(saved) do
                if type(Prefs[k]) == type(v) then
                    if k == "hudX" or k == "hudY" or k == "btnY" then
                        if v >= 0 and v < 20000 then Prefs[k] = v end
                    elseif k == "btnX" then
                        if v >= -1 and v < 20000 then Prefs[k] = v end
                    else
                        Prefs[k] = v
                    end
                end
            end
        end

        local jobId, placeId = tostring(game.JobId or ""), game.PlaceId
        local sights = Store.read(Config.SIGHTINGS_FILE)
        if type(sights) == "table" then
            for k, item in pairs(sights) do
                if type(k) == "string" and type(item) == "table"
                    and item.jobId == jobId and item.placeId == placeId
                    and type(item.at) == "number" and (os.time() - item.at) < 1800 then
                    Data.sightings[k] = item
                end
            end
        end

        local hist = Store.read(Config.HISTORY_FILE)
        if type(hist) == "table" then
            for i = 1, math.min(#hist, 100) do
                local h = hist[i]
                if type(h) == "table" and type(h.at) == "number" and (h.status == "CONFIRMED" or h.status == "UNCONFIRMED") then
                    Data.history[#Data.history + 1] = h
                end
            end
        end
    end

    -- Data Fetching & Parsing
    local Net = {}
    local reqFn = (type(syn) == "table" and syn.request)
        or (type(http) == "table" and http.request)
        or http_request or request
    if type(reqFn) ~= "function" then reqFn = nil end

    function Net.fetch(url)
        if reqFn then
            local okReq, resp = pcall(reqFn, {Url = url, Method = "GET", Headers = {Accept = "*/*"}})
            if okReq and type(resp) == "table" then
                local status = tonumber(resp.StatusCode or resp.Status or (resp.Success and 200))
                local body = resp.Body or resp.body
                if status == 200 and type(body) == "string" and #body > 0 then return body end
            end
        end
        local okGet, body = pcall(function() return game:HttpGet(url) end)
        return (okGet and type(body) == "string" and #body > 0) and body or nil
    end

    local function csvFields(line)
        local fields, buf, quoted, i = {}, {}, false, 1
        while i <= #line do
            local c = line:sub(i, i)
            if c == '"' then
                if quoted and line:sub(i + 1, i + 1) == '"' then
                    buf[#buf + 1] = '"'
                    i = i + 1
                else
                    quoted = not quoted
                end
            elseif c == "," and not quoted then
                fields[#fields + 1] = table.concat(buf)
                buf = {}
            else
                buf[#buf + 1] = c
            end
            i = i + 1
        end
        if quoted then return nil end
        fields[#fields + 1] = table.concat(buf)
        return fields
    end

    local function parseSupreme(csv)
        if not csv then return nil end
        local data, count, header = {}, 0, true
        for line in (csv .. "\n"):gmatch("(.-)\r?\n") do
            if header then
                header = false
                local cols = csvFields(line)
                if not cols or trim(cols[1]):lower() ~= "name" or trim(cols[3]):lower() ~= "value" then
                    return nil
                end
            elseif line ~= "" then
                local f = csvFields(line)
                if f and #f >= 7 then
                    local name, value = trim(f[1]), parseNum(f[3])
                    if name ~= "" and value then
                        local k = normalize(name)
                        if k ~= "" then
                            data[k] = {
                                name = name,
                                supreme = value,
                                category = trim(f[2]),
                                demand = parseNum(f[4]),
                                rarity = parseNum(f[5]),
                                change = tonumber(f[6]),
                                stability = trim(f[7]),
                                origin = trim(f[8] or "")
                            }
                            count = count + 1
                        end
                    end
                end
            end
        end
        return count >= 10 and data or nil
    end

    local function mergeArchive(index, archive)
        if type(archive) ~= "table" or type(archive.items) ~= "table" or #archive.items < 10 then
            return false
        end
        for _, item in ipairs(archive.items) do
            if type(item) == "table" and type(item.name) == "string" then
                local k = normalize(item.name)
                if k ~= "" then
                    local row = index[k]
                    if not row then
                        row = {name = item.name}
                        index[k] = row
                    end
                    row.mm2 = parseNum(item.mm2)
                    if type(item.aliases) == "table" then
                        for _, alias in ipairs(item.aliases) do
                            local a = normalize(alias)
                            if a ~= "" and not index[a] then index[a] = row end
                        end
                    end
                end
            end
        end
        return true
    end

    local function ageDays(stamp)
        local y, m, d = tostring(stamp or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")
        if not y then return nil end
        local okT, t = pcall(os.time, {year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12})
        return (okT and t) and math.max(0, math.floor((os.time() - t) / 86400)) or nil
    end

    local function rebuildItemsList(index)
        local seen, list = {}, {}
        for _, row in pairs(index) do
            if type(row) == "table" and row.name and not seen[row] then
                seen[row] = true
                list[#list + 1] = row
            end
        end
        table.sort(list, function(a, b)
            local va, vb = a.supreme or a.mm2 or -1, b.supreme or b.mm2 or -1
            if va ~= vb then return va > vb end
            return tostring(a.name) < tostring(b.name)
        end)
        Data.itemsList = list
    end

    local function commitPrices(sup, meta, archive, fromCache)
        if type(sup) ~= "table" then return false end
        local haveSup = next(sup) ~= nil
        local haveMM2 = mergeArchive(sup, archive)
        if not (haveSup or haveMM2) then return false end
        Data.index = sup
        rebuildItemsList(sup)
        Data.loaded = true
        Data.supremeStamp = haveSup and tostring(meta and meta.last_updated or "—"):sub(1, 10) or "Offline"
        Data.mm2Stamp = haveMM2 and tostring(archive.updatedAt or "—"):sub(1, 10) or "Offline"
        local sd, md = ageDays(Data.supremeStamp), ageDays(Data.mm2Stamp)
        Data.supremeStale = (not sd) or sd > 7
        Data.mm2Stale = (not md) or md > 14
        Data.lastError = fromCache and "Offline cache" or (not haveSup and "Supreme unavailable" or nil)
        for _, cb in ipairs(Data.listeners) do pcall(cb) end
        return true
    end

    function Net.readCache()
        local obj = Store.read(Config.PRICE_CACHE)
        if not obj or type(obj.supreme) ~= "string" then return false end
        return commitPrices(parseSupreme(obj.supreme), obj.meta, obj.archive, true)
    end

    function Net.loadPrices()
        if Data.loading or not State.alive then return end
        Data.loading = true
        local csv = Net.fetch(Config.URL_SUPREME)
        local meta = readJson(Net.fetch(Config.URL_META))
        local archive = readJson(Net.fetch(Config.URL_MM2))
        if not archive then
            local old = Store.read(Config.PRICE_CACHE)
            if old then archive = old.archive end
        end
        if not State.alive then Data.loading = false; return end
        local parsed = parseSupreme(csv)
        if not commitPrices(parsed, meta, archive, false) then
            Data.lastError = "Offline — using cached snapshot"
            if not Data.loaded then Net.readCache() end
        else
            if csv then Store.write(Config.PRICE_CACHE, {supreme = csv, meta = meta, archive = archive}) end
        end
        Data.loading = false
        for _, cb in ipairs(Data.listeners) do pcall(cb) end
    end

    local function lookup(name)
        local k = normalize(name)
        if k == "" then return nil end
        local obj = Data.index[k]
        if not obj and k:sub(1, 6) == "chroma" then
            obj = Data.index[k:sub(7) .. "chroma"]
        end
        return obj
    end

    local function safeMM2(row)
        if not row or not row.mm2 then return nil end
        if row.supreme and row.mm2 > 10 and row.supreme > 10 then
            local a, b = math.max(row.mm2, row.supreme), math.min(row.mm2, row.supreme)
            if a / b > 8 then return nil end
        end
        return row.mm2
    end

    -- Primitive UI Constructors
    local function mk(className, props, parent)
        local inst = Instance.new(className)
        for k, v in pairs(props or {}) do inst[k] = v end
        inst.Parent = parent
        return inst
    end

    local function corner(obj, r)
        return mk("UICorner", {CornerRadius = UDim.new(0, r or 8)}, obj)
    end

    local function stroke(obj, color, trans, thickness)
        return mk("UIStroke", {
            Color = color or Palette.hairline,
            Transparency = trans or 0,
            Thickness = thickness or 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        }, obj)
    end

    local function pad(obj, t, r, b, l)
        return mk("UIPadding", {
            PaddingTop = UDim.new(0, t or 0),
            PaddingRight = UDim.new(0, r or t or 0),
            PaddingBottom = UDim.new(0, b or t or 0),
            PaddingLeft = UDim.new(0, l or r or t or 0)
        }, obj)
    end

    local function vlist(obj, gap)
        return mk("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, gap or 8)
        }, obj)
    end

    local function tween(obj, props, dur)
        if not Prefs.animations or Prefs.lowPower then
            for k, v in pairs(props) do pcall(function() obj[k] = v end) end
            return
        end
        pcall(function()
            TweenService:Create(obj, TweenInfo.new(dur or 0.14, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props):Play()
        end)
    end

    local function label(parent, text, props)
        local p = {
            BackgroundTransparency = 1,
            Text = tostring(text or ""),
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextColor3 = Palette.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            BorderSizePixel = 0
        }
        for k, v in pairs(props or {}) do p[k] = v end
        return mk("TextLabel", p, parent)
    end

    local function button(parent, text, style, props, onClick, bucket)
        local isPrimary = style == "primary"
        local isDanger = style == "danger"
        local isGhost = style == "ghost"

        local bg = isPrimary and Palette.accent
            or (isDanger and Palette.negBg
            or (isGhost and Palette.surface or Palette.elevated))
        local bgHover = isPrimary and Color3.fromRGB(255, 255, 255)
            or (isDanger and Color3.fromRGB(68, 32, 36)
            or Palette.hover)
        local fg = isPrimary and Palette.accentFg
            or (isDanger and Palette.neg
            or (isGhost and Palette.subtext or Palette.text))

        local p = {
            Text = tostring(text or ""),
            Font = Enum.Font.GothamMedium,
            TextSize = 11,
            TextColor3 = fg,
            BackgroundColor3 = bg,
            BackgroundTransparency = isGhost and 1 or 0,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Active = true
        }
        for k, v in pairs(props or {}) do p[k] = v end
        local b = mk("TextButton", p, parent)
        corner(b, 7)

        attach(b.MouseEnter, function()
            tween(b, {BackgroundColor3 = bgHover, BackgroundTransparency = 0, TextColor3 = isPrimary and Palette.accentFg or (isDanger and Palette.neg or Palette.text)}, 0.1)
        end, bucket)
        attach(b.MouseLeave, function()
            tween(b, {BackgroundColor3 = bg, BackgroundTransparency = isGhost and 1 or 0, TextColor3 = fg}, 0.12)
        end, bucket)

        if onClick then
            attach(b.MouseButton1Click, function()
                if State.alive then onClick(b) end
            end, bucket)
        end
        return b
    end

    local function inputBox(parent, placeholder, initialText, props)
        local p = {
            Text = tostring(initialText or ""),
            PlaceholderText = tostring(placeholder or ""),
            ClearTextOnFocus = false,
            BackgroundColor3 = Palette.elevated,
            TextColor3 = Palette.text,
            PlaceholderColor3 = Palette.muted,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            BorderSizePixel = 0
        }
        for k, v in pairs(props or {}) do p[k] = v end
        local box = mk("TextBox", p, parent)
        corner(box, 7)
        local st = stroke(box, Palette.hairline, 0, 1)
        pad(box, 0, 10, 0, 10)

        attach(box.Focused, function()
            tween(st, {Color = Palette.focus}, 0.12)
        end)
        attach(box.FocusLost, function()
            tween(st, {Color = Palette.hairline}, 0.12)
        end)
        return box
    end

    local function toggleSwitch(parent, initialState, onToggle, bucket)
        local state = initialState == true
        local trackBtn = mk("TextButton", {
            Size = UDim2.fromOffset(38, 20),
            BackgroundColor3 = state and Palette.accent or Palette.elevated,
            Text = "",
            AutoButtonColor = false,
            BorderSizePixel = 0
        }, parent)
        corner(trackBtn, 10)

        local thumb = mk("Frame", {
            Size = UDim2.fromOffset(14, 14),
            Position = state and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3),
            BackgroundColor3 = state and Palette.accentFg or Palette.subtext,
            BorderSizePixel = 0
        }, trackBtn)
        corner(thumb, 7)

        attach(trackBtn.MouseButton1Click, function()
            if not State.alive then return end
            state = not state
            tween(trackBtn, {BackgroundColor3 = state and Palette.accent or Palette.elevated}, 0.14)
            tween(thumb, {
                Position = state and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3),
                BackgroundColor3 = state and Palette.accentFg or Palette.subtext
            }, 0.14)
            if onToggle then onToggle(state) end
        end, bucket)

        return trackBtn
    end

    local function copyClipboard(str)
        local fn = (type(setclipboard) == "function" and setclipboard)
            or (type(toclipboard) == "function" and toclipboard)
        if type(fn) ~= "function" then return false end
        return pcall(fn, str)
    end

    local function openBrowserUrl(url)
        if type(url) ~= "string" or not url:match("^https://") then return false end
        for _, fn in ipairs({
            type(openurl) == "function" and openurl or false,
            type(open_url) == "function" and open_url or false,
            type(openbrowser) == "function" and openbrowser or false
        }) do
            if type(fn) == "function" then
                local okOpen, res = pcall(fn, url)
                if okOpen and res ~= false then return true end
            end
        end
        return pcall(function() GuiService:OpenBrowserWindow(url) end)
    end

    local function makeDraggable(target, handle, onMoved)
        local activeInput, dragStart, startPos
        local moved = false

        attach(handle.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                activeInput = input
                dragStart = input.Position
                startPos = target.Position
                moved = false
            end
        end)

        attach(UserInputService.InputChanged, function(input)
            if not activeInput or not dragStart or not startPos then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement and input ~= activeInput then return end
            local delta = input.Position - dragStart
            if delta.Magnitude > 4 then moved = true end

            local abs = target.AbsoluteSize
            local maxX = math.max(0, State.screenSize.X - abs.X)
            local maxY = math.max(0, State.screenSize.Y - abs.Y)
            target.Position = UDim2.fromOffset(
                math.clamp(startPos.X.Offset + delta.X, 0, maxX),
                math.clamp(startPos.Y.Offset + delta.Y, 0, maxY)
            )
        end)

        attach(UserInputService.InputEnded, function(input)
            if activeInput and (input == activeInput or input.UserInputType == Enum.UserInputType.MouseButton1) then
                activeInput = nil
                if moved and onMoved then
                    pcall(onMoved, target.Position.X.Offset, target.Position.Y.Offset)
                end
            end
        end)

        return function() return moved end
    end

    -- Root ScreenGui
    UI.root = track(mk("ScreenGui", {
        Name = "MM2CarbonX",
        ResetOnSpawn = false,
        IgnoreGuiInset = false,
        DisplayOrder = 3900,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    }, playerGui))

    -- Minimalist Toast Pill
    UI.toast = mk("Frame", {
        Position = UDim2.new(0.5, -140, 0, 16),
        Size = UDim2.fromOffset(280, 44),
        BackgroundColor3 = Palette.surface,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 90
    }, UI.root)
    corner(UI.toast, 10)
    stroke(UI.toast, Palette.hairline, 0, 1)

    UI.toastDot = mk("Frame", {
        Position = UDim2.fromOffset(14, 18),
        Size = UDim2.fromOffset(8, 8),
        BackgroundColor3 = Palette.pos,
        BorderSizePixel = 0,
        ZIndex = 92
    }, UI.toast)
    corner(UI.toastDot, 4)

    UI.toastTitle = label(UI.toast, "", {
        Position = UDim2.fromOffset(30, 6),
        Size = UDim2.new(1, -40, 0, 16),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        ZIndex = 92
    })
    UI.toastBody = label(UI.toast, "", {
        Position = UDim2.fromOffset(30, 22),
        Size = UDim2.new(1, -40, 0, 15),
        TextSize = 10,
        TextColor3 = Palette.subtext,
        ZIndex = 92
    })

    local function notify(title, body, tint)
        State.toastId = State.toastId + 1
        local id = State.toastId
        UI.toastDot.BackgroundColor3 = tint or Palette.pos
        UI.toastTitle.Text = tostring(title or "Carbon X")
        UI.toastBody.Text = tostring(body or "")
        UI.toast.Visible = true
        if Prefs.animations and not Prefs.lowPower then
            UI.toast.Position = UDim2.new(0.5, -140, 0, 6)
            tween(UI.toast, {Position = UDim2.new(0.5, -140, 0, 16)}, 0.16)
        end
        task.delay(2.4, function()
            if State.alive and State.toastId == id then
                UI.toast.Visible = false
            end
        end)
    end

    -- Floating Launcher Pill
    local startBtnX = Prefs.btnX >= 0 and Prefs.btnX or math.max(16, State.screenSize.X - 126)
    UI.launcher = mk("TextButton", {
        Name = "CarbonLauncher",
        Position = UDim2.fromOffset(startBtnX, Prefs.btnY),
        Size = UDim2.fromOffset(110, 34),
        BackgroundColor3 = Palette.sidebar,
        Text = "",
        AutoButtonColor = false,
        BorderSizePixel = 0,
        ZIndex = 60
    }, UI.root)
    corner(UI.launcher, 17)
    stroke(UI.launcher, Palette.hairline, 0, 1)

    UI.launcherDot = mk("Frame", {
        Position = UDim2.fromOffset(13, 13),
        Size = UDim2.fromOffset(8, 8),
        BackgroundColor3 = Palette.subtext,
        BorderSizePixel = 0,
        ZIndex = 62
    }, UI.launcher)
    corner(UI.launcherDot, 4)

    label(UI.launcher, "Carbon X", {
        Position = UDim2.fromOffset(27, 0),
        Size = UDim2.new(1, -35, 1, 0),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        ZIndex = 62
    })

    local didDragLauncher = makeDraggable(UI.launcher, UI.launcher, function(x, y)
        Prefs.btnX = math.floor(x)
        Prefs.btnY = math.floor(y)
        Store.savePrefs()
    end)

    -- Live Trade HUD (Clean 2-Column Comparison Card)
    UI.hud = mk("Frame", {
        Name = "TradeHUD",
        Position = UDim2.fromOffset(Prefs.hudX, Prefs.hudY),
        Size = UDim2.fromOffset(264, 102),
        BackgroundColor3 = Palette.canvas,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 50
    }, UI.root)
    corner(UI.hud, 10)
    stroke(UI.hud, Palette.hairline, 0, 1)
    UI.hudScale = mk("UIScale", {Scale = 1}, UI.hud)

    UI.hudTopBar = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1,
        Active = true,
        ZIndex = 52
    }, UI.hud)

    UI.hudTitle = label(UI.hudTopBar, "Active Trade", {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -110, 1, 0),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        ZIndex = 53
    })

    UI.hudBadge = label(UI.hudTopBar, "Fair", {
        Position = UDim2.new(1, -96, 0, 6),
        Size = UDim2.fromOffset(62, 20),
        BackgroundTransparency = 0,
        BackgroundColor3 = Palette.elevated,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 53
    })
    corner(UI.hudBadge, 6)

    UI.hudCollapse = button(UI.hudTopBar, "−", "ghost", {
        Position = UDim2.new(1, -30, 0, 5),
        Size = UDim2.fromOffset(22, 22),
        TextSize = 13,
        ZIndex = 53
    }, function()
        State.hudCollapsed = not State.hudCollapsed
        UI.hudBody.Visible = not State.hudCollapsed
        UI.hudCollapse.Text = State.hudCollapsed and "+" or "−"
        if State.hudCollapsed then
            UI.hud.Size = UDim2.fromOffset(264, 32)
        else
            local hasWarn = UI.hudWarnBar.Visible
            UI.hud.Size = UDim2.fromOffset(264, Prefs.compact and 88 or (hasWarn and 126 or 102))
        end
    end)

    UI.hudBody = mk("Frame", {
        Position = UDim2.fromOffset(0, 32),
        Size = UDim2.new(1, 0, 1, -32),
        BackgroundTransparency = 1,
        ZIndex = 52
    }, UI.hud)

    -- Divider line
    mk("Frame", {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -24, 0, 1),
        BackgroundColor3 = Palette.hairline,
        BorderSizePixel = 0,
        ZIndex = 52
    }, UI.hudBody)

    label(UI.hudBody, "You", {
        Position = UDim2.fromOffset(12, 6),
        Size = UDim2.new(0.5, -16, 0, 14),
        TextSize = 10,
        TextColor3 = Palette.subtext,
        ZIndex = 53
    })
    UI.hudYouVal = label(UI.hudBody, "0", {
        Position = UDim2.fromOffset(12, 20),
        Size = UDim2.new(0.5, -16, 0, 22),
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        ZIndex = 53
    })
    UI.hudYouSub = label(UI.hudBody, "MM2: 0", {
        Position = UDim2.fromOffset(12, 42),
        Size = UDim2.new(0.5, -16, 0, 14),
        TextSize = 10,
        TextColor3 = Palette.muted,
        ZIndex = 53
    })

    -- Center vertical hairline
    mk("Frame", {
        Position = UDim2.new(0.5, 0, 0, 8),
        Size = UDim2.fromOffset(1, 46),
        BackgroundColor3 = Palette.hairline,
        BorderSizePixel = 0,
        ZIndex = 52
    }, UI.hudBody)

    label(UI.hudBody, "Them", {
        Position = UDim2.new(0.5, 10, 0, 6),
        Size = UDim2.new(0.5, -22, 0, 14),
        TextSize = 10,
        TextColor3 = Palette.subtext,
        ZIndex = 53
    })
    UI.hudThemVal = label(UI.hudBody, "0", {
        Position = UDim2.new(0.5, 10, 0, 20),
        Size = UDim2.new(0.5, -22, 0, 22),
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        ZIndex = 53
    })
    UI.hudThemSub = label(UI.hudBody, "MM2: 0", {
        Position = UDim2.new(0.5, 10, 0, 42),
        Size = UDim2.new(0.5, -22, 0, 14),
        TextSize = 10,
        TextColor3 = Palette.muted,
        ZIndex = 53
    })

    UI.hudWarnBar = mk("Frame", {
        Position = UDim2.fromOffset(10, 62),
        Size = UDim2.new(1, -20, 0, 22),
        BackgroundColor3 = Palette.warnBg,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 53
    }, UI.hudBody)
    corner(UI.hudWarnBar, 6)
    UI.hudWarnText = label(UI.hudWarnBar, "", {
        Position = UDim2.fromOffset(8, 0),
        Size = UDim2.new(1, -16, 1, 0),
        Font = Enum.Font.GothamMedium,
        TextSize = 10,
        TextColor3 = Palette.warn,
        ZIndex = 54
    })

    makeDraggable(UI.hud, UI.hudTopBar, function(x, y)
        Prefs.hudX = math.floor(x)
        Prefs.hudY = math.floor(y)
        Store.savePrefs()
    end)

    -- Widescreen Main Window (600 x 384)
    local WIN_W, WIN_H = 600, 384
    UI.window = mk("Frame", {
        Name = "Workspace",
        Position = UDim2.fromOffset(
            math.max(12, math.floor((State.screenSize.X - WIN_W) * 0.5)),
            math.max(16, math.floor((State.screenSize.Y - WIN_H) * 0.5))
        ),
        Size = UDim2.fromOffset(WIN_W, WIN_H),
        BackgroundColor3 = Palette.canvas,
        BorderSizePixel = 0,
        Visible = false,
        ClipsDescendants = true,
        ZIndex = 40
    }, UI.root)
    corner(UI.window, 12)
    stroke(UI.window, Palette.hairline, 0, 1)
    UI.windowScale = mk("UIScale", {Scale = 1}, UI.window)

    -- Left Sidebar (146px)
    UI.sidebar = mk("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, 146, 1, 0),
        BackgroundColor3 = Palette.sidebar,
        BorderSizePixel = 0,
        ZIndex = 41
    }, UI.window)

    -- Right-edge hairline separator for sidebar
    mk("Frame", {
        Position = UDim2.new(1, -1, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        BackgroundColor3 = Palette.hairline,
        BorderSizePixel = 0,
        ZIndex = 42
    }, UI.sidebar)

    -- Brand Header (Draggable handle)
    UI.brandDrag = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 56),
        BackgroundTransparency = 1,
        Active = true,
        ZIndex = 43
    }, UI.sidebar)

    local logoMark = mk("Frame", {
        Position = UDim2.fromOffset(16, 17),
        Size = UDim2.fromOffset(22, 22),
        BackgroundColor3 = Palette.accent,
        BorderSizePixel = 0,
        ZIndex = 44
    }, UI.brandDrag)
    corner(logoMark, 6)
    label(logoMark, "C", {
        Size = UDim2.fromScale(1, 1),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = Palette.accentFg,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 45
    })

    label(UI.brandDrag, "Carbon X", {
        Position = UDim2.fromOffset(46, 13),
        Size = UDim2.new(1, -54, 0, 16),
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        ZIndex = 44
    })
    label(UI.brandDrag, "MM2 Companion", {
        Position = UDim2.fromOffset(46, 29),
        Size = UDim2.new(1, -54, 0, 14),
        TextSize = 10,
        TextColor3 = Palette.muted,
        ZIndex = 44
    })

    -- Sidebar Navigation Items
    local NAV_TABS = {"Trade", "Values", "Servers", "Inventory", "History", "Settings"}
    UI.navItems = {}

    local navContainer = mk("Frame", {
        Position = UDim2.fromOffset(10, 62),
        Size = UDim2.new(1, -20, 1, -112),
        BackgroundTransparency = 1,
        ZIndex = 43
    }, UI.sidebar)
    vlist(navContainer, 4)

    for _, tabName in ipairs(NAV_TABS) do
        local btn = mk("TextButton", {
            Name = tabName,
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundColor3 = Palette.elevated,
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            BorderSizePixel = 0,
            ZIndex = 44
        }, navContainer)
        corner(btn, 7)

        local indicator = mk("Frame", {
            Position = UDim2.fromOffset(0, 8),
            Size = UDim2.fromOffset(3, 16),
            BackgroundColor3 = Palette.accent,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 45
        }, btn)
        corner(indicator, 2)

        local lbl = label(btn, tabName, {
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -18, 1, 0),
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextColor3 = Palette.subtext,
            ZIndex = 45
        })

        attach(btn.MouseEnter, function()
            if State.currentTab ~= tabName then
                tween(btn, {BackgroundTransparency = 0.55}, 0.1)
                tween(lbl, {TextColor3 = Palette.text}, 0.1)
            end
        end)
        attach(btn.MouseLeave, function()
            if State.currentTab ~= tabName then
                tween(btn, {BackgroundTransparency = 1}, 0.12)
                tween(lbl, {TextColor3 = Palette.subtext}, 0.12)
            end
        end)

        UI.navItems[tabName] = {btn = btn, indicator = indicator, label = lbl}
    end

    -- Sidebar Bottom Status Pill
    UI.dbDot = mk("Frame", {
        Position = UDim2.fromOffset(16, WIN_H - 28),
        Size = UDim2.fromOffset(7, 7),
        BackgroundColor3 = Palette.warn,
        BorderSizePixel = 0,
        ZIndex = 44
    }, UI.sidebar)
    corner(UI.dbDot, 4)

    UI.dbStatus = label(UI.sidebar, "Syncing values...", {
        Position = UDim2.fromOffset(29, WIN_H - 34),
        Size = UDim2.new(1, -38, 0, 18),
        TextSize = 10,
        TextColor3 = Palette.muted,
        ZIndex = 44
    })

    -- Right Main Content Area
    UI.mainArea = mk("Frame", {
        Position = UDim2.fromOffset(146, 0),
        Size = UDim2.new(1, -146, 1, 0),
        BackgroundTransparency = 1,
        ZIndex = 41
    }, UI.window)

    UI.headerBar = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundTransparency = 1,
        Active = true,
        ZIndex = 42
    }, UI.mainArea)

    UI.pageTitle = label(UI.headerBar, "Trade", {
        Position = UDim2.fromOffset(18, 0),
        Size = UDim2.new(1, -140, 1, 0),
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        ZIndex = 43
    })

    label(UI.headerBar, "RightShift", {
        Position = UDim2.new(1, -112, 0, 14),
        Size = UDim2.fromOffset(64, 20),
        BackgroundTransparency = 0,
        BackgroundColor3 = Palette.surface,
        TextSize = 10,
        TextColor3 = Palette.muted,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 43
    }):FindFirstChildOfClass("UICorner") or corner(UI.headerBar:GetChildren()[#UI.headerBar:GetChildren()], 5)

    button(UI.headerBar, "×", "ghost", {
        Position = UDim2.new(1, -40, 0, 10),
        Size = UDim2.fromOffset(28, 28),
        TextSize = 15,
        ZIndex = 43
    }, function()
        UI.window.Visible = false
    end)

    mk("Frame", {
        Position = UDim2.fromOffset(18, 47),
        Size = UDim2.new(1, -36, 0, 1),
        BackgroundColor3 = Palette.hairline,
        BorderSizePixel = 0,
        ZIndex = 42
    }, UI.mainArea)

    -- Auto-sizing Scrolling Content Viewport
    UI.scroll = mk("ScrollingFrame", {
        Position = UDim2.fromOffset(0, 48),
        Size = UDim2.new(1, 0, 1, -48),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Palette.elevated,
        CanvasSize = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ClipsDescendants = true,
        ZIndex = 42
    }, UI.mainArea)
    pad(UI.scroll, 14, 18, 18, 18)
    vlist(UI.scroll, 10)

    -- Allow dragging the main window from either the sidebar brand header or main top bar
    makeDraggable(UI.window, UI.brandDrag)
    makeDraggable(UI.window, UI.headerBar)

    local function toggleWindow(force)
        if force ~= nil then
            UI.window.Visible = force
        else
            UI.window.Visible = not UI.window.Visible
        end
    end

    attach(UI.launcher.MouseButton1Click, function()
        if didDragLauncher() then return end
        toggleWindow()
    end)

    attach(UserInputService.InputBegan, function(input, processed)
        if processed then return end
        if input.KeyCode == Config.TOGGLE_KEY then
            toggleWindow()
        end
    end)

    local function fitViewport()
        local cam = workspace.CurrentCamera
        if not cam then return end
        local sz = cam.ViewportSize
        if sz.X <= 0 or sz.Y <= 0 then return end
        State.screenSize = sz

        UI.windowScale.Scale = math.clamp(math.min((sz.X - 20) / WIN_W, (sz.Y - 24) / WIN_H), 0.5, 1)
        UI.hudScale.Scale = math.clamp((sz.X - 20) / 264, 0.6, 1)

        if UI.hud.Position.X.Offset > sz.X - 80 or UI.hud.Position.Y.Offset > sz.Y - 40 then
            UI.hud.Position = UDim2.fromOffset(16, math.min(82, sz.Y - 48))
        end
        if UI.launcher.Position.X.Offset > sz.X - 60 or UI.launcher.Position.Y.Offset > sz.Y - 36 then
            UI.launcher.Position = UDim2.fromOffset(math.max(16, sz.X - 126), math.min(82, sz.Y - 44))
        end
    end
    fitViewport()
    if workspace.CurrentCamera then
        attach(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), fitViewport)
    end

    -- Trade Aggregation Helpers
    local function emptySide()
        return {supreme = 0, mm2 = 0, missingSupreme = 0, missingMm2 = 0, items = {}, demandSum = 0, demandCount = 0}
    end

    local function aggregate(items)
        local out = emptySide()
        for _, item in ipairs(items or {}) do
            local cnt = math.clamp(math.floor(tonumber(item.count) or 1), 1, 9999)
            local row = lookup(item.name)
            local s = row and row.supreme
            local m = safeMM2(row)
            out.items[#out.items + 1] = {
                name = item.name,
                count = cnt,
                s = s,
                m = m,
                demand = row and row.demand
            }
            if s then out.supreme = out.supreme + s * cnt else out.missingSupreme = out.missingSupreme + cnt end
            if m then out.mm2 = out.mm2 + m * cnt else out.missingMm2 = out.missingMm2 + cnt end
            if row and row.demand then
                out.demandSum = out.demandSum + row.demand * cnt
                out.demandCount = out.demandCount + cnt
            end
        end
        return out
    end

    local function diffSummary(own, theirs, source)
        local missingKey = (source == "supreme") and "missingSupreme" or "missingMm2"
        if not own or not theirs or (own[missingKey] or 0) > 0 or (theirs[missingKey] or 0) > 0 then
            return "Unknown", nil
        end
        local n = theirs[source] - own[source]
        local p = (own[source] > 0) and (100 * n / own[source]) or nil
        local str = (n > 0 and "+" or "") .. formatVal(n) .. (p and (" (" .. string.format("%+.1f", p) .. "%)") or "")
        return str, n
    end

    local function displayNumber(n, missing)
        if (missing or 0) > 0 then return formatVal(n) .. "+?" end
        return formatVal(n)
    end

    local setTab, renderTrade, renderValues, renderServers, renderInventory, renderHistory, renderSettings

    local function updateLiveTradeCard()
        local refs = UI.tradeRefs
        if not refs then return end
        local active = State.tradeActive and State.latestTrade ~= nil
        local own = active and State.latestTrade.you or emptySide()
        local other = active and State.latestTrade.them or emptySide()

        refs.ownVal.Text = active and displayNumber(own.supreme, own.missingSupreme) or "—"
        refs.otherVal.Text = active and displayNumber(other.supreme, other.missingSupreme) or "—"
        refs.ownSub.Text = active and ("MM2: " .. displayNumber(own.mm2, own.missingMm2)) or "Waiting for trade"
        refs.otherSub.Text = active and ("MM2: " .. displayNumber(other.mm2, other.missingMm2)) or "Waiting for trade"

        local supStr, delta = diffSummary(own, other, "supreme")
        refs.deltaLabel.Text = active and ("Difference: " .. supStr) or "No active trade session"
        refs.deltaLabel.TextColor3 = not active and Palette.subtext
            or (delta and (delta > 0 and Palette.pos or (delta < 0 and Palette.neg or Palette.subtext)) or Palette.warn)

        local demand = (other.demandCount > 0) and (other.demandSum / other.demandCount) or nil
        refs.demandLabel.Text = demand and ("Demand " .. string.format("%.1f/10", demand)) or ""

        if os.clock() < State.warningUntil then
            refs.alertBanner.Visible = true
        else
            refs.alertBanner.Visible = false
        end
    end

    -- TAB 1: TRADE & INSTANT COMPARE
    renderTrade = function()
        local card = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 126),
            BackgroundColor3 = Palette.surface,
            BorderSizePixel = 0,
            LayoutOrder = 1,
            ZIndex = 43
        }, UI.scroll)
        corner(card, 10)

        label(card, "Your Offer", {
            Position = UDim2.fromOffset(14, 10),
            Size = UDim2.new(0.5, -20, 0, 14),
            TextSize = 11,
            TextColor3 = Palette.subtext,
            ZIndex = 44
        })
        local ownVal = label(card, "—", {
            Position = UDim2.fromOffset(14, 26),
            Size = UDim2.new(0.5, -20, 0, 28),
            Font = Enum.Font.GothamBold,
            TextSize = 22,
            ZIndex = 44
        })
        local ownSub = label(card, "Waiting for trade", {
            Position = UDim2.fromOffset(14, 56),
            Size = UDim2.new(0.5, -20, 0, 14),
            TextSize = 10,
            TextColor3 = Palette.muted,
            ZIndex = 44
        })

        mk("Frame", {
            Position = UDim2.new(0.5, 0, 0, 12),
            Size = UDim2.fromOffset(1, 58),
            BackgroundColor3 = Palette.hairline,
            BorderSizePixel = 0,
            ZIndex = 44
        }, card)

        label(card, "Their Offer", {
            Position = UDim2.new(0.5, 14, 0, 10),
            Size = UDim2.new(0.5, -26, 0, 14),
            TextSize = 11,
            TextColor3 = Palette.subtext,
            ZIndex = 44
        })
        local otherVal = label(card, "—", {
            Position = UDim2.new(0.5, 14, 0, 26),
            Size = UDim2.new(0.5, -26, 0, 28),
            Font = Enum.Font.GothamBold,
            TextSize = 22,
            ZIndex = 44
        })
        local otherSub = label(card, "Waiting for trade", {
            Position = UDim2.new(0.5, 14, 0, 56),
            Size = UDim2.new(0.5, -26, 0, 14),
            TextSize = 10,
            TextColor3 = Palette.muted,
            ZIndex = 44
        })

        mk("Frame", {
            Position = UDim2.fromOffset(14, 80),
            Size = UDim2.new(1, -28, 0, 1),
            BackgroundColor3 = Palette.hairline,
            BorderSizePixel = 0,
            ZIndex = 44
        }, card)

        local deltaLabel = label(card, "No active trade session", {
            Position = UDim2.fromOffset(14, 88),
            Size = UDim2.new(1, -110, 0, 26),
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextColor3 = Palette.subtext,
            ZIndex = 44
        })

        local demandLabel = label(card, "", {
            Position = UDim2.new(1, -104, 0, 88),
            Size = UDim2.fromOffset(90, 26),
            TextSize = 11,
            TextColor3 = Palette.muted,
            TextXAlignment = Enum.TextXAlignment.Right,
            ZIndex = 44
        })

        local alertBanner = mk("Frame", {
            Position = UDim2.fromOffset(12, 86),
            Size = UDim2.new(1, -24, 0, 28),
            BackgroundColor3 = Palette.negBg,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 46
        }, card)
        corner(alertBanner, 6)
        label(alertBanner, "Partner modified offer — verify items before accepting", {
            Position = UDim2.fromOffset(10, 0),
            Size = UDim2.new(1, -20, 1, 0),
            Font = Enum.Font.GothamMedium,
            TextSize = 11,
            TextColor3 = Palette.neg,
            ZIndex = 47
        })

        UI.tradeRefs = {
            ownVal = ownVal, ownSub = ownSub,
            otherVal = otherVal, otherSub = otherSub,
            deltaLabel = deltaLabel, demandLabel = demandLabel,
            alertBanner = alertBanner
        }
        updateLiveTradeCard()

        -- Quick 1v1 Calculator Card
        local calc = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 146),
            BackgroundColor3 = Palette.surface,
            BorderSizePixel = 0,
            LayoutOrder = 2,
            ZIndex = 43
        }, UI.scroll)
        corner(calc, 10)

        label(calc, "Quick Compare", {
            Position = UDim2.fromOffset(14, 10),
            Size = UDim2.new(1, -28, 0, 18),
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            ZIndex = 44
        })

        local boxA = inputBox(calc, "Your item (e.g. Harvester)", State.compareA, {
            Position = UDim2.fromOffset(14, 34),
            Size = UDim2.new(0.5, -19, 0, 32),
            ZIndex = 44
        })
        local boxB = inputBox(calc, "Their item (e.g. c luger)", State.compareB, {
            Position = UDim2.new(0.5, 5, 0, 34),
            Size = UDim2.new(0.5, -19, 0, 32),
            ZIndex = 44
        })

        local resLine = label(calc, "", {
            Position = UDim2.fromOffset(14, 74),
            Size = UDim2.new(1, -28, 0, 20),
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            ZIndex = 44
        })

        local function updateCalc()
            State.compareA = trim(boxA.Text)
            State.compareB = trim(boxB.Text)
            local a, b = lookup(State.compareA), lookup(State.compareB)
            local va, vb = a and a.supreme, b and b.supreme
            local na = a and a.name or (State.compareA ~= "" and State.compareA or "Item A")
            local nb = b and b.name or (State.compareB ~= "" and State.compareB or "Item B")

            if va and vb then
                local diff = vb - va
                local verdict = diff > 0 and ("Win +" .. formatVal(diff))
                    or (diff < 0 and ("Loss " .. formatVal(diff)) or "Fair trade")
                resLine.Text = na .. " (" .. formatVal(va) .. ")  →  " .. nb .. " (" .. formatVal(vb) .. ")   ·   " .. verdict
                resLine.TextColor3 = diff > 0 and Palette.pos or (diff < 0 and Palette.neg or Palette.subtext)
            else
                resLine.Text = na .. " (" .. formatVal(va) .. ")  vs  " .. nb .. " (" .. formatVal(vb) .. ")"
                resLine.TextColor3 = Palette.subtext
            end
        end

        attach(boxA:GetPropertyChangedSignal("Text"), updateCalc, State.tabConns)
        attach(boxB:GetPropertyChangedSignal("Text"), updateCalc, State.tabConns)
        updateCalc()

        button(calc, "Swap", "secondary", {
            Position = UDim2.fromOffset(14, 104),
            Size = UDim2.fromOffset(76, 28),
            ZIndex = 44
        }, function()
            local tmp = boxA.Text
            boxA.Text = boxB.Text
            boxB.Text = tmp
            updateCalc()
        end, State.tabConns)

        button(calc, "Watch Item A", "secondary", {
            Position = UDim2.fromOffset(98, 104),
            Size = UDim2.fromOffset(104, 28),
            ZIndex = 44
        }, function()
            local row = lookup(trim(boxA.Text))
            local target = row and row.name or trim(boxA.Text)
            if target ~= "" and #target < 80 then
                Prefs.wishlist[normalize(target)] = target
                Store.savePrefs()
                notify("Added to watchlist", target)
            end
        end, State.tabConns)

        button(calc, "Browse Values", "primary", {
            Position = UDim2.new(1, -122, 0, 104),
            Size = UDim2.fromOffset(108, 28),
            ZIndex = 44
        }, function()
            setTab("Values")
        end, State.tabConns)
    end

    -- TAB 2: ITEM VALUES BROWSER
    renderValues = function()
        local searchRow = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundTransparency = 1,
            LayoutOrder = 1,
            ZIndex = 43
        }, UI.scroll)

        local searchBox = inputBox(searchRow, "Search skin name (e.g. harvester, c luger, candy)...", State.valueSearch, {
            Size = UDim2.new(1, -72, 1, 0),
            ZIndex = 44
        })

        button(searchRow, "Clear", "secondary", {
            Position = UDim2.new(1, -64, 0, 0),
            Size = UDim2.fromOffset(64, 32),
            ZIndex = 44
        }, function()
            State.valueSearch = ""
            searchBox.Text = ""
        end, State.tabConns)

        -- Segmented Category Bar
        local segBar = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = Palette.surface,
            BorderSizePixel = 0,
            LayoutOrder = 2,
            ZIndex = 43
        }, UI.scroll)
        corner(segBar, 8)
        pad(segBar, 3)
        mk("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 3)
        }, segBar)

        local cats = {"All", "Weapons", "Chromas", "Pets", "Sets", "Saved"}
        for _, cat in ipairs(cats) do
            local active = State.valueFilter == cat
            button(segBar, cat, active and "primary" or "ghost", {
                Size = UDim2.new(1 / #cats, -3, 1, 0),
                TextSize = 10,
                ZIndex = 44
            }, function()
                State.valueFilter = cat
                setTab("Values")
            end, State.tabConns)
        end

        local metaLine = label(UI.scroll, "", {
            Size = UDim2.new(1, 0, 0, 16),
            TextSize = 11,
            TextColor3 = Palette.muted,
            LayoutOrder = 3,
            ZIndex = 43
        })

        local listWrap = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            LayoutOrder = 4,
            ZIndex = 43
        }, UI.scroll)
        vlist(listWrap, 6)

        local function rebuild()
            for _, ch in ipairs(listWrap:GetChildren()) do
                if not ch:IsA("UIListLayout") then ch:Destroy() end
            end

            local qRaw = trim(State.valueSearch):lower()
            local qNorm = normalize(qRaw)
            local matched = {}

            for _, item in ipairs(Data.itemsList) do
                local nLow = item.name:lower()
                local cLow = tostring(item.category or ""):lower()
                local isChroma = nLow:find("chroma", 1, true) ~= nil
                local isPet = cLow:find("pet", 1, true) ~= nil
                local isSet = cLow:find("set", 1, true) ~= nil
                local isSaved = Prefs.wishlist[normalize(item.name)] ~= nil

                local okCat = (State.valueFilter == "All")
                    or (State.valueFilter == "Chromas" and isChroma)
                    or (State.valueFilter == "Pets" and isPet)
                    or (State.valueFilter == "Sets" and isSet)
                    or (State.valueFilter == "Weapons" and not isPet and not isSet)
                    or (State.valueFilter == "Saved" and isSaved)

                if okCat and (qNorm == "" or nLow:find(qRaw, 1, true) or normalize(item.name):find(qNorm, 1, true)) then
                    matched[#matched + 1] = item
                end
            end

            local limit = math.min(#matched, 35)
            metaLine.Text = Data.loaded
                and ("Showing " .. limit .. " of " .. #matched .. " items")
                or "Loading item database..."

            for i = 1, limit do
                local item = matched[i]
                local key = normalize(item.name)
                local saved = Prefs.wishlist[key] ~= nil

                local row = mk("Frame", {
                    Size = UDim2.new(1, 0, 0, 48),
                    BackgroundColor3 = Palette.surface,
                    BorderSizePixel = 0,
                    LayoutOrder = i,
                    ZIndex = 44
                }, listWrap)
                corner(row, 8)

                label(row, item.name, {
                    Position = UDim2.fromOffset(12, 6),
                    Size = UDim2.new(1, -210, 0, 18),
                    Font = Enum.Font.GothamMedium,
                    TextSize = 12,
                    ZIndex = 45
                })

                local subParts = {}
                if item.category and item.category ~= "" then subParts[#subParts + 1] = item.category end
                if item.demand then subParts[#subParts + 1] = "Demand " .. formatVal(item.demand) .. "/10" end
                if item.stability and item.stability ~= "" then subParts[#subParts + 1] = item.stability end

                label(row, #subParts > 0 and table.concat(subParts, "  ·  ") or "Standard item", {
                    Position = UDim2.fromOffset(12, 25),
                    Size = UDim2.new(1, -210, 0, 15),
                    TextSize = 10,
                    TextColor3 = Palette.muted,
                    ZIndex = 45
                })

                -- Value block
                label(row, formatVal(item.supreme), {
                    Position = UDim2.new(1, -196, 0, 6),
                    Size = UDim2.fromOffset(74, 18),
                    Font = Enum.Font.GothamBold,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    ZIndex = 45
                })
                label(row, "MM2 " .. formatVal(safeMM2(item)), {
                    Position = UDim2.new(1, -196, 0, 25),
                    Size = UDim2.fromOffset(74, 15),
                    TextSize = 10,
                    TextColor3 = Palette.muted,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    ZIndex = 45
                })

                button(row, saved and "Saved" or "Save", saved and "primary" or "secondary", {
                    Position = UDim2.new(1, -112, 0, 10),
                    Size = UDim2.fromOffset(50, 28),
                    TextSize = 10,
                    ZIndex = 45
                }, function(b)
                    if Prefs.wishlist[key] then
                        Prefs.wishlist[key] = nil
                        b.Text = "Save"
                        notify("Removed from watchlist", item.name, Palette.subtext)
                    else
                        Prefs.wishlist[key] = item.name
                        b.Text = "Saved"
                        notify("Added to watchlist", item.name)
                    end
                    Store.savePrefs()
                end, State.tabConns)

                button(row, "+Inv", "secondary", {
                    Position = UDim2.new(1, -56, 0, 10),
                    Size = UDim2.fromOffset(46, 28),
                    TextSize = 10,
                    ZIndex = 45
                }, function()
                    local prev = type(Prefs.myItems[key]) == "table" and tonumber(Prefs.myItems[key].count) or 0
                    Prefs.myItems[key] = {name = item.name, count = math.min(9999, prev + 1)}
                    Store.savePrefs()
                    notify("Added to inventory", item.name .. " (×" .. (prev + 1) .. ")")
                end, State.tabConns)
            end

            if limit == 0 and Data.loaded then
                label(listWrap, "No items match your search.", {
                    Size = UDim2.new(1, 0, 0, 28),
                    TextSize = 11,
                    TextColor3 = Palette.muted,
                    ZIndex = 44
                })
            end
        end

        attach(searchBox:GetPropertyChangedSignal("Text"), function()
            State.valueSearch = searchBox.Text
            rebuild()
        end, State.tabConns)

        rebuild()
    end

    -- TAB 3: SERVERS HUB
    local function serverKey(s) return tostring(s.number) end
    local function isFavServer(s) return Prefs.favs[serverKey(s)] == true end

    local function getFilteredServers()
        local out = {}
        if State.serverCategory == "RECENT" then
            for _, id in ipairs(Prefs.recent) do
                for _, s in ipairs(Data.servers) do
                    if serverKey(s) == tostring(id) then out[#out + 1] = s; break end
                end
            end
            return out
        end
        for _, s in ipairs(Data.servers) do
            local match = (State.serverCategory == "ANY" and s.category == "ANY")
                or (State.serverCategory == "AGE" and s.category == "AGE")
                or (State.serverCategory == "HIGH" and s.category == "HIGH")
                or (State.serverCategory == "FAV" and isFavServer(s))
            if match then out[#out + 1] = s end
        end
        return out
    end

    local function syncServers()
        local html = Net.fetch(Config.OFFICIAL_SITE)
        if not State.alive or type(html) ~= "string" then
            notify("Sync unavailable", "Using cached server links", Palette.warn)
            return
        end
        local items, used = {}, {}
        for tag, inside in html:gmatch("(<a[%s][^>]->)(.-)</a>") do
            local href = tag:match('href%s*=%s*"([^"]+)"') or tag:match("href%s*=%s*'([^']+)'")
            if href and href:find("privateServerLinkCode=", 1, true) then
                href = href:gsub("&amp;", "&")
                local code = href:match("privateServerLinkCode=([%d]+)")
                local no = tonumber(inside:match("%[#(%d+)%]"))
                if no and no >= 1 and no <= 200 and code and #code == 32 and not used[no] then
                    local cat = no >= 71 and "HIGH" or (no >= 56 and "AGE" or "ANY")
                    items[#items + 1] = {
                        number = no,
                        category = cat,
                        code = code,
                        label = (cat == "HIGH" and "High Tier #" or (cat == "AGE" and "Age Group #" or "Any Ages #")) .. no
                    }
                    used[no] = true
                end
            end
        end
        if #items >= 10 then
            table.sort(items, function(a, b) return a.number < b.number end)
            Data.servers = items
            Data.serverStamp = os.date("!%H:%M UTC")
            notify("Servers synced", tostring(#items) .. " active private links")
            if UI.window.Visible and State.currentTab == "Servers" then setTab("Servers") end
        else
            notify("Sync fallback", "Using stored links", Palette.warn)
        end
    end

    renderServers = function()
        local segBar = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = Palette.surface,
            BorderSizePixel = 0,
            LayoutOrder = 1,
            ZIndex = 43
        }, UI.scroll)
        corner(segBar, 8)
        pad(segBar, 3)
        mk("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 3)
        }, segBar)

        local tabs = {{"ANY", "Any Ages"}, {"AGE", "Age Groups"}, {"HIGH", "High Tier"}, {"FAV", "Saved"}, {"RECENT", "Recent"}}
        for _, info in ipairs(tabs) do
            local active = State.serverCategory == info[1]
            button(segBar, info[2], active and "primary" or "ghost", {
                Size = UDim2.new(1 / #tabs, -3, 1, 0),
                TextSize = 10,
                ZIndex = 44
            }, function()
                State.serverCategory = info[1]
                State.serverPage = 1
                setTab("Servers")
            end, State.tabConns)
        end

        local list = getFilteredServers()
        local perPage = 3
        local maxPage = math.max(1, math.ceil(#list / perPage))
        State.serverPage = math.clamp(State.serverPage, 1, maxPage)

        local inviteBox
        for i = 1, perPage do
            local s = list[(State.serverPage - 1) * perPage + i]
            if s then
                local row = mk("Frame", {
                    Size = UDim2.new(1, 0, 0, 48),
                    BackgroundColor3 = Palette.surface,
                    BorderSizePixel = 0,
                    LayoutOrder = 1 + i,
                    ZIndex = 43
                }, UI.scroll)
                corner(row, 8)

                label(row, s.label, {
                    Position = UDim2.fromOffset(12, 6),
                    Size = UDim2.new(1, -140, 0, 18),
                    Font = Enum.Font.GothamMedium,
                    TextSize = 12,
                    ZIndex = 44
                })
                label(row, s.category == "HIGH" and "High-tier rules apply" or "Supreme trading lobby", {
                    Position = UDim2.fromOffset(12, 25),
                    Size = UDim2.new(1, -140, 0, 15),
                    TextSize = 10,
                    TextColor3 = Palette.muted,
                    ZIndex = 44
                })

                local fav = isFavServer(s)
                button(row, fav and "Saved" or "Save", fav and "primary" or "secondary", {
                    Position = UDim2.new(1, -124, 0, 10),
                    Size = UDim2.fromOffset(52, 28),
                    TextSize = 10,
                    ZIndex = 44
                }, function()
                    Prefs.favs[serverKey(s)] = not fav or nil
                    Store.savePrefs()
                    setTab("Servers")
                end, State.tabConns)

                button(row, "Join", "primary", {
                    Position = UDim2.new(1, -66, 0, 10),
                    Size = UDim2.fromOffset(56, 28),
                    TextSize = 11,
                    ZIndex = 44
                }, function()
                    local url = Config.JOIN_PREFIX .. tostring(s.code)
                    State.selectedUrl = url
                    if inviteBox then inviteBox.Text = url end
                    for idx = #Prefs.recent, 1, -1 do
                        if tostring(Prefs.recent[idx]) == serverKey(s) then table.remove(Prefs.recent, idx) end
                    end
                    table.insert(Prefs.recent, 1, serverKey(s))
                    while #Prefs.recent > 12 do table.remove(Prefs.recent) end
                    Store.savePrefs()

                    local opened = openBrowserUrl(url)
                    local copied = copyClipboard(url)
                    notify(opened and "Opening Roblox" or (copied and "Invite link copied" or "Link ready"), s.label)
                end, State.tabConns)
            end
        end

        if #list == 0 then
            label(UI.scroll, "No servers in this category.", {
                Size = UDim2.new(1, 0, 0, 28),
                TextSize = 11,
                TextColor3 = Palette.muted,
                LayoutOrder = 2,
                ZIndex = 43
            })
        end

        -- Pagination & Actions Row
        local navRow = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundTransparency = 1,
            LayoutOrder = 10,
            ZIndex = 43
        }, UI.scroll)

        button(navRow, "Prev", "secondary", {
            Size = UDim2.fromOffset(64, 28),
            ZIndex = 44
        }, function()
            State.serverPage = math.max(1, State.serverPage - 1)
            setTab("Servers")
        end, State.tabConns)

        label(navRow, "Page " .. State.serverPage .. " of " .. maxPage .. "  (" .. Data.serverStamp .. ")", {
            Position = UDim2.fromOffset(70, 0),
            Size = UDim2.new(1, -140, 1, 0),
            TextSize = 11,
            TextColor3 = Palette.subtext,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 44
        })

        button(navRow, "Next", "secondary", {
            Position = UDim2.new(1, -64, 0, 0),
            Size = UDim2.fromOffset(64, 28),
            ZIndex = 44
        }, function()
            State.serverPage = math.min(maxPage, State.serverPage + 1)
            setTab("Servers")
        end, State.tabConns)

        -- Link Share & Sync Row
        local linkRow = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            LayoutOrder = 11,
            ZIndex = 43
        }, UI.scroll)

        inviteBox = inputBox(linkRow, "Click Join on a server to copy invite link", State.selectedUrl, {
            Size = UDim2.new(1, -138, 1, 0),
            TextSize = 11,
            ZIndex = 44
        })

        button(linkRow, "Copy", "primary", {
            Position = UDim2.new(1, -132, 0, 0),
            Size = UDim2.fromOffset(62, 30),
            ZIndex = 44
        }, function()
            local u = trim(inviteBox.Text)
            if u ~= "" then
                notify(copyClipboard(u) and "Copied to clipboard" or "Copy failed", u:sub(1, 44))
            end
        end, State.tabConns)

        button(linkRow, "Sync", "secondary", {
            Position = UDim2.new(1, -64, 0, 0),
            Size = UDim2.fromOffset(64, 30),
            ZIndex = 44
        }, function()
            notify("Syncing directory", "Checking Supreme servers...")
            task.spawn(syncServers)
        end, State.tabConns)

        -- Rare sightings in current server
        local found = {}
        for _, entry in pairs(Data.sightings) do
            if os.time() - entry.at < 3600 then found[#found + 1] = entry end
        end
        if #found > 0 then
            table.sort(found, function(a, b) return a.value > b.value end)
            local sCard = mk("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = Palette.surface,
                BorderSizePixel = 0,
                LayoutOrder = 12,
                ZIndex = 43
            }, UI.scroll)
            corner(sCard, 8)
            pad(sCard, 10, 12, 10, 12)
            vlist(sCard, 4)

            label(sCard, "Spotted in current lobby", {
                Size = UDim2.new(1, 0, 0, 16),
                Font = Enum.Font.GothamBold,
                TextSize = 11,
                TextColor3 = Palette.subtext,
                ZIndex = 44
            })
            for i = 1, math.min(4, #found) do
                local it = found[i]
                label(sCard, it.name .. "  ·  " .. formatVal(it.value) .. " (" .. it.source .. ")", {
                    Size = UDim2.new(1, 0, 0, 16),
                    TextSize = 11,
                    ZIndex = 44
                })
            end
        end
    end

    -- TAB 4: INVENTORY & WATCHLIST
    renderInventory = function()
        local rows = {}
        for k, it in pairs(Prefs.myItems) do
            if type(it) == "table" and type(it.name) == "string" and type(it.count) == "number" and it.count > 0 then
                rows[#rows + 1] = {key = k, name = it.name, count = it.count}
            end
        end
        table.sort(rows, function(a, b)
            local ra, rb = lookup(a.name), lookup(b.name)
            return ((ra and ra.supreme) or -1) * a.count > ((rb and rb.supreme) or -1) * b.count
        end)

        local sums = aggregate(rows)
        local hero = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 62),
            BackgroundColor3 = Palette.surface,
            BorderSizePixel = 0,
            LayoutOrder = 1,
            ZIndex = 43
        }, UI.scroll)
        corner(hero, 10)

        label(hero, "Portfolio Value  ·  " .. #rows .. " unique", {
            Position = UDim2.fromOffset(14, 9),
            Size = UDim2.new(1, -90, 0, 14),
            TextSize = 11,
            TextColor3 = Palette.subtext,
            ZIndex = 44
        })
        label(hero, formatVal(sums.supreme) .. " Supreme   ·   " .. formatVal(sums.mm2) .. " MM2", {
            Position = UDim2.fromOffset(14, 27),
            Size = UDim2.new(1, -90, 0, 24),
            Font = Enum.Font.GothamBold,
            TextSize = 16,
            TextColor3 = Palette.pos,
            ZIndex = 44
        })

        if #rows > 0 then
            button(hero, "Clear", "danger", {
                Position = UDim2.new(1, -68, 0, 17),
                Size = UDim2.fromOffset(54, 28),
                TextSize = 10,
                ZIndex = 44
            }, function()
                Prefs.myItems = {}
                Store.savePrefs()
                setTab("Inventory")
            end, State.tabConns)
        end

        -- Add Item Bar
        local addRow = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundTransparency = 1,
            LayoutOrder = 2,
            ZIndex = 43
        }, UI.scroll)

        local nameBox = inputBox(addRow, "Skin name (e.g. Harvester)", State.invQuery, {
            Size = UDim2.new(1, -138, 1, 0),
            ZIndex = 44
        })
        local qtyBox = inputBox(addRow, "Qty", State.invQty, {
            Position = UDim2.new(1, -132, 0, 0),
            Size = UDim2.fromOffset(54, 32),
            ZIndex = 44
        })

        button(addRow, "Add", "primary", {
            Position = UDim2.new(1, -72, 0, 0),
            Size = UDim2.fromOffset(72, 32),
            ZIndex = 44
        }, function()
            State.invQuery = trim(nameBox.Text)
            State.invQty = trim(qtyBox.Text)
            local qty = tonumber(State.invQty)
            if #State.invQuery < 2 or not qty or qty < 1 or qty > 999 or qty ~= math.floor(qty) then
                notify("Invalid entry", "Specify item name and quantity (1–999)", Palette.warn)
                return
            end
            local row = lookup(State.invQuery)
            if not row then
                notify("Item not found", "Check spelling in Values tab", Palette.warn)
                return
            end
            local k = normalize(row.name)
            local prev = type(Prefs.myItems[k]) == "table" and tonumber(Prefs.myItems[k].count) or 0
            Prefs.myItems[k] = {name = row.name, count = math.min(9999, prev + qty)}
            Store.savePrefs()
            setTab("Inventory")
        end, State.tabConns)

        for i = 1, math.min(#rows, 20) do
            local item = rows[i]
            local row = lookup(item.name)
            local card = mk("Frame", {
                Size = UDim2.new(1, 0, 0, 44),
                BackgroundColor3 = Palette.surface,
                BorderSizePixel = 0,
                LayoutOrder = 10 + i,
                ZIndex = 43
            }, UI.scroll)
            corner(card, 8)

            label(card, item.name .. "  ×" .. item.count, {
                Position = UDim2.fromOffset(12, 5),
                Size = UDim2.new(1, -130, 0, 17),
                Font = Enum.Font.GothamMedium,
                TextSize = 12,
                ZIndex = 44
            })
            label(card, "Total: " .. formatVal((row and row.supreme or 0) * item.count) .. " Supreme", {
                Position = UDim2.fromOffset(12, 23),
                Size = UDim2.new(1, -130, 0, 14),
                TextSize = 10,
                TextColor3 = Palette.muted,
                ZIndex = 44
            })

            button(card, "−", "secondary", {
                Position = UDim2.new(1, -110, 0, 8),
                Size = UDim2.fromOffset(28, 28),
                TextSize = 13,
                ZIndex = 44
            }, function()
                local cur = Prefs.myItems[item.key]
                if cur then
                    cur.count = cur.count - 1
                    if cur.count <= 0 then Prefs.myItems[item.key] = nil end
                end
                Store.savePrefs()
                setTab("Inventory")
            end, State.tabConns)

            button(card, "+", "secondary", {
                Position = UDim2.new(1, -76, 0, 8),
                Size = UDim2.fromOffset(28, 28),
                TextSize = 13,
                ZIndex = 44
            }, function()
                Prefs.myItems[item.key].count = math.min(9999, item.count + 1)
                Store.savePrefs()
                setTab("Inventory")
            end, State.tabConns)

            button(card, "×", "danger", {
                Position = UDim2.new(1, -40, 0, 8),
                Size = UDim2.fromOffset(28, 28),
                TextSize = 13,
                ZIndex = 44
            }, function()
                Prefs.myItems[item.key] = nil
                Store.savePrefs()
                setTab("Inventory")
            end, State.tabConns)
        end

        if #rows == 0 then
            label(UI.scroll, "No items in portfolio yet.", {
                Size = UDim2.new(1, 0, 0, 22),
                TextSize = 11,
                TextColor3 = Palette.muted,
                LayoutOrder = 10,
                ZIndex = 43
            })
        end

        -- Watchlist Section
        local wishes = {}
        for k, name in pairs(Prefs.wishlist) do
            if type(k) == "string" and type(name) == "string" then
                wishes[#wishes + 1] = {key = k, name = name}
            end
        end
        table.sort(wishes, function(a, b) return a.name < b.name end)

        label(UI.scroll, "Watchlist (" .. #wishes .. ")", {
            Size = UDim2.new(1, 0, 0, 20),
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = Palette.subtext,
            LayoutOrder = 40,
            ZIndex = 43
        })

        for i = 1, math.min(12, #wishes) do
            local w = wishes[i]
            local r = lookup(w.name)
            local wc = mk("Frame", {
                Size = UDim2.new(1, 0, 0, 34),
                BackgroundColor3 = Palette.surface,
                BorderSizePixel = 0,
                LayoutOrder = 40 + i,
                ZIndex = 43
            }, UI.scroll)
            corner(wc, 7)

            label(wc, w.name .. "   ·   " .. formatVal(r and r.supreme) .. " Supreme", {
                Position = UDim2.fromOffset(12, 0),
                Size = UDim2.new(1, -50, 1, 0),
                TextSize = 11,
                ZIndex = 44
            })
            button(wc, "×", "ghost", {
                Position = UDim2.new(1, -34, 0, 3),
                Size = UDim2.fromOffset(28, 28),
                TextSize = 13,
                ZIndex = 44
            }, function()
                Prefs.wishlist[w.key] = nil
                Store.savePrefs()
                setTab("Inventory")
            end, State.tabConns)
        end
    end

    -- TAB 5: TRADE HISTORY
    renderHistory = function()
        local confirmedCount, profit, loss, net = 0, 0, 0, 0
        for _, h in ipairs(Data.history) do
            if h.status == "CONFIRMED" and type(h.supremeDelta) == "number" then
                confirmedCount = confirmedCount + 1
                if h.supremeDelta > 0 then profit = profit + h.supremeDelta end
                if h.supremeDelta < 0 then loss = loss + math.abs(h.supremeDelta) end
                net = net + h.supremeDelta
            end
        end

        local hero = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 62),
            BackgroundColor3 = Palette.surface,
            BorderSizePixel = 0,
            LayoutOrder = 1,
            ZIndex = 43
        }, UI.scroll)
        corner(hero, 10)

        label(hero, "Net Profit: " .. (net > 0 and "+" or "") .. formatVal(net), {
            Position = UDim2.fromOffset(14, 9),
            Size = UDim2.new(1, -90, 0, 22),
            Font = Enum.Font.GothamBold,
            TextSize = 16,
            TextColor3 = net >= 0 and Palette.pos or Palette.neg,
            ZIndex = 44
        })
        label(hero, confirmedCount .. " confirmed  ·  +" .. formatVal(profit) .. " won / −" .. formatVal(loss) .. " lost", {
            Position = UDim2.fromOffset(14, 34),
            Size = UDim2.new(1, -90, 0, 16),
            TextSize = 11,
            TextColor3 = Palette.subtext,
            ZIndex = 44
        })

        if #Data.history > 0 then
            button(hero, "Clear", "danger", {
                Position = UDim2.new(1, -68, 0, 17),
                Size = UDim2.fromOffset(54, 28),
                TextSize = 10,
                ZIndex = 44
            }, function()
                Data.history = {}
                Store.write(Config.HISTORY_FILE, Data.history)
                setTab("History")
            end, State.tabConns)
        end

        for i = 1, math.min(#Data.history, 35) do
            local h = Data.history[i]
            local isConf = h.status == "CONFIRMED"
            local card = mk("Frame", {
                Size = UDim2.new(1, 0, 0, 56),
                BackgroundColor3 = Palette.surface,
                BorderSizePixel = 0,
                LayoutOrder = 1 + i,
                ZIndex = 43
            }, UI.scroll)
            corner(card, 8)

            label(card, (isConf and "Confirmed" or "Unconfirmed") .. "  ·  " .. os.date("%d %b, %H:%M", h.at), {
                Position = UDim2.fromOffset(12, 6),
                Size = UDim2.new(1, -110, 0, 15),
                Font = Enum.Font.GothamBold,
                TextSize = 10,
                TextColor3 = isConf and Palette.pos or Palette.warn,
                ZIndex = 44
            })

            local dStr = type(h.supremeDelta) == "number"
                and ((h.supremeDelta > 0 and "+" or "") .. formatVal(h.supremeDelta)) or "—"
            label(card, dStr, {
                Position = UDim2.new(1, -96, 0, 6),
                Size = UDim2.fromOffset(84, 15),
                Font = Enum.Font.GothamBold,
                TextSize = 11,
                TextColor3 = (h.supremeDelta or 0) >= 0 and Palette.pos or Palette.neg,
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 44
            })

            label(card, "You: " .. tostring(h.you or "—"):sub(1, 42) .. "   →   Them: " .. tostring(h.them or "—"):sub(1, 42), {
                Position = UDim2.fromOffset(12, 24),
                Size = UDim2.new(1, -24, 0, 22),
                TextSize = 11,
                ZIndex = 44
            })
        end

        if #Data.history == 0 then
            label(UI.scroll, "No completed trades logged yet.", {
                Size = UDim2.new(1, 0, 0, 24),
                TextSize = 11,
                TextColor3 = Palette.muted,
                LayoutOrder = 2,
                ZIndex = 43
            })
        end
    end

    -- TAB 6: SETTINGS
    renderSettings = function()
        local options = {
            {"Smooth animations", "animations", "Subtle transitions when opening panels"},
            {"Low-power mode", "lowPower", "Reduces background scan frequency"},
            {"Compact trade HUD", "compact", "Smaller overlay box during trades"},
            {"Slot value badges", "showTags", "Display Supreme & MM2 prices on trade slots"},
            {"Auto-queue on teleport", "autoQueue", "Re-execute script automatically on server hop"}
        }

        for i, opt in ipairs(options) do
            local row = mk("Frame", {
                Size = UDim2.new(1, 0, 0, 48),
                BackgroundColor3 = Palette.surface,
                BorderSizePixel = 0,
                LayoutOrder = i,
                ZIndex = 43
            }, UI.scroll)
            corner(row, 8)

            label(row, opt[1], {
                Position = UDim2.fromOffset(14, 7),
                Size = UDim2.new(1, -74, 0, 17),
                Font = Enum.Font.GothamMedium,
                TextSize = 12,
                ZIndex = 44
            })
            label(row, opt[3], {
                Position = UDim2.fromOffset(14, 25),
                Size = UDim2.new(1, -74, 0, 15),
                TextSize = 10,
                TextColor3 = Palette.muted,
                ZIndex = 44
            })

            local sw = toggleSwitch(row, Prefs[opt[2]], function(val)
                Prefs[opt[2]] = val
                Store.savePrefs()
            end, State.tabConns)
            sw.Position = UDim2.new(1, -52, 0, 14)
            sw.ZIndex = 44
        end

        local infoCard = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 56),
            BackgroundColor3 = Palette.surface,
            BorderSizePixel = 0,
            LayoutOrder = 10,
            ZIndex = 43
        }, UI.scroll)
        corner(infoCard, 8)

        label(infoCard, "Supreme: " .. Data.supremeStamp .. "   ·   MM2 Archive: " .. Data.mm2Stamp .. "   ·   " .. #Data.itemsList .. " items", {
            Position = UDim2.fromOffset(14, 10),
            Size = UDim2.new(1, -28, 0, 16),
            TextSize = 11,
            ZIndex = 44
        })
        label(infoCard, "Status: " .. State.statusText, {
            Position = UDim2.fromOffset(14, 29),
            Size = UDim2.new(1, -28, 0, 16),
            TextSize = 10,
            TextColor3 = Palette.subtext,
            ZIndex = 44
        })

        local btnRow = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundTransparency = 1,
            LayoutOrder = 11,
            ZIndex = 43
        }, UI.scroll)

        button(btnRow, "Refresh Prices", "primary", {
            Size = UDim2.fromOffset(124, 32),
            ZIndex = 44
        }, function()
            notify("Syncing prices", "Fetching latest database...")
            task.spawn(function()
                Net.loadPrices()
                if State.alive then
                    notify("Database updated", Data.lastError or (#Data.itemsList .. " items loaded"))
                end
            end)
        end, State.tabConns)

        button(btnRow, "Reset Layout", "secondary", {
            Position = UDim2.fromOffset(132, 0),
            Size = UDim2.fromOffset(116, 32),
            ZIndex = 44
        }, function()
            Prefs.hudX, Prefs.hudY, Prefs.btnX, Prefs.btnY = 16, 82, -1, 82
            Store.savePrefs()
            UI.hud.Position = UDim2.fromOffset(16, 82)
            UI.launcher.Position = UDim2.fromOffset(math.max(16, State.screenSize.X - 126), 82)
            UI.window.Position = UDim2.fromOffset(
                math.max(12, math.floor((State.screenSize.X - WIN_W) * 0.5)),
                math.max(16, math.floor((State.screenSize.Y - WIN_H) * 0.5))
            )
            notify("Layout reset", "Windows restored to default positions")
        end, State.tabConns)

        button(btnRow, "Unload", "danger", {
            Position = UDim2.new(1, -84, 0, 0),
            Size = UDim2.fromOffset(84, 32),
            ZIndex = 44
        }, function()
            if type(env.MM2CarbonCleanup) == "function" then env.MM2CarbonCleanup() end
        end, State.tabConns)
    end

    -- Navigation Switcher
    setTab = function(tabName)
        State.currentTab = tabName
        UI.pageTitle.Text = tabName
        UI.tradeRefs = nil

        for name, item in pairs(UI.navItems) do
            local active = name == tabName
            item.indicator.Visible = active
            tween(item.btn, {BackgroundTransparency = active and 0 or 1}, 0.12)
            tween(item.label, {TextColor3 = active and Palette.text or Palette.subtext}, 0.12)
            item.label.Font = active and Enum.Font.GothamBold or Enum.Font.GothamMedium
        end

        disconnectBag(State.tabConns)
        for _, ch in ipairs(UI.scroll:GetChildren()) do
            if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then
                ch:Destroy()
            end
        end
        UI.scroll.CanvasPosition = Vector2.new(0, 0)

        if tabName == "Trade" then renderTrade()
        elseif tabName == "Values" then renderValues()
        elseif tabName == "Servers" then renderServers()
        elseif tabName == "Inventory" then renderInventory()
        elseif tabName == "History" then renderHistory()
        else renderSettings() end
    end

    for name, item in pairs(UI.navItems) do
        attach(item.btn.MouseButton1Click, function() setTab(name) end)
    end

    -- Live Trade Reader & Slot Badges
    local function findChild(parent, name)
        return parent and parent:FindFirstChild(name) or nil
    end

    local function findNested(parent, ...)
        local cur = parent
        for i = 1, select("#", ...) do
            cur = findChild(cur, select(i, ...))
            if not cur then return nil end
        end
        return cur
    end

    local function isGuiVisible(obj)
        while obj and obj ~= playerGui do
            if obj:IsA("GuiObject") and obj.Visible == false then return false end
            if obj:IsA("ScreenGui") and obj.Enabled == false then return false end
            obj = obj.Parent
        end
        return true
    end

    local function readSlotItem(slot)
        local lbl = findNested(slot, "ItemName", "Label") or findChild(slot, "ItemName")
        if not lbl or not lbl:IsA("TextLabel") then return nil end
        local name = trim(lbl.Text)
        if name == "" then return nil end

        local chroma = findNested(slot, "Tags", "Chroma")
        if chroma and chroma.Visible and not name:lower():match("^chroma%s") then
            name = "Chroma " .. name
        end

        local amtLbl = findNested(slot, "Container", "Amount") or findChild(slot, "Amount")
        local amount = 1
        if amtLbl and amtLbl:IsA("TextLabel") and type(amtLbl.Text) == "string" then
            local digits = amtLbl.Text:match("[xX×]?%s*(%d+)")
            amount = math.clamp(tonumber(digits) or 1, 1, 9999)
        end
        return name, amount
    end

    local function getOfferItems(offer)
        local list = {}
        if not offer then return list end
        local cont = findChild(offer, "Container") or offer
        for n = 1, 4 do
            local slot = findChild(cont, "NewItem" .. n) or findChild(offer, "NewItem" .. n)
            if slot and isGuiVisible(slot) then
                local name, count = readSlotItem(slot)
                if name then list[#list + 1] = {name = name, count = count, slot = slot} end
            end
        end
        return list
    end

    local function getOrCreateBadge(slot)
        local badge = State.badges[slot]
        if badge and badge.Parent == slot then return badge end
        if not slot:IsA("GuiObject") then return nil end
        badge = mk("TextLabel", {
            Name = "CarbonXValueTag",
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -3, 1, -3),
            Size = UDim2.fromOffset(90, 17),
            BackgroundColor3 = Palette.canvas,
            BackgroundTransparency = 0.08,
            TextColor3 = Palette.text,
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 82,
            Visible = false,
            Active = false,
            TextXAlignment = Enum.TextXAlignment.Center,
            BorderSizePixel = 0
        }, slot)
        corner(badge, 5)
        stroke(badge, Palette.hairline, 0, 1)
        State.badges[slot] = badge
        track(badge)
        return badge
    end

    local function applySlotBadges(items)
        for _, entry in ipairs(items) do
            local badge = getOrCreateBadge(entry.slot)
            if badge then
                badge.Visible = Prefs.showTags
                local row = lookup(entry.name)
                if entry.slot.AbsoluteSize.X < 92 then
                    badge.Size = UDim2.fromOffset(math.max(46, math.floor(entry.slot.AbsoluteSize.X) - 6), 16)
                    badge.Text = formatVal(row and row.supreme)
                else
                    badge.Size = UDim2.fromOffset(102, 17)
                    badge.Text = "S " .. formatVal(row and row.supreme) .. " · M " .. formatVal(safeMM2(row))
                end
                badge.TextColor3 = (row and row.supreme) and Palette.text or Palette.warn
            end
        end
    end

    local function findTradeWindow()
        for _, screen in ipairs(playerGui:GetChildren()) do
            if screen:IsA("ScreenGui") and screen ~= UI.root and screen.Enabled ~= false then
                local trade = findNested(screen, "Container", "Trade") or screen:FindFirstChild("Trade", true)
                if trade and isGuiVisible(trade) then
                    local own = findChild(trade, "YourOffer") or trade:FindFirstChild("YourOffer", true)
                    local them = findChild(trade, "TheirOffer") or trade:FindFirstChild("TheirOffer", true)
                    if own and them and isGuiVisible(own) and isGuiVisible(them) then
                        return screen, trade, own, them
                    end
                end
            end
        end
        return nil
    end

    local function markSightings(items, source)
        local jobId, placeId = tostring(game.JobId or ""), game.PlaceId
        local changed = false
        for _, entry in ipairs(items or {}) do
            local row = lookup(entry.name)
            if row and row.supreme and row.supreme >= 250 then
                local k = normalize(entry.name)
                local cur = Data.sightings[k]
                if not cur or cur.value ~= row.supreme or (os.time() - cur.at) > 60 then
                    Data.sightings[k] = {
                        name = row.name or entry.name,
                        value = row.supreme,
                        at = os.time(),
                        source = source,
                        jobId = jobId,
                        placeId = placeId
                    }
                    changed = true
                end
            end
        end
        if changed then Store.write(Config.SIGHTINGS_FILE, Data.sightings) end
    end

    local function updateHUD(own, theirs)
        UI.hudYouVal.Text = displayNumber(own.supreme, own.missingSupreme)
        UI.hudThemVal.Text = displayNumber(theirs.supreme, theirs.missingSupreme)
        UI.hudYouSub.Text = "MM2: " .. displayNumber(own.mm2, own.missingMm2)
        UI.hudThemSub.Text = "MM2: " .. displayNumber(theirs.mm2, theirs.missingMm2)

        local _, n = diffSummary(own, theirs, "supreme")
        if n == nil then
            UI.hudBadge.Text = "Unknown"
            UI.hudBadge.TextColor3 = Palette.warn
            UI.hudBadge.BackgroundColor3 = Palette.warnBg
        elseif n > 0 then
            UI.hudBadge.Text = "Win +" .. formatVal(n)
            UI.hudBadge.TextColor3 = Palette.pos
            UI.hudBadge.BackgroundColor3 = Palette.posBg
        elseif n < 0 then
            UI.hudBadge.Text = "Loss " .. formatVal(n)
            UI.hudBadge.TextColor3 = Palette.neg
            UI.hudBadge.BackgroundColor3 = Palette.negBg
        else
            UI.hudBadge.Text = "Fair"
            UI.hudBadge.TextColor3 = Palette.subtext
            UI.hudBadge.BackgroundColor3 = Palette.elevated
        end

        local demand = (theirs.demandCount > 0) and (theirs.demandSum / theirs.demandCount) or nil
        UI.hudTitle.Text = demand and ("Trade · Dem " .. string.format("%.1f", demand)) or "Active Trade"

        local warnMsg = ""
        if os.clock() < State.warningUntil then
            warnMsg = "Offer changed — recheck items"
        elseif demand and demand <= 2 then
            warnMsg = "Low demand — hard to trade"
        end

        UI.hudWarnBar.Visible = (warnMsg ~= "") and not Prefs.compact
        UI.hudWarnText.Text = warnMsg

        if not State.hudCollapsed then
            UI.hud.Size = UDim2.fromOffset(264, Prefs.compact and 88 or (warnMsg ~= "" and 126 or 102))
        end
        UI.hud.Visible = true
        UI.launcherDot.BackgroundColor3 = Palette.pos
    end

    local function probeTradeSuccess()
        for _, screen in ipairs(playerGui:GetChildren()) do
            if screen:IsA("ScreenGui") and screen ~= UI.root then
                for _, item in ipairs(screen:GetDescendants()) do
                    if (item:IsA("TextLabel") or item:IsA("TextButton")) and isGuiVisible(item) then
                        local val = trim(item.Text):lower()
                        if #val > 0 and #val < 110 then
                            for _, pat in ipairs({"trade successful", "trade completed", "trade complete", "successfully traded", "обмен завершен", "обмен завершён"}) do
                                if val:find(pat, 1, true) then return true end
                            end
                        end
                    end
                end
            end
        end
        return false
    end

    local function finalizeTrade()
        local snap = State.lastTradeSnapshot
        State.lastTradeSnapshot = nil
        if not snap or (snap.you == "(empty)" and snap.them == "(empty)") then return end

        State.pendingSuccessId = State.pendingSuccessId + 1
        local id = State.pendingSuccessId
        task.spawn(function()
            local confirmed = false
            for _ = 1, 7 do
                if not State.alive or id ~= State.pendingSuccessId then return end
                if probeTradeSuccess() then confirmed = true; break end
                task.wait(0.35)
            end
            if not State.alive or id ~= State.pendingSuccessId then return end
            snap.status = confirmed and "CONFIRMED" or "UNCONFIRMED"
            Store.addHistory(snap)
            if confirmed then
                local d = snap.supremeDelta
                notify("Trade confirmed", d and ((d > 0 and "+" or "") .. formatVal(d) .. " Supreme") or "Saved to journal", Palette.pos)
            end
            if UI.window.Visible and State.currentTab == "History" then setTab("History") end
        end)
    end

    local scheduleTradeScan

    local function rebindTradeListeners(screen, trade, own, theirs)
        if screen == State.activeTradeScreen and own == State.activeOur and theirs == State.activeTheirs then return end
        disconnectBag(State.tradeConns)
        State.activeTradeScreen = screen
        State.activeOur = own
        State.activeTheirs = theirs
        if not screen then return end

        attach(screen:GetPropertyChangedSignal("Enabled"), scheduleTradeScan, State.tradeConns)
        if trade:IsA("GuiObject") then
            attach(trade:GetPropertyChangedSignal("Visible"), scheduleTradeScan, State.tradeConns)
        end

        for _, offer in ipairs({own, theirs}) do
            attach(offer.DescendantAdded, function(o)
                if o.Name ~= "CarbonXValueTag" and not (o.Parent and o.Parent.Name == "CarbonXValueTag") then
                    task.defer(function()
                        if State.alive then
                            rebindTradeListeners(nil, nil, nil, nil)
                            scheduleTradeScan()
                        end
                    end)
                end
            end, State.tradeConns)
            attach(offer.DescendantRemoving, function(o)
                if o.Name ~= "CarbonXValueTag" then scheduleTradeScan() end
            end, State.tradeConns)

            local cont = findChild(offer, "Container") or offer
            for n = 1, 4 do
                local slot = findChild(cont, "NewItem" .. n) or findChild(offer, "NewItem" .. n)
                if slot then
                    attach(slot:GetPropertyChangedSignal("Visible"), scheduleTradeScan, State.tradeConns)
                    local lbl = findNested(slot, "ItemName", "Label") or findChild(slot, "ItemName")
                    if lbl then attach(lbl:GetPropertyChangedSignal("Text"), scheduleTradeScan, State.tradeConns) end
                    local chroma = findNested(slot, "Tags", "Chroma")
                    if chroma then attach(chroma:GetPropertyChangedSignal("Visible"), scheduleTradeScan, State.tradeConns) end
                    local amt = findNested(slot, "Container", "Amount") or findChild(slot, "Amount")
                    if amt then attach(amt:GetPropertyChangedSignal("Text"), scheduleTradeScan, State.tradeConns) end
                end
            end
        end
    end

    local function offerSignature(items)
        local rows = {}
        for _, it in ipairs(items or {}) do
            rows[#rows + 1] = normalize(it.name) .. ":" .. tostring(it.count or 1)
        end
        table.sort(rows)
        return table.concat(rows, "|")
    end

    local function detectRemovedItems(oldList, newList)
        local oldMap = {}
        for _, o in ipairs(oldList or {}) do
            local k = normalize(o.name)
            oldMap[k] = (oldMap[k] or 0) + (o.count or 1)
        end
        for _, n in ipairs(newList or {}) do
            local k = normalize(n.name)
            if oldMap[k] then oldMap[k] = oldMap[k] - (n.count or 1) end
        end
        local removed = {}
        for k, cnt in pairs(oldMap) do
            if cnt > 0 then removed[#removed + 1] = k .. " ×" .. cnt end
        end
        return removed
    end

    local function formatOfferNames(items)
        local list = {}
        for _, it in ipairs(items or {}) do
            list[#list + 1] = tostring(it.name) .. " ×" .. tostring(it.count or 1)
        end
        return #list > 0 and table.concat(list, ", ") or "(empty)"
    end

    local function evaluateTrade()
        if not State.alive then return end
        local screen, trade, own, theirs = findTradeWindow()
        if not screen then
            if State.tradeActive then finalizeTrade() end
            State.tradeActive = false
            State.firstOpen = false
            State.prevOther = ""
            UI.hud.Visible = false
            UI.launcherDot.BackgroundColor3 = Palette.subtext
            rebindTradeListeners(nil, nil, nil, nil)
            if UI.window.Visible and State.currentTab == "Trade" then updateLiveTradeCard() end
            return
        end

        if not State.tradeActive then
            State.pendingSuccessId = State.pendingSuccessId + 1
            State.firstOpen = true
            State.prevOther = ""
        end
        State.tradeActive = true
        rebindTradeListeners(screen, trade, own, theirs)

        local ownItems = getOfferItems(own)
        local otherItems = getOfferItems(theirs)
        local ourSum = aggregate(ownItems)
        local theirSum = aggregate(otherItems)

        for slot, badge in pairs(State.badges) do
            if badge and badge.Parent == slot then badge.Visible = false end
        end
        applySlotBadges(ownItems)
        applySlotBadges(otherItems)

        local newSig = offerSignature(otherItems)
        if not State.firstOpen and newSig ~= State.prevOther then
            local removed = detectRemovedItems(State.latestTrade and State.latestTrade.them and State.latestTrade.them.items, otherItems)
            if #removed > 0 then
                State.warningUntil = os.clock() + 5
                notify("Offer modified", "Removed: " .. table.concat(removed, ", "):sub(1, 46), Palette.warn)
            end
        end
        State.prevOther = newSig
        State.firstOpen = false

        local delta = (ourSum.missingSupreme == 0 and theirSum.missingSupreme == 0)
            and (theirSum.supreme - ourSum.supreme) or nil

        State.latestTrade = {you = ourSum, them = theirSum, at = os.time(), delta = delta}
        State.lastTradeSnapshot = {
            at = os.time(),
            status = "UNCONFIRMED",
            you = formatOfferNames(ourSum.items),
            them = formatOfferNames(theirSum.items),
            supremeYou = ourSum.missingSupreme == 0 and ourSum.supreme or nil,
            supremeThem = theirSum.missingSupreme == 0 and theirSum.supreme or nil,
            supremeDelta = delta,
            mm2You = ourSum.missingMm2 == 0 and ourSum.mm2 or nil,
            mm2Them = theirSum.missingMm2 == 0 and theirSum.mm2 or nil
        }

        updateHUD(ourSum, theirSum)
        markSightings(otherItems, "trade")
        if UI.window.Visible and State.currentTab == "Trade" then updateLiveTradeCard() end
    end

    scheduleTradeScan = function()
        if State.scheduled or not State.alive then return end
        State.scheduled = true
        task.delay(Prefs.lowPower and 0.22 or 0.08, function()
            State.scheduled = false
            if State.alive then
                local okScan, err = pcall(evaluateTrade)
                if not okScan then State.statusText = "Scan error: " .. tostring(err):sub(1, 50) end
            end
        end)
    end

    attach(playerGui.ChildAdded, function(node)
        if node ~= UI.root and node:IsA("ScreenGui") then scheduleTradeScan() end
    end)
    attach(playerGui.ChildRemoved, function(node)
        if node == State.activeTradeScreen then scheduleTradeScan() end
    end)

    task.spawn(function()
        while State.alive do
            task.wait(Prefs.lowPower and 8 or 4)
            if State.alive then scheduleTradeScan() end
        end
    end)

    local function watchPlayer(p)
        if State.trackedPlayers[p] or p == player then return end
        State.trackedPlayers[p] = true
        local function onChar(char)
            local function checkTool(tool)
                if not tool:IsA("Tool") then return end
                local row = lookup(tool.Name)
                if row and row.supreme and row.supreme >= 250 then
                    markSightings({{name = tool.Name}}, "equipped")
                end
            end
            for _, ch in ipairs(char:GetChildren()) do checkTool(ch) end
            attach(char.ChildAdded, checkTool)
        end
        if p.Character then onChar(p.Character) end
        attach(p.CharacterAdded, onChar)
    end
    for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
    attach(Players.PlayerAdded, watchPlayer)

    env.MM2CarbonCleanup = function()
        State.alive = false
        disconnectBag(State.tabConns)
        disconnectBag(State.tradeConns)
        disconnectBag(State.conns)
        for _, obj in ipairs(State.created) do pcall(function() obj:Destroy() end) end
        table.clear(State.created)
        env.MM2CarbonCleanup = nil
    end

    Data.listeners[#Data.listeners + 1] = function()
        if not State.alive then return end
        UI.dbDot.BackgroundColor3 = Data.lastError and Palette.warn or Palette.pos
        UI.dbStatus.Text = #Data.itemsList .. " items · " .. Data.supremeStamp
        scheduleTradeScan()
        if UI.window.Visible and (State.currentTab == "Values" or State.currentTab == "Settings") then
            setTab(State.currentTab)
        end
    end

    setTab("Trade")
    Net.readCache()
    task.spawn(function()
        Net.loadPrices()
        if not State.alive then return end
        State.statusText = Data.lastError or "Synced"
        UI.dbDot.BackgroundColor3 = Data.lastError and Palette.warn or Palette.pos
        UI.dbStatus.Text = #Data.itemsList .. " items · " .. Data.supremeStamp
        scheduleTradeScan()
    end)

    if Prefs.autoQueue then
        local queueFn = (type(queue_on_teleport) == "function" and queue_on_teleport)
            or (type(queueonteleport) == "function" and queueonteleport)
            or (type(syn) == "table" and type(syn.queue_on_teleport) == "function" and syn.queue_on_teleport)
        if type(queueFn) == "function" then
            local payload = "if not game:IsLoaded() then game.Loaded:Wait() end; "
                .. "pcall(function() loadstring(game:HttpGet('" .. Config.RELOAD_URL .. "'))() end)"
            pcall(queueFn, payload)
        end
    end

    scheduleTradeScan()
    notify("Carbon X loaded", "Press RightShift or tap Carbon X")

end, function(err)
    if debug and type(debug.traceback) == "function" then
        return debug.traceback(tostring(err), 2)
    end
    return tostring(err)
end)

if not ok then
    warn("[Carbon X] " .. tostring(failure))
end
