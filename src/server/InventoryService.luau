--[[
	InventoryService - מקור האמת לנתוני Inventory של כל שחקן.
	מבנה כללי: Id, Type, Amount. מתאים לחומרים (Amount > 1) ולפריטים כמו חרבות (Amount = 1).
	V1: חומרים בלבד (CopperOre, IronOre, GoldOre). ללא DataStore – session בלבד.
]]

local InventoryService = {}

-- סוגי פריטים – קל להרחבה
local ItemType = {
	Material = "Material",
	Sword = "Sword",
}

-- פריטי V1 – חומרים וחרבות (חרבות מהתנור)
local ITEM_REGISTRY: { [string]: { Type: string, DisplayName: string } } = {
	CopperOre = { Type = ItemType.Material, DisplayName = "Copper Ore" },
	IronOre = { Type = ItemType.Material, DisplayName = "Iron Ore" },
	GoldOre = { Type = ItemType.Material, DisplayName = "Gold Ore" },
	CopperSword = { Type = ItemType.Sword, DisplayName = "Copper Sword" },
	IronSword = { Type = ItemType.Sword, DisplayName = "Iron Sword" },
	GoldSword = { Type = ItemType.Sword, DisplayName = "Gold Sword" },
	DiamondSword = { Type = ItemType.Sword, DisplayName = "Diamond Sword" },
}

-- [player] = { [itemId] = { Id, Type, Amount } }
local inventoryStore: { [Player]: { [string]: { Id: string, Type: string, Amount: number } } } = {}

local DEBUG = true
local function debugPrint(msg: string)
	if DEBUG then
		print("[Inventory] " .. msg)
	end
end

local function getRegistry(itemId: string)
	local r = ITEM_REGISTRY[itemId]
	if r then
		return r.Type, r.DisplayName
	end
	return nil
end

local function createEmptyInventory(): { [string]: { Id: string, Type: string, Amount: number } }
	local inv = {}
	for id, info in ITEM_REGISTRY do
		inv[id] = {
			Id = id,
			Type = info.Type,
			Amount = 0,
		}
	end
	return inv
end

local function toSnapshot(inv: { [string]: { Id: string, Type: string, Amount: number } }): { { Id: string, Type: string, Amount: number, DisplayName: string } }
	local list = {}
	-- סדר קבוע לפי רשימת הפריטים – כך שכל חומר עם Amount > 0 נכנס לרשימה
	for itemId, _ in ITEM_REGISTRY do
		local entry = inv[itemId]
		if entry and entry.Amount > 0 then
			table.insert(list, {
				Id = entry.Id,
				Type = entry.Type,
				Amount = entry.Amount,
				DisplayName = InventoryService.GetDisplayName(entry.Id),
			})
		end
	end
	return list
end

-- ייקרא אחרי כל שינוי ב-Inventory (אם נרשם callback)
local _onInventoryChanged: any = nil
local function notifyChanged(player: Player)
	if type(_onInventoryChanged) == "function" then
		local ok, err = pcall(_onInventoryChanged, player)
		if not ok and DEBUG then
			warn("[Inventory] callback error:", err)
		end
	end
end

function InventoryService.CreateInventory(player: Player)
	if not player or not player:IsA("Player") then return end
	if inventoryStore[player] then
		debugPrint("CreateInventory: כבר קיים ל-" .. player.Name)
		return
	end
	inventoryStore[player] = createEmptyInventory()
	debugPrint("נוצר Inventory ל-" .. player.Name)
end

function InventoryService.DestroyInventory(player: Player)
	if not player then return end
	inventoryStore[player] = nil
	debugPrint("נמחק Inventory של " .. player.Name)
end

function InventoryService.GetInventory(player: Player): { { Id: string, Type: string, Amount: number, DisplayName: string } }
	local inv = inventoryStore[player]
	if not inv then return {} end
	return toSnapshot(inv)
end

function InventoryService.GetItemAmount(player: Player, itemId: string): number
	local inv = inventoryStore[player]
	if not inv then return 0 end
	local entry = inv[itemId]
	if not entry then return 0 end
	return entry.Amount
end

