# מערכת Claim לפלטפורמות – Sword Factory Tycoon

## 1. Folder Structure

### ב-Roblox Studio (Workspace)
```
Workspace
└── Plots (Folder)          ← יוצרים ידנית
    ├── Plot1 (Model)        ← המודלים שלך
    ├── Plot2 (Model)
    └── ...
```

### בפרויקט (Rojo / קבצים)
```
src/server/
├── init.server.luau        ← טוען את PlotClaimService
└── PlotClaimService.luau   ← הלוגיקה של ה-Claim
```

ב-Roblox (אם לא משתמשים ב-Rojo):
```
ServerScriptService
├── PlotClaimService (ModuleScript)   ← להדביק את תוכן PlotClaimService.luau
└── Server (Script)                   ← טוען: require(script.Parent.PlotClaimService).Init()
```

---

## 2. איך להכין כל Plot במפה

1. **תיקייה Plots**  
   ב-Workspace: ימני → Insert Object → **Folder**. שם: **Plots**.

2. **כל פלטפורמה = Model**  
   ימני על **Plots** → Insert Object → **Model**.  
   שם לדוגמה: Plot1, Plot2 וכו' (השם לא משנה למערכת).

3. **אזור ה-Claim בתוך כל Plot**  
   ימני על **ה-Model של הפלטפורמה** → Insert Object.  
   **חובה** שיהיה אובייקט אחד עם השם **בדיוק**: **ClaimPart**.

   **אפשרות א – Part (נגיעה):**
   - Insert Object → **Part**.
   - שנה שם ל-**ClaimPart**.
   - מקמם על הפלטפורמה איפה שהשחקן אמור לגעת כדי לעשות Claim.

   **אפשרות ב – ProximityPrompt:**
   - Insert Object → **ProximityPrompt** (תחת Part או ישירות תחת ה-Model).
   - אם הוא ילד של Part – שם ה-**Part** או ה-**ProximityPrompt** חייב להיות **ClaimPart**.  
     (המערכת מחפשת `FindFirstChild("ClaimPart")` – אם זה Part משתמשים ב-Touched, אם זה ProximityPrompt ב-Triggered.)
   - עדיף לתת ל-**Part** את השם **ClaimPart**, ולשים את ה-ProximityPrompt כבן של אותו Part.

**סיכום מבנה לכל Plot:**
```
Plots (Folder)
└── Plot1 (Model)
    └── ClaimPart (Part)     ← חובה. או Part עם Touched, או Part + ProximityPrompt כילד
```

אם אתה משתמש ב-ProximityPrompt – או ש-**ClaimPart** הוא ה-Part (ואז נשתמש ב-Touched עליו), או ש-**ClaimPart** הוא ה-ProximityPrompt עצמו. בקוד הנוכחי: אם `claimPart:IsA("ProximityPrompt")` אז משתמשים ב-Triggered, אחרת ב-Touched. אז אפשר:
- Part בשם ClaimPart → Claim בנגיעה.
- ProximityPrompt בשם ClaimPart (ילד של ה-Model) → Claim בהפעלת ה-Prompt.

---

## 3. הסקריפטים המלאים

### PlotClaimService.luau (ModuleScript)
הקובץ כבר בפרויקט: `src/server/PlotClaimService.luau`.  
אם לא משתמשים ב-Rojo – להעתיק את התוכן ל-ModuleScript חדש ב-ServerScriptService בשם **PlotClaimService**.

### init.server.luau (Script)
הקובץ כבר מעודכן: `src/server/init.server.luau`.  
תוכן רלוונטי:
```lua
local PlotClaimService = require(script.Parent.PlotClaimService)
PlotClaimService.Init()
print("Server loaded!")
```
אם לא משתמשים ב-Rojo – ב-Script ש� רץ ראשון ב-ServerScriptService:
```lua
local PlotClaimService = require(script.Parent.PlotClaimService)
PlotClaimService.Init()
```

---

## 4. איך זה עובד

- **בטעינה:** הסקריפט מחפש `Workspace.Plots`. לכל **Model** בתוך Plots הוא מחפש **ClaimPart** (Part או ProximityPrompt). על כל Plot משתמשים ב-**Attribute** בשם `OwnerUserId` – אם יש ערך, הפלטפורמה תפוסה; אם אין, פנויה.
- **Claim:** שחקן נוגע ב-ClaimPart או מפעיל ProximityPrompt. השרת בודק: (1) לשחקן עדיין אין פלטפורמה, (2) לפלטפורמה עדיין אין בעלים. אם שני התנאים מתקיימים – מגדירים `OwnerUserId` על ה-Plot, שומרים במערכת ש-player X הבעלים של plot Y, וקוראים ל-`onPlotClaimed(player, plot)` – שם יש היום `print("Load player data here...")` ואפשר בעתיד לחבר `LoadData(player)`.
- **יציאה:** ב-`PlayerRemoving` משחררים את הפלטפורמה (מנקים Attribute ו-tables) כדי ששחקן אחר יוכל לתפוס.
- **נתונים:** אין DataStore – רק זיכרון ו-Attribute בזמן ריצה. טעינת שחקן (LoadData) לא קורית בכניסה למשחק; רק אחרי Claim מוצלח קוראים ל-`onPlotClaimed`, ושם תחבר טעינה כשתבנה אותה.

---

## 5. מה לבדוק ב-Play Test

1. **יש תיקייה Plots ובתוכה לפחות Model אחד** שבתוכו **ClaimPart** (Part או ProximityPrompt בשם ClaimPart).
2. **להריץ משחק** – ב-Output אמור להופיע "Server loaded!".
3. **שחקן אחד:** נוגע ב-ClaimPart (או מפעיל ProximityPrompt) – ב-Output אמור להופיע:  
   `[PlotClaim] Load player data here – player: ... plot: ...`
4. **אותו שחקן** מנסה לתפוס שוב (או לתפוס Plot אחר) – לא קורה כלום (כבר יש לו פלטפורמה).
5. **שחקן שני** מנסה לתפוס **אותה** פלטפורמה – לא קורה כלום (תפוסה).
6. **שחקן שני** תופס **פלטפורמה אחרת** – מקבל את ה-print של Load player data.
7. **שחקן יוצא** – הפלטפורמה שלו משתחררת; שחקן אחר יכול לתפוס אותה.

אם משהו מזה לא עובד – לבדוק ש-**Plots** תחת Workspace, ש-**ClaimPart** קיים בתוך כל Plot ושהשם באנגלית ובאותיות כמו שכתוב.
