ProgressionsMutator = MutatorInterface:new("Progressions")

function ProgressionsMutator:priority()
	return SpellListMutator:priority() + 1
end

function ProgressionsMutator:canBeAdditive()
	return true
end

---@class ProgressionConditionalGroup
---@field progressionTableIds {[Guid] : number}?
---@field spellListDependencies Guid[]?
---@field numberOfSpellLists number?

---@class ProgressionsMutator : Mutator
---@field values ProgressionConditionalGroup[]

---@param mutator ProgressionsMutator
function ProgressionsMutator:renderMutator(parent, mutator)
	ProgressionProxy:buildProgressionIndex()

	mutator.values = mutator.values or {}

	Helpers:KillChildren(parent)

	Helpers:KillChildren(parent)

	local popup = parent:AddPopup("")

	local classTable = Styler:TwoColumnTable(parent)
	classTable.ColumnDefs[1].Width = 20
	classTable.BordersV = false
	classTable.Resizable = false
	classTable.Borders = false
	classTable.BordersH = true

	for i, progressionConditionalGroup in ipairs(mutator.values) do
		local row = classTable:AddRow()

		local delete = Styler:ImageButton(row:AddCell():AddImageButton("delete" .. mutator.targetProperty, "ico_red_x", { 16, 16 }))
		delete.OnClick = function()
			for x = i, TableUtils:CountElements(mutator.values) do
				mutator.values[x].delete = true
				mutator.values[x] = TableUtils:DeeplyCopyTable(mutator.values._real[x + 1])
			end
			Helpers:KillChildren(parent)
			self:renderMutator(parent, mutator)
		end

		local groupCell = row:AddCell()
		local conditionalGroupTable = groupCell:AddTable(tostring(i), 2)
		conditionalGroupTable.Resizable = true

		local progressionRow = conditionalGroupTable:AddRow()
		local progressionDefCell = progressionRow:AddCell()

		local function buildDisplayTable()
			Helpers:KillChildren(progressionDefCell)

			local groupTable = progressionDefCell:AddTable("", 2)
			groupTable.SizingStretchSame = true

			local headerRow = groupTable:AddRow()
			headerRow.Headers = true
			headerRow:AddCell():AddText("Progression Table")
			headerRow:AddCell():AddText("Level % ( ? )"):Tooltip():AddText([[
	What % of the selected entity's character level should be used when assigning progressions from this progression table (rounded as needed)
e.g. if a progression table is set to 75% and the entity's level is 10, they will be assigned levels 1-7 from the given progrsesion
Progressions are evaluated independently from one another to allow for progression stacking (i.e. to add Race and Class progressions)]])
			if progressionConditionalGroup.progressionTableIds then
				for progressionTableId, levelPercentage in TableUtils:OrderedPairs(progressionConditionalGroup.progressionTableIds, function(_, value)
					return value
				end) do
					local groupRow = groupTable:AddRow()

					---@type ResourceProgression
					local progression = Ext.StaticData.Get(ProgressionProxy.progressionTableMappings[progressionTableId][1], "Progression")

					local name = progression.Name

					local progressionTableCell = groupRow:AddCell()
					local deleteClass = Styler:ImageButton(progressionTableCell:AddImageButton("delete" .. progressionTableId, "ico_red_x", { 16, 16 }))
					deleteClass.OnClick = function()
						progressionConditionalGroup.progressionTableIds[progressionTableId] = nil
						if TableUtils:CountElements(progressionConditionalGroup.progressionTableIds) ~= 0 then
							for otherID, otherLevelPercentage in pairs(progressionConditionalGroup.progressionTableIds) do
								if levelPercentage + otherLevelPercentage <= 100 then
									progressionConditionalGroup.progressionTableIds[otherID] = otherLevelPercentage + levelPercentage
									break
								end
							end
						else
							progressionConditionalGroup.progressionTableIds.delete = true
						end

						self:renderMutator(parent, mutator)
					end

					Styler:HyperlinkText(progressionTableCell, name, function(parent)
						ResourceManager:RenderDisplayableValue(parent, progressionTableId, "Progression")
					end).SameLine = true

					local levelPercentageInput = groupRow:AddCell():AddInputInt("%", levelPercentage)
					levelPercentageInput.IDContext = progressionTableId
					levelPercentageInput.UserData = progressionTableId
					levelPercentageInput.ItemWidth = 40
					levelPercentageInput.SameLine = true

					levelPercentageInput.OnDeactivate = function()
						if levelPercentageInput.Value[1] < 0 then
							levelPercentageInput.Value = { 0, 0, 0, 0 }
						end

						progressionConditionalGroup.progressionTableIds[progressionTableId] = levelPercentageInput.Value[1]

						self:renderMutator(parent, mutator)
					end
				end
			end
		end

		buildDisplayTable()

		groupCell:AddButton("Add Progression Table").OnClick = function()
			Helpers:KillChildren(popup)
			popup:Open()

			local input = popup:AddInputText("")
			input.Hint = "Min 3 Characters"

			local timer

			local resultsGroup = popup:AddChildWindow("results")
			resultsGroup.NoSavedSettings = true
			resultsGroup.Size = { 0, 300 * Styler:ScaleFactor() }

			input.OnChange = function()
				if timer then
					Ext.Timer.Cancel(timer)
					timer = nil
				end

				Helpers:KillChildren(resultsGroup)

				if #input.Text >= 3 then
					timer = Ext.Timer.WaitFor(300, function()
						local upperValue = input.Text:upper()

						for tableUUID, name in TableUtils:OrderedPairs(ProgressionProxy.translationMap, function(key, value)
							return value
						end) do
							if type(ProgressionProxy.progressionTableMappings[tableUUID]) == "table" then
								if tableUUID:find(upperValue) or name:upper():find(upperValue) then
									---@type ExtuiSelectable
									local select = resultsGroup:AddSelectable(name, "DontClosePopups")
									select.IDContext = tableUUID

									local tooltipFunc = Styler:HyperlinkRenderable(select, name, "Shift", nil, nil, function(parent)
										ResourceManager:RenderDisplayableValue(parent, tableUUID, "Progression")
									end)

									select.Selected = progressionConditionalGroup.progressionTableIds ~= nil and progressionConditionalGroup.progressionTableIds[tableUUID] ~= nil

									select.OnClick = function()
										if not tooltipFunc() then
											-- This is flipped by the time this event fires
											if not select.Selected then
												progressionConditionalGroup.progressionTableIds[tableUUID] = nil
											else
												progressionConditionalGroup.progressionTableIds = progressionConditionalGroup.progressionTableIds or {}
												progressionConditionalGroup.progressionTableIds[tableUUID] = 100
											end
											buildDisplayTable()
										end
									end
								end
							end
						end

						timer = nil
					end)
				end
			end
		end

		local conditionalCell = progressionRow:AddCell()

		local inputToPreventOffset = conditionalCell:AddInputInt("")
		inputToPreventOffset:SetStyle("Alpha", 0)
		inputToPreventOffset.ItemWidth = 0

		conditionalCell:AddText("Must have been assigned ").SameLine = true
		local spellListNumberInput = conditionalCell:AddInputInt("", progressionConditionalGroup.numberOfSpellLists or 0)
		spellListNumberInput.ItemWidth = 40
		spellListNumberInput.SameLine = true
		spellListNumberInput.OnDeactivate = function()
			if spellListNumberInput.Value[1] < 0 then
				spellListNumberInput.Value = { 0, 0, 0, 0 }
			end
			progressionConditionalGroup.numberOfSpellLists = spellListNumberInput.Value[1]
		end

		conditionalCell:AddText(" or more of the following Spell Lists:").SameLine = true

		if progressionConditionalGroup.spellListDependencies then
			for i, spellListId in TableUtils:OrderedPairs(progressionConditionalGroup.spellListDependencies, function(key, value)
				return MutationConfigurationProxy.spellLists[value].name
			end) do
				local delete = Styler:ImageButton(conditionalCell:AddImageButton("delete" .. spellListId, "ico_red_x", { 16, 16 }))
				delete.OnClick = function()
					for x = i, TableUtils:CountElements(progressionConditionalGroup.spellListDependencies) do
						progressionConditionalGroup.spellListDependencies[x] = progressionConditionalGroup.spellListDependencies[x + 1]
					end

					self:renderMutator(parent, mutator)
				end

				local spellList = MutationConfigurationProxy.spellLists[spellListId]
				local spellListLink = conditionalCell:AddTextLink(spellList.name .. (spellList.modId and string.format(" (%s)", Ext.Mod.GetMod(spellList.modId).Info.Name) or ""))
				spellListLink.IDContext = spellListId
				spellListLink.SameLine = true
				spellListLink.OnClick = function()
					SpellListDesigner:buildSpellDesignerWindow(spellListId)
				end
			end
		end

		conditionalCell:AddButton("Add Spell List").OnClick = function()
			Helpers:KillChildren(popup)
			popup:Open()

			for spellListId, spellList in TableUtils:OrderedPairs(MutationConfigurationProxy.spellLists, function(key, value)
				return value.name .. (value.modId and string.format(" (%s)", Ext.Mod.GetMod(value.modId).Info.Name) or "")
			end) do
				---@type ExtuiSelectable
				local select = popup:AddSelectable(spellList.name .. (spellList.modId and string.format(" (%s)", Ext.Mod.GetMod(spellList.modId).Info.Name) or ""))
				select.Selected = TableUtils:IndexOf(progressionConditionalGroup.spellListDependencies, spellListId) ~= nil
				select.OnClick = function()
					-- selected is flipped by the time this fires
					if not select.Selected then
						for x = TableUtils:IndexOf(progressionConditionalGroup.spellListDependencies, spellListId), TableUtils:CountElements(progressionConditionalGroup.spellListDependencies) do
							progressionConditionalGroup.spellListDependencies[x] = progressionConditionalGroup.spellListDependencies[x + 1]
						end
					else
						progressionConditionalGroup.spellListDependencies = progressionConditionalGroup.spellListDependencies or {}
						table.insert(progressionConditionalGroup.spellListDependencies, spellListId)
					end
					self:renderMutator(parent, mutator)
				end
			end
		end
	end

	parent:AddButton("Add Progression Group").OnClick = function()
		table.insert(mutator.values, {})
		self:renderMutator(parent, mutator)
	end
