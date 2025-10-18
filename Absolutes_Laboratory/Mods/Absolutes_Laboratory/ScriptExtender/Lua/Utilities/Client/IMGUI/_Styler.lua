Styler = {}

---@param tree ExtuiTree
---@return ExtuiTree, fun(count: number)
function Styler:DynamicLabelTree(tree)
	local label = tree.Label
	tree.Label = tree.Label .. "###" .. tree.Label
	tree.DefaultOpen = false
	tree.SpanFullWidth = true

	return tree, function(count)
		tree.Label = label .. (count > 0 and (" - " .. count .. " " .. (Translator.translationTable["selected"] and Translator:translate("selected") or "selected")) or "") .. "###" .. label
	end
end

---@param imageButton ExtuiImageButton
function Styler:ImageButton(imageButton)
	imageButton.Background = { 0, 0, 0, 0 }
	imageButton:SetColor("Button", { 0, 0, 0, 0 })

	return imageButton
end

---@param text string
---@param parent ExtuiTreeParent
---@param font string?
function Styler:CheapTextAlign(text, parent, font)
	if text and text ~= "" then
		---@type ExtuiSelectable
		local selectable = parent:AddSelectable(text)
		if font then
			Styler:ScaledFont(selectable, font)
		end
		selectable:SetStyle("SelectableTextAlign", 0.5)
		selectable.Disabled = true

		return selectable
	end
end

---@param parent ExtuiTreeParent
---@return ExtuiPopup
function Styler:Popup(parent)
	local popup = parent:AddPopup("")
	popup.NoSavedSettings = true
	popup:SetColor("PopupBg", { 0, 0, 0, 1 })
	popup:SetColor("Border", { 1, 0, 0, 0.5 })
	popup:SetColor("ChildBg", { 0, 0, 0, 1 })
	return popup
end

---@param parent ExtuiTreeParent
---@param ... fun(ele: ExtuiTableCell)|string
---@return ExtuiTable
function Styler:MiddleAlignedColumnLayout(parent, ...)
	local table = parent:AddTable("", 3)
	table.NoSavedSettings = true

	table:AddColumn("", "WidthStretch")
	table:AddColumn("", "WidthFixed")
	table:AddColumn("", "WidthStretch")

	for _, uiElement in pairs({ ... }) do
		local row = table:AddRow()
		row:AddCell()

		if type(uiElement) == "function" then
			uiElement(row:AddCell())
		elseif type(uiElement) == "string" then
			row:AddCell():AddText(uiElement)
		end

		row:AddCell()
	end

	return table
end

---@param parent ExtuiTreeParent
---@return ExtuiTable
function Styler:TwoColumnTable(parent, id)
	local displayTable = parent:AddTable("twoCol" .. parent.IDContext .. (id or ""), 2)
	displayTable.NoSavedSettings = true
	displayTable.Borders = true
	displayTable.Resizable = true
	displayTable:SetColor("TableBorderStrong", { 0.56, 0.46, 0.26, 0.78 })
	displayTable:AddColumn("", "WidthFixed")
	displayTable:AddColumn("", "WidthStretch")

	return displayTable
end

