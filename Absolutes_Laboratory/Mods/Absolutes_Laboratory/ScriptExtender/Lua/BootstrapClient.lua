Ext.Require("Utilities/Common/_Index.lua")
Ext.Require("Utilities/Networking/Channels.lua")
Ext.Require("Utilities/Client/IMGUI/_Index.lua")

Ext.Require("Shared/Configurations/_ConfigurationStructure.lua")

ConfigurationStructure:InitializeConfig()

Ext.Require("Shared/EntityRecorder.lua")
Ext.Require("Shared/Channels.lua")
Ext.Require("Client/RandomHelpers.lua")
Ext.Require("Client/SpellBrowser.lua")
Ext.Require("Client/Styler.lua")
Ext.Require("Client/Inspector/CharacterInspector.lua")

Ext.Require("Shared/Mutations/MutationConfigurationProxy.lua")
Ext.Require("Client/Mutations/MutationExternalProfileUtility.lua")
Ext.Require("Client/Mutations/MutationProfileManager.lua")
