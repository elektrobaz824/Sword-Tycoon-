--[[
	SellZoneService - מכירת Copper ב-SellZone
	Server-side only. Part בשם SellZone בתוך כל Plot – נוגע ב-Copper → Coins לבעלים, הסתרת Copper (ללא Destroy).
]]

local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local SellZoneService = {}

local SELL_ZONE_PART_NAME = "SellZone"
local COPPER_NAME = "Copper"
local DROPPED_MATERIALS_FOLDER = "DroppedMaterials"
local COPPER_SELL_VALUE = 10 -- ברירת מחדל אם אין Attribute ולא AdminConfig
local SELL_VALUE_ATTRIBUTE = "SellValue"
local SOLD_ATTRIBUTE = "IsSelling"

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

-- הדפסות debug – להגדיר ל-false אחרי שאין צורך
local DEBUG = true
local function debugPrint(step: string, detail: string?)
	if DEBUG then
		print("[SellZone " .. step .. "]" .. (detail and (" " .. detail) or ""))
	end
end

local sellZonesConnected: { [Instance]: boolean } = {}

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

-- מסתיר instance (Part או Model) – Transparency 1, CanCollide/CanTouch false. בלי Destroy.
local function hideInstance(inst: Instance)
	if inst:IsA("BasePart") then
		inst.Transparency = 1
		inst.CanCollide = false
		inst.CanTouch = false
		return
	end
	if inst:IsA("Model") then
		for _, desc in inst:GetDescendants() do
			if desc:IsA("BasePart") then
				desc.Transparency = 1
				desc.CanCollide = false
				desc.CanTouch = false
			end
		end
		return
	end
end

-- מחזיר את ה-instance של Copper: Part בשם Copper (לא רגיש לאותיות), או Model בשם Copper שמכיל את ה-hit
local function getCopperInstance(hit: BasePart): Instance?
	if not hit or not hit:IsA("BasePart") then
		return nil
	end
	-- Part בשם Copper (תמיכה ב-Copper / copper / COPPER)
	if hit.Name and (hit.Name :: string):lower() == (COPPER_NAME :: string):lower() then
		return hit
	end
	-- חלק פנימי של Model בשם Copper
	local model = hit:FindFirstAncestorOfClass("Model")
	if model and model.Name and (model.Name :: string):lower() == (COPPER_NAME :: string):lower() then
		return model
	end
	return nil
end

-- מחזיר את ה-Plot שאליו שייך ה-SellZone (גם אם SellZone בתוך תיקייה בתוך ה-Plot)
local function getPlotFromSellZone(sellZonePart: Instance): Instance?
	local plotsFolder = Workspace:FindFirstChild("Plots")
	if not plotsFolder then
		return nil
	end
	local current = sellZonePart.Parent
	while current and current ~= Workspace do
		if current.Parent == plotsFolder then
			return current
		end
		current = current.Parent
	end
	return nil
end

-- חיפוש descendant לפי שם (בלי FindFirstDescendant – לא זמין בכל הגרסאות)
local function findDescendantByName(parent: Instance, name: string): Instance?
	for _, desc in parent:GetDescendants() do
		if desc.Name == name then
			return desc
		end
	end
	return nil
end

