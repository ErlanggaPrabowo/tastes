--[[
    ANCH HUB | GrowBlox  (V1.3 - All-in-One WindUI)

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
      anch                         Daftar perintah
]]

----------------------------------------------------------------------
-- SESI & CEGAH DOBEL EKSEKUSI (DENGAN CLEANUP OTOMATIS)
----------------------------------------------------------------------
local G = (getgenv and getgenv()) or _G

-- Cegah eksekusi dobel/spam (3x load sekaligus) saat baru pindah world / teleport
if G.__ANCHHub_LoadingAt and (os.clock() - G.__ANCHHub_LoadingAt) < 4.5 then
    return
end
G.__ANCHHub_LoadingAt = os.clock()

for _, key in ipairs({ "__ANCHHubSession", "__Tadonoki", "__Alfian", "__GTFarm" }) do
    if G[key] then
        G[key].Alive = false
        if G[key].Cleanup then
            pcall(G[key].Cleanup)
        end
    end
    G[key] = nil
end

local Session = { Alive = true, Connections = {} }
Session.Cleanup = function() Session.Alive = false end
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

-- Pelaksana UI dengan izin thread awal (mencegah error capability pada Dropdown)
do
    local getId = getthreadidentity or get_thread_identity or getidentity or (syn and syn.get_thread_identity)
    if type(getId) == "function" then pcall(function() Session.Ident = getId() end) end
    Session.Exec = coroutine.create(function(job)
        while true do
            local ok, err = pcall(job)
            job = coroutine.yield(ok, err)
        end
    end)
end

local function ExecUI(fn)
    local setId = setthreadidentity or set_thread_identity or setidentity or (syn and syn.set_thread_identity)
    local function elevate()
        if Session.Ident and type(setId) == "function" then pcall(setId, Session.Ident) end
    end
    local co = Session.Exec
    if co and coroutine.status(co) == "suspended" then
        local okR, ok = coroutine.resume(co, function()
            elevate()
            fn()
        end)
        if okR and ok ~= false then return true end
    end
    elevate()
    return pcall(fn)
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
local RunService = cloneref(game:GetService("RunService"))
local TeleportService = cloneref(game:GetService("TeleportService"))
local VirtualUser = cloneref(game:GetService("VirtualUser"))
local TextChatService = cloneref(game:GetService("TextChatService"))
local TextService = cloneref(game:GetService("TextService"))

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui", 5)

local Shared = ReplicatedStorage:FindFirstChild("Shared") or ReplicatedStorage:WaitForChild("Shared", 3)
local WorldRemotes = ReplicatedStorage:FindFirstChild("WorldRemotes") or ReplicatedStorage:WaitForChild("WorldRemotes", 1)
local DropEvent = WorldRemotes and WorldRemotes:FindFirstChild("DropItem")
local SetTileRemote = WorldRemotes and WorldRemotes:FindFirstChild("SetTile")
local TakeDropRemote = WorldRemotes and WorldRemotes:FindFirstChild("TakeDrop")
local PickTitleRemote = WorldRemotes and WorldRemotes:FindFirstChild("PickTitle")
local WorldClosedRemote = WorldRemotes and WorldRemotes:FindFirstChild("WorldClosed")

local ItemDB = G.__ANCH_ItemDBCache or {}
local function ResolveItemDB()
    if next(ItemDB) ~= nil then return ItemDB end
    pcall(function()
        local rawRep = game:GetService("ReplicatedStorage")
        local sh = rawRep:FindFirstChild("Shared") or Shared
        local mod = sh and sh:FindFirstChild("ItemDB")
        if mod then
            local ok, res = pcall(require, mod)
            if ok and type(res) == "table" then
                if type(rawget(res, 2)) == "table" or type(res[2]) == "table" then
                    ItemDB = res
                else
                    for _, k in ipairs({ "items", "Items", "list", "byId", "data", "db" }) do
                        local sub = rawget(res, k)
                        if type(sub) == "table" and (type(sub[2]) == "table" or type(sub["2"]) == "table") then
                            ItemDB = sub
                            break
                        end
                    end
                    if next(ItemDB) == nil then ItemDB = res end
                end
                G.__ANCH_ItemDBCache = ItemDB
            end
        end
    end)
    return ItemDB
end
ResolveItemDB()

local InvModOk, InventoryModule = pcall(function() return Shared and require(Shared:FindFirstChild("Inventory")) end)
local NetOk, Net = pcall(function() return Shared and require(Shared:FindFirstChild("Net")) end)
local RolesOk, RolesModule = pcall(function() return Shared and require(Shared:FindFirstChild("Roles")) end)
local SfxOk, SfxModule = pcall(function() return Shared and require(Shared:FindFirstChild("Sfx")) end)
local SpliceOk, SpliceModule = pcall(function() return Shared and require(Shared:FindFirstChild("Splice")) end)

local GameGui = PlayerGui and (PlayerGui:FindFirstChild("GameGui") or PlayerGui:WaitForChild("GameGui", 2))
local ParticlesOk, ParticlesModule = pcall(function() return GameGui and require(GameGui:FindFirstChild("Particles")) end)
local MenuModOk, MenuModule = pcall(function() return GameGui and require(GameGui:FindFirstChild("WorldMenu")) end)
-- Fallback Module Fingerprinting (Tetap mendeteksi modul walau nama diacak saat update game)
do (function()
    if (NetOk and InvModOk and next(ItemDB) ~= nil) or type(getloadedmodules) ~= "function" then return end
    local okM, mods = pcall(getloadedmodules)
    if not okM or type(mods) ~= "table" then return end
    local function field(t, k) local ok, v = pcall(function() return t[k] end); return ok and v or nil end
    local function isFn(t, k) return type(field(t, k)) == "function" end
    for _, m in ipairs(mods) do
        local ok, v = pcall(require, m)
        if ok and type(v) == "table" then
            if not NetOk and isFn(v, "call") and type(field(v, "act")) == "table" and type(field(v, "tile")) == "table" then
                NetOk, Net = true, v
            elseif not RolesOk and isFn(v, "titlesOf") and isFn(v, "isModerator") then
                RolesOk, RolesModule = true, v
            elseif not SfxOk and isFn(v, "play") and isFn(v, "playAt") then
                SfxOk, SfxModule = true, v
            elseif not InvModOk and isFn(v, "room") and isFn(v, "count") and isFn(v, "add") then
                InvModOk, InventoryModule = true, v
            elseif not SpliceOk and isFn(v, "result") and field(v, "SETS") ~= nil then
                SpliceOk, SpliceModule = true, v
            elseif not MenuModOk and isFn(v, "isDown") and field(v, "KEYS") ~= nil then
                MenuModOk, MenuModule = true, v
            elseif not ParticlesOk and isFn(v, "spawn") and not isFn(v, "play") then
                ParticlesOk, ParticlesModule = true, v
            elseif next(ItemDB) == nil then
                local a = field(v, 2) or field(v, 1)
                if type(a) == "table" and type(field(a, "name")) == "string" and field(a, "hits") ~= nil then
                    ItemDB = v
                    G.__ANCH_ItemDBCache = v
                end
            end
        end
    end
end)() end
----------------------------------------------------------------------
-- CONFIG & STATE GLOBAL
----------------------------------------------------------------------
local CONFIG_FILE = "ANCHHub_GrowBlox.json"
local REJOIN_FILE = "ANCHHub_Rejoin_" .. tostring(Player.UserId) .. ".json"
local PABRIK_STATE_FILE = "ANCHHub_Pabrik_" .. tostring(Player.UserId) .. ".json"
local AUTOMOVE_STATE_FILE = "ANCHHub_AutoMove_" .. tostring(Player.UserId) .. ".json"
Session.ROTATION_STATE_FILE = "ANCHHub_Rotation_" .. tostring(Player.UserId) .. ".json"
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
    -- Fast Wrench Action (Fast Pull / Fast Kick / Fast Ban)
    fastPull = false,
    fastKick = false,
    fastBan = false,
    -- Fast Drop & Fast Recycle/Trash (0 = All)
    fastDrop = false,
    fastDropCount = 0,
    fastRecycle = false,
    fastRecycleCount = 0,
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
    visualAnim = true, -- Animasi ayunan tangan & efek partikel saat place/break
    liteMode = false,
    customWatermark = true,
    watermarkText = "ANCH HUB",
    selectedRole = "none",
    calibX = 0,
    calibY = 0,
    -- Auto Collect Global ("Legit" = fisik badan anti-tolak server | "Remote" = jarak jauh)
    collectMode = "Legit",
    collectAround = false,
    collectRadius = 3,
    -- Vending Machine
    vendMode = "Isi stock dari drop",
    vendPoint = "",
    vendDropX = -1,
    vendDropY = -1,
    vendItems = {},
    -- Auto Farm (+ Fast Break, Anti-Detect Dynamic Delay, Auto Refill & Auto Drop Seed)
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
    farmFastBreak = true,
    farmDynamicDelay = true,
    farmDynamicJitterMs = 45, -- Variasi acak +/- ms agar ritme tidak terdeteksi bot
    farmAutoRefill = false,
    farmRefillWorld = "",     -- Kosong = ambil di world ini | "WORLD" atau "WORLD:DOOR" = ambil di world lain
    farmAutoDropSeed = false,
    farmSeedDropAt = 200,
    farmSeedKeep = 0,
    farmDropWorld = "",
    farmDropX = -1,
    farmDropY = -1,
    -- Multi-World Rotation
    rotWorlds = "",           -- Contoh: "FARM1, FARM2:DOOR1, FARM3"
    rotSeedId = 3,
    rotLoop = true,
    rotBreakX = -1,
    rotBreakY = -1,
    rotDropExcess = false,
    rotKeepSeed = 100,
    rotSaveWorld = "",
    rotSaveX = -1,
    rotSaveY = -1,
    -- Auto Clear World
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
    harvestUseBlock = false, -- Default false agar tidak menaruh/merusak blok DF
    harvestScaffoldId = 2,
    harvestDelay = 0.22,
    harvestPlantDelay = 0.25,
    harvestTpDelay = 0.30,
    harvestTake = true,
    harvestModFly = false,
    harvestAutoSaveBlock = true, -- Auto simpan block saat >= 200
    harvestSaveWorld = "",       -- Kosong = simpan di world ini | "WORLD" / "WORLD:DOOR"
    harvestSaveX = -1,           -- Posisi X simpan block (-1 = ikut Pos Drop Factory/Farm)
    harvestSaveY = -1,           -- Posisi Y simpan block (-1 = ikut Pos Drop Factory/Farm)
    harvestAutoTakeSeed = true,  -- Auto ambil dropped seed di world saat seed tanam habis
    -- Auto Dirt Farm (DF Full World + Use Platform)
    dfBreakDelay = 0.15,
    dfTpDelay = 0.28,
    dfTake = true,
    dfModFly = true,
    dfReplacePlatform = true,
    dfUsePlatform = false,
    dfPlatformId = 102, -- Default: 102 (Wooden Platform)
    -- Helper: Fast Roulette
    fastRoulette = false,
    -- Auto Splice
    spliceA = 3,
    spliceB = 5,
    spliceRoam = true,
    spliceMs = 300,
    -- Pabrik (Factory - Sistem Max Seed)
    pabrikSeedId = 3,
    pabrikMaxSeed = 100, -- Batas maksimal seed yang ditanam & diputarkan di pabrik
    pabrikWholeWorld = true,
    pabrikTiles = { ["1,0"] = true },
    pabrikBreakX = -1,
    pabrikBreakY = -1,
    pabrikBreakSec = 120,
    pabrikDrop = true,
    pabrikDropWorld = "",
    pabrikDropX = -1,
    pabrikDropY = -1,
    -- Tas (Auto Recycle & Auto Convert Lock)
    trashOn = false,
    trashList = {},
    trashAt = 150,
    trashKeep = 0,
    convertLockOn = false,
    -- Navigasi / Pathfinding Universal
    moveMode = "legit",      -- "legit" = Legit Walking | "teleport" = Teleport Stepper
    moveMethod = "Legit Walking", -- "Legit Walking" | "Teleport Mode"
    navSpeed = 1,
    moveStepDelay = 0.28,
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
    -- Auto Move Item (World 1 -> World 2)
    moveWorld1 = "",
    moveWorld2 = "",
    moveDropX = -1,
    moveDropY = -1,
    moveItemId = 2,
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

local UIInitializing = true

local function SaveConfig()
    if UIInitializing then return end
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
local function Notify(message, title, duration, forceShow)
    if UIInitializing and not forceShow then return end
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

local Drops = { list = nil, update = nil, brokeAt = {}, seen = {}, nextTick = 0 }
local Anim = { fn = nil, idx = nil, set = nil, Particles = nil }
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

-- Input buatan untuk Legit Walking, Auto Collect & FlyPad (Hook langsung ke getgc + VirtualInputManager)
local AutoInput = { active = false, left = false, right = false, jump = false, down = false }
local FlyPadState = { up = false, down = false }
local OrigIsDown = G.__ANCH_TrueOrigIsDown
local SyncVimKeys, ReleaseInput

do (function()
    local VIM = cloneref(game:GetService("VirtualInputManager"))
    local vimState = { left = false, right = false, jump = false }

    local function SetVimKey(keyName, kc, down)
        if vimState[keyName] == down then return end
        vimState[keyName] = down
        pcall(function()
            if VIM and VIM.SendKeyEvent then
                VIM:SendKeyEvent(down, kc, false, game)
            end
        end)
    end

    SyncVimKeys = function()
        if not AutoInput.active then
            SetVimKey("left", Enum.KeyCode.A, false)
            SetVimKey("right", Enum.KeyCode.D, false)
            SetVimKey("jump", Enum.KeyCode.Space, false)
            return
        end
        SetVimKey("left", Enum.KeyCode.A, AutoInput.left == true)
        SetVimKey("right", Enum.KeyCode.D, AutoInput.right == true)
        SetVimKey("jump", Enum.KeyCode.Space, AutoInput.jump == true)
    end

    ReleaseInput = function()
        AutoInput.left, AutoInput.right, AutoInput.jump, AutoInput.down = false, false, false, false
        SetVimKey("left", Enum.KeyCode.A, false)
        SetVimKey("right", Enum.KeyCode.D, false)
        SetVimKey("jump", Enum.KeyCode.Space, false)
    end

    local function IsDownInterceptor(saved, key, ...)
        if alive() then
            if AutoInput.active then
                if key == "keyLeft" then return AutoInput.left end
                if key == "keyRight" then return AutoInput.right end
                if key == "keyJump" then return AutoInput.jump end
                if key == "keyDown" then return AutoInput.down end
            end
            if FlyPadState.up and key == "keyJump" then return true end
            if FlyPadState.down and key == "keyDown" then return true end
        end
        if OrigIsDown then
            return OrigIsDown(saved, key, ...)
        end
        return false
    end

    local function HookAllIsDownTables()
        if MenuModOk and type(MenuModule) == "table" and type(rawget(MenuModule, "isDown")) == "function" then
            local fn = rawget(MenuModule, "isDown")
            if not OrigIsDown and not (isexecutorclosure and pcall(isexecutorclosure, fn) and isexecutorclosure(fn)) then
                OrigIsDown = fn
                G.__ANCH_TrueOrigIsDown = fn
            end
            rawset(MenuModule, "isDown", IsDownInterceptor)
            return
        end
        if getgcFn then
            task.spawn(function()
                for _, v in ipairs(getgcFn(true)) do
                    if type(v) == "table" then
                        local fn = rawget(v, "isDown")
                        if type(fn) == "function" then
                            if not OrigIsDown and not (isexecutorclosure and pcall(isexecutorclosure, fn) and isexecutorclosure(fn)) then
                                OrigIsDown = fn
                                G.__ANCH_TrueOrigIsDown = fn
                            end
                            rawset(v, "isDown", IsDownInterceptor)
                        end
                    end
                end
            end)
        end
    end
    HookAllIsDownTables()
end)() end

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

    function Anim.isArmFn(fn)
        if not getconstsFn or (islclosure and not islclosure(fn)) then return false end
        local ok, consts = pcall(getconstsFn, fn)
        if not ok or type(consts) ~= "table" then return false end
        local a, b, c = false, false, false
        for _, k in pairs(consts) do
            if k == "forearm" then a = true
            elseif k == "heldReach" then b = true
            elseif k == "punchReach" then c = true end
        end
        return a and b and c
    end

    function Anim.bind(fn)
        if not (getupvalueFn and setupvalueFn) then return false end
        local vals, last = {}, 0
        for i = 1, 16 do
            local ok, v = pcall(getupvalueFn, fn, i)
            if not ok then break end
            vals[i] = v
            if v ~= nil then last = i end
        end
        for i = 1, last - 1 do
            local v = vals[i]
            if v == nil or (type(v) == "table" and rawget(v, "t") ~= nil and rawget(v, "facing") ~= nil) then
                Anim.fn, Anim.idx, Anim.set = fn, i, setupvalueFn
                return true
            end
        end
        return false
    end

    -- Cari World, Inv, dan fungsi Animasi langsung dari koneksi RunService (Tanpa getgc!)
    local function scanViaConnections()
        if not getconnections then return end
        local queue, seen, n = {}, {}, 0
        for _, sigName in ipairs({ "RenderStepped", "Heartbeat", "Stepped" }) do
            local okS, sig = pcall(function() return RunService[sigName] end)
            if okS and sig then
                local okC, conns = pcall(getconnections, sig)
                if okC and type(conns) == "table" then
                    for _, c in ipairs(conns) do
                        local okF, fn = pcall(function() return c.Function end)
                        if okF and type(fn) == "function" then
                            table.insert(queue, fn)
                        end
                    end
                end
            end
        end
        local i = 1
        while i <= #queue and n < 450 do
            local fn = queue[i]
            i = i + 1
            if not seen[fn] then
                seen[fn] = true
                n = n + 1
                if not Anim.fn and Anim.isArmFn(fn) then Anim.bind(fn) end
                for _, u in pairs(GetUpvalues(fn)) do
                    local tu = type(u)
                    if tu == "table" then
                        if not Refs.World then
                            local ok, valid = pcall(function()
                                return type(rawget(u, "fg")) == "table" and type(rawget(u, "bg")) == "table"
                                    and type(rawget(u, "w")) == "number" and rawget(u, "w") > 0
                                    and rawget(u, "spawn") ~= nil
                            end)
                            if ok and valid then Refs.World = u end
                        end
                        if not Refs.Inv and InvModOk and InventoryModule then
                            local ok, valid = pcall(function()
                                return getmetatable(u) == InventoryModule and type(rawget(u, "slots")) == "table"
                            end)
                            if ok and valid then Refs.Inv = u end
                        end
                        if not Refs.State then
                            local ok, valid = pcall(isStateHolder, u)
                            if ok and valid then Refs.State = rawget(u, "state") end
                        end
                    elseif tu == "function" and not seen[u] then
                        if not Anim.fn and Anim.isArmFn(u) then Anim.bind(u) end
                        table.insert(queue, u)
                    end
                end
            end
        end
    end

    -- Cari Tabel Pohon dari struktur World.tileChanged (tetap ketemu walau world kosong tanpa pohon)
    local function findTreesFromWorldStruct()
        local w = Refs.World
        if not w then return false end
        for _, fname in ipairs({ "tileChanged", "treeChanged", "setTree" }) do
            local root = rawget(w, fname)
            if type(root) == "function" then
                local ups = GetUpvalues(root)
                local tset = {}
                for _, u in pairs(ups) do
                    if type(u) == "table" and u ~= w then tset[u] = true end
                end
                for _, g in pairs(ups) do
                    if type(g) == "function" then
                        local gu = GetUpvalues(g)
                        local hasW, nT, shared = false, 0, {}
                        for _, v in pairs(gu) do
                            if rawequal(v, w) then
                                hasW = true
                            elseif type(v) == "table" then
                                nT = nT + 1
                                if tset[v] then table.insert(shared, v) end
                            end
                        end
                        if hasW and nT <= 3 and #shared == 1 then
                            Refs.Trees = shared[1]
                            return true
                        end
                    end
                end
            end
        end
        return false
    end

    local lastScanAt = 0
    function Refs.Scan(force)
        local now = os.clock()
        if not force and (now - lastScanAt) < 2.5 and Refs.World then
            return true
        end
        lastScanAt = now
        ResolveItemDB()
        Refs.World, Refs.Inv, Refs.InvTable, Refs.SetTile, Refs.Punch, Refs.State, Refs.Menu, Refs.Gems, Refs.Hud, Refs.Others =
            nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
        Refs.Particles = {}
        scanViaConnections()
        if getgcFn then
            for gi, v in ipairs(getgcFn(true)) do
                if gi % 3000 == 0 then task.wait() end -- Anti-freeze pada device saat scan memori
                local tv = type(v)
            if tv == "table" then
                if next(ItemDB) == nil or type(ItemDB[2]) ~= "table" then
                    local okDb, isDb = pcall(function()
                        local d2 = rawget(v, 2)
                        local d242 = rawget(v, 242)
                        return type(d2) == "table" and type(d242) == "table"
                            and (type(rawget(d2, "name")) == "string" or type(rawget(d2, "hits")) == "number")
                    end)
                    if okDb and isDb then ItemDB = v end
                end
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
    end

        if Refs.World and (not Refs.SetTile or not Refs.Punch) and debug and debug.info then
            for gi, fn in ipairs(getgcFn(true)) do
                if gi % 3000 == 0 then task.wait() end
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

        function Drops.findUpdate()
            local w, list = Refs.World, Drops.list
            local wd = w and rawget(w, "dropTaken")
            if type(wd) ~= "function" or not list then return false end
            for _, u in pairs(GetUpvalues(wd)) do
                if type(u) == "function" then
                    for _, uu in pairs(GetUpvalues(u)) do
                        if rawequal(uu, list) then
                            Drops.update = u
                            return true
                        end
                    end
                end
            end
            return false
        end

        function Drops.findRefs()
            local w0 = Refs.World
            local dl = w0 and rawget(w0, "dropList")
            if type(dl) == "function" then
                local okL, l = pcall(dl)
                if okL and isDropList(l) then
                    if Drops.list ~= l then Drops.update = nil end
                    Drops.list = l
                    if not Drops.update then Drops.findUpdate() end
                    return true
                end
            end
            Drops.list, Drops.update = nil, nil
            local wd = w0 and rawget(w0, "dropTaken")
            if type(wd) == "function" then
                for _, u in pairs(GetUpvalues(wd)) do
                    if not Drops.list and isDropList(u) then
                        Drops.list = u
                    elseif not Drops.update and type(u) == "function" then
                        Drops.update = u
                    end
                end
                if Drops.list and not Drops.update then Drops.findUpdate() end
            end
            local evDrop = WorldRemotes and WorldRemotes:FindFirstChild("DropTaken")
            if not Drops.list and evDrop and getconnections then
                local okC, conns = pcall(getconnections, evDrop.OnClientEvent)
                if okC and type(conns) == "table" then
                    for _, c in ipairs(conns) do
                        local okF, fn = pcall(function() return c.Function end)
                        if okF and type(fn) == "function" then
                            for _, u in pairs(GetUpvalues(fn)) do
                                if not Drops.list and isDropList(u) then
                                    Drops.list = u
                                elseif not Drops.update and type(u) == "function" then
                                    Drops.update = u
                                end
                            end
                        end
                        if Drops.list then break end
                    end
                end
            end
            return Drops.list ~= nil
        end

        Drops.findRefs()

        Refs.Trees = nil
        if not Refs.Trees then findTreesFromWorldStruct() end
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

local function GetItemEntry(id)
    if not id then return nil end
    if next(ItemDB) == nil then ResolveItemDB() end
    local num = tonumber(id)
    local it = (num and (rawget(ItemDB, num) or ItemDB[num])) or rawget(ItemDB, tostring(id)) or ItemDB[tostring(id)]
    if type(it) == "table" then return it end
    if type(ItemDB.get) == "function" then
        local ok, res = pcall(ItemDB.get, num or id)
        if ok and type(res) == "table" then return res end
    end
    return nil
end

local function ItemName(id)
    local it = GetItemEntry(id)
    if type(it) == "table" then
        local nm = rawget(it, "name") or it.name or rawget(it, "title") or rawget(it, "itemName") or rawget(it, 1)
        if type(nm) == "string" and nm ~= "" then
            return nm
        end
    end
    return "Item #" .. tostring(id)
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
    blockId = tonumber(blockId)
    if not blockId then return nil end
    local it = GetItemEntry(blockId)
    if it and (it.kind == "seed" or type(it.tree) == "table" or type(it.grow) == "number") then
        return blockId
    end
    local sid = (it and tonumber(it.seedId)) or (blockId + 1)
    local sit = GetItemEntry(sid)
    if sit and (sit.kind == "seed" or type(sit.tree) == "table" or type(sit.grow) == "number") then
        return sid
    end
    return blockId + 1
end

local function BlockOfSeed(seedId)
    seedId = tonumber(seedId)
    if not seedId then return nil end
    local sit = GetItemEntry(seedId)
    if sit and sit.kind ~= "seed" and type(sit.tree) ~= "table" and type(sit.grow) ~= "number" then
        return seedId
    end
    local bid = (sit and tonumber(sit.blockId)) or (seedId - 1)
    local bit = GetItemEntry(bid)
    if bit and bit.kind ~= "seed" then
        return bid
    end
    return seedId - 1
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

local function GetGuiCameraState()
    local gg = PlayerGui:FindFirstChild("GameGui")
    local worldGui = gg and gg:FindFirstChild("World")
    local cam = worldGui and worldGui:FindFirstChild("Camera")
    local tiles = cam and cam:FindFirstChild("Tiles")
    local pv = cam and cam:FindFirstChild("PlayerView")
    if not (tiles and pv and tiles:IsA("GuiObject") and pv:IsA("GuiObject")) then return nil end
    local sample = tiles:FindFirstChildWhichIsA("ImageLabel")
    local ts = (sample and sample.AbsoluteSize.X > 0) and sample.AbsoluteSize.X or 64
    local center = pv.AbsolutePosition + (pv.AbsoluteSize / 2)
    local rel = center - tiles.AbsolutePosition
    return {
        x = rel.X / ts,
        y = (rel.Y / ts) + 0.475,
        vx = 0, vy = 0, facing = 1, grounded = true, dead = false, active = true,
    }
end

local function PlayerPhysicsState()
    if not Refs.State then Refs.Scan() end
    if Refs.State then
        local ok, s = pcall(Refs.State)
        if ok and type(s) == "table" and type(s.x) == "number" and type(s.y) == "number" and s.active ~= false then
            return s
        end
    end
    return GetGuiCameraState()
end

local function GetGridState()
    local s = PlayerPhysicsState()
    if s then
        return s.x + Config.calibX, s.y + Config.calibY, (s.facing and s.facing < 0) and -1 or 1
    end
    return nil, "Karakter belum berada di world"
end

function Anim.Swing(x, y, kind)
    if not Config.visualAnim or not (Anim.fn and Anim.idx and Anim.set) then return end
    local s = PlayerPhysicsState()
    local facing = (s and x + 0.5 < s.x) and -1 or 1
    pcall(Anim.set, Anim.fn, Anim.idx, { t = os.clock(), x = x + 0.5, y = y + 0.5, facing = facing, kind = kind })
end

function Anim.Place(x, y, id)
    if not Config.visualAnim then return end
    Anim.Swing(x, y, "build")
    local it = ItemDB[id]
    if it and it.kind ~= "seed" and Refs.Particles and #Refs.Particles > 0 then
        local pick = Anim.Particles or Refs.Particles[1]
        Anim.Particles = pick
        pcall(function() pick:place(x + 0.5, y + 0.5) end)
    end
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
    if id ~= 0 and Anim.Place then Anim.Place(x, y, id) end
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

-- Whitelist Permanen: ID Bedrock, Pintu Utama, dan Seluruh Jenis Lock
local UNBREAKABLE_IDS = {
    [6]    = true, -- Main Door
    [8]    = true, -- Bedrock
    [202]  = true, -- Small Lock
    [204]  = true, -- Big Lock
    [206]  = true, -- Huge Lock
    [242]  = true, -- World Lock
    [1796] = true, -- Diamond Lock
    [4994] = true, -- Builder's Lock
    [5814] = true, -- Guild Lock
    [7188] = true, -- Blue Gem Lock
}

local function CanBreakId(id, x, y)
    if not id or id == 0 or UNBREAKABLE_IDS[id] then return false end

    local w = FindWorld()
    if w and x and y then
        if typeof(w.spawn) == "Vector2" and x == math.floor(w.spawn.X) and y == math.floor(w.spawn.Y) then
            return false
        end
        if type(w.lock) == "table" and w.lock.x == x and w.lock.y == y then
            return false
        end
    end

    local it = GetItemEntry(id)
    if not it then
        -- Jika ItemDB belum terbaca dan blok berada di dasar world (baris bedrock), jangan pernah di-break!
        if w and y and y >= w.h - 6 then return false end
        return true
    end

    if it.lock or it.area or it.guildLock or it.vend or it.display or it.bedrock or it.unbreakable or it.door or it.entrance then
        return false
    end

    local name = tostring(rawget(it, "name") or it.name or ""):lower()
    if name:find("bedrock", 1, true)
        or name:find("lock", 1, true)
        or name:find("main door", 1, true)
        or name:find("white door", 1, true)
        or name:find("vending", 1, true) then
        return false
    end

    local h = (it.kind == "seed") and 20 or it.hits
    if type(h) == "number" then
        return h > 0
    end
    if it.staffHits then return false end
    return true
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
    if not layer or not CanBreakId(id, x, y) then return nil end

    WaitPlaceGuard(x, y)

    if not Refs.Punch then Refs.Scan() end
    if Refs.Punch then
        local ok = pcall(Refs.Punch, x, y, Config.mutePunch or nil, nil)
        if not ok then return nil end
        Anim.Swing(x, y, "punch")
        if TileValue(w, layer, x, y) ~= id then
            Stats.Broken += 1
            Drops.brokeAt[x .. "," .. y] = os.clock()
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
    if Drops.collecting then
        w.speedScale = 1
    elseif Config.walkSpeed ~= 100 then
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
        local id = fgIdAt(x, y)
        if id == 0 then return false end
        if id == 4 or id == 410 then return true end -- ID Lava standar
        local it = ItemDB[id]
        if not it then return false end
        if it.deadly or it.hurts or it.laser or it.bounce or it.bouncer then return true end
        local nm = tostring(rawget(it, "name") or it.name or ""):lower()
        if nm:find("lava", 1, true)
            or nm:find("spike", 1, true)
            or nm:find("magma", 1, true)
            or nm:find("acid", 1, true)
            or nm:find("fire", 1, true)
            or nm:find("pinball", 1, true)
            or nm:find("trampoline", 1, true) then
            return true
        end
        return false
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

    Nav.HazardAt = hazardAt

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

    -- Cek apakah target tidak terhalang blok lantai/atap di antaranya
    function Nav.Los(nx, ny, tx, ty)
        if ty - ny >= 2 then
            for y = ny + 1, ty - 1 do
                if solidAt(tx, y) then return false end
            end
        elseif ny - ty >= 2 then
            for y = ty + 1, ny - 1 do
                if solidAt(tx, y) then return false end
            end
        end
        return true
    end

    -- Lepaskan karakter jika nyangkut di udara / pinggir blok > 3 detik
    function Nav.AirCheck(s)
        if not s or s.grounded then
            Nav.AirAt = nil
            return
        end
        if not Nav.AirAt then
            Nav.AirAt = os.clock()
        elseif os.clock() - Nav.AirAt > 3 then
            Nav.AirAt = nil
            local right = (s.facing or 1) < 0
            AutoInput.active = true
            AutoInput.right, AutoInput.left = right, not right
            task.wait(0.2)
            AutoInput.right, AutoInput.left = false, false
        end
    end

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
                -- Tangga lahan/DF: naik 1-2 tile ke lorong setinggi 1 tile (atap langsung di atas kepala)
                for dy = 1, 2 do
                    if open(x, y - 1) and (dy == 1 or open(x, y - 2)) and open(ax, y - dy) and sup(ax, y - dy)
                        and not (open(x, y - dy - 1) and open(ax, y - dy - 1)) then
                        add(ax, y - dy, "stair", 3 + 1.5 * dy, false)
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

    local function execStair(e, cancel)
        if not execWalk(e.fx, e.fy, cancel) then return false end
        AutoInput.active = true
        local dir = (e.x > e.fx) and 1 or -1
        local top = e.y + 1
        local hug = e.fx + 0.5 + dir * 0.17
        for try = 1, 3 do
            local t0 = os.clock()
            while os.clock() - t0 <= 0.8 and alive() do
                if cancel and cancel() then ReleaseInput(); return false end
                local s = PlayerPhysicsState()
                if not s or s.dead then ReleaseInput(); return false end
                steerX(s, hug, 0.03)
                if abs(s.x - hug) <= 0.06 and abs(s.vx or 0) < 1 then break end
                task.wait()
            end
            ReleaseInput()
            task.wait()
            local s0 = PlayerPhysicsState()
            if not s0 then return false end
            local y0 = s0.y
            AutoInput.jump = true
            t0 = os.clock()
            local airborne, landed = false, nil
            while os.clock() - t0 <= 1.8 and alive() do
                if cancel and cancel() then ReleaseInput(); return false end
                local s = PlayerPhysicsState()
                if not s or s.dead then ReleaseInput(); return false end
                if not s.grounded then airborne = true end
                if AutoInput.jump and (s.y <= top - 0.1 or (airborne and (s.vy or 0) >= 0)) then
                    AutoInput.jump = false
                end
                local press = (try == 1 and s.y <= top + 0.02)
                    or (try == 2 and s.y <= y0 - 0.15)
                    or (try == 3 and s.y <= top + 0.25)
                if airborne and press then
                    AutoInput.right, AutoInput.left = dir > 0, dir < 0
                else
                    steerX(s, hug, 0.03)
                end
                if airborne and s.grounded then
                    landed = floor(s.y - 0.475)
                    break
                end
                if not airborne and os.clock() - t0 > 0.35 then break end
                task.wait()
            end
            ReleaseInput()
            if landed == e.y then
                return execWalk(e.x, e.y, cancel)
            end
            if landed ~= nil and landed ~= e.fy then return false end
            if not execWalk(e.fx, e.fy, cancel) then return false end
        end
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
            elseif e.kind == "stair" then
                ok = execStair(e, cancel)
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

    -- FUNGSI MEMANJAT VERTIKAL ANTI-STUCK & 100% BERSIH PIJAKAN
    function Nav.ClimbUpWithDirt(x, targetY, cancel, cleanBehind, stepDelayOverride, allowBreakOverhead)
        local world = FindWorld()
        if not world then return false end
        if cleanBehind == nil then cleanBehind = true end
        if allowBreakOverhead == nil then allowBreakOverhead = false end
        local settleDelay = math.max(0.24, tonumber(stepDelayOverride) or tonumber(Config.moveStepDelay) or 0.28)

        local savedLocks = {}
        for k, v in pairs(autoFlyLocks) do savedLocks[k] = v end
        table.clear(autoFlyLocks)
        local wasNoclip = noclipOn
        local wasCollecting = Drops.collecting
        noclipOn = false
        Drops.collecting = true -- Kunci speedScale = 1 agar lompatan pilar vertikal presisi di tengah tile
        world.speedScale = 1
        SyncGhostState()
        AutoInput.active = true
        ReleaseInput()

        local tempPlaced = {}

        -- Fungsi pembersih pijakan yang sudah berada >= 2 tile di bawah posisi karakter
        local function breakPlacedBelow(limitY)
            if not cleanBehind then return end
            local sortedY = {}
            for py in pairs(tempPlaced) do
                if py >= limitY then
                    table.insert(sortedY, py)
                end
            end
            table.sort(sortedY, function(a, b) return a > b end) -- Hancurkan dari yang paling bawah dulu
            for _, py in ipairs(sortedY) do
                if cancel and cancel() then return end
                local curFg = fgIdAt(x, py)
                if curFg ~= 0 and CanBreakId(curFg, x, py) then
                    WaitPlaceGuard(x, py)
                    local t0 = os.clock()
                    while fgIdAt(x, py) ~= 0 and (os.clock() - t0) < 3.5 and alive() do
                        if cancel and cancel() then break end
                        local s = PlayerPhysicsState()
                        -- Jika pijakan terlalu jauh di bawah (> 2.4 tile), turun sedikit dengan ghost agar terjangkau
                        if s and math.abs((py + 0.5) - (s.y - 0.475)) > PunchReach() - 0.1 then
                            world.ghost = true
                            pcall(world.goTo, x, math.max(0, py - 2))
                            task.wait(0.06)
                        end
                        TryBreakOnce(x, py, false)
                        task.wait(0.14)
                    end
                end
                if fgIdAt(x, py) == 0 then
                    tempPlaced[py] = nil
                end
            end
        end

        -- Fungsi pembersih seluruh sisa pijakan di akhir panjatan (menggunakan hover ModFly singkat agar pijakan tepat di bawah kaki ikut hancur)
        local function cleanupAllRemainingScaffolds()
            if not cleanBehind or next(tempPlaced) == nil then return end

            -- 1. Coba geser 1 langkah ke samping jika ada lantai padat di sebelahnya
            local sideCandidates = (x <= 2) and { x + 1, x + 2 }
                or ((x >= world.w - 3) and { x - 1, x - 2 } or { x + 1, x - 1 })
            for _, sx in ipairs(sideCandidates) do
                if InBounds(world, sx, targetY) and openAt(sx, targetY) and realSupport(sx, targetY) then
                    execWalk(sx, targetY, cancel)
                    task.wait(0.12)
                    break
                end
            end

            -- 2. Aktifkan ghost (hover) sementara agar meskipun tidak ada pijakan samping (misal di x=99),
            --    karakter tetap mengambang di (x, targetY) dan bisa menghancurkan blok pijakan terakhir di bawah kakinya!
            world.ghost = true
            local sortedY = {}
            for py in pairs(tempPlaced) do table.insert(sortedY, py) end
            table.sort(sortedY)

            for _, py in ipairs(sortedY) do
                if cancel and cancel() then break end
                if fgIdAt(x, py) ~= 0 and CanBreakId(fgIdAt(x, py), x, py) then
                    local standY = math.max(0, py - 1)
                    local cx, cy = GetTile()
                    if cx and cy and (math.abs(cx - x) > 2 or math.abs(cy - py) > 2) then
                        world.ghost = true
                        pcall(world.goTo, x, standY)
                        task.wait(0.08)
                    end
                    WaitPlaceGuard(x, py)
                    local t0 = os.clock()
                    while fgIdAt(x, py) ~= 0 and (os.clock() - t0) < 3.5 and alive() do
                        if cancel and cancel() then break end
                        world.ghost = true
                        TryBreakOnce(x, py, false)
                        task.wait(0.14)
                    end
                end
                if fgIdAt(x, py) == 0 then
                    tempPlaced[py] = nil
                end
            end
        end

        local function restore(result)
            pcall(cleanupAllRemainingScaffolds)
            ReleaseInput()
            AutoInput.active = false
            Drops.collecting = wasCollecting
            if Config.walkSpeed ~= 100 and Refs.World and not wasCollecting then
                Refs.World.speedScale = Config.walkSpeed / 100
            end
            noclipOn = wasNoclip
            for k, v in pairs(savedLocks) do autoFlyLocks[k] = v end
            SyncGhostState()
            return result
        end

        local cx, cy = GetTile()
        if not cx then return restore(false) end

        if cx ~= x then
            if not execWalk(x, cy, cancel) then
                pcall(world.goTo, x, cy)
                task.wait(settleDelay)
            end
            cx, cy = GetTile()
            if not cx then return restore(false) end
        end

        local scaffoldBlock = activeScaffoldId()

        if InBounds(world, x, cy + 1) and not realSupport(x, cy) then
            if fgIdAt(x, cy + 1) == 0 and placeScaffold(x, cy + 1) then
                tempPlaced[cy + 1] = scaffoldBlock
                task.wait(PLACE_GUARD)
            end
        end

        local stuckTries = 0
        while cy > targetY and alive() do
            if cancel and cancel() then return restore(false) end
            local nextY = cy - 1

            -- Jika di atas kepala ada blok dan tidak diizinkan menghancurkan (misal di Pabrik/Farmer), batalkan panjat
            if not allowBreakOverhead and fgIdAt(x, nextY) ~= 0 and solidAt(x, nextY) then
                return restore(false)
            end

            if allowBreakOverhead then
                for checkY = nextY, math.max(0, nextY - 2), -1 do
                    local fgUp = fgIdAt(x, checkY)
                    if fgUp ~= 0 and CanBreakId(fgUp, x, checkY) then
                        local t0 = os.clock()
                        while fgIdAt(x, checkY) ~= 0 and (os.clock() - t0) < 4 and alive() do
                            if cancel and cancel() then return restore(false) end
                            TryBreakOnce(x, checkY, false)
                            task.wait(0.15)
                        end
                    end
                end
            end

            -- Pusatkan posisi X di tengah tile (x + 0.5) sebelum melompat pilar
            if Drops.walkToX then
                Drops.walkToX(x + 0.5, 0.6)
            end

            local beforeY = cy
            local wasEmptyAtCy = (fgIdAt(x, cy) == 0)
            local okPillar = execPillar({ fx = x, fy = cy, x = x, y = nextY }, cancel)

            -- Catat ke tempPlaced jika blok di (x, cy) berubah menjadi terisi (walaupun execPillar return false!)
            if okPillar or (wasEmptyAtCy and fgIdAt(x, cy) ~= 0) then
                tempPlaced[cy] = scaffoldBlock
            elseif fgIdAt(x, cy) == 0 then
                if placeScaffold(x, cy) then
                    tempPlaced[cy] = scaffoldBlock
                end
                task.wait(0.14)
                pcall(world.goTo, x, nextY)
            end

            task.wait(math.max(PLACE_GUARD, settleDelay))

            local _, nowY = GetTile()
            if nowY and nowY < beforeY then
                cy = nowY
                stuckTries = 0
            else
                -- Jika blok sudah terpasang di (x, beforeY) tapi badan nyangkut di sampingnya, naikkan ke atas blok tersebut
                if fgIdAt(x, beforeY) ~= 0 and openAt(x, nextY) then
                    pcall(world.goTo, x, nextY)
                    task.wait(0.18)
                    _, nowY = GetTile()
                end
                if nowY and nowY < beforeY then
                    cy = nowY
                    stuckTries = 0
                else
                    stuckTries = stuckTries + 1
                    if stuckTries >= 3 then
                        return restore(false)
                    end
                end
            end

            -- Segera hancurkan semua pijakan yang sudah berada >= 2 tile di bawah posisi karakter sekarang
            breakPlacedBelow(cy + 2)
        end

        return restore(true)
    end

    -- Router BFS Udara: Mencari jalur tile kosong (tanpa menabrak blok) agar tidak pernah stuck/rollback
    local function FindOpenAirPath(w, sx, sy, tx, ty)
        local W, H = w.w, w.h
        local startKey = sy * W + sx
        local goalKey = ty * W + tx
        if startKey == goalKey then return {} end

        local queue = { startKey }
        local cameFrom = { [startKey] = -1 }
        local qHead = 1
        local dirs = { { 0, -1 }, { 1, 0 }, { -1, 0 }, { 0, 1 } } -- Prioritaskan naik ke udara terbuka dulu

        while qHead <= #queue and qHead <= 3500 do
            local cur = queue[qHead]
            qHead = qHead + 1
            if cur == goalKey then
                local path = {}
                local step = cur
                while step ~= startKey do
                    table.insert(path, 1, { x = step % W, y = math.floor(step / W) })
                    step = cameFrom[step]
                end
                return path
            end
            local cx, cy = cur % W, math.floor(cur / W)
            for _, d in ipairs(dirs) do
                local nx, ny = cx + d[1], cy + d[2]
                if nx >= 0 and nx < W and ny >= 0 and ny < H then
                    local nKey = ny * W + nx
                    if cameFrom[nKey] == nil and (nKey == goalKey or openAt(nx, ny)) then
                        cameFrom[nKey] = cur
                        table.insert(queue, nKey)
                    end
                end
            end
        end
        return nil
    end

    function Nav.FlyTo(tx, ty, cancel, stepDelayOverride, allowThroughBlocks)
        local w = FindWorld()
        if not w or type(w.goTo) ~= "function" then return false end
        local stepDelay = math.max(0.16, tonumber(stepDelayOverride) or tonumber(Config.moveStepDelay) or 0.22)

        for attempt = 1, 3 do
            if cancel and cancel() then return false end
            local cx, cy = GetTile()
            if not cx then return false end
            if cx == tx and cy == ty then return true end

            w.ghost = true

            -- 1. Coba ikuti jalur udara terbuka (BFS) agar tidak memaksa menembus blok solid
            local bfsPath = FindOpenAirPath(w, cx, cy, tx, ty)
            if bfsPath and #bfsPath > 0 then
                local stuck = false
                for _, node in ipairs(bfsPath) do
                    if cancel and cancel() then return false end
                    w.ghost = true
                    pcall(w.goTo, node.x, node.y)
                    task.wait(stepDelay)
                    local rx, ry = GetTile()
                    if not rx or (math.abs(rx - node.x) > 2 or math.abs(ry - node.y) > 2) then
                        stuck = true
                        break
                    end
                end
                local fx, fy = GetTile()
                if not stuck and fx == tx and fy == ty then
                    return true
                end
            end

            -- 2. Fallback: Naik dulu ke baris udara terbuka (Y kecil), geser X, baru turun ke Y tujuan
            local failCount = 0
            local maxLoops = 160
            while (cx ~= tx or cy ~= ty) and maxLoops > 0 and alive() do
                maxLoops = maxLoops - 1
                if cancel and cancel() then return false end
                w.ghost = true

                local rx, ry = GetTile()
                if not rx then return false end
                cx, cy = rx, ry
                if cx == tx and cy == ty then return true end

                local stepX = (tx > cx and 1) or (tx < cx and -1) or 0
                local stepY = (ty > cy and 1) or (ty < cy and -1) or 0
                local nx, ny = cx, cy

                -- Jangan melangkah diagonal jika terhalang blok; dahulukan sumbu yang terbuka
                if stepY < 0 and openAt(cx, cy - 1) then
                    nx, ny = cx, cy - 1
                elseif stepX ~= 0 and openAt(cx + stepX, cy) then
                    nx, ny = cx + stepX, cy
                elseif stepY ~= 0 and openAt(cx, cy + stepY) then
                    nx, ny = cx, cy + stepY
                elseif cy > 0 and openAt(cx, cy - 1) then
                    nx, ny = cx, cy - 1 -- Naik 1 tile ke atas untuk melewati gundukan blok
                elseif allowThroughBlocks then
                    nx, ny = cx + stepX, cy + stepY
                else
                    break
                end

                pcall(w.goTo, nx, ny)
                task.wait(stepDelay)

                local ax, ay = GetTile()
                if ax == cx and ay == cy then
                    failCount = failCount + 1
                    if failCount >= 3 then break end
                else
                    failCount = 0
                end
            end

            local fx, fy = GetTile()
            if fx == tx and fy == ty then return true end
        end
        return false
    end

    -- LEGIT WALKING DENGAN REAL-TIME POSITION CHECK & 3X RE-PATHFIND OTOMATIS
    function Nav.LegitTo(tx, ty, cancel, reachRadius, allowScaffold)
        local started = os.clock()
        local w = FindWorld()
        if not w then return false, "world" end
        if allowScaffold == nil then allowScaffold = false end
        local R = reachRadius or 0.4

        -- Lakukan hingga 3x percobaan pencarian rute ulang (Re-pathfind) jika di tengah jalan nyangkut/rollback
        for attempt = 1, 3 do
            if cancel and cancel() then return false, "cancel" end
            local sx, sy = GetTile()
            if not sx then return false, "pos" end
            if sx == tx and sy == ty then return true, os.clock() - started end
            local sNow = PlayerPhysicsState()
            if sNow and R >= 1 and stateReaches(sNow, tx, ty, R) then
                return true, os.clock() - started
            end

            local goals = { [ty * w.w + tx] = true }
            local path = Nav.AStar(sx, sy, goals, tx, ty, R, allowScaffold, cancel)
            if path and #path > 0 then
                if Nav.FollowPath(path, cancel) then
                    local fx, fy = GetTile()
                    local sEnd = PlayerPhysicsState()
                    if (fx == tx and fy == ty) or (sEnd and stateReaches(sEnd, tx, ty, R + 0.35)) then
                        return true, os.clock() - started
                    end
                end
            else
                -- Jika A* tidak menemukan jalan karena target di lantai berbeda pada DF, lewat tangga ujung kiri/kanan (x=1 atau x=W-2)
                if sy ~= ty then
                    local stairX = (math.abs(sx - 1) <= math.abs(sx - (w.w - 2))) and 1 or (w.w - 2)
                    local stairGoals = { [ty * w.w + stairX] = true }
                    local stairPath = Nav.AStar(sx, sy, stairGoals, stairX, ty, 0.5, allowScaffold, cancel)
                    if stairPath and #stairPath > 0 then
                        Nav.FollowPath(stairPath, cancel)
                    end
                end
            end
            task.wait(0.15)
        end

        return false, "nopath"
    end

    function Nav.StepGoTo(tx, ty, cancel, flyMode)
        local ok = Nav.FlyTo(tx, ty, cancel, Config.moveStepDelay, flyMode == true)
        SyncGhostState()
        return ok, ok and 0 or "stuck"
    end

    -- FUNGSI GERAK UTAMA: Jika Legit Walking dipilih, 100% murni jalan fisik A* TANPA Noclip/Ghost!
    function Nav.Go(tx, ty, cancel, reachRadius, allowScaffold)
        local isTeleport = (Config.moveMethod == "Teleport Mode") or (Config.moveMode == "fly") or (Config.moveMode == "teleport")
        if not isTeleport then
            -- Matikan semua ghost/noclip agar server tidak melakukan rollback/kick
            local w = FindWorld()
            if w and not noclipOn then w.ghost = false end
            local ok, info = Nav.LegitTo(tx, ty, cancel, reachRadius, allowScaffold)
            return ok, info
        end
        return Nav.StepGoTo(tx, ty, cancel, false)
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

local QueueReload
local function WarpToWorld(worldName)
    worldName = Trim(worldName):upper()
    if worldName == "" then
        Notify("Nama world tidak boleh kosong!")
        return false
    end
    Config.lastWorld = worldName
    SaveConfig()
    if QueueReload then pcall(QueueReload) end
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
local AutoMove = {
    on = false,
    token = 0,
    phase = "-",
    status = "Mati",
    collected = 0,
    dropped = 0,
    traveling = false,
    pauseCollect = false,
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
-- FAST AUTO-COLLECT DUAL MODE ("Legit" Badan Fisik & "Remote")
----------------------------------------------------------------------
do (function()
    local function inTile(t, x, y)
        return x >= t.x - 0.15 and x < t.x + 1.15 and y >= t.y - 0.15 and y < t.y + 1.15
    end

    local function canTryDrop(d, now)
        if type(d) ~= "table" or d.taking or d.pending or d.display or (d.n or 0) <= 0 or type(d.x) ~= "number" then
            return false
        end
        if d.armed == false and d.id ~= 112 then return false end
        local fail = d.uid and DropFailUntil[d.uid]
        return not (fail and now < fail)
    end

    function Drops.applyTaken(d, left)
        local list = Drops.list
        if not list or not table.find(list, d) then return end
        if not Drops.update and Drops.findUpdate then Drops.findUpdate() end
        if Drops.update then
            local ok = pcall(Drops.update, d, left)
            if ok then
                if left > 0 then
                    d.flown = nil
                    if typeof(d.frame) == "Instance" then pcall(function() d.frame.Visible = not d.culled end) end
                end
                return
            end
        end
        d.n = left
        if left > 0 then
            d.flown = nil
            if typeof(d.frame) == "Instance" then pcall(function() d.frame.Visible = not d.culled end) end
        else
            local i = table.find(list, d)
            if i then table.remove(list, i) end
            if typeof(d.frame) == "Instance" then pcall(function() d.frame:Destroy() end) end
        end
    end

    -- Tunggu sampai drop yang menempel di badan selesai dipungut oleh fisika game
    function Drops.waitNearDrops(maxSec)
        local list = Drops.list
        if not list then return end
        task.wait(0.15)
        local t0 = os.clock()
        while os.clock() - t0 < (maxSec or 0.45) and alive() do
            local s = PlayerPhysicsState()
            if not s or not s.x then return end
            local busy = false
            for _, d in ipairs(list) do
                if type(d) == "table" and type(d.x) == "number" and (d.n or 0) > 0 and d.armed ~= false
                    and math.abs(d.x - s.x) < 0.6 and d.y + 0.3 > s.y - 0.95 and d.y - 0.3 < s.y then
                    local room = true
                    if d.id ~= 112 and Refs.Inv and type(Refs.Inv.room) == "function" then
                        local okr, r = pcall(function() return Refs.Inv:room(d.id) end)
                        if okr and type(r) == "number" and r <= 0 then room = false end
                    end
                    if room then busy = true; break end
                end
            end
            if not busy then return end
            task.wait()
        end
    end

    -- Tunggu drop baru dari blok yang barusan pecah muncul dari server (sesuai ping)
    function Drops.waitSpawn(tiles)
        if not Drops.list and Drops.findRefs then Drops.findRefs() end
        local ping = 0.1
        pcall(function() ping = Player:GetNetworkPing() end)
        local limit = math.clamp(0.15 + 2.5 * ping, 0.25, 0.85)
        local newest = nil
        for _, t in ipairs(tiles) do
            local b = Drops.brokeAt[t.x .. "," .. t.y]
            if b and os.clock() - b < limit and (not newest or b > newest) then newest = b end
        end
        if not newest then return end
        local list = Drops.list
        while os.clock() - newest < limit and alive() do
            if list then
                for _, d in ipairs(list) do
                    if type(d) == "table" and type(d.x) == "number" and (d.born or 0) >= newest - 0.2 then
                        for _, t in ipairs(tiles) do
                            if inTile(t, d.x, d.y) then
                                task.wait(0.05)
                                return
                            end
                        end
                    end
                end
            end
            task.wait()
        end
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
        if typeof(d.frame) == "Instance" then pcall(function() d.frame.Visible = false end) end

        local ok, taken
        if type(worldTake) == "function" then
            ok, taken = pcall(worldTake, d.uid, amount)
        else
            ok, taken = pcall(TakeDropRemote.InvokeServer, TakeDropRemote, d.uid, amount)
        end

        d.taking = false

        if not (ok and type(taken) == "number" and taken > 0) then
            Farm.stats.fail = Farm.stats.fail + 1
            d.refused = os.clock()
            d.failN = (d.failN or 0) + 1
            if d.uid then DropFailUntil[d.uid] = os.clock() + math.min(8, d.failN) end
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

        Drops.applyTaken(d, math.max(0, (d.n or 0) - taken))

        Stats.Collected = Stats.Collected + taken
        Stats.Items[d.id] = (Stats.Items[d.id] or 0) + taken
        Farm.stats.picked = Farm.stats.picked + taken
        if Clear.on then Clear.stats.picked = Clear.stats.picked + taken end
        if Farmer.on then Farmer.stats.picked = Farmer.stats.picked + taken end
        if DF.on then DF.stats.picked = DF.stats.picked + taken end
        return true
    end

    -- Jalan fisik presisi dengan pengereman (braking) agar TIDAK tergelincir/overshoot & tidak bolak-balik
    function Drops.walkToX(targetCenterX, maxSec)
        local s0 = PlayerPhysicsState()
        if not s0 or s0.dead then return false end
        if math.abs(targetCenterX - s0.x) <= 0.18 and math.abs(s0.vx or 0) < 2.0 then
            ReleaseInput()
            return true
        end

        AutoInput.active = true
        local tol = 0.14
        local t0 = os.clock()

        while alive() and (Farm.on or Farm.Override ~= nil or Farmer.on or Pabrik.on or Pabrik.traveling or AutoMove.on) and (os.clock() - t0) < (maxSec or 1.6) do
            local s = PlayerPhysicsState()
            if not s or s.dead then break end

            local dx = targetCenterX - s.x
            local vx = s.vx or 0
            local decel = s.grounded and 48 or 17
            local dir = 0

            if math.abs(dx) > tol then
                dir = (dx > 0) and 1 or -1
                -- Pengereman: lepas tombol sebelum sampai jika laju karakter sudah cukup untuk meluncur ke target
                if vx * dir > 0 and (vx * vx) / (2 * decel) >= math.abs(dx) - tol * 0.5 then
                    dir = 0
                end
            end

            AutoInput.left = (dir < 0)
            AutoInput.right = (dir > 0)

            if math.abs(dx) <= 0.18 and s.grounded and math.abs(vx) < 2.2 then
                ReleaseInput()
                return true
            end
            task.wait()
        end

        ReleaseInput()
        return false
    end

    -- Sekali Sapu (Single Sweep): Kiri terjauh -> Kanan terjauh -> Kembali ke tengah (Tanpa mutar 2-3x!)
    function Drops.touchAll(brokenTiles, hx, hy)
        if type(brokenTiles) ~= "table" or #brokenTiles == 0 then return false end
        local w = FindWorld()
        if not w then return false end

        local minX, maxX = hx, hx
        local jumpCols = {}

        for _, t in ipairs(brokenTiles) do
            if not Nav.SolidAt(t.x, t.y) then
                if t.y == hy and math.abs(t.x - hx) <= 3 then
                    if t.x < minX then minX = t.x end
                    if t.x > maxX then maxX = t.x end
                elseif t.y < hy and math.abs(t.x - hx) <= 2 then
                    if not jumpCols[t.x] or t.y < jumpCols[t.x] then
                        jumpCols[t.x] = t.y
                    end
                end
            end
        end

        local wasActive = AutoInput.active
        AutoInput.active = true
        Drops.collecting = true
        w.speedScale = 1

        local function jumpOnce(topY)
            ReleaseInput()
            local isHigh = (topY <= hy - 2)
            AutoInput.jump = true
            local jt0 = os.clock()
            local air = false
            while alive() and (Farm.on or Farm.Override ~= nil) and (os.clock() - jt0) < 1.1 do
                local s = PlayerPhysicsState()
                if not s or s.dead then break end
                if not s.grounded then
                    air = true
                    if not isHigh or s.y <= (topY + 0.6) or (s.vy or 0) >= 0 then
                        AutoInput.jump = false
                    end
                end
                if air and s.grounded then break end
                if not air and (os.clock() - jt0) > 0.32 then break end
                task.wait()
            end
            ReleaseInput()
        end

        pcall(function()
            -- 1. Jika ada tile pecah di sebelah kiri, sapu lurus 1x ke ujung kiri (minX)
            if minX < hx then
                Drops.walkToX(minX + 0.5, 1.5)
                if jumpCols[minX] then
                    jumpOnce(jumpCols[minX])
                    jumpCols[minX] = nil
                else
                    task.wait(0.06)
                end
            end

            -- 2. Jika ada tile pecah di sebelah kanan, sapu lurus 1x ke ujung kanan (maxX)
            if maxX > hx then
                Drops.walkToX(maxX + 0.5, 1.8)
                if jumpCols[maxX] then
                    jumpOnce(jumpCols[maxX])
                    jumpCols[maxX] = nil
                else
                    task.wait(0.06)
                end
            end

            -- 3. Jika masih ada tile atas (misal tepat di atas kepala x == hx) yang belum dilompati
            for colX, topY in pairs(jumpCols) do
                if not alive() or not (Farm.on or Farm.Override ~= nil) then break end
                Drops.walkToX(colX + 0.5, 1.4)
                jumpOnce(topY)
            end

            -- 4. Kembali lurus 1x ke titik tengah Auto Farm (hx + 0.5) dengan pengereman
            if alive() and (Farm.on or Farm.Override ~= nil) then
                Drops.walkToX(hx + 0.5, 1.6)
            end
        end)

        ReleaseInput()
        Drops.collecting = false
        if Config.walkSpeed ~= 100 and Refs.World then
            Refs.World.speedScale = Config.walkSpeed / 100
        end
        AutoInput.active = wasActive
        return true
    end

    local nextDropScan = 0
    trackConn(RunService.Heartbeat:Connect(function()
        if not alive() then return end
        if AutoMove and AutoMove.pauseCollect then return end
        local activeGrid = (Farm.Override and Farm.Override.offsets) or Config.farmGrid
        local farmArea = (Farm.on and Config.farmTake) or (Farm.Override ~= nil)
        local nearArea = Config.collectAround
            or (Clear.on and Config.clearTake)
            or (Farmer.on and Config.harvestTake)
            or (DF.on and Config.dfTake)
            or SpliceBot.on
            or Pabrik.on
            or (Session.Rotation and Session.Rotation.on)
        if not farmArea and not nearArea then return end

        local tnow = os.clock()
        if tnow < (Drops.nextTick or 0) then return end
        Drops.nextTick = tnow + ((Config.collectMode == "Remote") and 0.1 or 0.2)

        local list = Drops.list
        if not list then
            if tnow >= nextDropScan then
                nextDropScan = tnow + 5
                if Drops.findRefs then Drops.findRefs() else Refs.Scan() end
            end
            return
        end

        local s = PlayerPhysicsState()
        if not s or type(s.x) ~= "number" then return end
        local cx, cy = s.x, s.y - 0.475

        -- Mode "Legit": drop dipungut otomatis oleh game saat tersentuh badan; hitung statistiknya
        if Config.collectMode ~= "Remote" then
            local seen = {}
            for _, d in ipairs(list) do
                if type(d) == "table" and type(d.x) == "number" and math.abs(d.x - cx) <= 1.5 and math.abs(d.y - cy) <= 1.5 then
                    seen[d] = d.n or 0
                end
            end
            for d, n in pairs(Drops.seen or {}) do
                if seen[d] == nil and not table.find(list, d) and d.id and n > 0 then
                    Stats.Collected = Stats.Collected + n
                    Stats.Items[d.id] = (Stats.Items[d.id] or 0) + n
                    Farm.stats.picked = Farm.stats.picked + n
                    if Clear.on then Clear.stats.picked = Clear.stats.picked + n end
                    if Farmer.on then Farmer.stats.picked = Farmer.stats.picked + n end
                    if DF.on then DF.stats.picked = DF.stats.picked + n end
                end
            end
            Drops.seen = seen
            return
        end

        -- Mode "Remote": ambil langsung via world.takeDrop
        if #list == 0 then return end
        local ptx, pty = math.floor(cx), math.floor(cy)
        local radius = (tonumber(Config.collectRadius) or 3) + 0.25
        local dropZone = Pabrik.Zone
        if dropZone and dropZone.world ~= CurrentWorldName() then dropZone = nil end

        for i = #list, 1, -1 do
            local d = list[i]
            if canTryDrop(d, tnow) and not (dropZone and math.abs(d.x - dropZone.x) <= 2.5 and math.abs(d.y - dropZone.y) <= 2.5) then
                local hit = nearArea and math.abs(d.x - cx) <= radius and math.abs(d.y - cy) <= radius
                if not hit and farmArea then
                    for key, on in pairs(activeGrid) do
                        if on then
                            local dx, dy = tostring(key):match("^(-?%d+),(-?%d+)$")
                            if dx and dy then
                                local tx, ty = ptx + tonumber(dx), pty + tonumber(dy)
                                if inTile({ x = tx, y = ty }, d.x, d.y) then
                                    hit = true
                                    break
                                end
                            end
                        end
                    end
                end
                if hit then task.spawn(takeSingleDrop, d) end
            end
        end
    end))
end)() end

----------------------------------------------------------------------
-- 1. AUTO FARM (FAST BREAK + DYNAMIC DELAY ANTI-DETECT + WORLD-TO-WORLD REFILL)
----------------------------------------------------------------------
local StartFarm, StopFarm, RunFarmLoopDirect

do (function()
    local RAY_DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }
    local lastDynamicGap = 0

    -- Reset gate cooldown pukulan milik game agar Fast Break tidak tertahan gate lokal
    local function ResetPunchGate(w)
        if not w or not Config.farmFastBreak then return end
        pcall(function()
            for k, v in pairs(w) do
                local kl = string.lower(tostring(k))
                if string.find(kl, "punch", 1, true)
                    and (string.find(kl, "ready", 1, true) or string.find(kl, "lock", 1, true)
                        or string.find(kl, "cd", 1, true) or string.find(kl, "cool", 1, true)
                        or string.find(kl, "gate", 1, true) or string.find(kl, "wait", 1, true)) then
                    if type(v) == "boolean" then w[k] = false
                    elseif type(v) == "number" then w[k] = 0 end
                end
            end
        end)
    end

    -- Hitung delay dinamis (Anti-Detection Rhythm) agar setiap pukulan/place memiliki variasi manusiawi
    local function GetHumanizedDelay(baseSec)
        baseSec = tonumber(baseSec) or 0.20
        if not Config.farmDynamicDelay then
            return math.max(0.04, baseSec)
        end
        local jitterMax = math.clamp((tonumber(Config.farmDynamicJitterMs) or 45) / 1000, 0.01, 0.12)
        local delta = (math.random(-1000, 1000) / 1000) * jitterMax
        local candidate = math.max(0.05, baseSec + delta)
        -- Pastikan dua delay berturut-turut tidak pernah identik persis
        if math.abs(candidate - lastDynamicGap) < 0.008 then
            candidate = math.max(0.05, candidate + ((delta >= 0) and 0.015 or -0.012))
        end
        lastDynamicGap = candidate
        return candidate
    end

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
        if fg ~= 0 then return CanBreakId(fg, x, y) end
        local bg = TileValue(w, "bg", x, y)
        return Config.farmBreakBg and bg ~= nil and bg ~= 0 and CanBreakId(bg, x, y)
    end

    local function ParseWorldAndDoor(rawStr)
        local raw = tostring(rawStr or ""):gsub("%s", "")
        local wName, doorId = string.match(raw, "^([^:]*):(.+)$")
        if not wName then wName = raw end
        wName = string.upper(wName):gsub("[^A-Z0-9]", "")
        if doorId == "" then doorId = nil end
        return wName, doorId
    end

    local function WarpForRefill(wName, doorId)
        wName = Trim(wName):upper()
        if wName == "" then return true end
        if CurrentWorldName():upper() == wName and not doorId then return true end

        if QueueReload then pcall(QueueReload) end
        if CurrentWorldName() ~= "" then
            local m = Refs.Menu
            if m and type(rawget(m, "openPicker")) == "function" then
                pcall(m.openPicker)
            else
                local cw = FindWorld()
                if cw and type(rawget(cw, "call")) == "function" then pcall(cw.call, "LeaveWorld") end
            end
            task.wait(1.8)
        end

        local w = FindWorld()
        if doorId and w then rawset(w, "arriveDoor", doorId) end
        local oldFg = w and rawget(w, "fg")
        local m = Refs.Menu
        if m and type(rawget(m, "enter")) == "function" then
            pcall(m.enter, wName)
        elseif w and type(rawget(w, "enter")) == "function" then
            pcall(w.enter, wName)
        else
            return false
        end

        local t0 = os.clock()
        while alive() and (os.clock() - t0) < 12 do
            local cw = FindWorld()
            if cw and rawget(cw, "fg") ~= oldFg and CurrentWorldName():upper() == wName then
                Refs.Scan(true)
                task.wait(1.2)
                return true
            end
            task.wait(0.25)
        end
        return false
    end

    local function FindNearestDropOfId(targetId)
        if not Drops.list and Drops.findRefs then Drops.findRefs() end
        local list = Drops.list
        if type(list) ~= "table" then return nil end
        local px, py = GetTile()
        px, py = px or 50, py or 30
        local best, bestDist = nil, math.huge
        for _, d in ipairs(list) do
            if type(d) == "table" and d.id == targetId and (d.n or 0) > 0 and not d.display and type(d.x) == "number" then
                local dist = math.abs(d.x - px) + math.abs(d.y - py)
                if dist < bestDist then
                    best, bestDist = d, dist
                end
            end
        end
        return best
    end

    -- Auto Refill Block (Mendukung Di World Ini maupun Pindah ke World Lain)
    local function ExecuteAutoRefill(itemId, anchor, token)
        local function liveFn() return Farm.on and Farm.token == token and alive() end
        local refWName, refDoor = ParseWorldAndDoor(Config.farmRefillWorld)
        local homeWorld = anchor.world
        local needWarp = (refWName ~= "" and refWName:upper() ~= homeWorld:upper()) or (refDoor ~= nil)

        Pabrik.traveling = true
        if needWarp then
            Farm.stats.status = "Refill: Warping to " .. refWName .. (refDoor and (":" .. refDoor) or "") .. "..."
            if not WarpForRefill(refWName, refDoor) then
                Pabrik.traveling = false
                return false
            end
        end

        Refs.Scan()
        if Drops.findRefs then Drops.findRefs() end
        task.wait(0.6)

        -- Kumpulkan drop item tersebut sampai tas penuh (200) atau drop habis
        while liveFn() and CountItem(itemId) < 200 do
            local d = FindNearestDropOfId(itemId)
            if not d then break end
            local tx, ty = math.floor(d.x), math.floor(d.y)
            Farm.stats.status = string.format("Refill: Taking %s at (%d,%d) [%d/200]", ItemName(itemId), tx, ty, CountItem(itemId))
            Nav.To(tx, ty, function() return not liveFn() end, 0.35, false)
            if Drops.walkToX then
                local wasA = AutoInput.active
                AutoInput.active = true
                Drops.collecting = true
                Drops.walkToX(d.x, 1.0)
                Drops.collecting = false
                AutoInput.active = wasA
            end
            local w = FindWorld()
            local worldTake = w and rawget(w, "takeDrop")
            if type(worldTake) == "function" and d.uid then
                local room = 200 - CountItem(itemId)
                if room > 0 then pcall(worldTake, d.uid, math.min(d.n or 1, room)) end
            end
            task.wait(0.35)
        end

        -- Kembali ke World Auto Farm jika tadi pindah world
        if CurrentWorldName():upper() ~= homeWorld:upper() and liveFn() then
            Farm.stats.status = "Refill: Returning to " .. homeWorld .. "..."
            if not WarpForRefill(homeWorld, nil) and liveFn() then
                task.wait(3)
                WarpForRefill(homeWorld, nil)
            end
        end
        Pabrik.traveling = false

        -- Kembali ke titik berdiri Auto Farm semula
        if liveFn() and CurrentWorldName():upper() == homeWorld:upper() then
            Farm.stats.status = string.format("Refill: Walking back to (%d,%d)...", anchor.x, anchor.y)
            Nav.To(anchor.x, anchor.y, function() return not liveFn() end, 0.25, false)
            if Drops.walkToX then
                local wasA = AutoInput.active
                AutoInput.active = true
                Drops.collecting = true
                Drops.walkToX(anchor.x + 0.5, 1.2)
                Drops.collecting = false
                AutoInput.active = wasA
            end
        end

        return CountItem(itemId) > 0
    end

    local function FarmLoop(token, anchor)
        local nextHitAt = 0
        while Farm.on and Farm.token == token and alive() do
            local w = FindWorld()
            if not w or CurrentWorldName() ~= anchor.world then
                Farm.stats.status = "World changed, stopped"
                break
            end

            local mode = (Farm.Override and Farm.Override.mode) or Config.farmMode
            local doPlace = mode ~= "Break saja"
            local doBreak = mode ~= "Place saja"
            local id = (Farm.Override and Farm.Override.block) or Config.farmPlaceId

            -- Helper Cek & Eksekusi Auto Drop Seed (Mencegah stuck di 195-199 karena partial pickup ditolak server)
            local function CheckAndExecuteFarmSeedDrop()
                if Farm.Override or not Config.farmAutoDropSeed then return false end
                local seedId = IsSeedId(id) and id or SeedOfBlock(id)
                if not seedId then return false end

                local userTarget = tonumber(Config.farmSeedDropAt) or 200
                -- Jika user set 200, trigger pada >= 195 agar tidak stuck di 198-199 saat tumpukan drop > sisa slot
                local effectiveThreshold = (userTarget >= 196) and 195 or math.max(1, userTarget)
                local curSeeds = CountItem(seedId)

                if curSeeds >= effectiveThreshold then
                    local keep = math.max(0, tonumber(Config.farmSeedKeep) or 0)
                    local dropAmt = curSeeds - keep
                    if dropAmt > 0 and Pabrik and type(Pabrik.ExternalDropSeed) == "function" then
                        local dropW = Trim(Config.farmDropWorld or "")
                        local dx, dy = tonumber(Config.farmDropX) or -1, tonumber(Config.farmDropY) or -1
                        -- Jika user belum SetPos Drop dan masih di world yang sama, drop 2 tile di samping anchor agar tidak menghambat!
                        if dropW == "" and (dx < 0 or dy < 0) then
                            dx = math.clamp(anchor.x + ((anchor.x >= 4) and -2 or 2), 1, w.w - 2)
                            dy = anchor.y
                        end
                        Farm.stats.status = string.format("Auto Drop Seed %s x%d...", ItemName(seedId), dropAmt)
                        Pabrik.ExternalDropSeed(
                            seedId, dropAmt, dropW, dx, dy,
                            anchor.world, anchor.x, anchor.y,
                            function() return Farm.on and Farm.token == token and alive() end
                        )
                        return true
                    end
                end
                return false
            end

            if CheckAndExecuteFarmSeedDrop() then
                w = FindWorld()
                if not w then break end
            end

            local offsets = activeOffsets()
            if #offsets == 0 then
                Farm.stats.status = "Select tiles in 5x5 Grid first"
                if not Farm.Quiet then Notify("Auto Farm: Select at least 1 tile in the 5x5 Grid.") end
                break
            end

            local sNow = PlayerPhysicsState()
            local px, py = GetTile()
            if not px then break end
            local offAnchor = (py ~= anchor.y) or (not sNow) or (math.abs(sNow.x - (anchor.x + 0.5)) > 0.38)
            if not Farm.Override and offAnchor then
                if py == anchor.y and math.abs(px - anchor.x) <= 4 and Drops.walkToX then
                    local wasA = AutoInput.active
                    AutoInput.active = true
                    Drops.collecting = true
                    Drops.walkToX(anchor.x + 0.5, 1.5)
                    Drops.collecting = false
                    AutoInput.active = wasA
                else
                    Nav.To(anchor.x, anchor.y, function() return Farm.token ~= token end, 0.2, false)
                end
                px, py = anchor.x, anchor.y
            end

            local tiles = {}
            for _, o in ipairs(offsets) do
                local tx, ty = anchor.x + o.dx, anchor.y + o.dy
                if InBounds(w, tx, ty) then
                    table.insert(tiles, { x = tx, y = ty })
                end
            end

            local acted, outOfBlock = false, false

            if doPlace then
                Farm.stats.status = "Placing " .. ItemName(id)
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
                            task.wait(GetHumanizedDelay(Config.farmPlaceMs / 1000))
                        end
                    end
                end
            end

            if not Farm.on or Farm.token ~= token then break end

            local brokenTiles = {}
            local brokenSeen = {}

            if doBreak then
                Farm.stats.status = "Breaking (" .. (raymanOn() and "Rayman" or ("Multi " .. Config.farmMultiTarget)) .. ")"
                local K = math.clamp(math.floor(Config.farmMultiTarget or 1), 1, 5)
                local nextI, active = 1, {}
                while Farm.on and Farm.token == token and alive() do
                    while #active < K and nextI <= #tiles do
                        local t = tiles[nextI]
                        nextI += 1
                        if breakableAt(w, t.x, t.y) then
                            active[#active + 1] = { x = t.x, y = t.y, n = 0 }
                            local bKey = t.x .. "," .. t.y
                            if not brokenSeen[bKey] then
                                brokenSeen[bKey] = true
                                table.insert(brokenTiles, { x = t.x, y = t.y })
                            end
                        end
                    end
                    if #active == 0 then break end

                    local hits, rayDir = nil, nil
                    if K > 1 and raymanOn() then
                        hits, rayDir = raymanLine(anchor.x, anchor.y, active)
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
                        ResetPunchGate(w)
                        local r = TryBreakOnce(a.x, a.y, Config.farmBreakBg)
                        a.n += 1
                        if r then hitAny, acted = true, true end
                        if r == "broke" then
                            Farm.stats.broken += 1
                            brokeAny = true
                        end
                        if r == nil or a.n > 80 or not breakableAt(w, a.x, a.y) then
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
                        local gap = GetHumanizedDelay(Config.farmDelay)
                        if rayDir then gap = math.max(gap, 0.35) end
                        if Config.farmFastBreak then
                            local due = (nextHitAt > 0 and nextHitAt or t0) + gap
                            local now = os.clock()
                            if due < now - gap then due = now end
                            nextHitAt = due
                            local rest = due - now
                            if rest > 0.002 then task.wait(rest) end
                        else
                            local rest = gap - (os.clock() - t0)
                            if rest > 0.005 then task.wait(rest) end
                        end
                    end
                    if brokeAny and not Config.farmFastBreak and #active > 0 and Config.farmAfterBreakMs > 0 then
                        task.wait(Config.farmAfterBreakMs / 1000)
                    end
                end
            end

            if #brokenTiles > 0 and (Config.farmTake or Farm.Override) and Config.collectMode == "Legit" then
                Farm.stats.status = "Collecting drops..."
                task.wait(0.18)
                if Drops.touchAll then
                    Drops.touchAll(brokenTiles, anchor.x, anchor.y)
                end
                task.wait(0.15) -- Tunggu inventori sinkron dari server setelah menyapu drop
            end

            -- Cek kembali Auto Drop Seed tepat setelah selesai mengambil drop!
            if CheckAndExecuteFarmSeedDrop() then
                w = FindWorld()
                if not w then break end
            end

            -- Cek apakah stok blok habis dan Auto Refill aktif
            if doPlace and not Farm.Override and CountItem(id) <= 0 then
                if Config.farmAutoRefill then
                    if ExecuteAutoRefill(id, anchor, token) then
                        w = FindWorld()
                        acted = true
                        outOfBlock = false
                    else
                        outOfBlock = true
                    end
                else
                    outOfBlock = true
                end
            end

            if not acted then
                if outOfBlock then
                    Farm.stats.status = ItemName(id) .. " depleted"
                    if not Farm.Quiet then
                        Notify("Auto Farm stopped: " .. ItemName(id) .. " is out of stock.")
                        Webhook.Send("stop", "Auto Farm stopped: " .. ItemName(id) .. " depleted")
                    end
                    break
                end
                task.wait(GetHumanizedDelay(Config.farmDelay))
            end

            Farm.stats.cycles += 1
        end
    end

    RunFarmLoopDirect = FarmLoop

    StopFarm = function()
        if not Farm.on then return false end
        Farm.token = Farm.token + 1
        Farm.on = false
        ReleaseInput()
        AutoInput.active = false
        Farm.stats.status = "Idle"
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
        if Session.Rotation and Session.Rotation.on then Session.Rotation.Stop() end

        local doPlace = Config.farmMode ~= "Break saja"
        if doPlace and (type(Config.farmPlaceId) ~= "number" or Config.farmPlaceId <= 0) then
            Notify("Select a Farm Block ID first in the Auto Farm tab.")
            return false
        end
        local x, y, facing = GetGridState()
        if not x then
            Notify("Character position not detected.")
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
        Farm.stats.status = "Running"
        if UpdateGridVisuals then pcall(UpdateGridVisuals) end

        task.spawn(function()
            local ok, err = pcall(FarmLoop, token, anchor)
            ReleaseInput()
            AutoInput.active = false
            if not ok then warn("[ANCHHub] Auto Farm error: " .. tostring(err)) end
            if Farm.token == token then
                Farm.on = false
                if Farm.stats.status == "Running" then Farm.stats.status = "Idle" end
                if UpdateGridVisuals then pcall(UpdateGridVisuals) end
                if RefreshHub then RefreshHub() end
            end
        end)
        return true
    end
end)() end

----------------------------------------------------------------------
-- 2. AUTO CLEAR WORLD (FULL LEGIT WALKING + SIDE BREAK + ANTI-LAVA)
----------------------------------------------------------------------
do (function()
    local STUCK_HIT_TIMEOUT = 5.5 -- Batas waktu jika 1 layer tidak hancur-hancur agar tidak loop stuck

    local function ClearLayerAt(w, x, y)
        local fg = TileValue(w, "fg", x, y)
        if fg == nil then return nil end
        if fg ~= 0 then
            if CanBreakId(fg, x, y) then return "fg", fg end
            return nil
        end
        if Config.clearIncludeBg then
            local bg = TileValue(w, "bg", x, y)
            if bg and bg ~= 0 and CanBreakId(bg, x, y) then return "bg", bg end
        end
        return nil
    end

    -- Cek apakah tile (x, y) aman untuk dipijak (kosong, punya lantai di y+1, dan lantai y+1 BUKAN Lava/Hazard)
    local function IsSafeStandTile(w, x, y)
        if not InBounds(w, x, y) then return false end
        if not Nav.OpenAt(x, y) then return false end
        if y + 1 >= w.h then return false end
        if Nav.HazardAt and Nav.HazardAt(x, y + 1) then return false end
        return Nav.RealSupport(x, y)
    end

    -- Cari baris paling atas yang masih memiliki blok untuk dihancurkan
    local function FindTopWorkRow(w, skippedSet)
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
                return y, rowTargets
            end
        end
        return nil, {}
    end

    -- Cari posisi berdiri terbaik: Prioritaskan di SAMPING blok (sejajar Y), bukan di atasnya, dan bebas Lava!
    local function FindSideStandPositions(w, tx, ty, prefSide)
        local s1 = (prefSide == 1) and 1 or -1
        local s2 = -s1
        local candidates = {
            -- 1. Prioritas Utama: Tepat di samping kiri/kanan blok (sejajar y)
            { x = tx + s1,     y = ty },
            { x = tx + s2,     y = ty },
            { x = tx + s1 * 2, y = ty },
            { x = tx + s2 * 2, y = ty },
            -- 2. Serong samping atas (jika di samping sejajar belum ada pijakan)
            { x = tx + s1,     y = ty - 1 },
            { x = tx + s2,     y = ty - 1 },
            -- 3. Fallback: Di atas blok (dipakai saat membuka blok paling ujung agar ada ruang turun)
            { x = tx,          y = ty - 1 },
        }
        local valid = {}
        for _, c in ipairs(candidates) do
            if IsSafeStandTile(w, c.x, c.y) then
                table.insert(valid, c)
            end
        end
        return valid
    end

    -- Pukul target (tx, ty) sampai benar-benar hancur total (FG + BG), kecuali lewat batas STUCK_HIT_TIMEOUT
    local function BreakTargetUntilGone(w, tx, ty, cancelFn)
        local lastLayer, lastId = ClearLayerAt(w, tx, ty)
        if not lastLayer then return true end

        local layerStartClock = os.clock()
        local reachR = PunchReach() - 0.1

        while not cancelFn() do
            local curLayer, curId = ClearLayerAt(w, tx, ty)
            if not curLayer then
                -- Verifikasi singkat 0.06 detik untuk memastikan blok tidak rollback dari server
                task.wait(0.06)
                curLayer, curId = ClearLayerAt(w, tx, ty)
                if not curLayer then
                    return true
                end
            end

            -- Jika layer/id berubah (misal FG pecah lanjut ke BG), reset timer timeout!
            if curLayer ~= lastLayer or curId ~= lastId then
                lastLayer, lastId = curLayer, curId
                layerStartClock = os.clock()
            end

            -- Jika sudah dipukul terus selama STUCK_HIT_TIMEOUT tapi tidak hancur, lewati agar tidak loop stuck!
            if (os.clock() - layerStartClock) >= STUCK_HIT_TIMEOUT then
                return false, "timeout"
            end

            -- Pastikan karakter masih dalam jangkauan pukul & tidak terpental lava
            local s = PlayerPhysicsState()
            if not s or not Nav.StateReaches(s, tx, ty, reachR + 0.35) then
                return false, "out_of_range"
            end

            Clear.status = string.format("Breaking %s (%d,%d)", ItemName(curId), tx, ty)
            local r = TryBreakOnce(tx, ty, Config.clearIncludeBg)
            if r == nil then
                return false, "unbreakable"
            elseif r == "broke" then
                Clear.stats.broken += 1
                layerStartClock = os.clock()
            end
            task.wait(math.max(0.04, Config.clearBreakDelay))
        end
        return false, "cancelled"
    end

    -- Bergerak murni dengan Legit Walking (tanpa ModFly) menuju samping/dekat target
    local function WalkToBreakTarget(w, tx, ty, prefSide, cancelFn)
        SetAutoFly("autoclear", false)
        if w and not noclipOn then w.ghost = false end

        local reachR = PunchReach() - 0.15
        local sNow = PlayerPhysicsState()
        local px, py = GetTile()

        -- Jika sudah berada di samping blok (atau dalam jangkauan pukul pada pijakan yang aman & bebas lava)
        if sNow and px and py and Nav.StateReaches(sNow, tx, ty, reachR) and IsSafeStandTile(w, px, py) and not (px == tx and py == ty - 1 and Nav.OpenAt(tx + prefSide, ty) and IsSafeStandTile(w, tx + prefSide, ty)) then
            return true
        end

        -- Tunggu karakter menapak tanah jika sedang melompat/jatuh
        local tGround = os.clock()
        while not cancelFn() and (os.clock() - tGround) < 0.5 do
            local st = PlayerPhysicsState()
            if st and st.grounded then break end
            task.wait(0.03)
        end

        local standList = FindSideStandPositions(w, tx, ty, prefSide)
        for _, stPos in ipairs(standList) do
            if cancelFn() then return false end
            if Nav.LegitTo(stPos.x, stPos.y, cancelFn, 0.35, true) then
                local sCheck = PlayerPhysicsState()
                if sCheck and Nav.StateReaches(sCheck, tx, ty, reachR + 0.3) then
                    return true
                end
            end
        end

        -- Fallback: Cari jalur A* ke tile mana saja yang menjangkau (tx, ty)
        if Nav.LegitTo(tx, ty, cancelFn, math.max(1.8, reachR), true) then
            local sCheck = PlayerPhysicsState()
            if sCheck and Nav.StateReaches(sCheck, tx, ty, reachR + 0.3) then
                return true
            end
        end
        return false
    end

    local function ClearLoop(token, home)
        -- Pastikan ModFly MATI sepenuhnya agar murni Legit Walking & tidak teleport-teleport
        SetAutoFly("autoclear", false)
        ReleaseInput()
        AutoInput.active = false

        local skippedSet = {}
        local retryCount = {}
        local pass = 0
        local rowDir = 1

        while Clear.on and Clear.token == token and alive() do
            local w = FindWorld()
            if not w or CurrentWorldName() ~= home.world then
                Clear.status = "World changed, stopped"
                break
            end
            if not noclipOn then w.ghost = false end

            local cancelFn = function()
                return not Clear.on or Clear.token ~= token or not alive()
            end

            local topY, rowTargets = FindTopWorkRow(w, skippedSet)
            if not topY then
                -- Jika masih ada blok yang tadi sempat ke-skip karena belum terjangkau, coba ulang maksimal 2 pass
                if next(skippedSet) ~= nil and pass < 3 then
                    pass += 1
                    table.clear(skippedSet)
                    table.clear(Nav.BadEdge)
                    task.wait(0.5)
                    continue
                end
                break
            end

            Clear.stats.row = topY
            Clear.stats.scanned = #rowTargets
            Clear.stats.left = #rowTargets

            -- Tentukan arah sapuan baris ini (pilih ujung terdekat jika Zig-zag)
            local px = GetTile()
            if Config.clearSweep == "Zig-zag" and px then
                local minX, maxX = rowTargets[1].x, rowTargets[#rowTargets].x
                for _, t in ipairs(rowTargets) do
                    if t.x < minX then minX = t.x end
                    if t.x > maxX then maxX = t.x end
                end
                rowDir = (math.abs(px - maxX) < math.abs(px - minX)) and -1 or 1
            else
                rowDir = 1
            end

            if rowDir == -1 then
                table.sort(rowTargets, function(a, b) return a.x > b.x end)
            else
                table.sort(rowTargets, function(a, b) return a.x < b.x end)
            end

            -- LANGKAH 1: Buka ruang di ujung baris terlebih dahulu agar karakter bisa turun ke samping blok!
            local firstEdge = rowTargets[1]
            if firstEdge and ClearLayerAt(w, firstEdge.x, firstEdge.y) then
                -- Jika di bawah blok ujung ada Lava, kita juga akan menghancurkan Lava tersebut sebelum turun
                Clear.status = string.format("Opening edge pocket at (%d,%d)...", firstEdge.x, firstEdge.y)
                if WalkToBreakTarget(w, firstEdge.x, firstEdge.y, -rowDir, cancelFn) then
                    BreakTargetUntilGone(w, firstEdge.x, firstEdge.y, cancelFn)
                    -- Cek apakah lantai di bawah ruang turun (firstEdge.x, firstEdge.y + 1) adalah Lava!
                    if InBounds(w, firstEdge.x, firstEdge.y + 1) and Nav.HazardAt(firstEdge.x, firstEdge.y + 1) and ClearLayerAt(w, firstEdge.x, firstEdge.y + 1) then
                        Clear.status = string.format("Clearing Lava below edge (%d,%d)...", firstEdge.x, firstEdge.y + 1)
                        if WalkToBreakTarget(w, firstEdge.x, firstEdge.y + 1, -rowDir, cancelFn) then
                            BreakTargetUntilGone(w, firstEdge.x, firstEdge.y + 1, cancelFn)
                        end
                    end
                end
            end

            -- LANGKAH 2: Sapu seluruh blok di baris topY dari samping (karakter berdiri di sejajar topY)
            for idx, target in ipairs(rowTargets) do
                if cancelFn() then return end
                w = FindWorld()
                if not w or CurrentWorldName() ~= home.world then return end

                if ClearLayerAt(w, target.x, target.y) then
                    -- Sebelum maju memijak tile sebelumnya, pastikan lantai di bawah target bukan Lava
                    if InBounds(w, target.x, target.y + 1) and Nav.HazardAt(target.x, target.y + 1) and ClearLayerAt(w, target.x, target.y + 1) then
                        if WalkToBreakTarget(w, target.x, target.y + 1, -rowDir, cancelFn) then
                            BreakTargetUntilGone(w, target.x, target.y + 1, cancelFn)
                        end
                    end

                    Clear.status = string.format("Walking beside (%d,%d) [%d/%d]", target.x, target.y, idx, #rowTargets)
                    local reached = WalkToBreakTarget(w, target.x, target.y, -rowDir, cancelFn)

                    if reached then
                        local okBroke, why = BreakTargetUntilGone(w, target.x, target.y, cancelFn)
                        -- Jika terpental saat memukul, jalan kembali 1x dan tuntaskan sampai benar-benar hancur!
                        if not okBroke and why == "out_of_range" and ClearLayerAt(w, target.x, target.y) then
                            if WalkToBreakTarget(w, target.x, target.y, -rowDir, cancelFn) then
                                okBroke, why = BreakTargetUntilGone(w, target.x, target.y, cancelFn)
                            end
                        end

                        if okBroke or not ClearLayerAt(w, target.x, target.y) then
                            Clear.stats.left = math.max(0, Clear.stats.left - 1)
                        else
                            skippedSet[target.key] = true
                            Clear.stats.skipped += 1
                            Clear.status = string.format("Skipped (%d,%d) [%s]", target.x, target.y, tostring(why))
                        end
                    else
                        retryCount[target.key] = (retryCount[target.key] or 0) + 1
                        if retryCount[target.key] >= 2 then
                            skippedSet[target.key] = true
                            Clear.stats.skipped += 1
                        end
                    end
                else
                    Clear.stats.left = math.max(0, Clear.stats.left - 1)
                end
            end
        end

        SetAutoFly("autoclear", false)
        ReleaseInput()
        AutoInput.active = false
        Clear.status = "Completed"
        local msg = string.format("Auto Clear finished! Broken: %d | Collected: %d | Skipped: %d", Clear.stats.broken, Clear.stats.picked, Clear.stats.skipped)
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
        Clear.status = "Idle"
        return true
    end

    function Clear.Start()
        if Clear.on then return true end
        if Farm.on then StopFarm() end
        if Farmer.on then Farmer.Stop() end
        if DF.on then DF.Stop() end
        if SpliceBot.on then SpliceBot.Stop() end
        if Pabrik.on then Pabrik.Stop() end
        if Session.Rotation and Session.Rotation.on then Session.Rotation.Stop() end

        local x, y = GetGridState()
        if not x then Notify("Character position not detected."); return false end
        local home = { x = math.floor(x), y = math.floor(y - 0.475), world = CurrentWorldName() }
        Clear.token += 1
        local token = Clear.token
        Clear.on = true
        Clear.status = "Starting"
        Clear.stats = { scanned = 0, broken = 0, picked = 0, skipped = 0, left = 0, pass = 1, row = -1 }

        task.spawn(function()
            local ok, err = pcall(ClearLoop, token, home)
            if not ok then warn("[ANCHHub] Auto Clear error: " .. tostring(err)) end
            SetAutoFly("autoclear", false)
            ReleaseInput()
            AutoInput.active = false
            if Clear.token == token then
                Clear.on = false
                if Clear.status ~= "Completed" then Clear.status = "Idle" end
                if RefreshHub then RefreshHub() end
            end
        end)
        return true
    end
end)() end

----------------------------------------------------------------------
-- 3. FARMER: AUTO HARVEST (+AUTO SAVE BLOCK) & AUTO PLANT (+AUTO TAKE SEED)
----------------------------------------------------------------------
do (function()
    local FailedSeedDrops = {}

    -- Tentukan koordinat & world penyimpanan block untuk Farmer
    local function GetFarmerSaveTarget(homeWorld, homeX, homeY, w)
        local saveW = Trim(Config.harvestSaveWorld or "")
        local sx = tonumber(Config.harvestSaveX) or -1
        local sy = tonumber(Config.harvestSaveY) or -1

        -- Fallback ke pengaturan Drop Factory / Farm jika Pos Simpan Farmer belum di-set
        if saveW == "" and (sx < 0 or sy < 0) then
            if (tonumber(Config.pabrikDropX) or -1) >= 0 and (tonumber(Config.pabrikDropY) or -1) >= 0 then
                saveW = Trim(Config.pabrikDropWorld or "")
                sx, sy = tonumber(Config.pabrikDropX), tonumber(Config.pabrikDropY)
            elseif (tonumber(Config.farmDropX) or -1) >= 0 and (tonumber(Config.farmDropY) or -1) >= 0 then
                saveW = Trim(Config.farmDropWorld or "")
                sx, sy = tonumber(Config.farmDropX), tonumber(Config.farmDropY)
            elseif type(Config.pos1) == "table" and type(Config.pos1.x) == "number" and type(Config.pos1.y) == "number" then
                saveW = Trim(Config.pos1.world or "")
                sx, sy = Config.pos1.x, Config.pos1.y
            else
                -- Fallback terakhir: di dekat Main Door / posisi awal mulai
                sx, sy = homeX, homeY
            end
        end
        return saveW, sx, sy
    end

    -- Simpan Block ke Posisi Simpan (Matikan Auto Collect -> Jalan ke Pos -> Drop -> Nyalakan Auto Collect)
    local function ExecuteSaveHarvestBlock(blockId, home, returnX, returnY, token)
        local function liveFn() return Farmer.on and Farmer.token == token and alive() end
        local have = CountItem(blockId)
        if have <= 0 then return false end

        local w = FindWorld()
        local saveW, saveX, saveY = GetFarmerSaveTarget(home.world, home.x, home.y, w)

        Farmer.status = string.format("Tas Block penuh (%d)! Menuju pos simpan (%d,%d)...", have, saveX, saveY)
        Notify(string.format("Auto Harvest: Menyimpan %s x%d ke (%d,%d)...", ItemName(blockId), have, saveX, saveY), "Farmer ANCH", 4)

        -- 1. Matikan Auto Collect sementara
        AutoMove.pauseCollect = true
        local savedTakeCfg = Config.harvestTake
        Config.harvestTake = false

        -- 2. Gunakan ExternalDropSeed untuk melakukan perjalanan, drop (dengan auto geser kanan jika penuh), dan kembali
        if Pabrik and type(Pabrik.ExternalDropSeed) == "function" then
            Pabrik.ExternalDropSeed(blockId, have, saveW, saveX, saveY, home.world, returnX, returnY, liveFn)
        end

        -- 3. Nyalakan kembali Auto Collect
        Config.harvestTake = savedTakeCfg
        AutoMove.pauseCollect = false
        Farmer.status = "Selesai simpan block, melanjutkan panen..."
        return true
    end

    -- Cari dropped seed terdekat di world (di luar zona simpan Pabrik.Zone) untuk Auto Take Seed saat Planting
    local function FindDroppedSeedInWorld(seedId)
        if not Drops.list and Drops.findRefs then Drops.findRefs() end
        local list = Drops.list
        if type(list) ~= "table" then return nil end

        local px, py = GetTile()
        px, py = px or 50, py or 30
        local now = os.clock()
        local dropZone = Pabrik.Zone
        if dropZone and dropZone.world ~= CurrentWorldName() then dropZone = nil end

        local best, bestDist = nil, math.huge
        for _, d in ipairs(list) do
            if type(d) == "table" and d.id == seedId and (d.n or 0) > 0 and not d.display and type(d.x) == "number" then
                local key = d.uid or (math.floor(d.x) .. "," .. math.floor(d.y))
                local skipUntil = FailedSeedDrops[key]
                local dx, dy = math.floor(d.x), math.floor(d.y)
                if not (skipUntil and now < skipUntil) and not Nav.SolidAt(dx, dy) then
                    local dist = math.abs(d.x - px) + math.abs(d.y - py)
                    if dist < bestDist then
                        best, bestDist = d, dist
                    end
                end
            end
        end
        return best
    end

    -- Auto Take Seed: Cari dan ambil dropped seed di world sampai tas penuh (200) atau drop habis
    local function CollectDroppedSeedsForPlanting(seedId, token)
        local function liveFn() return Farmer.on and Farmer.token == token and alive() end
        local gotAny = false
        local tries = {}
        local tStart = os.clock()

        while liveFn() and CountItem(seedId) < 200 and (os.clock() - tStart) < 40 do
            local d = FindDroppedSeedInWorld(seedId)
            if not d then break end

            local key = d.uid or (math.floor(d.x) .. "," .. math.floor(d.y))
            tries[key] = (tries[key] or 0) + 1
            if tries[key] > 2 then
                FailedSeedDrops[key] = os.clock() + 45
                continue
            end

            local tx, ty = math.floor(d.x), math.floor(d.y)
            local before = CountItem(seedId)
            Farmer.status = string.format("Seed habis! Mengambil drop %s di (%d,%d) [%d/200]...", ItemName(seedId), tx, ty, before)

            local reached = Nav.To(tx, ty, function() return not liveFn() end, 0.4, Config.harvestUseBlock)
            if reached and Drops.walkToX then
                local wasA = AutoInput.active
                AutoInput.active = true
                Drops.collecting = true
                Drops.walkToX(d.x, 0.9)
                Drops.collecting = false
                AutoInput.active = wasA
            end

            local w = FindWorld()
            local worldTake = w and rawget(w, "takeDrop")
            if type(worldTake) == "function" and d.uid then
                local room = 200 - CountItem(seedId)
                if room > 0 then pcall(worldTake, d.uid, math.min(d.n or 1, room)) end
            end

            task.wait(0.35)
            if CountItem(seedId) > before then
                gotAny = true
                FailedSeedDrops[key] = nil
            elseif not reached then
                FailedSeedDrops[key] = os.clock() + 45
            end
        end

        return gotAny or CountItem(seedId) > 0
    end

    local function FarmerLoop(token, home)
        if Config.harvestModFly then
            SetAutoFly("autoharvest", true)
        end

        table.clear(FailedSeedDrops)
        local failedSet = {}
        local pass = 0
        local targetSeedId = tonumber(Config.harvestSeedId) or 3
        local targetBlockId = BlockOfSeed(targetSeedId)

        while Farmer.on and Farmer.token == token and alive() do
            pass += 1
            local w = FindWorld()
            if not w or CurrentWorldName() ~= home.world then
                Farmer.status = "World berubah, berhenti"
                break
            end

            targetSeedId = tonumber(Config.harvestSeedId) or 3
            targetBlockId = BlockOfSeed(targetSeedId)

            -- Cek di awal pass: jika Auto Harvest aktif & block sudah >= 200, simpan dulu!
            if Config.harvestDoHarvest and Config.harvestAutoSaveBlock and targetBlockId and CountItem(targetBlockId) >= 200 then
                local cx, cy = GetTile()
                ExecuteSaveHarvestBlock(targetBlockId, home, cx or home.x, cy or home.y, token)
                if not Farmer.on or Farmer.token ~= token then break end
                w = FindWorld()
                if not w then break end
            end

            -- Cek di awal pass: jika Auto Plant aktif tapi seed di tas 0, coba ambil dropped seed di world dulu!
            if Config.harvestDoPlant and CountItem(targetSeedId) <= 0 and Config.harvestAutoTakeSeed ~= false then
                if FindDroppedSeedInWorld(targetSeedId) then
                    CollectDroppedSeedsForPlanting(targetSeedId, token)
                    w = FindWorld()
                    if not w then break end
                end
            end

            Farmer.status = "Scan pohon & lahan tanam..."
            local readyTrees = {}
            local plantSpots = {}
            local totalTrees = 0
            local skippedNotReady = 0
            local hasSeedOrDrop = (CountItem(targetSeedId) > 0)
                or (Config.harvestAutoTakeSeed ~= false and FindDroppedSeedInWorld(targetSeedId) ~= nil)
            local doPlant = Config.harvestDoPlant and targetSeedId and hasSeedOrDrop

            local rowDir = 1
            for y = 0, w.h - 1 do
                local rowTrees, rowSpots = {}, {}
                for x = 0, w.w - 1 do
                    local id = TileValue(w, "fg", x, y) or 0
                    -- Cek pohon yang sesuai dengan ID Seed yang dipilih user
                    if id ~= 0 and id == targetSeedId then
                        totalTrees = totalTrees + 1
                        if Config.harvestDoHarvest and not failedSet[x .. "," .. y] then
                            if IsTreeReady(w, x, y, id) then
                                table.insert(rowTrees, { x = x, y = y, id = id })
                            else
                                skippedNotReady = skippedNotReady + 1
                            end
                        end
                    elseif doPlant and id == 0 and CanPlantAt(w, x, y, targetSeedId) then
                        table.insert(rowSpots, { x = x, y = y })
                    end
                end
                if #rowTrees > 0 or #rowSpots > 0 then
                    if rowDir == -1 then
                        table.sort(rowTrees, function(a, b) return a.x > b.x end)
                        table.sort(rowSpots, function(a, b) return a.x > b.x end)
                    else
                        table.sort(rowTrees, function(a, b) return a.x < b.x end)
                        table.sort(rowSpots, function(a, b) return a.x < b.x end)
                    end
                    for _, tr in ipairs(rowTrees) do table.insert(readyTrees, tr) end
                    for _, sp in ipairs(rowSpots) do table.insert(plantSpots, sp) end
                    rowDir = -rowDir
                end
            end

            Farmer.stats.totalTrees = totalTrees
            Farmer.stats.ready = #readyTrees

            if pass == 1 then
                Farmer.stats.skipped = skippedNotReady
                if Config.harvestDoHarvest and #readyTrees == 0 then
                    Notify(string.format("Tidak ada pohon %s yang siap panen terdeteksi! (Total pohon: %d, Belum siap: %d)", ItemName(targetSeedId), totalTrees, skippedNotReady), "Auto Harvest", 5)
                else
                    Notify(string.format("Farmer Scan (%s): %d siap panen, %d belum siap | %d lahan kosong.", ItemName(targetSeedId), #readyTrees, skippedNotReady, #plantSpots), "Farmer ANCH", 4)
                end
            end

            if #readyTrees == 0 and #plantSpots == 0 then
                break
            end

            local actedInPass = false
            local R = math.min(PunchReach(), BuildReach()) - 0.15

            -- FASE 1: AUTO HARVEST (+ AUTO COLLECT BLOCK & AUTO SAVE SAAT >= 200)
            for idx, tree in ipairs(readyTrees) do
                if not Farmer.on or Farmer.token ~= token or not alive() then return end
                w = FindWorld()
                if not w or CurrentWorldName() ~= home.world then return end

                -- Cek apakah block di inventory sudah >= 200 (atau >= 196 agar tidak menolak tumpukan pohon berikutnya)
                if Config.harvestAutoSaveBlock and targetBlockId and CountItem(targetBlockId) >= 200 then
                    ExecuteSaveHarvestBlock(targetBlockId, home, tree.x, tree.y, token)
                    if not Farmer.on or Farmer.token ~= token then return end
                    w = FindWorld()
                    if not w then return end
                end

                if TileValue(w, "fg", tree.x, tree.y) == tree.id then
                    local s = PlayerPhysicsState()
                    if not (s and Nav.StateReaches(s, tree.x, tree.y, R)) then
                        Farmer.status = string.format("Jalan ke pohon (%d,%d) [%d/%d | Block: %d/200]", tree.x, tree.y, idx, #readyTrees, targetBlockId and CountItem(targetBlockId) or 0)
                        local moved = Nav.To(tree.x, tree.y, function() return Farmer.token ~= token or not Farmer.on end, R, Config.harvestUseBlock)
                        if not moved then
                            failedSet[tree.x .. "," .. tree.y] = true
                            Farmer.stats.skipped = Farmer.stats.skipped + 1
                        end
                        task.wait(math.max(0.08, Config.harvestTpDelay))
                    end

                    local sCheck = PlayerPhysicsState()
                    if sCheck and Nav.StateReaches(sCheck, tree.x, tree.y, R + 0.5) then
                        Farmer.status = string.format("Panen %s (%d,%d) [%d/%d]", ItemName(tree.id), tree.x, tree.y, idx, #readyTrees)
                        local t0 = os.clock()
                        while Farmer.on and Farmer.token == token and TileValue(w, "fg", tree.x, tree.y) == tree.id and os.clock() - t0 < 3.5 do
                            TryBreakOnce(tree.x, tree.y, false)
                            task.wait(math.max(0.05, Config.harvestDelay))
                        end

                        if TileValue(w, "fg", tree.x, tree.y) ~= tree.id then
                            actedInPass = true
                            Farmer.stats.harvested = Farmer.stats.harvested + 1
                            Stats.Harvested = Stats.Harvested + 1
                            Farmer.stats.ready = math.max(0, Farmer.stats.ready - 1)

                            -- Auto Collect: Maju sentuh tile bekas pohon agar block yang jatuh langsung terambil!
                            if Config.harvestTake then
                                task.wait(0.14)
                                local px, py = GetTile()
                                if Config.collectMode == "Legit" and px and py == tree.y and math.abs(px - tree.x) <= 3 and not Nav.SolidAt(tree.x, tree.y) and Drops.walkToX then
                                    local wasA = AutoInput.active
                                    AutoInput.active = true
                                    Drops.collecting = true
                                    Drops.walkToX(tree.x + 0.5, 0.9)
                                    Drops.collecting = false
                                    AutoInput.active = wasA
                                    if Drops.waitNearDrops then Drops.waitNearDrops(0.25) end
                                else
                                    task.wait(0.15)
                                end
                            end

                            -- Tanam ulang langsung di tile bekas pohon jika Auto Plant juga dinyalakan
                            if Config.harvestDoPlant and targetSeedId then
                                if CountItem(targetSeedId) <= 0 and Config.harvestAutoTakeSeed ~= false then
                                    CollectDroppedSeedsForPlanting(targetSeedId, token)
                                end
                                if CountItem(targetSeedId) > 0 and CanPlantAt(w, tree.x, tree.y, targetSeedId) then
                                    task.wait(0.06)
                                    if PlaceCell(targetSeedId, { x = tree.x, y = tree.y }, 1) then
                                        Farmer.stats.planted = Farmer.stats.planted + 1
                                        Stats.Planted = Stats.Planted + 1
                                        task.wait(math.max(0.05, Config.harvestPlantDelay))
                                    end
                                end
                            end

                            -- Cek langsung setelah collect pohon ini: apakah block sudah >= 200?
                            if Config.harvestAutoSaveBlock and targetBlockId and CountItem(targetBlockId) >= 200 then
                                ExecuteSaveHarvestBlock(targetBlockId, home, tree.x, tree.y, token)
                                if not Farmer.on or Farmer.token ~= token then return end
                                w = FindWorld()
                            end
                        else
                            failedSet[tree.x .. "," .. tree.y] = true
                            Farmer.stats.skipped = Farmer.stats.skipped + 1
                        end
                    end
                end
            end

            -- FASE 2: AUTO PLANT (+ AUTO TAKE DROPPED SEED SAAT SEED DI TAS HABIS)
            if Config.harvestDoPlant and targetSeedId and #plantSpots > 0 then
                for idx, spot in ipairs(plantSpots) do
                    if not Farmer.on or Farmer.token ~= token or not alive() then return end

                    -- Jika seed di tas habis (0), cek apakah ada dropped seed di world lalu ambil!
                    if CountItem(targetSeedId) <= 0 then
                        if Config.harvestAutoTakeSeed ~= false and FindDroppedSeedInWorld(targetSeedId) then
                            if not CollectDroppedSeedsForPlanting(targetSeedId, token) then
                                Notify("Auto Plant: " .. ItemName(targetSeedId) .. " habis & drop tidak terjangkau!", "Auto Plant", 4)
                                break
                            end
                        else
                            Notify("Auto Plant berhenti: " .. ItemName(targetSeedId) .. " di tas dan di world sudah habis!", "Auto Plant", 4)
                            break
                        end
                    end

                    w = FindWorld()
                    if not w or CurrentWorldName() ~= home.world then return end

                    if CanPlantAt(w, spot.x, spot.y, targetSeedId) then
                        local s = PlayerPhysicsState()
                        if not (s and Nav.StateReaches(s, spot.x, spot.y, R)) then
                            Farmer.status = string.format("Jalan ke tanam (%d,%d) [%d/%d | Seed: %d]", spot.x, spot.y, idx, #plantSpots, CountItem(targetSeedId))
                            Nav.To(spot.x, spot.y, function() return Farmer.token ~= token or not Farmer.on end, R, Config.harvestUseBlock)
                            task.wait(math.max(0.08, Config.harvestTpDelay))
                        end

                        local sCheck = PlayerPhysicsState()
                        if sCheck and Nav.StateReaches(sCheck, spot.x, spot.y, R + 0.5) and CanPlantAt(w, spot.x, spot.y, targetSeedId) then
                            if PlaceCell(targetSeedId, spot, 1) then
                                actedInPass = true
                                Farmer.stats.planted = Farmer.stats.planted + 1
                                Stats.Planted = Stats.Planted + 1
                                Farmer.status = string.format("Tanam %s (%d,%d) [Sisa: %d]", ItemName(targetSeedId), spot.x, spot.y, CountItem(targetSeedId))
                                task.wait(math.max(0.05, Config.harvestPlantDelay))
                            end
                        end
                    end
                end
            end

            if not actedInPass then break end
        end

        AutoMove.pauseCollect = false
        SetAutoFly("autoharvest", false)
        ReleaseInput()
        AutoInput.active = false
        Farmer.status = "Selesai"
        local msg = string.format("Farmer selesai! Panen: %d | Tanam: %d | Drop diambil: %d", Farmer.stats.harvested, Farmer.stats.planted, Farmer.stats.picked)
        Notify(msg)
        Webhook.Send("stop", msg)
    end

    function Farmer.Stop()
        if not Farmer.on then return false end
        Farmer.token += 1
        Farmer.on = false
        AutoMove.pauseCollect = false
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
        if Session.Rotation and Session.Rotation.on then Session.Rotation.Stop() end

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
            AutoMove.pauseCollect = false
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
-- 4. AUTO DIRT FARM (REWRITE: GRID-TRUTH RESUME, REACH-SAFE, LEGIT WALK)
----------------------------------------------------------------------
-- Mekanisme:
--   Pola baris dirt = tiap 2 baris, sejajar baris dirt pertama di bawah White Door.
--   Tiap level dikerjakan dari dalam lorong di atas baris dirt-nya, menyamping satu tile
--   demi satu tile. SEMUA target aksi hanya berjarak dx<=1 / dy<=1 dari tile pijakan,
--   jadi mustahil memasang/menghancurkan di luar jangkauan.
--   Turun level: hancurkan tile di bawah kaki lalu jatuh (dx=0, dy=1, selalu terjangkau).
--   Naik level: lewat tile tangga di kolom parit ujung (platform kalau Use Platform nyala,
--   kalau tidak pakai dirt) memakai A* Legit Walking milik Nav. Tanpa ModFly sama sekali.
--   Resume: tidak ada file progres. Tiap pass dihitung ulang dari grid world, jadi world
--   yang sudah jadi 1/4 atau 1/2 (manual sekalipun) langsung dilanjutkan.
----------------------------------------------------------------------
do (function()
    local BREAK_TIMEOUT = 6.0
    local DIRT_TARGET = 30      -- stok dirt yang dikejar saat restock
    local SEED_TARGET = 6       -- seed minimal sebelum mulai tanam
    local PLANT_BATCH = 12      -- jumlah seed yang ditanam sekali putaran
    local MAX_HOP = 2           -- jarak antar tile kerja yang masih layak dilewati jalan kaki
    local Blocked = {}          -- "x,y" -> os.clock() kedaluwarsa (tile yang gagal dikerjakan)

    ------------------------------------------------------------------
    -- DASAR
    ------------------------------------------------------------------
    local function Cancelled(token)
        return not (DF.on and DF.token == token and alive())
    end

    local function CancelFn(token)
        return function() return Cancelled(token) end
    end

    local function BlockedNow(x, y)
        local t = Blocked[x .. "," .. y]
        return t ~= nil and os.clock() < t
    end

    local function MarkBlocked(x, y, sec)
        Blocked[x .. "," .. y] = os.clock() + (sec or 90)
    end

    local function SettleDelay()
        local ping = 0.10
        pcall(function() ping = Player:GetNetworkPing() end)
        return math.clamp(0.12 + (ping * 2.2), 0.14, 0.55)
    end

    -- Posisi NYATA karakter: tunggu sampai mendarat & berhenti dulu.
    -- Semua pengecekan "sudah sampai?" wajib lewat sini, jangan pernah percaya niat gerak.
    local function Settle(token, maxSec)
        local t0 = os.clock()
        while (os.clock() - t0) < (maxSec or 1.2) do
            if Cancelled(token) then return nil end
            local s = PlayerPhysicsState()
            if not s or s.dead then return nil end
            if s.grounded and math.abs(s.vx or 0) < 1.2 and math.abs(s.vy or 0) < 1.2 then
                return s, math.floor(s.x), math.floor(s.y - 0.475), true
            end
            task.wait(0.04)
        end
        local s = PlayerPhysicsState()
        if not s or s.dead then return nil end
        return s, math.floor(s.x), math.floor(s.y - 0.475), false
    end

    -- Gerbang jangkauan: dipanggil TEPAT sebelum paket dikirim, bukan sekali di awal.
    local function ReachOk(tx, ty, reach)
        local s = PlayerPhysicsState()
        if not s or s.dead or not s.x then return false end
        if not s.grounded or math.abs(s.vx or 0) > 2.5 then return false end
        local r = reach - 0.05
        return math.abs((tx + 0.5) - s.x) <= r and math.abs((ty + 0.5) - (s.y - 0.475)) <= r
    end

    local function BodyOverlaps(tx, ty)
        local s = PlayerPhysicsState()
        if not s or not s.x then return false end
        return (tx + 1 > s.x - 0.30) and (tx < s.x + 0.30) and (ty + 1 > s.y - 0.95) and (ty < s.y)
    end

    local function IsBedrock(id)
        if not id or id == 0 then return false end
        if id == 8 then return true end
        local it = ItemDB and ItemDB[id]
        return type(it) == "table" and type(it.name) == "string"
            and it.name:lower():find("bedrock", 1, true) ~= nil
    end

    local function Breakable(w, x, y, includeBg)
        if not InBounds(w, x, y) or BlockedNow(x, y) then return false end
        local fg = TileValue(w, "fg", x, y) or 0
        if fg ~= 0 then return CanBreakId(fg, x, y) end
        if includeBg ~= false then
            local bg = TileValue(w, "bg", x, y) or 0
            if bg ~= 0 then return CanBreakId(bg, x, y) end
        end
        return false
    end

    -- Tile tangga di kolom parit: platform kalau Use Platform nyala, kalau tidak dirt.
    local function LadderId()
        if Config.dfUsePlatform then
            local p = tonumber(Config.dfPlatformId) or 102
            if p > 0 and CountItem(p) > 0 then return p end
        end
        return GetDirtId()
    end

    ------------------------------------------------------------------
    -- DENAH WORLD
    ------------------------------------------------------------------
    -- topDirtY = baris dirt pertama, yaitu 1 tile di bawah White Door.
    local function Layers(w)
        local doorY
        for y = 0, w.h - 1 do
            for x = 0, w.w - 1 do
                local id = TileValue(w, "fg", x, y) or 0
                if id ~= 0 then
                    local it = ItemDB and ItemDB[id]
                    local nm = (type(it) == "table" and type(it.name) == "string") and it.name:lower() or ""
                    if id == 6 or nm:find("white door", 1, true) then
                        doorY = y
                        break
                    end
                end
            end
            if doorY then break end
        end
        if not doorY and typeof(w.spawn) == "Vector2" then doorY = math.floor(w.spawn.Y) end

        local bedrockY
        for y = (doorY or 10) + 1, w.h - 1 do
            local n = 0
            for x = 0, w.w - 1 do
                if IsBedrock(TileValue(w, "fg", x, y) or 0) then n += 1 end
            end
            if n >= math.floor(w.w * 0.4) then
                bedrockY = y
                break
            end
        end
        return (doorY and (doorY + 1)) or 37, bedrockY or (w.h - 6)
    end

    ------------------------------------------------------------------
    -- AKSI ATOMIK (wajib dikonfirmasi grid server, bukan asumsi)
    ------------------------------------------------------------------
    local function BreakAt(w, x, y, token, includeBg)
        if not InBounds(w, x, y) then return true end
        if not Breakable(w, x, y, includeBg) then return true end

        WaitPlaceGuard(x, y)
        local t0 = os.clock()
        local lastId = -1

        while not Cancelled(token) do
            w = FindWorld()
            if not w then return false end

            if not Breakable(w, x, y, includeBg) then
                task.wait(SettleDelay())
                if not Breakable(FindWorld() or w, x, y, includeBg) then return true end
            end
            if not ReachOk(x, y, PunchReach()) then return false end

            local fg = TileValue(w, "fg", x, y) or 0
            local curId = (fg ~= 0) and fg or (TileValue(w, "bg", x, y) or 0)
            if curId ~= lastId then
                lastId, t0 = curId, os.clock()   -- blok berganti = ada kemajuan nyata
            end
            if (os.clock() - t0) >= BREAK_TIMEOUT then
                MarkBlocked(x, y, 300)
                return false
            end

            local r = TryBreakOnce(x, y, includeBg)
            if r == "broke" then
                DF.stats.broken += 1
                t0 = os.clock()
            elseif r == nil then
                return not Breakable(FindWorld() or w, x, y, includeBg)
            end
            task.wait(math.max(0.04, Config.dfBreakDelay))
        end
        return false
    end

    local function PlaceAt(w, id, x, y, token)
        if not id or id <= 0 or not InBounds(w, x, y) then return false end
        for _ = 1, 3 do
            if Cancelled(token) then return false end
            w = FindWorld()
            if not w then return false end
            if (TileValue(w, "fg", x, y) or 0) == id then return true end
            if CountItem(id) <= 0 then return false end
            if not ReachOk(x, y, BuildReach()) or BodyOverlaps(x, y) then return false end
            local s = PlayerPhysicsState()
            local facing = (s and x >= math.floor(s.x)) and 1 or -1
            if not PlaceCell(id, { x = x, y = y }, facing) then return false end

            local limit = SettleDelay() + 0.35
            local t0 = os.clock()
            repeat
                task.wait(0.05)
                w = FindWorld()
                if w and (TileValue(w, "fg", x, y) or 0) == id then
                    DF.stats.placed += 1
                    return true
                end
            until Cancelled(token) or (os.clock() - t0) >= limit
        end
        return false
    end

    ------------------------------------------------------------------
    -- GERAK (100% Legit Walking, tanpa ModFly / goTo)
    ------------------------------------------------------------------
    -- Langkah 1 tile di dalam lorong. Nav.ExecWalk sudah memverifikasi pendaratan sendiri.
    local function StepTo(x, standY, token)
        local _, cx, cy = Settle(token, 1.0)
        if not cx then return false end
        if cx == x and cy == standY then return true end
        if Nav.ExecWalk(x, standY, CancelFn(token)) then
            local _, nx, ny = Settle(token, 0.8)
            return nx == x and ny == standY
        end
        return false
    end

    -- Pindah ke tile pijakan mana pun: serahkan ke A* Nav, lalu verifikasi posisi nyata.
    local function GoStand(x, standY, token, allowScaffold)
        for attempt = 1, 3 do
            if Cancelled(token) then return false end
            local _, cx, cy = Settle(token, 1.2)
            if cx == x and cy == standY then return true end

            if cy == standY and math.abs((cx or 0) - x) <= 2 then
                if StepTo(x, standY, token) then return true end
            end

            Nav.To(x, standY, CancelFn(token), 0.4, allowScaffold == true)
            local _, nx, ny = Settle(token, 1.2)
            if nx == x and ny == standY then return true end

            -- Masih di bawah target: panjat pakai fungsi pilar Nav yang membersihkan pijakannya sendiri
            if ny and ny > standY and attempt >= 2 then
                Nav.ClimbUpWithDirt(x, standY, CancelFn(token), true, Config.dfTpDelay, false)
                local _, fx, fy = Settle(token, 1.2)
                if fx == x and fy == standY then return true end
            end
            task.wait(0.15)
        end
        return false
    end

    -- Turun 1 level: hancurkan tile di bawah kaki lalu jatuh. Target selalu dx=0, dy=1.
    local function DropOneLevel(w, token, wantStandY)
        local _, cx, cy = Settle(token, 1.2)
        if not cx then return false end
        local guard = 0
        while cy < wantStandY and guard < 6 and not Cancelled(token) do
            guard += 1
            w = FindWorld()
            if not w then return false end
            local floorY = cy + 1
            if not Breakable(w, cx, floorY, false) then
                if (TileValue(w, "fg", cx, floorY) or 0) ~= 0 then return false end
            elseif not BreakAt(w, cx, floorY, token, false) then
                return false
            end
            local _, nx, ny = Settle(token, 1.6)
            if not ny or ny <= cy then return false end
            cx, cy = nx, ny
        end
        return cy == wantStandY
    end

    ------------------------------------------------------------------
    -- RESTOCK DIRT (seed -> tanam -> tunggu -> panen; kalau tanpa seed, break dirt dulu)
    ------------------------------------------------------------------
    local function HarvestTree(w, x, y, seedId, token)
        local it = ItemDB and ItemDB[seedId]
        local grow = (it and (tonumber(it.grow) or tonumber(it.baseGrow))) or 31
        local t0 = os.clock()
        while not Cancelled(token) do
            w = FindWorld()
            if not w or (TileValue(w, "fg", x, y) or 0) ~= seedId then return end
            if IsTreeReady(w, x, y, seedId) or (os.clock() - t0) >= (grow + 6) then break end
            DF.status = string.format("Waiting dirt tree (%ds)...", math.max(0, math.ceil(grow - (os.clock() - t0))))
            task.wait(0.5)
        end
        if not GoStand(x, y, token, false) then return end
        local tB = os.clock()
        while not Cancelled(token) and (TileValue(FindWorld() or w, "fg", x, y) or 0) == seedId
            and (os.clock() - tB) < 6 do
            if not ReachOk(x, y, PunchReach()) then break end
            if TryBreakOnce(x, y, false) == "broke" then Stats.Harvested += 1 end
            task.wait(math.max(0.05, Config.dfBreakDelay))
        end
        task.wait(SettleDelay())
    end

    -- Tanam seed di lorong tempat karakter berdiri, lalu panen satu per satu.
    local function PlantRound(w, standY, token)
        local seedId = GetDirtSeedId()
        local dirtY = standY + 1
        local spots = {}
        local _, cx = Settle(token, 1.0)
        if not cx then return false end

        for d = 0, 18 do
            for _, x in ipairs({ cx + d, cx - d }) do
                if #spots >= PLANT_BATCH or CountItem(seedId) <= #spots then break end
                if x >= 2 and x <= w.w - 3 and x ~= cx
                    and (TileValue(w, "fg", x, standY) or 0) == 0
                    and (TileValue(w, "fg", x, dirtY) or 0) ~= 0
                    and CanPlantAt(w, x, standY, seedId) then
                    spots[#spots + 1] = { x = x, y = standY }
                end
            end
            if #spots >= PLANT_BATCH then break end
        end
        if #spots == 0 then return false end

        local planted = {}
        for _, sp in ipairs(spots) do
            if Cancelled(token) or CountItem(seedId) <= 0 then break end
            local standX = (sp.x > cx) and (sp.x - 1) or (sp.x + 1)
            if GoStand(standX, standY, token, false) then
                DF.status = string.format("Planting dirt seed (%d,%d)", sp.x, sp.y)
                if PlaceAt(w, seedId, sp.x, sp.y, token) then
                    Stats.Planted += 1
                    planted[#planted + 1] = sp
                    task.wait(0.18)
                end
            end
        end
        if #planted == 0 then return false end

        for _, sp in ipairs(planted) do
            if Cancelled(token) then break end
            HarvestTree(w, sp.x, sp.y, seedId, token)
        end
        return true
    end

    -- Tanpa seed: pecah beberapa dirt yang sudah terpasang untuk memancing seed, lalu tambal lagi.
    local function FarmSeedsFromDirt(w, standY, token)
        local dirtId, seedId = GetDirtId(), GetDirtSeedId()
        local dirtY = standY + 1
        local holes = {}
        local _, cx = Settle(token, 1.0)
        if not cx then return false end

        for d = 1, 18 do
            for _, x in ipairs({ cx + d, cx - d }) do
                if CountItem(seedId) >= SEED_TARGET or #holes >= PLANT_BATCH then break end
                if x >= 2 and x <= w.w - 3 and (TileValue(w, "fg", x, dirtY) or 0) == dirtId then
                    local standX = (x > cx) and (x - 1) or (x + 1)
                    if GoStand(standX, standY, token, false) then
                        DF.status = string.format("Breaking dirt for seeds (%d,%d)", x, dirtY)
                        if BreakAt(w, x, dirtY, token, false) then
                            holes[#holes + 1] = { x = x, y = dirtY, standX = standX }
                            task.wait(SettleDelay())
                        end
                    end
                end
            end
            if CountItem(seedId) >= SEED_TARGET or #holes >= PLANT_BATCH then break end
        end

        -- Tambal kembali lubangnya (langkah 7: jangan tinggalkan pola bolong)
        for _, h in ipairs(holes) do
            if Cancelled(token) or CountItem(dirtId) <= 0 then break end
            if GoStand(h.standX, standY, token, false) then
                PlaceAt(w, dirtId, h.x, h.y, token)
            end
        end
        return CountItem(seedId) > 0
    end

    local function Supply(w, token, standY)
        local dirtId = GetDirtId()
        if CountItem(dirtId) > 0 then return true end

        DF.stats.step = "Restock Dirt"
        local rounds = 0
        while not Cancelled(token) and CountItem(dirtId) < DIRT_TARGET and rounds < 6 do
            rounds += 1
            w = FindWorld()
            if not w then return false end

            if CountItem(GetDirtSeedId()) > 0 then
                DF.status = "Dirt empty: planting & harvesting dirt seeds..."
                if not PlantRound(w, standY, token) then
                    if CountItem(dirtId) > 0 then break end
                end
            else
                DF.status = "No dirt seed: breaking dirt to collect seeds..."
                if not FarmSeedsFromDirt(w, standY, token) then break end
            end
        end
        return CountItem(dirtId) > 0
    end

    ------------------------------------------------------------------
    -- SATU LEVEL POLA
    ------------------------------------------------------------------
    -- Daftar kerja baris ini, dihitung dari grid (inilah dasar Smart Resume).
    local function RowTodo(w, dirtY, standY)
        local dirtId = GetDirtId()
        local list = {}
        for x = 2, w.w - 3 do
            local needClear = Breakable(w, x, standY, true)
            local fg = TileValue(w, "fg", x, dirtY) or 0
            local needFloor = false
            if not BlockedNow(x, dirtY) and fg ~= dirtId then
                if fg == 0 or Nav.HazardAt(x, dirtY) then
                    needFloor = true
                elseif Config.dfReplacePlatform and CanBreakId(fg, x, dirtY) then
                    needFloor = true
                end
            end
            if needClear or needFloor then
                list[#list + 1] = { x = x, clear = needClear, floor = needFloor }
            end
        end
        return list
    end

    -- Apa yang masih perlu dikerjakan di satu kolom parit? Dicek dari grid DULU,
    -- supaya karakter tidak berjalan ke ujung world cuma untuk menemukan tidak ada kerjaan.
    local function EdgeSideNeeds(w, dirtY, standY, cols)
        local lid = LadderId()
        for i, col in ipairs(cols) do
            if Breakable(w, col, standY, true) then return true end
            if i == 1 then
                if (TileValue(w, "fg", col, dirtY) or 0) ~= lid and CountItem(lid) > 0 then return true end
            elseif Breakable(w, col, dirtY, true) then
                return true
            end
        end
        return false
    end

    -- Kolom parit ujung: lorong dibersihkan, baris dirt dapat tile tangga.
    local function EdgeWork(w, dirtY, standY, token)
        local W = w.w
        local sides = { { stand = 2, cols = { 1, 0 } }, { stand = W - 3, cols = { W - 2, W - 1 } } }

        -- Sisi terdekat dikerjakan lebih dulu, dan sisi yang tidak ada kerjaannya tidak didatangi
        local _, px = Settle(token, 1.0)
        if px and math.abs(px - sides[2].stand) < math.abs(px - sides[1].stand) then
            sides[1], sides[2] = sides[2], sides[1]
        end

        for _, side in ipairs(sides) do
            if Cancelled(token) then return end
            w = FindWorld()
            if not w then return end
            if EdgeSideNeeds(w, dirtY, standY, side.cols)
                and Nav.RealSupport(side.stand, standY)
                and GoStand(side.stand, standY, token, false) then
                for i, col in ipairs(side.cols) do
                    if Cancelled(token) then return end
                    if Breakable(w, col, standY, true) and ReachOk(col, standY, PunchReach()) then
                        DF.status = string.format("Clearing edge shaft (%d,%d)", col, standY)
                        BreakAt(w, col, standY, token, true)
                    end
                    -- i == 1 -> kolom dalam parit = tempat tangga; kolom terluar dikosongkan
                    if i == 1 then
                        local lid = LadderId()
                        if (TileValue(w, "fg", col, dirtY) or 0) ~= lid and CountItem(lid) > 0 then
                            if Breakable(w, col, dirtY, false) then BreakAt(w, col, dirtY, token, false) end
                            DF.status = string.format("Placing ladder tile (%d,%d)", col, dirtY)
                            PlaceAt(w, lid, col, dirtY, token)
                        end
                    elseif Breakable(w, col, dirtY, true) and ReachOk(col, dirtY, PunchReach()) then
                        BreakAt(w, col, dirtY, token, true)
                    end
                end
            end
        end
    end

    -- Pecah daftar kerja jadi gugus tile yang berdekatan. Tanpa ini, baris yang cuma
    -- bolong di dua ujungnya membuat karakter menyusuri seluruh baris tile per tile.
    local function Clusters(todo)
        local out = {}
        for _, t in ipairs(todo) do
            local last = out[#out]
            if last and (t.x - last.hi) <= (MAX_HOP + 1) then
                last.hi = t.x
            else
                out[#out + 1] = { lo = t.x, hi = t.x }
            end
        end
        return out
    end

    -- Sapu satu gugus saja. Return: progress, stuck
    local function SweepSegment(w, dirtY, standY, startX, endX, step, token)
        local dirtId = GetDirtId()
        local progress, prevNeedFloor = false, nil

        -- Masuk ke lorong dulu; kalau pijakan awalnya belum ada, izinkan Nav pakai pijakan sementara
        if not GoStand(startX, standY, token, true) then
            MarkBlocked(startX, standY, 45)
            return false, true
        end

        for x = startX, endX, step do
            if Cancelled(token) then return progress, true end
            w = FindWorld()
            if not w or CurrentWorldName() ~= DF.homeWorld then return progress, true end

            local _, cx, cy = Settle(token, 1.2)
            if not cx or cy ~= standY then
                -- Terperosok / terlempar: hitung ulang dari posisi nyata, jangan lanjut membabi buta
                if not GoStand(x, standY, token, true) then return progress, true end
                _, cx, cy = Settle(token, 1.0)
                if cy ~= standY then return progress, true end
            end

            -- 1. Kosongkan lorong di depan (dx=1, dy=0)
            if Breakable(w, x, standY, true) and x ~= cx then
                DF.status = string.format("Row Y=%d | clearing (%d,%d)", dirtY, x, standY)
                if BreakAt(w, x, standY, token, true) then progress = true end
            end

            -- 2. Pastikan lantai di depan-bawah = dirt (dx=1, dy=1)
            local fg = TileValue(w, "fg", x, dirtY) or 0
            if x ~= cx and fg ~= dirtId and not BlockedNow(x, dirtY) then
                local replace = (fg ~= 0) and (Nav.HazardAt(x, dirtY) or Config.dfReplacePlatform) and CanBreakId(fg, x, dirtY)
                if fg == 0 or replace then
                    if replace and not BreakAt(w, x, dirtY, token, false) then
                        MarkBlocked(x, dirtY, 120)
                    end
                    if (TileValue(FindWorld() or w, "fg", x, dirtY) or 0) == 0 then
                        if CountItem(dirtId) <= 0 and not Supply(w, token, standY) then
                            DF.status = "Out of dirt & no way to restock"
                            return progress, true
                        end
                        if not GoStand((x == cx) and cx or (x - step), standY, token, false) then
                            return progress, true
                        end
                        DF.status = string.format("Row Y=%d | placing dirt (%d,%d)", dirtY, x, dirtY)
                        if PlaceAt(FindWorld() or w, dirtId, x, dirtY, token) then
                            progress = true
                        else
                            MarkBlocked(x, dirtY, 60)
                        end
                    end
                end
            end

            -- 3. Baru melangkah ke tile itu setelah lantainya dipastikan ada
            if x ~= cx then
                if Nav.RealSupport(x, standY) then
                    if not StepTo(x, standY, token) then
                        if not GoStand(x, standY, token, true) then
                            MarkBlocked(x, standY, 45)
                        end
                    end
                else
                    MarkBlocked(x, dirtY, 60)
                end
            end

            -- 4. Tile pertama gugus: lantainya hanya bisa dikerjakan dari tetangganya
            if prevNeedFloor then
                local f2 = TileValue(FindWorld() or w, "fg", prevNeedFloor, dirtY) or 0
                if f2 ~= dirtId and CountItem(dirtId) > 0 and ReachOk(prevNeedFloor, dirtY, BuildReach()) then
                    if f2 ~= 0 then BreakAt(FindWorld() or w, prevNeedFloor, dirtY, token, false) end
                    if PlaceAt(FindWorld() or w, dirtId, prevNeedFloor, dirtY, token) then progress = true end
                end
                prevNeedFloor = nil
            end
            if x == startX then
                local f0 = TileValue(FindWorld() or w, "fg", startX, dirtY) or 0
                if f0 ~= dirtId then prevNeedFloor = startX end
            end
        end

        -- Tile terakhir yang lantainya belum tergarap: dekati dari tetangganya
        if prevNeedFloor then
            local f3 = TileValue(FindWorld() or w, "fg", prevNeedFloor, dirtY) or 0
            if f3 ~= dirtId and CountItem(dirtId) > 0 then
                local side = (prevNeedFloor < endX) and (prevNeedFloor + 1) or (prevNeedFloor - 1)
                if Nav.RealSupport(side, standY) and GoStand(side, standY, token, false) then
                    if f3 ~= 0 then BreakAt(FindWorld() or w, prevNeedFloor, dirtY, token, false) end
                    if PlaceAt(FindWorld() or w, dirtId, prevNeedFloor, dirtY, token) then progress = true end
                end
            end
        end

        return progress, false
    end

    -- Kerjakan 1 baris dirt. Return: "done" | "progress" | "stuck"
    local function BuildRow(w, dirtY, standY, token)
        local todo = RowTodo(w, dirtY, standY)
        if #todo == 0 then
            EdgeWork(w, dirtY, standY, token)
            return "done"
        end

        DF.stats.step = string.format("Row Y=%d", dirtY)
        local segs = Clusters(todo)
        local progress = false

        while #segs > 0 and not Cancelled(token) do
            -- Gugus terdekat dulu, biar tidak menyeberangi world berkali-kali
            local _, px = Settle(token, 1.2)
            px = px or 2
            local pick, bestD = 1, math.huge
            for i, sg in ipairs(segs) do
                local d = math.min(math.abs(px - sg.lo), math.abs(px - sg.hi))
                if d < bestD then pick, bestD = i, d end
            end
            local sg = table.remove(segs, pick)

            local leftToRight = math.abs(px - sg.lo) <= math.abs(px - sg.hi)
            local startX = leftToRight and sg.lo or sg.hi
            local endX = leftToRight and sg.hi or sg.lo
            local gained = SweepSegment(w, dirtY, standY, startX, endX, leftToRight and 1 or -1, token)
            if gained then progress = true end
            w = FindWorld()
            if not w then return progress and "progress" or "stuck" end
        end

        EdgeWork(FindWorld() or w, dirtY, standY, token)
        if #RowTodo(FindWorld() or w, dirtY, standY) == 0 then return "done" end
        return progress and "progress" or "stuck"
    end

    ------------------------------------------------------------------
    -- LOOP UTAMA
    ------------------------------------------------------------------
    local function DFLoop(token, home)
        table.clear(Blocked)
        SetAutoFly("autodf", false)          -- Auto DF selalu legit walking

        local w = FindWorld()
        if not w then return end
        DF.homeWorld = home.world

        local topDirtY, bedrockY = Layers(w)
        DF.stats.topDirtY, DF.stats.bedrockY = topDirtY, bedrockY
        Notify(string.format("Auto DF: dirt row Y=%d, bedrock Y=%d. Resuming from world grid.", topDirtY, bedrockY))

        -- Daftar baris dirt: dari White Door ke bawah dulu, lalu ke atas (langkah 4-6)
        local rows = {}
        for y = topDirtY, bedrockY - 1, 2 do rows[#rows + 1] = y end
        for y = topDirtY - 2, 2, -2 do rows[#rows + 1] = y end

        local pass = 0
        while not Cancelled(token) and pass < 4 do
            pass += 1
            local left, progressed, firstStuck = 0, false, nil

            for _, dirtY in ipairs(rows) do
                if Cancelled(token) then return end
                w = FindWorld()
                if not w or CurrentWorldName() ~= home.world then
                    DF.status = "World changed, stopping"
                    return
                end

                local standY = dirtY - 1
                if standY >= 0 and #RowTodo(w, dirtY, standY) > 0 then
                    -- Turun ke level berikutnya lewat tile di bawah kaki, bukan lewat parit
                    local _, _, cy = Settle(token, 1.0)
                    if cy and cy < standY and (standY - cy) <= 4 then
                        DF.status = string.format("Digging down to row Y=%d", dirtY)
                        DropOneLevel(w, token, standY)
                    end

                    local r = BuildRow(FindWorld() or w, dirtY, standY, token)
                    if r == "progress" then
                        progressed = true
                        left += 1
                    elseif r == "stuck" then
                        left += 1
                        firstStuck = firstStuck or dirtY
                    else
                        progressed = true
                    end
                end
            end

            if left == 0 then
                DF.stats.step = "Completed"
                DF.status = "Completed"
                local msg = string.format("Full World Dirt Farm finished! Broken: %d | Placed: %d | Drops: %d",
                    DF.stats.broken, DF.stats.placed, DF.stats.picked)
                Notify(msg)
                Webhook.Send("pabrik", msg)
                return
            end
            if not progressed then
                -- Jangan pernah mati diam-diam: sebutkan baris yang menghalangi biar bisa dilacak
                DF.stats.step = "Stuck"
                DF.status = string.format("Stuck at row Y=%s (%d rows left). Check that row manually.",
                    tostring(firstStuck), left)
                Notify("Auto DF stopped: " .. DF.status)
                Webhook.Send("stop", "Auto DF stopped: " .. DF.status)
                return
            end
            table.clear(Blocked)   -- pass berikutnya: beri kesempatan lagi pada tile yang di-skip
        end

        DF.status = "Stopped (pass limit reached)"
    end

    function DF.Stop()
        if not DF.on then return false end
        DF.token += 1
        DF.on = false
        SetAutoFly("autodf", false)
        ReleaseInput()
        AutoInput.active = false
        DF.status = "Idle"
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
        if Session.Rotation and Session.Rotation.on then Session.Rotation.Stop() end

        if not OrigIsDown then
            Notify("Auto DF needs the game movement hook (WorldMenu.isDown). Rejoin and try again.")
            return false
        end
        local x, y = GetGridState()
        if not x then Notify("Character position not detected."); return false end

        local home = { x = math.floor(x), y = math.floor(y - 0.475), world = CurrentWorldName() }
        DF.token += 1
        local token = DF.token
        DF.on = true
        DF.status = "Starting"
        DF.stats = { topDirtY = 0, bedrockY = 0, broken = 0, placed = 0, picked = 0, step = "Initializing" }

        task.spawn(function()
            local ok, err = pcall(DFLoop, token, home)
            if not ok then
                warn("[ANCHHub] Auto DF error: " .. tostring(err))
                Webhook.Send("stop", "Auto DF error: " .. tostring(err))
                DF.status = "Error: " .. tostring(err)
            end
            SetAutoFly("autodf", false)
            ReleaseInput()
            AutoInput.active = false
            if DF.token == token then
                DF.on = false
                if DF.status == "Starting" then DF.status = "Idle" end
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
-- 6. PABRIK / FACTORY (ANTI-STUCK HARVEST, BREAK & DROP SEED)
----------------------------------------------------------------------
do (function()
    local LocalPlantedAt = {} -- Fallback timer pohon lokal jika Refs.Trees belum terbaca sehabis pindah world
    local FailedDropUntil = {}

    local function SavePabrikState(stateTbl)
        if writefile then
            stateTbl.updatedAt = os.time()
            pcall(writefile, PABRIK_STATE_FILE, HttpService:JSONEncode(stateTbl))
        end
    end

    local function ClearPabrikState()
        if writefile then
            pcall(writefile, PABRIK_STATE_FILE, '{"active":false}')
        end
        if isfile and delfile and isfile(PABRIK_STATE_FILE) then
            pcall(delfile, PABRIK_STATE_FILE)
        end
    end

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
        name = Trim(name):upper()
        if name == "" then return false, "empty world name" end
        if CurrentWorldName():upper() == name and not doorId then return true end

        if QueueReload then pcall(QueueReload) end

        for try = 1, 3 do
            if not alive() then return false, "stopped" end
            if CurrentWorldName() ~= "" and (CurrentWorldName():upper() ~= name or doorId) then
                LeaveCurrentWorld()
                task.wait(1.8)
            end
            local w = FindWorld()
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
                Refs.Scan(true)
            end

            local t0 = os.clock()
            while alive() and (os.clock() - t0) < 14 do
                local cw = FindWorld()
                if cw and (rawget(cw, "fg") ~= oldFg or not doorId) and CurrentWorldName():upper() == name and GetTile() then
                    Refs.Scan(true)
                    task.wait(1.0)
                    return true
                end
                task.wait(0.25)
            end
            task.wait(1.5)
        end
        return false, "timeout entering " .. name
    end

    -- Cari dropped item dengan proteksi anti-loop pada drop yang nyangkut/tidak terjangkau
    local function FindDroppedItemInWorld(targetId)
        if not Drops.list and Drops.findRefs then Drops.findRefs() end
        local list = Drops.list
        if type(list) ~= "table" then return nil end
        local px, py = GetTile()
        px, py = px or 50, py or 30
        local dropZone = Pabrik.Zone
        if dropZone and dropZone.world ~= CurrentWorldName() then
            dropZone = nil
        end
        local now = os.clock()
        local best, bestDist = nil, math.huge
        for _, d in ipairs(list) do
            if type(d) == "table" and d.id == targetId and (d.n or 0) > 0 and not d.display and type(d.x) == "number" then
                local key = d.uid or (math.floor(d.x) .. "," .. math.floor(d.y))
                local skipUntil = FailedDropUntil[key]
                local dx, dy = math.floor(d.x), math.floor(d.y)
                if not (skipUntil and now < skipUntil) and not Nav.SolidAt(dx, dy) then
                    if not (dropZone and math.abs(d.x - dropZone.x) <= 2.5 and math.abs(d.y - dropZone.y) <= 2.5) then
                        local dist = math.abs(d.x - px) + math.abs(d.y - py)
                        if dist < bestDist then
                            best, bestDist = d, dist
                        end
                    end
                end
            end
        end
        return best
    end

    -- Ambil semua dropped block dengan batas percobaan agar TIDAK PERNAH diam/infinite loop!
    local function CollectAllDroppedBlocks(blockId, liveFn)
        local collectedAny = false
        local triesPerDrop = {}
        local startSweep = os.clock()

        while liveFn() and CountItem(blockId) < 200 and (os.clock() - startSweep) < 35 do
            local drop = FindDroppedItemInWorld(blockId)
            if not drop then break end
            local key = drop.uid or (math.floor(drop.x) .. "," .. math.floor(drop.y))
            triesPerDrop[key] = (triesPerDrop[key] or 0) + 1
            if triesPerDrop[key] > 2 then
                FailedDropUntil[key] = os.clock() + 45 -- Lewati drop yang nyangkut agar tidak loop stuck!
                continue
            end

            local dx, dy = math.floor(drop.x), math.floor(drop.y)
            local before = CountItem(blockId)
            Pabrik.phase = "COLLECT BLOCK"
            Pabrik.status = string.format("Collecting dropped %s at (%d,%d)...", ItemName(blockId), dx, dy)

            local reached = Nav.To(dx, dy, function() return not liveFn() end, 0.45, false)
            if reached and Drops.walkToX then
                local wasA = AutoInput.active
                AutoInput.active = true
                Drops.collecting = true
                Drops.walkToX(drop.x, 0.8)
                Drops.collecting = false
                AutoInput.active = wasA
            end

            -- Bantu ambil via takeDrop jika dalam jangkauan
            local w = FindWorld()
            local worldTake = w and rawget(w, "takeDrop")
            if type(worldTake) == "function" and drop.uid then
                local room = 200 - CountItem(blockId)
                if room > 0 then pcall(worldTake, drop.uid, math.min(drop.n or 1, room)) end
            end

            task.wait(0.35)
            if CountItem(blockId) > before then
                collectedAny = true
                FailedDropUntil[key] = nil
            elseif not reached then
                FailedDropUntil[key] = os.clock() + 45
            end
        end
        return collectedAny
    end

    -- Drop seed dengan fitur otomatis geser kanan 1 langkah jika tile penuh
    local function DropSeedItem(seedId, amount, liveFn)
        local hud = Refs.Hud or FindInventory()
        local onDrop = hud and rawget(hud, "onDrop")
        local rem = amount
        local stepTries = 0

        while rem > 0 and liveFn() and CountItem(seedId) > 0 and stepTries < 15 do
            local before = CountItem(seedId)
            local dropNow = math.min(rem, before, 200)
            if type(onDrop) == "function" then
                pcall(onDrop, seedId, dropNow)
            elseif DropEvent then
                pcall(function() DropEvent:FireServer(seedId, dropNow) end)
            elseif NetOk and type(Net) == "table" and Net.drop then
                pcall(Net.drop.send, { id = seedId, n = dropNow })
            end
            task.wait(0.8)
            local diff = before - CountItem(seedId)
            if diff > 0 then
                rem = rem - diff
                Pabrik.dropped = Pabrik.dropped + diff
            else
                -- Tile penuh: geser ke kanan 1 tile lalu coba drop lagi!
                stepTries = stepTries + 1
                local cx, cy = GetTile()
                if cx and cy and not Nav.SolidAt(cx + 1, cy) then
                    if Drops.walkToX then
                        local wasA = AutoInput.active
                        AutoInput.active = true
                        Drops.collecting = true
                        Drops.walkToX(cx + 1.5, 1.2)
                        Drops.collecting = false
                        AutoInput.active = wasA
                    else
                        Nav.To(cx + 1, cy, function() return not liveFn() end, 0.35, false)
                    end
                    task.wait(0.25)
                else
                    return amount - rem, "drop tile full"
                end
            end
        end
        return amount - rem, nil
    end

    local function ExecuteDropCycle(seedId, dropAmount, liveFn)
        local targetW, doorId = Pabrik.ParseDropTarget()
        local homeW = Pabrik.home ~= "" and Pabrik.home or CurrentWorldName()
        if targetW == "" then targetW = homeW end

        if Config.pabrikDropX < 0 and not doorId and targetW:upper() == homeW:upper() then
            Pabrik.status = "Drop position not set (skipping drop)"
            Pabrik.dropOffUntil = os.clock() + 60
            return
        end

        Pabrik.traveling = true
        AutoMove.pauseCollect = true -- Matikan auto collect sementara agar seed yang di-drop tidak terambil balik
        local diffWorld = targetW:upper() ~= CurrentWorldName():upper()

        SavePabrikState({
            active = true,
            stage = "dropping",
            homeWorld = homeW,
            targetWorld = targetW,
            doorId = doorId,
            seedId = seedId,
            dropAmount = dropAmount,
        })

        local okTravel, errMsg = true, nil
        if diffWorld or doorId then
            Pabrik.status = "Warping to storage world " .. targetW .. (doorId and (":" .. doorId) or "") .. "..."
            local okE, why = EnterTargetWorld(targetW, doorId)
            if not okE then
                okTravel, errMsg = false, "Failed entering " .. targetW .. " (" .. tostring(why) .. ")"
            end
        end

        if okTravel and liveFn() and Config.pabrikDropX >= 0 and Config.pabrikDropY >= 0 then
            Pabrik.status = string.format("Walking to drop pos (%d,%d)...", Config.pabrikDropX, Config.pabrikDropY)
            local reached = false
            for try = 1, 3 do
                if not liveFn() then break end
                if Nav.To(Config.pabrikDropX, Config.pabrikDropY, function() return not liveFn() end, 0.45, false) then
                    reached = true
                    break
                end
                task.wait(0.3)
            end
            if not reached then
                okTravel, errMsg = false, "Could not reach drop position"
            end
        end

        if okTravel and liveFn() then
            local s = PlayerPhysicsState()
            if s then
                Pabrik.Zone = { world = CurrentWorldName(), x = s.x, y = s.y - 0.475 }
            end
            local droppedN, dropErr = DropSeedItem(seedId, dropAmount, liveFn)
            if droppedN > 0 then
                local msg = string.format("Dropped %s x%d in %s", ItemName(seedId), droppedN, CurrentWorldName())
                Pabrik.status = msg
                Notify(msg, "Factory ANCH")
                Webhook.Send("pabrik", msg)
            end
            if dropErr then okTravel, errMsg = false, dropErr end
            -- Mundur 1 langkah setelah drop di world yang sama agar badan tidak menempel pada tumpukan seed
            if not diffWorld then
                local cx, cy = GetTile()
                if cx and cy and cx > 1 and not Nav.SolidAt(cx - 1, cy) and Drops.walkToX then
                    local wasA = AutoInput.active
                    AutoInput.active = true
                    Drops.collecting = true
                    Drops.walkToX(cx - 0.5, 1.0)
                    Drops.collecting = false
                    AutoInput.active = wasA
                end
            end
        end

        if not okTravel then
            Pabrik.dropOffUntil = os.clock() + 60
            Pabrik.status = "Drop failed: " .. tostring(errMsg)
        end

        SavePabrikState({
            active = true,
            stage = "farming",
            homeWorld = homeW,
            targetWorld = targetW,
            seedId = seedId,
        })

        -- Pastikan karakter BENAR-BENAR kembali ke world Pabrik sebelum melanjutkan loop!
        if homeW ~= "" and CurrentWorldName():upper() ~= homeW:upper() and liveFn() then
            for attempt = 1, 4 do
                if not liveFn() or CurrentWorldName():upper() == homeW:upper() then break end
                Pabrik.status = string.format("Returning to factory world %s (%d/4)...", homeW, attempt)
                if EnterTargetWorld(homeW, nil) then break end
                task.wait(2.5)
            end
        end

        AutoMove.pauseCollect = false
        Pabrik.traveling = false
    end

    function Pabrik.ExternalDropSeed(seedId, dropAmt, dropWorldRaw, dropX, dropY, returnWorld, returnX, returnY, liveFn)
        local origDropW, origX, origY, origHome = Config.pabrikDropWorld, Config.pabrikDropX, Config.pabrikDropY, Pabrik.home
        Config.pabrikDropWorld = dropWorldRaw or ""
        Config.pabrikDropX = dropX or -1
        Config.pabrikDropY = dropY or -1
        Pabrik.home = returnWorld or CurrentWorldName()
        ExecuteDropCycle(seedId, dropAmt, liveFn)
        Config.pabrikDropWorld, Config.pabrikDropX, Config.pabrikDropY, Pabrik.home = origDropW, origX, origY, origHome
        if returnX and returnY and liveFn() then
            Nav.To(returnX, returnY, function() return not liveFn() end, 0.3, false)
        end
    end

    local function CheckAndDropSeedIfReady(seedId, liveFn)
        if not Config.pabrikDrop then return false end
        local sCount = CountItem(seedId)
        local maxSeed = math.max(1, tonumber(Config.pabrikMaxSeed) or 100)
        if sCount > maxSeed and os.clock() >= (Pabrik.dropOffUntil or 0) then
            local dropAmt = sCount - maxSeed
            if dropAmt > 0 then
                Pabrik.phase = "DROP EXCESS SEEDS"
                Pabrik.status = string.format("Seeds %d > Max (%d)! Dropping %d seeds...", sCount, maxSeed, dropAmt)
                ExecuteDropCycle(seedId, dropAmt, liveFn)
                return true
            end
        end
        return false
    end

    -- Cek apakah masih ada blok yang menempel di tile break pabrik
    local function AnyBreakTileHasBlock(w, anchorX, anchorY)
        if not w then return false end
        for key, on in pairs(Config.pabrikTiles) do
            if on then
                local dx, dy = tostring(key):match("^(-?%d+),(-?%d+)$")
                if dx and dy then
                    local tx, ty = anchorX + tonumber(dx), anchorY + tonumber(dy)
                    local fg = TileValue(w, "fg", tx, ty) or 0
                    local bg = TileValue(w, "bg", tx, ty) or 0
                    if (fg ~= 0 and CanBreakId(fg, tx, ty)) or (Config.farmBreakBg and bg ~= 0 and CanBreakId(bg, tx, ty)) then
                        return true
                    end
                end
            end
        end
        return false
    end

    local function RunBreakUntilEmpty(seedId, blockId, liveFn)
        if Config.pabrikBreakX < 0 or Config.pabrikBreakY < 0 then
            Pabrik.status = "Break position not set! Click SetPos Break first."
            Notify("Factory: Click 'SetPos Break' in the Seed Factory tab first!")
            task.wait(2.5)
            return false
        end
        if next(Config.pabrikTiles) == nil then
            Config.pabrikTiles = { ["1,0"] = true }
        end

        while liveFn() do
            CheckAndDropSeedIfReady(seedId, liveFn)
            if not liveFn() then break end

            local w = FindWorld()
            local hasResidualOnTiles = AnyBreakTileHasBlock(w, Config.pabrikBreakX, Config.pabrikBreakY)

            if CountItem(blockId) <= 0 and not hasResidualOnTiles then
                if not CollectAllDroppedBlocks(blockId, liveFn) or CountItem(blockId) <= 0 then
                    break
                end
            end

            Pabrik.phase = "BREAK BLOCK"
            local px, py = GetTile()
            if px ~= Config.pabrikBreakX or py ~= Config.pabrikBreakY then
                Pabrik.status = string.format("Walking to Break Pos (%d,%d)...", Config.pabrikBreakX, Config.pabrikBreakY)
                local reached = false
                for try = 1, 3 do
                    if not liveFn() then break end
                    if Nav.To(Config.pabrikBreakX, Config.pabrikBreakY, function() return not liveFn() end, 0.45, false) then
                        reached = true
                        break
                    end
                    -- Jika tile di sekitar pos break tertutup blok sisa, hancurkan dulu agar bisa berdiri di pos break!
                    local cx, cy = GetTile()
                    if cx and cy and math.abs(cx - Config.pabrikBreakX) <= 2 and math.abs(cy - Config.pabrikBreakY) <= 2 then
                        TryBreakOnce(Config.pabrikBreakX, Config.pabrikBreakY, false)
                    end
                    task.wait(0.35)
                end
                if not reached then
                    Pabrik.status = "Failed walking to Break Pos, retrying..."
                    task.wait(1.5)
                    break
                end
            end
            if not liveFn() then break end

            -- Rapikan posisi tepat ke tengah tile anchor break
            if Drops.walkToX then
                local wasA = AutoInput.active
                AutoInput.active = true
                Drops.collecting = true
                Drops.walkToX(Config.pabrikBreakX + 0.5, 1.0)
                Drops.collecting = false
                AutoInput.active = wasA
            end

            local x, _, facing = GetGridState()
            if not x then break end
            local anchor = {
                x = Config.pabrikBreakX,
                y = Config.pabrikBreakY,
                facing = facing,
                world = CurrentWorldName(),
            }

            Farm.Override = { offsets = Config.pabrikTiles, block = blockId, mode = "Place + Break" }
            Farm.Quiet = true
            Farm.token = Farm.token + 1
            local fToken = Farm.token
            Farm.on = true

            local lastActs = Stats.Placed + Stats.Broken
            local lastActAt = os.clock()
            task.spawn(function()
                while Farm.on and Farm.token == fToken do
                    task.wait(0.4)
                    local acts = Stats.Placed + Stats.Broken
                    if acts ~= lastActs then lastActs, lastActAt = acts, os.clock() end
                    local sCount = CountItem(seedId)
                    local bCount = CountItem(blockId)
                    local cw = FindWorld()
                    local tilesBusy = AnyBreakTileHasBlock(cw, anchor.x, anchor.y)
                    -- PENTING: Jangan matikan Farm.on selama masih ada blok yang menempel di tile break (`tilesBusy`)!
                    if not liveFn()
                        or (bCount <= 0 and not tilesBusy and not Drops.collecting)
                        or (Config.pabrikDrop and sCount >= 195 and not tilesBusy)
                        or (os.clock() - lastActAt > 10) then
                        Farm.on = false
                    end
                end
            end)

            Pabrik.status = string.format("Breaking %s at (%d,%d) [Bag: %d]...", ItemName(blockId), anchor.x, anchor.y, CountItem(blockId))
            pcall(RunFarmLoopDirect, fToken, anchor)
            Farm.on = false
            Farm.Override = nil
            Farm.Quiet = false
            task.wait(0.3)
        end
        return true
    end

    local function IsReservedBreakSpot(x, y)
        if Config.pabrikBreakX < 0 or Config.pabrikBreakY < 0 then return false end
        if x == Config.pabrikBreakX and y == Config.pabrikBreakY then return true end
        for key, on in pairs(Config.pabrikTiles) do
            if on then
                local dx, dy = tostring(key):match("^(-?%d+),(-?%d+)$")
                if dx and dy then
                    if x == (Config.pabrikBreakX + tonumber(dx)) and y == (Config.pabrikBreakY + tonumber(dy)) then
                        return true
                    end
                end
            end
        end
        return false
    end

    local function ScanWorldTrees(w, seedId)
        local readyTrees = {}
        local growingCount = 0
        local soonestWait = nil
        local nowSrv = workspace:GetServerTimeNow()
        local it = ItemDB[seedId]
        local defaultGrow = (it and (tonumber(it.grow) or tonumber(it.baseGrow))) or 31
        local rowDir = 1

        for y = 0, w.h - 1 do
            local rowReady = {}
            for x = 0, w.w - 1 do
                local idx = y * w.w + x
                local fg = TileValue(w, "fg", x, y) or 0
                if fg == seedId then
                    local rAt = TreeReadyAt(w, x, y, fg)
                    -- Fallback jika Refs.Trees belum terbaca: gunakan waktu LocalPlantedAt agar tidak pernah stuck!
                    if not rAt then
                        if not LocalPlantedAt[idx] then
                            LocalPlantedAt[idx] = nowSrv
                        end
                        rAt = LocalPlantedAt[idx] + defaultGrow
                    end

                    if nowSrv >= rAt then
                        table.insert(rowReady, { x = x, y = y, idx = idx })
                    else
                        growingCount = growingCount + 1
                        local rem = rAt - nowSrv
                        if not soonestWait or rem < soonestWait then
                            soonestWait = rem
                        end
                    end
                else
                    LocalPlantedAt[idx] = nil
                end
            end
            if #rowReady > 0 then
                if rowDir == -1 then
                    table.sort(rowReady, function(a, b) return a.x > b.x end)
                else
                    table.sort(rowReady, function(a, b) return a.x < b.x end)
                end
                for _, tr in ipairs(rowReady) do table.insert(readyTrees, tr) end
                rowDir = -rowDir
            end
        end
        return readyTrees, growingCount, soonestWait
    end

    local function PabrikLoop(token, blockId)
        local function liveFn()
            return Pabrik.on and Pabrik.token == token and alive()
        end
        local R = math.min(PunchReach(), BuildReach()) - 0.15

        while liveFn() do
            -- Pastikan kita selalu berada di world Pabrik (jika habis drop seed di world lain dan belum balik)
            if Pabrik.home ~= "" and CurrentWorldName():upper() ~= Pabrik.home:upper() and not Pabrik.traveling then
                Pabrik.status = "Returning to factory world " .. Pabrik.home .. "..."
                EnterTargetWorld(Pabrik.home, nil)
            end

            local w = FindWorld()
            while not w and liveFn() do
                task.wait(1)
                w = FindWorld()
            end
            if not liveFn() then break end

            local seedId = Config.pabrikSeedId
            local maxSeed = math.max(1, tonumber(Config.pabrikMaxSeed) or 100)

            -- 1. Jika ada blok di tas atau drop blok di world, break sampai habis!
            if CountItem(blockId) > 0 or FindDroppedItemInWorld(blockId) ~= nil then
                RunBreakUntilEmpty(seedId, blockId, liveFn)
                if not liveFn() then break end
                w = FindWorld()
            end

            -- 2. Jika seed di tas > Max Seed, drop kelebihannya ke world/posisi penyimpanan!
            CheckAndDropSeedIfReady(seedId, liveFn)
            if not liveFn() then break end
            w = FindWorld()

            -- 3. Fase TANAM SEED (Zig-Zag & dibatasi maksimal sejumlah Max Seed)
            local existingReady, existingGrowing = ScanWorldTrees(w, seedId)
            local totalPlantedInWorld = #existingReady + existingGrowing
            local canPlantMore = math.max(0, maxSeed - totalPlantedInWorld)

            if CountItem(seedId) > 0 and canPlantMore > 0 then
                Pabrik.phase = "PLANT SEED"
                local spots = {}
                local rowDir = 1
                for y = 0, w.h - 1 do
                    local rowSpots = {}
                    for x = 0, w.w - 1 do
                        if (TileValue(w, "fg", x, y) or 0) == 0 and CanPlantAt(w, x, y, seedId) and not IsReservedBreakSpot(x, y) then
                            table.insert(rowSpots, { x = x, y = y })
                        end
                    end
                    if #rowSpots > 0 then
                        if rowDir == -1 then
                            table.sort(rowSpots, function(a, b) return a.x > b.x end)
                        else
                            table.sort(rowSpots, function(a, b) return a.x < b.x end)
                        end
                        for _, sp in ipairs(rowSpots) do table.insert(spots, sp) end
                        rowDir = -rowDir
                    end
                end

                local plantedNow = 0
                for _, sp in ipairs(spots) do
                    if not liveFn() or CountItem(seedId) <= 0 or plantedNow >= canPlantMore then break end
                    w = FindWorld()
                    if w and CanPlantAt(w, sp.x, sp.y, seedId) then
                        local s = PlayerPhysicsState()
                        if not (s and Nav.StateReaches(s, sp.x, sp.y, R)) then
                            Pabrik.status = string.format("Walking Zig-Zag to plant (%d,%d) [%d/%d]", sp.x, sp.y, plantedNow + 1, canPlantMore)
                            Nav.To(sp.x, sp.y, function() return not liveFn() end, R, false)
                        end
                        local sNow = PlayerPhysicsState()
                        if sNow and Nav.StateReaches(sNow, sp.x, sp.y, R + 0.5) and CanPlantAt(w, sp.x, sp.y, seedId) and PlaceCell(seedId, sp, 1) then
                            LocalPlantedAt[sp.y * w.w + sp.x] = workspace:GetServerTimeNow()
                            plantedNow = plantedNow + 1
                            Pabrik.planted = Pabrik.planted + 1
                            Stats.Planted = Stats.Planted + 1
                            Pabrik.status = string.format("Planting %s (%d/%d Max Seed)", ItemName(seedId), totalPlantedInWorld + plantedNow, maxSeed)
                            task.wait(math.max(0.05, Config.harvestPlantDelay))
                        end
                    end
                end
            end

            if not liveFn() then break end
            w = FindWorld()

            -- 4. Cek Pohon: Tunggu tumbuh jika belum ada yang matang
            local readyTrees, growingCount, soonestWait = ScanWorldTrees(w, seedId)

            if #readyTrees == 0 and growingCount > 0 then
                Pabrik.phase = "WAIT GROW"
                while liveFn() do
                    w = FindWorld()
                    if not w then break end
                    readyTrees, growingCount, soonestWait = ScanWorldTrees(w, seedId)
                    if #readyTrees > 0 or growingCount == 0 then
                        break
                    end
                    local waitSec = math.max(1, math.ceil(soonestWait or 15))
                    Pabrik.status = string.format("Waiting for %d trees to grow (±%ds)...", growingCount, waitSec)
                    task.wait(1)
                end
            end

            if not liveFn() then break end

            -- 5. Panen pohon secara Zig-Zag & langsung lewati tile pohon yang pecah agar drop langsung terambil!
            if #readyTrees > 0 then
                Pabrik.phase = "HARVEST ZIG-ZAG"
                for idx, t in ipairs(readyTrees) do
                    if not liveFn() then break end

                    if CountItem(blockId) >= 200 then
                        Pabrik.status = "Blocks reached 200! Going to Break Pos..."
                        RunBreakUntilEmpty(seedId, blockId, liveFn)
                        if not liveFn() then break end
                        CheckAndDropSeedIfReady(seedId, liveFn)
                        if not liveFn() then break end
                    end

                    w = FindWorld()
                    if w and (TileValue(w, "fg", t.x, t.y) or 0) == seedId then
                        local s = PlayerPhysicsState()
                        if not (s and Nav.StateReaches(s, t.x, t.y, R)) then
                            Pabrik.status = string.format("Harvesting Zig-Zag (%d,%d) [%d/%d]", t.x, t.y, idx, #readyTrees)
                            Nav.To(t.x, t.y, function() return not liveFn() end, R, false)
                        end
                        local sNow = PlayerPhysicsState()
                        if sNow and Nav.StateReaches(sNow, t.x, t.y, R + 0.5) then
                            local t0 = os.clock()
                            while liveFn() and (TileValue(w, "fg", t.x, t.y) or 0) == seedId and os.clock() - t0 < 3.5 do
                                local r = TryBreakOnce(t.x, t.y, false)
                                if r == "broke" then
                                    LocalPlantedAt[t.idx or (t.y * w.w + t.x)] = nil
                                    Pabrik.harvested = Pabrik.harvested + 1
                                    Stats.Harvested = Stats.Harvested + 1
                                end
                                task.wait(math.max(0.05, Config.harvestDelay))
                            end
                            -- Segera melangkah ke tile pohon yang baru dipanen agar drop langsung tersentuh badan!
                            local px, py = GetTile()
                            if px and py == t.y and math.abs(px - t.x) <= 3 and not Nav.SolidAt(t.x, t.y) and Drops.walkToX then
                                local wasA = AutoInput.active
                                AutoInput.active = true
                                Drops.collecting = true
                                Drops.walkToX(t.x + 0.5, 0.9)
                                Drops.collecting = false
                                AutoInput.active = wasA
                            end
                            task.wait(0.15)
                        end
                    end
                end

                -- Ambil sisa drop blok di world (dengan anti-stuck) lalu langsung lanjut break & tanam!
                CollectAllDroppedBlocks(blockId, liveFn)
                if CountItem(blockId) > 0 then
                    RunBreakUntilEmpty(seedId, blockId, liveFn)
                end
                CheckAndDropSeedIfReady(seedId, liveFn)
            else
                if CountItem(seedId) <= 0 and CountItem(blockId) <= 0 and FindDroppedItemInWorld(blockId) == nil then
                    Pabrik.status = "Done: All seeds, blocks, and trees are finished."
                    ClearPabrikState()
                    break
                end
            end

            task.wait(0.3)
        end
    end

    function Pabrik.Stop()
        ClearPabrikState()
        if not Pabrik.on then return false end
        Pabrik.token = Pabrik.token + 1
        Pabrik.on = false
        Pabrik.traveling = false
        AutoMove.pauseCollect = false
        if Farm.Override then
            Farm.on = false
            Farm.Override = nil
            Farm.Quiet = false
        end
        ReleaseInput()
        AutoInput.active = false
        Pabrik.phase = "-"
        Pabrik.status = "Idle"
        if UpdateGridVisuals then pcall(UpdateGridVisuals) end
        return true
    end

    function Pabrik.Start(resumeHomeWorld)
        if Pabrik.on then return true end
        local seedId = Config.pabrikSeedId
        local blockId = BlockOfSeed(seedId)
        if not seedId or not blockId then
            Notify("Factory: Select a valid factory Seed ID first!")
            return false
        end
        if Farm.on then StopFarm() end
        if Clear.on then Clear.Stop() end
        if Farmer.on then Farmer.Stop() end
        if DF.on then DF.Stop() end
        if SpliceBot.on then SpliceBot.Stop() end
        if Session.Rotation and Session.Rotation.on then Session.Rotation.Stop() end

        table.clear(FailedDropUntil)
        Pabrik.home = resumeHomeWorld or CurrentWorldName()
        Pabrik.dropOffUntil = 0
        Pabrik.token = Pabrik.token + 1
        local token = Pabrik.token
        Pabrik.on = true
        Pabrik.phase = "STARTING"
        Pabrik.status = "Initializing Seed Factory..."

        SavePabrikState({
            active = true,
            stage = "farming",
            homeWorld = Pabrik.home,
            seedId = seedId,
        })

        if UpdateGridVisuals then pcall(UpdateGridVisuals) end
        if RefreshHub then RefreshHub() end

        task.spawn(function()
            local ok, err = pcall(PabrikLoop, token, blockId)
            if not ok then warn("[ANCHHub] Pabrik error: " .. tostring(err)) end
            AutoMove.pauseCollect = false
            ReleaseInput()
            AutoInput.active = false
            if Pabrik.token == token then
                Pabrik.on = false
                Pabrik.traveling = false
                Pabrik.phase = "-"
                if Pabrik.status == "Initializing Seed Factory..." then Pabrik.status = "Idle" end
                if UpdateGridVisuals then pcall(UpdateGridVisuals) end
                if RefreshHub then RefreshHub() end
            end
        end)
        return true
    end

    function Pabrik.CheckStartup()
        pcall(function()
            if not (isfile and readfile and isfile(PABRIK_STATE_FILE)) then return end
            local raw = readfile(PABRIK_STATE_FILE)
            local st = HttpService:JSONDecode(raw)
            if type(st) ~= "table" or not st.active then return end
            if os.time() - (tonumber(st.updatedAt) or 0) > 1800 then
                ClearPabrikState()
                return
            end

            local t0 = os.clock()
            while alive() and os.clock() - t0 < 30 do
                if CurrentWorldName() ~= "" and GetTile() then break end
                task.wait(1)
            end
            if not alive() or CurrentWorldName() == "" then return end

            Refs.Scan(true)
            task.wait(1.2)
            local curW = CurrentWorldName():upper()
            local homeW = tostring(st.homeWorld or ""):upper()
            local targetW = tostring(st.targetWorld or ""):upper()

            if st.stage == "dropping" and targetW ~= "" and curW == targetW then
                Notify("Resuming Factory Seed Drop in " .. curW .. "...", "Factory ANCH")
                Pabrik.home = st.homeWorld
                Pabrik.on = true
                Pabrik.token = Pabrik.token + 1
                local tk = Pabrik.token
                ExecuteDropCycle(st.seedId or Config.pabrikSeedId, st.dropAmount or 100, function()
                    return Pabrik.on and Pabrik.token == tk and alive()
                end)
                Pabrik.on = false
                if CurrentWorldName():upper() == homeW then
                    Pabrik.Start(st.homeWorld)
                end
            elseif homeW ~= "" and curW == homeW then
                Notify("Resuming Seed Factory in " .. curW .. "!", "Factory ANCH")
                Pabrik.Start(st.homeWorld)
            elseif homeW ~= "" and curW ~= homeW then
                Notify("Returning to Factory world: " .. homeW .. "...", "Factory ANCH")
                if EnterTargetWorld(homeW, nil) then
                    Pabrik.Start(st.homeWorld)
                end
            end
        end)
    end
end)() end

----------------------------------------------------------------------
-- 6B. AUTO MOVE ITEM (WORLD 1 -> WORLD 2 +GESER KANAN + AUTO RESUME)
----------------------------------------------------------------------
do (function()
    local function SaveMoveState(st)
        if writefile then
            st.updatedAt = os.time()
            pcall(writefile, AUTOMOVE_STATE_FILE, HttpService:JSONEncode(st))
        end
    end

    local function ClearMoveState()
        if writefile then
            pcall(writefile, AUTOMOVE_STATE_FILE, '{"active":false}')
        end
        if isfile and delfile and isfile(AUTOMOVE_STATE_FILE) then
            pcall(delfile, AUTOMOVE_STATE_FILE)
        end
    end

    function AutoMove.ParseWorld(rawStr)
        local raw = tostring(rawStr or ""):gsub("%s", "")
        local wName, doorId = string.match(raw, "^([^:]*):(.+)$")
        if not wName then wName = raw end
        wName = string.upper(wName):gsub("[^A-Z0-9]", "")
        if doorId == "" then doorId = nil end
        return wName, doorId
    end

    local function LeaveWorldNow()
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

    local function WarpToTarget(wName, doorId)
        wName = Trim(wName):upper()
        if wName == "" then return false, "nama world kosong" end
        if CurrentWorldName():upper() == wName and not doorId then return true end

        if QueueReload then pcall(QueueReload) end

        if CurrentWorldName() ~= "" then
            LeaveWorldNow()
            task.wait(1.8)
        end

        local w = FindWorld()
        if doorId and w then
            rawset(w, "arriveDoor", doorId)
        end

        local oldFg = w and rawget(w, "fg")
        local m = Refs.Menu
        if m and type(rawget(m, "enter")) == "function" then
            pcall(m.enter, wName)
        elseif w and type(rawget(w, "enter")) == "function" then
            pcall(w.enter, wName)
        else
            return false, "fungsi enter world tidak ditemukan"
        end

        local t0 = os.clock()
        while alive() and (os.clock() - t0) < 12 do
            local cw = FindWorld()
            if cw and rawget(cw, "fg") ~= oldFg and CurrentWorldName():upper() == wName then
                Refs.Scan()
                task.wait(1.2)
                return true
            end
            task.wait(0.25)
        end
        return false, "timeout masuk world " .. wName
    end

    -- Cari dropped item terdekat dengan ID sesuai pilihan user di World 1
    local function FindTargetDropInWorld(itemId)
        if not Drops.list and Drops.findRefs then Drops.findRefs() end
        local list = Drops.list
        if type(list) ~= "table" then return nil, 0 end
        local px, py = GetTile()
        px, py = px or 50, py or 30
        local best, bestDist = nil, math.huge
        local totalCount = 0

        for _, d in ipairs(list) do
            if type(d) == "table" and d.id == itemId and (d.n or 0) > 0 and not d.display and type(d.x) == "number" then
                totalCount = totalCount + (d.n or 0)
                local dist = math.abs(d.x - px) + math.abs(d.y - py)
                if dist < bestDist then
                    best, bestDist = d, dist
                end
            end
        end
        return best, totalCount
    end

    -- Langkah 11-13: Drop item di World 2; jika masih tersisa di tas (tile penuh), geser ke kanan 1 langkah & ulangi
    local function DropWithStepRight(itemId, startX, startY, liveFn)
        local hud = Refs.Hud or FindInventory()
        local onDrop = hud and rawget(hud, "onDrop")
        local curX, curY = startX, startY
        local stepAttempts = 0

        while liveFn() and CountItem(itemId) > 0 and stepAttempts < 25 do
            local before = CountItem(itemId)
            local dropNow = math.min(before, 200)

            AutoMove.status = string.format("Drop %s x%d di (%d,%d)...", ItemName(itemId), dropNow, curX, curY)
            if type(onDrop) == "function" then
                pcall(onDrop, itemId, dropNow)
            elseif DropEvent then
                pcall(function() DropEvent:FireServer(itemId, dropNow) end)
            elseif NetOk and type(Net) == "table" and Net.drop then
                pcall(Net.drop.send, { id = itemId, n = dropNow })
            end

            task.wait(0.85)
            local after = CountItem(itemId)
            local droppedDiff = before - after
            if droppedDiff > 0 then
                AutoMove.dropped = AutoMove.dropped + droppedDiff
            end

            -- Langkah 12 & 13: Cek inventory apakah item sudah hilang; jika masih ada, gerak ke kanan 1 langkah & ulangi!
            if CountItem(itemId) > 0 and liveFn() then
                stepAttempts = stepAttempts + 1
                curX = curX + 1
                local w = FindWorld()
                if w and curX >= w.w - 1 then
                    return false, "Mentok ujung kanan world!"
                end
                AutoMove.status = string.format("Tile penuh! Geser kanan 1 langkah ke (%d,%d)...", curX, curY)
                if not Nav.SolidAt(curX, curY) and Drops.walkToX then
                    local wasA = AutoInput.active
                    AutoInput.active = true
                    Drops.collecting = true
                    Drops.walkToX(curX + 0.5, 1.5)
                    Drops.collecting = false
                    AutoInput.active = wasA
                else
                    Nav.To(curX, curY, function() return not liveFn() end, 0.3, false)
                end
                task.wait(0.25)
            end
        end

        return CountItem(itemId) == 0, nil
    end

    local function AutoMoveLoop(token)
        local function liveFn()
            return AutoMove.on and AutoMove.token == token and alive()
        end

        local itemId = tonumber(Config.moveItemId) or 0
        local w1Name, w1Door = AutoMove.ParseWorld(Config.moveWorld1)
        local w2Name, w2Door = AutoMove.ParseWorld(Config.moveWorld2)

        while liveFn() do
            local haveInBag = CountItem(itemId)

            -- Jika di tas belum penuh (< 200), kita ambil dulu di World 1 (Langkah 6 - 8)
            if haveInBag < 200 then
                AutoMove.pauseCollect = false
                AutoMove.phase = "TAKE (WORLD 1)"

                SaveMoveState({
                    active = true,
                    stage = "taking",
                    w1 = Config.moveWorld1,
                    w2 = Config.moveWorld2,
                    dropX = Config.moveDropX,
                    dropY = Config.moveDropY,
                    itemId = itemId,
                })

                -- Langkah 6: Pindah ke World 1
                if CurrentWorldName():upper() ~= w1Name then
                    AutoMove.traveling = true
                    AutoMove.status = "Pindah ke World 1: " .. w1Name .. (w1Door and (":" .. w1Door) or "") .. "..."
                    local okW1, errW1 = WarpToTarget(w1Name, w1Door)
                    AutoMove.traveling = false
                    if not okW1 then
                        AutoMove.status = "Gagal masuk World 1 (" .. tostring(errW1) .. "), coba lagi..."
                        task.wait(4)
                        continue
                    end
                end

                if not liveFn() then break end
                Refs.Scan()
                if Drops.findRefs then Drops.findRefs() end
                task.wait(0.8)

                -- Langkah 7: Deteksi dropped items di World 1
                local drop, totalInW1 = FindTargetDropInWorld(itemId)

                -- Langkah 15: Jika di World 1 item tersebut sudah habis/kosong
                if not drop then
                    if CountItem(itemId) > 0 then
                        -- Masih ada sisa item di tas yang belum di-drop ke World 2, lanjut ke fase Drop!
                        AutoMove.status = "Drop di World 1 habis, mengantar sisa tas ke World 2..."
                    else
                        -- Di World 1 kosong DAN di tas sudah 0 -> Selesai (Langkah 15-16)!
                        ClearMoveState()
                        AutoMove.pauseCollect = false
                        AutoMove.phase = "SELESAI"
                        local msg = string.format("Auto Move Selesai! %s habis di %s. Total dipindahkan: %d", ItemName(itemId), w1Name, AutoMove.dropped)
                        AutoMove.status = msg
                        Notify(msg, "Auto Move Selesai", 6)
                        Webhook.Send("pabrik", msg)
                        break
                    end
                else
                    -- Langkah 8: Bergerak menuju dropped items & ambil sampai tas penuh (200) atau drop di World 1 habis
                    while liveFn() and CountItem(itemId) < 200 do
                        local targetDrop = FindTargetDropInWorld(itemId)
                        if not targetDrop then break end

                        local tx, ty = math.floor(targetDrop.x), math.floor(targetDrop.y)
                        AutoMove.status = string.format("Ambil %s di (%d,%d) [Tas: %d/200]...", ItemName(itemId), tx, ty, CountItem(itemId))

                        local beforeTake = CountItem(itemId)
                        Nav.To(tx, ty, function() return not liveFn() end, 0.35, false)

                        -- Pastikan tersentuh fisik badan
                        if Drops.walkToX then
                            local wasA = AutoInput.active
                            AutoInput.active = true
                            Drops.collecting = true
                            Drops.walkToX(targetDrop.x, 1.0)
                            Drops.collecting = false
                            AutoInput.active = wasA
                        end

                        -- Bantu juga dengan takeDrop jika berada dalam jangkauan
                        local w = FindWorld()
                        local worldTake = w and rawget(w, "takeDrop")
                        if type(worldTake) == "function" and targetDrop.uid then
                            local room = 200 - CountItem(itemId)
                            if room > 0 then
                                pcall(worldTake, targetDrop.uid, math.min(targetDrop.n or 1, room))
                            end
                        end

                        task.wait(0.35)
                        local afterTake = CountItem(itemId)
                        if afterTake > beforeTake then
                            AutoMove.collected = AutoMove.collected + (afterTake - beforeTake)
                        end
                    end
                end
            end

            if not liveFn() then break end

            -- Langkah 9 - 13: Jika kita sudah membawa item di tas, pindah ke World 2 dan Drop!
            if CountItem(itemId) > 0 then
                AutoMove.phase = "DROP (WORLD 2)"

                -- Langkah 10: Matikan Auto Collect sebelum drop di World 2
                AutoMove.pauseCollect = true

                SaveMoveState({
                    active = true,
                    stage = "dropping",
                    w1 = Config.moveWorld1,
                    w2 = Config.moveWorld2,
                    dropX = Config.moveDropX,
                    dropY = Config.moveDropY,
                    itemId = itemId,
                })

                -- Langkah 9: Move ke World 2
                if CurrentWorldName():upper() ~= w2Name or w2Door then
                    AutoMove.traveling = true
                    AutoMove.status = "Pindah ke World 2: " .. w2Name .. (w2Door and (":" .. w2Door) or "") .. "..."
                    local okW2, errW2 = WarpToTarget(w2Name, w2Door)
                    AutoMove.traveling = false
                    if not okW2 then
                        AutoMove.status = "Gagal masuk World 2 (" .. tostring(errW2) .. "), coba lagi..."
                        task.wait(4)
                        continue
                    end
                end

                if not liveFn() then break end

                -- Tuju Pos Drop di World 2 yang telah ditentukan user
                local dropX, dropY = tonumber(Config.moveDropX) or -1, tonumber(Config.moveDropY) or -1
                if dropX >= 0 and dropY >= 0 then
                    AutoMove.status = string.format("Menuju Pos Drop (%d,%d) di %s...", dropX, dropY, w2Name)
                    local reached = false
                    for try = 1, 3 do
                        if not liveFn() then break end
                        if Nav.To(dropX, dropY, function() return not liveFn() end, 0.35, false) then
                            reached = true
                            break
                        end
                        task.wait(0.3)
                    end
                    if not reached then
                        AutoMove.status = "Gagal jalan ke Pos Drop di World 2, coba ulang..."
                        task.wait(2)
                        continue
                    end
                else
                    local cx, cy = GetTile()
                    dropX, dropY = cx or 50, cy or 30
                end

                -- Pastikan menghadap kanan agar arah drop konsisten
                local s = PlayerPhysicsState()
                if s and (s.facing or 1) < 0 then
                    AutoInput.active = true
                    AutoInput.right = true
                    task.wait(0.06)
                    ReleaseInput()
                    AutoInput.active = false
                end

                -- Langkah 11, 12, 13: Drop(itemId), cek inventory, kalau masih ada geser kanan 1 langkah & ulangi
                local okDrop, dropErr = DropWithStepRight(itemId, dropX, dropY, liveFn)
                if not okDrop and dropErr then
                    AutoMove.status = "Peringatan Drop: " .. tostring(dropErr)
                    task.wait(2)
                end

                -- Langkah 14: Kembali ke World 1 untuk mengecek/mengambil item berikutnya
                SaveMoveState({
                    active = true,
                    stage = "taking",
                    w1 = Config.moveWorld1,
                    w2 = Config.moveWorld2,
                    dropX = Config.moveDropX,
                    dropY = Config.moveDropY,
                    itemId = itemId,
                })
            end

            task.wait(0.3)
        end

        AutoMove.pauseCollect = false
    end

    function AutoMove.Stop()
        ClearMoveState()
        if not AutoMove.on then return false end
        AutoMove.token = AutoMove.token + 1
        AutoMove.on = false
        AutoMove.traveling = false
        AutoMove.pauseCollect = false
        ReleaseInput()
        AutoInput.active = false
        AutoMove.phase = "-"
        AutoMove.status = "Mati"
        if RefreshHub then RefreshHub() end
        return true
    end

    function AutoMove.Start()
        if AutoMove.on then return true end
        local w1Name = AutoMove.ParseWorld(Config.moveWorld1)
        local w2Name = AutoMove.ParseWorld(Config.moveWorld2)
        local itemId = tonumber(Config.moveItemId) or 0

        if w1Name == "" or w2Name == "" then
            Notify("Auto Move: Isi nama World 1 dan World 2 terlebih dahulu!")
            return false
        end
        if Config.moveDropX < 0 or Config.moveDropY < 0 then
            Notify("Auto Move: SetPos Drop di World 2 terlebih dahulu!")
            return false
        end
        if itemId <= 0 or not ItemDB[itemId] then
            Notify("Auto Move: ID Item tidak valid!")
            return false
        end

        if Farm.on then StopFarm() end
        if Clear.on then Clear.Stop() end
        if Farmer.on then Farmer.Stop() end
        if DF.on then DF.Stop() end
        if SpliceBot.on then SpliceBot.Stop() end
        if Pabrik.on then Pabrik.Stop() end

        AutoMove.token = AutoMove.token + 1
        local token = AutoMove.token
        AutoMove.on = true
        AutoMove.phase = "MULAI"
        AutoMove.status = "Inisialisasi Auto Move..."

        if RefreshHub then RefreshHub() end

        task.spawn(function()
            local ok, err = pcall(AutoMoveLoop, token)
            if not ok then warn("[ANCHHub] AutoMove error: " .. tostring(err)) end
            AutoMove.pauseCollect = false
            ReleaseInput()
            AutoInput.active = false
            if AutoMove.token == token then
                AutoMove.on = false
                AutoMove.traveling = false
                if AutoMove.phase ~= "SELESAI" then AutoMove.status = "Mati" end
                if RefreshHub then RefreshHub() end
            end
        end)
        return true
    end

    -- Auto-Resume saat script ke-reload sehabis pindah world / teleport
    function AutoMove.CheckStartup()
        pcall(function()
            if not (isfile and readfile and isfile(AUTOMOVE_STATE_FILE)) then return end
            local raw = readfile(AUTOMOVE_STATE_FILE)
            local st = HttpService:JSONDecode(raw)
            if type(st) ~= "table" or not st.active then return end
            if os.time() - (tonumber(st.updatedAt) or 0) > 1800 then
                ClearMoveState()
                return
            end

            local t0 = os.clock()
            while alive() and (os.clock() - t0) < 30 do
                if CurrentWorldName() ~= "" and GetTile() then break end
                task.wait(1)
            end
            if not alive() or CurrentWorldName() == "" then return end

            Refs.Scan()
            task.wait(1.2)

            if st.w1 then Config.moveWorld1 = st.w1 end
            if st.w2 then Config.moveWorld2 = st.w2 end
            if st.dropX then Config.moveDropX = st.dropX end
            if st.dropY then Config.moveDropY = st.dropY end
            if st.itemId then Config.moveItemId = st.itemId end

            Notify("Melanjutkan progres Auto Move (" .. tostring(st.stage or "aktif") .. ")...", "Auto Move ANCH")
            AutoMove.Start()
        end)
    end
end)() end

----------------------------------------------------------------------
-- 6C. MULTI-WORLD ROTATION (HARVEST -> 200 BLOCK BREAK -> PLANT -> NEXT WORLD)
----------------------------------------------------------------------
Session.Rotation = {
    on = false,
    token = 0,
    worldIndex = 1,
    currentWorld = "-",
    phase = "-",
    status = "Idle",
    harvested = 0,
    broken = 0,
    planted = 0,
    passes = 0,
    traveling = false,
}

do (function()
    local Rot = Session.Rotation

    local function SaveRotState(st)
        if writefile then
            st.updatedAt = os.time()
            pcall(writefile, Session.ROTATION_STATE_FILE, HttpService:JSONEncode(st))
        end
    end

    local function ClearRotState()
        if writefile then
            pcall(writefile, Session.ROTATION_STATE_FILE, '{"active":false}')
        end
        if isfile and delfile and isfile(Session.ROTATION_STATE_FILE) then
            pcall(delfile, Session.ROTATION_STATE_FILE)
        end
    end

    function Rot.ParseWorldsList()
        local out = {}
        local raw = tostring(Config.rotWorlds or "")
        for part in string.gmatch(raw, "[^,\n;]+") do
            local cleaned = Trim(part):gsub("%s", "")
            if cleaned ~= "" then
                local wName, doorId = string.match(cleaned, "^([^:]*):(.+)$")
                if not wName then wName = cleaned end
                wName = string.upper(wName):gsub("[^A-Z0-9]", "")
                if doorId == "" then doorId = nil end
                if wName ~= "" then
                    table.insert(out, { name = wName, door = doorId, raw = wName .. (doorId and (":" .. doorId) or "") })
                end
            end
        end
        return out
    end

    local function WarpToRotWorld(wName, doorId)
        wName = Trim(wName):upper()
        if wName == "" then return false, "empty world name" end
        if CurrentWorldName():upper() == wName and not doorId then return true end

        if QueueReload then pcall(QueueReload) end
        if CurrentWorldName() ~= "" then
            local m = Refs.Menu
            if m and type(rawget(m, "openPicker")) == "function" then
                pcall(m.openPicker)
            else
                local cw = FindWorld()
                if cw and type(rawget(cw, "call")) == "function" then pcall(cw.call, "LeaveWorld") end
            end
            task.wait(1.8)
        end

        local w = FindWorld()
        if doorId and w then rawset(w, "arriveDoor", doorId) end
        local oldFg = w and rawget(w, "fg")
        local m = Refs.Menu
        if m and type(rawget(m, "enter")) == "function" then
            pcall(m.enter, wName)
        elseif w and type(rawget(w, "enter")) == "function" then
            pcall(w.enter, wName)
        else
            return false, "enter function not found"
        end

        local t0 = os.clock()
        while alive() and (os.clock() - t0) < 12 do
            local cw = FindWorld()
            if cw and rawget(cw, "fg") ~= oldFg and CurrentWorldName():upper() == wName then
                Refs.Scan(true)
                task.wait(1.2)
                return true
            end
            task.wait(0.25)
        end
        return false, "timeout entering " .. wName
    end

    local function ScanReadyTreesInWorld(w, seedId)
        local ready = {}
        local nowSrv = workspace:GetServerTimeNow()
        local rowDir = 1
        for y = 0, w.h - 1 do
            local rowList = {}
            for x = 0, w.w - 1 do
                local fg = TileValue(w, "fg", x, y) or 0
                if fg == seedId then
                    local rAt = TreeReadyAt(w, x, y, fg)
                    if rAt and nowSrv >= rAt then
                        table.insert(rowList, { x = x, y = y })
                    end
                end
            end
            if #rowList > 0 then
                if rowDir == -1 then
                    table.sort(rowList, function(a, b) return a.x > b.x end)
                else
                    table.sort(rowList, function(a, b) return a.x < b.x end)
                end
                for _, tr in ipairs(rowList) do table.insert(ready, tr) end
                rowDir = -rowDir
            end
        end
        return ready
    end

    local function CollectDroppedBlockInWorld(blockId, liveFn)
        while liveFn() and CountItem(blockId) < 200 do
            if not Drops.list and Drops.findRefs then Drops.findRefs() end
            local list = Drops.list
            if type(list) ~= "table" then break end
            local px, py = GetTile()
            px, py = px or 50, py or 30
            local best, bestDist = nil, math.huge
            for _, d in ipairs(list) do
                if type(d) == "table" and d.id == blockId and (d.n or 0) > 0 and not d.display and type(d.x) == "number" then
                    local dist = math.abs(d.x - px) + math.abs(d.y - py)
                    if dist < bestDist then best, bestDist = d, dist end
                end
            end
            if not best then break end
            local dx, dy = math.floor(best.x), math.floor(best.y)
            Rot.status = string.format("Collecting dropped %s at (%d,%d)...", ItemName(blockId), dx, dy)
            Nav.To(dx, dy, function() return not liveFn() end, 0.45, false)
            task.wait(0.4)
        end
    end

    -- Fase Break Blok sampai Habis (0 di tas) lalu langsung Tanam Seed hasil break
    local function BreakAllBlocksAndPlant(seedId, blockId, liveFn)
        local R = math.min(PunchReach(), BuildReach()) - 0.15

        -- 1. Break seluruh block di tas sampai 0
        while liveFn() and (CountItem(blockId) > 0) do
            Rot.phase = "BREAK BLOCKS"
            local bx, by = Config.rotBreakX, Config.rotBreakY
            if bx < 0 or by < 0 then
                bx, by = Config.pabrikBreakX, Config.pabrikBreakY
            end
            local px, py = GetTile()
            if bx >= 0 and by >= 0 then
                if px ~= bx or py ~= by then
                    Rot.status = string.format("Walking to Break Pos (%d,%d)...", bx, by)
                    Nav.To(bx, by, function() return not liveFn() end, 0.45, false)
                end
            else
                bx, by = px or 50, py or 30
            end
            if not liveFn() then break end

            local _, _, facing = GetGridState()
            local breakTiles = (next(Config.pabrikTiles) ~= nil) and Config.pabrikTiles or { ["1,0"] = true }
            local anchor = { x = bx, y = by, facing = facing or 1, world = CurrentWorldName() }

            Farm.Override = { offsets = breakTiles, block = blockId, mode = "Place + Break" }
            Farm.Quiet = true
            Farm.token = Farm.token + 1
            local fToken = Farm.token
            Farm.on = true

            local brokenBefore = Stats.Broken
            local lastActs = Stats.Placed + Stats.Broken
            local lastActAt = os.clock()
            task.spawn(function()
                while Farm.on and Farm.token == fToken do
                    task.wait(0.4)
                    local acts = Stats.Placed + Stats.Broken
                    if acts ~= lastActs then lastActs, lastActAt = acts, os.clock() end
                    if not liveFn() or CountItem(blockId) <= 0 or (os.clock() - lastActAt > 8) then
                        Farm.on = false
                    end
                end
            end)

            Rot.status = string.format("Breaking %s [Remaining: %d]...", ItemName(blockId), CountItem(blockId))
            pcall(RunFarmLoopDirect, fToken, anchor)
            Rot.broken = Rot.broken + math.max(0, Stats.Broken - brokenBefore)
            Farm.on = false
            Farm.Override = nil
            Farm.Quiet = false
            task.wait(0.25)

            if CountItem(blockId) <= 0 then
                CollectDroppedBlockInWorld(blockId, liveFn)
            end
        end

        if not liveFn() then return end

        -- 2. Tanam seluruh seed yang ada di tas ke lahan kosong
        if CountItem(seedId) > 0 then
            Rot.phase = "PLANT SEEDS"
            local w = FindWorld()
            if w then
                local spots = {}
                local rowDir = 1
                for y = 0, w.h - 1 do
                    local rowSpots = {}
                    for x = 0, w.w - 1 do
                        if (TileValue(w, "fg", x, y) or 0) == 0 and CanPlantAt(w, x, y, seedId) then
                            table.insert(rowSpots, { x = x, y = y })
                        end
                    end
                    if #rowSpots > 0 then
                        if rowDir == -1 then
                            table.sort(rowSpots, function(a, b) return a.x > b.x end)
                        else
                            table.sort(rowSpots, function(a, b) return a.x < b.x end)
                        end
                        for _, sp in ipairs(rowSpots) do table.insert(spots, sp) end
                        rowDir = -rowDir
                    end
                end

                for idx, sp in ipairs(spots) do
                    if not liveFn() or CountItem(seedId) <= 0 then break end
                    w = FindWorld()
                    if w and CanPlantAt(w, sp.x, sp.y, seedId) then
                        local s = PlayerPhysicsState()
                        if not (s and Nav.StateReaches(s, sp.x, sp.y, R)) then
                            Rot.status = string.format("Planting Zig-Zag (%d,%d) [Seeds: %d]", sp.x, sp.y, CountItem(seedId))
                            Nav.To(sp.x, sp.y, function() return not liveFn() end, R, false)
                        end
                        local sNow = PlayerPhysicsState()
                        if sNow and Nav.StateReaches(sNow, sp.x, sp.y, R + 0.5) and CanPlantAt(w, sp.x, sp.y, seedId) then
                            if PlaceCell(seedId, sp, 1) then
                                Rot.planted = Rot.planted + 1
                                Stats.Planted = Stats.Planted + 1
                                task.wait(math.max(0.05, Config.harvestPlantDelay))
                            end
                        end
                    end
                end
            end
        end
    end

    local function RotationLoop(token, startIdx)
        local function liveFn() return Rot.on and Rot.token == token and alive() end
        local R = math.min(PunchReach(), BuildReach()) - 0.15
        local seedId = tonumber(Config.rotSeedId) or 3
        local blockId = BlockOfSeed(seedId) or GetDirtId()
        Rot.worldIndex = startIdx or 1

        while liveFn() do
            local worlds = Rot.ParseWorldsList()
            if #worlds == 0 then
                Rot.status = "World list is empty!"
                Notify("Rotation: Fill in the World List first!")
                break
            end
            if Rot.worldIndex > #worlds then
                Rot.passes = Rot.passes + 1
                if not Config.rotLoop then
                    ClearRotState()
                    Rot.phase = "DONE"
                    Rot.status = "All worlds finished!"
                    Notify("Multi-World Rotation finished all worlds!", "Rotation ANCH", 5)
                    break
                end
                Rot.worldIndex = 1
            end

            local entry = worlds[Rot.worldIndex]
            Rot.currentWorld = entry.raw
            Rot.phase = "WARP"
            Rot.status = string.format("Entering World [%d/%d]: %s...", Rot.worldIndex, #worlds, entry.raw)

            SaveRotState({
                active = true,
                worldIndex = Rot.worldIndex,
                worlds = Config.rotWorlds,
                seedId = seedId,
            })

            if CurrentWorldName():upper() ~= entry.name or entry.door then
                Rot.traveling = true
                local okW, errW = WarpToRotWorld(entry.name, entry.door)
                Rot.traveling = false
                if not okW then
                    Rot.status = "Failed to enter " .. entry.raw .. " (" .. tostring(errW) .. "), retrying..."
                    task.wait(4)
                    continue
                end
            end

            if not liveFn() then break end
            Refs.Scan()
            if Drops.findRefs then Drops.findRefs() end
            task.wait(1.0)

            -- Kerjakan World ini sampai seluruh pohon ready habis, seluruh block habis di-break, dan seluruh seed tertanam
            while liveFn() do
                local w = FindWorld()
                if not w or CurrentWorldName():upper() ~= entry.name then break end

                -- Jika di tas sudah ada 200 block, break & tanam dulu!
                if CountItem(blockId) >= 200 then
                    BreakAllBlocksAndPlant(seedId, blockId, liveFn)
                    if not liveFn() then break end
                    w = FindWorld()
                end

                local readyTrees = ScanReadyTreesInWorld(w, seedId)
                if #readyTrees == 0 then
                    -- Tidak ada pohon ready lagi di world ini: habiskan sisa block & tanam sisa seed sebelum pindah world!
                    CollectDroppedBlockInWorld(blockId, liveFn)
                    if CountItem(blockId) > 0 or CountItem(seedId) > 0 then
                        BreakAllBlocksAndPlant(seedId, blockId, liveFn)
                    end
                    break
                end

                Rot.phase = "HARVEST"
                for idx, tr in ipairs(readyTrees) do
                    if not liveFn() then break end

                    -- Saat block hasil harvest mencapai 200: STOP harvest, break dulu sampai habis, tanam seed, lalu lanjut harvest!
                    if CountItem(blockId) >= 200 then
                        Rot.status = "Block reached 200! Breaking & Planting before continuing harvest..."
                        BreakAllBlocksAndPlant(seedId, blockId, liveFn)
                        break -- Keluar dari for-loop agar scan ulang pohon ready yang tersisa
                    end

                    w = FindWorld()
                    if w and (TileValue(w, "fg", tr.x, tr.y) or 0) == seedId then
                        local s = PlayerPhysicsState()
                        if not (s and Nav.StateReaches(s, tr.x, tr.y, R)) then
                            Rot.status = string.format("[%s] Harvesting (%d,%d) [%d/%d | Bag: %d/200]", entry.name, tr.x, tr.y, idx, #readyTrees, CountItem(blockId))
                            Nav.To(tr.x, tr.y, function() return not liveFn() end, R, false)
                        end
                        local sNow = PlayerPhysicsState()
                        if sNow and Nav.StateReaches(sNow, tr.x, tr.y, R + 0.5) then
                            local t0 = os.clock()
                            while liveFn() and (TileValue(w, "fg", tr.x, tr.y) or 0) == seedId and (os.clock() - t0) < 3.5 do
                                local r = TryBreakOnce(tr.x, tr.y, false)
                                if r == "broke" then
                                    Rot.harvested = Rot.harvested + 1
                                    Stats.Harvested = Stats.Harvested + 1
                                end
                                task.wait(math.max(0.05, Config.harvestDelay))
                            end
                            task.wait(0.18)
                        end
                    end
                end
            end

            if not liveFn() then break end

            -- Opsional: Simpan kelebihan seed ke World Storage setelah selesai di world ini
            if Config.rotDropExcess and Config.rotSaveWorld ~= "" then
                local keep = tonumber(Config.rotKeepSeed) or 100
                local dropAmt = CountItem(seedId) - keep
                if dropAmt > 0 and Pabrik and Pabrik.ExternalDropSeed then
                    Rot.phase = "DROP SURPLUS"
                    Rot.status = string.format("Dropping %d surplus seeds to %s...", dropAmt, Config.rotSaveWorld)
                    Pabrik.ExternalDropSeed(seedId, dropAmt, Config.rotSaveWorld, Config.rotSaveX, Config.rotSaveY, entry.name, nil, nil, liveFn)
                end
            end

            -- Lanjut ke World berikutnya!
            Webhook.Send("pabrik", string.format("Rotation finished World **%s** (%d/%d). Moving to next world!", entry.name, Rot.worldIndex, #worlds))
            Rot.worldIndex = Rot.worldIndex + 1
            SaveRotState({
                active = true,
                worldIndex = Rot.worldIndex,
                worlds = Config.rotWorlds,
                seedId = seedId,
            })
            task.wait(0.8)
        end
    end

    function Rot.Stop()
        ClearRotState()
        if not Rot.on then return false end
        Rot.token = Rot.token + 1
        Rot.on = false
        Rot.traveling = false
        if Farm.Override then
            Farm.on = false
            Farm.Override = nil
            Farm.Quiet = false
        end
        ReleaseInput()
        AutoInput.active = false
        Rot.phase = "-"
        Rot.status = "Idle"
        if RefreshHub then RefreshHub() end
        return true
    end

    function Rot.Start(resumeIndex)
        if Rot.on then return true end
        local worlds = Rot.ParseWorldsList()
        if #worlds == 0 then
            Notify("Rotation: Enter at least 1 world in the World List!")
            return false
        end
        local seedId = tonumber(Config.rotSeedId) or 0
        if seedId <= 0 or not BlockOfSeed(seedId) then
            Notify("Rotation: Invalid Seed ID!")
            return false
        end

        if Farm.on then StopFarm() end
        if Clear.on then Clear.Stop() end
        if Farmer.on then Farmer.Stop() end
        if DF.on then DF.Stop() end
        if SpliceBot.on then SpliceBot.Stop() end
        if Pabrik.on then Pabrik.Stop() end
        if AutoMove.on then AutoMove.Stop() end

        Rot.token = Rot.token + 1
        local token = Rot.token
        Rot.on = true
        Rot.phase = "STARTING"
        Rot.status = "Initializing Multi-World Rotation..."
        if RefreshHub then RefreshHub() end

        task.spawn(function()
            local ok, err = pcall(RotationLoop, token, resumeIndex or 1)
            if not ok then warn("[ANCHHub] Rotation error: " .. tostring(err)) end
            ReleaseInput()
            AutoInput.active = false
            if Rot.token == token then
                Rot.on = false
                Rot.traveling = false
                if Rot.phase ~= "DONE" then Rot.status = "Idle" end
                if RefreshHub then RefreshHub() end
            end
        end)
        return true
    end

    function Rot.CheckStartup()
        pcall(function()
            if not (isfile and readfile and isfile(Session.ROTATION_STATE_FILE)) then return end
            local raw = readfile(Session.ROTATION_STATE_FILE)
            local st = HttpService:JSONDecode(raw)
            if type(st) ~= "table" or not st.active then return end
            if os.time() - (tonumber(st.updatedAt) or 0) > 1800 then
                ClearRotState()
                return
            end

            local t0 = os.clock()
            while alive() and (os.clock() - t0) < 30 do
                if CurrentWorldName() ~= "" and GetTile() then break end
                task.wait(1)
            end
            if not alive() or CurrentWorldName() == "" then return end

            Refs.Scan(true)
            task.wait(1.2)
            if st.worlds then Config.rotWorlds = st.worlds end
            if st.seedId then Config.rotSeedId = st.seedId end
            Notify("Resuming Multi-World Rotation (World #" .. tostring(st.worldIndex or 1) .. ")...", "Rotation ANCH")
            Rot.Start(tonumber(st.worldIndex) or 1)
        end)
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
-- 7B. VENDING MACHINE BOT (ISI STOCK DARI DROP & KOSONGKAN VENDING)
----------------------------------------------------------------------
local Vend = { on = false, token = 0, status = "Mati", stocked = 0, taken = 0, dropped = 0, picked = {}, carry = {} }

do (function()
    function Vend.ParsePoint()
        local raw = tostring(Config.vendPoint or ""):gsub("%s", "")
        local name, door = string.match(raw, "^([^:|]*)[:|](.+)$")
        if not name then name = raw end
        name = string.upper(name):gsub("[^A-Z0-9]", "")
        if door == "" then door = nil end
        return name, door
    end

    function Vend.Sellable(id)
        if type(id) ~= "number" or id == 112 then return false end
        local it = ItemDB[id]
        if not it or it.kind == "tool" then return false end
        if it.lock or it.area or it.guildLock or it.untradeable or it.vend or it.hub then return false end
        return true
    end

    function Vend.Allow(id)
        if not Vend.Sellable(id) then return false end
        if type(Config.vendItems) == "table" and #Config.vendItems > 0 and not table.find(Config.vendItems, id) then
            return false
        end
        return true
    end

    function Vend.Machines()
        local w = FindWorld()
        local out = {}
        if not w then return out end
        local now = os.clock()
        local cache = Vend.MachCache
        local cands
        if cache and cache.w == w and (now - cache.at) < 10 then
            cands = cache.list
        else
            cands = {}
            for y = 0, w.h - 1 do
                local row = w.fg[y]
                if row then
                    for x = 0, w.w - 1 do
                        local id = row[x] or 0
                        local it = id ~= 0 and ItemDB[id]
                        if it and it.vend then
                            table.insert(cands, { x = x, y = y, fg = id })
                        end
                    end
                end
            end
            Vend.MachCache = { w = w, at = now, list = cands }
        end
        local vends = rawget(w, "vends")
        local owner = rawget(w, "vendOwner")
        for _, m in ipairs(cands) do
            local okO, mine = true, true
            if type(owner) == "function" then okO, mine = pcall(owner, m.x, m.y) end
            if okO and mine then
                local d = nil
                if type(vends) == "table" and type(vends.get) == "function" then
                    local okD, v = pcall(vends.get, m.x, m.y)
                    if okD and type(v) == "table" then d = v end
                end
                d = d or {}
                if not d.shop then
                    table.insert(out, {
                        x = m.x, y = m.y, fg = m.fg, id = d.id,
                        stock = tonumber(d.stock) or 0,
                        cap = (m.fg == 9268) and 10398 or 5199,
                    })
                end
            end
        end
        return out
    end

    function Vend.Call(...)
        local w = FindWorld()
        local f = w and rawget(w, "vendCall")
        if type(f) ~= "function" then return false end
        local ok, res = pcall(f, ...)
        return ok and res == true
    end

    local function VendLoop(token, homeWorld)
        local function liveFn() return Vend.on and Vend.token == token and alive() end
        while liveFn() do
            local machines = Vend.Machines()
            if #machines == 0 then
                Vend.status = "Tidak ada Vending milikmu di world ini!"
                break
            end
            if Config.vendMode == "Kosongkan sampai habis" then
                local emptiedAny = false
                for _, m in ipairs(machines) do
                    if not liveFn() then break end
                    if m.id and m.stock > 0 and Vend.Allow(m.id) then
                        Vend.status = string.format("Mengambil %s dari Vending (%d,%d)...", ItemName(m.id), m.x, m.y)
                        Nav.To(m.x, m.y, function() return not liveFn() end, 0.4, false)
                        local before = CountItem(m.id)
                        Vend.Call("empty", m.x, m.y)
                        task.wait(0.45)
                        local got = CountItem(m.id) - before
                        if got > 0 then
                            Vend.taken = Vend.taken + got
                            emptiedAny = true
                        end
                        if CountItem(m.id) >= 190 and Pabrik and Pabrik.ExternalDropSeed then
                            Pabrik.ExternalDropSeed(m.id, CountItem(m.id), Config.vendPoint, Config.vendDropX, Config.vendDropY, homeWorld, m.x, m.y, liveFn)
                        end
                    end
                end
                if not emptiedAny then
                    Vend.status = "Semua Vending sudah kosong!"
                    break
                end
            else
                -- Mode Isi Stock dari Drop / Tas
                local stockedAny = false
                for _, m in ipairs(machines) do
                    if not liveFn() then break end
                    local id = (m.id and m.stock > 0) and m.id or nil
                    if id and Vend.Allow(id) then
                        local n = math.min(CountItem(id), m.cap - m.stock)
                        if n > 0 then
                            Vend.status = string.format("Mengisi %s +%d ke Vending (%d,%d)...", ItemName(id), n, m.x, m.y)
                            Nav.To(m.x, m.y, function() return not liveFn() end, 0.4, false)
                            if Vend.Call("stock", m.x, m.y, id, n) then
                                Vend.stocked = Vend.stocked + n
                                stockedAny = true
                                task.wait(0.35)
                            end
                        end
                    end
                end
                if not stockedAny then
                    Vend.status = "Menunggu item di tas / drop untuk dimasukkan ke Vending..."
                    task.wait(2)
                end
            end
            task.wait(0.5)
        end
    end

    function Vend.Stop()
        if not Vend.on then return false end
        Vend.token = Vend.token + 1
        Vend.on = false
        Vend.status = "Mati"
        return true
    end

    function Vend.Start()
        if Vend.on then return true end
        Vend.token = Vend.token + 1
        local token = Vend.token
        Vend.on = true
        Vend.status = "Mulai..."
        local home = CurrentWorldName()
        task.spawn(function()
            pcall(VendLoop, token, home)
            if Vend.token == token then
                Vend.on = false
                if RefreshHub then RefreshHub() end
            end
        end)
        return true
    end
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
            if wName ~= "" and not Pabrik.traveling and not AutoMove.traveling and not (Session.Rotation and Session.Rotation.traveling) then
                Config.lastWorld = wName
            end
            if anyBotRunning() and Guard.mode == "idle" then
                Reconnect.last = snapshot()
                Reconnect.lastAt = os.clock()
            else
                -- Jika user sudah mematikan bot, hapus snapshot agar tidak nyala sendiri saat pindah world!
                Reconnect.last = nil
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
            return string.format("%s: %s (%s/hr)", label, formatNum(val), formatNum(val / hours))
        end
        local gNow = Stats.GemsNow()
        if gNow and not Stats.Gems0 then Stats.Gems0 = gNow end
        local gemLine = "Gems: -"
        if gNow and Stats.Gems0 then
            local diff = gNow - Stats.Gems0
            gemLine = string.format("Gems: %s (%s%s, %s/hr)", formatNum(gNow), diff >= 0 and "+" or "", formatNum(diff), formatNum(diff / hours))
        end
        local topArr = {}
        for id, n in pairs(Stats.Items) do table.insert(topArr, { id = id, n = n }) end
        table.sort(topArr, function(a, b) return a.n > b.n end)
        local topStr = {}
        for i = 1, math.min(5, #topArr) do
            topStr[i] = ItemName(topArr[i].id) .. " x" .. formatNum(topArr[i].n)
        end
        return table.concat({
            "Session Time: " .. formatDuration(os.clock() - Stats.T0),
            gemLine,
            rateLine("Blocks Broken", Stats.Broken),
            rateLine("Blocks Placed", Stats.Placed),
            rateLine("Drops Collected", Stats.Collected),
            rateLine("Trees Harvested", Stats.Harvested),
            rateLine("Seeds Planted", Stats.Planted),
            "Top Collected: " .. (#topStr > 0 and table.concat(topStr, ", ") or "-"),
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

    local NameFx = { t0 = os.clock(), tag = nil, panel = nil, cachedTag = nil, cachedPanel = nil, nextScan = 0 }
    local NAME_COLORS = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(48, 255, 106)),
        ColorSequenceKeypoint.new(0.25, Color3.fromRGB(60, 205, 255)),
        ColorSequenceKeypoint.new(0.50, Color3.fromRGB(231, 255, 47)),
        ColorSequenceKeypoint.new(0.75, Color3.fromRGB(60, 205, 255)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(48, 255, 106)),
    })
    local NAME_FONT = Enum.Font.FredokaOne

    local function findCameraNameTag(gg)
        if not gg then return nil end
        -- 1. Cek path klasik jika suatu saat tidak di-obfuscate
        local w = gg:FindFirstChild("World")
        local c = w and w:FindFirstChild("Camera")
        local nt = c and c:FindFirstChild("NameTag")
        if nt then return nt end

        -- 2. Deteksi spesifik Frame NameTag (ZIndex == 1016 & memiliki BitmapText sesuai DisplayName "AyamSuki")
        local dispLen = #(Player.DisplayName or "")
        local nameLen = #(Player.Name or "")
        local fallback1016 = nil

        for _, worldCand in ipairs(gg:GetChildren()) do
            if worldCand:IsA("Frame") then
                for _, camCand in ipairs(worldCand:GetChildren()) do
                    if camCand:IsA("Frame") and camCand:FindFirstChildOfClass("UIScale") then
                        for _, child in ipairs(camCand:GetChildren()) do
                            if child:IsA("Frame") and child.ZIndex == 1016 then
                                local bmp = child:FindFirstChild("BitmapText")
                                if bmp then
                                    local letterCount = #bmp:GetChildren()
                                    if letterCount == dispLen or letterCount == nameLen then
                                        return child
                                    end
                                    fallback1016 = fallback1016 or child
                                end
                            end
                        end
                    end
                end
            end
        end
        return fallback1016
    end

    local function nameHolders()
        local now = os.clock()
        if NameFx.cachedTag and not NameFx.cachedTag.Parent then NameFx.cachedTag = nil end
        if NameFx.cachedPanel and not NameFx.cachedPanel.Parent then NameFx.cachedPanel = nil end

        if (not NameFx.cachedTag or not NameFx.cachedPanel) and now >= NameFx.nextScan then
            NameFx.nextScan = now + 0.5
            local gg = PlayerGui:FindFirstChild("GameGui")
            if not NameFx.cachedTag then
                NameFx.cachedTag = findCameraNameTag(gg)
            end
            if not NameFx.cachedPanel then
                local chat = PlayerGui:FindFirstChild("ChatGui")
                local hud = chat and chat:FindFirstChild("HUD")
                local panel = hud and hud:FindFirstChild("PlayerPanel")
                NameFx.cachedPanel = panel and panel:FindFirstChild("Name")
            end
        end
        return NameFx.cachedTag, NameFx.cachedPanel
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
        local bmp = (e.holder and e.holder:FindFirstChild("BitmapText")) or e.bitmap
        if bmp then pcall(function() bmp.Visible = true end) end
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
        local bmp = holder:FindFirstChild("BitmapText")
        if bmp then
            e.bitmap = bmp
            if bmp.Visible then bmp.Visible = false end
        end
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

   -- ANTI-AFK 3 LAPIS (Matikan Koneksi Idle Bawaan Roblox + Simulasi Input Tiap 60 Detik)
    local afkConn = nil
    local VirtualInputManager = cloneref and cloneref(game:GetService("VirtualInputManager")) or game:GetService("VirtualInputManager")

    local function DisableRobloxIdleConnections()
        if getconnections then
            pcall(function()
                for _, conn in ipairs(getconnections(Player.Idled)) do
                    if conn.Function == nil then
                        if conn.Disable then conn:Disable()
                        elseif conn.Disconnect then conn:Disconnect() end
                    end
                end
            end)
        end
    end

    local function SendAntiAfkPulse()
        pcall(function()
            VirtualUser:CaptureController()
            local cam = workspace.CurrentCamera
            local cf = cam and cam.CFrame or CFrame.new()
            VirtualUser:Button2Down(Vector2.new(0, 0), cf)
            task.wait(0.08)
            VirtualUser:Button2Up(Vector2.new(0, 0), cf)
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end

    function StartAntiAfk()
        if antiAfkOn then return true end
        antiAfkOn = true
        DisableRobloxIdleConnections()
        afkConn = trackConn(Player.Idled:Connect(function()
            if antiAfkOn and alive() then
                DisableRobloxIdleConnections()
                SendAntiAfkPulse()
            end
        end))
        task.spawn(function()
            while antiAfkOn and alive() do
                DisableRobloxIdleConnections()
                SendAntiAfkPulse()
                task.wait(60)
            end
        end)
        return true
    end

    function StopAntiAfk()
        if not antiAfkOn then return false end
        antiAfkOn = false
        if afkConn then afkConn:Disconnect(); afkConn = nil end
        return true
    end

    -- ====================================================================
    -- FAST PULL / FAST KICK / FAST BAN (AUTO CLOSE MENUGUI.PLAYER 0ms)
    -- ====================================================================
    local lastClickTileX, lastClickTileY = nil, nil
    local cachedWrenchModal = nil

    trackConn(UserInputService.InputBegan:Connect(function(inp)
        if not alive() then return end
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            local tx, ty = Nav.ScreenToTile(inp.Position)
            if tx and ty then
                lastClickTileX, lastClickTileY = tx, ty
            end
        end
    end))

    local function GetActiveFastWrenchCmd()
        if Config.fastPull then return "pull", "Fast Pull" end
        if Config.fastKick then return "kick", "Fast Kick" end
        if Config.fastBan then return "ban", "Fast Ban" end
        return nil, nil
    end

    -- Tutup dialog Wrench (Upval[6] / PlayerGui.MenuGui.Player) menggunakan fungsi close() asli milik game
    local function CloseWrenchPlayerModal(modalTbl)
        local m = modalTbl or cachedWrenchModal
        if type(m) == "table" then
            cachedWrenchModal = m
            local closeFn = rawget(m, "close")
            if type(closeFn) == "function" then
                pcall(closeFn)
            end
            local box = rawget(m, "box")
            if typeof(box) == "Instance" and box:IsA("GuiObject") then
                pcall(function() box.Visible = false end)
            end
        end
        pcall(function()
            local menuGui = PlayerGui:FindFirstChild("MenuGui")
            local playerModal = menuGui and menuGui:FindFirstChild("Player")
            if playerModal and playerModal:IsA("GuiObject") then
                playerModal.Visible = false
            end
        end)
    end

    -- Ambil target {userId, name} dan tabel kontroler dialog (Upval[6]) langsung dari Call Stack Stack[6]
    local function InspectWrenchCallStack(arg1)
        local foundUid, foundName, foundModal = nil, nil, nil
        if not (debug and debug.info and getupvalueFn) then
            return nil, nil, nil
        end

        for stackLvl = 2, 10 do
            local okF, callerFn = pcall(debug.info, stackLvl, "f")
            if not okF or type(callerFn) ~= "function" then break end
            for upIdx = 1, 20 do
                local okU, uv = pcall(getupvalueFn, callerFn, upIdx)
                if not okU then break end
                if type(uv) == "table" then
                    -- Deteksi Upval[6]: {close:function, isOpen:function, setHeight:function, box:Instance, area:Instance}
                    if not foundModal and type(rawget(uv, "close")) == "function"
                        and type(rawget(uv, "isOpen")) == "function"
                        and rawget(uv, "box") ~= nil then
                        foundModal = uv
                        cachedWrenchModal = uv
                    end
                    -- Deteksi Upval[2] / Upval[5]: {id:number, userId:number, name:string}
                    local uid = tonumber(rawget(uv, "userId"))
                    local pid = tonumber(rawget(uv, "id"))
                    local pname = rawget(uv, "name")
                    if uid and uid > 1000 and uid ~= Player.UserId then
                        if not foundUid or (arg1 ~= nil and pid == tonumber(arg1)) then
                            foundUid = uid
                            foundName = type(pname) == "string" and pname:gsub("`.", "") or tostring(uid)
                        end
                    end
                end
            end
        end
        return foundUid, foundName, foundModal
    end

    local function ResolveWrenchedTargetUid(arg1)
        -- 1. Prioritas Utama: Baca langsung dari Upvalue Stack[6] (100% akurat sesuai hasil Spy)
        local stackUid, stackName, stackModal = InspectWrenchCallStack(arg1)
        if stackUid then
            return stackUid, stackName, stackModal
        end

        -- 2. Fallback: Cek melalui Refs.Others (list, playerAt, where)
        local o = Refs.Others
        if not o then Refs.Scan(); o = Refs.Others end
        local candidates = {}

        if o and type(rawget(o, "list")) == "function" then
            local ok, list = pcall(o.list)
            if ok and type(list) == "table" then
                for idx, e in pairs(list) do
                    if type(e) == "table" then
                        local uid = tonumber(e[1] or e.userId)
                        local name = tostring(e[2] or e.name or uid or ""):gsub("`.", "")
                        if uid and uid ~= Player.UserId then
                            if arg1 ~= nil and (idx == arg1 or e.id == arg1 or e.pid == arg1) then
                                return uid, name, stackModal
                            end
                            table.insert(candidates, { uid = uid, name = name })
                        end
                    end
                end
            end
        end

        if o and lastClickTileX and lastClickTileY and type(rawget(o, "where")) == "function" and #candidates > 0 then
            local bestUid, bestName, bestDist = nil, nil, math.huge
            for _, c in ipairs(candidates) do
                local okW, wx, wy = pcall(o.where, c.uid)
                if okW and type(wx) == "table" then wx, wy = wx.x or wx[1], wx.y or wx[2] end
                if okW and type(wx) == "number" and type(wy) == "number" then
                    local dist = math.abs(wx - lastClickTileX) + math.abs(wy - lastClickTileY)
                    if dist < bestDist then
                        bestUid, bestName, bestDist = c.uid, c.name, dist
                    end
                end
            end
            if bestUid and bestDist <= 6 then
                return bestUid, bestName, stackModal
            end
        end

        if #candidates >= 1 then
            return candidates[1].uid, candidates[1].name, stackModal
        end

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= Player then
                return plr.UserId, plr.DisplayName or plr.Name, stackModal
            end
        end

        return nil, nil, stackModal
    end

    -- Pantau juga MenuGui.Player secara langsung agar tidak sempat berkedip saat Fast Wrench aktif
    pcall(function()
        local menuGui = PlayerGui:FindFirstChild("MenuGui")
        local playerFrame = menuGui and menuGui:FindFirstChild("Player")
        if playerFrame and playerFrame:IsA("GuiObject") then
            trackConn(playerFrame:GetPropertyChangedSignal("Visible"):Connect(function()
                if alive() and playerFrame.Visible and GetActiveFastWrenchCmd() then
                    if os.clock() - (G.__ANCH_LastFastWrench or 0) < 0.8 then
                        CloseWrenchPlayerModal(cachedWrenchModal)
                    end
                end
            end))
        end
    end)

    -- Pulihkan fungsi asli Net.call walaupun sudah pernah ter-hook oleh eksekusi script sebelumnya
    if not G.__ANCH_TrueOrigNetCall and NetOk and type(Net) == "table" and type(Net.call) == "function" then
        local curCall = Net.call
        if isexecutorclosure and pcall(isexecutorclosure, curCall) and isexecutorclosure(curCall) then
            for _, u in pairs(GetUpvalues(curCall)) do
                if type(u) == "function" and not (pcall(isexecutorclosure, u) and isexecutorclosure(u)) then
                    G.__ANCH_TrueOrigNetCall = u
                    break
                end
            end
        else
            G.__ANCH_TrueOrigNetCall = curCall
        end
    end

    local origNetCall = G.__ANCH_TrueOrigNetCall or (NetOk and type(Net) == "table" and Net.call) or nil
    local hookedUpvalues = {}
    local lastFastWrenchClock = 0
    local wrapperFn

    local function ExecuteFastWrenchOn(callFn, fastCmd, fastLabel, targetUid, targetName, modalTbl)
        lastFastWrenchClock = os.clock()
        G.__ANCH_LastFastWrench = lastFastWrenchClock

        -- 1. Langsung tutup dialog MenuGui.Player saat ini juga (0ms)
        CloseWrenchPlayerModal(modalTbl)

        -- 2. Tutup lagi pada task.defer (setelah Stack[6] selesai di frame yang sama, sebelum layar di-render)
        task.defer(function()
            CloseWrenchPlayerModal(modalTbl)
        end)

        -- 3. Kirim paket WorldCommand pull/kick/ban #<UserId> & pastikan status busy = 0
        task.spawn(function()
            pcall(callFn, "WorldCommand", fastCmd, "#" .. tostring(targetUid))
            pcall(callFn, "SetBusy", 0)
            task.wait(0.04)
            CloseWrenchPlayerModal(modalTbl)
            Notify(string.format("%s -> %s (#%s)", fastLabel, tostring(targetName or "Player"), tostring(targetUid)), fastLabel, 2)
        end)
    end

    local function FastWrenchInterceptor(callFn, cmdName, arg1, ...)
        local fastCmd, fastLabel = GetActiveFastWrenchCmd()
        if fastCmd then
            if cmdName == "GetPlayerLevel" or cmdName == "WrenchPlayer" or cmdName == "PlayerInfo" then
                local targetUid, targetName, modalTbl = ResolveWrenchedTargetUid(arg1)
                if targetUid then
                    if os.clock() - lastFastWrenchClock > 0.15 then
                        ExecuteFastWrenchOn(callFn, fastCmd, fastLabel, targetUid, targetName, modalTbl)
                    else
                        CloseWrenchPlayerModal(modalTbl)
                    end
                    -- Kembalikan nil secara instan tanpa menghubungi server & tanpa membekukan thread
                    return nil
                end
            elseif cmdName == "SetBusy" and arg1 == 2 then
                if os.clock() - lastFastWrenchClock < 1.0 then
                    CloseWrenchPlayerModal(cachedWrenchModal)
                    return false
                end
            end
        end
        return callFn(cmdName, arg1, ...)
    end

    if origNetCall then
        wrapperFn = function(cmdName, arg1, ...)
            if not alive() then return origNetCall(cmdName, arg1, ...) end
            return FastWrenchInterceptor(origNetCall, cmdName, arg1, ...)
        end
        Net.call = wrapperFn

        if Refs.World and type(rawget(Refs.World, "call")) == "function" then
            rawset(Refs.World, "call", wrapperFn)
        end

        if getgcFn and getupvalueFn and setupvalueFn then
            task.spawn(function()
                for _, fn in ipairs(getgcFn(false)) do
                    if type(fn) == "function" and fn ~= wrapperFn and fn ~= FastWrenchInterceptor then
                        if not (isexecutorclosure and pcall(isexecutorclosure, fn) and isexecutorclosure(fn)) then
                            for i = 1, 30 do
                                local okU, val = pcall(getupvalueFn, fn, i)
                                if not okU then break end
                                if type(val) == "function" then
                                    local isOldWrapper = false
                                    if isexecutorclosure and pcall(isexecutorclosure, val) and isexecutorclosure(val) then
                                        for _, uu in pairs(GetUpvalues(val)) do
                                            if uu == origNetCall then
                                                isOldWrapper = true
                                                break
                                            end
                                        end
                                    end
                                    if val == origNetCall or isOldWrapper then
                                        pcall(setupvalueFn, fn, i, wrapperFn)
                                        table.insert(hookedUpvalues, { fn = fn, idx = i, orig = origNetCall })
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        end
    end

    function Session.RestoreFastWrench()
        if origNetCall and NetOk and type(Net) == "table" then
            Net.call = origNetCall
        end
        if origNetCall and Refs.World and rawget(Refs.World, "call") == wrapperFn then
            pcall(rawset, Refs.World, "call", origNetCall)
        end
        if setupvalueFn then
            for _, h in ipairs(hookedUpvalues) do
                pcall(setupvalueFn, h.fn, h.idx, h.orig)
            end
        end
        table.clear(hookedUpvalues)
    end

    -- ====================================================================
    -- FAST DROP & FAST RECYCLE/TRASH (INTERCEPT UPVAL[5] openDialog 0ms)
    -- ====================================================================
    local bpInvRef = nil
    local bpGridCells = nil
    local hookedDialogUpvalues = {}

    local function CloseBackpackInfoDialog()
        pcall(function()
            local invGui = PlayerGui:FindFirstChild("InventoryGui")
            local infoDlg = invGui and invGui:FindFirstChild("InfoDialog")
            if infoDlg and infoDlg:IsA("GuiObject") then
                infoDlg.Visible = false
            end
        end)
    end

    local function GetSelectedBackpackItemId()
        local inv = bpInvRef or Refs.Inv
        if inv then
            local sel = rawget(inv, "selected")
            if type(sel) == "number" and sel > 0 then
                if CountItem(sel) > 0 then
                    return sel
                end
                local slots = rawget(inv, "slots")
                if type(slots) == "table" and type(slots[sel]) == "table" and tonumber(slots[sel].id) then
                    return tonumber(slots[sel].id)
                end
                if ItemDB[sel] then
                    return sel
                end
            end
        end
        if type(bpGridCells) == "table" then
            for _, cell in pairs(bpGridCells) do
                if type(cell) == "table" and typeof(cell.sel) == "Instance" and cell.sel.Visible and tonumber(cell.id) then
                    return tonumber(cell.id)
                end
            end
        end
        return nil
    end

    local function ExecuteFastDropNow()
        CloseBackpackInfoDialog()
        local itemId = GetSelectedBackpackItemId()
        if not itemId then
            Notify("Pilih item di Backpack terlebih dahulu!", "Fast Drop", 2)
            return
        end
        local have = CountItem(itemId)
        if have <= 0 then
            Notify("Item sudah habis di tas!", "Fast Drop", 2)
            return
        end
        local cfgCount = math.floor(tonumber(Config.fastDropCount) or 0)
        local dropAmt = (cfgCount <= 0) and have or math.min(cfgCount, have)

        task.spawn(function()
            local hud = Refs.Hud or FindInventory()
            local onDrop = hud and rawget(hud, "onDrop")
            if type(onDrop) == "function" then
                pcall(onDrop, itemId, dropAmt)
            elseif DropEvent then
                pcall(function() DropEvent:FireServer(itemId, dropAmt) end)
            elseif NetOk and type(Net) == "table" and Net.drop then
                pcall(Net.drop.send, { id = itemId, n = dropAmt })
            end
            CloseBackpackInfoDialog()
            Notify(string.format("Fast Drop: %s x%d", ItemName(itemId), dropAmt), "Fast Drop", 2)
        end)
    end

    local function ExecuteFastRecycleNow()
        CloseBackpackInfoDialog()
        local itemId = GetSelectedBackpackItemId()
        if not itemId then
            Notify("Pilih item di Backpack terlebih dahulu!", "Fast Recycle", 2)
            return
        end
        local have = CountItem(itemId)
        if have <= 0 then
            Notify("Item sudah habis di tas!", "Fast Recycle", 2)
            return
        end
        local cfgCount = math.floor(tonumber(Config.fastRecycleCount) or 0)
        local recAmt = (cfgCount <= 0) and have or math.min(cfgCount, have)

        task.spawn(function()
            if Bag and type(Bag.Recycle) == "function" then
                local ok = Bag.Recycle(itemId, recAmt)
                CloseBackpackInfoDialog()
                if ok then
                    local invTbl = FindInventory()
                    if invTbl and type(rawget(invTbl, "refresh")) == "function" then
                        pcall(invTbl.refresh)
                    end
                    Notify(string.format("Fast Recycle: %s x%d", ItemName(itemId), recAmt), "Fast Recycle", 2)
                else
                    Notify(ItemName(itemId) .. " tidak bisa di-recycle!", "Fast Recycle", 2)
                end
            end
        end)
    end

    local dropHandlerFn = nil
    local recycleHandlerFn = nil
    local lastClickedBpAction = nil
    local lastClickedBpClock = 0

    local function HookFastBackpackActions()
        local invGui = PlayerGui:FindFirstChild("InventoryGui")
        local holder = invGui and invGui:FindFirstChild("Holder")
        local bp = holder and holder:FindFirstChild("Backpack")
        local actions = bp and bp:FindFirstChild("Actions")
        if not actions or not getconnections or not getupvalueFn or not setupvalueFn then return end

        for _, child in ipairs(actions:GetChildren()) do
            if child:IsA("GuiButton") then
                for _, sig in ipairs({ child.Activated, child.MouseButton1Click }) do
                    local okC, conns = pcall(getconnections, sig)
                    if okC and type(conns) == "table" then
                        for _, c in ipairs(conns) do
                            local fn = c.Function
                            if type(fn) == "function" and not (isexecutorclosure and pcall(isexecutorclosure, fn) and isexecutorclosure(fn)) then
                                local ok1, u1 = pcall(getupvalueFn, fn, 1)
                                local ok2, u2 = pcall(getupvalueFn, fn, 2)
                                local ok3, u3 = pcall(getupvalueFn, fn, 3)
                                local ok5, u5 = pcall(getupvalueFn, fn, 5)
                                if ok2 and type(u2) == "table" and rawget(u2, "drop") and rawget(u2, "recycle") and ok5 and type(u5) == "function" then
                                    bpInvRef = (ok1 and type(u1) == "table") and u1 or bpInvRef
                                    bpGridCells = (ok3 and type(u3) == "table") and u3 or bpGridCells

                                    local dropBtn = rawget(u2, "drop")
                                    local recBtn = rawget(u2, "recycle")

                                    if child == dropBtn then
                                        dropHandlerFn = fn
                                        if not dropBtn:GetAttribute("ANCHDropHook") then
                                            dropBtn:SetAttribute("ANCHDropHook", true)
                                            trackConn(dropBtn.InputBegan:Connect(function(inp)
                                                if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                                                    lastClickedBpAction = "drop"
                                                    lastClickedBpClock = os.clock()
                                                end
                                            end))
                                        end
                                    elseif child == recBtn then
                                        recycleHandlerFn = fn
                                        if not recBtn:GetAttribute("ANCHRecHook") then
                                            recBtn:SetAttribute("ANCHRecHook", true)
                                            trackConn(recBtn.InputBegan:Connect(function(inp)
                                                if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                                                    lastClickedBpAction = "recycle"
                                                    lastClickedBpClock = os.clock()
                                                end
                                            end))
                                        end
                                    end

                                    if not G.__ANCH_TrueOrigOpenDialog then
                                        if isexecutorclosure and pcall(isexecutorclosure, u5) and isexecutorclosure(u5) then
                                            for _, uu in pairs(GetUpvalues(u5)) do
                                                if type(uu) == "function" and not (pcall(isexecutorclosure, uu) and isexecutorclosure(uu)) then
                                                    G.__ANCH_TrueOrigOpenDialog = uu
                                                    break
                                                end
                                            end
                                        else
                                            G.__ANCH_TrueOrigOpenDialog = u5
                                        end
                                    end

                                    local origOpenDlg = G.__ANCH_TrueOrigOpenDialog
                                    if origOpenDlg and u5 ~= Session.SharedDialogWrapper then
                                        Session.SharedDialogWrapper = function(...)
                                            if alive() then
                                                local caller = (debug and debug.info and debug.info(2, "f")) or nil
                                                local isDrop = (caller and dropHandlerFn and caller == dropHandlerFn)
                                                    or (lastClickedBpAction == "drop" and (os.clock() - lastClickedBpClock) < 0.5)
                                                local isRec = (caller and recycleHandlerFn and caller == recycleHandlerFn)
                                                    or (lastClickedBpAction == "recycle" and (os.clock() - lastClickedBpClock) < 0.5)

                                                if isDrop and not isRec then
                                                    lastClickedBpAction = nil
                                                    if Config.fastDrop then
                                                        ExecuteFastDropNow()
                                                        return
                                                    end
                                                elseif isRec and not isDrop then
                                                    lastClickedBpAction = nil
                                                    if Config.fastRecycle then
                                                        ExecuteFastRecycleNow()
                                                        return
                                                    end
                                                end
                                            end
                                            return origOpenDlg(...)
                                        end
                                        pcall(setupvalueFn, fn, 5, Session.SharedDialogWrapper)
                                        table.insert(hookedDialogUpvalues, { fn = fn, idx = 5, orig = origOpenDlg })
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    task.spawn(function()
        while alive() do
            pcall(HookFastBackpackActions)
            task.wait(1.5)
        end
    end)

    function Session.RestoreFastBackpack()
        if setupvalueFn then
            for _, h in ipairs(hookedDialogUpvalues) do
                pcall(setupvalueFn, h.fn, h.idx, h.orig)
            end
        end
        table.clear(hookedDialogUpvalues)
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
-- FEATURES REGISTRY & AUTO-RELOAD SESSION
----------------------------------------------------------------------
local Features = {
    blink = { label = "Skin Blink", get = function() return blinkOn end, set = function(on) return on and StartBlink() or StopBlink() end },
    longhand = { label = "Longhand Reach", get = function() return longhandOn end, set = function(on) return on and ApplyLonghand() or StopLonghand() end },
    noclip = { label = "Noclip / ModFly", get = function() return noclipOn end, set = function(on) return on and StartNoclip() or StopNoclip() end },
    ujump = { label = "Unlimited Jump", get = function() return ujumpOn end, set = function(on) return on and StartUjump() or StopUjump() end },
    antiafk = { label = "Anti-AFK", get = function() return antiAfkOn end, set = function(on) return on and StartAntiAfk() or StopAntiAfk() end },
    autorejoin = { label = "Auto Reconnect", get = function() return Config.reconnectOn end, set = function(on) return on and StartAutoRejoin() or StopAutoRejoin() end },
    god = { label = "God Mode", get = function() return godOn end, set = function(on) return on and StartGod() or StopGod() end },
    clicktp = { label = "Click TP", get = function() return Nav.clickOn end, set = function(on) return on and Nav.StartClick() or Nav.StopClick() end },
    lite = { label = "Lite Mode (FPS Boost)", get = function() return Config.liteMode end, set = function(on) LiteMode.Set(on); return true end },
    guard = { label = "Anti-Mod Guard", get = function() return Guard.on end, set = function(on) Guard.Set(on); return true end },
    autochat = { label = "Auto Chat", noSession = true, get = function() return Spam.on end, set = function(on) Spam.on = on; if on then Spam.nextAt = 0 end; return true end },
    autoclear = { label = "Auto Clear World", noSession = true, get = function() return Clear.on end, set = function(on) return on and Clear.Start() or Clear.Stop() end },
    autoharvest = { label = "Farmer (Harvest/Plant)", noSession = true, get = function() return Farmer.on end, set = function(on) return on and Farmer.Start() or Farmer.Stop() end },
    automove = { label = "Auto Move Item", noSession = true, get = function() return AutoMove.on end, set = function(on) return on and AutoMove.Start() or AutoMove.Stop() end },
    autodf = { label = "Auto Dirt Farm", noSession = true, get = function() return DF.on end, set = function(on) return on and DF.Start() or DF.Stop() end },
    autosplice = { label = "Auto Splice", noSession = true, get = function() return SpliceBot.on end, set = function(on) return on and SpliceBot.Start() or SpliceBot.Stop() end },
    pabrik = { label = "Seed Factory", noSession = true, get = function() return Pabrik.on end, set = function(on) return on and Pabrik.Start() or Pabrik.Stop() end },
    autofarm = { label = "Auto Farm", noSession = true, get = function() return Farm.on and not Farm.Override end, set = function(on) return on and StartFarm() or StopFarm() end },
    autoquest = { label = "Auto Quest", get = function() return questOn end, set = function(on) return on and StartQuest() or StopQuest() end },
    rotation = { label = "Multi-World Rotation", noSession = true, get = function() return Session.Rotation.on end, set = function(on) return on and Session.Rotation.Start() or Session.Rotation.Stop() end },
}

local function SetFeature(key, on)
    local feature = Features[key]
    if not feature then return end
    if UIInitializing and feature.noSession then return end
    feature.set(on)
    if feature.get() == on then
        Notify(feature.label .. (on and " enabled." or " disabled."))
        if not feature.noSession then
            Config.session[key] = on or nil
        else
            Config.session[key] = nil
        end
        SaveConfig()
    end
    if RefreshHub then RefreshHub() end
end

local lastQueuedClock = 0

local function ReloadSource()
    if type(G.ANCHHub_ReloadCode) == "string" and G.ANCHHub_ReloadCode ~= "" then
        return G.ANCHHub_ReloadCode
    end
    local url = Config.scriptUrl
    if type(url) ~= "string" or url == "" then url = G.ANCHHubURL end
    if type(url) == "string" and url ~= "" then
        return string.format("loadstring(game:HttpGet(%q))()", url)
    end
    if isfile and readfile then
        for _, fname in ipairs({ SCRIPT_FILE, "ANCHHub-Test.lua", "ANCHHub.lua", "ANCHHub_Loader.lua" }) do
            local okF, ex = pcall(isfile, fname)
            if okF and ex then
                return string.format("loadstring(readfile(%q))()", fname)
            end
        end
    end
    return nil
end

local function GetQueueFn()
    return queue_on_teleport
        or (syn and syn.queue_on_teleport)
        or (fluxus and fluxus.queue_on_teleport)
        or (getgenv and getgenv().queue_on_teleport)
end

-- Hanya mengantri 1 kali per sesi server + proteksi anti-dobel eksekusi di dalam payload
QueueReload = function()
    if not Config.autoReload or G.__ANCHHub_TeleportQueued then return false end
    local qFn, src = GetQueueFn(), ReloadSource()
    if not qFn or not src then return false end
    local guardedSrc = "local g=(getgenv and getgenv()) or _G; if g.__ANCH_TpLock and (os.clock()-g.__ANCH_TpLock)<6 then return end; g.__ANCH_TpLock=os.clock(); " .. src
    local ok = pcall(qFn, guardedSrc)
    if ok then
        G.__ANCHHub_TeleportQueued = true
    end
    return ok
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
-- FLOATING 5X5 GRID GUI (DUAL MODE: FARM / FACTORY) & FLYPAD
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
        ModeBtn.Text = isPabrik and "Factory" or "Farm"
        ModeBtn.BackgroundColor3 = isPabrik and Color3.fromRGB(200, 120, 40) or Color3.fromRGB(60, 60, 75)
        Title.Text = isPabrik and "Factory Break Tiles" or "ANCH Grid (Farm)"
        for key, btn in pairs(CellButtons) do
            btn.BackgroundColor3 = tbl[key] and COLOR_ON or COLOR_OFF
        end
        if isPabrik then
            GridStart.Text = Pabrik.on and "STOP FACTORY" or "START FACTORY"
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
    ClearBtn.Text = "Clear Selection"
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
-- MAIN GUI (WINDUI - FULL ENGLISH + LOCAL CACHE FOR INSTANT LOAD)
----------------------------------------------------------------------
local Window
do (function()
local WindUI
do
    local WINDUI_CACHE_FILE = "ANCHHub_WindUI_Cache.lua"
    local src = G.__ANCH_WindUISource
    if type(src) ~= "string" or #src < 1000 then
        if isfile and readfile then
            local okF, exists = pcall(isfile, WINDUI_CACHE_FILE)
            if okF and exists then
                local okR, content = pcall(readfile, WINDUI_CACHE_FILE)
                if okR and type(content) == "string" and #content > 1000 then
                    src = content
                end
            end
        end
    end
    if type(src) ~= "string" or #src < 1000 then
        local okH, fetched = pcall(function()
            return game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua")
        end)
        if okH and type(fetched) == "string" and #fetched > 1000 then
            src = fetched
            G.__ANCH_WindUISource = src
            if writefile then pcall(writefile, WINDUI_CACHE_FILE, src) end
        end
    end
    if type(src) == "string" and #src > 1000 then
        G.__ANCH_WindUISource = src
        WindUI = loadstring(src)()
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

Window = WindUI:CreateWindow({
    Title = "ANCH Hub  |  GrowBlox Beta",
    Folder = "ANCHHub_GrowBlox",
    Icon = "solar:folder-2-bold-duotone",
    NewElements = true,
    HideSearchBar = false,
    Theme = "Indigo",
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
})

Window:DisableTopbarButtons({ "Fullscreen" })

pcall(function()
    Window:Tag({
        Title = "V1.3 EN",
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
        warn("[ANCHHub UI] Error in " .. tostring(label) .. ": " .. tostring(err))
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

-- Sections
local MainSection     = Window:Section({ Title = "Main Section", Opened = true })
local AutoSection     = Window:Section({ Title = "Automation", Opened = true })
local HelperSection   = Window:Section({ Title = "Fast Helpers", Opened = true })
local BagWorldSection = Window:Section({ Title = "Inventory & World", Opened = true })
local SecuritySection = Window:Section({ Title = "Safety & Utility", Opened = true })
local SystemSection   = Window:Section({ Title = "System & Settings", Opened = true })

-- 1A. Tab: Dashboard & Statistics ------------------------------------
SafeUI("Tab:Dashboard", function()
    local Tab = MainSection:Tab({
        Title = "Dashboard & Stats",
        Icon = "solar:home-2-bold",
        IconColor = Green,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.features = Tab

    local statusPara = Tab:Paragraph({
        Title = "Character & Game Connection Status",
        Desc = "Detecting position...",
    })

    local statsPara = Tab:Paragraph({
        Title = "Real-Time Session Statistics",
        Desc = "Loading stats...",
    })

    task.spawn(function()
        while alive() and task.wait(0.6) do
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
                        string.format("World: %s  |  Tile Position: (%d, %d)", wName ~= "" and wName or "-", tx, ty),
                        refLine
                    )
                else
                    SetElementText(statusPara, "Character Status: Outside World", refLine)
                end
                SetElementText(statsPara, "Real-Time Session Statistics", Stats.Text())
            end)
        end
    end)

    Tab:Button({
        Title = "Rescan Game References (Reconnect Refs)",
        Color = Color3.fromHex("#305dff"),
        Justify = "Center",
        Callback = function()
            Refs.Scan(true)
            Notify("Game references refreshed!")
        end,
    })

    local stGrp = Tab:Group({})
    stGrp:Button({
        Title = "Reset Stats",
        Justify = "Center",
        Callback = function() Stats.Reset(); Notify("Session statistics reset.") end,
    })
    stGrp:Button({
        Title = "Send Stats to Discord",
        Justify = "Center",
        Callback = function()
            if not (Config.webhookOn and Webhook.Valid(Config.webhookUrl)) then
                Notify("Enable & set your Discord Webhook URL in System & Settings first!")
            else
                Webhook.Send("report", "Session Statistics Report\n```\n" .. Stats.Text() .. "\n```")
                Notify("Statistics report queued for Discord!")
            end
        end,
    })
end)

-- 1B. Tab: Character & Movement --------------------------------------
SafeUI("Tab:Character", function()
    local Tab = MainSection:Tab({
        Title = "Character & Movement",
        Icon = "solar:square-transfer-horizontal-bold",
        IconColor = Blue,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.nav = Tab

    local navPara = Tab:Paragraph({ Title = "Universal Navigation Status", Desc = "Last: -" })

    Tab:Dropdown({
        Title = "Universal Movement Method (DF / Farmer / Factory / Clear)",
        Desc = "Legit Walking = Physical A* pathfinding | Teleport Mode = Tile-by-tile real-time stepper.",
        Values = { "Legit Walking", "Teleport Mode" },
        Value = Config.moveMethod or "Legit Walking",
        Callback = function(v)
            Config.moveMethod = v or "Legit Walking"
            Config.moveMode = (Config.moveMethod == "Teleport Mode") and "fly" or "legit"
            SaveConfig()
            Notify("Movement method set to: " .. Config.moveMethod)
        end,
    })

    Tab:Space()

    task.spawn(function()
        while alive() and task.wait(0.6) do
            pcall(function()
                SetElementText(
                    navPara,
                    "Movement Mode: " .. Config.moveMode:upper(),
                    "Click TP Status: " .. tostring(Nav.last) .. " | Scaffolds Placed: " .. Nav.PlacedScaffolds
                )
            end)
        end
    end)

    AddFeatureToggle(Tab, "Click TP (Legit A* Pathfinding)", "Tap/click anywhere on screen to automatically walk & climb to that tile.", "clicktp")
    AddFeatureToggle(Tab, "Noclip + FlyPad (▲/▼)", "Fly through blocks and display on-screen Up/Down buttons.", "noclip")
    AddFeatureToggle(Tab, "Unlimited Jump (Air Jump)", "Jump infinitely in mid-air.", "ujump")
    AddFeatureToggle(Tab, "God Mode (Hazard Immunity)", "Immune to lava, spikes, fire, and deadly obstacles.", "god")
    AddFeatureToggle(Tab, "Longhand (Extended Reach)", "Extend your punch and build range.", "longhand")
    AddFeatureToggle(Tab, "Lite Mode (FPS Boost)", "Disable particles & punch sound effects for higher FPS.", "lite")
    AddFeatureToggle(Tab, "Skin Blink", "Automatically cycle character skin colors.", "blink")
    AddFeatureToggle(Tab, "Anti-AFK", "Prevent idle disconnection.", "antiafk")

    Tab:Space()
    Tab:Section({ Title = "Speed & Auto Collect Radius" })

    Tab:Slider({
        Title = "Character Walkspeed (%)",
        Desc = "100% = normal game speed.",
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
        Title = "Always Collect Nearby Drops",
        Value = Config.collectAround,
        Callback = function(on) Config.collectAround = on; SaveConfig() end,
    })

    Tab:Slider({
        Title = "Auto Collect Radius (Tiles)",
        IsTooltip = true,
        Step = 1,
        Value = { Min = 1, Max = 8, Default = math.clamp(Config.collectRadius, 1, 8) },
        Callback = function(v) Config.collectRadius = math.floor(tonumber(v) or 3); SaveConfig() end,
    })

    Tab:Toggle({
        Title = "Require Holding Shift for Click TP (PC)",
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

    local farmStatusPara = Tab:Paragraph({ Title = "Auto Farm Status", Desc = "Loading..." })

    task.spawn(function()
        while alive() and task.wait(0.5) do
            pcall(function()
                local id = Config.farmPlaceId
                SetElementText(
                    farmStatusPara,
                    "Status: " .. Farm.stats.status .. " (" .. Config.farmMode .. ")",
                    string.format(
                        "Block: %s [ID %d] (In Bag: %d)\nPlaced: %d | Broken: %d | Collected: %d | Cycles: %d",
                        ItemName(id), id, CountItem(id),
                        Farm.stats.placed, Farm.stats.broken, Farm.stats.picked, Farm.stats.cycles
                    )
                )
            end)
        end
    end)

    AddFeatureToggle(Tab, "Enable Auto Farm", "Automatically place & break blocks based on the 5x5 Grid.", "autofarm")

    Tab:Dropdown({
        Title = "Auto Collect Mode (Legit Physical / Remote)",
        Desc = "Legit = Physical sweep & small jump (anti-reject). Remote = Collect from range.",
        Values = { "Legit", "Remote" },
        Value = (Config.collectMode == "Remote") and "Remote" or "Legit",
        Callback = function(v)
            Config.collectMode = (v == "Remote") and "Remote" or "Legit"
            SaveConfig()
            Notify("Auto Collect Mode: " .. Config.collectMode)
        end,
    })

    Tab:Toggle({
        Title = "Hand Swing & Place Visual Effects",
        Desc = "Show arm swing animation and particle effects locally.",
        Value = Config.visualAnim,
        Callback = function(on) Config.visualAnim = on; SaveConfig() end,
    })

    Tab:Button({
        Title = "Open 5x5 Floating Grid (Farm Mode)",
        Color = Color3.fromHex("#305dff"),
        Justify = "Center",
        Callback = function()
            if SetGridMode then SetGridMode("farm") end
            if GridGui then GridGui.Enabled = not GridGui.Enabled end
        end,
    })

    Tab:Space()
    Tab:Section({ Title = "Farm Mode & Speed" })

    local farmModeMap = {
        ["Place + Break"] = "Place + Break",
        ["Break Only"] = "Break saja",
        ["Place Only"] = "Place saja",
    }
    local farmModeRev = {
        ["Place + Break"] = "Place + Break",
        ["Break saja"] = "Break Only",
        ["Place saja"] = "Place Only",
    }

    Tab:Dropdown({
        Title = "Auto Farm Mode",
        Values = { "Place + Break", "Break Only", "Place Only" },
        Value = farmModeRev[Config.farmMode] or "Place + Break",
        Callback = function(v)
            Config.farmMode = farmModeMap[v] or "Place + Break"
            SaveConfig()
        end,
    })

    Tab:Slider({
        Title = "Multi-Target Break (1 - 5 Tiles)",
        Desc = "Hit multiple tiles in rotation. Automatically uses Rayman Fist if equipped!",
        IsTooltip = true,
        Step = 1,
        Value = { Min = 1, Max = 5, Default = math.clamp(Config.farmMultiTarget, 1, 5) },
        Callback = function(v) Config.farmMultiTarget = math.clamp(math.floor(tonumber(v) or 1), 1, 5); SaveConfig() end,
    })

    Tab:Input({
        Title = "Farm Block ID",
        Value = tostring(Config.farmPlaceId),
        Placeholder = "e.g. 2 (Dirt)",
        Callback = function(text)
            local v = tonumber(text)
            if v and v > 0 then
                Config.farmPlaceId = math.floor(v)
                SaveConfig()
                Notify("Farm Block: " .. ItemName(Config.farmPlaceId) .. " [" .. Config.farmPlaceId .. "]")
            end
        end,
    })

    local searchMap = {}
    local searchDd
    Tab:Input({
        Title = "Search Block in Database",
        Placeholder = "Type block name...",
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
            if #vals == 0 then vals = { "No results" } end
            if searchDd and searchDd.Refresh then pcall(function() searchDd:Refresh(vals) end) end
        end,
    })

    searchDd = Tab:Dropdown({
        Title = "Select Search Result",
        Values = { "Type a block name above..." },
        Callback = function(sel)
            local id = searchMap[sel]
            if id then
                Config.farmPlaceId = id
                SaveConfig()
                Notify("Block set to: " .. ItemName(id) .. " [" .. id .. "]")
            end
        end,
    })

    Tab:Slider({
        Title = "Place Delay (ms)",
        IsTooltip = true,
        Step = 10,
        Value = { Min = 50, Max = 1000, Default = math.clamp(Config.farmPlaceMs, 50, 1000) },
        Callback = function(v) Config.farmPlaceMs = tonumber(v) or 250; SaveConfig() end,
    })

    Tab:Input({
        Title = "Break Delay (seconds)",
        Value = tostring(Config.farmDelay),
        Placeholder = "0.22",
        Callback = function(text)
            local v = tonumber(text)
            if v and v >= 0.03 and v <= 5 then Config.farmDelay = v; SaveConfig() end
        end,
    })

    Tab:Toggle({
        Title = "Auto Collect Drops",
        Value = Config.farmTake,
        Callback = function(on) Config.farmTake = on; SaveConfig() end,
    })

    Tab:Space()
    Tab:Section({ Title = "Fast Break, Anti-Detection & Auto Refill Block" })

    Tab:Toggle({
        Title = "Fast Break (Zero-Drift + Cooldown Gate Reset)",
        Desc = "Eliminates frame drift between hits for maximum server-allowed break speed.",
        Value = Config.farmFastBreak,
        Callback = function(on) Config.farmFastBreak = on; SaveConfig() end,
    })

    Tab:Toggle({
        Title = "Dynamic Delay (Anti-Detection Rhythm Jitter)",
        Desc = "Automatically randomizes each punch & place delay (e.g. 0.12s, 0.17s, 0.20s) to bypass server rhythm detection.",
        Value = Config.farmDynamicDelay,
        Callback = function(on) Config.farmDynamicDelay = on; SaveConfig() end,
    })

    Tab:Slider({
        Title = "Dynamic Jitter Range (+/- ms)",
        IsTooltip = true,
        Step = 5,
        Value = { Min = 10, Max = 100, Default = math.clamp(Config.farmDynamicJitterMs or 45, 10, 100) },
        Callback = function(v) Config.farmDynamicJitterMs = math.floor(tonumber(v) or 45); SaveConfig() end,
    })

    Tab:Toggle({
        Title = "Auto Refill Block When Depleted (World-to-World Support)",
        Desc = "When blocks run out, automatically pick up floating blocks in current world or warp to Refill World and return.",
        Value = Config.farmAutoRefill,
        Callback = function(on) Config.farmAutoRefill = on; SaveConfig() end,
    })

    Tab:Input({
        Title = "Refill Stock World (Empty = Current World | WORLD | WORLD:DOOR)",
        Value = Config.farmRefillWorld,
        Placeholder = "e.g. STORAGE1 or STORAGE1:DOOR1",
        Callback = function(t) Config.farmRefillWorld = Trim(t or ""); SaveConfig() end,
    })

    Tab:Space()
    Tab:Section({ Title = "Auto Save / Drop Seeds (When Seeds >= Threshold)" })

    Tab:Toggle({
        Title = "Enable Auto Drop Seeds When Full",
        Desc = "Automatically pause farming, drop seeds at target world/pos, and return to resume Auto Farm.",
        Value = Config.farmAutoDropSeed,
        Callback = function(on) Config.farmAutoDropSeed = on; SaveConfig() end,
    })

    Tab:Slider({
        Title = "Drop When Seed Count Reaches >=",
        IsTooltip = true,
        Step = 5,
        Value = { Min = 20, Max = 200, Default = math.clamp(Config.farmSeedDropAt or 200, 20, 200) },
        Callback = function(v) Config.farmSeedDropAt = math.floor(tonumber(v) or 200); SaveConfig() end,
    })

    Tab:Slider({
        Title = "Keep Seeds in Backpack",
        IsTooltip = true,
        Step = 5,
        Value = { Min = 0, Max = 190, Default = math.clamp(Config.farmSeedKeep or 0, 0, 190) },
        Callback = function(v) Config.farmSeedKeep = math.floor(tonumber(v) or 0); SaveConfig() end,
    })

    Tab:Input({
        Title = "Seed Drop World (Empty = Current World | WORLD | WORLD:DOOR)",
        Value = Config.farmDropWorld,
        Placeholder = "e.g. STORAGE or STORAGE:1",
        Callback = function(t) Config.farmDropWorld = Trim(t or ""); SaveConfig() end,
    })

    Tab:Button({
        Title = "SetPos Seed Drop (Save Current Position)",
        Color = Color3.fromHex("#10C550"),
        Justify = "Center",
        Callback = function()
            local tx, ty = GetTile()
            if not tx then Notify("Character position not detected!"); return end
            Config.farmDropX, Config.farmDropY = tx, ty
            SaveConfig()
            Notify(string.format("Auto Farm Seed Drop position saved at (%d, %d)!", tx, ty))
        end,
    })
end)

-- 2B. Tab: Auto Clear World ------------------------------------------
SafeUI("Tab:AutoClear", function()
    local Tab = AutoSection:Tab({
        Title = "Auto Clear",
        Icon = "solar:cursor-square-bold",
        IconColor = Red,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.clear = Tab

    local clearPara = Tab:Paragraph({ Title = "Auto Clear World Status", Desc = "Loading..." })

    task.spawn(function()
        while alive() and task.wait(0.5) do
            pcall(function()
                local st = Clear.stats
                SetElementText(
                    clearPara,
                    string.format("Status: %s (Pass %d | Row Y=%s)", Clear.status, st.pass, st.row >= 0 and tostring(st.row) or "-"),
                    string.format("Targets: %d | Remaining: %d | Skipped: %d\nBroken: %d | Drops Picked: %d", st.scanned, st.left, st.skipped, st.broken, st.picked)
                )
            end)
        end
    end)

    AddFeatureToggle(Tab, "Auto Clear World (Legit Walk + Hover Break)", "Walks via A* pathfinding between blocks and enables ModFly hover while breaking blocks underneath.", "autoclear")

    Tab:Dropdown({
        Title = "Sweep Direction",
        Values = { "Zig-zag", "Left -> Right" },
        Value = (Config.clearSweep == "Zig-zag") and "Zig-zag" or "Left -> Right",
        Callback = function(v)
            Config.clearSweep = (v == "Zig-zag") and "Zig-zag" or "Kiri → Kanan"
            SaveConfig()
        end,
    })

    Tab:Toggle({
        Title = "Include Background Blocks",
        Value = Config.clearIncludeBg,
        Callback = function(on) Config.clearIncludeBg = on; SaveConfig() end,
    })

    Tab:Input({
        Title = "Break Punch Delay (seconds)",
        Value = tostring(Config.clearBreakDelay),
        Callback = function(text)
            local v = tonumber(text)
            if v and v >= 0.03 and v <= 5 then Config.clearBreakDelay = v; SaveConfig() end
        end,
    })

    Tab:Input({
        Title = "Move Step Delay (seconds)",
        Value = tostring(Config.clearTpDelay),
        Callback = function(text)
            local v = tonumber(text)
            if v and v >= 0.05 and v <= 5 then Config.clearTpDelay = v; SaveConfig() end
        end,
    })

    Tab:Toggle({
        Title = "Auto Collect Drops",
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

    local farmerPara = Tab:Paragraph({ Title = "Farmer Status", Desc = "Loading..." })

    task.spawn(function()
        while alive() and task.wait(0.5) do
            pcall(function()
                local st = Farmer.stats
                SetElementText(
                    farmerPara,
                    "Status: " .. Farmer.status,
                    string.format(
                        "Total Trees: %d | Ready: %d | Growing: %d\nHarvested: %d | Planted: %d | Drops Picked: %d\nPlant Seed: %s [ID %d] (In Bag: %d)",
                        st.totalTrees, st.ready, st.skipped, st.harvested, st.planted, st.picked,
                        ItemName(Config.harvestSeedId), Config.harvestSeedId, CountItem(Config.harvestSeedId)
                    )
                )
            end)
        end
    end)

    AddFeatureToggle(Tab, "Enable Farmer", "Automatically harvest ready trees & plant seeds using Zig-Zag A* walking.", "autoharvest")

    Tab:Toggle({
        Title = "Auto Harvest (Break Ready Trees)",
        Value = Config.harvestDoHarvest,
        Callback = function(on) Config.harvestDoHarvest = on; SaveConfig() end,
    })

    Tab:Toggle({
        Title = "Auto Plant Seeds",
        Value = Config.harvestDoPlant,
        Callback = function(on) Config.harvestDoPlant = on; SaveConfig() end,
    })

    Tab:Input({
        Title = "Seed ID for Auto Plant",
        Desc = "e.g. 3 = Dirt Seed, 5 = Lava Seed",
        Value = tostring(Config.harvestSeedId),
        Placeholder = "3",
        Callback = function(text)
            local v = tonumber(text)
            if v and v > 0 then
                Config.harvestSeedId = math.floor(v)
                SaveConfig()
                Notify("Plant Seed set to: " .. ItemName(Config.harvestSeedId))
            end
        end,
    })

    Tab:Toggle({
    Title = "Auto Save Block (>= 200)",
    Desc = "Auto save block from harvest",
    Value = Config.harvestAutoSaveBlock,
    Callback = function(v)
        Config.harvestAutoSaveBlock = v
        SaveConfig()
    end,
})

Tab:Toggle({
    Title = "Auto Take Seed (Saat Habis)",
    Desc = "Auto take seed when empty",
    Value = Config.harvestAutoTakeSeed,
    Callback = function(v)
        Config.harvestAutoTakeSeed = v
        SaveConfig()
    end,
})

Tab:Input({
    Title = "World Drop Block",
    Desc = "Empty = this world, WORLD / WORLD:DOOR",
    Value = Config.harvestSaveWorld,
    Placeholder = "Example: STORAGE1:DOOR1",
    Callback = function(txt)
        Config.harvestSaveWorld = Trim(txt):upper()
        SaveConfig()
    end,
})

Tab:Button({
    Title = "SetPos Drop Block",
    Desc = "Save current coordinate to position save block",
    Callback = function()
        local tx, ty = GetTile()
        if not tx then
            Notify("Posisi karakter belum terbaca!")
            return
        end
        Config.harvestSaveX, Config.harvestSaveY = tx, ty
        SaveConfig()
        Notify(string.format("Pos Simpan Block Farmer diatur ke (%d, %d)", tx, ty))
    end,
})

    Tab:Toggle({
        Title = "Use Scaffold Blocks When Climbing",
        Value = Config.harvestUseBlock,
        Callback = function(on) Config.harvestUseBlock = on; SaveConfig() end,
    })

    Tab:Toggle({
        Title = "Auto Collect Harvest Drops",
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

    local dfPara = Tab:Paragraph({ Title = "Auto Dirt Farm Status", Desc = "Loading..." })

    task.spawn(function()
        while alive() and task.wait(0.5) do
            pcall(function()
                local st = DF.stats
                local dirtId = GetDirtId()
                local seedId = GetDirtSeedId()
                SetElementText(
                    dfPara,
                    "Status: " .. DF.status .. " (" .. tostring(st.step) .. ")",
                    string.format(
                        "Top Dirt Row: Y=%d | Bedrock: Y=%d\nDirt in Bag: %d | Dirt Seeds: %d\nBroken: %d | Dirt Placed: %d | Drops Picked: %d",
                        st.topDirtY, st.bedrockY, CountItem(dirtId), CountItem(seedId), st.broken, st.placed, st.picked
                    )
                )
            end)
        end
    end)

    AddFeatureToggle(Tab, "Enable Auto Dirt Farm (Full World)", "Automatically build lower & upper Dirt Farm platforms + Smart Dirt Restock.", "autodf")

    Tab:Toggle({
        Title = "Replace Lava/Rock with Dirt on Platforms",
        Value = Config.dfReplacePlatform,
        Callback = function(on) Config.dfReplacePlatform = on; SaveConfig() end,
    })

    Tab:Toggle({
        Title = "Use Platform",
        Desc = "Automaticly place platform like wooden platform",
        Value = Config.dfUsePlatform,
        Callback = function(on)
            Config.dfUsePlatform = on
            SaveConfig()
        end,
    })

    Tab:Input({
        Title = "ID Platform (Default: 102 = Wooden Platform)",
        Value = tostring(Config.dfPlatformId or 102),
        Placeholder = "102",
        Callback = function(text)
            local v = tonumber(text)
            if v and v > 0 then
                Config.dfPlatformId = math.floor(v)
                SaveConfig()
                Notify("Platform DF diset ke: " .. ItemName(Config.dfPlatformId) .. " [" .. Config.dfPlatformId .. "]")
            end
        end,
    })

    Tab:Toggle({
        Title = "Auto Collect Drops",
        Value = Config.dfTake,
        Callback = function(on) Config.dfTake = on; SaveConfig() end,
    })

    Tab:Toggle({
        Title = "Enable ModFly During Auto DF (Anti-Lava)",
        Desc = "Hover & stay immune to lava while breaking blocks.",
        Value = Config.dfModFly,
        Callback = function(on)
            Config.dfModFly = on
            SaveConfig()
            if DF.on then SetAutoFly("autodf", on) end
        end,
    })

    Tab:Input({
        Title = "Break Punch Delay (seconds)",
        Value = tostring(Config.dfBreakDelay),
        Callback = function(text)
            local v = tonumber(text)
            if v and v >= 0.03 and v <= 5 then Config.dfBreakDelay = v; SaveConfig() end
        end,
    })

    Tab:Input({
        Title = "Move Step Delay (seconds)",
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

    local splicePara = Tab:Paragraph({ Title = "Auto Splice Status", Desc = "Loading..." })

    task.spawn(function()
        while alive() and task.wait(0.6) do
            pcall(function()
                SetElementText(
                    splicePara,
                    "Status: " .. SpliceBot.status,
                    string.format(
                        "%s\nSeed A: %s [%d] (x%d) | Seed B: %s [%d] (x%d)\nPlanted: %d | Spliced: %d",
                        SpliceBot.ResultText(),
                        ItemName(Config.spliceA), Config.spliceA, CountItem(Config.spliceA),
                        ItemName(Config.spliceB), Config.spliceB, CountItem(Config.spliceB),
                        SpliceBot.planted, SpliceBot.made
                    )
                )
            end)
        end
    end)

    AddFeatureToggle(Tab, "Enable Auto Splice", "Plant Seed A and splice it with Seed B.", "autosplice")

    Tab:Input({
        Title = "Seed A ID (Planted First)",
        Value = tostring(Config.spliceA),
        Placeholder = "3 (Dirt Seed)",
        Callback = function(t)
            local v = tonumber(t)
            if v and v > 0 then Config.spliceA = math.floor(v); SaveConfig() end
        end,
    })

    Tab:Input({
        Title = "Seed B ID (Spliced onto Seed A)",
        Value = tostring(Config.spliceB),
        Placeholder = "5 (Lava Seed)",
        Callback = function(t)
            local v = tonumber(t)
            if v and v > 0 then Config.spliceB = math.floor(v); SaveConfig() end
        end,
    })

    Tab:Toggle({
        Title = "Roam Entire World (A*)",
        Desc = "ON = Find empty tiles across the world. OFF = Only splice within 5x5 Grid.",
        Value = Config.spliceRoam,
        Callback = function(on) Config.spliceRoam = on; SaveConfig() end,
    })

    Tab:Slider({
        Title = "Plant / Splice Delay (ms)",
        IsTooltip = true,
        Step = 10,
        Value = { Min = 140, Max = 2000, Default = math.clamp(Config.spliceMs, 140, 2000) },
        Callback = function(v) Config.spliceMs = math.floor(tonumber(v) or 300); SaveConfig() end,
    })
end)

-- 2F. Tab: Seed Factory (Pabrik) -------------------------------------
SafeUI("Tab:Pabrik", function()
    local Tab = AutoSection:Tab({
        Title = "Seed Factory",
        Icon = "solar:folder-with-files-bold",
        IconColor = Blue,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.pabrik = Tab

    local pabrikPara = Tab:Paragraph({ Title = "Seed Factory Status", Desc = "Loading..." })

    task.spawn(function()
        while alive() and task.wait(0.6) do
            pcall(function()
                local sid = Config.pabrikSeedId
                local bid = BlockOfSeed(sid)
                local wTarget, dTarget = Pabrik.ParseDropTarget()
                local dropInfo = (wTarget ~= "" and wTarget or "Current World")
                    .. (dTarget and (" Door:" .. dTarget) or "")
                    .. (Config.pabrikDropX >= 0 and string.format(" (%d,%d)", Config.pabrikDropX, Config.pabrikDropY) or "")
                SetElementText(
                    pabrikPara,
                    string.format("Status: %s (Phase: %s)", Pabrik.status, Pabrik.phase),
                    string.format(
                        "Seed: %s [%d] x%d | Block: %s x%d\nBreak Pos: %s\nDrop Target: %s (Max Seed Cap: %d)\nTotals: Harvested %d | Planted %d | Dropped %d",
                        ItemName(sid), sid, CountItem(sid),
                        bid and ItemName(bid) or "-", bid and CountItem(bid) or 0,
                        Config.pabrikBreakX >= 0 and string.format("Tile (%d, %d)", Config.pabrikBreakX, Config.pabrikBreakY) or "Not set!",
                        Config.pabrikDrop and dropInfo or "Disabled",
                        Config.pabrikMaxSeed or 100,
                        Pabrik.harvested, Pabrik.planted, Pabrik.dropped
                    )
                )
            end)
        end
    end)

    AddFeatureToggle(Tab, "Enable Seed Factory", "Full Cycle: Break Blocks -> Drop Excess Seeds -> Plant -> Wait -> Harvest -> Repeat.", "pabrik")

    Tab:Input({
        Title = "Factory Seed ID",
        Desc = "Block ID is detected automatically (e.g. 3 = Dirt Seed -> Block ID 2 = Dirt).",
        Value = tostring(Config.pabrikSeedId),
        Callback = function(t)
            local v = tonumber(t)
            if v and v > 0 then Config.pabrikSeedId = math.floor(v); SaveConfig() end
        end,
    })

    Tab:Input({
        Title = "Max Seed Cap (Plant & Rotation Limit)",
        Desc = "e.g. 100 = Only plant up to 100 seeds. Any extra seeds above 100 after breaking are automatically dropped at storage.",
        Value = tostring(Config.pabrikMaxSeed or 100),
        Placeholder = "100",
        Callback = function(t)
            local v = tonumber(t)
            if v and v >= 1 then
                Config.pabrikMaxSeed = math.floor(v)
                SaveConfig()
                Notify("Factory Max Seed set to: " .. tostring(Config.pabrikMaxSeed))
            end
        end,
    })

    Tab:Space()
    Tab:Section({ Title = "Factory Break Position (SetPos Break)" })

    local breakPosGrp = Tab:Group({})
    breakPosGrp:Button({
        Title = "SetPos Break (Save Position)",
        Color = Color3.fromHex("#10C550"),
        Justify = "Center",
        Callback = function()
            local tx, ty = GetTile()
            if not tx then Notify("Character position not detected!"); return end
            Config.pabrikBreakX, Config.pabrikBreakY = tx, ty
            SaveConfig()
            Notify(string.format("Factory Break Position saved at (%d, %d)!", tx, ty))
        end,
    })
    breakPosGrp:Button({
        Title = "Go to Break Pos",
        Justify = "Center",
        Callback = function()
            if Config.pabrikBreakX < 0 or Config.pabrikBreakY < 0 then
                Notify("Break Position is not set yet!")
                return
            end
            task.spawn(function()
                Nav.To(Config.pabrikBreakX, Config.pabrikBreakY, nil, 0.3, true)
            end)
        end,
    })

    Tab:Button({
        Title = "Select Break Tiles (Open 5x5 Grid in Factory Mode)",
        Color = Color3.fromHex("#305dff"),
        Justify = "Center",
        Callback = function()
            if SetGridMode then SetGridMode("pabrik") end
            if GridGui then GridGui.Enabled = true end
        end,
    })

    Tab:Space()
    Tab:Section({ Title = "Seed Storage / Auto Drop Settings" })

    Tab:Toggle({
        Title = "Enable Auto Drop Excess Seeds to Storage",
        Value = Config.pabrikDrop,
        Callback = function(on) Config.pabrikDrop = on; SaveConfig() end,
    })

    Tab:Input({
        Title = "Seed Storage World (WORLD or WORLD:DOOR_ID)",
        Value = Config.pabrikDropWorld,
        Placeholder = "e.g. STORAGE or STORAGE:1",
        Callback = function(t) Config.pabrikDropWorld = Trim(t or ""); SaveConfig() end,
    })

    Tab:Button({
        Title = "SetPos Seed Drop (Save Current Tile)",
        Justify = "Center",
        Callback = function()
            local tx, ty = GetTile()
            if not tx then Notify("Position not detected!"); return end
            Config.pabrikDropX, Config.pabrikDropY = tx, ty
            SaveConfig()
            Notify(string.format("Seed Drop Position saved at (%d, %d)", tx, ty))
        end,
    })
end)

-- 2G. Tab: Auto Move Item (World 1 -> World 2) -----------------------
SafeUI("Tab:AutoMove", function()
    local Tab = AutoSection:Tab({
        Title = "Auto Move Item",
        Icon = "solar:square-transfer-horizontal-bold",
        IconColor = Green,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.automove = Tab

    local movePara = Tab:Paragraph({ Title = "Auto Move Item Status", Desc = "Loading..." })

    task.spawn(function()
        while alive() and task.wait(0.6) do
            pcall(function()
                local id = tonumber(Config.moveItemId) or 0
                SetElementText(
                    movePara,
                    string.format("Status: %s (Phase: %s)", AutoMove.status, AutoMove.phase),
                    string.format(
                        "Item: %s [ID %d] (In Bag: %d)\nWorld 1 (Take): %s  ->  World 2 (Drop): %s\nWorld 2 Drop Pos: %s\nTotal Picked: %d | Total Dropped: %d",
                        ItemName(id), id, CountItem(id),
                        Config.moveWorld1 ~= "" and Config.moveWorld1 or "(Not set)",
                        Config.moveWorld2 ~= "" and Config.moveWorld2 or "(Not set)",
                        (Config.moveDropX >= 0 and Config.moveDropY >= 0) and string.format("(%d, %d)", Config.moveDropX, Config.moveDropY) or "(Not set)",
                        AutoMove.collected, AutoMove.dropped
                    )
                )
            end)
        end
    end)

    AddFeatureToggle(Tab, "Enable Auto Move (World 1 -> World 2)", "Take dropped items in World 1 -> Warp & Drop in World 2 (steps right 1 tile if full) -> Loop until empty.", "automove")

    Tab:Input({
        Title = "World 1 - Source World (WORLD or WORLD:DOOR_ID)",
        Value = Config.moveWorld1,
        Placeholder = "e.g. FARM1 or FARM1:DOOR1",
        Callback = function(t) Config.moveWorld1 = Trim(t or ""); SaveConfig() end,
    })

    Tab:Input({
        Title = "World 2 - Drop World (WORLD or WORLD:DOOR_ID)",
        Value = Config.moveWorld2,
        Placeholder = "e.g. STORAGE1 or STORAGE1:DOOR2",
        Callback = function(t) Config.moveWorld2 = Trim(t or ""); SaveConfig() end,
    })

    Tab:Button({
        Title = "SetPos Drop in World 2 (Save Current Position)",
        Color = Color3.fromHex("#10C550"),
        Justify = "Center",
        Callback = function()
            local tx, ty = GetTile()
            if not tx then Notify("Position not detected!"); return end
            Config.moveDropX, Config.moveDropY = tx, ty
            SaveConfig()
            Notify(string.format("World 2 Drop Position saved at (%d, %d)!", tx, ty))
        end,
    })

    Tab:Input({
        Title = "Item ID to Move",
        Value = tostring(Config.moveItemId),
        Placeholder = "e.g. 2 (Dirt) or 3 (Dirt Seed)",
        Callback = function(t)
            local v = tonumber(t)
            if v and v > 0 then
                Config.moveItemId = math.floor(v)
                SaveConfig()
                Notify("Auto Move Item set to: " .. ItemName(Config.moveItemId) .. " [" .. Config.moveItemId .. "]")
            end
        end,
    })
end)

-- 2G-2. Tab: Multi-World Rotation -----------------------------------
SafeUI("Tab:Rotation", function()
    local Tab = AutoSection:Tab({
        Title = "World Rotation",
        Icon = "solar:square-transfer-horizontal-bold",
        IconColor = Blue,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.rotation = Tab

    local rotPara = Tab:Paragraph({ Title = "Multi-World Rotation Status", Desc = "Loading..." })
    local Rot = Session.Rotation

    task.spawn(function()
        while alive() and task.wait(0.6) do
            pcall(function()
                local sid = tonumber(Config.rotSeedId) or 3
                local bid = BlockOfSeed(sid) or 2
                local wList = Rot.ParseWorldsList()
                SetElementText(
                    rotPara,
                    string.format("Status: %s (Phase: %s)", Rot.status, Rot.phase),
                    string.format(
                        "Current World: %s (#%d/%d | Full Loops: %d)\nSeed: %s [%d] (x%d) | Block: %s (x%d)\nHarvested: %d | Broken: %d | Planted: %d",
                        Rot.currentWorld, Rot.worldIndex, #wList, Rot.passes,
                        ItemName(sid), sid, CountItem(sid), ItemName(bid), CountItem(bid),
                        Rot.harvested, Rot.broken, Rot.planted
                    )
                )
            end)
        end
    end)

    AddFeatureToggle(Tab, "Enable Multi-World Rotation", "Warp World 1 -> Harvest Ready -> Break at 200 Blocks -> Plant Seeds -> Next World -> Loop.", "rotation")

    Tab:Input({
        Title = "Rotation World List (Separate with Comma)",
        Desc = "Format: WORLD1, WORLD2:DOOR_ID, WORLD3",
        Value = Config.rotWorlds,
        Placeholder = "e.g. FARM1, FARM2:1, FARM3",
        Callback = function(t) Config.rotWorlds = Trim(t or ""); SaveConfig() end,
    })

    Tab:Input({
        Title = "Target Tree Seed ID",
        Desc = "e.g. 3 = Dirt Seed (Block ID is detected automatically).",
        Value = tostring(Config.rotSeedId or 3),
        Placeholder = "3",
        Callback = function(t)
            local v = tonumber(t)
            if v and v > 0 then
                Config.rotSeedId = math.floor(v)
                SaveConfig()
                Notify("Rotation Seed set to: " .. ItemName(Config.rotSeedId))
            end
        end,
    })

    Tab:Toggle({
        Title = "Loop Back to World 1 After Finishing All Worlds",
        Value = Config.rotLoop,
        Callback = function(on) Config.rotLoop = on; SaveConfig() end,
    })

    Tab:Button({
        Title = "SetPos Break for Rotation (Save Current Position)",
        Color = Color3.fromHex("#10C550"),
        Justify = "Center",
        Callback = function()
            local tx, ty = GetTile()
            if not tx then Notify("Position not detected!"); return end
            Config.rotBreakX, Config.rotBreakY = tx, ty
            SaveConfig()
            Notify(string.format("Rotation Break Position saved at (%d, %d)!", tx, ty))
        end,
    })

    Tab:Space()
    Tab:Section({ Title = "Surplus Seed Storage (Optional)" })

    Tab:Toggle({
        Title = "Auto Drop Surplus Seeds to Storage World",
        Value = Config.rotDropExcess,
        Callback = function(on) Config.rotDropExcess = on; SaveConfig() end,
    })

    Tab:Input({
        Title = "Seeds to Keep for Next World",
        Value = tostring(Config.rotKeepSeed or 100),
        Callback = function(t)
            local v = tonumber(t)
            if v and v >= 0 then Config.rotKeepSeed = math.floor(v); SaveConfig() end
        end,
    })

    Tab:Input({
        Title = "Seed Storage World (WORLD or WORLD:DOOR_ID)",
        Value = Config.rotSaveWorld,
        Placeholder = "e.g. STORAGE or STORAGE:1",
        Callback = function(t) Config.rotSaveWorld = Trim(t or ""); SaveConfig() end,
    })

    Tab:Button({
        Title = "SetPos Seed Drop in Storage World",
        Justify = "Center",
        Callback = function()
            local tx, ty = GetTile()
            if not tx then Notify("Position not detected!"); return end
            Config.rotSaveX, Config.rotSaveY = tx, ty
            SaveConfig()
            Notify(string.format("Rotation Storage Drop Position saved at (%d, %d)", tx, ty))
        end,
    })
end)

-- 2H. Tab: Fast Wrench -----------------------------------------------
SafeUI("Tab:FastWrench", function()
    local Tab = HelperSection:Tab({
        Title = "Fast Wrench",
        Icon = "solar:square-transfer-horizontal-bold",
        IconColor = Purple,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.fastwrench = Tab

    Tab:Section({ Title = "Fast Wrench Actions (0ms Modal Bypass)" })

    local fpToggle, fkToggle, fbToggle

    fpToggle = Tab:Toggle({
        Title = "Fast Pull (Wrench Player = Instant Pull)",
        Desc = "Bypass the wrench dialog and immediately pull the wrenched player.",
        Value = Config.fastPull,
        Callback = function(on)
            Config.fastPull = on
            if on then
                Config.fastKick, Config.fastBan = false, false
                if fkToggle and fkToggle.Set then pcall(function() fkToggle:Set(false) end) end
                if fbToggle and fbToggle.Set then pcall(function() fbToggle:Set(false) end) end
                Notify("Fast Pull ENABLED! Wrench a player to pull them instantly.")
            end
            SaveConfig()
        end,
    })

    fkToggle = Tab:Toggle({
        Title = "Fast Kick (Wrench Player = Instant Kick)",
        Desc = "Bypass the wrench dialog and immediately kick the wrenched player.",
        Value = Config.fastKick,
        Callback = function(on)
            Config.fastKick = on
            if on then
                Config.fastPull, Config.fastBan = false, false
                if fpToggle and fpToggle.Set then pcall(function() fpToggle:Set(false) end) end
                if fbToggle and fbToggle.Set then pcall(function() fbToggle:Set(false) end) end
                Notify("Fast Kick ENABLED! Wrench a player to kick them instantly.")
            end
            SaveConfig()
        end,
    })

    fbToggle = Tab:Toggle({
        Title = "Fast Ban (Wrench Player = Instant Ban)",
        Desc = "Bypass the wrench dialog and immediately ban the wrenched player.",
        Value = Config.fastBan,
        Callback = function(on)
            Config.fastBan = on
            if on then
                Config.fastPull, Config.fastKick = false, false
                if fpToggle and fpToggle.Set then pcall(function() fpToggle:Set(false) end) end
                if fkToggle and fkToggle.Set then pcall(function() fkToggle:Set(false) end) end
                Notify("Fast Ban ENABLED! Wrench a player to ban them instantly.")
            end
            SaveConfig()
        end,
    })
end)

-- 2I. Tab: Fast Drop & Recycle ---------------------------------------
SafeUI("Tab:FastDropRecycle", function()
    local Tab = HelperSection:Tab({
        Title = "Fast Drop & Recycle",
        Icon = "solar:square-transfer-horizontal-bold",
        IconColor = Purple,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.fastdroprecycle = Tab

    Tab:Section({ Title = "Fast Drop & Fast Recycle / Trash (0ms Dialog Bypass)" })

    Tab:Toggle({
        Title = "Fast Drop (Click Drop = Instant Drop Without Dialog)",
        Desc = "Automatically bypass the quantity popup when clicking Drop in your Backpack.",
        Value = Config.fastDrop,
        Callback = function(on)
            Config.fastDrop = on
            SaveConfig()
            Notify("Fast Drop " .. (on and "ENABLED!" or "DISABLED."))
        end,
    })

    Tab:Input({
        Title = "Fast Drop Amount (0 = Drop All)",
        Desc = "Set to 0 to instantly drop the entire stack of the selected item.",
        Value = tostring(Config.fastDropCount or 0),
        Placeholder = "0 = All",
        Callback = function(t)
            local v = tonumber(t)
            Config.fastDropCount = (v and v >= 0) and math.floor(v) or 0
            SaveConfig()
            Notify("Fast Drop Amount set to: " .. (Config.fastDropCount == 0 and "ALL" or tostring(Config.fastDropCount)))
        end,
    })

    Tab:Space()

    Tab:Toggle({
        Title = "Fast Recycle / Trash (Click Recycle = Instant Trash)",
        Desc = "Automatically bypass the confirmation popup when clicking Recycle in your Backpack.",
        Value = Config.fastRecycle,
        Callback = function(on)
            Config.fastRecycle = on
            SaveConfig()
            Notify("Fast Recycle " .. (on and "ENABLED!" or "DISABLED."))
        end,
    })

    Tab:Input({
        Title = "Fast Recycle Amount (0 = Recycle All)",
        Desc = "Set to 0 to instantly recycle the entire stack of the selected item.",
        Value = tostring(Config.fastRecycleCount or 0),
        Placeholder = "0 = All",
        Callback = function(t)
            local v = tonumber(t)
            Config.fastRecycleCount = (v and v >= 0) and math.floor(v) or 0
            SaveConfig()
            Notify("Fast Recycle Amount set to: " .. (Config.fastRecycleCount == 0 and "ALL" or tostring(Config.fastRecycleCount)))
        end,
    })
end)

-- 3A. Tab: Backpack (Auto Recycle, Convert Lock & Drop WL) -----------
SafeUI("Tab:Bag", function()
    local Tab = BagWorldSection:Tab({
        Title = "Backpack (Recycle & Locks)",
        Icon = "solar:check-square-bold",
        IconColor = Green,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.bag = Tab

    local bagPara = Tab:Paragraph({ Title = "Backpack Management Status", Desc = "Loading..." })

    task.spawn(function()
        while alive() and task.wait(0.8) do
            pcall(function()
                local ids = {}
                for _, id in ipairs(Config.trashList or {}) do
                    table.insert(ids, ItemName(id) .. " [" .. id .. "]")
                end
                SetElementText(
                    bagPara,
                    "Last Action: " .. Bag.status,
                    string.format(
                        "Total Recycled: %d items | Locks Converted: %d times\nAuto-Recycle List: %s",
                        Bag.recycled, Bag.converted, #ids > 0 and table.concat(ids, ", ") or "(None)"
                    )
                )
            end)
        end
    end)

    Tab:Toggle({
        Title = "Enable Auto Recycle (Auto Trash Items)",
        Value = Config.trashOn,
        Callback = function(on) Config.trashOn = on; SaveConfig() end,
    })

    Tab:Input({
        Title = "Add / Remove Item ID from Auto-Recycle",
        Desc = "Enter an Item ID (e.g. 2 for Dirt) to toggle it in the Auto-Recycle list.",
        Placeholder = "Enter Item ID...",
        Callback = function(t)
            local id = tonumber(t)
            if not id or id <= 0 then return end
            id = math.floor(id)
            local idx = table.find(Config.trashList, id)
            if idx then
                table.remove(Config.trashList, idx)
                Notify(ItemName(id) .. " removed from Auto-Recycle list.")
            else
                table.insert(Config.trashList, id)
                Notify(ItemName(id) .. " added to Auto-Recycle list.")
            end
            SaveConfig()
        end,
    })

    Tab:Slider({
        Title = "Recycle When Count >=",
        IsTooltip = true,
        Step = 5,
        Value = { Min = 5, Max = 200, Default = math.clamp(Config.trashAt, 5, 200) },
        Callback = function(v) Config.trashAt = math.floor(tonumber(v) or 150); SaveConfig() end,
    })

    Tab:Slider({
        Title = "Keep Amount in Backpack",
        IsTooltip = true,
        Step = 5,
        Value = { Min = 0, Max = 195, Default = math.clamp(Config.trashKeep, 0, 195) },
        Callback = function(v) Config.trashKeep = math.floor(tonumber(v) or 0); SaveConfig() end,
    })

    Tab:Space()
    Tab:Section({ Title = "Locks & Quick Drop" })

    Tab:Toggle({
        Title = "Auto Convert Locks (100 WL -> 1 DL, 100 DL -> 1 BGL)",
        Value = Config.convertLockOn,
        Callback = function(on) Config.convertLockOn = on; SaveConfig() end,
    })

    local dropAmountText = "100"
    Tab:Input({
        Title = "World Lock Drop Amount",
        Value = "100",
        Placeholder = "Amount (1-10000)",
        Callback = function(text) dropAmountText = text end,
    })

    Tab:Button({
        Title = "Drop World Locks Now",
        Color = Color3.fromHex("#305dff"),
        Justify = "Center",
        Callback = function()
            local amount = tonumber(dropAmountText)
            if amount and amount >= 1 and amount <= MAX_AMOUNT then
                task.spawn(DropWorldLock, math.floor(amount))
            else
                Notify("Invalid WL amount!")
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

    local scanInfoPara = ScanTab:Paragraph({ Title = "GrowScan 9000", Desc = "Click the button below to scan all blocks, trees, and floating drops in the world." })

    local function RunGrowScan()
        local data = ScanWorld()
        if not data then
            SetElementText(scanInfoPara, "GrowScan", "World not detected.")
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
            return #out > 0 and table.concat(out, "\n") or "Empty"
        end
        local treeLines = {}
        for id, t in pairs(data.trees) do
            local nxt = t.nextIn and string.format(" (ready in %ds)", math.max(0, math.ceil(t.nextIn))) or ""
            table.insert(treeLines, string.format("• %s: %d ready | %d growing%s", ItemName(id), t.ready, t.growing, nxt))
        end
        local desc = table.concat({
            string.format("World: %s (%dx%d)", CurrentWorldName(), data.w, data.h),
            string.format("FG: %d | BG: %d | Floating: %d (%d stacks)", data.totalFg, data.totalBg, data.totalDrops, data.piles),
            string.format("Trees: %d ready | %d growing", data.readyTrees, data.growingTrees),
            "\n[TREES IN WORLD]:\n" .. (#treeLines > 0 and table.concat(treeLines, "\n") or "No trees"),
            "\n[FLOATING DROPS]:\n" .. topItems(data.drops, 10),
            "\n[WORLD BLOCKS]:\n" .. topItems(data.fg, 12),
        }, "\n")
        SetElementText(scanInfoPara, "GrowScan Results (" .. os.date("%H:%M:%S") .. ")", desc)
    end

    ScanTab:Button({
        Title = "Scan World Now",
        Color = Color3.fromHex("#305dff"),
        Justify = "Center",
        Callback = RunGrowScan,
    })

    ScanTab:Button({
        Title = "Open Native In-Game GrowScan UI",
        Justify = "Center",
        Callback = function()
            if not OpenNativeGrowScan() then Notify("Native GrowScan UI is unavailable.") end
        end,
    })
end)

-- 3C. Tab: Teleport & Positions (Pos 1/2) ----------------------------
SafeUI("Tab:Pos", function()
    local PosTab = BagWorldSection:Tab({
        Title = "Teleport & Positions",
        Icon = "solar:hamburger-menu-bold",
        IconColor = Yellow,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.pos = PosTab

    local warpTarget = ""
    PosTab:Input({
        Title = "Target World Name",
        Placeholder = "Enter world name...",
        Callback = function(t) warpTarget = Trim(t or "") end,
    })

    PosTab:Button({
        Title = "Warp to World",
        Color = Color3.fromHex("#305dff"),
        Justify = "Center",
        Callback = function()
            if warpTarget ~= "" then task.spawn(WarpToWorld, warpTarget) else Notify("Enter a world name first!") end
        end,
    })

    PosTab:Space()
    PosTab:Section({ Title = "Saved Positions (Pos 1 / Pos 2)" })

    for slot = 1, 2 do
        local posPara = PosTab:Paragraph({ Title = "Position " .. slot, Desc = "Not set" })
        local function refPos()
            local p = Config["pos" .. slot]
            if type(p) == "table" and type(p.x) == "number" then
                SetElementText(posPara, "Saved Pos " .. slot, string.format("Tile (%d, %d) in World %s", p.x, p.y, p.world or "-"))
            else
                SetElementText(posPara, "Position " .. slot, "Not set")
            end
        end
        table.insert(hub.refreshers, refPos)
        refPos()

        local grp = PosTab:Group({})
        grp:Button({ Title = "Save Pos " .. slot, Justify = "Center", Callback = function() SetPos(slot); RefreshHub() end })
        grp:Button({ Title = "Teleport (win" .. slot .. ")", Justify = "Center", Callback = function() task.spawn(GoToPos, slot) end })
    end
end)

-- 3D. Tab: Vending Machine Bot ---------------------------------------
SafeUI("Tab:Vending", function()
    local Tab = BagWorldSection:Tab({
        Title = "Vending Machine",
        Icon = "solar:folder-with-files-bold",
        IconColor = Purple,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.vending = Tab

    local vendPara = Tab:Paragraph({ Title = "Vending Bot Status", Desc = "Loading..." })

    task.spawn(function()
        while alive() and task.wait(0.8) do
            pcall(function()
                SetElementText(
                    vendPara,
                    "Status: " .. Vend.status,
                    string.format("Mode: %s\nStocked: %d | Emptied: %d", Config.vendMode, Vend.stocked, Vend.taken)
                )
            end)
        end
    end)

    Tab:Toggle({
        Title = "Enable Vending Machine Bot",
        Value = Vend.on,
        Callback = function(on)
            if on then Vend.Start() else Vend.Stop() end
        end,
    })

    local vendModeMap = {
        ["Restock from Backpack/Drops"] = "Isi stock dari drop",
        ["Empty Until Depleted"] = "Kosongkan sampai habis",
    }
    local vendModeRev = {
        ["Isi stock dari drop"] = "Restock from Backpack/Drops",
        ["Kosongkan sampai habis"] = "Empty Until Depleted",
    }

    Tab:Dropdown({
        Title = "Vending Mode",
        Values = { "Restock from Backpack/Drops", "Empty Until Depleted" },
        Value = vendModeRev[Config.vendMode] or "Restock from Backpack/Drops",
        Callback = function(v)
            Config.vendMode = vendModeMap[v] or "Isi stock dari drop"
            SaveConfig()
        end,
    })

    Tab:Input({
        Title = "Drop World When Emptying (WORLD or WORLD:DOOR)",
        Value = Config.vendPoint,
        Placeholder = "e.g. STORAGE or STORAGE:1",
        Callback = function(t) Config.vendPoint = Trim(t or ""); SaveConfig() end,
    })

    Tab:Button({
        Title = "SetPos Drop for Emptied Vending Items",
        Justify = "Center",
        Callback = function()
            local tx, ty = GetTile()
            if not tx then Notify("Position not detected!"); return end
            Config.vendDropX, Config.vendDropY = tx, ty
            SaveConfig()
            Notify(string.format("Vending Drop Position saved at (%d, %d)", tx, ty))
        end,
    })
end)

-- 4A. Tab: Anti-Mod Guard & Auto Reconnect ---------------------------
SafeUI("Tab:Guard", function()
    local Tab = SecuritySection:Tab({
        Title = "Guard & Reconnect",
        Icon = "solar:info-square-bold",
        IconColor = Red,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.guard = Tab

    local guardPara = Tab:Paragraph({ Title = "Guard & Reconnect Status", Desc = "Idle" })

    task.spawn(function()
        while alive() and task.wait(0.6) do
            pcall(function()
                SetElementText(
                    guardPara,
                    "Guard: " .. Guard.status .. " | Reconnect: " .. Reconnect.status,
                    string.format(
                        "Players in World: %s\nStaff in Server: %s\nDetections: %d | Rejoins: %d",
                        Guard.hereText, Guard.staffServerText, Guard.detected, Reconnect.count
                    )
                )
            end)
        end
    end)

    AddFeatureToggle(Tab, "Enable Anti-Mod Guard", "Monitor Moderators / Developers (including undercover) or other players entering the world.", "guard")

    local guardWhoMap = {
        ["Staff Only (Mod/Dev)"] = "Staff (Mod/Dev)",
        ["All Players"] = "Semua pemain",
    }
    local guardWhoRev = {
        ["Staff (Mod/Dev)"] = "Staff Only (Mod/Dev)",
        ["Semua pemain"] = "All Players",
    }

    Tab:Dropdown({
        Title = "Detection Target",
        Values = { "Staff Only (Mod/Dev)", "All Players" },
        Value = guardWhoRev[Config.guardWho] or "Staff Only (Mod/Dev)",
        Callback = function(v)
            Config.guardWho = guardWhoMap[v] or "Staff (Mod/Dev)"
            SaveConfig()
        end,
    })

    Tab:Toggle({
        Title = "Pause All Active Bots on Detection",
        Value = Config.guardStopAll,
        Callback = function(on) Config.guardStopAll = on; SaveConfig() end,
    })

    Tab:Toggle({
        Title = "Immediately Leave World on Detection",
        Value = Config.guardLeave,
        Callback = function(on) Config.guardLeave = on; SaveConfig() end,
    })

    Tab:Toggle({
        Title = "Auto Resume When Safe",
        Value = Config.guardAutoBack,
        Callback = function(on) Config.guardAutoBack = on; SaveConfig() end,
    })

    Tab:Slider({
        Title = "Return Wait Time (seconds)",
        IsTooltip = true,
        Step = 5,
        Value = { Min = 15, Max = 300, Default = math.clamp(Config.guardBackSec, 15, 300) },
        Callback = function(v) Config.guardBackSec = tonumber(v) or 60; SaveConfig() end,
    })

    Tab:Button({
        Title = "Whitelist Players Currently in World",
        Justify = "Center",
        Callback = function()
            local n = Guard.AllowCurrentPlayers()
            Notify(n .. " players in this world added to whitelist.")
        end,
    })

    Tab:Space()
    Tab:Section({ Title = "Auto Reconnect (World Closed & Server Disconnect)" })

    AddFeatureToggle(Tab, "Enable Auto Reconnect", "Re-enter the world & resume bot activities if kicked or disconnected.", "autorejoin")

    Tab:Toggle({
        Title = "Re-Enter When World Closes / Kicked",
        Value = Config.reconnectWorld,
        Callback = function(on) Config.reconnectWorld = on; SaveConfig() end,
    })

    Tab:Toggle({
        Title = "Always Stay in World (Auto Enter from Menu)",
        Value = Config.reconnectKeep,
        Callback = function(on) Config.reconnectKeep = on; SaveConfig() end,
    })

    Tab:Toggle({
        Title = "Auto Teleport on Server Disconnect",
        Value = Config.reconnectServer,
        Callback = function(on) Config.reconnectServer = on; SaveConfig() end,
    })

    Tab:Input({
        Title = "Reconnect Target World (Empty = Last World)",
        Placeholder = "WORLDNAME",
        Callback = function(t) Config.targetWorld = Trim(t or ""); SaveConfig() end,
    })
end)

-- 4B. Tab: Auto Chat & Bonus -----------------------------------------
SafeUI("Tab:Bonus", function()
    local Tab = SecuritySection:Tab({
        Title = "Auto Chat & Bonus",
        Icon = "solar:file-text-bold",
        IconColor = Purple,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.bonus = Tab

    local bonusPara = Tab:Paragraph({ Title = "Auto Chat & Bonus Status", Desc = "Loading..." })

    task.spawn(function()
        while alive() and task.wait(0.8) do
            pcall(function()
                SetElementText(
                    bonusPara,
                    string.format("Auto Chat: %s (Sent: %d)", Spam.on and "ACTIVE" or "OFF", Spam.sent),
                    string.format("Configured Message: %s\nLast Sent: %s\nQuests: %s\nRedeem: %s", Config.chatText ~= "" and Config.chatText or "(Not set)", Spam.last, Bonus.questText, Bonus.codeText)
                )
            end)
        end
    end)

    Tab:Section({ Title = "Auto Chat / Spammer (Single Message)" })

    AddFeatureToggle(Tab, "Enable Auto Chat", "Automatically send your configured message to the world chat channel.", "autochat")

    Tab:Input({
        Title = "Auto Chat Message",
        Value = Config.chatText,
        Placeholder = "Type the message to send...",
        Callback = function(text)
            Config.chatText = Trim(text or "")
            SaveConfig()
        end,
    })

    Tab:Slider({
        Title = "Chat Interval (seconds)",
        IsTooltip = true,
        Step = 1,
        Value = { Min = 3, Max = 120, Default = math.clamp(Config.chatInterval, 3, 120) },
        Callback = function(v) Config.chatInterval = tonumber(v) or 6; SaveConfig() end,
    })

    Tab:Button({
        Title = "Send Chat Message Once Now",
        Justify = "Center",
        Callback = function() Spam.SendNext() end,
    })

    Tab:Space()
    Tab:Section({ Title = "Quests & Promo Codes" })

    AddFeatureToggle(Tab, "Auto Claim Completed Quests", "Automatically check and claim finished quests every 30s.", "autoquest")

    Tab:Toggle({
        Title = "Auto Redeem Active Promo Codes",
        Value = Config.bonusAutoRedeem,
        Callback = function(on)
            Config.bonusAutoRedeem = on
            if on then Bonus.nextCode = 0 end
            SaveConfig()
        end,
    })

    local qGrp = Tab:Group({})
    qGrp:Button({
        Title = "Check Quests Now",
        Justify = "Center",
        Callback = function() task.spawn(QuestReport) end,
    })
    qGrp:Button({
        Title = "Redeem All Active Codes",
        Justify = "Center",
        Callback = function()
            task.spawn(function()
                Bonus.CheckCodes()
                Notify(Bonus.codeText, "Promo Codes")
            end)
        end,
    })
end)

-- 4C. Tab: Visual Cosmetics & Roles ----------------------------------
SafeUI("Tab:Visual", function()
    local Tab = SecuritySection:Tab({
        Title = "Cosmetics & Roles",
        Icon = "solar:check-square-bold",
        IconColor = Blue,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.visual = Tab

    Tab:Section({ Title = "Client-Side Visual Wearables" })

    local wearMap = {}
    local wearDd
    Tab:Input({
        Title = "Search Wearable / Cosmetic",
        Placeholder = "e.g. Rayman, Wings,Katana...",
        Callback = function(q)
            wearMap = {}
            local vals = {}
            local query = Trim(q):lower()
            for _, w in ipairs(GetWearables()) do
                if query == "" or w.lower:find(query, 1, true) then
                    local lbl = string.format("%s [%d] (%s)", w.name, w.id, w.slot)
                    wearMap[lbl] = w.id
                    table.insert(vals, lbl)
                    if #vals >= 30 then break end
                end
            end
            if #vals == 0 then vals = { "No matching items" } end
            if wearDd and wearDd.Refresh then pcall(function() wearDd:Refresh(vals) end) end
        end,
    })

    wearDd = Tab:Dropdown({
        Title = "Equip / Unequip Visual Item",
        Values = { "Search for an item above..." },
        Callback = function(sel)
            local id = wearMap[sel]
            if id then
                ToggleVisual(id)
                Notify("Toggled visual item: " .. ItemName(id))
            end
        end,
    })

    Tab:Button({
        Title = "Reset All Visual Wearables",
        Justify = "Center",
        Callback = ResetVisuals,
    })

    Tab:Space()
    Tab:Section({ Title = "Watermark & Title Role" })

    Tab:Toggle({
        Title = "Custom Animated NameTag Watermark",
        Value = Config.customWatermark,
        Callback = function(on) Config.customWatermark = on; SaveConfig() end,
    })

    Tab:Input({
        Title = "Custom Watermark Text",
        Value = Config.watermarkText,
        Placeholder = "ANCH HUB",
        Callback = function(t)
            local v = Trim(t or "")
            if v ~= "" then Config.watermarkText = v; SaveConfig() end
        end,
    })

    local roleDd = Tab:Dropdown({
        Title = "Select Owned Title / Role",
        Values = GetOwnedRoles(),
        Value = Config.selectedRole or "none",
        Callback = function(v)
            Config.selectedRole = v or "none"
            SaveConfig()
            ApplyRole(Config.selectedRole)
        end,
    })

    Tab:Button({
        Title = "Refresh Owned Roles",
        Justify = "Center",
        Callback = function()
            if roleDd and roleDd.Refresh then
                pcall(function() roleDd:Refresh(GetOwnedRoles()) end)
                Notify("Owned roles list refreshed!")
            end
        end,
    })
end)

-- 5A. Tab: Discord Webhook & System Settings -------------------------
SafeUI("Tab:Settings", function()
    local Tab = SystemSection:Tab({
        Title = "Webhook & Settings",
        Icon = "solar:folder-with-files-bold",
        IconColor = Green,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.settings = Tab

    local whPara = Tab:Paragraph({ Title = "Discord Webhook Status", Desc = "Last Status: -" })

    task.spawn(function()
        while alive() and task.wait(1) do
            pcall(function()
                SetElementText(whPara, "Discord Webhook: " .. (Config.webhookOn and "ENABLED" or "DISABLED"), "Delivery Status: " .. tostring(Webhook.Status))
            end)
        end
    end)

    Tab:Toggle({
        Title = "Enable Discord Webhook Notifications",
        Value = Config.webhookOn,
        Callback = function(on) Config.webhookOn = on; SaveConfig() end,
    })

    Tab:Input({
        Title = "Discord Webhook URL",
        Value = Config.webhookUrl,
        Placeholder = "https://discord.com/api/webhooks/...",
        Callback = function(t) Config.webhookUrl = Trim(t or ""); SaveConfig() end,
    })

    Tab:Slider({
        Title = "Periodic Session Report Interval (minutes, 0 = Off)",
        IsTooltip = true,
        Step = 5,
        Value = { Min = 0, Max = 120, Default = math.clamp(Config.webhookReportMin, 0, 120) },
        Callback = function(v) Config.webhookReportMin = tonumber(v) or 0; SaveConfig() end,
    })

    Tab:Button({
        Title = "Send Test Webhook",
        Color = Color3.fromHex("#305dff"),
        Justify = "Center",
        Callback = function()
            if not Webhook.Valid(Config.webhookUrl) then
                Notify("Invalid Discord Webhook URL!")
            else
                local old = Config.webhookOn
                Config.webhookOn = true
                Webhook.Send("test", "Test connection from **ANCH Hub | GrowBlox**! World: `" .. CurrentWorldName() .. "`")
                Config.webhookOn = old
                Notify("Test message queued!")
            end
        end,
    })

    Tab:Space()
    Tab:Section({ Title = "Session & Auto-Execute on Teleport" })

    Tab:Toggle({
        Title = "Auto-Restore Enabled Features on Startup",
        Value = Config.autoRestore,
        Callback = function(on) Config.autoRestore = on; SaveConfig() end,
    })

    Tab:Toggle({
        Title = "Auto-Reload Script on World Teleport",
        Value = Config.autoReload,
        Callback = function(on) Config.autoReload = on; SaveConfig() end,
    })

    Tab:Input({
        Title = "Script Reload URL (Optional for queue_on_teleport)",
        Value = Config.scriptUrl,
        Placeholder = "https://raw.githubusercontent.com/...",
        Callback = function(t) Config.scriptUrl = Trim(t or ""); SaveConfig() end,
    })

    local sysGrp = Tab:Group({})
    sysGrp:Button({
        Title = "Install Loader to Autoexec",
        Justify = "Center",
        Callback = InstallAutoexec,
    })
    sysGrp:Button({
        Title = "Rejoin Current Server",
        Justify = "Center",
        Callback = Rejoin,
    })
end)

pcall(function()
    Window:SetToggleKey(Enum.KeyCode.RightControl)
end)

----------------------------------------------------------------------
-- CHAT COMMAND HANDLER
----------------------------------------------------------------------
do (function()
    local function parseToggle(arg, current)
        if not arg or arg == "" then return not current end
        arg = arg:lower()
        if arg == "on" or arg == "1" or arg == "true" then return true end
        if arg == "off" or arg == "0" or arg == "false" then return false end
        return not current
    end

    local function processText(raw)
        if type(raw) ~= "string" then return false end
        local p = Config.prefix or "/"
        if raw:sub(1, #p) ~= p then return false end
        local body = Trim(raw:sub(#p + 1))
        if body == "" then return false end
        local cmd, rest = body:match("^(%S+)%s*(.*)$")
        if not cmd then return false end
        cmd = cmd:lower()

        if cmd == "wld" or cmd == "wd" then
            task.spawn(DropWorldLock, tonumber(rest))
            return true
        elseif cmd == "tp" or cmd == "warp" then
            task.spawn(WarpToWorld, rest)
            return true
        elseif cmd == "pos1" then SetPos(1); return true
        elseif cmd == "pos2" then SetPos(2); return true
        elseif cmd == "win1" or cmd == "w1" then task.spawn(GoToPos, 1, tonumber(rest)); return true
        elseif cmd == "win2" or cmd == "w2" then task.spawn(GoToPos, 2, tonumber(rest)); return true
        elseif cmd == "pos" then ShowPos(); return true
        elseif cmd == "rejoin" or cmd == "rj" then Rejoin(); return true
        elseif cmd == "noclip" then SetFeature("noclip", parseToggle(rest, noclipOn)); return true
        elseif cmd == "unlimitedjump" or cmd == "uj" then SetFeature("ujump", parseToggle(rest, ujumpOn)); return true
        elseif cmd == "blink" then SetFeature("blink", parseToggle(rest, blinkOn)); return true
        elseif cmd == "longhand" or cmd == "lh" then
            local n = tonumber(rest)
            if n then Config.longhandRange = n; SaveConfig(); SetFeature("longhand", true)
            else SetFeature("longhand", parseToggle(rest, longhandOn)) end
            return true
        elseif cmd == "afk" then SetFeature("antiafk", parseToggle(rest, antiAfkOn)); return true
        elseif cmd == "autorejoin" or cmd == "arj" then SetFeature("autorejoin", parseToggle(rest, Config.reconnectOn)); return true
        elseif cmd == "af" or cmd == "autofarm" then SetFeature("autofarm", parseToggle(rest, Farm.on)); return true
        elseif cmd == "ac" or cmd == "autoclear" then SetFeature("autoclear", parseToggle(rest, Clear.on)); return true
        elseif cmd == "ah" or cmd == "autoharvest" then SetFeature("autoharvest", parseToggle(rest, Farmer.on)); return true
        elseif cmd == "adf" or cmd == "autodf" then SetFeature("autodf", parseToggle(rest, DF.on)); return true
        elseif cmd == "as" or cmd == "autosplice" then SetFeature("autosplice", parseToggle(rest, SpliceBot.on)); return true
        elseif cmd == "pabrik" or cmd == "factory" then SetFeature("pabrik", parseToggle(rest, Pabrik.on)); return true
        elseif cmd == "guard" or cmd == "penjaga" then SetFeature("guard", parseToggle(rest, Guard.on)); return true
        elseif cmd == "chat" or cmd == "autochat" then SetFeature("autochat", parseToggle(rest, Spam.on)); return true
        elseif cmd == "ctp" or cmd == "clicktp" then SetFeature("clicktp", parseToggle(rest, Nav.clickOn)); return true
        elseif cmd == "god" then SetFeature("god", parseToggle(rest, godOn)); return true
        elseif cmd == "lite" then SetFeature("lite", parseToggle(rest, Config.liteMode)); return true
        elseif cmd == "gs" or cmd == "growscan" then OpenNativeGrowScan(); return true
        elseif cmd == "blockid" or cmd == "bid" then
            local res = SearchItems(rest, 5)
            if #res == 0 then Notify("No blocks matching: " .. tostring(rest))
            else
                local out = {}
                for _, e in ipairs(res) do table.insert(out, e.name .. " [" .. e.id .. "]") end
                Notify(table.concat(out, ", "), "Block ID Search")
            end
            return true
        end
        return false
    end

    local hookedBoxes = {}
    local function hookBox(d)
        if d:IsA("TextBox") and not hookedBoxes[d] then
            hookedBoxes[d] = true
            trackConn(d.FocusLost:Connect(function(enterPressed)
                if enterPressed and alive() then processText(d.Text) end
            end))
        end
    end
    for _, d in ipairs(PlayerGui:GetDescendants()) do hookBox(d) end
    trackConn(PlayerGui.DescendantAdded:Connect(hookBox))
    trackConn(Player.Chatted:Connect(processText))
end)() end
end)() end

----------------------------------------------------------------------
-- INITIALIZATION & CLEANUP HANDLER
----------------------------------------------------------------------
Session.Cleanup = function()
    Session.Alive = false
    ReleaseInput()
    AutoInput.active = false
    if Farm.on then pcall(StopFarm) end
    if Clear.on then pcall(Clear.Stop) end
    if Farmer.on then pcall(Farmer.Stop) end
    if DF.on then pcall(DF.Stop) end
    if SpliceBot.on then pcall(SpliceBot.Stop) end
    if Pabrik.on then pcall(Pabrik.Stop) end
    if AutoMove and AutoMove.Stop then pcall(AutoMove.Stop) end
    if Vend and Vend.Stop then pcall(Vend.Stop) end
    if Nav.clickOn then pcall(Nav.StopClick) end
    if blinkOn then pcall(StopBlink) end
    if longhandOn then pcall(StopLonghand) end
    if noclipOn then pcall(StopNoclip) end
    if ujumpOn then pcall(StopUjump) end
    if godOn then pcall(StopGod) end
    if antiAfkOn then pcall(StopAntiAfk) end
    if Config.liteMode then pcall(LiteMode.Set, false) end
    if Session.RestoreWatermark then pcall(Session.RestoreWatermark) end
    if Session.RestoreFastWrench then pcall(Session.RestoreFastWrench) end
    if Session.RestoreFastBackpack then pcall(Session.RestoreFastBackpack) end
    for _, conn in ipairs(Session.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(Session.Connections)
    if GridGui then pcall(function() GridGui:Destroy() end) end
    if FlyPadGui then pcall(function() FlyPadGui:Destroy() end) end
    if Window and Window.Destroy then pcall(function() Window:Destroy() end) end
    if Session.Rotation and Session.Rotation.Stop then pcall(Session.Rotation.Stop) end
end

task.spawn(function()
    G.__ANCHHub_LoadingAt = nil
    UIInitializing = false
    Notify("ANCH HUB V1.3 Loaded! All features are ready.", "ANCH HUB", 4, true)

    StartAntiAfk()
    Refs.Scan(true)
    Stats.Reset()
    if Config.liteMode then LiteMode.Set(true) end

    trackConn(Player.OnTeleport:Connect(function()
        UIInitializing = false
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
    task.spawn(Pabrik.CheckStartup)
    task.spawn(AutoMove.CheckStartup)
    task.spawn(Session.Rotation.CheckStartup)

    local lastSeenWorld = CurrentWorldName()
    while alive() do
        task.wait(1.5)
        local curW = CurrentWorldName()
        if curW ~= "" and curW ~= lastSeenWorld then
            lastSeenWorld = curW
            Refs.Scan(true)
        end
    end
end)