---@param parent ExtuiTreeParent
---@param id string?
---@param text string
---@return ExtuiInputText
function Styler:SelectableText(parent, id, text)
	local inputText = parent:AddInputText("##" .. (id or text), tostring(text))
	inputText.AutoSelectAll = true
	inputText.ItemReadOnly = true
	inputText.SizeHint = { #text * 15, 0 }
	inputText:SetColor("FrameBg", { 1, 1, 1, 0 })
	return inputText
end

---@param parent ExtuiTreeParent
---@param text string
---@param tooltipCallback fun(parent: ExtuiTreeParent)
---@param freeSize boolean?
---@return ExtuiSelectable|ExtuiTextLink
function Styler:HyperlinkText(parent, text, tooltipCallback, freeSize)
	local fakeTextSelectable
	if Ext.Utils.Version() >= 25 then
		---@type ExtuiTextLink
		fakeTextSelectable = parent:AddTextLink(text)
	else
		---@type ExtuiSelectable
		fakeTextSelectable = parent:AddSelectable(text)
		if not freeSize then
			fakeTextSelectable.Size = { (#text * 10) * Styler:ScaleFactor(), 0 }
		end

		fakeTextSelectable:SetColor("ButtonActive", { 1, 1, 1, 0 })
		fakeTextSelectable:SetColor("ButtonHovered", { 1, 1, 1, 0 })
		fakeTextSelectable:SetColor("FrameBgHovered", { 1, 1, 1, 0 })
		fakeTextSelectable:SetColor("FrameBgActive", { 1, 1, 1, 0 })
		fakeTextSelectable:SetColor("Text", { 173 / 255, 216 / 255, 230 / 255, 1 })
	end

	fakeTextSelectable.OnClick = self:HyperlinkRenderable(fakeTextSelectable, text, nil, nil, nil, tooltipCallback)

	return fakeTextSelectable
end

---@param renderable ExtuiStyledRenderable
---@param item string
---@param modifier InputModifier?
---@param modifierOnHover boolean?
---@param callback fun(parent: ExtuiTreeParent)
---@param altTooltip string?
---@return fun():boolean?
function Styler:HyperlinkRenderable(renderable, item, modifier, modifierOnHover, altTooltip, callback)
	-- Used in MutationDesigner to ensure hover events fire for links when viewing mod-added mutations
	if not renderable.UserData then
		renderable.UserData = "EnableForMods"
	end

	---@type ExtuiTooltip
	local tooltip = renderable:Tooltip()

	---@type ExtuiWindow?
	local window

	local killTimer
	renderable.OnHoverEnter = function()
		if killTimer then
			Ext.Timer.Cancel(killTimer)
			killTimer = nil
			return
		end
		if not modifier or not modifierOnHover or Ext.ClientInput.GetInputManager().PressedModifiers == modifier then
			Ext.Timer.WaitFor(modifierOnHover and 0 or 500, function()
				if not window then
					Helpers:KillChildren(tooltip)
					tooltip.Visible = true
					callback(tooltip)
				else
					window.Open = true
					window:SetFocus()
				end
			end)
		else
			Helpers:KillChildren(tooltip)
			if altTooltip then
				tooltip:AddText("\t " .. altTooltip)
			else
				tooltip.Visible = false
			end
		end
	end

	renderable.OnHoverLeave = function()
		if killTimer then
			Ext.Timer.Cancel(killTimer)
		end
		killTimer = Ext.Timer.WaitFor(100, function()
			Helpers:KillChildren(tooltip)
			killTimer = nil
		end)
	end

	return function()
		if not modifier or Ext.ClientInput.GetInputManager().PressedModifiers == modifier then
			window = Ext.IMGUI.NewWindow(item)
			window.Scaling = "Scaled"
			window.NoSavedSettings = true
			window.HorizontalScrollbar = true
			window:SetStyle("WindowMinSize", 100 * self:ScaleFactor(), 100 * self:ScaleFactor())
			window:SetSize({ 0, 0 }, "FirstUseEver")
			window.Closeable = true
			if MCM then
				window.Font = MCM.Get("font_size", "755a8a72-407f-4f0d-9a33-274ac0f0b53d")
			end
			window.OnClose = function()
				window:Destroy()
				window = nil
			end

			callback(window)
			return true
		end
	end
end

---@param parent ExtuiTreeParent
---@param opt1 string
---@param opt2 string
---@param startSameLine boolean
---@param callback fun(swap: boolean?): boolean
function Styler:DualToggleButton(parent, opt1, opt2, startSameLine, callback)
	local option1 = parent:AddButton(opt1)
	option1.AllowDuplicateId = true
	option1.Disabled = true
	self:Color(option1, "DisabledButton")
	option1.SameLine = startSameLine or false

	local toggle = parent:AddSliderInt("", callback() and 0 or 1, 0, 1)
	toggle:SetColor("Text", { 1, 1, 1, 0 })
	toggle.SameLine = true
	toggle.AllowDuplicateId = true
	toggle.ItemWidth = 80 * Styler:ScaleFactor()
	toggle.UserData = "EnableForMods"

	local option2 = parent:AddButton(opt2)
	option2.AllowDuplicateId = true
	option2.Disabled = true
	self:Color(option2, "ActiveButton")
	option2.SameLine = true

	if callback() then
		self:Color(option1, "ActiveButton")
		self:Color(option2, "DisabledButton")
	else
		self:Color(option1, "DisabledButton")
		self:Color(option2, "ActiveButton")
	end

	toggle.OnActivate = function()
		-- Prevents the user from keeping hold of the grab, triggering the Deactivate instantly
		-- Slider Grab POS won't update if changed during an OnClick or OnActivate event
		toggle.Disabled = true
	end

	toggle.OnDeactivate = function()
		toggle.Disabled = false

		local useFirstOption = not callback()
		local newValue = useFirstOption and 0 or 1
		toggle.Value = { newValue, newValue, newValue, newValue }

		if useFirstOption then
			self:Color(option1, "ActiveButton")
			self:Color(option2, "DisabledButton")
		else
			self:Color(option1, "DisabledButton")
			self:Color(option2, "ActiveButton")
		end

		callback(true)
	end
end

---@param parent ExtuiTreeParent
---@param buttonText string
---@param startSameLine boolean
---@param tooltip string?
---@param callback fun(swap: boolean?): boolean
function Styler:EnableToggleButton(parent, buttonText, startSameLine, tooltip, callback)
	if tooltip then
		buttonText = "(?) " .. buttonText
	end
	local option1 = parent:AddButton(buttonText)
	option1.AllowDuplicateId = true
	option1.Disabled = true
	self:Color(option1, "ActiveButton")
	option1.SameLine = startSameLine or false
	if tooltip then
		option1:Tooltip():AddText("\t " .. tooltip)
	end

	local toggle = parent:AddSliderInt("", callback() and 0 or 1, 0, 1)
	toggle:SetColor("Text", { 1, 1, 1, 0 })
	toggle:SetColor("SliderGrab", { 0, 1, 0.2, 1 })
	toggle.SameLine = true
	toggle.AllowDuplicateId = true
	toggle.ItemWidth = 80 * Styler:ScaleFactor()
	if tooltip then
		toggle:Tooltip():AddText("\t " .. tooltip)
	end

	if callback() then
		self:Color(option1, "ActiveButton")
		toggle:SetColor("SliderGrab", { 0, 1, 0.2, 0.3 })
	else
		self:Color(option1, "DisabledButton")
		toggle:SetColor("SliderGrab", { 1, 0.2, 0, 0.3 })
	end

	toggle.OnActivate = function()
		-- Prevents the user from keeping hold of the grab, triggering the Deactivate instantly
		-- Slider Grab POS won't update if changed during an OnClick or OnActivate event
		toggle.Disabled = true
	end

	toggle.OnDeactivate = function()
		toggle.Disabled = false

		local useFirstOption = not callback()
		local newValue = useFirstOption and 0 or 1
		toggle.Value = { newValue, newValue, newValue, newValue }

		if useFirstOption then
			self:Color(option1, "ActiveButton")
			toggle:SetColor("SliderGrab", { 0, 1, 0.2, 0.30 })
		else
			self:Color(option1, "DisabledButton")
			toggle:SetColor("SliderGrab", { 1, 0.2, 0, 0.30 })
		end

		callback(true)
	end
end

---@param dimensionalArray number[]?
---@return (number[]|number) dimensionalArray scaled up if present, otherwise it's the scale factor
function Styler:ScaleFactor(dimensionalArray)
	if dimensionalArray then
		for i, v in ipairs(dimensionalArray) do
			dimensionalArray[i] = v * (Ext.IMGUI.GetViewportSize()[2] / 1440)
		end
		return dimensionalArray
	end
	-- testing monitor for development is 1440p
	return Ext.IMGUI.GetViewportSize()[2] / 1440
end

---@enum FontSize
Styler.FontSize = {
	["Tiny"] = 1,
	["Small"] = 2,
	["Medium"] = 3,
	["Default"] = 4,
	["Big"] = 5,
	["Large"] = 6,
	"Tiny",
	"Small",
	"Medium",
	"Default",
	"Big",
	"Large"
}

---@generic E : ExtuiStyledRenderable
---@param element E
---@param elefontSize FontSize
---@return E
function Styler:ScaledFont(element, elefontSize)
	local mcmFontSize = Styler.FontSize[MCM.Get("font_size", "755a8a72-407f-4f0d-9a33-274ac0f0b53d")]
	local targetFontDiff = Styler.FontSize[elefontSize] - Styler.FontSize["Default"]

	element.Font = self.FontSize[math.max(1, math.min(#Styler.FontSize, mcmFontSize + targetFontDiff))]
	return element
end

---@param colour number[]
function Styler:ConvertRGBAToIMGUI(colour)
	for i, col in ipairs(colour) do
		if i < 4 and col > 1 then
			colour[i] = col / 255
		end
	end
	return colour
end

---@class StylerColors
Styler.Colours = {
	PlainLink = function(link)
		link:SetColor("TextLink", { 0.86, 0.79, 0.68, 0.78 })
	end,
	ActiveButton = function(button)
		button:SetColor("Button", { 0.38, 0.26, 0.21, 0.78 })
	end,
	DisabledButton = function(button)
		button:SetColor("Button", { 0, 0, 0, 0 })
	end,
	ErrorText = function(text)
		text:SetColor("Text", { 1, 0.02, 0, 1 })
	end,
}

---@generic Ele : ExtuiStyledRenderable
---@param element Ele
---@param property string|"PlainLink"|"ActiveButton"|"DisabledButton"|"ErrorText"
---@param color number[]?
---@return Ele
function Styler:Color(element, property, color)
	if not color then
		Styler.Colours[property](element)
	else
		element:SetColor(property, self:ConvertRGBAToIMGUI(color))
	end
	return element
end

--- Credit to Mazzle (RangeFinder, EzDocs) for this
---@param text string
---@param min_width number?
---@return number optimal width
---@return integer height
function Styler:calculateTextDimensions(text, min_width)
	local base_line_height = 21 -- Base line height
	local base_padding = 0   -- Base padding for InputText widget
	local line_padding = 0.0 -- Additional padding per line for multiline InputText
	local min_height = 30    -- Minimum height for single line
	local max_height = 1600  -- Maximum height to prevent huge blocks
	local char_width = 11
	local width_padding = 20
	min_width = min_width or 400

	-- Initialize variables for both calculations
	local line_count = 0
	local max_line_length = 0

	-- Normalize line endings and split into lines
	local normalized_text = (text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")

	-- Function to calculate visual width of a line (accounting for tabs)
	local function calculate_visual_width(line)
		local visual_width = 0
		local tab_size = 4 -- Standard tab size (4 spaces)

		for i = 1, #line do
			local char = line:sub(i, i)
			if char == '\t' then
				-- Tab expands to next multiple of tab_size
				local spaces_to_next_tab = tab_size - (visual_width % tab_size)
				visual_width = visual_width + spaces_to_next_tab
			else
				visual_width = visual_width + 1
			end
		end

		return visual_width
	end

	-- Handle empty text case
	if normalized_text == "" then
		line_count = 1
		max_line_length = 0
	else
		-- Split text into lines and process in single pass
		for line in (normalized_text .. "\n"):gmatch("([^\n]*)\n") do
			line_count = line_count + 1
			local visual_width = calculate_visual_width(line)
			max_line_length = math.max(max_line_length, visual_width)
		end
	end

	-- Calculate optimal width based on content
	local estimated_content_width = max_line_length * char_width
	local optimal_width = math.max(min_width, estimated_content_width + width_padding)

	-- Calculate height with scaling padding for multiline content
	local scaling_padding = base_padding + (line_count * line_padding)
	local calculated_height = (line_count * base_line_height) + scaling_padding
	calculated_height = math.max(min_height, math.min(calculated_height, max_height))

	return optimal_width, calculated_height
end
