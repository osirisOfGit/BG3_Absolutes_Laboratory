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
	Styler:MiddleAlignedColumnLayout(parent, function (ele)
		local existingEncounters = ele:AddButton("Existing Encounters")
		existingEncounters.OnClick = function ()
			ExistingEncounters:init(parent)
			existingEncounters:SetColor("Button", {0.38, 0.26, 0.21, 0.78})
		end

		existingEncounters:OnClick()
	end).UserData = "keep"
end
