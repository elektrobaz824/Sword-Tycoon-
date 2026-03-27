--[[
	PlotSetupService - מבנה Plot, מכונה ראשונה, ייצור Copper
	Server-side only. נקרא אחרי Claim מוצלח ומשחזר Plot אחרי טעינת שרת.
	מכונות: רק מודלים שמורים בפלוט (MechineN/MachineN) — ללא Clone מ-ReplicatedStorage.
	ייצור Copper עדיין משתמש ב-ReplicatedStorage.template.Copper (אם קיים).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local PlotSetupService = {}

-- שמות קבועים – לא לשנות שמות קיימים
local FOLDER_MACHINES = "Machines"
-- שם חלופי נפוץ ב-Studio (כמו ב-Explorer שלך): Mechines + Machine2
local FOLDER_MECHINES_ALT = "Mechines"
local FOLDER_DROPPED_MATERIALS = "DroppedMaterials"

local function isMachinesContainer(inst: Instance?): boolean
	return inst ~= nil and (inst:IsA("Folder") or inst:IsA("Model"))
end
local FOLDER_BUY_PADS = "BuyPads"
local FOLDER_BUILDINGS = "Buildings"
local VALUES_FOLDER_NAME = "Values"
local ACTIVE_FACTORY_TYPE_VALUE_NAME = "ActiveFactoryType"
local FACTORY_CONTENT_FOLDER_NAME = "FactoryContent"
-- בלי Values.ActiveFactoryType — עדיין מזהים מפעל נחושת אם קיים תחת FactoryContent
local DEFAULT_FACTORY_MODEL_NAME = "CopperFactory"
local TEMPLATE_MACHINE_NAME = "Machine"
local TEMPLATE_COPPER_NAME = "Copper"
local SPAWN_POINT_NAME = "SpawnPoint"
local FIRST_MACHINE_SPAWN_NAME = "FirstMachineSpawn"
-- Part שממקדים לפיו את המכונה על ה-Spawn וה-Pads: קודם Plane, אם אין אז Buttom
local PLACEMENT_PART_NAME = "Plane"
local BOTTOM_PART_NAME = "Buttom"

local COPPER_PRODUCTION_INTERVAL = 5 -- ברירת מחדל אם אין קונפיג

local templateFolder: Folder? = nil
local activeProductionMachines: { [Instance]: boolean } = {}

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

local function getTemplateFolder(): Folder?
	if templateFolder then
		return templateFolder
	end
	templateFolder = ReplicatedStorage:WaitForChild("template", 10) :: Folder?
	return templateFolder
end

local function getBuyPadService()
	for _, desc in ServerScriptService:GetDescendants() do
		if desc:IsA("ModuleScript") and desc.Name == "BuyPadService" then
			return require(desc)
		end
	end
	return nil
end

local function getPlayerDataService()
	for _, desc in ServerScriptService:GetDescendants() do
		if desc:IsA("ModuleScript") and desc.Name == "PlayerDataService" then
			return require(desc)
		end
	end
	return nil
end

-- מפעל עתידי: plot.Values.ActiveFactoryType = "Copper" → plot.FactoryContent.CopperFactory > Machines / Buildings / BuyPads
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

local function getFactoryContentFolder(plot: Instance): Instance?
	return plot:FindFirstChild(FACTORY_CONTENT_FOLDER_NAME)
end

local function getActiveFactoryModel(plot: Instance): Instance?
	local t = getActiveFactoryType(plot)
	if not t then
		return nil
	end
	local fc = getFactoryContentFolder(plot)
	if not fc then
		return nil
	end
	local modelName = t .. "Factory"
	local m = fc:FindFirstChild(modelName)
	if m and (m:IsA("Model") or m:IsA("Folder")) then
		return m
	end
	return nil
end

-- מפעל לשימוש במכונות/מבנה: קודם לפי Values, אחרת CopperFactory תחת FactoryContent (בלי חובה על StringValue).
local function getResolvedFactoryModel(plot: Instance): Instance?
	local m = getActiveFactoryModel(plot)
	if m then
		return m
	end
	local fc = getFactoryContentFolder(plot)
	if not fc then
		return nil
	end
	local defaultF = fc:FindFirstChild(DEFAULT_FACTORY_MODEL_NAME)
	if defaultF and (defaultF:IsA("Model") or defaultF:IsA("Folder")) then
		return defaultF
	end
	return nil
end

-- דיבאג מבנה פלוט/מפעל: לפני Play (שרת): _G.SwordTycoonDebugPlotStructure = true
-- או מהקומנד: require(game.ServerScriptService.Server.PlotSetupService).DebugPlotStructureSnapshot(workspace.Plots.Plot1, "manual")
local function plotStructureDebugEnabled(): boolean
	return _G.SwordTycoonDebugPlotStructure == true
end

local function countProximityPromptsUnder(inst: Instance): number
	local n = 0
	for _, d in inst:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			n += 1
		end
	end
	return n
end

local function debugPlotStructureSnapshot(label: string, plot: Instance, force: boolean?)
	if not force and not plotStructureDebugEnabled() then
		return
	end
	local plotPath = select(2, pcall(function()
		return plot:GetFullName()
	end))
	if type(plotPath) ~= "string" then
		plotPath = tostring(plot)
	end
	print("======== [PlotStructureDebug] " .. label .. " ========")
	print("[PlotStructureDebug] Context: Server Script (PlotSetupService module) | RunService:IsServer()=" .. tostring(RunService:IsServer()))
	print("[PlotStructureDebug] plot ref | " .. plotPath .. " | ClassName=" .. plot.ClassName)

	local plotsFolder = game.Workspace:FindFirstChild("Plots")
	if plotsFolder then
		local pk = plotsFolder:GetChildren()
		print("[PlotStructureDebug] Workspace.Plots | directChildCount=" .. tostring(#pk))
		for _, ch in pk do
			print("    ... | " .. ch:GetFullName() .. " | " .. ch.ClassName)
		end
	else
		warn("[PlotStructureDebug] Workspace.Plots is MISSING")
	end

	local fc = getFactoryContentFolder(plot)
	print("[PlotStructureDebug] FactoryContent (FindFirstChild on plot) | " .. (fc and fc:GetFullName() or "nil"))

	local fac = getResolvedFactoryModel(plot)
	print("[PlotStructureDebug] getResolvedFactoryModel | " .. (fac and fac:GetFullName() or "nil"))

	local watchNames = {
		FACTORY_CONTENT_FOLDER_NAME,
		DEFAULT_FACTORY_MODEL_NAME,
		FOLDER_BUY_PADS,
		FOLDER_MACHINES,
		FOLDER_MECHINES_ALT,
	}
	for _, nm in ipairs(watchNames) do
		local total = 0
		for _, d in plot:GetDescendants() do
			if d.Name == nm then
				total += 1
				local extra = ""
				if nm == FOLDER_BUY_PADS and (d:IsA("Folder") or d:IsA("Model")) then
					extra = " | children=" .. tostring(#d:GetChildren()) .. " | promptsUnder=" .. tostring(countProximityPromptsUnder(d))
				elseif d:IsA("Folder") or d:IsA("Model") then
					extra = " | children=" .. tostring(#d:GetChildren())
				end
				print("[PlotStructureDebug]   under-plot name match | " .. d:GetFullName() .. " | " .. d.ClassName .. extra)
			end
		end
		print("[PlotStructureDebug] name='" .. nm .. "' | descendantMatchCountUnderPlot=" .. tostring(total))
	end

	if fac then
		local dm = fac:FindFirstChild(FOLDER_MACHINES)
		local dme = fac:FindFirstChild(FOLDER_MECHINES_ALT)
		local dbp = fac:FindFirstChild(FOLDER_BUY_PADS)
		print(
			"[PlotStructureDebug] direct under resolved factory | Machines="
				.. (dm and dm:GetFullName() or "nil")
				.. " | Mechines="
				.. (dme and dme:GetFullName() or "nil")
				.. " | BuyPads="
				.. (dbp and dbp:GetFullName() or "nil")
		)
		local picked = pickMachinesUnderParent(fac)
		print("[PlotStructureDebug] pickMachinesUnderParent(factory) | " .. (picked and picked:GetFullName() or "nil"))
		if dbp and (dbp:IsA("Folder") or dbp:IsA("Model")) then
			print(
				"[PlotStructureDebug] canonical BuyPads children="
					.. tostring(#dbp:GetChildren())
					.. " promptsUnder="
					.. tostring(countProximityPromptsUnder(dbp))
			)
		end
	end

	print("======== [PlotStructureDebug] END " .. label .. " ========")
end

local function pickMachinesUnderParent(parent: Instance): Instance?
	local best: Instance? = nil
	local bestCount = -1
	for _, folderName in { FOLDER_MACHINES, FOLDER_MECHINES_ALT } do
		local c = parent:FindFirstChild(folderName)
		if isMachinesContainer(c) then
			local n = #(c :: Instance):GetChildren()
			if n > bestCount then
				bestCount = n
				best = c
			end
		end
	end
	return best
end

local function getFactoryMachinesContainer(plot: Instance): Instance?
	local f = getResolvedFactoryModel(plot)
	if not f then
		return nil
	end
	return pickMachinesUnderParent(f)
end

local function getFactoryBuildingsContainer(plot: Instance): Instance?
	local f = getResolvedFactoryModel(plot)
	if not f then
		return nil
	end
	local b = f:FindFirstChild(FOLDER_BUILDINGS)
	if b and (b:IsA("Folder") or b:IsA("Model")) then
		return b
	end
	return nil
end

local function getFactoryBuyPadsContainer(plot: Instance): Instance?
	local f = getResolvedFactoryModel(plot)
	if not f then
		return nil
	end
	local bp = f:FindFirstChild(FOLDER_BUY_PADS)
	if bp and (bp:IsA("Folder") or bp:IsA("Model")) then
		return bp
	end
	return nil
end

local function collectAllMachinesContainers(plot: Instance): { Instance }
	local seen: { [Instance]: boolean } = {}
	local list: { Instance } = {}
	local function add(c: Instance?)
		if c and isMachinesContainer(c) and not seen[c] then
			seen[c] = true
			table.insert(list, c)
		end
	end
	local f = getActiveFactoryModel(plot)
	if f then
		for _, folderName in { FOLDER_MACHINES, FOLDER_MECHINES_ALT } do
			add(f:FindFirstChild(folderName))
		end
	end
	-- כל מפעל ישירות תחת FactoryContent (למשל CopperFactory > Machines) גם בלי ActiveFactoryType
	local fc = getFactoryContentFolder(plot)
	if fc then
		for _, sub in fc:GetChildren() do
			if sub:IsA("Model") or sub:IsA("Folder") then
				add(pickMachinesUnderParent(sub))
			end
		end
	end
	for _, folderName in { FOLDER_MACHINES, FOLDER_MECHINES_ALT } do
		add(plot:FindFirstChild(folderName))
	end
	return list
end

-- מכונות ל-parent חדש: קודם תחת מפעל פעיל, אחרת שורש הפלוט. הדפסות לדיבוג מסלול מפעל מול שורש.
local function getPlotMachinesContainer(plot: Instance, context: string?): Instance?
	local ctx = context or "plot"
	local factoryModel = getResolvedFactoryModel(plot)
	local facM = factoryModel and pickMachinesUnderParent(factoryModel) or nil
	if facM then
		print(
			"[PlotSetupService] ["
				.. ctx
				.. "] Using factory Machines container ("
				.. factoryModel.Name
				.. ") on plot "
				.. plot.Name
				.. "."
		)
		return facM
	end
	local rootM = pickMachinesUnderParent(plot)
	if rootM and factoryModel then
		warn(
			"[PlotSetupService] ["
				.. ctx
				.. "] Active factory "
				.. factoryModel.Name
				.. " has no Machines/Mechines — root-level fallback on plot "
				.. plot.Name
				.. "."
		)
	end
	return rootM
end

local function machineParentIsPlotMachinesContainer(machine: Instance, plot: Instance): boolean
	local p = machine.Parent
	if not p then
		return false
	end
	for _, c in collectAllMachinesContainers(plot) do
		if p == c then
			return true
		end
	end
	return false
end

local function findFirstMachineSpawnPart(plot: Instance): BasePart?
	local fac = getResolvedFactoryModel(plot)
	if fac then
		local deep = fac:FindFirstChild(FIRST_MACHINE_SPAWN_NAME, true)
		if deep and deep:IsA("BasePart") then
			return deep
		end
	end
	local root = plot:FindFirstChild(FIRST_MACHINE_SPAWN_NAME)
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function ensureFolder(parent: Instance, name: string): Folder
	local folder = parent:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		if plotStructureDebugEnabled() then
			print("[PlotStructureDebug] REUSED Folder (already exists) | " .. folder:GetFullName())
		end
		return folder
	end
	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	if plotStructureDebugEnabled() then
		warn(
			"[PlotStructureDebug] CREATED Folder via Instance.new | "
				.. folder:GetFullName()
				.. " | parent="
				.. parent:GetFullName()
				.. " — only expected for DroppedMaterials on plot root, not for BuyPads/Machines."
		)
	end
	return folder
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

-- משלים רק DroppedMaterials בשרשור הפלוט. תיקיית מכונות (Machines / Mechines) חייבת להיות ב-Studio — לא יוצרים אותה בקוד (מניעת Package resync / קונפליקט עם preplaced).
-- BuyPads / FactoryContent / CopperFactory: לא נוגעים.
local function ensurePlotStructure(plot: Instance)
	if plotStructureDebugEnabled() then
		debugPlotStructureSnapshot("ensurePlotStructure BEFORE", plot)
	end
	local fac = getResolvedFactoryModel(plot)
	local machinesRoot: Instance = fac or plot

	local machinesOk = pickMachinesUnderParent(machinesRoot)
	if not machinesOk then
		local blockMachines = machinesRoot:FindFirstChild(FOLDER_MACHINES)
		local blockMechines = machinesRoot:FindFirstChild(FOLDER_MECHINES_ALT)
		local blocker = blockMachines or blockMechines
		if blocker and not isMachinesContainer(blocker) then
			warn(
				"[PlotSetupService] ensurePlotStructure: "
					.. machinesRoot:GetFullName()
					.. " has "
					.. blocker.Name
					.. " ("
					.. blocker.ClassName
					.. ") but Machines/Mechines must be a Folder or Model — fix in Studio; not auto-creating a container."
			)
		else
			warn(
				"[PlotSetupService] ensurePlotStructure: no Folder/Model named Machines or Mechines under "
					.. machinesRoot:GetFullName()
					.. " — add preplaced container in Studio; not auto-creating."
			)
		end
	end

	if fac then
		local m = pickMachinesUnderParent(fac)
		print(
			"[PlotSetupService] [ensurePlotStructure] plot="
				.. plot.Name
				.. " factory="
				.. fac.Name
				.. " | Machines/Mechines="
				.. (m and m:GetFullName() or "(none — expected preplaced Folder or Model)")
		)
	end
	ensureFolder(plot, FOLDER_DROPPED_MATERIALS)
	-- לא קוראים ל-ensureFolder(plot, FOLDER_BUY_PADS) – BuyPads נשאר כפי שסופק מ-Studio.
	if plotStructureDebugEnabled() then
		debugPlotStructureSnapshot("ensurePlotStructure AFTER", plot)
	end
end

local function getSpawnPoint(machine: Instance): BasePart?
	local sp = machine:FindFirstChild(SPAWN_POINT_NAME)
	if sp and sp:IsA("BasePart") then
		return sp
	end
	sp = findDescendantByName(machine, SPAWN_POINT_NAME)
	if sp and sp:IsA("BasePart") then
		return sp
	end
	return nil
end

local function placeInstanceAt(copy: Instance, cframe: CFrame)
	if copy:IsA("Model") then
		copy:PivotTo(cframe)
	elseif copy:IsA("BasePart") then
		copy.CFrame = cframe
	end
end

-- מחזיר את ה-Part שממקדים לפיו את המכונה על Spawn/Pad: קודם Plane, אם אין אז Buttom
local function getPlacementPart(machine: Instance): BasePart?
	local part = machine:FindFirstChild(PLACEMENT_PART_NAME)
	if part and part:IsA("BasePart") then
		return part
	end
	part = findDescendantByName(machine, PLACEMENT_PART_NAME)
	if part and part:IsA("BasePart") then
		return part
	end
	part = machine:FindFirstChild(BOTTOM_PART_NAME)
	if part and part:IsA("BasePart") then
		return part
	end
	part = findDescendantByName(machine, BOTTOM_PART_NAME)
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end

-- מחזיר את ה-Part התחתון של המכונה (שם Buttom) – ילד או descendant (לשימוש אחר במידת צורך)
local function getBottomPart(machine: Instance): BasePart?
	local bottom = machine:FindFirstChild(BOTTOM_PART_NAME)
	if bottom and bottom:IsA("BasePart") then
		return bottom
	end
	bottom = findDescendantByName(machine, BOTTOM_PART_NAME)
	if bottom and bottom:IsA("BasePart") then
		return bottom
	end
	return nil
end

-- ממקם את המכונה כך שה-Plane (או Buttom) יישב בדיוק על גבי FirstMachineSpawn.
local function placeMachineOnSpawn(machine: Instance, template: Instance, firstSpawn: BasePart)
	local placementPart = getPlacementPart(template)
	if not placementPart then
		placeInstanceAt(machine, firstSpawn.CFrame)
		return
	end
	local ok, err = pcall(function()
		local pivotCf: CFrame = template:IsA("Model") and template:GetPivot() or template.CFrame
		local offsetLocal = pivotCf:PointToObjectSpace(placementPart.Position)
		local spawnTop = firstSpawn.CFrame * CFrame.new(0, firstSpawn.Size.Y/2, 0)
		local targetCenter = spawnTop * CFrame.new(0, placementPart.Size.Y/2, 0)
		local targetPos = targetCenter.Position
		local rotationOnly = firstSpawn.CFrame - firstSpawn.CFrame.Position
		local offsetWorld = rotationOnly:PointToWorldSpace(offsetLocal)
		local newPivotPos = targetPos - offsetWorld
		machine:PivotTo(CFrame.new(newPivotPos) * rotationOnly)
	end)
	if not ok then
		warn("[PlotSetupService] מיקום לפי " .. PLACEMENT_PART_NAME .. "/Buttom נכשל, מציב במרכז FirstMachineSpawn:", err)
		placeInstanceAt(machine, firstSpawn.CFrame)
	end
end

-- ממקם את המכונה על Pad – ה-Plane (או Buttom) יישב על פני השטח העליונים של ה-Pad.
local function placeMachineOnPad(machine: Instance, template: Instance, padPart: BasePart)
	local placementPart = getPlacementPart(template)
	if not placementPart then
		placeInstanceAt(machine, padPart.CFrame)
		return
	end
	local ok, err = pcall(function()
		local pivotCf: CFrame = template:IsA("Model") and template:GetPivot() or template.CFrame
		local offsetLocal = pivotCf:PointToObjectSpace(placementPart.Position)
		local padTop = padPart.CFrame * CFrame.new(0, padPart.Size.Y / 2, 0)
		local targetCenter = padTop * CFrame.new(0, placementPart.Size.Y / 2, 0)
		local targetPos = targetCenter.Position
		local rotationOnly = padPart.CFrame - padPart.CFrame.Position
		local offsetWorld = rotationOnly:PointToWorldSpace(offsetLocal)
		local newPivotPos = targetPos - offsetWorld
		machine:PivotTo(CFrame.new(newPivotPos) * rotationOnly)
	end)
	if not ok then
		warn("[PlotSetupService] מיקום לפי " .. PLACEMENT_PART_NAME .. "/Buttom על Pad נכשל, מציב במרכז ה-Pad:", err)
		placeInstanceAt(machine, padPart.CFrame)
	end
end

-- מפעיל לופ ייצור Copper למכונה אחת. sellValue = Coins במכירה, spawnIntervalSec = שניות בין ייצור לייצור.
local COPPER_SELL_VALUE_ATTR = "SellValue"
local function startCopperProduction(machine: Instance, plot: Instance, sellValue: number?, spawnIntervalSec: number?)
	if activeProductionMachines[machine] then
		return
	end
	activeProductionMachines[machine] = true
	local value = (type(sellValue) == "number" and sellValue >= 0) and sellValue or 10
	local interval = (type(spawnIntervalSec) == "number" and spawnIntervalSec > 0) and spawnIntervalSec or COPPER_PRODUCTION_INTERVAL

	local template = getTemplateFolder()
	if not template then
		activeProductionMachines[machine] = nil
		return
	end
	local copperTemplate = template:FindFirstChild(TEMPLATE_COPPER_NAME) or findDescendantByName(template, TEMPLATE_COPPER_NAME)
	if not copperTemplate or not (copperTemplate:IsA("BasePart") or copperTemplate:IsA("Model")) then
		warn("[PlotSetupService] template.Copper לא נמצא ב-ReplicatedStorage.template (חייב Part או Model בשם Copper).")
		activeProductionMachines[machine] = nil
		return
	end

	local droppedFolder = plot:FindFirstChild(FOLDER_DROPPED_MATERIALS)
	if not droppedFolder or not droppedFolder:IsA("Folder") then
		activeProductionMachines[machine] = nil
		return
	end

	task.spawn(function()
		while machine.Parent and machineParentIsPlotMachinesContainer(machine, plot) do
			task.wait(interval)
			if not machine.Parent then
				break
			end
			local spawnPoint = getSpawnPoint(machine)
			if not spawnPoint then
				continue
			end
			local copper = copperTemplate:Clone()
			copper:SetAttribute(COPPER_SELL_VALUE_ATTR, value)
			-- Part עם Mesh: קודם Parent לעולם, אחר כך מיקום במסגרת הבאה – כך ה-Mesh מתאתחל נכון
			local targetCf = spawnPoint.CFrame
			copper.Parent = droppedFolder
			task.defer(function()
				if copper.Parent then
					placeInstanceAt(copper, targetCf)
				end
			end)
		end
		activeProductionMachines[machine] = nil
	end)
end

-- מחזיר SpawnInterval ו-SellValue מהקונפיג (AdminConfig) לפי מספר מכונה – שליטה מלאה מכל השרתים.
local function getConfigForMachine(machineNum: number): (number, number)
	local admin = getAdminConfigService()
	local pathBase = "Machines.Mechine" .. tostring(machineNum)
	local interval = COPPER_PRODUCTION_INTERVAL
	local sellVal = 10 + (machineNum - 1) * 20
	if admin and admin.GetValue then
		local iv, okIv = admin.GetValue(pathBase .. ".SpawnInterval")
		local sv, okSv = admin.GetValue(pathBase .. ".SellValue")
		if okIv and type(iv) == "number" and iv > 0 then
			interval = iv
		end
		if okSv and type(sv) == "number" and sv >= 0 then
			sellVal = sv
		end
	end
	return interval, sellVal
end

-- מזמן מכונה אחרי קניית Pad (למשל Mechine2Pad). משתמש באותו template כמו המכונה הראשונה (Machine).
local function getMachineNumberFromPadName(padName: string): number?
	local num = (padName :: string):match("Mechine(%d+)Pad") or (padName :: string):match("Machine(%d+)Pad")
	return num and tonumber(num) or nil
end

local FOLDER_HOUSE = "House"
local PAD_GROUP_BUILDINGS = "Buildings"

-- דיבאג: ב-Command Bar (שרת) הרץ: _G.SwordTycoonDebugHousePads = true
-- העתק מ-Output את כל השורות עם הקידומת [HouseSectionPadDebug] ושלח לדיבוג.
local function debugHouseSectionPad(msg: string)
	if _G.SwordTycoonDebugHousePads == true then
		print("[HouseSectionPadDebug] " .. msg)
	end
end

local function isHouseSectionPadName(padName: string): boolean
	return tonumber((padName :: string):match("^HouseSection(%d+)Pad$")) ~= nil
end

local function findPreplacedHouseRoot(plot: Instance): Instance?
	local b = getFactoryBuildingsContainer(plot)
	if not b then
		return nil
	end
	local h = b:FindFirstChild(FOLDER_HOUSE)
	if h and (h:IsA("Model") or h:IsA("Folder")) then
		return h
	end
	return nil
end

local function setHouseSectionHidden(sectionRoot: Instance, hidden: boolean)
	local function applyPart(p: BasePart)
		if hidden then
			p.Transparency = 1
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
		else
			p.Transparency = 0
			p.CanCollide = true
			p.CanTouch = true
			p.CanQuery = true
		end
	end
	for _, d in sectionRoot:GetDescendants() do
		if d:IsA("BasePart") then
			applyPart(d)
		end
	end
	if sectionRoot:IsA("BasePart") then
		applyPart(sectionRoot)
	end
end

-- מקטעי בית (SectionN): גלויים רק כשכל פדי Buildings עם ShowOrder=N נרכשו. נראות הפדים — ב-BuyPadService.RefreshPadVisibilityFromSave.
function PlotSetupService.ApplyHouseBuyProgression(plot: Instance, player: Player)
	local pds = getPlayerDataService()
	local buyPad = getBuyPadService()
	if not pds or not buyPad or not buyPad.GetPadGroup or not buyPad.GetPadShowOrder or not buyPad.GetBuyPadRootsInPlot then
		debugHouseSectionPad("ApplyHouseBuyProgression: missing pds or buyPad API | plot=" .. plot.Name)
		return
	end
	local purchased = pds.GetPurchasedPads(player)
	local function isPadMarkedPurchased(pad: Instance): boolean
		if pad:GetAttribute("Purchased") then
			return true
		end
		if purchased[pad.Name] then
			return true
		end
		return false
	end
	local pads = buyPad.GetBuyPadRootsInPlot(plot)
	local function buildingsStageFullyPurchased(order: number): boolean
		local found = false
		for _, p in pads do
			if buyPad.GetPadGroup(p) == PAD_GROUP_BUILDINGS and buyPad.GetPadShowOrder(p) == order then
				found = true
				if not isPadMarkedPurchased(p) then
					return false
				end
			end
		end
		return found
	end
	local houseRoot = findPreplacedHouseRoot(plot)
	debugHouseSectionPad(
		"ApplyHouseBuyProgression | plot="
			.. plot.Name
			.. " | houseRoot="
			.. (houseRoot and houseRoot:GetFullName() or "nil")
	)
	if not houseRoot then
		return
	end
	for _, child in houseRoot:GetChildren() do
		local ord = tonumber((child.Name :: string):match("^Section(%d+)$"))
		if ord then
			local visible = buildingsStageFullyPurchased(ord)
			setHouseSectionHidden(child, not visible)
			debugHouseSectionPad("Section " .. child.Name .. " | visible=" .. tostring(visible))
		end
	end
end

-- שמות אפשריים ב-Studio: Mechine3 / Machine3 וכו'
local function preplacedMachineNameVariants(machineNum: number): { string }
	local n = tostring(machineNum)
	return { "Mechine" .. n, "Machine" .. n }
end

local function findPreplacedMachineInContainer(container: Instance, machineNum: number): Instance?
	for _, modelName in preplacedMachineNameVariants(machineNum) do
		local direct = container:FindFirstChild(modelName)
		if direct and (direct:IsA("Model") or direct:IsA("BasePart")) then
			return direct
		end
	end
	for _, modelName in preplacedMachineNameVariants(machineNum) do
		local deep = container:FindFirstChild(modelName, true)
		if deep and (deep:IsA("Model") or deep:IsA("BasePart")) then
			return deep
		end
	end
	return nil
end

local function findPreplacedMachineInPlot(plot: Instance, machineNum: number): Instance?
	for _, cont in collectAllMachinesContainers(plot) do
		local found = findPreplacedMachineInContainer(cont, machineNum)
		if found then
			return found
		end
	end
	return nil
end

-- Pre-placed machine in Studio (hidden until pad purchased): show all parts + optional ProximityPrompts.
local function revealPreplacedMachine(machineRoot: Instance)
	for _, d in machineRoot:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 0
			d.CanCollide = true
			d.CanTouch = true
		elseif d:IsA("ProximityPrompt") then
			d.Enabled = true
		end
	end
	if machineRoot:IsA("BasePart") then
		machineRoot.Transparency = 0
		machineRoot.CanCollide = true
		machineRoot.CanTouch = true
	end
end

-- Hidden setup uses Transparency=1 on all BaseParts; revealed if any BasePart is not fully hidden.
local function isPreplacedMachineRevealed(machineRoot: Instance): boolean
	if machineRoot:IsA("BasePart") then
		return machineRoot.Transparency < 0.99
	end
	for _, d in machineRoot:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.99 then
			return true
		end
	end
	return false
end

-- מכונה ראשונה: קודם Mechine1/Machine1 מוכן בפלוט; אחרת ילד בשם Machine שכבר ב-Machines; בלי Clone מ-RS.
local function ensureFirstMachine(plot: Instance)
	local machinesFolder = getPlotMachinesContainer(plot, "ensureFirstMachine")
	if not isMachinesContainer(machinesFolder) then
		return
	end

	local preplaced1 = findPreplacedMachineInPlot(plot, 1)
	if preplaced1 then
		print("[PlotSetupService] Preplaced Mechine1 found on plot " .. plot.Name .. " (instance " .. preplaced1.Name .. ").")
		if activeProductionMachines[preplaced1] then
			print("[PlotSetupService] Mechine1 already active (copper); skip duplicate ensureFirstMachine.")
			return
		end
		local alreadyVisible = isPreplacedMachineRevealed(preplaced1)
		if not alreadyVisible then
			revealPreplacedMachine(preplaced1)
			print("[PlotSetupService] Preplaced Mechine1 revealed on plot " .. plot.Name .. ".")
		else
			print("[PlotSetupService] Preplaced Mechine1 already visible on plot " .. plot.Name .. "; syncing copper production.")
		end
		local interval1, sellVal1 = getConfigForMachine(1)
		startCopperProduction(preplaced1, plot, sellVal1, interval1)
		return
	end

	-- Fallback: אין Mechine1 מוכן — לא לשכפל אם כבר יש עותק template ישיר (ילד בשם Machine)
	local existingClone = machinesFolder:FindFirstChild(TEMPLATE_MACHINE_NAME)
	if existingClone and (existingClone:IsA("Model") or existingClone:IsA("BasePart")) then
		print(
			"[PlotSetupService] Preplaced Mechine1 not found; existing '"
				.. TEMPLATE_MACHINE_NAME
				.. "' clone present on plot "
				.. plot.Name
				.. " — skip new clone."
		)
		if not activeProductionMachines[existingClone] then
			local interval1, sellVal1 = getConfigForMachine(1)
			startCopperProduction(existingClone, plot, sellVal1, interval1)
			print("[PlotSetupService] Started copper on existing " .. TEMPLATE_MACHINE_NAME .. " for plot " .. plot.Name .. ".")
		end
		return
	end

	warn(
		"[PlotSetupService] אין Mechine1/Machine1 בפלוט ואין ילד '"
			.. TEMPLATE_MACHINE_NAME
			.. "' ב-"
			.. FOLDER_MACHINES
			.. " — לא משכפלים מכונה מ-ReplicatedStorage. הוסף מודל Mechine1 או Machine1 תחת Machines. plot="
			.. plot.Name
	)
end

-- Buy pad נשאר תחת BuyPads; מגלים מכונה שכבר בפלוט (MechineN) ומפעילים Copper — בלי Clone מ-ReplicatedStorage.
function PlotSetupService.SpawnMachineForPad(plot: Instance, pad: Instance)
	local buyPadMod = getBuyPadService()
	local group = buyPadMod and buyPadMod.GetPadGroup and buyPadMod.GetPadGroup(pad) or nil
	if group == PAD_GROUP_BUILDINGS or isHouseSectionPadName(pad.Name) then
		return
	end
	local machinesParent = getPlotMachinesContainer(plot, "SpawnMachineForPad")
	if not machinesParent then
		warn(
			"[PlotSetupService] SpawnMachineForPad: no "
				.. FOLDER_MACHINES
				.. " / "
				.. FOLDER_MECHINES_ALT
				.. " under plot "
				.. plot.Name
				.. "."
		)
		return
	end

	-- מספר מכונה חייב להתאים לשם המודל בפלוט (Mechine2Pad → Mechine2). ShowOrder הוא שלב בתור רכישה (1,2,3…) — לא אותו מספר; שימוש בו כאן גורם ל-off-by-one.
	local function resolveMachineIndexFromPad(): number?
		local fromName = getMachineNumberFromPadName(pad.Name)
		if fromName then
			return fromName
		end
		if buyPadMod and buyPadMod.GetPadShowOrder then
			return buyPadMod.GetPadShowOrder(pad)
		end
		return nil
	end
	local machineNumForPreplaced = resolveMachineIndexFromPad()
	if not machineNumForPreplaced or machineNumForPreplaced < 1 then
		warn("[PlotSetupService] SpawnMachineForPad: לא ניתן לקבוע מספר מכונה מהפד " .. pad.Name)
		return
	end
	local preplaced = findPreplacedMachineInPlot(plot, machineNumForPreplaced)
	if preplaced then
		print(
			"[PlotSetupService] Preplaced machine found: "
				.. preplaced.Name
				.. " for pad "
				.. pad.Name
				.. " on plot "
				.. plot.Name
				.. "."
		)
		if activeProductionMachines[preplaced] then
			print("[PlotSetupService] " .. preplaced.Name .. " already active (copper); skip duplicate SpawnMachineForPad.")
			return
		end
		local alreadyVisible = isPreplacedMachineRevealed(preplaced)
		if not alreadyVisible then
			revealPreplacedMachine(preplaced)
			print("[PlotSetupService] Preplaced " .. preplaced.Name .. " revealed on plot " .. plot.Name .. ".")
		else
			print("[PlotSetupService] Preplaced " .. preplaced.Name .. " already visible; syncing copper production on plot " .. plot.Name .. ".")
		end
		local intervalN, sellValN = getConfigForMachine(machineNumForPreplaced)
		startCopperProduction(preplaced, plot, sellValN, intervalN)
		return
	end

	local n = machineNumForPreplaced
	warn(
		"[PlotSetupService] SpawnMachineForPad: לא נמצאה מכונה מוכנה בפלוט (Mechine"
			.. tostring(n or "?")
			.. " / Machine"
			.. tostring(n or "?")
			.. "). לא משכפלים מ-ReplicatedStorage. pad="
			.. pad.Name
			.. " plot="
			.. plot.Name
	)
end

-- נקרא אחרי Claim מוצלח (ומשחזור בעלות ב-Init).
-- player – בעל ה-Plot (לטעינת נתונים ולשחזור מכונות שנרכשו).
function PlotSetupService.SetupPlotForPlayer(player: Player, plot: Instance)
	if plotStructureDebugEnabled() then
		debugPlotStructureSnapshot("SetupPlotForPlayer START | player=" .. player.Name, plot)
	end
	ensurePlotStructure(plot)
	if plotStructureDebugEnabled() then
		debugPlotStructureSnapshot("SetupPlotForPlayer after ensurePlotStructure", plot)
	end
	ensureFirstMachine(plot)
	if plotStructureDebugEnabled() then
		debugPlotStructureSnapshot("SetupPlotForPlayer after ensureFirstMachine", plot)
	end
	local buyPad = getBuyPadService()
	if buyPad and buyPad.RevealBuyPadsForPlot then
		-- Restore קודם (מסמן Purchased + מכונות), אחר כך Reveal/Refresh — שניהם מרעננים נראות בסוף
		if player and buyPad.RestorePurchasedPadsForPlot then
			buyPad.RestorePurchasedPadsForPlot(player, plot)
		end
		if plotStructureDebugEnabled() then
			debugPlotStructureSnapshot("SetupPlotForPlayer after RestorePurchasedPadsForPlot (before Reveal)", plot)
		end
		buyPad.RevealBuyPadsForPlot(plot)
	else
		if not buyPad then
			warn("[PlotSetupService] BuyPadService לא נמצא – BuyPads לא ייחשפו אחרי Claim.")
		end
	end
	if plotStructureDebugEnabled() then
		debugPlotStructureSnapshot("SetupPlotForPlayer END (after RevealBuyPadsForPlot)", plot)
	end
end

-- קומנד בר שרת (או F9): PlotSetupService.DebugPlotStructureSnapshot(workspace.Plots.Plot1, "manual")
function PlotSetupService.DebugPlotStructureSnapshot(plot: Instance, label: string?)
	debugPlotStructureSnapshot(label or "DebugPlotStructureSnapshot()", plot, true)
end

return PlotSetupService
