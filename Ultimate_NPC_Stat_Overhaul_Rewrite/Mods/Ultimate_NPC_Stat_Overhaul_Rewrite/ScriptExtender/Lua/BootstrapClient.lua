Ext.Require("Shared/Translator.lua")
Ext.Require("Shared/Utils/_TableUtils.lua")
Ext.Require("Shared/Utils/_FileUtils.lua")
Ext.Require("Shared/Utils/_ModUtils.lua")
Ext.Require("Shared/Utils/_Logger.lua")

Ext.Require("Shared/Channels.lua")

Ext.Events.StatsLoaded:Subscribe(function()
	Logger:ClearLogFile()
end)

Ext.Require("Client/RandomHelpers.lua")
Ext.Require("Client/Styler.lua")
Ext.Require("Client/Inspector/CharacterIndexer.lua")
Ext.Require("Client/Inspector/CharacterInspector.lua")
