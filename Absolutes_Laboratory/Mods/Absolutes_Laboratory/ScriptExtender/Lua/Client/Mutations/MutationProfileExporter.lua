MutationProfileExporter = {}

---@param profileID Guid
function MutationProfileExporter:exportProfile(profileID)
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
