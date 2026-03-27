--[[
	PlayerDataService - Coins + Save
	טעינה רק אחרי Claim מוצלח. שמירה ב-PlayerRemoving + Auto Save כל 60 שניות.
	שמירה מצטברת: RequestSavePlayerData מאחד קריאות (קנייה/מכירה/XP) — פחות עומס על תור DataStore.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlayerDataService = {}

local DATA_STORE_NAME = "SwordTycoon_PlayerData_v1"
local AUTO_SAVE_INTERVAL = 60
-- איחוד שמירות מהמשחק (מכירות חוזרות, חנות וכו') — SetAsync אחד אחרי שקט יחסי; מפחית "queue fills" ב-Studio
local SAVE_DEBOUNCE_SECONDS = 12
local DEBUG_SAVE = false -- true = הדפסת keys אחרי merge ובשמירה

-- מבנה ברירת מחדל – הרחבה בעתיד. אל מוחקים שדות קיימים.
-- PurchasedPads: [שם Pad] = true – לפי משתמש בלבד.
-- Inventory: [itemId] = amount – חומרים (נוסף בלבד, לא מחליף שדות אחרים).
local DEFAULT_DATA = {
	Coins = 0,
	PurchasedPads = {}, -- [padName] = true
	Inventory = { CopperOre = 0, IronOre = 0, GoldOre = 0 },
	EquippedSword = nil,
	Level = 1,
	XP = 0,
	StatPoints = 0,
	Strength = 0,
	Health = 0,
	Speed = 0,
}

local store = DataStoreService:GetDataStore(DATA_STORE_NAME)
local playerDataCache: { [Player]: { Coins: number, PurchasedPads: { [string]: boolean } } } = {}
local playerDataLoaded: { [Player]: boolean } = {}
local coinsValueConnected: { [Instance]: boolean } = {} -- שלא נחבר Changed פעמיים לאותו IntValue
local saveDebounceToken: { [Player]: number } = {}

-- merge בטוח: כל השדות מה-save נשארים. מוסיפים רק ברירת מחדל לשדות חסרים (כולל Inventory).
-- חשוב: יוצרים עותקים של PurchasedPads ו-Inventory כדי שלא נשתמש באותה טבלה משותפת (DEFAULT_DATA).
local function mergeWithDefault(data: { [string]: any })
	local out = table.clone(DEFAULT_DATA)
	out.PurchasedPads = table.clone(out.PurchasedPads or {})
	out.Inventory = table.clone(out.Inventory or {})
	for k, v in pairs(data or {}) do
		if k == "PurchasedPads" and type(v) == "table" then
			out.PurchasedPads = {}
			for plotOrPad, inner in pairs(v) do
				if type(inner) == "table" then
					for padName, _ in pairs(inner) do
						out.PurchasedPads[padName] = true
					end
				else
					out.PurchasedPads[plotOrPad] = true
				end
			end
		elseif k == "Inventory" and type(v) == "table" then
			out.Inventory = {}
			for itemId, amount in pairs(v) do
				if type(itemId) == "string" and type(amount) == "number" and amount >= 0 then
					out.Inventory[itemId] = math.floor(amount)
				end
			end
		elseif out[k] ~= nil and type(v) == type(out[k]) then
			out[k] = v
		else
			-- שדות שלא ב-DEFAULT – שומרים כמו שהם (Machines, וכל דבר אחר)
			out[k] = v
		end
	end
	-- רשת ביטחון למכונות: אם בשמירה יש PurchasedPads אבל out נשאר ריק – מעתיקים ידנית
	if data and type(data.PurchasedPads) == "table" and next(data.PurchasedPads) then
		if not next(out.PurchasedPads) then
			for plotOrPad, inner in pairs(data.PurchasedPads) do
				if type(inner) == "table" then
					for padName, _ in pairs(inner) do
						out.PurchasedPads[padName] = true
					end
				else
					out.PurchasedPads[plotOrPad] = true
				end
			end
		end
	end
	-- רשת ביטחון ל-Inventory: אם בשמירה יש Inventory אבל out נשאר ריק – מעתיקים ידנית
	if data and type(data.Inventory) == "table" and next(data.Inventory) then
		if not next(out.Inventory) then
			for itemId, amount in pairs(data.Inventory) do
				if type(itemId) == "string" and type(amount) == "number" and amount >= 0 then
					out.Inventory[itemId] = math.floor(amount)
				end
			end
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
	if DEBUG_SAVE then
		local keys = {}
		for k, _ in pairs(data) do table.insert(keys, k) end
		print("[PlayerDataService] Load merge OK | keys: " .. table.concat(keys, ", "))
	end

	playerDataCache[player] = data
	playerDataLoaded[player] = true
	createLeaderstats(player, data.Coins)
	local purchasedInfo = ""
	if data.PurchasedPads and next(data.PurchasedPads) then
		for padName, _ in pairs(data.PurchasedPads) do
			purchasedInfo = purchasedInfo .. " " .. padName
		end
	end
	print("[PlayerDataService] טעינה ל-" .. player.Name .. " | Coins = " .. tostring(data.Coins) .. (purchasedInfo ~= "" and " | Pads שנרכשו:" .. purchasedInfo or "") .. " | EquippedSword = " .. tostring(data.EquippedSword))
	print("[PlayerDataService] Stats | Level = " .. tostring(data.Level) .. " | XP = " .. tostring(data.XP) .. " | StatPoints = " .. tostring(data.StatPoints) .. " | Strength = " .. tostring(data.Strength) .. " | Health = " .. tostring(data.Health) .. " | Speed = " .. tostring(data.Speed))
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

	-- סנכרון Inventory מהשירות לפני שמירה – מעדכן רק את השדה data.Inventory, לא בונה payload חדש
	local getInv = _getInventoryForSave or (_G and _G.SwordTycoonInventoryGetter)
	if type(getInv) == "function" then
		local invSnapshot = getInv(player)
		if type(invSnapshot) == "table" then
			data.Inventory = {}
			for itemId, amount in pairs(invSnapshot) do
				if type(itemId) == "string" and type(amount) == "number" and amount >= 0 then
					data.Inventory[itemId] = math.floor(amount)
				end
			end
			local n = 0
			for _ in pairs(data.Inventory) do n = n + 1 end
			if n > 0 then
				print("[PlayerDataService] Save: שומרים " .. tostring(n) .. " סוגי חומרים ב-Inventory")
			end
		end
	else
		if _getInventoryForSave == nil and (not _G or not _G.SwordTycoonInventoryGetter) then
			print("[PlayerDataService] Save: אין getter ל-Inventory – לא נשמר")
		end
	end

	local userId = player.UserId
	local coinsToSave = data.Coins
	local success, err = pcall(function()
		store:SetAsync(userId, data)
	end)

	if not success then
		warn("[PlayerDataService] שמירה נכשלה ל-" .. player.Name .. ":", err)
		return false
	end
	if DEBUG_SAVE then
		local keys = {}
		for k, _ in pairs(data) do table.insert(keys, k) end
		print("[PlayerDataService] Save OK | keys: " .. table.concat(keys, ", "))
	end
	local purchasedCount = 0
	if data.PurchasedPads then
		for _padName, _ in pairs(data.PurchasedPads) do
			purchasedCount = purchasedCount + 1
		end
	end
	print("[PlayerDataService] נשמר ל-" .. player.Name .. " | Coins = " .. tostring(coinsToSave) .. " | Pads שנרכשו = " .. tostring(purchasedCount))
	return true
end

--[[
	מתזמן שמירה אחת ל-DataStore אחרי SAVE_DEBOUNCE_SECONDS ללא קריאות נוספות לאותו שחקן.
	מתאים למכירות/קניות תכופות — מפחית הצפת תור (במיוחד ב-Studio).
	לשמירה מיידית: SavePlayerData (יציאה, SaveNow, איפוס).
]]
function PlayerDataService.RequestSavePlayerData(player: Player)
	if not player or not player:IsA("Player") then
		return
	end
	if not playerDataLoaded[player] then
		return
	end
	local nextToken = (saveDebounceToken[player] or 0) + 1
	saveDebounceToken[player] = nextToken
	task.delay(SAVE_DEBOUNCE_SECONDS, function()
		if saveDebounceToken[player] ~= nextToken then
			return
		end
		saveDebounceToken[player] = nil
		if not player.Parent then
			return
		end
		if not playerDataLoaded[player] then
			return
		end
		PlayerDataService.SavePlayerData(player)
	end)
end

-- מחזיר את טבלת הנתונים של השחקן (רק אחרי טעינה). להרחבה בעתיד.
function PlayerDataService.GetPlayerData(player: Player)
	return playerDataCache[player]
end

-- רישום פונקציה שמחזירה Inventory לשמירה (מתבצע לפני כל Save). קוראים מ-InventoryBootstrap.
local _getInventoryForSave: ((Player) -> { [string]: number })? = nil
function PlayerDataService.SetInventoryGetter(fn: (Player) -> { [string]: number })
	_getInventoryForSave = fn
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

-- רושם שרכשו Pad – לפי משתמש בלבד (חל על כל Plot שהשחקן ייכנס אליו).
function PlayerDataService.RecordPurchasedPad(player: Player, padName: string)
	local data = playerDataCache[player]
	if not data then
		if _G.SwordTycoonDebugHousePads == true then
			print("[HouseSectionPadDebug] RecordPurchasedPad SKIP: no cache for " .. player.Name .. " pad=" .. padName)
		end
		return
	end
	if not data.PurchasedPads then
		data.PurchasedPads = {}
	end
	data.PurchasedPads[padName] = true
end

-- מחזיר את כל ה-Pads שהמשתמש רכש (לשחזור מכונות בכל Plot שנכנס אליו).
function PlayerDataService.GetPurchasedPads(player: Player): { [string]: boolean }
	local data = playerDataCache[player]
	if not data or not data.PurchasedPads then return {} end
	return data.PurchasedPads
end

-- לשמירת תאימות לאחור – מחזיר Pads שנרכשו (עכשיו לפי משתמש, לא לפי Plot).
function PlayerDataService.GetPurchasedPadsForPlot(player: Player, _plotName: string): { [string]: boolean }
	return PlayerDataService.GetPurchasedPads(player)
end

-- מאפס את השמירה של השחקן לשמירה חדשה (Coins=0, PurchasedPads={}) ושומר ל-DataStore.
function PlayerDataService.ResetPlayerSave(player: Player): boolean
	if not player or not player:IsA("Player") then
		print("[PlayerDataService] ResetPlayerSave: שחקן לא תקין")
		return false
	end
	local newData = table.clone(DEFAULT_DATA)
	playerDataCache[player] = newData
	playerDataLoaded[player] = true
	createLeaderstats(player, newData.Coins)
	local ok = PlayerDataService.SavePlayerData(player)
	print("[PlayerDataService] שמירה חדשה ל-" .. player.Name .. " | Coins=0, PurchasedPads={} | SavePlayerData=" .. tostring(ok))
	return ok
end

-- מרענן את התצוגה של leaderstats לפי הנתונים השמורים (למשל אחרי Claim).
function PlayerDataService.RefreshLeaderstats(player: Player)
	local data = playerDataCache[player]
	if data then
		createLeaderstats(player, data.Coins)
	end
end

--[[
	כמה XP צריך כדי לעבור מהרמה הנוכחית לרמה הבאה.
	רמה 1 → יעד = XPBaseForNextLevel (ברירת מחדל 100)
	רמה 2 → יעד = 100 + XPIncreasePerLevel (150), וכן הלאה.
]]
function PlayerDataService.GetXPRequiredForNextLevel(level: number): number
	local lv = math.max(1, math.floor(type(level) == "number" and level or 1))
	local base = 100
	local step = 50
	if _G.SwordTycoonAdminConfig then
		local v, ok = _G.SwordTycoonAdminConfig.GetValue("Stats.XPBaseForNextLevel")
		if ok and type(v) == "number" and v > 0 then
			base = math.floor(v)
		end
		v, ok = _G.SwordTycoonAdminConfig.GetValue("Stats.XPIncreasePerLevel")
		if ok and type(v) == "number" and v >= 0 then
			step = math.floor(v)
		end
	end
	return base + (lv - 1) * step
end

--[[
	מוסיף XP, מעלה רמה כשמגיעים ליעד של הרמה הנוכחית, ומעניק StatPoint אחד לכל רמה.
]]
function PlayerDataService.AddExperience(player: Player, amount: number): { Level: number, XP: number, StatPoints: number, XPRequiredForNext: number }?
	if not player or not player:IsA("Player") then
		return nil
	end
	if not amount or type(amount) ~= "number" or amount <= 0 then
		return nil
	end
	if not playerDataLoaded[player] then
		return nil
	end
	local data = playerDataCache[player]
	if not data then
		return nil
	end
	local add = math.floor(amount)
	data.XP = math.max(0, math.floor((type(data.XP) == "number" and data.XP or 0) + add))
	data.Level = math.max(1, math.floor(type(data.Level) == "number" and data.Level or 1))
	data.StatPoints = math.max(0, math.floor(type(data.StatPoints) == "number" and data.StatPoints or 0))

	while true do
		local need = PlayerDataService.GetXPRequiredForNextLevel(data.Level)
		if need <= 0 or data.XP < need then
			break
		end
		data.XP -= need
		data.Level += 1
		data.StatPoints += 1
	end

	PlayerDataService.RequestSavePlayerData(player)
	return {
		Level = data.Level,
		XP = data.XP,
		StatPoints = data.StatPoints,
		XPRequiredForNext = PlayerDataService.GetXPRequiredForNextLevel(data.Level),
	}
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

function PlayerDataService.Init(inventoryGetter: ((Player) -> { [string]: number })?)
	if type(inventoryGetter) == "function" then
		_getInventoryForSave = inventoryGetter
		print("[PlayerDataService] Inventory getter רשום – חומרים יישמרו.")
	end
	startAutoSave()

	Players.PlayerRemoving:Connect(function(player: Player)
		print("[PlayerDataService] PlayerRemoving: " .. player.Name)
		saveDebounceToken[player] = nil
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
		PlayerDataService.RequestSavePlayerData(player)
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
