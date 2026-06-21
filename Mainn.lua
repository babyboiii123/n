--!strict
-- MatchaUI: small retained-mode UI library for constrained Roblox LuaVMs.
-- Prefer Drawing objects when available; fall back to Roblox Instances or no-op objects.

local MatchaUI = {
	Version = "0.1.0",
	Theme = {
		Background = Color3.fromRGB(18, 20, 18),
		Panel = Color3.fromRGB(29, 32, 29),
		Panel2 = Color3.fromRGB(39, 44, 38),
		Accent = Color3.fromRGB(122, 184, 94),
		Text = Color3.fromRGB(235, 239, 231),
		Muted = Color3.fromRGB(166, 176, 158),
		Stroke = Color3.fromRGB(76, 86, 70),
		Hover = Color3.fromRGB(50, 58, 47),
		Pressed = Color3.fromRGB(95, 139, 76),
		Shadow = Color3.fromRGB(6, 7, 6),
		Danger = Color3.fromRGB(221, 105, 92),
		Warning = Color3.fromRGB(220, 175, 83),
	},
}

local floor = math.floor
local typeOf = typeof or type
local clamp = math.clamp or function(value, minValue, maxValue)
	if value < minValue then
		return minValue
	elseif value > maxValue then
		return maxValue
	end
	return value
end

local function vec2(x, y)
	return Vector2.new(floor(x + 0.5), floor(y + 0.5))
end

local Theme = MatchaUI.Theme

local function normalizeKey(value)
	if value == nil then
		return ""
	end

	local valueType = typeOf(value)
	if valueType ~= "string" and valueType ~= "number" then
		local ok, name = pcall(function()
			return value.Name
		end)
		if ok and name then
			value = name
		end
	end

	local text = tostring(value or "")
	text = text:gsub("Enum%.KeyCode%.", "")
	text = text:gsub("Enum%.UserInputType%.", "")
	text = text:gsub("KeyCode%.", "")
	text = text:gsub("UserInputType%.", "")
	text = text:gsub("%s+", "")
	return string.lower(text)
end

local function clearArray(list)
	for index = #list, 1, -1 do
		list[index] = nil
	end
end

local function makeThread(callback)
	if typeOf(task) == "table" and typeOf(task.spawn) == "function" then
		task.spawn(callback)
	else
		coroutine.wrap(callback)()
	end
end

local function sleep(seconds)
	if typeOf(task) == "table" and typeOf(task.wait) == "function" then
		task.wait(seconds)
		return true
	elseif typeOf(wait) == "function" then
		wait(seconds)
		return true
	end
	return false
end

local function isDrawingReady()
	return typeOf(Drawing) == "table" and typeOf(Drawing.new) == "function"
end

local hasDrawing = isDrawingReady()
local hasInstances = typeOf(Instance) == "table" and typeOf(Instance.new) == "function"

local NullObject = {}
NullObject.__index = NullObject

function NullObject:Remove() end
function NullObject:Destroy() end

local function newNull()
	return setmetatable({}, NullObject)
end

local function protect(callback)
	local ok, result = pcall(callback)
	if ok then
		return result
	end
	return nil
end

local function setVisible(object, visible)
	if object then
		object.Visible = visible
	end
end

local function removeObject(object)
	if not object then
		return
	end
	if typeOf(object.Remove) == "function" then
		pcall(function()
			object:Remove()
		end)
	elseif typeOf(object.Destroy) == "function" then
		pcall(function()
			object:Destroy()
		end)
	end
end

local function newDrawing(kind, props)
	if hasDrawing then
		local object = protect(function()
			return Drawing.new(kind)
		end)
		if object then
			for key, value in pairs(props) do
				pcall(function()
					object[key] = value
				end)
			end
			return object
		end
	end
	return newNull()
end

local function newGui(kind, props, parent)
	if not hasInstances then
		return newNull()
	end

	local object = protect(function()
		return Instance.new(kind)
	end)
	if not object then
		return newNull()
	end

	for key, value in pairs(props) do
		pcall(function()
			object[key] = value
		end)
	end
	if parent then
		pcall(function()
			object.Parent = parent
		end)
	end
	return object
end

local Backend = {}
Backend.GuiParent = nil

function Backend.createGuiParent()
	if hasDrawing or not hasInstances then
		return nil
	end

	local screen = newGui("ScreenGui", {
		Name = "MatchaUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
	}, nil)

	local parent = protect(function()
		return game:GetService("CoreGui")
	end) or protect(function()
		local players = game:GetService("Players")
		local localPlayer = players and players.LocalPlayer
		return localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
	end)

	if parent then
		pcall(function()
			screen.Parent = parent
		end)
	end

	Backend.GuiParent = screen
	return screen
end

function Backend.rect(color, filled)
	if hasDrawing then
		return newDrawing("Square", {
			Color = color,
			Filled = filled ~= false,
			Thickness = 1,
			Transparency = 1,
			Visible = true,
		})
	end
	return newGui("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = filled == false and 1 or 0,
		Visible = true,
	}, Backend.GuiParent)
