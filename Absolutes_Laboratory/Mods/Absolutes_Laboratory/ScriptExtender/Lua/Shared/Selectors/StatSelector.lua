StatSelector = SelectorInterface:new("Stats")

---@class StatCriteria
---@field id GUIDSTRING
---@field includeChildren boolean

---@class StatSelector : SelectorInterface
---@field criteriaValue StatCriteria[]

local stats = {}
local childRelationships = {}

local function init()
	if not next(stats) then
		for _, statName in pairs(Ext.Stats.GetStats("Character")) do
			---@type Character
			local stat = Ext.Stats.Get(statName)

			table.insert(stats, statName)

			if stat.Using ~= "" then
				if not childRelationships[stat.Using] then
					childRelationships[stat.Using] = {}
				end
				table.insert(childRelationships[stat.Using], statName)
			end
		end
		table.sort(stats)
	end
end

---@param parent ExtuiWindow|ExtuiTableCell
---@param statName string
local function displayChildStats(parent, statName)
	if childRelationships[statName] then
		local displayTable = Styler:TwoColumnTable(parent, "children" .. statName)

		for _, childStat in TableUtils:OrderedPairs(childRelationships[statName], function (key)
			return childRelationships[statName][key]
		end) do
			local row = displayTable:AddRow()
			Styler:HyperlinkText(row:AddCell(), childStat, function(parent)
				ResourceManager:RenderDisplayWindow(Ext.Stats.Get(childStat), parent)
			end, true)
			displayChildStats(row:AddCell(), childStat)
		end
	end
end

---@param statName string
---@param indent string?
---@return string
local function buildChildStatString(statName, indent)
	indent = indent or ""
	local result = indent .. (indent ~= "" and "-- " or "") .. statName .. "\n"
	if childRelationships[statName] then
		for _, childStat in TableUtils:OrderedPairs(childRelationships[statName], function (key)
			return childRelationships[statName][key]
		end) do
			result = result .. buildChildStatString(childStat, indent .. string.rep(" ", 3) .. "|")
		end
	end
	return result
end

