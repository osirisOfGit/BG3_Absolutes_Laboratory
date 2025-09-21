TagSelector = SelectorInterface:new("Tags")

---@class TagSelector : Selector
---@field criteriaValue GUIDSTRING[]

local tags = {}
local translationMap = {}

local function init()
	if not next(tags) then
		for _, tag in pairs(Ext.StaticData.GetAll("Tag")) do
			---@type ResourceTag
			tag = Ext.StaticData.Get(tag, "Tag")

			table.insert(tags, tag.ResourceUUID)

			local name = tag.Name
			if translationMap[name] then
				name = string.format("%s (%s)", name, tag.ResourceUUID:sub(-5))
			end

			translationMap[tag.ResourceUUID] = name
			translationMap[name] = tag.ResourceUUID
		end
		table.sort(tags, function(a, b)
			return translationMap[a] < translationMap[b]
		end)
	end
end

---@param existingSelector TagSelector
function TagSelector:renderSelector(parent, existingSelector)
	existingSelector.criteriaValue = existingSelector.criteriaValue or {}

	init()

	local tagTree, updateFunc = Styler:DynamicLabelTree(parent:AddTree("Tags"))
	tagTree.Disabled = false
	tagTree:SetColor("Header", { 1, 1, 1, 0 })

	local tagTable = Styler:TwoColumnTable(tagTree, "tags")
	tagTable.Disabled = parent.Disabled
	tagTable.ColumnDefs[1].Width = 300 * Styler:ScaleFactor()
	local row = tagTable:AddRow()

	local tagSelectCell = row:AddCell()

	local tagSelectInput = tagSelectCell:AddInputText("")
	tagSelectInput.EscapeClearsAll = true
	tagSelectInput.AutoSelectAll = true

	local tagSelect = tagSelectCell:AddChildWindow("Tags")
	tagSelect.NoSavedSettings = true
	tagSelect.Size = Styler:ScaleFactor({ 0, 400 })

	local tagDisplay = row:AddCell():AddChildWindow("TagDisplay")
	tagDisplay.NoSavedSettings = true
	tagDisplay.Size = Styler:ScaleFactor({ 0, 400 })

	local function displaySelectedTags()
		Helpers:KillChildren(tagDisplay)

		for _, tag in ipairs(existingSelector.criteriaValue) do
			local delete = Styler:ImageButton(tagDisplay:AddImageButton("delete" .. tag, "ico_red_x", { 16, 16 }))
			delete.OnClick = function()
				table.remove(existingSelector.criteriaValue, TableUtils:IndexOf(existingSelector.criteriaValue, tag))
				updateFunc(#existingSelector.criteriaValue)
				displaySelectedTags()
			end
			local text = tagDisplay:AddText(translationMap[tag])
			text.SameLine = true
			ResourceManager:RenderDisplayWindow(Ext.StaticData.Get(tag, "Tag"), text:Tooltip())
		end
	end

	displaySelectedTags()
	updateFunc(#existingSelector.criteriaValue)

	local tagGroup = tagSelect:AddGroup("tagSelect")

	---@param filter string?
	local function buildSelects(filter)
		Helpers:KillChildren(tagGroup)
		-- if filter and #filter >= 3 then
		for _, tag in ipairs(tags) do
			if not (filter and #filter > 0)
				or string.upper(translationMap[tag]):find(filter)
				or string.upper(tag):find(filter)
			then
				---@type ExtuiSelectable
				local select = tagGroup:AddSelectable(translationMap[tag])
				select.UserData = tag
				ResourceManager:RenderDisplayWindow(Ext.StaticData.Get(tag, "Tag"), select:Tooltip())
				-- Header is also the main color property of the group, which is set to hide it, which gets inherited by its kids, so have to reset it
				select:SetColor("Header", { 0.36, 0.30, 0.27, 0.76 })
				select.Selected = TableUtils:IndexOf(existingSelector.criteriaValue, tag) ~= nil

				select.OnClick = function()
					if select.Selected then
						table.insert(existingSelector.criteriaValue, tag)
						table.sort(existingSelector.criteriaValue, function(a, b)
							return translationMap[a] < translationMap[b]
						end)
					else
						table.remove(existingSelector.criteriaValue, TableUtils:IndexOf(existingSelector.criteriaValue, tag))
					end
					displaySelectedTags()
					updateFunc(#existingSelector.criteriaValue)
				end
			end
		end
		-- end
	end
	buildSelects()

	tagSelectInput.OnChange = function()
		buildSelects(string.upper(tagSelectInput.Text))
	end
end

---@param selector TagSelector
function TagSelector:handleDependencies(_, selector, removeMissingDependencies)
	local tagSources = Ext.StaticData.GetSources("Tag")

	for i, tagId in ipairs(selector.criteriaValue) do
		---@type ResourceTag
		local tagData = Ext.StaticData.Get(tagId, "Tag")
		if not tagData then
			selector.criteriaValue[i] = nil
		elseif not removeMissingDependencies then
			local tagSource = TableUtils:IndexOf(tagSources, function(value)
				return TableUtils:IndexOf(value, tagId) ~= nil
			end)

			if tagSource then
				selector.modDependencies = selector.modDependencies or {}
				if not selector.modDependencies[tagSource] then
					local name, author, version = Helpers:BuildModFields(tagSource)
					if author == "Larian" then
						goto continue
					end

					selector.modDependencies[tagSource] = {
						modName = name,
						modAuthor = author,
						modVersion = version,
						modId = tagSource,
						packagedItems = {}
					}
				end

				selector.modDependencies[tagSource].packagedItems[tagId] = tagData.DisplayName:Get() or tagData.Name
			end
			::continue::
		end
	end
	TableUtils:ReindexNumericTable(selector.criteriaValue)
end

---@param selector TagSelector
---@return fun(entity: EntityHandle|EntityRecord): boolean
function TagSelector:predicate(selector)
	local tags = selector.criteriaValue

	return function(entity)
		if type(entity) == "userdata" then
			---@cast entity EntityHandle
			for _, tag in pairs(tags) do
				if TableUtils:IndexOf(entity.Tag.Tags, tag) then
					return true
				end
			end
		else
			---@cast entity EntityRecord
			for _, tag in pairs(tags) do
				if TableUtils:IndexOf(entity.Tags, tag) then
					return true
				end
			end
		end
		return false
	end
end

function TagSelector:generateDocs()
end
