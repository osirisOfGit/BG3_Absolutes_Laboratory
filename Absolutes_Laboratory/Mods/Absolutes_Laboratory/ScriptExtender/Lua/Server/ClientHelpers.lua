Channels.GetEntityIcon:SetRequestHandler(function(data, user)
	local entity = Ext.Entity.Get(data.target) --[[@as EntityHandle]]
	return { Result = entity.Icon and entity.Icon.Icon }
end)

Channels.GetCurrentHostLevel:SetRequestHandler(function(data, user)
	---@type EntityHandle
	local entity = Ext.Entity.Get(Osi.GetHostCharacter())

	return entity.Level.LevelName
end)

Channels.TeleportToLevel:SetHandler(function(data, user)
	Osi.TeleportPartiesToLevelWithMovie(data.LevelName, "", "")
end)

Channels.TeleportToCoords:SetHandler(function(data, user)
	Osi.TeleportToPosition(Osi.GetHostCharacter(), data.x, data.y, data.z)
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


---@class OrbRequest
---@field coords number[]?
---@field context string
---@field cleanup boolean?
---@field moonbeam number?

local orbRequests = {}
Channels.OrbAtPosition:SetHandler(
---@param data OrbRequest
	function(data)
		local mazzleLib = Mods.Mazzle_Lib

		if mazzleLib then
			if data.cleanup then
				Osi.RequestDelete(orbRequests[data.context])
				orbRequests[data.context] = nil
			else
				---@class Mazzle_Orbs
				local mazzleOrbs = mazzleLib.Mazzle_Orbs
				if not orbRequests[data.context] then
					orbRequests[data.context] = mazzleOrbs:Create_Debug_Orb(data.coords[1], data.coords[2], data.coords[3])
				else
					Osi.TeleportToPosition(orbRequests[data.context], data.coords[1], data.coords[2], data.coords[3])
				end

				if data.moonbeam then
					mazzleOrbs:Add_VFX_to_Object(orbRequests[data.context], "moonbeam",data.moonbeam)
				end
			end
		else
			Logger:BasicWarning("MazzleLib isn't loaded?")
		end
	end)
