-- Command Bar: מוגבל ל~2000 תווים להדבקה. כל חלק קצר.
-- סדר: 1 → 2A → 2B1 → 2B2 → 2C → 2D

-- ========== PART 1: BARS (~1.5k) ==========
local sg = game:GetService("StarterGui")
if not sg then print("[StatsHUD] StarterGui not found.") return end
if sg:FindFirstChild("StatsHUD") then sg.StatsHUD:Destroy() end
local g = Instance.new("ScreenGui")
g.Name = "StatsHUD"
g.ResetOnSpawn = false
g.Parent = sg
local m = Instance.new("Frame", g)
m.Name = "MainHud"
m.AnchorPoint = Vector2.new(0.5,0)
m.Position = UDim2.new(0.5,0,0,12)
m.Size = UDim2.new(0,320,0,80)
m.BackgroundTransparency = 1
local h = Instance.new("Frame", m)
h.Name = "HPBarContainer"
h.Size = UDim2.new(1,0,0,22)
h.BackgroundColor3 = Color3.fromRGB(40,40,45)
Instance.new("UICorner", h).CornerRadius = UDim.new(0,6)
local hl = Instance.new("TextLabel", h)
hl.Size = UDim2.new(1,-12,1,0)
hl.Position = UDim2.new(0,6,0,0)
hl.BackgroundTransparency = 1
hl.Text = "100/100"
hl.TextColor3 = Color3.fromRGB(255,255,255)
hl.TextSize = 12
hl.Font = Enum.Font.GothamMedium
hl.TextXAlignment = Enum.TextXAlignment.Center
local e = Instance.new("Frame", m)
e.Name = "EXPBarContainer"
e.Size = UDim2.new(1,0,0,22)
e.Position = UDim2.new(0,0,0,28)
e.BackgroundColor3 = Color3.fromRGB(40,40,45)
Instance.new("UICorner", e).CornerRadius = UDim.new(0,6)
local el = Instance.new("TextLabel", e)
el.Size = UDim2.new(1,-12,1,0)
el.Position = UDim2.new(0,6,0,0)
el.BackgroundTransparency = 1
el.Text = "0/100"
el.TextColor3 = Color3.fromRGB(255,255,255)
el.TextSize = 12
el.Font = Enum.Font.GothamMedium
el.TextXAlignment = Enum.TextXAlignment.Center
local b = Instance.new("TextButton", m)
b.Name = "StatsButton"
b.Size = UDim2.new(0,100,0,28)
b.Position = UDim2.new(0,0,0,56)
b.BackgroundColor3 = Color3.fromRGB(55,55,62)
b.Text = "Stats"
b.TextColor3 = Color3.fromRGB(255,255,255)
b.TextSize = 14
b.Font = Enum.Font.GothamMedium
Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)

local ib = Instance.new("TextButton", m)
ib.Name = "InventoryButton"
ib.Size = UDim2.new(0,120,0,28)
ib.Position = UDim2.new(0,110,0,56)
ib.BackgroundColor3 = Color3.fromRGB(55,55,62)
ib.Text = "Inventory"
ib.TextColor3 = Color3.fromRGB(255,255,255)
ib.TextSize = 14
ib.Font = Enum.Font.GothamMedium
Instance.new("UICorner", ib).CornerRadius = UDim.new(0,6)
print("[StatsHUD] 1 done. Run 2A.")


-- ========== PART 2A: PANEL + TITLE + CLOSE (~0.9k) ==========
local sg = game:GetService("StarterGui")
local g = sg:FindFirstChild("StatsHUD")
if not g then print("[StatsHUD] Run Part 1 first.") return end
local p = Instance.new("Frame", g)
p.Name = "StatsPanel"
p.AnchorPoint = Vector2.new(0.5,0.5)
p.Position = UDim2.new(0.5,0,0.5,0)
p.Size = UDim2.new(0,280,0,400)
p.BackgroundColor3 = Color3.fromRGB(28,28,32)
p.BackgroundTransparency = 0
p.Visible = false
Instance.new("UICorner", p).CornerRadius = UDim.new(0,10)
Instance.new("UIStroke", p).Color = Color3.fromRGB(60,60,68)
local pad = Instance.new("UIPadding", p)
pad.PaddingTop = UDim.new(0,12)
pad.PaddingBottom = UDim.new(0,12)
pad.PaddingLeft = UDim.new(0,16)
pad.PaddingRight = UDim.new(0,16)
local ll = Instance.new("UIListLayout", p)
ll.Padding = UDim.new(0,8)
ll.SortOrder = Enum.SortOrder.LayoutOrder
local t = Instance.new("TextLabel", p)
t.Name = "Title"
t.LayoutOrder = 0
t.Size = UDim2.new(1,-44,0,24)
t.BackgroundTransparency = 1
t.Text = "Stats"
t.TextColor3 = Color3.fromRGB(255,255,255)
t.TextSize = 18
t.Font = Enum.Font.GothamBold
t.TextXAlignment = Enum.TextXAlignment.Left
local x = Instance.new("TextButton", p)
x.Name = "CloseButton"
x.LayoutOrder = 1
x.Size = UDim2.new(0,28,0,28)
x.BackgroundColor3 = Color3.fromRGB(60,60,68)
x.Text = "X"
x.TextColor3 = Color3.fromRGB(255,255,255)
x.TextSize = 14
x.Font = Enum.Font.GothamBold
Instance.new("UICorner", x).CornerRadius = UDim.new(0,6)
print("[StatsHUD] 2A done. Run 2B.")


