Ext.Require("Client/MonsterLab/ExistingEncounters.lua")

MonsterLab = {}

if Ext.Mod.IsModLoaded("755a8a72-407f-4f0d-9a33-274ac0f0b53d") then
	Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Monster Lab",
		--- @param tabHeader ExtuiTabItem
		function(tabHeader)
			MonsterLab:init(tabHeader)
		end)
end

---@param parent ExtuiTreeParent
function MonsterLab:init(parent)
	local tabBar = parent:AddTabBar("Monster Lab")

	ExistingEncounters:init(tabBar:AddTabItem("Existing Encounters"))
end
