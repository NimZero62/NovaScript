-- validate.lua
-- Colle ça au début de ton script chargé via loadstring.
-- Remplace SERVER_URL par l'URL du tunnel Cloudflare (ou localhost pour les tests locaux).

local SERVER_URL = "https://TON-TUNNEL.trycloudflare.com/api/validate"

local function checkKey(key)
    local ok, result = pcall(function()
        -- syn.request / http.request selon ton executor
        local res = (syn and syn.request or http and http.request or request)({
            Url    = SERVER_URL .. "?key=" .. key,
            Method = "GET",
        })
        return game:GetService("HttpService"):JSONDecode(res.Body)
    end)

    if not ok then
        return false, "Erreur réseau : " .. tostring(result)
    end

    if result.valid then
        return true, result
    else
        return false, result.reason or "Clé invalide"
    end
end

-- ── Key prompt ──────────────────────────────────────────────────────────────

local key = nil

-- Essayer de récupérer une clé sauvegardée (si l'executor supporte writefile)
pcall(function()
    local saved = readfile("keysystem_key.txt")
    if saved and #saved > 5 then
        key = saved:match("^%s*(.-)%s*$")  -- trim
    end
end)

if not key then
    -- Demander la clé via une InputBox (UI basique)
    local ScreenGui    = Instance.new("ScreenGui")
    local Frame        = Instance.new("Frame")
    local Title        = Instance.new("TextLabel")
    local Input        = Instance.new("TextBox")
    local SubmitBtn    = Instance.new("TextButton")
    local StatusLbl    = Instance.new("TextLabel")

    ScreenGui.Name           = "KeySystem"
    ScreenGui.ResetOnSpawn   = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    Frame.Size               = UDim2.new(0, 380, 0, 180)
    Frame.Position           = UDim2.new(0.5, -190, 0.5, -90)
    Frame.BackgroundColor3   = Color3.fromRGB(15, 15, 22)
    Frame.BorderSizePixel    = 0
    Frame.Parent             = ScreenGui

    Title.Size               = UDim2.new(1, -20, 0, 30)
    Title.Position           = UDim2.new(0, 10, 0, 10)
    Title.Text               = "KeySystem — Entre ta clé de licence"
    Title.TextColor3         = Color3.fromRGB(232, 230, 255)
    Title.TextSize           = 13
    Title.Font               = Enum.Font.Code
    Title.TextXAlignment     = Enum.TextXAlignment.Left
    Title.BackgroundTransparency = 1
    Title.Parent             = Frame

    Input.Size               = UDim2.new(1, -20, 0, 36)
    Input.Position           = UDim2.new(0, 10, 0, 50)
    Input.PlaceholderText    = "KEY-XXXXX-XXXXX-XXXXX-XXXXX"
    Input.Text               = ""
    Input.TextColor3         = Color3.fromRGB(232, 230, 255)
    Input.PlaceholderColor3  = Color3.fromRGB(107, 104, 128)
    Input.BackgroundColor3   = Color3.fromRGB(28, 28, 40)
    Input.BorderSizePixel    = 0
    Input.TextSize           = 12
    Input.Font               = Enum.Font.Code
    Input.ClearTextOnFocus   = false
    Input.Parent             = Frame

    SubmitBtn.Size           = UDim2.new(1, -20, 0, 34)
    SubmitBtn.Position       = UDim2.new(0, 10, 0, 96)
    SubmitBtn.Text           = "Valider"
    SubmitBtn.TextColor3     = Color3.fromRGB(255, 255, 255)
    SubmitBtn.BackgroundColor3 = Color3.fromRGB(124, 111, 255)
    SubmitBtn.BorderSizePixel = 0
    SubmitBtn.TextSize       = 13
    SubmitBtn.Font           = Enum.Font.GothamBold
    SubmitBtn.Parent         = Frame

    StatusLbl.Size           = UDim2.new(1, -20, 0, 24)
    StatusLbl.Position       = UDim2.new(0, 10, 0, 140)
    StatusLbl.Text           = ""
    StatusLbl.TextColor3     = Color3.fromRGB(255, 92, 92)
    StatusLbl.TextSize       = 11
    StatusLbl.Font           = Enum.Font.Code
    StatusLbl.TextXAlignment = Enum.TextXAlignment.Left
    StatusLbl.BackgroundTransparency = 1
    StatusLbl.Parent         = Frame

    ScreenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

    -- Attente de la validation
    local validated = false

    SubmitBtn.MouseButton1Click:Connect(function()
        local inputKey = Input.Text:match("^%s*(.-)%s*$")
        if #inputKey < 5 then
            StatusLbl.Text = "Clé trop courte."
            return
        end

        SubmitBtn.Text = "Vérification..."
        StatusLbl.Text = ""

        local valid, data = checkKey(inputKey)

        if valid then
            key = inputKey
            -- Sauvegarder pour la prochaine fois
            pcall(function() writefile("keysystem_key.txt", key) end)
            StatusLbl.TextColor3 = Color3.fromRGB(77, 255, 180)
            StatusLbl.Text       = "Clé valide. Chargement..."
            task.wait(0.8)
            ScreenGui:Destroy()
            validated = true
        else
            SubmitBtn.Text       = "Valider"
            StatusLbl.TextColor3 = Color3.fromRGB(255, 92, 92)
            StatusLbl.Text       = "Clé invalide : " .. tostring(data)
        end
    end)

    -- Bloquer l'exécution jusqu'à validation
    repeat task.wait(0.1) until validated
else
    -- Clé sauvegardée — vérifier silencieusement
    local valid, data = checkKey(key)
    if not valid then
        -- Clé expirée ou révoquée — supprimer et redemander au prochain lancement
        pcall(function() writefile("keysystem_key.txt", "") end)
        error("[KeySystem] Clé invalide ou expirée. Relance le script pour entrer une nouvelle clé.")
    end
end

-- ── Ton script continue ici ─────────────────────────────────────────────────
-- La clé a été validée avec succès.
print("[KeySystem] Accès autorisé.")
