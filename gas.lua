--[[
    ANCH HUB | GrowBlox  (v9 - Pathfinding, tanpa Key System - WindUI Edition)
    Prefix default "/" (bisa diganti / dikosongkan di /settingsgb)

      wld|wd <jumlah>        Drop World Lock
      tp|warp <world>        Pindah world
      pos1 | pos2            Simpan posisi sekarang
      win1|w1 [jumlah]       Teleport ke Pos 1 (opsional langsung drop WL)
      win2|w2 [jumlah]       Teleport ke Pos 2
      pos                    Lihat posisi sekarang & pos tersimpan
      rejoin|rj              Masuk ulang ke world ini
      noclip [on|off]        Tembus blok + terbang (mode ghost game)
      unlimitedjump|uj       Lompat di udara tanpa batas
      blink [on|off]         Warna skin berganti otomatis
      longhand|lh [n|off]    Jangkauan punch/build lebih jauh
      visualitem|vi          GUI item visual (lokal)
      settingsgb|sgb         GUI pengaturan
      afk                    Anti-AFK (tidak kena kick idle)
      autorejoin|arj         Rejoin otomatis kalau terputus
      session|sesi           GUI sesi (simpan & pulihkan otomatis)
      af|autofarm [on|off]   GUI Auto Farm (kecepatan pukulan, ID block, grid 5x5)
      ac|autoclear [on|off]  Auto Clear World (Legit 1-by-1 dari ujung, ModFly anti-jatuh, skip >5s)
      ah|autoharvest [on|off] Auto Harvest (Scan pohon siap panen, gerak aman, pukul sampai habis)
      ctp|clicktp [on|off]   Click TP: klik mana saja, jalan lewat path (tampil seperti teleport)
      move|mv <walk|fly|mix> Mode gerak: jalan / terbang / campur
      aq|autoquest [on|off|scan]  Auto quest (claim + kerjakan quest break/place)
      gs|growscan            Buka GrowScan
      god [on|off]           God mode (kebal lava, spike, api)
      blockid|bid <nama>     Cari ID block dari nama
      hpx                    Daftar fitur

    SESI: fitur aktif, Pos 1/2 & world terakhir disimpan ke file dan dipulihkan
    otomatis setelah ganti world / rejoin / buka Roblox lagi.
    Simpan skrip ini di folder workspace executor dengan nama
    "ANCHHub_GrowBlox.lua" (atau isi URL di tab Sesi) supaya auto-reload jalan.
]]

-- Cegah dobel-eksekusi
local genv = (getgenv and getgenv()) or _G
if genv.ANCHHubGB_Loaded then
    if type(genv.ANCHHubGB_Loaded) ~= "number" or os.clock() - genv.ANCHHubGB_Loaded > 15 then
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "ANCH HUB | GrowBlox",
                Text = "Sudah aktif. Ketik /hpx atau tekan tombol Open ANCH Hub.",
                Duration = 4,
            })
        end)
    end
    return
end
genv.ANCHHubGB_Loaded = os.clock()

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

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local DropEvent = ReplicatedStorage
    :WaitForChild("WorldRemotes")
    :WaitForChild("DropItem")

----------------------------------------------------------------------
-- CONFIG (disimpan ke file kalau executor mendukung writefile)
----------------------------------------------------------------------
local CONFIG_FILE = "ANCHHub_GrowBlox.json"

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
    -- Auto Farm
    farmDelay = 0.22,
    farmPlaceId = 0,
    farmGrid = { ["1,0"] = true },
    farmTake = true,
    -- Auto Clear World
    clearBreakDelay = 0.15,
    clearTpDelay = 0.18,
    clearTake = true,
    clearModFly = true,
    -- Auto Harvest
    harvestDelay = 0.20,
    harvestTpDelay = 0.18,
    harvestTake = true,
    harvestModFly = true,
    -- Pathfinding / Click TP
    navPath = true,
    moveMode = "mix",
    navSpeed = 1,          -- tile per step
    moveStepDelay = 0.07,  -- jeda detik per 1 tile langkah (mencegah rollback server)
    clickTpShift = false,
}

local SCRIPT_FILE = "ANCHHub_GrowBlox.lua"
local QueueReload

local MAX_AMOUNT = 10000
local COOLDOWN = 0.3

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
-- UTIL
----------------------------------------------------------------------
local ToastHook = nil

local function Notify(message)
    if ToastHook then
        local ok = pcall(ToastHook, tostring(message))
        if ok then
            return
        end
    end
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "ANCH HUB | GrowBlox",
            Text = tostring(message),
            Duration = 4,
        })
    end)
end

local function Trim(text)
    return (tostring(text):gsub("^%s+", ""):gsub("%s+$", ""))
end

local getgcFn = getgc or (debug and debug.getgc)
local getupvalueFn = (debug and debug.getupvalue) or getupvalue
local setupvalueFn = (debug and debug.setupvalue) or setupvalue

local function GetUpvalues(fn)
    local list = {}
    for i = 1, 255 do
        local ok, value = pcall(getupvalueFn, fn, i)
        if not ok then
            break
        end
        list[i] = value
    end
    return list
end

----------------------------------------------------------------------
-- AKSES KE INTERNAL GAME (lewat getgc)
----------------------------------------------------------------------
local cache = {}

local function ScanGc(name, check)
    local cached = cache[name]
    if cached and check(cached) then
        return cached
    end
    if not getgcFn then
        return nil
    end
    for _, obj in ipairs(getgcFn(true)) do
        if type(obj) == "table" then
            local ok, valid = pcall(check, obj)
            if ok and valid then
                cache[name] = obj
                return obj
            end
        end
    end
    return nil
end

local function FindInventory()
    return ScanGc("inventory", function(t)
        return type(rawget(t, "onDrop")) == "function"
            and type(rawget(t, "canDrop")) == "function"
            and type(rawget(t, "isWorn")) == "function"
    end)
end

local function FindWorld()
    return ScanGc("world", function(t)
        return type(rawget(t, "enter")) == "function"
            and type(rawget(t, "dropOk")) == "function"
    end)
end

local function FindRigs()
    return ScanGc("rigs", function(t)
        local a, b = rawget(t, 1), rawget(t, -1)
        return type(a) == "table" and type(b) == "table"
            and typeof(rawget(a, "body")) == "Instance"
            and typeof(rawget(b, "head")) == "Instance"
    end)
end

local function GetWorn()
    local inv = FindInventory()
    if not inv then
        return nil
    end
    local worn = GetUpvalues(inv.isWorn)[1]
    if type(worn) == "table" then
        return worn
    end
    return nil
end

local ItemDB = nil
local function GetItemDB()
    if ItemDB then
        return ItemDB
    end
    local ok, result = pcall(function()
        local shared = ReplicatedStorage:WaitForChild("Shared", 5)
        return require(shared:WaitForChild("ItemDB", 5))
    end)
    if ok and type(result) == "table" then
        ItemDB = result
    end
    return ItemDB
end

----------------------------------------------------------------------
-- POSISI GRID
----------------------------------------------------------------------
local function GetGridState()
    local inv = FindInventory()
    if not inv then
        return nil, "Inventory game tidak ditemukan (executor perlu getgc & debug.getupvalue)"
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

    return x, y, (facing >= 0) and 1 or -1
end

local function GetTile()
    local x, y = GetGridState()
    if not x then
        return nil
    end
    return math.floor(x), math.floor(y - 0.475)
end

local function CurrentWorldName()
    local world = FindWorld()
    local name = world and rawget(world, "name")
    return type(name) == "string" and name or ""
end

----------------------------------------------------------------------
-- DROP WORLD LOCK
----------------------------------------------------------------------
local busy = false

local function DropWorldLock(amount)
    if busy then
        Notify("Tunggu sebentar bre!")
        return
    end

    local x, y, facing = GetGridState()
    if not x then
        Notify("Posisi tidak terdeteksi: " .. tostring(y))
        return
    end

    local inv = FindInventory()
    local okCan, canDrop = pcall(inv.canDrop)
    if okCan and canDrop == false then
        Notify("Tidak bisa drop di posisi ini!")
        return
    end

    local dropX = x + facing * (0.7 + math.random() * 0.1)
    local dropY = y - 0.45

    busy = true

    local success, err = pcall(function()
        DropEvent:FireServer(Config.dropId, amount, dropX, dropY)
    end)

    if success then
        Notify("Sukses Drop " .. amount .. " World Lock")
    else
        Notify("Request gagal!")
        warn(err)
    end

    task.wait(COOLDOWN)
    busy = false
end

----------------------------------------------------------------------
-- WARP ANTAR WORLD
----------------------------------------------------------------------
local function WarpToWorld(name)
    name = Trim(name):upper()
    if name == "" then
        Notify("Contoh: " .. Config.prefix .. "tp START")
        return
    end

    local world = FindWorld()
    if not world then
        Notify("Fungsi world game tidak ditemukan!")
        return
    end

    Notify("Menuju world " .. name .. "...")
    local ok, success, message, teleporting = pcall(world.enter, name)

    if not ok then
        Notify("Warp gagal!")
        warn(success)
    elseif success then
        Notify("Berhasil masuk world " .. name)
    elseif teleporting then
        Notify(tostring(message or ("Memasuki " .. name .. "...")))
    else
        Notify(tostring(message or "Tidak bisa masuk world itu."))
    end
end

----------------------------------------------------------------------
-- POS1 / POS2 + WIN1 / WIN2
----------------------------------------------------------------------
local function SetPos(slot)
    local tx, ty = GetTile()
    if not tx then
        Notify("Posisi tidak terdeteksi!")
        return
    end
    Config["pos" .. slot] = { world = CurrentWorldName(), x = tx, y = ty }
    SaveConfig()
    Notify(string.format("Pos %d disimpan: %d, %d", slot, tx, ty))
end

local function GoToPos(slot, amount)
    local pos = Config["pos" .. slot]
    if type(pos) ~= "table" or type(pos.x) ~= "number" or type(pos.y) ~= "number" then
        Notify("Pos " .. slot .. " belum diset! Ketik " .. Config.prefix .. "pos" .. slot)
        return
    end

    local world = FindWorld()
    if not world or type(world.goTo) ~= "function" then
        Notify("Fungsi teleport game tidak ditemukan!")
        return
    end

    local current = CurrentWorldName()
    if type(pos.world) == "string" and pos.world ~= "" and current ~= pos.world then
        Notify(string.format("Pos %d disimpan di world %s (kamu di %s)", slot, pos.world, current))
        return
    end

    local ok, err = pcall(world.goTo, pos.x, pos.y)
    if not ok then
        Notify("Teleport gagal!")
        warn(err)
        return
    end
    Notify(string.format("Pindah ke Pos %d (%d, %d)", slot, pos.x, pos.y))

    local dropAmount = amount
    if not dropAmount and Config.winDrop > 0 then
        dropAmount = Config.winDrop
    end
    if dropAmount then
        task.wait(0.4)
        DropWorldLock(dropAmount)
    end
end

local function ShowPos()
    local tx, ty = GetTile()
    local parts = {}
    table.insert(parts, tx and string.format("Sekarang: %d, %d (%s)", tx, ty, CurrentWorldName()) or "Posisi tidak terdeteksi")
    for slot = 1, 2 do
        local pos = Config["pos" .. slot]
        if type(pos) == "table" and type(pos.x) == "number" then
            table.insert(parts, string.format("Pos%d: %d, %d", slot, pos.x, pos.y))
        else
            table.insert(parts, "Pos" .. slot .. ": -")
        end
    end
    Notify(table.concat(parts, " | "))
end

----------------------------------------------------------------------
-- REJOIN
----------------------------------------------------------------------
local function Rejoin()
    local name = CurrentWorldName()
    if name == "" then
        name = Config.lastWorld
    end
    SaveConfig()
    if QueueReload then
        pcall(QueueReload)
    end
    local data = (name ~= "") and { world = name } or nil
    Notify(name ~= "" and ("Rejoin world " .. name .. "...") or "Rejoin...")
    local ok, err = pcall(function()
        TeleportService:Teleport(game.PlaceId, Player, data)
    end)
    if not ok then
        Notify("Rejoin gagal!")
        warn(err)
    end
end

----------------------------------------------------------------------
-- BLINK SKIN
----------------------------------------------------------------------
local blinkOn = false
local blinkOriginal = {}

local function CollectSkinParts()
    local list = {}
    local rigs = FindRigs()
    if not rigs then
        return list
    end

    for _, key in ipairs({ 1, -1, 0 }) do
        local rig = rawget(rigs, key)
        if type(rig) == "table" then
            for _, field in ipairs({ "body", "head", "eyelids", "blink", "forearm", "fist" }) do
                local part = rig[field]
                if typeof(part) == "Instance" then
                    table.insert(list, { part = part, face = false })
                end
            end
            for _, field in ipairs({ "armBack", "armFront" }) do
                local arm = rig[field]
                local sprite
                if typeof(arm) == "Instance" then
                    sprite = arm:FindFirstChild("Sprite")
                elseif type(arm) == "table" then
                    sprite = arm.Sprite
                end
                if typeof(sprite) == "Instance" then
                    table.insert(list, { part = sprite, face = false })
                end
            end
            if typeof(rig.face) == "Instance" then
                table.insert(list, { part = rig.face, face = true })
            end
        end
    end
    return list
end

local function StopBlink()
    if not blinkOn then
        return false
    end
    blinkOn = false
    for part, color in pairs(blinkOriginal) do
        pcall(function()
            part.ImageColor3 = color
        end)
    end
    table.clear(blinkOriginal)
    return true
end

local function StartBlink()
    if blinkOn then
        return true
    end
    if not FindRigs() then
        Notify("Rig karakter tidak ditemukan!")
        return false
    end

    blinkOn = true
    table.clear(blinkOriginal)
    for _, entry in ipairs(CollectSkinParts()) do
        blinkOriginal[entry.part] = entry.part.ImageColor3
    end

    task.spawn(function()
        while blinkOn do
            local color = Color3.fromHSV(math.random(), 0.55 + math.random() * 0.4, 1)
            local dark = Color3.new(color.R * 0.38, color.G * 0.35, color.B * 0.3)
            for _, entry in ipairs(CollectSkinParts()) do
                if blinkOriginal[entry.part] == nil then
                    blinkOriginal[entry.part] = entry.part.ImageColor3
                end
                pcall(function()
                    entry.part.ImageColor3 = entry.face and dark or color
                end)
            end
            local minT = math.min(Config.blinkMin, Config.blinkMax)
            local maxT = math.max(Config.blinkMin, Config.blinkMax)
            task.wait(minT + math.random() * (maxT - minT))
        end
    end)
    return true
end

----------------------------------------------------------------------
-- LONGHAND
----------------------------------------------------------------------
local longhandOn = false
local longhandOriginal = nil

local function ApplyLonghand()
    local inv = FindInventory()
    if not inv then
        Notify("Inventory game tidak ditemukan!")
        return false
    end

    if not longhandOriginal then
        longhandOriginal = { build = inv.buildRange, punch = inv.punchRange }
    end

    local target = 2.5 + Config.longhandRange
    inv.buildRange = function()
        return math.max(longhandOriginal.build(), target)
    end
    inv.punchRange = function()
        return math.max(longhandOriginal.punch(), target)
    end
    longhandOn = true
    return true
end

local function StopLonghand()
    if not longhandOn then
        return false
    end
    local inv = FindInventory()
    if inv and longhandOriginal then
        inv.buildRange = longhandOriginal.build
        inv.punchRange = longhandOriginal.punch
    end
    longhandOn = false
    return true
end

----------------------------------------------------------------------
-- NOCLIP / MODFLY
----------------------------------------------------------------------
local noclipOn = false
local noclipConn = nil
local autoFlyLocks = {} -- dikelola bersama oleh Auto Clear / Auto Harvest

local function IsAnyFlyActive()
    if noclipOn then
        return true
    end
    for _, active in pairs(autoFlyLocks) do
        if active then
            return true
        end
    end
    return false
end

local function SyncGhostState()
    local world = FindWorld()
    if not world then
        return
    end
    if IsAnyFlyActive() then
        world.ghost = true
        if not noclipConn then
            noclipConn = RunService.Heartbeat:Connect(function()
                if IsAnyFlyActive() then
                    local w = FindWorld()
                    if w and w.ghost ~= true then
                        w.ghost = true
                    end
                end
            end)
        end
    else
        if noclipConn then
            noclipConn:Disconnect()
            noclipConn = nil
        end
        world.ghost = (Player:GetAttribute("Ghost") == true)
    end
end

local function SetAutoFly(sourceKey, enabled)
    autoFlyLocks[sourceKey] = enabled and true or nil
    SyncGhostState()
end

local function StopNoclip()
    if not noclipOn then
        return false
    end
    noclipOn = false
    SyncGhostState()
    return true
end

local function StartNoclip()
    if noclipOn then
        return true
    end
    local world = FindWorld()
    if not world then
        Notify("World game tidak ditemukan!")
        return false
    end
    noclipOn = true
    SyncGhostState()
    return true
end

----------------------------------------------------------------------
-- UNLIMITED JUMP
----------------------------------------------------------------------
local ujumpOn = false
local ujumpConn = nil
local ujumpFn = nil
local ujumpWingsOriginal = nil
local JUMP_FLAG_INDEX = 27
local WINGS_INDEX = 29

