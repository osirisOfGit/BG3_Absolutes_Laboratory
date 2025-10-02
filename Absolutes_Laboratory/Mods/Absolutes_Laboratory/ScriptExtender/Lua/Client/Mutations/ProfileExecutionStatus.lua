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

---@type ExtuiWindow
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
			backgroundWindow.Scaling = "Scaled"
			backgroundWindow.NoNav = true
			backgroundWindow:SetBgAlpha(0)
			backgroundWindow:SetColor("WindowBg", { 0, 0, 0, 0 })
			backgroundWindow:SetColor("FrameBg", { 0, 0, 0, 0 })
			backgroundWindow:AddImage("Background_Image", { 860, 484 })
			backgroundWindow.AlwaysAutoResize = true

			window = Ext.IMGUI.NewWindow("ProfileExecutionStatus")
			window.NoTitleBar = true
			window.NoMove = true
			window.Closeable = false
			window.Scaling = "Scaled"
			window.NoResize = true
			window.NoNav = true
			window:SetBgAlpha(0)
			window:SetColor("FrameBg", { 1, 1, 1, 0 })
			window:SetColor("WindowBg", { 0, 0, 0, 0 })

			window:SetColor("ChildBg", { 0, 0, 0, 0.6 })
			window:SetColor("Text", { 1, 1, 1, 1 })

			Ext.OnNextTick(function(e)
				backgroundWindow:SetPos(Styler:ScaleFactor({ -10, -10 }), "Always")
				window:SetSize(backgroundWindow.LastSize, "Always")
				Ext.OnNextTick(function(e)
					window:SetPos(Styler:ScaleFactor({ -10, -10 }), "Always")
				end)
			end)

			window:AddDummy(0, 180)
			updaterGroup = window:AddChildWindow("Updating")
		end

		Helpers:KillChildren(updaterGroup)
		Styler:CheapTextAlign("Executing Profile " .. data.profile, updaterGroup, "Large")

		if data.stage ~= "Complete" then
			Styler:ScaledFont(updaterGroup:AddText(
					("Stage %d: %s | Time Elapsed: %dms | Number Of Entities: %d"):format(stage[data.stage], data.stage, data.timeElapsed, data.numberOfEntitiesBeingProcessed)),
				"Big")

			if data.stage ~= "Selecting" then
				Styler:MiddleAlignedColumnLayout(updaterGroup, function(ele)
					---@type ExtuiProgressBar
					local progressBar = updaterGroup:AddProgressBar()
					if data.stage == "Applying" then
						progressBar.Value = data.numberOfEntitiesProcessed / data.numberOfEntitiesBeingProcessed
					end
					progressBar:SetColor("PlotHistogram", { 1, 1, 1, 1 })
				end)
			end
			Styler:CheapTextAlign("Currently Processing: " .. data.currentEntity, updaterGroup)
		else
			Styler:CheapTextAlign("Completed!", updaterGroup, "Large")

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

			local stepDelay = 10
			local minHeight = window.LastSize[2] * 0.1
			local function fadeOut()
				local height = window.LastSize[2]

				if height > minHeight then
					height = math.max(0, height - (height * 0.03)) -- Reduce by 10%

					window:SetSize({ window.LastSize[1], height }, "Always")
					backgroundWindow:SetSize({ backgroundWindow.LastSize[1], height }, "Always")
					updaterGroup.Size = { 0, math.max(0, updaterGroup.LastSize[2] - (updaterGroup.LastSize[2] * 0.003)) }

					Ext.Timer.WaitFor(stepDelay, fadeOut)
				else
					backgroundWindow:Destroy()
					backgroundWindow = nil
					window:Destroy()
					window = nil
				end
			end
			backgroundWindow.AlwaysAutoResize = false
			Ext.Timer.WaitFor(3000, fadeOut)
		end
	end)
