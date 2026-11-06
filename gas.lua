--[[
    ANCH HUB | GrowBlox  (v11 Ultimate - All-in-One WindUI)
    Gabungan penuh ANCH Hub + SkyP v1.2 Engine (ByteNet & Classic Compatible)

    Daftar Perintah Chat (Prefix default "/"):
      wld|wd <jumlah>             Drop World Lock
      tp|warp <world>             Pindah world
      pos1 | pos2                 Simpan posisi sekarang
      win1|w1 | win2|w2 [jumlah]  Teleport ke Pos 1 / Pos 2 (+opsional drop WL)
      pos                         Lihat posisi sekarang & pos tersimpan
      rejoin|rj                   Masuk ulang ke world ini
      noclip [on|off]             Fly + tembus blok (+ tombol layar ▲/▼)
      unlimitedjump|uj            Lompat di udara tanpa batas
      blink [on|off]              Warna skin berganti otomatis
      longhand|lh [n|off]         Jangkauan punch/build lebih jauh
      visualitem|vi               GUI item visual (lokal)
      settingsgb|sgb              GUI pengaturan
      afk                         Anti-AFK
      autorejoin|arj              Rejoin otomatis kalau disconnect
      session|sesi                GUI sesi (simpan & pulihkan otomatis)
      af|autofarm [on|off]        Auto Farm (Multi-target, Rayman, Grid 5x5)
      ac|autoclear [on|off]       Auto Clear World (ModFly Always On + Stand Above Block)
      ah|autoharvest [on|off]     Auto Harvest & Auto Plant (Farmer)
      adf|autodf [on|off]         Auto Dirt Farm (Full World Builder + Smart Supply)
      as|autosplice [on|off]      Auto Splice (Seed A + Seed B, Roam A* / Grid)
      pabrik|factory [on|off]     Pabrik Seed (Panen -> Tanam -> Break -> Auto Drop)
      guard|penjaga [on|off]      Anti-Mod / Staff & Player Detector
      chat|autochat [on|off]      Auto Chat / Spammer (1 Pesan)
      ctp|clicktp [on|off]        Click TP (Legit A* / Fly / Mix)
      move|mv <legit|walk|fly|mix> Ubah mode pergerakan
      aq|autoquest [on|off|scan]  Auto Quest
      gs|growscan                 Buka GrowScan
      god [on|off]                God Mode (kebal lava, spike, api)
      lite [on|off]               Mode Lite (matikan partikel & suara)
      blockid|bid <nama>          Cari ID block dari nama
      hpx                         Daftar perintah
]]

----------------------------------------------------------------------
-- SESI & CEGAH DOBEL EKSEKUSI (DENGAN CLEANUP OTOMATIS)
----------------------------------------------------------------------
local G = (getgenv and getgenv()) or _G
for _, key in ipairs({ "__ANCHHubSession", "__Alfian", "__GTFarm" }) do
    if G[key] and G[key].Cleanup then
        pcall(G[key].Cleanup)
    end
    G[key] = nil
end

local Session = { Alive = true, Connections = {} }
G.__ANCHHubSession = Session
G.ANCHHubGB_Loaded = os.clock()

local function alive()
    return Session.Alive and G.__ANCHHubSession == Session
end

local function trackConn(conn)
    if conn then
        table.insert(Session.Connections, conn)
    end
    return conn
end

----------------------------------------------------------------------
-- SERVICES & MODULE GAME
----------------------------------------------------------------------
local cloneref = (cloneref or clonereference or function(instance)
    return instance
end)