end

function Backend.text(text, color, size)
	if hasDrawing then
		return newDrawing("Text", {
			Text = text,
			Color = color,
			Size = size or 13,
			Font = 2,
			Outline = false,
			Center = false,
			Visible = true,
		})
	end
	return newGui("TextLabel", {
		Text = text,
		TextColor3 = color,
		TextSize = size or 13,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = true,
	}, Backend.GuiParent)
end

function Backend.place(object, x, y, w, h)
	if not object then
		return
	end
	if hasDrawing and object.Position ~= nil then
		object.Position = vec2(x, y)
		if object.Size ~= nil then
			object.Size = vec2(w, h)
		end
	else
		pcall(function()
			object.Position = UDim2.fromOffset(x, y)
			object.Size = UDim2.fromOffset(w, h)
		end)
	end
end

function Backend.textAt(object, x, y)
	if not object then
		return
	end
	if hasDrawing and object.Position ~= nil then
		object.Position = vec2(x, y)
	else
		pcall(function()
			object.Position = UDim2.fromOffset(x, y)
		end)
	end
end

function Backend.color(object, color)
	if not object then
		return
	end
	pcall(function()
		object.Color = color
	end)
	pcall(function()
		object.BackgroundColor3 = color
	end)
	pcall(function()
		object.TextColor3 = color
	end)
end

local Section = {}
local Settings = {}

local Root = {}
Root.__index = Root

function Root.new(options)
	options = options or {}
	local self = setmetatable({}, Root)
	self.Title = options.Title or "MatchaUI"
	self.Position = options.Position or Vector2.new(80, 80)
	self.Width = options.Width or 320
	self.Visible = options.Visible ~= false
	self.Minimized = false
	self.Theme = options.Theme or Theme
	self._objects = {}
	self._chromeObjects = {}
	self._widgets = {}
	self._sections = {}
	self._keybinds = {}
	self._activeSection = nil
	self._dirty = true
	self._height = 0
	self._hovered = nil
	self._pressed = nil
	self._pressedControl = nil
	self._hoveredControl = nil
	self._hoveredTab = nil
	self._pressedTab = nil
	self._draggingSlider = nil
	self._draggingWindow = false
	self._dragOffset = Vector2.new(0, 0)
	self._alive = true
	self._titleBounds = { X = 0, Y = 0, W = 0, H = 0 }
	self._controls = {}
	self._connections = {}
	self._guiParent = Backend.createGuiParent()
	self._mouse = self:_findMouse()

	self._shadow = self:_track(Backend.rect(self.Theme.Shadow, true))
	self._background = self:_track(Backend.rect(self.Theme.Background, true))
	self._header = self:_track(Backend.rect(self.Theme.Panel, true))
	self._accent = self:_track(Backend.rect(self.Theme.Accent, true))
	self._border = self:_track(Backend.rect(self.Theme.Stroke, false))
	self._title = self:_track(Backend.text(self.Title, self.Theme.Text, 15))
	self:_trackChrome(self._shadow)
	self:_trackChrome(self._background)
	self:_trackChrome(self._header)
	self:_trackChrome(self._accent)
	self:_trackChrome(self._border)
	self:_trackChrome(self._title)
	self:_createTitleControls()

	self:_connectInput()
	self:_startInputLoop()
	self:Layout()
	return self
end

