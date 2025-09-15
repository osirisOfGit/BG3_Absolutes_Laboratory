LevelMutator = MutatorInterface:new("Character Level")

function LevelMutator:priority()
	return self:recordPriority(1)
end

function LevelMutator:handleDependencies()
	-- NOOP
end

function LevelMutator:Transient()
	return false -- Dunno how, but it's not /shrug
end

---@class LevelRandomModifier
---@field offsetBase number?
---@field minimumBelow number?
---@field maximumAbove number?

---@class LevelModifier
---@field base LevelRandomModifier?
---@field xpReward {[string]: LevelRandomModifier}?

---@class LevelThresholdRequirement
---@field comparator ">"|">="|"<"|"<="
---@field level number
---@field relativeToPlayer boolean

---@class LevelMutator : Mutator
---@field levelThreshold LevelThresholdRequirement
---@field usePlayerLevel boolean
---@field values number
---@field modifiers LevelModifier

---@param mutator LevelMutator
function LevelMutator:renderMutator(parent, mutator)
	mutator.values = mutator.values or 0
	mutator.usePlayerLevel = mutator.usePlayerLevel or (mutator.usePlayerLevel == nil and false) or mutator.usePlayerLevel
	mutator.levelThreshold = mutator.levelThreshold or {
		comparator = ">=",
		level = 1,
		relativeToPlayer = false
	} --[[@as LevelThresholdRequirement]]

	Helpers:KillChildren(parent)

	parent:AddText("Entity's level must be ")
	local comparatorCombo = parent:AddCombo("")
	comparatorCombo.SameLine = true
	comparatorCombo.WidthFitPreview = true
	comparatorCombo.Options = { ">", ">=", "<", "<=" }
	comparatorCombo.SelectedIndex = TableUtils:IndexOf(comparatorCombo.Options, mutator.levelThreshold.comparator) - 1
	comparatorCombo.OnChange = function()
		mutator.levelThreshold.comparator = comparatorCombo.Options[comparatorCombo.SelectedIndex + 1]
	end

	local levelThresholdInput = parent:AddInputInt("", mutator.levelThreshold.level)
	levelThresholdInput.SameLine = true
	levelThresholdInput.ItemWidth = 40
	levelThresholdInput.OnChange = function()
		if levelThresholdInput.Value[1] >= 1 or mutator.levelThreshold.relativeToPlayer then
			mutator.levelThreshold.level = levelThresholdInput.Value[1]
		else
			levelThresholdInput.Value = { mutator.levelThreshold.level, mutator.levelThreshold.level, mutator.levelThreshold.level, mutator.levelThreshold.level }
		end
	end

	Styler:EnableToggleButton(parent, "relative to the highest-leveled player", true, function(swap)
		if swap then
			mutator.levelThreshold.relativeToPlayer = not mutator.levelThreshold.relativeToPlayer
			if not mutator.levelThreshold.relativeToPlayer and mutator.levelThreshold.level < 1 then
				mutator.levelThreshold.level = 1
				levelThresholdInput.Value = { 1, 1, 1, 1 }
			end
		end
		return mutator.levelThreshold.relativeToPlayer
	end)

	local thresholdText = parent:AddText("for this mutator to execute (?)")
	thresholdText.SameLine = true
	thresholdText:Tooltip():AddText(
		"\t Value can be negative only when the threshold is relative to the player to represent a comparison of (the player's level - value) vs the entity level;\notherwise, it represents the flat number to compare the entity's level against")

	parent:AddSeparator()

	parent:AddText("Entity should be ")

	local baseInput = parent:AddInputInt("", mutator.values)
	baseInput.SameLine = true
	baseInput.ItemWidth = 40

	local text = parent:AddText(" level(s) above/below ( ? )")
	text.SameLine = true
	text:Tooltip():AddText(
		"\t Value can be negative to reduce the entity level - 0 will set the entity to the player's level or the entity's current level, depending on the chosen option")

	Styler:DualToggleButton(parent, " the highest-leveled player", " its current level", true, function(swap)
		if swap then
			mutator.usePlayerLevel = not mutator.usePlayerLevel
		end
		return mutator.usePlayerLevel
	end)

	baseInput.OnChange = function()
		mutator.values = baseInput.Value[1]
	end

	mutator.modifiers = mutator.modifiers or {}

	self:renderModifiers(parent:AddGroup("Modifiers"), mutator.modifiers)
