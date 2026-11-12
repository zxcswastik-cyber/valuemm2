-- MM2 CARBON X V9 | complete read-only Delta companion.
-- A user-supplied client overlay: no remote calls or trade automation.
local ok, failure = xpcall(function()
-- MM2 CARBON X V9 | Carbon Glass, read-only trading assistant | 2026-11-13
-- Place into your GitHub repository as MM2_Carbon_Trade_v8_Supreme.lua.
-- Delta-compatible direct execution: no giant nested loadstring.
local embeddedSource = nil
-- MM2 CARBON TRADE v8.0 SUPREME (read-only prices; user-initiated server join)
-- Shows prices AUTOMATICALLY on items placed in both MM2 trade offers.
-- No trade remotes, auto-accept, credential requests, or payment features.
-- Sources: periodically updated community Supreme CSV + older MM2Values archive.
-- Source code/data: https://github.com/yanaa-12/mm2-trading
--                   https://github.com/timez170/mm2-values
-- This is an unofficial companion UI. Prices are estimated trade values, not Robux.
-- Requires a Lua environment that can access PlayerGui and perform HTTP GET.

-- All official MM2 modes share the same Universe (GameId), but have
-- different PlaceIds. v5 returned here before even creating the GUI.
local MM2_UNIVERSE_ID = 66654135
local MAIN_PLACE_ID = 142823291
if tonumber(game.GameId) ~= MM2_UNIVERSE_ID and tonumber(game.PlaceId) ~= MAIN_PLACE_ID then
    warn("[MM2 Carbon] Unsupported experience: " .. tostring(game.GameId))
    return
end
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
if not player then return end
local playerGui = player:WaitForChild("PlayerGui")
for _,legacyName in ipairs({"MM2CarbonTradeV5", "MM2CarbonTradeV6", "MM2CarbonTradeV7", "MM2CarbonTradeV8", "MM2CarbonXV9"}) do
    local oldRoot = playerGui:FindFirstChild(legacyName)
    if oldRoot then pcall(function() oldRoot:Destroy() end) end
end

local env = (type(getgenv) == "function" and getgenv()) or _G
if type(env.MM2CarbonCleanup) == "function" then pcall(env.MM2CarbonCleanup) end
-- Remove the old standalone search menu if the v2 desk is still open.
if type(env.MM2ValueDeskCleanup) == "function" then
    pcall(env.MM2ValueDeskCleanup)
end
if type(env.MM2TradeValuesCleanup) == "function" then
    pcall(env.MM2TradeValuesCleanup)
end

local URL_SUPREME = "https://raw.githubusercontent.com/yanaa-12/mm2-trading/main/docs/data/latest.csv"
local URL_META = "https://raw.githubusercontent.com/yanaa-12/mm2-trading/main/docs/data/meta.json"
local URL_MM2 = "https://raw.githubusercontent.com/timez170/mm2-values/main/values.json"
local req = (type(syn) == "table" and syn.request)
    or (type(http) == "table" and http.request)
    or http_request or request
if type(req) ~= "function" then req = nil end

-- Carefully restrained carbon / glass palette. One warm-grey accent, no neon.
local C = {
    bg = Color3.fromRGB(20, 22, 24),
    raised = Color3.fromRGB(37, 40, 42),
    card = Color3.fromRGB(31, 34, 36),
    rim = Color3.fromRGB(108, 115, 116),
    fg = Color3.fromRGB(239, 238, 234),
    muted = Color3.fromRGB(159, 164, 163),
    soft = Color3.fromRGB(204, 207, 203),
    positive = Color3.fromRGB(168, 199, 181),
    negative = Color3.fromRGB(214, 167, 165),
    amber = Color3.fromRGB(218, 194, 156)
}

local function trim(s) return tostring(s or ""):match("^%s*(.-)%s*$") end
local function normalize(s)
    return trim(s):lower():gsub("[^%w]", "")
end
local function number(v)
    if type(v) == "string" then v = v:gsub(",", "") end
    local n = tonumber(v)
    if n and n >= 0 and n < 10000000000 and n == n then return n end
    return nil
end
local function format(n)
    if type(n) ~= "number" then return "?" end
    if n == math.floor(n) then return string.format("%.0f", n) end
    return string.format("%.1f", n)
end
local function gui(className, props, parent)
    local obj = Instance.new(className)
    for k, v in pairs(props) do obj[k] = v end
    obj.Parent = parent
    return obj
end
local function label(parent, name, size, pos, fontSize)
    local v = gui("TextLabel", {
        Name = name, BackgroundColor3 = C.bg, BackgroundTransparency = 0.14,
        BorderSizePixel = 0, Text = "", TextSize = fontSize,
        TextColor3 = C.fg, Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextScaled = false, TextTruncate = Enum.TextTruncate.AtEnd,
        Size = size, Position = pos, ZIndex = 90, Active = false,
        Visible = false
    }, parent)
    gui("UICorner", { CornerRadius = UDim.new(0, 4) }, v)
    return v
end

local function fetch(url)
    if req then
        local ok, response = pcall(req, {Url = url, Method = "GET", Headers = {Accept = "*/*"}})
        if ok and type(response) == "table" then
            local status = tonumber(response.StatusCode or response.Status or (response.Success and 200))
            local body = response.Body or response.body
            if status == 200 and type(body) == "string" and #body > 0 then return body end
        end
    end
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" and #body > 0 then return body end
    return nil
end
local function readJson(s)
    if type(s) ~= "string" then return nil end
    local ok, result = pcall(function() return HttpService:JSONDecode(s) end)
    return ok and type(result) == "table" and result or nil
end
local function csvFields(line)
    local fields, buf, quoted, i = {}, {}, false, 1
    while i <= #line do
        local char = line:sub(i, i)
        if char == '"' then
            if quoted and line:sub(i + 1, i + 1) == '"' then
                buf[#buf + 1] = '"'; i = i + 1
            else
                quoted = not quoted
            end
        elseif char == "," and not quoted then
            fields[#fields + 1] = table.concat(buf); buf = {}
        else
            buf[#buf + 1] = char
        end
        i = i + 1
    end
    if quoted then return nil end
    fields[#fields + 1] = table.concat(buf)
    return fields
end
local function parseSupreme(csv)
    if not csv then return nil end
    local data, count, isHeader = {}, 0, true
    for line in (csv .. "\n"):gmatch("(.-)\r?\n") do
        if isHeader then
            isHeader = false
            local cols = csvFields(line)
            if not cols or trim(cols[1]):lower() ~= "name" or trim(cols[3]):lower() ~= "value" then return nil end
        elseif line ~= "" then
            local fields = csvFields(line)
            if fields and #fields >= 7 then
                local name, value = trim(fields[1]), number(fields[3])
                if name ~= "" and value then
                    local k = normalize(name)
                    if k ~= "" then
                        data[k] = {name = name, supreme = value,
                            category = trim(fields[2]), demand = number(fields[4]), rarity = number(fields[5]),
                            change = tonumber(fields[6]), stability = trim(fields[7]),
                            origin = trim(fields[8] or "") }
                        count = count + 1
                    end
                end
            end
        end
    end
    if count < 10 then return nil end
    return data
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
                row.mm2 = number(item.mm2) -- Never use archive 'supreme' as current price
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
    local y,m,d = tostring(stamp or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")
    if not y then return nil end
    local ok, t = pcall(os.time, {year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12})
    if not ok or not t then return nil end
    return math.max(0, math.floor((os.time() - t) / 86400))
end

local alive = true
local created = {}
local index = {}
local loaded = false
local supremeStamp = "?"
local mm2Stamp = "?"
local supremeStale = true
local mm2Stale = true
local lastError = nil
local loading = false
local PRICE_CACHE = "MM2CarbonX_v9_prices.json"
local mirrorStamp = "?"
local priceListeners = {}
local function pricesChanged()
    for _,cb in ipairs(priceListeners) do pcall(cb) end
end
local function cleanup()
    alive = false
    for _, obj in ipairs(created) do
        pcall(function() obj:Destroy() end)
    end
    if env.MM2CarbonCleanup == cleanup then env.MM2CarbonCleanup = nil end
    if env.MM2TradeValuesCleanup == cleanup then env.MM2TradeValuesCleanup = nil end
    env.MM2CarbonState = nil
end
env.MM2CarbonCleanup = cleanup

local function commitPrices(sup, meta, archive, cacheTag)
    if type(sup) ~= "table" then return false end
    local haveSup = next(sup) ~= nil
    local haveMM2 = mergeArchive(sup, archive)
    if not (haveSup or haveMM2) then return false end
    index = sup
    loaded = true
    supremeStamp = haveSup and tostring(meta and meta.last_updated or "?"):sub(1,10) or "offline"
    mirrorStamp = supremeStamp
    mm2Stamp = haveMM2 and tostring(archive.updatedAt or "?"):sub(1,10) or "offline"
    local sd, md = ageDays(supremeStamp), ageDays(mm2Stamp)
    supremeStale = (not sd) or sd > 7
    mm2Stale = (not md) or md > 14
    lastError = cacheTag and "Offline snapshot in use" or (not haveSup and "Supreme snapshot unavailable" or nil)
    pricesChanged()
    return true
end
local function readPriceCache()
    if type(readfile) ~= "function" then return false end
    local ok, text = pcall(readfile, PRICE_CACHE)
    if not ok then return false end
    local obj = readJson(text)
    if not obj or type(obj.supreme) ~= "string" then return false end
    return commitPrices(parseSupreme(obj.supreme), obj.meta, obj.archive, true)
end
local function loadPrices()
    if loading or not alive then return end
    loading = true
    local csv = fetch(URL_SUPREME)
    local meta = readJson(fetch(URL_META))
    local archive = readJson(fetch(URL_MM2))
    if not archive then
        if type(readfile)=="function" then
            local ok,raw=pcall(readfile,PRICE_CACHE)
            if ok then local old=readJson(raw); if old then archive=old.archive end end
        end
    end
    if not alive then loading = false; return end
    local parsed = parseSupreme(csv)
    if not commitPrices(parsed,meta,archive,false) then
        lastError = "Sources unavailable — retaining previous data"
        if not loaded then readPriceCache() end
    else
        if csv and type(writefile)=="function" then
            pcall(function()
                writefile(PRICE_CACHE,HttpService:JSONEncode({supreme=csv,meta=meta,archive=archive}))
            end)
        end
    end
    loading=false
    pricesChanged()
end


local function track(obj)
    created[#created + 1] = obj
    return obj
end
local function find(parent, name)
    if not parent then return nil end
    return parent:FindFirstChild(name)
end
local function nested(parent, ...)
    local obj = parent
    for i = 1, select("#", ...) do
        obj = find(obj, select(i, ...))
        if not obj then return nil end
    end
    return obj
end
local function readable(slot)
    local v = nested(slot, "ItemName", "Label")
    if not v or not v:IsA("TextLabel") then return nil end
    local name = trim(v.Text)
    if name == "" then return nil end
    local chroma = nested(slot, "Tags", "Chroma")
    if chroma and chroma.Visible and not name:lower():match("^chroma%s") then
        name = "Chroma " .. name
    end
    local amountLabel = nested(slot, "Container", "Amount")
    local amount = 1
    if amountLabel and type(amountLabel.Text) == "string" then
        local digits = amountLabel.Text:match("[xX×]%s*(%d+)")
        amount = math.max(1, math.min(9999, tonumber(digits) or 1))
    end
    return name, amount
end
local function lookup(name)
    local k = normalize(name)
    local obj = index[k]
    if not obj and k:sub(1, 6) == "chroma" then
        -- Some lists name chromas as "Name (Chroma)" instead of "Chroma Name".
        obj = index[k:sub(7) .. "chroma"]
    end
    return obj
end
local function safeMM2(row)
    if not row or not row.mm2 then return nil end
    if row.supreme and row.mm2 > 10 and row.supreme > 10 then
        local a, b = math.max(row.mm2, row.supreme), math.min(row.mm2, row.supreme)
        if a / b > 8 then return nil end -- reject extreme, likely incorrect entries
    end
    return row.mm2
end
local function validScreen(screen)
    if not screen or not screen:IsA("ScreenGui") then return false end
    if screen.Enabled == false then return false end
    return true
end
local function isVisible(obj)
    while obj and obj ~= playerGui do
        if obj:IsA("GuiObject") and obj.Visible == false then return false end
        if obj:IsA("ScreenGui") and obj.Enabled == false then return false end
        obj = obj.Parent
    end
    return true
end

-- CARBON X V9. This section shares only the read-only data engine above.
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local modePlace = game.PlaceId
local currentJob = tostring(game.JobId or "")
local C9 = {
    bg=Color3.fromRGB(20,22,23),panel=Color3.fromRGB(29,32,34),surface=Color3.fromRGB(41,45,48),
    text=Color3.fromRGB(240,241,241),sub=Color3.fromRGB(163,170,173),border=Color3.fromRGB(65,71,74),
    good=Color3.fromRGB(166,199,179),bad=Color3.fromRGB(216,162,160),warm=Color3.fromRGB(210,195,165),
    white=Color3.fromRGB(229,232,231)
}
local CONFIG_FILE="MM2CarbonX_v9_settings.json"
local HISTORY_FILE="MM2CarbonX_v9_history.json"
local SIGHTINGS_FILE="MM2CarbonX_v9_sightings.json"
local OFFICIAL="https://supremevalues.com/mm2/trading"
local JOIN_PREFIX="https://www.roblox.com/games/142823291/Murder-Mystery-2?privateServerLinkCode="
local RELOAD_URL="https://raw.githubusercontent.com/zxcswastik-cyber/valuemm2/main/MM2_CARBON_X_V9.lua"
local prefs={animations=true,lowPower=false,compact=false,showTags=true,favs={},recent={},wishlist={},myItems={},hudX=12,hudY=82}
local history={}
local sightings={}
local statusText="Ready"
local latestTrade=nil
local tradeActive=false
local tradeTarget=nil
local tradeSignalCache={}
local scheduled=false
local activeOfferSig=""
local lastTradeSnapshot=nil
local activeWatch={}
local pendingSuccessId=0
local renderDetails, renderHub, renderInventory, renderHistory, renderSettings
local scheduleUpdate
local screenSize=Vector2.new(1280,720)
local allFrames={}
local function attach(signal,fn,bucket)
    local ok,connection=pcall(function() return signal:Connect(fn) end)
    if not ok or not connection then return nil end
    local bag=bucket or allFrames
    bag[#bag+1]=connection
    if not bucket then
        created[#created+1]={Destroy=function() pcall(function()connection:Disconnect()end) end}
    end
    return connection
end
local function disconnect(bag)
    for _,v in ipairs(bag) do pcall(function()v:Disconnect()end) end
    table.clear(bag)
end
local function jread(path)
    if type(readfile)~="function" then return nil end
    local ok,data=pcall(readfile,path)
    if not ok then return nil end
    return readJson(data)
end
local function jwrite(path,value)
    if type(writefile)~="function" then return false end
    local ok=pcall(function() writefile(path,HttpService:JSONEncode(value)) end)
    return ok
end
local rawPrefs=jread(CONFIG_FILE)
if type(rawPrefs)=="table" then
    for k,v in pairs(rawPrefs) do
        if k=="animations" or k=="lowPower" or k=="compact" or k=="showTags" then
            if type(v)=="boolean" then prefs[k]=v end
        elseif k=="hudX" or k=="hudY" then
            if type(v)=="number" and v>=0 and v<20000 then prefs[k]=v end
        elseif (k=="favs" or k=="wishlist" or k=="myItems") and type(v)=="table" then
            prefs[k]=v
        elseif k=="recent" and type(v)=="table" then
            prefs[k]=v
        end
    end
end
local storedSightings=jread(SIGHTINGS_FILE)
if type(storedSightings)=="table" then
    for key,item in pairs(storedSightings) do
        if type(key)=="string" and type(item)=="table" and item.jobId==currentJob and item.placeId==modePlace
            and type(item.at)=="number" and os.time()-item.at<1800 then
            sightings[key]=item
        end
    end
end
local rawHistory=jread(HISTORY_FILE)
if type(rawHistory)=="table" then
    for i=1,math.min(#rawHistory,100) do
        local h=rawHistory[i]
        if type(h)=="table" and type(h.at)=="number" and (h.status=="CONFIRMED" or h.status=="UNCONFIRMED") then
            history[#history+1]=h
        end
    end
end
local function savePrefs() jwrite(CONFIG_FILE,prefs) end
local function addHistory(h)
    table.insert(history,1,h)
    while #history>100 do table.remove(history) end
    jwrite(HISTORY_FILE,history)
end
local function setStatus(s)
    statusText=tostring(s or "")
end
local function mk(kind,props,parent)
    local x=Instance.new(kind)
    for key,value in pairs(props or {}) do x[key]=value end
    x.Parent=parent
    return x
end
local function corner(frame,r)
    return mk("UICorner",{CornerRadius=UDim.new(0,r or 12)},frame)
end
local function outline(frame,alpha)
    return mk("UIStroke",{Thickness=1,Color=C9.border,Transparency=alpha or .25},frame)
end
local function ease(obj,properties,duration)
    if not prefs.animations then
        for k,v in pairs(properties) do pcall(function()obj[k]=v end) end
        return
    end
    pcall(function()
        TweenService:Create(obj,TweenInfo.new(duration or .15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),properties):Play()
    end)
end
local function frame(parent,name,pos,size,color,trans,z)
    local f=mk("Frame",{Name=name,Position=pos,Size=size,BackgroundColor3=color or C9.panel,
        BackgroundTransparency=trans or 0,BorderSizePixel=0,ZIndex=z or 20},parent)
    corner(f,12);outline(f,.35)
    return f
end
local function txt(parent,name,value,pos,size,font,weight,color,align,z)
    return mk("TextLabel",{Name=name,BackgroundTransparency=1,Text=tostring(value or ""),
        Position=pos,Size=size,Font=weight and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextSize=font or 12,TextColor3=color or C9.text,TextXAlignment=align or Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Center,TextTruncate=Enum.TextTruncate.AtEnd,
        BorderSizePixel=0,ZIndex=z or 25},parent)
end
local function btn(parent,name,label,pos,size,style,fn,bucket)
    local primary=style=="primary"
    local quiet=style=="quiet"
    local b=mk("TextButton",{Name=name,Text=tostring(label or ""),Position=pos,Size=size,
        Font=Enum.Font.GothamBold,TextSize=11,TextTruncate=Enum.TextTruncate.AtEnd,
        TextColor3=primary and C9.bg or (quiet and C9.sub or C9.text),
        BackgroundColor3=primary and C9.white or (quiet and C9.bg or C9.surface),
        BackgroundTransparency=quiet and .4 or (primary and 0 or .08),
        BorderSizePixel=0,AutoButtonColor=false,Active=true,ZIndex=34},parent)
    corner(b,9)
    if not quiet then outline(b,primary and .85 or .4) end
    if fn then attach(b.MouseButton1Click,function()
        if alive then fn() end
    end,bucket) end
    return b
end
local function input(parent,name,placeholder,pos,size)
    local i=mk("TextBox",{Name=name,Text="",PlaceholderText=placeholder,ClearTextOnFocus=false,
        Position=pos,Size=size,BackgroundColor3=C9.surface,BackgroundTransparency=.08,
        TextColor3=C9.text,PlaceholderColor3=C9.sub,Font=Enum.Font.Gotham,TextSize=12,
        TextXAlignment=Enum.TextXAlignment.Left,BorderSizePixel=0,ZIndex=32},parent)
    corner(i,9);outline(i,.6)
    return i
end
local function rule(parent,y)
    mk("Frame",{Size=UDim2.new(1,-28,0,1),Position=UDim2.new(0,14,0,y),
        BackgroundColor3=C9.border,BackgroundTransparency=.42,BorderSizePixel=0,ZIndex=25},parent)
end
local function paste(url)
    local f=(type(setclipboard)=="function" and setclipboard) or
        (type(toclipboard)=="function" and toclipboard)
    if type(f)~="function" then return false end
    return pcall(f,url)
end
local function openURL(url)
    if type(url)~="string" or not url:match("^https://") then return false end
    for _,candidate in ipairs({
        type(openurl)=="function" and openurl or false,
        type(open_url)=="function" and open_url or false,
        type(openbrowser)=="function" and openbrowser or false
    }) do
        if type(candidate)=="function" then
            local ok,result=pcall(candidate,url)
            if ok and result~=false then return true end
        end
    end
    return pcall(function()GuiService:OpenBrowserWindow(url)end)
end
local function shiftPanel(panel,handle,callback)
    local down=nil;local start=nil;local original=nil
    attach(handle.InputBegan,function(t)
        if t.UserInputType==Enum.UserInputType.Touch or t.UserInputType==Enum.UserInputType.MouseButton1 then
            down=t;start=t.Position;original=panel.Position
            attach(t.Changed,function()
                if t.UserInputState==Enum.UserInputState.End then
                    down=nil
                    if callback then pcall(callback) end
                end
            end)
        end
    end)
    attach(UserInputService.InputChanged,function(t)
        if not down or not start or not original then return end
        if t.UserInputType~=Enum.UserInputType.MouseMovement and t~=down then return end
        local delta=t.Position-start
        local x=math.max(0,math.min(screenSize.X-75,original.X.Offset+delta.X))
        local y=math.max(0,math.min(screenSize.Y-45,original.Y.Offset+delta.Y))
        panel.Position=UDim2.fromOffset(x,y)
    end)
end

local root=track(mk("ScreenGui",{Name="MM2CarbonXV9",ResetOnSpawn=false,IgnoreGuiInset=false,
    DisplayOrder=3900,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},playerGui))
local toast=frame(root,"Toast",UDim2.new(1,-276,0,64),UDim2.fromOffset(260,49),C9.panel,.03,70)
toast.Visible=false
local toastTitle=txt(toast,"Title","",UDim2.new(0,12,0,7),UDim2.new(1,-24,0,18),12,true,C9.good,Enum.TextXAlignment.Left,78)
local toastBody=txt(toast,"Body","",UDim2.new(0,12,0,25),UDim2.new(1,-24,0,17),10,false,C9.sub,Enum.TextXAlignment.Left,78)
local toastID=0
local function notify(title,body,tint)
    toastID=toastID+1
    local id=toastID
    toastTitle.Text=tostring(title or "CARBON X")
    toastTitle.TextColor3=tint or C9.good
    toastBody.Text=tostring(body or "")
    toast.Visible=true
    if not prefs.lowPower then
        toast.BackgroundTransparency=.65
        ease(toast,{BackgroundTransparency=.03},.16)
    end
    task.delay(2,function() if alive and toastID==id then toast.Visible=false end end)
end
-- HUD is never a modal overlay; by default it sits at the top edge.
local hud=frame(root,"TradeHUD",UDim2.fromOffset(prefs.hudX,prefs.hudY),UDim2.fromOffset(276,112),C9.bg,.09,40)
hud.Visible=false
local hudScale=mk("UIScale",{Scale=1},hud)
local hudHeading=txt(hud,"Heading","●  CARBON  /  LIVE TRADE",UDim2.fromOffset(12,6),UDim2.new(1,-58,0,23),11,true,C9.good)
hudHeading.Active=true
local hudToggle=btn(hud,"Collapse","−",UDim2.new(1,-35,0,5),UDim2.fromOffset(27,26),"quiet")
local hudYou=txt(hud,"You","YOU      S —     M —",UDim2.fromOffset(13,34),UDim2.new(1,-26,0,23),12,true,C9.text)
local hudThem=txt(hud,"Them","THEM    S —     M —",UDim2.fromOffset(13,58),UDim2.new(1,-26,0,22),12,true,C9.text)
local hudDiff=txt(hud,"Difference","DIFF  —",UDim2.fromOffset(13,82),UDim2.new(1,-26,0,22),12,true,C9.sub)
local hudWarn=txt(hud,"Warning","",UDim2.fromOffset(13,104),UDim2.new(1,-26,0,17),10,true,C9.warm)
local hudSmall=false
attach(hudToggle.MouseButton1Click,function()
    hudSmall=not hudSmall
    hud.Size=UDim2.fromOffset(276,hudSmall and 34 or (hudWarn.Text~="" and 124 or 112))
    for _,e in ipairs({hudYou,hudThem,hudDiff,hudWarn})do e.Visible=not hudSmall end
    hudToggle.Text=hudSmall and "+" or "−"
end)
shiftPanel(hud,hudHeading,function()
    prefs.hudX=math.floor(hud.Position.X.Offset)
    prefs.hudY=math.floor(hud.Position.Y.Offset)
    savePrefs()
end)
-- Compact floating trigger; no full menu remains visible during trade.
local launcher=btn(root,"CarbonLauncher","◇",UDim2.new(1,-55,0,82),UDim2.fromOffset(40,40),"primary")
launcher.TextSize=20
local quick=frame(root,"QuickPanel",UDim2.new(1,-247,0,129),UDim2.fromOffset(232,252),C9.bg,.04,42)
quick.Visible=false
local qTitle=txt(quick,"Title","CARBON X   /   V9",UDim2.fromOffset(13,10),UDim2.new(1,-26,0,24),13,true)
rule(quick,39)
local panel=frame(root,"Workspace",UDim2.new(.5,-233,.5,-255),UDim2.fromOffset(466,510),C9.bg,.04,42)
panel.Visible=false
panel.AnchorPoint=Vector2.new(.5,.5)
panel.Position=UDim2.new(.5,0,.5,0)
local panelScale=mk("UIScale",{Scale=1},panel)
local topName=txt(panel,"Header","CARBON  /  TRADE INTELLIGENCE",UDim2.fromOffset(17,10),UDim2.new(1,-67,0,25),13,true)
topName.Active=true
local topSub=txt(panel,"Version","V9  ·  READ-ONLY  ·  MM2",UDim2.fromOffset(17,34),UDim2.new(1,-80,0,18),10,false,C9.sub)
btn(panel,"Close","×",UDim2.new(1,-45,0,12),UDim2.fromOffset(29,28),"quiet",function()panel.Visible=false end)
rule(panel,61)
local tabNames={"TRADE","SERVERS","INVENTORY","HISTORY","SETTINGS"}
local tabButtons={}
local currentTab="TRADE"
local activeUI={}
local tabX=13
for i,tab in ipairs(tabNames) do
    local width=tab=="INVENTORY" and 90 or (tab=="SETTINGS" and 79 or (tab=="SERVERS" and 79 or 75))
    tabButtons[i]=btn(panel,"Tab"..tab,tab,UDim2.fromOffset(tabX,70),UDim2.fromOffset(width,31),"quiet")
    tabX=tabX+width+3
end
local content=mk("ScrollingFrame",{Name="Content",Position=UDim2.fromOffset(13,111),Size=UDim2.new(1,-26,1,-151),
    BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=2,ScrollBarImageColor3=C9.border,
    CanvasSize=UDim2.fromOffset(0,0),ScrollingDirection=Enum.ScrollingDirection.Y,
    ZIndex=29,ClipsDescendants=true},panel)
local footer=txt(panel,"Footer","SUPREME: WAITING   ·   MM2: WAITING",UDim2.fromOffset(17,477),UDim2.new(1,-34,0,20),10,false,C9.sub)
local function clearContent()
    disconnect(activeUI)
    for _,obj in ipairs(content:GetChildren()) do obj:Destroy() end
    content.CanvasPosition=Vector2.new(0,0)
end
local function height(y)
    content.CanvasSize=UDim2.fromOffset(0,math.max(363,y+18))
end
local function headline(title,sub,y)
    txt(content,"Heading",title,UDim2.fromOffset(4,y),UDim2.new(1,-8,0,26),15,true)
    if sub then txt(content,"Subtitle",sub,UDim2.fromOffset(4,y+26),UDim2.new(1,-8,0,22),11,false,C9.sub) end
end
local function card(y,h)
    return frame(content,"ContentCard",UDim2.fromOffset(1,y),UDim2.new(1,-3,0,h),C9.panel,.06,31)
end
local function setTab(tab)
    currentTab=tab
    for i,name in ipairs(tabNames) do
        local b=tabButtons[i]
        local selected=name==tab
        b.TextColor3=selected and C9.bg or C9.sub
        b.BackgroundColor3=selected and C9.white or C9.surface
        b.BackgroundTransparency=selected and 0 or .45
    end
    clearContent()
    if tab=="TRADE" then renderDetails()
    elseif tab=="SERVERS" then renderHub()
    elseif tab=="INVENTORY" then renderInventory()
    elseif tab=="HISTORY" then renderHistory()
    else renderSettings() end
end
for i,name in ipairs(tabNames) do
    attach(tabButtons[i].MouseButton1Click,function()setTab(name)end)
end
for i,name in ipairs({"TRADE","SERVERS","INVENTORY","HISTORY","SETTINGS"}) do
    btn(quick,"Quick"..name,name,UDim2.fromOffset(11,46+(i-1)*39),UDim2.new(1,-22,0,33),"secondary",function()
        quick.Visible=false
        panel.Visible=true
        setTab(name)
    end)
end
attach(launcher.MouseButton1Click,function()
    quick.Visible=not quick.Visible
    if quick.Visible then panel.Visible=false end
end)
local function fit()
    local ok,sz=pcall(function() return workspace.CurrentCamera.ViewportSize end)
    if not ok or not sz then return end
    screenSize=sz
    panelScale.Scale=math.max(.35,math.min(1,(sz.X-16)/466,(sz.Y-30)/510))
    hudScale.Scale=math.max(.35,math.min(1,(sz.X-20)/276))
    if hud.Position.X.Offset>sz.X-60 or hud.Position.Y.Offset>sz.Y-34 then
        hud.Position=UDim2.fromOffset(10,math.min(82,sz.Y-40))
    end
end
fit()
if workspace.CurrentCamera then
    attach(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"),fit)
end
-- NOTE: v8 links are kept as an explicitly dated, unverified-for-availability fallback.
local staticServers={
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
    {number=75,category="HIGH",label="High Tier #75",code="35319767785001568708602910095273"},
}
local serverList=staticServers
local serverStamp="V8 FALLBACK"
local selectedCategory="ANY"
local selectedPage=1
local selectedUrl=""
local function serverKey(s)return tostring(s.number)end
local function linkFor(s)
    return JOIN_PREFIX..tostring(s.code or "")
end
local function parseOfficial(html)
    if type(html)~="string" then return nil end
    local items={};local used={}
    -- Each regex candidate is restricted to the documented Roblox share-link shape.
    for tag,inside in html:gmatch("(<a[%s][^>]->)(.-)</a>") do
        local href=tag:match('href%s*=%s*"([^"]+)"') or tag:match("href%s*=%s*'([^']+)'")
        if href and href:find("privateServerLinkCode=",1,true) then
            href=href:gsub("&amp;","&")
            local code=href:match("privateServerLinkCode=([%d]+)")
            local numberText=inside:match("%[#(%d+)%]")
            local no=tonumber(numberText)
            if no and no>=1 and no<=200 and code and #code==32 and not used[no] then
                local category=no>=71 and "HIGH" or (no>=56 and "AGE" or "ANY")
                items[#items+1]={number=no,category=category,code=code,label=(category=="HIGH" and "High Tier #" or (category=="AGE" and "Age Group #" or "Any Ages #"))..no}
                used[no]=true
            end
        end
    end
    if #items<10 then return nil end
    table.sort(items,function(a,b)return a.number<b.number end)
    return items
end
local function syncServers()
    local html=fetch(OFFICIAL)
    if not alive then return end
    local parsed=parseOfficial(html)
    if parsed then
        serverList=parsed
        serverStamp=os.date("!%Y-%m-%d %H:%M UTC").." · SITE HTML"
        notify("SERVER LIST UPDATED",tostring(#parsed).." invites from Supreme")
    else
        notify("SERVER LIST UNAVAILABLE","Using V8 fallback; verify on website",C9.warm)
    end
    if panel.Visible and currentTab=="SERVERS" then setTab("SERVERS") end
end
local function addRecent(s)
    if not s then return end
    for i=#prefs.recent,1,-1 do
        if tostring(prefs.recent[i])==serverKey(s) then table.remove(prefs.recent,i) end
    end
    table.insert(prefs.recent,1,serverKey(s))
    while #prefs.recent>12 do table.remove(prefs.recent) end
    savePrefs()
end
local function join(s)
    if not s or type(s.code)~="string" or #s.code~=32 or not s.code:match("^%d+$") then
        notify("LINK UNKNOWN","Open the official Supreme directory",C9.warm)
        return
    end
    local url=linkFor(s)
    selectedUrl=url
    local field=content:FindFirstChild("Invite")
    if field and field:IsA("TextBox") then field.Text=url end
    addRecent(s)
    -- PrivateServerLinkCode is not a TeleportToPrivateServer access code.
    local opened=openURL(url)
    local copied=paste(url)
    notify(opened and "OPENING INVITE" or (copied and "LINK COPIED" or "COPY MANUALLY"),
        s.label.." · "..(opened and "Roblox link" or "See invite field"),opened and C9.good or C9.warm)
end
local function isFav(s)return prefs.favs[serverKey(s)]==true end
local function getServers()
    local out={}
    for _,s in ipairs(serverList) do
        local match=(selectedCategory=="ANY" and s.category=="ANY") or
            (selectedCategory=="AGE" and s.category=="AGE") or
            (selectedCategory=="HIGH" and s.category=="HIGH") or
            (selectedCategory=="FAV" and isFav(s))
        if match then out[#out+1]=s end
    end
    if selectedCategory=="RECENT" then
        for _,id in ipairs(prefs.recent) do
            for _,s in ipairs(serverList) do if serverKey(s)==tostring(id) then out[#out+1]=s;break end end
        end
    end
    return out
end
renderHub=function()
    headline("SUPREME SERVER HUB","Private server invites · occupancy unknown",0)
    local filterNames={{"ANY","ANY"},{"AGE","AGE"},{"HIGH","HIGH"},{"FAV","SAVED"},{"RECENT","RECENT"}}
    for i,g in ipairs(filterNames) do
        local x=2+(i-1)*86
        local b=btn(content,"ServerTab"..g[1],g[2],UDim2.fromOffset(x,54),UDim2.fromOffset(83,29),
            selectedCategory==g[1] and "primary" or "quiet",function()
                selectedCategory=g[1];selectedPage=1;setTab("SERVERS")
            end,activeUI)
    end
    local title=txt(content,"Source",serverStamp,UDim2.fromOffset(5,87),UDim2.new(1,-10,0,23),10,false,C9.sub)
    local view=getServers()
    local maxPage=math.max(1,math.ceil(#view/3))
    selectedPage=math.min(selectedPage,maxPage)
    for i=1,3 do
        local s=view[(selectedPage-1)*3+i]
        if s then
            local y=116+(i-1)*65
            local f=card(y,60)
            txt(f,"Server",s.label,UDim2.fromOffset(13,7),UDim2.new(1,-135,0,22),12,true)
            txt(f,"Meta",s.category=="HIGH" and "High tiers only · rules apply" or "Supreme private invite",UDim2.fromOffset(13,29),UDim2.new(1,-135,0,17),10,false,C9.sub)
            btn(f,"Favorite",isFav(s) and "★" or "☆",UDim2.new(1,-111,0,13),UDim2.fromOffset(31,33),"quiet",function()
                prefs.favs[serverKey(s)]=not isFav(s) or nil
                savePrefs();setTab("SERVERS")
            end,activeUI)
            btn(f,"Join","JOIN ↗",UDim2.new(1,-76,0,12),UDim2.fromOffset(66,35),"primary",function()join(s)end,activeUI)
        end
    end
    btn(content,"Prev","‹ PREV",UDim2.fromOffset(3,315),UDim2.fromOffset(80,30),"secondary",function()
        selectedPage=math.max(1,selectedPage-1);setTab("SERVERS")
    end,activeUI)
    txt(content,"Page",tostring(selectedPage).." / "..tostring(maxPage).."  ·  "..#view.." listed",UDim2.fromOffset(101,317),UDim2.fromOffset(158,26),10,false,C9.sub,Enum.TextXAlignment.Center)
    btn(content,"Next","NEXT ›",UDim2.new(1,-86,0,315),UDim2.fromOffset(82,30),"secondary",function()
        selectedPage=math.min(maxPage,selectedPage+1);setTab("SERVERS")
    end,activeUI)
    local selected=input(content,"Invite","  Select a server to get its link",UDim2.fromOffset(3,356),UDim2.new(1,-90,0,32))
    selected.Text=selectedUrl
    btn(content,"Copy","COPY",UDim2.new(1,-84,0,356),UDim2.fromOffset(80,32),"primary",function()
        local url=trim(selected.Text)
        if url:find("^https://www%.roblox%.com/games/142823291/") or url==OFFICIAL then
            notify(paste(url) and "COPIED" or "COPY MANUALLY",url:sub(1,54))
        else notify("NO VALID INVITE","Select an entry first",C9.warm) end
    end,activeUI)
    btn(content,"OfficialSite","SUPREME DIRECTORY ↗",UDim2.fromOffset(3,396),UDim2.fromOffset(199,34),"secondary",function()
        selectedUrl=OFFICIAL
        if not openURL(OFFICIAL) and paste(OFFICIAL) then notify("SITE LINK COPIED","Open in your browser") end
    end,activeUI)
    btn(content,"Sync","SYNC",UDim2.fromOffset(211,396),UDim2.fromOffset(77,34),"quiet",function()
        notify("CHECKING LINKS","Attempting HTML refresh")
        task.spawn(syncServers)
    end,activeUI)
    local found={}
    for _,entry in pairs(sightings) do
        if os.time()-entry.at<3600 then found[#found+1]=entry end
    end
    table.sort(found,function(a,b)return a.value>b.value end)
    txt(content,"ObservedTitle","OBSERVED HERE  ·  "..#found.." rare items",UDim2.fromOffset(5,441),UDim2.new(1,-10,0,20),10,true,C9.sub)
    local iy=466
    for i=1,math.min(3,#found) do
        local it=found[i]
        txt(content,"Sight"..i,it.name.."  ·  S "..format(it.value).."  /  "..it.source,UDim2.fromOffset(5,iy),UDim2.new(1,-10,0,23),11,false,C9.text)
        iy=iy+26
    end
    if #found==0 then
        txt(content,"NoSight","No verified equipped/trade items seen in this server",UDim2.fromOffset(5,iy),UDim2.new(1,-10,0,24),10,false,C9.sub)
        iy=iy+27
    end
    height(iy+8)
end
local function valueLine(row)
    if not row then return "S UNKNOWN    /    M UNKNOWN" end
    return "S "..format(row.supreme).."    /    M "..format(safeMM2(row))
end
local function diffSummary(own,theirs,source)
    local missingKey=(source=="supreme") and "missingSupreme" or "missingMm2"
    if not own or not theirs or (own[missingKey] or 0)>0 or (theirs[missingKey] or 0)>0 then return "UNKNOWN",nil end
    local n=theirs[source]-own[source]
    local p=(own[source]>0) and (100*n/own[source]) or nil
    return (n>0 and "+" or "")..format(n)..(p and ("  ("..string.format("%+.1f",p).."%)") or ""),n
end
local function displayNumber(n,missing)
    if (missing or 0)>0 then return format(n).."+?" end
    return format(n)
end
local function emptySide()
    return {supreme=0,mm2=0,missingSupreme=0,missingMm2=0,items={},demandSum=0,demandCount=0}
end
local function aggregate(items)
    local out=emptySide()
    for _,item in ipairs(items or {}) do
        local cnt=tonumber(item.count) or 1
        cnt=math.max(1,math.min(9999,math.floor(cnt)))
        local row=lookup(item.name)
        local s=row and row.supreme
        local m=safeMM2(row)
        out.items[#out.items+1]={name=item.name,count=cnt,s=s,m=m,demand=row and row.demand,category=row and row.category,stability=row and row.stability}
        if s then out.supreme=out.supreme+s*cnt else out.missingSupreme=out.missingSupreme+cnt end
        if m then out.mm2=out.mm2+m*cnt else out.missingMm2=out.missingMm2+cnt end
        if row and row.demand then out.demandSum=out.demandSum+row.demand*cnt;out.demandCount=out.demandCount+cnt end
    end
    return out
end
local function formatOffer(items)
    local names={}
    for _,it in ipairs(items or {}) do
        names[#names+1]=tostring(it.name).." x"..tostring(it.count or 1)
    end
    return #names>0 and table.concat(names,", ") or "(empty)"
end
local function offerFingerprint(items)
    local rows={}
    for _,it in ipairs(items or {}) do
        rows[#rows+1]=normalize(it.name)..":"..tostring(it.count or 1)
    end
    table.sort(rows)
    return table.concat(rows,"|")
end
local function offerToList(offer)
    local result={}
    if not offer then return result end
    local cont=find(offer,"Container") or offer
    for n=1,4 do
        local slot=find(cont,"NewItem"..n) or find(offer,"NewItem"..n)
        if slot and isVisible(slot) then
            local name,count=readable(slot)
            if name then result[#result+1]={name=name,count=count,slot=slot} end
        end
    end
    return result
end
local badges=setmetatable({}, {__mode="k"})
local function itemBadge(slot)
    local badge=badges[slot]
    if badge and badge.Parent==slot then return badge end
    if not slot:IsA("GuiObject") then return nil end
    badge=mk("TextLabel",{Name="CarbonXValueTag",AnchorPoint=Vector2.new(1,1),
        Position=UDim2.new(1,-2,1,-2),Size=UDim2.fromOffset(94,17),BackgroundColor3=C9.bg,
        BackgroundTransparency=.08,TextColor3=C9.text,Font=Enum.Font.GothamBold,
        TextSize=9,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=82,Visible=false,Active=false,
        TextXAlignment=Enum.TextXAlignment.Center,BorderSizePixel=0},slot)
    corner(badge,5)
    badges[slot]=badge
    created[#created+1]=badge
    return badge
end
local function showTags(list)
    for _,e in ipairs(list) do
        local badge=itemBadge(e.slot)
        if badge then
            badge.Visible=prefs.showTags
            local row=lookup(e.name)
            if e.slot.AbsoluteSize.X<92 then
                badge.Size=UDim2.fromOffset(math.max(45,math.floor(e.slot.AbsoluteSize.X)-3),16)
                badge.Text="S "..format(row and row.supreme)
            else
                badge.Size=UDim2.fromOffset(111,17)
                badge.Text="S "..format(row and row.supreme).." · M "..format(safeMM2(row))
            end
            badge.TextColor3=(row and row.supreme) and C9.text or C9.warm
        end
    end
end
local function watchSlotNodes(offer)
    if not offer then return end
    local cont=find(offer,"Container") or offer
    local function watchProperties(obj,props)
        if not obj then return end
        for _,name in ipairs(props) do
            pcall(function()attach(obj:GetPropertyChangedSignal(name),function()
                if alive then scheduleUpdate() end
            end,activeWatch)end)
        end
    end
    for n=1,4 do
        local slot=find(cont,"NewItem"..n) or find(offer,"NewItem"..n)
        if slot then
            watchProperties(slot,{"Visible"})
            watchProperties(nested(slot,"ItemName","Label"),{"Text","Visible"})
            watchProperties(nested(slot,"Tags","Chroma"),{"Visible"})
            watchProperties(nested(slot,"Container","Amount"),{"Text","Visible"})
        end
    end
end
local activeTradeScreen=nil
local activeOur=nil
local activeTheirs=nil
local function findTrade()
    for _,screen in ipairs(playerGui:GetChildren()) do
        if screen:IsA("ScreenGui") and screen~=root and validScreen(screen) then
            local trade=nested(screen,"Container","Trade") or screen:FindFirstChild("Trade",true)
            if trade and isVisible(trade) then
                local own=find(trade,"YourOffer") or trade:FindFirstChild("YourOffer",true)
                local them=find(trade,"TheirOffer") or trade:FindFirstChild("TheirOffer",true)
                if own and them and isVisible(own) and isVisible(them) then return screen,trade,own,them end
            end
        end
    end
    return nil
end
local function markSightings(items,source)
    for _,entry in ipairs(items or {}) do
        local row=lookup(entry.name)
        if row and row.supreme and row.supreme>=250 then
            local key=normalize(entry.name)
            local current=sightings[key]
            if not current or current.value~=row.supreme or os.time()-current.at>60 then
                sightings[key]={name=entry.name,value=row.supreme,at=os.time(),source=source,jobId=currentJob,placeId=modePlace}
                jwrite(SIGHTINGS_FILE,sightings)
            end
        end
    end
end
local warningUntil=0
local prevOther=""
local firstOpen=false
local function changedOffer(oldList,newList)
    local old={}
    for _,o in ipairs(oldList or {}) do old[normalize(o.name)]=(old[normalize(o.name)] or 0)+(o.count or 1)end
    local changes={}
    for _,n in ipairs(newList or {}) do
        local id=normalize(n.name)
        if old[id] then old[id]=old[id]-(n.count or 1) end
    end
    for name,count in pairs(old) do if count>0 then changes[#changes+1]=name.." x"..count end end
    return changes
end
local function refreshHUD(own,theirs)
    hudYou.Text="YOU      S "..displayNumber(own.supreme,own.missingSupreme).."    M "..displayNumber(own.mm2,own.missingMm2)
    hudThem.Text="THEM    S "..displayNumber(theirs.supreme,theirs.missingSupreme).."    M "..displayNumber(theirs.mm2,theirs.missingMm2)
    local diff,n=diffSummary(own,theirs,"supreme")
    hudDiff.Text="DIFF    "..diff
    hudDiff.TextColor3=n and (n>0 and C9.good or (n<0 and C9.bad or C9.sub)) or C9.warm
    local d=theirs.demandCount>0 and theirs.demandSum/theirs.demandCount or nil
    local age=supremeStale and " · STALE VALUES" or ""
    hudHeading.Text=(d and ("●  CARBON  /  DEMAND "..string.format("%.1f",d)) or "●  CARBON  /  LIVE TRADE")..age
    hudWarn.Text=(os.clock()<warningUntil and "!  OTHER OFFER CHANGED — RECHECK")
        or (d and d<=2 and "!  LOW DEMAND — CHECK LIQUIDITY" or "")
    if prefs.compact then
        hudYou.Position=UDim2.fromOffset(13,29);hudThem.Position=UDim2.fromOffset(13,50)
        hudDiff.Position=UDim2.fromOffset(13,72)
        hudWarn.Visible=false
        if not hudSmall then hud.Size=UDim2.fromOffset(276,99) end
    else
        hudYou.Position=UDim2.fromOffset(13,34);hudThem.Position=UDim2.fromOffset(13,58)
        hudDiff.Position=UDim2.fromOffset(13,82)
        hudWarn.Visible=not hudSmall
        if not hudSmall then hud.Size=UDim2.fromOffset(276,hudWarn.Text~="" and 124 or 112) end
    end
    hud.Visible=true
end
local function probeSuccess()
    for _,screen in ipairs(playerGui:GetChildren()) do
        if screen:IsA("ScreenGui") and screen~=root then
            for _,item in ipairs(screen:GetDescendants()) do
                if (item:IsA("TextLabel") or item:IsA("TextButton")) and isVisible(item) then
                    local value=trim(item.Text):lower()
                    if #value<110 then
                        for _,pat in ipairs({"trade successful","trade completed","trade complete","successfully traded", "обмен завершен", "обмен завершён"}) do
                            if value:find(pat,1,true) then return true end
                        end
                    end
                end
            end
        end
    end
    return false
end
local function finishTrade()
    if not lastTradeSnapshot then return end
    if (lastTradeSnapshot.you=="(empty)" and lastTradeSnapshot.them=="(empty)") then
        lastTradeSnapshot=nil
        return
    end
    local rec=lastTradeSnapshot
    lastTradeSnapshot=nil
    pendingSuccessId=pendingSuccessId+1
    local id=pendingSuccessId
    -- Do not claim confirmation from a closed trade window alone.
    task.spawn(function()
        local confirmed=false
        for step=1,7 do
            if not alive or id~=pendingSuccessId then return end
            if probeSuccess() then confirmed=true;break end
            task.wait(.35)
        end
        if not alive or id~=pendingSuccessId then return end
        rec.status=confirmed and "CONFIRMED" or "UNCONFIRMED"
        addHistory(rec)
        if confirmed then
            local d=rec.supremeDelta
            notify("TRADE COMPLETE",d and ((d>0 and "+" or "")..format(d).." SUPREME VALUE") or "Confirmed by game UI",C9.good)
        end
        if panel.Visible and currentTab=="HISTORY" then setTab("HISTORY") end
    end)
end
local function rebindTrade(screen,trade,own,theirs)
    if screen==activeTradeScreen and own==activeOur and theirs==activeTheirs then return end
    disconnect(activeWatch)
    activeTradeScreen=screen;activeOur=own;activeTheirs=theirs
    if not screen then return end
    attach(screen:GetPropertyChangedSignal("Enabled"),function()scheduleUpdate()end,activeWatch)
    if trade:IsA("GuiObject") then attach(trade:GetPropertyChangedSignal("Visible"),function()scheduleUpdate()end,activeWatch) end
    for _,offer in ipairs({own,theirs}) do
        attach(offer.DescendantAdded,function(o)
            if o.Name~="CarbonXValueTag" and not (o.Parent and o.Parent.Name=="CarbonXValueTag") then
                task.defer(function()
                    if alive then rebindTrade(nil,nil,nil,nil);scheduleUpdate()end
                end)
            end
        end,activeWatch)
        attach(offer.DescendantRemoving,function(o)
            if o.Name~="CarbonXValueTag" then scheduleUpdate()end
        end,activeWatch)
    end
    watchSlotNodes(own)
    watchSlotNodes(theirs)
end
local function readTrade()
    if not alive then return end
    local screen,trade,own,theirs=findTrade()
    if not screen then
        if tradeActive then finishTrade() end
        tradeActive=false
        firstOpen=false
        prevOther=""
        hud.Visible=false
        rebindTrade(nil,nil,nil,nil)
        if panel.Visible and currentTab=="TRADE" then renderDetails() end
        return
    end
    if not tradeActive then
        pendingSuccessId=pendingSuccessId+1
        firstOpen=true
        prevOther=""
    end
    tradeActive=true
    rebindTrade(screen,trade,own,theirs)
    local ownItems,otherItems=offerToList(own),offerToList(theirs)
    local ourSum,theirSum=aggregate(ownItems),aggregate(otherItems)
    for slot,badge in pairs(badges) do
        if badge and badge.Parent==slot then badge.Visible=false end
    end
    showTags(ownItems);showTags(otherItems)
    local newSig=offerFingerprint(otherItems)
    if not firstOpen and newSig~=prevOther then
        local removed=changedOffer(latestTrade and latestTrade.them and latestTrade.them.items,otherItems)
        if #removed>0 then
            warningUntil=os.clock()+5
            notify("OFFER MODIFIED",table.concat(removed,", "):sub(1,58),C9.warm)
        end
    end
    prevOther=newSig
    firstOpen=false
    local delta=nil
    if ourSum.missingSupreme==0 and theirSum.missingSupreme==0 then delta=theirSum.supreme-ourSum.supreme end
    latestTrade={you=ourSum,them=theirSum,at=os.time(),delta=delta,
        yourNames=formatOffer(ourSum.items),theirNames=formatOffer(theirSum.items)}
    lastTradeSnapshot={at=os.time(),status="UNCONFIRMED",
        you=latestTrade.yourNames,them=latestTrade.theirNames,
        supremeYou=ourSum.missingSupreme==0 and ourSum.supreme or nil,
        supremeThem=theirSum.missingSupreme==0 and theirSum.supreme or nil,
        supremeDelta=delta,
        mm2You=ourSum.missingMm2==0 and ourSum.mm2 or nil,
        mm2Them=theirSum.missingMm2==0 and theirSum.mm2 or nil}
    refreshHUD(ourSum,theirSum)
    markSightings(otherItems,"trade")
    if panel.Visible and currentTab=="TRADE" then renderDetails() end
end
scheduleUpdate = function()
    if scheduled or not alive then return end
    scheduled=true
    task.delay(prefs.lowPower and .22 or .09,function()
        scheduled=false
        if alive then
            local ok,err=pcall(readTrade)
            if not ok then setStatus("Trade UI: "..tostring(err):sub(1,80)) end
        end
    end)
end
attach(playerGui.ChildAdded,function(node)
    if node~=root and node:IsA("ScreenGui") then scheduleUpdate() end
end)
attach(playerGui.ChildRemoved,function(node)
    if node==activeTradeScreen then scheduleUpdate() end
end)
-- Listen for discovered changes, not 3 full rescans per second.
task.spawn(function()
    while alive do
        task.wait(prefs.lowPower and 8 or 4)
        if alive then scheduleUpdate() end -- low-frequency recovery only
    end
end)
local trackedPlayers=setmetatable({}, {__mode="k"})
local function watchPlayer(p)
    if trackedPlayers[p] or p==player then return end
    trackedPlayers[p]=true
    local function charAttached(ch)
        local function inspect(tool)
            if not tool:IsA("Tool") then return end
            local row=lookup(tool.Name)
            if row and row.supreme and row.supreme>=250 then
                markSightings({{name=tool.Name}},"equipped")
            end
        end
        for _,tool in ipairs(ch:GetChildren()) do inspect(tool) end
        attach(ch.ChildAdded,inspect)
    end
    if p.Character then charAttached(p.Character) end
    attach(p.CharacterAdded,charAttached)
end
for _,p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
attach(Players.PlayerAdded,watchPlayer)
local compareA="Harvester"
local compareB="Elderwood Scythe"
renderDetails=function()
    if currentTab~="TRADE" then return end
    clearContent()
    headline("TRADE INTELLIGENCE",tradeActive and "Live values from the current trade" or "Waiting for a trade",0)
    local c=card(56,104)
    local own=latestTrade and tradeActive and latestTrade.you or emptySide()
    local other=latestTrade and tradeActive and latestTrade.them or emptySide()
    txt(c,"YOU","YOUR OFFER",UDim2.fromOffset(14,8),UDim2.new(.5,-18,0,22),10,true,C9.sub)
    txt(c,"THEM","THEIR OFFER",UDim2.new(.5,3,0,8),UDim2.new(.5,-17,0,22),10,true,C9.sub)
    txt(c,"OwnNumber",tradeActive and displayNumber(own.supreme,own.missingSupreme) or "—",UDim2.fromOffset(14,30),UDim2.new(.5,-18,0,32),23,true)
    txt(c,"OtherNumber",tradeActive and displayNumber(other.supreme,other.missingSupreme) or "—",UDim2.new(.5,3,0,30),UDim2.new(.5,-17,0,32),23,true)
    local summary,delta=diffSummary(own,other,"supreme")
    txt(c,"Result",tradeActive and ("SUPREME  Δ "..summary) or "No active offer",UDim2.fromOffset(14,69),UDim2.new(1,-28,0,25),12,true,
        not tradeActive and C9.sub or (delta and (delta>0 and C9.good or delta<0 and C9.bad or C9.sub) or C9.warm))
    local m=card(171,58)
    local mm,diff=diffSummary(own,other,"mm2")
    txt(m,"MM2","MM2VALUES / ARCHIVE",UDim2.fromOffset(14,6),UDim2.new(1,-28,0,18),10,true,C9.sub)
    txt(m,"MM2Delta",tradeActive and ("YOU "..displayNumber(own.mm2,own.missingMm2).."  ·  THEM "..displayNumber(other.mm2,other.missingMm2).."  ·  Δ "..mm) or "No active offer",UDim2.fromOffset(14,26),UDim2.new(1,-28,0,22),11,true,C9.text)
    local s=card(240,83)
    local demand=(other.demandCount>0 and other.demandSum/other.demandCount) or nil
    local confidence=not loaded and "NOT LOADED" or (supremeStale and "SOURCE STALE" or "MIRROR SNAPSHOT")
    txt(s,"Demand","DEMAND  "..(demand and string.format("%.1f / 10",demand) or "UNKNOWN"),UDim2.fromOffset(13,10),UDim2.new(1,-26,0,23),12,true)
    txt(s,"Quality",confidence.." · no guaranteed profit",UDim2.fromOffset(13,36),UDim2.new(1,-26,0,19),10,false,C9.warm)
    if os.clock()<warningUntil then
        txt(s,"Risk","OTHER OFFER CHANGED — REVIEW ITEMS",UDim2.fromOffset(13,60),UDim2.new(1,-26,0,18),10,true,C9.bad)
    end
    local a=input(content,"CompareA","  First skin",UDim2.fromOffset(3,337),UDim2.new(.5,-9,0,33))
    local b=input(content,"CompareB","  Second skin",UDim2.new(.5,6,0,337),UDim2.new(.5,-9,0,33))
    a.Text=compareA;b.Text=compareB
    local result=txt(content,"CompareResult","Enter 2 items and press COMPARE",UDim2.fromOffset(4,375),UDim2.new(1,-8,0,27),11,false,C9.sub)
    btn(content,"Compare","COMPARE",UDim2.fromOffset(3,410),UDim2.fromOffset(113,34),"primary",function()
        compareA=trim(a.Text);compareB=trim(b.Text)
        local aa,bb=lookup(compareA),lookup(compareB)
        result.Text=compareA.."  "..format(aa and aa.supreme).."  /  "..compareB.."  "..format(bb and bb.supreme)
        result.TextColor3=(aa and bb) and C9.good or C9.warm
    end,activeUI)
    btn(content,"Wish","☆ WATCH FIRST",UDim2.fromOffset(125,410),UDim2.fromOffset(139,34),"secondary",function()
        local name=trim(a.Text)
        if name~="" and #name<80 then
            prefs.wishlist[normalize(name)]=name
            savePrefs();notify("WATCHLIST UPDATED",name)
        end
    end,activeUI)
    height(451)
end
local inventoryQuery=""
local inventoryQuantity="1"
renderInventory=function()
    headline("MY INVENTORY","Manual tracker · not a Roblox inventory scan",0)
    local a=input(content,"SkinInput","  Skin name (e.g. Harvester)",UDim2.fromOffset(3,55),UDim2.new(1,-108,0,35))
    a.Text=inventoryQuery
    local quantity=input(content,"Quantity","  QTY",UDim2.new(1,-100,0,55),UDim2.fromOffset(96,35))
    quantity.Text=inventoryQuantity
    btn(content,"Add","ADD ITEM",UDim2.fromOffset(3,99),UDim2.fromOffset(108,33),"primary",function()
        inventoryQuery=trim(a.Text)
        inventoryQuantity=trim(quantity.Text)
        local n=tonumber(inventoryQuantity)
        if #inventoryQuery<2 or #inventoryQuery>80 or not n or n<1 or n>999 or n~=math.floor(n) then
            notify("INVALID ENTRY","Use item name and quantity 1–999",C9.warm);return
        end
        local row=lookup(inventoryQuery)
        if not row then notify("NOT IN PRICE DATABASE","Try another item spelling",C9.warm);return end
        local key=normalize(row.name)
        prefs.myItems[key]={name=row.name,count=math.min(9999,(type(prefs.myItems[key])=="table" and tonumber(prefs.myItems[key].count) or 0)+n)}
        savePrefs();setTab("INVENTORY")
    end,activeUI)
    btn(content,"Clear","CLEAR ALL",UDim2.fromOffset(121,99),UDim2.fromOffset(101,33),"quiet",function()
        prefs.myItems={};savePrefs();setTab("INVENTORY")
    end,activeUI)
    local rows={}
    for key,it in pairs(prefs.myItems) do
        if type(it)=="table" and type(it.name)=="string" and type(it.count)=="number" and it.count>0 then
            rows[#rows+1]={name=it.name,count=it.count,key=key}
        end
    end
    table.sort(rows,function(a,b)
        local aa,bb=lookup(a.name),lookup(b.name)
        return ((aa and aa.supreme) or -1)*a.count > ((bb and bb.supreme) or -1)*b.count
    end)
    local sums=aggregate(rows)
    local c=card(146,67)
    txt(c,"Total","TRACKED VALUE · "..#rows.." unique items",UDim2.fromOffset(13,8),UDim2.new(1,-26,0,21),10,true,C9.sub)
    txt(c,"Price","S "..displayNumber(sums.supreme,sums.missingSupreme).."      M "..displayNumber(sums.mm2,sums.missingMm2),UDim2.fromOffset(13,31),UDim2.new(1,-26,0,27),16,true)
    local y=227
    for i=1,math.min(#rows,12) do
        local item=rows[i];local row=lookup(item.name)
        local c=card(y,44)
        txt(c,"Name",item.name.." ×"..item.count,UDim2.fromOffset(9,3),UDim2.new(1,-107,0,18),11,true)
        txt(c,"Value","S "..format(row and row.supreme).."  M "..format(safeMM2(row)),UDim2.fromOffset(9,22),UDim2.new(1,-107,0,15),9,false,C9.sub)
        btn(c,"Remove","−1",UDim2.new(1,-90,0,8),UDim2.fromOffset(38,29),"quiet",function()
            local v=prefs.myItems[item.key]
            if v then v.count=v.count-1;if v.count<=0 then prefs.myItems[item.key]=nil end end
            savePrefs();setTab("INVENTORY")
        end,activeUI)
        btn(c,"Delete","×",UDim2.new(1,-46,0,8),UDim2.fromOffset(36,29),"quiet",function()
            prefs.myItems[item.key]=nil;savePrefs();setTab("INVENTORY")
        end,activeUI)
        y=y+50
    end
    if #rows==0 then txt(content,"NoItems","No items recorded. Enter an item above.",UDim2.fromOffset(7,232),UDim2.new(1,-14,0,30),11,false,C9.sub) end
    if #rows>12 then txt(content,"Overflow","Showing first 12 of "..#rows.." entries",UDim2.fromOffset(7,y),UDim2.new(1,-14,0,28),11,false,C9.warm) end
    y=y+12
    txt(content,"Watchlist","WISHLIST",UDim2.fromOffset(7,y),UDim2.new(1,-14,0,25),12,true,C9.sub)
    y=y+29
    local wishes={}
    for key,name in pairs(prefs.wishlist) do
        if type(key)=="string" and type(name)=="string" then wishes[#wishes+1]={key=key,name=name} end
    end
    table.sort(wishes,function(a,b)return a.name<b.name end)
    for i=1,math.min(8,#wishes) do
        local it=wishes[i]
        local row=lookup(it.name)
        txt(content,"Wish"..i,it.name.."    S "..format(row and row.supreme),UDim2.fromOffset(7,y),UDim2.new(1,-54,0,28),11,false,C9.text)
        btn(content,"RemoveWish"..i,"×",UDim2.new(1,-44,0,y),UDim2.fromOffset(34,26),"quiet",function()
            prefs.wishlist[it.key]=nil;savePrefs();setTab("INVENTORY")
        end,activeUI)
        y=y+30
    end
    if #wishes==0 then
        txt(content,"NoWishes","Add skins using the Trade tab's ☆ button.",UDim2.fromOffset(7,y),UDim2.new(1,-14,0,25),10,false,C9.sub)
        y=y+28
    end
    height(y+20)
end
renderHistory=function()
    headline("TRADE JOURNAL","Only game-confirmed trades affect statistics",0)
    local completed,profit,loss,net=0,0,0,0
    for _,h in ipairs(history) do
        if h.status=="CONFIRMED" and type(h.supremeDelta)=="number" then
            completed=completed+1
            if h.supremeDelta>0 then profit=profit+h.supremeDelta end
            if h.supremeDelta<0 then loss=loss-math.abs(h.supremeDelta)end
            net=net+h.supremeDelta
        end
    end
    local c=card(54,76)
    txt(c,"Profit","NET  "..(net>0 and "+" or "")..format(net),UDim2.fromOffset(13,7),UDim2.new(1,-26,0,27),18,true,net>=0 and C9.good or C9.bad)
    txt(c,"Stats",completed.." confirmed  ·  gross +"..format(profit).."  /  losses "..format(loss),UDim2.fromOffset(13,39),UDim2.new(1,-26,0,22),11,false,C9.sub)
    local y=141
    for i=1,math.min(#history,35) do
        local h=history[i]
        local f=card(y,65)
        local confirmed=h.status=="CONFIRMED"
        txt(f,"Header",(confirmed and "● CONFIRMED" or "○ UNCONFIRMED").."  ·  "..os.date("%d %b %H:%M",h.at),UDim2.fromOffset(11,5),UDim2.new(1,-22,0,19),10,true,confirmed and C9.good or C9.warm)
        txt(f,"Items",tostring(h.you or "?"):sub(1,80).."  →  "..tostring(h.them or "?"):sub(1,80),UDim2.fromOffset(11,25),UDim2.new(1,-22,0,18),10,false,C9.text)
        txt(f,"Difference","SΔ "..format(h.supremeDelta).." · M "..format(h.mm2You).." → "..format(h.mm2Them),UDim2.fromOffset(11,44),UDim2.new(1,-22,0,17),10,false,C9.sub)
        y=y+71
    end
    if #history==0 then txt(content,"NoEntries","No completed trade records yet.",UDim2.fromOffset(7,157),UDim2.new(1,-14,0,30),11,false,C9.sub) end
    height(y+20)
end
renderSettings=function()
    headline("PREFERENCES","Persistent where file APIs are available",0)
    for i,row in ipairs({
        {"ANIMATIONS","animations","Show subtle confirmation effects"},
        {"LOW POWER","lowPower","Reduce activity and motion"},
        {"COMPACT HUD","compact","Use smaller HUD when trading"},
        {"ITEM PRICE TAGS","showTags","Value tags inside trade slots"}
    }) do
        local y=61+(i-1)*64
        local c=card(y,55)
        txt(c,"Name",row[1],UDim2.fromOffset(13,6),UDim2.new(1,-103,0,22),11,true)
        txt(c,"Explanation",row[3],UDim2.fromOffset(13,29),UDim2.new(1,-103,0,17),10,false,C9.sub)
        btn(c,"Toggle",prefs[row[2]] and "ON" or "OFF",UDim2.new(1,-78,0,10),UDim2.fromOffset(66,34),prefs[row[2]] and "primary" or "quiet",function()
            prefs[row[2]]=not prefs[row[2]];savePrefs()
            if row[2]=="compact" and not hudSmall then
                hud.Size=UDim2.fromOffset(276,prefs.compact and 95 or 112)
            end
            setTab("SETTINGS")
        end,activeUI)
    end
    local bottom=card(331,86)
    txt(bottom,"Debug","DIAGNOSTICS",UDim2.fromOffset(13,7),UDim2.new(1,-26,0,20),11,true)
    txt(bottom,"Sources","S mirror: "..supremeStamp.."   /   M archive: "..mm2Stamp,UDim2.fromOffset(13,28),UDim2.new(1,-26,0,17),10,false,C9.sub)
    txt(bottom,"Status",statusText:sub(1,100),UDim2.fromOffset(13,48),UDim2.new(1,-26,0,18),10,false,C9.warm)
    btn(content,"Update","REFRESH PRICES",UDim2.fromOffset(3,428),UDim2.fromOffset(144,34),"primary",function()
        notify("UPDATING VALUES","Network request started")
        task.spawn(function()loadPrices();if alive then notify("PRICE REFRESH",lastError or "Updated from public data")end end)
    end,activeUI)
    btn(content,"Export","EXPORT JOURNAL",UDim2.fromOffset(156,428),UDim2.fromOffset(144,34),"secondary",function()
        if jwrite("MM2CarbonX_v9_history_export.json",history) then notify("EXPORT SAVED","History export file created")
        else notify("EXPORT UNAVAILABLE","Delta needs writefile support",C9.warm) end
    end,activeUI)
    height(474)
end
-- Event-based initial scan and optional recovery.
priceListeners[#priceListeners+1]=function()
    if not alive then return end
    footer.Text="S SNAPSHOT: "..supremeStamp.."    /    M ARCHIVE: "..mm2Stamp
    scheduleUpdate()
    if panel.Visible then setTab(currentTab) end
end
-- Lua declarations above use this safe indirection to avoid local scoping issues.
local function detectMode()
    if tonumber(game.GameId)==66654135 then return "MM2 / UNIVERSE" end
    return "MM2 / MAIN"
end
setStatus(detectMode().."  ·  Prices pending")
setTab("TRADE")
-- Cache first, then update from upstream. Never silently invent prices.
readPriceCache()
task.spawn(syncServers)
task.spawn(function()
    loadPrices()
    if not alive then return end
    footer.Text="S SNAPSHOT: "..supremeStamp.."    /    M ARCHIVE: "..mm2Stamp
    setStatus(lastError or "Price mirror loaded")
    scheduleUpdate()
end)
-- Respect the user's chosen executor: queue is optional, not an assumed feature.
local queued=false
local queueFn=(type(queue_on_teleport)=="function" and queue_on_teleport) or
    (type(queueonteleport)=="function" and queueonteleport) or
    (type(syn)=="table" and type(syn.queue_on_teleport)=="function" and syn.queue_on_teleport)
if type(queueFn)=="function" then
    local nextCode="if not game:IsLoaded() then game.Loaded:Wait() end; "..
        "local ok,err=pcall(function() loadstring(game:HttpGet('"..RELOAD_URL.."'))() end); "..
        "if not ok then warn('[Carbon X teleport] '..tostring(err)) end"
    queued=pcall(queueFn,nextCode)
end
local function localDiagnostics()
    return {version="9.0",placeId=game.PlaceId,gameId=game.GameId,tradeOpen=tradeActive,
        supremeDate=supremeStamp,mm2Date=mm2Stamp,lastError=lastError,queued=queued,
        serverCount=#serverList,serverSource=serverStamp,rareSightings=sightings,
        snapshotMode="read only",historyCount=#history}
end
env.MM2CarbonXDiagnostics=localDiagnostics
env.MM2CarbonState=localDiagnostics
local originalCleanup=cleanup
env.MM2CarbonCleanup=function()
    disconnect(activeUI)
    disconnect(activeWatch)
    disconnect(allFrames)
    originalCleanup()
    env.MM2CarbonCleanup=nil
    env.MM2CarbonXDiagnostics=nil
end
-- Do not scan private inventories; capture only visually equipped tools / trade offers.
scheduleUpdate()

end, function(err)
    if debug and type(debug.traceback)=="function" then return debug.traceback(tostring(err),2) end
    return tostring(err)
end)
if not ok then
    warn("[MM2 CARBON X V9] "..tostring(failure))
    pcall(function()
        local pg=game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui",5)
        if not pg then return end
        local old=pg:FindFirstChild("MM2CarbonXError")
        if old then old:Destroy() end
        local g=Instance.new("ScreenGui")
        g.Name="MM2CarbonXError";g.ResetOnSpawn=false;g.DisplayOrder=10001;g.Parent=pg
        local t=Instance.new("TextLabel")
        t.Size=UDim2.fromOffset(320,86);t.Position=UDim2.new(.5,-160,0,65)
        t.TextWrapped=true;t.BackgroundTransparency=.09;t.BackgroundColor3=Color3.fromRGB(25,27,28)
        t.TextColor3=Color3.fromRGB(230,185,181);t.Font=Enum.Font.Gotham;t.TextSize=12
        t.Text="CARBON X FAILED\n"..tostring(failure):sub(1,300);t.Parent=g
        local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,12);c.Parent=t
    end)
end
