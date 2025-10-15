Ext.Require("Shared/Mutations/Mutators/StatusList/StatusListDesigner.lua")

---@class StatusListMutatorClass : MutatorInterface
StatusListMutator = MutatorInterface:new("StatusList")

---@type ExtComponentType[]
StatusListMutator.affectedComponents = {
	"StatusContainer"
}

function StatusListMutator:priority()
	return self:recordPriority(SpellListMutator:priority() + 1)
end

function StatusListMutator:canBeAdditive()
	return true
end

---@class StatusPool
---@field statusLists Guid[]
---@field statuses string[]?
---@field randomizedStatusPoolSize number[]

---@class StatusListMutator : Mutator
---@field values StatusPool
---@field useGameLevel boolean

---@param mutator StatusListMutator
function StatusListMutator:renderMutator(parent, mutator)
	mutator.values = mutator.values or {}
	mutator.useGameLevel = mutator.useGameLevel or false
	Helpers:KillChildren(parent)

	local popup = parent:AddPopup("")

	local statusListDesignerButton = parent:AddButton("Open Status List Designer")
	statusListDesignerButton.UserData = "EnableForMods"
	statusListDesignerButton.OnClick = function()
		StatusListDesigner:launch()
	end

	parent:AddText("(?) Distribute By: "):Tooltip():AddText([[
	Changing this option will clear all groups and only allow selecting lists that have the same option set, as the two options are not compatible with each other.
Using game level will distribute all entries in the same level that the entity is in and all the ones that come before (i.e. TUT, WLD, CRE, SCL if they're in SCL).
Using entity level will use the entity's character level, after Character Level Mutators if applicable.]])
	Styler:DualToggleButton(parent, "Entity Level", "Game Level", true, function(swap)
		if swap then
			mutator.useGameLevel = not mutator.useGameLevel
			mutator.values.delete = true
			mutator.values = {}
			self:renderMutator(parent, mutator)
		end
		return not mutator.useGameLevel
	end)

	local sectionTable = parent:AddTable("Sections", 2)
	sectionTable.BordersOuter = true
	local sectionsRow = sectionTable:AddRow()
	local mutatorSection = sectionsRow:AddCell()
	local modifierSection = sectionsRow:AddCell()

	local listSep = mutatorSection:AddSeparatorText("Status Lists ( ? )")
	listSep:SetStyle("SeparatorTextAlign", 0.1, 0.5)
	listSep:Tooltip():AddText(
		"\t If multiple lists are specified and are eligible to be assigned to the entity (according to their Spell List dependencies, or lack thereof), one will be randomly chosen")

	if mutator.values.statusLists then
		for l, statusListId in TableUtils:OrderedPairs(mutator.values.statusLists, function(key, value)
			local list = MutationConfigurationProxy.lists.statusLists[value]
			return (list.modId or "_") .. list.name
		end) do
			local list = MutationConfigurationProxy.lists.statusLists[statusListId]

			local delete = Styler:ImageButton(mutatorSection:AddImageButton("delete" .. list.name, "ico_red_x", { 16, 16 }))
			delete.OnClick = function()
				for x = l, TableUtils:CountElements(mutator.values.statusLists) do
					mutator.values.statusLists[x] = nil
					mutator.values.statusLists[x] = TableUtils:DeeplyCopyTable(mutator.values.statusLists._real[x + 1])
				end
				self:renderMutator(parent, mutator)
			end

			local link = mutatorSection:AddTextLink(list.name .. (list.modId and string.format(" (from %s)", Ext.Mod.GetMod(list.modId).Info.Name) or ""))
			link.SameLine = true
			link.OnClick = function()
				StatusListDesigner:launch(statusListId)
			end

			if list.spellListDependencies and list.spellListDependencies() then
				local sep = mutatorSection:AddCollapsingHeader("Spell List Dependencies ( ? )")
				sep.Font = "Small"
				sep:Tooltip():AddText([[
	These lists are automatically added from the defined dependencies in the Status List Designer - an entity must have been assigned at least one of these to be assigned this list,
and this list will use the sum of the assigned spell list levels to determine what levels from this status list should be used.]])

				for s, spellListId in ipairs(list.spellListDependencies) do
					local spellList = MutationConfigurationProxy.lists.spellLists[spellListId]
					if spellList then
						sep:AddTextLink(spellList.name .. (spellList.modId and string.format(" (from %s)", Ext.Mod.GetMod(spellList.modId).Info.Name) or "")).OnClick = function()
							SpellListDesigner:launch(spellListId)
						end
					else
						list.spellListDependencies[s] = nil
						TableUtils:ReindexNumericTable(list.spellListDependencies)
						self:renderMutator(parent, mutator)
						return
					end
				end
			end
		end
	end
	mutatorSection:AddButton("Add Status List").OnClick = function()
		Helpers:KillChildren(popup)
		popup:Open()

		for statusListId, statusList in pairs(MutationConfigurationProxy.lists.statusLists) do
			if statusList.useGameLevel == mutator.useGameLevel then
				---@type ExtuiSelectable
				local select = popup:AddSelectable(statusList.name .. (statusList.modId and string.format(" (from %s)", Ext.Mod.GetMod(statusList.modId).Info.Name) or ""),
					"DontClosePopups")
				select.Selected = TableUtils:IndexOf(mutator.values.statusLists, statusListId) ~= nil
				select.OnClick = function()
					if not select.Selected then
						mutator.values.statusLists[TableUtils:IndexOf(mutator.values.statusLists, statusListId)] = nil
						TableUtils:ReindexNumericTable(mutator.values.statusLists)
					else
						mutator.values.statusLists = mutator.values.statusLists or {}
						mutator.values.statusLists[#mutator.values.statusLists + 1] = statusListId
					end
					self:renderMutator(parent, mutator)
				end
			end
		end

		if MutationModProxy.ModProxy.lists.statusLists() then
			---@type {[Guid]: Guid[]}
			local modStatusLists = {}

			for modId, modCache in pairs(MutationModProxy.ModProxy.lists.statusLists) do
				---@cast modCache +LocalModCache

				if modCache.lists and modCache.lists.statusLists and next(modCache.lists.statusLists) then
					modStatusLists[modId] = {}
					for statusListId in pairs(modCache.lists.statusLists) do
						table.insert(modStatusLists[modId], statusListId)
					end
				end
			end

			if next(modStatusLists) then
				for modId, statusLists in TableUtils:OrderedPairs(modStatusLists, function(key, value)
					return Ext.Mod.GetMod(key).Info.Name
				end) do
					local modGroup = popup:AddGroup("Mods" .. modId)

					Styler:ScaledFont(modGroup:AddSeparatorText(Ext.Mod.GetMod(modId).Info.Name), "Small")

					for _, statusListId in TableUtils:OrderedPairs(statusLists, function(key, value)
						return MutationModProxy.ModProxy.lists.statusLists[value].name
					end) do
						local statusList = MutationModProxy.ModProxy.lists.statusLists[statusListId]
						if mutator.useGameLevel == statusList.useGameLevel then
							---@type ExtuiSelectable
							local select = modGroup:AddSelectable(statusList.name, "DontClosePopups")
							select.Selected = TableUtils:IndexOf(mutator.values.statusLists, statusListId) ~= nil
							select.OnClick = function()
								local index = TableUtils:IndexOf(mutator.values.statusLists, statusListId)
								if index then
									mutator.values.statusLists[index] = nil
									select.Selected = false
								else
									select.Selected = true
									table.insert(mutator.values.statusLists, statusListId)
								end
								self:renderMutator(parent, mutator)
							end
						end
					end
					if #modGroup.Children == 1 then
						modGroup:Destroy()
					end
				end
			end
		end
	end

	local looseSep = mutatorSection:AddSeparatorText("Loose Statuses ( ? )")
	looseSep:SetStyle("SeparatorTextAlign", 0.1, 0.5)
	looseSep:Tooltip():AddText("\t Statuses added here are guaranteed to be added to the entity no matter what")

	local statusGroup = mutatorSection:AddGroup("statuses")
	local function buildStatuses()
		Helpers:KillChildren(statusGroup)
		if mutator.values.statuses and mutator.values.statuses() then
			for i, statusId in ipairs(mutator.values.statuses) do
				local delete = Styler:ImageButton(statusGroup:AddImageButton("delete" .. statusId, "ico_red_x", { 16, 16 }))
				delete.OnClick = function()
					for x = i, TableUtils:CountElements(mutator.values.statuses) do
						mutator.values.statuses[x] = nil
						mutator.values.statuses[x] = TableUtils:DeeplyCopyTable(mutator.values.statuses._real[x + 1])
					end
					buildStatuses()
				end

				Styler:HyperlinkText(statusGroup, statusId, function(parent)
					ResourceManager:RenderDisplayWindow(Ext.Stats.Get(statusId), parent)
				end).SameLine = true
			end
		end
	end
	buildStatuses()

	mutatorSection:AddButton("Add Status").OnClick = function()
		popup:Open()

		Helpers:KillChildren(popup)

		StatBrowser:Render("StatusData",
			popup,
			nil,
			function(pos)
				return pos % 7 ~= 0
			end,
			function(statusId)
				return TableUtils:IndexOf(mutator.values.statuses, statusId) ~= nil
			end,
			nil,
			function(_, statusId)
				if not TableUtils:IndexOf(mutator.values.statuses, statusId) then
					mutator.values.statuses = mutator.values.statuses or {}

					table.insert(mutator.values.statuses, statusId)
				else
					local index = TableUtils:IndexOf(mutator.values.statuses, statusId)
					for x = index, TableUtils:CountElements(mutator.values.statuses) do
						mutator.values.statuses[x] = nil
						mutator.values.statuses[x] = mutator.values.statuses[x + 1]
					end
					if not mutator.values.statuses() then
						mutator.values.statuses.delete = true
					end
				end
				buildStatuses()
			end)
	end

	self:renderRandomizedAmountSettings(modifierSection, mutator.values)
end

---@param parent ExtuiTreeParent
---@param statusPool StatusPool
function StatusListMutator:renderRandomizedAmountSettings(parent, statusPool)
	Helpers:KillChildren(parent)

	local savedPresetSpreads = ConfigurationStructure.config.mutations.settings.customLists.savedSpellListSpreads.statusLists

	local popup = parent:AddPopup("Randomized")

	--#region Randomized Spell Pool Size
	parent:AddSeparatorText("Amount of Random Statuses to Give Per Level")

	statusPool.randomizedStatusPoolSize = statusPool.randomizedStatusPoolSize or {}
	local randomizedStatusPoolSize = statusPool.randomizedStatusPoolSize
	if getmetatable(randomizedStatusPoolSize) and getmetatable(randomizedStatusPoolSize).__call and not randomizedStatusPoolSize() then
		statusPool.randomizedStatusPoolSize.delete = true
		statusPool.randomizedStatusPoolSize = TableUtils:DeeplyCopyTable(savedPresetSpreads["Default"]._real)
		randomizedStatusPoolSize = statusPool.randomizedStatusPoolSize
	end

	local randoSpellsTable = parent:AddTable("RandomSpellNumbers", 3)
	randoSpellsTable:AddColumn("", "WidthFixed")

	local headers = randoSpellsTable:AddRow()
	headers.Headers = true
	headers:AddCell()
	headers:AddCell():AddText("Level ( ? )"):Tooltip():AddText([[
	Levels do not need to be consecutive - for example, you can set level 1 to give 3 random statuses, and level 5 to give 1 random status.
This will cause Lab to give the entity 3 random statuses from the selected Status List every level for levels 1-4, and 1 random status every level from level 5 onwards]])

	headers:AddCell():AddText("# Of Statuses ( ? )"):Tooltip():AddText([[
	This represents the amount of Random statuses to give the entity from the appropriate level in the Status List, if the status list has statuses for the appropriate level]])

	local enableDelete = false
	for level, numSpells in TableUtils:OrderedPairs(randomizedStatusPoolSize) do
		local row = randoSpellsTable:AddRow()
		if not enableDelete then
			row:AddCell()
			enableDelete = true
		else
			local delete = Styler:ImageButton(row:AddCell():AddImageButton("delete" .. level, "ico_red_x", { 16, 16 }))
			delete.OnClick = function()
				randomizedStatusPoolSize[level] = nil
				row:Destroy()
			end
		end

		---@param input ExtuiInputInt
		row:AddCell():AddInputInt("", level).OnDeactivate = function(input)
			if not randomizedStatusPoolSize[input.Value[1]] then
				randomizedStatusPoolSize[input.Value[1]] = numSpells
				randomizedStatusPoolSize[level] = nil
				self:renderRandomizedAmountSettings(parent, statusPool)
			else
				input.Value = { level, level, level, level }
			end
		end

		---@param input ExtuiInputInt
		row:AddCell():AddInputInt("", numSpells).OnDeactivate = function(input)
			randomizedStatusPoolSize[level] = input.Value[1]
		end
	end

	parent:AddButton("+").OnClick = function()
		Helpers:KillChildren(popup)
		popup:Open()

		local add = popup:AddButton("Add Level")
		local input = popup:AddInputInt("", randomizedStatusPoolSize() + 1)
		input.SameLine = true

		local errorText = popup:AddText("Choose a level that isn't already specified")
		errorText:SetColor("Text", Styler:ConvertRGBAToIMGUI({ 255, 100, 100, 0.7 }))
		errorText.Visible = false

		add.OnClick = function()
			if randomizedStatusPoolSize[input.Value[1]] then
				errorText.Visible = true
			else
				randomizedStatusPoolSize[input.Value[1]] = 2
				self:renderRandomizedAmountSettings(parent, statusPool)
			end
		end
	end

	local loadButton = parent:AddButton("L")
	loadButton:Tooltip():AddText("\t Load a saved preset")
	loadButton.SameLine = true
	loadButton.OnClick = function()
		Helpers:KillChildren(popup)
		popup:Open()

		for presetName, spread in TableUtils:OrderedPairs(savedPresetSpreads) do
			if presetName ~= "Default" then
				local delete = Styler:ImageButton(popup:AddImageButton("delete" .. presetName, "ico_red_x", { 16, 16 }))
				delete.OnClick = function()
					savedPresetSpreads[presetName].delete = true
					loadButton:OnClick()
				end
			end
			local loadPreset = popup:AddSelectable(presetName)
			loadPreset.SameLine = presetName ~= "Default"
			loadPreset.OnClick = function()
				statusPool.randomizedStatusPoolSize.delete = true
				statusPool.randomizedStatusPoolSize = TableUtils:DeeplyCopyTable(spread._real)
				self:renderRandomizedAmountSettings(parent, statusPool)
			end
		end
	end

	local saveButton = parent:AddButton("S")
	saveButton:Tooltip():AddText("\t Save the current table to a new or existing preset")
	saveButton.SameLine = true
	saveButton.OnClick = function()
		Helpers:KillChildren(popup)
		popup:Open()

		local nameInput = popup:AddInputText("")
		nameInput.Hint = "New or Existing Preset Name"

		local overrideConfirmation = popup:AddText("Are you sure you want to override %s?")
		overrideConfirmation.Visible = false
		overrideConfirmation:SetColor("Text", { 1, 0.2, 0, 1 })

		local submitButton = popup:AddButton("Save")
		submitButton.OnClick = function()
			if overrideConfirmation.Visible or not savedPresetSpreads[nameInput.Text] then
				if savedPresetSpreads[nameInput.Text] then
					savedPresetSpreads[nameInput.Text].delete = true
				end
				savedPresetSpreads[nameInput.Text] = TableUtils:DeeplyCopyTable(randomizedStatusPoolSize._real)
				self:renderRandomizedAmountSettings(parent, statusPool)
			else
				overrideConfirmation.Label = string.format("Are you sure you want to override %s?", nameInput.Text)
				overrideConfirmation.Visible = true
			end
		end
	end
end

---@param mutator StatusListMutator
function StatusListMutator:handleDependencies(export, mutator, removeMissingDependencies)
	---@param statusName string
	---@param container table?
	---@return boolean?
	local function buildStatusDependency(statusName, container)
		---@type StatusData?
		local status = Ext.Stats.Get(statusName)
		if status then
			if not removeMissingDependencies then
				container = container or mutator
				container.modDependencies = container.modDependencies or {}
				if not container.modDependencies[status.OriginalModId] then
					local name, author, version = Helpers:BuildModFields(status.OriginalModId)
					if author == "Larian" then
						return true
					end

					container.modDependencies[status.OriginalModId] = {
						modName = name,
						modAuthor = author,
						modVersion = version,
						modId = status.OriginalModId,
						packagedItems = {}
					}
				end
				container.modDependencies[status.OriginalModId].packagedItems[statusName] = Ext.Loca.GetTranslatedString(status.DisplayName, statusName)
			end
			return true
		else
			return false
		end
	end

	if mutator.values.statuses then
		for i, status in pairs(mutator.values.statuses) do
			if not buildStatusDependency(status) then
				mutator.values.statuses[i] = nil
			end
		end
		TableUtils:ReindexNumericTable(mutator.values.statuses)
	end

	if mutator.values.statusLists then
		ListConfigurationManager:HandleDependences(export, mutator, mutator.values.statusLists, removeMissingDependencies, StatusListDesigner.configKey)
	end
end

function StatusListMutator:undoMutator(entity, mutator, primedEntityVar, reprocessTransient)
	if mutator.originalValues[self.name] then
		for _, statusId in pairs(mutator.originalValues[self.name]) do
			if Osi.HasActiveStatus(entity.Uuid.EntityUuid, statusId) == 1 then
				Logger:BasicDebug("Removing status %s as it was given by Lab", statusId)
				Osi.RemoveStatus(entity.Uuid.EntityUuid, statusId)
			end
		end
	end
end

---@param entity EntityHandle
---@param levelToUse integer
---@param statusList CustomList
---@param numRandomStatusesPerLevel number[]
---@param appliedStatuses string[]
---@param appliedLists Guid[]
local function applyStatusLists(entity, levelToUse, statusList, numRandomStatusesPerLevel, appliedStatuses, appliedLists)
	Logger:BasicDebug("Applying levels %s to %s of list %s",
		statusList.useGameLevel and EntityRecorder.Levels[1] or 1,
		statusList.useGameLevel and EntityRecorder.Levels[levelToUse] or levelToUse,
		statusList.name .. (statusList.modId and (" from mod " .. Ext.Mod.GetMod(statusList.modId).Info.Name) or ""))

	for level = 1, levelToUse do
		local leveledLists = statusList.levels[level]
		---@type EntryName[]
		local randomPool = {}
		if leveledLists then
			if leveledLists.manuallySelectedEntries then
				if leveledLists.manuallySelectedEntries.randomized then
					for _, statusId in pairs(leveledLists.manuallySelectedEntries.randomized) do
						if Osi.HasActiveStatus(entity.Uuid.EntityUuid, statusId) == 0 then
							table.insert(randomPool, statusId)
						else
							Logger:BasicDebug("%s is already present, not adding to the random pool", statusId)
						end
					end
				end
				if leveledLists.manuallySelectedEntries.guaranteed and next(leveledLists.manuallySelectedEntries.guaranteed) then
					for _, statusId in pairs(leveledLists.manuallySelectedEntries.guaranteed) do
						if Osi.HasActiveStatus(entity.Uuid.EntityUuid, statusId) == 0 then
							Logger:BasicDebug("Adding guaranteed status %s", statusId)
							table.insert(appliedStatuses, statusId)
						else
							Logger:BasicDebug("Guaranteed status %s is already present", statusId)
						end
					end
				end
			end
		end

		local numRandomStatusesToPick = 0
		if numRandomStatusesPerLevel[level] then
			numRandomStatusesToPick = numRandomStatusesPerLevel[level]
		else
			local maxLevel = nil
			for definedLevel, _ in pairs(numRandomStatusesPerLevel) do
				if definedLevel < level and (not maxLevel or definedLevel > maxLevel) then
					maxLevel = definedLevel
				end
			end
			if maxLevel then
				numRandomStatusesToPick = numRandomStatusesPerLevel[maxLevel]
			end
		end

		if numRandomStatusesToPick > 0 then
			Logger:BasicDebug("Giving %s random statuses out of %s from level %s", numRandomStatusesToPick, #randomPool,
				statusList.useGameLevel and EntityRecorder.Levels[level] or level)

			local statusesToGive = {}
			if #randomPool <= numRandomStatusesToPick then
				statusesToGive = randomPool
			else
				for _ = 1, numRandomStatusesToPick do
					local num = math.random(#randomPool)
					table.insert(statusesToGive, randomPool[num])
					table.remove(randomPool, num)
				end
			end

			for _, statusId in pairs(statusesToGive) do
				table.insert(appliedStatuses, statusId)
			end
		else
			Logger:BasicDebug("Skipping level %s for random status assignment due to configured size being 0", statusList.useGameLevel and EntityRecorder.Levels[level] or level)
		end
	end

	---@param listToProcess CustomList
	local function recursivelyApplyLists(listToProcess)
		if listToProcess.linkedLists and next(listToProcess.linkedLists._real or listToProcess.linkedLists) then
			for _, linkedListId in pairs(listToProcess.linkedLists) do
				if not TableUtils:IndexOf(appliedLists, linkedListId) then
					table.insert(appliedLists, linkedListId)

					local linkedList = MutationConfigurationProxy.lists.statusLists[linkedListId]
					Logger:BasicDebug("### STARTING List %s, linked from %s ###", linkedList.name, listToProcess.name)
					applyStatusLists(entity, levelToUse, linkedList, numRandomStatusesPerLevel, appliedStatuses, appliedLists)
					Logger:BasicDebug("### FINISHED List %s, linked from %s ###", linkedList.name, listToProcess.name)

					recursivelyApplyLists(linkedList)
				end
			end
		end
	end
	recursivelyApplyLists(statusList)
end

function StatusListMutator:applyMutator(entity, entityVar)
	local statusListMutators = entityVar.appliedMutators[self.name]
	if not statusListMutators[1] then
		statusListMutators = { statusListMutators }
	end
	---@cast statusListMutators StatusListMutator[]

	local appliedStatuses = {}

	local usingListsWithSpellListDeps = false
	-- StatusListId : randomizedStatusPoolSize
	---@type {[Guid]: number[]}
	local statusListsPool = {}

	---@type string[]
	local looseStatusesToApply = {}
	for _, statusListMutator in pairs(statusListMutators) do
		if statusListMutator.values.statuses then
			for _, status in pairs(statusListMutator.values.statuses) do
				table.insert(looseStatusesToApply, status)
			end
		end

		if statusListMutator.values.statusLists then
			for _, statusListId in pairs(statusListMutator.values.statusLists) do
				local statusList = MutationConfigurationProxy.lists.statusLists[statusListId]
				statusList = statusList.__real or statusList
				if statusList then
					if statusList.spellListDependencies and next(statusList.spellListDependencies) then
						for _, spellListDependency in ipairs(statusList.spellListDependencies) do
							if entityVar.appliedMutators[SpellListMutator.name] and entityVar.appliedMutators[SpellListMutator.name].appliedLists[spellListDependency] then
								if not usingListsWithSpellListDeps then
									statusListsPool = {}
									usingListsWithSpellListDeps = true
								end

								statusListsPool[statusListId] = statusListMutator.values.randomizedStatusPoolSize
								Logger:BasicDebug(
									"List %s was added to the pool due to having Spell List Dependency %s being present (removing all status lists that don't have dependencies from the pool)",
									statusList.name,
									spellListDependency)
								break
							end
						end
					elseif not usingListsWithSpellListDeps then
						statusListsPool[statusListId] = statusListMutator.values.randomizedStatusPoolSize
						Logger:BasicDebug("List %s was added to the random pool due to having no Spell List Dependencies", statusList.name)
					end
				end
			end
		end
	end

	if next(looseStatusesToApply) then
		for _, statusId in pairs(looseStatusesToApply) do
			if Osi.HasActiveStatus(entity.Uuid.EntityUuid, statusId) == 0 then
				Logger:BasicDebug("Adding loose status %s", statusId)
				table.insert(appliedStatuses, statusId)
			else
				Logger:BasicDebug("Loose status %s is already present", statusId)
			end
		end
	end


	---@type EntryReplacerDictionary
	local replaceMap = TableUtils:DeeplyCopyTable(ConfigurationStructure.config.mutations.lists.entryReplacerDictionary)
	replaceMap.statusLists = replaceMap.statusLists or {}

	local appliedLists = {}

	if next(statusListsPool) then
		if not usingListsWithSpellListDeps then
			local chosenIndex = math.random(TableUtils:CountElements(statusListsPool))
			local count = 0
			for statusListId, numRandomStatusesPerLevel in pairs(statusListsPool) do
				count = count + 1
				if count == chosenIndex then
					local statusList = MutationConfigurationProxy.lists.statusLists[statusListId]
					statusList = statusList.__real or statusList

					Logger:BasicDebug("%s status lists without dependencies are in the pool - randomly chose %s",
						TableUtils:CountElements(statusListsPool),
						statusList.name .. (statusList.modId and (" from mod " .. Ext.Mod.GetMod(statusList.modId).Info.Name) or ""))

					local levelToUse = statusList.useGameLevel and EntityRecorder.Levels[entity.Level.LevelName] or entity.EocLevel.Level

					if levelToUse > 0 and statusList.modId then
						local modReplaceMap = MutationConfigurationProxy.lists.entryReplacerDictionary[statusList.modId]
						if modReplaceMap.statusLists then
							for statReplacement, statsToReplace in pairs(modReplaceMap.statusLists) do
								if not replaceMap.statusLists[statReplacement] then
									replaceMap.statusLists[statReplacement] = statsToReplace
								else
									for _, toReplace in ipairs(statsToReplace) do
										if not TableUtils:IndexOf(replaceMap.statusLists[statReplacement], toReplace) then
											table.insert(replaceMap.statusLists[statReplacement])
										end
									end
								end
							end
							Logger:BasicDebug("Added Mod %'s replacement map to the overall replacement map, as one of it's lists was used",
								Ext.Mod.GetMod(statusList.modId).Info.Name)
						end
					end

					applyStatusLists(entity, levelToUse, statusList, numRandomStatusesPerLevel, appliedStatuses, appliedLists)
					break
				end
			end
		else
			for statusListId, numRandomStatusesPerLevel in pairs(statusListsPool) do
				local statusList = MutationConfigurationProxy.lists.statusLists[statusListId]
				statusList = statusList.__real or statusList

				local levelToUse = 0
				for _, spellListDependency in pairs(statusList.spellListDependencies) do
					local appliedSpellListLevel = entityVar.appliedMutators[SpellListMutator.name].appliedLists[spellListDependency]
					if appliedSpellListLevel then
						levelToUse = levelToUse + appliedSpellListLevel
					end
				end

				if levelToUse > 0 and statusList.modId then
					local modReplaceMap = MutationConfigurationProxy.lists.entryReplacerDictionary[statusList.modId]
					if modReplaceMap.statusLists then
						for statReplacement, statsToReplace in pairs(modReplaceMap.statusLists) do
							if not replaceMap.statusLists[statReplacement] then
								replaceMap.statusLists[statReplacement] = statsToReplace
							else
								for _, toReplace in ipairs(statsToReplace) do
									if not TableUtils:IndexOf(replaceMap.statusLists[statReplacement], toReplace) then
										table.insert(replaceMap.statusLists[statReplacement])
									end
								end
							end
						end
						Logger:BasicDebug("Added Mod %'s replacement map to the overall replacement map, as one of its lists was used",
							Ext.Mod.GetMod(statusList.modId).Info.Name)
					end
				end

				applyStatusLists(entity, levelToUse, statusList, numRandomStatusesPerLevel, appliedStatuses, appliedLists)
			end
		end
	end

	if next(appliedStatuses) then
		for i = #appliedStatuses, 1, -1 do
			local statusToApply = appliedStatuses[i]
			if statusToApply and replaceMap.statusLists[statusToApply] then
				for _, statusToRemove in pairs(replaceMap.statusLists[statusToApply]) do
					if Osi.HasActiveStatus(entity.Uuid.EntityUuid, statusToRemove) == 1 then
						Osi.RemoveStatus(entity.Uuid.EntityUuid, statusToRemove, entity.Uuid.EntityUuid)
						Logger:BasicDebug("Removed %s from the entity as it's marked to be removed by %s", statusToRemove, statusToApply)
					end
					local index = TableUtils:IndexOf(appliedStatuses, statusToRemove)
					if index then
						appliedStatuses[index] = nil
						Logger:BasicDebug("Removed %s from list of statuses to apply as it's marked to be removed by %s", statusToRemove, statusToApply)
					end
				end
			end
		end

		TableUtils:ReindexNumericTable(appliedStatuses)

		Logger:BasicDebug("Applying the following statuses: %s", appliedStatuses)
		for _, statusToApply in ipairs(appliedStatuses) do
			Osi.ApplyStatus(entity.Uuid.EntityUuid, statusToApply, -1, 1)
		end

		entityVar.originalValues[self.name] = appliedStatuses
	end
end

---@return MazzleDocsDocumentation
function StatusListMutator:generateDocs()
	return {
		{
			Topic = self.Topic,
			SubTopic = self.SubTopic,
			content = {
				{
					type = "Heading",
					text = "Status Lists",
				},
				{
					type = "Separator"
				},
				{
					type = "CallOut",
					prefix = "",
					prefix_color = "Yellow",
					text = [[
Dependency On: Spell Lists
Transient: No
Composable: All groups will be combined into one large pool, which will be pulled from randomly post-filter]]
				} --[[@as MazzleDocsCallOut]],
				{
					type = "Separator"
				},
				{
					type = "SubHeading",
					text = "Summary"
				},
				{
					type = "Content",
					text = [[Basically Spell Lists, just with Statuses!]]
				},
				{
					type = "Separator"
				},
				{
					type = "SubHeading",
					text = "Client-Side Content"
				},
				{
					type = "Content",
					text = [[
The mutator is designed very similarily to Spell Lists again, so only the differences are notated:

- There are no level pools - instead, the mutator checks the combiend levels of the linked Spell Lists that were assigned and uses that to determine what level to use for the given list
- If there are no Linked Spell lists, the entity level will be used instead
- There are no criteria due to the Spell List dependency
- There is no Progression Browser in the Status List Designer, as Progressions don't assign statuses.

The rest of the Mutator UI is explained via tooltips to avoid duplicated info and inevitable deprecation of information.]]
				},
				{
					type = "Separator"
				},
				{
					type = "SubHeading",
					text = "Server-Side Implementation"
				},
				{
					type = "Content",
					text = [[Since this mutator only has Random and Guaranteed pools, all statuses are added via Osi: Osi.ApplyStatus(entity.Uuid.EntityUuid, statusToApply, -1, 1)
This forces the status to apply for an infinite duration - reasoning being that any temporary statuses should be given via a Spell cast configured through a given Spell List. Another mutator will be coming down that road that allows conditional, duration-locked status applications.

Building the random pool follows the same general logic as Spell List Mutator:
When determining what statuses end up in the Random pool to be added to the entity, checks are done to ensure:
1. The status isn't already on the entity

Once the final list of statuses are determined, the Replace logic is run, removing any statuses from the final list and the entity's StatusContainer (via Osi.RemoveStatus) if they're marked to be replaced by another status. ]]
				},
			}
		}
	} --[[@as MazzleDocsDocumentation]]
end

---@return {[string]: MazzleDocsContentItem}
function StatusListMutator:generateChangelog()
	return {
	} --[[@as {[string]: MazzleDocsContentItem}]]
end