local function FindRenderFn()
    if ujumpFn then
        return ujumpFn
    end
    if not getconnections then
        return nil
    end
    local world, inv = FindWorld(), FindInventory()
    if not world or not inv then
        return nil
    end
    local ok, conns = pcall(getconnections, RunService.RenderStepped)
    if not ok then
        return nil
    end
    for _, conn in ipairs(conns) do
        local okFn, fn = pcall(function()
            return conn.Function
        end)
        if okFn and type(fn) == "function" then
            local ups = GetUpvalues(fn)
            if ups[1] == world and ups[2] == inv then
                ujumpFn = fn
                return fn
            end
        end
    end
    return nil
end

local function FindFallbackWing()
    local db = GetItemDB()
    if not db then
        return nil
    end
    local best, bestPlain = nil, nil
    for id, item in pairs(db) do
        if type(id) == "number" and type(item) == "table" and item.doubleJump == true then
            if not item.wingSheet and (not bestPlain or id < bestPlain) then
                bestPlain = id
            end
            if not best or id < best then
                best = id
            end
        end
    end
    return bestPlain or best
end

local function StopUjump()
    if not ujumpOn then
        return false
    end
    ujumpOn = false
    if ujumpConn then
        ujumpConn:Disconnect()
        ujumpConn = nil
    end
    if ujumpFn and ujumpWingsOriginal and setupvalueFn then
        pcall(setupvalueFn, ujumpFn, WINGS_INDEX, ujumpWingsOriginal)
    end
    ujumpWingsOriginal = nil
    return true
end

local function StartUjump()
    if ujumpOn then
        return true
    end
    if not setupvalueFn then
        Notify("Executor perlu debug.setupvalue!")
        return false
    end
    local fn = FindRenderFn()
    if not fn then
        Notify("Fungsi gerak game tidak ditemukan (perlu getconnections)")
        return false
    end

    local ups = GetUpvalues(fn)
    if type(ups[JUMP_FLAG_INDEX]) ~= "boolean" or type(ups[WINGS_INDEX]) ~= "function" then
        Notify("Struktur game berubah, unlimited jump tidak bisa dipasang.")
        return false
    end

    local original = ups[WINGS_INDEX]
    local fallback = FindFallbackWing()
    if fallback then
        ujumpWingsOriginal = original
        pcall(setupvalueFn, fn, WINGS_INDEX, function()
            return original() or fallback
        end)
    end

    ujumpOn = true
    ujumpConn = RunService.Heartbeat:Connect(function()
        pcall(setupvalueFn, fn, JUMP_FLAG_INDEX, false)
    end)
    return true
end

----------------------------------------------------------------------
-- VISUAL ITEM
----------------------------------------------------------------------
local visualBackup = {}

local function IsVisualWorn(id)
    local worn = GetWorn()
    local db = GetItemDB()
    if not worn or not db or not db[id] then
        return false
    end
    return worn[db[id].slot] == id
end

local function ToggleVisual(id)
    local inv, worn, db = FindInventory(), GetWorn(), GetItemDB()
    if not inv or not worn or not db or not db[id] then
        Notify("Item/inventory game tidak ditemukan!")
        return false
    end

    local slot = db[id].slot
    if type(slot) ~= "string" then
        return false
    end

    if worn[slot] == id then
        worn[slot] = visualBackup[slot] or nil
    else
        if visualBackup[slot] == nil then
            visualBackup[slot] = worn[slot] or false
        end
        worn[slot] = id
    end

    pcall(inv.refresh)
    return true
end

local function ResetVisuals()
    local inv, worn = FindInventory(), GetWorn()
    if not inv or not worn then
        return
    end
    for slot, original in pairs(visualBackup) do
        worn[slot] = original or nil
    end
    table.clear(visualBackup)
    pcall(inv.refresh)
    Notify("Item visual dikembalikan.")
end

local wearableCache = nil
local function GetWearables()
    if wearableCache then
        return wearableCache
    end
    local db = GetItemDB()
    if not db then
        return nil
    end

    local list = {}
    for id, item in pairs(db) do
        if type(id) == "number" and type(item) == "table"
            and type(item.slot) == "string" and type(item.name) == "string" then
            local tags = {}
            local lower = item.name:lower()
            if item.kuyang then
                table.insert(tags, "Kuyang")
            end
            if item.bot then
                table.insert(tags, "LegendBot")
            end
            if id == 5480 or lower:find("rayman", 1, true) then
                table.insert(tags, "Rayman")
            end
            table.insert(list, { id = id, name = item.name, lower = lower, slot = item.slot, tags = tags })
        end
    end
    table.sort(list, function(a, b)
        if a.name == b.name then
            return a.id < b.id
        end
        return a.name < b.name
    end)
    wearableCache = list
    return list
end

----------------------------------------------------------------------
-- FEATURE SETTERS
----------------------------------------------------------------------
local antiAfkOn = false
local antiAfkConn = nil

local function StopAntiAfk()
    if not antiAfkOn then
        return false
    end
    antiAfkOn = false
    if antiAfkConn then
        antiAfkConn:Disconnect()
        antiAfkConn = nil
    end
    return true
end

local function StartAntiAfk()
    if antiAfkOn then
        return true
    end
    local okVU, VirtualUser = pcall(function()
        return game:GetService("VirtualUser")
    end)
    if not okVU or not VirtualUser then
        Notify("VirtualUser tidak tersedia di executor ini.")
        return false
    end
    antiAfkOn = true
    antiAfkConn = Player.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)
    return true
end

local arjOn = false
local arjConn = nil

local function StopAutoRejoin()
    if not arjOn then
        return false
    end
    arjOn = false
    if arjConn then
        arjConn:Disconnect()
        arjConn = nil
    end
    return true
end

local function StartAutoRejoin()
    if arjOn then
        return true
    end
    local ok, overlay = pcall(function()
        local gui = game:GetService("CoreGui"):WaitForChild("RobloxPromptGui", 5)
        return gui and gui:WaitForChild("promptOverlay", 5)
    end)
    if not ok or not overlay then
        Notify("Auto rejoin tidak didukung executor ini.")
        return false
    end
    arjOn = true
    arjConn = overlay.ChildAdded:Connect(function(child)
        if child.Name == "ErrorPrompt" and arjOn then
            Notify("Terputus! Rejoin dalam 3 detik...")
            task.wait(3)
            Rejoin()
        end
    end)
    return true
end

local RefreshHub

local SearchItems, ItemName, StartFarm, StopFarm, StartQuest, StopQuest, QuestReport, StartGod, StopGod, OpenNativeGrowScan, ScanWorld
local farmOn, questOn, godOn = false, false, false
local Nav = { clickOn = false, token = 0, conn = nil, last = "-" }
local Clear = { on = false, token = 0, status = "Mati", stats = { scanned = 0, broken = 0, picked = 0, skipped = 0, left = 0, pass = 0 } }
local Harvest = { on = false, token = 0, status = "Mati", stats = { totalTrees = 0, ready = 0, harvested = 0, skipped = 0, picked = 0 } }
local questStatus = "Mati"
local farmStats = { status = "Mati", placed = 0, broken = 0, picked = 0, cycles = 0 }
do
----------------------------------------------------------------------
-- DATABASE ITEM + PENCARIAN
----------------------------------------------------------------------
local blockListCache = nil

local function GetBlockList()
    if blockListCache then
        return blockListCache
    end
    local db = GetItemDB()
    if not db then
        return nil
    end
    local list = {}
    for id, item in pairs(db) do
        if type(id) == "number" and type(item) == "table" and type(item.name) == "string"
            and type(item.slot) ~= "string" then
            table.insert(list, {
                id = id,
                name = item.name,
                lower = item.name:lower(),
                kind = type(item.kind) == "string" and item.kind or "block",
            })
        end
    end
    table.sort(list, function(a, b)
        if a.name == b.name then
            return a.id < b.id
        end
        return a.name < b.name
    end)
    blockListCache = list
    return list
end

function ItemName(id)
    local db = GetItemDB()
    local item = db and db[id]
    if type(item) == "table" and type(item.name) == "string" then
        return item.name
    end
    return "?"
end

function SearchItems(query, limit)
    local list = GetBlockList()
    local results = {}
    query = Trim(query):lower()
    if not list or query == "" then
        return {}
    end
    local wantId = tonumber(query)
    for _, entry in ipairs(list) do
        local rank = nil
        if wantId and entry.id == wantId then
            rank = 0
        elseif entry.lower == query then
            rank = 1
        elseif entry.lower:sub(1, #query) == query then
            rank = 2
        elseif entry.lower:find(query, 1, true) then
            rank = 3
        end
        if rank then
            table.insert(results, { entry = entry, rank = rank })
        end
    end
    table.sort(results, function(a, b)
        if a.rank ~= b.rank then
            return a.rank < b.rank
        end
        if a.entry.name ~= b.entry.name then
            return a.entry.name < b.entry.name
        end
        return a.entry.id < b.entry.id
    end)
    local out = {}
    for i = 1, math.min(limit or 25, #results) do
        out[i] = results[i].entry
    end
    return out
end

----------------------------------------------------------------------
-- AKSES FUNGSI GAME: hit, setTile, backpack
----------------------------------------------------------------------
local gameFns = {}

local function FindGameFn(name)
    local cached = gameFns[name]
    if cached then
        return cached
    end
    local world = FindWorld()
    if not world or not getgcFn or not (debug and debug.info) then
        return nil
    end
    for _, fn in ipairs(getgcFn(true)) do
        if type(fn) == "function" then
            local okName, fnName = pcall(debug.info, fn, "n")
            if okName and fnName == name then
                for _, value in pairs(GetUpvalues(fn)) do
                    if value == world then
                        gameFns[name] = fn
                        return fn
                    end
                end
            end
        end
    end
    return nil
end

local function GetBag()
    local world = FindWorld()
    if not world or type(rawget(world, "backpackNow")) ~= "function" then
        return nil
    end
    for _, value in pairs(GetUpvalues(world.backpackNow)) do
        if type(value) == "table" and type(value.slots) == "table" then
            return value
        end
    end
    return nil
end

local function CountItem(id)
    local bag = GetBag()
    if not bag then
        return nil
    end
    local total = 0
    for _, slot in pairs(bag.slots) do
        if type(slot) == "table" and slot.id == id then
            total += slot.n or 0
        end
    end
    return total
end

local function TileValue(world, layer, x, y)
    local grid = rawget(world, layer)
    local row = grid and grid[y]
    return row and row[x] or nil
end

local function InBounds(world, x, y)
    return type(world.w) == "number" and x >= 0 and y >= 0 and x < world.w and y < world.h
end

local function LayerOf(id)
    local db = GetItemDB()
    local item = db and db[id]
    if type(item) == "table" and item.background then
        return "bg"
    end
    return "fg"
end

----------------------------------------------------------------------
-- AUTO FARM
----------------------------------------------------------------------
local farmToken = 0
local farmAnchor = nil

local function FarmCells(world, anchor)
    local cells = {}
    for key, on in pairs(Config.farmGrid) do
        local dx, dy = tostring(key):match("^(-?%d+),(-?%d+)$")
        dx, dy = tonumber(dx), tonumber(dy)
        if on and dx and dy and math.abs(dx) <= 2 and math.abs(dy) <= 2 and not (dx == 0 and dy == 0) then
            local x, y = anchor.x + dx, anchor.y + dy
            if InBounds(world, x, y) then
                table.insert(cells, { x = x, y = y })
            end
        end
    end
    table.sort(cells, function(p, q)
        if p.y ~= q.y then
            return p.y < q.y
        end
        return p.x < q.x
    end)
    return cells
end

local function PlaceCell(id, cell, facing)
    local setTile = FindGameFn("setTile")
    if not setTile then
        return false
    end
    local ok = pcall(setTile, LayerOf(id), cell.x, cell.y, id, false, facing < 0)
    if not ok then
        return false
    end
    local bag = GetBag()
    if bag and type(bag.remove) == "function" then
        pcall(bag.remove, bag, id, 1)
    end
    return true
end

local function BreakCell(world, id, cell, token)
    local hit = FindGameFn("hit")
    if not hit then
        return false
    end
    local layer = LayerOf(id)
    if layer == "bg" and TileValue(world, "fg", cell.x, cell.y) ~= 0 then
        return false
    end
    local started = os.clock()
    while farmToken == token and TileValue(world, layer, cell.x, cell.y) == id do
        if os.clock() - started > 10 then
            return false
        end
        pcall(hit, cell.x, cell.y, true)
        task.wait(math.max(0.03, Config.farmDelay))
    end
    return TileValue(world, layer, cell.x, cell.y) ~= id
end

local function DropSet(world)
    local set = {}
    local ok, list = pcall(world.dropList)
    if ok and type(list) == "table" then
        for _, drop in ipairs(list) do
            set[drop] = true
        end
    end
    return set
end

local function CollectDrops(world, anchor, before, token)
    local ok, list = pcall(world.dropList)
    if not ok or type(list) ~= "table" then
        return 0
    end
    local targets = {}
    for _, drop in ipairs(list) do
        if not before[drop] and type(drop.x) == "number" and type(drop.y) == "number" and not drop.pending then
            table.insert(targets, drop)
        end
    end
    local picked = 0
    for _, drop in ipairs(targets) do
        if farmToken ~= token then
            break
        end
        if table.find(list, drop) then
            local reached = Nav.To(math.floor(drop.x), math.floor(drop.y), function() return farmToken ~= token end)
            local waited = os.clock()
            while reached and farmToken == token and table.find(list, drop) and os.clock() - waited < 0.9 do
                task.wait(0.05)
            end
            if not table.find(list, drop) then
                picked += 1
            end
        end
    end
    Nav.To(anchor.x, anchor.y, function() return farmToken ~= token end)
    return picked
end

local function FarmLoop(token)
    while farmToken == token do
        local world = FindWorld()
        if not world then
            farmStats.status = "World tidak ditemukan"
            break
        end
        if CurrentWorldName() ~= farmAnchor.world then
            farmStats.status = "World berubah, farm berhenti"
            Notify("Auto Farm berhenti: kamu pindah world.")
            break
        end

        local id = Config.farmPlaceId
        local layer = LayerOf(id)
        local cells = FarmCells(world, farmAnchor)
        if #cells == 0 then
            farmStats.status = "Tidak ada sel target"
            Notify("Auto Farm: pilih kotak target di grid GUI (" .. Config.prefix .. "af).")
            break
        end

        local tx, ty = GetTile()
        if tx ~= farmAnchor.x or ty ~= farmAnchor.y then
            Nav.To(farmAnchor.x, farmAnchor.y, function() return farmToken ~= token end)
            task.wait(0.15)
        end

        -- 1) place
        farmStats.status = "Place " .. ItemName(id)
        local outOfItem = false
        for _, cell in ipairs(cells) do
            if farmToken ~= token then
                break
            end
            if TileValue(world, layer, cell.x, cell.y) == 0 then
                local have = CountItem(id)
                if have ~= nil and have <= 0 then
                    outOfItem = true
                    break
                end
                if PlaceCell(id, cell, farmAnchor.facing) then
                    farmStats.placed += 1
                end
                task.wait(0.1)
            end
        end
        if farmToken ~= token then
            break
        end
        task.wait(0.35)

        -- 2) break
        farmStats.status = "Break " .. ItemName(id)
        local before = DropSet(world)
        for _, cell in ipairs(cells) do
            if farmToken ~= token then
                break
            end
            if TileValue(world, layer, cell.x, cell.y) == id then
                if BreakCell(world, id, cell, token) then
                    farmStats.broken += 1
                end
            end
        end
        if farmToken ~= token then
            break
        end

        -- 3) ambil item
        if Config.farmTake then
            farmStats.status = "Ambil item"
            task.wait(0.3)
            farmStats.picked += CollectDrops(world, farmAnchor, before, token)
        end

        farmStats.cycles += 1

        if outOfItem then
            farmStats.status = "Item habis"
            Notify("Auto Farm berhenti: " .. ItemName(id) .. " habis di inventory.")
            break
        end
        task.wait(0.1)
    end
end

function StopFarm()
    if not farmOn then
        return false
    end
    farmToken += 1
    farmOn = false
    farmStats.status = "Mati"
    return true
end

function StartFarm()
    if farmOn then
        return true
    end
    local id = Config.farmPlaceId
    if type(id) ~= "number" or id <= 0 or ItemName(id) == "?" then
        Notify("Isi ID block dulu di GUI Auto Farm (" .. Config.prefix .. "af).")
        return false
    end
    local selected = 0
    for key, on in pairs(Config.farmGrid) do
        local dx, dy = tostring(key):match("^(-?%d+),(-?%d+)$")
        if on and dx and dy then
            selected += 1
        end
    end
    if selected < 1 then
        Notify("Pilih minimal 1 kotak di grid Auto Farm (" .. Config.prefix .. "af).")
        return false
    end
    if not (FindGameFn("hit") and FindGameFn("setTile")) then
        Notify("Fungsi hit/place game tidak ditemukan (executor perlu getgc + debug.info).")
        return false
    end
    local x, y, facing = GetGridState()
    if not x then
        Notify("Posisi tidak terdeteksi!")
        return false
    end

    farmAnchor = {
        x = math.floor(x),
        y = math.floor(y - 0.475),
        facing = facing,
        world = CurrentWorldName(),
    }
    farmToken += 1
    local token = farmToken
    farmOn = true
    farmStats = { status = "Mulai", placed = 0, broken = 0, picked = 0, cycles = 0 }

    task.spawn(function()
        local ok, err = pcall(FarmLoop, token)
        if not ok then
            warn(err)
            Notify("Auto Farm error: " .. tostring(err))
        end
        if farmToken == token then
            farmOn = false
            if farmStats.status ~= "Item habis" then
                farmStats.status = "Mati"
            end
            if RefreshHub then
                RefreshHub()
            end
        end
    end)
    return true