end

if Ext.IsServer() then
	function ProgressionsMutator:undoMutator(entity, entityVar)
		for _, list in ipairs(entity.ProgressionContainer.Progressions) do
			for _, progEntity in ipairs(list) do
				Ext.System.ServerProgression.DestroyedProgressions[progEntity] = true
			end
		end

		entity.ProgressionContainer.Progressions = {}

		for _, progressionEntity in pairs(Ext.Entity.GetAllEntitiesWithComponent("ProgressionMeta")) do
			for i, progressionDefList in ipairs(entityVar.originalValues[self.name]) do
				for x, progressionDef in ipairs(progressionDefList) do
					---@cast progressionDef ProgressionMetaComponent
					if progressionEntity.ProgressionMeta.Owner == entity and progressionEntity.ProgressionMeta.Progression == progressionDef.Progression then
						entity.ProgressionContainer.Progressions[i] = entity.ProgressionContainer.Progressions[i] or {}
						entity.ProgressionContainer.Progressions[i][x] = progressionEntity
						goto continue
					end
				end
			end
			::continue::
		end
		entity:Replicate("ProgressionContainer")
		Ext.System.ServerProgression.ProgressionUpdates[entity] = 1

		if Logger:IsLogLevelEnabled(Logger.PrintTypes.TRACE) then
			Logger:BasicTrace("Reverted to %s", Ext.Json.Stringify(entityVar.originalValues[self.name]))
		end
	end

	---@type {[Guid]: Guid[]}
	local progressionTableMappings = {}

	local function buildProgressionIndex()
		if not next(progressionTableMappings) then
			for _, progressionId in pairs(Ext.StaticData.GetAll("Progression")) do
				---@type ResourceProgression
				local progression = Ext.StaticData.Get(progressionId, "Progression")

				if progression and progression.ResourceUUID then
					progressionTableMappings[progression.TableUUID] = progressionTableMappings[progression.TableUUID] or {}

					table.insert(progressionTableMappings[progression.TableUUID], progression.ResourceUUID)
				end
			end

			for _, progressions in pairs(progressionTableMappings) do
				table.sort(progressions, function(a, b)
					return Ext.StaticData.Get(a, "Progression").Level < Ext.StaticData.Get(b, "Progression").Level
				end)
			end
		end
	end

	function ProgressionsMutator:applyMutator(entity, entityVar)
		local progressionMutators = entityVar.appliedMutators[self.name]
		if not progressionMutators[1] then
			progressionMutators = { progressionMutators }
		end
		---@cast progressionMutators ProgressionsMutator[]

		---@type ProgressionConditionalGroup[]
		local chosenProgressionGroups = {}

		for _, progressionMutator in ipairs(progressionMutators) do
			for _, progressionConditonal in ipairs(progressionMutator.values) do
				if progressionConditonal.progressionTableIds and next(progressionConditonal.progressionTableIds) then
					if progressionConditonal.numberOfSpellLists and progressionConditonal.numberOfSpellLists > 0 then
						if progressionConditonal.spellListDependencies and next(progressionConditonal.spellListDependencies) then
							local numberMatched = 0
							if entityVar.appliedMutators[SpellListMutator.name] and entityVar.appliedMutators[SpellListMutator.name].appliedLists then
								for _, appliedSpellListId in pairs(entityVar.appliedMutators[SpellListMutator.name].appliedLists) do
									if TableUtils:IndexOf(progressionConditonal.spellListDependencies, appliedSpellListId) then
										numberMatched = numberMatched + 1
									end
								end
							end

							if numberMatched < progressionConditonal.numberOfSpellLists then
								Logger:BasicDebug("Skipping a progression group because the number of matched spell lists, %s, is less than the defined minimum %s",
									numberMatched,
									progressionConditonal.numberOfSpellLists)

								goto continue
							end
						else
							Logger:BasicWarning("Skipping a Progressions Mutator spellList check because no spellLists were added to it despite specifying a number: %s",
								Ext.Json.Stringify(progressionConditonal))
						end
					end
					table.insert(chosenProgressionGroups, progressionConditonal)
					::continue::
				end
			end
		end

		if next(chosenProgressionGroups) then
			buildProgressionIndex()

			Logger:BasicDebug("%s potential progression groups were identified - randomly choosing one", #chosenProgressionGroups)
			---@type ProgressionConditionalGroup
			local progressionGroup = chosenProgressionGroups[math.random(#chosenProgressionGroups)]

			entityVar.originalValues[self.name] = {}
			for i, list in ipairs(entity.ProgressionContainer.Progressions) do
				entityVar.originalValues[self.name][i] = {}
				for x, progEntity in ipairs(list) do
					entityVar.originalValues[self.name][i][x] = Ext.Types.Serialize(progEntity.ProgressionMeta)
					entityVar.originalValues[self.name][i][x].Owner = nil
				end
			end

			entity.ProgressionContainer.Progressions = {}

			for progressionTableId, levelPercentage in pairs(progressionGroup.progressionTableIds) do
				local desiredLevel = math.max(1, math.ceil(entity.AvailableLevel.Level * (levelPercentage / 100)))
				local lastLevel = 0
				for _, progressionId in ipairs(progressionTableMappings[progressionTableId]) do
					---@type ResourceProgression
					local progression = Ext.StaticData.Get(progressionId, "Progression")

					if progression.Level <= desiredLevel and progression.Level > lastLevel then
						lastLevel = progression.Level
						local prog = Ext.Entity.Create()
						entity.ProgressionContainer.Progressions[#entity.ProgressionContainer.Progressions + 1] = { prog }

						prog:CreateComponent("ServerReplicationDependency")
						prog.ServerReplicationDependency.Dependency = entity

						prog:CreateComponent("ProgressionMeta")

						prog.ProgressionMeta.ClassLevel = (progression.ProgressionType == "Class" or progression.ProgressionType == "SubClass") and progression.Level or 0
						prog.ProgressionMeta.Level = progression.Level
						prog.ProgressionMeta.Owner = entity
						prog.ProgressionMeta.Progression = progressionId
						prog.ProgressionMeta.Source = "00000000-0000-0000-0000-000000000000"
						prog.ProgressionMeta.SpellSourceType = "Progression"

						prog:Replicate("ProgressionMeta")

						Logger:BasicDebug("Assigned progression %s at level %s", progressionId, progression.Level)
					end
				end
			end
			entity:Replicate("ProgressionContainer")
		end
	end
end
