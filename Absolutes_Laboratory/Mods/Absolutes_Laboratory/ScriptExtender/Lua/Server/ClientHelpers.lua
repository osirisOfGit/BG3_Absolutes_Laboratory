Channels.GetEntityIcon:SetRequestHandler(function(data, user)
	local entity = Ext.Entity.Get(data.target) --[[@as EntityHandle]]
	return { Result = entity.Icon and entity.Icon.Icon }
end)

Channels.TeleportToLevel:SetHandler(function(data, user)
	Osi.TeleportPartiesToLevelWithMovie(data.LevelName, "", "")
end)

Channels.TeleportToEntity:SetHandler(function(data, user)
	Osi.TeleportTo(Osi.GetHostCharacter(), data)
end)

Channels.TeleportEntityToHost:SetHandler(function(data, user)
	Osi.AppearAt(data, Osi.GetHostCharacter(), 0, "", "")
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
			if TableUtils:IndexOf(fieldsToGet, componentName) then
				response[componentName] = field
			end
		end
	end

	return CustomEntitySerializer:recursiveSerialization(response, nil, { Ext.Entity.HandleToUuid(entity) })
end)
