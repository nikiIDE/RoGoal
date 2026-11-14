--!strict

local Root = script.Parent.Parent
local Product = require(Root.Config.Product)
local Theme = require(Root.UI.Theme)
local Primitives = require(Root.UI.Primitives)

type Tab = {mode: string, title: string}

local ReferenceLayout = {}

function ReferenceLayout.Padding(parent: Instance, left: number, right: number, top: number, bottom: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, left)
	padding.PaddingRight = UDim.new(0, right)
	padding.PaddingTop = UDim.new(0, top)
	padding.PaddingBottom = UDim.new(0, bottom)
	padding.Parent = parent
	return padding
end

function ReferenceLayout.List(parent: Instance, gap: number, horizontal: boolean?, equalWidths: boolean?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap)
	if horizontal then
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		if equalWidths then
			layout.HorizontalFlex = Enum.UIFlexAlignment.Fill
		end
	end
	layout.Parent = parent
	return layout
end

function ReferenceLayout.Fill(gui: GuiObject)
	local item = Instance.new("UIFlexItem")
	item.FlexMode = Enum.UIFlexMode.Fill
	item.Parent = gui
end

local function getTemplate(): Frame
	return script.Parent.MainGui :: Frame
end

local function lockAppearance(root: Instance)
	root:SetAttribute("ReferenceAppearance", true)
	for _, child in root:GetDescendants() do
		child:SetAttribute("ReferenceAppearance", true)
	end
end

function ReferenceLayout.Mount(widget: DockWidgetPluginGui): Frame
	local root = getTemplate():Clone()
	root.ClipsDescendants = true
	lockAppearance(root)
	root.Parent = widget
	return root
end

function ReferenceLayout.BuildTabs(tabBar: Frame, definitions: {Tab}, onSelected: (string) -> ()): {[string]: Frame}
	local host = tabBar.ContentFrame
	local template = host.Text :: Frame
	template.Parent = nil

	local strip = Instance.new("Frame")
	strip.Name = "Tabs"
	strip.BackgroundTransparency = 1
	strip.Size = UDim2.new(1, -44, 1, 0)
	strip.Parent = host
	ReferenceLayout.List(strip, 0, true, true)

	local tabs: {[string]: Frame} = {}
	for index, definition in definitions do
		local tab = template:Clone()
		tab.Name = definition.mode
		tab.LayoutOrder = index
		tab.Size = UDim2.fromOffset(64, 40)
		tab.ClipsDescendants = true
		tab.Position = UDim2.fromOffset(0, 0)

		local wrap = tab.OuterFrame.ContentFrame.Wrap
		local wrapLayout = wrap.H :: UIListLayout
		wrapLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		wrapLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		local icon = wrap.Icon :: ImageLabel
		icon.Visible = index == 1
		icon.Size = UDim2.fromOffset(22, 22)
		icon.Image = Product.Icon
		icon.ImageColor3 = Color3.new(1, 1, 1)

		local label = wrap:FindFirstChild("Text") :: TextLabel
		label.Text = definition.title
		label.TextSize = 16
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.Size = if index == 1 then UDim2.fromOffset(42, 22) else UDim2.new(1, -8, 0, 22)
		label.TextXAlignment = Enum.TextXAlignment.Center

		local button = tab.StatefulButton :: TextButton
		button.ZIndex = 3
		button.AutoButtonColor = false
		button.Active = true
		button.Selectable = true
		button.Activated:Connect(function()
			onSelected(definition.mode)
		end)

		local inner = tab.OuterFrame.InnerFrame :: Frame
		local function highlight()
			if not tab:GetAttribute("Selected") then
				inner.BackgroundTransparency = 0
			end
		end
		local function removeHighlight()
			if not tab:GetAttribute("Selected") then
				inner.BackgroundTransparency = 1
			end
		end
		button.MouseEnter:Connect(highlight)
		button.SelectionGained:Connect(highlight)
		button.MouseLeave:Connect(removeHighlight)
		button.SelectionLost:Connect(removeHighlight)
		tab.Parent = strip
		tabs[definition.mode] = tab
	end
	template:Destroy()
	return tabs
end

function ReferenceLayout.SelectTab(tabs: {[string]: Frame}, mode: string)
	for name, tab in tabs do
		local selected = name == mode
		tab:SetAttribute("Selected", selected)
		local outer = tab.OuterFrame :: Frame
		local inner = outer.InnerFrame :: Frame
		outer.BackgroundTransparency = if selected then 0 else 1
		inner.BackgroundTransparency = if selected then 0 else 1
		inner.BackgroundColor3 = if selected then Color3.fromRGB(46, 46, 46) else Color3.fromRGB(62, 62, 62)
	end
end

