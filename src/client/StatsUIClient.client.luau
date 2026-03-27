--[[
	StatsUIClient - מחבר את ה-Stats UI (StatsHUD) לנתוני סטט מהשרת.
	קורא RequestStats ומעדכן LevelLabel, XPLabel, StatPointsLabel, StrengthRow, HealthRow, SpeedRow.
	Read-only; כפתורי + לא מחוברים כאן.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Use the same StatsHUD that is shown (StarterGui clone in PlayerGui). Wait for it so we don't update a different instance.
local gui = playerGui:WaitForChild("StatsHUD", 10)
if not gui then
	local template = StarterGui:FindFirstChild("StatsHUD")
	if template and template:IsA("ScreenGui") then
		gui = template:Clone()
		gui.ResetOnSpawn = false
		gui.Parent = playerGui
	end
end

if not gui or not gui:IsA("ScreenGui") then
	return
end

local mainHud = gui:FindFirstChild("MainHud")
local statsPanel = gui:WaitForChild("StatsPanel", 5)
if not statsPanel then
	return
end

-- Confirm we're on the correct UI path: StarterGui.StatsHUD.StatsPanel (in PlayerGui when playing)
print("[StatsUI] Connected to PlayerGui.StatsHUD.StatsPanel")

-- HP bar (MainHud.HPBarContainer) – מקסימום מהשרת (Base + HP stat), חיים נוכחיים מ-Humanoid
local hpBarContainer = mainHud and mainHud:FindFirstChild("HPBarContainer")
local hpLabel = hpBarContainer and (hpBarContainer:FindFirstChild("HPLabel") or hpBarContainer:FindFirstChildOfClass("TextLabel"))
local hpFill = hpBarContainer and hpBarContainer:FindFirstChild("HPFill") :: Frame?
local cachedMaxHealth: number? = nil
local function updateHPBar(health: number, maxHealth: number)
	local percent = 0
	if type(health) == "number" and type(maxHealth) == "number" and maxHealth > 0 then
		percent = math.clamp(health / maxHealth, 0, 1)
	end

	if hpFill and hpFill:IsA("Frame") then
		-- Assumes HPFill is positioned at the left edge and sized to the full height.
		-- We only shrink/grow the width by changing Scale.X.
		hpFill.Size = UDim2.fromScale(percent, 1)
	end

	if hpLabel and hpLabel:IsA("TextLabel") then
		hpLabel.Text = math.floor(health) .. "/" .. math.floor(maxHealth)
	end
end
local function getDisplayMaxHealth(humanoid: Humanoid): number
	if cachedMaxHealth and cachedMaxHealth > 0 then
		return cachedMaxHealth
	end
	return humanoid.MaxHealth
end
local function connectCharacterHealth(character: Model)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	updateHPBar(humanoid.Health, getDisplayMaxHealth(humanoid))
	humanoid.HealthChanged:Connect(function(h)
		updateHPBar(h, getDisplayMaxHealth(humanoid))
	end)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		updateHPBar(humanoid.Health, getDisplayMaxHealth(humanoid))
	end)
end
local doRefreshStatsForHP = nil
player.CharacterAdded:Connect(function(char)
	connectCharacterHealth(char)
	task.defer(function()
		if doRefreshStatsForHP then doRefreshStatsForHP() end
	end)
end)
if player.Character then
	connectCharacterHealth(player.Character)
end

local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
local requestStatsRf = remotes and remotes:FindFirstChild("RequestStats")
local upgradeStatRf = remotes and remotes:FindFirstChild("UpgradeStat")
local statsUpdatedEv = remotes and remotes:FindFirstChild("StatsUpdated")
if not requestStatsRf or not requestStatsRf:IsA("RemoteFunction") then
	return
end

-- יעד XP לרמה הבאה; מתעדכן מ-RequestStats (שדה XPRequiredForNext)
local cachedXPRequiredForNext = 100

-- EXP bar (MainHud.EXPBarContainer) – מילוי לפי XP / יעד לרמה הנוכחית
local expBarContainer = mainHud and mainHud:FindFirstChild("EXPBarContainer")
local expLabel = expBarContainer and (expBarContainer:FindFirstChild("EXPLabel") or expBarContainer:FindFirstChildOfClass("TextLabel"))
local expFill = expBarContainer and expBarContainer:FindFirstChild("EXPFill") :: Frame?

local function updateExpBar(xp: number, xpMax: number)
	local maxXp = (type(xpMax) == "number" and xpMax > 0) and xpMax or cachedXPRequiredForNext
	local percent = 0
	if maxXp > 0 then
		percent = math.clamp((type(xp) == "number" and xp or 0) / maxXp, 0, 1)
	end
	if expFill and expFill:IsA("Frame") then
		expFill.Size = UDim2.fromScale(percent, 1)
	end
	if expLabel and expLabel:IsA("TextLabel") then
		expLabel.Text = math.floor(type(xp) == "number" and xp or 0) .. "/" .. math.floor(maxXp)
	end
end

local function setLabel(frame: Instance?, value: string)
	if not frame then return end
	local vl = frame:FindFirstChild("ValueLabel")
	if vl and vl:IsA("TextLabel") then
		vl.Text = value
	end
end

local function applyStatsToUI(data)
	if type(data) ~= "table" then return end
	if type(data.XPRequiredForNext) == "number" and data.XPRequiredForNext > 0 then
		cachedXPRequiredForNext = math.floor(data.XPRequiredForNext)
	elseif type(data.XPPerLevel) == "number" and data.XPPerLevel > 0 then
		-- תאימות לאחור (גרסה ישנה)
		cachedXPRequiredForNext = math.floor(data.XPPerLevel)
	end
	setLabel(statsPanel:FindFirstChild("LevelLabel"), tostring(data.Level or 1))
	setLabel(statsPanel:FindFirstChild("XPLabel"), tostring(data.XP or 0) .. " / " .. tostring(cachedXPRequiredForNext))
	setLabel(statsPanel:FindFirstChild("StatPointsLabel"), tostring(data.StatPoints or 0))
	setLabel(statsPanel:FindFirstChild("StrengthRow"), tostring(data.Strength or 0))
	setLabel(statsPanel:FindFirstChild("HealthRow"), tostring(data.Health or 0))
	setLabel(statsPanel:FindFirstChild("SpeedRow"), tostring(data.Speed or 0))
	if type(data.MaxHealth) == "number" and data.MaxHealth > 0 then
		cachedMaxHealth = data.MaxHealth
		if hpLabel and player.Character then
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				updateHPBar(humanoid.Health, data.MaxHealth)
			end
		end
	end

	updateExpBar((type(data.XP) == "number" and data.XP) or 0, cachedXPRequiredForNext)
end

local function refreshStats()
	local ok, data = pcall(function()
		return requestStatsRf:InvokeServer()
	end)
	if ok and type(data) == "table" then
		applyStatsToUI(data)
	end
end

refreshStats()
doRefreshStatsForHP = refreshStats

if statsUpdatedEv and statsUpdatedEv:IsA("RemoteEvent") then
	statsUpdatedEv.OnClientEvent:Connect(function()
		refreshStats()
	end)
end

local statsButton = mainHud and mainHud:FindFirstChild("StatsButton")
if statsButton and statsButton:IsA("TextButton") then
	statsButton.MouseButton1Click:Connect(function()
		task.wait(0.05)
		if statsPanel.Visible then
			refreshStats()
		end
	end)
end

if upgradeStatRf and upgradeStatRf:IsA("RemoteFunction") then
	local function connectPlusButton(rowName: string, statName: string)
		local row = statsPanel:FindFirstChild(rowName)
		local plusBtn = row and row:FindFirstChild("PlusButton")
		if plusBtn and plusBtn:IsA("TextButton") then
			plusBtn.MouseButton1Click:Connect(function()
				local ok, result = pcall(function()
					return upgradeStatRf:InvokeServer(statName)
				end)
				if ok and type(result) == "table" and result.success then
					applyStatsToUI(result)
				end
			end)
		end
	end
	connectPlusButton("StrengthRow", "Strength")
	connectPlusButton("HealthRow", "Health")
	connectPlusButton("SpeedRow", "Speed")
end
