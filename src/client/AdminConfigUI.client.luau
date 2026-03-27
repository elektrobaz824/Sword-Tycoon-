--[[
	AdminConfigUI - חלון Config רק לאדמין. פתיחה/סגירה עם F9.
	רק אם השרת מחזיר IsAdmin=true – בונים ומציגים את ה-UI.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DEBUG_ADMIN_UI = true
local function debugPrint(msg: string)
	if DEBUG_ADMIN_UI then
		print("[AdminConfigUI] " .. msg)
	end
end

-- מחכה ל-AdminRemotes (השרת יוצר אחרי טעינת AdminConfigService).
local function getAdminRemotes(): (Instance?, Instance?, Instance?)
	local folder = ReplicatedStorage:WaitForChild("AdminRemotes", 15)
	if not folder then
		debugPrint("AdminRemotes לא נמצא – אולי השרת לא טען AdminConfigService.")
		return nil, nil, nil
	end
	local rfAdmin = folder:FindFirstChild("AdminIsAdmin")
	local rfGet = folder:FindFirstChild("AdminGetConfig")
	local reSet = folder:FindFirstChild("AdminSetValue")
	if not rfAdmin or not rfGet or not reSet then
		debugPrint("חסרים Remotes ב-AdminRemotes.")
		return nil, nil, nil
	end
	return rfAdmin, rfGet, reSet
end

local rfAdmin, rfGet, reSet = getAdminRemotes()
if not rfAdmin or not rfGet or not reSet then
	return
end

-- בדיקה אם השחקן אדמין – רק אז בונים UI
local ok, isAdmin = pcall(function()
	return (rfAdmin :: RemoteFunction):InvokeServer()
end)
if not ok or not isAdmin then
	debugPrint("שחקן לא אדמין – חלון Config לא יוצג.")
	return
end

debugPrint("אדמין זוהה – בונים חלון Config.")

-- טעינת רשימת הנתיבים מה-Shared (אותה רשימה כמו בשרת)
local Shared = ReplicatedStorage:WaitForChild("Shared", 5)
local GameConfigModule = Shared and Shared:FindFirstChild("GameConfig")
local GameConfig = GameConfigModule and require(GameConfigModule) or {}
local ConfigPaths = GameConfig.ConfigPaths or {}

-- קיבוץ לפי סקשן: Machines, Materials, BuyPads, MaterialShop, Furnace – כדי להציג במתקפל
local SECTION_ORDER = { "Machines", "Materials", "BuyPads", "MaterialShop", "Furnace", "Stats" }
local SECTION_NAMES = {
	Machines = "מכונות",
	Materials = "חומרים",
	BuyPads = "Buy Pads",
	MaterialShop = "Material Shop",
	Furnace = "Furnace",
	Stats = "Stats",
}
local function groupPathsBySection()
	local groups = { Machines = {}, Materials = {}, BuyPads = {}, MaterialShop = {}, Furnace = {}, Stats = {} }
	for _, path in ConfigPaths do
		local top = path:match("^([^.]+)%.")
		if top and groups[top] then
			table.insert(groups[top], path)
		end
	end
	return groups
end

-- עיצוב מקצועי: חלון רחב, תוויות מלאות (לא קטועות), ריווח נוח
local PAD = 16
local WINDOW_W = 420
local WINDOW_H = 460

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AdminConfigUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H)
mainFrame.Position = UDim2.new(0.5, -WINDOW_W/2, 0.5, -WINDOW_H/2)
mainFrame.BackgroundColor3 = Color3.fromRGB(38, 38, 42)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 10)
uiCorner.Parent = mainFrame

local uiStroke = Instance.new("UIStroke")
uiStroke.Color = Color3.fromRGB(60, 60, 65)
uiStroke.Thickness = 1
uiStroke.Parent = mainFrame

-- כותרת
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 44)
header.Position = UDim2.new(0, 0, 0, 0)
header.BackgroundColor3 = Color3.fromRGB(32, 32, 36)
header.BorderSizePixel = 0
header.Parent = mainFrame

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 10)
headerCorner.Parent = header

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -60, 0, 44)
title.Position = UDim2.new(0, PAD, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Admin Config"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextSize = 20
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -44, 0, 4)
closeBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 75)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.TextSize = 16
closeBtn.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(1, 0)
closeCorner.Parent = closeBtn

-- אזור גלילה עם ריווח
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "ScrollFrame"
scrollFrame.Size = UDim2.new(1, -PAD*2, 0, 320)
scrollFrame.Position = UDim2.new(0, PAD, 0, 52)
scrollFrame.BackgroundColor3 = Color3.fromRGB(32, 32, 36)
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 8
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 90)
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent = mainFrame

