# חיבור מערכות קיימות ל-GameConfig

המערכות במשחק יכולות לקרוא ערכים מ-AdminConfigService במקום מספרים קשיחים. כך עושים את זה בהדרגה.

## איך לקבל את AdminConfigService בשרת

```lua
local ServerScriptService = game:GetService("ServerScriptService")
local function getAdminConfigService()
	for _, desc in ServerScriptService:GetDescendants() do
		if desc:IsA("ModuleScript") and desc.Name == "AdminConfigService" then
			return require(desc)
		end
	end
	return nil
end
local AdminConfig = getAdminConfigService()
```

## קריאת ערך

```lua
local val, ok = AdminConfig.GetValue("Machines.Mechine1.SpawnInterval")
if ok and type(val) == "number" then
	-- השתמש ב-val
else
	-- ברירת מחדל אם המודול לא טעון או הערך חסר
	val = 5
end
```

---

## 1. PlotSetupService – SpawnInterval ו-SellValue

**קובץ:** `src/server/PlotSetupService.luau`

- **COPPER_PRODUCTION_INTERVAL** (שורה ~23): במקום קבוע 5, קרא:
  `AdminConfig.GetValue("Machines.Mechine1.SpawnInterval")` (או לפי מספר מכונה).
- **startCopperProduction** – הערך `value` (SellValue): במקום חישוב מקומי, קרא:
  - מכונה 1: `AdminConfig.GetValue("Machines.Mechine1.SellValue")`
  - מכונה 2: `AdminConfig.GetValue("Machines.Mechine2.SellValue")`
  - או: `AdminConfig.GetValue("Materials.Copper.SellValue")` אם אתה רוצה ערך אחיד ל-Copper.

**דוגמה (רק לוגיקה, לא להדביק-is):**

```lua
local interval, ok = AdminConfig and AdminConfig.GetValue("Machines.Mechine1.SpawnInterval")
local waitTime = (ok and type(interval) == "number" and interval > 0) and interval or COPPER_PRODUCTION_INTERVAL
task.wait(waitTime)
```

---

## 2. SellZoneService – ערך מכירת Copper

**קובץ:** `src/server/SellZoneService.luau`

- **COPPER_SELL_VALUE** (שורה ~14): כרגע משמש fallback כשאין Attribute על ה-Copper.
- בתחילת `onSellZoneTouched`, לפני השימוש ב-`sellValue`:
  אם אין Attribute על ה-Copper, קרא:
  `AdminConfig.GetValue("Materials.Copper.SellValue")` ו-use כ-fallback במקום `COPPER_SELL_VALUE`.

**דוגמה:**

```lua
local sellValue = copperInstance:GetAttribute(SELL_VALUE_ATTRIBUTE)
if type(sellValue) ~= "number" or sellValue < 0 then
	local configVal, ok = AdminConfig and AdminConfig.GetValue("Materials.Copper.SellValue")
	sellValue = (ok and type(configVal) == "number") and configVal or COPPER_SELL_VALUE
end
```

---

## 3. BuyPadService – מחיר Pad

**קובץ:** `src/server/BuyPadService.luau`

- **getCostForPad**: אחרי בדיקת Attribute, במקום `COST_BY_MACHINE_NUMBER[num]` קרא מהקונפיג:
  - Pad בשם "Mechine2Pad" → `AdminConfig.GetValue("BuyPads.Mechine2Pad.Cost")`
  - אפשר לבנות path: `"BuyPads." .. pad.Name .. ".Cost"` (כי ב-GameConfig יש BuyPads.Mechine2Pad, Mechine3Pad וכו').

**דוגמה:**

```lua
local path = "BuyPads." .. pad.Name .. ".Cost"
local configCost, ok = AdminConfig and AdminConfig.GetValue(path)
if ok and type(configCost) == "number" and configCost >= 0 then
	return configCost
end
-- fallback ל-COST_BY_MACHINE_NUMBER כרגיל
```

---

## סדר טעינה

- `AdminConfigService.Init()` רץ ב-`init.server.luau` אחרי שאר השירותים.
- אם שירות אחר רץ לפניו, `getAdminConfigService()` עלול להחזיר nil – לכן תמיד בדוק `if AdminConfig` והשתמש ב-fallback (הערך הקשיח הישן).

## הוספת שדות חדשים

1. ב-`src/shared/GameConfig.luau`: הוסף ל-`Default` (למשל `Machines.Mechine3.SpawnInterval`) ולהוסף את הנתיב ל-`ConfigPaths`.
2. בחלון האדמין יופיע השדה החדש אחרי רענון.
3. בשרת קרא עם `AdminConfig.GetValue("Machines.Mechine3.SpawnInterval")`.
