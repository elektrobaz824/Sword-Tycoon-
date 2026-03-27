--[[
  הרצה חד-פעמית ב-Studio – יוצר SwordFurnaceGui תחת StarterGui כאובייקטים אמיתיים.

  חשוב: להריץ במצב עריכה (Edit mode), לא ב-Play!
  אם תריץ ב-Play ותעצור – השינויים לא נשמרים.

  איך להריץ במצב עריכה:
  1. אל תלחץ Play.
  2. View → Command Bar.
  3. הדבק כאן את כל הקוד מהקובץ והקש Enter.
  4. שמור את ה-place (Ctrl+S).

  אחרי השמירה: SwordFurnaceGui יופיע ב-Explorer תחת StarterGui.
  כדי לראות אותו על המסך במשחק – הפעל Enabled = true על ה-ScreenGui.
]]

local StarterGui = game:GetService("StarterGui")

if StarterGui:FindFirstChild("SwordFurnaceGui") then
	print("[CreateSwordFurnaceGui] SwordFurnaceGui כבר קיים ב-StarterGui. לא יוצרים שוב.")
	return
end

local sg = Instance.new("ScreenGui")
sg.Name = "SwordFurnaceGui"
sg.Enabled = false
sg.Parent = StarterGui

local main = Instance.new("Frame")
main.Name = "MainFrame"
main.Size = UDim2.fromScale(0.45, 0.55)
main.Position = UDim2.fromScale(0.5, 0.5)
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.BackgroundColor3 = Color3.fromRGB(31, 31, 41)
main.BorderSizePixel = 0
main.Parent = sg

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(64, 64, 77)
mainStroke.Thickness = 1
mainStroke.Parent = main

local mainPad = Instance.new("UIPadding")
mainPad.PaddingLeft = UDim.new(0, 16)
mainPad.PaddingRight = UDim.new(0, 16)
mainPad.PaddingTop = UDim.new(0, 16)
mainPad.PaddingBottom = UDim.new(0, 16)
mainPad.Parent = main

local title = Instance.new("TextLabel")
title.Name = "TitleLabel"
title.Size = UDim2.new(1, -32, 0, 32)
title.Position = UDim2.fromOffset(0, 0)
title.BackgroundTransparency = 1
title.Text = "Sword Furnace"
title.TextColor3 = Color3.fromRGB(242, 242, 242)
title.TextSize = 24
title.Parent = main

local matFrame = Instance.new("Frame")
matFrame.Name = "MaterialsFrame"
matFrame.Size = UDim2.new(0.45, -8, 0, 180)
matFrame.Position = UDim2.fromOffset(0, 44)
matFrame.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
matFrame.BorderSizePixel = 0
matFrame.Parent = main

local matCorner = Instance.new("UICorner")
matCorner.CornerRadius = UDim.new(0, 8)
matCorner.Parent = matFrame

local matPad = Instance.new("UIPadding")
matPad.PaddingLeft = UDim.new(0, 10)
matPad.PaddingRight = UDim.new(0, 10)
matPad.PaddingTop = UDim.new(0, 8)
matPad.PaddingBottom = UDim.new(0, 8)
matPad.Parent = matFrame

local matList = Instance.new("UIListLayout")
matList.Padding = UDim.new(0, 6)
matList.VerticalAlignment = Enum.VerticalAlignment.Top
matList.SortOrder = Enum.SortOrder.LayoutOrder
matList.Parent = matFrame

local matTitle = Instance.new("TextLabel")
matTitle.Name = "MaterialsTitle"
matTitle.LayoutOrder = 0
matTitle.Size = UDim2.new(1, 0, 0, 22)
matTitle.BackgroundTransparency = 1
matTitle.Text = "Materials"
matTitle.TextColor3 = Color3.fromRGB(217, 217, 217)
matTitle.TextSize = 16
matTitle.Parent = matFrame

