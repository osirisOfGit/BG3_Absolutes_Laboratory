Ext.Vars.RegisterModVariable(ModuleUUID, "ActiveMutationProfile", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true,
	SyncOnWrite = true
})

Ext.Vars.RegisterModVariable(ModuleUUID, "HasDisabledProfiles", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true,
	SyncOnWrite = true
})

MutationProfileExecutor = {}

local mutatedEntities = {}

function MutationProfileExecutor:ExecuteProfile(rerunTransient, ...)
	local specifiedEntities = { ... }
	Logger.mode = "timer"
	Ext.Utils.ProfileBegin("Lab Profile Execution")
	local activeProfile = MutationConfigurationProxy.profiles[Ext.Vars.GetModVariables(ModuleUUID).ActiveMutationProfile]

	---@type ProfileExecutionStatus
	local profileExecutorStatus = {
		stage = "Selecting",
		currentEntity = "N/A",
		totalNumberOfEntities = 0,
		numberOfEntitiesBeingProcessed = 0,
		numberOfEntitiesProcessed = 0,
		profile = activeProfile.name,
		timeElapsed = 0,
	}

	local sendCount = 0
	local executorView = MCM.Get("profile_execution_view")
	local function broadcastStatus()
		if executorView ~= "Off" then
			if sendCount == 3 or profileExecutorStatus.stage == "Complete" or profileExecutorStatus.stage == "Error" then
				Channels.ProfileExecutionStatus:Broadcast(profileExecutorStatus)
				sendCount = 0
			end
			sendCount = sendCount + 1
		end
	end

	local success, error = xpcall(function(...)
		local trackerFile = FileUtils:LoadTableFile(EntityRecorder.trackerFilename)
		if trackerFile and next(trackerFile) then
			Logger:BasicInfo("Recorder is currently running - skipping Mutations")
			return
		end

		if not activeProfile and not Ext.Vars.GetModVariables(ModuleUUID).HasDisabledProfiles then
			local defaultProfile = ConfigurationStructure.config.mutations.settings.defaultProfile
			if defaultProfile then
				Ext.Vars.GetModVariables(ModuleUUID).ActiveMutationProfile = defaultProfile
				activeProfile = MutationConfigurationProxy.profiles[defaultProfile]
				Logger:BasicInfo("Default Profile %s activated", activeProfile.name)
			end
		end

		if activeProfile and next(activeProfile.mutationRules) then
			local time = Ext.Timer:MonotonicTime()

			---@type {[string] : fun()}
			local entitiesToProcess = {}

			---@type {[string] : number}
			local eligible = {}

			local tickCounter = 0
			local entityCounter = 0

			local function checkCompletion()
				if Logger:IsLogLevelEnabled(Logger.PrintTypes.DEBUG) then
					Logger:BasicDebug("%s entities left to process, %s currently eligible", TableUtils:CountElements(entitiesToProcess), TableUtils:CountElements(eligible))
				end

				if not next(entitiesToProcess) then
					Logger:BasicInfo("======= Mutated %s Entities in %dms under Profile %s =======",
						entityCounter,
						(Ext.Timer:MonotonicTime() - time),
						activeProfile.name .. (activeProfile.modId and string.format(" (from mod %s)", Ext.Mod.GetMod(activeProfile.modId).Info.Name) or ""))

					ListConfigurationManager.progressionIndex()

					profileExecutorStatus.stage = "Complete"
					profileExecutorStatus.timeElapsed = (Ext.Timer:MonotonicTime() - time)
					broadcastStatus()
				else
					tickCounter = tickCounter + 1
					for entityId, funct in pairs(entitiesToProcess) do
						---@type EntityHandle
						local entity = Ext.Entity.Get(entityId)
						if entity.Vars.Absolutes_Laboratory_Undone_Components then
							for _, component in ipairs(entity.Vars.Absolutes_Laboratory_Undone_Components) do
								if entity:GetReplicationFlags(component) ~= 0 then
									if Logger:IsLogLevelEnabled(Logger.PrintTypes.TRACE) then
										Logger:BasicTrace("Entity %s's component %s was dirty with flag %d, not eligible for processing yet",
											entityId,
											component,
											tonumber(entity:GetReplicationFlags(component)))
									end

									if eligible[entityId] then
										eligible[entityId] = nil
									end
									goto continue
								end
							end
							if eligible[entityId] and eligible[entityId] >= 2 then
								Logger:BasicDebug("Completed undo for %s after %d ms", EntityRecorder:GetEntityName(entity), tickCounter * 10)
								if profileExecutorStatus.stage ~= "Applying" then
									profileExecutorStatus.numberOfEntitiesProcessed = 0
								end
								profileExecutorStatus.stage = "Applying"
								profileExecutorStatus.timeElapsed = (Ext.Timer:MonotonicTime() - time)
								profileExecutorStatus.currentEntity = EntityRecorder:GetEntityName(entity) ..
									(" (%s)"):format(entity.Uuid.EntityUuid:sub(#entity.Uuid.EntityUuid - 5))
								profileExecutorStatus.numberOfEntitiesProcessed = profileExecutorStatus.numberOfEntitiesProcessed + 1

								broadcastStatus()

								funct()
								eligible[entityId] = nil
								entitiesToProcess[entityId] = nil
							else
								eligible[entityId] = (eligible[entityId] or 0) + 1
							end
						end
						::continue::
					end
					profileExecutorStatus.timeElapsed = (Ext.Timer:MonotonicTime() - time)
					broadcastStatus()
					Ext.Timer.WaitFor(10, checkCompletion)
				end
			end

			-- ---@type thread
			-- local delayedProcessor = coroutine.create(function(...)
			-- 	local counter = 1
			-- 	while counter < #entitiesToProcess do
			-- 		entitiesToProcess[counter]()
			-- 		counter = counter + 1
			-- 		coroutine.yield()
			-- 	end
			-- end)

			---@type {[Guid] : {[Guid]: SelectorPredicate}}
			local cachedSelectors = {}

			local currentLevel = Ext.Entity.Get(Osi.GetHostCharacter()).ServerCharacter.Level

			local loggedIndexes = {}

			for _, entity in pairs(next(specifiedEntities) and specifiedEntities or Ext.Entity.GetAllEntitiesWithComponent("ServerCharacter")) do
				---@cast entity EntityHandle
				local didIncrement = false

				if (Osi.IsDead(entity.Uuid.EntityUuid) == 0 or not entity.DeadByDefault) and not entity.PartyMember and entity.ServerCharacter.Level == currentLevel then
					profileExecutorStatus.totalNumberOfEntities = profileExecutorStatus.totalNumberOfEntities + 1

					mutatedEntities[entity.Uuid.EntityUuid] = true

					---@type MutatorEntityVar
					local entityVar = {
						appliedMutators = {},
						appliedMutatorsPath = {},
						originalValues = {}
					}
					Ext.Utils.ProfileBegin("Lab Profiles - Selecting and Building Pool On " .. EntityRecorder:GetEntityName(entity))
					for i, mProfileRule in TableUtils:OrderedPairs(activeProfile.mutationRules) do
						if not MutationConfigurationProxy.folders[mProfileRule.mutationFolderId] and MutationConfigurationProxy.folders[mProfileRule.mutationFolderId].mutations[mProfileRule.mutationId] then
							if not TableUtils:IndexOf(loggedIndexes, i) then
								Logger:BasicError("Couldn't find Mutation at index %d - folderId: %s | mutationId: %s", i, mProfileRule.mutationFolderId, mProfileRule.mutationId)
								loggedIndexes[#loggedIndexes + 1] = i
								goto continue
							end
						end

						local mutation = MutationConfigurationProxy.folders[mProfileRule.mutationFolderId].mutations[mProfileRule.mutationId]

						if not cachedSelectors[mProfileRule.mutationFolderId] then
							cachedSelectors[mProfileRule.mutationFolderId] = {}
						end
						if not cachedSelectors[mProfileRule.mutationFolderId][mProfileRule.mutationId] then
							cachedSelectors[mProfileRule.mutationFolderId][mProfileRule.mutationId] = SelectorInterface:createComposedPredicate(mutation.selectors)
						end

						if cachedSelectors[mProfileRule.mutationFolderId][mProfileRule.mutationId]:Test(entity, entityVar) then
							if not didIncrement then
								profileExecutorStatus.numberOfEntitiesBeingProcessed = profileExecutorStatus.numberOfEntitiesBeingProcessed + 1
								profileExecutorStatus.numberOfEntitiesProcessed = profileExecutorStatus.numberOfEntitiesProcessed + 1
								didIncrement = true
								profileExecutorStatus.timeElapsed = (Ext.Timer:MonotonicTime() - time)
								profileExecutorStatus.currentEntity = EntityRecorder:GetEntityName(entity) ..
									(" (%s)"):format(entity.Uuid.EntityUuid:sub(#entity.Uuid.EntityUuid - 5))

								broadcastStatus()
							end

							for _, mutator in pairs(mutation.mutators) do
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
								else
									entityVar.appliedMutators[mutator.targetProperty] = mutator
									entityVar.appliedMutatorsPath[mutator.targetProperty] = { [i] = mProfileRule }
								end
							end
						end
						::continue::
					end
					Ext.Utils.ProfileEnd("Lab Profiles - Selecting and Building Pool On " .. EntityRecorder:GetEntityName(entity))

					local didUndo = false
					if entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME] then
						didUndo = true
						Ext.OnNextTick(function(e)
							if profileExecutorStatus.stage ~= "Undoing" then
								profileExecutorStatus.numberOfEntitiesProcessed = 0
							end
							profileExecutorStatus.stage = "Undoing"
							profileExecutorStatus.timeElapsed = (Ext.Timer:MonotonicTime() - time)
							profileExecutorStatus.numberOfEntitiesProcessed = profileExecutorStatus.numberOfEntitiesProcessed + 1
							profileExecutorStatus.currentEntity = EntityRecorder:GetEntityName(entity) .. (" (%s)"):format(entity.Uuid.EntityUuid:sub(#entity.Uuid.EntityUuid - 5))

							broadcastStatus()

							MutatorInterface:undoMutator(entity, entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME], entityVar, rerunTransient)
						end)
					end

					if next(entityVar.appliedMutators) then
						entityCounter = entityCounter + 1
						if didUndo then
							entitiesToProcess[entity.Uuid.EntityUuid] = function()
								MutatorInterface:applyMutator(entity, entityVar)
								entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME] = next(entityVar.appliedMutators) and entityVar or nil
							end
						else
							MutatorInterface:applyMutator(entity, entityVar)
							entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME] = next(entityVar.appliedMutators) and entityVar or nil
						end
					end
				else
					if entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME] then
						MutatorInterface:undoMutator(entity, entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME], rerunTransient)
					end
				end
			end

			Ext.OnNextTick(function(e)
				checkCompletion()
				ListConfigurationManager:buildProgressionIndex()
			end)
		else
			local time = Ext.Timer:MonotonicTime()
			local counter = 0
			for _, entityId in pairs(Ext.Vars.GetEntitiesWithVariable(ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME)) do
				counter = counter + 1
				---@type EntityHandle
				local entity = Ext.Entity.Get(entityId)

				---@type MutatorEntityVar
				local mutatorVar = entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME]

				MutatorInterface:undoMutator(entity, mutatorVar)
			end
			Logger:BasicInfo("======= Cleared Mutations From %s Entities in %dms =======", counter, Ext.Timer:MonotonicTime() - time)
		end
	end, debug.traceback)

	if not success then
		Logger:BasicError("Unrecoverable error happened while executing the Mutation Profile %s: %s",
			activeProfile.name .. (activeProfile.modId and string.format(" (from mod %s)", Ext.Mod.GetMod(activeProfile.modId).Info.Name) or ""),
			error)
		profileExecutorStatus.stage = "Error"
		profileExecutorStatus.error = error
		broadcastStatus()
	end
	Ext.Utils.ProfileEnd("Lab Profile Execution")
	Logger.mode = "buffer"
