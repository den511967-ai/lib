--[[
	Neverlose-style Menu (LocalScript) — based on LumenMenu, all feature callbacks are empty
	Put into: StarterPlayer > StarterPlayerScripts > LocalScript
	Open / close: Delete (changeable in the profile popup, "Menu Bind")

	API:
	  menu:AddCategory(name)
	  menu:AddTab(name, icon, { Options = true })   -- Options: show the "Global" selector in the toolbar on this tab
	  tab:AddSubTab(name, icon)                     -- add sub-tabs right after their tab
	  tab:AddSection(name, "Left" | "Right")
	  tab:AddPreview(opts)                          -- character preview in the right column (see AddPreview)

	  Rows (text may be "Name" or { "Name", "icon" }):
	  sec:AddToggle(text, default, callback)        -> t:AddSettings(width, title) -> popup section
	                                                   t:AddColor(color, callback, alpha)
	  sec:AddSlider(text, min, max, default, callback, suffix, { Decimals = 1, Format = function(v) return "Auto" end })
	  sec:AddDropdown(text, options, default, callback)   -> d:AddColor(color, callback, alpha)
	  sec:AddMultiDropdown(text, options, defaults, callback)
	  sec:AddColorPicker(text, color, callback, alpha)
	  sec:AddKeybind(text, defaultKeyCode, callback)       -- plain key row (the menu itself no longer uses it)
	  Right-click a toggle / slider / dropdown row: All Hotkeys, New Hotkey, Reset.
	  A hotkey has Key, Mode (Toggle | Hold), the value it applies while active, Visible (Hotkeys window).
	  Hotkeys are saved in presets.
	  sec:AddNav(text, width)                       -> popup section (row with ">")
	  sec:AddButton(text, callback)
	  sec:AddLabel(text)
	  popupSection:AddGroup()                       -> next card inside the same popup
	  every row api:SetDisabled(bool)

	  menu:SetWindow("Watermark" | "Hotkeys" | "Spectators" | "Event Logs", visible)
	  menu:Log(text)                                -- line in the Event Logs window
	  menu:SetScale(number)                         -- menu + popups
	  menu:SetHudScale(number)                      -- watermark / hotkeys / spectators / logs
	  menu.FooterMenu                               -> section in the popup of the profile block
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")

local player = Players.LocalPlayer

------------------------------------------------------------------
-- Theme (sampled from the BloxStrike video frames)
------------------------------------------------------------------
local function makeFont(weight)
	return Font.new("rbxasset://fonts/families/BuilderSans.json", weight)
end

local Theme = {
	Window     = Color3.fromRGB(10, 11, 16),
	WindowTransparency = 0.06,
	Content    = Color3.fromRGB(13, 13, 19),
	ContentStroke = Color3.fromRGB(26, 26, 36),
	Section    = Color3.fromRGB(22, 22, 28),
	SectionStroke = Color3.fromRGB(32, 32, 40),
	Element    = Color3.fromRGB(26, 25, 34),
	ElementStroke = Color3.fromRGB(38, 36, 47),
	Hover      = Color3.fromRGB(36, 34, 46),
	Active     = Color3.fromRGB(33, 36, 46),
	Stroke     = Color3.fromRGB(32, 32, 40),
	Divider    = Color3.fromRGB(28, 27, 35),
	Pill       = Color3.fromRGB(13, 13, 20),
	ValueBox   = Color3.fromRGB(24, 22, 32),
	PopupBg    = Color3.fromRGB(17, 17, 24),
	PopupCard  = Color3.fromRGB(22, 22, 30),
	PopupCardStroke = Color3.fromRGB(34, 34, 44),
	Logo       = Color3.fromRGB(8, 8, 12),
	Accent     = Color3.fromRGB(88, 136, 244),
	Text       = Color3.fromRGB(240, 240, 245),
	TextDim    = Color3.fromRGB(215, 213, 221),
	TabText    = Color3.fromRGB(160, 162, 176),
	SubText    = Color3.fromRGB(84, 84, 96),
	IconDim    = Color3.fromRGB(120, 124, 140),
	SwitchOff  = Color3.fromRGB(9, 10, 15),
	KnobOff    = Color3.fromRGB(140, 144, 158),
	SliderTrack = Color3.fromRGB(44, 46, 60),
	-- border gradients and small surfaces
	LitTop     = Color3.fromRGB(52, 52, 66),
	LitBottom  = Color3.fromRGB(24, 24, 32),
	SelectLitTop = Color3.fromRGB(70, 73, 86),
	SelectLitBottom = Color3.fromRGB(42, 44, 54),
	PopupLitTop = Color3.fromRGB(58, 58, 72),
	PopupLitBottom = Color3.fromRGB(32, 32, 42),
	WindowLitTop = Color3.fromRGB(44, 44, 56),
	ContentLitTop = Color3.fromRGB(38, 38, 50),
	SectionLitTop = Color3.fromRGB(40, 40, 50),
	Deep       = Color3.fromRGB(20, 20, 28),
	SearchBg   = Color3.fromRGB(26, 26, 38),
	Scrollbar  = Color3.fromRGB(60, 60, 70),
	HeaderDivider = Color3.fromRGB(56, 56, 68),
	AccentSoft = Color3.fromRGB(22, 28, 58),
	Font       = makeFont(Enum.FontWeight.Medium),
	FontBold   = makeFont(Enum.FontWeight.Bold),
	FontHeavy  = makeFont(Enum.FontWeight.Heavy),
	FontLight  = makeFont(Enum.FontWeight.Regular),
}

-- Palettes for menu:SetThemeMode. Recolouring maps every old colour to the new one by value, so inside a
-- palette two keys may share a colour only if they share it in every palette (Stroke = SectionStroke),
-- and no palette colour may equal white, black, the accent or the fixed red/orange.
local rgb = Color3.fromRGB
local PALETTES = {
	Dark = {},
	Light = {
		Window = rgb(234, 235, 240), Content = rgb(244, 245, 248), ContentStroke = rgb(218, 220, 227),
		Section = rgb(252, 252, 254), SectionStroke = rgb(224, 226, 232), Stroke = rgb(224, 226, 232),
		Element = rgb(240, 241, 245), ElementStroke = rgb(212, 214, 222), Hover = rgb(230, 232, 238),
		Active = rgb(226, 229, 238), Divider = rgb(236, 237, 242), Pill = rgb(246, 247, 250),
		ValueBox = rgb(238, 239, 243), PopupBg = rgb(247, 247, 250), PopupCard = rgb(251, 251, 253),
		PopupCardStroke = rgb(222, 224, 230), Logo = rgb(229, 230, 235),
		Text = rgb(22, 23, 30), TextDim = rgb(50, 52, 62), TabText = rgb(98, 101, 114), SubText = rgb(142, 145, 157),
		IconDim = rgb(128, 132, 146), SwitchOff = rgb(208, 211, 220), KnobOff = rgb(249, 249, 251),
		SliderTrack = rgb(214, 217, 226),
		LitTop = rgb(232, 233, 238), LitBottom = rgb(210, 212, 220), SelectLitTop = rgb(226, 228, 234),
		SelectLitBottom = rgb(206, 208, 216), PopupLitTop = rgb(228, 230, 236), PopupLitBottom = rgb(208, 210, 218),
		WindowLitTop = rgb(225, 227, 233), ContentLitTop = rgb(227, 229, 235), SectionLitTop = rgb(229, 231, 237),
		Deep = rgb(204, 206, 214), SearchBg = rgb(235, 237, 242), Scrollbar = rgb(190, 192, 200),
		HeaderDivider = rgb(200, 202, 210),
	},
}
-- the dark palette is the Theme as written above
for key in pairs(PALETTES.Light) do
	PALETTES.Dark[key] = Theme[key]
end

-- the halo around the window: dark shadow in dark mode, white glow in light mode
local SHADOW_COLORS = { Dark = Color3.new(0, 0, 0), Light = Color3.new(1, 1, 1) }

------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------
local function create(className, props, children)
	local inst = Instance.new(className)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(r)
	return create("UICorner", { CornerRadius = UDim.new(0, r) })
end

local function stroke(color, thickness)
	return create("UIStroke", {
		Color = color or Theme.Stroke,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function litStroke(top, bottom)
	local s = stroke(Color3.new(1, 1, 1))
	create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(top or Theme.LitTop, bottom or Theme.LitBottom),
		Parent = s,
	})
	return s
end

local function padding(t, r, b, l)
	return create("UIPadding", {
		PaddingTop = UDim.new(0, t),
		PaddingRight = UDim.new(0, r),
		PaddingBottom = UDim.new(0, b),
		PaddingLeft = UDim.new(0, l),
	})
end

local function list(pad, horizontal)
	return create("UIListLayout", {
		Padding = UDim.new(0, pad or 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		VerticalAlignment = if horizontal then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top,
	})
end

local function tween(obj, props, time)
	TweenService:Create(
		obj,
		TweenInfo.new(time or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props
	):Play()
end

local function textLabel(props, children)
	local base = {
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		TextColor3 = Theme.TextDim,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for k, v in pairs(props) do
		base[k] = v
	end
	return create("TextLabel", base, children)
end

local function isClick(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch
end

-- Pointer position in the space of AbsolutePosition.
-- GetMouseLocation() is measured from the top of the screen; whether this gui's AbsolutePosition is
-- measured from there or from below the top bar differs between clients (a screen recording showed the
-- colour picker knob one top-bar height below the cursor either way). So the shift is measured at runtime:
-- when the mouse enters a small element, only one of "no shift" / "top-bar inset" puts the pointer inside it.
local GuiService = game:GetService("GuiService")
local pointerShift = nil -- Vector2 once measured

local function topInset()
	local ok, inset = pcall(function()
		return GuiService:GetGuiInset()
	end)
	return if ok and inset then inset else Vector2.zero
end

local function isInside(gui, p)
	local a, s = gui.AbsolutePosition, gui.AbsoluteSize
	return p.X >= a.X and p.Y >= a.Y and p.X <= a.X + s.X and p.Y <= a.Y + s.Y
end

-- call while the real pointer is over gui (MouseEnter, click); keeps the last unambiguous answer
local function calibratePointer(gui)
	local mouse = UserInputService:GetMouseLocation()
	local inset = topInset()
	if inset.Magnitude < 1 then
		pointerShift = Vector2.zero
		return
	end
	local plain, shifted = isInside(gui, mouse), isInside(gui, mouse - inset)
	if plain ~= shifted then
		pointerShift = if plain then Vector2.zero else inset
	end
end

local function pointerPosition(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		return Vector2.new(input.Position.X, input.Position.Y)
	end
	-- before the first measurement assume what the recording showed: AbsolutePosition starts under the top bar
	return UserInputService:GetMouseLocation() - (pointerShift or topInset())
end

-- elements that measure the shift while hovered / clicked
local function trackPointer(gui)
	gui.MouseEnter:Connect(function()
		calibratePointer(gui)
	end)
	if gui:IsA("GuiButton") then
		gui.MouseButton1Down:Connect(function()
			calibratePointer(gui)
		end)
	end
end

local function lower(s)
	local ok, result = pcall(function()
		local out = {}
		for _, c in utf8.codes(s) do
			if c >= 0x410 and c <= 0x42F then
				c += 0x20
			elseif c == 0x401 then
				c = 0x451
			elseif c >= 65 and c <= 90 then
				c += 32
			end
			table.insert(out, utf8.char(c))
		end
		return table.concat(out)
	end)
	return if ok then result else string.lower(s)
end

local function toHex(c, a)
	return string.format(
		"#%02X%02X%02X%02X",
		math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255), math.round((a or 1) * 255)
	)
end

-- "#RRGGBB" or "#RRGGBBAA" -> color, alpha (alpha nil when not given)
local function fromHex(s)
	local hex = (string.gsub(s, "[#%s]", ""))
	if (#hex ~= 6 and #hex ~= 8) or not string.match(hex, "^%x+$") then
		return nil
	end
	local color = Color3.fromRGB(
		tonumber(string.sub(hex, 1, 2), 16),
		tonumber(string.sub(hex, 3, 4), 16),
		tonumber(string.sub(hex, 5, 6), 16)
	)
	local alpha = if #hex == 8 then tonumber(string.sub(hex, 7, 8), 16) / 255 else nil
	return color, alpha
end

------------------------------------------------------------------
-- Icons (drawn from frames, no image loading)
------------------------------------------------------------------
local function iconBase(parent, props)
	local base = { Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1 }
	for k, v in pairs(props or {}) do
		base[k] = v
	end
	base.Parent = parent
	return create("Frame", base)
end

local function fill(parent, x, y, w, h, r, color, rotation)
	return create("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		Rotation = rotation or 0,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = parent,
	}, if r and r > 0 then { corner(r) } else nil)
end

local function outline(parent, x, y, w, h, r, color)
	return create("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		Parent = parent,
	}, { corner(r), stroke(color, 1.5) })
end

local Icons = {}

function Icons.crosshair(p, c, props)
	local i = iconBase(p, props)
	outline(i, 2, 2, 12, 12, 6, c)
	fill(i, 7, 7, 2, 2, 1, c)
	fill(i, 7, 0, 2, 4, 1, c); fill(i, 7, 12, 2, 4, 1, c)
	fill(i, 0, 7, 4, 2, 1, c); fill(i, 12, 7, 4, 2, 1, c)
	return i
end

function Icons.mouse(p, c, props)
	local i = iconBase(p, props)
	outline(i, 3, 1, 10, 14, 5, c)
	fill(i, 7, 3, 2, 4, 1, c)
	return i
end

function Icons.image(p, c, props)
	local i = iconBase(p, props)
	outline(i, 1, 2, 14, 12, 3, c)
	fill(i, 4, 5, 3, 3, 2, c)
	fill(i, 6, 9, 7, 2, 1, c, -30)
	return i
end

function Icons.layers(p, c, props)
	local i = iconBase(p, props)
	fill(i, 4, 1, 8, 8, 2, c, 45)
	fill(i, 1, 11, 8, 2, 1, c, 30)
	fill(i, 7, 11, 8, 2, 1, c, -30)
	return i
end

function Icons.panel(p, c, props)
	local i = iconBase(p, props)
	outline(i, 1, 1, 14, 14, 3, c)
	fill(i, 4, 5, 8, 2, 1, c)
	fill(i, 4, 9, 5, 2, 1, c)
	return i
end

function Icons.grid(p, c, props)
	local i = iconBase(p, props)
	fill(i, 1, 1, 6, 6, 2, c); fill(i, 9, 1, 6, 6, 2, c)
	fill(i, 1, 9, 6, 6, 2, c); fill(i, 9, 9, 6, 6, 2, c)
	return i
end

function Icons.ring(p, c, props)
	local i = iconBase(p, props)
	outline(i, 1, 1, 14, 14, 7, c)
	fill(i, 6, 6, 4, 4, 2, c)
	return i
end

function Icons.box(p, c, props)
	local i = iconBase(p, props)
	fill(i, 1, 2, 14, 4, 1, c)
	outline(i, 2, 7, 12, 8, 2, c)
	fill(i, 6, 9, 4, 2, 1, c)
	return i
end

function Icons.sliders(p, c, props)
	local i = iconBase(p, props)
	fill(i, 1, 4, 14, 2, 1, c); fill(i, 9, 2, 6, 6, 3, c)
	fill(i, 1, 11, 14, 2, 1, c); fill(i, 1, 9, 6, 6, 3, c)
	return i
end

function Icons.list(p, c, props)
	local i = iconBase(p, props)
	for _, y in ipairs({ 3, 7, 11 }) do
		fill(i, 1, y, 2, 2, 1, c)
		fill(i, 5, y, 10, 2, 1, c)
	end
	return i
end

function Icons.clock(p, c, props)
	local i = iconBase(p, props)
	outline(i, 1, 1, 14, 14, 7, c)
	fill(i, 7, 4, 2, 5, 1, c)
	fill(i, 7, 7, 4, 2, 1, c)
	return i
end

function Icons.user(p, c, props)
	local i = iconBase(p, props)
	fill(i, 5, 1, 6, 6, 3, c)
	fill(i, 2, 9, 12, 6, 3, c)
	return i
end

function Icons.globe(p, c, props)
	local i = iconBase(p, props)
	outline(i, 1, 1, 14, 14, 7, c)
	outline(i, 5, 1, 6, 14, 3, c)
	fill(i, 1, 7, 14, 2, 1, c)
	return i
end

function Icons.text(p, c, props)
	local i = iconBase(p, props)
	fill(i, 1, 2, 9, 2, 1, c); fill(i, 4, 2, 2, 12, 1, c)
	fill(i, 9, 8, 6, 2, 1, c); fill(i, 11, 8, 2, 6, 1, c)
	return i
end

function Icons.window(p, c, props)
	local i = iconBase(p, props)
	outline(i, 4, 1, 11, 9, 2, c)
	fill(i, 1, 6, 10, 9, 2, c)
	return i
end

function Icons.folder(p, c, props)
	local i = iconBase(p, props)
	fill(i, 1, 2, 6, 3, 1, c)
	outline(i, 1, 4, 14, 10, 2, c)
	return i
end

function Icons.eye(p, c, props)
	local i = iconBase(p, props)
	outline(i, 1, 4, 14, 8, 4, c)
	fill(i, 6, 6, 4, 4, 2, c)
	return i
end

function Icons.save(p, c, props)
	local i = iconBase(p, props)
	fill(i, 2, 2, 12, 12, 2, c)
	fill(i, 5, 3, 6, 3, 1, Theme.Element)
	fill(i, 5, 9, 6, 4, 1, Theme.Element)
	return i
end

function Icons.search(p, c, props)
	local i = iconBase(p, props)
	outline(i, 1, 1, 10, 10, 5, c)
	fill(i, 9, 11, 6, 2, 1, c, 45)
	return i
end

function Icons.cloud(p, c, props)
	local i = iconBase(p, props)
	fill(i, 1, 7, 14, 7, 3, c)
	fill(i, 3, 4, 7, 7, 4, c)
	fill(i, 7, 2, 7, 8, 4, c)
	return i
end

-- cloud with a cut-out down arrow; hole is the colour behind the icon
function Icons.cloudDown(p, c, props, hole)
	local i = Icons.cloud(p, c, props)
	hole = hole or Theme.PopupCard
	fill(i, 7, 5, 2, 6, 1, hole)
	fill(i, 5, 9, 4, 2, 1, hole, 45)
	fill(i, 7, 9, 4, 2, 1, hole, -45)
	return i
end

function Icons.upload(p, c, props)
	local i = iconBase(p, props)
	fill(i, 7, 2, 2, 9, 1, c)
	fill(i, 3, 4, 7, 2, 1, c, -45)
	fill(i, 6, 4, 7, 2, 1, c, 45)
	fill(i, 1, 13, 14, 2, 1, c)
	return i
end

function Icons.trash(p, c, props)
	local i = iconBase(p, props)
	fill(i, 1, 3, 14, 2, 1, c)
	fill(i, 6, 1, 4, 2, 1, c)
	outline(i, 3, 5, 10, 10, 2, c)
	fill(i, 7, 7, 2, 6, 1, c)
	return i
end

function Icons.plus(p, c, props)
	local i = iconBase(p, props)
	fill(i, 7, 2, 2, 12, 1, c)
	fill(i, 2, 7, 12, 2, 1, c)
	return i
end

function Icons.sort(p, c, props)
	local i = iconBase(p, props)
	fill(i, 3, 1, 2, 12, 1, c)
	fill(i, 0, 10, 5, 2, 1, c, 45)
	fill(i, 3, 10, 5, 2, 1, c, -45)
	fill(i, 9, 3, 6, 2, 1, c)
	fill(i, 9, 7, 5, 2, 1, c)
	fill(i, 9, 11, 3, 2, 1, c)
	return i
end

-- sunrise: three rays over a line (hotkey entries)
function Icons.sparkle(p, c, props)
	local i = iconBase(p, props)
	fill(i, 7, 1, 2, 5, 1, c)
	fill(i, 2, 4, 2, 5, 1, c, -45)
	fill(i, 12, 4, 2, 5, 1, c, 45)
	outline(i, 4, 8, 8, 8, 4, c)
	fill(i, 1, 12, 14, 4, 0, Theme.PopupBg)
	fill(i, 1, 12, 14, 2, 1, c)
	return i
end

function Icons.plusCircle(p, c, props)
	local i = iconBase(p, props)
	fill(i, 1, 1, 14, 14, 7, c)
	fill(i, 7, 4, 2, 8, 1, Theme.PopupBg)
	fill(i, 4, 7, 8, 2, 1, Theme.PopupBg)
	return i
end

function Icons.undo(p, c, props)
	local i = iconBase(p, props)
	outline(i, 2, 2, 12, 12, 6, c)
	fill(i, 1, 1, 6, 6, 0, Theme.PopupBg)
	fill(i, 1, 2, 2, 6, 1, c)
	fill(i, 1, 6, 6, 2, 1, c)
	return i
end

function Icons.keyboard(p, c, props)
	local i = iconBase(p, props)
	outline(i, 1, 3, 14, 10, 2, c)
	for _, x in ipairs({ 4, 7, 10 }) do
		fill(i, x, 6, 2, 2, 1, c)
	end
	fill(i, 5, 9, 6, 2, 1, c)
	return i
end

function Icons.link(p, c, props)
	local i = iconBase(p, props)
	outline(i, 0, 5, 9, 6, 3, c).Rotation = -45
	outline(i, 7, 5, 9, 6, 3, c).Rotation = -45
	return i
end

function Icons.switchIcon(p, c, props)
	local i = iconBase(p, props)
	outline(i, 0, 4, 16, 8, 4, c)
	fill(i, 2, 6, 4, 4, 2, c)
	return i
end

function Icons.userMinus(p, c, props)
	local i = iconBase(p, props)
	fill(i, 3, 1, 6, 6, 3, c)
	fill(i, 0, 9, 12, 6, 3, c)
	fill(i, 11, 4, 5, 2, 1, c)
	return i
end

function Icons.listBox(p, c, props)
	local i = iconBase(p, props)
	outline(i, 1, 1, 14, 14, 3, c)
	fill(i, 4, 5, 2, 2, 1, c); fill(i, 7, 5, 5, 2, 1, c)
	fill(i, 4, 9, 2, 2, 1, c); fill(i, 7, 9, 5, 2, 1, c)
	return i
end

function Icons.expand(p, c, props)
	local i = iconBase(p, props)
	fill(i, 1, 7, 14, 2, 1, c, -45)
	fill(i, 9, 1, 6, 2, 1, c); fill(i, 13, 1, 2, 6, 1, c)
	fill(i, 1, 13, 6, 2, 1, c); fill(i, 1, 9, 2, 6, 1, c)
	return i
end

function Icons.sun(p, c, props)
	local i = iconBase(p, props)
	fill(i, 4, 4, 8, 8, 4, c)
	fill(i, 7, 0, 2, 3, 1, c); fill(i, 7, 13, 2, 3, 1, c)
	fill(i, 0, 7, 3, 2, 1, c); fill(i, 13, 7, 3, 2, 1, c)
	fill(i, 2, 2, 2, 3, 1, c, -45); fill(i, 12, 2, 2, 3, 1, c, 45)
	fill(i, 2, 11, 2, 3, 1, c, 45); fill(i, 12, 11, 2, 3, 1, c, -45)
	return i
end

-- crescent: a disc with a disc of the button colour cut out of its upper right
function Icons.moon(p, c, props)
	local i = iconBase(p, props)
	fill(i, 2, 2, 12, 12, 6, c)
	fill(i, 6, 0, 10, 10, 5, Theme.Element)
	return i
end

function Icons.wind(p, c, props)
	local i = iconBase(p, props)
	fill(i, 1, 3, 10, 2, 1, c)
	fill(i, 1, 7, 14, 2, 1, c)
	fill(i, 1, 11, 8, 2, 1, c)
	return i
end

function Icons.waves(p, c, props)
	local i = iconBase(p, props)
	for _, y in ipairs({ 3, 8, 13 }) do
		fill(i, 0, y, 6, 2, 1, c, -20)
		fill(i, 5, y, 6, 2, 1, c, 20)
		fill(i, 10, y, 6, 2, 1, c, -20)
	end
	return i
end

function Icons.bolt(p, c, props)
	local i = iconBase(p, props)
	fill(i, 6, 0, 4, 9, 1, c, 20)
	fill(i, 4, 7, 9, 2, 1, c)
	fill(i, 7, 7, 4, 9, 1, c, 20)
	return i
end

function Icons.drop(p, c, props)
	local i = iconBase(p, props)
	fill(i, 4, 6, 8, 9, 4, c)
	fill(i, 5, 3, 6, 6, 1, c, 45)
	return i
end

function Icons.snow(p, c, props)
	local i = iconBase(p, props)
	fill(i, 7, 1, 2, 14, 1, c)
	fill(i, 7, 1, 2, 14, 1, c, 60)
	fill(i, 7, 1, 2, 14, 1, c, -60)
	return i
end

function Icons.compass(p, c, props)
	local i = iconBase(p, props)
	outline(i, 1, 1, 14, 14, 7, c)
	fill(i, 6, 4, 4, 8, 2, c, 45)
	return i
end

function Icons.angle(p, c, props)
	local i = iconBase(p, props)
	fill(i, 2, 1, 2, 13, 1, c)
	fill(i, 2, 12, 13, 2, 1, c)
	fill(i, 2, 6, 10, 2, 1, c, -45)
	return i
end

function Icons.folderPlus(p, c, props)
	local i = iconBase(p, props)
	fill(i, 1, 2, 5, 2, 1, c)
	outline(i, 1, 3, 11, 10, 2, c)
	fill(i, 10, 11, 6, 2, 1, c)
	fill(i, 12, 9, 2, 6, 1, c)
	return i
end

function Icons.copy(p, c, props)
	local i = iconBase(p, props)
	outline(i, 5, 1, 10, 10, 2, c)
	fill(i, 1, 5, 10, 10, 2, c)
	return i
end

function Icons.chart(p, c, props)
	local i = iconBase(p, props)
	fill(i, 1, 10, 3, 5, 1, c)
	fill(i, 6, 6, 3, 9, 1, c)
	fill(i, 11, 2, 3, 13, 1, c)
	return i
end

function Icons.pin(p, c, props)
	local i = iconBase(p, props)
	fill(i, 3, 1, 10, 10, 5, c)
	fill(i, 7, 9, 2, 6, 1, c)
	return i
end

function Icons.puzzle(p, c, props)
	local i = iconBase(p, props)
	fill(i, 1, 1, 6, 6, 1, c); fill(i, 9, 1, 6, 6, 1, c)
	fill(i, 1, 9, 6, 6, 1, c); fill(i, 9, 9, 6, 6, 1, c)
	fill(i, 6, 3, 4, 2, 1, c); fill(i, 3, 6, 2, 4, 1, c)
	return i
end

local function setIconColor(icon, color)
	for _, d in ipairs(icon:GetDescendants()) do
		if d:IsA("UIStroke") then
			tween(d, { Color = color })
		elseif d:IsA("Frame") and d.BackgroundTransparency < 1 then
			tween(d, { BackgroundColor3 = color })
		end
	end
end

local function chevron(parent, position, rotation, color)
	local c = create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = position,
		Size = UDim2.fromOffset(10, 10),
		Rotation = rotation or 0,
		BackgroundTransparency = 1,
		Parent = parent,
	})
	for _, side in ipairs({ -1, 1 }) do
		create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, side * 2, 0.5, 0),
			Size = UDim2.fromOffset(6, 2),
			Rotation = side * -45,
			BackgroundColor3 = color or Theme.TabText,
			BorderSizePixel = 0,
			Parent = c,
		}, { corner(1) })
	end
	return c
end

local function checkMark(parent, position, color)
	local c = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = position,
		Size = UDim2.fromOffset(12, 12),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	fill(c, 1, 5, 5, 2, 1, color, 45)
	fill(c, 3, 4, 9, 2, 1, color, -50)
	return c
end

local function selectButton(parent, props)
	local base = {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Element,
	}
	for k, v in pairs(props) do
		base[k] = v
	end
	base.Parent = parent
	local button = create("TextButton", base, { corner(6), stroke(Theme.ElementStroke) })
	local value = textLabel({
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -32, 1, 0),
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = button,
	})
	chevron(button, UDim2.new(1, -9, 0.5, 0))
	trackPointer(button)
	button.MouseEnter:Connect(function()
		tween(button, { BackgroundColor3 = Theme.Hover })
	end)
	button.MouseLeave:Connect(function()
		tween(button, { BackgroundColor3 = Theme.Element })
	end)
	return button, value
end

-- Popup for option lists. Active = true so empty areas do not leak clicks to the blocker below.
local function popupFrame(width, color)
	return create("Frame", {
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = color or Theme.Element,
		Active = true,
		ZIndex = 2,
	}, { corner(8), litStroke(Theme.SelectLitTop, Theme.SelectLitBottom), list(0), padding(4, 4, 4, 4) })
end

------------------------------------------------------------------
-- Classes
------------------------------------------------------------------
local UI = {}
UI.__index = UI

local Tab = {}
Tab.__index = Tab

local Section = {}
Section.__index = Section

-- opts: RowH, Compact (popup style rows), Bg (background behind the rows)
local function newSection(box, window, opts)
	opts = opts or {}
	return setmetatable({
		Box = box,
		Window = window,
		Rows = {},
		_n = 0,
		RowH = opts.RowH or 39,
		Compact = opts.Compact == true,
		Bg = opts.Bg or Theme.Section,
	}, Section)
end

-- Popup panel: bold title, then cards ("groups"); returns the panel and the first group's section.
-- path: preset key prefix for rows inside (nil = rows are not saved in presets)
local function newPanel(window, width, title, path)
	local panel = create("Frame", {
		Size = UDim2.fromOffset(width or 270, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.PopupBg,
		Active = true,
		ZIndex = 2,
		Visible = false,
		Parent = window.Overlay,
	}, { corner(10), litStroke(Theme.PopupLitTop, Theme.PopupLitBottom), list(8), padding(10, 10, 10, 10) })
	if title then
		textLabel({
			Text = title,
			Size = UDim2.new(1, 0, 0, 24),
			FontFace = Theme.FontBold,
			TextSize = 14,
			TextColor3 = Theme.Text,
			LayoutOrder = 0,
			Parent = panel,
		}, { padding(0, 0, 0, 4) })
	end
	local groups = 0
	local function addGroup()
		groups += 1
		local card = create("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.PopupCard,
			LayoutOrder = groups,
			Parent = panel,
		}, { corner(8), stroke(Theme.PopupCardStroke), list(0), padding(3, 0, 3, 0) })
		local sec = newSection(card, window, { RowH = 32, Compact = true, Bg = Theme.PopupCard })
		sec._addGroup = addGroup
		sec.Path = path
		return sec
	end
	return panel, addGroup()
end

------------------------------------------------------------------
-- Colour picker
------------------------------------------------------------------
local function newColorPicker(window, defaultColor, defaultAlpha, callback)
	local h, s, v = (defaultColor or Color3.new(1, 1, 1)):ToHSV()
	local a = defaultAlpha or 1

	local popup = create("Frame", {
		Size = UDim2.fromOffset(232, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.PopupBg,
		Active = true,
		ZIndex = 2,
		Visible = false,
		Parent = window.Overlay,
	}, { corner(10), litStroke(Theme.PopupLitTop, Theme.PopupLitBottom), list(10), padding(10, 10, 10, 10) })

	local api = { Popup = popup, Swatches = {} }

	local sv = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 130),
		BackgroundColor3 = Color3.fromHSV(h, 1, 1),
		LayoutOrder = 1,
		Parent = popup,
	}, { corner(6) })
	sv:SetAttribute("NoTheme", true)
	trackPointer(sv)
	create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = sv,
	}, { corner(6), create("UIGradient", { Transparency = NumberSequence.new(0, 1) }) })
	create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Parent = sv,
	}, { corner(6), create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }) })
	local svKnob = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1,
		Parent = sv,
	}, { corner(5), stroke(Color3.new(1, 1, 1), 2) })

	local keypoints = {}
	for i = 0, 6 do
		table.insert(keypoints, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)))
	end
	local hueBar = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = 2,
		Parent = popup,
	}, { corner(3), create("UIGradient", { Color = ColorSequence.new(keypoints) }) })
	hueBar:FindFirstChildOfClass("UIGradient"):SetAttribute("NoTheme", true)
	local hueKnob = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = hueBar,
	}, { corner(6), stroke(Theme.Deep, 1) })

	local alphaBar = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = 3,
		Parent = popup,
	}, { corner(3) })
	local alphaGradient = create("UIGradient", {
		Color = ColorSequence.new(Theme.Element, Color3.new(1, 1, 1)),
		Parent = alphaBar,
	})
	local alphaKnob = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = alphaBar,
	}, { corner(6), stroke(Theme.Deep, 1) })

	-- HEX row: "HEX" | [■ #RRGGBBAA] | 100%
	local hexRow = create("Frame", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Parent = popup,
	})
	textLabel({
		Text = "HEX",
		Size = UDim2.new(0, 34, 1, 0),
		FontFace = Theme.FontBold,
		TextSize = 12,
		TextColor3 = Theme.TabText,
		Parent = hexRow,
	})
	local hexField = create("Frame", {
		Position = UDim2.fromOffset(38, 0),
		Size = UDim2.new(1, -38 - 52, 1, 0),
		BackgroundColor3 = Theme.Element,
		Parent = hexRow,
	}, { corner(6), stroke(Theme.ElementStroke) })
	local hexSwatch = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 7, 0.5, 0),
		Size = UDim2.fromOffset(10, 10),
		Parent = hexField,
	}, { corner(3) })
	hexSwatch:SetAttribute("NoTheme", true)
	local hexBox = create("TextBox", {
		Text = "",
		ClearTextOnFocus = false,
		FontFace = Theme.Font,
		TextSize = 12,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(22, 0),
		Size = UDim2.new(1, -26, 1, 0),
		Parent = hexField,
	})
	local alphaLabel = textLabel({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 46, 1, 0),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.Element,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 12,
		Parent = hexRow,
	}, { corner(6), stroke(Theme.ElementStroke) })

	local function currentColor()
		return Color3.fromHSV(h, s, v)
	end

	local function render()
		local c = currentColor()
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		svKnob.Position = UDim2.fromScale(s, 1 - v)
		hueKnob.Position = UDim2.fromScale(h, 0.5)
		hueKnob.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		alphaGradient.Color = ColorSequence.new(Theme.Element, c)
		alphaKnob.Position = UDim2.fromScale(a, 0.5)
		hexSwatch.BackgroundColor3 = c
		if not hexBox:IsFocused() then
			hexBox.Text = toHex(c, a)
		end
		alphaLabel.Text = tostring(math.floor(a * 100 + 0.5)) .. "%"
		for _, sw in ipairs(api.Swatches) do
			sw.BackgroundColor3 = c
		end
	end

	local function fire()
		render()
		if callback then
			task.spawn(callback, currentColor(), a)
		end
	end

	local function drag(button, handler)
		local active = false
		button.InputBegan:Connect(function(input)
			if isClick(input) then
				active = true
				handler(pointerPosition(input))
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if active and isMove(input) then
				handler(pointerPosition(input))
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if isClick(input) then
				active = false
			end
		end)
	end

	drag(sv, function(p)
		s = math.clamp((p.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
		v = 1 - math.clamp((p.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
		fire()
	end)
	drag(hueBar, function(p)
		h = math.clamp((p.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 0.999)
		fire()
	end)
	drag(alphaBar, function(p)
		a = math.clamp((p.X - alphaBar.AbsolutePosition.X) / alphaBar.AbsoluteSize.X, 0, 1)
		fire()
	end)
	hexBox.FocusLost:Connect(function()
		local c, alpha = fromHex(hexBox.Text)
		if c then
			h, s, v = c:ToHSV()
			a = alpha or a
			fire()
		else
			render()
		end
	end)

	function api:Set(color, alpha)
		h, s, v = color:ToHSV()
		a = alpha or a
		fire()
	end
	function api:Get()
		return currentColor(), a
	end
	function api:AddSwatch(swatch)
		table.insert(api.Swatches, swatch)
		swatch.BackgroundColor3 = currentColor()
	end

	render()
	return api
end

-- Small rounded square that opens a colour picker
local function addSwatch(window, row, position, defaultColor, defaultAlpha, callback)
	local picker = newColorPicker(window, defaultColor, defaultAlpha, callback)
	local swatch = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = position,
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = defaultColor,
		Parent = row,
	}, { corner(4) })
	picker:AddSwatch(swatch)
	swatch:SetAttribute("NoTheme", true) -- shows the user's colour, never the theme's
	trackPointer(swatch) -- 14 px: the most reliable place to measure the pointer shift
	swatch.MouseButton1Click:Connect(function()
		window:ShowPopup(swatch, picker.Popup, true)
	end)
	if callback then
		task.spawn(callback, defaultColor, defaultAlpha or 1)
	end
	return picker, swatch
end

------------------------------------------------------------------
-- Window
------------------------------------------------------------------
function UI.new(config)
	config = config or {}
	local self = setmetatable({}, UI)
	self.Config = config
	self.Tabs = {}
	self._order = 0
	self._visible = false
	self._stack = {}
	self._hotkeys = {}
	self._elements = {}
	self._rows = {}
	self._binds = {}
	self.UserScale = 1
	self.ThemeMode = "Dark"
	self._shadows = {}

	-- Parent: the executor's hidden UI container (gethui) or CoreGui, so the game's own GUIs cannot cover the menu
	-- and it stays visible above the Roblox Esc menu (OnTopOfCoreBlur). PlayerGui is the fallback.
	local function menuParent()
		local ok, hidden = pcall(function()
			return gethui and gethui()
		end)
		if ok and typeof(hidden) == "Instance" then
			return hidden
		end
		local okCore, core = pcall(function()
			return game:GetService("CoreGui")
		end)
		if okCore then
			local probe = Instance.new("Folder")
			local writable = pcall(function()
				probe.Parent = core
			end)
			probe:Destroy()
			if writable then
				return core
			end
		end
		return player:WaitForChild("PlayerGui")
	end
	local gui = create("ScreenGui", {
		Name = "LumenMenu",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 2147483647,
		OnTopOfCoreBlur = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = menuParent(),
	})
	self.Gui = gui
	self._modal = create("TextButton", {
		Name = "CursorUnlock",
		Text = "",
		Modal = false,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 0),
		Parent = gui,
	})

	local holder = create("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(config.Width or 820, config.Height or 640),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 1,
		Parent = gui,
	})
	self.Holder = holder
	self.Scale = create("UIScale", { Parent = holder })

	self.ShadowLayer = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 0,
		Parent = holder,
	})

	-- Popup layer
	local overlay = create("Frame", {
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	})
	self.Overlay = overlay
	self.OverlayScale = create("UIScale", { Parent = overlay })
	local blocker = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 1,
		Parent = overlay,
	})
	blocker.MouseButton1Click:Connect(function()
		self:ClosePopup()
	end)
	self.Blocker = blocker

	self.ToggleKey = config.ToggleKey or Enum.KeyCode.Delete -- changed by the "Menu Bind" row of the profile popup

	-- watermark / hotkeys / spectators / logs live on the screen, not on the window
	self:_buildHud(config)

	------------------------------------------------------------------
	-- Main window
	------------------------------------------------------------------
	local window = create("Frame", {
		Name = "Window",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Window,
		BackgroundTransparency = Theme.WindowTransparency,
		ZIndex = 1,
		Parent = holder,
	}, {
		corner(16),
		litStroke(Theme.WindowLitTop, Theme.Deep),
	})
	self:_shadow(window, 0.5, 16) -- 16 px wide, same radius as the window's corners

	local sidebar = create("Frame", {
		Size = UDim2.new(0, 172, 1, 0),
		BackgroundTransparency = 1,
		Parent = window,
	})

	-- Logo: big "NL" letters, title and subtitle
	local header = create("Frame", {
		Size = UDim2.new(1, 0, 0, 62),
		BackgroundTransparency = 1,
		Parent = sidebar,
	})
	textLabel({
		Text = config.Logo or "UI",
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(40, 34),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.FontHeavy,
		TextSize = 26,
		TextColor3 = Theme.Text,
		Parent = header,
	})
	textLabel({
		Text = config.Title or "Menu",
		Position = UDim2.fromOffset(60, 15),
		Size = UDim2.new(1, -66, 0, 18),
		FontFace = Theme.FontBold,
		TextSize = 16,
		TextColor3 = Theme.Text,
		Parent = header,
	})
	textLabel({
		Text = config.Subtitle or "",
		Position = UDim2.fromOffset(60, 33),
		Size = UDim2.new(1, -66, 0, 14),
		FontFace = Theme.FontLight,
		TextSize = 12,
		TextColor3 = Theme.SubText,
		Parent = header,
	})

	self.TabList = create("Frame", {
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 1, -126),
		BackgroundTransparency = 1,
		Parent = sidebar,
	}, { list(3), padding(0, 10, 0, 10) })

	-- Profile block at the bottom
	local footer = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -6),
		Size = UDim2.new(1, -16, 0, 50),
		BackgroundColor3 = Theme.Active,
		BackgroundTransparency = 1,
		Parent = sidebar,
	}, { corner(8) })
	create("Frame", {
		Position = UDim2.new(0, -8, 0, -6),
		Size = UDim2.new(1, 16, 0, 1),
		BackgroundColor3 = Theme.Divider,
		BorderSizePixel = 0,
		Parent = footer,
	})
	local avatar = create("ImageLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = Theme.Element,
		Parent = footer,
	}, { corner(15) })
	textLabel({
		Text = player.Name,
		Position = UDim2.fromOffset(46, 9),
		Size = UDim2.new(1, -70, 0, 16),
		FontFace = Theme.FontBold,
		TextSize = 14,
		TextColor3 = Theme.Text,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = footer,
	})
	textLabel({
		Text = config.FooterText or "Profile",
		Position = UDim2.fromOffset(46, 26),
		Size = UDim2.new(1, -70, 0, 14),
		FontFace = Theme.FontLight,
		TextSize = 12,
		TextColor3 = Theme.SubText,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = footer,
	})
	chevron(footer, UDim2.new(1, -8, 0.5, 0), -90)
	footer.MouseEnter:Connect(function()
		tween(footer, { BackgroundTransparency = 0.5 })
	end)
	footer.MouseLeave:Connect(function()
		tween(footer, { BackgroundTransparency = 1 })
	end)

	-- Popup of the profile block
	local footerPanel = create("Frame", {
		Size = UDim2.fromOffset(260, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.PopupBg,
		Active = true,
		ZIndex = 2,
		Visible = false,
		Parent = overlay,
	}, { corner(10), litStroke(Theme.PopupLitTop, Theme.PopupLitBottom), list(4), padding(8, 8, 8, 8) })
	local head = create("Frame", {
		Size = UDim2.new(1, 0, 0, 62),
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		Parent = footerPanel,
	})
	local avatar2 = create("ImageLabel", {
		Position = UDim2.fromOffset(4, 6),
		Size = UDim2.fromOffset(42, 42),
		BackgroundColor3 = Theme.Element,
		Parent = head,
	}, { corner(21) })
	textLabel({
		Text = player.Name,
		Position = UDim2.fromOffset(56, 4),
		Size = UDim2.new(1, -60, 0, 18),
		FontFace = Theme.FontBold,
		TextSize = 14,
		TextColor3 = Theme.Text,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = head,
	})
	textLabel({
		Text = config.FooterSubtext or ("Till: " .. (config.FooterText or "")),
		Position = UDim2.fromOffset(56, 22),
		Size = UDim2.new(1, -60, 0, 16),
		TextSize = 13,
		TextColor3 = Theme.TextDim,
		Parent = head,
	})
	if config.FooterLink then
		local link = create("TextButton", {
			Text = config.FooterLink[1],
			FontFace = Theme.Font,
			TextSize = 13,
			TextColor3 = Theme.Accent,
			TextXAlignment = Enum.TextXAlignment.Left,
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(56, 39),
			Size = UDim2.fromOffset(80, 16),
			Parent = head,
		})
		link.MouseButton1Click:Connect(function()
			if config.FooterLink[2] then
				task.spawn(config.FooterLink[2])
			end
		end)
	end
	create("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Divider,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		Parent = footerPanel,
	})
	local footerRows = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = footerPanel,
	}, { list(0) })
	self.FooterMenu = newSection(footerRows, self, { RowH = 32, Compact = true, Bg = Theme.PopupBg })
	self.FooterMenu.Path = "Profile" -- rows of the profile popup (scales, style, menu bind, ...) are part of presets too
	footer.MouseButton1Click:Connect(function()
		self:ShowPopup(footer, footerPanel, true, "left")
	end)

	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(
				player.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size48x48
			)
		end)
		if ok then
			avatar.Image = img
			avatar2.Image = img
		end
	end)

	------------------------------------------------------------------
	-- Right part
	------------------------------------------------------------------
	local content = create("Frame", {
		Position = UDim2.fromOffset(172, 8),
		Size = UDim2.new(1, -180, 1, -16),
		BackgroundColor3 = Theme.Content,
		ClipsDescendants = true,
		Parent = window,
	}, { corner(14), litStroke(Theme.ContentLitTop, Theme.ContentStroke) })
	local toolbar = create("Frame", {
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundTransparency = 1,
		Parent = content,
	})
	create("Frame", {
		Position = UDim2.new(0, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Divider,
		BorderSizePixel = 0,
		Parent = toolbar,
	})

	-- Profile selector: [save icon | name ⌄]
	local profiles = config.Profiles or { "default" }
	self.Profile = profiles[1]
	local profileBtn, profileLabel = selectButton(toolbar, {
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(150, 30),
	})
	profileLabel.Position = UDim2.fromOffset(42, 0)
	profileLabel.Size = UDim2.new(1, -62, 1, 0)
	Icons.save(profileBtn, Theme.TabText, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 9, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
	})
	create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 33, 0.5, 0),
		Size = UDim2.fromOffset(1, 18),
		BackgroundColor3 = Theme.ElementStroke,
		BorderSizePixel = 0,
		Parent = profileBtn,
	})
	self.ProfileLabel = profileLabel
	self._presets = {}
	for _, name in ipairs(profiles) do
		table.insert(self._presets, { Name = name })
	end
	profileLabel.Text = self.Profile
	self:_buildPresets(profileBtn)

	if config.Options then
		local optValue = config.Options[1]
		local optBtn, optLabel = selectButton(toolbar, {
			Position = UDim2.fromOffset(170, 12),
			Size = UDim2.fromOffset(86, 30),
			Visible = false,
		})
		self.OptionsButton = optBtn
		optLabel.Text = optValue
		optBtn.MouseButton1Click:Connect(function()
			self:_openSelect(optBtn, config.Options, function(o)
				return o == optValue
			end, function(o)
				optValue = o
				optLabel.Text = o
				if config.OnOption then
					task.spawn(config.OnOption, o)
				end
			end, false)
		end)
	end

	-- Search: icon that expands into a field
	local searchButton = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = Theme.Hover,
		BackgroundTransparency = 1,
		Parent = toolbar,
	}, { corner(6) })
	Icons.search(searchButton, Theme.TabText, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
	})
	local searchField = create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -46, 0.5, 0),
		Size = UDim2.fromOffset(0, 30),
		BackgroundColor3 = Theme.Element,
		ClipsDescendants = true,
		Visible = false,
		Parent = toolbar,
	}, { corner(6), stroke(Theme.ElementStroke) })
	local search = create("TextBox", {
		Text = "",
		PlaceholderText = "Search",
		PlaceholderColor3 = Theme.SubText,
		ClearTextOnFocus = false,
		FontFace = Theme.Font,
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 1, 0),
		Parent = searchField,
	})
	self.Search = search
	local searchOpen = false
	searchButton.MouseEnter:Connect(function()
		tween(searchButton, { BackgroundTransparency = 0.4 })
	end)
	searchButton.MouseLeave:Connect(function()
		tween(searchButton, { BackgroundTransparency = 1 })
	end)
	searchButton.MouseButton1Click:Connect(function()
		searchOpen = not searchOpen
		if searchOpen then
			searchField.Visible = true
			tween(searchField, { Size = UDim2.fromOffset(180, 30) }, 0.2)
			search:CaptureFocus()
		else
			search.Text = ""
			tween(searchField, { Size = UDim2.fromOffset(0, 30) }, 0.2)
			task.delay(0.2, function()
				if not searchOpen then
					searchField.Visible = false
				end
			end)
		end
	end)
	search:GetPropertyChangedSignal("Text"):Connect(function()
		self:_filter(search.Text)
	end)

	self.Pages = create("Frame", {
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 1, -54),
		BackgroundTransparency = 1,
		Parent = content,
	})

	------------------------------------------------------------------
	-- Dragging and toggle key
	------------------------------------------------------------------
	local function makeDraggable(handle)
		local dragging, startInput, startPos = false, nil, nil
		handle.InputBegan:Connect(function(input)
			if isClick(input) then
				dragging = true
				startInput = input.Position
				startPos = holder.Position
				self:ClosePopup()
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
					end
				end)
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if dragging and isMove(input) then
				local d = input.Position - startInput
				holder.Position = UDim2.new(
					startPos.X.Scale, startPos.X.Offset + d.X,
					startPos.Y.Scale, startPos.Y.Offset + d.Y
				)
			end
		end)
	end
	makeDraggable(toolbar)
	makeDraggable(header)

	UserInputService.InputBegan:Connect(function(input, processed)
		if self._unloaded then
			return
		end
		-- a bind menu waiting for its key takes the next press
		if self._listening then
			local consume = self._listening
			if consume(input) then
				self._listening = nil
			end
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton2 and self._visible then
			self:_onRightClick(pointerPosition(input))
		end
		if processed and input.UserInputType == Enum.UserInputType.Keyboard then
			return -- typing in a text box or chat
		end
		-- not while a key is being captured, nor in the instant after (the press that set the bind)
		local capturing = self._capturing or os.clock() - (self._captureEnd or 0) < 0.2
		if input.KeyCode == self.ToggleKey and not capturing then
			self:SetVisible(not self._visible)
		end
		self:_bindInput(input, true)
	end)
	UserInputService.InputEnded:Connect(function(input)
		if self._unloaded then
			return
		end
		self:_bindInput(input, false)
	end)

	-- Loader toast, then the menu appears
	task.spawn(function()
		task.wait() -- let the calling script finish building tabs first
		self:_allOff()
		self:_initPresets()
		self:_restore()
		self:_runLoader()
		self:SetVisible(true)
	end)

	return self
end

-- Soft shadow from rounded layers, each SHADOW_STEP px larger than the last, the same on every side.
-- Band i (counted outwards from the window) gets opacity strength * (1 - (i-1)/steps)^2; each layer's
-- own alpha is solved from that, because a band is covered by its layer and every larger one.
local SHADOW_STEPS, SHADOW_STEP = 8, 2

local function shadowAlphas(strength)
	local function band(i)
		if i > SHADOW_STEPS then
			return 0
		end
		return strength * (1 - (i - 1) / SHADOW_STEPS) ^ 2
	end
	local alphas = {}
	for i = 1, SHADOW_STEPS do
		alphas[i] = 1 - (1 - band(i)) / (1 - band(i + 1))
	end
	return alphas
end

function UI:_shadow(target, strength, radius)
	local layer = self.ShadowLayer
	local frames = {}
	for i, alpha in ipairs(shadowAlphas(strength)) do
		local f = create("Frame", {
			BackgroundColor3 = SHADOW_COLORS[self.ThemeMode],
			BackgroundTransparency = 1 - alpha,
			BorderSizePixel = 0,
			Parent = layer,
		}, { corner(radius + i * SHADOW_STEP) })
		f:SetAttribute("NoTheme", true)
		frames[i] = f
		table.insert(self._shadows, f)
	end
	local function update()
		local scale = self.Scale.Scale
		local rel = (target.AbsolutePosition - layer.AbsolutePosition) / scale
		local size = target.AbsoluteSize / scale
		for i, f in ipairs(frames) do
			local o = i * SHADOW_STEP
			f.Position = UDim2.fromOffset(rel.X - o, rel.Y - o)
			f.Size = UDim2.fromOffset(size.X + o * 2, size.Y + o * 2)
			f.Visible = target.Visible
		end
	end
	target:GetPropertyChangedSignal("AbsolutePosition"):Connect(update)
	target:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	target:GetPropertyChangedSignal("Visible"):Connect(update)
	layer:GetPropertyChangedSignal("AbsolutePosition"):Connect(update)
	task.defer(update)
end

function UI:_nextOrder()
	self._order += 1
	return self._order
end

-- Free the mouse while the menu is open: a Modal button (Roblox unlocks the cursor for it) plus, every frame after the
-- game's camera code, MouseBehavior = Default and the cursor icon on. The previous values are put back on close.
function UI:_setCursor(open)
	pcall(RunService.UnbindFromRenderStep, RunService, "NeverloseCursor")
	if self._modal then
		self._modal.Modal = open
	end
	if open then
		if not self._cursorPrev then
			self._cursorPrev = { Icon = UserInputService.MouseIconEnabled, Behavior = UserInputService.MouseBehavior }
		end
		RunService:BindToRenderStep("NeverloseCursor", Enum.RenderPriority.Last.Value, function()
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end)
	elseif self._cursorPrev then
		UserInputService.MouseIconEnabled = self._cursorPrev.Icon
		UserInputService.MouseBehavior = self._cursorPrev.Behavior
		self._cursorPrev = nil
	end
end

-- Unload: give the mouse back, drop the hotkeys and remove the whole GUI
function UI:_unload()
	self._unloaded = true
	self._visible = false
	self:_setCursor(false)
	self:_clearBinds()
	self.Gui:Destroy()
end

function UI:SetVisible(v)
	self._visible = v
	self:_setCursor(v)
	local target = self.UserScale
	if v then
		self.Holder.Visible = true
		self.Scale.Scale = target * 0.94
		TweenService:Create(self.Scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target }):Play()
	else
		self:ClosePopup()
		local t = TweenService:Create(self.Scale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = target * 0.94 })
		t:Play()
		t.Completed:Connect(function()
			if not self._visible then
				self.Holder.Visible = false
			end
		end)
	end
end

------------------------------------------------------------------
-- Theme: accent colour and dark / light mode, applied to everything already built
------------------------------------------------------------------
local function colorKey(c)
	return string.format("%d,%d,%d", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255))
end

-- colours that are not theme colours but appear in the gui (knobs, ESP, danger / warning text)
local RESERVED_COLORS = { ["255,255,255"] = true, ["0,0,0"] = true, ["240,90,100"] = true, ["240,180,70"] = true }

local function softAccent(accent, background)
	return accent:Lerp(background, 0.78)
end

-- Accent colours must not equal any other theme colour (or each other), or the next recolour would
-- also catch elements of that colour — e.g. a dark accent mixed into the popup background gave exactly
-- the background colour, and the whole menu background followed the accent from then on.
-- palette: colours to stay clear of (defaults to the current Theme)
local function uniqueColor(c, avoid, palette)
	local r, g, b = math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255)
	local function taken(key)
		if RESERVED_COLORS[key] or (avoid and avoid[key]) then
			return true
		end
		for name, v in pairs(palette or Theme) do
			if name ~= "Accent" and name ~= "AccentSoft" and typeof(v) == "Color3" and colorKey(v) == key then
				return true
			end
		end
		return false
	end
	for _ = 1, 256 do
		if not taken(string.format("%d,%d,%d", r, g, b)) then
			break
		end
		b = (b + 1) % 256
	end
	return Color3.fromRGB(r, g, b)
end

local function accentPair(color, background, palette)
	local accent = uniqueColor(color, nil, palette)
	local soft = uniqueColor(softAccent(accent, background), { [colorKey(accent)] = true }, palette)
	return accent, soft
end

-- changes: { ThemeKey = Color3 }. Updates Theme and recolours every element that uses an old value.
function UI:_retheme(changes)
	local map = {}
	for key, c in pairs(changes) do
		local old = Theme[key]
		if old and colorKey(old) ~= colorKey(c) then
			map[colorKey(old)] = c
		end
		Theme[key] = c
	end
	if next(map) == nil then
		return
	end
	self._themeVersion = (self._themeVersion or 0) + 1
	local function remap(c)
		return map[colorKey(c)]
	end
	for _, d in ipairs(self.Gui:GetDescendants()) do
		if d:GetAttribute("NoTheme") then
			continue
		end
		if d:IsA("GuiObject") then
			local n = remap(d.BackgroundColor3)
			if n then
				d.BackgroundColor3 = n
			end
			if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
				n = remap(d.TextColor3)
				if n then
					d.TextColor3 = n
				end
				if d:IsA("TextBox") then
					n = remap(d.PlaceholderColor3)
					if n then
						d.PlaceholderColor3 = n
					end
				end
			end
			if d:IsA("ScrollingFrame") then
				n = remap(d.ScrollBarImageColor3)
				if n then
					d.ScrollBarImageColor3 = n
				end
			end
		elseif d:IsA("UIStroke") then
			local n = remap(d.Color)
			if n then
				d.Color = n
			end
		elseif d:IsA("UIGradient") then
			local changed, points = false, {}
			for _, kp in ipairs(d.Color.Keypoints) do
				local n = remap(kp.Value)
				changed = changed or n ~= nil
				table.insert(points, ColorSequenceKeypoint.new(kp.Time, n or kp.Value))
			end
			if changed then
				d.Color = ColorSequence.new(points)
			end
		end
	end
end

-- Accent for switches, sliders, icons, selections. Calls are coalesced (the picker fires on every drag step).
function UI:SetAccent(color)
	self._pendingAccent = color
	if self._accentScheduled then
		return
	end
	self._accentScheduled = true
	task.delay(0.05, function()
		self._accentScheduled = false
		local accent, soft = accentPair(self._pendingAccent, Theme.PopupBg)
		self:_retheme({ Accent = accent, AccentSoft = soft })
	end)
end

-- "Dark" | "Light"
function UI:SetThemeMode(mode)
	local palette = PALETTES[mode]
	if not palette or mode == self.ThemeMode then
		return
	end
	self.ThemeMode = mode
	-- one recolour pass: the accent pair is made unique against the new palette before anything changes
	local changes = table.clone(palette)
	local accent, soft = accentPair(Theme.Accent, palette.PopupBg, palette)
	changes.Accent = accent
	changes.AccentSoft = soft
	self:_retheme(changes)
	for _, s in ipairs(self._shadows) do
		s.BackgroundColor3 = SHADOW_COLORS[mode]
	end
	self._shadowColor = nil -- back to the plain shadow of the mode
end

------------------------------------------------------------------
-- Menu colour: the user picks the colour of the window itself and the whole palette is built around it. A dark colour
-- (luminance < 0.5) uses the Dark palette as its base, a light one the Light palette, so text, icons and shadows keep their
-- contrast. Every surface keeps its offset from the base palette's Window, so cards, strokes and hover states keep their
-- relative lightness. Colours stay unique inside the palette (the recolour maps old values to new ones by value) and never
-- equal a reserved colour (white, black, danger / warning text).
------------------------------------------------------------------
local TEXT_KEYS = { Text = true, TextDim = true, TabText = true, SubText = true, IconDim = true, KnobOff = true }

local function luminance(c)
	return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
end

local function menuPalette(base, color)
	if colorKey(color) == colorKey(base.Window) then
		return table.clone(base) -- exactly the default of this mode: nothing is recomputed
	end
	local out, used, byBase = {}, {}, {}
	for key, value in pairs(base) do
		if TEXT_KEYS[key] then
			out[key] = value
			used[colorKey(value)] = true
		end
	end
	local order = {}
	for key in pairs(base) do
		if not TEXT_KEYS[key] then
			table.insert(order, key)
		end
	end
	table.sort(order)
	local window = base.Window
	local function byte(x)
		return math.round(x * 255)
	end
	-- the window colour is moved into the range where every surface (Window + its offset) still fits in 1..254, so extreme
	-- picks (near white / black) do not squash several surfaces onto the same value
	local lo, hi = { 1, 1, 1 }, { 254, 254, 254 }
	local channels = { "R", "G", "B" }
	for key in pairs(base) do
		if not TEXT_KEYS[key] then
			for i, ch in ipairs(channels) do
				local offset = byte(base[key][ch]) - byte(window[ch])
				lo[i] = math.max(lo[i], 1 - offset)
				hi[i] = math.min(hi[i], 254 - offset)
			end
		end
	end
	local w = {}
	for i, ch in ipairs(channels) do
		w[i] = math.clamp(byte(color[ch]), lo[i], math.max(lo[i], hi[i]))
	end
	for _, key in ipairs(order) do
		local value = base[key]
		local baseKey = colorKey(value)
		local result = byBase[baseKey] -- keys that share a colour in the base (Stroke / SectionStroke) share it here too
		if not result then
			local r = math.clamp(w[1] + byte(value.R) - byte(window.R), 1, 254)
			local g = math.clamp(w[2] + byte(value.G) - byte(window.G), 1, 254)
			local b = math.clamp(w[3] + byte(value.B) - byte(window.B), 1, 254)
			local tries = 0
			local k = string.format("%d,%d,%d", r, g, b)
			while (used[k] or RESERVED_COLORS[k]) and tries < 512 do
				tries += 1
				b = (b % 254) + 1
				k = string.format("%d,%d,%d", r, g, b)
			end
			result = Color3.fromRGB(r, g, b)
			byBase[baseKey] = result
			used[k] = true
		end
		out[key] = result
	end
	return out
end

------------------------------------------------------------------
-- Menu transparency: the big surfaces of the menu (window, content area, section cards, popups) become see-through, the
-- controls on them stay solid. A surface is recognised by its background colour (the Window / Content / Section / Popup
-- colours of the live theme, so a custom menu colour works too); its designed transparency is remembered in the attribute
-- NLBaseT and the shown one is 1 - (1 - designed) * (1 - t). The HUD windows have their own settings and are skipped.
------------------------------------------------------------------
local FADE_KEYS = { "Window", "Content", "Section", "PopupBg", "PopupCard" }

function UI:_fadeSurface(d)
	if not d:IsA("GuiObject") or d:GetAttribute("NoTheme") or d:IsDescendantOf(self.Hud) then
		return
	end
	local base = d:GetAttribute("NLBaseT")
	if base == nil then
		if d.BackgroundTransparency >= 1 then
			return
		end
		local key = colorKey(d.BackgroundColor3)
		local surface = false
		for _, name in ipairs(FADE_KEYS) do
			if colorKey(Theme[name]) == key then
				surface = true
				break
			end
		end
		if not surface then
			return
		end
		base = d.BackgroundTransparency
		d:SetAttribute("NLBaseT", base)
	end
	d.BackgroundTransparency = 1 - (1 - base) * (1 - self._menuTransparency)
end

-- t: 0 = as designed, up to 0.9. Calls are coalesced (the slider fires on every drag step).
function UI:SetMenuTransparency(t)
	self._menuTransparency = math.clamp(t, 0, 0.9)
	if not self._fadeConn then
		self._fadeConn = self.Gui.DescendantAdded:Connect(function(d)
			if self._fadeTouched then
				self:_fadeSurface(d) -- popups and sections built later follow the setting
			end
		end)
	end
	if self._fadeScheduled then
		return
	end
	self._fadeScheduled = true
	task.delay(0.05, function()
		self._fadeScheduled = false
		if self._menuTransparency == 0 and not self._fadeTouched then
			return -- nothing was ever changed: leave the menu alone
		end
		self._fadeTouched = true
		for _, d in ipairs(self.Gui:GetDescendants()) do
			self:_fadeSurface(d)
		end
	end)
end

-- The window colour. Calls are coalesced (the picker fires on every drag step).
function UI:SetMenuColor(color)
	if self._syncingMenuColor then
		return -- the swatch is only being moved to the window colour of a mode (sun / moon switch)
	end
	self._pendingMenuColor = color
	if self._menuColorScheduled then
		return
	end
	self._menuColorScheduled = true
	task.delay(0.05, function()
		self._menuColorScheduled = false
		local picked = self._pendingMenuColor
		local mode = if luminance(picked) < 0.5 then "Dark" else "Light"
		local changes = menuPalette(PALETTES[mode], picked)
		local accent, soft = accentPair(Theme.Accent, changes.PopupBg, changes)
		changes.Accent, changes.AccentSoft = accent, soft
		self.ThemeMode = mode
		-- the shadow takes the colour too: the window colour pulled towards black (dark) or white (light); the default colour of a mode keeps the plain shadow
		local shadow = nil
		if colorKey(picked) ~= colorKey(PALETTES[mode].Window) then
			shadow = if mode == "Dark" then picked:Lerp(Color3.new(0, 0, 0), 0.3) else picked:Lerp(Color3.new(1, 1, 1), 0.3)
		end
		self._shadowColor = shadow
		self:_retheme(changes)
		self._themeVersion = (self._themeVersion or 0) + 1 -- the indicators re-read the palette and the shadow colour
		for _, s in ipairs(self._shadows) do
			s.BackgroundColor3 = shadow or SHADOW_COLORS[mode]
		end
	end)
end

-- Menu (window + its popups) scale; animated while the menu is open
function UI:SetScale(scale)
	scale = math.clamp(scale, 0.5, 2)
	if math.abs(scale - self.UserScale) < 0.001 then
		return
	end
	self.UserScale = scale
	self:ClosePopup()
	self.OverlayScale.Scale = scale
	-- the popup layer is scaled too; the click-away blocker must still cover the whole screen
	self.Blocker.Size = UDim2.fromScale(1 / scale, 1 / scale)
	if self._visible then
		TweenService:Create(self.Scale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = scale,
		}):Play()
	end
end

-- Largest scale (up to 100 %) at which the whole window fits on the screen with a 30 px margin
function UI:GetFitScale()
	local screen = self.Gui.AbsoluteSize
	local size = self.Holder.Size
	if screen.X <= 0 or screen.Y <= 0 then
		return 1
	end
	local fit = math.min((screen.X - 60) / size.X.Offset, (screen.Y - 60) / size.Y.Offset, 1)
	return math.clamp(fit, 0.5, 1)
end

------------------------------------------------------------------
-- HUD windows: watermark, hotkeys, spectators, event logs (top right of the screen)
------------------------------------------------------------------
local Stats = game:GetService("Stats")

-- Watermark items in display order: name, icon. Values a LocalScript cannot read show "n/a".
local WATERMARK_ITEMS = {
	{ "Logo", "text" }, { "KD Ratio", "crosshair" }, { "Speed", "compass" }, { "Framerate", "chart" },
	{ "GPU Load", "window" }, { "CPU Load", "grid" }, { "CPU Frequency", "waves" }, { "CPU Cores", "grid" },
	{ "Memory Load", "layers" }, { "Delay", "chart" }, { "Delivery Issues", "wind" },
	{ "Server Stability", "list" }, { "Connection Status", "globe" }, { "Packet Loss", "wind" },
	{ "Late Packets", "clock" }, { "Network Jitter", "waves" }, { "Input Timing", "keyboard" },
	{ "Prediction Lead", "crosshair" }, { "Network Traffic", "sort" }, { "Server Address", "ring" },
	{ "Preset", "cloud" }, { "Username", "user" }, { "Time", "clock" },
}

local WATERMARK_POSITIONS = {
	["Top-Left"] = { Vector2.new(0, 0), UDim2.new(0, 14, 0, 12) },
	["Top-Center"] = { Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 12) },
	["Top-Right"] = { Vector2.new(1, 0), UDim2.new(1, -14, 0, 12) },
	["Bottom-Right"] = { Vector2.new(1, 1), UDim2.new(1, -14, 1, -12) },
	["Bottom-Center"] = { Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -12) },
	["Bottom-Left"] = { Vector2.new(0, 1), UDim2.new(0, 14, 1, -12) },
}

-- height, side padding, gap between items
local WATERMARK_DENSITY = { Compact = { 30, 12, 10 }, Default = { 36, 16, 16 }, Spacious = { 42, 20, 22 } }

local STATUS_COLORS = { Good = rgb(110, 220, 130), Warn = rgb(240, 200, 80), Bad = rgb(240, 90, 100) }

local function readNumber(fn)
	local ok, v = pcall(fn)
	if ok and type(v) == "number" and v == v and v ~= math.huge then
		return v
	end
	return nil
end

-- higherIsBetter: fps; otherwise lower is better (ping, jitter)
local function grade(v, good, warn, higherIsBetter)
	if higherIsBetter then
		return if v >= good then "Good" elseif v >= warn then "Warn" else "Bad"
	end
	return if v <= good then "Good" elseif v <= warn then "Warn" else "Bad"
end

function UI:_buildHud(config)
	local hud = create("Frame", {
		Name = "Hud",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = self.Gui,
	})
	self.Hud = hud
	self.Windows = {}
	self._hudScales = {}
	self._windowOn = { Watermark = true, Hotkeys = true, Spectators = true, ["Event Logs"] = true }
	self.HudOptions = {
		Color = Color3.fromRGB(235, 235, 240), -- icons of the windows, event log accent
		LineOpacity = 0.45,
		Background = 0.4,
		BackgroundWatermark = 0.4,
		BackgroundHotkeys = 0.4,
		BackgroundSpectators = 0.4,
		Items = { "Logo", "Time", "Username", "Preset" },
		Position = "Top-Center",
		Density = "Default",
		AdditionalColors = false,
		Avatar = false,
		HotkeysStyle = "Default",
		HotkeysRight = false,
		HotkeysDynamic = false,
		LogHideIcons = false,
		LogReduceMotion = false,
		LogLine = 1,
		LogBackground = 0.8,
	}

	local pills = {} -- styled by their own background setting / Line Opacity
	local pillOptions = {} -- [pill] = the HudOptions key of its background (BackgroundWatermark, ...)
	local tintIcons = {} -- tinted with Color

	-- Shadows behind the HUD windows (watermark, Hotkeys, Spectators), the same look as the indicator pills: layered rounded
	-- frames, 24 px wide, strong, in the menu's shadow colour (white glow on the light theme). The frames live in their own
	-- layer under every window; a window's frames are only touched when its position, size, fade, scale or the theme changed.
	local hudShadowLayer = create("Frame", { Name = "HudShadows", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = hud })
	local hudShadowAlphas = shadowAlphas(0.85)
	local HUD_SHADOW_STEP = 3
	local hudShadows = {}
	local function shadowFor(target, optionKey)
		local entry = { Target = target, Frames = {}, Key = "", Option = optionKey }
		for i = 1, #hudShadowAlphas do
			local f = create("Frame", {
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Visible = false,
				Parent = hudShadowLayer,
			}, { corner(12) })
			f:SetAttribute("NoTheme", true)
			entry.Frames[i] = f
		end
		table.insert(hudShadows, entry)
	end
	local function updateHudShadow(entry)
		local target = entry.Target
		local shown, scale = true, 1
		local g = target
		while g and g ~= hud do
			if g:IsA("GuiObject") and not g.Visible then
				shown = false
			end
			local us = g:FindFirstChildOfClass("UIScale")
			if us then
				scale = scale * us.Scale
			end
			g = g.Parent
		end
		local pos, size = target.AbsolutePosition, target.AbsoluteSize
		local seen = 0
		if shown then
			seen = math.clamp((1 - target.BackgroundTransparency) / math.max(self.HudOptions[entry.Option or "Background"] or self.HudOptions.Background, 0.05), 0, 1)
		end
		local mode = self.ThemeMode
		local shadowColor = self._shadowColor or SHADOW_COLORS[mode] or Color3.new(0, 0, 0)
		local key = string.format("%.1f|%.1f|%.1f|%.1f|%.3f|%.3f|%s|%s", pos.X, pos.Y, size.X, size.Y, seen, scale, mode, colorKey(shadowColor))
		if key == entry.Key then
			return
		end
		entry.Key = key
		local color = self._shadowColor or SHADOW_COLORS[mode] or Color3.new(0, 0, 0)
		local targetCorner = target:FindFirstChildOfClass("UICorner")
		local radius = (if targetCorner then targetCorner.CornerRadius.Offset else 12) * scale
		local layerPos = hudShadowLayer.AbsolutePosition
		for i, f in ipairs(entry.Frames) do
			local o = i * HUD_SHADOW_STEP * scale
			f.Position = UDim2.fromOffset(pos.X - layerPos.X - o, pos.Y - layerPos.Y - o)
			f.Size = UDim2.fromOffset(size.X + o * 2, size.Y + o * 2)
			f.BackgroundTransparency = 1 - hudShadowAlphas[i] * seen
			f.BackgroundColor3 = color
			f.Visible = seen > 0.001
			f:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, radius + o)
		end
	end
	local hudShadowConn
	hudShadowConn = RunService.RenderStepped:Connect(function()
		if not hud.Parent then
			hudShadowConn:Disconnect()
			return
		end
		for _, entry in ipairs(hudShadows) do
			updateHudShadow(entry)
		end
	end)

	local function scaled(widget)
		table.insert(self._hudScales, create("UIScale", { Parent = widget }))
	end

	local function pill(parent, isButton, optionKey)
		local p = create(if isButton then "TextButton" else "Frame", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 36),
			BackgroundColor3 = Theme.Pill,
			BackgroundTransparency = Theme.WindowTransparency,
			Parent = parent,
		}, { corner(18), litStroke(), padding(0, 16, 0, 14), list(16, true) })
		if isButton then
			p.Text = ""
			p.AutoButtonColor = false
		end
		table.insert(pills, p)
		pillOptions[p] = optionKey
		return p
	end

	-- icon + text; returns label, frame, icon
	local function group(parent, iconName, text, bold, order)
		local g = create("Frame", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = parent,
		}, { list(7, true) })
		local icon = Icons[iconName](g, self.HudOptions.Color, { LayoutOrder = 1 })
		local label = textLabel({
			Text = text,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			FontFace = if bold then Theme.FontBold else Theme.Font,
			TextSize = 14,
			TextColor3 = if bold then Theme.Text else Theme.TextDim,
			LayoutOrder = 2,
			Parent = g,
		})
		return label, g, icon
	end

	------------------------------------------------------------------
	-- Metrics for the watermark
	------------------------------------------------------------------
	local fps, frames, elapsed = 0, 0, 0
	RunService.Heartbeat:Connect(function(dt)
		frames += 1
		elapsed += dt
		if elapsed >= 0.5 then
			fps = math.floor(frames / elapsed + 0.5)
			frames, elapsed = 0, 0
		end
	end)
	local pings = {} -- last 20 samples, ms
	local function samplePing()
		local p = readNumber(function()
			return player:GetNetworkPing()
		end)
		if p then
			table.insert(pings, p * 1000)
			if #pings > 20 then
				table.remove(pings, 1)
			end
		end
	end
	local function jitter()
		if #pings < 2 then
			return nil
		end
		local sum = 0
		for i = 2, #pings do
			sum += math.abs(pings[i] - pings[i - 1])
		end
		return sum / (#pings - 1)
	end

	-- text, status ("Good" | "Warn" | "Bad" | nil)
	local function itemValue(name)
		if name == "Framerate" then
			return fps .. " FPS", grade(fps, 60, 30, true)
		elseif name == "Delay" then
			local p = pings[#pings]
			if p then
				return math.floor(p + 0.5) .. " ms", grade(p, 80, 150)
			end
		elseif name == "Network Jitter" then
			local j = jitter()
			if j then
				return string.format("%.1f ms", j), grade(j, 10, 30)
			end
		elseif name == "Connection Status" then
			local p = pings[#pings]
			if p then
				return (if p <= 150 then "Stable" else "Unstable"), grade(p, 80, 150)
			end
			return "Connected", "Good"
		elseif name == "Memory Load" then
			local mb = readNumber(function()
				return Stats:GetTotalMemoryUsageMb()
			end)
			if mb then
				return math.floor(mb + 0.5) .. " MB"
			end
		elseif name == "Network Traffic" then
			local kb = readNumber(function()
				return Stats.DataReceiveKbps + Stats.DataSendKbps
			end)
			if kb then
				return string.format("%.1f KB/s", kb)
			end
		elseif name == "Speed" then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				return math.floor(root.AssemblyLinearVelocity.Magnitude + 0.5) .. " st/s"
			end
		elseif name == "KD Ratio" then
			local stats = player:FindFirstChild("leaderstats")
			local kills = stats and stats:FindFirstChild("Kills")
			local deaths = stats and stats:FindFirstChild("Deaths")
			local k = kills and tonumber(kills.Value)
			local d = deaths and tonumber(deaths.Value)
			if k and d then
				return string.format("%.2f", k / math.max(d, 1))
			end
		elseif name == "Server Address" then
			return if game.JobId ~= "" then string.sub(game.JobId, 1, 8) else "Studio"
		elseif name == "Preset" then
			return self.Profile or ""
		elseif name == "Username" then
			return player.Name
		elseif name == "Time" then
			return os.date("%H:%M")
		end
		return "n/a"
	end

	------------------------------------------------------------------
	-- Watermark
	------------------------------------------------------------------
	local watermark = pill(hud, false, "BackgroundWatermark")
	scaled(watermark)
	self.Windows.Watermark = watermark
	shadowFor(watermark, "BackgroundWatermark")
	local wmLayout = watermark:FindFirstChildOfClass("UIListLayout")
	local wmPadding = watermark:FindFirstChildOfClass("UIPadding")
	local wmCorner = watermark:FindFirstChildOfClass("UICorner")
	local wmEntries = {}
	local builtSignature = nil
	local avatarImage = ""

	local function rebuildWatermark()
		local o = self.HudOptions
		local signature = table.concat(o.Items, "|") .. (if o.Avatar then "+avatar" .. avatarImage else "")
		if signature == builtSignature then
			return
		end
		builtSignature = signature
		for _, c in ipairs(watermark:GetChildren()) do
			if c:GetAttribute("WmItem") then
				c:Destroy()
			end
		end
		wmEntries = {}
		if o.Avatar then
			local image = create("ImageLabel", {
				Size = UDim2.fromOffset(22, 22),
				BackgroundColor3 = Theme.Element,
				Image = avatarImage,
				LayoutOrder = 0,
				Parent = watermark,
			}, { corner(11) })
			image:SetAttribute("WmItem", true)
		end
		for i, def in ipairs(WATERMARK_ITEMS) do
			if table.find(o.Items, def[1]) then
				if def[1] == "Logo" then
					local logo = textLabel({
						Text = config.Logo or "UI",
						AutomaticSize = Enum.AutomaticSize.X,
						Size = UDim2.fromScale(0, 1),
						FontFace = Theme.FontHeavy,
						TextSize = 17,
						TextColor3 = Theme.Text,
						LayoutOrder = i,
						Parent = watermark,
					})
					logo:SetAttribute("WmItem", true)
				else
					local label, frame, icon = group(watermark, def[2], "", false, i)
					frame:SetAttribute("WmItem", true)
					table.insert(wmEntries, { Name = def[1], Label = label, Icon = icon })
				end
			end
		end
	end

	local function updateWatermark()
		local o = self.HudOptions
		for _, e in ipairs(wmEntries) do
			local text, status = itemValue(e.Name)
			e.Label.Text = text
			e.Label.TextColor3 = if o.AdditionalColors and status then STATUS_COLORS[status] else Theme.TextDim
		end
	end

	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
		end)
		if ok then
			avatarImage = image
			if self._applyHud then
				self._applyHud()
			end
		end
	end)

	------------------------------------------------------------------
	-- Draggable widgets: pill header + animated list (Hotkeys, Spectators)
	------------------------------------------------------------------
	local function widget(title, iconName)
		local w = create("Frame", {
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			Parent = hud,
		}, { list(6) })
		scaled(w)
		local layout = w:FindFirstChildOfClass("UIListLayout")
		local head = pill(w, true, "Background" .. title)
		head.LayoutOrder = 0
		local _, _, headIcon = group(head, iconName, title, true, 1)
		table.insert(tintIcons, headIcon)

		local box = create("Frame", {
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(140, 0),
			BackgroundColor3 = Theme.Pill,
			BackgroundTransparency = 1,
			Visible = false,
			LayoutOrder = 1,
			Parent = w,
		}, { corner(12), litStroke(), list(2), padding(8, 14, 8, 14) })
		local boxStroke = box:FindFirstChildOfClass("UIStroke")
		shadowFor(head, "Background" .. title)
		shadowFor(box, "Background" .. title)
		local ctl = {
			Widget = w,
			Title = title,
			Head = head,
			Box = box,
			BoxStroke = boxStroke,
			Layout = layout,
			BoxLayout = box:FindFirstChildOfClass("UIListLayout"),
			Moved = false,
			Shown = false,
			HasRows = false,
		}

		-- Rows keyed by their left text: a new row opens from 0 to 20 px and fades in, a removed one
		-- closes and fades out; the auto-sized box follows and fades with the first / last row.
		local ANIM = 0.22
		local rows = {}
		local order = 0

		local function showBox(v)
			if v == ctl.Shown then
				return
			end
			ctl.Shown = v
			local o = self.HudOptions
			if v then
				box.Visible = true
				box.BackgroundTransparency = 1
				boxStroke.Transparency = 1
				tween(box, { BackgroundTransparency = 1 - o["Background" .. title] }, ANIM)
				tween(boxStroke, { Transparency = 1 - o.LineOpacity }, ANIM)
			else
				tween(box, { BackgroundTransparency = 1 }, ANIM)
				tween(boxStroke, { Transparency = 1 }, ANIM)
				task.delay(ANIM, function()
					if not ctl.Shown then
						box.Visible = false
					end
				end)
			end
		end

		local function fadeRow(r, visible)
			local t = if visible then 0 else 1
			tween(r.Frame, { Size = UDim2.fromOffset(0, if visible then 20 else 0) }, ANIM)
			tween(r.Left, { TextTransparency = t }, ANIM)
			if r.Right then
				tween(r.Right, { TextTransparency = t }, ANIM)
			end
		end

		function ctl.SetRows(entries)
			local seen = {}
			for _, e in ipairs(entries) do
				local key = e[1]
				seen[key] = true
				local r = rows[key]
				if r and r.Removing then
					r.Removing = false
					fadeRow(r, true)
				elseif not r then
					order += 1
					local frame = create("Frame", {
						AutomaticSize = Enum.AutomaticSize.X,
						Size = UDim2.fromOffset(0, 0),
						BackgroundTransparency = 1,
						ClipsDescendants = true,
						LayoutOrder = order,
						Parent = box,
					}, { list(16, true) })
					r = {
						Frame = frame,
						Left = textLabel({
							Text = key,
							AutomaticSize = Enum.AutomaticSize.X,
							Size = UDim2.fromOffset(0, 20),
							TextSize = 13,
							TextTransparency = 1,
							LayoutOrder = 1,
							Parent = frame,
						}),
					}
					if e[2] then
						r.Right = textLabel({
							Text = e[2],
							AutomaticSize = Enum.AutomaticSize.X,
							Size = UDim2.fromOffset(0, 20),
							TextSize = 13,
							TextColor3 = Theme.SubText,
							TextTransparency = 1,
							LayoutOrder = 2,
							Parent = frame,
						})
					end
					rows[key] = r
					fadeRow(r, true)
				end
				if r.Right and e[2] then
					r.Right.Text = e[2]
				end
			end

			for key, r in pairs(rows) do
				if not seen[key] and not r.Removing then
					r.Removing = true
					fadeRow(r, false)
					task.delay(ANIM, function()
						if r.Removing and rows[key] == r then
							r.Frame:Destroy()
							rows[key] = nil
							if next(rows) == nil then
								showBox(false)
								ctl.HasRows = false
								if self._applyHud then
									self._applyHud()
								end
							end
						end
					end)
				end
			end

			if next(seen) ~= nil then
				ctl.HasRows = true
				showBox(true)
				if self._applyHud then
					self._applyHud()
				end
			end
		end

		-- after a layout change, move the widget so the pill stays where it was on screen
		function ctl.KeepHead(change)
			local before = head.AbsolutePosition
			change()
			task.spawn(function()
				task.wait()
				task.wait()
				local d = before - head.AbsolutePosition
				if d.Magnitude > 0.5 then
					w.Position = w.Position + UDim2.fromOffset(d.X, d.Y)
				end
			end)
		end

		-- drag by the pill; once moved, the widget keeps its place
		local dragging, startInput, startPos = false, nil, nil
		head.InputBegan:Connect(function(input)
			if isClick(input) then
				dragging = true
				ctl.Moved = true
				startInput = input.Position
				startPos = w.Position
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
					end
				end)
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if dragging and isMove(input) then
				local d = input.Position - startInput
				local screen = self.Gui.AbsoluteSize
				local size = w.AbsoluteSize
				local x = startPos.X.Offset + d.X
				local y = startPos.Y.Offset + d.Y
				-- keep the widget on screen (offsets are relative to its scale position and anchor)
				local baseX = startPos.X.Scale * screen.X - w.AnchorPoint.X * size.X
				local baseY = startPos.Y.Scale * screen.Y - w.AnchorPoint.Y * size.Y
				x = math.clamp(x, -baseX, math.max(-baseX, screen.X - size.X - baseX))
				y = math.clamp(y, -baseY, math.max(-baseY, screen.Y - size.Y - baseY))
				w.Position = UDim2.new(startPos.X.Scale, x, startPos.Y.Scale, y)
			end
		end)
		return ctl
	end

	local hotkeys = widget("Hotkeys", "list")
	self.Windows.Hotkeys = hotkeys.Widget
	self._setHotkeyRows = hotkeys.SetRows

	local spectators = widget("Spectators", "eye")
	self.Windows.Spectators = spectators.Widget
	self._hudWidgets = { Hotkeys = hotkeys, Spectators = spectators }
	task.spawn(function()
		while self.Gui.Parent do
			local entries = {}
			for _, name in ipairs(self:_spectators()) do
				table.insert(entries, { name })
			end
			spectators.SetRows(entries)
			task.wait(1)
		end
	end)

	-- Until dragged, Hotkeys sits left of the top-centre spot and Spectators right of it
	local function placeBesideWatermark()
		local half = watermark.AbsoluteSize.X / 2
		if not hotkeys.Moved then
			hotkeys.Widget.Position = UDim2.new(0.5, -half - 10 - hotkeys.Head.AbsoluteSize.X, 0, 12)
		end
		if not spectators.Moved then
			spectators.Widget.Position = UDim2.new(0.5, half + 10, 0, 12)
		end
	end
	watermark:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeBesideWatermark)
	self._placeHud = placeBesideWatermark
	hotkeys.Head:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeBesideWatermark)

	------------------------------------------------------------------
	-- Event logs (top right, under a top-right watermark)
	------------------------------------------------------------------
	local logs = create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 60),
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Parent = hud,
	}, {
		create("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
		}),
	})
	scaled(logs)
	self.Windows["Event Logs"] = logs
	self._logs = logs
	self._logOrder = 0

	------------------------------------------------------------------
	-- Apply options (called by SetHudOption / SetWindow)
	------------------------------------------------------------------
	local function applyWatermark()
		local o = self.HudOptions
		rebuildWatermark()
		local d = WATERMARK_DENSITY[o.Density] or WATERMARK_DENSITY.Default
		watermark.Size = UDim2.fromOffset(0, d[1])
		wmCorner.CornerRadius = UDim.new(0, d[1] / 2)
		wmPadding.PaddingLeft = UDim.new(0, d[2])
		wmPadding.PaddingRight = UDim.new(0, d[2])
		wmLayout.Padding = UDim.new(0, d[3])
		local pos = WATERMARK_POSITIONS[o.Position] or WATERMARK_POSITIONS["Top-Center"]
		watermark.AnchorPoint = pos[1]
		watermark.Position = pos[2]
		updateWatermark()
	end

	local function applyHotkeys()
		local o = self.HudOptions
		local inverted = o.HotkeysStyle == "Inverted"
		local anchor = Vector2.new(if o.HotkeysRight then 1 else 0, if inverted then 1 else 0)
		local align = if o.HotkeysRight then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left
		local boxOrder = if inverted then -1 else 1
		local w = hotkeys.Widget
		if w.AnchorPoint ~= anchor or hotkeys.Box.LayoutOrder ~= boxOrder or hotkeys.Layout.HorizontalAlignment ~= align then
			-- inverted: the list grows upwards; right-aligned: it grows to the left; the pill stays put
			hotkeys.KeepHead(function()
				w.AnchorPoint = anchor
				hotkeys.Box.LayoutOrder = boxOrder
				hotkeys.Layout.HorizontalAlignment = align
				hotkeys.BoxLayout.HorizontalAlignment = align
			end)
			hotkeys.Moved = true
		end
	end

	local function applyStyle()
		local o = self.HudOptions
		for _, p in ipairs(pills) do
			p.BackgroundTransparency = 1 - (o[pillOptions[p] or "Background"] or o.Background)
			local s = p:FindFirstChildOfClass("UIStroke")
			if s then
				s.Transparency = 1 - o.LineOpacity
			end
		end
		for _, c in ipairs({ hotkeys, spectators }) do
			if c.Shown then
				c.Box.BackgroundTransparency = 1 - o["Background" .. c.Title]
				c.BoxStroke.Transparency = 1 - o.LineOpacity
			end
		end
		for _, icon in ipairs(tintIcons) do
			setIconColor(icon, o.Color)
		end
		for _, e in ipairs(wmEntries) do
			setIconColor(e.Icon, o.Color)
		end
	end

	local function applyVisibility()
		local on, o = self._windowOn, self.HudOptions
		watermark.Visible = on.Watermark
		-- Dynamic Header: the Hotkeys window shows up only while a hotkey is active
		hotkeys.Widget.Visible = on.Hotkeys and (not o.HotkeysDynamic or hotkeys.HasRows)
		spectators.Widget.Visible = on.Spectators
		logs.Visible = on["Event Logs"]
	end

	self._applyHud = function()
		applyWatermark()
		applyHotkeys()
		applyStyle()
		applyVisibility()
	end
	self._applyHud()
	placeBesideWatermark()

	task.spawn(function()
		while self.Gui.Parent do
			samplePing()
			updateWatermark()
			task.wait(0.5)
		end
	end)
end

-- names and icons of the watermark items, for the Items list in the menu
function UI:GetWatermarkItems()
	local names, icons = {}, {}
	for _, def in ipairs(WATERMARK_ITEMS) do
		table.insert(names, def[1])
		icons[def[1]] = def[2]
	end
	return names, icons
end

function UI:_spectators()
	local getter = self.Config.GetSpectators
	if not getter then
		return {}
	end
	local ok, names = pcall(getter)
	return if ok and type(names) == "table" then names else {}
end

function UI:_hotkeyEntries()
	local entries = {}
	for name, key in pairs(self._hotkeys) do
		table.insert(entries, { name, "[" .. key .. "]" })
	end
	table.sort(entries, function(x, y)
		return x[1] < y[1]
	end)
	return entries
end

function UI:SetHotkey(name, keyText)
	self._hotkeys[name] = keyText
	if self._setHotkeyRows then
		self._setHotkeyRows(self:_hotkeyEntries())
	end
end

-- "Watermark" | "Hotkeys" | "Spectators" | "Event Logs"
function UI:SetWindow(name, visible)
	self._windowOn[name] = visible
	if self._applyHud then
		self._applyHud()
	end
end

-- Options of the screen windows (keys of self.HudOptions), e.g. SetHudOption("Position", "Top-Right")
function UI:SetHudOption(key, value)
	self.HudOptions[key] = value
	if self._applyHud then
		self._applyHud()
	end
end

-- Scale of the watermark, Hotkeys, Spectators and Event Logs (animated)
function UI:SetHudScale(scale)
	scale = math.clamp(scale, 0.5, 2)
	for _, s in ipairs(self._hudScales) do
		TweenService:Create(s, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = scale,
		}):Play()
	end
end

-- Line in the Event Logs window: accent bar, icon, text; slides in unless Reduce Motion is on
function UI:Log(text)
	local o = self.HudOptions
	local logs = self._logs
	self._logOrder += 1
	local motion = not o.LogReduceMotion

	local row = create("Frame", {
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		LayoutOrder = self._logOrder,
		Parent = logs,
	})
	local inner = create("Frame", {
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.fromOffset(if motion then 24 else 0, 0),
		Size = UDim2.fromOffset(0, 26),
		BackgroundColor3 = Theme.Pill,
		BackgroundTransparency = if motion then 1 else 1 - o.LogBackground,
		Parent = row,
	}, { corner(6), padding(0, 10, 0, 8), list(8, true) })
	local bar = create("Frame", {
		Size = UDim2.fromOffset(2, 14),
		BackgroundColor3 = o.Color,
		BackgroundTransparency = if motion then 1 else 1 - o.LogLine,
		BorderSizePixel = 0,
		LayoutOrder = 0,
		Parent = inner,
	}, { corner(1) })
	if not o.LogHideIcons then
		Icons.ring(inner, o.Color, { LayoutOrder = 1 })
	end
	local label = textLabel({
		Text = text,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		TextSize = 13,
		TextColor3 = Theme.TextDim,
		TextTransparency = if motion then 1 else 0,
		LayoutOrder = 2,
		Parent = inner,
	})
	if motion then
		tween(inner, { Position = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 - o.LogBackground }, 0.25)
		tween(bar, { BackgroundTransparency = 1 - o.LogLine }, 0.25)
		tween(label, { TextTransparency = 0 }, 0.25)
	end

	local rows = {}
	for _, c in ipairs(logs:GetChildren()) do
		if c:IsA("Frame") then
			table.insert(rows, c)
		end
	end
	if #rows > 8 then
		table.sort(rows, function(x, y)
			return x.LayoutOrder < y.LayoutOrder
		end)
		rows[1]:Destroy()
	end

	task.delay(6, function()
		if not row.Parent then
			return
		end
		if not motion then
			row:Destroy()
			return
		end
		tween(inner, { Position = UDim2.fromOffset(24, 0), BackgroundTransparency = 1 }, 0.3)
		tween(bar, { BackgroundTransparency = 1 }, 0.3)
		tween(label, { TextTransparency = 1 }, 0.3)
		for _, d in ipairs(inner:GetDescendants()) do
			if d:IsA("Frame") and d ~= bar and d.BackgroundTransparency < 1 then
				tween(d, { BackgroundTransparency = 1 }, 0.3)
			end
		end
		task.wait(0.32)
		row:Destroy()
	end)
end

-- Toast "NL  Neverlose / status   n of N" while the gui's images preload
function UI:_runLoader()
	local config = self.Config
	local toast = create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 340, 0, 10),
		Size = UDim2.fromOffset(300, 52),
		BackgroundColor3 = Theme.Pill,
		BackgroundTransparency = Theme.WindowTransparency,
		ZIndex = 20,
		Parent = self.Gui,
	}, { corner(14), litStroke() })
	create("Frame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = Theme.Logo,
		ZIndex = 20,
		Parent = toast,
	}, {
		corner(8),
		textLabel({
			Text = config.Logo or "UI",
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			FontFace = Theme.FontHeavy,
			TextSize = 18,
			TextColor3 = Theme.Text,
			ZIndex = 20,
		}),
	})
	textLabel({
		Text = config.Title or "Menu",
		Position = UDim2.fromOffset(54, 9),
		Size = UDim2.new(1, -130, 0, 18),
		FontFace = Theme.FontBold,
		TextSize = 15,
		TextColor3 = Theme.Text,
		ZIndex = 20,
		Parent = toast,
	})
	local status = textLabel({
		Text = "Loading icons...",
		Position = UDim2.fromOffset(54, 27),
		Size = UDim2.new(1, -130, 0, 16),
		TextSize = 13,
		TextColor3 = Theme.SubText,
		ZIndex = 20,
		Parent = toast,
	})
	local counter = textLabel({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(70, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 14,
		TextColor3 = Theme.TextDim,
		ZIndex = 20,
		Parent = toast,
	})
	tween(toast, { Position = UDim2.new(1, -14, 0, 10) }, 0.3)

	local assets, seen = {}, {}
	for _, d in ipairs(self.Gui:GetDescendants()) do
		if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image ~= "" and not seen[d.Image] then
			seen[d.Image] = true
			table.insert(assets, d.Image)
		end
	end
	local total, done = #assets, 0
	counter.Text = string.format("%d of %d", done, total)
	pcall(function()
		ContentProvider:PreloadAsync(assets, function()
			done += 1
			counter.Text = string.format("%d of %d", math.min(done, total), total)
		end)
	end)
	status.Text = "Initialization complete"
	counter.Text = string.format("%d of %d", total, total)
	task.wait(1.2)
	tween(toast, { Position = UDim2.new(1, 340, 0, 10) }, 0.3)
	task.delay(0.35, function()
		toast:Destroy()
	end)
end

------------------------------------------------------------------
-- Presets: every saved row registers under "Tab/Section/Row"; a preset is a snapshot of all values
------------------------------------------------------------------
-- row: the row frame (enables the right-click menu); meta.Type: "toggle" | "slider" | "dropdown" (can get hotkeys)
-- every switch starts off (a fresh start, and the defaults a new config is made from); rows built after this are switched off as they register
function UI:_allOff()
	self._forceOff = true
	for _, entry in pairs(self._elements) do
		if entry.Kind == "toggle" then
			if self:_valueOf(entry) == true then
				self:_setValue(entry, false)
			end
			entry.Default = false
		end
	end
end

function UI:_register(key, kind, api, row, meta, name)
	local k, n = key, 1
	while self._elements[k] do
		n += 1
		k = key .. "#" .. n
	end
	local entry = { Key = k, Kind = kind, Api = api, Row = row, Meta = meta, Name = name or k }
	self._elements[k] = entry
	entry.Default = self:_valueOf(entry)
	if self._forceOff and kind == "toggle" then
		if entry.Default == true then
			self:_setValue(entry, false)
		end
		entry.Default = false
	end
	if row then
		self._rows[row] = k
	end
	if self._restoredValues and self._restoredValues[k] ~= nil then
		self:_setValue(entry, self._restoredValues[k])
	end
end

function UI:_valueOf(entry)
	local api = entry.Api
	if entry.Kind == "color" then
		local c, a = api:Get()
		return { c.R, c.G, c.B, a }
	elseif entry.Kind == "keybind" then
		local k = api:Get()
		return if k then k.Name else false
	elseif entry.Kind == "multi" then
		return table.clone(api:Get())
	end
	return api:Get()
end

function UI:_setValue(entry, value)
	pcall(function()
		if entry.Kind == "color" then
			entry.Api:Set(Color3.new(value[1], value[2], value[3]), value[4])
		elseif entry.Kind == "keybind" then
			entry.Api:Set(if value then Enum.KeyCode[value] else nil)
		elseif entry.Kind == "multi" then
			entry.Api:Set(table.clone(value))
		else
			entry.Api:Set(value)
		end
	end)
end

-- State that is not a menu row: where the menu and the draggable Hotkeys / Spectators windows are, and dark / light mode.
-- Event Logs and the watermark have fixed places chosen by their options, which are menu rows and saved as such.
function UI:_uiState()
	local state = { Theme = self.ThemeMode }
	local p = self.Holder.Position
	state.Menu = { p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset }
	for name, ctl in pairs(self._hudWidgets or {}) do
		local wp = ctl.Widget.Position
		state[name] = { wp.X.Scale, wp.X.Offset, wp.Y.Scale, wp.Y.Offset, ctl.Moved }
	end
	return state
end

function UI:_applyUiState(state)
	local function finiteNumber(v)
		return type(v) == "number" and v == v and v > -1e6 and v < 1e6
	end
	local screen = self.Gui.AbsoluteSize
	local function valid(t, n)
		if type(t) ~= "table" then
			return false
		end
		for i = 1, n do
			if not finiteNumber(t[i]) then
				return false
			end
		end
		return true
	end
	-- an absolute position clamped onto the screen, kept as scale + offset
	local function onScreen(sx, ox, sy, oy)
		local x = math.clamp(sx * screen.X + ox, 0, screen.X)
		local y = math.clamp(sy * screen.Y + oy, 0, screen.Y)
		return UDim2.new(sx, x - sx * screen.X, sy, y - sy * screen.Y)
	end
	if state.Theme == "Dark" or state.Theme == "Light" then
		self:SetThemeMode(state.Theme)
	end
	if valid(state.Menu, 4) then
		local m = state.Menu
		self.Holder.Position = onScreen(m[1], m[2], m[3], m[4])
	end
	for name, ctl in pairs(self._hudWidgets or {}) do
		local s = state[name]
		if valid(s, 4) and s[5] == true then
			ctl.Widget.Position = onScreen(s[1], s[2], s[3], s[4])
			ctl.Moved = true
		else
			ctl.Moved = false -- never dragged: it follows the watermark again
		end
	end
	if self._placeHud then
		self._placeHud()
	end
end

-- values first (their callbacks may move the Hotkeys window), then window positions; positions are applied again a
-- moment later because the Hotkeys window re-anchors itself over two frames when Right-Aligned / Style change
function UI:_apply(data)
	-- the HUD windows are more transparent by default now (like the indicator pills): the old defaults of the Background and
	-- Line Opacity sliders move to the new ones, a value the user changed is kept
	local styleDefaults = { ["Visuals/World/Miscellaneous/Windows/Background"] = { 94, 40 }, ["Visuals/World/Miscellaneous/Windows/Line Opacity"] = { 100, 45 } }
	local oldBackground = data["Visuals/World/Miscellaneous/Windows/Background"]
	for key, pair in pairs(styleDefaults) do
		if data[key] == pair[1] then
			data[key] = pair[2]
		end
	end
	-- the single Background slider became one slider per window: a config that still has it passes its value on
	if oldBackground ~= nil then
		for _, name in ipairs({ "Watermark", "Hotkeys", "Spectators", "Indicators" }) do
			local key = "Visuals/World/Miscellaneous/Windows/" .. name .. " Background"
			if data[key] == nil then
				data[key] = if oldBackground == 94 then 40 else oldBackground -- 94 was the old default
			end
		end
	end
	self:_applyValues(data)
	local ui = data["@ui"]
	if type(ui) == "table" then
		pcall(self._applyUiState, self, ui)
		task.delay(0.3, function()
			if not self._unloaded then
				pcall(self._applyUiState, self, ui)
			end
		end)
	end
end
function UI:_snapshot()
	local data = {}
	for key, entry in pairs(self._elements) do
		data[key] = self:_valueOf(entry)
	end
	local binds = {}
	for _, b in ipairs(self._binds) do
		table.insert(binds, { b.ElementKey, b.Key or false, b.Mode, b.Value, b.Visible })
	end
	data["@binds"] = binds
	data["@ui"] = self:_uiState()
	return data
end

function UI:_applyValues(data)
	self._restoredValues = data -- rows registered later (the profile popup is built last) get their saved value in _register
	if data["@binds"] then
		self:_clearBinds()
	end
	for key, value in pairs(data) do
		local entry = self._elements[key]
		if entry then
			self:_setValue(entry, value)
		end
	end
	for _, b in ipairs(data["@binds"] or {}) do
		if self._elements[b[1]] then
			table.insert(self._binds, {
				ElementKey = b[1],
				Key = b[2] or nil,
				Mode = b[3] or "Toggle",
				Value = b[4],
				Visible = b[5] ~= false,
				Active = false,
			})
		end
	end
end

------------------------------------------------------------------
-- Hotkeys: right-click a row -> context menu; each bind sets the row's value while active
------------------------------------------------------------------
local BIND_MODES = { "Toggle", "Hold" }

local function contains(gui, p)
	local a, s = gui.AbsolutePosition, gui.AbsoluteSize
	return p.X >= a.X and p.Y >= a.Y and p.X <= a.X + s.X and p.Y <= a.Y + s.Y
end

local function isShown(gui)
	local g = gui
	while g and not g:IsA("ScreenGui") do
		if g:IsA("GuiObject") and not g.Visible then
			return false
		end
		g = g.Parent
	end
	return g ~= nil and g.Enabled
end

local function keyMatches(input, key)
	return key ~= nil and (input.KeyCode.Name == key or input.UserInputType.Name == key)
end

function UI:_updateBindHud(b)
	local entry = self._elements[b.ElementKey]
	if entry then
		self:SetHotkey(entry.Name, if b.Active and b.Visible then b.Mode else nil)
	end
end

function UI:_activateBind(b)
	local entry = self._elements[b.ElementKey]
	if not entry or b.Active then
		return
	end
	b.Prev = self:_valueOf(entry)
	b.Active = true
	self:_setValue(entry, b.Value)
	self:_updateBindHud(b)
end

function UI:_deactivateBind(b, restore)
	local entry = self._elements[b.ElementKey]
	if not b.Active then
		return
	end
	b.Active = false
	if entry and restore ~= false and b.Prev ~= nil then
		self:_setValue(entry, b.Prev)
	end
	b.Prev = nil
	self:_updateBindHud(b)
end

-- dropped without restoring values (used before a preset overwrites them)
function UI:_clearBinds()
	for _, b in ipairs(self._binds) do
		self:_deactivateBind(b, false)
	end
	self._binds = {}
end

function UI:_bindInput(input, began)
	-- while the menu is open, Mouse 1 / Mouse 2 are menu clicks: they must not fire binds (releases still pass)
	local t = input.UserInputType
	if began and self._visible and (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseButton2) then
		return
	end
	for _, b in ipairs(self._binds) do
		if keyMatches(input, b.Key) then
			if b.Mode == "Hold" then
				if began then
					self:_activateBind(b)
				else
					self:_deactivateBind(b)
				end
			elseif began then
				if b.Active then
					self:_deactivateBind(b)
				else
					self:_activateBind(b)
				end
			end
		end
	end
end

function UI:_onRightClick(p)
	for _, e in ipairs(self._stack) do
		if contains(e.popup, p) then
			-- inside an open popup: only rows of that popup count
			for row, key in pairs(self._rows) do
				if row:IsDescendantOf(e.popup) and contains(row, p) and isShown(row) then
					self:_openContext(key, p)
					return
				end
			end
			return
		end
	end
	for row, key in pairs(self._rows) do
		if row.Parent and not row:IsDescendantOf(self.Overlay) and contains(row, p) and isShown(row) then
			local clip = row:FindFirstAncestorWhichIsA("ScrollingFrame")
			if not clip or contains(clip, p) then
				self:_openContext(key, p)
				return
			end
		end
	end
end

-- Popup at a screen point (context menus)
function UI:ShowPopupAt(popup, p)
	self:ClosePopup()
	popup.Parent = self.Overlay
	popup.Visible = true
	table.insert(self._stack, { popup = popup, keep = false })
	popup.ZIndex = 2
	self.Overlay.Visible = true
	local scale = self.UserScale
	local screen = self.Gui.AbsoluteSize
	local x = math.clamp(p.X + 2, 8, math.max(8, screen.X - popup.Size.X.Offset * scale - 8))
	popup.Position = UDim2.fromOffset(x / scale, p.Y / scale)
	task.spawn(function()
		task.wait()
		if popup.Parent then
			local h = popup.AbsoluteSize.Y
			popup.Position = UDim2.fromOffset(x / scale, math.clamp(p.Y, 8, math.max(8, screen.Y - 8 - h)) / scale)
		end
	end)
end

local function menuItem(parent, order, iconName, text, color, withChevron, disabled)
	local c = if disabled then Theme.SubText else color
	local b = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Theme.Hover,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	}, { corner(6) })
	Icons[iconName](b, if disabled then Theme.SubText elseif color == Theme.TextDim then Theme.TabText else color, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
	})
	textLabel({
		Text = text,
		Position = UDim2.fromOffset(36, 0),
		Size = UDim2.new(1, -56, 1, 0),
		TextSize = 14,
		TextColor3 = c,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = b,
	})
	if withChevron then
		chevron(b, UDim2.new(1, -8, 0.5, 0), -90, c)
	end
	if not disabled then
		b.MouseEnter:Connect(function()
			tween(b, { BackgroundTransparency = 0.3 })
		end)
		b.MouseLeave:Connect(function()
			tween(b, { BackgroundTransparency = 1 })
		end)
	end
	return b
end

local function menuDivider(parent, order)
	create("Frame", {
		Size = UDim2.new(1, 0, 0, 9),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	}, {
		create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -12, 0, 1),
			BackgroundColor3 = Theme.Divider,
			BorderSizePixel = 0,
		}),
	})
end

local MOUSE_LABELS = { MouseButton1 = "Mouse 1", MouseButton2 = "Mouse 2", MouseButton3 = "Mouse 3" }
local function keyLabel(key)
	return if key then MOUSE_LABELS[key] or key else "None"
end

local function bindLabel(b)
	return string.format('%s "%s"', b.Mode, keyLabel(b.Key))
end

function UI:_newBind(elementKey)
	local entry = self._elements[elementKey]
	local value = if entry.Meta.Type == "toggle" then true else self:_valueOf(entry)
	local b = { ElementKey = elementKey, Key = nil, Mode = "Toggle", Value = value, Visible = true, Active = false }
	table.insert(self._binds, b)
	return b
end

function UI:_openContext(key, p, openBind)
	local entry = self._elements[key]
	local bindable = entry.Meta ~= nil and entry.Meta.Type ~= nil
	local popup = popupFrame(210, Theme.PopupBg)
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	local buttons = {}
	for _, b in ipairs(self._binds) do
		if b.ElementKey == key then
			local item
			item = menuItem(popup, nextOrder(), "sparkle", bindLabel(b), Theme.TextDim, true)
			item.MouseButton1Click:Connect(function()
				self:_openBindMenu(item, b)
			end)
			buttons[b] = item
		end
	end

	local all = menuItem(popup, nextOrder(), "list", "All Hotkeys", Theme.TextDim, #self._binds > 0, #self._binds == 0)
	if #self._binds > 0 then
		all.MouseButton1Click:Connect(function()
			self:_openAllHotkeys(all)
		end)
	end

	if bindable then
		local new = menuItem(popup, nextOrder(), "plusCircle", "New Hotkey", Theme.TextDim, false)
		new.MouseButton1Click:Connect(function()
			local b = self:_newBind(key)
			self:_openContext(key, p, b)
		end)
	end

	menuDivider(popup, nextOrder())
	local reset = menuItem(popup, nextOrder(), "undo", "Reset", Color3.fromRGB(240, 90, 100), false)
	reset.MouseButton1Click:Connect(function()
		self:ClosePopup()
		self:_setValue(entry, entry.Default)
	end)

	self:ShowPopupAt(popup, p)
	if openBind and buttons[openBind] then
		-- wait until the context menu has its final position, then open the new bind beside it
		task.delay(0.05, function()
			if buttons[openBind].Parent then
				self:_openBindMenu(buttons[openBind], openBind, true)
			end
		end)
	end
end

function UI:_openAllHotkeys(anchor)
	local popup = popupFrame(230, Theme.PopupBg)
	for i, b in ipairs(self._binds) do
		local entry = self._elements[b.ElementKey]
		local item
		item = menuItem(popup, i, "sparkle", (if entry then entry.Name else "?") .. "  " .. bindLabel(b), Theme.TextDim, true)
		item.MouseButton1Click:Connect(function()
			self:_openBindMenu(item, b)
		end)
	end
	self:ShowPopup(anchor, popup, false)
end

-- Key / Mode / value of the row / Visible / Delete
function UI:_openBindMenu(anchor, b, listenNow)
	local entry = self._elements[b.ElementKey]
	if not entry then
		return
	end
	local meta = entry.Meta or {}
	local panel = popupFrame(250, Theme.PopupBg)

	local function row(order, iconName, text)
		local r = create("Frame", {
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = panel,
		})
		Icons[iconName](r, Theme.TabText, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0),
		})
		textLabel({ Text = text, Position = UDim2.fromOffset(38, 0), Size = UDim2.new(0.5, -38, 1, 0), Parent = r })
		return r
	end

	local function pill(parent, accent)
		local p = create("TextButton", {
			Text = "",
			AutoButtonColor = false,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = if accent then Theme.Accent else Theme.Element,
			BackgroundTransparency = if accent then 0.8 else 0,
			Parent = parent,
		}, { corner(6), padding(0, 9, 0, 9), list(6, true) })
		if not accent then
			stroke(Theme.ElementStroke).Parent = p
		else
			Icons.switchIcon(p, Theme.Accent, { LayoutOrder = 1 })
		end
		local t = textLabel({
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			TextSize = 13,
			TextColor3 = if accent then Theme.Accent else Theme.TextDim,
			LayoutOrder = 2,
			Parent = p,
		})
		return p, t
	end

	-- Key
	local keyRow = row(1, "sparkle", "Key")
	local keyPill, keyText = pill(keyRow, false)
	keyText.Text = keyLabel(b.Key)
	local function listen()
		keyText.Text = "..."
		keyText.TextColor3 = Theme.Accent
		self._listening = function(input)
			local t = input.UserInputType
			if t == Enum.UserInputType.Keyboard then
				if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
					b.Key = nil
				elseif input.KeyCode ~= Enum.KeyCode.Escape then
					self:_deactivateBind(b)
					b.Key = input.KeyCode.Name
				end
			elseif
				t == Enum.UserInputType.MouseButton1
				or t == Enum.UserInputType.MouseButton2
				or t == Enum.UserInputType.MouseButton3
			then
				self:_deactivateBind(b)
				b.Key = t.Name
			else
				return false
			end
			if keyText.Parent then
				keyText.Text = keyLabel(b.Key)
				keyText.TextColor3 = Theme.TextDim
			end
			return true
		end
	end
	keyPill.MouseButton1Click:Connect(listen)

	-- Mode
	local modeRow = row(2, "keyboard", "Mode")
	local modePill, modeText = pill(modeRow, true)
	modeText.Text = b.Mode
	modePill.MouseButton1Click:Connect(function()
		local index = table.find(BIND_MODES, b.Mode) or 1
		self:_deactivateBind(b)
		b.Mode = BIND_MODES[index % #BIND_MODES + 1]
		modeText.Text = b.Mode
	end)

	menuDivider(panel, 3)

	-- Value the bind applies + Visible (compact rows, not saved as rows of their own)
	local rows = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Parent = panel,
	}, { list(0) })
	local sec = newSection(rows, self, { RowH = 32, Compact = true, Bg = Theme.PopupBg })
	local function setValue(v)
		b.Value = v
		if b.Active then
			self:_setValue(entry, v)
		end
	end
	if meta.Type == "toggle" then
		sec:AddToggle({ entry.Name, "link" }, b.Value == true, setValue)
	elseif meta.Type == "slider" then
		sec:AddSlider({ entry.Name, "link" }, meta.Min, meta.Max, b.Value, setValue, meta.Suffix, meta.Opts)
	elseif meta.Type == "dropdown" then
		sec:AddDropdown({ entry.Name, "link" }, meta.Options, b.Value, setValue)
	end
	sec:AddToggle({ "Visible", "eye" }, b.Visible, function(v)
		b.Visible = v
		self:_updateBindHud(b)
	end)

	menuDivider(panel, 5)
	local delete = menuItem(panel, 6, "trash", "Delete", Color3.fromRGB(240, 90, 100), false)
	delete.MouseButton1Click:Connect(function()
		self:_deactivateBind(b)
		local index = table.find(self._binds, b)
		if index then
			table.remove(self._binds, index)
		end
		self:ClosePopup()
	end)

	self:ShowPopup(anchor, panel, false)
	if listenNow then
		listen()
	end
end

function UI:_initPresets()
	for _, preset in ipairs(self._presets) do
		preset.Data = preset.Data or self:_snapshot()
	end
end

------------------------------------------------------------------
-- Config files: presets are kept in <workspace>/NeverloseBloxStrike/presets.json (executor file API:
-- writefile / readfile / isfile / makefolder / isfolder). Without writefile, presets live in memory only.
------------------------------------------------------------------
local CONFIG_DIR = "NeverloseBloxStrike"
local CONFIG_FILE = CONFIG_DIR .. "/presets.json"

local function fileApi()
	local ok, write, read, isFile, makeFolder, isFolder = pcall(function()
		return writefile, readfile, isfile, makefolder, isfolder
	end)
	if ok and type(write) == "function" and type(read) == "function" and type(isFile) == "function" then
		return { Write = write, Read = read, IsFile = isFile, MakeFolder = makeFolder, IsFolder = isFolder }
	end
	return nil
end

function UI:_persist()
	local fs = fileApi()
	if not fs then
		if not self._fsWarned then
			self._fsWarned = true
			self:Log("Config files unavailable: no writefile in this executor")
		end
		return false
	end
	local list = {}
	for _, preset in ipairs(self._presets) do
		table.insert(list, { Name = preset.Name, Data = preset.Data })
	end
	local encoded, json = pcall(function()
		return HttpService:JSONEncode({ Version = 1, Profile = self.Profile, Presets = list })
	end)
	if not encoded then
		self:Log("Config save failed: cannot encode presets")
		return false
	end
	local wrote, err = pcall(function()
		if type(fs.MakeFolder) == "function" and type(fs.IsFolder) == "function" and not fs.IsFolder(CONFIG_DIR) then
			fs.MakeFolder(CONFIG_DIR)
		end
		fs.Write(CONFIG_FILE, json)
	end)
	if not wrote then
		self:Log("Config save failed: " .. tostring(err))
	end
	return wrote
end

-- runs once after every tab is built: replaces the preset list with the saved one and applies the saved profile
function UI:_restore()
	local fs = fileApi()
	if not fs then
		return
	end
	local ok, raw = pcall(function()
		if fs.IsFile(CONFIG_FILE) then
			return fs.Read(CONFIG_FILE)
		end
		return nil
	end)
	if not ok or type(raw) ~= "string" then
		return
	end
	local decoded, saved = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not decoded or type(saved) ~= "table" or type(saved.Presets) ~= "table" then
		self:Log("Config file unreadable, defaults kept")
		return
	end
	local presets = {}
	for _, p in ipairs(saved.Presets) do
		if type(p) == "table" and type(p.Name) == "string" and p.Name ~= "" and type(p.Data) == "table" then
			table.insert(presets, { Name = p.Name, Data = p.Data })
		end
	end
	if #presets == 0 then
		return
	end
	-- the saved configs only fill the list: nothing is applied on start, the user loads one by hand
	self._presets = presets
	if self._refreshPresets then
		self._refreshPresets()
	end
	self:Log(#presets .. " saved configs found, none loaded automatically")
end

function UI:_findPreset(name)
	for i, preset in ipairs(self._presets) do
		if preset.Name == name then
			return preset, i
		end
	end
	return nil
end

function UI:_uniqueName(base)
	if not self:_findPreset(base) then
		return base
	end
	local n = 2
	while self:_findPreset(base .. " " .. n) do
		n += 1
	end
	return base .. " " .. n
end

function UI:_setProfile(name)
	self.Profile = name
	self.ProfileLabel.Text = name
	if self.Config.OnProfile then
		task.spawn(self.Config.OnProfile, name)
	end
end

-- JSON of a preset, e.g. to store it yourself (DataStore through a RemoteEvent, writefile, ...)
function UI:ExportPreset(name)
	local preset = self:_findPreset(name or self.Profile)
	return if preset and preset.Data then HttpService:JSONEncode(preset.Data) else nil
end

function UI:ImportPreset(name, json)
	local ok, data = pcall(function()
		return HttpService:JSONDecode(json)
	end)
	if not ok or type(data) ~= "table" then
		return false
	end
	local preset = self:_findPreset(name)
	if preset then
		preset.Data = data
	else
		table.insert(self._presets, { Name = name, Data = data })
	end
	if self._refreshPresets then
		self._refreshPresets()
	end
	self:_persist()
	return true
end

-- Presets popup: [☁ Presets] [scripts]  ...  [save] [delete] [+] / search + sort / cards
function UI:_buildPresets(anchorButton)
	local config = self.Config
	local panel = create("Frame", {
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.PopupBg,
		Active = true,
		ZIndex = 2,
		Visible = false,
		Parent = self.Overlay,
	}, { corner(10), litStroke(Theme.PopupLitTop, Theme.PopupLitBottom), list(8), padding(8, 8, 8, 8) })

	local function divider(order, parent)
		create("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Theme.Divider,
			BorderSizePixel = 0,
			LayoutOrder = order,
			Parent = parent,
		})
	end

	local function iconButton(parent, iconName, color, props)
		local base = {
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = Theme.Hover,
			BackgroundTransparency = 1,
			Parent = parent,
		}
		for k, v in pairs(props or {}) do
			base[k] = v
		end
		local b = create("TextButton", base, { corner(6) })
		local icon = Icons[iconName](b, color, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
		})
		b.MouseEnter:Connect(function()
			tween(b, { BackgroundTransparency = 0.4 })
		end)
		b.MouseLeave:Connect(function()
			tween(b, { BackgroundTransparency = 1 })
		end)
		return b, icon
	end

	-- Header
	local header = create("Frame", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = panel,
	})
	local tabs = create("Frame", {
		Size = UDim2.new(0.65, 0, 1, 0),
		BackgroundTransparency = 1,
		Parent = header,
	}, { list(6, true) })

	local presetsTab = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 28),
		BackgroundColor3 = Theme.AccentSoft,
		LayoutOrder = 1,
		Parent = tabs,
	}, { corner(8), padding(0, 10, 0, 8), list(6, true) })
	local presetsIcon = Icons.cloud(presetsTab, Theme.Accent, { LayoutOrder = 1 })
	local presetsLabel = textLabel({
		Text = "Presets",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		FontFace = Theme.FontBold,
		TextSize = 14,
		TextColor3 = Theme.Accent,
		LayoutOrder = 2,
		Parent = presetsTab,
	})
	local scriptsTab, scriptsIcon = iconButton(tabs, "puzzle", Theme.TabText, { Size = UDim2.fromOffset(28, 28), LayoutOrder = 2 })

	local actions = create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.35, 0, 1, 0),
		BackgroundTransparency = 1,
		Parent = header,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local saveButton = iconButton(actions, "upload", Theme.Accent, { LayoutOrder = 1 })
	local deleteButton = iconButton(actions, "trash", Theme.TabText, { LayoutOrder = 2 })
	local addButton = iconButton(actions, "plus", Theme.TextDim, { LayoutOrder = 3 })

	divider(2, panel)

	-- Presets body: search + sort, list of cards
	local presetsBody = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = panel,
	}, { list(8) })

	local searchRow = create("Frame", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = presetsBody,
	})
	local searchField = create("Frame", {
		Size = UDim2.new(1, -34, 1, 0),
		BackgroundColor3 = Theme.SearchBg,
		Parent = searchRow,
	}, { corner(8), stroke(Theme.PopupCardStroke) })
	Icons.search(searchField, Theme.SubText, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 9, 0.5, 0),
	})
	local searchBox = create("TextBox", {
		Text = "",
		PlaceholderText = "Search",
		PlaceholderColor3 = Theme.SubText,
		ClearTextOnFocus = false,
		FontFace = Theme.Font,
		TextSize = 14,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(32, 0),
		Size = UDim2.new(1, -40, 1, 0),
		Parent = searchField,
	})
	local sortButton, sortIcon = iconButton(searchRow, "sort", Theme.TabText, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
	})

	divider(2, presetsBody)

	local listFrame = create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Scrollbar,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = presetsBody,
	}, { list(8), padding(1, 9, 1, 1) }) -- 1 px so the edge cards' borders are not clipped
	local emptyLabel = textLabel({
		Text = "No presets",
		Size = UDim2.new(1, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 13,
		TextColor3 = Theme.SubText,
		Visible = false,
		LayoutOrder = 4,
		Parent = presetsBody,
	})

	-- Scripts body: entries from config.Scripts = { { "Name", callback }, ... }
	local scriptsBody = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
		LayoutOrder = 4,
		Parent = panel,
	}, { list(8) })

	local CARD_H, GAP, MAX_VISIBLE = 40, 8, 5
	local sortMode = 0 -- 0 = creation order, 1 = A-Z, 2 = Z-A
	local renaming = nil

	local function card(parent, order, text, active)
		local b = create("TextButton", {
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.new(1, 0, 0, CARD_H),
			BackgroundColor3 = Theme.PopupCard,
			LayoutOrder = order,
			Parent = parent,
		}, { corner(8) })
		local s = stroke(if active then Theme.Accent else Theme.PopupCardStroke)
		s.Transparency = if active then 0.35 else 0
		s.Parent = b
		local label = textLabel({
			Text = text,
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -80, 1, 0),
			TextSize = 14,
			TextColor3 = if active then Theme.Text else Theme.TextDim,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = b,
		})
		b.MouseEnter:Connect(function()
			tween(b, { BackgroundColor3 = Theme.Hover })
		end)
		b.MouseLeave:Connect(function()
			tween(b, { BackgroundColor3 = Theme.PopupCard })
		end)
		return b, label
	end

	local function dotsButton(parent)
		local d = create("TextButton", {
			Text = "",
			AutoButtonColor = false,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -36, 0.5, 0),
			Size = UDim2.fromOffset(22, 22),
			BackgroundColor3 = Theme.Hover,
			BackgroundTransparency = 1,
			Parent = parent,
		}, { corner(5) })
		for i = -1, 1 do
			create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, i * 5, 0.5, 0),
				Size = UDim2.fromOffset(3, 3),
				BackgroundColor3 = Theme.TabText,
				BorderSizePixel = 0,
				Parent = d,
			}, { corner(2) })
		end
		d.MouseEnter:Connect(function()
			tween(d, { BackgroundTransparency = 0.3 })
		end)
		d.MouseLeave:Connect(function()
			tween(d, { BackgroundTransparency = 1 })
		end)
		return d
	end

	local refresh

	local function load(preset)
		if preset.Data then
			self:_apply(preset.Data)
		end
		self:_setProfile(preset.Name)
		self:_persist()
		refresh()
	end

	local function save(preset)
		preset.Data = self:_snapshot()
		self:_persist()
		self:Log("Saved preset " .. preset.Name)
		if config.OnSave then
			task.spawn(config.OnSave, preset.Name, HttpService:JSONEncode(preset.Data))
		end
		refresh()
	end

	local function delete(preset)
		if #self._presets <= 1 then
			self:Log("Can't delete the last preset")
			return
		end
		local _, index = self:_findPreset(preset.Name)
		if not index then
			return
		end
		table.remove(self._presets, index)
		if config.OnDelete then
			task.spawn(config.OnDelete, preset.Name)
		end
		if self.Profile == preset.Name then
			self:_setProfile(self._presets[1].Name)
		end
		self:_persist()
		self:Log("Deleted preset " .. preset.Name)
		refresh()
	end

	local function duplicate(preset)
		local copy = {
			Name = self:_uniqueName(preset.Name .. " copy"),
			Data = if preset.Data then table.clone(preset.Data) else nil,
		}
		table.insert(self._presets, copy)
		self:_persist()
		refresh()
	end

	local function rename(preset, newName)
		newName = string.match(newName or "", "^%s*(.-)%s*$")
		renaming = nil
		if newName ~= "" and newName ~= preset.Name and not self:_findPreset(newName) then
			local old = preset.Name
			preset.Name = newName
			if self.Profile == old then
				self:_setProfile(newName)
			end
			if config.OnRename then
				task.spawn(config.OnRename, old, newName)
			end
			self:_persist()
		end
		refresh()
	end

	local function openCardMenu(dots, preset)
		local popup = popupFrame(150, Theme.PopupBg)
		local entries = {
			{ "Load", load },
			{ "Save", save },
			{
				"Rename",
				function(p)
					renaming = p
					refresh()
				end,
			},
			{ "Duplicate", duplicate },
			{ "Delete", delete },
		}
		for i, entry in ipairs(entries) do
			local b = create("TextButton", {
				Text = "",
				AutoButtonColor = false,
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundColor3 = Theme.Hover,
				BackgroundTransparency = 1,
				LayoutOrder = i,
				Parent = popup,
			}, { corner(5) })
			textLabel({
				Text = entry[1],
				Position = UDim2.fromOffset(10, 0),
				Size = UDim2.new(1, -20, 1, 0),
				TextSize = 13,
				TextColor3 = if entry[1] == "Delete" then Color3.fromRGB(240, 90, 100) else Theme.TextDim,
				Parent = b,
			})
			b.MouseEnter:Connect(function()
				tween(b, { BackgroundTransparency = 0.3 })
			end)
			b.MouseLeave:Connect(function()
				tween(b, { BackgroundTransparency = 1 })
			end)
			b.MouseButton1Click:Connect(function()
				self:_closeFrom(2) -- close this menu, keep the presets window
				entry[2](preset)
			end)
		end
		self:ShowPopup(dots, popup, false)
	end

	refresh = function()
		for _, c in ipairs(listFrame:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end

		local q = lower(searchBox.Text)
		local shown = {}
		for _, preset in ipairs(self._presets) do
			if q == "" or string.find(lower(preset.Name), q, 1, true) then
				table.insert(shown, preset)
			end
		end
		if sortMode ~= 0 then
			table.sort(shown, function(x, y)
				local a, b = lower(x.Name), lower(y.Name)
				return if sortMode == 1 then a < b else a > b
			end)
		end

		for i, preset in ipairs(shown) do
			local active = preset.Name == self.Profile
			local b, label = card(listFrame, i, preset.Name, active)
			if renaming == preset then
				label.Visible = false
				local box = create("TextBox", {
					Text = preset.Name,
					ClearTextOnFocus = false,
					FontFace = Theme.Font,
					TextSize = 14,
					TextColor3 = Theme.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(12, 0),
					Size = UDim2.new(1, -80, 1, 0),
					Parent = b,
				})
				box.FocusLost:Connect(function()
					rename(preset, box.Text)
				end)
				task.defer(function()
					box:CaptureFocus()
				end)
			end
			b.MouseButton1Click:Connect(function()
				if renaming ~= preset then
					load(preset)
				end
			end)
			local dots = dotsButton(b)
			dots.MouseButton1Click:Connect(function()
				openCardMenu(dots, preset)
			end)
			local cloud = iconButton(b, "cloudDown", if active then Theme.Accent else Theme.TabText, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
			})
			cloud.MouseButton1Click:Connect(function()
				load(preset)
			end)
		end

		local n = #shown
		listFrame.Size = UDim2.new(1, 0, 0, if n == 0 then 0 else math.min(n, MAX_VISIBLE) * (CARD_H + GAP) - GAP + 2)
		listFrame.ScrollBarThickness = if n > MAX_VISIBLE then 3 else 0
		emptyLabel.Visible = n == 0
	end
	self._refreshPresets = refresh

	local function buildScripts()
		for _, c in ipairs(scriptsBody:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local scripts = config.Scripts or {}
		if #scripts == 0 then
			textLabel({
				Text = "No scripts",
				Size = UDim2.new(1, 0, 0, 30),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextSize = 13,
				TextColor3 = Theme.SubText,
				Parent = scriptsBody,
			})
		end
		for i, entry in ipairs(scripts) do
			local b = card(scriptsBody, i, entry[1], false)
			b.MouseButton1Click:Connect(function()
				if entry[2] then
					task.spawn(entry[2])
				end
			end)
		end
	end

	local function showTab(scripts)
		presetsBody.Visible = not scripts
		scriptsBody.Visible = scripts
		saveButton.Visible = not scripts
		deleteButton.Visible = not scripts
		addButton.Visible = not scripts
		tween(presetsTab, { BackgroundTransparency = if scripts then 1 else 0 })
		tween(scriptsTab, { BackgroundTransparency = if scripts then 0 else 1 })
		scriptsTab.BackgroundColor3 = Theme.AccentSoft
		tween(presetsLabel, { TextColor3 = if scripts then Theme.TabText else Theme.Accent })
		setIconColor(presetsIcon, if scripts then Theme.TabText else Theme.Accent)
		setIconColor(scriptsIcon, if scripts then Theme.Accent else Theme.TabText)
		if scripts then
			buildScripts()
		end
	end

	presetsTab.MouseButton1Click:Connect(function()
		showTab(false)
	end)
	scriptsTab.MouseButton1Click:Connect(function()
		showTab(true)
	end)
	saveButton.MouseButton1Click:Connect(function()
		local preset = self:_findPreset(self.Profile)
		if preset then
			save(preset)
		end
	end)
	deleteButton.MouseButton1Click:Connect(function()
		local preset = self:_findPreset(self.Profile)
		if preset then
			delete(preset)
		end
	end)
	addButton.MouseButton1Click:Connect(function()
	-- a new config starts from the defaults: every row back to its first value, no hotkeys, dark mode, and the skin changer cleared
	local fresh = {}
	for key, entry in pairs(self._elements) do
		fresh[key] = if type(entry.Default) == "table" then table.clone(entry.Default) else entry.Default
	end
	fresh["@binds"] = {}
	fresh["@ui"] = { Theme = "Dark" }
	self:_apply(fresh)
	if self.OnNewConfig then
		pcall(self.OnNewConfig)
	end
	local preset = { Name = self:_uniqueName("New preset"), Data = self:_snapshot() }		table.insert(self._presets, preset)
		self:_setProfile(preset.Name)
		self:_persist()
		renaming = preset
		searchBox.Text = ""
		refresh()
	end)
	sortButton.MouseButton1Click:Connect(function()
		sortMode = (sortMode + 1) % 3
		sortIcon.Rotation = if sortMode == 2 then 180 else 0
		setIconColor(sortIcon, if sortMode == 0 then Theme.TabText else Theme.Accent)
		refresh()
	end)
	searchBox:GetPropertyChangedSignal("Text"):Connect(refresh)

	anchorButton.MouseButton1Click:Connect(function()
		renaming = nil
		showTab(false)
		refresh()
		self:ShowPopup(anchorButton, panel, true, "left")
	end)
end

------------------------------------------------------------------
-- Popups (stack: a popup opened from inside another popup opens beside it)
------------------------------------------------------------------
function UI:_closeFrom(index)
	local stack = self._stack
	for i = #stack, index, -1 do
		local e = table.remove(stack, i)
		if e.keep then
			e.popup.Visible = false
		else
			e.popup:Destroy()
		end
	end
	if #stack == 0 then
		self.Overlay.Visible = false
	end
end

function UI:ClosePopup()
	self:_closeFrom(1)
end

-- align: "right" (default, under the anchor), "left", "side" (next to the anchor)
-- Positions are computed in screen pixels and divided by the overlay scale.
function UI:ShowPopup(anchor, popup, keep, align)
	local stack = self._stack

	local owner = 0
	if anchor:IsDescendantOf(self.Overlay) then
		for i, e in ipairs(stack) do
			if anchor:IsDescendantOf(e.popup) then
				owner = i
			end
		end
	end
	local nested = owner > 0

	if nested then
		local existing = stack[owner + 1]
		self:_closeFrom(owner + 1)
		if existing and existing.anchor == anchor then
			return -- second click on the same opener closes it
		end
	else
		self:ClosePopup()
	end

	popup.Parent = self.Overlay
	popup.Visible = true
	table.insert(stack, { popup = popup, keep = keep, anchor = anchor })
	popup.ZIndex = 1 + #stack
	self.Overlay.Visible = true

	local scale = self.UserScale
	local abs, size = anchor.AbsolutePosition, anchor.AbsoluteSize
	local width = popup.Size.X.Offset * scale
	local screen = self.Gui.AbsoluteSize
	local beside = nested or align == "side"
	local x, y
	if beside then
		local ref = if nested then stack[owner].popup else anchor
		x = ref.AbsolutePosition.X + ref.AbsoluteSize.X + 6
		if x + width > screen.X - 8 then
			x = ref.AbsolutePosition.X - width - 6
		end
		y = abs.Y - 8
	else
		x = if align == "left" then abs.X else (abs.X + size.X - width)
		y = abs.Y + size.Y + 6
	end
	x = math.clamp(x, 8, math.max(8, screen.X - width - 8))
	popup.Position = UDim2.fromOffset(x / scale, y / scale)

	task.spawn(function()
		task.wait()
		if not popup.Parent then
			return
		end
		local h = popup.AbsoluteSize.Y
		local finalY = y
		if beside then
			finalY = math.clamp(y, 8, math.max(8, screen.Y - 8 - h))
		elseif y + h > screen.Y - 8 then
			finalY = abs.Y - h - 6
		end
		popup.Position = UDim2.fromOffset(x / scale, finalY / scale)
	end)
end

-- icons: optional { [option] = iconName }, drawn between the check mark and the text
function UI:_openSelect(anchor, options, isSelected, onPick, multi, icons)
	local popup = popupFrame(math.max(anchor.AbsoluteSize.X / self.UserScale, if icons then 210 else 150))
	local items = {}

	local function refresh()
		for opt, item in pairs(items) do
			local selected = isSelected(opt)
			item.Label.TextColor3 = if selected then Theme.Text else Theme.TabText
			item.Mark.Visible = selected
		end
	end

	for i, opt in ipairs(options) do
		local b = create("TextButton", {
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundColor3 = Theme.Hover,
			BackgroundTransparency = 1,
			LayoutOrder = i,
			Parent = popup,
		}, { corner(5) })
		local x = 10
		local mark
		if multi then
			mark = checkMark(b, UDim2.new(0, 10, 0.5, 0), Theme.Accent)
			x = 30
		else
			mark = create("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(6, 6),
				BackgroundColor3 = Theme.Accent,
				Visible = false,
				Parent = b,
			}, { corner(3) })
		end
		local iconName = icons and icons[opt]
		if iconName and Icons[iconName] then
			Icons[iconName](b, Theme.TabText, {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, x, 0.5, 0),
			})
			x += 24
		end
		local label = textLabel({
			Text = tostring(opt),
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.new(1, -x - 20, 1, 0),
			TextSize = 13,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = b,
		})
		items[opt] = { Label = label, Mark = mark }

		b.MouseEnter:Connect(function()
			tween(b, { BackgroundTransparency = 0.3 })
		end)
		b.MouseLeave:Connect(function()
			tween(b, { BackgroundTransparency = 1 })
		end)
		b.MouseButton1Click:Connect(function()
			onPick(opt)
			refresh()
			if not multi then
				self:ClosePopup()
			end
		end)
	end

	refresh()
	self:ShowPopup(anchor, popup, false)
end

------------------------------------------------------------------
-- Search
------------------------------------------------------------------
function UI:_filter(query)
	local tab = self.Current
	if not tab then
		return
	end
	local q = lower(query)
	for _, sec in ipairs(tab.Sections) do
		local any = false
		for _, r in ipairs(sec.Rows) do
			local visible = q == "" or (r.Text ~= nil and lower(r.Text):find(q, 1, true) ~= nil)
			r.Frame.Visible = visible
			any = any or visible
		end
		local modeOk = sec.Mode == nil or sec.Mode == tab.Mode
		sec.Wrap.Visible = modeOk and (any or q == "")
	end
end

------------------------------------------------------------------
-- Tabs
------------------------------------------------------------------
function UI:AddCategory(name)
	textLabel({
		Text = string.upper(name),
		Size = UDim2.new(1, 0, 0, 30),
		TextSize = 12,
		FontFace = Theme.Font,
		TextColor3 = Theme.SubText,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		LayoutOrder = self:_nextOrder(),
		Parent = self.TabList,
	}, { padding(0, 0, 6, 6) })
end

function UI:SelectTab(selected)
	if self.Current then
		self:_filter("")
	end
	if self._subPage then
		self._subPage.Page.Visible = false
		self._subPage.Bar.Visible = false
		self._subPage = nil
	end
	self.Current = selected
	self.Search.Text = ""
	self:ClosePopup()
	if self.OptionsButton then
		self.OptionsButton.Visible = selected.Options == true
	end
	for _, t in ipairs(self.Tabs) do
		local active = t == selected
		local childActive = selected.Parent == t
		t.Page.Visible = active
		tween(t.Button, { BackgroundTransparency = if active then 0 else 1 })
		tween(t.Title, { TextColor3 = if (active or childActive) then Theme.Text else Theme.TabText })
		if t.Icon then
			setIconColor(t.Icon, if active then Theme.Accent elseif childActive then Theme.TextDim else Theme.IconDim)
		end
		if #t.Children > 0 then
			local open = active or childActive
			for _, c in ipairs(t.Children) do
				c.Button.Visible = open
			end
		end
	end
	if selected._layoutColumns then
		selected._layoutColumns()
	end
	selected.Page.Position = UDim2.fromOffset(0, 12)
	TweenService:Create(selected.Page, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {
		Position = UDim2.fromOffset(0, 0),
	}):Play()
end

-- Scrolling page with two columns; used by tabs and sub-pages. tab.TopOffset leaves room above the columns.
function UI:_makePage(tab)
	tab.Page = create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Stroke,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = self.Pages,
	}, { padding(18, 20, 20, 20) })
	tab.Page:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		self:ClosePopup()
	end)

	local function column()
		return create("Frame", {
			Size = UDim2.fromOffset(300, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = tab.Page,
		}, { list(20) })
	end
	tab.Left = column()
	tab.Right = column()

	-- Columns in pixels from the page's visible width: scale sizes inside a ScrollingFrame are taken
	-- from the canvas, not the padded area, which pushed the right column into the left one.
	local PAD_X, GAP = 20, 20
	function tab._layoutColumns()
		local scale = self.Scale.Scale
		local width = tab.Page.AbsoluteWindowSize.X
		if scale <= 0 or width <= 0 then
			return
		end
		local inner = math.floor(width / scale) - PAD_X * 2
		local top = tab.TopOffset or 0
		if tab.Expanded then
			tab.Right.Position = UDim2.fromOffset(0, top)
			tab.Right.Size = UDim2.fromOffset(inner, 0)
		else
			local w = math.floor((inner - GAP) / 2)
			tab.Left.Position = UDim2.fromOffset(0, top)
			tab.Left.Size = UDim2.fromOffset(w, 0)
			tab.Right.Position = UDim2.fromOffset(w + GAP, top)
			tab.Right.Size = UDim2.fromOffset(w, 0)
		end
	end
	tab.Page:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(tab._layoutColumns)
	task.defer(tab._layoutColumns)
end

function UI:_buildTab(name, iconName, parent, opts)
	opts = opts or {}
	local tab = setmetatable({
		Name = name,
		Window = self,
		Sections = {},
		Children = {},
		Parent = parent,
		Options = opts.Options == true,
	}, Tab)
	local isSub = parent ~= nil

	tab.Button = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, if isSub then 30 else 34),
		BackgroundColor3 = Theme.Active,
		BackgroundTransparency = 1,
		Visible = not isSub,
		LayoutOrder = self:_nextOrder(),
		Parent = self.TabList,
	}, { corner(8) })

	local iconX = if isSub then 30 else 12
	local textX = iconX
	if iconName and Icons[iconName] then
		tab.Icon = Icons[iconName](tab.Button, Theme.IconDim, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, iconX, 0.5, 0),
		})
		textX = iconX + 26
	end

	tab.Title = textLabel({
		Text = name,
		Position = UDim2.fromOffset(textX, 0),
		Size = UDim2.new(1, -textX - 6, 1, 0),
		TextSize = if isSub then 14 else 15,
		TextColor3 = Theme.TabText,
		Parent = tab.Button,
	})

	tab.Button.MouseEnter:Connect(function()
		if self.Current ~= tab then
			tween(tab.Title, { TextColor3 = Theme.Text })
			tween(tab.Button, { BackgroundTransparency = 0.6 })
		end
	end)
	tab.Button.MouseLeave:Connect(function()
		if self.Current ~= tab then
			local keep = self.Current and self.Current.Parent == tab
			tween(tab.Title, { TextColor3 = if keep then Theme.Text else Theme.TabText })
			tween(tab.Button, { BackgroundTransparency = 1 })
		end
	end)

	self:_makePage(tab)

	tab.Button.MouseButton1Click:Connect(function()
		if #tab.Children > 0 then
			local current = self.Current
			if not (current and current.Parent == tab) then
				self:SelectTab(tab.Children[1])
			end
		else
			self:SelectTab(tab)
		end
	end)

	table.insert(self.Tabs, tab)
	if not self.Current then
		self:SelectTab(tab)
	end
	return tab
end

function UI:AddTab(name, iconName, opts)
	return self:_buildTab(name, iconName, nil, opts)
end

function Tab:AddSubTab(name, iconName, opts)
	local sub = self.Window:_buildTab(name, iconName, self, opts)
	table.insert(self.Children, sub)
	if self.Window.Current == self then
		self.Window:SelectTab(sub)
	end
	return sub
end

------------------------------------------------------------------
-- Sub-pages: a page that replaces its tab's content (opened by sec:AddPageLink), with "..." and "×"
------------------------------------------------------------------
function Tab:AddSubPage(title)
	local window = self.Window
	local sub = setmetatable({
		Name = self.Name .. "/" .. title,
		Title = title,
		Window = window,
		Sections = {},
		Children = {},
		Parent = self.Parent,
		Owner = self,
		TopOffset = 26,
		MenuItems = {},
	}, Tab)
	window:_makePage(sub)

	-- "..." and "×" sit on the non-scrolling Pages frame, above the sub-page
	local bar = create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 12),
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 3,
		Parent = window.Pages,
	}, { list(2, true) })
	sub.Bar = bar

	local function barButton(order)
		local b = create("TextButton", {
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = Theme.Hover,
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = bar,
		}, { corner(6) })
		b.MouseEnter:Connect(function()
			tween(b, { BackgroundTransparency = 0.4 })
		end)
		b.MouseLeave:Connect(function()
			tween(b, { BackgroundTransparency = 1 })
		end)
		return b
	end
	local more = barButton(1)
	for i = -1, 1 do
		create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, i * 5, 0.5, 0),
			Size = UDim2.fromOffset(3, 3),
			BackgroundColor3 = Theme.TabText,
			BorderSizePixel = 0,
			Parent = more,
		}, { corner(2) })
	end
	local close = barButton(2)
	fill(close, 6, 12, 14, 2, 1, Theme.TabText, 45)
	fill(close, 6, 12, 14, 2, 1, Theme.TabText, -45)

	more.MouseButton1Click:Connect(function()
		local popup = popupFrame(160, Theme.PopupBg)
		for i, item in ipairs(sub.MenuItems) do
			local disabled = item.Disabled ~= nil and item.Disabled()
			local b = menuItem(popup, i, item[2], item[1], Theme.TextDim, false, disabled)
			if not disabled then
				b.MouseButton1Click:Connect(function()
					window:ClosePopup()
					item[3]()
				end)
			end
		end
		window:ShowPopup(more, popup, false)
	end)
	close.MouseButton1Click:Connect(function()
		window:_closeSubPage()
	end)
	return sub
end

-- entry in the sub-page's "..." menu; disabled() -> true greys it out
function Tab:AddMenuItem(text, iconName, callback, disabled)
	table.insert(self.MenuItems, { text, iconName or "list", callback, Disabled = disabled })
end

local function slideIn(page)
	page.Position = UDim2.fromOffset(0, 12)
	TweenService:Create(page, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {
		Position = UDim2.fromOffset(0, 0),
	}):Play()
end

function UI:_openSubPage(sub)
	self:ClosePopup()
	if self._subPage then
		self._subPage.Page.Visible = false
		self._subPage.Bar.Visible = false
	end
	self._subPage = sub
	sub.Owner.Page.Visible = false
	sub.Page.Visible = true
	sub.Bar.Visible = true
	sub._layoutColumns()
	slideIn(sub.Page)
end

function UI:_closeSubPage()
	local sub = self._subPage
	if not sub then
		return
	end
	self:ClosePopup()
	self._subPage = nil
	sub.Page.Visible = false
	sub.Bar.Visible = false
	if self.Current == sub.Owner then
		sub.Owner.Page.Visible = true
		slideIn(sub.Owner.Page)
	end
end

-- Map Selection (left column of a sub-page): "Global" plus opts.Maps. "Add" gives a map its own copy of
-- every value on this sub-page; selecting a map swaps its values in (the rows' callbacks fire).
-- opts: Title, Maps = { "Main Menu", ... }, OnMap(name). Returns api: SetMap(name), GetMap().
function Tab:AddMapSelector(opts)
	opts = opts or {}
	local window = self.Window
	local prefix = (if self.Parent then self.Parent.Name .. "/" else "") .. self.Name .. "/"
	local maps = { "Global" }
	for _, m in ipairs(opts.Maps or {}) do
		table.insert(maps, m)
	end
	local store = {} -- map name -> values; the active map's values live in the rows themselves
	local active = "Global"
	local clipboard = nil

	local function capture()
		local data = {}
		for key, entry in pairs(window._elements) do
			if string.sub(key, 1, #prefix) == prefix then
				data[key] = window:_valueOf(entry)
			end
		end
		return data
	end
	local function apply(data)
		for key, value in pairs(data) do
			local entry = window._elements[key]
			if entry then
				window:_setValue(entry, value)
			end
		end
	end

	local wrap = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = #self.Left:GetChildren(),
		Parent = self.Left,
	}, { list(9) })
	textLabel({
		Text = string.upper(opts.Title or "Map Selection"),
		Size = UDim2.new(1, 0, 0, 14),
		TextSize = 12,
		TextColor3 = Theme.SubText,
		LayoutOrder = 1,
		Parent = wrap,
	}, { padding(0, 0, 0, 14) })
	local cards = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = wrap,
	}, { list(8) })

	local refresh

	local function select(name)
		if name == active then
			return
		end
		store[active] = capture()
		active = name
		apply(store[name] or store.Global)
		refresh()
		if opts.OnMap then
			task.spawn(opts.OnMap, name)
		end
	end

	local function cardMenu(anchor, entries)
		local popup = popupFrame(150, Theme.PopupBg)
		for i, e in ipairs(entries) do
			local b = menuItem(popup, i, e[2], e[1], e[4] or Theme.TextDim, false)
			b.MouseButton1Click:Connect(function()
				window:ClosePopup()
				e[3]()
			end)
		end
		window:ShowPopup(anchor, popup, false)
	end

	refresh = function()
		for _, c in ipairs(cards:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for i, name in ipairs(maps) do
			local own = name == "Global" or store[name] ~= nil
			local isActive = name == active
			local card = create("TextButton", {
				Text = "",
				AutoButtonColor = false,
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = if isActive then Theme.Active else Theme.Section,
				LayoutOrder = i,
				Parent = cards,
			}, { corner(10) })
			local s = stroke(if isActive then Theme.Accent else Theme.SectionStroke)
			s.Transparency = if isActive then 0.45 else 0
			s.Parent = card
			textLabel({
				Text = name,
				Position = UDim2.fromOffset(14, 0),
				Size = UDim2.new(1, -110, 1, 0),
				TextColor3 = if own then Theme.Text else Theme.TextDim,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = card,
			})

			if own then
				card.MouseButton1Click:Connect(function()
					select(name)
				end)
				local dots = create("TextButton", {
					Text = "",
					AutoButtonColor = false,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.fromOffset(24, 22),
					BackgroundColor3 = Theme.Hover,
					BackgroundTransparency = 1,
					Parent = card,
				}, { corner(5) })
				for k = -1, 1 do
					create("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(0.5, k * 5, 0.5, 0),
						Size = UDim2.fromOffset(3, 3),
						BackgroundColor3 = Theme.TabText,
						BorderSizePixel = 0,
						Parent = dots,
					}, { corner(2) })
				end
				dots.MouseButton1Click:Connect(function()
					if name == "Global" then
						cardMenu(dots, {
							{
								"Reset",
								"undo",
								function()
									-- Global back to the defaults: in the rows if it is active, else in its stored copy
									local defaults = {}
									for key, entry in pairs(window._elements) do
										if string.sub(key, 1, #prefix) == prefix then
											defaults[key] = entry.Default
										end
									end
									if active == "Global" then
										apply(defaults)
									else
										store.Global = defaults
									end
								end,
							},
						})
					else
						cardMenu(dots, {
							{
								"Remove",
								"trash",
								function()
									if active == name then
										select("Global")
									end
									store[name] = nil
									refresh()
								end,
								Color3.fromRGB(240, 90, 100),
							},
						})
					end
				end)
			else
				local add = create("TextButton", {
					Text = "",
					AutoButtonColor = false,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -8, 0.5, 0),
					Size = UDim2.fromOffset(0, 26),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundColor3 = Theme.Hover,
					BackgroundTransparency = 1,
					Parent = card,
				}, { corner(6), padding(0, 8, 0, 8), list(6, true) })
				Icons.folderPlus(add, Theme.TabText, { LayoutOrder = 1 })
				textLabel({
					Text = "Add",
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromScale(0, 1),
					TextColor3 = Theme.TextDim,
					LayoutOrder = 2,
					Parent = add,
				})
				add.MouseEnter:Connect(function()
					tween(add, { BackgroundTransparency = 0.4 })
				end)
				add.MouseLeave:Connect(function()
					tween(add, { BackgroundTransparency = 1 })
				end)
				add.MouseButton1Click:Connect(function()
					store[name] = capture()
					select(name)
				end)
			end
		end
	end
	refresh()

	self:AddMenuItem("Copy", "copy", function()
		clipboard = capture()
	end)
	self:AddMenuItem("Paste", "copy", function()
		apply(clipboard)
	end, function()
		return clipboard == nil
	end)

	local api = {}
	-- call when the game changes map: uses that map's values if it has its own, otherwise Global
	function api:SetMap(name)
		select(if store[name] then name else "Global")
	end
	function api:GetMap()
		return active
	end
	return api
end

-- Row with ">" that opens a sub-page in place of the tab's content
function Section:AddPageLink(text, subPage)
	local row, label = self:_row(text)
	label.Size = UDim2.new(1, -(label.Position.X.Offset + 34), 1, 0)
	chevron(row, UDim2.new(1, -14, 0.5, 0), -90)
	local button = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = row,
	})
	button.MouseEnter:Connect(function()
		tween(label, { TextColor3 = Theme.Text })
	end)
	button.MouseLeave:Connect(function()
		tween(label, { TextColor3 = Theme.TextDim })
	end)
	button.MouseButton1Click:Connect(function()
		self.Window:_openSubPage(subPage)
	end)
end

-- Plain list of options that toggle on click (selected: bright text and a check); name is the preset key
function Section:AddSelectList(name, options, defaults, callback)
	local selected = {}
	for _, o in ipairs(defaults or {}) do
		selected[o] = true
	end
	local items = {}

	local function getList()
		local t = {}
		for _, o in ipairs(options) do
			if selected[o] then
				table.insert(t, o)
			end
		end
		return t
	end
	local function render()
		for opt, item in pairs(items) do
			tween(item.Label, { TextColor3 = if selected[opt] then Theme.Text else Theme.TabText })
			item.Mark.Visible = selected[opt] == true
		end
	end
	local function changed()
		render()
		if callback then
			task.spawn(callback, getList())
		end
	end

	for _, opt in ipairs(options) do
		self._n += 1
		local b = create("TextButton", {
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundColor3 = Theme.Hover,
			BackgroundTransparency = 1,
			LayoutOrder = self._n,
			Parent = self.Box,
		}, { corner(6) })
		items[opt] = {
			Label = textLabel({
				Text = opt,
				Position = UDim2.fromOffset(14, 0),
				Size = UDim2.new(1, -44, 1, 0),
				TextColor3 = Theme.TabText,
				Parent = b,
			}),
			Mark = checkMark(b, UDim2.new(1, -26, 0.5, 0), Theme.Accent),
		}
		b.MouseEnter:Connect(function()
			tween(b, { BackgroundTransparency = 0.5 })
		end)
		b.MouseLeave:Connect(function()
			tween(b, { BackgroundTransparency = 1 })
		end)
		b.MouseButton1Click:Connect(function()
			selected[opt] = if selected[opt] then nil else true
			changed()
		end)
		table.insert(self.Rows, { Frame = b, Text = opt })
	end

	local api = {}
	function api:Get()
		return getList()
	end
	function api:Set(list)
		selected = {}
		for _, o in ipairs(list) do
			selected[o] = true
		end
		changed()
	end
	render()
	if callback then
		task.spawn(callback, getList())
	end
	self:_register(name, "multi", api)
	return api
end

------------------------------------------------------------------
-- Character preview (right column): mode tabs, ESP Items popup, expand, viewport with your character
------------------------------------------------------------------
local CHAMS_MATERIALS = {
	Neon = Enum.Material.Neon,
	Flat = Enum.Material.SmoothPlastic,
	ForceField = Enum.Material.ForceField,
	Glass = Enum.Material.Glass,
}

local DEFAULT_ESP_ITEMS = {
	{ "Main", { "Bounding Box", "Name", "Distance", "Health Bar", "Ammo Bar", "Skeleton" } },
	{
		"Flags",
		{
			"Unarmored", "Defuser", "Blind", "Scoped", "Reload", "Immunity", "Slowed", "Vulnerable",
			"Bomb", "Hostage", "Defuse", "Pin Pulled", "Money", "Order Priority", "Delay",
		},
	},
	{ "Weapon", { "Text", "Icon", "Readiness Bar", "Bomb", "Defuser", "Taser" } },
}

-- items drawn by dedicated elements; every other enabled item is listed as a flag right of the box
local DRAWN_ITEMS = {
	["Main/Bounding Box"] = true,
	["Main/Name"] = true,
	["Main/Distance"] = true,
	["Main/Health Bar"] = true,
	["Main/Ammo Bar"] = true,
	["Main/Skeleton"] = true,
	["Weapon/Text"] = true,
	["Weapon/Icon"] = true,
	["Weapon/Readiness Bar"] = true,
}

local SKELETON = {
	-- R15
	{ "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
	{ "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
	{ "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
	{ "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
	{ "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
	-- R6
	{ "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" }, { "Torso", "Left Leg" }, { "Torso", "Right Leg" },
}

local function textWidth(text, size)
	local ok, v = pcall(function()
		return TextService:GetTextSize(text, size, Enum.Font.BuilderSansMedium, Vector2.new(1000, 100))
	end)
	return if ok then v.X else #text * size * 0.55
end

function Tab:_applyMode()
	for _, sec in ipairs(self.Sections) do
		if sec.Mode then
			sec.Wrap.Visible = sec.Mode == self.Mode
		end
	end
end

-- ESP elements that can be dragged to a side of the box: key, kind, default side (order = list order per side)
local ESP_ELEMENTS = {
	{ "Main/Name", "text", "Top" },
	{ "Main/Health Bar", "bar", "Left" },
	{ "Main/Ammo Bar", "bar", "Bottom" },
	{ "Weapon/Readiness Bar", "bar", "Bottom" },
	{ "Weapon/Icon", "icon", "Bottom" },
	{ "Weapon/Text", "text", "Bottom" },
	{ "Main/Distance", "text", "Bottom" },
	-- every flag is an element of its own ("flag", default side Right), added per preview from its items
}
local ESP_SIDES = { "Top", "Bottom", "Left", "Right" }

-- How each flag is written next to the box: short CS-style text, or a value; default colour by meaning.
-- Value flags read the local player in the preview (ping, leaderstats money) and fall back to a sample.
local FLAG_LOOK = {
	["Flags/Unarmored"] = { Text = "NO ARMOR", Color = rgb(235, 235, 240) },
	["Flags/Defuser"] = { Text = "KIT", Color = rgb(120, 190, 255) },
	["Flags/Blind"] = { Text = "BLIND", Color = rgb(235, 235, 240) },
	["Flags/Scoped"] = { Text = "SCOPED", Color = rgb(120, 190, 255) },
	["Flags/Reload"] = { Text = "RELOAD", Color = rgb(235, 235, 240) },
	["Flags/Immunity"] = { Text = "IMMUNE", Color = rgb(170, 150, 255) },
	["Flags/Slowed"] = { Text = "SLOWED", Color = rgb(235, 235, 240) },
	["Flags/Vulnerable"] = { Text = "VULN", Color = rgb(255, 120, 120) },
	["Flags/Bomb"] = { Text = "C4", Color = rgb(255, 120, 120) },
	["Flags/Hostage"] = { Text = "HOSTAGE", Color = rgb(235, 235, 240) },
	["Flags/Defuse"] = { Text = "DEFUSING", Color = rgb(120, 190, 255) },
	["Flags/Pin Pulled"] = { Text = "PIN", Color = rgb(255, 120, 120) },
	["Flags/Money"] = { Value = "money", Color = rgb(110, 220, 130) },
	["Flags/Order Priority"] = { Text = "#1", Color = rgb(235, 235, 240) },
	["Flags/Delay"] = { Value = "ping", Color = rgb(235, 235, 240) },
	-- weapon flags say what the player carries; the C4 / KIT of the Flags group mean the same thing
	["Weapon/Bomb"] = { Text = "C4", Color = rgb(240, 180, 70) },
	["Weapon/Defuser"] = { Text = "KIT", Color = rgb(240, 180, 70) },
	["Weapon/Taser"] = { Text = "TASER", Color = rgb(240, 180, 70) },
}

local function flagText(key)
	local look = FLAG_LOOK[key]
	if not look then
		return string.upper(string.match(key, "/(.+)$") or key)
	end
	if look.Value == "ping" then
		local ok, ping = pcall(function()
			return player:GetNetworkPing()
		end)
		return (if ok and type(ping) == "number" then math.floor(ping * 1000 + 0.5) else 48) .. "MS"
	elseif look.Value == "money" then
		local stats = player:FindFirstChild("leaderstats")
		local money = stats and (stats:FindFirstChild("Money") or stats:FindFirstChild("Cash"))
		local amount = money and tonumber(money.Value)
		return "$" .. tostring(if amount then math.floor(amount) else 2350)
	end
	return look.Text
end

local function espKind(key)
	for _, def in ipairs(ESP_ELEMENTS) do
		if def[1] == key then
			return def[2]
		end
	end
	return nil
end

-- per-item look; the fields present decide which settings the item's popup shows
local function defaultEspStyle(key)
	local s = { Color = rgb(235, 235, 240) }
	if key == "Main/Bounding Box" then
		s.Thickness = 1
		s.Fill = false
	elseif key == "Main/Skeleton" then
		s.Thickness = 2
	elseif key == "Main/Health Bar" then
		s.Color = rgb(110, 220, 130)
		s.Thickness = 3
		s.ShowValue = true
	elseif key == "Main/Ammo Bar" then
		s.Color = rgb(90, 140, 245)
		s.Thickness = 3
	elseif key == "Weapon/Readiness Bar" then
		s.Color = rgb(240, 180, 70)
		s.Thickness = 3
	elseif key == "Main/Name" or key == "Main/Distance" or key == "Weapon/Text" then
		s.Size = if key == "Main/Name" then 13 else 12
		s.Outline = true
	elseif key == "Weapon/Icon" then
		s.Color = rgb(215, 213, 221)
		s.IconSize = 100 -- percent of the default icon size
	end
	local flag = FLAG_LOOK[key]
	if flag then
		s.Color = flag.Color
	end
	return s
end

-- opts: Height, Modes = { { Name, Icon, Label } }, Items = { { group, { items } } }, Weapon = "AK-47",
--       OnMode(mode), OnItem(mode, "Group/Item", enabled), OnLayout(mode, layout), OnStyle(mode, key, style)
-- Sections added with tab:AddSection(name, side, modeName) show only in that mode.
-- Preview: drag an element to another side of the box; click it (or right-click its chip) for its settings.
function Tab:AddPreview(opts)
	opts = opts or {}
	local window = self.Window
	local tab = self
	local modes = opts.Modes or {
		{ Name = "Enemies", Icon = "user", Label = "Enemy" },
		{ Name = "Teammates", Icon = "userMinus", Label = "Teammate" },
	}
	local espItems = opts.Items or DEFAULT_ESP_ITEMS
	local baseHeight = opts.Height or 480
	local tabPath = (if tab.Parent then tab.Parent.Name .. "/" else "") .. tab.Name
	tab.Mode = modes[1].Name

	-- flags: every item that has no element of its own
	local flagKeys = {}
	for _, group in ipairs(espItems) do
		for _, item in ipairs(group[2]) do
			local key = group[1] .. "/" .. item
			if not DRAWN_ITEMS[key] then
				table.insert(flagKeys, key)
			end
		end
	end
	-- draggable elements of this preview: the fixed ones plus one per flag
	local elements = table.clone(ESP_ELEMENTS)
	for _, key in ipairs(flagKeys) do
		table.insert(elements, { key, "flag", "Right" })
	end

	local frame = create("Frame", {
		Size = UDim2.new(1, 0, 0, baseHeight),
		BackgroundTransparency = 1,
		LayoutOrder = #self.Right:GetChildren(),
		Parent = self.Right,
	})

	------------------------------------------------------------------
	-- Header: [mode] [mode] | [ESP items] [expand]
	------------------------------------------------------------------
	local header = create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -2, 0, 0),
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = frame,
	}, { list(4, true) })

	local function headerButton(order)
		local b = create("TextButton", {
			Text = "",
			AutoButtonColor = false,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = Theme.Hover,
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = header,
		}, { corner(6), padding(0, 5, 0, 5), list(6, true) })
		b.MouseEnter:Connect(function()
			tween(b, { BackgroundTransparency = 0.5 })
		end)
		b.MouseLeave:Connect(function()
			tween(b, { BackgroundTransparency = 1 })
		end)
		return b
	end

	local modeViews = {}
	for i, m in ipairs(modes) do
		local b = headerButton(i)
		local icon = Icons[m.Icon](b, Theme.TextDim, { LayoutOrder = 1 })
		local label = textLabel({
			Text = m.Name,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			TextSize = 14,
			TextColor3 = Theme.Accent,
			LayoutOrder = 2,
			Parent = b,
		})
		modeViews[i] = { Button = b, Icon = icon, Label = label }
	end
	create("Frame", {
		Size = UDim2.fromOffset(1, 16),
		BackgroundColor3 = Theme.HeaderDivider,
		BorderSizePixel = 0,
		LayoutOrder = #modes + 1,
		Parent = header,
	})
	local itemsButton = headerButton(#modes + 2)
	Icons.listBox(itemsButton, Theme.TextDim, { LayoutOrder = 1 })
	local expandButton = headerButton(#modes + 3)
	local expandIcon = Icons.expand(expandButton, Theme.TextDim, { LayoutOrder = 1 })

	------------------------------------------------------------------
	-- Stage: viewport + ESP overlay
	------------------------------------------------------------------
	local stage = create("Frame", {
		Position = UDim2.fromOffset(20, 44),
		Size = UDim2.new(1, -40, 1, -64),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	local viewport = create("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 170, 180),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-0.4, -1, 0.6),
		Parent = stage,
	})
	local camera = create("Camera", { FieldOfView = 30, Parent = viewport })
	viewport.CurrentCamera = camera
	local worldModel = create("WorldModel", { Parent = viewport })
	local status = textLabel({
		Text = "Loading character...",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 13,
		TextColor3 = Theme.SubText,
		Parent = stage,
	})

	local skeletonFolder = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = stage,
	})
	-- the box itself is not draggable; clicking it opens its settings
	local box = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = stage,
	})
	local boxFill = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = box,
	})
	local boxStroke = stroke(Color3.new(1, 1, 1), 1)
	boxStroke.Parent = box

	-- one stack per side of the box; Top / Left list outwards with negative orders
	local sideFrames = {
		Top = create("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 0, -3),
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = box,
		}),
		Bottom = create("Frame", {
			Position = UDim2.new(0, 0, 1, 3),
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = box,
		}),
		Left = create("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(0, -4, 0, 0),
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Parent = box,
		}),
		Right = create("Frame", {
			Position = UDim2.new(1, 4, 0, 0),
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Parent = box,
		}),
	}
	for side, f in pairs(sideFrames) do
		local horizontal = side == "Left" or side == "Right"
		create("UIListLayout", {
			Padding = UDim.new(0, if horizontal then 3 else 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
			HorizontalAlignment = if side == "Left" then Enum.HorizontalAlignment.Right
				elseif side == "Right" then Enum.HorizontalAlignment.Left
				else Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Parent = f,
		})
	end

	------------------------------------------------------------------
	-- State per mode: enabled items, styles, layout
	------------------------------------------------------------------
	local espState, chams, styles, layouts = {}, {}, {}, {}
	for _, m in ipairs(modes) do
		espState[m.Name] = {}
		chams[m.Name] = { Material = nil, Color = Color3.new(1, 1, 1) }
		styles[m.Name] = {}
		local lay, counts = {}, {}
		for _, def in ipairs(elements) do
			counts[def[3]] = (counts[def[3]] or 0) + 1
			lay[def[1]] = { Side = def[3], Order = counts[def[3]] }
		end
		layouts[m.Name] = lay
	end
	local function on(key)
		return espState[tab.Mode][key] == true
	end
	local function styleOf(mode, key)
		local s = styles[mode][key]
		if not s then
			s = defaultEspStyle(key)
			styles[mode][key] = s
		end
		return s
	end
	-- On Left / Right, bars stand as columns next to the box and all other elements form one text
	-- stack outside them (so "12m" sits above the flags, not in a column of its own); Top / Bottom
	-- keep a single list. Orders count within such a group.
	local function category(key, side)
		if side == "Top" or side == "Bottom" then
			return "all"
		end
		return if espKind(key) == "bar" then "bar" else "stack"
	end

	local function normalize(mode)
		local lay = layouts[mode]
		for _, side in ipairs(ESP_SIDES) do
			for _, cat in ipairs({ "all", "bar", "stack" }) do
				local keys = {}
				for k, v in pairs(lay) do
					if v.Side == side and category(k, side) == cat then
						table.insert(keys, k)
					end
				end
				table.sort(keys, function(a, b)
					return lay[a].Order < lay[b].Order
				end)
				for i, k in ipairs(keys) do
					lay[k].Order = i
				end
			end
		end
	end

	------------------------------------------------------------------
	-- Building the elements
	------------------------------------------------------------------
	local built = {} -- key -> holder (TextButton in a side stack)
	local healthRefs = {}
	local healthValue = 100
	local drag = nil
	local openSettings -- defined below

	local function isHorizontalSide(side)
		return side == "Top" or side == "Bottom"
	end
	-- LayoutOrder for the n-th element of a side (x10 leaves room for the drop placeholder)
	local function sideOrder(side, n)
		return if side == "Top" or side == "Left" then -n else n
	end

	local function textElement(holder, horizontal, text, s, bold)
		textLabel({
			Text = text,
			AutomaticSize = if horizontal then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
			Size = if horizontal then UDim2.new(1, 0, 0, s.Size + 3) else UDim2.fromOffset(0, s.Size + 3),
			TextXAlignment = if horizontal then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
			FontFace = if bold then Theme.FontBold else Theme.Font,
			TextSize = s.Size,
			TextColor3 = s.Color,
			TextStrokeTransparency = if s.Outline then 0.5 else 1,
			Parent = holder,
		})
	end

	local function barElement(holder, horizontal, fraction, s, health)
		local t = s.Thickness
		holder.AutomaticSize = Enum.AutomaticSize.None
		holder.Size = if horizontal then UDim2.new(1, 0, 0, t) else UDim2.new(0, t, 1, 0)
		local track = create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Deep,
			BorderSizePixel = 0,
			Parent = holder,
		})
		local barFill = create("Frame", {
			AnchorPoint = if horizontal then Vector2.zero else Vector2.new(0, 1),
			Position = if horizontal then UDim2.new() else UDim2.fromScale(0, 1),
			Size = if horizontal then UDim2.fromScale(fraction, 1) else UDim2.fromScale(1, fraction),
			BackgroundColor3 = s.Color,
			BorderSizePixel = 0,
			Parent = track,
		})
		local value
		if health and s.ShowValue then
			value = textLabel({
				AnchorPoint = if horizontal then Vector2.new(0, 0.5) else Vector2.new(1, 0.5),
				Position = if horizontal then UDim2.new(1, 4, 0.5, 0) else UDim2.new(0, -3, 0, 0),
				Size = UDim2.fromOffset(24, 12),
				TextXAlignment = if horizontal then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
				TextSize = 11,
				TextColor3 = s.Color,
				TextStrokeTransparency = 0.6,
				Text = tostring(healthValue),
				Parent = if horizontal then track else barFill,
			})
		end
		if health then
			table.insert(healthRefs, { Fill = barFill, Label = value, Horizontal = horizontal })
		end
	end

	local function iconElement(holder, horizontal, s)
		local k = (s.IconSize or 100) / 100 -- "Icon Size" setting of the item
		local function px(n)
			return math.max(1, math.floor(n * k + 0.5))
		end
		holder.AutomaticSize = Enum.AutomaticSize.None
		holder.Size = if horizontal then UDim2.new(1, 0, 0, px(10)) else UDim2.fromOffset(px(26), px(12))
		local g = create("Frame", {
			AnchorPoint = Vector2.new(if horizontal then 0.5 else 0, 0),
			Position = UDim2.fromScale(if horizontal then 0.5 else 0, 0),
			Size = UDim2.fromOffset(px(26), px(10)),
			BackgroundTransparency = 1,
			Parent = holder,
		})
		fill(g, 0, px(2), px(26), px(3), 1, s.Color)
		fill(g, px(5), px(1), px(10), px(5), 1, s.Color)
		fill(g, px(11), px(5), px(3), px(5), 1, s.Color)
		fill(g, 0, px(3), px(5), px(5), 1, s.Color)
	end

	-- one flag: short bold text in its own colour
	local function flagElement(holder, horizontal, text, s)
		textLabel({
			Text = text,
			AutomaticSize = if horizontal then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
			Size = if horizontal then UDim2.new(1, 0, 0, 12) else UDim2.fromOffset(0, 12),
			TextXAlignment = if horizontal then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
			FontFace = Theme.FontBold,
			TextSize = 10,
			TextColor3 = s.Color,
			TextStrokeTransparency = 0.4,
			Parent = holder,
		})
	end

	local function hookElement(holder, key)
		holder.InputBegan:Connect(function(input)
			if not isClick(input) or drag then
				return
			end
			local p = pointerPosition(input)
			drag = { Key = key, Holder = holder, Start = p, Grab = p - holder.AbsolutePosition, Moving = false }
		end)
	end

	-- text stack of a Left / Right side, outside the bars
	local stacks = {}
	local function getStack(side)
		local st = stacks[side]
		if not st or not st.Parent then
			st = create("Frame", {
				AutomaticSize = Enum.AutomaticSize.XY,
				Size = UDim2.fromOffset(0, 0),
				BackgroundTransparency = 1,
				LayoutOrder = sideOrder(side, 100000),
				Parent = sideFrames[side],
			}, {
				create("UIListLayout", {
					Padding = UDim.new(0, 1),
					SortOrder = Enum.SortOrder.LayoutOrder,
					HorizontalAlignment = if side == "Left" then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left,
				}),
			})
			stacks[side] = st
		end
		return st
	end

	local function refreshEsp()
		local mode = tab.Mode
		local boxStyle = styleOf(mode, "Main/Bounding Box")
		boxStroke.Enabled = on("Main/Bounding Box")
		boxStroke.Color = boxStyle.Color
		boxStroke.Thickness = boxStyle.Thickness
		boxFill.BackgroundColor3 = boxStyle.Color
		boxFill.BackgroundTransparency = if boxStyle.Fill and on("Main/Bounding Box") then 0.85 else 1
		skeletonFolder.Visible = on("Main/Skeleton")

		for _, h in pairs(built) do
			h:Destroy()
		end
		for _, st in pairs(stacks) do
			st:Destroy()
		end
		built = {}
		stacks = {}
		healthRefs = {}
		local lay = layouts[mode]
		local label = mode
		for _, m in ipairs(modes) do
			if m.Name == mode then
				label = m.Label or m.Name
			end
		end

		local shownFlags = {} -- C4 / KIT from Flags and from Weapon are written once
		for _, def in ipairs(elements) do
			local key, kind = def[1], def[2]
			local enabled = on(key)
			local flagLabel = if kind == "flag" then flagText(key) else nil
			if flagLabel then
				enabled = enabled and not shownFlags[flagLabel]
				if enabled then
					shownFlags[flagLabel] = true
				end
			end
			local dragged = drag ~= nil and drag.Moving and drag.Key == key
			if enabled and not dragged then
				local side = lay[key].Side
				local horizontal = isHorizontalSide(side)
				local inStack = category(key, side) == "stack"
				local holder = create("TextButton", {
					Text = "",
					AutoButtonColor = false,
					BackgroundTransparency = 1,
					AutomaticSize = if horizontal then Enum.AutomaticSize.Y
						elseif inStack then Enum.AutomaticSize.XY
						else Enum.AutomaticSize.X,
					Size = if horizontal then UDim2.new(1, 0, 0, 0)
						elseif inStack then UDim2.fromOffset(0, 0)
						else UDim2.new(0, 0, 1, 0),
					LayoutOrder = if inStack then lay[key].Order * 10 else sideOrder(side, lay[key].Order * 10),
					Parent = if inStack then getStack(side) else sideFrames[side],
				})
				local s = styleOf(mode, key)
				if kind == "text" then
					local text = if key == "Main/Name" then label
						elseif key == "Main/Distance" then "12m"
						else opts.Weapon or "AK-47"
					textElement(holder, horizontal, text, s, key == "Main/Name")
				elseif kind == "bar" then
					local fraction = if key == "Main/Health Bar" then healthValue / 100
						elseif key == "Main/Ammo Bar" then 0.7
						else 0.45
					barElement(holder, horizontal, fraction, s, key == "Main/Health Bar")
				elseif kind == "icon" then
					iconElement(holder, horizontal, s)
				else
					flagElement(holder, horizontal, flagLabel, s)
				end
				built[key] = holder
				hookElement(holder, key)
			end
		end
	end

	------------------------------------------------------------------
	-- Dragging: the element follows the pointer, a grey placeholder shows where it will land
	------------------------------------------------------------------
	local function scale()
		return window.Scale.Scale
	end
	local function toStage(abs)
		return (abs - stage.AbsolutePosition) / scale()
	end

	-- side: the one the pointer is furthest beyond (inside the box: the nearest edge);
	-- index: 1 + elements of that side that were closer to the box than the pointer when the drag began
	local function dropTarget(p)
		local a, s = box.AbsolutePosition, box.AbsoluteSize
		local beyond = {
			Top = a.Y - p.Y,
			Bottom = p.Y - (a.Y + s.Y),
			Left = a.X - p.X,
			Right = p.X - (a.X + s.X),
		}
		local side, best = "Top", -math.huge
		for _, name in ipairs(ESP_SIDES) do
			if beyond[name] > best then
				side, best = name, beyond[name]
			end
		end
		local cat = category(drag.Key, side)
		local index = 1
		for _, e in ipairs(drag.Snapshot) do
			if e.Side == side and category(e.Key, side) == cat then
				local c = e.Center
				local closer = if cat == "stack" then c.Y < p.Y -- stack: top to bottom
					else (side == "Top" and c.Y > p.Y)
						or (side == "Bottom" and c.Y < p.Y)
						or (side == "Left" and c.X > p.X)
						or (side == "Right" and c.X < p.X)
				if closer then
					index += 1
				end
			end
		end
		return side, index
	end

	local function showPlaceholder(side, index)
		if drag.Placeholder then
			drag.Placeholder:Destroy()
		end
		local kind = espKind(drag.Key)
		local inStack = category(drag.Key, side) == "stack"
		local size
		if isHorizontalSide(side) then
			size = UDim2.fromOffset(48, if kind == "bar" then 6 else 16)
		else
			size = if inStack then UDim2.fromOffset(46, 14) else UDim2.new(0, 6, 1, 0)
		end
		drag.Placeholder = create("Frame", {
			Size = size,
			BackgroundColor3 = Theme.Element,
			BackgroundTransparency = 0.15,
			LayoutOrder = if inStack then index * 10 - 5 else sideOrder(side, index * 10 - 5),
			Parent = if inStack then getStack(side) else sideFrames[side],
		}, { corner(4), stroke(Theme.ElementStroke) })
	end

	local function moveElement(key, side, index)
		local lay = layouts[tab.Mode]
		local cat = category(key, side)
		local keys = {}
		for k, v in pairs(lay) do
			if v.Side == side and k ~= key and category(k, side) == cat then
				table.insert(keys, k)
			end
		end
		table.sort(keys, function(a, b)
			return lay[a].Order < lay[b].Order
		end)
		table.insert(keys, math.clamp(index, 1, #keys + 1), key)
		lay[key].Side = side
		for i, k in ipairs(keys) do
			lay[k].Order = i
		end
		normalize(tab.Mode)
		if opts.OnLayout then
			task.spawn(opts.OnLayout, tab.Mode, table.clone(lay))
		end
	end

	UserInputService.InputChanged:Connect(function(input)
		if not drag or not isMove(input) then
			return
		end
		local p = pointerPosition(input)
		if not drag.Moving then
			if (p - drag.Start).Magnitude < 4 then
				return
			end
			drag.Moving = true
			window:ClosePopup()
			drag.Snapshot = {}
			for k, h in pairs(built) do
				if k ~= drag.Key then
					table.insert(drag.Snapshot, {
						Key = k,
						Side = layouts[tab.Mode][k].Side,
						Center = h.AbsolutePosition + h.AbsoluteSize / 2,
					})
				end
			end
			local h = drag.Holder
			local ghost = h:Clone()
			ghost.AutomaticSize = Enum.AutomaticSize.None
			ghost.Size = UDim2.fromOffset(h.AbsoluteSize.X / scale(), h.AbsoluteSize.Y / scale())
			ghost.Active = false
			ghost.Parent = stage
			drag.Ghost = ghost
			h.Visible = false
		end
		local at = toStage(p - drag.Grab)
		drag.Ghost.Position = UDim2.fromOffset(at.X, at.Y)
		local side, index = dropTarget(p)
		if side ~= drag.Side or index ~= drag.Index then
			drag.Side, drag.Index = side, index
			showPlaceholder(side, index)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if not drag or not isClick(input) then
			return
		end
		local d = drag
		drag = nil
		if d.Moving then
			if d.Ghost then
				d.Ghost:Destroy()
			end
			if d.Placeholder then
				d.Placeholder:Destroy()
			end
			if d.Side then
				moveElement(d.Key, d.Side, d.Index)
			end
			refreshEsp()
		elseif d.Holder.Parent then
			openSettings(d.Key, d.Holder)
		end
	end)

	-- demo health: the bar keeps changing like in the original preview
	task.spawn(function()
		while frame.Parent do
			task.wait(1.6)
			healthValue = math.random(15, 100)
			for _, ref in ipairs(healthRefs) do
				if ref.Fill.Parent then
					tween(ref.Fill, {
						Size = if ref.Horizontal then UDim2.fromScale(healthValue / 100, 1) else UDim2.fromScale(1, healthValue / 100),
					}, 0.5)
					if ref.Label then
						ref.Label.Text = tostring(healthValue)
					end
				end
			end
		end
	end)

	------------------------------------------------------------------
	-- Model, camera and projection
	------------------------------------------------------------------
	local model, extents, distance
	local originals = {}
	local skeletonLines = {}

	local function frameCamera()
		local s = stage.AbsoluteSize
		local aspect = if s.Y > 0 and s.X > 0 then s.X / s.Y else 0.75
		local t = math.tan(math.rad(camera.FieldOfView / 2))
		local dv = (extents.Y / 2) / t
		local dh = (extents.X / 2) / (t * aspect)
		-- 1.45: the model takes about two thirds of the stage, as in the original
		distance = math.max(dv, dh) * 1.45 + extents.Z / 2
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, -distance), Vector3.zero)
	end

	-- camera at (0, 0, -distance) looking +Z, vertical FOV; screen X grows toward world -X
	local function project(p)
		local s = stage.AbsoluteSize / scale()
		local depth = p.Z + distance
		if depth <= 0.05 then
			return nil
		end
		local k = (s.Y / 2) / (depth * math.tan(math.rad(camera.FieldOfView / 2)))
		return Vector2.new(s.X / 2 - p.X * k, s.Y / 2 - p.Y * k)
	end

	local function layoutOverlay()
		if not model or not extents then
			box.Visible = false
			skeletonFolder.Visible = false
			return
		end
		frameCamera()
		local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local q = project(Vector3.new(sx * extents.X / 2, sy * extents.Y / 2, sz * extents.Z / 2))
					if q then
						minX, minY = math.min(minX, q.X), math.min(minY, q.Y)
						maxX, maxY = math.max(maxX, q.X), math.max(maxY, q.Y)
					end
				end
			end
		end
		if minX < maxX then
			box.Position = UDim2.fromOffset(minX, minY)
			box.Size = UDim2.fromOffset(maxX - minX, maxY - minY)
			box.Visible = true
		end
		local skeletonStyle = styleOf(tab.Mode, "Main/Skeleton")
		for _, line in ipairs(skeletonLines) do
			local a, b = project(line.A.Position), project(line.B.Position)
			line.Frame.Visible = a ~= nil and b ~= nil
			line.Frame.BackgroundColor3 = skeletonStyle.Color
			if a and b then
				local d = b - a
				line.Frame.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
				line.Frame.Size = UDim2.fromOffset(d.Magnitude, skeletonStyle.Thickness)
				line.Frame.Rotation = math.deg(math.atan2(d.Y, d.X))
			end
		end
		refreshEsp()
	end
	stage:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutOverlay)

	local function applyChams()
		if not model then
			return
		end
		local c = chams[tab.Mode]
		for part, orig in pairs(originals) do
			if c.Material then
				part.Material = c.Material
				part.Color = c.Color
			else
				part.Material = orig.Material
				part.Color = orig.Color
			end
		end
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("Decal") then
				d.Transparency = if c.Material then 1 else 0
			end
		end
		-- clothing paints over part colour, so it is moved out while chams are on
		if c.Material then
			for _, d in ipairs(model:GetChildren()) do
				if d:IsA("Clothing") or d:IsA("ShirtGraphic") then
					d.Parent = viewport
				end
			end
		else
			for _, d in ipairs(viewport:GetChildren()) do
				if d:IsA("Clothing") or d:IsA("ShirtGraphic") then
					d.Parent = model
				end
			end
		end
	end

	local function load(character)
		if model then
			model:Destroy()
			model = nil
		end
		for _, d in ipairs(viewport:GetChildren()) do
			if d:IsA("Clothing") or d:IsA("ShirtGraphic") then
				d:Destroy()
			end
		end
		for _, line in ipairs(skeletonLines) do
			line.Frame:Destroy()
		end
		skeletonLines = {}
		originals = {}
		extents = nil
		status.Text = "Loading character..."
		status.Visible = true
		layoutOverlay()

		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not root or not character.Parent then
			status.Text = "No character"
			return
		end
		task.wait(0.5) -- accessories and clothing arrive slightly after the root part

		local wasArchivable = character.Archivable
		character.Archivable = true
		local ok, clone = pcall(function()
			return character:Clone()
		end)
		character.Archivable = wasArchivable
		if not ok or not clone then
			status.Text = "No character"
			return
		end

		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("ForceField") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
				originals[d] = { Material = d.Material, Color = d.Color }
			end
		end
		local humanoid = clone:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		local hrp = clone:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.Transparency = 1
			originals[hrp] = nil
		end

		clone:PivotTo(CFrame.new(clone:GetPivot().Position))
		local center, size = clone:GetBoundingBox()
		clone:TranslateBy(-center.Position)
		clone.Parent = worldModel
		model = clone
		extents = size

		for _, pair in ipairs(SKELETON) do
			local a, b = clone:FindFirstChild(pair[1]), clone:FindFirstChild(pair[2])
			if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
				table.insert(skeletonLines, {
					A = a,
					B = b,
					Frame = create("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.new(1, 1, 1),
						BorderSizePixel = 0,
						Parent = skeletonFolder,
					}),
				})
			end
		end

		status.Visible = false
		applyChams()
		layoutOverlay()
	end

	if player.Character then
		task.spawn(load, player.Character)
	end
	player.CharacterAdded:Connect(load)

	------------------------------------------------------------------
	-- Settings popup of one item (colour, thickness, text size, ...), one per mode and item
	------------------------------------------------------------------
	local panels = {}
	local function itemTitle(key)
		return if key == "Flags" then "Flags" else (string.match(key, "/(.+)$") or key)
	end

	openSettings = function(key, anchor)
		local mode = tab.Mode
		local id = mode .. "|" .. key
		local panel = panels[id]
		if not panel then
			local section
			panel, section = newPanel(window, 250, itemTitle(key), nil)
			local function changed()
				layoutOverlay()
				if not model then
					refreshEsp()
				end
			end
			local function notify(k, s)
				if opts.OnStyle then
					task.spawn(opts.OnStyle, mode, k, table.clone(s))
				end
			end
			if key == "Flags" then
				for _, flagKey in ipairs(flagKeys) do
					local s = styleOf(mode, flagKey)
					section:AddColorPicker(itemTitle(flagKey), s.Color, function(c)
						s.Color = c
						changed()
						notify(flagKey, s)
					end)
				end
			else
				local s = styleOf(mode, key)
				local function set(field)
					return function(v)
						s[field] = v
						changed()
						notify(key, s)
					end
				end
				section:AddColorPicker("Color", s.Color, set("Color"))
				if s.Thickness then
					section:AddSlider("Thickness", 1, 6, s.Thickness, set("Thickness"), "px")
				end
				if s.Size then
					section:AddSlider("Text Size", 9, 20, s.Size, set("Size"), "px")
				end
				if s.IconSize then
					section:AddSlider("Icon Size", 50, 300, s.IconSize, set("IconSize"), "%")
				end
				if s.Outline ~= nil then
					section:AddToggle("Outline", s.Outline, set("Outline"))
				end
				if s.ShowValue ~= nil then
					section:AddToggle("Show Value", s.ShowValue, set("ShowValue"))
				end
				if s.Fill ~= nil then
					section:AddToggle("Fill", s.Fill, set("Fill"))
				end
			end
			panels[id] = panel
		end
		window:ShowPopup(anchor, panel, true, "side")
	end

	box.MouseButton1Click:Connect(function()
		if on("Main/Bounding Box") then
			openSettings("Main/Bounding Box", box)
		end
	end)

	------------------------------------------------------------------
	-- ESP Items popup: group cards with chips, per mode
	-- left click: on / off; right click: settings of that item
	------------------------------------------------------------------
	local PANEL_W, CHIP_H, CHIP_GAP = 300, 24, 6
	local innerWidth = PANEL_W - 16 - 16
	local itemsPanel = create("Frame", {
		Size = UDim2.fromOffset(PANEL_W, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.PopupBg,
		Active = true,
		ZIndex = 2,
		Visible = false,
		Parent = window.Overlay,
	}, { corner(10), litStroke(Theme.PopupLitTop, Theme.PopupLitBottom), list(8), padding(10, 8, 8, 8) })
	textLabel({
		Text = "ESP Items",
		Size = UDim2.new(1, 0, 0, 22),
		FontFace = Theme.FontBold,
		TextSize = 15,
		TextColor3 = Theme.Text,
		LayoutOrder = 0,
		Parent = itemsPanel,
	}, { padding(0, 0, 0, 4) })

	local chips = {}
	local function renderChips()
		for _, chip in ipairs(chips) do
			local active = on(chip.Key)
			chip.Button.BackgroundColor3 = if active then Theme.AccentSoft else Theme.PopupCard
			chip.Button.TextColor3 = if active then Theme.Accent else Theme.TabText
			chip.Stroke.Color = if active then Theme.Accent else Theme.ElementStroke
			chip.Stroke.Transparency = if active then 0.4 else 0
		end
	end

	for gi, group in ipairs(espItems) do
		local groupName, items = group[1], group[2]
		local x, y = 0, 0
		local placements = {}
		for _, item in ipairs(items) do
			local w = math.ceil(textWidth(item, 13)) + 18
			if x > 0 and x + w > innerWidth then
				x = 0
				y += CHIP_H + CHIP_GAP
			end
			table.insert(placements, { item, x, y, w })
			x += w + CHIP_GAP
		end
		local chipsHeight = y + CHIP_H
		local card = create("Frame", {
			Size = UDim2.new(1, 0, 0, 32 + chipsHeight + 10),
			BackgroundColor3 = Theme.PopupCard,
			LayoutOrder = gi,
			Parent = itemsPanel,
		}, { corner(8), stroke(Theme.PopupCardStroke) })
		textLabel({
			Text = groupName,
			Position = UDim2.fromOffset(10, 8),
			Size = UDim2.new(1, -20, 0, 18),
			FontFace = Theme.FontBold,
			TextSize = 13,
			TextColor3 = Theme.Text,
			Parent = card,
		})
		local area = create("Frame", {
			Position = UDim2.fromOffset(8, 32),
			Size = UDim2.new(1, -16, 0, chipsHeight),
			BackgroundTransparency = 1,
			Parent = card,
		})
		for _, pl in ipairs(placements) do
			local key = groupName .. "/" .. pl[1]
			local b = create("TextButton", {
				Text = pl[1],
				FontFace = Theme.Font,
				TextSize = 13,
				TextColor3 = Theme.TabText,
				AutoButtonColor = false,
				Position = UDim2.fromOffset(pl[2], pl[3]),
				Size = UDim2.fromOffset(pl[4], CHIP_H),
				BackgroundColor3 = Theme.PopupCard,
				Parent = area,
			}, { corner(6) })
			local s = stroke(Theme.ElementStroke)
			s.Parent = b
			table.insert(chips, { Key = key, Button = b, Stroke = s })
			b.MouseButton1Click:Connect(function()
				local st = espState[tab.Mode]
				st[key] = not st[key]
				renderChips()
				refreshEsp()
				if opts.OnItem then
					task.spawn(opts.OnItem, tab.Mode, key, st[key] == true)
				end
			end)
			b.MouseButton2Click:Connect(function()
				openSettings(key, b)
			end)
		end
	end
	textLabel({
		Text = "Right-click an item for its settings, drag it in the preview to move it",
		Size = UDim2.new(1, 0, 0, 16),
		TextSize = 11,
		TextColor3 = Theme.SubText,
		TextWrapped = true,
		LayoutOrder = #espItems + 1,
		Parent = itemsPanel,
	}, { padding(0, 0, 0, 4) })

	------------------------------------------------------------------
	-- Presets: chips, styles and layout of every mode
	------------------------------------------------------------------
	local function encodeStyles(mode)
		local out = {}
		for key, s in pairs(styles[mode]) do
			local copy = table.clone(s)
			copy.Color = { s.Color.R, s.Color.G, s.Color.B }
			out[key] = copy
		end
		return HttpService:JSONEncode(out)
	end
	local function decodeStyles(mode, json)
		local ok, data = pcall(function()
			return HttpService:JSONDecode(json)
		end)
		if not ok or type(data) ~= "table" then
			return
		end
		styles[mode] = {}
		for key, s in pairs(data) do
			if type(s) == "table" then
				local style = defaultEspStyle(key)
				for field, value in pairs(s) do
					if field == "Color" and type(value) == "table" then
						style.Color = Color3.new(value[1] or 1, value[2] or 1, value[3] or 1)
					elseif style[field] ~= nil and type(value) == type(style[field]) then
						style[field] = value
					end
				end
				styles[mode][key] = style
			end
		end
		-- popups show the old values: rebuild them on next open
		for id, panel in pairs(panels) do
			if string.sub(id, 1, #mode + 1) == mode .. "|" then
				panel:Destroy()
				panels[id] = nil
			end
		end
	end

	for _, m in ipairs(modes) do
		local mName = m.Name
		for _, group in ipairs(espItems) do
			for _, item in ipairs(group[2]) do
				local key = group[1] .. "/" .. item
				local entryApi = {}
				function entryApi:Get()
					return espState[mName][key] == true
				end
				function entryApi:Set(v)
					espState[mName][key] = v == true
					renderChips()
					refreshEsp()
					if opts.OnItem then
						task.spawn(opts.OnItem, mName, key, v == true)
					end
				end
				window:_register(tabPath .. "/ESP Items/" .. mName .. "/" .. key, "toggle", entryApi)
			end
		end

		local layoutApi = {}
		function layoutApi:Get()
			return HttpService:JSONEncode(layouts[mName])
		end
		function layoutApi:Set(json)
			local ok, data = pcall(function()
				return HttpService:JSONDecode(json)
			end)
			if ok and type(data) == "table" then
				for key, e in pairs(data) do
					if layouts[mName][key] and type(e) == "table" and table.find(ESP_SIDES, e.Side) then
						layouts[mName][key] = { Side = e.Side, Order = tonumber(e.Order) or 1 }
					end
				end
				normalize(mName)
				refreshEsp()
			end
		end
		window:_register(tabPath .. "/ESP Items/" .. mName .. "/@Layout", "value", layoutApi)

		local styleApi = {}
		function styleApi:Get()
			return encodeStyles(mName)
		end
		function styleApi:Set(json)
			decodeStyles(mName, json)
			layoutOverlay()
			refreshEsp()
		end
		window:_register(tabPath .. "/ESP Items/" .. mName .. "/@Style", "value", styleApi)
	end

	itemsButton.MouseButton1Click:Connect(function()
		renderChips()
		window:ShowPopup(itemsButton, itemsPanel, true)
	end)

	------------------------------------------------------------------
	-- Expand: the preview takes the whole page
	------------------------------------------------------------------
	local expanded = false
	expandButton.MouseButton1Click:Connect(function()
		expanded = not expanded
		window:ClosePopup()
		tab.Left.Visible = not expanded
		tab.Expanded = expanded
		tab._layoutColumns()
		for _, c in ipairs(tab.Right:GetChildren()) do
			if c:IsA("GuiObject") and c ~= frame then
				c.Visible = not expanded
			end
		end
		frame.Size = UDim2.new(1, 0, 0, if expanded then baseHeight + 80 else baseHeight)
		setIconColor(expandIcon, if expanded then Theme.Accent else Theme.TextDim)
	end)

	------------------------------------------------------------------
	-- Modes
	------------------------------------------------------------------
	local function setMode(index)
		tab.Mode = modes[index].Name
		for i, v in ipairs(modeViews) do
			local active = i == index
			v.Label.Visible = active
			setIconColor(v.Icon, if active then Theme.Accent else Theme.TextDim)
		end
		tab:_applyMode()
		applyChams()
		layoutOverlay()
		refreshEsp()
		renderChips()
		if opts.OnMode then
			task.spawn(opts.OnMode, tab.Mode)
		end
	end
	for i, v in ipairs(modeViews) do
		v.Button.MouseButton1Click:Connect(function()
			window:ClosePopup()
			setMode(i)
		end)
	end
	setMode(1)

	local api = {}
	-- material: "Disabled" | "Neon" | "Flat" | "ForceField" | "Glass"; mode defaults to the first mode
	function api:SetChams(material, color, mode)
		local c = chams[mode or modes[1].Name]
		if not c then
			return
		end
		c.Material = CHAMS_MATERIALS[material]
		c.Color = color or c.Color
		applyChams()
	end
	function api:GetMode()
		return tab.Mode
	end
	function api:GetItems(mode)
		return table.clone(espState[mode or tab.Mode] or {})
	end
	-- { [elementKey] = { Side = "Top" | "Bottom" | "Left" | "Right", Order = n } }
	function api:GetLayout(mode)
		return table.clone(layouts[mode or tab.Mode])
	end
	function api:GetStyle(key, mode)
		return table.clone(styleOf(mode or tab.Mode, key))
	end
	return api
end

------------------------------------------------------------------
-- Sections
------------------------------------------------------------------
-- mode: optional preview mode name ("Enemies" / "Teammates"); the section shows only in that mode
function Tab:AddSection(name, side, mode)
	local column = if side == "Right" then self.Right else self.Left

	local wrap = create("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		LayoutOrder = #column:GetChildren(),
		Parent = column,
	}, { list(9) })

	textLabel({
		Text = string.upper(name),
		Size = UDim2.new(1, 0, 0, 14),
		TextSize = 12,
		FontFace = Theme.Font,
		TextColor3 = Theme.SubText,
		LayoutOrder = 1,
		Parent = wrap,
	}, { padding(0, 0, 0, 14) })

	local box = create("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = Theme.Section,
		LayoutOrder = 2,
		Parent = wrap,
	}, { corner(12), litStroke(Theme.SectionLitTop, Theme.SectionStroke), list(0), padding(1, 0, 1, 0) })

	local section = newSection(box, self.Window, { Bg = Theme.Section })
	section.Wrap = wrap
	section.Path = (if self.Parent then self.Parent.Name .. "/" else "") .. self.Name .. "/" .. name
	section.Mode = mode
	if mode and self.Mode and mode ~= self.Mode then
		wrap.Visible = false
	end
	table.insert(self.Sections, section)
	return section
end

function Section:AddGroup()
	assert(self._addGroup, "AddGroup works only on popup sections")
	return self._addGroup()
end

-- Rows of sections without a Path (profile popup) are not part of presets
function Section:_register(name, kind, api, row, meta)
	if self.Path and name then
		self.Window:_register(self.Path .. "/" .. name, kind, api, row, meta, name)
	end
end

function Section:_childPath(name)
	return if self.Path and name then self.Path .. "/" .. name else nil
end

-- text: "Name" or { "Name", "icon" }. Returns row, label, name.
function Section:_row(text, hideLabel)
	local name, iconName = text, nil
	if type(text) == "table" then
		name, iconName = text[1], text[2]
	end
	self._n += 1
	local row = create("Frame", {
		Size = UDim2.new(1, 0, 0, self.RowH),
		BackgroundTransparency = 1,
		LayoutOrder = self._n,
		Parent = self.Box,
	})
	trackPointer(row)
	if self._n > 1 and not self.Compact then
		create("Frame", {
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -24, 0, 1),
			BackgroundColor3 = Theme.Divider,
			BorderSizePixel = 0,
			Parent = row,
		})
	end
	local x = if self.Compact then 12 else 16
	if iconName and Icons[iconName] then
		Icons[iconName](row, Theme.TabText, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, x, 0.5, 0),
		})
		x += 26
	end
	local label
	if name and not hideLabel then
		label = textLabel({
			Text = name,
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.new(0.5, -x, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
	end
	table.insert(self.Rows, { Frame = row, Text = name })
	return row, label, name
end

-- Grey cover over a row that swallows input; returns setter(disabled)
function Section:_disabler(row)
	local cover = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = self.Bg,
		BackgroundTransparency = 0.45,
		Visible = false,
		ZIndex = 5,
		Parent = row,
	})
	return function(disabled)
		cover.Visible = disabled == true
	end
end

-- Value selector: boxed button in sections, "Value >" text in popups
function Section:_valueButton(row)
	if not self.Compact then
		return selectButton(row, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.new(0.46, 0, 0, 27),
		})
	end
	local button = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0.5, 0, 1, -6),
		BackgroundTransparency = 1,
		Parent = row,
	})
	local value = textLabel({
		Size = UDim2.new(1, -14, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 13,
		TextColor3 = Theme.TabText,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = button,
	})
	chevron(button, UDim2.new(1, 2, 0.5, 0), -90)
	button.MouseEnter:Connect(function()
		tween(value, { TextColor3 = Theme.Text })
	end)
	button.MouseLeave:Connect(function()
		tween(value, { TextColor3 = Theme.TabText })
	end)
	return button, value
end

-- Toggle
function Section:AddToggle(text, default, callback)
	local row, label, name = self:_row(text)
	local labelX = label.Position.X.Offset
	label.Size = UDim2.new(1, -110, 1, 0)
	local state = default == true
	local window = self.Window
	local section = self

	local switch = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(36, 20),
		BackgroundColor3 = Theme.SwitchOff,
		Parent = row,
	}, { corner(10) })

	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Theme.KnobOff,
		Parent = switch,
	}, { corner(8) })

	local function render(time)
		local t = time or 0.22
		TweenService:Create(switch, TweenInfo.new(t, Enum.EasingStyle.Quint), {
			BackgroundColor3 = if state then Theme.Accent else Theme.SwitchOff,
		}):Play()
		TweenService:Create(knob, TweenInfo.new(t, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = if state then UDim2.new(1, -10, 0.5, 0) else UDim2.new(0, 10, 0.5, 0),
			Size = if state then UDim2.fromOffset(16, 16) else UDim2.fromOffset(14, 14),
			BackgroundColor3 = if state then Color3.new(1, 1, 1) else Theme.KnobOff,
		}):Play()
	end
	switch.MouseEnter:Connect(function()
		if not state then
			tween(knob, { BackgroundColor3 = Theme.TabText })
		end
	end)
	switch.MouseLeave:Connect(function()
		if not state then
			tween(knob, { BackgroundColor3 = Theme.KnobOff })
		end
	end)

	-- Add-ons left of the switch: colour swatches sit next to it, the "..." button further left
	local addons = {}
	local function layoutAddons()
		local x = -58
		for _, kind in ipairs({ "color", "settings" }) do
			for _, a in ipairs(addons) do
				if a.Kind == kind then
					a.Frame.Position = UDim2.new(1, x, 0.5, 0)
					x -= a.Width
				end
			end
		end
		label.Size = UDim2.new(1, x - 4 - labelX, 1, 0)
	end

	local api = {}
	function api:Set(v)
		state = v
		render()
		if callback then
			task.spawn(callback, state)
		end
	end
	function api:Get()
		return state
	end
	api.SetDisabled = (function(set)
		return function(_, v)
			set(v)
		end
	end)(self:_disabler(row))

	function api:AddSettings(width, title)
		local dots = create("TextButton", {
			Text = "",
			AutoButtonColor = false,
			AnchorPoint = Vector2.new(1, 0.5),
			Size = UDim2.fromOffset(22, 22),
			BackgroundColor3 = Theme.Hover,
			BackgroundTransparency = 1,
			Parent = row,
		}, { corner(5) })
		for i = -1, 1 do
			create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, i * 5, 0.5, 0),
				Size = UDim2.fromOffset(3, 3),
				BackgroundColor3 = Theme.TabText,
				BorderSizePixel = 0,
				Parent = dots,
			}, { corner(2) })
		end
		dots.MouseEnter:Connect(function()
			tween(dots, { BackgroundTransparency = 0.3 })
		end)
		dots.MouseLeave:Connect(function()
			tween(dots, { BackgroundTransparency = 1 })
		end)
		table.insert(addons, { Kind = "settings", Frame = dots, Width = 28 })
		layoutAddons()

		local panel, panelSection = newPanel(window, width or 270, title or name, section:_childPath(name))
		dots.MouseButton1Click:Connect(function()
			window:ShowPopup(dots, panel, true, "side")
		end)
		return panelSection
	end

	function api:AddColor(color, colorCallback, alpha)
		local picker, swatch = addSwatch(window, row, UDim2.new(1, -58, 0.5, 0), color or Color3.new(1, 1, 1), alpha, colorCallback)
		table.insert(addons, { Kind = "color", Frame = swatch, Width = 22 })
		layoutAddons()
		section:_register(name .. ":color", "color", picker)
		return picker
	end

	switch.MouseButton1Click:Connect(function()
		api:Set(not state)
	end)
	self:_register(name, "toggle", api, row, { Type = "toggle" })

	render(0)
	if callback then
		task.spawn(callback, state)
	end
	return api
end

-- Slider. opts: Decimals (number of digits after the dot), Format(value) -> string or nil
function Section:AddSlider(text, min, max, default, callback, suffix, opts)
	opts = opts or {}
	local row, label, name = self:_row(text)
	local section, window = self, self.Window
	local compact = self.Compact
	local decimals = opts.Decimals or 0
	local step = 10 ^ -decimals
	local value = math.clamp(default or min, min, max)

	local function round(v)
		return math.clamp(math.floor(v / step + 0.5) * step, min, max)
	end
	local function display(v)
		if opts.Format then
			local s = opts.Format(v)
			if s then
				return s
			end
		end
		return string.format("%." .. decimals .. "f", v) .. (suffix or "")
	end

	local valueLabel
	if compact then
		label.Size = UDim2.new(0.5, -label.Position.X.Offset, 1, 0)
	else
		label.Size = UDim2.new(0.58, -(label.Position.X.Offset + 60), 1, 0)
		local valueBox = create("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(46, 24),
			BackgroundColor3 = Theme.ValueBox,
			Parent = row,
		}, { corner(6), stroke(Theme.ElementStroke) })
		valueLabel = textLabel({
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = 12,
			Parent = valueBox,
		})
	end

	local hit = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = if compact then UDim2.new(1, -14, 0.5, 0) else UDim2.new(1, -70, 0.5, 0),
		Size = if compact then UDim2.new(0.42, 0, 0, 16) else UDim2.new(0.38, 0, 0, 16),
		BackgroundTransparency = 1,
		Parent = row,
	})
	local bar = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, if compact then 4 else 3),
		BackgroundColor3 = Theme.SliderTrack,
		BorderSizePixel = 0,
		Parent = hit,
	}, { corner(2) })
	local fillBar = create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = bar,
	}, { corner(2) })
	local knobSize = if compact then 10 else 13
	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(knobSize, knobSize),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = hit,
	}, { corner(7) })
	-- popups have no value box: a bubble above the knob shows the value on hover / drag
	local bubble
	if compact then
		bubble = textLabel({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0, -4),
			Size = UDim2.fromOffset(44, 18),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 0,
			BackgroundColor3 = Theme.Element,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = 11,
			Visible = false,
			ZIndex = 3,
			Parent = knob,
		}, { corner(4), padding(0, 4, 0, 4) })
	end

	local function render()
		local a = (value - min) / (max - min)
		fillBar.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.fromScale(a, 0.5)
		if valueLabel then
			valueLabel.Text = display(value)
		end
		if bubble then
			bubble.Text = display(value)
		end
	end

	local api = {}
	function api:Set(v)
		value = round(v)
		render()
		if callback then
			task.spawn(callback, value)
		end
	end
	function api:Get()
		return value
	end
	api.SetDisabled = (function(set)
		return function(_, v)
			set(v)
		end
	end)(self:_disabler(row))

	local dragging, hovering = false, false
	local function update(x)
		local a = math.clamp((x - hit.AbsolutePosition.X) / hit.AbsoluteSize.X, 0, 1)
		local new = round(min + (max - min) * a)
		if new ~= value then
			api:Set(new)
		end
	end
	local function showBubble()
		if bubble then
			bubble.Visible = dragging or hovering
		end
	end

	hit.MouseEnter:Connect(function()
		hovering = true
		showBubble()
	end)
	hit.MouseLeave:Connect(function()
		hovering = false
		showBubble()
	end)
	hit.InputBegan:Connect(function(input)
		if isClick(input) then
			dragging = true
			tween(knob, { Size = UDim2.fromOffset(knobSize + 3, knobSize + 3) })
			update(input.Position.X)
			showBubble()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if isClick(input) and dragging then
			dragging = false
			tween(knob, { Size = UDim2.fromOffset(knobSize, knobSize) })
			showBubble()
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and isMove(input) then
			update(input.Position.X)
		end
	end)

	-- colour swatch left of the track ("Blur Weight 1 [■] ━━━")
	function api:AddColor(color, colorCallback, alpha)
		local x = label.Position.X.Offset
		local position
		if compact then
			label.Size = UDim2.new(0.58, -(x + 40), 1, 0)
			position = UDim2.new(0.58, -22, 0.5, 0)
		else
			label.Size = UDim2.new(0.62, -(x + 100), 1, 0)
			position = UDim2.new(0.62, -78, 0.5, 0)
		end
		local picker = addSwatch(window, row, position, color or Color3.new(1, 1, 1), alpha, colorCallback)
		section:_register(name .. ":color", "color", picker)
		return picker
	end

	value = round(value)
	render()
	if callback then
		task.spawn(callback, value)
	end
	self:_register(name, "value", api, row, { Type = "slider", Min = min, Max = max, Suffix = suffix, Opts = opts })
	return api
end

-- Dropdown (single choice)
function Section:AddDropdown(text, options, default, callback)
	local row, label, name = self:_row(text)
	local section = self
	label.Size = if self.Compact
		then UDim2.new(0.5, -label.Position.X.Offset, 1, 0)
		else UDim2.new(0.54, -(label.Position.X.Offset + 14), 1, 0)
	local window = self.Window
	local value = default or options[1]

	local button, valueLabel = self:_valueButton(row)

	local api = {}
	function api:Set(v)
		value = v
		valueLabel.Text = tostring(v)
		if callback then
			task.spawn(callback, v)
		end
	end
	function api:Get()
		return value
	end
	api.SetDisabled = (function(set)
		return function(_, v)
			set(v)
		end
	end)(self:_disabler(row))
	-- colour swatch left of the selector (as in "Player [■] [Neon ⌄]")
	function api:AddColor(color, colorCallback, alpha)
		local x = label.Position.X.Offset
		local position
		if section.Compact then
			label.Size = UDim2.new(0.5, -(x + 30), 1, 0)
			position = UDim2.new(0.5, -18, 0.5, 0)
		else
			label.Size = UDim2.new(0.54, -(x + 34), 1, 0)
			position = UDim2.new(0.54, -22, 0.5, 0)
		end
		local picker = addSwatch(window, row, position, color or Color3.new(1, 1, 1), alpha, colorCallback)
		section:_register(name .. ":color", "color", picker)
		return picker
	end

	button.MouseButton1Click:Connect(function()
		window:_openSelect(button, options, function(o)
			return o == value
		end, function(o)
			api:Set(o)
		end, false)
	end)

	api:Set(value)
	self:_register(name, "value", api, row, { Type = "dropdown", Options = options })
	return api
end

-- Dropdown (several choices)
-- icons: optional { [option] = iconName } shown in the open list
function Section:AddMultiDropdown(text, options, defaults, callback, icons)
	local row, label, name = self:_row(text)
	label.Size = if self.Compact
		then UDim2.new(0.5, -label.Position.X.Offset, 1, 0)
		else UDim2.new(0.54, -(label.Position.X.Offset + 14), 1, 0)
	local window = self.Window
	local selected = {}
	for _, o in ipairs(defaults or {}) do
		selected[o] = true
	end

	local button, valueLabel = self:_valueButton(row)

	local function getList()
		local t = {}
		for _, o in ipairs(options) do
			if selected[o] then
				table.insert(t, o)
			end
		end
		return t
	end

	local function changed()
		local t = getList()
		valueLabel.Text = if #t == 0 then "Select" else table.concat(t, ", ")
		if callback then
			task.spawn(callback, t)
		end
	end

	local api = {}
	function api:Set(t)
		selected = {}
		for _, o in ipairs(t) do
			selected[o] = true
		end
		changed()
	end
	function api:Get()
		return getList()
	end
	api.SetDisabled = (function(set)
		return function(_, v)
			set(v)
		end
	end)(self:_disabler(row))

	button.MouseButton1Click:Connect(function()
		window:_openSelect(button, options, function(o)
			return selected[o] == true
		end, function(o)
			selected[o] = if selected[o] then nil else true
			changed()
		end, true, icons)
	end)

	changed()
	self:_register(name, "multi", api, row)
	return api
end

-- Colour row (label + swatch)
function Section:AddColorPicker(text, color, callback, alpha)
	local row, label, name = self:_row(text)
	label.Size = UDim2.new(1, -(label.Position.X.Offset + 44), 1, 0)
	local picker = addSwatch(self.Window, row, UDim2.new(1, -14, 0.5, 0), color or Color3.new(1, 1, 1), alpha, callback)
	picker.SetDisabled = (function(set)
		return function(_, v)
			set(v)
		end
	end)(self:_disabler(row))
	self:_register(name, "color", picker, row)

	-- Dark / light switch left of the swatch: sun in dark mode, moon on a pill in light mode
	local window = self.Window
	function picker:AddThemeToggle()
		label.Size = UDim2.new(1, -(label.Position.X.Offset + 76), 1, 0)
		local button = create("TextButton", {
			Text = "",
			AutoButtonColor = false,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -36, 0.5, 0),
			Size = UDim2.fromOffset(26, 22),
			BackgroundColor3 = Theme.Element,
			BackgroundTransparency = 1,
			Parent = row,
		}, { corner(11) })
		local icon
		local function render()
			if icon then
				icon:Destroy()
			end
			local light = window.ThemeMode == "Light"
			button.BackgroundTransparency = if light then 0 else 1
			icon = (if light then Icons.moon else Icons.sun)(button, Theme.TabText, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
			})
		end
		button.MouseButton1Click:Connect(function()
			window:SetThemeMode(if window.ThemeMode == "Light" then "Dark" else "Light")
			if window._menuColorPicker then
				window._syncingMenuColor = true
				window._menuColorPicker:Set(Theme.Window)
				window._syncingMenuColor = false
			end
			render()
		end)
		render()
		return button
	end

	return picker
end

-- Keybind row: click, then press a key (Escape clears). Bound keys show in the Hotkeys window.
-- hideFromHud: do not list the key in the Hotkeys window
function Section:AddKeybind(text, default, callback, hideFromHud)
	local row, label, name = self:_row(text)
	label.Size = UDim2.new(0.54, -(label.Position.X.Offset + 14), 1, 0)
	local window = self.Window
	local key = default
	local listening = false

	local button = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.new(0.46, 0, 0, 27),
		BackgroundColor3 = Theme.Element,
		Parent = row,
	}, { corner(6), stroke(Theme.ElementStroke) })
	local valueLabel = textLabel({
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 13,
		Parent = button,
	})

	local function render()
		valueLabel.Text = if listening then "..." elseif key then key.Name else "None"
		valueLabel.TextColor3 = if listening then Theme.Accent else Theme.TextDim
		if not hideFromHud then
			window:SetHotkey(name, if key then key.Name else nil)
		end
	end

	local api = {}
	function api:Get()
		return key
	end
	function api:Set(k)
		key = k
		render()
		if callback then
			task.spawn(callback, key)
		end
	end
	api.SetDisabled = (function(set)
		return function(_, v)
			set(v)
		end
	end)(self:_disabler(row))

	button.MouseButton1Click:Connect(function()
		listening = true
		window._capturing = true
		render()
	end)
	UserInputService.InputBegan:Connect(function(input)
		if not listening or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		listening = false
		window._capturing = false
		window._captureEnd = os.clock()
		api:Set(if input.KeyCode == Enum.KeyCode.Escape then nil else input.KeyCode)
	end)

	render()
	self:_register(name, "keybind", api, row)
	return api
end

-- Row with ">" that opens a popup beside it; returns the popup's section
function Section:AddNav(text, width)
	local row, label, name = self:_row(text)
	label.Size = UDim2.new(1, -(label.Position.X.Offset + 34), 1, 0)
	chevron(row, UDim2.new(1, -14, 0.5, 0), -90)
	local window = self.Window

	local button = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = row,
	})
	button.MouseEnter:Connect(function()
		tween(label, { TextColor3 = Theme.Text })
	end)
	button.MouseLeave:Connect(function()
		tween(label, { TextColor3 = Theme.TextDim })
	end)

	local panel, panelSection = newPanel(window, width or 270, name, self:_childPath(name))
	button.MouseButton1Click:Connect(function()
		window:ShowPopup(row, panel, true, "side")
	end)
	return panelSection
end

function Section:AddLabel(text)
	local _, label = self:_row(text)
	label.Size = UDim2.new(1, -(label.Position.X.Offset + 14), 1, 0)
	label.TextColor3 = Theme.SubText
	return label
end

function Section:AddButton(text, callback)
	local row = self:_row(text, true)
	local name = if type(text) == "table" then text[1] else text
	local button = create("TextButton", {
		Text = name,
		FontFace = Theme.Font,
		TextSize = 14,
		TextColor3 = Theme.TextDim,
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.new(1, -24, 0, 28),
		BackgroundColor3 = Theme.Element,
		Parent = row,
	}, { corner(6), stroke(Theme.ElementStroke) })
	button.MouseEnter:Connect(function()
		tween(button, { BackgroundColor3 = Theme.Hover })
	end)
	button.MouseLeave:Connect(function()
		tween(button, { BackgroundColor3 = Theme.Element })
	end)
	button.MouseButton1Click:Connect(function()
		if callback then
			task.spawn(callback)
		end
	end)
end

------------------------------------------------------------------
-- Spectator list. NOT MEASURED: which players watch the local player. The game keeps its own spectate state only for
-- the local player (PlayerGui.GUI.Spectate.Current = who YOU watch); nothing seen in the dump or the recording says
-- who watches you. Until that is measured the list shows players who COULD be watching and marks them "(?)":
--   * dead players on your team (Status.Alive == false, same Status.Team as yours, CT or T),
--   * players on the Spectator team (Status.Team == "Spectator").
------------------------------------------------------------------
-- Unload: every engine adds a function here; the "Unload" button in the profile popup runs them (the menu last).
local Unloaders = {}

local SpectatorList = {}
do
	local logLine

	local function statusOf(plr)
		local status = plr:FindFirstChild("Status")
		local team = status and status:FindFirstChild("Team")
		local alive = status and status:FindFirstChild("Alive")
		local teamName = if team and team:IsA("StringValue") then team.Value else nil
		local isAlive = if alive and alive:IsA("BoolValue") then alive.Value else nil -- false must stay false
		return teamName, isAlive
	end

	-- the guess above is OFF: the list stays empty until the real "who watches me" data is found
	local USE_GUESS = false

	function SpectatorList.Get()
		local names = {}
		if not USE_GUESS then
			return names
		end
		local myTeam = statusOf(player)
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= player then
				local team, alive = statusOf(plr)
				if team == "Spectator" or (alive == false and myTeam ~= nil and team == myTeam and (team == "CT" or team == "T")) then
					table.insert(names, plr.DisplayName .. " (?)")
				end
			end
		end
		table.sort(names)
		return names
	end

	function SpectatorList.SetLog(fn)
		logLine = fn
	end

end

------------------------------------------------------------------
-- Loader. Nothing below this point (the menu, the engines, the hooks, the "loading textures" toast) runs until Inject was pressed
-- here; closing the loader ends the script. It follows the look of the menu (Theme colours, the same layered shadow) and has
-- three screens: the subscription list, the product window (info + update log + Inject) and the inject animation.
-- Product data: the name, "Lifetime" (the menu's own footer text), the update log (the real changes of this project) and the
-- last launch time (kept in <workspace>/NeverloseBloxStrike/loader.json). Website / Support / Market have no address yet.
------------------------------------------------------------------
if not (function()
	local Lighting = game:GetService("Lighting")
	local GAME = "Counter Blox"
	local W, H = 460, 372 -- about a third of the menu's area
	local RELEASES = {
		{
			Date = "11.11.2026",
			Groups = {
				{
					"Added",
					{
						"Indicators on the left edge: Hit Chance, Min Damage, SLOW - with themes, shadows and animations",
						"Hit Sound and Shoot Sound with your own .mp3 / .ogg / .wav files",
						"Scope Zoom for snipers: first and second scope, x0 - x10",
						"Game Volume, Menu Color, Menu Transparency and a background setting for every window",
						"Damage Numbers, Hitboxes, Session Stats, Speedometer and Radar",
						"Grenade ESP, trajectory, smoke and inferno radius, Remove Flash / Smoke / Fog",
						"Manuals for anti aim: direction and keys",
						"Revolver auto fire on the right mouse button",
						"This loader",
					},
				},
				{
					"Changed",
					{
						"Hotkeys, Spectators and Watermark are transparent and cast shadows",
						"Configs keep window positions, the menu colour and the profile settings",
						"Behind Walls chams are drawn without Highlights",
					},
				},
				{
					"Fixed",
					{
						"Offscreen arrows",
						"The penetration indicator no longer lights up on floors",
					},
				},
				{
					"Removed",
					{
						"Debug probes and counters",
						"The Rapid Fire toggle",
					},
				},
			},
		},
		{
			Date = "09.11.2026",
			Groups = {
				{ "Added", { "First build: menu, enemy ESP, silent aim, anti aim, movement and world effects" } },
			},
		},
	}

	-- the update log as a flat list of lines for the scroll list: { Kind = "date" | "group" | "item", Text = ... }
	local function buildLogLines(releases)
		local lines = {}
		for _, release in ipairs(releases) do
			table.insert(lines, { Kind = "date", Text = release.Date })
			for _, group in ipairs(release.Groups) do
				table.insert(lines, { Kind = "group", Text = group[1] })
				for _, item in ipairs(group[2]) do
					table.insert(lines, { Kind = "item", Text = item })
				end
			end
		end
		return lines
	end
	local function formatLaunch(previous)
		if type(previous) ~= "number" then
			return "First launch"
		end
		return os.date("%d.%m.%Y %H:%M", previous)
	end
	local function loadingDots(t)
		return string.rep(".", math.floor(t * 3) % 4)
	end

	-- last launch, kept next to the presets
	local STORE_FILE = CONFIG_DIR .. "/loader.json"
	local fs = fileApi()
	local previousLaunch
	if fs then
		pcall(function()
			if fs.IsFile(STORE_FILE) then
				local data = HttpService:JSONDecode(fs.Read(STORE_FILE))
				if type(data) == "table" and type(data.LastLaunch) == "number" then
					previousLaunch = data.LastLaunch
				end
			end
		end)
	end
	local function rememberLaunch()
		if not fs then
			return
		end
		pcall(function()
			if type(fs.MakeFolder) == "function" and type(fs.IsFolder) == "function" and not fs.IsFolder(CONFIG_DIR) then
				fs.MakeFolder(CONFIG_DIR)
			end
			fs.Write(STORE_FILE, HttpService:JSONEncode({ LastLaunch = os.time() }))
		end)
	end

	local function parentGui()
		local ok, hidden = pcall(function()
			return gethui and gethui()
		end)
		if ok and typeof(hidden) == "Instance" then
			return hidden
		end
		local okCore, core = pcall(function()
			return game:GetService("CoreGui")
		end)
		if okCore then
			local probe = Instance.new("Folder")
			local writable = pcall(function()
				probe.Parent = core
			end)
			probe:Destroy()
			if writable then
				return core
			end
		end
		return player:WaitForChild("PlayerGui")
	end
	local function tw(object, props, time, style, direction)
		local info = TweenInfo.new(time or 0.2, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
		TweenService:Create(object, info, props):Play()
	end

	local result -- nil while open, true after Inject, false when closed
	local frameSteps = {} -- run every frame (spinner, shimmer)
	local gui = create("ScreenGui", {
		Name = "NeverloseLoader",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 2147483646,
		OnTopOfCoreBlur = true,
		Parent = parentGui(),
	})
	-- free the mouse (a Modal button) and keep it free every frame, like the menu does; the old values come back at the end
	local modal = create("TextButton", { Name = "CursorUnlock", Text = "", Modal = true, BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 0), Parent = gui })
	local cursorPrev = { Icon = UserInputService.MouseIconEnabled, Behavior = UserInputService.MouseBehavior }
	pcall(RunService.UnbindFromRenderStep, RunService, "NeverloseLoaderCursor")
	RunService:BindToRenderStep("NeverloseLoaderCursor", Enum.RenderPriority.Last.Value, function()
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end)
	local frameConn = RunService.RenderStepped:Connect(function(dt)
		for _, fn in ipairs(frameSteps) do
			fn(dt, os.clock())
		end
	end)
	local blur
	pcall(function()
		blur = Instance.new("BlurEffect")
		blur.Name = "NLLoaderBlur"
		blur.Size = 0
		blur.Parent = Lighting
		tw(blur, { Size = 12 }, 0.6)
	end)

	local dim = create("Frame", { Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Parent = gui })
	tw(dim, { BackgroundTransparency = 0.5 }, 0.5)
	local shadowLayer = create("Frame", { Name = "Shadows", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })

	-- the window sits in a frame that carries the screen fit, so the pop-up scale of the window itself does not fight it
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local fit = math.clamp(math.min(viewport.X / 700, viewport.Y / 560), 0.6, 1.5) * 0.82
	local holder = create("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { create("UIScale", { Scale = fit }) })
	local root = create("CanvasGroup", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Window,
		BackgroundTransparency = 0.02,
		GroupTransparency = 1,
		Parent = holder,
	}, { corner(16), litStroke(Theme.WindowLitTop, Theme.Deep) })
	local rootScale = create("UIScale", { Scale = 0.86, Parent = root })
	tw(root, { GroupTransparency = 0 }, 0.4)
	tw(rootScale, { Scale = 1 }, 0.55, Enum.EasingStyle.Back)

	-- the same layered shadow as the HUD windows and the indicators, following the window through its scale animation
	local shadowAlphas8 = shadowAlphas(0.85)
	local shadowFrames = {}
	for i = 1, #shadowAlphas8 do
		shadowFrames[i] = create("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = shadowLayer }, { corner(16 + i * 3) })
	end
	local function updateShadow()
		local rel = root.AbsolutePosition - shadowLayer.AbsolutePosition
		local size = root.AbsoluteSize
		local seen = 1 - root.GroupTransparency
		for i, f in ipairs(shadowFrames) do
			local o = i * 3 * fit * rootScale.Scale
			f.Position = UDim2.fromOffset(rel.X - o, rel.Y - o)
			f.Size = UDim2.fromOffset(size.X + o * 2, size.Y + o * 2)
			f.BackgroundTransparency = 1 - shadowAlphas8[i] * seen
		end
	end
	for _, prop in ipairs({ "AbsolutePosition", "AbsoluteSize", "GroupTransparency", "Visible" }) do
		root:GetPropertyChangedSignal(prop):Connect(updateShadow)
	end
	updateShadow()

	------------------------------------------------------------------
	-- Small drawing helpers (anti-aliased rounded frames and strokes, like the indicator icons)
	------------------------------------------------------------------
	local function disc(parent, x, y, d, color)
		return create("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(d, d), BackgroundColor3 = color, BorderSizePixel = 0, Parent = parent }, { corner(math.ceil(d / 2)) })
	end
	local function ring(parent, x, y, d, thick, color)
		local s = stroke(color, thick)
		create("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(d, d), BackgroundTransparency = 1, Parent = parent }, { corner(math.ceil(d / 2)), s })
		return s
	end
	local function bar(parent, cx, cy, w, h, rot, color)
		return create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(cx, cy),
			Size = UDim2.fromOffset(w, h),
			Rotation = rot or 0,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = parent,
		}, { corner(math.ceil(math.min(w, h) / 2)) })
	end
	-- the product picture (Counter Blox icon, 128x128 PNG as base64): written to the workspace once and loaded with getcustomasset
	local ICON_B64 = table.concat({
		"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",
	})
	local iconAssetId = nil
	local function iconAsset()
		if iconAssetId ~= nil then
			return iconAssetId or nil
		end
		iconAssetId = false
		pcall(function()
			if typeof(writefile) ~= "function" or typeof(getcustomasset) ~= "function" then
				return
			end
			local path = CONFIG_DIR .. "/counterblox_icon.png"
			if not (typeof(isfile) == "function" and isfile(path)) then
				if typeof(makefolder) == "function" and not (typeof(isfolder) == "function" and isfolder(CONFIG_DIR)) then
					makefolder(CONFIG_DIR)
				end
				local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
				local lookup = {}
				for i = 1, #alphabet do
					lookup[string.byte(alphabet, i)] = i - 1
				end
				local pieces = {}
				for i = 1, #ICON_B64, 4 do
					local a, b, c, d = string.byte(ICON_B64, i, i + 3)
					local n = lookup[a] * 262144 + lookup[b] * 4096 + (lookup[c] or 0) * 64 + (lookup[d] or 0)
					local b1, b2, b3 = math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256
					if c == 61 then
						table.insert(pieces, string.char(b1))
					elseif d == 61 then
						table.insert(pieces, string.char(b1, b2))
					else
						table.insert(pieces, string.char(b1, b2, b3))
					end
				end
				writefile(path, table.concat(pieces))
			end
			local id = getcustomasset(path)
			if id and id ~= "" then
				iconAssetId = id
			end
		end)
		return iconAssetId or nil
	end
	-- the product icon: a rounded tile with the accent gradient and a crosshair
	local function productIcon(parent, size, position, z)
		local asset = iconAsset()
		if asset then
			return create("ImageLabel", {
				Position = position,
				Size = UDim2.fromOffset(size, size),
				BackgroundTransparency = 1,
				Image = asset,
				ScaleType = Enum.ScaleType.Crop,
				ZIndex = z or 1,
				Parent = parent,
			}, { corner(math.floor(size * 0.26)) })
		end
		local tile = create("Frame", {
			Position = position,
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = Theme.Accent,
			BorderSizePixel = 0,
			ZIndex = z or 1,
			Parent = parent,
		}, {
			corner(math.floor(size * 0.26)),
			create("UIGradient", { Rotation = 60, Color = ColorSequence.new(Theme.Accent:Lerp(Color3.new(1, 1, 1), 0.25), Theme.Accent:Lerp(Color3.new(0, 0, 0), 0.35)) }),
		})
		local k = size / 40
		local white = Color3.new(1, 1, 1)
		ring(tile, 9 * k, 9 * k, 22 * k, 2.4 * k, white)
		disc(tile, 18 * k, 18 * k, 4 * k, white)
		bar(tile, 20 * k, 5.5 * k, 2.4 * k, 7 * k, 0, white)
		bar(tile, 20 * k, 34.5 * k, 2.4 * k, 7 * k, 0, white)
		bar(tile, 5.5 * k, 20 * k, 7 * k, 2.4 * k, 0, white)
		bar(tile, 34.5 * k, 20 * k, 7 * k, 2.4 * k, 0, white)
		return tile
	end
	-- an arc that turns: a ring stroke whose gradient is opaque on a third of the circle, turned every frame
	local function spinner(parent, size, thick, color, position)
		local holderRing = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = position, Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, Parent = parent }, { corner(size) })
		local track = stroke(color, thick)
		track.Transparency = 0.86
		track.Parent = holderRing
		local arcRing = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = holderRing }, { corner(size) })
		local arc = stroke(color, thick)
		arc.Parent = arcRing
		local gradient = create("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.3, 0),
				NumberSequenceKeypoint.new(0.31, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = arc,
		})
		table.insert(frameSteps, function(_, now)
			gradient.Rotation = (now * 420) % 360
		end)
		return holderRing, track, arc
	end

	local function button(parent, props)
		local b = create("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Parent = parent,
		}, nil)
		for k, v in pairs(props or {}) do
			b[k] = v
		end
		return b
	end

	------------------------------------------------------------------
	-- Left side: logo, links, profile
	------------------------------------------------------------------
	local sidebar = create("CanvasGroup", { Name = "Sidebar", Size = UDim2.fromOffset(150, H), BackgroundTransparency = 1, GroupTransparency = 1, Parent = root })
	for _, offset in ipairs({ 2, 0 }) do -- the logo: an accent copy behind the white one, like the menu's NL
		textLabel({
			Text = "NL",
			Position = UDim2.fromOffset(24 + offset, 20 + offset),
			Size = UDim2.fromOffset(80, 40),
			FontFace = Theme.FontHeavy,
			TextSize = 40,
			TextColor3 = if offset == 0 then Theme.Text else Theme.Accent,
			Parent = sidebar,
		})
	end
	local toast
	local function showToast(text)
		if toast then
			toast:Destroy()
		end
		toast = create("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 20),
			Size = UDim2.fromOffset(0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Theme.Pill,
			BackgroundTransparency = 0.1,
			FontFace = Theme.Font,
			Text = text,
			TextSize = 13,
			TextColor3 = Theme.TextDim,
			ZIndex = 30,
			Parent = root,
		}, { corner(13), padding(0, 14, 0, 14), litStroke() })
		tw(toast, { Position = UDim2.new(0.5, 0, 1, -14) }, 0.3, Enum.EasingStyle.Back)
		local mine = toast
		task.delay(1.8, function()
			if toast == mine then
				tw(mine, { BackgroundTransparency = 1, TextTransparency = 1 }, 0.3)
				task.delay(0.35, function()
					mine:Destroy()
				end)
			end
		end)
	end
	for i, name in ipairs({ "Website", "Support", "Market" }) do
		local link = button(sidebar, { Position = UDim2.fromOffset(24, 100 + (i - 1) * 34), Size = UDim2.fromOffset(110, 28) })
		local label = textLabel({ Text = name, Size = UDim2.fromScale(1, 1), FontFace = Theme.Font, TextSize = 15, TextColor3 = Theme.TabText, Parent = link })
		local accentBar = create("Frame", { Position = UDim2.fromOffset(-10, 8), Size = UDim2.fromOffset(3, 12), BackgroundColor3 = Theme.Accent, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = link }, { corner(2) })
		link.MouseEnter:Connect(function()
			tw(label, { TextColor3 = Theme.Text, Position = UDim2.fromOffset(6, 0) }, 0.18)
			tw(accentBar, { BackgroundTransparency = 0 }, 0.18)
		end)
		link.MouseLeave:Connect(function()
			tw(label, { TextColor3 = Theme.TabText, Position = UDim2.fromOffset(0, 0) }, 0.18)
			tw(accentBar, { BackgroundTransparency = 1 }, 0.18)
		end)
		link.MouseButton1Click:Connect(function()
			showToast(name .. " has no address yet")
		end)
	end
	local avatar = create("ImageLabel", {
		Position = UDim2.fromOffset(20, H - 56),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = Theme.Element,
		Image = "",
		Parent = sidebar,
	}, { corner(18), litStroke() })
	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and type(image) == "string" and avatar.Parent then
			avatar.Image = image
		end
	end)
	textLabel({ Text = player.Name, Position = UDim2.fromOffset(64, H - 56), Size = UDim2.fromOffset(84, 20), FontFace = Theme.FontBold, TextSize = 14, TextColor3 = Theme.Text, TextTruncate = Enum.TextTruncate.AtEnd, Parent = sidebar })
	textLabel({ Text = "Lifetime", Position = UDim2.fromOffset(64, H - 37), Size = UDim2.fromOffset(84, 16), FontFace = Theme.Font, TextSize = 12, TextColor3 = Theme.SubText, Parent = sidebar })

	------------------------------------------------------------------
	-- Right side: title, window buttons, product cards
	------------------------------------------------------------------
	local content = create("CanvasGroup", { Name = "Content", Position = UDim2.fromOffset(150, 0), Size = UDim2.fromOffset(W - 150, H), BackgroundTransparency = 1, GroupTransparency = 1, Parent = root })
	textLabel({ Text = "Subscription", Position = UDim2.fromOffset(20, 20), Size = UDim2.fromOffset(180, 30), FontFace = Theme.FontBold, TextSize = 24, TextColor3 = Theme.Text, Parent = content })
	textLabel({ Text = "Available subscriptions", Position = UDim2.fromOffset(20, 52), Size = UDim2.fromOffset(200, 20), FontFace = Theme.Font, TextSize = 14, TextColor3 = Theme.SubText, Parent = content })

	local function windowButton(x, glyph, action)
		local b = button(content, { Position = UDim2.fromOffset(x, 16), Size = UDim2.fromOffset(26, 26) })
		local back = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Element, BackgroundTransparency = 1, Parent = b }, { corner(8) })
		local label = textLabel({ Text = glyph, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, FontFace = Theme.FontBold, TextSize = 18, TextColor3 = Theme.TabText, Parent = back })
		b.MouseEnter:Connect(function()
			tw(back, { BackgroundTransparency = 0 }, 0.15)
			tw(label, { TextColor3 = Theme.Text }, 0.15)
		end)
		b.MouseLeave:Connect(function()
			tw(back, { BackgroundTransparency = 1 }, 0.15)
			tw(label, { TextColor3 = Theme.TabText }, 0.15)
		end)
		b.MouseButton1Click:Connect(action)
		return b
	end

	local cards = {}
	local function addCard(y, locked, order)
		local card = create("CanvasGroup", {
			Name = "Card",
			Position = UDim2.fromOffset(20, y + 14),
			Size = UDim2.fromOffset(W - 150 - 40, 70),
			BackgroundColor3 = Theme.Section,
			BackgroundTransparency = if locked then 0.35 else 0.1,
			GroupTransparency = 1,
			Parent = content,
		}, { corner(12) })
		local rim = stroke(Theme.SectionStroke, 1)
		rim.Parent = card
		table.insert(cards, { Card = card, Y = y, Order = order, Rim = rim, Locked = locked })
		return card, rim
	end
	local mainCard, mainRim = addCard(96, false, 1)
	textLabel({ Text = GAME, Position = UDim2.fromOffset(16, 13), Size = UDim2.fromOffset(180, 22), FontFace = Theme.FontBold, TextSize = 17, TextColor3 = Theme.Text, Parent = mainCard })
	textLabel({ Text = "Lifetime", Position = UDim2.fromOffset(16, 38), Size = UDim2.fromOffset(150, 18), FontFace = Theme.Font, TextSize = 13, TextColor3 = Theme.SubText, Parent = mainCard })
	productIcon(mainCard, 40, UDim2.new(1, -56, 0.5, -20), 4)
	local mainButton = button(mainCard, { Size = UDim2.fromScale(1, 1), ZIndex = 5 })
	-- two locked cards, with a slow light sweep, like the blurred ones of the original
	for index, y in ipairs({ 176, 256 }) do
		local locked = addCard(y, true, index + 1)
		for _, spec in ipairs({ { 16, 18, 90, 14, 0.6 }, { 16, 40, 60, 12, 0.75 } }) do
			create("Frame", { Position = UDim2.fromOffset(spec[1], spec[2]), Size = UDim2.fromOffset(spec[3], spec[4]), BackgroundColor3 = Theme.Hover, BackgroundTransparency = spec[5], BorderSizePixel = 0, Parent = locked }, { corner(6) })
		end
		create("Frame", { Position = UDim2.new(1, -56, 0.5, -20), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = Theme.Hover, BackgroundTransparency = 0.7, BorderSizePixel = 0, Parent = locked }, { corner(10) })
		local sweep = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.94, BorderSizePixel = 0, Parent = locked }, {
			create("UIGradient", {
				Rotation = 20,
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }),
			}),
		})
		local gradient = sweep:FindFirstChildOfClass("UIGradient")
		table.insert(frameSteps, function(_, now)
			gradient.Offset = Vector2.new(((now * 0.35 + index * 0.4) % 2) - 1, 0)
		end)
	end

	-- hover: the card lifts a little, the rim takes the accent colour
	mainButton.MouseEnter:Connect(function()
		tw(mainCard, { Position = UDim2.fromOffset(20, 92), BackgroundColor3 = Theme.Hover }, 0.18)
		tw(mainRim, { Color = Theme.Accent }, 0.18)
	end)
	mainButton.MouseLeave:Connect(function()
		tw(mainCard, { Position = UDim2.fromOffset(20, 96), BackgroundColor3 = Theme.Section }, 0.18)
		tw(mainRim, { Color = Theme.SectionStroke }, 0.18)
	end)

	------------------------------------------------------------------
	-- Product window: info on the left, the update log on the right, Inject at the bottom
	------------------------------------------------------------------
	local overlay = create("Frame", { Name = "Overlay", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 10, Parent = root })
	local modalCard = create("CanvasGroup", {
		Name = "Product",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(412, 300),
		BackgroundColor3 = Theme.PopupBg,
		GroupTransparency = 1,
		Visible = false,
		ZIndex = 11,
		Parent = overlay,
	}, { corner(14), litStroke(Theme.PopupLitTop, Theme.PopupLitBottom) })
	local modalScale = create("UIScale", { Scale = 0.9, Parent = modalCard })
	productIcon(modalCard, 30, UDim2.fromOffset(18, 16), 12)
	textLabel({ Text = GAME, Position = UDim2.fromOffset(58, 16), Size = UDim2.fromOffset(250, 30), FontFace = Theme.FontBold, TextSize = 20, TextColor3 = Theme.Text, ZIndex = 12, Parent = modalCard })
	local modalOpen = false
	local function closeProduct()
		if not modalOpen then
			return
		end
		modalOpen = false
		tw(modalCard, { GroupTransparency = 1 }, 0.18)
		tw(modalScale, { Scale = 0.92 }, 0.18)
		tw(overlay, { BackgroundTransparency = 1 }, 0.2)
		task.delay(0.22, function()
			if not modalOpen then
				modalCard.Visible = false
				overlay.Visible = false
			end
		end)
	end
	local closeProductButton = button(modalCard, { Position = UDim2.new(1, -40, 0, 16), Size = UDim2.fromOffset(24, 24), ZIndex = 12 })
	local closeGlyph = textLabel({ Text = "x", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, FontFace = Theme.FontBold, TextSize = 18, TextColor3 = Theme.TabText, ZIndex = 12, Parent = closeProductButton })
	closeProductButton.MouseEnter:Connect(function()
		tw(closeGlyph, { TextColor3 = Theme.Text }, 0.15)
	end)
	closeProductButton.MouseLeave:Connect(function()
		tw(closeGlyph, { TextColor3 = Theme.TabText }, 0.15)
	end)
	closeProductButton.MouseButton1Click:Connect(closeProduct)
	create("Frame", { Position = UDim2.fromOffset(18, 58), Size = UDim2.new(1, -36, 0, 1), BackgroundColor3 = Theme.Divider, BorderSizePixel = 0, ZIndex = 12, Parent = modalCard })

	-- left column: label + value lines (labels in the accent colour, as in the original)
	local infoRows = {
		{ "Build", "Release" },
		{ "Updated", RELEASES[1].Date },
		{ "Last launch", formatLaunch(previousLaunch) },
		{ "Subscription", "Lifetime" },
		{ "Game", GAME },
	}
	local infoList = create("Frame", { Position = UDim2.fromOffset(18, 70), Size = UDim2.fromOffset(150, 160), BackgroundTransparency = 1, ZIndex = 12, Parent = modalCard }, { list(7) })
	for i, row in ipairs(infoRows) do
		local line = create("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 12, Parent = infoList })
		textLabel({ Text = row[1], Size = UDim2.new(1, 0, 0, 14), FontFace = Theme.Font, TextSize = 11, TextColor3 = Theme.SubText, ZIndex = 12, Parent = line })
		textLabel({ Text = row[2], Position = UDim2.fromOffset(0, 13), Size = UDim2.new(1, 0, 0, 16), FontFace = Theme.FontBold, TextSize = 13, TextColor3 = Theme.Accent, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 12, Parent = line })
	end

	-- right column: the update log
	local logScroll = create("ScrollingFrame", {
		Position = UDim2.fromOffset(184, 66),
		Size = UDim2.fromOffset(212, 170),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Scrollbar,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 12,
		Parent = modalCard,
	}, { list(4), padding(0, 6, 4, 0) })
	for i, line in ipairs(buildLogLines(RELEASES)) do
		if line.Kind == "date" then
			textLabel({ Text = line.Text, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = i, FontFace = Theme.FontBold, TextSize = 14, TextColor3 = Theme.Text, ZIndex = 12, Parent = logScroll })
		elseif line.Kind == "group" then
			textLabel({ Text = line.Text, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = i, FontFace = Theme.FontBold, TextSize = 12, TextColor3 = Theme.Accent, ZIndex = 12, Parent = logScroll }, { padding(6, 0, 0, 0) })
		else
			textLabel({
				Text = "- " .. line.Text,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = i,
				FontFace = Theme.Font,
				TextSize = 12,
				TextColor3 = Theme.TextDim,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
				ZIndex = 12,
				Parent = logScroll,
			})
		end
	end

	-- the Inject button: accent fill, a play triangle and the label; it brightens on hover and presses in
	local injectButton = button(modalCard, { Position = UDim2.fromOffset(184, 248), Size = UDim2.fromOffset(212, 36), BackgroundTransparency = 0, BackgroundColor3 = Theme.Accent, ZIndex = 12 })
	create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = injectButton })
	create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Theme.Accent:Lerp(Color3.new(1, 1, 1), 0.12), Theme.Accent:Lerp(Color3.new(0, 0, 0), 0.18)), Parent = injectButton })
	local injectScale = create("UIScale", { Scale = 1, Parent = injectButton })
	-- the play mark: a ">" made of two rounded bars, left of the label
	for _, spec in ipairs({ { 65, 14.5, -41 }, { 65, 21.5, 41 } }) do
		bar(injectButton, spec[1], spec[2], 3, 9.5, spec[3], Color3.new(1, 1, 1)).ZIndex = 13
	end
	textLabel({ Text = "Inject", Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, FontFace = Theme.FontBold, TextSize = 15, TextColor3 = Color3.new(1, 1, 1), ZIndex = 13, Parent = injectButton })
	injectButton.MouseEnter:Connect(function()
		tw(injectScale, { Scale = 1.03 }, 0.15)
	end)
	injectButton.MouseLeave:Connect(function()
		tw(injectScale, { Scale = 1 }, 0.15)
	end)
	injectButton.MouseButton1Down:Connect(function()
		tw(injectScale, { Scale = 0.96 }, 0.08)
	end)

	local function openProduct()
		if modalOpen then
			return
		end
		modalOpen = true
		overlay.Visible = true
		modalCard.Visible = true
		modalCard.GroupTransparency = 1
		modalScale.Scale = 0.9
		tw(overlay, { BackgroundTransparency = 0.45 }, 0.25)
		tw(modalCard, { GroupTransparency = 0 }, 0.25)
		tw(modalScale, { Scale = 1 }, 0.4, Enum.EasingStyle.Back)
	end
	mainButton.MouseButton1Click:Connect(openProduct)

	------------------------------------------------------------------
	-- Injecting: spinner, steps with a progress bar, a check mark, shock waves, the window dissolves
	------------------------------------------------------------------
	local injecting = false
	local function executorReport()
		local present = {
			hookmetamethod = typeof(hookmetamethod) == "function",
			getnamecallmethod = typeof(getnamecallmethod) == "function",
			writefile = typeof(writefile) == "function",
			getcustomasset = typeof(getcustomasset) == "function",
			mouse1press = typeof(mouse1press) == "function",
		}
		local missing = {}
		for _, name in ipairs({ "hookmetamethod", "getnamecallmethod", "writefile", "getcustomasset", "mouse1press" }) do
			if not present[name] then
				table.insert(missing, name)
			end
		end
		if #missing == 0 then
			return "Executor: all functions found"
		end
		return "Executor: missing " .. table.concat(missing, ", ")
	end
	local function outro(scaleTo)
		tw(rootScale, { Scale = scaleTo }, 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tw(root, { GroupTransparency = 1 }, 0.38)
		tw(dim, { BackgroundTransparency = 1 }, 0.45)
		if blur then
			tw(blur, { Size = 0 }, 0.45)
		end
	end
	local function runInject()
		if injecting then
			return
		end
		injecting = true
		closeProduct()
		rememberLaunch()
		local screen = create("CanvasGroup", { Name = "Injecting", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Window, GroupTransparency = 1, ZIndex = 20, Parent = root })
		tw(screen, { GroupTransparency = 0 }, 0.3)
		local spinHolder, spinTrack, spinArc = spinner(screen, 56, 4, Theme.Accent, UDim2.new(0.5, 0, 0.4, 0))
		local title = textLabel({ Text = "Preparing " .. GAME, Position = UDim2.new(0, 0, 0.4, 52), Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Center, FontFace = Theme.FontBold, TextSize = 20, TextColor3 = Theme.Text, ZIndex = 21, Parent = screen })
		local status = textLabel({ Text = "", Position = UDim2.new(0, 0, 0.4, 82), Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Center, FontFace = Theme.Font, TextSize = 13, TextColor3 = Theme.SubText, ZIndex = 21, Parent = screen })
		local track = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -54), Size = UDim2.fromOffset(220, 4), BackgroundColor3 = Theme.Element, BorderSizePixel = 0, ZIndex = 21, Parent = screen }, { corner(2) })
		local fill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, ZIndex = 22, Parent = track }, { corner(2), create("UIGradient", { Color = ColorSequence.new(Theme.Accent:Lerp(Color3.new(1, 1, 1), 0.25), Theme.Accent) }) })
		-- the dots after the title
		local base = "Preparing " .. GAME
		table.insert(frameSteps, function(_, now)
			if title.Parent and not title:GetAttribute("Done") then
				title.Text = base .. loadingDots(now)
			end
		end)
		task.spawn(function()
			local steps = {
				{ "Starting the loader", 0.3, 0.12 },
				{ "Checking the executor", 0.55, 0.3 },
				{ "Loading modules", 0.55, 0.55 },
				{ "Loading textures", 0.6, 0.8 },
				{ "Building the menu", 0.45, 1 },
			}
			for _, step in ipairs(steps) do
				status.Text = if step[1] == "Checking the executor" then executorReport() else step[1]
				tw(fill, { Size = UDim2.fromScale(step[3], 1) }, step[2], Enum.EasingStyle.Quad)
				task.wait(step[2] + 0.1)
			end
			-- finished: the arc turns into a ring with a check mark that pops in
			title:SetAttribute("Done", true)
			title.Text = GAME .. " is ready"
			status.Text = "Injecting"
			tw(spinArc, { Transparency = 1 }, 0.2)
			tw(spinTrack, { Transparency = 0.2 }, 0.2)
			local check = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.4, 0), Size = UDim2.fromOffset(56, 56), BackgroundTransparency = 1, ZIndex = 22, Parent = screen })
			local checkScale = create("UIScale", { Scale = 0, Parent = check })
			bar(check, 22, 32, 4, 12, -45, Theme.Accent) -- a check mark: a short and a long bar
			bar(check, 34, 27, 4, 26, 43, Theme.Accent)
			tw(checkScale, { Scale = 1 }, 0.4, Enum.EasingStyle.Back)
			-- two shock waves leave the centre
			for i = 1, 2 do
				task.delay((i - 1) * 0.18, function()
					local waveStroke = stroke(Theme.Accent, 2.5)
					local wave = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.4, 0), Size = UDim2.fromOffset(56, 56), BackgroundTransparency = 1, ZIndex = 21, Parent = screen }, { corner(300), waveStroke })
					tw(wave, { Size = UDim2.fromOffset(520, 520) }, 0.8, Enum.EasingStyle.Quad)
					tw(waveStroke, { Transparency = 1 }, 0.8)
				end)
			end
			task.wait(0.95)
			outro(1.07) -- the window grows a little while it dissolves, the blur and the dimming go away
			task.wait(0.5)
			result = true
		end)
	end
	injectButton.MouseButton1Click:Connect(runInject)

	------------------------------------------------------------------
	-- Window buttons: minimise to a pill, close, drag
	------------------------------------------------------------------
	local pillButton
	local function setMinimised(on)
		if on then
			holder.Visible = false
			shadowLayer.Visible = false
			tw(dim, { BackgroundTransparency = 1 }, 0.25)
			if blur then
				tw(blur, { Size = 0 }, 0.25)
			end
			pillButton = create("TextButton", {
				Name = "Minimised",
				Text = "",
				AutoButtonColor = false,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, -40),
				Size = UDim2.fromOffset(0, 34),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = Theme.Pill,
				BackgroundTransparency = 0.1,
				Parent = gui,
			}, { corner(17), litStroke(), padding(0, 16, 0, 16), list(8, true) })
			textLabel({ Text = "Neverlose  |  " .. GAME .. "  -  click to open", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 34), FontFace = Theme.FontBold, TextSize = 13, TextColor3 = Theme.Text, Parent = pillButton })
			tw(pillButton, { Position = UDim2.new(0.5, 0, 0, 14) }, 0.35, Enum.EasingStyle.Back)
			pillButton.MouseButton1Click:Connect(function()
				pillButton:Destroy()
				pillButton = nil
				holder.Visible = true
				shadowLayer.Visible = true
				tw(dim, { BackgroundTransparency = 0.5 }, 0.3)
				if blur then
					tw(blur, { Size = 12 }, 0.3)
				end
				rootScale.Scale = 0.9
				tw(rootScale, { Scale = 1 }, 0.4, Enum.EasingStyle.Back)
			end)
		end
	end
	windowButton(W - 150 - 76, "-", function()
		if not injecting and not pillButton then
			setMinimised(true)
		end
	end)
	windowButton(W - 150 - 44, "x", function()
		if injecting or result ~= nil then
			return
		end
		outro(0.92)
		task.delay(0.5, function()
			result = false
		end)
	end)

	local dragging, dragStart, startPosition = false, nil, nil
	local dragArea = create("Frame", { Name = "Drag", Size = UDim2.new(1, -90, 0, 70), BackgroundTransparency = 1, Active = true, ZIndex = 3, Parent = root })
	dragArea.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, dragStart, startPosition = true, input.Position, holder.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	local dragConn = UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			holder.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
		end
	end)

	------------------------------------------------------------------
	-- Intro: the sidebar slides in, the cards rise one after the other
	------------------------------------------------------------------
	task.delay(0.12, function()
		sidebar.Position = UDim2.fromOffset(-14, 0)
		tw(sidebar, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, 0.45, Enum.EasingStyle.Quint)
		tw(content, { GroupTransparency = 0 }, 0.45)
		for _, entry in ipairs(cards) do
			task.delay(0.12 + entry.Order * 0.1, function()
				tw(entry.Card, { GroupTransparency = 0, Position = UDim2.fromOffset(20, entry.Y) }, 0.45, Enum.EasingStyle.Quint)
			end)
		end
	end)

	while result == nil and gui.Parent do
		task.wait()
	end

	-- clean up: the mouse goes back to the game's state, every connection and effect is removed
	dragConn:Disconnect()
	frameConn:Disconnect()
	pcall(RunService.UnbindFromRenderStep, RunService, "NeverloseLoaderCursor")
	modal.Modal = false
	UserInputService.MouseIconEnabled = cursorPrev.Icon
	UserInputService.MouseBehavior = cursorPrev.Behavior
	if blur then
		blur:Destroy()
	end
	gui:Destroy()
	return result == true
end)() then
	return
end

------------------------------------------------------------------
-- Menu layout. Feature callbacks are empty (noop) — fill them in.
-- Only the menu's own windows (watermark, hotkeys, scale, preview) are wired.
------------------------------------------------------------------
local menu = UI.new({
	Title = "Neverlose",
	Subtitle = "BloxStrike",
	Logo = "NL",
	ToggleKey = Enum.KeyCode.Delete,
	Profiles = { "Default", "Legit", "Rage" },
	Options = { "Global", "Local" },
	FooterText = "Lifetime",
	FooterLink = { "Renew", nil },
	GetSpectators = function()
		return SpectatorList.Get()
	end,
})

local function noop() end

------------------------------------------------------------------
-- Extras config. The menu callbacks only store values here; the Extras block further down reads them.
-- Feat.unwired(name, reason) makes a callback for a feature whose game data is missing: it logs once, never pretends.
------------------------------------------------------------------
local Feat = {
	HitMarker = false, HitMarkerColor = Color3.fromRGB(255, 255, 255),
	HitSound = false, HitSoundName = "Hit1", HitSoundVolume = 0.5,
	HitSoundNames = { "Hit1", "Hit2", "Hit3", "Hit4", "Hit5", "Hit6", "Damage" },
	LogEvents = { "Damage Dealt" },
	Tracers = false, TracerColor = Color3.fromRGB(94, 160, 247),
	Impacts = false, ImpactColor = Color3.fromRGB(255, 94, 200),
	Sparks = false, SparkColor = Color3.fromRGB(255, 255, 255),
	GrenadeEsp = false, GrenadeFx = false, GrenadeFxColor = Color3.fromRGB(255, 94, 200),
	SmokeRadius = false, InfernoRadius = false,
	Trajectory = false, TrajThickness = 2, TrajColor = Color3.fromRGB(255, 94, 200),
	Proximity = false,
	Radar = {},
	DamageNumbers = false, DamageColor = Color3.fromRGB(255, 255, 255),
	SessionStats = false, Speedometer = false,
	IndHC = false, IndMD = false, IndDT = false, IndDuck = false, IndSlow = false, IndJump = false,
	IndicatorOpacity = 0.4, PanelOpacity = 0.6, -- background opacity of the indicator pills / of the radar and session stats
	Hitboxes = false, HitboxColor = Color3.fromRGB(94, 160, 247),
	ShootSound = false, ShootSoundName = "Hit1", ShootSoundVolume = 0.5, ShootSoundNames = {}, ShootSoundFiles = {},
	RemoveFlash = false, RemoveSmoke = false, RemoveFog = false,
	Penetration = false, PenetrationColor = Color3.fromRGB(94, 94, 247),
	PreventAFK = false,
	EdgeJump = false, EdgeQuickStop = false, StandaloneQuickStop = false,
	SlowWalk = false, SlowWalkSpeed = 0.5,
	PeekAssist = false, PeekColor = Color3.fromRGB(240, 60, 70), PeekMax = 25, PeekRetreat = "Off",
	OnShot = nil, -- set by the Extras block: called from the BulletHitreg hook with the (possibly rewritten) packed args
	Gated = {},
	Notes = {
		Recoil = "the weapon client script that applies recoil is not in the dump (only Weapons.<name>.Recoil / ScopedPattern values are); dump it, find where the camera or viewmodel is kicked, then hook that",
		Timing = "fire rate, reload and equip timing are enforced by the weapon client script (not in the dump) and maybe by the server; record one reload and one held fire with the remote logger before building this",
		Scope = "the scope / ADS input path is not measured (character.ADS BoolValue is the only lead); log the camera FOV and the AdjustADS remote while scoping",
		Crouch = "the crouch input / state of the game's custom movement is not measured; read MasterControl for the duck flag",
		Server = "needs the server to accept older positions or delayed shots; no measurement exists, test with a controlled shot log first",
		World = "the in-world object was never captured: the dump's Workspace listing is depth 1 only; dump Workspace descendants during a round while it exists",
		Gui = "the GUI path for this is not in the dump; dump PlayerGui while it is visible",
		Remote = "no matching remote was captured in shots.txt; record the action with the remote logger and add the remote name and args",
		Chat = "the chat system and its team filter are not measured; dump the chat GUI or TextChatService config",
	},
}

-- Shoot Sound list: the game's own sound ids plus every .mp3 / .ogg in <executor workspace>/NeverloseBloxStrike/sounds
do
	for _, name in ipairs({ "Hit1", "Hit2", "Hit3", "Hit4", "Hit5", "Hit6", "Damage" }) do
		table.insert(Feat.ShootSoundNames, name)
	end
	pcall(function()
		local folder = "NeverloseBloxStrike/sounds"
		if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder(folder) then
			makefolder(folder)
		end
		if type(listfiles) == "function" and type(isfolder) == "function" and isfolder(folder) then
			for _, path in ipairs(listfiles(folder)) do
				local file = string.match(path, "([^/\\]+)$")
				local ext = file and string.lower(string.match(file, "%.(%w+)$") or "") or ""
				if ext == "mp3" or ext == "ogg" or ext == "wav" then
					local label = "File: " .. file
					Feat.ShootSoundFiles[label] = path
					table.insert(Feat.ShootSoundNames, label)
				end
			end
		end
	end)
end

function Feat.gate(name, reason)
	if Feat.Gated[name] then
		return
	end
	Feat.Gated[name] = true
	pcall(function()
		menu:Log(name .. " is not wired (see console)")
	end)
	warn("[Extras] " .. name .. " is not wired: " .. reason)
end

function Feat.unwired(name, reason)
	return function(v)
		local on
		if type(v) == "table" then
			on = #v > 0
		elseif type(v) == "string" then
			on = v ~= "Off" and v ~= "Default" and v ~= "Disabled"
		else
			on = v == true or (type(v) == "number" and v ~= 0)
		end
		if on then
			Feat.gate(name, reason)
		end
	end
end


SpectatorList.SetLog(function(text)
	menu:Log(text)
end)

------------------------------------------------------------------
-- Enemy ESP engine: draws what Visuals > Players > Enemies configures.
-- Overlay = Frames in a ScreenGui (no Drawing API); chams = part materials + Highlight instances.
-- Screen space: Camera:WorldToViewportPoint, pixels, origin top-left, +Y down. World is Y-up.
-- All BloxStrike-specific reads live in Adapter. A field left nil was NOT measured on the game:
-- the matching item stays hidden instead of showing a made-up value.
------------------------------------------------------------------
local EnemyESP = {}
do
	local Workspace = game:GetService("Workspace")
	local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
	local STUDS_TO_METERS = 0.28 -- Roblox's own conversion
	local MAX_RINGS, RING_LIFE, RING_GAP = 32, 0.8, 0.45
	local HIGHLIGHT_FILL = { Neon = 0.3, SmoothPlastic = 0.5, ForceField = 0.7, Glass = 0.8 }
	local SKIN_CLASSES = { "Shirt", "Pants", "ShirtGraphic", "SurfaceAppearance" }

	-- UNVERIFIED on BloxStrike: generic Roblox defaults. Measured values are noted per field (the console
	-- first enemy) and replace these with what the game really uses (attributes, folders, remotes).
	local iconModule -- nil = not loaded yet, false = unavailable
	local Adapter = {
		IsEnemy = function(plr)
			if plr == player then
				return false
			end
			local mine, theirs = player.Team, plr.Team
			if mine == nil and theirs == nil then
				return true -- place without teams: everyone else is an enemy
			end
			return mine ~= theirs
		end,
		GetHealth = function(_, _, humanoid)
			return humanoid.Health, humanoid.MaxHealth
		end,
		-- MEASURED (Counter Blox probe): the character holds a StringValue "EquippedTool"; its value text is not yet seen
		GetWeaponName = function(_, character)
			local equipped = character:FindFirstChild("EquippedTool")
			if equipped and equipped:IsA("StringValue") and equipped.Value ~= "" then
				return equipped.Value
			end
			local tool = character:FindFirstChildOfClass("Tool")
			return if tool then tool.Name else nil
		end,
		-- MEASURED: player.Status.Alive (BoolValue, true while alive). ASSUMED: it turns false on death.
		IsAlive = function(plr, humanoid)
			local status = plr:FindFirstChild("Status")
			local alive = status and status:FindFirstChild("Alive")
			if alive and alive:IsA("BoolValue") and alive.Value == false then
				return false
			end
			return humanoid.Health > 0
		end,
		-- MEASURED (ReplicatedStorage.GetIcon): getWeaponOfKiller(name) -> killfeed icon image id, or the generic
		-- "rbxassetid://121479936598672" when the weapon has no icon (then nothing is drawn)
		GetWeaponIcon = function(name)
			if iconModule == nil then
				local module = game:GetService("ReplicatedStorage"):FindFirstChild("GetIcon")
				local ok, loaded = pcall(function()
					return module and require(module)
				end)
				iconModule = if ok and type(loaded) == "table" then loaded else false
			end
			if not iconModule then
				return nil
			end
			local ok, image = pcall(iconModule.getWeaponOfKiller, name)
			if ok and type(image) == "string" and image ~= "" and image ~= "rbxassetid://121479936598672" then
				return image
			end
			return nil
		end,
		-- no ammo of other players is replicated (recording: only the local GUI shows ammo)
		GetAmmo = nil, -- function(plr, character) -> fraction 0..1
		GetReadiness = nil, -- function(plr, character) -> fraction 0..1 ; not measured
		-- [flag key] = function(plr, character) -> true | "text" | nil ; keys that are missing are never drawn.
		-- Object names below are MEASURED (probe); what their values mean (0/1, amount) is ASSUMED until the second probe.
		Flags = {
			-- MEASURED (Modules.DeathmatchSpawnProtection): protection = a ForceField in the character while the character
			-- attribute DMSpawnProtectionState == "active" (the module also ends it once the player moves). Deathmatch mode.
			["Flags/Immunity"] = function(_, character)
				if character:FindFirstChildOfClass("ForceField") == nil then
					return false
				end
				local state = character:GetAttribute("DMSpawnProtectionState")
				return state == nil or state == "active"
			end,
			["Flags/Unarmored"] = function(plr) -- player.Kevlar (IntValue); ASSUMED: 0 = no armor
				local kevlar = plr:FindFirstChild("Kevlar")
				return if kevlar and kevlar:IsA("IntValue") then kevlar.Value <= 0 else nil
			end,
			["Flags/Defuser"] = function(plr) -- player.DefuseKit (IntValue); ASSUMED: > 0 = has a kit
				local kit = plr:FindFirstChild("DefuseKit")
				return if kit and kit:IsA("IntValue") then kit.Value > 0 else nil
			end,
			["Weapon/Defuser"] = function(plr)
				local kit = plr:FindFirstChild("DefuseKit")
				return if kit and kit:IsA("IntValue") then kit.Value > 0 else nil
			end,
			["Flags/Scoped"] = function(_, character) -- character.ADS (BoolValue); ASSUMED: aiming down sights = scoped
				local ads = character:FindFirstChild("ADS")
				return if ads and ads:IsA("BoolValue") then ads.Value else nil
			end,
			-- character.BackC4 (MeshPart) is fully transparent on a player without the bomb (measured);
			-- ASSUMED: it becomes visible on the bomb carrier. Not yet seen on a Terrorist with C4.
			["Flags/Bomb"] = function(_, character)
				local c4 = character:FindFirstChild("BackC4")
				return if c4 and c4:IsA("BasePart") then c4.Transparency < 1 else nil
			end,
			["Weapon/Bomb"] = function(_, character)
				local c4 = character:FindFirstChild("BackC4")
				return if c4 and c4:IsA("BasePart") then c4.Transparency < 1 else nil
			end,
			["Flags/Money"] = function(plr) -- player attribute "Cash" (seen: 4150); ASSUMED to be the round money
				local cash = plr:GetAttribute("Cash")
				return if type(cash) == "number" then "$" .. tostring(math.floor(cash)) else nil
			end,
			["Flags/Delay"] = function(plr) -- player attribute "Ping" (seen: 118)
				local ping = plr:GetAttribute("Ping")
				return if type(ping) == "number" then tostring(math.floor(ping + 0.5)) .. "MS" else nil
			end,
		},
	}
	EnemyESP.Adapter = Adapter

	local Cfg = {
		Enabled = false,
		Arrow = { On = false, Color = WHITE },
		Sounds = { On = false, Color = rgb(240, 90, 140) },
		KillEffect = { On = false, Color = rgb(240, 50, 70) },
		Glow = { On = false, Color = rgb(200, 195, 240) },
		-- Material = Enum.Material or nil (Disabled)
		Chams = {
			["Player"] = { Material = nil, Color = rgb(160, 170, 250) },
			["Behind Walls"] = { Material = nil, Color = rgb(90, 240, 240) },
			["Ragdolls"] = { Material = nil, Color = rgb(150, 145, 170) },
			["On Shot"] = { Material = nil, Color = rgb(225, 232, 225) },
		},
	}
	EnemyESP.Cfg = Cfg

	local NEEDS = {
		["History"] = "needs recorded past positions of enemies (not measured)",
	}

	-- On Shot: MEASURED (recording): the local player's attribute Damaged_UserId is set to the victim's UserId when
	-- the local player damages someone, and cleared about a second later. The victim flashes for SHOT_SECONDS.
	local shots = {} -- [Player] = os.clock() until which the On Shot chams show
	local SHOT_SECONDS = 0.45
	player:GetAttributeChangedSignal("Damaged_UserId"):Connect(function()
		local id = player:GetAttribute("Damaged_UserId")
		if type(id) == "number" then
			local victim = Players:GetPlayerByUserId(id)
			if victim then
				shots[victim] = os.clock() + SHOT_SECONDS
			end
		end
	end)
	local preview, logLine
	local warned = {}
	local function warnOnce(key, text)
		if not warned[key] then
			warned[key] = true
			if logLine then
				logLine(text)
			else
				warn(text)
			end
		end
	end

	function EnemyESP.SetChams(label, materialName, color)
		local material = CHAMS_MATERIALS[materialName]
		local entry = Cfg.Chams[label]
		if entry then
			entry.Material, entry.Color = material, color
		elseif NEEDS[label] and material then
			warnOnce(label, label .. " chams: not drawn, " .. NEEDS[label])
		end
	end

	------------------------------------------------------------------
	-- Cache of the preview's items / layout / styles (refreshed on change callbacks and every 0.25 s)
	------------------------------------------------------------------
	local cache = { Items = {}, Layout = {}, Styles = {}, Stamp = 0 }
	local function refreshCache()
		if not preview then
			return
		end
		cache.Items = preview:GetItems("Enemies")
		cache.Layout = preview:GetLayout("Enemies")
		cache.Styles = {}
		cache.Stamp = os.clock()
	end
	local function styleOf(key)
		local s = cache.Styles[key]
		if not s then
			s = preview:GetStyle(key, "Enemies")
			cache.Styles[key] = s
		end
		return s
	end
	function EnemyESP.Invalidate()
		cache.Stamp = 0
	end

	------------------------------------------------------------------
	-- Overlay
	------------------------------------------------------------------
	local gui = create("ScreenGui", {
		Name = "EnemyESPOverlay",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = -1,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	local function newStroke(parent, thickness)
		local s = Instance.new("UIStroke")
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Thickness = thickness or 1
		s.Parent = parent
		return s
	end

	local objects = {}

	local function newObject(plr)
		local container = create("Frame", {
			Name = plr.Name,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = gui,
		})
		local box = create("Frame", { BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, Parent = container })
		local o = {
			Plr = plr,
			Container = container,
			Box = box,
			BoxStroke = newStroke(box, 1),
			Pool = {},
			Lines = {},
			Conns = {},
			Sounds = {},
			LastRing = 0,
			Orig = {},
			Applied = nil,
			Dirty = true,
			Cleared = false,
		}
		objects[plr] = o
		return o
	end

	local function poolText(o, key)
		local e = o.Pool[key]
		if not e then
			e = {
				Label = create("TextLabel", {
					BackgroundTransparency = 1,
					Text = "",
					Visible = false,
					TextStrokeColor3 = BLACK,
					Parent = o.Container,
				}),
			}
			o.Pool[key] = e
		end
		return e
	end

	local function poolBar(o, key)
		local e = o.Pool[key]
		if not e then
			local track = create("Frame", { BackgroundColor3 = Theme.Deep, BorderSizePixel = 0, Visible = false, Parent = o.Container })
			e = {
				Track = track,
				Fill = create("Frame", { BorderSizePixel = 0, Parent = track }),
				Value = create("TextLabel", {
					BackgroundTransparency = 1,
					Text = "",
					Visible = false,
					TextSize = 11,
					TextStrokeColor3 = BLACK,
					TextStrokeTransparency = 0.6,
					Size = UDim2.fromOffset(26, 12),
					Parent = o.Container,
				}),
			}
			o.Pool[key] = e
		end
		return e
	end

	-- weapon icon: an ImageLabel kept in the pool under .Label so hideDrawing treats it like a text label
	local function poolIcon(o, key)
		local e = o.Pool[key]
		if not e then
			e = {
				Label = create("ImageLabel", {
					BackgroundTransparency = 1,
					ScaleType = Enum.ScaleType.Fit,
					Visible = false,
					Parent = o.Container,
				}),
			}
			o.Pool[key] = e
		end
		return e
	end

	local function placeIcon(e, image, style, x, y, w, h, anchorX)
		local l = e.Label
		l.Visible = true
		l.Image = image
		l.ImageColor3 = style.Color
		l.AnchorPoint = Vector2.new(anchorX, 0)
		l.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
		l.Size = UDim2.fromOffset(w, h)
	end

	local function placeText(e, text, style, flag, x, y, w, h, anchorX, align)
		local l = e.Label
		l.Visible = true
		l.Text = text
		l.FontFace = if flag then Theme.FontBold else Theme.Font
		l.TextSize = if flag then 10 else style.Size
		l.TextColor3 = style.Color
		l.TextStrokeTransparency = if flag then 0.4 elseif style.Outline then 0.5 else 1
		l.TextXAlignment = align
		l.AnchorPoint = Vector2.new(anchorX, 0)
		l.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
		l.Size = UDim2.fromOffset(w, h)
	end

	-- vertical bars fill from the bottom, horizontal bars from the left
	local function placeBar(e, style, x, y, w, h, vertical, fraction, valueText, valueRight)
		e.Track.Visible = true
		e.Track.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
		e.Track.Size = UDim2.fromOffset(math.max(1, math.floor(w)), math.max(1, math.floor(h)))
		e.Fill.BackgroundColor3 = style.Color
		if vertical then
			e.Fill.AnchorPoint = Vector2.new(0, 1)
			e.Fill.Position = UDim2.fromScale(0, 1)
			e.Fill.Size = UDim2.fromScale(1, fraction)
		else
			e.Fill.AnchorPoint = Vector2.zero
			e.Fill.Position = UDim2.new()
			e.Fill.Size = UDim2.fromScale(fraction, 1)
		end
		if valueText then
			local v = e.Value
			v.Visible = true
			v.Text = valueText
			v.TextColor3 = style.Color
			if vertical then
				v.AnchorPoint = Vector2.new(if valueRight then 0 else 1, 0.5)
				v.TextXAlignment = if valueRight then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
				v.Position = UDim2.fromOffset(
					math.floor(if valueRight then x + w + 3 else x - 3),
					math.floor(y + h * (1 - fraction))
				)
			else
				v.AnchorPoint = Vector2.new(0, 0.5)
				v.TextXAlignment = Enum.TextXAlignment.Left
				v.Position = UDim2.fromOffset(math.floor(x + w + 4), math.floor(y + h / 2))
			end
		else
			e.Value.Visible = false
		end
	end

	local function placeLine(o, i, a, b, color, thickness)
		local f = o.Lines[i]
		if not f then
			f = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Parent = o.Container })
			o.Lines[i] = f
		end
		local d = b - a
		f.Visible = true
		f.BackgroundColor3 = color
		f.Size = UDim2.fromOffset(d.Magnitude, thickness)
		f.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
		f.Rotation = math.deg(math.atan2(d.Y, d.X))
	end

	local function hideDrawing(o)
		o.Box.Visible = false
		for _, e in pairs(o.Pool) do
			if e.Label then
				e.Label.Visible = false
			else
				e.Track.Visible = false
				e.Value.Visible = false
			end
		end
		for _, f in ipairs(o.Lines) do
			f.Visible = false
		end
		if o.Arrow then
			o.Arrow.Visible = false
		end
	end

	------------------------------------------------------------------
	-- Chams: material on the character's parts (Player), Highlight instances (Behind Walls, Glow)
	------------------------------------------------------------------
	local function restoreChams(o)
		for inst, orig in pairs(o.Orig) do
			pcall(function()
				if orig.Kind == "part" then
					inst.Material, inst.Color = orig.Material, orig.Color
				elseif orig.Kind == "decal" then
					inst.Transparency = orig.Transparency
				else
					inst.Parent = orig.Parent
				end
			end)
		end
		o.Orig = {}
	end

	local function applyChams(o, character, material, color)
		if not material then
			if o.Applied ~= "off" then
				restoreChams(o)
				o.Applied = "off"
			end
			o.Dirty = false
			return
		end
		local key = material.Name .. tostring(color)
		if o.Applied == key and not o.Dirty then
			return
		end
		o.Applied, o.Dirty = key, false
		for _, d in ipairs(character:GetDescendants()) do
			if d:IsA("BasePart") then
				if d.Name ~= "HumanoidRootPart" then
					if not o.Orig[d] then
						o.Orig[d] = { Kind = "part", Material = d.Material, Color = d.Color }
					end
					d.Material, d.Color = material, color
				end
			elseif d:IsA("Decal") then
				if not o.Orig[d] then
					o.Orig[d] = { Kind = "decal", Transparency = d.Transparency }
				end
				d.Transparency = 1
			else
				for _, class in ipairs(SKIN_CLASSES) do
					if d:IsA(class) then
						if not o.Orig[d] then
							o.Orig[d] = { Kind = "skin", Parent = d.Parent }
						end
						d.Parent = nil
						break
					end
				end
			end
		end
	end

	local function setHighlight(o, field, character, cam, on, props)
		local hl = o[field]
		if not on then
			if hl then
				hl.Enabled = false
			end
			return
		end
		if not hl then
			hl = Instance.new("Highlight")
			hl.Name = "NLChams"
			o[field] = hl
		end
		hl.Adornee = character
		if hl.Parent ~= cam then
			-- a Highlight whose camera was destroyed (new round / map) is locked: Parent errors, so make a fresh one
			if not pcall(function()
				hl.Parent = cam
			end) then
				hl = Instance.new("Highlight")
				hl.Name = "NLChams"
				o[field] = hl
				hl.Adornee = character
				hl.Parent = cam
			end
		end
		hl.Enabled = true
		hl.FillColor = props.FillColor
		hl.FillTransparency = props.FillTransparency
		hl.OutlineColor = props.OutlineColor
		hl.OutlineTransparency = props.OutlineTransparency
		hl.DepthMode = props.DepthMode
	end

	-- Behind Walls: BoxHandleAdornments on the limb parts, AlwaysOnTop. Used instead of a Highlight (those stopped drawing on
	-- this game, Player chams that change materials still work); adornments do not count against Roblox's limit of 31 Highlights.
	-- Part names MEASURED (BulletCast limb table). Fill only: an adornment has no outline.
	local WALL_PARTS = {
		"HeadHB", "UpperTorso", "LowerTorso", "RightUpperArm", "LeftUpperArm", "RightLowerArm", "LeftLowerArm",
		"RightHand", "LeftHand", "RightUpperLeg", "LeftUpperLeg", "RightLowerLeg", "LeftLowerLeg", "RightFoot", "LeftFoot",
	}
	local function setWallAdorn(o, character, on, color, transparency)
		local list = o.WallAdorn
		if not on then
			if list then
				for _, a in pairs(list) do
					a.Visible = false
				end
			end
			return
		end
		if not list then
			list = {}
			o.WallAdorn = list
		end
		for _, name in ipairs(WALL_PARTS) do
			local part = character:FindFirstChild(name)
			local a = list[name]
			if part and part:IsA("BasePart") then
				if not a or a.Parent == nil then
					a = Instance.new("BoxHandleAdornment")
					a.Name = "NLWall"
					a.AlwaysOnTop = true
					a.ZIndex = 1
					a.Parent = gui
					list[name] = a
				end
				a.Adornee = part
				a.Size = part.Size
				a.Color3 = color
				a.Transparency = transparency
				a.Visible = true
			elseif a then
				a.Visible = false
			end
		end
	end

	------------------------------------------------------------------
	-- Effects: sound rings, kill burst
	------------------------------------------------------------------
	local rings = {}
	local function addRing(pos, color)
		if #rings >= MAX_RINGS then
			return
		end
		local f = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = gui,
		}, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		newStroke(f, 2).Color = color
		table.insert(rings, { Pos = pos, Born = os.clock(), Frame = f })
	end

	local function stepRings(cam, now)
		for i = #rings, 1, -1 do
			local r = rings[i]
			local a = (now - r.Born) / RING_LIFE
			if a >= 1 or not Cfg.Enabled then
				r.Frame:Destroy()
				table.remove(rings, i)
			else
				local v = cam:WorldToViewportPoint(r.Pos)
				r.Frame.Visible = v.Z > 0
				local size = 8 + 44 * a
				r.Frame.Position = UDim2.fromOffset(v.X, v.Y)
				r.Frame.Size = UDim2.fromOffset(size, size)
				r.Frame:FindFirstChildOfClass("UIStroke").Transparency = a
			end
		end
	end

	local function killEffect(pos)
		local part = Instance.new("Part")
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
		part.Shape = Enum.PartType.Ball
		part.Material = Enum.Material.Neon
		part.Color = Cfg.KillEffect.Color
		part.Size = Vector3.one
		part.Transparency = 0.2
		part.Position = pos
		part.Parent = Workspace
		TweenService:Create(part, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.one * 9,
			Transparency = 1,
		}):Play()
		task.delay(0.7, function()
			part:Destroy()
		end)
	end

	------------------------------------------------------------------
	-- Per-character binding (sounds, death, new parts)
	------------------------------------------------------------------
	local function unbind(o)
		for _, c in ipairs(o.Conns) do
			c:Disconnect()
		end
		o.Conns, o.Sounds = {}, {}
		restoreChams(o)
		o.Applied, o.Dirty = nil, true
		o.Char = nil
	end

	local function bind(o, character, humanoid, root)
		unbind(o)
		o.Char = character
		for _, d in ipairs(character:GetDescendants()) do
			if d:IsA("Sound") then
				table.insert(o.Sounds, d)
			end
		end
		table.insert(o.Conns, character.DescendantAdded:Connect(function(d)
			if d:IsA("Sound") then
				table.insert(o.Sounds, d)
			end
			o.Dirty = true
		end))
		table.insert(o.Conns, humanoid.Died:Connect(function()
			if Cfg.Enabled and Cfg.KillEffect.On and root.Parent then
				killEffect(root.Position)
			end
		end))
	end

	local function clearObject(o)
		if o.RagHL then
			o.RagHL.Enabled = false -- ragdoll chams are redrawn by process() after this call when they apply
		end
		if o.ShotHL then
			o.ShotHL.Enabled = false
		end
		if o.Cleared then
			return
		end
		o.Cleared = true
		hideDrawing(o)
		o.Container.Visible = false
		unbind(o)
		for _, field in ipairs({ "WallHL", "GlowHL" }) do
			if o[field] then
				o[field].Enabled = false
			end
		end
		if o.WallAdorn then
			for _, a in pairs(o.WallAdorn) do
				a.Visible = false
			end
		end
	end

	local function destroyObject(plr)
		local o = objects[plr]
		if o then
			clearObject(o)
			for _, field in ipairs({ "WallHL", "GlowHL", "RagHL", "ShotHL" }) do
				if o[field] then
					o[field]:Destroy()
				end
			end
			if o.WallAdorn then
				for _, a in pairs(o.WallAdorn) do
					a:Destroy()
				end
			end
			o.Container:Destroy()
			objects[plr] = nil
		end
	end

	------------------------------------------------------------------
	-- Drawing one enemy
	------------------------------------------------------------------
	local function sideEntries(o, plr, character, humanoid, dist, items, layout)
		local sides = { Top = {}, Bottom = {}, Left = {}, Right = {} }
		for key, place in pairs(layout) do
			if items[key] and sides[place.Side] then
				local kind = espKind(key) or "flag"
				local entry
				if key == "Main/Name" then
					entry = { Kind = "text", Text = plr.DisplayName }
				elseif key == "Main/Distance" then
					entry = { Kind = "text", Text = string.format("%dm", math.floor(dist * STUDS_TO_METERS + 0.5)) }
				elseif key == "Weapon/Text" then
					local name = Adapter.GetWeaponName and Adapter.GetWeaponName(plr, character)
					if type(name) == "string" and name ~= "" then
						entry = { Kind = "text", Text = name }
					end
				elseif key == "Main/Health Bar" then
					local hp, max = Adapter.GetHealth(plr, character, humanoid)
					if type(hp) == "number" and type(max) == "number" and max > 0 and hp == hp and max == max then
						entry = { Kind = "bar", Fraction = math.clamp(hp / max, 0, 1), Value = tostring(math.floor(hp + 0.5)) }
					end
				elseif key == "Main/Ammo Bar" or key == "Weapon/Readiness Bar" then
					local fn = if key == "Main/Ammo Bar" then Adapter.GetAmmo else Adapter.GetReadiness
					local f = fn and fn(plr, character)
					if type(f) == "number" and f == f then
						entry = { Kind = "bar", Fraction = math.clamp(f, 0, 1) }
					end
				elseif kind == "flag" then
					local fn = Adapter.Flags[key]
					local v = fn and fn(plr, character)
					if v == true then
						local look = FLAG_LOOK[key]
						entry = { Kind = "flag", Text = if look and look.Text then look.Text else string.upper(string.match(key, "/(.+)$") or key) }
					elseif type(v) == "string" then
						entry = { Kind = "flag", Text = v }
					end
				end
				if key == "Weapon/Icon" then
					-- MEASURED: ReplicatedStorage.GetIcon.getWeaponOfKiller(weapon name) returns the killfeed icon image
					local name = Adapter.GetWeaponName and Adapter.GetWeaponName(plr, character)
					local image = type(name) == "string" and Adapter.GetWeaponIcon(name)
					if image then
						entry = { Kind = "icon", Image = image }
					end
				end
				if entry then
					entry.Key, entry.Order, entry.Style = key, place.Order, styleOf(key)
					table.insert(sides[place.Side], entry)
				end
			end
		end
		for _, list in pairs(sides) do
			table.sort(list, function(a, b)
				if a.Order ~= b.Order then
					return a.Order < b.Order
				end
				return a.Key < b.Key
			end)
		end
		return sides
	end

	local ICON_W, ICON_H = 48, 16
	-- the "Icon Size" setting of the item is a percentage of the default size
	local function iconSize(entry)
		local k = (entry.Style.IconSize or 100) / 100
		return ICON_W * k, ICON_H * k
	end
	local function textHeight(entry)
		if entry.Kind == "icon" then
			local _, h = iconSize(entry)
			return h
		end
		return if entry.Kind == "flag" then 12 else entry.Style.Size + 3
	end

	local function drawBox(o, plr, character, humanoid, box, dist, items, layout)
		local L, T, R, B = box.L, box.T, box.R, box.B
		local W, H = R - L, B - T
		local cx = (L + R) / 2

		if items["Main/Bounding Box"] then
			local s = styleOf("Main/Bounding Box")
			o.Box.Visible = true
			o.Box.Position = UDim2.fromOffset(math.floor(L), math.floor(T))
			o.Box.Size = UDim2.fromOffset(math.floor(W), math.floor(H))
			o.BoxStroke.Color = s.Color
			o.BoxStroke.Thickness = s.Thickness
			o.Box.BackgroundColor3 = s.Color
			o.Box.BackgroundTransparency = if s.Fill then 0.85 else 1
		end

		local sides = sideEntries(o, plr, character, humanoid, dist, items, layout)

		local y = T - 3 -- Top: grows upwards, order 1 nearest the box
		for _, e in ipairs(sides.Top) do
			local pe = if e.Kind == "bar" then poolBar(o, e.Key) elseif e.Kind == "icon" then poolIcon(o, e.Key) else poolText(o, e.Key)
			if e.Kind == "bar" then
				local t = e.Style.Thickness
				y -= t
				placeBar(pe, e.Style, L, y, W, t, false, e.Fraction, if e.Style.ShowValue then e.Value else nil)
			elseif e.Kind == "icon" then
				local iw, ih = iconSize(e)
				y -= ih
				placeIcon(pe, e.Image, e.Style, cx, y, iw, ih, 0.5)
			else
				local h = textHeight(e)
				y -= h
				placeText(pe, e.Text, e.Style, e.Kind == "flag", cx, y, 300, h, 0.5, Enum.TextXAlignment.Center)
			end
			y -= 2
		end

		y = B + 3 -- Bottom: grows downwards
		for _, e in ipairs(sides.Bottom) do
			local pe = if e.Kind == "bar" then poolBar(o, e.Key) elseif e.Kind == "icon" then poolIcon(o, e.Key) else poolText(o, e.Key)
			if e.Kind == "bar" then
				local t = e.Style.Thickness
				placeBar(pe, e.Style, L, y, W, t, false, e.Fraction, if e.Style.ShowValue then e.Value else nil)
				y += t
			elseif e.Kind == "icon" then
				local iw, ih = iconSize(e)
				placeIcon(pe, e.Image, e.Style, cx, y, iw, ih, 0.5)
				y += ih
			else
				local h = textHeight(e)
				placeText(pe, e.Text, e.Style, e.Kind == "flag", cx, y, 300, h, 0.5, Enum.TextXAlignment.Center)
				y += h
			end
			y += 2
		end

		-- Left / Right: bars are columns next to the box, every other element forms one text stack outside them
		for _, side in ipairs({ "Left", "Right" }) do
			local left = side == "Left"
			local x = if left then L - 4 else R + 4
			for _, e in ipairs(sides[side]) do
				if e.Kind == "bar" then
					local pe = poolBar(o, e.Key)
					local t = e.Style.Thickness
					local showValue = e.Style.ShowValue and e.Value
					if left then
						x -= t
					end
					placeBar(pe, e.Style, x, T, t, H, true, e.Fraction, if showValue then e.Value else nil, not left)
					if left then
						x -= 3 + (if showValue then 22 else 0)
					else
						x += t + 3 + (if showValue then 22 else 0)
					end
				end
			end
			local sy = T
			for _, e in ipairs(sides[side]) do
				if e.Kind ~= "bar" then
					local h = textHeight(e)
					if e.Kind == "icon" then
						local iw = iconSize(e)
						placeIcon(poolIcon(o, e.Key), e.Image, e.Style, x, sy, iw, h, if left then 1 else 0)
					else
						placeText(
							poolText(o, e.Key), e.Text, e.Style, e.Kind == "flag",
							x, sy, 200, h, if left then 1 else 0,
							if left then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
						)
					end
					sy += h + 1
				end
			end
		end

		if items["Main/Skeleton"] then
			local s = styleOf("Main/Skeleton")
			local n = 0
			for _, pair in ipairs(SKELETON) do
				local a, b = character:FindFirstChild(pair[1]), character:FindFirstChild(pair[2])
				if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
					local cam = Workspace.CurrentCamera
					local va, vb = cam:WorldToViewportPoint(a.Position), cam:WorldToViewportPoint(b.Position)
					if va.Z > 0 and vb.Z > 0 then
						n += 1
						placeLine(o, n, Vector2.new(va.X, va.Y), Vector2.new(vb.X, vb.Y), s.Color, s.Thickness)
					end
				end
			end
		end
	end

	local function drawArrow(o, cam, rootPos, viewport)
		local rel = cam.CFrame:PointToObjectSpace(rootPos)
		local center = viewport / 2
		local dir
		if rel.Z < 0 then
			-- in front of the camera but outside the viewport: the real screen direction (the projection is valid here)
			local v = cam:WorldToViewportPoint(rootPos)
			dir = Vector2.new(v.X, v.Y) - center
		else
			-- behind the camera the projection mirrors, so use the bearing: screen right = camera right, screen down = behind
			dir = Vector2.new(rel.X, rel.Z)
		end
		if dir.Magnitude < 1e-4 then
			dir = Vector2.new(0, 1)
		end
		dir = dir.Unit
		local arrow = o.Arrow
		if not arrow then
			arrow = create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(20, 20),
				BackgroundTransparency = 1,
				Parent = o.Container,
			})
			-- GuiObject.Rotation turns an element around its own centre (not its AnchorPoint), so each bar is placed with one end on
			-- the tip (20, 10) of the 20x20 arrow frame; together they form a ">" pointing right.
			local half, rad = 13 / 2, math.rad(35)
			for _, side in ipairs({ -1, 1 }) do
				create("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(20 - half * math.cos(rad), 10 + side * half * math.sin(rad)),
					Size = UDim2.fromOffset(13, 3),
					Rotation = -side * 35,
					BorderSizePixel = 0,
					Parent = arrow,
				})
			end
			o.Arrow = arrow
		end
		local radius = math.min(viewport.X, viewport.Y) * 0.42
		local at = center + dir * radius
		arrow.Visible = true
		arrow.Position = UDim2.fromOffset(at.X, at.Y)
		arrow.Rotation = math.deg(math.atan2(dir.Y, dir.X))
		for _, c in ipairs(arrow:GetChildren()) do
			c.BackgroundColor3 = Cfg.Arrow.Color
		end
	end

	-- MEASURED (Modules.DamagePrediction): after a kill the game clones player.Ragdoll into workspace.Debris under the
	-- player's name (the clone has a Humanoid2). A character the game already treats as dead is moved to
	-- ReplicatedStorage.DeathFolder, i.e. out of the workspace.
	local function ragdollChams(o, plr, cam)
		local cfg = Cfg.Chams["Ragdolls"]
		local debris = Workspace:FindFirstChild("Debris")
		local model = debris and debris:FindFirstChild(plr.Name)
		local on = cfg.Material ~= nil and model ~= nil and model:IsA("Model") and model:FindFirstChild("Humanoid2") ~= nil
		setHighlight(o, "RagHL", model, cam, on, {
			FillColor = cfg.Color,
			FillTransparency = if cfg.Material then HIGHLIGHT_FILL[cfg.Material.Name] or 0.5 else 1,
			OutlineColor = cfg.Color,
			OutlineTransparency = 0,
			DepthMode = Enum.HighlightDepthMode.Occluded,
		})
	end

	local function process(plr, cam, viewport, now)
		local o = objects[plr] or newObject(plr)
		local character = plr.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local head = character and character:FindFirstChild("Head")
		if
			not (humanoid and root and head and root:IsA("BasePart") and head:IsA("BasePart"))
			or not Adapter.IsAlive(plr, humanoid)
			or not character:IsDescendantOf(Workspace)
		then
			clearObject(o)
			ragdollChams(o, plr, cam)
			return
		end
		local rootPos = root.Position
		if not (rootPos.X == rootPos.X and rootPos.Y == rootPos.Y and rootPos.Z == rootPos.Z and rootPos.Magnitude < 1e6) then
			clearObject(o)
			ragdollChams(o, plr, cam)
			return
		end
		ragdollChams(o, plr, cam)
		o.Cleared = false
		o.Container.Visible = true
		if o.Char ~= character then
			bind(o, character, humanoid, root)
		end

		-- chams
		local pl, bw = Cfg.Chams["Player"], Cfg.Chams["Behind Walls"]
		applyChams(o, character, pl.Material, pl.Color)
		setWallAdorn(o, character, bw.Material ~= nil, bw.Color, if bw.Material then HIGHLIGHT_FILL[bw.Material.Name] or 0.5 else 1)
		local os_cfg = Cfg.Chams["On Shot"]
		local shotOn = os_cfg.Material ~= nil and (shots[plr] or 0) > now
		setHighlight(o, "ShotHL", character, cam, shotOn, {
			FillColor = os_cfg.Color,
			FillTransparency = if os_cfg.Material then HIGHLIGHT_FILL[os_cfg.Material.Name] or 0.5 else 1,
			OutlineColor = os_cfg.Color,
			OutlineTransparency = 0,
			DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		})
		setHighlight(o, "GlowHL", character, cam, Cfg.Glow.On, {
			FillColor = Cfg.Glow.Color,
			FillTransparency = 1,
			OutlineColor = Cfg.Glow.Color,
			OutlineTransparency = 0,
			DepthMode = Enum.HighlightDepthMode.Occluded,
		})

		-- sound rings: any Sound inside the character that is playing
		if Cfg.Sounds.On and now - o.LastRing >= RING_GAP then
			for i = #o.Sounds, 1, -1 do
				local s = o.Sounds[i]
				if not s.Parent then
					table.remove(o.Sounds, i)
				elseif s.IsPlaying and s.Volume > 0 then
					o.LastRing = now
					local feet = rootPos - Vector3.new(0, 3, 0)
					addRing(feet, Cfg.Sounds.Color)
					break
				end
			end
		end

		hideDrawing(o)
		local v = cam:WorldToViewportPoint(rootPos)
		local offscreen = v.Z <= 0 or v.X < 0 or v.Y < 0 or v.X > viewport.X or v.Y > viewport.Y
		if offscreen then
			if Cfg.Arrow.On then
				drawArrow(o, cam, rootPos, viewport)
			end
			return
		end

		-- box from head top to feet (world up), width = 0.55 * height
		local feetDrop = if humanoid.HipHeight > 0 then humanoid.HipHeight + root.Size.Y / 2 else 3
		local top = cam:WorldToViewportPoint(head.Position + Vector3.new(0, head.Size.Y / 2 + 0.15, 0))
		local bot = cam:WorldToViewportPoint(rootPos - Vector3.new(0, feetDrop, 0))
		if top.Z <= 0 or bot.Z <= 0 then
			return
		end
		local h = bot.Y - top.Y
		if h < 4 or h > 4000 then
			return
		end
		local w = h * 0.55
		local cx = (top.X + bot.X) / 2
		local dist = (cam.CFrame.Position - rootPos).Magnitude
		drawBox(o, plr, character, humanoid, { L = cx - w / 2, T = top.Y, R = cx + w / 2, B = bot.Y }, dist, cache.Items, cache.Layout)
	end

	local lastError
	-- runs after the aspect stretch (World FX binds before Last), so screen positions match the rendered image
	pcall(RunService.UnbindFromRenderStep, RunService, "EnemyESP")
	RunService:BindToRenderStep("EnemyESP", Enum.RenderPriority.Last.Value, function()
		local cam = Workspace.CurrentCamera
		if not cam or not preview then
			return
		end
		local now = os.clock()
		if now - cache.Stamp > 0.25 then
			refreshCache()
		end
		local seen = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			local o = objects[plr]
			if Cfg.Enabled and Adapter.IsEnemy(plr) then
				seen[plr] = true
				local ok, err = pcall(process, plr, cam, cam.ViewportSize, now)
				if not ok and err ~= lastError then
					lastError = err
					warn("[EnemyESP] " .. tostring(err))
					if logLine then
						logLine("Enemy ESP error, see console")
					end
				end
			elseif o then
				clearObject(o)
			end
		end
		for plr, o in pairs(objects) do
			if not seen[plr] and plr.Parent == nil then
				destroyObject(plr)
			end
		end
		stepRings(cam, now)
	end)
	Players.PlayerRemoving:Connect(destroyObject)

	-- Unload: stop drawing, restore every character's materials / clothing, remove highlights and the overlay
	table.insert(Unloaders, function()
		Cfg.Enabled = false
		pcall(RunService.UnbindFromRenderStep, RunService, "EnemyESP")
		for plr in pairs(objects) do
			pcall(destroyObject, plr)
		end
		for _, r in ipairs(rings) do
			r.Frame:Destroy()
		end
		rings = {}
		gui:Destroy()
	end)

	function EnemyESP.Bind(p, log)
		preview, logLine = p, log
		refreshCache()
	end
end

-- Rage silent aim state. Defaults equal the defaults of the Rage controls below; the controls write into Cfg.
local SilentAim = {
	Cfg = {
		Enabled = true, Silent = true, Target = "Highest Damage", Fov = 180,
		Hitboxes = { "Head", "Chest", "Stomach" }, HitChance = 0, MinDamage = 0, NoSpread = true, AutoFire = true,
		Walls = false, MaxWalls = 3, Multipoint = { "Head" }, Prediction = 0, WallK = 8.67, WallC = 1,
		Visualize = false, VisualizeColor = rgb(235, 235, 240),
	},
	AA = { Enabled = true, Manual = false, ManualDir = "None", Keys = { Left = Enum.KeyCode.Left, Right = Enum.KeyCode.Right, Forward = Enum.KeyCode.Up, Back = Enum.KeyCode.Down }, Yaw = "Backwards", Pitch = "Off", Freestanding = "Off" },
	Stats = { Hooked = false, Calls = 0, Rewritten = 0, Skipped = 0, NoSpread = 0, Shots = 0, Last = "none" },
}
do
	local warned = {}
	function SilentAim.Unwired(name, reason)
		if not warned[name] then
			warned[name] = true
			menu:Log(name .. ": not active, " .. reason)
		end
	end
end

menu:AddCategory("Aimbot")
local rage = menu:AddTab("Rage", "crosshair", { Options = true })
local legit = menu:AddTab("Legit", "mouse", { Options = true })

menu:AddCategory("Common")
local visuals = menu:AddTab("Visuals", "image")
local players = visuals:AddSubTab("Players", "user")
local world = visuals:AddSubTab("World", "globe")
local inventory = menu:AddTab("Inventory", "layers")
local misc = menu:AddTab("Miscellaneous", "panel")

------------------------------------------------------------------
-- Rage (layout from the video)
------------------------------------------------------------------
do
	local main = rage:AddSection("Main", "Left")
	main:AddToggle("Enabled", true, function(v)
			SilentAim.Cfg.Enabled = v
		end):AddSettings(270, "Enabled")
	main:AddDropdown("Target", { "Highest Damage", "Closest To Crosshair", "Lowest Health", "Distance" }, "Highest Damage", function(v)
			SilentAim.Cfg.Target = v
		end)
	main:AddSlider("Field of View", 0, 180, 180, function(v)
			SilentAim.Cfg.Fov = v
		end,"°", { Decimals = 1 })
	main:AddToggle("Silent Aim", true, function(v)
			SilentAim.Cfg.Silent = v
		end):AddSettings(270, "Silent Aim")
	main:AddToggle("Automatic Fire", true, function(v)
			SilentAim.Cfg.AutoFire = v
		end)
	main:AddToggle("Origin Scan", true, noop):AddSettings(270, "Origin Scan")
	main:AddSlider("Max Walls", 0, 5, 3, function(v)
			SilentAim.Cfg.MaxWalls = v
		end, "w")

	local selection = rage:AddSection("Selection", "Left")
	selection:AddMultiDropdown("Hitboxes", { "Head", "Chest", "Stomach", "Arms", "Legs" }, { "Head", "Chest", "Stomach" }, function(list)
			SilentAim.Cfg.Hitboxes = list
		end)
	selection:AddMultiDropdown("Multipoint", { "Head", "Chest", "Stomach", "Arms", "Legs" }, { "Head" }, function(list)
			SilentAim.Cfg.Multipoint = list
		end)
	selection:AddSlider("Hit Chance", 0, 100, 0, function(v)
			SilentAim.Cfg.HitChance = v
		end,"%", {
		Format = function(v)
			return if v == 0 then "Auto" else nil
		end,
	})
	selection:AddSlider("Min Damage", 0, 100, 0, function(v)
			SilentAim.Cfg.MinDamage = v
		end,nil, {
		Format = function(v)
			return if v == 0 then "any" else nil
		end,
	})
	selection:AddSlider("Prediction", 0, 300, 0, function(v)
			SilentAim.Cfg.Prediction = v
		end, "ms")
		selection:AddToggle("Quick Stop", false, Feat.unwired("Rage Quick Stop", "the rage target state is local to the silent-aim block; use Miscellaneous > Standalone Quick Stop, which cancels movement while the fire button is held")):AddSettings(250, "Quick Stop")
	selection:AddToggle("Quick Scope", false, Feat.unwired("Rage Quick Scope", Feat.Notes.Scope))

	local other = rage:AddSection("Other", "Right")
	other:AddDropdown("History", { "Low", "Medium", "High", "Maximum" }, "High", function(v) if v ~= "High" then Feat.gate("History", Feat.Notes.Server) end end)
	other:AddDropdown("Delay Shot", { "None", "Damage", "Hit Chance" }, "None", function(v) if v ~= "None" then Feat.gate("Delay Shot", Feat.Notes.Server) end end)
	other:AddToggle("Remove Recoil", false, Feat.unwired("Remove Recoil", Feat.Notes.Recoil)):AddSettings(250, "Remove Recoil")
	other:AddToggle("Remove Spread", true, function(v)
		SilentAim.Cfg.NoSpread = v
	end)
	other:AddToggle("Duck Peek Assist", false, Feat.unwired("Duck Peek Assist", Feat.Notes.Crouch))
	local peek = other:AddToggle("Peek Assist", false, function(v) Feat.PeekAssist = v end):AddSettings(260, "Peek Assist")
	peek:AddColorPicker("Color", Color3.fromRGB(240, 60, 70), function(c) Feat.PeekColor = c end)
	peek:AddSlider("Max Distance", 0, 50, 25, function(v) Feat.PeekMax = v end, "m")
	peek:AddDropdown("Retreat Mode", { "Off", "Always", "Only While Standing" }, "Off", function(v) Feat.PeekRetreat = v end)
	other:AddToggle("Fast Reload", false, Feat.unwired("Fast Reload", Feat.Notes.Timing)):AddSettings(250, "Fast Reload")
	other:AddToggle("Auto Reload", false, Feat.unwired("Auto Reload", Feat.Notes.Timing)):AddSettings(250, "Auto Reload")
	local rageVisualize = other:AddToggle("Visualize", false, function(v)
		SilentAim.Cfg.Visualize = v
	end):AddSettings(250, "Visualize")
	rageVisualize:AddColorPicker("Color", SilentAim.Cfg.VisualizeColor, function(c)
		SilentAim.Cfg.VisualizeColor = c
	end)

	local aa = rage:AddSection("Anti Aim", "Right")
	aa:AddToggle("Enabled", true, function(v)
		SilentAim.AA.Enabled = v
	end):AddSettings(250, "Anti Aim")
	do
		local manuals = aa:AddToggle("Manuals", false, function(v)
			SilentAim.AA.Manual = v
		end):AddSettings(250, "Manuals")
		-- the direction is relative to the camera: Forward = body faces where you look, Back = away, Left / Right = sideways
		SilentAim.AA.ManualDropdown = manuals:AddDropdown("Direction", { "None", "Left", "Right", "Forward", "Back" }, "None", function(v)
			SilentAim.AA.ManualDir = v
		end)
		for _, name in ipairs({ "Left", "Right", "Forward", "Back" }) do
			manuals:AddKeybind(name .. " Key", SilentAim.AA.Keys[name], function(k)
				SilentAim.AA.Keys[name] = if k and k ~= Enum.KeyCode.Unknown then k else nil -- unbound keys do nothing
			end, true)
		end
	end
	aa:AddDropdown("Yaw", { "Off", "Backwards", "At Targets", "Spin" }, "Backwards", function(v)
		SilentAim.AA.Yaw = v
	end)
	aa:AddDropdown("Pitch", { "Off", "Down", "Up", "Zero" }, "Off", function(v)
		SilentAim.AA.Pitch = v
	end)
	aa:AddDropdown("Freestanding", { "Off", "Peek Fake", "Peek Real" }, "Off", function(v)
		SilentAim.AA.Freestanding = v
		if v ~= "Off" then
			SilentAim.Unwired("Freestanding", "needs wall probing for the peek side, not implemented")
		end
	end)
end

------------------------------------------------------------------
-- Legit engine: aim lock (camera pull) and triggerbot.
-- Angles in degrees, world is Y-up. FOV is a radius: a target counts when the angle between the camera's
-- look direction and the direction to the hitbox is <= Field of View.
-- Not measured on BloxStrike (so not enforced): damage, smoke, flash, recoil, scope state.
------------------------------------------------------------------
local LegitAim = {}
do
	local Workspace = game:GetService("Workspace")
	local AIM_KEY = Enum.UserInputType.MouseButton2 -- "On Key" activation: hold this
	local FIRE_KEY = Enum.UserInputType.MouseButton1 -- "Assisted" activation: while the player fires
	local MIN_PRESS = 0.03 -- seconds, shortest synthetic press
	local SEMI_AUTO_GAP = 0.12 -- seconds between synthetic clicks when Automatic Weapons is off
	local MAX_RANGE = 2000
	local HITBOX_PARTS = {
		-- MEASURED in ReplicatedStorage.Modules.BulletCast: bullets only collide with these character parts
		-- (HeadHB is the head hitbox: IsHeadShot is `Name == "HeadHB"`); Head / FakeHead / HumanoidRootPart do not count.
		Head = { "HeadHB" },
		Chest = { "UpperTorso" },
		Stomach = { "LowerTorso" },
	}
	-- MEASURED: BulletCast limb modifiers and the list of parts that take hits
	local LIMB_MODIFIER = {
		HeadHB = 4, UpperTorso = 1, LowerTorso = 1.25,
		RightUpperArm = 1, LeftUpperArm = 1, RightLowerArm = 1, LeftLowerArm = 1, RightHand = 1, LeftHand = 1,
		RightUpperLeg = 0.75, LeftUpperLeg = 0.75, RightLowerLeg = 0.75, LeftLowerLeg = 0.75, RightFoot = 0.75, LeftFoot = 0.75,
	}
	local NOISE_DEG = { Off = 0, Low = 0.15, Medium = 0.35, High = 0.7 } -- aim point scatter per target
	local NOISE_TIME = { Off = 0, Low = 0.1, Medium = 0.25, High = 0.5 } -- relative jitter of reaction time

	local Cfg = {
		Master = false,
		Aim = {
			Enabled = false, Activation = "Assisted", Conditions = { "Through Smokes", "Jumping" }, Hitboxes = { "Head" },
			Fov = 20, Smoothing = 15, Reaction = 200, MinDamage = 1, QuickStop = false,
		},
		Trigger = {
			Enabled = false, Conditions = { "Through Smokes", "Jumping" }, Hitboxes = { "Head", "Chest", "Stomach" },
			HitChance = 50, Reaction = 200, Burst = 50, MinDamage = 0,
		},
		Other = { Visualize = false, VisualizeColor = rgb(235, 235, 240), Automatic = false, Randomize = "Low" },
	}
	LegitAim.Cfg = Cfg

	local rng = Random.new()
	local isMenuOpen, logLine
	local warned = {}
	function LegitAim.Unwired(name, reason)
		if not warned[name] then
			warned[name] = true
			if logLine then
				logLine(name .. ": not active, " .. reason)
			end
		end
	end

	local focused = true
	UserInputService.WindowFocused:Connect(function()
		focused = true
	end)

	------------------------------------------------------------------
	-- Synthetic fire. Order: executor mouse1press/mouse1release, then Tool:Activate (click only).
	-- Which of them works in BloxStrike is not verified.
	------------------------------------------------------------------
	local fireMethod
	local function resolveFire()
		if fireMethod then
			return fireMethod
		end
		-- executor globals; a plain Roblox script has none of them and reads nil
		local ok, press, release = pcall(function()
			return mouse1press, mouse1release
		end)
		if ok and type(press) == "function" and type(release) == "function" then
			fireMethod = { Name = "mouse1press", Press = press, Release = release }
		else
			fireMethod = {
				Name = "Tool:Activate",
				Press = function()
					local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
					if tool then
						tool:Activate()
					end
				end,
				Release = function() end,
			}
		end
		if logLine then
			logLine("Triggerbot fire method: " .. fireMethod.Name)
		end
		return fireMethod
	end

	local pressedAt -- os.clock() of our own synthetic press, nil when released
	local function releaseFire()
		if pressedAt then
			pressedAt = nil
			pcall(resolveFire().Release)
		end
	end
	UserInputService.WindowFocusReleased:Connect(function()
		focused = false
		releaseFire()
	end)

	------------------------------------------------------------------
	-- Targeting
	------------------------------------------------------------------
	local function has(list, name)
		return table.find(list, name) ~= nil
	end

	local function localAlive()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			return character, humanoid
		end
		return nil
	end

	-- MEASURED (ReplicatedStorage.Modules.Blind): while flashed, PlayerGui.Blnd.Blind.BackgroundTransparency = 1 - blindness
	local function localFlashed()
		local gui = player:FindFirstChild("PlayerGui")
		local blnd = gui and gui:FindFirstChild("Blnd")
		local overlay = blnd and blnd:FindFirstChild("Blind")
		return overlay ~= nil and overlay.BackgroundTransparency < 0.99
	end

	local function blockedByConditions(conditions, humanoid)
		if not has(conditions, "Jumping") then
			local state = humanoid:GetState()
			if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
				return true
			end
		end
		if not has(conditions, "Flashed") and localFlashed() then
			return true
		end
		return false
	end

	-- Estimated damage of one bullet of the weapon the local player holds (character.EquippedTool -> ReplicatedStorage.Weapons).
	-- MEASURED: DMG, RangeModifier, ArmorPenetration values, the limb modifiers and GetDamageFallOff
	-- (DMG * limb * clamp((RangeModifier / 100) ^ (max(0, distance - 18) / 31.25), 0.05, 1)).
	-- ASSUMED: the distance is in studs, and an armored hit (Kevlar > 0, head also needs Helmet > 0, not a leg)
	-- is scaled by ArmorPenetration / 100. Returns nil when any input is missing (then no damage filter applies).
	local function estimateDamage(plr, part, dist)
		local character = player.Character
		local equipped = character and character:FindFirstChild("EquippedTool")
		local weapons = game:GetService("ReplicatedStorage"):FindFirstChild("Weapons")
		local weapon = weapons and equipped and equipped:IsA("StringValue") and equipped.Value ~= "" and weapons:FindFirstChild(equipped.Value)
		local dmg = weapon and weapon:FindFirstChild("DMG")
		local rangeModifier = weapon and weapon:FindFirstChild("RangeModifier")
		local limb = LIMB_MODIFIER[part.Name]
		if not (dmg and rangeModifier and limb) then
			return nil
		end
		local damage = dmg.Value * limb * math.clamp((rangeModifier.Value / 100) ^ (math.max(0, dist - 18) / 31.25), 0.05, 1)
		local penetration = weapon:FindFirstChild("ArmorPenetration")
		local kevlar, helmet = plr:FindFirstChild("Kevlar"), plr:FindFirstChild("Helmet")
		local armored = penetration and kevlar and kevlar.Value > 0 and limb ~= 0.75
			and (part.Name ~= "HeadHB" or (helmet ~= nil and helmet.Value > 0))
		if armored then
			damage *= penetration.Value / 100
		end
		return damage
	end

	local function enemyCharacter(plr)
		if not EnemyESP.Adapter.IsEnemy(plr) then
			return nil
		end
		local character = plr.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and EnemyESP.Adapter.IsAlive(plr, humanoid) and character:IsDescendantOf(Workspace) then
			return character
		end
		return nil
	end

	local function hitboxParts(character, hitboxes)
		local out = {}
		for _, box in ipairs(hitboxes) do
			for _, name in ipairs(HITBOX_PARTS[box] or {}) do
				local part = character:FindFirstChild(name)
				if part and part:IsA("BasePart") then
					table.insert(out, part)
					break
				end
			end
		end
		return out
	end

	-- A ray that sees the world the way the game's bullets do (MEASURED in BulletCast.GetIncludeList / IsBlacklisted):
	-- only Map.Geometry, Map.Regen, the smokes (workspace.Ray_Ignore.Smokes) and the hit parts of the given characters
	-- collide; invisible (Transparency 1) parts that are not hit parts or smoke are skipped.
	-- The smokes folder is read from the server side of that module; that it exists on the client is not verified.
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.IgnoreWater = true

	local function gameCast(origin, vector, throughSmokes, characters)
		local map = Workspace:FindFirstChild("Map")
		if not map then
			return nil
		end
		local include = {}
		for _, name in ipairs({ "Geometry", "Regen" }) do
			local folder = map:FindFirstChild(name)
			if folder then
				table.insert(include, folder)
			end
		end
		if not throughSmokes then
			local ignore = Workspace:FindFirstChild("Ray_Ignore")
			local smokes = ignore and ignore:FindFirstChild("Smokes")
			if smokes then
				table.insert(include, smokes)
			end
		end
		for _, character in ipairs(characters) do
			for _, child in ipairs(character:GetChildren()) do
				if LIMB_MODIFIER[child.Name] then
					table.insert(include, child)
				end
			end
		end
		rayParams.FilterDescendantsInstances = include
		local total = vector.Magnitude
		if total < 1e-3 then
			return nil
		end
		local unit = vector.Unit
		local from, remaining = origin, total
		for _ = 1, 8 do
			local result = Workspace:Raycast(from, unit * remaining, rayParams)
			if not result then
				return nil
			end
			local inst = result.Instance
			if inst:IsA("BasePart") and inst.Transparency == 1 and not LIMB_MODIFIER[inst.Name] and not inst:HasTag("Smoke") then
				local advance = (result.Position - from).Magnitude + 0.05
				from += unit * advance
				remaining -= advance
				if remaining <= 0 then
					return nil
				end
			else
				return result
			end
		end
		return nil
	end

	local function visibleFromCamera(cam, part, character, throughSmokes)
		local origin = cam.CFrame.Position
		local result = gameCast(origin, part.Position - origin, throughSmokes, { character })
		return result == nil or result.Instance:IsDescendantOf(character)
	end

	local function finite(v)
		return v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.Magnitude < 1e6
	end

	-- best enemy hitbox: smallest angle to the camera's look direction, inside fov, not behind a wall
	local function pickTarget(cam, hitboxes, fov, throughSmokes, minDamage)
		local origin, look = cam.CFrame.Position, cam.CFrame.LookVector
		local best
		for _, plr in ipairs(Players:GetPlayers()) do
			local character = enemyCharacter(plr)
			if character then
				for _, part in ipairs(hitboxParts(character, hitboxes)) do
					local pos = part.Position
					if finite(pos) then
						local delta = pos - origin
						local dist = delta.Magnitude
						if dist > 0.5 and dist < MAX_RANGE then
							local angle = math.deg(math.acos(math.clamp(look:Dot(delta.Unit), -1, 1)))
							if angle <= fov and (not best or angle < best.Angle) and visibleFromCamera(cam, part, character, throughSmokes) then
								local damage = if minDamage > 1 then estimateDamage(plr, part, dist) else nil
								if not damage or damage >= minDamage then
									best = { Plr = plr, Part = part, Angle = angle, Dist = dist }
								end
							end
						end
					end
				end
			end
		end
		return best
	end

	------------------------------------------------------------------
	-- Aim lock
	------------------------------------------------------------------
	local aim = { Plr = nil, ReadyAt = 0, Offset = Vector3.zero }

	local function aimActive(activation)
		if activation == "Always" then
			return true
		elseif activation == "On Key" then
			return UserInputService:IsMouseButtonPressed(AIM_KEY)
		end
		return UserInputService:IsMouseButtonPressed(FIRE_KEY) -- "Assisted": pulls while the player fires
	end

	local function aimStep(cam, dt, now, humanoid)
		local A = Cfg.Aim
		if not (Cfg.Master and A.Enabled) or not aimActive(A.Activation) or blockedByConditions(A.Conditions, humanoid) then
			aim.Plr = nil
			return
		end
		local target = pickTarget(cam, A.Hitboxes, A.Fov, has(A.Conditions, "Through Smokes"), A.MinDamage)
		if not target then
			aim.Plr = nil
			return
		end
		if target.Plr ~= aim.Plr then
			aim.Plr = target.Plr
			local jitter = 1 + (rng:NextNumber() * 2 - 1) * (NOISE_TIME[Cfg.Other.Randomize] or 0)
			aim.ReadyAt = now + (A.Reaction / 1000) * jitter
			local scatter = target.Dist * math.tan(math.rad(NOISE_DEG[Cfg.Other.Randomize] or 0)) * rng:NextNumber()
			local dir = Vector3.new(rng:NextNumber() * 2 - 1, rng:NextNumber() * 2 - 1, rng:NextNumber() * 2 - 1)
			aim.Offset = if dir.Magnitude > 1e-3 then dir.Unit * scatter else Vector3.zero
		end
		if now < aim.ReadyAt or target.Angle < 0.05 then
			return
		end
		local camPos = cam.CFrame.Position
		local goal = (target.Part.Position + aim.Offset - camPos).Unit
		local s = math.clamp(A.Smoothing, 0, 99) / 100
		local alpha = if s == 0 then 1 else 1 - s ^ (math.min(dt, 0.1) * 60) -- frame-rate independent pull
		local look = cam.CFrame.LookVector:Lerp(goal, alpha)
		if look.Magnitude > 1e-3 then
			look = look.Unit
			if math.abs(look.Y) < 0.999 then
				cam.CFrame = CFrame.lookAt(camPos, camPos + look)
			end
		end
	end

	------------------------------------------------------------------
	-- Triggerbot: fires while an allowed hitbox of an enemy is under the screen centre
	------------------------------------------------------------------
	local trig = { Since = nil, Roll = false, Delay = 0, LastClick = 0 }

	-- true when the first thing a bullet would hit from the screen centre is an allowed hit part of an enemy
	local function underCrosshair(cam, hitboxes, throughSmokes, minDamage)
		local vp = cam.ViewportSize
		local ray = cam:ViewportPointToRay(vp.X / 2, vp.Y / 2)
		local characters = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			local character = enemyCharacter(plr)
			if character then
				table.insert(characters, character)
			end
		end
		local result = gameCast(ray.Origin, ray.Direction * MAX_RANGE, throughSmokes, characters)
		if not result then
			return false
		end
		local model = result.Instance:FindFirstAncestorOfClass("Model")
		local plr = model and Players:GetPlayerFromCharacter(model)
		if not plr or enemyCharacter(plr) ~= model then
			return false
		end
		for _, box in ipairs(hitboxes) do
			if table.find(HITBOX_PARTS[box] or {}, result.Instance.Name) then
				local damage = if minDamage > 0 then estimateDamage(plr, result.Instance, (result.Position - ray.Origin).Magnitude) else nil
				return not damage or damage >= minDamage
			end
		end
		return false
	end

	local function triggerStep(cam, now, humanoid)
		local T = Cfg.Trigger
		if not (Cfg.Master and T.Enabled) or blockedByConditions(T.Conditions, humanoid) then
			trig.Since = nil
			releaseFire()
			return
		end
		-- the player's own held button is theirs: do not press or release it
		if not pressedAt and UserInputService:IsMouseButtonPressed(FIRE_KEY) then
			trig.Since = nil
			return
		end
		local automatic = Cfg.Other.Automatic
		local onTarget = underCrosshair(cam, T.Hitboxes, has(T.Conditions, "Through Smokes"), T.MinDamage)
		if pressedAt and (not automatic or not onTarget) and now - pressedAt >= math.max(T.Burst / 1000, MIN_PRESS) then
			releaseFire()
		end
		if not onTarget then
			trig.Since = nil
			return
		end
		if not trig.Since then
			trig.Since = now
			trig.Roll = rng:NextNumber() * 100 < T.HitChance -- chance is rolled once per time the crosshair lands on a target
			trig.Delay = (T.Reaction / 1000) * (1 + (rng:NextNumber() * 2 - 1) * (NOISE_TIME[Cfg.Other.Randomize] or 0))
		end
		if trig.Roll and now - trig.Since >= trig.Delay and not pressedAt and now - trig.LastClick >= SEMI_AUTO_GAP then
			local method = resolveFire()
			pressedAt, trig.LastClick = now, now
			pcall(method.Press)
		end
	end

	------------------------------------------------------------------
	-- Quick Stop. MEASURED (ControlScript.MasterControl): AddToPlayerMovement(v) adds v to the movement vector that
	-- GetMoveVector() returns; the keyboard code adds / removes its own contribution the same way. So the movement
	-- input is cancelled by adding -GetMoveVector() every frame while shooting at a target, and the removed amount
	-- is added back afterwards (not if the character changed meanwhile, so a respawn cannot leave a phantom input).
	------------------------------------------------------------------
	local masterControl
	local function getMasterControl()
		if masterControl then
			return masterControl
		end
		pcall(function()
			local scripts = player:FindFirstChild("PlayerScripts")
			local control = scripts and scripts:FindFirstChild("ControlScript")
			local module = control and control:FindFirstChild("MasterControl")
			local m = module and require(module)
			if type(m) == "table" and type(m.AddToPlayerMovement) == "function" and type(m.GetMoveVector) == "function" then
				masterControl = m
			end
		end)
		return masterControl
	end

	local qs = { Active = false, Removed = Vector3.zero, Char = nil }
	local function quickStopRestore()
		if not qs.Active then
			return
		end
		local removed, char = qs.Removed, qs.Char
		qs.Active, qs.Removed, qs.Char = false, Vector3.zero, nil
		local m = getMasterControl()
		if m and char and char == player.Character and char.Parent then
			pcall(m.AddToPlayerMovement, m, removed)
		end
	end

	local function quickStopStep()
		local firing = (aim.Plr ~= nil and (UserInputService:IsMouseButtonPressed(FIRE_KEY) or pressedAt ~= nil))
			or (Cfg.Trigger.Enabled and trig.Since ~= nil and trig.Roll)
		if not (Cfg.Master and Cfg.Aim.QuickStop and firing) then
			quickStopRestore()
			return
		end
		local m = getMasterControl()
		if not m then
			return
		end
		local ok, current = pcall(m.GetMoveVector, m)
		if not ok or typeof(current) ~= "Vector3" then
			return
		end
		if not qs.Active then
			qs.Active, qs.Char = true, player.Character
		end
		if current.Magnitude > 1e-4 then
			qs.Removed += current
			pcall(m.AddToPlayerMovement, m, -current)
		end
	end

	------------------------------------------------------------------
	-- FOV circle (Visualize)
	------------------------------------------------------------------
	local gui = create("ScreenGui", {
		Name = "LegitAimOverlay",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 5, -- above the game's own HUD; the circle does not take clicks
		Parent = player:WaitForChild("PlayerGui"),
	})
	local circle = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	}, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local circleStroke = Instance.new("UIStroke")
	circleStroke.Thickness = 1.5
	circleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	circleStroke.Color = Cfg.Other.VisualizeColor
	circleStroke.Parent = circle

	local function drawCircle(cam)
		local fov = Cfg.Aim.Fov
		if not Cfg.Other.Visualize or fov >= 89.5 then
			circle.Visible = false
			return
		end
		-- pixel radius of an angle on a perspective screen: tan(angle) / tan(verticalFov / 2) * half height
		local radius = math.tan(math.rad(fov)) / math.tan(math.rad(cam.FieldOfView) / 2) * (cam.ViewportSize.Y / 2)
		radius = math.clamp(radius, 1, 4000)
		circle.Visible = true
		circle.Size = UDim2.fromOffset(radius * 2, radius * 2)
		circleStroke.Color = Cfg.Other.VisualizeColor
	end

	local lastError
	pcall(RunService.UnbindFromRenderStep, RunService, "LegitAim") -- a second run of the script replaces the first
	RunService:BindToRenderStep("LegitAim",Enum.RenderPriority.Camera.Value + 1, function(dt)
		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end
		local ok, err = pcall(function()
			drawCircle(cam)
			local _, humanoid = localAlive()
			local blocked = not humanoid or not focused or (isMenuOpen and isMenuOpen()) or UserInputService:GetFocusedTextBox() ~= nil
			if blocked then
				aim.Plr, trig.Since = nil, nil
				releaseFire()
				quickStopRestore()
				return
			end
			local now = os.clock()
			aimStep(cam, dt, now, humanoid)
			triggerStep(cam, now, humanoid)
			quickStopStep()
		end)
		if not ok and err ~= lastError then
			lastError = err
			warn("[LegitAim] " .. tostring(err))
			if logLine then
				logLine("Legit error, see console")
			end
		end
	end)

	-- Unload: release a held synthetic click, give back the movement input Quick Stop removed, drop the overlay
	table.insert(Unloaders, function()
		Cfg.Master = false
		pcall(RunService.UnbindFromRenderStep, RunService, "LegitAim")
		pcall(releaseFire)
		pcall(quickStopRestore)
		gui:Destroy()
	end)

	-- shared with the Rage silent aim engine below
	LegitAim.Engine = {
		MAX_RANGE = MAX_RANGE,
		LIMB_MODIFIER = LIMB_MODIFIER,
		enemyCharacter = enemyCharacter,
		gameCast = gameCast,
		estimateDamage = estimateDamage,
		finite = finite,
		resolveFire = resolveFire,
	}

	function LegitAim.QuickStopActive()
		return qs.Active
	end

	function LegitAim.Bind(menuOpen, log)
		isMenuOpen, logLine = menuOpen, log
	end
end

------------------------------------------------------------------
-- Legit
------------------------------------------------------------------
do
	LegitAim.Bind(function()
		return menu._visible
	end, function(text)
		menu:Log(text)
	end)
	------------------------------------------------------------------
	-- Rage silent aim.
	-- MEASURED (shots.txt): a shot is one RemoteFunction call
	--   BulletHitreg:InvokeServer(origin: Vector3, direction: Vector3 (unit), hits: table, weapon: string, opts: table)
	-- origin equals the camera position, hits is {} for a miss, and a hit is one entry
	--   { Normal, Position, Instance (a HeadHB / UpperTorso / ... part), Distance = |Position - origin|, Falloff, Damage }
	-- with Falloff = 1 for an unobstructed hit. The client builds the hit, so silent aim replaces direction and hits of
	-- that call with a self-consistent hit on the chosen target; the camera is never moved.
	-- NOT verified: whether the server accepts the rewritten call (it may compare direction with the look it receives
	-- through ControlTurn, or recompute Damage). Status is printed to the menu log so this can be checked in-game.
	-- Not wired: wall penetration (Falloff < 1 formula not measured), Remove Spread / Recoil, Automatic Fire, Multipoint.
	------------------------------------------------------------------
	do
		local Workspace = game:GetService("Workspace")
		local E = LegitAim.Engine
		local Cfg = SilentAim.Cfg
		local Stats = SilentAim.Stats
		local REMOTE = "BulletHitreg"
		local PARTS = { -- part names MEASURED in LIMB_MODIFIER (BulletCast)
			Head = { "HeadHB" },
			Chest = { "UpperTorso" },
			Stomach = { "LowerTorso" },
			Arms = { "RightUpperArm", "LeftUpperArm", "RightLowerArm", "LeftLowerArm", "RightHand", "LeftHand" },
			Legs = { "RightUpperLeg", "LeftUpperLeg", "RightLowerLeg", "LeftLowerLeg", "RightFoot", "LeftFoot" },
		}
		local rng = Random.new()
		local alive = true
		local lastError = nil

		local function log(text)
			pcall(function()
				menu:Log(text)
			end)
		end

		-- score: bigger is better
		local function score(mode, damage, angle, health, dist)
			if mode == "Closest To Crosshair" then
				return -angle
			elseif mode == "Lowest Health" then
				return -health
			elseif mode == "Distance" then
				return -dist
			end
			return damage -- "Highest Damage"
		end

		local function has(list, name)
			return table.find(list, name) ~= nil
		end

		-- the parts of the chosen hitboxes, each tagged with its hitbox name (needed for Multipoint)
		local function partsOf(character, boxes)
			local out = {}
			for _, box in ipairs(boxes) do
				for _, name in ipairs(PARTS[box] or {}) do
					local part = character:FindFirstChild(name)
					if part and part:IsA("BasePart") then
						table.insert(out, { Part = part, Box = box })
					end
				end
			end
			return out
		end

		-- every character that can stop a bullet: all players except the local one (enemies and teammates)
		local function allCharacters()
			local list = {}
			for _, plr in ipairs(Players:GetPlayers()) do
				local character = plr ~= player and plr.Character
				if character and character.Parent then
					table.insert(list, character)
				end
			end
			return list
		end

		------------------------------------------------------------------
		-- Wall penetration. MEASURED (shots.txt, two real hits through one wall, weapon M4A4): the hit entry has
		--   Distance = |Position - origin| - wall thickness (22.87 - 8.89 = 13.98, 22.63 - 8.93 = 13.71)
		--   Falloff  = about 0.485 for a wall of 8.9 studs (0.4863 and 0.4827)
		--   Damage   = full damage * Falloff * 0.9385 (head 140 -> 63.89, torso 35 -> 15.86; the factor is the same twice)
		-- ASSUMED: Falloff = exp(-WallK * thickness) (1 for no wall, matching the measured Falloff = 1), the 0.9385 factor
		-- constant. Both are refined from every wall hit the game itself sends (learnWall). NOT measured: other materials,
		-- several walls, and whether the server re-checks Falloff / Damage.
		------------------------------------------------------------------
		local MAX_WALL_PART = 40 -- studs, thickest single part that can be measured
		-- the only measured penetration is a wall of 8.9 studs, so shots through more than this are not attempted
		local MAX_PENETRATION = 10
		-- The game's own wall rules (BulletCast.BulletFalloff, MEASURED): every wall part costs thickness / modifier / PenetrationPower
		-- off the bullet's Falloff (1 -> 0, the bullet stops at 0). Modifier: part name nowallbang = bullet stops; Grate 2.25, Glass 0,
		-- Cardboard 0; otherwise by material (DiamondPlate 0.35, Wood / WoodPlanks 2.25, other 0.75). ASSUMED: PenetrationPower = the
		-- weapon's Penetration value, and the one measured wall (M4A4, 8.9 studs, Falloff 0.485) had modifier 0.75, which gives
		-- Cfg.WallK = 8.67 (cost = thickness / modifier * WallK / Penetration), refined from every wall hit the game itself sends.
		local WALL = {
			Cost = {
				[Enum.Material.DiamondPlate] = 0.35, [Enum.Material.CorrodedMetal] = 0.75, [Enum.Material.Metal] = 0.75,
				[Enum.Material.Concrete] = 0.75, [Enum.Material.Brick] = 0.75, [Enum.Material.Wood] = 2.25, [Enum.Material.WoodPlanks] = 2.25,
			},
			Names = { Grate = 2.25, Glass = 0, Cardboard = 0 },
			Misses = 0, Pending = nil, Total = nil, BlockedUntil = 0,
			-- MEASURED in silent_log (35 shots, 11.11.2026 test): every shot turned 23 degrees or more away from the game's own direction missed, none of the
			-- hits was above 19.5 degrees. Targets further from the crosshair than this are not taken, whatever the Field of View slider says.
			MaxTurn = 18,
		}
		-- nil = the bullet cannot pass this part at all
		function WALL.modifier(inst)
			if inst.Name == "nowallbang" then
				return nil
			end
			local named = WALL.Names[inst.Name]
			if named ~= nil then
				return named
			end
			return WALL.Cost[inst.Material] or 0.75
		end
		function WALL.power()
			local character = player.Character
			local equipped = character and character:FindFirstChild("EquippedTool")
			local weapons = game:GetService("ReplicatedStorage"):FindFirstChild("Weapons")
			local weapon = weapons and equipped and equipped:IsA("StringValue") and equipped.Value ~= "" and weapons:FindFirstChild(equipped.Value)
			local pen = weapon and weapon:FindFirstChild("Penetration")
			if pen and pen:IsA("ValueBase") and type(pen.Value) == "number" and pen.Value > 0 then
				return pen.Value
			end
			return nil -- a knife / grenade / Penetration 0: nothing goes through a wall
		end
		-- Shot report for the Event Logs: what the rewritten shot claimed and what the server gave back (TotalDamage after 0.7 s),
		-- so it is visible whether the misses are wall shots or direct ones, moving targets, a damage mismatch or the anti aim.
		function WALL.report(target, dist, claimed, args, origin)
			local before = player:GetAttribute("TotalDamage")
			local inst = target.Hit.Instance
			local speed = 0
			pcall(function()
				speed = inst.AssemblyLinearVelocity.Magnitude
			end)
			local ping = 0
			pcall(function()
				ping = player:GetNetworkPing() * 1000
			end)
			local aa = SilentAim.AA
			local spoof = aa and aa.Enabled and aa.Pitch ~= "Off"
			local kind = if target.Thickness > 0 then string.format("wall %.1f studs", target.Thickness) else "direct"
			-- how far the rewritten direction is from the one the game sent (the spread-free camera look + spread) and the victim's health
			local off, hp = 0, -1
			pcall(function()
				local aimed = (target.Hit.Position + target.Shift - origin).Unit
				off = math.deg(math.acos(math.clamp(aimed:Dot(args[2]), -1, 1)))
				local model = inst:FindFirstAncestorOfClass("Model")
				local humanoid = model and model:FindFirstChildOfClass("Humanoid")
				hp = if humanoid then humanoid.Health else -1
			end)
			local weapon = tostring(args[4])
			task.delay(0.7, function()
				local after = player:GetAttribute("TotalDamage")
				local dealt = (type(after) == "number" and type(before) == "number") and after - before or nil
				local verdict = if dealt and dealt > 0 then string.format("HIT +%.0f", dealt) else "MISS"
				local wallInfo = if target.Parts then string.format(" [falloff %.2f, eff %.1f: %s]", target.Falloff, target.Cost or 0, table.concat(target.Parts, "; ")) else ""
				local text = string.format("Silent %s %s %s: %s (claimed %.0f, %.0f studs, target speed %.0f, ping %.0f ms, aim moved %.1f deg, victim hp %.0f%s)", weapon, kind, inst.Name, verdict, claimed, dist, speed, ping, off, hp, if spoof then ", anti-aim pitch ON" else "") .. wallInfo
				log(text)
				-- the Event Logs cannot be copied, so every report line is also appended to NeverloseBloxStrike/silent_log.txt
				pcall(function()
					local path = CONFIG_DIR .. "/silent_log.txt"
					local line = os.date("%H:%M:%S") .. "  " .. text .. "\n"
					if typeof(appendfile) == "function" then
						appendfile(path, line)
					elseif typeof(writefile) == "function" then
						local old = if typeof(isfile) == "function" and isfile(path) then readfile(path) else ""
						writefile(path, string.sub(old, -20000) .. line)
					end
				end)
			end)
		end
		-- a wall shot is about to be sent: three in a row that did not raise TotalDamage pause wall shots for a few seconds
		function WALL.noteShot()
			local now = os.clock()
			local total = player:GetAttribute("TotalDamage")
			if WALL.Pending and now - WALL.Pending <= 0.45 then
				return -- the previous wall shot is still waiting for its answer
			end
			if WALL.Pending then
				if total ~= WALL.Total then
					WALL.Misses = 0
				else
					WALL.Misses += 1
					if WALL.Misses >= 3 then
						WALL.Misses = 0
						WALL.BlockedUntil = now + 5
						log("Aim Through Walls: 3 wall shots did not hit, paused for 5 s")
					end
				end
			end
			WALL.Pending, WALL.Total = now, total
		end
		local WALL_TARGETS = 4 -- wall shots are only tried on this many parts, the closest to the crosshair
		local scanParams = RaycastParams.new() -- map geometry + smokes + hit parts of all players (the game's bullet ray)
		local wallParams = RaycastParams.new() -- map geometry only
		local smokeParams = RaycastParams.new()
		local partParams = RaycastParams.new()
		local limbParams = RaycastParams.new()
		for _, params in ipairs({ scanParams, wallParams, smokeParams, partParams, limbParams }) do
			params.FilterType = Enum.RaycastFilterType.Include
			params.IgnoreWater = true
		end

		-- One scan = one set of filter lists. Assigning a RaycastParams filter copies the whole list, so it is done once
		-- per scan and not once per ray: that was the frame time cost whenever enemies were in view.
		local function beginScan(allChars)
			local ctx = { Valid = false, HasSmokes = false }
			local map = Workspace:FindFirstChild("Map")
			if not map then
				return ctx
			end
			local geometry = {}
			for _, name in ipairs({ "Geometry", "Regen" }) do
				local folder = map:FindFirstChild(name)
				if folder then
					table.insert(geometry, folder)
				end
			end
			if #geometry == 0 then
				return ctx
			end
			local ignore = Workspace:FindFirstChild("Ray_Ignore")
			local smokes = ignore and ignore:FindFirstChild("Smokes")
			local include = table.clone(geometry)
			if smokes then
				table.insert(include, smokes)
				smokeParams.FilterDescendantsInstances = { smokes }
				ctx.HasSmokes = true
			end
			for _, character in ipairs(allChars) do
				for _, child in ipairs(character:GetChildren()) do
					if E.LIMB_MODIFIER[child.Name] then
						table.insert(include, child)
					end
				end
			end
			scanParams.FilterDescendantsInstances = include
			wallParams.FilterDescendantsInstances = geometry
			ctx.Valid = true
			return ctx
		end

		-- the game's bullet ray (same rules as the Legit gameCast: invisible parts that are not hit parts or smoke are skipped)
		local function castGame(origin, vector)
			local total = vector.Magnitude
			if total < 1e-3 then
				return nil
			end
			local unit = vector.Unit
			local from, remaining = origin, total
			for _ = 1, 8 do
				local result = Workspace:Raycast(from, unit * remaining, scanParams)
				if not result then
					return nil
				end
				local inst = result.Instance
				if inst:IsA("BasePart") and inst.Transparency == 1 and not E.LIMB_MODIFIER[inst.Name] and not inst:HasTag("Smoke") then
					local advance = (result.Position - from).Magnitude + 0.05
					from += unit * advance
					remaining -= advance
					if remaining <= 0 then
						return nil
					end
				else
					return result
				end
			end
			return nil
		end

		-- total thickness of Map.Geometry / Map.Regen between `from` and `to` and the number of parts crossed;
		-- nil when more than maxWalls parts are crossed or a part is too thick to measure. Invisible parts
		-- (Transparency 1) are not walls: the game's bullets ignore them (same rule as the bullet ray).
		local function wallThickness(from, to, maxWalls)
			local total = (to - from).Magnitude
			if total < 0.1 then
				return 0, 0, 0
			end
			local unit = (to - from).Unit
			local pos, thickness, walls, effective, lastEntry, parts = from, 0, 0, 0, nil, {}
			for _ = 1, 16 do
				local remaining = total - (pos - from).Magnitude
				if remaining <= 0.01 then
					break
				end
				local res = Workspace:Raycast(pos, unit * remaining, wallParams)
				if not res then
					break
				end
				local inst = res.Instance
				if inst:IsA("BasePart") and inst.Transparency == 1 then
					pos = res.Position + unit * 0.05
				else
					walls += 1
					if walls > maxWalls then
						return nil
					end
					-- the exit face: cast back from beyond the part, against this part only
					partParams.FilterDescendantsInstances = { inst }
					local back = Workspace:Raycast(res.Position + unit * MAX_WALL_PART, -unit * MAX_WALL_PART, partParams)
					if not back then
						return nil
					end
						local piece = math.min((back.Position - res.Position).Magnitude, remaining)
						local modifier = WALL.modifier(inst)
						if modifier == nil then
							return nil -- nowallbang: the bullet stops here
						end
						thickness += piece
						if modifier > 0 then
							effective += piece / modifier
						end
						lastEntry = res.Position -- BulletCast restarts every cast at the entry point of the wall it just hit
						table.insert(parts, string.format("%s/%s/%s %.1f", inst.Parent and inst.Parent.Name or "?", inst.Name, inst.Material.Name, piece))
						pos = back.Position + unit * 0.05
				end
			end
			return thickness, walls, effective, lastEntry, parts
		end

		local function smokeBlocked(ctx, from, to)
			return ctx.HasSmokes and Workspace:Raycast(from, to - from, smokeParams) ~= nil
		end

		-- the first surface of this character's hit parts on the ray from `origin` towards `point` (map ignored)
		local function limbHit(origin, point, character)
			local include = {}
			for _, child in ipairs(character:GetChildren()) do
				if E.LIMB_MODIFIER[child.Name] then
					table.insert(include, child)
				end
			end
			limbParams.FilterDescendantsInstances = include
			local delta = point - origin
			return Workspace:Raycast(origin, delta.Unit * (delta.Magnitude + 1), limbParams)
		end

		-- refine WallK and the damage factor from a wall hit the game made itself (see the measured relations above)
		local function learnWall(args)
			local entry = args[3][1]
			if type(entry) ~= "table" or typeof(entry.Position) ~= "Vector3" or type(entry.Falloff) ~= "number"
				or type(entry.Distance) ~= "number" or type(entry.Damage) ~= "number" or typeof(entry.Instance) ~= "Instance" then
				return
			end
			local f = entry.Falloff
			-- MEASURED (BulletCast): Distance of the hit after a wall is counted from the entry point of the last wall, not from the
			-- shooter, so |Position - origin| - Distance is how far the wall is, not its thickness. A wall shot only needs Falloff < 1.
			local thickness = (entry.Position - args[1]).Magnitude - entry.Distance
			if f >= 0.999 or f <= 0.01 or thickness < 0.5 or thickness > 2 * MAX_WALL_PART then
				return
			end
			-- WallK = (1 - Falloff) * power / (sum of thickness / modifier) over the walls between the shooter and the hit
			local power = WALL.power()
			local ok, _, _, cost = pcall(wallThickness, args[1], entry.Position, 6)
			if power and ok and type(cost) == "number" and cost > 0.5 then
				local k = (1 - f) * power / cost
				if k > 1 and k < 60 then
					Cfg.WallK = Cfg.WallK * 0.5 + k * 0.5
				end
			end
			local model = entry.Instance:FindFirstAncestorOfClass("Model")
			local plr = model and Players:GetPlayerFromCharacter(model)
			-- MEASURED (two M4A4 wall hits): Damage = DMG * limb * range factor at the full shooter-to-hit distance * Falloff
			local full = plr and E.estimateDamage(plr, entry.Instance, (entry.Position - args[1]).Magnitude)
			if full and full > 0 then
				local c = entry.Damage / (full * f)
				if c > 0.3 and c < 1.5 then
					Cfg.WallC = Cfg.WallC * 0.5 + c * 0.5
				end
			end
		end

		------------------------------------------------------------------
		-- Target evaluation
		------------------------------------------------------------------
		-- extra aim points on a hit part, used when Multipoint is on for its hitbox and the centre is covered
		local function aimPoints(part, dir, multi)
			local points = { part.Position }
			if multi then
				local right = dir:Cross(Vector3.yAxis)
				if right.Magnitude < 1e-3 then
					right = Vector3.xAxis
				end
				right = right.Unit
				local up = right:Cross(dir).Unit
				local r = math.min(part.Size.X, part.Size.Y, part.Size.Z) * 0.35
				for _, offset in ipairs({ right * r, -right * r, up * r, -up * r }) do
					table.insert(points, part.Position + offset)
				end
			end
			return points
		end

		-- Prediction: where the part will be after Cfg.Prediction milliseconds at its current velocity
		local function predictedShift(part)
			if Cfg.Prediction <= 0 then
				return Vector3.zero
			end
			local velocity = part.AssemblyLinearVelocity
			if not E.finite(velocity) then
				return Vector3.zero
			end
			local shift = velocity * (Cfg.Prediction / 1000)
			return if shift.Magnitude > 8 then shift.Unit * 8 else shift
		end

		-- a part that can be hit without crossing a wall: a visible aim point (centre first)
		-- Returns { Hit = { Position, Normal, Instance }, Dist, Thickness, Falloff, Damage } or nil.
		local function evaluateDirect(plr, character, entry, origin)
			local part = entry.Part
			local dir = (part.Position - origin).Unit
			for _, point in ipairs(aimPoints(part, dir, has(Cfg.Multipoint, entry.Box))) do
				local hit = castGame(origin, point - origin)
				local inst = hit and hit.Instance
				if inst and inst:IsDescendantOf(character) and E.LIMB_MODIFIER[inst.Name] then
					local dist = (hit.Position - origin).Magnitude
					local damage = E.estimateDamage(plr, inst, dist)
					if damage then
						return { Hit = hit, Dist = dist, Thickness = 0, Falloff = 1, Damage = damage }
					end
					SilentAim.Unwired("Silent Aim damage", "no weapon stats (EquippedTool / ReplicatedStorage.Weapons.DMG, RangeModifier) for the held weapon")
					return nil
				end
			end
			return nil
		end

		-- Aim Through Walls: the centre of the part (and the Multipoint points) behind walls that the bullet can cross
		local function evaluateWall(plr, character, entry, origin, ctx)
			local part = entry.Part
			local dir = (part.Position - origin).Unit
			for _, point in ipairs(aimPoints(part, dir, has(Cfg.Multipoint, entry.Box))) do
				if not smokeBlocked(ctx, origin, point) then
					local hit = limbHit(origin, point, character)
					if hit then
						local thickness, _, cost, entryPoint, parts = wallThickness(origin, hit.Position, Cfg.MaxWalls)
							local power = WALL.power()
							-- thickness ~ 0 here would mean something other than a wall (another player) is in the way. The remaining
							-- Falloff follows the game's rule (1 - sum of thickness / modifier / power); nothing is shot at a wall the bullet
							-- would not get through (nowallbang, too thick, too many) or that leaves almost nothing of it
							local falloff = if thickness and power then 1 - cost * Cfg.WallK / power else 0
							if thickness and entryPoint and thickness >= 0.05 and thickness <= MAX_PENETRATION and falloff >= 0.2 then
								local dist = (hit.Position - origin).Magnitude
								-- MEASURED: the damage uses the full distance, the hit's Distance field counts from the last wall's entry point
								local full = E.estimateDamage(plr, hit.Instance, dist)
								if full then
									return { Hit = hit, Dist = dist, Thickness = thickness, Entry = entryPoint, Falloff = falloff, Cost = cost, Parts = parts, Damage = full * falloff * Cfg.WallC }
								end
							end
					end
				end
			end
			return nil
		end

		-- best enemy target from `origin`. Order of work (cheapest first): angle / range filter, then ONE pass of visible
		-- targets; wall shots are tried only when nothing is visible, and only on the WALL_TARGETS parts closest to the crosshair.
		local function pickTarget(origin, look)
			local candidates
			for _, plr in ipairs(Players:GetPlayers()) do
				local character = E.enemyCharacter(plr)
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					for _, entry in ipairs(partsOf(character, Cfg.Hitboxes)) do
						local center = entry.Part.Position
						if E.finite(center) then
							local delta = center - origin
							local dist = delta.Magnitude
							if dist > 0.5 and dist < E.MAX_RANGE then
								local angle = math.deg(math.acos(math.clamp(look:Dot(delta.Unit), -1, 1)))
								if angle <= math.min(Cfg.Fov, WALL.MaxTurn) then
									candidates = candidates or {}
									table.insert(candidates, { Plr = plr, Character = character, Humanoid = humanoid, Entry = entry, Angle = angle })
								end
							end
						end
					end
				end
			end
			if not candidates then
				return nil -- nobody to shoot at: no rays at all
			end
			local ctx = beginScan(allCharacters())
			if not ctx.Valid then
				return nil
			end

			local best
			local function consider(c, result)
				if result and (Cfg.MinDamage <= 0 or result.Damage >= Cfg.MinDamage) then
					local s = score(Cfg.Target, result.Damage, c.Angle, c.Humanoid.Health, result.Dist)
					if not best or s > best.Score then
						result.Plr, result.Score, result.Shift = c.Plr, s, predictedShift(c.Entry.Part)
						best = result
					end
				end
			end

			for _, c in ipairs(candidates) do
				consider(c, evaluateDirect(c.Plr, c.Character, c.Entry, origin))
			end
			if best or not Cfg.Walls or Cfg.MaxWalls < 1 or os.clock() < WALL.BlockedUntil then
				return best
			end
			table.sort(candidates, function(a, b)
				return a.Angle < b.Angle
			end)
			for i = 1, math.min(#candidates, WALL_TARGETS) do
				local c = candidates[i]
				consider(c, evaluateWall(c.Plr, c.Character, c.Entry, origin, ctx))
			end
			return best
		end

		-- args = table.pack(...) of the InvokeServer call; returns a new packed args table, or nil to leave the shot alone
		local function silentShot(args, cam)
			local origin = args[1]
			local target = pickTarget(origin, cam.CFrame.LookVector)
			if not target then
				return nil
			end
			local hit = target.Hit
			local position = hit.Position + target.Shift
			local toTarget = position - origin
			if toTarget.Magnitude < 0.1 then
				return nil
			end
			if target.Thickness > 0 then
				WALL.noteShot()
			end
			local out = table.pack(table.unpack(args, 1, args.n))
			-- A wall shot is aimed 60% of the way from the surface point to the centre of the hit part (MEASURED in silent_log: direct shots hit
			-- 23 of 23, wall shots hit 5/7 within 25 studs and 2/45 beyond 45; ASSUMED: the server re-casts wall shots from its own origin, where
			-- a ray along the surface point has no margin). The claimed hit Position stays the surface point.
			local aimAt = position
			if target.Thickness > 0 and hit.Instance:IsA("BasePart") then
				aimAt = position:Lerp(hit.Instance.Position, 0.6)
			end
			out[2] = (aimAt - origin).Unit
			pcall(WALL.report, target, toTarget.Magnitude, target.Damage, args, origin)
			out[3] = {
				{
					Normal = hit.Normal,
					Position = position,
					Instance = hit.Instance,
					Distance = if target.Entry then (position - target.Entry).Magnitude else toTarget.Magnitude,
					Falloff = target.Falloff,
					Damage = target.Damage,
				},
			}
			return out
		end

		-- Remove Spread. MEASURED: the sent direction differs slightly from the camera look (that difference is the spread).
		-- The direction becomes the exact camera look and the hit list is rebuilt along it: an enemy hit part gives one
		-- entry, anything else (a wall, a teammate in the way, a miss) leaves the shot unchanged, spread included.
		-- NOT verified: that the server takes the client direction without applying its own spread.
		local function noSpread(args, cam)
			local origin = args[1]
			local look = cam.CFrame.LookVector
			local hit = E.gameCast(origin, look * E.MAX_RANGE, false, allCharacters())
			local model = hit and hit.Instance:FindFirstAncestorOfClass("Model")
			local plr = model and Players:GetPlayerFromCharacter(model)
			if not (plr and E.enemyCharacter(plr) == model and E.LIMB_MODIFIER[hit.Instance.Name]) then
				return nil
			end
			local dist = (hit.Position - origin).Magnitude
			local damage = E.estimateDamage(plr, hit.Instance, dist)
			if not damage then
				SilentAim.Unwired("Remove Spread", "no weapon stats (EquippedTool / ReplicatedStorage.Weapons.DMG, RangeModifier) for the held weapon")
				return nil
			end
			local out = table.pack(table.unpack(args, 1, args.n))
			out[2] = look
			out[3] = {
				{ Normal = hit.Normal, Position = hit.Position, Instance = hit.Instance, Distance = dist, Falloff = 1, Damage = damage },
			}
			return out
		end

		-- args = table.pack(...) of the InvokeServer call; returns a new packed args table, or nil to leave the shot alone
		local function rewrite(args)
			if typeof(args[1]) ~= "Vector3" or typeof(args[2]) ~= "Vector3" or type(args[3]) ~= "table" or type(args[4]) ~= "string" then
				return nil -- not the measured argument shape
			end
			pcall(learnWall, args)
			if not Cfg.Enabled then
				return nil
			end
			local cam = Workspace.CurrentCamera
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not cam or not humanoid or humanoid.Health <= 0 then
				return nil
			end
			if Cfg.Silent and #Cfg.Hitboxes > 0 then
				if Cfg.HitChance > 0 and rng:NextNumber() * 100 >= Cfg.HitChance then
				else
					local out = silentShot(args, cam)
					if out then
						return out
					end
				end
			end
			if Cfg.NoSpread then
				return noSpread(args, cam)
			end
			return nil
		end

		local oldNamecall
		local function install()
			-- setnamecallmethod is required: the lookups made while choosing a target are namecalls themselves and
			-- overwrite the stored method, so it must be restored before the original metamethod runs
			-- executor globals read nil in a plain Roblox script
			if not (typeof(hookmetamethod) == "function" and typeof(getnamecallmethod) == "function" and typeof(setnamecallmethod) == "function") then
				SilentAim.Unwired("Silent Aim", "executor lacks hookmetamethod / getnamecallmethod / setnamecallmethod")
				return
			end
			local canCheck = typeof(checkcaller) == "function"
			local wrap = if typeof(newcclosure) == "function" then newcclosure else function(f)
				return f
			end
			local ok, err = pcall(function()
				oldNamecall = hookmetamethod(game, "__namecall", wrap(function(self, ...)
					local method = getnamecallmethod()
					if alive and method == "InvokeServer" and typeof(self) == "Instance" and self.Name == REMOTE
						and self.ClassName == "RemoteFunction" and not (canCheck and checkcaller()) then
						local packed = table.pack(...)
						local okRewrite, out = pcall(rewrite, packed)
							Feat.LastShotAt = os.clock() -- our own shot (the game's BulletHitreg call): Shoot Sound uses it to tell our shots from other players'
							if Feat.OnShot then pcall(Feat.OnShot, (okRewrite and out) or packed) end
						if okRewrite and out then
							setnamecallmethod(method)
							return oldNamecall(self, table.unpack(out, 1, out.n))
						elseif not okRewrite and out ~= lastError then
							lastError = out
							warn("[SilentAim] " .. tostring(out))
						end
						setnamecallmethod(method)
					end
					if alive and method == "FireServer" and typeof(self) == "Instance" and self.Name == "ControlTurn"
						and SilentAim.ControlTurn and not (canCheck and checkcaller()) then
						local packed = table.pack(...)
						local okTurn, out = pcall(SilentAim.ControlTurn, packed, self)
						setnamecallmethod(method)
						if okTurn and out then
							return oldNamecall(self, table.unpack(out, 1, out.n))
						end
					end
					if alive and method == "FireServer" and typeof(self) == "Instance" and self.Name == "ReplicateReload" and Feat.OnReload
						and not (canCheck and checkcaller()) then
						pcall(Feat.OnReload) -- MEASURED remote (shots.txt): the game tells the server about a reload
						setnamecallmethod(method)
					end
					return oldNamecall(self, ...)
				end))
			end)
			if ok then
				log("Silent Aim: hooked " .. REMOTE .. " (__namecall)")
			else
				SilentAim.Unwired("Silent Aim", "hook failed: " .. tostring(err))
			end
		end
		install()

		-- Automatic Fire: while silent aim has a visible target inside the FOV, click the fire button in short pulses
		-- (a pulse per shot works for automatic and semi-automatic weapons alike). Needs Silent Aim, otherwise the
		-- bullets would leave along the camera look. The fire method (mouse1press or Tool:Activate) is the one resolved
		-- by the Legit triggerbot; which of them works in this game is not verified.
		-- ASSUMED: a knife is "melee" (measured name "CT Knife"), so any equipped tool whose name contains "Knife" is skipped.
		local AUTO_PRESS = 0.03 -- seconds a pulse is held
		local AUTO_GAP = 0.1 -- seconds between pulse starts
		local autoFocused = true
		local autoConns = {
			UserInputService.WindowFocused:Connect(function()
				autoFocused = true
			end),
			UserInputService.WindowFocusReleased:Connect(function()
				autoFocused = false
			end),
		}
		local auto = { PressedAt = nil, LastPress = 0, LastScan = 0, Target = nil, Alt = false }
		-- Revolver (ASSUMED tool name "R8", the Weapons folder name) with Remove Spread on: the shot is fired with the RIGHT mouse
		-- button instead of the left one. Needs the executor's mouse2press / mouse2release; without them the left button is used.
		local REVOLVER = "R8"
		local altFire, altWarned
		local function resolveAltFire()
			if altFire == nil then
				local ok, press, release = pcall(function()
					return mouse2press, mouse2release
				end)
				altFire = if ok and type(press) == "function" and type(release) == "function" then { Press = press, Release = release } else false
			end
			return altFire
		end
		local function heldTool(character)
			local equipped = character:FindFirstChild("EquippedTool")
			return if equipped and equipped:IsA("StringValue") then equipped.Value else ""
		end

		local function autoRelease()
			if auto.PressedAt then
				auto.PressedAt = nil
				pcall((if auto.Alt then resolveAltFire() else E.resolveFire()).Release)
			end
		end

		local function weaponAllowed(character)
			local equipped = character:FindFirstChild("EquippedTool")
			local name = equipped and equipped:IsA("StringValue") and equipped.Value or ""
			return name ~= "" and not string.find(name, "Knife", 1, true) and not string.find(name, "Bayonet", 1, true)
		end

		local autoError
		pcall(RunService.UnbindFromRenderStep, RunService, "RageAutoFire") -- a second run of the script replaces the first
		RunService:BindToRenderStep("RageAutoFire", Enum.RenderPriority.Camera.Value + 2, function()
			local ok, err = pcall(function()
				local cam = Workspace.CurrentCamera
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if not (Cfg.Enabled and Cfg.Silent and Cfg.AutoFire) or not cam or not humanoid or humanoid.Health <= 0
					or not autoFocused or menu._visible or UserInputService:GetFocusedTextBox() ~= nil or not weaponAllowed(character) then
					auto.Target = nil
					autoRelease()
					return
				end
				-- the player's own held button is theirs: do not press or release it
				local useAlt = Cfg.NoSpread and heldTool(character) == REVOLVER and resolveAltFire() ~= false
				if Cfg.NoSpread and not useAlt and not altWarned and heldTool(character) == REVOLVER then
					altWarned = true
					log("Automatic Fire: no mouse2press in this executor, the revolver is fired with the left button")
				end
				local ownButton = if useAlt then Enum.UserInputType.MouseButton2 else Enum.UserInputType.MouseButton1
				if not auto.PressedAt and UserInputService:IsMouseButtonPressed(ownButton) then
					return
				end
				local now = os.clock()
				if now - auto.LastScan >= (if auto.Target then 0.06 else 0.12) then
					auto.LastScan = now
					auto.Target = pickTarget(cam.CFrame.Position, cam.CFrame.LookVector)
				end
				if auto.PressedAt and now - auto.PressedAt >= AUTO_PRESS then
					autoRelease()
				end
				if auto.Target and not auto.PressedAt and now - auto.LastPress >= AUTO_GAP then
					auto.PressedAt, auto.LastPress = now, now
					auto.Alt = useAlt
					pcall((if useAlt then resolveAltFire() else E.resolveFire()).Press)
				end
			end)
			if not ok then
				autoRelease()
				if err ~= autoError then
					autoError = err
					warn("[RageAutoFire] " .. tostring(err))
					log("Automatic Fire error, see console")
				end
			end
		end)
		table.insert(Unloaders, function()
			Cfg.AutoFire = false
			pcall(RunService.UnbindFromRenderStep, RunService, "RageAutoFire")
			for _, c in ipairs(autoConns) do
				c:Disconnect()
			end
			autoRelease()
		end)

		-- FOV circle (Visualize): pixel radius of an angle on a perspective screen = tan(angle) / tan(verticalFov / 2) * half height
		local fovGui = create("ScreenGui", {
			Name = "RageAimOverlay",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 5,
			Parent = player:WaitForChild("PlayerGui"),
		})
		local fovCircle = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = fovGui,
		}, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		local fovStroke = Instance.new("UIStroke")
		fovStroke.Thickness = 1.5
		fovStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		fovStroke.Color = Cfg.VisualizeColor
		fovStroke.Parent = fovCircle

		pcall(RunService.UnbindFromRenderStep, RunService, "RageFov") -- a second run of the script replaces the first
		RunService:BindToRenderStep("RageFov", Enum.RenderPriority.Camera.Value + 1, function()
			local cam = Workspace.CurrentCamera
			-- the circle shows the silent aim FOV; at 90 degrees and above it would leave the screen, so it is hidden
			if not (cam and Cfg.Visualize and Cfg.Enabled and Cfg.Silent) or Cfg.Fov >= 89.5 then
				fovCircle.Visible = false
				return
			end
			local radius = math.tan(math.rad(Cfg.Fov)) / math.tan(math.rad(cam.FieldOfView) / 2) * (cam.ViewportSize.Y / 2)
			radius = math.clamp(radius, 1, 4000)
			fovCircle.Size = UDim2.fromOffset(radius * 2, radius * 2)
			fovStroke.Color = Cfg.VisualizeColor
			fovCircle.Visible = true
		end)
		table.insert(Unloaders, function()
			pcall(RunService.UnbindFromRenderStep, RunService, "RageFov")
			fovGui:Destroy()
		end)

		-- the metamethod hook cannot be removed safely; after unload it only passes calls through
		table.insert(Unloaders, function()
			alive = false
			Cfg.Enabled = false
		end)
	end

	------------------------------------------------------------------
	-- Rage anti aim.
	-- Pitch: MEASURED (shots.txt) ControlTurn:FireServer(a, b) sends a = the camera's look.Y (-1..1, negative = looking
	--   down) every ~0.1 s, so Down / Up / Zero replace a (hooked in the same __namecall hook as the silent aim).
	--   The server's accepted range and what other players see for it are not measured; 0.99 is the edge of the measured range.
	-- Yaw: ASSUMED that other players see HumanoidRootPart.CFrame, so the root is turned every Heartbeat and
	--   Humanoid.AutoRotate is switched off meanwhile. The meaning of ControlTurn's second argument is NOT measured and the
	--   game may override the root rotation; verify by watching the character from a second client / spectate.
	-- Yaw base angle: Backwards = camera yaw + 180, At Targets = away from the nearest enemy, Spin = SPIN_RATE rad/s
	--   (uncalibrated). Manuals: a direction (Left / Right / Forward / Back, relative to the camera) is picked in the menu or
	--   with its own configurable key (default: the arrow keys); the same key again clears it.
	-- Not wired: Freestanding.
	------------------------------------------------------------------
	do
		local E = LegitAim.Engine
		local AA = SilentAim.AA
		local Workspace = game:GetService("Workspace")
		local PITCH_EDGE = 0.99
		local SPIN_RATE = 12
		local MANUAL = { Left = math.pi / 2, Right = -math.pi / 2, Forward = 0, Back = math.pi }

		local spin = 0
		local rotated -- { Humanoid, Was } while AutoRotate is off because of us
		local lastError

		-- Roblox yaw of CFrame.Angles(0, yaw, 0): its LookVector is (-sin yaw, 0, -cos yaw)
		local function yawOf(v)
			return math.atan2(-v.X, -v.Z)
		end

		local function restoreRotate()
			local r = rotated
			rotated = nil
			if r and r.Humanoid.Parent then
				r.Humanoid.AutoRotate = r.Was
			end
		end

		local turnRemote -- the game's ControlTurn remote, remembered from its own call or found in ReplicatedStorage
		-- MEASURED: the replicated "Aim" attribute is (pitch, yaw), where yaw is the game's own second ControlTurn argument
		-- (about +-pi while the body faces away from the camera). Our own sends reuse the game's last value so the
		-- yaw does not flicker between 0 and the game's value.
		local lastTurn = 0

		local function pitchValue()
			return if AA.Pitch == "Down" then -PITCH_EDGE elseif AA.Pitch == "Up" then PITCH_EDGE else 0
		end

		-- called from the hook for every ControlTurn the game sends: remember the remote, replace the pitch
		function SilentAim.ControlTurn(args, remote)
			if typeof(remote) == "Instance" then
				turnRemote = remote
			end
			if type(args[2]) == "number" then
				lastTurn = args[2]
			end
			if not AA.Enabled or AA.Pitch == "Off" or type(args[1]) ~= "number" then
				return nil
			end
			local out = table.pack(table.unpack(args, 1, args.n))
			out[1] = pitchValue()
			return out
		end

		-- MEASURED: the game sends ControlTurn only while the mouse moves, so a spoofed pitch would never reach the
		-- server for a player standing still. Send it ourselves every 0.1 s (second argument 0: yaw delta, a value that
		-- occurs in the log), and send the real look.Y once when the spoof is switched off.
		local lastSend, lastSearch, spoofing = 0, 0, false
		local function findTurnRemote()
			if turnRemote and turnRemote.Parent then
				return turnRemote
			end
			turnRemote = nil
			local now = os.clock()
			if now - lastSearch >= 2 then
				lastSearch = now
				local found = game:GetService("ReplicatedStorage"):FindFirstChild("ControlTurn", true)
				if found and (found:IsA("RemoteEvent") or found:IsA("UnreliableRemoteEvent")) then
					turnRemote = found
				end
			end
			return turnRemote
		end

		local pitchConn = RunService.Heartbeat:Connect(function()
			local ok, err = pcall(function()
				local now = os.clock()
				if now - lastSend < 0.1 then
					return
				end
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local cam = Workspace.CurrentCamera
				local active = AA.Enabled and AA.Pitch ~= "Off" and humanoid ~= nil and humanoid.Health > 0 and cam ~= nil
				if not active and not spoofing then
					return
				end
				local remote = findTurnRemote()
				if not remote then
					return
				end
				lastSend = now
				if active then
					spoofing = true
					remote:FireServer(pitchValue(), lastTurn)
				else
					spoofing = false
					if cam then
						remote:FireServer(cam.CFrame.LookVector.Y, 0)
					end
				end
			end)
			if not ok and err ~= lastError then
				lastError = err
				warn("[AntiAim pitch] " .. tostring(err))
				menu:Log("Anti Aim pitch error, see console")
			end
		end)

		local function nearestEnemyDirection(root)
			local best, bestDist
			for _, plr in ipairs(Players:GetPlayers()) do
				local character = E.enemyCharacter(plr)
				local enemyRoot = character and character:FindFirstChild("HumanoidRootPart")
				if enemyRoot and E.finite(enemyRoot.Position) then
					local delta = enemyRoot.Position - root.Position
					local flat = Vector3.new(delta.X, 0, delta.Z)
					if flat.Magnitude > 0.5 and (not bestDist or flat.Magnitude < bestDist) then
						best, bestDist = flat, flat.Magnitude
					end
				end
			end
			return best
		end

		local keyConn = UserInputService.InputBegan:Connect(function(input, processed)
			if processed or not AA.Manual then
				return
			end
			-- the key of a direction sets it; the same key again clears it (the menu dropdown follows)
			for name, key in pairs(AA.Keys) do
				if input.KeyCode == key then
					AA.ManualDir = if AA.ManualDir == name then "None" else name
					if AA.ManualDropdown then
						AA.ManualDropdown:Set(AA.ManualDir)
					end
					return
				end
			end
		end)

		-- Local preview of the spoofed pitch. MEASURED (rig probe): the game never pitches the local head (Head.LookY and
		-- Neck.Transform stay the same from look.Y -0.985 to +0.985) and leaves Neck.C0 at zero rotation, so the head is
		-- pitched through Neck.C0. ASSUMED: R15 neck axes (rotation about the joint's X axis pitches the head, positive =
		-- up). This changes only what this client draws; what other players see is the replicated Aim attribute.
		local neck = { Joint = nil, Base = nil }
		local function restoreNeck()
			if neck.Joint and neck.Joint.Parent then
				neck.Joint.C0 = neck.Base
			end
			neck.Joint, neck.Base = nil, nil
		end
		local previewConn = RunService.RenderStepped:Connect(function()
			pcall(function()
				local character = player.Character
				if not (AA.Enabled and AA.Pitch ~= "Off" and character) then
					restoreNeck()
					return
				end
				if not neck.Joint or not neck.Joint:IsDescendantOf(character) then
					restoreNeck()
					local joint = character:FindFirstChild("Neck", true)
					if not (joint and joint:IsA("Motor6D")) then
						return
					end
					neck.Joint, neck.Base = joint, joint.C0
				end
				neck.Joint.C0 = neck.Base * CFrame.Angles(math.asin(pitchValue()), 0, 0)
			end)
		end)

		local stepConn = RunService.Heartbeat:Connect(function(dt)
			local ok, err = pcall(function()
				local cam = Workspace.CurrentCamera
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local manualOn = AA.Manual and MANUAL[AA.ManualDir] ~= nil
				if not (AA.Enabled and cam and humanoid and root) or humanoid.Health <= 0 or humanoid.Sit
					or (AA.Yaw == "Off" and not manualOn) then
					restoreRotate()
					return
				end
				local camYaw = yawOf(cam.CFrame.LookVector)
				local yaw
				if manualOn then
					yaw = camYaw + MANUAL[AA.ManualDir]
				elseif AA.Yaw == "Spin" then
					spin = (spin + SPIN_RATE * math.min(dt, 0.1)) % (2 * math.pi)
					yaw = spin
				elseif AA.Yaw == "At Targets" then
					local dir = nearestEnemyDirection(root)
					yaw = (if dir then yawOf(dir) else camYaw) + math.pi
				else -- Backwards
					yaw = camYaw + math.pi
				end
				if not rotated or rotated.Humanoid ~= humanoid then
					restoreRotate()
					rotated = { Humanoid = humanoid, Was = humanoid.AutoRotate }
				end
				humanoid.AutoRotate = false
				root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
				root.AssemblyAngularVelocity = Vector3.zero
			end)
			if not ok and err ~= lastError then
				lastError = err
				warn("[AntiAim] " .. tostring(err))
				menu:Log("Anti Aim error, see console")
			end
		end)

		table.insert(Unloaders, function()
			AA.Enabled = false
			SilentAim.ControlTurn = nil
			keyConn:Disconnect()
			stepConn:Disconnect()
			pitchConn:Disconnect()
			previewConn:Disconnect()
			restoreNeck()
			restoreRotate()
		end)
	end

	local C = LegitAim.Cfg
	local function unwired(name, reason)
		return function(v)
			if v and v ~= 0 and v ~= 1 then
				LegitAim.Unwired(name, reason)
			end
		end
	end

	local main = legit:AddSection("Main", "Left")
	main:AddToggle("Enabled", false, function(v)
		C.Master = v
	end)

	local aimbot = legit:AddSection("Aimbot", "Left")
	aimbot:AddToggle("Enabled", false, function(v)
		C.Aim.Enabled = v
	end)
	aimbot:AddDropdown("Activation", { "Assisted", "Always", "On Key" }, "Assisted", function(v)
		C.Aim.Activation = v
	end)
	aimbot:AddMultiDropdown("Conditions", { "Through Smokes", "Flashed", "Jumping" }, { "Through Smokes", "Jumping" }, function(list)
		C.Aim.Conditions = list
	end)
	aimbot:AddMultiDropdown("Hitboxes", { "Head", "Chest", "Stomach" }, { "Head" }, function(list)
		C.Aim.Hitboxes = list
	end)
	aimbot:AddSlider("Field of View", 1, 180, 20, function(v)
		C.Aim.Fov = v
	end, "°")
	aimbot:AddSlider("Smoothing", 0, 100, 15, function(v)
		C.Aim.Smoothing = v
	end, "%")
	aimbot:AddSlider("Reaction Time", 0, 1000, 200, function(v)
		C.Aim.Reaction = v
	end, "ms")
	aimbot:AddSlider("Min Damage", 1, 100, 1, function(v)
		C.Aim.MinDamage = v
	end)
	aimbot:AddToggle("Recoil Control", false, unwired("Recoil Control", "the game's recoil source is not measured")):AddSettings(250, "Recoil Control")
	aimbot:AddToggle("Quick Scope", false, unwired("Quick Scope", "the game's scope input is not measured")):AddSettings(250, "Quick Scope")
	aimbot:AddToggle("Quick Stop", false, function(v)
		C.Aim.QuickStop = v
	end):AddSettings(250, "Quick Stop")

	local trigger = legit:AddSection("Triggerbot", "Right")
	trigger:AddToggle("Enabled", false, function(v)
		C.Trigger.Enabled = v
	end)
	trigger:AddMultiDropdown("Conditions", { "Through Smokes", "Flashed", "Jumping" }, { "Through Smokes", "Jumping" }, function(list)
		C.Trigger.Conditions = list
	end)
	trigger:AddMultiDropdown("Hitboxes", { "Head", "Chest", "Stomach" }, { "Head", "Chest", "Stomach" }, function(list)
		C.Trigger.Hitboxes = list
	end)
	trigger:AddSlider("Hit Chance", 0, 100, 50, function(v)
		C.Trigger.HitChance = v
	end, "%")
	trigger:AddSlider("Min Damage", 0, 100, 0, function(v)
		C.Trigger.MinDamage = v
	end, nil, {
		Format = function(v)
			return if v == 0 then "auto" else nil
		end,
	})
	trigger:AddSlider("Reaction Time", 0, 1000, 200, function(v)
		C.Trigger.Reaction = v
	end, "ms")
	trigger:AddSlider("Burst Time", 0, 1000, 50, function(v)
		C.Trigger.Burst = v
	end, "ms")
	trigger:AddToggle("Quick Scope", false, unwired("Triggerbot Quick Scope", "the game's scope input is not measured"))

	local other = legit:AddSection("Other", "Right")
	local visualize = other:AddToggle("Visualize", false, function(v)
		C.Other.Visualize = v
	end):AddSettings(250, "Visualize")
	visualize:AddColorPicker("Color", C.Other.VisualizeColor, function(c)
		C.Other.VisualizeColor = c
	end)
	other:AddToggle("Automatic Weapons", false, function(v)
		C.Other.Automatic = v
	end):AddSettings(250, "Automatic Weapons")
	local rcs = other:AddToggle("Standalone Recoil Control", false, unwired("Standalone Recoil Control", "the game's recoil source is not measured")):AddSettings(260, "Standalone Recoil Control")
	rcs:AddToggle("Start Bullet", false, noop)
	rcs:AddSlider("Vertical", 0, 100, 100, noop, "%")
	rcs:AddSlider("Horizontal", 0, 100, 100, noop, "%")
	rcs:AddToggle("Crosshair Recovery", false, noop)
	other:AddDropdown("Randomize", { "Off", "Low", "Medium", "High" }, "Low", function(v)
		C.Other.Randomize = v
	end)
end

------------------------------------------------------------------
-- Visuals > Players > Teammates: teammate chams and the local player's own model.
-- Teammate = another player that EnemyESP.Adapter.IsEnemy rejects (same team). Chams, Highlights and the restore of the
-- original look follow the Enemy engine. Hide uses LocalTransparencyModifier, which only this client sees.
-- ASSUMED (not measured): the first-person weapon (viewmodel) lives under Workspace.CurrentCamera, so Weapon chams
-- touch every part under the camera that does not belong to a player's character. The first time Weapon chams
-- are on and nothing is found, the menu log says so.
-- Local model transparency: while the character's ADS value (MEASURED: BoolValue "ADS" on the character) is true the
-- "When Scoped" value is used, otherwise "Model". 0 leaves the game's own transparency alone.
------------------------------------------------------------------
local TeamVisuals = {
	Cfg = {
		Enabled = false,
		Player = { Material = nil, Color = rgb(225, 225, 250) },
		Walls = { Material = nil, Color = rgb(250, 210, 180) },
		Hide = false,
		Glow = { On = false, Color = rgb(200, 200, 200) },
		Local = {
			Model = { Material = nil, Color = rgb(160, 170, 250) },
			ModelGlow = { On = false, Color = rgb(200, 200, 200) },
			Weapon = { Material = nil, Color = rgb(160, 170, 250) },
			Transparency = 0, -- percent
			Scoped = 0, -- percent (0 = do not touch the model: the game hides the own model in first person)
		},
	},
}
do
	local Workspace = game:GetService("Workspace")
	local Cfg = TeamVisuals.Cfg
	local Adapter = EnemyESP.Adapter
	local HIGHLIGHT_FILL = { Neon = 0.3, SmoothPlastic = 0.5, ForceField = 0.7, Glass = 0.8 }
	local SKIN_CLASSES = { "Shirt", "Pants", "ShirtGraphic", "SurfaceAppearance" }
	local SCAN_GAP = 0.4 -- seconds between full passes (parts added later are picked up by the next pass)

	function TeamVisuals.SetChams(key, materialName, color)
		local entry = ({
			TeamPlayer = Cfg.Player,
			TeamWalls = Cfg.Walls,
			LocalModel = Cfg.Local.Model,
			LocalWeapon = Cfg.Local.Weapon,
		})[key]
		if entry then
			entry.Material, entry.Color = CHAMS_MATERIALS[materialName], color
		end
	end

	-- one styler per styled model: originals to restore, Highlight instances
	local function newStyler()
		return { Orig = {}, Hidden = {}, HL = {} }
	end

	local function restoreMaterial(o)
		for inst, orig in pairs(o.Orig) do
			pcall(function()
				if orig.Kind == "part" then
					inst.Material, inst.Color = orig.Material, orig.Color
				elseif orig.Kind == "decal" then
					inst.Transparency = orig.Transparency
				else
					inst.Parent = orig.Parent
				end
			end)
		end
		o.Orig = {}
	end

	-- skip(d) returns true for instances that must stay untouched
	local function applyMaterial(o, root, material, color, skip)
		if not material then
			if next(o.Orig) then
				restoreMaterial(o)
			end
			return
		end
		for _, d in ipairs(root:GetDescendants()) do
			if not (skip and skip(d)) then
				if d:IsA("BasePart") then
					if d.Name ~= "HumanoidRootPart" then
						if not o.Orig[d] then
							o.Orig[d] = { Kind = "part", Material = d.Material, Color = d.Color }
						end
						d.Material, d.Color = material, color
					end
				elseif d:IsA("Decal") then
					if not o.Orig[d] then
						o.Orig[d] = { Kind = "decal", Transparency = d.Transparency }
					end
					d.Transparency = 1
				else
					for _, class in ipairs(SKIN_CLASSES) do
						if d:IsA(class) then
							if not o.Orig[d] then
								o.Orig[d] = { Kind = "skin", Parent = d.Parent }
							end
							d.Parent = nil
							break
						end
					end
				end
			end
		end
	end

	local function setHidden(o, root, on)
		if not on then
			for inst, value in pairs(o.Hidden) do
				pcall(function()
					inst.LocalTransparencyModifier = value
				end)
			end
			o.Hidden = {}
			return
		end
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("BasePart") then
				if o.Hidden[d] == nil then
					o.Hidden[d] = d.LocalTransparencyModifier
				end
				d.LocalTransparencyModifier = 1
			end
		end
	end

	local function setHighlight(o, field, adornee, cam, on, props)
		local hl = o.HL[field]
		if not on then
			if hl then
				hl.Enabled = false
			end
			return
		end
		if not hl then
			hl = Instance.new("Highlight")
			hl.Name = "NLChams"
			o.HL[field] = hl
		end
		hl.Adornee = adornee
		if hl.Parent ~= cam then
			if not pcall(function()
				hl.Parent = cam
			end) then
				hl = Instance.new("Highlight")
				hl.Name = "NLChams"
				o.HL[field] = hl
				hl.Adornee = adornee
				hl.Parent = cam
			end
		end
		hl.Enabled = true
		hl.FillColor = props.FillColor
		hl.FillTransparency = props.FillTransparency
		hl.OutlineColor = props.OutlineColor
		hl.OutlineTransparency = 0
		hl.DepthMode = props.DepthMode
	end

	local function destroyStyler(o)
		restoreMaterial(o)
		setHidden(o, nil, false)
		for _, hl in pairs(o.HL) do
			hl:Destroy()
		end
		o.HL = {}
	end

	local function wallsProps(entry)
		return {
			FillColor = entry.Color,
			FillTransparency = if entry.Material then HIGHLIGHT_FILL[entry.Material.Name] or 0.5 else 1,
			OutlineColor = entry.Color,
			DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		}
	end

	local function glowProps(glow)
		return { FillColor = glow.Color, FillTransparency = 1, OutlineColor = glow.Color, DepthMode = Enum.HighlightDepthMode.Occluded }
	end

	local teammates = {} -- [Player] = styler
	local localStyler, weaponStyler = newStyler(), newStyler()
	local weaponWarned = false

	local function inPlayerCharacter(d)
		local model = d:FindFirstAncestorOfClass("Model")
		return model ~= nil and Players:GetPlayerFromCharacter(model) ~= nil
	end

	local function slowStep()
		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end

		-- teammates
		local seen = {}
		if Cfg.Enabled then
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= player and not Adapter.IsEnemy(plr) then
					local character = plr.Character
					local humanoid = character and character:FindFirstChildOfClass("Humanoid")
					if humanoid and character:IsDescendantOf(Workspace) and Adapter.IsAlive(plr, humanoid) then
						seen[plr] = true
						local o = teammates[plr]
						if not o then
							o = newStyler()
							teammates[plr] = o
						end
						if Cfg.Hide then
							applyMaterial(o, character, nil)
							setHidden(o, character, true)
							setHighlight(o, "Walls", character, cam, false)
							setHighlight(o, "Glow", character, cam, false)
						else
							setHidden(o, nil, false)
							applyMaterial(o, character, Cfg.Player.Material, Cfg.Player.Color)
							setHighlight(o, "Walls", character, cam, Cfg.Walls.Material ~= nil, wallsProps(Cfg.Walls))
							setHighlight(o, "Glow", character, cam, Cfg.Glow.On, glowProps(Cfg.Glow))
						end
					end
				end
			end
		end
		for plr, o in pairs(teammates) do
			if not seen[plr] then
				destroyStyler(o)
				teammates[plr] = nil
			end
		end

		-- the local character
		local character = player.Character
		if character and character.Parent then
			applyMaterial(localStyler, character, Cfg.Local.Model.Material, Cfg.Local.Model.Color)
			setHighlight(localStyler, "Glow", character, cam, Cfg.Local.ModelGlow.On, glowProps(Cfg.Local.ModelGlow))
		else
			destroyStyler(localStyler)
		end

		-- the first-person weapon (assumed: parts under the camera)
		local weapon = Cfg.Local.Weapon
		if weapon.Material then
			applyMaterial(weaponStyler, cam, weapon.Material, weapon.Color, inPlayerCharacter)
		else
			restoreMaterial(weaponStyler)
		end
	end

	-- local model transparency, every frame after the camera (the default camera scripts also write
	-- LocalTransparencyModifier on the local character)
	local transparencyApplied = false
	local function transparencyStep()
		local character = player.Character
		if not character then
			transparencyApplied = false
			return
		end
		local ads = character:FindFirstChild("ADS")
		local scoped = ads ~= nil and ads:IsA("BoolValue") and ads.Value
		local value = (if scoped then Cfg.Local.Scoped else Cfg.Local.Transparency) / 100
		-- the sliders only make sense in third person: in first person the game hides the own model, and writing a modifier
		-- below 1 would show it inside the camera (this is what showed the own model in front of the scope)
		if value <= 0 or not TeamVisuals.Cfg.Local.ThirdOn then
			if transparencyApplied then
				transparencyApplied = false
				for _, d in ipairs(character:GetDescendants()) do
					if d:IsA("BasePart") then
						d.LocalTransparencyModifier = 0
					end
				end
			end
			return
		end
		transparencyApplied = true
		for _, d in ipairs(character:GetDescendants()) do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				d.LocalTransparencyModifier = value
			end
		end
	end

	local last, lastError = 0, nil
	local function guarded(f, ...)
		local ok, err = pcall(f, ...)
		if not ok and err ~= lastError then
			lastError = err
			warn("[TeamVisuals] " .. tostring(err))
			menu:Log("Visuals error, see console")
		end
	end

	pcall(RunService.UnbindFromRenderStep, RunService, "TeamVisuals") -- a second run of the script replaces the first
	RunService:BindToRenderStep("TeamVisuals", Enum.RenderPriority.Camera.Value + 2, function()
		local now = os.clock()
		if now - last >= SCAN_GAP then
			last = now
			guarded(slowStep)
		end
		guarded(transparencyStep)
	end)

	table.insert(Unloaders, function()
		pcall(RunService.UnbindFromRenderStep, RunService, "TeamVisuals")
		for _, o in pairs(teammates) do
			destroyStyler(o)
		end
		teammates = {}
		destroyStyler(localStyler)
		destroyStyler(weaponStyler)
		local character = player.Character
		if character and transparencyApplied then
			for _, d in ipairs(character:GetDescendants()) do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = 0
				end
			end
		end
	end)
end

------------------------------------------------------------------
-- Visuals > Players: header switches Enemies / Teammates, list button opens ESP Items
------------------------------------------------------------------
do
	local preview = players:AddPreview({
		Weapon = "AK-47",
		OnMode = EnemyESP.Invalidate,
		OnItem = EnemyESP.Invalidate,
		OnStyle = EnemyESP.Invalidate,
		OnLayout = EnemyESP.Invalidate,
	})
	EnemyESP.Bind(preview, function(text)
		menu:Log(text)
	end)
	local chamsOptions = { "Disabled", "Neon", "Flat", "ForceField", "Glass" }

	-- "Player [■] [Disabled ⌄]"; wired rows also tint the preview model of their mode
	local function chamsRow(section, label, mode, color, wired, key)
		local material, tint = "Disabled", color
		local function update()
			if wired then
				preview:SetChams(material, tint, mode)
			end
			if mode == "Enemies" then
				EnemyESP.SetChams(label, material, tint)
			elseif mode == "Teammates" and key then
				TeamVisuals.SetChams(key, material, tint)
			end
		end
		section:AddDropdown(label, chamsOptions, "Disabled", function(v)
			material = v
			update()
		end):AddColor(color, function(c)
			tint = c
			update()
		end)
	end

	-- Enemies
	local enemy = players:AddSection("Enemy", "Left", "Enemies")
	local espCfg = EnemyESP.Cfg
	enemy:AddToggle("Enabled", false, function(v)
		espCfg.Enabled = v
	end)
	enemy:AddToggle("Offscreen Arrow", false, function(v)
		espCfg.Arrow.On = v
	end):AddColor(Color3.fromRGB(255, 255, 255), function(c)
		espCfg.Arrow.Color = c
	end)
	enemy:AddToggle("Sounds", false, function(v)
		espCfg.Sounds.On = v
	end):AddColor(Color3.fromRGB(240, 90, 140), function(c)
		espCfg.Sounds.Color = c
	end)

	local enemyModel = players:AddSection("Enemy Model", "Left", "Enemies")
	chamsRow(enemyModel, "Player", "Enemies", Color3.fromRGB(160, 170, 250), true)
	chamsRow(enemyModel, "Behind Walls", "Enemies", Color3.fromRGB(90, 240, 240))
	chamsRow(enemyModel, "On Shot", "Enemies", Color3.fromRGB(225, 232, 225))
	chamsRow(enemyModel, "History", "Enemies", Color3.fromRGB(200, 200, 200))
	chamsRow(enemyModel, "Ragdolls", "Enemies", Color3.fromRGB(150, 145, 170))
	enemyModel:AddToggle("Kill Effect", false, function(v)
		espCfg.KillEffect.On = v
	end):AddColor(Color3.fromRGB(240, 50, 70), function(c)
		espCfg.KillEffect.Color = c
	end)
	enemyModel:AddToggle("Glow", false, function(v)
		espCfg.Glow.On = v
	end):AddColor(Color3.fromRGB(200, 195, 240), function(c)
		espCfg.Glow.Color = c
	end)

	-- Teammates
	local teammate = players:AddSection("Teammate", "Left", "Teammates")
	teammate:AddToggle("Enabled", false, function(v)
		TeamVisuals.Cfg.Enabled = v
	end)

	local teammateModel = players:AddSection("Teammate Model", "Left", "Teammates")
	chamsRow(teammateModel, "Player", "Teammates", Color3.fromRGB(225, 225, 250), true, "TeamPlayer")
	chamsRow(teammateModel, "Behind Walls", "Teammates", Color3.fromRGB(250, 210, 180), nil, "TeamWalls")
	teammateModel:AddToggle("Disable Model Rendering", false, function(v)
		TeamVisuals.Cfg.Hide = v
	end)
	teammateModel:AddToggle("Glow", false, function(v)
		TeamVisuals.Cfg.Glow.On = v
	end):AddColor(Color3.fromRGB(200, 200, 200), function(c)
		TeamVisuals.Cfg.Glow.Color = c
	end)

	local localModel = players:AddSection("Local Player Model", "Left", "Teammates")
	local modelNav = localModel:AddNav("Model")
	chamsRow(modelNav, "Chams", "Teammates", Color3.fromRGB(160, 170, 250), nil, "LocalModel")
	modelNav:AddToggle("Glow", false, function(v)
		TeamVisuals.Cfg.Local.ModelGlow.On = v
	end):AddColor(Color3.fromRGB(200, 200, 200), function(c)
		TeamVisuals.Cfg.Local.ModelGlow.Color = c
	end)
	local weaponNav = localModel:AddNav("Weapon")
	chamsRow(weaponNav, "Chams", "Teammates", Color3.fromRGB(160, 170, 250), nil, "LocalWeapon")
	local transparencyNav = localModel:AddNav("Transparency")
	transparencyNav:AddSlider("Model", 0, 100, 0, function(v)
		TeamVisuals.Cfg.Local.Transparency = v
	end, "%")
	transparencyNav:AddSlider("When Scoped", 0, 100, 0, function(v)
		TeamVisuals.Cfg.Local.Scoped = v
	end, "%")
end

------------------------------------------------------------------
-- World FX engine: Visuals > World > Ambience effects and View Options.
-- Lighting properties are "claimed": the original value is stored when an effect takes a property and
-- put back when the effect is switched off. Own post effects are named NL_*.
-- Lua units: studs; the menu's metres are converted with 1 stud = 0.28 m.
------------------------------------------------------------------
local WorldFX = {}
do
	local Lighting = game:GetService("Lighting")
	local Workspace = game:GetService("Workspace")
	local WHITE = Color3.new(1, 1, 1)
	local STUDS_PER_METER = 1 / 0.28
	local NIL = {} -- "set this property to nil" (Sky.Parent)

	local Cfg = {
		Night = { On = false, Color = rgb(150, 145, 170) },
		Fullbright = { On = false, Color = WHITE },
		Exposure = { On = false, Adaptation = "Map", Compensation = 0 },
		Sunlight = { On = false, Color = rgb(220, 220, 228) },
		Sky = { On = false, Color = WHITE },
		Fog = { On = false, Color = rgb(245, 245, 245), Start = 0, End = 120 }, -- metres
		Bloom = { On = false, Strength = 50, Blur = 5, Threshold = 10 },
		Vignette = { On = false, Color = WHITE },
		LocalContrast = { On = false, Strength = 50, VignetteStart = 25, VignetteEnd = 80 },
		Correction = {
			On = false, Contrast = 0, Highlights = 0, Shadows = 0, Saturation = 0, Vibrance = 0,
			Temperature = 0, Tint = 0, Grayscale = false,
		},
		Dof = { On = false, Mode = "Manual", Distance = 20, Range = 40 }, -- metres
		Wind = { On = false, Direction = 0, Strength = 30 },
		Thunder = { On = false, Color = rgb(200, 220, 255) },
		Rain = { On = false, Color = rgb(225, 235, 255) },
		Snow = { On = false, Color = WHITE },
		Removals = {},
		Fov = { On = false, Value = 90 },
		ScopeZoom = { 0, 0 }, -- first / second scope magnification, 0 = the game's own
		Third = { On = false, Distance = 12, Disablers = { "Close to Wall" } },
		Aspect = { On = false, Scaling = "Horizontal", Value = 100 },
	}
	WorldFX.Cfg = Cfg

	local logLine
	local ready = false -- menu callbacks fire with defaults while the script builds: stay quiet until then
	local warned = {}
	function WorldFX.Unwired(name, reason)
		if ready and not warned[name] then
			warned[name] = true
			if logLine then
				logLine(name .. ": not active, " .. reason)
			end
		end
	end
	function WorldFX.Bind(log)
		logLine = log
		task.delay(3, function()
			ready = true
		end)
	end

	local function scale(c, k)
		return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
	end

	------------------------------------------------------------------
	-- Property claims
	------------------------------------------------------------------
	local owned = {} -- [instance] = { [property] = original value }
	local want

	local function claim(inst, prop, value)
		local t = want[inst]
		if not t then
			t = {}
			want[inst] = t
		end
		t[prop] = if value == nil then NIL else value
	end

	local function flush()
		for inst, props in pairs(owned) do
			for prop, original in pairs(props) do
				local w = want[inst]
				if not (w and w[prop] ~= nil) then
					pcall(function()
						inst[prop] = original
					end)
					props[prop] = nil
				end
			end
			if next(props) == nil then
				owned[inst] = nil
			end
		end
		for inst, props in pairs(want) do
			local o = owned[inst]
			if not o then
				o = {}
				owned[inst] = o
			end
			for prop, value in pairs(props) do
				pcall(function()
					if o[prop] == nil then
						o[prop] = inst[prop]
					end
					local v = if value == NIL then nil else value
					if inst[prop] ~= v then
						inst[prop] = v
					end
				end)
			end
		end
	end

	-- own post effect: created when switched on, disabled when switched off
	local function own(class, name, on)
		local inst = Lighting:FindFirstChild(name)
		if on then
			if not inst or inst.ClassName ~= class then
				if inst then
					inst:Destroy()
				end
				inst = Instance.new(class)
				inst.Name = name
				inst.Parent = Lighting
			end
			inst.Enabled = true
			return inst
		elseif inst then
			inst.Enabled = false
		end
		return nil
	end

	------------------------------------------------------------------
	-- Vignette + thunder flash overlay
	------------------------------------------------------------------
	local gui = create("ScreenGui", {
		Name = "WorldFXOverlay",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 3,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local edges = {}
	for _, def in ipairs({
		{ "Top", 90 }, { "Bottom", 270 }, { "Left", 0 }, { "Right", 180 },
	}) do
		local f = create("Frame", {
			BorderSizePixel = 0,
			Visible = false,
			Active = false,
			Parent = gui,
		})
		local g = Instance.new("UIGradient")
		g.Rotation = def[2]
		g.Parent = f
		edges[def[1]] = { Frame = f, Gradient = g }
	end
	local flash = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		Parent = gui,
	})
	local vignetteSignature

	local function updateVignette()
		local on = Cfg.Vignette.On
		local lc = Cfg.LocalContrast
		-- thickness of each edge band comes from "Vignette Start", its darkness from "Vignette End"
		local thickness = (100 - lc.VignetteStart) / 100 * 0.45 + 0.05
		local alpha = 1 - math.clamp(lc.VignetteEnd / 100, 0, 1)
		local color = Cfg.Vignette.Color
		local signature = tostring(on) .. tostring(color) .. thickness .. alpha
		if signature == vignetteSignature then
			return
		end
		vignetteSignature = signature
		for side, e in pairs(edges) do
			e.Frame.Visible = on
			e.Frame.BackgroundColor3 = color
			e.Frame.BackgroundTransparency = 0
			e.Gradient.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, alpha),
				NumberSequenceKeypoint.new(1, 1),
			})
			if side == "Top" then
				e.Frame.Position, e.Frame.Size = UDim2.fromScale(0, 0), UDim2.fromScale(1, thickness)
			elseif side == "Bottom" then
				e.Frame.Position, e.Frame.Size = UDim2.fromScale(0, 1 - thickness), UDim2.fromScale(1, thickness)
			elseif side == "Left" then
				e.Frame.Position, e.Frame.Size = UDim2.fromScale(0, 0), UDim2.fromScale(thickness, 1)
			else
				e.Frame.Position, e.Frame.Size = UDim2.fromScale(1 - thickness, 0), UDim2.fromScale(thickness, 1)
			end
		end
	end

	local rng = Random.new()
	local nextThunder = 0
	local function thunder(now)
		if not Cfg.Thunder.On then
			return
		end
		if now < nextThunder then
			return
		end
		nextThunder = now + 4 + rng:NextNumber() * 6
		flash.BackgroundColor3 = Cfg.Thunder.Color
		task.spawn(function()
			for _, strength in ipairs({ 0.7, 0.8 }) do
				flash.BackgroundTransparency = strength
				TweenService:Create(flash, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
				task.wait(0.18)
			end
		end)
	end

	------------------------------------------------------------------
	-- Rain / snow: particle emitters on a part that follows the camera
	------------------------------------------------------------------
	local weatherPart, rainEmitter, snowEmitter
	local function ensureWeather(cam)
		if not weatherPart or not weatherPart.Parent then
			weatherPart = Instance.new("Part")
			weatherPart.Name = "NL_Weather"
			weatherPart.Anchored, weatherPart.CanCollide, weatherPart.CanQuery, weatherPart.CanTouch = true, false, false, false
			weatherPart.CastShadow = false
			weatherPart.Transparency = 1
			weatherPart.Size = Vector3.new(90, 1, 90)

			rainEmitter = Instance.new("ParticleEmitter")
			rainEmitter.Rate = 900
			rainEmitter.Lifetime = NumberRange.new(0.9, 1.1)
			rainEmitter.Speed = NumberRange.new(95, 110)
			rainEmitter.EmissionDirection = Enum.NormalId.Bottom
			rainEmitter.SpreadAngle = Vector2.new(2, 2)
			rainEmitter.Orientation = Enum.ParticleOrientation.VelocityParallel
			rainEmitter.Size = NumberSequence.new(0.35)
			rainEmitter.Transparency = NumberSequence.new(0.55)
			rainEmitter.LightEmission = 0.3
			rainEmitter.Enabled = false
			rainEmitter.Parent = weatherPart

			snowEmitter = Instance.new("ParticleEmitter")
			snowEmitter.Rate = 350
			snowEmitter.Lifetime = NumberRange.new(5, 7)
			snowEmitter.Speed = NumberRange.new(7, 12)
			snowEmitter.EmissionDirection = Enum.NormalId.Bottom
			snowEmitter.SpreadAngle = Vector2.new(25, 25)
			snowEmitter.RotSpeed = NumberRange.new(-60, 60)
			snowEmitter.Size = NumberSequence.new(0.28)
			snowEmitter.Transparency = NumberSequence.new(0.15)
			snowEmitter.LightEmission = 0.4
			snowEmitter.Enabled = false
			snowEmitter.Parent = weatherPart
		end
		if weatherPart.Parent ~= cam then
			weatherPart.Parent = cam
		end
	end

	local function stepWeather(cam)
		local rain, snow = Cfg.Rain.On, Cfg.Snow.On
		if not (rain or snow) and not weatherPart then
			return
		end
		if rain or snow then
			ensureWeather(cam)
			weatherPart.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 35, 0))
		end
		if weatherPart then
			rainEmitter.Enabled = rain
			snowEmitter.Enabled = snow
			rainEmitter.Color = ColorSequence.new(Cfg.Rain.Color)
			snowEmitter.Color = ColorSequence.new(Cfg.Snow.Color)
		end
	end

	------------------------------------------------------------------
	-- Lighting and post effects
	------------------------------------------------------------------
	local focus = 50
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local skyStash = {}

	local function isRemoved(name)
		return table.find(Cfg.Removals, name) ~= nil
	end

	local function step(cam, dt, now)
		want = {}
		local C = Cfg

		if C.Night.On then
			local c = C.Night.Color
			claim(Lighting, "ClockTime", 0)
			claim(Lighting, "Brightness", 0.4)
			claim(Lighting, "Ambient", scale(c, 0.3))
			claim(Lighting, "OutdoorAmbient", scale(c, 0.3))
		end
		if C.Fullbright.On then
			claim(Lighting, "Brightness", 2)
			claim(Lighting, "Ambient", C.Fullbright.Color)
			claim(Lighting, "OutdoorAmbient", C.Fullbright.Color)
			claim(Lighting, "GlobalShadows", false)
		end
		if C.Exposure.On then
			local base = (owned[Lighting] and owned[Lighting].ExposureCompensation) or Lighting.ExposureCompensation
			claim(Lighting, "ExposureCompensation", if C.Exposure.Adaptation == "Map" then base + C.Exposure.Compensation else C.Exposure.Compensation)
		end
		if C.Sunlight.On then
			claim(Lighting, "ColorShift_Top", C.Sunlight.Color)
		end
		if C.Fog.On then
			claim(Lighting, "FogColor", C.Fog.Color)
			claim(Lighting, "FogStart", C.Fog.Start * STUDS_PER_METER)
			claim(Lighting, "FogEnd", math.max(C.Fog.End, C.Fog.Start + 1) * STUDS_PER_METER)
		end

		-- Sky colour: the map's Atmosphere is recoloured, or an own one is added
		local gameAtmosphere, ownAtmosphere
		for _, child in ipairs(Lighting:GetChildren()) do
			if child:IsA("Atmosphere") then
				if child.Name == "NL_Atmosphere" then
					ownAtmosphere = child
				elseif not gameAtmosphere then
					gameAtmosphere = child
				end
			end
		end
		if C.Sky.On then
			local target = gameAtmosphere
			if not target then
				if not ownAtmosphere then
					ownAtmosphere = Instance.new("Atmosphere")
					ownAtmosphere.Name = "NL_Atmosphere"
					ownAtmosphere.Density, ownAtmosphere.Offset, ownAtmosphere.Glare, ownAtmosphere.Haze = 0.3, 0, 0, 0
					ownAtmosphere.Parent = Lighting
				end
				target = ownAtmosphere
			end
			claim(target, "Color", C.Sky.Color)
			claim(target, "Decay", C.Sky.Color)
		elseif ownAtmosphere then
			ownAtmosphere:Destroy()
		end

		-- removals
		if isRemoved("Fog") then
			claim(Lighting, "FogStart", 1e6)
			claim(Lighting, "FogEnd", 1e6)
			if gameAtmosphere then
				claim(gameAtmosphere, "Density", 0)
				claim(gameAtmosphere, "Haze", 0)
			end
		end
		if isRemoved("Sunlight") then
			claim(Lighting, "Brightness", 0)
		end
		if isRemoved("Dynamic Shadows") then
			claim(Lighting, "GlobalShadows", false)
		end
		if isRemoved("Post Processing") then
			local function sweep(parent)
				for _, e in ipairs(parent:GetDescendants()) do
					if e:IsA("PostEffect") and string.sub(e.Name, 1, 3) ~= "NL_" then
						claim(e, "Enabled", false)
					end
				end
			end
			sweep(Lighting)
			sweep(cam)
		end
		if isRemoved("2D Skybox") then
			for _, child in ipairs(Lighting:GetChildren()) do
				if child:IsA("Sky") then
					skyStash[child] = true
				end
			end
			for sky in pairs(skyStash) do
				claim(sky, "Parent", nil)
			end
		elseif next(skyStash) then
			skyStash = {}
		end

		if C.Wind.On then
			local a = math.rad(C.Wind.Direction)
			claim(Workspace, "GlobalWind", Vector3.new(math.cos(a), 0, math.sin(a)) * (C.Wind.Strength * 0.5))
		end

		flush()

		-- own post effects
		local bloom = own("BloomEffect", "NL_Bloom", C.Bloom.On)
		if bloom then
			bloom.Intensity = C.Bloom.Strength / 50
			bloom.Size = C.Bloom.Blur / 100 * 56
			bloom.Threshold = C.Bloom.Threshold / 100 * 2
		end

		local cc = C.Correction
		local lc = C.LocalContrast
		local correction = own("ColorCorrectionEffect", "NL_ColorCorrection", cc.On or lc.On)
		if correction then
			local contrast = if cc.On then cc.Contrast / 100 else 0
			if lc.On then
				contrast += lc.Strength / 100 * 0.4
			end
			correction.Contrast = math.clamp(contrast, -1, 1)
			local saturation = if cc.On then cc.Saturation / 100 + cc.Vibrance / 200 else 0
			correction.Saturation = if cc.On and cc.Grayscale then -1 else math.clamp(saturation, -1, 1)
			correction.Brightness = if cc.On then math.clamp((cc.Highlights + cc.Shadows) / 400, -0.5, 0.5) else 0
			local t, g = cc.Temperature / 100, cc.Tint / 100
			correction.TintColor = if cc.On
				then Color3.new(math.min(1, 1 + 0.25 * t), math.min(1, 1 - 0.25 * g), math.min(1, 1 - 0.25 * t))
				else WHITE
		end

		local dof = own("DepthOfFieldEffect", "NL_DepthOfField", C.Dof.On)
		if dof then
			if C.Dof.Mode == "Crosshair" then
				rayParams.FilterDescendantsInstances = { player.Character, Workspace.CurrentCamera } -- the camera holds the viewmodel
				local hit = Workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 2000, rayParams)
				focus += ((if hit then hit.Distance else 1000) - focus) * math.min(1, dt * 8)
				dof.FocusDistance = focus
			else
				dof.FocusDistance = C.Dof.Distance * STUDS_PER_METER
			end
			dof.InFocusRadius = C.Dof.Range * STUDS_PER_METER / 2
			dof.NearIntensity, dof.FarIntensity = 0.7, 0.7
		end

		updateVignette()
		thunder(now)
		stepWeather(cam)
	end

	------------------------------------------------------------------
	-- View: FOV override and aspect-ratio stretch. The stretch is a non-uniform scale on the camera CFrame;
	-- it is taken off at the start of every frame so the game's camera never sees (and compounds) it.
	------------------------------------------------------------------
	local stretchBase -- the camera CFrame before this script changed it (third person / stretch)
	local fovOriginal
	local function undoStretch()
		if stretchBase then
			local cam = Workspace.CurrentCamera
			if cam then
				cam.CFrame = stretchBase
			end
			stretchBase = nil
		end
	end

	------------------------------------------------------------------
	-- Third person. The game's camera is first person; the camera is pulled back along its own look axis by
	-- "Distance" studs (shortened when Map.Geometry / Map.Regen is behind it; both names MEASURED in BulletCast).
	-- The local character is shown by setting LocalTransparencyModifier = 0 on its parts, except the invisible helper
	-- parts measured on a character (Head, HeadHB, HumanoidRootPart, Gun, BackC4). The viewmodel (workspace.Camera.Arms,
	-- MEASURED in the dump) is hidden the same way. That the local character is hidden through the modifier and not
	-- through Transparency is NOT measured: Event Logs says so if limbs turn out to have Transparency 1.
	------------------------------------------------------------------
	local TP_HELPERS = { Head = true, HeadHB = true, HumanoidRootPart = true, Gun = true, BackC4 = true, StandHitbox = true }
	local third = { Active = false, Parts = {}, ArmsParts = {}, At = 0, Reported = false }
	local tpParams = RaycastParams.new()
	tpParams.FilterType = Enum.RaycastFilterType.Include
	tpParams.IgnoreWater = true

	local function hasOption(list, name)
		return table.find(list, name) ~= nil
	end

	local function thirdPersonDistance(cam)
		local T = Cfg.Third
		if not T.On then
			return nil
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return nil
		end
		if hasOption(T.Disablers, "While Scoped") then
			local ads = character:FindFirstChild("ADS") -- MEASURED: BoolValue, true while aiming down sights
			if ads and ads:IsA("BoolValue") and ads.Value then
				return nil
			end
		end
		local want = T.Distance
		local map = Workspace:FindFirstChild("Map")
		local include = {}
		for _, name in ipairs({ "Geometry", "Regen" }) do
			local folder = map and map:FindFirstChild(name)
			if folder then
				table.insert(include, folder)
			end
		end
		if #include > 0 then
			tpParams.FilterDescendantsInstances = include
			local base = cam.CFrame
			local hit = Workspace:Raycast(base.Position, -base.LookVector * (want + 0.6), tpParams)
			if hit then
				if hasOption(T.Disablers, "Close to Wall") and hit.Distance < 3 then
					return nil
				end
				want = math.max(0.5, hit.Distance - 0.6)
			end
		end
		return want
	end

	local function setThirdVisibility(on, cam)
		local now = os.clock()
		if now - third.At > 0.5 then
			third.At = now
			third.Parts, third.ArmsParts = {}, {}
			local character = player.Character
			if character then
				for _, d in ipairs(character:GetDescendants()) do
					if d:IsA("BasePart") and not TP_HELPERS[d.Name] then
						table.insert(third.Parts, d)
					end
				end
			end
			local arms = cam:FindFirstChild("Arms")
			if arms then
				for _, d in ipairs(arms:GetDescendants()) do
					if d:IsA("BasePart") then
						table.insert(third.ArmsParts, d)
					end
				end
			end
		end
		for _, p in ipairs(third.Parts) do
			p.LocalTransparencyModifier = if on then 0 else p.LocalTransparencyModifier
		end
		for _, p in ipairs(third.ArmsParts) do
			p.LocalTransparencyModifier = if on then 1 else 0
		end
		third.Active = on
		TeamVisuals.Cfg.Local.ThirdOn = on
	end

	------------------------------------------------------------------
	-- Viewmodel offset through the game's own settings. MEASURED (Controllers.SettingsController, Modules.Settings):
	-- the in-game "Viewmodel Position X / Y / Z" live at {"Misc", "Viewmodel Position <axis>"}, limited to -1..1, and
	-- SettingsController:SetState(path, value) updates the state, tells the game's listeners (which move the viewmodel)
	-- and sends the settings to the server. The menu slider -20..20 maps to -1..1. The first call per axis is the
	-- menu's default value at start-up and is skipped, so the player's in-game setting is not overwritten by it.
	------------------------------------------------------------------
	local settingsModule
	local function gameSettings()
		if settingsModule == nil then
			local ok, module = pcall(function()
				local controllers = game:GetService("ReplicatedStorage"):FindFirstChild("Controllers")
				local m = controllers and controllers:FindFirstChild("SettingsController")
				return m and require(m)
			end)
			settingsModule = if ok and type(module) == "table" then module else false
		end
		return settingsModule or nil
	end

	local viewmodelSeen = {}
	function WorldFX.SetViewmodel(axis, menuValue)
		if not viewmodelSeen[axis] then
			viewmodelSeen[axis] = true
			return
		end
		local settings = gameSettings()
		if not settings then
			WorldFX.Unwired("Viewmodel offset", "the game's SettingsController is not reachable")
			return
		end
		local path = { "Misc", "Viewmodel Position " .. axis }
		local value = math.clamp(menuValue / 20, -1, 1)
		local ok, current = pcall(settings.GetState, settings, path)
		if ok and current == value then
			return
		end
		pcall(settings.SetState, settings, path, value)
	end

	-- Scope Zoom (Scope Options: First Scope / Second Scope, x0..x10).
	-- A sniper is a weapon whose ReplicatedStorage.Weapons.<name> has a Scoped value (MEASURED: AWP, Scout, G3SG1); it counts as
	-- scoped while character.ADS (a BoolValue, MEASURED to exist) is true (ASSUMED to be the scope flag). The game's own scoped
	-- field of view is not in the dump (the weapon client script is missing), so it is learned at run time: whatever differs from
	-- what this script wrote last frame was set by the game; a value that stays put for 0.15 s is a scope level of that weapon,
	-- the biggest level is the first scope, the next one the second (ASSUMED: each scope stage has its own field of view).
	-- x = magnification against the normal (not scoped) field of view: FOV = 2 * atan(tan(normal / 2) / x). x0 means "the game's
	-- own scoped field of view" - also while Override FOV is on, which would otherwise cancel the game's zoom completely.
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local scopeSeen = { Last = nil, Game = nil, Since = 0, Base = nil, Out = nil }
	local scopeLevels = {} -- [weapon name] = { biggest field of view first }

	local function scopedSniper()
		local character = player.Character
		local ads = character and character:FindFirstChild("ADS")
		local equipped = character and character:FindFirstChild("EquippedTool")
		if not (ads and ads:IsA("BoolValue") and ads.Value and equipped and equipped:IsA("StringValue") and equipped.Value ~= "") then
			return nil
		end
		local weapons = ReplicatedStorage:FindFirstChild("Weapons")
		local weapon = weapons and weapons:FindFirstChild(equipped.Value)
		if weapon and weapon:FindFirstChild("Scoped") then
			return equipped.Value
		end
		return nil
	end
	-- the field of view that magnifies `base` by x (x = 1 leaves it unchanged), kept inside what Roblox accepts
	local function zoomedFov(base, x)
		return math.clamp(math.deg(2 * math.atan(math.tan(math.rad(base) / 2) / x)), 1, 120)
	end
	-- the scope stage (1 = biggest learned field of view) a game field of view belongs to
	local function stageOf(levels, fov)
		local best, bestDiff = 1, math.huge
		for i, level in ipairs(levels) do
			local diff = math.abs(level - fov)
			if diff < bestDiff then
				best, bestDiff = i, diff
			end
		end
		return best
	end
	-- adds a stable level (values closer than 0.75 degrees are the same level), biggest first, at most 3
	local function addLevel(levels, fov)
		for _, level in ipairs(levels) do
			if math.abs(level - fov) < 0.75 then
				return
			end
		end
		table.insert(levels, fov)
		table.sort(levels, function(a, b)
			return a > b
		end)
		while #levels > 3 do
			table.remove(levels)
		end
	end
	-- true when the scoped-sniper logic owns the field of view this frame (then the plain Override FOV must not write it)
	local function scopeStep(cam, dt, now)
		local F = Cfg.Fov
		local current = cam.FieldOfView
		-- a value that is not the one this script wrote last frame was set by the game; only a different value than the game's
		-- previous one restarts the stability timer (the game may write the same number every frame while we overwrite it)
		if scopeSeen.Last == nil or math.abs(current - scopeSeen.Last) > 0.01 then
			if scopeSeen.Game == nil or math.abs(current - scopeSeen.Game) > 0.01 then
				scopeSeen.Game, scopeSeen.Since = current, now
			end
		end
		local sniper = scopedSniper()
		if not sniper then
			scopeSeen.Out = nil
			if not F.On then
				scopeSeen.Base = current -- the game's normal field of view
			end
			return false
		end
		local levels = scopeLevels[sniper]
		if not levels then
			levels = {}
			scopeLevels[sniper] = levels
		end
		local gameFov = scopeSeen.Game or current
		if now - scopeSeen.Since >= 0.15 then
			addLevel(levels, gameFov)
		end
		local x = Cfg.ScopeZoom[math.min(stageOf(levels, gameFov), 2)] or 0
		local base = if F.On then F.Value else (scopeSeen.Base or current)
		local target
		if x > 0 then
			target = zoomedFov(base, x)
		elseif F.On then
			target = gameFov -- Override FOV would cancel the game's zoom: let the game's scoped value through
		end
		if target then
			local value = scopeSeen.Out or current
			value = value + (target - value) * (1 - math.exp(-25 * math.min(dt, 0.1)))
			if math.abs(value - target) < 0.05 then
				value = target
			end
			scopeSeen.Out = value
			cam.FieldOfView = value
		else
			scopeSeen.Out = nil
		end
		scopeSeen.Last = cam.FieldOfView
		return true
	end

	local function applyView(cam, dt)
		local F, A = Cfg.Fov, Cfg.Aspect
		local handled = scopeStep(cam, dt or 1 / 60, os.clock())
		if handled then
			-- a scoped sniper: the scope step set (or deliberately left) the field of view
		elseif F.On then
			if not fovOriginal then
				fovOriginal = cam.FieldOfView
			end
			cam.FieldOfView = F.Value
			scopeSeen.Last = cam.FieldOfView
		elseif fovOriginal then
			cam.FieldOfView = fovOriginal
			fovOriginal = nil
			scopeSeen.Last = nil
		end
		local base = cam.CFrame
		local cf = base
		local distance = thirdPersonDistance(cam)
		if distance then
			cf = cf * CFrame.new(0, 0, distance)
			setThirdVisibility(true, cam)
		elseif third.Active then
			setThirdVisibility(false, cam)
		end
		if A.On and A.Value ~= 100 then
			local k = 100 / A.Value
			-- Horizontal: world gets wider (Y compressed); Vertical: world gets taller (X compressed)
			local m = if A.Scaling == "Horizontal"
				then CFrame.new(0, 0, 0, 1, 0, 0, 0, k, 0, 0, 0, 1)
				else CFrame.new(0, 0, 0, k, 0, 0, 0, 1, 0, 0, 0, 1)
			cf = cf * m
		end
		if cf ~= base then
			stretchBase = base
			cam.CFrame = cf
		end
	end

	local lastError
	local function guarded(fn)
		local ok, err = pcall(fn)
		if not ok and err ~= lastError then
			lastError = err
			warn("[WorldFX] " .. tostring(err))
			if logLine then
				logLine("World FX error, see console")
			end
		end
	end

	pcall(RunService.UnbindFromRenderStep, RunService, "WorldFXUndo")
	pcall(RunService.UnbindFromRenderStep, RunService, "WorldFXView")
	pcall(RunService.UnbindFromRenderStep, RunService, "WorldFXAmbience")
	pcall(RunService.UnbindFromRenderStep, RunService, "WorldFXViewmodel") -- removed binding of an earlier version
	RunService:BindToRenderStep("WorldFXUndo", Enum.RenderPriority.First.Value, function()
		guarded(undoStretch)
	end)
	RunService:BindToRenderStep("WorldFXView", Enum.RenderPriority.Camera.Value + 2, function(dt)
		local cam = Workspace.CurrentCamera
		if cam then
			guarded(function()
				applyView(cam, dt)
			end)
		end
	end)
	RunService:BindToRenderStep("WorldFXAmbience", Enum.RenderPriority.Last.Value - 1, function(dt)
		local cam = Workspace.CurrentCamera
		if cam then
			guarded(function()
				step(cam, dt, os.clock())
			end)
		end
	end)

	-- Unload: stop the render steps, put every claimed Lighting / Workspace property back, remove the own effects
	table.insert(Unloaders, function()
		for _, name in ipairs({ "WorldFXUndo", "WorldFXView", "WorldFXAmbience", "WorldFXViewmodel" }) do
			pcall(RunService.UnbindFromRenderStep, RunService, name)
		end
		pcall(undoStretch)
		pcall(function()
			local cam = Workspace.CurrentCamera
			if cam and third.Active then
				setThirdVisibility(false, cam)
			end
			if cam and fovOriginal then
				cam.FieldOfView = fovOriginal
			end
		end)
		want = {}
		pcall(flush)
		for _, name in ipairs({ "NL_Bloom", "NL_ColorCorrection", "NL_DepthOfField", "NL_Atmosphere" }) do
			local inst = Lighting:FindFirstChild(name)
			if inst then
				inst:Destroy()
			end
		end
		if weatherPart then
			weatherPart:Destroy()
		end
		gui:Destroy()
	end)
end


------------------------------------------------------------------
-- Visuals > World
------------------------------------------------------------------
do
	WorldFX.Bind(function(text)
		menu:Log(text)
	end)
	local view = world:AddSection("View", "Left")

	local viewOptions = view:AddNav("View Options")
	local fovValue, aspectScaling, aspectValue
	local viewFx = WorldFX.Cfg
	local overrideFov = viewOptions:AddToggle("Override FOV", false, function(v)
		viewFx.Fov.On = v
		if fovValue then
			fovValue:SetDisabled(not v)
		end
	end)
	fovValue = viewOptions:AddSlider("Value", 60, 120, 90, function(v)
		viewFx.Fov.Value = v
	end, "°")
	fovValue:SetDisabled(not overrideFov:Get())
	local aspect = viewOptions:AddGroup()
	local overrideAspect = aspect:AddToggle("Override Aspect Ratio", false, function(v)
		viewFx.Aspect.On = v
		if aspectScaling then
			aspectScaling:SetDisabled(not v)
			aspectValue:SetDisabled(not v)
		end
	end)
	aspectScaling = aspect:AddDropdown("Scaling", { "Horizontal", "Vertical" }, "Horizontal", function(v)
		viewFx.Aspect.Scaling = v
	end)
	aspectValue = aspect:AddSlider("Value", 50, 200, 100, function(v)
		viewFx.Aspect.Value = v
	end, "%")
	aspectScaling:SetDisabled(not overrideAspect:Get())
	aspectValue:SetDisabled(not overrideAspect:Get())
	viewOptions:AddGroup():AddToggle("Disable Landing Bob", false, function(v)
		if v then
			WorldFX.Unwired("Disable Landing Bob", "the game's landing animation is not measured")
		end
	end)

	local scopeOptions = view:AddNav("Scope Options")
	scopeOptions:AddToggle("Remove Zoom", false, Feat.unwired("Remove Zoom", Feat.Notes.Scope))
	scopeOptions:AddToggle("Remove Blur", false, Feat.unwired("Remove Blur", Feat.Notes.Scope))
	-- Scope Zoom: x0 = the game's own scoped field of view, otherwise the magnification of that scope stage
	scopeOptions:AddSlider("First Scope", 0, 10, 0, function(v)
		WorldFX.Cfg.ScopeZoom[1] = v
	end, "x", { Decimals = 1 })
	scopeOptions:AddSlider("Second Scope", 0, 10, 0, function(v)
		WorldFX.Cfg.ScopeZoom[2] = v
	end, "x", { Decimals = 1 })

	local viewmodel = view:AddNav("Viewmodel Options")
	viewmodel:AddSlider("Offset X", -20, 20, 0, function(v)
		WorldFX.SetViewmodel("X", v)
	end)
	viewmodel:AddSlider("Offset Y", -20, 20, 0, function(v)
		WorldFX.SetViewmodel("Y", v)
	end)
	viewmodel:AddSlider("Offset Z", -20, 20, 0, function(v)
		WorldFX.SetViewmodel("Z", v)
	end)

	local perspective = view:AddNav("Perspective Options")
	perspective:AddToggle("Force Third Person", false, function(v)
		WorldFX.Cfg.Third.On = v
	end)
	perspective:AddMultiDropdown("Disablers", { "Close to Wall", "While Scoped" }, { "Close to Wall" }, function(list)
		WorldFX.Cfg.Third.Disablers = list
	end)
	perspective:AddSlider("Distance", 5, 30, 12, function(v)
		WorldFX.Cfg.Third.Distance = v
	end)
	perspective:AddGroup():AddMultiDropdown("Disable Overhead", { "Grenades", "Knife" }, {}, function(list)
		if #list > 0 then
			WorldFX.Unwired("Disable Overhead", "the game's grenade / knife item names are not measured")
		end
	end)

	view:AddMultiDropdown("Unlock Spectating", { "Enemies", "Teammates" }, {}, Feat.unwired("Unlock Spectating", "what restricts spectating is not identified: spectate.txt records attribute changes while spectating, not the camera script; trace the spectate GUI / camera code"))
	view:AddMultiDropdown("Visual Recoil", { "Camera", "Viewmodel" }, {}, Feat.unwired("Visual Recoil", Feat.Notes.Recoil))

	local esp = world:AddSection("World ESP", "Left")
	local bomb = esp:AddNav("Bomb")
	bomb:AddToggle("Icon", false, Feat.unwired("Bomb Icon", Feat.Notes.World))
	bomb:AddToggle("Timer", false, Feat.unwired("Bomb Timer", Feat.Notes.World))
	local weapons = esp:AddNav("Weapons")
	weapons:AddToggle("Enabled", false, Feat.unwired("Weapon ESP", Feat.Notes.World))
	weapons:AddToggle({ "Colorize Effects", "image" }, false, Feat.unwired("Weapon Colorize Effects", Feat.Notes.World))
	local weaponItems = weapons:AddGroup()
	weaponItems:AddToggle("Icon", false, Feat.unwired("Weapon ESP Icon", Feat.Notes.World))
	weaponItems:AddToggle("Text", false, Feat.unwired("Weapon ESP Text", Feat.Notes.World))
	weaponItems:AddToggle("Ammo", false, Feat.unwired("Weapon ESP Ammo", Feat.Notes.World))
	weaponItems:AddToggle("Distance", false, Feat.unwired("Weapon ESP Distance", Feat.Notes.World))
	weaponItems:AddToggle("Glow", false, Feat.unwired("Weapon ESP Glow", Feat.Notes.World))
	local hostages = esp:AddNav("Hostages")
	hostages:AddToggle("Enabled", false, Feat.unwired("Hostage ESP", Feat.Notes.World)):AddColor(Color3.fromRGB(255, 94, 140), noop)
	hostages:AddToggle({ "Rescue Indicator", "user" }, false, Feat.unwired("Rescue Indicator", Feat.Notes.World)):AddColor(Color3.fromRGB(110, 190, 255), noop)
	local grenades = esp:AddNav("Grenades")
	grenades:AddToggle("Enabled", false, function(v) Feat.GrenadeEsp = v end):AddSettings(250, "Grenades")
	grenades:AddToggle({ "Smoke Radius", "ring" }, false, function(v) Feat.SmokeRadius = v end)
	grenades:AddToggle({ "Inferno Radius", "ring" }, false, function(v) Feat.InfernoRadius = v end)
	grenades:AddGroup():AddToggle("Effects", false, function(v) Feat.GrenadeFx = v end):AddColor(Color3.fromRGB(255, 94, 200), function(c) Feat.GrenadeFxColor = c end)
	local trajectory = esp:AddToggle("Grenade Trajectory", false, function(v) Feat.Trajectory = v end):AddSettings(250, "Trajectory")
	trajectory:AddSlider("Thickness", 1, 5, 2, function(v) Feat.TrajThickness = v end)
	trajectory:AddColorPicker("Color", Color3.fromRGB(255, 94, 200), function(c) Feat.TrajColor = c end)
	esp:AddToggle("Grenade Proximity Warnings", false, function(v) Feat.Proximity = v end)

	local hud = world:AddSection("HUD", "Right")
	hud:AddMultiDropdown("Radar", { "Enemies", "Teammates", "Bomb" }, {}, function(list) Feat.Radar = list end)
	hud:AddToggle("Session Stats", false, function(v) Feat.SessionStats = v end)
	hud:AddToggle("Speedometer", false, function(v) Feat.Speedometer = v end)
	hud:AddDropdown("Scope Overlay", { "Default", "Lines", "Off" }, "Default", function(v) if v ~= "Default" then Feat.gate("Scope Overlay", Feat.Notes.Gui) end end):AddColor(Color3.fromRGB(10, 10, 14), noop)
	hud:AddToggle("Inaccuracy Overlay", false, Feat.unwired("Inaccuracy Overlay", "spread units are not measured: Weapons.<name>.Spread values exist but their mapping to a screen angle is unknown; read where the weapon client script applies spread")):AddColor(Color3.fromRGB(150, 150, 160), noop)
	local notices = hud:AddNav("Death Notices")
	notices:AddDropdown("Preserve Notices", { "Off", "Own Kills", "All" }, "Off", Feat.unwired("Preserve Notices", "the AddToKillfeed remote is measured but the killfeed GUI is not; " .. Feat.Notes.Gui))
	notices:AddToggle("Hide Teammate Assists", false, Feat.unwired("Hide Teammate Assists", Feat.Notes.Gui))
	local scoreboard = hud:AddNav("Scoreboard")
	scoreboard:AddToggle("Reveal Ranks", false, Feat.unwired("Reveal Ranks", Feat.Notes.Gui))
	local crosshairs = hud:AddNav("Crosshairs")
	crosshairs:AddToggle("Force Sniper Crosshair", false, Feat.unwired("Force Sniper Crosshair", Feat.Notes.Gui))
	crosshairs:AddToggle("Force While Scoped", false, Feat.unwired("Force While Scoped", Feat.Notes.Scope))
	crosshairs:AddToggle("Hide While Holding Knife", false, Feat.unwired("Hide While Holding Knife", Feat.Notes.Gui))
	crosshairs:AddToggle("Penetration", false, function(v) Feat.Penetration = v end):AddColor(Color3.fromRGB(94, 94, 247), function(c) Feat.PenetrationColor = c end)

	local miscellaneous = world:AddSection("Miscellaneous", "Right")
	-- these four drive the menu's own HUD windows
	local windows = miscellaneous:AddNav("Windows", 280)
	local function option(key)
		return function(v)
			menu:SetHudOption(key, v)
		end
	end

	-- Watermark
	local watermark = windows:AddToggle({ "Watermark", "text" }, true, function(v)
		menu:SetWindow("Watermark", v)
	end):AddSettings(270, "Watermark")
	local itemNames, itemIcons = menu:GetWatermarkItems()
	watermark:AddMultiDropdown({ "Items", "list" }, itemNames, { "Logo", "Time", "Username", "Preset" }, option("Items"), itemIcons)
	watermark:AddDropdown(
		{ "Position", "pin" },
		{ "Top-Left", "Top-Center", "Top-Right", "Bottom-Right", "Bottom-Center", "Bottom-Left" },
		"Top-Center",
		option("Position")
	)
	watermark:AddDropdown({ "Density", "expand" }, { "Compact", "Default", "Spacious" }, "Default", option("Density"))
	-- colours values by state: framerate, delay, jitter, connection (green / yellow / red)
	watermark:AddToggle({ "Additional Colors", "image" }, false, option("AdditionalColors"))
	watermark:AddGroup():AddToggle({ "Display Avatar", "user" }, false, option("Avatar"))

	-- Hotkeys
	local hotkeysWindow = windows:AddToggle({ "Hotkeys", "list" }, true, function(v)
		menu:SetWindow("Hotkeys", v)
	end):AddSettings(260, "Hotkeys")
	hotkeysWindow:AddDropdown("Style", { "Default", "Inverted" }, "Default", option("HotkeysStyle"))
	hotkeysWindow:AddToggle("Right-Aligned", false, option("HotkeysRight"))
	hotkeysWindow:AddToggle("Dynamic Header", false, option("HotkeysDynamic"))

	windows:AddToggle({ "Spectators", "eye" }, true, function(v)
		menu:SetWindow("Spectators", v)
	end)

	-- Event Logs
	local eventLogs = windows:AddToggle({ "Event Logs", "panel" }, true, function(v)
		menu:SetWindow("Event Logs", v)
	end):AddSettings(270, "Event Logs")
	eventLogs:AddToggle("Hide Icons", false, option("LogHideIcons"))
	eventLogs:AddToggle("Reduce Motion", false, option("LogReduceMotion"))
	eventLogs:AddSlider("Line Opacity", 0, 100, 100, function(v)
		menu:SetHudOption("LogLine", v / 100)
	end, "%")
	eventLogs:AddSlider("Background Opacity", 0, 100, 80, function(v)
		menu:SetHudOption("LogBackground", v / 100)
	end, "%")

	-- Look of all windows
	local windowStyle = windows:AddGroup()
	windowStyle:AddColorPicker({ "Color", "image" }, Color3.fromRGB(235, 235, 240), option("Color"))
	windowStyle:AddSlider({ "Line Opacity", "sliders" }, 0, 100, 45, function(v)
		menu:SetHudOption("LineOpacity", v / 100)
	end, "%")
	-- a background setting for every window (0% = fully transparent, 100% = solid)
	windowStyle:AddSlider({ "Watermark Background", "window" }, 0, 100, 40, function(v)
		menu:SetHudOption("BackgroundWatermark", v / 100)
	end, "%")
	windowStyle:AddSlider({ "Hotkeys Background", "window" }, 0, 100, 40, function(v)
		menu:SetHudOption("BackgroundHotkeys", v / 100)
	end, "%")
	windowStyle:AddSlider({ "Spectators Background", "window" }, 0, 100, 40, function(v)
		menu:SetHudOption("BackgroundSpectators", v / 100)
	end, "%")
	windowStyle:AddSlider({ "Indicators Background", "window" }, 0, 100, 40, function(v)
		Feat.IndicatorOpacity = v / 100
	end, "%")
	windowStyle:AddSlider({ "Panels Background", "window" }, 0, 100, 60, function(v) -- radar, session stats
		Feat.PanelOpacity = v / 100
	end, "%")

	-- Indicators: their "..." settings come later
	local indicators = windows:AddGroup()
	indicators:AddToggle({ "Hit Chance Override", "crosshair" }, false, function(v) Feat.IndHC = v end)
	indicators:AddToggle({ "Min Damage Override", "keyboard" }, false, function(v) Feat.IndMD = v end)
	indicators:AddToggle({ "Double Tap", "chart" }, false, function(v) Feat.IndDT = v end)
	indicators:AddToggle({ "Duck Peek Assist", "user" }, false, function(v) Feat.IndDuck = v end)
	indicators:AddToggle({ "Slowdown", "angle" }, false, function(v) Feat.IndSlow = v end)
	indicators:AddToggle({ "Jump Bug", "wind" }, false, function(v) Feat.IndJump = v end)

	-- one line in Event Logs so the window can be checked right away
	menu:Log("Welcome back, " .. player.Name)

	local removals = miscellaneous:AddNav("Removals")
	removals:AddToggle("Remove Flash", false, function(v) Feat.RemoveFlash = v end)
	removals:AddToggle("Remove Smoke", false, function(v) Feat.RemoveSmoke = v end)
	removals:AddToggle("Remove Fog", false, function(v) Feat.RemoveFog = v end)
	-- Ambience: a page of its own (Map Selection + Effects), opened from this row
	local ambience = world:AddSubPage("Ambience")
	miscellaneous:AddPageLink("Ambience", ambience)
	-- maps the game has; keep the returned api and call :SetMap(name) when the map changes
	ambience:AddMapSelector({ Maps = { "Main Menu" }, OnMap = noop })

	local white = Color3.fromRGB(255, 255, 255)
	local FX = WorldFX.Cfg
	local function unwired(name, reason)
		return function()
			WorldFX.Unwired(name, reason)
		end
	end
	local effects = ambience:AddSection("Effects", "Right")
	effects:AddToggle("Nightmode", false, function(v)
		FX.Night.On = v
	end):AddColor(Color3.fromRGB(150, 145, 170), function(c)
		FX.Night.Color = c
	end)
	effects:AddToggle("Fullbright", false, function(v)
		FX.Fullbright.On = v
	end):AddColor(white, function(c)
		FX.Fullbright.Color = c
	end)

	local exposure = effects:AddToggle("Exposure", false, function(v)
		FX.Exposure.On = v
	end):AddSettings(260, "Exposure")
	exposure:AddDropdown("Adaptation", { "Map", "Custom" }, "Map", function(v)
		FX.Exposure.Adaptation = v
	end)
	exposure:AddSlider("Compensation", -3, 3, 0, function(v)
		FX.Exposure.Compensation = v
	end, nil, { Decimals = 1 })

	effects:AddToggle("Sunlight", false, function(v)
		FX.Sunlight.On = v
	end):AddColor(Color3.fromRGB(220, 220, 228), function(c)
		FX.Sunlight.Color = c
	end)
	effects:AddToggle("Sky", false, function(v)
		FX.Sky.On = v
	end):AddColor(white, function(c)
		FX.Sky.Color = c
	end)
	local fog = effects:AddToggle("Fog", false, function(v)
		FX.Fog.On = v
	end)
	fog:AddColor(Color3.fromRGB(245, 245, 245), function(c)
		FX.Fog.Color = c
	end)
	local fogSettings = fog:AddSettings(250, "Fog")
	fogSettings:AddSlider("Start", 0, 500, 0, function(v)
		FX.Fog.Start = v
	end, "m")
	fogSettings:AddSlider("End", 1, 1000, 120, function(v)
		FX.Fog.End = v
	end, "m")

	local bloom = effects:AddToggle("Bloom", false, function(v)
		FX.Bloom.On = v
	end):AddSettings(280, "Bloom")
	bloom:AddSlider("Strength", 0, 100, 50, function(v)
		FX.Bloom.Strength = v
	end, "%")
	bloom:AddSlider("Screen Strength", 0, 100, 50, unwired("Bloom Screen Strength", "Roblox's bloom has no such parameter"), "%")
	bloom:AddSlider("Blur Strength", 0, 100, 5, function(v)
		FX.Bloom.Blur = v
	end, "%")
	bloom:AddSlider("Threshold", 0, 100, 10, function(v)
		FX.Bloom.Threshold = v
	end, "%")
	bloom:AddSlider("Threshold Width", 0, 100, 10, unwired("Bloom Threshold Width", "Roblox's bloom has no such parameter"), "%")
	local blurWeights = bloom:AddGroup()
	for i = 1, 5 do
		blurWeights:AddSlider("Blur Weight " .. i, 0, 100, 20, unwired("Bloom Blur Weights", "Roblox's bloom has no per-pass weights"), "%"):AddColor(white, noop)
	end

	effects:AddToggle("Vignette", false, function(v)
		FX.Vignette.On = v
	end):AddColor(white, function(c)
		FX.Vignette.Color = c
	end)

	local localContrast = effects:AddToggle("Local Contrast", false, function(v)
		FX.LocalContrast.On = v
	end):AddSettings(270, "Local Contrast")
	localContrast:AddSlider("Strength", 0, 100, 50, function(v)
		FX.LocalContrast.Strength = v
	end, "%")
	localContrast:AddSlider("Edge Strength", 0, 100, 50, unwired("Local Contrast Edge Strength", "Roblox has no edge-contrast effect"), "%")
	localContrast:AddSlider("Vignette Start", 0, 100, 25, function(v)
		FX.LocalContrast.VignetteStart = v
	end, "%")
	localContrast:AddSlider("Vignette End", 0, 100, 80, function(v)
		FX.LocalContrast.VignetteEnd = v
	end, "%")
	localContrast:AddSlider("Vignette Blur", 0, 100, 50, unwired("Vignette Blur", "the vignette softness is fixed"), "%")

	local colorCorrection = effects:AddToggle("Color Correction", false, function(v)
		FX.Correction.On = v
	end):AddSettings(280, "Color Correction")
	colorCorrection:AddDropdown("Tone Curve", { "Linear", "Filmic" }, "Linear", function(v)
		if v ~= "Linear" then
			WorldFX.Unwired("Tone Curve", "Roblox has no tone-curve setting")
		end
	end)
	for _, name in ipairs({ "Contrast", "Highlights", "Shadows", "Saturation", "Vibrance", "Temperature", "Tint" }) do
		colorCorrection:AddSlider(name, -100, 100, 0, function(v)
			FX.Correction[name] = v
		end)
	end
	colorCorrection:AddToggle("Grayscale", false, function(v)
		FX.Correction.Grayscale = v
	end)

	local depthOfField = effects:AddToggle("Depth of Field", false, function(v)
		FX.Dof.On = v
	end):AddSettings(270, "Depth of Field")
	depthOfField:AddDropdown("Mode", { "Manual", "Crosshair" }, "Manual", function(v)
		FX.Dof.Mode = v
	end)
	depthOfField:AddDropdown("Quality", { "Native", "Balanced", "Performance" }, "Balanced", function(v)
		if v ~= "Balanced" then
			WorldFX.Unwired("Depth of Field Quality", "Roblox has no quality setting for it")
		end
	end)
	depthOfField:AddSlider("Focus Distance", 0, 500, 20, function(v)
		FX.Dof.Distance = v
	end, "m")
	depthOfField:AddSlider("Focus Range", 0, 500, 40, function(v)
		FX.Dof.Range = v
	end, "m")

	local weather = effects:AddNav("Weather", 260)
	local wind = weather:AddToggle({ "Wind", "wind" }, false, function(v)
		FX.Wind.On = v
	end):AddSettings(270, "Wind")
	wind:AddSlider({ "Direction", "compass" }, 0, 360, 0, function(v)
		FX.Wind.Direction = v
	end, "°")
	wind:AddSlider({ "Strength", "wind" }, 0, 100, 30, function(v)
		FX.Wind.Strength = v
	end, "%")
	local particles = wind:AddGroup()
	particles:AddSlider({ "Particle Strength", "wind" }, 0, 100, 5, unwired("Wind Particle Strength", "the game's wind particles are not known"), "%")
	particles:AddSlider({ "Particle Turbulence", "waves" }, 0, 100, 20, unwired("Wind Particle Turbulence", "the game's wind particles are not known"), "%")
	particles:AddSlider({ "Maximum Tilt", "angle" }, 0, 90, 25, unwired("Wind Maximum Tilt", "the game's foliage is not known"), "°")
	local wetness = weather:AddToggle({ "Model Wetness", "waves" }, false, function(v)
		if v then
			WorldFX.Unwired("Model Wetness", "needs a wet-surface shader, Roblox has none")
		end
	end):AddSettings(280, "Model Wetness")
	wetness:AddSlider({ "Rain Strength", "drop" }, 0, 100, 50, noop, "%")
	wetness:AddSlider({ "Wetness Coverage", "waves" }, 0, 100, 50, noop, "%")
	wetness:AddSlider({ "Wetness Drying", "wind" }, 0, 100, 0, noop, "%")
	wetness:AddToggle({ "Ignore Sky Exposure", "cloud" }, false, noop)
	local precipitation = weather:AddGroup()
	precipitation:AddToggle({ "Thunder", "bolt" }, false, function(v)
		FX.Thunder.On = v
	end):AddColor(Color3.fromRGB(200, 220, 255), function(c)
		FX.Thunder.Color = c
	end)
	precipitation:AddToggle({ "Rain", "drop" }, false, function(v)
		FX.Rain.On = v
	end):AddColor(Color3.fromRGB(225, 235, 255), function(c)
		FX.Rain.Color = c
	end)
	precipitation:AddToggle({ "Snow", "snow" }, false, function(v)
		FX.Snow.On = v
	end):AddColor(white, function(c)
		FX.Snow.Color = c
	end)

	local ambienceRemovals = effects:AddNav("Removals", 260)
	local UNKNOWN_REMOVALS = {
		["Viewmodel Sunlight"] = "the viewmodel's lights are not measured",
		["Barnlights"] = "the map's lights are not measured",
		["Baked Shadows"] = "the map's baked shadows are not measured",
		["3D Skybox"] = "the game's 3D skybox is not measured",
		["Cable Particles"] = "the game's cable particles are not measured",
	}
	ambienceRemovals:AddSelectList("Removals", {
		"Fog", "Sunlight", "Viewmodel Sunlight", "Barnlights", "Baked Shadows",
		"Dynamic Shadows", "Post Processing", "2D Skybox", "3D Skybox", "Cable Particles",
	}, {}, function(list)
		FX.Removals = list
		for _, name in ipairs(list) do
			if UNKNOWN_REMOVALS[name] then
				WorldFX.Unwired("Removal " .. name, UNKNOWN_REMOVALS[name])
			end
		end
	end)
	local hitMarker = miscellaneous:AddNav("Hit Marker")
	hitMarker:AddToggle("Enabled", false, function(v) Feat.HitMarker = v end):AddColor(Color3.fromRGB(255, 255, 255), function(c) Feat.HitMarkerColor = c end)
	local tracers = miscellaneous:AddNav("Bullet Tracers")
	tracers:AddToggle("Enabled", false, function(v) Feat.Tracers = v end):AddColor(Color3.fromRGB(94, 160, 247), function(c) Feat.TracerColor = c end)
	local impacts = miscellaneous:AddNav("Bullet Impacts")
	impacts:AddToggle({ "Bullet Impacts", "ring" }, false, function(v) Feat.Impacts = v end):AddColor(Color3.fromRGB(255, 94, 200), function(c) Feat.ImpactColor = c end)
	impacts:AddToggle({ "Impact Sparks", "crosshair" }, false, function(v) Feat.Sparks = v end):AddColor(Color3.fromRGB(255, 255, 255), function(c) Feat.SparkColor = c end)
	miscellaneous:AddNav("Damage Numbers"):AddToggle("Enabled", false, function(v) Feat.DamageNumbers = v end):AddColor(Color3.fromRGB(255, 255, 255), function(c) Feat.DamageColor = c end)
	miscellaneous:AddNav("Hitboxes"):AddToggle("Enabled", false, function(v) Feat.Hitboxes = v end):AddColor(Color3.fromRGB(94, 160, 247), function(c) Feat.HitboxColor = c end)
end

------------------------------------------------------------------
-- Skin changer (visual only, on the local viewmodel). MEASURED in the dump:
--  * ReplicatedStorage.Skins.<Weapon>.<Skin> holds every skin on the client;
--  * Modules.GetAndMap.MapSkin(model, skinName, statTrak, ...) paints a weapon model with such a skin and finds the
--    weapon through the model's NAME (WhichIsWhich), the viewmodel is workspace.Camera.Arms and the held weapon's name
--    is character.EquippedTool.Value.
-- NOT measured: how PlayerGui.Client itself calls MapSkin. The viewmodel is renamed to the weapon name only for the
-- duration of the call. Others do not see the skin (the server paints weapons from the real inventory).
------------------------------------------------------------------
local SkinChanger = {}
do
	local Workspace = game:GetService("Workspace")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local STOCK = "Stock"
	local Cfg = { On = false, Weapon = nil, Pending = STOCK, Skins = {} } -- Skins[weapon] = skin name
	SkinChanger.Cfg = Cfg

	local mapSkin
	local function getMapSkin()
		if mapSkin == nil then
			local ok, module = pcall(function()
				local modules = ReplicatedStorage:FindFirstChild("Modules")
				local m = modules and modules:FindFirstChild("GetAndMap")
				return m and require(m)
			end)
			mapSkin = if ok and type(module) == "table" and type(module.MapSkin) == "function" then module.MapSkin else false
		end
		return mapSkin or nil
	end

	local function folderNames(parent)
		local names = {}
		if parent then
			for _, child in ipairs(parent:GetChildren()) do
				if child:IsA("Folder") then
					table.insert(names, child.Name)
				end
			end
		end
		table.sort(names)
		return names
	end

	function SkinChanger.WeaponNames()
		return folderNames(ReplicatedStorage:FindFirstChild("Skins"))
	end

	function SkinChanger.SkinNames(weapon)
		local skins = ReplicatedStorage:FindFirstChild("Skins")
		return folderNames(skins and weapon and skins:FindFirstChild(weapon))
	end

	local KNIFE_WORDS = { "Knife", "Karambit", "Bayonet", "Sickle", "Cleaver", "Axe", "Crowbar", "Banana" }
	local function isKnife(weapon)
		for _, word in ipairs(KNIFE_WORDS) do
			if string.find(weapon, word, 1, true) then
				return true
			end
		end
		return false
	end

	-- knives that can be chosen: those that have skins and a model template in ReplicatedStorage.Weapons
	function SkinChanger.KnifeNames()
		local out = {}
		local weapons = ReplicatedStorage:FindFirstChild("Weapons")
		for _, name in ipairs(SkinChanger.WeaponNames()) do
			if isKnife(name) and weapons and weapons:FindFirstChild(name) then
				table.insert(out, name)
			end
		end
		return out
	end

	local added = setmetatable({}, { __mode = "k" }) -- [Arms] = Texture instances the last MapSkin call added
	local snapshots = setmetatable({}, { __mode = "k" }) -- [Arms] = what the game had painted before the first change

	-- remember the game's own textures of this viewmodel before the first change, so they can be put back when the
	-- weapon in the viewmodel is no longer one with a chosen skin (a reused viewmodel must not keep the old skin)
	local function snapshot(arms)
		if snapshots[arms] then
			return
		end
		local list = {}
		for _, d in ipairs(arms:GetDescendants()) do
			if d:IsA("MeshPart") then
				local appearances = {}
				for _, child in ipairs(d:GetChildren()) do
					if child:IsA("SurfaceAppearance") then
						table.insert(appearances, child:Clone())
					end
				end
				table.insert(list, { Part = d, Texture = d.TextureID, Appearances = appearances })
			elseif d:IsA("SpecialMesh") then
				table.insert(list, { Mesh = d, TextureId = d.TextureId })
			end
		end
		snapshots[arms] = list
	end

	local function restore(arms)
		local list = snapshots[arms]
		if not list then
			return
		end
		snapshots[arms] = nil
		for _, e in ipairs(list) do
			pcall(function()
				if e.Part and e.Part.Parent then
					e.Part.TextureID = e.Texture
					for _, child in ipairs(e.Part:GetChildren()) do
						if child:IsA("SurfaceAppearance") then
							child:Destroy()
						end
					end
					for _, appearance in ipairs(e.Appearances) do
						appearance:Clone().Parent = e.Part
					end
				elseif e.Mesh and e.Mesh.Parent then
					e.Mesh.TextureId = e.TextureId
				end
			end)
		end
		for _, texture in ipairs(added[arms] or {}) do
			texture:Destroy()
		end
		added[arms] = nil
	end

	-- Knife model through the game's own viewmodel templates. MEASURED in the dump: ReplicatedStorage.Viewmodels holds a
	-- complete viewmodel (rig, joints, its own animations, VOffset) per knife: v_T Knife, v_CT Knife, v_Karambit,
	-- v_Butterfly Knife, ... The rigs and animations differ between knives (the Butterfly has Joint / ControllerHandle /
	-- Butterfly_LHandle ..., the T Knife has KnifeGrip / Handle), so a mesh swap inside another knife's rig cannot animate.
	-- Instead the templates of the default knives are replaced by a copy of the chosen knife's template: the next time the
	-- knife is taken in the hands, the game itself builds, scales, positions and animates the chosen knife. The originals
	-- are put back when the changer is off, the knife is "Default" or the script is unloaded.
	-- NOT verified: that the game clones Viewmodels["v_" .. EquippedTool.Value] when a knife is equipped; a knife that is
	-- already in your hands changes after you switch to another weapon and back.
	local viewmodels = ReplicatedStorage:FindFirstChild("Viewmodels")
	local DEFAULT_KNIVES = { "T Knife", "CT Knife" }
	local originals, installed = {}, nil

	local function restoreKnifeTemplates()
		if viewmodels then
			for name, original in pairs(originals) do
				local current = viewmodels:FindFirstChild("v_" .. name)
				if current and current ~= original then
					current:Destroy()
				end
				original.Parent = viewmodels
			end
		end
		originals, installed = {}, nil
	end

	local function syncKnifeTemplates()
		local want = if Cfg.On and Cfg.Knife then Cfg.Knife else nil
		if want == installed then
			return
		end
		restoreKnifeTemplates()
		if not want or not viewmodels then
			return
		end
		local source = viewmodels:FindFirstChild("v_" .. want)
		if not source then
			warn("[SkinChanger] no viewmodel template v_" .. want)
			return
		end
		for _, name in ipairs(DEFAULT_KNIVES) do
			local existing = viewmodels:FindFirstChild("v_" .. name)
			if existing then
				originals[name] = existing
				existing.Parent = nil
				local copy = source:Clone()
				copy.Name = "v_" .. name
				copy.Parent = viewmodels
			end
		end
		installed = want
	end
	SkinChanger.SyncKnife = syncKnifeTemplates

	-- a knife's skin: every StringValue of the skin folder names a part of the knife's template and holds its texture
	local function paintKnife(arms, skinFolder)
		for _, d in ipairs(skinFolder:GetDescendants()) do
			if d:IsA("StringValue") and d.Name ~= "meshtype" and d.Name ~= "Quality" and not d:FindFirstAncestor("WorldModel") then
				local part = arms:FindFirstChild(d.Name)
				if part and part:IsA("MeshPart") then
					part.TextureID = d.Value
					local appearance = d:FindFirstChildOfClass("SurfaceAppearance")
					if appearance then
						for _, child in ipairs(part:GetChildren()) do
							if child:IsA("SurfaceAppearance") then
								child:Destroy()
							end
						end
						appearance:Clone().Parent = part
					end
				end
			end
		end
	end

	-- Gloves. MEASURED in Modules.GetAndMap: EffectiveGloveItemId(loadout, team) returns the glove item of the local
	-- loadout as "<Glove>_<Skin>" (e.g. "Sports Glove_Reinforced Aquamarine", default "TGlove_Stock"); WhichGlove splits it at
	-- "_" and looks in ReplicatedStorage.Gloves (<Glove> = a folder of skins, also present in Gloves.Models).
	-- The function is replaced by one that returns the chosen item while the changer is on. NOT verified: that the game's
	-- viewmodel code calls it through the module table (a cached local copy would not see the change); the first call is
	-- reported in Event Logs. The new gloves appear the next time the viewmodel is built (switch weapons).
	local logLine
	function SkinChanger.SetLog(fn)
		logLine = fn
	end
	local gloveTable, gloveOriginal, gloveReported = nil, nil, false
	local function installGloveHook()
		if gloveTable then
			return true
		end
		local ok, module = pcall(function()
			local modules = ReplicatedStorage:FindFirstChild("Modules")
			local m = modules and modules:FindFirstChild("GetAndMap")
			return m and require(m)
		end)
		if not (ok and type(module) == "table" and type(module.EffectiveGloveItemId) == "function") then
			return false
		end
		gloveTable, gloveOriginal = module, module.EffectiveGloveItemId
		module.EffectiveGloveItemId = function(loadout, team)
			if Cfg.On and Cfg.Glove then
				if not gloveReported then
					gloveReported = true
					if logLine then
						logLine("Gloves: the game asked for the glove item (team " .. tostring(team) .. ")")
					end
				end
				return Cfg.Glove
			end
			return gloveOriginal(loadout, team)
		end
		return true
	end
	local function removeGloveHook()
		if gloveTable then
			gloveTable.EffectiveGloveItemId = gloveOriginal
			gloveTable, gloveOriginal = nil, nil
		end
	end

	-- The glove item of every player is also a Player attribute: GloveItemT / GloveItemCT (MEASURED in the first probe:
	-- "TGlove_Stock", "CTGlove_Stock", "Sports Glove_Reinforced Aquamarine"). EffectiveGloveItemId takes the loadout table,
	-- i.e. it is what the server evaluates, so the client most likely builds gloves from these attributes. They are set
	-- on the LOCAL player only (a client-side change, nothing is sent), written again if the server overwrites them, and
	-- the original values are put back when the changer is off. NOT verified: that the viewmodel reads these attributes.
	local GLOVE_ATTRIBUTES = { "GloveItemT", "GloveItemCT" }
	local gloveOriginals = {} -- [attribute] = the value before the changer wrote it (false = it had none)
	local function applyGloveAttributes()
		for _, attribute in ipairs(GLOVE_ATTRIBUTES) do
			if Cfg.On and Cfg.Glove then
				if gloveOriginals[attribute] == nil then
					local original = player:GetAttribute(attribute)
					gloveOriginals[attribute] = if original == nil then false else original
				end
				if player:GetAttribute(attribute) ~= Cfg.Glove then
					player:SetAttribute(attribute, Cfg.Glove)
					if logLine and not gloveReported then
						gloveReported = true
						logLine("Gloves: " .. attribute .. " set to " .. Cfg.Glove .. " (take another weapon and back)")
					end
				end
			elseif gloveOriginals[attribute] ~= nil then
				local original = gloveOriginals[attribute]
				gloveOriginals[attribute] = nil
				player:SetAttribute(attribute, if original == false then nil else original)
			end
		end
	end
	for _, attribute in ipairs(GLOVE_ATTRIBUTES) do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			if Cfg.On and Cfg.Glove then
				local current = player:GetAttribute(attribute)
				if current ~= Cfg.Glove then
					-- the server wrote a new value: keep it as the one to restore, show ours
					gloveOriginals[attribute] = if current == nil then false else current
					player:SetAttribute(attribute, Cfg.Glove)
				end
			end
		end)
	end

	-- Gloves drawn on the viewmodel by the changer itself. MEASURED in the Arms probe: Arms contains a sub-model named like
	-- the appearance ("PTArms"); its "Right Arm" / "Left Arm" parts carry a "Glove" Part (a SpecialMesh, here fully
	-- transparent = no gloves) with a Motor6D to the arm, and the whole viewmodel is scaled by Arms:GetScale() = 0.25.
	-- MEASURED in ReplicatedStorage.Gloves: Models.<glove>.RGlove / LGlove are Parts with a SpecialMesh "Mesh" (the glove
	-- mesh) and Gloves.<glove>.<skin> holds a SpecialMesh "Textures" (the skin's TextureId).
	-- The "Glove" part gets the glove's mesh (scaled like the viewmodel), the skin texture and is made visible; a MeshPart
	-- glove (appearances with default gloves, seen in the first dump) is hidden and replaced by a copy of the template on
	-- the same joint. The original look is put back when the choice is removed. NOT verified in the game.
	local gloveBackups = setmetatable({}, { __mode = "k" }) -- [Arms] = { list of what was changed }
	local gloveApplied = setmetatable({}, { __mode = "k" }) -- [Arms] = "<glove>_<skin>" already applied

	local function restoreGloves(arms)
		local list = gloveBackups[arms]
		if not list then
			return
		end
		gloveBackups[arms], gloveApplied[arms] = nil, nil
		for _, e in ipairs(list) do
			pcall(function()
				if e.Created then
					e.Created:Destroy()
				end
				if e.Glove and e.Glove.Parent then
					e.Glove.Transparency = e.Transparency
					if e.Mesh and e.Mesh.Parent then
						e.Mesh.MeshId, e.Mesh.Scale, e.Mesh.Offset = e.MeshId, e.Scale, e.Offset
						e.Mesh.TextureId, e.Mesh.VertexColor = e.TextureId, e.VertexColor
					end
				end
			end)
		end
	end

	local function applyGloves(arms)
		local name, skin = Cfg.GloveName, Cfg.GloveSkin or "Stock"
		if not (Cfg.On and name) then
			restoreGloves(arms)
			return
		end
		local key = name .. "_" .. skin
		if gloveApplied[arms] == key then
			return
		end
		local gloves = ReplicatedStorage:FindFirstChild("Gloves")
		local models = gloves and gloves:FindFirstChild("Models")
		local template = models and models:FindFirstChild(name)
		if not template then
			return
		end
		local skinFolder = gloves:FindFirstChild(name) and gloves[name]:FindFirstChild(skin)
		local texture = skinFolder and skinFolder:FindFirstChildOfClass("SpecialMesh")
		local sub
		for _, child in ipairs(arms:GetChildren()) do
			if child:IsA("Model") and string.find(child.Name, "Arms$") then
				sub = child
				break
			end
		end
		if not sub then
			return
		end
		restoreGloves(arms) -- an earlier choice on this viewmodel goes first
		local ok, scale = pcall(function()
			return arms:GetScale()
		end)
		local factor = if ok and type(scale) == "number" and scale > 0 then scale else 1
		local list = {}
		for _, side in ipairs({ { "Right Arm", "RGlove" }, { "Left Arm", "LGlove" } }) do
			local arm = sub:FindFirstChild(side[1])
			local glove = arm and arm:FindFirstChild("Glove")
			local source = template:FindFirstChild(side[2])
			local sourceMesh = source and source:FindFirstChildOfClass("SpecialMesh")
			if arm and glove and glove:IsA("BasePart") and source and sourceMesh then
				local mesh = glove:FindFirstChildOfClass("SpecialMesh")
				if mesh then
					table.insert(list, {
						Glove = glove, Mesh = mesh, Transparency = glove.Transparency,
						MeshId = mesh.MeshId, Scale = mesh.Scale, Offset = mesh.Offset,
						TextureId = mesh.TextureId, VertexColor = mesh.VertexColor,
					})
					mesh.MeshId = sourceMesh.MeshId
					mesh.Scale = sourceMesh.Scale * factor
					mesh.Offset = sourceMesh.Offset * factor
					mesh.VertexColor = sourceMesh.VertexColor
					mesh.TextureId = if texture and texture.TextureId ~= "" then texture.TextureId else sourceMesh.TextureId
					glove.Transparency = 0
				else
					-- a MeshPart glove: hide it and put a copy of the template glove on the same joint
					local joint
					for _, d in ipairs(sub:GetDescendants()) do
						if d:IsA("JointInstance") and d.Part1 == glove then
							joint = d
							break
						end
					end
					local copy = source:Clone()
					for _, child in ipairs(copy:GetChildren()) do
						if child:IsA("JointInstance") then
							child:Destroy()
						end
					end
					copy.Name = "NLGlove"
					copy.Size = source.Size * factor
					copy.Transparency = 0
					copy.Anchored, copy.CanCollide, copy.Massless = false, false, true
					local copyMesh = copy:FindFirstChildOfClass("SpecialMesh")
					if copyMesh then
						copyMesh.Scale = copyMesh.Scale * factor
						copyMesh.Offset = copyMesh.Offset * factor
						if texture and texture.TextureId ~= "" then
							copyMesh.TextureId = texture.TextureId
						end
					end
					copy.CFrame = glove.CFrame
					copy.Parent = glove.Parent
					if joint then
						local motor = Instance.new("Motor6D")
						motor.Part0, motor.Part1, motor.C0, motor.C1 = joint.Part0, copy, joint.C0, CFrame.new()
						motor.Parent = joint.Part0
					end
					table.insert(list, { Glove = glove, Transparency = glove.Transparency, Created = copy })
					glove.Transparency = 1
				end
			end
		end
		if #list > 0 then
			gloveBackups[arms], gloveApplied[arms] = list, key
		end
	end

	function SkinChanger.GloveNames()
		local gloves = ReplicatedStorage:FindFirstChild("Gloves")
		local models = gloves and gloves:FindFirstChild("Models")
		local out = {}
		if gloves and models then
			for _, child in ipairs(gloves:GetChildren()) do
				if child:IsA("Folder") and child ~= models and models:FindFirstChild(child.Name) then
					table.insert(out, child.Name)
				end
			end
		end
		table.sort(out)
		return out
	end

	function SkinChanger.GloveSkinNames(glove)
		local gloves = ReplicatedStorage:FindFirstChild("Gloves")
		return folderNames(gloves and glove and gloves:FindFirstChild(glove))
	end

	function SkinChanger.SetGlove(name, skin)
		Cfg.GloveName, Cfg.GloveSkin = name, skin
		Cfg.Glove = if name then name .. "_" .. (skin or "Stock") else nil
		if Cfg.Glove then
			installGloveHook()
		end
	end

	-- plain texture assignment from a skin folder (what MapSkin does for texture skins); used for a knife's Stock look,
	-- which MapSkin itself leaves untouched
	local function paintFolder(arms, folder)
		for _, d in ipairs(folder:GetDescendants()) do
			if d:IsA("StringValue") and d.Name ~= "meshtype" and d.Name ~= "Quality" then
				local part = arms:FindFirstChild(d.Name)
				if part and part:IsA("MeshPart") and part.Transparency == 0 then
					part.TextureID = d.Value
				end
			end
		end
	end

	local function apply()
		syncKnifeTemplates() -- keeps the knife viewmodel templates in line with the menu (also when it is switched off)
		local cam = Workspace.CurrentCamera
		local arms = cam and cam:FindFirstChild("Arms")
		if not (arms and arms:IsA("Model")) then
			return
		end
		applyGloves(arms)
		local character = player.Character
		local equipped = character and character:FindFirstChild("EquippedTool")
		local weapon = equipped and equipped:IsA("StringValue") and equipped.Value
		if type(weapon) ~= "string" or weapon == "" then
			return
		end
		local key, skin, knifeSwap = weapon, Cfg.Skins[weapon], false
		if isKnife(weapon) and Cfg.Knife then
			key, skin, knifeSwap = Cfg.Knife, Cfg.Skins[Cfg.Knife] or STOCK, true
		end
		if not Cfg.On or ((not skin or skin == STOCK) and not knifeSwap) then
			restore(arms)
			return
		end
		local skins = ReplicatedStorage:FindFirstChild("Skins")
		local folder = skins and skins:FindFirstChild(key)
		local skinFolder = folder and folder:FindFirstChild(skin)
		if not skinFolder then
			restore(arms)
			return
		end
		snapshot(arms)
		-- texture skins add Texture instances on every call: remove the ones added by the previous call first
		for _, texture in ipairs(added[arms] or {}) do
			texture:Destroy()
		end
		if knifeSwap then
			-- paint only a viewmodel the game has built from the chosen template (same mesh in its first MeshPart)
			local template = viewmodels and viewmodels:FindFirstChild("v_" .. key)
			local probe = template and template:FindFirstChildWhichIsA("MeshPart")
			local inHands = probe and arms:FindFirstChild(probe.Name)
			if not (inHands and inHands:IsA("MeshPart") and inHands.MeshId == probe.MeshId) then
				return
			end
			paintKnife(arms, skinFolder)
			return
		end
		if skin == STOCK then
			paintFolder(arms, skinFolder)
			return
		end
		local map = getMapSkin()
		if not map then
			return
		end
		local before = {}
		for _, d in ipairs(arms:GetDescendants()) do
			if d:IsA("Texture") then
				before[d] = true
			end
		end
		-- MapSkin finds the weapon through the model's name: the viewmodel is renamed for the duration of the call
		local oldName = arms.Name
		arms.Name = key
		local ok, err = pcall(map, arms, skin, nil, nil)
		arms.Name = oldName
		local fresh = {}
		for _, d in ipairs(arms:GetDescendants()) do
			if d:IsA("Texture") and not before[d] then
				table.insert(fresh, d)
			end
		end
		added[arms] = fresh
		if not ok then
			warn("[SkinChanger] " .. tostring(err))
		end
	end

	-- The game paints the weapon itself shortly after a switch, so apply a few times. A newer change cancels the
	-- pending applies of older ones (generation counter): after fast switching nothing stale runs on the new weapon.
	local generation = 0
	local function schedule()
		generation += 1
		local mine = generation
		for _, delay in ipairs({ 0.15, 0.6, 1.5 }) do
			task.delay(delay, function()
				if generation == mine then
					apply()
				end
			end)
		end
	end

	function SkinChanger.Apply()
		if Cfg.On and Cfg.Glove then
			installGloveHook()
		end
		applyGloveAttributes()
		apply()
		schedule()
		if SkinChanger.OnChange then
			SkinChanger.OnChange()
		end
	end

	function SkinChanger.SetWeapon(weapon, skinOptions, skinDropdown)
		Cfg.Weapon = weapon
		table.clear(skinOptions)
		table.insert(skinOptions, STOCK)
		for _, name in ipairs(SkinChanger.SkinNames(weapon)) do
			table.insert(skinOptions, name)
		end
		if table.find(skinOptions, Cfg.Pending) then
			Cfg.Skins[weapon] = Cfg.Pending
		elseif skinDropdown then
			skinDropdown:Set(STOCK)
		end
		SkinChanger.Apply()
	end

	function SkinChanger.SetSkin(skin, skinOptions)
		Cfg.Pending = skin
		if Cfg.Weapon and table.find(skinOptions, skin) then
			Cfg.Skins[Cfg.Weapon] = skin
			SkinChanger.Apply()
		end
	end

	-- re-apply when the viewmodel is rebuilt or the equipped weapon changes
	local function hookEquipped(character)
		local equipped = character:WaitForChild("EquippedTool", 10)
		if equipped and equipped:IsA("StringValue") then
			equipped.Changed:Connect(schedule)
			schedule()
		end
	end
	local function hookCamera(cam)
		cam.ChildAdded:Connect(function(child)
			if child.Name == "Arms" then
				schedule()
			end
		end)
	end
	if Workspace.CurrentCamera then
		hookCamera(Workspace.CurrentCamera)
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		if Workspace.CurrentCamera then
			hookCamera(Workspace.CurrentCamera)
		end
	end)
	if player.Character then
		task.spawn(hookEquipped, player.Character)
	end
	player.CharacterAdded:Connect(hookEquipped)

	table.insert(Unloaders, function()
		Cfg.On = false
		syncKnifeTemplates() -- puts the game's own knife viewmodels back
		removeGloveHook()
		applyGloveAttributes() -- with Cfg.On false this restores the attributes
	end)
end

------------------------------------------------------------------
-- Inventory > loadout screen: T / CT switch, your character, weapon tiles in three columns (Pistols, Mid-Tier,
-- Rifles); click a tile to pick its skin. Tile icons are drawn by the game's own Modules.WeaponImages.render (MEASURED:
-- render(ImageLabel, weaponName, { skin = skinName })), so a tile shows the chosen skin.
-- Category of each weapon: MEASURED (the game's Images list: Pistol / SMG / Rifle / Heavy; Mid-Tier = SMG + Heavy).
-- Which team may use a weapon is NOT measured: the sets below follow Counter-Strike conventions and your screenshots.
-- Knife and glove slots are drawn dimmed: that changer does not exist yet.
------------------------------------------------------------------
do
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Cfg = SkinChanger.Cfg
	SkinChanger.SetLog(function(text)
		menu:Log(text)
	end)

	local CATEGORIES = {
		{ "Pistols", { "CZ", "DesertEagle", "DualBerettas", "FiveSeven", "Glock", "P2000", "P250", "R8", "Tec9", "USP" } },
		{ "Mid-Tier", { "Bizon", "MAC10", "MP7", "MP7-SD", "MP9", "P90", "UMP", "M249", "MAG7", "Negev", "Nova", "SawedOff", "XM" } },
		{ "Rifles", { "AK47", "AUG", "AWP", "Famas", "G3SG1", "Galil", "M4A1", "M4A4", "SG", "Scar", "Scout" } },
	}
	-- the folder in ReplicatedStorage.Weapons may be spelled differently from the image list: first existing one is used
	local ALIASES = { SG = { "SG", "SG553", "SG533" }, Scar = { "Scar", "SCAR-20", "SCAR" }, XM = { "XM", "XM1014" } }
	local T_ONLY = { Glock = true, Tec9 = true, AK47 = true, Galil = true, SG = true, MAC10 = true, SawedOff = true, G3SG1 = true }
	local CT_ONLY = {
		USP = true, P2000 = true, FiveSeven = true, M4A4 = true, M4A1 = true, AUG = true, Famas = true,
		MP9 = true, MP7 = true, ["MP7-SD"] = true, MAG7 = true, Scar = true,
	}

	local weaponsFolder = ReplicatedStorage:FindFirstChild("Weapons")
	local function resolve(name)
		for _, candidate in ipairs(ALIASES[name] or { name }) do
			if weaponsFolder and weaponsFolder:FindFirstChild(candidate) then
				return candidate
			end
		end
		return nil
	end

	local weaponImages
	local function renderer()
		if weaponImages == nil then
			local ok, module = pcall(function()
				local modules = ReplicatedStorage:FindFirstChild("Modules")
				local m = modules and modules:FindFirstChild("WeaponImages")
				return m and require(m)
			end)
			weaponImages = if ok and type(module) == "table" and type(module.render) == "function" then module else false
		end
		return weaponImages or nil
	end

	------------------------------------------------------------------
	-- Skin picker with photos. MEASURED: ReplicatedStorage.Images.<Weapon>.<Skin> is a StringValue holding the skin's
	-- photo (an asset URL), with child StringValues "Quality" (Blue / Purple / Pink / Red / Knife / ...) and, for knives,
	-- "DisplayName". The list of skins that can be applied still comes from ReplicatedStorage.Skins.
	-- The quality colours below are my choice (not from the game).
	------------------------------------------------------------------
	local QUALITY_COLORS = {
		Blue = Color3.fromRGB(75, 105, 255), Purple = Color3.fromRGB(136, 71, 255), Pink = Color3.fromRGB(211, 44, 230),
		Red = Color3.fromRGB(235, 75, 75), Knife = Color3.fromRGB(228, 174, 57), Contraband = Color3.fromRGB(255, 140, 60),
		Retired = Color3.fromRGB(160, 160, 170), Finite = Color3.fromRGB(120, 220, 255), Limited = Color3.fromRGB(120, 255, 160),
	}

	local function imagesFor(weapon)
		local images = ReplicatedStorage:FindFirstChild("Images")
		if not images then
			return nil
		end
		local entry = images:FindFirstChild(weapon)
		if entry then
			return entry
		end
		for canonical, variants in pairs(ALIASES) do
			if table.find(variants, weapon) then
				local other = images:FindFirstChild(canonical)
				if other then
					return other
				end
			end
		end
		return nil
	end

	-- The picture of a skin and whether it is only a stand-in. Order: the skin's photo in Images; many skins have the
	-- link "rbxassetid://0" there (no photo exists), then the skin's own texture from ReplicatedStorage.Skins (the colours
	-- of the skin, not a picture of the weapon); last the weapon's Stock photo.
	local function validImage(value)
		return type(value) == "string" and value ~= "" and value ~= "rbxassetid://0" and not string.find(value, "id=0$")
	end

	local function skinImage(weapon, skin)
		skin = skin or "Stock"
		local entries = imagesFor(weapon)
		local entry = entries and entries:FindFirstChild(skin)
		if entry and entry:IsA("StringValue") and validImage(entry.Value) then
			return entry.Value, false
		end
		local skins = ReplicatedStorage:FindFirstChild("Skins")
		local folder = skins and skins:FindFirstChild(weapon)
		local skinFolder = folder and folder:FindFirstChild(skin)
		if skinFolder then
			for _, d in ipairs(skinFolder:GetDescendants()) do
				if d:IsA("StringValue") and d.Name ~= "meshtype" and d.Name ~= "Quality" and validImage(d.Value) and not d:FindFirstAncestor("WorldModel") then
					return d.Value, true
				end
				if d:IsA("SurfaceAppearance") and validImage(d.ColorMap) then
					return d.ColorMap, true
				end
			end
		end
		local stock = entries and entries:FindFirstChild("Stock")
		if stock and stock:IsA("StringValue") and validImage(stock.Value) then
			return stock.Value, true
		end
		return "", true
	end

	-- skinNames: optional list (gloves take theirs from ReplicatedStorage.Gloves); default = ReplicatedStorage.Skins
	local function openSkinPicker(anchor, weapon, current, onPick, skinNames)
		local names, seen = { "Stock" }, { Stock = true }
		for _, name in ipairs(skinNames or SkinChanger.SkinNames(weapon)) do
			if not seen[name] then
				seen[name] = true
				table.insert(names, name)
			end
		end
		if #names == 1 then
			menu:Log(weapon .. ": no skins in ReplicatedStorage.Skins")
			return
		end
		local entries = imagesFor(weapon)
		local popup = popupFrame(396, Theme.PopupBg)
		textLabel({
			Text = weapon .. " skins",
			Size = UDim2.new(1, 0, 0, 24),
			FontFace = Theme.FontBold,
			TextSize = 14,
			TextColor3 = Theme.Text,
			LayoutOrder = 0,
			Parent = popup,
		}, { padding(0, 0, 0, 6) })
		local scroll = create("ScrollingFrame", {
			Size = UDim2.new(1, 0, 0, 320),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Theme.Stroke,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			LayoutOrder = 1,
			Parent = popup,
		}, {
			create("UIGridLayout", {
				CellSize = UDim2.fromOffset(118, 92),
				CellPadding = UDim2.fromOffset(6, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			padding(2, 2, 2, 2),
		})
		for i, name in ipairs(names) do
			local entry = entries and entries:FindFirstChild(name)
			local url, standIn = skinImage(weapon, name)
			local qualityValue = entry and entry:FindFirstChild("Quality")
			local quality = if qualityValue and qualityValue:IsA("StringValue") then qualityValue.Value else nil
			local displayValue = entry and entry:FindFirstChild("DisplayName")
			local display = if displayValue and displayValue:IsA("StringValue") then (string.match(displayValue.Value, "|%s*(.+)$") or displayValue.Value) else name
			local tile = create("TextButton", {
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = Theme.PopupCard,
				LayoutOrder = i,
				Parent = scroll,
			}, { corner(8), stroke(if name == current then Theme.Accent else Theme.PopupCardStroke) })
			create("ImageLabel", {
				Position = UDim2.fromOffset(4, 4),
				Size = UDim2.new(1, -8, 1, -30),
				BackgroundTransparency = 1,
				Image = url,
				ImageTransparency = if standIn then 0.35 else 0,
				ScaleType = Enum.ScaleType.Fit,
				Parent = tile,
			})
			textLabel({
				Text = display,
				Position = UDim2.new(0, 4, 1, -22),
				Size = UDim2.new(1, -8, 0, 14),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextSize = 11,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = if name == current then Theme.Text else Theme.TabText,
				Parent = tile,
			})
			create("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -4),
				Size = UDim2.new(1, -16, 0, 2),
				BackgroundColor3 = QUALITY_COLORS[quality] or Theme.Stroke,
				BorderSizePixel = 0,
				Parent = tile,
			})
			tile.MouseEnter:Connect(function()
				tween(tile, { BackgroundColor3 = Theme.Hover })
			end)
			tile.MouseLeave:Connect(function()
				tween(tile, { BackgroundColor3 = Theme.PopupCard })
			end)
			tile.MouseButton1Click:Connect(function()
				onPick(name)
				menu:ClosePopup()
			end)
		end
		menu:ShowPopup(anchor, popup, false)
	end

	local page = inventory.Right
	inventory.Expanded = true
	inventory.Left.Visible = false
	inventory._layoutColumns()

	local HEIGHT = 470
	local root = create("Frame", {
		Size = UDim2.new(1, 0, 0, HEIGHT),
		BackgroundTransparency = 1,
		Parent = page,
	})

	------------------------------------------------------------------
	-- Left: team switch, character, slots
	------------------------------------------------------------------
	local team = "T"
	local statusTeam = player:FindFirstChild("Status") and player.Status:FindFirstChild("Team")
	if statusTeam and statusTeam:IsA("StringValue") and statusTeam.Value == "CT" then
		team = "CT"
	end

	local left = create("Frame", { Size = UDim2.new(0, 170, 1, 0), BackgroundTransparency = 1, Parent = root })
	local teamButtons = {}
	local function teamButton(name, x)
		local b = create("TextButton", {
			Text = name .. " Loadout",
			FontFace = Theme.FontBold,
			TextSize = 13,
			TextColor3 = Theme.TabText,
			AutoButtonColor = false,
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.fromOffset(82, 28),
			BackgroundColor3 = Theme.Element,
			Parent = left,
		}, { corner(6), stroke(Theme.ElementStroke) })
		teamButtons[name] = b
		return b
	end
	teamButton("T", 0)
	teamButton("CT", 86)

	local stage = create("Frame", {
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 1, -112),
		BackgroundColor3 = Theme.Section,
		Parent = left,
	}, { corner(8), stroke(Theme.SectionStroke) })
	local viewport = create("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 170, 180),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(0.4, -1, 0.6),
		Parent = stage,
	})
	local camera = create("Camera", { FieldOfView = 30, Parent = viewport })
	viewport.CurrentCamera = camera
	local worldModel = create("WorldModel", { Parent = viewport })
	local status = textLabel({
		Text = "Loading character...",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 13,
		TextColor3 = Theme.SubText,
		Parent = stage,
	})

	local previewModel
	local function buildPreview()
		if previewModel then
			previewModel:Destroy()
			previewModel = nil
		end
		local character = player.Character
		if not character then
			status.Text, status.Visible = "No character", true
			return
		end
		local archivable = character.Archivable
		character.Archivable = true
		local ok, clone = pcall(function()
			return character:Clone()
		end)
		character.Archivable = archivable
		if not ok or not clone then
			status.Text, status.Visible = "No character", true
			return
		end
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("ForceField") or d.Name == "StandHitbox" then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		local humanoid = clone:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		clone:PivotTo(CFrame.new(clone:GetPivot().Position))
		-- bounds of the VISIBLE parts only: invisible helper parts of the character (hitboxes, grips) would make it tiny
		local low, high = Vector3.one * math.huge, Vector3.one * -math.huge
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency < 0.95 then
				local half = d.Size / 2
				for _, sx in ipairs({ -1, 1 }) do
					for _, sy in ipairs({ -1, 1 }) do
						for _, sz in ipairs({ -1, 1 }) do
							local corner = (d.CFrame * CFrame.new(half.X * sx, half.Y * sy, half.Z * sz)).Position
							low = Vector3.new(math.min(low.X, corner.X), math.min(low.Y, corner.Y), math.min(low.Z, corner.Z))
							high = Vector3.new(math.max(high.X, corner.X), math.max(high.Y, corner.Y), math.max(high.Z, corner.Z))
						end
					end
				end
			end
		end
		if low.X == math.huge then
			status.Text, status.Visible = "No character", true
			clone:Destroy()
			return
		end
		local size = high - low
		clone:TranslateBy(-(low + high) / 2)
		clone.Parent = worldModel
		previewModel = clone
		local distance = (size.Y / 2) / math.tan(math.rad(camera.FieldOfView / 2)) * 1.1 + size.Z
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, -distance), Vector3.zero)
		status.Visible = false
	end
	task.defer(buildPreview)
	player.CharacterAdded:Connect(function()
		task.wait(1)
		buildPreview()
	end)

	-- Knife slot: click to pick a knife model (the knife in your hands is replaced), then its skin.
	local knifeSlot = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Position = UDim2.new(0, 0, 1, -68),
		Size = UDim2.fromOffset(82, 60),
		BackgroundColor3 = Theme.Section,
		Parent = left,
	}, { corner(8), stroke(Theme.SectionStroke) })
	local knifeImage = create("ImageLabel", {
		Size = UDim2.new(1, -8, 1, -18),
		Position = UDim2.fromOffset(4, 2),
		BackgroundTransparency = 1,
		Image = "",
		Parent = knifeSlot,
	})
	local knifeLabel = textLabel({
		Text = "Knife",
		Position = UDim2.new(0, 0, 1, -16),
		Size = UDim2.new(1, 0, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 11,
		TextColor3 = Theme.SubText,
		Parent = knifeSlot,
	})
	local function drawKnife()
		local name = Cfg.Knife
		knifeLabel.Text = name or "Knife"
		knifeLabel.TextColor3 = if name then Theme.Accent else Theme.SubText
		knifeImage.Image = ""
		local old = knifeImage:FindFirstChild("_RENDER")
		if old then
			old:Destroy()
		end
		knifeImage.ImageTransparency = 0
		if name then
			local photo, standIn = skinImage(name, Cfg.Skins[name])
			knifeImage.Image = photo
			knifeImage.ImageTransparency = if standIn then 0.35 else 0
		end
	end
	local function pickKnifeSkin(name)
		openSkinPicker(knifeSlot, name, Cfg.Skins[name] or "Stock", function(option)
			Cfg.Skins[name] = option
			drawKnife()
			SkinChanger.Apply()
		end)
	end
	knifeSlot.MouseButton1Click:Connect(function()
		local options = { "Default" }
		for _, name in ipairs(SkinChanger.KnifeNames()) do
			table.insert(options, name)
		end
		if #options == 1 then
			menu:Log("Knife: no knife models found in ReplicatedStorage.Weapons / Skins")
			return
		end
		menu:_openSelect(knifeSlot, options, function(option)
			return option == (Cfg.Knife or "Default")
		end, function(option)
			Cfg.Knife = if option == "Default" then nil else option
			drawKnife()
			SkinChanger.Apply()
			if Cfg.Knife then
				task.delay(0.2, pickKnifeSkin, Cfg.Knife)
			end
		end, false)
	end)
	-- Glove slot: click to pick a glove, then its skin. They apply the next time the viewmodel is built.
	local gloveSlot = create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Position = UDim2.new(0, 86, 1, -68),
		Size = UDim2.fromOffset(82, 60),
		BackgroundColor3 = Theme.Section,
		Parent = left,
	}, { corner(8), stroke(Theme.SectionStroke) })
	local gloveImage = create("ImageLabel", {
		Size = UDim2.new(1, -8, 1, -18),
		Position = UDim2.fromOffset(4, 2),
		BackgroundTransparency = 1,
		Image = "",
		Parent = gloveSlot,
	})
	local gloveLabel = textLabel({
		Text = "Gloves",
		Position = UDim2.new(0, 0, 1, -16),
		Size = UDim2.new(1, 0, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 11,
		TextColor3 = Theme.SubText,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = gloveSlot,
	})
	local function drawGlove()
		local name = Cfg.GloveName
		gloveLabel.Text = name or "Gloves"
		gloveLabel.TextColor3 = if name then Theme.Accent else Theme.SubText
		gloveImage.Image = ""
		gloveImage.ImageTransparency = 0
		if name then
			local entries = imagesFor(name)
			local photo = entries and entries:FindFirstChild(Cfg.GloveSkin or "Stock")
			local stock = entries and entries:FindFirstChild("Stock")
			local value = if photo and photo:IsA("StringValue") and validImage(photo.Value) then photo.Value
				elseif stock and stock:IsA("StringValue") and validImage(stock.Value) then stock.Value
				else ""
			gloveImage.Image = value
			gloveImage.ImageTransparency = if photo and photo:IsA("StringValue") and validImage(photo.Value) then 0 else 0.35
		end
	end
	local function pickGloveSkin(name)
		openSkinPicker(gloveSlot, name, Cfg.GloveSkin or "Stock", function(option)
			SkinChanger.SetGlove(name, option)
			drawGlove()
			SkinChanger.Apply()
			menu:Log("Gloves: " .. name .. "_" .. option .. " (take another weapon and back to see them)")
		end, SkinChanger.GloveSkinNames(name))
	end
	gloveSlot.MouseButton1Click:Connect(function()
		local options = { "Default" }
		for _, name in ipairs(SkinChanger.GloveNames()) do
			table.insert(options, name)
		end
		if #options == 1 then
			menu:Log("Gloves: no glove models found in ReplicatedStorage.Gloves")
			return
		end
		menu:_openSelect(gloveSlot, options, function(option)
			return option == (Cfg.GloveName or "Default")
		end, function(option)
			if option == "Default" then
				SkinChanger.SetGlove(nil, nil)
				drawGlove()
				SkinChanger.Apply()
			else
				SkinChanger.SetGlove(option, "Stock")
				drawGlove()
				task.delay(0.2, pickGloveSkin, option)
			end
		end, false)
	end)

	------------------------------------------------------------------
	-- Right: header + the three columns inside one scrolling frame
	------------------------------------------------------------------
	local right = create("Frame", {
		Position = UDim2.fromOffset(184, 0),
		Size = UDim2.new(1, -184, 1, 0),
		BackgroundTransparency = 1,
		Parent = root,
	})
	local enabledButton = create("TextButton", {
		Text = "Skin Changer: Off",
		FontFace = Theme.FontBold,
		TextSize = 13,
		TextColor3 = Theme.TabText,
		AutoButtonColor = false,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = Theme.Element,
		Parent = right,
	}, { corner(6), stroke(Theme.ElementStroke) })

	local function renderEnabled()
		enabledButton.Text = "Skin Changer: " .. (if Cfg.On then "On" else "Off")
		enabledButton.TextColor3 = if Cfg.On then Theme.Accent else Theme.TabText
	end
	enabledButton.MouseButton1Click:Connect(function()
		Cfg.On = not Cfg.On
		renderEnabled()
		SkinChanger.Apply() -- also when switched off: puts the game's own look back and saves the state
	end)

	local scroller = create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 1, -36),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Stroke,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = right,
	})
	local columns = {}
	for i, category in ipairs(CATEGORIES) do
		local column = create("Frame", {
			Position = UDim2.new((i - 1) / 3, if i == 1 then 0 else 3, 0, 0),
			Size = UDim2.new(1 / 3, -6, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = scroller,
		}, { list(6) })
		textLabel({
			Text = category[1],
			Size = UDim2.new(1, 0, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Center,
			FontFace = Theme.FontBold,
			TextSize = 14,
			TextColor3 = Theme.Text,
			LayoutOrder = 0,
			Parent = column,
		})
		columns[i] = column
	end

	local tiles = {} -- [folder name] = { Image, Bar, Frame }
	-- the tile shows the skin's photo from ReplicatedStorage.Images (the same photo as in the skin picker); the game's
	-- 3D renderer (WeaponImages.render) is only the fallback when a weapon has no photo
	local function photoFor(weapon, skin)
		local entries = imagesFor(weapon)
		local entry = entries and entries:FindFirstChild(skin or "Stock")
		if entry and entry:IsA("StringValue") and entry.Value ~= "" then
			return entry.Value
		end
		return nil
	end

	local function drawIcon(tile, weapon)
		local skin = Cfg.Skins[weapon]
		local chosen = skin and skin ~= "Stock"
		tile.Bar.BackgroundColor3 = if chosen then Theme.Accent else Theme.Stroke
		local photo, standIn = skinImage(weapon, skin)
		tile.Image.Image = photo
		tile.Image.ImageTransparency = if standIn then 0.35 else 0
		if photo == "" then
			local module = renderer()
			if module then
				pcall(module.render, tile.Image, weapon, { skin = if chosen then skin else nil })
			end
		end
	end

	local function openSkins(tile, weapon)
		openSkinPicker(tile.Frame, weapon, Cfg.Skins[weapon] or "Stock", function(option)
			Cfg.Skins[weapon] = option
			drawIcon(tile, weapon)
			SkinChanger.Apply()
		end)
	end

	local function makeTile(column, weapon, order)
		local frame = create("TextButton", {
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.new(1, 0, 0, 66),
			BackgroundColor3 = Theme.Section,
			LayoutOrder = order,
			Parent = column,
		}, { corner(8), stroke(Theme.SectionStroke) })
		local image = create("ImageLabel", {
			Size = UDim2.new(1, -10, 1, -16),
			Position = UDim2.fromOffset(5, 3),
			BackgroundTransparency = 1,
			Image = "",
			Parent = frame,
		})
		textLabel({
			Text = weapon,
			Position = UDim2.fromOffset(6, 2),
			Size = UDim2.new(1, -12, 0, 12),
			TextSize = 10,
			TextColor3 = Theme.SubText,
			Parent = frame,
		})
		local bar = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -4),
			Size = UDim2.new(1, -16, 0, 2),
			BackgroundColor3 = Theme.Stroke,
			BorderSizePixel = 0,
			Parent = frame,
		})
		frame.MouseEnter:Connect(function()
			tween(frame, { BackgroundColor3 = Theme.Hover })
		end)
		frame.MouseLeave:Connect(function()
			tween(frame, { BackgroundColor3 = Theme.Section })
		end)
		local tile = { Frame = frame, Image = image, Bar = bar }
		frame.MouseButton1Click:Connect(function()
			openSkins(tile, weapon)
		end)
		return tile
	end

	local function populate()
		for _, tile in pairs(tiles) do
			tile.Frame:Destroy()
		end
		tiles = {}
		for name, button in pairs(teamButtons) do
			button.TextColor3 = if name == team then Theme.Accent else Theme.TabText
		end
		local pending = {}
		for i, category in ipairs(CATEGORIES) do
			local order = 0
			for _, name in ipairs(category[2]) do
				local folder = resolve(name)
				local allowed = if team == "T" then not CT_ONLY[name] else not T_ONLY[name]
				if folder and allowed then
					order += 1
					local tile = makeTile(columns[i], folder, order)
					tiles[folder] = tile
					table.insert(pending, { tile, folder })
				end
			end
		end
		-- the viewports are drawn one after another so opening the tab does not stall
		task.spawn(function()
			for _, item in ipairs(pending) do
				if item[1].Frame.Parent then
					drawIcon(item[1], item[2])
				end
				task.wait(0.03)
			end
		end)
	end
	for name, button in pairs(teamButtons) do
		button.MouseButton1Click:Connect(function()
			team = name
			populate()
		end)
	end
	renderEnabled()
	populate()

	-- The skin changer saves itself, independent of the presets: every change writes NeverloseBloxStrike/skins.json
	-- (after half a second without another change) and the file is read here, when the script starts. So the choices
	-- survive a restart without pressing Save in Presets, and no preset can bring older values back.
	local SKIN_FILE = CONFIG_DIR .. "/skins.json"
	local loadedSkins, saveQueued = false, false
	local function saveSkins()
		if not loadedSkins or saveQueued then
			return
		end
		saveQueued = true
		task.delay(0.5, function()
			saveQueued = false
			local fs = fileApi()
			if not fs then
				return
			end
			local encoded, json = pcall(function()
				return HttpService:JSONEncode({
					On = Cfg.On,
					Skins = Cfg.Skins,
					Knife = Cfg.Knife or "",
					Glove = Cfg.GloveName or "",
					GloveSkin = Cfg.GloveSkin or "",
				})
			end)
			if not encoded then
				return
			end
			pcall(function()
				if type(fs.MakeFolder) == "function" and type(fs.IsFolder) == "function" and not fs.IsFolder(CONFIG_DIR) then
					fs.MakeFolder(CONFIG_DIR)
				end
				fs.Write(SKIN_FILE, json)
			end)
		end)
	end
	SkinChanger.OnChange = saveSkins
	-- "new config" clears the skin changer too (the change is written to skins.json like any other)
	menu.OnNewConfig = function()
		Cfg.On = false
		Cfg.Skins = {}
		Cfg.Knife = nil
		SkinChanger.SetGlove(nil, nil)
		renderEnabled()
		for weapon, tile in pairs(tiles) do
			drawIcon(tile, weapon)
		end
		drawKnife()
		drawGlove()
		SkinChanger.Apply()
	end
	local function loadSkins()
		local fs = fileApi()
		if fs then
			local ok, raw = pcall(function()
				if fs.IsFile(SKIN_FILE) then
					return fs.Read(SKIN_FILE)
				end
				return nil
			end)
			if ok and type(raw) == "string" then
				local decoded, data = pcall(function()
					return HttpService:JSONDecode(raw)
				end)
				if decoded and type(data) == "table" then
					Cfg.Skins = {}
					local count = 0
					if type(data.Skins) == "table" then
						for weapon, skin in pairs(data.Skins) do
							if type(weapon) == "string" and type(skin) == "string" then
								Cfg.Skins[weapon] = skin
								if skin ~= "Stock" then
									count += 1
								end
							end
						end
					end
					Cfg.Knife = if type(data.Knife) == "string" and data.Knife ~= "" then data.Knife else nil
					if type(data.Glove) == "string" and data.Glove ~= "" then
						SkinChanger.SetGlove(data.Glove, if type(data.GloveSkin) == "string" and data.GloveSkin ~= "" then data.GloveSkin else "Stock")
					else
						SkinChanger.SetGlove(nil, nil)
					end
					Cfg.On = data.On == true
					menu:Log("Skin Changer: loaded " .. count .. " skin(s) from skins.json")
				end
			end
		end
		loadedSkins = true
		renderEnabled()
		for weapon, tile in pairs(tiles) do
			drawIcon(tile, weapon)
		end
		drawKnife()
		drawGlove()
		SkinChanger.Apply()
	end
	loadSkins()
end

------------------------------------------------------------------
-- Miscellaneous
------------------------------------------------------------------
do
	local movement = misc:AddSection("Movement", "Left")
	-- Bunny Hop. MEASURED in the game's own scripts (ControlScript.MasterControl, KeyboardMovement):
	--  * the jump key is a ContextAction that calls MasterControl:SetIsJumping(true) ONCE per key press (Begin);
	--    every call adds one "jump packet"; the movement step turns a packet into a jump only while the state is
	--    Running / Landed. Holding the key sends no further packets, so a held Space jumps once.
	--  * the jump keys come from SettingsController:GetState({"Keybinds","Jump"}) (a list of key names).
	-- Method "Game Input": while a jump key is held and the character is on the floor, send a new packet every frame
	-- (require(MasterControl):SetIsJumping(true)). "Key Press": executor keyrelease/keypress of the key.
	-- "Humanoid": Humanoid.Jump (the game's movement step ignores it; kept as a last resort).
	local bhop = { On = false, Method = "Game Input" }
	local bhopFocused, bhopLast, bhopWarned = true, 0, false
	local bhopKeys, bhopKeysAt = nil, 0
	UserInputService.WindowFocused:Connect(function()
		bhopFocused = true
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		bhopFocused = false
	end)

	local function bhopWarn(text)
		if not bhopWarned then
			bhopWarned = true
			menu:Log(text)
		end
	end

	-- the player's jump keys; Space when the settings module cannot be read
	local function jumpKeys()
		local now = os.clock()
		if bhopKeys and now - bhopKeysAt < 2 then
			return bhopKeys
		end
		bhopKeysAt = now
		local keys = {}
		pcall(function()
			local controllers = game:GetService("ReplicatedStorage"):FindFirstChild("Controllers")
			local module = controllers and controllers:FindFirstChild("SettingsController")
			local settings = module and require(module)
			local names = settings and settings:GetState({ "Keybinds", "Jump" })
			if type(names) == "table" then
				for _, name in pairs(names) do
					local key = Enum.KeyCode:FromName(tostring(name))
					if key then
						table.insert(keys, key)
					end
				end
			end
		end)
		if #keys == 0 then
			keys = { Enum.KeyCode.Space }
		end
		bhopKeys = keys
		return keys
	end

	local function jumpHeld()
		for _, key in ipairs(jumpKeys()) do
			if UserInputService:IsKeyDown(key) then
				return key
			end
		end
		return nil
	end

	local masterControl
	local function getMasterControl()
		if masterControl then
			return masterControl
		end
		local ok = pcall(function()
			local scripts = player:FindFirstChild("PlayerScripts")
			local control = scripts and scripts:FindFirstChild("ControlScript")
			local module = control and control:FindFirstChild("MasterControl")
			local m = module and require(module)
			if type(m) == "table" and type(m.SetIsJumping) == "function" then
				masterControl = m
			end
		end)
		return if ok then masterControl else nil
	end

	pcall(RunService.UnbindFromRenderStep, RunService, "BunnyHop")
	RunService:BindToRenderStep("BunnyHop", Enum.RenderPriority.Input.Value + 1, function()
		if not bhop.On or not bhopFocused or UserInputService:GetFocusedTextBox() ~= nil then
			return
		end
		local heldKey = jumpHeld()
		if not heldKey then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local now = os.clock()
		if not humanoid or humanoid.Health <= 0 then
			return
		end
		-- the game's movement step jumps only from Running / Landed
		local state = humanoid:GetState()
		local onFloor = state == Enum.HumanoidStateType.Running
			or state == Enum.HumanoidStateType.Landed
			or humanoid.FloorMaterial ~= Enum.Material.Air
		if not onFloor then
			return
		end

		if bhop.Method == "Game Input" then
			local m = getMasterControl()
			if m then
				-- MEASURED (MasterControl): every SetIsJumping(true) is one "jump packet"; the movement step turns the
				-- earliest packet that is later than the landing tick into the jump and the jump keeps full speed only
				-- when that packet is exactly the tick after landing (otherwise the horizontal speed is cut: the bunny
				-- hop felt slow). Several packets per frame, spread over the frame, make that exact tick far more likely.
				for _ = 1, 8 do
					pcall(m.SetIsJumping, m, true)
				end
				return
			end
			bhopWarn("Bunny Hop: ControlScript.MasterControl not reachable, falling back to Key Press")
		end
		if bhop.Method ~= "Humanoid" then
			if now - bhopLast < 0.06 then
				return
			end
			local ok, press, release = pcall(function()
				return keypress, keyrelease
			end)
			if ok and type(press) == "function" and type(release) == "function" then
				if heldKey == Enum.KeyCode.Space then
					bhopLast = now
					pcall(release, 0x20) -- Windows virtual-key code of Space
					pcall(press, 0x20)
					return
				end
				bhopWarn("Bunny Hop: Key Press supports Space only (jump key is " .. heldKey.Name .. "), using Humanoid")
			else
				bhopWarn("Bunny Hop: no keypress/keyrelease in this executor, using Humanoid")
			end
		end
		humanoid.Jump = true
	end)
	local bunnyHop = movement:AddToggle("Bunny Hop", false, function(v)
		bhop.On = v
	end):AddSettings(250, "Bunny Hop")
	bunnyHop:AddDropdown("Method", { "Game Input", "Key Press", "Humanoid" }, "Game Input", function(v)
		bhop.Method = v
	end)
	table.insert(Unloaders, function()
		bhop.On = false
		pcall(RunService.UnbindFromRenderStep, RunService, "BunnyHop")
	end)
	-- Air Strafe (automatic, from the velocity). MEASURED in the game's movement code (ControlScript.MasterControl):
	--  * the movement vector is MasterControl:GetMoveVector() (x = right, z = back, W = -1); the PreSimulation step reads it
	--    (v14 = v13) and makes the wish direction  (planar look * -z + planar right * x).Unit  with the wish speed
	--    Speed * 0.0625 * min(|(x, z)|, 1);
	--  * moveAir (every 1/128 s) adds speed along the wish direction only while the speed already along it is below
	--    min(wishSpeed, 3.75), by at most 8 * wishSpeed * dt per tick, and caps the horizontal speed at 20.625
	--    (run speed 15.625).
	-- So the best wish direction is the velocity direction turned by acos(3.75 / speed) to the side the view is on: the
	-- speed along the wish stays just below the limit, so every tick adds speed, and the velocity is carried round
	-- towards where the view points (the character is not thrown aside). That direction is turned back into the input
	-- (x, z) = (wish . right, -(wish . look)), a full-length vector, and SET each frame; the player's own keys decide what it
	-- is set back to on landing, so nothing is left over.
	-- Modes: "View Angles" strafes whenever airborne; "Movement Keys" only while a W / A / S / D key is held;
	-- "Avoid Collisions" falls back to the player's keys when a wall is within 2.5 studs along the wish direction.
	-- Turn Speed: how much of the optimal angle is used (50 = all of it); Smoothing: how slowly the input follows.
	-- NOT verified in the game.
	local airStrafe = { On = false, Modes = { "View Angles" }, Smoothing = 50, TurnSpeed = 50 }
	local strafeActive, strafeFilter, strafeYaw, strafeSide = false, nil, nil, 1
	local driftFrames, driftReported = 0, false
	local strafeRay = RaycastParams.new()
	strafeRay.FilterType = Enum.RaycastFilterType.Exclude

	-- the movement input the player's own keys give (KeyboardMovement: A = -x, D = +x, W = -z, S = +z)
	local function ownInput()
		local function held(key)
			return if UserInputService:IsKeyDown(key) then 1 else 0
		end
		return held(Enum.KeyCode.D) - held(Enum.KeyCode.A), held(Enum.KeyCode.S) - held(Enum.KeyCode.W)
	end

	local function strafeSet(m, x, z)
		local ok, current = pcall(m.GetMoveVector, m)
		if ok and typeof(current) == "Vector3" and (math.abs(current.X - x) > 1e-4 or math.abs(current.Z - z) > 1e-4) then
			pcall(m.AddToPlayerMovement, m, Vector3.new(x - current.X, 0, z - current.Z))
		end
	end

	local function strafeRelease(m)
		if strafeActive then
			strafeActive, strafeFilter = false, nil
			if m then
				strafeSet(m, ownInput()) -- back to what the keys say
			end
		end
	end

	pcall(RunService.UnbindFromRenderStep, RunService, "AirStrafe")
	RunService:BindToRenderStep("AirStrafe", Enum.RenderPriority.Camera.Value + 3, function()
		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end
		local look = cam.CFrame.LookVector
		local yaw = math.atan2(-look.X, -look.Z)
		local delta = if strafeYaw then (yaw - strafeYaw + math.pi) % (2 * math.pi) - math.pi else 0
		strafeYaw = yaw
		local m = getMasterControl()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local state = humanoid and humanoid:GetState()
		local airborne = humanoid ~= nil and humanoid.Health > 0 and root ~= nil
			and (state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall)
		local keysHeld = UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.A)
			or UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.D)
		local allowed = table.find(airStrafe.Modes, "View Angles") ~= nil
			or (table.find(airStrafe.Modes, "Movement Keys") ~= nil and keysHeld)
		if not (airStrafe.On and m and airborne and allowed and bhopFocused and UserInputService:GetFocusedTextBox() == nil) then
			strafeRelease(m)
			-- Drift guard: on the ground, with Air Strafe on, a movement input that the keys do not explain (left over from
			-- anything that changed the game's movement vector and did not give it back) is removed after 3 frames.
			-- Gamepad / touch movement is not seen by this check and would be cancelled while Air Strafe is on.
			if airStrafe.On and m and not airborne and bhopFocused and UserInputService:GetFocusedTextBox() == nil
				and not (LegitAim.QuickStopActive and LegitAim.QuickStopActive()) then
				local okVector, current = pcall(m.GetMoveVector, m)
				local keyX, keyZ = ownInput()
				if okVector and typeof(current) == "Vector3" and (math.abs(current.X - keyX) > 0.01 or math.abs(current.Z - keyZ) > 0.01) then
					driftFrames += 1
					if driftFrames >= 3 then
						strafeSet(m, keyX, keyZ)
						driftFrames = 0
					end
				else
					driftFrames = 0
				end
			end
			return
		end

		local lookFlat = Vector3.new(look.X, 0, look.Z)
		if lookFlat.Magnitude < 1e-3 then
			return
		end
		lookFlat = lookFlat.Unit
		local rightFlat = Vector3.new(-lookFlat.Z, 0, lookFlat.X)
		local velocity = root.AssemblyLinearVelocity
		local planar = Vector3.new(velocity.X, 0, velocity.Z)
		local speed = planar.Magnitude

		local wish
		if speed < 1 then
			wish = lookFlat -- standing still in the air: simply push where the view points
		else
			local velocityDir = planar / speed
			local limit = 3.75
			local optimal = math.acos(math.clamp(limit / math.max(speed, limit), -1, 1))
			local angle = math.min(optimal * (0.8 + 0.4 * (airStrafe.TurnSpeed / 100)), math.rad(89))
			-- turn the velocity towards the side the view is on (Y of velocity x look < 0: the view is on the right)
			local cross = velocityDir.Z * lookFlat.X - velocityDir.X * lookFlat.Z
			if math.abs(cross) > 0.02 then
				strafeSide = if cross < 0 then -1 else 1
			elseif math.abs(delta) > 1e-4 then
				strafeSide = if delta < 0 then -1 else 1 -- aligned: follow the way the view is turning
			end
			wish = CFrame.Angles(0, strafeSide * angle, 0):VectorToWorldSpace(velocityDir)
		end

		local x, z = wish:Dot(rightFlat), -wish:Dot(lookFlat)
		-- follow smoothly and keep the full length (a shorter input would give a smaller wish speed)
		local alpha = 1 - math.clamp(airStrafe.Smoothing / 100, 0, 0.9)
		if strafeFilter then
			x = strafeFilter.X + (x - strafeFilter.X) * alpha
			z = strafeFilter.Y + (z - strafeFilter.Y) * alpha
		end
		local length = math.sqrt(x * x + z * z)
		if length > 1e-3 then
			x, z = x / length, z / length
		end
		strafeFilter = Vector2.new(x, z)

		if table.find(airStrafe.Modes, "Avoid Collisions") then
			local dir = lookFlat * -z + rightFlat * x
			if dir.Magnitude > 1e-3 then
				strafeRay.FilterDescendantsInstances = { character, cam }
				if Workspace:Raycast(root.Position, dir.Unit * 2.5, strafeRay) then
					x, z = ownInput()
				end
			end
		end
		strafeActive = true
		strafeSet(m, x, z)
	end)
	table.insert(Unloaders, function()
		airStrafe.On = false
		pcall(RunService.UnbindFromRenderStep, RunService, "AirStrafe")
		strafeRelease(getMasterControl())
	end)
	local strafeSettings = movement:AddToggle("Air Strafe", false, function(v)
		airStrafe.On = v
	end):AddSettings(260, "Air Strafe")
	strafeSettings:AddMultiDropdown("Mode", { "Avoid Collisions", "View Angles", "Movement Keys" }, { "View Angles" }, function(list)
		airStrafe.Modes = list
	end)
	strafeSettings:AddSlider("Smoothing", 0, 100, 50, function(v)
		airStrafe.Smoothing = v
	end, "%")
	strafeSettings:AddSlider("Turn Speed", 0, 100, 50, function(v)
		airStrafe.TurnSpeed = v
	end, "%")
	-- Speed: its own toggle with a Multiplier slider. Every frame the character is moved along its CURRENT horizontal
	-- velocity by (multiplier - 1) * velocity * dt, while a W / A / S / D key is held. This does not depend on how the game
	-- computes its own speed (changing the character attribute "Speed" was tried first and had no effect), so the game's
	-- movement code and its speed caps are left alone and only add to what they produce. A ray along the extra step stops
	-- it before solid parts, so the character is not pushed into walls.
	-- NOT verified: that the server accepts the faster position changes (it may pull the character back).
	local speedCfg = { On = false, Mult = 1.1 }
	local speedRay = RaycastParams.new()
	speedRay.FilterType = Enum.RaycastFilterType.Exclude
	speedRay.RespectCanCollide = true
	local speedConn = RunService.Heartbeat:Connect(function(dt)
		if not speedCfg.On or UserInputService:GetFocusedTextBox() ~= nil then
			return
		end
		local ok, err = pcall(function()
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local cam = Workspace.CurrentCamera
			if not (humanoid and root and cam) or humanoid.Health <= 0 or humanoid.Sit then
				return
			end
			local keyX, keyZ = ownInput()
			if keyX == 0 and keyZ == 0 then
				return
			end
			local velocity = root.AssemblyLinearVelocity
			local planar = Vector3.new(velocity.X, 0, velocity.Z)
			if planar.Magnitude < 1 or planar.Magnitude > 200 then
				return
			end
			local extra = planar * (speedCfg.Mult - 1) * math.min(dt, 0.1)
			if extra.Magnitude < 1e-4 then
				return
			end
			speedRay.FilterDescendantsInstances = { character, cam }
			local margin = 1.2
			local hit = Workspace:Raycast(root.Position, extra.Unit * (extra.Magnitude + margin), speedRay)
			if hit then
				local room = hit.Distance - margin
				if room <= 0 then
					return
				end
				extra = extra.Unit * math.min(extra.Magnitude, room)
			end
			root.CFrame = root.CFrame + extra
		end)
		if not ok then
			warn("[Speed] " .. tostring(err))
		end
	end)
	table.insert(Unloaders, function()
		speedCfg.On = false
		speedConn:Disconnect()
	end)
	local speedSettings = movement:AddToggle("Speed", false, function(v)
		speedCfg.On = v
	end):AddSettings(250, "Speed")
	speedSettings:AddSlider("Multiplier", 100, 150, 110, function(v)
		speedCfg.Mult = v / 100
	end, "%")
	movement:AddToggle("Jump Bug", false, Feat.unwired("Jump Bug", "needs the game fall-damage and duck timing of its custom movement, not measured; read MasterControl duck / landing code")):AddSettings(250, "Jump Bug")
	movement:AddToggle("Edge Quick Stop", false, function(v) Feat.EdgeQuickStop = v end)
	movement:AddToggle("Standalone Quick Stop", false, function(v) Feat.StandaloneQuickStop = v end)
	movement:AddToggle("Strafe Assist", false, Feat.unwired("Strafe Assist", "its behaviour is undefined: Air Strafe already covers strafing; say what this should do"))
	movement:AddToggle("Edge Jump", false, function(v) Feat.EdgeJump = v end)
	local slowWalkSettings = movement:AddToggle("Slow Walk", false, function(v) Feat.SlowWalk = v end):AddSettings(250, "Slow Walk")
	slowWalkSettings:AddSlider("Speed", 10, 90, 50, function(v) Feat.SlowWalkSpeed = v / 100 end, "%")
	movement:AddToggle("Fast Ladder", false, Feat.unwired("Fast Ladder", "ladder handling of the custom movement is not measured; read MasterControl for the climbing state"))

	local features = misc:AddSection("Features", "Right")
	features:AddToggle("Quick Switch", false, Feat.unwired("Quick Switch", "weapon switching goes through the game inventory input, not measured; " .. Feat.Notes.Remote))
	features:AddToggle("Super Toss", false, Feat.unwired("Super Toss", "the throw velocity is built outside the client sim and no ThrowGrenade request was captured; " .. Feat.Notes.Remote))
	features:AddToggle("Prevent AFK Kick", false, function(v) Feat.PreventAFK = v end)
	features:AddSlider("Game Volume", 0, 100, 100, function(v)
		Feat.GameVolumeRaw = v
		if Feat.SetGameVolume then
			Feat.SetGameVolume(v)
		end
	end, "%")
	local hitSoundSettings = features:AddToggle("Hit Sound", false, function(v) Feat.HitSound = v end):AddSettings(270, "Hit Sound")
	hitSoundSettings:AddDropdown("Sound", Feat.ShootSoundNames, "Hit1", function(v)
		Feat.HitSoundName = v
		if menu._visible and Feat.PreviewHitSound then
			Feat.PreviewHitSound() -- plays the picked sound for you
		end
	end)
	hitSoundSettings:AddSlider("Volume", 0, 100, 50, function(v) Feat.HitSoundVolume = v / 100 end, "%")
	do
		local shootSoundSettings = features:AddToggle("Shoot Sound", false, function(v) Feat.ShootSound = v end):AddSettings(270, "Shoot Sound")
		shootSoundSettings:AddDropdown("Sound", Feat.ShootSoundNames, "Hit1", function(v)
			Feat.ShootSoundName = v
			if menu._visible and Feat.PreviewShootSound then
				Feat.PreviewShootSound() -- plays the picked sound for you
			end
		end)
		shootSoundSettings:AddSlider("Volume", 0, 100, 50, function(v) Feat.ShootSoundVolume = v / 100 end, "%")
	end
	features:AddToggle("Automatic Purchase", false, Feat.unwired("Automatic Purchase", Feat.Notes.Remote)):AddSettings(270, "Automatic Purchase")
	features:AddToggle("Auto-Accept Matchmaking", false, Feat.unwired("Auto-Accept Matchmaking", Feat.Notes.Remote))
	features:AddToggle("Reveal Enemy Chat", false, Feat.unwired("Reveal Enemy Chat", Feat.Notes.Chat))
	features:AddMultiDropdown("Filter Chat Messages", { "Damage Dealt", "Damage Received", "Missed Shots", "Purchases", "Votes" }, {}, Feat.unwired("Filter Chat Messages", Feat.Notes.Chat))
	features:AddMultiDropdown("Log Events", { "Damage Dealt", "Damage Received", "Missed Shots", "Purchases", "Votes" }, { "Damage Dealt" }, function(list)
		Feat.LogEvents = list
		if table.find(list, "Purchases") or table.find(list, "Votes") then
			Feat.gate("Log Events: Purchases / Votes", Feat.Notes.Remote)
		end
	end)
end

------------------------------------------------------------------
-- Extras: hit feedback, bullet effects, grenades / smokes, flash and fog removal, radar, penetration indicator,
-- movement helpers, Peek Assist, AFK guard. Reads what the menu stores in Feat.
-- MEASURED = from the dump or an earlier probe (named at each use). ASSUMED = generic Roblox / guess, to verify in-game.
-- Nothing here is verified on the live game: it has not been run.
-- Runs as its own function: the main chunk is near Luau's limit of 200 active locals.
------------------------------------------------------------------
;(function()
	local Workspace = game:GetService("Workspace")
	local Lighting = game:GetService("Lighting")
	local SoundService = game:GetService("SoundService")
	local Debris = game:GetService("Debris")
	local VirtualUser = game:GetService("VirtualUser")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local peekShotAt = 0 -- os.clock() of the last shot seen by the BulletHitreg hook
	local STUDS_TO_METERS = 0.28 -- same conversion as the ESP
	local E = LegitAim.Engine
	local Adapter = EnemyESP.Adapter
	local connections = {}
	local failed = {}

	local function fail(tag, err)
		if failed[tag] ~= tostring(err) then
			failed[tag] = tostring(err)
			warn("[Extras:" .. tag .. "] " .. tostring(err))
			menu:Log("Extras " .. tag .. " error, see console")
		end
	end
	local function guard(tag, fn, ...)
		local ok, err = pcall(fn, ...)
		if not ok then
			fail(tag, err)
		end
	end
	local function has(list, name)
		return table.find(list, name) ~= nil
	end

	------------------------------------------------------------------
	-- Pure helpers (no game state)
	------------------------------------------------------------------
	-- radar: rel = other - camera (world), forward / right = camera yaw axes on the ground plane (Y up, right-handed).
	-- Returns the pixel offset from the radar centre (x right, y down), clamped to the circle.
	local function radarPoint(rel, forward, right, range, radius)
		local x, y = rel:Dot(right), rel:Dot(forward)
		local scale = radius / range
		local px, py = x * scale, -y * scale
		local len = math.sqrt(px * px + py * py)
		if len > radius then
			px, py = px / len * radius, py / len * radius
		end
		return px, py
	end

	-- MEASURED (Grenade module): bounce = (u - 1.45 * (u . n) * n) * |v|
	local function reflectBounce(v, n)
		local m = v.Magnitude
		if m < 1e-6 then
			return v
		end
		local u = v.Unit
		return (u - 1.45 * u:Dot(n) * n) * m
	end

	-- MEASURED (BulletCast.BulletFalloff): the falloff a wall of this thickness costs
	local MATERIAL_COST = {
		[Enum.Material.DiamondPlate] = 0.35,
		[Enum.Material.CorrodedMetal] = 0.75,
		[Enum.Material.Metal] = 0.75,
		[Enum.Material.Concrete] = 0.75,
		[Enum.Material.Brick] = 0.75,
		[Enum.Material.Wood] = 2.25,
		[Enum.Material.WoodPlanks] = 2.25,
	}
	local NAME_COST = { Grate = 2.25, Glass = 0, Cardboard = 0 }
	local function wallCost(thickness, modifier, power)
		if modifier == 0 then
			return 0
		end
		local cost = thickness / modifier / power
		if cost ~= cost then
			return 0
		end
		return cost
	end

	-- steps a thrown grenade 1/60 s. MEASURED (Grenade module): 60 Hz step, gravity added each step, ground contact
	-- scales the speed by 1 - (|u . down| - 0.5) / 2 when |u . down| >= 0.5, then reflects with reflectBounce; after the
	-- first ground bounce the velocity decays with lerp(v, 0, 0.25, dt) = v * exp(-0.25 dt). Slope sliding is not modelled.
	local function bounceVelocity(v, normal)
		local m = v.Magnitude
		if m > 1e-6 then
			local d = math.abs(v.Unit:Dot(Vector3.new(0, -1, 0)))
			if d >= 0.5 then
				v = v * (1 - (d - 0.5) / 2)
			end
		end
		return reflectBounce(v, normal)
	end

	------------------------------------------------------------------
	-- GUI container and 3D effect folder
	------------------------------------------------------------------
	local playerGui = player:WaitForChild("PlayerGui")
	local cameraAtLoad = Workspace.CurrentCamera
	if cameraAtLoad then
		for _, c in ipairs(cameraAtLoad:GetChildren()) do
			if c:IsA("Highlight") then
				c:Destroy()
			end
		end
	end
	local oldGui = playerGui:FindFirstChild("NLExtras")
	if oldGui then
		oldGui:Destroy()
	end
	local gui = create("ScreenGui", {
		Name = "NLExtras",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 6,
		Parent = playerGui,
	})

	-- under the camera on purpose: the game's grenade / bullet casts whitelist Terrain and Map folders, never the camera
	local function fxFolder()
		local cam = Workspace.CurrentCamera
		if not cam then
			return nil
		end
		local f = cam:FindFirstChild("NLFx")
		if not f then
			f = Instance.new("Folder")
			f.Name = "NLFx"
			f.Parent = cam
		end
		return f
	end

	local function newFrame(parent, color)
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.BackgroundColor3 = color or Color3.new(1, 1, 1)
		f.Visible = false
		f.Parent = parent
		return f
	end
	local function newText(parent, size)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamBold
		l.TextSize = size or 13
		l.TextColor3 = Color3.new(1, 1, 1)
		l.TextStrokeTransparency = 0.4
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Size = UDim2.fromOffset(260, 16)
		l.Visible = false
		l.Parent = parent
		return l
	end
	local function placeLine(f, a, b, thickness)
		local d = b - a
		f.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
		f.Size = UDim2.fromOffset(math.max(d.Magnitude, 1), thickness)
		f.Rotation = math.deg(math.atan2(d.Y, d.X))
		f.Visible = true
	end
	local function project(cam, point)
		local v, onScreen = cam:WorldToViewportPoint(point)
		if v.Z <= 0 or not onScreen then
			return nil
		end
		return Vector2.new(v.X, v.Y)
	end

	------------------------------------------------------------------
	-- Hit feedback. MEASURED (spectate_diff.txt + recording): the player attributes TotalDamage and Headshots rise on the
	-- local player when it damages someone, and Damaged_UserId holds the victim for about a second.
	-- ASSUMED: the ids below (the game's own ReplicatedStorage.Sounds Hit1..Hit6 / Damage1) suit as a hit confirmation.
	------------------------------------------------------------------
	local HIT_SOUNDS = {
		Hit1 = "rbxassetid://93480384164139",
		Hit2 = "rbxassetid://70449006573568",
		Hit3 = "rbxassetid://116147455394529",
		Hit4 = "rbxassetid://85834859045781",
		Hit5 = "rbxassetid://111500749678945",
		Hit6 = "rbxassetid://80804883667633",
		Damage = "rbxassetid://107570278849125",
	}
	local function logOn(name)
		return has(Feat.LogEvents, name)
	end

	local marker = create("Frame", {
		Name = "HitMarker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local markerTicks = {}
	for _, spec in ipairs({ { -7, -7, 45 }, { 7, 7, 45 }, { 7, -7, -45 }, { -7, 7, -45 } }) do
		local bar = newFrame(marker)
		bar.Position = UDim2.fromOffset(spec[1], spec[2])
		bar.Rotation = spec[3]
		bar.Size = UDim2.fromOffset(8, 2)
		table.insert(markerTicks, bar)
	end
	local function showMarker(headshot)
		for _, bar in ipairs(markerTicks) do
			bar.BackgroundColor3 = if headshot then Color3.fromRGB(255, 70, 70) else Feat.HitMarkerColor
			bar.Size = UDim2.fromOffset(if headshot then 11 else 8, 2)
			bar.BackgroundTransparency = 0
			bar.Visible = true
			TweenService:Create(bar, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
		end
	end
	local function playHitSound()
		if Feat.PlaySound then
			Feat.PlaySound(Feat.HitSoundName, Feat.HitSoundVolume)
		end
	end

	-- floating damage number over the victim. ASSUMED: the number is the TotalDamage delta of the hit (one bullet, or the sum
	-- when several hits arrive between two attribute updates).
	local function showDamageNumber(plr, damage, headshot)
		local character = plr and plr.Character
		local anchor = character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
		if not (anchor and anchor:IsA("BasePart")) then
			return
		end
		local bb = Instance.new("BillboardGui")
		bb.Adornee = anchor
		bb.AlwaysOnTop = true
		bb.Size = UDim2.fromOffset(80, 24)
		bb.StudsOffset = Vector3.new((math.random() - 0.5) * 1.5, 2.2, 0)
		bb.Parent = gui
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.GothamBold
		t.TextSize = if headshot then 22 else 17
		t.TextColor3 = if headshot then Color3.fromRGB(255, 70, 70) else Feat.DamageColor
		t.TextStrokeTransparency = 0.3
		t.Text = tostring(math.floor(damage + 0.5))
		t.Parent = bb
		TweenService:Create(bb, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = bb.StudsOffset + Vector3.new(0, 2.5, 0) }):Play()
		TweenService:Create(t, TweenInfo.new(0.9), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		Debris:AddItem(bb, 1)
	end
	local victimName, victimAt, victimPlr = nil, 0, nil
	local lastTotal, lastHeads, feedbackAt = nil, nil, 0
	-- marker + sound, once per hit
	local function feedback(headshot)
		feedbackAt = os.clock()
		if Feat.HitMarker then
			showMarker(headshot)
		end
		if Feat.HitSound then
			playHitSound()
		end
	end
	-- damage number + log line
	local function describeHit(damage, headshot)
		if Feat.DamageNumbers and damage and victimPlr and os.clock() - victimAt < 1.5 then
			guard("damage numbers", showDamageNumber, victimPlr, damage, headshot)
		end
		if logOn("Damage Dealt") then
			local who = if victimName and os.clock() - victimAt < 1.5 then victimName else "enemy"
			local amount = if damage then (" for " .. tostring(math.floor(damage + 0.5))) else ""
			menu:Log("Hit " .. who .. amount .. (if headshot then " (head)" else ""))
		end
	end
	-- MEASURED (recording): Damaged_UserId is set to the victim's UserId at the moment you damage someone and cleared about a
	-- second later, so it is the real-time hit signal: marker and sound fire from it at once. TotalDamage / Headshots (MEASURED
	-- player attributes) add the amount and the headshot flag; they may update later, and when no Damaged_UserId came with a
	-- hit (a burst on one victim within that second does not change the attribute again) they signal the hit themselves.
	table.insert(connections, player:GetAttributeChangedSignal("Damaged_UserId"):Connect(function()
		local id = player:GetAttribute("Damaged_UserId")
		if type(id) == "number" then
			local victim = Players:GetPlayerByUserId(id)
			victimName, victimAt, victimPlr = if victim then victim.Name else nil, os.clock(), victim
			feedback(false)
			if type(player:GetAttribute("TotalDamage")) ~= "number" then
				describeHit(nil, false) -- no damage counter on this build
			end
		end
	end))
	lastTotal, lastHeads = player:GetAttribute("TotalDamage"), player:GetAttribute("Headshots")
	table.insert(connections, player:GetAttributeChangedSignal("TotalDamage"):Connect(function()
		local total = player:GetAttribute("TotalDamage")
		if type(total) ~= "number" then
			return
		end
		local heads = player:GetAttribute("Headshots")
		if type(lastTotal) == "number" and total > lastTotal then
			local headshot = type(heads) == "number" and type(lastHeads) == "number" and heads > lastHeads
			if os.clock() - feedbackAt < 0.4 then
				if headshot then
					showMarker(true) -- the hit was already signalled by Damaged_UserId; add the headshot flash
				end
			else
				feedback(headshot)
			end
			describeHit(total - lastTotal, headshot)
		end
		lastTotal, lastHeads = total, heads
	end))

	-- Damage Received: the local humanoid's health dropping
	local function bindHealth(character)
		local humanoid = character:WaitForChild("Humanoid", 5)
		if not humanoid then
			return
		end
		local last = humanoid.Health
		humanoid.HealthChanged:Connect(function(h)
			if h < last and logOn("Damage Received") then
				menu:Log("Took " .. tostring(math.floor(last - h + 0.5)) .. " damage")
			end
			last = h
		end)
	end
	table.insert(connections, player.CharacterAdded:Connect(bindHealth))
	if player.Character then
		task.spawn(bindHealth, player.Character)
	end

	------------------------------------------------------------------
	-- Bullet tracers / impacts / sparks, from the shot itself. MEASURED (shots.txt, silent aim notes): one shot is
	-- BulletHitreg:InvokeServer(origin, direction, hits, weapon, opts), hits[i].Position is where the bullet struck.
	-- Needs the same executor hook as Silent Aim (it feeds Feat.OnShot).
	------------------------------------------------------------------
	local function spawnTracer(from, to, color)
		local folder = fxFolder()
		if not folder then
			return
		end
		local part = Instance.new("Part")
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
		part.Transparency = 1
		part.Size = Vector3.new(0.05, 0.05, 0.05)
		part.CFrame = CFrame.new(from)
		part.Parent = folder
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Parent, a1.Parent = part, part
		a1.WorldPosition = to
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Color = ColorSequence.new(color)
		beam.LightEmission = 1
		beam.FaceCamera = true
		beam.Segments = 1
		beam.Width0, beam.Width1 = 0.08, 0.08
		beam.Parent = part
		TweenService:Create(beam, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Width0 = 0, Width1 = 0 }):Play()
		Debris:AddItem(part, 0.8)
	end
	local function spawnImpact(position, normal, color, sparkColor)
		local folder = fxFolder()
		if not folder then
			return
		end
		if color then
			local ball = Instance.new("Part")
			ball.Shape = Enum.PartType.Ball
			ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch = true, false, false, false
			ball.Material = Enum.Material.Neon
			ball.Color = color
			ball.Size = Vector3.new(0.35, 0.35, 0.35)
			ball.Position = position
			ball.Parent = folder
			TweenService:Create(ball, TweenInfo.new(0.6), { Transparency = 1, Size = Vector3.new(0.9, 0.9, 0.9) }):Play()
			Debris:AddItem(ball, 0.7)
		end
		if sparkColor then
			local emitterPart = Instance.new("Part")
			emitterPart.Anchored, emitterPart.CanCollide, emitterPart.CanQuery, emitterPart.CanTouch = true, false, false, false
			emitterPart.Transparency = 1
			emitterPart.Size = Vector3.new(0.2, 0.2, 0.2)
			emitterPart.CFrame = CFrame.lookAt(position, position + normal)
			emitterPart.Parent = folder
			local p = Instance.new("ParticleEmitter")
			p.Rate = 0
			p.Lifetime = NumberRange.new(0.15, 0.4)
			p.Speed = NumberRange.new(8, 18)
			p.SpreadAngle = Vector2.new(60, 60)
			p.Color = ColorSequence.new(sparkColor)
			p.LightEmission = 1
			p.Size = NumberSequence.new(0.14, 0)
			p.Parent = emitterPart
			p:Emit(10)
			Debris:AddItem(emitterPart, 0.6)
		end
	end

	Feat.OnShot = function(args)
		if typeof(args[1]) ~= "Vector3" or typeof(args[2]) ~= "Vector3" or type(args[3]) ~= "table" then
			return -- not the measured argument shape
		end
		local origin, direction, hits = args[1], args[2], args[3]
		local last = hits[#hits]
		local landed = type(last) == "table" and typeof(last.Position) == "Vector3"
		local endPos = if landed then last.Position else origin + direction * 300
		local normal = if landed and typeof(last.Normal) == "Vector3" then last.Normal else -direction
		if not landed and logOn("Missed Shots") then
			menu:Log("Shot without a client hit")
		end
		peekShotAt = os.clock()
		task.defer(function()
			local cam = Workspace.CurrentCamera
			if Feat.Tracers and cam then
				local cf = cam.CFrame
				local start = origin + cf.RightVector * 0.6 - cf.UpVector * 0.5 + cf.LookVector * 1.5
				spawnTracer(start, endPos, Feat.TracerColor)
			end
			if landed and (Feat.Impacts or Feat.Sparks) then
				spawnImpact(endPos, normal, if Feat.Impacts then Feat.ImpactColor else nil, if Feat.Sparks then Feat.SparkColor else nil)
			end
		end)
	end

	------------------------------------------------------------------
	-- Grenades. MEASURED (Grenade module): a thrown grenade is a BasePart with child creator.NameTag (StringValue, e.g.
	-- "Smoke Grenade"), a Vector3Value Velocity2 (current velocity), and a "Stopped" folder once it rests. Where in
	-- Workspace it lives is NOT measured, so the scan looks at Workspace, Debris and Ray_Ignore (two levels).
	-- Smokes: Workspace.Ray_Ignore.Smokes (BulletCast); fires: Workspace.Ray_Ignore.Fires, active ones have attribute
	-- Enabled (Grenade module). ASSUMED: those parts' size is the effect's extent.
	------------------------------------------------------------------
	local grenades = {} -- [part] = entry
	local WARN_NAMES = { ["HE Grenade"] = true, Molotov = true, Flashbang = true } -- names MEASURED in LoadoutGrenades
	local WARN_RADIUS = 45 -- studs, ASSUMED (blast radii are not in the dump)

	local function grenadeNameOf(part)
		local creator = part:FindFirstChild("creator")
		local tag = creator and creator:FindFirstChild("NameTag")
		if tag and tag:IsA("StringValue") and tag.Value ~= "" then
			return tag.Value
		end
		return nil
	end
	local function scanFolder(folder, depth, found, budget)
		for _, c in ipairs(folder:GetChildren()) do
			budget.n = budget.n + 1
			if budget.n > 700 then
				return
			end
			if c:IsA("BasePart") then
				if grenadeNameOf(c) then
					found[c] = true
				end
			elseif depth > 1 and (c:IsA("Folder") or c:IsA("Model")) and c.Name ~= "Map" and c.Name ~= "Fires" and c.Name ~= "Smokes" then
				scanFolder(c, depth - 1, found, budget)
			end
		end
	end

	local function dropGrenade(part, entry)
		if entry.Label then
			entry.Label:Destroy()
		end
		if entry.Highlight then
			entry.Highlight:Destroy()
		end
		grenades[part] = nil
	end

	local zoneAdornments = {} -- [part] = SphereHandleAdornment
	local function syncZones(folder, enabled, color, requireEnabled)
		local alive = {}
		if enabled and folder then
			for _, part in ipairs(folder:GetChildren()) do
				if part:IsA("BasePart") and (not requireEnabled or part:GetAttribute("Enabled")) then
					alive[part] = true
					local a = zoneAdornments[part]
					if not a then
						a = Instance.new("SphereHandleAdornment")
						a.Adornee = part
						a.AlwaysOnTop = false
						a.ZIndex = 1
						a.Parent = gui
						zoneAdornments[part] = a
					end
					a.Radius = math.max(part.Size.X, part.Size.Y, part.Size.Z) / 2
					a.Color3 = color
					a.Transparency = 0.8
				end
			end
		end
		return alive
	end

	local smokeSaved = setmetatable({}, { __mode = "k" })
	local function smokeVisuals(smokes, hide)
		if not smokes then
			return
		end
		local n = 0
		for _, d in ipairs(smokes:GetDescendants()) do
			n = n + 1
			if n > 400 then
				break
			end
			if d:IsA("ParticleEmitter") then
				if hide then
					if smokeSaved[d] == nil then
						smokeSaved[d] = d.Enabled
					end
					d.Enabled = false
				elseif smokeSaved[d] ~= nil then
					d.Enabled = smokeSaved[d]
					smokeSaved[d] = nil
				end
			elseif d:IsA("BasePart") then
				d.LocalTransparencyModifier = if hide then 1 else 0
			end
		end
	end

	local smokeWasOn = false
	local function slowScan()
		local ray = Workspace:FindFirstChild("Ray_Ignore")
		local smokes = ray and ray:FindFirstChild("Smokes")
		local fires = ray and ray:FindFirstChild("Fires")
		-- grenade discovery
		if Feat.GrenadeEsp or Feat.GrenadeFx or Feat.Trajectory or Feat.Proximity then
			local found, budget = {}, { n = 0 }
			scanFolder(Workspace, 2, found, budget)
			local debris = Workspace:FindFirstChild("Debris")
			if debris then
				scanFolder(debris, 2, found, budget)
			end
			if ray then
				scanFolder(ray, 2, found, budget)
			end
			for part in pairs(found) do
				if not grenades[part] then
					grenades[part] = { Name = grenadeNameOf(part), History = {}, Warned = false }
				end
			end
		end
		for part, entry in pairs(grenades) do
			if not part:IsDescendantOf(Workspace) then
				dropGrenade(part, entry)
			end
		end
		-- zones
		local aliveSmokes = syncZones(smokes, Feat.SmokeRadius, Color3.fromRGB(160, 170, 190), false)
		local aliveFires = syncZones(fires, Feat.InfernoRadius, Color3.fromRGB(255, 140, 50), true)
		for part, a in pairs(zoneAdornments) do
			if not aliveSmokes[part] and not aliveFires[part] then
				a:Destroy()
				zoneAdornments[part] = nil
			end
		end
		if Feat.RemoveSmoke then
			smokeWasOn = true
			smokeVisuals(smokes, true)
		elseif smokeWasOn then
			smokeWasOn = false
			smokeVisuals(smokes, false)
		end
	end

	-- trajectory pool
	local trajLines, trajLanding = {}, newFrame(gui)
	trajLanding.Size = UDim2.fromOffset(8, 8)
	create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = trajLanding })
	local warnLabel = newText(gui, 15)
	warnLabel.Position = UDim2.fromScale(0.5, 0.2)
	warnLabel.TextColor3 = Color3.fromRGB(255, 80, 80)

	local function trajectoryFilter()
		local list = { Workspace.Terrain }
		local map = Workspace:FindFirstChild("Map")
		for _, name in ipairs({ "Geometry", "Regen" }) do
			local f = map and map:FindFirstChild(name)
			if f then
				table.insert(list, f)
			end
		end
		local clips = map and map:FindFirstChild("Clips")
		local grenadeClips = clips and clips:FindFirstChild("GrenadeClips")
		if grenadeClips then
			table.insert(list, grenadeClips)
		end
		return list
	end

	-- returns up to ~90 predicted points from the current position and velocity
	local function predictPath(position, velocity, gravity)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = trajectoryFilter()
		params.IgnoreWater = false
		local dt = 1 / 60
		local p, v = position, velocity
		local pts = { p }
		local bounces = 0
		for i = 1, 270 do
			local step = v * dt
			local hit = if step.Magnitude > 1e-4 then Workspace:Raycast(p, step, params) else nil
			if hit then
				p = hit.Position + hit.Normal * 0.05
				v = bounceVelocity(v, hit.Normal)
				bounces = bounces + 1
				table.insert(pts, p)
				if bounces >= 4 then
					break
				end
			else
				p = p + step
			end
			if bounces >= 1 then
				v = v * math.exp(-0.25 * dt)
			end
			v = v + gravity * dt
			if i % 3 == 0 then
				table.insert(pts, p)
			end
			if #pts >= 90 then
				break
			end
		end
		return pts
	end

	local function grenadeVelocity(part, entry, now)
		local v2 = part:FindFirstChild("Velocity2")
		if v2 and v2:IsA("Vector3Value") then
			local v = v2.Value
			local hist = entry.History
			table.insert(hist, { T = now, V = v })
			while #hist > 2 and now - hist[1].T > 0.6 do
				table.remove(hist, 1)
			end
			-- gravity estimated from the velocity itself (ASSUMED constant between bounces); rejected when implausible
			for i = 1, #hist - 1 do
				local old = hist[i]
				if now - old.T >= 0.15 then
					local g = (v - old.V) / (now - old.T)
					if g.Y < -20 and g.Y > -600 and math.abs(g.X) < 15 and math.abs(g.Z) < 15 then
						entry.G = g
					end
					break
				end
			end
			return v
		end
		local prev = entry.Prev
		entry.Prev = { T = now, P = part.Position }
		if prev and now > prev.T then
			return (part.Position - prev.P) / (now - prev.T)
		end
		return nil
	end

	local function grenadeStep(cam, now)
		local wantLines = 0
		local nearest, nearestDist
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local lineBudget = 240
		for part, entry in pairs(grenades) do
			local name = entry.Name or grenadeNameOf(part) or "Grenade"
			entry.Name = name
			local dist = (part.Position - cam.CFrame.Position).Magnitude
			if Feat.GrenadeEsp then
				if not entry.Label then
					local bb = Instance.new("BillboardGui")
					bb.Adornee = part
					bb.AlwaysOnTop = true
					bb.Size = UDim2.fromOffset(150, 18)
					bb.StudsOffset = Vector3.new(0, 1.2, 0)
					bb.Parent = gui
					local t = Instance.new("TextLabel")
					t.BackgroundTransparency = 1
					t.Size = UDim2.fromScale(1, 1)
					t.Font = Enum.Font.GothamBold
					t.TextSize = 12
					t.TextColor3 = Color3.new(1, 1, 1)
					t.TextStrokeTransparency = 0.4
					t.Parent = bb
					entry.Label, entry.Text = bb, t
				end
				entry.Text.Text = string.format("%s  %.0fm", name, dist * STUDS_TO_METERS)
			elseif entry.Label then
				entry.Label:Destroy()
				entry.Label, entry.Text = nil, nil
			end
			if Feat.GrenadeFx then
				if not entry.Highlight then
					local h = Instance.new("Highlight")
					local visible = part
					if part.Transparency >= 1 then
						for _, c in ipairs(part:GetChildren()) do
							if c:IsA("BasePart") and c.Transparency < 1 then
								visible = c
								break
							end
						end
					end
					h.Adornee = visible
					h.FillTransparency = 0.45
					h.OutlineTransparency = 0
					h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					h.Parent = gui
					entry.Highlight = h
				end
				entry.Highlight.FillColor = Feat.GrenadeFxColor
				entry.Highlight.OutlineColor = Feat.GrenadeFxColor
			elseif entry.Highlight then
				entry.Highlight:Destroy()
				entry.Highlight = nil
			end
			-- proximity
			if Feat.Proximity and WARN_NAMES[name] and root then
				local d = (part.Position - root.Position).Magnitude
				if d <= WARN_RADIUS and (not nearestDist or d < nearestDist) then
					nearest, nearestDist = name, d
				end
				if d <= WARN_RADIUS and not entry.Warned then
					entry.Warned = true
					menu:Log(string.format("%s %.0fm away", name, d * STUDS_TO_METERS))
				end
			end
			-- trajectory (in-flight only)
			if Feat.Trajectory and not part:FindFirstChild("Stopped") then
				local v = grenadeVelocity(part, entry, now)
				if v and E.finite(v) and v.Magnitude > 2 then
					local pts = predictPath(part.Position, v, entry.G or Vector3.new(0, -Workspace.Gravity, 0))
					local prev
					for _, point in ipairs(pts) do
						local s = project(cam, point)
						if s and prev and wantLines < lineBudget then
							wantLines = wantLines + 1
							local f = trajLines[wantLines]
							if not f then
								f = newFrame(gui)
								trajLines[wantLines] = f
							end
							f.BackgroundColor3 = Feat.TrajColor
							placeLine(f, prev, s, Feat.TrajThickness)
						end
						prev = s
					end
					local landing = project(cam, pts[#pts])
					if landing then
						trajLanding.Position = UDim2.fromOffset(landing.X, landing.Y)
						trajLanding.BackgroundColor3 = Feat.TrajColor
						trajLanding.Visible = true
					end
				end
			end
		end
		for i = wantLines + 1, #trajLines do
			trajLines[i].Visible = false
		end
		if wantLines == 0 then
			trajLanding.Visible = false
		end
		if nearest then
			warnLabel.Text = string.format("! %s  %.0fm", nearest, nearestDist * STUDS_TO_METERS)
			warnLabel.Visible = true
		else
			warnLabel.Visible = false
		end
	end

	------------------------------------------------------------------
	-- Flash / fog removal.
	-- MEASURED (Blind module): the flash is PlayerGui.Blnd.Blind (its BackgroundTransparency is rewritten every frame) and a
	-- looping animation rbxassetid://105564828335809. Hiding Blind through Visible does not race with that rewrite.
	------------------------------------------------------------------
	local FLASH_ANIMATION = "rbxassetid://105564828335809"
	local flashHidden = false
	local function flashStep()
		local blnd = playerGui:FindFirstChild("Blnd")
		local overlay = blnd and blnd:FindFirstChild("Blind")
		if Feat.RemoveFlash then
			if overlay and overlay:IsA("GuiObject") then
				overlay.Visible = false
				flashHidden = true
			end
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
			if animator then
				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
					if track.Animation and track.Animation.AnimationId == FLASH_ANIMATION then
						track:Stop(0)
					end
				end
			end
		elseif flashHidden then
			flashHidden = false
			if overlay and overlay:IsA("GuiObject") then
				overlay.Visible = true
			end
		end
	end

	local fogSaved
	local function fogStep()
		local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		if Feat.RemoveFog then
			if not fogSaved then
				fogSaved = { Start = Lighting.FogStart, End = Lighting.FogEnd, Atmosphere = atmosphere, Density = atmosphere and atmosphere.Density, Haze = atmosphere and atmosphere.Haze }
			end
			Lighting.FogStart, Lighting.FogEnd = 1e5, 1e6
			if atmosphere then
				atmosphere.Density, atmosphere.Haze = 0, 0
			end
		elseif fogSaved then
			Lighting.FogStart, Lighting.FogEnd = fogSaved.Start, fogSaved.End
			if fogSaved.Atmosphere and fogSaved.Atmosphere.Parent then
				fogSaved.Atmosphere.Density, fogSaved.Atmosphere.Haze = fogSaved.Density, fogSaved.Haze
			end
			fogSaved = nil
		end
	end

	------------------------------------------------------------------
	-- Radar. Players only need the ESP adapter (team / alive). "Bomb" marks the bomb carrier through the same
	-- character.BackC4 check the ESP uses (ASSUMED visible on the carrier); a planted bomb is not measured.
	------------------------------------------------------------------
	local RADAR_SIZE, RADAR_RANGE = 160, 150 -- pixels, studs (ASSUMED, not configurable yet)
	local radarFrame = create("Frame", {
		Name = "Radar",
		Size = UDim2.fromOffset(RADAR_SIZE, RADAR_SIZE),
		Position = UDim2.fromOffset(20 + RADAR_SIZE / 2, 70 + RADAR_SIZE / 2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(10, 10, 16),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Visible = false,
		Parent = gui,
	}, {
		create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		create("UIStroke", { Color = Color3.fromRGB(60, 60, 80), Thickness = 1 }),
	})
	local radarSelf = newFrame(radarFrame, Color3.new(1, 1, 1))
	radarSelf.Size = UDim2.fromOffset(5, 5)
	radarSelf.Position = UDim2.fromScale(0.5, 0.5)
	radarSelf.Visible = true
	local radarDots = {}
	local function radarDot(i)
		local d = radarDots[i]
		if not d then
			d = newFrame(radarFrame)
			d.Size = UDim2.fromOffset(6, 6)
			create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = d })
			radarDots[i] = d
		end
		return d
	end
	local function radarStep(cam)
		local panelTransparency = 1 - Feat.PanelOpacity
		if radarFrame.BackgroundTransparency ~= panelTransparency then
			radarFrame.BackgroundTransparency = panelTransparency
		end
		local mode = Feat.Radar
		if #mode == 0 then
			radarFrame.Visible = false
			return
		end
		radarFrame.Visible = true
		local look = cam.CFrame.LookVector
		local forward = Vector3.new(look.X, 0, look.Z)
		if forward.Magnitude < 1e-3 then
			forward = Vector3.new(0, 0, -1)
		else
			forward = forward.Unit
		end
		local right = forward:Cross(Vector3.new(0, 1, 0)) -- right-handed, Y up
		local used = 0
		local half = RADAR_SIZE / 2
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= player then
				local character = plr.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if humanoid and root and Adapter.IsAlive(plr, humanoid) then
					local enemy = Adapter.IsEnemy(plr)
					local c4 = character:FindFirstChild("BackC4")
					local carrier = c4 and c4:IsA("BasePart") and c4.Transparency < 1
					local color
					if has(mode, "Bomb") and carrier then
						color = Color3.fromRGB(255, 210, 60)
					elseif enemy and has(mode, "Enemies") then
						color = Color3.fromRGB(240, 70, 70)
					elseif not enemy and has(mode, "Teammates") then
						color = Color3.fromRGB(80, 220, 120)
					end
					if color then
						used = used + 1
						local px, py = radarPoint(root.Position - cam.CFrame.Position, forward, right, RADAR_RANGE, half - 4)
						local d = radarDot(used)
						d.BackgroundColor3 = color
						d.Position = UDim2.fromOffset(half + px, half + py)
						d.Visible = true
					end
				end
			end
		end
		for i = used + 1, #radarDots do
			radarDots[i].Visible = false
		end
	end

	------------------------------------------------------------------
	-- Penetration indicator: re-runs the game's own wall rules (BulletCast) along the camera look and shows whether a
	-- bullet of the held weapon would get through. Only Map.Geometry / Map.Regen count as walls (MEASURED include list).
	-- ASSUMED: PenetrationPower = Weapons.<name>.Penetration (BulletCast.new defaults it to 100).
	------------------------------------------------------------------
	local penDot = newFrame(gui, Color3.fromRGB(94, 94, 247))
	penDot.Size = UDim2.fromOffset(6, 6)
	penDot.Position = UDim2.new(0.5, 0, 0.5, 0) -- exactly on the crosshair centre
	local penAt = 0
	local function heldWeaponPower()
		local character = player.Character
		local equipped = character and character:FindFirstChild("EquippedTool")
		local weapons = ReplicatedStorage:FindFirstChild("Weapons")
		local weapon = weapons and equipped and equipped:IsA("StringValue") and equipped.Value ~= "" and weapons:FindFirstChild(equipped.Value)
		local pen = weapon and weapon:FindFirstChild("Penetration")
		if pen and pen:IsA("ValueBase") and type(pen.Value) == "number" and pen.Value > 0 then
			return pen.Value
		end
		return nil -- no weapon, a knife / grenade (no Penetration value) or Penetration 0: the indicator has no meaning
	end
	-- returns nil (no wall under the crosshair), "pass" or "blocked", plus the wall count
	local function wallProbe(origin, look, power)
		local map = Workspace:FindFirstChild("Map")
		local geometry, regen = map and map:FindFirstChild("Geometry"), map and map:FindFirstChild("Regen")
		if not geometry then
			return nil
		end
		local character = player.Character
		local excluded = { Workspace.CurrentCamera }
		if character then
			table.insert(excluded, character)
		end
		local folder = Workspace.CurrentCamera and Workspace.CurrentCamera:FindFirstChild("NLFx")
		if folder then
			table.insert(excluded, folder)
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.IgnoreWater = true
		local exitParams = RaycastParams.new()
		exitParams.FilterType = Enum.RaycastFilterType.Include
		local remaining = look * 300
		local from = origin
		local falloff, walls = 1, 0
		for _ = 1, 10 do
			params.FilterDescendantsInstances = excluded
			local hit = Workspace:Raycast(from, remaining, params)
			if not hit then
				break
			end
			local inst = hit.Instance
			if E.LIMB_MODIFIER[inst.Name] then
				break -- reached a player part: the bullet got that far
			end
			local isWall = inst:IsDescendantOf(geometry) or (regen ~= nil and inst:IsDescendantOf(regen))
			if not isWall or (inst.Transparency == 1 and not inst:HasTag("Smoke")) then
				table.insert(excluded, inst)
			else
				if walls == 0 and math.abs(hit.Normal.Y) > 0.7 then
					return nil -- the first surface is a floor or ceiling, not a wall to shoot through
				end
				walls = walls + 1
				if inst.Name == "nowallbang" then
					return "blocked", walls
				end
				local u = remaining.Unit
				exitParams.FilterDescendantsInstances = { inst }
				local size = inst.Size.Magnitude
				local out = Workspace:Raycast(hit.Position + u * size, -u * size, exitParams)
				if not out then
					return "blocked", walls
				end
				local modifier = NAME_COST[inst.Name]
				if modifier == nil then
					modifier = MATERIAL_COST[inst.Material] or 0.75
				end
				local thickness = (hit.Position - out.Position).Magnitude
				falloff = falloff - wallCost(thickness, modifier, power)
				if falloff <= 0 then
					return "blocked", walls
				end
				table.insert(excluded, inst)
				from = hit.Position
				remaining = remaining - u * hit.Distance
			end
		end
		if walls == 0 then
			return nil
		end
		return "pass", walls, falloff
	end
	local penText = newText(gui, 11)
	penText.Size = UDim2.fromOffset(40, 12)
	penText.Position = UDim2.new(0.5, 24, 0.5, -12) -- right of the crosshair, a little above its centre
	local function penetrationStep(cam, now)
		if not Feat.Penetration then
			penDot.Visible, penText.Visible = false, false
			return
		end
		if now - penAt < 0.05 then
			return
		end
		penAt = now
		local power = heldWeaponPower()
		local state, _, left
		if power then
			state, _, left = wallProbe(cam.CFrame.Position, cam.CFrame.LookVector, power)
		end
		if state == nil then
			penDot.Visible, penText.Visible = false, false
			return
		end
		if state == "pass" then
			penDot.BackgroundColor3 = Feat.PenetrationColor
			penText.TextColor3 = Feat.PenetrationColor
			penText.Text = string.format("%d%%", math.floor(math.clamp(left or 0, 0, 1) * 100 + 0.5)) -- ASSUMED: damage scales with the remaining falloff
			penText.Visible = true
		else
			penDot.BackgroundColor3 = Color3.fromRGB(240, 60, 70)
			penText.Visible = false
		end
		penDot.Visible = true
	end

	------------------------------------------------------------------
	-- Movement helpers. MEASURED (ControlScript.MasterControl): AddToPlayerMovement(v) adds to the vector GetMoveVector()
	-- returns, SetIsJumping(true) queues one jump packet; Humanoid.Jump is ignored by the game's movement step.
	-- The governor keeps one offset on the move vector so it scales the player's own input and restores it when off.
	-- ASSUMED: the game's speed follows the move vector magnitude (analog scaling). Not verified in-game.
	------------------------------------------------------------------
	local masterControl
	local function getMasterControl()
		if masterControl then
			return masterControl
		end
		pcall(function()
			local scripts = player:FindFirstChild("PlayerScripts")
			local control = scripts and scripts:FindFirstChild("ControlScript")
			local module = control and control:FindFirstChild("MasterControl")
			local m = module and require(module)
			if type(m) == "table" and type(m.AddToPlayerMovement) == "function" and type(m.GetMoveVector) == "function" then
				masterControl = m
			end
		end)
		return masterControl
	end
	local move = { Applied = Vector3.zero, Char = nil, LastJump = 0 }
	local function moveRestore()
		local m = masterControl
		if m and move.Char and move.Char == player.Character and move.Applied.Magnitude > 0 then
			pcall(m.AddToPlayerMovement, m, -move.Applied)
		end
		move.Applied, move.Char = Vector3.zero, nil
	end

	local moveParams = RaycastParams.new()
	moveParams.FilterType = Enum.RaycastFilterType.Exclude
	moveParams.IgnoreWater = true
	-- ASSUMED drop of 3 studs below the feet counts as an edge; ahead distance scales with speed
	local function edgeAhead(character, humanoid, root, planar)
		local ahead = planar.Unit * math.clamp(planar.Magnitude * 0.08, 1, 3.5)
		moveParams.FilterDescendantsInstances = { character, Workspace.CurrentCamera }
		local depth = humanoid.HipHeight + root.Size.Y / 2 + 3
		return Workspace:Raycast(root.Position + ahead, Vector3.new(0, -depth, 0), moveParams) == nil
	end

	local peek = { Start = nil, Returning = false }
	local function peekStep(character, humanoid, root, planar, dt)
		if not Feat.PeekAssist then
			peek.Start, peek.Returning = nil, false
			return
		end
		if not peek.Start then
			peek.Start = root.Position
		end
		local toStart = peek.Start - root.Position
		local flat = Vector3.new(toStart.X, 0, toStart.Z)
		local maxStuds = Feat.PeekMax / STUDS_TO_METERS
		local mode = Feat.PeekRetreat
		if mode ~= "Off" then
			local standing = planar.Magnitude < 1
			if os.clock() - peekShotAt < 0.1 and (mode == "Always" or standing) then
				peek.Returning = true
			end
			if flat.Magnitude > maxStuds then
				peek.Returning = true
			end
			if flat.Magnitude < 1.5 then
				peek.Returning = false
			end
		else
			peek.Returning = false
		end
		if peek.Returning and flat.Magnitude > 0.05 then
			local step = flat.Unit * math.min(flat.Magnitude, 24 * dt)
			moveParams.FilterDescendantsInstances = { character, Workspace.CurrentCamera }
			local margin = 1.2
			local hit = Workspace:Raycast(root.Position, step.Unit * (step.Magnitude + margin), moveParams)
			if hit then
				local room = hit.Distance - margin
				if room <= 0 then
					return
				end
				step = step.Unit * math.min(step.Magnitude, room)
			end
			root.CFrame = root.CFrame + step
		end
	end
	local peekRing = newFrame(gui)
	peekRing.Size = UDim2.fromOffset(16, 16)
	peekRing.BackgroundTransparency = 1
	create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = peekRing })
	local peekStroke = create("UIStroke", { Thickness = 2, Color = Color3.fromRGB(240, 60, 70), Parent = peekRing })
	local function peekDraw(cam)
		if peek.Start and Feat.PeekAssist then
			local s = project(cam, peek.Start)
			if s then
				peekRing.Position = UDim2.fromOffset(s.X, s.Y)
				peekStroke.Color = Feat.PeekColor
				peekRing.Visible = true
				return
			end
		end
		peekRing.Visible = false
	end

	local gatedMove = false
	local function moveStep(dt)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart
		if not humanoid or not root or humanoid.Health <= 0 then
			move.Applied, move.Char = Vector3.zero, nil
			peek.Start, peek.Returning = nil, false
			return
		end
		local vel = root.AssemblyLinearVelocity
		local planar = Vector3.new(vel.X, 0, vel.Z)
		guard("peek", peekStep, character, humanoid, root, planar, dt)

		local wantsMove = Feat.SlowWalk or Feat.StandaloneQuickStop or Feat.EdgeQuickStop or Feat.EdgeJump
		if not wantsMove then
			if move.Applied.Magnitude > 0 then
				moveRestore()
			end
			return
		end
		local m = getMasterControl()
		if not m then
			if not gatedMove then
				gatedMove = true
				Feat.gate("Movement helpers", "ControlScript.MasterControl is not reachable from this script")
			end
			return
		end
		if move.Char ~= character then
			move.Applied, move.Char = Vector3.zero, character
		end
		local factor = 1
		if Feat.SlowWalk then
			factor = math.min(factor, Feat.SlowWalkSpeed)
		end
		local firing = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
			and not menu._visible and UserInputService:GetFocusedTextBox() == nil
		if Feat.StandaloneQuickStop and firing then
			factor = 0
		end
		local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
		if (Feat.EdgeQuickStop or Feat.EdgeJump) and grounded and planar.Magnitude > 2 then
			local edge = edgeAhead(character, humanoid, root, planar)
			if edge then
				local now = os.clock()
				if Feat.EdgeJump then
					if now - move.LastJump > 0.3 then
						move.LastJump = now
						pcall(m.SetIsJumping, m, true)
					end
				elseif Feat.EdgeQuickStop then
					factor = 0
				end
			end
		end
		local ok, current = pcall(m.GetMoveVector, m)
		if not ok or typeof(current) ~= "Vector3" then
			return
		end
		local raw = current - move.Applied
		local target = raw * (factor - 1)
		local delta = target - move.Applied
		if delta.Magnitude > 1e-4 then
			pcall(m.AddToPlayerMovement, m, delta)
			move.Applied = target
		end
	end

	------------------------------------------------------------------
	-- Session stats, speedometer and hitboxes.
	-- Stats: MEASURED player attributes (spectate_diff / probe): Kills, Deaths, Assists, Headshots, TotalDamage (this round),
	-- GameTotalDamage (whole game). ASSUMED: Headshots counts headshot kills (it rose together with Kills in the recording).
	-- Speed: the planar part of root.AssemblyLinearVelocity, studs per second (no game data needed).
	-- Hitboxes: the limb parts of BulletCast's limb table (names MEASURED), drawn as AlwaysOnTop BoxHandleAdornments.
	------------------------------------------------------------------
	local function statNumber(v)
		return if type(v) == "number" and v == v then math.floor(v) else nil
	end
	local function statsText(kills, deaths, assists, heads, roundDamage, gameDamage)
		local function show(v)
			return if v then tostring(v) else "-"
		end
		local ratio = "-"
		if kills and deaths then
			ratio = if deaths > 0 then string.format("%.2f", kills / deaths) else tostring(kills)
		end
		local headPercent = ""
		if heads and kills and kills > 0 then
			headPercent = string.format("  (%d%%)", math.floor(heads / kills * 100 + 0.5))
		end
		return table.concat({
			"K / D / A    " .. show(kills) .. " / " .. show(deaths) .. " / " .. show(assists),
			"K/D          " .. ratio,
			"HS kills     " .. show(heads) .. headPercent,
			"Damage       round " .. show(roundDamage) .. "  |  game " .. show(gameDamage),
		}, "\n")
	end

	local statsLabel = newText(gui, 13)
	statsLabel.Size = UDim2.fromOffset(230, 70)
	statsLabel.AnchorPoint = Vector2.new(0, 0)
	statsLabel.Position = UDim2.fromOffset(20, 250)
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.TextYAlignment = Enum.TextYAlignment.Top
	statsLabel.BackgroundTransparency = 0.45
	statsLabel.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
	local speedLabel = newText(gui, 17)
	speedLabel.Size = UDim2.fromOffset(240, 44)
	speedLabel.Position = UDim2.new(0.5, 0, 1, -150)
	speedLabel.TextYAlignment = Enum.TextYAlignment.Top

	-- jumps in a row: a takeoff counts as a jump when the root leaves the floor going up; the chain breaks after 0.3 s on the floor
	local jumpState = { Chain = 0, WasOnFloor = true, LandedAt = 0, TakeoffSpeed = 0 }
	local hudAt = 0
	local function hudStep(now)
		local panelTransparency = 1 - Feat.PanelOpacity
		if statsLabel.BackgroundTransparency ~= panelTransparency then
			statsLabel.BackgroundTransparency = panelTransparency
		end
		statsLabel.Visible = Feat.SessionStats
		speedLabel.Visible = Feat.Speedometer
		if Feat.SessionStats and now - hudAt >= 0.25 then
			hudAt = now
			statsLabel.Text = statsText(
				statNumber(player:GetAttribute("Kills")),
				statNumber(player:GetAttribute("Deaths")),
				statNumber(player:GetAttribute("Assists")),
				statNumber(player:GetAttribute("Headshots")),
				statNumber(player:GetAttribute("TotalDamage")),
				statNumber(player:GetAttribute("GameTotalDamage"))
			)
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart
		if not root then
			return
		end
		local vel = root.AssemblyLinearVelocity
		local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
		local onFloor = humanoid.FloorMaterial ~= Enum.Material.Air
		if jumpState.WasOnFloor and not onFloor and vel.Y > 8 then
			jumpState.Chain = if now - jumpState.LandedAt < 0.3 then jumpState.Chain + 1 else 1
			jumpState.TakeoffSpeed = speed
		end
		if not jumpState.WasOnFloor and onFloor then
			jumpState.LandedAt = now
		end
		jumpState.WasOnFloor = onFloor
		if onFloor and now - jumpState.LandedAt > 1 then
			jumpState.Chain = 0
		end
		if Feat.Speedometer then
			speedLabel.Text = string.format("SPEED  %.1f\nJUMPS  %d    LAST  %.1f", speed, jumpState.Chain, jumpState.TakeoffSpeed)
		end
	end

	local HITBOX_PARTS = {
		"HeadHB", "UpperTorso", "LowerTorso", "RightUpperArm", "LeftUpperArm", "RightLowerArm", "LeftLowerArm",
		"RightHand", "LeftHand", "RightUpperLeg", "LeftUpperLeg", "RightLowerLeg", "LeftLowerLeg", "RightFoot", "LeftFoot",
	}
	local hitboxSets = {} -- [Player] = { [partName] = BoxHandleAdornment }
	local function hitboxStep()
		local alive = {}
		if Feat.Hitboxes then
			for _, plr in ipairs(Players:GetPlayers()) do
				local character = plr.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if plr ~= player and humanoid and Adapter.IsEnemy(plr) and Adapter.IsAlive(plr, humanoid) then
					alive[plr] = true
					local set = hitboxSets[plr]
					if not set then
						set = {}
						hitboxSets[plr] = set
					end
					for _, name in ipairs(HITBOX_PARTS) do
						local part = character:FindFirstChild(name)
						local a = set[name]
						if part and part:IsA("BasePart") then
							if not a or a.Parent == nil then
								a = Instance.new("BoxHandleAdornment")
								a.Name = "NLHitbox"
								a.AlwaysOnTop = true
								a.ZIndex = 2
								a.Parent = gui
								set[name] = a
							end
							a.Adornee = part
							a.Size = part.Size
							a.Color3 = if name == "HeadHB" then Color3.fromRGB(255, 70, 70) else Feat.HitboxColor
							a.Transparency = 0.7
							a.Visible = true
						elseif a then
							a.Visible = false
						end
					end
				end
			end
		end
		for plr, set in pairs(hitboxSets) do
			if not alive[plr] then
				for _, a in pairs(set) do
					a:Destroy()
				end
				hitboxSets[plr] = nil
			end
		end
	end

	------------------------------------------------------------------
	-- Shoot Sound. MEASURED (Modules.Sound): the game plays every sound through Sound.playsound, which clones
	-- ReplicatedStorage.Sound, names the clone "<Name>Playing", puts it next to its source value (or on a part of the shooter),
	-- applies Volume * ReplicatedStorage.GeneralVolume.Value, routes it through SoundService.Sounds and calls :Play(). The gun's
	-- own sounds are named "Shoot", "SShoot" (silenced) or "Shoot...", so their clones are "ShootPlaying" / "SShootPlaying".
	-- ASSUMED: another player's shot sits inside that player's character model (their gun part is a child of it), so a clone
	-- that is not inside another player's character is ours. Muting happens after the game started the clone (a clone is seen
	-- through DescendantAdded, which may be deferred), so a click-length leak of the original is possible.
	-- Custom sounds: the game's own Hit1..Hit6 / Damage ids (MEASURED in ReplicatedStorage.Sounds) and every .mp3 / .ogg in
	-- <executor workspace>/NeverloseBloxStrike/sounds (needs getcustomasset).
	------------------------------------------------------------------
	local function isShootName(name)
		return name == "SShootPlaying" or (string.sub(name, 1, 5) == "Shoot" and string.sub(name, -7) == "Playing")
	end
	local function belongsToOtherPlayer(sound)
		local model = sound:FindFirstAncestorOfClass("Model")
		local owner = model and Players:GetPlayerFromCharacter(model)
		return owner ~= nil and owner ~= player
	end

	local customAssets = {}
	local function shootSoundId(name)
		local builtin = HIT_SOUNDS[name]
		if builtin then
			return builtin
		end
		local path = Feat.ShootSoundFiles[name]
		if not path then
			return nil
		end
		local cached = customAssets[path]
		if cached == nil then
			local ok, asset = pcall(function()
				return getcustomasset(path)
			end)
			cached = if ok and type(asset) == "string" and asset ~= "" then asset else false
			customAssets[path] = cached
			if cached == false then
				Feat.gate("Custom shoot sound files", "getcustomasset is not available in this executor")
			end
		end
		return cached or nil
	end
	-- one place that plays a sound by its menu name (game ids or a file of the sounds folder); the hit and shoot sounds share it
	local function playSoundNamed(name, volume)
		local id = shootSoundId(name)
		if not id then
			return
		end
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Volume = volume -- independent of Game Volume: no GeneralVolume factor and no game sound group
		s.Parent = SoundService
		s:Play()
		Debris:AddItem(s, 10)
	end
	Feat.PlaySound = playSoundNamed
	local function playShootSound()
		playSoundNamed(Feat.ShootSoundName, Feat.ShootSoundVolume)
	end
	Feat.PreviewShootSound = playShootSound -- called by the menu when a sound is picked
	Feat.PreviewHitSound = function()
		playSoundNamed(Feat.HitSoundName, Feat.HitSoundVolume)
	end

	local lastShootSound = 0
	local function replaceShootSound(sound)
		sound.Volume = 0
		sound:Stop()
		local now = os.clock()
		if now - lastShootSound > 0.03 then -- one custom sound per shot even when the gun layers several sounds
			lastShootSound = now
			playShootSound()
		end
	end
	-- only OUR shots are replaced. A clone sitting inside our character or the camera (the first-person gun) is ours; any other
	-- clone counts only when we really fired a moment ago (the BulletHitreg call, Feat.LastShotAt), so a shot of somebody else
	-- or a sound the game plays on its own is left alone.
	local function recentlyFired()
		return os.clock() - (Feat.LastShotAt or -10) < 0.3
	end
	local function handleShootSound(sound)
		if not Feat.ShootSound or not isShootName(sound.Name) or belongsToOtherPlayer(sound) then
			return
		end
		local camera = Workspace.CurrentCamera
		local character = player.Character
		if (character and sound:IsDescendantOf(character)) or (camera and sound:IsDescendantOf(camera)) or recentlyFired() then
			replaceShootSound(sound)
			return
		end
		task.defer(function() -- the shot call can come a moment after the sound starts
			if sound.Parent and recentlyFired() then
				replaceShootSound(sound)
			end
		end)
	end
	local function watchSound(sound)
		if not sound:IsA("Sound") then
			return
		end
		table.insert(connections, sound.Played:Connect(function()
			guard("shoot sound", handleShootSound, sound)
		end))
		if sound.Playing then
			guard("shoot sound", handleShootSound, sound) -- already started: DescendantAdded was deferred past :Play()
		end
	end
	for _, root in ipairs({ Workspace, SoundService, playerGui }) do
		table.insert(connections, root.DescendantAdded:Connect(watchSound))
	end

	------------------------------------------------------------------
	-- Game Volume. MEASURED: ReplicatedStorage.GeneralVolume (a NumberValue, 1 in the dump) is the game's own volume factor:
	-- Modules.Sound multiplies every sound it plays by it, and the footstep, HE deafening, underwater and infection scripts read
	-- it too. Changing it on the client only changes what the game plays from then on, so sounds that already run (music,
	-- loops) are rescaled here as well. The sounds this script plays (Hit Sound, Shoot Sound, previews) use their own volume
	-- and are not touched. 100% means "leave the game's value alone"; moving away from it remembers the game's value and
	-- going back to 100% (or Unload) puts it back. ASSUMED: the game does not clamp or rewrite GeneralVolume often (if it
	-- does, the slider's value is written back).
	------------------------------------------------------------------
	local gameVolume = { Target = nil, Original = nil, Value = nil, Token = 0, PendingFrom = nil }
	local function generalVolumeValue()
		local v = ReplicatedStorage:FindFirstChild("GeneralVolume")
		return if v and v:IsA("NumberValue") then v else nil
	end
	-- sounds the game started through Sound.playsound are named "<Name>Playing"; their volume is base * factor
	local function rescaleRunningSounds(before, after)
		for _, root in ipairs({ SoundService, playerGui }) do
			for _, d in ipairs(root:GetDescendants()) do
				if d:IsA("Sound") and d.Playing and string.sub(d.Name, -7) == "Playing" then
					local base = d:GetAttribute("NLBaseVolume")
					if type(base) ~= "number" and before > 1e-4 then
						base = d.Volume / before
						d:SetAttribute("NLBaseVolume", base)
					end
					if type(base) == "number" then
						d.Volume = base * after
					end
				end
			end
		end
	end
	local function applyGameVolume()
		local v = generalVolumeValue()
		if not v then
			return
		end
		if gameVolume.Value ~= v then
			gameVolume.Value = v
			table.insert(connections, v:GetPropertyChangedSignal("Value"):Connect(function()
				local want = gameVolume.Target
				if want ~= nil and math.abs(v.Value - want) > 1e-4 then
					v.Value = want -- the game rewrote its factor: keep the slider's value
				end
			end))
		end
		local want = gameVolume.Target
		if want == nil then
			if gameVolume.Original ~= nil then
				v.Value = gameVolume.Original
				gameVolume.Original = nil
			end
		else
			if gameVolume.Original == nil then
				gameVolume.Original = v.Value
			end
			if math.abs(v.Value - want) > 1e-4 then
				v.Value = want
			end
		end
	end
	local function setGameVolume(percent)
		local v = generalVolumeValue()
		local before = if v then v.Value else nil
		gameVolume.Target = if percent >= 100 then nil else math.clamp(percent, 0, 100) / 100
		applyGameVolume()
		if v and before then
			gameVolume.PendingFrom = gameVolume.PendingFrom or before
			gameVolume.Token += 1
			local token = gameVolume.Token
			task.delay(0.15, function() -- the slider sends a value per pixel; rescale once it settles
				if token == gameVolume.Token and gameVolume.PendingFrom then
					local from = gameVolume.PendingFrom
					gameVolume.PendingFrom = nil
					guard("game volume", rescaleRunningSounds, from, v.Value)
				end
			end)
		end
	end
	Feat.SetGameVolume = setGameVolume
	if Feat.GameVolumeRaw then
		setGameVolume(Feat.GameVolumeRaw) -- the slider was already set (saved config) before this block existed
	end
	table.insert(Unloaders, function()
		gameVolume.Target = nil
		pcall(applyGameVolume)
	end)

	------------------------------------------------------------------
	-- Indicators: small pills pressed against the left screen edge, vertically centred (HC / minimum damage / SLOW ...), in the
	-- style of the Event Logs pills. They fade and pop in when they turn on, fade out when they turn off, and cast a crisp
	-- shadow. Hit Chance and Min Damage show while a hotkey bound to a row of that name (Rage or Legit) is active, and the
	-- Min Damage pill carries that row's current value; SLOW shows while Slow Walk is on. Double Tap, Duck Peek Assist and
	-- Jump Bug have no feature behind them yet, so their pills never show.
	------------------------------------------------------------------
	local INDICATOR_RED = Color3.fromRGB(240, 66, 78)
	local READY_GREEN = { Dark = Color3.fromRGB(96, 226, 140), Light = Color3.fromRGB(26, 160, 84) }
	local indicatorBlocked = false -- true while shooting is not possible (see shootingBlocked below)

	-- Icons are drawn straight on a 26 px grid out of rounded frames and strokes (UICorner / UIStroke are anti-aliased, so there
	-- are no scaled-up pixels). Every shape is registered in `parts` so the theme can recolour it: Fills use the icon colour,
	-- Strokes the icon colour as stroke, Cuts are holes (eyes, teeth) that take the pill's own colour.
	local function disc(parent, parts, x, y, d, isCut)
		local f = create("Frame", {
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(d, d),
			BorderSizePixel = 0,
			Parent = parent,
		}, { corner(math.ceil(d / 2)) })
		table.insert(if isCut then parts.Cuts else parts.Fills, f)
	end
	local function outlined(parent, parts, x, y, w, h, radius, thick)
		local s = stroke(Color3.new(1, 1, 1), thick)
		create("Frame", {
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			BackgroundTransparency = 1,
			Parent = parent,
		}, { corner(radius), s })
		table.insert(parts.Strokes, s)
	end
	-- a rounded bar centred on (cx, cy); rot turns it clockwise (degrees), the bar is w wide and h tall before turning
	local function bar(parent, parts, cx, cy, w, h, rot, isCut)
		local f = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(cx, cy),
			Size = UDim2.fromOffset(w, h),
			Rotation = rot or 0,
			BorderSizePixel = 0,
			Parent = parent,
		}, { corner(math.ceil(math.min(w, h) / 2)) })
		table.insert(if isCut then parts.Cuts else parts.Fills, f)
	end

	-- an outlined skull (the look of the first version) with more detail: round cranium, jaw with tooth dividers, deep eye
	-- sockets, a nose, and two small cheekbone marks
	local function skullIcon(slot, parts)
		outlined(slot, parts, 3, 0.5, 20, 20, 10, 2.2) -- cranium
		outlined(slot, parts, 7, 16, 12, 8.5, 3.5, 2.2) -- jaw (it overlaps the cranium's lower edge, like a real chin line)
		disc(slot, parts, 6.8, 8, 5.6) -- eye sockets
		disc(slot, parts, 13.6, 8, 5.6)
		bar(slot, parts, 13, 14.3, 3, 3, 45) -- nose
		bar(slot, parts, 11, 21, 1.5, 4) -- tooth dividers
		bar(slot, parts, 15, 21, 1.5, 4)
		bar(slot, parts, 4.6, 14.2, 2.2, 3.4, -20) -- cheekbone marks
		bar(slot, parts, 21.4, 14.2, 2.2, 3.4, 20)
	end
	local function crosshairIcon(slot, parts)
		outlined(slot, parts, 5, 5, 16, 16, 8, 2.2)
		disc(slot, parts, 11, 11, 4)
		bar(slot, parts, 13, 2.5, 2.4, 5)
		bar(slot, parts, 13, 23.5, 2.4, 5)
		bar(slot, parts, 2.5, 13, 5, 2.4)
		bar(slot, parts, 23.5, 13, 5, 2.4)
	end
	local function runnerIcon(slot, parts)
		disc(slot, parts, 14.5, 1.5, 6) -- head
		bar(slot, parts, 12.5, 11, 3.2, 11, 18) -- torso, leaning forward
		bar(slot, parts, 8, 9.5, 2.8, 7.5, 50) -- back arm
		bar(slot, parts, 17.5, 10.5, 2.8, 7.5, -50) -- front arm
		bar(slot, parts, 8.5, 19.5, 3, 9, 35) -- back leg
		bar(slot, parts, 16.5, 19, 3, 9, -25) -- front leg
	end
	local function doubleTapIcon(slot, parts)
		for _, dx in ipairs({ 0, 8 }) do -- two chevrons, fast-forward style
			bar(slot, parts, 7 + dx, 8.5, 3, 11, -41)
			bar(slot, parts, 7 + dx, 17.5, 3, 11, 41)
		end
	end
	local function duckIcon(slot, parts)
		disc(slot, parts, 9, 1.5, 8) -- head
		bar(slot, parts, 13, 17, 14, 9) -- shoulders / crouched body
		bar(slot, parts, 13, 23.5, 8, 2.6)
	end
	local function jumpIcon(slot, parts)
		bar(slot, parts, 13, 12, 3, 15) -- shaft
		bar(slot, parts, 9.4, 6.5, 3, 9, 45) -- arrow head
		bar(slot, parts, 16.6, 6.5, 3, 9, -45)
		bar(slot, parts, 13, 23, 14, 2.6) -- ground
	end

	-- Neutral pills use the menu's text colour (dark on the light theme). Stateful pills (HC, Double Tap, Jump Bug) are green
	-- while you can shoot and red while you cannot (just shot, reloading, equipping).
	local INDICATORS = {
		{ Id = "HitChance", Flag = "IndHC", Stateful = true, Draw = crosshairIcon },
		{ Id = "MinDamage", Flag = "IndMD", Neutral = true, Draw = skullIcon },
		{ Id = "DoubleTap", Flag = "IndDT", Stateful = true, Draw = doubleTapIcon },
		{ Id = "DuckPeek", Flag = "IndDuck", Neutral = true, Draw = duckIcon },
		{ Id = "Slowdown", Flag = "IndSlow", Neutral = true, Draw = runnerIcon },
		{ Id = "JumpBug", Flag = "IndJump", Stateful = true, Draw = jumpIcon },
	}

	-- A crisp shadow behind every pill: the menu's shadow (layered rounded frames, same alpha curve) but wider and stronger.
	-- The frames live in their own layer under the pills and follow each pill's position, size, scale and fade.
	local SHADOW_STEP_PX, SHADOW_STRENGTH = 3, 0.85
	local indicatorShadowAlphas = shadowAlphas(SHADOW_STRENGTH)
	local shadowLayer = create("Frame", {
		Name = "IndicatorShadows",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local indicatorHost = create("Frame", {
		Name = "Indicators",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0), -- a little away from the wall
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { list(8) })
	for order, def in ipairs(INDICATORS) do
		-- a CanvasGroup, so one GroupTransparency fades background, rim, icon and text together
		local pill = create("CanvasGroup", {
			Name = def.Id,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 38),
			BackgroundColor3 = Color3.fromRGB(10, 10, 15),
			BackgroundTransparency = 0.6,
			GroupTransparency = 1,
			LayoutOrder = order,
			Visible = false,
			Parent = indicatorHost,
		}, { corner(19), litStroke(), list(10, true), padding(0, 18, 0, 14) })
		-- the accent line: a rounded capsule whose ends fade out
		def.Bar = create("Frame", {
			Name = "Bar",
			Size = UDim2.fromOffset(4, 22),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			LayoutOrder = 1,
			Parent = pill,
		}, {
			corner(2),
			create("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.55),
					NumberSequenceKeypoint.new(0.5, 0),
					NumberSequenceKeypoint.new(1, 0.55),
				}),
			}),
		})
		local slot = create("Frame", { Name = "IconSlot", Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1, LayoutOrder = 2, Parent = pill })
		def.Parts = { Fills = {}, Strokes = {}, Cuts = {} }
		def.Draw(slot, def.Parts)
		def.Stroke = pill:FindFirstChildOfClass("UIStroke")
		def.Stroke.Transparency = 0.55 -- a faint rim, not a hard outline
		def.Gradient = def.Stroke:FindFirstChildOfClass("UIGradient")
		def.Label = textLabel({
			Name = "Text",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 24),
			FontFace = Theme.FontBold,
			TextSize = 20,
			LayoutOrder = 3,
			Text = "",
			Parent = pill,
		})
		def.Scale = create("UIScale", { Scale = 1, Parent = pill })
		def.Pill = pill
		def.Shadow = {}
		for i = 1, #indicatorShadowAlphas do
			def.Shadow[i] = create("Frame", {
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Visible = false,
				Parent = shadowLayer,
			}, { corner(19 + i * SHADOW_STEP_PX) })
		end
		local function updateShadow()
			local rel = pill.AbsolutePosition - shadowLayer.AbsolutePosition
			local size = pill.AbsoluteSize
			local seen = 1 - pill.GroupTransparency
			for i, f in ipairs(def.Shadow) do
				local o = i * SHADOW_STEP_PX
				f.Position = UDim2.fromOffset(rel.X - o, rel.Y - o)
				f.Size = UDim2.fromOffset(size.X + o * 2, size.Y + o * 2)
				f.BackgroundTransparency = 1 - indicatorShadowAlphas[i] * seen
				f.Visible = pill.Visible
			end
		end
		for _, prop in ipairs({ "AbsolutePosition", "AbsoluteSize", "Visible", "GroupTransparency" }) do
			table.insert(connections, pill:GetPropertyChangedSignal(prop):Connect(updateShadow))
		end
	end

	-- The pills follow the menu theme (Dark / Light, the same palettes and shadow colour the menu uses) and the shooting state.
	local indicatorMode, indicatorVersion, indicatorOpacity
	local function setProps(object, props, instant)
		if instant then
			for key, value in pairs(props) do
				object[key] = value
			end
		else
			tween(object, props, 0.2)
		end
	end
	local function indicatorColor(def)
		local palette = Theme
		if def.Neutral then
			return palette.Text
		end
		if indicatorBlocked then
			return INDICATOR_RED
		end
		return READY_GREEN[indicatorMode] or READY_GREEN.Dark
	end
	-- the colour of the line, icon and text of one pill
	local function paintIndicator(def, instant)
		local color = indicatorColor(def)
		setProps(def.Bar, { BackgroundColor3 = color }, instant)
		setProps(def.Label, { TextColor3 = color }, instant)
		for _, f in ipairs(def.Parts.Fills) do
			setProps(f, { BackgroundColor3 = color }, instant)
		end
		for _, s in ipairs(def.Parts.Strokes) do
			setProps(s, { Color = color }, instant)
		end
	end
	local function applyIndicatorTheme(mode, instant)
		indicatorMode = mode
		local palette = Theme -- the live palette: it carries a custom menu colour too
		local light = mode == "Light"
		local background = palette.Pill
		local backgroundAlpha = 1 - Feat.IndicatorOpacity
		for _, def in ipairs(INDICATORS) do
			setProps(def.Pill, { BackgroundColor3 = background, BackgroundTransparency = backgroundAlpha }, instant)
			paintIndicator(def, instant)
			for _, f in ipairs(def.Parts.Cuts) do
				setProps(f, { BackgroundColor3 = background }, instant)
			end
			def.Gradient.Color = ColorSequence.new(palette.LitTop, palette.LitBottom)
			for _, f in ipairs(def.Shadow) do
				setProps(f, { BackgroundColor3 = menu._shadowColor or SHADOW_COLORS[mode] or Color3.new(0, 0, 0) }, instant)
			end
		end
	end
	applyIndicatorTheme(menu.ThemeMode or "Dark", true)

	-- appear: fade in while popping up from 80% with a small overshoot; disappear: fade out while shrinking to 85%
	local function setIndicatorShown(def, show)
		if def.Shown == show then
			return
		end
		def.Shown = show
		def.Token = (def.Token or 0) + 1
		local token = def.Token
		local pill = def.Pill
		if show then
			if not pill.Visible then
				pill.GroupTransparency = 1
				def.Scale.Scale = 0.8
				pill.Visible = true
			end
			TweenService:Create(pill, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { GroupTransparency = 0 }):Play()
			TweenService:Create(def.Scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		else
			TweenService:Create(pill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1 }):Play()
			TweenService:Create(def.Scale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.85 }):Play()
			task.delay(0.22, function()
				if def.Token == token and not def.Shown then
					pill.Visible = false
				end
			end)
		end
	end
	-- the value changed while the pill is up: a short pulse
	local function pulseIndicator(def)
		def.Scale.Scale = 1.1
		TweenService:Create(def.Scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end

	-- "Can I shoot right now?" for the stateful pills. Blocked for FireRate seconds after a shot, while a reload runs and while
	-- the weapon is being equipped. MEASURED: Weapons.<tool>.FireRate / ReloadTime / EquipTime (the dump), the game's
	-- ReplicateReload remote (shots.txt: FireServer when you reload), the shot itself through the BulletHitreg hook.
	-- ASSUMED: ReplicateReload is sent when a reload starts; a missing ReloadTime counts as 2 s; a shot always blocks for at
	-- least 0.12 s so the red flash is visible on fast weapons.
	local function cannotShoot(now, lastShot, fireRate, reloadStart, reloadTime, equipUntil)
		if lastShot and now - lastShot < math.max(fireRate or 0, 0.12) then
			return true
		end
		if reloadStart and now - reloadStart < (reloadTime or 2) then
			return true
		end
		if equipUntil and now < equipUntil then
			return true
		end
		return false
	end
	local weaponStatCache = {}
	local function weaponStats(name)
		local cached = weaponStatCache[name]
		if cached then
			return cached
		end
		local weapons = ReplicatedStorage:FindFirstChild("Weapons")
		local weapon = weapons and weapons:FindFirstChild(name)
		if not weapon then
			return nil -- not cached: the folder may load later
		end
		local function stat(key)
			local v = weapon:FindFirstChild(key)
			return if v and v:IsA("ValueBase") and type(v.Value) == "number" then v.Value else nil
		end
		cached = { FireRate = stat("FireRate"), ReloadTime = stat("ReloadTime"), EquipTime = stat("EquipTime") }
		weaponStatCache[name] = cached
		return cached
	end
	local reloadStartedAt, equipUntil, lastToolName
	Feat.OnReload = function()
		reloadStartedAt = os.clock()
	end
	local function shootingBlocked(now)
		local character = player.Character
		local equipped = character and character:FindFirstChild("EquippedTool")
		local name = if equipped and equipped:IsA("StringValue") and equipped.Value ~= "" then equipped.Value else nil
		local stats = name and weaponStats(name)
		if name ~= lastToolName then
			lastToolName = name
			reloadStartedAt = nil -- switching cancels a reload
			equipUntil = if stats and stats.EquipTime then now + stats.EquipTime else nil
		end
		return cannotShoot(now, peekShotAt, stats and stats.FireRate, reloadStartedAt, stats and stats.ReloadTime, equipUntil)
	end

	-- the element entry of a row with this name that has an active hotkey, or nil
	local function activeBind(name)
		for _, b in ipairs(menu._binds or {}) do
			if b.Active then
				local entry = menu._elements[b.ElementKey]
				if entry and entry.Name == name then
					return entry
				end
			end
		end
		return nil
	end
	local indicatorAt = 0
	local function indicatorStep(now)
		if now - indicatorAt < 0.1 then
			return
		end
		indicatorAt = now
		if menu.ThemeMode ~= indicatorMode or menu._themeVersion ~= indicatorVersion or Feat.IndicatorOpacity ~= indicatorOpacity then
			indicatorOpacity = Feat.IndicatorOpacity
			indicatorVersion = menu._themeVersion
			applyIndicatorTheme(menu.ThemeMode or "Dark", false) -- the menu theme or its colours changed
		end
		local blocked = shootingBlocked(now)
		if blocked ~= indicatorBlocked then
			indicatorBlocked = blocked
			for _, def in ipairs(INDICATORS) do
				if def.Stateful then
					paintIndicator(def, false) -- green <-> red
				end
			end
		end
		for _, def in ipairs(INDICATORS) do
			local show, text = false, ""
			if Feat[def.Flag] then
				if def.Id == "HitChance" then
					if activeBind("Hit Chance") then
						show, text = true, "HC"
					end
				elseif def.Id == "MinDamage" then
					local entry = activeBind("Min Damage")
					if entry then
						local ok, value = pcall(menu._valueOf, menu, entry)
						show, text = true, if ok and type(value) == "number" then tostring(math.floor(value + 0.5)) else "MD"
					end
				elseif def.Id == "Slowdown" then
					if Feat.SlowWalk then
						show, text = true, "SLOW"
					end
				end
			end
			setIndicatorShown(def, show)
			if show and def.Label.Text ~= text then
				local changed = def.Label.Text ~= ""
				def.Label.Text = text
				if changed then
					pulseIndicator(def)
				end
			end
		end
	end

	------------------------------------------------------------------
	-- AFK guard (generic Roblox: Idled + VirtualUser). ASSUMED: the game has no separate AFK kicker of its own.
	------------------------------------------------------------------
	table.insert(connections, player.Idled:Connect(function()
		if Feat.PreventAFK then
			pcall(function()
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new())
			end)
		end
	end))

	------------------------------------------------------------------
	-- Loops and cleanup
	------------------------------------------------------------------
	local lastScan = 0
	local function visualStep()
		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end
		local now = os.clock()
		guard("flash", flashStep)
		guard("fog", fogStep)
		guard("radar", radarStep, cam)
		guard("grenades", grenadeStep, cam, now)
		guard("peek draw", peekDraw, cam)
		guard("penetration", penetrationStep, cam, now)
		guard("hud", hudStep, now)
		guard("indicators", indicatorStep, now)
		if now - lastScan > 0.25 then
			lastScan = now
			guard("scan", slowScan)
			guard("hitboxes", hitboxStep)
			if gameVolume.Target ~= nil then
				guard("game volume", applyGameVolume)
			end
		end
	end
	pcall(RunService.UnbindFromRenderStep, RunService, "NLExtrasVisual")
	RunService:BindToRenderStep("NLExtrasVisual", Enum.RenderPriority.Last.Value, visualStep)
	table.insert(connections, RunService.Heartbeat:Connect(function(dt)
		guard("movement", moveStep, dt)
	end))

	table.insert(Unloaders, function()
		Feat.OnShot = nil
		for k, v in pairs(Feat) do
			if type(v) == "boolean" then
				Feat[k] = false
			end
		end
		Feat.Radar = {}
		pcall(RunService.UnbindFromRenderStep, RunService, "NLExtrasVisual")
		for _, c in ipairs(connections) do
			c:Disconnect()
		end
		pcall(flashStep)
		pcall(fogStep)
		pcall(smokeVisuals, (Workspace:FindFirstChild("Ray_Ignore") or Workspace):FindFirstChild("Smokes"), false)
		moveRestore()
		local cam = Workspace.CurrentCamera
		local folder = cam and cam:FindFirstChild("NLFx")
		if folder then
			folder:Destroy()
		end
		gui:Destroy()
	end)
end)()

------------------------------------------------------------------
-- Popup of the profile block (bottom left). Menu / Windows scale are wired.
------------------------------------------------------------------
do
	local function percent(v)
		return tonumber((string.gsub(v, "%%", ""))) / 100
	end

	local account = menu.FooterMenu
	account:AddDropdown({ "Language", "globe" }, { "English", "Русский" }, "English", noop)
	-- Menu Scale: "Auto" fits the window into the screen and follows screen size changes
	local menuScale = "Auto"
	local function applyMenuScale()
		menu:SetScale(if menuScale == "Auto" then menu:GetFitScale() else percent(menuScale))
	end
	menu.Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if menuScale == "Auto" then
			applyMenuScale()
		end
	end)
	account:AddDropdown(
		{ "Menu Scale", "sliders" },
		{ "Auto", "75%", "90%", "100%", "110%", "125%", "150%" },
		"Auto",
		function(v)
			menuScale = v
			applyMenuScale()
		end
	)
	account:AddDropdown({ "ESP Scale", "text" }, { "Auto", "100%", "125%", "150%" }, "Auto", noop)
	account:AddDropdown(
		{ "Windows Scale", "window" },
		{ "75%", "90%", "100%", "110%", "125%", "150%" },
		"100%",
		function(v)
			menu:SetHudScale(percent(v))
		end
	)
	account:AddDropdown({ "Units", "sliders" }, { "Auto", "Studs", "Meters" }, "Auto", noop)
	-- Menu Bind: click the field, press a key (Esc / unknown keys keep the previous one)
	local menuKey = menu.ToggleKey
	local menuBind
	menuBind = account:AddKeybind({ "Menu Bind", "keyboard" }, menuKey, function(k)
		if not k or k == Enum.KeyCode.Unknown then
			menuBind:Set(menuKey)
			return
		end
		menuKey = k
		menu.ToggleKey = k
	end, true)
	-- Style: swatch recolours the accent of the whole menu, the button left of it switches dark / light
	account:AddColorPicker({ "Style", "image" }, Theme.Accent, function(c)
		menu:SetAccent(c)
	end):AddThemeToggle()
	-- Menu Color: the colour of the window itself, the rest of the palette follows; the sun / moon switch above resets it
	menu._menuColorPicker = account:AddColorPicker({ "Menu Color", "image" }, Theme.Window, function(c)
		menu:SetMenuColor(c)
	end)
	-- Menu Transparency: how see-through the menu's window, section cards and popups are (0% = as designed)
	account:AddSlider({ "Menu Transparency", "window" }, 0, 90, 0, function(v)
		menu:SetMenuTransparency(v / 100)
	end, "%")
	account:AddDropdown({ "Safe Mode", "ring" }, { "Disabled", "Automatic", "Forced on" }, "Automatic", noop)
	account:AddToggle({ "Synchronization", "layers" }, true, noop)
	account:AddToggle({ "Developer Mode", "panel" }, false, noop)

	-- Unload: switches every feature off and removes the menu; after it only a new run of the script brings it back.
	-- Settings of the game that the menu changed through the game's own settings (Viewmodel offset) stay as they are.
	account:AddButton("Unload", function()
		task.defer(function()
			for i = #Unloaders, 1, -1 do
				pcall(Unloaders[i])
			end
			menu:_unload()
		end)
	end)
end
