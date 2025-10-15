---@class ProgressionLevel
local progressionLevel = {
	---@type Guid
	id = nil,
	---@type Guid
	modId = nil,
	---@type number
	level = nil,
	---@type ProgressionType
	type = nil,
	---@class ProgressionSpells
	spellLists = {
		---@type string[]
		AddSpells = {},
		---@type string[]
		SelectSpells = {}
	},
	---@class ProgressionPassives
	passiveLists = {
		---@type string[]
		PassivePrototypesAdded = {},
		---@type string[]
		PassivePrototypesRemoved = {},
		---@type string[]
		SelectPassives = {}
	}
}

---@class ProgressionTable
---@field progressionLevels ProgressionLevel[]
---@field name string
---@field tableId tableUUID

---@alias tableUUID Guid

ListConfigurationManager = {
	---@type {[tableUUID] : ProgressionTable}
	progressionIndex = setmetatable({}, {
		__mode = Ext.IsClient() and "v" or nil,
		__index = function(t, k)
			ListConfigurationManager:buildProgressionIndex(k)
			return rawget(t, k)
		end,
		__call = function(t, ...)
			for key in pairs(ListConfigurationManager.progressionIndex) do
				t[key] = nil
			end
		end
	}),
	---@type Guid[]
	progressionTables = {},
	---@enum ProgressionNodes
	progressionNodes = {
		["AddSpells"] = 1,
		["PassivePrototypesAdded"] = 2,
		["PassivePrototypesRemoved"] = 3,
		["PassivesAdded"] = 4,
		["PassivesRemoved"] = 5,
		["SelectPassives"] = 6,
		["SelectSpells"] = 7,
		[1] = "AddSpells",
		[2] = "PassivePrototypesAdded",
		[3] = "PassivePrototypesRemoved",
		[4] = "PassivesAdded",
		[5] = "PassivesRemoved",
		[6] = "SelectPassives",
		[7] = "SelectSpells",
	},
	settings = ConfigurationStructure.config.mutations.settings.customLists,
	listsConfig = ConfigurationStructure.config.mutations.lists
}

