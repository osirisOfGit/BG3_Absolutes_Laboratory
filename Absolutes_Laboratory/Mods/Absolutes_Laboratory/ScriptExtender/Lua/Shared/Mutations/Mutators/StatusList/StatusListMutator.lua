Ext.Require("Shared/Mutations/Mutators/StatusList/StatusListDesigner.lua")

---@class StatusListMutatorClass : MutatorInterface
StatusListMutator = MutatorInterface:new("StatusList")

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

---@param mutator StatusListMutator
function StatusListMutator:renderMutator(parent, mutator)
	mutator.values = mutator.values or {}
	Helpers:KillChildren(parent)

	local popup = parent:AddPopup("")

	local statusListDesignerButton = parent:AddButton("Open Status List Designer")
	statusListDesignerButton.UserData = "EnableForMods"
	statusListDesignerButton.OnClick = function()
		StatusListDesigner:launch()
	end
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
			local list = MutationConfigurationProxy.statusLists[value]
			return (list.modId or "_") .. list.name
		end) do
			local list = MutationConfigurationProxy.statusLists[statusListId]

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

				for _, spellListId in ipairs(list.spellListDependencies) do
					local spellList = MutationConfigurationProxy.spellLists[spellListId]
					sep:AddTextLink(spellList.name .. (spellList.modId and string.format(" (from %s)", Ext.Mod.GetMod(spellList.modId).Info.Name) or "")).OnClick = function()
						SpellListDesigner:launch(spellListId)
					end
				end
			end
		end
	end
	mutatorSection:AddButton("Add Status List").OnClick = function()
		Helpers:KillChildren(popup)
		popup:Open()

		for statusListId, statusList in pairs(MutationConfigurationProxy.statusLists) do
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

	local popup = parent:AddPopup("Randomized")

	--#region Randomized Spell Pool Size
	parent:AddSeparatorText("Amount of Random Statuses to Give Per Level")

	statusPool.randomizedStatusPoolSize = statusPool.randomizedStatusPoolSize or {}
	local randomizedStatusPoolSize = statusPool.randomizedStatusPoolSize
	if getmetatable(randomizedStatusPoolSize) and getmetatable(randomizedStatusPoolSize).__call and not randomizedStatusPoolSize() then
		randomizedStatusPoolSize[1] = 1
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
						return
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
		StatusListDesigner:HandleDependences(export, mutator, mutator.values.statusLists, removeMissingDependencies)
	end
end

function StatusListMutator:undoMutator(entity, mutator, primedEntityVar, reprocessTransient)
	for _, statusId in pairs(mutator.originalValues[self.name]) do
		if Osi.HasActiveStatus(entity.Uuid.EntityUuid, statusId) == 1 then
			Logger:BasicDebug("Removing status %s as it was given by Lab", statusId)
			Osi.RemoveStatus(entity.Uuid.EntityUuid, statusId)
		end
	end
end

---@param entity EntityHandle
---@param levelToUse integer
---@param statusList CustomList
---@param numRandomStatusesPerLevel number[]
---@param appliedStatuses string[]
local function applyStatusLists(entity, levelToUse, statusList, numRandomStatusesPerLevel, appliedStatuses)
	Logger:BasicDebug("Applying levels 1 to %s of list %s", levelToUse,
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
							Osi.ApplyStatus(entity.Uuid.EntityUuid, statusId, -1)
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
			Logger:BasicDebug("Giving %s random statuses out of %s from level %s", numRandomStatusesToPick, #randomPool, level)
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
				Osi.ApplyStatus(entity.Uuid.EntityUuid, statusId, -1)
				table.insert(appliedStatuses, statusId)
				Logger:BasicDebug("Added status %s", statusId)
			end
		else
			Logger:BasicDebug("Skipping level %s for random status assignment due to configured size being 0", level)
		end
	end
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
				local statusList = MutationConfigurationProxy.statusLists[statusListId]
				statusList = statusList.__real or statusList
				if statusList then
					if statusList.spellListDependencies and next(statusList.spellListDependencies) then
						for _, spellListDependency in ipairs(statusList.spellListDependencies) do
							if entityVar.appliedMutators[SpellListMutator.name].appliedLists[spellListDependency] then
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
				Osi.ApplyStatus(entity.Uuid.EntityUuid, statusId, -1)
				table.insert(appliedStatuses, statusId)
			else
				Logger:BasicDebug("Loose status %s is already present", statusId)
			end
		end
	end

	if next(statusListsPool) then
		if not usingListsWithSpellListDeps then
			local chosenIndex = math.random(TableUtils:CountElements(statusListsPool))
			local count = 0
			for statusListId, numRandomStatusesPerLevel in pairs(statusListsPool) do
				count = count + 1
				if count == chosenIndex then
					local statusList = MutationConfigurationProxy.statusLists[statusListId]
					statusList = statusList.__real or statusList

					Logger:BasicDebug("%s status lists without dependencies are in the pool - randomly chose %s",
						TableUtils:CountElements(statusListsPool),
						statusList.name .. (statusList.modId and (" from mod " .. Ext.Mod.GetMod(statusList.modId).Info.Name) or ""))

					local levelToUse = entity.EocLevel.Level
					applyStatusLists(entity, levelToUse, statusList, numRandomStatusesPerLevel, appliedStatuses)
					break
				end
			end
		else
			for statusListId, numRandomStatusesPerLevel in pairs(statusListsPool) do
				local statusList = MutationConfigurationProxy.statusLists[statusListId]
				statusList = statusList.__real or statusList

				local levelToUse = 0
				for _, spellListDependency in pairs(statusList.spellListDependencies) do
					local appliedSpellListLevel = entityVar.appliedMutators[SpellListMutator.name].appliedLists[spellListDependency]
					if appliedSpellListLevel then
						levelToUse = levelToUse + appliedSpellListLevel
					end
				end

				applyStatusLists(entity, levelToUse, statusList, numRandomStatusesPerLevel, appliedStatuses)
			end
		end
	end

	if next(appliedStatuses) then
		entityVar.originalValues[self.name] = appliedStatuses
	end
end
