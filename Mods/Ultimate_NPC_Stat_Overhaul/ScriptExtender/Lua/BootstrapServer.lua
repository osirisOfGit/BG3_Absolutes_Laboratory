Ext.Require("Shared/Utils/_FileUtils.lua")
Ext.Require("Shared/Utils/_ModUtils.lua")
Ext.Require("Shared/Utils/_Logger.lua")
Ext.Require("Shared/Utils/_TableUtils.lua")

-- Load required files
Ext.Require("Server/_Vars.lua")
Ext.Require("Server/_ListCalling.lua")

-- Load class-specific files
Ext.Require("Server/Classes/_Barbarian.lua")
Ext.Require("Server/Classes/_Bard.lua")
Ext.Require("Server/Classes/_Cleric.lua")
Ext.Require("Server/Classes/_Druid.lua")
Ext.Require("Server/Classes/_Fighter.lua")
Ext.Require("Server/Classes/_Monk.lua")
Ext.Require("Server/Classes/_Paladin.lua")
Ext.Require("Server/Classes/_Ranger.lua")
Ext.Require("Server/Classes/_Rogue.lua")
Ext.Require("Server/Classes/_Sorcerer.lua")
Ext.Require("Server/Classes/_Warlock.lua")
Ext.Require("Server/Classes/_Wizard.lua")

-- Load utility and table files
Ext.Require("Server/Tables/_Feats.lua")
Ext.Require("Server/Tables/_Subclasses.lua")

-- Load main functionality files
Ext.Require("Server/_VarsReset.lua")
Ext.Require("Server/_LevelBoosts.lua")
