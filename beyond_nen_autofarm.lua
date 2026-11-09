--[[
    Beyond Nen - Ultimate Hub v5 (Combat, Auto Farm, Nen Mastery & Chests/Loot)
    Built with WindUI Library
    Author: cook45
]]

-- Fix: Security capability patch for CoreGui / gethui (Fixes "lacking capability Plugin")
if setidentity then
    pcall(setidentity, 8)
elseif setthreadidentity then
    pcall(setthreadidentity, 8)
elseif setthreadcontext then
    pcall(setthreadcontext, 8)
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Route gethui to PlayerGui to bypass CoreGui permission/capability isolation
if getgenv then
    getgenv().gethui = function()
        return PlayerGui
    end
end

_G.BeyondNenInstanceId = (_G.BeyondNenInstanceId or 0) + 1
local myInstanceId = _G.BeyondNenInstanceId

if _G.BeyondNenConnections then
    for _, conn in ipairs(_G.BeyondNenConnections) do
        pcall(function() conn:Disconnect() end)
    end
end
_G.BeyondNenConnections = {}

local function RegisterConnection(conn)
    if conn then
        table.insert(_G.BeyondNenConnections, conn)
    end
    return conn
end

-- Destroy existing WindUI instances to prevent duplicates
for _, c in ipairs(PlayerGui:GetChildren()) do
    if string.find(c.Name, "WindUI") then
        pcall(function() c:Destroy() end)
    end
end
pcall(function()
    local core = game:GetService("CoreGui")
    for _, c in ipairs(core:GetChildren()) do
        if string.find(c.Name, "WindUI") then
            c:Destroy()
        end
    end
end)

local WindUI
local windUrls = {
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua",
    "https://cdn.jsdelivr.net/gh/Footagesus/WindUI@main/dist/main.lua",
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
}
for _, url in ipairs(windUrls) do
    local s, src = pcall(function() return game:HttpGet(url) end)
    if s and src and not src:find("<html") and #src > 1000 then
        local lf = loadstring(src)
        if lf then
            local ok, lib = pcall(lf)
            if ok and lib then
                WindUI = lib
                break
            end
        end
    end
end
assert(WindUI, "Failed to load WindUI library from all mirror sources!")

-- Services
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- Knit Services & Controllers
local knit = require(ReplicatedStorage.Packages.knit)
local MeditationService = knit.GetService("MeditationService")
local NenService = knit.GetService("NenService")
local NenMasteryService = knit.GetService("NenMasteryService")
local MerchantService = knit.GetService("MerchantService")
local ChestService = knit.GetService("ChestService")
local InventoryService = knit.GetService("InventoryService")
local FishingService = knit.GetService("FishingService")
local MaterialService = knit.GetService("MaterialService")
local QuestsService = pcall(function() return knit.GetService("QuestsService") end) and knit.GetService("QuestsService") or nil
local MilestonesService = pcall(function() return knit.GetService("MilestonesService") end) and knit.GetService("MilestonesService") or nil
local StorylineBoardService = pcall(function() return knit.GetService("StorylineBoardService") end) and knit.GetService("StorylineBoardService") or nil
local NotificationService = pcall(function() return knit.GetService("NotificationService") end) and knit.GetService("NotificationService") or nil
local CampfireService = pcall(function() return knit.GetService("CampfireService") end) and knit.GetService("CampfireService") or nil
local MovementService = pcall(function() return knit.GetService("MovementService") end) and knit.GetService("MovementService") or nil
local StatsService = pcall(function() return knit.GetService("StatsService") end) and knit.GetService("StatsService") or nil
local TalentService = pcall(function() return knit.GetService("TalentService") end) and knit.GetService("TalentService") or nil
local CodeService = pcall(function() return knit.GetService("CodeService") end) and knit.GetService("CodeService") or nil
local DeathService = pcall(function() return knit.GetService("DeathService") end) and knit.GetService("DeathService") or nil
local CombatModule = require(LocalPlayer.PlayerScripts.Client.Controllers.CombatController.Combat)
local CombatController = pcall(function() return knit.GetController("CombatController") end) and knit.GetController("CombatController") or nil
local AnimationMarkers = pcall(function() return require(ReplicatedStorage.SecondaryShared.AnimationMarkers) end) and require(ReplicatedStorage.SecondaryShared.AnimationMarkers) or nil
local SecondaryRemotes = ReplicatedStorage:FindFirstChild("SecondaryRemotes")
local CombatRemotes = SecondaryRemotes and SecondaryRemotes:FindFirstChild("Combat")
local RemoteBlock = CombatRemotes and CombatRemotes:FindFirstChild("Block")
local RemoteInputUpdate = CombatRemotes and CombatRemotes:FindFirstChild("InputUpdate")
local RemotePendingReaction = CombatRemotes and CombatRemotes:FindFirstChild("PendingReaction")
local NenTechniqueMastery = require(ReplicatedStorage.Shared.Data.NenTechniqueMastery)
local ItemList = require(ReplicatedStorage.Shared.Data.InventoryItems.ItemList)
local FishingConfig = require(ReplicatedStorage.Shared.Data.FishingConfig)
local FishingReel = require(ReplicatedStorage.Shared.Data.FishingReel)
local FishingWater = pcall(function() return require(ReplicatedStorage.Shared.Data.FishingWater) end) and require(ReplicatedStorage.Shared.Data.FishingWater) or nil
local Pickaxes = require(ReplicatedStorage.Shared.Data.Pickaxes)
local MinesArea = require(ReplicatedStorage.Shared.Data.MinesArea)
local OreSellData = require(ReplicatedStorage.Shared.Data.OreSellData)
local Talents = pcall(function() return require(ReplicatedStorage.Shared.Data.Talents) end) and require(ReplicatedStorage.Shared.Data.Talents) or nil
local CodesData = pcall(function() return require(ReplicatedStorage.Shared.Data.CodesData) end) and require(ReplicatedStorage.Shared.Data.CodesData) or nil

-- Fishing state tracking
local isFishingCastActive = false
local isFishingBiting = false
local currentCastId = nil
local lastFishingActivity = 0

-- ========================================================
-- CONFIGURATION STATE
-- ========================================================
local Config = {
    -- Combat & Farm
    AutoLevelFarm = false,
    LevelFarmIncludeBosses = false,
    LevelFarmRoute = "Surface Route (Blick -> Beach)",
    AutoFarmMob = false,
    SelectedMob = "Forest Brawler",
    AutoFarmBoss = false,
    SelectedBoss = "Master of the Swamp",
    AutoRespawn = true,
    FarmMode = "Behind",
    FarmDistance = 5,
    AttackDelay = 0.2,
    FastAttack = false,
    TravelMode = "Teleport",
    TweenSpeed = 250,
    SelectedWeapon = "Fists",
    AutoEquip = true,
    Noclip = false,
    MobESP = false,
    FarmAnyNearby = false,
    MaxRadius = 600,

    -- Auto Parry (100% Precision)
    AutoParry = true,
    AutoParryMobs = true,
    AutoParryPlayers = true,
    AutoFeintToParry = true,
    AutoBlockOnParryCooldown = true,
    AutoFaceAttackerOnParry = true,
    ShowParryVisualRange = true,
    ParryRange = 28,
    ParryTimingOffset = 0,

    -- Nen & Meditation
    AutoMeditation = false,
    AutoSolveMinigame = true,
    SelectedTechnique = "Ten",
    AutoUpgradeTier = true,
    TargetAffinity = "Specialist",
    AutoRollAffinity = false,

    -- Chests & Loot
    AutoLootChests = false,
    ChestESP = false,
    AutoOpenInventoryChests = false,
    SelectedInventoryChest = "Normal Chest",
    SelectedOutfit = "None",
    SelectedAccessory = "None",

    -- Auto Fishing
    AutoFishing = false,
    AutoSolveFishing = true,
    AutoTeleportToFishingSpot = true,
    UseCustomFishingSpot = false,
    CustomFishingCFrame = nil,
    CustomWaterTarget = nil,

    -- Mining & Gathering
    AutoMine = false,
    SelectedOre = "All Ores",
    AutoSellOres = false,
    AutoSellOreThreshold = 10,
    AutoEquipPickaxe = true,
    MineTravelMode = "Teleport",
    MineDefendMobs = false,
    SkipOresWithMobs = true,

    -- Quests, Milestones & Storylines
    AutoCollectQuests = true,
    AutoRepeatQuests = true,
    AutoClaimMilestones = true,
    AutoClaimStorylineBoards = true,
    AutoTakeQuestForTargetMob = true,
    AutoTakeQuestForTargetBoss = true,
    QuestCheckInterval = 2,
    SelectedIslandBoard = "1. Whale Island Town Board [Lv. 1-10] (ในเมืองเกาะปลาวาฬ)",
    SelectedBoardQuest = "KillForestBrawler",
    CustomQuestName = "KillForestBrawler",

    -- Movement, Teleport & Cheats
    Fly = false,
    FlySpeed = 50,
    TPWalk = false,
    TPWalkSpeed = 2.5,
    InfiniteJump = false,
    CustomWalkSpeed = 16,
    EnableCustomWalkSpeed = false,
    CustomJumpPower = 80,
    EnableCustomJumpPower = false,
    InfiniteStamina = false,
    InfiniteOxygen = false,
    SelectedCampfire = "None",
    SelectedNPC = "None",
    SelectedPlayer = "None",
    CustomTPX = 0,
    CustomTPY = 0,
    CustomTPZ = 0,

    -- Stats & Talents (System 8)
    AutoStats = false,
    AutoStatTarget = "StrengthStat",
    AutoStatRatio = "Single", -- "Single", "Balanced"
    AutoStatThreshold = 1,
    AutoRerollHand = false,
    AutoPickTalent = false,
    TargetTalentRarity = "Legendary",
    TargetTalent = "None",
    AutoRerollOwnedTalent = false,
    SelectedOwnedTalent = "None",
    MinJenniForReroll = 10000,

    -- Codes & Rewards (System 9)
    CustomCodeInput = "",
}

-- Lists & Constants (Complete Verified Mobs & Bosses sorted by Level Progression)
local AvailableMobs = {
    "Forest Brawler",     -- Lv. 1-5 (Whale Island Town)
    "Cave Brawler",       -- Lv. 5-10 (Whale Island Town)
    "Phantom Raider",     -- Lv. 10-15 (Crimson Camp)
    "Angry Farmer",       -- Lv. 15-18 (Farm)
    "Farm Keeper",        -- Lv. 18-21 (Farm)
    "Chief Farmer",       -- Lv. 21-25 (Farm)
    "Port Invader",       -- Lv. 25-32 (Blick Castle)
    "Port Marksman",      -- Lv. 32-40 (Blick Castle)
    "Green Goblin",       -- Lv. 25-33 (Mines)
    "Zombie",             -- Lv. 33-40 (Mines)
    "Big Zombie",         -- Lv. 40-48 (Mines)
    "Stone Soldier",      -- Lv. 48-60 (Mines)
    "Stone Roller",       -- (Mines)
    "Beach Brawler",      -- Lv. 40-48 (Whale Island Beach)
    "Beach Warrior",      -- Lv. 48-60 (Whale Island Beach)
    "Foxbear Hunter",     -- Lv. 60-62 (Deep Forest)
    "Lost Hunter",        -- Lv. 62-65 (Deep Forest)
    "Swamp Viper",        -- Lv. 65-70 (Swamp)
    "Purple Viper",       -- Lv. 70-75 (Swamp)
    "Crimson Swordsman",  -- Lv. 75-80 (Volcanic Area)
    "Flame Worshipper",   -- Lv. 80-85 (Volcanic Area)
    "Volcano Warrior",    -- Lv. 85-92 (Volcanic Area)
    "Fire Spirit",        -- Lv. 92-100 (Volcanic Area)
}

local AvailableBosses = {
    "Crimson Flame",       -- Lv. 10-15 Boss (Crimson Camp)
    "Fox Bear",            -- Lv. 15-25 Boss (Farm)
    "Black Blick",         -- Lv. 25-40 Boss (Blick Castle)
    "Mole Rat",            -- Lv. 25-60 Boss (Mines)
    "Stone Eye",           -- Lv. 25-60 Boss (Mines)
    "Sandy Storm",         -- Lv. 40-55 Boss (Beach)
    "Beach King",          -- Lv. 40-55 Boss (Beach)
    "Master of the Swamp", -- Lv. 65-75 Boss (Swamp)
    "Dracolith",           -- Lv. 75-100 Boss (Volcanic Area)
    "Frost Fang",          -- World Boss
    "Fire Master",         -- World Boss
}

local AvailableOres = {
    "All Ores",
    "Refined Stone",
    "Lime Stone",
    "Iron",
    "Aluminium",
    "Gold",
    "Ruby",
    "Nen Crystal",
    "Ocean Crystal",
    "Ruby Crystal",
    "Charged Crystal",
    "Fire Essence",
    "Frost Stone",
    "Wood"
}

local NenTechniques = {
    "Ten",
    "Ren",
    "Ken",
    "Zetsu",
    "Gyo",
    "Ko",
    "Shu",
    "Ryu_Strength",
    "Ryu_Defense",
    "En"
}

local NenAffinities = {
    "Specialist",
    "Enhancer",
    "Transmuter",
    "Conjuration",
    "Emitter",
    "Manipulator"
}

local TierThresholds = { 250, 750, 1750, 3500 }

local ChestRarityColors = {
    Common = Color3.fromRGB(200, 200, 200),
    Uncommon = Color3.fromRGB(100, 255, 100),
    Rare = Color3.fromRGB(60, 150, 255),
    Legendary = Color3.fromRGB(255, 180, 0),
    Extraordinary = Color3.fromRGB(200, 50, 255),
    Mythical = Color3.fromRGB(255, 50, 50),
}

-- ========================================================
-- HELPER FUNCTIONS
-- ========================================================
local function GetCharacter()
    return LocalPlayer.Character
end

local function GetHRP()
    local char = GetCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local activeDefenseTarget = nil
local isBoardInteractionBusy = false
local MobDropdown = nil
local lastSpawnStreamTime = 0
local UpdateESP = nil

local function IsPlayerDead()
    local char = GetCharacter()
    if not char then return true end
    if char:GetAttribute("Dead") == true then return true end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return true end
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local ds = pg and pg:FindFirstChild("DeathScreen")
    if ds and ds.Enabled then return true end
    return false
end

local function TriggerPlayerRespawn()
    local ok = false
    -- 1. Call DeathService:Respawn() directly via Knit
    if DeathService and DeathService.Respawn then
        pcall(function()
            local res = DeathService:Respawn():await()
            if res == true then ok = true end
        end)
    end
    -- 2. Also fire Activated signal on DeathScreen Respawn button if visible
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local ds = pg and pg:FindFirstChild("DeathScreen")
        if ds then
            local respawnBtn = (ds:FindFirstChild("DeathScene") and ds.DeathScene:FindFirstChild("Panel") and ds.DeathScene.Panel:FindFirstChild("Respawn"))
                or (ds:FindFirstChild("RespawnButton") and ds.RespawnButton:FindFirstChild("Btn"))
            if respawnBtn then
                if getconnections then
                    for _, conn in ipairs(getconnections(respawnBtn.Activated)) do
                        conn:Fire()
                        ok = true
                    end
                elseif firesignal then
                    firesignal(respawnBtn.Activated)
                    ok = true
                end
            end
        end
    end)
    return ok
end

-- ========================================================
-- SINGLE-TOOL IDENTIFICATION & EQUIPPING SYSTEM
-- ========================================================
local function IsRodItem(tool)
    if not tool or not tool:IsA("Tool") then return false end
    if FishingConfig and FishingConfig.IsRod and FishingConfig.IsRod(tool) then return true end
    local name = tool.Name:lower()
    return name == "fishing" or string.find(name, "rod") ~= nil or string.find(name, "fish") ~= nil
end

local function IsPickaxeItem(tool)
    if not tool or not tool:IsA("Tool") then return false end
    if Pickaxes and Pickaxes.Tools and Pickaxes.Tools[tool.Name] then return true end
    local name = tool.Name:lower()
    return string.find(name, "pickaxe") ~= nil or string.find(name, "pick") ~= nil
end

local function IsChestItem(tool)
    if not tool or not tool:IsA("Tool") then return false end
    local name = tool.Name:lower()
    return string.find(name, "chest") ~= nil
end

local function IsCombatWeaponItem(tool)
    if not tool or not tool:IsA("Tool") then return false end
    if IsRodItem(tool) or IsPickaxeItem(tool) or IsChestItem(tool) then return false end
    local name = tool.Name:lower()
    if string.find(name, "mat") then return false end
    return true
end

local function EquipOnlyTool(targetTool)
    local char = GetCharacter()
    if not char then return false end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    local hum = char:FindFirstChildOfClass("Humanoid")

    if not targetTool or not targetTool:IsA("Tool") then
        if hum then hum:UnequipTools() end
        if bp then
            for _, child in ipairs(char:GetChildren()) do
                if child:IsA("Tool") then
                    pcall(function() child.Parent = bp end)
                end
            end
        end
        return false
    end

    -- Return all conflicting tools in Character to Backpack
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") and child ~= targetTool then
            if bp then
                child.Parent = bp
            end
        end
    end

    -- Equip targetTool if not already inside Character
    if targetTool.Parent ~= char then
        if hum then
            hum:EquipTool(targetTool)
        else
            targetTool.Parent = char
        end
    end

    return true
end

local function GetAvailableWeapons()
    local weapons = { "Any" }
    local seen = { ["Any"] = true }
    local char = GetCharacter()
    local bp = LocalPlayer:FindFirstChild("Backpack")

    local function checkTool(t)
        if t:IsA("Tool") and not seen[t.Name] and IsCombatWeaponItem(t) then
            seen[t.Name] = true
            table.insert(weapons, t.Name)
        end
    end

    if char then
        for _, t in ipairs(char:GetChildren()) do checkTool(t) end
    end
    if bp then
        for _, t in ipairs(bp:GetChildren()) do checkTool(t) end
    end
    if not seen["Fists"] then
        table.insert(weapons, "Fists")
    end
    return weapons
end

local WeaponDropdown = nil

local function EnsureWeaponEquipped()
    if (Config.AutoFishing or Config.AutoMine) and not activeDefenseTarget then return end
    local char = GetCharacter()
    if not char then return end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    local choice = Config.SelectedWeapon

    -- 1. Check tools currently held in character
    local heldWeapons = {}
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            if not IsCombatWeaponItem(child) then
                if bp then child.Parent = bp end
            else
                table.insert(heldWeapons, child)
            end
        end
    end

    -- If choice is Any and exactly one combat weapon is already held
    if choice == "Any" and #heldWeapons == 1 then
        return
    end
    -- If choice is specific and that exact weapon is the only one held
    if choice ~= "Any" and #heldWeapons == 1 and heldWeapons[1].Name == choice then
        return
    end

    -- 2. Find target weapon to equip
    local targetTool = nil
    if choice ~= "Any" then
        for _, t in ipairs(heldWeapons) do
            if t.Name == choice then targetTool = t; break end
        end
        if not targetTool and bp then
            targetTool = bp:FindFirstChild(choice)
        end
    end

    if not targetTool then
        for _, t in ipairs(heldWeapons) do
            if IsCombatWeaponItem(t) then targetTool = t; break end
        end
        if not targetTool and bp then
            for _, t in ipairs(bp:GetChildren()) do
                if IsCombatWeaponItem(t) then targetTool = t; break end
            end
        end
        if not targetTool and bp then
            targetTool = bp:FindFirstChild("Fists")
        end
    end

    if targetTool then
        EquipOnlyTool(targetTool)
    end
end

local function IsAlive(model)
    if not model or not model.Parent then return false end
    if model == GetCharacter() then return false end

    if model:GetAttribute("Respawning") == true then
        return false
    end

    local attrHealth = model:GetAttribute("Health")
    if attrHealth ~= nil and attrHealth <= 0 then
        return false
    end

    if model:GetAttribute("Dead") == true or model:GetAttribute("Downed") == true then
        return false
    end

    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then
        return false
    end

    local hrp = model:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return false
    end

    return true
end

local function GetTarget(targetName)
    local hrp = GetHRP()
    if not hrp then return nil end
    local myPos = hrp.Position
    local bestTarget = nil
    local bestDist = math.huge

    for _, model in ipairs(workspace:GetChildren()) do
        if model:IsA("Model") and model.Name == targetName then
            if IsAlive(model) then
                local targetHrp = model:FindFirstChild("HumanoidRootPart")
                local dist = (targetHrp.Position - myPos).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    bestTarget = model
                end
            end
        end
    end

    if not bestTarget and Config.FarmAnyNearby then
        bestDist = Config.MaxRadius
        for _, model in ipairs(workspace:GetChildren()) do
            if model:IsA("Model") and table.find(AvailableMobs, model.Name) then
                if IsAlive(model) then
                    local targetHrp = model:FindFirstChild("HumanoidRootPart")
                    local dist = (targetHrp.Position - myPos).Magnitude
                    if dist < bestDist then
                        bestDist = dist
                        bestTarget = model
                    end
                end
            end
        end
    end

    return bestTarget
end

local VerifiedMobSpawnPoints = {
    ["Forest Brawler"] = Vector3.new(-1362.12, 289.99, -208.63),
    ["Cave Brawler"] = Vector3.new(-1570.80, 284.75, -179.07),
    ["Phantom Raider"] = Vector3.new(-2135.75, 268.87, 283.88),
    ["Crimson Flame"] = Vector3.new(-2825.43, 217.32, 319.31),
    ["Angry Farmer"] = Vector3.new(-2345.07, 189.00, -1035.39),
    ["Farm Keeper"] = Vector3.new(-2315.08, 192.26, -1269.62),
    ["Chief Farmer"] = Vector3.new(-2303.73, 187.33, -1056.32),
    ["Fox Bear"] = Vector3.new(-3024.24, 205.48, -583.11),
    ["Port Invader"] = Vector3.new(-3751.95, 548.83, 550.79),
    ["Port Marksman"] = Vector3.new(-4083.41, 545.70, 502.09),
    ["Black Blick"] = Vector3.new(-4718.96, 686.14, 460.53),
    ["Green Goblin"] = Vector3.new(-1885.00, -652.66, -6675.88),
    ["Zombie"] = Vector3.new(-2937.73, -776.59, -7050.71),
    ["Big Zombie"] = Vector3.new(-2679.84, -733.01, -7249.57),
    ["Stone Soldier"] = Vector3.new(-2482.72, -669.33, -7298.81),
    ["Stone Roller"] = Vector3.new(-1965.63, -636.06, -7225.62),
    ["Mole Rat"] = Vector3.new(-3352.15, -789.46, -7238.43),
    ["Stone Eye"] = Vector3.new(-2564.11, -748.99, -6767.88),
    ["Beach Brawler"] = Vector3.new(-5624.49, 331.71, 1811.82),
    ["Beach Warrior"] = Vector3.new(-4542.51, 312.49, 2045.53),
    ["Sandy Storm"] = Vector3.new(-3964.52, 323.26, 2093.05),
    ["Beach King"] = Vector3.new(-3474.09, 419.27, 2133.75),
    ["Foxbear Hunter"] = Vector3.new(-2862.11, 184.61, -2034.22),
    ["Lost Hunter"] = Vector3.new(-3909.93, 61.49, -2693.43),
    ["Swamp Viper"] = Vector3.new(-5165.88, -68.05, -3181.02),
    ["Purple Viper"] = Vector3.new(-5328.42, -53.05, -2601.74),
    ["Master of the Swamp"] = Vector3.new(-4917.82, -19.50, -1715.45),
    ["Crimson Swordsman"] = Vector3.new(-1137.95, 479.24, -3157.92),
    ["Flame Worshipper"] = Vector3.new(-918.64, 461.74, -2832.95),
    ["Volcano Warrior"] = Vector3.new(-682.06, 448.58, -2943.81),
    ["Fire Spirit"] = Vector3.new(-293.48, 407.94, -2971.22),
    ["Dracolith"] = Vector3.new(84.45, 410.79, -2895.86),
    ["Frost Fang"] = Vector3.new(-5695.19, 441.02, -1197.51),
    ["Fire Master"] = Vector3.new(-2832.78, 217.85, 316.14),
}

local function GetMobSpawnPoint(targetName)
    if not targetName then return nil end
    local bestPoint = nil
    local bestDist = math.huge
    local hrp = GetHRP()
    local myPos = hrp and hrp.Position or Vector3.zero
    
    local cleanName = targetName:lower():gsub("%s+", "")
    
    -- 1. Check ReplicatedStorage.NpcSpawnPoints
    local NpcSpawnPoints = ReplicatedStorage:FindFirstChild("NpcSpawnPoints")
    if NpcSpawnPoints then
        for _, v in ipairs(NpcSpawnPoints:GetChildren()) do
            local vClean = v.Name:lower():gsub("%s+", "")
            if (v.Name == targetName or vClean == cleanName) and v:IsA("Vector3Value") then
                local dist = (v.Value - myPos).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    bestPoint = v.Value
                end
            end
        end
    end
    if bestPoint then return bestPoint end
    
    -- 2. Check VerifiedMobSpawnPoints fallback
    if VerifiedMobSpawnPoints[targetName] then
        return VerifiedMobSpawnPoints[targetName]
    end
    for k, pos in pairs(VerifiedMobSpawnPoints) do
        if k:lower():gsub("%s+", "") == cleanName then
            return pos
        end
    end

    -- 3. Check NpcDataLibrary
    local NpcDataLibrary = ReplicatedStorage:FindFirstChild("NpcDataLibrary")
    if NpcDataLibrary then
        pcall(function()
            local lib = require(NpcDataLibrary)
            for name, data in pairs(lib) do
                local nClean = name:lower():gsub("%s+", "")
                if (name == targetName or nClean == cleanName) and data.SpawnPoint then
                    local sp = data.SpawnPoint
                    if typeof(sp) == "CFrame" then
                        bestPoint = sp.Position
                        break
                    elseif typeof(sp) == "Vector3" then
                        bestPoint = sp
                        break
                    end
                end
            end
        end)
    end
    return bestPoint
end

local function CalculateFarmCFrame(targetHrp)
    local mode = Config.FarmMode
    local dist = Config.FarmDistance
    local targetPos = targetHrp.Position
    local targetLook = targetHrp.CFrame.LookVector

    if mode == "Behind" then
        local pos = targetPos - (targetLook * dist) + Vector3.new(0, 2, 0)
        return CFrame.new(pos, targetPos)
    elseif mode == "Above" then
        local pos = targetPos + Vector3.new(0, dist + 2, 0)
        return CFrame.new(pos, targetPos)
    elseif mode == "Front" then
        local pos = targetPos + (targetLook * dist) + Vector3.new(0, 2, 0)
        return CFrame.new(pos, targetPos)
    end
    return CFrame.new(targetPos - (targetLook * dist), targetPos)
end

local function SetHover(enable)
    local hrp = GetHRP()
    if not hrp then return end
    local bv = hrp:FindFirstChild("FarmHoverBV")
    if enable then
        if not bv then
            bv = Instance.new("BodyVelocity")
            bv.Name = "FarmHoverBV"
            bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
            bv.Velocity = Vector3.zero
            bv.Parent = hrp
        end
    else
        if bv then bv:Destroy() end
    end
end

local function MoveToTarget(targetCFrame, dt)
    local hrp = GetHRP()
    if not hrp then return false end

    local currentPos = hrp.Position
    local targetPos = targetCFrame.Position
    local distance = (targetPos - currentPos).Magnitude

    if Config.TravelMode == "Teleport" then
        hrp.CFrame = targetCFrame
        hrp.AssemblyLinearVelocity = Vector3.zero
        return true
    else
        local speed = math.max(Config.TweenSpeed, 50)
        local step = speed * dt

        if step >= distance or distance <= 2 then
            hrp.CFrame = targetCFrame
            hrp.AssemblyLinearVelocity = Vector3.zero
            return true
        else
            local dir = (targetPos - currentPos).Unit
            local nextPos = currentPos + (dir * step)
            hrp.CFrame = CFrame.new(nextPos, targetPos)
            hrp.AssemblyLinearVelocity = Vector3.zero
            return false
        end
    end
end

local parryImminentUntil = 0
local lastParryAttemptTime = 0

local function DoM1Attack()
    if Config.AutoParry and os.clock() < parryImminentUntil then
        return
    end
    pcall(function()
        CombatModule.Hit(false, false, CombatModule.BeginInputTrace("M1"))
    end)
end

local lastAttackTime = 0

local function AttackTargetEntity(target, dt)
    if not target or not target:FindFirstChild("HumanoidRootPart") or not IsAlive(target) then
        SetHover(false)
        return false
    end

    local hrp = GetHRP()
    local targetHrp = target.HumanoidRootPart
    if not hrp then return false end

    SetHover(true)
    local isParryingOrImminent = Config.AutoParry and (os.clock() < parryImminentUntil or (GetCharacter() and (GetCharacter():HasTag("CanParry") or GetCharacter():HasTag("ParryFrames"))))
    local farmCFrame = CalculateFarmCFrame(targetHrp)
    if isParryingOrImminent and Config.AutoFaceAttackerOnParry then
        farmCFrame = CFrame.lookAt(farmCFrame.Position, Vector3.new(targetHrp.Position.X, farmCFrame.Position.Y, targetHrp.Position.Z))
    end

    local arrived = MoveToTarget(farmCFrame, dt or 0.03)

    if isParryingOrImminent and Config.AutoFaceAttackerOnParry then
        hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(targetHrp.Position.X, hrp.Position.Y, targetHrp.Position.Z))
    end

    if Config.AutoEquip then
        EnsureWeaponEquipped()
    end

    local distToTarget = (targetHrp.Position - hrp.Position).Magnitude
    if (arrived or distToTarget <= Config.FarmDistance + 4) and (os.clock() - lastAttackTime >= Config.AttackDelay) then
        lastAttackTime = os.clock()
        DoM1Attack()
    end

    return true
end

-- ========================================================
-- AUTO PARRY SYSTEM (100% PRECISION HIT-MARKER PREDICTION)
-- ========================================================
local ParryStats = {
    TotalParries = 0,
    TotalAttempts = 0,
    LastParried = "None",
    Status = "Standby",
}
local ParryStatusParagraph = nil

local animMarkerCache = {}
local firedTrackMarkers = {}
local parryAdornmentOuter = nil
local parryAdornmentInner = nil

local HitMarkerNames = {
    ["Hit"] = true,
    ["Punch"] = true,
    ["Kick"] = true,
    ["Slash"] = true,
    ["Slam"] = true,
    ["Stomp"] = true,
    ["SlamGround"] = true,
    ["Shoot"] = true,
    ["Throw"] = true,
    ["Whip"] = true,
    ["Grab"] = true,
    ["Barrage"] = true,
    ["Scissors"] = true,
    ["Land"] = true,
    ["Impact"] = true,
    ["Strike"] = true,
    ["Bite"] = true,
    ["Claw"] = true,
    ["Pierce"] = true,
    ["Smash"] = true,
    ["Burst"] = true,
    ["Beam"] = true,
    ["Clap"] = true,
    ["1"] = true,
    ["2"] = true,
    ["3"] = true,
    ["4"] = true,
    ["5"] = true,
    ["Attack Loop 1 (Start)"] = true,
    ["Attack Loop 2 (Start)"] = true,
    ["Start"] = true,
}

local IgnoredMarkerNames = {
    ["FeintStart"] = true,
    ["Feint Start"] = true,
    ["FeintEnd"] = true,
    ["Feint End"] = true,
    ["SwingLead"] = true,
    ["SwingHold"] = true,
    ["Swing Hold"] = true,
    ["Lunge"] = true,
    ["Charge"] = true,
    ["ChargeFX"] = true,
    ["ArmFX"] = true,
    ["RockArm"] = true,
    ["Effect"] = true,
    ["Spin"] = true,
    ["Jump"] = true,
    ["Vanish"] = true,
    ["Pause"] = true,
    ["Stop"] = true,
    ["Attack Loop 1 (End)"] = true,
    ["Attack Loop 2 (End)"] = true,
    ["Finished"] = true,
    [""] = true,
}

local function ExtractMarkerList(markers)
    local list = {}
    if type(markers) ~= "table" then return list end
    for markerName, times in pairs(markers) do
        local sName = tostring(markerName)
        if not IgnoredMarkerNames[sName] then
            local isHit = HitMarkerNames[sName]
                or string.find(sName:lower(), "hit")
                or string.find(sName:lower(), "punch")
                or string.find(sName:lower(), "kick")
                or string.find(sName:lower(), "slash")
                or string.find(sName:lower(), "strike")
                or string.find(sName:lower(), "bite")
                or string.find(sName:lower(), "pierce")
                or string.find(sName:lower(), "smash")
                or string.find(sName:lower(), "impact")
                or string.find(sName:lower(), "barrage")
                or string.find(sName:lower(), "clap")
                or string.find(sName:lower(), "slam")
                or string.find(sName:lower(), "shoot")
                or string.find(sName:lower(), "burst")
                or string.find(sName:lower(), "beam")

            if isHit then
                local timeList = type(times) == "table" and times or { times }
                for _, numT in ipairs(timeList) do
                    if type(numT) == "number" then
                        table.insert(list, { time = numT, name = sName })
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.time < b.time end)
    return list
end