end

----------------------------------------------------------------------
-- PATHFINDING + CLICK TP (DENGAN KECEPATAN AMAN ANTI-ROLLBACK)
----------------------------------------------------------------------
do
    local function Passable(db, world, x, y)
        if not InBounds(world, x, y) then
            return false
        end
        local id = TileValue(world, "fg", x, y)
        if id == nil then
            return false
        end
        if id == 0 then
            return true
        end
        local item = db and db[id]
        if type(item) ~= "table" then
            return false
        end
        if item.combiner then
            local okC, shut = pcall(function()
                return world.combinerShut(x, y)
            end)
            return okC and not shut
        end
        if item.entrance then
            local sw = nil
            local okS, sws = pcall(function()
                return world.switches
            end)
            if okS and type(sws) == "table" then
                sw = sws[y * world.w + x]
            end
            if item.gate then
                return sw ~= nil and sw.off == true
            end
            if sw and sw.public then
                return true
            end
            local okA, may = pcall(function()
                return world.areas.mayBuild(world.lock, x, y)
            end)
            return okA and may and true or false
        end
        return not item.solid
    end

    function Nav.Find(sx, sy, tx, ty)
        local world = FindWorld()
        local db = GetItemDB()
        if not world or type(rawget(world, "w")) ~= "number" then
            return nil, "world"
        end
        local W = world.w

        if not Passable(db, world, tx, ty) then
            local best, bestD = nil, math.huge
            for r = 1, 3 do
                for dy = -r, r do
                    for dx = -r, r do
                        local nx, ny = tx + dx, ty + dy
                        if math.max(math.abs(dx), math.abs(dy)) == r and Passable(db, world, nx, ny) then
                            local d = math.abs(dx) + math.abs(dy)
                            if d < bestD then
                                best, bestD = { nx, ny }, d
                            end
                        end
                    end
                end
                if best then
                    break
                end
            end
            if not best then
                return nil, "target"
            end
            tx, ty = best[1], best[2]
        end

        if sx == tx and sy == ty then
            return {}, tx, ty
        end

        local startKey = sy * W + sx
        local goalKey = ty * W + tx
        local parent = { [startKey] = -1 }
        local queue, head = { startKey }, 1
        local found = false
        while head <= #queue do
            local key = queue[head]
            head += 1
            if key == goalKey then
                found = true
                break
            end
            local x, y = key % W, key // W
            local neighbors = { { x, y - 1 }, { x, y + 1 }, { x - 1, y }, { x + 1, y } }
            for _, n in ipairs(neighbors) do
                local nk = n[2] * W + n[1]
                if parent[nk] == nil and Passable(db, world, n[1], n[2]) then
                    parent[nk] = key
                    table.insert(queue, nk)
                end
            end
            if head % 800 == 0 then
                task.wait()
            end
        end
        if not found then
            return nil, "nopath"
        end

        local path, key = {}, goalKey
        while key ~= startKey do
            table.insert(path, 1, { x = key % W, y = key // W })
            key = parent[key]
        end
        return path, tx, ty
    end

    -- Jeda per langkah supaya tidak terdeteksi speedhack / di-rollback server
    local function StepWait()
        local stepDelay = tonumber(Config.moveStepDelay) or 0.07
        if stepDelay >= 0.02 then
            task.wait(stepDelay)
        else
            RunService.Heartbeat:Wait()
        end
    end

    function Nav.Walk(tx, ty, cancel)
        local started = os.clock()
        local world = FindWorld()
        if not world or type(world.goTo) ~= "function" then
            return false, "world"
        end
        local sx, sy = GetTile()
        if not sx then
            return false, "pos"
        end
        local path, a = Nav.Find(sx, sy, tx, ty)
        if not path then
            return false, a
        end
        local perStep = math.clamp(math.floor(tonumber(Config.navSpeed) or 1), 1, 6)
        local count = 0
        for _, node in ipairs(path) do
            if cancel and cancel() then
                return false, "cancel"
            end
            pcall(world.goTo, node.x, node.y)
            count += 1
            if count >= perStep then
                count = 0
                StepWait()
            end
        end
        return true, os.clock() - started
    end

    function Nav.Fly(tx, ty, cancel)
        local started = os.clock()
        local world = FindWorld()
        if not world or type(world.goTo) ~= "function" then
            return false, "world"
        end
        local sx, sy = GetTile()
        if not sx then
            return false, "pos"
        end
        local db = GetItemDB()
        if not InBounds(world, tx, ty) then
            return false, "target"
        end
        if not Passable(db, world, tx, ty) then
            local best, bestD = nil, math.huge
            for r = 1, 3 do
                for dy = -r, r do
                    for dx = -r, r do
                        local nx, ny = tx + dx, ty + dy
                        if math.max(math.abs(dx), math.abs(dy)) == r and Passable(db, world, nx, ny) then
                            local d = math.abs(dx) + math.abs(dy)
                            if d < bestD then
                                best, bestD = { nx, ny }, d
                            end
                        end
                    end
                end
                if best then
                    break
                end
            end
            if not best then
                return false, "target"
            end
            tx, ty = best[1], best[2]
        end

        local dx, dy = tx - sx, ty - sy
        local steps = math.max(math.abs(dx), math.abs(dy))
        if steps == 0 then
            return true, 0
        end
        local perStep = math.clamp(math.floor(tonumber(Config.navSpeed) or 1), 1, 6)
        local cancelled = false
        world.ghost = true
        local okFly = pcall(function()
            local count = 0
            for i = 1, steps do
                if cancel and cancel() then
                    cancelled = true
                    return
                end
                local x = sx + math.floor(dx * i / steps + 0.5)
                local y = sy + math.floor(dy * i / steps + 0.5)
                pcall(world.goTo, x, y)
                count += 1
                if count >= perStep then
                    count = 0
                    StepWait()
                end
            end
        end)
        SyncGhostState()
        if cancelled then
            return false, "cancel"
        end
        if not okFly then
            return false, "fly"
        end
        pcall(world.goTo, tx, ty)
        return true, os.clock() - started
    end

    function Nav.Go(tx, ty, cancel)
        local mode = Config.moveMode
        if mode == "fly" then
            return Nav.Fly(tx, ty, cancel)
        elseif mode == "walk" then
            return Nav.Walk(tx, ty, cancel)
        end
        local ok, info = Nav.Walk(tx, ty, cancel)
        if ok or info == "cancel" then
            return ok, info
        end
        return Nav.Fly(tx, ty, cancel)
    end

    function Nav.To(x, y, cancel)
        local world = FindWorld()
        if not world then
            return false
        end
        local ok = Nav.Go(x, y, cancel)
        return ok
    end

    local actFn = nil
    local function CamInfo()
        if not actFn then
            if not getgcFn or not (debug and debug.info) then
                return nil
            end
            for _, fn in ipairs(getgcFn(true)) do
                if type(fn) == "function" then
                    local okName, fnName = pcall(debug.info, fn, "n")
                    if okName and fnName == "act" then
                        local ups = GetUpvalues(fn)
                        if ups[1] == Players and type(ups[2]) == "number"
                            and type(ups[4]) == "number" and type(ups[5]) == "number" then
                            actFn = fn
                            break
                        end
                    end
                end
            end
        end
        if not actFn then
            return nil
        end
        local okX, camX = pcall(getupvalueFn, actFn, 2)
        local okT, tile = pcall(getupvalueFn, actFn, 4)
        local okY, camY = pcall(getupvalueFn, actFn, 5)
        if okX and okT and okY and type(camX) == "number" and type(tile) == "number"
            and type(camY) == "number" and tile > 0 then
            return camX, camY, tile
        end
        return nil
    end

    function Nav.ScreenToTile(pos)
        local camX, camY, tile = CamInfo()
        if not camX then
            return nil
        end
        local worldGui = PlayerGui:FindFirstChild("World", true)
        if not worldGui or not worldGui:IsA("GuiObject") then
            return nil
        end
        local scaleObj = worldGui:FindFirstChildWhichIsA("UIScale", true)
        local scale = scaleObj and scaleObj.Scale or 1
        local rel = (Vector2.new(pos.X, pos.Y) - worldGui.AbsolutePosition) / scale
        return math.floor(camX + rel.X / tile), math.floor(camY + rel.Y / tile)
    end

    local function OnClick(input, processed)
        if processed or not Nav.clickOn then
            return
        end
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
                return Nav.token ~= token or not Nav.clickOn
            end)
            if ok then
                Nav.last = string.format("PATH FINDING in %.2fs", os.clock() - started)
                Notify(Nav.last)
            elseif info == "cancel" then
                return
            else
                Nav.last = "Gagal (" .. tostring(info) .. ")"
                if info == "nopath" then
                    Notify("PATH FINDING gagal: tidak ada jalan ke sana.")
                elseif info == "target" then
                    Notify("PATH FINDING gagal: tujuan tertutup block.")
                else
                    Notify("PATH FINDING gagal: " .. tostring(info))
                end
            end
        end)
    end

    function Nav.StartClick()
        if Nav.clickOn then
            return true
        end
        if not CamInfo() then
            Notify("Click TP: data kamera game tidak ditemukan (executor perlu getgc + debug.info).")
            return false
        end
        Nav.clickOn = true
        Nav.conn = UserInputService.InputBegan:Connect(OnClick)
        return true
    end

    function Nav.StopClick()
        if not Nav.clickOn then
            return false
        end
        Nav.clickOn = false
        Nav.token += 1
        if Nav.conn then
            Nav.conn:Disconnect()
            Nav.conn = nil
        end
        return true
    end
end

----------------------------------------------------------------------
-- AUTO CLEAR WORLD (LEGIT METHOD + MODFLY ANTI-JATUH + SAFE SPEED)
-- Sistem Auto Clear:
-- 1. Mulai (aktifkan ModFly agar karakter tidak jatuh saat block/bg hancur)
-- 2. Deteksi / Scan objek-objek di world
-- 3. Menuju ke koordinat block paling kecil (misal (1,23) -> bergerak ke (1,22) di atas block)
-- 4. Jika block hancur, lanjut ke block selanjutnya
-- 5. Jika yang di-break tidak hancur dalam 5 detik, skip block tersebut
-- 6. Lakukan hingga seluruh blok yang ada di world tersebut habis
-- 7. Selesai (matikan ModFly kembali)
----------------------------------------------------------------------
do
    local BREAK_TIMEOUT = 5.0

    local function Protected(db, id)
        local item = db and db[id]
        if type(item) ~= "table" then
            return true
        end
        if item.lock or item.area then
            return true
        end
        if type(item.hits) == "number" and item.hits <= 0 then
            return true
        end
        local name = type(item.name) == "string" and item.name:lower() or ""
        if name:find("bedrock", 1, true) or name:find("main door", 1, true)
            or name:find("white door", 1, true) or name:find("world lock", 1, true) then
            return true
        end
        return false
    end

    local function Alive(world, t)
        return TileValue(world, t.layer, t.x, t.y) == t.id
    end

    local function Collect(world, db, skippedSet)
        local list = {}
        for y = 0, world.h - 1 do
            for x = 0, world.w - 1 do
                local f = TileValue(world, "fg", x, y)
                if f and f ~= 0 and not Protected(db, f) then
                    local keyFg = x .. "," .. y .. ",fg"
                    if not skippedSet[keyFg] then
                        table.insert(list, { x = x, y = y, id = f, layer = "fg", key = keyFg })
                    end
                end
                local b = TileValue(world, "bg", x, y)
                if b and b ~= 0 and not Protected(db, b) then
                    local keyBg = x .. "," .. y .. ",bg"
                    if not skippedSet[keyBg] then
                        table.insert(list, { x = x, y = y, id = b, layer = "bg", key = keyBg })
                    end
                end
            end
        end

        table.sort(list, function(p, q)
            if p.y ~= q.y then
                return p.y < q.y
            end
            if p.x ~= q.x then
                return p.x < q.x
            end
            return p.layer == "fg" and q.layer == "bg"
        end)
        return list
    end

    -- Berdiri tepat di atas block (x, y - 1) supaya tidak menembus block solid & tidak jauh
    local function GetStandSpot(world, db, target)
        local aboveX, aboveY = target.x, target.y - 1
        if InBounds(world, aboveX, aboveY) then
            local fgAbove = TileValue(world, "fg", aboveX, aboveY)
            local itemAbove = db and fgAbove and db[fgAbove]
            if fgAbove == 0 or (type(itemAbove) == "table" and not itemAbove.solid) then
                return { x = aboveX, y = aboveY }
            end
        end
        local fallbacks = {
            { x = target.x - 1, y = target.y },
            { x = target.x + 1, y = target.y },
            { x = target.x - 1, y = target.y - 1 },
            { x = target.x + 1, y = target.y - 1 },
            { x = target.x,     y = target.y + 1 },
        }
        for _, pos in ipairs(fallbacks) do
            if InBounds(world, pos.x, pos.y) then
                local fg = TileValue(world, "fg", pos.x, pos.y)
                local item = db and fg and db[fg]
                if fg == 0 or (type(item) == "table" and not item.solid) then
                    return pos
                end
            end
        end
        return { x = target.x, y = math.max(0, target.y - 1) }
    end

    local function TakeDrops(world, before, token, returnSpot)
        local ok, list = pcall(world.dropList)
        if not ok or type(list) ~= "table" then
            return 0
        end
        local targets = {}
        for _, drop in ipairs(list) do
            if (before == nil or not before[drop]) and type(drop.x) == "number"
                and type(drop.y) == "number" and not drop.pending then
                table.insert(targets, drop)
            end
        end
        if #targets == 0 then
            return 0
        end
        local picked = 0
        for _, drop in ipairs(targets) do
            if Clear.token ~= token then
                break
            end
            if table.find(list, drop) then
                local reached = Nav.To(math.floor(drop.x), math.floor(drop.y), function() return Clear.token ~= token end)
                task.wait(math.max(0.05, Config.clearTpDelay))
                -- Matikan ghost sejenak di titik drop agar item tersedot jika game mewajibkan non-ghost
                if reached and Clear.token == token then
                    SetAutoFly("autoclear", false)
                    local waited = os.clock()
                    while Clear.token == token and table.find(list, drop) and os.clock() - waited < 0.45 do
                        task.wait(0.05)
                    end
                    if Config.clearModFly and Clear.on then
                        SetAutoFly("autoclear", true)
                    end
                end
                if not table.find(list, drop) then
                    picked += 1
                end
            end
        end
        if returnSpot and Clear.token == token then
            Nav.To(returnSpot.x, returnSpot.y, function() return Clear.token ~= token end)
            task.wait(math.max(0.05, Config.clearTpDelay))
        end
        return picked
    end

    local function ClearLoop(token, home)
        local db = GetItemDB()
        local hit = FindGameFn("hit")
        if not db or not hit then
            Clear.status = "Fungsi game tidak ditemukan"
            return
        end

        if Config.clearModFly then
            SetAutoFly("autoclear", true)
        end

        local skippedSet = {}
        local pass = 0

        while Clear.token == token do
            pass += 1
            local world = FindWorld()
            if not world or CurrentWorldName() ~= home.world then
                Clear.status = "World berubah, berhenti"
                Notify("Auto Clear berhenti: kamu pindah world.")
                return
            end

            Clear.status = "Scan objek di world..."
            Clear.stats.pass = pass
            local targets = Collect(world, db, skippedSet)
            Clear.stats.scanned = #targets
            Clear.stats.left = #targets

            if pass == 1 then
                if #targets > 0 then
                    local first = targets[1]
                    Notify(string.format(
                        "Scan selesai: %d block ditemukan. Mulai dari ujung (%d, %d).",
                        #targets, first.x, first.y
                    ))
                else
                    Notify("World sudah bersih, tidak ada block untuk dihancurkan.")
                end
            end

            if #targets == 0 then
                break
            end

            local brokeAnyInPass = false

            for idx, target in ipairs(targets) do
                if Clear.token ~= token then
                    return
                end
                world = FindWorld()
                if not world or CurrentWorldName() ~= home.world then
                    Clear.status = "World berubah, berhenti"
                    Notify("Auto Clear berhenti: kamu pindah world.")
                    return
                end

                if Config.clearModFly then
                    SetAutoFly("autoclear", true)
                end

                if Alive(world, target) then
                    if target.layer == "bg" and (TileValue(world, "fg", target.x, target.y) or 0) ~= 0 then
                        continue
                    end

                    local spot = GetStandSpot(world, db, target)
                    Clear.status = string.format(
                        "Menuju (%d,%d) -> Break (%d,%d) [%d/%d]",
                        spot.x, spot.y, target.x, target.y, idx, #targets
                    )

                    local px, py = GetTile()
                    if px ~= spot.x or py ~= spot.y then
                        local reached = Nav.To(spot.x, spot.y, function() return Clear.token ~= token end)
                        task.wait(math.max(0.05, Config.clearTpDelay))
                        -- Pastikan karakter benar-benar sudah sampai di dekat spot (jarak <= 2 tile)
                        local cx, cy = GetTile()
                        if not reached or not cx or math.abs(cx - spot.x) > 2 or math.abs(cy - spot.y) > 2 then
                            -- Coba sekali lagi dengan mode Fly bertahap agar tidak di-rollback server
                            Nav.Fly(spot.x, spot.y, function() return Clear.token ~= token end)
                            task.wait(math.max(0.05, Config.clearTpDelay))
                        end
                    end

                    if Clear.token ~= token then
                        return
                    end

                    local beforeDrops = Config.clearTake and DropSet(world) or nil
                    local started = os.clock()
                    local timedOut = false

                    Clear.status = string.format(
                        "Break %s (%d,%d) [%d/%d]",
                        ItemName(target.id), target.x, target.y, idx, #targets
                    )

                    while Clear.token == token and Alive(world, target) do
                        if os.clock() - started >= BREAK_TIMEOUT then
                            timedOut = true
                            break
                        end
                        -- Jaga posisi apabila bergeser 1 tile, namun jika terlempar jauh (>2 tile) gunakan Nav.To
                        local cx, cy = GetTile()
                        if cx and (cx ~= spot.x or cy ~= spot.y) then
                            local dist = math.max(math.abs(cx - spot.x), math.abs(cy - spot.y))
                            if dist <= 2 then
                                pcall(world.goTo, spot.x, spot.y)
                            else
                                Nav.To(spot.x, spot.y, function() return Clear.token ~= token end)
                            end
                        end
                        pcall(hit, target.x, target.y, true)
                        task.wait(math.max(0.03, Config.clearBreakDelay))
                    end

                    if Clear.token ~= token then
                        return
                    end

                    if not Alive(world, target) then
                        brokeAnyInPass = true
                        Clear.stats.broken += 1
                        Clear.stats.left = math.max(0, Clear.stats.left - 1)

                        if Config.clearTake then
                            task.wait(0.12)
                            Clear.stats.picked += TakeDrops(world, beforeDrops, token, spot)
                        end
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

            if not brokeAnyInPass then
                break
            end
        end

        if Config.clearTake and Clear.token == token then
            local world = FindWorld()
            if world then
                Clear.status = "Ambil sisa item drop..."
                Clear.stats.picked += TakeDrops(world, nil, token, home)
            end
        end

        local world = FindWorld()
        if world and Clear.token == token then
            Nav.To(home.x, home.y, function() return Clear.token ~= token end)
        end
        SetAutoFly("autoclear", false)
        Clear.status = "Selesai"
        Notify(string.format(
            "Auto Clear selesai! Hancur: %d | Diambil: %d | Di-skip: %d",
            Clear.stats.broken, Clear.stats.picked, Clear.stats.skipped
        ))
    end

    function Clear.Stop()
        if not Clear.on then
            return false
        end
        Clear.token += 1
        Clear.on = false
        SetAutoFly("autoclear", false)
        Clear.status = "Mati"
        return true
    end

    function Clear.Start()
        if Clear.on then
            return true
        end
        if farmOn then
            StopFarm()
        end
        if Harvest.on then
            Harvest.Stop()
        end
        if not (FindGameFn("hit") and GetItemDB()) then
            Notify("Fungsi hit game tidak ditemukan (executor perlu getgc + debug.info).")
            return false
        end
        local x, y = GetGridState()
        if not x then
            Notify("Posisi tidak terdeteksi!")
            return false
        end
        local world = FindWorld()
        if not world or type(rawget(world, "w")) ~= "number" then
            Notify("World tidak ditemukan.")
            return false
        end

        if longhandOn then
            StopLonghand()
        end

        local home = {
            x = math.floor(x),
            y = math.floor(y - 0.475),
            world = CurrentWorldName(),
        }
        Clear.token += 1
        local token = Clear.token
        Clear.on = true
        Clear.status = "Mulai"
        Clear.stats = { scanned = 0, broken = 0, picked = 0, skipped = 0, left = 0, pass = 0 }
        task.spawn(function()
            local ok, err = pcall(ClearLoop, token, home)
            if not ok then
                warn(err)
                Notify("Auto Clear error: " .. tostring(err))
            end
            SetAutoFly("autoclear", false)
            if Clear.token == token then
                Clear.on = false
                if Clear.status ~= "Selesai" then
                    Clear.status = "Mati"
                end
                if RefreshHub then
                    RefreshHub()
                end
            end
        end)
        return true
    end
