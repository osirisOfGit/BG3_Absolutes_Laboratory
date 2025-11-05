---@class LevelMutatorClass : MutatorInterface
LevelMutator = MutatorInterface:new("Character Level")
LevelMutator.affectedComponents = {
	"BoostsContainer"
}

function LevelMutator:priority()
	return self:recordPriority(1)
end

function LevelMutator:canBeAdditive()
	return true
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
---@field offsetBasePerPartyMember number?
---@field basePartySize number

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

	Styler:EnableToggleButton(parent, "relative to the highest-leveled player", true, nil, function(swap)
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

	parent:AddSeparator()

	modifiers.offsetBasePerPartyMember = modifiers.offsetBasePerPartyMember or 0
	modifiers.basePartySize = modifiers.basePartySize or 1

	parent:AddText("When the Party Size is more than ")
	local basePartySize = parent:AddInputInt("", modifiers.basePartySize)
	basePartySize.SameLine = true
	basePartySize.ItemWidth = 30
	basePartySize.OnChange = function()
		if basePartySize.Value[1] < 1 then
			basePartySize.Value = { 1, 1, 1, 1 }
		end
		modifiers.basePartySize = basePartySize.Value[1]
	end

	local secondText = parent:AddText(", for each party member + follower, increase base value by (?)")
	secondText.SameLine = true
	secondText:Tooltip():AddText(
		"\t Excludes Summons; this accounts for the mod Sit This One Out 2, so any party members that won't join combat are excluded from the calculation.\nIf the active party size is less than the specified base size, the specified base offset will be subtracted from the base, instead of added to.")
	local partyMemberIncreaseInput = parent:AddInputInt("", modifiers.offsetBasePerPartyMember)
	partyMemberIncreaseInput.SameLine = true
	partyMemberIncreaseInput.ItemWidth = 30
	partyMemberIncreaseInput.OnChange = function()
		modifiers.offsetBasePerPartyMember = partyMemberIncreaseInput.Value[1]
	end

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

if Ext.IsServer() then
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
		local levelMutators = entityVar.appliedMutators[self.name]
		if not levelMutators[1] then
			levelMutators = { levelMutators }
		end
		---@cast levelMutators LevelMutator[]

		local function calculateHighestPlayerLevel()
			local targetLevel = 1
			for _, playerTable in pairs(Osi.DB_Players:Get(nil)) do
				local player = playerTable[1]

				---@type EntityHandle
				local playerEntity = Ext.Entity.Get(player)

				if playerEntity.EocLevel.Level > targetLevel then
					targetLevel = playerEntity.EocLevel.Level
				end
			end
			return targetLevel
		end

		for l = #levelMutators, 1, -1 do
			local mutator = levelMutators[l]

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
				Logger:BasicDebug("Entity's level of %s is NOT %s the target level of %s%s - checking next mutator", entity.EocLevel.Level, levelThreshold.comparator, targetLevel,
					levelThreshold.relativeToPlayer and " (calculated relative to the player's level)" or "")
			else
				entityVar.originalValues[self.name] = entity.EocLevel.Level

				Logger:BasicDebug("Entity's level of %s is %s the target level of %s%s", entity.EocLevel.Level, levelThreshold.comparator, targetLevel,
					levelThreshold.relativeToPlayer and " (calculated relative to the player's level)" or "")

				---@type Character
				local charStat = Ext.Stats.Get(entity.Data.StatsId)

				local baseLevel = mutator.values

				local offsetBasePerPartyMember = mutator.modifiers.offsetBasePerPartyMember
				if offsetBasePerPartyMember and offsetBasePerPartyMember > 0 then
					mutator.modifiers.basePartySize = mutator.modifiers.basePartySize or 1

					self:RegisterListeners()
					local amountOfPartyMembers = 0
					for _, playerDB in TableUtils:CombinedPairs(Osi.DB_PartyFollowers:Get(nil), Osi.DB_Players:Get(nil)) do
						local player = playerDB[1]
						if (Osi.HasActiveStatus(player, "SITOUT_ONCOMBATSTART_APPLIER_TECHNICAL") == 0
								and Osi.HasActiveStatus(player, "SITOUT_HUSH_STATUS") == 0
								and Osi.HasActiveStatus(player, "SITOUT_VANISH_STATUS_APPLIER") == 0)
							or Osi.HasActiveStatus(player, "SITOUT_ALWAYS_FIGHT_STATUS") == 1
						then
							amountOfPartyMembers = amountOfPartyMembers + 1
						else
							Logger:BasicTrace("Party Member %s has a SitOut status - excluding", player)
						end
					end
					amountOfPartyMembers = amountOfPartyMembers - mutator.modifiers.basePartySize

					if amountOfPartyMembers ~= 0 then
						if amountOfPartyMembers < 0 then
							offsetBasePerPartyMember = offsetBasePerPartyMember
						end

						Logger:BasicDebug(
							"There are %d active, non-sitout party members (excluding host's starting character), compared to the base party size of %d, adding %d to the base level",
							amountOfPartyMembers,
							mutator.modifiers.basePartySize,
							amountOfPartyMembers * offsetBasePerPartyMember)

						baseLevel = baseLevel + (math.abs(amountOfPartyMembers) * offsetBasePerPartyMember)
					end
				end

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

				Logger:BasicDebug("Base level above the %s level is %s (post XPReward + PartyMember calculation)", mutator.usePlayerLevel and "player" or "entity", baseLevel)

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
					levelUpSubscription = Ext.Entity.OnChange("EocLevel", function()
						Logger:BasicInfo("A levelup mutator is registered and a player just gained enough XP to level up - rerunning mutations")
						MutationProfileExecutor:ExecuteProfile(true)
					end, Ext.Entity.Get(Osi.GetHostCharacter()))
				end

				entity.AvailableLevel.Level = math.max(1, targetLevel + baseLevel)
				entity.EocLevel.Level = entity.AvailableLevel.Level
				Logger:BasicDebug("Changed level from %s to %s", entityVar.originalValues[self.name], entity.AvailableLevel.Level)

				break
			end
		end

		if not entityVar.originalValues[self.name] then
			Logger:BasicDebug("No level mutators applied")
		end
	end

	function LevelMutator:FinalizeMutator(entity)
		entity:Replicate("AvailableLevel")
		entity:Replicate("EocLevel")
	end

	local isInCamp = false
	local changedPartyMembers = false
	local isRegistered = false
	function LevelMutator:RegisterListeners()
		if not isRegistered then
			isRegistered = true
			Ext.Osiris.RegisterListener("TeleportedToCamp", 1, "after", function(character)
				if Osi.IsInPartyWith(character, Osi.GetHostCharacter()) == 1 then
					isInCamp = true
				end
			end)

			Ext.Osiris.RegisterListener("LongRestStarted", 0, "after", function()
				isInCamp = true
			end)

			Ext.Osiris.RegisterListener("TeleportedFromCamp", 1, "after", function(character)
				isInCamp = false
				if changedPartyMembers then
					Logger:BasicDebug("Party members changed and the player just left camp, rerunning profile")
					MutationProfileExecutor:ExecuteProfile(true)
					changedPartyMembers = false
				end
			end)

			Ext.Osiris.RegisterListener("CharacterLeftParty", 1, "after", function(character)
				if (Osi.IsSummon(character) == 0) then
					if not isInCamp then
						Logger:BasicDebug("Character %s (%s) left the party, rerunning profile", EntityRecorder:GetEntityName(Ext.Entity.Get(character)), character)
						MutationProfileExecutor:ExecuteProfile(true)
					else
						changedPartyMembers = true
					end
				end
			end)

			Ext.Osiris.RegisterListener("CharacterJoinedParty", 1, "after", function(character)
				if (Osi.IsPartyFollower(character) == 1 or Osi.IsPlayer(character) == 1) then
					if not isInCamp then
						Logger:BasicDebug("Character %s (%s) joined the party, rerunning profile", EntityRecorder:GetEntityName(Ext.Entity.Get(character)), character)
						MutationProfileExecutor:ExecuteProfile(true)
					else
						changedPartyMembers = true
					end
				end
			end)
		end
	end
end

---@return MazzleDocsDocumentation
function LevelMutator:generateDocs()
	return {
		{
			Topic = self.Topic,
			SubTopic = self.SubTopic,
			content = {
				{
					type = "Heading",
					text = "Character Level",
				},
				{
					type = "Separator"
				},
				{
					type = "CallOut",
					prefix = "",
					prefix_color = "Yellow",
					text = [[
Dependency On: None
Transient: No
Composable: Yes]]
				} --[[@as MazzleDocsCallOut]],
				{
					type = "Separator"
				},
				{
					type = "SubHeading",
					text = "Summary"
				},
				{
					type = "Content",
					text = [[
This mutator serves as an important dependency for almost every other mutator - it allows creating both a living world that grows alongside the player and a tailored one that provides a specific experience, separately or at the same time.

The 'Entity' mentioned throughout refers strictly to the Entity being mutated - the player's level is only relevant where specifically called out.]]
				},
				{
					type = "Separator"
				},
				{
					type = "SubHeading",
					text = "Client-Side Content"
				},
				{
					type = "Content",
					text = [[
The mutator is laid out as follows:

Level Threshold - this represents a condition on the Mutator, separate from the selector, allowing you to design a Mutation that changes the bell curve of the selected entity's levels to match your intended experience.
This also serves as a filter when this mutator is composed with others - they are processed last->first (bottom to top in the context of a profile), and the first mutator whose level threshold applies to the entity is the one that will be used - the rest will be skipped

Base Level - this is the non-random value to set the entity to, which becomes the new 'base' and is referenced in the rest of the Mutator.
If this is configured to be relative to the highest-leveled player (separate from the threshold), it's considered 'Dynamic', otherwise it's 'Static'

The rest of the Mutator UI is explained via tooltips to avoid duplicated info and inevitable deprecation of information.]]
				},
				{
					type = "Separator"
				},
				{
					type = "SubHeading",
					text = "Server-Side Implementation"
				},
				{
					type = "Content",
					text = [[
This Mutator directly changes the AvailableLevel and EocLevel components on the Entity (somehow this is not transient behavior)

If the Base level is calculated relative to the Players's level (threshold is not relevant here), then a Component listener will be set on the host of the party - when the host levels up and exits the Character Level Up screen, the Profile will completely re-executed as if the game had been saved and reloaded (which does mean that entities that previously didn't meet the threshold could meet it now)

For party size calculations, only party members and followers (not summons) other than the host's character are counted - for compatibility with Sit This One Out 2, the following checks are done on each party member to see if they will join combat:
if (Osi.HasActiveStatus(char, "SITOUT_ONCOMBATSTART_APPLIER_TECHNICAL") == 0
		and Osi.HasActiveStatus(char, "SITOUT_HUSH_STATUS") == 0
		and Osi.HasActiveStatus(char, "SITOUT_VANISH_STATUS_APPLIER") == 0)
	or Osi.HasActiveStatus(char, "SITOUT_ALWAYS_FIGHT_STATUS") == 1
	
Additionally, when a mutator with a party-size calculator is run, OSI Event listeners will be registered to re-execute the profile whenever a party member/follower leaves or joins - if these events happen in camp, then the execution will be deferred until they leave to prevent any dialogue locks and constant execution.]]
				},
				{
					type = "Separator"
				},
				{
					type = "SubHeading",
					text = "Example Use Cases"
				},
				{
					type = "Section",
					text = "Selected entities:"
				},
				{
					type = "Bullet",
					text = {
						"5 levels or more below the player should become between -2 and +1 levels of the player instead",
						"less than level 3 should be become between 0 and +3 levels above level 5",
						"should be 4 levels above their current level",
						"should be 2 levels lower than the player, but Minibosses should be -1/+2 levels and Bosses should be +3/+5."
					}
				} --[[@as MazzleDoctsBullet]],
			}
		}
	} --[[@as MazzleDocsDocumentation]]
end

---@return {[string]: MazzleDocsContentItem}
function LevelMutator:generateChangelog()
	return {
		["1.8.2"] = {
			type = "Bullet",
			text = {
				"Adds ability to specify what the base party size should be for party-based scaling"
			}
		},
		["1.8.1"] = {
			type = "Bullet",
			text = {
				"Makes this mutator composable, using the last mutator in the profile that passes the Level Threshold check",
				"Adds an option to increase the base level for each party member + follower, excluding summons"
			}
		},
		["1.7.0"] = {
			type = "Bullet",
			text = {
				"Changes the on level up behavior to trigger when the EocLevel component changes instead of the AvailableLevel component, preventing it from firing mid-combat",
				"Use EocLevel for all player-centric calculations"
			}
		},
		["1.6.0"] = {
			type = "Bullet",
			text = {
				"Adds Level Thresholds",
				"Adds option to base the static increase/decrease on the entity's level, not the player's level"
			}
		}
	} --[[@as {[string]: MazzleDocsContentItem}]]
end
