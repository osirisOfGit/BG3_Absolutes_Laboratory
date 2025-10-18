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
	"Error",
	["Selecting"] = 1,
	["Undoing"] = 2,
	["Applying"] = 3,
	["Complete"] = 4,
	["Error"] = 5,
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

---@type "Detailed"|"Simple"|"Off"
local profileView = "Simple"

---@type ExtuiChildWindow|ExtuiGroup
local updaterGroup
Channels.ProfileExecutionStatus:SetHandler(
---@param data ProfileExecutionStatus
	function(data, _)
		if not window then
			profileView = MCM.Get("profile_execution_view") or profileView

			backgroundWindow = Ext.IMGUI.NewWindow("backgroundWindow")
			backgroundWindow.NoSavedSettings = true
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
			backgroundWindow.Visible = profileView == "Detailed"

			window = Ext.IMGUI.NewWindow("ProfileExecutionStatus")
			window.NoSavedSettings = true
			window.NoTitleBar = true
			window.NoMove = true
			window.Closeable = false
			window.Scaling = "Scaled"
			window.NoResize = true
			window.NoNav = true
			window.AlwaysAutoResize = profileView == "Simple"

			if profileView == "Detailed" then
				window:SetBgAlpha(0)
				window:SetColor("FrameBg", { 1, 1, 1, 0 })
				window:SetColor("WindowBg", { 0, 0, 0, 0 })
			end

			window:SetColor("ChildBg", { 0, 0, 0, 0.6 })
			window:SetColor("Text", { 1, 1, 1, 1 })

			if profileView == "Detailed" then
				window:AddDummy(0, 180)
				updaterGroup = window:AddChildWindow("Updating")
			else
				updaterGroup = window:AddGroup("Updating")
			end

			local function sizing()
				if backgroundWindow then
					if backgroundWindow.LastSize[2] and backgroundWindow.LastSize[2] > 200 then
						window:SetSize(backgroundWindow.LastSize, "Always")
						window:SetPos(Styler:ScaleFactor({ -10, -10 }), "Always")
					else
						Ext.Timer.WaitFor(10, sizing)
					end
				end
			end

			Ext.OnNextTick(function(e)
				backgroundWindow:SetPos(Styler:ScaleFactor({ -10, -10 }), "Always")
				if profileView == "Detailed" then
					sizing()
				end
			end)
		end

		Helpers:KillChildren(updaterGroup)
		Styler:CheapTextAlign(("%sExecuting Profile %s"):format(profileView == "Detailed" and "" or "Absolute's Laboratory: ", data.profile), updaterGroup, "Large")

		if data.stage ~= "Complete" and data.stage ~= "Error" then
			if profileView == "Detailed" then
				Styler:CheapTextAlign("Change Report Level In Lab's MCM General Tab", updaterGroup, "Tiny")

				Styler:CheapTextAlign(("Stage %d: %s | Time Elapsed: %dms | Number Of Entities: %d%s"):format(
						stage[data.stage],
						data.stage,
						data.timeElapsed,
						data.numberOfEntitiesProcessed,
						data.stage == "Selecting" and (" out of " .. data.totalNumberOfEntities) or ""),
					updaterGroup,
					"Big")

				if data.stage ~= "Selecting" then
					Styler:MiddleAlignedColumnLayout(updaterGroup, function(ele)
						---@type ExtuiProgressBar
						local progressBar = ele:AddProgressBar()
						progressBar.ItemWidth = math.floor(window.LastSize[1] * .8)
						progressBar.Value = data.numberOfEntitiesProcessed / data.numberOfEntitiesBeingProcessed
						progressBar:SetColor("PlotHistogram", { 1, 1, 1, 1 })
					end)
				end
				Styler:CheapTextAlign("Currently Processing: " .. data.currentEntity, updaterGroup)
			else
				Styler:CheapTextAlign(("Stage %d: %s"):format(stage[data.stage], data.stage), updaterGroup)
				Styler:MiddleAlignedColumnLayout(updaterGroup, function(ele)
					ele:AddText(
						("Time Elapsed: %dms | Number Of Entities Being Processed: %d"):format(data.timeElapsed,
							data.numberOfEntitiesBeingProcessed))
				end)
			end

			if MCM.Get("log_level") >= Logger.PrintTypes.DEBUG then
				Styler:Color(Styler:CheapTextAlign("Debug Logs Are Currently Enabled - This Will Slow Things Down!", updaterGroup), "ErrorText")
			end
		else
			Styler:CheapTextAlign(data.stage == "Complete" and "Completed!" or "Unrecoverable Error Occurred", updaterGroup, "Large")

			if data.stage == "Error" then
				Styler:CheapTextAlign("See log.txt more details and report on Nexus", updaterGroup)
			end

			backgroundWindow.AlwaysAutoResize = false
			window.AlwaysAutoResize = false

			if profileView == "Detailed" then
				Styler:MiddleAlignedColumnLayout(updaterGroup, function(ele)
					Styler:CheapTextAlign("Stats:", ele, "Big")
					local statusTable = ele:AddTable("stats", 2)

					local row = statusTable:AddRow()
					row:AddCell():AddText("Total Time")
					row:AddCell():AddText(("%d milliseconds"):format(data.timeElapsed))

					local row = statusTable:AddRow()
					row:AddCell():AddText("Total Eligible Entities On Server")
					row:AddCell():AddText(("%d"):format(data.totalNumberOfEntities))

					local row = statusTable:AddRow()
					row:AddCell():AddText("Total Entities Mutated")
					row:AddCell():AddText(tostring(data.numberOfEntitiesProcessed))
				end)

				local stepDelay = 33
				local minHeight = window.LastSize[2] * 0.025
				local lastSize = window.LastSize[2]
				local function fadeOut()
					if not window then
						return
					end

					local height = window.LastSize[2]

					if height > minHeight then
						height = math.max(0, height - minHeight)

						window:SetSize({ window.LastSize[1], height }, "Always")
						backgroundWindow:SetSize({ backgroundWindow.LastSize[1], height }, "Always")
						if lastSize ~= height then
							lastSize = height
							Ext.Timer.WaitFor(stepDelay, fadeOut)
						else
							backgroundWindow:Destroy()
							backgroundWindow = nil
							window:Destroy()
							window = nil
						end
					else
						backgroundWindow:Destroy()
						backgroundWindow = nil
						window:Destroy()
						window = nil
					end
				end
				Ext.Timer.WaitFor(3000, fadeOut)
			else
				Ext.Timer.WaitFor(2000, function()
					backgroundWindow:Destroy()
					backgroundWindow = nil
					window:Destroy()
					window = nil
				end)
			end
		end
	end)
