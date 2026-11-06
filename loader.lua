--[[
    ANCH HUB | GrowBlox Official Loader (Key System)
]]

local API_BASE_URL = "https://anch-key-system.vercel.app/" -- Ganti dengan IP/Domain VPS kamu
local DISCORD_INVITE = "https://discord.gg/linkdiscordkamu"
local KEY_FILE = "ANCHHub_SavedKey.txt"

local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local RbxAnalyticsService = game:GetService("RbxAnalyticsService")
local Players = game:GetService("Players")

local function Trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Ambil HWID unik device pengguna
local function GetDeviceHWID()
    local estimators = {
        gethwid,
        get_hwid,
        function() return RbxAnalyticsService:GetClientId() end,
    }
    for _, fn in ipairs(estimators) do
        if type(fn) == "function" then
            local ok, res = pcall(fn)
            if ok and type(res) == "string" and #res > 4 then
                return Trim(res)
            end
        end
    end
    return "UID_" .. tostring(Players.LocalPlayer.UserId)
end

local HWID = GetDeviceHWID()

local function Notify(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title or "ANCH Hub Key System",
            Text = tostring(text),
            Duration = dur or 5,
        })
    end)
end

-- Fungsi Cek Key ke Server VPS Node.js
local function VerifyAndLoadScript(inputKey, onFailCallback)
    inputKey = Trim(inputKey)
    if inputKey == "" then
        if onFailCallback then onFailCallback("Masukkan Key terlebih dahulu!") end
        return false
    end

    local verifyUrl = string.format(
        "%s/api/verify?key=%s&hwid=%s",
        API_BASE_URL,
        HttpService:UrlEncode(inputKey),
        HttpService:UrlEncode(HWID)
    )

    local ok, response = pcall(function()
        return game:HttpGet(verifyUrl)
    end)

    if not ok or type(response) ~= "string" then
        local msg = "Gagal terhubung ke server Key ANCH Hub!"
        Notify("Koneksi Gagal", msg, 5)
        if onFailCallback then onFailCallback(msg) end
        return false
    end

    local decodeOk, data = pcall(function()
        return HttpService:JSONDecode(response)
    end)

    if not decodeOk or type(data) ~= "table" then
        local msg = "Respon server tidak valid!"
        if onFailCallback then onFailCallback(msg) end
        return false
    end

    if data.discordInvite and data.discordInvite ~= "" then
        DISCORD_INVITE = data.discordInvite
    end

    if not data.valid then
        local errReason = tostring(data.message or "Key tidak valid atau sudah Expired!")
        Notify("Verifikasi Gagal (" .. tostring(data.status or "ERROR") .. ")", errReason, 6)
        if onFailCallback then onFailCallback(errReason) end
        return false
    end

    -- Simpan Key yang valid agar ke depannya auto-login
    if writefile then
        pcall(writefile, KEY_FILE, inputKey)
    end

    Notify("Key Valid!", "Sisa Durasi: " .. tostring(data.remainingText) .. ". Memuat ANCH Hub...", 4)

    -- Ambil dan jalankan Skrip Utama dari endpoint /api/script
    local scriptUrl = string.format(
        "%s/api/script?key=%s&hwid=%s",
        API_BASE_URL,
        HttpService:UrlEncode(inputKey),
        HttpService:UrlEncode(HWID)
    )

    local okScript, scriptCode = pcall(function()
        return game:HttpGet(scriptUrl)
    end)

    if not okScript or type(scriptCode) ~= "string" or #scriptCode < 50 then
        local msg = "Gagal mengunduh skrip utama dari server!"
        Notify("Error", msg, 5)
        if onFailCallback then onFailCallback(msg) end
        return false
    end

    local fn, syntaxErr = loadstring(scriptCode)
    if not fn then
        Notify("Error Script", tostring(syntaxErr), 5)
        return false
    end

    task.spawn(fn)
    return true
end

-- 1. Coba Auto-Login jika sudah ada Key tersimpan di file
if isfile and readfile and isfile(KEY_FILE) then
    local okRead, savedKey = pcall(readfile, KEY_FILE)
    if okRead and Trim(savedKey) ~= "" then
        if VerifyAndLoadScript(Trim(savedKey), nil) then
            return -- Langsung masuk ke skrip utama tanpa buka UI Key!
        end
    end
end

-- 2. Jika belum ada Key atau Key Expired/Invalid, tampilkan UI Key System (WindUI)
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

local KeyWindow = WindUI:CreateWindow({
    Title = "ANCH Hub  |  Key Verification",
    Folder = "ANCHHub_KeySystem",
    Icon = "solar:key-bold-duotone",
    NewElements = true,
    HideSearchBar = true,
    Size = UDim2.fromOffset(480, 320),
    Topbar = {
        Height = 42,
        ButtonsType = "Mac",
    },
})

local KeyTab = KeyWindow:Tab({
    Title = "Key System",
    Icon = "solar:lock-password-bold",
    IconColor = Color3.fromHex("#10C550"),
    IconShape = "Square",
    Border = true,
})

local statusPara = KeyTab:Paragraph({
    Title = "Verifikasi Lisensi ANCH Hub",
    Desc = "Silakan masukkan Key kamu untuk membuka ANCH Hub.\nHWID Perangkat: " .. HWID,
})

local typedKey = ""
KeyTab:Input({
    Title = "Input Key ANCH Hub",
    Placeholder = "ANCH-XXXX-XXXX-XXXX",
    Callback = function(t)
        typedKey = Trim(t or "")
    end,
})

KeyTab:Button({
    Title = "Verifikasi & Buka Script",
    Color = Color3.fromHex("#10C550"),
    Justify = "Center",
    Callback = function()
        statusPara:SetTitle("Memeriksa Key...")
        statusPara:SetDesc("Menghubungi server lisensi ANCH Hub...")

        local success = VerifyAndLoadScript(typedKey, function(failMsg)
            statusPara:SetTitle("❌ Key Tidak Valid / Expired!")
            statusPara:SetDesc(failMsg .. "\n\nKlik tombol 'Join Discord' di bawah untuk mendapatkan Key baru.")
            WindUI:Notify({
                Title = "Akses Ditolak",
                Content = failMsg,
                Icon = "solar:shield-warning-bold",
                Duration = 5,
            })
        end)

        if success then
            pcall(function() KeyWindow:Destroy() end)
        end
    end,
})

KeyTab:Space()

KeyTab:Button({
    Title = "Join Discord (Salin Link Get Key)",
    Color = Color3.fromHex("#5865F2"),
    Justify = "Center",
    Callback = function()
        local copyFn = setclipboard or toclipboard
        if copyFn then
            pcall(copyFn, DISCORD_INVITE)
            WindUI:Notify({
                Title = "Link Discord Disalin!",
                Content = "Link Discord (" .. DISCORD_INVITE .. ") berhasil disalin ke clipboard. Buka browser/Discord untuk bergabung!",
                Icon = "solar:copy-bold",
                Duration = 5,
            })
        else
            Notify("Join Discord", "Link Discord: " .. DISCORD_INVITE, 6)
        end
    end,
})
