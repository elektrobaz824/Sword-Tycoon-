--[[
	StatsApplyService - מחיל סטט Health ו-Speed על הדמות (Humanoid) לפי Admin config.
	לא נוגע ב-Strength / attack speed. נקרא: אחרי טעינת נתונים, CharacterAdded, אחרי שדרוג Health/Speed.
]]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local StatsApplyService = {}

local function getPlayerDataService()
	for _, desc in ServerScriptService:GetDescendants() do
		if desc:IsA("ModuleScript") and desc.Name == "PlayerDataService" then
			return require(desc)
		end
	end
	return nil
end

local function getAdminConfig()
	if _G.SwordTycoonAdminConfig then
		return _G.SwordTycoonAdminConfig
	end
	for _, desc in game:GetService("ServerScriptService"):GetDescendants() do
		if desc:IsA("ModuleScript") and desc.Name == "AdminConfigService" then
			local svc = require(desc)
			return svc
		end
	end
	return nil
end

function StatsApplyService.ApplyToCharacter(player: Player)
	if not player or not player:IsA("Player") then return end
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local playerData = nil
	local pds = getPlayerDataService()
	if pds and pds.GetPlayerData then
		playerData = pds.GetPlayerData(player)
	end
	local healthStat = (playerData and type(playerData.Health) == "number") and playerData.Health or 0
	local speedStat = (playerData and type(playerData.Speed) == "number") and playerData.Speed or 0

	local admin = getAdminConfig()
	local baseHealth = 100
	local healthPerPoint = 20
	local baseWalkSpeed = 16
	local walkSpeedPerPoint = 0.5
	if admin then
		local v, ok = admin.GetValue("Stats.BaseHealth")
		if ok and type(v) == "number" and v > 0 then baseHealth = v end
		v, ok = admin.GetValue("Stats.HealthPerPoint")
		if ok and type(v) == "number" and v >= 0 then healthPerPoint = v end
		v, ok = admin.GetValue("Stats.BaseWalkSpeed")
		if ok and type(v) == "number" and v >= 0 then baseWalkSpeed = v end
		v, ok = admin.GetValue("Stats.WalkSpeedPerPoint")
		if ok and type(v) == "number" and v >= 0 then walkSpeedPerPoint = v end
	end

	local maxHealth = baseHealth + (healthStat * healthPerPoint)
	local walkSpeed = baseWalkSpeed + (speedStat * walkSpeedPerPoint)

	humanoid.MaxHealth = maxHealth
	local currentH = humanoid.Health
	if currentH ~= currentH or currentH > maxHealth or currentH < 0 then
		humanoid.Health = math.clamp((currentH == currentH) and currentH or maxHealth, 0, maxHealth)
	end
	humanoid.WalkSpeed = walkSpeed

	print("[StatsApply] applied for " .. player.Name .. " | config BaseHealth=" .. tostring(baseHealth) .. " HealthPerPoint=" .. tostring(healthPerPoint) .. " BaseWalkSpeed=" .. tostring(baseWalkSpeed) .. " WalkSpeedPerPoint=" .. tostring(walkSpeedPerPoint))
	print("[StatsApply] final MaxHealth=" .. tostring(maxHealth) .. " WalkSpeed=" .. tostring(walkSpeed))
end

function StatsApplyService.Init()
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function()
			StatsApplyService.ApplyToCharacter(player)
		end)
		if player.Character then
			task.defer(function()
				StatsApplyService.ApplyToCharacter(player)
			end)
		end
	end
	Players.PlayerAdded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function()
			StatsApplyService.ApplyToCharacter(player)
		end)
	end)
	print("[StatsApplyService] Init – Health/Speed application on character spawn and stat change.")
end

return StatsApplyService