local Players = cloneref(game:GetService("Players"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local StarterGui = cloneref(game:GetService("StarterGui"))
local GuiService = cloneref(game:GetService("GuiService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local HttpService = cloneref(game:GetService("HttpService"))
local TweenService = cloneref(game:GetService("TweenService"))
local RunService = cloneref(game:GetService("RunService"))
local TeleportService = cloneref(game:GetService("TeleportService"))
local VirtualUser = cloneref(game:GetService("VirtualUser"))
local TextChatService = cloneref(game:GetService("TextChatService"))
local TextService = cloneref(game:GetService("TextService"))

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
local WorldRemotes = ReplicatedStorage:WaitForChild("WorldRemotes", 10)
local DropEvent = WorldRemotes and WorldRemotes:WaitForChild("DropItem", 5)
local SetTileRemote = WorldRemotes and WorldRemotes:FindFirstChild("SetTile")
local TakeDropRemote = WorldRemotes and WorldRemotes:FindFirstChild("TakeDrop")
local PickTitleRemote = WorldRemotes and WorldRemotes:FindFirstChild("PickTitle")
local WorldClosedRemote = WorldRemotes and WorldRemotes:FindFirstChild("WorldClosed")

local ItemDB = Shared and require(Shared:WaitForChild("ItemDB", 5)) or {}
local InvModOk, InventoryModule = pcall(function() return require(Shared:WaitForChild("Inventory", 5)) end)
local NetOk, Net = pcall(function() return require(Shared:WaitForChild("Net", 5)) end)
local RolesOk, RolesModule = pcall(function() return require(Shared:FindFirstChild("Roles")) end)
local SfxOk, SfxModule = pcall(function() return require(Shared:FindFirstChild("Sfx")) end)
local SpliceOk, SpliceModule = pcall(function() return require(Shared:FindFirstChild("Splice")) end)

local GameGui = PlayerGui:WaitForChild("GameGui", 10)
local ParticlesOk, ParticlesModule = pcall(function() return require(GameGui:WaitForChild("Particles", 5)) end)
local MenuModOk, MenuModule = pcall(function() return require(GameGui:WaitForChild("WorldMenu", 5)) end)

----------------------------------------------------------------------
-- CONFIG & STATE GLOBAL
----------------------------------------------------------------------
local CONFIG_FILE = "ANCHHub_GrowBlox.json"
local REJOIN_FILE = "ANCHHub_Rejoin_" .. tostring(Player.UserId) .. ".json"
local SCRIPT_FILE = "ANCHHub_GrowBlox.lua"
local MAX_AMOUNT = 10000
local COOLDOWN = 0.3
local PLACE_GUARD = 0.34

local Config = {
    prefix = "/",
    dropId = 242,
    longhandRange = 3,
    blinkMin = 0.2,
    blinkMax = 0.5,
    winDrop = 0,
    pos1 = {},
    pos2 = {},
    -- Sesi & Reconnect
    autoRestore = true,
    autoReload = true,
    autoWarp = false,
    launcher = true,
    lastWorld = "",
    scriptUrl = "",
    session = {},
    reconnectOn = false,
    reconnectWorld = true,
    reconnectServer = true,
    reconnectKeep = false,
    reconnectDelay = 5,
    targetWorld = "",
    -- Karakter & Misc
    walkSpeed = 100,
    mutePunch = true,
    liteMode = false,
    customWatermark = true,
    watermarkText = "ANCH HUB",
    selectedRole = "none",
    calibX = 0,
    calibY = 0,
    -- Auto Collect Global
    collectAround = false,
    collectRadius = 3,
    -- Auto Farm
    farmMode = "Place + Break",
    farmPlaceMs = 250,
    farmDelay = 0.22,
    farmAfterBreakMs = 300,
    farmMultiTarget = 1,
    farmHitsOverride = 0,
    farmBreakBg = true,
    farmPlaceId = 2,
    farmGrid = { ["1,0"] = true },
    farmTake = true,
    -- Auto Clear World (ModFly Always On + Berdiri di atas blok)
    clearSweep = "Zig-zag",
    clearIncludeBg = true,
    clearBreakDelay = 0.16,
    clearTpDelay = 0.22,
    clearTake = true,
    clearModFly = true,
    -- Farmer (Auto Harvest + Auto Plant)
    harvestDoHarvest = true,
    harvestDoPlant = false,
    harvestSeedId = 3,
    harvestUseBlock = true,
    harvestScaffoldId = 2,
    harvestDelay = 0.22,
    harvestPlantDelay = 0.25,
    harvestTpDelay = 0.30,
    harvestTake = true,
    harvestModFly = false,
    -- Auto Dirt Farm (DF Full World)
    dfBreakDelay = 0.15,
    dfTpDelay = 0.30,
    dfTake = true,
    dfModFly = false,
    dfReplacePlatform = true,
    -- Auto Splice
    spliceA = 3,
    spliceB = 5,
    spliceRoam = true,
    spliceMs = 300,
    -- Pabrik (Factory)
    pabrikSeedId = 3,
    pabrikWholeWorld = true,
    pabrikTiles = { ["1,0"] = true },
    pabrikBreakX = -1,
    pabrikBreakY = -1,
    pabrikBreakSec = 60,
    pabrikDrop = true,
    pabrikKeep = 50,
    pabrikDropAt = 200,
    pabrikDropWorld = "",
    pabrikDropX = -1,
    pabrikDropY = -1,
    -- Tas (Auto Recycle & Auto Convert Lock)
    trashOn = false,
    trashList = {},
    trashAt = 150,
    trashKeep = 0,
    convertLockOn = false,
    -- Navigasi / Pathfinding
    moveMode = "legit",
    navSpeed = 1,
    moveStepDelay = 0.30,
    clickTpShift = false,
    -- Penjaga (Anti-Mod / Staff)
    guardWho = "Staff (Mod/Dev)",
    guardStopAll = true,
    guardLeave = false,
    guardAutoBack = true,
    guardBackSec = 60,
    guardCalmSec = 5,
    -- Auto Chat (1 Pesan)
    chatText = "",
    chatInterval = 6,
    -- Bonus
    bonusAutoQuest = false,
    bonusAutoRedeem = false,
    -- GrowScan
    scanAuto = false,
    scanLayer = "Semua",
    scanFilter = "",
    -- Discord Webhook
    webhookOn = false,
    webhookUrl = "",
    webhookReportMin = 0,
    whPenjaga = true,
    whStop = true,
    whFull = true,
    whBonus = true,
    whRejoin = true,
    whPabrik = true,
}

local function LoadConfig()
    pcall(function()
        if isfile and readfile and isfile(CONFIG_FILE) then
            local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
            for key, value in pairs(data) do
                if Config[key] ~= nil and type(value) == type(Config[key]) then
                    Config[key] = value
                end
            end
        end
    end)
end

local function SaveConfig()
    pcall(function()
        if writefile then
            writefile(CONFIG_FILE, HttpService:JSONEncode(Config))
        end
    end)
end

LoadConfig()

----------------------------------------------------------------------
-- REFERENSI INTERNAL GAME (getgc) & KONTROL INPUT FISIK (WorldMenu.isDown)
----------------------------------------------------------------------
local getgcFn = getgc or (debug and debug.getgc)
local getupvalueFn = (debug and debug.getupvalue) or getupvalue
local setupvalueFn = (debug and debug.setupvalue) or setupvalue
local getconstsFn = (debug and debug.getconstants) or getconstants

local function GetUpvalues(fn)
    if debug and debug.getupvalues then
        local ok, ups = pcall(debug.getupvalues, fn)
        if ok and type(ups) == "table" then
            return ups
        end
    end
    local list = {}
    if getupvalueFn then
        for i = 1, 255 do
            local ok, value = pcall(getupvalueFn, fn, i)
            if not ok then
                break
            end
            list[i] = value
        end
    end
    return list
end

local function Trim(text)
    return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local ToastHook = nil
local function Notify(message, title, duration)
    if ToastHook then
        local ok = pcall(ToastHook, tostring(message), title, duration)
        if ok then
            return
        end
    end
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title or "ANCH HUB | GrowBlox",
            Text = tostring(message),
            Duration = duration or 4,
        })
    end)
end

local Refs = {
    World = nil,
    Inv = nil,
    InvTable = nil,
    SetTile = nil,
    Punch = nil,
    State = nil,
    Menu = nil,
    Gems = nil,
    Hud = nil,
    Trees = nil,
    Others = nil,
    Rigs = nil,
    Particles = {},
}

local Drops = { list = nil, update = nil }
local DropFailUntil = {}
local PlacedAt = {}
local HitCount = {}
local InvChangedConn = nil
local OnInventoryChanged = nil

-- Statistik Sesi & Discord Webhook
local Stats = {
    T0 = os.clock(),
    Gems0 = nil,
    Placed = 0,
    Broken = 0,
    Collected = 0,
    Harvested = 0,
    Planted = 0,
    Items = {},
}

local Webhook = {
    Queue = {},
    LastFull = {},
    Status = "-",
}

do (function()
    local function getRequestFn()
        return (syn and syn.request) or (http and http.request) or http_request or request or (fluxus and fluxus.request)
    end

    function Webhook.Valid(url)
        url = tostring(url or "")
        for _, host in ipairs({ "discord.com", "discordapp.com", "ptb.discord.com", "canary.discord.com" }) do
            if string.sub(url, 1, #host + 22) == "https://" .. host .. "/api/webhooks/" then
                return true
            end
        end
        return false
    end

    function Webhook.Send(category, message)
        if not Config.webhookOn or not Webhook.Valid(Config.webhookUrl) then return end
        local allowed = category == "test"
            or category == "report"
            or (category == "penjaga" and Config.whPenjaga)
            or (category == "stop" and Config.whStop)
            or (category == "full" and Config.whFull)
            or (category == "bonus" and Config.whBonus)
            or (category == "rejoin" and Config.whRejoin)
            or (category == "pabrik" and Config.whPabrik)
        if not allowed or #Webhook.Queue >= 20 then return end
        table.insert(Webhook.Queue, tostring(message))
    end

    task.spawn(function()
        while alive() do
            local msg = table.remove(Webhook.Queue, 1)
            if not msg then
                task.wait(0.5)
            else
                local req = getRequestFn()
                if not req then
                    Webhook.Status = "Executor tidak mendukung request HTTP"
                else
                    local body = HttpService:JSONEncode({
                        username = "ANCH Hub | GrowBlox",
                        content = string.format("**[%s]** %s", Player.Name, msg),
                    })
                    local ok, res = pcall(req, {
                        Url = Config.webhookUrl,
                        Method = "POST",
                        Headers = { ["Content-Type"] = "application/json" },
                        Body = body,
                    })
                    local code = ok and type(res) == "table" and tonumber(res.StatusCode or res.Status) or nil
                    if ok and (code == nil or code < 300) then
                        Webhook.Status = "Terkirim " .. os.date("%H:%M:%S")
                    else
                        Webhook.Status = "Gagal kirim (" .. tostring(code or res) .. ")"
                    end
                end
                task.wait(2.5)
            end
        end
    end)
end)() end

-- Input buatan untuk Legit Walking & FlyPad
local AutoInput = { active = false, left = false, right = false, jump = false, down = false }
local FlyPadState = { up = false, down = false }
local OrigIsDown = nil

local function ReleaseInput()
    AutoInput.left, AutoInput.right, AutoInput.jump, AutoInput.down = false, false, false, false
end

if MenuModOk and type(MenuModule) == "table" and type(rawget(MenuModule, "isDown")) == "function" then
    OrigIsDown = rawget(MenuModule, "isDown")
    MenuModule.isDown = function(saved, key, ...)
        if AutoInput.active then
            if key == "keyLeft" then return AutoInput.left end
            if key == "keyRight" then return AutoInput.right end
            if key == "keyJump" then return AutoInput.jump end
            if key == "keyDown" then return AutoInput.down end
        end
        if FlyPadState.up and key == "keyJump" then return true end
        if FlyPadState.down and key == "keyDown" then return true end
        return OrigIsDown(saved, key, ...)
    end
end

do (function()
    local function isSetTileFn(fn)
        if not getconstsFn or (islclosure and not islclosure(fn)) then return false end
        local ok, consts = pcall(getconstsFn, fn)
        if not ok or type(consts) ~= "table" then return false end
        local hasSend, hasPlaced, hasFlips = false, false, false
        for _, c in pairs(consts) do
            if c == "tile" or c == "SetTile" then hasSend = true
            elseif c == "placedAt" then hasPlaced = true
            elseif c == "flips" then hasFlips = true end
        end
        return hasSend and hasPlaced and hasFlips
    end

    local function isPunchFn(fn)
        if not getconstsFn or (islclosure and not islclosure(fn)) then return false end
        local ok, consts = pcall(getconstsFn, fn)
        if not ok or type(consts) ~= "table" then return false end
        local hasVend, hasMark = false, false
        for _, c in pairs(consts) do
            if c == "Empty the Vending Machine first!" then hasVend = true
            elseif c == "newCrack" or c == "HarvestProvider" then hasMark = true end
        end
        return hasVend and hasMark
    end

    local function isStateHolder(v)
        local fn = rawget(v, "state")
        if type(fn) ~= "function" then return false end
        local ok, s = pcall(fn)
        return ok and type(s) == "table" and type(s.x) == "number" and type(s.y) == "number"
            and s.facing ~= nil and s.vx ~= nil
    end

    local function isGameFn(fn)
        if fn == isSetTileFn or fn == isPunchFn then return false end
        if isexecutorclosure then
            local ok, res = pcall(isexecutorclosure, fn)
            if ok and res then return false end
        end
        return true
    end

    local function isDropList(t)
        if type(t) ~= "table" or t == Refs.World then return false end
        local first = rawget(t, 1)
        if first == nil then return next(t) == nil end
        return type(first) == "table" and rawget(first, "uid") ~= nil and rawget(first, "frame") ~= nil
    end

    function Refs.Scan()
        if not getgcFn then return false end
        Refs.World, Refs.Inv, Refs.InvTable, Refs.SetTile, Refs.Punch, Refs.State, Refs.Menu, Refs.Gems, Refs.Hud, Refs.Others =
            nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
        Refs.Particles = {}
        for _, v in ipairs(getgcFn(true)) do
            local tv = type(v)
            if tv == "table" then
                if not Refs.World then
                    local ok, valid = pcall(function()
                        return type(rawget(v, "fg")) == "table" and type(rawget(v, "bg")) == "table"
                            and type(rawget(v, "w")) == "number" and type(rawget(v, "h")) == "number"
                            and rawget(v, "spawn") ~= nil
                    end)
                    if ok and valid then Refs.World = v end
                end
                if not Refs.InvTable then
                    local ok, valid = pcall(function()
                        return type(rawget(v, "onDrop")) == "function"
                            and type(rawget(v, "canDrop")) == "function"
                            and type(rawget(v, "isWorn")) == "function"
                    end)
                    if ok and valid then
                        Refs.InvTable = v
                        Refs.Hud = Refs.Hud or v
                    end
                end
                if not Refs.Inv and InvModOk and InventoryModule then
                    local ok, valid = pcall(function()
                        return getmetatable(v) == InventoryModule and type(rawget(v, "slots")) == "table"
                    end)
                    if ok and valid then Refs.Inv = v end
                end
                if not Refs.State then
                    local ok, valid = pcall(isStateHolder, v)
                    if ok and valid then Refs.State = rawget(v, "state") end
                end
                if not Refs.Menu then
                    local ok, valid = pcall(function()
                        return type(rawget(v, "openBackpack")) == "function" and type(rawget(v, "ui")) == "table"
                    end)
                    if ok and valid then Refs.Menu = v end
                end
                if not Refs.Gems then
                    local ok, valid = pcall(function() return type(rawget(v, "addGems")) == "function" end)
                    if ok and valid then Refs.Gems = v end
                end
                if not Refs.Hud then
                    local ok, valid = pcall(function()
                        return type(rawget(v, "punchRange")) == "function" and type(rawget(v, "buildRange")) == "function"
                    end)
                    if ok and valid then Refs.Hud = v end
                end
                if not Refs.Others then
                    local ok, valid = pcall(function()
                        return type(rawget(v, "list")) == "function" and type(rawget(v, "where")) == "function"
                            and type(rawget(v, "playerAt")) == "function"
                    end)
                    if ok and valid then Refs.Others = v end
                end
                if not Refs.Rigs then
                    local ok, valid = pcall(function()
                        local a, b = rawget(v, 1), rawget(v, -1)
                        return type(a) == "table" and type(b) == "table"
                            and typeof(rawget(a, "body")) == "Instance"
                            and typeof(rawget(b, "head")) == "Instance"
                    end)
                    if ok and valid then Refs.Rigs = v end
                end
                if ParticlesOk and ParticlesModule then
                    local ok, valid = pcall(function()
                        return getmetatable(v) == ParticlesModule and type(rawget(v, "live")) == "table"
                    end)
                    if ok and valid then table.insert(Refs.Particles, v) end
                end
            elseif tv == "function" and isGameFn(v) then
                if not Refs.SetTile and isSetTileFn(v) then
                    Refs.SetTile = v
                elseif not Refs.Punch and isPunchFn(v) then
                    Refs.Punch = v
                end
            end
        end

        if Refs.World and (not Refs.SetTile or not Refs.Punch) and debug and debug.info then
            for _, fn in ipairs(getgcFn(true)) do
                if type(fn) == "function" then
                    local okN, fnName = pcall(debug.info, fn, "n")
                    if okN and (fnName == "setTile" or fnName == "hit") then
                        for _, up in pairs(GetUpvalues(fn)) do
                            if up == Refs.World then
                                if fnName == "setTile" and not Refs.SetTile then Refs.SetTile = fn end
                                if fnName == "hit" and not Refs.Punch then Refs.Punch = fn end
                            end
                        end
                    end
                end
            end
        end

        if not Refs.Inv and Refs.World and type(rawget(Refs.World, "backpackNow")) == "function" then
            for _, u in pairs(GetUpvalues(Refs.World.backpackNow)) do
                if type(u) == "table" and type(u.slots) == "table" then
                    Refs.Inv = u
                    break
                end
            end
        end

        -- Hook Inventory changed event
        if InvChangedConn then pcall(function() InvChangedConn:Disconnect() end); InvChangedConn = nil end
        if Refs.Inv and typeof(Refs.Inv.changed) == "Instance" then
            InvChangedConn = trackConn(Refs.Inv.changed.Event:Connect(function()
                if alive() and OnInventoryChanged then
                    pcall(OnInventoryChanged)
                end
            end))
        end

        Drops.list, Drops.update = nil, nil
        local wd = Refs.World and rawget(Refs.World, "dropTaken")
        if type(wd) == "function" then
            for _, u in pairs(GetUpvalues(wd)) do
                if not Drops.list and isDropList(u) then Drops.list = u
                elseif not Drops.update and type(u) == "function" then Drops.update = u end
            end
        end
        if not Drops.list and Refs.World and type(rawget(Refs.World, "dropList")) == "function" then
            local okL, l = pcall(Refs.World.dropList)
            if okL and type(l) == "table" then Drops.list = l end
        end

        Refs.Trees = nil
        if Refs.World and type(rawget(Refs.World, "treeLook")) == "function" and getupvalueFn then
            local okT, tMap = pcall(getupvalueFn, Refs.World.treeLook, 8)
            if okT and type(tMap) == "table" then
                Refs.Trees = tMap
            end
        end
        local evTree = WorldRemotes and WorldRemotes:FindFirstChild("TreeChanged")
        if not Refs.Trees and evTree and getconnections then
            local okC, conns = pcall(getconnections, evTree.OnClientEvent)
            if okC and type(conns) == "table" then
                for _, c in ipairs(conns) do
                    local okF, fn = pcall(function() return c.Function end)
                    if okF and type(fn) == "function" then
                        for _, u in pairs(GetUpvalues(fn)) do
                            if type(u) == "table" and u ~= Refs.World and rawget(u, "fg") == nil then
                                local _, sample = next(u)
                                if sample == nil or (type(sample) == "table" and type(rawget(sample, "p")) == "number") then
                                    Refs.Trees = u
                                    break
                                end
                            end
                        end
                    end
                    if Refs.Trees then break end
                end
            end
        end

        return Refs.World ~= nil
    end
end)() end

local function FindWorld()
    if Refs.World and type(rawget(Refs.World, "fg")) == "table" then
        return Refs.World
    end
    Refs.Scan()
    return Refs.World
end

local function FindInventory()
    if Refs.InvTable then
        return Refs.InvTable
    end
    Refs.Scan()
    return Refs.InvTable
end

local function FindRigs()
    if Refs.Rigs then
        return Refs.Rigs
    end
    Refs.Scan()
    return Refs.Rigs
end

local function ItemName(id)
    local it = ItemDB and ItemDB[id]
    return (type(it) == "table" and type(it.name) == "string") and it.name or ("Item #" .. tostring(id))
end

local function CountItem(id)
    if not id then return 0 end
    if not Refs.Inv then Refs.Scan() end
    local bag = Refs.Inv
    if not bag then return 0 end
    if type(bag.count) == "function" then
        local ok, n = pcall(function() return bag:count(id) end)
        if ok and type(n) == "number" then return n end
    end
    local total = 0
    if type(bag.slots) == "table" then
        for _, slot in pairs(bag.slots) do
            if type(slot) == "table" and slot.id == id then
                total += (slot.n or 0)
            end
        end
    end
    return total
end

local function SeedOfBlock(blockId)
    local it = blockId and ItemDB[blockId]
    if not it then return nil end
    local sid = it.seedId or (blockId + 1)
    local sit = ItemDB[sid]
    return (sit and sit.kind == "seed") and sid or nil
end

local function BlockOfSeed(seedId)
    if not seedId then return nil end
    local bid = seedId - 1
    local bit = ItemDB[bid]
    if bit and bit.kind ~= "seed" and (bit.seedId == nil or bit.seedId == seedId) then
        return bid
    end
    return nil
end

local cachedDirtId = nil
local function GetDirtId()
    if cachedDirtId then return cachedDirtId end
    if ItemDB[2] and type(ItemDB[2].name) == "string" and ItemDB[2].name:lower() == "dirt" then
        cachedDirtId = 2
        return 2
    end
    for id, it in pairs(ItemDB) do
        if type(id) == "number" and type(it) == "table" and type(it.name) == "string" and it.name:lower() == "dirt" then
            cachedDirtId = id
            return id
        end
    end
    return 2
end

local cachedDirtSeedId = nil
local function GetDirtSeedId()
    if cachedDirtSeedId then return cachedDirtSeedId end
    local sid = SeedOfBlock(GetDirtId())
    if sid then
        cachedDirtSeedId = sid
        return sid
    end
    return 3
end

local function PlayerPhysicsState()
    if not Refs.State then Refs.Scan() end
    if Refs.State then
        local ok, s = pcall(Refs.State)
        if ok and type(s) == "table" and type(s.x) == "number" and type(s.y) == "number" and s.active ~= false then
            return s
        end
    end
    return nil
end

local function GetGridState()
    local s = PlayerPhysicsState()
    if s then
        return s.x + Config.calibX, s.y + Config.calibY, (s.facing and s.facing < 0) and -1 or 1
    end
    local inv = FindInventory()
    if not inv then
        return nil, "Inventory game tidak ditemukan"
    end
    local canDropUp = GetUpvalues(inv.canDrop)
    local x = canDropUp[2]
    local facing = canDropUp[3]
    if type(x) ~= "number" or type(facing) ~= "number" then
        return nil, "Upvalue X/arah tidak cocok"
    end
    local nums = {}
    for _, value in ipairs(GetUpvalues(inv.onDrop)) do
        if type(value) == "number" then
            table.insert(nums, value)
        end
    end
    local y = nums[3]
    if type(y) ~= "number" then
        return nil, "Upvalue Y tidak ditemukan"
    end
    return x + Config.calibX, y + Config.calibY, (facing >= 0) and 1 or -1
end

local function GetTile()
    local x, y = GetGridState()
    if not x then return nil end
    return math.floor(x), math.floor(y - 0.475)
end

local function CurrentWorldName()
    local w = FindWorld()
    local name = w and rawget(w, "name")
    return type(name) == "string" and name or ""
end

local function TileValue(world, layer, x, y)
    local w = world or FindWorld()
    if not w or x < 0 or y < 0 or x >= w.w or y >= w.h then return nil end
    local grid = rawget(w, layer)
    local row = grid and grid[y]
    return row and (row[x] or 0) or nil
end

local function InBounds(world, x, y)
    local w = world or FindWorld()
    return w and type(w.w) == "number" and x >= 0 and y >= 0 and x < w.w and y < w.h
end

local function LayerOf(id)
    local it = ItemDB and ItemDB[id]
    return (type(it) == "table" and it.background) and "bg" or "fg"
end

local function PunchReach()
    local hud = Refs.Hud or FindInventory()
    if hud and type(hud.punchRange) == "function" then
        local ok, r = pcall(hud.punchRange)
        if ok and type(r) == "number" and r > 0 then return r end
    end
    return 2.5
end

local function BuildReach()
    local hud = Refs.Hud or FindInventory()
    if hud and type(hud.buildRange) == "function" then
        local ok, r = pcall(hud.buildRange)
        if ok and type(r) == "number" and r > 0 then return r end
    end
    return 2.5
end

----------------------------------------------------------------------
-- AKSI DASAR: PLACE & BREAK (KOMPATIBEL BYTENET + CLASSIC)
----------------------------------------------------------------------
local function SendSetTile(layer, x, y, id, facingLeft)
    if not Refs.SetTile then Refs.Scan() end
    if Refs.SetTile then
        local ok = pcall(Refs.SetTile, layer, x, y, id, false, facingLeft == true)
        if ok then
            PlacedAt[x .. "," .. y] = os.clock()
            return true
        end
    end
    if NetOk and type(Net) == "table" and type(Net.tile) == "table" then
        local ok = pcall(Net.tile.send, {
            layer = (layer == "bg") and 2 or 1, x = x, y = y, id = id, flip = facingLeft == true,
        })
        if ok then
            local w = FindWorld()
            if w and w[layer] and w[layer][y] then w[layer][y][x] = id end
            PlacedAt[x .. "," .. y] = os.clock()
            return true
        end
    elseif SetTileRemote then
        pcall(function() SetTileRemote:FireServer(layer, x, y, id, facingLeft == true) end)
        local w = FindWorld()
        if w and w[layer] and w[layer][y] then w[layer][y][x] = id end
        PlacedAt[x .. "," .. y] = os.clock()
        return true
    end
    return false
end

local function PlaceCell(id, cell, facing)
    if not id or id <= 0 then return false end
    if CountItem(id) <= 0 then return false end
    local layer = LayerOf(id)
    local ok = SendSetTile(layer, cell.x, cell.y, id, (facing or 1) < 0)
    if not ok then return false end
    if Refs.Inv and type(Refs.Inv.remove) == "function" then
        pcall(function() Refs.Inv:remove(id, 1) end)
    end
    Stats.Placed += 1
    return true
end

local function WaitPlaceGuard(x, y)
    local key = x .. "," .. y
    local t = PlacedAt[key]
    if t then
        local age = os.clock() - t
        if age < PLACE_GUARD then
            task.wait(PLACE_GUARD - age)
        end
        PlacedAt[key] = nil
    end
end

local function CanBreakId(id)
    if not id or id == 0 then return false end
    local it = ItemDB[id]
    if not it then return true end
    if it.lock or it.area or it.guildLock or it.vend or it.display then return false end
    local name = type(it.name) == "string" and it.name:lower() or ""
    if name:find("bedrock", 1, true) or name:find("main door", 1, true) or name:find("white door", 1, true) then
        return false
    end
    local h = (it.kind == "seed") and 20 or it.hits
    if type(h) == "number" and h > 0 then return true end
    local w = FindWorld()
    if it.staffHits and w and w.areas and w.areas.staff then return true end
    return h == nil
end

local function TryBreakOnce(x, y, includeBg)
    if includeBg == nil then includeBg = true end
    local w = FindWorld()
    if not w then return nil end
    local fg = TileValue(w, "fg", x, y)
    if fg == nil then return nil end
    local bg = TileValue(w, "bg", x, y)
    local layer, id
    if fg ~= 0 then
        layer, id = "fg", fg
    elseif includeBg and bg and bg ~= 0 then
        layer, id = "bg", bg
    end
    if not layer or not CanBreakId(id) then return nil end

    WaitPlaceGuard(x, y)

    if not Refs.Punch then Refs.Scan() end
    if Refs.Punch then
        local ok = pcall(Refs.Punch, x, y, Config.mutePunch or nil, nil)
        if not ok then return nil end
        if TileValue(w, layer, x, y) ~= id then
            Stats.Broken += 1
            return "broke", id, layer
        end
        return "hit", id, layer
    end
    return nil
end

----------------------------------------------------------------------
-- NOCLIP / MODFLY + TOMBOL LAYAR FLYPAD (▲ / ▼)
----------------------------------------------------------------------
local noclipOn = false
local autoFlyLocks = {}
local FlyPadGui = nil

local function IsAnyFlyActive()
    if noclipOn then return true end
    for _, active in pairs(autoFlyLocks) do
        if active then return true end
    end
    return false
end

local function SyncGhostState()
    local world = FindWorld()
    if not world then return end
    if IsAnyFlyActive() then
        world.ghost = true
    else
        FlyPadState.up, FlyPadState.down = false, false
        world.ghost = (Player:GetAttribute("Ghost") == true)
    end
    if FlyPadGui then
        FlyPadGui.Enabled = noclipOn
    end
end

local function SetAutoFly(sourceKey, enabled)
    autoFlyLocks[sourceKey] = enabled and true or nil
    SyncGhostState()
end

local function StartNoclip()
    noclipOn = true
    SyncGhostState()
    return true
end

local function StopNoclip()
    noclipOn = false
    SyncGhostState()
    return true
end

trackConn(RunService.Heartbeat:Connect(function()
    if not alive() then return end
    local w = Refs.World
    if not w then return end
    if Config.walkSpeed ~= 100 then
        w.speedScale = Config.walkSpeed / 100
    end
    if IsAnyFlyActive() and w.ghost ~= true then
        w.ghost = true
    end
end))

----------------------------------------------------------------------
-- MESIN NAVIGASI UNIVERSAL: LEGIT WALKING (A*) + PILLAR CLIMB + FLYTO
----------------------------------------------------------------------
local Nav = {
    clickOn = false,
    token = 0,
    conn = nil,
    last = "-",
    BadEdge = {},
    PlacedScaffolds = 0,
}

do (function()
    local floor, abs = math.floor, math.abs

    local function fgIdAt(x, y)
        local w = FindWorld()
        local row = w and w.fg and w.fg[y]
        return (row and row[x]) or 0
    end

    local function fgItemAt(x, y)
        local id = fgIdAt(x, y)
        if id ~= 0 then return ItemDB[id] end
        return nil
    end

    local function solidAt(x, y)
        local w = FindWorld()
        if not w then return true end
        if x < 0 or x >= w.w or y >= w.h then return true end
        if y < 0 then return false end
        local it = fgItemAt(x, y)
        if not it then return false end
        if it.combiner then
            local ok, shut = pcall(w.combinerShut, x, y)
            return (not ok) or (shut and true or false)
        end
        if it.vip then
            local ok, may = pcall(w.vipMay, x, y)
            return not (ok and may)
        end
        if it.entrance then
            local sw = w.switches and w.switches[y * w.w + x]
            if it.gate then
                return not (sw and sw.off == true)
            end
            if sw and sw.public then return false end
            local ok, may = pcall(function() return w.areas.mayBuild(w.lock, x, y) end)
            return not (ok and may)
        end
        return it.solid and true or false
    end

    local function hazardAt(x, y)
        local it = fgItemAt(x, y)
        return it ~= nil and (it.deadly or it.hurts or it.laser) and true or false
    end

    local function platformAt(x, y)
        local it = fgItemAt(x, y)
        return it ~= nil and it.platform and true or false
    end

    local function openAt(x, y)
        return not solidAt(x, y) and not hazardAt(x, y)
    end

    local function realSupport(x, y)
        return not hazardAt(x, y + 1) and (solidAt(x, y + 1) or platformAt(x, y + 1))
    end

    local function stateReaches(s, tx, ty, R)
        return abs(tx + 0.5 - s.x) <= R and abs(ty + 0.5 - (s.y - 0.475)) <= R
    end

    local function placeOk(x, y)
        local w = FindWorld()
        if not w or x < 0 or y < 0 or x >= w.w or y >= w.h then return false end
        if fgIdAt(x, y) ~= 0 then return false end
        local ok, res = pcall(function()
            if w.areas and type(w.areas.canEdit) == "function" and not w.areas.canEdit(x, y) then return false end
            if type(w.builderOk) == "function" and not w.builderOk(x, y, true) then return false end
            return true
        end)
        return (not ok) or res
    end

    local function activeScaffoldId()
        local candidates = {
            Config.harvestScaffoldId,
            GetDirtId(),
            Config.farmPlaceId,
        }
        for _, id in ipairs(candidates) do
            if type(id) == "number" and id > 0 and CountItem(id) > 0 then
                local it = ItemDB[id]
                if it and it.solid and it.kind ~= "seed" then
                    return id
                end
            end
        end
        if Refs.Inv and type(Refs.Inv.slots) == "table" then
            for _, slot in ipairs(Refs.Inv.slots) do
                local it = slot.id and ItemDB[slot.id]
                if it and it.solid and it.kind ~= "seed" and not it.lock and (slot.n or 0) > 0 then
                    return slot.id
                end
            end
        end
        return GetDirtId()
    end

    local function placeScaffold(x, y)
        local id = activeScaffoldId()
        if not id or CountItem(id) <= 0 or not placeOk(x, y) then return false end
        local s = PlayerPhysicsState()
        if s and not stateReaches(s, x, y, BuildReach() + 0.5) then return false end
        if PlaceCell(id, { x = x, y = y }, 1) then
            Nav.PlacedScaffolds += 1
            return true
        end
        return false
    end

    Nav.SolidAt = solidAt
    Nav.OpenAt = openAt
    Nav.RealSupport = realSupport
    Nav.PlaceScaffold = placeScaffold
    Nav.StateReaches = stateReaches
    Nav.PlaceOk = placeOk

    local function heapPush(hf, hi, n, f, i)
        n += 1
        local k = n
        while k > 1 do
            local p = k // 2
            if hf[p] <= f then break end
            hf[k], hi[k] = hf[p], hi[p]
            k = p
        end
        hf[k], hi[k] = f, i
        return n
    end

    local function heapPop(hf, hi, n)
        local top = hi[1]
        local lf, li = hf[n], hi[n]
        hf[n], hi[n] = nil, nil
        n -= 1
        if n > 0 then
            local k = 1
            while true do
                local c = k * 2
                if c > n then break end
                if c < n and hf[c + 1] < hf[c] then c += 1 end
                if lf <= hf[c] then break end
                hf[k], hi[k] = hf[c], hi[c]
                k = c
            end
            hf[k], hi[k] = lf, li
        end
        return top, n
    end

    function Nav.AStar(sx, sy, goals, gx, gy, R, useBlock, cancel)
        local w = FindWorld()
        if not w then return nil, false, {} end
        local W, H = w.w, w.h
        local WH = W * H
        R = R or 0.4
        local dxm = floor(R)
        local dyLo = math.ceil(-R + 0.025)
        local dyHi = floor(R + 0.025)
        local oC, sC, bC = {}, {}, {}

        local function open(x, y)
            if x < 0 or x >= W or y >= H then return false end
            if y < 0 then return true end
            local i = y * W + x
            local v = oC[i]
            if v == nil then v = openAt(x, y); oC[i] = v end
            return v
        end

        local function sup(x, y)
            if x < 0 or x >= W or y < 0 or y >= H then return false end
            local i = y * W + x
            local v = sC[i]
            if v == nil then v = realSupport(x, y); sC[i] = v end
            return v
        end

        local function buildable(x, y)
            if not useBlock or x < 0 or x >= W or y < 0 or y >= H then return false end
            local i = y * W + x
            local v = bC[i]
            if v == nil then v = placeOk(x, y); bC[i] = v end
            return v
        end

        local function h(x, y)
            local dx = abs(gx - x) - R
            local dyRaw = gy - y
            local dy = abs(dyRaw) - R
            local vw = (dyRaw < 0) and 1.5 or 0.5
            return (dx > 0 and dx or 0) + vw * (dy > 0 and dy or 0)
        end

        local function isGoal(nx, ny)
            if goals[ny * W + nx] then return true end
            if R >= 1 then
                for ty = ny + dyLo, ny + dyHi do
                    if ty >= 0 and ty < H then
                        local base = ty * W
                        for tx = nx - dxm, nx + dxm do
                            if tx >= 0 and tx < W and goals[base + tx] and not (tx == nx and ty == ny + 1) then
                                return true
                            end
                        end
                    end
                end
            end
            return false
        end

        local ex, ey, ek, ec, eb = {}, {}, {}, {}, {}
        local n = 0
        local function add(x, y, kind, cost, build)
            n += 1
            ex[n], ey[n], ek[n], ec[n], eb[n] = x, y, kind, cost, build
        end

        local function expand(x, y)
            n = 0
            for s = -1, 1, 2 do
                local ax = x + s
                if open(ax, y) then
                    if sup(ax, y) then
                        add(ax, y, "walk", 1, false)
                    else
                        if buildable(ax, y + 1) then
                            add(ax, y, "walk", 3, true)
                        end
                        local fy = y + 1
                        while fy < H and fy - y <= 40 and open(ax, fy) and not sup(ax, fy) do
                            fy += 1
                        end
                        if fy < H and open(ax, fy) and sup(ax, fy) then
                            add(ax, fy, "fall", 1 + 0.5 * (fy - y), false)
                        end
                        if open(x, y - 1) and open(x, y - 2) then
                            for dist = 2, 3 do
                                local mx = x + (dist - 1) * s
                                if not (open(mx, y) and open(mx, y - 1) and open(mx, y - 2)) then break end
                                if dist == 3 and sup(mx, y) then break end
                                local bx = x + dist * s
                                if open(bx, y - 1) and open(bx, y - 2) then
                                    for k = 0, 2 do
                                        if not open(bx, y + k) then break end
                                        if sup(bx, y + k) then
                                            add(bx, y + k, "gap", dist + 0.5 + 0.5 * k, false)
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                for dy = 1, 3 do
                    if not open(x, y - dy) then break end
                    if open(x, y - dy - 1) and open(ax, y - dy) and sup(ax, y - dy) and open(ax, y - dy - 1) then
                        add(ax, y - dy, "jump", 1 + 1.5 * dy, false)
                    end
                end
            end
            if useBlock and open(x, y - 1) and open(x, y - 2) and open(x, y - 3) and buildable(x, y) then
                add(x, y - 1, "pillar", 4, true)
            end
            return n
        end

        local startI = sy * W + sx
        local g, came, kind, buildOf, closed = { [startI] = 0 }, {}, {}, {}, {}
        local hf, hi, hn = {}, {}, 0
        hn = heapPush(hf, hi, hn, h(sx, sy), startI)
        local expanded = 0
        local now = os.clock()

        while hn > 0 do
            local cur
            cur, hn = heapPop(hf, hi, hn)
            if not closed[cur] then
                closed[cur] = true
                local cx, cy = cur % W, cur // W
                if isGoal(cx, cy) then
                    local path = {}
                    local i = cur
                    while i ~= startI do
                        local p = came[i]
                        table.insert(path, 1, {
                            fx = p % W, fy = p // W, x = i % W, y = i // W,
                            kind = kind[i], build = buildOf[i], key = p * WH + i,
                        })
                        i = p
                    end
                    return path, false, closed
                end
                expanded += 1
                if expanded > 6500 then return nil, false, closed end
                if expanded % 400 == 0 then
                    task.wait()
                    if cancel and cancel() then return nil, false, closed end
                end
                local gc = g[cur]
                local cnt = expand(cx, cy)
                for k = 1, cnt do
                    local ni = ey[k] * W + ex[k]
                    if not closed[ni] then
                        local bad = Nav.BadEdge[cur * WH + ni]
                        if not (bad and bad > now) then
                            local ng = gc + ec[k]
                            local old = g[ni]
                            if old == nil or ng < old then
                                g[ni], came[ni], kind[ni], buildOf[ni] = ng, cur, ek[k], eb[k]
                                hn = heapPush(hf, hi, hn, ng + h(ex[k], ey[k]), ni)
                            end
                        end
                    end
                end
            end
        end
        return nil, true, closed
    end

    local function steerX(s, targetX, tol)
        local dx = targetX - s.x
        local vx = s.vx or 0
        local decel = s.grounded and 48 or 17
        local dir = 0
        if abs(dx) > tol then
            dir = dx > 0 and 1 or -1
            if vx * dir > 0 and (vx * vx) / (2 * decel) >= abs(dx) - tol * 0.5 then
                dir = 0
            end
        end
        AutoInput.left = dir < 0
        AutoInput.right = dir > 0
    end

    local function execWalk(tx, ty, cancel)
        local w = FindWorld()
        if not OrigIsDown or not PlayerPhysicsState() then
            if w and w.goTo then
                pcall(w.goTo, tx, ty)
                task.wait(math.max(0.25, Config.moveStepDelay))
                return true
            end
            return false
        end
        AutoInput.active = true
        local cx = tx + 0.5
        local s0 = PlayerPhysicsState()
        if not s0 then ReleaseInput(); return false end
        local limit = 1.6 + abs(cx - s0.x) * 0.38
        local t0 = os.clock()
        while os.clock() - t0 <= limit and alive() do
            if cancel and cancel() then ReleaseInput(); return false end
            local s = PlayerPhysicsState()
            if not s or s.dead then ReleaseInput(); return false end
            local nx, ny = floor(s.x), floor(s.y - 0.475)
            if s.grounded and ny ~= ty then ReleaseInput(); return false end
            steerX(s, cx, 0.1)
            if nx == tx and abs(s.x - cx) <= 0.22 and s.grounded and abs(s.vx or 0) < 2.2 then
                ReleaseInput()
                return true
            end
            task.wait()
        end
        ReleaseInput()
        return false
    end

    local function execFall(e, cancel)
        AutoInput.active = true
        local cx = e.x + 0.5
        local limit = 1.6 + 0.3 * (e.y - e.fy)
        local t0 = os.clock()
        while os.clock() - t0 <= limit and alive() do
            if cancel and cancel() then ReleaseInput(); return false end
            local s = PlayerPhysicsState()
            if not s or s.dead then ReleaseInput(); return false end
            steerX(s, cx, 0.1)
            if s.grounded then
                local nx, ny = floor(s.x), floor(s.y - 0.475)
                if ny == e.y then
                    if nx == e.x and abs(s.x - cx) <= 0.25 then
                        ReleaseInput()
                        return true
                    end
                elseif ny ~= e.fy then
                    ReleaseInput()
                    return false
                end
            end
            task.wait()
        end
        ReleaseInput()
        return false
    end

    local function execJump(e, cancel)
        if not execWalk(e.fx, e.fy, cancel) then return false end
        AutoInput.active = true
        local dy = e.fy - e.y
        local top = e.y + 1
        local releaseY = top - ((dy == 1) and 0 or 0.4)
        local cx = e.x + 0.5
        ReleaseInput()
        task.wait()
        AutoInput.jump = true
        local t0 = os.clock()
        local airborne = false
        while os.clock() - t0 <= 1.8 and alive() do
            if cancel and cancel() then ReleaseInput(); return false end
            local s = PlayerPhysicsState()
            if not s or s.dead then ReleaseInput(); return false end
            if not s.grounded then airborne = true end
            if AutoInput.jump and (s.y <= releaseY or (airborne and (s.vy or 0) >= 0)) then
                AutoInput.jump = false
            end
            if s.y <= top + 0.25 then
                steerX(s, cx, 0.1)
            else
                steerX(s, e.fx + 0.5, 0.15)
            end
            if airborne and s.grounded then
                local nx, ny = floor(s.x), floor(s.y - 0.475)
                ReleaseInput()
                return (ny == e.y and nx == e.x and abs(s.x - cx) <= 0.26)
            end
            if not airborne and os.clock() - t0 > 0.38 then break end
            task.wait()
        end
        ReleaseInput()
        return false
    end

    local function execGap(e, cancel)
        if not execWalk(e.fx, e.fy, cancel) then return false end
        AutoInput.active = true
        local s0 = PlayerPhysicsState()
        if not s0 then ReleaseInput(); return false end
        local dir = (e.x > e.fx) and 1 or -1
        local takeoff = e.fx + 0.5 + dir * 0.6
        local startY = s0.y
        local cx = e.x + 0.5
        ReleaseInput()
        local t0 = os.clock()
        local jumped, airborne, jumpAt = false, false, 0
        while os.clock() - t0 <= 2.2 and alive() do
            if cancel and cancel() then ReleaseInput(); return false end
            local s = PlayerPhysicsState()
            if not s or s.dead then ReleaseInput(); return false end
            if not jumped then
                AutoInput.left, AutoInput.right = dir < 0, dir > 0
                if (s.x - takeoff) * dir >= 0 or not s.grounded then
                    jumped, jumpAt = true, os.clock()
                    AutoInput.jump = s.grounded
                end
            else
                if not s.grounded then airborne = true end
                if AutoInput.jump and (s.y <= startY - 1 or (airborne and (s.vy or 0) >= 0)) then
                    AutoInput.jump = false
                end
                steerX(s, cx, 0.1)
                if airborne and s.grounded then
                    local nx, ny = floor(s.x), floor(s.y - 0.475)
                    ReleaseInput()
                    return (ny == e.y and nx == e.x and abs(s.x - cx) <= 0.26)
                end
                if not airborne and os.clock() - jumpAt > 0.38 then break end
            end
            task.wait()
        end
        ReleaseInput()
        return false
    end

    local function execPillar(e, cancel)
        if not execWalk(e.fx, e.fy, cancel) then return false end
        if fgIdAt(e.fx, e.fy) ~= 0 then return false end
        AutoInput.active = true
        ReleaseInput()
        task.wait()
        AutoInput.jump = true
        local t0 = os.clock()
        local placed, airborne = false, false
        while os.clock() - t0 <= 1.8 and alive() do
            if cancel and cancel() then ReleaseInput(); return false end
            local s = PlayerPhysicsState()
            if not s or s.dead then ReleaseInput(); return false end
            if not s.grounded then airborne = true end
            steerX(s, e.fx + 0.5, 0.12)
            if AutoInput.jump and (s.y < e.fy - 0.9 or (airborne and (s.vy or 0) >= 0)) then
                AutoInput.jump = false
            end
            if not placed and airborne and s.y < e.fy - 0.25 and ((s.vy or 0) > -6 or s.y < e.fy - 0.8) then
                placed = placeScaffold(e.fx, e.fy)
                if not placed then ReleaseInput(); return false end
            end
            if s.grounded and airborne then
                ReleaseInput()
                local nx, ny = floor(s.x), floor(s.y - 0.475)
                return placed and nx == e.x and ny == e.y
            end
            if not airborne and os.clock() - t0 > 0.38 then break end
            task.wait()
        end
        ReleaseInput()
        return false
    end

    Nav.ExecWalk = execWalk
    Nav.ExecPillar = execPillar

    function Nav.FollowPath(path, cancel)
        local savedLocks = {}
        for k, v in pairs(autoFlyLocks) do savedLocks[k] = v end
        table.clear(autoFlyLocks)
        local wasNoclip = noclipOn
        noclipOn = false
        SyncGhostState()
        AutoInput.active = true

        local tempScaffolds = {}

        local function cleanupScaffolds()
            if #tempScaffolds == 0 then return end
            for idx = #tempScaffolds, 1, -1 do
                local sc = tempScaffolds[idx]
                local cx, cy = GetTile()
                if not (cx == sc.x and cy == sc.y - 1) then
                    local s = PlayerPhysicsState()
                    if s and stateReaches(s, sc.x, sc.y, PunchReach() - 0.1) and fgIdAt(sc.x, sc.y) ~= 0 and CanBreakId(fgIdAt(sc.x, sc.y)) then
                        WaitPlaceGuard(sc.x, sc.y)
                        local t0 = os.clock()
                        while fgIdAt(sc.x, sc.y) ~= 0 and os.clock() - t0 < 3.0 and alive() do
                            if cancel and cancel() then break end
                            TryBreakOnce(sc.x, sc.y, false)
                            task.wait(0.15)
                        end
                    end
                    if fgIdAt(sc.x, sc.y) == 0 then
                        table.remove(tempScaffolds, idx)
                    end
                end
            end
        end

        local function finish(result)
            cleanupScaffolds()
            ReleaseInput()
            AutoInput.active = false
            noclipOn = wasNoclip
            for k, v in pairs(savedLocks) do autoFlyLocks[k] = v end
            SyncGhostState()
            return result
        end

        local i = 1
        while i <= #path and alive() do
            if cancel and cancel() then return finish(false) end
            local e = path[i]
            local last, ok = i, false
            if e.kind == "walk" then
                local dir = e.x - e.fx
                while path[last + 1] and path[last + 1].kind == "walk" and (path[last + 1].x - path[last + 1].fx) == dir do
                    last += 1
                end
                local anyBuild = false
                for j = i, last do
                    if path[j].build then anyBuild = true; break end
                end
                if anyBuild then
                    ok = true
                    for j = i, last do
                        if cancel and cancel() then return finish(false) end
                        local st = path[j]
                        if st.build and not realSupport(st.x, st.y) then
                            if not placeScaffold(st.x, st.y + 1) then ok = false; break end
                            table.insert(tempScaffolds, { x = st.x, y = st.y + 1 })
                            task.wait(0.14)
                        end
                        if not execWalk(st.x, st.y, cancel) then ok = false; break end
                        cleanupScaffolds()
                    end
                else
                    ok = execWalk(path[last].x, path[last].y, cancel)
                    cleanupScaffolds()
                end
            elseif e.kind == "pillar" then
                ok = execPillar(e, cancel)
                if ok then
                    table.insert(tempScaffolds, { x = e.fx, y = e.fy })
                    task.wait(0.08)
                    cleanupScaffolds()
                end
            elseif e.kind == "fall" then
                ok = execFall(e, cancel)
                cleanupScaffolds()
            elseif e.kind == "jump" then
                ok = execJump(e, cancel)
                cleanupScaffolds()
            elseif e.kind == "gap" then
                ok = execGap(e, cancel)
                cleanupScaffolds()
            end
            ReleaseInput()
            if not ok then
                Nav.BadEdge[e.key] = os.clock() + 20
                return finish(false)
            end
            i = last + 1
        end
        return finish(true)
    end

    -- FUNGSI MEMANJAT VERTIKAL UNIVERSAL (CLIMB UP WITH DIRT / BERSIH PIJAKAN)
    function Nav.ClimbUpWithDirt(x, targetY, cancel, cleanBehind, stepDelayOverride)
        local world = FindWorld()
        if not world then return false end
        if cleanBehind == nil then cleanBehind = true end
        local settleDelay = math.max(0.28, tonumber(stepDelayOverride) or tonumber(Config.moveStepDelay) or 0.30)

        local savedLocks = {}
        for k, v in pairs(autoFlyLocks) do savedLocks[k] = v end
        table.clear(autoFlyLocks)
        local wasNoclip = noclipOn
        noclipOn = false
        SyncGhostState()
        AutoInput.active = true
        ReleaseInput()

        local function restore()
            ReleaseInput()
            AutoInput.active = false
            noclipOn = wasNoclip
            for k, v in pairs(savedLocks) do autoFlyLocks[k] = v end
            SyncGhostState()
        end

        local cx, cy = GetTile()
        if not cx then restore(); return false end

        if cx ~= x then
            if not execWalk(x, cy, cancel) then
                pcall(world.goTo, x, cy)
                task.wait(settleDelay)
            end
            cx, cy = GetTile()
            if not cx then restore(); return false end
        end

        local tempPlaced = {}
        local scaffoldBlock = activeScaffoldId()

        if InBounds(world, x, cy + 1) and not realSupport(x, cy) then
            if fgIdAt(x, cy + 1) == 0 and placeScaffold(x, cy + 1) then
                tempPlaced[cy + 1] = scaffoldBlock
                task.wait(PLACE_GUARD)
            end
        end

        while cy > targetY and alive() do
            if cancel and cancel() then restore(); return false end
            local nextY = cy - 1

            for checkY = nextY, math.max(0, nextY - 2), -1 do
                local fgUp = fgIdAt(x, checkY)
                if fgUp ~= 0 and CanBreakId(fgUp) then
                    local t0 = os.clock()
                    while fgIdAt(x, checkY) ~= 0 and os.clock() - t0 < 4 do
                        if cancel and cancel() then restore(); return false end
                        TryBreakOnce(x, checkY, false)
                        task.wait(0.16)
                    end
                end
            end

            local okPillar = execPillar({ fx = x, fy = cy, x = x, y = nextY }, cancel)
            if okPillar then
                tempPlaced[cy] = scaffoldBlock
            else
                if fgIdAt(x, cy) == 0 then
                    placeScaffold(x, cy)
                    tempPlaced[cy] = scaffoldBlock
                end
                task.wait(0.15)
                pcall(world.goTo, x, nextY)
            end

            task.wait(math.max(PLACE_GUARD, settleDelay))

            local _, ncy = GetTile()
            if ncy and ncy <= nextY then
                cy = ncy
            else
                cy = nextY
            end

            if cleanBehind then
                for py, _ in pairs(tempPlaced) do
                    if py >= cy + 2 and math.abs(py - cy) <= 3 and fgIdAt(x, py) ~= 0 and CanBreakId(fgIdAt(x, py)) then
                        WaitPlaceGuard(x, py)
                        local t0 = os.clock()
                        while fgIdAt(x, py) ~= 0 and os.clock() - t0 < 3.5 do
                            if cancel and cancel() then restore(); return false end
                            TryBreakOnce(x, py, false)
                            task.wait(0.16)
                        end
                        if fgIdAt(x, py) == 0 then
                            tempPlaced[py] = nil
                        end
                    end
                end
            end
        end

        if cleanBehind and next(tempPlaced) ~= nil then
            local sideCandidates = {}
            if x <= 2 then
                sideCandidates = { x + 1, x + 2, x - 1 }
            elseif x >= world.w - 3 then
                sideCandidates = { x - 1, x - 2, x + 1 }
            else
                sideCandidates = { x + 1, x - 1, x + 2, x - 2 }
            end

            local steppedSide = false
            for _, sx in ipairs(sideCandidates) do
                if InBounds(world, sx, targetY) and openAt(sx, targetY) and realSupport(sx, targetY) then
                    if not execWalk(sx, targetY, cancel) then
                        pcall(world.goTo, sx, targetY)
                    end
                    task.wait(settleDelay)
                    steppedSide = true
                    break
                end
            end

            if not steppedSide then
                for _, sx in ipairs(sideCandidates) do
                    if InBounds(world, sx, targetY + 1) and openAt(sx, targetY + 1) and realSupport(sx, targetY + 1) then
                        pcall(world.goTo, sx, targetY + 1)
                        task.wait(settleDelay)
                        steppedSide = true
                        break
                    end
                end
            end

            if steppedSide then
                local sortedY = {}
                for py in pairs(tempPlaced) do table.insert(sortedY, py) end
                table.sort(sortedY)
                for _, py in ipairs(sortedY) do
                    if fgIdAt(x, py) ~= 0 and math.abs(py - targetY) <= 3 and CanBreakId(fgIdAt(x, py)) then
                        WaitPlaceGuard(x, py)
                        local t0 = os.clock()
                        while fgIdAt(x, py) ~= 0 and os.clock() - t0 < 3.5 do
                            if cancel and cancel() then break end
                            TryBreakOnce(x, py, false)
                            task.wait(0.16)
                        end
                    end
                end
            end
        end

        restore()
        return true
    end

    -- FUNGSI TERBANG MODFLY MURNI (DIPAKAI AUTO CLEAR WORLD AGAR MODFLY SELALU NYALA & BERDIRI DI ATAS BLOK)
    function Nav.FlyTo(tx, ty, cancel, stepDelayOverride)
        local w = FindWorld()
        if not w or type(w.goTo) ~= "function" then return false end
        w.ghost = true
        local sx, sy = GetTile()
        if not sx then return false end
        if sx == tx and sy == ty then return true end

        local dx, dy = tx - sx, ty - sy
        local steps = math.max(abs(dx), abs(dy))
        local stepDelay = math.max(0.18, tonumber(stepDelayOverride) or tonumber(Config.clearTpDelay) or 0.22)

        for i = 1, steps do
            if cancel and cancel() then return false end
            w.ghost = true
            local nx = sx + floor(dx * i / steps + 0.5)
            local ny = sy + floor(dy * i / steps + 0.5)
            pcall(w.goTo, nx, ny)
            task.wait(stepDelay)
        end
        w.ghost = true
        return true
    end

    function Nav.LegitTo(tx, ty, cancel, reachRadius, allowScaffold)
        local started = os.clock()
        local w = FindWorld()
        if not w then return false, "world" end
        local sx, sy = GetTile()
        if not sx then return false, "pos" end
        if sx == tx and sy == ty then return true, 0 end

        if allowScaffold == nil then allowScaffold = true end
        local R = reachRadius or 0.4
        local goals = { [ty * w.w + tx] = true }

        local path = Nav.AStar(sx, sy, goals, tx, ty, R, allowScaffold, cancel)
        if path and #path > 0 then
            if Nav.FollowPath(path, cancel) then
                return true, os.clock() - started
            end
        end

        local cx, cy = GetTile()
        if cx and cy and ty < cy then
            local okClimb = Nav.ClimbUpWithDirt(cx, ty, cancel, true, Config.moveStepDelay)
            if okClimb then
                cx, cy = GetTile()
                if cx and cx ~= tx then
                    local goalsAfter = { [ty * w.w + tx] = true }
                    local pathAfter = Nav.AStar(cx, cy, goalsAfter, tx, ty, R, allowScaffold, cancel)
                    if pathAfter and #pathAfter > 0 then
                        Nav.FollowPath(pathAfter, cancel)
                    else
                        local dir = (tx > cx) and 1 or -1
                        for stepX = cx + dir, tx, dir do
                            if cancel and cancel() then return false, "cancel" end
                            local placedBridge = false
                            if allowScaffold and not realSupport(stepX, ty) and placeOk(stepX, ty + 1) then
                                placedBridge = placeScaffold(stepX, ty + 1)
                                task.wait(0.14)
                            end
                            if not execWalk(stepX, ty, cancel) then
                                pcall(w.goTo, stepX, ty)
                                task.wait(math.max(0.28, Config.moveStepDelay))
                            end
                            local prevX = stepX - dir
                            if placedBridge and fgIdAt(prevX, ty + 1) ~= 0 and CanBreakId(fgIdAt(prevX, ty + 1)) then
                                WaitPlaceGuard(prevX, ty + 1)
                                local t0 = os.clock()
                                while fgIdAt(prevX, ty + 1) ~= 0 and os.clock() - t0 < 2.5 do
                                    TryBreakOnce(prevX, ty + 1, false)
                                    task.wait(0.15)
                                end
                            end
                        end
                    end
                end
                local fx, fy = GetTile()
                if fx and math.abs(fx - tx) <= math.ceil(R + 1) and math.abs(fy - ty) <= math.ceil(R + 1) then
                    return true, os.clock() - started
                end
            end
        end

        return false, "nopath"
    end

    function Nav.StepGoTo(tx, ty, cancel, flyMode)
        local started = os.clock()
        local w = FindWorld()
        if not w or type(w.goTo) ~= "function" then return false, "world" end
        local sx, sy = GetTile()
        if not sx then return false, "pos" end

        if ty < sy and not flyMode then
            Nav.ClimbUpWithDirt(sx, ty, cancel, true, Config.moveStepDelay)
            sx, sy = GetTile()
            if not sx then return false, "pos" end
        end

        local dx, dy = tx - sx, ty - sy
        local steps = math.max(abs(dx), abs(dy))
        if steps == 0 then return true, 0 end
        local stepDelay = math.max(0.22, tonumber(Config.moveStepDelay) or 0.30)

        if flyMode then w.ghost = true end
        for i = 1, steps do
            if cancel and cancel() then
                SyncGhostState()
                return false, "cancel"
            end
            if flyMode then w.ghost = true end
            local nx = sx + floor(dx * i / steps + 0.5)
            local ny = sy + floor(dy * i / steps + 0.5)
            pcall(w.goTo, nx, ny)
            task.wait(stepDelay)
        end
        SyncGhostState()
        return true, os.clock() - started
    end

    function Nav.Go(tx, ty, cancel, reachRadius, allowScaffold)
        local mode = Config.moveMode
        if mode == "legit" or mode == "walk" or mode == "mix" then
            local ok, info = Nav.LegitTo(tx, ty, cancel, reachRadius, allowScaffold)
            if ok or info == "cancel" then
                return ok, info
            end
            if mode == "legit" or mode == "walk" then
                return false, info
            end
        end
        return Nav.StepGoTo(tx, ty, cancel, true)
    end

    function Nav.To(tx, ty, cancel, reachRadius, allowScaffold)
        local ok = Nav.Go(tx, ty, cancel, reachRadius, allowScaffold)
        return ok
    end

    -- Click TP Kamera -> Tile (Diperbaiki dari hasil Camera Spy)
    local actFn = nil
    local function CamInfo()
        if not actFn and getgcFn and debug and debug.info then
            for _, fn in ipairs(getgcFn(true)) do
                if type(fn) == "function" then
                    local okN, fnName = pcall(debug.info, fn, "n")
                    if okN and fnName == "act" and getupvalueFn then
                        local ok1, u1 = pcall(getupvalueFn, fn, 1)
                        local ok2, u2 = pcall(getupvalueFn, fn, 2)
                        local ok4, u4 = pcall(getupvalueFn, fn, 4)
                        local ok5, u5 = pcall(getupvalueFn, fn, 5)
                        if ok1 and typeof(u1) == "Instance" and u1.ClassName == "Players"
                            and ok2 and type(u2) == "number"
                            and ok4 and type(u4) == "number"
                            and ok5 and type(u5) == "number" then
                            actFn = fn
                            break
                        end
                    end
                end
            end
        end
        if actFn and getupvalueFn then
            local okX, camX = pcall(getupvalueFn, actFn, 2)
            local okT, tile = pcall(getupvalueFn, actFn, 4)
            local okY, camY = pcall(getupvalueFn, actFn, 5)
            if okX and okT and okY and type(camX) == "number" and type(tile) == "number" and type(camY) == "number" and tile > 0 then
                return camX, camY, tile
            end
        end

        local gg = PlayerGui:FindFirstChild("GameGui")
        local worldGui = gg and gg:FindFirstChild("World")
        local camGui = worldGui and worldGui:FindFirstChild("Camera")
        local tilesFrame = camGui and camGui:FindFirstChild("Tiles")
        if tilesFrame and tilesFrame:IsA("GuiObject") then
            local tileSize = 64
            local camX = -tilesFrame.Position.X.Offset / tileSize
            local camY = -tilesFrame.Position.Y.Offset / tileSize
            return camX, camY, tileSize
        end
        return nil
    end

    function Nav.ScreenToTile(pos)
        local camX, camY, tile = CamInfo()
        if not camX then return nil end
        local gg = PlayerGui:FindFirstChild("GameGui")
        local worldGui = (gg and gg:FindFirstChild("World")) or PlayerGui:FindFirstChild("World", true)
        if not worldGui or not worldGui:IsA("GuiObject") then return nil end
        local scaleObj = worldGui:FindFirstChildWhichIsA("UIScale", true)
        local scale = scaleObj and scaleObj.Scale or 1
        local rel = (Vector2.new(pos.X, pos.Y) - worldGui.AbsolutePosition) / scale
        return floor(camX + rel.X / tile), floor(camY + rel.Y / tile)
    end

    local function OnClick(input, processed)
        if processed or not Nav.clickOn then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        if Config.clickTpShift and not (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
            or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)) then
            return
        end
        local tx, ty = Nav.ScreenToTile(input.Position)
        if not tx then
            Notify("Click TP: posisi klik tidak terbaca.")
            return
        end
        Nav.token += 1
        local token = Nav.token
        task.spawn(function()
            local started = os.clock()
            local ok, info = Nav.Go(tx, ty, function()
                return Nav.token ~= token or not Nav.clickOn or not alive()
            end, 0.4, true)
            if ok then
                Nav.last = string.format("Sampai (%d,%d) dalam %.2fs", tx, ty, os.clock() - started)
                Notify(Nav.last)
            elseif info ~= "cancel" then
                Nav.last = "Gagal (" .. tostring(info) .. ")"
                Notify("Click TP gagal: " .. tostring(info))
            end
        end)
    end

    function Nav.StartClick()
        if Nav.clickOn then return true end
        if not CamInfo() then
            Notify("Click TP: data kamera game tidak ditemukan.")
            return false
        end
        Nav.clickOn = true
        Nav.conn = trackConn(UserInputService.InputBegan:Connect(OnClick))
        return true
    end

    function Nav.StopClick()
        if not Nav.clickOn then return false end
        Nav.clickOn = false
        Nav.token += 1
        if Nav.conn then
            Nav.conn:Disconnect()
            Nav.conn = nil
        end
        ReleaseInput()
        return true
    end
end)() end

----------------------------------------------------------------------
-- UTILITAS AKSI CEPAT: DROP WL, WARP, POS 1/2, REJOIN
----------------------------------------------------------------------
local lastDropClock = 0

local function DropWorldLock(amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 or amount > MAX_AMOUNT then
        Notify("Jumlah WL tidak valid!")
        return false
    end
    local now = os.clock()
    if now - lastDropClock < COOLDOWN then
        task.wait(COOLDOWN - (now - lastDropClock))
    end
    lastDropClock = os.clock()

    local id = Config.dropId or 242
    if DropEvent then
        pcall(function() DropEvent:FireServer(id, amount) end)
        Notify(string.format("Drop %d %s dikirim!", amount, ItemName(id)))
        return true
    elseif NetOk and type(Net) == "table" and Net.drop then
        pcall(Net.drop.send, { id = id, n = amount })
        Notify(string.format("Drop %d %s dikirim!", amount, ItemName(id)))
        return true
    end
    Notify("Remote DropItem tidak ditemukan!")
    return false
end

local function WarpToWorld(worldName)
    worldName = Trim(worldName):upper()
    if worldName == "" then
        Notify("Nama world tidak boleh kosong!")
        return false
    end
    Config.lastWorld = worldName
    SaveConfig()
    local m = Refs.Menu
    if m and type(rawget(m, "enter")) == "function" then
        pcall(m.enter, worldName)
        Notify("Memasuki world: " .. worldName)
        return true
    end
    local w = FindWorld()
    if w and type(rawget(w, "enter")) == "function" then
        pcall(w.enter, worldName)
        Notify("Memasuki world: " .. worldName)
        return true
    end
    Notify("Fungsi enter world tidak ditemukan.")
    return false
end

local QueueReload
local function Rejoin()
    local wName = CurrentWorldName()
    if wName ~= "" then
        Config.lastWorld = wName
        SaveConfig()
    end
    if QueueReload then pcall(QueueReload) end
    pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Player)
    end)
