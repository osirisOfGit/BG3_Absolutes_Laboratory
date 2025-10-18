Translator = {
	translationTable = {}
}

function Translator:RegisterTranslation(translationTableToCopy)
	for key, value in pairs(translationTableToCopy) do
		self.translationTable[key] = value
	end
end

function Translator:translate(text)
	return Ext.Loca.GetTranslatedString(self.translationTable[text], text)
end
