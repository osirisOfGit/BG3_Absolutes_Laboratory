Styler = {}

---@param tree ExtuiTree
---@return ExtuiTree, fun(count: number)
function Styler:DynamicLabelTree(tree)
	local label = tree.Label
	tree.Label = tree.Label .. "###" .. tree.Label
	tree.DefaultOpen = false
	tree.SpanFullWidth = true

	return tree, function(count)
		tree.Label = label .. (count > 0 and (" - " .. count .. " " .. Translator:translate("selected")) or "") .. "###" .. label
	end
end

Translator:RegisterTranslation({
	["selected"] = "h3876382ff8ce409fa821615fe1171de2d3a5",
})

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
			selectable.Font = font
		end
		selectable:SetStyle("SelectableTextAlign", 0.5)
		selectable.Disabled = true

		return selectable
	end
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
---@return number
local function countNumberOfChildrenInTree(parent)
	local counter = 0

	pcall(function()
		local maxChildren = 0
		for _, child in pairs(parent.Children) do
			if child.UserData ~= "collapsed" then
				local children = countNumberOfChildrenInTree(child.UserData == "row" and child.Children[2] or child)
				counter = counter + 1
				if children > maxChildren then
					maxChildren = children
				end
			end
		end
		counter = counter + maxChildren
	end)

	return counter
end

---@param parent ExtuiTreeParent
---@param resource Resource
---@param resourceType string?
function Styler:SimpleRecursiveTwoColumnTable(parent, resource, resourceType)
	local subTable = Styler:TwoColumnTable(parent)
	subTable.Borders = false
	subTable.BordersInnerH = true
	for key, value in TableUtils:OrderedPairs(resource, function(key)
		return tonumber(key) or key
	end) do
		local row = subTable:AddRow()
		row.UserData = "row"

		if type(value) == "table" then
			row:AddCell():AddText(tostring(key))

			local valueCell = row:AddCell()
			EntityManager:RenderDisplayableValue(valueCell, value, key)
			if #valueCell.Children == 0 then
				row:Destroy()
			end
		elseif (value ~= "" and value ~= "00000000-0000-0000-0000-000000000000") and (not tonumber(value) or tonumber(value) > 0) then
			row:AddCell():AddText(key)
			local displayCell = row:AddCell()
			EntityManager:RenderDisplayableValue(displayCell, value, key)
			if #displayCell.Children == 0 then
				Styler:SelectableText(displayCell, resourceType, tostring(value))
			end
		else
			row:Destroy()
		end
	end

	if #subTable.Children == 0 then
		subTable:Destroy()
	elseif parent.UserData ~= "collapsed" and countNumberOfChildrenInTree(subTable) >= 15 then
		parent:DetachChild(subTable)
		parent = parent:AddCollapsingHeader(resourceType or parent.Label or parent.IDContext or "")
		parent.UserData = "collapsed"
		parent:AttachChild(subTable)
		parent:SetColor("Header", { 1, 1, 1, 0 })
	end
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

---@param dimensionalArray number[]?
---@return (number[]|number) dimensionalArray scaled up if present, otherwise it's the scale factor
function Styler:ScaleFactor(dimensionalArray)
	if dimensionalArray then
		for i, v in ipairs(dimensionalArray) do
			dimensionalArray[i] = v * Ext.IMGUI.GetViewportSize()[2] / 1440
		end
		return dimensionalArray
	end
	-- testing monitor for development is 1440p
	return Ext.IMGUI.GetViewportSize()[2] / 1440
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
			Ext.Timer.WaitFor(modifierOnHover and 0 or 400, function()
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
			window.HorizontalScrollbar = true
			window:SetStyle("WindowMinSize", 100 * self:ScaleFactor(), 100 * self:ScaleFactor())
			window:SetSize({ 0, 0 }, "FirstUseEver")
			window.Closeable = true

			window.OnClose = function()
				window:Destroy()
				window = nil
			end

			callback(window)
			return true
		end
	end
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
