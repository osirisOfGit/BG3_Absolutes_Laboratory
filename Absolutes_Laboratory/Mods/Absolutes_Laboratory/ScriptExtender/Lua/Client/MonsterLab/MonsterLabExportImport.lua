MonsterLabExportImport = {}

---@param monsterLabConfig MonsterLabConfig
---@return { [string]: ModDependency } modCache
---@return { [string]: DependencyFailure[] } failedDependencies
function MonsterLabExportImport:ValidateConfig(monsterLabConfig)
	---@type {[Guid]: ModDependency}
	local modCache = {}

	---@type {[Guid]: DependencyFailure[]}
	local failedDependencies = {}

	for profileId, profile in pairs(monsterLabConfig.profiles) do
		for _, profileRule in pairs(profile.encounters) do
			if profileRule.sourceMod then
				local modId = profileRule.sourceMod.modId
				local modDependency = profileRule.sourceMod
				modCache[modId] = modDependency
				if modDependency.modName then
					if not Ext.Mod.GetMod(modId) then
						failedDependencies[modId] = failedDependencies[modId] or {}
						table.insert(failedDependencies[modId], {
							type = "Folder",
							packagedItems = modDependency.packagedItems
						} --[[@as DependencyFailure]]
						)

						modCache[modId] = modDependency
					end
				end
			end
		end
	end

	for _, folder in pairs(monsterLabConfig.folders) do
		if not folder.modId then
			for _, encounter in pairs(folder.encounters) do
				if encounter.modDependencies and next(encounter.modDependencies) then
					for modId, modDependency in pairs(encounter.modDependencies) do
						modCache[modId] = modDependency
						if modDependency.modName then
							if not Ext.Mod.GetMod(modId) then
								failedDependencies[modId] = failedDependencies[modId] or {}
								table.insert(failedDependencies[modId], {
									type = "Encounter",
									folderName = folder.name,
									mutationName = encounter.name,
									packagedItems = modDependency.packagedItems
								} --[[@as DependencyFailure]]
								)

								modCache[modId] = modDependency
							end
						end
					end
				end
				for _, entity in pairs(encounter.entities) do
					for _, ruleset in pairs(entity.rulesetModifiers) do
						for _, mutator in pairs(ruleset.mutators) do
							if mutator.modDependencies then
								for modId, modDependency in pairs(mutator.modDependencies) do
									modCache[modId] = modDependency
									if modDependency.modName then
										if not Ext.Mod.GetMod(modId) then
											failedDependencies[modId] = failedDependencies[modId] or {}
											table.insert(failedDependencies[modId], {
												type = "Mutator",
												target = mutator.targetProperty,
												folderName = folder.name,
												mutationName = encounter.name,
												packagedItems = modDependency.packagedItems
											} --[[@as DependencyFailure]]
											)

											modCache[modId] = modDependency
										end
									end
								end
							end
							mutator.modDependencies = nil
						end
					end
				end
			end
		else
			local name, author, version = Helpers:BuildModFields(folder.modId)
			modCache[folder.modId] = {
				modAuthor = author,
				modName = name,
				modVersion = version,
				modId = folder.modId,
				packagedItems = nil
			} --[[@as ModDependency]]
		end
	end

	for _, listType in pairs(MutationModProxy.listTypes) do
		if monsterLabConfig.lists[listType] then
			for _, list in pairs(monsterLabConfig.lists[listType]) do
				---@cast list CustomList
				if not list.modId then
					if list.modDependencies then
						for modId, modDependency in pairs(list.modDependencies) do
							modCache[modId] = modDependency
							if modDependency.modName then
								if not Ext.Mod.GetMod(modId) then
									failedDependencies[modId] = failedDependencies[modId] or {}
									table.insert(failedDependencies[modId], {
										type = listType:upper(),
										target = list.name,
										packagedItems = modDependency.packagedItems
									} --[[@as DependencyFailure]]
									)
								end
							end
						end
						list.modDependencies = nil
					end
				else
					local name, author, version = Helpers:BuildModFields(list.modId)
					modCache[list.modId] = {
						modAuthor = author,
						modName = name,
						modVersion = version,
						modId = list.modId,
						packagedItems = nil
					} --[[@as ModDependency]]
				end
			end
		end
	end

	return modCache, failedDependencies
