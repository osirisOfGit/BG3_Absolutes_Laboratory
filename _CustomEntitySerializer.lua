CustomEntitySerializer = {}

--- Recursivelly serializes the provided table, serializing table/userdata components and either converting sub-entities into their handles if available or serializing them if not
---@param response table
---@param parentKey string
---@param entityHistory Guid[]
---@return table serializedEntity
function CustomEntitySerializer:recursiveSerialization(response, parentKey, entityHistory)
	local success, error = xpcall(function(...)
		if response then
			if type(response) ~= "table" then
				return response
			else
				for key, value in pairs(response) do
					if type(value) == "userdata" then
						local objectType = Ext.Types.GetObjectType(value)
						if objectType == "Entity" then
							---@cast value EntityHandle
							if TableUtils:IndexOf(entityHistory, Ext.Entity.HandleToUuid(value) or tostring(value)) then
								response[key] = "Entity (RECURSION) : " .. (Ext.Entity.HandleToUuid(value) or tostring(value))
							else
								local entityHistory = TableUtils:DeeplyCopyTable(entityHistory)
								table.insert(entityHistory, Ext.Entity.HandleToUuid(value) or tostring(value))
								response[key] = Ext.Entity.HandleToUuid(value)
									and ("Entity: " .. Ext.Entity.HandleToUuid(value))
									or self:recursiveSerialization(value:GetAllComponents(), key, entityHistory)
							end
						else
							local typeInfo = Ext.Types.GetTypeInfo(objectType)
							if typeInfo and typeInfo.IsBitfield then
								response[key] = value.__Labels
							elseif Ext.Enums[objectType] then
								response[key] = tostring(value)
							else
								local success, serializedValue = pcall(function()
									return Ext.Types.Serialize(value)
								end)

								if success then
									response[key] = self:recursiveSerialization(serializedValue, key, entityHistory)
								else
									response[key] = self:recursiveSerialization(
										Ext.Json.Parse(Ext.Json.Stringify(value, { AvoidRecursion = true, IterateUserdata = true, StringifyInternalTypes = true })),
										key,
										entityHistory)
								end
							end
						end
					end
					value = response[key]
					if type(value) == "table" then
						if type(next(value)) == "userdata" then
							response[key] = {}
							for subKey, subValue in pairs(value) do
								table.insert(entityHistory, Ext.Entity.HandleToUuid(subKey) or tostring(subKey))
								response[key][subValue] = Ext.Entity.HandleToUuid(subKey) and ("ENTITY: " .. Ext.Entity.HandleToUuid(subKey)) or subKey:GetAllComponents()
							end
							value = response[key]
						end

						if TableUtils:CountElements(value) == 1 then
							local innerValue = value[next(value)]
							if type(innerValue) == "table" then
								response[key] = self:recursiveSerialization(innerValue, key, entityHistory)
							elseif type(innerValue) == "userdata" then
								response[key] = innerValue
								self:recursiveSerialization(response, parentKey, entityHistory)
							else
								response[key] = innerValue
							end
						else
							response[key] = self:recursiveSerialization(value, key, entityHistory)
						end
					end
				end
			end
		end
	end, debug.traceback)

	if not success then
		Logger:BasicError("Error while serializing a value for key %s - %s", parentKey, error)
	end

	return response
end
