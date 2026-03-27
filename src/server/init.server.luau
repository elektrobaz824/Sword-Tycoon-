-- טעינת שירותים – מחפש את המודולים בכל ServerScriptService
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local container = script.Parent
local serverFolder = container:FindFirstChild("Server") or container

-- Remotes לתנור (נוצרים מיד כדי שהקליינט ימצא גם אם FurnacePromptServer טוען אחרי)
do
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	if not remotes:FindFirstChild("OpenSwordFurnace") then
		local ev = Instance.new("RemoteEvent")
		ev.Name = "OpenSwordFurnace"
		ev.Parent = remotes
	end
	if not remotes:FindFirstChild("RequestFurnaceChances") then
		local rf = Instance.new("RemoteFunction")
		rf.Name = "RequestFurnaceChances"
		rf.Parent = remotes
	end
	if not remotes:FindFirstChild("RequestForge") then
		local rf = Instance.new("RemoteFunction")
		rf.Name = "RequestForge"
		rf.Parent = remotes
	end
	if not remotes:FindFirstChild("ForgeResult") then
		local ev = Instance.new("RemoteEvent")
		ev.Name = "ForgeResult"
		ev.Parent = remotes
	end
	if not remotes:FindFirstChild("RequestMaterialShopPrices") then
		local rf = Instance.new("RemoteFunction")
		rf.Name = "RequestMaterialShopPrices"
		rf.Parent = remotes
	end
	if not remotes:FindFirstChild("RequestMaterialShopData") then
		local rf = Instance.new("RemoteFunction")
		rf.Name = "RequestMaterialShopData"
		rf.Parent = remotes
	end
	-- חנות חומרים – נוצרים מיד כדי שהקליינט ימצא גם אם MaterialShopService נטען אחרי
	if not remotes:FindFirstChild("BuyMaterial") then
		local ev = Instance.new("RemoteEvent")
		ev.Name = "BuyMaterial"
		ev.Parent = remotes
	end
	if not remotes:FindFirstChild("BuyMaterialResult") then
		local ev = Instance.new("RemoteEvent")
		ev.Name = "BuyMaterialResult"
		ev.Parent = remotes
	end

	-- Raid remotes – נוצר מיד כדי שהקליינט ימצא
	if not remotes:FindFirstChild("RaidRequestTeleport") then
		local ev = Instance.new("RemoteEvent")
		ev.Name = "RaidRequestTeleport"
		ev.Parent = remotes
	end
	if not remotes:FindFirstChild("RaidTeleportStatus") then
		local ev = Instance.new("RemoteEvent")
		ev.Name = "RaidTeleportStatus"
		ev.Parent = remotes
	end
	if not remotes:FindFirstChild("RequestStats") then
		local rf = Instance.new("RemoteFunction")
		rf.Name = "RequestStats"
		rf.Parent = remotes
	end
	if not remotes:FindFirstChild("UpgradeStat") then
		local rf = Instance.new("RemoteFunction")
		rf.Name = "UpgradeStat"
		rf.Parent = remotes
	end
	if not remotes:FindFirstChild("GiveTestStatPoints") then
		local rf = Instance.new("RemoteFunction")
		rf.Name = "GiveTestStatPoints"
		rf.Parent = remotes
	end
	if not remotes:FindFirstChild("ResetStats") then
		local rf = Instance.new("RemoteFunction")
		rf.Name = "ResetStats"
		rf.Parent = remotes
	end
	if not remotes:FindFirstChild("StatsUpdated") then
		local ev = Instance.new("RemoteEvent")
		ev.Name = "StatsUpdated"
		ev.Parent = remotes
	end
end

local function findModule(name: string): ModuleScript?
	local found = serverFolder:FindFirstChild(name)
	if found and found:IsA("ModuleScript") then
		return found
	end
	for _, desc in ServerScriptService:GetDescendants() do
		if desc:IsA("ModuleScript") and desc.Name == name then
			return desc
		end
	end
	return nil
end

