MonsterLabExportImport = {}

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

					for _, ruleset in pairs(mlEntity.rulesetModifiers) do
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
		FileUtils:SaveStringContentToFile("ExportedProfiles/ExportedMonsterLabModMetaLsxDependencies.lsx", self:BuildMetaDependencyBlock(export, dependencies) or "")
	end

	FileUtils:SaveTableToFile("ExportedProfiles/" .. names .. ".json", {
		["monsterLab"] = export
	})
end
