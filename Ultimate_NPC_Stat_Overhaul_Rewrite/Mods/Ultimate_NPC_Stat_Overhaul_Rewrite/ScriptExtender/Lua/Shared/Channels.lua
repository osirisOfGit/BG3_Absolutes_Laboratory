---@class ExtenderNetChannel
---@field Module string
---@field Channel string
---@field RequestHandler fun(data:table, user:integer):table
---@field MessageHandler fun(data:table, user:integer)
---@field SendToServer fun(self:ExtenderNetChannel, data:table)
---@field SendToClient fun(self:ExtenderNetChannel, data:table, user:integer|Guid)
---@field Broadcast fun(self:ExtenderNetChannel, data:table, excludeCharacter?:Guid)
local NetChannel = {}

---Sets MessageHandler
---@param callback fun(data:table, user:integer)
function NetChannel:SetHandler(callback) end

---Sets RequestHandler
---@param callback fun(data:table, user:integer):table
function NetChannel:SetRequestHandler(callback) end

---@param data table
---@param replyCallback fun(data:table)
function NetChannel:RequestToServer(data, replyCallback) end

---@param data table
---@param user integer|Guid
---@param replyCallback fun(data:table)
function NetChannel:RequestToClient(data, user, replyCallback) end

---@type {[string]: ExtenderNetChannel}
Channels = {}

Channels.GetEntityDump = Ext.Net.CreateChannel(ModuleUUID, "GetEntityDump")
Channels.GetEntityIcon = Ext.Net.CreateChannel(ModuleUUID, "GetEntityIcon")
Channels.IsEntityAlive = Ext.Net.CreateChannel(ModuleUUID, "IsEntityAlive")
Channels.GetEntityStat = Ext.Net.CreateChannel(ModuleUUID, "GetEntityStat")
