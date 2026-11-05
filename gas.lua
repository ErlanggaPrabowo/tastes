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
    farm
