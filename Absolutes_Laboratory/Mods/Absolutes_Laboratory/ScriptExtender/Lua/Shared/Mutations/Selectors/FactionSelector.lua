FactionSelector = SelectorInterface:new("Factions")

---@class FactionCriteria
---@field id GUIDSTRING
---@field includeChildren boolean

---@class FactionSelector : SelectorInterface
---@field criteriaValue FactionCriteria[]

local factions = {}
local translationMap = {}
local childRelationships = {}

local function init()
	if not next(factions) then
		for _, factionId in pairs(Ext.StaticData.GetAll("Faction")) do
			---@type ResourceFaction
			local faction = Ext.StaticData.Get(factionId, "Faction")

			table.insert(factions, factionId)
			local name = faction.Faction
			if translationMap[name] then
				name = string.format("%s (%s)", name, factionId:sub(-5))
			end

			if faction.ParentGuid ~= "00000000-0000-0000-0000-000000000000" then
				if not childRelationships[faction.ParentGuid] then
					childRelationships[faction.ParentGuid] = {}
				end
				table.insert(childRelationships[faction.ParentGuid], factionId)
			end

			translationMap[factionId] = name
			translationMap[name] = factionId
		end
		table.sort(factions, function(a, b)
			return translationMap[a] < translationMap[b]
		end)
	end
end

---@param parent ExtuiWindow|ExtuiTableCell
---@param factionId GUIDSTRING
local function displayChildFactions(parent, factionId)
	if childRelationships[factionId] then
		local displayTable = Styler:TwoColumnTable(parent, "children" .. factionId)

		for _, childId in TableUtils:OrderedPairs(childRelationships[factionId], function(key)
			return translationMap[childRelationships[factionId][key]]
		end) do
			local row = displayTable:AddRow()
			Styler:HyperlinkText(row:AddCell(), translationMap[childId], function(parent)
				ResourceManager:RenderDisplayWindow(Ext.StaticData.Get(childId, "Faction"), parent)
			end, true)
			displayChildFactions(row:AddCell(), childId)
		end
	end
end

---@param factionId GUIDSTRING
---@param indent string?
---@return string
local function buildChildFactionsString(factionId, indent)
	indent = indent or ""
	local result = indent .. (indent ~= "" and "-- " or "") .. translationMap[factionId] .. "\n"
	if childRelationships[factionId] then
		for _, childId in TableUtils:OrderedPairs(childRelationships[factionId], function(key)
			return translationMap[childRelationships[factionId][key]]
		end) do
			result = result .. buildChildFactionsString(childId, indent .. string.rep(" ", 3) .. "|")
		end
	end
	return result
end

