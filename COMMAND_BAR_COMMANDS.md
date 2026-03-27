# פקודות Command Bar – ריכוז כל הפקודות במשחק

הרצה: **View → Command Bar** (או **Developer Console**), להדביק את השורה ולהריץ.

---

## מהקליינט (Client Command Bar)

כשהפוקוס על **Client** ב-Command Bar – הפקודות האלו רצות מהשחקן ומגיעות לשרת דרך Remotes.

| פקודה | מה עושה |
|--------|---------|
| `game.ReplicatedStorage.AddTestCoinsRF:InvokeServer(100)` | מוסיף 100 מטבעות לשחקן שלך. אפשר לשנות את המספר. דורש שנתוני השחקן כבר נטענו (אחרי Claim). |
| `game.ReplicatedStorage.ResetSave:InvokeServer()` | מאפס את **כל** השמירה של השחקן שלך (Coins=0, Pads ריק, Inventory ריק וכו'). |
| `game.ReplicatedStorage.Remotes.ResetStats:InvokeServer()` | מאפס **רק** את הסטטים: Level=1, XP=0, StatPoints=0, Strength=0, Health=0, Speed=0. לא נוגע במטבעות או ב-Inventory. |
| `game.ReplicatedStorage.Remotes.GiveTestStatPoints:InvokeServer(10)` | מוסיף נקודות סטט לבדיקה. **עובד רק לשחקן בשם "elektorbaz824"**. משמש לבדיקת כפתורי + ב-Stats. |
| `print(game.ReplicatedStorage.GiveTestXP:InvokeServer())` | מוסיף **50 XP** לבדיקה (ברירת מחדל; אפשר `InvokeServer(120)`). **חובה:** Command Bar על **Client** (לא Server) + **Play** + **Claim לפלוט** (אחרת תקבל `ok=false`, `reason=data_not_loaded`). `print` מראה אם הצליח. |
| `game.ReplicatedStorage.InventoryRemotes.AddTestInventoryItems:InvokeServer("CopperOre", 10)` | מוסיף 10 Copper Ore לאינבנטרי. אפשר להחליף ל־`"IronOre"`, `"GoldOre"` ולשנות כמות. |
| `game.ReplicatedStorage.InventoryRemotes.DebugPrintInventory:InvokeServer()` | מדפיס ב-Output (כ-warning) את רשימת החומרים באינבנטרי של השחקן. |

---

## מהשרת (Server Command Bar)

כשהפוקוס על **Server** ב-Command Bar – הפקודות האלו רצות בשרת. מתאימות כשאתה רוצה לשלוט על שחקן ספציפי או לבצע פעולה בשרת.

| פקודה | מה עושה |
|--------|---------|
| `game.ReplicatedStorage.AddTestCoins:Invoke(nil, 100)` | מוסיף 100 מטבעות לשחקן הראשון במשחק. `nil` = השחקן הראשון; אפשר להעביר `game.Players:GetPlayers()[1]` ושני פרמטר = כמות. |
| `game.ReplicatedStorage.SaveNow:Invoke(nil)` | מבצע שמירה ידנית של נתוני השחקן הראשון ל-DataStore. שימושי ב-Studio כשרוצים לשמור בלי לצאת. |
| `print(game.ReplicatedStorage.GiveTestXPServer:Invoke(game.Players:GetPlayers()[1], 50))` | מוסיף XP לשחקן מה**שרת** (BindableFunction). שחקן ראשון + 50 XP; אם אין Claim – `ok=false`. |
| `_G.SwordTycoonDebugBuyPadsRemoval = true` | **דיבאג:** אחרי ש-BuyPadService מחבר watch ל-`BuyPads`: `ChildRemoved`, `DescendantRemoving` (ילד ישיר או `ProximityPrompt`), שינוי `Parent` של תיקיית `BuyPads`, ומוניטור שמדפיס כש**מספר הילדים הישירים** משתנה. להריץ ב**שרת** לפני Play. אם אין שום `[BuyPadRemovalDebug]` בזמן Play והפדים “נעלמים” אחרי Stop — זה כמעט תמיד **מצב Edit** / שמירת מקום, לא מחיקה בקוד. |

---

## סיכום לפי נושא

### מטבעות ושמירה
- **הוספת מטבעות (מהקליינט):**  
  `game.ReplicatedStorage.AddTestCoinsRF:InvokeServer(100)`
- **הוספת מטבעות (מהשרת):**  
  `game.ReplicatedStorage.AddTestCoins:Invoke(nil, 100)`
- **שמירה ידנית (מהשרת):**  
  `game.ReplicatedStorage.SaveNow:Invoke(nil)`
- **איפוס שמירה מלא (מהקליינט):**  
  `game.ReplicatedStorage.ResetSave:InvokeServer()`

### סטטים
- **איפוס סטטים בלבד:**  
  `game.ReplicatedStorage.Remotes.ResetStats:InvokeServer()`
- **נקודות סטט לבדיקה (רק elektorbaz824):**  
  `game.ReplicatedStorage.Remotes.GiveTestStatPoints:InvokeServer(10)`
- **XP לבדיקה (Client, אחרי Claim):**  
  `print(game.ReplicatedStorage.GiveTestXP:InvokeServer())`
- **XP לבדיקה (Server):**  
  `print(game.ReplicatedStorage.GiveTestXPServer:Invoke(game.Players:GetPlayers()[1], 50))`

### אינבנטרי
- **הוספת חומרים לבדיקה:**  
  `game.ReplicatedStorage.InventoryRemotes.AddTestInventoryItems:InvokeServer("CopperOre", 10)`
- **הדפסת האינבנטרי:**  
  `game.ReplicatedStorage.InventoryRemotes.DebugPrintInventory:InvokeServer()`

---

## הערות

- **מהקליינט** – הפקודה רצה בהקשר של השחקן שבו אתה צופה (LocalPlayer), ולכן אין צורך לציין שחקן.
- **`GiveTestXP` לא עובד?** ודא שה-Command Bar מוגדר ל-**Client** (לא Server), שהמשחק ב-**Play**, ושעשית **Claim** לפלוט. מ-**Server** השתמש ב-`GiveTestXPServer:Invoke(...)` – `InvokeServer` לא רץ מהשרת כמו מהקליינט.
- **מהשרת** – ב-`Invoke(nil, ...)` ה-`nil` מחליף את השחקן; השרת ב-PlayerDataService לוקח את השחקן הראשון במשחק. אם יש שחקן אחד, זה תמיד הוא.
- GiveTestStatPoints מוגן לשם משתמש אחד בלבד (elektorbaz824) – אם תרצה לשנות, ערוך ב-`src/server/init.server.luau` את התנאי `player.Name ~= "elektorbaz824"`.
