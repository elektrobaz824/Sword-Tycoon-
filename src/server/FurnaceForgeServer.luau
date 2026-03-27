--[[
	FurnaceForgeServer – לוגיקת Forge בשרת.
	מקבל כמויות Copper/Iron/Gold, מחשב Score וסיכויים (דרך FurnaceChancesService),
	עושה RNG 1–100 ובוחר חרב אחת. לא מוסיף ל-Inventory – הקורא יקרא ל-InventoryService.AddItem.
]]

local FurnaceForgeServer = {}

local SWORD_ORDER = { "CopperSword", "IronSword", "GoldSword", "DiamondSword" }

-- @param FurnaceChancesService module (בעל ComputeChances)
-- @param copper number
-- @param iron number
-- @param gold number
-- @return number score, string swordName (או nil אם score = 0)
function FurnaceForgeServer.ExecuteForge(FurnaceChancesService: any, copper: number, iron: number, gold: number): (number, string?)
	local score, chances = FurnaceChancesService.ComputeChances(copper, iron, gold)
	if score <= 0 then
		return 0, nil
	end

	-- RNG: מספר אקראי 1–100, טווחות מצטברים לפי האחוזים
	local roll = math.random(1, 100)
	local cumulative = 0
	for _, swordName in SWORD_ORDER do
		local pct = chances[swordName] or 0
		cumulative = cumulative + pct
		if roll <= cumulative then
			return score, swordName
		end
	end
	-- fallback (לא אמור לקרות אם הסכום 100)
	return score, SWORD_ORDER[#SWORD_ORDER]
end

return FurnaceForgeServer
