ExecutorDiagramGenerator = {}

function ExecutorDiagramGenerator:GenerateDiagram(entityId)
	---@type EntityHandle
	local entity = Ext.Entity.Get(entityId)

	if not entity or not (Osi.IsDead(entity.Uuid.EntityUuid) == 0 or entity.DeadByDefault) and not entity.PartyMember then
		if entity then
			local criteria = {
				exists = entity ~= nil,
				["not a party member"] = entity.PartyMember == nil,
				["is alive or is 'fake' dead"] = (Osi.IsDead(entity.Uuid.EntityUuid) == 0 or entity.DeadByDefault)
			}
			Logger:BasicError("Entity is not eligible for execution processing! \n%s", criteria)
		else
			Logger:BasicError("Entity does not exist!")
		end
		return
	end

	local activeProfile = MutationConfigurationProxy.profiles[Ext.Vars.GetModVariables(ModuleUUID).ActiveMutationProfile]

	if not activeProfile and not Ext.Vars.GetModVariables(ModuleUUID).HasDisabledProfiles then
		local defaultProfile = ConfigurationStructure.config.mutations.settings.defaultProfile
		if defaultProfile then
			Ext.Vars.GetModVariables(ModuleUUID).ActiveMutationProfile = defaultProfile
			activeProfile = MutationConfigurationProxy.profiles[defaultProfile]
			Logger:BasicInfo("Default Profile %s activated", activeProfile.name)
		end
	end

	Logger:BasicInfo("Running entity %s against profile %s", EntityRecorder:GetEntityName(entity), activeProfile.name)

	local diagramResult = ([[
ENTER THE BELOW INTO https://www.mermaidchart.com/play (Hit Edit code in the bottom left)
Delete the [direction LR] line if you want top-down
=====================================================
---
config:
  theme: dark
---
stateDiagram-v2
    direction LR
	%%%% Node categories
	classDef entityNode fill:#0b3d91,stroke:#8fb3ff,stroke-width:2px,color:#ffffff;

	%%%% Mutator types
	classDef PassiveList fill:#123c3c,stroke:#5bd9d4,stroke-width:2px,color:#eaffff;
	classDef SpellList fill:#341234,stroke:#d85ad8,stroke-width:2px,color:#ffebff;
	classDef StatusList fill:#2a163e,stroke:#b487ff,stroke-width:2px,color:#f3eaff;
	classDef Boosts fill:#3e2a14,stroke:#f0aa4a,stroke-width:2px,color:#fff5e6;
	classDef ActionResources fill:#0f2740,stroke:#6fb6ff,stroke-width:2px,color:#eaf4ff;
	classDef Abilities fill:#133a22,stroke:#69d969,stroke-width:2px,color:#eaffea;
	classDef Health fill:#3a1414,stroke:#ff6e6e,stroke-width:2px,color:#ffeaea;
	classDef ClassesAndSubclasses fill:#24163a,stroke:#a880ff,stroke-width:2px,color:#f3eaff;
	classDef CharacterLevel fill:#1c2e4a,stroke:#7ab0ff,stroke-width:2px,color:#eaf2ff;
	classDef Progressions fill:#2a233e,stroke:#8f8cff,stroke-width:2px,color:#f0efff;

	%%%% Edge styles
	classDef edgeAdditive stroke:#4cd137,color:#b8ffcc,stroke-width:2px;
	classDef edgeOverwrite stroke:#e84118,color:#ffd6d1,stroke-dasharray: 5 3,stroke-width:2px;

	%%%% State (node) styling helpers
	classDef compact font-size:10px;
	classDef headerBold font-weight:700;
	
	note: %s
	note: Template - %s
	note: Stat - %s
	note: Id - %s
]]):format(EntityRecorder:GetEntityName(entity), entity.ServerCharacter.Template.Name, entity.Data.StatsId, entity.Uuid.EntityUuid)

	---@type MutatorEntityVar
	local entityVar = {
		appliedMutators = {},
		appliedMutatorsPath = {},
		originalValues = {}
	}

	---@type {[string] : string[]}
	local stateTracker = {}

	local stylingBlock = [[
class Entity entityNode]]

	for i, mProfileRule in TableUtils:OrderedPairs(activeProfile.mutationRules) do
		local mutation = MutationConfigurationProxy.folders[mProfileRule.mutationFolderId].mutations[mProfileRule.mutationId]
		local fullName = ("Rule %d - %s/%s"):format(i, MutationConfigurationProxy.folders[mProfileRule.mutationFolderId].name:gsub(":", ""), mutation.name:gsub(":", ""))
		local stateName = "mutation" .. i

		local ruleEntry = ([[
		
	%s: %s
	state %s {
]]):format(stateName, fullName, stateName, stateName)

		local overridenTextBlock = ""
		if SelectorInterface:createComposedPredicate(mutation.selectors):Test(entity, entityVar) then
			for _, mutator in pairs(mutation.mutators) do
				local noSpaceName = mutator.targetProperty:gsub("%s", "")
				local mutatorName = stateName .. "mutator" .. noSpaceName
				ruleEntry = ruleEntry .. ("\t\t%s: %s\n"):format(mutatorName, mutator.targetProperty)

				if entityVar.appliedMutators[mutator.targetProperty]
					and mProfileRule.additive
					and MutatorInterface.registeredMutators[mutator.targetProperty]:canBeAdditive(mutator, entityVar.appliedMutators[mutator.targetProperty])
				then
					if entityVar.appliedMutators[mutator.targetProperty][1] then
						table.insert(entityVar.appliedMutators[mutator.targetProperty], mutator)
					else
						entityVar.appliedMutators[mutator.targetProperty] = { entityVar.appliedMutators[mutator.targetProperty], mutator }
					end

					entityVar.appliedMutatorsPath[mutator.targetProperty][i] = mProfileRule

					local additiveWith
					for existingMutation, existingMutators in TableUtils:OrderedPairs(stateTracker) do
						local index = TableUtils:IndexOf(existingMutators, function(value)
							return value:find(noSpaceName) ~= nil
						end)
						if index then
							additiveWith = existingMutation .. "mutator" .. noSpaceName
						end
					end
					if additiveWith then
						overridenTextBlock = overridenTextBlock .. ([[
	%s --> %s: Composes With
]]):format(additiveWith, mutatorName)
					end
				else
					local overrides
					for existingMutation, existingMutators in TableUtils:OrderedPairs(stateTracker) do
						local index = TableUtils:IndexOf(existingMutators, function(value)
							return value:find(noSpaceName) ~= nil
						end)
						if index then
							overrides = existingMutation .. "mutator" .. noSpaceName

							existingMutators[index] = nil
						end
					end
					if overrides then
						overridenTextBlock = overridenTextBlock .. ([[
%s --> %s: Overwritten By
]]):format(overrides, mutatorName)
					end

					entityVar.appliedMutators[mutator.targetProperty] = mutator
					entityVar.appliedMutatorsPath[mutator.targetProperty] = { [i] = mProfileRule }
				end
				stateTracker[stateName] = stateTracker[stateName] or {}
				table.insert(stateTracker[stateName], mutatorName)

				stylingBlock = stylingBlock .. ("\n\tclass %s %s"):format(mutatorName, noSpaceName)
			end
			diagramResult = diagramResult .. ruleEntry .. "\t}\n" .. overridenTextBlock .. "\n"
		end
	end

	diagramResult = diagramResult .. "\t" .. stylingBlock

	local fileName = "DiagramOutputs/" .. EntityRecorder:GetEntityName(entity) .. " - " .. entity.Uuid.EntityUuid:sub(#entity.Uuid.EntityUuid - 5) .. ".txt"
	FileUtils:SaveStringContentToFile(fileName, diagramResult)
	Logger:BasicInfo("Generated diagram to %%localappdata%%/Larian Studios/Baldur's Gate 3/Script Extender/Absolutes_Laboratory/%s", fileName)

	return diagramResult
end

Ext.RegisterConsoleCommand("Lab_GenerateMutationDiagram", function(cmd, ...)
	if #{ ... } > 1 then
		Logger:BasicError("Only enter 1 EntityId!")
		return
	end
	local entityId = ...
	local success, error = xpcall(function()
		ExecutorDiagramGenerator:GenerateDiagram(entityId)
	end, debug.traceback)

	if not success then
		Logger:BasicError("Could not fully generate diagram due to error: %s", error)
	end
end)

Channels.GenerateMutationDiagram:SetRequestHandler(function(data, user)
	local success, error = xpcall(function()
		return ExecutorDiagramGenerator:GenerateDiagram(data)
	end, debug.traceback)

	if not success then
		Logger:BasicError("Could not fully generate diagram due to error: %s", error)
		return {
			error = error
		}
	else
		return {
			result = error
		}
	end
end)
