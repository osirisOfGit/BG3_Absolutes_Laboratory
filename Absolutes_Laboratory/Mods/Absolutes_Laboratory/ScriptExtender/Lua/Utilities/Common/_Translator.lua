Translator = {}

local translationTable = {
}

function Translator:RegisterTranslation(translationTableToCopy)
	for key, value in pairs(translationTableToCopy) do
		translationTable[key] = value
	end
end

function Translator:translate(text)
	return Ext.Loca.GetTranslatedString(translationTable[text], text)
end