local scrollCorner = Instance.new("UICorner")
scrollCorner.CornerRadius = UDim.new(0, 8)
scrollCorner.Parent = scrollFrame

local scrollPadding = Instance.new("UIPadding")
scrollPadding.PaddingLeft = UDim.new(0, 10)
scrollPadding.PaddingRight = UDim.new(0, 10)
scrollPadding.PaddingTop = UDim.new(0, 10)
scrollPadding.PaddingBottom = UDim.new(0, 10)
scrollPadding.Parent = scrollFrame

local scrollList = Instance.new("UIListLayout")
scrollList.Padding = UDim.new(0, 8)
scrollList.SortOrder = Enum.SortOrder.LayoutOrder
scrollList.Parent = scrollFrame

-- כפתור Apply
local applyBtn = Instance.new("TextButton")
applyBtn.Name = "ApplyBtn"
applyBtn.Size = UDim2.new(1, -PAD*2, 0, 40)
applyBtn.Position = UDim2.new(0, PAD, 0, WINDOW_H - 56)
applyBtn.BackgroundColor3 = Color3.fromRGB(0, 122, 204)
applyBtn.Text = "Apply"
applyBtn.TextColor3 = Color3.new(1, 1, 1)
applyBtn.TextSize = 16
applyBtn.Font = Enum.Font.GothamSemibold
applyBtn.Parent = mainFrame

local applyCorner = Instance.new("UICorner")
applyCorner.CornerRadius = UDim.new(0, 8)
applyCorner.Parent = applyBtn

-- מחזיק ref ל-TextBoxים לפי path
local pathToInput: { [string]: TextBox } = {}

-- שורה אחת: תווית + שדה ערך (קומפקטי)
local function buildRow(path: string, value: any, layoutOrder: number): Frame
	local row = Instance.new("Frame")
	row.Name = path:gsub("%.", "_")
	row.Size = UDim2.new(1, 0, 0, 52)
	row.BackgroundTransparency = 1
	row.LayoutOrder = layoutOrder

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.Padding = UDim.new(0, 2)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.FillDirection = Enum.FillDirection.Vertical
	rowLayout.Parent = row

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 22)
	label.BackgroundTransparency = 1
	label.Text = path
	label.TextColor3 = Color3.fromRGB(220, 220, 225)
	label.TextSize = 11
	label.Font = Enum.Font.Gotham
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	label.LayoutOrder = 1
	label.Parent = row

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, 0, 0, 26)
	box.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
	box.BorderSizePixel = 0
	box.Text = tostring(value)
	box.TextColor3 = Color3.new(1, 1, 1)
	box.PlaceholderColor3 = Color3.fromRGB(120, 120, 125)
	box.PlaceholderText = "מספר"
	box.TextSize = 13
	box.Font = Enum.Font.Gotham
	box.ClearTextOnFocus = false
	box.LayoutOrder = 2
	box.Parent = row

	local boxCorner = Instance.new("UICorner")
	boxCorner.CornerRadius = UDim.new(0, 4)
	boxCorner.Parent = box

	pathToInput[path] = box
	return row
end