---@param existingSelector StatSelector
function StatSelector:renderSelector(parent, existingSelector)
	init()

	existingSelector.criteriaValue = existingSelector.criteriaValue or {}

	local updateFunc
	parent, updateFunc = Styler:DynamicLabelTree(parent:AddTree("Stats"))
	parent:SetColor("Header", { 1, 1, 1, 0 })

	local templateTable = Styler:TwoColumnTable(parent, "stats")
	local row = templateTable:AddRow()

	local statSelectCell = row:AddCell()

	local statSelectInput = statSelectCell:AddInputText("")
	statSelectInput.EscapeClearsAll = true
	statSelectInput.AutoSelectAll = true

	local infoText = statSelectCell:AddText("( ? )")
	infoText.SameLine = true
	infoText:Tooltip():AddText("\t Hold shift before hovering to see tooltips")

	local statSelect = statSelectCell:AddChildWindow("Stats")
	statSelect.NoSavedSettings = true

	local statDisplay = row:AddCell():AddChildWindow("StatDisplay")
	statDisplay.NoSavedSettings = true

	local function displaySelectedStats()
		Helpers:KillChildren(statDisplay)

		for i, statCriteria in TableUtils:OrderedPairs(existingSelector.criteriaValue, function(key)
			return existingSelector.criteriaValue[key].id
		end) do
			local delete = Styler:ImageButton(statDisplay:AddImageButton("delete" .. statCriteria.id, "ico_red_x", { 16, 16 }))
			delete.OnClick = function()
				for x = i, TableUtils:CountElements(existingSelector.criteriaValue) do
					existingSelector.criteriaValue[x].delete = true
					existingSelector.criteriaValue[x] = TableUtils:DeeplyCopyTable(existingSelector.criteriaValue._real[x + 1])
				end

				updateFunc(#existingSelector.criteriaValue)
				displaySelectedStats()
			end

			if childRelationships[statCriteria.id] then
				local includeChildrenCheckbox = statDisplay:AddCheckbox("##" .. statCriteria.id, statCriteria.includeChildren)
				includeChildrenCheckbox.SameLine = true

				includeChildrenCheckbox:Tooltip():AddText(
					"\t Also select all entities whose template inherit from this template. Shift-click on this checkbox to see that list of children")

				includeChildrenCheckbox.OnChange = function()
					if Ext.ClientInput.GetInputManager().PressedModifiers == "Shift" then
						local window = Ext.IMGUI.NewWindow("Child Stats for " .. statCriteria.id)
						window.Closeable = true
						window.AlwaysAutoResize = true
						window:AddButton("Export tree to file").OnClick = function()
							FileUtils:SaveStringContentToFile(statCriteria.id .. ".txt", buildChildStatString(statCriteria.id))
						end

						displayChildStats(window, statCriteria.id)
						includeChildrenCheckbox.Checked = statCriteria.includeChildren
					else
						statCriteria.includeChildren = includeChildrenCheckbox.Checked
					end
				end
			else
				statDisplay:AddDummy(38, 32).SameLine = true
			end

			Styler:HyperlinkText(statDisplay, statCriteria.id, function(parent)
				ResourceManager:RenderDisplayWindow(Ext.Stats.Get(statCriteria.id), parent)
			end, true).SameLine = true
		end
	end

	displaySelectedStats()
	updateFunc(#existingSelector.criteriaValue)

	local statGroup = statSelect:AddGroup("statSelect")

	---@param filter string?
	local function buildSelects(filter)
		Helpers:KillChildren(statGroup)
		for _, statName in ipairs(stats) do
			if not (filter and #filter > 0)
				or string.upper(statName):find(filter)
			then
				---@type ExtuiSelectable
				local select = statGroup:AddSelectable(statName .. "##select")
				select.UserData = statName
				select.Selected = TableUtils:IndexOf(existingSelector.criteriaValue, function(value)
					return value.id == statName
				end) ~= nil

				local tooltip = select:Tooltip()
				tooltip.Visible = false
				select.OnHoverEnter = function()
					if Ext.ClientInput.GetInputManager().PressedModifiers == "Shift" then
						tooltip.Visible = true
						ResourceManager:RenderDisplayWindow(Ext.Stats.Get(statName), tooltip)
					end
				end

				select.OnHoverLeave = function()
					tooltip.Visible = false
					Helpers:KillChildren(tooltip)
				end

				select.OnClick = function()
					if select.Selected then
						table.insert(existingSelector.criteriaValue, {
							id = statName,
							includeChildren = false
						} --[[@as StatCriteria]])
					else
						local i = TableUtils:IndexOf(existingSelector.criteriaValue, function(value)
							return value.id == statName
						end)

						for x = i, TableUtils:CountElements(existingSelector.criteriaValue) do
							existingSelector.criteriaValue[x].delete = true
							existingSelector.criteriaValue[x] = TableUtils:DeeplyCopyTable(existingSelector.criteriaValue._real[x + 1])
						end
					end
					displaySelectedStats()
					updateFunc(#existingSelector.criteriaValue)
				end
			end
		end
	end
	buildSelects()

	statSelectInput.OnChange = function()
		buildSelects(string.upper(statSelectInput.Text))
	end
	updateFunc(#existingSelector.criteriaValue)
end

---@param charStat Character
---@param statToMatch GUIDSTRING
---@return boolean?
local function checkParent(charStat, statToMatch, statCache)
	if charStat then
		table.insert(statCache, charStat.Name)

		if charStat.Name == statToMatch then
			return true
		elseif charStat.Using ~= "" then
			return checkParent(Ext.Stats.Get(charStat.Using), statToMatch, statCache)
		end
	end
end

---@param selector StatSelector
---@return fun(entity: EntityHandle|EntityRecord): boolean
function StatSelector:predicate(selector)
	return function(entity)
		local criteria = selector.criteriaValue

		local parentStats = {}
		if type(entity) == "userdata" then
			---@cast entity EntityHandle
			for _, statCriteria in pairs(criteria) do
				if entity.Data.StatsId == statCriteria.id then
					return true
				elseif statCriteria.includeChildren then
					if next(parentStats) then
						if TableUtils:IndexOf(parentStats, statCriteria.id) then
							return true
						end
					else
						---@type Character
						local stat = Ext.Stats.Get(entity.Data.StatsId)
						if stat.Using ~= ""
							and checkParent(Ext.Stats.Get(stat.Using), statCriteria.id, parentStats)
						then
							return true
						end
					end
				end
			end
		else
			---@cast entity EntityRecord
			for _, statCriteria in pairs(criteria) do
				if entity.Stat == statCriteria.id then
					return true
				elseif statCriteria.includeChildren then
					if next(parentStats) then
						if TableUtils:IndexOf(parentStats, statCriteria.id) then
							return true
						end
					else
						---@type Character?
						local charStat = Ext.Stats.Get(entity.Stat)
						if charStat
							and charStat.Using ~= ""
							and checkParent(Ext.Stats.Get(charStat.Using), statCriteria.id, parentStats)
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
