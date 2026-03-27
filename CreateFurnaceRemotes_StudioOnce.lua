--[[
  הרצה חד-פעמית ב-Studio במצב עריכה – יוצר Remotes ו-OpenSwordFurnace ב-ReplicatedStorage.
  איך: View → Command Bar, הדבק והרץ, שמור (Ctrl+S).
  אחרי השמירה יופיעו ב-Explorer: ReplicatedStorage → Remotes → OpenSwordFurnace.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
	print("[CreateFurnaceRemotes] נוצרה תיקייה Remotes ב-ReplicatedStorage.")
else
	print("[CreateFurnaceRemotes] תיקיית Remotes כבר קיימת.")
end

if not remotes:FindFirstChild("OpenSwordFurnace") then
	local ev = Instance.new("RemoteEvent")
	ev.Name = "OpenSwordFurnace"
	ev.Parent = remotes
	print("[CreateFurnaceRemotes] נוצר RemoteEvent OpenSwordFurnace. שמור את ה-place (Ctrl+S).")
else
	print("[CreateFurnaceRemotes] OpenSwordFurnace כבר קיים.")
end