-- סקשן מתקפל: כותרת + תוכן (שורות)
local function buildSection(sectionKey: string, paths: { string }, layoutOrder: number): Frame
	local sectionFrame = Instance.new("Frame")
	sectionFrame.Name = sectionKey
	sectionFrame.Size = UDim2.new(1, 0, 0, 0)
	sectionFrame.AutomaticSize = Enum.AutomaticSize.Y
	sectionFrame.BackgroundTransparency = 1
	sectionFrame.LayoutOrder = layoutOrder

	local sectionLayout = Instance.new("UIListLayout")
	sectionLayout.Padding = UDim.new(0, 0)
	sectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sectionLayout.FillDirection = Enum.FillDirection.Vertical
	sectionLayout.Parent = sectionFrame

	-- כותרת לחיצה (פתח/סגור)
	local headerBtn = Instance.new("TextButton")
	headerBtn.Name = "Header"
	headerBtn.Size = UDim2.new(1, 0, 0, 36)
	headerBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
	headerBtn.BorderSizePixel = 0
	headerBtn.Text = ""
	headerBtn.LayoutOrder = 1
	headerBtn.AutoButtonColor = true
	headerBtn.Parent = sectionFrame

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 6)
	headerCorner.Parent = headerBtn

	local headerLabel = Instance.new("TextLabel")
	headerLabel.Size = UDim2.new(1, -40, 0, 36)
	headerLabel.Position = UDim2.new(0, 10, 0, 0)
	headerLabel.BackgroundTransparency = 1
	headerLabel.Text = SECTION_NAMES[sectionKey] or sectionKey
	headerLabel.TextColor3 = Color3.new(1, 1, 1)
	headerLabel.TextSize = 14
	headerLabel.Font = Enum.Font.GothamSemibold
	headerLabel.TextXAlignment = Enum.TextXAlignment.Left
	headerLabel.Parent = headerBtn

	local arrowLabel = Instance.new("TextLabel")
	arrowLabel.Size = UDim2.new(0, 24, 0, 36)
	arrowLabel.Position = UDim2.new(1, -30, 0, 0)
	arrowLabel.BackgroundTransparency = 1
	arrowLabel.Text = "▼"
	arrowLabel.TextColor3 = Color3.fromRGB(180, 180, 185)
	arrowLabel.TextSize = 12
	arrowLabel.Parent = headerBtn

	-- תוכן הסקשן (שורות)
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.new(1, 0, 0, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.BackgroundColor3 = Color3.fromRGB(32, 32, 36)
	content.BorderSizePixel = 0
	content.Visible = false
	content.LayoutOrder = 2
	content.Parent = sectionFrame

	local contentPadding = Instance.new("UIPadding")
	contentPadding.PaddingLeft = UDim.new(0, 8)
	contentPadding.PaddingRight = UDim.new(0, 8)
	contentPadding.PaddingTop = UDim.new(0, 6)
	contentPadding.PaddingBottom = UDim.new(0, 6)
	contentPadding.Parent = content

	local contentList = Instance.new("UIListLayout")
	contentList.Padding = UDim.new(0, 6)
	contentList.SortOrder = Enum.SortOrder.LayoutOrder
	contentList.Parent = content

	for i, path in paths do
		local row = buildRow(path, 0, i)
		row.Parent = content
	end

	headerBtn.MouseButton1Click:Connect(function()
		content.Visible = not content.Visible
		arrowLabel.Text = content.Visible and "▼" or "▶"
	end)

	return sectionFrame
end

local function refreshFromServer()
	local ok, data = pcall(function()
		return (rfGet :: RemoteFunction):InvokeServer()
	end)
	if not ok or type(data) ~= "table" then
		debugPrint("refreshFromServer נכשל")
		return
	end
	for path, value in data do
		local box = pathToInput[path]
		if box then
			box.Text = tostring(value)
		end
	end
end

-- בניית הסקשנים (מכונות, חומרים, Buy Pads) – כל סקשן מתקפל, פחות גלילה
local groups = groupPathsBySection()
for order = 1, #SECTION_ORDER do
	local sectionKey = SECTION_ORDER[order]
	local paths = groups[sectionKey]
	if paths and #paths > 0 then
		local section = buildSection(sectionKey, paths, order)
		section.Parent = scrollFrame
	end
end

-- כפתור גלוי על המסך – רק אדמין רואה. לחיצה פותחת את חלון ה-Config
local openBtn = Instance.new("TextButton")
openBtn.Name = "AdminConfigButton"
openBtn.Size = UDim2.new(0, 120, 0, 36)
openBtn.Position = UDim2.new(1, -130, 0, 10)
openBtn.AnchorPoint = Vector2.new(0, 0)
openBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
openBtn.Text = "Admin Config"
openBtn.TextColor3 = Color3.new(1, 1, 1)
openBtn.TextSize = 14
openBtn.Visible = true
openBtn.Parent = screenGui

local openBtnCorner = Instance.new("UICorner")
openBtnCorner.CornerRadius = UDim.new(0, 6)
openBtnCorner.Parent = openBtn

openBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = not mainFrame.Visible
	if mainFrame.Visible then
		refreshFromServer()
		debugPrint("חלון נפתח (מכפתור), נתונים נטענו.")
	end
end)

screenGui.Parent = playerGui

-- Apply – שולח כל ערך לשרת
applyBtn.MouseButton1Click:Connect(function()
	debugPrint("Apply נלחץ.")
	for path, box in pathToInput do
		local text = box.Text
		local num = tonumber(text)
		if num ~= nil then
			(reSet :: RemoteEvent):FireServer(path, num)
			debugPrint("נשלח: " .. path .. " = " .. tostring(num))
		end
	end
	-- רענון מהשרת אחרי רגע (כדי לראות ערכים מעודכנים)
	task.defer(refreshFromServer)
end)

closeBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
	debugPrint("חלון נסגר.")
end)

-- פתיחה עם F9
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.F9 then
		mainFrame.Visible = not mainFrame.Visible
		if mainFrame.Visible then
			refreshFromServer()
			debugPrint("חלון נפתח, נתונים נטענו.")
		end
	end
end)

debugPrint("מוכן. לחץ F9 לפתיחת חלון Config.")