local function UpdateParryVisualRange()
    if not Config.ShowParryVisualRange then
        if parryAdornmentOuter then parryAdornmentOuter.Visible = false end
        if parryAdornmentInner then parryAdornmentInner.Visible = false end
        return
    end

    local myHrp = GetHRP()
    if not myHrp then return end

    if not parryAdornmentOuter or not parryAdornmentOuter.Parent then
        parryAdornmentOuter = Instance.new("CylinderHandleAdornment")
        parryAdornmentOuter.Name = "ParryVisualRangeOuter"
        parryAdornmentOuter.Adornee = workspace.Terrain
        parryAdornmentOuter.AlwaysOnTop = false
        parryAdornmentOuter.Color3 = Color3.fromRGB(0, 230, 255)
        parryAdornmentOuter.Transparency = 0.35
        parryAdornmentOuter.Height = 0.12
        parryAdornmentOuter.ZIndex = 5
        parryAdornmentOuter.Parent = workspace.CurrentCamera
    end

    if not parryAdornmentInner or not parryAdornmentInner.Parent then
        parryAdornmentInner = Instance.new("CylinderHandleAdornment")
        parryAdornmentInner.Name = "ParryVisualRangeInner"
        parryAdornmentInner.Adornee = workspace.Terrain
        parryAdornmentInner.AlwaysOnTop = false
        parryAdornmentInner.Color3 = Color3.fromRGB(0, 180, 255)
        parryAdornmentInner.Transparency = 0.88
        parryAdornmentInner.Height = 0.08
        parryAdornmentInner.InnerRadius = 0
        parryAdornmentInner.ZIndex = 4
        parryAdornmentInner.Parent = workspace.CurrentCamera
    end

    local radius = Config.ParryRange or 28
    parryAdornmentOuter.Radius = radius
    parryAdornmentOuter.InnerRadius = math.max(radius - 0.45, 0)
    parryAdornmentOuter.Visible = true

    parryAdornmentInner.Radius = radius
    parryAdornmentInner.Visible = true
end

local function GetAnimationMarkersCached(track)
    local anim = track.Animation
    local animId = anim and anim.AnimationId
    if not animId or animId == "" then
        return nil
    end

    local cached = animMarkerCache[animId]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end

    animMarkerCache[animId] = false
    task.spawn(function()
        local markers = nil
        if AnimationMarkers then
            pcall(function()
                markers = AnimationMarkers.Get(anim)
            end)
        end
        local list = ExtractMarkerList(markers)
        if #list > 0 then
            animMarkerCache[animId] = list
        else
            local tName = track.Name:lower()
            if string.find(tName, "punch") or string.find(tName, "slash") or string.find(tName, "attack") or string.find(tName, "kick") or string.find(tName, "combo") then
                local estHit = (track.Length > 0.15) and (track.Length * 0.40) or 0.20
                animMarkerCache[animId] = { { time = estHit, name = "EstimatedHit" } }
            else
                animMarkerCache[animId] = {}
            end
        end
    end)

    return nil
end

task.spawn(function()
    pcall(function()
        local assets = ReplicatedStorage:FindFirstChild("Assets")
        if not assets then return end
        local animFolders = {
            assets:FindFirstChild("Animations"),
            assets:FindFirstChild("Items"),
        }
        for _, root in ipairs(animFolders) do
            if root then
                for _, desc in ipairs(root:GetDescendants()) do
                    if desc:IsA("Animation") and desc.AnimationId ~= "" and animMarkerCache[desc.AnimationId] == nil then
                        animMarkerCache[desc.AnimationId] = false
                        task.spawn(function()
                            if AnimationMarkers then
                                local ok, markers = pcall(function() return AnimationMarkers.Get(desc) end)
                                if ok and type(markers) == "table" then
                                    animMarkerCache[desc.AnimationId] = ExtractMarkerList(markers)
                                else
                                    animMarkerCache[desc.AnimationId] = {}
                                end
                            end
                        end)
                        task.wait(0.02)
                    end
                end
            end
        end
    end)
end)

local function TriggerParry(attackerModel, attackName)
    local char = GetCharacter()
    if not char or IsPlayerDead() then return false end
    local myHrp = GetHRP()

    if char:HasTag("CanParry") or char:HasTag("ParryFrames") then
        return true
    end

    local onCooldown = char:GetAttribute("ParryOnCooldown") == true
    if onCooldown then
        if Config.AutoBlockOnParryCooldown then
            pcall(function()
                CombatModule.Block(false, false)
            end)
        end
        return false
    end

    local now = os.clock()
    if now - lastParryAttemptTime < 0.22 then
        return false
    end
    lastParryAttemptTime = now
    ParryStats.TotalAttempts = ParryStats.TotalAttempts + 1

    if Config.AutoFaceAttackerOnParry and myHrp and attackerModel and attackerModel:FindFirstChild("HumanoidRootPart") then
        local attHrp = attackerModel.HumanoidRootPart
        myHrp.CFrame = CFrame.lookAt(myHrp.Position, Vector3.new(attHrp.Position.X, myHrp.Position.Y, attHrp.Position.Z))
    end

    if char:HasTag("Attacking") and Config.AutoFeintToParry then
        pcall(function()
            if CombatController and CombatController.BeginFeint then
                CombatController:BeginFeint()
            elseif RemoteInputUpdate then
                RemoteInputUpdate:FireServer("IsHoldingRightClick", true)
                RemoteInputUpdate:FireServer("IsHoldingRightClick", false)
            end
        end)
    end

    pcall(function()
        CombatModule.Block(true, false)
    end)

    task.defer(function()
        if RemoteInputUpdate then
            RemoteInputUpdate:FireServer("HoldingBlock", false)
        end
    end)

    ParryStats.LastParried = attackerModel and attackerModel.Name or "Enemy"
    ParryStats.Status = "Parried " .. tostring(ParryStats.LastParried) .. (attackName and (" (" .. attackName .. ")") or "")
    return true
end

if RemotePendingReaction then
    RegisterConnection(RemotePendingReaction.OnClientEvent:Connect(function(...)
        local args = { ... }
        if args[1] == "ParryResult" or args[2] == "ParryResult" then
            ParryStats.TotalParries = ParryStats.TotalParries + 1
            ParryStats.Status = "Parry Confirmed! (" .. tostring(ParryStats.LastParried) .. ")"
            if RemoteInputUpdate then
                RemoteInputUpdate:FireServer("HoldingBlock", false)
            end
        end
    end))
end

if RemoteBlock then
    RegisterConnection(RemoteBlock.OnClientEvent:Connect(function(...)
        local args = { ... }
        local eventName = args[1]
        if eventName == "ParryDecision" and args[3] == "Accepted" then
            ParryStats.Status = "Parry Window Active"
        end
    end))
end

RegisterConnection(RunService.RenderStepped:Connect(function()
    local myChar = GetCharacter()
    local myHrp = GetHRP()

    if Config.ShowParryVisualRange and parryAdornmentOuter and parryAdornmentOuter.Visible and myHrp then
        local cf = CFrame.new(myHrp.Position.X, myHrp.Position.Y - 2.8, myHrp.Position.Z) * CFrame.Angles(math.rad(90), 0, 0)
        parryAdornmentOuter.CFrame = cf
        if parryAdornmentInner then
            parryAdornmentInner.CFrame = cf
        end
    end

    if not Config.AutoParry then return end
    if not myChar or IsPlayerDead() then return end
    if not myHrp then return end

    local latency = LocalPlayer:GetAttribute("CombatSmoothedLatency") or (LocalPlayer:GetNetworkPing() * 0.5) or 0.06
    local lead = math.clamp(latency + 0.14 + (Config.ParryTimingOffset or 0), 0.13, 0.32)
    local parryRange = Config.ParryRange or 28

    local enemies = {}

    if Config.AutoParryMobs then
        local scanRoots = { workspace }
        local humFolder = workspace:FindFirstChild("Humanoids")
        if humFolder then table.insert(scanRoots, humFolder) end

        for _, root in ipairs(scanRoots) do
            for _, obj in ipairs(root:GetChildren()) do
                if obj:IsA("Model") and obj ~= myChar and not Players:GetPlayerFromCharacter(obj) then
                    local oHrp = obj:FindFirstChild("HumanoidRootPart")
                    local hum = obj:FindFirstChildOfClass("Humanoid")
                    if oHrp and hum and hum.Health > 0 and (oHrp.Position - myHrp.Position).Magnitude <= parryRange then
                        table.insert(enemies, obj)
                    end
                end
            end
        end
    end

    if Config.AutoParryPlayers then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character ~= myChar then
                local pHrp = p.Character:FindFirstChild("HumanoidRootPart")
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if pHrp and hum and hum.Health > 0 and (pHrp.Position - myHrp.Position).Magnitude <= parryRange then
                    table.insert(enemies, p.Character)
                end
            end
        end
    end

    local activeAttackerHrp = nil

    for _, enemy in ipairs(enemies) do
        local hum = enemy:FindFirstChildOfClass("Humanoid")
        local animCtrl = enemy:FindFirstChildOfClass("AnimationController")
        local animator = (hum and hum:FindFirstChildOfClass("Animator")) or (animCtrl and animCtrl:FindFirstChildOfClass("Animator"))
        
        if animator then
            local tracks = animator:GetPlayingAnimationTracks()
            for _, track in ipairs(tracks) do
                local markers = GetAnimationMarkersCached(track)
                if markers and #markers > 0 then
                    local trackKey = tostring(track.Animation and track.Animation.AnimationId or track.Name) .. "_" .. tostring(enemy:GetDebugId())
                    firedTrackMarkers[trackKey] = firedTrackMarkers[trackKey] or {}

                    for idx, marker in ipairs(markers) do
                        local hitTime = marker.time
                        local spd = math.max(track.Speed, 0.05)
                        local rem = (hitTime - track.TimePosition) / spd

                        if track.TimePosition < hitTime - 0.22 then
                            firedTrackMarkers[trackKey][idx] = nil
                        end

                        if rem <= (lead + 0.35) and rem >= -0.04 then
                            activeAttackerHrp = enemy:FindFirstChild("HumanoidRootPart")
                            parryImminentUntil = math.max(parryImminentUntil, os.clock() + rem + 0.10)
                        end

                        if rem <= lead and rem >= -0.04 and not firedTrackMarkers[trackKey][idx] then
                            firedTrackMarkers[trackKey][idx] = true
                            TriggerParry(enemy, marker.name)
                            break
                        end
                    end
                end
            end
        end
    end

    if Config.AutoFaceAttackerOnParry and activeAttackerHrp and myHrp then
        myHrp.CFrame = CFrame.lookAt(myHrp.Position, Vector3.new(activeAttackerHrp.Position.X, myHrp.Position.Y, activeAttackerHrp.Position.Z))
    end
end))

-- ========================================================
-- CHEST & INVENTORY FUNCTIONS (FIXED HOTBAR & SAFE ZONE PIPELINE)
-- ========================================================
local function GetInventoryChests()
    local chests = {}
    local slot = LocalPlayer:FindFirstChild("Data") and LocalPlayer.Data.SavesSlot:FindFirstChild("1")
    local inv = slot and slot.PlayerData:FindFirstChild("Inventory")
    if inv then
        for _, item in ipairs(inv:GetChildren()) do
            local name = item:GetAttribute("item_name") or item.Name
            if string.find(name:lower(), "chest") then
                table.insert(chests, {
                    name = name,
                    uuid = item:GetAttribute("uuid") or item.Name,
                    quantity = item:GetAttribute("quantity") or 1
                })
            end
        end
    end
    return chests
end

local function GetInventoryGear()
    local outfits = {}
    local accessories = {}
    local slot = LocalPlayer:FindFirstChild("Data") and LocalPlayer.Data.SavesSlot:FindFirstChild("1")
    local inv = slot and slot.PlayerData:FindFirstChild("Inventory")
    if inv then
        for _, item in ipairs(inv:GetChildren()) do
            local itemId = item:GetAttribute("item_id")
            local info = ItemList and (ItemList[itemId] or ItemList[tostring(itemId)])
            local itemType = info and info.Type or ""
            local itemName = item:GetAttribute("item_name") or item.Name
            local uuid = item:GetAttribute("uuid") or item.Name
            local isEquipped = item:GetAttribute("equipped") == true or LocalPlayer:GetAttribute("CustomOutfitUUID") == uuid

            if itemType == "Outfit" or string.find(itemName:lower(), "outfit") or string.find(itemName:lower(), "armor") then
                table.insert(outfits, {
                    name = itemName,
                    uuid = uuid,
                    equipped = isEquipped,
                    itemId = itemId
                })
            elseif itemType == "Accessory" or string.find(itemName:lower(), "mask") or string.find(itemName:lower(), "hat") or string.find(itemName:lower(), "scarf") or string.find(itemName:lower(), "boots") then
                table.insert(accessories, {
                    name = itemName,
                    uuid = uuid,
                    equipped = isEquipped,
                    itemId = itemId
                })
            end
        end
    end
    return outfits, accessories
end

local function EquipGearItem(uuid)
    if not uuid then return false end
    local success, res = pcall(function()
        return InventoryService:put_in_hotbar_backpack(uuid):expect()
    end)
    return success and res == true
end

local function UnequipGearItem(uuid)
    if not uuid then return false end
    pcall(function()
        InventoryService:unequip(uuid):expect()
    end)
    pcall(function()
        InventoryService:remove_from_hotbar_backpack(uuid):expect()
    end)
    return true
end

-- ========================================================
-- FISHING DATA & HELPER FUNCTIONS
-- ========================================================
local DefaultFishingSpot = {
    StandCFrame = CFrame.lookAt(Vector3.new(-2840, 220.97, -758), Vector3.new(-2840, 220.97, -775)),
    WaterTarget = Vector3.new(-2840, 188.8, -775),
    Name = "Deep Forest Lake"
}

local function GetTargetFishingSpot()
    if Config.UseCustomFishingSpot and Config.CustomFishingCFrame and Config.CustomWaterTarget then
        return Config.CustomFishingCFrame, Config.CustomWaterTarget, "Custom Saved Spot"
    end
    return DefaultFishingSpot.StandCFrame, DefaultFishingSpot.WaterTarget, "Deep Forest Lake"
end

local FishingStats = {
    TotalFished = 0,
    FishCount = 0,
    ChestCount = 0,
    Status = "Idle",
}

local activeReelConn = nil

local function EnsureRodEquipped()
    local char = GetCharacter()
    if not char then return false end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    
    -- Check tools currently held in character: return weapons/pickaxes/chests to backpack
    local heldRods = {}
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            if not IsRodItem(child) then
                if bp then child.Parent = bp end
            else
                table.insert(heldRods, child)
            end
        end
    end
    
    if #heldRods == 1 then
        return true
    end
    
    local rodTool = heldRods[1]
    if not rodTool and bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if IsRodItem(tool) then
                rodTool = tool
                break
            end
        end
    end
    
    if not rodTool then
        local slot = LocalPlayer:FindFirstChild("Data") and LocalPlayer.Data.SavesSlot:FindFirstChild("1")
        local inv = slot and slot.PlayerData:FindFirstChild("Inventory")
        if inv then
            for _, item in ipairs(inv:GetChildren()) do
                local name = item:GetAttribute("item_name") or item.Name
                if string.find(name:lower(), "rod") or string.find(name:lower(), "fish") then
                    local uuid = item:GetAttribute("uuid") or item.Name
                    pcall(function()
                        InventoryService:put_in_hotbar(uuid, 2):await()
                    end)
                    task.wait(0.3)
                    if bp and bp:FindFirstChild(name) then
                        rodTool = bp[name]
                        break
                    end
                end
            end
        end
    end
    
    if rodTool then
        EquipOnlyTool(rodTool)
        task.wait(0.2)
        return true
    end
    return false
end

local function SetCustomSpotFromPlayer()
    local hrp = GetHRP()
    if not hrp then return false, "No character" end
    
    local forward = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
    if forward.Magnitude < 0.05 then
        forward = Vector3.new(0, 0, -1)
    else
        forward = forward.Unit
    end
    
    local waterTarget = nil
    if FishingWater and FishingWater.Parts and FishingWater.RayHit then
        local waterParts = FishingWater.Parts()
        for _, dist in ipairs({ 9, 12, 15, 18, 22 }) do
            local probePos = hrp.Position + (forward * dist)
            local hitPos = FishingWater.RayHit(waterParts, probePos + Vector3.new(0, 40, 0), Vector3.new(0, -160, 0))
            if hitPos then
                waterTarget = hitPos
                break
            end
        end
    end
    
    if not waterTarget then
        local lookPos = hrp.Position + (forward * 12)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {GetCharacter()}
        local hit = workspace:Raycast(lookPos + Vector3.new(0, 20, 0), Vector3.new(0, -80, 0), params)
        local waterY = hit and hit.Position.Y or (hrp.Position.Y - 5)
        waterTarget = Vector3.new(lookPos.X, waterY, lookPos.Z)
    end
    
    Config.CustomFishingCFrame = hrp.CFrame
    Config.CustomWaterTarget = waterTarget
    Config.UseCustomFishingSpot = true
    return true
end

local function ClaimFreeRodFromHal()
    local hrp = GetHRP()
    if not hrp then return false end
    hrp.CFrame = CFrame.new(-2836.94, 222, -750)
    task.wait(0.4)
    local npc = workspace:FindFirstChild("FishingLesson", true)
    local prompt = npc and npc:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then
        if fireproximityprompt then
            fireproximityprompt(prompt)
        end
        task.wait(0.5)
        local bd = LocalPlayer.PlayerGui:FindFirstChild("BetterDialog")
        if bd and bd:FindFirstChild("Responses", true) then
            for _, r in ipairs(bd.Dialogue.Responses:GetChildren()) do
                local label = r:FindFirstChildWhichIsA("TextLabel", true)
                if label and (string.find(label.Text:lower(), "give it a try") or string.find(label.Text:lower(), "go on") or string.find(label.Text:lower(), "yes")) then
                    local btn = r:FindFirstChildWhichIsA("GuiButton", true)
                    if btn then
                        if getconnections then
                            for _, c in ipairs(getconnections(btn.Activated)) do c:Fire() end
                        elseif firesignal then
                            firesignal(btn.Activated)
                        end
                    end
                end
            end
        end
    end
    return true
end

-- ========================================================
-- MINING & GATHERING HELPERS
-- ========================================================
local MiningStats = {
    TotalJenniEarned = 0,
    OresMined = 0,
    Status = "Idle",
    CurrentTarget = "None",
}

local MineClusters = {
    Vector3.new(-2050, -625, -7100),
    Vector3.new(-2500, -700, -6900),
    Vector3.new(-2850, -720, -6600),
    Vector3.new(-2434, -600, -7374),
    Vector3.new(-2180, -660, -6650),
    Vector3.new(-2740, -700, -7200),
}

local function GetInventoryOres()
    local ores = {}
    local totalCount = 0
    local slot = LocalPlayer:FindFirstChild("Data") and LocalPlayer.Data.SavesSlot:FindFirstChild("1")
    local inv = slot and slot.PlayerData:FindFirstChild("Inventory")
    if inv then
        for _, item in ipairs(inv:GetChildren()) do
            local name = item:GetAttribute("item_name") or item.Name
            if OreSellData.Prices[name] then
                local qty = item:GetAttribute("quantity") or 1
                ores[name] = (ores[name] or 0) + qty
                totalCount = totalCount + qty
            end
        end
    end
    return ores, totalCount
end

local function EnsurePickaxeEquipped()
    local char = GetCharacter()
    if not char then return false end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    
    -- Check tools currently held in character: return weapons/rods/chests to backpack
    local heldPickaxes = {}
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            if not IsPickaxeItem(child) then
                if bp then child.Parent = bp end
            else
                table.insert(heldPickaxes, child)
            end
        end
    end
    
    if #heldPickaxes == 1 then
        return true
    end
    
    local pickTool = heldPickaxes[1]
    if not pickTool and bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if IsPickaxeItem(tool) then
                pickTool = tool
                break
            end
        end
    end
    
    if not pickTool then
        local slot = LocalPlayer:FindFirstChild("Data") and LocalPlayer.Data.SavesSlot:FindFirstChild("1")
        local inv = slot and slot.PlayerData:FindFirstChild("Inventory")
        if inv then
            for _, item in ipairs(inv:GetChildren()) do
                local name = item:GetAttribute("item_name") or item.Name
                if (Pickaxes and Pickaxes.Tools and Pickaxes.Tools[name]) or string.find(name:lower(), "pickaxe") or string.find(name:lower(), "pick") then
                    local uuid = item:GetAttribute("uuid") or item.Name
                    pcall(function()
                        InventoryService:put_in_hotbar(uuid, 2):await()
                    end)
                    task.wait(0.3)
                    if bp and bp:FindFirstChild(name) then
                        pickTool = bp[name]
                        break
                    end
                end
            end
        end
    end
    
    if pickTool then
        EquipOnlyTool(pickTool)
        task.wait(0.2)
        return true
    end
    return false
end

local function BuyPickAxe()
    local hrp = GetHRP()
    if not hrp then return false end
    local oldCF = hrp.CFrame
    hrp.CFrame = CFrame.new(-544.43, 239, -322.40)
    hrp.AssemblyLinearVelocity = Vector3.zero
    task.wait(0.5)
    local success, res = pcall(function()
        return MerchantService:purchase("PickAxe"):await()
    end)
    task.wait(0.5)
    EnsurePickaxeEquipped()
    if oldCF then
        hrp.CFrame = oldCF
        hrp.AssemblyLinearVelocity = Vector3.zero
    end
    return success and res == true
end

local function SellAllOres()
    local ores, totalCount = GetInventoryOres()
    if totalCount == 0 then
        return 0, 0
    end
    
    local hrp = GetHRP()
    if not hrp then return 0, 0 end
    local previousCF = hrp.CFrame
    
    -- Teleport to Ore Merchant
    hrp.CFrame = CFrame.new(-824.6, 274, -405.28)
    hrp.AssemblyLinearVelocity = Vector3.zero
    task.wait(0.5)
    
    local initialJenni = LocalPlayer:GetAttribute("Jenni") or 0
    local soldCount = 0
    
    for oreName, count in pairs(ores) do
        pcall(function()
            MerchantService:sellItem(oreName, count):await()
        end)
        task.wait(0.2)
        soldCount = soldCount + count
    end
    
    task.wait(0.4)
    local finalJenni = LocalPlayer:GetAttribute("Jenni") or initialJenni
    local earned = finalJenni - initialJenni
    if earned > 0 then
        MiningStats.TotalJenniEarned = MiningStats.TotalJenniEarned + earned
    end
    
    -- If was auto mining, return back to previous position in mine
    if Config.AutoMine and previousCF then
        task.wait(0.3)
        hrp.CFrame = previousCF
        hrp.AssemblyLinearVelocity = Vector3.zero
        task.wait(0.4)
    end
    
    return earned, soldCount
end

local function IsHostileMob(model)
    if not model or not model:IsA("Model") or not model.Parent then return false end
    if model == GetCharacter() then return false end
    if Players:GetPlayerFromCharacter(model) ~= nil then return false end
    if not IsAlive(model) then return false end
    
    if model:GetAttribute("NPC") == true or model:GetAttribute("Monster") == true then
        return true
    end
    if table.find(AvailableMobs, model.Name) or table.find(AvailableBosses, model.Name) then
        return true
    end
    return false
end

local function IsMobNearPosition(pos, radius)
    radius = radius or 22
    for _, child in ipairs(workspace:GetChildren()) do
        if IsHostileMob(child) then
            local mHrp = child:FindFirstChild("HumanoidRootPart")
            if mHrp and (mHrp.Position - pos).Magnitude <= radius then
                return true, child
            end
        end
    end
    return false, nil
end

local function DefendAgainstMob(mob)
    local char = GetCharacter()
    local hrp = GetHRP()
    if not char or not hrp or not mob or not IsAlive(mob) then return end
    
    local mobHrp = mob:FindFirstChild("HumanoidRootPart")
    if not mobHrp then return end
    
    -- Stop mining if active
    if char:GetAttribute("Mining") == true then
        pcall(function() MaterialService:StopMine():await() end)
    end
    
    -- Mark active defense target so Noclip and Hover stay active
    activeDefenseTarget = mob
    EnsureWeaponEquipped()
    task.wait(0.1)
    
    local combatTimeout = os.clock() + 45
    while IsAlive(mob) and os.clock() < combatTimeout and Config.AutoMine and (_G.BeyondNenInstanceId == myInstanceId) do
        local dt = task.wait(0.03)
        MiningStats.Status = string.format("Defending! Fighting %s (%d HP)...", mob.Name, math.floor(mob:GetAttribute("Health") or 0))
        AttackTargetEntity(mob, dt)
    end
    
    activeDefenseTarget = nil
    SetHover(false)
    MiningStats.Status = "Mob defeated! Re-equipping pickaxe..."
    task.wait(0.2)
    EnsurePickaxeEquipped()
    task.wait(0.3)
end

local function GetStandPositionForOre(ore)
    local orePos = ore:GetPivot().Position
    local hrp = GetHRP()
    local dir = hrp and (hrp.Position - orePos) or Vector3.new(0, 0, 1)
    dir = Vector3.new(dir.X, 0, dir.Z)
    if dir.Magnitude < 0.1 then
        dir = Vector3.new(0, 0, 1)
    else
        dir = dir.Unit
    end
    return orePos + (dir * 3.5) + Vector3.new(0, 0.8, 0)
end

local function FindTargetOre()
    local hrp = GetHRP()
    if not hrp then return nil, math.huge end
    local pPos = hrp.Position
    
    local targetOre = nil
    local minDistance = math.huge
    local filterName = Config.SelectedOre
    
    -- Priority 1: Streamed in ores with parts
    for _, child in ipairs(workspace:GetChildren()) do
        if (child:GetAttribute("IsMaterial") or OreSellData.Prices[child.Name]) and #child:GetChildren() > 0 then
            if filterName == "All Ores" or child.Name == filterName then
                local orePos = child:GetPivot().Position
                if not (Config.SkipOresWithMobs and IsMobNearPosition(orePos, 22)) then
                    local dist = (orePos - pPos).Magnitude
                    if dist < minDistance then
                        minDistance = dist
                        targetOre = child
                    end
                end
            end
        end
    end
    
    -- Priority 2: Nearest ore model
    if not targetOre then
        for _, child in ipairs(workspace:GetChildren()) do
            if child:GetAttribute("IsMaterial") or OreSellData.Prices[child.Name] then
                if filterName == "All Ores" or child.Name == filterName then
                    local orePos = child:GetPivot().Position
                    if not (Config.SkipOresWithMobs and IsMobNearPosition(orePos, 22)) then
                        local dist = (orePos - pPos).Magnitude
                        if dist < minDistance then
                            minDistance = dist
                            targetOre = child
                        end
                    end
                end
            end
        end
    end
    
    return targetOre, minDistance
end

local function GetWorldChests()
    local list = {}
    local world = workspace:FindFirstChild("World")
    local chests = world and world:FindFirstChild("Chests")
    if chests then
        for _, c in ipairs(chests:GetChildren()) do
            local chestId = c:GetAttribute("Id") or c:GetAttribute("ChestId")
            if chestId then
                table.insert(list, c)
            end
        end
    end
    return list
end

local function LootChestInstance(chest)
    local chestId = chest:GetAttribute("Id") or chest:GetAttribute("ChestId")
    if not chestId then return end
    local hrp = GetHRP()
    if not hrp then return end

    local chestPos = chest:GetPivot().Position
    hrp.CFrame = CFrame.new(chestPos + Vector3.new(0, 3, 3), chestPos)
    hrp.AssemblyLinearVelocity = Vector3.zero
    task.wait(0.25)

    pcall(function()
        ChestService:OpenChest(chestId):await()
    end)
    task.wait(0.25)
    pcall(function()
        ChestService:TakeAll(chestId):await()
    end)
    task.wait(0.15)
    pcall(function()
        ChestService:CloseChest(chestId):await()
    end)
end

-- Complete Automated Chest Opener (Hotbar + Equip + Safezone Bypass + Auto Confirm + Loot)
local function AutoOpenChestPipeline(uuid)
    local char = GetCharacter()
    if not char then return false end

    -- 1. Check Safe Zone: Auto teleport outside Town if needed
    if char:GetAttribute("InNpcSafeZone") == true then
        local hrp = GetHRP()
        if hrp then
            hrp.CFrame = CFrame.new(-3473, 586, -48)
            task.wait(0.6)
        end
    end

    -- 2. Put into Hotbar Slot 2 (Slot 1 is reserved for fists/weapon)
    pcall(function()
        InventoryService:put_in_hotbar(uuid, 2):await()
    end)
    task.wait(0.3)

    -- 3. Equip the tool from Backpack into Character
    local bp = LocalPlayer:FindFirstChild("Backpack")
    local chestTool = nil
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if string.find(t.Name:lower(), "chest") then
                chestTool = t
                break
            end
        end
    end
    if not chestTool and char then
        for _, t in ipairs(char:GetChildren()) do
            if string.find(t.Name:lower(), "chest") then
                chestTool = t
                break
            end
        end
    end

    if chestTool then
        EquipOnlyTool(chestTool)
        task.wait(0.3)
    end

    -- 4. Trigger placement via ChestController
    local cc = require(LocalPlayer.PlayerScripts.Client.Controllers.InventoryController.tools_handlers.ChestController)
    pcall(function()
        cc.on_click()
    end)
    task.wait(0.3)

    -- 5. Auto Confirm QuestionPrompt ("Are you sure you want to use...")
    local qp = PlayerGui:FindFirstChild("QuestionPrompt")
    if qp and qp:FindFirstChild("Host") and qp.Host:FindFirstChild("Panel") and qp.Host.Panel:FindFirstChild("Yes") then
        local yesBtn = qp.Host.Panel.Yes
        if getconnections then
            for _, conn in ipairs(getconnections(yesBtn.Activated)) do
                conn:Fire()
            end
        elseif firesignal then
            firesignal(yesBtn.Activated)
        end
    end
    task.wait(0.8)

    -- 6. Claim loot from the placed chest in workspace.World.Chests
    local world = workspace:FindFirstChild("World")
    local chests = world and world:FindFirstChild("Chests")
    if chests then
        for _, c in ipairs(chests:GetChildren()) do
            if c:GetAttribute("Owner") == LocalPlayer.UserId then
                local chestId = c:GetAttribute("Id") or c:GetAttribute("ChestId")
                if chestId then
                    pcall(function()
                        ChestService:OpenChest(chestId):await()
                    end)
                    task.wait(0.3)
                    pcall(function()
                        ChestService:TakeAll(chestId):await()
                    end)
                    task.wait(0.2)
                    pcall(function()
                        ChestService:CloseChest(chestId):await()
                    end)
                    WindUI:Notify({
                        Title = "Chest Looted!",
                        Content = "Successfully claimed all loot from " .. c.Name,
                        Duration = 4,
                    })
                    return true
                end
            end
        end
    end
    return false
end

-- ========================================================
-- EVENT LISTENERS
-- ========================================================

-- Auto take all whenever any chest opens
RegisterConnection(ChestService.OpenedChest:Connect(function(chestId)
    if Config.AutoLootChests or Config.AutoOpenInventoryChests then
        task.wait(0.1)
        pcall(function()
            ChestService:TakeAll(chestId):await()
        end)
        task.wait(0.15)
        pcall(function()
            ChestService:CloseChest(chestId):await()
        end)
    end
end))

-- Meditation Solvers
RegisterConnection(MeditationService.CreateBubble:Connect(function(bubbleId)
    if Config.AutoSolveMinigame and bubbleId then
        task.wait(0.04)
        pcall(function()
            MeditationService:meditationSphreClick(bubbleId)
        end)
    end
end))

RegisterConnection(MeditationService.KeyPrompt:Connect(function(active)
    if Config.AutoSolveMinigame and active and active.id then
        task.wait(0.04)
        pcall(function()
            MeditationService:KeyPromptResult(active.id, true)
        end)
    end
end))

RegisterConnection(MeditationService.GamePrompt:Connect(function(active)
    if Config.AutoSolveMinigame and active and active.id then
        task.wait(0.04)
        pcall(function()
            MeditationService.GameInput:Fire(active.id, true)
        end)
    end
end))

-- Fishing Controller Sync Helper (keeps native UI & animations synced and prevents input interference)
local FishingControllerRef = pcall(function() return knit.GetController("FishingController") end) and knit.GetController("FishingController") or nil
local function SyncFishingControllerState(stateStr, castIdVal, biteDataVal, reelVal, holdingVal)
    if not FishingControllerRef or not FishingControllerRef.on_equip or not debug or not debug.setupvalue then return end
    pcall(function()
        if stateStr ~= nil then debug.setupvalue(FishingControllerRef.on_equip, 4, stateStr) end
        if castIdVal ~= nil then debug.setupvalue(FishingControllerRef.on_equip, 5, castIdVal) end
        if biteDataVal ~= nil then debug.setupvalue(FishingControllerRef.on_equip, 6, biteDataVal) end
        if reelVal ~= nil then debug.setupvalue(FishingControllerRef.on_equip, 7, reelVal) end
        if holdingVal ~= nil then debug.setupvalue(FishingControllerRef.on_equip, 8, holdingVal) end
    end)
end

