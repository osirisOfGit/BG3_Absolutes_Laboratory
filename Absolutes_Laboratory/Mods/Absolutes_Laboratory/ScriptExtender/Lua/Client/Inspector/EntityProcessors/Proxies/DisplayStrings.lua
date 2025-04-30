DisplayStringProxy = EntityProxy:new()

EntityProxy:RegisterResourceProxy("DisplayName", DisplayStringProxy)


---@param translatedString TranslatedString
function DisplayStringProxy:RenderDisplayableValue(parent, translatedString, resourceType)
	if translatedString then
		if type(translatedString) == "table" then
			for name, stringTable in TableUtils:OrderedPairs(translatedString) do
				local translated = Ext.Loca.GetTranslatedString(stringTable.Handle.Handle)
				if translated ~= "" then
					local displayTable = Styler:TwoColumnTable(parent, name)
					local row = displayTable:AddRow()
					row:AddCell():AddText(name)
					row:AddCell():AddText(translated)
				end
			end
		end
	end
end
