--!strict

local Root = script.Parent.Parent
local Theme = require(Root.UI.Theme)
local Primitives = require(Root.UI.Primitives)
local Layout = require(Root.UI.ReferenceLayout)
local Defaults = require(Root.Config.Defaults)

local BridgeWindow = {}
BridgeWindow.__index = BridgeWindow

local function frame(parent: Instance, name: string, size: UDim2): Frame
	local object = Instance.new("Frame")
	object.Name = name
	object.Size = size
	object.BackgroundTransparency = 1
	object.Parent = parent
	return object
end

local function text(parent: Instance, name: string, value: string, size: number, color: Color3, order: number, bold: boolean?): TextLabel
	local label = Primitives.Label(parent, value, size, color, bold)
	label.Name = name
	label.LayoutOrder = order
	label.Size = UDim2.fromScale(1, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.TextWrapped = true
	return label
end

local function card(parent: Instance, name: string, order: number): Frame
	local object = Primitives.Card(parent)
	object.Name = name
	object.Size = UDim2.fromScale(1, 0)
	object.AutomaticSize = Enum.AutomaticSize.Y
	object.LayoutOrder = order
	Layout.Padding(object, 12, 12, 12, 12)
	Layout.List(object, 8)
	return object
end

local function page(body: Frame, name: string, widget: DockWidgetPluginGui): (Frame, Frame)
	local scroll = Layout.NewScroll(body, widget)
	scroll.Name = name
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.Position = UDim2.fromOffset(0, 0)
	local canvas = scroll.ScrollingFrame :: ScrollingFrame
	local content = frame(canvas, "Content", UDim2.fromScale(1, 0))
	content.AutomaticSize = Enum.AutomaticSize.Y
	Layout.Padding(content, 10, 10, 10, 10)
	Layout.List(content, 10)
	return scroll, content
end

function BridgeWindow.new(widget: DockWidgetPluginGui)
	local window = Layout.Mount(widget)
	local tabber = window.Tabber
	local body = tabber.TabBody.Body :: Frame
	body.Text:Destroy()

	local pairingPage, pairing = page(body, "Pairing", widget)
	local sessionPage, session = page(body, "Session", widget)

	local pairCard = card(pairing, "PairDesktop", 1)
	local pairTitle = text(pairCard, "Title", "Connect to the desktop app", 17, Theme.Text, 1, true)
	local instructions = text(pairCard, "Instructions", "Open RoGoal on Windows and enter the six-digit pairing code shown there.", 14, Theme.TextMuted, 2)

	local controls = frame(pairCard, "PairingControls", UDim2.new(1, 0, 0, 32))
	controls.LayoutOrder = 3
	Layout.List(controls, 8, true)
	local code = Primitives.Input(controls, "Pairing code", 124)
	code.Name = "Code"
	code.LayoutOrder = 1
	code.Size = UDim2.fromOffset(124, 32)
	code.ClearTextOnFocus = false
	Layout.Fill(code)
	code.MultiLine = false

	local connect = Primitives.Button(controls, "Connect", 104, "Primary")
	connect.Name = "Connect"
	connect.LayoutOrder = 2
	connect.Size = UDim2.fromOffset(104, 32)

	local disconnect = Primitives.Button(controls, "Disconnect", 104, "Secondary")
	disconnect.Name = "Disconnect"
	disconnect.LayoutOrder = 2
	disconnect.Size = UDim2.fromOffset(104, 32)
	disconnect.Visible = false

	local statusCard = card(pairing, "PairingStatus", 2)
	local badge = Primitives.Badge(statusCard, "Disconnected")
	badge.LayoutOrder = 1
	local pairStatus = text(statusCard, "Status", "", 14, Theme.TextMuted, 2)

	local sessionCard = card(session, "DesktopSession", 1)
	text(sessionCard, "Title", "Desktop session", 17, Theme.Text, 1, true)
	local sessionStatus = text(sessionCard, "Status", "", 14, Theme.TextMuted, 2)
	text(sessionCard, "Endpoint", Defaults.ServerURL, 13, Theme.TextMuted, 3)

	local capabilities = card(session, "Synchronization", 2)
	text(capabilities, "Title", "Live synchronization", 17, Theme.Text, 1, true)
	text(capabilities, "Description", "Once paired, open scripts in the desktop Explorer. Edits sync between RoGoal and Studio, and recovery copies are stored on this computer.", 14, Theme.TextMuted, 2)

	local tabs: {[string]: Frame}
	local function selectPage(mode: string)
		pairingPage.Visible = mode == "Pairing"
		sessionPage.Visible = mode == "Session"
		Layout.SelectTab(tabs, mode)
	end
	tabs = Layout.BuildTabs(tabber.TabBar, {
		{mode = "Pairing", title = "Pair"},
		{mode = "Session", title = "Session"},
	}, selectPage)
	selectPage("Pairing")

	return setmetatable({
		_window = window,
		_pairTitle = pairTitle,
		_instructions = instructions,
		_badge = badge,
		_pairStatus = pairStatus,
		_sessionStatus = sessionStatus,
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
	self._pairTitle.Text = if connected then "Desktop paired" else "Connect to the desktop app"
	self._instructions.Text = if connected then "Use the desktop Explorer to open scripts in this place." else "Open RoGoal on Windows and enter the six-digit pairing code shown there."
	self._badge.Text = if connected then "Connected" else "Disconnected"
	self._badge.TextColor3 = if connected then Theme.Success else Theme.TextMuted
	self._badge.BackgroundColor3 = if connected then Theme.Success:Lerp(Theme.Surface, 0.82) else Theme.SurfaceActive
end

function BridgeWindow:SetStatus(message: string, isError: boolean?)
	local lowered = string.lower(message)
	local warning = isError or string.find(lowered, "failed", 1, true)
		or string.find(lowered, "interruption", 1, true)
		or string.find(lowered, "expired", 1, true)
		or string.find(lowered, "unavailable", 1, true)
		or string.find(lowered, "could not", 1, true)
		or string.find(lowered, "limit", 1, true)

	for _, label in {self._pairStatus, self._sessionStatus} do
		label.Text = message
		label.TextColor3 = if warning then Theme.Warning else Theme.TextMuted
	end
end

function BridgeWindow:GetWindow(): Frame
	return self._window
end

function BridgeWindow:Destroy()
	self._window:Destroy()
end

return BridgeWindow