-- ========== PART 2B1: Level row only (~0.8k) ==========
local sg = game:GetService("StarterGui")
local g = sg:FindFirstChild("StatsHUD")
local p = g and g:FindFirstChild("StatsPanel")
if not p then print("[StatsHUD] Run 1 and 2A first.") return end
local function ir(nm,txt,val,ord)
	local r = Instance.new("Frame", p)
	r.Name = nm
	r.LayoutOrder = ord
	r.Size = UDim2.new(1,0,0,24)
	r.BackgroundTransparency = 1
	local rl = Instance.new("UIListLayout", r)
	rl.FillDirection = Enum.FillDirection.Horizontal
	rl.HorizontalAlignment = Enum.HorizontalAlignment.Left
	rl.VerticalAlignment = Enum.VerticalAlignment.Center
	local a = Instance.new("TextLabel", r)
	a.Size = UDim2.new(1,-80,1,0)
	a.BackgroundTransparency = 1
	a.Text = txt
	a.TextColor3 = Color3.fromRGB(200,200,205)
	a.TextSize = 14
	a.Font = Enum.Font.Gotham
	a.TextXAlignment = Enum.TextXAlignment.Left
	local v = Instance.new("TextLabel", r)
	v.Name = "ValueLabel"
	v.Size = UDim2.new(0,80,1,0)
	v.BackgroundTransparency = 1
	v.Text = val
	v.TextColor3 = Color3.fromRGB(255,255,255)
	v.TextSize = 14
	v.Font = Enum.Font.GothamMedium
	v.TextXAlignment = Enum.TextXAlignment.Right
end
ir("LevelLabel","Level","1",2)
print("[StatsHUD] 2B1 done. Run 2B2.")

-- ========== PART 2B2: XP + Stat Points rows (~0.5k) ==========
local sg = game:GetService("StarterGui")
local g = sg:FindFirstChild("StatsHUD")
local p = g and g:FindFirstChild("StatsPanel")
if not p then print("[StatsHUD] Run 1, 2A, 2B1 first.") return end
local function ir(nm,txt,val,ord)
	local r = Instance.new("Frame", p)
	r.Name = nm
	r.LayoutOrder = ord
	r.Size = UDim2.new(1,0,0,24)
	r.BackgroundTransparency = 1
	local rl = Instance.new("UIListLayout", r)
	rl.FillDirection = Enum.FillDirection.Horizontal
	rl.HorizontalAlignment = Enum.HorizontalAlignment.Left
	rl.VerticalAlignment = Enum.VerticalAlignment.Center
	local a = Instance.new("TextLabel", r)
	a.Size = UDim2.new(1,-80,1,0)
	a.BackgroundTransparency = 1
	a.Text = txt
	a.TextColor3 = Color3.fromRGB(200,200,205)
	a.TextSize = 14
	a.Font = Enum.Font.Gotham
	a.TextXAlignment = Enum.TextXAlignment.Left
	local v = Instance.new("TextLabel", r)
	v.Name = "ValueLabel"
	v.Size = UDim2.new(0,80,1,0)
	v.BackgroundTransparency = 1
	v.Text = val
	v.TextColor3 = Color3.fromRGB(255,255,255)
	v.TextSize = 14
	v.Font = Enum.Font.GothamMedium
	v.TextXAlignment = Enum.TextXAlignment.Right
end
ir("XPLabel","XP","0 / 100",3)
ir("StatPointsLabel","Stat Points","0",4)
print("[StatsHUD] 2B2 done. Run 2C.")