function Root:_track(object)
	self._objects[#self._objects + 1] = object
	return object
end

function Root:_trackChrome(object)
	self._chromeObjects[#self._chromeObjects + 1] = object
	return object
end

function Root:_makeControl(name, text, color, callback)
	local bg = self:_track(Backend.rect(self.Theme.Panel2, true))
	local label = self:_track(Backend.text(text, color, 13))
	self:_trackChrome(bg)
	self:_trackChrome(label)

	local control = {
		Name = name,
		Text = text,
		Callback = callback,
		BG = bg,
		Label = label,
		Color = color,
		Bounds = { X = 0, Y = 0, W = 0, H = 0 },
	}
	self._controls[#self._controls + 1] = control
	return control
end

function Root:_createTitleControls()
	self._minimizeControl = self:_makeControl("Minimize", "-", self.Theme.Warning, function()
		self:SetMinimized(not self.Minimized)
	end)
	self._closeControl = self:_makeControl("Close", "x", self.Theme.Danger, function()
		self:Close()
	end)
end

function Root:_connectInput()
	local ok, service = pcall(function()
		return game:GetService("UserInputService")
	end)
	if not ok or not service then
		return
	end

	local began = service.InputBegan
	local changed = service.InputChanged
	local ended = service.InputEnded

	if began and began.Connect then
		self._connections[#self._connections + 1] = began:Connect(function(input, processed)
			if processed then
				self:_dispatchKey(input)
				return
			end
			self:_inputBegan(input)
		end)
	end
	if changed and changed.Connect then
		self._connections[#self._connections + 1] = changed:Connect(function(input)
			self:_inputChanged(input)
		end)
	end
	if ended and ended.Connect then
		self._connections[#self._connections + 1] = ended:Connect(function(input)
			self:_inputEnded(input)
		end)
	end
end

function Root:_findMouse()
	local player = protect(function()
		return game:GetService("Players").LocalPlayer
	end)
	if player and player.GetMouse then
		return protect(function()
			return player:GetMouse()
		end)
	end
	return nil
end

function Root:_mousePosition(input)
	local position = input and input.Position
	if typeOf(position) == "Vector3" then
		return Vector2.new(position.X, position.Y)
	elseif typeOf(position) == "Vector2" then
		return position
	end
	if self._mouse and self._mouse.X and self._mouse.Y then
		return Vector2.new(self._mouse.X, self._mouse.Y)
	end
	return nil
end

function Root:_isMouse(input)
	local inputType = input and input.UserInputType
	local keyCode = input and input.KeyCode
	return tostring(inputType) == "Enum.UserInputType.MouseButton1"
		or tostring(inputType) == "MouseButton1"
		or tostring(keyCode) == "Enum.UserInputType.MouseButton1"
		or tostring(keyCode) == "MouseButton1"
		or inputType == nil
end

function Root:_keyName(input)
	if not input then
		return ""
	end
	local keyCode = input.KeyCode
	if keyCode and tostring(keyCode) ~= "Enum.KeyCode.Unknown" then
		return normalizeKey(keyCode)
	end
	local key = normalizeKey(input.Key or input.KeyName or input.Name)
	if key ~= "" then
		return key
	end
	return normalizeKey(input.UserInputType)
end

function Root:_dispatchKey(input)
	local key = self:_keyName(input)
	if key == "" then
		return false
	end
	for _, bind in ipairs(self._keybinds) do
		if bind.Enabled ~= false and bind.Key == key then
			bind.Callback(self, input)
			return true
		end
	end
	return false
end

function Root:_inTitle(point)
	local b = self._titleBounds
	return point.X >= b.X and point.Y >= b.Y and point.X <= b.X + b.W and point.Y <= b.Y + b.H
end

function Root:_hitControl(point)
	for index = #self._controls, 1, -1 do
		local control = self._controls[index]
		local b = control.Bounds
		if point.X >= b.X and point.Y >= b.Y and point.X <= b.X + b.W and point.Y <= b.Y + b.H then
			return control
		end
	end
	return nil
end

function Root:_hitTab(point)
	if self.Minimized then
		return nil
	end
	for index = #self._sections, 1, -1 do
		local section = self._sections[index]
		local b = section._tabBounds
		if section.Visible ~= false
			and b
			and point.X >= b.X
			and point.Y >= b.Y
			and point.X <= b.X + b.W
			and point.Y <= b.Y + b.H
		then
			return section
		end
	end
	return nil
end

function Root:_paintControl(control, state)
	if not control then
		return
	end
	local color = self.Theme.Panel2
	if state == "hover" then
		color = self.Theme.Hover
	elseif state == "pressed" then
		color = self.Theme.Pressed
	end
	Backend.color(control.BG, color)
end

function Root:_paintTab(section, state)
	if not section then
		return
	end
	local color = self.Theme.Panel2
	local textColor = self.Theme.Muted
	if section == self._activeSection then
		color = self.Theme.Accent
		textColor = self.Theme.Text
	elseif state == "hover" then
		color = self.Theme.Hover
		textColor = self.Theme.Text
	end
	Backend.color(section._tabBg, color)
	Backend.color(section._tabLabel, textColor)
end

function Root:_startInputLoop()
	makeThread(function()
		while self._alive do
			self:_tickInput()
			if not sleep(1 / 30) then
				break
			end
		end
	end)
end

function Root:_tickInput()
	if not self.Visible then
		return
	end

	local point = self:_mousePosition(nil)
	if not point then
		return
	end

	if self._draggingWindow then
		self.Position = vec2(point.X - self._dragOffset.X, point.Y - self._dragOffset.Y)
		self._dirty = true
		self:Layout()
		return
	end

	if self._draggingSlider and self._draggingSlider._drag then
		self._draggingSlider:_drag(point)
		return
	end

	local control = self:_hitControl(point)
	if control ~= self._hoveredControl then
		self:_paintControl(self._hoveredControl, "idle")
		self._hoveredControl = control
		self:_paintControl(control, "hover")
	end
	if control then
		if self._hovered and self._hovered._hover then
			self._hovered:_hover(false)
		end
		self:_paintTab(self._hoveredTab, "idle")
		self._hoveredTab = nil
		self._hovered = nil
		return
	end

	local tab = self:_hitTab(point)
	if tab ~= self._hoveredTab then
		self:_paintTab(self._hoveredTab, "idle")
		self._hoveredTab = tab
		self:_paintTab(tab, "hover")
	end
	if tab then
		if self._hovered and self._hovered._hover then
			self._hovered:_hover(false)
		end
		self._hovered = nil
		return
	end

	local hovered = self:_hitTest(point)
	if hovered ~= self._hovered then
		if self._hovered and self._hovered._hover then
			self._hovered:_hover(false)
		end
		self._hovered = hovered
		if hovered and hovered._hover then
			hovered:_hover(true)
		end
	end
end

function Root:_hitTest(point)
	for index = #self._widgets, 1, -1 do
		local widget = self._widgets[index]
		if widget._interactive
			and widget.Visible ~= false
			and widget.Section == self._activeSection
			and not self.Minimized
		then
			local bounds = widget._bounds
			if bounds
				and point.X >= bounds.X
				and point.Y >= bounds.Y
				and point.X <= bounds.X + bounds.W
				and point.Y <= bounds.Y + bounds.H
			then
				return widget
			end
		end
	end
	return nil
end

function Root:_inputBegan(input)
	if self:_dispatchKey(input) then
		return
	end
	if not self.Visible or not self:_isMouse(input) then
		return
	end
	local point = self:_mousePosition(input)
	if not point then
		return
	end
	local control = self:_hitControl(point)
	if control then
		self._pressedControl = control
		self:_paintControl(control, "pressed")
		return
	end
	local tab = self:_hitTab(point)
	if tab then
		self._pressedTab = tab
		self._activeSection = tab
		self:_paintTab(tab, "hover")
		self._dirty = true
		self:Layout()
		return
	end
	if self:_inTitle(point) then
		self._draggingWindow = true
		self._dragOffset = Vector2.new(point.X - self.Position.X, point.Y - self.Position.Y)
		return
	end
	local widget = self:_hitTest(point)
	self._pressed = widget
	if widget and widget._press then
		widget:_press(point)
	end
end

function Root:_inputChanged(input)
	if not self.Visible then
		return
	end
	local point = self:_mousePosition(input)
	if not point then
		return
	end
	if self._draggingWindow then
		self.Position = vec2(point.X - self._dragOffset.X, point.Y - self._dragOffset.Y)
		self._dirty = true
		self:Layout()
	elseif self._draggingSlider and self._draggingSlider._drag then
		self._draggingSlider:_drag(point)
	else
		local control = self:_hitControl(point)
		if control ~= self._hoveredControl then
			self:_paintControl(self._hoveredControl, "idle")
			self._hoveredControl = control
			self:_paintControl(control, "hover")
		end
		if control then
			if self._hovered and self._hovered._hover then
				self._hovered:_hover(false)
			end
			self:_paintTab(self._hoveredTab, "idle")
			self._hoveredTab = nil
			self._hovered = nil
			return
		end

		local tab = self:_hitTab(point)
		if tab ~= self._hoveredTab then
			self:_paintTab(self._hoveredTab, "idle")
			self._hoveredTab = tab
			self:_paintTab(tab, "hover")
		end
		if tab then
			if self._hovered and self._hovered._hover then
				self._hovered:_hover(false)
			end
			self._hovered = nil
			return
		end

		local hovered = self:_hitTest(point)
		if hovered ~= self._hovered then
			if self._hovered and self._hovered._hover then
				self._hovered:_hover(false)
			end
			self._hovered = hovered
			if hovered and hovered._hover then
				hovered:_hover(true)
			end
		end
	end
end

function Root:_inputEnded(input)
	if not self:_isMouse(input) then
		return
	end
	local point = self:_mousePosition(input)
	local pressed = self._pressed
	local pressedControl = self._pressedControl
	local pressedTab = self._pressedTab
	self._pressed = nil
	self._pressedControl = nil
	self._pressedTab = nil
	self._draggingSlider = nil
	self._draggingWindow = false
	if pressedControl then
		local overControl = point and self:_hitControl(point) == pressedControl
		self:_paintControl(pressedControl, overControl and "hover" or "idle")
		if overControl and pressedControl.Callback then
			pressedControl.Callback()
		end
		return
	end
	if pressedTab then
		self:_paintTab(pressedTab, self._hoveredTab == pressedTab and "hover" or "idle")
		return
	end
	if pressed and pressed._release then
		pressed:_release(point)
	end
end

function Root:AddWidget(widget)
	self._widgets[#self._widgets + 1] = widget
	self._dirty = true
	return widget
end

function Root:Section(title)
	local section = setmetatable({
		Root = self,
		Title = title or "Section",
		Widgets = {},
		Visible = true,
		_tabBg = self:_track(Backend.rect(self.Theme.Panel2, true)),
		_tabLabel = self:_track(Backend.text(title or "Section", self.Theme.Muted, 12)),
		_tabBounds = { X = 0, Y = 0, W = 0, H = 0 },
	}, Section)
	self._sections[#self._sections + 1] = section
	if not self._activeSection then
		self._activeSection = section
	end
	self._dirty = true
	return section
end

function Root:Tab(title)
	return self:Section(title)
end

function Root:Layout()
	if not self._dirty then
		return
	end
	self._dirty = false

	local x = self.Position.X
	local y = self.Position.Y
	local width = self.Width
	local cursor = y + 72
	local pad = 10

	self._titleBounds.X = x
	self._titleBounds.Y = y
	self._titleBounds.W = width
	self._titleBounds.H = 34

	Backend.place(self._shadow, x + 5, y + 6, width, math.max(self._height, 52))
	Backend.place(self._background, x, y, width, 52)
	Backend.place(self._header, x, y, width, 34)
	Backend.place(self._accent, x, y + 34, width, 2)
	Backend.place(self._border, x - 1, y - 1, width + 2, 54)
	Backend.textAt(self._title, x + pad, y + 9)

	local closeX = x + width - 28
	local minimizeX = x + width - 54
	self._minimizeControl.Bounds.X = minimizeX
	self._minimizeControl.Bounds.Y = y + 7
	self._minimizeControl.Bounds.W = 20
	self._minimizeControl.Bounds.H = 20
	self._closeControl.Bounds.X = closeX
	self._closeControl.Bounds.Y = y + 7
	self._closeControl.Bounds.W = 20
	self._closeControl.Bounds.H = 20
	Backend.place(self._minimizeControl.BG, minimizeX, y + 7, 20, 20)
	Backend.textAt(self._minimizeControl.Label, minimizeX + 7, y + 9)
	Backend.place(self._closeControl.BG, closeX, y + 7, 20, 20)
	Backend.textAt(self._closeControl.Label, closeX + 7, y + 8)
	pcall(function()
		self._minimizeControl.Label.Text = self.Minimized and "+" or "-"
	end)

	if not self.Minimized then
		if self._activeSection and self._activeSection.Visible == false then
			self._activeSection = nil
		end
		if not self._activeSection then
			for _, section in ipairs(self._sections) do
				if section.Visible ~= false then
					self._activeSection = section
					break
				end
			end
		end

		local tabCount = math.max(#self._sections, 1)
		local tabGap = 5
		local tabW = floor((width - pad * 2 - tabGap * (tabCount - 1)) / tabCount)
		local tabY = y + 42
		for index, section in ipairs(self._sections) do
			local tabX = x + pad + (index - 1) * (tabW + tabGap)
			section._tabBounds.X = tabX
			section._tabBounds.Y = tabY
			section._tabBounds.W = tabW
			section._tabBounds.H = 22
			Backend.place(section._tabBg, tabX, tabY, tabW, 22)
			Backend.textAt(section._tabLabel, tabX + 8, tabY + 4)
			setVisible(section._tabBg, self.Visible and section.Visible ~= false)
			setVisible(section._tabLabel, self.Visible and section.Visible ~= false)
			self:_paintTab(section, section == self._hoveredTab and "hover" or "idle")
		end

		for _, section in ipairs(self._sections) do
			if section.Visible ~= false and section == self._activeSection then
				for _, widget in ipairs(section.Widgets) do
					if widget.Visible ~= false then
						for _, object in ipairs(widget._objects) do
							setVisible(object, self.Visible)
						end
						widget:_layout(x + pad, cursor, width - pad * 2)
						cursor += widget.Height + 6
					end
				end
				cursor += 5
			else
				for _, widget in ipairs(section.Widgets) do
					for _, object in ipairs(widget._objects) do
						setVisible(object, false)
					end
				end
			end
		end
	else
		for _, section in ipairs(self._sections) do
			setVisible(section._tabBg, false)
			setVisible(section._tabLabel, false)
			for _, widget in ipairs(section.Widgets) do
				for _, object in ipairs(widget._objects) do
					setVisible(object, false)
				end
			end
		end
	end

	self._height = self.Minimized and 36 or cursor - y + pad
	Backend.place(self._shadow, x + 5, y + 6, width, self._height)
	Backend.place(self._background, x, y, width, self._height)
	Backend.place(self._header, x, y, width, 34)
	Backend.place(self._accent, x, y + 34, width, 2)
	Backend.place(self._border, x - 1, y - 1, width + 2, self._height + 2)
end

function Root:SetVisible(visible)
	self.Visible = visible == true
	for _, object in ipairs(self._objects) do
		setVisible(object, self.Visible)
	end
	if self.Visible then
		self._dirty = true
		self:Layout()
	end
end

function Root:ToggleVisible()
	self:SetVisible(not self.Visible)
end

function Root:SetMinimized(minimized)
	self.Minimized = minimized == true
	self._pressed = nil
	self._draggingSlider = nil
	self._dirty = true
	self:Layout()
end

function Root:ToggleMinimized()
	self:SetMinimized(not self.Minimized)
end

function Root:Close()
	self:SetVisible(false)
end

function Root:BindKey(key, callback)
	local bind = {
		Key = normalizeKey(key),
		Callback = callback,
		Enabled = true,
	}
	self._keybinds[#self._keybinds + 1] = bind
	return {
		Disconnect = function()
			bind.Enabled = false
		end,
	}
end

function Root:Settings(options)
	return Settings.new(self, options)
end

function Root:Destroy()
	self._alive = false
	for _, connection in ipairs(self._connections) do
		if connection and connection.Disconnect then
			pcall(function()
				connection:Disconnect()
			end)
		end
	end
	for _, object in ipairs(self._objects) do
		removeObject(object)
	end
	removeObject(self._guiParent)
	clearArray(self._objects)
	clearArray(self._widgets)
	clearArray(self._sections)
end

Settings.__index = Settings

function Settings.new(root, options)
	options = options or {}
	local self = setmetatable({}, Settings)
	self.Root = root
	self.ToggleKey = nil
	self.MinimizeKey = nil
	self.BeaconEnabled = false
	self._toggleBind = nil
	self._minimizeBind = nil
	self._beaconObjects = nil
	self._beaconAlive = false
	self._section = nil
	self._defaultBeacon = options.Beacon ~= false

	if options.Panel ~= false then
		self:_createPanel()
	end

	if options.ToggleKey ~= false then
		self:BindToggleKey(options.ToggleKey or "F1")
	end

	if options.MinimizeKey then
		self:BindMinimizeKey(options.MinimizeKey)
	end

	if options.Beacon ~= false then
		self:EnableBeacon(true)
	end

	return self
end

function Settings:_createPanel()
	local section = self.Root:Section("UI")
	self._section = section
	self._keyLabel = section:Label("Toggle key: F1")
	section:Button("Hide UI", function()
		self.Root:SetVisible(false)
	end)
	section:Button("Minimize", function()
		self.Root:ToggleMinimized()
	end)
	section:Toggle("Cursor beacon", self._defaultBeacon, function(enabled)
		self:EnableBeacon(enabled)
	end)
end

function Settings:_setKeyLabel()
	if self._keyLabel then
		self._keyLabel:Set("Toggle key: " .. tostring(self.ToggleKey or "none"))
	end
end

function Settings:BindToggleKey(key)
	if self._toggleBind then
		self._toggleBind.Disconnect()
	end
	self.ToggleKey = tostring(key)
	self._toggleBind = self.Root:BindKey(key, function(root)
		root:ToggleVisible()
		self:Pulse()
	end)
	self:_setKeyLabel()
	return self
end

function Settings:BindMinimizeKey(key)
	if self._minimizeBind then
		self._minimizeBind.Disconnect()
	end
	self.MinimizeKey = tostring(key)
	self._minimizeBind = self.Root:BindKey(key, function(root)
		if root.Visible then
			root:ToggleMinimized()
			self:Pulse()
		end
	end)
	return self
end

function Settings:_ensureBeacon()
	if self._beaconObjects then
		return
	end

	self._beaconObjects = {
		self.Root:_track(Backend.rect(self.Root.Theme.Accent, true)),
		self.Root:_track(Backend.rect(self.Root.Theme.Text, true)),
		self.Root:_track(Backend.rect(self.Root.Theme.Accent, true)),
	}

	for _, object in ipairs(self._beaconObjects) do
		setVisible(object, false)
	end
end

function Settings:EnableBeacon(enabled)
	self.BeaconEnabled = enabled == true
	self:_ensureBeacon()

	if not self.BeaconEnabled then
		for _, object in ipairs(self._beaconObjects) do
			setVisible(object, false)
		end
		return self
	end

	if not self._beaconAlive then
		self._beaconAlive = true
		makeThread(function()
			while self._beaconAlive and self.Root._alive do
				self:_tickBeacon()
				if not sleep(1 / 24) then
					break
				end
			end
		end)
	end

	return self
end

function Settings:_tickBeacon()
	if not self.BeaconEnabled or not self.Root.Visible then
		for _, object in ipairs(self._beaconObjects) do
			setVisible(object, false)
		end
		return
	end

	local point = self.Root:_mousePosition(nil)
	if not point then
		return
	end

	local bounds = nil
	if self.Root._hovered then
		bounds = self.Root._hovered._bounds
	elseif self.Root._hoveredControl then
		bounds = self.Root._hoveredControl.Bounds
	end

	local x = point.X + 12
	local y = point.Y + 14
	if bounds then
		x = bounds.X + bounds.W + 6
		y = bounds.Y + 4
	end

	for index, object in ipairs(self._beaconObjects) do
		setVisible(object, true)
		Backend.place(object, x, y + (index - 1) * 6, index == 2 and 10 or 6, 3)
	end
end

function Settings:Pulse()
	self:_ensureBeacon()
	makeThread(function()
		for step = 1, 6 do
			if not self.Root._alive then
				return
			end
			local x = self.Root.Position.X + self.Root.Width - 82 + step * 3
			local y = self.Root.Position.Y + 39
			for index, object in ipairs(self._beaconObjects) do
				setVisible(object, self.Root.Visible)
				Backend.place(object, x + (index - 1) * 12, y, 9, 3)
			end
			if not sleep(0.035) then
				break
			end
		end
	end)
end

function Settings:Destroy()
	if self._toggleBind then
		self._toggleBind.Disconnect()
	end
	if self._minimizeBind then
		self._minimizeBind.Disconnect()
	end
	self._beaconAlive = false
	if self._beaconObjects then
		for _, object in ipairs(self._beaconObjects) do
			removeObject(object)
		end
		clearArray(self._beaconObjects)
	end
end

Section.__index = Section

local Widget = {}
Widget.__index = Widget

function Widget:_setBounds(x, y, w, h)
	self._bounds.X = x
	self._bounds.Y = y
	self._bounds.W = w
	self._bounds.H = h
end

function Widget:SetVisible(visible)
	self.Visible = visible == true
	for _, object in ipairs(self._objects) do
		setVisible(object, self.Visible and self.Root.Visible)
	end
	self.Root._dirty = true
	self.Root:Layout()
end

function Widget:Destroy()
	self.Visible = false
	for _, object in ipairs(self._objects) do
		removeObject(object)
	end
	clearArray(self._objects)
	self.Root._dirty = true
	self.Root:Layout()
end

local function baseWidget(section, height, interactive)
	local root = section.Root
	local widget = setmetatable({
		Root = root,
		Section = section,
		Height = height,
		Visible = true,
		_interactive = interactive == true,
		_bounds = { X = 0, Y = 0, W = 0, H = height },
		_objects = {},
	}, Widget)
	section.Widgets[#section.Widgets + 1] = widget
	root:AddWidget(widget)
	return widget
end

function Section:Label(text)
	local widget = baseWidget(self, 20, false)
	widget.Text = text or ""
	widget._text = widget.Root:_track(Backend.text(widget.Text, widget.Root.Theme.Muted, 13))
	widget._objects[#widget._objects + 1] = widget._text

	function widget:_layout(x, y, w)
		self:_setBounds(x, y, w, self.Height)
		Backend.textAt(self._text, x, y + 2)
	end

	function widget:Set(textValue)
		self.Text = textValue or ""
		pcall(function()
			self._text.Text = self.Text
		end)
	end

	self.Root:Layout()
	return widget
end

function Section:Button(text, callback)
	local widget = baseWidget(self, 28, true)
	widget.Text = text or "Button"
	widget.Callback = callback
	widget._down = false
	widget._isHovering = false
	widget._bg = widget.Root:_track(Backend.rect(widget.Root.Theme.Panel2, true))
	widget._edge = widget.Root:_track(Backend.rect(widget.Root.Theme.Accent, true))
	widget._label = widget.Root:_track(Backend.text(widget.Text, widget.Root.Theme.Text, 13))
	widget._objects[#widget._objects + 1] = widget._bg
	widget._objects[#widget._objects + 1] = widget._edge
	widget._objects[#widget._objects + 1] = widget._label

	function widget:_layout(x, y, w)
		self:_setBounds(x, y, w, self.Height)
		Backend.place(self._bg, x, y, w, self.Height)
		Backend.place(self._edge, x, y, 3, self.Height)
		Backend.textAt(self._label, x + 10, y + 6)
	end

	function widget:_hover(active)
		self._isHovering = active == true
		if not self._down then
			Backend.color(self._bg, active and self.Root.Theme.Hover or self.Root.Theme.Panel2)
		end
	end

	function widget:_press()
		self._down = true
		Backend.color(self._bg, self.Root.Theme.Pressed)
	end

	function widget:_release(point)
		self._down = false
		Backend.color(self._bg, self._isHovering and self.Root.Theme.Hover or self.Root.Theme.Panel2)
		if not point or self.Root:_hitTest(point) == self then
			if self.Callback then
				self.Callback()
			end
		end
	end

	function widget:Set(textValue)
		self.Text = textValue or ""
		pcall(function()
			self._label.Text = self.Text
		end)
	end

	self.Root:Layout()
	return widget
end

function Section:Toggle(text, defaultValue, callback)
	local widget = baseWidget(self, 28, true)
	widget.Text = text or "Toggle"
	widget.Value = defaultValue == true
	widget.Callback = callback
	widget._down = false
	widget._isHovering = false
	widget._bg = widget.Root:_track(Backend.rect(widget.Root.Theme.Panel2, true))
	widget._box = widget.Root:_track(Backend.rect(widget.Value and widget.Root.Theme.Accent or widget.Root.Theme.Panel, true))
	widget._mark = widget.Root:_track(Backend.text(widget.Value and "on" or "", widget.Root.Theme.Text, 11))
	widget._label = widget.Root:_track(Backend.text(widget.Text, widget.Root.Theme.Text, 13))
	widget._objects[#widget._objects + 1] = widget._bg
	widget._objects[#widget._objects + 1] = widget._box
	widget._objects[#widget._objects + 1] = widget._mark
	widget._objects[#widget._objects + 1] = widget._label

	function widget:_layout(x, y, w)
		self:_setBounds(x, y, w, self.Height)
		Backend.place(self._bg, x, y, w, self.Height)
		Backend.place(self._box, x + 8, y + 7, 28, 14)
		Backend.textAt(self._mark, x + 14, y + 7)
		Backend.textAt(self._label, x + 46, y + 6)
	end

	function widget:_hover(active)
		self._isHovering = active == true
		if not self._down then
			Backend.color(self._bg, active and self.Root.Theme.Hover or self.Root.Theme.Panel2)
		end
	end

	function widget:_press()
		self._down = true
		Backend.color(self._bg, self.Root.Theme.Pressed)
	end

	function widget:Set(value, silent)
		self.Value = value == true
		Backend.color(self._box, self.Value and self.Root.Theme.Accent or self.Root.Theme.Panel)
		pcall(function()
			self._mark.Text = self.Value and "on" or ""
		end)
		if not silent and self.Callback then
			self.Callback(self.Value)
		end
	end

	function widget:_release(point)
		self._down = false
		Backend.color(self._bg, self._isHovering and self.Root.Theme.Hover or self.Root.Theme.Panel2)
		if not point or self.Root:_hitTest(point) == self then
			self:Set(not self.Value)
		end
	end

	self.Root:Layout()
	return widget
end

function Section:Slider(text, minValue, maxValue, defaultValue, callback)
	minValue = minValue or 0
	maxValue = maxValue or 100
	defaultValue = defaultValue or minValue

	local widget = baseWidget(self, 34, true)
	widget.Text = text or "Slider"
	widget.Min = minValue
	widget.Max = maxValue
	widget.Value = clamp(defaultValue, minValue, maxValue)
	widget.Callback = callback
	widget._isHovering = false
	widget._bg = widget.Root:_track(Backend.rect(widget.Root.Theme.Panel2, true))
	widget._bar = widget.Root:_track(Backend.rect(widget.Root.Theme.Panel, true))
	widget._fill = widget.Root:_track(Backend.rect(widget.Root.Theme.Accent, true))
	widget._knob = widget.Root:_track(Backend.rect(widget.Root.Theme.Text, true))
	widget._label = widget.Root:_track(Backend.text("", widget.Root.Theme.Text, 13))
	widget._objects[#widget._objects + 1] = widget._bg
	widget._objects[#widget._objects + 1] = widget._bar
	widget._objects[#widget._objects + 1] = widget._fill
	widget._objects[#widget._objects + 1] = widget._knob
	widget._objects[#widget._objects + 1] = widget._label

	function widget:_ratio()
		local range = self.Max - self.Min
		if range == 0 then
			return 0
		end
		return clamp((self.Value - self.Min) / range, 0, 1)
	end

	function widget:_layout(x, y, w)
		self:_setBounds(x, y, w, self.Height)
		local ratio = self:_ratio()
		Backend.place(self._bg, x, y, w, self.Height)
		Backend.place(self._bar, x + 8, y + 22, w - 16, 5)
		Backend.place(self._fill, x + 8, y + 22, floor((w - 16) * ratio), 5)
		Backend.place(self._knob, x + 6 + floor((w - 16) * ratio), y + 19, 5, 11)
		Backend.textAt(self._label, x + 8, y + 5)
		pcall(function()
			self._label.Text = self.Text .. ": " .. tostring(self.Value)
		end)
	end

	function widget:_hover(active)
		self._isHovering = active == true
		Backend.color(self._bg, active and self.Root.Theme.Hover or self.Root.Theme.Panel2)
	end

	function widget:Set(value, silent)
		local nextValue = clamp(value, self.Min, self.Max)
		if nextValue == self.Value then
			return
		end
		self.Value = nextValue
		self.Root._dirty = true
		self.Root:Layout()
		if not silent and self.Callback then
			self.Callback(self.Value)
		end
	end

	function widget:_drag(point)
		local x = self._bounds.X + 8
		local width = self._bounds.W - 16
		local ratio = clamp((point.X - x) / width, 0, 1)
		self:Set(floor((self.Min + (self.Max - self.Min) * ratio) + 0.5))
	end

	function widget:_press(point)
		self.Root._draggingSlider = self
		self:_drag(point)
	end

	self.Root:Layout()
	return widget
end

function MatchaUI.Window(options)
	return Root.new(options)
end

function MatchaUI.CreateWindow(options)
	return Root.new(options)
end

function MatchaUI.Settings(window, options)
	return Settings.new(window, options)
end

if typeOf(_G) == "table" then
	_G.MatchaUI = MatchaUI
end

if typeOf(shared) == "table" then
	shared.MatchaUI = MatchaUI
end

if typeOf(getgenv) == "function" then
	pcall(function()
		getgenv().MatchaUI = MatchaUI
	end)
end

return MatchaUI
