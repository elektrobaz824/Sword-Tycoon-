# Coins + Save – מבנה והתחברות

## 1. מבנה תיקיות (Rojo → Roblox)

```
ServerScriptService
  Server/                    ← src/server
    init.server.luau         → Script (init.server)
    PlotClaimService.luau   → ModuleScript
    PlayerDataService.luau   → ModuleScript
```

- **init.server** – טוען קודם את PlayerDataService.Init(), אחר כך PlotClaimService.Init().
- **PlotClaimService** – מערכת ה-Claim הקיימת; אחרי Claim מוצלח קורא ל-`PlayerDataService.LoadPlayerData(player)`.
- **PlayerDataService** – DataStore, טעינה/שמירה, leaderstats (Coins), Auto Save כל 60 שניות.

## 2. מה כל סקריפט עושה

| קובץ | תפקיד |
|------|--------|
| **init.server.luau** | מריץ `PlayerDataService.Init()` (אוטו-סייב + PlayerRemoving), אחר כך `PlotClaimService.Init()`. |
| **PlotClaimService.luau** | Claim לפלטפורמות. אחרי Claim מוצלח קורא ל-`PlayerDataService.LoadPlayerData(player)` – רק אז נטענים Coins ונוצר leaderstats. |
| **PlayerDataService.luau** | טעינה מ-DataStore רק דרך `LoadPlayerData(player)` (לא ב-PlayerAdded). שמירה ב-PlayerRemoving ובאוטו-סייב כל 60 שניות. יוצר `leaderstats` עם Coins. |

## 3. חיבור ל-Claim

כבר מחובר. ב-**PlotClaimService**:

- אחרי `tryClaim` מוצלח נקראת `onPlotClaimed(player, plot)`.
- בתוך `onPlotClaimed` מתבצעת קריאה ל-`PlayerDataService.LoadPlayerData(player)`.

אין צורך לשנות שום דבר – הטעינה מתבצעת אוטומטית אחרי Claim מוצלח.

## 4. API של PlayerDataService (לשימוש ממודולים אחרים)

- **LoadPlayerData(player)** – טוען נתונים מהשרת (או defaults), יוצר leaderstats. קוראים פעם אחת אחרי Claim.
- **SavePlayerData(player)** – שומר ל-DataStore. נקרא אוטומטית ב-PlayerRemoving ובאוטו-סייב.
- **GetPlayerData(player)** – מחזיר טבלת הנתונים (למשל `{ Coins = 0 }`) או nil אם עדיין לא נטען.
- **SetCoins(player, amount)** – מעדכן Coins ומסנכרן ל-leaderstats (למשל ממערכת מכונות/מכירה בעתיד).
- **IsDataLoaded(player)** – האם הנתונים כבר נטענו.

## 5. איך לבדוק ב-Play Test

1. **הפעל את המשחק** (Play / Run).
2. **עשה Claim** – גע ב-Plot (או ב-ClaimPart) עד ש-Claim מצליח.
3. **בדוק leaderstats** – מעל ה-head של הדמות אמור להופיע **Coins** עם ערך (ברירת מחדל 0).
4. **שינוי Coins (לבדיקה)** – מסקריפט שרת:
   ```lua
   local PlayerDataService = require(script.Parent.PlayerDataService)
   -- אחרי שהשחקן עשה Claim:
   PlayerDataService.SetCoins(player, 100)
   ```
   אחרי זה ב-leaderstats יופיע 100.
5. **יציאה מהמשחק** – השחקן יוצא (Stop). נכנס שוב, עושה Claim שוב – ה-Coins שהיו אמורים להישמר (למשל 100) אמורים להיטען.
6. **אוטו-סייב** – כל 60 שניות נשמרים נתוני כל השחקנים שנטענו; אין צורך לעשות דבר.

## 6. הרחבה בעתיד

מבנה הנתונים ב-**PlayerDataService** מוגדר ב-`DEFAULT_DATA` (כרגע רק `Coins`). כדי להוסיף שדות (Machines, Inventory, Materials):

- להוסיף ל-`DEFAULT_DATA` ערכי ברירת מחדל.
- ב-`mergeWithDefault` כבר מתמזגים שדות קיימים מהשמירה – שדות חדשים יקבלו default.
- לשמור/לטעון עם `SetAsync`/`GetAsync` את הטבלה המלאה – אין צורך לשנות לוגיקת שמירה.
