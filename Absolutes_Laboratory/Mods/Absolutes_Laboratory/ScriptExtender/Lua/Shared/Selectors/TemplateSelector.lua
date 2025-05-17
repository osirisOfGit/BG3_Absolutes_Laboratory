TemplateSelector = SelectorInterface:new("Templates")

---@class TemplateCriteria
---@field id GUIDSTRING
---@field includeChildren boolean

---@class TemplateSelector : SelectorInterface
---@field criteriaValue TemplateCriteria[]

local templates = {}
local translationMap = {}
local childRelationships = {}

local function init()
	if not next(templates) then
		for _, template in pairs(Ext.ClientTemplate.GetAllRootTemplates()) do
			if template.TemplateType == "character" and not string.find(template.Name, "Timeline") then
				---@cast template CharacterTemplate

				table.insert(templates, template.Id)
				local name = template.Name
				if translationMap[name] then
					name = string.format("%s (%s)", name, template.Id:sub(-5))
				end

				if template.ParentTemplateId ~= "00000000-0000-0000-0000-000000000000" then
					if not childRelationships[template.ParentTemplateId] then
						childRelationships[template.ParentTemplateId] = {}
					end
					table.insert(childRelationships[template.ParentTemplateId], template.Id)
				end

				translationMap[template.Id] = name
				translationMap[name] = template.Id
			end
		end
		table.sort(templates, function(a, b)
			return translationMap[a] < translationMap[b]
		end)
	end
end

---@param parent ExtuiWindow|ExtuiTableCell
---@param templateId GUIDSTRING
local function displayChildTemplates(parent, templateId)
	if childRelationships[templateId] then
		local displayTable = Styler:TwoColumnTable(parent, "children" .. templateId)

		for _, childId in TableUtils:OrderedPairs(childRelationships[templateId], function(key)
			return translationMap[childRelationships[templateId][key]]
		end) do
			local row = displayTable:AddRow()
			Styler:HyperlinkText(row:AddCell(), translationMap[childId], function(parent)
				ResourceManager:RenderDisplayWindow(Ext.Template.GetTemplate(childId), parent)
			end, true)
			displayChildTemplates(row:AddCell(), childId)
		end
	end
end

---@param templateId GUIDSTRING
---@param indent string?
---@return string
local function buildChildTemplatesString(templateId, indent)
	indent = indent or ""
	local result = indent .. (indent ~= "" and "-- " or "") .. translationMap[templateId] .. "\n"
	if childRelationships[templateId] then
		for _, childId in TableUtils:OrderedPairs(childRelationships[templateId], function(key)
			return translationMap[childRelationships[templateId][key]]
		end) do
			result = result .. buildChildTemplatesString(childId, indent .. string.rep(" ", 3) .. "|")
		end
	end
	return result
end