local function onSellZoneTouched(sellZonePart: BasePart, hit: BasePart)
	debugPrint("1_Touched", "נגיעה: " .. (hit and hit:GetFullName() or "nil") .. " | שם: " .. (hit and hit.Name or "?"))

	if not hit or not hit:IsA("BasePart") then
		debugPrint("1_FAIL", "hit לא BasePart")
		return
	end
	if hit == sellZonePart then
		debugPrint("1_SKIP", "נגיעה עצמית ב-SellZone")
		return
	end

	local copperInstance = getCopperInstance(hit)
	if not copperInstance then
		debugPrint("2_FAIL", "לא Copper – hit.Name=" .. tostring(hit.Name))
		return
	end
	if not copperInstance.Parent then
		debugPrint("2_FAIL", "Copper בלי Parent")
		return
	end
	if copperInstance:GetAttribute(SOLD_ATTRIBUTE) then
		debugPrint("3_SKIP", "Copper כבר נמכר (IsSelling)")
		return
	end

	local plot = getPlotFromSellZone(sellZonePart)
	if not plot then
		debugPrint("4_FAIL", "לא נמצא Plot ל-SellZone")
		return
	end
	debugPrint("4_OK", "Plot: " .. plot.Name)

	local droppedMaterials = plot:FindFirstChild(DROPPED_MATERIALS_FOLDER)
	if not droppedMaterials or not droppedMaterials:IsA("Folder") then
		debugPrint("5_FAIL", "אין DroppedMaterials ב-Plot")
		return
	end
	-- Copper חייב להיות ילד ישיר של DroppedMaterials של *אותו* Plot
	if copperInstance.Parent ~= droppedMaterials then
		debugPrint("5_FAIL", "Copper לא ב-DroppedMaterials של Plot זה (Parent=" .. tostring(copperInstance.Parent and copperInstance.Parent.Name) .. ")")
		return
	end

	local plotClaim = getPlotClaimService()
	local pds = getPlayerDataService()
	if not plotClaim or not pds then
		debugPrint("6_FAIL", "שירותים לא נטענו")
		return
	end

	local owner = plotClaim.GetPlotOwner(plot)
	if not owner or not owner:IsA("Player") or not owner.Parent then
		debugPrint("7_FAIL", "אין בעלים ל-Plot")
		return
	end
	debugPrint("7_OK", "בעלים: " .. owner.Name)

	if not pds.IsDataLoaded(owner) then
		debugPrint("8_FAIL", "נתוני שחקן לא נטענו")
		return
	end

	local data = pds.GetPlayerData(owner)
	if not data then
		debugPrint("8_FAIL", "אין data לשחקן")
		return
	end

	-- הגנה מפני מכירה כפולה – סימון לפני עדכון Coins
	copperInstance:SetAttribute(SOLD_ATTRIBUTE, true)

	local sellValue = copperInstance:GetAttribute(SELL_VALUE_ATTRIBUTE)
	if type(sellValue) ~= "number" or sellValue < 0 then
		local admin = getAdminConfigService()
		if admin and admin.GetValue then
			local cv, ok = admin.GetValue("Materials.Copper.SellValue")
			if ok and type(cv) == "number" and cv >= 0 then
				sellValue = cv
			else
				sellValue = COPPER_SELL_VALUE
			end
		else
			sellValue = COPPER_SELL_VALUE
		end
	end
	local newCoins = data.Coins + sellValue
	pds.SetCoins(owner, newCoins)
	pds.RequestSavePlayerData(owner)
	debugPrint("9_SOLD", owner.Name .. " קיבל " .. tostring(sellValue) .. " Coins, סה\"כ " .. tostring(newCoins))

	hideInstance(copperInstance)
	debugPrint("10_DONE", "Copper הוסתר")
end

local function setupSellZone(plot: Instance)
	local sellZone = plot:FindFirstChild(SELL_ZONE_PART_NAME) or findDescendantByName(plot, SELL_ZONE_PART_NAME)
	if not sellZone or not sellZone:IsA("BasePart") then
		if DEBUG then
			debugPrint("setup", "ב-Plot " .. plot.Name .. " לא נמצא Part בשם " .. SELL_ZONE_PART_NAME)
		end
		return
	end
	if sellZonesConnected[sellZone] then
		return
	end
	sellZonesConnected[sellZone] = true
	sellZone.CanTouch = true
	sellZone.Touched:Connect(function(hit: BasePart)
		onSellZoneTouched(sellZone, hit)
	end)
	if DEBUG then
		debugPrint("setup", "SellZone מחובר ב-Plot " .. plot.Name)
	end
end

function SellZoneService.Init()
	local plotsFolder = Workspace:WaitForChild("Plots", 10)
	if not plotsFolder then
		warn("[SellZoneService] Workspace.Plots לא נמצא.")
		return
	end

	local count = 0
	for _, plot in plotsFolder:GetChildren() do
		if plot:IsA("Model") or plot:IsA("BasePart") then
			setupSellZone(plot)
			count = count + 1
		end
	end
	if DEBUG then
		debugPrint("Init", "נסרקו " .. tostring(count) .. " Plot(s)")
	end

	plotsFolder.ChildAdded:Connect(function(plot)
		if plot:IsA("Model") or plot:IsA("BasePart") then
			setupSellZone(plot)
		end
	end)
end

return SellZoneService