-- טוענים InventoryService לפני PlayerDataService כדי להעביר getter לשמירת חומרים
local InventoryModule = findModule("InventoryService")
local InventoryServiceForSave = nil
if InventoryModule then
	InventoryServiceForSave = require(InventoryModule)
end

local PlayerDataModule = findModule("PlayerDataService")
if PlayerDataModule then
	local PlayerDataService = require(PlayerDataModule)
	local inventoryGetter = nil
	if InventoryServiceForSave and InventoryServiceForSave.GetInventoryForSave then
		inventoryGetter = function(player)
			return InventoryServiceForSave.GetInventoryForSave(player)
		end
	end
	PlayerDataService.Init(inventoryGetter)
	if type(inventoryGetter) == "function" then
		_G.SwordTycoonInventoryGetter = inventoryGetter
	end
	local requestStatsRf = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("RequestStats")
	if requestStatsRf and requestStatsRf:IsA("RemoteFunction") then
		requestStatsRf.OnServerInvoke = function(player: Player)
			print("[Server] RequestStats from " .. player.Name)
			local data = PlayerDataService.GetPlayerData(player)
			local baseHealth, healthPerPoint = 100, 20
			if _G.SwordTycoonAdminConfig then
				local v, ok = _G.SwordTycoonAdminConfig.GetValue("Stats.BaseHealth")
				if ok and type(v) == "number" and v > 0 then baseHealth = v end
				v, ok = _G.SwordTycoonAdminConfig.GetValue("Stats.HealthPerPoint")
				if ok and type(v) == "number" and v >= 0 then healthPerPoint = v end
			end
			local healthStat = (data and type(data.Health) == "number") and data.Health or 0
			local maxHealth = baseHealth + (healthStat * healthPerPoint)
			local levelForXp = (data and (type(data.Level) == "number" and data.Level)) or 1
			local xpRequiredForNext = PlayerDataService.GetXPRequiredForNextLevel(levelForXp)
			if not data then
				return {
					Level = 1,
					XP = 0,
					StatPoints = 0,
					Strength = 0,
					Health = 0,
					Speed = 0,
					MaxHealth = maxHealth,
					XPRequiredForNext = xpRequiredForNext,
				}
			end
			return {
				Level = data.Level or 1,
				XP = data.XP or 0,
				StatPoints = data.StatPoints or 0,
				Strength = data.Strength or 0,
				Health = data.Health or 0,
				Speed = data.Speed or 0,
				MaxHealth = maxHealth,
				XPRequiredForNext = xpRequiredForNext,
			}
		end
	end
	local upgradeStatRf = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("UpgradeStat")
	if upgradeStatRf and upgradeStatRf:IsA("RemoteFunction") then
		upgradeStatRf.OnServerInvoke = function(player: Player, statName: string)
			print("[Server] UpgradeStat request from " .. player.Name .. " statName=" .. tostring(statName))
			local validStat = type(statName) == "string" and (statName == "Strength" or statName == "Health" or statName == "Speed")
			if not validStat then
				print("[Server] UpgradeStat rejected – invalid stat name")
				return { success = false, reason = "invalid_stat" }
			end
			local data = PlayerDataService.GetPlayerData(player)
			if not data then
				return { success = false, reason = "no_data" }
			end
			local sp = (type(data.StatPoints) == "number" and data.StatPoints) or 0
			if sp <= 0 then
				print("[Server] UpgradeStat rejected – no stat points (StatPoints=" .. tostring(sp) .. ")")
				return { success = false, reason = "no_stat_points" }
			end
			data.StatPoints = sp - 1
			if statName == "Strength" then
				data.Strength = ((type(data.Strength) == "number" and data.Strength) or 0) + 1
			elseif statName == "Health" then
				data.Health = ((type(data.Health) == "number" and data.Health) or 0) + 1
			elseif statName == "Speed" then
				data.Speed = ((type(data.Speed) == "number" and data.Speed) or 0) + 1
			end
			local newVal = (statName == "Strength" and data.Strength) or (statName == "Health" and data.Health) or data.Speed
			print("[Server] UpgradeStat success – " .. statName .. "=" .. tostring(newVal) .. " StatPoints=" .. tostring(data.StatPoints))
			if (statName == "Health" or statName == "Speed") and _G.SwordTycoonStatsApplyService and _G.SwordTycoonStatsApplyService.ApplyToCharacter then
				_G.SwordTycoonStatsApplyService.ApplyToCharacter(player)
			end
			local baseHealth, healthPerPoint = 100, 20
			if _G.SwordTycoonAdminConfig then
				local v, ok = _G.SwordTycoonAdminConfig.GetValue("Stats.BaseHealth")
				if ok and type(v) == "number" and v > 0 then baseHealth = v end
				v, ok = _G.SwordTycoonAdminConfig.GetValue("Stats.HealthPerPoint")
				if ok and type(v) == "number" and v >= 0 then healthPerPoint = v end
			end
			local healthStat = (type(data.Health) == "number") and data.Health or 0
			local maxHealth = baseHealth + (healthStat * healthPerPoint)
			local xpRequiredForNext = PlayerDataService.GetXPRequiredForNextLevel(data.Level or 1)
			return {
				success = true,
				Level = data.Level or 1,
				XP = data.XP or 0,
				StatPoints = data.StatPoints,
				Strength = data.Strength,
				Health = data.Health or 0,
				Speed = data.Speed or 0,
				MaxHealth = maxHealth,
				XPRequiredForNext = xpRequiredForNext,
			}
		end
	end
	local giveTestStatPointsRf = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("GiveTestStatPoints")
	if giveTestStatPointsRf and giveTestStatPointsRf:IsA("RemoteFunction") then
		giveTestStatPointsRf.OnServerInvoke = function(player: Player, amount: number)
			if player.Name ~= "elektorbaz824" then
				return false
			end
			local data = PlayerDataService.GetPlayerData(player)
			if not data then
				return false
			end
			local add = type(amount) == "number" and math.floor(amount) or 0
			if add <= 0 then
				return false
			end
			data.StatPoints = ((type(data.StatPoints) == "number" and data.StatPoints) or 0) + add
			print("[Server] GiveTestStatPoints: " .. player.Name .. " +" .. tostring(add) .. " StatPoints, total=" .. tostring(data.StatPoints))
			return true
		end
	end
	print("[Server] PlayerDataService נטען.")
