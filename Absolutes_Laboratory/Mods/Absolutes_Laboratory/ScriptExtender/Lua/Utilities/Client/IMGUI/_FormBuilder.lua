---@class FormBuilder
FormBuilder = {
}

function FormBuilder:generateGUID()
	local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
	local guid = string.gsub(template, '[xy]', function(c)
		local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
		return string.format('%x', v)
	end)
	return guid
end

---@class FormStructure
---@field label string
---@field propertyField string?
---@field type "Text"|"NumericText"|"Multiline"|"Checkbox"
---@field enabled boolean?
---@field defaultValue string|string[]|boolean?
---@field dependsOn string?
---@field errorMessageIfEmpty string?
---@field input ExtuiInputText|ExtuiCheckbox? Internal
---@field authorError ExtuiText? Internal
---@field enumTable function? Internal

---@param parent ExtuiTreeParent
---@param onSubmitFunc fun(formResults: table<string, string|boolean>)
---@param formInputs FormStructure[]
---@return function
function FormBuilder:CreateForm(parent, onSubmitFunc, formInputs)
	Helpers:KillChildren(parent)

	for _, formInput in pairs(formInputs) do
		local label = parent:AddText(formInput.label)

		if formInput.errorMessageIfEmpty then
			label.Label = label.Label .. "*"
		end

		local input
		if formInput.type == "Text" or formInput.type == "NumericText" or formInput.type == "Multiline" then
			input = parent:AddInputText("", formInput.defaultValue or nil)
			input.AutoSelectAll = true

			if formInput.type == "NumericText" then
				input.CharsDecimal = true
				input.Hint = Translator:translate("Numbers, periods, and slashes only")
			elseif formInput.type == "Multiline" then
				input.Multiline = true
			end
		elseif formInput.type == "Checkbox" then
			input = parent:AddCheckbox("", formInput.defaultValue or false)
		end
		input.Disabled = formInput.enabled ~= nil and formInput.enabled or false
		if input.Disabled then
			input:SetColor("Text", { 1, 1, 1, .5 })
		end

		formInput.input = input

		if formInput.enumTable then
			formInput.input.Hint = (formInput.input.Hint and "; " or "") .. Translator:translate("Must select from the list that appears on focus")
			local keyToDisplayMap = formInput.enumTable()

			if formInput.defaultValue then
				for key, displayName in pairs(keyToDisplayMap) do
					if formInput.defaultValue == key then
						formInput.input.Text = displayName
						formInput.input.UserData = key
						break
					end
				end
			end

			local resultsView = parent:AddChildWindow(formInput.propertyField or formInput.label)
			resultsView.AutoResizeY = true
			resultsView.NoSavedSettings = true
			resultsView.Visible = false
			formInput.input.OnChange = function()
				local displayKey = TableUtils:IndexOf(keyToDisplayMap, formInput.input.Text)
				formInput.input.UserData = (displayKey or formInput.input.Text) == formInput.input.UserData
					and formInput.input.UserData
					or nil

				Helpers:KillChildren(resultsView)
				resultsView.Visible = true
				for key, displayName in TableUtils:OrderedPairs(keyToDisplayMap, function(key)
					return keyToDisplayMap[key]
				end) do
					if #input.Text == 0 or input.UserData or string.match(string.upper(displayName), string.upper(input.Text)) then
						---@type ExtuiSelectable
						local enumSelectable = resultsView:AddSelectable(displayName, "DontClosePopups")

						enumSelectable.OnActivate = function()
							formInput.input.UserData = key
							formInput.input.Text = enumSelectable.Label
							resultsView.Visible = false
						end
					end
				end
			end

			input.OnActivate = function()
				formInput.input.OnChange()
			end
			input.OnDeactivate = function()
				if formInput.input.UserData == nil then
					formInput.input.Text = ""
				end
				resultsView.Visible = false
			end
		end

		if formInput.errorMessageIfEmpty then
			local authorError = parent:AddText(formInput.errorMessageIfEmpty)
			-- Red
			authorError:SetColor("Text", { 1, 0.02, 0, 1 })
			authorError.Visible = false

			local oldOnChange = input.OnChange
			input.OnChange = function()
				if oldOnChange then
					oldOnChange()
				end
				authorError.Visible = false
			end
			formInput.authorError = authorError
		end
	end

	local function buildInputs()
		local hasErrors
		local inputs = {}
		for _, formInput in pairs(formInputs) do
			if formInput.authorError then
				local dependsHasContent = nil
				if formInput.dependsOn then
					for _, inputToDependOn in pairs(formInputs) do
						if inputToDependOn.label == formInput.dependsOn then
							if inputToDependOn.input.Text and not inputToDependOn.input.Text:match("^%s*$") then
								dependsHasContent = true
							else
								dependsHasContent = false
							end
							break
						end
					end
					if dependsHasContent == true and (not formInput.input.Text or formInput.input.Text:match("^%s*$")) then
						formInput.authorError.Visible = true
						hasErrors = true
						goto continue
					end
				else
					-- If it's empty
					if not formInput.input.Text or formInput.input.Text:match("^%s*$") then
						formInput.authorError.Visible = true
						hasErrors = true
						goto continue
					end
				end
			end
			if formInput.type == "Text" or formInput.type == "NumericText" or formInput.type == "Multiline" then
				inputs[formInput.propertyField or formInput.label] = formInput.input.UserData or formInput.input.Text
			elseif formInput.type == "Checkbox" then
				inputs[formInput.propertyField or formInput.label] = formInput.input.Checked
			end
			::continue::
		end

		if hasErrors then
			return
		end
		return inputs
	end

	local submit = parent:AddButton(Translator:translate("Submit"))
	submit.OnClick = function()
		local results = buildInputs()
		if results then
			onSubmitFunc(results)
		end
	end

	return buildInputs
end

Translator:RegisterTranslation({
	["Numbers, periods, and slashes only"] = "hac02ba6d6b2b4edab1eeb923591ccd4e6e7e",
	["Must select from the list that appears on focus"] = "h22a13b7bb7414c7a9d31bc5c82c363c9af2g",
	["Submit"] = "he104f70306a44117a9fbe8367c05d5bbe6ba",
})
