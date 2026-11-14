--!strict

local RunService = game:GetService("RunService")

local pluginContext = plugin
if pluginContext == nil or not RunService:IsStudio() or not RunService:IsEdit() then
	return
end

local Root = script.Parent
local Product = require(Root.Config.Product)
local toolbar = pluginContext:CreateToolbar(Product.Name)
local button = toolbar:CreateButton(Product.WidgetId .. ".Toggle", "Open " .. Product.Name, Product.Icon, Product.Name)
button.ClickableWhenViewportHidden = true

local controller: any
local widget: DockWidgetPluginGui?
local initializing = false
local alive = true

local function destroyController()
	local active = controller
	controller = nil
	if active then
		active:Destroy()
	end
end

local function toggle()
	if not alive or not RunService:IsEdit() or initializing then
		return
	end
	if widget and controller then
		widget.Enabled = not widget.Enabled
		return
	end

	initializing = true
	local ok, err = xpcall(function()
		local panel = widget
		if not panel then
			local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, true, 420, 390, 352, 300)
			panel = pluginContext:CreateDockWidgetPluginGuiAsync(Product.WidgetId, info)
			if not alive then
				panel:Destroy()
				return
			end
			widget = panel
			panel.Title = Product.Name
			panel.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			panel:GetPropertyChangedSignal("Enabled"):Connect(function()
				button:SetActive(panel.Enabled)
			end)
		end

		if not RunService:IsEdit() then
			return
		end
		local BridgeController = require(Root.Controllers.BridgeController)
		controller = BridgeController.new(pluginContext, panel)
		controller:Start()
		panel.Enabled = true
	end, debug.traceback)
	initializing = false

	if not ok then
		warn(string.format("[%s] %s", Product.Name, tostring(err)))
		destroyController()
		if widget then
			widget.Enabled = false
			widget:ClearAllChildren()
		end
	end
end

button.Click:Connect(toggle)
task.spawn(function()
	while alive do
		if widget and not RunService:IsEdit() then
			if widget.Enabled then
				widget.Enabled = false
			end
			destroyController()
		end
		task.wait(0.15)
	end
end)

pluginContext.Unloading:Connect(function()
	alive = false
	destroyController()
	if widget then
		widget:Destroy()
		widget = nil
	end
end)