else
	warn("[Server] PlayerDataService לא נמצא – Coins ו-Save לא יעבדו.")
end

local BuyPadModule = findModule("BuyPadService")
if BuyPadModule then
	local BuyPadService = require(BuyPadModule)
	BuyPadService.Init()
	print("[Server] BuyPadService נטען.")
else
	warn("[Server] BuyPadService לא נמצא – Buy Pads לא יעבדו.")
end

local SellZoneModule = findModule("SellZoneService")
if SellZoneModule then
	local SellZoneService = require(SellZoneModule)
	SellZoneService.Init()
	print("[Server] SellZoneService נטען.")
else
	warn("[Server] SellZoneService לא נמצא – מכירת Copper ב-SellZone לא תעבוד.")
end

local PlotClaimModule = findModule("PlotClaimService")
if not PlotClaimModule then
	warn("[Server] PlotClaimService לא נמצא.")
	return
end
local PlotClaimService = require(PlotClaimModule)
PlotClaimService.Init()
print("[Server] PlotClaimService נטען. Server loaded!")

local AdminConfigModule = findModule("AdminConfigService")
if AdminConfigModule then
	local AdminConfigService = require(AdminConfigModule)
	AdminConfigService.Init()
	-- שירותים אחרים (PlotSetup, SellZone, BuyPad) ישתמשו באותו מופע – כך הערכים מהקונפיג באמת יחולו.
	_G.SwordTycoonAdminConfig = AdminConfigService
	print("[Server] AdminConfigService נטען.")
