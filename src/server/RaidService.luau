local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")

local RaidService = {}

local DEBUG = true

local function debugPrint(msg: string)
	if DEBUG then
		print("[RaidServer] " .. msg)
	end
end

-- בעתיד ניתן להרחיב ליעדים נוספים / Places אחרים.
local VALID_DESTINATIONS = {
	TestRaid = {
		Type = "PlaceTeleport",
		PlaceId = 105083717354905,
	},
}

function RaidService.Init(inventoryService: any?)
	debugPrint("Init called")

	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

	-- יצירת רמוטים אם חסרים (התנהגות זהה ל-init.server)
	local requestEvent = remotesFolder:FindFirstChild("RaidRequestTeleport")
	if not requestEvent then
		requestEvent = Instance.new("RemoteEvent")
		requestEvent.Name = "RaidRequestTeleport"
		requestEvent.Parent = remotesFolder
	end

	local statusEvent = remotesFolder:FindFirstChild("RaidTeleportStatus")
	if not statusEvent then
		statusEvent = Instance.new("RemoteEvent")
		statusEvent.Name = "RaidTeleportStatus"
		statusEvent.Parent = remotesFolder
	end

	requestEvent = requestEvent :: RemoteEvent
	statusEvent = statusEvent :: RemoteEvent

	if not inventoryService then
		warn("[RaidServer] Init called without InventoryService – raid validation disabled.")
		return
	end

	local InventoryService = inventoryService

	requestEvent.OnServerEvent:Connect(function(player: Player, destinationId: string)
		debugPrint("teleport request received from " .. player.Name .. " to destination " .. tostring(destinationId))

		-- בדיקת יעד
		local destConfig = VALID_DESTINATIONS[destinationId]
		if not destConfig then
			debugPrint("invalid destination: " .. tostring(destinationId))
			statusEvent:FireClient(player, {
				success = false,
				code = "invalid_destination",
				message = "Invalid destination",
			})
			return
		end

		-- בדיקת חרב באינבנטורי
		debugPrint("sword validation started for " .. player.Name)
		local swords = InventoryService.GetItemsByType(player, "Sword")
		local hasSword = false
		for _, entry in swords do
			if entry.Amount and entry.Amount > 0 then
				hasSword = true
				break
			end
		end
		debugPrint("sword validation result for " .. player.Name .. " = " .. (hasSword and "has_sword" or "no_sword"))

		if not hasSword then
			debugPrint("access denied for " .. player.Name .. " (no sword)")
			statusEvent:FireClient(player, {
				success = false,
				code = "no_sword",
				message = "No sword found",
			})
			return
		end

		debugPrint("validation passed for " .. player.Name .. " to destination " .. tostring(destinationId))

		-- הבאת דמות + RootPart
		local character = player.Character or player.CharacterAdded:Wait()
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not character or not rootPart or not rootPart:IsA("BasePart") then
			debugPrint("missing character/root part for " .. player.Name)
			statusEvent:FireClient(player, {
				success = false,
				code = "missing_character",
				message = "Missing character or root part",
			})
			return
		end

		local destConfig = VALID_DESTINATIONS[destinationId]
		local placeId = destConfig and destConfig.PlaceId
		if type(placeId) ~= "number" then
			debugPrint("invalid destination (missing PlaceId) for " .. player.Name)
			statusEvent:FireClient(player, {
				success = false,
				code = "invalid_destination_config",
				message = "Invalid destination configuration",
			})
			return
		end

		debugPrint("teleport start for " .. player.Name .. " to place " .. tostring(placeId))
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(placeId, { player })
		end)
		if not ok then
			debugPrint("teleport failure for " .. player.Name .. ": " .. tostring(err))
			statusEvent:FireClient(player, {
				success = false,
				code = "teleport_failed",
				message = "Teleport failed",
			})
			return
		end

		debugPrint("teleport success for " .. player.Name)

		-- נסיון Equip אוטומטי לחרב החזקה ביותר שיש לשחקן
		local swordEquipModule = script.Parent:FindFirstChild("SwordEquipService")
		if not swordEquipModule or not swordEquipModule:IsA("ModuleScript") then
			-- חיפוש גיבוי דרך ServerScriptService
			local serverScriptService = game:GetService("ServerScriptService")
			for _, desc in serverScriptService:GetDescendants() do
				if desc:IsA("ModuleScript") and desc.Name == "SwordEquipService" then
					swordEquipModule = desc
					break
				end
			end
		end

		if swordEquipModule and swordEquipModule:IsA("ModuleScript") then
			local ok, SwordEquipServiceOrErr = pcall(function()
				return require(swordEquipModule)
			end)
			if ok and type(SwordEquipServiceOrErr) == "table" and SwordEquipServiceOrErr.EquipBestSword then
				debugPrint("auto-equip best sword started for " .. player.Name)
				local success, info = SwordEquipServiceOrErr.EquipBestSword(player)
				debugPrint("auto-equip best sword result for " .. player.Name .. " = " .. tostring(success) .. " (" .. tostring(info) .. ")")
			else
				debugPrint("auto-equip best sword skipped – failed to require SwordEquipService")
			end
		else
			debugPrint("auto-equip best sword skipped – SwordEquipService module not found")
		end

		statusEvent:FireClient(player, {
			success = true,
			code = "ok",
			message = "Teleporting...",
		})
	end)

	debugPrint("RaidService initialized")
end

return RaidService