end

---@param monsterLabConfig MonsterLabConfig
---@param extraDependencies ModDependency[]
---@return string?
function MonsterLabExportImport:BuildMetaDependencyBlock(monsterLabConfig, extraDependencies)
	local mods = self:ValidateConfig(TableUtils:DeeplyCopyTable(monsterLabConfig))

	local lab = Ext.Mod.GetMod(ModuleUUID).Info
	mods[ModuleUUID] = {
		modId = ModuleUUID,
		modName = lab.Name,
		modAuthor = lab.Author,
		modVersion = lab.ModVersion,
		packagedItems = nil
	}

	local extraDependencies = TableUtils:DeeplyCopyTable(extraDependencies)
	for modId in pairs(mods) do
		table.insert(extraDependencies, modId)
	end

	return MutationExternalProfileUtility:buildMetaBlock(extraDependencies)
end

function MonsterLabExportImport:exportProfile(forMod, ...)
	---@type MonsterLabConfig
	local export = {
		rulesets = {},
		folders = {},
		profiles = {},
		---@type MutationLists
		lists = {}
	}

	---@type {[Guid] : ModDependency}
	local dependencies = {}

	local names = ""

	for _, profileId in pairs({ ... }) do
		local profile = TableUtils:DeeplyCopyTable(MonsterLabConfigurationProxy.profiles[profileId])

		if #names == 0 then
			names = profile.name
		else
			names = names .. "-" .. profile.name
		end

		export.profiles[profileId .. "Exported"] = profile

		for _, encounterRule in ipairs(profile.encounters) do
			local folder = MonsterLabConfigurationProxy.folders[encounterRule.folderId]

			if not folder.modId then
				if not export.folders[encounterRule.folderId] then
					export.folders[encounterRule.folderId] = {
						name = folder.name,
						description = folder.description,
						encounters = {}
					}
				end

				local encounter = TableUtils:DeeplyCopyTable(folder.encounters[encounterRule.encounterId])

				export.folders[encounterRule.folderId].encounters[encounterRule.encounterId] = encounter

				for _, mlEntity in pairs(encounter.entities) do
					---@type CharacterTemplate
					local characterTemplate = Ext.ClientTemplate.GetTemplate(mlEntity.template)

					local fileName = characterTemplate.FileName:gsub("^.*[\\/]Mods[\\/]", ""):gsub("^.*[\\/]Public[\\/]", ""):match("([^/\\]+)")
					fileName = fileName ~= "" and fileName or characterTemplate.FileName

					if not TableUtils:IndexOf({ "Shared", "SharedDev", "Gustav" }, fileName) then
						---@type ModuleInfo
						local modInfo
						for _, modId in pairs(Ext.Mod.GetLoadOrder()) do
							local mod = Ext.Mod.GetMod(modId)
							if fileName:find(mod.Info.Directory) then
								modInfo = mod.Info
								break
							end
						end

						encounter.modDependencies = encounter.modDependencies or {}
						if not encounter.modDependencies[modInfo.ModuleUUID] then
							encounter.modDependencies[modInfo.ModuleUUID] = {
								modName = modInfo.Name,
								modAuthor = modInfo.Author,
								modVersion = modInfo.ModVersion,
								modId = modInfo.ModuleUUID,
								packagedItems = {}
							}

							encounter.modDependencies[modInfo.ModuleUUID].packagedItems[mlEntity.template] = characterTemplate.DisplayName:Get() or characterTemplate.Name
						end
					end

					for rulesetId, ruleset in pairs(mlEntity.rulesetModifiers) do
						if rulesetId ~= "Base" and not export.rulesets[rulesetId] then
							local ruleset = TableUtils:DeeplyCopyTable(MonsterLabConfigurationProxy.rulesets[rulesetId])
							if not ruleset.modId then
								export.rulesets[rulesetId] = ruleset
							else
								---@type ModuleInfo
								local modInfo = Ext.Mod.GetMod(ruleset.modId).Info

								encounter.modDependencies = encounter.modDependencies or {}
								if not encounter.modDependencies[modInfo.ModuleUUID] then
									encounter.modDependencies[modInfo.ModuleUUID] = {
										modName = modInfo.Name,
										modAuthor = modInfo.Author,
										modVersion = modInfo.ModVersion,
										modId = modInfo.ModuleUUID,
										packagedItems = {}
									}

									encounter.modDependencies[modInfo.ModuleUUID].packagedItems[rulesetId] = ruleset.name
								end
							end
						end

						for _, mutator in pairs(ruleset.mutators) do
							MutatorInterface:handleDependencies(export, mutator)
						end
					end
				end
			else
				local name, author, version = Helpers:BuildModFields(folder.modId)
				dependencies[folder.modId] = {
					modAuthor = author,
					modName = name,
					modVersion = version,
					modId = folder.modId,
					packagedItems = nil
				} --[[@as ModDependency]]

				encounterRule.sourceMod = dependencies[folder.modId]
			end
		end
	end

	if forMod then
		names = MonsterLabModProxy.FileName
		FileUtils:SaveStringContentToFile("ExportedProfiles/MonsterLab/ExportedModMetaLsxDependencies.lsx", self:BuildMetaDependencyBlock(export, dependencies) or "")
	end

	FileUtils:SaveTableToFile("ExportedProfiles/MonsterLab/" .. names .. ".json", {
		["monsterLab"] = export
	})
