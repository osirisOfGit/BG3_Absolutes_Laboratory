---@class ExtenderNetChannel
---@field Module string
---@field Channel string
---@field RequestHandler fun(data:any?, user:integer):any?
---@field MessageHandler fun(data:any?, user:integer)
---@field SendToServer fun(self:ExtenderNetChannel, data:any?)
---@field SendToClient fun(self:ExtenderNetChannel, data:any?, user:integer|Guid)
---@field Broadcast fun(self:ExtenderNetChannel, data:any?, excludeCharacter?:Guid)
local NetChannel = {}

---Sets MessageHandler
---@param callback fun(data:any?, user:integer)
function NetChannel:SetHandler(callback) end

---Sets RequestHandler
---@param callback fun(data:any?, user:integer):any?
function NetChannel:SetRequestHandler(callback) end

---@param data any?
---@param replyCallback fun(data:any?)
function NetChannel:RequestToServer(data, replyCallback) end

---@param data any?
---@param user integer|Guid
---@param replyCallback fun(data:any?)
function NetChannel:RequestToClient(data, user, replyCallback) end

---@type {[string]: ExtenderNetChannel}
Channels = {}

Channels.GetEntityDump = Ext.Net.CreateChannel(ModuleUUID, "GetEntityDump")
Channels.GetEntityIcon = Ext.Net.CreateChannel(ModuleUUID, "GetEntityIcon")
Channels.IsEntityAlive = Ext.Net.CreateChannel(ModuleUUID, "IsEntityAlive")
Channels.GetEntityStat = Ext.Net.CreateChannel(ModuleUUID, "GetEntityStat")
Channels.TeleportToLevel = Ext.Net.CreateChannel(ModuleUUID, "TeleportToLevel")
Channels.TeleportToEntity = Ext.Net.CreateChannel(ModuleUUID, "TeleportToEntity")
Channels.TeleportEntityToHost = Ext.Net.CreateChannel(ModuleUUID, "TeleportEntityToHost")


Channels.ActivateMutationProfile = Ext.Net.CreateChannel(ModuleUUID, "ActivateMutationProfile")