end

----------------------------------------------------------------------
-- AUTO HARVEST
-- Sistem Auto Harvest:
-- 1. Mulai
-- 2. Scan World
-- 3. Cari objek pohon (tile fg dengan item.kind == "seed" / item.tree)
-- 4. Cek apakah pohon itu siap harvest (ripe == true / waktu tumbuh terpenuhi)
-- 5. Jika siap harvest, bergerak ke pohon tersebut dan pukul
-- 6. Jika tidak siap harvest, skip dan lanjut ke pohon selanjutnya
-- 7. Lakukan hingga seluruh pohon yang ready harvest habis
-- 8. Selesai
----------------------------------------------------------------------
do
    local HARVEST_TIMEOUT = 4.0

    local function IsSeedItem(db, id)
        local item = db and db[id]
        if type(item) ~= "table" then
            return false
        end
        return item.kind == "seed" or type(item.tree) == "table" or type(item.grow) == "number"
    end

    local function GetTreeLookMap(world)
        if not world or type(world.treeLook) ~= "function" or not getupvalueFn then
            return nil
        end
        local ok, map = pcall(getupvalueFn, world.treeLook, 8)
        if ok and type(map) == "table" then
            return map
        end
        -- Fallback jika indeks upvalue bergeser
        for i = 1, 15 do
            local okU, up = pcall(getupvalueFn, world.treeLook, i)
            if not okU then
                break
            end
            if type(up) == "table" and up ~= world and up ~= GetItemDB() then
                for k, v in pairs(up) do
                    if type(k) == "number" and type(v) == "table" and (v.tree ~= nil or v.scale ~= nil) then
                        return up
                    end
                    break
                end
            end
        end
        return nil
    end

    -- Cek apakah pohon di (x, y) sudah siap harvest (Ready Harvest)
    local function IsTreeReady(world, db, x, y, id)
        local item = db and db[id]
        if type(item) ~= "table" then
            return false
        end
        local growTime = tonumber(item.grow) or tonumber(item.baseGrow) or 31
        local idx = y * world.w + x

        -- Panggil world.treeLook(x, y) supaya game me-refresh status .ripe pada tabel pohon
        if type(world.treeLook) == "function" then
            pcall(world.treeLook, x, y)
        end

        local treeMap = GetTreeLookMap(world)
        local entry = treeMap and treeMap[idx]
        if type(entry) == "table" then
            if entry.ripe == true or entry.fruitMade == true or entry.step == 1 then
                return true
            end
            if type(entry.tree) == "table" and type(entry.tree.p) == "number" then
                local nowServer = workspace:GetServerTimeNow()
                return (nowServer - entry.tree.p) >= growTime
            end
            -- Jika entry ada namun ripe masih false/nil dan step < 1, berarti belum matang
            if entry.ripe == false or (type(entry.step) == "number" and entry.step < 1) then
                return false
            end
        end

        -- Cek dari tabel world.placedAt.fg apabila baru ditanam di sesi ini
        local placedFg = world.placedAt and world.placedAt.fg
        local plantedAt = placedFg and placedFg[idx]
        if type(plantedAt) == "number" then
            return (os.clock() - plantedAt) >= growTime
        end

        return false
    end

    -- Scan seluruh objek pohon di world (urut dari atas ke bawah, kiri ke kanan)
    local function ScanTrees(world, db)
        local trees = {}
        for y = 0, world.h - 1 do
            for x = 0, world.w - 1 do
                local id = TileValue(world, "fg", x, y)
                if id and id ~= 0 and IsSeedItem(db, id) then
                    table.insert(trees, { x = x, y = y, id = id })
                end
            end
        end
        table.sort(trees, function(a, b)
            if a.y ~= b.y then
                return a.y < b.y
            end
            return a.x < b.x
        end)
        return trees
    end

    local function CollectHarvestDrops(world, before, token, spot)
        local ok, list = pcall(world.dropList)
        if not ok or type(list) ~= "table" then
            return 0
        end
        local targets = {}
        for _, drop in ipairs(list) do
            if (before == nil or not before[drop]) and type(drop.x) == "number"
                and type(drop.y) == "number" and not drop.pending then
                table.insert(targets, drop)
            end
        end
        if #targets == 0 then
            return 0
        end
        local picked = 0
        for _, drop in ipairs(targets) do
            if Harvest.token ~= token then
                break
            end
            if table.find(list, drop) then
                local reached = Nav.To(math.floor(drop.x), math.floor(drop.y), function() return Harvest.token ~= token end)
                task.wait(math.max(0.05, Config.harvestTpDelay))
                if reached and Harvest.token == token then
                    SetAutoFly("autoharvest", false)
                    local waited = os.clock()
                    while Harvest.token == token and table.find(list, drop) and os.clock() - waited < 0.45 do
                        task.wait(0.05)
                    end
                    if Config.harvestModFly and Harvest.on then
                        SetAutoFly("autoharvest", true)
                    end
                end
                if not table.find(list, drop) then
                    picked += 1
                end
            end
        end
        if spot and Harvest.token == token then
            Nav.To(spot.x, spot.y, function() return Harvest.token ~= token end)
        end
        return picked
    end

    local function HarvestLoop(token, home)
        local db = GetItemDB()
        local hit = FindGameFn("hit")
        if not db or not hit then
            Harvest.status = "Fungsi game tidak ditemukan"
            return
        end

        if Config.harvestModFly then
            SetAutoFly("autoharvest", true)
        end

        local failedSet = {}
        local pass = 0

        while Harvest.token == token do
            pass += 1
            local world = FindWorld()
            if not world or CurrentWorldName() ~= home.world then
                Harvest.status = "World berubah, berhenti"
                Notify("Auto Harvest berhenti: kamu pindah world.")
                return
            end

            -- 2 & 3. Scan World & cari objek pohon
            Harvest.status = "Scan objek pohon di world..."
            local allTrees = ScanTrees(world, db)
            Harvest.stats.totalTrees = #allTrees

            if #allTrees == 0 then
                if pass == 1 then
                    Notify("Auto Harvest: Tidak ditemukan pohon di world ini.")
                end
                break
            end

            -- 4. Cek apakah pohon siap harvest
            local readyTrees = {}
            local skippedNotReady = 0
            for _, t in ipairs(allTrees) do
                local key = t.x .. "," .. t.y
                if not failedSet[key] then
                    if IsTreeReady(world, db, t.x, t.y, t.id) then
                        table.insert(readyTrees, t)
                    else
                        skippedNotReady += 1
                    end
                end
            end

            Harvest.stats.ready = #readyTrees
            if pass == 1 then
                Harvest.stats.skipped = skippedNotReady
                Notify(string.format(
                    "Scan Pohon: %d total | %d siap panen | %d belum siap (di-skip).",
                    #allTrees, #readyTrees, skippedNotReady
                ))
            end

            -- 7. Jika seluruh pohon yang ready harvest sudah habis -> keluar loop (Selesai)
            if #readyTrees == 0 then
                break
            end

            local harvestedInPass = false

            for idx, tree in ipairs(readyTrees) do
                if Harvest.token ~= token then
                    return
                end
                world = FindWorld()
                if not world or CurrentWorldName() ~= home.world then
                    Harvest.status = "World berubah, berhenti"
                    Notify("Auto Harvest berhenti: kamu pindah world.")
                    return
                end

                if Config.harvestModFly then
                    SetAutoFly("autoharvest", true)
                end

                -- Pastikan pohon masih ada dan siap harvest
                if TileValue(world, "fg", tree.x, tree.y) == tree.id then
                    if not IsTreeReady(world, db, tree.x, tree.y, tree.id) then
                        Harvest.stats.skipped += 1
                        continue
                    end

                    -- 5. Bergerak ke pohon tersebut (tile pohon tidak solid sehingga bisa ditempati langsung)
                    Harvest.status = string.format(
                        "Menuju pohon (%d,%d) [%d/%d]",
                        tree.x, tree.y, idx, #readyTrees
                    )

                    local px, py = GetTile()
                    if px ~= tree.x or py ~= tree.y then
                        local reached = Nav.To(tree.x, tree.y, function() return Harvest.token ~= token end)
                        task.wait(math.max(0.05, Config.harvestTpDelay))
                        local cx, cy = GetTile()
                        if not reached or not cx or math.abs(cx - tree.x) > 2 or math.abs(cy - tree.y) > 2 then
                            Nav.Fly(tree.x, tree.y, function() return Harvest.token ~= token end)
                            task.wait(math.max(0.05, Config.harvestTpDelay))
                        end
                    end

                    if Harvest.token ~= token then
                        return
                    end

                    local beforeDrops = Config.harvestTake and DropSet(world) or nil
                    local started = os.clock()

                    Harvest.status = string.format(
                        "Harvest %s (%d,%d) [%d/%d]",
                        ItemName(tree.id), tree.x, tree.y, idx, #readyTrees
                    )

                    while Harvest.token == token and TileValue(world, "fg", tree.x, tree.y) == tree.id do
                        if os.clock() - started >= HARVEST_TIMEOUT then
                            break
                        end
                        local cx, cy = GetTile()
                        if cx and (cx ~= tree.x or cy ~= tree.y) then
                            local dist = math.max(math.abs(cx - tree.x), math.abs(cy - tree.y))
                            if dist <= 2 then
                                pcall(world.goTo, tree.x, tree.y)
                            else
                                Nav.To(tree.x, tree.y, function() return Harvest.token ~= token end)
                            end
                        end
                        pcall(hit, tree.x, tree.y, true)
                        task.wait(math.max(0.05, Config.harvestDelay))
                    end

                    if Harvest.token ~= token then
                        return
                    end

                    if TileValue(world, "fg", tree.x, tree.y) ~= tree.id then
                        harvestedInPass = true
                        Harvest.stats.harvested += 1
                        Harvest.stats.ready = math.max(0, Harvest.stats.ready - 1)

                        if Config.harvestTake then
                            task.wait(0.15)
                            Harvest.stats.picked += CollectHarvestDrops(world, beforeDrops, token, { x = tree.x, y = tree.y })
                        end
                    else
                        failedSet[tree.x .. "," .. tree.y] = true
                        Harvest.stats.skipped += 1
                    end
                end
            end

            if not harvestedInPass then
                break
            end
        end

        if Config.harvestTake and Harvest.token == token then
            local world = FindWorld()
            if world then
                Harvest.status = "Ambil sisa drop panen..."
                Harvest.stats.picked += CollectHarvestDrops(world, nil, token, home)
            end
        end

        -- 8. Selesai
        local world = FindWorld()
        if world and Harvest.token == token then
            Nav.To(home.x, home.y, function() return Harvest.token ~= token end)
        end
        SetAutoFly("autoharvest", false)
        Harvest.status = "Selesai"
        Notify(string.format(
            "Auto Harvest selesai! Dipanen: %d | Diambil: %d | Di-skip (belum siap): %d",
            Harvest.stats.harvested, Harvest.stats.picked, Harvest.stats.skipped
        ))
    end

    function Harvest.Stop()
        if not Harvest.on then
            return false
        end
        Harvest.token += 1
        Harvest.on = false
        SetAutoFly("autoharvest", false)
        Harvest.status = "Mati"
        return true
    end

    function Harvest.Start()
        if Harvest.on then
            return true
        end
        if farmOn then
            StopFarm()
        end
        if Clear.on then
            Clear.Stop()
        end
        if not (FindGameFn("hit") and GetItemDB()) then
            Notify("Fungsi hit game tidak ditemukan (executor perlu getgc + debug.info).")
            return false
        end
        local x, y = GetGridState()
        if not x then
            Notify("Posisi tidak terdeteksi!")
            return false
        end
        local world = FindWorld()
        if not world or type(rawget(world, "w")) ~= "number" then
            Notify("World tidak ditemukan.")
            return false
        end

        if longhandOn then
            StopLonghand()
        end

        local home = {
            x = math.floor(x),
            y = math.floor(y - 0.475),
            world = CurrentWorldName(),
        }
        Harvest.token += 1
        local token = Harvest.token
        Harvest.on = true
        Harvest.status = "Mulai"
        Harvest.stats = { totalTrees = 0, ready = 0, harvested = 0, skipped = 0, picked = 0 }
        task.spawn(function()
            local ok, err = pcall(HarvestLoop, token, home)
            if not ok then
                warn(err)
                Notify("Auto Harvest error: " .. tostring(err))
            end
            SetAutoFly("autoharvest", false)
            if Harvest.token == token then
                Harvest.on = false
                if Harvest.status ~= "Selesai" then
                    Harvest.status = "Mati"
                end
                if RefreshHub then
                    RefreshHub()
                end
            end
        end)
        return true
    end
end

----------------------------------------------------------------------
-- AUTO QUEST
----------------------------------------------------------------------
local questToken = 0

local function IsShown(obj)
    local current = obj
    while current and current ~= PlayerGui do
        if current:IsA("GuiObject") and not current.Visible then
            return false
        end
        if current:IsA("ScreenGui") and not current.Enabled then
            return false
        end
        current = current.Parent
    end
    return true
end

local function CleanText(text)
    return (tostring(text):gsub("<[^>]+>", ""))
end