end

---@param modifiers LevelModifier
function LevelMutator:renderModifiers(parent, modifiers)
	Helpers:KillChildren(parent)

	parent:AddText("Level can be randomly set to: ( ? )"):Tooltip():AddText(
		"\t If both of the below are set to 0, affected entities will just have the value defined above used - otherwise, that value will be randomly +/- by the defined amounts")

	local baseMinInput = parent:AddInputInt("below base", modifiers.base and modifiers.base.minimumBelow or 0)
	baseMinInput.ItemWidth = 40
	baseMinInput.OnChange = function()
		if baseMinInput.Value[1] < 0 then
			baseMinInput.Value = { 0, 0, 0, 0 }
		end
		if baseMinInput.Value[1] == 0 and modifiers.base then
			modifiers.base.minimumBelow = nil
			if not modifiers.base.minimumBelow and not modifiers.base.maximumAbove then
				modifiers.base.delete = true
			end
		else
			modifiers.base = modifiers.base or {}
			modifiers.base.minimumBelow = baseMinInput.Value[1]
		end
	end

	local baseMaxInput = parent:AddInputInt("above base", modifiers.base and modifiers.base.maximumAbove or 0)
	baseMaxInput.ItemWidth = 40
	baseMaxInput.OnChange = function()
		if baseMaxInput.Value[1] < 0 then
			baseMaxInput.Value = { 0, 0, 0, 0 }
		end
		if baseMaxInput.Value[1] == 0 and modifiers.base then
			modifiers.base.maximumAbove = nil
			if not modifiers.base.minimumBelow and not modifiers.base.maximumAbove then
				modifiers.base.delete = true
			end
		else
			modifiers.base = modifiers.base or {}
			modifiers.base.maximumAbove = baseMaxInput.Value[1]
		end
	end

	local xpRewardHeader = parent:AddCollapsingHeader("By XPReward")

	local xpLevelTable = xpRewardHeader:AddTable("xpRewardModifierCustomizer", 4)
	local xpHeaders = xpLevelTable:AddRow()
	xpHeaders.Headers = true
	xpHeaders:AddCell():AddText("XPReward ( ? )"):Tooltip():AddText([[
	Set the XPReward Categories at which the modifier(s) change - for example, setting the base offset to 4 for Elites when the overall base is 2
means all Pack/Combatant NPCs will be 2 levels above the highest-leveled party member and 6 levels above for elites and above
Setting the min/max offset will offset the overall min/max in the same way
]])
	xpHeaders:AddCell():AddText("Base Offset ( ? )"):Tooltip():AddText("\t Offsets the base value set above - use a negative value to reduce it")
	xpHeaders:AddCell():AddText("Min Offset For Random")
	xpHeaders:AddCell():AddText("Max Offset For Random")

	for _, xpReward in ipairs(Ext.StaticData.GetAll("ExperienceReward")) do
		---@type ResourceExperienceRewards
		local xpRewardResource = Ext.StaticData.Get(xpReward, "ExperienceReward")
		if xpRewardResource.LevelSource > 0 then
			local row = xpLevelTable:AddRow()
			local levelCell = row:AddCell()

			Styler:HyperlinkText(levelCell, xpRewardResource.Name, function(parent)
				ResourceManager:RenderDisplayWindow(xpRewardResource, parent)
			end)

			local modInput = row:AddCell():AddInputInt("##base" .. xpReward, modifiers.xpReward and modifiers.xpReward[xpReward] and modifiers.xpReward[xpReward].offsetBase)
			modInput.ItemWidth = 40
			modInput.ParseEmptyRefVal = true
			modInput.DisplayEmptyRefVal = true
			modInput.OnChange = function()
				modifiers.xpReward = modifiers.xpReward or {}
				modifiers.xpReward[xpReward] = modifiers.xpReward[xpReward] or {}
				modifiers.xpReward[xpReward].offsetBase = modInput.Value[1] ~= 0 and modInput.Value[1] or nil
				if not modifiers.xpReward[xpReward]() then
					modifiers.xpReward[xpReward].delete = true
					if not modifiers.xpReward() then
						modifiers.xpReward.delete = true
					end
				end
			end

			local modMinInput = row:AddCell():AddInputInt("##min" .. xpReward, modifiers.xpReward and modifiers.xpReward[xpReward] and modifiers.xpReward[xpReward].minimumBelow)
			modMinInput.ItemWidth = 40
			modMinInput.ParseEmptyRefVal = true
			modMinInput.DisplayEmptyRefVal = true

			modMinInput.OnDeactivate = function()
				modifiers.xpReward = modifiers.xpReward or {}
				modifiers.xpReward[xpReward] = modifiers.xpReward[xpReward] or {}
				modifiers.xpReward[xpReward].minimumBelow = modMinInput.Value[1] ~= 0 and modMinInput.Value[1] or nil
				if not modifiers.xpReward[xpReward]() then
					modifiers.xpReward[xpReward].delete = true
					if not modifiers.xpReward() then
						modifiers.xpReward.delete = true
					end
				end
			end

			local modMaxInput = row:AddCell():AddInputInt("##max" .. xpReward, modifiers.xpReward and modifiers.xpReward[xpReward] and modifiers.xpReward[xpReward].maximumAbove)
			modMaxInput.ItemWidth = 40
			modMaxInput.ParseEmptyRefVal = true
			modMaxInput.DisplayEmptyRefVal = true

			modMaxInput.OnDeactivate = function()
				modifiers.xpReward = modifiers.xpReward or {}
				modifiers.xpReward[xpReward] = modifiers.xpReward[xpReward] or {}

				modifiers.xpReward[xpReward].maximumAbove = modMaxInput.Value[1] ~= 0 and modMaxInput.Value[1] or nil
				if not modifiers.xpReward[xpReward]() then
					modifiers.xpReward[xpReward].delete = true
					if not modifiers.xpReward() then
						modifiers.xpReward.delete = true
					end
				end
			end
		end
	end