-- Fishing Minigame Solver Listeners (High-Speed Predictive Solver + Multi-Confirm Start)
RegisterConnection(FishingService.Bite:Connect(function(castId, biteData)
    if not Config.AutoSolveFishing and not Config.AutoFishing then return end
    if typeof(biteData) ~= "table" or typeof(biteData.Goals) ~= "table" then return end

    currentCastId = castId
    isFishingCastActive = true
    isFishingBiting = true
    lastFishingActivity = os.clock()
    FishingStats.Status = string.format("Fish Biting! [%s] Fast Reeling...", tostring(biteData.Tier or "Common"))

    local reel = FishingReel.New(biteData.Tier, biteData.Goals, biteData.GoalWidth, FishingConfig.GoalShrink)
    local startTime = os.clock()
    local isHolding = true
    local lastToggleTime = 0
    local lastKeepAliveTime = 0

    if activeReelConn then
        activeReelConn:Disconnect()
        activeReelConn = nil
    end

    -- 1. Immediate StartReel fire + redundant confirmations so server NEVER misses the bite
    pcall(function()
        FishingReel.SetHolding(reel, 0, true)
        FishingService.Hold:Fire(castId, true)
    end)
    SyncFishingControllerState("Reeling", castId, biteData, reel, true)

    task.spawn(function()
        for _, delaySec in ipairs({ 0.04, 0.08, 0.13 }) do
            task.wait(delaySec)
            if not isFishingBiting or currentCastId ~= castId then return end
            pcall(function()
                if isHolding then
                    FishingService.Hold:Fire(castId, true)
                end
            end)
        end
    end)

    -- 2. High-Speed Predictive Lookahead Solver Loop
    activeReelConn = RegisterConnection(RunService.Heartbeat:Connect(function()
        if currentCastId ~= castId or (not isFishingBiting and not isFishingCastActive) then
            if activeReelConn then
                activeReelConn:Disconnect()
                activeReelConn = nil
            end
            return
        end

        local elapsed = os.clock() - startTime
        if elapsed > (reel.Tier.Time + 2.5) then
            isFishingBiting = false
            isFishingCastActive = false
            if activeReelConn then
                activeReelConn:Disconnect()
                activeReelConn = nil
            end
            return
        end

        lastFishingActivity = os.clock()
        FishingReel.Advance(reel, elapsed)

        local targetPos, targetSpan = FishingReel.GoalSpan(reel, elapsed)
        local barWidth = FishingConfig.Bar.Width
        local barLeft = FishingReel.BarLeft(reel.Value)
        local curCenter = barLeft + (barWidth * 0.5)

        -- Lookahead to next goal right before reroll while staying 100% inside current goal
        local rerollPeriod = reel.Tier.Reroll or 5
        local timeInPeriod = elapsed % rerollPeriod
        local timeToNext = rerollPeriod - timeInPeriod
        local nextIdx = math.min(math.floor(elapsed / rerollPeriod) + 2, #biteData.Goals)
        local nextGoal = biteData.Goals[nextIdx]

        local aimCenter = targetPos + (targetSpan * 0.5)
        if timeToNext < 0.22 and nextGoal then
            if nextGoal > targetPos then
                aimCenter = targetPos + (targetSpan * 0.80)
            else
                aimCenter = targetPos + (targetSpan * 0.20)
            end
        end

        -- Velocity-aware braking band so fast rising/falling bars settle inside narrow goals without overshooting
        local phaseTime = math.max(0, reel.Clock - reel.PhaseStart)
        local brakeOffset = 0
        if isHolding and phaseTime > 0.20 then
            brakeOffset = -math.min(targetSpan * 0.18, phaseTime * 0.03)
        elseif (not isHolding) and phaseTime > 0.25 then
            brakeOffset = math.min(targetSpan * 0.15, phaseTime * 0.02)
        end

        local effectiveAim = aimCenter + brakeOffset
        local band = math.max(targetSpan * 0.12, 0.005)

        local shouldHold = isHolding
        if elapsed < 0.12 then
            -- Always hold during initial 120ms launch from 0.02 (lowest possible goal is >= 0.05)
            shouldHold = true
        elseif curCenter < (effectiveAim - band) then
            shouldHold = true
        elseif curCenter > (effectiveAim + band) then
            shouldHold = false
        end

        -- State transition fire (rate-limited to <= 25 msgs/sec, well under server's 30 msgs/sec cap)
        if shouldHold ~= isHolding and (elapsed - lastToggleTime) >= 0.04 then
            isHolding = shouldHold
            lastToggleTime = elapsed
            lastKeepAliveTime = elapsed
            FishingReel.SetHolding(reel, elapsed, isHolding)
            SyncFishingControllerState("Reeling", castId, biteData, reel, isHolding)
            pcall(function()
                FishingService.Hold:Fire(castId, isHolding, elapsed)
            end)
        elseif (elapsed - lastKeepAliveTime) >= 0.18 then
            -- Periodic keep-alive sync: heals any dropped packet or mouse-click interference without resetting PhaseStart
            lastKeepAliveTime = elapsed
            SyncFishingControllerState("Reeling", castId, biteData, reel, isHolding)
            pcall(function()
                FishingService.Hold:Fire(castId, isHolding, elapsed)
            end)
        end

        local pct = math.clamp(math.floor(FishingReel.Progress(reel) * 100 + 0.5), 0, 100)
        FishingStats.Status = string.format("Reeling [%s]: %d%%", tostring(biteData.Tier or "Fish"), pct)
    end))
end))

RegisterConnection(FishingService.Result:Connect(function(castId, resultData)
    if currentCastId and castId and castId ~= currentCastId then
        return
    end
    if activeReelConn then
        activeReelConn:Disconnect()
        activeReelConn = nil
    end
    isFishingBiting = false
    isFishingCastActive = false
    currentCastId = nil
    SyncFishingControllerState("Idle", nil, nil, nil, false)
    
    local outcome = (typeof(resultData) == "table" and resultData.Outcome) or "Done"
    if outcome == "Caught" then
        FishingStats.TotalFished = FishingStats.TotalFished + 1
        local fishName = (typeof(resultData.Fish) == "table" and resultData.Fish.Name) or (resultData.Fish and tostring(resultData.Fish)) or "Fish"
        if string.find(string.lower(tostring(fishName)), "chest") then
            FishingStats.ChestCount = FishingStats.ChestCount + 1
        else
            FishingStats.FishCount = FishingStats.FishCount + 1
        end
        FishingStats.Status = "Caught: " .. tostring(fishName) .. "!"
        WindUI:Notify({
            Title = "Fishing Success!",
            Content = "You reeled in: " .. tostring(fishName),
            Duration = 2.5,
        })
    else
        FishingStats.Status = "Outcome: " .. tostring(outcome)
    end
end))

local function CheckAndUpgradeTiers()
    if not Config.AutoUpgradeTier then return end
    for _, tech in ipairs(NenTechniques) do
        local currentTier = LocalPlayer:GetAttribute("NenTier_" .. tech) or 0
        local currentXP = LocalPlayer:GetAttribute("NenXP_" .. tech) or 0
        if currentTier < 5 then
            local nextThreshold = TierThresholds[currentTier + 1] or 3500
            if currentXP >= nextThreshold then
                pcall(function()
                    NenMasteryService:UpgradeTier(tech)
                end)
            end
        end
    end
end

-- ========================================================
-- BACKGROUND LOOPS
-- ========================================================

-- ========================================================
-- TAB 7: MOVEMENT, FLY & INFINITE CHEATS
-- ========================================================
local flyBodyVel = nil
local flyBodyGyro = nil

local function UpdateFlyPhysics(enabled)
    local char = GetCharacter()
    local hrp = GetHRP()
    if not char or not hrp then return end
    
    if enabled then
        if not flyBodyVel or not flyBodyVel.Parent then
            flyBodyVel = Instance.new("BodyVelocity")
            flyBodyVel.Name = "BeyondNenFlyVel"
            flyBodyVel.MaxForce = Vector3.new(1e6, 1e6, 1e6)
            flyBodyVel.Velocity = Vector3.zero
            flyBodyVel.Parent = hrp
        end
        if not flyBodyGyro or not flyBodyGyro.Parent then
            flyBodyGyro = Instance.new("BodyGyro")
            flyBodyGyro.Name = "BeyondNenFlyGyro"
            flyBodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
            flyBodyGyro.P = 10000
            flyBodyGyro.CFrame = hrp.CFrame
            flyBodyGyro.Parent = hrp
        end
    else
        if flyBodyVel then
            pcall(function() flyBodyVel:Destroy() end)
            flyBodyVel = nil
        end
        if flyBodyGyro then
            pcall(function() flyBodyGyro:Destroy() end)
            flyBodyGyro = nil
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.PlatformStand = false
        end
    end
end

-- Fly Movement Step
RegisterConnection(RunService.RenderStepped:Connect(function()
    if Config.Fly and GetCharacter() and GetHRP() then
        local hrp = GetHRP()
        local camera = workspace.CurrentCamera
        local moveDir = Vector3.zero
        
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveDir = moveDir + camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveDir = moveDir - camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveDir = moveDir - camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveDir = moveDir + camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDir = moveDir + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            moveDir = moveDir - Vector3.new(0, 1, 0)
        end
        
        if not flyBodyVel or not flyBodyVel.Parent then
            UpdateFlyPhysics(true)
        end
        
        if flyBodyVel and flyBodyVel.Parent then
            if moveDir.Magnitude > 0 then
                flyBodyVel.Velocity = moveDir.Unit * (Config.FlySpeed or 50)
            else
                flyBodyVel.Velocity = Vector3.zero
            end
        end
        if flyBodyGyro and flyBodyGyro.Parent then
            flyBodyGyro.CFrame = camera.CFrame
        end
    elseif not Config.Fly and flyBodyVel then
        UpdateFlyPhysics(false)
    end
end))

-- Jump & Infinite Jump Listener (Bypasses MovementController reset)
RegisterConnection(UserInputService.JumpRequest:Connect(function()
    local char = GetCharacter()
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
    if not hum or not hrp then return end

    if Config.InfiniteJump then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
        local jumpVal = Config.EnableCustomJumpPower and Config.CustomJumpPower or 55
        hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, jumpVal, hrp.AssemblyLinearVelocity.Z)
    elseif Config.EnableCustomJumpPower then
        hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, Config.CustomJumpPower, hrp.AssemblyLinearVelocity.Z)
    end
end))

-- TP Walk (Teleport Walk / CFrame Speed) Loop
RegisterConnection(RunService.Heartbeat:Connect(function(dt)
    if Config.TPWalk then
        local char = GetCharacter()
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
        if hum and hrp and hum.MoveDirection.Magnitude > 0 then
            local stepSpeed = (Config.TPWalkSpeed or 2.5) * 16 * dt
            hrp.CFrame = hrp.CFrame + (hum.MoveDirection * stepSpeed)
        end
    end
end))

-- Movement Modifiers Loop (Stamina, Oxygen, WalkSpeed, JumpPower)
task.spawn(function()
    while _G.BeyondNenInstanceId == myInstanceId do
        task.wait(0.3)
        
        if Config.InfiniteStamina then
            pcall(function()
                LocalPlayer:SetAttribute("Stamina", 100)
            end)
        end
        
        if Config.InfiniteOxygen then
            pcall(function()
                LocalPlayer:SetAttribute("Oxygen", 100)
                if MovementService and MovementService.RegenOxygen then
                    MovementService:RegenOxygen():await()
                end
            end)
        end
        
        local char = GetCharacter()
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            if Config.EnableCustomWalkSpeed then
                if hum.WalkSpeed ~= Config.CustomWalkSpeed then
                    hum.WalkSpeed = Config.CustomWalkSpeed
                end
            end
            if Config.EnableCustomJumpPower then
                if hum.UseJumpPower then
                    if hum.JumpPower ~= Config.CustomJumpPower then
                        hum.JumpPower = Config.CustomJumpPower
                    end
                else
                    if hum.JumpHeight ~= Config.CustomJumpPower then
                        hum.JumpHeight = Config.CustomJumpPower
                    end
                end
            end
        end
    end
end)

