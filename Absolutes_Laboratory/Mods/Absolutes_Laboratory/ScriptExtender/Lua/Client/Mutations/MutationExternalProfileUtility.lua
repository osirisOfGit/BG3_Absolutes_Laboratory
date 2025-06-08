MutationExternalProfileUtility = {}

---@param profileID Guid
function MutationExternalProfileUtility:exportProfile(profileID)
	local mutationConfig = ConfigurationStructure.config.mutations

	---@type MutationProfile
	local profile = TableUtils:DeeplyCopyTable(mutationConfig.profiles[profileID]._real)

	---@type MutationsConfig
	---@diagnostic disable-next-line: missing-fields
	local export = {
		profiles = {
			[profileID] = profile
		},
		folders = {},
		spellLists = {}
	}

	for _, mutationRule in ipairs(profile.mutationRules) do
		local folder = mutationConfig.folders[mutationRule.mutationFolderId]

		if not export.folders[mutationRule.mutationFolderId] then
			export.folders[mutationRule.mutationFolderId] = {
				name = folder.name,
				description = folder.description,
				mutations = {}
			}
		end

		---@type Mutation
		local mutation = TableUtils:DeeplyCopyTable(folder.mutations[mutationRule.mutationId]._real)

		export.folders[mutationRule.mutationFolderId].mutations[mutationRule.mutationId] = mutation

		for _, selector in ipairs(mutation.selectors) do
			if type(selector) == "table" then
				---@cast selector Selector
				SelectorInterface:enhanceExport(export, selector)
			end
		end

		for _, mutator in ipairs(mutation.mutators) do
			MutatorInterface:enhanceExport(export, mutator)
		end
	end

	FileUtils:SaveTableToFile("ExportedProfiles/" .. profile.name .. ".json", {
		["mutations"] = export
	})
end

---@type ExtuiWindow
local window

---@class DependencyFailure
---@field type "Selector"|"Mutator"
---@field target string
---@field folderName string
---@field mutationName string
---@field packagedItems {string: string}

---@param export {["mutations"]: MutationsConfig}
---@return fun()? import
---@return {[Guid]: ModDependency}? modCache
---@return fun()? dependencyWindow
function MutationExternalProfileUtility:importProfile(export)
	local mutations = export["mutations"]
	local mutationConfig = ConfigurationStructure.config.mutations

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
					if modDependency.modName or not Ext.Template.GetTemplate(next(modDependency.packagedItems)) then
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

							modCache[modId] = modDependency
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

	for _, folder in pairs(mutations.folders) do
		for _, mutation in pairs(folder.mutations) do
			for _, selector in pairs(mutation.selectors) do
				validateSelector(folder.name, mutation.name, selector)
			end

			for _, mutator in pairs(mutation.mutators) do
				if mutator.modDependencies then
					for modId, modDependency in pairs(mutator.modDependencies) do
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
	end

	local function import()
		for profileId, profile in pairs(mutations.profiles) do
			if mutationConfig.profiles[profileId] then
				mutationConfig.profiles[profileId].delete = true
			end
			mutationConfig.profiles[profileId] = profile

			for folderId, folder in pairs(mutations.folders) do
				if mutationConfig.folders[folderId] then
					mutationConfig.folders[folderId].delete = true
				end

				if TableUtils:IndexOf(mutationConfig.folders, function(value)
						return value.name == folder.name
					end) then
					folder.name = string.format("%s - %s", folder.name, "Imported")
				end

				mutationConfig.folders[folderId] = folder
			end

			if mutations.spellLists then
				for spellListId, spellList in pairs(mutations.spellLists) do
					if mutationConfig.spellLists[spellListId] then
						mutationConfig.spellLists[spellListId].delete = true
					end

					if TableUtils:IndexOf(mutationConfig.spellLists, function(value)
							return value.name == spellList.name
						end) then
						spellList.name = string.format("%s - %s", spellList.name, "Imported")
					end

					mutationConfig.spellLists[spellListId] = spellList
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
				return value.type .. value.folderName .. value.mutationName .. value.target
			end) do
				local depTable = header:AddTable("headers" .. dep.folderName .. dep.mutationName, 5)
				local headerRow = depTable:AddRow()
				headerRow.Headers = true
				headerRow:AddCell():AddText("Type")
				headerRow:AddCell():AddText("Target")
				headerRow:AddCell():AddText("Folder Name")
				headerRow:AddCell():AddText("Mutation Name")

				local row = depTable:AddRow()
				row:AddCell():AddText(dep.type)
				row:AddCell():AddText(dep.target)
				row:AddCell():AddText(dep.folderName)
				row:AddCell():AddText(dep.mutationName)

				header:AddSeparatorText("Missing Items"):SetStyle("SeparatorTextAlign", 0.2)

				for id, name in pairs(dep.packagedItems) do
					header:AddText("%s (%s)", name, id)
				end
				header:AddNewLine()
			end
		end
	end

	if next(failedDependencies) then
		return import, modCache, buildDepWindow
	else
		import()
	end
end
