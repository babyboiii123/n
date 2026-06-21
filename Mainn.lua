--!strict
-- MatchaUI: small retained-mode UI library for constrained Roblox LuaVMs.
-- Prefer Drawing objects when available; fall back to Roblox Instances or no-op objects.

local MatchaUI = {
	Version = "0.1.0",
	Theme = {
		Background = Color3.fromRGB(24, 25, 23),
		Panel = Color3.fromRGB(33, 35, 32),
		Panel2 = Color3.fromRGB(43, 47, 41),
		Accent = Color3.fromRGB(122, 184, 94),
		Text = Color3.fromRGB(235, 239, 231),
		Muted = Color3.fromRGB(160, 169, 153),
		Stroke = Color3.fromRGB(70, 76, 66),
		Danger = Color3.fromRGB(221, 105, 92),
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

local Root = {}
Root.__index = Root

function Root.new(options)
	options = options or {}
	local self = setmetatable({}, Root)
	self.Title = options.Title or "MatchaUI"
	self.Position = options.Position or Vector2.new(80, 80)
	self.Width = options.Width or 320
	self.Visible = options.Visible ~= false
	self.Theme = options.Theme or Theme
	self._objects = {}
	self._widgets = {}
	self._sections = {}
	self._dirty = true
	self._height = 0
	self._hovered = nil
	self._pressed = nil
	self._draggingSlider = nil
	self._connections = {}
	self._guiParent = Backend.createGuiParent()

	self._background = self:_track(Backend.rect(self.Theme.Background, true))
	self._border = self:_track(Backend.rect(self.Theme.Stroke, false))
	self._title = self:_track(Backend.text(self.Title, self.Theme.Text, 15))

	self:_connectInput()
	self:Layout()
	return self
end

function Root:_track(object)
	self._objects[#self._objects + 1] = object
	return object
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

function Root:_mousePosition(input)
	local position = input and input.Position
	if typeOf(position) == "Vector3" then
		return Vector2.new(position.X, position.Y)
	elseif typeOf(position) == "Vector2" then
		return position
	end
	return nil
end

function Root:_isMouse(input)
	local inputType = input and input.UserInputType
	return tostring(inputType) == "Enum.UserInputType.MouseButton1"
		or tostring(inputType) == "MouseButton1"
		or inputType == nil
end

function Root:_hitTest(point)
	for index = #self._widgets, 1, -1 do
		local widget = self._widgets[index]
		if widget._interactive and widget.Visible ~= false then
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
	if not self.Visible or not self:_isMouse(input) then
		return
	end
	local point = self:_mousePosition(input)
	if not point then
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
	if self._draggingSlider and self._draggingSlider._drag then
		self._draggingSlider:_drag(point)
	else
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
	self._pressed = nil
	self._draggingSlider = nil
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
		_header = self:_track(Backend.text(title or "Section", self.Theme.Accent, 13)),
	}, Section)
	self._sections[#self._sections + 1] = section
	self._dirty = true
	return section
end

function Root:Layout()
	if not self._dirty then
		return
	end
	self._dirty = false

	local x = self.Position.X
	local y = self.Position.Y
	local width = self.Width
	local cursor = y + 36
	local pad = 10

	Backend.place(self._background, x, y, width, 44, 0)
	Backend.place(self._border, x - 1, y - 1, width + 2, 46, 0)
	Backend.textAt(self._title, x + pad, y + 9)

	for _, section in ipairs(self._sections) do
		if section.Visible ~= false then
			Backend.textAt(section._header, x + pad, cursor)
			cursor += 22
			for _, widget in ipairs(section.Widgets) do
				if widget.Visible ~= false then
					widget:_layout(x + pad, cursor, width - pad * 2)
					cursor += widget.Height + 6
				end
			end
			cursor += 5
		end
	end

	self._height = cursor - y + pad
	Backend.place(self._background, x, y, width, self._height)
	Backend.place(self._border, x - 1, y - 1, width + 2, self._height + 2)
end

function Root:SetVisible(visible)
	self.Visible = visible == true
	for _, object in ipairs(self._objects) do
		setVisible(object, self.Visible)
	end
end

function Root:Destroy()
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
	table.clear(self._objects)
	table.clear(self._widgets)
	table.clear(self._sections)
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
	table.clear(self._objects)
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
	widget._bg = widget.Root:_track(Backend.rect(widget.Root.Theme.Panel2, true))
	widget._label = widget.Root:_track(Backend.text(widget.Text, widget.Root.Theme.Text, 13))
	widget._objects[#widget._objects + 1] = widget._bg
	widget._objects[#widget._objects + 1] = widget._label

	function widget:_layout(x, y, w)
		self:_setBounds(x, y, w, self.Height)
		Backend.place(self._bg, x, y, w, self.Height)
		Backend.textAt(self._label, x + 8, y + 6)
	end

	function widget:_hover(active)
		Backend.color(self._bg, active and self.Root.Theme.Stroke or self.Root.Theme.Panel2)
	end

	function widget:_press()
		Backend.color(self._bg, self.Root.Theme.Accent)
	end

	function widget:_release(point)
		Backend.color(self._bg, self.Root.Theme.Panel2)
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
	widget._bg = widget.Root:_track(Backend.rect(widget.Root.Theme.Panel2, true))
	widget._box = widget.Root:_track(Backend.rect(widget.Value and widget.Root.Theme.Accent or widget.Root.Theme.Panel, true))
	widget._label = widget.Root:_track(Backend.text(widget.Text, widget.Root.Theme.Text, 13))
	widget._objects[#widget._objects + 1] = widget._bg
	widget._objects[#widget._objects + 1] = widget._box
	widget._objects[#widget._objects + 1] = widget._label

	function widget:_layout(x, y, w)
		self:_setBounds(x, y, w, self.Height)
		Backend.place(self._bg, x, y, w, self.Height)
		Backend.place(self._box, x + 7, y + 7, 14, 14)
		Backend.textAt(self._label, x + 29, y + 6)
	end

	function widget:_hover(active)
		Backend.color(self._bg, active and self.Root.Theme.Stroke or self.Root.Theme.Panel2)
	end

	function widget:Set(value, silent)
		self.Value = value == true
		Backend.color(self._box, self.Value and self.Root.Theme.Accent or self.Root.Theme.Panel)
		if not silent and self.Callback then
			self.Callback(self.Value)
		end
	end

	function widget:_release(point)
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
	widget._bg = widget.Root:_track(Backend.rect(widget.Root.Theme.Panel2, true))
	widget._bar = widget.Root:_track(Backend.rect(widget.Root.Theme.Panel, true))
	widget._fill = widget.Root:_track(Backend.rect(widget.Root.Theme.Accent, true))
	widget._label = widget.Root:_track(Backend.text("", widget.Root.Theme.Text, 13))
	widget._objects[#widget._objects + 1] = widget._bg
	widget._objects[#widget._objects + 1] = widget._bar
	widget._objects[#widget._objects + 1] = widget._fill
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
		Backend.textAt(self._label, x + 8, y + 5)
		pcall(function()
			self._label.Text = self.Text .. ": " .. tostring(self.Value)
		end)
	end

	function widget:Set(value, silent)
		self.Value = clamp(value, self.Min, self.Max)
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