local function ClickGui(button)
    local clicked = false
    if getconnections then
        for _, signalName in ipairs({ "MouseButton1Click", "Activated", "MouseButton1Down", "MouseButton1Up" }) do
            local okSignal, conns = pcall(function()
                return getconnections(button[signalName])
            end)
            if okSignal and type(conns) == "table" then
                for _, conn in ipairs(conns) do
                    if pcall(function() conn:Fire() end) then
                        clicked = true
                    end
                end
            end
        end
    end
    if not clicked and firesignal then
        clicked = pcall(firesignal, button.MouseButton1Click)
    end
    return clicked
end

local function ButtonText(button)
    local texts = {}
    if button:IsA("TextButton") and button.Text ~= "" then
        table.insert(texts, button.Text)
    end
    for _, child in ipairs(button:GetDescendants()) do
        if (child:IsA("TextLabel") or child:IsA("TextButton")) and child.Text ~= "" then
            table.insert(texts, child.Text)
        end
    end
    return CleanText(table.concat(texts, " ")):lower()
end

local function FindQuestRoot()
    local viewport = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(800, 600)
    local best, bestCount = nil, 0
    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui.Name ~= "ANCHHubGB" and not gui.Name:lower():find("windui", 1, true) and gui:IsA("ScreenGui") then
            for _, obj in ipairs(gui:GetDescendants()) do
                if obj:IsA("TextLabel") and obj.Text ~= "" and IsShown(obj)
                    and CleanText(obj.Text):lower():find("quest", 1, true) then
                    local root = obj
                    while root.Parent and root.Parent:IsA("GuiObject") do
                        local size = root.Parent.AbsoluteSize
                        if size.X >= viewport.X * 0.95 and size.Y >= viewport.Y * 0.95 then
                            break
                        end
                        root = root.Parent
                    end
                    local count = #root:GetDescendants()
                    if count > bestCount then
                        best, bestCount = root, count
                    end
                end
            end
        end
    end
    return best
end

local function ParseNumber(text)
    return tonumber((text:gsub(",", "")))
end

local function GatherTexts(container)
    local texts = {}
    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Text ~= "" and IsShown(obj) then
            table.insert(texts, CleanText(obj.Text))
        end
    end
    return texts
end

local function ReadQuestRows(root)
    local rows, seen = {}, {}
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("TextLabel") and IsShown(obj) then
            local a, b = CleanText(obj.Text):match("(%d[%d,]*)%s*/%s*(%d[%d,]*)")
            if a and b then
                local container = obj.Parent
                local texts = GatherTexts(container)
                if #texts < 2 and container.Parent and container.Parent ~= root then
                    container = container.Parent
                    texts = GatherTexts(container)
                end
                if not seen[container] then
                    seen[container] = true
                    table.insert(rows, {
                        have = ParseNumber(a),
                        need = ParseNumber(b),
                        text = table.concat(texts, " "),
                    })
                end
            end
        end
    end
    return rows
end

local function ClassifyQuest(text)
    local lower = text:lower()
    local verb = nil
    if lower:find("break") or lower:find("punch") or lower:find("smash") or lower:find("harvest")
        or lower:find("chop") or lower:find("hancur") or lower:find("pecah") then
        verb = "break"
    elseif lower:find("place") or lower:find("build") or lower:find("plant")
        or lower:find("pasang") or lower:find("taruh") then
        verb = "place"
    elseif lower:find("collect") or lower:find("gather") or lower:find("pick up")
        or lower:find("kumpul") or lower:find("ambil") then
        verb = "collect"
    end

    local bestId, bestLen = nil, 0
    local list = GetBlockList()
    if list then
        for _, entry in ipairs(list) do
            if #entry.lower >= 3 and #entry.lower > bestLen and lower:find(entry.lower, 1, true) then
                bestId, bestLen = entry.id, #entry.lower
            end
        end
    end
    return verb, bestId
end

local function OpenQuestWindow()
    local world = FindWorld()
    local quests = world and rawget(world, "quests")
    if type(quests) ~= "table" or type(quests.open) ~= "function" then
        return nil
    end
    pcall(quests.open)
    task.wait(0.8)
    return FindQuestRoot()
end

local function CloseQuestWindow(root)
    if not root then
        return
    end
    for _, obj in ipairs(root:GetDescendants()) do
        if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and IsShown(obj) then
            local text = ButtonText(obj)
            if text == "x" or text:find("close", 1, true) or text:find("tutup", 1, true) then
                ClickGui(obj)
                return
            end
        end
    end
end

local function ClaimAll(root)
    local claimed = 0
    for _, obj in ipairs(root:GetDescendants()) do
        if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and IsShown(obj) then
            local text = ButtonText(obj)
            if text:find("claim", 1, true) or text:find("redeem", 1, true) or text:find("klaim", 1, true)
                or text:find("selesai", 1, true) then
                if ClickGui(obj) then
                    claimed += 1
                    task.wait(0.5)
                end
            end
        end
    end
    return claimed
end

function QuestReport()
    local root = OpenQuestWindow()
    if not root then
        Notify("Jendela quest tidak terbaca. Buka menu quest di game lalu ketik " .. Config.prefix .. "aq scan lagi.")
        return
    end
    local rows = ReadQuestRows(root)
    if #rows == 0 then
        Notify("Tidak ada baris progres (x/y) di jendela quest.")
    end
    for index, row in ipairs(rows) do
        local verb, itemId = ClassifyQuest(row.text)
        local line = string.format("Quest %d: %d/%d | aksi: %s | item: %s | %s", index, row.have, row.need,
            verb or "?", itemId and (ItemName(itemId) .. " #" .. itemId) or "?", row.text)
        print("[ANCHHub] " .. line)
        Notify(string.format("Quest %d: %d/%d  %s  %s", index, row.have, row.need, verb or "?",
            itemId and ItemName(itemId) or "?"))
    end
end

local function QuestLoop(token)
    while questOn and questToken == token do
        questStatus = "Membaca quest"
        local root = OpenQuestWindow()
        if not root then
            questStatus = "Jendela quest tidak terbaca"
            Notify("Auto Quest berhenti: jendela quest tidak terbaca. Coba " .. Config.prefix .. "aq scan.")
            break
        end

        questStatus = "Claim reward"
        ClaimAll(root)
        task.wait(0.4)
        root = FindQuestRoot() or root

        local target = nil
        for _, row in ipairs(ReadQuestRows(root)) do
            if row.have < row.need then
                local verb, itemId = ClassifyQuest(row.text)
                if (verb == "break" or verb == "place") and itemId then
                    local have = CountItem(itemId)
                    if have == nil or have > 0 then
                        target = { itemId = itemId, text = row.text }
                        break
                    end
                end
            end
        end
        CloseQuestWindow(root)

        if not target then
            questStatus = "Tidak ada quest yang bisa dikerjakan otomatis"
            Notify("Auto Quest selesai: tidak ada quest break/place dengan item yang kamu punya.")
            break
        end

        local savedId = Config.farmPlaceId
        Config.farmPlaceId = target.itemId
        questStatus = "Farm " .. ItemName(target.itemId)
        if farmOn then
            StopFarm()
            task.wait(0.3)
        end
        if not StartFarm() then
            Config.farmPlaceId = savedId
            questStatus = "Auto Farm gagal mulai"
            break
        end
        local started = os.clock()
        local lastCheck = os.clock()
        local done = false
        while questOn and questToken == token and farmOn and os.clock() - started < 900 do
            task.wait(1)
            if os.clock() - lastCheck >= 25 then
                lastCheck = os.clock()
                local checkRoot = OpenQuestWindow()
                if checkRoot then
                    local finished = true
                    for _, row in ipairs(ReadQuestRows(checkRoot)) do
                        local verb, itemId = ClassifyQuest(row.text)
                        if itemId == target.itemId and (verb == "break" or verb == "place") and row.have < row.need then
                            finished = false
                        end
                    end
                    CloseQuestWindow(checkRoot)
                    if finished then
                        done = true
                        break
                    end
                end
            end
        end
        StopFarm()
        Config.farmPlaceId = savedId
        if not (questOn and questToken == token) then
            break
        end
        if not done then
            questStatus = "Farm berhenti sebelum quest selesai"
            Notify("Auto Quest berhenti: farm berhenti (item habis / world berubah / timeout).")
            break
        end
        task.wait(1)
    end
    if questToken == token then
        questOn = false
        if RefreshHub then
            RefreshHub()
        end
    end
end

function StopQuest()
    if not questOn then
        return false
    end
    questToken += 1
    questOn = false
    questStatus = "Mati"
    StopFarm()
    return true
end

function StartQuest()
    if questOn then
        return true
    end
    questToken += 1
    local token = questToken
    questOn = true
    questStatus = "Mulai"
    task.spawn(function()
        local ok, err = pcall(QuestLoop, token)
        if not ok then
            warn(err)
            Notify("Auto Quest error: " .. tostring(err))
            if questToken == token then
                questOn = false
                if RefreshHub then
                    RefreshHub()
                end
            end
        end
    end)
    return true
end

----------------------------------------------------------------------
-- GOD MODE
----------------------------------------------------------------------
local godSaved = {}
local godConns = {}

function StopGod()
    if not godOn then
        return false
    end
    for _, saved in ipairs(godSaved) do
        pcall(function()
            rawset(saved.item, saved.key, saved.value)
        end)
    end
    godSaved = {}
    for _, conn in ipairs(godConns) do
        pcall(function()
            conn:Enable()
        end)
    end
    godConns = {}
    godOn = false
    return true
end

function StartGod()
    if godOn then
        return true
    end
    local db = GetItemDB()
    if not db then
        Notify("ItemDB game tidak ditemukan!")
        return false
    end
    godSaved = {}
    for _, item in pairs(db) do
        if type(item) == "table" then
            for _, key in ipairs({ "hurts", "deadly" }) do
                if item[key] then
                    table.insert(godSaved, { item = item, key = key, value = rawget(item, key) })
                    pcall(function()
                        if setreadonly then
                            setreadonly(item, false)
                        end
                        rawset(item, key, false)
                    end)
                end
            end
        end
    end

    local remotes = ReplicatedStorage:FindFirstChild("WorldRemotes")
    local burned = remotes and remotes:FindFirstChild("Burned")
    if burned and getconnections then
        local okConn, conns = pcall(getconnections, burned.OnClientEvent)
        if okConn and type(conns) == "table" then
            for _, conn in ipairs(conns) do
                if pcall(function() conn:Disable() end) then
                    table.insert(godConns, conn)
                end
            end
        end
    end
    godOn = true
    return true
end

----------------------------------------------------------------------
-- GROWSCAN
----------------------------------------------------------------------
local function FindGrowScanItem()
    local db = GetItemDB()
    if db then
        for id, item in pairs(db) do
            if type(id) == "number" and type(item) == "table" and item.growscan then
                return id
            end
        end
    end
    return 0
end

function OpenNativeGrowScan()
    local world = FindWorld()
    local ui = world and rawget(world, "growScan")
    if type(ui) ~= "table" or type(ui.open) ~= "function" then
        return false
    end
    local ok, err = pcall(ui.open, {
        item = FindGrowScanItem(),
        owner = true,
        blocksPublic = false,
        floatingPublic = false,
    }, function() end)
    if not ok then
        warn(err)
    end
    return ok
end

function ScanWorld()
    local world = FindWorld()
    if not world or type(rawget(world, "w")) ~= "number" then
        return nil
    end
    local result = { fg = {}, bg = {}, drops = {}, w = world.w, h = world.h }
    local gridFg, gridBg = rawget(world, "fg"), rawget(world, "bg")
    for y = 0, world.h - 1 do
        local rowFg = gridFg and gridFg[y]
        local rowBg = gridBg and gridBg[y]
        for x = 0, world.w - 1 do
            local f = rowFg and rowFg[x]
            if f and f ~= 0 then
                result.fg[f] = (result.fg[f] or 0) + 1
            end
            local b = rowBg and rowBg[x]
            if b and b ~= 0 then
                result.bg[b] = (result.bg[b] or 0) + 1
            end
        end
    end
    local okDrops, list = pcall(world.dropList)
    if okDrops and type(list) == "table" then
        for _, drop in ipairs(list) do
            if type(drop) == "table" and type(drop.id) == "number" then
                result.drops[drop.id] = (result.drops[drop.id] or 0) + (drop.n or 1)
            end
        end
    end
    return result
end

end

local Features = {
    blink = {
        label = "Blink",
        get = function() return blinkOn end,
        set = function(on)
            if on then return StartBlink() end
            return StopBlink()
        end,
    },
    longhand = {
        label = "Longhand",
        get = function() return longhandOn end,
        set = function(on)
            if on then return ApplyLonghand() end
            return StopLonghand()
        end,
    },
    noclip = {
        label = "Noclip",
        get = function() return noclipOn end,
        set = function(on)
            if on then return StartNoclip() end
            return StopNoclip()
        end,
    },
    ujump = {
        label = "Unlimited Jump",
        get = function() return ujumpOn end,
        set = function(on)
            if on then return StartUjump() end
            return StopUjump()
        end,
    },
    antiafk = {
        label = "Anti-AFK",
        get = function() return antiAfkOn end,
        set = function(on)
            if on then return StartAntiAfk() end
            return StopAntiAfk()
        end,
    },
    autorejoin = {
        label = "Auto Rejoin",
        get = function() return arjOn end,
        set = function(on)
            if on then return StartAutoRejoin() end
            return StopAutoRejoin()
        end,
    },
    god = {
        label = "God Mode",
        get = function() return godOn end,
        set = function(on)
            if on then return StartGod() end
            return StopGod()
        end,
    },
    clicktp = {
        label = "Click TP",
        get = function() return Nav.clickOn end,
        set = function(on)
            if on then return Nav.StartClick() end
            return Nav.StopClick()
        end,
    },
    autoclear = {
        label = "Auto Clear World",
        noSession = true,
        get = function() return Clear.on end,
        set = function(on)
            if on then return Clear.Start() end
            return Clear.Stop()
        end,
    },
    autoharvest = {
        label = "Auto Harvest",
        noSession = true,
        get = function() return Harvest.on end,
        set = function(on)
            if on then return Harvest.Start() end
            return Harvest.Stop()
        end,
    },
    autofarm = {
        label = "Auto Farm",
        noSession = true,
        get = function() return farmOn end,
        set = function(on)
            if on then return StartFarm() end
            return StopFarm()
        end,
    },
    autoquest = {
        label = "Auto Quest",
        noSession = true,
        get = function() return questOn end,
        set = function(on)
            if on then return StartQuest() end
            return StopQuest()
        end,
    },
}

local function SetFeature(key, on)
    local feature = Features[key]
    feature.set(on)
    if feature.get() == on then
        Notify(feature.label .. (on and " aktif." or " dimatikan."))
        if not feature.noSession then
            Config.session[key] = on or nil
        end
        SaveConfig()
    end
    if RefreshHub then
        RefreshHub()
    end
end

----------------------------------------------------------------------
-- SESI: simpan, auto-reload setelah teleport, pulihkan fitur
----------------------------------------------------------------------
local function ReloadSource()
    local url = Config.scriptUrl
    if type(url) ~= "string" or url == "" then
        url = genv.ANCHHubURL
    end
    if type(url) == "string" and url ~= "" then
        return string.format("loadstring(game:HttpGet(%q))()", url)
    end
    local okFile, exists = pcall(function()
        return isfile and readfile and isfile(SCRIPT_FILE)
    end)
    if okFile and exists then
        return string.format("loadstring(readfile(%q))()", SCRIPT_FILE)
    end
    return nil
end

local function GetQueueFn()
    return queue_on_teleport
        or (syn and syn.queue_on_teleport)
        or (fluxus and fluxus.queue_on_teleport)
end

local function ReloadReady()
    return GetQueueFn() ~= nil and ReloadSource() ~= nil
end

QueueReload = function()
    if not Config.autoReload then
        return false
    end
    local queueFn = GetQueueFn()
    local source = ReloadSource()
    if not queueFn or not source then
        return false
    end
    return pcall(queueFn, source)
end

local function InstallAutoexec()
    if not writefile then
        Notify("Executor tidak punya writefile.")
        return
    end
    local source = ReloadSource()
    if not source then
        Notify("Simpan skrip sebagai " .. SCRIPT_FILE .. " di folder workspace, atau isi URL dulu.")
        return
    end
    local loader = "-- ANCH HUB | GrowBlox auto-loader\n" .. source .. "\n"
    pcall(writefile, "ANCHHub_Loader.lua", loader)

    for _, path in ipairs({ "../autoexec/ANCHHub_Loader.lua", "../Autoexec/ANCHHub_Loader.lua" }) do
        local okWrite = pcall(writefile, path, loader)
        local okCheck, exists = pcall(function()
            return isfile and isfile(path)
        end)
        if okWrite and okCheck and exists then
            Notify("Auto-execute terpasang. Skrip jalan otomatis tiap buka Roblox.")
            return
        end
    end
    Notify("Folder autoexec tidak terjangkau. Salin ANCHHub_Loader.lua dari workspace ke folder autoexec executor.")
end

local function SaveSessionNow()
    Config.session = {}
    for key, feature in pairs(Features) do
        if feature.get() and not feature.noSession then
            Config.session[key] = true
        end
    end
    local world = CurrentWorldName()
    if world ~= "" then
        Config.lastWorld = world
    end
    SaveConfig()
end

