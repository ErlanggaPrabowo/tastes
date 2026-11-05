--[[
    ANCH HUB | GrowBlox  (v10 Ultimate - Legit A* Walking, Pillar Climb & All-in-One WindUI)
    Gabungan penuh fitur Peex/ANCH Hub + SkyP Engine (ByteNet & Classic Compatible)

    Daftar Perintah Chat (Prefix default "/"):
      wld|wd <jumlah>             Drop World Lock
      tp|warp <world>             Pindah world
      pos1 | pos2                 Simpan posisi sekarang
      win1|w1 | win2|w2 [jumlah]  Teleport ke Pos 1 / Pos 2 (+opsional drop WL)
      pos                         Lihat posisi sekarang & pos tersimpan
      rejoin|rj                   Masuk ulang ke world ini
      noclip [on|off]             Fly + tembus blok (+ tombol layar ▲/▼)
      unlimitedjump|uj            Lompat di udara tanpa batas (Jammer + Upvalue)
      blink [on|off]              Warna skin berganti otomatis
      longhand|lh [n|off]         Jangkauan punch/build lebih jauh
      visualitem|vi               GUI item visual (lokal)
      settingsgb|sgb              GUI pengaturan
      afk                         Anti-AFK
      autorejoin|arj              Rejoin otomatis kalau disconnect
      session|sesi                GUI sesi (simpan & pulihkan otomatis)
      af|autofarm [on|off]        Auto Farm (Multi-target, Rayman, Grid 5x5)
      ac|autoclear [on|off]       Auto Clear World (Legit Walk + Pillar Climb + ModFly)
      ah|autoharvest [on|off]     Auto Harvest & Auto Plant (Farmer)
      adf|autodf [on|off]         Auto Dirt Farm (Half DF Builder + Pillar Climb)
      guard|penjaga [on|off]      Anti-Mod / Staff & Player Detector
      chat|autochat [on|off]      Auto Chat / Spammer
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

local ItemDB = Shared and require(Shared:WaitForChild("ItemDB", 5)) or {}
local InvModOk, InventoryModule = pcall(function() return require(Shared:WaitForChild("Inventory", 5)) end)
local NetOk, Net = pcall(function() return require(Shared:WaitForChild("Net", 5)) end)
local RolesOk, RolesModule = pcall(function() return require(Shared:FindFirstChild("Roles")) end)
local SfxOk, SfxModule = pcall(function() return require(Shared:FindFirstChild("Sfx")) end)

local GameGui = PlayerGui:WaitForChild("GameGui", 10)
local ParticlesOk, ParticlesModule = pcall(function() return require(GameGui:WaitForChild("Particles", 5)) end)
local MenuModOk, MenuModule = pcall(function() return require(GameGui:WaitForChild("WorldMenu", 5)) end)

----------------------------------------------------------------------
-- CONFIG & STATE GLOBAL
----------------------------------------------------------------------
local CONFIG_FILE = "ANCHHub_GrowBlox.json"
local SCRIPT_FILE = "ANCHHub_GrowBlox.lua"
local MAX_AMOUNT = 10000
local COOLDOWN = 0.3
local PLACE_GUARD = 0.34 -- Game mengabaikan pukulan ke tile yang baru dipasang < 0.32 dtk

local Config = {
    prefix = "/",
    dropId = 242,
    longhandRange = 3,
    blinkMin = 0.2,
    blinkMax = 0.5,
    winDrop = 0,
    pos1 = {},
    pos2 = {},
    -- Sesi
    autoRestore = true,
    autoReload = true,
    autoWarp = false,
    launcher = true,
    lastWorld = "",
    scriptUrl = "",
    session = {},
    -- Karakter & Misc
    walkSpeed = 100,
    mutePunch = true,
    liteMode = false,
    customWatermark = true,
    watermarkText = "ANCH HUB",
    calibX = 0,
    calibY = 0,
    -- Auto Farm
    farmMode = "Place + Break", -- "Place + Break" | "Break saja" | "Place saja"
    farmPlaceMs = 250,
    farmDelay = 0.22,
    farmAfterBreakMs = 300,
    farmMultiTarget = 1,
    farmHitsOverride = 0,
    farmBreakBg = true,
    farmPlaceId = 2,
    farmGrid = { ["1,0"] = true },
    farmTake = true,
    -- Auto Clear World
    clearSweep = "Zig-zag",     -- "Kiri → Kanan" | "Zig-zag"
    clearUseBlock = true,
    clearScaffoldId = 2,
    clearIncludeBg = true,
    clearBreakDelay = 0.16,
    clearTpDelay = 0.30,
    clearTake = true,
    clearModFly = false,        -- Default false karena kita pakai Legit Walk + Pillar
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
    -- Auto Dirt Farm (DF)
    dfBreakDelay = 0.15,
    dfTpDelay = 0.30,
    dfTake = true,
    dfModFly = false,
    dfReplacePlatform = true,
    -- Navigasi / Pathfinding
    moveMode = "legit",         -- "legit" = A* Physical Walk + Pillar Jump | "walk" | "fly" | "mix"
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
    -- Auto Chat
    chatTexts = "ANCH Hub Terbaik!|Jual Dirt Murah",
    chatInterval = 6,
    -- Bonus
    bonusAutoQuest = false,
    bonusAutoRedeem = false,
    -- GrowScan
    scanAuto = false,
    scanLayer = "Semua",
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
        Refs.Particles = {}
        for _, v in ipairs(getgcFn(true)) do
            local tv = type(v)
            if tv == "table" then
                if not Refs.World then
                    local ok, valid = pcall(function()
                        return type(rawget(v, "fg")) == "table" and type(rawget(v, "bg")) == "table"
                            and type(rawget(v, "w")) == "number" and type(rawget(v, "h")) == "number"
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

        -- Fallback cari hit/setTile berdasarkan debug.info name
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

        -- Fallback Inv dari world.backpackNow
        if not Refs.Inv and Refs.World and type(rawget(Refs.World, "backpackNow")) == "function" then
            for _, u in pairs(GetUpvalues(Refs.World.backpackNow)) do
                if type(u) == "table" and type(u.slots) == "table" then
                    Refs.Inv = u
                    break
                end
            end
        end

        -- Cari Drop List & Updater
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

        -- Cari Tabel Pohon (Up[8] dari world.treeLook atau TreeChanged)
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

local function GetItemDB()
    return ItemDB
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
    local h = (it.kind == "seed") and 3 or it.hits
    return h == nil or h > 0
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
-- MESIN NAVIGASI UNIVERSAL: LEGIT WALKING (A*) + PILLAR CLIMB SKYP
-- Digunakan oleh Auto DF, Auto Clear, Auto Harvest/Farmer, Auto Farm,
-- Penjaga (Homing), dan Click TP.
-- Jika Y tujuan berada di atas karakter (ty < sy), otomatis memakai
-- metode Pillar Climb (lompat fisik asli + pasang pijakan Dirt).
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
            Config.clearScaffoldId,
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
        -- Cari block solid apa pun di inventory
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

    -- Binary Heap untuk A*
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

    -- Algoritma A* Fisika Game (walk, fall, jump 1-3, gap 1-2, pillar naik dengan block)
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

    -- Eksekutor Gerak Fisik Legit (SteerX, Walk, Fall, Jump, Gap, Pillar)
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

    -- Naik 1 tile pakai block (Pillar Jump SkyP): lompat fisik, pasang block di bawah kaki saat melayang, lalu mendarat
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

        local function finish(result)
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
                            task.wait(0.14)
                        end
                        if not execWalk(st.x, st.y, cancel) then ok = false; break end
                    end
                else
                    ok = execWalk(path[last].x, path[last].y, cancel)
                end
            elseif e.kind == "pillar" then
                ok = execPillar(e, cancel)
                if ok then task.wait(0.08) end
            elseif e.kind == "fall" then
                ok = execFall(e, cancel)
            elseif e.kind == "jump" then
                ok = execJump(e, cancel)
            elseif e.kind == "gap" then
                ok = execGap(e, cancel)
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

    -- FUNGSI MEMANJAT VERTIKAL UNIVERSAL (CLIMB UP WITH DIRT / SCAFFOLD)
    -- Dipakai kapan saja Y tujuan berada di atas karakter (targetY < currentY)
    function Nav.ClimbUpWithDirt(x, targetY, cancel, cleanBehind, stepDelayOverride)
        local world = FindWorld()
        if not world then return false end
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

        -- Pastikan ada pijakan di bawah kaki sebelum mulai melompat
        if InBounds(world, x, cy + 1) and not realSupport(x, cy) then
            if fgIdAt(x, cy + 1) == 0 and placeScaffold(x, cy + 1) then
                tempPlaced[cy + 1] = scaffoldBlock
                task.wait(PLACE_GUARD)
            end
        end

        while cy > targetY and alive() do
            if cancel and cancel() then restore(); return false end
            local nextY = cy - 1

            -- Jika ruang di atas kepala tertutup block yang bisa dihancurkan, pecahkan dulu
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

            -- Gunakan execPillar (lompat fisik asli + pasang pijakan di bawah kaki)
            local okPillar = execPillar({ fx = x, fy = cy, x = x, y = nextY }, cancel)
            if okPillar then
                tempPlaced[cy] = scaffoldBlock
            else
                -- Cadangan jika terhalang sedikit: pasang pijakan lalu melangkah
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

            -- Jika diminta bersih (seperti di kolom pinggir Auto DF), hancurkan pijakan lama 2 blok di bawah kaki (cy + 2)
            -- karena kaki kita saat ini sudah menapak aman di (cy + 1)
            if cleanBehind then
                local oldY = cy + 2
                if tempPlaced[oldY] and fgIdAt(x, oldY) ~= 0 and CanBreakId(fgIdAt(x, oldY)) then
                    WaitPlaceGuard(x, oldY)
                    local t0 = os.clock()
                    while fgIdAt(x, oldY) ~= 0 and os.clock() - t0 < 3.5 do
                        if cancel and cancel() then restore(); return false end
                        TryBreakOnce(x, oldY, false)
                        task.wait(0.16)
                    end
                    tempPlaced[oldY] = nil
                end
            end
        end

        -- Jika sampai di puncak dan cleanBehind aktif, geser 1 langkah ke samping yang ada pijakan lalu hancurkan sisa pijakan terakhir
        if cleanBehind then
            local sideX = (x <= 2) and 2 or (world.w - 3)
            if InBounds(world, sideX, targetY) and realSupport(sideX, targetY) then
                execWalk(sideX, targetY, cancel)
                task.wait(settleDelay)
                for py, _ in pairs(tempPlaced) do
                    if fgIdAt(x, py) ~= 0 and math.abs(py - targetY) <= 2 and CanBreakId(fgIdAt(x, py)) then
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

    -- FUNGSI NAVIGASI UTAMA (DIPAKAI SELURUH FITUR):
    -- 1. Mencari jalur Legit Walking & Jump/Pillar via A*
    -- 2. Jika target Y berada di atas player (ty < sy) dan butuh naik, otomatis menggunakan Pillar Climb
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

        -- Coba cari rute A* Legit (sudah termasuk walk, jump, fall, gap, dan pillar naik)
        local path = Nav.AStar(sx, sy, goals, tx, ty, R, allowScaffold, cancel)
        if path and #path > 0 then
            if Nav.FollowPath(path, cancel) then
                return true, os.clock() - started
            end
        end

        -- Jika target Y berada di atas player (ty < sy), gunakan metode memanjat Pillar Climb!
        local cx, cy = GetTile()
        if cx and cy and ty < cy then
            local okClimb = Nav.ClimbUpWithDirt(cx, ty, cancel, false, Config.moveStepDelay)
            if okClimb then
                cx, cy = GetTile()
                if cx and cx ~= tx then
                    local goalsAfter = { [ty * w.w + tx] = true }
                    local pathAfter = Nav.AStar(cx, cy, goalsAfter, tx, ty, R, allowScaffold, cancel)
                    if pathAfter and #pathAfter > 0 then
                        Nav.FollowPath(pathAfter, cancel)
                    else
                        -- Jalan bertahap sambil pasang jembatan jika bawah kosong
                        local dir = (tx > cx) and 1 or -1
                        for stepX = cx + dir, tx, dir do
                            if cancel and cancel() then return false, "cancel" end
                            if allowScaffold and not realSupport(stepX, ty) and placeOk(stepX, ty + 1) then
                                placeScaffold(stepX, ty + 1)
                                task.wait(0.14)
                            end
                            if not execWalk(stepX, ty, cancel) then
                                pcall(w.goTo, stepX, ty)
                                task.wait(math.max(0.28, Config.moveStepDelay))
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

    -- Fallback BFS / Fly untuk mode "walk" / "fly" / "mix"
    function Nav.StepGoTo(tx, ty, cancel, flyMode)
        local started = os.clock()
        local w = FindWorld()
        if not w or type(w.goTo) ~= "function" then return false, "world" end
        local sx, sy = GetTile()
        if not sx then return false, "pos" end

        -- Bahkan di mode StepGoTo, jika ty < sy (tujuan di atas player), wajib gunakan ClimbUpWithDirt agar tidak kena rollback!
        if ty < sy then
            Nav.ClimbUpWithDirt(sx, ty, cancel, false, Config.moveStepDelay)
            sx, sy = GetTile()
            if not sx then return false, "pos" end
        end

        local dx, dy = tx - sx, ty - sy
        local steps = math.max(abs(dx), abs(dy))
        if steps == 0 then return true, 0 end
        local stepDelay = math.max(0.25, tonumber(Config.moveStepDelay) or 0.30)

        if flyMode then w.ghost = true end
        for i = 1, steps do
            if cancel and cancel() then
                SyncGhostState()
                return false, "cancel"
            end
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

    -- Click TP Kamera -> Tile
    local actFn = nil
    local function CamInfo()
        if not actFn and getgcFn and debug and debug.info then
            for _, fn in ipairs(getgcFn(true)) do
                if type(fn) == "function" then
                    local okN, fnName = pcall(debug.info, fn, "n")
                    if okN and fnName == "act" then
                        local ups = GetUpvalues(fn)
                        if ups[1] == Players and type(ups[2]) == "number" and type(ups[4]) == "number" and type(ups[5]) == "number" then
                            actFn = fn
                            break
                        end
                    end
                end
            end
        end
        if not actFn then return nil end
        local okX, camX = pcall(getupvalueFn, actFn, 2)
        local okT, tile = pcall(getupvalueFn, actFn, 4)
        local okY, camY = pcall(getupvalueFn, actFn, 5)
        if okX and okT and okY and type(camX) == "number" and type(tile) == "number" and type(camY) == "number" and tile > 0 then
            return camX, camY, tile
        end
        return nil
    end

    function Nav.ScreenToTile(pos)
        local camX, camY, tile = CamInfo()
        if not camX then return nil end
        local worldGui = PlayerGui:FindFirstChild("World", true)
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
-- FAST PARALLEL AUTO-COLLECT (SKYP ENGINE: world.takeDrop TIAP FRAME)
----------------------------------------------------------------------
local Farm = { on = false, token = 0, stats = { status = "Mati", placed = 0, broken = 0, picked = 0, fail = 0, cycles = 0 } }
local Clear = { on = false, token = 0, status = "Mati", stats = { scanned = 0, broken = 0, picked = 0, skipped = 0, left = 0, pass = 0, row = -1 } }
local Farmer = { on = false, token = 0, status = "Mati", stats = { totalTrees = 0, ready = 0, harvested = 0, planted = 0, skipped = 0, picked = 0 } }
local DF = { on = false, token = 0, status = "Mati", stats = { topDirtY = 0, bedrockY = 0, broken = 0, placed = 0, picked = 0, step = "-" } }

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
        if not canTryDrop(d, os.clock()) then return false end

        local amount = d.n
        if d.id ~= 112 and Refs.Inv and type(Refs.Inv.room) == "function" then
            local okR, room = pcall(function() return Refs.Inv:room(d.id) end)
            if okR and type(room) == "number" then amount = math.min(amount, room) end
        end
        if amount <= 0 then
            if d.uid then DropFailUntil[d.uid] = os.clock() + 1 end
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

        Farm.stats.picked += taken
        if Clear.on then Clear.stats.picked += taken end
        if Farmer.on then Farmer.stats.picked += taken end
        if DF.on then DF.stats.picked += taken end
        return true
    end

    local nextDropScan = 0
    trackConn(RunService.Heartbeat:Connect(function()
        if not alive() then return end
        local farmArea = Farm.on and Config.farmTake
        local nearArea = (Clear.on and Config.clearTake)
            or (Farmer.on and Config.harvestTake)
            or (DF.on and Config.dfTake)
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

        for i = #list, 1, -1 do
            local d = list[i]
            if canTryDrop(d, now) then
                local hit = math.abs(d.x - cx) <= 3.2 and math.abs(d.y - cy) <= 3.2
                if not hit and farmArea then
                    for key, on in pairs(Config.farmGrid) do
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
-- 1. AUTO FARM (MULTI-TARGET + RAYMAN'S FIST + FLOATING GRID 5X5)
----------------------------------------------------------------------
local RefreshHub
local GridGui = nil
local UpdateGridVisuals = nil

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

    local function sortedOffsets()
        local list = {}
        for key, on in pairs(Config.farmGrid) do
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

            local doPlace = Config.farmMode ~= "Break saja"
            local doBreak = Config.farmMode ~= "Place saja"
            local id = Config.farmPlaceId
            local offsets = sortedOffsets()
            if #offsets == 0 then
                Farm.stats.status = "Pilih kotak di Grid 5x5 dulu"
                Notify("Auto Farm: pilih minimal 1 kotak di Grid 5x5.")
                break
            end

            -- Pastikan karakter berada di titik anchor farm
            local px, py = GetTile()
            if not px then break end
            if px ~= anchor.x or py ~= anchor.y then
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

            -- 1) Place semua tile kosong
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

            -- 2) Break (Mendukung Multi-Target 1-5 & Rayman's Fist)
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
                    Notify("Auto Farm berhenti: " .. ItemName(id) .. " habis di inventori.")
                    break
                end
                task.wait(math.max(0.1, Config.farmDelay))
            end

            Farm.stats.cycles += 1
        end
    end

    function StopFarm()
        if not Farm.on then return false end
        Farm.token += 1
        Farm.on = false
        Farm.stats.status = "Mati"
        if UpdateGridVisuals then pcall(UpdateGridVisuals) end
        return true
    end

    function StartFarm()
        if Farm.on then return true end
        if Clear.on then Clear.Stop() end
        if Farmer.on then Farmer.Stop() end
        if DF.on then DF.Stop() end

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
-- 2. AUTO CLEAR WORLD (LEGIT WALKING + PILLAR CLIMB + MODFLY OPTION)
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
                    local key = x .. "," .. y .. "," .. layer
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

    local function GetStandSpot(w, target)
        -- Prioritas berdiri di atas block (x, y - 1) atau di sampingnya (x - 1, y) / (x + 1, y)
        local candidates = {
            { x = target.x,     y = target.y - 1 },
            { x = target.x - 1, y = target.y },
            { x = target.x + 1, y = target.y },
            { x = target.x - 1, y = target.y - 1 },
            { x = target.x + 1, y = target.y - 1 },
        }
        for _, pos in ipairs(candidates) do
            if InBounds(w, pos.x, pos.y) and Nav.OpenAt(pos.x, pos.y) then
                return pos
            end
        end
        return { x = target.x, y = math.max(0, target.y - 1) }
    end

    local function ClearLoop(token, home)
        if Config.clearModFly then
            SetAutoFly("autoclear", true)
        end

        local skippedSet = {}
        local pass = 0

        while Clear.on and Clear.token == token and alive() do
            pass += 1
            local w = FindWorld()
            if not w or CurrentWorldName() ~= home.world then
                Clear.status = "World berubah, berhenti"
                break
            end

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
                Notify(string.format("Auto Clear: %d objek ditemukan. Mulai dari (%d, %d).", #targets, first.x, first.y))
            end

            local brokeAny = false

            for idx, target in ipairs(targets) do
                if not Clear.on or Clear.token ~= token or not alive() then return end
                w = FindWorld()
                if not w or CurrentWorldName() ~= home.world then return end

                local curLayer, curId = ClearLayerAt(w, target.x, target.y)
                if curLayer then
                    Clear.stats.row = target.y
                    local spot = GetStandSpot(w, target)
                    local px, py = GetTile()
                    local s = PlayerPhysicsState()
                    local R = PunchReach() - 0.15

                    -- Jika target berada di luar jangkauan pukulan, bergerak dengan Legit Walk + Pillar Climb
                    if not (s and Nav.StateReaches(s, target.x, target.y, R)) then
                        Clear.status = string.format("Jalan ke (%d,%d) -> Break (%d,%d) [%d/%d]", spot.x, spot.y, target.x, target.y, idx, #targets)
                        -- Jika tujuan Y berada di atas posisi karakter sekarang (spot.y < py), otomatis gunakan Pillar Climb!
                        if py and spot.y < py then
                            Nav.ClimbUpWithDirt(px, spot.y, function() return Clear.token ~= token end, false, Config.clearTpDelay)
                        end
                        Nav.To(spot.x, spot.y, function() return Clear.token ~= token end, R, Config.clearUseBlock)
                        task.wait(math.max(0.10, Config.clearTpDelay))
                    end

                    if Config.clearModFly then
                        SetAutoFly("autoclear", true)
                    end

                    local started = os.clock()
                    local timedOut = false
                    Clear.status = string.format("Break %s (%d,%d) [%d/%d]", ItemName(curId), target.x, target.y, idx, #targets)

                    while Clear.on and Clear.token == token and alive() do
                        local lNow = ClearLayerAt(w, target.x, target.y)
                        if not lNow then break end
                        if os.clock() - started >= BREAK_TIMEOUT then
                            timedOut = true
                            break
                        end
                        local r = TryBreakOnce(target.x, target.y, Config.clearIncludeBg)
                        if r == "broke" then
                            brokeAny = true
                            Clear.stats.broken += 1
                            started = os.clock() -- reset timer jika berhasil memecahkan fg dan lanjut ke bg
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
        Notify(string.format("Auto Clear selesai! Hancur: %d | Diambil: %d | Skip: %d", Clear.stats.broken, Clear.stats.picked, Clear.stats.skipped))
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
-- 3. FARMER: AUTO HARVEST + AUTO PLANT (GABUNGAN SKYP FARMER & HARVEST)
----------------------------------------------------------------------
do (function()
    local function IsSeedId(id)
        local it = ItemDB and ItemDB[id]
        return type(it) == "table" and (it.kind == "seed" or type(it.tree) == "table" or type(it.grow) == "number")
    end

    local function IsTreeReady(w, x, y, id)
        local it = ItemDB[id]
        if not it then return false end
        local growTime = tonumber(it.grow) or tonumber(it.baseGrow) or 31
        local idx = y * w.w + x

        if type(w.treeLook) == "function" then
            pcall(w.treeLook, x, y)
        end

        if not Refs.Trees then Refs.Scan() end
        local entry = Refs.Trees and Refs.Trees[idx]
        if type(entry) == "table" then
            if entry.ripe == true or entry.fruitMade == true or entry.step == 1 then
                return true
            end
            if type(entry.tree) == "table" and type(entry.tree.p) == "number" then
                return workspace:GetServerTimeNow() >= (entry.tree.p + growTime)
            end
            if type(entry.p) == "number" then
                return workspace:GetServerTimeNow() >= (entry.p + growTime)
            end
            if entry.ripe == false or (type(entry.step) == "number" and entry.step < 1) then
                return false
            end
        end

        local placedFg = w.placedAt and w.placedAt.fg
        if placedFg and type(placedFg[idx]) == "number" then
            return (os.clock() - placedFg[idx]) >= growTime
        end
        return false
    end

    local function CanPlantAt(w, x, y)
        if not InBounds(w, x, y) or y + 1 >= w.h then return false end
        if (TileValue(w, "fg", x, y) or 0) ~= 0 then return false end
        local below = TileValue(w, "fg", x, y + 1) or 0
        if below == 0 then return false end
        local it = ItemDB[below]
        if not it or it.kind == "seed" then return false end
        return (Nav.SolidAt(x, y + 1) or it.platform) and true or false
    end

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
                    elseif doPlant and id == 0 and CanPlantAt(w, x, y) then
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

            -- 1) Panen seluruh pohon yang siap
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
                            Nav.ClimbUpWithDirt(px, tree.y, function() return Farmer.token ~= token end, false, Config.harvestTpDelay)
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
                        Farmer.stats.ready = math.max(0, Farmer.stats.ready - 1)
                        -- Jika Auto Plant aktif dan ada seed, langsung tanam di tile yang baru dipanen!
                        if Config.harvestDoPlant and Config.harvestSeedId and CountItem(Config.harvestSeedId) > 0 and CanPlantAt(w, tree.x, tree.y) then
                            task.wait(0.08)
                            if PlaceCell(Config.harvestSeedId, { x = tree.x, y = tree.y }, 1) then
                                Farmer.stats.planted += 1
                                task.wait(math.max(0.05, Config.harvestPlantDelay))
                            end
                        end
                    else
                        failedSet[tree.x .. "," .. tree.y] = true
                        Farmer.stats.skipped += 1
                    end
                end
            end

            -- 2) Tanam seed di lahan yang kosong (jika Auto Plant aktif)
            if Config.harvestDoPlant and Config.harvestSeedId and CountItem(Config.harvestSeedId) > 0 then
                for idx, spot in ipairs(plantSpots) do
                    if not Farmer.on or Farmer.token ~= token or not alive() then return end
                    if CountItem(Config.harvestSeedId) <= 0 then break end
                    w = FindWorld()
                    if not w or CurrentWorldName() ~= home.world then return end

                    if CanPlantAt(w, spot.x, spot.y) then
                        local px, py = GetTile()
                        local s = PlayerPhysicsState()
                        if not (s and Nav.StateReaches(s, spot.x, spot.y, R)) then
                            Farmer.status = string.format("Menuju tanam (%d,%d) [%d/%d]", spot.x, spot.y, idx, #plantSpots)
                            if py and spot.y < py then
                                Nav.ClimbUpWithDirt(px, spot.y, function() return Farmer.token ~= token end, false, Config.harvestTpDelay)
                            end
                            Nav.To(spot.x, spot.y, function() return Farmer.token ~= token end, R, Config.harvestUseBlock)
                            task.wait(math.max(0.10, Config.harvestTpDelay))
                        end

                        if CanPlantAt(w, spot.x, spot.y) and PlaceCell(Config.harvestSeedId, spot, 1) then
                            actedInPass = true
                            Farmer.stats.planted += 1
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
        Notify(string.format("Farmer selesai! Panen: %d | Tanam: %d | Drop: %d", Farmer.stats.harvested, Farmer.stats.planted, Farmer.stats.picked))
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
-- 4. AUTO DIRT FARM (AUTO DF - LEGIT WALK + PILLAR CLIMB)
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

    local function BreakTotalAt(w, tx, ty, standX, standY, token)
        if not InBounds(w, tx, ty) then return false end
        local fg = TileValue(w, "fg", tx, ty) or 0
        local bg = TileValue(w, "bg", tx, ty) or 0
        if (fg == 0 or not CanBreakId(fg)) and (bg == 0 or not CanBreakId(bg)) then
            return true
        end

        local px, py = GetTile()
        if px ~= standX or py ~= standY then
            if py and standY < py then
                Nav.ClimbUpWithDirt(standX, standY, function() return DF.token ~= token end, false, Config.dfTpDelay)
            elseif not Nav.ExecWalk(standX, standY, function() return DF.token ~= token end) then
                Nav.To(standX, standY, function() return DF.token ~= token end, 0.3, true)
            end
        end

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

    local function EnsurePlatformDirtAt(w, tx, ty, standX, standY, token)
        if not InBounds(w, tx, ty) then return end
        local dirtId = GetDirtId()
        local fg = TileValue(w, "fg", tx, ty) or 0
        if fg == dirtId then return end
        if fg ~= 0 and not CanBreakId(fg) then return end

        local px, py = GetTile()
        if px ~= standX or py ~= standY then
            if not Nav.ExecWalk(standX, standY, function() return DF.token ~= token end) then
                Nav.To(standX, standY, function() return DF.token ~= token end, 0.3, true)
            end
        end

        if fg ~= 0 and fg ~= dirtId then
            local t0 = os.clock()
            while DF.on and DF.token == token and (TileValue(w, "fg", tx, ty) or 0) ~= 0 and os.clock() - t0 < DF_BREAK_TIMEOUT do
                local r = TryBreakOnce(tx, ty, false)
                if r == "broke" then DF.stats.broken += 1 end
                task.wait(math.max(0.04, Config.dfBreakDelay))
            end
        end

        if DF.on and DF.token == token and (TileValue(w, "fg", tx, ty) or 0) == 0 and CountItem(dirtId) > 0 then
            if PlaceCell(dirtId, { x = tx, y = ty }, (tx >= standX) and 1 or -1) then
                DF.stats.placed += 1
                task.wait(0.14)
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
            DF.status = string.format("Panjat naik %s (Pillar Climb)...", label)
            Nav.ClimbUpWithDirt(colB, startY, function() return DF.token ~= token end, true, Config.dfTpDelay)
        end
        return true
    end

    local function DFLoop(token, home)
        local w = FindWorld()
        if not w then return end

        local topDirtY, bedrockY = DetectWorldLayers(w)
        DF.stats.topDirtY = topDirtY
        DF.stats.bedrockY = bedrockY
        Notify(string.format("Auto DF: Lapisan Dirt di Y=%d, Bedrock di Y=%d.", topDirtY, bedrockY))

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
            DF.stats.step = string.format("Baris Kosong Y=%d", emptyY)

            local startX = leftToRight and 2 or (W - 3)
            local endX   = leftToRight and (W - 3) or 2
            local stepX  = leftToRight and 1 or -1
            local entryStandX = leftToRight and 1 or (W - 2)

            local px, py = GetTile()
            if px ~= entryStandX or py ~= emptyY then
                if py and emptyY < py then
                    Nav.ClimbUpWithDirt(entryStandX, emptyY, function() return DF.token ~= token end, true, Config.dfTpDelay)
                else
                    Nav.To(entryStandX, emptyY, function() return DF.token ~= token end, 0.3, true)
                end
            end

            for x = startX, endX, stepX do
                if not DF.on or DF.token ~= token or not alive() then return end
                w = FindWorld()
                if not w or CurrentWorldName() ~= home.world then return end

                local standX = x - stepX
                local standY = emptyY

                if Config.dfReplacePlatform and platformBelowY < bedrockY then
                    EnsurePlatformDirtAt(w, standX, platformBelowY, standX, standY, token)
                end
                if Config.dfReplacePlatform and platformAboveY >= topDirtY then
                    EnsurePlatformDirtAt(w, standX, platformAboveY, standX, standY, token)
                end

                DF.status = string.format("Clear Baris Y=%d | Break (%d,%d)", emptyY, x, emptyY)
                BreakTotalAt(w, x, emptyY, standX, standY, token)

                if Config.dfReplacePlatform then
                    if platformAboveY >= topDirtY then
                        EnsurePlatformDirtAt(w, x, platformAboveY, standX, standY, token)
                    end
                    if platformBelowY < bedrockY then
                        EnsurePlatformDirtAt(w, x, platformBelowY, standX, standY, token)
                    end
                end

                if not Nav.ExecWalk(x, emptyY, function() return DF.token ~= token end) then
                    pcall(w.goTo, x, emptyY)
                    task.wait(math.max(0.22, Config.dfTpDelay))
                end
            end

            leftToRight = not leftToRight
        end

        SetAutoFly("autodf", false)
        ReleaseInput()
        AutoInput.active = false
        DF.stats.step = "Selesai"
        DF.status = "Selesai"
        Notify(string.format("Half Dirt Farm selesai! Hancur: %d | Dirt dipasang: %d | Drop: %d", DF.stats.broken, DF.stats.placed, DF.stats.picked))
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
-- 5. PENJAGA: ANTI-MOD / STAFF & PLAYER DETECTOR (DARI SKYP)
----------------------------------------------------------------------
local Guard = {
    on = false,
    mode = "idle", -- idle | pause | away | out | back
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

local Spam = { on = false, texts = {}, index = 1, sent = 0, last = "-", nextAt = 0 }

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

    local function snapshot()
        local tx, ty = GetTile()
        return {
            farm = Farm.on,
            clear = Clear.on,
            farmer = Farmer.on,
            df = DF.on,
            spam = Spam.on,
            world = CurrentWorldName(),
            tx = tx,
            ty = ty,
        }
    end

    local function stopAllBots()
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
            if rawget(w, "fg") ~= oldFg then return true end
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
                Nav.To(saved.tx, saved.ty, function() return Guard.token ~= token or not Guard.on end, 0.3, true)
            end
        end
        if Guard.token ~= token or not Guard.on then return end
        if saved.farm then StartFarm()
        elseif saved.clear then Clear.Start()
        elseif saved.farmer then Farmer.Start()
        elseif saved.df then DF.Start() end
        if RefreshHub then RefreshHub() end
    end

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
                -- Cek staff di seluruh server
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
                    Notify("Terdeteksi masuk world: " .. namesList(fresh), "PERINGATAN PENJAGA", 6)
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
end)() end

----------------------------------------------------------------------
-- 6. AUTO CHAT, BONUS (NET.CALL QUEST & REDEEM), LITE MODE, WATERMARK
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
    -- Auto Chat
    local function parseChatTexts(raw)
        local out = {}
        for part in string.gmatch(raw or "", "[^|\n]+") do
            part = Trim(part)
            if part ~= "" then table.insert(out, part) end
        end
        return out
    end
    Spam. parse = parseChatTexts
    Spam.texts = parseChatTexts(Config.chatTexts)

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
        if #Spam.texts == 0 then
            Spam.last = "Daftar pesan kosong"
            return false
        end
        local ch = getWorldChannel()
        if not ch then
            Spam.last = "Channel chat belum ada"
            return false
        end
        if Spam.index > #Spam.texts then Spam.index = 1 end
        local msg = Spam.texts[Spam.index]
        Spam.index = (Spam.index % #Spam.texts) + 1
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

    -- Bonus: Server Net.call Quests & Redeem Codes
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
                    Notify("Quest diklaim: " .. stripColor(q.text or q.id), "Bonus ANCH")
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

    -- Mode Lite (Matikan Partikel & Suara)
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

    -- Watermark Nama Animasi (ANCH HUB)
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
-- FITUR TAMBAHAN: BLINK, LONGHAND, UNLIMITED JUMP, GOD MODE, VISUAL, QUEST
----------------------------------------------------------------------
local blinkOn, longhandOn, ujumpOn, antiAfkOn, arjOn, godOn, questOn = false, false, false, false, false, false, false
local questStatus = "Mati"
local StartBlink, StopBlink, ApplyLonghand, StopLonghand, StartUjump, StopUjump
local StartAntiAfk, StopAntiAfk, StartAutoRejoin, StopAutoRejoin, StartGod, StopGod
local StartQuest, StopQuest, QuestReport, OpenNativeGrowScan, ScanWorld, SearchItems
local IsVisualWorn, ToggleVisual, ResetVisuals, GetWearables

do (function()
    -- Blink Skin
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

    -- Longhand
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

    -- Unlimited Jump (Gabungan Jammer 4992 SkyP + Upvalue RenderStepped)
    local origJammerOn = nil
    local ujumpConn = nil
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
        if ujumpConn then ujumpConn:Disconnect(); ujumpConn = nil end
        return true
    end

    -- Anti-AFK & Auto Rejoin
    local afkConn, arjConn = nil, nil
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
        if arjOn then return true end
        local ok, overlay = pcall(function()
            local gui = game:GetService("CoreGui"):WaitForChild("RobloxPromptGui", 5)
            return gui and gui:WaitForChild("promptOverlay", 5)
        end)
        if not ok or not overlay then Notify("Auto rejoin tidak didukung executor ini."); return false end
        arjOn = true
        arjConn = trackConn(overlay.ChildAdded:Connect(function(child)
            if child.Name == "ErrorPrompt" and arjOn and alive() then
                Notify("Terputus! Rejoin dalam 3 detik...")
                task.wait(3)
                Rejoin()
            end
        end))
        return true
    end

    function StopAutoRejoin()
        if not arjOn then return false end
        arjOn = false
        if arjConn then arjConn:Disconnect(); arjConn = nil end
        return true
    end

    -- God Mode
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

    -- Visual Item
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

    -- Search Items & GrowScan
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
        local result = { fg = {}, bg = {}, drops = {}, w = w.w, h = w.h, totalFg = 0, totalBg = 0, totalDrops = 0, piles = 0 }
        for y = 0, w.h - 1 do
            local rFg, rBg = w.fg[y], w.bg and w.bg[y]
            for x = 0, w.w - 1 do
                local f = rFg and rFg[x] or 0
                if f ~= 0 then result.fg[f] = (result.fg[f] or 0) + 1; result.totalFg += 1 end
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

    -- Auto Quest (Klaim + Kerjakan Quest)
    function QuestReport()
        Bonus.CheckQuests()
        Notify(Bonus.questText, "Info Quest")
    end

    function StartQuest()
        if questOn then return true end
        questOn = true
        Config.bonusAutoQuest = true
        Bonus.nextQuest = 0
        questStatus = "Auto Claim Aktif"
        return true
    end

    function StopQuest()
        if not questOn then return false end
        questOn = false
        Config.bonusAutoQuest = false
        questStatus = "Mati"
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
    autorejoin = { label = "Auto Rejoin", get = function() return arjOn end, set = function(on) return on and StartAutoRejoin() or StopAutoRejoin() end },
    god = { label = "God Mode", get = function() return godOn end, set = function(on) return on and StartGod() or StopGod() end },
    clicktp = { label = "Click TP", get = function() return Nav.clickOn end, set = function(on) return on and Nav.StartClick() or Nav.StopClick() end },
    lite = { label = "Mode Lite", get = function() return Config.liteMode end, set = function(on) LiteMode.Set(on); return true end },
    guard = { label = "Penjaga Anti-Mod", get = function() return Guard.on end, set = function(on) Guard.Set(on); return true end },
    autochat = { label = "Auto Chat", noSession = true, get = function() return Spam.on end, set = function(on) Spam.on = on; if on then Spam.nextAt = 0 end; return true end },
    autoclear = { label = "Auto Clear World", noSession = true, get = function() return Clear.on end, set = function(on) return on and Clear.Start() or Clear.Stop() end },
    autoharvest = { label = "Farmer (Harvest/Plant)", noSession = true, get = function() return Farmer.on end, set = function(on) return on and Farmer.Start() or Farmer.Stop() end },
    autodf = { label = "Auto Dirt Farm", noSession = true, get = function() return DF.on end, set = function(on) return on and DF.Start() or DF.Stop() end },
    autofarm = { label = "Auto Farm", noSession = true, get = function() return Farm.on end, set = function(on) return on and StartFarm() or StopFarm() end },
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

local function ReloadReady()
    return GetQueueFn() ~= nil and ReloadSource() ~= nil
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
-- GUI TAMBAHAN: FLOATING GRID 5X5 & FLYPAD (▲ / ▼) DARI SKYP
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

    -- 1) Floating Grid 5x5
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
    Title.Size = UDim2.new(1, -40, 0, 28)
    Title.Position = UDim2.fromOffset(10, 4)
    Title.BackgroundTransparency = 1
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 13
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.TextColor3 = Color3.fromRGB(235, 235, 245)
    Title.Text = "ANCH Grid 5x5"
    Title.Active = true

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

    local GridStart = Instance.new("TextButton", Panel)
    GridStart.Size = UDim2.new(1, -20, 0, 30)
    GridStart.Position = UDim2.new(0, 10, 1, -54)
    GridStart.BackgroundColor3 = COLOR_ON
    GridStart.Font = Enum.Font.GothamBold
    GridStart.TextSize = 14
    GridStart.TextColor3 = Color3.new(1, 1, 1)
    GridStart.Text = "START FARM"
    Instance.new("UICorner", GridStart).CornerRadius = UDim.new(0, 8)
    GridStart.MouseButton1Click:Connect(function()
        SetFeature("autofarm", not Farm.on)
    end)

    UpdateGridVisuals = function()
        for key, btn in pairs(CellButtons) do
            btn.BackgroundColor3 = Config.farmGrid[key] and COLOR_ON or COLOR_OFF
        end
        GridStart.Text = Farm.on and "STOP FARM" or "START FARM"
        GridStart.BackgroundColor3 = Farm.on and Color3.fromRGB(200, 60, 60) or COLOR_ON
    end

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
                btn.BackgroundColor3 = Config.farmGrid[key] and COLOR_ON or COLOR_OFF
                CellButtons[key] = btn
                btn.MouseButton1Click:Connect(function()
                    Config.farmGrid[key] = (not Config.farmGrid[key]) or nil
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
        Config.farmGrid = {}
        SaveConfig()
        UpdateGridVisuals()
    end)

    -- Draggable Grid Panel
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

    -- 2) FlyPad (▲ / ▼)
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
-- GUI UTAMA (WINDUI)
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
local Green = Color3.fromHex("#10C550")
local Grey = Color3.fromHex("#83889E")
local Blue = Color3.fromHex("#257AF7")
local Red = Color3.fromHex("#EF4F1D")

local Window = WindUI:CreateWindow({
    Title = "ANCH Hub  |  GrowBlox Ultimate",
    Folder = "ANCHHub_GrowBlox",
    Icon = "solar:folder-2-bold-duotone",
    NewElements = true,
    HideSearchBar = false,
    OpenButton = {
        Title = "Open ANCH Hub",
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

do
    Window:Tag({
        Title = "v10 Ultimate",
        Icon = "github",
        Color = Color3.fromHex("#1c1c1c"),
        Border = true,
    })
end

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
    local toggle = tab:Toggle({
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
    return toggle
end

local MainSection = Window:Section({ Title = "Utama" })
local AutoSection = Window:Section({ Title = "Farming & Bot" })
local SecuritySection = Window:Section({ Title = "Keamanan & Fitur" })
local WorldSection = Window:Section({ Title = "World & Visual" })
local SystemSection = Window:Section({ Title = "Sistem" })

-- 1. Tab: Fitur & Karakter -------------------------------------------
do (function()
    local Tab = MainSection:Tab({
        Title = "Fitur Utama",
        Icon = "solar:home-2-bold",
        IconColor = Green,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.features = Tab

    local statusPara = Tab:Paragraph({
        Title = "Status Karakter & Referensi",
        Desc = "Mendeteksi posisi...",
    })

    task.spawn(function()
        while alive() and task.wait(0.4) do
            pcall(function()
                local tx, ty = GetTile()
                local wName = CurrentWorldName()
                local refLine = string.format(
                    "World: %s | Inv: %s | State: %s | Punch: %s | Drop: %s",
                    Refs.World and "OK" or "-",
                    Refs.Inv and "OK" or "-",
                    Refs.State and "OK" or "-",
                    Refs.Punch and "OK" or "-",
                    Drops.list and "OK" or "-"
                )
                if tx then
                    SetElementText(
                        statusPara,
                        string.format("World: %s  |  Tile: (%d, %d)", wName ~= "" and wName or "-", tx, ty),
                        refLine
                    )
                else
                    SetElementText(statusPara, "Status Karakter: Di luar world", refLine)
                end
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

    Tab:Space()
    Tab:Section({ Title = "Kontrol Bot & Karakter" })

    AddFeatureToggle(Tab, "Auto Farm (Grid 5x5 + Rayman)", "Place & break otomatis di sekitar karakter.", "autofarm")
    AddFeatureToggle(Tab, "Auto Clear World (Legit A* + Pillar)", "Bersihkan seluruh blok world dari ujung.", "autoclear")
    AddFeatureToggle(Tab, "Farmer (Auto Harvest + Auto Plant)", "Panen pohon siap & tanam seed otomatis.", "autoharvest")
    AddFeatureToggle(Tab, "Auto Dirt Farm (Half DF)", "Buat Dirt Farm otomatis dengan Pillar Climb.", "autodf")
    AddFeatureToggle(Tab, "Penjaga (Anti-Mod / Staff Detector)", "Otomatis jeda / keluar world saat Mod atau pemain masuk.", "guard")
    AddFeatureToggle(Tab, "Click TP (Legit Pathfinding)", "Klik di layar untuk berjalan & memanjat otomatis ke tujuan.", "clicktp")
    AddFeatureToggle(Tab, "Noclip + FlyPad (▲/▼)", "Terbang menembus blok dan munculkan tombol naik/turun di layar.", "noclip")
    AddFeatureToggle(Tab, "Unlimited Jump (Jammer)", "Lompat di udara tanpa batas (Antigravity).", "ujump")
    AddFeatureToggle(Tab, "God Mode", "Kebal lava, spike, api, dan hazard tile.", "god")
    AddFeatureToggle(Tab, "Mode Lite (FPS Boost)", "Matikan partikel & efek suara pukulan agar hemat baterai & FPS tinggi.", "lite")
    AddFeatureToggle(Tab, "Blink Skin", "Warna karakter berganti otomatis.", "blink")
    AddFeatureToggle(Tab, "Anti-AFK", "Mencegah disconnect karena diam terlalu lama.", "antiafk")
    AddFeatureToggle(Tab, "Auto Rejoin", "Otomatis masuk kembali jika terputus dari server.", "autorejoin")

    Tab:Space()
    Tab:Section({ Title = "Kecepatan & Aksi Cepat" })

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

    local dropAmountText = "100"
    local dropInput = Tab:Input({
        Title = "Jumlah Drop World Lock",
        Value = "100",
        Placeholder = "Jumlah (1-10000)",
        Callback = function(text) dropAmountText = text end,
    })

    local quickGroup = Tab:Group({})
    for idx, val in ipairs({ 1, 10, 50, 100 }) do
        quickGroup:Button({
            Title = tostring(val) .. " WL",
            Justify = "Center",
            Callback = function()
                dropAmountText = tostring(val)
                pcall(function() if dropInput and dropInput.Set then dropInput:Set(tostring(val)) end end)
            end,
        })
        if idx < 4 then quickGroup:Space() end
    end

    Tab:Space()
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

    Tab:Space()
    Tab:Button({ Title = "Rejoin World", Justify = "Center", Callback = Rejoin })
end)() end

-- 2. Tab: Auto Farm --------------------------------------------------
do (function()
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
        Title = "Buka Floating Grid 5x5 (Bisa Digeser)",
        Color = Color3.fromHex("#305dff"),
        Justify = "Center",
        Callback = function()
            if GridGui then GridGui.Enabled = not GridGui.Enabled end
        end,
    })

    Tab:Space()
    Tab:Section({ Title = "Mode & Kecepatan Farm" })

    Tab:Dropdown({
        Title = "Mode Auto Farm",
        Values = { "Place + Break", "Break saja", "Place saja" },
        Value = Config.farmMode,
        Callback = function(v)
            Config.farmMode = v or "Place + Break"
            SaveConfig()
        end,
    })

    Tab:Slider({
        Title = "Multi-Target Break (1 - 5 Tile)",
        Desc = "Memukul beberapa tile bergantian. Otomatis pakai efek Rayman jika memakai Rayman's Fist!",
        IsTooltip = true,
        Step = 1,
        Value = { Min = 1, Max = 5, Default = math.clamp(Config.farmMultiTarget, 1, 5) },
        Callback = function(v)
            Config.farmMultiTarget = math.clamp(math.floor(tonumber(v) or 1), 1, 5)
            SaveConfig()
        end,
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
end)() end

-- 3. Tab: Auto Clear World -------------------------------------------
do (function()
    local Tab = AutoSection:Tab({
        Title = "Auto Clear",
        Icon = "solar:cursor-square-bold",
        IconColor = Red,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.clear = Tab

    local clearPara = Tab:Paragraph({ Title = "Status Auto Clear", Desc = "Memuat..." })

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

    AddFeatureToggle(Tab, "Auto Clear World (Legit A* + Pillar)", "Bersihkan world dengan Legit Walking & otomatis memanjat pakai pijakan jika Y di atas player.", "autoclear")

    Tab:Dropdown({
        Title = "Arah Sapuan (Sweep)",
        Values = { "Zig-zag", "Kiri → Kanan" },
        Value = Config.clearSweep,
        Callback = function(v) Config.clearSweep = v or "Zig-zag"; SaveConfig() end,
    })

    Tab:Toggle({
        Title = "Gunakan Block Pijakan (Pillar & Jembatan)",
        Desc = "Otomatis menaruh block saat melewati jurang atau memanjat ke Y yang lebih tinggi.",
        Value = Config.clearUseBlock,
        Callback = function(on) Config.clearUseBlock = on; SaveConfig() end,
    })

    Tab:Toggle({
        Title = "Ikut Hancurkan Background",
        Value = Config.clearIncludeBg,
        Callback = function(on) Config.clearIncludeBg = on; SaveConfig() end,
    })

    Tab:Toggle({
        Title = "Aktifkan ModFly Saat Memukul",
        Desc = "Menjaga karakter tidak jatuh saat menghancurkan pijakan (otomatis mati saat Pillar Jump).",
        Value = Config.clearModFly,
        Callback = function(on)
            Config.clearModFly = on
            SaveConfig()
            if Clear.on then SetAutoFly("autoclear", on) end
        end,
    })

    Tab:Toggle({
        Title = "Auto Collect Drop",
        Value = Config.clearTake,
        Callback = function(on) Config.clearTake = on; SaveConfig() end,
    })
end)() end

-- 4. Tab: Farmer (Auto Harvest + Auto Plant) -------------------------
do (function()
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

    AddFeatureToggle(Tab, "Jalankan Farmer", "Otomatis panen pohon siap & tanam seed dengan Legit Walking + Pillar Climb.", "autoharvest")

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
end)() end

-- 5. Tab: Auto DF (Dirt Farm) ----------------------------------------
do (function()
    local Tab = AutoSection:Tab({
        Title = "Auto DF",
        Icon = "solar:hamburger-menu-bold",
        IconColor = Yellow,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.df = Tab

    local dfPara = Tab:Paragraph({ Title = "Status Auto Dirt Farm", Desc = "Memuat..." })

    task.spawn(function()
        while alive() and task.wait(0.4) do
            pcall(function()
                local st = DF.stats
                SetElementText(
                    dfPara,
                    "Status: " .. DF.status .. " (" .. tostring(st.step) .. ")",
                    string.format(
                        "Lapisan Dirt Atas: Y=%d | Batas Bedrock: Y=%d\nBlock Dihancurkan: %d | Dirt Dipasang: %d | Drop Diambil: %d",
                        st.topDirtY, st.bedrockY, st.broken, st.placed, st.picked
                    )
                )
            end)
        end
    end)

    AddFeatureToggle(Tab, "Jalankan Auto Dirt Farm (Half DF)", "Bersihkan 2 kolom vertikal ujung, panjat dengan Pillar Climb, dan buat baris platform Dirt.", "autodf")

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
end)() end

-- 6. Tab: Navigasi & Click TP ----------------------------------------
do (function()
    local Tab = AutoSection:Tab({
        Title = "Navigasi & Click TP",
        Icon = "solar:square-transfer-horizontal-bold",
        IconColor = Blue,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.nav = Tab

    local navPara = Tab:Paragraph({ Title = "Status Navigasi Universal", Desc = "Terakhir: -" })

    task.spawn(function()
        while alive() and task.wait(0.4) do
            pcall(function()
                SetElementText(navPara, "Mode Gerak: " .. Config.moveMode:upper(), "Status Terakhir: " .. tostring(Nav.last) .. " | Pijakan Dipasang: " .. Nav.PlacedScaffolds)
            end)
        end
    end)

    AddFeatureToggle(Tab, "Aktifkan Click TP", "Klik di mana saja untuk berjalan / memanjat otomatis ke titik tersebut.", "clicktp")

    Tab:Dropdown({
        Title = "Mode Pergerakan Universal",
        Desc = "legit = Legit Walking A* + Pillar Climb otomatis saat Y di atas player.",
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

    Tab:Input({
        Title = "Jeda Langkah / Settle (detik)",
        Desc = "Rekomendasi optimal: 0.28 - 0.35 detik.",
        Value = tostring(Config.moveStepDelay),
        Callback = function(text)
            local v = tonumber(text)
            if v and v >= 0.05 and v <= 2 then Config.moveStepDelay = v; SaveConfig() end
        end,
    })
end)() end

-- 7. Tab: Penjaga (Anti-Mod / Staff Detector) ------------------------
do (function()
    local Tab = SecuritySection:Tab({
        Title = "Penjaga (Anti-Mod)",
        Icon = "solar:info-square-bold",
        IconColor = Red,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.guard = Tab

    local guardPara = Tab:Paragraph({ Title = "Status Penjaga", Desc = "Mati" })

    task.spawn(function()
        while alive() and task.wait(0.5) do
            pcall(function()
                SetElementText(
                    guardPara,
                    "Status Penjaga: " .. Guard.status,
                    string.format(
                        "Pemain di World: %s\nStaff Online di Server: %s\nTotal Terdeteksi: %d kali",
                        Guard.hereText, Guard.staffServerText, Guard.detected
                    )
                )
            end)
        end
    end)

    AddFeatureToggle(Tab, "Aktifkan Penjaga", "Pantau Moderator / Developer (termasuk undercover) atau pemain yang masuk ke world.", "guard")

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
        Desc = "Masuk kembali & berjalan balik ke titik farm setelah situasi aman.",
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
end)() end

-- 8. Tab: Auto Chat & Bonus (Quest/Redeem/Staff) ---------------------
do (function()
    local Tab = SecuritySection:Tab({
        Title = "Chat, Bonus & Staff",
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
                    string.format("Pesan Terakhir: %s\nQuest: %s\nRedeem: %s", Spam.last, Bonus.questText, Bonus.codeText)
                )
            end)
        end
    end)

    Tab:Section({ Title = "Auto Chat / Spammer" })

    AddFeatureToggle(Tab, "Aktifkan Auto Chat", "Kirim daftar pesan secara bergantian ke channel world.", "autochat")

    Tab:Input({
        Title = "Daftar Pesan (Pisahkan dengan |)",
        Value = Config.chatTexts,
        Placeholder = "pesan 1|pesan 2|pesan 3",
        Callback = function(text)
            Config.chatTexts = text or ""
            Spam.texts = Spam.parse(Config.chatTexts)
            Spam.index = 1
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

    Tab:Space()
    Tab:Section({ Title = "Staff Tools" })

    Tab:Button({
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
end)() end

-- 9. Tab: GrowScan, Posisi & Visual ----------------------------------
do (function()
    local ScanTab = WorldSection:Tab({
        Title = "GrowScan",
        Icon = "solar:info-square-bold",
        IconColor = Green,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.scan = ScanTab

    local scanInfoPara = ScanTab:Paragraph({ Title = "GrowScan 9000", Desc = "Tekan Scan Sekarang" })

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
            for i = 1, math.min(maxLines or 15, #arr) do
                table.insert(out, string.format("• %s [%d] x%d", ItemName(arr[i].id), arr[i].id, arr[i].n))
            end
            return #out > 0 and table.concat(out, "\n") or "Kosong"
        end
        local desc = table.concat({
            string.format("World: %s (%dx%d)", CurrentWorldName(), data.w, data.h),
            string.format("Foreground: %d | Background: %d | Floating: %d (%d tumpukan)", data.totalFg, data.totalBg, data.totalDrops, data.piles),
            "\n[FLOATING DROPS]:\n" .. topItems(data.drops, 12),
            "\n[WORLD BLOCKS]:\n" .. topItems(data.fg, 15),
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

    -- Tab Posisi
    local PosTab = WorldSection:Tab({
        Title = "Posisi (Pos 1/2)",
        Icon = "solar:hamburger-menu-bold",
        IconColor = Yellow,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.pos = PosTab

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
        grp:Space()
        grp:Button({ Title = "Teleport (win" .. slot .. ")", Justify = "Center", Callback = function() task.spawn(GoToPos, slot) end })
    end

    -- Tab Visual
    local VisTab = WorldSection:Tab({
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
        Value = Config.watermarkText,
        Placeholder = "ANCH HUB",
        Callback = function(text)
            if Trim(text) ~= "" then
                Config.watermarkText = Trim(text)
                SaveConfig()
            end
        end,
    })

    VisTab:Space()
    VisTab:Section({ Title = "Visual Item Lokal" })

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

    task.defer(rebuildWear)
end)() end

-- 10. Tab: Sesi, Setelan & Bantuan -----------------------------------
do (function()
    local SesiTab = SystemSection:Tab({
        Title = "Sesi & Setelan",
        Icon = "solar:folder-with-files-bold",
        IconColor = Blue,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.session = SesiTab
    hub.tabs.settings = SesiTab

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
        Title = "Prefix Command Chat",
        Value = Config.prefix,
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

    local HelpTab = SystemSection:Tab({
        Title = "Bantuan",
        Icon = "solar:info-square-bold",
        IconColor = Purple,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.help = HelpTab

    HelpTab:Paragraph({
        Title = "Daftar Perintah Chat ANCH Hub Ultimate",
        Desc = table.concat({
            "/af [on/off]  —  Auto Farm (Multi-Target + Rayman)",
            "/ac [on/off]  —  Auto Clear World (Legit Walk + Pillar Climb)",
            "/ah [on/off]  —  Farmer (Auto Harvest + Auto Plant)",
            "/adf [on/off] —  Auto Dirt Farm (Half DF Builder)",
            "/guard [on/off] — Penjaga Anti-Mod / Staff Detector",
            "/chat [on/off]  — Auto Chat / Spammer",
            "/ctp [on/off] —  Click TP (Legit A* / Pillar)",
            "/move <legit|walk|fly|mix> — Ubah mode gerak",
            "/noclip | /uj | /god | /lite | /blink | /lh",
            "/wld <jumlah> | /tp <world> | /pos1 | /pos2 | /win1 | /win2",
        }, "\n"),
    })
end)() end

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
        SetFeature("autorejoin", WantedState(args, arjOn)); return true
    elseif command == "blink" then
        SetFeature("blink", WantedState(args, blinkOn)); return true
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
    Notify("ANCH HUB v10 Ultimate Loaded! Mode gerak: LEGIT (A* + Pillar Climb).")
end)