end

function LevelMutator:undoMutator(entity, entityVar)
	Logger:BasicDebug("Reset to %s", entityVar.originalValues[self.name])
	entity.AvailableLevel.Level = entityVar.originalValues[self.name]
	entity.EocLevel.Level = entity.AvailableLevel.Level
end

local xpRewardList = {}

---@param mutatorModifier {[string]: LevelRandomModifier}
---@param xpRewardId string
---@return LevelRandomModifier?
local function calculateXPRewardLevelModifier(mutatorModifier, xpRewardId)
	if not next(xpRewardList) then
		for _, xpReward in ipairs(Ext.StaticData.GetAll("ExperienceReward")) do
			---@type ResourceExperienceRewards
			local xpRewardResource = Ext.StaticData.Get(xpReward, "ExperienceReward")
			if xpRewardResource.LevelSource > 0 then
				table.insert(xpRewardList, xpReward)
			end
		end
	end

	local xMod = mutatorModifier[xpRewardId]
	if not xMod and TableUtils:IndexOf(xpRewardList, xpRewardId) then
		for i = TableUtils:IndexOf(xpRewardList, xpRewardId) - 1, 0, -1 do
			xMod = mutatorModifier[xpRewardList[i]]
			if xMod then
				break
			end
		end
	end

	return xMod
end

local levelUpSubscription