else
	warn("[Server] AdminConfigService לא נמצא – חלון Admin Config לא יהיה זמין.")
end

local StatsApplyModule = findModule("StatsApplyService")
if StatsApplyModule then
	local StatsApplyService = require(StatsApplyModule)
	StatsApplyService.Init()
	_G.SwordTycoonStatsApplyService = StatsApplyService
	print("[Server] StatsApplyService נטען.")
else
	warn("[Server] StatsApplyService לא נמצא – Health/Speed לא יחולו על הדמות.")
end

local InventoryBootstrapModule = findModule("InventoryBootstrap")
local InventoryModule = findModule("InventoryService")
-- טוענים את InventoryService פעם אחת כדי שיהיה cache – Bootstrap ו-MaterialShop ישתמשו באותו מופע.
local InventoryServiceSingleton = InventoryServiceForSave
if InventoryModule and not InventoryServiceSingleton then
	InventoryServiceSingleton = require(InventoryModule)
end
if InventoryBootstrapModule then
	require(InventoryBootstrapModule)
	print("[Server] InventoryBootstrap נטען.")
else
	warn("[Server] InventoryBootstrap לא נמצא – Inventory לא יעבוד.")
end

local MaterialShopModule = findModule("MaterialShopService")
if MaterialShopModule then
	local MaterialShopService = require(MaterialShopModule)
	MaterialShopService.Init(InventoryServiceSingleton)
	print("[Server] MaterialShopService נטען.")
else
	warn("[Server] MaterialShopService לא נמצא – חנות חומרים לא תעבוד.")
end

-- Sword equip / unequip – server-authoritative, uses Inventory + SwordTools templates
local SwordEquipModule = findModule("SwordEquipService")
if SwordEquipModule then
	local SwordEquipService = require(SwordEquipModule)
	SwordEquipService.Init()
	print("[Server] SwordEquipService נטען.")
else
	warn("[Server] SwordEquipService לא נמצא – Equip / Unequip לחרבות לא יעבוד.")
end

-- RaidService – בדיקת גישה לרייד וטלפורט פנימי (משתמש ב-InventoryServiceSingleton)
local RaidModule = findModule("RaidService")
if RaidModule then
	local RaidService = require(RaidModule)
	RaidService.Init(InventoryServiceSingleton)
	print("[Server] RaidService נטען.")
else
	warn("[Server] RaidService לא נמצא – Raid teleport לא יעבוד.")
end

