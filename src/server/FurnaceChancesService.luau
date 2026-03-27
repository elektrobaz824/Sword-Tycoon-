--[[
	FurnaceChancesService – חישוב סיכויי חרבות לפי כמויות Copper/Iron/Gold.
	קורא Ore Weights ו-Tiers מ-AdminConfig (קטגוריית Furnace). ברירות מחדל אם אין Config.
	Score = copper*CopperWeight + iron*IronWeight + gold*GoldWeight.
]]

local FurnaceChancesService = {}

local ZERO_CHANCES = {
	CopperSword = 0,
	IronSword = 0,
	GoldSword = 0,
	DiamondSword = 0,
}

local FURNACE_DEBUG = true
local function debugPrint(msg: string)
	if FURNACE_DEBUG then
		print("[Furnace Config] " .. msg)
	end
end

local function getAdminConfig()
	if _G.SwordTycoonAdminConfig then
		return _G.SwordTycoonAdminConfig
	end
	return nil
end

-- מחזיר משקלי חומרים מה-Config (או ברירות מחדל). מאמת >= 0.
local function getWeights(): { Copper: number, Iron: number, Gold: number }
	local admin = getAdminConfig()
	local cw = 1
	local iw = 5
	local gw = 10
	if admin then
		local v, ok = admin.GetValue("Furnace.CopperWeight")
		if ok and type(v) == "number" and v >= 0 then cw = v end
		v, ok = admin.GetValue("Furnace.IronWeight")
		if ok and type(v) == "number" and v >= 0 then iw = v end
		v, ok = admin.GetValue("Furnace.GoldWeight")
		if ok and type(v) == "number" and v >= 0 then gw = v end
	end
	return { Copper = cw, Iron = iw, Gold = gw }
end

-- מחזיר טבלת Tiers מה-Config. כל tier: min, max, CopperSword, IronSword, GoldSword, DiamondSword. מאמת min<=max, chances>=0, מדפיס warning אם סכום != 100.
local function getTiers(): { { min: number, max: number, CopperSword: number, IronSword: number, GoldSword: number, DiamondSword: number } }
	local admin = getAdminConfig()
	local tiers = {}
	for t = 1, 5 do
		local prefix = "Furnace.Tier" .. t
		local minVal, maxVal = 1, 5
		local cS, iS, gS, dS = 99, 1, 0, 0
		if t == 2 then minVal, maxVal, cS, iS, gS, dS = 6, 15, 85, 14, 1, 0
		elseif t == 3 then minVal, maxVal, cS, iS, gS, dS = 16, 30, 35, 55, 9, 1
		elseif t == 4 then minVal, maxVal, cS, iS, gS, dS = 31, 50, 5, 30, 55, 10
		elseif t == 5 then minVal, maxVal, cS, iS, gS, dS = 51, 999999, 0, 15, 30, 55
		end
		if admin then
			local v, ok = admin.GetValue(prefix .. "Min")
			if ok and type(v) == "number" then minVal = math.max(0, v) end
			v, ok = admin.GetValue(prefix .. "Max")
			if ok and type(v) == "number" then maxVal = math.max(0, v) end
			if maxVal < minVal then
				debugPrint("Invalid Tier" .. t .. " range: max < min, using min=" .. tostring(minVal) .. " max=" .. tostring(minVal))
				maxVal = minVal
			end
			v, ok = admin.GetValue(prefix .. "CopperSword")
			if ok and type(v) == "number" and v >= 0 then cS = v end
			v, ok = admin.GetValue(prefix .. "IronSword")
			if ok and type(v) == "number" and v >= 0 then iS = v end
			v, ok = admin.GetValue(prefix .. "GoldSword")
			if ok and type(v) == "number" and v >= 0 then gS = v end
			v, ok = admin.GetValue(prefix .. "DiamondSword")
			if ok and type(v) == "number" and v >= 0 then dS = v end
			local sum = cS + iS + gS + dS
			if sum ~= 100 then
				debugPrint("Tier" .. t .. " chances sum = " .. tostring(sum) .. " (expected 100)")
			end
		end
		table.insert(tiers, { min = minVal, max = maxVal, CopperSword = cS, IronSword = iS, GoldSword = gS, DiamondSword = dS })
	end
	return tiers
end

-- @param copper number
-- @param iron number
-- @param gold number
-- @return number score, { CopperSword, IronSword, GoldSword, DiamondSword }
function FurnaceChancesService.ComputeChances(copper: number, iron: number, gold: number): (number, { [string]: number })
	copper = math.max(0, tonumber(copper) or 0)
	iron = math.max(0, tonumber(iron) or 0)
	gold = math.max(0, tonumber(gold) or 0)

	local weights = getWeights()
	local score = copper * weights.Copper + iron * weights.Iron + gold * weights.Gold
	if score <= 0 then
		return 0, ZERO_CHANCES
	end

	local tiers = getTiers()
	for _, tier in tiers do
		if score >= tier.min and score <= tier.max then
			return score, {
				CopperSword = tier.CopperSword,
				IronSword = tier.IronSword,
				GoldSword = tier.GoldSword,
				DiamondSword = tier.DiamondSword,
			}
		end
	end

	return score, ZERO_CHANCES
end

return FurnaceChancesService
