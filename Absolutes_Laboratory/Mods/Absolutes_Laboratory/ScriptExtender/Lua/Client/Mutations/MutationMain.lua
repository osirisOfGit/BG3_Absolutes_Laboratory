MutationMain = {}

Ext.Require("Client/Mutations/MutationDesigner.lua")
Ext.Require("Client/Mutations/MutationProfileManager.lua")

Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Mutations",
	--- @param tabHeader ExtuiTreeParent
	function(tabHeader)
		local mutationTab = tabHeader:AddTabBar("Mutations")

		local designerTab = mutationTab:AddTabItem("Designer")
		designerTab.OnActivate = function()
			MutationDesigner:BuildMutationView(designerTab)
		end
		designerTab:Activate()
		mutationTab:AddTabItem("Profiles").OnActivate = function()
			MutationProfileManager:BuildProfileView(mutationTab)
		end
	end)
