Styler = {}

--- OKAY, so, this fucker.
--- Changing a label for tree elements in this flavour of IMGUI recomputes the _internal_ id, which is different from the IDContext
--- For Tree Elements, the internal id is based exclusively on the label. Change the label, change the id, it behaves like you just created it again
--- If the default open is false and it hasn't seen this id before, guess what, tree element collapses on you even if you didn't click it
--- If it has seen this ID before, it'll set the state to its last known state, and if the filter has 5 selected, but another filter removes 1 possible option, it closes/opens on you
--- I tried using a separate text element with absolute positioning and overlap, but collapsible tree elements are actually two distinct ui elements - only one shows when it's collapsed,
--- but when you open it the main "collapsible" element gets shunted down a row and the "collapsible" is replaced by a totally separate element. This means any elements next to the initial
--- element get shunted down a row alongside the original collapsible - using visible hacks on the text element was ugly and would briefly show the element to users on each label change
---@param tree ExtuiTree
---@return ExtuiTree, fun(count: number)
function Styler:DynamicLabelTree(tree)
	local label = tree.Label
	tree.DefaultOpen = true
	tree:SetOpen(false, "Always")

	tree.SpanFullWidth = true

	local isOpen = false
	tree.OnClick = function()
		isOpen = not isOpen
	end

	tree.OnCollapse = function()
		tree:SetOpen(isOpen, "Always")
	end

	return tree, function(count)
		tree.Label = label .. (count > 0 and (" - " .. count .. " " .. Translator:translate("selected")) or "")
		tree.DefaultOpen = true
		tree:SetOpen(isOpen, "Always")
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
	displayTable:AddColumn("", "WidthFixed", 300 * self:ScaleFactor())
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

	for key, value in TableUtils:OrderedPairs(resource, function(key)
		return tonumber(key) or key
	end) do
		local subTable = Styler:TwoColumnTable(parent)

		if type(value) == "table" then
			for name, subValue in TableUtils:OrderedPairs(value, function(key)
				return tonumber(key) or key
			end) do
				local subRow = subTable:AddRow()
				subRow:AddCell():AddText(name)

				local valueCell = subRow:AddCell()
				EntityManager:RenderDisplayableValue(valueCell, subValue, name)

				if #valueCell.Children == 0 then
					subRow:Destroy()
				end
			end
		elseif (value ~= "" and value ~= "00000000-0000-0000-0000-000000000000") and (type(value) ~= "number" or value > 0) then
			local subRow = subTable:AddRow()
			subRow:AddCell():AddText(key)
			local displayCell = subRow:AddCell()
			EntityManager:RenderDisplayableValue(displayCell, value, key)
			if #displayCell.Children == 0 then
				displayCell:AddText(tostring(value)).TextWrapPos = 800 * self:ScaleFactor()
			end
		end

		if #subTable.Children == 0 then
			subTable:Destroy()
		end
	end
end

function Styler:ScaleFactor()
	-- testing monitor for development is 1440p
	return Ext.IMGUI.GetViewportSize()[2] / 1440
end

---@param parent ExtuiTreeParent
---@param text string
---@param tooltipCallback fun(parent: ExtuiTreeParent)
---@return ExtuiSelectable
function Styler:HyperlinkText(parent, text, tooltipCallback)
	---@type ExtuiSelectable
	local fakeTextSelectable = parent:AddSelectable(text)
	fakeTextSelectable.Size = { (#text * 10) * Styler:ScaleFactor(), 0 }

	fakeTextSelectable:SetColor("ButtonActive", { 1, 1, 1, 0 })
	fakeTextSelectable:SetColor("ButtonHovered", { 1, 1, 1, 0 })
	fakeTextSelectable:SetColor("FrameBgHovered", { 1, 1, 1, 0 })
	fakeTextSelectable:SetColor("FrameBgActive", { 1, 1, 1, 0 })
	fakeTextSelectable:SetColor("Text", { 173 / 255, 216 / 255, 230 / 255, 1 })

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
		fakeTextSelectable.Selected = false

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
