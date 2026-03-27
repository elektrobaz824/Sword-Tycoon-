# Material Shop – Sword Factory Tycoon

## 1. מבנה כללי

- **MaterialShopService (שרת):** טבלת מחירים (CopperOre 10, IronOre 25, GoldOre 50), יוצר Remotes (BuyMaterial, BuyMaterialResult), מטפל ב-OnServerEvent של BuyMaterial: בודק Coins (PlayerDataService), מוריד מטבעות, מוסיף חומר ל-Inventory (InventoryService), שולח תוצאה ללקוח.
- **MaterialShopClient (לקוח):** מחפש NPC בשם MaterialShopNPC ב-Workspace, מתחבר ל-ProximityPrompt (תחת Head או כל descendant), בלחיצה פותח GUI. כפתור לכל חומר + Close. לחיצה על חומר → FireServer(BuyMaterial, itemId). מאזין ל-BuyMaterialResult ומציג הודעת הצלחה/כישלון.

לא משכתב Coins, Inventory, Claim, Machines, BuyPads או SellZone – רק מחבר אליהם.

---

## 2. רשימת קבצים

| קובץ | תפקיד |
|------|--------|
| `src/server/MaterialShopService.luau` | מחירים, TryPurchase, Remotes, חיבור ל-PDS ו-Inventory |
| `src/client/MaterialShopClient.client.luau` | ProximityPrompt, בניית MaterialShopGui, כפתורים, שליחת קנייה והצגת תוצאה |
| `src/server/init.server.luau` | טוען MaterialShopService ומפעיל Init() |

**Remotes (נוצרים בשרת):**  
`ReplicatedStorage.Remotes.BuyMaterial` (RemoteEvent), `BuyMaterialResult` (RemoteEvent).

---

## 3. איפה ב-Explorer (Rojo)

- **ServerScriptService.Server:** `MaterialShopService.luau`, `init.server.luau`
- **StarterPlayer.StarterPlayerScripts.Client:** `MaterialShopClient.client.luau`
- **ReplicatedStorage:** אחרי הרצה – תיקייה `Remotes` עם `BuyMaterial`, `BuyMaterialResult`
- **Workspace:** צריך NPC בשם **MaterialShopNPC** עם ProximityPrompt (למשל תחת Head)

---

## 4. הוראות בדיקה ב-Studio

1. **וידוא NPC:** ב-Workspace קיים `MaterialShopNPC`, ובתוכו (למשל ב-Head) יש `ProximityPrompt`.
2. **הרצת משחק (Play).**
3. **מטבעות לבדיקה:** אם צריך, ב-Command Bar:  
   `game.ReplicatedStorage.AddTestCoinsRF:InvokeServer(100)`  
   (או להשתמש במערכת הקיימת שלך.)
4. **Claim Plot** אם נדרש כדי ש-PlayerDataService יטען ו-Coins יופיעו.
5. **התקרבות ל-NPC** והפעלת ה-ProximityPrompt – אמור להיפתח חלון "Material Shop" עם שלושה כפתורים (Copper Ore, Iron Ore, Gold Ore) ומחירים.
6. **לחיצה על Copper Ore (10 Coins):** אם יש ≥10 מטבעות – Coins יורדים, CopperOre נוסף ל-Inventory, מופיעה הודעה "Purchased!". אם אין מספיק – הודעה "Not enough coins".
7. **סגירה:** כפתור Close סוגר את החלון.

ב-Output (שרת) אמורות להופיע הדפסות כמו:  
`[MaterialShop] בקשת קנייה: ... – CopperOre`  
`[MaterialShop] קנייה הצליחה: ... קנה CopperOre`  
או `[MaterialShop] לא מספיק מטבעות...`.

---

## 5. הרחבה

- **מחירים:** לערוך את הטבלה `MATERIAL_PRICES` ב-`MaterialShopService.luau`.
- **חומרים חדשים:** להוסיף ל-`MATERIAL_PRICES` ולוודא שהפריט קיים ב-InventoryService (ITEM_REGISTRY). בלקוח להוסיף שורה ל-`MATERIALS` ב-`MaterialShopClient.client.luau`.