end

---@type ExtuiWindow
local window

---@param export {["monsterLab"]: MonsterLabConfig}
---@return fun()? import
---@return {[Guid]: ModDependency}? modCache
---@return { [string]: DependencyFailure[] }? failedDependencies
---@return fun()? dependencyWindow
function MonsterLabExportImport:importProfile(export)
	local importedMonsterLab = TableUtils:DeeplyCopyTable(export["monsterLab"])
	local monsterLabConfig = ConfigurationStructure.config.monsterLab

	local modCache, failedDependencies = self:ValidateConfig(importedMonsterLab)

	local function import()
		for profileId, profile in pairs(importedMonsterLab.profiles) do
			if monsterLabConfig.profiles[profileId] then
				monsterLabConfig.profiles[profileId].delete = true
			end

			if TableUtils:IndexOf(monsterLabConfig.profiles, function(value)
					return value.name == profile.name
				end)
			then
				profile.name = string.format("%s (%s)", profile.name, profileId:sub(1, 3))
			end

			monsterLabConfig.profiles[profileId] = profile
		end

		for rulesetId, ruleset in pairs(importedMonsterLab.rulesets) do
			if monsterLabConfig.rulesets[rulesetId] then
				monsterLabConfig.rulesets[rulesetId].delete = true
			end

			if TableUtils:IndexOf(monsterLabConfig.rulesets, function (value)
				return value.name == ruleset.name
			end) then
				ruleset.name = ruleset.name .. " - Imported"
			end

			monsterLabConfig.rulesets[rulesetId] = ruleset
		end

		for folderId, folder in pairs(importedMonsterLab.folders) do
			if monsterLabConfig.folders[folderId] then
				monsterLabConfig.folders[folderId].delete = true
			end

			if TableUtils:IndexOf(monsterLabConfig.folders, function(value)
					return value.name == folder.name
				end) then
				folder.name = string.format("%s - %s", folder.name, "Imported")
			end

			for _, encounters in pairs(folder.encounters) do
				for _, entity in pairs(encounters.entities) do
					for _, ruleset in pairs(entity.rulesetModifiers) do
						for _, mutator in ipairs(ruleset.mutators) do
							MutatorInterface:handleDependencies(importedMonsterLab, mutator, true)
						end
					end
				end
			end

			monsterLabConfig.folders[folderId] = folder
		end

		local mutationsConfig = ConfigurationStructure.config.mutations
		if importedMonsterLab.lists.entryReplacerDictionary then
			for _, listType in pairs(MutationModProxy.listTypes) do
				if importedMonsterLab.lists.entryReplacerDictionary[listType] and next(importedMonsterLab.lists.entryReplacerDictionary[listType]) then
					mutationsConfig.lists.entryReplacerDictionary = mutationsConfig.lists.entryReplacerDictionary or {}
					mutationsConfig.lists.entryReplacerDictionary[listType] = mutationsConfig.lists.entryReplacerDictionary[listType] or {}

					for entryName, replacementMap in pairs(importedMonsterLab.lists.entryReplacerDictionary[listType]) do
						mutationsConfig.lists.entryReplacerDictionary[listType][entryName] = mutationsConfig.lists.entryReplacerDictionary[listType][entryName] or {}
						for _, replacement in ipairs(replacementMap) do
							if not TableUtils:IndexOf(mutationsConfig.lists.entryReplacerDictionary[listType][entryName], replacement) then
								table.insert(mutationsConfig.lists.entryReplacerDictionary[listType][entryName], replacement)
							end
						end
					end
				end
			end
		end

		for _, listType in pairs(MutationModProxy.listTypes) do
			if importedMonsterLab.lists[listType] then
				for listId, list in pairs(importedMonsterLab.lists[listType]) do
					if mutationsConfig.lists[listType][listId] then
						mutationsConfig.lists[listType][listId].delete = true
					end

					if TableUtils:IndexOf(mutationsConfig.lists[listType], function(value)
							return value.name == list.name
						end)
					then
						list.name = string.format("%s - %s", list.name, "Imported")
					end

					mutationsConfig.lists[listType][listId] = list
				end
			end
		end
	end

	local function buildDepWindow()
		if not window then
			window = Ext.IMGUI.NewWindow("Dependency Report")
			window.Closeable = true
			window:SetStyle("WindowMinSize", 250 * Styler:ScaleFactor(), 400 * Styler:ScaleFactor())
		else
			window.Open = true
			window:SetFocus()
		end

		Helpers:KillChildren(window)

		for modId, failedDependency in TableUtils:OrderedPairs(failedDependencies, function(key, value)
			return modCache[key].modName
		end) do
			local modInfo = modCache[modId]
			local header = window:AddCollapsingHeader(string.format("%s v%s by %s", modInfo.modName, table.concat(modInfo.modVersion, "."), modInfo.modAuthor:gsub("\\n", " ")))

			for _, dep in TableUtils:OrderedPairs(failedDependency, function(key, value)
				return value.type .. (value.folderName or "") .. (value.encounterName or "") .. value.target
			end) do
				header:AddSeparatorText(string.format("%s: %s %s", dep.type, dep.target, dep.folderName and ("|" .. dep.folderName .. "/" .. dep.encounterName) or "")).Font = "Large"

				local itemsTable = header:AddTable("items", 2)
				local itemHeaderRow = itemsTable:AddRow()
				itemHeaderRow.Headers = true
				itemHeaderRow:AddCell():AddText("Name")
				itemHeaderRow:AddCell():AddText("ID")
				for id, name in pairs(dep.packagedItems) do
					local row = itemsTable:AddRow()
					row:AddCell():AddText(name)
					row:AddCell():AddText(id)
				end

				header:AddNewLine()
			end
		end
	end

	if next(failedDependencies) then
		return import, modCache, failedDependencies, buildDepWindow
	else
		import()
	end
end
