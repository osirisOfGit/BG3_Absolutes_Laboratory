---@type ExtuiWindow?
local window = nil

---@type ExtuiWindow
local backgroundWindow = nil

---@enum Stage
local stage = {
	"Selecting",
	"Undoing",
	"Applying",
	"Complete",
	["Selecting"] = 1,
	["Undoing"] = 2,
	["Applying"] = 3,
	["Complete"] = 4
}

---@class ProfileExecutionStatus
---@field profile string
---@field stage Stage
---@field currentEntity Guid
---@field totalNumberOfEntities number
---@field numberOfEntitiesBeingProcessed number
---@field numberOfEntitiesProcessed number
---@field timeElapsed number
---@field error string?

local function fadeOut(delay)
	-- if delay then
	-- 	backgroundWindow:SetBgAlpha(100)
	-- 	window:SetBgAlpha(100)
	-- 	Ext.Timer.WaitFor(3000, fadeOut)
	-- 	return
	-- end

	if window:GetStyle("Alpha") > 0 then
		backgroundWindow:SetStyle("Alpha", backgroundWindow:GetStyle("Alpha") - 0.1)
		window:SetStyle("Alpha", window:GetStyle("Alpha") - 0.1)
		Ext.Timer.WaitFor(300, fadeOut)
	else
		backgroundWindow:Destroy()
		backgroundWindow = nil
		window:Destroy()
		window = nil
	end
end

---@type ExtuiGroup
local updaterGroup
Channels.ProfileExecutionStatus:SetHandler(
---@param data ProfileExecutionStatus
	function(data, _)
		if not window then
			backgroundWindow = Ext.IMGUI.NewWindow("backgroundWindow")
			backgroundWindow.NoTitleBar = true
			backgroundWindow.NoMove = true
			backgroundWindow.Closeable = false
			backgroundWindow.NoResize = true
			backgroundWindow.AlwaysAutoResize = true
			backgroundWindow.Scaling = "Scaled"
			-- backgroundWindow:SetBgAlpha(0)
			backgroundWindow:SetStyle("Alpha", 100)
			-- backgroundWindow:SetColor("FrameBg", { 1, 1, 1, 0 })
			-- backgroundWindow:SetColor("WindowBg", { 1, 1, 1, 0 })
			backgroundWindow:AddImage("Background_Image", { 860, 484 }):SetStyle("Alpha", 0.5)

			window = Ext.IMGUI.NewWindow("ProfileExecutionStatus")
			window.NoTitleBar = true
			window.NoMove = true
			window.Closeable = false
			window.Scaling = "Scaled"
			window.NoResize = true
			window:SetColor("ChildBg", { 0, 0, 0, 0.1 })
			window:SetBgAlpha(0)
			window:SetStyle("Alpha", 100)
			window:SetColor("FrameBg", { 1, 1, 1, 0 })
			window:SetColor("WindowBg", { 1, 1, 1, 0 })
			window:SetColor("Text", { 1, 1, 1, 1 })

			Ext.OnNextTick(function(e)
				backgroundWindow:SetPos({ 0, 0 }, "Always")
				Ext.OnNextTick(function(e)
					window:SetPos({ 0, 0 }, "Always")
					window:SetSize(backgroundWindow.LastSize)
				end)
			end)

			updaterGroup = window:AddGroup("Updating")
		end

		Helpers:KillChildren(updaterGroup)
		Styler:ScaledFont(updaterGroup:AddText("Executing Absolute's Laboratory Profile " .. data.profile), "Large")

		if data.stage ~= "Complete" then
			Styler:ScaledFont(updaterGroup:AddText(
					("Stage %d: %s | Time Elapsed: %dms | Number Of Entities: %d"):format(stage[data.stage], data.stage, data.timeElapsed, data.numberOfEntitiesBeingProcessed)),
				"Big")

			---@type ExtuiProgressBar
			local progressBar = updaterGroup:AddProgressBar()
			progressBar.Value = data.numberOfEntitiesProcessed / data.numberOfEntitiesBeingProcessed
			Styler:CheapTextAlign("Currently Processing: " .. data.currentEntity, updaterGroup)
		else
			Styler:CheapTextAlign("Completed!", updaterGroup, "Large").SameLine = true

			Styler:ScaledFont(updaterGroup:AddText("Stats:"), "Big")
			local statusTable = updaterGroup:AddTable("stats", 2)

			local row = statusTable:AddRow()
			row:AddCell():AddText("Total Time")
			row:AddCell():AddText(("%d milliseconds"):format(data.timeElapsed))

			local row = statusTable:AddRow()
			row:AddCell():AddText("Total Entities Eligible For Mutation")
			row:AddCell():AddText(("%d"):format(data.totalNumberOfEntities))

			local row = statusTable:AddRow()
			row:AddCell():AddText("Total Entities Mutated")
			row:AddCell():AddText(tostring(data.numberOfEntitiesProcessed))


			fadeOut(true)
		end
	end)