-- Noclip Loop
RegisterConnection(RunService.Stepped:Connect(function()
    if (Config.Noclip or Config.Fly or Config.AutoLevelFarm or Config.AutoFarmMob or Config.AutoFarmBoss or Config.AutoMeditation or Config.AutoLootChests or activeDefenseTarget ~= nil) and GetCharacter() then
        for _, part in ipairs(GetCharacter():GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end))

-- Auto Respawn on Death Loop
task.spawn(function()
    while _G.BeyondNenInstanceId == myInstanceId do
        task.wait(0.4)
        if Config.AutoRespawn and IsPlayerDead() then
            SetHover(false)
            local unlockAt = LocalPlayer:GetAttribute("RespawnUnlockAt")
            local now = workspace:GetServerTimeNow()
            if typeof(unlockAt) == "number" and unlockAt > now then
                local rem = math.ceil(unlockAt - now)
                QuestsStats.LastAction = string.format("Dead! Waiting %ds to Auto Respawn...", rem)
            else
                QuestsStats.LastAction = "Triggering Auto Respawn..."
                TriggerPlayerRespawn()
            end
        end
    end
end)

-- Main Farm Loop
RegisterConnection(RunService.Heartbeat:Connect(function(dt)
    if isBoardInteractionBusy then return end
    if IsPlayerDead() then
        SetHover(false)
        return
    end
    local isFarming = Config.AutoLevelFarm or Config.AutoFarmMob or Config.AutoFarmBoss
    if isFarming and not Config.AutoMeditation and not Config.AutoLootChests and not activeDefenseTarget then
        local targetName = Config.AutoFarmBoss and Config.SelectedBoss or Config.SelectedMob
        local target = GetTarget(targetName)

        if target and target:FindFirstChild("HumanoidRootPart") and IsAlive(target) then
            AttackTargetEntity(target, dt)
        else
            -- Target not found in workspace (outside streaming distance or waiting to spawn)
            local hrp = GetHRP()
            local spawnPos = GetMobSpawnPoint(targetName)
            if hrp and spawnPos then
                local distToSpawn = (spawnPos - hrp.Position).Magnitude
                if distToSpawn > 25 then
                    SetHover(true)
                    if os.clock() - lastSpawnStreamTime > 1.5 then
                        lastSpawnStreamTime = os.clock()
                        task.spawn(function()
                            pcall(function() LocalPlayer:RequestStreamAroundAsync(spawnPos, 2) end)
                        end)
                    end
                    -- If crossing between Surface (Y > -100) and Mines (Y < -200), warp directly to avoid solid terrain wall
                    local crossingMineBoundary = (spawnPos.Y < -200 and hrp.Position.Y > -100) or (spawnPos.Y > -100 and hrp.Position.Y < -200)
                    local approachCFrame = CFrame.new(spawnPos + Vector3.new(0, 8, 0), spawnPos)
                    if crossingMineBoundary then
                        hrp.CFrame = approachCFrame
                        hrp.AssemblyLinearVelocity = Vector3.zero
                    else
                        MoveToTarget(approachCFrame, dt)
                    end
                else
                    SetHover(false)
                end
            else
                SetHover(false)
            end
        end
    elseif not activeDefenseTarget and not Config.AutoMeditation and not Config.AutoLootChests then
        SetHover(false)
    end
end))

-- Fast Attack Loop
task.spawn(function()
    while _G.BeyondNenInstanceId == myInstanceId do
        task.wait(Config.AttackDelay)
        if Config.FastAttack and not (Config.AutoLevelFarm or Config.AutoFarmMob or Config.AutoFarmBoss or Config.AutoMeditation) then
            DoM1Attack()
        end
    end
end)

-- Auto Meditation Loop
task.spawn(function()
    while _G.BeyondNenInstanceId == myInstanceId do
        task.wait(1)
        if Config.AutoMeditation then
            local char = GetCharacter()
            local isMeditating = char and char:GetAttribute("meditating") == true

            if not isMeditating then
                local hrp = GetHRP()
                if hrp then
                    pcall(function()
                        MeditationService:PlaceCarpet(hrp.Position - Vector3.new(0, 2.5, 0)):await()
                    end)
                    task.wait(0.5)
                    pcall(function()
                        MeditationService:StartMeditation():await()
                    end)
                end
            end
            CheckAndUpgradeTiers()
        end
    end
end)

-- Auto Roll Affinity Loop
task.spawn(function()
    while _G.BeyondNenInstanceId == myInstanceId do
        task.wait(1.5)
        if Config.AutoRollAffinity then
            local currentAffinity = LocalPlayer:GetAttribute("NenAffinity")
            if currentAffinity and currentAffinity ~= Config.TargetAffinity then
                pcall(function()
                    NenService:roll_nen_affinity()
                end)
            else
                Config.AutoRollAffinity = false
                WindUI:Notify({
                    Title = "Nen Affinity Rolled!",
                    Content = "Target reached: " .. tostring(currentAffinity),
                    Duration = 5,
                })
            end
        end
    end
end)

-- Auto Loot World Chests Loop
task.spawn(function()
    while _G.BeyondNenInstanceId == myInstanceId do
        task.wait(1)
        if Config.AutoLootChests then
            local worldChests = GetWorldChests()
            for _, chest in ipairs(worldChests) do
                if not Config.AutoLootChests or _G.BeyondNenInstanceId ~= myInstanceId then break end
                local owner = chest:GetAttribute("Owner")
                local ownerOnly = chest:GetAttribute("OwnerOnly")
                local canLoot = (owner == nil or owner == LocalPlayer.UserId or ownerOnly ~= true)
                if canLoot and chest.Parent then
                    LootChestInstance(chest)
                    task.wait(0.5)
                end
            end
        end
    end
end)

-- Auto Open All Inventory Chests Loop
task.spawn(function()
    while _G.BeyondNenInstanceId == myInstanceId do
        task.wait(2)
        if Config.AutoOpenInventoryChests then
            local invChests = GetInventoryChests()
            if #invChests > 0 then
                local chest = invChests[1]
                AutoOpenChestPipeline(chest.uuid)
                task.wait(1.5)
            else
                Config.AutoOpenInventoryChests = false
                WindUI:Notify({
                    Title = "All Chests Opened!",
                    Content = "No more chests remaining in your inventory.",
                    Duration = 5,
                })
            end
        end
    end
end)

-- Expose state for external diagnostics
_G.BeyondNenConfig = Config
_G.BeyondNenFishingStats = FishingStats
_G.BeyondNenMiningStats = MiningStats

-- Auto Fishing Loop (High-Speed Cast & Zero Dead-Time Re-Cast)
task.spawn(function()
    local busyRetryCount = 0
    while _G.BeyondNenInstanceId == myInstanceId do
        task.wait(0.1)
        if Config.AutoFishing then
            if isFishingBiting then
                -- Do not touch tools or position while actively reeling a fish
                task.wait(0.1)
            else
                local hasRod = EnsureRodEquipped()
                if not hasRod then
                    FishingStats.Status = "No Fishing Rod equipped! Claiming from Fisherman Hal..."
                    ClaimFreeRodFromHal()
                    task.wait(1.5)
                else
                    local standCF, waterPos, spotName = GetTargetFishingSpot()

                    if standCF and waterPos then
                        local hrp = GetHRP()
                        if hrp and Config.AutoTeleportToFishingSpot then
                            local dist = (hrp.Position - standCF.Position).Magnitude
                            if dist > 6 then
                                pcall(function()
                                    LocalPlayer:RequestStreamAroundAsync(waterPos, 2)
                                end)
                                hrp.CFrame = standCF
                                hrp.AssemblyLinearVelocity = Vector3.zero
                                task.wait(0.35)
                            end
                        end

                        if not isFishingCastActive and not isFishingBiting then
                            -- Stabilize character facing water so "Moved" cancellation never triggers
                            if hrp then
                                hrp.AssemblyLinearVelocity = Vector3.zero
                                local flatTarget = Vector3.new(waterPos.X, hrp.Position.Y, waterPos.Z)
                                if (flatTarget - hrp.Position).Magnitude > 0.2 then
                                    hrp.CFrame = CFrame.lookAt(hrp.Position, flatTarget)
                                end
                            end

                            FishingStats.Status = "Casting line into " .. spotName .. "..."
                            local success, canFish, castId = FishingService:Cast(waterPos):await()
                            if success and canFish then
                                busyRetryCount = 0
                                isFishingCastActive = true
                                currentCastId = castId
                                lastFishingActivity = os.clock()
                                SyncFishingControllerState("Waiting", castId, nil, nil, false)
                                FishingStats.Status = "Line in water... waiting for bite!"

                                while isFishingCastActive and Config.AutoFishing and (_G.BeyondNenInstanceId == myInstanceId) do
                                    task.wait(0.1)
                                    local maxIdle = isFishingBiting and 18 or 16
                                    if (os.clock() - lastFishingActivity) > maxIdle then
                                        break
                                    end
                                end

                                if isFishingCastActive and not isFishingBiting then
                                    pcall(function() FishingService:Reel(castId):await() end)
                                    isFishingCastActive = false
                                    currentCastId = nil
                                end
                                task.wait(0.15)
                            else
                                local reason = tostring(castId)
                                if reason == "cooldown" then
                                    FishingStats.Status = "Cooldown... fast retrying"
                                    task.wait(0.15)
                                elseif reason == "busy" then
                                    if isFishingBiting then
                                        task.wait(0.2)
                                    else
                                        busyRetryCount = busyRetryCount + 1
                                        pcall(function() FishingService:Reel(currentCastId or 0):await() end)
                                        if busyRetryCount >= 3 then
                                            busyRetryCount = 0
                                            local char = GetCharacter()
                                            local hum = char and char:FindFirstChildOfClass("Humanoid")
                                            if hum then
                                                hum:UnequipTools()
                                                task.wait(0.4)
                                                EnsureRodEquipped()
                                                task.wait(0.3)
                                            end
                                        else
                                            task.wait(0.35)
                                        end
                                    end
                                elseif reason == "not water" then
                                    pcall(function()
                                        LocalPlayer:RequestStreamAroundAsync(waterPos, 2)
                                    end)
                                    FishingStats.Status = "Streaming water surface..."
                                    task.wait(0.4)
                                else
                                    FishingStats.Status = "Cast retry (" .. reason .. ")"
                                    task.wait(0.35)
                                end
                            end
                        end
                    else
                        FishingStats.Status = "No valid fishing spot found!"
                        task.wait(1)
                    end
                end
            end
        end
    end
end)

-- Auto Mining Loop
task.spawn(function()
    local clusterIndex = 1
    while _G.BeyondNenInstanceId == myInstanceId do
        task.wait(0.35)
        if Config.AutoMine then
            local char = GetCharacter()
            local hrp = GetHRP()
            if char and hrp then
                -- 1. Ensure Pickaxe is equipped
                local hasPick = EnsurePickaxeEquipped()
                if not hasPick then
                    MiningStats.Status = "No PickAxe! Buying from store..."
                    local bought = BuyPickAxe()
                    if not bought then
                        MiningStats.Status = "Need 500 Jenni to buy PickAxe!"
                        task.wait(2.5)
                    end
                else
                    -- 2. Check Auto Sell threshold
                    if Config.AutoSellOres then
                        local _, oreCount = GetInventoryOres()
                        if oreCount >= Config.AutoSellOreThreshold then
                            MiningStats.Status = string.format("Selling %d ores at Merchant...", oreCount)
                            SellAllOres()
                            task.wait(0.5)
                        end
                    end
                    
                    -- 3. Check if inside Mines Area
                    if not MinesArea.PlayerInside(LocalPlayer) then
                        MiningStats.Status = "Teleporting into Mines..."
                        hrp.CFrame = CFrame.new(MinesArea.ExitPosition + Vector3.new(0, 3, 10))
                        hrp.AssemblyLinearVelocity = Vector3.zero
                        task.wait(1)
                    end
                    
                    -- Check for nearby mob threats if defense is enabled
                    if Config.MineDefendMobs then
                        local hasThreat, threatMob = IsMobNearPosition(hrp.Position, 22)
                        if hasThreat and threatMob and IsAlive(threatMob) then
                            DefendAgainstMob(threatMob)
                        end
                    end
                    
                    -- 4. Find target ore
                    local targetOre, dist = FindTargetOre()
                    if targetOre then
                        MiningStats.CurrentTarget = targetOre.Name
                        local orePos = targetOre:GetPivot().Position
                        
                        -- If mob is guarding target ore and defense is enabled, defeat it first
                        if Config.MineDefendMobs then
                            local hasGuard, guardMob = IsMobNearPosition(orePos, 20)
                            if hasGuard and guardMob and IsAlive(guardMob) then
                                DefendAgainstMob(guardMob)
                            end
                        end
                        
                        -- Move to ore if not in mining range (approx 3.5 - 4 studs)
                        if dist > 4.5 then
                            local standPos = GetStandPositionForOre(targetOre)
                            if Config.MineTravelMode == "Tween" and TweenTo then
                                MiningStats.Status = "Traveling to " .. targetOre.Name .. "..."
                                TweenTo(standPos, Config.TweenSpeed)
                            else
                                hrp.CFrame = CFrame.lookAt(standPos, orePos)
                                hrp.AssemblyLinearVelocity = Vector3.zero
                                task.wait(0.2)
                            end
                        end
                        
                        -- Turn character directly towards ore
                        hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(orePos.X, hrp.Position.Y, orePos.Z))
                        hrp.AssemblyLinearVelocity = Vector3.zero
                        
                        -- Invoke Mining
                        MiningStats.Status = "Mining " .. targetOre.Name .. "..."
                        local ok, res = pcall(function()
                            return MaterialService:Mine():await()
                        end)
                        
                        -- Wait for mining cycle to complete (usually 2 - 2.5 seconds)
                        local mineTimeout = os.clock() + 4.5
                        while (char:GetAttribute("Mining") == true) and os.clock() < mineTimeout and Config.AutoMine and (_G.BeyondNenInstanceId == myInstanceId) do
                            if Config.MineDefendMobs then
                                local hasAttacker, attackerMob = IsMobNearPosition(hrp.Position, 16)
                                if hasAttacker and attackerMob and IsAlive(attackerMob) then
                                    DefendAgainstMob(attackerMob)
                                    break
                                end
                            end
                            task.wait(0.2)
                        end
                        
                        if ok and res then
                            MiningStats.OresMined = MiningStats.OresMined + 1
                        end
                        task.wait(0.3)
                    else
                        -- Stream in ores by moving between clusters
                        MiningStats.Status = string.format("Scanning mine for ores (Zone %d)...", clusterIndex)
                        local clusterPos = MineClusters[clusterIndex]
                        if clusterPos then
                            hrp.CFrame = CFrame.new(clusterPos)
                            hrp.AssemblyLinearVelocity = Vector3.zero
                        end
                        clusterIndex = (clusterIndex % #MineClusters) + 1
                        task.wait(1.5)
                    end
                end
            end
        else
            if MiningStats.Status ~= "Idle" and MiningStats.Status ~= "Stopped" then
                MiningStats.Status = "Idle"
            end
        end
    end
end)

-- ========================================================
-- TAB 6: QUESTS, MILESTONES, STORYLINES & LEVEL FARM BACKEND
-- ========================================================
local QuestsStats = {
    ActiveCount = 0,
    ActiveQuestsList = "None",
    CompletedCount = 0,
    LastAction = "Idle",
    TotalCollected = 0,
    TotalMilestonesClaimed = 0,
    TotalStorylineClaimed = 0,
    CurrentLevelBracket = "Idle",
}

-- Complete Verified Database of All 9 Official Quest Boards + Fisherman Hal
local IslandQuestBoards = {
    {
        Id = "WhaleIslandTown",
        BoardId = "WhaleIslandTown",
        Name = "1. Whale Island Town Board [Lv. 1-10] (ในเมืองเกาะปลาวาฬ)",
        InternalName = "Whale Island Town Quest Board",
        Npc = "Sarah",
        NpcPosition = Vector3.new(-845.4, 267.8, -317.6),
        Position = Vector3.new(-835.94, 269.35, -317.10),
        Island = "Whale Island Town",
        LvMin = 1,
        LvMax = 10,
        Quests = { "KillForestBrawler", "KillCaveBrawler" },
    },
    {
        Id = "CrimsonCamp",
        BoardId = "CrimsonCamp",
        Name = "2. Crimson Camp Board [Lv. 10-15] (ค่ายคริมสัน)",
        InternalName = "Crimson Camp Quest Board",
        Npc = "Zeal",
        NpcPosition = Vector3.new(-1946.0, 280.2, 189.8),
        Position = Vector3.new(-1946.46, 281.70, 197.24),
        Island = "Crimson Camp",
        LvMin = 10,
        LvMax = 15,
        Quests = { "KillPhantomRaider", "KillCrimsonFlame" },
    },
    {
        Id = "Farm",
        BoardId = "Farm",
        Name = "3. Farm Quest Board [Lv. 15-25] (ฟาร์มเกษตร)",
        InternalName = "Farm Quest Board",
        Npc = "Roger",
        NpcPosition = Vector3.new(-2154.5, 195.5, -885.9),
        Position = Vector3.new(-2161.17, 196.36, -890.73),
        Island = "Farm",
        LvMin = 15,
        LvMax = 25,
        Quests = { "KillAngryFarmer", "KillFarmKeeper", "KillChiefFarmer", "KillFoxBear" },
    },
    {
        Id = "BlickCastle",
        BoardId = "BlickCastle",
        Name = "4. Blick Castle Board [Lv. 25-40] (ปราสาทบลิค)",
        InternalName = "Blick Castle Quest board",
        Npc = "Nora",
        NpcPosition = Vector3.new(-3696.9, 548.3, 420.3),
        Position = Vector3.new(-3702.89, 549.71, 420.27),
        Island = "Blick Castle",
        LvMin = 25,
        LvMax = 40,
        Quests = { "KillPortInvader", "KillPortMarksman", "KillBlackBlick" },
    },
    {
        Id = "Mines",
        BoardId = "Mines",
        Name = "5. Mines Quest Board [Lv. 25-60] (ภายในเหมืองใต้ดิน)",
        InternalName = "Mines Quest Board",
        Npc = "Jacob",
        NpcPosition = Vector3.new(-2223.2, -660.0, -7206.1),
        Position = Vector3.new(-2215.32, -658.39, -7206.08),
        Island = "Mines Cavern",
        LvMin = 25,
        LvMax = 60,
        Quests = { "KillGreenGoblin", "KillZombie", "KillBigZombie", "KillStoneSoldier", "KillMoleRat", "KillStoneEye" },
    },
    {
        Id = "WhaleIslandBeach",
        BoardId = "WhaleIslandBeach",
        Name = "6. Whale Island Beach Board [Lv. 40-55] (ชายหาดเกาะปลาวาฬ)",
        InternalName = "Whale Island Beach Quest Board",
        Npc = "Kato",
        NpcPosition = Vector3.new(-5715.7, 359.5, 1336.0),
        Position = Vector3.new(-5716.46, 361.05, 1344.16),
        Island = "Whale Island Beach",
        LvMin = 40,
        LvMax = 55,
        Quests = { "KillBeachBrawler", "KillBeachWarrior", "KillSandyStorm", "KillBeachKing" },
    },
    {
        Id = "DeepForest",
        BoardId = "DeepForest",
        Name = "7. Deep Forest Board [Lv. 60-65] (ป่าลึก)",
        InternalName = "Deep Forest Quest Board",
        Npc = "Lily",
        NpcPosition = Vector3.new(-3295.5, 156.6, -2018.2),
        Position = Vector3.new(-3301.82, 157.79, -2021.10),
        Island = "Deep Forest",
        LvMin = 60,
        LvMax = 65,
        Quests = { "KillFoxBearHunter", "KillLostHunter" },
    },
    {
        Id = "Swamp",
        BoardId = "Swamp",
        Name = "8. Swamp Quest Board [Lv. 65-75] (บึงหนองน้ำ)",
        InternalName = "Swamp Quest board",
        Npc = "Victor",
        NpcPosition = Vector3.new(-4438.4, -39.8, -2966.1),
        Position = Vector3.new(-4444.17, -38.15, -2976.38),
        Island = "Swamp",
        LvMin = 65,
        LvMax = 75,
        Quests = { "KillSwampViper", "KillPurpleViper", "KillMasterOfTheSwamp" },
    },
    {
        Id = "VolcanicArea",
        BoardId = "VolcanicArea",
        Name = "9. Volcanic Area Board [Lv. 75-100] (ภูเขาไฟ)",
        InternalName = "Volcanic Area Quest Board",
        Npc = "Florence",
        NpcPosition = Vector3.new(-2227.7, 379.9, -2676.8),
        Position = Vector3.new(-2225.52, 382.00, -2668.02),
        Island = "Volcanic Area",
        LvMin = 75,
        LvMax = 100,
        Quests = { "KillCrimsonSwordsman", "KillFlameWorshipper", "KillVolcanoWarrior", "KillFireSpirits", "KillDrakolith" },
    },
    {
        Id = "Whale_Hal",
        BoardId = "Whale_Hal",
        Name = "10. Fisherman Hal [Fishing Quest] (คุณตา Hal ริมทะเลสาบ)",
        InternalName = "FishingLesson",
        Npc = "Hal",
        NpcPosition = Vector3.new(-2836.94, 222.0, -750.0),
        Position = Vector3.new(-2836.94, 222.0, -750.0),
        Island = "Deep Forest Lake",
        LvMin = 1,
        LvMax = 100,
        Quests = { "FishingLesson" },
    },
}

-- Complete Mapping of All 30 Quest Mobs & Bosses -> Exact Quest & Board
local MobToBoardMap = {
    -- 1. Whale Island Town (Lv. 1-10)
    ["Forest Brawler"] = {
        MobName = "Forest Brawler",
        QuestName = "KillForestBrawler",
        BoardId = "WhaleIslandTown",
        Name = "Whale Island Town Quest Board",
        InternalName = "Whale Island Town Quest Board",
        Npc = "Sarah",
        NpcPosition = Vector3.new(-845.4, 267.8, -317.6),
        Position = Vector3.new(-835.94, 269.35, -317.10),
        TargetCount = 4, Xp = 150, Money = 55, LvMin = 1, LvMax = 5, IsBoss = false,
    },
    ["Cave Brawler"] = {
        MobName = "Cave Brawler",
        QuestName = "KillCaveBrawler",
        BoardId = "WhaleIslandTown",
        Name = "Whale Island Town Quest Board",
        InternalName = "Whale Island Town Quest Board",
        Npc = "Sarah",
        NpcPosition = Vector3.new(-845.4, 267.8, -317.6),
        Position = Vector3.new(-835.94, 269.35, -317.10),
        TargetCount = 4, Xp = 200, Money = 65, LvMin = 5, LvMax = 10, IsBoss = false,
    },
    -- 2. Crimson Camp (Lv. 10-15)
    ["Phantom Raider"] = {
        MobName = "Phantom Raider",
        QuestName = "KillPhantomRaider",
        BoardId = "CrimsonCamp",
        Name = "Crimson Camp Quest Board",
        InternalName = "Crimson Camp Quest Board",
        Npc = "Zeal",
        NpcPosition = Vector3.new(-1946.0, 280.2, 189.8),
        Position = Vector3.new(-1946.46, 281.70, 197.24),
        TargetCount = 4, Xp = 225, Money = 70, LvMin = 10, LvMax = 15, IsBoss = false,
    },
    ["Crimson Flame"] = {
        MobName = "Crimson Flame",
        QuestName = "KillCrimsonFlame",
        BoardId = "CrimsonCamp",
        Name = "Crimson Camp Quest Board",
        InternalName = "Crimson Camp Quest Board",
        Npc = "Zeal",
        NpcPosition = Vector3.new(-1946.0, 280.2, 189.8),
        Position = Vector3.new(-1946.46, 281.70, 197.24),
        TargetCount = 1, Xp = 2200, Money = 350, LvMin = 10, LvMax = 15, IsBoss = true,
    },
    -- 3. Farm (Lv. 15-25)
    ["Angry Farmer"] = {
        MobName = "Angry Farmer",
        QuestName = "KillAngryFarmer",
        BoardId = "Farm",
        Name = "Farm Quest Board",
        InternalName = "Farm Quest Board",
        Npc = "Roger",
        NpcPosition = Vector3.new(-2154.5, 195.5, -885.9),
        Position = Vector3.new(-2161.17, 196.36, -890.73),
        TargetCount = 4, Xp = 265, Money = 100, LvMin = 15, LvMax = 18, IsBoss = false,
    },
    ["Farm Keeper"] = {
        MobName = "Farm Keeper",
        QuestName = "KillFarmKeeper",
        BoardId = "Farm",
        Name = "Farm Quest Board",
        InternalName = "Farm Quest Board",
        Npc = "Roger",
        NpcPosition = Vector3.new(-2154.5, 195.5, -885.9),
        Position = Vector3.new(-2161.17, 196.36, -890.73),
        TargetCount = 3, Xp = 290, Money = 115, LvMin = 18, LvMax = 21, IsBoss = false,
    },
    ["Chief Farmer"] = {
        MobName = "Chief Farmer",
        QuestName = "KillChiefFarmer",
        BoardId = "Farm",
        Name = "Farm Quest Board",
        InternalName = "Farm Quest Board",
        Npc = "Roger",
        NpcPosition = Vector3.new(-2154.5, 195.5, -885.9),
        Position = Vector3.new(-2161.17, 196.36, -890.73),
        TargetCount = 3, Xp = 325, Money = 130, LvMin = 21, LvMax = 25, IsBoss = false,
    },
    ["Fox Bear"] = {
        MobName = "Fox Bear",
        QuestName = "KillFoxBear",
        BoardId = "Farm",
        Name = "Farm Quest Board",
        InternalName = "Farm Quest Board",
        Npc = "Roger",
        NpcPosition = Vector3.new(-2154.5, 195.5, -885.9),
        Position = Vector3.new(-2161.17, 196.36, -890.73),
        TargetCount = 1, Xp = 2700, Money = 450, LvMin = 15, LvMax = 25, IsBoss = true,
    },
    -- 4. Blick Castle (Lv. 25-40)
    ["Port Invader"] = {
        MobName = "Port Invader",
        QuestName = "KillPortInvader",
        BoardId = "BlickCastle",
        Name = "Blick Castle Quest board",
        InternalName = "Blick Castle Quest board",
        Npc = "Nora",
        NpcPosition = Vector3.new(-3696.9, 548.3, 420.3),
        Position = Vector3.new(-3702.89, 549.71, 420.27),
        TargetCount = 4, Xp = 365, Money = 160, LvMin = 25, LvMax = 32, IsBoss = false,
    },
    ["Port Marksman"] = {
        MobName = "Port Marksman",
        QuestName = "KillPortMarksman",
        BoardId = "BlickCastle",
        Name = "Blick Castle Quest board",
        InternalName = "Blick Castle Quest board",
        Npc = "Nora",
        NpcPosition = Vector3.new(-3696.9, 548.3, 420.3),
        Position = Vector3.new(-3702.89, 549.71, 420.27),
        TargetCount = 4, Xp = 390, Money = 170, LvMin = 32, LvMax = 40, IsBoss = false,
    },
    ["Black Blick"] = {
        MobName = "Black Blick",
        QuestName = "KillBlackBlick",
        BoardId = "BlickCastle",
        Name = "Blick Castle Quest board",
        InternalName = "Blick Castle Quest board",
        Npc = "Nora",
        NpcPosition = Vector3.new(-3696.9, 548.3, 420.3),
        Position = Vector3.new(-3702.89, 549.71, 420.27),
        TargetCount = 1, Xp = 2990, Money = 500, LvMin = 25, LvMax = 40, IsBoss = true,
    },
    -- 5. Mines (Lv. 25-60)
    ["Green Goblin"] = {
        MobName = "Green Goblin",
        QuestName = "KillGreenGoblin",
        BoardId = "Mines",
        Name = "Mines Quest Board",
        InternalName = "Mines Quest Board",
        Npc = "Jacob",
        NpcPosition = Vector3.new(-2223.2, -660.0, -7206.1),
        Position = Vector3.new(-2215.32, -658.39, -7206.08),
        TargetCount = 4, Xp = 400, Money = 190, LvMin = 25, LvMax = 33, IsBoss = false,
    },
    ["Zombie"] = {
        MobName = "Zombie",
        QuestName = "KillZombie",
        BoardId = "Mines",
        Name = "Mines Quest Board",
        InternalName = "Mines Quest Board",
        Npc = "Jacob",
        NpcPosition = Vector3.new(-2223.2, -660.0, -7206.1),
        Position = Vector3.new(-2215.32, -658.39, -7206.08),
        TargetCount = 4, Xp = 425, Money = 200, LvMin = 33, LvMax = 40, IsBoss = false,
    },
    ["Big Zombie"] = {
        MobName = "Big Zombie",
        QuestName = "KillBigZombie",
        BoardId = "Mines",
        Name = "Mines Quest Board",
        InternalName = "Mines Quest Board",
        Npc = "Jacob",
        NpcPosition = Vector3.new(-2223.2, -660.0, -7206.1),
        Position = Vector3.new(-2215.32, -658.39, -7206.08),
        TargetCount = 3, Xp = 450, Money = 215, LvMin = 40, LvMax = 48, IsBoss = false,
    },
    ["Stone Soldier"] = {
        MobName = "Stone Soldier",
        QuestName = "KillStoneSoldier",
        BoardId = "Mines",
        Name = "Mines Quest Board",
        InternalName = "Mines Quest Board",
        Npc = "Jacob",
        NpcPosition = Vector3.new(-2223.2, -660.0, -7206.1),
        Position = Vector3.new(-2215.32, -658.39, -7206.08),
        TargetCount = 3, Xp = 490, Money = 240, LvMin = 48, LvMax = 60, IsBoss = false,
    },
    ["Mole Rat"] = {
        MobName = "Mole Rat",
        QuestName = "KillMoleRat",
        BoardId = "Mines",
        Name = "Mines Quest Board",
        InternalName = "Mines Quest Board",
        Npc = "Jacob",
        NpcPosition = Vector3.new(-2223.2, -660.0, -7206.1),
        Position = Vector3.new(-2215.32, -658.39, -7206.08),
        TargetCount = 1, Xp = 3000, Money = 750, LvMin = 25, LvMax = 60, IsBoss = true,
    },
    ["Stone Eye"] = {
        MobName = "Stone Eye",
        QuestName = "KillStoneEye",
        BoardId = "Mines",
        Name = "Mines Quest Board",
        InternalName = "Mines Quest Board",
        Npc = "Jacob",
        NpcPosition = Vector3.new(-2223.2, -660.0, -7206.1),
        Position = Vector3.new(-2215.32, -658.39, -7206.08),
        TargetCount = 1, Xp = 3200, Money = 700, LvMin = 25, LvMax = 60, IsBoss = true,
    },
    -- 6. Whale Island Beach (Lv. 40-55)
    ["Beach Brawler"] = {
        MobName = "Beach Brawler",
        QuestName = "KillBeachBrawler",
        BoardId = "WhaleIslandBeach",
        Name = "Whale Island Beach Quest Board",
        InternalName = "Whale Island Beach Quest Board",
        Npc = "Kato",
        NpcPosition = Vector3.new(-5715.7, 359.5, 1336.0),
        Position = Vector3.new(-5716.46, 361.05, 1344.16),
        TargetCount = 4, Xp = 525, Money = 310, LvMin = 40, LvMax = 48, IsBoss = false,
    },
    ["Beach Warrior"] = {
        MobName = "Beach Warrior",
        QuestName = "KillBeachWarrior",
        BoardId = "WhaleIslandBeach",
        Name = "Whale Island Beach Quest Board",
        InternalName = "Whale Island Beach Quest Board",
        Npc = "Kato",
        NpcPosition = Vector3.new(-5715.7, 359.5, 1336.0),
        Position = Vector3.new(-5716.46, 361.05, 1344.16),
        TargetCount = 3, Xp = 565, Money = 320, LvMin = 48, LvMax = 60, IsBoss = false,
    },
    ["Sandy Storm"] = {
        MobName = "Sandy Storm",
        QuestName = "KillSandyStorm",
        BoardId = "WhaleIslandBeach",
        Name = "Whale Island Beach Quest Board",
        InternalName = "Whale Island Beach Quest Board",
        Npc = "Kato",
        NpcPosition = Vector3.new(-5715.7, 359.5, 1336.0),
        Position = Vector3.new(-5716.46, 361.05, 1344.16),
        TargetCount = 1, Xp = 3250, Money = 500, LvMin = 40, LvMax = 60, IsBoss = true,
    },
    ["Beach King"] = {
        MobName = "Beach King",
        QuestName = "KillBeachKing",
        BoardId = "WhaleIslandBeach",
        Name = "Whale Island Beach Quest Board",
        InternalName = "Whale Island Beach Quest Board",
        Npc = "Kato",
        NpcPosition = Vector3.new(-5715.7, 359.5, 1336.0),
        Position = Vector3.new(-5716.46, 361.05, 1344.16),
        TargetCount = 1, Xp = 3400, Money = 650, LvMin = 40, LvMax = 60, IsBoss = true,
    },
    -- 7. Deep Forest (Lv. 60-65)
    ["Foxbear Hunter"] = {
        MobName = "Foxbear Hunter",
        QuestName = "KillFoxBearHunter",
        BoardId = "DeepForest",
        Name = "Deep Forest Quest Board",
        InternalName = "Deep Forest Quest Board",
        Npc = "Lily",
        NpcPosition = Vector3.new(-3295.5, 156.6, -2018.2),
        Position = Vector3.new(-3301.82, 157.79, -2021.10),
        TargetCount = 4, Xp = 590, Money = 350, LvMin = 60, LvMax = 62, IsBoss = false,
    },
    ["Lost Hunter"] = {
        MobName = "Lost Hunter",
        QuestName = "KillLostHunter",
        BoardId = "DeepForest",
        Name = "Deep Forest Quest Board",
        InternalName = "Deep Forest Quest Board",
        Npc = "Lily",
        NpcPosition = Vector3.new(-3295.5, 156.6, -2018.2),
        Position = Vector3.new(-3301.82, 157.79, -2021.10),
        TargetCount = 4, Xp = 625, Money = 360, LvMin = 62, LvMax = 65, IsBoss = false,
    },
    -- 8. Swamp (Lv. 65-75)
    ["Swamp Viper"] = {
        MobName = "Swamp Viper",
        QuestName = "KillSwampViper",
        BoardId = "Swamp",
        Name = "Swamp Quest board",
        InternalName = "Swamp Quest board",
        Npc = "Victor",
        NpcPosition = Vector3.new(-4438.4, -39.8, -2966.1),
        Position = Vector3.new(-4444.17, -38.15, -2976.38),
        TargetCount = 4, Xp = 650, Money = 385, LvMin = 65, LvMax = 70, IsBoss = false,
    },
    ["Purple Viper"] = {
        MobName = "Purple Viper",
        QuestName = "KillPurpleViper",
        BoardId = "Swamp",
        Name = "Swamp Quest board",
        InternalName = "Swamp Quest board",
        Npc = "Victor",
        NpcPosition = Vector3.new(-4438.4, -39.8, -2966.1),
        Position = Vector3.new(-4444.17, -38.15, -2976.38),
        TargetCount = 4, Xp = 680, Money = 390, LvMin = 70, LvMax = 75, IsBoss = false,
    },
    ["Master of the Swamp"] = {
        MobName = "Master of the Swamp",
        QuestName = "KillMasterOfTheSwamp",
        BoardId = "Swamp",
        Name = "Swamp Quest board",
        InternalName = "Swamp Quest board",
        Npc = "Victor",
        NpcPosition = Vector3.new(-4438.4, -39.8, -2966.1),
        Position = Vector3.new(-4444.17, -38.15, -2976.38),
        TargetCount = 1, Xp = 4430, Money = 450, LvMin = 65, LvMax = 75, IsBoss = true,
    },
    -- 9. Volcanic Area (Lv. 75-100)
    ["Crimson Swordsman"] = {
        MobName = "Crimson Swordsman",
        QuestName = "KillCrimsonSwordsman",
        BoardId = "VolcanicArea",
        Name = "Volcanic Area Quest Board",
        InternalName = "Volcanic Area Quest Board",
        Npc = "Florence",
        NpcPosition = Vector3.new(-2227.7, 379.9, -2676.8),
        Position = Vector3.new(-2225.52, 382.00, -2668.02),
        TargetCount = 4, Xp = 700, Money = 500, LvMin = 75, LvMax = 80, IsBoss = false,
    },
    ["Flame Worshipper"] = {
        MobName = "Flame Worshipper",
        QuestName = "KillFlameWorshipper",
        BoardId = "VolcanicArea",
        Name = "Volcanic Area Quest Board",
        InternalName = "Volcanic Area Quest Board",
        Npc = "Florence",
        NpcPosition = Vector3.new(-2227.7, 379.9, -2676.8),
        Position = Vector3.new(-2225.52, 382.00, -2668.02),
        TargetCount = 4, Xp = 750, Money = 525, LvMin = 80, LvMax = 85, IsBoss = false,
    },
    ["Volcano Warrior"] = {
        MobName = "Volcano Warrior",
        QuestName = "KillVolcanoWarrior",
        BoardId = "VolcanicArea",
        Name = "Volcanic Area Quest Board",
        InternalName = "Volcanic Area Quest Board",
        Npc = "Florence",
        NpcPosition = Vector3.new(-2227.7, 379.9, -2676.8),
        Position = Vector3.new(-2225.52, 382.00, -2668.02),
        TargetCount = 3, Xp = 800, Money = 550, LvMin = 85, LvMax = 92, IsBoss = false,
    },
    ["Fire Spirit"] = {
        MobName = "Fire Spirit",
        QuestName = "KillFireSpirits",
        BoardId = "VolcanicArea",
        Name = "Volcanic Area Quest Board",
        InternalName = "Volcanic Area Quest Board",
        Npc = "Florence",
        NpcPosition = Vector3.new(-2227.7, 379.9, -2676.8),
        Position = Vector3.new(-2225.52, 382.00, -2668.02),
        TargetCount = 4, Xp = 900, Money = 565, LvMin = 92, LvMax = 100, IsBoss = false,
    },
    ["Dracolith"] = {
        MobName = "Dracolith",
        QuestName = "KillDrakolith",
        BoardId = "VolcanicArea",
        Name = "Volcanic Area Quest Board",
        InternalName = "Volcanic Area Quest Board",
        Npc = "Florence",
        NpcPosition = Vector3.new(-2227.7, 379.9, -2676.8),
        Position = Vector3.new(-2225.52, 382.00, -2668.02),
        TargetCount = 1, Xp = 5575, Money = 800, LvMin = 75, LvMax = 100, IsBoss = true,
    },
}

local QuestNameToDetailsMap = {}
for mobName, info in pairs(MobToBoardMap) do
    QuestNameToDetailsMap[info.QuestName] = info
end

local function GetPlayerData()
    local data = LocalPlayer:FindFirstChild("Data")
    local slotNum = tostring((data and data:GetAttribute("SelectedSlot")) or LocalPlayer:GetAttribute("SelectedSlot") or 1)
    local slot = data and data:FindFirstChild("SavesSlot") and data.SavesSlot:FindFirstChild(slotNum)
    return slot and slot:FindFirstChild("PlayerData")
end

local function GetActiveQuests()
    local pd = GetPlayerData()
    local activeFolder = pd and pd:FindFirstChild("ActiveQuests")
    local quests = {}
    if activeFolder then
        for _, q in ipairs(activeFolder:GetChildren()) do
            local qName = q.Name
            local stage = q:GetAttribute("stage") or q:GetAttribute("Stage") or 1
            local progress = q:GetAttribute("stage_progress") or q:GetAttribute("progress") or q:GetAttribute("Progress") or 0
            local details = QuestNameToDetailsMap[qName]
            local target = q:GetAttribute("target") or q:GetAttribute("Target") or (details and details.TargetCount) or 0
            table.insert(quests, {
                Name = qName,
                Instance = q,
                Stage = stage,
                Progress = progress,
                Target = target,
            })
        end
    end
    return quests
end

local function HasActiveQuest(questName)
    if not questName then return false end
    for _, q in ipairs(GetActiveQuests()) do
        if q.Name == questName then
            return true, q
        end
    end
    return false, nil
end

local function GetCompletedQuestsCount()
    local pd = GetPlayerData()
    local compFolder = pd and pd:FindFirstChild("CompletedQuests")
    if compFolder then
        return #compFolder:GetChildren()
    end
    return 0
end

local function CollectQuest(questName)
    if not QuestsService or not questName then return false end
    local ok = false
    pcall(function()
        QuestsService:collect(questName):await()
        ok = true
    end)
    pcall(function()
        QuestsService:finish_last_stage(questName):await()
        ok = true
    end)
    if ok then
        QuestsStats.TotalCollected = QuestsStats.TotalCollected + 1
        QuestsStats.LastAction = "Collected: " .. tostring(questName)
    end
    return ok
end

local function RepeatQuest(questName)
    if not QuestsService or not questName then return false end
    local ok = false
    pcall(function()
        QuestsService:repeat_quest(questName):await()
        ok = true
    end)
    if ok then
        QuestsStats.LastAction = "Repeated: " .. tostring(questName)
    end
    return ok
end

local function AbandonActiveQuest(questName)
    if not QuestsService or not questName then return false end
    local ok = false
    pcall(function()
        QuestsService:abandon(questName):await()
        ok = true
    end)
    if ok then
        QuestsStats.LastAction = "Abandoned: " .. tostring(questName)
    end
    return ok
end

local function FindQuestBoardModel(targetName)
    if not targetName then return nil end
    local world = workspace:FindFirstChild("World")
    if world then
        local qb = world:FindFirstChild("Quest Boards")
        if qb then
            for _, child in ipairs(qb:GetChildren()) do
                if child.Name == targetName or child.Name:lower() == targetName:lower() or string.find(child.Name:lower(), targetName:lower(), 1, true) then
                    return child
                end
            end
        end
        local qf = world:FindFirstChild("Quests")
        if qf then
            for _, child in ipairs(qf:GetChildren()) do
                if child.Name == targetName or child.Name:lower() == targetName:lower() then
                    return child
                end
            end
        end
    end
    return nil
end

local function WaitOutOfCombat(maxWaitSec)
    local char = GetCharacter()
    local hrp = GetHRP()
    if not char or not hrp then return end
    if not char:HasTag("InCombat") then return end

    maxWaitSec = maxWaitSec or 6
    local safeSkyPos = hrp.Position + Vector3.new(0, 60, 0)
    local deadline = os.clock() + maxWaitSec
    QuestsStats.LastAction = "Waiting for InCombat tag to clear..."
    while os.clock() < deadline and char.Parent and char:HasTag("InCombat") do
        SetHover(true)
        hrp.CFrame = CFrame.new(safeSkyPos)
        hrp.AssemblyLinearVelocity = Vector3.zero
        task.wait(0.2)
    end
    SetHover(false)
end

local function TakeQuestAtBoard(boardInfo, questName, skipReturn)
    if isBoardInteractionBusy then return false end
    isBoardInteractionBusy = true

    local accepted = false
    local okErr, _ = pcall(function()
        local char = GetCharacter()
        local hrp = GetHRP()
        if not char or not hrp or not boardInfo then
            return
        end

        -- 1. If in combat, wait safely in air until InCombat clears so board does not reject
        if char:HasTag("InCombat") then
            WaitOutOfCombat(6.5)
        end

        SetHover(false)
        local boardPos = boardInfo.Position
        local boardName = boardInfo.InternalName or boardInfo.Name
        local boardId = boardInfo.BoardId or boardInfo.Id
        local returnCF = (not skipReturn) and hrp.CFrame or nil

        -- 2. Stream around the board area first
        pcall(function()
            LocalPlayer:RequestStreamAroundAsync(boardPos, 2)
        end)

        -- 3. Unlock Storyline Board prerequisite via NPC if still locked ("Intro" or nil)
        if boardId and boardId ~= "Whale_Hal" and StorylineBoardService then
            local sbAttr = "SB_" .. tostring(boardId)
            local sbState = LocalPlayer:GetAttribute(sbAttr)
            if sbState == nil or sbState == "Intro" then
                local npcPos = boardInfo.NpcPosition or boardPos
                QuestsStats.LastAction = "Unlocking Board (" .. tostring(boardInfo.Npc or boardId) .. ")..."
                hrp.CFrame = CFrame.new(npcPos + Vector3.new(0, 2.5, 2.5), npcPos)
                hrp.AssemblyLinearVelocity = Vector3.zero
                task.wait(0.35)
                pcall(function()
                    StorylineBoardService:unlock(boardId):await()
                end)
                task.wait(0.2)
            elseif sbState == "Complete" and Config.AutoClaimStorylineBoards then
                local npcPos = boardInfo.NpcPosition or boardPos
                hrp.CFrame = CFrame.new(npcPos + Vector3.new(0, 2.5, 2.5), npcPos)
                hrp.AssemblyLinearVelocity = Vector3.zero
                task.wait(0.25)
                pcall(function()
                    StorylineBoardService:claim(boardId):await()
                end)
                task.wait(0.2)
            end
        end

        -- 4. Find physical board Interactor position if streamed in
        local boardModel = FindQuestBoardModel(boardName)
        if boardModel then
            local interactor = boardModel:FindFirstChild("Interactor") or boardModel:FindFirstChild("Board")
            if interactor and interactor:IsA("BasePart") then
                boardPos = interactor.Position
            elseif boardModel:IsA("Model") then
                boardPos = boardModel:GetPivot().Position
            elseif boardModel:IsA("BasePart") then
                boardPos = boardModel.Position
            end
        end

        -- 5. Stand directly in front of the board (within 4 studs of Interactor)
        local standPos = boardPos + Vector3.new(0, 1.5, 3.0)
        QuestsStats.LastAction = "At Board: " .. tostring(boardName)
        hrp.CFrame = CFrame.lookAt(standPos, boardPos)
        hrp.AssemblyLinearVelocity = Vector3.zero
        task.wait(0.3)

        -- 6. If questName is nil, user just wanted to open/interact with the board physically
        if not questName then
            local prompt = boardModel and boardModel:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt and fireproximityprompt then
                pcall(function() fireproximityprompt(prompt) end)
            end
            accepted = true
            return
        end

        -- 7. Open board viewing state on server (MUST pass boolean true, NOT boardName!)
        if QuestsService and QuestsService.set_board_viewing then
            pcall(function()
                QuestsService:set_board_viewing(true):await()
            end)
            task.wait(0.12)
        end

        -- 8. Accept the quest on server (MUST pass "yes" as 2nd argument!)
        if QuestsService and QuestsService.get_quest then
            QuestsStats.LastAction = "Accepting Quest: " .. tostring(questName) .. "..."
            pcall(function()
                QuestsService:get_quest(questName, "yes"):await()
            end)
            task.wait(0.2)
        end

        -- 9. Close board viewing state on server
        if QuestsService and QuestsService.set_board_viewing then
            pcall(function()
                QuestsService:set_board_viewing(false):await()
            end)
        end

        -- 10. Ensure camera & HUD are restored if physical board prompt opened
        pcall(function()
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            local qg = pg and pg:FindFirstChild("QuestGui")
            if qg and qg.Enabled then
                qg.Enabled = false
            end
            local hud = pg and pg:FindFirstChild("Hud")
            if hud and not hud.Enabled then
                hud.Enabled = true
            end
            if workspace.CurrentCamera and workspace.CurrentCamera.CameraType == Enum.CameraType.Scriptable then
                workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
            end
        end)

        accepted = HasActiveQuest(questName)
        if accepted then
            QuestsStats.LastAction = "Accepted: " .. tostring(questName)
        else
            QuestsStats.LastAction = "Requested: " .. tostring(questName)
        end

        -- 11. Return to previous position if requested
        if returnCF and not Config.AutoLevelFarm then
            task.wait(0.15)
            hrp.CFrame = returnCF
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
    end)

    isBoardInteractionBusy = false
    return accepted and okErr
end

local function AcceptQuestByName(questName)
    if not questName or questName == "" then return false end

    local targetBoard = QuestNameToDetailsMap[questName]
    if not targetBoard then
        for mobName, mapData in pairs(MobToBoardMap) do
            if mapData.QuestName:lower() == questName:lower() or string.find(questName:lower(), mobName:gsub("%s+", ""):lower(), 1, true) then
                targetBoard = mapData
                questName = mapData.QuestName
                break
            end
        end
    end

    if not targetBoard then
        for _, b in ipairs(IslandQuestBoards) do
            if table.find(b.Quests, questName) or b.Name == Config.SelectedIslandBoard then
                targetBoard = b
                break
            end
        end
        targetBoard = targetBoard or IslandQuestBoards[1]
    end

    return TakeQuestAtBoard(targetBoard, questName)
end

-- Unlock & Claim All 9 Storyline Quest Boards by visiting each NPC
local function UnlockAllStorylineBoards()
    if not StorylineBoardService or isBoardInteractionBusy then return 0 end
    isBoardInteractionBusy = true
    local unlockedCount = 0

    pcall(function()
        local hrp = GetHRP()
        if not hrp then return end
        local prevCF = hrp.CFrame
        WaitOutOfCombat(5)
        SetHover(false)

        for _, b in ipairs(IslandQuestBoards) do
            if b.BoardId and b.BoardId ~= "Whale_Hal" then
                local sbState = LocalPlayer:GetAttribute("SB_" .. b.BoardId)
                local targetPos = b.NpcPosition or b.Position
                if sbState == nil or sbState == "Intro" or sbState == "Complete" then
                    QuestsStats.LastAction = "Visiting " .. tostring(b.Npc) .. " (" .. tostring(b.BoardId) .. ")..."
                    pcall(function() LocalPlayer:RequestStreamAroundAsync(targetPos, 2) end)
                    hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 2.5, 2.5), targetPos)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    task.wait(0.35)
                    pcall(function() StorylineBoardService:unlock(b.BoardId):await() end)
                    if LocalPlayer:GetAttribute("SB_" .. b.BoardId) == "Complete" then
                        pcall(function() StorylineBoardService:claim(b.BoardId):await() end)
                    end
                    task.wait(0.15)
                    local newState = LocalPlayer:GetAttribute("SB_" .. b.BoardId)
                    if newState and newState ~= "Intro" then
                        unlockedCount = unlockedCount + 1
                    end
                else
                    unlockedCount = unlockedCount + 1
                end
            end
        end

        hrp.CFrame = prevCF
        hrp.AssemblyLinearVelocity = Vector3.zero
        QuestsStats.LastAction = string.format("Unlocked %d/9 Quest Boards!", unlockedCount)
    end)

    isBoardInteractionBusy = false
    return unlockedCount
end

local function ClaimAllMilestones()
    if not MilestonesService then return 0 end
    local pd = GetPlayerData()
    local mFolder = pd and pd:FindFirstChild("Milestones")
    local count = 0
    if mFolder then
        for _, m in ipairs(mFolder:GetChildren()) do
            local isClaimed = m:GetAttribute("claimed") == true or m:GetAttribute("Claimed") == true
            if not isClaimed then
                local ok = pcall(function()
                    MilestonesService:claim(m.Name):await()
                end)
                if ok then count = count + 1 end
            end
        end
    end
    pcall(function()
        local mc = require(LocalPlayer.PlayerScripts.Client.Controllers.MilestonesController)
        if mc and typeof(mc.claim_all) == "function" then
            mc.claim_all()
        end
    end)
    if count > 0 then
        QuestsStats.TotalMilestonesClaimed = QuestsStats.TotalMilestonesClaimed + count
        QuestsStats.LastAction = string.format("Claimed %d Milestones", count)
    end
    return count
end

local function ClaimStorylineBoards()
    if not StorylineBoardService then return 0 end
    local count = 0
    for _, b in ipairs(IslandQuestBoards) do
        if b.BoardId and b.BoardId ~= "Whale_Hal" then
            local sbState = LocalPlayer:GetAttribute("SB_" .. b.BoardId)
            if sbState == "Complete" and not isBoardInteractionBusy then
                local hrp = GetHRP()
                if hrp then
                    local prevCF = hrp.CFrame
                    local npcPos = b.NpcPosition or b.Position
                    pcall(function() LocalPlayer:RequestStreamAroundAsync(npcPos, 2) end)
                    hrp.CFrame = CFrame.new(npcPos + Vector3.new(0, 2.5, 2.5), npcPos)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    task.wait(0.3)
                    pcall(function() StorylineBoardService:claim(b.BoardId):await() end)
                    task.wait(0.2)
                    hrp.CFrame = prevCF
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    count = count + 1
                end
            end
        end
    end
    if count > 0 then
        QuestsStats.TotalStorylineClaimed = QuestsStats.TotalStorylineClaimed + count
        QuestsStats.LastAction = string.format("Claimed %d Storyline Boards", count)
    end
    return count
end

-- ========================================================
-- AUTO LEVEL FARM PROGRESSION ENGINE (Lv. 1 -> Lv. 100+)
-- ========================================================
local function GetRecommendedLevelTarget(myLevel)
    myLevel = tonumber(myLevel) or tonumber(LocalPlayer:GetAttribute("Level")) or 1
    local useMinesRoute = (Config.LevelFarmRoute == "Mines Route (Lv. 25-60)")

    -- Optional: Check if an eligible Boss for our current level bracket is alive in workspace
    if Config.LevelFarmIncludeBosses then
        local bossCandidates = {}
        if myLevel >= 75 then
            bossCandidates = { "Dracolith" }
        elseif myLevel >= 65 then
            bossCandidates = { "Master of the Swamp" }
        elseif myLevel >= 40 and not useMinesRoute then
            bossCandidates = { "Beach King", "Sandy Storm" }
        elseif myLevel >= 25 and useMinesRoute then
            bossCandidates = { "Stone Eye", "Mole Rat" }
        elseif myLevel >= 25 then
            bossCandidates = { "Black Blick" }
        elseif myLevel >= 15 then
            bossCandidates = { "Fox Bear" }
        elseif myLevel >= 10 then
            bossCandidates = { "Crimson Flame" }
        end

        for _, bossName in ipairs(bossCandidates) do
            local aliveBoss = GetTarget(bossName)
            if aliveBoss and IsAlive(aliveBoss) and MobToBoardMap[bossName] then
                return bossName, MobToBoardMap[bossName]
            end
        end
    end

    -- Standard Level Progression Brackets
    local targetMob = "Forest Brawler"
    if myLevel < 5 then
        targetMob = "Forest Brawler"       -- Lv. 1-4 (Whale Island Town)
    elseif myLevel < 10 then
        targetMob = "Cave Brawler"         -- Lv. 5-9 (Whale Island Town)
    elseif myLevel < 15 then
        targetMob = "Phantom Raider"       -- Lv. 10-14 (Crimson Camp)
    elseif myLevel < 18 then
        targetMob = "Angry Farmer"         -- Lv. 15-17 (Farm)
    elseif myLevel < 21 then
        targetMob = "Farm Keeper"          -- Lv. 18-20 (Farm)
    elseif myLevel < 25 then
        targetMob = "Chief Farmer"         -- Lv. 21-24 (Farm)
    elseif myLevel < 60 then
        if useMinesRoute then
            if myLevel < 33 then
                targetMob = "Green Goblin"     -- Lv. 25-32 (Mines)
            elseif myLevel < 40 then
                targetMob = "Zombie"           -- Lv. 33-39 (Mines)
            elseif myLevel < 48 then
                targetMob = "Big Zombie"       -- Lv. 40-47 (Mines)
            else
                targetMob = "Stone Soldier"    -- Lv. 48-59 (Mines)
            end
        else
            if myLevel < 32 then
                targetMob = "Port Invader"     -- Lv. 25-31 (Blick Castle)
            elseif myLevel < 40 then
                targetMob = "Port Marksman"    -- Lv. 32-39 (Blick Castle)
            elseif myLevel < 48 then
                targetMob = "Beach Brawler"    -- Lv. 40-47 (Beach)
            else
                targetMob = "Beach Warrior"    -- Lv. 48-59 (Beach)
            end
        end
    elseif myLevel < 62 then
        targetMob = "Foxbear Hunter"       -- Lv. 60-61 (Deep Forest)
    elseif myLevel < 65 then
        targetMob = "Lost Hunter"          -- Lv. 62-64 (Deep Forest)
    elseif myLevel < 70 then
        targetMob = "Swamp Viper"          -- Lv. 65-69 (Swamp)
    elseif myLevel < 75 then
        targetMob = "Purple Viper"         -- Lv. 70-74 (Swamp)
    elseif myLevel < 80 then
        targetMob = "Crimson Swordsman"    -- Lv. 75-79 (Volcanic Area)
    elseif myLevel < 85 then
        targetMob = "Flame Worshipper"     -- Lv. 80-84 (Volcanic Area)
    elseif myLevel < 92 then
        targetMob = "Volcano Warrior"      -- Lv. 85-91 (Volcanic Area)
    else
        targetMob = "Fire Spirit"          -- Lv. 92-100+ (Volcanic Area)
    end

    return targetMob, MobToBoardMap[targetMob]
