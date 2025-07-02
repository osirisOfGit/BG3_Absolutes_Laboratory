-- Thank ya Norbyte

--- @class ChangePrinter
--- @field TargetedEntities EntityHandle[]
--- @field EntityHandlers number[]
--- @field FrameLimit number?
--- @field ChangeCounts number[]
--- @field TrackChangeCounts boolean
--- @field PrintChanges boolean
--- @field EntityCreations boolean|nil Include entity creation events
--- @field EntityDeletions boolean|nil Include entity deletion events
--- @field OneFrameComponents boolean|nil Include "one-frame" components (usually one-shot event components)
--- @field ReplicatedComponents boolean|nil Include components that can be replicated (not the same as replication events!)
--- @field ComponentReplications boolean|nil Include server-side replication events
--- @field ComponentCreations boolean|nil Include entity creation events
--- @field ComponentDeletions boolean|nil Include component deletions
--- @field ExcludeComponents table<string,boolean> Exclude these components
--- @field IncludedOnly boolean
--- @field IncludeComponents table<string,boolean> Only include these components
--- @field ExcludeSpamComponents boolean
--- @field ExcludeCommonComponents boolean
--- @field Boosts boolean|nil Include boost entities
--- @field ExcludeCrowds boolean|nil Exclude crowd entities
--- @field ExcludeStatuses boolean|nil Exclude status entities
--- @field ExcludeBoosts boolean|nil Exclude boost entities
--- @field ExcludeInterrupts boolean|nil Exclude interrupt entities
--- @field ExcludePassives boolean|nil Exclude passive entities
--- @field ExcludeInventories boolean|nil Exclude inventory entities
ChangePrinter = {}

ECSLogger = Logger:new("ECSPrinter.txt")
ECSLogger:ClearLogFile()