-- הוספת מטבעות מבדיקה – מהקליינט (Command Bar). השרת מקבל את הקריאה.
if PlayerDataModule then
	local PDS = require(PlayerDataModule)
	local rf = Instance.new("RemoteFunction")
	rf.Name = "AddTestCoinsRF"
	rf.Parent = ReplicatedStorage
	rf.OnServerInvoke = function(player: Player, amount: number)
		if not amount or type(amount) ~= "number" then amount = 100 end
		if not PDS.IsDataLoaded(player) then return nil end
		local data = PDS.GetPlayerData(player)
		if not data then return nil end
		local newAmount = data.Coins + amount
		PDS.SetCoins(player, newAmount)
		PDS.RequestSavePlayerData(player)
		return newAmount
	end
	print("[Server] AddTestCoinsRF מוכן. Command Bar: game.ReplicatedStorage.AddTestCoinsRF:InvokeServer(100)")

	-- XP לבדיקה: GiveTestXP מהקליינט; GiveTestXPServer מהשרת (BindableFunction).
	local giveTestXpRf = ReplicatedStorage:FindFirstChild("GiveTestXP")
	if not giveTestXpRf or not giveTestXpRf:IsA("RemoteFunction") then
		giveTestXpRf = Instance.new("RemoteFunction")
		giveTestXpRf.Name = "GiveTestXP"
		giveTestXpRf.Parent = ReplicatedStorage
	end
	giveTestXpRf.OnServerInvoke = function(player: Player, amount: number)
		if not player or not player:IsA("Player") then
			return { ok = false, reason = "no_player", hint = "הרץ מ-Client Command Bar (לא Server) אחרי Play." }
		end
		if not amount or type(amount) ~= "number" then
			amount = 50
		end
		if not PDS.IsDataLoaded(player) then
			warn("[GiveTestXP] נתונים לא נטענו ל-" .. player.Name .. " – צריך Claim לפלוט קודם.")
			return {
				ok = false,
				reason = "data_not_loaded",
				hint = "תעשה Claim לפלוט, ואז שוב. או השתמש ב-GiveTestXPServer מהשרת (ראה COMMAND_BAR_COMMANDS).",
			}
		end
		local result = PDS.AddExperience(player, amount)
		if not result then
			return { ok = false, reason = "add_experience_failed" }
		end
		local statsEv = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("StatsUpdated")
		if statsEv and statsEv:IsA("RemoteEvent") then
			statsEv:FireClient(player)
		end
		return {
			ok = true,
			Level = result.Level,
			XP = result.XP,
			StatPoints = result.StatPoints,
			XPRequiredForNext = result.XPRequiredForNext,
		}
	end

	-- בדיקה מ-**Server** Command Bar (אין InvokeServer מהשרת): GiveTestXPServer:Invoke(player, amount)
	local giveTestXpBf = ReplicatedStorage:FindFirstChild("GiveTestXPServer")
	if not giveTestXpBf or not giveTestXpBf:IsA("BindableFunction") then
		giveTestXpBf = Instance.new("BindableFunction")
		giveTestXpBf.Name = "GiveTestXPServer"
		giveTestXpBf.Parent = ReplicatedStorage
	end
	giveTestXpBf.OnInvoke = function(player: Player?, amount: number?)
		if not player or not player:IsA("Player") then
			player = Players:GetPlayers()[1]
		end
		if not player then
			return { ok = false, reason = "no_player" }
		end
		local amt = (type(amount) == "number" and amount) or 50
		if not PDS.IsDataLoaded(player) then
			return { ok = false, reason = "data_not_loaded", player = player.Name }
		end
		local result = PDS.AddExperience(player, amt)
		if not result then
			return { ok = false, reason = "add_experience_failed" }
		end
		local statsEv = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("StatsUpdated")
		if statsEv and statsEv:IsA("RemoteEvent") then
			statsEv:FireClient(player)
		end
		return {
			ok = true,
			Level = result.Level,
			XP = result.XP,
			StatPoints = result.StatPoints,
			XPRequiredForNext = result.XPRequiredForNext,
		}
	end

	print("[Server] GiveTestXP מוכן (Client CB). GiveTestXPServer מוכן (Server CB). ראה COMMAND_BAR_COMMANDS.")

	-- שמירה חדשה – איפוס שמירה של השחקן. RemoteFunction כדי ש-InvokeServer מהקליינט/Command Bar יגיע לשרת.
	local resetRf = Instance.new("RemoteFunction")
	resetRf.Name = "ResetSave"
	resetRf.Parent = ReplicatedStorage
	resetRf.OnServerInvoke = function(player: Player)
		print("[Server] ResetSave: נקרא מהשרת")
		if not player or not player:IsA("Player") then
			player = Players:GetPlayers()[1]
		end
		if not player then
			warn("[Server] ResetSave: אין שחקן")
			return false
		end
		print("[Server] ResetSave: מאפס שמירה ל-" .. player.Name)
		local ok = PDS.ResetPlayerSave(player)
		print("[Server] ResetSave: סיום, החזיר " .. tostring(ok))
		return ok
	end
	print("[Server] ResetSave מוכן. Command Bar (מהקליינט): game.ReplicatedStorage.ResetSave:InvokeServer()")

	-- איפוס סטטים בלבד (Level, XP, StatPoints, Strength, Health, Speed). Command Bar: game.ReplicatedStorage.Remotes.ResetStats:InvokeServer()
	local resetStatsRf = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("ResetStats")
	if resetStatsRf and resetStatsRf:IsA("RemoteFunction") then
		resetStatsRf.OnServerInvoke = function(player: Player)
			if not player or not player:IsA("Player") then
				return false
			end
			if not PDS.IsDataLoaded(player) then
				print("[Server] ResetStats: אין נתונים נטענים ל-" .. player.Name)
				return false
			end
			local data = PDS.GetPlayerData(player)
			if not data then
				return false
			end
			data.Level = 1
			data.XP = 0
			data.StatPoints = 0
			data.Strength = 0
			data.Health = 0
			data.Speed = 0
			PDS.SavePlayerData(player)
			if _G.SwordTycoonStatsApplyService and _G.SwordTycoonStatsApplyService.ApplyToCharacter then
				_G.SwordTycoonStatsApplyService.ApplyToCharacter(player)
			end
			print("[Server] ResetStats: אופסו הסטטים ל-" .. player.Name)
			return true
		end
		print("[Server] ResetStats מוכן. Command Bar: game.ReplicatedStorage.Remotes.ResetStats:InvokeServer()")
	end
