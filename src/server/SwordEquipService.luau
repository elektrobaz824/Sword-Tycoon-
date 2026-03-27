--[[
	SwordEquipService
	- Server-authoritative equip / unequip for swords.
	- Maps inventory sword ids directly to Tool names under:
		ReplicatedStorage > template > SwordTools
	- Never touches inventory amounts (equip is purely visual/active state).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local SwordEquipService = {}

local DEBUG = true

local VALID_SWORDS = {
	"CopperSword",
	"IronSword",
	"GoldSword",
	"DiamondSword",
}

local VALID_SWORD_SET: { [string]: boolean } = {}
for _, name in VALID_SWORDS do
	VALID_SWORD_SET[name] = true
end

-- Tracking currently equipped sword per player (by inventory/tool id)
local equippedSwordByPlayer: { [Player]: string? } = {}

local function debugPrint(msg: string)
	if DEBUG then
		print("[SwordEquip] " .. msg)
	end
end

local function findModule(name: string): ModuleScript?
	for _, desc in ServerScriptService:GetDescendants() do
		if desc:IsA("ModuleScript") and desc.Name == name then
			return desc
		end
	end
	return nil
end

local function getPlayerDataService()
	local mod = findModule("PlayerDataService")
	if not mod then
		warn("[SwordEquip] PlayerDataService module not found.")
		return nil
	end
	local ok, svc = pcall(function()
		return require(mod)
	end)
	if not ok then
		warn("[SwordEquip] Failed to require PlayerDataService:", svc)
		return nil
	end
	return svc
end

local function getPlotClaimService()
	local mod = findModule("PlotClaimService")
	if not mod then
		warn("[SwordEquip] PlotClaimService module not found.")
		return nil
	end
	local ok, svc = pcall(function()
		return require(mod)
	end)
	if not ok then
		warn("[SwordEquip] Failed to require PlotClaimService:", svc)
		return nil
	end
	return svc
end

local function getInventoryService()
	local mod = findModule("InventoryService")
	if not mod then
		warn("[SwordEquip] InventoryService module not found.")
		return nil
	end
	local ok, svc = pcall(function()
		return require(mod)
	end)
	if not ok then
		warn("[SwordEquip] Failed to require InventoryService:", svc)
		return nil
	end
	return svc
end

local function getSwordToolsFolder(): Folder?
	local templateFolder = ReplicatedStorage:FindFirstChild("template")
	if not templateFolder or not templateFolder:IsA("Folder") then
		debugPrint("missing SwordTools folder – no 'template' folder in ReplicatedStorage.")
		return nil
	end

	local swordTools = templateFolder:FindFirstChild("SwordTools")
	if not swordTools or not swordTools:IsA("Folder") then
		debugPrint("missing SwordTools folder – no 'SwordTools' under ReplicatedStorage.template.")
		return nil
	end

	return swordTools
end

local function clearToolsFromPlayer(player: Player, swordName: string?)
	local nameToRemove = swordName

	-- Remove tools with this name from character and backpack.
	local function removeFromContainer(container: Instance?)
		if not container then
			return
		end
		for _, child in container:GetChildren() do
			if child:IsA("Tool") then
				if not nameToRemove or child.Name == nameToRemove then
					child:Destroy()
				end
			end
		end
	end

	removeFromContainer(player.Character)
	removeFromContainer(player:FindFirstChildOfClass("Backpack"))
end

local function unequipInternal(player: Player): boolean
	debugPrint("unequip requested for " .. player.Name)
	local current = equippedSwordByPlayer[player]
	if not current then
		debugPrint("unequip no-op – no sword equipped for " .. player.Name)
		return false
	end

	clearToolsFromPlayer(player, current)
	equippedSwordByPlayer[player] = nil
	local pds = getPlayerDataService()
	if pds and pds.GetPlayerData then
		local data = pds.GetPlayerData(player)
		if data then
			data.EquippedSword = nil
		end
	end
	debugPrint("unequip success – removed " .. tostring(current) .. " from " .. player.Name)
	print("[SwordEquip] unequip success – " .. player.Name .. " EquippedSword cleared")
	return true
end

local function equipInternal(player: Player, swordName: string, InventoryService): (boolean, string?)
	debugPrint("equip requested by " .. player.Name .. " for sword '" .. tostring(swordName) .. "'")

	local plotSvc = getPlotClaimService()
	if not plotSvc or not plotSvc.PlayerHasPlot or not plotSvc.PlayerHasPlot(player) then
		debugPrint("equip rejected – no claimed plot for " .. player.Name)
		print("[SwordEquip] equip rejected – no claimed plot for " .. player.Name)
		return false, "no_plot"
	end

	if type(swordName) ~= "string" or not VALID_SWORD_SET[swordName] then
		debugPrint("invalid sword name: " .. tostring(swordName))
		return false, "invalid_sword_name"
	end

	if not InventoryService then
		debugPrint("equip failed – InventoryService missing.")
		return false, "inventory_missing"
	end

	-- Check ownership – at least 1 in inventory.
	if not InventoryService.HasItem(player, swordName, 1) then
		debugPrint("sword not owned: " .. swordName .. " by " .. player.Name)
		return false, "sword_not_owned"
	end

	-- Always unequip previous sword first (if any).
	if equippedSwordByPlayer[player] then
		unequipInternal(player)
	end

	local swordTools = getSwordToolsFolder()
	if not swordTools then
		-- getSwordToolsFolder already printed a detailed debug message.
		return false, "missing_swordtools_folder"
	end

	local templateTool = swordTools:FindFirstChild(swordName)
	if not templateTool or not templateTool:IsA("Tool") then
		debugPrint("missing sword tool for '" .. swordName .. "' under SwordTools.")
		return false, "missing_sword_tool"
	end

	local ok, cloned = pcall(function()
		return templateTool:Clone()
	end)
	if not ok or not cloned then
		debugPrint("failed to clone sword tool '" .. swordName .. "': " .. tostring(cloned))
		return false, "clone_failed"
	end

	cloned.Name = templateTool.Name -- ensure exact name, even if modified elsewhere

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		debugPrint("Backpack missing for " .. player.Name .. " – cannot equip.")
		cloned:Destroy()
		return false, "no_backpack"
	end

	cloned.Parent = backpack
	equippedSwordByPlayer[player] = swordName
	local pds = getPlayerDataService()
	if pds and pds.GetPlayerData then
		local data = pds.GetPlayerData(player)
		if data then
			data.EquippedSword = swordName
		end
	end
	debugPrint("equip success – " .. player.Name .. " equipped " .. swordName)
	print("[SwordEquip] equip success – " .. player.Name .. " EquippedSword = " .. tostring(swordName))

	return true, nil
end

-- Equip the strongest sword the player owns, based on VALID_SWORDS order.
function SwordEquipService.EquipBestSword(player: Player): (boolean, string?)
	local InventoryService = getInventoryService()
	if not InventoryService then
		debugPrint("EquipBestSword failed – InventoryService missing.")
		return false, "inventory_missing"
	end

	-- iterate from strongest to weakest
	for i = #VALID_SWORDS, 1, -1 do
		local swordName = VALID_SWORDS[i]
		if InventoryService.HasItem(player, swordName, 1) then
			debugPrint("EquipBestSword: trying to equip " .. swordName .. " for " .. player.Name)
			local ok, reason = equipInternal(player, swordName, InventoryService)
			if ok then
				return true, swordName
			else
				return false, reason or "equip_failed"
			end
		end
	end

	debugPrint("EquipBestSword: no sword owned by " .. player.Name)
	return false, "no_sword_owned"
end

function SwordEquipService.GetEquippedSword(player: Player): string?
	return equippedSwordByPlayer[player]
end

function SwordEquipService.Init()
	local InventoryService = getInventoryService()

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local equipRf = remotes:FindFirstChild("RequestEquipSword")
	if not equipRf or not equipRf:IsA("RemoteFunction") then
		equipRf = Instance.new("RemoteFunction")
		equipRf.Name = "RequestEquipSword"
		equipRf.Parent = remotes
	end

	local unequipRf = remotes:FindFirstChild("RequestUnequipSword")
	if not unequipRf or not unequipRf:IsA("RemoteFunction") then
		unequipRf = Instance.new("RemoteFunction")
		unequipRf.Name = "RequestUnequipSword"
		unequipRf.Parent = remotes
	end

	-- מאפשר ללקוח לשאול מה מצויד כרגע (ללא לוגיקה חדשה)
	local equippedRf = remotes:FindFirstChild("RequestEquippedSword")
	if not equippedRf or not equippedRf:IsA("RemoteFunction") then
		equippedRf = Instance.new("RemoteFunction")
		equippedRf.Name = "RequestEquippedSword"
		equippedRf.Parent = remotes
	end

	equipRf.OnServerInvoke = function(player: Player, swordName: string)
		local success, reason = equipInternal(player, swordName, InventoryService)
		return {
			success = success,
			reason = reason,
			equippedSword = success and swordName or SwordEquipService.GetEquippedSword(player),
		}
	end

	unequipRf.OnServerInvoke = function(player: Player)
		local hadSword = equippedSwordByPlayer[player] ~= nil
		local success = unequipInternal(player)
		return {
			success = success,
			hadSword = hadSword,
			equippedSword = SwordEquipService.GetEquippedSword(player),
		}
	end

	equippedRf.OnServerInvoke = function(player: Player)
		return {
			equippedSword = SwordEquipService.GetEquippedSword(player),
		}
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		equippedSwordByPlayer[player] = nil
	end)

	debugPrint("SwordEquipService ready. Remotes: RequestEquipSword, RequestUnequipSword.")
end

return SwordEquipService

