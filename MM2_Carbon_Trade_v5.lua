-- MM2 Carbon Trade v5.1 / Delta compatibility patch
-- Replace the original MM2_Carbon_Trade_v5.lua on your GitHub with this file.
local ok, failure = xpcall(function()
-- Delta-compatible direct execution: no giant nested loadstring.
local embeddedSource = nil
-- MM2 CARBON TRADE v5.0 (trade UI is read-only; server join is user initiated)
-- Shows prices AUTOMATICALLY on items placed in both MM2 trade offers.
-- No menu, no input, no trade remotes, no auto-accept, no authentication.
-- Sources: periodically updated community Supreme CSV + older MM2Values archive.
-- Source code/data: https://github.com/yanaa-12/mm2-trading
--                   https://github.com/timez170/mm2-values
-- This is an unofficial companion UI. Prices are estimated trade values, not Robux.
-- Requires a Lua environment that can access PlayerGui and perform HTTP GET.

if game.PlaceId ~= 142823291 then
    warn("MM2 Carbon Trade is intended for Murder Mystery 2 (place 142823291).")
    return
end
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
if not player then return end
local playerGui = player:WaitForChild("PlayerGui")
local oldRoot = playerGui:FindFirstChild("MM2CarbonTradeV5")
if oldRoot then pcall(function() oldRoot:Destroy() end) end

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

local C = {
    bg = Color3.fromRGB(25, 28, 30), raised = Color3.fromRGB(36, 40, 42),
    rim = Color3.fromRGB(93, 101, 104), fg = Color3.fromRGB(236, 239, 238),
    muted = Color3.fromRGB(162, 169, 170), positive = Color3.fromRGB(172, 211, 192),
    negative = Color3.fromRGB(220, 172, 166), amber = Color3.fromRGB(222, 203, 165)
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
                            demand = number(fields[4]), rarity = number(fields[5])}
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

local function loadPrices()
    if loading or not alive then return end
    loading = true
    local csv = fetch(URL_SUPREME)
    local meta = readJson(fetch(URL_META))
    local archive = readJson(fetch(URL_MM2))
    local sup = parseSupreme(csv)
    if not alive then loading = false; return end
    if not sup then sup = {} end
    local haveSup = next(sup) ~= nil
    local haveMM2 = mergeArchive(sup, archive)
    if haveSup or haveMM2 then
        index = sup
        loaded = true
        supremeStamp = haveSup and tostring(meta and meta.last_updated or "?"):sub(1, 10) or "offline"
        mm2Stamp = haveMM2 and tostring(archive.updatedAt or "?"):sub(1, 10) or "offline"
        local sd = ageDays(supremeStamp)
        local md = ageDays(mm2Stamp)
        supremeStale = not sd or sd > 7
        mm2Stale = not md or md > 14
        lastError = not haveSup and "Supreme unavailable" or nil
    else
        lastError = "Price sources unreachable"
        -- Keep previously fetched values if refresh fails. Never inject made-up numbers.
    end
    loading = false
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

-- Carbon Trade v5: read-only values and manually initiated server browsing.
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local PLACE_ID = 142823291
local RARE_THRESHOLD = 250
local CACHE_FILE = "MM2Carbon_SeenServers_v5.json"
local CACHE_TTL = 30 * 60 -- 30 minute historical observation, NOT a live inventory lookup.
local root = track(gui("ScreenGui", {
    Name = "MM2CarbonTradeV5", ResetOnSpawn = false,
    IgnoreGuiInset = false, DisplayOrder = 3500,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling
}, playerGui))
local function mk(kind, props, parent) return gui(kind, props, parent) end
local function rounded(parent, radius)
    return mk("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, parent)
end
local function outlined(parent, opacity)
    return mk("UIStroke", {Color=C.rim, Thickness=1, Transparency=opacity or .7}, parent)
end
local function conn(signal, fn)
    local link = signal:Connect(fn)
    created[#created+1]={Destroy=function() link:Disconnect() end}
    return link
end
local function textLabel(parent, name, value, pos, size, fontSize, bold, color, align)
    local t=mk("TextLabel",{Name=name,Text=value,Position=pos,Size=size,BorderSizePixel=0,
        BackgroundTransparency=1,Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextColor3=color or C.fg,TextSize=fontSize,TextXAlignment=align or Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=32},parent)
    return t
end
local function button(parent,name,caption,pos,size,primary)
    local b=mk("TextButton",{Name=name,Text=caption,Position=pos,Size=size,BorderSizePixel=0,
        BackgroundColor3=primary and C.fg or C.raised,
        BackgroundTransparency=primary and .06 or .22,
        TextColor3=primary and C.bg or C.fg,Font=Enum.Font.GothamBold,TextSize=12,
        AutoButtonColor=true,Active=true,Selectable=true,ZIndex=36},parent)
    rounded(b,8)
    if not primary then outlined(b,.84) end
    return b
end
local function panel(parent,name,size,position)
    local p=mk("Frame",{Name=name,Size=size,Position=position,BorderSizePixel=0,
        BackgroundColor3=C.bg,BackgroundTransparency=.14,Visible=false,
        Active=true,ClipsDescendants=false,ZIndex=26},parent)
    rounded(p,12);outlined(p,.56)
    mk("Frame",{Name="TopHighlight",Size=UDim2.new(1,-26,0,1),Position=UDim2.new(0,13,0,1),
        BackgroundColor3=C.fg,BackgroundTransparency=.88,BorderSizePixel=0,ZIndex=29},p)
    return p
end
local function drag(frame, handle)
    local started,input0,position0,moving
    conn(handle.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            started=true;input0=input.Position;position0=frame.Position
            local ref
            ref=input.Changed:Connect(function()
                if input.UserInputState==Enum.UserInputState.End then
                    started=false
                    if ref then ref:Disconnect();ref=nil end
                end
            end)
        end
    end)
    conn(handle.InputChanged,function(input)
        if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then
            moving=input
        end
    end)
    conn(UserInputService.InputChanged,function(input)
        if started and input==moving and position0 and input0 then
            local d=input.Position-input0
            frame.Position=UDim2.new(position0.X.Scale,position0.X.Offset+d.X,
                position0.Y.Scale,position0.Y.Offset+d.Y)
        end
    end)
end

-- Mobile and short monitors: a scaled panel remains fully on-screen.
local hud = panel(root,"TradeTotalsHUD",UDim2.new(0,284,0,104),UDim2.new(0,13,0,69))
local hudScale=mk("UIScale",{Name="UIScale",Scale=1},hud)
local hudTitle=textLabel(hud,"Title","CARBON   /   TRADE",UDim2.new(0,13,0,8),UDim2.new(0,215,0,19),12,true,C.fg)
hudTitle.Active=true;drag(hud,hudTitle)
local hudCollapse=button(hud,"Collapse","–",UDim2.new(1,-31,0,7),UDim2.new(0,24,0,22))
local hairline=mk("Frame",{BackgroundColor3=C.rim,BackgroundTransparency=.73,BorderSizePixel=0,
    Size=UDim2.new(1,-26,0,1),Position=UDim2.new(0,13,0,31),ZIndex=29},hud)
local ownLabel=textLabel(hud,"You","YOU     —",UDim2.new(0,13,0,35),UDim2.new(1,-26,0,20),12,true,C.muted)
local themLabel=textLabel(hud,"Them","THEM    —",UDim2.new(0,13,0,57),UDim2.new(1,-26,0,20),12,true,C.muted)
local deltaLabel=textLabel(hud,"Delta","Δ   —",UDim2.new(0,13,0,80),UDim2.new(0,185,0,17),12,true,C.muted)
local ageLabel=textLabel(hud,"Sources","",UDim2.new(1,-83,0,80),UDim2.new(0,70,0,17),9,false,C.muted,Enum.TextXAlignment.Right)
local collapsed=false
conn(hudCollapse.MouseButton1Click,function()
    collapsed=not collapsed
    hud.Size=UDim2.new(0,284,0,collapsed and 36 or 104)
    for _,o in ipairs({hairline,ownLabel,themLabel,deltaLabel,ageLabel}) do o.Visible=not collapsed end
    hudCollapse.Text=collapsed and "+" or "–"
end)

-- Server finder is separate from trade UI, with a permanently visible OPEN button.
local launcher=button(root,"OpenServers","SERVERS",UDim2.new(1,-118,0,55),UDim2.new(0,105,0,30),false)
launcher.AnchorPoint=Vector2.new(0,0)
launcher.BackgroundTransparency=.08
local browser=panel(root,"Browser",UDim2.new(0,396,0,411),UDim2.new(1,-13,0,91))
browser.AnchorPoint=Vector2.new(1,0)
local browserScale=mk("UIScale",{Name="UIScale",Scale=1},browser)
local browserTitle=textLabel(browser,"Title","CARBON  /  SERVER FINDER",UDim2.new(0,14,0,10),UDim2.new(0,311,0,22),13,true,C.fg)
browserTitle.Active=true;drag(browser,browserTitle)
local close=button(browser,"Close","×",UDim2.new(1,-36,0,8),UDim2.new(0,27,0,25))
local info=textLabel(browser,"Info","Only observed skins are identified",UDim2.new(0,14,0,36),UDim2.new(1,-28,0,18),11,false,C.muted)
local refresh=button(browser,"Refresh","REFRESH",UDim2.new(0,12,0,61),UDim2.new(0,86,0,28))
local seenFilter=button(browser,"SeenOnly","SEEN",UDim2.new(0,104,0,61),UDim2.new(0,80,0,28))
local prev=button(browser,"Prev","‹",UDim2.new(0,297,0,61),UDim2.new(0,39,0,28))
local nextB=button(browser,"Next","›",UDim2.new(0,342,0,61),UDim2.new(0,39,0,28))
local pageText=textLabel(browser,"Page","PAGE 1",UDim2.new(0,189,0,61),UDim2.new(0,102,0,28),10,false,C.muted,Enum.TextXAlignment.Center)
local subTitle=textLabel(browser,"SectionTitle","PUBLIC SERVERS  /  UNVERIFIED UNTIL VISITED",UDim2.new(0,13,0,94),UDim2.new(1,-26,0,13),9,true,C.muted)

local rows={}
for i=1,4 do
    local y=112+(i-1)*53
    local row=mk("Frame",{Name="ServerRow"..i,BackgroundColor3=C.raised,
        BackgroundTransparency=.36,BorderSizePixel=0,
        Position=UDim2.new(0,12,0,y),Size=UDim2.new(1,-24,0,49),ZIndex=29,Visible=false},browser)
    rounded(row,8)
    local name=textLabel(row,"Item","UNKNOWN",UDim2.new(0,11,0,4),UDim2.new(0,265,0,20),12,true,C.fg)
    local detail=textLabel(row,"Details","Not visited",UDim2.new(0,11,0,26),UDim2.new(0,265,0,17),10,false,C.muted)
    local join=button(row,"Join","JOIN",UDim2.new(1,-84,0,9),UDim2.new(0,74,0,31),true)
    rows[i]={frame=row,name=name,detail=detail,join=join,server=nil}
end
local directInput=mk("TextBox",{Name="JobIdInput",Text="",PlaceholderText="Paste server JobId (optional)",
    ClearTextOnFocus=false,Font=Enum.Font.Gotham,TextSize=12,
    TextColor3=C.fg,PlaceholderColor3=C.muted,BackgroundColor3=C.raised,
    BackgroundTransparency=.3,BorderSizePixel=0,TextXAlignment=Enum.TextXAlignment.Left,
    Position=UDim2.new(0,12,0,332),Size=UDim2.new(0,275,0,30),ZIndex=35},browser)
rounded(directInput,7)
local manualJoin=button(browser,"JoinId","JOIN ID",UDim2.new(0,294,0,332),UDim2.new(0,88,0,30),true)
local message=textLabel(browser,"Status","Press Refresh to view public servers",UDim2.new(0,13,0,367),UDim2.new(1,-26,0,18),10,false,C.muted)
local hint=textLabel(browser,"Hint","Seen = witnessed here earlier, not a live inventory",UDim2.new(0,13,0,388),UDim2.new(1,-26,0,13),9,false,C.muted)

local function fitViewport()
    local wide,high=1280,720
    local ok,size=pcall(function() return workspace.CurrentCamera.ViewportSize end)
    if ok and size then wide,high=size.X,size.Y end
    if wide<=0 or high<=0 then return end
    browserScale.Scale=math.max(.48,math.min(1,(wide-26)/396,(high-108)/411))
    hudScale.Scale=math.max(.6,math.min(1,(wide-26)/284))
end
pcall(fitViewport)
local cam=workspace and workspace.CurrentCamera
if cam then pcall(function() conn(cam:GetPropertyChangedSignal("ViewportSize"),fitViewport) end) end

-- Queue a self-contained script on the next teleport, only where supported by the executor.
local queueFunc=(type(queue_on_teleport)=="function" and queue_on_teleport)
    or (type(queueonteleport)=="function" and queueonteleport)
    or (type(syn)=="table" and type(syn.queue_on_teleport)=="function" and syn.queue_on_teleport)
local autoReload=false
local queueRegistered=false
local function queueAgain()
    if queueRegistered then return true end
    if type(queueFunc)~="function" then return false end
    -- Short queue payload: re-download the full file rather than queueing 37 KB.
    -- Works only if this fixed source is uploaded at this GitHub path.
    local payload = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/zxcswastik-cyber/valuemm2/refs/heads/main/MM2_Carbon_Trade_v5.lua"))()'
    local ok = pcall(queueFunc, payload)
    if ok then queueRegistered=true end
    return ok
end
autoReload=queueAgain()

local seenServers={}
local serverItems={}
local cursor=nil
local page=1
local filtered=false
local busy=false
local knownCursor={}
local lastRefresh=0
local function idShort(id)
    id=tostring(id or "")
    return #id>8 and id:sub(1,8) or id
end
local function loadHistory()
    if type(readfile)~="function" then return end
    local ok,raw=pcall(readfile,CACHE_FILE)
    if not ok then return end
    local src=readJson(raw)
    if type(src)~="table" then return end
    local now=os.time()
    for id,record in pairs(src) do
        if type(id)=="string" and type(record)=="table" and type(record.at)=="number"
            and record.at<=now and now-record.at<CACHE_TTL and type(record.items)=="table" then
            local items={}
            for _,item in ipairs(record.items) do
                if #items>=4 then break end
                if type(item)=="table" and type(item.name)=="string"
                    and type(item.value)=="number" and item.value>=RARE_THRESHOLD then
                    items[#items+1]={name=item.name:sub(1,55),value=item.value,
                        source=tostring(item.source or "Seen"):sub(1,16)}
                end
            end
            if #items>0 then seenServers[id]={at=record.at,items=items} end
        end
    end
end
loadHistory()
local function saveHistory()
    if type(writefile)~="function" then return end
    pcall(function() writefile(CACHE_FILE,HttpService:JSONEncode(seenServers)) end)
end
local function observed(id)
    local record=seenServers[tostring(id or "")]
    if not record or type(record.items)~="table" then return nil end
    if os.time()-(record.at or 0)>CACHE_TTL then return nil end
    return record
end
local function remember(name,value,kind)
    if type(game.JobId)~="string" or game.JobId=="" or type(name)~="string" then return end
    if not value or value<RARE_THRESHOLD then return end
    local id=game.JobId
    local record=seenServers[id] or {items={}}
    local same=false
    for _,item in ipairs(record.items) do
        if item.name==name and item.value==value then same=true;break end
    end
    if same then return end
    record.items[#record.items+1]={name=name:sub(1,55),value=value,source=kind}
    table.sort(record.items,function(a,b) return a.value>b.value end)
    while #record.items>4 do table.remove(record.items) end
    record.at=os.time()
    seenServers[id]=record
    saveHistory()
end
local function scanCurrent()
    local found={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=player and p.Character then
            for _,tool in ipairs(p.Character:GetChildren()) do
                if tool:IsA("Tool") then
                    local row=lookup(tool.Name)
                    if row and row.supreme and row.supreme>=RARE_THRESHOLD then
                        found[#found+1]={player=tostring(p.DisplayName or p.Name),name=row.name,value=row.supreme}
                    end
                end
            end
        end
    end
    table.sort(found,function(a,b)return a.value>b.value end)
    for i=1,math.min(4,#found) do
        local e=found[i]
        remember(e.name,e.value,"equipped")
    end
    if browser.Visible then
        if #found>0 then
            message.Text="CURRENT  "..found[1].name.."  S "..format(found[1].value)
            message.TextColor3=C.positive
        else
            message.Text="No high-value equipped items observed"
            message.TextColor3=C.muted
        end
    end
end
local function serverKey(id)
    return tostring(id or "")
end
local function addServer(s)
    if type(s)~="table" or type(s.id)~="string" or s.id=="" then return end
    for _,old in ipairs(serverItems) do
        if old.id==s.id then
            old.playing=s.playing or old.playing
            old.maxPlayers=s.maxPlayers or old.maxPlayers
            old.ping=s.ping or old.ping
            return
        end
    end
    serverItems[#serverItems+1]=s
end
local function getVisible()
    local out={}
    for _,s in ipairs(serverItems) do
        if (not filtered) or observed(s.id) then out[#out+1]=s end
    end
    table.sort(out,function(a,b)
        local ah,bh=observed(a.id),observed(b.id)
        if (ah~=nil)~=(bh~=nil) then return ah~=nil end
        if ah and bh then return (ah.items[1].value or 0)>(bh.items[1].value or 0) end
        return (tonumber(a.playing) or 0)<(tonumber(b.playing) or 0)
    end)
    return out
end
local function redraw()
    local view=getVisible()
    local pages=math.max(1,math.ceil(#view/4))
    page=math.max(1,math.min(page,pages))
    pageText.Text="PAGE "..page.." / "..pages
    for i,cell in ipairs(rows) do
        local s=view[(page-1)*4+i]
        cell.server=s
        cell.frame.Visible=s~=nil
        if s then
            local hit=observed(s.id)
            local players=tostring(s.playing or "?").."/"..tostring(s.maxPlayers or "?")
            if hit and #hit.items>0 then
                local best=hit.items[1]
                cell.name.Text=best.name.."   ·   "..format(best.value).." S"
                cell.name.TextColor3=C.positive
                local extra={}
                for j=2,math.min(#hit.items,3) do
                    local thing=hit.items[j]
                    extra[#extra+1]=thing.name.." "..format(thing.value)
                end
                cell.detail.Text=#extra>0 and table.concat(extra," · ")
                    or ("Seen "..math.floor((os.time()-hit.at)/60).."m ago  •  "..players.." players")
            else
                cell.name.Text="UNSCANNED   /   #"..idShort(s.id)
                cell.name.TextColor3=C.fg
                cell.detail.Text=players.." players  ·  ping "..tostring(math.floor(tonumber(s.ping) or 0)).."ms"
            end
            cell.join.Text=s.id==game.JobId and "HERE" or "JOIN"
            cell.join.Active=s.id~=game.JobId
            cell.join.BackgroundTransparency=s.id==game.JobId and .55 or .06
        end
    end
    seenFilter.Text=filtered and "ALL" or "SEEN"
    subTitle.Text=filtered and "OBSERVED ON PREVIOUS VISITS  /  NOT LIVE" or "PUBLIC SERVERS  /  UNVERIFIED UNTIL VISITED"
    info.Text=tostring(#view).." servers  •  "..(autoReload and "AUTO-QUEUE READY" or "MANUAL REINJECT REQUIRED")
end

local function encode(s)
    return tostring(s):gsub("([^%w%-%._~])",function(c)
        return string.format("%%%02X",string.byte(c)) end)
end
local function loadServers(restart)
    if busy then return end
    if restart then
        serverItems={}; cursor=nil;page=1
        -- Cached servers are historical: show them, but never claim they are still populated.
        for id,_ in pairs(seenServers) do
            if observed(id) then addServer({id=id,playing="?",maxPlayers="?",cached=true}) end
        end
    end
    busy=true; message.Text="Loading public servers...";message.TextColor3=C.muted
    task.spawn(function()
        local url="https://games.roblox.com/v1/games/"..PLACE_ID.."/servers/Public?limit=50&sortOrder=Asc"
        if cursor and cursor~="" then url=url.."&cursor="..encode(cursor) end
        local data=readJson(fetch(url))
        if not alive then return end
        busy=false
        if not data or type(data.data)~="table" then
            message.Text="Server API blocked. Paste JobId to join."
            redraw()
            return
        end
        for _,s in ipairs(data.data) do
            if type(s)=="table" and type(s.id)=="string" and tonumber(s.playing)
                and tonumber(s.maxPlayers) and tonumber(s.playing)<tonumber(s.maxPlayers) then
                addServer(s)
            end
        end
        cursor=type(data.nextPageCursor)=="string" and data.nextPageCursor or nil
        page=math.max(1,math.ceil(#getVisible()/4))
        message.Text=cursor and "More pages available" or "End of public server list"
        redraw()
    end)
end
local function joinServer(s)
    local id=type(s)=="table" and s.id or tostring(s or "")
    id=trim(id)
    if id=="" or id==game.JobId then message.Text="Already on this server";return end
    if not id:match("^[%x%-]+$") or #id<25 or #id>64 then
        message.Text="Invalid server JobId";return
    end
    if type(s)=="table" and tonumber(s.playing) and tonumber(s.maxPlayers)
        and tonumber(s.playing)>=tonumber(s.maxPlayers) then
        message.Text="Server is full. Refresh.";return
    end
    message.Text="Joining #"..idShort(id).."..."
    if type(queueFunc)=="function" then autoReload=queueAgain() end
    local ok,err=pcall(function() TeleportService:TeleportToPlaceInstance(PLACE_ID,id,player) end)
    if not ok then message.Text="Join error: "..tostring(err):sub(1,65) end
end
-- Show a concrete error when Roblox rejects a join request.
pcall(function()
    conn(TeleportService.TeleportInitFailed,function(who,kind,detail)
        if who==player then
            browser.Visible=true
            message.Text="Teleport failed: "..tostring(detail or kind):sub(1,72)
        end
    end)
end)
for _,r in ipairs(rows) do conn(r.join.MouseButton1Click,function()joinServer(r.server)end)end
conn(manualJoin.MouseButton1Click,function()joinServer(directInput.Text)end)
conn(launcher.MouseButton1Click,function()
    browser.Visible=not browser.Visible
    if browser.Visible then
        fitViewport();scanCurrent()
        if #serverItems==0 then loadServers(true) else redraw() end
    end
end)
conn(close.MouseButton1Click,function()browser.Visible=false end)
conn(refresh.MouseButton1Click,function()loadServers(true)end)
conn(seenFilter.MouseButton1Click,function()filtered=not filtered;page=1;redraw()end)
conn(nextB.MouseButton1Click,function()
    local total=#getVisible()
    if page*4<total then page=page+1;redraw()
    elseif cursor and not filtered then loadServers(false)
    else message.Text="No more servers in this list" end
end)
conn(prev.MouseButton1Click,function()page=math.max(1,page-1);redraw()end)

local badges=setmetatable({}, {__mode="k"})
local function badgeFor(slot)
    local b=badges[slot]
    if b and b.Parent==slot then return b end
    b=mk("TextLabel",{Name="CarbonValue",Text="",Font=Enum.Font.GothamBold,
        TextSize=9,TextColor3=C.fg,BackgroundColor3=C.bg,BackgroundTransparency=.13,
        BorderSizePixel=0,AnchorPoint=Vector2.new(1,1),
        Position=UDim2.new(1,-3,1,-3),Size=UDim2.new(0,92,0,17),
        TextXAlignment=Enum.TextXAlignment.Center,TextTruncate=Enum.TextTruncate.AtEnd,
        ZIndex=75,Active=false,Selectable=false,Visible=false},slot)
    rounded(b,5);outlined(b,.8)
    badges[slot]=b
    created[#created+1]=b
    return b
end
local function countOffer(offer)
    local container=find(offer,"Container")
    local out={supreme=0,mm2=0,missingSupreme=0,missingMM2=0,top=nil,rare={}}
    if not container then return out end
    for i=1,4 do
        local slot=find(container,"NewItem"..i)
        if slot then
            local tag=badgeFor(slot)
            local name,count
            if isVisible(slot) then name,count=readable(slot) end
            if name then
                local row=lookup(name)
                local s=row and row.supreme
                local m=safeMM2(row)
                if s and m and s>0 and m>0 and math.max(s,m)/math.min(s,m)>8 then m=nil end
                if s then out.supreme=out.supreme+s*count else out.missingSupreme=out.missingSupreme+count end
                if m then out.mm2=out.mm2+m*count else out.missingMM2=out.missingMM2+count end
                if s and s>=RARE_THRESHOLD then
                    out.rare[#out.rare+1]={name=name,value=s}
                    if not out.top or out.top.value<s then out.top={name=name,value=s} end
                end
                local width=slot.AbsoluteSize and slot.AbsoluteSize.X or 95
                if width>0 and width<92 then
                    tag.Size=UDim2.new(0,math.max(37,width-5),0,16)
                    tag.Text="S "..format(s)
                else
                    tag.Size=UDim2.new(0,110,0,17)
                    tag.Text="S "..format(s).."  M "..format(m)
                end
                tag.TextColor3=s and C.fg or C.amber
                tag.Visible=true
            else
                tag.Visible=false
            end
        end
    end
    return out
end
local function countText(value,missing)
    return missing>0 and (format(value).."+?") or format(value)
end
local function updateTrade(screen)
    local trade=nested(screen,"Container","Trade")
    if not trade or not isVisible(trade) then return false end
    local our=trade:FindFirstChild("YourOffer")
    local theirs=trade:FindFirstChild("TheirOffer")
    if not our or not theirs or not isVisible(our) or not isVisible(theirs) then return false end
    local mine=countOffer(our)
    local other=countOffer(theirs)
    for _,item in ipairs(other.rare) do remember(item.name,item.value,"trade") end
    ownLabel.Text="YOU       S "..countText(mine.supreme,mine.missingSupreme).."     M "..countText(mine.mm2,mine.missingMM2)
    themLabel.Text="THEM    S "..countText(other.supreme,other.missingSupreme).."     M "..countText(other.mm2,other.missingMM2)
    ageLabel.Text=(supremeStale and "S: OLD" or "S: OK").."  "..(mm2Stale and "M: OLD" or "M: OK")
    if not loaded then
        deltaLabel.Text="Loading prices...";deltaLabel.TextColor3=C.amber
    elseif mine.missingSupreme>0 or other.missingSupreme>0 then
        deltaLabel.Text="Δ    INCOMPLETE";deltaLabel.TextColor3=C.amber
    else
        local d=other.supreme-mine.supreme
        deltaLabel.Text="Δ    "..(d>0 and "+" or "")..format(d).." S"
        deltaLabel.TextColor3=(d>0 and C.positive or (d<0 and C.negative or C.muted))
    end
    hud.Visible=true
    return true
end

local toast=panel(root,"SuccessToast",UDim2.new(0,235,0,50),UDim2.new(1,-13,0,94))
toast.AnchorPoint=Vector2.new(1,0)
local tIcon=textLabel(toast,"Mark","✓",UDim2.new(0,13,0,6),UDim2.new(0,27,0,36),24,true,C.positive)
local tTitle=textLabel(toast,"Text","TRADE COMPLETED",UDim2.new(0,42,0,6),UDim2.new(1,-52,0,19),12,true,C.fg)
local tSub=textLabel(toast,"Subtitle","Confirmed by game UI",UDim2.new(0,42,0,26),UDim2.new(1,-52,0,16),10,false,C.muted)
local toastToken=0
local patterns={"trade successful","trade completed","trade complete","successfully traded",
    "обмен завершен","обмен завершён"}
local function successTextVisible()
    local children=playerGui:GetDescendants()
    for i=1,math.min(#children,600) do
        local node=children[i]
        if (node:IsA("TextLabel") or node:IsA("TextButton"))
            and not node:IsDescendantOf(root) and isVisible(node) then
            local value=trim(node.Text):lower()
            if #value<100 then
                for _,p in ipairs(patterns) do
                    if value:find(p,1,true) then return true end
                end
            end
        end
    end
    return false
end
local function successToast()
    toastToken=toastToken+1
    local current=toastToken
    toast.Visible=true
    toast.BackgroundTransparency=.88
    pcall(function()
        TweenService:Create(toast,TweenInfo.new(.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
            {BackgroundTransparency=.14}):Play()
    end)
    task.spawn(function()
        task.wait(2.7)
        if alive and toastToken==current then toast.Visible=false end
    end)
end

local tradeOpen=false
local awaitingSuccess=0
local scanTicks=0
local inFlight=false
local function tradePulse()
    local opened=false
    for _,screenName in ipairs({"TradeGUI","TradeGUI_Phone"}) do
        local screen=find(playerGui,screenName)
        if screen and validScreen(screen) then
            local ok,yes=pcall(updateTrade,screen)
            if ok and yes then opened=true end
        end
    end
    if not opened and tradeOpen then awaitingSuccess=15 end
    if opened then awaitingSuccess=0 end
    tradeOpen=opened
    if not opened then hud.Visible=false end
    if awaitingSuccess>0 then
        if successTextVisible() then successToast();awaitingSuccess=0
        else awaitingSuccess=awaitingSuccess-1 end
    end
end

task.spawn(function()
    pcall(loadPrices)
    while alive do
        pcall(tradePulse)
        scanTicks=scanTicks+1
        if scanTicks%6==0 then pcall(scanCurrent) end
        task.wait(.35)
    end
end)
task.spawn(function()
    while alive do
        task.wait(1200)
        if alive then pcall(loadPrices) end
    end
end)
redraw()
env.MM2CarbonState=function()
    return {version=5,loaded=loaded,supremeDate=supremeStamp,mm2Date=mm2Stamp,
        observedServers=seenServers,listedServers=#serverItems,autoReload=autoReload}
end

end, function(err)
    if debug and type(debug.traceback) == "function" then return debug.traceback(tostring(err),2) end
    return tostring(err)
end)
if not ok then
    warn("[MM2 Carbon Trade] " .. tostring(failure))
    pcall(function()
        local pg = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui",5)
        if not pg then return end
        local old = pg:FindFirstChild("MM2CarbonError")
        if old then old:Destroy() end
        local g = Instance.new("ScreenGui")
        g.Name = "MM2CarbonError"
        g.ResetOnSpawn = false
        g.DisplayOrder = 10001
        g.Parent = pg
        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(0,300,0,72)
        t.Position = UDim2.new(.5,-150,0,64)
        t.BackgroundColor3 = Color3.fromRGB(27,29,30)
        t.BackgroundTransparency = .12
        t.TextColor3 = Color3.fromRGB(238,214,211)
        t.TextWrapped = true
        t.TextSize = 13
        t.Font = Enum.Font.Gotham
        t.Text = "CARBON FAILED\n" .. tostring(failure):sub(1,220)
        t.Parent = g
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0,10)
        c.Parent = t
    end)
end
