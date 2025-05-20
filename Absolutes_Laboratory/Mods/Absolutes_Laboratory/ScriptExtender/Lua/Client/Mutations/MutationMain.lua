MutationMain = {}

Ext.Require("Client/Mutations/MutationDesigner.lua")
Ext.Require("Client/Mutations/MutationProfileManager.lua")

Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Mutations",
	--- @param tabHeader ExtuiTreeParent
	function(tabHeader)
		local mutationTab = tabHeader:AddTabBar("Mutations")

		local designerTab = mutationTab:AddTabItem("Designer")
		MutationDesigner:BuildMutationView(designerTab)
		designerTab.OnActivate = function()
			MutationDesigner:BuildMutationView(designerTab)
		end
		designerTab:Activate()
		local profileTab = mutationTab:AddTabItem("Profiles")
		profileTab.OnActivate = function()
			MutationProfileManager:BuildProfileView(profileTab)
		end
	end)
