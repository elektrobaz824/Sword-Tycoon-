-- טעינת שירותים – מחפש את המודולים בכל ServerScriptService
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local container = script.Parent
local serverFolder = container:FindFirstChild("Server") or container

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

local PlayerDataModule = findModule("PlayerDataService")
if PlayerDataModule then
	local PlayerDataService = require(PlayerDataModule)
	PlayerDataService.Init()
	print("[Server] PlayerDataService נטען.")
else
	warn("[Server] PlayerDataService לא נמצא – Coins ו-Save לא יעבדו.")
end

local PlotClaimModule = findModule("PlotClaimService")
if not PlotClaimModule then
	warn("[Server] PlotClaimService לא נמצא.")
	return
end
local PlotClaimService = require(PlotClaimModule)
PlotClaimService.Init()
print("[Server] PlotClaimService נטען. Server loaded!")

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
		PDS.SavePlayerData(player)
		return newAmount
	end
	print("[Server] AddTestCoinsRF מוכן. Command Bar: game.ReplicatedStorage.AddTestCoinsRF:InvokeServer(100)")
end