function LevelMutator:applyMutator(entity, entityVar)
	local function calculateHighestPlayerLevel()
		local targetLevel = 1
		for _, playerTable in pairs(Osi.DB_Players:Get(nil)) do
			local player = playerTable[1]

			---@type EntityHandle
			local playerEntity = Ext.Entity.Get(player)

			if playerEntity.AvailableLevel.Level > targetLevel then
				targetLevel = playerEntity.AvailableLevel.Level
			end
		end
		return targetLevel
	end
	entityVar.originalValues[self.name] = entity.AvailableLevel.Level

	---@type LevelMutator
	local mutator = entityVar.appliedMutators[self.name]

	local levelThreshold = mutator.levelThreshold
	local targetLevel = levelThreshold.relativeToPlayer and (calculateHighestPlayerLevel() + levelThreshold.level) or levelThreshold.level

	local entityPasses = false
	if levelThreshold.comparator == ">" then
		entityPasses = entity.EocLevel.Level > targetLevel
	elseif levelThreshold.comparator == ">=" then
		entityPasses = entity.EocLevel.Level >= targetLevel
	elseif levelThreshold.comparator == "<" then
		entityPasses = entity.EocLevel.Level < targetLevel
	elseif levelThreshold.comparator == "<=" then
		entityPasses = entity.EocLevel.Level <= targetLevel
	end

	if not entityPasses then
		Logger:BasicDebug("Entity's level of %s is NOT %s the target level of %s%s", entity.EocLevel.Level, levelThreshold.comparator, targetLevel,
			levelThreshold.relativeToPlayer and " (calculated relative to the player's level)" or "")
		return
	else
		Logger:BasicDebug("Entity's level of %s is %s the target level of %s%s", entity.EocLevel.Level, levelThreshold.comparator, targetLevel,
			levelThreshold.relativeToPlayer and " (calculated relative to the player's level)" or "")
	end

	---@type Character
	local charStat = Ext.Stats.Get(entity.Data.StatsId)

	local baseLevel = mutator.values
	local minBelow = mutator.modifiers.base and mutator.modifiers.base.minimumBelow or 0
	local maxAbove = mutator.modifiers.base and mutator.modifiers.base.maximumAbove or 0

	if charStat.XPReward and mutator.modifiers.xpReward then
		---@type LevelRandomModifier?
		local xPRewardMod
		xPRewardMod = calculateXPRewardLevelModifier(mutator.modifiers.xpReward, charStat.XPReward)
		if xPRewardMod then
			baseLevel = baseLevel + (xPRewardMod.offsetBase or 0)
			minBelow = baseLevel + (xPRewardMod.minimumBelow or 0)
			maxAbove = baseLevel + (xPRewardMod.maximumAbove or 0)
		end
		if Logger:IsLogLevelEnabled(Logger.PrintTypes.DEBUG) then
			Logger:BasicDebug("XPReward is %s, resulting modifier is %s", charStat.XPReward, xPRewardMod or "[Appropriate Modifier Not Found]")
		end
	end

	Logger:BasicDebug("Base level above the %s level is %s (post XPReward calculation)", mutator.usePlayerLevel and "player" or "entity", baseLevel)

	local useMin
	if minBelow ~= 0 and maxAbove ~= 0 then
		useMin = math.random(0, 1) == 0
	elseif minBelow ~= 0 then
		useMin = true
	elseif maxAbove ~= 0 then
		useMin = false
	end

	if useMin ~= nil then
		if useMin then
			Logger:BasicDebug("Subtracting a random value between 0 and %s from the base value %s", minBelow, baseLevel)
			baseLevel = baseLevel - (math.random(0, minBelow))
		else
			Logger:BasicDebug("Adding a random value between 0 and %s to the base value %s", maxAbove, baseLevel)
			baseLevel = baseLevel + (math.random(0, maxAbove))
		end
	end

	local targetLevel = mutator.usePlayerLevel and 1 or entity.EocLevel.Level
	if mutator.usePlayerLevel then
		targetLevel = calculateHighestPlayerLevel()
		Logger:BasicDebug("Highest player level is %s", targetLevel)
	else
		Logger:BasicDebug("Current entity level is %s", targetLevel)
	end

	if not levelUpSubscription and mutator.usePlayerLevel then
		---@diagnostic disable-next-line: param-type-mismatch
		levelUpSubscription = Ext.Entity.OnChange("AvailableLevel", function()
			Logger:BasicInfo("A levelup mutator is registered and a player just gained enough XP to level up - rerunning mutations")
			MutationProfileExecutor:ExecuteProfile(true)
		end, Ext.Entity.Get(Osi.GetHostCharacter()))
	end

	baseLevel = (Ext.Math.Sign(baseLevel) == -1 and baseLevel < targetLevel) and targetLevel or baseLevel

	entity.AvailableLevel.Level = targetLevel + baseLevel
	entity.EocLevel.Level = entity.AvailableLevel.Level
	Logger:BasicDebug("Changed level from %s to %s", entityVar.originalValues[self.name], entity.AvailableLevel.Level)
end

function LevelMutator:FinalizeMutator(entity)
	entity:Replicate("AvailableLevel")
	entity:Replicate("EocLevel")
end
