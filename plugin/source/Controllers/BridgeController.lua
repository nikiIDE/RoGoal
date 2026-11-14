--!strict

local Root = script.Parent.Parent
local Maid = require(Root.Packages.Maid)
local StudioBridge = require(Root.Services.StudioBridge)
local BridgeWindow = require(Root.UI.BridgeWindow)
local Theme = require(Root.UI.Theme)
local Defaults = require(Root.Config.Defaults)
local SettingsService = require(Root.Core.SettingsService)
local ThemeService = require(Root.Core.ThemeService)
local CommandService = require(Root.Core.CommandService)
local ShortcutService = require(Root.Core.ShortcutService)
local VertexShell = require(Root.UI.VertexShell)

local BridgeController = {}
BridgeController.__index = BridgeController

local function messageText(value: any): string
	local content = tostring(value)
	return content:match("([^\n]+)$") or content
end

function BridgeController.new(pluginObject: Plugin, widget: DockWidgetPluginGui)
	local settings = SettingsService.new(pluginObject, Defaults)
	local themeService = ThemeService.new(settings, Theme)
	themeService:Initialize()

	local window = BridgeWindow.new(widget)
	local service = StudioBridge.new()
	local commands = CommandService.new()
	local shortcuts = ShortcutService.new(pluginObject, widget)
	themeService:SetPreset(themeService:GetActivePreset(), widget)
	local shell = VertexShell.new(
		widget,
		window:GetWindow(),
		settings,
		themeService,
		commands,
		shortcuts,
		function(message, isError) window:SetStatus(message, isError) end
	)

	return setmetatable({
		_maid = Maid.new(),
		_window = window,
		_service = service,
		_settings = settings,
		_themeService = themeService,
		_commandService = commands,
		_shortcutService = shortcuts,
		_shell = shell,
		_busy = false,
		_destroyed = false,
	}, BridgeController)
end

function BridgeController:_connect()
	local window = self._window
	local service = self._service
	if self._busy or not window or not service or service:IsConnected() then
		return
	end

	local pairingCode = string.gsub(window.CodeBox.Text, "%s", "")
	if not pairingCode:match("^%d%d%d%d%d%d$") then
		window:SetStatus("Enter the six-digit pairing code from Windows.", true)
		return
	end

	self._busy = true
	window:SetBusy(true)
	window:SetStatus("Pairing with desktop...")

	task.spawn(function()
		local ran, connected, result = xpcall(function()
			return service:Connect(pairingCode)
		end, debug.traceback)
		if self._destroyed then
			if service:IsConnected() then
				service:Disconnect(true)
			end
			return
		end

		self._busy = false
		window:SetBusy(false)
		local success = ran and connected == true
		window:SetConnected(success or service:IsConnected())
		if success then
			window:SetStatus("Connected. Synchronizing the Explorer...")
		else
			local errorMessage = messageText(if ran then result else connected)
			window:SetStatus("Connection failed: " .. errorMessage)
		end
	end)
end

function BridgeController:_disconnect()
	local service = self._service
	if not service or self._destroyed then
		return
	end
	service:Disconnect(true)
	local window = self._window
	if window then
		window:SetConnected(false)
		window:SetStatus("Disconnected")
	end
end

function BridgeController:Start()
	local maid = self._maid
	local window = self._window
	local service = self._service
	local commands = self._commandService
	if not maid or not window or not service or not commands then
		return
	end

	maid:Give(window.ConnectButton.Activated:Connect(function()
		self:_connect()
	end))
	maid:Give(window.DisconnectButton.Activated:Connect(function()
		self:_disconnect()
	end))
	maid:Give(window.CodeBox.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then
			self:_connect()
		end
	end))
	maid:Give(service.StateChanged.Event:Connect(function(status: string)
		if self._destroyed or not self._window then
			return
		end
		window:SetConnected(service:IsConnected())
		window:SetStatus(status)
	end))

	maid:Give(commands:Register({
		id = "bridge.connect",
		title = "Connect to Desktop",
		description = "Pair this Studio session with the local RoGoal app",
		keywords = {"studio", "desktop", "pair", "sync"},
		action = function() self:_connect() end,
	}))
	maid:Give(commands:Register({
		id = "bridge.disconnect",
		title = "Disconnect Desktop",
		description = "Release the active RoGoal session",
		keywords = {"disconnect", "session", "stop"},
		action = function() self:_disconnect() end,
	}))

	window:SetConnected(service:IsConnected())
	window:SetStatus("Disconnected")
end


function BridgeController:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true

	local maid = self._maid
	self._maid = nil
	if maid then maid:Destroy() end

	local shell = self._shell
	self._shell = nil
	if shell then shell:Destroy() end

	local service = self._service
	self._service = nil
	if service then service:Destroy() end

	local window = self._window
	self._window = nil
	if window then window:Destroy() end

	local shortcuts = self._shortcutService
	self._shortcutService = nil
	if shortcuts then shortcuts:Destroy() end

	local commands = self._commandService
	self._commandService = nil
	if commands then commands:Destroy() end

	local themeService = self._themeService
	self._themeService = nil
	if themeService then themeService:Destroy() end

	local settings = self._settings
	self._settings = nil
	if settings then settings:Destroy() end
end

return BridgeController
