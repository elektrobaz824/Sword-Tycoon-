--[[
	MaterialShopService - חנות חומרים דרך NPC.
	מחובר ל-PlayerDataService (Coins) ו-InventoryService. קנייה: יחידה אחת בלבד.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MaterialShopService = {}

local NPC_NAME = "MaterialShopNPC"
local PROMPT_NAME = "ProximityPrompt"

-- מחירים V1 – קל להרחיב
local MATERIAL_PRICES: { [string]: number } = {
	CopperOre = 10,
	IronOre = 25,
	GoldOre = 50,
}

local DEBUG = true
local function debugPrint(msg: string)
	if DEBUG then
		print("[MaterialShop] " .. msg)
	end
end

local function getAdminConfig()
	if _G.SwordTycoonAdminConfig then
		return _G.SwordTycoonAdminConfig
	end
	return nil
end

-- מחירי מכירת חרבות (ברירת מחדל) – יחידה אחת מכל סוג
local SWORD_SELL_DEFAULTS: { [string]: number } = {
	CopperSword = 5,
	IronSword = 15,
	GoldSword = 40,
	DiamondSword = 100,
}

-- רשימת כל סוגי החרבות שהחנות יודעת למכור
local SWORD_IDS = { "CopperSword", "IronSword", "GoldSword", "DiamondSword" }

local function getPlayerDataService()
	for _, desc in ServerScriptService:GetDescendants() do
		if desc:IsA("ModuleScript") and desc.Name == "PlayerDataService" then
			return require(desc)
		end
	end
	return nil
end

local function getInventoryService()
	for _, desc in ServerScriptService:GetDescendants() do
		if desc:IsA("ModuleScript") and desc.Name == "InventoryService" then
			return require(desc)
		end
	end
	return nil
end

-- מחזיר כמה מכל חרב יש לשחקן
local function getSwordCounts(player: Player, invService: any): { [string]: number }
	local counts: { [string]: number } = {}
	if not invService then return counts end
	for _, id in SWORD_IDS do
		counts[id] = invService.GetItemAmount(player, id)
	end
	return counts
end

-- מוחזר מ-Init – אם הועבר מהשרת הראשי, משתמשים בו (אותו מופע כמו Bootstrap).
local injectedInventoryService: any = nil

function MaterialShopService.GetPrice(itemId: string): number?
	local admin = getAdminConfig()
	local base = MATERIAL_PRICES[itemId]
	if not admin then
		return base
	end
	local path = "MaterialShop." .. itemId .. "Price"
	local v, ok = admin.GetValue(path)
	if ok and type(v) == "number" and v >= 0 then
		return v
	end
	return base
end

function MaterialShopService.GetPrices(): { [string]: number }
	local prices = {}
	for id, _ in MATERIAL_PRICES do
		prices[id] = MaterialShopService.GetPrice(id)
	end
	return prices
end

-- מחזיר מחיר מכירה לחרב אחת (לפי AdminConfig או ברירת מחדל)
function MaterialShopService.GetSwordSellPrice(swordId: string): number?
	local base = SWORD_SELL_DEFAULTS[swordId]
	if not base then
		return nil
	end
	local admin = getAdminConfig()
	if not admin then
		return base
	end
	local path = "MaterialShop." .. swordId .. "SellPrice"
	local v, ok = admin.GetValue(path)
	if ok and type(v) == "number" and v >= 0 then
		return v
	end
	return base
end

function MaterialShopService.GetSwordSellPrices(): { [string]: number }
	local prices = {}
	for id, _ in SWORD_SELL_DEFAULTS do
		prices[id] = MaterialShopService.GetSwordSellPrice(id) or 0
	end
	return prices
end

function MaterialShopService.TryPurchase(player: Player, itemId: string): (boolean, string)
	local price = MaterialShopService.GetPrice(itemId)
	if not price then
		debugPrint("חומר לא מוכר: " .. tostring(itemId))
		return false, "Invalid item"
	end

	local pds = getPlayerDataService()
	local inv = injectedInventoryService or getInventoryService()
	if not pds or not inv then
		debugPrint("חסרים PlayerDataService או InventoryService")
		return false, "Shop error"
	end

	if not pds.IsDataLoaded(player) then
		debugPrint("נתוני שחקן לא נטענו – " .. player.Name)
		return false, "Please wait"
	end

	local data = pds.GetPlayerData(player)
	if not data then
		return false, "Please wait"
	end

	local coins = data.Coins
	if coins < price then
		debugPrint("לא מספיק מטבעות ל-" .. player.Name .. " – " .. itemId .. " (צריך " .. price .. ")")
		return false, "Not enough coins"
	end

	pds.SetCoins(player, coins - price)
	inv.AddItem(player, itemId, 1)
	pds.RequestSavePlayerData(player)
	debugPrint("קנייה הצליחה: " .. player.Name .. " קנה " .. itemId)
	return true, "Purchased!"
end

-- מכירת חרב אחת
function MaterialShopService.TrySellSword(player: Player, swordId: string): (boolean, string)
	local price = MaterialShopService.GetSwordSellPrice(swordId)
	if not price or price <= 0 then
		debugPrint("TrySellSword: מחיר לא תקין ל-" .. tostring(swordId))
		return false, "Cannot sell this sword"
	end

	local pds = getPlayerDataService()
	local inv = injectedInventoryService or getInventoryService()
	if not pds or not inv then
		debugPrint("TrySellSword: חסרים PlayerDataService או InventoryService")
		return false, "Shop error"
	end

	if not pds.IsDataLoaded(player) then
		debugPrint("TrySellSword: נתוני שחקן לא נטענו – " .. player.Name)
		return false, "Please wait"
	end

	if inv.GetItemAmount(player, swordId) < 1 then
		debugPrint("TrySellSword: אין " .. tostring(swordId) .. " ל-" .. player.Name)
		return false, "You have no this sword"
	end

	if not inv.RemoveItem(player, swordId, 1) then
		return false, "Sell failed"
	end

	local data = pds.GetPlayerData(player)
	if not data then
		return false, "Please wait"
	end

	local newCoins = data.Coins + price
	pds.SetCoins(player, newCoins)
	pds.RequestSavePlayerData(player)
	debugPrint("מכר חרב: " .. player.Name .. " מכר 1x " .. swordId .. " וקיבל " .. price .. " Coins")
	return true, "Sold 1 " .. swordId .. " for " .. tostring(price) .. " Coins"
end

-- מכירת כל החרבות
function MaterialShopService.TrySellAllSwords(player: Player): (boolean, string, number, number)
	local pds = getPlayerDataService()
	local inv = injectedInventoryService or getInventoryService()
	if not pds or not inv then
		debugPrint("TrySellAllSwords: חסרים PlayerDataService או InventoryService")
		return false, "Shop error", 0, 0
	end

	if not pds.IsDataLoaded(player) then
		debugPrint("TrySellAllSwords: נתוני שחקן לא נטענו – " .. player.Name)
		return false, "Please wait", 0, 0
	end

	local counts = getSwordCounts(player, inv)
	local totalCoins = 0
	local totalSwords = 0

	for _, id in SWORD_IDS do
		local count = counts[id] or 0
		if count > 0 then
			local price = MaterialShopService.GetSwordSellPrice(id) or 0
			if price > 0 then
				-- הסרה מה-Inventory
				if inv.RemoveItem(player, id, count) then
					totalCoins += price * count
					totalSwords += count
				end
			end
		end
	end

	if totalSwords == 0 then
		debugPrint("TrySellAllSwords: אין חרבות למכור ל-" .. player.Name)
		return false, "You have no swords to sell", 0, 0
	end

	local data = pds.GetPlayerData(player)
	if not data then
		return false, "Please wait", 0, 0
	end

	local newCoins = data.Coins + totalCoins
	pds.SetCoins(player, newCoins)
	pds.RequestSavePlayerData(player)
	debugPrint("TrySellAllSwords: " .. player.Name .. " מכר " .. totalSwords .. " חרבות וקיבל " .. totalCoins .. " Coins")
	return true, "Sold " .. totalSwords .. " swords for " .. tostring(totalCoins) .. " Coins", totalCoins, totalSwords
end

local remotesCreated = false

function MaterialShopService.Init(inventoryService: any)
	if inventoryService then
		injectedInventoryService = inventoryService
	end
	if remotesCreated then return end

	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end

	local reBuy = folder:FindFirstChild("BuyMaterial")
	if not reBuy or not reBuy:IsA("RemoteEvent") then
		reBuy = Instance.new("RemoteEvent")
		reBuy.Name = "BuyMaterial"
		reBuy.Parent = folder
	end

	local reResult = folder:FindFirstChild("BuyMaterialResult")
	if not reResult or not reResult:IsA("RemoteEvent") then
		reResult = Instance.new("RemoteEvent")
		reResult.Name = "BuyMaterialResult"
		reResult.Parent = folder
	end

	local rfPrices = folder:FindFirstChild("RequestMaterialShopPrices")
	if rfPrices and rfPrices:IsA("RemoteFunction") then
		rfPrices.OnServerInvoke = function(player: Player)
			return MaterialShopService.GetPrices()
		end
		debugPrint("RequestMaterialShopPrices מחובר – מחזיר מחירי קנייה.")
	end

	local rfData = folder:FindFirstChild("RequestMaterialShopData")
	if rfData and rfData:IsA("RemoteFunction") then
		rfData.OnServerInvoke = function(player: Player)
			local inv = injectedInventoryService or getInventoryService()
			return {
				materialPrices = MaterialShopService.GetPrices(),
				swordSellPrices = MaterialShopService.GetSwordSellPrices(),
				swordCounts = getSwordCounts(player, inv),
			}
		end
		debugPrint("RequestMaterialShopData מחובר – מחזיר מחירים וכמויות.")
	end

	local reSellSword = folder:FindFirstChild("SellSword")
	if not reSellSword or not reSellSword:IsA("RemoteEvent") then
		reSellSword = Instance.new("RemoteEvent")
		reSellSword.Name = "SellSword"
		reSellSword.Parent = folder
	end

	local reSellAll = folder:FindFirstChild("SellAllSwords")
	if not reSellAll or not reSellAll:IsA("RemoteEvent") then
		reSellAll = Instance.new("RemoteEvent")
		reSellAll.Name = "SellAllSwords"
		reSellAll.Parent = folder
	end

	reBuy.OnServerEvent:Connect(function(player: Player, itemId: string)
		if not player or not player:IsA("Player") or type(itemId) ~= "string" then
			return
		end
		debugPrint("בקשת קנייה: " .. player.Name .. " – " .. itemId)
		local ok, msg = MaterialShopService.TryPurchase(player, itemId)
		reResult:FireClient(player, ok, msg)
	end)

	reSellSword.OnServerEvent:Connect(function(player: Player, swordId: string)
		if not player or not player:IsA("Player") or type(swordId) ~= "string" then
			return
		end
		debugPrint("בקשת מכירת חרב: " .. player.Name .. " – " .. swordId)
		local ok, msg = MaterialShopService.TrySellSword(player, swordId)
		reResult:FireClient(player, ok, msg)
	end)

	reSellAll.OnServerEvent:Connect(function(player: Player)
		if not player or not player:IsA("Player") then
			return
		end
		debugPrint("בקשת Sell All Swords מ-" .. player.Name)
		local ok, msg = MaterialShopService.TrySellAllSwords(player)
		reResult:FireClient(player, ok, msg)
	end)

	remotesCreated = true
	debugPrint("מוכן. BuyMaterial, BuyMaterialResult.")
end

return MaterialShopService