---@param existingSelector FactionSelector
function FactionSelector:renderSelector(parent, existingSelector)
	init()

	existingSelector.criteriaValue = existingSelector.criteriaValue or {}

	local updateFunc
	parent, updateFunc = Styler:DynamicLabelTree(parent:AddTree("Factions"))
	parent:SetColor("Header", { 1, 1, 1, 0 })

	local factionTable = Styler:TwoColumnTable(parent, "factions")
	local row = factionTable:AddRow()

	local factionSelectCell = row:AddCell()

	local factionSelectInput = factionSelectCell:AddInputText("")
	factionSelectInput.EscapeClearsAll = true
	factionSelectInput.AutoSelectAll = true

	local infoText = factionSelectCell:AddText("( ? )")
	infoText.SameLine = true
	infoText:Tooltip():AddText("\t Hold shift before hovering to see tooltips")

	local factionSelect = factionSelectCell:AddChildWindow("Factions")
	factionSelect.NoSavedSettings = true

	local factionDisplay = row:AddCell():AddChildWindow("FactionDisplay")
	factionDisplay.NoSavedSettings = true

	local function displaySelectedFactions()
		Helpers:KillChildren(factionDisplay)

		for i, factionCriteria in TableUtils:OrderedPairs(existingSelector.criteriaValue, function(key)
			return translationMap[existingSelector.criteriaValue[key].id]
		end) do
			local delete = Styler:ImageButton(factionDisplay:AddImageButton("delete" .. factionCriteria.id, "ico_red_x", { 16, 16 }))
			delete.OnClick = function()
				for x = i, TableUtils:CountElements(existingSelector.criteriaValue) do
					existingSelector.criteriaValue[x].delete = true
					existingSelector.criteriaValue[x] = TableUtils:DeeplyCopyTable(existingSelector.criteriaValue._real[x + 1])
				end

				updateFunc(#existingSelector.criteriaValue)
				displaySelectedFactions()
			end

			if childRelationships[factionCriteria.id] then
				local includeChildrenCheckbox = factionDisplay:AddCheckbox("##" .. factionCriteria.id, factionCriteria.includeChildren)
				includeChildrenCheckbox.SameLine = true

				includeChildrenCheckbox:Tooltip():AddText(
					"\t Also select all entities whose faction inherit from this faction. Shift-click on this checkbox to see that list of children")

				includeChildrenCheckbox.OnChange = function()
					if Ext.ClientInput.GetInputManager().PressedModifiers == "Shift" then
						local window = Ext.IMGUI.NewWindow("Child Factions for " .. translationMap[factionCriteria.id])
						window.Closeable = true
						window.AlwaysAutoResize = true
						window:AddButton("Export tree to file").OnClick = function()
							FileUtils:SaveStringContentToFile(translationMap[factionCriteria.id] .. ".txt", buildChildFactionsString(factionCriteria.id))
						end

						displayChildFactions(window, factionCriteria.id)
						includeChildrenCheckbox.Checked = factionCriteria.includeChildren
					else
						factionCriteria.includeChildren = includeChildrenCheckbox.Checked
					end
				end
			else
				factionDisplay:AddDummy(38, 32).SameLine = true
			end

			Styler:HyperlinkText(factionDisplay, translationMap[factionCriteria.id], function(parent)
				ResourceManager:RenderDisplayWindow(Ext.StaticData.Get(factionCriteria.id, "Faction"), parent)
			end, true).SameLine = true
		end
	end

	displaySelectedFactions()
	updateFunc(#existingSelector.criteriaValue)

	local factionGroup = factionSelect:AddGroup("factionSelect")

	---@param filter string?
	local function buildSelects(filter)
		Helpers:KillChildren(factionGroup)
		for _, faction in ipairs(factions) do
			if not (filter and #filter > 0)
				or string.upper(translationMap[faction]):find(filter)
				or string.upper(faction):find(filter)
			then
				---@type ExtuiSelectable
				local select = factionGroup:AddSelectable(translationMap[faction] .. "##select")
				select.UserData = faction
				select.Selected = TableUtils:IndexOf(existingSelector.criteriaValue, function(value)
					return value.id == faction
				end) ~= nil

				local tooltip = select:Tooltip()
				tooltip.Visible = false
				select.OnHoverEnter = function()
					if Ext.ClientInput.GetInputManager().PressedModifiers == "Shift" then
						tooltip.Visible = true
						ResourceManager:RenderDisplayWindow(Ext.StaticData.Get(faction, "Faction"), tooltip)
					end
				end

				select.OnHoverLeave = function()
					tooltip.Visible = false
					Helpers:KillChildren(tooltip)
				end

				select.OnClick = function()
					if select.Selected then
						table.insert(existingSelector.criteriaValue, {
							id = faction,
							includeChildren = false
						} --[[@as FactionCriteria]])
					else
						local i = TableUtils:IndexOf(existingSelector.criteriaValue, function(value)
							return value.id == faction
						end)

						for x = i, TableUtils:CountElements(existingSelector.criteriaValue) do
							existingSelector.criteriaValue[x].delete = true
							existingSelector.criteriaValue[x] = TableUtils:DeeplyCopyTable(existingSelector.criteriaValue._real[x + 1])
						end
					end
					displaySelectedFactions()
					updateFunc(#existingSelector.criteriaValue)
				end
			end
		end
	end
	buildSelects()

	factionSelectInput.OnChange = function()
		buildSelects(string.upper(factionSelectInput.Text))
	end
	updateFunc(#existingSelector.criteriaValue)
end

---@param charFaction ResourceFaction
---@param factionToMatch GUIDSTRING
---@return boolean?
local function checkParent(charFaction, factionToMatch, factionCache)
	if charFaction then
		table.insert(factionCache, charFaction.ResourceUUID)

		if charFaction.ResourceUUID == factionToMatch then
			return true
		elseif charFaction.ParentGuid ~= "00000000-0000-0000-0000-000000000000" then
			return checkParent(Ext.StaticData.Get(charFaction.ParentGuid, "Faction"), factionToMatch, factionCache)
		end
	end
end

---@param selector FactionSelector
---@return fun(entity: EntityHandle|EntityRecord): boolean
function FactionSelector:predicate(selector)
	return function(entity)
		local criteria = selector.criteriaValue

		local parentFactions = {}
		if type(entity) == "userdata" then
			---@cast entity EntityHandle
			for _, factionCriteria in pairs(criteria) do
				if entity.Faction.field_8 == factionCriteria.id then
					return true
				elseif factionCriteria.includeChildren then
					if next(parentFactions) then
						if TableUtils:IndexOf(parentFactions, factionCriteria.id) then
							return true
						end
					else
						---@type ResourceFaction
						local faction = Ext.StaticData.Get(entity.Faction.field_8, "Faction")
						if faction.ParentGuid ~= "00000000-0000-0000-0000-000000000000"
							and checkParent(Ext.StaticData.Get(faction.ParentGuid, "Faction"), factionCriteria.id, parentFactions)
						then
							return true
						end
					end
				end
			end
		else
			---@cast entity EntityRecord
			for _, factionCriteria in pairs(criteria) do
				if entity.Faction == factionCriteria.id then
					return true
				elseif factionCriteria.includeChildren then
					if next(parentFactions) then
						if TableUtils:IndexOf(parentFactions, factionCriteria.id) then
							return true
						end
					else
						local charFaction = Ext.StaticData.Get(entity.Faction, "Faction")
						if charFaction and charFaction.ParentGuid ~= "00000000-0000-0000-0000-000000000000"
							and checkParent(Ext.StaticData.Get(charFaction.ParentGuid, "Faction"), factionCriteria.id, parentFactions)
						then
							return true
						end
					end
				end
			end
		end

		return false
	end
end
