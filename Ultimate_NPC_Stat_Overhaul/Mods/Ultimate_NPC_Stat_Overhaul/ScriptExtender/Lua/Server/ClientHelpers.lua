Channels.GetEntityIcon:SetRequestHandler(function(data, user)
	local entity = Ext.Entity.Get(data.target) --[[@as EntityHandle]]
	return { Result = entity.Icon and entity.Icon.Icon }
end)

Channels.GetEntityStat:SetRequestHandler(function(data, user)
	local entity = Ext.Entity.Get(data.target) --[[@as EntityHandle]]
	return { Result = entity.Data and entity.Data.StatsId }
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

				if value[componentName] then
					response[componentName] = value[componentName]
				elseif value[componentName .. "s"] then
					response[componentName] = value[componentName .. "s"]
				else
					response[componentName] = value
				end
			end
		end
	end

	return Ext.Json.Parse(Ext.Json.Stringify(response, {AvoidRecursion = true, IterateUserdata = true, StringifyInternalTypes = true, MaxDepth = 10}))
end)
