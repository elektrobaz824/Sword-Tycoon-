--[[
	GameConfig - קונפיגורציה מרכזית (ברירות מחדל בלבד).
	השרת משתמש ב-AdminConfigService שמעתיק את זה ל-Runtime ומאפשר עדכון מהאדמין.
]]

local GameConfig = {}

-- רשימת UserIds של אדמינים. רק הם רואים את חלון ה-Config ויכולים לשנות ערכים.
-- איך למצוא את ה-UserId: ב-Roblox → פרופיל שלך → ה-URL מכיל מספר, או ב-Studio: Output → print(game.Players.LocalPlayer.UserId)
GameConfig.AdminUserIds = {
	1110466185, -- UserId שלך
}

-- ברירות המחדל לכל הערכים במשחק. מבנה מסודר להרחבה.
GameConfig.Default = {
	Machines = {
		Mechine1 = { SpawnInterval = 3, SellValue = 10 },
		Mechine2 = { SpawnInterval = 2, SellValue = 20 },
		Mechine3 = { SpawnInterval = 2, SellValue = 30 },
		Mechine4 = { SpawnInterval = 2, SellValue = 40 },
		Mechine5 = { SpawnInterval = 2, SellValue = 50 },
		Mechine6 = { SpawnInterval = 2, SellValue = 60 },
		Mechine7 = { SpawnInterval = 2, SellValue = 70 },
		Mechine8 = { SpawnInterval = 2, SellValue = 80 },
		Mechine9 = { SpawnInterval = 2, SellValue = 90 },
		Mechine10 = { SpawnInterval = 2, SellValue = 100 },
	},
	Materials = {
		Copper = { SellValue = 10 },
	},
	BuyPads = {
		Mechine2Pad = { Cost = 100 },
		Mechine3Pad = { Cost = 400 },
		Mechine4Pad = { Cost = 500 },
		Mechine5Pad = { Cost = 600 },
		Mechine6Pad = { Cost = 700 },
		Mechine7Pad = { Cost = 800 },
		Mechine8Pad = { Cost = 900 },
		Mechine9Pad = { Cost = 1000 },
		Mechine10Pad = { Cost = 1100 },
	},
	MaterialShop = {
		CopperOrePrice = 10,
		IronOrePrice = 25,
		GoldOrePrice = 50,
		CopperSwordSellPrice = 5,
		IronSwordSellPrice = 15,
		GoldSwordSellPrice = 40,
		DiamondSwordSellPrice = 100,
	},
	Furnace = {
		CopperWeight = 1,
		IronWeight = 5,
		GoldWeight = 10,
		ForgeTime = 3,
		Tier1Min = 1,
		Tier1Max = 5,
		Tier1CopperSword = 99,
		Tier1IronSword = 1,
		Tier1GoldSword = 0,
		Tier1DiamondSword = 0,
		Tier2Min = 6,
		Tier2Max = 15,
		Tier2CopperSword = 85,
		Tier2IronSword = 14,
		Tier2GoldSword = 1,
		Tier2DiamondSword = 0,
		Tier3Min = 16,
		Tier3Max = 30,
		Tier3CopperSword = 35,
		Tier3IronSword = 55,
		Tier3GoldSword = 9,
		Tier3DiamondSword = 1,
		Tier4Min = 31,
		Tier4Max = 50,
		Tier4CopperSword = 5,
		Tier4IronSword = 30,
		Tier4GoldSword = 55,
		Tier4DiamondSword = 10,
		Tier5Min = 51,
		Tier5Max = 999999,
		Tier5CopperSword = 0,
		Tier5IronSword = 15,
		Tier5GoldSword = 30,
		Tier5DiamondSword = 55,
	},
	Stats = {
		BaseHealth = 100,
		HealthPerPoint = 20,
		BaseWalkSpeed = 16,
		WalkSpeedPerPoint = 0.5,
		-- XP לרמה הבאה: ברמה 1 היעד הוא XPBaseForNextLevel (למשל 100), ואז בכל רמה מוסיפים XPIncreasePerLevel (למשל 50).
		XPBaseForNextLevel = 100,
		XPIncreasePerLevel = 50,
	},
}

-- בניית רשימת כל הנתיבים מהמבנה (מכונות 1–10, חומרים, פדים 2–10, Furnace)
local function buildConfigPaths()
	local paths = {}
	for i = 1, 10 do
		table.insert(paths, "Machines.Mechine" .. i .. ".SpawnInterval")
		table.insert(paths, "Machines.Mechine" .. i .. ".SellValue")
	end
	table.insert(paths, "Materials.Copper.SellValue")
	for i = 2, 10 do
		table.insert(paths, "BuyPads.Mechine" .. i .. "Pad.Cost")
	end
	-- MaterialShop – מחירי חומרים
	table.insert(paths, "MaterialShop.CopperOrePrice")
	table.insert(paths, "MaterialShop.IronOrePrice")
	table.insert(paths, "MaterialShop.GoldOrePrice")
	-- MaterialShop – מחירי מכירת חרבות
	table.insert(paths, "MaterialShop.CopperSwordSellPrice")
	table.insert(paths, "MaterialShop.IronSwordSellPrice")
	table.insert(paths, "MaterialShop.GoldSwordSellPrice")
	table.insert(paths, "MaterialShop.DiamondSwordSellPrice")
	-- Furnace – משקלי חומרים, זמן Forge, טווחים ואחוזים לכל Tier
	table.insert(paths, "Furnace.CopperWeight")
	table.insert(paths, "Furnace.IronWeight")
	table.insert(paths, "Furnace.GoldWeight")
	table.insert(paths, "Furnace.ForgeTime")
	for t = 1, 5 do
		local prefix = "Furnace.Tier" .. t
		table.insert(paths, prefix .. "Min")
		table.insert(paths, prefix .. "Max")
		table.insert(paths, prefix .. "CopperSword")
		table.insert(paths, prefix .. "IronSword")
		table.insert(paths, prefix .. "GoldSword")
		table.insert(paths, prefix .. "DiamondSword")
	end
	-- Stats – Health/Speed character application
	table.insert(paths, "Stats.BaseHealth")
	table.insert(paths, "Stats.HealthPerPoint")
	table.insert(paths, "Stats.BaseWalkSpeed")
	table.insert(paths, "Stats.WalkSpeedPerPoint")
	table.insert(paths, "Stats.XPBaseForNextLevel")
	table.insert(paths, "Stats.XPIncreasePerLevel")
	return paths
end
GameConfig.ConfigPaths = buildConfigPaths()

return GameConfig
