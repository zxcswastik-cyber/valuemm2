-- MM2 CARBON | Fortnite UI Edition (Read-Only Trading Intelligence Terminal)
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
    -- FORTNITE VISUAL SYSTEM (ROYAL BLUE GRADIENTS, RARITIES & DAMAGE NUMBERS)
    -- ========================================================================
    local FN = {
        bgTop = Color3.fromRGB(16, 124, 240),         -- Bright Fortnite sky/royal blue
        bgMid = Color3.fromRGB(9, 68, 164),           -- Mid royal blue
        bgBottom = Color3.fromRGB(5, 32, 88),         -- Deep navy wave base

        cardBg = Color3.fromRGB(8, 34, 86),           -- Translucent locker/shop card fill
        cardAlt = Color3.fromRGB(6, 24, 64),          -- Darker inset tile
        cardHover = Color3.fromRGB(16, 56, 132),      -- Interactive tile hover
        footerDark = Color3.fromRGB(5, 14, 34),       -- Item Shop bottom nameplate bar

        borderBlue = Color3.fromRGB(56, 168, 255),    -- Crisp electric blue card border
        borderSoft = Color3.fromRGB(32, 102, 196),    -- Subtle divider border
        borderWhite = Color3.fromRGB(255, 255, 255),  -- Active selection outline

        white = Color3.fromRGB(255, 255, 255),
        inkDark = Color3.fromRGB(10, 22, 48),         -- Text on white pills
        textMuted = Color3.fromRGB(162, 210, 255),    -- Soft sky-blue secondary text
        textDim = Color3.fromRGB(110, 164, 226),      -- Captions & metadata

        btnPrimary = Color3.fromRGB(32, 178, 255),    -- Fortnite "SAVE LOADOUT" cyan-blue
        btnPrimaryHover = Color3.fromRGB(72, 198, 255),
        btnKeybind = Color3.fromRGB(238, 246, 255),   -- Keybind white/ice pill
        btnKeybindHover = Color3.fromRGB(255, 255, 255),

        -- Damage Number Styles (50676.jpg Shield & 50677.jpg Health/Base)
        shieldFill = Color3.fromRGB(69, 243, 255),    -- #45F3FF Bright Shield Cyan (MV)
        shieldStroke = Color3.fromRGB(11, 43, 76),    -- #0B2B4C Deep Navy Outline
        baseFill = Color3.fromRGB(255, 255, 255),     -- #FFFFFF Pure White (SV)
        baseStroke = Color3.fromRGB(12, 16, 24),      -- #0C1018 Heavy Black Outline
        goldFill = Color3.fromRGB(255, 214, 68),      -- Gold highlight
        goldStroke = Color3.fromRGB(44, 24, 4),

        pos = Color3.fromRGB(74, 238, 138),
        posBg = Color3.fromRGB(12, 68, 48),
        neg = Color3.fromRGB(255, 76, 92),
        negBg = Color3.fromRGB(84, 18, 32),
        warn = Color3.fromRGB(255, 204, 64),
        warnBg = Color3.fromRGB(82, 58, 14),

        -- Fortnite Rarity Accents
        rarityLegendary = Color3.fromRGB(255, 152, 24),
        rarityEpic = Color3.fromRGB(186, 82, 255),
        rarityRare = Color3.fromRGB(44, 174, 255),
        rarityUncommon = Color3.fromRGB(76, 218, 108)
    }

    local DISPLAY_FONT = Enum.Font.FredokaOne
    local UI_FONT_BOLD = Enum.Font.GothamBlack
    local UI_FONT_MED = Enum.Font.GothamBold

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
        prevOther = "",
        warningUntil = 0,
        toastId = 0,
        hudCollapsed = false,
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
        autoQueue = false,
        favs = {},
        wishlist = {},
        myItems = {},
        hudX = 16,
        hudY = 82,
        btnX = -1,
        btnY = 82
    }

    local UI = {}
    local Win = {order = 0, topTabs = {}, navButtons = {}}
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

    local function getRarityAccent(row)
        if not row then return FN.rarityRare end
        local cat = tostring(row.category or ""):lower()
        local name = tostring(row.name or ""):lower()
        if name:find("chroma", 1, true) or cat:find("ancient", 1, true) or (row.supreme or 0) >= 800 then
            return FN.rarityLegendary
        elseif cat:find("godl", 1, true) or (row.supreme or 0) >= 50 then
            return FN.rarityEpic
        elseif cat:find("vintage", 1, true) or cat:find("legend", 1, true) or (row.supreme or 0) >= 5 then
            return FN.rarityRare
        end
        return FN.rarityUncommon
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
                rarityColor = getRarityAccent(row)
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
    -- FORTNITE UI & OUTLINED DAMAGE NUMBER PRIMITIVES
    -- ========================================================================
    local function mk(className, props, parent)
        local inst = Instance.new(className)
        for k, v in pairs(props or {}) do inst[k] = v end
        inst.Parent = parent
        return inst
    end

    local function corner(obj, r)
        return mk("UICorner", {CornerRadius = UDim.new(0, r or 6)}, obj)
    end

    local function borderStroke(obj, color, trans, thickness)
        return mk("UIStroke", {
            Color = color or FN.borderBlue,
            Transparency = trans or 0,
            Thickness = thickness or 1.5,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        }, obj)
    end

    local function textStroke(obj, color, thickness)
        return mk("UIStroke", {
            Color = color or FN.baseStroke,
            Transparency = 0,
            Thickness = thickness or 2.4,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
        }, obj)
    end

    local function applyFortniteSkyGradient(frame)
        return mk("UIGradient", {
            Rotation = 90,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, FN.bgTop),
                ColorSequenceKeypoint.new(0.45, FN.bgMid),
                ColorSequenceKeypoint.new(1.00, FN.bgBottom)
            })
        }, frame)
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
                frame.Position = UDim2.new(origPos.X.Scale, origPos.X.Offset, origPos.Y.Scale, origPos.Y.Offset + 10)
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
            Font = UI_FONT_MED,
            TextSize = 12,
            TextColor3 = FN.white,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            BorderSizePixel = 0
        }
        for k, v in pairs(props or {}) do p[k] = v end
        return mk("TextLabel", p, parent)
    end

    -- Fortnite Damage-Number Outlined Text (50676.jpg Shield Cyan & 50677.jpg White Base)
    local function fnNumber(parent, text, style, props)
        local fill = FN.baseFill
        local outline = FN.baseStroke
        if style == "shield" or style == "mv" then
            fill = FN.shieldFill
            outline = FN.shieldStroke
        elseif style == "gold" then
            fill = FN.goldFill
            outline = FN.goldStroke
        elseif style == "pos" then
            fill = FN.pos
            outline = Color3.fromRGB(6, 36, 20)
        elseif style == "neg" then
            fill = FN.neg
            outline = Color3.fromRGB(40, 6, 12)
        end

        local p = {
            BackgroundTransparency = 1,
            Text = tostring(text or ""),
            Font = DISPLAY_FONT,
            TextSize = 18,
            TextColor3 = fill,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            BorderSizePixel = 0
        }
        for k, v in pairs(props or {}) do p[k] = v end
        local lbl = mk("TextLabel", p, parent)
        textStroke(lbl, outline, p.StrokeThickness or 2.4)
        return lbl
    end

    -- Fortnite Action Buttons (Sky Blue "SAVE LOADOUT", White Keybind Pill, Dark Locker Tile)
    local function button(parent, text, style, props, onClick, bucket)
        local isPrimary = style == "primary"
        local isWhite = style == "white"
        local isDanger = style == "danger"
        local isGhost = style == "ghost"

        local bg = isPrimary and FN.btnPrimary
            or (isWhite and FN.btnKeybind
            or (isDanger and FN.neg
            or FN.cardBg))
        local bgHover = isPrimary and FN.btnPrimaryHover
            or (isWhite and FN.btnKeybindHover
            or (isDanger and Color3.fromRGB(255, 102, 116)
            or FN.cardHover))
        local fg = (isPrimary or isWhite) and FN.inkDark or FN.white

        local p = {
            Text = string.upper(tostring(text or "")),
            Font = UI_FONT_BOLD,
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
        corner(b, 6)
        if not isGhost and not isPrimary and not isWhite then
            borderStroke(b, isDanger and FN.neg or FN.borderBlue, 0.2, 1.5)
        end

        attach(b.MouseEnter, function()
            Motion.spring(b, {
                BackgroundColor3 = bgHover,
                BackgroundTransparency = 0
            }, 0.1)
        end, bucket)
        attach(b.MouseLeave, function()
            Motion.spring(b, {
                BackgroundColor3 = bg,
                BackgroundTransparency = isGhost and 1 or 0
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
            BackgroundColor3 = FN.cardAlt,
            TextColor3 = FN.white,
            PlaceholderColor3 = FN.textDim,
            Font = UI_FONT_MED,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            BorderSizePixel = 0
        }
        for k, v in pairs(props or {}) do p[k] = v end
        local box = mk("TextBox", p, parent)
        corner(box, 6)
        local st = borderStroke(box, FN.borderBlue, 0.25, 1.5)
        pad(box, 0, 12, 0, 12)

        attach(box.Focused, function()
            Motion.spring(st, {Color = FN.white, Transparency = 0}, 0.12)
        end)
        attach(box.FocusLost, function()
            Motion.spring(st, {Color = FN.borderBlue, Transparency = 0.25}, 0.12)
        end)
        return box
    end

    -- Fortnite Keybind-Style ON/OFF Pill Switch (50674.jpg)
    local function toggleSwitch(parent, initialState, onToggle, bucket)
        local state = initialState == true
        local pillBtn = mk("TextButton", {
            Size = UDim2.fromOffset(66, 26),
            BackgroundColor3 = state and FN.btnKeybind or FN.cardAlt,
            Text = state and "ON" or "OFF",
            Font = UI_FONT_BOLD,
            TextSize = 11,
            TextColor3 = state and FN.inkDark or FN.textMuted,
            AutoButtonColor = false,
            BorderSizePixel = 0
        }, parent)
        corner(pillBtn, 6)
        local st = borderStroke(pillBtn, state and FN.white or FN.borderBlue, 0.1, 1.5)

        attach(pillBtn.MouseButton1Click, function()
            if not State.alive then return end
            state = not state
            pillBtn.Text = state and "ON" or "OFF"
            Motion.spring(pillBtn, {
                BackgroundColor3 = state and FN.btnKeybind or FN.cardAlt,
                TextColor3 = state and FN.inkDark or FN.textMuted
            }, 0.14)
            st.Color = state and FN.white or FN.borderBlue
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

    -- ========================================================================
    -- ROOT SCREENGUI, TOAST, FLOATING LAUNCHER & TRADE HUD
    -- ========================================================================
    UI.root = track(mk("ScreenGui", {
        Name = "MM2CarbonX",
        ResetOnSpawn = false,
        IgnoreGuiInset = false,
        DisplayOrder = 3900,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    }, playerGui))

    -- Fortnite Notification Banner
    UI.toast = mk("Frame", {
        Position = UDim2.new(0.5, -165, 0, 16),
        Size = UDim2.fromOffset(330, 50),
        BackgroundColor3 = FN.cardBg,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 90
    }, UI.root)
    corner(UI.toast, 8)
    UI.toastStroke = borderStroke(UI.toast, FN.borderBlue, 0, 2)

    UI.toastBar = mk("Frame", {
        Size = UDim2.new(0, 5, 1, 0),
        BackgroundColor3 = FN.pos,
        BorderSizePixel = 0,
        ZIndex = 92
    }, UI.toast)
    corner(UI.toastBar, 4)

    UI.toastTitle = label(UI.toast, "", {
        Position = UDim2.fromOffset(16, 6),
        Size = UDim2.new(1, -24, 0, 18),
        Font = UI_FONT_BOLD,
        TextSize = 12,
        ZIndex = 92
    })
    UI.toastBody = label(UI.toast, "", {
        Position = UDim2.fromOffset(16, 24),
        Size = UDim2.new(1, -24, 0, 16),
        TextSize = 11,
        TextColor3 = FN.textMuted,
        ZIndex = 92
    })

    local function notify(title, body, tint)
        State.toastId = State.toastId + 1
        local id = State.toastId
        local c = tint or FN.pos
        UI.toastBar.BackgroundColor3 = c
        UI.toastStroke.Color = c
        UI.toastTitle.Text = string.upper(tostring(title or "MM2 CARBON"))
        UI.toastBody.Text = tostring(body or "")
        UI.toast.Visible = true
        if Prefs.animations and not Prefs.lowPower then
            UI.toast.Position = UDim2.new(0.5, -165, 0, 6)
            Motion.spring(UI.toast, {Position = UDim2.new(0.5, -165, 0, 16)}, 0.16)
        end
        task.delay(2.4, function()
            if State.alive and State.toastId == id then
                UI.toast.Visible = false
            end
        end)
    end

    -- Floating V-Bucks / Locker Style Launcher Pill (50672.jpg top right)
    local startBtnX = Prefs.btnX >= 0 and Prefs.btnX or math.max(16, State.screenSize.X - 150)
    UI.launcher = mk("TextButton", {
        Name = "CarbonLauncher",
        Position = UDim2.fromOffset(startBtnX, Prefs.btnY),
        Size = UDim2.fromOffset(134, 36),
        BackgroundColor3 = FN.cardBg,
        Text = "",
        AutoButtonColor = false,
        BorderSizePixel = 0,
        ZIndex = 60
    }, UI.root)
    corner(UI.launcher, 6)
    borderStroke(UI.launcher, FN.borderBlue, 0, 2)

    local badgeIcon = mk("Frame", {
        Position = UDim2.fromOffset(8, 7),
        Size = UDim2.fromOffset(22, 22),
        BackgroundColor3 = FN.btnPrimary,
        BorderSizePixel = 0,
        ZIndex = 62
    }, UI.launcher)
    corner(badgeIcon, 11)
    label(badgeIcon, "V", {
        Size = UDim2.fromScale(1, 1),
        Font = UI_FONT_BOLD,
        TextSize = 12,
        TextColor3 = FN.inkDark,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 63
    })

    fnNumber(UI.launcher, "CARBON", "base", {
        Position = UDim2.fromOffset(36, 0),
        Size = UDim2.fromOffset(74, 36),
        TextSize = 15,
        StrokeThickness = 2,
        ZIndex = 62
    })

    UI.launcherDot = mk("Frame", {
        Position = UDim2.new(1, -16, 0.5, -4),
        Size = UDim2.fromOffset(8, 8),
        BackgroundColor3 = FN.pos,
        BorderSizePixel = 0,
        ZIndex = 62
    }, UI.launcher)
    corner(UI.launcherDot, 4)

    local didDragLauncher = makeDraggable(UI.launcher, UI.launcher, function(x, y)
        Prefs.btnX = math.floor(x)
        Prefs.btnY = math.floor(y)
        Store.savePrefs()
    end)

    -- Live Trade HUD (Fortnite Squad / Damage HUD Style)
    UI.hud = mk("Frame", {
        Name = "TradeHUD",
        Position = UDim2.fromOffset(Prefs.hudX, Prefs.hudY),
        Size = UDim2.fromOffset(320, 128),
        BackgroundColor3 = FN.cardBg,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 50
    }, UI.root)
    corner(UI.hud, 8)
    UI.hudStroke = borderStroke(UI.hud, FN.borderBlue, 0, 2)
    UI.hudScale = mk("UIScale", {Scale = 1}, UI.hud)

    UI.hudTopBar = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = FN.footerDark,
        BorderSizePixel = 0,
        Active = true,
        ZIndex = 52
    }, UI.hud)
    corner(UI.hudTopBar, 8)

    UI.hudTitle = label(UI.hudTopBar, "TRADE EVALUATOR", {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -124, 1, 0),
        Font = UI_FONT_BOLD,
        TextSize = 11,
        TextColor3 = FN.white,
        ZIndex = 53
    })

    UI.hudBadge = mk("TextLabel", {
        Text = "FAIR",
        Position = UDim2.new(1, -104, 0, 6),
        Size = UDim2.fromOffset(66, 22),
        BackgroundColor3 = FN.white,
        TextColor3 = FN.inkDark,
        Font = UI_FONT_BOLD,
        TextSize = 10,
        BorderSizePixel = 0,
        ZIndex = 53
    }, UI.hudTopBar)
    corner(UI.hudBadge, 5)

    UI.hudCollapse = button(UI.hudTopBar, "–", "ghost", {
        Position = UDim2.new(1, -32, 0, 5),
        Size = UDim2.fromOffset(24, 24),
        TextSize = 14,
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

    local function hudRow(y, caption)
        label(UI.hudBody, caption, {
            Position = UDim2.fromOffset(12, y), Size = UDim2.fromOffset(50, 24),
            Font = UI_FONT_BOLD, TextSize = 11, TextColor3 = FN.textMuted, ZIndex = 53
        })
        local s = fnNumber(UI.hudBody, "SV —", "base", {
            Position = UDim2.fromOffset(66, y), Size = UDim2.fromOffset(122, 24),
            TextSize = 15, StrokeThickness = 2.2,
            TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 53
        })
        local m = fnNumber(UI.hudBody, "MV —", "shield", {
            Position = UDim2.fromOffset(192, y), Size = UDim2.fromOffset(116, 24),
            TextSize = 15, StrokeThickness = 2.2,
            TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 53
        })
        return s, m
    end
    UI.ownS, UI.ownM = hudRow(6, "YOU")
    UI.themS, UI.themM = hudRow(32, "THEM")

    UI.hudDiff = label(UI.hudBody, "NET SPREAD  —", {
        Position = UDim2.fromOffset(12, 62), Size = UDim2.new(1, -24, 0, 18),
        Font = UI_FONT_BOLD, TextSize = 11, TextColor3 = FN.textMuted, ZIndex = 53
    })

    UI.hudWarnBar = mk("Frame", {
        Position = UDim2.fromOffset(12, 84),
        Size = UDim2.new(1, -24, 0, 22),
        BackgroundColor3 = FN.warnBg,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 53
    }, UI.hudBody)
    corner(UI.hudWarnBar, 5)
    borderStroke(UI.hudWarnBar, FN.warn, 0.2, 1)
    UI.hudWarnText = label(UI.hudWarnBar, "", {
        Size = UDim2.new(1, 0, 1, 0), Font = UI_FONT_BOLD, TextSize = 10, TextColor3 = FN.warn,
        TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 54
    })

    function UI.applyHudSize()
        local h
        if State.hudCollapsed then
            h = 34
        else
            h = (Prefs.compact and 100 or 124) + (UI.hudWarnBar.Visible and 28 or 0)
        end
        UI.hudBody.Visible = not State.hudCollapsed
        UI.hudDiff.Visible = not Prefs.compact
        UI.hudWarnBar.Position = UDim2.fromOffset(12, Prefs.compact and 62 or 84)
        UI.hud.Size = UDim2.fromOffset(320, h)
    end
    UI.applyHudSize()

    makeDraggable(UI.hud, UI.hudTopBar, function(x, y)
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
    -- READ-ONLY TRADE EVALUATOR & SERVER SIGHTINGS
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
            Font = DISPLAY_FONT,
            TextSize = 11,
            TextColor3 = FN.baseFill,
            BackgroundColor3 = FN.footerDark,
            BackgroundTransparency = 0.08,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, 0, 1, -2),
            Size = UDim2.new(1, -6, 0, 18),
            TextTruncate = Enum.TextTruncate.AtEnd,
            Visible = false,
            Active = false,
            Selectable = false,
            ZIndex = 75
        }, slot)
        corner(b, 4)
        borderStroke(b, FN.borderBlue, 0, 1.5)
        textStroke(b, FN.baseStroke, 1.8)
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
                        local stBorder = tag:FindFirstChildOfClass("UIStroke")
                        if stBorder and stBorder.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
                            stBorder.Color = row and getRarityAccent(row) or FN.warn
                        end
                        local width = slot.AbsoluteSize and slot.AbsoluteSize.X or 95
                        if width > 0 and width < 86 then
                            tag.Text = "SV " .. formatVal(sTotal)
                        else
                            if Prefs.currencyMode == "SV" then
                                tag.Text = "SV " .. formatVal(sTotal)
                                tag.TextColor3 = FN.baseFill
                            elseif Prefs.currencyMode == "MV" then
                                tag.Text = "MV " .. formatVal(mTotal)
                                tag.TextColor3 = FN.shieldFill
                            else
                                tag.Text = "SV " .. formatVal(sTotal) .. " | MV " .. formatVal(mTotal)
                                tag.TextColor3 = FN.baseFill
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
            notify("VICTORY ROYALE TRADE", entry.delta and ("Net change " .. Util.signed(entry.delta) .. " SV") or "Confirmed by game", FN.pos)
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
        UI.ownS.TextColor3 = mine.missS > 0 and FN.warn or FN.baseFill
        UI.themS.TextColor3 = other.missS > 0 and FN.warn or FN.baseFill

        local d = other.s - mine.s
        local dm = other.m - mine.m
        local txt, fg, bg
        if mine.count + other.count == 0 then
            txt, fg, bg = "EMPTY", FN.inkDark, FN.white
        elseif not Data.loaded then
            txt, fg, bg = "SYNC", FN.inkDark, FN.warn
        elseif incomplete then
            txt, fg, bg = "N/A", FN.inkDark, FN.warn
        else
            local base = math.max(mine.s, other.s)
            if math.abs(d) <= math.max(2, base * 0.05) then
                txt, fg, bg = "FAIR", FN.inkDark, FN.shieldFill
            elseif d > 0 then
                txt, fg, bg = "WIN", FN.inkDark, FN.pos
            else
                txt, fg, bg = "LOSS", FN.white, FN.neg
            end
        end
        UI.hudBadge.Text = txt
        UI.hudBadge.TextColor3 = fg
        UI.hudBadge.BackgroundColor3 = bg
        UI.hudStroke.Color = (txt == "WIN" or txt == "LOSS") and bg or FN.borderBlue

        if incomplete or not Data.loaded then
            UI.hudDiff.Text = "NET SPREAD  incomplete"
        else
            UI.hudDiff.Text = "NET SPREAD  " .. Util.signed(d) .. " SV   |   " .. Util.signed(dm) .. " MV"
        end

        local warnMsg, danger
        if os.clock() < State.warningUntil then
            warnMsg, danger = "OFFER MODIFIED — RE-VERIFY ITEMS!", true
        elseif not Data.loaded then
            warnMsg = "SYNCING LIVE MARKET VALUES..."
        elseif incomplete then
            warnMsg = "UNLISTED ITEM IN TRADE"
        elseif Data.supremeStale then
            warnMsg = "PRICE FEED MAY BE OUTDATED"
        elseif mine.s > 0 and other.s < mine.s * 0.75 then
            warnMsg = "WARNING: YOU ARE GIVING >25% MORE"
        end
        local wasVisible = UI.hudWarnBar.Visible
        UI.hudWarnBar.Visible = warnMsg ~= nil
        if warnMsg then
            UI.hudWarnText.Text = warnMsg
            UI.hudWarnText.TextColor3 = danger and FN.neg or FN.warn
            UI.hudWarnBar.BackgroundColor3 = danger and FN.negBg or FN.warnBg
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
                notify("OFFER CHANGED", "Re-check their items before accepting", FN.warn)
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
    -- FORTNITE LOBBY / ITEM SHOP APPLICATION SHELL (95% VIEWPORT)
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
        local targetW = math.clamp(math.floor(vw * 0.95), 720, 1880)
        local targetH = math.clamp(math.floor(vh * 0.94), 480, 1060)
        return targetW, targetH
    end

    function Shell.build()
        local w, h = computeShellSize()
        local topH = 56
        local botH = 42

        UI.win = mk("Frame", {
            Name = "Window",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(w, h),
            BackgroundColor3 = FN.bgMid,
            BorderSizePixel = 0,
            Visible = false,
            Active = true,
            ClipsDescendants = true,
            ZIndex = 70
        }, UI.root)
        corner(UI.win, 10)
        borderStroke(UI.win, FN.borderBlue, 0, 2)
        applyFortniteSkyGradient(UI.win)
        Win.scale = mk("UIScale", {Scale = 1}, UI.win)

        -- Subtle Fortnite Background Geometric Wave Accents (50674.jpg)
        local wave1 = mk("Frame", {
            Position = UDim2.new(0.55, 0, -0.1, 0),
            Size = UDim2.new(0.6, 0, 1.3, 0),
            Rotation = 18,
            BackgroundColor3 = Color3.fromRGB(45, 165, 255),
            BackgroundTransparency = 0.88,
            BorderSizePixel = 0,
            ZIndex = 70
        }, UI.win)
        corner(wave1, 80)

        -- TOP NAVIGATION BAR (Fortnite Item Shop / Locker Horizontal Tabs 50672.jpg)
        local topbar = mk("Frame", {
            Name = "Topbar",
            Size = UDim2.new(1, 0, 0, topH),
            BackgroundColor3 = Color3.fromRGB(6, 26, 70),
            BackgroundTransparency = 0.25,
            BorderSizePixel = 0,
            Active = true,
            ZIndex = 72
        }, UI.win)
        mk("Frame", {
            Position = UDim2.new(0, 0, 1, -1),
            Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = FN.borderSoft,
            BorderSizePixel = 0,
            ZIndex = 73
        }, topbar)

        -- Left Squad / Status Indicator Pill ([● 1])
        local statusPill = mk("Frame", {
            Position = UDim2.fromOffset(16, 12),
            Size = UDim2.fromOffset(124, 32),
            BackgroundColor3 = FN.cardAlt,
            BorderSizePixel = 0,
            ZIndex = 73
        }, topbar)
        corner(statusPill, 4)
        borderStroke(statusPill, FN.borderSoft, 0.2, 1.5)

        Win.sideDot = mk("Frame", {
            Position = UDim2.fromOffset(10, 11),
            Size = UDim2.fromOffset(10, 10),
            BackgroundColor3 = FN.pos,
            BorderSizePixel = 0,
            ZIndex = 74
        }, statusPill)
        corner(Win.sideDot, 5)

        Win.status = label(statusPill, "SYNCING...", {
            Position = UDim2.fromOffset(26, 0),
            Size = UDim2.new(1, -32, 1, 0),
            Font = UI_FONT_BOLD,
            TextSize = 10,
            TextColor3 = FN.white,
            ZIndex = 74
        })

        -- Centered Fortnite Horizontal Tabs (Active = Crisp White Pill with Dark Navy Text)
        local navRow = mk("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.47, 0.5),
            Size = UDim2.fromOffset(636, 34),
            BackgroundTransparency = 1,
            ZIndex = 73
        }, topbar)
        mk("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 6)
        }, navRow)

        local navItems = {
            {id = "Overview",  label = "OVERVIEW",   w = 96},
            {id = "Values",    label = "ITEM SHOP",  w = 98},
            {id = "Compare",   label = "COMPARE",    w = 92},
            {id = "Inventory", label = "LOCKER",     w = 84},
            {id = "Servers",   label = "SERVERS",    w = 88},
            {id = "Settings",  label = "SETTINGS",   w = 92}
        }

        for idx, item in ipairs(navItems) do
            local b = mk("TextButton", {
                Name = item.id .. "Tab",
                Text = item.label,
                Size = UDim2.fromOffset(item.w, 32),
                BackgroundColor3 = FN.white,
                BackgroundTransparency = 1,
                TextColor3 = FN.textMuted,
                Font = UI_FONT_BOLD,
                TextSize = 12,
                AutoButtonColor = false,
                BorderSizePixel = 0,
                LayoutOrder = idx,
                ZIndex = 74
            }, navRow)
            corner(b, 4)

            Win.topTabs[item.id] = b

            attach(b.MouseEnter, function()
                if State.currentTab ~= item.id then
                    b.TextColor3 = FN.white
                end
            end)
            attach(b.MouseLeave, function()
                if State.currentTab ~= item.id then
                    b.TextColor3 = FN.textMuted
                end
            end)
            attach(b.MouseButton1Click, function()
                if State.alive then UI.selectTab(item.id) end
            end)
        end

        -- Top-Right V-Bucks Style Currency & Sync Badges (50672.jpg)
        local vbuckBox = mk("Frame", {
            Position = UDim2.new(1, -242, 0, 12),
            Size = UDim2.fromOffset(136, 32),
            BackgroundColor3 = FN.cardAlt,
            BorderSizePixel = 0,
            ZIndex = 73
        }, topbar)
        corner(vbuckBox, 4)
        borderStroke(vbuckBox, FN.borderSoft, 0.2, 1.5)

        Win.svPill = fnNumber(vbuckBox, "SV —", "base", {
            Position = UDim2.fromOffset(8, 0),
            Size = UDim2.fromOffset(58, 32),
            TextSize = 12,
            StrokeThickness = 1.8,
            ZIndex = 74
        })
        Win.mvPill = fnNumber(vbuckBox, "MV —", "shield", {
            Position = UDim2.fromOffset(68, 0),
            Size = UDim2.fromOffset(62, 32),
            TextSize = 12,
            StrokeThickness = 1.8,
            TextXAlignment = Enum.TextXAlignment.Right,
            ZIndex = 74
        })

        button(topbar, "SYNC", "primary", {
            Position = UDim2.new(1, -98, 0, 12),
            Size = UDim2.fromOffset(54, 32),
            TextSize = 11,
            ZIndex = 74
        }, function()
            notify("SYNCING FEEDS", "Fetching latest Supreme & MM2Values...", FN.shieldFill)
            task.spawn(function()
                pcall(Net.loadPrices)
                Data.loading = false
            end)
        end)

        button(topbar, "×", "white", {
            Position = UDim2.new(1, -38, 0, 12),
            Size = UDim2.fromOffset(26, 32),
            TextSize = 15,
            ZIndex = 74
        }, function()
            UI.setWindow(false)
        end)

        makeDraggable(UI.win, topbar)

        -- MAIN WORKSPACE SCROLL CONTAINER
        Win.content = mk("Frame", {
            Name = "Workspace",
            Position = UDim2.fromOffset(0, topH),
            Size = UDim2.new(1, 0, 1, -(topH + botH)),
            BackgroundTransparency = 1,
            ZIndex = 71
        }, UI.win)

        -- BOTTOM FORTNITE ACTION BAR (50674.jpg "[X] Restore to default  [B] Back")
        local bottomBar = mk("Frame", {
            Position = UDim2.new(0, 0, 1, -botH),
            Size = UDim2.new(1, 0, 0, botH),
            BackgroundColor3 = FN.footerDark,
            BackgroundTransparency = 0.25,
            BorderSizePixel = 0,
            ZIndex = 72
        }, UI.win)
        mk("Frame", {
            Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = FN.borderSoft,
            BorderSizePixel = 0,
            ZIndex = 73
        }, bottomBar)

        Win.sectionHeading = label(bottomBar, "MM2 CARBON  //  OVERVIEW", {
            Position = UDim2.fromOffset(20, 0),
            Size = UDim2.fromOffset(320, botH),
            Font = UI_FONT_BOLD,
            TextSize = 11,
            TextColor3 = FN.textMuted,
            ZIndex = 73
        })

        local hintPill = mk("Frame", {
            Position = UDim2.new(1, -266, 0, 7),
            Size = UDim2.fromOffset(250, 28),
            BackgroundColor3 = FN.footerDark,
            BorderSizePixel = 0,
            ZIndex = 73
        }, bottomBar)
        corner(hintPill, 14)
        borderStroke(hintPill, FN.borderSoft, 0.25, 1)

        label(hintPill, "[" .. Config.TOGGLE_KEY.Name .. "] Toggle UI    •    Read-Only Safe", {
            Size = UDim2.fromScale(1, 1),
            Font = UI_FONT_BOLD,
            TextSize = 10,
            TextColor3 = FN.white,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 74
        })

        function Win.paintTabs()
            for id, b in pairs(Win.topTabs) do
                local active = (State.currentTab == id)
                if active then
                    Motion.spring(b, {
                        BackgroundTransparency = 0,
                        BackgroundColor3 = FN.white,
                        TextColor3 = FN.inkDark
                    }, 0.14)
                else
                    Motion.spring(b, {
                        BackgroundTransparency = 1,
                        TextColor3 = FN.textMuted
                    }, 0.14)
                end
            end
        end

        function Shell.applyResponsiveGeometry()
            local nw, nh = computeShellSize()
            UI.win.Size = UDim2.fromOffset(nw, nh)
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
            ScrollBarThickness = 5,
            ScrollBarImageColor3 = FN.white,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ZIndex = 72
        }, Win.content)
        pad(Win.page, 18, 24, 18, 24)
        vlist(Win.page, 14)
        return Win.page
    end

    -- ========================================================================
    -- FORTNITE ITEM SHOP & LOCKER CARD COMPONENTS
    -- ========================================================================
    local Components = {}

    -- Item Shop Featured Tile (50672.jpg: Rarity Header Strip + Outlined Damage Value + Dark Footer Bar)
    function Components.statCard(parent, opts)
        local rarityCol = opts.rarityColor or FN.rarityRare
        local cardFrame = mk("Frame", {
            Size = opts.size or UDim2.new(0.25, -9, 0, 102),
            BackgroundColor3 = FN.cardBg,
            BorderSizePixel = 0,
            LayoutOrder = opts.order or 1,
            ClipsDescendants = true,
            ZIndex = 73
        }, parent)
        corner(cardFrame, 8)
        local st = borderStroke(cardFrame, rarityCol, 0.1, 2)

        -- Top Rarity Accent Bar
        mk("Frame", {
            Size = UDim2.new(1, 0, 0, 4),
            BackgroundColor3 = rarityCol,
            BorderSizePixel = 0,
            ZIndex = 74
        }, cardFrame)

        attach(cardFrame.MouseEnter, function()
            Motion.spring(cardFrame, {BackgroundColor3 = FN.cardHover}, 0.12)
            st.Color = FN.white
            st.Transparency = 0
        end, State.tabConns)
        attach(cardFrame.MouseLeave, function()
            Motion.spring(cardFrame, {BackgroundColor3 = FN.cardBg}, 0.14)
            st.Color = rarityCol
            st.Transparency = 0.1
        end, State.tabConns)

        label(cardFrame, string.upper(opts.title), {
            Position = UDim2.fromOffset(14, 10),
            Size = UDim2.new(1, -28, 0, 16),
            Font = UI_FONT_BOLD,
            TextSize = 11,
            TextColor3 = FN.textMuted,
            ZIndex = 74
        })

        -- Outlined Damage-Number Metric (50676.jpg / 50677.jpg)
        local valLabel = fnNumber(cardFrame, "—", opts.numberStyle or "base", {
            Position = UDim2.fromOffset(14, 30),
            Size = UDim2.new(1, -28, 0, 34),
            TextSize = 26,
            StrokeThickness = 2.8,
            ZIndex = 74
        })

        if type(opts.numericValue) == "number" then
            local from = opts.prevValue or opts.numericValue
            Motion.animateNumber(valLabel, from, opts.numericValue, formatVal, opts.suffix or "")
        else
            valLabel.Text = tostring(opts.textValue or "—")
        end

        -- Dark Bottom Nameplate Strip (50672.jpg "OWNED ✓" footer)
        local footer = mk("Frame", {
            Position = UDim2.new(0, 0, 1, -26),
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundColor3 = FN.footerDark,
            BorderSizePixel = 0,
            ZIndex = 74
        }, cardFrame)

        label(footer, string.upper(opts.subtitle or ""), {
            Position = UDim2.fromOffset(14, 0),
            Size = UDim2.new(1, -28, 1, 0),
            Font = UI_FONT_BOLD,
            TextSize = 10,
            TextColor3 = FN.white,
            ZIndex = 75
        })

        return cardFrame
    end

    function Components.panel(parent, title, subtitle, props)
        local p = {
            Size = UDim2.new(1, 0, 0, 200),
            BackgroundColor3 = FN.cardBg,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            ZIndex = 73
        }
        for k, v in pairs(props or {}) do p[k] = v end
        local frame = mk("Frame", p, parent)
        corner(frame, 8)
        borderStroke(frame, FN.borderBlue, 0.2, 1.5)

        local header = mk("Frame", {
            Name = "PanelHeader",
            Size = UDim2.new(1, 0, 0, 46),
            BackgroundColor3 = FN.footerDark,
            BackgroundTransparency = 0.25,
            BorderSizePixel = 0,
            ZIndex = 74
        }, frame)

        fnNumber(header, string.upper(title), "base", {
            Position = UDim2.fromOffset(16, subtitle and 6 or 0),
            Size = UDim2.new(1, -140, 0, subtitle and 20 or 46),
            TextSize = 15,
            StrokeThickness = 2,
            ZIndex = 75
        })

        if subtitle then
            label(header, subtitle, {
                Position = UDim2.fromOffset(16, 26),
                Size = UDim2.new(1, -140, 0, 14),
                Font = UI_FONT_MED,
                TextSize = 10,
                TextColor3 = FN.textMuted,
                ZIndex = 75
            })
        end

        mk("Frame", {
            Position = UDim2.new(0, 0, 1, -1),
            Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = FN.borderSoft,
            BorderSizePixel = 0,
            ZIndex = 74
        }, header)

        return frame, header
    end

    function Components.emptyState(parent, title, desc, yOffset)
        local box = mk("Frame", {
            Position = UDim2.new(0.5, -150, 0, yOffset or 46),
            Size = UDim2.fromOffset(300, 72),
            BackgroundTransparency = 1,
            ZIndex = 74
        }, parent)

        fnNumber(box, string.upper(title), "base", {
            Size = UDim2.new(1, 0, 0, 22),
            TextSize = 15,
            StrokeThickness = 2,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 75
        })

        label(box, desc, {
            Position = UDim2.fromOffset(0, 26),
            Size = UDim2.new(1, 0, 0, 34),
            Font = UI_FONT_MED,
            TextSize = 11,
            TextColor3 = FN.textMuted,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 75
        })
        return box
    end

    -- Fortnite Keybind Row (50674.jpg: Label on Left + White Keybind Value Pill on Right)
    local function keybindRow(parent, key, value, numberStyle, yPos)
        local row = mk("Frame", {
            Position = UDim2.fromOffset(0, yPos),
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            ZIndex = 74
        }, parent)

        label(row, key, {
            Size = UDim2.new(0.55, 0, 1, 0),
            Font = UI_FONT_BOLD,
            TextSize = 12,
            TextColor3 = FN.white,
            ZIndex = 75
        })

        if numberStyle then
            fnNumber(row, tostring(value), numberStyle, {
                Position = UDim2.fromScale(0.55, 0),
                Size = UDim2.fromScale(0.45, 1),
                TextSize = 16,
                StrokeThickness = 2.2,
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 75
            })
        else
            local pill = mk("TextLabel", {
                Text = tostring(value),
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.fromScale(1, 0.5),
                Size = UDim2.fromOffset(118, 24),
                BackgroundColor3 = FN.btnKeybind,
                TextColor3 = FN.inkDark,
                Font = UI_FONT_BOLD,
                TextSize = 11,
                BorderSizePixel = 0,
                ZIndex = 75
            }, row)
            corner(pill, 4)
        end
        return row
    end

    -- ========================================================================
    -- TAB 1: OVERVIEW (FORTNITE LOBBY & FEATURED METRICS)
    -- ========================================================================
    Tabs.Overview = function(page)
        local pStats = Selectors.getPortfolioStats()
        local sightings = Selectors.getServerSightings()
        local favCount, wishCount = Selectors.getWatchlistCount()

        local kpiRow = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 102),
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
            title = "Locker Value (Supreme)",
            rarityColor = FN.rarityLegendary,
            numberStyle = "base",
            numericValue = pStats.totalSV,
            prevValue = State.prevKpis.sv,
            suffix = pStats.missingSV > 0 and "+? SV" or " SV",
            subtitle = pStats.totalUnits .. " Items  •  " .. pStats.stackCount .. " Stacks"
        })

        local k2 = Components.statCard(kpiRow, {
            order = 2,
            title = "Locker Value (MM2Values)",
            rarityColor = FN.rarityRare,
            numberStyle = "shield",
            numericValue = pStats.totalMV,
            prevValue = State.prevKpis.mv,
            suffix = pStats.missingMV > 0 and "+? MV" or " MV",
            subtitle = "Shield-Tier Cross Valuation"
        })

        local k3 = Components.statCard(kpiRow, {
            order = 3,
            title = "Item Shop Database",
            rarityColor = FN.rarityEpic,
            numberStyle = "base",
            numericValue = #Data.itemsList,
            prevValue = State.prevKpis.db,
            subtitle = "SV " .. Data.supremeStamp .. "  •  MV " .. Data.mm2Stamp
        })

        local k4 = Components.statCard(kpiRow, {
            order = 4,
            title = "Match & Trade Log",
            rarityColor = FN.rarityUncommon,
            numberStyle = "pos",
            numericValue = #Data.history,
            prevValue = State.prevKpis.trades,
            suffix = " TRADES",
            subtitle = favCount .. " Favorites  •  " .. wishCount .. " Wishlist"
        })

        State.prevKpis.sv = pStats.totalSV
        State.prevKpis.mv = pStats.totalMV
        State.prevKpis.db = #Data.itemsList
        State.prevKpis.trades = #Data.history

        local mainGrid = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 412),
            BackgroundTransparency = 1,
            LayoutOrder = ord(),
            ZIndex = 72
        }, page)

        -- Left: Recent Trade Activity
        local tradePanel, tradeHeader = Components.panel(
            mainGrid,
            "RECENT TRADE ACTIVITY",
            "Live Murder Mystery 2 trade history & net SV gain/loss",
            {Size = UDim2.new(0.62, -7, 1, 0)}
        )

        if #Data.history > 0 then
            button(tradeHeader, "CLEAR", "white", {
                Position = UDim2.new(1, -76, 0, 10),
                Size = UDim2.fromOffset(62, 26),
                TextSize = 10,
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
                "NO TRADES RECORDED",
                "Completed MM2 trade sessions will appear here automatically.",
                160
            )
        else
            local maxRows = 8
            for i = 1, math.min(#Data.history, maxRows) do
                local h = Data.history[i]
                local rowY = 54 + (i - 1) * 43
                local tr = mk("Frame", {
                    Position = UDim2.fromOffset(12, rowY),
                    Size = UDim2.new(1, -24, 0, 38),
                    BackgroundColor3 = FN.cardAlt,
                    BorderSizePixel = 0,
                    ZIndex = 74
                }, tradePanel)
                corner(tr, 6)
                borderStroke(tr, FN.borderSoft, 0.3, 1)

                local when = tostring(h.at)
                pcall(function() when = os.date("%H:%M", h.at) end)
                local confirmed = (h.status == "CONFIRMED")

                label(tr, when, {
                    Position = UDim2.fromOffset(12, 0),
                    Size = UDim2.fromOffset(44, 38),
                    Font = UI_FONT_BOLD,
                    TextSize = 11,
                    TextColor3 = FN.textMuted,
                    ZIndex = 75
                })

                local statusTag = mk("TextLabel", {
                    Text = confirmed and "DONE" or "CLOSED",
                    Position = UDim2.fromOffset(58, 9),
                    Size = UDim2.fromOffset(58, 20),
                    BackgroundColor3 = confirmed and FN.pos or FN.btnKeybind,
                    TextColor3 = FN.inkDark,
                    Font = UI_FONT_BOLD,
                    TextSize = 9,
                    BorderSizePixel = 0,
                    ZIndex = 75
                }, tr)
                corner(statusTag, 4)

                label(tr, "GOT: " .. tostring(h.get ~= "" and h.get or "—"), {
                    Position = UDim2.fromOffset(124, 4),
                    Size = UDim2.new(1, -220, 0, 16),
                    Font = UI_FONT_BOLD,
                    TextSize = 11,
                    ZIndex = 75
                })

                label(tr, "GAVE: " .. tostring(h.give ~= "" and h.give or "—"), {
                    Position = UDim2.fromOffset(124, 20),
                    Size = UDim2.new(1, -220, 0, 14),
                    TextSize = 10,
                    TextColor3 = FN.textDim,
                    ZIndex = 75
                })

                local nStyle = "base"
                if h.delta then
                    nStyle = h.delta > 0 and "pos" or (h.delta < 0 and "neg" or "base")
                end
                fnNumber(tr, h.delta and (Util.signed(h.delta) .. " SV") or "—", nStyle, {
                    Position = UDim2.new(1, -94, 0, 0),
                    Size = UDim2.fromOffset(82, 38),
                    TextSize = 14,
                    StrokeThickness = 2,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    ZIndex = 75
                })
            end
        end

        -- Right Stack: Server Sightings + Feed Sources
        local rightStack = mk("Frame", {
            Position = UDim2.new(0.62, 7, 0, 0),
            Size = UDim2.new(0.38, -7, 1, 0),
            BackgroundTransparency = 1,
            ZIndex = 73
        }, mainGrid)

        local sightPanel = Components.panel(
            rightStack,
            "LOBBY SIGHTINGS (" .. #sightings .. ")",
            "Players holding 250+ SV items in this server",
            {Size = UDim2.new(1, 0, 0, 236)}
        )

        if #sightings == 0 then
            Components.emptyState(
                sightPanel,
                "NO RARE ITEMS SPOTTED",
                "Equipped weapons worth 250+ SV on this server appear here.",
                90
            )
        else
            for i = 1, math.min(#sightings, 4) do
                local s = sightings[i]
                local sy = 52 + (i - 1) * 43
                local sr = mk("Frame", {
                    Position = UDim2.fromOffset(12, sy),
                    Size = UDim2.new(1, -24, 0, 38),
                    BackgroundColor3 = FN.cardAlt,
                    BorderSizePixel = 0,
                    ZIndex = 74
                }, sightPanel)
                corner(sr, 6)
                borderStroke(sr, FN.rarityLegendary, 0.35, 1)

                label(sr, tostring(s.name), {
                    Position = UDim2.fromOffset(12, 4),
                    Size = UDim2.new(1, -96, 0, 16),
                    Font = UI_FONT_BOLD,
                    TextSize = 11,
                    ZIndex = 75
                })
                label(sr, tostring(s.player) .. " • " .. Util.ago(s.at), {
                    Position = UDim2.fromOffset(12, 20),
                    Size = UDim2.new(1, -96, 0, 14),
                    TextSize = 10,
                    TextColor3 = FN.textMuted,
                    ZIndex = 75
                })
                fnNumber(sr, formatVal(s.value) .. " SV", "gold", {
                    Position = UDim2.new(1, -86, 0, 0),
                    Size = UDim2.fromOffset(76, 38),
                    TextSize = 14,
                    StrokeThickness = 2,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    ZIndex = 75
                })
            end
        end

        local feedPanel = Components.panel(
            rightStack,
            "DATA FEED SOURCES",
            "Live Supreme CSV & MM2Values JSON sync",
            {Position = UDim2.fromOffset(0, 248), Size = UDim2.new(1, 0, 0, 164)}
        )

        local feedBody = mk("Frame", {
            Position = UDim2.fromOffset(16, 54),
            Size = UDim2.new(1, -32, 0, 98),
            BackgroundTransparency = 1,
            ZIndex = 74
        }, feedPanel)

        label(feedBody, "SUPREME: " .. Data.supremeStamp .. "   •   MM2VALUES: " .. Data.mm2Stamp, {
            Size = UDim2.new(1, 0, 0, 16),
            Font = UI_FONT_BOLD,
            TextSize = 11,
            TextColor3 = FN.white,
            ZIndex = 75
        })

        local syncLine = Data.lastError and ("STATUS: " .. tostring(Data.lastError))
            or (Data.lastFetchAt > 0 and ("SYNCED " .. Util.ago(Data.lastFetchAt) .. " • AUTO-REFRESH ACTIVE") or "INITIALIZING DATASET...")
        label(feedBody, syncLine, {
            Position = UDim2.fromOffset(0, 20),
            Size = UDim2.new(1, 0, 0, 16),
            TextSize = 10,
            TextColor3 = Data.lastError and FN.warn or FN.textMuted,
            ZIndex = 75
        })

        button(feedBody, "SYNC NOW", "primary", {
            Position = UDim2.fromOffset(0, 50),
            Size = UDim2.fromOffset(92, 32),
            TextSize = 11,
            ZIndex = 75
        }, function()
            notify("SYNCING", "Refreshing Supreme & MM2Values...", FN.shieldFill)
            task.spawn(function()
                pcall(Net.loadPrices)
                Data.loading = false
            end)
        end, State.tabConns)

        button(feedBody, "SUPREME WEB", "white", {
            Position = UDim2.fromOffset(100, 50),
            Size = UDim2.fromOffset(104, 32),
            TextSize = 11,
            ZIndex = 75
        }, function()
            openLink(Config.OFFICIAL_SITE, "Supreme Values")
        end, State.tabConns)

        button(feedBody, "COPY URL", "default", {
            Position = UDim2.fromOffset(212, 50),
            Size = UDim2.fromOffset(78, 32),
            TextSize = 11,
            ZIndex = 75
        }, function()
            copyOrNotify(Config.OFFICIAL_SITE, "Supreme URL copied")
        end, State.tabConns)

        Motion.staggerIn({k1, k2, k3, k4, tradePanel, sightPanel, feedPanel}, 0.03)
        Win.refresh = function() UI.selectTab("Overview") end
    end

    -- ========================================================================
    -- TAB 2: ITEM SHOP / MARKET INDEX
    -- ========================================================================
    Tabs.Values = function(page)
        local render

        local toolbar = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundTransparency = 1,
            LayoutOrder = ord(),
            ZIndex = 73
        }, page)

        local searchBox = inputBox(toolbar, "Search MM2 items (e.g. Harvester, Chroma Luger)...", State.valueSearch, {
            Size = UDim2.fromOffset(300, 34),
            ZIndex = 74
        })

        local filterSetters = {}
        local filterX = 310
        for _, f in ipairs({
            {id = "All", label = "ALL", w = 48},
            {id = "Favs", label = "FAVORITES", w = 82},
            {id = "Wish", label = "WISHLIST", w = 74},
            {id = "High", label = "500+ SV", w = 68},
            {id = "Chroma", label = "CHROMA", w = 68}
        }) do
            local b = mk("TextButton", {
                Text = f.label,
                Position = UDim2.fromOffset(filterX, 1),
                Size = UDim2.fromOffset(f.w, 32),
                BackgroundColor3 = FN.cardBg,
                TextColor3 = FN.textMuted,
                Font = UI_FONT_BOLD,
                TextSize = 10,
                AutoButtonColor = false,
                BorderSizePixel = 0,
                ZIndex = 74
            }, toolbar)
            corner(b, 5)
            local st = borderStroke(b, FN.borderSoft, 0.2, 1.5)

            filterSetters[f.id] = function(active)
                b.BackgroundColor3 = active and FN.white or FN.cardBg
                b.TextColor3 = active and FN.inkDark or FN.textMuted
                st.Color = active and FN.white or FN.borderSoft
            end

            attach(b.MouseButton1Click, function()
                State.valueFilter = f.id
                State.valuePage = 1
                for id, fn in pairs(filterSetters) do fn(id == f.id) end
                render()
            end, State.tabConns)

            filterX = filterX + f.w + 6
        end
        if not filterSetters[State.valueFilter] then State.valueFilter = "All" end
        filterSetters[State.valueFilter](true)

        local sortCycle = {
            {id = "SV_DESC", label = "SORT: SV ↓"},
            {id = "SV_ASC",  label = "SORT: SV ↑"},
            {id = "MV_DESC", label = "SORT: MV ↓"},
            {id = "DEM_DESC",label = "SORT: DEMAND"},
            {id = "NAME_ASC",label = "SORT: A–Z"}
        }
        local function getSortLabel()
            for _, s in ipairs(sortCycle) do
                if s.id == State.valueSort then return s.label end
            end
            return "SORT: SV ↓"
        end

        button(toolbar, getSortLabel(), "primary", {
            Position = UDim2.new(1, -114, 0, 1),
            Size = UDim2.fromOffset(114, 32),
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

        local PER_PAGE = 11
        local ROW_H = 36
        local HEAD_H = 34
        local FOOT_H = 42
        local tableHeight = HEAD_H + (PER_PAGE * ROW_H) + FOOT_H

        local tableCard = mk("Frame", {
            Size = UDim2.new(1, 0, 0, tableHeight),
            BackgroundColor3 = FN.cardBg,
            BorderSizePixel = 0,
            LayoutOrder = ord(),
            ClipsDescendants = true,
            ZIndex = 73
        }, page)
        corner(tableCard, 8)
        borderStroke(tableCard, FN.borderBlue, 0.15, 2)

        local thead = mk("Frame", {
            Size = UDim2.new(1, 0, 0, HEAD_H),
            BackgroundColor3 = FN.footerDark,
            BorderSizePixel = 0,
            ZIndex = 74
        }, tableCard)

        label(thead, "ITEM NAME", {Position = UDim2.fromOffset(18, 0), Size = UDim2.new(0.36, -18, 1, 0), Font = UI_FONT_BOLD, TextSize = 10, TextColor3 = FN.textMuted, ZIndex = 75})
        label(thead, "RARITY / TYPE", {Position = UDim2.fromScale(0.36, 0), Size = UDim2.fromScale(0.15, 1), Font = UI_FONT_BOLD, TextSize = 10, TextColor3 = FN.textMuted, ZIndex = 75})
        label(thead, "SUPREME (SV)", {Position = UDim2.fromScale(0.51, 0), Size = UDim2.fromScale(0.13, 1), Font = UI_FONT_BOLD, TextSize = 10, TextColor3 = FN.white, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 75})
        label(thead, "MM2VALUES (MV)", {Position = UDim2.fromScale(0.64, 0), Size = UDim2.fromScale(0.13, 1), Font = UI_FONT_BOLD, TextSize = 10, TextColor3 = FN.shieldFill, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 75})
        label(thead, "DEMAND", {Position = UDim2.fromScale(0.77, 0), Size = UDim2.fromScale(0.09, 1), Font = UI_FONT_BOLD, TextSize = 10, TextColor3 = FN.textMuted, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 75})
        label(thead, "ACTIONS", {Position = UDim2.new(1, -112, 0, 0), Size = UDim2.fromOffset(94, HEAD_H), Font = UI_FONT_BOLD, TextSize = 10, TextColor3 = FN.textMuted, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 75})

        local tbody = mk("Frame", {
            Position = UDim2.fromOffset(0, HEAD_H),
            Size = UDim2.new(1, 0, 0, PER_PAGE * ROW_H),
            BackgroundTransparency = 1,
            ZIndex = 74
        }, tableCard)

        local tfoot = mk("Frame", {
            Position = UDim2.new(0, 0, 1, -FOOT_H),
            Size = UDim2.new(1, 0, 0, FOOT_H),
            BackgroundColor3 = FN.footerDark,
            BorderSizePixel = 0,
            ZIndex = 74
        }, tableCard)

        local countLbl = label(tfoot, "SYNCING ITEM SHOP...", {
            Position = UDim2.fromOffset(18, 0),
            Size = UDim2.fromOffset(280, FOOT_H),
            Font = UI_FONT_BOLD,
            TextSize = 11,
            TextColor3 = FN.textMuted,
            ZIndex = 75
        })

        button(tfoot, "PREV", "white", {
            Position = UDim2.new(1, -214, 0, 7),
            Size = UDim2.fromOffset(64, 28),
            TextSize = 11,
            ZIndex = 75
        }, function()
            State.valuePage = math.max(1, State.valuePage - 1)
            render()
        end, State.tabConns)

        local pageLbl = fnNumber(tfoot, "1 / 1", "base", {
            Position = UDim2.new(1, -146, 0, 0),
            Size = UDim2.fromOffset(76, FOOT_H),
            TextSize = 14,
            StrokeThickness = 2,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 75
        })

        button(tfoot, "NEXT", "white", {
            Position = UDim2.new(1, -66, 0, 7),
            Size = UDim2.fromOffset(52, 28),
            TextSize = 11,
            ZIndex = 75
        }, function()
            State.valuePage = State.valuePage + 1
            render()
        end, State.tabConns)

        local function renderRow(row, idx)
            local y = (idx - 1) * ROW_H
            local rarityCol = getRarityAccent(row)
            local tr = mk("Frame", {
                Position = UDim2.fromOffset(0, y),
                Size = UDim2.new(1, 0, 0, ROW_H),
                BackgroundColor3 = FN.cardBg,
                BorderSizePixel = 0,
                ZIndex = 74
            }, tbody)

            -- Left Fortnite Rarity Strip
            mk("Frame", {
                Size = UDim2.new(0, 4, 1, 0),
                BackgroundColor3 = rarityCol,
                BorderSizePixel = 0,
                ZIndex = 75
            }, tr)

            mk("Frame", {
                Position = UDim2.new(0, 0, 1, -1),
                Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = FN.borderSoft,
                BackgroundTransparency = 0.4,
                BorderSizePixel = 0,
                ZIndex = 75
            }, tr)

            attach(tr.MouseEnter, function() tr.BackgroundColor3 = FN.cardHover end, State.tabConns)
            attach(tr.MouseLeave, function() tr.BackgroundColor3 = FN.cardBg end, State.tabConns)

            label(tr, string.upper(row.name), {
                Position = UDim2.fromOffset(18, 0),
                Size = UDim2.new(0.36, -24, 1, 0),
                Font = UI_FONT_BOLD,
                TextSize = 12,
                TextColor3 = FN.white,
                ZIndex = 75
            })

            label(tr, (row.category and row.category ~= "") and string.upper(row.category) or "WEAPON", {
                Position = UDim2.fromScale(0.36, 0),
                Size = UDim2.fromScale(0.15, 1),
                Font = UI_FONT_BOLD,
                TextSize = 10,
                TextColor3 = rarityCol,
                ZIndex = 75
            })

            -- Supreme Value in Fortnite White+Black Outlined Font (50677.jpg)
            fnNumber(tr, formatVal(row.supreme), "base", {
                Position = UDim2.fromScale(0.51, 0),
                Size = UDim2.fromScale(0.13, 1),
                TextSize = 15,
                StrokeThickness = 2.1,
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 75
            })

            -- MM2Values in Fortnite Cyan+Navy Outlined Font (50676.jpg)
            fnNumber(tr, formatVal(safeMM2(row)), "shield", {
                Position = UDim2.fromScale(0.64, 0),
                Size = UDim2.fromScale(0.13, 1),
                TextSize = 15,
                StrokeThickness = 2.1,
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 75
            })

            label(tr, row.demand and (formatVal(row.demand) .. " / 10") or "—", {
                Position = UDim2.fromScale(0.77, 0),
                Size = UDim2.fromScale(0.09, 1),
                Font = UI_FONT_BOLD,
                TextSize = 11,
                TextColor3 = FN.textMuted,
                TextXAlignment = Enum.TextXAlignment.Center,
                ZIndex = 75
            })

            local isFav = (Prefs.favs[row.name] == true)
            local isWish = (Prefs.wishlist[row.name] == true)

            local favBtn = mk("TextButton", {
                Text = "★",
                Position = UDim2.new(1, -104, 0, 6),
                Size = UDim2.fromOffset(26, 24),
                BackgroundColor3 = isFav and FN.goldFill or FN.cardAlt,
                TextColor3 = isFav and FN.inkDark or FN.textMuted,
                Font = UI_FONT_BOLD,
                TextSize = 12,
                AutoButtonColor = false,
                BorderSizePixel = 0,
                ZIndex = 75
            }, tr)
            corner(favBtn, 5)
            attach(favBtn.MouseButton1Click, function()
                Prefs.favs[row.name] = not (Prefs.favs[row.name] == true) or nil
                Store.savePrefs()
                render()
            end, State.tabConns)

            local wishBtn = mk("TextButton", {
                Text = "+",
                Position = UDim2.new(1, -74, 0, 6),
                Size = UDim2.fromOffset(26, 24),
                BackgroundColor3 = isWish and FN.btnPrimary or FN.cardAlt,
                TextColor3 = isWish and FN.inkDark or FN.textMuted,
                Font = UI_FONT_BOLD,
                TextSize = 13,
                AutoButtonColor = false,
                BorderSizePixel = 0,
                ZIndex = 75
            }, tr)
            corner(wishBtn, 5)
            attach(wishBtn.MouseButton1Click, function()
                Prefs.wishlist[row.name] = not (Prefs.wishlist[row.name] == true) or nil
                Store.savePrefs()
                render()
            end, State.tabConns)

            local cmpBtn = mk("TextButton", {
                Text = "⇄",
                Position = UDim2.new(1, -44, 0, 6),
                Size = UDim2.fromOffset(26, 24),
                BackgroundColor3 = FN.btnKeybind,
                TextColor3 = FN.inkDark,
                Font = UI_FONT_BOLD,
                TextSize = 11,
                AutoButtonColor = false,
                BorderSizePixel = 0,
                ZIndex = 75
            }, tr)
            corner(cmpBtn, 5)
            attach(cmpBtn.MouseButton1Click, function()
                State.compareB = State.compareA
                State.compareA = row.name
                notify("ADDED TO COMPARE", row.name .. " loaded into Slot A", FN.shieldFill)
            end, State.tabConns)
        end

        render = function()
            clearChildren(tbody)
            if not Data.loaded then
                Components.emptyState(tbody, "SYNCING ITEM SHOP", "Loading Supreme Values & MM2Values datasets...", 140)
                countLbl.Text = "SYNCING..."
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
                countLbl.Text = "0 ITEMS MATCHED"
                Components.emptyState(tbody, "NO ITEMS FOUND", "Try adjusting your search query or clearing active filters.", 140)
                return
            end

            local startIdx = (State.valuePage - 1) * PER_PAGE + 1
            local endIdx = math.min(total, State.valuePage * PER_PAGE)
            countLbl.Text = "SHOWING " .. startIdx .. "–" .. endIdx .. " OF " .. total .. " ITEMS"

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
    -- TAB 3: COMPARE ITEMS (FORTNITE LOCKER LOADOUT COMPARISON 50673.jpg)
    -- ========================================================================
    Tabs.Compare = function(page)
        local update

        local selectorBar = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 38),
            BackgroundTransparency = 1,
            LayoutOrder = ord(),
            ZIndex = 73
        }, page)

        local boxA = inputBox(selectorBar, "Slot A item (e.g. Harvester)...", State.compareA, {
            Size = UDim2.new(0.5, -26, 0, 36),
            ZIndex = 74
        })

        button(selectorBar, "⇄", "primary", {
            Position = UDim2.new(0.5, -18, 0, 1),
            Size = UDim2.fromOffset(36, 34),
            TextSize = 15,
            ZIndex = 74
        }, function()
            State.compareA, State.compareB = State.compareB, State.compareA
            boxA.Text = State.compareA
            boxB.Text = State.compareB
            update()
        end, State.tabConns)

        local boxB = inputBox(selectorBar, "Slot B item (e.g. Elderwood Scythe)...", State.compareB, {
            Position = UDim2.new(0.5, 26, 0, 0),
            Size = UDim2.new(0.5, -26, 0, 36),
            ZIndex = 74
        })

        local cardsGrid = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 294),
            BackgroundTransparency = 1,
            LayoutOrder = ord(),
            ZIndex = 72
        }, page)

        local panelA, headerA = Components.panel(cardsGrid, "LOADOUT SLOT A", "Primary evaluation target", {
            Size = UDim2.new(0.5, -7, 1, 0)
        })
        local bodyA = mk("Frame", {
            Position = UDim2.fromOffset(18, 54),
            Size = UDim2.new(1, -36, 1, -64),
            BackgroundTransparency = 1,
            ZIndex = 74
        }, panelA)

        local panelB, headerB = Components.panel(cardsGrid, "LOADOUT SLOT B", "Benchmark comparison target", {
            Position = UDim2.new(0.5, 7, 0, 0),
            Size = UDim2.new(0.5, -7, 1, 0)
        })
        local bodyB = mk("Frame", {
            Position = UDim2.fromOffset(18, 54),
            Size = UDim2.new(1, -36, 1, -64),
            BackgroundTransparency = 1,
            ZIndex = 74
        }, panelB)

        local summaryPanel = Components.panel(page, "VALUE SPREAD & RATIO", "Net comparison between Slot A and Slot B", {
            Size = UDim2.new(1, 0, 0, 126),
            LayoutOrder = ord()
        })
        local summaryBody = mk("Frame", {
            Position = UDim2.fromOffset(18, 54),
            Size = UDim2.new(1, -36, 0, 62),
            BackgroundTransparency = 1,
            ZIndex = 74
        }, summaryPanel)

        local function populateItem(headerObj, bodyObj, queryText)
            clearChildren(bodyObj)
            local titleLbl = headerObj:FindFirstChildOfClass("TextLabel")
            local row = Util.resolve(queryText)
            if not row then
                if titleLbl then titleLbl.Text = "UNRESOLVED ITEM" end
                Components.emptyState(
                    bodyObj,
                    Data.loaded and "ITEM NOT FOUND" or "SYNCING...",
                    "Type a valid MM2 weapon or pet name above.",
                    68
                )
                return nil
            end

            if titleLbl then titleLbl.Text = string.upper(row.name) end

            local changeStyle = "base"
            if row.change then
                changeStyle = row.change > 0 and "pos" or (row.change < 0 and "neg" or "base")
            end

            keybindRow(bodyObj, "SUPREME VALUE (SV)", formatVal(row.supreme) .. " SV", "base", 0)
            keybindRow(bodyObj, "MM2VALUES (MV)", formatVal(safeMM2(row)) .. " MV", "shield", 32)
            keybindRow(bodyObj, "CATEGORY", (row.category and row.category ~= "") and string.upper(row.category) or "ITEM", nil, 64)
            keybindRow(bodyObj, "DEMAND RATING", row.demand and (formatVal(row.demand) .. " / 10") or "—", nil, 96)
            keybindRow(bodyObj, "RARITY TIER", row.rarity and (formatVal(row.rarity) .. " / 10") or "—", nil, 128)
            keybindRow(bodyObj, "RECENT CHANGE", row.change and Util.signed(row.change) or "—", changeStyle, 160)
            keybindRow(bodyObj, "STABILITY", (row.stability and row.stability ~= "") and string.upper(row.stability) or "—", nil, 192)
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
                local diffStyle = diffSV > 0 and "pos" or (diffSV < 0 and "neg" or "base")

                keybindRow(
                    summaryBody,
                    "NET SPREAD (" .. string.upper(a.name) .. " VS " .. string.upper(b.name) .. ")",
                    Util.signed(diffSV) .. " SV  (" .. string.format("%+.1f%%", pct) .. ")",
                    diffStyle,
                    0
                )
                keybindRow(
                    summaryBody,
                    "MULTIPLIER RATIO",
                    string.format("%.2f x", ratio),
                    "shield",
                    32
                )
            else
                label(summaryBody, "Select two priced items above to compute exact value spread.", {
                    Size = UDim2.new(1, 0, 0, 24),
                    TextSize = 12,
                    TextColor3 = FN.textMuted,
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
    -- TAB 4: LOCKER / PORTFOLIO MANAGER
    -- ========================================================================
    Tabs.Inventory = function(page)
        local kpiRow = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 102),
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
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundTransparency = 1,
            LayoutOrder = ord(),
            ZIndex = 73
        }, page)

        local nameBox = inputBox(actionBar, "Add item to Locker (e.g. Corrupt, Gingerscope)...", State.invQuery, {
            Size = UDim2.fromOffset(310, 34),
            ZIndex = 74
        })
        local qtyBox = inputBox(actionBar, "Qty", State.invQty, {
            Position = UDim2.fromOffset(318, 0),
            Size = UDim2.fromOffset(64, 34),
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 74
        })

        local render

        button(actionBar, "SAVE TO LOCKER", "primary", {
            Position = UDim2.fromOffset(390, 0),
            Size = UDim2.fromOffset(124, 34),
            TextSize = 11,
            ZIndex = 75
        }, function()
            local row = Util.resolve(State.invQuery)
            if not row then
                notify("ITEM NOT FOUND", "Enter a valid MM2 item name", FN.warn)
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
                    notify("LOCKER FULL", "Maximum 60 unique stacks", FN.warn)
                    return
                end
                Prefs.myItems[#Prefs.myItems + 1] = {name = row.name, qty = qty}
            end
            Store.savePrefs()
            nameBox.Text = ""
            State.invQuery = ""
            notify("LOADOUT SAVED", row.name .. " (x" .. qty .. ") added to Locker", FN.pos)
            render()
        end, State.tabConns)

        local filterBox = inputBox(actionBar, "Filter Locker...", State.invFilter, {
            Position = UDim2.new(1, -200, 0, 0),
            Size = UDim2.fromOffset(200, 34),
            ZIndex = 74
        })

        attach(nameBox:GetPropertyChangedSignal("Text"), function() State.invQuery = nameBox.Text end, State.tabConns)
        attach(qtyBox:GetPropertyChangedSignal("Text"), function() State.invQty = qtyBox.Text end, State.tabConns)
        attach(filterBox:GetPropertyChangedSignal("Text"), function()
            State.invFilter = filterBox.Text
            render()
        end, State.tabConns)

        local holdingsCard = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 180),
            BackgroundColor3 = FN.cardBg,
            BorderSizePixel = 0,
            LayoutOrder = ord(),
            ClipsDescendants = true,
            ZIndex = 73
        }, page)
        corner(holdingsCard, 8)
        borderStroke(holdingsCard, FN.borderBlue, 0.2, 2)

        render = function()
            clearChildren(kpiRow)
            clearChildren(holdingsCard)

            local stats = Selectors.getPortfolioStats()

            Components.statCard(kpiRow, {
                order = 1,
                size = UDim2.new(0.333, -8, 1, 0),
                title = "Total Supreme Valuation",
                rarityColor = FN.rarityLegendary,
                numberStyle = "base",
                numericValue = stats.totalSV,
                suffix = stats.missingSV > 0 and "+? SV" or " SV",
                subtitle = "Primary Market Value"
            })

            Components.statCard(kpiRow, {
                order = 2,
                size = UDim2.new(0.333, -8, 1, 0),
                title = "Total MM2Values Valuation",
                rarityColor = FN.rarityRare,
                numberStyle = "shield",
                numericValue = stats.totalMV,
                suffix = stats.missingMV > 0 and "+? MV" or " MV",
                subtitle = "Secondary Shield Value"
            })

            Components.statCard(kpiRow, {
                order = 3,
                size = UDim2.new(0.333, -8, 1, 0),
                title = "Locker Inventory Count",
                rarityColor = FN.rarityEpic,
                numberStyle = "gold",
                numericValue = stats.totalUnits,
                suffix = " ITEMS",
                subtitle = stats.stackCount .. " Unique Stacks"
            })

            if #stats.rows == 0 then
                holdingsCard.Size = UDim2.new(1, 0, 0, 180)
                Components.emptyState(
                    holdingsCard,
                    "YOUR LOCKER IS EMPTY",
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

            local HEAD_H = 34
            local ROW_H = 40
            local thead = mk("Frame", {
                Size = UDim2.new(1, 0, 0, HEAD_H),
                BackgroundColor3 = FN.footerDark,
                BorderSizePixel = 0,
                ZIndex = 74
            }, holdingsCard)

            label(thead, "ITEM", {Position = UDim2.fromOffset(18, 0), Size = UDim2.new(0.34, -18, 1, 0), Font = UI_FONT_BOLD, TextSize = 10, TextColor3 = FN.textMuted, ZIndex = 75})
            label(thead, "QUANTITY", {Position = UDim2.fromScale(0.34, 0), Size = UDim2.fromScale(0.18, 1), Font = UI_FONT_BOLD, TextSize = 10, TextColor3 = FN.textMuted, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 75})
            label(thead, "SUBTOTAL (SV)", {Position = UDim2.fromScale(0.52, 0), Size = UDim2.fromScale(0.18, 1), Font = UI_FONT_BOLD, TextSize = 10, TextColor3 = FN.white, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 75})
            label(thead, "SUBTOTAL (MV)", {Position = UDim2.fromScale(0.70, 0), Size = UDim2.fromScale(0.16, 1), Font = UI_FONT_BOLD, TextSize = 10, TextColor3 = FN.shieldFill, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 75})
            label(thead, "REMOVE", {Position = UDim2.new(1, -78, 0, 0), Size = UDim2.fromOffset(60, HEAD_H), Font = UI_FONT_BOLD, TextSize = 10, TextColor3 = FN.textMuted, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 75})

            if #visibleRows == 0 then
                holdingsCard.Size = UDim2.new(1, 0, 0, 180)
                Components.emptyState(holdingsCard, "NO MATCHING ITEMS", "Clear the Locker filter to view all items.", 60)
                return
            end

            for i, item in ipairs(visibleRows) do
                local y = HEAD_H + (i - 1) * ROW_H
                local tr = mk("Frame", {
                    Position = UDim2.fromOffset(0, y),
                    Size = UDim2.new(1, 0, 0, ROW_H),
                    BackgroundColor3 = FN.cardBg,
                    BorderSizePixel = 0,
                    ZIndex = 74
                }, holdingsCard)

                mk("Frame", {
                    Size = UDim2.new(0, 4, 1, 0),
                    BackgroundColor3 = item.rarityColor,
                    BorderSizePixel = 0,
                    ZIndex = 75
                }, tr)

                mk("Frame", {
                    Position = UDim2.new(0, 0, 1, -1),
                    Size = UDim2.new(1, 0, 0, 1),
                    BackgroundColor3 = FN.borderSoft,
                    BackgroundTransparency = 0.4,
                    BorderSizePixel = 0,
                    ZIndex = 75
                }, tr)

                label(tr, string.upper(item.name), {
                    Position = UDim2.fromOffset(18, 0),
                    Size = UDim2.new(0.34, -22, 1, 0),
                    Font = UI_FONT_BOLD,
                    TextSize = 12,
                    ZIndex = 75
                })

                local qtyWrap = mk("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.fromScale(0.43, 0.5),
                    Size = UDim2.fromOffset(96, 26),
                    BackgroundTransparency = 1,
                    ZIndex = 75
                }, tr)

                button(qtyWrap, "–", "white", {
                    Size = UDim2.fromOffset(26, 26),
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

                fnNumber(qtyWrap, tostring(item.qty), "base", {
                    Position = UDim2.fromOffset(28, 0),
                    Size = UDim2.fromOffset(40, 26),
                    TextSize = 15,
                    StrokeThickness = 2,
                    TextXAlignment = Enum.TextXAlignment.Center,
                    ZIndex = 76
                })

                button(qtyWrap, "+", "white", {
                    Position = UDim2.fromOffset(70, 0),
                    Size = UDim2.fromOffset(26, 26),
                    TextSize = 12,
                    ZIndex = 76
                }, function()
                    local entry = Prefs.myItems[item.index]
                    if not entry then return end
                    entry.qty = math.min(9999, (tonumber(entry.qty) or 1) + 1)
                    Store.savePrefs()
                    render()
                end, State.tabConns)

                fnNumber(tr, item.subtotalSV and (formatVal(item.subtotalSV) .. " SV") or "—", "base", {
                    Position = UDim2.fromScale(0.52, 0),
                    Size = UDim2.fromScale(0.18, 1),
                    TextSize = 15,
                    StrokeThickness = 2,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    ZIndex = 75
                })

                fnNumber(tr, item.subtotalMV and (formatVal(item.subtotalMV) .. " MV") or "—", "shield", {
                    Position = UDim2.fromScale(0.70, 0),
                    Size = UDim2.fromScale(0.16, 1),
                    TextSize = 15,
                    StrokeThickness = 2,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    ZIndex = 75
                })

                button(tr, "X", "danger", {
                    Position = UDim2.new(1, -48, 0, 7),
                    Size = UDim2.fromOffset(30, 26),
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
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundTransparency = 1,
            LayoutOrder = ord(),
            ZIndex = 73
        }, page)

        local setters = {}
        local chipX = 0
        for _, cat in ipairs({
            {id = "ANY",  label = "ANY AGES",        w = 88},
            {id = "AGE",  label = "15–18+ VERIFIED", w = 122},
            {id = "HIGH", label = "HIGH TIER",       w = 88},
            {id = "ALL",  label = "ALL SERVERS",     w = 96}
        }) do
            local b = mk("TextButton", {
                Text = cat.label,
                Position = UDim2.fromOffset(chipX, 1),
                Size = UDim2.fromOffset(cat.w, 32),
                BackgroundColor3 = FN.cardBg,
                TextColor3 = FN.textMuted,
                Font = UI_FONT_BOLD,
                TextSize = 10,
                AutoButtonColor = false,
                BorderSizePixel = 0,
                ZIndex = 74
            }, toolbar)
            corner(b, 5)
            local st = borderStroke(b, FN.borderSoft, 0.2, 1.5)

            setters[cat.id] = function(active)
                b.BackgroundColor3 = active and FN.white or FN.cardBg
                b.TextColor3 = active and FN.inkDark or FN.textMuted
                st.Color = active and FN.white or FN.borderSoft
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
            Size = UDim2.new(1, 0, 0, 340),
            BackgroundTransparency = 1,
            LayoutOrder = ord(),
            ZIndex = 72
        }, page)

        local footerBar = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundTransparency = 1,
            LayoutOrder = ord(),
            ZIndex = 73
        }, page)

        label(footerBar, "Private trading lobbies launch directly in your browser or Roblox app.", {
            Size = UDim2.new(1, -240, 1, 0),
            TextSize = 11,
            TextColor3 = FN.textMuted,
            ZIndex = 74
        })

        button(footerBar, "PREV", "white", {
            Position = UDim2.new(1, -206, 0, 3),
            Size = UDim2.fromOffset(64, 28),
            TextSize = 11,
            ZIndex = 75
        }, function()
            State.serverPage = math.max(1, State.serverPage - 1)
            render()
        end, State.tabConns)

        local pageLbl = fnNumber(footerBar, "1 / 1", "base", {
            Position = UDim2.new(1, -138, 0, 0),
            Size = UDim2.fromOffset(72, 34),
            TextSize = 14,
            StrokeThickness = 2,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 74
        })

        button(footerBar, "NEXT", "white", {
            Position = UDim2.new(1, -62, 0, 3),
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
                    Position = UDim2.new(col * 0.5, col == 1 and 7 or 0, 0, r * 68),
                    Size = UDim2.new(0.5, -7, 0, 58),
                    BackgroundColor3 = FN.cardBg,
                    BorderSizePixel = 0,
                    ZIndex = 73
                }, grid)
                corner(cardItem, 8)
                local st = borderStroke(cardItem, FN.borderBlue, 0.2, 1.5)

                attach(cardItem.MouseEnter, function()
                    Motion.spring(cardItem, {BackgroundColor3 = FN.cardHover}, 0.12)
                    st.Color = FN.white
                    st.Transparency = 0
                end, State.tabConns)
                attach(cardItem.MouseLeave, function()
                    Motion.spring(cardItem, {BackgroundColor3 = FN.cardBg}, 0.14)
                    st.Color = FN.borderBlue
                    st.Transparency = 0.2
                end, State.tabConns)

                label(cardItem, string.upper(s.label), {
                    Position = UDim2.fromOffset(16, 10),
                    Size = UDim2.new(1, -162, 0, 18),
                    Font = UI_FONT_BOLD,
                    TextSize = 12,
                    ZIndex = 74
                })

                label(cardItem, "PRIVATE VIP LOBBY #" .. s.number .. "  •  " .. s.category, {
                    Position = UDim2.fromOffset(16, 29),
                    Size = UDim2.new(1, -162, 0, 15),
                    TextSize = 10,
                    TextColor3 = FN.textMuted,
                    ZIndex = 74
                })

                button(cardItem, "COPY", "white", {
                    Position = UDim2.new(1, -138, 0.5, -14),
                    Size = UDim2.fromOffset(58, 28),
                    TextSize = 11,
                    ZIndex = 75
                }, function()
                    copyOrNotify(url, "SERVER LINK COPIED")
                end, State.tabConns)

                button(cardItem, "JOIN", "primary", {
                    Position = UDim2.new(1, -72, 0.5, -14),
                    Size = UDim2.fromOffset(58, 28),
                    TextSize = 11,
                    ZIndex = 75
                }, function()
                    openLink(url, s.label)
                end, State.tabConns)
            end

            grid.Size = UDim2.new(1, 0, 0, math.max(68, math.ceil(count / 2) * 68))
        end

        Motion.staggerIn({toolbar, grid}, 0.04)
        render()
    end

    -- ========================================================================
    -- TAB 6: SETTINGS (FORTNITE KEYBOARD CONTROLS LAYOUT 50674.jpg)
    -- ========================================================================
    Tabs.Settings = function(page)
        local currencyPanel = Components.panel(page, "CURRENCY DISPLAY MODE", "Choose which valuation system appears in trade slots", {
            Size = UDim2.new(1, 0, 0, 106),
            LayoutOrder = ord()
        })

        local modeBody = mk("Frame", {
            Position = UDim2.fromOffset(18, 56),
            Size = UDim2.new(1, -36, 0, 36),
            BackgroundTransparency = 1,
            ZIndex = 74
        }, currencyPanel)

        local currSetters = {}
        for _, cOpt in ipairs({
            {id = "BOTH", label = "SUPREME + MM2VALUES", x = 0,   w = 172},
            {id = "SV",   label = "SUPREME ONLY (SV)",   x = 180, w = 152},
            {id = "MV",   label = "MM2VALUES ONLY (MV)", x = 340, w = 166}
        }) do
            local b = mk("TextButton", {
                Text = cOpt.label,
                Position = UDim2.fromOffset(cOpt.x, 2),
                Size = UDim2.fromOffset(cOpt.w, 30),
                BackgroundColor3 = FN.cardAlt,
                TextColor3 = FN.textMuted,
                Font = UI_FONT_BOLD,
                TextSize = 10,
                AutoButtonColor = false,
                BorderSizePixel = 0,
                ZIndex = 75
            }, modeBody)
            corner(b, 5)
            local st = borderStroke(b, FN.borderSoft, 0.2, 1.5)

            currSetters[cOpt.id] = function(active)
                b.BackgroundColor3 = active and FN.white or FN.cardAlt
                b.TextColor3 = active and FN.inkDark or FN.textMuted
                st.Color = active and FN.white or FN.borderSoft
            end

            attach(b.MouseButton1Click, function()
                Prefs.currencyMode = cOpt.id
                Store.savePrefs()
                for id, fn in pairs(currSetters) do fn(id == cOpt.id) end
                if State.latestTrade then pcall(updateHud, State.latestTrade) end
            end, State.tabConns)
        end
        currSetters[Prefs.currencyMode](true)

        local behaviorPanel = Components.panel(page, "CONTROLS & OVERLAY BINDINGS", "Configure live trade evaluator, animations, and server-hop reload", {
            Size = UDim2.new(1, 0, 0, 286),
            LayoutOrder = ord()
        })

        local rows = {
            {title = "TRADE SLOT PRICE TAGS", desc = "Show outlined SV/MV damage-style values in trade slots", key = "showTags", onChange = function(v) if not v then Trade.hideTags() end end},
            {title = "COMPACT TRADE HUD", desc = "Condensed single-row trade evaluator overlay", key = "compact", onChange = function() UI.applyHudSize() end},
            {title = "SMOOTH UI MOTION", desc = "Spring transitions and staggered card entrances", key = "animations"},
            {title = "LOW POWER MODE", desc = "Slower background polling and reduced animations", key = "lowPower"},
            {title = "RELOAD AFTER TELEPORT", desc = "Automatically queue script on server hop", key = "autoQueue", onChange = function(v)
                if v and not Net.queueReload() then
                    notify("TELEPORT QUEUE", "Not supported by this executor", FN.warn)
                end
            end}
        }

        for i, item in ipairs(rows) do
            local ry = 54 + (i - 1) * 44
            local r = mk("Frame", {
                Position = UDim2.fromOffset(18, ry),
                Size = UDim2.new(1, -36, 0, 42),
                BackgroundTransparency = 1,
                ZIndex = 74
            }, behaviorPanel)

            if i < #rows then
                mk("Frame", {
                    Position = UDim2.new(0, 0, 1, -1),
                    Size = UDim2.new(1, 0, 0, 1),
                    BackgroundColor3 = FN.borderSoft,
                    BackgroundTransparency = 0.4,
                    BorderSizePixel = 0,
                    ZIndex = 75
                }, r)
            end

            label(r, item.title, {
                Size = UDim2.new(1, -80, 0, 18),
                Font = UI_FONT_BOLD,
                TextSize = 12,
                ZIndex = 75
            })
            label(r, item.desc, {
                Position = UDim2.fromOffset(0, 19),
                Size = UDim2.new(1, -80, 0, 15),
                TextSize = 11,
                TextColor3 = FN.textMuted,
                ZIndex = 75
            })

            local sw = toggleSwitch(r, Prefs[item.key], function(v)
                Prefs[item.key] = v
                Store.savePrefs()
                if item.onChange then pcall(item.onChange, v) end
            end, State.tabConns)
            sw.Position = UDim2.new(1, -66, 0.5, -13)
            sw.ZIndex = 75
        end

        local sysBar = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundTransparency = 1,
            LayoutOrder = ord(),
            ZIndex = 73
        }, page)

        button(sysBar, "RESTORE TO DEFAULT", "white", {
            Size = UDim2.fromOffset(156, 32),
            TextSize = 11,
            ZIndex = 75
        }, function()
            Prefs.hudX, Prefs.hudY, Prefs.btnX, Prefs.btnY = 16, 82, -1, 82
            UI.hud.Position = UDim2.fromOffset(16, 82)
            UI.launcher.Position = UDim2.fromOffset(math.max(16, State.screenSize.X - 150), 82)
            UI.win.Position = UDim2.fromScale(0.5, 0.5)
            Store.savePrefs()
            notify("LAYOUT RESTORED", "Dashboard, HUD, and button reset", FN.pos)
        end, State.tabConns)

        button(sysBar, "UNLOAD SCRIPT", "danger", {
            Position = UDim2.fromOffset(166, 0),
            Size = UDim2.fromOffset(124, 32),
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
        if Win.sectionHeading then
            Win.sectionHeading.Text = "MM2 CARBON  //  " .. string.upper(name)
        end
        local page = Win.newPage()
        local okTab, err = pcall(Tabs[name], page)
        if not okTab then
            warn("[Carbon] View '" .. name .. "' failed: " .. tostring(err))
            Components.emptyState(page, "RENDER ERROR", tostring(err):sub(1, 140), 40)
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
            Win.scale.Scale = math.clamp(math.min((State.screenSize.X - 16) / targetW, (State.screenSize.Y - 16) / targetH), 0.45, 1)
        end
        UI.hudScale.Scale = math.clamp((State.screenSize.X - 16) / 320, 0.65, 1)
        pcall(clampInto, UI.hud)
        pcall(clampInto, UI.launcher)
    end

    function UI.setWindow(visible)
        if visible then
            applyLayout()
            ensureFreshPrices(120)
            UI.win.Visible = true
            UI.selectTab(State.currentTab)
        else
            UI.win.Visible = false
        end
    end

    function UI.updateStatus()
        local color, text
        if not Data.loaded then
            color, text = FN.warn, "SYNCING..."
        elseif Data.lastError or Data.supremeStale then
            color, text = FN.warn, "CHECK FEED"
        else
            color, text = FN.pos, "LIVE (" .. #Data.itemsList .. ")"
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
    attach(UI.launcher.MouseEnter, function() Motion.spring(UI.launcher, {BackgroundColor3 = FN.cardHover}, 0.1) end)
    attach(UI.launcher.MouseLeave, function() Motion.spring(UI.launcher, {BackgroundColor3 = FN.cardBg}, 0.12) end)
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
        UI.launcher.Position = UDim2.fromOffset(math.max(16, State.screenSize.X - 150), Prefs.btnY)
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

    notify("MM2 CARBON READY", "Press " .. Config.TOGGLE_KEY.Name .. " or click CARBON", FN.pos)
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
        t.BackgroundColor3 = Color3.fromRGB(8, 34, 86)
        t.TextColor3 = Color3.fromRGB(255, 76, 92)
        t.TextWrapped = true
        t.TextSize = 12
        t.Font = Enum.Font.GothamBold
        t.Text = "CARBON ERROR\n" .. tostring(failure):sub(1, 240)
        t.Parent = g
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 8)
        c.Parent = t
    end)
end
