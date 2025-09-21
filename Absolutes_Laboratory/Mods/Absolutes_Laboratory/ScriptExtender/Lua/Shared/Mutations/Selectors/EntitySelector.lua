EntitySelector = SelectorInterface:new("Entity")

function EntitySelector:renderSelector(parent, existingSelector)
	existingSelector.criteriaValue = existingSelector.criteriaValue or {}

	local entityTree, updateFunc = Styler:DynamicLabelTree(parent:AddTree("Entities"))
	entityTree:SetColor("Header", { 1, 1, 1, 0 })
	entityTree.Disabled = false

	local entityTable = Styler:TwoColumnTable(entityTree, "entities")
	entityTable.Disabled = parent.Disabled
	entityTable.ColumnDefs[1].Width = 300 * Styler:ScaleFactor()

	local row = entityTable:AddRow()

	local entitySelectCell = row:AddCell()

	local entitySelectInput = entitySelectCell:AddInputText("")
	entitySelectInput.Hint = "ID or Name - 2+ characters"
	entitySelectInput.EscapeClearsAll = true
	entitySelectInput.AutoSelectAll = true

	local infoText = entitySelectCell:AddText("( ? )")
	infoText.SameLine = true
	infoText:Tooltip():AddText("\t Hold shift before hovering to see tooltips")

	local entitySelect = entitySelectCell:AddChildWindow("Entities")
	entitySelect.NoSavedSettings = true
	entitySelect.Size = Styler:ScaleFactor({ 0, 400 })

	local entityDisplay = row:AddCell():AddChildWindow("EntityDisplay")
	entityDisplay.NoSavedSettings = true
	entityDisplay.Size = Styler:ScaleFactor({ 0, 400 })

	local function displaySelectedEntities()
		Helpers:KillChildren(entityDisplay)

		for i, entityId in TableUtils:OrderedPairs(existingSelector.criteriaValue, function(_, entityId)
			local entity = EntityRecorder:GetEntity(entityId)
			return entity and entity.Name or entityId
		end) do
			local entity = EntityRecorder:GetEntity(entityId)

			local delete = Styler:ImageButton(entityDisplay:AddImageButton("delete" .. entityId, "ico_red_x", { 16, 16 }))
			delete.OnClick = function()
				existingSelector.criteriaValue[i] = nil
				TableUtils:ReindexNumericTable(existingSelector.criteriaValue)

				updateFunc(#existingSelector.criteriaValue)
				displaySelectedEntities()
			end

			if entity then
				local link = Styler:HyperlinkText(entityDisplay, entity.Name, function(parent)
					CharacterWindow:BuildWindow(parent, entityId)
				end, true)
				link.IDContext = entityId
				link.SameLine = true
			else
				entityDisplay:AddText(entityId)
			end
		end
	end

	displaySelectedEntities()
	updateFunc(#existingSelector.criteriaValue)

	local entityGroup = entitySelect:AddGroup("entitySelect")

	---@param filter string?
	local function buildSelects(filter)
		Helpers:KillChildren(entityGroup)
		if filter and #filter >= 2 then
			for level, entities in pairs(EntityRecorder:GetEntities()) do
				for _, entity in TableUtils:OrderedPairs(entities, function(key, value)
						return value.Name
					end,
					function(key, value)
						return not (filter and #filter > 0)
							or (string.upper(value.Name):find(filter) ~= nil)
							or (#filter == 36 and (string.upper(value.Id):find(filter) ~= nil))
					end) do
					---@type ExtuiSelectable
					local select = entityGroup:AddSelectable(("%s (%s)"):format(entity.Name, string.sub(entity.Id, -6)))
					-- Header is also the main color property of the group, which is set to hide it, which gets inherited by its kids, so have to reset it
					select:SetColor("Header", { 0.36, 0.30, 0.27, 0.76 })
					select.Selected = TableUtils:IndexOf(existingSelector.criteriaValue, entity.Id) ~= nil

					Styler:HyperlinkRenderable(select, entity.Id, "Shift", true, nil, function(parent)
						CharacterWindow:BuildWindow(parent, entity.Id)
					end)

					select.OnClick = function()
						if select.Selected then
							table.insert(existingSelector.criteriaValue, entity.Id)
						else
							local i = TableUtils:IndexOf(existingSelector.criteriaValue, entity.Id)

							if i then
								existingSelector.criteriaValue[i] = nil
								TableUtils:ReindexNumericTable(existingSelector.criteriaValue)
							end
						end
						displaySelectedEntities()
						updateFunc(#existingSelector.criteriaValue)
					end
				end
			end
		end
	end
	buildSelects()

	entitySelectInput.OnChange = function()
		buildSelects(string.upper(entitySelectInput.Text))
	end
	updateFunc(#existingSelector.criteriaValue)
end

function EntitySelector:handleDependencies()
	-- NOOP
end

---@return fun(entity: (EntityHandle|EntityRecord)): boolean
function EntitySelector:predicate(selector)
	return function(entity)
		if type(entity) == "userdata" then
			---@cast entity EntityHandle
			return TableUtils:IndexOf(selector.criteriaValue, entity.Uuid.EntityUuid) ~= nil
		else
			---@cast entity EntityRecord
			return TableUtils:IndexOf(selector.criteriaValue, entity.Id) ~= nil
		end
	end
end

function EntitySelector:generateDocs()
end
