--[[
	InventoryBootstrap - יוצר Remotes מיד, אחר כך טוען InventoryService. כך InventoryRemotes תמיד קיים בשרת.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local DEBUG = true
local function debugPrint(msg: string)
	if DEBUG then
		print("[InventoryBootstrap] " .. msg)
	end
end

-- יוצרים את התיקייה וה-Remotes מיד – גם אם InventoryService חסר, הלקוח ימצא את התיקייה
local folder = ReplicatedStorage:FindFirstChild("InventoryRemotes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "InventoryRemotes"
	folder.Parent = ReplicatedStorage
	debugPrint("נוצרה תיקיית InventoryRemotes.")
end

local rfRequest = folder:FindFirstChild("RequestInventory")
if not rfRequest or not rfRequest:IsA("RemoteFunction") then
	rfRequest = Instance.new("RemoteFunction")
	rfRequest.Name = "RequestInventory"
	rfRequest.Parent = folder
end

local reUpdated = folder:FindFirstChild("InventoryUpdated")
if not reUpdated or not reUpdated:IsA("RemoteEvent") then
	reUpdated = Instance.new("RemoteEvent")
	reUpdated.Name = "InventoryUpdated"
	reUpdated.Parent = folder
end

local function findModule(name: string): ModuleScript?
	for _, desc in ServerScriptService:GetDescendants() do
		if desc:IsA("ModuleScript") and desc.Name == name then
			return desc
		end
	end
	return nil
end

local InventoryModule = findModule("InventoryService")
if not InventoryModule then
	warn("[InventoryBootstrap] InventoryService לא נמצא – Inventory יחזיר ריק.")
	rfRequest.OnServerInvoke = function(_player: Player)
		return {}
	end
	debugPrint("Remotes מוכנים (ללא InventoryService).")
	return nil
end

local InventoryService = require(InventoryModule)

rfRequest.OnServerInvoke = function(player: Player)
	local list = InventoryService.GetInventory(player)
	debugPrint("RequestInventory מ-" .. player.Name .. " – " .. #list .. " פריטים")
	return list
end

local function sendInventoryToPlayer(player: Player)
	local list = InventoryService.GetInventory(player)
	reUpdated:FireClient(player, list)
	debugPrint("נשלח InventoryUpdated ל-" .. player.Name)
end

InventoryService.SetOnInventoryChanged(sendInventoryToPlayer)

-- רישום ב-PlayerDataService: לפני כל Save מעדכן את data.Inventory מהשירות (לא בונה payload חדש).
local pdsModule = findModule("PlayerDataService")
if pdsModule then
	local PlayerDataService = require(pdsModule)
	if PlayerDataService.SetInventoryGetter then
		PlayerDataService.SetInventoryGetter(function(player: Player)
			return InventoryService.GetInventoryForSave(player)
		end)
		debugPrint("PlayerDataService.SetInventoryGetter רשום – Inventory יישמר עם השמירה.")
	end
end

-- לולאת חיים – שולח Inventory מיד כשהשחקן נכנס (בלי דחייה)
Players.PlayerAdded:Connect(function(player: Player)
	InventoryService.CreateInventory(player)
	sendInventoryToPlayer(player)
end)

-- לא מוחקים Inventory ב-PlayerRemoving – כך השמירה (PlayerDataService) תמיד תמצא את הנתונים.

-- שחקנים שכבר בשרת
for _, player in Players:GetPlayers() do
	InventoryService.CreateInventory(player)
	sendInventoryToPlayer(player)
end

-- בדיקה: הוספת פריטים לבדיקה מהקליינט או Command Bar
local rfTestAdd = folder:FindFirstChild("AddTestInventoryItems")
if not rfTestAdd or not rfTestAdd:IsA("RemoteFunction") then
	rfTestAdd = Instance.new("RemoteFunction")
	rfTestAdd.Name = "AddTestInventoryItems"
	rfTestAdd.Parent = folder
end
rfTestAdd.OnServerInvoke = function(player: Player, itemId: string?, amount: number?)
	local id = type(itemId) == "string" and itemId or "CopperOre"
	local amt = type(amount) == "number" and amount or 5
	InventoryService.AddItem(player, id, amt)
	debugPrint("בדיקה: נוספו " .. amt .. "x " .. id .. " ל-" .. player.Name)
	return InventoryService.GetItemAmount(player, id)
end

-- דיבאג: הצגת חומרים ב-warning (מהקליינט – Command Bar)
local rfDebugPrint = folder:FindFirstChild("DebugPrintInventory")
if not rfDebugPrint or not rfDebugPrint:IsA("RemoteFunction") then
	rfDebugPrint = Instance.new("RemoteFunction")
	rfDebugPrint.Name = "DebugPrintInventory"
	rfDebugPrint.Parent = folder
end
rfDebugPrint.OnServerInvoke = function(player: Player)
	local list = InventoryService.GetInventory(player)
	local parts = {}
	for _, item in list do
		if item.Amount and item.Amount > 0 then
			table.insert(parts, (item.DisplayName or item.Id) .. " x" .. tostring(item.Amount))
		end
	end
	local msg = #parts > 0 and table.concat(parts, ", ") or "(ריק)"
	warn("[Inventory Debug] " .. player.Name .. ": " .. msg)
	return list
end

debugPrint("מוכן. RequestInventory, InventoryUpdated, AddTestInventoryItems, DebugPrintInventory.")

return nil