function ReferenceLayout.Empty(parent: GuiObject, message: string): TextLabel
	local label = Primitives.Label(parent, message, 10, Theme.TextFaint, false)
	label.Name = "EmptyMessage"
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Size = UDim2.new(1, -16, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.new(0.5, -8, 0.5, 0)
	return label
end

function ReferenceLayout.SetEmpty(canvas: ScrollingFrame, empty: boolean)
	canvas:SetAttribute("Empty", empty)
	if empty then
		canvas.CanvasPosition = Vector2.zero
	end
end

function ReferenceLayout.BindScroll(scroll: Frame, widget: DockWidgetPluginGui): ScrollingFrame
	local canvas = scroll.ScrollingFrame :: ScrollingFrame
	canvas.AutomaticCanvasSize = Enum.AutomaticSize.Y
	canvas.CanvasSize = UDim2.fromOffset(0, 0)
	canvas.ScrollBarImageTransparency = 1
	canvas.ScrollBarThickness = 16
	canvas.VerticalScrollBarInset = Enum.ScrollBarInset.Always
	canvas.ScrollingDirection = Enum.ScrollingDirection.Y
	canvas.Active = true

	local track = scroll.ScrollBarBackground :: Frame
	local controls = track.ContentFrame
	local thumb = controls.HoverDetector :: TextButton
	local skip = controls.SkipDetector :: TextButton
	local grip = thumb.ScrollBar :: ImageLabel
	local arrows = grip.ContentFrame
	thumb.AutoButtonColor = false
	skip.AutoButtonColor = false
	thumb.Selectable = false
	skip.Selectable = false
	track.ZIndex = canvas.ZIndex + 1
	track.ClipsDescendants = true

	local restingColor = grip.ImageColor3
	local dragOrigin = 0
	local canvasOrigin = 0
	local dragging = false
	local dragger = Instance.new("UIDragDetector")
	dragger.ResponseStyle = Enum.UIDragDetectorResponseStyle.CustomOffset
	dragger.Parent = thumb

	local function scrollRange(): number
		return math.max(0, canvas.AbsoluteCanvasSize.Y - canvas.AbsoluteWindowSize.Y)
	end

	local function moveTo(y: number)
		if canvas.ScrollingEnabled then
			canvas.CanvasPosition = Vector2.new(0, math.clamp(y, 0, scrollRange()))
		end
	end

	local function updateThumb()
		local height = track.AbsoluteSize.Y
		local viewport = canvas.AbsoluteWindowSize.Y
		local range = scrollRange()
		local empty = canvas:GetAttribute("Empty") == true
		local scrollable = not empty and height > 0 and viewport > 0 and range > 0.5
		canvas.ScrollingEnabled = scrollable
		thumb.Active = scrollable
		thumb.Interactable = scrollable
		skip.Visible = scrollable
		skip.Active = scrollable
		dragger.Enabled = scrollable
		if not scrollable then
			dragging = false
			thumb.Visible = empty
			thumb.Position = UDim2.fromOffset(0, 0)
			thumb.Size = UDim2.fromScale(1, 1)
			grip.ImageColor3 = Color3.fromRGB(49, 49, 49)
			arrows.Visible = false
			return
		end

		local thumbHeight = math.min(height, math.max(28, math.floor(height * viewport / (viewport + range))))
		local fraction = math.clamp(canvas.CanvasPosition.Y / range, 0, 1)
		thumb.Visible = true
		thumb.Position = UDim2.fromOffset(0, math.round((height - thumbHeight) * fraction))
		thumb.Size = UDim2.new(1, 0, 0, thumbHeight)
		grip.ImageColor3 = if dragging then Color3.fromRGB(92, 92, 92) else restingColor
		arrows.Visible = thumbHeight >= 28
	end

	dragger.DragStart:Connect(function(position)
		dragOrigin = position.Y
		canvasOrigin = canvas.CanvasPosition.Y
		dragging = true
		updateThumb()
	end)
	dragger.DragContinue:Connect(function(position)
		local travel = track.AbsoluteSize.Y - thumb.AbsoluteSize.Y
		if dragging and travel > 0 then
			moveTo(canvasOrigin + (position.Y - dragOrigin) * scrollRange() / travel)
		end
	end)
	dragger.DragEnd:Connect(function()
		dragging = false
		updateThumb()
	end)
	skip.Activated:Connect(function()
		local y = widget:GetRelativeMousePosition().Y + widget.AbsolutePosition.Y
		local page = canvas.AbsoluteWindowSize.Y
		moveTo(canvas.CanvasPosition.Y + (if y < thumb.AbsolutePosition.Y then -page else page))
	end)
	for _, zone in {skip, thumb} do
		zone.MouseWheelForward:Connect(function()
			moveTo(canvas.CanvasPosition.Y - 48)
		end)
		zone.MouseWheelBackward:Connect(function()
			moveTo(canvas.CanvasPosition.Y + 48)
		end)
	end
	canvas:GetPropertyChangedSignal("CanvasPosition"):Connect(updateThumb)
	canvas:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updateThumb)
	canvas:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(updateThumb)
	canvas:GetAttributeChangedSignal("Empty"):Connect(updateThumb)
	track:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateThumb)
	updateThumb()
	return canvas
end

function ReferenceLayout.NewScroll(parent: GuiObject, widget: DockWidgetPluginGui): Frame
	local template = getTemplate().Tabber.TabBody.Body.Text.Scroll :: Frame
	local scroll = template:Clone()
	lockAppearance(scroll)
	scroll.Parent = parent
	ReferenceLayout.BindScroll(scroll, widget)
	return scroll
end

return ReferenceLayout
