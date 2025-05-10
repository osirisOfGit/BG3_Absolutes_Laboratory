Channels.GetEntityIcon:SetRequestHandler(function(data, user)
	local entity = Ext.Entity.Get(data.target) --[[@as EntityHandle]]
	return { Result = entity.Icon and entity.Icon.Icon }
end)

Channels.GetEntityStat:SetRequestHandler(function(data, user)
	local entity = Ext.Entity.Get(data.target) --[[@as EntityHandle]]
	return { Result = entity.Data and entity.Data.StatsId }
end)

Channels.IsEntityAlive:SetRequestHandler(function(data, user)
	return { Result = Osi.IsDead(data.target) == 0 }
end)

---@param response table
---@param entity EntityHandle
local function populateBoosts(response, entity)
	response["BoostsContainer"] = {}
	for _, boosts in ipairs(entity.BoostsContainer.Boosts) do
		response["BoostsContainer"][boosts.Type] = {}
		for _, boost in ipairs(boosts.Boosts) do
			local boostTable = {}
			for key, boostInfo in TableUtils:OrderedPairs(boost:GetAllComponents()) do
				boostInfo = (type(boostInfo) == "userdata"
						and (Ext.Types.GetObjectType(boostInfo) == "Entity" and boostInfo:GetAllComponents())
						or Ext.Types.Serialize(boostInfo))
					or boostInfo

				if key ~= "ServerReplicationDependency" then
					if key == "BoostInfo" then
						---@cast boostInfo BoostInfoComponent
						boostTable[key] = {
							Cause = {
								Type = boostInfo.Cause.Type,
								Entity = boostInfo.Cause.Entity and boostInfo.Cause.Entity.Uuid and boostInfo.Cause.Entity.Uuid.EntityUuid
							},
							Params = boostInfo.Params
						}
					else
						boostTable[key] = boostInfo
					end
				end
			end
			table.insert(response["BoostsContainer"][boosts.Type], boostTable)
		end
	end
end

---@param response table
---@param entity EntityHandle
local function populatePassives(response, entity)
	response["PassiveContainer"] = {}

	for _, passive in ipairs(entity.PassiveContainer.Passives) do
		response["PassiveContainer"][passive.Passive.PassiveId] = {}
		local passiveTable = response["PassiveContainer"][passive.Passive.PassiveId]

		for key, passiveInfo in TableUtils:OrderedPairs(passive:GetAllComponents()) do
			passiveInfo = (type(passiveInfo) == "userdata"
					and (Ext.Types.GetObjectType(passiveInfo) == "Entity" and passiveInfo:GetAllComponents())
					or Ext.Types.Serialize(passiveInfo))
				or passiveInfo

			if key ~= "ServerReplicationDependency" then
				if key == "Passive" then
					---@cast passiveInfo PassiveComponent
					passiveTable[key] = {
						Passive = {
							Disabled = passiveInfo.Disabled,
							Source = passiveInfo.Source and passiveInfo.Source.StatusID.ID,
							ToggledOn = passiveInfo.ToggledOn,
							Type = passiveInfo.Type,
							ItemEntity = passiveInfo.Item and passiveInfo.Item.Uuid.EntityUuid,
						},
						Params = passiveInfo.Params
					}
				else
					passiveTable[key] = passiveInfo
				end
			end
		end
	end
end

---@param response table
---@param entity EntityHandle
local function populateStatusContainer(response, entity)
	response["StatusContainer"] = {}

	for _, status in pairs(entity.StatusContainer.Statuses) do
		---@cast entityHandle EntityHandle

		response["StatusContainer"] = status
	end
end

---@param response table
---@param entity EntityHandle
local function populateProgressions(response, entity)
	response["ProgressionContainer"] = {}

	for index, progressions in ipairs(entity.ProgressionContainer.Progressions) do
		response["ProgressionContainer"][index] = {}


		for _, progression in TableUtils:OrderedPairs(progressions) do
			progression = (type(progression) == "userdata"
					and (Ext.Types.GetObjectType(progression) == "Entity" and progression:GetAllComponents())
					or Ext.Types.Serialize(progression))
				or progression

			response["ProgressionContainer"][index][progression.ProgressionMeta.Progression] = {}
			local progressionTable = response["ProgressionContainer"][index][progression.ProgressionMeta.Progression]

			for key, value in TableUtils:OrderedPairs(progression) do
				if key ~= "ServerReplicationDependency" then
					if key == "ProgressionMeta" then
						---@cast value ProgressionMetaComponent

						progressionTable[key] = {
							ClassLevel = value.ClassLevel,
							MulticlassSpellSlotOverride = value.MulticlassSpellSlotOverride,
							Source = value.Source,
							SpellSourceType = value.SpellSourceType,
							Owner = value.Owner and value.Owner.Uuid.EntityUuid,
						}
					else
						progressionTable[key] = value
					end
				end
			end
		end
	end
end

Channels.GetEntityDump:SetRequestHandler(function(data, user)
	---@type EntityHandle
	local entity = Ext.Entity.Get(data.entity)

	---@type string[]
	local fieldsToGet = data.fields

	local response = {}

	if entity then
		for componentName, field in pairs(entity:GetAllComponents()) do
			if TableUtils:ListContains(fieldsToGet, componentName) then
				if componentName == "BoostsContainer" then
					populateBoosts(response, entity)
				elseif componentName == "PassiveContainer" then
					populatePassives(response, entity)
				elseif componentName == "ProgressionContainer" then
					populateProgressions(response, entity)
				elseif componentName == "StatusContainer" then
					populateStatusContainer(response, entity)
				else
					local value = type(field) == "userdata" and Ext.Types.Serialize(field) or field

					if TableUtils:CountElements(value) == 1 then
						response[componentName] = value[next(value)]
					else
						response[componentName] = value
					end
				end
			end
		end
	end

	return Ext.Json.Parse(Ext.Json.Stringify(response, { AvoidRecursion = true, IterateUserdata = true, StringifyInternalTypes = true }))
end)
