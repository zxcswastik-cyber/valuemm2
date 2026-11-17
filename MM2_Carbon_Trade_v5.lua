-- MM2 CARBON | Matte Monochrome Edition (Read-Only Trading & Profile Companion)
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

    -- ========================================================================
    -- STRICT MATTE MONOCHROME CARBON PALETTE (ONLY BLACK, GRAY & WHITE MATTE)
    -- ========================================================================
    local Carbon = {
        canvasTop = Color3.fromRGB(18, 18, 20),       -- Matte dark charcoal
        canvasBottom = Color3.fromRGB(10, 10, 12),    -- Matte obsidian black
        surface = Color3.fromRGB(22, 22, 25),         -- Primary matte card
        surfaceRecessed = Color3.fromRGB(14, 14, 16), -- Inset wells & table headers
        surfaceHover = Color3.fromRGB(32, 32, 36),    -- Subtle matte hover
        surfaceBar = Color3.fromRGB(13, 13, 15),      -- Top/bottom chrome bars

        hairline = Color3.fromRGB(44, 44, 50),        -- 1px matte gray border
        hairlineFocus = Color3.fromRGB(115, 115, 124),-- Focused border
        shadow = Color3.fromRGB(0, 0, 0),

        textPrimary = Color3.fromRGB(244, 244, 246),  -- Matte off-white
        textSecondary = Color3.fromRGB(162, 162, 170),-- Neutral mid-gray
        textMuted = Color3.fromRGB(106, 106, 114),    -- Muted graphite gray

        pillActive = Color3.fromRGB(242, 242, 245),   -- Matte white pill
        pillActiveHover = Color3.fromRGB(255, 255, 255),
        pillActiveInk = Color3.fromRGB(12, 12, 14),

        -- Fortnite Damage Font Gradient Stops (Black-White-Gray)
        gradTop = Color3.fromRGB(255, 255, 255),      -- Pure White
        gradMid = Color3.fromRGB(206, 206, 212),      -- Light Matte Gray
        gradBottom = Color3.fromRGB(112, 112, 120),   -- Charcoal Gray
        gradMvTop = Color3.fromRGB(232, 232, 236),    -- Soft White-Silver
        gradMvMid = Color3.fromRGB(164, 164, 172),    -- Mid Gray
        gradMvBottom = Color3.fromRGB(84, 84, 92),    -- Dark Slate Gray
        numOutline = Color3.fromRGB(8, 8, 10),        -- Deep Matte Black Stroke

        -- Monochrome Tier Edge Accents
        tierTop = Color3.fromRGB(245, 245, 248),
        tierHigh = Color3.fromRGB(178, 178, 186),
        tierMid = Color3.fromRGB(116, 116, 124),
        tierBase = Color3.fromRGB(68, 68, 74)
    }

    local NUM_FONT = Enum.Font.FredokaOne
    local FONT_BOLD = Enum.Font.GothamBold
    local FONT_MED = Enum.Font.GothamMedium
    local FONT_REG = Enum.Font.Gotham

    local State = {
        alive = true,
        conns = {},
        tabConns = {},
        tradeConns = {},
        created = {},
        badges = setmetatable({}, {__mode = "k"}),
        screenSize = Vector2.new(1280, 720),

        currentTab = "Overview",
        winCentered = false,
        tradeActive = false,
        latestTrade = nil,
        lastTradeSnapshot = nil,
        activeTradeScreen = nil,
        scheduled = false,
        prevOther = "",
        warningUntil = 0,
        toastId = 0,
        hudCollapsed = false,
        profileCollapsed = false,
        profileVisible = false,
        prevKpis = {sv = 0, mv = 0, db = 0, trades = 0},

        valueSearch = "",
        valueFilter = "All",
        valueSort = "SV_DESC",
        valuePage = 1,
        compareA = "Harvester",
        compareB = "Elderwood Scythe",
        invQuery = "",
        invQty = "1",
        invFilter = "",
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
        currencyMode = "BOTH",
        animations = true,
        lowPower = false,
        compact = false,
        showTags = true,
        showProfileHud = true,
        autoQueue = false,
        favs = {},
        wishlist = {},
        myItems = {},
        hudX = 16,
        hudY = 82,
        profX = -1,
        profY = 48,
        btnX = -1,
        btnY = 82
    }

    local UI = {}
    local Win = {order = 0, topTabs = {}}
    local Tabs = {}

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

    local function getTierAccent(row)
        if not row then return Carbon.tierMid end
        local cat = tostring(row.category or ""):lower()
        local name = tostring(row.name or ""):lower()
        if name:find("chroma", 1, true) or cat:find("ancient", 1, true) or (row.supreme or 0) >= 800 then
            return Carbon.tierTop
        elseif cat:find("godl", 1, true) or (row.supreme or 0) >= 50 then
            return Carbon.tierHigh
        elseif cat:find("vintage", 1, true) or cat:find("legend", 1, true) or (row.supreme or 0) >= 5 then
            return Carbon.tierMid
        end
        return Carbon.tierBase
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
                    if k == "hudX" or k == "hudY" or k == "btnY" or k == "profY" then
                        if v >= 0 and v < 20000 then Prefs[k] = v end
                    elseif k == "btnX" or k == "profX" then
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

    -- ========================================================================
    -- LIVE PRICE SYNCHRONIZATION ENGINE
    -- ========================================================================
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
            Data.lastError = "Offline - using cached snapshot"
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

    -- ========================================================================
    -- PURE DATA SELECTORS
    -- ========================================================================
    local Selectors = {}

    function Selectors.getPortfolioStats()
        local totalS, totalM, totalUnits, missingS, missingM = 0, 0, 0, 0, 0
        local rows = {}
        for idx, it in ipairs(Prefs.myItems) do
            local qty = math.max(1, tonumber(it.qty) or 1)
            totalUnits = totalUnits + qty
            local row = lookup(it.name)
            local sv = row and row.supreme or nil
            local mv = safeMM2(row)
            if sv then totalS = totalS + sv * qty else missingS = missingS + 1 end
            if mv then totalM = totalM + mv * qty else missingM = missingM + 1 end
            rows[#rows + 1] = {
                index = idx,
                name = it.name,
                qty = qty,
                unitSV = sv,
                unitMV = mv,
                subtotalSV = sv and (sv * qty) or nil,
                subtotalMV = mv and (mv * qty) or nil,
                category = row and row.category or "Item",
                tierColor = getTierAccent(row)
            }
        end
        return {
            totalSV = totalS,
            totalMV = totalM,
            totalUnits = totalUnits,
            stackCount = #Prefs.myItems,
            missingSV = missingS,
            missingMV = missingM,
            rows = rows
        }
    end

    function Selectors.getServerSightings()
        local jobId = tostring(game.JobId or "")
        local now = os.time()
        local out = {}
        for _, s in pairs(Data.sightings) do
            if type(s) == "table" and s.jobId == jobId and (now - (s.at or 0)) < 1800 then
                out[#out + 1] = s
            end
        end
        table.sort(out, function(a, b) return (a.value or 0) > (b.value or 0) end)
        return out
    end

    function Selectors.getWatchlistCount()
        local favs, wishes = 0, 0
        for _ in pairs(Prefs.favs) do favs = favs + 1 end
        for _ in pairs(Prefs.wishlist) do wishes = wishes + 1 end
        return favs, wishes
    end

    -- ========================================================================
    -- MATTE CARBON UI & FORTNITE DAMAGE-FONT GRADIENT PRIMITIVES
    -- ========================================================================
    local function mk(className, props, parent)
        local inst = Instance.new(className)
        for k, v in pairs(props or {}) do
            inst[k] = v
        end
        inst.Parent = parent
        return inst
    end

    local function corner(obj, r)
        return mk("UICorner", {CornerRadius = UDim.new(0, r or 8)}, obj)
    end

    local function borderStroke(obj, color, trans, thickness)
        return mk("UIStroke", {
            Color = color or Carbon.hairline,
            Transparency = trans or 0,
            Thickness = thickness or 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        }, obj)
    end

    local function textStroke(obj, color, thickness)
        return mk("UIStroke", {
            Color = color or Carbon.numOutline,
            Transparency = 0,
            Thickness = thickness or 2.2,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
        }, obj)
    end

    local function applyMatteCarbonGradient(frame)
        return mk("UIGradient", {
            Rotation = 90,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Carbon.canvasTop),
                ColorSequenceKeypoint.new(1.00, Carbon.canvasBottom)
            })
        }, frame)
    end

    -- Fortnite Damage-Font Black-White-Gray Gradient
    local function applyMonochromeDamageGradient(labelObj, variant)
        local old = labelObj:FindFirstChild("DamageMonoGrad")
        if old then old:Destroy() end
        local topC = (variant == "mv") and Carbon.gradMvTop or Carbon.gradTop
        local midC = (variant == "mv") and Carbon.gradMvMid or Carbon.gradMid
        local botC = (variant == "mv") and Carbon.gradMvBottom or Carbon.gradBottom
        return mk("UIGradient", {
            Name = "DamageMonoGrad",
            Rotation = 90,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, topC),
                ColorSequenceKeypoint.new(0.55, midC),
                ColorSequenceKeypoint.new(1.00, botC)
            })
        }, labelObj)
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
            Padding = UDim.new(0, gap or 12)
        }, obj)
    end

    local Motion = {}

    function Motion.spring(obj, props, duration)
        if not Prefs.animations or Prefs.lowPower then
            for k, v in pairs(props) do
                pcall(function() obj[k] = v end)
            end
            return
        end
        pcall(function()
            TweenService:Create(
                obj,
                TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                props
            ):Play()
        end)
    end

    function Motion.staggerIn(frames, stepDelay)
        if not Prefs.animations or Prefs.lowPower then return end
        for idx, frame in ipairs(frames) do
            if frame and frame:IsA("GuiObject") then
                local origPos = frame.Position
                frame.Position = UDim2.new(origPos.X.Scale, origPos.X.Offset, origPos.Y.Scale, origPos.Y.Offset + 8)
                task.delay((idx - 1) * (stepDelay or 0.03), function()
                    if State.alive and frame.Parent then
                        Motion.spring(frame, {Position = origPos}, 0.22)
                    end
                end)
            end
        end
    end

    function Motion.animateNumber(labelObj, fromVal, toVal, formatter, suffix)
        formatter = formatter or formatVal
        suffix = suffix or ""
        if not Prefs.animations or Prefs.lowPower or fromVal == toVal then
            labelObj.Text = formatter(toVal) .. suffix
            return
        end
        local steps = 12
        for i = 1, steps do
            task.delay(i * 0.018, function()
                if State.alive and labelObj.Parent then
                    local t = 1 - math.pow(1 - (i / steps), 3)
                    local cur = fromVal + (toVal - fromVal) * t
                    labelObj.Text = formatter(math.floor(cur + 0.5)) .. suffix
                end
            end)
        end
    end

    local function label(parent, text, props)
        local p = {
            BackgroundTransparency = 1,
            Text = tostring(text or ""),
            Font = FONT_MED,
            TextSize = 12,
            TextColor3 = Carbon.textPrimary,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            BorderSizePixel = 0
        }
        for k, v in pairs(props or {}) do p[k] = v end
        return mk("TextLabel", p, parent)
    end

    -- Fortnite Damage Font with Black-White-Gray Gradient + Heavy Black Outline
    local function damageNumber(parent, text, variant, props)
        local stThick = 2.2
        local p = {
            BackgroundTransparency = 1,
            Text = tostring(text or ""),
            Font = NUM_FONT,
            TextSize = 18,
            TextColor3 = Color3.fromRGB(255, 255, 255), -- Pure white base so UIGradient renders exact B/W/G stops
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            BorderSizePixel = 0
        }
        for k, v in pairs(props or {}) do
            if k == "StrokeThickness" then
                stThick = v
            else
                p[k] = v
            end
        end
        local lbl = mk("TextLabel", p, parent)
        textStroke(lbl, Carbon.numOutline, stThick)
        applyMonochromeDamageGradient(lbl, variant or "sv")
        return lbl
    end

    local function button(parent, text, style, props, onClick, bucket)
        local isPrimary = style == "primary"
        local isGhost = style == "ghost"

        local bg = isPrimary and Carbon.pillActive or Carbon.surface
        local bgHover = isPrimary and Carbon.pillActiveHover or Carbon.surfaceHover
        local fg = isPrimary and Carbon.pillActiveInk or (isGhost and Carbon.textSecondary or Carbon.textPrimary)

        local p = {
            Text = tostring(text or ""),
            Font = FONT_BOLD,
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
        corner(b, 8)
        if not isGhost and not isPrimary then
            borderStroke(b, Carbon.hairline, 0, 1)
        end

        attach(b.MouseEnter, function()
            Motion.spring(b, {
                BackgroundColor3 = bgHover,
                BackgroundTransparency = 0,
                TextColor3 = isPrimary and Carbon.pillActiveInk or Carbon.textPrimary
            }, 0.1)
        end, bucket)
        attach(b.MouseLeave, function()
            Motion.spring(b, {
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
            BackgroundColor3 = Carbon.surfaceRecessed,
            TextColor3 = Carbon.textPrimary,
            PlaceholderColor3 = Carbon.textMuted,
            Font = FONT_MED,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            BorderSizePixel = 0
        }
        for k, v in pairs(props or {}) do p[k] = v end
        local box = mk("TextBox", p, parent)
        corner(box, 8)
        local st = borderStroke(box, Carbon.hairline, 0, 1)
        pad(box, 0, 12, 0, 12)

        attach(box.Focused, function()
            Motion.spring(st, {Color = Carbon.hairlineFocus}, 0.12)
        end)
        attach(box.FocusLost, function()
            Motion.spring(st, {Color = Carbon.hairline}, 0.12)
        end)
        return box
    end

    local function toggleSwitch(parent, initialState, onToggle, bucket)
        local state = initialState == true
        local pillBtn = mk("TextButton", {
            Size = UDim2.fromOffset(42, 22),
            BackgroundColor3 = state and Carbon.pillActive or Carbon.surfaceRecessed,
            Text = "",
            AutoButtonColor = false,
            BorderSizePixel = 0
        }, parent)
        corner(pillBtn, 11)
        local st = borderStroke(pillBtn, state and Carbon.pillActive or Carbon.hairline, 0, 1)

        local thumb = mk("Frame", {
            Size = UDim2.fromOffset(16, 16),
            Position = state and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3),
            BackgroundColor3 = state and Carbon.pillActiveInk or Carbon.textSecondary,
            BorderSizePixel = 0
        }, pillBtn)
        corner(thumb, 8)

        attach(pillBtn.MouseButton1Click, function()
            if not State.alive then return end
            state = not state
            Motion.spring(pillBtn, {BackgroundColor3 = state and Carbon.pillActive or Carbon.surfaceRecessed}, 0.14)
            Motion.spring(thumb, {
                Position = state and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3),
                BackgroundColor3 = state and Carbon.pillActiveInk or Carbon.textSecondary
            }, 0.14)
            st.Color = state and Carbon.pillActive or Carbon.hairline
            if onToggle then onToggle(state) end
        end, bucket)

        return pillBtn
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

    -- Smooth Dragging Handler (works with both Mouse and Touch, converts Scale to Offset cleanly)
    local function makeDraggable(target, handle, onDragStep, onMoved)
        local activeInput, dragStart, startX, startY
        local moved = false

        attach(handle.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                activeInput = input
                dragStart = input.Position
                -- Convert current visual top-left position into exact pixel offsets
                local rootPos = UI.root and UI.root.AbsolutePosition or Vector2.zero
                local curAbs = target.AbsolutePosition - rootPos
                startX = curAbs.X
                startY = curAbs.Y
                moved = false
            end
        end)

        attach(UserInputService.InputChanged, function(input)
            if not activeInput or not dragStart or not startX then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement and input ~= activeInput then return end
            local delta = input.Position - dragStart
            if delta.Magnitude > 4 then moved = true end
            if not moved then return end

            local abs = target.AbsoluteSize
            local maxX = math.max(0, State.screenSize.X - abs.X)
            local maxY = math.max(0, State.screenSize.Y - abs.Y)
            local nx = math.clamp(math.floor(startX + delta.X), 0, maxX)
            local ny = math.clamp(math.floor(startY + delta.Y), 0, maxY)
            target.Position = UDim2.fromOffset(nx, ny)
            if onDragStep then
                pcall(onDragStep, nx, ny)
            end
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

    -- ========================================================================
    -- ROOT SCREENGUI, TOAST, LAUNCHER, TRADE HUD & PROFILE VALUATION PILL
    -- ========================================================================
    UI.root = track(mk("ScreenGui", {
        Name = "MM2CarbonX",
        ResetOnSpawn = false,
        IgnoreGuiInset = false,
        DisplayOrder = 3900,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    }, playerGui))

    UI.toast = mk("Frame", {
        Position = UDim2.new(0.5, -150, 0, 14),
        Size = UDim2.fromOffset(300, 44),
        BackgroundColor3 = Carbon.surface,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 90
    }, UI.root)
    corner(UI.toast, 10)
    borderStroke(UI.toast, Carbon.hairline, 0, 1)

    UI.toastDot = mk("Frame", {
        Position = UDim2.fromOffset(14, 18),
        Size = UDim2.fromOffset(8, 8),
        BackgroundColor3 = Carbon.textPrimary,
        BorderSizePixel = 0,
        ZIndex = 92
    }, UI.toast)
    corner(UI.toastDot, 4)

    UI.toastTitle = label(UI.toast, "", {
        Position = UDim2.fromOffset(30, 5),
        Size = UDim2.new(1, -40, 0, 16),
        Font = FONT_BOLD,
        TextSize = 11,
        ZIndex = 92
    })
    UI.toastBody = label(UI.toast, "", {
        Position = UDim2.fromOffset(30, 22),
        Size = UDim2.new(1, -40, 0, 15),
        Font = FONT_REG,
        TextSize = 10,
        TextColor3 = Carbon.textSecondary,
        ZIndex = 92
    })

    local function notify(title, body, tint)
        State.toastId = State.toastId + 1
        local id = State.toastId
        UI.toastDot.BackgroundColor3 = tint or Carbon.textPrimary
        UI.toastTitle.Text = tostring(title or "Carbon")
        UI.toastBody.Text = tostring(body or "")
        UI.toast.Visible = true
        if Prefs.animations and not Prefs.lowPower then
            UI.toast.Position = UDim2.new(0.5, -150, 0, 6)
            Motion.spring(UI.toast, {Position = UDim2.new(0.5, -150, 0, 14)}, 0.16)
        end
        task.delay(2.4, function()
            if State.alive and State.toastId == id then
                UI.toast.Visible = false
            end
        end)
    end

    -- Floating Matte Carbon Capsule Launcher
    local startBtnX = Prefs.btnX >= 0 and Prefs.btnX or math.max(16, State.screenSize.X - 138)
    UI.launcher = mk("TextButton", {
        Name = "CarbonLauncher",
        Position = UDim2.fromOffset(startBtnX, Prefs.btnY),
        Size = UDim2.fromOffset(122, 32),
        BackgroundColor3 = Carbon.surface,
        Text = "",
        AutoButtonColor = false,
        BorderSizePixel = 0,
        ZIndex = 60
    }, UI.root)
    corner(UI.launcher, 16)
    borderStroke(UI.launcher, Carbon.hairline, 0, 1)

    UI.launcherDot = mk("Frame", {
        Position = UDim2.fromOffset(12, 12),
        Size = UDim2.fromOffset(8, 8),
        BackgroundColor3 = Carbon.textPrimary,
        BorderSizePixel = 0,
        ZIndex = 62
    }, UI.launcher)
    corner(UI.launcherDot, 4)

    damageNumber(UI.launcher, "CARBON", "sv", {
        Position = UDim2.fromOffset(25, 0),
        Size = UDim2.fromOffset(60, 32),
        TextSize = 13,
        StrokeThickness = 1.8,
        ZIndex = 62
    })

    local mm2Pill = mk("TextLabel", {
        Text = "MM2",
        Position = UDim2.new(1, -35, 0.5, -8),
        Size = UDim2.fromOffset(27, 16),
        BackgroundColor3 = Carbon.surfaceRecessed,
        TextColor3 = Carbon.textSecondary,
        Font = FONT_BOLD,
        TextSize = 9,
        BorderSizePixel = 0,
        ZIndex = 62
    }, UI.launcher)
    corner(mm2Pill, 5)

    local didDragLauncher = makeDraggable(UI.launcher, UI.launcher, nil, function(x, y)
        Prefs.btnX = math.floor(x)
        Prefs.btnY = math.floor(y)
        Store.savePrefs()
    end)

    -- Compact Non-Intrusive Player Profile Valuation Pill (Top-Center Docked & Draggable)
    local startProfX = Prefs.profX >= 0 and Prefs.profX or math.max(16, math.floor(State.screenSize.X * 0.5 - 155))
    UI.profileHud = mk("Frame", {
        Name = "ProfileValuationPill",
        Position = UDim2.fromOffset(startProfX, Prefs.profY),
        Size = UDim2.fromOffset(310, 42),
        BackgroundColor3 = Carbon.surfaceBar,
        BackgroundTransparency = 0.06,
        BorderSizePixel = 0,
        Visible = false,
        Active = true,
        ZIndex = 55
    }, UI.root)
    corner(UI.profileHud, 10)
    borderStroke(UI.profileHud, Carbon.hairline, 0, 1)

    UI.profName = label(UI.profileHud, "Player", {
        Position = UDim2.fromOffset(12, 4),
        Size = UDim2.fromOffset(116, 16),
        Font = FONT_BOLD,
        TextSize = 11,
        TextColor3 = Carbon.textPrimary,
        ZIndex = 56
    })
    UI.profMeta = label(UI.profileHud, "0 items", {
        Position = UDim2.fromOffset(12, 20),
        Size = UDim2.fromOffset(116, 15),
        Font = FONT_REG,
        TextSize = 10,
        TextColor3 = Carbon.textMuted,
        ZIndex = 56
    })

    UI.profSV = damageNumber(UI.profileHud, "SV 0", "sv", {
        Position = UDim2.fromOffset(130, 0),
        Size = UDim2.fromOffset(86, 42),
        TextSize = 14,
        StrokeThickness = 2,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 56
    })
    UI.profMV = damageNumber(UI.profileHud, "MV 0", "mv", {
        Position = UDim2.fromOffset(220, 0),
        Size = UDim2.fromOffset(78, 42),
        TextSize = 14,
        StrokeThickness = 2,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 56
    })

    makeDraggable(UI.profileHud, UI.profileHud, nil, function(x, y)
        Prefs.profX = math.floor(x)
        Prefs.profY = math.floor(y)
        Store.savePrefs()
    end)

    -- Live Trade HUD (Compact Matte Carbon Floating Card)
    UI.hud = mk("Frame", {
        Name = "TradeHUD",
        Position = UDim2.fromOffset(Prefs.hudX, Prefs.hudY),
        Size = UDim2.fromOffset(296, 114),
        BackgroundColor3 = Carbon.surface,
        BackgroundTransparency = 0.04,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 50
    }, UI.root)
    corner(UI.hud, 10)
    UI.hudStroke = borderStroke(UI.hud, Carbon.hairline, 0, 1)
    UI.hudScale = mk("UIScale", {Scale = 1}, UI.hud)

    UI.hudTopBar = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = Carbon.surfaceBar,
        BorderSizePixel = 0,
        Active = true,
        ZIndex = 52
    }, UI.hud)
    corner(UI.hudTopBar, 10)

    UI.hudTitle = label(UI.hudTopBar, "Trade Evaluator", {
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -110, 1, 0),
        Font = FONT_BOLD,
        TextSize = 11,
        TextColor3 = Carbon.textPrimary,
        ZIndex = 53
    })

    UI.hudBadge = mk("TextLabel", {
        Text = "FAIR",
        Position = UDim2.new(1, -92, 0, 5),
        Size = UDim2.fromOffset(56, 20),
        BackgroundColor3 = Carbon.surfaceHover,
        TextColor3 = Carbon.textSecondary,
        Font = FONT_BOLD,
        TextSize = 9,
        BorderSizePixel = 0,
        ZIndex = 53
    }, UI.hudTopBar)
    corner(UI.hudBadge, 5)

    UI.hudCollapse = button(UI.hudTopBar, "–", "ghost", {
        Position = UDim2.new(1, -30, 0, 3),
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
        Position = UDim2.fromOffset(0, 30),
        Size = UDim2.new(1, 0, 1, -30),
        BackgroundTransparency = 1,
        ZIndex = 52
    }, UI.hud)

    mk("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Carbon.hairline,
        BorderSizePixel = 0,
        ZIndex = 53
    }, UI.hudBody)

    local function hudRow(y, caption)
        label(UI.hudBody, caption, {
            Position = UDim2.fromOffset(10, y), Size = UDim2.fromOffset(44, 22),
            Font = FONT_BOLD, TextSize = 10, TextColor3 = Carbon.textMuted, ZIndex = 53
        })
        local s = damageNumber(UI.hudBody, "SV —", "sv", {
            Position = UDim2.fromOffset(56, y), Size = UDim2.fromOffset(116, 22),
            TextSize = 14, StrokeThickness = 2,
            TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 53
        })
        local m = damageNumber(UI.hudBody, "MV —", "mv", {
            Position = UDim2.fromOffset(176, y), Size = UDim2.fromOffset(110, 22),
            TextSize = 14, StrokeThickness = 2,
            TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 53
        })
        return s, m
    end
    UI.ownS, UI.ownM = hudRow(5, "YOU")
    UI.themS, UI.themM = hudRow(28, "THEM")

    UI.hudDiff = label(UI.hudBody, "Net Spread  —", {
        Position = UDim2.fromOffset(10, 54), Size = UDim2.new(1, -20, 0, 18),
        Font = FONT_MED, TextSize = 10, TextColor3 = Carbon.textSecondary, ZIndex = 53
    })

    UI.hudWarnBar = mk("Frame", {
        Position = UDim2.fromOffset(10, 76),
        Size = UDim2.new(1, -20, 0, 20),
        BackgroundColor3 = Carbon.surfaceRecessed,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 53
    }, UI.hudBody)
    corner(UI.hudWarnBar, 5)
    borderStroke(UI.hudWarnBar, Carbon.hairlineFocus, 0, 1)
    UI.hudWarnText = label(UI.hudWarnBar, "", {
        Size = UDim2.new(1, 0, 1, 0), Font = FONT_BOLD, TextSize = 10, TextColor3 = Carbon.textPrimary,
        TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 54
    })

    function UI.applyHudSize()
        local h
        if State.hudCollapsed then
            h = 30
        else
            h = (Prefs.compact and 90 or 112) + (UI.hudWarnBar.Visible and 26 or 0)
        end
        UI.hudBody.Visible = not State.hudCollapsed
        UI.hudDiff.Visible = not Prefs.compact
        UI.hudWarnBar.Position = UDim2.fromOffset(10, Prefs.compact and 54 or 76)
        UI.hud.Size = UDim2.fromOffset(296, h)
    end
    UI.applyHudSize()

    makeDraggable(UI.hud, UI.hudTopBar, nil, function(x, y)
        Prefs.hudX = math.max(0, math.floor(x))
        Prefs.hudY = math.max(0, math.floor(y))
        Store.savePrefs()
    end)

    -- ========================================================================
    -- CLEANUP & SHARED HELPERS
    -- ========================================================================
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

    -- ========================================================================
    -- READ-ONLY TRADE EVALUATOR, PROFILE INSPECTOR & SERVER SIGHTINGS
    -- ========================================================================
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
            Font = NUM_FONT,
            TextSize = 10,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundColor3 = Carbon.surfaceBar,
            BackgroundTransparency = 0.14,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, 0, 1, -2),
            Size = UDim2.new(1, -6, 0, 15),
            TextTruncate = Enum.TextTruncate.AtEnd,
            Visible = false,
            Active = false,
            Selectable = false,
            ZIndex = 75
        }, slot)
        corner(b, 4)
        borderStroke(b, Carbon.hairline, 0, 1)
        textStroke(b, Carbon.numOutline, 1.8)
        applyMonochromeDamageGradient(b, "sv")
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
                            tag.Text = "SV " .. formatVal(sTotal)
                            applyMonochromeDamageGradient(tag, "sv")
                        else
                            if Prefs.currencyMode == "SV" then
                                tag.Text = "SV " .. formatVal(sTotal)
                                applyMonochromeDamageGradient(tag, "sv")
                            elseif Prefs.currencyMode == "MV" then
                                tag.Text = "MV " .. formatVal(mTotal)
                                applyMonochromeDamageGradient(tag, "mv")
                            else
                                tag.Text = "SV " .. formatVal(sTotal) .. " · MV " .. formatVal(mTotal)
                                applyMonochromeDamageGradient(tag, "sv")
                            end
                        end
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

    -- Player Profile / Inspect Inventory Detector (Read-Only)
    local function scanOpenedPlayerProfile()
        if not Prefs.showProfileHud or not Data.loaded then
            if State.profileVisible then
                State.profileVisible = false
                UI.profileHud.Visible = false
            end
            return
        end

        local myNameLow = tostring(player.Name or ""):lower()
        local myDispLow = tostring(player.DisplayName or ""):lower()

        -- Build lookup map of other players currently in server
        local otherPlayers = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player then
                local n1 = tostring(p.Name or ""):lower()
                local n2 = tostring(p.DisplayName or ""):lower()
                if n1 ~= "" then otherPlayers[n1] = p.DisplayName or p.Name end
                if n2 ~= "" then otherPlayers[n2] = p.DisplayName or p.Name end
            end
        end

        local bestContainer = nil
        local detectedPlayerName = nil

        -- 1. Look for visible Profile / Inspect containers inside PlayerGui
        for _, screen in ipairs(playerGui:GetChildren()) do
            if screen ~= UI.root and screen:IsA("ScreenGui") and screen.Enabled ~= false
                and screen.Name ~= "TradeGUI" and screen.Name ~= "TradeGUI_Phone" then
                for _, desc in ipairs(screen:GetDescendants()) do
                    if desc:IsA("GuiObject") and desc.Visible then
                        local nm = desc.Name:lower()
                        if nm:find("profile", 1, true) or nm:find("inspect", 1, true) or nm:find("viewinv", 1, true) then
                            if isShown(desc) then
                                -- Verify it isn't our own profile
                                local isSelf = false
                                local foundOther = nil
                                for _, lbl in ipairs(desc:GetDescendants()) do
                                    if lbl:IsA("TextLabel") and lbl.Visible then
                                        local txt = trim(lbl.Text)
                                        local low = txt:lower()
                                        if low == myNameLow or low == myDispLow then
                                            isSelf = true
                                        elseif otherPlayers[low] then
                                            foundOther = otherPlayers[low]
                                        end
                                    end
                                end
                                if not isSelf then
                                    bestContainer = desc
                                    detectedPlayerName = foundOther or "Player Profile"
                                    break
                                end
                            end
                        end
                    end
                end
            end
            if bestContainer then break end
        end

        if not bestContainer then
            if State.profileVisible then
                State.profileVisible = false
                UI.profileHud.Visible = false
            end
            return
        end

        -- 2. Sum all visible item cards inside the inspected player's profile
        local totalSV, totalMV, totalItems, pricedItems = 0, 0, 0, 0
        local seenSlots = {}

        for _, desc in ipairs(bestContainer:GetDescendants()) do
            if desc:IsA("GuiObject") and desc.Visible and not seenSlots[desc] then
                -- Standard MM2 item card has an ItemName child
                local itemNameObj = desc:FindFirstChild("ItemName")
                if itemNameObj then
                    seenSlots[desc] = true
                    local name, amount = readSlot(desc)
                    if name then
                        totalItems = totalItems + amount
                        local row = lookup(name)
                        if row then
                            pricedItems = pricedItems + amount
                            if row.supreme then totalSV = totalSV + row.supreme * amount end
                            local mv = safeMM2(row)
                            if mv then totalMV = totalMV + mv * amount end
                        end
                    end
                end
            end
        end

        if totalItems == 0 then
            if State.profileVisible then
                State.profileVisible = false
                UI.profileHud.Visible = false
            end
            return
        end

        UI.profName.Text = tostring(detectedPlayerName or "Player Profile")
        UI.profMeta.Text = totalItems .. " items (" .. pricedItems .. " priced)"
        UI.profSV.Text = "SV " .. formatVal(totalSV)
        UI.profMV.Text = "MV " .. formatVal(totalMV)
        UI.profileHud.Visible = true
        State.profileVisible = true
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
            notify("Trade completed", entry.delta and ("Net change " .. Util.signed(entry.delta) .. " SV") or "Confirmed by game", Carbon.textPrimary)
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

        local d = other.s - mine.s
        local dm = other.m - mine.m
        local txt, fg, bg
        if mine.count + other.count == 0 then
            txt, fg, bg = "EMPTY", Carbon.textSecondary, Carbon.surfaceHover
        elseif not Data.loaded then
            txt, fg, bg = "SYNC", Carbon.textSecondary, Carbon.surfaceRecessed
        elseif incomplete then
            txt, fg, bg = "N/A", Carbon.textSecondary, Carbon.surfaceRecessed
        else
            local base = math.max(mine.s, other.s)
            if math.abs(d) <= math.max(2, base * 0.05) then
                txt, fg, bg = "FAIR", Carbon.textPrimary, Carbon.surfaceHover
            elseif d > 0 then
                txt, fg, bg = "WIN", Carbon.pillActiveInk, Carbon.pillActive
            else
                txt, fg, bg = "LOSS", Carbon.textSecondary, Carbon.surfaceRecessed
            end
        end
        UI.hudBadge.Text = txt
        UI.hudBadge.TextColor3 = fg
        UI.hudBadge.BackgroundColor3 = bg
        UI.hudStroke.Color = (txt == "WIN") and Carbon.pillActive or Carbon.hairline

        if incomplete or not Data.loaded then
            UI.hudDiff.Text = "Net Spread  incomplete"
        else
            UI.hudDiff.Text = "Net Spread  " .. Util.signed(d) .. " SV   ·   " .. Util.signed(dm) .. " MV"
        end

        local warnMsg
        if os.clock() < State.warningUntil then
            warnMsg = "Offer modified — re-verify items"
        elseif not Data.loaded then
            warnMsg = "Syncing live values..."
        elseif incomplete then
            warnMsg = "Unlisted item in trade"
        elseif Data.supremeStale then
            warnMsg = "Price feed may be outdated"
        elseif mine.s > 0 and other.s < mine.s * 0.75 then
            warnMsg = "You are giving >25% more value"
        end
        local wasVisible = UI.hudWarnBar.Visible
        UI.hudWarnBar.Visible = warnMsg ~= nil
        if warnMsg then
            UI.hudWarnText.Text = warnMsg
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
                notify("Offer changed", "Re-check their items before accepting", Carbon.textPrimary)
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

        if Trade.tick % 2 == 0 then
            pcall(scanOpenedPlayerProfile)
        end
    end

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

    -- ========================================================================
    -- DRAGGABLE MATTE CARBON DESKTOP / MOBILE APPLICATION SHELL
    -- ========================================================================
    local Shell = {}

    local function ord()
        Win.order = Win.order + 1
        return Win.order
    end

    local function clearChildren(f)
        for _, c in ipairs(f:GetChildren()) do
            if c:IsA("GuiObject") then c:Destroy() end
        end
    end

    local function computeShellSize()
        refreshScreen()
        local vw, vh = State.screenSize.X, State.screenSize.Y
        local targetW = math.clamp(math.floor(vw * 0.92), 660, 1680)
        local targetH = math.clamp(math.floor(vh * 0.88), 420, 980)
        return targetW, targetH
    end

    function Shell.build()
        local w, h = computeShellSize()
        local topH = 50
        local botH = 36
        local initX = math.max(8, math.floor((State.screenSize.X - w) * 0.5))
        local initY = math.max(8, math.floor((State.screenSize.Y - h) * 0.5))

        -- Using AnchorPoint (0, 0) + Offset coordinates guarantees smooth, jump-free dragging
        UI.win = mk("Frame", {
            Name = "Window",
            AnchorPoint = Vector2.new(0, 0),
            Position = UDim2.fromOffset(initX, initY),
            Size = UDim2.fromOffset(w, h),
            BackgroundColor3 = Carbon.canvasBottom,
            BorderSizePixel = 0,
            Visible = false,
            Active = true,
            ClipsDescendants = true,
            ZIndex = 70
        }, UI.root)
        corner(UI.win, 14)
        borderStroke(UI.win, Carbon.hairline, 0, 1)
        applyMatteCarbonGradient(UI.win)
        Win.scale = mk("UIScale", {Scale = 1}, UI.win)

        local shadow = mk("Frame", {
            Name = "CarbonShadow",
            AnchorPoint = Vector2.new(0, 0),
            Position = UDim2.fromOffset(initX - 6, initY),
            Size = UDim2.fromOffset(w + 12, h + 12),
            BackgroundColor3 = Carbon.shadow,
            BackgroundTransparency = 0.62,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 69
        }, UI.root)
        corner(shadow, 18)
        Shell.shadow = shadow

        -- TOP DRAGGABLE APPLICATION BAR
        local topbar = mk("Frame", {
            Name = "Topbar",
            Size = UDim2.new(1, 0, 0, topH),
            BackgroundColor3 = Carbon.surfaceBar,
            BorderSizePixel = 0,
            Active = true,
            ZIndex = 72
        }, UI.win)
        mk("Frame", {
            Position = UDim2.new(0, 0, 1, -1),
            Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = Carbon.hairline,
            BorderSizePixel = 0,
            ZIndex = 73
        }, topbar)

        -- Left Drag Grip + Brand Identity
        label(topbar, "⋮⋮", {
            Position = UDim2.fromOffset(10, 0),
            Size = UDim2.fromOffset(14, topH),
            Font = FONT_BOLD,
            TextSize = 12,
            TextColor3 = Carbon.textMuted,
            ZIndex = 74
        })

        Win.sideDot = mk("Frame", {
            Position = UDim2.fromOffset(26, 21),
            Size = UDim2.fromOffset(7, 7),
            BackgroundColor3 = Carbon.textPrimary,
            BorderSizePixel = 0,
            ZIndex = 74
        }, topbar)
        corner(Win.sideDot, 4)

        local brandLbl = damageNumber(topbar, "CARBON", "sv", {
            Position = UDim2.fromOffset(38, 0),
            Size = UDim2.fromOffset(66, topH),
            TextSize = 14,
            StrokeThickness = 1.8,
            ZIndex = 74
        })

        -- Responsive Segmented Navigation Well
        local navWell = mk("Frame", {
            Position = UDim2.fromOffset(112, 9),
            Size = UDim2.fromOffset(476, 32),
            BackgroundColor3 = Carbon.surfaceRecessed,
            BorderSizePixel = 0,
            ZIndex = 73
        }, topbar)
        corner(navWell, 8)
        borderStroke(navWell, Carbon.hairline, 0, 1)
        pad(navWell, 3, 3, 3, 3)

        mk("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 2)
        }, navWell)

        local navItems = {
            {id = "Overview",  label = "Overview", w = 74},
            {id = "Values",    label = "Market",   w = 68},
            {id = "Compare",   label = "Compare",  w = 72},
            {id = "Inventory", label = "Portfolio",w = 76},
            {id = "Servers",   label = "Servers",  w = 68},
            {id = "Settings",  label = "Settings", w = 72}
        }

        for idx, item in ipairs(navItems) do
            local b = mk("TextButton", {
                Name = item.id .. "Tab",
                Text = item.label,
                Size = UDim2.fromOffset(item.w, 26),
                BackgroundColor3 = Carbon.pillActive,
                BackgroundTransparency = 1,
                TextColor3 = Carbon.textSecondary,
                Font = FONT_BOLD,
                TextSize = 11,
                AutoButtonColor = false,
                BorderSizePixel = 0,
                LayoutOrder = idx,
                ZIndex = 74
            }, navWell)
            corner(b, 6)

            Win.topTabs[item.id] = b

            attach(b.MouseEnter, function()
                if State.currentTab ~= item.id then
                    b.TextColor3 = Carbon.textPrimary
                end
            end)
            attach(b.MouseLeave, function()
                if State.currentTab ~= item.id then
                    b.TextColor3 = Carbon.textSecondary
                end
            end)
            attach(b.MouseButton1Click, function()
                if State.alive then UI.selectTab(item.id) end
            end)
        end

        -- Top-Right Dataset Dates + Sync + Close
        local feedWell = mk("Frame", {
            Position = UDim2.new(1, -220, 0, 10),
            Size = UDim2.fromOffset(126, 30),
            BackgroundColor3 = Carbon.surfaceRecessed,
            BorderSizePixel = 0,
            ZIndex = 73
        }, topbar)
        corner(feedWell, 7)
        borderStroke(feedWell, Carbon.hairline, 0, 1)

        Win.svPill = damageNumber(feedWell, "SV —", "sv", {
            Position = UDim2.fromOffset(7, 0),
            Size = UDim2.fromOffset(54, 30),
            TextSize = 11,
            StrokeThickness = 1.6,
            ZIndex = 74
        })
        Win.mvPill = damageNumber(feedWell, "MV —", "mv", {
            Position = UDim2.fromOffset(63, 0),
            Size = UDim2.fromOffset(56, 30),
            TextSize = 11,
            StrokeThickness = 1.6,
            TextXAlignment = Enum.TextXAlignment.Right,
            ZIndex = 74
        })

        button(topbar, "Sync", "primary", {
            Position = UDim2.new(1, -88, 0, 10),
            Size = UDim2.fromOffset(46, 30),
            TextSize = 11,
            ZIndex = 74
        }, function()
            notify("Syncing", "Updating Supreme & MM2Values datasets...", Carbon.textPrimary)
            task.spawn(function()
                pcall(Net.loadPrices)
                Data.loading = false
            end)
        end)

        button(topbar, "×", "ghost", {
            Position = UDim2.new(1, -38, 0, 10),
            Size = UDim2.fromOffset(28, 30),
            TextSize = 15,
            ZIndex = 74
        }, function()
            UI.setWindow(false)
        end)

        -- Attach smooth drag to topbar AND brand label (updates shadow in real time)
        local function syncShadowPos(nx, ny)
            shadow.Position = UDim2.fromOffset(nx - 6, ny)
        end
        makeDraggable(UI.win, topbar, syncShadowPos)
        makeDraggable(UI.win, brandLbl, syncShadowPos)

        -- MAIN WORKSPACE CONTAINER
        Win.content = mk("Frame", {
            Name = "Workspace",
            Position = UDim2.fromOffset(0, topH),
            Size = UDim2.new(1, 0, 1, -(topH + botH)),
            BackgroundTransparency = 1,
            ZIndex = 71
        }, UI.win)

        -- BOTTOM DRAGGABLE TELEMETRY FOOTER BAR
        local bottomBar = mk("Frame", {
            Position = UDim2.new(0, 0, 1, -botH),
            Size = UDim2.new(1, 0, 0, botH),
            BackgroundColor3 = Carbon.surfaceBar,
            BorderSizePixel = 0,
            Active = true,
            ZIndex = 72
        }, UI.win)
        mk("Frame", {
            Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = Carbon.hairline,
            BorderSizePixel = 0,
            ZIndex = 73
        }, bottomBar)
        makeDraggable(UI.win, bottomBar, syncShadowPos)

        Win.status = label(bottomBar, "Syncing live feeds...", {
            Position = UDim2.fromOffset(18, 0),
            Size = UDim2.fromOffset(300, botH),
            Font = FONT_MED,
            TextSize = 11,
            TextColor3 = Carbon.textSecondary,
            ZIndex = 73
        })

        label(bottomBar, "Drag top bar to move  ·  " .. Config.TOGGLE_KEY.Name, {
            Position = UDim2.new(1, -240, 0, 0),
            Size = UDim2.fromOffset(222, botH),
            Font = FONT_MED,
            TextSize = 10,
            TextColor3 = Carbon.textMuted,
            TextXAlignment = Enum.TextXAlignment.Right,
            ZIndex = 73
        })

        function Win.paintTabs()
            for id, b in pairs(Win.topTabs) do
                local active = (State.currentTab == id)
                if active then
                    Motion.spring(b, {
                        BackgroundTransparency = 0,
                        BackgroundColor3 = Carbon.pillActive,
                        TextColor3 = Carbon.pillActiveInk
                    }, 0.14)
                else
                    Motion.spring(b, {
                        BackgroundTransparency = 1,
                        TextColor3 = Carbon.textSecondary
                    }, 0.14)
                end
            end
        end

        function Shell.applyResponsiveGeometry()
            local nw, nh = computeShellSize()
            UI.win.Size = UDim2.fromOffset(nw, nh)
            shadow.Size = UDim2.fromOffset(nw + 12, nh + 12)

            -- Keep navigation well neatly centered between brand and right controls without ever overlapping
            local leftBound = 108
            local rightBound = nw - 228
            local avail = math.max(340, rightBound - leftBound)
            local wellW = math.min(476, avail)
            navWell.Size = UDim2.fromOffset(wellW, 32)
            navWell.Position = UDim2.fromOffset(leftBound + math.floor((avail - wellW) * 0.5), 9)
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
            ScrollBarImageColor3 = Carbon.hairlineFocus,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ZIndex = 72
        }, Win.content)
        pad(Win.page, 14, 18, 14, 18)
        vlist(Win.page, 12)
        return Win.page
    end

    -- ========================================================================
    -- MATTE CARBON COMPONENT LIBRARY
    -- ========================================================================
    local Components = {}

    function Components.statCard(parent, opts)
        local cardFrame = mk("Frame", {
            Size = opts.size or UDim2.new(0.25, -9, 0, 90),
            BackgroundColor3 = Carbon.surface,
            BorderSizePixel = 0,
            LayoutOrder = opts.order or 1,
            ZIndex = 73
        }, parent)
        corner(cardFrame, 12)
        local st = borderStroke(cardFrame, Carbon.hairline, 0, 1)
        pad(cardFrame, 12, 14, 12, 14)

        attach(cardFrame.MouseEnter, function()
            Motion.spring(cardFrame, {BackgroundColor3 = Carbon.surfaceHover}, 0.12)
            st.Color = Carbon.hairlineFocus
        end, State.tabConns)
        attach(cardFrame.MouseLeave, function()
            Motion.spring(cardFrame, {BackgroundColor3 = Carbon.surface}, 0.14)
            st.Color = Carbon.hairline
        end, State.tabConns)

        label(cardFrame, opts.title, {
            Size = UDim2.new(1, -40, 0, 16),
            Font = FONT_MED,
            TextSize = 11,
            TextColor3 = Carbon.textSecondary,
            ZIndex = 74
        })

        if opts.badgeText then
            local badge = mk("TextLabel", {
                Text = opts.badgeText,
                Position = UDim2.new(1, -34, 0, -1),
                Size = UDim2.fromOffset(34, 18),
                BackgroundColor3 = Carbon.surfaceRecessed,
                TextColor3 = Carbon.textPrimary,
                Font = FONT_BOLD,
                TextSize = 9,
                BorderSizePixel = 0,
                ZIndex = 74
            }, cardFrame)
            corner(badge, 5)
            borderStroke(badge, Carbon.hairline, 0, 1)
        end

        local valLabel = damageNumber(cardFrame, "—", opts.variant or "sv", {
            Position = UDim2.fromOffset(0, 20),
            Size = UDim2.new(1, 0, 0, 28),
            TextSize = 21,
            StrokeThickness = 2.4,
            ZIndex = 74
        })

        if type(opts.numericValue) == "number" then
            local from = opts.prevValue or opts.numericValue
            Motion.animateNumber(valLabel, from, opts.numericValue, formatVal, opts.suffix or "")
        else
            valLabel.Text = tostring(opts.textValue or "—")
        end

        label(cardFrame, opts.subtitle or "", {
            Position = UDim2.fromOffset(0, 50),
            Size = UDim2.new(1, 0, 0, 14),
            Font = FONT_REG,
            TextSize = 10,
            TextColor3 = Carbon.textMuted,
            ZIndex = 74
        })

        return cardFrame
    end

    function Components.panel(parent, title, subtitle, props)
        local p = {
            Size = UDim2.new(1, 0, 0, 200),
            BackgroundColor3 = Carbon.surface,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            ZIndex = 73
        }
        for k, v in pairs(props or {}) do p[k] = v end
        local frame = mk("Frame", p, parent)
        corner(frame, 12)
        borderStroke(frame, Carbon.hairline, 0, 1)

        local header = mk("Frame", {
            Name = "PanelHeader",
            Size = UDim2.new(1, 0, 0, 44),
            BackgroundColor3 = Carbon.surfaceRecessed,
            BorderSizePixel = 0,
            ZIndex = 74
        }, frame)

        label(header, title, {
            Position = UDim2.fromOffset(16, subtitle and 7 or 0),
            Size = UDim2.new(1, -130, 0, subtitle and 17 or 44),
            Font = FONT_BOLD,
            TextSize = 12,
            TextColor3 = Carbon.textPrimary,
            ZIndex = 75
        })

        if subtitle then
            label(header, subtitle, {
                Position = UDim2.fromOffset(16, 24),
                Size = UDim2.new(1, -130, 0, 14),
                Font = FONT_REG,
                TextSize = 10,
                TextColor3 = Carbon.textMuted,
                ZIndex = 75
            })
        end

        mk("Frame", {
            Position = UDim2.new(0, 0, 1, -1),
            Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = Carbon.hairline,
            BorderSizePixel = 0,
            ZIndex = 74
        }, header)

        return frame, header
    end

    function Components.emptyState(parent, title, desc, yOffset)
        local box = mk("Frame", {
            Position = UDim2.new(0.5, -145, 0, yOffset or 46),
            Size = UDim2.fromOffset(290, 66),
            BackgroundTransparency = 1,
            ZIndex = 74
        }, parent)

        label(box, title, {
            Size = UDim2.new(1, 0, 0, 18),
            Font = FONT_BOLD,
            TextSize = 12,
            TextColor3 = Carbon.textPrimary,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 75
        })

        label(box, desc, {
            Position = UDim2.fromOffset(0, 21),
            Size = UDim2.new(1, 0, 0, 34),
            Font = FONT_REG,
            TextSize = 11,
            TextColor3 = Carbon.textMuted,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 75
        })
        return box
    end

    local function specRow(parent, key, value, variant, yPos)
        local row = mk("Frame", {
            Position = UDim2.fromOffset(0, yPos),
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundTransparency = 1,
            ZIndex = 74
        }, parent)

        mk("Frame", {
            Position = UDim2.new(0, 0, 1, -1),
            Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = Carbon.hairline,
            BorderSizePixel = 0,
            ZIndex = 75
        }, row)

        label(row, key, {
            Size = UDim2.new(0.52, 0, 1, 0),
            Font = FONT_MED,
            TextSize = 11,
            TextColor3 = Carbon.textSecondary,
            ZIndex = 75
        })

        if variant then
            damageNumber(row, tostring(value), variant, {
                Position = UDim2.fromScale(0.52, 0),
                Size = UDim2.fromScale(0.48, 1),
                TextSize = 15,
                StrokeThickness = 2,
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 75
            })
        else
            label(row, tostring(value), {
                Position = UDim2.fromScale(0.52, 0),
                Size = UDim2.fromScale(0.48, 1),
                Font = FONT_BOLD,
                TextSize = 11,
                TextColor3 = Carbon.textPrimary,
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 75
            })
        end
        return row
    end

    -- ========================================================================
    -- TAB 1: OVERVIEW DASHBOARD
    -- ========================================================================
    Tabs.Overview = function(page)
        local pStats = Selectors.getPortfolioStats()
        local sightings = Selectors.getServerSightings()
        local favCount, wishCount = Selectors.getWatchlistCount()

        local kpiRow = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 90),
            BackgroundTransparency = 1,
            LayoutOrder = ord(),
            ZIndex = 72
        }, page)
        mk("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 12)
        }, kpiRow)

        local k1 = Components.statCard(kpiRow, {
            order = 1,
            title = "Portfolio (Supreme)",
            badgeText = "SV",
            variant = "sv",
            numericValue = pStats.totalSV,
            prevValue = State.prevKpis.sv,
            suffix = pStats.missingSV > 0 and "+? SV" or " SV",
            subtitle = pStats.totalUnits .. " items  ·  " .. pStats.stackCount .. " stacks"
        })

        local k2 = Components.statCard(kpiRow, {
            order = 2,
            title = "Portfolio (MM2Values)",
            badgeText = "MV",
            variant = "mv",
            numericValue = pStats.totalMV,
            prevValue = State.prevKpis.mv,
            suffix = pStats.missingMV > 0 and "+? MV" or " MV",
            subtitle = "Cross-referenced valuation"
        })

        local k3 = Components.statCard(kpiRow, {
            order = 3,
            title = "Market Database",
            badgeText = Data.loaded and "LIVE" or "SYNC",
            variant = "sv",
            numericValue = #Data.itemsList,
            prevValue = State.prevKpis.db,
            subtitle = "SV " .. Data.supremeStamp .. "  ·  MV " .. Data.mm2Stamp
        })

        local k4 = Components.statCard(kpiRow, {
            order = 4,
            title = "Watchlist & Trades",
            badgeText = "LOG",
            variant = "mv",
            numericValue = #Data.history,
            prevValue = State.prevKpis.trades,
            suffix = " trades",
            subtitle = favCount .. " favorites  ·  " .. wishCount .. " wishlist"
        })

        State.prevKpis.sv = pStats.totalSV
        State.prevKpis.mv = pStats.totalMV
        State.prevKpis.db = #Data.itemsList
        State.prevKpis.trades = #Data.history

        local mainGrid = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 396),
            BackgroundTransparency = 1,
            LayoutOrder = ord(),
            ZIndex = 72
        }, page)

        local tradePanel, tradeHeader = Components.panel(
            mainGrid,
            "Recent Trade Activity",
            "Read-only ledger of completed and closed MM2 trades",
            {Size = UDim2.new(0.62, -7, 1, 0)}
        )

        if #Data.history > 0 then
            button(tradeHeader, "Clear", "ghost", {
                Position = UDim2.new(1, -66, 0, 9),
                Size = UDim2.fromOffset(54, 26),
                TextSize = 11,
                ZIndex = 75
            }, function()
                Data.history = {}
                Store.write(Config.HISTORY_FILE, Data.history)
                UI.selectTab("Overview")
            end, State.tabConns)
        end

        if #Data.history == 0 then
            Components.emptyState(
                tradePanel,
                "No trades recorded yet",
                "Completed MM2 trade sessions will appear here automatically.",
                156
            )
        else
            local maxRows = 8
            for i = 1, math.min(#Data.history, maxRows) do
                local h = Data.history[i]
                local rowY = 50 + (i - 1) * 42
                local tr = mk("Frame", {
                    Position = UDim2.fromOffset(12, rowY),
                    Size = UDim2.new(1, -24, 0, 37),
                    BackgroundColor3 = Carbon.surfaceRecessed,
                    BorderSizePixel = 0,
                    ZIndex = 74
                }, tradePanel)
                corner(tr, 8)
                borderStroke(tr, Carbon.hairline, 0, 1)

                local when = tostring(h.at)
                pcall(function() when = os.date("%H:%M", h.at) end)
                local confirmed = (h.status == "CONFIRMED")

                label(tr, when, {
                    Position = UDim2.fromOffset(12, 0),
                    Size = UDim2.fromOffset(44, 37),
                    Font = FONT_MED,
                    TextSize = 11,
                    TextColor3 = Carbon.textSecondary,
                    ZIndex = 75
                })

                local statusTag = mk("TextLabel", {
                    Text = confirmed and "DONE" or "CLOSED",
                    Position = UDim2.fromOffset(58, 9),
                    Size = UDim2.fromOffset(56, 19),
                    BackgroundColor3 = confirmed and Carbon.pillActive or Carbon.surface,
                    TextColor3 = confirmed and Carbon.pillActiveInk or Carbon.textSecondary,
                    Font = FONT_BOLD,
                    TextSize = 9,
                    BorderSizePixel = 0,
                    ZIndex = 75
                }, tr)
                corner(statusTag, 5)

                label(tr, "Got: " .. tostring(h.get ~= "" and h.get or "—"), {
                    Position = UDim2.fromOffset(122, 4),
                    Size = UDim2.new(1, -218, 0, 15),
                    Font = FONT_BOLD,
                    TextSize = 11,
                    ZIndex = 75
                })

                label(tr, "Gave: " .. tostring(h.give ~= "" and h.give or "—"), {
                    Position = UDim2.fromOffset(122, 19),
                    Size = UDim2.new(1, -218, 0, 14),
                    Font = FONT_REG,
                    TextSize = 10,
                    TextColor3 = Carbon.textMuted,
                    ZIndex = 75
                })

                damageNumber(tr, h.delta and (Util.signed(h.delta) .. " SV") or "—", (h.delta and h.delta < 0) and "mv" or "sv", {
                    Position = UDim2.new(1, -94, 0, 0),
                    Size = UDim2.fromOffset(82, 37),
                    TextSize = 14,
                    StrokeThickness = 1.9,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    ZIndex = 75
                })
            end
        end

        local rightStack = mk("Frame", {
            Position = UDim2.new(0.62, 7, 0, 0),
            Size = UDim2.new(0.38, -7, 1, 0),
            BackgroundTransparency = 1,
            ZIndex = 73
        }, mainGrid)

        local sightPanel = Components.panel(
            rightStack,
            "Server Sightings (" .. #sightings .. ")",
            "Players holding 250+ SV items in this lobby",
            {Size = UDim2.new(1, 0, 0, 226)}
        )

        if #sightings == 0 then
            Components.emptyState(
                sightPanel,
                "No rare items spotted",
                "Equipped weapons worth 250+ SV in this server appear here.",
                86
            )
        else
            for i = 1, math.min(#sightings, 4) do
                local s = sightings[i]
                local sy = 50 + (i - 1) * 41
                local sr = mk("Frame", {
                    Position = UDim2.fromOffset(12, sy),
                    Size = UDim2.new(1, -24, 0, 37),
                    BackgroundColor3 = Carbon.surfaceRecessed,
                    BorderSizePixel = 0,
                    ZIndex = 74
                }, sightPanel)
                corner(sr, 8)
                borderStroke(sr, Carbon.hairline, 0, 1)

                label(sr, tostring(s.name), {
                    Position = UDim2.fromOffset(12, 4),
                    Size = UDim2.new(1, -96, 0, 15),
                    Font = FONT_BOLD,
                    TextSize = 11,
                    ZIndex = 75
                })
                label(sr, tostring(s.player) .. " · " .. Util.ago(s.at), {
                    Position = UDim2.fromOffset(12, 19),
                    Size = UDim2.new(1, -96, 0, 14),
                    Font = FONT_REG,
                    TextSize = 10,
                    TextColor3 = Carbon.textMuted,
                    ZIndex = 75
                })
                damageNumber(sr, formatVal(s.value) .. " SV", "sv", {
                    Position = UDim2.new(1, -86, 0, 0),
                    Size = UDim2.fromOffset(76, 37),
                    TextSize = 13,
                    StrokeThickness = 1.8,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    ZIndex = 75
                })
            end
        end

        local feedPanel = Components.panel(
            rightStack,
            "Market Feed Sources",
            "Live Supreme CSV & MM2Values JSON sync",
            {Position = UDim2.fromOffset(0, 238), Size = UDim2.new(1, 0, 0, 158)}
        )

        local feedBody = mk("Frame", {
            Position = UDim2.fromOffset(16, 52),
            Size = UDim2.new(1, -32, 0, 96),
            BackgroundTransparency = 1,
            ZIndex = 74
        }, feedPanel)

        label(feedBody, "Supreme: " .. Data.supremeStamp .. "   ·   MM2Values: " .. Data.mm2Stamp, {
            Size = UDim2.new(1, 0, 0, 16),
            Font = FONT_BOLD,
            TextSize = 11,
            TextColor3 = Carbon.textPrimary,
            ZIndex = 75
        })

        local syncLine = Data.lastError and ("Notice: " .. tostring(Data.lastError))
            or (Data.lastFetchAt > 0 and ("Synced " .. Util.ago(Data.lastFetchAt) .. " · Auto-refresh active") or "Initializing dataset...")
        label(feedBody, syncLine, {
            Position = UDim2.fromOffset(0, 20),
            Size = UDim2.new(1, 0, 0, 16),
            Font = FONT_REG,
            TextSize = 10,
            TextColor3 = Data.lastError and Carbon.textPrimary or Carbon.textMuted,
            ZIndex = 75
        })

        button(feedBody, "Sync Now", "primary", {
            Position = UDim2.fromOffset(0, 48),
            Size = UDim2.fromOffset(88, 30),
            TextSize = 11,
            ZIndex = 75
        }, function()
            notify("Syncing", "Refreshing Supreme & MM2Values...", Carbon.textPrimary)
            task.spawn(function()
                pcall(Net.loadPrices)
                Data.loading = false
            end)
        end, State.tabConns)

        button(feedBody, "Supreme Web", "default", {
            Position = UDim2.fromOffset(96, 48),
            Size = UDim2.fromOffset(102, 30),
            TextSize = 11,
            ZIndex = 75
        }, function()
            openLink(Config.OFFICIAL_SITE, "Supreme Values")
        end, State.tabConns)

        button(feedBody, "Copy URL", "default", {
            Position = UDim2.fromOffset(206, 48),
            Size = UDim2.fromOffset(78, 30),
            TextSize = 11,
            ZIndex = 75
        }, function()
            copyOrNotify(Config.OFFICIAL_SITE, "Supreme URL copied")
        end, State.tabConns)

        Motion.staggerIn({k1, k2, k3, k4, tradePanel, sightPanel, feedPanel}, 0.03)
        Win.refresh = function() UI.selectTab("Overview") end
    end

    -- ========================================================================
    -- TAB 2: MARKET INDEX
    -- ========================================================================
    Tabs.Values = function(page)
        local render

        local toolbar = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundTransparency = 1,
            LayoutOrder = ord(),
            ZIndex = 73
        }, page)

        local searchBox = inputBox(toolbar, "Search MM2 items (e.g. Harvester, Chroma Luger)...", State.valueSearch, {
            Size = UDim2.fromOffset(280, 32),
            ZIndex = 74
        })

        local filterSetters = {}
        local filterX = 288
        for _, f in ipairs({
            {id = "All", label = "All", w = 44},
            {id = "Favs", label = "Favorites", w = 72},
            {id = "Wish", label = "Wishlist", w = 66},
            {id = "High", label = "500+ SV", w = 64},
            {id = "Chroma", label = "Chroma", w = 64}
        }) do
            local b = mk("TextButton", {
                Text = f.label,
                Position = UDim2.fromOffset(filterX, 1),
                Size = UDim2.fromOffset(f.w, 30),
                BackgroundColor3 = Carbon.surface,
                TextColor3 = Carbon.textSecondary,
                Font = FONT_BOLD,
                TextSize = 10,
                AutoButtonColor = false,
                BorderSizePixel = 0,
                ZIndex = 74
            }, toolbar)
            corner(b, 8)
            local st = borderStroke(b, Carbon.hairline, 0, 1)

            filterSetters[f.id] = function(active)
                b.BackgroundColor3 = active and Carbon.pillActive or Carbon.surface
                b.TextColor3 = active and Carbon.pillActiveInk or Carbon.textSecondary
                st.Color = active and Carbon.pillActive or Carbon.hairline
            end

            attach(b.MouseButton1Click, function()
                State.valueFilter = f.id
                State.valuePage = 1
                for id, fn in pairs(filterSetters) do fn(id == f.id) end
                render()
            end, State.tabConns)

            filterX = filterX + f.w + 5
        end
        if not filterSetters[State.valueFilter] then State.valueFilter = "All" end
        filterSetters[State.valueFilter](true)

        local sortCycle = {
            {id = "SV_DESC", label = "Sort: SV ↓"},
            {id = "SV_ASC",  label = "Sort: SV ↑"},
            {id = "MV_DESC", label = "Sort: MV ↓"},
            {id = "DEM_DESC",label = "Sort: Demand"},
            {id = "NAME_ASC",label = "Sort: A–Z"}
        }
        local function getSortLabel()
            for _, s in ipairs(sortCycle) do
                if s.id == State.valueSort then return s.label end
            end
            return "Sort: SV ↓"
        end

        button(toolbar, getSortLabel(), "default", {
            Position = UDim2.new(1, -104, 0, 1),
            Size = UDim2.fromOffset(104, 30),
            TextSize = 10,
            ZIndex = 74
        }, function(btn)
            local nextIdx = 1
            for i, s in ipairs(sortCycle) do
                if s.id == State.valueSort then
                    nextIdx = (i % #sortCycle) + 1
                    break
                end
            end
            State.valueSort = sortCycle[nextIdx].id
            State.valuePage = 1
            btn.Text = sortCycle[nextIdx].label
            render()
        end, State.tabConns)

        local PER_PAGE = 10
        local ROW_H = 35
        local HEAD_H = 32
        local FOOT_H = 40
        local tableHeight = HEAD_H + (PER_PAGE * ROW_H) + FOOT_H

        local tableCard = mk("Frame", {
            Size = UDim2.new(1, 0, 0, tableHeight),
            BackgroundColor3 = Carbon.surface,
            BorderSizePixel = 0,
            LayoutOrder = ord(),
            ClipsDescendants = true,
            ZIndex = 73
        }, page)
        corner(tableCard, 12)
        borderStroke(tableCard, Carbon.hairline, 0, 1)

        local thead = mk("Frame", {
            Size = UDim2.new(1, 0, 0, HEAD_H),
            BackgroundColor3 = Carbon.surfaceRecessed,
            BorderSizePixel = 0,
            ZIndex = 74
        }, tableCard)
        mk("Frame", {
            Position = UDim2.new(0, 0, 1, -1),
            Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = Carbon.hairline,
            BorderSizePixel = 0,
            ZIndex = 75
        }, thead)

        label(thead, "ITEM NAME", {Position = UDim2.fromOffset(16, 0), Size = UDim2.new(0.36, -16, 1, 0), Font = FONT_BOLD, TextSize = 10, TextColor3 = Carbon.textMuted, ZIndex = 75})
        label(thead, "CATEGORY", {Position = UDim2.fromScale(0.36, 0), Size = UDim2.fromScale(0.15, 1), Font = FONT_BOLD, TextSize = 10, TextColor3 = Carbon.textMuted, ZIndex = 75})
        label(thead, "SUPREME (SV)", {Position = UDim2.fromScale(0.51, 0), Size = UDim2.fromScale(0.13, 1), Font = FONT_BOLD, TextSize = 10, TextColor3 = Carbon.textPrimary, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 75})
        label(thead, "MM2VALUES (MV)", {Position = UDim2.fromScale(0.64, 0), Size = UDim2.fromScale(0.13, 1), Font = FONT_BOLD, TextSize = 10, TextColor3 = Carbon.textSecondary, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 75})
        label(thead, "DEMAND", {Position = UDim2.fromScale(0.77, 0), Size = UDim2.fromScale(0.09, 1), Font = FONT_BOLD, TextSize = 10, TextColor3 = Carbon.textMuted, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 75})
        label(thead, "ACTIONS", {Position = UDim2.new(1, -110, 0, 0), Size = UDim2.fromOffset(94, HEAD_H), Font = FONT_BOLD, TextSize = 10, TextColor3 = Carbon.textMuted, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 75})

        local tbody = mk("Frame", {
            Position = UDim2.fromOffset(0, HEAD_H),
            Size = UDim2.new(1, 0, 0, PER_PAGE * ROW_H),
            BackgroundTransparency = 1,
            ZIndex = 74
        }, tableCard)

        local tfoot = mk("Frame", {
            Position = UDim2.new(0, 0, 1, -FOOT_H),
            Size = UDim2.new(1, 0, 0, FOOT_H),
            BackgroundColor3 = Carbon.surfaceRecessed,
            BorderSizePixel = 0,
            ZIndex = 74
        }, tableCard)
        mk("Frame", {
            Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = Carbon.hairline,
            BorderSizePixel = 0,
            ZIndex = 75
        }, tfoot)

        local countLbl = label(tfoot, "Syncing market index...", {
            Position = UDim2.fromOffset(16, 0),
            Size = UDim2.fromOffset(260, FOOT_H),
            Font = FONT_MED,
            TextSize = 11,
            TextColor3 = Carbon.textSecondary,
            ZIndex = 75
        })

        button(tfoot, "Prev", "default", {
            Position = UDim2.new(1, -210, 0, 6),
            Size = UDim2.fromOffset(62, 28),
            TextSize = 11,
            ZIndex = 75
        }, function()
            State.valuePage = math.max(1, State.valuePage - 1)
            render()
        end, State.tabConns)

        local pageLbl = damageNumber(tfoot, "1 / 1", "sv", {
            Position = UDim2.new(1, -144, 0, 0),
            Size = UDim2.fromOffset(74, FOOT_H),
            TextSize = 13,
            StrokeThickness = 1.8,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 75
        })

        button(tfoot, "Next", "default", {
            Position = UDim2.new(1, -66, 0, 6),
            Size = UDim2.fromOffset(52, 28),
            TextSize = 11,
            ZIndex = 75
        }, function()
            State.valuePage = State.valuePage + 1
            render()
        end, State.tabConns)

        local function renderRow(row, idx)
            local y = (idx - 1) * ROW_H
            local tierCol = getTierAccent(row)
            local tr = mk("Frame", {
                Position = UDim2.fromOffset(0, y),
                Size = UDim2.new(1, 0, 0, ROW_H),
                BackgroundColor3 = Carbon.surface,
                BorderSizePixel = 0,
                ZIndex = 74
            }, tbody)

            mk("Frame", {
                Size = UDim2.new(0, 3, 1, 0),
                BackgroundColor3 = tierCol,
                BorderSizePixel = 0,
                ZIndex = 75
            }, tr)

            mk("Frame", {
                Position = UDim2.new(0, 0, 1, -1),
                Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = Carbon.hairline,
                BorderSizePixel = 0,
                ZIndex = 75
            }, tr)

            attach(tr.MouseEnter, function() tr.BackgroundColor3 = Carbon.surfaceHover end, State.tabConns)
            attach(tr.MouseLeave, function() tr.BackgroundColor3 = Carbon.surface end, State.tabConns)

            label(tr, row.name, {
                Position = UDim2.fromOffset(16, 0),
                Size = UDim2.new(0.36, -22, 1, 0),
                Font = FONT_BOLD,
                TextSize = 12,
                TextColor3 = Carbon.textPrimary,
                ZIndex = 75
            })

            label(tr, (row.category and row.category ~= "") and row.category or "Weapon", {
                Position = UDim2.fromScale(0.36, 0),
                Size = UDim2.fromScale(0.15, 1),
                Font = FONT_MED,
                TextSize = 11,
                TextColor3 = Carbon.textSecondary,
                ZIndex = 75
            })

            damageNumber(tr, formatVal(row.supreme), "sv", {
                Position = UDim2.fromScale(0.51, 0),
                Size = UDim2.fromScale(0.13, 1),
                TextSize = 14,
                StrokeThickness = 1.9,
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 75
            })

            damageNumber(tr, formatVal(safeMM2(row)), "mv", {
                Position = UDim2.fromScale(0.64, 0),
                Size = UDim2.fromScale(0.13, 1),
                TextSize = 14,
                StrokeThickness = 1.9,
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 75
            })

            label(tr, row.demand and (formatVal(row.demand) .. " / 10") or "—", {
                Position = UDim2.fromScale(0.77, 0),
                Size = UDim2.fromScale(0.09, 1),
                Font = FONT_MED,
                TextSize = 11,
                TextColor3 = Carbon.textSecondary,
                TextXAlignment = Enum.TextXAlignment.Center,
                ZIndex = 75
            })

            local isFav = (Prefs.favs[row.name] == true)
            local isWish = (Prefs.wishlist[row.name] == true)

            local favBtn = mk("TextButton", {
                Text = "★",
                Position = UDim2.new(1, -102, 0, 5),
                Size = UDim2.fromOffset(26, 24),
                BackgroundColor3 = isFav and Carbon.pillActive or Carbon.surfaceRecessed,
                TextColor3 = isFav and Carbon.pillActiveInk or Carbon.textMuted,
                Font = FONT_BOLD,
                TextSize = 11,
                AutoButtonColor = false,
                BorderSizePixel = 0,
                ZIndex = 75
            }, tr)
            corner(favBtn, 6)
            attach(favBtn.MouseButton1Click, function()
                Prefs.favs[row.name] = not (Prefs.favs[row.name] == true) or nil
                Store.savePrefs()
                render()
            end, State.tabConns)

            local wishBtn = mk("TextButton", {
                Text = "+",
                Position = UDim2.new(1, -72, 0, 5),
                Size = UDim2.fromOffset(26, 24),
                BackgroundColor3 = isWish and Carbon.pillActive or Carbon.surfaceRecessed,
                TextColor3 = isWish and Carbon.pillActiveInk or Carbon.textMuted,
                Font = FONT_BOLD,
                TextSize = 12,
                AutoButtonColor = false,
                BorderSizePixel = 0,
                ZIndex = 75
            }, tr)
            corner(wishBtn, 6)
            attach(wishBtn.MouseButton1Click, function()
                Prefs.wishlist[row.name] = not (Prefs.wishlist[row.name] == true) or nil
                Store.savePrefs()
                render()
            end, State.tabConns)

            local cmpBtn = mk("TextButton", {
                Text = "⇄",
                Position = UDim2.new(1, -42, 0, 5),
                Size = UDim2.fromOffset(26, 24),
                BackgroundColor3 = Carbon.surfaceRecessed,
                TextColor3 = Carbon.textSecondary,
                Font = FONT_BOLD,
                TextSize = 11,
                AutoButtonColor = false,
                BorderSizePixel = 0,
                ZIndex = 75
            }, tr)
            corner(cmpBtn, 6)
            attach(cmpBtn.MouseButton1Click, function()
                State.compareB = State.compareA
                State.compareA = row.name
                notify("Added to Compare", row.name .. " loaded into Slot A", Carbon.textPrimary)
            end, State.tabConns)
        end

        render = function()
            clearChildren(tbody)
            if not Data.loaded then
                Components.emptyState(tbody, "Synchronizing market data", "Loading Supreme Values and MM2Values datasets...", 130)
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
                if match and State.valueFilter == "Favs" then match = (Prefs.favs[row.name] == true) end
                if match and State.valueFilter == "Wish" then match = (Prefs.wishlist[row.name] == true) end
                if match and State.valueFilter == "High" then match = ((row.supreme or 0) >= 500) end
                if match and State.valueFilter == "Chroma" then
                    match = tostring(row.name):lower():find("chroma", 1, true) ~= nil
                end
                if match then
                    filtered[#filtered + 1] = row
                end
            end

            table.sort(filtered, function(a, b)
                if State.valueSort == "SV_ASC" then
                    local va, vb = a.supreme or 999999999, b.supreme or 999999999
                    if va ~= vb then return va < vb end
                elseif State.valueSort == "MV_DESC" then
                    local va, vb = safeMM2(a) or -1, safeMM2(b) or -1
                    if va ~= vb then return va > vb end
                elseif State.valueSort == "DEM_DESC" then
                    local va, vb = a.demand or -1, b.demand or -1
                    if va ~= vb then return va > vb end
                elseif State.valueSort == "NAME_ASC" then
                    return tostring(a.name) < tostring(b.name)
                else
                    local va, vb = a.supreme or a.mm2 or -1, b.supreme or b.mm2 or -1
                    if va ~= vb then return va > vb end
                end
                return tostring(a.name) < tostring(b.name)
            end)

            local total = #filtered
            local pages = math.max(1, math.ceil(total / PER_PAGE))
            State.valuePage = math.max(1, math.min(State.valuePage, pages))
            pageLbl.Text = State.valuePage .. " / " .. pages

            if total == 0 then
                countLbl.Text = "0 items matched"
                Components.emptyState(tbody, "No matching items", "Try adjusting your search query or clearing active filters.", 130)
                return
            end

            local startIdx = (State.valuePage - 1) * PER_PAGE + 1
            local endIdx = math.min(total, State.valuePage * PER_PAGE)
            countLbl.Text = "Showing " .. startIdx .. "–" .. endIdx .. " of " .. total .. " items"

            for i = startIdx, endIdx do
                renderRow(filtered[i], i - startIdx + 1)
            end
        end

        local token = 0
        attach(searchBox:GetPropertyChangedSignal("Text"), function()
            State.valueSearch = searchBox.Text
            State.valuePage = 1
            token = token + 1
            local mine = token
            task.delay(0.18, function()
                if State.alive and token == mine and searchBox.Parent then pcall(render) end
            end)
        end, State.tabConns)

        Motion.staggerIn({toolbar, tableCard}, 0.04)
        Win.refresh = render
        render()
    end

    -- ========================================================================
    -- TAB 3: COMPARE ITEMS
    -- ========================================================================
    Tabs.Compare = function(page)
        local update

        local selectorBar = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundTransparency = 1,
            LayoutOrder = ord(),
            ZIndex = 73
        }, page)

        local boxA = inputBox(selectorBar, "Primary item (e.g. Harvester)...", State.compareA, {
            Size = UDim2.new(0.5, -24, 0, 34),
            ZIndex = 74
        })

        button(selectorBar, "⇄", "default", {
            Position = UDim2.new(0.5, -17, 0, 0),
            Size = UDim2.fromOffset(34, 34),
            TextSize = 14,
            ZIndex = 74
        }, function()
            State.compareA, State.compareB = State.compareB, State.compareA
            boxA.Text = State.compareA
            boxB.Text = State.compareB
            update()
        end, State.tabConns)

        local boxB = inputBox(selectorBar, "Comparison item (e.g. Elderwood Scythe)...", State.compareB, {
            Position = UDim2.new(0.5, 24, 0, 0),
            Size = UDim2.new(0.5, -24, 0, 34),
            ZIndex = 74
        })

        local cardsGrid = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 276),
            BackgroundTransparency = 1,
            LayoutOrder = ord(),
            ZIndex = 72
        }, page)

        local panelA, headerA = Components.panel(cardsGrid, "Item A", "Primary evaluation target", {
            Size = UDim2.new(0.5, -6, 1, 0)
        })
        local bodyA = mk("Frame", {
            Position = UDim2.fromOffset(16, 50),
            Size = UDim2.new(1, -32, 1, -58),
            BackgroundTransparency = 1,
            ZIndex = 74
        }, panelA)

        local panelB, headerB = Components.panel(cardsGrid, "Item B", "Benchmark comparison target", {
            Position = UDim2.new(0.5, 6, 0, 0),
            Size = UDim2.new(0.5, -6, 1, 0)
        })
        local bodyB = mk("Frame", {
            Position = UDim2.fromOffset(16, 50),
            Size = UDim2.new(1, -32, 1, -58),
            BackgroundTransparency = 1,
            ZIndex = 74
        }, panelB)

        local summaryPanel = Components.panel(page, "Differential Analysis", "Value spread and ratio between Item A and Item B", {
            Size = UDim2.new(1, 0, 0, 118),
            LayoutOrder = ord()
        })
        local summaryBody = mk("Frame", {
            Position = UDim2.fromOffset(16, 50),
            Size = UDim2.new(1, -32, 0, 60),
            BackgroundTransparency = 1,
            ZIndex = 74
        }, summaryPanel)

        local function populateItem(headerObj, bodyObj, queryText)
            clearChildren(bodyObj)
            local titleLbl = headerObj:FindFirstChildOfClass("TextLabel")
            local row = Util.resolve(queryText)
            if not row then
                if titleLbl then titleLbl.Text = "Unresolved Item" end
                Components.emptyState(
                    bodyObj,
                    Data.loaded and "Item not found" or "Syncing...",
                    "Enter a valid MM2 weapon or pet name above.",
                    62
                )
                return nil
            end

            if titleLbl then titleLbl.Text = row.name end

            specRow(bodyObj, "Supreme Value (SV)", formatVal(row.supreme) .. " SV", "sv", 0)
            specRow(bodyObj, "MM2Values (MV)", formatVal(safeMM2(row)) .. " MV", "mv", 30)
            specRow(bodyObj, "Category", (row.category and row.category ~= "") and row.category or "Item", nil, 60)
            specRow(bodyObj, "Demand Rating", row.demand and (formatVal(row.demand) .. " / 10") or "—", nil, 90)
            specRow(bodyObj, "Rarity Tier", row.rarity and (formatVal(row.rarity) .. " / 10") or "—", nil, 120)
            specRow(bodyObj, "Recent Change", row.change and Util.signed(row.change) or "—", "sv", 150)
            specRow(bodyObj, "Stability", (row.stability and row.stability ~= "") and row.stability or "—", nil, 180)
            return row
        end

        update = function()
            local a = populateItem(headerA, bodyA, State.compareA)
            local b = populateItem(headerB, bodyB, State.compareB)
            clearChildren(summaryBody)

            if a and b and a.supreme and b.supreme and a.supreme > 0 and b.supreme > 0 then
                local diffSV = a.supreme - b.supreme
                local ratio = a.supreme / b.supreme
                local pct = ((a.supreme - b.supreme) / b.supreme) * 100

                specRow(
                    summaryBody,
                    "Net Spread (" .. a.name .. " vs " .. b.name .. ")",
                    Util.signed(diffSV) .. " SV  (" .. string.format("%+.1f%%", pct) .. ")",
                    "sv",
                    0
                )
                specRow(
                    summaryBody,
                    "Multiplier Ratio",
                    string.format("%.2fx", ratio),
                    "mv",
                    30
                )
            else
                label(summaryBody, "Select two priced items above to compute value spread and ratio.", {
                    Size = UDim2.new(1, 0, 0, 24),
                    Font = FONT_REG,
                    TextSize = 12,
                    TextColor3 = Carbon.textMuted,
                    ZIndex = 75
                })
            end
        end

        local token = 0
        local function watchInput(box, field)
            attach(box:GetPropertyChangedSignal("Text"), function()
                State[field] = box.Text
                token = token + 1
                local mine = token
                task.delay(0.22, function()
                    if State.alive and token == mine and box.Parent then pcall(update) end
                end)
            end, State.tabConns)
        end
        watchInput(boxA, "compareA")
        watchInput(boxB, "compareB")

        Motion.staggerIn({selectorBar, panelA, panelB, summaryPanel}, 0.04)
        Win.refresh = update
        update()
    end

    -- ========================================================================
    -- TAB 4: PORTFOLIO
    -- ========================================================================
    Tabs.Inventory = function(page)
        local kpiRow = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 90),
            BackgroundTransparency = 1,
            LayoutOrder = ord(),
            ZIndex = 72
        }, page)
        mk("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 12)
        }, kpiRow)

        local actionBar = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundTransparency = 1,
            LayoutOrder = ord(),
            ZIndex = 73
        }, page)

        local nameBox = inputBox(actionBar, "Add item to portfolio (e.g. Corrupt, Gingerscope)...", State.invQuery, {
            Size = UDim2.fromOffset(290, 32),
            ZIndex = 74
        })
        local qtyBox = inputBox(actionBar, "Qty", State.invQty, {
            Position = UDim2.fromOffset(298, 0),
            Size = UDim2.fromOffset(58, 32),
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 74
        })

        local render

        button(actionBar, "+ Add", "primary", {
            Position = UDim2.fromOffset(364, 0),
            Size = UDim2.fromOffset(78, 32),
            TextSize = 11,
            ZIndex = 75
        }, function()
            local row = Util.resolve(State.invQuery)
            if not row then
                notify("Item not found", "Enter a valid MM2 item name", Carbon.textSecondary)
                return
            end
            local qty = math.max(1, math.min(9999, math.floor(tonumber(State.invQty) or 1)))
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
                    notify("Portfolio full", "Maximum 60 unique stacks supported", Carbon.textSecondary)
                    return
                end
                Prefs.myItems[#Prefs.myItems + 1] = {name = row.name, qty = qty}
            end
            Store.savePrefs()
            nameBox.Text = ""
            State.invQuery = ""
            notify("Portfolio updated", row.name .. " (×" .. qty .. ") added", Carbon.textPrimary)
            render()
        end, State.tabConns)

        local filterBox = inputBox(actionBar, "Filter...", State.invFilter, {
            Position = UDim2.new(1, -170, 0, 0),
            Size = UDim2.fromOffset(170, 32),
            ZIndex = 74
        })

        attach(nameBox:GetPropertyChangedSignal("Text"), function() State.invQuery = nameBox.Text end, State.tabConns)
        attach(qtyBox:GetPropertyChangedSignal("Text"), function() State.invQty = qtyBox.Text end, State.tabConns)
        attach(filterBox:GetPropertyChangedSignal("Text"), function()
            State.invFilter = filterBox.Text
            render()
        end, State.tabConns)

        local holdingsCard = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 176),
            BackgroundColor3 = Carbon.surface,
            BorderSizePixel = 0,
            LayoutOrder = ord(),
            ClipsDescendants = true,
            ZIndex = 73
        }, page)
        corner(holdingsCard, 12)
        borderStroke(holdingsCard, Carbon.hairline, 0, 1)

        render = function()
            clearChildren(kpiRow)
            clearChildren(holdingsCard)

            local stats = Selectors.getPortfolioStats()

            Components.statCard(kpiRow, {
                order = 1,
                size = UDim2.new(0.333, -8, 1, 0),
                title = "Total Supreme Valuation",
                badgeText = "SV",
                variant = "sv",
                numericValue = stats.totalSV,
                suffix = stats.missingSV > 0 and "+? SV" or " SV",
                subtitle = "Primary market value"
            })

            Components.statCard(kpiRow, {
                order = 2,
                size = UDim2.new(0.333, -8, 1, 0),
                title = "Total MM2Values Valuation",
                badgeText = "MV",
                variant = "mv",
                numericValue = stats.totalMV,
                suffix = stats.missingMV > 0 and "+? MV" or " MV",
                subtitle = "Secondary archive valuation"
            })

            Components.statCard(kpiRow, {
                order = 3,
                size = UDim2.new(0.333, -8, 1, 0),
                title = "Tracked Holdings",
                badgeText = "QTY",
                variant = "sv",
                numericValue = stats.totalUnits,
                suffix = " items",
                subtitle = stats.stackCount .. " unique stacks"
            })

            if #stats.rows == 0 then
                holdingsCard.Size = UDim2.new(1, 0, 0, 176)
                Components.emptyState(
                    holdingsCard,
                    "Your portfolio is empty",
                    "Add items above to calculate your total combined MM2 inventory value.",
                    52
                )
                return
            end

            local q = normalize(State.invFilter)
            local visibleRows = {}
            for _, r in ipairs(stats.rows) do
                if q == "" or normalize(r.name):find(q, 1, true) then
                    visibleRows[#visibleRows + 1] = r
                end
            end

            local HEAD_H = 32
            local ROW_H = 38
            local thead = mk("Frame", {
                Size = UDim2.new(1, 0, 0, HEAD_H),
                BackgroundColor3 = Carbon.surfaceRecessed,
                BorderSizePixel = 0,
                ZIndex = 74
            }, holdingsCard)
            mk("Frame", {
                Position = UDim2.new(0, 0, 1, -1),
                Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = Carbon.hairline,
                BorderSizePixel = 0,
                ZIndex = 75
            }, thead)

            label(thead, "ITEM", {Position = UDim2.fromOffset(16, 0), Size = UDim2.new(0.34, -16, 1, 0), Font = FONT_BOLD, TextSize = 10, TextColor3 = Carbon.textMuted, ZIndex = 75})
            label(thead, "QUANTITY", {Position = UDim2.fromScale(0.34, 0), Size = UDim2.fromScale(0.18, 1), Font = FONT_BOLD, TextSize = 10, TextColor3 = Carbon.textMuted, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 75})
            label(thead, "SUBTOTAL (SV)", {Position = UDim2.fromScale(0.52, 0), Size = UDim2.fromScale(0.18, 1), Font = FONT_BOLD, TextSize = 10, TextColor3 = Carbon.textPrimary, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 75})
            label(thead, "SUBTOTAL (MV)", {Position = UDim2.fromScale(0.70, 0), Size = UDim2.fromScale(0.16, 1), Font = FONT_BOLD, TextSize = 10, TextColor3 = Carbon.textSecondary, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 75})
            label(thead, "ACTION", {Position = UDim2.new(1, -76, 0, 0), Size = UDim2.fromOffset(60, HEAD_H), Font = FONT_BOLD, TextSize = 10, TextColor3 = Carbon.textMuted, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 75})

            if #visibleRows == 0 then
                holdingsCard.Size = UDim2.new(1, 0, 0, 176)
                Components.emptyState(holdingsCard, "No matching items", "Clear the portfolio filter to view all items.", 58)
                return
            end

            for i, item in ipairs(visibleRows) do
                local y = HEAD_H + (i - 1) * ROW_H
                local tr = mk("Frame", {
                    Position = UDim2.fromOffset(0, y),
                    Size = UDim2.new(1, 0, 0, ROW_H),
                    BackgroundColor3 = Carbon.surface,
                    BorderSizePixel = 0,
                    ZIndex = 74
                }, holdingsCard)

                mk("Frame", {
                    Size = UDim2.new(0, 3, 1, 0),
                    BackgroundColor3 = item.tierColor,
                    BorderSizePixel = 0,
                    ZIndex = 75
                }, tr)

                mk("Frame", {
                    Position = UDim2.new(0, 0, 1, -1),
                    Size = UDim2.new(1, 0, 0, 1),
                    BackgroundColor3 = Carbon.hairline,
                    BorderSizePixel = 0,
                    ZIndex = 75
                }, tr)

                label(tr, item.name, {
                    Position = UDim2.fromOffset(16, 0),
                    Size = UDim2.new(0.34, -20, 1, 0),
                    Font = FONT_BOLD,
                    TextSize = 12,
                    ZIndex = 75
                })

                local qtyWrap = mk("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.fromScale(0.43, 0.5),
                    Size = UDim2.fromOffset(92, 24),
                    BackgroundTransparency = 1,
                    ZIndex = 75
                }, tr)

                button(qtyWrap, "–", "default", {
                    Size = UDim2.fromOffset(24, 24),
                    TextSize = 12,
                    ZIndex = 76
                }, function()
                    local entry = Prefs.myItems[item.index]
                    if not entry then return end
                    if (tonumber(entry.qty) or 1) > 1 then
                        entry.qty = entry.qty - 1
                    else
                        table.remove(Prefs.myItems, item.index)
                    end
                    Store.savePrefs()
                    render()
                end, State.tabConns)

                damageNumber(qtyWrap, tostring(item.qty), "sv", {
                    Position = UDim2.fromOffset(26, 0),
                    Size = UDim2.fromOffset(40, 24),
                    TextSize = 14,
                    StrokeThickness = 1.8,
                    TextXAlignment = Enum.TextXAlignment.Center,
                    ZIndex = 76
                })

                button(qtyWrap, "+", "default", {
                    Position = UDim2.fromOffset(68, 0),
                    Size = UDim2.fromOffset(24, 24),
                    TextSize = 12,
                    ZIndex = 76
                }, function()
                    local entry = Prefs.myItems[item.index]
                    if not entry then return end
                    entry.qty = math.min(9999, (tonumber(entry.qty) or 1) + 1)
                    Store.savePrefs()
                    render()
                end, State.tabConns)

                damageNumber(tr, item.subtotalSV and (formatVal(item.subtotalSV) .. " SV") or "—", "sv", {
                    Position = UDim2.fromScale(0.52, 0),
                    Size = UDim2.fromScale(0.18, 1),
                    TextSize = 14,
                    StrokeThickness = 1.8,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    ZIndex = 75
                })

                damageNumber(tr, item.subtotalMV and (formatVal(item.subtotalMV) .. " MV") or "—", "mv", {
                    Position = UDim2.fromScale(0.70, 0),
                    Size = UDim2.fromScale(0.16, 1),
                    TextSize = 14,
                    StrokeThickness = 1.8,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    ZIndex = 75
                })

                button(tr, "Remove", "ghost", {
                    Position = UDim2.new(1, -72, 0, 6),
                    Size = UDim2.fromOffset(56, 26),
                    TextSize = 11,
                    ZIndex = 75
                }, function()
                    table.remove(Prefs.myItems, item.index)
                    Store.savePrefs()
                    render()
                end, State.tabConns)
            end

            holdingsCard.Size = UDim2.new(1, 0, 0, HEAD_H + (#visibleRows * ROW_H))
        end

        Motion.staggerIn({kpiRow, actionBar, holdingsCard}, 0.04)
        Win.refresh = render
        render()
    end

    -- ========================================================================
    -- TAB 5: TRADE SERVERS
    -- ========================================================================
    Tabs.Servers = function(page)
        local render

        local toolbar = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundTransparency = 1,
            LayoutOrder = ord(),
            ZIndex = 73
        }, page)

        local setters = {}
        local chipX = 0
        for _, cat in ipairs({
            {id = "ANY",  label = "Any Ages",        w = 82},
            {id = "AGE",  label = "15–18+ Verified", w = 112},
            {id = "HIGH", label = "High Tier",       w = 82},
            {id = "ALL",  label = "All Servers",     w = 86}
        }) do
            local b = mk("TextButton", {
                Text = cat.label,
                Position = UDim2.fromOffset(chipX, 1),
                Size = UDim2.fromOffset(cat.w, 30),
                BackgroundColor3 = Carbon.surface,
                TextColor3 = Carbon.textSecondary,
                Font = FONT_BOLD,
                TextSize = 11,
                AutoButtonColor = false,
                BorderSizePixel = 0,
                ZIndex = 74
            }, toolbar)
            corner(b, 8)
            local st = borderStroke(b, Carbon.hairline, 0, 1)

            setters[cat.id] = function(active)
                b.BackgroundColor3 = active and Carbon.pillActive or Carbon.surface
                b.TextColor3 = active and Carbon.pillActiveInk or Carbon.textSecondary
                st.Color = active and Carbon.pillActive or Carbon.hairline
            end

            attach(b.MouseButton1Click, function()
                State.serverCategory = cat.id
                State.serverPage = 1
                for id, fn in pairs(setters) do fn(id == cat.id) end
                render()
            end, State.tabConns)

            chipX = chipX + cat.w + 8
        end
        if not setters[State.serverCategory] then State.serverCategory = "ANY" end
        setters[State.serverCategory](true)

        local grid = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 320),
            BackgroundTransparency = 1,
            LayoutOrder = ord(),
            ZIndex = 72
        }, page)

        local footerBar = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundTransparency = 1,
            LayoutOrder = ord(),
            ZIndex = 73
        }, page)

        label(footerBar, "Private trading lobbies open externally in your browser or Roblox client.", {
            Size = UDim2.new(1, -220, 1, 0),
            Font = FONT_REG,
            TextSize = 11,
            TextColor3 = Carbon.textMuted,
            ZIndex = 74
        })

        button(footerBar, "Prev", "default", {
            Position = UDim2.new(1, -206, 0, 2),
            Size = UDim2.fromOffset(64, 28),
            TextSize = 11,
            ZIndex = 75
        }, function()
            State.serverPage = math.max(1, State.serverPage - 1)
            render()
        end, State.tabConns)

        local pageLbl = damageNumber(footerBar, "1 / 1", "sv", {
            Position = UDim2.new(1, -138, 0, 0),
            Size = UDim2.fromOffset(72, 32),
            TextSize = 13,
            StrokeThickness = 1.8,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 74
        })

        button(footerBar, "Next", "default", {
            Position = UDim2.new(1, -62, 0, 2),
            Size = UDim2.fromOffset(62, 28),
            TextSize = 11,
            ZIndex = 75
        }, function()
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

            local PER_PAGE = 10
            local pages = math.max(1, math.ceil(#items / PER_PAGE))
            State.serverPage = math.max(1, math.min(State.serverPage, pages))
            pageLbl.Text = State.serverPage .. " / " .. pages

            local count = 0
            for i = (State.serverPage - 1) * PER_PAGE + 1, math.min(#items, State.serverPage * PER_PAGE) do
                count = count + 1
                local s = items[i]
                local url = Config.JOIN_PREFIX .. s.code
                local col = (count - 1) % 2
                local r = math.floor((count - 1) / 2)

                local cardItem = mk("Frame", {
                    Position = UDim2.new(col * 0.5, col == 1 and 6 or 0, 0, r * 62),
                    Size = UDim2.new(0.5, -6, 0, 54),
                    BackgroundColor3 = Carbon.surface,
                    BorderSizePixel = 0,
                    ZIndex = 73
                }, grid)
                corner(cardItem, 10)
                local st = borderStroke(cardItem, Carbon.hairline, 0, 1)

                attach(cardItem.MouseEnter, function()
                    Motion.spring(cardItem, {BackgroundColor3 = Carbon.surfaceHover}, 0.12)
                    st.Color = Carbon.hairlineFocus
                end, State.tabConns)
                attach(cardItem.MouseLeave, function()
                    Motion.spring(cardItem, {BackgroundColor3 = Carbon.surface}, 0.14)
                    st.Color = Carbon.hairline
                end, State.tabConns)

                label(cardItem, s.label, {
                    Position = UDim2.fromOffset(14, 8),
                    Size = UDim2.new(1, -150, 0, 18),
                    Font = FONT_BOLD,
                    TextSize = 12,
                    ZIndex = 74
                })

                label(cardItem, "VIP Lobby #" .. s.number .. "  ·  " .. s.category, {
                    Position = UDim2.fromOffset(14, 27),
                    Size = UDim2.new(1, -150, 0, 15),
                    Font = FONT_REG,
                    TextSize = 10,
                    TextColor3 = Carbon.textMuted,
                    ZIndex = 74
                })

                button(cardItem, "Copy", "default", {
                    Position = UDim2.new(1, -128, 0.5, -13),
                    Size = UDim2.fromOffset(52, 26),
                    TextSize = 11,
                    ZIndex = 75
                }, function()
                    copyOrNotify(url, "Server link copied")
                end, State.tabConns)

                button(cardItem, "Join", "primary", {
                    Position = UDim2.new(1, -68, 0.5, -13),
                    Size = UDim2.fromOffset(52, 26),
                    TextSize = 11,
                    ZIndex = 75
                }, function()
                    openLink(url, s.label)
                end, State.tabConns)
            end

            grid.Size = UDim2.new(1, 0, 0, math.max(62, math.ceil(count / 2) * 62))
        end

        Motion.staggerIn({toolbar, grid}, 0.04)
        render()
    end

    -- ========================================================================
    -- TAB 6: SETTINGS
    -- ========================================================================
    Tabs.Settings = function(page)
        local currencyPanel = Components.panel(page, "Currency Display Mode", "Choose which valuation system appears in trade slots", {
            Size = UDim2.new(1, 0, 0, 102),
            LayoutOrder = ord()
        })

        local modeBody = mk("Frame", {
            Position = UDim2.fromOffset(16, 52),
            Size = UDim2.new(1, -32, 0, 36),
            BackgroundTransparency = 1,
            ZIndex = 74
        }, currencyPanel)

        local currSetters = {}
        for _, cOpt in ipairs({
            {id = "BOTH", label = "Supreme + MM2Values", x = 0,   w = 164},
            {id = "SV",   label = "Supreme Only (SV)",   x = 172, w = 144},
            {id = "MV",   label = "MM2Values Only (MV)", x = 324, w = 156}
        }) do
            local b = mk("TextButton", {
                Text = cOpt.label,
                Position = UDim2.fromOffset(cOpt.x, 2),
                Size = UDim2.fromOffset(cOpt.w, 30),
                BackgroundColor3 = Carbon.surfaceRecessed,
                TextColor3 = Carbon.textSecondary,
                Font = FONT_BOLD,
                TextSize = 11,
                AutoButtonColor = false,
                BorderSizePixel = 0,
                ZIndex = 75
            }, modeBody)
            corner(b, 8)
            local st = borderStroke(b, Carbon.hairline, 0, 1)

            currSetters[cOpt.id] = function(active)
                b.BackgroundColor3 = active and Carbon.pillActive or Carbon.surfaceRecessed
                b.TextColor3 = active and Carbon.pillActiveInk or Carbon.textSecondary
                st.Color = active and Carbon.pillActive or Carbon.hairline
            end

            attach(b.MouseButton1Click, function()
                Prefs.currencyMode = cOpt.id
                Store.savePrefs()
                for id, fn in pairs(currSetters) do fn(id == cOpt.id) end
                if State.latestTrade then pcall(updateHud, State.latestTrade) end
            end, State.tabConns)
        end
        currSetters[Prefs.currencyMode](true)

        local behaviorPanel = Components.panel(page, "Overlaid HUDs & Performance", "Configure profile valuation pill, trade tags, and motion", {
            Size = UDim2.new(1, 0, 0, 318),
            LayoutOrder = ord()
        })

        local rows = {
            {title = "Player Profile Valuation Pill", desc = "Show compact SV/MV total when viewing anyone's profile", key = "showProfileHud", onChange = function(v)
                if not v then
                    State.profileVisible = false
                    UI.profileHud.Visible = false
                end
            end},
            {title = "Trade Slot Price Tags", desc = "Show compact SV/MV tags inside MM2 trade slots", key = "showTags", onChange = function(v) if not v then Trade.hideTags() end end},
            {title = "Compact Trade HUD", desc = "Use a smaller layout for the active trade evaluator", key = "compact", onChange = function() UI.applyHudSize() end},
            {title = "Smooth UI Motion", desc = "Enable spring transitions and staggered card entrances", key = "animations"},
            {title = "Low Power Mode", desc = "Slower background polling and disabled animations", key = "lowPower"},
            {title = "Reload After Teleport", desc = "Automatically queue script re-execution on server hop", key = "autoQueue", onChange = function(v)
                if v and not Net.queueReload() then
                    notify("Teleport Queue", "Not supported by this executor", Carbon.textSecondary)
                end
            end}
        }

        for i, item in ipairs(rows) do
            local ry = 50 + (i - 1) * 43
            local r = mk("Frame", {
                Position = UDim2.fromOffset(16, ry),
                Size = UDim2.new(1, -32, 0, 41),
                BackgroundTransparency = 1,
                ZIndex = 74
            }, behaviorPanel)

            if i < #rows then
                mk("Frame", {
                    Position = UDim2.new(0, 0, 1, -1),
                    Size = UDim2.new(1, 0, 0, 1),
                    BackgroundColor3 = Carbon.hairline,
                    BorderSizePixel = 0,
                    ZIndex = 75
                }, r)
            end

            label(r, item.title, {
                Size = UDim2.new(1, -60, 0, 18),
                Font = FONT_BOLD,
                TextSize = 12,
                ZIndex = 75
            })
            label(r, item.desc, {
                Position = UDim2.fromOffset(0, 19),
                Size = UDim2.new(1, -60, 0, 15),
                Font = FONT_REG,
                TextSize = 11,
                TextColor3 = Carbon.textMuted,
                ZIndex = 75
            })

            local sw = toggleSwitch(r, Prefs[item.key], function(v)
                Prefs[item.key] = v
                Store.savePrefs()
                if item.onChange then pcall(item.onChange, v) end
            end, State.tabConns)
            sw.Position = UDim2.new(1, -42, 0.5, -11)
            sw.ZIndex = 75
        end

        local sysBar = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundTransparency = 1,
            LayoutOrder = ord(),
            ZIndex = 73
        }, page)

        button(sysBar, "Reset Positions", "default", {
            Size = UDim2.fromOffset(122, 30),
            TextSize = 11,
            ZIndex = 75
        }, function()
            Prefs.hudX, Prefs.hudY, Prefs.btnX, Prefs.btnY, Prefs.profX, Prefs.profY = 16, 82, -1, 82, -1, 48
            UI.hud.Position = UDim2.fromOffset(16, 82)
            UI.launcher.Position = UDim2.fromOffset(math.max(16, State.screenSize.X - 138), 82)
            UI.profileHud.Position = UDim2.fromOffset(math.max(16, math.floor(State.screenSize.X * 0.5 - 155)), 48)
            local nw, nh = computeShellSize()
            local cx = math.max(8, math.floor((State.screenSize.X - nw) * 0.5))
            local cy = math.max(8, math.floor((State.screenSize.Y - nh) * 0.5))
            UI.win.Position = UDim2.fromOffset(cx, cy)
            if Shell.shadow then Shell.shadow.Position = UDim2.fromOffset(cx - 6, cy) end
            Store.savePrefs()
            notify("Positions reset", "Window, HUD, and pills restored", Carbon.textPrimary)
        end, State.tabConns)

        button(sysBar, "Unload Carbon", "default", {
            Position = UDim2.fromOffset(132, 0),
            Size = UDim2.fromOffset(114, 30),
            TextSize = 11,
            ZIndex = 75
        }, function()
            cleanup()
        end, State.tabConns)

        Motion.staggerIn({currencyPanel, behaviorPanel, sysBar}, 0.04)
    end

    -- ========================================================================
    -- VIEW ROUTER, STATUS SYNC & VIEWPORT FITTING
    -- ========================================================================
    function UI.selectTab(name)
        if not Tabs[name] then name = "Overview" end
        State.currentTab = name
        Win.paintTabs()
        local page = Win.newPage()
        local okTab, err = pcall(Tabs[name], page)
        if not okTab then
            warn("[Carbon] View '" .. name .. "' failed: " .. tostring(err))
            Components.emptyState(page, "Render Error", tostring(err):sub(1, 140), 40)
        end
    end

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
        if Shell and Shell.applyResponsiveGeometry then
            pcall(Shell.applyResponsiveGeometry)
        end
        if UI.win and Win.scale then
            local targetW, targetH = computeShellSize()
            Win.scale.Scale = math.clamp(math.min((State.screenSize.X - 12) / targetW, (State.screenSize.Y - 12) / targetH), 0.55, 1)
            pcall(clampInto, UI.win)
            if Shell.shadow then
                Shell.shadow.Position = UDim2.fromOffset(UI.win.Position.X.Offset - 6, UI.win.Position.Y.Offset)
            end
        end
        UI.hudScale.Scale = math.clamp((State.screenSize.X - 16) / 296, 0.68, 1)
        pcall(clampInto, UI.hud)
        pcall(clampInto, UI.launcher)
        pcall(clampInto, UI.profileHud)
    end

    function UI.setWindow(visible)
        if visible then
            applyLayout()
            ensureFreshPrices(120)
            UI.win.Visible = true
            if Shell.shadow then Shell.shadow.Visible = true end
            UI.selectTab(State.currentTab)
        else
            UI.win.Visible = false
            if Shell.shadow then Shell.shadow.Visible = false end
        end
    end

    function UI.updateStatus()
        local color, text
        if not Data.loaded then
            color, text = Carbon.textSecondary, "Syncing live feeds..."
        elseif Data.lastError or Data.supremeStale then
            color, text = Carbon.textSecondary, (Data.lastError or "Feed outdated") .. " · SV " .. Data.supremeStamp
        else
            color, text = Carbon.textPrimary, "Feeds Connected · " .. #Data.itemsList .. " items indexed"
        end
        UI.launcherDot.BackgroundColor3 = color
        if Win.sideDot then Win.sideDot.BackgroundColor3 = color end
        if Win.status then Win.status.Text = text end
        if Win.svPill then Win.svPill.Text = "SV " .. Data.supremeStamp:sub(6) end
        if Win.mvPill then Win.mvPill.Text = "MV " .. Data.mm2Stamp:sub(6) end
    end

    attach(UI.launcher.MouseButton1Click, function()
        if didDragLauncher() then return end
        UI.setWindow(not UI.win.Visible)
    end)
    attach(UI.launcher.MouseEnter, function() Motion.spring(UI.launcher, {BackgroundColor3 = Carbon.surfaceHover}, 0.1) end)
    attach(UI.launcher.MouseLeave, function() Motion.spring(UI.launcher, {BackgroundColor3 = Carbon.surface}, 0.12) end)
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

    -- ========================================================================
    -- INITIALIZATION & BACKGROUND LOOPS
    -- ========================================================================
    Shell.build()
    refreshScreen()
    if Prefs.btnX < 0 then
        UI.launcher.Position = UDim2.fromOffset(math.max(16, State.screenSize.X - 138), Prefs.btnY)
    end
    if Prefs.profX < 0 then
        UI.profileHud.Position = UDim2.fromOffset(math.max(16, math.floor(State.screenSize.X * 0.5 - 155)), Prefs.profY)
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

    notify("Carbon ready", "Press " .. Config.TOGGLE_KEY.Name .. " or tap Carbon", Carbon.textPrimary)
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
        t.BackgroundColor3 = Color3.fromRGB(22, 22, 25)
        t.TextColor3 = Color3.fromRGB(244, 244, 246)
        t.TextWrapped = true
        t.TextSize = 12
        t.Font = Enum.Font.GothamBold
        t.Text = "CARBON ERROR\n" .. tostring(failure):sub(1, 240)
        t.Parent = g
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 10)
        c.Parent = t
    end)
end