function InventoryService.AddItem(player: Player, itemId: string, amount: number): boolean
	if not amount or amount < 1 then return false end
	local inv = inventoryStore[player]
	if not inv then return false end
	local regType = getRegistry(itemId)
	if not regType then
		debugPrint("AddItem: פריט לא מוכר – " .. tostring(itemId))
		return false
	end
	if not inv[itemId] then
		inv[itemId] = { Id = itemId, Type = regType, Amount = 0 }
	end
	inv[itemId].Amount = inv[itemId].Amount + amount
	debugPrint("נוסף " .. amount .. "x " .. itemId .. " ל-" .. player.Name .. " (סה\"כ " .. inv[itemId].Amount .. ")")
	local ok, err = pcall(notifyChanged, player)
	if not ok and DEBUG then
		warn("[Inventory] AddItem notifyChanged error:", err)
	end
	return true
end

function InventoryService.RemoveItem(player: Player, itemId: string, amount: number): boolean
	if not amount or amount < 1 then return false end
	local inv = inventoryStore[player]
	if not inv then return false end
	local entry = inv[itemId]
	if not entry or entry.Amount < amount then
		debugPrint("RemoveItem: לא מספיק – " .. tostring(itemId) .. " ל-" .. player.Name)
		return false
	end
	entry.Amount = entry.Amount - amount
	debugPrint("הוסר " .. amount .. "x " .. itemId .. " מ-" .. player.Name .. " (נותר " .. entry.Amount .. ")")
	local ok, err = pcall(notifyChanged, player)
	if not ok and DEBUG then
		warn("[Inventory] RemoveItem notifyChanged error:", err)
	end
	return true
end

function InventoryService.HasItem(player: Player, itemId: string, amount: number?): boolean
	local need = amount or 1
	return InventoryService.GetItemAmount(player, itemId) >= need
end

function InventoryService.GetItemsByType(player: Player, itemType: string): { { Id: string, Type: string, Amount: number } }
	local inv = inventoryStore[player]
	if not inv then return {} end
	local list = {}
	for _, entry in inv do
		if entry.Type == itemType and entry.Amount > 0 then
			table.insert(list, { Id = entry.Id, Type = entry.Type, Amount = entry.Amount })
		end
	end
	return list
end

function InventoryService.GetDisplayName(itemId: string): string
	local _, name = getRegistry(itemId)
	return name or itemId
end

-- מחזיר טבלה לשמירה: [itemId] = amount (רק פריטים מוכרים, Amount >= 0). לשימוש ב-PlayerDataService.Save.
function InventoryService.GetInventoryForSave(player: Player): { [string]: number }
	local inv = inventoryStore[player]
	if not inv then return {} end
	local out = {}
	for itemId, entry in inv do
		if entry and type(entry.Amount) == "number" and entry.Amount >= 0 and getRegistry(itemId) then
			out[itemId] = math.floor(entry.Amount)
		end
	end
	return out
end

-- טוען Inventory משמירה (אחרי Claim). saved = { [itemId] = amount }.
function InventoryService.LoadFromSave(player: Player, saved: { [string]: number })
	if not player or not player:IsA("Player") then return end
	local inv = inventoryStore[player]
	if not inv then
		InventoryService.CreateInventory(player)
		inv = inventoryStore[player]
	end
	if not inv then return end
	for itemId, info in ITEM_REGISTRY do
		local amount = 0
		if type(saved) == "table" and type(saved[itemId]) == "number" and saved[itemId] >= 0 then
			amount = math.floor(saved[itemId])
		end
		inv[itemId] = { Id = itemId, Type = info.Type, Amount = amount }
	end
	debugPrint("LoadFromSave ל-" .. player.Name .. " – הוחל משמירה")
	local ok, err = pcall(notifyChanged, player)
	if not ok and DEBUG then
		warn("[Inventory] LoadFromSave notifyChanged error:", err)
	end
end
-- Bootstrap או קוד אחר יכול להגדיר callback – ייקרא אחרי כל AddItem/RemoveItem
function InventoryService.SetOnInventoryChanged(fn: (Player) -> ())
	_onInventoryChanged = fn
end

return InventoryService
