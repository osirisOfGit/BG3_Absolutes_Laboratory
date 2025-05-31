SpellBrowser = {}

---@param parent ExtuiTreeParent
---@param supplementaryResultProcessor fun(parent: ExtuiTreeParent, results: SpellName[])?
---@param wrapFunc fun(pos: number): boolean?
---@param shouldTint fun(spellName: SpellName): boolean?
---@param customizer fun(spellImage: ExtuiImageButton, spellName: SpellName)?
---@param onClickCallback fun(spellImage: ExtuiImageButton, spellName: SpellName)
function SpellBrowser:Render(parent, supplementaryResultProcessor, wrapFunc, shouldTint, customizer, onClickCallback)
	local input = parent:AddInputText("")
	input.Hint = "Min 3 Characters"

	local helpText = parent:AddText("( ? )")
	helpText.SameLine = true
	helpText:Tooltip():AddText([[
	See detailed tooltips on spell images by holding shift -
click outside of the text input first, as the modifier won't be registered while the input is accepting keystrokes.
You can shift-click on images to pop out their tooltip into a new window, but that will close the search popup]])

	local resultsGroup = parent:AddChildWindow("results")
	resultsGroup.NoSavedSettings = true
	resultsGroup.Size = { 0, 300 * Styler:ScaleFactor() }
	local timer
	input.OnChange = function()
		if timer then
			Ext.Timer.Cancel(timer)
		end

		Helpers:KillChildren(resultsGroup)
		if #input.Text >= 3 then
			timer = Ext.Timer.WaitFor(300, function()
				local value = input.Text:upper()
				local results = {}
				for _, spellName in pairs(Ext.Stats.GetStats("SpellData")) do
					---@type SpellData
					local spell = Ext.Stats.Get(spellName)
					if spell.RootSpellID == "" then
						if spellName:upper():find(value) then
							table.insert(results, spellName)
						else
							if spell.DisplayName and Ext.Loca.GetTranslatedString(spell.DisplayName, spell.Name):find(value) then
								table.insert(results, spellName)
							end
						end
					end
				end
				if #results > 0 then
					table.sort(results, function(a, b)
						return Ext.Loca.GetTranslatedString(Ext.Stats.Get(a).DisplayName, a) < Ext.Loca.GetTranslatedString(Ext.Stats.Get(b).DisplayName, b)
					end)

					if supplementaryResultProcessor then
						supplementaryResultProcessor(resultsGroup, results)
					end

					for i, spellName in ipairs(results) do
						---@type SpellData
						local spell = Ext.Stats.Get(spellName)

						local spellImage = resultsGroup:AddImageButton(spellName .. i, spell.Icon, { 48, 48 })

						spellImage.AutoClosePopups = false
						if spellImage.Image.Icon == "" then
							spellImage:Destroy()
							spellImage = resultsGroup:AddImageButton(spellName .. i, "Item_Unknown", { 48, 48 })
						end
						spellImage.SameLine = wrapFunc and wrapFunc(i - 1) or false

						if shouldTint(spellName) then
							spellImage.Tint = { 1, 1, 1, 0.2 }
						end

						if customizer then
							customizer(spellImage, spellName)
						end

						local hyperlinkFunc = Styler:HyperlinkRenderable(spellImage,
							spellName,
							"Shift",
							true,
							string.format("%s\n%s", spellName, Ext.Loca.GetTranslatedString(spell.DisplayName, spellName)),
							function(parent)
								ResourceManager:RenderDisplayWindow(spell, parent)
							end)

						spellImage.OnClick = function()
							if not hyperlinkFunc() then
								onClickCallback(spellImage, spellName)
								spellImage.Tint = { 1, 1, 1, shouldTint(spellName) and 0.2 or 1 }
							end
						end
					end
				end
			end)
		end
	end
end
