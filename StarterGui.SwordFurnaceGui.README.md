# Sword Furnace UI – בסיס ב-StarterGui

## איך נבנה ה-UI

ה-UI נבנה כ-**Instance Descriptions** בתוך קובץ הפרויקט של Rojo (`default.project.json`).  
Rojo יוצר מזה אובייקטים אמיתיים ב-place כש־**Build** או **Live Sync** רצים – אין שום קוד שרץ במשחק ויוצר את ה-GUI.

- **מיקום:** עץ `StarterGui` → `SwordFurnaceGui` (ScreenGui) → `MainFrame` וכל הילדים.
- **מבנה:** Frame ראשי במרכז, MaterialsFrame משמאל, ChancesFrame מימין, ButtonsFrame למטה; בכל Row יש NameLabel, MinusButton, AmountLabel, PlusButton.
- **עיצוב:** רקע כהה, UICorner, UIStroke, UIPadding, UIListLayout; טקסטים וכפתורים עם צבעים וריווח ברורים.

## רשימת האובייקטים שנוצרו

| נתיב ב-Explorer | ClassName | תיאור |
|-----------------|-----------|--------|
| **StarterGui** | StarterGui | שירות (כבר קיים; נוסף אליו תוכן) |
| **StarterGui.SwordFurnaceGui** | ScreenGui | GUI ראשי, Enabled = false |
| **SwordFurnaceGui.MainFrame** | Frame | חלון ראשי במרכז |
| MainFrame.UICorner | UICorner | פינות מעוגלות |
| MainFrame.UIStroke | UIStroke | מסגרת |
| MainFrame.UIPadding | UIPadding | רווח פנימי |
| MainFrame.TitleLabel | TextLabel | "Sword Furnace" |
| MainFrame.MaterialsFrame | Frame | אזור חומרים (שמאל) |
| MaterialsFrame.MaterialsTitle | TextLabel | "Materials" |
| MaterialsFrame.CopperRow | Frame | שורת Copper Ore |
| MaterialsFrame.IronRow | Frame | שורת Iron Ore |
| MaterialsFrame.GoldRow | Frame | שורת Gold Ore |
| בכל Row: NameLabel, MinusButton, AmountLabel, PlusButton | TextLabel / TextButton | טקסט ו־+/- |
| MainFrame.ChancesFrame | Frame | אזור סיכויים (ימין) |
| ChancesFrame.ChancesTitle | TextLabel | "Sword Chances" |
| ChancesFrame.CopperChanceLabel | TextLabel | "Copper Sword - 0%" |
| ChancesFrame.IronChanceLabel | TextLabel | "Iron Sword - 0%" |
| ChancesFrame.GoldChanceLabel | TextLabel | "Gold Sword - 0%" |
| ChancesFrame.DiamondChanceLabel | TextLabel | "Diamond Sword - 0%" |
| MainFrame.ButtonsFrame | Frame | אזור כפתורים (למטה) |
| ButtonsFrame.ForgeButton | TextButton | "Forge" |
| ButtonsFrame.CloseButton | TextButton | "Close" |

## איפה זה יושב ב-Explorer

```
StarterGui
└── SwordFurnaceGui (ScreenGui, Enabled = false)
    └── MainFrame (Frame)
        ├── UICorner
        ├── UIStroke
        ├── UIPadding
        ├── TitleLabel
        ├── MaterialsFrame
        │   ├── UICorner, UIPadding, UIListLayout
        │   ├── MaterialsTitle
        │   ├── CopperRow (NameLabel, MinusButton, AmountLabel, PlusButton + UICorner בכל כפתור)
        │   ├── IronRow (אותו מבנה)
        │   └── GoldRow (אותו מבנה)
        ├── ChancesFrame
        │   ├── UICorner, UIPadding, UIListLayout
        │   ├── ChancesTitle
        │   ├── CopperChanceLabel, IronChanceLabel, GoldChanceLabel, DiamondChanceLabel
        ├── ButtonsFrame
        │   ├── ForgeButton + UICorner
        │   └── CloseButton + UICorner
```

## איפה מוגדר ה-UI בפרויקט (Rojo)

- **קובץ:** `default.project.json` (בשורש הפרויקט).
- **עץ:** תחת `tree` → `StarterGui` → `SwordFurnaceGui` → `MainFrame` וכל הילדים.
- **קובץ עזר (לעיון בלבד):** `StarterGui.SwordFurnaceGui.json` – גרסה מפורשת של אותו עץ; Rojo **לא** קורא אותו אוטומטית, ההגדרה האמיתית נמצאת רק ב-`default.project.json`.

## איך לראות ולערוך ב-Studio

1. להריץ **Rojo build** או **Rojo serve** ולחבר את Studio (Live Sync) או לבנות place file.
2. לפתוח את ה-place ב-Roblox Studio.
3. ב-**Explorer** לפתוח **StarterGui** – יופיע **SwordFurnaceGui** עם כל ה-Frames, Labels וה-Buttons.
4. לערוך ידנית: להזיז, לצבוע, למחוק, להוסיף עיצוב, לשנות טקסטים וגדלים – כמו כל GUI שנוצר ישירות ב-Studio.  
   ה-UI **לא** נוצר מ-Script בזמן ריצה; אחרי ש-Rojo מיישם את הפרויקט, האובייקטים נשמרים ב-place וניתנים לעריכה מלאה.

## הערה על Font

ב-JSON הוסר המאפיין `Font` מטקסטים (כי ב-Roblox החדש משתמשים ב-FontFace). אם תרצה פונט ספציפי, אפשר להגדיר FontFace או את ה-Font הישן ידנית ב-Studio על ה-TextLabel/TextButton הרלוונטיים.
