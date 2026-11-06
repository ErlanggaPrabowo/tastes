--[[
    ANCH HUB | GrowBlox Official Loader (Key System - Single Request)
]]

local API_BASE_URL = "https://anch-key-system.vercel.app" -- Pastikan TANPA garis miring (/) di paling belakang
local DISCORD_INVITE = "https://discord.gg/linkdiscordkamu"
local KEY_FILE = "ANCHHub_SavedKey.txt"

local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local RbxAnalyticsService = game:GetService("RbxAnalyticsService")
local Players = game:GetService("Players")

local function Trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

API_BASE_URL = Trim(API_BASE_URL):gsub("/+$", "")

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
        local msg = "Gagal terhubung ke server Key ANCH Hub! Cek API_BASE_URL."
        Notify("Koneksi Gagal", msg, 5)
        if onFailCallback then onFailCallback(msg) end
        return false
    end

    local decodeOk, data = pcall(function()
        return HttpService:JSONDecode(response)
    end)

    if not decodeOk or type(data) ~= "table" then
        local msg = "Respon server bukan JSON valid!"
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

    -- Simpan Key yang valid untuk auto-login berikutnya
    if writefile then
        pcall(writefile, KEY_FILE, inputKey)
    end

    -- Ambil skrip langsung dari respon JSON /api/verify (1x Request)
    local scriptCode = data.script

    -- Cadangan jika server belum mengirim field data.script
    if type(scriptCode) ~= "string" or #scriptCode < 50 then
        if data.scriptError then
            Notify("Error Server", tostring(data.scriptError), 6)
            if onFailCallback then onFailCallback(tostring(data.scriptError)) end
            return false
        end

        local scriptUrl = string.format(
            "%s/api/script?key=%s&hwid=%s",
            API_BASE_URL,
            HttpService:UrlEncode(inputKey),
            HttpService:UrlEncode(HWID)
        )
        local okScript, resScript = pcall(function()
            return game:HttpGet(scriptUrl)
        end)
        if okScript and type(resScript) == "string" then
            if resScript:sub(1, 3) == "-- " and #resScript < 150 then
                Notify("Server Info", resScript, 6)
                if onFailCallback then onFailCallback(resScript) end
                return false
            end
            scriptCode = resScript
        end
    end

    if type(scriptCode) ~= "string" or #scriptCode < 50 then
        local msg = "File ANCHHub.lua belum ditemukan di server Vercel kamu!"
        Notify("Gagal Memuat Skrip", msg, 6)
        if onFailCallback then onFailCallback(msg) end
        return false
    end

    Notify("Key Valid!", "Sisa Durasi: " .. tostring(data.remainingText) .. ". Memuat ANCH Hub...", 4)

    local fn, syntaxErr = loadstring(scriptCode)
    if not fn then
        Notify("Syntax Error di ANCHHub.lua", tostring(syntaxErr), 6)
        if onFailCallback then onFailCallback("Syntax Error: " .. tostring(syntaxErr)) end
        return false
    end

    task.spawn(fn)
    return true
end

-- 1. Cek Auto-Login dari file Key tersimpan
if isfile and readfile and isfile(KEY_FILE) then
    local okRead, savedKey = pcall(readfile, KEY_FILE)
    if okRead and Trim(savedKey) ~= "" then
        if VerifyAndLoadScript(Trim(savedKey), nil) then
            return
        end
    end
end

-- 2. Tampilkan Window Key System (WindUI) jika belum punya key / tidak valid
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
            statusPara:SetTitle("Verifikasi Gagal!")
            statusPara:SetDesc(failMsg .. "\n\nKlik tombol 'Join Discord' di bawah untuk mendapatkan Key baru.")
            WindUI:Notify({
                Title = "Gagal Memuat",
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
                Content = "Link Discord (" .. DISCORD_INVITE .. ") berhasil disalin ke clipboard!",
                Icon = "solar:copy-bold",
                Duration = 5,
            })
        else
            Notify("Join Discord", "Link Discord: " .. DISCORD_INVITE, 6)
        end
    end,
})
