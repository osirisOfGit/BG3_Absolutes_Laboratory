Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Configuration",
	--- @param tabHeader ExtuiTreeParent
	function(tabHeader)
		---@type ExtuiProgressBar
		local progressBar = tabHeader:AddProgressBar()
		progressBar.Visible = false

		local displayTable = tabHeader:AddTable("allConfigs", 2)
		displayTable:AddColumn("", "WidthFixed")
		displayTable:AddColumn("", "WidthStretch")

		local row = displayTable:AddRow()

		local selectionTreeCell = row:AddCell()

		local configurationViewCell = row:AddCell()

		local universalSelection = selectionTreeCell:AddTree("Acts")
		universalSelection:AddDummy(0, 0)
		universalSelection:SetOpen(false, "Always")

		universalSelection.OnClick = function()
			if not next(CharacterIndex.displayNameMappings) then
				local maxCount, hydrateIndex = CharacterIndex:hydrateIndex()
				progressBar.Visible = true
				local function doIt()
					local count = hydrateIndex()
					if count then
						progressBar.Value = (count / maxCount)
						Ext.Timer.WaitFor(1, doIt)
					elseif #selectionTreeCell.Children <= 1 then
						maxCount = TableUtils:CountElements(CharacterIndex.templates.acts)
						count = 0
						hydrateIndex = coroutine.wrap(function()
							for act, actTemplates in TableUtils:OrderedPairs(CharacterIndex.templates.acts) do
								local actSelection = universalSelection:AddTree(act)

								local parentRaceSelection = actSelection:AddTree("Races")
								for race, raceTemplates in TableUtils:OrderedPairs(CharacterIndex.templates.races, function(key)
									return CharacterIndex.displayNameMappings[key]
								end) do
									local raceSelection = parentRaceSelection:AddTree(CharacterIndex.displayNameMappings[race] or race)
									raceSelection.UserData = race

									for _, raceTemplate in TableUtils:OrderedPairs(raceTemplates, function(key)
										return CharacterIndex.displayNameMappings[raceTemplates[key]]
									end) do
										if TableUtils:ListContains(actTemplates, raceTemplate) then
											local selectable = raceSelection:AddSelectable(CharacterIndex.displayNameMappings[raceTemplate])
											selectable.UserData = raceTemplate
										end
									end
									if #raceSelection.Children == 0 then
										raceSelection:Destroy()
									end
								end

								local parentProgressionTableSelection = actSelection:AddTree("Progression Tables")
								for progressionTable, progressionTemplates in TableUtils:OrderedPairs(CharacterIndex.templates.progressions) do
									local progressionTableSelection = parentProgressionTableSelection:AddTree(progressionTable)

									for _, progressionTemplate in TableUtils:OrderedPairs(progressionTemplates, function(key)
										return CharacterIndex.displayNameMappings[progressionTemplates[key]]
									end) do
										if TableUtils:ListContains(actTemplates, progressionTemplate) then
											progressionTableSelection:AddSelectable(CharacterIndex.displayNameMappings[progressionTemplate])
										end
									end
								end
								count = count + 1
								coroutine.yield(count)
							end

							progressBar.Visible = false
						end)
						doIt()
					end
				end
				doIt()
			end
		end
	end
)