-- ========== PART 2C: STRENGTH + HEALTH ROWS (~1.2k) ==========
local sg = game:GetService("StarterGui")
local g = sg:FindFirstChild("StatsHUD")
local p = g and g:FindFirstChild("StatsPanel")
if not p then print("[StatsHUD] Run 1, 2A, 2B1, 2B2 first.") return end
local function sr(nm,txt,ord)
	local r = Instance.new("Frame", p)
	r.Name = nm
	r.LayoutOrder = ord
	r.Size = UDim2.new(1,0,0,28)
	r.BackgroundTransparency = 1
	local rl = Instance.new("UIListLayout", r)
	rl.FillDirection = Enum.FillDirection.Horizontal
	rl.HorizontalAlignment = Enum.HorizontalAlignment.Left
	rl.VerticalAlignment = Enum.VerticalAlignment.Center
	rl.Padding = UDim.new(0,8)
	local a = Instance.new("TextLabel", r)
	a.Name = "NameLabel"
	a.Size = UDim2.new(1,-70,1,0)
	a.BackgroundTransparency = 1
	a.Text = txt
	a.TextColor3 = Color3.fromRGB(220,220,225)
	a.TextSize = 14
	a.Font = Enum.Font.GothamMedium
	a.TextXAlignment = Enum.TextXAlignment.Left
	local v = Instance.new("TextLabel", r)
	v.Name = "ValueLabel"
	v.Size = UDim2.new(0,40,1,0)
	v.BackgroundTransparency = 1
	v.Text = "0"
	v.TextColor3 = Color3.fromRGB(255,255,255)
	v.TextSize = 14
	v.Font = Enum.Font.GothamMedium
	v.TextXAlignment = Enum.TextXAlignment.Right
	local pb = Instance.new("TextButton", r)
	pb.Name = "PlusButton"
	pb.Size = UDim2.new(0,24,0,24)
	pb.BackgroundColor3 = Color3.fromRGB(70,130,80)
	pb.Text = "+"
	pb.TextColor3 = Color3.fromRGB(255,255,255)
	pb.TextSize = 14
	pb.Font = Enum.Font.GothamBold
	Instance.new("UICorner", pb).CornerRadius = UDim.new(0,4)
end
sr("StrengthRow","Strength",5)
sr("HealthRow","Health",6)
print("[StatsHUD] 2C done. Run 2D.")


-- ========== PART 2D: SPEED + LOCALSCRIPT (~0.7k) ==========
local sg = game:GetService("StarterGui")
local g = sg:FindFirstChild("StatsHUD")
local p = g and g:FindFirstChild("StatsPanel")
if not p then print("[StatsHUD] Run 1, 2A, 2B1, 2B2, 2C first.") return end
local function sr(nm,txt,ord)
	local r = Instance.new("Frame", p)
	r.Name = nm
	r.LayoutOrder = ord
	r.Size = UDim2.new(1,0,0,28)
	r.BackgroundTransparency = 1
	local rl = Instance.new("UIListLayout", r)
	rl.FillDirection = Enum.FillDirection.Horizontal
	rl.HorizontalAlignment = Enum.HorizontalAlignment.Left
	rl.VerticalAlignment = Enum.VerticalAlignment.Center
	rl.Padding = UDim.new(0,8)
	local a = Instance.new("TextLabel", r)
	a.Name = "NameLabel"
	a.Size = UDim2.new(1,-70,1,0)
	a.BackgroundTransparency = 1
	a.Text = txt
	a.TextColor3 = Color3.fromRGB(220,220,225)
	a.TextSize = 14
	a.Font = Enum.Font.GothamMedium
	a.TextXAlignment = Enum.TextXAlignment.Left
	local v = Instance.new("TextLabel", r)
	v.Name = "ValueLabel"
	v.Size = UDim2.new(0,40,1,0)
	v.BackgroundTransparency = 1
	v.Text = "0"
	v.TextColor3 = Color3.fromRGB(255,255,255)
	v.TextSize = 14
	v.Font = Enum.Font.GothamMedium
	v.TextXAlignment = Enum.TextXAlignment.Right
	local pb = Instance.new("TextButton", r)
	pb.Name = "PlusButton"
	pb.Size = UDim2.new(0,24,0,24)
	pb.BackgroundColor3 = Color3.fromRGB(70,130,80)
	pb.Text = "+"
	pb.TextColor3 = Color3.fromRGB(255,255,255)
	pb.TextSize = 14
	pb.Font = Enum.Font.GothamBold
	Instance.new("UICorner", pb).CornerRadius = UDim.new(0,4)
end
sr("SpeedRow","Speed",7)
local ls = Instance.new("LocalScript", g)
ls.Name = "StatsHUDClient"
ls.Source = "local Players=game:GetService('Players') local player=Players.LocalPlayer local playerGui=player:WaitForChild('PlayerGui') local g=script.Parent local m=g:WaitForChild('MainHud') local p=g:WaitForChild('StatsPanel') local sb=m:WaitForChild('StatsButton') local ib=m:WaitForChild('InventoryButton') local cb=p:WaitForChild('CloseButton') sb.MouseButton1Click:Connect(function() p.Visible=not p.Visible end) cb.MouseButton1Click:Connect(function() p.Visible=false end) ib.MouseButton1Click:Connect(function() local inv=playerGui:FindFirstChild('InventoryGui') if not inv then local ok,res=pcall(function() return playerGui:WaitForChild('InventoryGui',5) end) inv=(ok and res) or nil end if inv then inv.Enabled=not inv.Enabled end end) for _,n in pairs({'StrengthRow','HealthRow','SpeedRow'}) do local r=p:FindFirstChild(n) if r then local pb=r:FindFirstChild('PlusButton') if pb then pb.MouseButton1Click:Connect(function() print('[StatsUI] '..n:gsub('Row','')..' plus clicked') end) end end end"
print("[StatsHUD] 2D done. All set.")
