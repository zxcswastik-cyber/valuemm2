-- MM2 CARBON | Read-Only Trading Dashboard (Carbon White Edition)
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
        warn("[Carbon] Unsupported experience: " .. tostring(game.GameId))
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

    -- Carbon White / Clean Enterprise Web Palette
    local Palette = {
        canvas = Color3.fromRGB(244, 245, 247),      -- #F4F5F7 Off-white app background
        surface = Color3.fromRGB(255, 255, 255),     -- #FFFFFF Pure white cards & panels
        subtle = Color3.fromRGB(248, 249, 251),      -- #F8F9FB Table header & inset well
        hover = Color3.fromRGB(238, 241, 246),       -- #EEF1F6 Row & button hover
        border = Color3.fromRGB(224, 228, 235),      -- #E0E4EB 1px structural hairline
        borderStrong = Color3.fromRGB(184, 192, 206),-- #B8C0CE Active input border

        ink = Color3.fromRGB(17, 24, 39),            -- #111827 Primary charcoal ink
        inkSecondary = Color3.fromRGB(75, 85, 99),   -- #4B5563 Secondary text
        inkMuted = Color3.fromRGB(134, 144, 160),    -- #8690A0 Table headers & labels

        accent = Color3.fromRGB(17, 24, 39),         -- #111827 Carbon Onyx primary action
        accentHover = Color3.fromRGB(38, 46, 64),
        accentFg = Color3.fromRGB(255, 255, 255),

        svInk = Color3.fromRGB(168, 98, 8),          -- #A86208 Supreme Values amber
        svBg = Color3.fromRGB(254, 247, 232),        -- #FEF7E8
        mvInk = Color3.fromRGB(15, 98, 254),         -- #0F62FE IBM Carbon Blue (MM2Values)
        mvBg = Color3.fromRGB(237, 244, 255),        -- #EDF4FF

        pos = Color3.fromRGB(14, 130, 72),           -- #0E8248 Positive / Win
        posBg = Color3.fromRGB(232, 248, 240),       -- #E8F8F0
        neg = Color3.fromRGB(218, 30, 40),           -- #DA1E28 Negative / Loss
        negBg = Color3.fromRGB(253, 237, 238),       -- #FDEDEE
        warn = Color3.fromRGB(176, 100, 10),         -- #B0640A Warning
        warnBg = Color3.fromRGB(254, 245, 230)       -- #FEF5E6
    }

    local State = {
        alive = true,
        conns = {},
        tabConns = {},
        tradeConns = {},
        created = {},
        badges = setmetatable({}, {__mode = "k"}),
        screenSize = Vector2.new(1280, 720),

        currentTab = "Overview",
        tradeActive = false,
        latestTrade = nil,
        lastTradeSnapshot = nil,
        activeTradeScreen = nil,
        scheduled = false,
        firstOpen = false,
        prevOther = "",
        warningUntil = 0,
        toastId = 0,
        hudCollapsed = false,
        statusText = "Syncing...",

        valueSearch = "",
        valueFilter = "All",
        valueSort = "SV_DESC",
        valuePage = 1,
        compareA = "Harvester",
        compareB = "Elderwood Scythe",
        invQuery = "",
        invQty = "1",
        serverCategory = "ANY",
        serverPage = 1
    }

    local Data = {
        index = {},
        itemsList = {},
        loaded = false,
        loading = false,
        lastFetchAt = 0,
        supremeStamp = "-",
        mm2Stamp = "-",
        supremeStale = true,
        mm2Stale = true,
        lastError = nil,
        listeners = {},
        history = {},
        sightings = {},
        serverStamp = "Directory",
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
        currencyMode = "BOTH",
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

    local function stripRichText(s)
        return tostring(s or ""):gsub("<[^>]+>", "")
    end

    local function trim(s)
        return stripRichText(s):match("^%s*(.-)%s*$")
    end

    local function normalize(s)
        local clean = trim(s):lower()
        clean = clean:gsub("&", " and ")
        clean = clean:gsub("^c%.%s*", "chroma ")
        clean = clean:gsub("^c%s+", "chroma ")
        if clean:find("%(chroma%)") or clean:find("%[chroma%]") then
            clean = "chroma " .. clean:gsub("%(chroma%)", ""):gsub("%[chroma%]", "")
        end
        return (clean:gsub("[^%w]", ""))
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
                    elseif k == "currencyMode" then
                        if v == "BOTH" or v == "SV" or v == "MV" then Prefs[k] = v end
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

    ----------------------------------------------------------------------
    -- Live Price Engine
    ----------------------------------------------------------------------
    local Net = {}
    local reqFn = (type(syn) == "table" and syn.request)
        or (type(http) == "table" and http.request)
        or http_request or request
    if type(reqFn) ~= "function" then reqFn = nil end

    local function withCacheBust(url)
        local sep = url:find("?", 1, true) and "&" or "?"
        return url .. sep .. "_cb=" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
    end

    function Net.fetch(url)
        local freshUrl = withCacheBust(url)
        if reqFn then
            local okReq, resp = pcall(reqFn, {
                Url = freshUrl,
                Method = "GET",
                Headers = {
                    Accept = "*/*",
                    ["Cache-Control"] = "no-cache, no-store, must-revalidate",
                    Pragma = "no-cache"
                }
            })
            if okReq and type(resp) == "table" then
                local status = tonumber(resp.StatusCode or resp.Status or (resp.Success and 200))
                local body = resp.Body or resp.body
                if status == 200 and type(body) == "string" and #body > 0 then return body end
            end
        end
        local okGet, body = pcall(function() return game:HttpGet(freshUrl, true) end)
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

    local function registerAliases(index, row)
        local k = normalize(row.name)
        if k == "" then return end
        index[k] = row
        if k:sub(1, 6) == "chroma" then
            local base = k:sub(7)
            if base ~= "" then
                if not index[base .. "chroma"] then index[base .. "chroma"] = row end
                if not index["c" .. base] then index["c" .. base] = row end
            end
        end
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
                            local row = {
                                name = name,
                                supreme = value,
                                category = trim(f[2]),
                                demand = parseNum(f[4]),
                                rarity = parseNum(f[5]),
                                change = tonumber(f[6]),
                                stability = trim(f[7]),
                                origin = trim(f[8] or "")
                            }
                            registerAliases(data, row)
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
                        row = {name = trim(item.name), category = trim(item.category or item.rarity or "")}
                        registerAliases(index, row)
                    end
                    local mm2Val = parseNum(item.mm2 or item.mv)
                    if mm2Val then row.mm2 = mm2Val end
                    if not row.supreme then
                        local fallbackSup = parseNum(item.supreme or item.sv or item.value)
                        if fallbackSup then row.supreme = fallbackSup end
                    end
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
        if not fromCache then Data.lastFetchAt = os.time() end
        Data.supremeStamp = haveSup and tostring(meta and meta.last_updated or "-"):sub(1, 10) or "Offline"
        Data.mm2Stamp = haveMM2 and tostring(archive.updatedAt or "-"):sub(1, 10) or "Offline"
        local sd, md = ageDays(Data.supremeStamp), ageDays(Data.mm2Stamp)
        Data.supremeStale = (not sd) or sd > 4
        Data.mm2Stale = (not md) or md > 7
        Data.lastError = fromCache and "Cached" or (not haveSup and "Supreme offline" or nil)
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
        for _, cb in ipairs(Data.listeners) do pcall(cb) end
        local csv = Net.fetch(Config.URL_SUPREME)
        local meta = readJson(Net.fetch(Config.URL_META))
        local archive = readJson(Net.fetch(Config.URL_MM2))
        if not archive then
            local old = Store.read(Config.PRICE_CACHE)
            if old then archive = old.archive end
        end
        if not State.alive then Data.loading = false; return end
        local parsed = parseSupreme(csv) or {}
        if not commitPrices(parsed, meta, archive, false) then
            Data.lastError = "Offline"
            if not Data.loaded then Net.readCache() end
        else
            if csv then Store.write(Config.PRICE_CACHE, {supreme = csv, meta = meta, archive = archive}) end
        end
        Data.loading = false
        for _, cb in ipairs(Data.listeners) do pcall(cb) end
    end

    local function ensureFreshPrices(maxAgeSec)
        if Data.loading or not State.alive then return end
        if os.time() - Data.lastFetchAt > (maxAgeSec or 120) then
            task.spawn(function()
                pcall(Net.loadPrices)
                Data.loading = false
            end)
        end
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
            if a / b > 30 then return nil end
        end
        return row.mm2
    end

    ----------------------------------------------------------------------
    -- UI Primitives (Carbon White System)
    ----------------------------------------------------------------------
    local function mk(className, props, parent)
        local inst = Instance.new(className)
        for k, v in pairs(props or {}) do inst[k] = v end
        inst.Parent = parent
        return inst
    end

    local function corner(obj, r)
        return mk("UICorner", {CornerRadius = UDim.new(0, r or 6)}, obj)
    end

    local function stroke(obj, color, trans, thickness)
        return mk("UIStroke", {
            Color = color or Palette.border,
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
            Padding = UDim.new(0, gap or 10)
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
            TextColor3 = Palette.ink,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            BorderSizePixel = 0
        }
        for k, v in pairs(props or {}) do p[k] = v end
        return mk("TextLabel", p, parent)
    end

    local function pill(parent, text, fg, bg, props)
        local p = {
            Text = tostring(text or ""),
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            TextColor3 = fg or Palette.inkSecondary,
            BackgroundColor3 = bg or Palette.subtle,
            BackgroundTransparency = 0,
            TextXAlignment = Enum.TextXAlignment.Center,
            BorderSizePixel = 0
        }
        for k, v in pairs(props or {}) do p[k] = v end
        local l = mk("TextLabel", p, parent)
        corner(l, 5)
        return l
    end

    local function button(parent, text, style, props, onClick, bucket)
        local isPrimary = style == "primary"
        local isDanger = style == "danger"
        local isGhost = style == "ghost"

        local bg = isPrimary and Palette.accent
            or (isDanger and Palette.negBg
            or (isGhost and Palette.surface or Palette.surface))
        local bgHover = isPrimary and Palette.accentHover
            or (isDanger and Color3.fromRGB(249, 222, 224)
            or Palette.hover)
        local fg = isPrimary and Palette.accentFg
            or (isDanger and Palette.neg
            or (isGhost and Palette.inkSecondary or Palette.ink))

        local p = {
            Text = tostring(text or ""),
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextColor3 = fg,
            BackgroundColor3 = bg,
            BackgroundTransparency = isGhost and 1 or 0,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Active = true
        }
        for k, v in pairs(props or {}) do p[k] = v end
        local b = mk("TextButton", p, parent)
        corner(b, 6)
        if not isGhost and not isPrimary then
            stroke(b, isDanger and Color3.fromRGB(245, 198, 202) or Palette.border, 0, 1)
        end

        attach(b.MouseEnter, function()
            tween(b, {
                BackgroundColor3 = bgHover,
                BackgroundTransparency = 0,
                TextColor3 = isPrimary and Palette.accentFg or (isDanger and Palette.neg or Palette.ink)
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
            BackgroundColor3 = Palette.surface,
            TextColor3 = Palette.ink,
            PlaceholderColor3 = Palette.inkMuted,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            BorderSizePixel = 0
        }
        for k, v in pairs(props or {}) do p[k] = v end
        local box = mk("TextBox", p, parent)
        corner(box, 6)
        local st = stroke(box, Palette.border, 0, 1)
        pad(box, 0, 10, 0, 10)

        attach(box.Focused, function()
            tween(st, {Color = Palette.accent}, 0.12)
        end)
        attach(box.FocusLost, function()
            tween(st, {Color = Palette.border}, 0.12)
        end)
        return box
    end

    local function toggleSwitch(parent, initialState, onToggle, bucket)
        local state = initialState == true
        local trackBtn = mk("TextButton", {
            Size = UDim2.fromOffset(40, 22),
            BackgroundColor3 = state and Palette.accent or Palette.border,
            Text = "",
            AutoButtonColor = false,
            BorderSizePixel = 0
        }, parent)
        corner(trackBtn, 11)

        local thumb = mk("Frame", {
            Size = UDim2.fromOffset(16, 16),
            Position = state and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3),
            BackgroundColor3 = Palette.surface,
            BorderSizePixel = 0
        }, trackBtn)
        corner(thumb, 8)

        attach(trackBtn.MouseButton1Click, function()
            if not State.alive then return end
            state = not state
            tween(trackBtn, {BackgroundColor3 = state and Palette.accent or Palette.border}, 0.14)
            tween(thumb, {Position = state and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3)}, 0.14)
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

    -- Crisp White Toast Notification
    UI.toast = mk("Frame", {
        Position = UDim2.new(0.5, -155, 0, 16),
        Size = UDim2.fromOffset(310, 48),
        BackgroundColor3 = Palette.surface,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 90
    }, UI.root)
    corner(UI.toast, 8)
    stroke(UI.toast, Palette.border, 0, 1)

    UI.toastDot = mk("Frame", {
        Position = UDim2.fromOffset(14, 20),
        Size = UDim2.fromOffset(8, 8),
        BackgroundColor3 = Palette.pos,
        BorderSizePixel = 0,
        ZIndex = 92
    }, UI.toast)
    corner(UI.toastDot, 4)

    UI.toastTitle = label(UI.toast, "", {
        Position = UDim2.fromOffset(30, 7),
        Size = UDim2.new(1, -40, 0, 16),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        ZIndex = 92
    })
    UI.toastBody = label(UI.toast, "", {
        Position = UDim2.fromOffset(30, 24),
        Size = UDim2.new(1, -40, 0, 15),
        TextSize = 11,
        TextColor3 = Palette.inkSecondary,
        ZIndex = 92
    })

    local function notify(title, body, tint)
        State.toastId = State.toastId + 1
        local id = State.toastId
        UI.toastDot.BackgroundColor3 = tint or Palette.pos
        UI.toastTitle.Text = tostring(title or "Carbon")
        UI.toastBody.Text = tostring(body or "")
        UI.toast.Visible = true
        if Prefs.animations and not Prefs.lowPower then
            UI.toast.Position = UDim2.new(0.5, -155, 0, 8)
            tween(UI.toast, {Position = UDim2.new(0.5, -155, 0, 16)}, 0.16)
        end
        task.delay(2.4, function()
            if State.alive and State.toastId == id then
                UI.toast.Visible = false
            end
        end)
    end

    -- Floating Launcher Pill (Carbon White)
    local startBtnX = Prefs.btnX >= 0 and Prefs.btnX or math.max(16, State.screenSize.X - 132)
    UI.launcher = mk("TextButton", {
        Name = "CarbonLauncher",
        Position = UDim2.fromOffset(startBtnX, Prefs.btnY),
        Size = UDim2.fromOffset(116, 34),
        BackgroundColor3 = Palette.surface,
        Text = "",
        AutoButtonColor = false,
        BorderSizePixel = 0,
        ZIndex = 60
    }, UI.root)
    corner(UI.launcher, 17)
    stroke(UI.launcher, Palette.border, 0, 1)

    UI.launcherDot = mk("Frame", {
        Position = UDim2.fromOffset(13, 13),
        Size = UDim2.fromOffset(8, 8),
        BackgroundColor3 = Palette.inkMuted,
        BorderSizePixel = 0,
        ZIndex = 62
    }, UI.launcher)
    corner(UI.launcherDot, 4)

    label(UI.launcher, "Carbon", {
        Position = UDim2.fromOffset(27, 0),
        Size = UDim2.fromOffset(50, 34),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        ZIndex = 62
    })

    pill(UI.launcher, "MM2", Palette.inkSecondary, Palette.canvas, {
        Position = UDim2.fromOffset(76, 8),
        Size = UDim2.fromOffset(30, 18),
        TextSize = 9,
        ZIndex = 62
    })

    local didDragLauncher = makeDraggable(UI.launcher, UI.launcher, function(x, y)
        Prefs.btnX = math.floor(x)
        Prefs.btnY = math.floor(y)
        Store.savePrefs()
    end)

    -- Live Trade HUD (Crisp White Card)
    UI.hud = mk("Frame", {
        Name = "TradeHUD",
        Position = UDim2.fromOffset(Prefs.hudX, Prefs.hudY),
        Size = UDim2.fromOffset(300, 118),
        BackgroundColor3 = Palette.surface,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 50
    }, UI.root)
    corner(UI.hud, 8)
    stroke(UI.hud, Palette.border, 0, 1)
    UI.hudScale = mk("UIScale", {Scale = 1}, UI.hud)

    UI.hudTopBar = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Palette.subtle,
        BorderSizePixel = 0,
        Active = true,
        ZIndex = 52
    }, UI.hud)
    corner(UI.hudTopBar, 8)

    UI.hudTitle = label(UI.hudTopBar, "Trade Evaluator", {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -116, 1, 0),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        ZIndex = 53
    })

    UI.hudBadge = pill(UI.hudTopBar, "FAIR", Palette.inkSecondary, Palette.hover, {
        Position = UDim2.new(1, -98, 0, 7),
        Size = UDim2.fromOffset(62, 20),
        TextSize = 10,
        ZIndex = 53
    })

    UI.hudCollapse = button(UI.hudTopBar, "–", "ghost", {
        Position = UDim2.new(1, -30, 0, 5),
        Size = UDim2.fromOffset(24, 24),
        TextSize = 13,
        ZIndex = 53
    }, function()
        State.hudCollapsed = not State.hudCollapsed
        UI.hudBody.Visible = not State.hudCollapsed
        UI.hudCollapse.Text = State.hudCollapsed and "+" or "–"
        UI.applyHudSize()
    end)

    UI.hudBody = mk("Frame", {
        Position = UDim2.fromOffset(0, 34),
        Size = UDim2.new(1, 0, 1, -34),
        BackgroundTransparency = 1,
        ZIndex = 52
    }, UI.hud)

    mk("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Palette.border,
        BorderSizePixel = 0,
        ZIndex = 53
    }, UI.hudBody)

    local function hudRow(y, caption)
        label(UI.hudBody, caption, {
            Position = UDim2.fromOffset(12, y), Size = UDim2.fromOffset(48, 22),
            Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Palette.inkMuted, ZIndex = 53
        })
        local s = label(UI.hudBody, "—", {
            Position = UDim2.fromOffset(64, y), Size = UDim2.fromOffset(112, 22),
            Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Palette.svInk,
            TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 53
        })
        local m = label(UI.hudBody, "—", {
            Position = UDim2.fromOffset(180, y), Size = UDim2.fromOffset(108, 22),
            Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Palette.mvInk,
            TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 53
        })
        return s, m
    end
    UI.ownS, UI.ownM = hudRow(6, "YOU")
    UI.themS, UI.themM = hudRow(30, "THEM")

    UI.hudDiff = label(UI.hudBody, "NET  —", {
        Position = UDim2.fromOffset(12, 56), Size = UDim2.new(1, -24, 0, 18),
        Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Palette.inkSecondary, ZIndex = 53
    })

    UI.hudWarnBar = mk("Frame", {
        Position = UDim2.fromOffset(12, 78),
        Size = UDim2.new(1, -24, 0, 22),
        BackgroundColor3 = Palette.warnBg,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 53
    }, UI.hudBody)
    corner(UI.hudWarnBar, 5)
    UI.hudWarnText = label(UI.hudWarnBar, "", {
        Size = UDim2.new(1, 0, 1, 0), Font = Enum.Font.GothamMedium, TextSize = 10, TextColor3 = Palette.warn,
        TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 54
    })

    function UI.applyHudSize()
        local h
        if State.hudCollapsed then
            h = 34
        else
            h = (Prefs.compact and 94 or 116) + (UI.hudWarnBar.Visible and 28 or 0)
        end
        UI.hudBody.Visible = not State.hudCollapsed
        UI.hudDiff.Visible = not Prefs.compact
        UI.hudWarnBar.Position = UDim2.fromOffset(12, Prefs.compact and 58 or 78)
        UI.hud.Size = UDim2.fromOffset(300, h)
    end
    UI.applyHudSize()

    makeDraggable(UI.hud, UI.hudTopBar, function(x, y)
        Prefs.hudX = math.max(0, math.floor(x))
        Prefs.hudY = math.max(0, math.floor(y))
        Store.savePrefs()
    end)

    ----------------------------------------------------------------------
    -- Cleanup
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

        local bestPrefix, bestPrefixLen
        local bestSub, bestSubLen
        for _, row in ipairs(Data.itemsList) do
            row._k = row._k or normalize(row.name)
            local k = row._k
            if k:sub(1, #q) == q then
                if not bestPrefixLen or #k < bestPrefixLen then
                    bestPrefix = row
                    bestPrefixLen = #k
                end
            elseif k:find(q, 1, true) then
                if not bestSubLen or #k < bestSubLen then
                    bestSub = row
                    bestSubLen = #k
                end
            end
        end
        return bestPrefix or bestSub
    end

    function Util.ago(ts)
        local d = math.max(0, os.time() - (tonumber(ts) or 0))
        if d < 60 then return d .. "s ago" end
        if d < 3600 then return math.floor(d / 60) .. "m ago" end
        if d < 86400 then return math.floor(d / 3600) .. "h ago" end
        return math.floor(d / 86400) .. "d ago"
    end

    function Util.signed(n)
        if type(n) ~= "number" then return "—" end
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
    -- Trade reading (read-only)
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

    local function isChromaSlot(slot, labelObj, rawName)
        if rawName:lower():match("^chroma%s") or rawName:lower():match("^c%.%s") then
            return true
        end
        local chroma = nested(slot, "Tags", "Chroma") or slot:FindFirstChild("Chroma", true)
        if chroma and chroma:IsA("GuiObject") and chroma.Visible then
            return true
        end
        local grad = labelObj:FindFirstChildOfClass("UIGradient")
        if grad and grad.Enabled and #grad.Color.Keypoints >= 3 then
            return true
        end
        return false
    end

    local function readSlot(slot)
        local v = nested(slot, "ItemName", "Label") or slot:FindFirstChild("ItemName", true)
        if v and not v:IsA("TextLabel") then
            v = v:FindFirstChildOfClass("TextLabel")
        end
        if not v or not v:IsA("TextLabel") then return nil end
        local name = trim(v.Text)
        if name == "" then return nil end
        if isChromaSlot(slot, v, name) and not name:lower():match("^chroma%s") then
            name = "Chroma " .. name
        end
        local amount = 1
        local amountLabel = nested(slot, "Container", "Amount") or slot:FindFirstChild("Amount", true)
        if amountLabel and amountLabel:IsA("TextLabel") and amountLabel.Visible and type(amountLabel.Text) == "string" then
            local cleanAmt = trim(amountLabel.Text)
            local digits = cleanAmt:match("[xX×]%s*(%d+)") or cleanAmt:match("^(%d+)$")
            if digits then
                amount = math.max(1, math.min(9999, tonumber(digits) or 1))
            end
        end
        return name, amount
    end

    local function tagFor(slot)
        local b = State.badges[slot]
        if b and b.Parent == slot then return b end
        b = mk("TextLabel", {
            Name = "CarbonXValueTag",
            Text = "",
            Font = Enum.Font.GothamBold,
            TextSize = 9,
            TextColor3 = Palette.ink,
            BackgroundColor3 = Palette.surface,
            BackgroundTransparency = 0.04,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -3, 1, -3),
            Size = UDim2.fromOffset(96, 16),
            TextTruncate = Enum.TextTruncate.AtEnd,
            Visible = false,
            Active = false,
            Selectable = false,
            ZIndex = 75
        }, slot)
        corner(b, 4)
        stroke(b, Palette.border, 0, 1)
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
                        local sTotal = s and (s * amount) or nil
                        local mTotal = m and (m * amount) or nil
                        local width = slot.AbsoluteSize and slot.AbsoluteSize.X or 95
                        if width > 0 and width < 86 then
                            tag.Size = UDim2.fromOffset(math.max(40, width - 6), 16)
                            tag.Text = "SV " .. formatVal(sTotal)
                        else
                            tag.Size = UDim2.fromOffset(106, 16)
                            if Prefs.currencyMode == "SV" then
                                tag.Text = "SV " .. formatVal(sTotal)
                            elseif Prefs.currencyMode == "MV" then
                                tag.Text = "MV " .. formatVal(mTotal)
                            else
                                tag.Text = "SV " .. formatVal(sTotal) .. " · MV " .. formatVal(mTotal)
                            end
                        end
                        tag.TextColor3 = row and Palette.ink or Palette.warn
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
        for _, tag in pairs(State.badges) do
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
            notify("Trade recorded", entry.delta and ("Net change " .. Util.signed(entry.delta) .. " SV") or "Confirmed by game", Palette.pos)
        end
        if UI.win and UI.win.Visible and State.currentTab == "Overview" and UI.selectTab then
            pcall(UI.selectTab, "Overview")
        end
    end

    local function fmtSide(total, missing)
        return formatVal(total) .. (missing > 0 and "+?" or "")
    end

    local function updateHud(snap)
        local mine, other = snap.mine, snap.other
        local incomplete = mine.missS > 0 or other.missS > 0
        UI.ownS.Text = "SV " .. fmtSide(mine.s, mine.missS)
        UI.ownM.Text = "MV " .. fmtSide(mine.m, mine.missM)
        UI.themS.Text = "SV " .. fmtSide(other.s, other.missS)
        UI.themM.Text = "MV " .. fmtSide(other.m, other.missM)
        UI.ownS.TextColor3 = mine.missS > 0 and Palette.warn or Palette.svInk
        UI.themS.TextColor3 = other.missS > 0 and Palette.warn or Palette.svInk

        local d = other.s - mine.s
        local dm = other.m - mine.m
        local txt, fg, bg
        if mine.count + other.count == 0 then
            txt, fg, bg = "EMPTY", Palette.inkSecondary, Palette.hover
        elseif not Data.loaded then
            txt, fg, bg = "SYNC", Palette.warn, Palette.warnBg
        elseif incomplete then
            txt, fg, bg = "N/A", Palette.warn, Palette.warnBg
        else
            local base = math.max(mine.s, other.s)
            if math.abs(d) <= math.max(2, base * 0.05) then
                txt, fg, bg = "FAIR", Palette.mvInk, Palette.mvBg
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
            UI.hudDiff.Text = "NET  incomplete"
        else
            UI.hudDiff.Text = "NET  " .. Util.signed(d) .. " SV   ·   " .. Util.signed(dm) .. " MV"
        end

        local warnMsg, danger
        if os.clock() < State.warningUntil then
            warnMsg, danger = "Offer modified — re-verify items before accepting", true
        elseif not Data.loaded then
            warnMsg = "Syncing live market values..."
        elseif incomplete then
            warnMsg = "One or more items have no listed price"
        elseif Data.supremeStale then
            warnMsg = "Price feed may be outdated"
        elseif mine.s > 0 and other.s < mine.s * 0.75 then
            warnMsg = "You are giving >25% more value"
        end
        local wasVisible = UI.hudWarnBar.Visible
        UI.hudWarnBar.Visible = warnMsg ~= nil
        if warnMsg then
            UI.hudWarnText.Text = warnMsg
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
            if not State.tradeActive then
                ensureFreshPrices(120)
            end
            local snap = {mine = summarizeOffer(our), other = summarizeOffer(theirs)}
            local sig = table.concat(snap.other.sig, "|")
            if State.tradeActive and State.prevOther ~= "" and sig ~= State.prevOther then
                State.warningUntil = os.clock() + 5
                notify("Offer changed", "Verify their items before accepting", Palette.warn)
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

    -- High-tier items observed on current server
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
                                    name = row.name, value = row.supreme, category = row.category,
                                    player = tostring(p.DisplayName or p.Name)
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
    -- Main Web Dashboard Shell (880 x 550 Carbon White)
    ----------------------------------------------------------------------
    local WIN_W, WIN_H = 880, 550
    local SIDE_W = 196
    local TOP_H = 48

    local NAV_SECTIONS = {
        {
            heading = "OVERVIEW",
            items = {
                {id = "Overview", label = "Dashboard"},
                {id = "Values", label = "Market Index"}
            }
        },
        {
            heading = "TOOLS",
            items = {
                {id = "Compare", label = "Compare Items"},
                {id = "Inventory", label = "Portfolio"},
                {id = "Servers", label = "Trade Servers"}
            }
        },
        {
            heading = "SYSTEM",
            items = {
                {id = "Settings", label = "Settings"}
            }
        }
    }

    local Tabs = {}
    local Win = {order = 0, navButtons = {}, navBars = {}}
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
    corner(UI.win, 10)
    stroke(UI.win, Palette.border, 0, 1)
    Win.scale = mk("UIScale", {Scale = 1}, UI.win)

    -- Top Application Bar (48px)
    local topBar = mk("Frame", {
        Size = UDim2.new(1, 0, 0, TOP_H),
        BackgroundColor3 = Palette.surface,
        BorderSizePixel = 0,
        Active = true,
        ZIndex = 72
    }, UI.win)
    mk("Frame", {
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Palette.border,
        BorderSizePixel = 0,
        ZIndex = 73
    }, topBar)

    -- Brand block (aligned with sidebar width)
    label(topBar, "Carbon", {
        Position = UDim2.fromOffset(18, 0),
        Size = UDim2.fromOffset(58, TOP_H),
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        ZIndex = 73
    })
    pill(topBar, "WHITE", Palette.inkSecondary, Palette.canvas, {
        Position = UDim2.fromOffset(78, 15),
        Size = UDim2.fromOffset(44, 18),
        TextSize = 9,
        ZIndex = 73
    })
    mk("Frame", {
        Position = UDim2.fromOffset(SIDE_W - 1, 0),
        Size = UDim2.new(0, 1, 1, 0),
        BackgroundColor3 = Palette.border,
        BorderSizePixel = 0,
        ZIndex = 73
    }, topBar)

    -- Page Title & Breadcrumb
    Win.title = label(topBar, "Dashboard", {
        Position = UDim2.fromOffset(SIDE_W + 20, 0),
        Size = UDim2.fromOffset(220, TOP_H),
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        ZIndex = 73
    })

    -- Topbar Right Status & Sync Controls
    Win.svPill = pill(topBar, "SV —", Palette.svInk, Palette.svBg, {
        Position = UDim2.new(1, -286, 0, 13),
        Size = UDim2.fromOffset(96, 22),
        TextSize = 10,
        ZIndex = 73
    })
    Win.mvPill = pill(topBar, "MV —", Palette.mvInk, Palette.mvBg, {
        Position = UDim2.new(1, -184, 0, 13),
        Size = UDim2.fromOffset(96, 22),
        TextSize = 10,
        ZIndex = 73
    })
    button(topBar, "Sync", "default", {
        Position = UDim2.new(1, -82, 0, 11),
        Size = UDim2.fromOffset(44, 26),
        TextSize = 11,
        ZIndex = 74
    }, function()
        notify("Syncing", "Updating Supreme & MM2Values...", Palette.mvInk)
        task.spawn(function()
            pcall(Net.loadPrices)
            Data.loading = false
        end)
    end)
    button(topBar, "×", "ghost", {
        Position = UDim2.new(1, -34, 0, 10),
        Size = UDim2.fromOffset(26, 28),
        TextSize = 16,
        ZIndex = 74
    }, function() UI.setWindow(false) end)

    makeDraggable(UI.win, topBar)

    -- Left Navigation Sidebar (196px)
    Win.side = mk("Frame", {
        Position = UDim2.fromOffset(0, TOP_H),
        Size = UDim2.new(0, SIDE_W, 1, -TOP_H),
        BackgroundColor3 = Palette.surface,
        BorderSizePixel = 0,
        ZIndex = 71
    }, UI.win)
    mk("Frame", {
        Position = UDim2.new(1, -1, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        BackgroundColor3 = Palette.border,
        BorderSizePixel = 0,
        ZIndex = 72
    }, Win.side)

    local navY = 14
    for _, sec in ipairs(NAV_SECTIONS) do
        label(Win.side, sec.heading, {
            Position = UDim2.fromOffset(18, navY),
            Size = UDim2.new(1, -36, 0, 16),
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            TextColor3 = Palette.inkMuted,
            ZIndex = 73
        })
        navY = navY + 20
        for _, item in ipairs(sec.items) do
            local b = mk("TextButton", {
                Name = item.id .. "Nav",
                Position = UDim2.fromOffset(10, navY),
                Size = UDim2.new(1, -20, 0, 32),
                BackgroundColor3 = Palette.canvas,
                BackgroundTransparency = 1,
                Text = item.label,
                Font = Enum.Font.GothamMedium,
                TextSize = 12,
                TextColor3 = Palette.inkSecondary,
                TextXAlignment = Enum.TextXAlignment.Left,
                AutoButtonColor = false,
                BorderSizePixel = 0,
                ZIndex = 73
            }, Win.side)
            corner(b, 6)
            pad(b, 0, 10, 0, 14)

            local bar = mk("Frame", {
                Position = UDim2.fromOffset(-14, 7),
                Size = UDim2.fromOffset(3, 18),
                BackgroundColor3 = Palette.accent,
                BorderSizePixel = 0,
                Visible = false,
                ZIndex = 74
            }, b)
            corner(bar, 2)

            Win.navButtons[item.id] = b
            Win.navBars[item.id] = bar

            attach(b.MouseEnter, function()
                if State.currentTab ~= item.id then
                    b.BackgroundTransparency = 0
                    b.BackgroundColor3 = Palette.subtle
                    b.TextColor3 = Palette.ink
                end
            end)
            attach(b.MouseLeave, function()
                if State.currentTab ~= item.id then
                    b.BackgroundTransparency = 1
                    b.TextColor3 = Palette.inkSecondary
                end
            end)
            attach(b.MouseButton1Click, function()
                if State.alive then UI.selectTab(item.id) end
            end)
            navY = navY + 34
        end
        navY = navY + 10
    end

    -- Sidebar Bottom Session Card
    local sideFooter = mk("Frame", {
        Position = UDim2.new(0, 12, 1, -68),
        Size = UDim2.new(1, -24, 0, 56),
        BackgroundColor3 = Palette.subtle,
        BorderSizePixel = 0,
        ZIndex = 73
    }, Win.side)
    corner(sideFooter, 8)
    stroke(sideFooter, Palette.border, 0, 1)

    Win.sideDot = mk("Frame", {
        Position = UDim2.fromOffset(12, 14),
        Size = UDim2.fromOffset(8, 8),
        BackgroundColor3 = Palette.pos,
        BorderSizePixel = 0,
        ZIndex = 74
    }, sideFooter)
    corner(Win.sideDot, 4)

    Win.status = label(sideFooter, "Syncing...", {
        Position = UDim2.fromOffset(26, 8),
        Size = UDim2.new(1, -34, 0, 40),
        Font = Enum.Font.GothamMedium,
        TextSize = 10,
        TextColor3 = Palette.inkSecondary,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextTruncate = Enum.TextTruncate.None,
        ZIndex = 74
    })

    -- Main Workspace Area
    Win.content = mk("Frame", {
        Position = UDim2.fromOffset(SIDE_W, TOP_H),
        Size = UDim2.new(1, -SIDE_W, 1, -TOP_H),
        BackgroundColor3 = Palette.canvas,
        BorderSizePixel = 0,
        ZIndex = 71
    }, UI.win)

    function Win.paintTabs()
        for id, b in pairs(Win.navButtons) do
            local active = State.currentTab == id
            b.BackgroundTransparency = active and 0 or 1
            b.BackgroundColor3 = Palette.canvas
            b.Font = active and Enum.Font.GothamBold or Enum.Font.GothamMedium
            b.TextColor3 = active and Palette.ink or Palette.inkSecondary
            if Win.navBars[id] then
                Win.navBars[id].Visible = active
            end
        end
    end

    function Win.newPage()
        disconnectBag(State.tabConns)
        if Win.page then pcall(function() Win.page:Destroy() end) end
        Win.order = 0
        Win.refresh = nil
        Win.page = mk("ScrollingFrame", {
            Name = "Page",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 4,
            ScrollBarImageColor3 = Palette.borderStrong,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ZIndex = 72
        }, Win.content)
        pad(Win.page, 18, 20, 18, 20)
        vlist(Win.page, 14)
        return Win.page
    end

    ----------------------------------------------------------------------
    -- Dashboard Layout Components
    ----------------------------------------------------------------------
    local function card(parent, props)
        local p = {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Palette.surface,
            BorderSizePixel = 0,
            LayoutOrder = ord(),
            ZIndex = 73
        }
        for k, v in pairs(props or {}) do p[k] = v end
        local c = mk("Frame", p, parent)
        corner(c, 8)
        stroke(c, Palette.border, 0, 1)
        return c
    end

    local function kpiCard(parent, title, value, subtext, valueColor)
        local c = mk("Frame", {
            Size = UDim2.new(0.25, -9, 0, 82),
            BackgroundColor3 = Palette.surface,
            BorderSizePixel = 0,
            ZIndex = 73
        }, parent)
        corner(c, 8)
        stroke(c, Palette.border, 0, 1)
        pad(c, 12, 14, 12, 14)

        label(c, title, {
            Size = UDim2.new(1, 0, 0, 16),
            Font = Enum.Font.GothamMedium,
            TextSize = 11,
            TextColor3 = Palette.inkSecondary,
            ZIndex = 74
        })
        label(c, value, {
            Position = UDim2.fromOffset(0, 20),
            Size = UDim2.new(1, 0, 0, 24),
            Font = Enum.Font.GothamBold,
            TextSize = 18,
            TextColor3 = valueColor or Palette.ink,
            ZIndex = 74
        })
        label(c, subtext, {
            Position = UDim2.fromOffset(0, 46),
            Size = UDim2.new(1, 0, 0, 14),
            Font = Enum.Font.Gotham,
            TextSize = 10,
            TextColor3 = Palette.inkMuted,
            ZIndex = 74
        })
        return c
    end

    local function cardHeader(parent, title, subtitle)
        local h = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 42),
            BackgroundTransparency = 1,
            ZIndex = 74
        }, parent)
        pad(h, 0, 16, 0, 16)
        label(h, title, {
            Position = UDim2.fromOffset(0, 8),
            Size = UDim2.new(1, -120, 0, 16),
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            ZIndex = 75
        })
        if subtitle then
            label(h, subtitle, {
                Position = UDim2.fromOffset(0, 24),
                Size = UDim2.new(1, -120, 0, 14),
                TextSize = 10,
                TextColor3 = Palette.inkMuted,
                ZIndex = 75
            })
        end
        mk("Frame", {
            Position = UDim2.new(0, -16, 1, -1),
            Size = UDim2.new(1, 32, 0, 1),
            BackgroundColor3 = Palette.border,
            BorderSizePixel = 0,
            ZIndex = 74
        }, h)
        return h
    end

    local function kv(parent, key, value, color)
        local f = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
            LayoutOrder = ord(),
            ZIndex = 74
        }, parent)
        label(f, key, {
            Size = UDim2.new(0.48, 0, 1, 0),
            TextColor3 = Palette.inkSecondary,
            TextSize = 12,
            ZIndex = 75
        })
        label(f, tostring(value), {
            Position = UDim2.fromScale(0.48, 0),
            Size = UDim2.fromScale(0.52, 1),
            TextXAlignment = Enum.TextXAlignment.Right,
            TextColor3 = color or Palette.ink,
            TextSize = 12,
            Font = Enum.Font.GothamBold,
            ZIndex = 75
        })
        return f
    end

    local function hrow(parent, h, gap)
        local f = mk("Frame", {
            Size = UDim2.new(1, 0, 0, h or 32),
            BackgroundTransparency = 1,
            LayoutOrder = ord(),
            ZIndex = 73
        }, parent)
        mk("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, gap or 8),
            VerticalAlignment = Enum.VerticalAlignment.Center
        }, f)
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
            Text = text,
            Size = UDim2.fromOffset(w, 28),
            BackgroundColor3 = Palette.surface,
            TextColor3 = Palette.inkSecondary,
            Font = Enum.Font.GothamMedium,
            TextSize = 11,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            LayoutOrder = ord(),
            ZIndex = 74
        }, parent)
        corner(b, 6)
        local st = stroke(b, Palette.border, 0, 1)
        local function paint(hover)
            tween(b, {
                BackgroundColor3 = active and Palette.accent or (hover and Palette.hover or Palette.surface),
                TextColor3 = active and Palette.accentFg or (hover and Palette.ink or Palette.inkSecondary)
            }, 0.1)
            st.Color = active and Palette.accent or Palette.border
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

    local function copyOrNotify(text, okTitle)
        if copyClipboard(text) then
            notify(okTitle or "Copied", "Copied to clipboard", Palette.pos)
        else
            notify("Clipboard unavailable", "Executor does not support clipboard", Palette.warn)
        end
    end

    local function openLink(url, title)
        if openBrowserUrl(url) then
            notify("Opening link", title or "Opened in browser", Palette.pos)
        elseif copyClipboard(url) then
            notify("Link copied", "Paste URL into your browser", Palette.mvInk)
        else
            notify("Action unavailable", "Cannot open external browser", Palette.neg)
        end
    end

    ----------------------------------------------------------------------
    -- Tab 1: Overview (Multi-Column Executive Dashboard)
    ----------------------------------------------------------------------
    Tabs.Overview = function(page)
        -- Calculate portfolio metrics
        local invS, invM, invCount = 0, 0, 0
        for _, it in ipairs(Prefs.myItems) do
            local qty = tonumber(it.qty) or 1
            invCount = invCount + qty
            local row = lookup(it.name)
            if row and row.supreme then invS = invS + row.supreme * qty end
            local mv = safeMM2(row)
            if mv then invM = invM + mv * qty end
        end

        -- 4-Column KPI Row
        local kpiGrid = hrow(page, 82, 12)
        kpiCard(kpiGrid, "Portfolio (Supreme)", formatVal(invS) .. " SV", invCount .. " items tracked", Palette.svInk)
        kpiCard(kpiGrid, "Portfolio (MM2Values)", formatVal(invM) .. " MV", "Cross-referenced value", Palette.mvInk)
        kpiCard(kpiGrid, "Market Database", tostring(#Data.itemsList), "Updated " .. Data.supremeStamp, Palette.ink)
        local favCount = 0
        for _ in pairs(Prefs.favs) do favCount = favCount + 1 end
        kpiCard(kpiGrid, "Watchlist & Trades", tostring(#Data.history) .. " trades", favCount .. " pinned favorites", Palette.pos)

        -- 2-Column Main Workspace Split
        local split = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 356),
            BackgroundTransparency = 1,
            LayoutOrder = ord(),
            ZIndex = 72
        }, page)

        -- Left Column (60%): Recent Trade Ledger
        local leftCol = mk("Frame", {
            Size = UDim2.new(0.60, -7, 1, 0),
            BackgroundColor3 = Palette.surface,
            BorderSizePixel = 0,
            ZIndex = 73
        }, split)
        corner(leftCol, 8)
        stroke(leftCol, Palette.border, 0, 1)

        local lh = cardHeader(leftCol, "Recent Trade Activity", "Recorded from active MM2 trade sessions")
        if #Data.history > 0 then
            button(lh, "Clear", "ghost", {
                Position = UDim2.new(1, -56, 0, 9),
                Size = UDim2.fromOffset(48, 24),
                TextSize = 11,
                ZIndex = 75
            }, function()
                Data.history = {}
                Store.write(Config.HISTORY_FILE, Data.history)
                UI.selectTab("Overview")
            end, State.tabConns)
        end

        -- Table Column Headers
        local th = mk("Frame", {
            Position = UDim2.fromOffset(0, 42),
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundColor3 = Palette.subtle,
            BorderSizePixel = 0,
            ZIndex = 74
        }, leftCol)
        mk("Frame", {
            Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = Palette.border, BorderSizePixel = 0, ZIndex = 75
        }, th)
        label(th, "TIME", {Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(46, 26), Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Palette.inkMuted, ZIndex = 75})
        label(th, "STATUS", {Position = UDim2.fromOffset(62, 0), Size = UDim2.fromOffset(74, 26), Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Palette.inkMuted, ZIndex = 75})
        label(th, "SUMMARY", {Position = UDim2.fromOffset(142, 0), Size = UDim2.new(1, -226, 1, 0), Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Palette.inkMuted, ZIndex = 75})
        label(th, "NET SV", {Position = UDim2.new(1, -80, 0, 0), Size = UDim2.fromOffset(66, 26), Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Palette.inkMuted, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 75})

        if #Data.history == 0 then
            label(leftCol, "No trades recorded yet.\nCompleted trades will automatically appear in this ledger.", {
                Position = UDim2.fromOffset(16, 84),
                Size = UDim2.new(1, -32, 0, 44),
                TextSize = 12,
                TextColor3 = Palette.inkMuted,
                TextWrapped = true,
                ZIndex = 74
            })
        else
            for i = 1, math.min(#Data.history, 7) do
                local h = Data.history[i]
                local rowY = 68 + (i - 1) * 40
                local r = mk("Frame", {
                    Position = UDim2.fromOffset(0, rowY),
                    Size = UDim2.new(1, 0, 0, 40),
                    BackgroundTransparency = 1,
                    ZIndex = 74
                }, leftCol)
                if i < math.min(#Data.history, 7) then
                    mk("Frame", {
                        Position = UDim2.new(0, 14, 1, -1), Size = UDim2.new(1, -28, 0, 1),
                        BackgroundColor3 = Palette.border, BorderSizePixel = 0, ZIndex = 75
                    }, r)
                end

                local when = tostring(h.at)
                pcall(function() when = os.date("%H:%M", h.at) end)
                local confirmed = h.status == "CONFIRMED"

                label(r, when, {
                    Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(44, 40),
                    Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Palette.inkSecondary, ZIndex = 75
                })
                pill(r, confirmed and "DONE" or "CLOSED",
                    confirmed and Palette.pos or Palette.inkSecondary,
                    confirmed and Palette.posBg or Palette.subtle, {
                        Position = UDim2.fromOffset(62, 11), Size = UDim2.fromOffset(66, 18), TextSize = 9, ZIndex = 75
                    })
                label(r, "In: " .. tostring(h.get or "—"), {
                    Position = UDim2.fromOffset(136, 4), Size = UDim2.new(1, -220, 0, 16),
                    Font = Enum.Font.GothamMedium, TextSize = 11, ZIndex = 75
                })
                label(r, "Out: " .. tostring(h.give or "—"), {
                    Position = UDim2.fromOffset(136, 20), Size = UDim2.new(1, -220, 0, 14),
                    TextSize = 10, TextColor3 = Palette.inkMuted, ZIndex = 75
                })
                local dCol = h.delta and (h.delta > 0 and Palette.pos or (h.delta < 0 and Palette.neg or Palette.inkSecondary)) or Palette.inkMuted
                label(r, h.delta and (Util.signed(h.delta)) or "—", {
                    Position = UDim2.new(1, -80, 0, 0), Size = UDim2.fromOffset(66, 40),
                    Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = dCol,
                    TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 75
                })
            end
        end

        -- Right Column (40%): Server Sightings + Feed Status
        local rightCol = mk("Frame", {
            Position = UDim2.new(0.60, 7, 0, 0),
            Size = UDim2.new(0.40, -7, 1, 0),
            BackgroundTransparency = 1,
            ZIndex = 73
        }, split)

        -- Top Right Card: High-Tier Sightings on Server
        local sightCard = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 210),
            BackgroundColor3 = Palette.surface,
            BorderSizePixel = 0,
            ZIndex = 73
        }, rightCol)
        corner(sightCard, 8)
        stroke(sightCard, Palette.border, 0, 1)
        cardHeader(sightCard, "Server Sightings", "Players holding 250+ SV items")

        local list = {}
        local now = os.time()
        for _, s in pairs(Data.sightings) do
            if type(s) == "table" and s.jobId == tostring(game.JobId) and now - (s.at or 0) < 1800 then
                list[#list + 1] = s
            end
        end
        table.sort(list, function(a, b) return (a.value or 0) > (b.value or 0) end)

        if #list == 0 then
            label(sightCard, "No high-tier items spotted in this server yet.", {
                Position = UDim2.fromOffset(16, 56), Size = UDim2.new(1, -32, 0, 32),
                TextSize = 11, TextColor3 = Palette.inkMuted, TextWrapped = true, ZIndex = 74
            })
        else
            for i = 1, math.min(#list, 4) do
                local s = list[i]
                local sy = 48 + (i - 1) * 38
                local r = mk("Frame", {
                    Position = UDim2.fromOffset(14, sy), Size = UDim2.new(1, -28, 0, 34),
                    BackgroundTransparency = 1, ZIndex = 74
                }, sightCard)
                label(r, tostring(s.name), {
                    Size = UDim2.new(1, -80, 0, 18), Font = Enum.Font.GothamBold, TextSize = 11, ZIndex = 75
                })
                label(r, tostring(s.player) .. " · " .. Util.ago(s.at), {
                    Position = UDim2.fromOffset(0, 17), Size = UDim2.new(1, -80, 0, 14),
                    TextSize = 10, TextColor3 = Palette.inkMuted, ZIndex = 75
                })
                label(r, formatVal(s.value) .. " SV", {
                    Position = UDim2.new(1, -78, 0, 0), Size = UDim2.fromOffset(78, 34),
                    Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Palette.svInk,
                    TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 75
                })
            end
        end

        -- Bottom Right Card: Data Feed & External Links
        local feedCard = mk("Frame", {
            Position = UDim2.fromOffset(0, 222),
            Size = UDim2.new(1, 0, 0, 134),
            BackgroundColor3 = Palette.surface,
            BorderSizePixel = 0,
            ZIndex = 73
        }, rightCol)
        corner(feedCard, 8)
        stroke(feedCard, Palette.border, 0, 1)
        pad(feedCard, 12, 14, 12, 14)

        label(feedCard, "Market Feed Sources", {
            Size = UDim2.new(1, 0, 0, 18), Font = Enum.Font.GothamBold, TextSize = 12, ZIndex = 74
        })
        label(feedCard, "Supreme: " .. Data.supremeStamp .. "   ·   MM2Values: " .. Data.mm2Stamp, {
            Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 16),
            TextSize = 11, TextColor3 = Palette.inkSecondary, ZIndex = 74
        })
        label(feedCard, Data.lastFetchAt > 0 and ("Last synced " .. Util.ago(Data.lastFetchAt) .. " (auto-syncs every 3m)") or "Waiting for initial sync", {
            Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 16),
            TextSize = 10, TextColor3 = Palette.inkMuted, ZIndex = 74
        })

        local btnRow = mk("Frame", {
            Position = UDim2.fromOffset(0, 68), Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1, ZIndex = 74
        }, feedCard)
        button(btnRow, "Open Supreme", "primary", {
            Size = UDim2.fromOffset(112, 28), TextSize = 11, ZIndex = 75
        }, function()
            openLink(Config.OFFICIAL_SITE, "Supreme Values")
        end, State.tabConns)
        button(btnRow, "Copy URL", "default", {
            Position = UDim2.fromOffset(120, 0), Size = UDim2.fromOffset(82, 28), TextSize = 11, ZIndex = 75
        }, function()
            copyOrNotify(Config.OFFICIAL_SITE, "URL copied")
        end, State.tabConns)

        Win.refresh = function() UI.selectTab("Overview") end
    end

    ----------------------------------------------------------------------
    -- Tab 2: Market Index (Full Web Data Table with Pagination)
    ----------------------------------------------------------------------
    Tabs.Values = function(page)
        -- Toolbar: Search + Filter Chips + Sort
        local toolbar = hrow(page, 32, 8)
        local box = inputBox(toolbar, "Search items by name (e.g. Harvester, Chroma Luger)...", State.valueSearch, {
            Size = UDim2.fromOffset(310, 32), LayoutOrder = ord(), ZIndex = 73
        })

        local render
        local setters = {}
        for _, f in ipairs({
            {id = "All", label = "All", w = 48},
            {id = "Favs", label = "Favorites", w = 72},
            {id = "Wish", label = "Wishlist", w = 66},
            {id = "High", label = "500+ SV", w = 68}
        }) do
            local _, set = chip(toolbar, f.label, f.w, function()
                State.valueFilter = f.id
                State.valuePage = 1
                for id, fn in pairs(setters) do fn(id == f.id) end
                render()
            end)
            setters[f.id] = set
        end
        if not setters[State.valueFilter] then State.valueFilter = "All" end
        setters[State.valueFilter](true)

        -- Main Table Container
        local tableCard = card(page, {Size = UDim2.new(1, 0, 0, 412), AutomaticSize = Enum.AutomaticSize.None})

        -- Table Column Header
        local thead = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundColor3 = Palette.subtle,
            BorderSizePixel = 0,
            ZIndex = 74
        }, tableCard)
        mk("Frame", {
            Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = Palette.border, BorderSizePixel = 0, ZIndex = 75
        }, thead)

        label(thead, "ITEM NAME", {Position = UDim2.fromOffset(16, 0), Size = UDim2.fromOffset(220, 32), Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Palette.inkMuted, ZIndex = 75})
        label(thead, "CATEGORY", {Position = UDim2.fromOffset(240, 0), Size = UDim2.fromOffset(96, 32), Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Palette.inkMuted, ZIndex = 75})
        label(thead, "SUPREME (SV)", {Position = UDim2.fromOffset(340, 0), Size = UDim2.fromOffset(88, 32), Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Palette.inkMuted, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 75})
        label(thead, "MM2VALUES (MV)", {Position = UDim2.fromOffset(434, 0), Size = UDim2.fromOffset(94, 32), Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Palette.inkMuted, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 75})
        label(thead, "DEMAND", {Position = UDim2.fromOffset(534, 0), Size = UDim2.fromOffset(56, 32), Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Palette.inkMuted, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 75})
        label(thead, "PIN", {Position = UDim2.new(1, -66, 0, 0), Size = UDim2.fromOffset(52, 32), Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Palette.inkMuted, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 75})

        local tbody = mk("Frame", {
            Position = UDim2.fromOffset(0, 32),
            Size = UDim2.new(1, 0, 0, 340),
            BackgroundTransparency = 1,
            ZIndex = 74
        }, tableCard)

        -- Table Footer (Pagination)
        local tfoot = mk("Frame", {
            Position = UDim2.new(0, 0, 1, -40),
            Size = UDim2.new(1, 0, 0, 40),
            BackgroundColor3 = Palette.subtle,
            BorderSizePixel = 0,
            ZIndex = 74
        }, tableCard)
        mk("Frame", {
            Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = Palette.border, BorderSizePixel = 0, ZIndex = 75
        }, tfoot)

        local countLbl = label(tfoot, "", {
            Position = UDim2.fromOffset(16, 0), Size = UDim2.fromOffset(260, 40),
            TextSize = 11, TextColor3 = Palette.inkSecondary, ZIndex = 75
        })
        button(tfoot, "Previous", "default", {
            Position = UDim2.new(1, -214, 0, 7), Size = UDim2.fromOffset(68, 26), TextSize = 11, ZIndex = 75
        }, function()
            State.valuePage = math.max(1, State.valuePage - 1)
            render()
        end, State.tabConns)
        local pageLbl = label(tfoot, "1 / 1", {
            Position = UDim2.new(1, -142, 0, 0), Size = UDim2.fromOffset(66, 40),
            Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Palette.inkSecondary,
            TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 75
        })
        button(tfoot, "Next", "default", {
            Position = UDim2.new(1, -72, 0, 7), Size = UDim2.fromOffset(56, 26), TextSize = 11, ZIndex = 75
        }, function()
            State.valuePage = State.valuePage + 1
            render()
        end, State.tabConns)

        local function renderRow(row, idx)
            local y = (idx - 1) * 34
            local tr = mk("Frame", {
                Position = UDim2.fromOffset(0, y),
                Size = UDim2.new(1, 0, 0, 34),
                BackgroundColor3 = Palette.surface,
                BorderSizePixel = 0,
                ZIndex = 74
            }, tbody)
            mk("Frame", {
                Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = Palette.border, BorderSizePixel = 0, ZIndex = 75
            }, tr)

            attach(tr.MouseEnter, function() tr.BackgroundColor3 = Palette.subtle end, State.tabConns)
            attach(tr.MouseLeave, function() tr.BackgroundColor3 = Palette.surface end, State.tabConns)

            label(tr, row.name, {
                Position = UDim2.fromOffset(16, 0), Size = UDim2.fromOffset(220, 34),
                Font = Enum.Font.GothamBold, TextSize = 12, ZIndex = 75
            })
            label(tr, (row.category and row.category ~= "") and row.category or "Item", {
                Position = UDim2.fromOffset(240, 0), Size = UDim2.fromOffset(96, 34),
                TextSize = 11, TextColor3 = Palette.inkSecondary, ZIndex = 75
            })
            label(tr, formatVal(row.supreme), {
                Position = UDim2.fromOffset(340, 0), Size = UDim2.fromOffset(88, 34),
                Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Palette.svInk,
                TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 75
            })
            label(tr, formatVal(safeMM2(row)), {
                Position = UDim2.fromOffset(434, 0), Size = UDim2.fromOffset(94, 34),
                Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Palette.mvInk,
                TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 75
            })
            label(tr, row.demand and (formatVal(row.demand) .. "/10") or "—", {
                Position = UDim2.fromOffset(534, 0), Size = UDim2.fromOffset(56, 34),
                TextSize = 11, TextColor3 = Palette.inkSecondary,
                TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 75
            })

            local isFav = Prefs.favs[row.name] == true
            local isWish = Prefs.wishlist[row.name] == true

            local favBtn = mk("TextButton", {
                Text = "★",
                Position = UDim2.new(1, -64, 0, 6), Size = UDim2.fromOffset(24, 22),
                BackgroundColor3 = isFav and Palette.svBg or Palette.subtle,
                TextColor3 = isFav and Palette.svInk or Palette.inkMuted,
                Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 75
            }, tr)
            corner(favBtn, 4)
            attach(favBtn.MouseButton1Click, function()
                Prefs.favs[row.name] = not (Prefs.favs[row.name] == true) or nil
                Store.savePrefs()
                render()
            end, State.tabConns)

            local wishBtn = mk("TextButton", {
                Text = "+",
                Position = UDim2.new(1, -36, 0, 6), Size = UDim2.fromOffset(24, 22),
                BackgroundColor3 = isWish and Palette.mvBg or Palette.subtle,
                TextColor3 = isWish and Palette.mvInk or Palette.inkMuted,
                Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 75
            }, tr)
            corner(wishBtn, 4)
            attach(wishBtn.MouseButton1Click, function()
                Prefs.wishlist[row.name] = not (Prefs.wishlist[row.name] == true) or nil
                Store.savePrefs()
                render()
            end, State.tabConns)
        end

        render = function()
            clearChildren(tbody)
            if not Data.loaded then
                label(tbody, "Loading live market index...", {
                    Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(260, 24),
                    TextSize = 12, TextColor3 = Palette.inkMuted, ZIndex = 75
                })
                countLbl.Text = "Syncing..."
                return
            end

            local q = normalize(State.valueSearch)
            local filtered = {}
            for _, row in ipairs(Data.itemsList) do
                local match = true
                if q ~= "" then
                    row._k = row._k or normalize(row.name)
                    match = row._k:find(q, 1, true) ~= nil
                end
                if match and State.valueFilter == "Favs" then match = Prefs.favs[row.name] == true end
                if match and State.valueFilter == "Wish" then match = Prefs.wishlist[row.name] == true end
                if match and State.valueFilter == "High" then match = (row.supreme or 0) >= 500 end
                if match then
                    filtered[#filtered + 1] = row
                end
            end

            local perPage = 10
            local total = #filtered
            local pages = math.max(1, math.ceil(total / perPage))
            State.valuePage = math.max(1, math.min(State.valuePage, pages))
            pageLbl.Text = State.valuePage .. " / " .. pages

            if total == 0 then
                countLbl.Text = "0 items found"
                label(tbody, "No items match your current filter.", {
                    Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(260, 24),
                    TextSize = 12, TextColor3 = Palette.inkMuted, ZIndex = 75
                })
                return
            end

            local startIdx = (State.valuePage - 1) * perPage + 1
            local endIdx = math.min(total, State.valuePage * perPage)
            countLbl.Text = "Showing " .. startIdx .. "–" .. endIdx .. " of " .. total .. " items"

            for i = startIdx, endIdx do
                renderRow(filtered[i], i - startIdx + 1)
            end
        end

        local token = 0
        attach(box:GetPropertyChangedSignal("Text"), function()
            State.valueSearch = box.Text
            State.valuePage = 1
            token = token + 1
            local mine = token
            task.delay(0.2, function()
                if State.alive and token == mine and box.Parent then pcall(render) end
            end)
        end, State.tabConns)
        Win.refresh = render
        render()
    end

    ----------------------------------------------------------------------
    -- Tab 3: Compare Items (Side-by-Side Spec Matrix)
    ----------------------------------------------------------------------
    Tabs.Compare = function(page)
        local grid = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 326),
            BackgroundTransparency = 1,
            LayoutOrder = ord(),
            ZIndex = 72
        }, page)

        local function buildCol(xScale, xOff, initial)
            local col = mk("Frame", {
                Position = UDim2.new(xScale, xOff, 0, 0),
                Size = UDim2.new(0.5, -7, 1, 0),
                BackgroundTransparency = 1,
                ZIndex = 73
            }, grid)
            local box = inputBox(col, "Type item name...", initial, {
                Size = UDim2.new(1, 0, 0, 34), ZIndex = 74
            })
            local c = mk("Frame", {
                Position = UDim2.fromOffset(0, 44),
                Size = UDim2.new(1, 0, 1, -44),
                BackgroundColor3 = Palette.surface,
                BorderSizePixel = 0,
                ZIndex = 73
            }, col)
            corner(c, 8)
            stroke(c, Palette.border, 0, 1)
            pad(c, 14, 16, 14, 16)
            vlist(c, 6)
            return box, c
        end

        local boxA, cardA = buildCol(0, 0, State.compareA)
        local boxB, cardB = buildCol(0.5, 7, State.compareB)
        local summary = card(page)
        pad(summary, 14, 16, 14, 16)
        vlist(summary, 6)

        local function fill(c, text)
            clearChildren(c)
            local row = Util.resolve(text)
            if not row then
                label(c, Data.loaded and "Item not found in database." or "Syncing prices...", {
                    Size = UDim2.new(1, 0, 0, 22), TextSize = 12, TextColor3 = Palette.inkMuted, ZIndex = 74
                })
                return nil
            end
            label(c, row.name, {
                Size = UDim2.new(1, 0, 0, 22), Font = Enum.Font.GothamBold, TextSize = 15, LayoutOrder = ord(), ZIndex = 74
            })
            kv(c, "Category", (row.category and row.category ~= "") and row.category or "—")
            kv(c, "Supreme Value (SV)", formatVal(row.supreme), Palette.svInk)
            kv(c, "MM2Values (MV)", formatVal(safeMM2(row)), Palette.mvInk)
            kv(c, "Demand", row.demand and (formatVal(row.demand) .. " / 10") or "—")
            kv(c, "Rarity", row.rarity and (formatVal(row.rarity) .. " / 10") or "—")
            kv(c, "Recent Change", row.change and Util.signed(row.change) or "—",
                row.change and (row.change > 0 and Palette.pos or (row.change < 0 and Palette.neg or Palette.ink)) or Palette.ink)
            kv(c, "Stability", (row.stability and row.stability ~= "") and row.stability or "—")
            return row
        end

        local function update()
            local a = fill(cardA, State.compareA)
            local b = fill(cardB, State.compareB)
            clearChildren(summary)
            if a and b and a.supreme and b.supreme and a.supreme > 0 and b.supreme > 0 then
                local ratio = a.supreme / b.supreme
                kv(summary, "Relative Ratio (" .. a.name .. " / " .. b.name .. ")", string.format("%.2fx", ratio), Palette.mvInk)
                local diff = a.supreme - b.supreme
                kv(summary, "Net Value Spread (Supreme)", Util.signed(diff) .. " SV",
                    diff > 0 and Palette.pos or (diff < 0 and Palette.neg or Palette.inkSecondary))
            else
                label(summary, "Enter two valid items above to calculate spread and ratio.", {
                    Size = UDim2.new(1, 0, 0, 20), TextSize = 12, TextColor3 = Palette.inkMuted, ZIndex = 74
                })
            end
        end

        local token = 0
        local function watch(box, field)
            attach(box:GetPropertyChangedSignal("Text"), function()
                State[field] = box.Text
                token = token + 1
                local mine = token
                task.delay(0.25, function()
                    if State.alive and token == mine and box.Parent then pcall(update) end
                end)
            end, State.tabConns)
        end
        watch(boxA, "compareA")
        watch(boxB, "compareB")
        Win.refresh = update
        update()
    end

    ----------------------------------------------------------------------
    -- Tab 4: Portfolio / Inventory Manager
    ----------------------------------------------------------------------
    Tabs.Inventory = function(page)
        local totalsRow = hrow(page, 72, 12)
        local addRow = hrow(page, 34, 8)
        local nameBox = inputBox(addRow, "Add item to portfolio (e.g. Corrupt, Gingerscope)...", State.invQuery, {
            Size = UDim2.fromOffset(360, 34), LayoutOrder = ord(), ZIndex = 73
        })
        local qtyBox = inputBox(addRow, "Qty", State.invQty, {
            Size = UDim2.fromOffset(68, 34), LayoutOrder = ord(), ZIndex = 73
        })
        local tableCard = card(page)
        local render

        attach(nameBox:GetPropertyChangedSignal("Text"), function() State.invQuery = nameBox.Text end, State.tabConns)
        attach(qtyBox:GetPropertyChangedSignal("Text"), function() State.invQty = qtyBox.Text end, State.tabConns)

        button(addRow, "Add Item", "primary", {
            Size = UDim2.fromOffset(96, 34), LayoutOrder = ord(), ZIndex = 75
        }, function()
            local row = Util.resolve(State.invQuery)
            if not row then
                notify("Item not found", "Check spelling and try again", Palette.warn)
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
                    notify("Portfolio limit", "Maximum 60 unique stacks", Palette.warn)
                    return
                end
                Prefs.myItems[#Prefs.myItems + 1] = {name = row.name, qty = qty}
            end
            Store.savePrefs()
            nameBox.Text = ""
            State.invQuery = ""
            render()
        end, State.tabConns)

        render = function()
            clearChildren(totalsRow)
            clearChildren(tableCard)

            local s, m, totalUnits, missS, missM = 0, 0, 0, 0, 0
            for _, it in ipairs(Prefs.myItems) do
                local qty = tonumber(it.qty) or 1
                totalUnits = totalUnits + qty
                local row = lookup(it.name)
                local sv, mv = row and row.supreme, safeMM2(row)
                if sv then s = s + sv * qty else missS = missS + 1 end
                if mv then m = m + mv * qty else missM = missM + 1 end
            end

            local function miniKpi(title, val, col)
                local k = mk("Frame", {
                    Size = UDim2.new(0.333, -8, 1, 0), BackgroundColor3 = Palette.surface,
                    BorderSizePixel = 0, ZIndex = 73
                }, totalsRow)
                corner(k, 8)
                stroke(k, Palette.border, 0, 1)
                pad(k, 10, 14, 10, 14)
                label(k, title, {Size = UDim2.new(1, 0, 0, 16), TextSize = 11, TextColor3 = Palette.inkSecondary, ZIndex = 74})
                label(k, val, {Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 24), Font = Enum.Font.GothamBold, TextSize = 17, TextColor3 = col, ZIndex = 74})
            end

            miniKpi("Total Supreme Value", formatVal(s) .. (missS > 0 and "+?" or "") .. " SV", Palette.svInk)
            miniKpi("Total MM2Values", formatVal(m) .. (missM > 0 and "+?" or "") .. " MV", Palette.mvInk)
            miniKpi("Total Holdings", totalUnits .. " items (" .. #Prefs.myItems .. " stacks)", Palette.ink)

            if #Prefs.myItems == 0 then
                pad(tableCard, 16)
                label(tableCard, "Your portfolio is empty. Add items above to track combined net worth.", {
                    Size = UDim2.new(1, 0, 0, 20), TextSize = 12, TextColor3 = Palette.inkMuted, ZIndex = 74
                })
                return
            end

            local thead = mk("Frame", {
                Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Palette.subtle, BorderSizePixel = 0, ZIndex = 74
            }, tableCard)
            mk("Frame", {
                Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = Palette.border, BorderSizePixel = 0, ZIndex = 75
            }, thead)
            label(thead, "HOLDING", {Position = UDim2.fromOffset(16, 0), Size = UDim2.fromOffset(220, 30), Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Palette.inkMuted, ZIndex = 75})
            label(thead, "QUANTITY", {Position = UDim2.fromOffset(250, 0), Size = UDim2.fromOffset(90, 30), Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Palette.inkMuted, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 75})
            label(thead, "SUBTOTAL (SV)", {Position = UDim2.new(1, -166, 0, 0), Size = UDim2.fromOffset(100, 30), Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Palette.inkMuted, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 75})

            for idx, it in ipairs(Prefs.myItems) do
                local qty = tonumber(it.qty) or 1
                local row = lookup(it.name)
                local tr = mk("Frame", {
                    Position = UDim2.fromOffset(0, 30 + (idx - 1) * 36),
                    Size = UDim2.new(1, 0, 0, 36),
                    BackgroundTransparency = 1,
                    ZIndex = 74
                }, tableCard)
                if idx < #Prefs.myItems then
                    mk("Frame", {
                        Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1),
                        BackgroundColor3 = Palette.border, BorderSizePixel = 0, ZIndex = 75
                    }, tr)
                end

                label(tr, tostring(it.name), {
                    Position = UDim2.fromOffset(16, 0), Size = UDim2.fromOffset(224, 36),
                    Font = Enum.Font.GothamBold, TextSize = 12, ZIndex = 75
                })

                button(tr, "–", "default", {
                    Position = UDim2.fromOffset(252, 6), Size = UDim2.fromOffset(24, 24), TextSize = 12, ZIndex = 75
                }, function()
                    if qty > 1 then
                        it.qty = qty - 1
                    else
                        table.remove(Prefs.myItems, idx)
                    end
                    Store.savePrefs()
                    render()
                end, State.tabConns)

                label(tr, tostring(qty), {
                    Position = UDim2.fromOffset(278, 0), Size = UDim2.fromOffset(34, 36),
                    Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 75
                })

                button(tr, "+", "default", {
                    Position = UDim2.fromOffset(314, 6), Size = UDim2.fromOffset(24, 24), TextSize = 12, ZIndex = 75
                }, function()
                    it.qty = math.min(9999, qty + 1)
                    Store.savePrefs()
                    render()
                end, State.tabConns)

                label(tr, row and row.supreme and (formatVal(row.supreme * qty) .. " SV") or "—", {
                    Position = UDim2.new(1, -166, 0, 0), Size = UDim2.fromOffset(100, 36),
                    Font = Enum.Font.GothamBold, TextSize = 12,
                    TextColor3 = (row and row.supreme) and Palette.svInk or Palette.inkMuted,
                    TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 75
                })

                button(tr, "Remove", "ghost", {
                    Position = UDim2.new(1, -58, 0, 6), Size = UDim2.fromOffset(48, 24), TextSize = 11, ZIndex = 75
                }, function()
                    table.remove(Prefs.myItems, idx)
                    Store.savePrefs()
                    render()
                end, State.tabConns)
            end
            tableCard.Size = UDim2.new(1, 0, 0, 30 + #Prefs.myItems * 36)
        end
        Win.refresh = render
        render()
    end

    ----------------------------------------------------------------------
    -- Tab 5: Trading Servers (2-Column Grid)
    ----------------------------------------------------------------------
    Tabs.Servers = function(page)
        local chips = hrow(page, 30, 8)
        local grid = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 336),
            BackgroundTransparency = 1,
            LayoutOrder = ord(),
            ZIndex = 72
        }, page)
        local pager = hrow(page, 30, 8)
        local pageLbl
        local render

        local setters = {}
        for _, cat in ipairs({
            {id = "ANY", label = "Any Ages", w = 78},
            {id = "AGE", label = "15–18+ Verified", w = 110},
            {id = "HIGH", label = "High Tier", w = 78},
            {id = "ALL", label = "All Servers", w = 82}
        }) do
            local _, set = chip(chips, cat.label, cat.w, function()
                State.serverCategory = cat.id
                State.serverPage = 1
                for id, fn in pairs(setters) do fn(id == cat.id) end
                render()
            end)
            setters[cat.id] = set
        end
        if not setters[State.serverCategory] then State.serverCategory = "ANY" end
        setters[State.serverCategory](true)

        button(pager, "Previous", "default", {Size = UDim2.fromOffset(72, 28), LayoutOrder = ord(), ZIndex = 75}, function()
            State.serverPage = math.max(1, State.serverPage - 1)
            render()
        end, State.tabConns)
        pageLbl = label(pager, "1 / 1", {
            Size = UDim2.fromOffset(64, 28), TextXAlignment = Enum.TextXAlignment.Center,
            Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Palette.inkSecondary, LayoutOrder = ord(), ZIndex = 74
        })
        button(pager, "Next", "default", {Size = UDim2.fromOffset(60, 28), LayoutOrder = ord(), ZIndex = 75}, function()
            State.serverPage = State.serverPage + 1
            render()
        end, State.tabConns)

        render = function()
            clearChildren(grid)
            local items = {}
            for _, s in ipairs(Data.servers) do
                if State.serverCategory == "ALL" or s.category == State.serverCategory then
                    items[#items + 1] = s
                end
            end
            local per = 10
            local pages = math.max(1, math.ceil(#items / per))
            State.serverPage = math.max(1, math.min(State.serverPage, pages))
            pageLbl.Text = State.serverPage .. " / " .. pages

            local sliceCount = 0
            for i = (State.serverPage - 1) * per + 1, math.min(#items, State.serverPage * per) do
                sliceCount = sliceCount + 1
                local s = items[i]
                local url = Config.JOIN_PREFIX .. s.code
                local col = (sliceCount - 1) % 2
                local row = math.floor((sliceCount - 1) / 2)

                local sc = mk("Frame", {
                    Position = UDim2.new(col * 0.5, col == 1 and 6 or 0, 0, row * 66),
                    Size = UDim2.new(0.5, -6, 0, 56),
                    BackgroundColor3 = Palette.surface,
                    BorderSizePixel = 0,
                    ZIndex = 73
                }, grid)
                corner(sc, 8)
                stroke(sc, Palette.border, 0, 1)

                label(sc, s.label, {
                    Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -144, 0, 18),
                    Font = Enum.Font.GothamBold, TextSize = 12, ZIndex = 74
                })
                label(sc, "Private VIP Server · #" .. s.number, {
                    Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -144, 0, 16),
                    TextSize = 10, TextColor3 = Palette.inkMuted, ZIndex = 74
                })
                button(sc, "Copy", "default", {
                    Position = UDim2.new(1, -124, 0.5, -13), Size = UDim2.fromOffset(52, 26), TextSize = 11, ZIndex = 75
                }, function() copyOrNotify(url, "Server link copied") end, State.tabConns)
                button(sc, "Join", "primary", {
                    Position = UDim2.new(1, -66, 0.5, -13), Size = UDim2.fromOffset(52, 26), TextSize = 11, ZIndex = 75
                }, function() openLink(url, s.label) end, State.tabConns)
            end
            grid.Size = UDim2.new(1, 0, 0, math.max(60, math.ceil(sliceCount / 2) * 66))
        end
        render()
    end

    ----------------------------------------------------------------------
    -- Tab 6: Settings
    ----------------------------------------------------------------------
    Tabs.Settings = function(page)
        local c1 = card(page)
        pad(c1, 14, 16, 14, 16)
        vlist(c1, 10)

        label(c1, "Currency Display Mode", {
            Size = UDim2.new(1, 0, 0, 18), Font = Enum.Font.GothamBold, TextSize = 13, LayoutOrder = ord(), ZIndex = 74
        })
        local modeRow = hrow(c1, 30, 8)
        local modeSetters = {}
        for _, opt in ipairs({
            {id = "BOTH", label = "Supreme + MM2Values", w = 152},
            {id = "SV", label = "Supreme Only (SV)", w = 134},
            {id = "MV", label = "MM2Values Only (MV)", w = 144}
        }) do
            local _, set = chip(modeRow, opt.label, opt.w, function()
                Prefs.currencyMode = opt.id
                Store.savePrefs()
                for id, fn in pairs(modeSetters) do fn(id == opt.id) end
                if State.latestTrade then updateHud(State.latestTrade) end
            end)
            modeSetters[opt.id] = set
        end
        if modeSetters[Prefs.currencyMode] then modeSetters[Prefs.currencyMode](true) end

        local c2 = card(page)
        pad(c2, 14, 16, 14, 16)
        vlist(c2, 10)

        label(c2, "Interface & Behavior", {
            Size = UDim2.new(1, 0, 0, 18), Font = Enum.Font.GothamBold, TextSize = 13, LayoutOrder = ord(), ZIndex = 74
        })

        local function setting(title, desc, key, onChange)
            local f = mk("Frame", {
                Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, LayoutOrder = ord(), ZIndex = 74
            }, c2)
            label(f, title, {Size = UDim2.new(1, -56, 0, 18), Font = Enum.Font.GothamBold, TextSize = 12, ZIndex = 75})
            label(f, desc, {
                Position = UDim2.fromOffset(0, 19), Size = UDim2.new(1, -56, 0, 16),
                TextSize = 11, TextColor3 = Palette.inkMuted, ZIndex = 75
            })
            local sw = toggleSwitch(f, Prefs[key], function(v)
                Prefs[key] = v
                Store.savePrefs()
                if onChange then pcall(onChange, v) end
            end, State.tabConns)
            sw.Position = UDim2.new(1, -40, 0.5, -11)
            sw.ZIndex = 75
            for _, d in ipairs(sw:GetChildren()) do
                if d:IsA("GuiObject") then d.ZIndex = 76 end
            end
        end

        setting("Trade Slot Price Tags", "Display item values directly inside MM2 trade slots", "showTags", function(v)
            if not v then Trade.hideTags() end
        end)
        setting("Compact Trade HUD", "Minimize active trade overlay height", "compact", function() UI.applyHudSize() end)
        setting("UI Transitions", "Smooth hover and toast animations", "animations")
        setting("Low Power Mode", "Reduce polling rate and disable animations", "lowPower")
        setting("Reload After Teleport", "Automatically re-execute when joining another server", "autoQueue", function(v)
            if v and not Net.queueReload() then
                notify("Auto reload", "Not supported by this executor", Palette.warn)
            end
        end)

        local actions = hrow(page, 32, 8)
        button(actions, "Reset HUD Positions", "default", {Size = UDim2.fromOffset(146, 30), LayoutOrder = ord(), ZIndex = 75}, function()
            Prefs.hudX, Prefs.hudY, Prefs.btnX, Prefs.btnY = 16, 82, -1, 82
            UI.hud.Position = UDim2.fromOffset(16, 82)
            UI.launcher.Position = UDim2.fromOffset(math.max(16, State.screenSize.X - 132), 82)
            Store.savePrefs()
            notify("Positions reset", "HUD and launcher restored", Palette.pos)
        end, State.tabConns)
        button(actions, "Unload Dashboard", "danger", {Size = UDim2.fromOffset(132, 30), LayoutOrder = ord(), ZIndex = 75}, function()
            cleanup()
        end, State.tabConns)
    end

    function UI.selectTab(name)
        if not Tabs[name] then name = "Overview" end
        State.currentTab = name
        Win.paintTabs()
        local titles = {
            Overview = "Dashboard",
            Values = "Market Index",
            Compare = "Compare Items",
            Inventory = "Portfolio",
            Servers = "Trade Servers",
            Settings = "Settings"
        }
        Win.title.Text = titles[name] or name
        local page = Win.newPage()
        local okTab, err = pcall(Tabs[name], page)
        if not okTab then
            warn("[Carbon] Tab '" .. name .. "' failed: " .. tostring(err))
            label(page, "Failed to render view:\n" .. tostring(err):sub(1, 160), {
                Size = UDim2.new(1, 0, 0, 50), TextColor3 = Palette.neg, TextSize = 12,
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
        Win.scale.Scale = math.clamp(math.min((sx - 24) / WIN_W, (sy - 24) / WIN_H), 0.45, 1)
        UI.hudScale.Scale = math.clamp((sx - 16) / 300, 0.6, 1)
        pcall(clampInto, UI.hud)
        pcall(clampInto, UI.launcher)
        if UI.win.Visible then pcall(clampInto, UI.win) end
    end

    function UI.setWindow(visible)
        if visible then
            applyLayout()
            ensureFreshPrices(120)
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
            color, text = Palette.warn, "Syncing live feeds..."
        elseif Data.lastError or Data.supremeStale then
            color, text = Palette.warn, (Data.lastError or "Feed outdated") .. "\nSV " .. Data.supremeStamp
        else
            color, text = Palette.pos, "Feeds Connected\n" .. #Data.itemsList .. " items indexed"
        end
        State.statusText = text
        UI.launcherDot.BackgroundColor3 = color
        Win.sideDot.BackgroundColor3 = color
        Win.status.Text = text
        Win.svPill.Text = "SV " .. Data.supremeStamp
        Win.mvPill.Text = "MV " .. Data.mm2Stamp
    end

    attach(UI.launcher.MouseButton1Click, function()
        if didDragLauncher() then return end
        UI.setWindow(not UI.win.Visible)
    end)
    attach(UI.launcher.MouseEnter, function() tween(UI.launcher, {BackgroundColor3 = Palette.subtle}, 0.1) end)
    attach(UI.launcher.MouseLeave, function() tween(UI.launcher, {BackgroundColor3 = Palette.surface}, 0.12) end)
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
        if State.latestTrade then pcall(updateHud, State.latestTrade) end
        if UI.win.Visible and Win.refresh then pcall(Win.refresh) end
    end

    ----------------------------------------------------------------------
    -- Start
    ----------------------------------------------------------------------
    refreshScreen()
    if Prefs.btnX < 0 then
        UI.launcher.Position = UDim2.fromOffset(math.max(16, State.screenSize.X - 132), Prefs.btnY)
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
                warn("[Carbon] " .. tostring(err))
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
            task.wait(Prefs.lowPower and 480 or 180)
            if State.alive then
                pcall(Net.loadPrices)
                Data.loading = false
            end
        end
    end)

    notify("Carbon Dashboard ready", "Press " .. Config.TOGGLE_KEY.Name .. " or click Carbon", Palette.pos)
end, function(err)
    if debug and type(debug.traceback) == "function" then
        return debug.traceback(tostring(err), 2)
    end
    return tostring(err)
end)

if not ok then
    warn("[Carbon] " .. tostring(failure))
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
        t.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        t.TextColor3 = Color3.fromRGB(218, 30, 40)
        t.TextWrapped = true
        t.TextSize = 12
        t.Font = Enum.Font.GothamMedium
        t.Text = "CARBON ERROR\n" .. tostring(failure):sub(1, 240)
        t.Parent = g
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 8)
        c.Parent = t
    end)
end
