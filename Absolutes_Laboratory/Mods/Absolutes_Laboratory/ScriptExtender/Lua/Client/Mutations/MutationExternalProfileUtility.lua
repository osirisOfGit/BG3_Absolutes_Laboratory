MutationExternalProfileUtility = {}

---@param importedMutations MutationsConfig
---@return { [string]: ModDependency } modCache
---@return { [string]: DependencyFailure[] } failedDependencies
function MutationExternalProfileUtility:ValidateMutations(importedMutations)
	---@type {[Guid]: ModDependency}
	local modCache = {}

	---@type {[Guid]: DependencyFailure[]}
	local failedDependencies = {}

	---@param folderName string
	---@param mutationName string
	---@param selector Selector
	local function validateSelector(folderName, mutationName, selector)
		if type(selector) == "table" then
			if selector.modDependencies then
				for modId, modDependency in pairs(selector.modDependencies) do
					modCache[modId] = modDependency
					if modDependency.modName then
						if not Ext.Mod.GetMod(modId) then
							failedDependencies[modId] = failedDependencies[modId] or {}
							table.insert(failedDependencies[modId], {
								type = "Selector",
								target = selector.criteriaCategory,
								folderName = folderName,
								mutationName = mutationName,
								packagedItems = modDependency.packagedItems
							} --[[@as DependencyFailure]]
							)
						end
					end
				end
				selector.modDependencies = nil
			end

			if selector.subSelectors then
				for _, subSelector in pairs(selector.subSelectors) do
					validateSelector(folderName, mutationName, subSelector)
				end
			end
		end
	end

	for profileId, profile in pairs(importedMutations.profiles) do
		for _, profileRule in pairs(profile.mutationRules) do
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

	for _, folder in pairs(importedMutations.folders) do
		if not folder.modId then
			for _, mutation in pairs(folder.mutations) do
				for _, selector in pairs(mutation.selectors) do
					validateSelector(folder.name, mutation.name, selector)
				end

				for _, mutator in pairs(mutation.mutators) do
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
										mutationName = mutation.name,
										packagedItems = modDependency.packagedItems
									} --[[@as DependencyFailure]]
									)

									modCache[modId] = modDependency
								end
							end
						end
						mutator.modDependencies = nil
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
		if importedMutations[listType] then
			for _, list in pairs(importedMutations[listType]) do
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

local dependencyBlock = [[
<node id="ModuleShortDesc">
	<attribute id="Folder" type="LSWString" value="%s" />
	<attribute id="MD5" type="LSString" value="" />
	<attribute id="Name" type="FixedString" value="%s" />
	<attribute id="UUID" type="FixedString" value="%s" />
	<attribute id="Version64" type="int64" value="%s" />
</node>
]]

---@param mutationConfig MutationsConfig
---@param extraDependencies ModDependency[]
---@return string?
function MutationExternalProfileUtility:BuildMetaDependencyBlock(mutationConfig, extraDependencies)
	local mods = self:ValidateMutations(TableUtils:DeeplyCopyTable(mutationConfig))

	local lab = Ext.Mod.GetMod(ModuleUUID).Info
	mods[ModuleUUID] = {
		modId = ModuleUUID,
		modName = lab.Name,
		modAuthor = lab.Author,
		modVersion = lab.ModVersion,
		packagedItems = nil
	}

	if next(mods) then
		local output = ""
		for modId in TableUtils:CombinedPairs(mods, extraDependencies) do
			local modInfo = Ext.Mod.GetMod(modId)
			if modInfo then
				local modInfo = modInfo.Info
				if #output ~= 0 then
					output = output .. "\n"
				end

				local ver = 0

				ver = ver + (modInfo.ModVersion[1] * 36028797018963968)
				ver = ver + (modInfo.ModVersion[2] * 140737488355328)
				ver = ver + (modInfo.ModVersion[3] * 2147483648)
				ver = ver + (modInfo.ModVersion[4] * 1)

				output = output .. string.format(dependencyBlock,
					modInfo.Directory,
					modInfo.Name,
					modInfo.ModuleUUID,
					ver)
			end
		end
		if #output > 0 then
			return output
		end
	end
end

