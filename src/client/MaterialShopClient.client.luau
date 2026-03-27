--[[
	MaterialShopClient - פתיחת חנות חומרים דרך ProximityPrompt של MaterialShopNPC.
	ה-UI נבנה ידנית ב-Studio תחת StarterGui.MaterialShopGui.
	הסקריפט רק:
	- מחפש את האובייקטים הקיימים (MainFrame, Rows, Labels, Buttons)
	- מבקש מחירים מהשרת ומעדכן את ה-PriceLabel
	- שולח בקשות קנייה לשרת (BuyMaterial)
	- מציג תוצאת קנייה (BuyMaterialResult)
	אין יצירת Frames/Buttons/Labels כאן.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DEBUG = true
local function debugPrint(msg: string)
	if DEBUG then
		print("[MaterialShopUI] " .. msg)
	end
end

local NPC_NAME = "MaterialShopNPC"

-- שמות השורות כפי שנבנו ב-Studio
local ROW_CONFIG = {
	CopperOre = "CopperRow",
	IronOre = "IronRow",
	GoldOre = "GoldRow",
}

-- שורות מכירת חרבות
local SWORD_ROW_CONFIG = {
	CopperSword = "CopperSwordRow",
	IronSword = "IronSwordRow",
	GoldSword = "GoldSwordRow",
	DiamondSword = "DiamondSwordRow",
}

-- מנסה קודם למצוא GUI חדש ב-PlayerGui; אם אין, משכפל מ-StarterGui
local gui = playerGui:FindFirstChild("MaterialShopGui")
if not gui then
	local template = StarterGui:FindFirstChild("MaterialShopGui")
	if template and template:IsA("ScreenGui") then
		gui = template:Clone()
		gui.ResetOnSpawn = false
		gui.Parent = playerGui
		debugPrint("שוכפל MaterialShopGui מ-StarterGui ל-PlayerGui.")
	end
end

if not gui or not gui:IsA("ScreenGui") then
	warn("[MaterialShopUI] MaterialShopGui לא נמצא ב-PlayerGui או StarterGui.")
	return
end

-- ברירת מחדל: החנות סגורה עד שלוחצים על ה-NPC
gui.Enabled = false

local mainFrame = gui:WaitForChild("MainFrame", 5)
if not mainFrame or not mainFrame:IsA("Frame") then
	warn("[MaterialShopUI] MainFrame לא נמצא ב-MaterialShopGui.")
	return
end

local materialsFrame = mainFrame:FindFirstChild("MaterialsFrame")
if not materialsFrame or not materialsFrame:IsA("Frame") then
	warn("[MaterialShopUI] MaterialsFrame לא נמצא ב-MainFrame.")
	return
end

local swordsFrame = mainFrame:FindFirstChild("SwordsFrame")
local bottomButtonsFrame = mainFrame:FindFirstChild("BottomButtonsFrame")
local sellAllButton = bottomButtonsFrame and bottomButtonsFrame:FindFirstChild("SellAllSwordsButton")

local closeButton = mainFrame:FindFirstChild("CloseButton")
local statusLabel = mainFrame:FindFirstChild("ShopStatusLabel") or mainFrame:FindFirstChild("StatusLabel")

local reBuy: RemoteEvent? = nil
local reResult: RemoteEvent? = nil
local rfPrices: RemoteFunction? = nil
local rfData: RemoteFunction? = nil
local reSellSword: RemoteEvent? = nil
local reSellAllSwords: RemoteEvent? = nil

-- מחזיק הפניות לשורות לפי itemId
type RowRefs = { Row: Instance?, NameLabel: TextLabel?, PriceLabel: TextLabel?, BuyButton: GuiButton? }
type SwordRowRefs = { Row: Instance?, NameLabel: TextLabel?, AmountLabel: TextLabel?, SellPriceLabel: TextLabel?, SellButton: GuiButton? }
local rows: { [string]: RowRefs } = {}
local swordRows: { [string]: SwordRowRefs } = {}

for itemId, rowName in ROW_CONFIG do
	local row = materialsFrame:FindFirstChild(rowName)
	if row and row:IsA("Frame") then
		local nameLabel = row:FindFirstChild("NameLabel")
		local priceLabel = row:FindFirstChild("PriceLabel")
		local buyButton = row:FindFirstChild("BuyButton")
		rows[itemId] = {
			Row = row,
			NameLabel = (nameLabel and nameLabel:IsA("TextLabel")) and nameLabel or nil,
			PriceLabel = (priceLabel and priceLabel:IsA("TextLabel")) and priceLabel or nil,
			BuyButton = (buyButton and buyButton:IsA("GuiButton")) and buyButton or nil,
		}
	else
		warn("[MaterialShopUI] לא נמצאה שורה " .. tostring(rowName) .. " עבור " .. tostring(itemId))
	end
end

if swordsFrame and swordsFrame:IsA("Frame") then
	for swordId, rowName in SWORD_ROW_CONFIG do
		local row = swordsFrame:FindFirstChild(rowName)
		if row and row:IsA("Frame") then
			local nameLabel = row:FindFirstChild("NameLabel")
			local amountLabel = row:FindFirstChild("AmountLabel")
			local sellPriceLabel = row:FindFirstChild("SellPriceLabel")
			local sellButton = row:FindFirstChild("SellButton")
			swordRows[swordId] = {
				Row = row,
				NameLabel = (nameLabel and nameLabel:IsA("TextLabel")) and nameLabel or nil,
				AmountLabel = (amountLabel and amountLabel:IsA("TextLabel")) and amountLabel or nil,
				SellPriceLabel = (sellPriceLabel and sellPriceLabel:IsA("TextLabel")) and sellPriceLabel or nil,
				SellButton = (sellButton and sellButton:IsA("GuiButton")) and sellButton or nil,
			}
		else
			warn("[MaterialShopUI] לא נמצאה שורת חרב " .. tostring(rowName) .. " עבור " .. tostring(swordId))
		end
	end
else
	debugPrint("SwordsFrame לא נמצא – אזור מכירת חרבות לא יוצג.")
end

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

local function connectRemotes()
	local folder = ReplicatedStorage:WaitForChild("Remotes", 30)
	if not folder then
		debugPrint("Remotes לא נמצא – החנות לא תפעיל קנייה.")
		return
	end
	local rb = folder:WaitForChild("BuyMaterial", 15)
	local rr = folder:WaitForChild("BuyMaterialResult", 15)
	local rp = folder:FindFirstChild("RequestMaterialShopPrices")
	local rd = folder:FindFirstChild("RequestMaterialShopData")
	-- Remotes של מכירת חרבות עשויים להיווצר קצת אחרי Init, לכן ננסה WaitForChild קודם
	local rs = folder:FindFirstChild("SellSword") or folder:WaitForChild("SellSword", 5)
	local rsa = folder:FindFirstChild("SellAllSwords") or folder:WaitForChild("SellAllSwords", 5)
	if not rb or not rb:IsA("RemoteEvent") or not rr or not rr:IsA("RemoteEvent") then
		debugPrint("BuyMaterial או BuyMaterialResult חסרים.")
		return
	end
	reBuy = rb :: RemoteEvent
	reResult = rr :: RemoteEvent
	if rp and rp:IsA("RemoteFunction") then
		rfPrices = rp :: RemoteFunction
	end
	if rd and rd:IsA("RemoteFunction") then
		rfData = rd :: RemoteFunction
	end
	if rs and rs:IsA("RemoteEvent") then
		reSellSword = rs :: RemoteEvent
	else
		debugPrint("SellSword Remote לא נמצא – Sell לא יעבוד.")
	end
	if rsa and rsa:IsA("RemoteEvent") then
		reSellAllSwords = rsa :: RemoteEvent
	else
		debugPrint("SellAllSwords Remote לא נמצא – Sell All לא יעבוד.")
	end

	if reResult then
		reResult.OnClientEvent:Connect(function(success: boolean, message: string)
			if success then
				setStatus("Purchase completed", true)
			else
				setStatus(message or "Not enough coins", false)
			end
			-- אחרי כל פעולה (קנייה/מכירה) נרענן נתונים
			if rfData then
				task.delay(0.1, function()
					-- ריענון מלא כדי לעדכן כמויות ומחירים
					if rfData then
						local ok, data = pcall(function()
							return rfData:InvokeServer()
						end)
						if ok and type(data) == "table" then
							if type(data.materialPrices) == "table" then
								for itemId, refs in rows do
									local price = data.materialPrices[itemId]
									if refs.PriceLabel and type(price) == "number" then
										refs.PriceLabel.Text = tostring(price) .. " Coins"
									end
								end
							end
							if type(data.swordSellPrices) == "table" then
								for swordId, refs in swordRows do
									local price = data.swordSellPrices[swordId]
									if refs.SellPriceLabel and type(price) == "number" then
										refs.SellPriceLabel.Text = tostring(price) .. " Coins"
									end
								end
							end
							if type(data.swordCounts) == "table" then
								for swordId, refs in swordRows do
									local count = data.swordCounts[swordId]
									if refs.AmountLabel and type(count) == "number" then
										refs.AmountLabel.Text = tostring(count)
									end
								end
							end
						end
					end
				end)
			end
		end)
	end

	debugPrint("Remotes חנות מחוברים.")
end

-- בקשת מחירים וכמויות מהשרת
local function refreshData()
	if rfData then
		local ok, data = pcall(function()
			return rfData:InvokeServer()
		end)
		if not ok or type(data) ~= "table" then
			debugPrint("קבלת נתוני חנות מהשרת נכשלה.")
			return
		end
		if type(data.materialPrices) == "table" then
			for itemId, refs in rows do
				local price = data.materialPrices[itemId]
				if refs.PriceLabel and type(price) == "number" then
					refs.PriceLabel.Text = tostring(price) .. " Coins"
				end
			end
		end
		if type(data.swordSellPrices) == "table" then
			for swordId, refs in swordRows do
				local price = data.swordSellPrices[swordId]
				if refs.SellPriceLabel and type(price) == "number" then
					refs.SellPriceLabel.Text = tostring(price) .. " Coins"
				end
			end
		end
		if type(data.swordCounts) == "table" then
			for swordId, refs in swordRows do
				local count = data.swordCounts[swordId]
				if refs.AmountLabel and type(count) == "number" then
					refs.AmountLabel.Text = tostring(count)
				end
			end
		end
	elseif rfPrices then
		-- תאימות לאחור: רק מחירי קנייה
		local ok, prices = pcall(function()
			return rfPrices:InvokeServer()
		end)
		if not ok or type(prices) ~= "table" then
			debugPrint("קבלת מחירים מהשרת נכשלה.")
		 return
		end
		for itemId, refs in rows do
			local price = prices[itemId]
			if refs.PriceLabel and type(price) == "number" then
				refs.PriceLabel.Text = tostring(price) .. " Coins"
			end
		end
	end
end

-- חיבור כפתורי קנייה קיימים ב-UI
local function connectBuyButtons()
	for itemId, refs in rows do
		if refs.BuyButton then
			refs.BuyButton.MouseButton1Click:Connect(function()
				if reBuy then
					debugPrint("לחיצה על Buy: " .. itemId)
					setStatus("Processing...", nil)
					reBuy:FireServer(itemId)
				end
			end)
		end
	end

	for swordId, refs in swordRows do
		if refs.SellButton then
			refs.SellButton.MouseButton1Click:Connect(function()
				if reSellSword then
					debugPrint("לחיצה על Sell Sword: " .. swordId)
					setStatus("Processing...", nil)
					reSellSword:FireServer(swordId)
				end
			end)
		end
	end

	if sellAllButton and sellAllButton:IsA("GuiButton") then
		sellAllButton.MouseButton1Click:Connect(function()
			if reSellAllSwords then
				debugPrint("לחיצה על Sell All Swords")
				setStatus("Processing...", nil)
				reSellAllSwords:FireServer()
			end
		end)
	end
end

if closeButton and closeButton:IsA("GuiButton") then
	closeButton.MouseButton1Click:Connect(function()
		mainFrame.Visible = false
		debugPrint("חנות נסגרה.")
	end)
end

-- פונקציית פתיחת חנות – רק מציגה UI קיים ומרעננת מחירים
local function openShop()
	gui.Enabled = true
	mainFrame.Visible = true
	setStatus("", nil)
	debugPrint("Shop opened.")
	refreshData()
end

-- חיבור ל-NPC ו-ProximityPrompt – מחפשים בכל ה-descendants
local function connectToNPC()
	local npc = Workspace:WaitForChild(NPC_NAME, 15)
	if not npc then
		debugPrint("NPC '" .. NPC_NAME .. "' לא נמצא ב-Workspace. וודא שיש אובייקט בשם זה.")
		return
	end
	debugPrint("NPC נמצא: " .. npc:GetFullName())
	local prompt = nil
	for _, desc in npc:GetDescendants() do
		if desc:IsA("ProximityPrompt") then
			prompt = desc
			break
		end
	end
	if not prompt then
		warn("[MaterialShopUI] לא נמצא ProximityPrompt תחת " .. NPC_NAME .. ". הוסף ProximityPrompt ל-Head או ל-NPC.")
		return
	end
	debugPrint("ProximityPrompt נמצא – מתחבר.")
	prompt.Triggered:Connect(function()
		openShop()
	end)
end

connectRemotes()
connectBuyButtons()
connectToNPC()
