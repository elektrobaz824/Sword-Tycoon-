--[[
	FurnaceUIController – פתיחה וסגירה של Sword Furnace UI.
	מקשיב ל-OpenSwordFurnace ומציג את MainFrame; לחיצה על CloseButton סוגרת.
	כפתורי + ו-- משנים תצוגת כמות (Copper, Iron, Gold) – רק UI, בלי לוגיקת משחק.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- מחפש את ה-GUI – יכול להיות SwordFurnaceGui או העתק עם אותו שם
local gui = playerGui:WaitForChild("SwordFurnaceGui", 30)
if not gui then
	warn("[FurnaceUIController] PlayerGui.SwordFurnaceGui לא נמצא. וודא ש-StarterGui מכיל SwordFurnaceGui.")
	return
end

local mainFrame = gui:WaitForChild("MainFrame", 5)
if not mainFrame then
	warn("[FurnaceUIController] MainFrame לא נמצא.")
	return
end

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 20)
local openFurnaceEvent = remotesFolder and remotesFolder:WaitForChild("OpenSwordFurnace", 15)
local requestFurnaceChancesRf = remotesFolder and remotesFolder:FindFirstChild("RequestFurnaceChances")
local requestForgeRf = remotesFolder and remotesFolder:FindFirstChild("RequestForge")
local forgeResultEvent = remotesFolder and remotesFolder:FindFirstChild("ForgeResult")
if not openFurnaceEvent or not openFurnaceEvent:IsA("RemoteEvent") then
	warn("[FurnaceUIController] Remotes.OpenSwordFurnace לא נמצא.")
	return
end

print("[FurnaceUIController] מחובר ל-OpenSwordFurnace, מחכה לפתיחה.")

-- --- כתובית גדולה באנגלית (Forge result / Not enough materials) ---
local subtitleGui = Instance.new("ScreenGui")
subtitleGui.Name = "FurnaceSubtitleGui"
subtitleGui.ResetOnSpawn = false
subtitleGui.DisplayOrder = 100
subtitleGui.IgnoreGuiInset = true

local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.Name = "SubtitleLabel"
subtitleLabel.Size = UDim2.fromScale(1, 0.15)
subtitleLabel.Position = UDim2.fromScale(0.5, 0.5)
subtitleLabel.AnchorPoint = Vector2.new(0.5, 0.5)
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.Text = ""
subtitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
subtitleLabel.TextSize = 42
subtitleLabel.Font = Enum.Font.GothamBold
subtitleLabel.TextStrokeTransparency = 0.3
subtitleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
subtitleLabel.Visible = false
subtitleLabel.Parent = subtitleGui
subtitleGui.Parent = playerGui

local subtitleHideTask = nil
local forgeCountdownTask = nil

local function showSubtitle(text: string, duration: number)
	if subtitleHideTask then
		task.cancel(subtitleHideTask)
	end
	subtitleLabel.Text = text
	subtitleLabel.Visible = true
	subtitleHideTask = task.delay(duration or 3, function()
		subtitleLabel.Visible = false
		subtitleHideTask = nil
	end)
end

local function startForgeCountdown(durationSeconds: number)
	if forgeCountdownTask then
		task.cancel(forgeCountdownTask)
	end
	if subtitleHideTask then
		task.cancel(subtitleHideTask)
		subtitleHideTask = nil
	end
	forgeCountdownTask = task.spawn(function()
		for i = durationSeconds, 1, -1 do
			subtitleLabel.Text = "Time remaining: " .. tostring(i) .. " s"
			subtitleLabel.Visible = true
			local ok = pcall(task.wait, 1)
			if not ok then break end
		end
		forgeCountdownTask = nil
	end)
end

local function stopForgeCountdown()
	if forgeCountdownTask then
		task.cancel(forgeCountdownTask)
		forgeCountdownTask = nil
	end
end

local function swordIdToDisplayName(swordId: string): string
	if swordId == "CopperSword" then return "Copper" end
	if swordId == "IronSword" then return "Iron" end
	if swordId == "GoldSword" then return "Gold" end
	if swordId == "DiamondSword" then return "Diamond" end
	return swordId:gsub("Sword", " ")
end

-- ברירת מחדל: החלון סגור
mainFrame.Visible = false

-- --- כפתורי + / - לחומרים (רק תצוגה, איפוס בכל פתיחה) ---
local MATERIAL_ROW_NAMES = { "CopperRow", "IronRow", "GoldRow" }
local DISPLAY_NAMES = { CopperRow = "Copper", IronRow = "Iron", GoldRow = "Gold" }
local amounts: { [string]: number } = {}

local function updateRowLabel(row: Instance, value: number)
	local label = row:FindFirstChild("AmountLabel")
	if label and label:IsA("TextLabel") then
		label.Text = tostring(value)
	end
end

local function resetAllAmounts()
	local materialsFrame = mainFrame:FindFirstChild("MaterialsFrame")
	if not materialsFrame then return end
	for _, rowName in MATERIAL_ROW_NAMES do
		amounts[rowName] = 0
		local row = materialsFrame:FindFirstChild(rowName)
		if row then
			updateRowLabel(row, 0)
		end
	end
end

-- מחפש Label לפי שם בתוך MainFrame (למשל CopperChanceLabel)
local function findChanceLabel(labelName: string): Instance?
	for _, desc in mainFrame:GetDescendants() do
		if desc.Name == labelName and desc:IsA("TextLabel") then
			return desc
		end
	end
	return nil
end

-- שולח כמויות לשרת, מקבל אחוזים, מעדכן את תגי הסיכויים
local function requestChancesAndUpdateUI()
	if not requestFurnaceChancesRf or not requestFurnaceChancesRf:IsA("RemoteFunction") then
		return
	end
	local copper = amounts["CopperRow"] or 0
	local iron = amounts["IronRow"] or 0
	local gold = amounts["GoldRow"] or 0
	print("Requesting furnace chances", copper, iron, gold)
	local ok, chances = pcall(function()
		return requestFurnaceChancesRf:InvokeServer(copper, iron, gold)
	end)
	if not ok or not chances or type(chances) ~= "table" then
		return
	end
	print("Updating furnace UI chances")
	local labelMap = {
		CopperChanceLabel = "CopperSword",
		IronChanceLabel = "IronSword",
		GoldChanceLabel = "GoldSword",
		DiamondChanceLabel = "DiamondSword",
	}
	local displayNames = {
		CopperChanceLabel = "Copper Sword",
		IronChanceLabel = "Iron Sword",
		GoldChanceLabel = "Gold Sword",
		DiamondChanceLabel = "Diamond Sword",
	}
	for labelName, key in labelMap do
		local label = findChanceLabel(labelName)
		if label and label:IsA("TextLabel") then
			local pct = type(chances[key]) == "number" and chances[key] or 0
			label.Text = displayNames[labelName] .. " - " .. tostring(pct) .. "%"
		end
	end
end

local function setupMaterialButtons()
	local materialsFrame = mainFrame:FindFirstChild("MaterialsFrame")
	if not materialsFrame then return end

	for _, rowName in MATERIAL_ROW_NAMES do
		amounts[rowName] = 0
		local row = materialsFrame:FindFirstChild(rowName)
		if not row then continue end

		local minusBtn = row:FindFirstChild("MinusButton")
		local amountLabel = row:FindFirstChild("AmountLabel")
		local plusBtn = row:FindFirstChild("PlusButton")

		if not amountLabel or not amountLabel:IsA("TextLabel") then continue end
		updateRowLabel(row, 0)

		if plusBtn and plusBtn:IsA("GuiButton") then
			plusBtn.MouseButton1Click:Connect(function()
				amounts[rowName] = (amounts[rowName] or 0) + 1
				updateRowLabel(row, amounts[rowName])
				local displayName = DISPLAY_NAMES[rowName] or rowName
				print(displayName .. " amount = " .. tostring(amounts[rowName]))
				requestChancesAndUpdateUI()
			end)
		end

		if minusBtn and minusBtn:IsA("GuiButton") then
			minusBtn.MouseButton1Click:Connect(function()
				local current = amounts[rowName] or 0
				if current > 0 then
					amounts[rowName] = current - 1
					updateRowLabel(row, amounts[rowName])
					local displayName = DISPLAY_NAMES[rowName] or rowName
					print(displayName .. " amount = " .. tostring(amounts[rowName]))
					requestChancesAndUpdateUI()
				end
			end)
		end
	end
end

setupMaterialButtons()

-- כשהשרת מסיים Craft Timer – מקבלים תוצאת Forge (ForgeResult)
if forgeResultEvent and forgeResultEvent:IsA("RemoteEvent") then
	forgeResultEvent.OnClientEvent:Connect(function(result)
		stopForgeCountdown()
		if type(result) == "table" and result.success and result.sword then
			local displayName = swordIdToDisplayName(result.sword)
			showSubtitle("You got " .. displayName .. " Sword!", 4)
			print("Forge finished:", result.sword)
		else
			print("Forge finished: no sword")
		end
	end)
end

openFurnaceEvent.OnClientEvent:Connect(function()
	resetAllAmounts()
	requestChancesAndUpdateUI()
	gui.Enabled = true
	mainFrame.Visible = true
	print("Opening furnace UI")
end)

local buttonsFrame = mainFrame:FindFirstChild("ButtonsFrame")
local closeButton = buttonsFrame and buttonsFrame:FindFirstChild("CloseButton")
if closeButton and closeButton:IsA("GuiButton") then
	closeButton.MouseButton1Click:Connect(function()
		mainFrame.Visible = false
		print("Closing furnace UI")
	end)
else
	warn("[FurnaceUIController] CloseButton לא נמצא ב-ButtonsFrame.")
end

-- ForgeButton – שולח כמויות לשרת, מקבל שם חרב, מדפיס תוצאה
local forgeButton = buttonsFrame and buttonsFrame:FindFirstChild("ForgeButton")
if forgeButton and forgeButton:IsA("GuiButton") and requestForgeRf and requestForgeRf:IsA("RemoteFunction") then
	forgeButton.MouseButton1Click:Connect(function()
		local copper = amounts["CopperRow"] or 0
		local iron = amounts["IronRow"] or 0
		local gold = amounts["GoldRow"] or 0
		print("Forge requested:", copper, iron, gold)
		local ok, result = pcall(function()
			return requestForgeRf:InvokeServer(copper, iron, gold)
		end)
		if ok and type(result) == "table" then
			if result.started then
				print("Forge started")
				if type(result.duration) == "number" and result.duration > 0 then
					startForgeCountdown(result.duration)
				end
			else
				if result.reason == "already_forging" then
					showSubtitle("Already forging", 4)
					print("Forge failed: already forging")
				else
					showSubtitle("Not enough materials", 4)
					print("Forge failed: not enough ores")
				end
			end
		elseif ok then
			-- תאימות לאחור אם השרת החזיר success/sword
			if type(result) == "table" and result.success and result.sword then
				local displayName = swordIdToDisplayName(result.sword)
				showSubtitle("You got " .. displayName .. " Sword!", 4)
				print("Forge finished:", result.sword)
			elseif type(result) == "string" then
				local displayName = swordIdToDisplayName(result)
				showSubtitle("You got " .. displayName .. " Sword!", 4)
				print("Forge finished:", result)
			else
				showSubtitle("Not enough materials", 4)
				print("Forge failed: not enough ores")
			end
		else
			showSubtitle("Not enough materials", 4)
			warn("[FurnaceUIController] Forge failed:", result)
		end
	end)
else
	if not (forgeButton and forgeButton:IsA("GuiButton")) then
		warn("[FurnaceUIController] ForgeButton לא נמצא ב-ButtonsFrame.")
	end
end