end

local function SetPos(slot)
    local tx, ty = GetTile()
    if not tx then
        Notify("Posisi karakter belum terbaca!")
        return false
    end
    local key = "pos" .. tostring(slot)
    Config[key] = { x = tx, y = ty, world = CurrentWorldName() }
    SaveConfig()
    Notify(string.format("Pos %d disimpan di (%d, %d) [%s]", slot, tx, ty, CurrentWorldName()))
    return true
end

local function ShowPos()
    local tx, ty = GetTile()
    local p1, p2 = Config.pos1 or {}, Config.pos2 or {}
    local msg = string.format(
        "Sekarang: (%s, %s) | Pos1: (%s, %s) | Pos2: (%s, %s)",
        tx and tostring(tx) or "-", ty and tostring(ty) or "-",
        p1.x and tostring(p1.x) or "-", p1.y and tostring(p1.y) or "-",
        p2.x and tostring(p2.x) or "-", p2.y and tostring(p2.y) or "-"
    )
    Notify(msg, "Info Posisi")
end

local function GoToPos(slot, dropAmount)
    local key = "pos" .. tostring(slot)
    local p = Config[key]
    if type(p) ~= "table" or type(p.x) ~= "number" or type(p.y) ~= "number" then
        Notify("Pos " .. tostring(slot) .. " belum disimpan!")
        return false
    end
    local ok = Nav.To(p.x, p.y, nil, 0.3, true)
    if ok then
        local amt = tonumber(dropAmount) or tonumber(Config.winDrop) or 0
        if amt >= 1 then
            task.wait(0.15)
            DropWorldLock(amt)
        end
    end
    return ok
end

----------------------------------------------------------------------
-- STATE MODUL BOT & HELPER POHON UNIVERSAL
----------------------------------------------------------------------
local RefreshHub
local GridGui = nil
local GridMode = "farm" -- "farm" | "pabrik"
local UpdateGridVisuals = nil
local SetGridMode = nil

local Farm = {
    on = false,
    token = 0,
    Override = nil,
    Quiet = false,
    stats = { status = "Mati", placed = 0, broken = 0, picked = 0, fail = 0, cycles = 0 },
}
local Clear = {
    on = false,
    token = 0,
    status = "Mati",
    stats = { scanned = 0, broken = 0, picked = 0, skipped = 0, left = 0, pass = 0, row = -1 },
}
local Farmer = {
    on = false,
    token = 0,
    status = "Mati",
    stats = { totalTrees = 0, ready = 0, harvested = 0, planted = 0, skipped = 0, picked = 0 },
}
local DF = {
    on = false,
    token = 0,
    status = "Mati",
    stats = { topDirtY = 0, bedrockY = 0, broken = 0, placed = 0, picked = 0, step = "-" },
}
local SpliceBot = {
    on = false,
    roaming = false,
    token = 0,
    status = "Mati",
    made = 0,
    planted = 0,
    fail = {},
    skip = {},
}
local Pabrik = {
    on = false,
    token = 0,
    phase = "-",
    status = "Mati",
    harvested = 0,
    planted = 0,
    dropped = 0,
    traveling = false,
    home = "",
    Zone = nil,
    skip = {},
}
local Bag = {
    recycled = 0,
    converted = 0,
    status = "-",
}
local Guard = {
    on = false,
    mode = "idle",
    allow = {},
    alerted = {},
    saved = nil,
    token = 0,
    backAt = 0,
    calmAt = nil,
    leftFg = nil,
    status = "Mati",
    detected = 0,
    hereText = "tidak ada",
    staffServerText = "tidak ada",
}
local Reconnect = {
    busy = false,
    leaving = false,
    last = nil,
    lastAt = 0,
    count = 0,
    status = "-",
}
local Spam = { on = false, sent = 0, last = "-", nextAt = 0 }

local function IsSeedId(id)
    local it = ItemDB and ItemDB[id]
    return type(it) == "table" and (it.kind == "seed" or type(it.tree) == "table" or type(it.grow) == "number")
end

local function TreeReadyAt(w, x, y, id)
    w = w or FindWorld()
    if not w then return nil end
    local it = ItemDB[id]
    if not it then return nil end
    local growTime = tonumber(it.grow) or tonumber(it.baseGrow) or 31
    local idx = y * w.w + x

    if type(w.treeLook) == "function" then
        pcall(w.treeLook, x, y)
    end
    if not Refs.Trees then Refs.Scan() end
    local entry = Refs.Trees and Refs.Trees[idx]
    if type(entry) == "table" then
        if entry.ripe == true or entry.fruitMade == true or entry.step == 1 then
            return 0
        end
        if type(entry.tree) == "table" and type(entry.tree.p) == "number" then
            return entry.tree.p + growTime
        end
        if type(entry.p) == "number" then
            return entry.p + growTime
        end
    end
    local placedFg = w.placedAt and w.placedAt.fg
    if placedFg and type(placedFg[idx]) == "number" then
        return workspace:GetServerTimeNow() - (os.clock() - placedFg[idx]) + growTime
    end
    return nil
end

local function IsTreeReady(w, x, y, id)
    local readyAt = TreeReadyAt(w, x, y, id)
    if not readyAt then return false end
    return workspace:GetServerTimeNow() >= readyAt
end

local function CanPlantAt(w, x, y, seedId)
    w = w or FindWorld()
    if not InBounds(w, x, y) or y + 1 >= w.h then return false end
    if (TileValue(w, "fg", x, y) or 0) ~= 0 then return false end
    local below = TileValue(w, "fg", x, y + 1) or 0
    if below == 0 then return false end
    local it = ItemDB[below]
    if not it or it.kind == "seed" then return false end
    if not (Nav.SolidAt(x, y + 1) or it.platform) then return false end
    local ok, res = pcall(function()
        if w.areas and type(w.areas.canEdit) == "function" and not w.areas.canEdit(x, y) then return false end
        if type(w.builderOk) == "function" and not w.builderOk(x, y, true) then return false end
        local sItem = seedId and ItemDB[seedId]
        if sItem and type(w.needsWay) == "function" and w.needsWay(sItem) and type(w.wayBlocked) == "function" and w.wayBlocked(x, y) then
            return false
        end
        return true
    end)
    return (not ok) or res
end

----------------------------------------------------------------------
-- FAST PARALLEL AUTO-COLLECT (RADIUS + DROP ZONE PABRIK + WEBHOOK FULL)
----------------------------------------------------------------------
do (function()
    local function canTryDrop(d, now)
        if type(d) ~= "table" or d.taking or d.pending or d.display or (d.n or 0) <= 0 or type(d.x) ~= "number" then
            return false
        end
        if d.armed == false and d.id ~= 112 then return false end
        local fail = d.uid and DropFailUntil[d.uid]
        return not (fail and now < fail)
    end

    local function takeSingleDrop(d)
        local w = FindWorld()
        local worldTake = w and rawget(w, "takeDrop")
        if type(worldTake) ~= "function" and not TakeDropRemote then return false end
        local now = os.clock()
        if not canTryDrop(d, now) then return false end

        local amount = d.n
        if d.id ~= 112 and Refs.Inv and type(Refs.Inv.room) == "function" then
            local okR, room = pcall(function() return Refs.Inv:room(d.id) end)
            if okR and type(room) == "number" then amount = math.min(amount, room) end
        end
        if amount <= 0 then
            if d.uid then DropFailUntil[d.uid] = now + 1 end
            local lastFull = Webhook.LastFull[d.id]
            if not lastFull or now - lastFull > 120 then
                Webhook.LastFull[d.id] = now
                Webhook.Send("full", "Inventori penuh: " .. ItemName(d.id) .. " tidak bisa diambil lagi")
            end
            return false
        end

        d.taking = true
        d.flown = true
        if typeof(d.frame) == "Instance" then pcall(function() d.frame.Visible = false end) end

        local ok, taken
        if type(worldTake) == "function" then
            ok, taken = pcall(worldTake, d.uid, amount)
        else
            ok, taken = pcall(TakeDropRemote.InvokeServer, TakeDropRemote, d.uid, amount)
        end
        d.taking = false

        if not (ok and type(taken) == "number" and taken > 0) then
            Farm.stats.fail += 1
            d.refused = os.clock()
            if d.uid then DropFailUntil[d.uid] = os.clock() + 1 end
            d.flown = nil
            if typeof(d.frame) == "Instance" then pcall(function() d.frame.Visible = not d.culled end) end
            return false
        end

        if d.uid then DropFailUntil[d.uid] = nil end
        if d.id == 112 then
            if Refs.Gems and type(Refs.Gems.addGems) == "function" then pcall(Refs.Gems.addGems, taken) end
        elseif Refs.Inv and type(Refs.Inv.add) == "function" then
            pcall(function() Refs.Inv:add(d.id, taken) end)
        end
        if Drops.list and Drops.update and table.find(Drops.list, d) then
            pcall(Drops.update, d, d.n - taken)
        end

        Stats.Collected += taken
        Stats.Items[d.id] = (Stats.Items[d.id] or 0) + taken
        Farm.stats.picked += taken
        if Clear.on then Clear.stats.picked += taken end
        if Farmer.on then Farmer.stats.picked += taken end
        if DF.on then DF.stats.picked += taken end
        return true
    end

    local nextDropScan = 0
    trackConn(RunService.Heartbeat:Connect(function()
        if not alive() then return end
        local activeGrid = (Farm.Override and Farm.Override.offsets) or Config.farmGrid
        local farmArea = (Farm.on and Config.farmTake) or (Farm.Override ~= nil)
        local nearArea = Config.collectAround
            or (Clear.on and Config.clearTake)
            or (Farmer.on and Config.harvestTake)
            or (DF.on and Config.dfTake)
            or SpliceBot.on
            or Pabrik.on
        if not farmArea and not nearArea then return end

        local list = Drops.list
        if not list then
            if os.clock() >= nextDropScan then
                nextDropScan = os.clock() + 4
                Refs.Scan()
            end
            return
        end
        if #list == 0 then return end

        local x, y = GetGridState()
        if not x then return end
        local cx, cy = x, y - 0.475
        local ptx, pty = math.floor(cx), math.floor(cy)
        local now = os.clock()
        local radius = (tonumber(Config.collectRadius) or 3) + 0.25

        local dropZone = Pabrik.Zone
        if dropZone and dropZone.world ~= CurrentWorldName() then
            dropZone = nil
        end

        for i = #list, 1, -1 do
            local d = list[i]
            if canTryDrop(d, now) and not (dropZone and math.abs(d.x - dropZone.x) <= 2.5 and math.abs(d.y - dropZone.y) <= 2.5) then
                local hit = nearArea and math.abs(d.x - cx) <= radius and math.abs(d.y - cy) <= radius
                if not hit and farmArea then
                    for key, on in pairs(activeGrid) do
                        if on then
                            local dx, dy = tostring(key):match("^(-?%d+),(-?%d+)$")
                            if dx and dy then
                                local tx, ty = ptx + tonumber(dx), pty + tonumber(dy)
                                if d.x >= tx - 0.15 and d.x < tx + 1.15 and d.y >= ty - 0.15 and d.y < ty + 1.15 then
                                    hit = true
                                    break
                                end
                            end
                        end
                    end
                end
                if hit then
                    task.spawn(takeSingleDrop, d)
                end
            end
        end
    end))
end)() end

