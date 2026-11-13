-- MM2 CARBON X | Read-Only Trading Companion
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local ok, failure = xpcall(function()
    local MM2_UNIVERSE_ID = 66654135
    local MAIN_PLACE_ID = 142823291

    local Players = game:GetService("Players")
    local HttpService = game:GetService("HttpService")
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local GuiService = game:GetService("GuiService")

    local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
    local playerGui = player:WaitForChild("PlayerGui")

    if tonumber(game.GameId) ~= 0 and tonumber(game.GameId) ~= MM2_UNIVERSE_ID and tonumber(game.PlaceId) ~= MAIN_PLACE_ID then
        warn("[Carbon X] Unsupported experience: " .. tostring(game.GameId))
        return
    end

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
        supremeStamp = "-",
        mm2Stamp = "-",
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
            {number=56,category="AGE",label="9-15 Years #56",code="90246163478876606479670100047019"},
            {number=57,category="AGE",label="9-15 Years #57",code="83367765949007168971266059380186"},
            {number=58,category="AGE",label="9-15 Years #58",code="30573624551302812150126292321731"},
            {number=59,category="AGE",label="9-15 Years #59",code="35628184866192837925469885558481"},
            {number=60,category="AGE",label="9-15 Years #60",code="17302568250702812171846186180666"},
            {number=61,category="AGE",label="9-15 Years #61",code="67302018046903083244956932774414"},
            {number=62,category="AGE",label="9-15 Years #62",code="23017297771776532094192413007181"},
            {number=63,category="AGE",label="15-18 Years #63",code="62640428440367202194173423300127"},
            {number=64,category="AGE",label="15-18 Years #64",code="70528245225099173571462694452389"},
            {number=65,category="AGE",label="15-18 Years #65",code="61839134489251782547262022500361"},
            {number=66,category="AGE",label="15-18 Years #66",code="56578360603812889488354049946918"},
            {number=67,category="AGE",label="15-18 Years #67",code="88336436079327296139003254015359"},
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

    local function trim(s)
        return tostring(s or ""):match("^%s*(.-)%s*$")
    end

    local function normalize(s)
        local clean = trim(s):lower()
        clean = clean:gsub("^c%.%s*", "chroma ")
        clean = clean:gsub("^c%s+", "chroma ")
        return (clean:gsub("[^%w]", ""))
    end

    local function parseNum(v)
        if type(v) == "string" then v = v:gsub(",", "") end
        local n = tonumber(v)
        if n and n >= 0 and n < 10000000000 and n == n then return n end
        return nil
    end

    local function formatVal(n)
        if type(n) ~= "number" then return "-" end
        local absN = math.abs(n)
        local sign = n < 0 and "-" or ""
        local intPart, fracPart
        if absN == math.floor(absN) then
            intPart = string.format("%.0f", absN)
            fracPart = ""
        else
            local s = string.format("%.1f", absN)
            intPart, fracPart = s:match("^(%d+)(%.%d+)$")
            if not intPart then
                intPart = s
                fracPart = ""
            end
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
        Data.supremeStamp = haveSup and tostring(meta and meta.last_updated or "-"):sub(1, 10) or "Offline"
        Data.mm2Stamp = haveMM2 and tostring(archive.updatedAt or "-"):sub(1, 10) or "Offline"
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
            Data.lastError = "Offline - using cached snapshot"
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
            tween(b, {
                BackgroundColor3 = bgHover,
                BackgroundTransparency = 0,
                TextColor3 = isPrimary and Palette.accentFg or (isDanger and Palette.neg or Palette.text)
            }, 0.1)
        end, bucket)
        attach(b.MouseLeave, function()
            tween(b, {
                BackgroundColor3 = bg,
                BackgroundTransparency = isGhost and 1 or 0,
                TextColor3 = fg
            }, 0.12)
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

    -- Toast Pill
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

    -- Live Trade HUD
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

    UI.hudCollapse = button(UI.hudTopBar, "-", "ghost", {
        Position = UDim2.new(1, -30, 0, 5),
        Size = UDim2.fromOffset(22, 22),
        TextSize = 13,
        ZIndex = 53
    }, function()
        State.hudCollapsed = not State.hudCollapsed
        UI.hudBody.Visible = not State.hudCollapsed
        UI.hudCollapse.Text = State.hudCollapsed and "+" or "-"
        UI.applyHudSize()
    end)

    UI.hudBody = mk("Frame", {
        Position = UDim2.fromOffset(0, 32),
        Size = UDim2.new(1, 0, 1, -32),
        BackgroundTransparency = 1,
        ZIndex = 52
    }, UI.hud)


    mk("Frame", {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -24, 0, 1),
        BackgroundColor3 = Palette.hairline,
        BorderSizePixel = 0,
        ZIndex = 53
    }, UI.hudBody)

    local function hudRow(y, caption)
        label(UI.hudBody, caption, {
            Position = UDim2.fromOffset(12, y), Size = UDim2.fromOffset(44, 20),
            Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Palette.subtext, ZIndex = 53
        })
        local s = label(UI.hudBody, "-", {
            Position = UDim2.fromOffset(56, y), Size = UDim2.fromOffset(100, 20),
            Font = Enum.Font.GothamMedium, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 53
        })
        local m = label(UI.hudBody, "-", {
            Position = UDim2.fromOffset(160, y), Size = UDim2.fromOffset(92, 20),
            Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Palette.subtext,
            TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 53
        })
        return s, m
    end
    UI.ownS, UI.ownM = hudRow(6, "YOU")
    UI.themS, UI.themM = hudRow(28, "THEM")

    UI.hudDiff = label(UI.hudBody, "DIFF  -", {
        Position = UDim2.fromOffset(12, 50), Size = UDim2.new(1, -24, 0, 16),
        TextSize = 10, TextColor3 = Palette.subtext, ZIndex = 53
    })

    UI.hudWarnBar = mk("Frame", {
        Position = UDim2.fromOffset(12, 70),
        Size = UDim2.new(1, -24, 0, 20),
        BackgroundColor3 = Palette.warnBg,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 53
    }, UI.hudBody)
    corner(UI.hudWarnBar, 6)
    UI.hudWarnText = label(UI.hudWarnBar, "", {
        Size = UDim2.new(1, 0, 1, 0), TextSize = 10, TextColor3 = Palette.warn,
        TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 54
    })

    function UI.applyHudSize()
        local h
        if State.hudCollapsed then
            h = 32
        else
            h = (Prefs.compact and 88 or 102) + (UI.hudWarnBar.Visible and 24 or 0)
        end
        UI.hudBody.Visible = not State.hudCollapsed
        UI.hudDiff.Visible = not Prefs.compact
        UI.hudWarnBar.Position = UDim2.fromOffset(12, Prefs.compact and 52 or 70)
        UI.hud.Size = UDim2.fromOffset(264, h)
    end
    UI.applyHudSize()

    makeDraggable(UI.hud, UI.hudTopBar, function(x, y)
        Prefs.hudX = math.max(0, math.floor(x))
        Prefs.hudY = math.max(0, math.floor(y))
        Store.savePrefs()
    end)

    ----------------------------------------------------------------------
    -- Cleanup (registered early so a later failure never leaves half a UI)
    ----------------------------------------------------------------------
    local function cleanup()
        State.alive = false
        disconnectBag(State.conns)
        disconnectBag(State.tabConns)
        disconnectBag(State.tradeConns)
        for _, obj in ipairs(State.created) do
            pcall(function() obj:Destroy() end)
        end
        pcall(function()
            for _, d in ipairs(playerGui:GetDescendants()) do
                if d.Name == "CarbonXValueTag" then d:Destroy() end
            end
        end)
        if env.MM2CarbonCleanup == cleanup then env.MM2CarbonCleanup = nil end
    end
    env.MM2CarbonCleanup = cleanup

    ----------------------------------------------------------------------
    -- Shared helpers
    ----------------------------------------------------------------------
    local Util = {}

    function Util.resolve(text)
        local q = normalize(text)
        if q == "" then return nil end
        local exact = lookup(text)
        if exact then return exact end
        for _, row in ipairs(Data.itemsList) do
            row._k = row._k or normalize(row.name)
            if row._k:find(q, 1, true) then return row end
        end
        return nil
    end

    function Util.ago(ts)
        local d = math.max(0, os.time() - (tonumber(ts) or 0))
        if d < 60 then return d .. "s ago" end
        if d < 3600 then return math.floor(d / 60) .. "m ago" end
        if d < 86400 then return math.floor(d / 3600) .. "h ago" end
        return math.floor(d / 86400) .. "d ago"
    end

    function Util.signed(n)
        if type(n) ~= "number" then return "-" end
        return (n > 0 and "+" or "") .. formatVal(n)
    end

    local queueFn = (type(queue_on_teleport) == "function" and queue_on_teleport)
        or (type(queueonteleport) == "function" and queueonteleport)
        or (type(syn) == "table" and type(syn.queue_on_teleport) == "function" and syn.queue_on_teleport)
        or nil
    local queued = false
    function Net.queueReload()
        if queued then return true end
        if type(queueFn) ~= "function" then return false end
        local src = 'if not game:IsLoaded() then game.Loaded:Wait() end '
            .. 'pcall(function() loadstring(game:HttpGet("' .. Config.RELOAD_URL .. '"))() end)'
        local okQ = pcall(queueFn, src)
        if okQ then queued = true end
        return okQ
    end

    local function refreshScreen()
        local size = UI.root.AbsoluteSize
        if size.X <= 0 or size.Y <= 0 then
            local cam = workspace.CurrentCamera
            if cam then size = cam.ViewportSize end
        end
        if size.X > 0 and size.Y > 0 then State.screenSize = size end
    end

    ----------------------------------------------------------------------
    -- Trade reading (read-only: only looks at the game's own trade GUI)
    ----------------------------------------------------------------------
    local Trade = {tick = 0, closing = nil}
    local TRADE_SCREENS = {"TradeGUI", "TradeGUI_Phone"}
    local SUCCESS_PATTERNS = {
        "trade successful", "trade completed", "trade complete", "successfully traded",
        "обмен завершен", "обмен завершён", "Обмен завершен", "Обмен завершён"
    }

    local function child(parent, name)
        if not parent then return nil end
        return parent:FindFirstChild(name)
    end

    local function nested(parent, ...)
        local obj = parent
        for i = 1, select("#", ...) do
            obj = child(obj, (select(i, ...)))
            if not obj then return nil end
        end
        return obj
    end

    local function isShown(obj)
        while obj and obj ~= playerGui do
            if obj:IsA("GuiObject") and obj.Visible == false then return false end
            if obj:IsA("ScreenGui") and obj.Enabled == false then return false end
            obj = obj.Parent
        end
        return true
    end

    local function readSlot(slot)
        local v = nested(slot, "ItemName", "Label")
        if not v or not v:IsA("TextLabel") then return nil end
        local name = trim(v.Text)
        if name == "" then return nil end
        local chroma = nested(slot, "Tags", "Chroma")
        if chroma and chroma:IsA("GuiObject") and chroma.Visible and not name:lower():match("^chroma%s") then
            name = "Chroma " .. name
        end
        local amount = 1
        local amountLabel = nested(slot, "Container", "Amount")
        if amountLabel and type(amountLabel.Text) == "string" then
            local digits = amountLabel.Text:match("[xX×]%s*(%d+)")
            amount = math.max(1, math.min(9999, tonumber(digits) or 1))
        end
        return name, amount
    end

    local function tagFor(slot)
        local b = State.badges[slot]
        if b and b.Parent == slot then return b end
        b = mk("TextLabel", {
            Name = "CarbonXValueTag", Text = "", Font = Enum.Font.GothamBold, TextSize = 9,
            TextColor3 = Palette.text, BackgroundColor3 = Palette.canvas, BackgroundTransparency = 0.1,
            BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -3, 1, -3),
            Size = UDim2.fromOffset(92, 16), TextTruncate = Enum.TextTruncate.AtEnd,
            Visible = false, Active = false, Selectable = false, ZIndex = 75
        }, slot)
        corner(b, 5)
        stroke(b, Palette.hairline, 0, 1)
        State.badges[slot] = b
        track(b)
        return b
    end

    local function summarizeOffer(offer)
        local out = {s = 0, m = 0, missS = 0, missM = 0, count = 0, names = {}, sig = {}}
        if not offer then return out end
        local container = child(offer, "Container") or offer
        for i = 1, 4 do
            local slot = child(container, "NewItem" .. i) or child(offer, "NewItem" .. i)
            if slot then
                local name, amount
                if isShown(slot) then name, amount = readSlot(slot) end
                local existing = State.badges[slot]
                if name then
                    local row = lookup(name)
                    local s = row and row.supreme
                    local m = safeMM2(row)
                    if s then out.s = out.s + s * amount else out.missS = out.missS + amount end
                    if m then out.m = out.m + m * amount else out.missM = out.missM + amount end
                    out.count = out.count + amount
                    out.names[#out.names + 1] = amount > 1 and (name .. " x" .. amount) or name
                    out.sig[#out.sig + 1] = normalize(name) .. "x" .. amount
                    if Prefs.showTags then
                        local tag = tagFor(slot)
                        local width = slot.AbsoluteSize and slot.AbsoluteSize.X or 95
                        if width > 0 and width < 92 then
                            tag.Size = UDim2.fromOffset(math.max(37, width - 5), 16)
                            tag.Text = "S " .. formatVal(s)
                        else
                            tag.Size = UDim2.fromOffset(110, 16)
                            tag.Text = "S " .. formatVal(s) .. "  M " .. formatVal(m)
                        end
                        tag.TextColor3 = s and Palette.text or Palette.warn
                        tag.Visible = true
                    elseif existing then
                        existing.Visible = false
                    end
                elseif existing then
                    existing.Visible = false
                end
            end
        end
        return out
    end

    function Trade.hideTags()
        for slot, tag in pairs(State.badges) do
            pcall(function() tag.Visible = false end)
        end
    end

    function Trade.locate()
        local function check(screen)
            if not screen or screen == UI.root or not screen:IsA("ScreenGui") or screen.Enabled == false then
                return nil
            end
            local trade = nested(screen, "Container", "Trade") or screen:FindFirstChild("Trade", true)
            if not trade or not isShown(trade) then return nil end
            local our = trade:FindFirstChild("YourOffer") or trade:FindFirstChild("YourOffer", true)
            local theirs = trade:FindFirstChild("TheirOffer") or trade:FindFirstChild("TheirOffer", true)
            if our and theirs and isShown(our) and isShown(theirs) then
                return screen, our, theirs
            end
            return nil
        end

        local active = State.activeTradeScreen
        if active and active.Parent then
            local s, o, t = check(active)
            if s then return s, o, t end
        end
        for _, nm in ipairs(TRADE_SCREENS) do
            local s, o, t = check(playerGui:FindFirstChild(nm))
            if s then return s, o, t end
        end
        -- Renamed ScreenGui in another mode: scan sparingly (every ~2s), it is the costly path.
        if Trade.tick % 6 == 0 then
            for _, screen in ipairs(playerGui:GetChildren()) do
                if screen ~= UI.root and screen:IsA("ScreenGui") and screen.Enabled ~= false then
                    local cand = screen:FindFirstChild("Trade", true)
                    if cand and cand:FindFirstChild("YourOffer", true) and cand:FindFirstChild("TheirOffer", true) then
                        local s, o, t = check(screen)
                        if s then return s, o, t end
                    end
                end
            end
        end
        return nil
    end

    function Trade.successVisible()
        local nodes = playerGui:GetDescendants()
        for i = 1, math.min(#nodes, 2500) do
            local node = nodes[i]
            if (node:IsA("TextLabel") or node:IsA("TextButton")) and not node:IsDescendantOf(UI.root) then
                local value = trim(node.Text)
                if #value > 0 and #value < 100 and isShown(node) then
                    local low = value:lower()
                    for _, p in ipairs(SUCCESS_PATTERNS) do
                        if low:find(p, 1, true) or value:find(p, 1, true) then return true end
                    end
                end
            end
        end
        return false
    end

    function Trade.finish(confirmed)
        local c = Trade.closing
        Trade.closing = nil
        if not c or not c.snap then return end
        local snap = c.snap
        local entry = {
            at = os.time(),
            status = confirmed and "CONFIRMED" or "UNCONFIRMED",
            give = table.concat(snap.mine.names, ", "):sub(1, 90),
            get = table.concat(snap.other.names, ", "):sub(1, 90)
        }
        if Data.loaded and snap.mine.missS == 0 and snap.other.missS == 0 then
            entry.delta = snap.other.s - snap.mine.s
        end
        Store.addHistory(entry)
        if confirmed then
            notify("Trade completed", entry.delta and ("Value change " .. Util.signed(entry.delta) .. " S") or "Confirmed by game UI", Palette.pos)
        end
        if UI.win and UI.win.Visible and State.currentTab == "Trade" and UI.selectTab then
            pcall(UI.selectTab, "Trade")
        end
    end

    local function fmtSide(total, missing)
        return formatVal(total) .. (missing > 0 and "+?" or "")
    end

    local function updateHud(snap)
        local mine, other = snap.mine, snap.other
        local incomplete = mine.missS > 0 or other.missS > 0
        UI.ownS.Text = "S " .. fmtSide(mine.s, mine.missS)
        UI.ownM.Text = "M " .. fmtSide(mine.m, mine.missM)
        UI.themS.Text = "S " .. fmtSide(other.s, other.missS)
        UI.themM.Text = "M " .. fmtSide(other.m, other.missM)
        UI.ownS.TextColor3 = mine.missS > 0 and Palette.warn or Palette.text
        UI.themS.TextColor3 = other.missS > 0 and Palette.warn or Palette.text

        local d = other.s - mine.s
        local dm = other.m - mine.m
        local txt, fg, bg
        if mine.count + other.count == 0 then
            txt, fg, bg = "EMPTY", Palette.subtext, Palette.elevated
        elseif not Data.loaded then
            txt, fg, bg = "WAIT", Palette.warn, Palette.warnBg
        elseif incomplete then
            txt, fg, bg = "N/A", Palette.warn, Palette.warnBg
        else
            local base = math.max(mine.s, other.s)
            if math.abs(d) <= math.max(2, base * 0.05) then
                txt, fg, bg = "FAIR", Palette.subtext, Palette.elevated
            elseif d > 0 then
                txt, fg, bg = "WIN", Palette.pos, Palette.posBg
            else
                txt, fg, bg = "LOSS", Palette.neg, Palette.negBg
            end
        end
        UI.hudBadge.Text = txt
        UI.hudBadge.TextColor3 = fg
        UI.hudBadge.BackgroundColor3 = bg

        if incomplete or not Data.loaded then
            UI.hudDiff.Text = "DIFF  incomplete"
        else
            UI.hudDiff.Text = "DIFF  " .. Util.signed(d) .. " S   /   " .. Util.signed(dm) .. " M"
        end

        local warn, danger
        if os.clock() < State.warningUntil then
            warn, danger = "Their offer just changed - re-check", true
        elseif not Data.loaded then
            warn = "Prices are loading"
        elseif incomplete then
            warn = "Some items have no price"
        elseif Data.supremeStale then
            warn = "Price data may be outdated"
        elseif mine.s > 0 and other.s < mine.s * 0.75 then
            warn = "You give noticeably more"
        end
        local wasVisible = UI.hudWarnBar.Visible
        UI.hudWarnBar.Visible = warn ~= nil
        if warn then
            UI.hudWarnText.Text = warn
            UI.hudWarnText.TextColor3 = danger and Palette.neg or Palette.warn
            UI.hudWarnBar.BackgroundColor3 = danger and Palette.negBg or Palette.warnBg
        end
        if wasVisible ~= UI.hudWarnBar.Visible then UI.applyHudSize() end
        UI.hud.Visible = true
    end

    local function pulse()
        Trade.tick = Trade.tick + 1
        local screen, our, theirs = Trade.locate()
        if screen then
            if Trade.closing then Trade.finish(false) end
            local snap = {mine = summarizeOffer(our), other = summarizeOffer(theirs)}
            local sig = table.concat(snap.other.sig, "|")
            if State.tradeActive and State.prevOther ~= "" and sig ~= State.prevOther then
                State.warningUntil = os.clock() + 5
                notify("Their offer changed", "Re-check the items before accepting", Palette.warn)
            end
            State.prevOther = sig
            State.tradeActive = true
            State.latestTrade = snap
            State.activeTradeScreen = screen
            if snap.mine.count + snap.other.count > 0 then State.lastTradeSnapshot = snap end
            updateHud(snap)
        else
            if State.tradeActive then
                State.tradeActive = false
                State.prevOther = ""
                State.latestTrade = nil
                UI.hud.Visible = false
                if State.lastTradeSnapshot then
                    Trade.closing = {snap = State.lastTradeSnapshot, ticks = 15}
                end
                State.lastTradeSnapshot = nil
            end
            if Trade.closing then
                if Trade.successVisible() then
                    Trade.finish(true)
                else
                    Trade.closing.ticks = Trade.closing.ticks - 1
                    if Trade.closing.ticks <= 0 then Trade.finish(false) end
                end
            end
        end
    end

    -- Rare items other players are visibly holding on this server (public info, stored locally).
    local lastSightWrite = 0
    local function scanSightings()
        local jobId = tostring(game.JobId or "")
        if jobId == "" or not Data.loaded then return end
        local now = os.time()
        local changed = false
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                for _, tool in ipairs(p.Character:GetChildren()) do
                    if tool:IsA("Tool") then
                        local row = lookup(tool.Name)
                        if row and row.supreme and row.supreme >= 250 then
                            local key = tostring(p.UserId) .. "|" .. normalize(row.name)
                            local cur = Data.sightings[key]
                            if not cur or now - cur.at > 60 then
                                Data.sightings[key] = {
                                    jobId = jobId, placeId = game.PlaceId, at = now,
                                    name = row.name, value = row.supreme, player = tostring(p.DisplayName or p.Name)
                                }
                                changed = true
                            end
                        end
                    end
                end
            end
        end
        local count = 0
        for k, item in pairs(Data.sightings) do
            if type(item) ~= "table" or now - (item.at or 0) > 1800 then
                Data.sightings[k] = nil
                changed = true
            else
                count = count + 1
            end
        end
        if changed and os.clock() - lastSightWrite > 10 and count <= 60 then
            lastSightWrite = os.clock()
            Store.write(Config.SIGHTINGS_FILE, Data.sightings)
        end
    end

    ----------------------------------------------------------------------
    -- Main window
    ----------------------------------------------------------------------
    local WIN_W, WIN_H = 560, 360
    local TAB_NAMES = {"Trade", "Values", "Compare", "Inventory", "Servers", "Settings"}
    local Tabs = {}
    local Win = {order = 0, tabButtons = {}}
    local function ord()
        Win.order = Win.order + 1
        return Win.order
    end

    UI.win = mk("Frame", {
        Name = "Window",
        Position = UDim2.fromOffset(60, 60),
        Size = UDim2.fromOffset(WIN_W, WIN_H),
        BackgroundColor3 = Palette.canvas,
        BorderSizePixel = 0,
        Visible = false,
        Active = true,
        ClipsDescendants = true,
        ZIndex = 70
    }, UI.root)
    corner(UI.win, 12)
    stroke(UI.win, Palette.hairline, 0, 1)
    Win.scale = mk("UIScale", {Scale = 1}, UI.win)

    local header = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Palette.sidebar,
        BorderSizePixel = 0, Active = true, ZIndex = 72
    }, UI.win)
    mk("Frame", {
        Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Palette.hairline, BorderSizePixel = 0, ZIndex = 73
    }, header)
    label(header, "CARBON X", {
        Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(100, 36),
        Font = Enum.Font.GothamBold, TextSize = 12, ZIndex = 73
    })
    Win.title = label(header, "Trade", {
        Position = UDim2.fromOffset(134, 0), Size = UDim2.new(1, -190, 1, 0),
        Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Palette.subtext, ZIndex = 73
    })
    button(header, "x", "ghost", {
        Position = UDim2.new(1, -34, 0, 6), Size = UDim2.fromOffset(24, 24), TextSize = 13, ZIndex = 74
    }, function() UI.setWindow(false) end)
    makeDraggable(UI.win, header)

    Win.side = mk("Frame", {
        Position = UDim2.fromOffset(0, 36), Size = UDim2.new(0, 120, 1, -36),
        BackgroundColor3 = Palette.sidebar, BorderSizePixel = 0, ZIndex = 71
    }, UI.win)
    mk("Frame", {
        Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0),
        BackgroundColor3 = Palette.hairline, BorderSizePixel = 0, ZIndex = 72
    }, Win.side)
    Win.indicator = mk("Frame", {
        Position = UDim2.fromOffset(0, 18), Size = UDim2.fromOffset(3, 14),
        BackgroundColor3 = Palette.accent, BorderSizePixel = 0, ZIndex = 74
    }, Win.side)
    corner(Win.indicator, 2)

    Win.status = label(Win.side, "", {
        Position = UDim2.new(0, 10, 1, -44), Size = UDim2.new(1, -20, 0, 36),
        TextSize = 9, TextColor3 = Palette.muted, TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Bottom, TextTruncate = Enum.TextTruncate.None, ZIndex = 73
    })

    Win.content = mk("Frame", {
        Position = UDim2.fromOffset(120, 36), Size = UDim2.new(1, -120, 1, -36),
        BackgroundTransparency = 1, ZIndex = 71
    }, UI.win)

    function Win.paintTabs()
        for i, name in ipairs(TAB_NAMES) do
            local b = Win.tabButtons[name]
            if b then
                local active = State.currentTab == name
                b.BackgroundTransparency = active and 0 or 1
                b.BackgroundColor3 = Palette.elevated
                b.TextColor3 = active and Palette.text or Palette.subtext
                if active then
                    tween(Win.indicator, {Position = UDim2.fromOffset(0, 10 + (i - 1) * 34 + 8)}, 0.14)
                end
            end
        end
    end

    for i, name in ipairs(TAB_NAMES) do
        local b = mk("TextButton", {
            Name = name .. "Tab", Position = UDim2.fromOffset(8, 10 + (i - 1) * 34),
            Size = UDim2.new(1, -16, 0, 30), BackgroundColor3 = Palette.elevated, BackgroundTransparency = 1,
            Text = name, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Palette.subtext,
            TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 73
        }, Win.side)
        corner(b, 7)
        pad(b, 0, 0, 0, 12)
        Win.tabButtons[name] = b
        attach(b.MouseEnter, function()
            if State.currentTab ~= name then
                b.BackgroundTransparency = 0.4
                b.TextColor3 = Palette.text
            end
        end)
        attach(b.MouseLeave, function()
            if State.currentTab ~= name then
                b.BackgroundTransparency = 1
                b.TextColor3 = Palette.subtext
            end
        end)
        attach(b.MouseButton1Click, function()
            if State.alive then UI.selectTab(name) end
        end)
    end

    function Win.newPage()
        disconnectBag(State.tabConns)
        if Win.page then pcall(function() Win.page:Destroy() end) end
        Win.order = 0
        Win.refresh = nil
        Win.page = mk("ScrollingFrame", {
            Name = "Page", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = Palette.focus,
            CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 72
        }, Win.content)
        pad(Win.page, 12, 14, 12, 12)
        vlist(Win.page, 8)
        return Win.page
    end

    ----------------------------------------------------------------------
    -- Page widgets
    ----------------------------------------------------------------------
    local function heading(parent, text)
        return label(parent, string.upper(text), {
            Size = UDim2.new(1, 0, 0, 16), Font = Enum.Font.GothamBold, TextSize = 10,
            TextColor3 = Palette.muted, LayoutOrder = ord(), ZIndex = 73
        })
    end

    local function card(parent)
        local c = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Palette.surface, BorderSizePixel = 0, LayoutOrder = ord(), ZIndex = 73
        }, parent)
        corner(c, 8)
        stroke(c, Palette.hairline, 0, 1)
        pad(c, 10)
        vlist(c, 6)
        return c
    end

    local function kv(parent, key, value, color)
        local f = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, LayoutOrder = ord(), ZIndex = 74
        }, parent)
        label(f, key, {Size = UDim2.new(0.5, 0, 1, 0), TextColor3 = Palette.subtext, TextSize = 11, ZIndex = 75})
        label(f, tostring(value), {
            Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.5, 1),
            TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = color or Palette.text,
            TextSize = 11, Font = Enum.Font.GothamMedium, ZIndex = 75
        })
        return f
    end

    local function note(parent, text, color)
        return label(parent, text, {
            Size = UDim2.new(1, 0, 0, 24), TextSize = 11, TextColor3 = color or Palette.muted,
            LayoutOrder = ord(), ZIndex = 74
        })
    end

    local function listRow(parent, title, right, sub, rightColor)
        local h = sub and 38 or 28
        local f = mk("Frame", {
            Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = Palette.surface, BorderSizePixel = 0,
            LayoutOrder = ord(), ZIndex = 73
        }, parent)
        corner(f, 6)
        label(f, title, {
            Position = UDim2.fromOffset(10, sub and 3 or 0), Size = UDim2.new(1, -120, 0, sub and 18 or h),
            Font = Enum.Font.GothamBold, TextSize = 11, ZIndex = 74
        })
        label(f, right or "", {
            Position = UDim2.new(1, -110, 0, sub and 3 or 0), Size = UDim2.fromOffset(100, sub and 18 or h),
            TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = rightColor or Palette.subtext,
            Font = Enum.Font.GothamMedium, TextSize = 11, ZIndex = 74
        })
        if sub then
            label(f, sub, {
                Position = UDim2.fromOffset(10, 21), Size = UDim2.new(1, -20, 0, 14),
                TextSize = 10, TextColor3 = Palette.muted, ZIndex = 74
            })
        end
        return f
    end

    local function hrow(parent, h)
        local f = mk("Frame", {
            Size = UDim2.new(1, 0, 0, h or 28), BackgroundTransparency = 1, LayoutOrder = ord(), ZIndex = 73
        }, parent)
        mk("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center
        }, f)
        return f
    end

    local function holderFrame(parent)
        local f = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1, LayoutOrder = ord(), ZIndex = 73
        }, parent)
        vlist(f, 4)
        return f
    end

    local function clearChildren(f)
        for _, c in ipairs(f:GetChildren()) do
            if c:IsA("GuiObject") then c:Destroy() end
        end
    end

    local function chip(parent, text, w, onClick)
        local active = false
        local b = mk("TextButton", {
            Text = text, Size = UDim2.fromOffset(w, 26), BackgroundColor3 = Palette.elevated,
            TextColor3 = Palette.subtext, Font = Enum.Font.GothamMedium, TextSize = 11,
            AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = ord(), ZIndex = 74
        }, parent)
        corner(b, 7)
        local function paint(hover)
            tween(b, {
                BackgroundColor3 = active and Palette.accent or (hover and Palette.hover or Palette.elevated),
                TextColor3 = active and Palette.accentFg or (hover and Palette.text or Palette.subtext)
            }, 0.1)
        end
        attach(b.MouseEnter, function() paint(true) end, State.tabConns)
        attach(b.MouseLeave, function() paint(false) end, State.tabConns)
        attach(b.MouseButton1Click, function()
            if State.alive and onClick then onClick() end
        end, State.tabConns)
        return b, function(v)
            active = v
            paint(false)
        end
    end

    local function miniToggle(parent, text, rightOffset, w, isOn, onChange)
        local on = isOn()
        local b = mk("TextButton", {
            Text = text, Position = UDim2.new(1, -rightOffset, 0.5, -10), Size = UDim2.fromOffset(w, 20),
            BackgroundColor3 = on and Palette.accent or Palette.elevated,
            TextColor3 = on and Palette.accentFg or Palette.subtext,
            Font = Enum.Font.GothamBold, TextSize = 9, AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 75
        }, parent)
        corner(b, 5)
        attach(b.MouseButton1Click, function()
            on = not on
            b.BackgroundColor3 = on and Palette.accent or Palette.elevated
            b.TextColor3 = on and Palette.accentFg or Palette.subtext
            onChange(on)
        end, State.tabConns)
        return b
    end

    local function copyOrNotify(text, okTitle)
        if copyClipboard(text) then
            notify(okTitle or "Copied", "Saved to clipboard", Palette.pos)
        else
            notify("Clipboard unavailable", "This executor has no clipboard function", Palette.warn)
        end
    end

    local function openLink(url, title)
        State.selectedUrl = url
        if openBrowserUrl(url) then
            notify("Opening", title or "Link sent to your browser", Palette.pos)
        elseif copyClipboard(url) then
            notify("Link copied", "Paste it into your browser", Palette.warn)
        else
            notify("Cannot open link", "No browser or clipboard function available", Palette.neg)
        end
    end

    ----------------------------------------------------------------------
    -- Tabs
    ----------------------------------------------------------------------
    Tabs.Trade = function(page)
        heading(page, "Price data")
        local c = card(page)
        kv(c, "Supreme", Data.loaded and (Data.supremeStamp .. (Data.supremeStale and "  (old)" or "")) or "-",
            Data.supremeStale and Palette.warn or Palette.pos)
        kv(c, "MM2 archive", Data.loaded and (Data.mm2Stamp .. (Data.mm2Stale and "  (old)" or "")) or "-",
            Data.mm2Stale and Palette.warn or Palette.pos)
        kv(c, "Items indexed", tostring(#Data.itemsList))
        kv(c, "Status", Data.loading and "Refreshing..." or (Data.lastError or "OK"),
            (Data.lastError and not Data.loading) and Palette.warn or Palette.text)
        local actions = hrow(c, 28)
        button(actions, "Refresh prices", "primary", {Size = UDim2.fromOffset(110, 26), LayoutOrder = ord(), ZIndex = 75}, function()
            notify("Prices", "Refreshing...", Palette.subtext)
            task.spawn(function()
                pcall(Net.loadPrices)
                Data.loading = false
            end)
        end, State.tabConns)
        button(actions, "Open Supreme", "default", {Size = UDim2.fromOffset(104, 26), LayoutOrder = ord(), ZIndex = 75}, function()
            openLink(Config.OFFICIAL_SITE, "Supreme Values")
        end, State.tabConns)
        button(actions, "Copy link", "default", {Size = UDim2.fromOffset(80, 26), LayoutOrder = ord(), ZIndex = 75}, function()
            copyOrNotify(Config.OFFICIAL_SITE, "Link copied")
        end, State.tabConns)

        heading(page, "Rare items seen on this server")
        local list = {}
        local now = os.time()
        for _, s in pairs(Data.sightings) do
            if type(s) == "table" and s.jobId == tostring(game.JobId) and now - (s.at or 0) < 1800 then
                list[#list + 1] = s
            end
        end
        table.sort(list, function(a, b) return (a.value or 0) > (b.value or 0) end)
        if #list == 0 then
            note(page, "Nothing noticed yet. Items others hold in hand appear here.")
        else
            for i = 1, math.min(#list, 5) do
                local s = list[i]
                listRow(page, tostring(s.name), "S " .. formatVal(s.value), tostring(s.player) .. "  -  " .. Util.ago(s.at))
            end
        end

        heading(page, "Recent trades")
        if #Data.history == 0 then
            note(page, "No trades recorded yet.")
        else
            for i = 1, math.min(#Data.history, 8) do
                local h = Data.history[i]
                local when = tostring(h.at)
                pcall(function() when = os.date("%H:%M", h.at) end)
                local confirmed = h.status == "CONFIRMED"
                listRow(page, when .. "   " .. (confirmed and "COMPLETED" or "CLOSED"),
                    h.delta and (Util.signed(h.delta) .. " S") or "-",
                    "gave: " .. tostring(h.give or "-") .. "  /  got: " .. tostring(h.get or "-"),
                    h.delta and (h.delta > 0 and Palette.pos or (h.delta < 0 and Palette.neg or Palette.subtext)) or Palette.subtext)
            end
            button(page, "Clear history", "danger", {Size = UDim2.fromOffset(100, 26), LayoutOrder = ord(), ZIndex = 75}, function()
                Data.history = {}
                Store.write(Config.HISTORY_FILE, Data.history)
                UI.selectTab("Trade")
            end, State.tabConns)
        end
        Win.refresh = function() UI.selectTab("Trade") end
    end

    Tabs.Values = function(page)
        local box = inputBox(page, "Search items (e.g. harvester, chroma luger)", State.valueSearch, {
            Size = UDim2.new(1, 0, 0, 30), LayoutOrder = ord(), ZIndex = 73
        })
        local chips = hrow(page, 26)
        local info = label(page, "", {
            Size = UDim2.new(1, 0, 0, 14), TextSize = 10, TextColor3 = Palette.muted, LayoutOrder = ord(), ZIndex = 73
        })
        local holder = holderFrame(page)
        local render

        local setters = {}
        for _, f in ipairs({"All", "Favs", "Wish"}) do
            local _, set = chip(chips, f, 54, function()
                State.valueFilter = f
                for name, fn in pairs(setters) do fn(name == f) end
                render()
            end)
            setters[f] = set
        end
        if not setters[State.valueFilter] then State.valueFilter = "All" end
        setters[State.valueFilter](true)

        local function itemRow(row)
            local f = mk("Frame", {
                Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Palette.surface, BorderSizePixel = 0,
                LayoutOrder = ord(), ZIndex = 73
            }, holder)
            corner(f, 6)
            label(f, row.name, {
                Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -214, 1, 0),
                Font = Enum.Font.GothamMedium, TextSize = 11, ZIndex = 74
            })
            label(f, "S " .. formatVal(row.supreme), {
                Position = UDim2.new(1, -204, 0, 0), Size = UDim2.fromOffset(62, 30),
                TextXAlignment = Enum.TextXAlignment.Right, TextSize = 11, ZIndex = 74
            })
            label(f, "M " .. formatVal(safeMM2(row)), {
                Position = UDim2.new(1, -140, 0, 0), Size = UDim2.fromOffset(58, 30),
                TextXAlignment = Enum.TextXAlignment.Right, TextSize = 11, TextColor3 = Palette.subtext, ZIndex = 74
            })
            miniToggle(f, "FAV", 78, 34, function() return Prefs.favs[row.name] == true end, function(on)
                Prefs.favs[row.name] = on or nil
                Store.savePrefs()
                if State.valueFilter == "Favs" then render() end
            end)
            miniToggle(f, "WISH", 40, 34, function() return Prefs.wishlist[row.name] == true end, function(on)
                Prefs.wishlist[row.name] = on or nil
                Store.savePrefs()
                if State.valueFilter == "Wish" then render() end
            end)
        end

        render = function()
            clearChildren(holder)
            if not Data.loaded then
                note(holder, "Prices are loading...")
                info.Text = ""
                return
            end
            local q = normalize(State.valueSearch)
            local shown, total = 0, 0
            for _, row in ipairs(Data.itemsList) do
                local match = true
                if q ~= "" then
                    row._k = row._k or normalize(row.name)
                    match = row._k:find(q, 1, true) ~= nil
                end
                if match and State.valueFilter == "Favs" then match = Prefs.favs[row.name] == true end
                if match and State.valueFilter == "Wish" then match = Prefs.wishlist[row.name] == true end
                if match then
                    total = total + 1
                    if shown < 40 then
                        shown = shown + 1
                        itemRow(row)
                    end
                end
            end
            info.Text = "Showing " .. shown .. " of " .. total
            if total == 0 then note(holder, "No items match.") end
        end

        local token = 0
        attach(box:GetPropertyChangedSignal("Text"), function()
            State.valueSearch = box.Text
            token = token + 1
            local mine = token
            task.delay(0.25, function()
                if State.alive and token == mine and box.Parent then pcall(render) end
            end)
        end, State.tabConns)
        Win.refresh = render
        render()
    end

    Tabs.Compare = function(page)
        local function build(initial, key)
            local box = inputBox(page, "Item name", initial, {Size = UDim2.new(1, 0, 0, 30), LayoutOrder = ord(), ZIndex = 73})
            local c = card(page)
            return box, c
        end

        local boxA, cardA = build(State.compareA, "compareA")
        local boxB, cardB = build(State.compareB, "compareB")
        local summary = card(page)

        local function fill(c, text)
            clearChildren(c)
            local row = Util.resolve(text)
            if not row then
                note(c, Data.loaded and "Item not found." or "Prices are loading...")
                return nil
            end
            label(c, row.name, {
                Size = UDim2.new(1, 0, 0, 18), Font = Enum.Font.GothamBold, TextSize = 12,
                LayoutOrder = ord(), ZIndex = 74
            })
            kv(c, "Supreme value", formatVal(row.supreme))
            kv(c, "MM2 value", formatVal(safeMM2(row)))
            kv(c, "Demand", row.demand and (formatVal(row.demand) .. " / 10") or "-")
            kv(c, "Rarity", row.rarity and (formatVal(row.rarity) .. " / 10") or "-")
            kv(c, "Recent change", row.change and Util.signed(row.change) or "-",
                row.change and (row.change > 0 and Palette.pos or (row.change < 0 and Palette.neg or Palette.text)) or Palette.text)
            kv(c, "Stability", (row.stability and row.stability ~= "") and row.stability or "-")
            kv(c, "Origin", (row.origin and row.origin ~= "") and row.origin or "-")
            return row
        end

        local function update()
            local a = fill(cardA, State.compareA)
            local b = fill(cardB, State.compareB)
            clearChildren(summary)
            if a and b and a.supreme and b.supreme and a.supreme > 0 and b.supreme > 0 then
                local ratio = a.supreme / b.supreme
                kv(summary, a.name .. " vs " .. b.name, string.format("%.2f x", ratio))
                local diff = a.supreme - b.supreme
                kv(summary, "Difference (Supreme)", Util.signed(diff), diff > 0 and Palette.pos or (diff < 0 and Palette.neg or Palette.text))
            else
                note(summary, "Pick two priced items to compare them.")
            end
        end

        local token = 0
        local function watch(box, field)
            attach(box:GetPropertyChangedSignal("Text"), function()
                State[field] = box.Text
                token = token + 1
                local mine = token
                task.delay(0.3, function()
                    if State.alive and token == mine and box.Parent then pcall(update) end
                end)
            end, State.tabConns)
        end
        watch(boxA, "compareA")
        watch(boxB, "compareB")
        Win.refresh = update
        update()
    end

    Tabs.Inventory = function(page)
        local totals = card(page)
        local addRow = hrow(page, 30)
        local nameBox = inputBox(addRow, "Item name", State.invQuery, {Size = UDim2.fromOffset(230, 30), LayoutOrder = ord(), ZIndex = 73})
        local qtyBox = inputBox(addRow, "Qty", State.invQty, {Size = UDim2.fromOffset(56, 30), LayoutOrder = ord(), ZIndex = 73})
        local holder
        local render

        attach(nameBox:GetPropertyChangedSignal("Text"), function() State.invQuery = nameBox.Text end, State.tabConns)
        attach(qtyBox:GetPropertyChangedSignal("Text"), function() State.invQty = qtyBox.Text end, State.tabConns)

        button(addRow, "Add", "primary", {Size = UDim2.fromOffset(70, 30), LayoutOrder = ord(), ZIndex = 75}, function()
            local row = Util.resolve(State.invQuery)
            if not row then
                notify("Not found", "No item matches that name", Palette.warn)
                return
            end
            local qty = math.floor(tonumber(State.invQty) or 1)
            qty = math.max(1, math.min(9999, qty))
            local merged = false
            for _, it in ipairs(Prefs.myItems) do
                if it.name == row.name then
                    it.qty = math.min(9999, (tonumber(it.qty) or 0) + qty)
                    merged = true
                    break
                end
            end
            if not merged then
                if #Prefs.myItems >= 60 then
                    notify("List full", "Remove an item first", Palette.warn)
                    return
                end
                Prefs.myItems[#Prefs.myItems + 1] = {name = row.name, qty = qty}
            end
            Store.savePrefs()
            nameBox.Text = ""
            State.invQuery = ""
            render()
        end, State.tabConns)

        holder = holderFrame(page)

        render = function()
            clearChildren(totals)
            clearChildren(holder)
            local s, m, missS, missM = 0, 0, 0, 0
            for _, it in ipairs(Prefs.myItems) do
                local qty = tonumber(it.qty) or 1
                local row = lookup(it.name)
                local sv, mv = row and row.supreme, safeMM2(row)
                if sv then s = s + sv * qty else missS = missS + 1 end
                if mv then m = m + mv * qty else missM = missM + 1 end
            end
            kv(totals, "Items", tostring(#Prefs.myItems))
            kv(totals, "Total (Supreme)", formatVal(s) .. (missS > 0 and "+?" or ""), missS > 0 and Palette.warn or Palette.text)
            kv(totals, "Total (MM2)", formatVal(m) .. (missM > 0 and "+?" or ""), missM > 0 and Palette.warn or Palette.text)
            if #Prefs.myItems == 0 then
                note(holder, "Add items you own to track their combined value.")
                return
            end
            for idx, it in ipairs(Prefs.myItems) do
                local qty = tonumber(it.qty) or 1
                local row = lookup(it.name)
                local f = mk("Frame", {
                    Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Palette.surface, BorderSizePixel = 0,
                    LayoutOrder = ord(), ZIndex = 73
                }, holder)
                corner(f, 6)
                label(f, tostring(it.name) .. "  x" .. qty, {
                    Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -150, 1, 0),
                    Font = Enum.Font.GothamMedium, TextSize = 11, ZIndex = 74
                })
                label(f, row and row.supreme and ("S " .. formatVal(row.supreme * qty)) or "no price", {
                    Position = UDim2.new(1, -140, 0, 0), Size = UDim2.fromOffset(90, 30),
                    TextXAlignment = Enum.TextXAlignment.Right, TextSize = 11,
                    TextColor3 = (row and row.supreme) and Palette.text or Palette.warn, ZIndex = 74
                })
                button(f, "x", "danger", {
                    Position = UDim2.new(1, -40, 0.5, -11), Size = UDim2.fromOffset(30, 22), TextSize = 11, ZIndex = 75
                }, function()
                    table.remove(Prefs.myItems, idx)
                    Store.savePrefs()
                    render()
                end, State.tabConns)
            end
        end
        Win.refresh = render
        render()
    end

    Tabs.Servers = function(page)
        local chips = hrow(page, 26)
        local holder = holderFrame(page)
        local pager = hrow(page, 28)
        local pageLbl
        local render

        local setters = {}
        for _, cat in ipairs({"ANY", "AGE", "HIGH", "ALL"}) do
            local _, set = chip(chips, cat, 54, function()
                State.serverCategory = cat
                State.serverPage = 1
                for name, fn in pairs(setters) do fn(name == cat) end
                render()
            end)
            setters[cat] = set
        end
        if not setters[State.serverCategory] then State.serverCategory = "ANY" end
        setters[State.serverCategory](true)

        button(pager, "Prev", "default", {Size = UDim2.fromOffset(60, 26), LayoutOrder = ord(), ZIndex = 75}, function()
            State.serverPage = math.max(1, State.serverPage - 1)
            render()
        end, State.tabConns)
        pageLbl = label(pager, "1 / 1", {
            Size = UDim2.fromOffset(70, 26), TextXAlignment = Enum.TextXAlignment.Center,
            TextSize = 11, TextColor3 = Palette.subtext, LayoutOrder = ord(), ZIndex = 74
        })
        button(pager, "Next", "default", {Size = UDim2.fromOffset(60, 26), LayoutOrder = ord(), ZIndex = 75}, function()
            State.serverPage = State.serverPage + 1
            render()
        end, State.tabConns)

        render = function()
            clearChildren(holder)
            local items = {}
            for _, s in ipairs(Data.servers) do
                if State.serverCategory == "ALL" or s.category == State.serverCategory then
                    items[#items + 1] = s
                end
            end
            local per = 6
            local pages = math.max(1, math.ceil(#items / per))
            State.serverPage = math.max(1, math.min(State.serverPage, pages))
            pageLbl.Text = State.serverPage .. " / " .. pages
            for i = (State.serverPage - 1) * per + 1, math.min(#items, State.serverPage * per) do
                local s = items[i]
                local url = Config.JOIN_PREFIX .. s.code
                local f = mk("Frame", {
                    Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Palette.surface, BorderSizePixel = 0,
                    LayoutOrder = ord(), ZIndex = 73
                }, holder)
                corner(f, 6)
                label(f, s.label, {
                    Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -140, 1, 0),
                    Font = Enum.Font.GothamMedium, TextSize = 11, ZIndex = 74
                })
                button(f, "COPY", "default", {
                    Position = UDim2.new(1, -126, 0.5, -12), Size = UDim2.fromOffset(54, 24), TextSize = 10, ZIndex = 75
                }, function() copyOrNotify(url, "Link copied") end, State.tabConns)
                button(f, "OPEN", "primary", {
                    Position = UDim2.new(1, -64, 0.5, -12), Size = UDim2.fromOffset(54, 24), TextSize = 10, ZIndex = 75
                }, function() openLink(url, s.label) end, State.tabConns)
            end
            if #items == 0 then note(holder, "No servers in this category.") end
        end
        note(page, Data.serverStamp .. ". Links open in your browser or Roblox app; availability is not verified.")
        render()
    end

    Tabs.Settings = function(page)
        heading(page, "Preferences")
        local c = card(page)
        local function setting(title, desc, key, onChange)
            local f = mk("Frame", {
                Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = ord(), ZIndex = 74
            }, c)
            label(f, title, {Size = UDim2.new(1, -50, 0, 18), Font = Enum.Font.GothamBold, TextSize = 11, ZIndex = 75})
            label(f, desc, {
                Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, -50, 0, 16),
                TextSize = 10, TextColor3 = Palette.muted, ZIndex = 75
            })
            local sw = toggleSwitch(f, Prefs[key], function(v)
                Prefs[key] = v
                Store.savePrefs()
                if onChange then pcall(onChange, v) end
            end, State.tabConns)
            sw.Position = UDim2.new(1, -38, 0.5, -10)
            sw.ZIndex = 75
            for _, d in ipairs(sw:GetChildren()) do
                if d:IsA("GuiObject") then d.ZIndex = 76 end
            end
        end
        setting("Value tags", "Show prices on items in the trade window", "showTags", function(v)
            if not v then Trade.hideTags() end
        end)
        setting("Compact HUD", "Smaller trade summary", "compact", function() UI.applyHudSize() end)
        setting("Animations", "Smooth hover and toast effects", "animations")
        setting("Low power mode", "Slower refresh, no animations", "lowPower")
        setting("Reload after teleport", "Re-run the script when you join another server", "autoQueue", function(v)
            if v and not Net.queueReload() then
                notify("Auto reload", "Not supported by this executor", Palette.warn)
            end
        end)

        heading(page, "Actions")
        local actions = hrow(page, 28)
        button(actions, "Reset positions", "default", {Size = UDim2.fromOffset(110, 26), LayoutOrder = ord(), ZIndex = 75}, function()
            Prefs.hudX, Prefs.hudY, Prefs.btnX, Prefs.btnY = 16, 82, -1, 82
            UI.hud.Position = UDim2.fromOffset(16, 82)
            UI.launcher.Position = UDim2.fromOffset(math.max(16, State.screenSize.X - 126), 82)
            Store.savePrefs()
            notify("Positions reset", "HUD and button moved back", Palette.subtext)
        end, State.tabConns)
        button(actions, "Unload script", "danger", {Size = UDim2.fromOffset(100, 26), LayoutOrder = ord(), ZIndex = 75}, function()
            cleanup()
        end, State.tabConns)

        heading(page, "About")
        local about = card(page)
        kv(about, "Menu key", Config.TOGGLE_KEY.Name)
        kv(about, "Mode", "Read-only")
        note(about, "No trade remotes, no auto-accept. Values are estimates, not Robux.")
    end

    function UI.selectTab(name)
        if not Tabs[name] then name = "Trade" end
        State.currentTab = name
        Win.paintTabs()
        Win.title.Text = name
        local page = Win.newPage()
        local okTab, err = pcall(Tabs[name], page)
        if not okTab then
            warn("[Carbon X] Tab '" .. name .. "' failed: " .. tostring(err))
            label(page, "This tab failed to load:\n" .. tostring(err):sub(1, 160), {
                Size = UDim2.new(1, 0, 0, 50), TextColor3 = Palette.neg, TextSize = 11,
                TextWrapped = true, TextTruncate = Enum.TextTruncate.None, ZIndex = 74
            })
        end
    end

    ----------------------------------------------------------------------
    -- Screen fitting, window toggle, launcher
    ----------------------------------------------------------------------
    local function clampInto(frame)
        local abs = frame.AbsoluteSize
        local maxX = math.max(0, State.screenSize.X - abs.X)
        local maxY = math.max(0, State.screenSize.Y - abs.Y)
        frame.Position = UDim2.fromOffset(
            math.clamp(frame.Position.X.Offset, 0, maxX),
            math.clamp(frame.Position.Y.Offset, 0, maxY)
        )
    end

    local function applyLayout()
        refreshScreen()
        local sx, sy = State.screenSize.X, State.screenSize.Y
        Win.scale.Scale = math.clamp(math.min((sx - 16) / WIN_W, (sy - 16) / WIN_H), 0.5, 1)
        UI.hudScale.Scale = math.clamp((sx - 16) / 264, 0.6, 1)
        pcall(clampInto, UI.hud)
        pcall(clampInto, UI.launcher)
        if UI.win.Visible then pcall(clampInto, UI.win) end
    end

    function UI.setWindow(visible)
        if visible then
            applyLayout()
            if not State.firstOpen then
                State.firstOpen = true
                local w, h = WIN_W * Win.scale.Scale, WIN_H * Win.scale.Scale
                UI.win.Position = UDim2.fromOffset(
                    math.max(0, math.floor((State.screenSize.X - w) / 2)),
                    math.max(0, math.floor((State.screenSize.Y - h) / 2))
                )
            end
            UI.win.Visible = true
            pcall(clampInto, UI.win)
            UI.selectTab(State.currentTab)
        else
            UI.win.Visible = false
        end
    end

    function UI.updateStatus()
        local color, text
        if not Data.loaded then
            color, text = Palette.subtext, "Loading prices..."
        elseif Data.lastError or Data.supremeStale then
            color, text = Palette.warn, (Data.lastError or "Prices may be old") .. "\nSupreme " .. Data.supremeStamp
        else
            color, text = Palette.pos, "Prices OK\nSupreme " .. Data.supremeStamp
        end
        State.statusText = text
        UI.launcherDot.BackgroundColor3 = color
        Win.status.Text = text
    end

    attach(UI.launcher.MouseButton1Click, function()
        if didDragLauncher() then return end
        UI.setWindow(not UI.win.Visible)
    end)
    attach(UI.launcher.MouseEnter, function() tween(UI.launcher, {BackgroundColor3 = Palette.elevated}, 0.1) end)
    attach(UI.launcher.MouseLeave, function() tween(UI.launcher, {BackgroundColor3 = Palette.sidebar}, 0.12) end)
    attach(UserInputService.InputBegan, function(input, processed)
        if processed or not State.alive then return end
        if input.KeyCode == Config.TOGGLE_KEY then UI.setWindow(not UI.win.Visible) end
    end)
    attach(UI.root:GetPropertyChangedSignal("AbsoluteSize"), function()
        if State.alive then pcall(applyLayout) end
    end)

    Data.listeners[#Data.listeners + 1] = function()
        if not State.alive then return end
        UI.updateStatus()
        if UI.win.Visible and Win.refresh then pcall(Win.refresh) end
    end

    ----------------------------------------------------------------------
    -- Start
    ----------------------------------------------------------------------
    refreshScreen()
    if Prefs.btnX < 0 then
        UI.launcher.Position = UDim2.fromOffset(math.max(16, State.screenSize.X - 126), Prefs.btnY)
    end
    applyLayout()
    UI.updateStatus()
    if Prefs.autoQueue then Net.queueReload() end

    State.scheduled = true
    task.spawn(function()
        local n = 0
        local lastErr
        while State.alive do
            local okP, err = pcall(pulse)
            if not okP and err ~= lastErr then
                lastErr = err
                warn("[Carbon X] " .. tostring(err))
            end
            n = n + 1
            if n % 6 == 0 then pcall(scanSightings) end
            if n % 20 == 0 then pcall(applyLayout) end
            task.wait(Prefs.lowPower and 0.8 or 0.35)
        end
    end)

    task.spawn(function()
        pcall(Net.readCache)
        pcall(Net.loadPrices)
        Data.loading = false
        while State.alive do
            task.wait(1200)
            if State.alive then
                pcall(Net.loadPrices)
                Data.loading = false
            end
        end
    end)

    notify("Carbon X ready", "Press " .. Config.TOGGLE_KEY.Name .. " or tap the button", Palette.pos)
end, function(err)
    if debug and type(debug.traceback) == "function" then
        return debug.traceback(tostring(err), 2)
    end
    return tostring(err)
end)

if not ok then
    warn("[Carbon X] " .. tostring(failure))
    pcall(function()
        local env = (type(getgenv) == "function" and getgenv()) or _G
        if type(env.MM2CarbonCleanup) == "function" then env.MM2CarbonCleanup() end
    end)
    pcall(function()
        local pg = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui", 5)
        if not pg then return end
        local old = pg:FindFirstChild("MM2CarbonXError")
        if old then old:Destroy() end
        local g = Instance.new("ScreenGui")
        g.Name = "MM2CarbonXError"
        g.ResetOnSpawn = false
        g.DisplayOrder = 10001
        g.Parent = pg
        local t = Instance.new("TextLabel")
        t.Size = UDim2.fromOffset(320, 84)
        t.Position = UDim2.new(0.5, -160, 0, 64)
        t.BackgroundColor3 = Color3.fromRGB(34, 20, 22)
        t.TextColor3 = Color3.fromRGB(240, 200, 200)
        t.TextWrapped = true
        t.TextSize = 12
        t.Font = Enum.Font.Gotham
        t.Text = "CARBON X FAILED\n" .. tostring(failure):sub(1, 240)
        t.Parent = g
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 10)
        c.Parent = t
    end)
end