local function RestoreSession()
    if not Config.autoRestore then
        return
    end

    local waited = 0
    while not (FindInventory() and FindWorld()) and waited < 60 do
        task.wait(1)
        waited += 1
    end
    waited = 0
    while CurrentWorldName() == "" and waited < 20 do
        task.wait(1)
        waited += 1
    end
    task.wait(1.5)

    if Config.autoWarp and Config.lastWorld ~= "" and CurrentWorldName() ~= Config.lastWorld then
        WarpToWorld(Config.lastWorld)
        task.wait(4)
    end

    local restored = {}
    for key, feature in pairs(Features) do
        if Config.session[key] and not feature.get() then
            local ok = pcall(feature.set, true)
            if ok and feature.get() then
                table.insert(restored, feature.label)
            end
        end
    end
    if RefreshHub then
        RefreshHub()
    end
    if #restored > 0 then
        table.sort(restored)
        Notify("Sesi dipulihkan: " .. table.concat(restored, ", "))
    end
end

----------------------------------------------------------------------
-- GUI (WindUI)
----------------------------------------------------------------------
local WindUI
do
    local ok, result = pcall(function()
        return require("./src/Init")
    end)

    if ok then
        WindUI = result
    else
        if RunService:IsStudio() and ReplicatedStorage:FindFirstChild("WindUI") then
            WindUI = require(cloneref(ReplicatedStorage:WaitForChild("WindUI"):WaitForChild("Init")))
        else
            WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
        end
    end
end

ToastHook = function(message)
    WindUI:Notify({
        Title = "ANCH HUB | GrowBlox",
        Content = tostring(message),
        Icon = "solar:bell-bold",
        Duration = 4,
    })
end

local Purple = Color3.fromHex("#7775F2")
local Yellow = Color3.fromHex("#ECA201")
local Green = Color3.fromHex("#10C550")
local Grey = Color3.fromHex("#83889E")
local Blue = Color3.fromHex("#257AF7")
local Red = Color3.fromHex("#EF4F1D")

