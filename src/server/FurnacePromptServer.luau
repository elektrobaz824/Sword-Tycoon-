--[[
	FurnacePromptServer – מחבר את ה-ProximityPrompt של התנור ל-RemoteEvent לפתיחת ה-UI.
	מחפש Workspace.SwordFurnace.PromptPart.ProximityPrompt.
	יוצר ReplicatedStorage.Remotes ו-OpenSwordFurnace אם לא קיימים (כדי שהקליינט תמיד ימצא).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local openFurnaceEvent = remotesFolder:FindFirstChild("OpenSwordFurnace")
if not openFurnaceEvent or not openFurnaceEvent:IsA("RemoteEvent") then
	if openFurnaceEvent then
		openFurnaceEvent:Destroy()
	end
	openFurnaceEvent = Instance.new("RemoteEvent")
	openFurnaceEvent.Name = "OpenSwordFurnace"
	openFurnaceEvent.Parent = remotesFolder
end

local furnace = Workspace:WaitForChild("SwordFurnace", 10)
if not furnace then
	warn("[FurnacePromptServer] Workspace.SwordFurnace לא נמצא. הוסף Model/Folder בשם SwordFurnace עם PromptPart ובתוכו ProximityPrompt.")
	return
end

print("[FurnacePromptServer] נמצא SwordFurnace, מחפש ProximityPrompt...")

local promptPart = furnace:FindFirstChild("PromptPart")
local prompt: ProximityPrompt? = nil
if promptPart then
	prompt = promptPart:IsA("ProximityPrompt") and promptPart or promptPart:FindFirstChildOfClass("ProximityPrompt")
end
if not prompt then
	-- fallback: כל ProximityPrompt בתוך התנור
	prompt = furnace:FindFirstChildWhichIsA("ProximityPrompt", true)
end
if not prompt then
	warn("[FurnacePromptServer] ProximityPrompt לא נמצא. הוסף PromptPart עם ProximityPrompt, או ProximityPrompt בתוך SwordFurnace. שמות הילדים:", table.concat((function()
		local t = {}
		for _, c in furnace:GetChildren() do table.insert(t, c.Name) end
		return t
	end)(), ", "))
	return
end

prompt.Triggered:Connect(function(player: Player)
	print("Furnace prompt triggered by", player.Name)
	openFurnaceEvent:FireClient(player)
end)

print("[FurnacePromptServer] מחובר – ProximityPrompt שולח OpenSwordFurnace לשחקן.")