---@param forMod boolean
---@param ... Guid
function MutationExternalProfileUtility:exportProfile(forMod, ...)
	---@type MutationsConfig
	---@diagnostic disable-next-line: missing-fields
	local export = {
		profiles = {},
		folders = {},
		prepPhaseMarkers = {},
		spellLists = {},
		statusLists = {},
		passiveLists = {},
	}

	for _, listType in pairs(MutationModProxy.listTypes) do
		export[listType] = {}
	end

	local names = ""

	---@type {[Guid] : ModDependency}
	local mutationDependencies = {}

	for _, profileID in pairs({ ... }) do
		---@type MutationProfile
		local profile = TableUtils:DeeplyCopyTable(MutationConfigurationProxy.profiles[profileID]._real)

		if #names > 0 then
			names = names .. "-" .. profile.name
		else
			names = profile.name
		end

		export.profiles[profileID .. "Exported"] = profile

		---@param mutationRule MutationProfileRule
		local function validateRules(mutationRule)
			local folder = MutationConfigurationProxy.folders[mutationRule.mutationFolderId]

			if not folder.modId then
				mutationRule.mutationFolderId = mutationRule.mutationFolderId .. "Exported"
				if not export.folders[mutationRule.mutationFolderId] then
					export.folders[mutationRule.mutationFolderId] = {
						name = folder.name,
						description = folder.description,
						mutations = {}
					}
				end

				---@type Mutation
				local mutation = TableUtils:DeeplyCopyTable(folder.modId and folder.mutations[mutationRule.mutationId] or folder.mutations[mutationRule.mutationId]._real)

				export.folders[mutationRule.mutationFolderId].mutations[mutationRule.mutationId] = mutation

				for _, selector in ipairs(mutation.selectors) do
					if type(selector) == "table" then
						---@cast selector Selector
						SelectorInterface:handleDependencies(export, selector)
					end
				end

				for _, mutator in ipairs(mutation.mutators) do
					MutatorInterface:handleDependencies(export, mutator)
				end
			else
				local name, author, version = Helpers:BuildModFields(folder.modId)
				mutationDependencies[folder.modId] = {
					modAuthor = author,
					modName = name,
					modVersion = version,
					modId = folder.modId,
					packagedItems = nil
				} --[[@as ModDependency]]

				mutationRule.sourceMod = mutationDependencies[folder.modId]
			end
		end

		for _, mutationRule in ipairs(profile.mutationRules) do
			validateRules(mutationRule)
		end
		for _, mutationRule in ipairs(profile.prepPhaseMutations or {}) do
			validateRules(mutationRule)
		end
	end

	if forMod then
		names = MutationModProxy.Filename
		FileUtils:SaveStringContentToFile("ExportedProfiles/ExportedModMetaLsxDependencies.lsx", self:BuildMetaDependencyBlock(export, mutationDependencies) or "")
	end

	FileUtils:SaveTableToFile("ExportedProfiles/" .. names .. ".json", {
		["mutations"] = export
	})
end

---@type ExtuiWindow
local window

---@class DependencyFailure
---@field type "Selector"|"Mutator"|"SpellList"|"Folder"
---@field target string?
---@field folderName string?
---@field mutationName string?
---@field packagedItems {string: string}

---@param export {["mutations"]: MutationsConfig}
---@return fun()? import
---@return {[Guid]: ModDependency}? modCache
---@return { [string]: DependencyFailure[] }? failedDependencies
---@return fun()? dependencyWindow
function MutationExternalProfileUtility:importProfile(export)
	local importedMutations = export["mutations"]
	local mutationConfig = ConfigurationStructure.config.mutations

	local modCache, failedDependencies = self:ValidateMutations(mutationConfig)

	local function import()
		for profileId, profile in pairs(importedMutations.profiles) do
			if mutationConfig.profiles[profileId] then
				mutationConfig.profiles[profileId].delete = true
			end

			if TableUtils:IndexOf(mutationConfig.profiles, function(value)
					return value.name == profile.name
				end)
			then
				profile.name = string.format("%s (%s)", profile.name, profileId:sub(1, 3))
			end

			mutationConfig.profiles[profileId] = profile
		end
		for folderId, folder in pairs(importedMutations.folders) do
			if mutationConfig.folders[folderId] then
				mutationConfig.folders[folderId].delete = true
			end

			if TableUtils:IndexOf(mutationConfig.folders, function(value)
					return value.name == folder.name
				end) then
				folder.name = string.format("%s - %s", folder.name, "Imported")
			end

			for _, mutation in pairs(folder.mutations) do
				for _, selector in ipairs(mutation.selectors) do
					if type(selector) == "table" then
						---@cast selector Selector
						SelectorInterface:handleDependencies(importedMutations, selector, true)
					end
				end

				for _, mutator in ipairs(mutation.mutators) do
					MutatorInterface:handleDependencies(importedMutations, mutator, true)
				end
			end

			mutationConfig.folders[folderId] = folder
		end

		if importedMutations.prepPhaseMarkers then
			for categoryId, markerCategory in pairs(importedMutations.prepPhaseMarkers) do
				if mutationConfig.prepPhaseMarkers[categoryId] then
					mutationConfig.prepPhaseMarkers[categoryId].delete = true
				end

				if TableUtils:IndexOf(mutationConfig.prepPhaseMarkers, function(value)
						return value.name == markerCategory.name
					end)
				then
					markerCategory.name = markerCategory.name .. " - Imported"
				end

				mutationConfig.prepPhaseMarkers[categoryId] = markerCategory
			end
		end

		for _, listType in pairs(MutationModProxy.listTypes) do
			if importedMutations[listType] then
				for listId, list in pairs(importedMutations[listType]) do
					if mutationConfig[listType][listId] then
						mutationConfig[listType][listId].delete = true
					end

					if TableUtils:IndexOf(mutationConfig[listType], function(value)
							return value.name == list.name
						end)
					then
						list.name = string.format("%s - %s", list.name, "Imported")
					end

					mutationConfig[listType][listId] = list
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
				return value.type .. (value.folderName or "") .. (value.mutationName or "") .. value.target
			end) do
				header:AddSeparatorText(string.format("%s: %s %s", dep.type, dep.target, dep.folderName and ("|" .. dep.folderName .. "/" .. dep.mutationName) or "")).Font = "Large"

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