---@param tableUUID Guid?
function ListConfigurationManager:buildProgressionIndex(tableUUID)
	if tableUUID or not next(self.progressionIndex) or not next(self.progressionTables) then
		Ext.Utils.ProfileBegin(("Indexing %s"):format(tableUUID or "All Progressions"))
		local progressionSources = Ext.StaticData.GetSources("Progression")
		for _, progressionId in pairs(Ext.StaticData.GetAll("Progression")) do
			---@type ResourceProgression
			local progression = Ext.StaticData.Get(progressionId, "Progression")

			if tableUUID and progression.TableUUID ~= tableUUID then
				goto continue
			end

			if not rawget(self.progressionIndex, progression.TableUUID) then
				local name = progression.Name
				if TableUtils:IndexOf(self.progressionIndex, function(value)
						return value.name == name
					end) then
					name = name .. (" (%s)"):format(progressionId:sub(#progressionId - 5))
				end

				self.progressionIndex[progression.TableUUID] = {
					name = name,
					tableId = progression.TableUUID,
					progressionLevels = {}
				}
			elseif TableUtils:IndexOf(self.progressionIndex[progression.TableUUID].progressionLevels, function(value)
					return value.id == progressionId
				end)
			then
				goto continue
			end

			---@type ProgressionLevel
			local progressionIndex = {
				id = progressionId,
				level = progression.Level,
				type = tostring(progression.ProgressionType)
			}

			local nodesToIterate = {}
			for node, nodeEntry in pairs(progression) do
				---@cast node string
				if self.progressionNodes[node]
					and ((type(nodeEntry) == "string" and nodeEntry ~= "")
						or (type(nodeEntry) == "userdata" and next(Ext.Types.Serialize(nodeEntry))))
				then
					local entries = {}
					if type(nodeEntry) == "table" or type(nodeEntry) == "userdata" then
						for _, entry in ipairs(nodeEntry) do
							table.insert(entries, entry)
						end
					else
						local splitTable = {}
						for _, val in string.gmatch(progression[node], "([^;]+)") do
							table.insert(splitTable, val)
						end
						if next(splitTable) then
							for _, entry in ipairs(splitTable) do
								table.insert(nodesToIterate[node], entry)
							end
						end
					end

					for _, entry in ipairs(entries) do
						if node:find("Spells") then
							---@cast entry ResourceProgressionSpell|ResourceProgressionAddedSpell

							---@type ResourceSpellList
							local progSpellList = Ext.StaticData.Get(entry.SpellUUID, "SpellList")

							if progSpellList then
								progressionIndex["spellLists"] = progressionIndex["spellLists"] or {}
								progressionIndex["spellLists"][node] = progressionIndex["spellLists"][node] or {}
								for _, spellName in pairs(progSpellList.Spells) do
									table.insert(progressionIndex["spellLists"][node], spellName)
								end
							else
								Logger:BasicWarning("SpellUUID %s from Progression %s (%s, Level %d) does not exist as a spell list",
									entry.SpellUUID,
									progressionId,
									progression.Name,
									progression.Level)
							end
						elseif node:find("Passive") then
							---@cast entry ResourceProgressionPassive|StatsPassivePrototype|string
							if type(entry) == "string" then
								progressionIndex["passiveLists"] = progressionIndex["passiveLists"] or {}
								progressionIndex["passiveLists"][node] = progressionIndex["passiveLists"][node] or {}
								table.insert(progressionIndex["passiveLists"][node], entry)
							elseif Ext.Types.GetObjectType(entry) == "stats::PassivePrototype" then
								progressionIndex["passiveLists"] = progressionIndex["passiveLists"] or {}
								progressionIndex["passiveLists"][node] = progressionIndex["passiveLists"][node] or {}
								table.insert(progressionIndex["passiveLists"][node], entry.Name)
							else
								---@type ResourcePassiveList
								local passiveList = Ext.StaticData.Get(entry.UUID, "PassiveList")

								if passiveList then
									progressionIndex["passiveLists"] = progressionIndex["passiveLists"] or {}
									progressionIndex["passiveLists"][node] = progressionIndex["passiveLists"][node] or {}
									for _, passiveName in pairs(passiveList.Passives) do
										table.insert(progressionIndex["passiveLists"][node], passiveName)
									end
								else
									Logger:BasicWarning("Passive UUID %s from Progression %s (%s, Level %d) does not exist as a spell list",
										entry.UUID,
										progressionId,
										progression.Name,
										progression.Level)
								end
							end
						end
					end
				end
			end
			if (progressionIndex["passiveLists"] or progressionIndex["spellLists"]) then
				progressionIndex.modId = TableUtils:IndexOf(progressionSources, function(value)
					return TableUtils:IndexOf(value, progressionId) ~= nil
				end)

				table.insert(self.progressionIndex[progression.TableUUID].progressionLevels, progressionIndex)
			end

			if not next(self.progressionIndex[progression.TableUUID].progressionLevels) then
				self.progressionIndex[progression.TableUUID] = nil
			elseif not TableUtils:IndexOf(self.progressionTables, progression.TableUUID) then
				table.insert(self.progressionTables, progression.TableUUID)
			end

			::continue::
		end
		Ext.Utils.ProfileEnd(("Indexing %s"):format(tableUUID or "All Progressions"))
	end
end

---@param progressionTableId Guid
---@param level number
---@param entryName string
---@param configKey "spellLists"|"passiveLists"
---@return boolean
function ListConfigurationManager:hasSameEntryInLowerLevel(progressionTableId, level, entryName, configKey)
	if level <= 1 then
		return false
	end

	Ext.Utils.ProfileBegin(("Checking if %s offers the same entry in a level lower than %d"):format(self.progressionIndex[progressionTableId].name, level))
	for _, progEntry in pairs(self.progressionIndex[progressionTableId].progressionLevels) do
		if progEntry.level < level and progEntry[configKey] then
			if TableUtils:IndexOf(progEntry[configKey], function(value)
					return TableUtils:IndexOf(value, entryName) ~= nil
				end) then
				Ext.Utils.ProfileEnd(("Checking if %s offers the same entry in a level lower than %d"):format(self.progressionIndex[progressionTableId].name, level))
				return true
			end
		end
	end
	Ext.Utils.ProfileEnd(("Checking if %s offers the same entry in a level lower than %d"):format(self.progressionIndex[progressionTableId].name, level))

	return false
end

---@param export MutationsConfig
---@param mutator Mutator
---@param lists Guid[]
---@param removeMissingDependencies boolean?
function ListConfigurationManager:HandleDependences(export, mutator, lists, removeMissingDependencies, configKey)
	local progressionSources = Ext.StaticData.GetSources("Progression")

	local replaceMap = removeMissingDependencies == true
		and export.lists.entryReplacerDictionary
		or TableUtils:DeeplyCopyTable(ConfigurationStructure.config.mutations.lists.entryReplacerDictionary._real)

	---@param statName string
	---@param container table?
	---@return boolean?
	local function buildStatDependency(statName, container)
		---@type (SpellData|PassiveData|StatusData)?
		local stat = Ext.Stats.Get(statName)
		if stat then
			if not removeMissingDependencies then
				container = container or mutator
				container.modDependencies = container.modDependencies or {}
				if not container.modDependencies[stat.OriginalModId] then
					local name, author, version = Helpers:BuildModFields(stat.OriginalModId)
					if author == "Larian" then
						return true
					end

					container.modDependencies[stat.OriginalModId] = {
						modName = name,
						modAuthor = author,
						modVersion = version,
						modId = stat.OriginalModId,
						packagedItems = {}
					}
				end
				local name = Ext.Loca.GetTranslatedString(stat.DisplayName, statName)
				name = name == "" and statName or name
				container.modDependencies[stat.OriginalModId].packagedItems[statName] = name
			end
			return true
		else
			return false
		end
	end

	if replaceMap[configKey] and next(replaceMap[configKey]) then
		if not removeMissingDependencies then
			replaceMap.modDependencies = export.lists.entryReplacerDictionary.modDependencies
		end
		for statName, entriesToReplace in pairs(replaceMap[configKey]) do
			for i, statBeingReplaced in ipairs(entriesToReplace) do
				if not buildStatDependency(statBeingReplaced, replaceMap) then
					replaceMap[configKey][statName][i] = nil
				end
			end

			TableUtils:ReindexNumericTable(replaceMap[configKey][statName])
		end
		if not removeMissingDependencies then
			export.lists.entryReplacerDictionary.modDependencies = replaceMap.modDependencies
			export.lists.entryReplacerDictionary[configKey] = replaceMap[configKey]
		end
	end

	for _, listId in pairs(lists) do
		---@type CustomList
		local list = MutationConfigurationProxy.lists[configKey][listId]
		if list then
			local listModId = list.modId
			if not listModId then
				--- @type CustomList
				local listDef = removeMissingDependencies == true
					and export.lists[configKey][listId]
					or TableUtils:DeeplyCopyTable(ConfigurationStructure.config.mutations.lists[configKey][listId]._real)

				if listDef.linkedProgressionTableIds then
					for i, progressionTableId in pairs(listDef.linkedProgressionTableIds) do
						local progressionTable = self.progressionIndex[progressionTableId]
						if progressionTable then
							for _, progressionLevel in pairs(progressionTable.progressionLevels) do
								local progressionId = progressionLevel.id
								local progressionSource = TableUtils:IndexOf(progressionSources, function(value)
									return TableUtils:IndexOf(value, progressionId) ~= nil
								end)
								if progressionSource then
									listDef.modDependencies = listDef.modDependencies or {}
									if not listDef.modDependencies[progressionSource] then
										local name, author, version = Helpers:BuildModFields(progressionSource)
										if author == "Larian" then
											goto continue
										end
										listDef.modDependencies[progressionSource] = {
											modName = name,
											modAuthor = author,
											modVersion = version,
											modId = progressionSource,
											packagedItems = {}
										}
									end
									listDef.modDependencies[progressionSource].packagedItems[progressionId] = progressionLevel.name
								end
								::continue::
							end
						elseif removeMissingDependencies then
							listDef.linkedProgressionTableIds[i] = nil
						end
					end
				end

				if listDef.levels then
					for level, levelSubList in pairs(listDef.levels) do
						if levelSubList.linkedProgressions then
							for progressionTableId, sublists in pairs(levelSubList.linkedProgressions) do
								if self.progressionIndex[progressionTableId] then
									for subListName, entries in pairs(sublists) do
										if next(entries._real or entries) then
											for i, entry in pairs(entries) do
												if not buildStatDependency(entry, listDef) then
													entries[i] = nil
												end
											end
											TableUtils:ReindexNumericTable(entries)
										else
											sublists[subListName].delete = true
											sublists[subListName] = nil
										end
									end
									if not next(sublists._real or sublists) then
										sublists.delete = true
										levelSubList.linkedProgressions[progressionTableId] = nil
										if not next(levelSubList.linkedProgressions._real or levelSubList.linkedProgressions) then
											levelSubList.linkedProgressions.delete = true
											levelSubList.linkedProgressions = nil
										end
										goto nextProgression
									end

									for _, progressionLevel in pairs(self.progressionIndex[progressionTableId].progressionLevels) do
										if progressionLevel.level == level then
											local progressionId = progressionLevel.id

											---@type ResourceProgression
											local progression = Ext.StaticData.Get(progressionId, "Progression")
											if not progression then
												levelSubList.linkedProgressions[progressionTableId] = nil
											elseif not removeMissingDependencies then
												local progressionSource = TableUtils:IndexOf(progressionSources, function(value)
													return TableUtils:IndexOf(value, progressionId) ~= nil
												end)
												if progressionSource then
													listDef.modDependencies = listDef.modDependencies or {}
													if not listDef.modDependencies[progressionSource] then
														local name, author, version = Helpers:BuildModFields(progressionSource)
														if author == "Larian" then
															goto continue
														end
														listDef.modDependencies[progressionSource] = {
															modName = name,
															modAuthor = author,
															modVersion = version,
															modId = progressionSource,
															packagedItems = {}
														}
													end
													listDef.modDependencies[progressionSource].packagedItems[progressionId] = progression.Name
												end
												::continue::
											end
										end
									end
								end
								::nextProgression::
							end
						end

						if levelSubList.manuallySelectedEntries then
							for e, entries in pairs(levelSubList.manuallySelectedEntries) do
								for i, entry in pairs(entries) do
									if not buildStatDependency(entry, listDef) then
										entries[i] = nil
									end
								end
								TableUtils:ReindexNumericTable(entries)
								if not next(entries._real or entries) then
									entries.delete = true
									levelSubList.manuallySelectedEntries[e] = nil
								end
							end
							if not next(levelSubList.manuallySelectedEntries._real or levelSubList.manuallySelectedEntries) then
								levelSubList.manuallySelectedEntries.delete = true
								levelSubList.manuallySelectedEntries = nil
							end
						end
					end
				end

				listDef.defaultPool = ConfigurationStructure.config.mutations.settings.customLists.defaultPool[configKey]
				export.lists[configKey] = export.lists[configKey] or {}
				if not export.lists[configKey][listId] then
					export.lists[configKey][listId] = listDef
				end
			else
				local name, author, version = Helpers:BuildModFields(listModId)
				mutator.modDependencies = mutator.modDependencies or {}
				mutator.modDependencies[listModId] = {
					modAuthor = author,
					modName = name,
					modVersion = version,
					modId = listModId,
					packagedItems = nil
				}
			end
		end
	end
end

---@param configBase MutationsConfig?
function ListConfigurationManager:maintainLists(configBase)
	configBase = configBase or ConfigurationStructure.config.mutations
	if configBase.spellLists then
		for guid, list in pairs(configBase.spellLists) do
			---@cast list CustomList
			configBase.lists.spellLists[guid] = TableUtils:DeeplyCopyTable(list._real or list)
		end
		configBase.spellLists.delete = true
		configBase.spellLists = nil
	end

	if configBase.passiveLists then
		for guid, list in pairs(configBase.passiveLists) do
			configBase.lists.passiveLists[guid] = TableUtils:DeeplyCopyTable(list._real or list)
		end
		configBase.passiveLists.delete = true
		configBase.passiveLists = nil
	end

	if configBase.statusLists then
		for guid, list in pairs(configBase.statusLists) do
			configBase.lists.statusLists[guid] = TableUtils:DeeplyCopyTable(list._real or list)
		end
		configBase.statusLists.delete = true
		configBase.statusLists = nil
	end

	if configBase.listEntryReplaceMap then
		configBase.lists.entryReplacerDictionary = TableUtils:DeeplyCopyTable(configBase.listEntryReplaceMap._real or configBase.listEntryReplaceMap)
		configBase.listEntryReplaceMap.delete = true
		configBase.listEntryReplaceMap = nil
	end

	for _, list in TableUtils:CombinedPairs(configBase.lists.passiveLists,
		configBase.lists.spellLists,
		configBase.lists.statusLists)
	do
		if list.levels then
			for _, levelList in TableUtils:OrderedPairs(list.levels) do
				if levelList.linkedProgressions then
					list.linkedProgressionTableIds = list.linkedProgressionTableIds or {}
					for progTableId, customSubList in TableUtils:OrderedPairs(levelList.linkedProgressions) do
						if not TableUtils:IndexOf(list.linkedProgressionTableIds, progTableId) then
							table.insert(list.linkedProgressionTableIds, progTableId)
						end
						if not next(customSubList._real or customSubList) then
							customSubList.delete = true
							levelList.linkedProgressions[progTableId] = nil
						end
					end
					if not next(levelList.linkedProgressions._real or levelList.linkedProgressions) then
						levelList.linkedProgressions.delete = true
						levelList.linkedProgressions = nil
					end
				end
			end
		end
	end
end

Ext.RegisterConsoleCommand("Lab_DumpProgressions", function(cmd, ...)
	local self = ListConfigurationManager

	self.progressionIndex()
	self:buildProgressionIndex()

	local progLog = Logger:new("ProgressionDumper.txt", false)
	progLog:ClearLogFile()
	progLog:BasicDebug("%s", self.progressionIndex)
end)
