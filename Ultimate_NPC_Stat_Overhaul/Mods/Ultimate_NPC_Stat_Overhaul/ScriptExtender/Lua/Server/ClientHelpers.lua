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

	return Ext.Json.Parse(Ext.Json.Stringify(response, {AvoidRecursion = true, IterateUserdata = true, StringifyInternalTypes = true, MaxDepth = 10}))
end)