-- Components that change hundreds of times and have no gameplay relevance
local SpamComponents = {
	['eoc::PathingDistanceChangedOneFrameComponent'] = true,
	['eoc::PathingMovementSpeedChangedOneFrameComponent'] = true,
	['eoc::animation::AnimationInstanceEventsOneFrameComponent'] = true,
	['eoc::animation::BlueprintRefreshedEventOneFrameComponent'] = true,
	['eoc::animation::GameplayEventsOneFrameComponent'] = true,
	['eoc::animation::TextKeyEventsOneFrameComponent'] = true,
	['eoc::animation::TriggeredEventsOneFrameComponent'] = true,
	['ls::AnimationBlueprintLoadedEventOneFrameComponent'] = true,
	['ls::RotateChangedOneFrameComponent'] = true,
	['ls::TranslateChangedOneFrameComponent'] = true,
	['ls::VisualChangedEventOneFrameComponent'] = true,
	['ls::animation::LoadAnimationSetRequestOneFrameComponent'] = true,
	['ls::animation::RemoveAnimationSetsRequestOneFrameComponent'] = true,
	['ls::animation::LoadAnimationSetGameplayRequestOneFrameComponent'] = true,
	['ls::animation::RemoveAnimationSetsGameplayRequestOneFrameComponent'] = true,
	['ls::ActiveVFXTextKeysComponent'] = true,
	['ls::InvisibilityVisualComponent'] = true,
	['ecl::InvisibilityVisualComponent'] = true,
	['ls::LevelComponent'] = true,
	['ls::LevelIsOwnerComponent'] = true,
	['ls::IsGlobalComponent'] = true,
	['ls::SavegameComponent'] = true,
	['ls::SaveWithComponent'] = true,
	['ls::TransformComponent'] = true,
	['ls::ParentEntityComponent'] = true,

	-- Client
	['ecl::level::PresenceComponent'] = true,
	['ecl::character::GroundMaterialChangedEventOneFrameComponent'] = true,

	-- Replication
	['ecs::IsReplicationOwnedComponent'] = true,
	['esv::replication::PeersInRangeComponent'] = true,

	-- SFX
	['ls::SoundMaterialComponent'] = true,
	['ls::SoundComponent'] = true,
	['ls::SoundActivatedEventOneFrameComponent'] = true,
	['ls::SoundActivatedComponent'] = true,
	['ls::SoundUsesTransformComponent'] = true,
	['ecl::sound::CharacterSwitchDataComponent'] = true,
	['ls::SkeletonSoundObjectTransformComponent'] = true,

	-- Sight & co
	['eoc::sight::EntityViewshedComponent'] = true,
	['esv::sight::EntityViewshedContentsChangedEventOneFrameComponent'] = true,
	['esv::sight::AiGridViewshedComponent'] = true,
	['esv::sight::SightEventsOneFrameComponent'] = true,
	['esv::sight::ViewshedParticipantsAddedEventOneFrameComponent'] = true,
	['eoc::sight::DarkvisionRangeChangedEventOneFrameComponent'] = true,
	['eoc::sight::DataComponent'] = true,

	-- Common events/updates
	['eoc::inventory::MemberTransformComponent'] = true,
	['eoc::translate::ChangedEventOneFrameComponent'] = true,
	['esv::status::StatusEventOneFrameComponent'] = true,
	['esv::status::TurnStartEventOneFrameComponent'] = true,
	['ls::anubis::TaskFinishedOneFrameComponent'] = true,
	['ls::anubis::TaskPausedOneFrameComponent'] = true,
	['ls::anubis::UnselectedStateComponent'] = true,
	['ls::anubis::ActiveComponent'] = true,
	['esv::GameTimerComponent'] = true,

	-- Navigation
	['navcloud::RegionLoadingComponent'] = true,
	['navcloud::RegionLoadedOneFrameComponent'] = true,
	['navcloud::RegionsUnloadedOneFrameComponent'] = true,
	['navcloud::AgentChangedOneFrameComponent'] = true,
	['navcloud::ObstacleChangedOneFrameComponent'] = true,
	['navcloud::ObstacleMetaDataComponent'] = true,
	['navcloud::ObstacleComponent'] = true,
	['navcloud::InRangeComponent'] = true,

	-- AI movement
	['eoc::steering::SyncComponent'] = true,

	-- Timelines
	['eoc::TimelineReplicationComponent'] = true,
	['eoc::SyncedTimelineControlComponent'] = true,
	['eoc::SyncedTimelineActorControlComponent'] = true,
	['esv::ServerTimelineCreationConfirmationComponent'] = true,
	['esv::ServerTimelineDataComponent'] = true,
	['esv::ServerTimelineActorDataComponent'] = true,
	['eoc::TimelineActorDataComponent'] = true,
	['eoc::timeline::ActorVisualDataComponent'] = true,
	['ecl::TimelineSteppingFadeComponent'] = true,
	['ecl::TimelineAutomatedLookatComponent'] = true,
	['ecl::TimelineActorLeftEventOneFrameComponent'] = true,
	['ecl::TimelineActorJoinedEventOneFrameComponent'] = true,
	['eoc::timeline::steering::TimelineSteeringComponent'] = true,
	['esv::dialog::ADRateLimitingDataComponent'] = true,

	-- Crowd behavior
	['esv::crowds::AnimationComponent'] = true,
	['esv::crowds::DetourIdlingComponent'] = true,
	['esv::crowds::PatrolComponent'] = true,
	['eoc::crowds::CustomAnimationComponent'] = true,
	['eoc::crowds::ProxyComponent'] = true,
	['eoc::crowds::DeactivateCharacterComponent'] = true,
	['eoc::crowds::FadeComponent'] = true,

	-- A lot of things sync this one for no reason
	['eoc::CanSpeakComponent'] = true,

	-- Animations trigger tag updates
	['esv::tags::TagsChangedEventOneFrameComponent'] = true,
	['ls::animation::DynamicAnimationTagsComponent'] = true,
	['eoc::TagComponent'] = true,
	['eoc::trigger::TypeComponent'] = true,

	-- Misc event spam
	['esv::spell::SpellPreparedEventOneFrameComponent'] = true,
	['esv::interrupt::ValidateOwnersRequestOneFrameComponent'] = true,
	['esv::death::DeadByDefaultRequestOneFrameComponent'] = true,
	['eoc::DarknessComponent'] = true,
	['esv::boost::DelayedDestroyRequestOneFrameComponent'] = true,
	['eoc::stats::EntityHealthChangedEventOneFrameComponent'] = true,

	-- Updated based on distance to player
	['eoc::GameplayLightComponent'] = true,
	['esv::light::GameplayLightChangesComponent'] = true,
	['eoc::item::ISClosedAnimationFinishedOneFrameComponent'] = true,
}


local StatusComponents = {
	['esv::status::AttemptEventOneFrameComponent'] = true,
	['esv::status::AttemptFailedEventOneFrameComponent'] = true,
	['esv::status::ApplyEventOneFrameComponent'] = true,
	['esv::status::ActivationEventOneFrameComponent'] = true,
	['esv::status::DeactivationEventOneFrameComponent'] = true,
	['esv::status::RemoveEventOneFrameComponent'] = true
}

---@return ChangePrinter
function ChangePrinter:New()
	---@type ChangePrinter
	local o = {
		TargetedEntities = {},
		EntityHandlers = {},
		FrameNo = 1,
		PrintChanges = true,
		TrackChangeCounts = true,
		ChangeCounts = {},

		ExcludeSpamComponents = true,

		-- Exclude these components
		ExcludeComponents = {},
		-- Only include these components
		IncludedOnly = false,
		IncludeComponents = {},

		ExcludeCrowds = false,
		ExcludeStatuses = false,
		ExcludeBoosts = false,
		ExcludeInterrupts = false,
		ExcludePassives = false,
		ExcludeInventories = false,
	}
	setmetatable(o, self)
	self.__index = self
	return o
