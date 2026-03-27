--[[
	BuyPadUIClient - הצגת הודעה כשאין מספיק מטבעות לרכישת Pad
	מאזין ל-RemoteEvent מהשרת ומציג מסך זמני עם Cost / You have / You need X more.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_NAME = "BuyPadNotEnoughCoins"
local DISPLAY_SECONDS = 5

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remote = ReplicatedStorage:WaitForChild(REMOTE_NAME, 10)
if not remote or not remote:IsA("RemoteEvent") then
	return
end

local function showNotEnoughCoins(cost: number, have: number, need: number)
	local gui = Instance.new("ScreenGui")
	gui.Name = "BuyPadNotEnoughCoins"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 280, 0, 160)
	frame.Position = UDim2.new(0.5, -140, 0.5, -80)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 16)
	padding.PaddingBottom = UDim.new(0, 16)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = frame

	local function addLabel(text: string, order: number): TextLabel
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -32, 0, 28)
		label.Position = UDim2.new(0, 0, 0, (order - 1) * 32)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextSize = 18
		label.Font = Enum.Font.Gotham
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = frame
		return label
	end

	addLabel("Not enough coins", 1)
	addLabel("Cost: " .. tostring(cost), 2)
	addLabel("You have: " .. tostring(have), 3)
	addLabel("You need " .. tostring(need) .. " more", 4)

	task.delay(DISPLAY_SECONDS, function()
		if gui and gui.Parent then
			gui.Enabled = false
			local frame = gui:FindFirstChildOfClass("Frame")
			if frame then
				frame.Visible = false
			end
		end
	end)
end

remote.OnClientEvent:Connect(function(cost: number, have: number, need: number)
	showNotEnoughCoins(cost, have, need)
end)
