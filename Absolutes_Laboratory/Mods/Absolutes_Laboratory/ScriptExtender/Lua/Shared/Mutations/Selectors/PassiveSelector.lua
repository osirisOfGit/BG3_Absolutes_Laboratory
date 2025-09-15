PassiveSelector = SelectorInterface:new("Passives")

function PassiveSelector:renderSelector(parent, existingSelector)
	Helpers:KillChildren(parent)

	existingSelector.criteriaValue = existingSelector.criteriaValue or {}

	local passiveTree, updateFunc = Styler:DynamicLabelTree(parent:AddTree("Passives"))
	passiveTree:SetColor("Header", { 1, 1, 1, 0 })
	passiveTree.Disabled = false

	local passiveTable = Styler:TwoColumnTable(passiveTree, "passives")
	passiveTable.Disabled = parent.Disabled
	passiveTable.ColumnDefs[1].Width = 300 * Styler:ScaleFactor()

	local row = passiveTable:AddRow()

	local passiveSelectCell = row:AddCell()

	local passiveSelectInput = passiveSelectCell:AddInputText("")
	passiveSelectInput.EscapeClearsAll = true
	passiveSelectInput.AutoSelectAll = true

	local infoText = passiveSelectCell:AddText("( ? )")
	infoText.SameLine = true
	infoText:Tooltip():AddText("\t Hold shift before hovering to see tooltips")

	local passiveSelect = passiveSelectCell:AddChildWindow("Passives")
	passiveSelect.NoSavedSettings = true
	passiveSelect.Size = Styler:ScaleFactor({ 0, 400 })

	local passiveDisplay = row:AddCell():AddChildWindow("PassiveDisplay")
	passiveDisplay.NoSavedSettings = true
	passiveDisplay.Size = Styler:ScaleFactor({ 0, 400 })

	local function displaySelectedPassives()
		Helpers:KillChildren(passiveDisplay)

		for i, passiveId in TableUtils:OrderedPairs(existingSelector.criteriaValue, function(key, passiveId)
			return Ext.Loca.GetTranslatedString(Ext.Stats.Get(passiveId).DisplayName, passiveId)
		end) do
			local delete = Styler:ImageButton(passiveDisplay:AddImageButton("delete" .. passiveId, "ico_red_x", { 16, 16 }))
			delete.OnClick = function()
				existingSelector.criteriaValue[i] = nil
				TableUtils:ReindexNumericTable(existingSelector.criteriaValue)

				updateFunc(#existingSelector.criteriaValue)
				displaySelectedPassives()
			end

			---@type PassiveData
			local passive = Ext.Stats.Get(passiveId)

			local icon = passiveDisplay:AddImage((passive.Icon ~= "" and passive.Icon ~= "unknown") and passive.Icon or "Item_Unknown", { 32, 32 })
			if icon.ImageData.Icon == "" then
				icon:Destroy()
				icon = passiveDisplay:AddImage("Item_Unknown", { 32, 32 })
			end
			icon.SameLine = true

			Styler:HyperlinkText(passiveDisplay, Ext.Loca.GetTranslatedString(passive.DisplayName, passiveId), function(parent)
				ResourceManager:RenderDisplayWindow(passive, parent)
			end, true).SameLine = true
		end
	end

	displaySelectedPassives()
	updateFunc(#existingSelector.criteriaValue)

	local passiveGroup = passiveSelect:AddGroup("passiveSelect")

	---@param filter string?
	local function buildSelects(filter)
		Helpers:KillChildren(passiveGroup)
		if filter and #filter >= 3 then
			for _, passiveId in TableUtils:OrderedPairs(Ext.Stats.GetStats("PassiveData"), function(key, passiveId)
				local dn = Ext.Loca.GetTranslatedString(Ext.Stats.Get(passiveId).DisplayName, passiveId)
				return dn == "%%% EMPTY" and passiveId or dn
			end) do
				---@type PassiveData
				local passive = Ext.Stats.Get(passiveId)
				local displayName = Ext.Loca.GetTranslatedString(passive.DisplayName, passiveId)
				displayName = displayName == "%%% EMPTY" and passiveId or displayName

				if not (filter and #filter > 0)
					or string.upper(displayName):find(filter)
					or string.upper(passiveId):find(filter)
				then
					local icon = passiveGroup:AddImage((passive.Icon ~= "" and passive.Icon ~= "unknown") and passive.Icon or "Item_Unknown", { 32, 32 })
					if icon.ImageData.Icon == "" then
						icon:Destroy()
						icon = passiveGroup:AddImage("Item_Unknown", { 32, 32 })
					end
					---@type ExtuiSelectable
					local select = passiveGroup:AddSelectable(string.format("%s (%s)%s", displayName, passiveId, "##select"))
					select.SameLine = true
					select.UserData = passive
					select.Selected = TableUtils:IndexOf(existingSelector.criteriaValue, function(value)
						return value == passiveId
					end) ~= nil
					-- Header is also the main color property of the group, which is set to hide it, which gets inherited by its kids, so have to reset it
					select:SetColor("Header", { 0.36, 0.30, 0.27, 0.76 })

					local tooltip = select:Tooltip()
					tooltip.Visible = false
					select.OnHoverEnter = function()
						if Ext.ClientInput.GetInputManager().PressedModifiers == "Shift" then
							tooltip.Visible = true
							ResourceManager:RenderDisplayWindow(passive, tooltip)
						end
					end

					select.OnHoverLeave = function()
						tooltip.Visible = false
						Helpers:KillChildren(tooltip)
					end

					select.OnClick = function()
						if select.Selected then
							table.insert(existingSelector.criteriaValue, passiveId)
						else
							local i = TableUtils:IndexOf(existingSelector.criteriaValue, function(value)
								return value == passiveId
							end)

							if i then
								existingSelector.criteriaValue[i] = nil
								TableUtils:ReindexNumericTable(existingSelector.criteriaValue)
							end
						end
						displaySelectedPassives()
						updateFunc(#existingSelector.criteriaValue)
					end
				end
			end
		end
	end
	buildSelects()

	passiveSelectInput.OnChange = function()
		buildSelects(string.upper(passiveSelectInput.Text))
	end
	updateFunc(#existingSelector.criteriaValue)
end

function PassiveSelector:handleDependencies(_, selector, removeMissingDependencies)
	for i, passiveId in ipairs(selector.criteriaValue) do
		---@type PassiveData
		local passive = Ext.Stats.Get(passiveId)
		if not passive then
			selector.criteriaValue[i] = nil
		elseif not removeMissingDependencies then
			if passive.OriginalModId ~= "" then
				selector.modDependencies = selector.modDependencies or {}
				if not selector.modDependencies[passive.OriginalModId] then
					local name, author, version = Helpers:BuildModFields(passive.OriginalModId)
					if author == "Larian" then
						goto continue
					end
					selector.modDependencies[passive.OriginalModId] = {
						modName = name,
						modAuthor = author,
						modVersion = version,
						modId = passive.OriginalModId,
						packagedItems = {}
					}
				end

				local displayName = Ext.Loca.GetTranslatedString(passive.DisplayName, passiveId)
				displayName = displayName == "%%% EMPTY" and passiveId or displayName
				selector.modDependencies[passive.OriginalModId].packagedItems[passiveId] = displayName
			end
		end
		::continue::
	end
	TableUtils:ReindexNumericTable(selector.criteriaValue)
end

---@return fun(entity: EntityHandle|EntityRecord): boolean
function PassiveSelector:predicate(selector)
	return function(entity)
		---@type string[]
		local criteria = selector.criteriaValue

		if type(entity) == "userdata" then
			---@cast entity EntityHandle

			for _, passiveId in pairs(criteria) do
				if entity.PassiveContainer and TableUtils:IndexOf(entity.PassiveContainer.Passives, function(value)
						return value.Passive.PassiveId == passiveId
					end) then
					return true
				end
			end
		else
			---@cast entity EntityRecord
			for _, passiveId in pairs(criteria) do
				if TableUtils:IndexOf(entity.Passives, passiveId) then
					return true
				end
			end
		end
		return false
	end
end
