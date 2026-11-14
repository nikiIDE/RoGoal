--!strict

export type Shortcut = {
	id: string,
	title: string,
	description: string?,
	callback: () -> (),
	isEnabled: (() -> boolean)?,
}

type ActionBinding = {
	action: PluginAction,
	connection: RBXScriptConnection?,
}

local ShortcutService = {}
ShortcutService.__index = ShortcutService

export type ShortcutService = typeof(setmetatable({
	_plugin = nil :: Plugin?,
	_widget = nil :: DockWidgetPluginGui?,
	_actions = {} :: {[string]: ActionBinding},
}, ShortcutService))

function ShortcutService.new(plugin: Plugin, widget: DockWidgetPluginGui): ShortcutService
	return setmetatable({
		_plugin = plugin,
		_widget = widget,
		_actions = {},
	}, ShortcutService)
end

function ShortcutService:Register(shortcut: Shortcut): () -> ()
	local plugin = self._plugin
	local widget = self._widget
	if not plugin or not widget then
		return function() end
	end

	local binding = self._actions[shortcut.id]
	if not binding then
		binding = {
			action = plugin:CreatePluginAction(shortcut.id, shortcut.title, shortcut.description or "", "", true),
			connection = nil,
		}
		self._actions[shortcut.id] = binding
	end

	local previous = binding.connection
	if previous then
		previous:Disconnect()
	end
	local connection = binding.action.Triggered:Connect(function()
		if widget.Enabled and (not shortcut.isEnabled or shortcut.isEnabled()) then
			shortcut.callback()
		end
	end)
	binding.connection = connection
	return function()
		connection:Disconnect()
		if binding.connection == connection then
			binding.connection = nil
		end
	end
end

function ShortcutService:Destroy()
	for _, binding in self._actions do
		if binding.connection then
			binding.connection:Disconnect()
		end
		binding.action:Destroy()
	end
	table.clear(self._actions)
	self._widget = nil
	self._plugin = nil
end

return ShortcutService
