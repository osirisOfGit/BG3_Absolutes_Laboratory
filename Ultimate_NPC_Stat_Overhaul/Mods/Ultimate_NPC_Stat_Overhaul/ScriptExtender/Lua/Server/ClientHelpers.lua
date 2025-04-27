Channels.GetEntityIcon:SetRequestHandler(function(data, user)
	local entity = Ext.Entity.Get(data.target) --[[@as EntityHandle]]
	return { Result = entity.Icon and entity.Icon.Icon }
end)

Channels.GetEntityDump:SetRequestHandler(function(data, user)
	---@type EntityHandle
	local entity = Ext.Entity.Get(data.entity)

	---@type string[]
	local fieldsToGet = data.fields

	local response = {}

	if entity then
		for _, field in ipairs(fieldsToGet) do
			if entity[field] then
				if entity[field][field] then
					local value = entity[field][field]
					response[field] = type(value) == "userdata" and Ext.Types.Serialize(value) or value
				else
					response[field] = type(entity[field]) == "userdata" and Ext.Types.Serialize(entity[field]) or entity[field]
				end
			end
		end
	end

	return response
end)
