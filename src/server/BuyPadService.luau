--[[
	BuyPadService - Buy Pads (למשל Plot > BuyPads > Mechine2Pad)
	פד יכול להיות Part/BasePart או Model — שני המצבים נתמכים (בפרויקט רבים הם Part עם ProximityPrompt כילד).
	אין שום Destroy / שינוי Parent על Pads בקוד הזה.
	ProximityPrompt: Hide/Show דרך Enabled. גיאומטריה: Transparency 0/1 לפי שלב (ShowOrder) ושמירת רכישות — ראה RefreshPadVisibilityFromSave.
	דיבאג מחזור חיים: לפני Play בשרת: _G.SwordTycoonDebugBuyPadLifecycle = true
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local BuyPadService = {}

local FOLDER_BUY_PADS = "BuyPads"
local VALUES_FOLDER_NAME = "Values"
local ACTIVE_FACTORY_TYPE_VALUE_NAME = "ActiveFactoryType"
local FACTORY_CONTENT_FOLDER_NAME = "FactoryContent"
local DEFAULT_FACTORY_MODEL_NAME = "CopperFactory"
local ATTR_COST = "Cost"
local ATTR_DISPLAY_NAME = "DisplayName"
local ATTR_PURCHASED = "Purchased"
local ATTR_LAST_TRIGGER = "LastTriggerTime"
local ATTR_PAD_GROUP = "PadGroup"
local ATTR_SHOW_ORDER = "ShowOrder"
local PAD_GROUP_MACHINES = "Machines"
local PAD_GROUP_BUILDINGS = "Buildings"
local REMOTE_NAME = "BuyPadNotEnoughCoins"
local DEFAULT_COST = 100
-- מחיר לפי מספר המכונה: Mechine2Pad=100, Mechine3Pad=400, Mechine4Pad=500, Mechine5Pad=600 וכו'
local COST_BY_MACHINE_NUMBER: { [number]: number } = {
	[2] = 100,
	[3] = 400,
	[4] = 500,
	[5] = 600,
	[6] = 700,
	[7] = 800,
	[8] = 900,
	[9] = 1000,
	[10] = 1100,
}
local DEBOUNCE_SEC = 2

local DEBUG_BUYPADS = true
local function debugPrint(msg: string)
	if DEBUG_BUYPADS then
		print("[BuyPad Debug] " .. msg)
	end
end

local function lifecycleDebugEnabled(): boolean
	return _G.SwordTycoonDebugBuyPadLifecycle == true
end

local function removalOrLifecycleDebug(): boolean
	return _G.SwordTycoonDebugBuyPadsRemoval == true or lifecycleDebugEnabled()
end

local function safeFullName(inst: Instance): string
	local ok, s = pcall(function()
		return inst:GetFullName()
	end)
	return ok and s or inst.Name
end

-- פדים שכבר חוברו ל-setupPad (כשהם נטענים אחרי Init / Claim)
local wiredPadRoots: { [Instance]: boolean } = {}
local padLifecycleWatched: { [Instance]: boolean } = {}

local function attachBuyPadLifecycleDebug(pad: Instance)
	if padLifecycleWatched[pad] then
		return
	end
	padLifecycleWatched[pad] = true
	pad.Destroying:Connect(function()
		if not lifecycleDebugEnabled() then
			return
		end
		warn("[BuyPadLifecycle] DESTROYING | " .. safeFullName(pad))
		warn("[BuyPadLifecycle] DESTROYING traceback:\n" .. debug.traceback())
	end)
	pad.AncestryChanged:Connect(function()
		if not lifecycleDebugEnabled() then
			return
		end
		local p = pad.Parent
		warn(
			"[BuyPadLifecycle] PARENT_CHANGED | "
				.. safeFullName(pad)
				.. " | newParent="
				.. (p and safeFullName(p) or "nil")
		)
		warn("[BuyPadLifecycle] PARENT_CHANGED traceback:\n" .. debug.traceback())
	end)
end
-- plot → BuyPads container שאליו חוברו ChildAdded/DescendantAdded (אם הקונטיינר משתנה — מחברים שוב)
local buyPadsWatchAttached: { [Instance]: Instance? } = {}
local hydrationPollActive: { [Instance]: boolean } = {}
local notEnoughRemoteForPads: RemoteEvent? = nil
-- Restore רץ לפעמים כשעדיין אין פדים בעולם — צריך לחזור על השחזור כשהם מופיעים
local buyPadRestoreNeedsRetry: { [Instance]: boolean } = {}

-- דיבאג ילד שנעקר מ-BuyPads: _G.SwordTycoonDebugBuyPadsRemoval = true או _G.SwordTycoonDebugBuyPadLifecycle = true (שרת, לפני Play)
local buyPadsRemovalDebugAttached: { [Instance]: boolean } = {}

local function attachBuyPadsRemovalDebug(container: Instance, plot: Instance)
	if buyPadsRemovalDebugAttached[container] then
		return
	end
	buyPadsRemovalDebugAttached[container] = true
	container.ChildRemoved:Connect(function(child: Instance)
		if not removalOrLifecycleDebug() then
			return
		end
		local fullNameOk, fullName = pcall(function()
			return child:GetFullName()
		end)
		if not fullNameOk then
			fullName = child.Name .. " (GetFullName failed)"
		end
		warn(
			"[BuyPadRemovalDebug] ChildRemoved מ-BuyPads | plot="
				.. plot.Name
				.. " | container="
				.. container:GetFullName()
				.. " | child="
				.. child.Name
				.. " | ClassName="
				.. child.ClassName
				.. " | fullName="
				.. tostring(fullName)
		)
		-- לא תמיד מציג מי ביצע את ה-Destroy (לרוב סטאק של המנוע); עדיין עוזר לזמן + שם אובייקט
		print("[BuyPadRemovalDebug] traceback (מהקולבק של ChildRemoved):")
		print(debug.traceback())
	end)
	-- ילד ישיר או ProximityPrompt (בלי לוג על כל Part פנימי כשמוחקים מודל שלם)
	container.DescendantRemoving:Connect(function(desc: Instance)
		if not removalOrLifecycleDebug() then
			return
		end
		if desc.Parent ~= container and not desc:IsA("ProximityPrompt") then
			return
		end
		local ok, fn = pcall(function()
			return desc:GetFullName()
		end)
		warn(
			"[BuyPadRemovalDebug] DescendantRemoving מתחת ל-BuyPads | plot="
				.. plot.Name
				.. " | "
				.. desc.ClassName
				.. " | "
				.. (ok and fn or desc.Name)
		)
	end)
	container:GetPropertyChangedSignal("Parent"):Connect(function()
		if not removalOrLifecycleDebug() then
			return
		end
		local p = container.Parent
		warn(
			"[BuyPadRemovalDebug] BuyPads.Parent השתנה | plot="
				.. plot.Name
				.. " | parentעכשיו="
				.. (p and p:GetFullName() or "nil (התיקייה הועברה או נהרסה)")
		)
		print(debug.traceback())
	end)
	-- מוניטור מספר ילדים ישירים — אם יורד בלי ChildRemoved (נדיר) או כדי לתעד זמן
	if removalOrLifecycleDebug() then
		task.spawn(function()
			local last = #container:GetChildren()
			while container.Parent do
				task.wait(0.75)
				local n = #container:GetChildren()
				if n ~= last then
					warn(
						"[BuyPadRemovalDebug] מספר ילדים ב-BuyPads השתנה | plot="
							.. plot.Name
							.. " | "
							.. tostring(last)
							.. " -> "
							.. tostring(n)
							.. " | "
							.. container:GetFullName()
					)
					last = n
				end
			end
		end)
	end
end

-- דיבאג פדי בית (אותו מתג כמו PlotSetupService): _G.SwordTycoonDebugHousePads = true
local function debugHouseSectionPad(msg: string)
	if _G.SwordTycoonDebugHousePads == true then
		print("[HouseSectionPadDebug] " .. msg)
	end
end

local function getPlayerDataService()
	for _, desc in ServerScriptService:GetDescendants() do
		if desc:IsA("ModuleScript") and desc.Name == "PlayerDataService" then
			return require(desc)
		end
	end
	return nil
end

local function getPlotClaimService()
	for _, desc in ServerScriptService:GetDescendants() do
		if desc:IsA("ModuleScript") and desc.Name == "PlotClaimService" then
			return require(desc)
		end
	end
	return nil
end

local function getPlotSetupService()
	for _, desc in ServerScriptService:GetDescendants() do
		if desc:IsA("ModuleScript") and desc.Name == "PlotSetupService" then
			return require(desc)
		end
	end
	return nil
end

local function getAdminConfigService()
	if _G.SwordTycoonAdminConfig then
		return _G.SwordTycoonAdminConfig
	end
	for _, desc in ServerScriptService:GetDescendants() do
		if desc:IsA("ModuleScript") and desc.Name == "AdminConfigService" then
			return require(desc)
		end
	end
	return nil
end

local function getPlotFromPad(pad: Instance): Instance?
	local plotsFolder = Workspace:FindFirstChild("Plots")
	if not plotsFolder then
		return nil
	end
	local current = pad.Parent
	while current and current ~= Workspace do
		if current.Parent == plotsFolder then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function getActiveFactoryType(plot: Instance): string?
	local values = plot:FindFirstChild(VALUES_FOLDER_NAME)
	if not values then
		return nil
	end
	local v = values:FindFirstChild(ACTIVE_FACTORY_TYPE_VALUE_NAME)
	if v and v:IsA("StringValue") then
		local s = v.Value
		if type(s) == "string" and s ~= "" then
			return s
		end
	end
	return nil
end

-- תואם PlotSetupService: Values + FactoryContent, או ברירת מחדל CopperFactory
local function getResolvedFactoryModelForBuyPads(plot: Instance): Instance?
	local fc = plot:FindFirstChild(FACTORY_CONTENT_FOLDER_NAME)
	if not fc then
		return nil
	end
	local t = getActiveFactoryType(plot)
	if t then
		local m = fc:FindFirstChild(t .. "Factory")
		if m and (m:IsA("Model") or m:IsA("Folder")) then
			return m
		end
	end
	local def = fc:FindFirstChild(DEFAULT_FACTORY_MODEL_NAME)
	if def and (def:IsA("Model") or def:IsA("Folder")) then
		return def
	end
	return nil
end

local function isBuyPadsContainer(inst: Instance?): boolean
	return inst ~= nil and (inst:IsA("Folder") or inst:IsA("Model"))
end

-- כל תיקיות/מודלים בשם BuyPads תחת המפעל; בוחרים את זה עם הכי הרבה ProximityPrompt (לא רק FindFirstChild — נמנע תיקייה ריקה כפולה)
local function findBestBuyPadsUnderFactory(fac: Instance): Instance?
	local best: Instance? = nil
	local bestPrompts = -1
	local bestChildren = -1
	for _, d in fac:GetDescendants() do
		if not isBuyPadsContainer(d) or d.Name ~= FOLDER_BUY_PADS then
			continue
		end
		local promptCount = 0
		for _, x in d:GetDescendants() do
			if x:IsA("ProximityPrompt") then
				promptCount += 1
			end
		end
		local childCount = #d:GetChildren()
		if promptCount > bestPrompts or (promptCount == bestPrompts and childCount > bestChildren) then
			bestPrompts = promptCount
			bestChildren = childCount
			best = d
		end
	end
	if best and (bestPrompts > 0 or bestChildren > 0) then
		return best
	end
	-- כולם ריקים / 0: עדיין מחזירים את BuyPads הישיר תחת המפעל (זרימה + streaming), לא תיקייה ריקה אקראית קודמה ב-GetDescendants של ה-Plot
	local direct = fac:FindFirstChild(FOLDER_BUY_PADS)
	if isBuyPadsContainer(direct) then
		return direct
	end
	return best
end

-- קודם FactoryContent > <Type>Factory > BuyPads (העשיר ביותר), אחרת plot > BuyPads, אחרת חיפוש descendant (תאימות לאחור)
local function getBuyPadsContainerForPlot(plot: Instance, suppressLog: boolean?): Instance?
	local fac = getResolvedFactoryModelForBuyPads(plot)
	if fac then
		local bp = findBestBuyPadsUnderFactory(fac)
		if bp then
			if not suppressLog then
				local promptCount = 0
				for _, x in bp:GetDescendants() do
					if x:IsA("ProximityPrompt") then
						promptCount += 1
					end
				end
				print(
					"[BuyPadService] BuyPads: using FACTORY path "
						.. bp:GetFullName()
						.. " | prompts="
						.. tostring(promptCount)
						.. " | children="
						.. tostring(#bp:GetChildren())
				)
			end
			return bp
		end
	end
	local root = plot:FindFirstChild(FOLDER_BUY_PADS)
	if isBuyPadsContainer(root) then
		if not suppressLog then
			print("[BuyPadService] BuyPads: using ROOT fallback (plot > " .. FOLDER_BUY_PADS .. ") on plot " .. plot.Name)
		end
		return root
	end
	for _, desc in plot:GetDescendants() do
		if (desc:IsA("Folder") or desc:IsA("Model")) and desc.Name == FOLDER_BUY_PADS then
			if not suppressLog then
				print("[BuyPadService] BuyPads: using DESCENDANT fallback at " .. desc:GetFullName())
			end
			return desc
		end
	end
	debugPrint("ERROR: BuyPads folder/model not found for plot: " .. plot.Name)
	return nil
end

local function getProximityPrompt(pad: Instance): ProximityPrompt?
	if pad:IsA("ProximityPrompt") then
		return pad :: ProximityPrompt
	end
	for _, desc in pad:GetDescendants() do
		if desc:IsA("ProximityPrompt") then
			return desc :: ProximityPrompt
		end
	end
	return nil
end

-- מחזיר את מספר המכונה משם ה-Pad: Mechine2Pad / Machine2Pad -> 2 וכו'
local function getMachineNumberFromPadName(padName: string): number?
	local num = padName:match("Mechine(%d+)Pad") or padName:match("Machine(%d+)Pad")
	if num then
		return tonumber(num)
	end
	return nil
end

function BuyPadService.GetPadGroup(pad: Instance): string
	local g = pad:GetAttribute(ATTR_PAD_GROUP)
	if type(g) == "string" then
		g = (g :: string):match("^%s*(.-)%s*$") or ""
		if g ~= "" then
			return g
		end
	end
	if pad.Name:match("^HouseSection%d+Pad$") then
		return PAD_GROUP_BUILDINGS
	end
	if getMachineNumberFromPadName(pad.Name) then
		return PAD_GROUP_MACHINES
	end
	return PAD_GROUP_MACHINES
end

function BuyPadService.GetPadShowOrder(pad: Instance): number
	local raw = pad:GetAttribute(ATTR_SHOW_ORDER)
	if raw ~= nil then
		local o: number? = nil
		if type(raw) == "number" then
			o = raw
		elseif type(raw) == "string" then
			local s = (raw :: string):match("^%s*(.-)%s*$") or ""
			o = tonumber(s)
		end
		if type(o) == "number" and o >= 1 and o == math.floor(o) then
			return math.floor(o)
		end
	end
	local hs = pad.Name:match("^HouseSection(%d+)Pad$")
	if hs then
		return tonumber(hs) or 1
	end
	local m = getMachineNumberFromPadName(pad.Name)
	if m then
		return m
	end
	return 1
end

local function getPadGroup(pad: Instance): string
	return BuyPadService.GetPadGroup(pad)
end

local function getPadShowOrder(pad: Instance): number
	return BuyPadService.GetPadShowOrder(pad)
end

local function nameLooksLikeBuyPad(name: string): boolean
	if getMachineNumberFromPadName(name) then
		return true
	end
	if name:match("^HouseSection%d+Pad$") then
		return true
	end
	if name == "Pad" then
		return false
	end
	return name:match("Pad$") ~= nil
end

-- שורש הפד לפי ה-Prompt: האב הקרוב ביותר בשרשרת עד ה-Plot ששמו נראה כמו buy pad (מתקן תיקיית מעטפת תחת BuyPads)
local function resolvePadRootForPrompt(plot: Instance, prompt: ProximityPrompt): Instance?
	local ancestors = {}
	local cur: Instance? = prompt.Parent
	while cur and cur ~= plot do
		table.insert(ancestors, cur)
		cur = cur.Parent
	end
	if #ancestors == 0 then
		return nil
	end
	for _, inst in ipairs(ancestors) do
		local pgRaw = inst:GetAttribute(ATTR_PAD_GROUP)
		local pg = if type(pgRaw) == "string" then ((pgRaw :: string):match("^%s*(.-)%s*$") or "") else ""
		if pg ~= "" then
			return inst
		end
		if inst:GetAttribute(ATTR_SHOW_ORDER) ~= nil then
			return inst
		end
		if nameLooksLikeBuyPad(inst.Name) then
			return inst
		end
	end
	-- אל תחזירו Part אקראי: רק אב עם PadGroup או שם פד תקין (מתקן חוסר התאמה ל-computeVisibleShowOrder)
	for i = #ancestors, 1, -1 do
		local inst = ancestors[i]
		if inst.Name == FOLDER_BUY_PADS then
			continue
		end
		local pgRaw2 = inst:GetAttribute(ATTR_PAD_GROUP)
		local pg2 = if type(pgRaw2) == "string" then ((pgRaw2 :: string):match("^%s*(.-)%s*$") or "") else ""
		if pg2 ~= "" then
			return inst
		end
		if inst:GetAttribute(ATTR_SHOW_ORDER) ~= nil then
			return inst
		end
		if nameLooksLikeBuyPad(inst.Name) then
			return inst
		end
	end
	return nil
end

-- שם תצוגה לפדים בלי כלל מיוחד: מסיר סיומת Pad, מפריד CamelCase ומפריד מספרים (למשל ExtraThing3Pad -> "Extra Thing 3")
local function humanizePadName(raw: string): string
	local s = raw
	if s:match("Pad$") then
		s = s:sub(1, -4)
	end
	if s == "" then
		return raw
	end
	s = s:gsub("(%l)(%u)", "%1 %2")
	s = s:gsub("(%a+)(%d+)", "%1 %2")
	return s
end

-- מחזיר מחיר ל-Pad: קודם Attribute, אחרת AdminConfig (BuyPads.Mechine2Pad.Cost), אחרת COST_BY_MACHINE_NUMBER
local function getCostForPad(pad: Instance): number
	local attr = pad:GetAttribute(ATTR_COST)
	if type(attr) == "number" and attr >= 0 then
		return attr
	end
	-- Config מהאדמין – אם שינית מחיר בחלון F9, משתמשים בו
	local adminConfig = getAdminConfigService()
	local getConfigValue = adminConfig and (adminConfig :: any).GetValue
	if type(getConfigValue) == "function" then
		local path = "BuyPads." .. pad.Name .. ".Cost"
		local configCost, ok = getConfigValue(path)
		if ok and type(configCost) == "number" and configCost >= 0 then
			return configCost
		end
	end
	local num = getMachineNumberFromPadName(pad.Name)
	if num and COST_BY_MACHINE_NUMBER[num] then
		return COST_BY_MACHINE_NUMBER[num]
	end
	if num and num > 10 then
		return 500 + (num - 3) * 100
	end
	return DEFAULT_COST
end

-- מחזיר שם לתצוגה: Mechine*Pad נשאר "Mechine N"; שאר שמות PascalCase מתורבצים; אפשר לדרוס ב-Attribute DisplayName
local function getDisplayNameForPad(pad: Instance): string
	local override = pad:GetAttribute(ATTR_DISPLAY_NAME)
	if type(override) == "string" and override:match("%S") then
		return override
	end
	local num = getMachineNumberFromPadName(pad.Name)
	if num then
		return "Mechine " .. tostring(num)
	end
	return humanizePadName(pad.Name)
end

-- מעדכן את ה-ProximityPrompt של ה-Pad: שם תצוגה + מחיר (למשל "Mechine 2 - 100")
local function updatePadPromptDisplay(pad: Instance)
	local prompt = getProximityPrompt(pad)
	if not prompt then return end
	local displayName = getDisplayNameForPad(pad)
	local cost = getCostForPad(pad)
	prompt.ActionText = displayName .. " - " .. tostring(cost)
	prompt.ObjectText = displayName
end

-- כיבוי/הפעלת קנייה: רק כל ProximityPrompt תחת שורש הפד.
local function setAllProximityPromptsUnderPadEnabled(pad: Instance, enabled: boolean)
	if pad:IsA("ProximityPrompt") then
		(pad :: ProximityPrompt).Enabled = enabled
		return
	end
	for _, d in pad:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			d.Enabled = enabled
		end
	end
end

-- HidePad – כיבוי קנייה בלבד (Prompt). אין Destroy. ה-Pad נשאר ב-Plot > BuyPads.
local function HidePad(pad: Instance)
	if lifecycleDebugEnabled() then
		attachBuyPadLifecycleDebug(pad)
	end
	debugPrint("HidePad called for: " .. pad.Name .. " | " .. (pad:IsA("Model") and "Model" or (pad:IsA("BasePart") and "Part" or pad.ClassName)))
	setAllProximityPromptsUnderPadEnabled(pad, false)
	if getProximityPrompt(pad) then
		debugPrint("Prompt(s) disabled for: " .. pad.Name)
	else
		debugPrint("ERROR: Prompt not found on pad: " .. pad.Name)
	end
	if lifecycleDebugEnabled() then
		print("[BuyPadLifecycle] HIDE | " .. safeFullName(pad))
	end
end

-- ShowPad – הפעלת Prompt בלבד.
local function ShowPad(pad: Instance)
	if lifecycleDebugEnabled() then
		attachBuyPadLifecycleDebug(pad)
	end
	debugPrint("ShowPad called for: " .. pad.Name .. " | " .. (pad:IsA("Model") and "Model" or (pad:IsA("BasePart") and "Part" or pad.ClassName)))
	setAllProximityPromptsUnderPadEnabled(pad, true)
	if getProximityPrompt(pad) then
		debugPrint("Prompt(s) enabled for: " .. pad.Name)
	else
		debugPrint("ERROR: Prompt not found on pad: " .. pad.Name)
	end
	if lifecycleDebugEnabled() then
		print("[BuyPadLifecycle] SHOW | " .. safeFullName(pad))
	end
end

-- מחזיר את כל ה-Pads ב-Plot. לכל ProximityPrompt: שורש הפד = האב הקרוב ביותר ל-prompt ששמו נראה כ-*Pad (מתקן BuyPads > תיקייה > Mechine2Pad).
local function visibilityDebug(msg: string)
	if _G.SwordTycoonDebugBuyPadVisibility == true then
		print("[BuyPadVisibility] " .. msg)
	end
end

local function hasBuyPadAncestorBetween(instance: Instance, top: Instance): boolean
	local cur: Instance? = instance.Parent
	while cur and cur ~= top do
		if cur:IsA("Model") or cur:IsA("BasePart") then
			local pgRaw = cur:GetAttribute(ATTR_PAD_GROUP)
			local pg = if type(pgRaw) == "string"
				then ((pgRaw :: string):match("^%s*(.-)%s*$") or "")
				else ""
			if pg ~= "" and getProximityPrompt(cur) then
				return true
			end
			if cur:GetAttribute(ATTR_SHOW_ORDER) ~= nil and getProximityPrompt(cur) then
				return true
			end
			if nameLooksLikeBuyPad(cur.Name) and getProximityPrompt(cur) then
				return true
			end
		end
		cur = cur.Parent
	end
	return false
end

-- גיבוי כש-resolvePadRootForPrompt לא מזהה שורש (מבנה Prompt חריג) אבל יש Part/Model בשם פד עם Prompt
local function collectBuyPadRootsByNameUnderPlot(plot: Instance, seen: { [Instance]: boolean }, list: { Instance })
	for _, d in plot:GetDescendants() do
		if not (d:IsA("Model") or d:IsA("BasePart")) then
			continue
		end
		if not nameLooksLikeBuyPad(d.Name) then
			continue
		end
		if not getProximityPrompt(d) then
			continue
		end
		if seen[d] then
			continue
		end
		seen[d] = true
		table.insert(list, d)
	end
end

local function appendPadRootsFromBuyPadsContainer(container: Instance, seen: { [Instance]: boolean }, list: { Instance })
	for _, d in container:GetDescendants() do
		if not d:IsA("Model") and not d:IsA("BasePart") then
			continue
		end
		local pgRaw = d:GetAttribute(ATTR_PAD_GROUP)
		local pg = if type(pgRaw) == "string" then ((pgRaw :: string):match("^%s*(.-)%s*$") or "") else ""
		local hasGroup = pg ~= ""
		local hasShowOrderAttr = d:GetAttribute(ATTR_SHOW_ORDER) ~= nil
		if not hasGroup and not nameLooksLikeBuyPad(d.Name) and not hasShowOrderAttr then
			continue
		end
		if not getProximityPrompt(d) then
			continue
		end
		if hasBuyPadAncestorBetween(d, container) then
			continue
		end
		if not seen[d] then
			seen[d] = true
			table.insert(list, d)
		end
	end
end

local function getPadsInPlot(plot: Instance, suppressBuyPadsLog: boolean?): { Instance }
	local list = {}
	local seen = {}
	local container = getBuyPadsContainerForPlot(plot, suppressBuyPadsLog)
	for _, desc in plot:GetDescendants() do
		if not desc:IsA("ProximityPrompt") then
			continue
		end
		local root = resolvePadRootForPrompt(plot, desc :: ProximityPrompt)
		if root and not seen[root] then
			seen[root] = true
			table.insert(list, root)
		end
	end
	if container then
		appendPadRootsFromBuyPadsContainer(container, seen, list)
	end
	if #list == 0 then
		collectBuyPadRootsByNameUnderPlot(plot, seen, list)
	end
	return list
end

-- שלב גלוי לקבוצה: סדר ממוין לפי ShowOrder; מחזיר את הסדר הראשון שבו לא כל הפדים נרכשו.
local function computeVisibleShowOrderForGroup(
	pads: { Instance },
	group: string,
	isPurchased: (Instance) -> boolean
): number?
	local byOrder: { [number]: { Instance } } = {}
	for _, pad in pads do
		if getPadGroup(pad) == group then
			local o = getPadShowOrder(pad)
			if not byOrder[o] then
				byOrder[o] = {}
			end
			table.insert(byOrder[o], pad)
		end
	end
	local orders = {}
	for o in pairs(byOrder) do
		table.insert(orders, o)
	end
	if #orders == 0 then
		return nil
	end
	table.sort(orders)
	for _, o in ipairs(orders) do
		local list = byOrder[o]
		local allPurchased = true
		for _, p in list do
			if not isPurchased(p) then
				allPurchased = false
				break
			end
		end
		if not allPurchased then
			return o
		end
	end
	return nil
end

-- השלב ה"ראשון" בקבוצה לפי ה-ShowOrder הממוספר בפועל (שם/אטריביוט), לא תמיד 1 — למשל Mechine2Pad => 2.
local function getMinShowOrderAmongPadsForGroup(pads: { Instance }, group: string): number?
	local minO: number? = nil
	for _, pad in pads do
		if getPadGroup(pad) == group then
			local o = getPadShowOrder(pad)
			if minO == nil or o < minO then
				minO = o
			end
		end
	end
	return minO
end

-- שקיפות גיאומטריה (Part או כל BasePart תחת Model). 0 = גלוי, 1 = מוסתר.
local function applyPadGeometryTransparency(pad: Instance, transparency: number)
	local t = transparency
	if t < 0 then
		t = 0
	elseif t > 1 then
		t = 1
	end
	if pad:IsA("BasePart") then
		pad.Transparency = t
		return
	end
	for _, d in pad:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = t
		end
	end
end

-- סנכרון נראות פדים לפי PadGroup + ShowOrder + PurchasedPads (ללא שרשור לפי שם).
function BuyPadService.RefreshPadVisibilityFromSave(plot: Instance, player: Player)
	local pds = getPlayerDataService()
	if not pds then
		visibilityDebug("Refresh SKIP: PlayerDataService nil | plot=" .. plot.Name)
		return
	end
	if not pds.IsDataLoaded(player) then
		visibilityDebug(
			"Refresh DEFER: IsDataLoaded=false | plot="
				.. plot.Name
				.. " | player="
				.. player.Name
				.. " — will retry next frame"
		)
		task.defer(function()
			if plot.Parent == nil or player.Parent == nil then
				return
			end
			local pds2 = getPlayerDataService()
			if pds2 and pds2.IsDataLoaded(player) then
				BuyPadService.RefreshPadVisibilityFromSave(plot, player)
			else
				visibilityDebug("Refresh DEFER retry: still not loaded for " .. player.Name)
			end
		end)
		return
	end
	local purchasedByName = pds.GetPurchasedPads(player)
	local pads = getPadsInPlot(plot, true)
	for _, pad in pads do
		if purchasedByName[pad.Name] then
			pad:SetAttribute(ATTR_PURCHASED, true)
		end
	end
	local function isPurchased(pad: Instance): boolean
		if pad:GetAttribute(ATTR_PURCHASED) then
			return true
		end
		if purchasedByName[pad.Name] then
			return true
		end
		return false
	end
	local groups: { [string]: boolean } = {}
	for _, pad in pads do
		groups[getPadGroup(pad)] = true
	end
	local visibleOrderByGroup: { [string]: number? } = {}
	for g in pairs(groups) do
		visibleOrderByGroup[g] = computeVisibleShowOrderForGroup(pads, g, isPurchased)
	end
	-- שקיפות גיאומטריה: בלי אף רכישת פד בשמירה → רק השלב הראשון בקבוצה (מינימום ShowOrder); אחרי שיש רכישה → השלב הנוכחי (כמו vo).
	local anyPadPurchasedEver = next(purchasedByName) ~= nil
	local geometryVisibleOrderByGroup: { [string]: number? } = {}
	for g in pairs(groups) do
		if anyPadPurchasedEver then
			geometryVisibleOrderByGroup[g] = visibleOrderByGroup[g]
		else
			geometryVisibleOrderByGroup[g] = getMinShowOrderAmongPadsForGroup(pads, g) or 1
		end
	end
	if _G.SwordTycoonDebugBuyPadVisibility == true then
		visibilityDebug(
			"Refresh RUN | plot="
				.. plot.Name
				.. " | player="
				.. player.Name
				.. " | padCount="
				.. tostring(#pads)
		)
		for g, vo in pairs(visibleOrderByGroup) do
			visibilityDebug(
				"  computed visible ShowOrder for group ["
					.. g
					.. "] = "
					.. tostring(vo)
					.. " | geometryTier="
					.. tostring(geometryVisibleOrderByGroup[g])
					.. " (anyPurchase="
					.. tostring(anyPadPurchasedEver)
					.. ")"
			)
		end
	end
	for _, pad in pads do
		local g = getPadGroup(pad)
		local ord = getPadShowOrder(pad)
		local vo = visibleOrderByGroup[g]
		local geoVo = geometryVisibleOrderByGroup[g]
		local purchased = isPurchased(pad)
		if _G.SwordTycoonDebugBuyPadVisibility == true then
			local action: string
			if purchased then
				action = "HIDE (purchased)"
			elseif vo and ord == vo then
				action = "SHOW (current stage)"
			elseif vo == nil then
				action = "HIDE (no visible stage for group)"
			else
				action = "HIDE (not current stage; need ShowOrder=" .. tostring(vo) .. ")"
			end
			visibilityDebug(
				"  pad="
					.. pad.Name
					.. " | attr PadGroup="
					.. tostring(pad:GetAttribute(ATTR_PAD_GROUP))
					.. " | resolvedGroup="
					.. g
					.. " | attr ShowOrder="
					.. tostring(pad:GetAttribute(ATTR_SHOW_ORDER))
					.. " | resolvedOrder="
					.. tostring(ord)
					.. " | purchased="
					.. tostring(purchased)
					.. " | groupVisibleOrder="
					.. tostring(vo)
					.. " | -> "
					.. action
			)
		end
		local promptActive = not purchased and vo ~= nil and ord == vo
		local geometryVisible = not purchased and geoVo ~= nil and ord == geoVo

		if purchased then
			HidePad(pad)
			applyPadGeometryTransparency(pad, 1)
		else
			if promptActive then
				ShowPad(pad)
				updatePadPromptDisplay(pad)
			else
				HidePad(pad)
			end
			applyPadGeometryTransparency(pad, geometryVisible and 0 or 1)
		end
	end
	local plotSetup = getPlotSetupService()
	if plotSetup and plotSetup.ApplyHouseBuyProgression then
		plotSetup.ApplyHouseBuyProgression(plot, player)
	end
end

function BuyPadService.GetBuyPadRootsInPlot(plot: Instance): { Instance }
	return getPadsInPlot(plot, true)
end

local function setupPad(pad: Instance, plot: Instance, notEnoughRemote: RemoteEvent)
	local prompt = getProximityPrompt(pad)
	if not prompt then
		debugPrint("ERROR: Prompt not found on pad: " .. pad.Name)
		return
	end
	updatePadPromptDisplay(pad)
	debugPrint("Found pad: " .. pad.Name)
	attachBuyPadLifecycleDebug(pad)

	prompt.Triggered:Connect(function(player: Player)
		local now = tick()
		local last = pad:GetAttribute(ATTR_LAST_TRIGGER) or 0
		if now - last < DEBOUNCE_SEC then
			return
		end
		pad:SetAttribute(ATTR_LAST_TRIGGER, now)

		local plotClaim = getPlotClaimService()
		local pds = getPlayerDataService()
		if not plotClaim or not pds then
			return
		end

		local owner = plotClaim.GetPlotOwner(plot)
		if owner ~= player or not owner then
			return
		end

		if pad:GetAttribute(ATTR_PURCHASED) then
			return
		end

		local cost = getCostForPad(pad)

		if not pds.IsDataLoaded(player) then
			return
		end

		local data = pds.GetPlayerData(player)
		if not data then
			return
		end

		local have = data.Coins
		local need = cost - have

		if need > 0 then
			notEnoughRemote:FireClient(player, cost, have, need)
			return
		end

		pds.SetCoins(player, have - cost)
		pds.RequestSavePlayerData(player)
		pad:SetAttribute(ATTR_PURCHASED, true)
		pds.RecordPurchasedPad(player, pad.Name)
		debugPrint("Purchase success, hiding pad: " .. pad.Name)
		HidePad(pad)
		local plotSetup = getPlotSetupService()
		if plotSetup and plotSetup.SpawnMachineForPad then
			plotSetup.SpawnMachineForPad(plot, pad)
		end
		BuyPadService.RefreshPadVisibilityFromSave(plot, player)
	end)
end

local function ensureNotEnoughRemote(): RemoteEvent?
	if notEnoughRemoteForPads then
		return notEnoughRemoteForPads
	end
	local r = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
	if r and r:IsA("RemoteEvent") then
		notEnoughRemoteForPads = r
	end
	return notEnoughRemoteForPads
end

-- חיווט Triggered לפדים שהופיעו אחרי Init (רפליקציה / תוכן נטען מאוחר)
local function ensurePadPromptsWired(plot: Instance)
	local remote = ensureNotEnoughRemote()
	if not remote then
		return
	end
	local pads = getPadsInPlot(plot, true)
	for _, pad in pads do
		if not wiredPadRoots[pad] then
			wiredPadRoots[pad] = true
			setupPad(pad, plot, remote)
		end
	end
end

local function attachBuyPadsHydrationWatch(plot: Instance)
	local container = getBuyPadsContainerForPlot(plot, true)
	if not container then
		return
	end
	if buyPadsWatchAttached[plot] == container then
		return
	end
	buyPadsWatchAttached[plot] = container
	attachBuyPadsRemovalDebug(container, plot)
	local function onBuyPadsTreeChanged()
		task.defer(function()
			if plot.Parent == nil then
				return
			end
			ensurePadPromptsWired(plot)
			local pc = getPlotClaimService()
			local owner = pc and pc.GetPlotOwner(plot)
			if owner then
				BuyPadService.RefreshPadVisibilityFromSave(plot, owner)
				if buyPadRestoreNeedsRetry[plot] and #getPadsInPlot(plot, true) > 0 then
					buyPadRestoreNeedsRetry[plot] = nil
					BuyPadService.RestorePurchasedPadsForPlot(owner, plot)
				end
			end
		end)
	end
	container.DescendantAdded:Connect(onBuyPadsTreeChanged)
	container.ChildAdded:Connect(onBuyPadsTreeChanged)
end

-- כש-BuyPads עדיין ריק בזמן Claim: נסיונות חוזרים עד שיילדים/Prompts מופיעים
local function scheduleBuyPadsHydrationPoll(plot: Instance, player: Player)
	if hydrationPollActive[plot] then
		return
	end
	hydrationPollActive[plot] = true
	task.spawn(function()
		for attempt = 1, 120 do
			if plot.Parent == nil or player.Parent == nil then
				break
			end
			attachBuyPadsHydrationWatch(plot)
			ensureNotEnoughRemote()
			ensurePadPromptsWired(plot)
			BuyPadService.RefreshPadVisibilityFromSave(plot, player)
			local n = #getPadsInPlot(plot, true)
			if n > 0 then
				debugPrint(
					"BuyPads hydrated | plot="
						.. plot.Name
						.. " | padCount="
						.. tostring(n)
						.. " | attempt="
						.. tostring(attempt)
				)
				if buyPadRestoreNeedsRetry[plot] then
					buyPadRestoreNeedsRetry[plot] = nil
					BuyPadService.RestorePurchasedPadsForPlot(player, plot)
				end
				break
			end
			task.wait(0.05)
		end
		if plot.Parent and #getPadsInPlot(plot, true) == 0 then
			warn(
				"[BuyPadService] BuyPads עדיין ריק או בלי ProximityPrompts אחרי ~6s | plot="
					.. plot.Name
					.. " — בדוק שתחת FactoryContent > CopperFactory > BuyPads יש מודלים עם ProximityPrompt."
			)
		end
		hydrationPollActive[plot] = nil
	end)
end

-- אחרי Claim מוצלח – נראות פדים לפי PadGroup / ShowOrder ו-PurchasedPads.
function BuyPadService.RevealBuyPadsForPlot(plot: Instance)
	debugPrint("Claim success, syncing pad visibility for plot: " .. plot.Name)
	local buyPadsFolder = getBuyPadsContainerForPlot(plot)
	if buyPadsFolder then
		debugPrint("BuyPads container: " .. buyPadsFolder.ClassName .. ", children: " .. tostring(#buyPadsFolder:GetChildren()))
	else
		debugPrint("ERROR: BuyPads folder not found")
	end
	local plotClaim = getPlotClaimService()
	local owner = plotClaim and plotClaim.GetPlotOwner(plot)
	if owner then
		attachBuyPadsHydrationWatch(plot)
		ensurePadPromptsWired(plot)
		BuyPadService.RefreshPadVisibilityFromSave(plot, owner)
		local nPads = #getPadsInPlot(plot, true)
		if nPads > 0 and buyPadRestoreNeedsRetry[plot] then
			buyPadRestoreNeedsRetry[plot] = nil
			BuyPadService.RestorePurchasedPadsForPlot(owner, plot)
		elseif nPads == 0 then
			debugPrint("BuyPads ריק בזמן Claim — מפעילים polling + ChildAdded עד שיתמלא התוכן")
			scheduleBuyPadsHydrationPoll(plot, owner)
		end
	else
		local pads = getPadsInPlot(plot, true)
		for _, pad in pads do
			HidePad(pad)
		end
	end
end

function BuyPadService.ShowBuyPadsForPlot(plot: Instance)
	BuyPadService.RevealBuyPadsForPlot(plot)
end

-- משחזר Pads שנרכשו מהשמירה: מסתיר את ה-Pad ומזמן את המכונה (נקרא אחרי Claim / טעינת שרת).
-- תשתית: כל Pad שמופיע ב-PurchasedPads יוסתר ויזומן עבורו Machine – אפשר להוסיף עוד Pads (Mechine3Pad וכו') והם ישמרו אוטומטית.
function BuyPadService.RestorePurchasedPadsForPlot(player: Player, plot: Instance)
	local pds = getPlayerDataService()
	if not pds then
		debugPrint("RestorePurchasedPadsForPlot: pds nil")
		return
	end
	if not pds.GetPurchasedPadsForPlot then
		debugPrint("RestorePurchasedPadsForPlot: GetPurchasedPadsForPlot nil")
		return
	end
	if not pds.IsDataLoaded(player) then
		debugPrint("RestorePurchasedPadsForPlot: IsDataLoaded=false ל-" .. player.Name .. " – נתונים עדיין לא נטענו?")
		return
	end
	local purchased = pds.GetPurchasedPadsForPlot(player, plot.Name)
	local pads = getPadsInPlot(plot)
	local purchasedCount = 0
	for _ in pairs(purchased) do
		purchasedCount = purchasedCount + 1
	end
	debugPrint("RestorePurchasedPadsForPlot: " .. player.Name .. " | Plot " .. plot.Name .. " | PurchasedPads=" .. tostring(purchasedCount) .. " | Pads ב-Plot=" .. tostring(#pads))
	if #pads == 0 then
		buyPadRestoreNeedsRetry[plot] = true
	else
		buyPadRestoreNeedsRetry[plot] = nil
	end
	local plotSetup = getPlotSetupService()
	local restored = {}
	for _, pad in pads do
		if purchased[pad.Name] then
			pad:SetAttribute(ATTR_PURCHASED, true)
			HidePad(pad)
			if plotSetup and plotSetup.SpawnMachineForPad then
				plotSetup.SpawnMachineForPad(plot, pad)
			end
			table.insert(restored, pad.Name)
		end
	end
	if #restored > 0 then
		debugPrint("RestorePurchasedPadsForPlot: שוחזרו " .. tostring(#restored) .. " מכונות ל-Plot " .. plot.Name .. ": " .. table.concat(restored, ", "))
	end
	BuyPadService.RefreshPadVisibilityFromSave(plot, player)
end

-- הסתרת כל ה-Pads של Plot (לפני Claim). רק Hide – אין Destroy.
function BuyPadService.HideBuyPadsForPlot(plot: Instance)
	local pads = getPadsInPlot(plot)
	for _, pad in pads do
		HidePad(pad)
	end
end

-- API חיצוני אם צריך
function BuyPadService.HidePad(pad: Instance)
	HidePad(pad)
end
function BuyPadService.ShowPad(pad: Instance)
	ShowPad(pad)
end

function BuyPadService.Init()
	local plotsFolder = Workspace:WaitForChild("Plots", 10)
	if not plotsFolder then
		warn("[BuyPad Debug] ERROR: Workspace.Plots not found.")
		return
	end

	local notEnoughRemote = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
	if not notEnoughRemote or not notEnoughRemote:IsA("RemoteEvent") then
		notEnoughRemote = Instance.new("RemoteEvent")
		notEnoughRemote.Name = REMOTE_NAME
		notEnoughRemote.Parent = ReplicatedStorage
	end

	local plotClaim = getPlotClaimService()
	if not plotClaim then
		warn("[BuyPad Debug] ERROR: PlotClaimService not found.")
		return
	end

	notEnoughRemoteForPads = notEnoughRemote
	local pds = getPlayerDataService()
	for _, plot in plotsFolder:GetChildren() do
		if not (plot:IsA("Model") or plot:IsA("BasePart")) then
			continue
		end
		attachBuyPadsHydrationWatch(plot)
		local pads = getPadsInPlot(plot)
		for _, pad in pads do
			if not wiredPadRoots[pad] then
				wiredPadRoots[pad] = true
				setupPad(pad, plot, notEnoughRemote)
			end
		end
		local owner = plotClaim.GetPlotOwner(plot)
		if owner and pds and pds.IsDataLoaded(owner) then
			BuyPadService.RefreshPadVisibilityFromSave(plot, owner)
		else
			BuyPadService.HideBuyPadsForPlot(plot)
		end
	end
end

return BuyPadService
