# מערכת Inventory – Sword Factory Tycoon

## 1. מבנה כללי

- **מקור האמת:** שרת. כל הנתונים נשמרים ב-InventoryService (בזיכרון ב-V1).
- **מבנה פריט:** `Id`, `Type`, `Amount` – מתאים לחומרים (כמות) ולפריטים כמו חרבות (כמות 1).
- **V1:** חומרים בלבד – CopperOre, IronOre, GoldOre. ללא DataStore.

**זרימה:**
- שחקן נכנס → Bootstrap יוצר Inventory ריק → שולח snapshot ללקוח.
- כל `AddItem` / `RemoveItem` בשרת → callback מעדכן את הלקוח (InventoryUpdated).
- הלקוח פותח חלון (I או כפתור) → RequestInventory מחזיר snapshot → מציג רשימה.

---

## 2. רשימת קבצים

| קובץ | סוג | תפקיד |
|------|-----|--------|
| `src/server/InventoryService.luau` | ModuleScript | נתונים + GetInventory, GetItemAmount, AddItem, RemoveItem, HasItem, GetItemsByType, GetDisplayName |
| `src/server/InventoryBootstrap.luau` | ModuleScript | Remotes, PlayerAdded/Removing, SetOnInventoryChanged, AddTestInventoryItems |
| `src/client/InventoryUIClient.client.luau` | LocalScript | UI: חלון, רשימה, מקש I, כפתור Inventory |
| `src/server/init.server.luau` | (קיים) | טוען את InventoryBootstrap |

**Remotes** (נוצרים ב-Bootstrap, תחת ReplicatedStorage):
- `InventoryRemotes/RequestInventory` (RemoteFunction)
- `InventoryRemotes/InventoryUpdated` (RemoteEvent)
- `InventoryRemotes/AddTestInventoryItems` (RemoteFunction – לבדיקה)

---

## 3. איפה כל קובץ ב-Explorer (Rojo)

- **ServerScriptService.Server:**  
  `InventoryService.luau`, `InventoryBootstrap.luau`, `init.server.luau` (וכן שאר המודולים הקיימים).
- **ReplicatedStorage:**  
  אחרי הרצה – תיקייה `InventoryRemotes` עם RequestInventory, InventoryUpdated, AddTestInventoryItems (השרת יוצר אותם).
- **StarterPlayer.StarterPlayerScripts.Client:**  
  `InventoryUIClient.client.luau` (ו-scripts קליינט אחרים).

---

## 4. הוראות בדיקה ב-Studio

1. **הרצת משחק (Play).**
2. **פתיחת Inventory:**  
   - ללחוץ **I** או על הכפתור **"Inventory (I)"** בפינה השמאלית העליונה.  
   - אמור להיפתח חלון "Inventory". בהתחלה הרשימה ריקה או עם הודעה "האינבנטורי ריק".
3. **הוספת פריטים לבדיקה (Command Bar או מהקליינט):**
   ```lua
   -- מה-Command Bar (שרת):
   local rf = game.ReplicatedStorage.InventoryRemotes.AddTestInventoryItems
   rf:InvokeServer("CopperOre", 10)   -- 10 Copper Ore
   rf:InvokeServer("IronOre", 5)      -- 5 Iron Ore
   rf:InvokeServer("GoldOre", 3)      -- 3 Gold Ore
   ```
   או מהקליינט (למשל ב-Command Bar כשהפוקוס על הקליינט):
   ```lua
   game.ReplicatedStorage.InventoryRemotes.AddTestInventoryItems:InvokeServer("CopperOre", 10)
   ```
4. **אימות:**  
   פתיחת חלון ה-Inventory שוב – אמורים להופיע הפריטים עם שם, סוג וכמות. ב-Output (שרת) אמורות להופיע הדפסות כמו `[Inventory] נוסף 10x CopperOre ל-...`.

---

## 5. Debug prints

- **InventoryService:**  
  נוצר Inventory, נוסף Item, הוסר Item.
- **InventoryBootstrap:**  
  RequestInventory מ-שחקן, נשלח InventoryUpdated, בדיקה AddTestInventoryItems.
- **InventoryUI (קליינט):**  
  נטען Inventory, InventoryUpdated.

(ניתן לכבות על ידי `DEBUG = false` / הסרת ההדפסות בקבצים הרלוונטיים.)

---

## 6. שימוש ממערכות אחרות

כדי להוסיף/להסיר פריטים מקוד שרת (למשל מכונה שמייצרת חומר, או SellZone):

```lua
local InventoryService = require(path.to.InventoryService)

-- הוספה
InventoryService.AddItem(player, "CopperOre", 1)

-- הסרה (למשל אחרי craft)
InventoryService.RemoveItem(player, "IronOre", 2)

-- בדיקה
if InventoryService.HasItem(player, "GoldOre", 5) then
  -- ...
end
```

אין צורך לקרוא ל-NotifyClient – ה-callback רשום ב-Bootstrap ומתעדכן אוטומטית אחרי AddItem/RemoveItem.

---

## 7. הרחבה עתידית

- **פריטים חדשים:** לעדכן את `ITEM_REGISTRY` ב-InventoryService (Id, Type, DisplayName).
- **חרבות:** להוסיף Type = "Sword" ו-Id כמו "BasicSword"; Amount בדרך כלל 1.
- **שמירה ל-DataStore:** להרחיב את Bootstrap או שירות נפרד – לשמור את `GetInventory(player)` ב-PlayerData ולטעון ב-PlayerAdded.
