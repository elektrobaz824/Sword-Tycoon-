--[[
	AdminConfigService - מחזיק את ה-Runtime Config ומאפשר רק לאדמין לעדכן ערכים.
	שינויים נשמרים ב-DataStore ונטענים בהפעלה הבאה.
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local AdminConfigService = {}
local CONFIG_DATASTORE_KEY = "SwordTycoon_AdminConfig_v1"
local CONFIG_SAVE_KEY = "Global"

local store = DataStoreService:GetDataStore(CONFIG_DATASTORE_KEY)
local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
local GameConfigModule = Shared and Shared:FindFirstChild("GameConfig")
local GameConfig = GameConfigModule and require(GameConfigModule) or nil

if not GameConfig or not GameConfig.Default then
	warn("[AdminConfigService] GameConfig לא נמצא או חסר Default – משתמש בטבלה ריקה.")
end

local Default = (GameConfig and GameConfig.Default) or {}
local RuntimeConfig = {}
local ConfigPaths = (GameConfig and GameConfig.ConfigPaths) or {}
local AdminUserIds = (GameConfig and GameConfig.AdminUserIds) or {}

local DEBUG_ADMIN = true
local function debugPrint(msg: string)
	if DEBUG_ADMIN then
		print("[AdminConfig] " .. msg)
	end
end

-- העתקה עמוקה של טבלה (רק טבלאות ומספרים – מספיק לקונפיג).
local function deepCopy(src: any): any
	if type(src) ~= "table" then
		return src
	end
	local out = {}
	for k, v in src do
		out[k] = deepCopy(v)
	end
	return out
end

-- ממזג מ-loaded ל-dst – רק ערכים שמתאימים למבנה (מספרים). לא מוסיף מפתחות חדשים ל-dst.
local function deepMergeFromSaved(dst: any, loaded: any)
	if type(loaded) ~= "table" or type(dst) ~= "table" then
		return
	end
	for k, v in loaded do
		if type(v) == "number" then
			dst[k] = v
		elseif type(v) == "table" and dst[k] and type(dst[k]) == "table" then
			deepMergeFromSaved(dst[k], v)
		end
	end
end

-- מחזיר ערך מטבלה לפי path: "Machines.Mechine1.SpawnInterval" -> table["Machines"]["Mechine1"]["SpawnInterval"]
local function getByPath(tbl: { [string]: any }, path: string): (any, boolean)
	local keys = string.split(path, ".")
	local current = tbl
	for i = 1, #keys - 1 do
		local key = keys[i]
		if type(current) ~= "table" or current[key] == nil then
			return nil, false
		end
		current = current[key]
	end
	local lastKey = keys[#keys]
	if type(current) ~= "table" then
		return nil, false
	end
	return current[lastKey], true
end

-- מעדכן ערך בטבלה לפי path. יוצר תת-טבלאות אם חסרות.
local function setByPath(tbl: { [string]: any }, path: string, value: any): boolean
	local keys = string.split(path, ".")
	local current = tbl
	for i = 1, #keys - 1 do
		local key = keys[i]
		if current[key] == nil then
			current[key] = {}
		end
		if type(current[key]) ~= "table" then
			return false
		end
		current = current[key]
	end
	local lastKey = keys[#keys]
	if type(current) ~= "table" then
		return false
	end
	current[lastKey] = value
	return true
end

-- בודק אם path קיים ב-Default (כדי לא לאפשר path שרירותי).
local function isPathAllowed(path: string): boolean
	local allowed = {}
	for _, p in ConfigPaths do
		allowed[p] = true
	end
	if #ConfigPaths > 0 then
		return allowed[path] == true
	end
	-- אם אין רשימה – בודק שה-path קיים ב-Default
	local _, ok = getByPath(Default, path)
	return ok
end

function AdminConfigService.IsAdmin(player: Player): boolean
	if not player or not player:IsA("Player") then
		return false
	end
	for _, id in AdminUserIds do
		if type(id) == "number" and player.UserId == id then
			return true
		end
	end
	return false
end

-- path כמו "Machines.Mechine1.SpawnInterval"
function AdminConfigService.GetValue(path: string): (any, boolean)
	local val, ok = getByPath(RuntimeConfig, path)
	return val, ok
end

function AdminConfigService.SetValue(path: string, value: any): boolean
	if not isPathAllowed(path) then
		debugPrint("SetValue נכשל: path לא מורשה – " .. tostring(path))
		return false
	end
	-- מאפשרים רק מספרים כרגע (ניתן להרחיב ל-string וכו').
	if type(value) ~= "number" then
		debugPrint("SetValue נכשל: ערך לא מספרי – " .. tostring(path))
		return false
	end
	-- ולידציה לקטגוריית Furnace
	if path:match("^Furnace%.") then
		if value < 0 then
			debugPrint("[Furnace Config] Invalid: value cannot be negative – " .. path .. " = " .. tostring(value))
			return false
		end
		local tierMaxMatch = path:match("^Furnace%.(Tier%d+)Max$")
		if tierMaxMatch then
			local tierMinPath = "Furnace." .. tierMaxMatch .. "Min"
			local minVal, okMin = getByPath(RuntimeConfig, tierMinPath)
			if okMin and type(minVal) == "number" and value < minVal then
				debugPrint("[Furnace Config] Invalid Tier range: Max < Min – " .. path)
				return false
			end
		end
	end
	local ok = setByPath(RuntimeConfig, path, value)
	if ok then
		debugPrint("SetValue הצליח: " .. path .. " = " .. tostring(value))
		if path:match("^Furnace%.") then
			print("[Furnace Config] Updated " .. path .. " =", value)
		end
		saveConfigToStore()
	end
	return ok
end

-- טוען קונפיג מ-DataStore וממזג ל-RuntimeConfig (לא דורס – רק מעדכן ערכים שמורים).
local function loadConfigFromStore()
	local ok, data = pcall(function()
		return store:GetAsync(CONFIG_SAVE_KEY)
	end)
	if not ok then
		warn("[AdminConfig] טעינת Config מ-DataStore נכשלה:", data)
		return
	end
	if type(data) == "table" then
		deepMergeFromSaved(RuntimeConfig, data)
		debugPrint("Config נטען מ-DataStore – השינויים נשמרו מהפעלה קודמת.")
	else
		-- הפעלה ראשונה או שום שמירה קודמת (למשל בסטודיו בלי Enable Studio Access to API Services)
		debugPrint("אין Config שמור – משתמשים בברירות המחדל. אחרי שינוי ערך ב-F9 יישמר ביציאה.")
	end
end

-- מחזיר עותק של הטבלה שמתאים ל-DataStore (רק טבלאות ומספרים).
local function copyForDataStore(src: any): any
	if type(src) == "number" then
		return src
	end
	if type(src) ~= "table" then
		return nil
	end
	local out = {}
	for k, v in src do
		if type(v) == "number" then
			out[k] = v
		elseif type(v) == "table" then
			out[k] = copyForDataStore(v)
		end
	end
	return out
end

-- שומר את RuntimeConfig ל-DataStore. נקרא אחרי כל SetValue וגם ב-BindToClose ביציאה.
local function saveConfigToStore()
	local toSave = copyForDataStore(RuntimeConfig)
	if not toSave then
		warn("[AdminConfig] אין מה לשמור.")
		return
	end
	local ok, err = pcall(function()
		store:SetAsync(CONFIG_SAVE_KEY, toSave)
	end)
	if ok then
		debugPrint("Config נשמר ל-DataStore.")
	else
		warn("[AdminConfig] שמירת Config נכשלה:", err)
	end
end

-- מחזיר טבלה של path -> value לכל ה-ConfigPaths (להצגה ב-UI).
function AdminConfigService.GetAllForUI(): { [string]: any }
	local out = {}
	for _, path in ConfigPaths do
		local val, ok = AdminConfigService.GetValue(path)
		if ok and val ~= nil then
			out[path] = val
		end
	end
	return out
end

local remotesCreated = false

function AdminConfigService.Init()
	RuntimeConfig = deepCopy(Default)
	loadConfigFromStore()
	debugPrint("Init: RuntimeConfig הועתק מ-Default ונטען שמירה (אם קיימת).")

	-- ביציאה מהמשחק – שומרים את הקונפיג כדי שבכניסה הבאה ייטען מה ששינית.
	game:BindToClose(function()
		saveConfigToStore()
	end)

	-- Remotes – נוצרים פעם אחת תחת ReplicatedStorage
	local folder = ReplicatedStorage:FindFirstChild("AdminRemotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "AdminRemotes"
		folder.Parent = ReplicatedStorage
	end

	-- RemoteFunction: האם השחקן אדמין?
	local rfAdmin = folder:FindFirstChild("AdminIsAdmin")
	if not rfAdmin or not rfAdmin:IsA("RemoteFunction") then
		rfAdmin = Instance.new("RemoteFunction")
		rfAdmin.Name = "AdminIsAdmin"
		rfAdmin.Parent = folder
	end
	rfAdmin.OnServerInvoke = function(player: Player)
		local isAdmin = AdminConfigService.IsAdmin(player)
		debugPrint("AdminIsAdmin נבדק ל-" .. player.Name .. " = " .. tostring(isAdmin))
		return isAdmin
	end

	-- RemoteFunction: קבלת כל הערכים ל-UI
	local rfGet = folder:FindFirstChild("AdminGetConfig")
	if not rfGet or not rfGet:IsA("RemoteFunction") then
		rfGet = Instance.new("RemoteFunction")
		rfGet.Name = "AdminGetConfig"
		rfGet.Parent = folder
	end
	rfGet.OnServerInvoke = function(player: Player)
		if not AdminConfigService.IsAdmin(player) then
			debugPrint("AdminGetConfig דחוי – לא אדמין: " .. player.Name)
			return nil
		end
		return AdminConfigService.GetAllForUI()
	end

	-- RemoteEvent: עדכון ערך בודד (path, value)
	local reSet = folder:FindFirstChild("AdminSetValue")
	if not reSet or not reSet:IsA("RemoteEvent") then
		reSet = Instance.new("RemoteEvent")
		reSet.Name = "AdminSetValue"
		reSet.Parent = folder
	end
	reSet.OnServerEvent:Connect(function(player: Player, path: string, value: any)
		if not AdminConfigService.IsAdmin(player) then
			debugPrint("AdminSetValue דחוי – לא אדמין: " .. player.Name)
			return
		end
		if type(path) ~= "string" or path == "" then
			debugPrint("AdminSetValue דחוי – path לא תקין")
			return
		end
		AdminConfigService.SetValue(path, value)
	end)

	remotesCreated = true
	debugPrint("Init: Remotes מוכנים (AdminIsAdmin, AdminGetConfig, AdminSetValue).")
end

return AdminConfigService
