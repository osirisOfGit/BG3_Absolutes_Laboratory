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
---@param resource Resource
---@param resourceType string?
function Styler:SimpleRecursiveTwoColumnTable(parent, resource, resourceType)
	if TableUtils:CountElements(resource) >= 10 then
		parent = parent:AddCollapsingHeader(resourceType or "")
		parent:SetColor("Header", { 1, 1, 1, 0 })
	end

	local subTable = Styler:TwoColumnTable(parent)
	subTable.Borders = false
	subTable.BordersInnerH = true
	for key, value in TableUtils:OrderedPairs(resource, function(key)
		return tonumber(key) or key
	end) do
		local row = subTable:AddRow()

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
	inputText:SetColor("FrameBg", {1, 1, 1, 0})
	return inputText
end

function Styler:ScaleFactor()
	-- testing monitor for development is 1440p
	return Ext.IMGUI.GetViewportSize()[2] / 1440
end

---@param parent ExtuiTreeParent
---@param text string
---@param tooltipCallback fun(parent: ExtuiTreeParent)
---@param freeSize boolean?
---@return ExtuiSelectable
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

	---@type ExtuiTooltip?
	local tooltip

	---@type ExtuiWindow?
	local window

	fakeTextSelectable.OnHoverEnter = function()
		if not window then
			if not tooltip then
				tooltip = fakeTextSelectable:Tooltip()
				tooltipCallback(tooltip)
			end
		else
			window.Open = true
			window:SetFocus()
		end
	end

	fakeTextSelectable.OnHoverLeave = function()
		if tooltip and not tooltip.Visible then
			Helpers:KillChildren(tooltip)
		end
	end

	fakeTextSelectable.OnClick = function()
		if Ext.Utils.Version() < 25 then
			fakeTextSelectable.Selected = false
		end

		window = Ext.IMGUI.NewWindow(text)
		window.IDContext = parent.IDContext .. text
		window.Closeable = true
		window.AlwaysAutoResize = true

		window.OnClose = function()
			window:Destroy()
			window = nil
		end

		tooltipCallback(window)
	end

	return fakeTextSelectable
end
