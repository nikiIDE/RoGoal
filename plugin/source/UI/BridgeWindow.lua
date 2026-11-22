--!strict

local Root = script.Parent.Parent
local Theme = require(Root.UI.Theme)
local Primitives = require(Root.UI.Primitives)
local Layout = require(Root.UI.ReferenceLayout)
local Defaults = require(Root.Config.Defaults)

local BridgeWindow = {}
BridgeWindow.__index = BridgeWindow

local function label(parent: Instance, value: string, size: number, order: number, bold: boolean?): TextLabel
	local item = Primitives.Label(parent, value, size, if bold then Theme.Text else Theme.TextMuted, bold)
	item.LayoutOrder = order
	item.Size = UDim2.fromScale(1, 0)
	item.AutomaticSize = Enum.AutomaticSize.Y
	item.TextWrapped = true
	return item
end

function BridgeWindow.new(widget: DockWidgetPluginGui)
	local window = Layout.Mount(widget)
	local tabber = window.Tabber
	local header = tabber.TabBar.ContentFrame
	header.Text.Visible = false
	local version = Primitives.Label(header, "RoGoal  v" .. Defaults.Version, 11, Theme.Text, true)
	version.Position = UDim2.fromOffset(16, 0)
	version.Size = UDim2.new(1, -64, 1, 0)
	version.TextTruncate = Enum.TextTruncate.AtEnd

	local body = tabber.TabBody.Body :: Frame
	body.Text:Destroy()
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Connection"
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundColor3 = Theme.Background
	scroll.BorderSizePixel = 0
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Theme.BorderStrong
	scroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	scroll.Parent = body

	local content = Instance.new("Frame")
	content.Size = UDim2.fromScale(1, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.BackgroundTransparency = 1
	content.Parent = scroll
	Layout.Padding(content, 16, 16, 18, 18)
	Layout.List(content, 10)

	local title = label(content, "Connect to RoGoal", 17, 1, true)
	local instructions = label(content, "Enter the six-digit code shown in the Windows app.", 12, 2)
	local code = Primitives.Input(content, "Six-digit code", 124)
	code.Size = UDim2.new(1, 0, 0, 36)
	code.LayoutOrder = 3
	code.MultiLine = false

	local connect = Primitives.Button(content, "Connect", 104, "Primary")
	connect.Size = UDim2.new(1, 0, 0, 36)
	connect.LayoutOrder = 4

	local disconnect = Primitives.Button(content, "Disconnect", 104, "Secondary")
	disconnect.Size = UDim2.new(1, 0, 0, 36)
	disconnect.LayoutOrder = 4
	disconnect.Visible = false

	local status = label(content, "", 11, 5)
	status.Visible = false

	return setmetatable({
		_window = window,
		_title = title,
		_instructions = instructions,
		_status = status,
		_busy = false,
		_connected = false,
		CodeBox = code,
		ConnectButton = connect,
		DisconnectButton = disconnect,
	}, BridgeWindow)
end

function BridgeWindow:SetBusy(busy: boolean)
	self._busy = busy
	self.ConnectButton.Text = if busy then "Connecting..." else "Connect"
	Primitives.SetButtonEnabled(self.ConnectButton, not busy)
	self.CodeBox.TextEditable = not busy and not self._connected
end

function BridgeWindow:SetConnected(connected: boolean)
	self._connected = connected
	self.ConnectButton.Visible = not connected
	self.DisconnectButton.Visible = connected
	self.CodeBox.Visible = not connected
	self.CodeBox.TextEditable = not connected and not self._busy
	if connected and self.CodeBox.Text ~= "" then
		self.CodeBox.Text = ""
	end
	self._title.Text = if connected then "Studio connected" else "Connect to RoGoal"
	self._instructions.Text = if connected then "Use Paste AI response in the Windows app to import folders and scripts."
		else "Enter the six-digit code shown in the Windows app."
end

function BridgeWindow:SetStatus(message: string, isError: boolean?)
	local lowered = string.lower(message)
	local warning = isError or string.find(lowered, "failed", 1, true)
		or string.find(lowered, "interruption", 1, true)
		or string.find(lowered, "expired", 1, true)
		or string.find(lowered, "unavailable", 1, true)
		or string.find(lowered, "could not", 1, true)
		or string.find(lowered, "limit", 1, true)

	self._status.Visible = message ~= "" and message ~= "Disconnected"
	self._status.Text = message
	self._status.TextColor3 = if warning then Theme.Warning else Theme.TextMuted
end

function BridgeWindow:GetWindow(): Frame
	return self._window
end

function BridgeWindow:Destroy()
	self._window:Destroy()
end

return BridgeWindow
