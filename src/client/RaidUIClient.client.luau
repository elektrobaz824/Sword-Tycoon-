local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local DEBUG = true

local function debugPrint(msg: string)
	if DEBUG then
		print("[RaidClient] " .. msg)
	end
end

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local requestEvent = remotesFolder:WaitForChild("RaidRequestTeleport") :: RemoteEvent
local statusEvent = remotesFolder:WaitForChild("RaidTeleportStatus") :: RemoteEvent

-- ה-UI נבנה ידנית ב-StarterGui.RaidGui
local raidGui = playerGui:WaitForChild("RaidGui") :: ScreenGui
local mainFrame = raidGui:WaitForChild("MainFrame") :: Frame
local titleLabel = mainFrame:WaitForChild("TitleLabel") :: TextLabel
local destinationsFrame = mainFrame:WaitForChild("DestinationsFrame") :: Frame
local testRaidButton = destinationsFrame:WaitForChild("TestRaidButton") :: TextButton
local closeButton = mainFrame:WaitForChild("CloseButton") :: TextButton
local statusLabel = mainFrame:WaitForChild("StatusLabel") :: TextLabel

local isOpen = false

-- בזמן משחק תמיד נתחיל כשהחלון סגור דרך Enabled, כדי שב-Edit יהיה אפשר לראות את ה-UI כשMainFrame.Visible = true
raidGui.Enabled = false

local function openRaidUI()
	debugPrint("UI open requested")
	isOpen = true
	raidGui.Enabled = true
	statusLabel.Text = ""
	titleLabel.Text = "Raid Lobby"
end

local function closeRaidUI()
	isOpen = false
	raidGui.Enabled = false
end

-- זיהוי דריכה על RaidCircle – לוקאלי בלבד, השרת נשאר הסמכות ל-validation
local function bindRaidCircle()
	local lobby = Workspace:FindFirstChild("RaidLobby")
	if not lobby then
		warn("[RaidClient] RaidLobby not found in Workspace")
		return
	end

	local raidCircle = lobby:FindFirstChild("RaidCircle")
	if not raidCircle or not raidCircle:IsA("BasePart") then
		warn("[RaidClient] RaidCircle not found or not a BasePart")
		return
	end

	local function onTouched(otherPart: BasePart)
		local character = localPlayer.Character
		if not character then
			return
		end

		if otherPart:IsDescendantOf(character) then
			debugPrint("player entered raid circle")
			if not isOpen then
				openRaidUI()
			end
		end
	end

	raidCircle.Touched:Connect(onTouched)
end

-- כפתור רייד
testRaidButton.MouseButton1Click:Connect(function()
	debugPrint("raid button clicked")
	statusLabel.Text = "Requesting teleport..."
	requestEvent:FireServer("TestRaid")
end)

-- כפתור סגירה
closeButton.MouseButton1Click:Connect(function()
	closeRaidUI()
end)

-- קבלת סטטוס מהשרת
statusEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local message = payload.message or ""
	local code = payload.code or ""

	statusLabel.Text = message

	if code == "ok" and payload.success then
		-- לפרוטוטייפ נסגור את ה-UI בעת התחלת טלפורט
		closeRaidUI()
	end
end)

-- חיבור ראשוני ל-RaidCircle
bindRaidCircle()

-- חיבור מחדש אחרי Respawn
localPlayer.CharacterAdded:Connect(function()
	task.wait(0.5)
	bindRaidCircle()
end)

