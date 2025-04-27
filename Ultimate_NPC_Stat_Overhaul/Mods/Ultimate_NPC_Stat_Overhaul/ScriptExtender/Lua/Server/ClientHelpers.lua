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

Channels.GetEntityDump:SetRequestHandler(function(data, user)
	---@type EntityHandle
	local entity = Ext.Entity.Get(data.entity)

	---@type string[]
	local fieldsToGet = data.fields

	local response = {}

	if entity then
		for componentName, field in pairs(entity:GetAllComponents()) do
			if TableUtils:ListContains(fieldsToGet, componentName) then
				local value = type(field) == "userdata" and Ext.Types.Serialize(field) or field

				if TableUtils:CountElements(value) == 1 then
					response[componentName] = value[next(value)]
				else
					response[componentName] = value
				end
			end
		end
	end

	return Ext.Json.Parse(Ext.Json.Stringify(response, { AvoidRecursion = true, IterateUserdata = true, StringifyInternalTypes = true }))
end)

Channels.GetBoosts:SetRequestHandler(function(data, user)
	---@type EntityHandle
	local entity = Ext.Entity.Get(data.target)

	local response = {}
	if entity then
		for _, boosts in ipairs(entity.BoostsContainer.Boosts) do
			response[boosts.Type] = {}
			for _, boost in ipairs(boosts.Boosts) do
				local boostTable = {}
				for key, boostInfo in TableUtils:OrderedPairs(boost:GetAllComponents()) do
					boostInfo = (type(boostInfo) == "userdata"
							and (Ext.Types.GetObjectType(boostInfo) == "Entity" and boostInfo:GetAllComponents())
							or Ext.Types.Serialize(boostInfo))
						or boostInfo

					if key ~= "ServerReplicationDependency" then
						if key == "BoostInfo" then
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
				table.insert(response[boosts.Type], boostTable)
			end
		end
	end

	return response
end)