end

Ext.Osiris.RegisterListener("LevelGameplayReady", 2, "after", function(levelName, isEditorMode)
	if levelName == "SYS_CC_I" then return end

	MutationProfileExecutor:ExecuteProfile()
end)

Ext.Osiris.RegisterListener("EnteredCombat", 2, "before", function(entityId, combatGuid)
	---@type EntityHandle
	local entity = Ext.Entity.Get(entityId)
	if not mutatedEntities[entity.Uuid.EntityUuid] and entity.ServerCharacter and not entity.PartyMember then
		Logger:BasicInfo("%s entered combat %s and hasn't been mutated - executing profile!", entityId, combatGuid)
		MutationProfileExecutor:ExecuteProfile(false, entityId)
	end
end)

Ext.RegisterConsoleCommand("Lab_TraceEntities", function(cmd, ...)
	ECSLogger:ClearLogFile()
	Printer:Start(100, ...)
	MutationProfileExecutor:ExecuteProfile()
end)

Ext.RegisterConsoleCommand("Lab_TestTransient", function(cmd, ...)
	MutationProfileExecutor:ExecuteProfile(true)
end)

Ext.RegisterConsoleCommand("Lab_ClearEntityClasses", function(cmd, ...)
	for _, entity in pairs(Ext.Entity.GetAllEntitiesWithComponent("ServerCharacter")) do
		entity:RemoveComponent("Classes")
		entity:CreateComponent("Classes")
	end
end)