----------------------------------------------------------------------
-- 1. AUTO FARM (MULTI-TARGET + RAYMAN'S FIST + OVERRIDE PABRIK)
----------------------------------------------------------------------
local StartFarm, StopFarm, RunFarmLoopDirect

do (function()
    local RAY_DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }

    local function raymanOn()
        local w = FindWorld()
        local f = w and rawget(w, "raymanOn")
        if type(f) ~= "function" then return false end
        local ok, on = pcall(f)
        return ok and on == true
    end

    local function raymanLine(px, py, active)
        local byKey = {}
        for _, a in ipairs(active) do byKey[a.x .. "," .. a.y] = a end
        local best, bestDir = nil, nil
        for _, d in ipairs(RAY_DIRS) do
            local line = {}
            for i = 1, 3 do
                local a = byKey[(px + d[1] * i) .. "," .. (py + d[2] * i)]
                if a then line[#line + 1] = a end
            end
            if #line >= 2 and #line > (best and #best or 0) then
                best, bestDir = line, d
            end
        end
        return best, bestDir
    end

    local function raymanAct(dir)
        local s = PlayerPhysicsState()
        if not s or not s.x then return end
        if NetOk and type(Net) == "table" and Net.act then
            pcall(Net.act.send, { kind = 4, x = s.x + dir[1], y = s.y - 0.475 + dir[2] })
        end
    end

    local function activeOffsets()
        local grid = (Farm.Override and Farm.Override.offsets) or Config.farmGrid
        local list = {}
        for key, on in pairs(grid) do
            if on then
                local dx, dy = tostring(key):match("^(-?%d+),(-?%d+)$")
                dx, dy = tonumber(dx), tonumber(dy)
                if dx and dy and not (dx == 0 and dy == 0) then
                    table.insert(list, { dx = dx, dy = dy })
                end
            end
        end
        table.sort(list, function(a, b)
            if a.dy ~= b.dy then return a.dy < b.dy end
            return a.dx < b.dx
        end)
        return list
    end

    local function breakableAt(w, x, y)
        local fg = TileValue(w, "fg", x, y)
        if fg == nil then return false end
        if fg ~= 0 then return CanBreakId(fg) end
        local bg = TileValue(w, "bg", x, y)
        return Config.farmBreakBg and bg ~= nil and bg ~= 0 and CanBreakId(bg)
    end

    local function FarmLoop(token, anchor)
        while Farm.on and Farm.token == token and alive() do
            local w = FindWorld()
            if not w or CurrentWorldName() ~= anchor.world then
                Farm.stats.status = "World berubah, berhenti"
                break
            end

            local mode = (Farm.Override and Farm.Override.mode) or Config.farmMode
            local doPlace = mode ~= "Break saja"
            local doBreak = mode ~= "Place saja"
            local id = (Farm.Override and Farm.Override.block) or Config.farmPlaceId
            local offsets = activeOffsets()
            if #offsets == 0 then
                Farm.stats.status = "Pilih kotak di Grid 5x5 dulu"
                if not Farm.Quiet then Notify("Auto Farm: pilih minimal 1 kotak di Grid 5x5.") end
                break
            end

            local px, py = GetTile()
            if not px then break end
            if not Farm.Override and (px ~= anchor.x or py ~= anchor.y) then
                Nav.To(anchor.x, anchor.y, function() return Farm.token ~= token end, 0.2, true)
                px, py = GetTile()
                if not px then break end
            end

            local tiles = {}
            for _, o in ipairs(offsets) do
                local tx, ty = px + o.dx, py + o.dy
                if InBounds(w, tx, ty) then
                    table.insert(tiles, { x = tx, y = ty })
                end
            end

            local acted, outOfBlock = false, false

            if doPlace then
                Farm.stats.status = "Place " .. ItemName(id)
                local layer = LayerOf(id)
                for _, t in ipairs(tiles) do
                    if not Farm.on or Farm.token ~= token then break end
                    local fg = TileValue(w, "fg", t.x, t.y)
                    local cur = TileValue(w, layer, t.x, t.y)
                    if cur == 0 and (layer == "bg" or fg == 0) then
                        if CountItem(id) <= 0 then
                            outOfBlock = true
                            break
                        end
                        if PlaceCell(id, t, anchor.facing) then
                            Farm.stats.placed += 1
                            acted = true
                            task.wait(math.max(0.05, Config.farmPlaceMs / 1000))
                        end
                    end
                end
            end

            if not Farm.on or Farm.token ~= token then break end

            if doBreak then
                Farm.stats.status = "Break (" .. (raymanOn() and "Rayman" or ("Multi " .. Config.farmMultiTarget)) .. ")"
                local K = math.clamp(math.floor(Config.farmMultiTarget or 1), 1, 5)
                local nextI, active = 1, {}
                while Farm.on and Farm.token == token and alive() do
                    while #active < K and nextI <= #tiles do
                        local t = tiles[nextI]
                        nextI += 1
                        if breakableAt(w, t.x, t.y) then
                            active[#active + 1] = { x = t.x, y = t.y, n = 0 }
                        end
                    end
                    if #active == 0 then break end

                    local hits, rayDir = nil, nil
                    if K > 1 and raymanOn() then
                        hits, rayDir = raymanLine(px, py, active)
                    end
                    if not rayDir then
                        hits = { active[1] }
                    end

                    local t0 = os.clock()
                    if rayDir then raymanAct(rayDir) end
                    local hitAny, brokeAny = false, false

                    for i, a in ipairs(hits) do
                        if not Farm.on or Farm.token ~= token then break end
                        if i > 1 then task.wait(0.05) end
                        local r = TryBreakOnce(a.x, a.y, Config.farmBreakBg)
                        a.n += 1
                        if r then hitAny, acted = true, true end
                        if r == "broke" then
                            Farm.stats.broken += 1
                            brokeAny = true
                        end
                        if r == nil or a.n > 80 or (r == "broke" and not breakableAt(w, a.x, a.y)) then
                            a.done = true
                        end
                        a.used = true
                    end

                    local nextActive = {}
                    for _, a in ipairs(active) do
                        if not a.done and not a.used then nextActive[#nextActive + 1] = a end
                    end
                    for _, a in ipairs(hits) do
                        a.used = nil
                        if not a.done then nextActive[#nextActive + 1] = a end
                    end
                    active = nextActive

                    if hitAny then
                        local gap = math.max(0.04, Config.farmDelay)
                        if rayDir then gap = math.max(gap, 0.35) end
                        local rest = gap - (os.clock() - t0)
                        if rest > 0.005 then task.wait(rest) end
                    end
                    if brokeAny and Config.farmAfterBreakMs > 0 then
                        task.wait(Config.farmAfterBreakMs / 1000)
                    end
                end
            end

            if not acted then
                if outOfBlock then
                    Farm.stats.status = "Item " .. ItemName(id) .. " habis"
                    if not Farm.Quiet then
                        Notify("Auto Farm berhenti: " .. ItemName(id) .. " habis di inventori.")
                        Webhook.Send("stop", "Auto Farm berhenti: " .. ItemName(id) .. " habis")
                    end
                    break
                end
                task.wait(math.max(0.1, Config.farmDelay))
            end

            Farm.stats.cycles += 1
        end
    end

    RunFarmLoopDirect = FarmLoop

    StopFarm = function()
        if not Farm.on then return false end
        Farm.token += 1
        Farm.on = false
        Farm.stats.status = "Mati"
        if UpdateGridVisuals then pcall(UpdateGridVisuals) end
        return true
    end

    StartFarm = function()
        if Farm.on then return true end
        if Clear.on then Clear.Stop() end
        if Farmer.on then Farmer.Stop() end
        if DF.on then DF.Stop() end
        if SpliceBot.on then SpliceBot.Stop() end
        if Pabrik.on then Pabrik.Stop() end

        local doPlace = Config.farmMode ~= "Break saja"
        if doPlace and (type(Config.farmPlaceId) ~= "number" or Config.farmPlaceId <= 0) then
            Notify("Pilih block dulu di tab Auto Farm.")
            return false
        end
        local x, y, facing = GetGridState()
        if not x then
            Notify("Posisi karakter belum terdeteksi.")
            return false
        end
        local anchor = {
            x = math.floor(x),
            y = math.floor(y - 0.475),
            facing = facing,
            world = CurrentWorldName(),
        }
        Farm.Override = nil
        Farm.Quiet = false
        Farm.token += 1
        local token = Farm.token
        Farm.on = true
        Farm.stats.status = "Berjalan"
        if UpdateGridVisuals then pcall(UpdateGridVisuals) end

        task.spawn(function()
            local ok, err = pcall(FarmLoop, token, anchor)
            if not ok then warn("[ANCHHub] Auto Farm error: " .. tostring(err)) end
            if Farm.token == token then
                Farm.on = false
                if Farm.stats.status == "Berjalan" then Farm.stats.status = "Mati" end
                if UpdateGridVisuals then pcall(UpdateGridVisuals) end
                if RefreshHub then RefreshHub() end
            end
        end)
        return true
    end
end)() end

----------------------------------------------------------------------
-- 2. AUTO CLEAR WORLD (MODFLY SELALU NYALA + BERDIRI DI ATAS BLOCK TARGET)
----------------------------------------------------------------------
do (function()
    local BREAK_TIMEOUT = 5.0

    local function ClearLayerAt(w, x, y)
        if typeof(w.spawn) == "Vector2" and x == math.floor(w.spawn.X) and y == math.floor(w.spawn.Y) then
            return nil
        end
        local fg = TileValue(w, "fg", x, y)
        if fg == nil then return nil end
        if fg ~= 0 then
            if CanBreakId(fg) then return "fg", fg end
            return nil
        end
        if Config.clearIncludeBg then
            local bg = TileValue(w, "bg", x, y)
            if bg and bg ~= 0 and CanBreakId(bg) then return "bg", bg end
        end
        return nil
    end

    local function CollectTargets(w, skippedSet)
        local list = {}
        local dir = 1
        for y = 0, w.h - 1 do
            local rowTargets = {}
            for x = 0, w.w - 1 do
                local layer, id = ClearLayerAt(w, x, y)
                if layer then
                    local key = x .. "," .. y
                    if not skippedSet[key] then
                        table.insert(rowTargets, { x = x, y = y, id = id, layer = layer, key = key })
                    end
                end
            end
            if #rowTargets > 0 then
                if Config.clearSweep == "Zig-zag" and dir == -1 then
                    table.sort(rowTargets, function(a, b) return a.x > b.x end)
                else
                    table.sort(rowTargets, function(a, b) return a.x < b.x end)
                end
                for _, t in ipairs(rowTargets) do
                    table.insert(list, t)
                end
                if Config.clearSweep == "Zig-zag" then
                    dir = -dir
                end
            end
        end
        return list
    end

    local function ClearLoop(token, home)
        -- ModFly SELALU NYALA selama Auto Clear berjalan
        SetAutoFly("autoclear", true)
        ReleaseInput()
        AutoInput.active = false

        local skippedSet = {}
        local pass = 0

        while Clear.on and Clear.token == token and alive() do
            pass += 1
            local w = FindWorld()
            if not w or CurrentWorldName() ~= home.world then
                Clear.status = "World berubah, berhenti"
                break
            end
            w.ghost = true

            Clear.status = "Scan objek di world..."
            Clear.stats.pass = pass
            local targets = CollectTargets(w, skippedSet)
            Clear.stats.scanned = #targets
            Clear.stats.left = #targets

            if #targets == 0 then
                break
            end

            if pass == 1 then
                local first = targets[1]
                Notify(string.format("Auto Clear (ModFly): %d blok ditemukan. Mulai dari (%d, %d).", #targets, first.x, first.y))
            end

            local brokeAny = false

            for idx, target in ipairs(targets) do
                if not Clear.on or Clear.token ~= token or not alive() then return end
                w = FindWorld()
                if not w or CurrentWorldName() ~= home.world then return end

                local curLayer, curId = ClearLayerAt(w, target.x, target.y)
                if curLayer then
                    Clear.stats.row = target.y
                    -- Karakter SELALU berdiri tepat di atas block yang akan di-break (x, y - 1)
                    local standX = target.x
                    local standY = math.max(0, target.y - 1)

                    SetAutoFly("autoclear", true)
                    w.ghost = true

                    local px, py = GetTile()
                    if px ~= standX or py ~= standY then
                        Clear.status = string.format("Terbang ke atas blok (%d,%d) [%d/%d]", standX, standY, idx, #targets)
                        Nav.FlyTo(standX, standY, function()
                            return not Clear.on or Clear.token ~= token or not alive()
                        end, Config.clearTpDelay)
                    end

                    -- Pastikan karakter tepat di (standX, standY) dengan ModFly aktif
                    w.ghost = true
                    pcall(w.goTo, standX, standY)
                    task.wait(0.05)

                    local started = os.clock()
                    local timedOut = false
                    Clear.status = string.format("Break %s di bawah (%d,%d) [%d/%d]", ItemName(curId), target.x, target.y, idx, #targets)

                    -- Pukul terus blok di bawah kaki sampai fg & bg habis sebelum pindah ke blok selanjutnya
                    while Clear.on and Clear.token == token and alive() do
                        w.ghost = true
                        local lNow, idNow = ClearLayerAt(w, target.x, target.y)
                        if not lNow then break end
                        if os.clock() - started >= BREAK_TIMEOUT then
                            timedOut = true
                            break
                        end
                        Clear.status = string.format("Break %s (%d,%d) [%d/%d]", ItemName(idNow), target.x, target.y, idx, #targets)
                        local r = TryBreakOnce(target.x, target.y, Config.clearIncludeBg)
                        if r == "broke" then
                            brokeAny = true
                            Clear.stats.broken += 1
                            started = os.clock()
                        end
                        task.wait(math.max(0.04, Config.clearBreakDelay))
                    end

                    if not ClearLayerAt(w, target.x, target.y) then
                        Clear.stats.left = math.max(0, Clear.stats.left - 1)
                    elseif timedOut then
                        skippedSet[target.key] = true
                        Clear.stats.skipped += 1
                        Clear.stats.left = math.max(0, Clear.stats.left - 1)
                        Clear.status = string.format("Skip (%d,%d) > 5 dtk", target.x, target.y)
                    end
                else
                    Clear.stats.left = math.max(0, Clear.stats.left - 1)
                end
            end

            if not brokeAny then break end
        end

        SetAutoFly("autoclear", false)
        ReleaseInput()
        AutoInput.active = false
        Clear.status = "Selesai"
        local msg = string.format("Auto Clear selesai! Hancur: %d | Diambil: %d | Skip: %d", Clear.stats.broken, Clear.stats.picked, Clear.stats.skipped)
        Notify(msg)
        Webhook.Send("stop", msg)
    end

    function Clear.Stop()
        if not Clear.on then return false end
        Clear.token += 1
        Clear.on = false
        SetAutoFly("autoclear", false)
        ReleaseInput()
        AutoInput.active = false
        Clear.status = "Mati"
        return true
    end

    function Clear.Start()
        if Clear.on then return true end
        if Farm.on then StopFarm() end
        if Farmer.on then Farmer.Stop() end
        if DF.on then DF.Stop() end
        if SpliceBot.on then SpliceBot.Stop() end
        if Pabrik.on then Pabrik.Stop() end

        local x, y = GetGridState()
        if not x then Notify("Posisi belum terdeteksi."); return false end
        local home = { x = math.floor(x), y = math.floor(y - 0.475), world = CurrentWorldName() }
        Clear.token += 1
        local token = Clear.token
        Clear.on = true
        Clear.status = "Mulai"
        Clear.stats = { scanned = 0, broken = 0, picked = 0, skipped = 0, left = 0, pass = 0, row = -1 }

        task.spawn(function()
            local ok, err = pcall(ClearLoop, token, home)
            if not ok then warn("[ANCHHub] Auto Clear error: " .. tostring(err)) end
            SetAutoFly("autoclear", false)
            ReleaseInput()
            AutoInput.active = false
            if Clear.token == token then
                Clear.on = false
                if Clear.status ~= "Selesai" then Clear.status = "Mati" end
                if RefreshHub then RefreshHub() end
            end
        end)
        return true
    end
end)() end

----------------------------------------------------------------------
-- 3. FARMER: AUTO HARVEST + AUTO PLANT (BERSIH PIJAKAN)
----------------------------------------------------------------------
do (function()
    local function FarmerLoop(token, home)
        if Config.harvestModFly then
            SetAutoFly("autoharvest", true)
        end

        local failedSet = {}
        local pass = 0

        while Farmer.on and Farmer.token == token and alive() do
            pass += 1
            local w = FindWorld()
            if not w or CurrentWorldName() ~= home.world then
                Farmer.status = "World berubah, berhenti"
                break
            end

            Farmer.status = "Scan pohon & lahan tanam..."
            local readyTrees = {}
            local plantSpots = {}
            local totalTrees = 0
            local skippedNotReady = 0
            local doPlant = Config.harvestDoPlant and Config.harvestSeedId and CountItem(Config.harvestSeedId) > 0

            for y = 0, w.h - 1 do
                for x = 0, w.w - 1 do
                    local id = TileValue(w, "fg", x, y) or 0
                    if id ~= 0 and IsSeedId(id) then
                        totalTrees += 1
                        if Config.harvestDoHarvest and not failedSet[x .. "," .. y] then
                            if IsTreeReady(w, x, y, id) then
                                table.insert(readyTrees, { x = x, y = y, id = id })
                            else
                                skippedNotReady += 1
                            end
                        end
                    elseif doPlant and id == 0 and CanPlantAt(w, x, y, Config.harvestSeedId) then
                        table.insert(plantSpots, { x = x, y = y })
                    end
                end
            end

            Farmer.stats.totalTrees = totalTrees
            Farmer.stats.ready = #readyTrees
            if pass == 1 then
                Farmer.stats.skipped = skippedNotReady
                Notify(string.format("Farmer Scan: %d pohon (%d siap panen, %d belum siap) | %d lahan kosong.", totalTrees, #readyTrees, skippedNotReady, #plantSpots))
            end

            if #readyTrees == 0 and #plantSpots == 0 then
                break
            end

            local actedInPass = false
            local R = math.min(PunchReach(), BuildReach()) - 0.15

            for idx, tree in ipairs(readyTrees) do
                if not Farmer.on or Farmer.token ~= token or not alive() then return end
                w = FindWorld()
                if not w or CurrentWorldName() ~= home.world then return end

                if TileValue(w, "fg", tree.x, tree.y) == tree.id then
                    local px, py = GetTile()
                    local s = PlayerPhysicsState()
                    if not (s and Nav.StateReaches(s, tree.x, tree.y, R)) then
                        Farmer.status = string.format("Menuju pohon (%d,%d) [%d/%d]", tree.x, tree.y, idx, #readyTrees)
                        if py and tree.y < py then
                            Nav.ClimbUpWithDirt(px, tree.y, function() return Farmer.token ~= token end, true, Config.harvestTpDelay)
                        end
                        Nav.To(tree.x, tree.y, function() return Farmer.token ~= token end, R, Config.harvestUseBlock)
                        task.wait(math.max(0.10, Config.harvestTpDelay))
                    end

                    Farmer.status = string.format("Panen %s (%d,%d) [%d/%d]", ItemName(tree.id), tree.x, tree.y, idx, #readyTrees)
                    local t0 = os.clock()
                    while Farmer.on and Farmer.token == token and TileValue(w, "fg", tree.x, tree.y) == tree.id and os.clock() - t0 < 3.5 do
                        TryBreakOnce(tree.x, tree.y, false)
                        task.wait(math.max(0.05, Config.harvestDelay))
                    end

                    if TileValue(w, "fg", tree.x, tree.y) ~= tree.id then
                        actedInPass = true
                        Farmer.stats.harvested += 1
                        Stats.Harvested += 1
                        Farmer.stats.ready = math.max(0, Farmer.stats.ready - 1)
                        if Config.harvestDoPlant and Config.harvestSeedId and CountItem(Config.harvestSeedId) > 0 and CanPlantAt(w, tree.x, tree.y, Config.harvestSeedId) then
                            task.wait(0.08)
                            if PlaceCell(Config.harvestSeedId, { x = tree.x, y = tree.y }, 1) then
                                Farmer.stats.planted += 1
                                Stats.Planted += 1
                                task.wait(math.max(0.05, Config.harvestPlantDelay))
                            end
                        end
                    else
                        failedSet[tree.x .. "," .. tree.y] = true
                        Farmer.stats.skipped += 1
                    end
                end
            end

            if Config.harvestDoPlant and Config.harvestSeedId and CountItem(Config.harvestSeedId) > 0 then
                for idx, spot in ipairs(plantSpots) do
                    if not Farmer.on or Farmer.token ~= token or not alive() then return end
                    if CountItem(Config.harvestSeedId) <= 0 then break end
                    w = FindWorld()
                    if not w or CurrentWorldName() ~= home.world then return end

                    if CanPlantAt(w, spot.x, spot.y, Config.harvestSeedId) then
                        local px, py = GetTile()
                        local s = PlayerPhysicsState()
                        if not (s and Nav.StateReaches(s, spot.x, spot.y, R)) then
                            Farmer.status = string.format("Menuju tanam (%d,%d) [%d/%d]", spot.x, spot.y, idx, #plantSpots)
                            if py and spot.y < py then
                                Nav.ClimbUpWithDirt(px, spot.y, function() return Farmer.token ~= token end, true, Config.harvestTpDelay)
                            end
                            Nav.To(spot.x, spot.y, function() return Farmer.token ~= token end, R, Config.harvestUseBlock)
                            task.wait(math.max(0.10, Config.harvestTpDelay))
                        end

                        if CanPlantAt(w, spot.x, spot.y, Config.harvestSeedId) and PlaceCell(Config.harvestSeedId, spot, 1) then
                            actedInPass = true
                            Farmer.stats.planted += 1
                            Stats.Planted += 1
                            Farmer.status = string.format("Tanam %s (%d,%d)", ItemName(Config.harvestSeedId), spot.x, spot.y)
                            task.wait(math.max(0.05, Config.harvestPlantDelay))
                        end
                    end
                end
            end

            if not actedInPass then break end
        end

        SetAutoFly("autoharvest", false)
        ReleaseInput()
        AutoInput.active = false
        Farmer.status = "Selesai"
        local msg = string.format("Farmer selesai! Panen: %d | Tanam: %d | Drop: %d", Farmer.stats.harvested, Farmer.stats.planted, Farmer.stats.picked)
        Notify(msg)
        Webhook.Send("stop", msg)
    end

    function Farmer.Stop()
        if not Farmer.on then return false end
        Farmer.token += 1
        Farmer.on = false
        SetAutoFly("autoharvest", false)
        ReleaseInput()
        AutoInput.active = false
        Farmer.status = "Mati"
        return true
    end

    function Farmer.Start()
        if Farmer.on then return true end
        if Farm.on then StopFarm() end
        if Clear.on then Clear.Stop() end
        if DF.on then DF.Stop() end
        if SpliceBot.on then SpliceBot.Stop() end
        if Pabrik.on then Pabrik.Stop() end

        local x, y = GetGridState()
        if not x then Notify("Posisi belum terdeteksi."); return false end
        local home = { x = math.floor(x), y = math.floor(y - 0.475), world = CurrentWorldName() }
        Farmer.token += 1
        local token = Farmer.token
        Farmer.on = true
        Farmer.status = "Mulai"
        Farmer.stats = { totalTrees = 0, ready = 0, harvested = 0, planted = 0, skipped = 0, picked = 0 }

        task.spawn(function()
            local ok, err = pcall(FarmerLoop, token, home)
            if not ok then warn("[ANCHHub] Farmer error: " .. tostring(err)) end
            SetAutoFly("autoharvest", false)
            ReleaseInput()
            AutoInput.active = false
            if Farmer.token == token then
                Farmer.on = false
                if Farmer.status ~= "Selesai" then Farmer.status = "Mati" end
                if RefreshHub then RefreshHub() end
            end
        end)
        return true
    end
end)() end

----------------------------------------------------------------------
-- 4. AUTO DIRT FARM (FULL WORLD: BAWAH + ATAS + SMART SUPPLY + NO MODFLY)
----------------------------------------------------------------------
do (function()
    local DF_BREAK_TIMEOUT = 5.0

    local function IsBedrockId(id)
        local it = ItemDB and ItemDB[id]
        return type(it) == "table" and type(it.name) == "string" and it.name:lower():find("bedrock", 1, true) ~= nil
    end

    local function DetectWorldLayers(w)
        local dirtId = GetDirtId()
        local topDirtY, bedrockY = nil, nil
        for y = 0, w.h - 1 do
            local groundCount, bedrockCount = 0, 0
            for x = 0, w.w - 1 do
                local fg = TileValue(w, "fg", x, y) or 0
                if fg ~= 0 then
                    if IsBedrockId(fg) then
                        bedrockCount += 1
                    elseif fg == dirtId or CanBreakId(fg) then
                        groundCount += 1
                    end
                end
            end
            if not topDirtY and groundCount >= math.floor(w.w * 0.25) then topDirtY = y end
            if topDirtY and y > topDirtY and bedrockCount >= math.floor(w.w * 0.4) then
                bedrockY = y
                break
            end
        end
        if not topDirtY then
            topDirtY = (typeof(w.spawn) == "Vector2") and (math.floor(w.spawn.Y) + 1) or 37
        end
        if not bedrockY then bedrockY = w.h - 6 end
        return topDirtY, bedrockY
    end

    local function WalkOrClimbTo(standX, standY, token)
        local px, py = GetTile()
        if not px or (px == standX and py == standY) then return true end
        if py and standY < py and math.abs(px - standX) <= 1 then
            return Nav.ClimbUpWithDirt(standX, standY, function() return DF.token ~= token or not DF.on end, true, Config.dfTpDelay)
        elseif py == standY and Nav.ExecWalk(standX, standY, function() return DF.token ~= token or not DF.on end) then
            return true
        else
            return Nav.To(standX, standY, function() return DF.token ~= token or not DF.on end, 0.3, true)
        end
    end

    local function BreakTotalAt(w, tx, ty, standX, standY, token)
        if not InBounds(w, tx, ty) then return false end
        local fg = TileValue(w, "fg", tx, ty) or 0
        local bg = TileValue(w, "bg", tx, ty) or 0
        if (fg == 0 or not CanBreakId(fg)) and (bg == 0 or not CanBreakId(bg)) then
            return true
        end

        WalkOrClimbTo(standX, standY, token)

        local startT = os.clock()
        while DF.on and DF.token == token and alive() do
            local cFg = TileValue(w, "fg", tx, ty) or 0
            local cBg = TileValue(w, "bg", tx, ty) or 0
            local hasFg = cFg ~= 0 and CanBreakId(cFg)
            local hasBg = cBg ~= 0 and CanBreakId(cBg)
            if not hasFg and not hasBg then break end
            if os.clock() - startT >= DF_BREAK_TIMEOUT then break end

            local r = TryBreakOnce(tx, ty, true)
            if r == "broke" then
                DF.stats.broken += 1
                startT = os.clock()
            end
            task.wait(math.max(0.04, Config.dfBreakDelay))
        end
        return true
    end

    local function FindWorldDirtDrop(dirtId, seedId)
        local list = Drops.list
        if not list then Refs.Scan(); list = Drops.list end
        if type(list) ~= "table" then return nil end
        local px, py = GetTile()
        px, py = px or 50, py or 30
        local best, bestDist = nil, math.huge
        for _, d in ipairs(list) do
            if type(d) == "table" and (d.id == dirtId or d.id == seedId) and (d.n or 0) > 0 and type(d.x) == "number" then
                local dist = math.abs(d.x - px) + math.abs(d.y - py)
                if dist < bestDist then
                    best, bestDist = d, dist
                end
            end
        end
        return best
    end

    local function PlantAndHarvestDirtSeeds(w, platformY, token, maxPlant)
        local dirtId = GetDirtId()
        local seedId = GetDirtSeedId()
        local plantY = platformY - 1
        if plantY < 0 then return false end

        local plantedSpots = {}
        local count = 0
        for x = 3, w.w - 4 do
            if not DF.on or DF.token ~= token then break end
            if CountItem(seedId) <= 0 or count >= (maxPlant or 20) then break end
            if (TileValue(w, "fg", x, platformY) or 0) == dirtId and (TileValue(w, "fg", x, plantY) or 0) == 0 then
                WalkOrClimbTo(x, plantY, token)
                if PlaceCell(seedId, { x = x, y = plantY }, 1) then
                    Stats.Planted += 1
                    table.insert(plantedSpots, { x = x, y = plantY, plantedTime = os.clock() })
                    count += 1
                    task.wait(0.18)
                end
            end
        end

        for x = 2, w.w - 3 do
            if (TileValue(w, "fg", x, plantY) or 0) == seedId then
                local exists = false
                for _, p in ipairs(plantedSpots) do
                    if p.x == x and p.y == plantY then exists = true; break end
                end
                if not exists then
                    table.insert(plantedSpots, { x = x, y = plantY, plantedTime = os.clock() - 25 })
                end
            end
        end

        if #plantedSpots == 0 then return false end

        local it = ItemDB[seedId]
        local growTime = (it and (tonumber(it.grow) or tonumber(it.baseGrow))) or 31

        for idx, spot in ipairs(plantedSpots) do
            if not DF.on or DF.token ~= token then return false end
            while DF.on and DF.token == token and alive() do
                if (TileValue(w, "fg", spot.x, spot.y) or 0) ~= seedId then break end
                local elapsed = os.clock() - spot.plantedTime
                if IsTreeReady(w, spot.x, spot.y, seedId) or elapsed >= (growTime + 1.5) then
                    break
                end
                local left = math.max(0, math.ceil(growTime - elapsed))
                DF.status = string.format("Menunggu Dirt Tree matang (%ds) [%d/%d]...", left, idx, #plantedSpots)
                task.wait(0.5)
            end

            if (TileValue(w, "fg", spot.x, spot.y) or 0) == seedId then
                DF.status = string.format("Harvest Dirt Tree (%d,%d) [%d/%d]", spot.x, spot.y, idx, #plantedSpots)
                WalkOrClimbTo(spot.x, spot.y, token)
                local t0 = os.clock()
                while DF.on and DF.token == token and (TileValue(w, "fg", spot.x, spot.y) or 0) == seedId and os.clock() - t0 < 3.5 do
                    local r = TryBreakOnce(spot.x, spot.y, false)
                    if r == "broke" then Stats.Harvested += 1 end
                    task.wait(math.max(0.05, Config.dfBreakDelay))
                end
                task.wait(0.25)
            end
        end
        return true
    end

    local function FindFarmablePlatformRow(w, topDirtY, bedrockY)
        local dirtId = GetDirtId()
        for y = topDirtY, bedrockY - 1, 2 do
            local dirtCount = 0
            for x = 3, w.w - 4 do
                if (TileValue(w, "fg", x, y) or 0) == dirtId and (TileValue(w, "fg", x, y - 1) or 0) == 0 then
                    dirtCount += 1
                    if dirtCount >= 12 then return y end
                end
            end
        end
        return topDirtY
    end

    local function EnsureDirtSupply(w, returnX, returnY, refPlatformY, topDirtY, bedrockY, token)
        local dirtId = GetDirtId()
        local seedId = GetDirtSeedId()

        if CountItem(dirtId) > 0 then
            return true
        end

        DF.stats.step = "Restock Dirt"
        local workPlatformY = FindFarmablePlatformRow(w, topDirtY, bedrockY)

        while DF.on and DF.token == token and alive() and CountItem(dirtId) < 15 do
            if CountItem(seedId) > 0 then
                DF.status = "Stok Dirt habis! Menanam & memanen Dirt Seed..."
                PlantAndHarvestDirtSeeds(w, workPlatformY, token, 20)
                if CountItem(dirtId) >= 15 then break end
            end

            local drop = FindWorldDirtDrop(dirtId, seedId)
            if drop then
                local dx, dy = math.floor(drop.x), math.floor(drop.y)
                DF.status = string.format("Mengambil drop Dirt/Seed di (%d, %d)...", dx, dy)
                WalkOrClimbTo(dx, dy, token)
                task.wait(0.5)
                if CountItem(dirtId) >= 15 then break end
                if CountItem(seedId) > 0 then
                    PlantAndHarvestDirtSeeds(w, workPlatformY, token, 20)
                    if CountItem(dirtId) >= 15 then break end
                end
            end

            if CountItem(dirtId) == 0 and CountItem(seedId) == 0 then
                DF.status = "Break Dirt di world untuk mencari Seed..."
                local brokenList = {}
                for x = 4, w.w - 5 do
                    if not DF.on or DF.token ~= token then break end
                    if #brokenList >= 14 or CountItem(seedId) >= 6 then break end
                    if (TileValue(w, "fg", x, workPlatformY) or 0) == dirtId
                        and (TileValue(w, "fg", x - 1, workPlatformY) or 0) == dirtId then
                        local standX, standY = x - 1, workPlatformY - 1
                        WalkOrClimbTo(standX, standY, token)
                        BreakTotalAt(w, x, workPlatformY, standX, standY, token)
                        if (TileValue(w, "fg", x, workPlatformY) or 0) == 0 then
                            table.insert(brokenList, { x = x, y = workPlatformY, standX = standX, standY = standY })
                        end
                        task.wait(0.2)
                    end
                end

                if CountItem(seedId) > 0 then
                    PlantAndHarvestDirtSeeds(w, workPlatformY, token, 20)
                end

                for _, item in ipairs(brokenList) do
                    if not DF.on or DF.token ~= token then break end
                    while DF.on and DF.token == token and CountItem(dirtId) == 0 and CountItem(seedId) > 0 do
                        PlantAndHarvestDirtSeeds(w, workPlatformY, token, 15)
                    end
                    if (TileValue(w, "fg", item.x, item.y) or 0) == 0 and CountItem(dirtId) > 0 then
                        WalkOrClimbTo(item.standX, item.standY, token)
                        if PlaceCell(dirtId, { x = item.x, y = item.y }, 1) then
                            DF.stats.placed += 1
                            task.wait(0.14)
                        end
                    end
                end
            elseif CountItem(dirtId) > 0 and CountItem(dirtId) < 15 and CountItem(seedId) == 0 then
                local testX = 5
                local standX, standY = 4, workPlatformY - 1
                WalkOrClimbTo(standX, standY, token)
                while DF.on and DF.token == token and CountItem(seedId) < 4 and CountItem(dirtId) > 0 do
                    if (TileValue(w, "fg", testX, standY) or 0) == 0 then
                        PlaceCell(dirtId, { x = testX, y = standY }, 1)
                        task.wait(PLACE_GUARD)
                    end
                    BreakTotalAt(w, testX, standY, standX, standY, token)
                    task.wait(0.2)
                end
            else
                break
            end
        end

        if returnX and returnY then
            WalkOrClimbTo(returnX, returnY, token)
        end
        return CountItem(dirtId) > 0
    end

    local function EnsurePlatformDirtAt(w, tx, ty, standX, standY, topDirtY, bedrockY, token)
        if not InBounds(w, tx, ty) then return end
        local dirtId = GetDirtId()
        local fg = TileValue(w, "fg", tx, ty) or 0
        if fg == dirtId then return end
        if fg ~= 0 and not CanBreakId(fg) then return end

        WalkOrClimbTo(standX, standY, token)

        if fg ~= 0 and fg ~= dirtId then
            local t0 = os.clock()
            while DF.on and DF.token == token and (TileValue(w, "fg", tx, ty) or 0) ~= 0 and os.clock() - t0 < DF_BREAK_TIMEOUT do
                local r = TryBreakOnce(tx, ty, false)
                if r == "broke" then DF.stats.broken += 1 end
                task.wait(math.max(0.04, Config.dfBreakDelay))
            end
        end

        if DF.on and DF.token == token and (TileValue(w, "fg", tx, ty) or 0) == 0 then
            if CountItem(dirtId) <= 0 then
                EnsureDirtSupply(w, standX, standY, ty, topDirtY, bedrockY, token)
            end
            if CountItem(dirtId) > 0 then
                if PlaceCell(dirtId, { x = tx, y = ty }, (tx >= standX) and 1 or -1) then
                    DF.stats.placed += 1
                    task.wait(0.14)
                end
            end
        end
    end

    local function ClearVerticalEdge(w, colA, colB, topDirtY, bedrockY, label, token)
        DF.stats.step = "Clear Vertikal " .. label
        local startY = math.max(0, topDirtY - 1)
        DF.status = string.format("Menuju ujung %s (%d, %d)...", label, colB, startY)

        Nav.To(colB, startY, function() return DF.token ~= token end, 0.3, true)
        task.wait(math.max(0.25, Config.dfTpDelay))

        local lastY = startY
        for y = topDirtY, bedrockY - 1 do
            if not DF.on or DF.token ~= token or not alive() then return false end
            w = FindWorld()
            if not w then return false end
            if IsBedrockId(TileValue(w, "fg", colA, y)) and IsBedrockId(TileValue(w, "fg", colB, y)) then
                break
            end
            local standY = math.max(0, y - 1)
            DF.status = string.format("Vertikal %s: Break Y=%d", label, y)
            BreakTotalAt(w, colA, y, colB, standY, token)
            if not DF.on or DF.token ~= token then return false end
            BreakTotalAt(w, colB, y, colB, standY, token)
            lastY = standY
        end

        if DF.on and DF.token == token and lastY > startY then
            DF.status = string.format("Panjat naik %s (Bersih Pijakan)...", label)
            Nav.ClimbUpWithDirt(colB, startY, function() return DF.token ~= token end, true, Config.dfTpDelay)
        end
        return true
    end

    local function DFLoop(token, home)
        SetAutoFly("autodf", false)

        local w = FindWorld()
        if not w then return end

        local topDirtY, bedrockY = DetectWorldLayers(w)
        DF.stats.topDirtY = topDirtY
        DF.stats.bedrockY = bedrockY
        Notify(string.format("Auto DF Full World: Dirt Y=%d, Bedrock Y=%d.", topDirtY, bedrockY))

        local W = w.w
        if not ClearVerticalEdge(w, 0, 1, topDirtY, bedrockY, "Kiri (1-2)", token) then return end
        if not DF.on or DF.token ~= token then return end
        if not ClearVerticalEdge(w, W - 2, W - 1, topDirtY, bedrockY, "Kanan (99-100)", token) then return end
        if not DF.on or DF.token ~= token then return end

        local leftToRight = false
        for emptyY = topDirtY + 1, bedrockY - 1, 2 do
            if not DF.on or DF.token ~= token or not alive() then return end
            w = FindWorld()
            if not w or CurrentWorldName() ~= home.world then return end

            local platformAboveY = emptyY - 1
            local platformBelowY = emptyY + 1
            DF.stats.step = string.format("Bawah: Baris Y=%d", emptyY)

            local startX = leftToRight and 2 or (W - 3)
            local endX   = leftToRight and (W - 3) or 2
            local stepX  = leftToRight and 1 or -1
            local entryStandX = leftToRight and 1 or (W - 2)

            WalkOrClimbTo(entryStandX, emptyY, token)

            for x = startX, endX, stepX do
                if not DF.on or DF.token ~= token or not alive() then return end
                w = FindWorld()
                if not w or CurrentWorldName() ~= home.world then return end

                local standX = x - stepX
                local standY = emptyY

                if Config.dfReplacePlatform and platformBelowY < bedrockY then
                    EnsurePlatformDirtAt(w, standX, platformBelowY, standX, standY, topDirtY, bedrockY, token)
                end
                if Config.dfReplacePlatform and platformAboveY >= topDirtY then
                    EnsurePlatformDirtAt(w, standX, platformAboveY, standX, standY, topDirtY, bedrockY, token)
                end

                DF.status = string.format("Bawah Y=%d | Break (%d,%d)", emptyY, x, emptyY)
                BreakTotalAt(w, x, emptyY, standX, standY, token)

                if Config.dfReplacePlatform then
                    if platformAboveY >= topDirtY then
                        EnsurePlatformDirtAt(w, x, platformAboveY, standX, standY, topDirtY, bedrockY, token)
                    end
                    if platformBelowY < bedrockY then
                        EnsurePlatformDirtAt(w, x, platformBelowY, standX, standY, topDirtY, bedrockY, token)
                    end
                end

                if not Nav.ExecWalk(x, emptyY, function() return DF.token ~= token end) then
                    pcall(w.goTo, x, emptyY)
                    task.wait(math.max(0.22, Config.dfTpDelay))
                end
            end

            leftToRight = not leftToRight
        end

        for x = 2, W - 3 do
            if not DF.on or DF.token ~= token then return end
            EnsurePlatformDirtAt(w, x, topDirtY, x, topDirtY - 1, topDirtY, bedrockY, token)
        end

        local upperLeftToRight = true
        for platformY = topDirtY - 2, 2, -2 do
            if not DF.on or DF.token ~= token or not alive() then return end
            w = FindWorld()
            if not w or CurrentWorldName() ~= home.world then return end

            local walkY = platformY - 1
            DF.stats.step = string.format("Atas: Platform Y=%d", platformY)

            local startX = upperLeftToRight and 2 or (W - 3)
            local endX   = upperLeftToRight and (W - 3) or 2
            local stepX  = upperLeftToRight and 1 or -1

            local prevWalkY = platformY + 1
            WalkOrClimbTo(startX, prevWalkY, token)
            EnsurePlatformDirtAt(w, startX, platformY, startX, prevWalkY, topDirtY, bedrockY, token)

            local climbCol = upperLeftToRight and 1 or (W - 2)
            Nav.ClimbUpWithDirt(climbCol, walkY, function() return DF.token ~= token end, true, Config.dfTpDelay)
            WalkOrClimbTo(startX, walkY, token)

            for x = startX + stepX, endX, stepX do
                if not DF.on or DF.token ~= token or not alive() then return end
                w = FindWorld()
                if not w or CurrentWorldName() ~= home.world then return end

                local standX = x - stepX
                if (TileValue(w, "fg", x, walkY) or 0) ~= 0 or (TileValue(w, "bg", x, walkY) or 0) ~= 0 then
                    BreakTotalAt(w, x, walkY, standX, walkY, token)
                end

                DF.status = string.format("Atas Y=%d | Pasang Dirt (%d,%d)", platformY, x, platformY)
                EnsurePlatformDirtAt(w, x, platformY, standX, walkY, topDirtY, bedrockY, token)

                if not Nav.ExecWalk(x, walkY, function() return DF.token ~= token end) then
                    pcall(w.goTo, x, walkY)
                    task.wait(math.max(0.22, Config.dfTpDelay))
                end
            end

            upperLeftToRight = not upperLeftToRight
        end

        SetAutoFly("autodf", false)
        ReleaseInput()
        AutoInput.active = false
        DF.stats.step = "Selesai"
        DF.status = "Selesai"
        local msg = string.format("Full World Dirt Farm selesai! Hancur: %d | Dirt dipasang: %d | Drop: %d", DF.stats.broken, DF.stats.placed, DF.stats.picked)
        Notify(msg)
        Webhook.Send("pabrik", msg)
    end

    function DF.Stop()
        if not DF.on then return false end
        DF.token += 1
        DF.on = false
        SetAutoFly("autodf", false)
        ReleaseInput()
        AutoInput.active = false
        DF.status = "Mati"
        DF.stats.step = "-"
        return true
    end

    function DF.Start()
        if DF.on then return true end
        if Farm.on then StopFarm() end
        if Clear.on then Clear.Stop() end
        if Farmer.on then Farmer.Stop() end
        if SpliceBot.on then SpliceBot.Stop() end
        if Pabrik.on then Pabrik.Stop() end

        local x, y = GetGridState()
        if not x then Notify("Posisi belum terdeteksi."); return false end
        local home = { x = math.floor(x), y = math.floor(y - 0.475), world = CurrentWorldName() }
        DF.token += 1
        local token = DF.token
        DF.on = true
        DF.status = "Mulai"
        DF.stats = { topDirtY = 0, bedrockY = 0, broken = 0, placed = 0, picked = 0, step = "Inisialisasi" }

        task.spawn(function()
            local ok, err = pcall(DFLoop, token, home)
            if not ok then warn("[ANCHHub] Auto DF error: " .. tostring(err)) end
            SetAutoFly("autodf", false)
            ReleaseInput()
            AutoInput.active = false
            if DF.token == token then
                DF.on = false
                if DF.status ~= "Selesai" then DF.status = "Mati" end
                if RefreshHub then RefreshHub() end
            end
        end)
        return true
    end
end)() end

----------------------------------------------------------------------
-- 5. AUTO SPLICE (TANAM SEED A + SPLICE SEED B | ROAM A* / GRID 5X5)
----------------------------------------------------------------------
do (function()
    function SpliceBot.Result(seedA, seedB)
        if not (SpliceOk and type(SpliceModule) == "table" and type(SpliceModule.result) == "function") then
            return nil
        end
        if not (seedA and seedB) then return nil end
        local ok, res = pcall(SpliceModule.result, seedA, seedB)
        return ok and res or nil
    end

    function SpliceBot.ResultText()
        local a, b = Config.spliceA, Config.spliceB
        if not (a and b) then return "Pilih Seed A dan Seed B" end
        local r = SpliceBot.Result(a, b)
        if not r then return "Hasil: Kombinasi ini tidak bisa di-splice" end
        return "Hasil Splice: " .. ItemName(r) .. " [" .. tostring(r) .. "]"
    end

    local function IsSplicedTree(w, x, y)
        if not Refs.Trees then Refs.Scan() end
        local entry = Refs.Trees and Refs.Trees[y * w.w + x]
        return type(entry) == "table" and entry.s == true
    end

    local function DoSpliceAt(w, x, y, seedB)
        local fn = w and rawget(w, "spliceSeed")
        if type(fn) ~= "function" then return false, "fungsi spliceSeed tidak ditemukan" end
        local ok, newId = pcall(fn, x, y, seedB)
        if ok and newId and ItemDB[newId] then
            if Refs.Inv and type(Refs.Inv.remove) == "function" then
                pcall(function() Refs.Inv:remove(seedB, 1) end)
            end
            if Refs.SetTile then
                pcall(Refs.SetTile, "fg", x, y, newId, true)
            end
            SpliceBot.made += 1
            SpliceBot.status = string.format("Splice jadi %s (%d,%d)", ItemName(newId), x, y)
            return true
        end
        return false, "ditolak server"
    end

    local function SpliceLoop(token, home)
        local R = math.min(PunchReach(), BuildReach()) - 0.15
        while SpliceBot.on and SpliceBot.token == token and alive() do
            local w = FindWorld()
            if not w or CurrentWorldName() ~= home.world then
                SpliceBot.status = "World berubah, berhenti"
                break
            end

            local seedA, seedB = Config.spliceA, Config.spliceB
            local countA, countB = CountItem(seedA), CountItem(seedB)
            if countB <= 0 then
                SpliceBot.status = "Seed B habis!"
                Notify("Auto Splice berhenti: " .. ItemName(seedB) .. " habis.")
                break
            end

            local acted = false
            if Config.spliceRoam then
                -- Mode Keliling World (A*)
                local targets = {}
                local now = os.clock()
                for y = 0, w.h - 1 do
                    for x = 0, w.w - 1 do
                        local key = x .. "," .. y
                        if not (SpliceBot.skip[key] and SpliceBot.skip[key] > now) then
                            local fg = TileValue(w, "fg", x, y) or 0
                            if fg == 0 and countA > 0 and CanPlantAt(w, x, y, seedA) then
                                table.insert(targets, { x = x, y = y, key = key })
                            elseif fg == seedA and not IsSplicedTree(w, x, y) and not IsTreeReady(w, x, y, seedA) then
                                table.insert(targets, { x = x, y = y, key = key })
                            end
                        end
                    end
                end

                if #targets == 0 then
                    SpliceBot.status = (countA <= 0) and "Seed A habis & tidak ada pohon A" or "Tidak ada lahan kosong untuk tanam/splice"
                    break
                end

                for idx, t in ipairs(targets) do
                    if not SpliceBot.on or SpliceBot.token ~= token or not alive() then break end
                    if CountItem(seedB) <= 0 then break end
                    local s = PlayerPhysicsState()
                    local px, py = GetTile()
                    if not (s and Nav.StateReaches(s, t.x, t.y, R)) then
                        SpliceBot.status = string.format("Menuju (%d,%d) [%d/%d]", t.x, t.y, idx, #targets)
                        if py and t.y < py then
                            Nav.ClimbUpWithDirt(px, t.y, function() return SpliceBot.token ~= token end, true, Config.moveStepDelay)
                        end
                        Nav.To(t.x, t.y, function() return SpliceBot.token ~= token end, R, true)
                        task.wait(0.2)
                    end

                    if (TileValue(w, "fg", t.x, t.y) or 0) == 0 and CountItem(seedA) > 0 then
                        if PlaceCell(seedA, { x = t.x, y = t.y }, 1) then
                            SpliceBot.planted += 1
                            Stats.Planted += 1
                            acted = true
                            task.wait(math.max(0.14, Config.spliceMs / 1000))
                        end
                    end

                    if (TileValue(w, "fg", t.x, t.y) or 0) == seedA and CountItem(seedB) > 0 and not IsSplicedTree(w, t.x, t.y) then
                        local okS, msg = DoSpliceAt(w, t.x, t.y, seedB)
                        if not okS then
                            SpliceBot.skip[t.key] = os.clock() + 45
                            SpliceBot.status = string.format("Gagal splice (%d,%d): %s", t.x, t.y, tostring(msg))
                        else
                            acted = true
                        end
                        task.wait(math.max(0.14, Config.spliceMs / 1000))
                    end
                end
            else
                -- Mode Grid 5x5
                local px, py = GetTile()
                if not px then break end
                local now = os.clock()
                for key, on in pairs(Config.farmGrid) do
                    if on then
                        local dx, dy = tostring(key):match("^(-?%d+),(-?%d+)$")
                        if dx and dy then
                            local tx, ty = px + tonumber(dx), py + tonumber(dy)
                            local k = tx .. "," .. ty
                            if InBounds(w, tx, ty) and not (SpliceBot.fail[k] and SpliceBot.fail[k] > now) then
                                local fg = TileValue(w, "fg", tx, ty) or 0
                                if fg == 0 and CountItem(seedA) > 0 and CountItem(seedB) > 0 and CanPlantAt(w, tx, ty, seedA) then
                                    if PlaceCell(seedA, { x = tx, y = ty }, 1) then
                                        SpliceBot.planted += 1
                                        Stats.Planted += 1
                                        acted = true
                                        task.wait(math.max(0.14, Config.spliceMs / 1000))
                                    end
                                end
                                if (TileValue(w, "fg", tx, ty) or 0) == seedA and CountItem(seedB) > 0 and not IsSplicedTree(w, tx, ty) then
                                    local okS, msg = DoSpliceAt(w, tx, ty, seedB)
                                    if not okS then
                                        SpliceBot.fail[k] = os.clock() + 30
                                        SpliceBot.status = string.format("Gagal splice (%d,%d): %s", tx, ty, tostring(msg))
                                    end
                                    acted = true
                                    task.wait(math.max(0.14, Config.spliceMs / 1000))
                                end
                            end
                        end
                    end
                end
                if not acted then
                    if CountItem(seedA) <= 0 or CountItem(seedB) <= 0 then
                        SpliceBot.status = "Seed habis"
                        break
                    end
                    SpliceBot.status = "Menunggu tile Grid kosong..."
                    task.wait(1)
                end
            end

            if not acted and Config.spliceRoam then break end
            task.wait(0.2)
        end
    end

    function SpliceBot.Stop()
        if not SpliceBot.on then return false end
        SpliceBot.token += 1
        SpliceBot.on = false
        SpliceBot.roaming = false
        ReleaseInput()
        AutoInput.active = false
        SpliceBot.status = "Mati"
        return true
    end

    function SpliceBot.Start()
        if SpliceBot.on then return true end
        if not (Config.spliceA and Config.spliceB) or Config.spliceA == Config.spliceB then
            Notify("Auto Splice: Pilih Seed A dan Seed B yang berbeda!")
            return false
        end
        if SpliceOk and type(SpliceModule) == "table" and not SpliceBot.Result(Config.spliceA, Config.spliceB) then
            Notify("Kombinasi Seed A & Seed B ini tidak bisa di-splice!")
            return false
        end
        if Farm.on then StopFarm() end
        if Clear.on then Clear.Stop() end
        if Farmer.on then Farmer.Stop() end
        if DF.on then DF.Stop() end
        if Pabrik.on then Pabrik.Stop() end

        local x, y = GetGridState()
        if not x then Notify("Posisi belum terdeteksi."); return false end
        local home = { x = math.floor(x), y = math.floor(y - 0.475), world = CurrentWorldName() }
        table.clear(SpliceBot.fail)
        table.clear(SpliceBot.skip)
        SpliceBot.token += 1
        local token = SpliceBot.token
        SpliceBot.on = true
        SpliceBot.roaming = Config.spliceRoam
        SpliceBot.status = "Mulai..."

        task.spawn(function()
            local ok, err = pcall(SpliceLoop, token, home)
            if not ok then warn("[ANCHHub] Auto Splice error: " .. tostring(err)) end
            ReleaseInput()
            AutoInput.active = false
            if SpliceBot.token == token then
                SpliceBot.on = false
                SpliceBot.roaming = false
                if SpliceBot.status == "Mulai..." then SpliceBot.status = "Mati" end
                if RefreshHub then RefreshHub() end
            end
        end)
        return true
    end
end)() end

----------------------------------------------------------------------
-- 6. PABRIK / FACTORY (PANEN -> TANAM -> BREAK -> AUTO DROP SEED)
----------------------------------------------------------------------
do (function()
    function Pabrik.ParseDropTarget()
        local raw = tostring(Config.pabrikDropWorld or ""):gsub("%s", "")
        local wName, doorId = string.match(raw, "^([^:]*):(.+)$")
        if not wName then wName = raw end
        wName = string.upper(wName):gsub("[^A-Z0-9]", "")
        if doorId == "" then doorId = nil end
        return wName, doorId
    end

    local function LeaveCurrentWorld()
        local m = Refs.Menu
        if m and type(rawget(m, "openPicker")) == "function" and pcall(m.openPicker) then
            return true
        end
        local w = FindWorld()
        if w and type(rawget(w, "call")) == "function" then
            return pcall(w.call, "LeaveWorld")
        end
        return false
    end

    local function EnterTargetWorld(name, doorId)
        local w = FindWorld()
        if not w or name == "" then return false, "nama world kosong" end
        if CurrentWorldName() ~= "" then
            LeaveCurrentWorld()
            task.wait(1.8)
        end
        w = FindWorld()
        if doorId and w then
            rawset(w, "arriveDoor", doorId)
        end
        local oldFg = w and rawget(w, "fg")
        local m = Refs.Menu
        if m and type(rawget(m, "enter")) == "function" then
            pcall(m.enter, name)
        elseif w and type(rawget(w, "enter")) == "function" then
            pcall(w.enter, name)
        else
            return false, "fungsi enter tidak ditemukan"
        end
        local t0 = os.clock()
        while alive() and os.clock() - t0 < 8 do
            local cw = FindWorld()
            if cw and rawget(cw, "fg") ~= oldFg and CurrentWorldName() == name then
                Refs.Scan()
                task.wait(1.2)
                return true
            end
            task.wait(0.25)
        end
        return false, "timeout / terkunci"
    end

    local function DropSeedItem(seedId, amount, liveFn)
        local hud = Refs.Hud or FindInventory()
        local onDrop = hud and rawget(hud, "onDrop")
        local rem = amount
        local nudged = false
        while rem > 0 and liveFn() do
            local before = CountItem(seedId)
            local dropNow = math.min(rem, 200)
            if type(onDrop) == "function" then
                pcall(onDrop, seedId, dropNow)
            elseif DropEvent then
                pcall(function() DropEvent:FireServer(seedId, dropNow) end)
            end
            task.wait(0.7)
            local diff = before - CountItem(seedId)
            if diff > 0 then
                rem -= diff
                Pabrik.dropped += diff
            elseif not nudged then
                nudged = true
                local s = PlayerPhysicsState()
                local faceLeft = s and (s.facing or 1) < 0
                AutoInput.active = true
                AutoInput.right, AutoInput.left = faceLeft, not faceLeft
                task.wait(0.06)
                ReleaseInput()
                AutoInput.active = false
                task.wait(0.3)
            else
                return amount - rem, "tile drop penuh"
            end
        end
        return amount - rem, nil
    end

    local function ExecuteDropCycle(seedId, amount, liveFn)
        local targetW, doorId = Pabrik.ParseDropTarget()
        local homeW = CurrentWorldName()
        if targetW == "" then targetW = homeW end
        if Config.pabrikDropX < 0 and not doorId and targetW == homeW then
            Pabrik.status = "Posisi drop belum diatur (drop dilewati)"
            Pabrik.dropOffUntil = os.clock() + 60
            return
        end

        Pabrik.traveling = true
        local diffWorld = targetW ~= homeW
        local okTravel, errMsg = true, nil

        if diffWorld or doorId then
            Pabrik.status = "Pergi ke " .. targetW .. (doorId and (":" .. doorId) or "") .. " untuk drop..."
            local okE, why = EnterTargetWorld(targetW, doorId)
            if not okE then
                okTravel, errMsg = false, "Gagal masuk " .. targetW .. " (" .. tostring(why) .. ")"
            end
        end

        if okTravel and liveFn() and Config.pabrikDropX >= 0 and Config.pabrikDropY >= 0 then
            Pabrik.status = string.format("Jalan ke posisi drop (%d,%d)...", Config.pabrikDropX, Config.pabrikDropY)
            if not Nav.To(Config.pabrikDropX, Config.pabrikDropY, function() return not liveFn() end, 0.3, true) then
                okTravel, errMsg = false, "Tidak bisa jalan ke posisi drop"
            end
        end

        if okTravel and liveFn() then
            local s = PlayerPhysicsState()
            if s then
                Pabrik.Zone = { world = CurrentWorldName(), x = s.x, y = s.y - 0.475 }
            end
            local droppedN, dropErr = DropSeedItem(seedId, amount, liveFn)
            if droppedN > 0 then
                local msg = string.format("Pabrik Drop %s x%d di %s", ItemName(seedId), droppedN, CurrentWorldName())
                Pabrik.status = msg
                Notify(msg, "Pabrik ANCH")
                Webhook.Send("pabrik", msg)
            end
            if dropErr then okTravel, errMsg = false, dropErr end
        end

        if not okTravel then
            Pabrik.dropOffUntil = os.clock() + 120
            Pabrik.status = "Drop gagal: " .. tostring(errMsg)
            Webhook.Send("pabrik", Pabrik.status)
        end

        if diffWorld and homeW ~= "" and liveFn() then
            Pabrik.status = "Pulang ke world pabrik " .. homeW .. "..."
            if not EnterTargetWorld(homeW, nil) and liveFn() then
                task.wait(4)
                EnterTargetWorld(homeW, nil)
            end
        end
        Pabrik.traveling = false
    end

    local function RunBreakSession(seedId, blockId, liveFn)
        if Config.pabrikBreakX < 0 or Config.pabrikBreakY < 0 or next(Config.pabrikTiles) == nil then
            return false
        end
        local px, py = GetTile()
        if px ~= Config.pabrikBreakX or py ~= Config.pabrikBreakY then
            Pabrik.status = string.format("Jalan ke posisi break (%d,%d)...", Config.pabrikBreakX, Config.pabrikBreakY)
            if not Nav.To(Config.pabrikBreakX, Config.pabrikBreakY, function() return not liveFn() end, 0.3, true) then
                return false
            end
        end
        if not liveFn() then return false end

        local x, y, facing = GetGridState()
        if not x then return false end
        local anchor = { x = math.floor(x), y = math.floor(y - 0.475), facing = facing, world = CurrentWorldName() }

        Farm.Override = { offsets = Config.pabrikTiles, block = blockId, mode = "Place + Break" }
        Farm.Quiet = true
        Farm.token += 1
        local fToken = Farm.token
        Farm.on = true
        local t0 = os.clock()

        task.spawn(function()
            while Farm.on and Farm.token == fToken do
                task.wait(0.8)
                local sCount = CountItem(seedId)
                if not liveFn()
                    or (os.clock() - t0) > Config.pabrikBreakSec
                    or sCount >= 190
                    or (Config.pabrikDrop and sCount >= Config.pabrikDropAt)
                    or CountItem(blockId) <= 0 then
                    Farm.on = false
                end
            end
        end)

        Pabrik.status = "Break " .. ItemName(blockId) .. " di posisi pabrik..."
        pcall(RunFarmLoopDirect, fToken, anchor)
        Farm.on = false
        Farm.Override = nil
        Farm.Quiet = false
        return true
    end

    local function PabrikLoop(token, blockId)
        local function liveFn()
            return Pabrik.on and Pabrik.token == token and alive()
        end
        local R = math.min(PunchReach(), BuildReach()) - 0.15

        while liveFn() do
            local w = FindWorld()
            if not w then task.wait(1); continue end
            local seedId = Config.pabrikSeedId
            local sCount = CountItem(seedId)
            local bCount = CountItem(blockId)

            -- 1. Cek Auto Drop Seed
            if Config.pabrikDrop and sCount >= Config.pabrikDropAt and sCount > Config.pabrikKeep and os.clock() >= (Pabrik.dropOffUntil or 0) then
                Pabrik.phase = "DROP"
                ExecuteDropCycle(seedId, sCount - Config.pabrikKeep, liveFn)
                if not liveFn() then break end
                w = FindWorld()
            end

            -- 2. Fase PANEN (Harvest pohon siap)
            Pabrik.phase = "PANEN"
            local readyTrees = {}
            local soonestWait = nil
            local nowSrv = workspace:GetServerTimeNow()
            for y = 0, w.h - 1 do
                for x = 0, w.w - 1 do
                    local fg = TileValue(w, "fg", x, y) or 0
                    if fg == seedId then
                        local rAt = TreeReadyAt(w, x, y, fg)
                        if rAt then
                            if nowSrv >= rAt then
                                table.insert(readyTrees, { x = x, y = y })
                            elseif not soonestWait or (rAt - nowSrv) < soonestWait then
                                soonestWait = rAt - nowSrv
                            end
                        end
                    end
                end
            end

            if #readyTrees > 0 and CountItem(blockId) < 180 and CountItem(seedId) < 180 then
                for idx, t in ipairs(readyTrees) do
                    if not liveFn() or CountItem(blockId) >= 185 or CountItem(seedId) >= 185 then break end
                    local px, py = GetTile()
                    local s = PlayerPhysicsState()
                    if not (s and Nav.StateReaches(s, t.x, t.y, R)) then
                        Pabrik.status = string.format("Panen menuju (%d,%d) [%d/%d]", t.x, t.y, idx, #readyTrees)
                        if py and t.y < py then
                            Nav.ClimbUpWithDirt(px, t.y, function() return not liveFn() end, true, Config.harvestTpDelay)
                        end
                        Nav.To(t.x, t.y, function() return not liveFn() end, R, true)
                    end
                    local t0 = os.clock()
                    while liveFn() and (TileValue(w, "fg", t.x, t.y) or 0) == seedId and os.clock() - t0 < 3.5 do
                        local r = TryBreakOnce(t.x, t.y, false)
                        if r == "broke" then
                            Pabrik.harvested += 1
                            Stats.Harvested += 1
                        end
                        task.wait(math.max(0.05, Config.harvestDelay))
                    end
                end
            end

            if not liveFn() then break end

            -- 3. Fase TANAM (Plant seed di lahan kosong)
            if CountItem(seedId) > 0 then
                Pabrik.phase = "TANAM"
                local spots = {}
                for y = 0, w.h - 1 do
                    for x = 0, w.w - 1 do
                        if (TileValue(w, "fg", x, y) or 0) == 0 and CanPlantAt(w, x, y, seedId) then
                            -- Jangan tanam di titik break pabrik
                            if not (x == Config.pabrikBreakX and y == Config.pabrikBreakY) then
                                table.insert(spots, { x = x, y = y })
                            end
                        end
                    end
                end
                for idx, sp in ipairs(spots) do
                    if not liveFn() or CountItem(seedId) <= 0 then break end
                    if CanPlantAt(w, sp.x, sp.y, seedId) then
                        local px, py = GetTile()
                        local s = PlayerPhysicsState()
                        if not (s and Nav.StateReaches(s, sp.x, sp.y, R)) then
                            Pabrik.status = string.format("Tanam menuju (%d,%d) [%d/%d]", sp.x, sp.y, idx, #spots)
                            if py and sp.y < py then
                                Nav.ClimbUpWithDirt(px, sp.y, function() return not liveFn() end, true, Config.harvestTpDelay)
                            end
                            Nav.To(sp.x, sp.y, function() return not liveFn() end, R, true)
                        end
                        if CanPlantAt(w, sp.x, sp.y, seedId) and PlaceCell(seedId, sp, 1) then
                            Pabrik.planted += 1
                            Stats.Planted += 1
                            task.wait(math.max(0.05, Config.harvestPlantDelay))
                        end
                    end
                end
            end

            if not liveFn() then break end

            -- 4. Fase BREAK (Break block di posisi pabrik)
            if CountItem(blockId) > 0 then
                Pabrik.phase = "BREAK"
                if not RunBreakSession(seedId, blockId, liveFn) then
                    Pabrik.status = "Ada block tapi posisi / tile break belum diatur"
                    task.wait(2)
                end
            else
                -- 5. Fase TUNGGU
                Pabrik.phase = "TUNGGU"
                if soonestWait then
                    Pabrik.status = string.format("Menunggu pohon siap panen (±%ds)...", math.ceil(soonestWait))
                elseif CountItem(seedId) <= 0 and CountItem(blockId) <= 0 then
                    Pabrik.status = "Seed & block habis, tidak ada pohon tumbuh"
                    Webhook.Send("pabrik", "Pabrik berhenti: Seed & block habis")
                    break
                else
                    Pabrik.status = "Menunggu..."
                end
                task.wait(1.5)
            end
        end
    end

    function Pabrik.Stop()
        if not Pabrik.on then return false end
        Pabrik.token += 1
        Pabrik.on = false
        Pabrik.traveling = false
        if Farm.Override then
            Farm.on = false
            Farm.Override = nil
            Farm.Quiet = false
        end
        ReleaseInput()
        AutoInput.active = false
        Pabrik.phase = "-"
        Pabrik.status = "Mati"
        if UpdateGridVisuals then pcall(UpdateGridVisuals) end
        return true
    end

    function Pabrik.Start()
        if Pabrik.on then return true end
        local seedId = Config.pabrikSeedId
        local blockId = BlockOfSeed(seedId)
        if not seedId or not blockId then
            Notify("Pabrik: Pilih seed pabrik yang valid terlebih dahulu!")
            return false
        end
        if Farm.on then StopFarm() end
        if Clear.on then Clear.Stop() end
        if Farmer.on then Farmer.Stop() end
        if DF.on then DF.Stop() end
        if SpliceBot.on then SpliceBot.Stop() end

        Pabrik.home = CurrentWorldName()
        Pabrik.dropOffUntil = 0
        Pabrik.token += 1
        local token = Pabrik.token
        Pabrik.on = true
        Pabrik.phase = "MULAI"
        Pabrik.status = "Inisialisasi Pabrik..."
        if UpdateGridVisuals then pcall(UpdateGridVisuals) end

        task.spawn(function()
            local ok, err = pcall(PabrikLoop, token, blockId)
            if not ok then warn("[ANCHHub] Pabrik error: " .. tostring(err)) end
            ReleaseInput()
            AutoInput.active = false
            if Pabrik.token == token then
                Pabrik.on = false
                Pabrik.traveling = false
                Pabrik.phase = "-"
                if Pabrik.status == "Inisialisasi Pabrik..." then Pabrik.status = "Mati" end
                if UpdateGridVisuals then pcall(UpdateGridVisuals) end
                if RefreshHub then RefreshHub() end
            end
        end)
        return true
    end
end)() end

----------------------------------------------------------------------
-- 7. MANAJEMEN TAS: AUTO RECYCLE & AUTO CONVERT LOCK (WL -> DL -> BGL)
----------------------------------------------------------------------
do (function()
    local LOCK_IDS = { [242] = true, [1796] = true, [7188] = true }
    local LOCK_CONVERSIONS = {
        { from = 242,  to = 1796, name = "Diamond Lock" },
        { from = 1796, to = 7188, name = "Blue Gem Lock" },
    }

    local function worldCall(...)
        local w = FindWorld()
        local fn = w and rawget(w, "call")
        if type(fn) ~= "function" then return false end
        return pcall(fn, ...)
    end

    local function canRecycleItem(id)
        local it = ItemDB[id]
        return it ~= nil and it.kind ~= "tool" and not it.lock and not LOCK_IDS[id]
    end

    function Bag.Recycle(id, count)
        if not Refs.Inv or count <= 0 or not canRecycleItem(id) then return false end
        count = math.min(count, CountItem(id))
        if count <= 0 then return false end
        pcall(function() Refs.Inv:remove(id, count) end)
        local ok = worldCall("Recycle", id, count)
        if ok then
            Bag.recycled += count
            Bag.status = string.format("Recycle %s x%d", ItemName(id), count)
        end
        return ok
    end

    local function convertLockStep(rule)
        local inv = Refs.Inv
        if not inv or CountItem(rule.from) < 100 then return false end
        if CountItem(rule.to) + 1 > 200 then return false end
        pcall(function()
            inv:remove(rule.from, 100)
            inv:add(rule.to, 1)
        end)
        local ok = worldCall("ConvertLock", rule.from, rule.to)
        if ok then
            Bag.converted += 1
            Bag.status = "Convert ke " .. rule.name
        end
        return ok
    end

    task.spawn(function()
        while alive() do
            pcall(function()
                if Config.trashOn and type(Config.trashList) == "table" then
                    for _, id in ipairs(Config.trashList) do
                        local have = CountItem(id)
                        if have >= Config.trashAt and have > Config.trashKeep then
                            Bag.Recycle(id, have - Config.trashKeep)
                            task.wait(0.5)
                        end
                    end
                end
                if Config.convertLockOn then
                    for _, rule in ipairs(LOCK_CONVERSIONS) do
                        if convertLockStep(rule) then
                            task.wait(0.5)
                        end
                    end
                end
            end)
            task.wait(2.5)
        end
    end)
end)() end

----------------------------------------------------------------------
-- 8. PENJAGA (ANTI-MOD) & AUTO RECONNECT LINTAS WORLD/SERVER
----------------------------------------------------------------------
do (function()
    local function strip(s) return (tostring(s or ""):gsub("`.", "")) end

    local function roleOf(uid)
        if not (RolesOk and type(RolesModule) == "table") then return nil end
        local okD, dev = pcall(RolesModule.isDeveloper, uid)
        if okD and dev then return "Developer" end
        local okM, mod = pcall(RolesModule.isModerator, uid)
        if okM and mod then return "Moderator" end
        return nil
    end

    local function playersHere()
        local out = {}
        local o = Refs.Others
        if not o or type(rawget(o, "list")) ~= "function" then return out end
        local ok, list = pcall(o.list)
        if not ok or type(list) ~= "table" then return out end
        for _, e in ipairs(list) do
            local uid = type(e) == "table" and tonumber(e[1] or e.userId)
            if uid and uid ~= Player.UserId then
                out[#out + 1] = { id = uid, name = strip(e[2] or e.name or uid), role = roleOf(uid) }
            end
        end
        return out
    end

    local function threatsOf(list)
        local out = {}
        for _, p in ipairs(list) do
            if p.role or (Config.guardWho == "Semua pemain" and not Guard.allow[p.id]) then
                out[#out + 1] = p
            end
        end
        return out
    end

    local function formatPlayer(p)
        local under = false
        if p.role and RolesOk and type(RolesModule.isUndercover) == "function" then
            local ok, u = pcall(RolesModule.isUndercover, p.id)
            under = ok and u == true
        end
        return p.name .. " (" .. (p.role or "Pemain") .. (under and ", undercover" or "") .. ")"
    end

    local function namesList(list)
        local t = {}
        for i, p in ipairs(list) do
            if i > 5 then
                t[#t + 1] = "+" .. (#list - i + 1) .. " lagi"
                break
            end
            t[#t + 1] = formatPlayer(p)
        end
        return #t > 0 and table.concat(t, ", ") or "tidak ada"
    end

    local function anyBotRunning()
        return (Farm.on and not Farm.Override) or Clear.on or Farmer.on or DF.on or SpliceBot.on or Pabrik.on or Spam.on
    end

    local function snapshot()
        local tx, ty = GetTile()
        return {
            farm = Farm.on and not Farm.Override,
            clear = Clear.on,
            farmer = Farmer.on,
            df = DF.on,
            splice = SpliceBot.on,
            pabrik = Pabrik.on,
            spam = Spam.on,
            world = CurrentWorldName(),
            tx = tx,
            ty = ty,
        }
    end

    local function stopAllBots()
        if Pabrik.on then Pabrik.Stop() end
        if SpliceBot.on then SpliceBot.Stop() end
        if Farm.on then StopFarm() end
        if Clear.on then Clear.Stop(); Clear.status = "Dijeda Penjaga" end
        if Farmer.on then Farmer.Stop(); Farmer.status = "Dijeda Penjaga" end
        if DF.on then DF.Stop(); DF.status = "Dijeda Penjaga" end
        if Spam.on then Spam.on = false end
        ReleaseInput()
        if RefreshHub then RefreshHub() end
    end

    local function leaveWorld()
        local m = Refs.Menu
        if m and type(rawget(m, "openPicker")) == "function" and pcall(m.openPicker) then
            return true
        end
        local w = FindWorld()
        if w and type(rawget(w, "call")) == "function" then
            return pcall(w.call, "LeaveWorld")
        end
        return false
    end

    local function enterWorld(name)
        local w = FindWorld()
        if not w or name == "" then return false end
        local oldFg = rawget(w, "fg")
        local m = Refs.Menu
        if m and type(rawget(m, "enter")) == "function" then
            pcall(m.enter, name)
        elseif type(rawget(w, "enter")) == "function" then
            pcall(w.enter, name)
        else
            return false
        end
        local t0 = os.clock()
        while alive() and os.clock() - t0 < 8 do
            local cw = FindWorld()
            if cw and rawget(cw, "fg") ~= oldFg then return true end
            task.wait(0.25)
        end
        return false
    end

    local function resumeSaved(saved, token)
        if not saved then return end
        if saved.world ~= "" and CurrentWorldName() ~= saved.world then return end
        if saved.spam then Spam.on = true end
        if saved.tx and saved.ty then
            local cx, cy = GetTile()
            if cx and (cx ~= saved.tx or cy ~= saved.ty) then
                Guard.status = string.format("Jalan balik ke (%d,%d)...", saved.tx, saved.ty)
                Nav.To(saved.tx, saved.ty, function() return (token and Guard.token ~= token) or not alive() end, 0.3, true)
            end
        end
        if token and Guard.token ~= token then return end
        if saved.farm then StartFarm()
        elseif saved.clear then Clear.Start()
        elseif saved.farmer then Farmer.Start()
        elseif saved.df then DF.Start()
        elseif saved.splice then SpliceBot.Start()
        elseif saved.pabrik then Pabrik.Start() end
        if RefreshHub then RefreshHub() end
    end

    Guard.Snapshot = snapshot
    Guard.StopAllBots = stopAllBots
    Guard.LeaveWorld = leaveWorld
    Guard.EnterWorld = enterWorld
    Guard.ResumeSaved = resumeSaved
    Guard.AnyRunning = anyBotRunning

    function Guard.AllowCurrentPlayers()
        local n = 0
        for _, p in ipairs(playersHere()) do
            if not p.role then
                Guard.allow[p.id] = true
                n += 1
            end
        end
        return n
    end

    function Guard.Set(on)
        Guard.on = on
        Guard.token += 1
        Guard.mode, Guard.saved, Guard.calmAt = "idle", nil, nil
        table.clear(Guard.alerted)
        table.clear(Guard.allow)
        if on then
            Guard.AllowCurrentPlayers()
            Guard.status = "Aman (Memantau)"
        else
            Guard.status = "Mati"
        end
    end

    task.spawn(function()
        while alive() do
            pcall(function()
                local stList = {}
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= Player then
                        local r = roleOf(plr.UserId)
                        if r then table.insert(stList, (plr.DisplayName or plr.Name) .. " (" .. r .. ")") end
                    end
                end
                Guard.staffServerText = #stList > 0 and table.concat(stList, ", ") or "tidak ada"

                local here = (Guard.mode ~= "away" and Guard.mode ~= "out") and playersHere() or {}
                Guard.hereText = namesList(here)

                if not Guard.on then
                    Guard.status = "Mati"
                    return
                end

                local now = os.clock()
                if Guard.mode == "away" or Guard.mode == "out" then
                    local name = Guard.saved and Guard.saved.world or ""
                    if Guard.mode == "out" or name == "" then
                        Guard.status = "Sudah keluar world"
                        return
                    end
                    local left = Guard.backAt - now
                    if left > 0 then
                        Guard.status = string.format("Di luar world. Masuk %s dlm %ds", name, math.ceil(left))
                        return
                    end
                    Guard.status = "Masuk kembali ke " .. name .. "..."
                    if enterWorld(name) then
                        Refs.Scan()
                        task.wait(1.5)
                        local th = threatsOf(playersHere())
                        if #th > 0 then
                            Notify("Masih ada " .. namesList(th) .. "! Keluar lagi.", "Penjaga ANCH")
                            leaveWorld()
                            Guard.backAt = os.clock() + Config.guardBackSec
                        else
                            Notify("World sudah aman, melanjutkan aktivitas!", "Penjaga ANCH")
                            Webhook.Send("penjaga", "World " .. name .. " aman, lanjut aktivitas")
                            local sv = Guard.saved
                            Guard.mode, Guard.saved = "idle", nil
                            Guard.token += 1
                            local tk = Guard.token
                            task.spawn(resumeSaved, sv, tk)
                        end
                    else
                        Guard.backAt = os.clock() + math.max(15, Config.guardBackSec)
                    end
                    return
                end

                local present = {}
                for _, p in ipairs(here) do present[p.id] = true end
                for id in pairs(Guard.alerted) do
                    if not present[id] then Guard.alerted[id] = nil end
                end

                local threats = threatsOf(here)
                local fresh = {}
                for _, p in ipairs(threats) do
                    if not Guard.alerted[p.id] then
                        Guard.alerted[p.id] = true
                        fresh[#fresh + 1] = p
                    end
                end

                if #fresh > 0 then
                    Guard.detected += #fresh
                    local alertMsg = "Terdeteksi masuk world " .. CurrentWorldName() .. ": " .. namesList(fresh)
                    Notify(alertMsg, "PERINGATAN PENJAGA", 6)
                    Webhook.Send("penjaga", alertMsg)
                    if Config.guardStopAll or Config.guardLeave then
                        if not Guard.saved then Guard.saved = snapshot() end
                        Guard.token += 1
                        stopAllBots()
                        Guard.calmAt = nil
                        if Config.guardLeave then
                            if leaveWorld() then
                                Guard.backAt = os.clock() + Config.guardBackSec
                                Guard.mode = Config.guardAutoBack and "away" or "out"
                                Guard.status = "Keluar world"
                                return
                            end
                        end
                        Guard.mode = "pause"
                    end
                end

                if #threats > 0 then
                    Guard.calmAt = nil
                    Guard.status = (Guard.mode == "pause" and "Dijeda! Ada: " or "Waspada! Ada: ") .. namesList(threats)
                elseif Guard.mode == "pause" then
                    Guard.calmAt = Guard.calmAt or now
                    local rem = Config.guardCalmSec - (now - Guard.calmAt)
                    if rem > 0 then
                        Guard.status = string.format("Sudah sepi. Lanjut dlm %ds...", math.ceil(rem))
                    else
                        Guard.calmAt = nil
                        local sv = Guard.saved
                        Guard.mode, Guard.saved = "idle", nil
                        if Config.guardAutoBack and sv then
                            Notify("World aman, melanjutkan aktivitas!", "Penjaga ANCH")
                            Guard.token += 1
                            local tk = Guard.token
                            task.spawn(resumeSaved, sv, tk)
                        end
                    end
                else
                    Guard.status = "Aman (Memantau)"
                end
            end)
            task.wait(0.5)
        end
    end)

    -- AUTO RECONNECT (WORLD CLOSED & SERVER DISCONNECT)
    function Reconnect.TargetWorld()
        local t = tostring(Config.targetWorld or ""):upper():gsub("[^A-Z0-9]", "")
        if t ~= "" then return t end
        return Config.lastWorld or ""
    end

    task.spawn(function()
        while alive() do
            local wName = CurrentWorldName()
            if wName ~= "" and not Pabrik.traveling then
                Config.lastWorld = wName
            end
            if anyBotRunning() and Guard.mode == "idle" then
                Reconnect.last = snapshot()
                Reconnect.lastAt = os.clock()
            end
            task.wait(1)
        end
    end)

    local function onWorldKicked(reason)
        if not (Config.reconnectOn and Config.reconnectWorld) or Reconnect.busy or Pabrik.traveling then return end
        if Guard.mode == "away" or Guard.mode == "out" then return end
        local snap = Reconnect.last
        if not snap or snap.world == "" or os.clock() - Reconnect.lastAt > 15 then return end
        Reconnect.busy = true
        task.spawn(function()
            stopAllBots()
            Reconnect.status = "Terlempar dari " .. snap.world .. ". Masuk lagi..."
            Webhook.Send("rejoin", "Terlempar dari world " .. snap.world .. " (" .. strip(reason) .. ")")
            task.wait(Config.reconnectDelay + 1.5)
            for attempt = 1, 3 do
                if not alive() or not Config.reconnectOn then break end
                if enterWorld(snap.world) then
                    Refs.Scan()
                    task.wait(1.5)
                    Reconnect.count += 1
                    Reconnect.status = "Berhasil masuk lagi ke " .. snap.world
                    Webhook.Send("rejoin", "Berhasil masuk kembali ke " .. snap.world)
                    resumeSaved(snap, nil)
                    Reconnect.busy = false
                    return
                end
                Reconnect.status = string.format("Gagal masuk (%d/3), coba lagi...", attempt)
                task.wait(8)
            end
            Reconnect.busy = false
        end)
    end

    if WorldClosedRemote and WorldClosedRemote:IsA("RemoteEvent") then
        trackConn(WorldClosedRemote.OnClientEvent:Connect(function(reason)
            if alive() then onWorldKicked(reason) end
        end))
    end

    -- Pantau jika karakter berada di luar world & Keep in World aktif
    task.spawn(function()
        local outsideSince = nil
        while alive() do
            task.wait(2)
            local outside = CurrentWorldName() == ""
            local canKeep = Config.reconnectOn and Config.reconnectKeep and not Reconnect.busy and not Reconnect.leaving and not Pabrik.traveling and Guard.mode == "idle"
            if not (outside and canKeep) then
                outsideSince = nil
            else
                outsideSince = outsideSince or os.clock()
                local target = Reconnect.TargetWorld()
                if target ~= "" and os.clock() - outsideSince >= Config.reconnectDelay then
                    outsideSince = nil
                    Reconnect.busy = true
                    Reconnect.status = "Di luar world, masuk ke " .. target .. "..."
                    if enterWorld(target) then
                        Refs.Scan()
                        task.wait(1.5)
                        Reconnect.count += 1
                        Reconnect.status = "Kembali otomatis ke " .. target
                        if Reconnect.last and Reconnect.last.world == target then
                            resumeSaved(Reconnect.last, nil)
                        end
                    end
                    Reconnect.busy = false
                end
            end
        end
    end)

    -- Server Disconnect Handler
    pcall(function()
        trackConn(GuiService.ErrorMessageChanged:Connect(function(msg)
            if not alive() or type(msg) ~= "string" or msg == "" then return end
            if not (Config.reconnectOn and Config.reconnectServer) or Reconnect.leaving then return end
            Reconnect.leaving = true
            local snap = Reconnect.last or (anyBotRunning() and snapshot()) or nil
            local targetW = (snap and snap.world) or CurrentWorldName()
            if writefile and snap then
                snap.at = os.time()
                pcall(writefile, REJOIN_FILE, HttpService:JSONEncode(snap))
            end
            if QueueReload then pcall(QueueReload) end
            Webhook.Send("rejoin", "Disconnect dari server (" .. msg .. "). Rejoin otomatis...")
            task.spawn(function()
                task.wait(Config.reconnectDelay)
                while alive() do
                    pcall(function()
                        TeleportService:Teleport(game.PlaceId, Player, (targetW ~= "") and { world = targetW } or nil)
                    end)
                    task.wait(12)
                end
            end)
        end))
    end)

    function Reconnect.CheckStartup()
        pcall(function()
            if not (isfile and readfile and isfile(REJOIN_FILE)) then return end
            local raw = readfile(REJOIN_FILE)
            if delfile then pcall(delfile, REJOIN_FILE) end
            local snap = HttpService:JSONDecode(raw)
            if type(snap) ~= "table" or type(snap.world) ~= "string" or snap.world == "" then return end
            if os.time() - (tonumber(snap.at) or 0) > 900 then return end
            Reconnect.busy = true
            Reconnect.status = "Pulihkan sesi setelah Rejoin Server: " .. snap.world
            local t0 = os.clock()
            local triedEnter = false
            while alive() and os.clock() - t0 < 50 do
                if CurrentWorldName() == snap.world and GetTile() then break end
                if CurrentWorldName() == "" and not triedEnter and os.clock() - t0 > 8 then
                    triedEnter = true
                    enterWorld(snap.world)
                end
                task.wait(2)
            end
            if alive() and CurrentWorldName() == snap.world then
                Refs.Scan()
                task.wait(1.5)
                Reconnect.count += 1
                Webhook.Send("rejoin", "Berhasil rejoin server ke world " .. snap.world .. ", melanjutkan bot!")
                resumeSaved(snap, nil)
            end
            Reconnect.busy = false
        end)
    end
end)() end

----------------------------------------------------------------------
-- 9. STATISTIK SESI, AUTO CHAT (1 PESAN), BONUS, LITE MODE, WATERMARK
----------------------------------------------------------------------
local Bonus = {
    claimed = 0,
    redeemed = 0,
    tried = {},
    questFail = {},
    questText = "-",
    codeText = "-",
    nextQuest = 0,
    nextCode = 0,
}

local LiteMode = { saved = {} }

do (function()
    local function formatNum(n)
        local s = tostring(math.floor(tonumber(n) or 0))
        local neg = s:sub(1, 1) == "-"
        if neg then s = s:sub(2) end
        local rev = s:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
        return (neg and "-" or "") .. rev
    end

    local function formatDuration(sec)
        sec = math.max(0, math.floor(sec or 0))
        return string.format("%dj %dm %dd", sec // 3600, (sec % 3600) // 60, sec % 60)
    end

    function Stats.GemsNow()
        local g = Refs.Gems
        local fn = g and rawget(g, "addGems")
        if type(fn) ~= "function" then return nil end
        for _, v in pairs(GetUpvalues(fn)) do
            if type(v) == "number" then return v end
        end
        return nil
    end

    function Stats.Reset()
        Stats.T0 = os.clock()
        Stats.Gems0 = Stats.GemsNow()
        Stats.Placed = 0
        Stats.Broken = 0
        Stats.Collected = 0
        Stats.Harvested = 0
        Stats.Planted = 0
        table.clear(Stats.Items)
    end

    function Stats.Text()
        local hours = math.max((os.clock() - Stats.T0) / 3600, 1 / 3600)
        local function rateLine(label, val)
            return string.format("%s: %s (%s/jam)", label, formatNum(val), formatNum(val / hours))
        end
        local gNow = Stats.GemsNow()
        if gNow and not Stats.Gems0 then Stats.Gems0 = gNow end
        local gemLine = "Gems: -"
        if gNow and Stats.Gems0 then
            local diff = gNow - Stats.Gems0
            gemLine = string.format("Gems: %s (%s%s, %s/jam)", formatNum(gNow), diff >= 0 and "+" or "", formatNum(diff), formatNum(diff / hours))
        end
        local topArr = {}
        for id, n in pairs(Stats.Items) do table.insert(topArr, { id = id, n = n }) end
        table.sort(topArr, function(a, b) return a.n > b.n end)
        local topStr = {}
        for i = 1, math.min(5, #topArr) do
            topStr[i] = ItemName(topArr[i].id) .. " x" .. formatNum(topArr[i].n)
        end
        return table.concat({
            "Lama Sesi: " .. formatDuration(os.clock() - Stats.T0),
            gemLine,
            rateLine("Block Pecah", Stats.Broken),
            rateLine("Block Dipasang", Stats.Placed),
            rateLine("Drop Diambil", Stats.Collected),
            rateLine("Pohon Dipanen", Stats.Harvested),
            rateLine("Seed Ditanam", Stats.Planted),
            "Item Terbanyak: " .. (#topStr > 0 and table.concat(topStr, ", ") or "-"),
        }, "\n")
    end

    task.spawn(function()
        local lastReport = os.clock()
        while alive() do
            if Config.webhookReportMin > 0 and (os.clock() - lastReport) >= Config.webhookReportMin * 60 then
                lastReport = os.clock()
                local ok, txt = pcall(Stats.Text)
                if ok then
                    Webhook.Send("report", "Laporan Statistik Sesi\n```\n" .. txt .. "\n```")
                end
            elseif Config.webhookReportMin <= 0 then
                lastReport = os.clock()
            end
            task.wait(2)
        end
    end)

    -- Auto Chat (Hanya mengirim 1 pesan tunggal yang diatur)
    local function getWorldChannel()
        local folder = TextChatService:FindFirstChild("WorldChannels")
        if not folder then return nil end
        local wName = CurrentWorldName()
        if wName ~= "" and folder:FindFirstChild(wName) then
            return folder:FindFirstChild(wName)
        end
        for _, ch in ipairs(folder:GetChildren()) do
            if ch:IsA("TextChannel") then
                for _, src in ipairs(ch:GetChildren()) do
                    if src:IsA("TextSource") and src.UserId == Player.UserId then return ch end
                end
            end
        end
        return nil
    end

    function Spam.SendNext()
        local msg = Trim(Config.chatText)
        if msg == "" then
            Spam.last = "Pesan chat belum diisi"
            return false
        end
        local ch = getWorldChannel()
        if not ch then
            Spam.last = "Channel chat belum ada"
            return false
        end
        local ok, err = pcall(ch.SendAsync, ch, msg)
        if ok then
            Spam.sent += 1
            Spam.last = msg
        else
            Spam.last = "Gagal: " .. tostring(err)
        end
        return ok
    end

    task.spawn(function()
        while alive() do
            if Spam.on and os.clock() >= Spam.nextAt then
                Spam.SendNext()
                Spam.nextAt = os.clock() + math.max(3, Config.chatInterval)
            end
            task.wait(0.3)
        end
    end)

    local function stripColor(s) return (tostring(s or ""):gsub("`.", "")) end
    local function netCall(...)
        if NetOk and type(Net) == "table" and type(Net.call) == "function" then
            return pcall(Net.call, ...)
        end
        return false, "Net.call tidak tersedia"
    end

    function Bonus.CheckQuests()
        local ok, good, data = netCall("Quests", "list")
        if not ok or not good or type(data) ~= "table" or type(data.quests) ~= "table" then
            Bonus.questText = "Quest belum terbaca dari server"
            return
        end
        local total, done = 0, 0
        local now = os.clock()
        for _, q in ipairs(data.quests) do
            total += 1
            local have, need = tonumber(q.have) or 0, tonumber(q.need) or math.huge
            if q.claimed then
                done += 1
            elseif have >= need and not ((Bonus.questFail[q.id] or 0) > now) then
                local okC, success, _, _, gems = netCall("Quests", "claim", q.id)
                if okC and success then
                    done += 1
                    Bonus.claimed += 1
                    local qName = stripColor(q.text or q.id)
                    Notify("Quest diklaim: " .. qName, "Bonus ANCH")
                    Webhook.Send("bonus", "Quest diklaim: " .. qName)
                    if type(gems) == "number" and Refs.Gems and type(Refs.Gems.setGems) == "function" then
                        pcall(Refs.Gems.setGems, gems)
                    end
                else
                    Bonus.questFail[q.id] = now + 120
                end
                task.wait(0.5)
            end
        end
        Bonus.questText = string.format("Selesai: %d/%d | Diklaim script: %d", done, total, Bonus.claimed)
    end

    function Bonus.RedeemSingle(code)
        local ok, res = netCall("ModCommand", "redeemcode", code)
        if not ok then return nil, "Gagal menghubungi server" end
        local lines = type(res) == "table" and type(res.lines) == "table" and res.lines or nil
        if not lines then return false, "Balasan kosong" end
        local first = tostring(lines[1] or "")
        local parts = {}
        for _, l in ipairs(lines) do table.insert(parts, stripColor(l)) end
        return string.sub(first, 1, 2) == "`2", table.concat(parts, " ")
    end

    function Bonus.CheckCodes()
        local ok, list = netCall("ActiveCodes")
        if not ok or type(list) ~= "table" then
            Bonus.codeText = "Gagal mengambil ActiveCodes"
            return
        end
        if list.note ~= nil then
            Bonus.codeText = "Redeem ditutup: " .. stripColor(list.note)
            return
        end
        local total, have = 0, 0
        for _, c in ipairs(list) do
            total += 1
            local code = c.code and tostring(c.code)
            if c.done then
                have += 1
            elseif code and not Bonus.tried[code] and not (type(c.uses) == "number" and c.uses == 0) then
                local success, msg = Bonus.RedeemSingle(code)
                if success ~= nil then Bonus.tried[code] = true end
                if success then
                    have += 1
                    Bonus.redeemed += 1
                    Notify(code .. " -> " .. tostring(msg), "Redeem Berhasil!")
                    Webhook.Send("bonus", "Redeem berhasil " .. code .. ": " .. tostring(msg))
                end
                task.wait(0.8)
            end
        end
        Bonus.codeText = string.format("Code aktif: %d | Sudah ditukar: %d | Baru: %d", total, have, Bonus.redeemed)
    end

    task.spawn(function()
        while alive() do
            local now = os.clock()
            if Config.bonusAutoQuest and now >= Bonus.nextQuest then
                Bonus.nextQuest = now + 30
                pcall(Bonus.CheckQuests)
            end
            if Config.bonusAutoRedeem and now >= Bonus.nextCode then
                Bonus.nextCode = now + 300
                pcall(Bonus.CheckCodes)
            end
            task.wait(1)
        end
    end)

    local DummyLabel = setmetatable({}, { __index = function() return 0 end, __newindex = function() end })
    local DummyParticle = setmetatable({ l = DummyLabel, k = {} }, { __index = function() return 0 end, __newindex = function() end })
    local NullSound
    NullSound = setmetatable({}, {
        __index = function() return NullSound end,
        __newindex = function() end,
        __call = function() return NullSound end,
    })

    local function overrideFn(tbl, key, repl)
        if type(tbl) == "table" and type(rawget(tbl, key)) == "function" then
            table.insert(LiteMode.saved, { tbl, key, rawget(tbl, key) })
            tbl[key] = repl
        end
    end

    function LiteMode.Set(on)
        Config.liteMode = on
        if on then
            if #LiteMode.saved == 0 then
                if ParticlesOk and ParticlesModule then overrideFn(ParticlesModule, "spawn", function() return DummyParticle end) end
                if SfxOk and SfxModule then
                    overrideFn(SfxModule, "play", function() return NullSound end)
                    overrideFn(SfxModule, "playAt", function() return NullSound end)
                end
            end
            for _, p in ipairs(Refs.Particles) do
                pcall(function()
                    for _, e in ipairs(p.live) do
                        if typeof(e.l) == "Instance" then e.l.Visible = false end
                    end
                end)
            end
        else
            for _, s in ipairs(LiteMode.saved) do
                pcall(function() s[1][s[2]] = s[3] end)
            end
            table.clear(LiteMode.saved)
        end
    end

    local NameFx = { t0 = os.clock(), tag = nil, panel = nil }
    local NAME_COLORS = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(48, 255, 106)),
        ColorSequenceKeypoint.new(0.25, Color3.fromRGB(60, 205, 255)),
        ColorSequenceKeypoint.new(0.50, Color3.fromRGB(231, 255, 47)),
        ColorSequenceKeypoint.new(0.75, Color3.fromRGB(60, 205, 255)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(48, 255, 106)),
    })
    local NAME_FONT = Enum.Font.FredokaOne

    local function nameHolders()
        local gg = PlayerGui:FindFirstChild("GameGui")
        local world = gg and gg:FindFirstChild("World")
        local cam = world and world:FindFirstChild("Camera")
        local chat = PlayerGui:FindFirstChild("ChatGui")
        local hud = chat and chat:FindFirstChild("HUD")
        local panel = hud and hud:FindFirstChild("PlayerPanel")
        return cam and cam:FindFirstChild("NameTag"), panel and panel:FindFirstChild("Name")
    end

    local function textWidth(text, size)
        local ok, v = pcall(TextService.GetTextSize, TextService, text, size, NAME_FONT, Vector2.new(2000, 200))
        return (ok and v.X or #text * size * 0.55) + 6
    end

    local function makeLabel(holder, size, isTag)
        local lb = Instance.new("TextLabel")
        lb.Name = "ANCHWatermark"
        lb.BackgroundTransparency = 1
        lb.Font = NAME_FONT
        lb.TextSize = size
        lb.TextColor3 = Color3.new(1, 1, 1)
        lb.Text = Config.watermarkText
        lb.ZIndex = isTag and 1017 or 10
        if isTag then
            lb.AnchorPoint = Vector2.new(0.5, 0.5)
            lb.Position = UDim2.fromScale(0.5, 0.5)
        else
            lb.AnchorPoint = Vector2.new(0, 0.5)
            lb.Position = UDim2.new(0, 3, 0.5, 0)
            lb.TextXAlignment = Enum.TextXAlignment.Left
        end
        local st = Instance.new("UIStroke", lb)
        st.Thickness = 2
        st.Color = Color3.fromRGB(18, 28, 20)
        local gr = Instance.new("UIGradient", lb)
        gr.Color = NAME_COLORS
        gr.Rotation = 12
        local sc = Instance.new("UIScale", lb)
        lb.Parent = holder
        return { holder = holder, bitmap = holder:FindFirstChild("BitmapText"), label = lb, gr = gr, sc = sc, size = size, isTag = isTag, text = nil, w = 0 }
    end

    local function dropEntry(e)
        if not e then return end
        pcall(function() e.label:Destroy() end)
        if e.bitmap then pcall(function() e.bitmap.Visible = true end) end
    end

    function Session.RestoreWatermark()
        dropEntry(NameFx.tag)
        dropEntry(NameFx.panel)
        NameFx.tag, NameFx.panel = nil, nil
    end

    local function keepLabel(e, holder, size, isTag)
        if not holder then dropEntry(e); return nil end
        if not e or e.holder ~= holder or not e.label.Parent then
            dropEntry(e)
            e = makeLabel(holder, size, isTag)
        end
        if e.text ~= Config.watermarkText then
            e.text = Config.watermarkText
            e.label.Text = Config.watermarkText
            e.w = textWidth(Config.watermarkText, size)
        end
        if e.bitmap and e.bitmap.Visible then e.bitmap.Visible = false end
        if isTag then
            local h = math.max(holder.Size.Y.Offset, size + 6)
            e.label.Size = UDim2.fromOffset(e.w, h)
            holder.Size = UDim2.fromOffset(e.w, holder.Size.Y.Offset)
        else
            e.label.Size = UDim2.new(1, -6, 1, 0)
        end
        return e
    end

    trackConn(RunService.RenderStepped:Connect(function()
        if not alive() then return end
        if not Config.customWatermark then
            if NameFx.tag or NameFx.panel then Session.RestoreWatermark() end
            return
        end
        local tag, panelName = nameHolders()
        NameFx.tag = keepLabel(NameFx.tag, tag, 22, true)
        NameFx.panel = keepLabel(NameFx.panel, panelName, 21, false)
        local t = os.clock() - NameFx.t0
        local offset = Vector2.new(((t * 0.45) % 2) - 1, 0)
        local pulse = 1 + 0.045 * math.sin(t * 3.2)
        if NameFx.tag then NameFx.tag.gr.Offset = offset; NameFx.tag.sc.Scale = pulse end
        if NameFx.panel then NameFx.panel.gr.Offset = offset; NameFx.panel.sc.Scale = pulse end
    end))
end)() end

----------------------------------------------------------------------
-- FITUR TAMBAHAN: BLINK, LONGHAND, UJUMP, GOD, VISUAL, GROWSCAN, ROLE
----------------------------------------------------------------------
local blinkOn, longhandOn, ujumpOn, antiAfkOn, arjOn, godOn, questOn = false, false, false, false, false, false, false
local StartBlink, StopBlink, ApplyLonghand, StopLonghand, StartUjump, StopUjump
local StartAntiAfk, StopAntiAfk, StartAutoRejoin, StopAutoRejoin, StartGod, StopGod
local StartQuest, StopQuest, QuestReport, OpenNativeGrowScan, ScanWorld, SearchItems
local IsVisualWorn, ToggleVisual, ResetVisuals, GetWearables, GetOwnedRoles, ApplyRole

do (function()
    local blinkOriginal = {}
    local function collectSkinParts()
        local list = {}
        local rigs = FindRigs()
        if not rigs then return list end
        for _, key in ipairs({ 1, -1, 0 }) do
            local rig = rawget(rigs, key)
            if type(rig) == "table" then
                for _, field in ipairs({ "body", "head", "eyelids", "blink", "forearm", "fist" }) do
                    local part = rig[field]
                    if typeof(part) == "Instance" then table.insert(list, { part = part, face = false }) end
                end
                for _, field in ipairs({ "armBack", "armFront" }) do
                    local arm = rig[field]
                    local sprite = (typeof(arm) == "Instance" and arm:FindFirstChild("Sprite")) or (type(arm) == "table" and arm.Sprite)
                    if typeof(sprite) == "Instance" then table.insert(list, { part = sprite, face = false }) end
                end
                if typeof(rig.face) == "Instance" then table.insert(list, { part = rig.face, face = true }) end
            end
        end
        return list
    end

    function StopBlink()
        if not blinkOn then return false end
        blinkOn = false
        for part, color in pairs(blinkOriginal) do pcall(function() part.ImageColor3 = color end) end
        table.clear(blinkOriginal)
        return true
    end

    function StartBlink()
        if blinkOn then return true end
        if not FindRigs() then Notify("Rig karakter tidak ditemukan!"); return false end
        blinkOn = true
        table.clear(blinkOriginal)
        for _, e in ipairs(collectSkinParts()) do blinkOriginal[e.part] = e.part.ImageColor3 end
        task.spawn(function()
            while blinkOn and alive() do
                local color = Color3.fromHSV(math.random(), 0.55 + math.random() * 0.4, 1)
                local dark = Color3.new(color.R * 0.38, color.G * 0.35, color.B * 0.3)
                for _, e in ipairs(collectSkinParts()) do
                    if blinkOriginal[e.part] == nil then blinkOriginal[e.part] = e.part.ImageColor3 end
                    pcall(function() e.part.ImageColor3 = e.face and dark or color end)
                end
                local minT = math.min(Config.blinkMin, Config.blinkMax)
                local maxT = math.max(Config.blinkMin, Config.blinkMax)
                task.wait(minT + math.random() * (maxT - minT))
            end
        end)
        return true
    end

    local longhandOriginal = nil
    function ApplyLonghand()
        local inv = FindInventory()
        if not inv then Notify("Inventory belum ditemukan!"); return false end
        if not longhandOriginal then longhandOriginal = { build = inv.buildRange, punch = inv.punchRange } end
        local target = 2.5 + Config.longhandRange
        inv.buildRange = function() return math.max(longhandOriginal.build(), target) end
        inv.punchRange = function() return math.max(longhandOriginal.punch(), target) end
        longhandOn = true
        return true
    end

    function StopLonghand()
        if not longhandOn then return false end
        local inv = FindInventory()
        if inv and longhandOriginal then
            inv.buildRange = longhandOriginal.build
            inv.punchRange = longhandOriginal.punch
        end
        longhandOn = false
        return true
    end

    local origJammerOn = nil
    local function jammerWrapper(id, ...)
        if ujumpOn and id == 4992 and not AutoInput.active then return true end
        if origJammerOn then return origJammerOn(id, ...) end
        return false
    end

    function StartUjump()
        if ujumpOn then return true end
        ujumpOn = true
        local w = FindWorld()
        if w and type(rawget(w, "jammerOn")) == "function" and rawget(w, "jammerOn") ~= jammerWrapper then
            origJammerOn = rawget(w, "jammerOn")
            w.jammerOn = jammerWrapper
        end
        return true
    end

    function StopUjump()
        if not ujumpOn then return false end
        ujumpOn = false
        local w = FindWorld()
        if w and origJammerOn and rawget(w, "jammerOn") == jammerWrapper then
            w.jammerOn = origJammerOn
        end
        return true
    end

    local afkConn = nil
    function StartAntiAfk()
        if antiAfkOn then return true end
        antiAfkOn = true
        afkConn = trackConn(Player.Idled:Connect(function()
            if antiAfkOn and alive() then
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            end
        end))
        return true
    end

    function StopAntiAfk()
        if not antiAfkOn then return false end
        antiAfkOn = false
        if afkConn then afkConn:Disconnect(); afkConn = nil end
        return true
    end

    function StartAutoRejoin()
        arjOn = true
        Config.reconnectOn = true
        SaveConfig()
        return true
    end

    function StopAutoRejoin()
        arjOn = false
        Config.reconnectOn = false
        SaveConfig()
        return true
    end

    local godSaved, godConns = {}, {}
    function StartGod()
        if godOn then return true end
        godSaved = {}
        for _, item in pairs(ItemDB) do
            if type(item) == "table" then
                for _, k in ipairs({ "hurts", "deadly" }) do
                    if item[k] then
                        table.insert(godSaved, { item = item, key = k, value = rawget(item, k) })
                        pcall(function()
                            if setreadonly then setreadonly(item, false) end
                            rawset(item, k, false)
                        end)
                    end
                end
            end
        end
        local burned = WorldRemotes and WorldRemotes:FindFirstChild("Burned")
        if burned and getconnections then
            local okC, conns = pcall(getconnections, burned.OnClientEvent)
            if okC and type(conns) == "table" then
                for _, conn in ipairs(conns) do
                    if pcall(function() conn:Disable() end) then table.insert(godConns, conn) end
                end
            end
        end
        godOn = true
        return true
    end

    function StopGod()
        if not godOn then return false end
        for _, s in ipairs(godSaved) do pcall(function() rawset(s.item, s.key, s.value) end) end
        godSaved = {}
        for _, c in ipairs(godConns) do pcall(function() c:Enable() end) end
        godConns = {}
        godOn = false
        return true
    end

    local visualBackup = {}
    local wearableCache = nil
    local function getWornTable()
        local inv = FindInventory()
        if not inv then return nil end
        local worn = GetUpvalues(inv.isWorn)[1]
        return type(worn) == "table" and worn or nil
    end

    function IsVisualWorn(id)
        local worn = getWornTable()
        return worn and ItemDB[id] and worn[ItemDB[id].slot] == id or false
    end

    function ToggleVisual(id)
        local inv, worn = FindInventory(), getWornTable()
        if not inv or not worn or not ItemDB[id] then return false end
        local slot = ItemDB[id].slot
        if type(slot) ~= "string" then return false end
        if worn[slot] == id then
            worn[slot] = visualBackup[slot] or nil
        else
            if visualBackup[slot] == nil then visualBackup[slot] = worn[slot] or false end
            worn[slot] = id
        end
        pcall(inv.refresh)
        return true
    end

    function ResetVisuals()
        local inv, worn = FindInventory(), getWornTable()
        if not inv or not worn then return end
        for slot, orig in pairs(visualBackup) do worn[slot] = orig or nil end
        table.clear(visualBackup)
        pcall(inv.refresh)
        Notify("Item visual dikembalikan.")
    end

    function GetWearables()
        if wearableCache then return wearableCache end
        local list = {}
        for id, item in pairs(ItemDB) do
            if type(id) == "number" and type(item) == "table" and type(item.slot) == "string" and type(item.name) == "string" then
                local tags = {}
                local lower = item.name:lower()
                if item.kuyang then table.insert(tags, "Kuyang") end
                if item.bot then table.insert(tags, "LegendBot") end
                if id == 5480 or lower:find("rayman", 1, true) then table.insert(tags, "Rayman") end
                table.insert(list, { id = id, name = item.name, lower = lower, slot = item.slot, tags = tags })
            end
        end
        table.sort(list, function(a, b) return a.name < b.name end)
        wearableCache = list
        return list
    end

    local blockCache = nil
    local function getBlocks()
        if blockCache then return blockCache end
        local list = {}
        for id, item in pairs(ItemDB) do
            if type(id) == "number" and type(item) == "table" and type(item.name) == "string" and type(item.slot) ~= "string" then
                table.insert(list, { id = id, name = item.name, lower = item.name:lower(), kind = item.kind or "block" })
            end
        end
        table.sort(list, function(a, b) return a.name < b.name end)
        blockCache = list
        return list
    end

    function SearchItems(query, limit)
        local list = getBlocks()
        query = Trim(query):lower()
        if query == "" then return {} end
        local wantId = tonumber(query)
        local results = {}
        for _, e in ipairs(list) do
            local rank = nil
            if wantId and e.id == wantId then rank = 0
            elseif e.lower == query then rank = 1
            elseif e.lower:sub(1, #query) == query then rank = 2
            elseif e.lower:find(query, 1, true) then rank = 3 end
            if rank then table.insert(results, { entry = e, rank = rank }) end
        end
        table.sort(results, function(a, b)
            if a.rank ~= b.rank then return a.rank < b.rank end
            return a.entry.name < b.entry.name
        end)
        local out = {}
        for i = 1, math.min(limit or 25, #results) do out[i] = results[i].entry end
        return out
    end

    function OpenNativeGrowScan()
        local w = FindWorld()
        local ui = w and rawget(w, "growScan")
        if type(ui) ~= "table" or type(ui.open) ~= "function" then return false end
        local gsId = 0
        for id, it in pairs(ItemDB) do
            if type(id) == "number" and type(it) == "table" and it.growscan then gsId = id; break end
        end
        local ok = pcall(ui.open, { item = gsId, owner = true, blocksPublic = false, floatingPublic = false }, function() end)
        return ok
    end

    function ScanWorld()
        local w = FindWorld()
        if not w or type(rawget(w, "w")) ~= "number" then return nil end
        local result = {
            fg = {}, bg = {}, drops = {}, trees = {},
            w = w.w, h = w.h,
            totalFg = 0, totalBg = 0, totalDrops = 0, piles = 0,
            readyTrees = 0, growingTrees = 0,
        }
        local nowSrv = workspace:GetServerTimeNow()
        for y = 0, w.h - 1 do
            local rFg, rBg = w.fg[y], w.bg and w.bg[y]
            for x = 0, w.w - 1 do
                local f = rFg and rFg[x] or 0
                if f ~= 0 then
                    result.fg[f] = (result.fg[f] or 0) + 1
                    result.totalFg += 1
                    if IsSeedId(f) then
                        local rAt = TreeReadyAt(w, x, y, f)
                        local tEntry = result.trees[f]
                        if not tEntry then
                            tEntry = { ready = 0, growing = 0, nextIn = nil }
                            result.trees[f] = tEntry
                        end
                        if rAt and nowSrv >= rAt then
                            tEntry.ready += 1
                            result.readyTrees += 1
                        else
                            tEntry.growing += 1
                            result.growingTrees += 1
                            if rAt then
                                local rem = rAt - nowSrv
                                if not tEntry.nextIn or rem < tEntry.nextIn then
                                    tEntry.nextIn = rem
                                end
                            end
                        end
                    end
                end
                local b = rBg and rBg[x] or 0
                if b ~= 0 then result.bg[b] = (result.bg[b] or 0) + 1; result.totalBg += 1 end
            end
        end
        local dList = Drops.list
        if not dList and type(w.dropList) == "function" then
            local okD, l = pcall(w.dropList)
            if okD then dList = l end
        end
        if type(dList) == "table" then
            for _, d in pairs(dList) do
                if type(d) == "table" and type(d.id) == "number" and (d.n or 0) > 0 then
                    result.drops[d.id] = (result.drops[d.id] or 0) + (d.n or 1)
                    result.totalDrops += (d.n or 1)
                    result.piles += 1
                end
            end
        end
        return result
    end

    function GetOwnedRoles()
        local out, seen = { "none" }, { none = true }
        if RolesOk and type(RolesModule) == "table" and type(RolesModule.titlesOf) == "function" then
            local ok, list = pcall(RolesModule.titlesOf, Player.UserId)
            if ok and type(list) == "table" then
                for _, r in ipairs(list) do
                    if type(r) == "string" and not seen[r] then
                        seen[r] = true
                        local label = r
                        if type(RolesModule.titleName) == "function" then
                            local okN, tName = pcall(RolesModule.titleName, r)
                            if okN and type(tName) == "string" and tName ~= "" and tName ~= r then
                                label = tName .. " [" .. r .. "]"
                            end
                        end
                        table.insert(out, label)
                    end
                end
            end
        end
        return out
    end

    function ApplyRole(roleStr)
        local code = string.match(roleStr or "", "%[(.-)%]$") or roleStr or "none"
        if code == "" then code = "none" end
        if NetOk and type(Net) == "table" and type(Net.call) == "function" then
            task.spawn(function()
                local ok, err = pcall(Net.call, "PickTitle", code)
                Notify(ok and ("Role dipasang: " .. code) or ("Gagal pasang role: " .. tostring(err)))
            end)
        elseif PickTitleRemote then
            pcall(function() PickTitleRemote:FireServer(code) end)
            Notify("Role dikirim: " .. code)
        else
            Notify("Fungsi PickTitle tidak ditemukan.")
        end
    end

    function QuestReport()
        Bonus.CheckQuests()
        Notify(Bonus.questText, "Info Quest")
    end

    function StartQuest()
        if questOn then return true end
        questOn = true
        Config.bonusAutoQuest = true
        Bonus.nextQuest = 0
        return true
    end

    function StopQuest()
        if not questOn then return false end
        questOn = false
        Config.bonusAutoQuest = false
        return true
    end
end)() end

----------------------------------------------------------------------
-- DAFTAR FEATURES & SESI AUTO-RELOAD
----------------------------------------------------------------------
local Features = {
    blink = { label = "Blink", get = function() return blinkOn end, set = function(on) return on and StartBlink() or StopBlink() end },
    longhand = { label = "Longhand", get = function() return longhandOn end, set = function(on) return on and ApplyLonghand() or StopLonghand() end },
    noclip = { label = "Noclip", get = function() return noclipOn end, set = function(on) return on and StartNoclip() or StopNoclip() end },
    ujump = { label = "Unlimited Jump", get = function() return ujumpOn end, set = function(on) return on and StartUjump() or StopUjump() end },
    antiafk = { label = "Anti-AFK", get = function() return antiAfkOn end, set = function(on) return on and StartAntiAfk() or StopAntiAfk() end },
    autorejoin = { label = "Auto Reconnect", get = function() return Config.reconnectOn end, set = function(on) return on and StartAutoRejoin() or StopAutoRejoin() end },
    god = { label = "God Mode", get = function() return godOn end, set = function(on) return on and StartGod() or StopGod() end },
    clicktp = { label = "Click TP", get = function() return Nav.clickOn end, set = function(on) return on and Nav.StartClick() or Nav.StopClick() end },
    lite = { label = "Mode Lite", get = function() return Config.liteMode end, set = function(on) LiteMode.Set(on); return true end },
    guard = { label = "Penjaga Anti-Mod", get = function() return Guard.on end, set = function(on) Guard.Set(on); return true end },
    autochat = { label = "Auto Chat", noSession = true, get = function() return Spam.on end, set = function(on) Spam.on = on; if on then Spam.nextAt = 0 end; return true end },
    autoclear = { label = "Auto Clear World", noSession = true, get = function() return Clear.on end, set = function(on) return on and Clear.Start() or Clear.Stop() end },
    autoharvest = { label = "Farmer (Harvest/Plant)", noSession = true, get = function() return Farmer.on end, set = function(on) return on and Farmer.Start() or Farmer.Stop() end },
    autodf = { label = "Auto Dirt Farm", noSession = true, get = function() return DF.on end, set = function(on) return on and DF.Start() or DF.Stop() end },
    autosplice = { label = "Auto Splice", noSession = true, get = function() return SpliceBot.on end, set = function(on) return on and SpliceBot.Start() or SpliceBot.Stop() end },
    pabrik = { label = "Pabrik Seed", noSession = true, get = function() return Pabrik.on end, set = function(on) return on and Pabrik.Start() or Pabrik.Stop() end },
    autofarm = { label = "Auto Farm", noSession = true, get = function() return Farm.on and not Farm.Override end, set = function(on) return on and StartFarm() or StopFarm() end },
    autoquest = { label = "Auto Quest", get = function() return questOn end, set = function(on) return on and StartQuest() or StopQuest() end },
}

local function SetFeature(key, on)
    local feature = Features[key]
    if not feature then return end
    feature.set(on)
    if feature.get() == on then
        Notify(feature.label .. (on and " aktif." or " dimatikan."))
        if not feature.noSession then
            Config.session[key] = on or nil
        end
        SaveConfig()
    end
    if RefreshHub then RefreshHub() end
end

local function ReloadSource()
    local url = Config.scriptUrl
    if type(url) ~= "string" or url == "" then url = G.ANCHHubURL end
    if type(url) == "string" and url ~= "" then
        return string.format("loadstring(game:HttpGet(%q))()", url)
    end
    local okFile, exists = pcall(function() return isfile and readfile and isfile(SCRIPT_FILE) end)
    if okFile and exists then
        return string.format("loadstring(readfile(%q))()", SCRIPT_FILE)
    end
    return nil
end

local function GetQueueFn()
    return queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
end

QueueReload = function()
    if not Config.autoReload then return false end
    local qFn, src = GetQueueFn(), ReloadSource()
    if not qFn or not src then return false end
    return pcall(qFn, src)
end

local function InstallAutoexec()
    if not writefile then Notify("Executor tidak punya writefile."); return end
    local src = ReloadSource()
    if not src then Notify("Simpan skrip sebagai " .. SCRIPT_FILE .. " di workspace atau isi URL dulu."); return end
    local loader = "-- ANCH HUB | GrowBlox auto-loader\n" .. src .. "\n"
    pcall(writefile, "ANCHHub_Loader.lua", loader)
    for _, path in ipairs({ "../autoexec/ANCHHub_Loader.lua", "../Autoexec/ANCHHub_Loader.lua" }) do
        local okW = pcall(writefile, path, loader)
        local okC, ex = pcall(function() return isfile and isfile(path) end)
        if okW and okC and ex then
            Notify("Auto-execute berhasil dipasang!")
            return
        end
    end
    Notify("Salin ANCHHub_Loader.lua dari workspace ke folder autoexec executor.")
end

----------------------------------------------------------------------
-- GUI TAMBAHAN: FLOATING GRID 5X5 (DUAL MODE: FARM / PABRIK) & FLYPAD
----------------------------------------------------------------------
do (function()
    local guiParent = (gethui and gethui()) or game:GetService("CoreGui")
    local function makeScreenGui(name)
        local sg = Instance.new("ScreenGui")
        sg.Name = name
        sg.ResetOnSpawn = false
        sg.IgnoreGuiInset = true
        sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        sg.DisplayOrder = 999
        sg.Enabled = false
        sg.Parent = guiParent
        return sg
    end

    GridGui = makeScreenGui("ANCHGridGui")
    local CELL, GAP, RAD = 38, 4, 2
    local side = RAD * 2 + 1
    local gridSize = side * CELL + (side - 1) * GAP

    local Panel = Instance.new("Frame", GridGui)
    Panel.Size = UDim2.fromOffset(gridSize + 20, gridSize + 96)
    Panel.Position = UDim2.fromOffset(24, 90)
    Panel.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    Panel.BorderSizePixel = 0
    Instance.new("UICorner", Panel).CornerRadius = UDim.new(0, 10)
    local pStroke = Instance.new("UIStroke", Panel)
    pStroke.Color = Color3.fromRGB(48, 255, 106)

    local Title = Instance.new("TextLabel", Panel)
    Title.Size = UDim2.new(1, -106, 0, 28)
    Title.Position = UDim2.fromOffset(10, 4)
    Title.BackgroundTransparency = 1
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 12
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.TextColor3 = Color3.fromRGB(235, 235, 245)
    Title.Text = "ANCH Grid (Farm)"
    Title.Active = true

    local ModeBtn = Instance.new("TextButton", Panel)
    ModeBtn.Size = UDim2.fromOffset(62, 22)
    ModeBtn.Position = UDim2.new(1, -98, 0, 7)
    ModeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
    ModeBtn.Text = "Farm"
    ModeBtn.Font = Enum.Font.GothamBold
    ModeBtn.TextSize = 11
    ModeBtn.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", ModeBtn).CornerRadius = UDim.new(0, 6)

    local CloseBtn = Instance.new("TextButton", Panel)
    CloseBtn.Size = UDim2.fromOffset(24, 24)
    CloseBtn.Position = UDim2.new(1, -30, 0, 6)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
    CloseBtn.Text = "X"
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 12
    CloseBtn.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)
    CloseBtn.MouseButton1Click:Connect(function() GridGui.Enabled = false end)

    local GridHolder = Instance.new("Frame", Panel)
    GridHolder.Size = UDim2.fromOffset(gridSize, gridSize)
    GridHolder.Position = UDim2.fromOffset(10, 36)
    GridHolder.BackgroundTransparency = 1

    local COLOR_OFF = Color3.fromRGB(48, 48, 60)
    local COLOR_ON = Color3.fromRGB(46, 160, 90)
    local COLOR_ME = Color3.fromRGB(60, 110, 220)
    local CellButtons = {}

    local function currentGridTable()
        return (GridMode == "pabrik") and Config.pabrikTiles or Config.farmGrid
    end

    local GridStart = Instance.new("TextButton", Panel)
    GridStart.Size = UDim2.new(1, -20, 0, 30)
    GridStart.Position = UDim2.new(0, 10, 1, -54)
    GridStart.BackgroundColor3 = COLOR_ON
    GridStart.Font = Enum.Font.GothamBold
    GridStart.TextSize = 13
    GridStart.TextColor3 = Color3.new(1, 1, 1)
    GridStart.Text = "START FARM"
    Instance.new("UICorner", GridStart).CornerRadius = UDim.new(0, 8)
    GridStart.MouseButton1Click:Connect(function()
        if GridMode == "pabrik" then
            SetFeature("pabrik", not Pabrik.on)
        else
            SetFeature("autofarm", not (Farm.on and not Farm.Override))
        end
    end)

    UpdateGridVisuals = function()
        local tbl = currentGridTable()
        local isPabrik = GridMode == "pabrik"
        ModeBtn.Text = isPabrik and "Pabrik" or "Farm"
        ModeBtn.BackgroundColor3 = isPabrik and Color3.fromRGB(200, 120, 40) or Color3.fromRGB(60, 60, 75)
        Title.Text = isPabrik and "Tile Break Pabrik" or "ANCH Grid (Farm)"
        for key, btn in pairs(CellButtons) do
            btn.BackgroundColor3 = tbl[key] and COLOR_ON or COLOR_OFF
        end
        if isPabrik then
            GridStart.Text = Pabrik.on and "STOP PABRIK" or "START PABRIK"
            GridStart.BackgroundColor3 = Pabrik.on and Color3.fromRGB(200, 60, 60) or COLOR_ON
        else
            local running = Farm.on and not Farm.Override
            GridStart.Text = running and "STOP FARM" or "START FARM"
            GridStart.BackgroundColor3 = running and Color3.fromRGB(200, 60, 60) or COLOR_ON
        end
    end

    SetGridMode = function(mode)
        GridMode = mode
        UpdateGridVisuals()
    end

    ModeBtn.MouseButton1Click:Connect(function()
        SetGridMode(GridMode == "pabrik" and "farm" or "pabrik")
    end)

    for row = 0, side - 1 do
        for col = 0, side - 1 do
            local dx, dy = col - RAD, row - RAD
            local key = dx .. "," .. dy
            local btn = Instance.new("TextButton", GridHolder)
            btn.Size = UDim2.fromOffset(CELL, CELL)
            btn.Position = UDim2.fromOffset(col * (CELL + GAP), row * (CELL + GAP))
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = 11
            btn.TextColor3 = Color3.new(1, 1, 1)
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
            if dx == 0 and dy == 0 then
                btn.Text = "ME"
                btn.BackgroundColor3 = COLOR_ME
                btn.AutoButtonColor = false
            else
                btn.Text = ""
                btn.BackgroundColor3 = currentGridTable()[key] and COLOR_ON or COLOR_OFF
                CellButtons[key] = btn
                btn.MouseButton1Click:Connect(function()
                    local tbl = currentGridTable()
                    tbl[key] = (not tbl[key]) or nil
                    SaveConfig()
                    UpdateGridVisuals()
                end)
            end
        end
    end

    local ClearBtn = Instance.new("TextButton", Panel)
    ClearBtn.Size = UDim2.new(1, -20, 0, 18)
    ClearBtn.Position = UDim2.new(0, 10, 1, -22)
    ClearBtn.BackgroundTransparency = 1
    ClearBtn.Font = Enum.Font.Gotham
    ClearBtn.TextSize = 12
    ClearBtn.TextColor3 = Color3.fromRGB(180, 180, 195)
    ClearBtn.Text = "Bersihkan pilihan"
    ClearBtn.MouseButton1Click:Connect(function()
        if GridMode == "pabrik" then
            Config.pabrikTiles = {}
        else
            Config.farmGrid = {}
        end
        SaveConfig()
        UpdateGridVisuals()
    end)

    local dragging, dragStart, startPos
    Title.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, inp.Position, Panel.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    trackConn(UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - dragStart
            Panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))

    FlyPadGui = makeScreenGui("ANCHFlyPad")
    local function makeFlyBtn(text, yOffset, onHold)
        local b = Instance.new("TextButton", FlyPadGui)
        b.Size = UDim2.fromOffset(60, 60)
        b.AnchorPoint = Vector2.new(1, 0.5)
        b.Position = UDim2.new(1, -24, 0.5, yOffset)
        b.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        b.BackgroundTransparency = 0.2
        b.Text = text
        b.Font = Enum.Font.GothamBold
        b.TextSize = 26
        b.TextColor3 = Color3.new(1, 1, 1)
        Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
        local st = Instance.new("UIStroke", b)
        st.Color = Color3.fromRGB(48, 255, 106)
        st.Thickness = 2
        local heldInput = nil
        b.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                heldInput = input
                onHold(true)
            end
        end)
        trackConn(UserInputService.InputEnded:Connect(function(input)
            if heldInput and (input == heldInput or input.UserInputType == Enum.UserInputType.MouseButton1) then
                heldInput = nil
                onHold(false)
            end
        end))
    end
    makeFlyBtn("▲", -38, function(v) FlyPadState.up = v end)
    makeFlyBtn("▼", 38, function(v) FlyPadState.down = v end)
end)() end

----------------------------------------------------------------------
-- GUI UTAMA (WINDUI - STRUKTUR RILIS PUBLIK + PROTEKSI SAFEUI)
----------------------------------------------------------------------
local WindUI
do
    local ok, result = pcall(function() return require("./src/Init") end)
    if ok then
        WindUI = result
    else
        WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
    end
end

ToastHook = function(message, title, duration)
    WindUI:Notify({
        Title = title or "ANCH HUB | GrowBlox",
        Content = tostring(message),
        Icon = "solar:bell-bold",
        Duration = duration or 4,
    })
end

local Purple = Color3.fromHex("#7775F2")
local Yellow = Color3.fromHex("#ECA201")
local Green  = Color3.fromHex("#10C550")
local Blue   = Color3.fromHex("#257AF7")
local Red    = Color3.fromHex("#EF4F1D")

local Window = WindUI:CreateWindow({
    Title = "ANCH Hub  |  GrowBlox Ultimate",
    Folder = "ANCHHub_GrowBlox",
    Icon = "solar:folder-2-bold-duotone",
    NewElements = true,
    HideSearchBar = false,
    --Theme = "Indigo",
    OpenButton = {
        Title = "ANCH Hub",
        CornerRadius = UDim.new(1, 0),
        StrokeThickness = 3,
        Enabled = Config.launcher,
        Draggable = true,
        OnlyMobile = false,
        Scale = 0.5,
        Color = ColorSequence.new(
            Color3.fromHex("#30FF6A"),
            Color3.fromHex("#e7ff2f")
        ),
    },
    Topbar = {
        Height = 44,
        ButtonsType = "Mac",
    },
})

Window::DisableTopbarButtons({
    "Fullscreen",
})

pcall(function()
    Window:Tag({
        Title = "v11 Release",
        Icon = "github",
        Color = Color3.fromHex("#1c1c1c"),
        Border = true,
    })
end)

local hub = {
    tabs = {},
    refreshers = {},
    syncing = false,
    active = "features",
}

RefreshHub = function()
    hub.syncing = true
    for _, fn in ipairs(hub.refreshers) do pcall(fn) end
    hub.syncing = false
end

local function SafeUI(label, fn)
    local ok, err = pcall(fn)
    if not ok then
        warn("[ANCHHub UI] Error pada " .. tostring(label) .. ": " .. tostring(err))
    end
end

local function SetElementText(el, title, desc)
    if not el then return end
    pcall(function()
        if title and el.SetTitle then el:SetTitle(title) end
        if desc and el.SetDesc then el:SetDesc(desc)
        elseif desc and el.SetContent then el:SetContent(desc) end
    end)
end

local function AddFeatureToggle(tab, title, desc, key)
    local feature = Features[key]
    if not feature then return nil end
    local toggle
    SafeUI("Toggle:" .. tostring(key), function()
        toggle = tab:Toggle({
            Title = title,
            Desc = desc,
            Value = feature.get(),
            Callback = function(state)
                if hub.syncing then return end
                if feature.get() ~= state then SetFeature(key, state) end
            end,
        })
        table.insert(hub.refreshers, function()
            if toggle and toggle.Set then toggle:Set(feature.get()) end
        end)
    end)
    return toggle
end

-- 5 Kategori Proporsional Standar Publik
local MainSection     = Window:Section({ Title = "Utama", Opened = true })
local AutoSection     = Window:Section({ Title = "Farming & Bot", Opened = true })
local BagWorldSection = Window:Section({ Title = "Tas & World", Opened = true })
local SecuritySection = Window:Section({ Title = "Keamanan & Sosial", Opened = true })
local SystemSection   = Window:Section({ Title = "Visual & Sistem", Opened = true })

-- 1A. Tab: Dashboard & Statistik (Utama) -----------------------------
SafeUI("Tab:Dashboard", function()
    local Tab = MainSection:Tab({
        Title = "Dashboard & Statistik",
        Icon = "solar:home-2-bold",
        IconColor = Green,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.features = Tab

    local statusPara = Tab:Paragraph({
        Title = "Status Karakter & Koneksi Game",
        Desc = "Mendeteksi posisi...",
    })

    local statsPara = Tab:Paragraph({
        Title = "Statistik Sesi Real-Time",
        Desc = "Memuat statistik...",
    })

    task.spawn(function()
        while alive() and task.wait(0.5) do
            pcall(function()
                local tx, ty = GetTile()
                local wName = CurrentWorldName()
                local refLine = string.format(
                    "World: %s | Inv: %s | State: %s | Punch: %s | Drop: %s | Trees: %s",
                    Refs.World and "OK" or "-",
                    Refs.Inv and "OK" or "-",
                    Refs.State and "OK" or "-",
                    Refs.Punch and "OK" or "-",
                    Drops.list and "OK" or "-",
                    Refs.Trees and "OK" or "-"
                )
                if tx then
                    SetElementText(
                        statusPara,
                        string.format("World: %s  |  Posisi Tile: (%d, %d)", wName ~= "" and wName or "-", tx, ty),
                        refLine
                    )
                else
                    SetElementText(statusPara, "Status Karakter: Di luar world", refLine)
                end
                SetElementText(statsPara, "Statistik Sesi Real-Time", Stats.Text())
            end)
        end
    end)

    Tab:Button({
        Title = "Hubungkan Ulang ke Game (Reconnect Refs)",
        Color = Color3.fromHex("#305dff"),
        Justify = "Center",
        Callback = function()
            Refs.Scan()
            Notify("Referensi game berhasil diperbarui!")
        end,
    })

    local stGrp = Tab:Group({})
    stGrp:Button({
        Title = "Reset Statistik",
        Justify = "Center",
        Callback = function() Stats.Reset(); Notify("Statistik sesi direset ke nol.") end,
    })
    stGrp:Button({
        Title = "Kirim Statistik ke Discord",
        Justify = "Center",
        Callback = function()
            if not (Config.webhookOn and Webhook.Valid(Config.webhookUrl)) then
                Notify("Aktifkan & isi URL Webhook di tab Discord & Pengaturan dulu!")
            else
                Webhook.Send("report", "Laporan Statistik Sesi\n```\n" .. Stats.Text() .. "\n```")
                Notify("Laporan statistik masuk antrian kirim Discord!")
            end
        end,
    })

    Tab:Space()
    Tab:Section({ Title = "Sakelar Cepat Bot Utama" })

    AddFeatureToggle(Tab, "Auto Farm (Grid 5x5 + Rayman)", "Place & break otomatis di sekitar karakter.", "autofarm")
    AddFeatureToggle(Tab, "Auto Clear World (ModFly + Stand Above)", "ModFly aktif penuh, berdiri di atas blok target sampai hancur lalu pindah.", "autoclear")
    AddFeatureToggle(Tab, "Farmer (Auto Harvest + Auto Plant)", "Panen pohon siap & tanam seed otomatis.", "autoharvest")
    AddFeatureToggle(Tab, "Auto Dirt Farm (Full World + Smart Supply)", "Bangun Dirt Farm bagian bawah & atas otomatis.", "autodf")
    AddFeatureToggle(Tab, "Auto Splice (Seed A + Seed B)", "Tanam Seed A lalu gabungkan dengan Seed B.", "autosplice")
    AddFeatureToggle(Tab, "Pabrik Seed (Siklus Panen-Tanam-Break-Drop)", "Produksi seed otomatis & drop lintas world.", "pabrik")
    AddFeatureToggle(Tab, "Penjaga (Anti-Mod / Staff Detector)", "Jeda / keluar world otomatis saat Mod atau pemain masuk.", "guard")
end)

-- 1B. Tab: Karakter & Movement (Utama) -------------------------------
SafeUI("Tab:Character", function()
    local Tab = MainSection:Tab({
        Title = "Karakter & Navigasi",
        Icon = "solar:square-transfer-horizontal-bold",
        IconColor = Blue,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.nav = Tab

    local navPara = Tab:Paragraph({ Title = "Status Navigasi Universal", Desc = "Terakhir: -" })

    task.spawn(function()
        while alive() and task.wait(0.5) do
            pcall(function()
                SetElementText(
                    navPara,
                    "Mode Gerak: " .. Config.moveMode:upper(),
                    "Status Click TP: " .. tostring(Nav.last) .. " | Pijakan Dipasang: " .. Nav.PlacedScaffolds
                )
            end)
        end
    end)

    AddFeatureToggle(Tab, "Click TP (Legit A* Pathfinding)", "Klik di layar untuk berjalan & memanjat otomatis ke tujuan.", "clicktp")
    AddFeatureToggle(Tab, "Noclip + FlyPad (▲/▼)", "Terbang menembus blok dan munculkan tombol naik/turun di layar.", "noclip")
    AddFeatureToggle(Tab, "Unlimited Jump (Jammer)", "Lompat di udara tanpa batas.", "ujump")
    AddFeatureToggle(Tab, "God Mode (Kebal Hazard)", "Kebal lava, spike, api, dan rintangan tajam.", "god")
    AddFeatureToggle(Tab, "Longhand (Jangkauan Jauh)", "Perluas jangkauan pukulan & pasang blok.", "longhand")
    AddFeatureToggle(Tab, "Mode Lite (FPS Boost)", "Matikan partikel & efek suara pukulan agar hemat baterai & FPS tinggi.", "lite")
    AddFeatureToggle(Tab, "Blink Skin", "Warna karakter berganti otomatis.", "blink")
    AddFeatureToggle(Tab, "Anti-AFK", "Mencegah disconnect karena diam terlalu lama.", "antiafk")

    Tab:Space()
    Tab:Section({ Title = "Kecepatan & Radius Collect" })

    Tab:Slider({
        Title = "Walkspeed Karakter (%)",
        Desc = "100% = kecepatan normal.",
        IsTooltip = true,
        Step = 10,
        Value = { Min = 50, Max = 400, Default = math.clamp(Config.walkSpeed, 50, 400) },
        Callback = function(v)
            Config.walkSpeed = tonumber(v) or 100
            if Config.walkSpeed == 100 and Refs.World then Refs.World.speedScale = 1 end
            SaveConfig()
        end,
    })

    Tab:Toggle({
        Title = "Collect Drop di Sekitar Karakter (Kapan Saja)",
        Value = Config.collectAround,
        Callback = function(on) Config.collectAround = on; SaveConfig() end,
    })

    Tab:Slider({
        Title = "Radius Auto Collect (Tile)",
        IsTooltip = true,
        Step = 1,
        Value = { Min = 1, Max = 8, Default = math.clamp(Config.collectRadius, 1, 8) },
        Callback = function(v) Config.collectRadius = math.floor(tonumber(v) or 3); SaveConfig() end,
    })

    Tab:Dropdown({
        Title = "Mode Pergerakan Universal",
        Values = { "legit", "walk", "fly", "mix" },
        Value = Config.moveMode,
        Callback = function(v)
            if type(v) == "string" then
                Config.moveMode = v
                SaveConfig()
                Notify("Mode gerak diubah ke: " .. v)
            end
        end,
    })

    Tab:Toggle({
        Title = "Wajib Tahan Shift untuk Click TP (PC)",
        Value = Config.clickTpShift,
        Callback = function(on) Config.clickTpShift = on; SaveConfig() end,
    })
end)

-- 2A. Tab: Auto Farm -------------------------------------------------
SafeUI("Tab:AutoFarm", function()
    local Tab = AutoSection:Tab({
        Title = "Auto Farm",
        Icon = "solar:check-square-bold",
        IconColor = Yellow,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.farm = Tab

    local farmStatusPara = Tab:Paragraph({ Title = "Status Auto Farm", Desc = "Memuat..." })

    task.spawn(function()
        while alive() and task.wait(0.4) do
            pcall(function()
                local id = Config.farmPlaceId
                SetElementText(
                    farmStatusPara,
                    "Status: " .. Farm.stats.status .. " (" .. Config.farmMode .. ")",
                    string.format(
                        "Block: %s [ID %d] (Stok: %d)\nPlace: %d | Break: %d | Collect: %d | Siklus: %d",
                        ItemName(id), id, CountItem(id),
                        Farm.stats.placed, Farm.stats.broken, Farm.stats.picked, Farm.stats.cycles
                    )
                )
            end)
        end
    end)

    AddFeatureToggle(Tab, "Jalankan Auto Farm", "Place & break otomatis sesuai Grid 5x5.", "autofarm")

    Tab:Button({
        Title = "Buka Floating Grid 5x5 (Mode Farm)",
        Color = Color3.fromHex("#305dff"),
        Justify = "Center",
        Callback = function()
            if SetGridMode then SetGridMode("farm") end
            if GridGui then GridGui.Enabled = not GridGui.Enabled end
        end,
    })

    Tab:Space()
    Tab:Section({ Title = "Mode & Kecepatan Farm" })

    Tab:Dropdown({
        Title = "Mode Auto Farm",
        Values = { "Place + Break", "Break saja", "Place saja" },
        Value = Config.farmMode,
        Callback = function(v) Config.farmMode = v or "Place + Break"; SaveConfig() end,
    })

    Tab:Slider({
        Title = "Multi-Target Break (1 - 5 Tile)",
        Desc = "Memukul beberapa tile bergantian. Otomatis pakai efek Rayman jika memakai Rayman's Fist!",
        IsTooltip = true,
        Step = 1,
        Value = { Min = 1, Max = 5, Default = math.clamp(Config.farmMultiTarget, 1, 5) },
        Callback = function(v) Config.farmMultiTarget = math.clamp(math.floor(tonumber(v) or 1), 1, 5); SaveConfig() end,
    })

    Tab:Input({
        Title = "ID Block Farm",
        Value = tostring(Config.farmPlaceId),
        Placeholder = "Contoh: 2 (Dirt)",
        Callback = function(text)
            local v = tonumber(text)
            if v and v > 0 then
                Config.farmPlaceId = math.floor(v)
                SaveConfig()
                Notify("Block Farm: " .. ItemName(Config.farmPlaceId) .. " [" .. Config.farmPlaceId .. "]")
            end
        end,
    })

    local searchMap = {}
    local searchDd
    Tab:Input({
        Title = "Cari Block di Database",
        Placeholder = "Ketik nama block...",
        Callback = function(q)
            searchMap = {}
            local vals = {}
            if Trim(q) ~= "" then
                for _, e in ipairs(SearchItems(q, 25)) do
                    local lbl = string.format("%s [%d]", e.name, e.id)
                    searchMap[lbl] = e.id
                    table.insert(vals, lbl)
                end
            end
            if #vals == 0 then vals = { "Tidak ada hasil" } end
            if searchDd and searchDd.Refresh then pcall(function() searchDd:Refresh(vals) end) end
        end,
    })

    searchDd = Tab:Dropdown({
        Title = "Pilih Hasil Pencarian Block",
        Values = { "Ketik nama di atas..." },
        Callback = function(sel)
            local id = searchMap[sel]
            if id then
                Config.farmPlaceId = id
                SaveConfig()
                Notify("Block diset ke: " .. ItemName(id) .. " [" .. id .. "]")
            end
        end,
    })

    Tab:Slider({
        Title = "Speed Place (ms)",
        IsTooltip = true,
        Step = 10,
        Value = { Min = 50, Max = 1000, Default = math.clamp(Config.farmPlaceMs, 50, 1000) },
        Callback = function(v) Config.farmPlaceMs = tonumber(v) or 250; SaveConfig() end,
    })

    Tab:Input({
        Title = "Speed Break (detik)",
        Value = tostring(Config.farmDelay),
        Placeholder = "0.22",
        Callback = function(text)
            local v = tonumber(text)
            if v and v >= 0.03 and v <= 5 then Config.farmDelay = v; SaveConfig() end
        end,
    })

    Tab:Toggle({
        Title = "Auto Collect Drop",
        Value = Config.farmTake,
        Callback = function(on) Config.farmTake = on; SaveConfig() end,
    })
end)

-- 2B. Tab: Auto Clear World (ModFly + Stand Above) -------------------
SafeUI("Tab:AutoClear", function()
    local Tab = AutoSection:Tab({
        Title = "Auto Clear",
        Icon = "solar:cursor-square-bold",
        IconColor = Red,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.clear = Tab

    local clearPara = Tab:Paragraph({ Title = "Status Auto Clear (ModFly)", Desc = "Memuat..." })

    task.spawn(function()
        while alive() and task.wait(0.4) do
            pcall(function()
                local st = Clear.stats
                SetElementText(
                    clearPara,
                    string.format("Status: %s (Pass %d | Baris Y=%s)", Clear.status, st.pass, st.row >= 0 and tostring(st.row) or "-"),
                    string.format("Target: %d | Sisa: %d | Di-skip: %d\nHancur: %d | Drop Diambil: %d", st.scanned, st.left, st.skipped, st.broken, st.picked)
                )
            end)
        end
    end)

    AddFeatureToggle(Tab, "Auto Clear World (ModFly + Berdiri di Atas Block)", "ModFly otomatis selalu menyala, karakter berdiri tepat di atas block yang akan di-break hingga hancur lalu pindah.", "autoclear")

    Tab:Dropdown({
        Title = "Arah Sapuan (Sweep)",
        Values = { "Zig-zag", "Kiri → Kanan" },
        Value = Config.clearSweep,
        Callback = function(v) Config.clearSweep = v or "Zig-zag"; SaveConfig() end,
    })

    Tab:Toggle({
        Title = "Ikut Hancurkan Background",
        Value = Config.clearIncludeBg,
        Callback = function(on) Config.clearIncludeBg = on; SaveConfig() end,
    })

    Tab:Input({
        Title = "Delay Pukulan Break (detik)",
        Value = tostring(Config.clearBreakDelay),
        Callback = function(text)
            local v = tonumber(text)
            if v and v >= 0.03 and v <= 5 then Config.clearBreakDelay = v; SaveConfig() end
        end,
    })

    Tab:Input({
        Title = "Delay Pindah Antar Blok (detik)",
        Value = tostring(Config.clearTpDelay),
        Callback = function(text)
            local v = tonumber(text)
            if v and v >= 0.05 and v <= 5 then Config.clearTpDelay = v; SaveConfig() end
        end,
    })

    Tab:Toggle({
        Title = "Auto Collect Drop",
        Value = Config.clearTake,
        Callback = function(on) Config.clearTake = on; SaveConfig() end,
    })
end)

-- 2C. Tab: Farmer (Auto Harvest + Auto Plant) ------------------------
SafeUI("Tab:Farmer", function()
    local Tab = AutoSection:Tab({
        Title = "Farmer (Harvest/Plant)",
        Icon = "solar:check-square-bold",
        IconColor = Green,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.harvest = Tab

    local farmerPara = Tab:Paragraph({ Title = "Status Farmer", Desc = "Memuat..." })

    task.spawn(function()
        while alive() and task.wait(0.4) do
            pcall(function()
                local st = Farmer.stats
                SetElementText(
                    farmerPara,
                    "Status: " .. Farmer.status,
                    string.format(
                        "Total Pohon: %d | Siap Panen: %d | Belum Siap: %d\nDipanen: %d | Ditanam: %d | Drop Diambil: %d\nSeed Tanam: %s [ID %d] (Stok: %d)",
                        st.totalTrees, st.ready, st.skipped, st.harvested, st.planted, st.picked,
                        ItemName(Config.harvestSeedId), Config.harvestSeedId, CountItem(Config.harvestSeedId)
                    )
                )
            end)
        end
    end)

    AddFeatureToggle(Tab, "Jalankan Farmer", "Otomatis panen pohon siap & tanam seed dengan Legit Walking + Bersih Pijakan.", "autoharvest")

    Tab:Toggle({
        Title = "Auto Harvest (Panen Pohon Siap)",
        Value = Config.harvestDoHarvest,
        Callback = function(on) Config.harvestDoHarvest = on; SaveConfig() end,
    })

    Tab:Toggle({
        Title = "Auto Plant (Tanam Seed Otomatis)",
        Value = Config.harvestDoPlant,
        Callback = function(on) Config.harvestDoPlant = on; SaveConfig() end,
    })

    Tab:Input({
        Title = "ID Seed untuk Auto Plant",
        Desc = "Contoh: 3 = Dirt Seed, 5 = Lava Seed",
        Value = tostring(Config.harvestSeedId),
        Placeholder = "3",
        Callback = function(text)
            local v = tonumber(text)
            if v and v > 0 then
                Config.harvestSeedId = math.floor(v)
                SaveConfig()
                Notify("Seed diset ke: " .. ItemName(Config.harvestSeedId))
            end
        end,
    })

    Tab:Toggle({
        Title = "Pakai Block Pijakan Saat Memanjat",
        Value = Config.harvestUseBlock,
        Callback = function(on) Config.harvestUseBlock = on; SaveConfig() end,
    })

    Tab:Toggle({
        Title = "Auto Collect Hasil Panen",
        Value = Config.harvestTake,
        Callback = function(on) Config.harvestTake = on; SaveConfig() end,
    })
end)

-- 2D. Tab: Auto DF (Dirt Farm Full World) ----------------------------
SafeUI("Tab:AutoDF", function()
    local Tab = AutoSection:Tab({
        Title = "Auto DF (Full World)",
        Icon = "solar:hamburger-menu-bold",
        IconColor = Yellow,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.df = Tab

    local dfPara = Tab:Paragraph({ Title = "Status Auto Dirt Farm (Full World)", Desc = "Memuat..." })

    task.spawn(function()
        while alive() and task.wait(0.4) do
            pcall(function()
                local st = DF.stats
                local dirtId = GetDirtId()
                local seedId = GetDirtSeedId()
                SetElementText(
                    dfPara,
                    "Status: " .. DF.status .. " (" .. tostring(st.step) .. ")",
                    string.format(
                        "Lapisan Dirt: Y=%d | Bedrock: Y=%d\nStok Dirt: %d | Stok Dirt Seed: %d\nHancur: %d | Dirt Dipasang: %d | Drop Diambil: %d",
                        st.topDirtY, st.bedrockY, CountItem(dirtId), CountItem(seedId), st.broken, st.placed, st.picked
                    )
                )
            end)
        end
    end)

    AddFeatureToggle(Tab, "Jalankan Auto Dirt Farm (Full World)", "Bangun DF bawah & atas otomatis + Smart Supply (tanam/panen/break Dirt otomatis saat stok habis, tanpa ModFly).", "autodf")

    Tab:Toggle({
        Title = "Ganti Lava/Rock dengan Dirt di Platform",
        Value = Config.dfReplacePlatform,
        Callback = function(on) Config.dfReplacePlatform = on; SaveConfig() end,
    })

    Tab:Toggle({
        Title = "Auto Collect Drop",
        Value = Config.dfTake,
        Callback = function(on) Config.dfTake = on; SaveConfig() end,
    })

    Tab:Input({
        Title = "Delay Pukulan Break (detik)",
        Value = tostring(Config.dfBreakDelay),
        Callback = function(text)
            local v = tonumber(text)
            if v and v >= 0.03 and v <= 5 then Config.dfBreakDelay = v; SaveConfig() end
        end,
    })

    Tab:Input({
        Title = "Delay Gerak / Langkah (detik)",
        Value = tostring(Config.dfTpDelay),
        Callback = function(text)
            local v = tonumber(text)
            if v and v >= 0.05 and v <= 5 then Config.dfTpDelay = v; SaveConfig() end
        end,
    })
end)

-- 2E. Tab: Auto Splice -----------------------------------------------
SafeUI("Tab:AutoSplice", function()
    local Tab = AutoSection:Tab({
        Title = "Auto Splice",
        Icon = "solar:square-transfer-horizontal-bold",
        IconColor = Purple,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.splice = Tab

    local splicePara = Tab:Paragraph({ Title = "Status Auto Splice", Desc = "Memuat..." })

    task.spawn(function()
        while alive() and task.wait(0.5) do
            pcall(function()
                SetElementText(
                    splicePara,
                    "Status: " .. SpliceBot.status,
                    string.format(
                        "%s\nSeed A: %s [%d] (x%d) | Seed B: %s [%d] (x%d)\nDitanam: %d | Berhasil Splice: %d",
                        SpliceBot.ResultText(),
                        ItemName(Config.spliceA), Config.spliceA, CountItem(Config.spliceA),
                        ItemName(Config.spliceB), Config.spliceB, CountItem(Config.spliceB),
                        SpliceBot.planted, SpliceBot.made
                    )
                )
            end)
        end
    end)

    AddFeatureToggle(Tab, "Jalankan Auto Splice", "Tanam Seed A lalu gabungkan (splice) dengan Seed B.", "autosplice")

    Tab:Input({
        Title = "ID Seed A (Ditanam Pertama)",
        Value = tostring(Config.spliceA),
        Placeholder = "3 (Dirt Seed)",
        Callback = function(t)
            local v = tonumber(t)
            if v and v > 0 then Config.spliceA = math.floor(v); SaveConfig() end
        end,
    })

    Tab:Input({
        Title = "ID Seed B (Di-splice ke Pohon A)",
        Value = tostring(Config.spliceB),
        Placeholder = "5 (Lava Seed)",
        Callback = function(t)
            local v = tonumber(t)
            if v and v > 0 then Config.spliceB = math.floor(v); SaveConfig() end
        end,
    })

    Tab:Toggle({
        Title = "Keliling World Otomatis (A*)",
        Desc = "Nyala = cari tempat kosong di seluruh world. Mati = hanya di kotak Grid 5x5.",
        Value = Config.spliceRoam,
        Callback = function(on) Config.spliceRoam = on; SaveConfig() end,
    })

    Tab:Slider({
        Title = "Jeda Tanam / Splice (ms)",
        IsTooltip = true,
        Step = 10,
        Value = { Min = 140, Max = 2000, Default = math.clamp(Config.spliceMs, 140, 2000) },
        Callback = function(v) Config.spliceMs = math.floor(tonumber(v) or 300); SaveConfig() end,
    })
end)

-- 2F. Tab: Pabrik / Factory ------------------------------------------
SafeUI("Tab:Pabrik", function()
    local Tab = AutoSection:Tab({
        Title = "Pabrik (Factory)",
        Icon = "solar:folder-with-files-bold",
        IconColor = Blue,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.pabrik = Tab

    local pabrikPara = Tab:Paragraph({ Title = "Status Pabrik Seed", Desc = "Memuat..." })

    task.spawn(function()
        while alive() and task.wait(0.5) do
            pcall(function()
                local sid = Config.pabrikSeedId
                local bid = BlockOfSeed(sid)
                local wTarget, dTarget = Pabrik.ParseDropTarget()
                local dropInfo = (wTarget ~= "" and wTarget or "World Ini")
                    .. (dTarget and (" Pintu:" .. dTarget) or "")
                    .. (Config.pabrikDropX >= 0 and string.format(" (%d,%d)", Config.pabrikDropX, Config.pabrikDropY) or "")
                SetElementText(
                    pabrikPara,
                    string.format("Status: %s (Fase: %s)", Pabrik.status, Pabrik.phase),
                    string.format(
                        "Seed: %s [%d] x%d | Block: %s x%d\nPosisi Break: %s\nTarget Drop: %s (Drop >= %d, Sisakan %d)\nHasil: Panen %d | Tanam %d | Di-drop %d",
                        ItemName(sid), sid, CountItem(sid),
                        bid and ItemName(bid) or "-", bid and CountItem(bid) or 0,
                        Config.pabrikBreakX >= 0 and string.format("(%d, %d)", Config.pabrikBreakX, Config.pabrikBreakY) or "Belum diatur",
                        Config.pabrikDrop and dropInfo or "Mati", Config.pabrikDropAt, Config.pabrikKeep,
                        Pabrik.harvested, Pabrik.planted, Pabrik.dropped
                    )
                )
            end)
        end
    end)

    AddFeatureToggle(Tab, "Jalankan Pabrik", "Siklus otomatis Panen -> Tanam -> Break -> Auto Drop Seed lebihan.", "pabrik")

    Tab:Input({
        Title = "ID Seed Pabrik",
        Desc = "Block otomatis terdeteksi (contoh: 3 = Dirt Seed -> Block ID 2 = Dirt).",
        Value = tostring(Config.pabrikSeedId),
        Callback = function(t)
            local v = tonumber(t)
            if v and v > 0 then Config.pabrikSeedId = math.floor(v); SaveConfig() end
        end,
    })

    Tab:Button({
        Title = "Pakai Posisi Karakter Sekarang untuk Tempat Break",
        Justify = "Center",
        Callback = function()
            local tx, ty = GetTile()
            if not tx then Notify("Posisi belum terbaca!"); return end
            Config.pabrikBreakX, Config.pabrikBreakY = tx, ty
            SaveConfig()
            Notify(string.format("Posisi Break Pabrik disimpan di (%d, %d)", tx, ty))
        end,
    })

    Tab:Button({
        Title = "Pilih Tile Break Pabrik (Buka Grid Mode Pabrik)",
        Color = Color3.fromHex("#305dff"),
        Justify = "Center",
        Callback = function()
            if SetGridMode then SetGridMode("pabrik") end
            if GridGui then GridGui.Enabled = true end
        end,
    })

    Tab:Slider({
        Title = "Lama 1 Sesi Break (detik)",
        IsTooltip = true,
        Step = 5,
        Value = { Min = 15, Max = 300, Default = math.clamp(Config.pabrikBreakSec, 15, 300) },
        Callback = function(v) Config.pabrikBreakSec = math.floor(tonumber(v) or 60); SaveConfig() end,
    })

    Tab:Space()
    Tab:Section({ Title = "Pengaturan Auto Drop Seed" })

    Tab:Toggle({
        Title = "Aktifkan Auto Drop Seed",
        Value = Config.pabrikDrop,
        Callback = function(on) Config.pabrikDrop = on; SaveConfig() end,
    })

    Tab:Slider({
        Title = "Drop Saat Jumlah Seed Mencapai >=",
        IsTooltip = true,
        Step = 5,
        Value = { Min = 10, Max = 200, Default = math.clamp(Config.pabrikDropAt, 10, 200) },
        Callback = function(v) Config.pabrikDropAt = math.floor(tonumber(v) or 200); SaveConfig() end,
    })

    Tab:Slider({
        Title = "Sisakan Seed di Tas (Untuk Tanam Ulang)",
        IsTooltip = true,
        Step = 5,
        Value = { Min = 0, Max = 195, Default = math.clamp(Config.pabrikKeep, 0, 195) },
        Callback = function(v) Config.pabrikKeep = math.floor(tonumber(v) or 50); SaveConfig() end,
    })

    Tab:Input({
        Title = "World Drop (Kosong = World Ini | WORLD | WORLD:ID_PINTU)",
        Placeholder = "Contoh: STORAGE:1",
        Callback = function(t) Config.pabrikDropWorld = Trim(t or ""); SaveConfig() end,
    })

    Tab:Button({
        Title = "Pakai Posisi Sekarang untuk Tempat Drop Seed",
        Justify = "Center",
        Callback = function()
            local tx, ty = GetTile()
            if not tx then Notify("Posisi belum terbaca!"); return end
            Config.pabrikDropX, Config.pabrikDropY = tx, ty
            SaveConfig()
            Notify(string.format("Posisi Drop Pabrik disimpan di (%d, %d)", tx, ty))
        end,
    })
end)

-- 3A. Tab: Tas (Auto Recycle, Convert Lock & Drop WL) ----------------
SafeUI("Tab:Bag", function()
    local Tab = BagWorldSection:Tab({
        Title = "Tas (Recycle & Lock)",
        Icon = "solar:check-square-bold",
        IconColor = Green,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.bag = Tab

    local bagPara = Tab:Paragraph({ Title = "Status Manajemen Tas", Desc = "Memuat..." })

    task.spawn(function()
        while alive() and task.wait(0.8) do
            pcall(function()
                local ids = {}
                for _, id in ipairs(Config.trashList or {}) do
                    table.insert(ids, ItemName(id) .. " [" .. id .. "]")
                end
                SetElementText(
                    bagPara,
                    "Aksi Terakhir: " .. Bag.status,
                    string.format(
                        "Total Di-recycle: %d item | Convert Lock: %d kali\nDaftar Item Recycle: %s",
                        Bag.recycled, Bag.converted, #ids > 0 and table.concat(ids, ", ") or "(Belum ada)"
                    )
                )
            end)
        end
    end)

    Tab:Toggle({
        Title = "Aktifkan Auto Recycle (Buang Item Otomatis)",
        Value = Config.trashOn,
        Callback = function(on) Config.trashOn = on; SaveConfig() end,
    })

    Tab:Input({
        Title = "Tambah / Hapus ID Item Recycle",
        Desc = "Ketik angka ID item (misal 2 untuk Dirt) lalu Enter untuk menambah/menghapus dari daftar.",
        Placeholder = "Ketik ID item...",
        Callback = function(t)
            local id = tonumber(t)
            if not id or id <= 0 then return end
            id = math.floor(id)
            local idx = table.find(Config.trashList, id)
            if idx then
                table.remove(Config.trashList, idx)
                Notify(ItemName(id) .. " dihapus dari daftar Auto Recycle.")
            else
                table.insert(Config.trashList, id)
                Notify(ItemName(id) .. " ditambahkan ke daftar Auto Recycle.")
            end
            SaveConfig()
        end,
    })

    Tab:Slider({
        Title = "Recycle Kalau Jumlah >=",
        IsTooltip = true,
        Step = 5,
        Value = { Min = 5, Max = 200, Default = math.clamp(Config.trashAt, 5, 200) },
        Callback = function(v) Config.trashAt = math.floor(tonumber(v) or 150); SaveConfig() end,
    })

    Tab:Slider({
        Title = "Sisakan di Tas (Jangan Di-recycle)",
        IsTooltip = true,
        Step = 5,
        Value = { Min = 0, Max = 195, Default = math.clamp(Config.trashKeep, 0, 195) },
        Callback = function(v) Config.trashKeep = math.floor(tonumber(v) or 0); SaveConfig() end,
    })

    Tab:Space()
    Tab:Section({ Title = "Lock & Drop Cepat" })

    Tab:Toggle({
        Title = "Auto Convert Lock (100 WL -> 1 DL, 100 DL -> 1 BGL)",
        Value = Config.convertLockOn,
        Callback = function(on) Config.convertLockOn = on; SaveConfig() end,
    })

    local dropAmountText = "100"
    Tab:Input({
        Title = "Jumlah Drop World Lock",
        Value = "100",
        Placeholder = "Jumlah (1-10000)",
        Callback = function(text) dropAmountText = text end,
    })

    Tab:Button({
        Title = "Drop World Lock Sekarang",
        Color = Color3.fromHex("#305dff"),
        Justify = "Center",
        Callback = function()
            local amount = tonumber(dropAmountText)
            if amount and amount >= 1 and amount <= MAX_AMOUNT then
                task.spawn(DropWorldLock, math.floor(amount))
            else
                Notify("Jumlah WL tidak valid!")
            end
        end,
    })
end)

-- 3B. Tab: GrowScan 9000 ---------------------------------------------
SafeUI("Tab:GrowScan", function()
    local ScanTab = BagWorldSection:Tab({
        Title = "GrowScan 9000",
        Icon = "solar:info-square-bold",
        IconColor = Blue,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.scan = ScanTab

    local scanInfoPara = ScanTab:Paragraph({ Title = "GrowScan 9000", Desc = "Tekan tombol Scan di bawah untuk memindai isi world." })

    local function RunGrowScan()
        local data = ScanWorld()
        if not data then
            SetElementText(scanInfoPara, "GrowScan", "World belum terbaca.")
            return
        end
        local function topItems(counts, maxLines)
            local arr = {}
            for id, n in pairs(counts) do table.insert(arr, { id = id, n = n }) end
            table.sort(arr, function(a, b) return a.n > b.n end)
            local out = {}
            for i = 1, math.min(maxLines or 12, #arr) do
                table.insert(out, string.format("• %s [%d] x%d", ItemName(arr[i].id), arr[i].id, arr[i].n))
            end
            return #out > 0 and table.concat(out, "\n") or "Kosong"
        end
        local treeLines = {}
        for id, t in pairs(data.trees) do
            local nxt = t.nextIn and string.format(" (panen dlm %ds)", math.max(0, math.ceil(t.nextIn))) or ""
            table.insert(treeLines, string.format("• %s: %d siap | %d tumbuh%s", ItemName(id), t.ready, t.growing, nxt))
        end
        local desc = table.concat({
            string.format("World: %s (%dx%d)", CurrentWorldName(), data.w, data.h),
            string.format("FG: %d | BG: %d | Floating: %d (%d tumpukan)", data.totalFg, data.totalBg, data.totalDrops, data.piles),
            string.format("Pohon: %d siap panen | %d tumbuh", data.readyTrees, data.growingTrees),
            "\n[POHON DI WORLD]:\n" .. (#treeLines > 0 and table.concat(treeLines, "\n") or "Tidak ada pohon"),
            "\n[FLOATING DROPS]:\n" .. topItems(data.drops, 10),
            "\n[WORLD BLOCKS]:\n" .. topItems(data.fg, 12),
        }, "\n")
        SetElementText(scanInfoPara, "Hasil GrowScan (" .. os.date("%H:%M:%S") .. ")", desc)
    end

    ScanTab:Button({
        Title = "Scan Isi World Sekarang",
        Color = Color3.fromHex("#305dff"),
        Justify = "Center",
        Callback = RunGrowScan,
    })

    ScanTab:Button({
        Title = "Buka UI GrowScan Bawaan Game",
        Justify = "Center",
        Callback = function()
            if not OpenNativeGrowScan() then Notify("GrowScan bawaan tidak tersedia.") end
        end,
    })
end)

-- 3C. Tab: Teleport & Posisi (Pos 1/2) -------------------------------
SafeUI("Tab:Pos", function()
    local PosTab = BagWorldSection:Tab({
        Title = "Teleport & Posisi",
        Icon = "solar:hamburger-menu-bold",
        IconColor = Yellow,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.pos = PosTab

    local warpTarget = ""
    PosTab:Input({
        Title = "Nama World Tujuan Warp",
        Placeholder = "Ketik nama world...",
        Callback = function(t) warpTarget = Trim(t or "") end,
    })

    PosTab:Button({
        Title = "Warp ke World Tujuan",
        Color = Color3.fromHex("#305dff"),
        Justify = "Center",
        Callback = function()
            if warpTarget ~= "" then task.spawn(WarpToWorld, warpTarget) else Notify("Ketik nama world terlebih dahulu!") end
        end,
    })

    PosTab:Space()
    PosTab:Section({ Title = "Simpan & Teleport Posisi (Pos 1 / Pos 2)" })

    for slot = 1, 2 do
        local posPara = PosTab:Paragraph({ Title = "Pos " .. slot, Desc = "Belum diset" })
        local function refPos()
            local p = Config["pos" .. slot]
            if type(p) == "table" and type(p.x) == "number" then
                SetElementText(posPara, "Pos " .. slot .. " Tersimpan", string.format("Tile (%d, %d) di World %s", p.x, p.y, p.world or "-"))
            else
                SetElementText(posPara, "Pos " .. slot, "Belum diset")
            end
        end
        table.insert(hub.refreshers, refPos)
        refPos()

        local grp = PosTab:Group({})
        grp:Button({ Title = "Simpan Pos " .. slot, Justify = "Center", Callback = function() SetPos(slot); RefreshHub() end })
        grp:Button({ Title = "Teleport (win" .. slot .. ")", Justify = "Center", Callback = function() task.spawn(GoToPos, slot) end })
    end
end)

-- 4A. Tab: Penjaga (Anti-Mod) & Auto Reconnect -----------------------
SafeUI("Tab:Guard", function()
    local Tab = SecuritySection:Tab({
        Title = "Penjaga & Reconnect",
        Icon = "solar:info-square-bold",
        IconColor = Red,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.guard = Tab

    local guardPara = Tab:Paragraph({ Title = "Status Penjaga & Reconnect", Desc = "Mati" })

    task.spawn(function()
        while alive() and task.wait(0.5) do
            pcall(function()
                SetElementText(
                    guardPara,
                    "Penjaga: " .. Guard.status .. " | Reconnect: " .. Reconnect.status,
                    string.format(
                        "Pemain di World: %s\nStaff Online di Server: %s\nTerdeteksi: %d kali | Berhasil Rejoin: %d kali",
                        Guard.hereText, Guard.staffServerText, Guard.detected, Reconnect.count
                    )
                )
            end)
        end
    end)

    AddFeatureToggle(Tab, "Aktifkan Penjaga (Anti-Mod)", "Pantau Moderator / Developer (termasuk undercover) atau pemain yang masuk ke world.", "guard")

    Tab:Dropdown({
        Title = "Target Deteksi",
        Values = { "Staff (Mod/Dev)", "Semua pemain" },
        Value = Config.guardWho,
        Callback = function(v) Config.guardWho = v or "Staff (Mod/Dev)"; SaveConfig() end,
    })

    Tab:Toggle({
        Title = "Hentikan Semua Aktivitas Bot",
        Value = Config.guardStopAll,
        Callback = function(on) Config.guardStopAll = on; SaveConfig() end,
    })

    Tab:Toggle({
        Title = "Langsung Keluar World (Leave World)",
        Value = Config.guardLeave,
        Callback = function(on) Config.guardLeave = on; SaveConfig() end,
    })

    Tab:Toggle({
        Title = "Lanjut Otomatis Setelah Aman",
        Value = Config.guardAutoBack,
        Callback = function(on) Config.guardAutoBack = on; SaveConfig() end,
    })

    Tab:Slider({
        Title = "Waktu Tunggu Masuk Lagi (detik)",
        IsTooltip = true,
        Step = 5,
        Value = { Min = 15, Max = 300, Default = math.clamp(Config.guardBackSec, 15, 300) },
        Callback = function(v) Config.guardBackSec = tonumber(v) or 60; SaveConfig() end,
    })

    Tab:Button({
        Title = "Whitelist Pemain yang Ada di World Sekarang",
        Justify = "Center",
        Callback = function()
            local n = Guard.AllowCurrentPlayers()
            Notify(n .. " pemain di world ini dimasukkan ke whitelist.")
        end,
    })

    Tab:Space()
    Tab:Section({ Title = "Auto Reconnect (World Closed & Server Disconnect)" })

    AddFeatureToggle(Tab, "Aktifkan Auto Reconnect", "Masuk kembali & lanjutkan aktivitas bot jika terlempar atau disconnect.", "autorejoin")

    Tab:Toggle({
        Title = "Masuk Lagi Saat World Ditutup / Di-kick",
        Value = Config.reconnectWorld,
        Callback = function(on) Config.reconnectWorld = on; SaveConfig() end,
    })

    Tab:Toggle({
        Title = "Selalu Kembali ke World (Jika Berada di Menu)",
        Value = Config.reconnectKeep,
        Callback = function(on) Config.reconnectKeep = on; SaveConfig() end,
    })

    Tab:Toggle({
        Title = "Teleport Ulang Saat Disconnect dari Server",
        Value = Config.reconnectServer,
        Callback = function(on) Config.reconnectServer = on; SaveConfig() end,
    })

    Tab:Input({
        Title = "World Tujuan Reconnect (Kosong = World Terakhir)",
        Placeholder = "NAMAWORLD",
        Callback = function(t) Config.targetWorld = Trim(t or ""); SaveConfig() end,
    })
end)

-- 4B. Tab: Auto Chat (1 Pesan) & Bonus -------------------------------
SafeUI("Tab:Bonus", function()
    local Tab = SecuritySection:Tab({
        Title = "Auto Chat & Bonus",
        Icon = "solar:file-text-bold",
        IconColor = Purple,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.bonus = Tab

    local bonusPara = Tab:Paragraph({ Title = "Status Auto Chat & Bonus", Desc = "Memuat..." })

    task.spawn(function()
        while alive() and task.wait(0.6) do
            pcall(function()
                SetElementText(
                    bonusPara,
                    string.format("Auto Chat: %s (Terkirim: %d)", Spam.on and "AKTIF" or "MATI", Spam.sent),
                    string.format("Pesan Disetting: %s\nTerakhir Terkirim: %s\nQuest: %s\nRedeem: %s", Config.chatText ~= "" and Config.chatText or "(Belum diisi)", Spam.last, Bonus.questText, Bonus.codeText)
                )
            end)
        end
    end)

    Tab:Section({ Title = "Auto Chat / Spammer (1 Pesan)" })

    AddFeatureToggle(Tab, "Aktifkan Auto Chat", "Kirim 1 pesan yang telah disetting secara otomatis ke channel world.", "autochat")

    Tab:Input({
        Title = "Pesan Auto Chat",
        Placeholder = "Ketik 1 pesan yang akan dikirim otomatis...",
        Callback = function(text)
            Config.chatText = Trim(text or "")
            SaveConfig()
        end,
    })

    Tab:Slider({
        Title = "Interval Chat (detik)",
        IsTooltip = true,
        Step = 1,
        Value = { Min = 3, Max = 120, Default = math.clamp(Config.chatInterval, 3, 120) },
        Callback = function(v) Config.chatInterval = tonumber(v) or 6; SaveConfig() end,
    })

    Tab:Space()
    Tab:Section({ Title = "Bonus: Auto Claim Quest & Auto Redeem Code" })

    Tab:Toggle({
        Title = "Auto Claim Quest Harian (Server Net.call)",
        Value = Config.bonusAutoQuest,
        Callback = function(on)
            Config.bonusAutoQuest = on
            if on then Bonus.nextQuest = 0 end
            SaveConfig()
        end,
    })

    Tab:Button({
        Title = "Cek & Klaim Quest Sekarang",
        Justify = "Center",
        Callback = function() task.spawn(Bonus.CheckQuests) end,
    })

    Tab:Toggle({
        Title = "Auto Redeem Active Codes",
        Value = Config.bonusAutoRedeem,
        Callback = function(on)
            Config.bonusAutoRedeem = on
            if on then Bonus.nextCode = 0 end
            SaveConfig()
        end,
    })

    Tab:Input({
        Title = "Redeem Code Manual",
        Placeholder = "Ketik kode lalu Enter...",
        Callback = function(text)
            local code = Trim(text)
            if code == "" then return end
            task.spawn(function()
                local ok, msg = Bonus.RedeemSingle(code)
                Notify(code .. ": " .. tostring(msg), ok and "Redeem Sukses" or "Redeem Gagal")
            end)
        end,
    })
end)

-- 5A. Tab: Visual, Role & Watermark ----------------------------------
SafeUI("Tab:Visual", function()
    local VisTab = SystemSection:Tab({
        Title = "Visual & Watermark",
        Icon = "solar:password-minimalistic-input-bold",
        IconColor = Purple,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.visual = VisTab

    VisTab:Toggle({
        Title = "Watermark Nama Beranimasi",
        Desc = "Ubah tampilan nama di atas karakter & HUD kiri atas dengan efek gradient.",
        Value = Config.customWatermark,
        Callback = function(on) Config.customWatermark = on; SaveConfig() end,
    })

    VisTab:Input({
        Title = "Teks Watermark Nama",
        Value = Config.watermarkText ~= "" and Config.watermarkText or "ANCH HUB",
        Placeholder = "ANCH HUB",
        Callback = function(text)
            if Trim(text) ~= "" then
                Config.watermarkText = Trim(text)
                SaveConfig()
            end
        end,
    })

    VisTab:Space()
    VisTab:Section({ Title = "Visual Item Lokal (Kuyang, LegendBot, Rayman)" })

    local activeFilter, searchQ = "Semua", ""
    local wearMap = {}
    local wearDd

    local function rebuildWear()
        local list = GetWearables()
        wearMap = {}
        local vals = {}
        local q = Trim(searchQ):lower()
        for _, e in ipairs(list) do
            if (activeFilter == "Semua" or table.find(e.tags, activeFilter)) and (q == "" or e.lower:find(q, 1, true)) then
                local lbl = string.format("%s (%s)%s #%d", e.name, e.slot, IsVisualWorn(e.id) and " [ON]" or "", e.id)
                wearMap[lbl] = e.id
                table.insert(vals, lbl)
                if #vals >= 80 then break end
            end
        end
        if #vals == 0 then vals = { "Tidak ada item" } end
        if wearDd and wearDd.Refresh then pcall(function() wearDd:Refresh(vals) end) end
    end

    VisTab:Dropdown({
        Title = "Filter Kategori",
        Values = { "Semua", "Kuyang", "LegendBot", "Rayman" },
        Value = "Semua",
        Callback = function(v) activeFilter = v or "Semua"; rebuildWear() end,
    })

    VisTab:Input({
        Title = "Cari Item Visual",
        Placeholder = "Ketik nama item...",
        Callback = function(t) searchQ = t or ""; rebuildWear() end,
    })

    wearDd = VisTab:Dropdown({
        Title = "Pilih Item Visual (Tap untuk Pakai/Lepas)",
        Values = { "Memuat..." },
        Callback = function(sel)
            local id = wearMap[sel]
            if id and ToggleVisual(id) then
                Notify("Visual item diubah: " .. ItemName(id))
                rebuildWear()
            end
        end,
    })

    VisTab:Button({
        Title = "Reset Semua Visual Item",
        Color = Color3.fromHex("#ff4830"),
        Justify = "Center",
        Callback = function() ResetVisuals(); rebuildWear() end,
    })

    VisTab:Space()
    VisTab:Section({ Title = "Role / Title & Staff UI" })

    local roleDd = VisTab:Dropdown({
        Title = "Pilih Role / Title",
        Values = { "none" },
        Callback = function(v) Config.selectedRole = v or "none"; SaveConfig() end,
    })

    VisTab:Button({
        Title = "Refresh & Pasang Role Sekarang",
        Justify = "Center",
        Callback = function()
            if roleDd and roleDd.Refresh then pcall(function() roleDd:Refresh(GetOwnedRoles()) end) end
            ApplyRole(Config.selectedRole)
        end,
    })

    VisTab:Button({
        Title = "Buka Staff Backpack",
        Justify = "Center",
        Callback = function()
            if Refs.Menu and type(Refs.Menu.openBackpack) == "function" then
                pcall(Refs.Menu.openBackpack, { name = Player.DisplayName or Player.Name, userId = Player.UserId })
            else
                Notify("Menu Staff belum ditemukan.")
            end
        end,
    })

    task.defer(rebuildWear)
end)

-- 5B. Tab: Discord Webhook & Pengaturan Sistem -----------------------
SafeUI("Tab:Settings", function()
    local SesiTab = SystemSection:Tab({
        Title = "Discord & Pengaturan",
        Icon = "solar:folder-with-files-bold",
        IconColor = Blue,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.session = SesiTab
    hub.tabs.settings = SesiTab

    local whPara = SesiTab:Paragraph({ Title = "Status Discord Webhook", Desc = "-" })
    task.spawn(function()
        while alive() and task.wait(1) do
            pcall(function()
                SetElementText(whPara, "Status Webhook: " .. Webhook.Status, "Antrian Pesan: " .. #Webhook.Queue)
            end)
        end
    end)

    SesiTab:Toggle({
        Title = "Aktifkan Notifikasi Discord Webhook",
        Value = Config.webhookOn,
        Callback = function(on) Config.webhookOn = on; SaveConfig() end,
    })

    SesiTab:Input({
        Title = "URL Webhook Discord",
        Placeholder = "https://discord.com/api/webhooks/...",
        Callback = function(t)
            Config.webhookUrl = Trim(t or "")
            SaveConfig()
            if Config.webhookUrl ~= "" and not Webhook.Valid(Config.webhookUrl) then
                Notify("Format URL Webhook Discord tidak valid!")
            end
        end,
    })

    SesiTab:Button({
        Title = "Tes Kirim Webhook Discord",
        Justify = "Center",
        Callback = function()
            if not Webhook.Valid(Config.webhookUrl) then
                Notify("Isi URL Webhook Discord yang valid terlebih dahulu!")
                return
            end
            local prev = Config.webhookOn
            Config.webhookOn = true
            Webhook.Send("test", "Tes notifikasi dari ANCH Hub v11 Ultimate!")
            Config.webhookOn = prev
            Notify("Pesan tes masuk antrian kirim Discord.")
        end,
    })

    SesiTab:Slider({
        Title = "Interval Laporan Statistik ke Discord (Menit, 0 = Mati)",
        IsTooltip = true,
        Step = 5,
        Value = { Min = 0, Max = 180, Default = math.clamp(Config.webhookReportMin, 0, 180) },
        Callback = function(v) Config.webhookReportMin = math.floor(tonumber(v) or 0); SaveConfig() end,
    })

    SesiTab:Space()
    SesiTab:Section({ Title = "Sesi, Kalibrasi & Autoexec" })

    SesiTab:Toggle({
        Title = "Pulihkan Fitur Otomatis Saat Masuk",
        Value = Config.autoRestore,
        Callback = function(on) Config.autoRestore = on; SaveConfig() end,
    })

    SesiTab:Toggle({
        Title = "Auto-Reload Skrip Saat Teleport",
        Value = Config.autoReload,
        Callback = function(on) Config.autoReload = on; SaveConfig(); if on then QueueReload() end end,
    })

    SesiTab:Input({
        Title = "URL Script (Untuk Auto-Reload Teleport)",
        Placeholder = "https://...",
        Callback = function(t) Config.scriptUrl = Trim(t or ""); SaveConfig() end,
    })

    SesiTab:Input({
        Title = "Prefix Command Chat",
        Value = Config.prefix ~= "" and Config.prefix or "/",
        Callback = function(t) Config.prefix = Trim(t); SaveConfig() end,
    })

    SesiTab:Input({
        Title = "Kalibrasi Posisi X",
        Value = tostring(Config.calibX),
        Callback = function(t) Config.calibX = tonumber(t) or 0; SaveConfig() end,
    })

    SesiTab:Input({
        Title = "Kalibrasi Posisi Y",
        Value = tostring(Config.calibY),
        Callback = function(t) Config.calibY = tonumber(t) or 0; SaveConfig() end,
    })

    SesiTab:Keybind({
        Title = "Keybind Buka/Tutup UI",
        Value = "RightControl",
        Callback = function(v) pcall(function() Window:SetToggleKey(Enum.KeyCode[v]) end) end,
    })

    SesiTab:Button({
        Title = "Pasang Auto-Execute (autoexec)",
        Justify = "Center",
        Callback = InstallAutoexec,
    })
end)

-- 5C. Tab: Bantuan & Daftar Command ----------------------------------
SafeUI("Tab:Help", function()
    local HelpTab = SystemSection:Tab({
        Title = "Panduan Command",
        Icon = "solar:info-square-bold",
        IconColor = Green,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.help = HelpTab

    HelpTab:Paragraph({
        Title = "Daftar Perintah Chat ANCH Hub v11 Ultimate",
        Desc = table.concat({
            "/af [on/off]  —  Auto Farm (Multi-Target + Rayman)",
            "/ac [on/off]  —  Auto Clear World (ModFly + Berdiri di Atas Blok)",
            "/ah [on/off]  —  Farmer (Auto Harvest + Auto Plant)",
            "/adf [on/off] —  Auto Dirt Farm (Full World + Smart Supply)",
            "/as [on/off]  —  Auto Splice (Seed A + Seed B)",
            "/pabrik [on/off] — Pabrik Seed (Panen -> Tanam -> Break -> Drop)",
            "/guard [on/off] — Penjaga Anti-Mod / Staff Detector",
            "/chat [on/off]  — Auto Chat / Spammer (1 Pesan)",
            "/ctp [on/off] —  Click TP (Legit A* / Pillar)",
            "/move <legit|walk|fly|mix> — Ubah mode gerak",
            "/noclip | /uj | /god | /lite | /blink | /lh [n|off] | /aq [on|off|scan]",
            "/wld <jumlah> | /tp <world> | /pos1 | /pos2 | /win1 | /win2",
        }, "\n"),
    })
end)

----------------------------------------------------------------------
-- COMMAND HANDLER & CHAT HOOK
----------------------------------------------------------------------
local function ToggleHub(tabId)
    local target = hub.tabs[tabId or "features"]
    if target and target.Select then pcall(function() target:Select() end) end
    if Window.Open then pcall(function() Window:Open() end) end
end

local function WantedState(args, current)
    if args == "on" or args == "start" then return true
    elseif args == "off" or args == "stop" then return false end
    return not current
end

local function HandleMessage(text)
    text = Trim(text)
    if text == "" then return false end
    local prefix = Config.prefix
    local bodyText
    if prefix == "" then
        bodyText = text
    elseif text:sub(1, #prefix) == prefix then
        bodyText = text:sub(#prefix + 1)
    elseif text:sub(1, 1) == "/" then
        local w = text:sub(2):lower()
        if w == "settingsgb" or w == "sgb" or w == "hpx" then bodyText = text:sub(2) end
    end
    if not bodyText then return false end
    local command, args = bodyText:match("^(%S+)%s*(.-)%s*$")
    if not command then return false end
    command, args = command:lower(), (args or ""):lower()

    if command == "wld" or command == "wd" then
        local n = tonumber(args:match("^(%d+)$"))
        if n and n >= 1 and n <= MAX_AMOUNT then task.spawn(DropWorldLock, n) else Notify("Jumlah WL tidak valid!") end
        return true
    elseif command == "tp" or command == "warp" then
        task.spawn(WarpToWorld, args); return true
    elseif command == "pos1" or command == "pos2" then
        SetPos(tonumber(command:sub(4))); RefreshHub(); return true
    elseif command == "pos" then
        ShowPos(); return true
    elseif command == "win1" or command == "w1" or command == "win2" or command == "w2" then
        local slot = tonumber(command:match("%d$"))
        local n = tonumber(args:match("^(%d+)$"))
        task.spawn(GoToPos, slot, n); return true
    elseif command == "rejoin" or command == "rj" then
        task.spawn(Rejoin); return true
    elseif command == "noclip" then
        SetFeature("noclip", WantedState(args, noclipOn)); return true
    elseif command == "unlimitedjump" or command == "uj" or command == "infjump" then
        SetFeature("ujump", WantedState(args, ujumpOn)); return true
    elseif command == "afk" or command == "antiafk" then
        SetFeature("antiafk", WantedState(args, antiAfkOn)); return true
    elseif command == "autorejoin" or command == "arj" then
        SetFeature("autorejoin", WantedState(args, Config.reconnectOn)); return true
    elseif command == "blink" then
        SetFeature("blink", WantedState(args, blinkOn)); return true
    elseif command == "longhand" or command == "lh" then
        local rangeNum = tonumber(args)
        if rangeNum and rangeNum > 0 then
            Config.longhandRange = rangeNum
            SaveConfig()
            SetFeature("longhand", true)
        else
            SetFeature("longhand", WantedState(args, longhandOn))
        end
        return true
    elseif command == "autoquest" or command == "aq" then
        if args == "scan" then
            task.spawn(QuestReport)
        else
            SetFeature("autoquest", WantedState(args, questOn))
        end
        return true
    elseif command == "god" or command == "godmode" then
        SetFeature("god", WantedState(args, godOn)); return true
    elseif command == "lite" then
        SetFeature("lite", WantedState(args, Config.liteMode)); return true
    elseif command == "guard" or command == "penjaga" then
        SetFeature("guard", WantedState(args, Guard.on)); return true
    elseif command == "chat" or command == "autochat" then
        SetFeature("autochat", WantedState(args, Spam.on)); return true
    elseif command == "autofarm" or command == "af" then
        if args == "" then ToggleHub("farm") else SetFeature("autofarm", WantedState(args, Farm.on)) end
        return true
    elseif command == "autoclear" or command == "ac" or command == "clear" then
        if args == "" then ToggleHub("clear") else SetFeature("autoclear", WantedState(args, Clear.on)) end
        return true
    elseif command == "autoharvest" or command == "ah" or command == "harvest" or command == "farmer" then
        if args == "" then ToggleHub("harvest") else SetFeature("autoharvest", WantedState(args, Farmer.on)) end
        return true
    elseif command == "autodf" or command == "adf" or command == "df" then
        if args == "" then ToggleHub("df") else SetFeature("autodf", WantedState(args, DF.on)) end
        return true
    elseif command == "autosplice" or command == "as" or command == "splice" then
        if args == "" then ToggleHub("splice") else SetFeature("autosplice", WantedState(args, SpliceBot.on)) end
        return true
    elseif command == "pabrik" or command == "factory" then
        if args == "" then ToggleHub("pabrik") else SetFeature("pabrik", WantedState(args, Pabrik.on)) end
        return true
    elseif command == "clicktp" or command == "ctp" then
        SetFeature("clicktp", WantedState(args, Nav.clickOn)); return true
    elseif command == "move" or command == "mv" then
        local map = { legit = "legit", walk = "walk", jalan = "walk", fly = "fly", terbang = "fly", mix = "mix", campur = "mix" }
        if map[args] then
            Config.moveMode = map[args]
            SaveConfig()
            Notify("Mode gerak: " .. map[args])
        else
            Notify("Mode aktif: " .. Config.moveMode .. " (pilihan: legit | walk | fly | mix)")
        end
        return true
    elseif command == "growscan" or command == "gs" then
        ToggleHub("scan"); return true
    elseif command == "visualitem" or command == "vi" then
        ToggleHub("visual"); return true
    elseif command == "settingsgb" or command == "sgb" or command == "session" or command == "sesi" then
        ToggleHub("session"); return true
    elseif command == "blockid" or command == "bid" then
        local found = SearchItems(args, 5)
        local parts = {}
        for _, e in ipairs(found) do table.insert(parts, e.name .. " = " .. e.id) end
        Notify(#parts > 0 and table.concat(parts, " | ") or "Block tidak ditemukan.")
        return true
    elseif command == "hpx" then
        ToggleHub("help"); return true
    end
    return false
end

do (function()
    local hooked, lastMsg, lastTime = {}, nil, 0
    local function processText(t)
        if type(t) ~= "string" then return end
        local norm = Trim(t):lower()
        if norm == lastMsg and os.clock() - lastTime < 1.5 then return end
        if HandleMessage(Trim(t)) then
            lastMsg, lastTime = norm, os.clock()
        end
    end
    local function hookBox(box)
        if hooked[box] or not box:IsA("TextBox") then return end
        local sg = box:FindFirstAncestorOfClass("ScreenGui")
        if sg and (sg.Name:find("ANCH", 1, true) or sg.Name:lower():find("windui", 1, true)) then return end
        hooked[box] = true
        local last = ""
        box:GetPropertyChangedSignal("Text"):Connect(function()
            if box.Text ~= "" then last = box.Text end
        end)
        box.FocusLost:Connect(function(enter)
            if enter then
                local txt = box.Text ~= "" and box.Text or last
                last = ""
                processText(txt)
            end
        end)
    end
    for _, d in ipairs(PlayerGui:GetDescendants()) do hookBox(d) end
    trackConn(PlayerGui.DescendantAdded:Connect(hookBox))
    trackConn(Player.Chatted:Connect(processText))
end)() end

----------------------------------------------------------------------
-- INISIALISASI & CLEANUP HANDLER
----------------------------------------------------------------------
Session.Cleanup = function()
    Session.Alive = false
    StopFarm()
    Clear.Stop()
    Farmer.Stop()
    DF.Stop()
    SpliceBot.Stop()
    Pabrik.Stop()
    Nav.StopClick()
    Guard.Set(false)
    Spam.on = false
    StopBlink()
    StopLonghand()
    StopNoclip()
    StopUjump()
    StopGod()
    LiteMode.Set(false)
    if Session.RestoreWatermark then pcall(Session.RestoreWatermark) end
    if OrigIsDown and MenuModOk and rawget(MenuModule, "isDown") ~= OrigIsDown then
        MenuModule.isDown = OrigIsDown
    end
    for _, c in ipairs(Session.Connections) do pcall(function() c:Disconnect() end) end
    if GridGui then pcall(function() GridGui:Destroy() end) end
    if FlyPadGui then pcall(function() FlyPadGui:Destroy() end) end
    if Window then pcall(function() Window:Destroy() end) end
end

task.spawn(function()
    Refs.Scan()
    Stats.Reset()
    if Config.liteMode then LiteMode.Set(true) end
    pcall(QueueReload)
    trackConn(Player.OnTeleport:Connect(function()
        SaveConfig()
        pcall(QueueReload)
    end))
    if Config.autoRestore then
        for key, feature in pairs(Features) do
            if Config.session[key] and not feature.noSession and not feature.get() then
                pcall(feature.set, true)
            end
        end
        if RefreshHub then RefreshHub() end
    end
    task.spawn(Reconnect.CheckStartup)
    Notify("ANCH HUB v11 Ultimate Loaded! Semua tab & fitur siap digunakan.")
end)