end

-- Quests Remote Listeners
pcall(function()
    if QuestsService and QuestsService.RepeatQuestOffer then
        RegisterConnection(QuestsService.RepeatQuestOffer:Connect(function(questName)
            if not questName then return end
            -- If AutoLevelFarm is active, only repeat if our current level still recommends this exact quest!
            if Config.AutoLevelFarm then
                local _, recData = GetRecommendedLevelTarget()
                if recData and recData.QuestName == questName then
                    task.wait(0.25)
                    RepeatQuest(questName)
                end
            elseif Config.AutoRepeatQuests then
                task.wait(0.25)
                RepeatQuest(questName)
            end
        end))
    end
end)

pcall(function()
    if NotificationService and NotificationService.QuestComplete then
        RegisterConnection(NotificationService.QuestComplete:Connect(function(questName)
            if Config.AutoCollectQuests and questName then
                task.wait(0.3)
                CollectQuest(questName)
                if Config.AutoLevelFarm then
                    local _, recData = GetRecommendedLevelTarget()
                    if recData and recData.QuestName == questName then
                        task.wait(0.4)
                        RepeatQuest(questName)
                    end
                elseif Config.AutoRepeatQuests then
                    task.wait(0.5)
                    RepeatQuest(questName)
                end
            end
        end))
    end
end)

-- Auto Quests, Level Farm & Mob Quest Matching Background Loop
task.spawn(function()
    while _G.BeyondNenInstanceId == myInstanceId do
        task.wait(Config.QuestCheckInterval or 2)

        if not IsPlayerDead() then
            -- 1. Auto Collect Completed Active Quests
            if Config.AutoCollectQuests and QuestsService then
                local active = GetActiveQuests()
                for _, q in ipairs(active) do
                    if q.Target > 0 and q.Progress >= q.Target then
                        CollectQuest(q.Name)
                    else
                        pcall(function() QuestsService:collect(q.Name):await() end)
                        pcall(function() QuestsService:finish_last_stage(q.Name):await() end)
                    end
                end
            end

            -- 2. Auto Level Farm: Dynamic Mob & Quest Progression based on Player Level
            if Config.AutoLevelFarm and not isBoardInteractionBusy and not Config.AutoMeditation and not Config.AutoLootChests then
                local myLevel = LocalPlayer:GetAttribute("Level") or 1
                local recMob, recQuestData = GetRecommendedLevelTarget(myLevel)
                if recMob and recQuestData then
                    QuestsStats.CurrentLevelBracket = string.format("Lv.%d -> %s (%s)", myLevel, recMob, recQuestData.QuestName)

                    -- Update SelectedMob if level progressed to a new mob
                    if Config.SelectedMob ~= recMob then
                        Config.SelectedMob = recMob
                        if UpdateESP then UpdateESP() end
                    end

                    -- Abandon any outdated Kill* quests from lower level brackets
                    local active = GetActiveQuests()
                    local hasRecQuest = false
                    for _, q in ipairs(active) do
                        if q.Name == recQuestData.QuestName then
                            hasRecQuest = true
                        elseif string.sub(q.Name, 1, 4) == "Kill" and QuestNameToDetailsMap[q.Name] then
                            AbandonActiveQuest(q.Name)
                            task.wait(0.2)
                        end
                    end

                    -- If we don't have the recommended quest for our level, go to its board and take it
                    if not hasRecQuest then
                        TakeQuestAtBoard(recQuestData, recQuestData.QuestName, true)
                        -- Immediately move toward the recommended mob's spawn area after taking the quest
                        local spawnPos = GetMobSpawnPoint(recMob)
                        local hrp = GetHRP()
                        if hrp and spawnPos then
                            pcall(function() LocalPlayer:RequestStreamAroundAsync(spawnPos, 2) end)
                            hrp.CFrame = CFrame.new(spawnPos + Vector3.new(0, 8, 0), spawnPos)
                            hrp.AssemblyLinearVelocity = Vector3.zero
                        end
                        task.wait(0.8)
                    end
                end

            -- 3. Auto Match Quest for Selected Mob / Boss in Manual Mob/Boss Farm
            elseif not isBoardInteractionBusy and not Config.AutoMeditation and not Config.AutoLootChests then
                local wantBossQuest = Config.AutoFarmBoss and Config.AutoTakeQuestForTargetBoss
                local wantMobQuest = Config.AutoFarmMob and Config.AutoTakeQuestForTargetMob
                if wantBossQuest or wantMobQuest then
                    local targetName = wantBossQuest and Config.SelectedBoss or Config.SelectedMob
                    local mapping = targetName and MobToBoardMap[targetName]
                    if mapping and mapping.QuestName then
                        local hasQuest = HasActiveQuest(mapping.QuestName)
                        if not hasQuest then
                            -- Abandon conflicting Kill* quests if any so board quest is clean
                            for _, q in ipairs(GetActiveQuests()) do
                                if string.sub(q.Name, 1, 4) == "Kill" and q.Name ~= mapping.QuestName then
                                    AbandonActiveQuest(q.Name)
                                    task.wait(0.15)
                                end
                            end
                            TakeQuestAtBoard(mapping, mapping.QuestName, false)
                            task.wait(1.0)
                        end
                    end
                end
            end

            -- 4. Auto Claim Milestones
            if Config.AutoClaimMilestones then
                ClaimAllMilestones()
            end

            -- 5. Auto Claim Completed Storyline Boards
            if Config.AutoClaimStorylineBoards then
                ClaimStorylineBoards()
            end
        end
    end
end)

-- Chest ESP Storage & Update
local ActiveChestESP = {}
local function UpdateChestESP()
    for inst, hl in pairs(ActiveChestESP) do
        if not Config.ChestESP or not inst.Parent then
            hl:Destroy()
            ActiveChestESP[inst] = nil
        end
    end

    if not Config.ChestESP then return end

    local worldChests = GetWorldChests()
    for _, chest in ipairs(worldChests) do
        if not ActiveChestESP[chest] then
            local rarity = chest:GetAttribute("VisualRarity") or chest:GetAttribute("LootRarity") or "Common"
            local color = ChestRarityColors[rarity] or Color3.fromRGB(255, 255, 255)

            local hl = Instance.new("Highlight")
            hl.Adornee = chest
            hl.FillColor = color
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
            hl.FillTransparency = 0.4
            hl.Parent = chest
            ActiveChestESP[chest] = hl
        end
    end
end

task.spawn(function()
    while _G.BeyondNenInstanceId == myInstanceId do
        task.wait(1)
        UpdateChestESP()
    end
end)

-- Mob ESP
local ActiveHighlights = {}
UpdateESP = function()
    for model, hl in pairs(ActiveHighlights) do
        if not Config.MobESP or not model.Parent or not IsAlive(model) then
            hl:Destroy()
            ActiveHighlights[model] = nil
        end
    end

    if not Config.MobESP then return end

    local targetName = Config.AutoFarmBoss and Config.SelectedBoss or Config.SelectedMob
    for _, model in ipairs(workspace:GetChildren()) do
        if model:IsA("Model") and (model.Name == targetName or (Config.FarmAnyNearby and table.find(AvailableMobs, model.Name))) then
            if IsAlive(model) and not ActiveHighlights[model] then
                local hl = Instance.new("Highlight")
                hl.Adornee = model
                hl.FillColor = Color3.fromRGB(255, 60, 60)
                hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                hl.FillTransparency = 0.5
                hl.Parent = model
                ActiveHighlights[model] = hl
            end
        end
    end
end

task.spawn(function()
    while _G.BeyondNenInstanceId == myInstanceId do
        task.wait(0.5)
        UpdateESP()
    end
end)

-- Auto refresh weapon list on backpack changes
task.spawn(function()
    local bp = LocalPlayer:WaitForChild("Backpack")
    local function onChange()
        if WeaponDropdown then
            local weapons = GetAvailableWeapons()
            WeaponDropdown:Refresh(weapons)
        end
    end
    RegisterConnection(bp.ChildAdded:Connect(onChange))
    RegisterConnection(bp.ChildRemoved:Connect(onChange))
end)

-- ========================================================
-- STATS, TALENTS & CODES LOGIC (System 8 & 9)
-- ========================================================
local StatKeysList = { "StrengthStat", "DurabilityStat", "StaminaStat", "WeaponStat", "NenStat" }

local function AllocateStat(statName, count)
    if not StatsService then return false, "StatsService not available" end
    local pts = LocalPlayer:GetAttribute("StatPoints") or 0
    if pts <= 0 then return false, "No Stat Points" end
    count = math.min(count or 1, pts)
    if count <= 0 then return false, "Invalid count" end

    local s, res = pcall(function()
        return StatsService:RequestIncrementStat(statName, count):await()
    end)
    return s and res == true, res
end

local function DistributeStatsEvenly()
    if not StatsService then return false end
    local pts = LocalPlayer:GetAttribute("StatPoints") or 0
    if pts <= 0 then return false end

    local each = math.floor(pts / #StatKeysList)
    local rem = pts % #StatKeysList

    for _, key in ipairs(StatKeysList) do
        local toAdd = each
        if rem > 0 then
            toAdd = toAdd + 1
            rem = rem - 1
        end
        if toAdd > 0 then
            pcall(function()
                StatsService:RequestIncrementStat(key, toAdd):await()
            end)
            task.wait(0.05)
        end
    end
    return true
end

-- Background Auto Stats Loop
task.spawn(function()
    while _G.BeyondNenInstanceId == myInstanceId do
        task.wait(1.5)
        if Config.AutoStats and StatsService then
            local pts = LocalPlayer:GetAttribute("StatPoints") or 0
            if pts >= (Config.AutoStatThreshold or 1) then
                if Config.AutoStatRatio == "Balanced" then
                    DistributeStatsEvenly()
                else
                    local target = Config.AutoStatTarget or "StrengthStat"
                    pcall(function()
                        StatsService:RequestIncrementStat(target, pts):await()
                    end)
                end
            end
        end
    end
end)

-- Talents Helpers
local function GetOwnedTalentsList()
    local owned = {}
    if Talents and Talents.Order then
        for _, name in ipairs(Talents.Order) do
            if Talents.Has(LocalPlayer, name) then
                table.insert(owned, name)
            end
        end
    end
    if #owned == 0 then
        table.insert(owned, "None")
    end
    return owned
end

local function CheckAndAutoHandleTalentChoice()
    if not TalentService or not (Config.AutoPickTalent or Config.AutoRerollHand) then return end
    local s, choice = pcall(function()
        return TalentService:GetChoice():await()
    end)
    if not s or typeof(choice) ~= "table" or not choice.Hand then return end

    local hand = choice.Hand
    local chosenTalent = nil

    -- 1. Check specific target talent
    if Config.TargetTalent and Config.TargetTalent ~= "None" and Config.TargetTalent ~= "Any Preferred" then
        for _, tName in ipairs(hand) do
            if tName == Config.TargetTalent then
                chosenTalent = tName
                break
            end
        end
    end

    -- 2. Check rarity target
    if not chosenTalent and Config.TargetTalentRarity and Talents and Talents.List then
        for _, tName in ipairs(hand) do
            local tData = Talents.List[tName]
            if tData and tData.Rarity then
                if Config.TargetTalentRarity == "Legendary" and tData.Rarity == "Legendary" then
                    chosenTalent = tName
                    break
                elseif Config.TargetTalentRarity == "Extraordinary" and (tData.Rarity == "Legendary" or tData.Rarity == "Extraordinary") then
                    chosenTalent = tName
                    break
                elseif Config.TargetTalentRarity == "Rare" and (tData.Rarity == "Legendary" or tData.Rarity == "Extraordinary" or tData.Rarity == "Rare") then
                    chosenTalent = tName
                    break
                end
            end
        end
    end

    if chosenTalent and Config.AutoPickTalent then
        pcall(function()
            TalentService:Choose(chosenTalent)
            WindUI:Notify({
                Title = "Talent Picked!",
                Content = string.format("Automatically chose: %s", chosenTalent),
                Duration = 4,
            })
        end)
    elseif Config.AutoRerollHand then
        local jenni = LocalPlayer:GetAttribute("Jenni") or 0
        local credits = 0
        pcall(function()
            local cr = TalentService:GetRerollCredits():await()
            credits = tonumber(cr) or 0
        end)

        if credits > 0 or jenni >= (Config.MinJenniForReroll or 10000) then
            pcall(function()
                TalentService:RerollHand()
            end)
        end
    end
end

if TalentService then
    if TalentService.TalentChoice then
        RegisterConnection(TalentService.TalentChoice:Connect(function()
            task.wait(0.5)
            CheckAndAutoHandleTalentChoice()
        end))
    end
    if TalentService.TalentHandRerolled then
        RegisterConnection(TalentService.TalentHandRerolled:Connect(function()
            task.wait(0.5)
            CheckAndAutoHandleTalentChoice()
        end))
    end
end

-- Background Auto Talent Check Loop
task.spawn(function()
    while _G.BeyondNenInstanceId == myInstanceId do
        task.wait(2)
        if Config.AutoPickTalent or Config.AutoRerollHand then
            CheckAndAutoHandleTalentChoice()
        end
    end
end)

-- Codes Helpers
local function RedeemAllGameCodes()
    if not CodeService then
        WindUI:Notify({ Title = "Code Error", Content = "CodeService not available", Duration = 3 })
        return
    end

    local count = 0
    local codes = {}
    if CodesData then
        for code, _ in pairs(CodesData) do
            table.insert(codes, code)
        end
    else
        codes = { "PATCH1!", "THANKYOU!", "RELEASE!", "UPDATECOMING" }
    end

    for _, code in ipairs(codes) do
        local s, res = pcall(function()
            return CodeService:RedeemCode(code):await()
        end)
        if s and res == true then
            count = count + 1
        end
        task.wait(0.2)
    end

    WindUI:Notify({
        Title = "Codes Redeemed",
        Content = string.format("Redeemed %d new code rewards!", count),
        Duration = 4,
    })
end

local function RedeemSingleCode(code)
    if not CodeService or not code or code == "" then return end
    local s, res = pcall(function()
        return CodeService:RedeemCode(code):await()
    end)
    if s and res == true then
        WindUI:Notify({
            Title = "Code Success",
            Content = string.format("Code '%s' redeemed successfully!", code),
            Duration = 4,
        })
    else
        WindUI:Notify({
            Title = "Code Result",
            Content = string.format("Code '%s' was invalid or already claimed.", code),
            Duration = 3,
        })
    end
end

-- ========================================================
-- UI CREATION (WindUI)
-- ========================================================
local Window = WindUI:CreateWindow({
    Title = "Beyond Nen - Auto Farm & Hub",
    Icon = "swords",
    Author = "cook45",
    Folder = "BeyondNenHub",
    Size = UDim2.fromOffset(620, 580),
    Transparent = true,
    Theme = "Dark",
})

-- ==================== TAB 1: AUTO FARM & COMBAT ====================
local CombatTab = Window:Tab({
    Title = "Auto Farm & Combat",
    Icon = "swords",
})

local StatusParagraph = CombatTab:Paragraph({
    Title = "Farm & Level Progression Status (สถานะการฟาร์มและเลเวล)",
    Desc = "Status: Idle",
})

task.spawn(function()
    while _G.BeyondNenInstanceId == myInstanceId do
        task.wait(0.4)
        local myLv = LocalPlayer:GetAttribute("Level") or 1
        local curXp = math.floor(LocalPlayer:GetAttribute("CurrentExp") or 0)
        local maxXp = math.floor(LocalPlayer:GetAttribute("NeededXp") or 100)
        local recMob, recQuest = GetRecommendedLevelTarget(myLv)
        local activeList = GetActiveQuests()
        local questStr = "None"
        if #activeList > 0 then
            local parts = {}
            for _, q in ipairs(activeList) do
                if q.Target > 0 then
                    table.insert(parts, string.format("%s (%d/%d)", q.Name, q.Progress, q.Target))
                else
                    table.insert(parts, q.Name)
                end
            end
            questStr = table.concat(parts, ", ")
        end

        if IsPlayerDead() then
            StatusParagraph:SetDesc(string.format(
                "[DEAD - %s] Lv.%d (%d/%d XP)\n%s\nActive Quests: %s",
                Config.AutoRespawn and "AUTO RESPAWN ON" or "WAITING TO RESPAWN",
                myLv, curXp, maxXp,
                tostring(QuestsStats.LastAction),
                questStr
            ))
        elseif Config.AutoLevelFarm or Config.AutoFarmMob or Config.AutoFarmBoss then
            local targetName = Config.AutoFarmBoss and Config.SelectedBoss or Config.SelectedMob
            local target = GetTarget(targetName)
            local modeLabel = Config.AutoLevelFarm and "AUTO LEVEL FARM" or (Config.AutoFarmBoss and "BOSS FARM" or "MOB FARM")
            if isBoardInteractionBusy then
                StatusParagraph:SetDesc(string.format(
                    "[%s] Lv.%d (%d/%d XP)\nBoard Action: %s\nActive Quests: %s",
                    modeLabel, myLv, curXp, maxXp, tostring(QuestsStats.LastAction), questStr
                ))
            elseif target and IsAlive(target) then
                local hp = math.floor(target:GetAttribute("Health") or 0)
                local maxHp = math.floor(target:GetAttribute("BaseMaxHealth") or 100)
                local hrp = GetHRP()
                local dist = hrp and math.floor((target.HumanoidRootPart.Position - hrp.Position).Magnitude) or 0
                StatusParagraph:SetDesc(string.format(
                    "[%s] Lv.%d (%d/%d XP) | Recommended: %s\nFighting: %s [HP: %d/%d] | Dist: %d studs\nActive Quests: %s",
                    modeLabel, myLv, curXp, maxXp, tostring(recMob), target.Name, hp, maxHp, dist, questStr
                ))
            else
                local spawnPos = GetMobSpawnPoint(targetName)
                local hrp = GetHRP()
                local dist = (hrp and spawnPos) and math.floor((spawnPos - hrp.Position).Magnitude) or 0
                if dist > 25 then
                    StatusParagraph:SetDesc(string.format(
                        "[%s] Lv.%d (%d/%d XP)\nTraveling to %s spawn (%d studs)...\nActive Quests: %s",
                        modeLabel, myLv, curXp, maxXp, tostring(targetName), dist, questStr
                    ))
                else
                    StatusParagraph:SetDesc(string.format(
                        "[%s] Lv.%d (%d/%d XP)\nWaiting for %s to respawn...\nActive Quests: %s",
                        modeLabel, myLv, curXp, maxXp, tostring(targetName), questStr
                    ))
                end
            end
        else
            StatusParagraph:SetDesc(string.format(
                "Status: Idle | Player Level: %d (%d/%d XP)\nRecommended for Lv.%d: %s (%s)\nActive Quests: %s",
                myLv, curXp, maxXp, myLv, tostring(recMob), tostring(recQuest and recQuest.QuestName or "None"), questStr
            ))
        end
    end
end)

-- SECTION 1: AUTO LEVEL FARM
local LevelFarmSection = CombatTab:Section({ Title = "1. Auto Level Farm (ระบบฟาร์มเวลอัตโนมัติ 1 - 100+)" })

LevelFarmSection:Toggle({
    Title = "Auto Level Farm (เปิดฟาร์มเวลอัตโนมัติ รับเควส+เปลี่ยนมอนตามเวล)",
    Desc = "เช็คเลเวลตัวละครอัตโนมัติ ไปปลดล็อกและรับเควสตามเวล เปลี่ยนมอนสเตอร์ไปเรื่อยๆ เมื่อเลเวลอัพ!",
    Value = Config.AutoLevelFarm,
    Callback = function(state)
        Config.AutoLevelFarm = state
        if state then
            local myLv = LocalPlayer:GetAttribute("Level") or 1
            local recMob, _ = GetRecommendedLevelTarget(myLv)
            if recMob then
                Config.SelectedMob = recMob
                if UpdateESP then UpdateESP() end
            end
        else
            if not Config.AutoFarmMob and not Config.AutoFarmBoss then
                SetHover(false)
            end
        end
    end,
})

LevelFarmSection:Dropdown({
    Title = "Lv. 25-60 Progression Route (เส้นทางฟาร์มช่วงเวล 25-60)",
    Desc = "เลือกฟาร์มบนบก (ปราสาทบลิค -> ชายหาด) หรือลงเหมืองใต้ดิน (โกบลิน -> ซอมบี้ -> ทหารหิน)",
    Values = { "Surface Route (Blick -> Beach)", "Mines Route (Lv. 25-60)" },
    Value = Config.LevelFarmRoute,
    Callback = function(val)
        Config.LevelFarmRoute = val
    end,
})

LevelFarmSection:Toggle({
    Title = "Include Alive Bosses in Level Farm (รับเควส+ตีบอสถ้าบอสในโซนเกิด)",
    Desc = "หากบอสประจำบอร์ดเควสในเลเวลนั้นมีชีวิตอยู่ จะสลับไปรับเควสบอสและตีบอสเพื่อรับ XP ก้อนโต",
    Value = Config.LevelFarmIncludeBosses,
    Callback = function(state)
        Config.LevelFarmIncludeBosses = state
    end,
})

-- SECTION 2: MOB FARMING
local MobSection = CombatTab:Section({ Title = "2. Mob Farming (ระบบฟาร์มม็อบแยกเฉพาะตัว)" })

MobDropdown = MobSection:Dropdown({
    Title = "Select Target Mob (เลือกมอนสเตอร์)",
    Desc = "เลือกมอนสเตอร์ที่ต้องการฟาร์ม (ครบทุกตัวในเกม เรียงตามเลเวล)",
    Values = AvailableMobs,
    Value = Config.SelectedMob,
    Callback = function(val)
        Config.SelectedMob = val
        if UpdateESP then UpdateESP() end
    end,
})

MobSection:Toggle({
    Title = "Auto Farm Selected Mob (เปิดฟาร์มม็อบที่เลือก)",
    Desc = "บิน/วาปไปหามอนสเตอร์ที่เลือกและโจมตีอัตโนมัติ",
    Value = Config.AutoFarmMob,
    Callback = function(state)
        Config.AutoFarmMob = state
        if not state and not Config.AutoLevelFarm and not Config.AutoFarmBoss then
            SetHover(false)
        end
    end,
})

MobSection:Toggle({
    Title = "Auto Quest for Selected Mob (รับเควสตามม็อบที่เลือกฟาร์มอัตโนมัติ)",
    Desc = "เมื่อเปิดฟาร์มมอนสเตอร์ ระบบจะวาปไปบอร์ดเควสของมอนตัวนั้นเพื่อปลดล็อกและรับเควสให้อัตโนมัติ!",
    Value = Config.AutoTakeQuestForTargetMob,
    Callback = function(state)
        Config.AutoTakeQuestForTargetMob = state
    end,
})

MobSection:Toggle({
    Title = "Farm Any Nearby Mob (ตีม็อบตัวอื่นใกล้ๆ ระหว่างรอเกิด)",
    Desc = "สลับไปตีมอนสเตอร์ตัวอื่นที่อยู่ใกล้ๆ ระหว่างรอมอนเป้าหมายเกิดใหม่",
    Value = Config.FarmAnyNearby,
    Callback = function(state)
        Config.FarmAnyNearby = state
    end,
})

MobSection:Button({
    Title = "Take Quest for Selected Mob Now (กดไปรับเควสม็อบที่เลือกทันที)",
    Desc = "วาปไปที่บอร์ดเควสของมอนสเตอร์ที่เลือกไว้ กดรับเควส แล้ววาปกลับมาจุดเดิม",
    Callback = function()
        local mapping = MobToBoardMap[Config.SelectedMob]
        if mapping then
            task.spawn(function()
                local ok = TakeQuestAtBoard(mapping, mapping.QuestName, false)
                WindUI:Notify({
                    Title = ok and "Quest Accepted!" or "Quest Requested",
                    Content = string.format("%s (%s)", mapping.QuestName, mapping.Name),
                    Duration = 3,
                })
            end)
        else
            WindUI:Notify({
                Title = "No Board Quest",
                Content = tostring(Config.SelectedMob) .. " does not have a quest board paper.",
                Duration = 3,
            })
        end
    end,
})

-- SECTION 3: BOSS FARMING
local BossSection = CombatTab:Section({ Title = "3. Boss Farming (ระบบฟาร์มบอสแยกเฉพาะตัว)" })

BossSection:Dropdown({
    Title = "Select Target Boss (เลือกบอส)",
    Desc = "เลือกบอสที่ต้องการฟาร์ม (ครบทั้ง 11 ตัวในเกม)",
    Values = AvailableBosses,
    Value = Config.SelectedBoss,
    Callback = function(val)
        Config.SelectedBoss = val
        if UpdateESP then UpdateESP() end
    end,
})

BossSection:Toggle({
    Title = "Auto Farm Selected Boss (เปิดฟาร์มบอสที่เลือก)",
    Desc = "ล็อกเป้าหมายไปหาบอสที่เลือกและโจมตีอัตโนมัติ",
    Value = Config.AutoFarmBoss,
    Callback = function(state)
        Config.AutoFarmBoss = state
        if not state and not Config.AutoLevelFarm and not Config.AutoFarmMob then
            SetHover(false)
        end
    end,
})

BossSection:Toggle({
    Title = "Auto Quest for Selected Boss (รับเควสตามบอสที่เลือกอัตโนมัติ)",
    Desc = "ไปรับเควสบอสที่บอร์ดเควสอัตโนมัติก่อนเริ่มตีบอส",
    Value = Config.AutoTakeQuestForTargetBoss,
    Callback = function(state)
        Config.AutoTakeQuestForTargetBoss = state
    end,
})

BossSection:Button({
    Title = "Take Quest for Selected Boss Now (กดไปรับเควสบอสที่เลือกทันที)",
    Desc = "วาปไปบอร์ดเควสเพื่อรับเควสบอสตัวที่เลือกไว้ทันที",
    Callback = function()
        local mapping = MobToBoardMap[Config.SelectedBoss]
        if mapping then
            task.spawn(function()
                local ok = TakeQuestAtBoard(mapping, mapping.QuestName, false)
                WindUI:Notify({
                    Title = ok and "Boss Quest Accepted!" or "Boss Quest Requested",
                    Content = string.format("%s (%s)", mapping.QuestName, mapping.Name),
                    Duration = 3,
                })
            end)
        else
            WindUI:Notify({
                Title = "No Board Quest",
                Content = tostring(Config.SelectedBoss) .. " does not have a board quest.",
                Duration = 3,
            })
        end
    end,
})

-- SECTION 4: AUTO PARRY SYSTEM (100% PRECISION HIT-MARKER PREDICTION)
local ParrySection = CombatTab:Section({ Title = "4. Auto Parry System (ระบบออโต้แพรี่แม่นยำ 100%)" })

ParryStatusParagraph = ParrySection:Paragraph({
    Title = "Auto Parry Status (สถานะระบบแพรี่)",
    Desc = "Loading status...",
})

task.spawn(function()
    while _G.BeyondNenInstanceId == myInstanceId do
        if ParryStatusParagraph then
            local modeStr = (Config.AutoParryMobs and Config.AutoParryPlayers) and "Mobs + Players" or (Config.AutoParryMobs and "Mobs Only" or (Config.AutoParryPlayers and "Players Only" or "Disabled"))
            local descText = string.format("Status: %s\nTotal Parried: %d | Total Attempts: %d\nLast Parried: %s\nTarget Mode: %s | Detection Range: %d studs",
                Config.AutoParry and "ACTIVE (100% Accuracy)" or "DISABLED",
                ParryStats.TotalParries,
                ParryStats.TotalAttempts,
                ParryStats.LastParried,
                modeStr,
                Config.ParryRange
            )
            ParryStatusParagraph:SetDesc(descText)
        end
        task.wait(1)
    end
end)

ParrySection:Toggle({
    Title = "Auto Parry (เปิดระบบออโต้แพรี่ 100%)",
    Desc = "ปัดป้องการโจมตี (M1, M2, สกิล) ของมอนสเตอร์ บอส และผู้เล่นอัตโนมัติแม่นยำ 100%",
    Value = Config.AutoParry,
    Callback = function(state)
        Config.AutoParry = state
    end,
})

ParrySection:Toggle({
    Title = "Parry Mobs & Bosses (แพรี่มอนสเตอร์และบอส)",
    Desc = "เปิดใช้งานแพรี่กับการโจมตีจากมอนสเตอร์และบอสทุกตัว",
    Value = Config.AutoParryMobs,
    Callback = function(state)
        Config.AutoParryMobs = state
    end,
})

ParrySection:Toggle({
    Title = "Parry Players [PvP] (แพรี่ผู้เล่นคนอื่น)",
    Desc = "เปิดใช้งานแพรี่กับการโจมตีของผู้เล่นคนอื่นในโหมด PvP",
    Value = Config.AutoParryPlayers,
    Callback = function(state)
        Config.AutoParryPlayers = state
    end,
})

ParrySection:Toggle({
    Title = "Auto Feint M1 to Parry (ยกเลิกหมัดเพื่อแพรี่ทันที)",
    Desc = "หากเรากำลังกดต่อย/ฟันอยู่ แล้วศัตรูโจมตีสวนเข้ามา จะ Feint ยกเลิกหมัดเพื่อแพรี่ทันที",
    Value = Config.AutoFeintToParry,
    Callback = function(state)
        Config.AutoFeintToParry = state
    end,
})

ParrySection:Toggle({
    Title = "Auto Block on Parry Cooldown (ยกบล็อกเมื่อติดคูลดาวน์)",
    Desc = "หากแพรี่ติดคูลดาวน์ จะกดยกบล็อกธรรมดาเพื่อลดดาเมจแทน",
    Value = Config.AutoBlockOnParryCooldown,
    Callback = function(state)
        Config.AutoBlockOnParryCooldown = state
    end,
})

ParrySection:Toggle({
    Title = "Face Attacker on Parry (หันหน้าหาศัตรูขณะแพรี่)",
    Desc = "หันตัวละครไปทางทิศทางที่ศัตรูโจมตีเข้ามาทันที",
    Value = Config.AutoFaceAttackerOnParry,
    Callback = function(state)
        Config.AutoFaceAttackerOnParry = state
    end,
})

ParrySection:Toggle({
    Title = "Show Parry Range 3D (เปิด/ปิด วงระยะแพรี่ 3D)",
    Desc = "แสดงวงแหวนนีออน 3D รอบตัวละคร แสดงระยะที่แพรี่จะทำงานในโลกเกมจริง",
    Value = Config.ShowParryVisualRange,
    Callback = function(state)
        Config.ShowParryVisualRange = state
        UpdateParryVisualRange()
    end,
})

ParrySection:Slider({
    Title = "Parry Detection Range (ระยะตรวจจับการโจมตี)",
    Desc = "ระยะตรวจจับอนิเมชั่นการโจมตีรอบตัว (Studs) ปรับได้อิสระตามต้องการ",
    Value = {
        Min = 5,
        Max = 100,
        Default = Config.ParryRange,
    },
    Step = 1,
    Callback = function(val)
        Config.ParryRange = val
        UpdateParryVisualRange()
    end,
})

ParrySection:Slider({
    Title = "Parry Timing Offset (ปรับชดเชยเวลาแพรี่)",
    Desc = "ปรับชดเชยเวลา (+ คือแพรี่เร็วขึ้น, - คือแพรี่ช้าลง) ค่าเริ่มต้น 0 เสถียรที่สุด",
    Value = {
        Min = -0.10,
        Max = 0.10,
        Default = Config.ParryTimingOffset,
    },
    Step = 0.01,
    Callback = function(val)
        Config.ParryTimingOffset = val
    end,
})

task.defer(function()
    UpdateParryVisualRange()
end)

-- SECTION 5: FARM & COMBAT SETTINGS (INCLUDES AUTO RESPAWN)
local FarmSettingsSection = CombatTab:Section({ Title = "5. Farm & Combat Settings (ตั้งค่าการฟาร์ม อาวุธ & ออโต้เกิดใหม่)" })

FarmSettingsSection:Toggle({
    Title = "Auto Respawn on Death (ออโต้กดเกิดใหม่เมื่อตาย)",
    Desc = "เมื่อตัวละครตายและหน้าต่าง 'You have been defeated...' เด้งขึ้นมา จะกดปุ่ม Respawn เกิดใหม่ให้อัตโนมัติทันที!",
    Value = Config.AutoRespawn,
    Callback = function(state)
        Config.AutoRespawn = state
        if state and IsPlayerDead() then
            task.spawn(TriggerPlayerRespawn)
        end
    end,
})

FarmSettingsSection:Button({
    Title = "Respawn Character Now (กดเกิดใหม่ทันที)",
    Desc = "สั่งกด Respawn ทันทีหากติดหน้าจอตาย",
    Callback = function()
        task.spawn(function()
            local ok = TriggerPlayerRespawn()
            WindUI:Notify({
                Title = ok and "Respawned!" or "Respawn Sent",
                Content = "Sent respawn request to DeathService.",
                Duration = 2.5,
            })
        end)
    end,
})

local initialWeapons = GetAvailableWeapons()
WeaponDropdown = FarmSettingsSection:Dropdown({
    Title = "Select Weapon (เลือกอาวุธที่ใช้ตี)",
    Desc = "เลือกอาวุธที่ต้องการให้ถือขณะฟาร์ม",
    Values = initialWeapons,
    Value = table.find(initialWeapons, Config.SelectedWeapon) and Config.SelectedWeapon or initialWeapons[1],
    Callback = function(val)
        Config.SelectedWeapon = val
        EnsureWeaponEquipped()
    end,
})

FarmSettingsSection:Toggle({
    Title = "Auto Equip Weapon (ถืออาวุธอัตโนมัติขณะฟาร์ม)",
    Desc = "ถืออาวุธที่เลือกไว้ตลอดเวลาขณะตีมอนสเตอร์/บอส",
    Value = Config.AutoEquip,
    Callback = function(state)
        Config.AutoEquip = state
        if state then EnsureWeaponEquipped() end
    end,
})

FarmSettingsSection:Button({
    Title = "Refresh Weapons List (รีเฟรชรายการอาวุธในกระเป๋า)",
    Desc = "สแกนหาอาวุธในกระเป๋าใหม่",
    Callback = function()
        local newWeapons = GetAvailableWeapons()
        WeaponDropdown:Refresh(newWeapons)
        WindUI:Notify({
            Title = "Weapons Refreshed",
            Content = "Found " .. tostring(#newWeapons) .. " weapons/tools.",
            Duration = 3,
        })
    end,
})

FarmSettingsSection:Dropdown({
    Title = "Farm Position (ตำแหน่งยืนตีมอน)",
    Desc = "เลือกตำแหน่งเกาะมอนสเตอร์ (ด้านหลัง / ด้านบน / ด้านหน้า)",
    Values = { "Behind", "Above", "Front" },
    Value = Config.FarmMode,
    Callback = function(val)
        Config.FarmMode = val
    end,
})

FarmSettingsSection:Slider({
    Title = "Farm Distance (ระยะห่างจากมอนสเตอร์)",
    Desc = "ระยะห่างในการตีมอนสเตอร์ (Studs)",
    Value = {
        Min = 3,
        Max = 15,
        Default = Config.FarmDistance,
    },
    Step = 1,
    Callback = function(val)
        Config.FarmDistance = val
    end,
})

FarmSettingsSection:Slider({
    Title = "Attack Delay (ความเร็วในการโจมตี M1)",
    Desc = "หน่วงเวลาระหว่างการต่อย/ฟันแต่ละครั้ง (วินาที)",
    Value = {
        Min = 0.1,
        Max = 0.5,
        Default = Config.AttackDelay,
    },
    Step = 0.05,
    Callback = function(val)
        Config.AttackDelay = val
    end,
})

FarmSettingsSection:Dropdown({
    Title = "Travel Method (วิธีเดินทางไปหามอน)",
    Desc = "เลือกระหว่างวาปทันที (Teleport) หรือบินไปแบบสมูท (Tween)",
    Values = { "Teleport", "Tween" },
    Value = Config.TravelMode,
    Callback = function(val)
        Config.TravelMode = val
    end,
})

FarmSettingsSection:Slider({
    Title = "Tween Speed (ความเร็วบิน Tween)",
    Desc = "ความเร็วเมื่อเลือกวิธีเดินทางเป็น Tween (Studs/s)",
    Value = {
        Min = 50,
        Max = 600,
        Default = Config.TweenSpeed,
    },
    Step = 10,
    Callback = function(val)
        Config.TweenSpeed = val
    end,
})

FarmSettingsSection:Toggle({
    Title = "Fast Attack (ตีรัวอัตโนมัติแม้ไม่ได้เปิดฟาร์ม)",
    Desc = "ออกหมัด/ฟัน M1 รัวๆ อัตโนมัติโดยไม่ต้องกดคลิกเอง",
    Value = Config.FastAttack,
    Callback = function(state)
        Config.FastAttack = state
    end,
})

FarmSettingsSection:Toggle({
    Title = "Noclip (เดินทะลุกำแพง)",
    Desc = "เดินและบินทะลุสิ่งกีดขวาง",
    Value = Config.Noclip,
    Callback = function(state)
        Config.Noclip = state
    end,
})

FarmSettingsSection:Toggle({
    Title = "Target ESP / Highlight (มองทะลุมอนสเตอร์เป้าหมาย)",
    Desc = "ไฮไลท์สีแดงที่ตัวมอนสเตอร์หรือบอสเป้าหมายให้เห็นทะลุกำแพง",
    Value = Config.MobESP,
    Callback = function(state)
        Config.MobESP = state
        if UpdateESP then UpdateESP() end
    end,
})

-- ==================== TAB 2: NEN & MEDITATION ====================
local NenTab = Window:Tab({
    Title = "Nen & Meditation",
    Icon = "flame",
})

local NenStatusParagraph = NenTab:Paragraph({
    Title = "Nen Status Overview",
    Desc = "Loading status...",
})

task.spawn(function()
    while _G.BeyondNenInstanceId == myInstanceId do
        task.wait(0.5)
        local unlocked = LocalPlayer:GetAttribute("NenUnlocked") == true and "Unlocked" or "Locked"
        local affinity = LocalPlayer:GetAttribute("NenAffinity") or "Unknown"
        local currentTech = LocalPlayer:GetAttribute("MeditationTechnique") or "Ten"
        local tier = LocalPlayer:GetAttribute("NenTier_" .. currentTech) or 0
        local xp = LocalPlayer:GetAttribute("NenXP_" .. currentTech) or 0
        local nextXP = TierThresholds[tier + 1] or 3500
        local curNen = math.floor(LocalPlayer:GetAttribute("CurrentNen") or 0)
        local maxNen = math.floor(LocalPlayer:GetAttribute("MaxNen") or 100)
        local reserve = math.floor(LocalPlayer:GetAttribute("CurrentNenReserve") or 0)

        NenStatusParagraph:SetDesc(string.format(
            "Nen: %s | Affinity: %s\nNen Power: %d/%d | Reserve: %d\nTraining: %s (Tier %d - %d/%d XP)",
            unlocked, affinity, curNen, maxNen, reserve, currentTech, tier, xp, nextXP
        ))
    end
end)

local MeditateSection = NenTab:Section({ Title = "Auto Meditation (100% Perfect QTE)" })

MeditateSection:Toggle({
    Title = "Auto Solve Minigame (100% Perfect)",
    Desc = "Automatically solves all bubble clicks and key QTE prompts for max bonus XP & streak",
    Value = Config.AutoSolveMinigame,
    Callback = function(state)
        Config.AutoSolveMinigame = state
    end,
})

MeditateSection:Toggle({
    Title = "Auto Meditate Loop",
    Desc = "Places mat at feet and loops meditation continuously without stopping",
    Value = Config.AutoMeditation,
    Callback = function(state)
        Config.AutoMeditation = state
        if not state then
            pcall(function()
                MeditationService:StopMeditation():await()
            end)
        end
    end,
})

MeditateSection:Button({
    Title = "Place Mat & Meditate Now",
    Desc = "Immediately places a meditation mat at your feet and starts meditating",
    Callback = function()
        local hrp = GetHRP()
        if hrp then
            pcall(function()
                MeditationService:PlaceCarpet(hrp.Position - Vector3.new(0, 2.5, 0)):await()
            end)
            task.wait(0.3)
            pcall(function()
                MeditationService:StartMeditation():await()
            end)
            WindUI:Notify({
                Title = "Meditation",
                Content = "Started meditating!",
                Duration = 3,
            })
        end
    end,
})

MeditateSection:Button({
    Title = "Stop Meditating",
    Desc = "Stops meditation and clears current mat",
    Callback = function()
        pcall(function()
            MeditationService:StopMeditation():await()
            MeditationService:UnplaceCarpet()
        end)
        WindUI:Notify({
            Title = "Meditation",
            Content = "Stopped meditation.",
            Duration = 3,
        })
    end,
})

MeditateSection:Button({
    Title = "Buy Meditation Mat (2,500 Jenni)",
    Desc = "Purchases a permanent Meditation Mat from the Merchant in 1 click",
    Callback = function()
        pcall(function()
            MerchantService:purchase("003")
        end)
        WindUI:Notify({
            Title = "Shop",
            Content = "Purchase request sent to Merchant for Meditation Mat!",
            Duration = 4,
        })
    end,
})

local MasterySection = NenTab:Section({ Title = "Nen Technique Mastery" })

MasterySection:Dropdown({
    Title = "Select Technique to Train",
    Desc = "Choose which Nen technique to gain XP for during meditation",
    Values = NenTechniques,
    Value = Config.SelectedTechnique,
    Callback = function(val)
        Config.SelectedTechnique = val
        pcall(function()
            NenMasteryService:SetMeditationTechnique(val)
        end)
        WindUI:Notify({
            Title = "Technique Set",
            Content = "Now training: " .. val,
            Duration = 3,
        })
    end,
})

MasterySection:Toggle({
    Title = "Auto Upgrade Technique Tiers",
    Desc = "Automatically levels up technique tiers when enough XP is reached",
    Value = Config.AutoUpgradeTier,
    Callback = function(state)
        Config.AutoUpgradeTier = state
    end,
})

local NodeSection = NenTab:Section({ Title = "Nen Affinity & Aura Nodes" })

NodeSection:Dropdown({
    Title = "Target Nen Affinity",
    Desc = "Select the affinity you want to roll for",
    Values = NenAffinities,
    Value = Config.TargetAffinity,
    Callback = function(val)
        Config.TargetAffinity = val
    end,
})

NodeSection:Toggle({
    Title = "Auto Roll Affinity",
    Desc = "Continuously rolls Nen Affinity until the target affinity is achieved",
    Value = Config.AutoRollAffinity,
    Callback = function(state)
        Config.AutoRollAffinity = state
    end,
})

NodeSection:Button({
    Title = "Roll Affinity (Once)",
    Desc = "Rolls Nen Affinity one time",
    Callback = function()
        pcall(function()
            NenService:roll_nen_affinity()
        end)
    end,
})

NodeSection:Button({
    Title = "Unlock & Heal All Aura Nodes (1-7)",
    Desc = "Opens and heals all 7 aura nodes in your character",
    Callback = function()
        task.spawn(function()
            for i = 1, 7 do
                pcall(function()
                    NenService:open_aura_node(i)
                    NenService:heal_aura_node(i)
                end)
                task.wait(0.2)
            end
            WindUI:Notify({
                Title = "Aura Nodes",
                Content = "Processed nodes 1 through 7!",
                Duration = 4,
            })
        end)
    end,
})

local TeleportSection = NenTab:Section({ Title = "Nen NPCs & Waypoints" })

TeleportSection:Button({
    Title = "Teleport to Rohan (Activate Nen NPC)",
    Desc = "Warps inside the Nen Cave right in front of Rohan",
    Callback = function()
        local hrp = GetHRP()
        if hrp then
            hrp.CFrame = CFrame.new(-4343.87, 426.20, -914.85)
            WindUI:Notify({
                Title = "Teleport",
                Content = "Teleported to Rohan!",
                Duration = 3,
            })
        end
    end,
})

TeleportSection:Button({
    Title = "Teleport to Shin (Nen Merchant)",
    Desc = "Warps to Shin the Nen seller",
    Callback = function()
        local hrp = GetHRP()
        if hrp then
            hrp.CFrame = CFrame.new(-4182.20, 411.85, -994.80)
            WindUI:Notify({
                Title = "Teleport",
                Content = "Teleported to Shin!",
                Duration = 3,
            })
        end
    end,
})

-- ==================== TAB 3: CHESTS & INVENTORY ====================
local ChestTab = Window:Tab({
    Title = "Chests & Inventory",
    Icon = "package",
})

local ChestStatusParagraph = ChestTab:Paragraph({
    Title = "Chests & Loot Overview",
    Desc = "Scanning chests...",
})

task.spawn(function()
    while _G.BeyondNenInstanceId == myInstanceId do
        task.wait(0.6)
        local worldChests = GetWorldChests()
        local invChests = GetInventoryChests()
        local jenni = LocalPlayer:GetAttribute("Jenni") or 0

        local invChestNames = {}
        for _, c in ipairs(invChests) do
            table.insert(invChestNames, c.name .. " (x" .. c.quantity .. ")")
        end
        local invStr = #invChestNames > 0 and table.concat(invChestNames, ", ") or "None"

        ChestStatusParagraph:SetDesc(string.format(
            "World Chests Active: %d | Jenni: ¥%d\nOwned Chests: %s",
            #worldChests, jenni, invStr
        ))
    end
end)

-- ----------------- World Chests Section -----------------
local WorldChestSection = ChestTab:Section({ Title = "World Chests Automation" })

WorldChestSection:Toggle({
    Title = "Auto Loot World Chests",
    Desc = "Automatically travels to and claims all openable chests spawned in the world",
    Value = Config.AutoLootChests,
    Callback = function(state)
        Config.AutoLootChests = state
    end,
})

WorldChestSection:Toggle({
    Title = "Chest ESP / Highlights",
    Desc = "Highlights active world chests with rarity colors through walls",
    Value = Config.ChestESP,
    Callback = function(state)
        Config.ChestESP = state
        UpdateChestESP()
    end,
})

WorldChestSection:Button({
    Title = "Teleport to Nearest World Chest",
    Desc = "Warps directly to the closest active chest",
    Callback = function()
        local worldChests = GetWorldChests()
        local hrp = GetHRP()
        if hrp and #worldChests > 0 then
            local myPos = hrp.Position
            local closest = nil
            local bestDist = math.huge
            for _, c in ipairs(worldChests) do
                local dist = (c:GetPivot().Position - myPos).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    closest = c
                end
            end
            if closest then
                local pos = closest:GetPivot().Position
                hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 3), pos)
                WindUI:Notify({
                    Title = "Chest Teleport",
                    Content = "Teleported to " .. closest.Name .. " (" .. math.floor(bestDist) .. " studs)",
                    Duration = 3,
                })
            end
        else
            WindUI:Notify({
                Title = "No Chests",
                Content = "No active chests currently spawned in the world.",
                Duration = 3,
            })
        end
    end,
})