local function addRow(parent, layoutOrder, oreName)
	local row = Instance.new("Frame")
	row.Name = oreName .. "Row"
	row.LayoutOrder = layoutOrder
	row.Size = UDim2.new(1, 0, 0, 32)
	row.BackgroundColor3 = Color3.fromRGB(41, 41, 51)
	row.BorderSizePixel = 0
	row.Parent = parent

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 6)
	rowCorner.Parent = row

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Name = "NameLabel"
	nameLbl.Size = UDim2.new(0.4, -4, 1, 0)
	nameLbl.Position = UDim2.fromOffset(4, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = oreName .. " Ore"
	nameLbl.TextColor3 = Color3.fromRGB(230, 230, 230)
	nameLbl.TextSize = 14
	nameLbl.Parent = row

	local minusBtn = Instance.new("TextButton")
	minusBtn.Name = "MinusButton"
	minusBtn.Size = UDim2.fromOffset(28, 28)
	minusBtn.Position = UDim2.new(0.45, 0, 0.5, 0)
	minusBtn.AnchorPoint = Vector2.new(0, 0.5)
	minusBtn.BackgroundColor3 = Color3.fromRGB(64, 51, 51)
	minusBtn.Text = "-"
	minusBtn.TextColor3 = Color3.fromRGB(242, 230, 230)
	minusBtn.TextSize = 16
	minusBtn.Parent = row
	local minusCorner = Instance.new("UICorner")
	minusCorner.CornerRadius = UDim.new(0, 4)
	minusCorner.Parent = minusBtn

	local amountLbl = Instance.new("TextLabel")
	amountLbl.Name = "AmountLabel"
	amountLbl.Size = UDim2.fromOffset(36, 32)
	amountLbl.Position = UDim2.new(0.5, -18, 0, 0)
	amountLbl.BackgroundTransparency = 1
	amountLbl.Text = "0"
	amountLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	amountLbl.TextSize = 14
	amountLbl.Parent = row

	local plusBtn = Instance.new("TextButton")
	plusBtn.Name = "PlusButton"
	plusBtn.Size = UDim2.fromOffset(28, 28)
	plusBtn.Position = UDim2.new(0.65, 0, 0.5, 0)
	plusBtn.AnchorPoint = Vector2.new(0, 0.5)
	plusBtn.BackgroundColor3 = Color3.fromRGB(51, 71, 51)
	plusBtn.Text = "+"
	plusBtn.TextColor3 = Color3.fromRGB(242, 242, 230)
	plusBtn.TextSize = 16
	plusBtn.Parent = row
	local plusCorner = Instance.new("UICorner")
	plusCorner.CornerRadius = UDim.new(0, 4)
	plusCorner.Parent = plusBtn
end

addRow(matFrame, 1, "Copper")
addRow(matFrame, 2, "Iron")
addRow(matFrame, 3, "Gold")

local chanceFrame = Instance.new("Frame")
chanceFrame.Name = "ChancesFrame"
chanceFrame.Size = UDim2.new(0.5, -12, 0, 180)
chanceFrame.Position = UDim2.new(0.5, 8, 0, 44)
chanceFrame.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
chanceFrame.BorderSizePixel = 0
chanceFrame.Parent = main

local chanceCorner = Instance.new("UICorner")
chanceCorner.CornerRadius = UDim.new(0, 8)
chanceCorner.Parent = chanceFrame

local chancePad = Instance.new("UIPadding")
chancePad.PaddingLeft = UDim.new(0, 10)
chancePad.PaddingRight = UDim.new(0, 10)
chancePad.PaddingTop = UDim.new(0, 8)
chancePad.PaddingBottom = UDim.new(0, 8)
chancePad.Parent = chanceFrame

local chanceList = Instance.new("UIListLayout")
chanceList.Padding = UDim.new(0, 6)
chanceList.VerticalAlignment = Enum.VerticalAlignment.Top
chanceList.SortOrder = Enum.SortOrder.LayoutOrder
chanceList.Parent = chanceFrame

local chanceTitle = Instance.new("TextLabel")
chanceTitle.Name = "ChancesTitle"
chanceTitle.LayoutOrder = 0
chanceTitle.Size = UDim2.new(1, 0, 0, 22)
chanceTitle.BackgroundTransparency = 1
chanceTitle.Text = "Sword Chances"
chanceTitle.TextColor3 = Color3.fromRGB(217, 217, 217)
chanceTitle.TextSize = 16
chanceTitle.Parent = chanceFrame

local function addChanceLabel(parent, order, name, text)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.LayoutOrder = order
	l.Size = UDim2.new(1, 0, 0, 20)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = Color3.fromRGB(204, 204, 204)
	l.TextSize = 14
	l.Parent = parent
end

addChanceLabel(chanceFrame, 1, "CopperChanceLabel", "Copper Sword - 0%")
addChanceLabel(chanceFrame, 2, "IronChanceLabel", "Iron Sword - 0%")
addChanceLabel(chanceFrame, 3, "GoldChanceLabel", "Gold Sword - 0%")
addChanceLabel(chanceFrame, 4, "DiamondChanceLabel", "Diamond Sword - 0%")

local btnFrame = Instance.new("Frame")
btnFrame.Name = "ButtonsFrame"
btnFrame.Size = UDim2.new(1, -32, 0, 48)
btnFrame.Position = UDim2.new(0, 0, 1, -60)
btnFrame.BackgroundTransparency = 1
btnFrame.BorderSizePixel = 0
btnFrame.Parent = main

local forgeBtn = Instance.new("TextButton")
forgeBtn.Name = "ForgeButton"
forgeBtn.Size = UDim2.fromOffset(140, 40)
forgeBtn.Position = UDim2.new(0, 0, 0.5, 0)
forgeBtn.AnchorPoint = Vector2.new(0, 0.5)
forgeBtn.BackgroundColor3 = Color3.fromRGB(51, 128, 64)
forgeBtn.Text = "Forge"
forgeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
forgeBtn.TextSize = 18
forgeBtn.Parent = btnFrame
local forgeCorner = Instance.new("UICorner")
forgeCorner.CornerRadius = UDim.new(0, 8)
forgeCorner.Parent = forgeBtn

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseButton"
closeBtn.Size = UDim2.fromOffset(100, 40)
closeBtn.Position = UDim2.new(1, 0, 0.5, 0)
closeBtn.AnchorPoint = Vector2.new(1, 0.5)
closeBtn.BackgroundColor3 = Color3.fromRGB(89, 51, 51)
closeBtn.Text = "Close"
closeBtn.TextColor3 = Color3.fromRGB(242, 230, 230)
closeBtn.TextSize = 18
closeBtn.Parent = btnFrame
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeBtn

print("[CreateSwordFurnaceGui] נוצר SwordFurnaceGui ב-StarterGui. שמור את ה-place (Ctrl+S) ומחק את הסקריפט.")
