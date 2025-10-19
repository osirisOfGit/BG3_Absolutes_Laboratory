-- Credit: LaughingLeader

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
