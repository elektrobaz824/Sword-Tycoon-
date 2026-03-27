--[[
	PlotClaimService - מערכת Claim לפלטפורמות
	Server-side only. משתמש ב-Attributes על ה-Plot לשמירת בעלות.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local PlotClaimService = {}

-- מחפש את PlayerDataService בכל ServerScriptService (עובד גם אם המבנה שונה)
local function getPlayerDataService()
	for _, desc in ServerScriptService:GetDescendants() do
		if desc:IsA("ModuleScript") and desc.Name == "PlayerDataService" then
			return require(desc)
		end
	end
	return nil
end

local function getPlotSetupService()
	for _, desc in ServerScriptService:GetDescendants() do
		if desc:IsA("ModuleScript") and desc.Name == "PlotSetupService" then
			return require(desc)
		end
	end
	return nil
end

local function getInventoryService()
	for _, desc in ServerScriptService:GetDescendants() do
		if desc:IsA("ModuleScript") and desc.Name == "InventoryService" then
			return require(desc)
		end
	end
	return nil
end

local function getStatsApplyService()
	if _G.SwordTycoonStatsApplyService then
		return _G.SwordTycoonStatsApplyService
	end
	for _, desc in ServerScriptService:GetDescendants() do
		if desc:IsA("ModuleScript") and desc.Name == "StatsApplyService" then
			return require(desc)
		end
	end
	return nil
end

-- שם ה-Attribute על כל Plot: UserId של הבעלים (nil = פנוי)
local OWNER_ATTRIBUTE = "OwnerUserId"

-- שם ה-Part או ה-ProximityPrompt בתוך כל Plot שמפעיל Claim
local CLAIM_PART_NAME = "ClaimPart"

-- [Player] -> Plot (Model או Part)
local playerToPlot: { [Player]: Instance } = {}
-- [Plot] -> Player
local plotToPlayer: { [Instance]: Player } = {}
-- קוּלדאון להודעת "כבר יש לך Plot" – הודעה אחת ל-10 שניות לשחקן
local COOLDOWN_SECONDS = 10
local lastAlreadyHasPlotMessage: { [Player]: number } = {}

-- מעדכן HUD סטטים בקליינט (HP/XP bars + פאנל) אחרי שיש נתונים בשרת
local function notifyStatsReady(player: Player)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local ev = remotes and remotes:FindFirstChild("StatsUpdated")
	if ev and ev:IsA("RemoteEvent") then
		ev:FireClient(player)
	end
end

-- נקרא אחרי Claim מוצלח – טוען נתונים, מרענן leaderstats, משחזר Inventory, ומגדיר Plot (מכונה ראשונה וכו')
local function onPlotClaimed(player: Player, plot: Instance)
	local pds = getPlayerDataService()
	if pds then
		local data = pds.LoadPlayerData(player)
		if data then
			pds.RefreshLeaderstats(player)
			local invSvc = getInventoryService()
			if invSvc and invSvc.LoadFromSave then
				local savedInv = type(data.Inventory) == "table" and data.Inventory or {}
				local n = 0
				for _ in pairs(savedInv) do n = n + 1 end
				if n > 0 then
					print("[PlotClaim] טוען " .. tostring(n) .. " סוגי חומרים מ-Inventory לשחקן " .. player.Name)
				end
				invSvc.LoadFromSave(player, savedInv)
			end
		end
	end
	local plotSetup = getPlotSetupService()
	if plotSetup then
		plotSetup.SetupPlotForPlayer(player, plot)
	end
	-- Apply Health/Speed stats to character after data loaded
	local statsApply = getStatsApplyService()
	if statsApply and statsApply.ApplyToCharacter then
		statsApply.ApplyToCharacter(player)
	end
	notifyStatsReady(player)
end

local function getPlayerFromCharacter(part: BasePart): Player?
	local character = part:FindFirstAncestorOfClass("Model")
	if not character then return nil end
	return Players:GetPlayerFromCharacter(character)
end

local function tryClaim(player: Player, plot: Instance): boolean
	-- כבר יש לשחקן פלטפורמה
	if playerToPlot[player] then
		-- הודעה רק אם נוגע ב-Plot *אחר* (לא ב-Plot שלו), ומקסימום פעם ב-10 שניות
		if playerToPlot[player] ~= plot then
			local now = tick()
			local last = lastAlreadyHasPlotMessage[player] or 0
			if now - last >= COOLDOWN_SECONDS then
				print("[PlotClaim] " .. player.Name .. " כבר יש לך Plot (" .. playerToPlot[player].Name .. "). לא ניתן לקחת Plot נוסף.")
				lastAlreadyHasPlotMessage[player] = now
			end
		end
		return false
	end
	-- הפלטפורמה כבר תפוסה
	if plotToPlayer[plot] then
		return false
	end
	-- קבע בעלות
	plot:SetAttribute(OWNER_ATTRIBUTE, player.UserId)
	plotToPlayer[plot] = player
	playerToPlot[player] = plot
	print("[PlotClaim] " .. player.Name .. " תפס Plot: " .. plot.Name)
	onPlotClaimed(player, plot)
	return true
end

local function releasePlot(plot: Instance)
	local owner = plotToPlayer[plot]
	if owner then
		plot:SetAttribute(OWNER_ATTRIBUTE, nil)
		plotToPlayer[plot] = nil
		playerToPlot[owner] = nil
	end
end

local function setupPlot(plot: Instance)
	-- אם יש ילד ClaimPart – משתמשים בו. אם ה-Plot עצמו Part בלי ילדים – נוגעים ב-Plot כדי לעשות Claim
	local claimPart = plot:FindFirstChild(CLAIM_PART_NAME)
	if not claimPart and plot:IsA("BasePart") then
		-- Plot הוא Part בלי ClaimPart – הנגיעה ב-Plot עצמו מפעילה Claim
		plot.Touched:Connect(function(hit: BasePart)
			local player = getPlayerFromCharacter(hit)
			if not player then return end
			tryClaim(player, plot)
		end)
		return
	end
	if not claimPart then return end

	if claimPart:IsA("ProximityPrompt") then
		claimPart.Triggered:Connect(function(playerWhoTriggered: Player)
			if tryClaim(playerWhoTriggered, plot) then
				-- הצלחה – אולי להציג הודעה (השרת יכול לשלוח RemoteEvent)
			end
		end)
	elseif claimPart:IsA("BasePart") then
		claimPart.Touched:Connect(function(hit: BasePart)
			local player = getPlayerFromCharacter(hit)
			if not player then return end
			tryClaim(player, plot)
		end)
	end
end

function PlotClaimService.Init()
	local plotsFolder = Workspace:WaitForChild("Plots", 10)
	if not plotsFolder then
		warn("[PlotClaimService] Workspace.Plots לא נמצא! צור Folder בשם Plots ותשים בו את ה-Plots (Model או Part).")
		return
	end
	print("[PlotClaimService] Plots נמצא, מגדיר " .. #plotsFolder:GetChildren() .. " Plot(s)")

	for _, child in plotsFolder:GetChildren() do
		if child:IsA("Model") or child:IsA("BasePart") then
			-- טען state קיים מהמשחק (אם השרת התחיל מחדש – ה-Attribute מאפס)
			local ownerId = child:GetAttribute(OWNER_ATTRIBUTE)
			if ownerId and type(ownerId) == "number" then
				local owner = Players:GetPlayerByUserId(ownerId)
				if owner then
					plotToPlayer[child] = owner
					playerToPlot[owner] = child
					local pds = getPlayerDataService()
					if pds then
						pds.LoadPlayerData(owner)
						local data = pds.GetPlayerData(owner)
						if data then
							local invSvc = getInventoryService()
							if invSvc and invSvc.LoadFromSave then
								invSvc.LoadFromSave(owner, type(data.Inventory) == "table" and data.Inventory or {})
							end
						end
					end
					-- משחזר מבנה Plot ומכונה ראשונה + Pads שנרכשו (מכונות)
					local plotSetup = getPlotSetupService()
					if plotSetup then
						plotSetup.SetupPlotForPlayer(owner, child)
					end
					local statsApply = getStatsApplyService()
					if statsApply and statsApply.ApplyToCharacter then
						statsApply.ApplyToCharacter(owner)
					end
					notifyStatsReady(owner)
				else
					child:SetAttribute(OWNER_ATTRIBUTE, nil)
				end
			end
			setupPlot(child)
		end
	end

	plotsFolder.ChildAdded:Connect(function(child)
		if child:IsA("Model") or child:IsA("BasePart") then
			setupPlot(child)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastAlreadyHasPlotMessage[player] = nil
		local plot = playerToPlot[player]
		if plot then
			releasePlot(plot)
		end
	end)
end

-- API לשימוש ממערכות אחרות
function PlotClaimService.GetPlayerPlot(player: Player): Instance?
	return playerToPlot[player]
end

function PlotClaimService.GetPlotOwner(plot: Instance): Player?
	return plotToPlayer[plot]
end

function PlotClaimService.PlayerHasPlot(player: Player): boolean
	return playerToPlot[player] ~= nil
end

return PlotClaimService