end

-- חיבור תנור (Sword Furnace) – ProximityPrompt שולח OpenSwordFurnace לשחקן
do
	local Workspace = game:GetService("Workspace")
	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	local openFurnaceEvent = remotesFolder and remotesFolder:FindFirstChild("OpenSwordFurnace")
	if openFurnaceEvent and openFurnaceEvent:IsA("RemoteEvent") then
		local furnace = Workspace:WaitForChild("SwordFurnace", 5)
		if furnace then
			local promptPart = furnace:FindFirstChild("PromptPart")
			local prompt = nil
			if promptPart then
				prompt = promptPart:IsA("ProximityPrompt") and promptPart or promptPart:FindFirstChildOfClass("ProximityPrompt")
			end
			if not prompt then
				prompt = furnace:FindFirstChildWhichIsA("ProximityPrompt", true)
			end
			if prompt then
				prompt.Triggered:Connect(function(player: Player)
					print("Furnace prompt triggered by", player.Name)
					openFurnaceEvent:FireClient(player)
				end)
				print("[Server] Sword Furnace מחובר – ProximityPrompt שולח OpenSwordFurnace.")
			else
				warn("[Server] Sword Furnace: לא נמצא ProximityPrompt ב-SwordFurnace.")
			end
		else
			warn("[Server] Workspace.SwordFurnace לא נמצא – תנור לא מחובר.")
		end
	end
end

-- Furnace Chances – הקליינט שולח כמויות, השרת מחזיר אחוזים (Preview בלבד)
do
	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	local requestChancesRf = remotesFolder and remotesFolder:FindFirstChild("RequestFurnaceChances")
	local FurnaceChancesModule = findModule("FurnaceChancesService")
	if requestChancesRf and requestChancesRf:IsA("RemoteFunction") and FurnaceChancesModule then
		local FurnaceChancesService = require(FurnaceChancesModule)
		requestChancesRf.OnServerInvoke = function(player: Player, copper: number, iron: number, gold: number)
			print("Furnace chances request from", player.Name, copper, iron, gold)
			local score, chances = FurnaceChancesService.ComputeChances(copper, iron, gold)
			print("Calculated score =", score)
			print("Returning chances =", chances)
			return chances
		end
		print("[Server] RequestFurnaceChances מוכן – Preview סיכויי תנור.")
	else
		if not requestChancesRf then
			warn("[Server] RequestFurnaceChances לא נמצא ב-Remotes.")
		end
		if not FurnaceChancesModule then
			warn("[Server] FurnaceChancesService לא נמצא – Preview סיכויים לא יעבוד.")
		end
	end
end

