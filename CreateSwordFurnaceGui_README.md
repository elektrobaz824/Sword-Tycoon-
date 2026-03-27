# יצירת Sword Furnace UI ב-StarterGui (פעם אחת ב-Studio)

## למה לא רואים כלום

- **אם הרצת את הסקריפט ב-Play (F5):** כש-Studio עוצר את המשחק, ה-place חוזר למצב שלפני ה-Play. כל מה שהסקריפט יצר (כולל ה-GUI) **לא נשמר**. לכן חייבים להריץ את הסקריפט **במצב עריכה (Edit mode)**, לא ב-Play.
- **אם ה-GUI כבר קיים ב-Explorer אבל לא על המסך:** ב-ScreenGui מוגדר `Enabled = false`, אז הוא לא מוצג. כדי לראות אותו במשחק הפעל `Enabled = true` ב-Explorer או מקוד.

---

## איך להשתמש (חשוב: במצב עריכה)

### אפשרות א' – Command Bar (בלי Play)

1. **אל תלחץ Play.** הישאר במצב עריכה.
2. פתח **Command Bar**: תפריט **View** → **Command Bar** (או Alt+C).
3. פתח את הקובץ `CreateSwordFurnaceGui_StudioOnce.lua` והעתק את **כל** התוכן (מהשורה הראשונה עד האחרונה).
4. הדבק ב-Command Bar והקש **Enter**.
5. אם הופיעה הודעה ב-Output על יצירת SwordFurnaceGui – **שמור את ה-place** (Ctrl+S).
6. ב-**Explorer** פתח **StarterGui** – אמור להופיע **SwordFurnaceGui** עם כל ה-Frames וה-Buttons.

אם ההדבקה ב-Command Bar לא עובדת (קוד ארוך מדי), השתמש באפשרות ב'.

### אפשרות ב' – Script שמריץ רק במצב עריכה (Plugin / Run פעם אחת)

1. הורד/התקן פלאגין שמריץ סקריפט **במצב עריכה** (למשל "Run Script", "Script Runner", או דומה).
2. במצב עריכה הרץ דרכו את הקובץ `CreateSwordFurnaceGui_StudioOnce.lua`.
3. שמור את ה-place (Ctrl+S).
4. מחק את הסקריפט אם הוספת אותו לפרויקט – ה-GUI כבר שמור ב-StarterGui.

### אפשרות ג' – הרצה ב-Play + שמירה לפני Stop

1. שים את הסקריפט תחת **ServerScriptService**.
2. לחץ **Play**.
3. **מיד** אחרי שה-GUI נוצר (תראה הודעה ב-Output): בתפריט **File** → **Save to Roblox** (או **Save** אם אתה עובד על קובץ מקומי) – **לפני** שאתה לוחץ Stop.
4. בחלק מהגרסאות של Studio שמירה בזמן Play שומרת את המצב הנוכחי; אם אחרי Stop ה-GUI נעלם, השתמש באפשרות א' או ב'.

---

## איפה לראות את ה-GUI

- **במצב עריכה:** ב-**Explorer** → **StarterGui** → **SwordFurnaceGui**. אם אתה רוצה לראות אותו גם על המסך בעריכה, בחר את ה-ScreenGui והפעל **Enabled** ב-Properties.
- **במשחק (Play):** ה-GUI מועתק ל-**PlayerGui**. כרגע הוא עם **Enabled = false** אז לא יוצג. כדי לראות אותו במשחק הפעל `Enabled = true` על SwordFurnaceGui ב-StarterGui (או הפעל אותו מקוד כשאתה רוצה להציג את המסך).

---

## מה נוצר

- **SwordFurnaceGui** (ScreenGui, Enabled = false)
  - **MainFrame** – UICorner, UIStroke, UIPadding
  - **TitleLabel** – "Sword Furnace"
  - **MaterialsFrame** – MaterialsTitle, CopperRow, IronRow, GoldRow (בכל שורה: NameLabel, MinusButton, AmountLabel, PlusButton)
  - **ChancesFrame** – ChancesTitle, CopperChanceLabel, IronChanceLabel, GoldChanceLabel, DiamondChanceLabel
  - **ButtonsFrame** – ForgeButton, CloseButton

הסקריפט בודק אם SwordFurnaceGui כבר קיים; אם כן, הוא לא יוצר כפילות.
