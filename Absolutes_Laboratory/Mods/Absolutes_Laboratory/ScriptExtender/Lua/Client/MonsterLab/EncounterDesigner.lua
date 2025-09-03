EncounterDesigner = {
	---@type ExtuiWindow
	window = nil
}

---@param encounter MonsterLabEncounter
function EncounterDesigner:buildDesigner(encounter)
	if not self.window then
		self.window = Ext.IMGUI.NewWindow(encounter.name .. "###encounterDesigner")
		self.window.Closeable = true
	else
		self.window.Open = true
		self.window:SetFocus()
	end

	
end