-- Forge – Validate → Remove ores → Craft Timer (מ-Config) → RNG → Add sword. מניעת double forge.
do
	local DEFAULT_FORGE_TIME = 3
	local playerIsForging: { [Player]: boolean } = {}

	local function getForgeTime(): number
		if _G.SwordTycoonAdminConfig then
			local v, ok = _G.SwordTycoonAdminConfig.GetValue("Furnace.ForgeTime")
			if ok and type(v) == "number" and v >= 0 then
				return v
			end
		end
		return DEFAULT_FORGE_TIME
	end

	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	local requestForgeRf = remotesFolder and remotesFolder:FindFirstChild("RequestForge")
	local forgeResultEvent = remotesFolder and remotesFolder:FindFirstChild("ForgeResult")
	local FurnaceChancesModule = findModule("FurnaceChancesService")
	local FurnaceForgeModule = findModule("FurnaceForgeServer")
	local InvModule = findModule("InventoryService")
	if requestForgeRf and requestForgeRf:IsA("RemoteFunction") and forgeResultEvent and forgeResultEvent:IsA("RemoteEvent") and FurnaceChancesModule and FurnaceForgeModule and InvModule then
		local FurnaceChancesService = require(FurnaceChancesModule)
		local FurnaceForgeServer = require(FurnaceForgeModule)
		local InventoryService = require(InvModule)
		requestForgeRf.OnServerInvoke = function(player: Player, copper: number, iron: number, gold: number)
			copper = math.max(0, tonumber(copper) or 0)
			iron = math.max(0, tonumber(iron) or 0)
			gold = math.max(0, tonumber(gold) or 0)

			local forgeTime = getForgeTime()
			print("Forge request from", player.Name)
			print("Requested ores:", copper, iron, gold)
			print("[Furnace Config] ForgeTime =", forgeTime)

			if copper + iron + gold == 0 then
				print("Not enough ores")
				return { started = false, reason = "not_enough_ores" }
			end

			-- 1. Validate inventory
			local hasCopper = InventoryService.GetItemAmount(player, "CopperOre") >= copper
			local hasIron = InventoryService.GetItemAmount(player, "IronOre") >= iron
			local hasGold = InventoryService.GetItemAmount(player, "GoldOre") >= gold
			if not (hasCopper and hasIron and hasGold) then
				print("Not enough ores")
				return { started = false, reason = "not_enough_ores" }
			end

			-- 2. Check player not already forging
			if playerIsForging[player] then
				print("Player already forging")
				return { started = false, reason = "already_forging" }
			end

			-- 3. Remove ores
			if copper > 0 then InventoryService.RemoveItem(player, "CopperOre", copper) end
			if iron > 0 then InventoryService.RemoveItem(player, "IronOre", iron) end
			if gold > 0 then InventoryService.RemoveItem(player, "GoldOre", gold) end
			print("Removed ores from inventory")

			-- 4. Start craft timer (משך מהקונפיג)
			playerIsForging[player] = true
			print("Forge started for", player.Name)

			task.delay(forgeTime, function()
				-- 5. After timer: RNG + add sword (משתמש בערכי Furnace מה-Config)
				print("Forge finished for", player.Name)
				local score, swordName = FurnaceForgeServer.ExecuteForge(FurnaceChancesService, copper, iron, gold)
				print("Forge result =", swordName or "none")
				if swordName then
					InventoryService.AddItem(player, swordName, 1)
					print("Sword added to inventory")
				end
				playerIsForging[player] = nil
				forgeResultEvent:FireClient(player, { success = swordName ~= nil, sword = swordName })
			end)

			return { started = true, duration = forgeTime }
		end
		print("[Server] RequestForge מוכן – Validate → Remove ores → Timer (Furnace.ForgeTime) → RNG → Add sword.")
	else
		if not requestForgeRf then warn("[Server] RequestForge לא נמצא ב-Remotes.") end
		if not forgeResultEvent then warn("[Server] ForgeResult לא נמצא ב-Remotes.") end
		if not FurnaceForgeModule then warn("[Server] FurnaceForgeServer לא נמצא.") end
		if not InvModule then warn("[Server] InventoryService לא נמצא – Forge לא יוכל להוסיף חרב.") end
	end
end
