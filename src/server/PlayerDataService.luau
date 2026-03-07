--[[
	PlayerDataService - Coins + Save
	טעינה רק אחרי Claim מוצלח. שמירה ב-PlayerRemoving + Auto Save כל 60 שניות.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlayerDataService = {}

local DATA_STORE_NAME = "SwordTycoon_PlayerData_v1"
local AUTO_SAVE_INTERVAL = 60

-- מבנה ברירת מחדל – הרחבה בעתיד: Machines, Inventory, Materials וכו'
local DEFAULT_DATA = {
	Coins = 0,
}

local store = DataStoreService:GetDataStore(DATA_STORE_NAME)
local playerDataCache: { [Player]: { Coins: number } } = {}
local playerDataLoaded: { [Player]: boolean } = {}
local coinsValueConnected: { [Instance]: boolean } = {} -- שלא נחבר Changed פעמיים לאותו IntValue

local function mergeWithDefault(data: { [string]: any }): { Coins: number }
	local out = table.clone(DEFAULT_DATA)
	for k, v in pairs(data or {}) do
		if out[k] ~= nil and type(v) == type(out[k]) then
			out[k] = v
		end
	end
	return out
end

local function createLeaderstats(player: Player, coins: number)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		ls.Parent = player
	end
	local coinsVal = ls:FindFirstChild("Coins")
	if not coinsVal then
		coinsVal = Instance.new("IntValue")
		coinsVal.Name = "Coins"
		coinsVal.Parent = ls
	end
	coinsVal.Value = math.floor(tonumber(coins) or 0)
	-- כל שינוי ב-Coins (גם עריכה ב-Explorer) מעדכן את ה-cache כדי שהשמירה תשמור את הערך הנכון
	if not coinsValueConnected[coinsVal] then
		coinsValueConnected[coinsVal] = true
		coinsVal.Changed:Connect(function()
			local data = playerDataCache[player]
			if data then
				local v = tonumber(coinsVal.Value)
				if v and v >= 0 then
					data.Coins = math.floor(v)
				end
			end
		end)
	end
	-- עדכון שוב במסגרת הבאה – עוזר לרובלוקס להציג את הערך
	task.defer(function()
		if player.Parent and player:FindFirstChild("leaderstats") then
			local c = player.leaderstats:FindFirstChild("Coins")
			if c then
				c.Value = math.floor(tonumber(coins) or 0)
			end
		end
	end)
end

-- טוען נתונים מהשרת, מיישם defaults, יוצר leaderstats. קוראים רק אחרי Claim מוצלח.
function PlayerDataService.LoadPlayerData(player: Player): { Coins: number }?
	if playerDataLoaded[player] then
		-- כבר נטען – מרענן leaderstats בכל מקרה
		createLeaderstats(player, playerDataCache[player].Coins)
		return playerDataCache[player]
	end

	local userId = player.UserId
	local success, data = pcall(function()
		return store:GetAsync(userId)
	end)

	if not success then
		warn("[PlayerDataService] טעינה נכשלה ל-" .. player.Name .. ":", data)
		data = nil
	end

	if not data or type(data) ~= "table" then
		data = {}
		if not success then
			print("[PlayerDataService] אם אתה ב-Studio: בדוק Game Settings → Security → Enable Studio Access to API Services")
		end
	end
	data = mergeWithDefault(data)

	playerDataCache[player] = data
	playerDataLoaded[player] = true
	createLeaderstats(player, data.Coins)
	print("[PlayerDataService] טעינה ל-" .. player.Name .. " | מהשמירה: Coins = " .. tostring(data.Coins))
	return data
end

-- מעתיק את ערך ה-Coins מ-leaderstats לנתונים (לפני שמירה – כך ששינוי ידני ב-Explorer יישמר)
local function syncCoinsFromLeaderstats(player: Player, data: { Coins: number })
	local ls = player:FindFirstChild("leaderstats")
	if not ls then return end
	local coinsVal = ls:FindFirstChild("Coins")
	if not coinsVal or not coinsVal:IsA("IntValue") then return end
	local v = tonumber(coinsVal.Value)
	if v and v >= 0 then
		data.Coins = math.floor(v)
	end
end

-- שומר את הנתונים ל-DataStore. קוראים ב-PlayerRemoving ובאוטו-סייב.
function PlayerDataService.SavePlayerData(player: Player): boolean
	if not playerDataLoaded[player] then
		print("[PlayerDataService] שמירה דולגת – אין נתונים נטענים ל-" .. player.Name)
		return true
	end
	local data = playerDataCache[player]
	if not data then
		print("[PlayerDataService] שמירה דולגת – אין cache ל-" .. player.Name)
		return true
	end
	-- סנכרון מהתצוגה (leaderstats) לנתונים – גיבוי לפני שמירה
	syncCoinsFromLeaderstats(player, data)

	local userId = player.UserId
	local coinsToSave = data.Coins
	local success, err = pcall(function()
		store:SetAsync(userId, data)
	end)

	if not success then
		warn("[PlayerDataService] שמירה נכשלה ל-" .. player.Name .. ":", err)
		return false
	end
	print("[PlayerDataService] נשמר ל-" .. player.Name .. " | Coins = " .. tostring(coinsToSave))
	return true
end

-- מחזיר את טבלת הנתונים של השחקן (רק אחרי טעינה). להרחבה בעתיד.
function PlayerDataService.GetPlayerData(player: Player): { Coins: number }?
	return playerDataCache[player]
end

-- מעדכן Coins ומסנכרן ל-leaderstats. לשימוש ממערכות אחרות (למשל מכונות, מכירה).
function PlayerDataService.SetCoins(player: Player, amount: number)
	local data = playerDataCache[player]
	if not data then
		return
	end
	data.Coins = amount
	-- תמיד לסנכרן ל-leaderstats (יוצר אם לא קיים)
	createLeaderstats(player, amount)
end

-- האם הנתונים של השחקן כבר נטענו (אחרי Claim).
function PlayerDataService.IsDataLoaded(player: Player): boolean
	return playerDataLoaded[player] == true
end

-- מרענן את התצוגה של leaderstats לפי הנתונים השמורים (למשל אחרי Claim).
function PlayerDataService.RefreshLeaderstats(player: Player)
	local data = playerDataCache[player]
	if data then
		createLeaderstats(player, data.Coins)
	end
end

local function startAutoSave()
	local lastSave = tick()
	RunService.Heartbeat:Connect(function()
		if tick() - lastSave < AUTO_SAVE_INTERVAL then
			return
		end
		lastSave = tick()
		for player, _ in pairs(playerDataLoaded) do
			if player and player.Parent then
				PlayerDataService.SavePlayerData(player)
			end
		end
	end)
end

function PlayerDataService.Init()
	startAutoSave()

	Players.PlayerRemoving:Connect(function(player: Player)
		print("[PlayerDataService] PlayerRemoving: " .. player.Name)
		PlayerDataService.SavePlayerData(player)
		playerDataCache[player] = nil
		playerDataLoaded[player] = nil
	end)

	-- פקודת בדיקה: מוסיפה Coins. ב-Command Bar: game.ReplicatedStorage.AddTestCoins:Invoke(nil, 100)
	local bf = Instance.new("BindableFunction")
	bf.Name = "AddTestCoins"
	bf.Parent = ReplicatedStorage
	bf.OnInvoke = function(player, amount)
		if not player or not player:IsA("Player") then
			player = Players:GetPlayers()[1]
		end
		if not amount then
			amount = 100
		end
		if type(amount) ~= "number" or not player then
			return nil
		end
		if not PlayerDataService.IsDataLoaded(player) then
			return nil
		end
		local data = PlayerDataService.GetPlayerData(player)
		if not data then
			return nil
		end
		local newAmount = data.Coins + amount
		PlayerDataService.SetCoins(player, newAmount)
		-- שמירה מיד אחרי הוספת מטבעות (גם אם ב-Studio לא רץ PlayerRemoving בזמן)
		PlayerDataService.SavePlayerData(player)
		return newAmount
	end

	-- שמירה ידנית מהפקודה (רץ בשרת גם אם מפעילים מ-Client). Command Bar: game.ReplicatedStorage.SaveNow:Invoke(nil)
	local saveBf = Instance.new("BindableFunction")
	saveBf.Name = "SaveNow"
	saveBf.Parent = ReplicatedStorage
	saveBf.OnInvoke = function(player)
		if not player or not player:IsA("Player") then
			player = Players:GetPlayers()[1]
		end
		if not player then return false end
		local ok = PlayerDataService.SavePlayerData(player)
		return ok
	end
end

return PlayerDataService