end

function ChangePrinter:Start(frameLimit, ...)
	local targetedEntities = { ... }
	table.move(targetedEntities, 1, #targetedEntities, #self.TargetedEntities + 1, self.TargetedEntities)
	if not self.TickHandler then
		self.FrameLimit = frameLimit
		Ext.Entity.EnableTracing(true)
		self.TickHandler = Ext.Events.Tick:Subscribe(function() self:OnTick() end)
		self.Timer = Ext.Timer.WaitFor(10000, function()
			self:Stop()
		end)
		ECSLogger:BasicInfo("Started Tracing")
	end
end

function ChangePrinter:Stop()
	if self.Timer then
		Ext.Timer.Cancel(self.Timer)
	end
	Ext.Entity.EnableTracing(false)
	Ext.Entity.ClearTrace()
	Ext.Events.Tick:Unsubscribe(self.TickHandler)
	self.TargetedEntities = {}
	self.TickHandler = nil
	ECSLogger:BasicInfo("Finished Tracing")
	for _, handle in pairs(self.EntityHandlers) do
		Ext.Entity.Unsubscribe(handle)
	end
end

---@param subscriptionHandle number returned by the Ext.Entity subscribe call - will be automatically unsubscribed when Tracing ends
function ChangePrinter:RegisterEntitySubscription(subscriptionHandle)
	if self.TickHandler then
		table.insert(self.EntityHandlers, subscriptionHandle)
	end
end

---@param entity EntityHandle
---@param changes EcsECSEntityLog
function ChangePrinter:EntityHasPrintableChanges(entity, changes)
	if self.EntityCreations ~= nil and self.EntityCreations ~= changes.Create then return false end
	if self.EntityDeletions ~= nil and self.EntityDeletions ~= changes.Destroy then return false end

	if self.ExcludeInterrupts and entity:HasRawComponent("eoc::interrupt::DataComponent") then
		return false
	end

	if self.ExcludeBoosts and entity:HasRawComponent("eoc::BoostInfoComponent") then
		return false
	end

	if self.ExcludeStatuses and entity:HasRawComponent("esv::status::StatusComponent") then
		return false
	end

	if self.ExcludePassives and entity:HasRawComponent("eoc::PassiveComponent") then
		return false
	end

	if self.ExcludeInventories and entity:HasRawComponent("eoc::inventory::DataComponent") then
		return false
	end

	if self.ExcludeCrowds and entity:HasRawComponent("eoc::crowds::AppearanceComponent") then return false end

	for _, component in pairs(changes.Components) do
		if self:IsComponentChangePrintable(entity, component) then
			return true
		end
	end

	return false
end

---@param entity EntityHandle
---@param component EcsECSComponentLog
function ChangePrinter:IsComponentChangePrintable(entity, component)
	if self.OneFrameComponents ~= nil and self.OneFrameComponents ~= component.OneFrame then return false end
	if self.ReplicatedComponents ~= nil and self.ReplicatedComponents ~= component.ReplicatedComponent then return false end
	if self.ComponentCreations ~= nil and self.ComponentCreations ~= component.Create then return false end
	if self.ComponentDeletions ~= nil and self.ComponentDeletions ~= component.Destroy then return false end
	if self.ComponentReplications ~= nil and self.ComponentReplications ~= component.Replicate then return false end

	if self.ExcludeSpamComponents and SpamComponents[component.Name] then return false end
	if self.ExcludeStatuses and StatusComponents[component.Name] then return false end

	if self.ExcludeComponents[component.Name] == true then return false end
	if self.IncludedOnly and self.IncludeComponents[component.Name] ~= true then return false end

	return true
end

---@param entity EntityHandle
function ChangePrinter:GetEntityName(entity)
	if entity.DisplayName ~= nil then
		return Ext.Loca.GetTranslatedString(entity.DisplayName.NameKey.Handle.Handle)
	elseif entity.SpellCastState ~= nil then
		return "Spell Cast " .. entity.SpellCastState.SpellId.Prototype
	elseif entity.ProgressionMeta ~= nil then
		--- @type ResourceProgression
		local progression = Ext.StaticData.Get(entity.ProgressionMeta.Progression, "Progression")
		return "Progression " .. progression.Name
	elseif entity.BoostInfo ~= nil then
		return "Boost " .. entity.BoostInfo.Params.Boost
	elseif entity.StatusID ~= nil then
		return "Status " .. entity.StatusID.ID
	elseif entity.Passive ~= nil then
		return "Passive " .. entity.Passive.PassiveId
	elseif entity.InterruptData ~= nil then
		return "Interrupt " .. entity.InterruptData.Interrupt
	elseif entity.InventoryIsOwned ~= nil then
		return "Inventory of " .. self:GetEntityName(entity.InventoryIsOwned.Owner)
	elseif entity.InventoryData ~= nil then
		return "Inventory"
	elseif entity:HasRawComponent("eoc::crowds::AppearanceComponent") then
		return "Crowd"
	end

	return ""
end

---@param entity EntityHandle
function ChangePrinter:GetEntityNameDecorated(entity)
	local name = self:GetEntityName(entity)

	if name ~= nil and #name > 0 then
		return "[" .. name .. "]"
	else
		return tostring(entity)
	end
end

function ChangePrinter:OnTick()
	local trace = Ext.Entity.GetTrace()
	for entity, changes in pairs(trace.Entities) do
		if ((not next(self.TargetedEntities) or not entity.Uuid) or (entity.Uuid and TableUtils:IndexOf(self.TargetedEntities, entity.Uuid.EntityUuid))) and self:EntityHasPrintableChanges(entity, changes) then
			if self.PrintChanges then
				local msg = "[#" .. self.FrameNo .. "] " .. self:GetEntityNameDecorated(entity) .. ": "
				if changes.Create then msg = msg .. " Created" end
				if changes.Destroy then msg = msg .. " Destroyed" end
				ECSLogger:BasicDebug(msg)
			end

			for _, component in pairs(changes.Components) do
				if self:IsComponentChangePrintable(entity, component) then
					if self.TrackChangeCounts then
						if self.ChangeCounts[component.Name] == nil then
							self.ChangeCounts[component.Name] = 1
						else
							self.ChangeCounts[component.Name] = self.ChangeCounts[component.Name] + 1
						end
					end

					if self.PrintChanges then
						local msg = "\t" .. component.Name .. ": "
						if component.Create then msg = msg .. " Created" end
						if component.Destroy then msg = msg .. " Destroyed" end
						if component.Replicate then msg = msg .. " Replicated" end
						ECSLogger:BasicDebug(msg)
					end
				end
			end
		end
	end

	Ext.Entity.ClearTrace()
	self.FrameNo = self.FrameNo + 1
	if self.FrameLimit and self.FrameLimit == self.FrameNo then
		self:Stop()
	end
end

Printer = ChangePrinter:New()
Printer.PrintChanges = true
Printer.EntityDeletions = false
Printer.ExcludeCrowds = true
Printer.ExcludeStatuses = true
Printer.ExcludeBoosts = true
Printer.ExcludeInterrupts = true
Printer.ExcludePassives = true
Printer.ExcludeInventories = true
-- Printer:Start()

SpellPrinter = ChangePrinter:New()
SpellPrinter.PrintChanges = false
SpellPrinter.EntityDeletions = false
SpellPrinter.ExcludeCrowds = true
SpellPrinter.ExcludeStatuses = true
SpellPrinter.ExcludeBoosts = true
SpellPrinter.ExcludeInterrupts = true
SpellPrinter.ExcludePassives = true
SpellPrinter.ExcludeInventories = true

function SpellPrinter:OnTick()
	local trace = Ext.Entity.GetTrace()
	for entity, changes in pairs(trace.Entities) do
		if self:EntityHasPrintableChanges(entity, changes) then
			if self.PrintChanges then
				local msg = "[#" .. self.FrameNo .. "] " .. self:GetEntityNameDecorated(entity) .. ": "
				if changes.Create then msg = msg .. "Created" end
				if changes.Destroy then msg = msg .. "Destroyed" end
				ECSLogger:BasicDebug(msg)
			end

			for _, component in pairs(changes.Components) do
				if self:IsComponentChangePrintable(entity, component) then
					if self.TrackChangeCounts then
						if self.ChangeCounts[component.Name] == nil then
							self.ChangeCounts[component.Name] = 1
						else
							self.ChangeCounts[component.Name] = self.ChangeCounts[component.Name] + 1
						end
					end

					if self.PrintChanges then
						local msg = "\t" .. component.Name .. ": "
						if component.Create then msg = msg .. "Created" end
						if component.Destroy then msg = msg .. "Destroyed" end
						if component.Replicate then msg = msg .. "Replicated" end
						ECSLogger:BasicDebug(msg)
					end

					if component.Name == "ecl::spell_preview::EffectsComponent" then
						Ext.Events.Tick:Subscribe(function()
							ECSLogger:BasicDebug(entity:GetAllComponents())
						end)
					end
				end
			end
		end
	end

	Ext.Entity.ClearTrace()
	self.FrameNo = self.FrameNo + 1
end
