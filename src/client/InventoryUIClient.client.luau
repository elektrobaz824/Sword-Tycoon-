--[[
	InventoryUIClient - UI לאינבנטורי בסגנון Shop/Furnace.
	ה-UI נבנה ידנית ב-Studio תחת StarterGui.InventoryGui.
	הסקריפט רק:
	- מחפש את האובייקטים הקיימים (MainFrame, Sections, Rows, Buttons)
	- מקבל Snapshot מהשרת דרך InventoryRemotes
	- מקבל/שולח Equip / Unequip דרך Remotes (RequestEquipSword / RequestUnequipSword / RequestEquippedSword)
	- מעדכן את הטקסטים והמצב ב-UI
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DEBUG = true
local function debugPrint(msg: string)
	if DEBUG then
		print("[InventoryUI] " .. msg)
	end
end

-- Inventory data snapshot from server
type ItemEntry = { Id: string, Type: string, Amount: number, DisplayName: string }
local currentItems: { ItemEntry } = {}
local equippedSword: string? = nil

-- item id lists
local MATERIAL_IDS = { "CopperOre", "IronOre", "GoldOre" }
local SWORD_IDS = { "CopperSword", "IronSword", "GoldSword", "DiamondSword" }

-- Find or clone InventoryGui from StarterGui (no dynamic UI creation beyond cloning template)
local gui = playerGui:FindFirstChild("InventoryGui")
if not gui then
	local template = StarterGui:FindFirstChild("InventoryGui")
	if template and template:IsA("ScreenGui") then
		gui = template:Clone()
		gui.ResetOnSpawn = false
		gui.Parent = playerGui
		debugPrint("InventoryGui cloned from StarterGui to PlayerGui.")
	end
end

if not gui or not gui:IsA("ScreenGui") then
	warn("[InventoryUI] InventoryGui not found in PlayerGui or StarterGui.")
	return
end

-- Default: hidden until toggled
gui.Enabled = false

local mainFrame = gui:FindFirstChild("MainFrame")
if not mainFrame or not mainFrame:IsA("Frame") then
	warn("[InventoryUI] MainFrame not found under InventoryGui.")
	return
end

-- Avoid clipping for tab buttons that might sit above the main border.
-- (Safe even if you don't use tabs.)
pcall(function()
	mainFrame.ClipsDescendants = false
end)

local contentFrame = mainFrame:FindFirstChild("ContentFrame")
if not contentFrame or not (contentFrame:IsA("Frame") or contentFrame:IsA("ScrollingFrame")) then
	warn("[InventoryUI] ContentFrame not found under MainFrame.")
	return
end

local materialsSection = contentFrame:FindFirstChild("MaterialsSection")
local swordsSection = contentFrame:FindFirstChild("SwordsSection")

if not materialsSection or not (materialsSection:IsA("Frame") or materialsSection:IsA("ScrollingFrame")) then
	warn("[InventoryUI] MaterialsSection not found under ContentFrame.")
	return
end

if not swordsSection or not (swordsSection:IsA("Frame") or swordsSection:IsA("ScrollingFrame")) then
	warn("[InventoryUI] SwordsSection not found under ContentFrame.")
	return
end

local materialsListFrame = materialsSection:FindFirstChild("MaterialsListFrame")
local swordsListFrame = swordsSection:FindFirstChild("SwordsListFrame")

if not materialsListFrame or not (materialsListFrame:IsA("Frame") or materialsListFrame:IsA("ScrollingFrame")) then
	warn("[InventoryUI] MaterialsListFrame not found under MaterialsSection.")
	return
end

if not swordsListFrame or not (swordsListFrame:IsA("Frame") or swordsListFrame:IsA("ScrollingFrame")) then
	warn("[InventoryUI] SwordsListFrame not found under SwordsSection.")
	return
end

local closeButton = mainFrame:FindFirstChild("CloseButton")
local statusLabel = mainFrame:FindFirstChild("StatusLabel")

-- Optional tabs UI (Materials / Swords). If buttons don't exist in the current UI,
-- the inventory behaves like before (shows both columns).
local materialsTabButton = mainFrame:FindFirstChild("MaterialsTabButton")
local swordsTabButton = mainFrame:FindFirstChild("SwordsTabButton")
local activeTab: "materials" | "swords" = "materials"

local function setActiveTab(tab: "materials" | "swords")
	activeTab = tab

	-- Hide/show columns based on active tab.
	if materialsSection and (materialsSection:IsA("Frame") or materialsSection:IsA("ScrollingFrame")) then
		materialsSection.Visible = (tab == "materials")
	end
	if swordsSection and (swordsSection:IsA("Frame") or swordsSection:IsA("ScrollingFrame")) then
		swordsSection.Visible = (tab == "swords")
	end

	-- Visual feedback (safe: buttons might be missing).
	local ACTIVE_BG = Color3.fromRGB(51, 128, 64)
	local INACTIVE_BG = Color3.fromRGB(45, 45, 60)
	if materialsTabButton and materialsTabButton:IsA("GuiButton") then
		-- Ensure tabs render above backgrounds/overlays.
		pcall(function()
			materialsTabButton.ZIndex = 50
			materialsTabButton.Visible = true
			materialsTabButton.Active = true
		end)
		materialsTabButton.BackgroundColor3 = (tab == "materials") and ACTIVE_BG or INACTIVE_BG
	end
	if swordsTabButton and swordsTabButton:IsA("GuiButton") then
		pcall(function()
			swordsTabButton.ZIndex = 50
			swordsTabButton.Visible = true
			swordsTabButton.Active = true
		end)
		swordsTabButton.BackgroundColor3 = (tab == "swords") and ACTIVE_BG or INACTIVE_BG
	end
end

-- Row references
type MaterialRowRefs = { Row: Instance?, NameLabel: TextLabel?, AmountLabel: TextLabel? }
type SwordRowRefs = {
	Row: Instance?,
	NameLabel: TextLabel?,
	AmountLabel: TextLabel?,
	EquippedLabel: TextLabel?,
	EquipButton: GuiButton?,
	UnequipButton: GuiButton?,
}

local materialRows: { [string]: MaterialRowRefs } = {}
local swordRows: { [string]: SwordRowRefs } = {}

for _, itemId in MATERIAL_IDS do
	local rowName = ""
	if itemId == "CopperOre" then
		rowName = "CopperRow"
	elseif itemId == "IronOre" then
		rowName = "IronRow"
	elseif itemId == "GoldOre" then
		rowName = "GoldRow"
	end

	local row = materialsListFrame:FindFirstChild(rowName)
	if row and row:IsA("Frame") then
		local nameLabel = row:FindFirstChild("NameLabel")
		local amountLabel = row:FindFirstChild("AmountLabel")
		materialRows[itemId] = {
			Row = row,
			NameLabel = (nameLabel and nameLabel:IsA("TextLabel")) and nameLabel or nil,
			AmountLabel = (amountLabel and amountLabel:IsA("TextLabel")) and amountLabel or nil,
		}
	else
		warn("[InventoryUI] Missing material row " .. tostring(rowName) .. " for " .. tostring(itemId))
	end
end

for _, swordId in SWORD_IDS do
	local rowName = swordId .. "Row"
	local row = swordsListFrame:FindFirstChild(rowName)
	if row and row:IsA("Frame") then
		local nameLabel = row:FindFirstChild("NameLabel")
		local amountLabel = row:FindFirstChild("AmountLabel")
		local equippedLabel = row:FindFirstChild("EquippedLabel")
		local equipButton = row:FindFirstChild("EquipButton")
		local unequipButton = row:FindFirstChild("UnequipButton")
		swordRows[swordId] = {
			Row = row,
			NameLabel = (nameLabel and nameLabel:IsA("TextLabel")) and nameLabel or nil,
			AmountLabel = (amountLabel and amountLabel:IsA("TextLabel")) and amountLabel or nil,
			EquippedLabel = (equippedLabel and equippedLabel:IsA("TextLabel")) and equippedLabel or nil,
			EquipButton = (equipButton and equipButton:IsA("GuiButton")) and equipButton or nil,
			UnequipButton = (unequipButton and unequipButton:IsA("GuiButton")) and unequipButton or nil,
		}
	else
		warn("[InventoryUI] Missing sword row " .. tostring(rowName) .. " for " .. tostring(swordId))
	end
end

local rfInventory: RemoteFunction? = nil
local reInventoryUpdated: RemoteEvent? = nil
local rfEquipSword: RemoteFunction? = nil
local rfUnequipSword: RemoteFunction? = nil
local rfEquippedSword: RemoteFunction? = nil

local function setStatus(text: string, isSuccess: boolean?)
	if statusLabel and statusLabel:IsA("TextLabel") then
		statusLabel.Text = text
		if isSuccess == nil then
			statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		elseif isSuccess then
			statusLabel.TextColor3 = Color3.fromRGB(100, 255, 120)
		else
			statusLabel.TextColor3 = Color3.fromRGB(255, 120, 100)
		end
		statusLabel.Visible = text ~= ""
	end
end

local function normalizeList(list: { any }): { ItemEntry }
	local out: { ItemEntry } = {}
	if type(list) ~= "table" then
		return out
	end
	for _, v in list do
		if type(v) == "table" and (v.Id or v.id) then
			table.insert(out, {
				Id = v.Id or v.id,
				Type = v.Type or v.type or "Material",
				Amount = type(v.Amount) == "number" and v.Amount
					or (type(v.amount) == "number" and v.amount or 0),
				DisplayName = v.DisplayName or v.displayName or v.Id or v.id,
			})
		end
	end
	if #out == 0 and type(list[1]) == "table" then
		for i = 1, #list do
			local v = list[i]
			if v and (v.Id or v.id) then
				table.insert(out, {
					Id = v.Id or v.id,
					Type = v.Type or v.type or "Material",
					Amount = type(v.Amount) == "number" and v.Amount
						or (type(v.amount) == "number" and v.amount or 0),
					DisplayName = v.DisplayName or v.displayName or v.Id or v.id,
				})
			end
		end
	end
	return out
end

local function getAmountById(id: string): number
	for _, item in currentItems do
		if item.Id == id then
			return item.Amount or 0
		end
	end
	return 0
end

local function refreshInventoryFromServer()
	if not rfInventory then
		return
	end
	local ok, list = pcall(function()
		return rfInventory:InvokeServer()
	end)
	if ok and type(list) == "table" then
		currentItems = normalizeList(list)
		debugPrint("inventory data loaded – items: " .. tostring(#currentItems))
	else
		debugPrint("failed to load inventory data from server.")
	end
end

local function refreshEquippedSwordFromServer()
	if not rfEquippedSword then
		return
	end
	local ok, data = pcall(function()
		return rfEquippedSword:InvokeServer()
	end)
	if ok and type(data) == "table" then
		equippedSword = data.equippedSword
		debugPrint("equipped sword snapshot: " .. tostring(equippedSword))
	else
		debugPrint("failed to load equipped sword from server.")
	end
end

local function updateMaterialRows()
	for itemId, refs in materialRows do
		local amount = getAmountById(itemId)
		-- Hide rows that have zero amount.
		if refs.Row then
			refs.Row.Visible = amount > 0
		end
		if refs.AmountLabel then
			refs.AmountLabel.Text = tostring(amount)
		end
	end
end

local function updateSwordRows()
	for swordId, refs in swordRows do
		local amount = getAmountById(swordId)
		local isEquipped = (equippedSword == swordId)
		-- Hide swords that aren't owned (unless equipped).
		if refs.Row then
			refs.Row.Visible = (amount > 0) or isEquipped
		end

		if refs.AmountLabel then
			refs.AmountLabel.Text = tostring(amount)
		end

		if refs.EquippedLabel then
			if isEquipped then
				refs.EquippedLabel.Text = "Equipped"
				refs.EquippedLabel.Visible = true
			else
				refs.EquippedLabel.Text = ""
				refs.EquippedLabel.Visible = false
			end
		end

		-- Equip button should appear only on hover.
		if refs.EquipButton then
			refs.EquipButton.Visible = false
		end
		if refs.UnequipButton then
			refs.UnequipButton.Visible = isEquipped
		end
	end
end

local function updateAllRows()
	updateMaterialRows()
	updateSwordRows()
end

local function connectRemotes()
	-- inventory
	local invFolder = ReplicatedStorage:WaitForChild("InventoryRemotes", 30)
	if not invFolder then
		debugPrint("InventoryRemotes not found – inventory UI will not update.")
	else
		local rf = invFolder:FindFirstChild("RequestInventory")
		local re = invFolder:FindFirstChild("InventoryUpdated")
		if rf and rf:IsA("RemoteFunction") then
			rfInventory = rf
		end
		if re and re:IsA("RemoteEvent") then
			reInventoryUpdated = re
		end
		if reInventoryUpdated then
			reInventoryUpdated.OnClientEvent:Connect(function(list: { any })
				if type(list) == "table" then
					currentItems = normalizeList(list)
					debugPrint("InventoryUpdated event – items: " .. tostring(#currentItems))
					if gui.Enabled then
						updateAllRows()
					end
				end
			end)
		end
	end

	-- equip / unequip
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
	if not remotes then
		debugPrint("Remotes folder not found – equip / unequip will not work.")
		return
	end

	local equipRf = remotes:FindFirstChild("RequestEquipSword")
	local unequipRf = remotes:FindFirstChild("RequestUnequipSword")
	local getEquippedRf = remotes:FindFirstChild("RequestEquippedSword")

	if equipRf and equipRf:IsA("RemoteFunction") then
		rfEquipSword = equipRf
	end
	if unequipRf and unequipRf:IsA("RemoteFunction") then
		rfUnequipSword = unequipRf
	end
	if getEquippedRf and getEquippedRf:IsA("RemoteFunction") then
		rfEquippedSword = getEquippedRf
	end

	if not rfEquipSword or not rfUnequipSword then
		debugPrint("Equip/Unequip remotes missing – buttons will not work.")
	end
end

local function requestEquipSword(swordId: string)
	if not rfEquipSword then
		return
	end
	debugPrint("equip requested: " .. swordId)
	setStatus("Equipping...", nil)
	local ok, result = pcall(function()
		return rfEquipSword:InvokeServer(swordId)
	end)
	if not ok or type(result) ~= "table" then
		setStatus("Equip failed", false)
		debugPrint("equip result error.")
		return
	end
	if result.success then
		equippedSword = result.equippedSword
		setStatus("Equipped " .. tostring(swordId), true)
		-- Auto-hide equipped message.
		task.delay(2, function()
			if gui and gui.Enabled then
				setStatus("", nil)
			end
		end)
	else
		setStatus("Equip failed (" .. tostring(result.reason or "error") .. ")", false)
	end
	debugPrint("equip result: success=" .. tostring(result.success) .. " sword=" .. tostring(result.equippedSword))
	updateSwordRows()
end

local function requestUnequipSword()
	if not rfUnequipSword then
		return
	end
	debugPrint("unequip requested")
	setStatus("Unequipping...", nil)
	local ok, result = pcall(function()
		return rfUnequipSword:InvokeServer()
	end)
	if not ok or type(result) ~= "table" then
		setStatus("Unequip failed", false)
		debugPrint("unequip result error.")
		return
	end
	if result.success then
		equippedSword = result.equippedSword
		setStatus("Unequipped", true)
		-- Auto-hide unequipped message.
		task.delay(2, function()
			if gui and gui.Enabled then
				setStatus("", nil)
			end
		end)
	else
		setStatus("Unequip failed", false)
	end
	debugPrint("unequip result: success=" .. tostring(result.success) .. " sword=" .. tostring(result.equippedSword))
	updateSwordRows()
end

local function connectButtons()
	-- sword equip/unequip buttons
	for swordId, refs in swordRows do
		if refs.EquipButton then
			refs.EquipButton.MouseButton1Click:Connect(function()
				if getAmountById(swordId) > 0 then
					requestEquipSword(swordId)
				end
			end)
		end
		if refs.UnequipButton then
			refs.UnequipButton.MouseButton1Click:Connect(function()
				if equippedSword == swordId then
					requestUnequipSword()
				end
			end)
		end

		-- Show Equip button only when hovering over the sword row.
		if refs.Row and refs.Row:IsA("GuiObject") then
			refs.Row.MouseEnter:Connect(function()
				local amount = getAmountById(swordId)
				local isEquipped = (equippedSword == swordId)
				if refs.EquipButton then
					refs.EquipButton.Visible = (amount > 0 and not isEquipped)
				end
			end)

			refs.Row.MouseLeave:Connect(function()
				if refs.EquipButton then
					refs.EquipButton.Visible = false
				end
			end)
		end
	end

	-- close button
	if closeButton and closeButton:IsA("GuiButton") then
		closeButton.MouseButton1Click:Connect(function()
			gui.Enabled = false
			debugPrint("inventory ui closed.")
		end)
	end

	-- tabs: Materials / Swords
	if materialsTabButton and materialsTabButton:IsA("GuiButton") then
		pcall(function()
			materialsTabButton.Active = true
			materialsTabButton.ZIndex = 50
			materialsTabButton.Visible = true
		end)
		materialsTabButton.MouseButton1Click:Connect(function()
			setActiveTab("materials")
		end)
	end
	if swordsTabButton and swordsTabButton:IsA("GuiButton") then
		pcall(function()
			swordsTabButton.Active = true
			swordsTabButton.ZIndex = 50
			swordsTabButton.Visible = true
		end)
		swordsTabButton.MouseButton1Click:Connect(function()
			setActiveTab("swords")
		end)
	end
end

local suppressEnabledSignal = false

local function openInventory()
	-- Guard: other scripts may toggle `gui.Enabled` and this signal will try
	-- to reopen/refresh. While we're opening, ignore the Enabled-changed handler.
	suppressEnabledSignal = true
	gui.Enabled = true
	debugPrint("inventory ui opened.")
	setStatus("", nil)
	setActiveTab(activeTab)
	-- Refresh snapshot + equipped state, then update rows
	refreshInventoryFromServer()
	refreshEquippedSwordFromServer()
	updateAllRows()
	suppressEnabledSignal = false
end

local function toggleInventory()
	if gui.Enabled then
		gui.Enabled = false
		debugPrint("inventory ui closed (toggle).")
	else
		openInventory()
	end
end

-- If some other UI (like a HUD button) flips `InventoryGui.Enabled = true`,
-- refresh the inventory data and row visibility accordingly.
gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if suppressEnabledSignal then
		return
	end
	if gui.Enabled then
		-- Reuse the existing openInventory logic (refresh snapshot, equipped sword, etc.)
		openInventory()
	end
end)

-- Fallback: If StatsHUD exists but doesn't have InventoryButton yet,
-- create it and hook it to `toggleInventory()`.
task.spawn(function()
	local statsGui: Instance? = nil
	local ok, res = pcall(function()
		return playerGui:WaitForChild("StatsHUD", 10)
	end)
	statsGui = (ok and res) or playerGui:FindFirstChild("StatsHUD")
	if not statsGui then return end

	local mainHud = statsGui:FindFirstChild("MainHud")
	if not mainHud or not mainHud:IsA("Frame") then
		return
	end
	if mainHud:FindFirstChild("InventoryButton") then
		return -- already created (avoid double handlers)
	end

	local invBtn = Instance.new("TextButton")
	invBtn.Name = "InventoryButton"
	invBtn.Size = UDim2.new(0, 120, 0, 28)
	invBtn.Position = UDim2.new(0, 110, 0, 56)
	invBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 62)
	invBtn.Text = "Inventory"
	invBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	invBtn.TextSize = 14
	invBtn.Font = Enum.Font.GothamMedium
	Instance.new("UICorner", invBtn).CornerRadius = UDim.new(0, 6)
	invBtn.Parent = mainHud

	invBtn.MouseButton1Click:Connect(function()
		toggleInventory()
	end)
end)

connectRemotes()
connectButtons()

-- Keyboard toggle: I / Tab (consistent with old UI, but ללא יצירת כפתור דרך קוד)
ContextActionService:BindActionAtPriority("InventoryToggle", function(_, state)
	if state == Enum.UserInputState.Begin then
		toggleInventory()
	end
	return Enum.ContextActionResult.Sink
end, false, 10000, Enum.KeyCode.I, Enum.KeyCode.Tab)

debugPrint("Inventory UI client ready.")