-- ----------------- Inventory Chests Section -----------------
local InvChestSection = ChestTab:Section({ Title = "Inventory Chests Opener" })

local initialInvChests = GetInventoryChests()
local initialInvNames = {}
for _, c in ipairs(initialInvChests) do
    table.insert(initialInvNames, c.name)
end
if #initialInvNames == 0 then table.insert(initialInvNames, "None") end

local InvChestDropdown = InvChestSection:Dropdown({
    Title = "Select Inventory Chest",
    Desc = "Choose a chest from your inventory to place and open",
    Values = initialInvNames,
    Value = initialInvNames[1],
    Callback = function(val)
        Config.SelectedInventoryChest = val
    end,
})

InvChestSection:Button({
    Title = "Refresh Inventory Chests",
    Desc = "Re-scans inventory for chests",
    Callback = function()
        local list = GetInventoryChests()
        local names = {}
        for _, c in ipairs(list) do table.insert(names, c.name) end
        if #names == 0 then table.insert(names, "None") end
        InvChestDropdown:Refresh(names)
        WindUI:Notify({
            Title = "Refreshed",
            Content = "Found " .. tostring(#list) .. " chests in inventory.",
            Duration = 3,
        })
    end,
})

InvChestSection:Button({
    Title = "Open Selected Chest",
    Desc = "Places and loots the selected inventory chest",
    Callback = function()
        local list = GetInventoryChests()
        for _, c in ipairs(list) do
            if c.name == Config.SelectedInventoryChest then
                task.spawn(function()
                    AutoOpenChestPipeline(c.uuid)
                end)
                return
            end
        end
        WindUI:Notify({
            Title = "Chest Not Found",
            Content = "Selected chest not found in inventory.",
            Duration = 3,
        })
    end,
})

InvChestSection:Toggle({
    Title = "Auto Open All Owned Chests",
    Desc = "Continuously places and claims every chest in your inventory until finished",
    Value = Config.AutoOpenInventoryChests,
    Callback = function(state)
        Config.AutoOpenInventoryChests = state
    end,
})

InvChestSection:Button({
    Title = "Teleport Outside Safe Zone (To Place Chests)",
    Desc = "Warps to open field outside Town2 so chests can be placed freely",
    Callback = function()
        local hrp = GetHRP()
        if hrp then
            hrp.CFrame = CFrame.new(-3473, 586, -48)
            WindUI:Notify({
                Title = "Teleport",
                Content = "Teleported outside safe zone!",
                Duration = 3,
            })
        end
    end,
})

-- ----------------- Inventory & Gear Management -----------------
local GearSection = ChestTab:Section({ Title = "Gear & Outfits (ระบบสวมใส่อุปกรณ์ & เสื้อผ้า)" })

local GearStatusParagraph = GearSection:Paragraph({
    Title = "Equipped Gear Status",
    Desc = "Scanning equipped gear...",
})

task.spawn(function()
    while _G.BeyondNenInstanceId == myInstanceId do
        task.wait(1)
        local curOutfitUUID = LocalPlayer:GetAttribute("CustomOutfitUUID") or ""
        local outfits, accessories = GetInventoryGear()
        
        local outfitName = "None"
        for _, o in ipairs(outfits) do
            if o.uuid == curOutfitUUID or o.equipped then
                outfitName = o.name
                break
            end
        end
        
        local accNames = {}
        for _, a in ipairs(accessories) do
            if a.equipped then
                table.insert(accNames, a.name)
            end
        end
        local accStr = #accNames > 0 and table.concat(accNames, ", ") or "None"
        
        GearStatusParagraph:SetDesc(string.format("Current Outfit: %s\nCurrent Accessories: %s", outfitName, accStr))
    end
end)

local initialOutfits, initialAccessories = GetInventoryGear()
local initialOutfitNames = {}
for _, o in ipairs(initialOutfits) do
    table.insert(initialOutfitNames, o.name)
end
if #initialOutfitNames == 0 then table.insert(initialOutfitNames, "None") end

local initialAccNames = {}
for _, a in ipairs(initialAccessories) do
    table.insert(initialAccNames, a.name)
end
if #initialAccNames == 0 then table.insert(initialAccNames, "None") end

local OutfitDropdown = GearSection:Dropdown({
    Title = "Select Outfit (เลือกชุด)",
    Desc = "Choose an outfit or armor from inventory",
    Values = initialOutfitNames,
    Value = initialOutfitNames[1],
    Callback = function(val)
        Config.SelectedOutfit = val
    end,
})

GearSection:Button({
    Title = "Equip Selected Outfit (สวมใส่ชุดที่เลือก)",
    Desc = "Equips the chosen outfit on your character",
    Callback = function()
        local outfits = GetInventoryGear()
        for _, o in ipairs(outfits) do
            if o.name == Config.SelectedOutfit then
                local ok = EquipGearItem(o.uuid)
                WindUI:Notify({
                    Title = ok and "Outfit Equipped" or "Equip Failed",
                    Content = ok and ("Equipped: " .. o.name) or "Could not equip outfit",
                    Duration = 3,
                })
                return
            end
        end
        WindUI:Notify({
            Title = "Not Found",
            Content = "Please select a valid outfit from the dropdown.",
            Duration = 3,
        })
    end,
})

GearSection:Button({
    Title = "Unequip Outfit (ถอดชุด)",
    Desc = "Unequips the currently equipped outfit",
    Callback = function()
        local curOutfitUUID = LocalPlayer:GetAttribute("CustomOutfitUUID")
        if curOutfitUUID and curOutfitUUID ~= "" then
            UnequipGearItem(curOutfitUUID)
            WindUI:Notify({
                Title = "Outfit Unequipped",
                Content = "Removed outfit from character.",
                Duration = 3,
            })
        else
            local outfits = GetInventoryGear()
            for _, o in ipairs(outfits) do
                if o.equipped then
                    UnequipGearItem(o.uuid)
                end
            end
            WindUI:Notify({
                Title = "Outfit Unequipped",
                Content = "Cleared all equipped outfits.",
                Duration = 3,
            })
        end
    end,
})

local AccessoryDropdown = GearSection:Dropdown({
    Title = "Select Accessory (เลือกเครื่องประดับ/หน้ากาก)",
    Desc = "Choose a mask or accessory from inventory",
    Values = initialAccNames,
    Value = initialAccNames[1],
    Callback = function(val)
        Config.SelectedAccessory = val
    end,
})

GearSection:Button({
    Title = "Equip Selected Accessory (สวมใส่เครื่องประดับ)",
    Desc = "Equips the chosen accessory or mask",
    Callback = function()
        local _, accessories = GetInventoryGear()
        for _, a in ipairs(accessories) do
            if a.name == Config.SelectedAccessory then
                local ok = EquipGearItem(a.uuid)
                WindUI:Notify({
                    Title = ok and "Accessory Equipped" or "Equip Failed",
                    Content = ok and ("Equipped: " .. a.name) or "Could not equip accessory",
                    Duration = 3,
                })
                return
            end
        end
        WindUI:Notify({
            Title = "Not Found",
            Content = "Please select a valid accessory from the dropdown.",
            Duration = 3,
        })
    end,
})

GearSection:Button({
    Title = "Unequip Accessory (ถอดเครื่องประดับ)",
    Desc = "Unequips the selected accessory or mask",
    Callback = function()
        local _, accessories = GetInventoryGear()
        for _, a in ipairs(accessories) do
            if a.name == Config.SelectedAccessory or a.equipped then
                UnequipGearItem(a.uuid)
            end
        end
        WindUI:Notify({
            Title = "Accessory Unequipped",
            Content = "Removed accessory.",
            Duration = 3,
        })
    end,
})

GearSection:Button({
    Title = "Auto Equip Best Gear (สวมใส่อุปกรณ์ที่ดีที่สุดอัตโนมัติ)",
    Desc = "Automatically equips highest tier armor outfit and mask available",
    Callback = function()
        local outfits, accessories = GetInventoryGear()
        local equippedAny = false
        if #outfits > 0 then
            local bestOutfit = outfits[1]
            for _, o in ipairs(outfits) do
                if string.find(o.name:lower(), "arcane") then
                    bestOutfit = o
                    break
                end
            end
            EquipGearItem(bestOutfit.uuid)
            equippedAny = true
        end
        if #accessories > 0 then
            local bestAcc = accessories[1]
            for _, a in ipairs(accessories) do
                if string.find(a.name:lower(), "warick") or string.find(a.name:lower(), "friend") then
                    bestAcc = a
                    break
                end
            end
            EquipGearItem(bestAcc.uuid)
            equippedAny = true
        end
        WindUI:Notify({
            Title = "Auto Equip",
            Content = equippedAny and "Best available gear equipped!" or "No gear found in inventory.",
            Duration = 4,
        })
    end,
})

GearSection:Button({
    Title = "Refresh Gear List (รีเฟรชรายการอุปกรณ์)",
    Desc = "Re-scans inventory and updates outfit/accessory dropdowns",
    Callback = function()
        local outfits, accessories = GetInventoryGear()
        local oNames = {}
        for _, o in ipairs(outfits) do table.insert(oNames, o.name) end
        if #oNames == 0 then table.insert(oNames, "None") end
        OutfitDropdown:Refresh(oNames)
        
        local aNames = {}
        for _, a in ipairs(accessories) do table.insert(aNames, a.name) end
        if #aNames == 0 then table.insert(aNames, "None") end
        AccessoryDropdown:Refresh(aNames)
        
        WindUI:Notify({
            Title = "Refreshed",
            Content = string.format("Found %d Outfits and %d Accessories.", #outfits, #accessories),
            Duration = 3,
        })
    end,
})

-- ==================== TAB 4: AUTO FISHING ====================
local FishingTab = Window:Tab({
    Title = "Auto Fishing",
    Icon = "anchor",
})

local FishingStatusParagraph = FishingTab:Paragraph({
    Title = "Fishing Overview & Status",
    Desc = "Status: Idle",
})

task.spawn(function()
    while _G.BeyondNenInstanceId == myInstanceId do
        task.wait(0.5)
        local _, _, spotName = GetTargetFishingSpot()
        local rodEquipped = FishingConfig.FindRod(GetCharacter()) ~= nil
        local rodStatus = rodEquipped and "Equipped in Hand" or "Not in Hand"
        
        FishingStatusParagraph:SetDesc(string.format(
            "Status: %s\nTarget Spot: %s | Rod: %s\nFish Caught: %d | Chests Fished: %d | Total: %d",
            FishingStats.Status,
            spotName,
            rodStatus,
            FishingStats.FishCount,
            FishingStats.ChestCount,
            FishingStats.TotalFished
        ))
    end
end)

local FishingMainSection = FishingTab:Section({ Title = "Fishing Automation (ระบบตกปลาอัตโนมัติ)" })

FishingMainSection:Toggle({
    Title = "Auto Fishing (เปิดระบบตกปลาอัตโนมัติ)",
    Desc = "Automatically travels to spot, casts, solves bite minigame, and reels in fish",
    Value = Config.AutoFishing,
    Callback = function(state)
        Config.AutoFishing = state
        if not state then
            FishingStats.Status = "Stopped"
            if isFishingCastActive and currentCastId then
                pcall(function() FishingService:Reel(currentCastId):await() end)
                isFishingCastActive = false
            end
        end
    end,
})

FishingMainSection:Toggle({
    Title = "Auto Solve Minigame (แก้และดึงปลาอัตโนมัติ 100%)",
    Desc = "Automatically tracks fish target with deadzone precision so you never lose a fish",
    Value = Config.AutoSolveFishing,
    Callback = function(state)
        Config.AutoSolveFishing = state
    end,
})

FishingMainSection:Toggle({
    Title = "Auto Teleport to Fishing Spot (วาปไปยังจุดตกปลาอัตโนมัติ)",
    Desc = "Teleports to the chosen fishing spot when Auto Fishing is active",
    Value = Config.AutoTeleportToFishingSpot,
    Callback = function(state)
        Config.AutoTeleportToFishingSpot = state
    end,
})

local FishingSpotSection = FishingTab:Section({ Title = "Fishing Spot & Teleport (จุดตกปลา & วาป)" })

local CustomSpotToggle = FishingSpotSection:Toggle({
    Title = "Use Custom Fishing Spot (ใช้จุดตกปลาที่บันทึกไว้)",
    Desc = "เปิดเพื่อไปจุดที่บันทึกเอง / ปิดเพื่อกลับไปจุดเริ่มต้น Deep Forest Lake",
    Value = Config.UseCustomFishingSpot,
    Callback = function(state)
        if state and not Config.CustomFishingCFrame then
            WindUI:Notify({
                Title = "No Custom Spot",
                Content = "You haven't set a custom spot yet! Stand near water and click 'Set Current Position' first.",
                Duration = 4,
            })
            Config.UseCustomFishingSpot = false
            return
        end
        Config.UseCustomFishingSpot = state
    end,
})

FishingSpotSection:Button({
    Title = "Set Current Position as Custom Spot (บันทึกจุดตกปลาปัจจุบัน)",
    Desc = "บันทึกพิกัดที่คุณยืนอยู่ และหันหน้าไปที่ผิวน้ำ พร้อมเปิดใช้จุดนี้ให้อัตโนมัติ",
    Callback = function()
        local ok, err = SetCustomSpotFromPlayer()
        if ok then
            Config.UseCustomFishingSpot = true
            WindUI:Notify({
                Title = "Spot Saved!",
                Content = "Saved current spot and activated custom mode!",
                Duration = 4,
            })
        else
            WindUI:Notify({
                Title = "Failed",
                Content = "Could not save spot: " .. tostring(err),
                Duration = 3,
            })
        end
    end,
})

FishingSpotSection:Button({
    Title = "Teleport to Fishing Spot Now (วาปไปยังจุดตกปลาทันที)",
    Desc = "Warps your character directly to the active fishing spot (Custom or Deep Forest Lake)",
    Callback = function()
        local standCF, _, spotName = GetTargetFishingSpot()
        local hrp = GetHRP()
        if hrp and standCF then
            hrp.CFrame = standCF
            hrp.AssemblyLinearVelocity = Vector3.zero
            WindUI:Notify({
                Title = "Teleport",
                Content = "Teleported to " .. spotName .. "!",
                Duration = 3,
            })
        end
    end,
})

local RodSection = FishingTab:Section({ Title = "Fishing Rod Tools (จัดการเบ็ดตกปลา)" })

RodSection:Button({
    Title = "Equip Fishing Rod (หยิบเบ็ดตกปลามาถือ)",
    Desc = "Equips your fishing rod into hand from inventory/backpack",
    Callback = function()
        local ok = EnsureRodEquipped()
        WindUI:Notify({
            Title = ok and "Rod Equipped" or "Rod Not Found",
            Content = ok and "Fishing rod is now equipped in hand!" or "No fishing rod found. Click 'Get Free Basic Rod' below!",
            Duration = 3,
        })
    end,
})

RodSection:Button({
    Title = "Get Free Basic Rod (Fisherman Hal) (รับเบ็ดตกปลาฟรีจากคุณตา Hal)",
    Desc = "Warps to Fisherman Hal in Deep Forest and automatically claims a free Basic Rod",
    Callback = function()
        task.spawn(function()
            ClaimFreeRodFromHal()
            task.wait(1)
            EnsureRodEquipped()
            WindUI:Notify({
                Title = "Fisherman Hal",
                Content = "Claim request sent to Fisherman Hal!",
                Duration = 4,
            })
        end)
    end,
})

WindUI:Notify({
    Title = "Beyond Nen Hub v8",
    Content = "All Modules (Combat, Nen, Chests, Fishing, Mining & Quests) Loaded Successfully!",
    Duration = 5,
})

-- ==================== TAB 5: MINING & GATHERING ====================
local MiningTab = Window:Tab({
    Title = "Auto Mining",
    Icon = "pickaxe",
})

local MiningStatusParagraph = MiningTab:Paragraph({
    Title = "Mining Overview & Status",
    Desc = "Status: Idle",
})

task.spawn(function()
    while _G.BeyondNenInstanceId == myInstanceId do
        task.wait(0.5)
        local char = GetCharacter()
        local pickEquipped = char and Pickaxes.Has(char)
        local pickStatus = pickEquipped and "Equipped in Hand" or "Not in Hand"
        local isInside = MinesArea.PlayerInside(LocalPlayer) and "Inside Mines" or "Outside Mines"
        local oresDict, totalOreCount = GetInventoryOres()
        local jenni = LocalPlayer:GetAttribute("Jenni") or 0
        
        local oreDetails = {}
        for oreName, count in pairs(oresDict) do
            table.insert(oreDetails, string.format("%s: %d", oreName, count))
        end
        local oreStr = #oreDetails > 0 and table.concat(oreDetails, ", ") or "None"
        
        MiningStatusParagraph:SetDesc(string.format(
            "Status: %s\nTarget Ore: %s | Zone: %s\nPickAxe: %s | Current Jenni: %s\nOres in Bag: %d (%s)\nOres Mined: %d | Jenni Earned: +%d",
            MiningStats.Status,
            Config.SelectedOre,
            isInside,
            pickStatus,
            tostring(jenni),
            totalOreCount,
            oreStr,
            MiningStats.OresMined,
            MiningStats.TotalJenniEarned
        ))
    end
end)

local MiningMainSection = MiningTab:Section({ Title = "Mining Automation (ระบบขุดแร่อัตโนมัติ)" })

MiningMainSection:Toggle({
    Title = "Auto Mine (เปิดระบบขุดแร่อัตโนมัติ)",
    Desc = "Automatically travels to ores inside mines, equips pickaxe, and mines nodes",
    Value = Config.AutoMine,
    Callback = function(state)
        Config.AutoMine = state
        if not state then
            MiningStats.Status = "Stopped"
        end
    end,
})

MiningMainSection:Dropdown({
    Title = "Select Target Ore (เลือกแร่ที่ต้องการขุด)",
    Desc = "Choose a specific ore or All Ores to mine anything nearby",
    Values = AvailableOres,
    Value = Config.SelectedOre,
    Callback = function(choice)
        Config.SelectedOre = choice
    end,
})

MiningMainSection:Toggle({
    Title = "Auto Sell Ores (ขายแร่อัตโนมัติเมื่อครบกำหนด)",
    Desc = "Automatically warps to Ore Merchant to sell ores when bag reaches threshold, then returns",
    Value = Config.AutoSellOres,
    Callback = function(state)
        Config.AutoSellOres = state
    end,
})

MiningMainSection:Slider({
    Title = "Sell Threshold (จำนวนแร่ก่อนไปขาย)",
    Desc = "Number of ores in inventory required to trigger Auto Sell",
    Value = {
        Min = 1,
        Max = 50,
        Default = Config.AutoSellOreThreshold,
    },
    Step = 1,
    Callback = function(val)
        local n = tonumber(val)
        if n then
            Config.AutoSellOreThreshold = math.clamp(math.floor(n), 1, 50)
        end
    end,
})

MiningMainSection:Dropdown({
    Title = "Travel Mode (รูปแบบการเดินทางในเหมือง)",
    Desc = "Choose between instant Teleport or smooth Tween",
    Values = { "Teleport", "Tween" },
    Value = Config.MineTravelMode,
    Callback = function(choice)
        Config.MineTravelMode = choice
    end,
})

MiningMainSection:Toggle({
    Title = "Kill Nearby Mobs (ต่อยมอนที่เข้ามาใกล้ให้ตาย)",
    Desc = "เมื่อมีมอนสเตอร์อยู่ใกล้หรือเข้ามาขัดขวาง จะสลับอาวุธไปต่อยมอนให้ตายก่อน แล้วค่อยกลับมาขุดต่อ",
    Value = Config.MineDefendMobs,
    Callback = function(state)
        Config.MineDefendMobs = state
    end,
})

MiningMainSection:Toggle({
    Title = "Skip Ores Near Mobs (ข้ามแร่ที่มีมอนสเตอร์เฝ้า)",
    Desc = "ไม่วาปไปหาแร่ที่มีมอนสเตอร์เกิดหรือยืนอยู่ใกล้ๆ (ระยะ 22 studs) เพื่อหลีกเลี่ยงการโดนโจมตี",
    Value = Config.SkipOresWithMobs,
    Callback = function(state)
        Config.SkipOresWithMobs = state
    end,
})

local OreSellSection = MiningTab:Section({ Title = "Ore Selling & Merchant (ขายแร่ & เงิน Jenni)" })

OreSellSection:Button({
    Title = "Sell All Ores Now (ขายแร่ทั้งหมดทันที)",
    Desc = "Warps to Ore Merchant, sells all ores in your bag, and collects Jenni",
    Callback = function()
        task.spawn(function()
            local earned, count = SellAllOres()
            WindUI:Notify({
                Title = "Ore Merchant",
                Content = count > 0 and string.format("Sold %d ores for +%d Jenni!", count, earned) or "No sellable ores found in inventory!",
                Duration = 4,
            })
        end)
    end,
})

OreSellSection:Button({
    Title = "Teleport to Ore Merchant (วาปไปคนรับซื้อแร่)",
    Desc = "Warps to the Ore Merchant NPC in the village (-824.6, 274, -405.28)",
    Callback = function()
        local hrp = GetHRP()
        if hrp then
            hrp.CFrame = CFrame.new(-824.6, 274, -405.28)
            hrp.AssemblyLinearVelocity = Vector3.zero
            WindUI:Notify({
                Title = "Teleport",
                Content = "Teleported to Ores Merchant!",
                Duration = 3,
            })
        end
    end,
})

local MinesToolsSection = MiningTab:Section({ Title = "Pickaxe & Mines Teleport (จัดการอุปกรณ์ & วาปเหมือง)" })

MinesToolsSection:Button({
    Title = "Equip PickAxe (หยิบที่ขุดแร่มาถือ)",
    Desc = "Equips your pickaxe into hand from backpack or inventory",
    Callback = function()
        local ok = EnsurePickaxeEquipped()
        WindUI:Notify({
            Title = ok and "PickAxe Equipped" or "PickAxe Missing",
            Content = ok and "PickAxe is now equipped in hand!" or "No pickaxe found! Click 'Buy Basic PickAxe' below.",
            Duration = 3,
        })
    end,
})

MinesToolsSection:Button({
    Title = "Buy Basic PickAxe (500 Jenni) (ซื้อที่ขุดแร่จากร้าน)",
    Desc = "Warps to the tool merchant store and purchases a Basic PickAxe for 500 Jenni",
    Callback = function()
        task.spawn(function()
            local bought = BuyPickAxe()
            WindUI:Notify({
                Title = bought and "Purchased!" or "Purchase Failed",
                Content = bought and "Bought and equipped PickAxe!" or "Could not purchase PickAxe. Need 500 Jenni!",
                Duration = 4,
            })
        end)
    end,
})

MinesToolsSection:Button({
    Title = "Teleport Inside Mines (วาปเข้าไปในเหมือง)",
    Desc = "Warps directly into the Mines cavern interior (-2009, -626, -7413)",
    Callback = function()
        local hrp = GetHRP()
        if hrp then
            hrp.CFrame = CFrame.new(MinesArea.ExitPosition + Vector3.new(0, 3, 10))
            hrp.AssemblyLinearVelocity = Vector3.zero
            WindUI:Notify({
                Title = "Teleport",
                Content = "Teleported inside Mines Cavern!",
                Duration = 3,
            })
        end
    end,
})

MinesToolsSection:Button({
    Title = "Teleport to Mine Entrance (วาปไปหน้าทางเข้าเหมืองบนผิวดิน)",
    Desc = "Warps to the surface entrance of the mine (-1282, 342, -644)",
    Callback = function()
        local hrp = GetHRP()
        if hrp then
            hrp.CFrame = CFrame.new(-1282, 342, -644)
            hrp.AssemblyLinearVelocity = Vector3.zero
            WindUI:Notify({
                Title = "Teleport",
                Content = "Teleported to Mine Entrance!",
                Duration = 3,
            })
        end
    end,
})

-- ==================== TAB 6: AUTO QUESTS & MILESTONES ====================
local QuestTab = Window:Tab({
    Title = "Quests & Milestones",
    Icon = "book-open",
})

local QuestStatusParagraph = QuestTab:Paragraph({
    Title = "Quests & Storyline Boards Status (สถานะเควส & กระดานเควส)",
    Desc = "Loading quests status...",
})

task.spawn(function()
    while _G.BeyondNenInstanceId == myInstanceId do
        task.wait(0.6)
        local activeQuests = GetActiveQuests()
        QuestsStats.ActiveCount = #activeQuests
        QuestsStats.CompletedCount = GetCompletedQuestsCount()
        local myLv = LocalPlayer:GetAttribute("Level") or 1
        local recMob, recQuest = GetRecommendedLevelTarget(myLv)

        local unlockedBoards = 0
        for _, b in ipairs(IslandQuestBoards) do
            if b.BoardId and b.BoardId ~= "Whale_Hal" then
                local st = LocalPlayer:GetAttribute("SB_" .. b.BoardId)
                if st and st ~= "Intro" then
                    unlockedBoards = unlockedBoards + 1
                end
            end
        end

        local activeDesc = {}
        if #activeQuests == 0 then
            table.insert(activeDesc, "• No active quests.")
        else
            for _, q in ipairs(activeQuests) do
                local progStr = ""
                if q.Target > 0 then
                    progStr = string.format(" (%d/%d)", q.Progress, q.Target)
                elseif q.Stage > 1 then
                    progStr = string.format(" (Stage %d)", q.Stage)
                end
                local info = QuestNameToDetailsMap[q.Name]
                local extra = info and string.format(" -> %s [%d XP / %d ¥]", info.MobName, info.Xp, info.Money) or ""
                table.insert(activeDesc, string.format("• %s%s%s", q.Name, progStr, extra))
            end
        end

        QuestStatusParagraph:SetDesc(string.format(
            "Player Level: %d | Recommended: %s (%s)\nStoryline Boards Unlocked: %d / 9\nActive Quests (%d):\n%s\n\nTotal Completed: %d | Last Action: %s\nCollected This Session: %d | Milestones: %d | Storylines: %d",
            myLv,
            tostring(recMob),
            tostring(recQuest and recQuest.QuestName or "None"),
            unlockedBoards,
            QuestsStats.ActiveCount,
            table.concat(activeDesc, "\n"),
            QuestsStats.CompletedCount,
            QuestsStats.LastAction,
            QuestsStats.TotalCollected,
            QuestsStats.TotalMilestonesClaimed,
            QuestsStats.TotalStorylineClaimed
        ))
    end
end)

-- ====================================================================
-- SECTION 1: QUEST AUTOMATION SETTINGS (ตั้งค่าระบบออโต้เควส)
-- ====================================================================
local QuestAutoSection = QuestTab:Section({ Title = "1. Quest Automation Settings (ตั้งค่าระบบออโต้เควส)" })

QuestAutoSection:Toggle({
    Title = "Auto Collect Completed Quests (ส่งเควสอัตโนมัติเมื่อทำเสร็จ)",
    Desc = "ส่งเควสที่ทำครบจำนวนแล้วอัตโนมัติทันทีเพื่อรับ EXP, เงิน Jenni และรางวัล",
    Value = Config.AutoCollectQuests,
    Callback = function(state)
        Config.AutoCollectQuests = state
    end,
})

QuestAutoSection:Toggle({
    Title = "Auto Repeat Quests (กดรับเควสซ้ำวนลูปอัตโนมัติ)",
    Desc = "รับข้อเสนอทำเควสซ้ำอัตโนมัติเพื่อให้ฟาร์มต่อเนื่องได้เรื่อยๆ",
    Value = Config.AutoRepeatQuests,
    Callback = function(state)
        Config.AutoRepeatQuests = state
    end,
})

QuestAutoSection:Button({
    Title = "Collect All Active Quests (กดส่งเควสที่ทำเสร็จทั้งหมดทันที)",
    Desc = "ส่งเควสที่กำลังทำอยู่ทั้งหมดทันที",
    Callback = function()
        local active = GetActiveQuests()
        local collected = 0
        for _, q in ipairs(active) do
            if CollectQuest(q.Name) then
                collected = collected + 1
            end
        end
        WindUI:Notify({
            Title = "Quests Collection",
            Content = string.format("Attempted collection for %d quests.", #active),
            Duration = 3,
        })
    end,
})

QuestAutoSection:Button({
    Title = "Abandon All Active Quests (ยกเลิกเควสที่รับค้างอยู่ทั้งหมด)",
    Desc = "ล้างเควสที่ค้างอยู่ในตัวทั้งหมด เผื่อรับเควสใหม่ไม่ได้",
    Callback = function()
        local active = GetActiveQuests()
        for _, q in ipairs(active) do
            AbandonActiveQuest(q.Name)
        end
        WindUI:Notify({
            Title = "Quests Abandoned",
            Content = string.format("Abandoned %d active quests.", #active),
            Duration = 3,
        })
    end,
})

-- ====================================================================
-- SECTION 2: QUEST BOARDS & QUEST PICKER (เลือกบอร์ดเควส & เลือกใบเควส)
-- ====================================================================
local IslandBoardsSection = QuestTab:Section({ Title = "2. Quest Boards & Quest Picker (เลือกบอร์ดเควส & เลือกใบเควสประจำโซน)" })

local IslandNames = {}
for _, b in ipairs(IslandQuestBoards) do
    table.insert(IslandNames, b.Name)
end

local function GetQuestsForSelectedBoard(boardDisplayName)
    for _, b in ipairs(IslandQuestBoards) do
        if b.Name == boardDisplayName then
            local list = {}
            for _, qName in ipairs(b.Quests or {}) do
                local info = QuestNameToDetailsMap[qName]
                if info then
                    local tag = info.IsBoss and "[BOSS]" or string.format("[Lv.%d+]", info.LvMin or b.LvMin or 1)
                    table.insert(list, string.format("%s - %s %s (%d XP / %d ¥)", qName, info.MobName, tag, info.Xp, info.Money))
                else
                    table.insert(list, qName)
                end
            end
            if #list > 0 then return list end
        end
    end
    return { "KillForestBrawler - Forest Brawler [Lv.1+] (150 XP / 55 ¥)" }
end

local function ExtractQuestIdFromOption(optStr)
    if not optStr then return "KillForestBrawler" end
    local id = string.match(optStr, "^([%w_]+)")
    return id or optStr
end

local BoardQuestDropdown = nil

IslandBoardsSection:Dropdown({
    Title = "Select Quest Board (เลือกบอร์ดเควสประจำโซน - ครบทุกบอร์ด)",
    Desc = "เลือกบอร์ดเควส (มีครบทั้ง 9 บอร์ดหลัก + คุณตา Hal)",
    Values = IslandNames,
    Value = Config.SelectedIslandBoard,
    Callback = function(val)
        Config.SelectedIslandBoard = val
        local qOptions = GetQuestsForSelectedBoard(val)
        if qOptions[1] then
            Config.SelectedBoardQuest = ExtractQuestIdFromOption(qOptions[1])
        end
        if BoardQuestDropdown and BoardQuestDropdown.Refresh then
            pcall(function() BoardQuestDropdown:Refresh(qOptions) end)
        elseif BoardQuestDropdown and BoardQuestDropdown.SetValues then
            pcall(function() BoardQuestDropdown:SetValues(qOptions) end)
        end
    end,
})

local initialBoardQuests = GetQuestsForSelectedBoard(Config.SelectedIslandBoard)
Config.SelectedBoardQuest = ExtractQuestIdFromOption(initialBoardQuests[1])

BoardQuestDropdown = IslandBoardsSection:Dropdown({
    Title = "Select Quest on Board (เลือกใบเควสในบอร์ดนี้)",
    Desc = "เลือกเควสที่ต้องการรับจากบอร์ดที่เลือกไว้ด้านบน",
    Values = initialBoardQuests,
    Value = initialBoardQuests[1],
    Callback = function(val)
        Config.SelectedBoardQuest = ExtractQuestIdFromOption(val)
        Config.CustomQuestName = Config.SelectedBoardQuest
    end,
})

IslandBoardsSection:Button({
    Title = "Take Selected Board Quest Now (กดไปรับเควสที่เลือกจากบอร์ดนี้ทันที)",
    Desc = "วาปไปที่บอร์ด ปลดล็อกบอร์ดกับ NPC (ถ้ายังไม่ปลด) กดรับเควสที่เลือก แล้วกลับมาจุดเดิม!",
    Callback = function()
        local qName = Config.SelectedBoardQuest or "KillForestBrawler"
        task.spawn(function()
            local ok = AcceptQuestByName(qName)
            WindUI:Notify({
                Title = ok and "Quest Accepted!" or "Quest Requested",
                Content = (ok and "Successfully accepted: " or "Requested: ") .. tostring(qName),
                Duration = 3,
            })
        end)
    end,
})

IslandBoardsSection:Button({
    Title = "Unlock All 9 Quest Boards (ปลดล็อกบอร์ดเควสครบทั้ง 9 โซนทันที)",
    Desc = "วาปไปคุยกับ NPC ประจำบอร์ดทั้ง 9 โซน (Sarah, Zeal, Roger, Nora, Jacob, Kato, Lily, Victor, Florence) เพื่อปลดล็อกทุกบอร์ด!",
    Callback = function()
        task.spawn(function()
            WindUI:Notify({
                Title = "Unlocking All Boards...",
                Content = "Visiting all 9 Storyline NPCs to unlock every Quest Board...",
                Duration = 4,
            })
            local count = UnlockAllStorylineBoards()
            WindUI:Notify({
                Title = "Quest Boards Unlocked!",
                Content = string.format("Successfully unlocked %d / 9 Quest Boards!", count),
                Duration = 4,
            })
        end)
    end,
})

IslandBoardsSection:Button({
    Title = "Teleport to Selected Quest Board (วาปไปหน้ากระดานเควสที่เลือก)",
    Desc = "วาปตัวละครไปยืนหน้าบอร์ดเควสที่เลือกไว้ด้านบน",
    Callback = function()
        for _, b in ipairs(IslandQuestBoards) do
            if b.Name == Config.SelectedIslandBoard then
                local hrp = GetHRP()
                if hrp then
                    pcall(function() LocalPlayer:RequestStreamAroundAsync(b.Position, 2) end)
                    hrp.CFrame = CFrame.lookAt(b.Position + Vector3.new(0, 1.5, 3.5), b.Position)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    WindUI:Notify({
                        Title = "Teleport to Board",
                        Content = "Teleported to " .. b.Name,
                        Duration = 3,
                    })
                end
                break
            end
        end
    end,
})

IslandBoardsSection:Button({
    Title = "Interact & Open Selected Board UI (กดเปิดดูหน้ากระดานเควส)",
    Desc = "วาปไปปลดล็อกและเปิดหน้าต่าง UI ของกระดานเควสที่เลือก",
    Callback = function()
        for _, b in ipairs(IslandQuestBoards) do
            if b.Name == Config.SelectedIslandBoard then
                task.spawn(function()
                    TakeQuestAtBoard(b, nil, true)
                end)
                WindUI:Notify({
                    Title = "Opening Board",
                    Content = "Interacting with " .. b.Name,
                    Duration = 3,
                })
                break
            end
        end
    end,
})

-- ====================================================================
-- SECTION 3: QUICK WARP TO ALL 10 QUEST BOARDS (วาปด่วนไปบอร์ดเควสทุกโซน)
-- ====================================================================
local QuickWarpBoardsSection = QuestTab:Section({ Title = "3. Quick Warp to All 10 Quest Boards (วาปด่วนไปบอร์ดเควสครบทุกโซน)" })

for _, boardEntry in ipairs(IslandQuestBoards) do
    QuickWarpBoardsSection:Button({
        Title = "Warp: " .. boardEntry.Name,
        Desc = string.format("NPC: %s | Pos: (%.0f, %.0f, %.0f) | Quests: %s", tostring(boardEntry.Npc), boardEntry.Position.X, boardEntry.Position.Y, boardEntry.Position.Z, table.concat(boardEntry.Quests or {}, ", ")),
        Callback = function()
            local hrp = GetHRP()
            if hrp then
                pcall(function() LocalPlayer:RequestStreamAroundAsync(boardEntry.Position, 2) end)
                hrp.CFrame = CFrame.lookAt(boardEntry.Position + Vector3.new(0, 1.5, 3.5), boardEntry.Position)
                hrp.AssemblyLinearVelocity = Vector3.zero
                WindUI:Notify({
                    Title = "Teleported to Board",
                    Content = boardEntry.Name,
                    Duration = 2.5,
                })
            end
        end,
    })
end

-- ====================================================================
-- SECTION 4: MILESTONES & STORYLINES (ไมล์สโตน & รางวัลเนื้อเรื่อง)
-- ====================================================================
local MilestoneSection = QuestTab:Section({ Title = "4. Milestones & Storylines (เคลมไมล์สโตน & รางวัลเนื้อเรื่อง)" })

MilestoneSection:Toggle({
    Title = "Auto Claim Milestones (เคลมไมล์สโตนอัตโนมัติ)",
    Desc = "กดรับรางวัลจากความสำเร็จ (Milestones) อัตโนมัติทันที",
    Value = Config.AutoClaimMilestones,
    Callback = function(state)
        Config.AutoClaimMilestones = state
    end,
})

MilestoneSection:Toggle({
    Title = "Auto Claim Storyline Boards (เคลมรางวัลกระดานเนื้อเรื่องอัตโนมัติ)",
    Desc = "กดรับรางวัลเมื่อทำเควสประจำบอร์ดครบทุกใบ (XP, Jenni, สูตรคราฟต์ และกล่องสุ่ม)",
    Value = Config.AutoClaimStorylineBoards,
    Callback = function(state)
        Config.AutoClaimStorylineBoards = state
    end,
})

MilestoneSection:Button({
    Title = "Claim All Milestones Now (กดเคลมไมล์สโตนทั้งหมดทันที)",
    Desc = "ตรวจสอบและกดรับรางวัลไมล์สโตนทั้งหมดที่ทำสำเร็จแล้ว",
    Callback = function()
        local count = ClaimAllMilestones()
        WindUI:Notify({
            Title = "Milestones",
            Content = string.format("Claimed %d available milestones!", count),
            Duration = 3,
        })
    end,
})

MilestoneSection:Button({
    Title = "Claim All Storyline Boards Now (กดเคลมรางวัลกระดานเนื้อเรื่องทั้งหมดทันที)",
    Desc = "วาปไปรับรางวัลกระดานเนื้อเรื่องที่ทำครบแล้วทั้งหมด",
    Callback = function()
        task.spawn(function()
            local count = ClaimStorylineBoards()
            WindUI:Notify({
                Title = "Storylines",
                Content = string.format("Claimed %d completed storyline boards!", count),
                Duration = 3,
            })
        end)
    end,
})

MilestoneSection:Input({
    Title = "Custom Quest ID (กรอกรหัสเควสเอง)",
    Desc = "เช่น KillForestBrawler, KillCaveBrawler, KillPhantomRaider",
    Value = Config.CustomQuestName,
    Placeholder = "Enter quest name...",
    Callback = function(val)
        Config.CustomQuestName = val
    end,
})

MilestoneSection:Button({
    Title = "Accept Custom Quest ID (กดรับเควสตามรหัสที่กรอก)",
    Desc = "เดินทางไปบอร์ดของเควสที่กรอกและกดรับทันที",
    Callback = function()
        if Config.CustomQuestName and Config.CustomQuestName ~= "" then
            task.spawn(function()
                local ok = AcceptQuestByName(Config.CustomQuestName)
                WindUI:Notify({
                    Title = ok and "Quest Accepted" or "Quest Request Sent",
                    Content = ok and ("Accepted: " .. Config.CustomQuestName) or ("Requested quest: " .. Config.CustomQuestName),
                    Duration = 3,
                })
            end)
        end
    end,
})

-- ========================================================
-- TAB 7: TELEPORT & MOVEMENT (WAYPOINTS & CHEATS)
-- ========================================================
local function GetCampfires()
    local campfires = {}
    local cfFolder = workspace:FindFirstChild("Campires") or workspace:FindFirstChild("Campfires")
    if cfFolder then
        for _, cf in ipairs(cfFolder:GetChildren()) do
            local id = cf:GetAttribute("CampfireId") or cf.Name
            local pos = cf:IsA("Model") and cf:GetPivot().Position or (cf:IsA("BasePart") and cf.Position or nil)
            if pos then
                table.insert(campfires, {
                    Id = tostring(id),
                    Name = cf.Name,
                    Model = cf,
                    Position = pos
                })
            end
        end
    end
    
    local VerifiedCampfires = {
        { Id = "Campfire10", Name = "Whale Island Town Campfire 1 (แคมป์ไฟในหมู่บ้าน 1)", Position = Vector3.new(-480.5, 241.4, -452.1) },
        { Id = "Campfire4",  Name = "Whale Island Town Campfire 2 / Mines (แคมป์ไฟหน้าเหมือง 2)", Position = Vector3.new(-1268.0, 327.8, -550.5) },
        { Id = "Campfire3",  Name = "Whale Island Forest Campfire 1 (แคมป์ไฟฟาร์ม/ป่า 1)", Position = Vector3.new(-2252.1, 213.5, -799.5) },
        { Id = "Campfire5",  Name = "Whale Island Forest Campfire 2 (แคมป์ไฟค่ายคริมสัน 2)", Position = Vector3.new(-1877.2, 287.5, 197.7) },
        { Id = "Campfire2",  Name = "Deep Forest Campfire 1 (แคมป์ไฟป่าลึก 1)", Position = Vector3.new(-2836.9, 224.5, -750.0) },
        { Id = "Campfire9",  Name = "Deep Forest Campfire 2 (แคมป์ไฟป่าลึก 2)", Position = Vector3.new(-3301.8, 163.5, -2021.6) },
        { Id = "Campfire6",  Name = "Beach Campfire 1 (แคมป์ไฟชายหาด 1)", Position = Vector3.new(-4775.6, 313.0, 1950.2) },
        { Id = "Campfire7",  Name = "Beach Campfire 2 (แคมป์ไฟชายหาด 2)", Position = Vector3.new(-5717.0, 368.0, 1344.2) },
        { Id = "Campfire8",  Name = "Nen Cave Campfire 2 (แคมป์ไฟถ้ำเน็น 2)", Position = Vector3.new(-4182.2, 415.5, -994.8) },
        { Id = "Campfire12", Name = "Nen Cave Campfire 1 (แคมป์ไฟถ้ำเน็น 1)", Position = Vector3.new(-4343.9, 428.0, -914.8) },
        { Id = "Campfire11", Name = "Blick Castle Campfire (แคมป์ไฟปราสาทบลิค)", Position = Vector3.new(-3703.0, 556.0, 419.8) },
        { Id = "Campfire1",  Name = "Swamp Campfire (แคมป์ไฟหนองน้ำ)", Position = Vector3.new(-4444.2, -30.0, -2976.9) },
    }
    
    local finalCampfires = {}
    local seen = {}
    for _, cf in ipairs(campfires) do
        seen[cf.Id] = true
        local friendlyName = cf.Name
        for _, db in ipairs(VerifiedCampfires) do
            if db.Id == cf.Id then
                friendlyName = db.Name
                break
            end
        end
        cf.Name = friendlyName
        table.insert(finalCampfires, cf)
    end
    for _, db in ipairs(VerifiedCampfires) do
        if not seen[db.Id] then
            table.insert(finalCampfires, {
                Id = db.Id,
                Name = db.Name,
                Model = nil,
                Position = db.Position
            })
        end
    end
    
    return finalCampfires
end

-- Safe Ground Teleport: Casts vertical ray to find the true surface and prevents spawning underground
local function SafeGroundTeleport(targetPos, extraHeight)
    local hrp = GetHRP()
    if not hrp then return false end
    extraHeight = extraHeight or 4

    -- Request Streaming around target so terrain and models stream in
    pcall(function()
        LocalPlayer:RequestStreamAroundAsync(targetPos, 2)
    end)

    local isUnderground = targetPos.Y < -100
    local rayOrigin
    local rayDir
    if isUnderground then
        rayOrigin = Vector3.new(targetPos.X, targetPos.Y + 30, targetPos.Z)
        rayDir = Vector3.new(0, -60, 0)
    else
        rayOrigin = Vector3.new(targetPos.X, targetPos.Y + 100, targetPos.Z)
        rayDir = Vector3.new(0, -220, 0)
    end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local myChar = GetCharacter()
    if myChar then
        rayParams.FilterDescendantsInstances = { myChar }
    end
    rayParams.IgnoreWater = false

    local rayResult = workspace:Raycast(rayOrigin, rayDir, rayParams)
    local finalPos
    if rayResult and rayResult.Position then
        finalPos = rayResult.Position + Vector3.new(0, extraHeight, 0)
    else
        finalPos = targetPos + Vector3.new(0, math.max(extraHeight, 5), 0)
    end

    hrp.CFrame = CFrame.new(finalPos)
    hrp.AssemblyLinearVelocity = Vector3.zero

    -- Secondary check: in case terrain streamed in fraction of second later, adjust gently
    task.spawn(function()
        task.wait(0.35)
        local curHrp = GetHRP()
        if curHrp and (curHrp.Position - finalPos).Magnitude < 30 then
            local checkOrigin = Vector3.new(curHrp.Position.X, curHrp.Position.Y + 40, curHrp.Position.Z)
            local checkResult = workspace:Raycast(checkOrigin, Vector3.new(0, -80, 0), rayParams)
            if checkResult and checkResult.Position then
                local safeY = checkResult.Position.Y + extraHeight
                if curHrp.Position.Y < safeY - 1 or curHrp.Position.Y > safeY + 15 then
                    curHrp.CFrame = CFrame.new(curHrp.Position.X, safeY, curHrp.Position.Z)
                    curHrp.AssemblyLinearVelocity = Vector3.zero
                end
            end
        end
    end)

    return true
end

local function FastTravelToCampfire(campfireIdOrName)
    local campfires = GetCampfires()
    local targetCf = nil
    for _, cf in ipairs(campfires) do
        if cf.Id == campfireIdOrName or cf.Name == campfireIdOrName then
            targetCf = cf
            break
        end
    end
    if not targetCf then return false end

    -- 1. Try official game WorldMapController:TravelTo
    local wmcSuccess, wmc = pcall(function()
        local knit = require(game.ReplicatedStorage.Packages.knit)
        return knit.GetController("WorldMapController")
    end)
    if wmcSuccess and wmc and wmc.TravelTo then
        local ok = pcall(function()
            wmc:TravelTo(targetCf.Id)
        end)
        if ok then return true end
    end

    -- 2. Try official CampfireService:FastTravel
    if CampfireService and CampfireService.FastTravel then
        local s, r1 = pcall(function()
            return CampfireService:FastTravel(targetCf.Id):await()
        end)
        if s and r1 == true then return true end
    end

    -- 3. Direct fallback teleport using SafeGroundTeleport
    if targetCf.Position then
        return SafeGroundTeleport(targetCf.Position, 4)
    end
    return false
end

local function GetAvailableNPCs()
    local npcs = {}
    local seen = {}
    
    local function addNpc(model, category)
        if model and model:IsA("Model") and not seen[model.Name] then
            local pos = model:GetPivot().Position
            if pos then
                seen[model.Name] = true
                table.insert(npcs, {
                    Name = model.Name,
                    Category = category,
                    Model = model,
                    Position = pos
                })
            end
        end
    end
    
    local world = workspace:FindFirstChild("World")
    if world then
        local bdn = world:FindFirstChild("BetterDialogNpcs")
        if bdn then
            for _, c in ipairs(bdn:GetChildren()) do addNpc(c, "Dialog") end
        end
        local cn = world:FindFirstChild("CraftingNpcs")
        if cn then
            for _, c in ipairs(cn:GetChildren()) do addNpc(c, "Crafting") end
        end
        local ban = world:FindFirstChild("BountyAppraiserNpcs")
        if ban then
            for _, c in ipairs(ban:GetChildren()) do addNpc(c, "Bounty") end
        end
    end
    
    local roaming = workspace:FindFirstChild("RoamingNpcs")
    if roaming then
        for _, c in ipairs(roaming:GetChildren()) do addNpc(c, "Roaming") end
    end
    
    table.sort(npcs, function(a, b) return a.Name < b.Name end)
    return npcs
end

local function GetPlayerList()
    local playerNames = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(playerNames, p.Name)
        end
    end
    table.sort(playerNames)
    if #playerNames == 0 then table.insert(playerNames, "None") end
    return playerNames
end

local function GetPlayerTargetCFrame(targetName)
    local target = Players:FindFirstChild(targetName)
    local char = (target and target.Character) or (workspace:FindFirstChild("Humanoids") and workspace.Humanoids:FindFirstChild(targetName)) or workspace:FindFirstChild(targetName)
    if not char then return nil end

    local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso") or char.PrimaryPart
    if hrp then
        return hrp.CFrame
    end

    local pivot = char:GetPivot()
    if pivot and pivot.Position.Magnitude > 0 then
        return pivot
    end
    return nil
end

local function TeleportToPlayer(targetName)
    local targetCf = GetPlayerTargetCFrame(targetName)
    if not targetCf then return false end

    local myHrp = GetHRP()
    if not myHrp then return false end

    pcall(function()
        LocalPlayer:RequestStreamAroundAsync(targetCf.Position, 2)
    end)

    myHrp.CFrame = targetCf * CFrame.new(0, 0, 4)
    myHrp.AssemblyLinearVelocity = Vector3.zero
    return true
end

local isSpectating = false
local spectateConnection = nil

local function StopSpectate()
    isSpectating = false
    if spectateConnection then
        spectateConnection:Disconnect()
        spectateConnection = nil
    end
    local myChar = GetCharacter()
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    local cam = workspace.CurrentCamera
    if cam and myHum then
        cam.CameraSubject = myHum
        cam.CameraType = Enum.CameraType.Custom
    end
    pcall(function()
        LocalPlayer.ReplicationFocus = myChar
    end)
end

local function ToggleSpectate(targetName)
    local cam = workspace.CurrentCamera
    if not cam then return false end
    
    if isSpectating then
        StopSpectate()
        return false
    else
        local target = Players:FindFirstChild(targetName)
        local char = (target and target.Character) or (workspace:FindFirstChild("Humanoids") and workspace.Humanoids:FindFirstChild(targetName)) or workspace:FindFirstChild(targetName)
        if not char then return false end

        local targetPos = char:GetPivot().Position

        -- Force StreamingEnabled to replicate the target player and area around them
        pcall(function()
            LocalPlayer.ReplicationFocus = char
            LocalPlayer:RequestStreamAroundAsync(targetPos, 3)
        end)

        local targetHum = char:FindFirstChildOfClass("Humanoid")
        if targetHum then
            cam.CameraSubject = targetHum
        else
            local primary = char.PrimaryPart or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("Head")
            if primary then
                cam.CameraSubject = primary
            end
        end
        cam.CameraType = Enum.CameraType.Custom
        isSpectating = true

        if spectateConnection then spectateConnection:Disconnect() end
        spectateConnection = RunService.RenderStepped:Connect(function()
            if not isSpectating then
                if spectateConnection then spectateConnection:Disconnect() end
                return
            end
            local curTarget = Players:FindFirstChild(targetName)
            local curChar = (curTarget and curTarget.Character) or (workspace:FindFirstChild("Humanoids") and workspace.Humanoids:FindFirstChild(targetName))
            if curChar then
                local hum = curChar:FindFirstChildOfClass("Humanoid")
                if hum and cam.CameraSubject ~= hum then
                    cam.CameraSubject = hum
                end
            end
        end)
        return true
    end
end

-- ==================== TAB 7: TELEPORT & MOVEMENT ====================
local TeleportTab = Window:Tab({
    Title = "Teleport & Movement",
    Icon = "map-pin",
})

-- Section 1: Movement Cheats
local MovementSection = TeleportTab:Section({ Title = "Movement & Fly Cheats (การเคลื่อนที่ & บินอิสระ)" })

MovementSection:Toggle({
    Title = "Fly (บินอิสระ)",
    Desc = "Fly freely in 3D space using WASD + Space (Up) + LeftShift/Ctrl (Down)",
    Value = Config.Fly,
    Callback = function(state)
        Config.Fly = state
        UpdateFlyPhysics(state)
    end,
})

MovementSection:Slider({
    Title = "Fly Speed (ความเร็วการบิน)",
    Desc = "Adjust flight movement velocity",
    Value = {
        Min = 10,
        Max = 250,
        Default = Config.FlySpeed,
    },
    Step = 5,
    Callback = function(val)
        Config.FlySpeed = val
    end,
})

MovementSection:Toggle({
    Title = "Noclip (เดิน/บินทะลุกำแพง)",
    Desc = "Disables player collision to walk and fly directly through walls and terrain",
    Value = Config.Noclip,
    Callback = function(state)
        Config.Noclip = state
    end,
})

MovementSection:Toggle({
    Title = "TP Walk (เดินแบบเทเลพอร์ต CFrame)",
    Desc = "Teleports forward per frame based on MoveDirection - completely bypasses speed limits & anticheat",
    Value = Config.TPWalk,
    Callback = function(state)
        Config.TPWalk = state
    end,
})

MovementSection:Slider({
    Title = "TP Walk Speed (ความเร็ว TP Walk)",
    Desc = "Speed multiplier for CFrame step walking",
    Value = {
        Min = 1,
        Max = 10,
        Default = Config.TPWalkSpeed,
    },
    Step = 0.5,
    Callback = function(val)
        Config.TPWalkSpeed = val
    end,
})

MovementSection:Toggle({
    Title = "Infinite Jump (กระโดดในอากาศไม่จำกัด)",
    Desc = "Allows jumping repeatedly in mid-air with upward impulse velocity",
    Value = Config.InfiniteJump,
    Callback = function(state)
        Config.InfiniteJump = state
    end,
})

MovementSection:Toggle({
    Title = "Infinite Stamina (สตามิน่าไม่จำกัด)",
    Desc = "Prevents stamina depletion during sprinting, climbing, and skills",
    Value = Config.InfiniteStamina,
    Callback = function(state)
        Config.InfiniteStamina = state
    end,
})

MovementSection:Toggle({
    Title = "Infinite Oxygen (ดำน้ำไม่มีวันจมน้ำตาย)",
    Desc = "Keeps oxygen at 100% so you can breathe and swim underwater infinitely",
    Value = Config.InfiniteOxygen,
    Callback = function(state)
        Config.InfiniteOxygen = state
    end,
})

MovementSection:Toggle({
    Title = "Enable Custom WalkSpeed (ปรับความเร็วเดิน)",
    Desc = "Overrides default player WalkSpeed",
    Value = Config.EnableCustomWalkSpeed,
    Callback = function(state)
        Config.EnableCustomWalkSpeed = state
        if not state and GetCharacter() then
            local hum = GetCharacter():FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16 end
        end
    end,
})

MovementSection:Slider({
    Title = "WalkSpeed (ความเร็วเดิน)",
    Desc = "Custom player movement speed (Default: 16)",
    Value = {
        Min = 16,
        Max = 150,
        Default = Config.CustomWalkSpeed,
    },
    Step = 2,
    Callback = function(val)
        Config.CustomWalkSpeed = val
    end,
})

MovementSection:Toggle({
    Title = "Enable Custom JumpPower / High Jump (เปิดกระโดดสูงพิเศษ)",
    Desc = "Overrides jump height with custom vertical velocity impulse",
    Value = Config.EnableCustomJumpPower,
    Callback = function(state)
        Config.EnableCustomJumpPower = state
        if not state and GetCharacter() then
            local hum = GetCharacter():FindFirstChildOfClass("Humanoid")
            if hum then
                if hum.UseJumpPower then hum.JumpPower = 42 else hum.JumpHeight = 7.2 end
            end
        end
    end,
})

MovementSection:Slider({
    Title = "JumpPower (แรงกระโดดสูง)",
    Desc = "Custom jump power / vertical launch force (Default: 50 - 80)",
    Value = {
        Min = 50,
        Max = 300,
        Default = Config.CustomJumpPower,
    },
    Step = 5,
    Callback = function(val)
        Config.CustomJumpPower = val
    end,
})

MovementSection:Button({
    Title = "Reset Speed & Jump to Default (รีเซ็ตความเร็วกลับปกติ)",
    Desc = "Restores WalkSpeed to 16 and JumpPower to default",
    Callback = function()
        Config.EnableCustomWalkSpeed = false
        Config.EnableCustomJumpPower = false
        Config.TPWalk = false
        local char = GetCharacter()
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = 16
            if hum.UseJumpPower then hum.JumpPower = 42 else hum.JumpHeight = 7.2 end
        end
        WindUI:Notify({
            Title = "Movement Reset",
            Content = "Speed and Jump restored to default values.",
            Duration = 3,
        })
    end,
})

MovementSection:Button({
    Title = "Instant TP Dash (พุ่งตัวเทเลพอร์ตระยะไกล)",
    Desc = "Triggers MovementService:TpDash for an instant high-speed teleport dash",
    Callback = function()
        if MovementService and MovementService.TpDash then
            pcall(function() MovementService:TpDash():await() end)
        else
            local hrp = GetHRP()
            if hrp then
                hrp.CFrame = hrp.CFrame * CFrame.new(0, 0, -35)
            end
        end
    end,
})

MovementSection:Button({
    Title = "Rushdown Dash (พุ่งโจมตีระยะไกล)",
    Desc = "Triggers MovementService:Rushdown for an attack gap-closer",
    Callback = function()
        if MovementService and MovementService.Rushdown then
            pcall(function() MovementService:Rushdown():await() end)
        end
    end,
})

-- Section 2: Campfire Fast Travel
local CampfireSection = TeleportTab:Section({ Title = "Campfire Fast Travel (วาร์ปแคมป์ไฟข้ามเกาะ)" })

local function RefreshCampfireOptions()
    local cfs = GetCampfires()
    local names = {}
    for _, c in ipairs(cfs) do
        table.insert(names, c.Name)
    end
    if #names == 0 then table.insert(names, "None") end
    return names
end

local CampfireNames = RefreshCampfireOptions()
if #CampfireNames > 0 and Config.SelectedCampfire == "None" then
    Config.SelectedCampfire = CampfireNames[1]
end

local CampfireDropdown = CampfireSection:Dropdown({
    Title = "Select Campfire (เลือกแคมป์ไฟจริง)",
    Desc = "Choose a genuine campfire to fast travel or set spawn",
    Values = CampfireNames,
    Value = Config.SelectedCampfire,
    Callback = function(val)
        Config.SelectedCampfire = val
    end,
})

CampfireSection:Button({
    Title = "Fast Travel to Campfire (วาร์ปผ่านระบบ Campfire จริง)",
    Desc = "Calls CampfireService:FastTravel to warp across islands",
    Callback = function()
        if Config.SelectedCampfire and Config.SelectedCampfire ~= "None" then
            local ok = FastTravelToCampfire(Config.SelectedCampfire)
            WindUI:Notify({
                Title = ok and "Fast Travel" or "Teleport",
                Content = ok and ("Traveled to " .. Config.SelectedCampfire) or "Failed to travel to campfire.",
                Duration = 3,
            })
        end
    end,
})

CampfireSection:Button({
    Title = "Set Spawn at Selected Campfire (ตั้งจุดเกิดที่แคมป์ไฟนี้)",
    Desc = "Calls CampfireService:SetSpawn to set your respawn point",
    Callback = function()
        if Config.SelectedCampfire and Config.SelectedCampfire ~= "None" then
            local cfs = GetCampfires()
            local targetId = nil
            for _, cf in ipairs(cfs) do
                if cf.Name == Config.SelectedCampfire or cf.Id == Config.SelectedCampfire then
                    targetId = cf.Id
                    break
                end
            end
            if targetId and CampfireService and CampfireService.SetSpawn then
                pcall(function()
                    CampfireService:SetSpawn(targetId):await()
                end)
                WindUI:Notify({
                    Title = "Spawn Point Set",
                    Content = "Spawn set to " .. Config.SelectedCampfire,
                    Duration = 3,
                })
            end
        end
    end,
})

CampfireSection:Button({
    Title = "Direct Teleport to Campfire (วาร์ปไปพิกัดแคมป์ไฟโดยตรง)",
    Desc = "Directly teleports character position safely on the ground at the campfire",
    Callback = function()
        local cfs = GetCampfires()
        for _, c in ipairs(cfs) do
            if c.Name == Config.SelectedCampfire or c.Id == Config.SelectedCampfire then
                if c.Position then
                    SafeGroundTeleport(c.Position, 4)
                    WindUI:Notify({
                        Title = "Campfire Teleport",
                        Content = "Warped safely to " .. c.Name,
                        Duration = 3,
                    })
                    break
                end
            end
        end
    end,
})

-- Section 3: World & Island Waypoints
local WaypointsSection = TeleportTab:Section({ Title = "World Destinations & Locations (สถานที่สำคัญทั่วโลก)" })

local WaypointCategories = {
    -- Towns & Key Locations
    { Name = "[เมือง] Whale Island Town (ในหมู่บ้านเกาะปลาวาฬ)", Pos = Vector3.new(-835.89, 276.0, -316.60) },
    { Name = "[ท่าเรือ] Whale Island Beach / Docks (ชายหาด/ท่าเรือเกาะปลาวาฬ)", Pos = Vector3.new(-5716.97, 368.0, 1344.22) },
    { Name = "[ป่า] Whale Island Forest (ป่าเกาะปลาวาฬ)", Pos = Vector3.new(-3403.55, 417.0, -156.95) },
    { Name = "[ทะเลสาบ] Deep Forest Lake (ทะเลสาบป่าลึก)", Pos = Vector3.new(-2836.94, 224.5, -750.00) },
    { Name = "[ค่าย] Crimson Camp (ค่ายคริมสัน)", Pos = Vector3.new(-1946.90, 287.5, 197.30) },
    { Name = "[ฟาร์ม] Korko Farm (ฟาร์มเกาะคอร์โค)", Pos = Vector3.new(-2161.23, 202.5, -891.23) },
    { Name = "[ปราสาท] Blick Castle (ปราสาทบลิค)", Pos = Vector3.new(-3702.95, 556.0, 419.77) },
    { Name = "[ถ้ำเน็น] Nen Cave Entrance (ทางเข้าถ้ำเน็น)", Pos = Vector3.new(-4182.20, 415.5, -994.80) },
    { Name = "[ภูเขาไฟ] Dracolith Volcano (ภูเขาไฟดราโคลิธ)", Pos = Vector3.new(-2225.02, 388.5, -2668.11) },
    { Name = "[หนองน้ำ] Swamp Marsh (บึงหนองน้ำใหญ่)", Pos = Vector3.new(-4444.24, -30.0, -2976.88) },
    { Name = "[เหมือง] Mine Entrance (หน้าทางเข้าเหมืองแร่)", Pos = Vector3.new(-1282.00, 344.5, -644.00) },
    { Name = "[เหมือง] Inside Mines Cavern (ในเหมืองแร่ใต้ดิน)", Pos = Vector3.new(-2009.00, -623.0, -7413.00) },
    { Name = "[ยอร์คชิน] Yorknew Mainland Docks (ท่าเรือแผ่นดินใหญ่)", Pos = Vector3.new(-500.00, 235.0, -2200.00) },

    -- Merchants & Facilities
    { Name = "[ร้านค้า] General Merchant Store (ร้านขายของชำ)", Pos = Vector3.new(-543.9, 239.6, -322.3) },
    { Name = "[ร้านค้า] Ore Merchant (คนรับซื้อแร่)", Pos = Vector3.new(-824.7, 277.6, -405.3) },
    { Name = "[คราฟต์] Blacksmith Crafting (ช่างตีเหล็กคราฟต์ของ)", Pos = Vector3.new(-471.7, 240.1, -323.6) },
    { Name = "[ห้องสมุด] Librarian (บรรณารักษ์)", Pos = Vector3.new(-631.3, 282.0, -522.6) },
    { Name = "[ค่าหัว] Bounty Appraiser (ส่งเควสล่าค่าหัว)", Pos = Vector3.new(-732.4, 423.4, -189.6) },
    { Name = "[กิลด์] Guild Hall (กิลด์ฮอลล์)", Pos = Vector3.new(-812, 303, -1420) },
    { Name = "[เน็น] Shin (Nen Shop ร้านขายของเน็น)", Pos = Vector3.new(-4182.2, 415.5, -994.7) },
    { Name = "[เน็น] Rohan (Nen Master ปลดล็อคเน็น)", Pos = Vector3.new(-4343.8, 428.0, -914.8) },
    { Name = "[ตกปลา] Fisherman Hal (คุณตา Hal แจกเบ็ดฟรี)", Pos = Vector3.new(-2836.9, 224.5, -750) },

    -- Quest Boards
    { Name = "[บอร์ดเควส] Whale Island Town Board (Lv 1-10)", Pos = Vector3.new(-835.8, 275.0, -316.5) },
    { Name = "[บอร์ดเควส] Crimson Camp Board (Lv 10-15)", Pos = Vector3.new(-1946.9, 287.5, 197.3) },
    { Name = "[บอร์ดเควส] Farm Quest Board (Lv 15-25)", Pos = Vector3.new(-2161.2, 202.5, -891.2) },
    { Name = "[บอร์ดเควส] Blick Castle Board (Lv 25-40)", Pos = Vector3.new(-3702.9, 556.0, 419.7) },
    { Name = "[บอร์ดเควส] Whale Island Beach Board (Lv 40-55)", Pos = Vector3.new(-5716.9, 368.0, 1344.2) },
    { Name = "[บอร์ดเควส] Deep Forest Board (Lv 60-65)", Pos = Vector3.new(-3301.8, 163.5, -2021.6) },
    { Name = "[บอร์ดเควส] Swamp Board (Lv 65-75)", Pos = Vector3.new(-4444.2, -30.0, -2976.8) },
    { Name = "[บอร์ดเควส] Volcanic Area Board (Lv 75-100)", Pos = Vector3.new(-2225.0, 388.5, -2668.1) },

    -- Boss Arenas
    { Name = "[บอส] Master of the Swamp (บอสหนองน้ำ)", Pos = Vector3.new(-2600, 218, -1200) },
    { Name = "[บอส] Stone Eye (บอสถ้ำหินในเหมือง)", Pos = Vector3.new(-2496, -745, -6767) },
    { Name = "[บอส] Beach King (ราชันย์ชายหาด)", Pos = Vector3.new(-4800, 225, 900) },
    { Name = "[บอส] Frost Fang (เขี้ยวหิมะ)", Pos = Vector3.new(1200, 455, -3200) },
    { Name = "[บอส] Crimson Flame (เปลวเพลิงสีเลือด)", Pos = Vector3.new(2400, 505, 1500) },
    { Name = "[บอส] Sandy Storm (พายุทราย)", Pos = Vector3.new(3100, 255, -1800) },
}

local WaypointNames = {}
for _, wp in ipairs(WaypointCategories) do table.insert(WaypointNames, wp.Name) end

local SelectedWaypoint = WaypointNames[1]

WaypointsSection:Dropdown({
    Title = "Select Destination (เลือกสถานที่ปลายทาง)",
    Desc = "Choose a key location, town, island, or boss arena",
    Values = WaypointNames,
    Value = SelectedWaypoint,
    Callback = function(val)
        SelectedWaypoint = val
    end,
})

WaypointsSection:Button({
    Title = "Teleport to Selected Destination (วาร์ปไปสถานที่ที่เลือก)",
    Desc = "Instantly teleports your character safely to the chosen waypoint surface",
    Callback = function()
        for _, wp in ipairs(WaypointCategories) do
            if wp.Name == SelectedWaypoint then
                SafeGroundTeleport(wp.Pos, 5)
                WindUI:Notify({
                    Title = "Waypoint Teleport",
                    Content = "Teleported safely to " .. wp.Name,
                    Duration = 3,
                })
                break
            end
        end
    end,
})

-- Section 4: NPC Teleport
local NpcSection = TeleportTab:Section({ Title = "NPC Teleport (วาร์ปหา NPC ทั่วโลก)" })

local function RefreshNpcDropdown()
    local npcs = GetAvailableNPCs()
    local names = {}
    for _, n in ipairs(npcs) do table.insert(names, string.format("[%s] %s", n.Category, n.Name)) end
    if #names == 0 then table.insert(names, "No NPCs found") end
    return names, npcs
end

local CurrentNpcNames, CurrentNpcList = RefreshNpcDropdown()
local SelectedNpcEntry = CurrentNpcNames[1]

NpcDropdown = NpcSection:Dropdown({
    Title = "Select NPC (เลือก NPC)",
    Desc = "Scans all active NPCs across the world",
    Values = CurrentNpcNames,
    Value = SelectedNpcEntry,
    Callback = function(val)
        SelectedNpcEntry = val
    end,
})

NpcSection:Button({
    Title = "Teleport to Selected NPC (วาร์ปไปหา NPC ที่เลือก)",
    Desc = "Teleports safely directly in front of the selected NPC",
    Callback = function()
        local _, npcs = RefreshNpcDropdown()
        for _, n in ipairs(npcs) do
            local label = string.format("[%s] %s", n.Category, n.Name)
            if label == SelectedNpcEntry or n.Name == SelectedNpcEntry then
                SafeGroundTeleport(n.Position + Vector3.new(0, 0, 3.5), 4)
                WindUI:Notify({
                    Title = "NPC Teleport",
                    Content = "Teleported safely to " .. n.Name,
                    Duration = 3,
                })
                break
            end
        end
    end,
})

NpcSection:Button({
    Title = "Refresh NPCs List (รีเฟรชรายชื่อ NPC)",
    Desc = "Rescans workspace for any newly loaded NPCs",
    Callback = function()
        local names = RefreshNpcDropdown()
        NpcDropdown:SetValues(names)
        WindUI:Notify({
            Title = "NPC List Refreshed",
            Content = string.format("Found %d NPCs in workspace.", #names),
            Duration = 3,
        })
    end,
})

-- Section 5: Player Teleport & Spectate
local PlayerSection = TeleportTab:Section({ Title = "Player Teleport & Spectate (ผู้เล่น & ดูมุมมอง)" })

local CurrentPlayers = GetPlayerList()
local SelectedPlayerName = CurrentPlayers[1]

local PlayerDropdown = PlayerSection:Dropdown({
    Title = "Select Player (เลือกผู้เล่นในเซิร์ฟ)",
    Desc = "List of all active players in this server",
    Values = CurrentPlayers,
    Value = SelectedPlayerName,
    Callback = function(val)
        SelectedPlayerName = val
    end,
})

PlayerSection:Button({
    Title = "Teleport to Selected Player (วาร์ปไปหาผู้เล่น)",
    Desc = "Teleports behind the chosen player",
    Callback = function()
        if SelectedPlayerName and SelectedPlayerName ~= "None" then
            local ok = TeleportToPlayer(SelectedPlayerName)
            WindUI:Notify({
                Title = ok and "Teleported to Player" or "Player Not Found",
                Content = ok and ("Warped behind " .. SelectedPlayerName) or "Target player character not loaded.",
                Duration = 3,
            })
        end
    end,
})

PlayerSection:Button({
    Title = "Spectate Player (ดูมุมมอง / กดซ้ำเพื่อยกเลิก)",
    Desc = "Switches your camera to spectate the chosen player",
    Callback = function()
        if SelectedPlayerName and SelectedPlayerName ~= "None" then
            local spectating = ToggleSpectate(SelectedPlayerName)
            WindUI:Notify({
                Title = spectating and "Spectating Player" or "Spectate Cancelled",
                Content = spectating and ("Now watching " .. SelectedPlayerName) or "Camera returned to your character.",
                Duration = 3,
            })
        end
    end,
})

PlayerSection:Button({
    Title = "Refresh Players List (รีเฟรชรายชื่อผู้เล่น)",
    Desc = "Updates player list with current server members",
    Callback = function()
        local players = GetPlayerList()
        PlayerDropdown:SetValues(players)
        WindUI:Notify({
            Title = "Players Refreshed",
            Content = string.format("%d other players online.", #players),
            Duration = 2,
        })
    end,
})

-- Section 6: Custom Coordinates Teleport
local CustomSection = TeleportTab:Section({ Title = "Custom Coordinates (วาร์ปพิกัด X, Y, Z)" })

CustomSection:Input({
    Title = "Coordinate X",
    Value = tostring(Config.CustomTPX),
    Placeholder = "Enter X...",
    Callback = function(val)
        Config.CustomTPX = tonumber(val) or 0
    end,
})

CustomSection:Input({
    Title = "Coordinate Y",
    Value = tostring(Config.CustomTPY),
    Placeholder = "Enter Y...",
    Callback = function(val)
        Config.CustomTPY = tonumber(val) or 0
    end,
})

CustomSection:Input({
    Title = "Coordinate Z",
    Value = tostring(Config.CustomTPZ),
    Placeholder = "Enter Z...",
    Callback = function(val)
        Config.CustomTPZ = tonumber(val) or 0
    end,
})

CustomSection:Button({
    Title = "Copy Current Position to Inputs (คัดลอกพิกัดปัจจุบัน)",
    Desc = "Reads your current character X, Y, Z coordinates",
    Callback = function()
        local hrp = GetHRP()
        if hrp then
            Config.CustomTPX = math.floor(hrp.Position.X * 10) / 10
            Config.CustomTPY = math.floor(hrp.Position.Y * 10) / 10
            Config.CustomTPZ = math.floor(hrp.Position.Z * 10) / 10
            WindUI:Notify({
                Title = "Position Copied",
                Content = string.format("X: %.1f, Y: %.1f, Z: %.1f", Config.CustomTPX, Config.CustomTPY, Config.CustomTPZ),
                Duration = 4,
            })
        end
    end,
})

CustomSection:Button({
    Title = "Teleport to Coordinates (วาร์ปไปพิกัด)",
    Desc = "Teleports to the entered X, Y, Z coordinates",
    Callback = function()
        local hrp = GetHRP()
        if hrp then
            hrp.CFrame = CFrame.new(Vector3.new(Config.CustomTPX, Config.CustomTPY, Config.CustomTPZ))
            hrp.AssemblyLinearVelocity = Vector3.zero
            WindUI:Notify({
                Title = "Custom Teleport",
                Content = string.format("Teleported to (%.1f, %.1f, %.1f)", Config.CustomTPX, Config.CustomTPY, Config.CustomTPZ),
                Duration = 3,
            })
        end
    end,
})

-- ========================================================
-- TAB 8: STATS & TALENTS (System 8)
-- ========================================================
local StatsTab = Window:Tab({
    Title = "Stats & Talents",
    Icon = "sparkles",
})

local StatInfoSection = StatsTab:Section({ Title = "Stat Overview (ข้อมูลค่าพลัง)" })

local StatOverviewParagraph = StatInfoSection:Paragraph({
    Title = "Current Stats & Points",
    Desc = "Loading stats...",
})

task.spawn(function()
    while _G.BeyondNenInstanceId == myInstanceId do
        task.wait(1)
        if StatOverviewParagraph then
            local pts = LocalPlayer:GetAttribute("StatPoints") or 0
            local str = LocalPlayer:GetAttribute("StrengthStat") or 0
            local dur = LocalPlayer:GetAttribute("DurabilityStat") or 0
            local sta = LocalPlayer:GetAttribute("StaminaStat") or 0
            local wep = LocalPlayer:GetAttribute("WeaponStat") or 0
            local nen = LocalPlayer:GetAttribute("NenStat") or 0
            local jenni = LocalPlayer:GetAttribute("Jenni") or 0

            pcall(function()
                StatOverviewParagraph:SetDesc(string.format(
                    "⭐ Available Stat Points: %d\n💰 Jenni: %s\n\n💪 Strength: %d | 🛡️ Durability: %d\n⚡ Stamina: %d | ⚔️ Weapon: %d | 🔮 Nen: %d",
                    pts,
                    tostring(jenni):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""),
                    str, dur, sta, wep, nen
                ))
            end)
        end
    end
end)

local StatAllocSection = StatsTab:Section({ Title = "Auto Allocate Stats (ระบบอัปแต้มอัตโนมัติ)" })

StatAllocSection:Toggle({
    Title = "Auto Allocate Stat Points (อัปแต้มสเตตัสอัตโนมัติ)",
    Desc = "Automatically spends earned stat points into your selected build",
    Value = Config.AutoStats,
    Callback = function(state)
        Config.AutoStats = state
    end,
})

StatAllocSection:Dropdown({
    Title = "Target Stat (สเตตัสเป้าหมาย)",
    Desc = "Select which stat to invest points into or balance them",
    Values = {
        "StrengthStat (หมัด/กล้าม)",
        "DurabilityStat (เลือด/ความทนทาน)",
        "StaminaStat (สตามิน่า/เคลื่อนไหว)",
        "WeaponStat (อาวุธ)",
        "NenStat (เน็น/พลังจิต)",
        "Balanced (แบ่งเท่าๆ กันทุกค่า)"
    },
    Value = "StrengthStat (หมัด/กล้าม)",
    Callback = function(choice)
        if choice:find("Strength") then
            Config.AutoStatTarget = "StrengthStat"
            Config.AutoStatRatio = "Single"
        elseif choice:find("Durability") then
            Config.AutoStatTarget = "DurabilityStat"
            Config.AutoStatRatio = "Single"
        elseif choice:find("Stamina") then
            Config.AutoStatTarget = "StaminaStat"
            Config.AutoStatRatio = "Single"
        elseif choice:find("Weapon") then
            Config.AutoStatTarget = "WeaponStat"
            Config.AutoStatRatio = "Single"
        elseif choice:find("Nen") then
            Config.AutoStatTarget = "NenStat"
            Config.AutoStatRatio = "Single"
        elseif choice:find("Balanced") then
            Config.AutoStatRatio = "Balanced"
        end
    end,
})

local ManualStatSection = StatsTab:Section({ Title = "Manual Quick Allocate (กดอัปสเตตัสทันที)" })

ManualStatSection:Button({
    Title = "+1 Point to Target Stat (+1 แต้ม)",
    Desc = "Adds 1 point to selected target stat",
    Callback = function()
        local target = Config.AutoStatTarget or "StrengthStat"
        local success, res = AllocateStat(target, 1)
        WindUI:Notify({
            Title = success and "Stat Upgraded" or "Upgrade Failed",
            Content = success and string.format("+1 point added to %s", target) or tostring(res),
            Duration = 2,
        })
    end,
})

ManualStatSection:Button({
    Title = "+5 Points to Target Stat (+5 แต้ม)",
    Desc = "Adds 5 points to selected target stat",
    Callback = function()
        local target = Config.AutoStatTarget or "StrengthStat"
        local success, res = AllocateStat(target, 5)
        WindUI:Notify({
            Title = success and "Stat Upgraded" or "Upgrade Failed",
            Content = success and string.format("+5 points added to %s", target) or tostring(res),
            Duration = 2,
        })
    end,
})

ManualStatSection:Button({
    Title = "+10 Points to Target Stat (+10 แต้ม)",
    Desc = "Adds 10 points to selected target stat",
    Callback = function()
        local target = Config.AutoStatTarget or "StrengthStat"
        local success, res = AllocateStat(target, 10)
        WindUI:Notify({
            Title = success and "Stat Upgraded" or "Upgrade Failed",
            Content = success and string.format("+10 points added to %s", target) or tostring(res),
            Duration = 2,
        })
    end,
})

ManualStatSection:Button({
    Title = "Max All Points to Target Stat (อัปแต้มทั้งหมดที่มี)",
    Desc = "Dumps all available stat points into target stat",
    Callback = function()
        local target = Config.AutoStatTarget or "StrengthStat"
        local pts = LocalPlayer:GetAttribute("StatPoints") or 0
        if pts <= 0 then
            WindUI:Notify({ Title = "No Points", Content = "You don't have any stat points to spend.", Duration = 2 })
            return
        end
        local success, res = AllocateStat(target, pts)
        WindUI:Notify({
            Title = success and "All Points Allocated" or "Upgrade Failed",
            Content = success and string.format("Spent %d points on %s", pts, target) or tostring(res),
            Duration = 3,
        })
    end,
})

ManualStatSection:Button({
    Title = "Distribute All Points Evenly (แบ่งแต้มเท่ากันทุกค่า)",
    Desc = "Evenly spreads all available stat points across all 5 stats",
    Callback = function()
        local pts = LocalPlayer:GetAttribute("StatPoints") or 0
        if pts <= 0 then
            WindUI:Notify({ Title = "No Points", Content = "You don't have any stat points to spend.", Duration = 2 })
            return
        end
        DistributeStatsEvenly()
        WindUI:Notify({
            Title = "Stats Distributed",
            Content = string.format("Distributed %d points across all stats.", pts),
            Duration = 3,
        })
    end,
})

-- Talents Section
local TalentSection = StatsTab:Section({ Title = "Talents & Hand Choices (ระบบสุ่มพรสวรรค์)" })

TalentSection:Toggle({
    Title = "Auto Pick Preferred Talent (เลือกการ์ดพรสวรรค์อัตโนมัติ)",
    Desc = "Automatically claims card if target talent or rarity appears in hand",
    Value = Config.AutoPickTalent,
    Callback = function(state)
        Config.AutoPickTalent = state
    end,
})

TalentSection:Toggle({
    Title = "Auto Reroll Hand (สุ่มการ์ดใหม่หากไม่ได้ตามเป้า)",
    Desc = "Rerolls choice hand using Jenni/credits until preferred talent is drawn",
    Value = Config.AutoRerollHand,
    Callback = function(state)
        Config.AutoRerollHand = state
    end,
})

TalentSection:Dropdown({
    Title = "Minimum Target Rarity (ระดับความหายากขั้นต่ำ)",
    Desc = "Target threshold for auto selection and reroll",
    Values = { "Legendary", "Extraordinary", "Rare", "Any Preferred" },
    Value = Config.TargetTalentRarity,
    Callback = function(choice)
        Config.TargetTalentRarity = choice
    end,
})

local TopTalentNames = {
    "None (Any of Target Rarity)",
    "Lifesteal",
    "SecondWind",
    "AuraReversal",
    "LuckyDiscovery",
    "RelentlessSpirit",
    "HuntersIntuition",
    "MartialMaster",
    "NenMaster",
    "ParryGod",
    "IronWill",
    "HeavenlyRestriction",
    "WarriorHate",
    "ComebackSpirit",
    "TechniqueMaster"
}

TalentSection:Dropdown({
    Title = "Specific Target Talent (เลือกพรสวรรค์เจาะจง)",
    Desc = "Select specific high-tier talent to chase",
    Values = TopTalentNames,
    Value = "None (Any of Target Rarity)",
    Callback = function(choice)
        if choice:find("None") then
            Config.TargetTalent = "None"
        else
            Config.TargetTalent = choice
        end
    end,
})

TalentSection:Slider({
    Title = "Min Jenni Safety Reserve (เงินสำรองขั้นต่ำ)",
    Desc = "Auto reroll will pause if Jenni drops below this amount",
    Value = {
        Min = 0,
        Max = 50000,
        Default = Config.MinJenniForReroll,
    },
    Step = 1000,
    Callback = function(val)
        Config.MinJenniForReroll = math.floor(val)
    end,
})

TalentSection:Button({
    Title = "Manual Reroll Hand Now (สุ่มการ์ดใหม่ทันที)",
    Desc = "Rerolls active choice hand using saved credit or 10,000 Jenni",
    Callback = function()
        if not TalentService then return end
        local s, res = pcall(function()
            return TalentService:RerollHand():await()
        end)
        WindUI:Notify({
            Title = s and "Hand Rerolled" or "Reroll Failed",
            Content = s and "Choice cards rerolled successfully!" or tostring(res),
            Duration = 3,
        })
    end,
})

-- Owned Talents Section
local OwnedTalentSection = StatsTab:Section({ Title = "Owned Talents Management (จัดการพรสวรรค์ที่มี)" })

local initialOwned = GetOwnedTalentsList()
local OwnedDropdown = OwnedTalentSection:Dropdown({
    Title = "Select Owned Talent (เลือกพรสวรรค์ที่มี)",
    Desc = "Choose which owned talent you want to reroll",
    Values = initialOwned,
    Value = initialOwned[1] or "None",
    Callback = function(choice)
        Config.SelectedOwnedTalent = choice
    end,
})

OwnedTalentSection:Button({
    Title = "Refresh Owned Talents (รีเฟรชรายการ)",
    Desc = "Updates dropdown with your character's current active talents",
    Callback = function()
        local list = GetOwnedTalentsList()
        OwnedDropdown:SetValues(list)
        WindUI:Notify({
            Title = "Talents Refreshed",
            Content = string.format("Found %d active talents.", #list == 1 and list[1] == "None" and 0 or #list),
            Duration = 2,
        })
    end,
})

OwnedTalentSection:Button({
    Title = "Reroll Selected Talent with Jenni (สุ่มเปลี่ยนพรสวรรค์ 3,333 ¥)",
    Desc = "Replaces selected owned talent with a new random talent using 3,333 Jenni",
    Callback = function()
        if not TalentService then return end
        local target = Config.SelectedOwnedTalent
        if not target or target == "None" then
            WindUI:Notify({ Title = "No Talent Selected", Content = "Please select a valid owned talent first.", Duration = 3 })
            return
        end
        local s, res = pcall(function()
            return TalentService:RerollOwnedJenni(target):await()
        end)
        WindUI:Notify({
            Title = (s and res == true) and "Talent Rerolled!" or "Reroll Failed",
            Content = (s and res == true) and string.format("Successfully rerolled %s!", target) or "Failed to reroll (check Jenni balance).",
            Duration = 4,
        })
        task.wait(0.5)
        local updated = GetOwnedTalentsList()
        OwnedDropdown:SetValues(updated)
    end,
})

-- ========================================================
-- TAB 9: CODES & REWARDS (System 9)
-- ========================================================
local CodesTab = Window:Tab({
    Title = "Codes & Rewards",
    Icon = "gift",
})

local CodesAutoSection = CodesTab:Section({ Title = "Auto Redeem All (รับโค้ดทั้งหมดในคลิกเดียว)" })

CodesAutoSection:Button({
    Title = "Redeem All Game Codes (กดรับทุกโค้ดในเกมทันที)",
    Desc = "Redeems all available codes from game data (PATCH1!, THANKYOU!, RELEASE!, UPDATECOMING)",
    Callback = function()
        RedeemAllGameCodes()
    end,
})

local CustomCodeSection = CodesTab:Section({ Title = "Custom Code Redeem (ใส่โค้ดเอง)" })

CustomCodeSection:Input({
    Title = "Enter Code String",
    Value = Config.CustomCodeInput,
    Placeholder = "e.g. PATCH1! ...",
    Callback = function(val)
        Config.CustomCodeInput = val
    end,
})

CustomCodeSection:Button({
    Title = "Redeem Code (กดรับโค้ด)",
    Desc = "Sends redemption request to game server",
    Callback = function()
        if not Config.CustomCodeInput or Config.CustomCodeInput == "" then
            WindUI:Notify({ Title = "Empty Code", Content = "Please enter a code name first.", Duration = 2 })
            return
        end
        RedeemSingleCode(Config.CustomCodeInput)
    end,
})

local ActiveCodesInfoSection = CodesTab:Section({ Title = "Active Known Codes List (รายการโค้ดที่เปิดใช้งาน)" })

local knownCodesDesc = "🎁 Active Codes:\n" ..
    "• PATCH1!  ->  30 Spins\n" ..
    "• THANKYOU!  ->  10 Spins\n" ..
    "• RELEASE!  ->  10 Spins + 1 ResetOrb\n" ..
    "• UPDATECOMING  ->  20 Spins\n\n" ..
    "Tip: Click 'Redeem All Game Codes' above to claim all rewards automatically."

ActiveCodesInfoSection:Paragraph({
    Title = "Game Codes & Rewards",
    Desc = knownCodesDesc,
})