local Window = WindUI:CreateWindow({
    Title = "ANCH Hub  |  GrowBlox",
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
        Title = "v9",
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
    for _, fn in ipairs(hub.refreshers) do
        pcall(fn)
    end
    hub.syncing = false
end

local function SetElementText(el, title, desc)
    if not el then
        return
    end
    pcall(function()
        if title and el.SetTitle then
            el:SetTitle(title)
        end
        if desc and el.SetDesc then
            el:SetDesc(desc)
        elseif desc and el.SetContent then
            el:SetContent(desc)
        end
    end)
end

local function AddFeatureToggle(tab, title, desc, key)
    local feature = Features[key]
    local toggle = tab:Toggle({
        Title = title,
        Desc = desc,
        Value = feature.get(),
        Callback = function(state)
            if hub.syncing then
                return
            end
            if feature.get() ~= state then
                SetFeature(key, state)
            end
        end,
    })
    table.insert(hub.refreshers, function()
        if toggle and toggle.Set then
            toggle:Set(feature.get())
        end
    end)
    return toggle
end

local function CopyId(id)
    if setclipboard then
        pcall(setclipboard, tostring(id))
    end
end

local MainSection = Window:Section({ Title = "Utama" })
local AutoSection = Window:Section({ Title = "Otomatisasi" })
local WorldSection = Window:Section({ Title = "World & Visual" })
local SystemSection = Window:Section({ Title = "Sistem" })

-- 1. Tab: Fitur ------------------------------------------------------
do
    local Tab = MainSection:Tab({
        Title = "Fitur",
        Icon = "solar:home-2-bold",
        IconColor = Green,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.features = Tab

    local statusPara = Tab:Paragraph({
        Title = "Status Karakter",
        Desc = "Mendeteksi posisi...",
    })

    task.spawn(function()
        while task.wait(0.3) do
            pcall(function()
                local tx, ty = GetTile()
                local worldName = CurrentWorldName()
                if tx then
                    SetElementText(
                        statusPara,
                        "World: " .. (worldName ~= "" and worldName or "-"),
                        string.format("Tile: %d, %d", tx, ty)
                    )
                else
                    SetElementText(statusPara, "Status Karakter", "Posisi tidak terdeteksi")
                end
            end)
        end
    end)

    Tab:Space()
    Tab:Section({ Title = "Fitur Utama" })

    AddFeatureToggle(Tab, "Blink Skin", "Warna skin berganti otomatis tiap 0.2-0.5 detik.", "blink")
    AddFeatureToggle(Tab, "Longhand", "Jangkauan punch & build lebih jauh (atur tile di Setelan).", "longhand")
    AddFeatureToggle(Tab, "Noclip (ModFly)", "Tembus blok & terbang (mode ghost). Naik: lompat, turun: bawah/S.", "noclip")
    AddFeatureToggle(Tab, "Unlimited Jump", "Lompat di udara tanpa batas, bahkan tanpa sayap.", "ujump")
    AddFeatureToggle(Tab, "Anti-AFK", "Mencegah kick karena idle.", "antiafk")
    AddFeatureToggle(Tab, "Auto Rejoin", "Rejoin otomatis ke world ini kalau terputus.", "autorejoin")
    AddFeatureToggle(Tab, "God Mode", "Kebal lava, spike, api (burn), dan hazard tile lain.", "god")
    AddFeatureToggle(Tab, "Auto Farm", "Atur kecepatan, ID block, dan pola place di tab Auto Farm.", "autofarm")
    AddFeatureToggle(Tab, "Auto Clear World", "Clear world legit dari ujung, ModFly aktif agar tidak jatuh, skip >5 dtk.", "autoclear")
    AddFeatureToggle(Tab, "Auto Harvest", "Scan pohon yang siap harvest, bergerak ke pohon & pukul sampai habis.", "autoharvest")
    AddFeatureToggle(Tab, "Click TP", "Klik tujuan, jalan lewat path tapi terlihat seperti teleport.", "clicktp")
    AddFeatureToggle(Tab, "Auto Quest", "Claim dan kerjakan quest otomatis (lihat tab Auto Quest).", "autoquest")

    Tab:Space()
    Tab:Section({ Title = "Aksi Cepat" })

    local dropAmountText = "100"
    local dropInput = Tab:Input({
        Title = "Jumlah Drop World Lock",
        Desc = "Isi jumlah WL (1 - " .. MAX_AMOUNT .. ")",
        Value = "100",
        Placeholder = "Jumlah",
        Callback = function(text)
            dropAmountText = text
        end,
    })

    local quickGroup = Tab:Group({})
    for idx, val in ipairs({ 1, 10, 50, 100 }) do
        quickGroup:Button({
            Title = tostring(val) .. " WL",
            Justify = "Center",
            Callback = function()
                dropAmountText = tostring(val)
                pcall(function()
                    if dropInput and dropInput.Set then
                        dropInput:Set(tostring(val))
                    end
                end)
                Notify("Jumlah drop diset ke " .. val .. " WL")
            end,
        })
        if idx < 4 then
            quickGroup:Space()
        end
    end

    Tab:Space()

    Tab:Button({
        Title = "Drop World Lock Sekarang",
        Color = Color3.fromHex("#305dff"),
        Justify = "Center",
        Callback = function()
            local amount = tonumber(dropAmountText)
            if amount and amount >= 1 and amount <= MAX_AMOUNT and amount == math.floor(amount) then
                task.spawn(DropWorldLock, amount)
            else
                Notify("Jumlah tidak valid (1-" .. MAX_AMOUNT .. ")")
            end
        end,
    })

    Tab:Space()

    Tab:Button({
        Title = "Rejoin World",
        Justify = "Center",
        Callback = Rejoin,
    })
end

-- 2. Tab: Auto Farm --------------------------------------------------
do
    local Tab = AutoSection:Tab({
        Title = "Auto Farm",
        Icon = "solar:check-square-bold",
        IconColor = Yellow,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.farm = Tab

    local function GridCount()
        local n = 0
        for _, on in pairs(Config.farmGrid) do
            if on then
                n += 1
            end
        end
        return n
    end

    local function GridSummaryText()
        local rows = {}
        for dy = -2, 2 do
            local cols = {}
            for dx = -2, 2 do
                if dx == 0 and dy == 0 then
                    table.insert(cols, "[P]")
                elseif Config.farmGrid[dx .. "," .. dy] then
                    table.insert(cols, "[ON]")
                else
                    table.insert(cols, "[..]")
                end
            end
            table.insert(rows, table.concat(cols, " "))
        end
        return table.concat(rows, "\n")
    end

    local farmStatusPara = Tab:Paragraph({
        Title = "Status Auto Farm",
        Desc = "Memuat...",
    })

    task.spawn(function()
        while task.wait(0.4) do
            pcall(function()
                local id = Config.farmPlaceId
                local blockText = (type(id) == "number" and id > 0) and (ItemName(id) .. " (ID " .. id .. ")") or "belum dipilih"
                SetElementText(
                    farmStatusPara,
                    "Status: " .. farmStats.status,
                    string.format(
                        "Block: %s\nKotak target: %d | Jeda: %.2f dtk\nPlace: %d | Break: %d | Ambil: %d | Siklus: %d",
                        blockText, GridCount(), Config.farmDelay,
                        farmStats.placed, farmStats.broken, farmStats.picked, farmStats.cycles
                    )
                )
            end)
        end
    end)

    AddFeatureToggle(Tab, "Auto Farm", "Place, pukul, lalu ambil item. Berdiri di posisi farm sebelum menyalakan.", "autofarm")

    Tab:Space()
    Tab:Section({ Title = "Pengaturan Farm" })

    Tab:Input({
        Title = "Kecepatan pukulan (detik)",
        Desc = "Jeda antar pukulan. Normal game 0.22, minimum 0.03.",
        Value = tostring(Config.farmDelay),
        Placeholder = "0.22",
        Callback = function(text)
            local value = tonumber(text)
            if value and value >= 0.03 and value <= 5 then
                Config.farmDelay = value
                SaveConfig()
            else
                Notify("Isi angka 0.03 sampai 5.")
            end
        end,
    })

    local idInput
    idInput = Tab:Input({
        Title = "ID Block",
        Desc = "Block yang di-place. Cari nama di bawah supaya ID terisi.",
        Value = tostring(Config.farmPlaceId),
        Placeholder = "ID",
        Callback = function(text)
            local value = tonumber(text)
            if value and value > 0 and ItemName(value) ~= "?" then
                Config.farmPlaceId = value
                SaveConfig()
                Notify("Block: " .. ItemName(value) .. " (ID " .. value .. ")")
            elseif tonumber(text) ~= 0 then
                Notify("ID tidak ada di database item.")
            end
        end,
    })

    Tab:Space()
    Tab:Section({ Title = "Pola Place (Grid 5x5)" })

    local gridPreviewPara = Tab:Paragraph({
        Title = "Peta Grid 5x5 ([P] = Kamu, [ON] = Aktif)",
        Desc = GridSummaryText(),
    })

    local function RefreshGridPreview()
        SetElementText(gridPreviewPara, "Peta Grid 5x5 ([P] = Kamu, [ON] = Aktif)", GridSummaryText())
    end

    for dy = -2, 2 do
        local rowGroup = Tab:Group({})
        for dx = -2, 2 do
            local key = dx .. "," .. dy
            if dx == 0 and dy == 0 then
                rowGroup:Button({
                    Title = "KAMU",
                    Justify = "Center",
                    Callback = function()
                        Notify("Ini posisi karakter kamu (0,0).")
                    end,
                })
            else
                rowGroup:Button({
                    Title = string.format("(%d,%d)", dx, dy),
                    Justify = "Center",
                    Callback = function()
                        Config.farmGrid[key] = (not Config.farmGrid[key]) or nil
                        SaveConfig()
                        RefreshGridPreview()
                        Notify(string.format("Grid (%d,%d): %s", dx, dy, Config.farmGrid[key] and "AKTIF" or "MATI"))
                    end,
                })
            end
            if dx < 2 then
                rowGroup:Space()
            end
        end
    end

    Tab:Space()

    Tab:Button({
        Title = "Kosongkan Semua Kotak Grid",
        Color = Color3.fromHex("#ff4830"),
        Justify = "Center",
        Callback = function()
            Config.farmGrid = {}
            SaveConfig()
            RefreshGridPreview()
            Notify("Semua kotak grid dikosongkan.")
        end,
    })

    Tab:Space()

    Tab:Toggle({
        Title = "Ambil Item Otomatis",
        Desc = "Setelah break, teleport ke item yang jatuh lalu kembali ke posisi farm.",
        Value = Config.farmTake,
        Callback = function(on)
            Config.farmTake = on
            SaveConfig()
        end,
    })

    Tab:Space()
    Tab:Section({ Title = "Database Pencarian Block" })

    local searchResultsMap = {}
    local searchDropdown

    Tab:Input({
        Title = "Cari Nama Block atau ID",
        Desc = "Ketik nama block lalu pilih dari dropdown di bawah",
        Placeholder = "Contoh: dirt, rock, 2...",
        Callback = function(query)
            searchResultsMap = {}
            local values = {}
            if Trim(query) ~= "" then
                for _, entry in ipairs(SearchItems(query, 25)) do
                    local label = string.format("%s [ID %d]", entry.name, entry.id)
                    searchResultsMap[label] = entry
                    table.insert(values, label)
                end
            end
            if #values == 0 then
                values = { "Tidak ada hasil" }
            end
            if searchDropdown and searchDropdown.Refresh then
                pcall(function()
                    searchDropdown:Refresh(values)
                end)
            end
        end,
    })

    searchDropdown = Tab:Dropdown({
        Title = "Hasil Pencarian Block (Tap untuk Pakai)",
        Values = { "Ketik pencarian di atas..." },
        Callback = function(selected)
            local entry = searchResultsMap[selected]
            if entry then
                CopyId(entry.id)
                Config.farmPlaceId = entry.id
                SaveConfig()
                pcall(function()
                    if idInput and idInput.Set then
                        idInput:Set(tostring(entry.id))
                    end
                end)
                Notify("Block dipilih: " .. entry.name .. " (ID " .. entry.id .. ")")
            end
        end,
    })
end

-- 3. Tab: Auto Clear -------------------------------------------------
do
    local Tab = AutoSection:Tab({
        Title = "Auto Clear",
        Icon = "solar:cursor-square-bold",
        IconColor = Red,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.clear = Tab

    local clearStatusPara = Tab:Paragraph({
        Title = "Status Auto Clear World",
        Desc = "Memuat...",
    })

    task.spawn(function()
        while task.wait(0.4) do
            pcall(function()
                local st = Clear.stats
                SetElementText(
                    clearStatusPara,
                    string.format("Status: %s (Pass %d)", Clear.status, st.pass),
                    string.format(
                        "Target: %d | Sisa: %d | Di-skip (>5s): %d\nHancur: %d | Ambil: %d\nDelay Break: %.2f dtk | Jeda Langkah: %.2f dtk",
                        st.scanned, st.left, st.skipped, st.broken, st.picked,
                        Config.clearBreakDelay, Config.moveStepDelay
                    )
                )
            end)
        end
    end)

    AddFeatureToggle(Tab, "Auto Clear World (Legit + ModFly)", "Scan world, bergerak ke atas block terkecil (x, y-1), ModFly aktif agar tidak jatuh, skip > 5 detik.", "autoclear")

    Tab:Space()
    Tab:Section({ Title = "Pengaturan Clear" })

    Tab:Toggle({
        Title = "Aktifkan ModFly Saat Auto Clear",
        Desc = "Menyalakan mode ghost/fly otomatis agar player tidak terjatuh saat block atau background hancur.",
        Value = Config.clearModFly,
        Callback = function(on)
            Config.clearModFly = on
            SaveConfig()
            if Clear.on then
                SetAutoFly("autoclear", on)
            end
        end,
    })

    Tab:Input({
        Title = "Delay Break (detik)",
        Desc = "Jeda antar pukulan (0.03 - 5).",
        Value = tostring(Config.clearBreakDelay),
        Placeholder = "0.15",
        Callback = function(text)
            local value = tonumber(text)
            if value and value >= 0.03 and value <= 5 then
                Config.clearBreakDelay = value
                SaveConfig()
            else
                Notify("Isi angka 0.03 sampai 5.")
            end
        end,
    })

    Tab:Input({
        Title = "Delay Setelah Pindah Posisi (detik)",
        Desc = "Jeda setelah sampai di atas block (0.05 - 5).",
        Value = tostring(Config.clearTpDelay),
        Placeholder = "0.18",
        Callback = function(text)
            local value = tonumber(text)
            if value and value >= 0.05 and value <= 5 then
                Config.clearTpDelay = value
                SaveConfig()
            else
                Notify("Isi angka 0.05 sampai 5.")
            end
        end,
    })

    Tab:Toggle({
        Title = "Ambil Item Otomatis",
        Desc = "Ambil item drop setelah block pecah dan sapu sisa drop di akhir.",
        Value = Config.clearTake,
        Callback = function(on)
            Config.clearTake = on
            SaveConfig()
        end,
    })

    Tab:Space()

    Tab:Button({
        Title = "GrowScan Sekarang",
        Color = Color3.fromHex("#305dff"),
        Justify = "Center",
        Callback = function()
            task.spawn(function()
                local scan = ScanWorld()
                if not scan then
                    Notify("World tidak terbaca.")
                    return
                end
                local fg, bg, drops = 0, 0, 0
                for _, n in pairs(scan.fg) do fg += n end
                for _, n in pairs(scan.bg) do bg += n end
                for _, n in pairs(scan.drops) do drops += n end
                Notify(string.format("GrowScan: %d fg, %d bg, %d item drop (world %dx%d)", fg, bg, drops, scan.w, scan.h))
            end)
        end,
    })
end

-- 4. Tab: Auto Harvest -----------------------------------------------
do
    local Tab = AutoSection:Tab({
        Title = "Auto Harvest",
        Icon = "solar:check-square-bold",
        IconColor = Green,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.harvest = Tab

    local harvestStatusPara = Tab:Paragraph({
        Title = "Status Auto Harvest",
        Desc = "Memuat...",
    })

    task.spawn(function()
        while task.wait(0.4) do
            pcall(function()
                local st = Harvest.stats
                SetElementText(
                    harvestStatusPara,
                    "Status: " .. Harvest.status,
                    string.format(
                        "Total Pohon: %d | Siap Panen: %d\nDipanen: %d | Di-skip (Belum Siap): %d | Drop Diambil: %d",
                        st.totalTrees, st.ready, st.harvested, st.skipped, st.picked
                    )
                )
            end)
        end
    end)

    AddFeatureToggle(Tab, "Auto Harvest Pohon", "Scan world, cari pohon siap panen (ripe), gerak ke pohon & pukul sampai habis.", "autoharvest")

    Tab:Space()
    Tab:Section({ Title = "Pengaturan Auto Harvest" })

    Tab:Toggle({
        Title = "Aktifkan ModFly Saat Harvest",
        Desc = "Menjaga karakter tidak terjatuh saat berpindah antar barisan pohon.",
        Value = Config.harvestModFly,
        Callback = function(on)
            Config.harvestModFly = on
            SaveConfig()
            if Harvest.on then
                SetAutoFly("autoharvest", on)
            end
        end,
    })

    Tab:Toggle({
        Title = "Ambil Drop Panen Otomatis",
        Desc = "Mengambil buah/block & seed yang jatuh setelah pohon dipukul.",
        Value = Config.harvestTake,
        Callback = function(on)
            Config.harvestTake = on
            SaveConfig()
        end,
    })

    Tab:Input({
        Title = "Delay Pukulan Harvest (detik)",
        Desc = "Jeda antar pukulan saat memanen pohon (0.05 - 5).",
        Value = tostring(Config.harvestDelay),
        Placeholder = "0.20",
        Callback = function(text)
            local value = tonumber(text)
            if value and value >= 0.05 and value <= 5 then
                Config.harvestDelay = value
                SaveConfig()
            else
                Notify("Isi angka 0.05 sampai 5.")
            end
        end,
    })

    Tab:Input({
        Title = "Delay Pindah Pohon (detik)",
        Desc = "Jeda setelah sampai di pohon sebelum memukul (0.05 - 5).",
        Value = tostring(Config.harvestTpDelay),
        Placeholder = "0.18",
        Callback = function(text)
            local value = tonumber(text)
            if value and value >= 0.05 and value <= 5 then
                Config.harvestTpDelay = value
                SaveConfig()
            else
                Notify("Isi angka 0.05 sampai 5.")
            end
        end,
    })

    Tab:Paragraph({
        Title = "Alur Auto Harvest",
        Desc = "1. Scan seluruh world & cari objek pohon.\n2. Cek apakah pohon sudah siap harvest (.ripe == true / waktu tumbuh terpenuhi).\n3. Jika siap harvest, bergerak ke pohon dan pukul.\n4. Jika belum siap harvest, skip ke pohon berikutnya hingga seluruh pohon siap panen habis.",
    })
end

-- 5. Tab: Click TP & Kecepatan Gerak ---------------------------------
do
    local Tab = AutoSection:Tab({
        Title = "Click TP",
        Icon = "solar:square-transfer-horizontal-bold",
        IconColor = Blue,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.nav = Tab

    local navStatusPara = Tab:Paragraph({
        Title = "Status Navigasi / Pathfinding",
        Desc = "Terakhir: -",
    })

    task.spawn(function()
        while task.wait(0.4) do
            pcall(function()
                SetElementText(navStatusPara, "Status Navigasi / Pathfinding", "Terakhir: " .. tostring(Nav.last))
            end)
        end
    end)

    AddFeatureToggle(Tab, "Click TP", "Klik mana saja, karakter menyusuri path ke sana.", "clicktp")

    Tab:Toggle({
        Title = "Wajib Tahan Shift (PC)",
        Desc = "Click TP hanya jalan kalau Shift ditahan, supaya tidak ikut memukul block.",
        Value = Config.clickTpShift,
        Callback = function(on)
            Config.clickTpShift = on
            SaveConfig()
        end,
    })

    Tab:Space()
    Tab:Section({ Title = "Mode & Kecepatan Gerak (Click TP, Auto Clear, Auto Harvest)" })

    local MODE_NAMES = { walk = "Jalan (walk)", fly = "Terbang (fly)", mix = "Campur (mix)" }
    local modePara = Tab:Paragraph({
        Title = "Mode Gerak Aktif",
        Desc = MODE_NAMES[Config.moveMode] or "Campur (mix)",
    })

    local function SetMoveMode(mode)
        Config.moveMode = mode
        SaveConfig()
        SetElementText(modePara, "Mode Gerak Aktif", MODE_NAMES[mode] or mode)
        Notify("Mode gerak: " .. (MODE_NAMES[mode] or mode))
    end

    Tab:Dropdown({
        Title = "Pilih Mode Gerak",
        Values = { "walk", "fly", "mix" },
        Value = Config.moveMode,
        Callback = function(val)
            if type(val) == "string" then
                SetMoveMode(val)
            end
        end,
    })

    Tab:Input({
        Title = "Jeda Langkah per Tile (detik)",
        Desc = "Default 0.07 dtk/tile agar aman & tidak di-rollback server. Naikkan (mis. 0.09) jika masih kena rollback.",
        Value = tostring(Config.moveStepDelay),
        Placeholder = "0.07",
        Callback = function(text)
            local val = tonumber(text)
            if val and val >= 0.01 and val <= 1 then
                Config.moveStepDelay = val
                SaveConfig()
                Notify(string.format("Jeda langkah: %.2f dtk/tile", val))
            else
                Notify("Isi angka 0.01 sampai 1.0")
            end
        end,
    })

    Tab:Slider({
        Title = "Tile per Langkah (Nav Speed)",
        Desc = "Disarankan 1 agar server tidak membalikkan posisi player.",
        IsTooltip = true,
        Step = 1,
        Value = {
            Min = 1,
            Max = 6,
            Default = math.clamp(tonumber(Config.navSpeed) or 1, 1, 6),
        },
        Callback = function(value)
            Config.navSpeed = math.clamp(math.floor(tonumber(value) or 1), 1, 6)
            SaveConfig()
        end,
    })
end

-- 6. Tab: Auto Quest -------------------------------------------------
do
    local Tab = AutoSection:Tab({
        Title = "Auto Quest",
        Icon = "solar:file-text-bold",
        IconColor = Purple,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.quest = Tab

    local questPara = Tab:Paragraph({
        Title = "Status Auto Quest",
        Desc = "Status: " .. questStatus,
    })

    task.spawn(function()
        while task.wait(0.5) do
            pcall(function()
                SetElementText(questPara, "Status Auto Quest", "Status: " .. tostring(questStatus))
            end)
        end
    end)

    AddFeatureToggle(Tab, "Auto Quest", "Claim reward lalu kerjakan quest break/place lewat Auto Farm.", "autoquest")

    Tab:Space()

    Tab:Button({
        Title = "Baca Quest Sekarang (Scan)",
        Color = Color3.fromHex("#305dff"),
        Justify = "Center",
        Callback = function()
            task.spawn(QuestReport)
        end,
    })

    Tab:Paragraph({
        Title = "Catatan Auto Quest",
        Desc = "Syarat: block untuk quest harus ada di inventory. Quest yang tidak dikenali dilewati. Kalau quest tidak terbaca, tekan tombol Baca Quest di atas.",
    })
end

-- 7. Tab: GrowScan ---------------------------------------------------
do
    local Tab = WorldSection:Tab({
        Title = "GrowScan",
        Icon = "solar:info-square-bold",
        IconColor = Green,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.scan = Tab

    Tab:Button({
        Title = "Buka GrowScan Bawaan Game",
        Color = Color3.fromHex("#305dff"),
        Justify = "Center",
        Callback = function()
            if not OpenNativeGrowScan() then
                Notify("GrowScan bawaan game tidak tersedia, pakai Scan Isi World di bawah.")
            end
        end,
    })

    Tab:Space()

    local scanMap = {}
    local fgDropdown, bgDropdown, dropDropdown

    Tab:Button({
        Title = "Scan Isi World Sekarang",
        Justify = "Center",
        Callback = function()
            local data = ScanWorld()
            if not data then
                Notify("World belum terbaca.")
                return
            end
            scanMap = {}
            local function BuildList(counts, pickable)
                local entries = {}
                for id, count in pairs(counts) do
                    table.insert(entries, { id = id, count = count })
                end
                table.sort(entries, function(a, b)
                    if a.count ~= b.count then
                        return a.count > b.count
                    end
                    return a.id < b.id
                end)
                local out = {}
                for _, entry in ipairs(entries) do
                    local label = string.format("%s [ID %d] x%d", ItemName(entry.id), entry.id, entry.count)
                    scanMap[label] = { id = entry.id, pickable = pickable }
                    table.insert(out, label)
                end
                if #out == 0 then
                    out = { "Kosong" }
                end
                return out
            end

            local fgList = BuildList(data.fg, true)
            local bgList = BuildList(data.bg, true)
            local dropList = BuildList(data.drops, false)

            pcall(function()
                if fgDropdown and fgDropdown.Refresh then fgDropdown:Refresh(fgList) end
                if bgDropdown and bgDropdown.Refresh then bgDropdown:Refresh(bgList) end
                if dropDropdown and dropDropdown.Refresh then dropDropdown:Refresh(dropList) end
            end)
            Notify("Scan selesai! Pilih item dari dropdown di bawah.")
        end,
    })

    local function OnPickScan(selected)
        local item = scanMap[selected]
        if item then
            CopyId(item.id)
            if item.pickable then
                Config.farmPlaceId = item.id
                SaveConfig()
                Notify("Block Auto Farm: " .. ItemName(item.id) .. " (ID " .. item.id .. ")")
            else
                Notify(ItemName(item.id) .. " = ID " .. item.id .. " (disalin)")
            end
        end
    end

    fgDropdown = Tab:Dropdown({
        Title = "Foreground Blocks (Tap untuk Set Auto Farm)",
        Values = { "Tekan Scan Isi World dulu..." },
        Callback = OnPickScan,
    })

    bgDropdown = Tab:Dropdown({
        Title = "Background Blocks (Tap untuk Set Auto Farm)",
        Values = { "Tekan Scan Isi World dulu..." },
        Callback = OnPickScan,
    })

    dropDropdown = Tab:Dropdown({
        Title = "Item Tergeletak (Floating Drops)",
        Values = { "Tekan Scan Isi World dulu..." },
        Callback = OnPickScan,
    })
end

-- 8. Tab: Posisi -----------------------------------------------------
do
    local Tab = WorldSection:Tab({
        Title = "Posisi",
        Icon = "solar:hamburger-menu-bold",
        IconColor = Yellow,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.pos = Tab

    Tab:Paragraph({
        Title = "Panduan Posisi",
        Desc = "Berdiri di posisi pemain lalu tekan Set. Saat ada pemenang, tekan Teleport atau ketik command win1 / win2.",
    })

    for slot = 1, 2 do
        Tab:Space()
        Tab:Section({ Title = "Posisi " .. slot })

        local posPara = Tab:Paragraph({
            Title = "Pos " .. slot,
            Desc = "Belum diset",
        })

        local function RefreshPos()
            local pos = Config["pos" .. slot]
            if type(pos) == "table" and type(pos.x) == "number" then
                SetElementText(
                    posPara,
                    "Pos " .. slot .. " Tersimpan",
                    string.format("Tile %d, %d - World: %s", pos.x, pos.y, (pos.world and pos.world ~= "") and pos.world or "-")
                )
            else
                SetElementText(posPara, "Pos " .. slot, "Belum diset")
            end
        end
        table.insert(hub.refreshers, RefreshPos)
        RefreshPos()

        local posGroup = Tab:Group({})
        posGroup:Button({
            Title = "Set Pos " .. slot .. " di Sini",
            Justify = "Center",
            Callback = function()
                SetPos(slot)
                RefreshHub()
            end,
        })
        posGroup:Space()
        posGroup:Button({
            Title = "Teleport (win" .. slot .. ")",
            Justify = "Center",
            Callback = function()
                task.spawn(GoToPos, slot)
            end,
        })
    end
end

-- 9. Tab: Visual Item ------------------------------------------------
do
    local Tab = WorldSection:Tab({
        Title = "Visual",
        Icon = "solar:password-minimalistic-input-bold",
        IconColor = Purple,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.visual = Tab

    Tab:Paragraph({
        Title = "Visual Item (Lokal)",
        Desc = "Hanya tampilan lokal. Pilih kategori atau cari nama item, lalu pilih dari daftar untuk memakai/melepas.",
    })

    local activeFilter = "Semua"
    local searchQuery = ""
    local wearableMap = {}
    local wearableDropdown

    local function RebuildWearables()
        local list = GetWearables()
        if not list then
            return
        end
        wearableMap = {}
        local values = {}
        local q = Trim(searchQuery):lower()
        for _, entry in ipairs(list) do
            local matchFilter = (activeFilter == "Semua") or (table.find(entry.tags, activeFilter) ~= nil)
            local matchQuery = (q == "") or (entry.lower:find(q, 1, true) ~= nil)
            if matchFilter and matchQuery then
                local tagStr = #entry.tags > 0 and (" [" .. table.concat(entry.tags, ",") .. "]") or ""
                local wornStr = IsVisualWorn(entry.id) and " (DIPAKAI)" or ""
                local label = string.format("%s (%s)%s%s #%d", entry.name, entry.slot, tagStr, wornStr, entry.id)
                wearableMap[label] = entry.id
                table.insert(values, label)
                if #values >= 80 then
                    break
                end
            end
        end
        if #values == 0 then
            values = { "Tidak ada item yang cocok" }
        end
        if wearableDropdown and wearableDropdown.Refresh then
            pcall(function()
                wearableDropdown:Refresh(values)
            end)
        end
    end

    Tab:Dropdown({
        Title = "Filter Kategori",
        Values = { "Semua", "Kuyang", "LegendBot", "Rayman" },
        Value = "Semua",
        Callback = function(val)
            activeFilter = val or "Semua"
            RebuildWearables()
        end,
    })

    Tab:Input({
        Title = "Cari Nama Item Visual",
        Placeholder = "Ketik nama item...",
        Callback = function(text)
            searchQuery = text or ""
            RebuildWearables()
        end,
    })

    wearableDropdown = Tab:Dropdown({
        Title = "Pilih Item Visual (Tap untuk Pakai/Lepas)",
        Values = { "Memuat daftar item..." },
        Callback = function(selected)
            local id = wearableMap[selected]
            if id then
                if ToggleVisual(id) then
                    Notify("Visual item diubah: ID " .. id)
                    RebuildWearables()
                end
            end
        end,
    })

    Tab:Space()

    Tab:Button({
        Title = "Kembalikan Semua Item Visual",
        Color = Color3.fromHex("#ff4830"),
        Justify = "Center",
        Callback = function()
            ResetVisuals()
            RebuildWearables()
        end,
    })

    task.defer(RebuildWearables)
end

-- 10. Tab: Sesi ------------------------------------------------------
do
    local Tab = SystemSection:Tab({
        Title = "Sesi",
        Icon = "solar:folder-with-files-bold",
        IconColor = Blue,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.session = Tab

    local sessionInfoPara = Tab:Paragraph({
        Title = "Informasi Sesi",
        Desc = "Memuat...",
    })

    local function RefreshSessionInfo()
        local active = {}
        for key, feature in pairs(Features) do
            if Config.session[key] then
                table.insert(active, feature.label)
            end
        end
        table.sort(active)
        local desc = table.concat({
            "World terakhir: " .. (Config.lastWorld ~= "" and Config.lastWorld or "-"),
            "Fitur tersimpan: " .. (#active > 0 and table.concat(active, ", ") or "-"),
            "Simpan file: " .. (writefile and "tersedia" or "TIDAK tersedia"),
            "Auto-reload: " .. (ReloadReady() and "siap" or "belum siap (simpan skrip di workspace / isi URL)"),
        }, "\n")
        SetElementText(sessionInfoPara, "Informasi Sesi", desc)
    end
    table.insert(hub.refreshers, RefreshSessionInfo)
    RefreshSessionInfo()

    Tab:Space()
    Tab:Section({ Title = "Otomatis" })

    Tab:Toggle({
        Title = "Pulihkan Fitur",
        Desc = "Nyalakan lagi fitur yang aktif sebelumnya saat skrip dimuat.",
        Value = Config.autoRestore,
        Callback = function(on)
            Config.autoRestore = on
            SaveConfig()
        end,
    })

    Tab:Toggle({
        Title = "Auto-Reload Skrip",
        Desc = "Jalankan ulang skrip setelah pindah world / rejoin.",
        Value = Config.autoReload,
        Callback = function(on)
            Config.autoReload = on
            SaveConfig()
            if on then
                QueueReload()
            end
            RefreshSessionInfo()
        end,
    })

    Tab:Toggle({
        Title = "Masuk World Terakhir",
        Desc = "Setelah buka Roblox, warp otomatis ke world terakhir.",
        Value = Config.autoWarp,
        Callback = function(on)
            Config.autoWarp = on
            SaveConfig()
        end,
    })

    Tab:Space()
    Tab:Section({ Title = "Sumber Skrip & Aksi" })

    Tab:Input({
        Title = "URL Skrip (Opsional)",
        Desc = "Dipakai auto-reload tanpa file lokal",
        Value = Config.scriptUrl,
        Placeholder = "https://...",
        Callback = function(text)
            Config.scriptUrl = Trim(text)
            SaveConfig()
            QueueReload()
            RefreshSessionInfo()
        end,
    })

    Tab:Button({
        Title = "Simpan Sesi Sekarang",
        Color = Color3.fromHex("#305dff"),
        Justify = "Center",
        Callback = function()
            SaveSessionNow()
            Notify("Sesi disimpan.")
            RefreshSessionInfo()
        end,
    })

    Tab:Space()

    Tab:Button({
        Title = "Pasang Auto-Execute (autoexec)",
        Justify = "Center",
        Callback = InstallAutoexec,
    })

    Tab:Space()

    Tab:Button({
        Title = "Reset Sesi",
        Color = Color3.fromHex("#ff4830"),
        Justify = "Center",
        Callback = function()
            Config.session = {}
            Config.lastWorld = ""
            SaveConfig()
            Notify("Sesi direset.")
            RefreshSessionInfo()
        end,
    })
end

-- 11. Tab: Setelan & 12. Tab: Bantuan --------------------------------
local RebuildHelp
do
    local SettingsTab = SystemSection:Tab({
        Title = "Setelan",
        Icon = "solar:check-square-bold",
        IconColor = Grey,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.settings = SettingsTab

    SettingsTab:Section({ Title = "Command" })

    SettingsTab:Input({
        Title = "Prefix Command",
        Desc = "Kosong = tanpa prefix. /settingsgb dan /sgb selalu aktif.",
        Value = Config.prefix,
        Placeholder = "/",
        Callback = function(text)
            Config.prefix = Trim(text)
            SaveConfig()
            Notify(Config.prefix == "" and "Prefix dikosongkan." or ("Prefix: " .. Config.prefix))
            if RebuildHelp then
                RebuildHelp()
            end
        end,
    })

    SettingsTab:Input({
        Title = "ID Item Drop",
        Desc = "Dipakai oleh command wld / wd (default 242 = WL)",
        Value = tostring(Config.dropId),
        Placeholder = "242",
        Callback = function(text)
            local value = tonumber(text)
            if value and value >= 1 and value == math.floor(value) then
                Config.dropId = value
                SaveConfig()
                Notify("ID drop: " .. value)
            else
                Notify("ID tidak valid!")
            end
        end,
    })

    SettingsTab:Input({
        Title = "Auto-Drop saat Win",
        Desc = "Jumlah WL otomatis saat win1/win2 (0 = mati)",
        Value = tostring(Config.winDrop),
        Placeholder = "0",
        Callback = function(text)
            local value = tonumber(text)
            if value and value >= 0 and value <= MAX_AMOUNT and value == math.floor(value) then
                Config.winDrop = value
                SaveConfig()
                Notify(value == 0 and "Auto-drop dimatikan." or ("Auto-drop win: " .. value))
            else
                Notify("Isi angka 0-" .. MAX_AMOUNT .. "!")
            end
        end,
    })

    SettingsTab:Space()
    SettingsTab:Section({ Title = "Parameter Fitur" })

    SettingsTab:Slider({
        Title = "Jangkauan Longhand (Tile Tambahan)",
        Step = 1,
        IsTooltip = true,
        Value = {
            Min = 1,
            Max = 20,
            Default = math.clamp(tonumber(Config.longhandRange) or 3, 1, 20),
        },
        Callback = function(value)
            Config.longhandRange = value
            SaveConfig()
            if longhandOn then
                ApplyLonghand()
            end
        end,
    })

    SettingsTab:Input({
        Title = "Blink Minimum (detik)",
        Desc = "Rentang 0.05 - 10 detik",
        Value = tostring(Config.blinkMin),
        Placeholder = "0.2",
        Callback = function(text)
            local value = tonumber(text)
            if value and value >= 0.05 and value <= 10 then
                Config.blinkMin = value
                SaveConfig()
            else
                Notify("Isi angka 0.05-10!")
            end
        end,
    })

    SettingsTab:Input({
        Title = "Blink Maksimum (detik)",
        Desc = "Rentang 0.05 - 10 detik",
        Value = tostring(Config.blinkMax),
        Placeholder = "0.5",
        Callback = function(text)
            local value = tonumber(text)
            if value and value >= 0.05 and value <= 10 then
                Config.blinkMax = value
                SaveConfig()
            else
                Notify("Isi angka 0.05-10!")
            end
        end,
    })

    SettingsTab:Space()
    SettingsTab:Section({ Title = "Antarmuka" })

    SettingsTab:Keybind({
        Title = "Keybind Buka/Tutup UI",
        Desc = "Tombol keyboard untuk toggle ANCH Hub",
        Value = "RightControl",
        Callback = function(v)
            pcall(function()
                Window:SetToggleKey(Enum.KeyCode[v])
            end)
        end,
    })

    SettingsTab:Button({
        Title = "Destroy Window",
        Color = Color3.fromHex("#ff4830"),
        Icon = "shredder",
        Justify = "Center",
        Callback = function()
            Window:Destroy()
        end,
    })
end

do
    local HelpTab = SystemSection:Tab({
        Title = "Bantuan",
        Icon = "solar:info-square-bold",
        IconColor = Purple,
        IconShape = "Square",
        Border = true,
    })
    hub.tabs.help = HelpTab

    local function HelpText()
        local p = Config.prefix
        local lines = {
            p .. "wld <jumlah> | " .. p .. "wd  —  Drop World Lock",
            p .. "tp <world> | " .. p .. "warp  —  Pindah ke world lain",
            p .. "pos1 | " .. p .. "pos2  —  Simpan posisi sekarang",
            p .. "win1 | " .. p .. "w1 [jumlah]  —  Teleport ke Pos 1 (+opsional drop WL)",
            p .. "win2 | " .. p .. "w2 [jumlah]  —  Teleport ke Pos 2 (+opsional drop WL)",
            p .. "pos  —  Lihat posisi sekarang & pos tersimpan",
            p .. "rejoin | " .. p .. "rj  —  Masuk ulang ke world ini",
            p .. "noclip [on/off]  —  Tembus blok & terbang (ModFly)",
            p .. "unlimitedjump | " .. p .. "uj  —  Lompat udara tanpa batas",
            p .. "blink [on/off]  —  Warna skin berganti otomatis",
            p .. "longhand [n] | " .. p .. "lh  —  Jangkauan punch & build lebih jauh",
            p .. "visualitem | " .. p .. "vi  —  Buka tab Visual Item",
            p .. "settingsgb | " .. p .. "sgb  —  Buka tab Setelan",
            p .. "afk  —  Anti-AFK (tidak kena kick idle)",
            p .. "autorejoin | " .. p .. "arj  —  Rejoin otomatis kalau terputus",
            p .. "session | " .. p .. "sesi  —  Buka tab Sesi",
            p .. "af | " .. p .. "autofarm [on/off]  —  Auto Farm",
            p .. "ac | " .. p .. "autoclear [on/off]  —  Auto Clear World (Legit + ModFly)",
            p .. "ah | " .. p .. "autoharvest [on/off]  —  Auto Harvest Pohon",
            p .. "ctp | " .. p .. "clicktp [on/off]  —  Click TP (Pathfinding)",
            p .. "move | " .. p .. "mv <walk/fly/mix>  —  Ubah mode gerak",
            p .. "aq | " .. p .. "autoquest [on/off/scan]  —  Auto Quest",
            p .. "gs | " .. p .. "growscan  —  Buka GrowScan",
            p .. "god [on/off]  —  God Mode (kebal hazard)",
            p .. "blockid <nama> | " .. p .. "bid  —  Cari ID block dari nama",
            p .. "hpx  —  Daftar perintah ANCH Hub",
        }
        return table.concat(lines, "\n")
    end

    local helpPara = HelpTab:Paragraph({
        Title = "Daftar Perintah Chat ANCH Hub",
        Desc = HelpText(),
    })

    RebuildHelp = function()
        SetElementText(helpPara, "Daftar Perintah Chat ANCH Hub", HelpText())
    end
end

local function OpenHub(tabId)
    hub.active = tabId or "features"
    local targetTab = hub.tabs[hub.active]
    if targetTab then
        pcall(function()
            if targetTab.Select then
                targetTab:Select()
            end
        end)
    end
    pcall(function()
        if Window.Open then
            Window:Open()
        end
    end)
end

local function ToggleHub(tabId)
    OpenHub(tabId)
end

----------------------------------------------------------------------
-- PERINTAH TAMBAHAN: GrowScan & pencarian ID
----------------------------------------------------------------------
local function OpenGrowScan()
    if not OpenNativeGrowScan() then
        ToggleHub("scan")
    end
end

local function ShowItemIds(query)
    if Trim(query) == "" then
        Notify("Contoh: " .. Config.prefix .. "blockid dirt")
        return
    end
    local found = SearchItems(query, 5)
    if #found == 0 then
        Notify("Block '" .. query .. "' tidak ditemukan.")
        return
    end
    local parts = {}
    for _, entry in ipairs(found) do
        table.insert(parts, entry.name .. " = " .. entry.id)
    end
    Notify(table.concat(parts, " | "))
end

----------------------------------------------------------------------
-- COMMAND HANDLER
----------------------------------------------------------------------
local function ParseCommand(text)
    text = Trim(text)
    if text == "" then
        return nil
    end

    local prefix = Config.prefix
    local bodyText

    if prefix == "" then
        bodyText = text
    elseif text:sub(1, #prefix) == prefix then
        bodyText = text:sub(#prefix + 1)
    elseif text:sub(1, 1) == "/" then
        local word = text:sub(2):lower()
        if word == "settingsgb" or word == "sgb" then
            bodyText = text:sub(2)
        end
    end

    if not bodyText then
        return nil
    end

    local command, args = bodyText:match("^(%S+)%s*(.-)%s*$")
    if not command then
        return nil
    end
    return command:lower(), (args or ""):lower()
end

local function WantedState(args, current)
    if args == "on" then
        return true
    elseif args == "off" then
        return false
    end
    return not current
end

local function HandleMessage(text)
    local command, args = ParseCommand(text)
    if not command then
        return false
    end

    if command == "wld" or command == "wd" then
        local amount = tonumber(args:match("^(%d+)$"))
        if not amount or amount < 1 or amount > MAX_AMOUNT then
            Notify("Jumlah tidak valid! Contoh: " .. Config.prefix .. command .. " 100")
        else
            task.spawn(DropWorldLock, amount)
        end
        return true

    elseif command == "tp" or command == "warp" then
        task.spawn(WarpToWorld, args)
        return true

    elseif command == "pos1" or command == "pos2" then
        SetPos(tonumber(command:sub(4)))
        RefreshHub()
        return true

    elseif command == "pos" then
        ShowPos()
        return true

    elseif command == "win1" or command == "w1" or command == "win2" or command == "w2" then
        local slot = tonumber(command:match("%d$"))
        local amount = tonumber(args:match("^(%d+)$"))
        if amount and (amount < 1 or amount > MAX_AMOUNT) then
            Notify("Jumlah tidak valid!")
        else
            task.spawn(GoToPos, slot, amount)
        end
        return true

    elseif command == "rejoin" or command == "rj" then
        task.spawn(Rejoin)
        return true

    elseif command == "noclip" then
        SetFeature("noclip", WantedState(args, noclipOn))
        return true

    elseif command == "unlimitedjump" or command == "uj" or command == "ujump" or command == "infjump" then
        SetFeature("ujump", WantedState(args, ujumpOn))
        return true

    elseif command == "afk" or command == "antiafk" then
        SetFeature("antiafk", WantedState(args, antiAfkOn))
        return true

    elseif command == "autorejoin" or command == "arj" then
        SetFeature("autorejoin", WantedState(args, arjOn))
        return true

    elseif command == "session" or command == "sesi" then
        ToggleHub("session")
        return true

    elseif command == "blink" then
        SetFeature("blink", WantedState(args, blinkOn))
        return true

    elseif command == "longhand" or command == "lh" then
        local value = tonumber(args)
        if value and value >= 1 and value <= 20 then
            Config.longhandRange = value
            SaveConfig()
            SetFeature("longhand", true)
        else
            SetFeature("longhand", WantedState(args, longhandOn))
        end
        return true

    elseif command == "visualitem" or command == "vi" then
        ToggleHub("visual")
        return true

    elseif command == "settingsgb" or command == "sgb" then
        ToggleHub("settings")
        return true

    elseif command == "autofarm" or command == "af" then
        if args == "on" or args == "start" then
            SetFeature("autofarm", true)
        elseif args == "off" or args == "stop" then
            SetFeature("autofarm", false)
        else
            ToggleHub("farm")
        end
        return true

    elseif command == "clicktp" or command == "ctp" then
        SetFeature("clicktp", WantedState(args, Nav.clickOn))
        return true

    elseif command == "move" or command == "mv" or command == "mode" then
        local m = (args or ""):lower()
        local map = { walk = "walk", jalan = "walk", fly = "fly", terbang = "fly", mix = "mix", campur = "mix" }
        if map[m] then
            Config.moveMode = map[m]
            SaveConfig()
            Notify("Mode gerak: " .. map[m])
        else
            Notify("Mode gerak sekarang: " .. tostring(Config.moveMode) .. ". Pakai: move walk | fly | mix")
        end
        return true

    elseif command == "autoclear" or command == "ac" or command == "clear" then
        if args == "on" or args == "start" then
            SetFeature("autoclear", true)
        elseif args == "off" or args == "stop" then
            SetFeature("autoclear", false)
        else
            ToggleHub("clear")
        end
        return true

    elseif command == "autoharvest" or command == "ah" or command == "harvest" then
        if args == "on" or args == "start" then
            SetFeature("autoharvest", true)
        elseif args == "off" or args == "stop" then
            SetFeature("autoharvest", false)
        else
            ToggleHub("harvest")
        end
        return true

    elseif command == "autoquest" or command == "aq" then
        if args == "scan" then
            task.spawn(QuestReport)
        else
            SetFeature("autoquest", WantedState(args, questOn))
        end
        return true

    elseif command == "growscan" or command == "gs" then
        task.spawn(OpenGrowScan)
        return true

    elseif command == "god" or command == "godmode" then
        SetFeature("god", WantedState(args, godOn))
        return true

    elseif command == "blockid" or command == "bid" then
        ShowItemIds(args)
        return true

    elseif command == "hpx" then
        ToggleHub("help")
        return true
    end

    return false
end

----------------------------------------------------------------------
-- DETEKSI CHAT
----------------------------------------------------------------------
local hooked = {}
local lastMessage = nil
local lastHandled = 0
local DEDUPE_WINDOW = 1.5

local function Process(text)
    if type(text) ~= "string" then
        return
    end

    local normalized = Trim(text):lower()
    if normalized == lastMessage and os.clock() - lastHandled < DEDUPE_WINDOW then
        return
    end

    if HandleMessage(Trim(text)) then
        lastMessage = normalized
        lastHandled = os.clock()
    end
end

local function HookTextBox(box)
    if hooked[box] or not box:IsA("TextBox") then
        return
    end
    local screenGui = box:FindFirstAncestorOfClass("ScreenGui")
    if screenGui and (screenGui.Name == "ANCHHubGB" or screenGui.Name:lower():find("windui", 1, true)) then
        return
    end
    hooked[box] = true

    local lastText = ""

    box:GetPropertyChangedSignal("Text"):Connect(function()
        if box.Text ~= "" then
            lastText = box.Text
        end
    end)

    box.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            local text = box.Text ~= "" and box.Text or lastText
            lastText = ""
            Process(text)
        end
    end)
end

for _, descendant in ipairs(PlayerGui:GetDescendants()) do
    HookTextBox(descendant)
end
PlayerGui.DescendantAdded:Connect(HookTextBox)

Player.Chatted:Connect(Process)

-- Auto-reload: antrekan skrip untuk server/world berikutnya
pcall(QueueReload)
Player.OnTeleport:Connect(function()
    SaveConfig()
    pcall(QueueReload)
end)

-- Catat world terakhir
task.spawn(function()
    while true do
        task.wait(2)
        local name = CurrentWorldName()
        if name ~= "" and name ~= Config.lastWorld then
            Config.lastWorld = name
            SaveConfig()
        end
    end
end)

task.spawn(RestoreSession)

if Config.autoReload and not ReloadReady() then
    task.delay(3, function()
        Notify("Auto-reload belum siap: simpan skrip sebagai " .. SCRIPT_FILE .. " di workspace atau isi URL di tab Sesi.")
    end)
end

if FindInventory() then
    Notify("ANCH HUB v9 loaded! Ketik " .. Config.prefix .. "hpx untuk daftar perintah.")
else
    Notify("Loaded, tapi inventory game belum ditemukan (cek executor).")
end