---@param existingSelector TemplateSelector
function TemplateSelector:renderSelector(parent, existingSelector)
	init()

	existingSelector.criteriaValue = existingSelector.criteriaValue or {}

	local updateFunc
	parent, updateFunc = Styler:DynamicLabelTree(parent:AddTree("Templates"))
	parent:SetColor("Header", { 1, 1, 1, 0 })

	local templateTable = Styler:TwoColumnTable(parent, "templates")
	local row = templateTable:AddRow()

	local templateSelectCell = row:AddCell()

	local templateSelectInput = templateSelectCell:AddInputText("")
	templateSelectInput.EscapeClearsAll = true
	templateSelectInput.AutoSelectAll = true

	local infoText = templateSelectCell:AddText("( ? )")
	infoText.SameLine = true
	infoText:Tooltip():AddText("\t Hold shift before hovering to see tooltips")

	local templateSelect = templateSelectCell:AddChildWindow("Templates")
	templateSelect.NoSavedSettings = true

	local templateDisplay = row:AddCell():AddChildWindow("TemplateDisplay")
	templateDisplay.NoSavedSettings = true

	local function displaySelectedTemplates()
		Helpers:KillChildren(templateDisplay)

		for i, templateCriteria in TableUtils:OrderedPairs(existingSelector.criteriaValue, function(key)
			return translationMap[existingSelector.criteriaValue[key].id]
		end) do
			local delete = Styler:ImageButton(templateDisplay:AddImageButton("delete" .. templateCriteria.id, "ico_red_x", { 16, 16 }))
			delete.OnClick = function()
				for x = i, TableUtils:CountElements(existingSelector.criteriaValue) do
					existingSelector.criteriaValue[x].delete = true
					existingSelector.criteriaValue[x] = TableUtils:DeeplyCopyTable(existingSelector.criteriaValue._real[x + 1])
				end

				updateFunc(#existingSelector.criteriaValue)
				displaySelectedTemplates()
			end

			if childRelationships[templateCriteria.id] then
				local includeChildrenCheckbox = templateDisplay:AddCheckbox("##" .. templateCriteria.id, templateCriteria.includeChildren)
				includeChildrenCheckbox.SameLine = true

				includeChildrenCheckbox:Tooltip():AddText(
					"\t Also select all entities whose template inherit from this template. Shift-click on this checkbox to see that list of children")

				includeChildrenCheckbox.OnChange = function()
					if Ext.ClientInput.GetInputManager().PressedModifiers == "Shift" then
						local window = Ext.IMGUI.NewWindow("Child Templates for " .. translationMap[templateCriteria.id])
						window.Closeable = true
						window.AlwaysAutoResize = true
						window:AddButton("Export tree to file").OnClick = function()
							FileUtils:SaveStringContentToFile(translationMap[templateCriteria.id] .. ".txt", buildChildTemplatesString(templateCriteria.id))
						end

						displayChildTemplates(window, templateCriteria.id)
						includeChildrenCheckbox.Checked = templateCriteria.includeChildren
					else
						templateCriteria.includeChildren = includeChildrenCheckbox.Checked
					end
				end
			else
				templateDisplay:AddDummy(38, 32).SameLine = true
			end

			Styler:HyperlinkText(templateDisplay, translationMap[templateCriteria.id], function(parent)
				ResourceManager:RenderDisplayWindow(Ext.Template.GetTemplate(templateCriteria.id), parent)
			end, true).SameLine = true
		end
	end

	displaySelectedTemplates()
	updateFunc(#existingSelector.criteriaValue)

	local templateGroup = templateSelect:AddGroup("templateSelect")

	---@param filter string?
	local function buildSelects(filter)
		Helpers:KillChildren(templateGroup)
		for _, template in ipairs(templates) do
			if not (filter and #filter > 0)
				or string.upper(translationMap[template]):find(filter)
				or string.upper(template):find(filter)
			then
				---@type ExtuiSelectable
				local select = templateGroup:AddSelectable(translationMap[template] .. "##select")
				select.UserData = template
				select.Selected = TableUtils:IndexOf(existingSelector.criteriaValue, function(value)
					return value.id == template
				end) ~= nil

				local tooltip = select:Tooltip()
				tooltip.Visible = false
				select.OnHoverEnter = function()
					if Ext.ClientInput.GetInputManager().PressedModifiers == "Shift" then
						tooltip.Visible = true
						ResourceManager:RenderDisplayWindow(Ext.Template.GetTemplate(template), tooltip)
					end
				end

				select.OnHoverLeave = function()
					tooltip.Visible = false
					Helpers:KillChildren(tooltip)
				end

				select.OnClick = function()
					if select.Selected then
						table.insert(existingSelector.criteriaValue, {
							id = template,
							includeChildren = false
						} --[[@as TemplateCriteria]])
					else
						local i = TableUtils:IndexOf(existingSelector.criteriaValue, function(value)
							return value.id == template
						end)

						for x = i, TableUtils:CountElements(existingSelector.criteriaValue) do
							existingSelector.criteriaValue[x].delete = true
							existingSelector.criteriaValue[x] = TableUtils:DeeplyCopyTable(existingSelector.criteriaValue._real[x + 1])
						end
					end
					displaySelectedTemplates()
					updateFunc(#existingSelector.criteriaValue)
				end
			end
		end
	end
	buildSelects()

	templateSelectInput.OnChange = function()
		buildSelects(string.upper(templateSelectInput.Text))
	end
	updateFunc(#existingSelector.criteriaValue)
end
