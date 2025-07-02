FileUtils = {}

--- Builds a file target path relative to AIM's ScriptExtender/ path (to be used in combination with Utils:BuildAbsoluteFileTargetPath)
---@tparam string fileName required
---@tparam string... subDirs optional varargs
---@treturn string Example: subDir="dir", fileName="file", returns dir/file.json
function FileUtils:BuildRelativeJsonFileTargetPath(fileName, ...)
	local subDirs = { ... }
	if #subDirs > 0 then
		local filePath = ""
		for _, subDir in pairs(subDirs) do
			filePath = filePath .. subDir .. "/"
		end
		return filePath .. fileName .. ".json"
	else
		return fileName .. ".json"
	end
end

--- Builds the aboslute file path to the AIM ScriptExtender directory
---@tparam string filepath required
---@treturn string
function FileUtils:BuildAbsoluteFileTargetPath(filepath)
	return Ext.Mod.GetMod(ModuleUUID).Info.Directory .. "/" .. filepath
end

--- Convenience for saving a Lua Table to a file under the AIM mod directory, logging and swallowing any errors encountered
---@param filepath string relative to the mod dir (e.g. filters/weapons.json)
---@param content any will be stringified using Ext.Json.Stringify
---@treturn boolean true if the operation succeeded, false otherwise
function FileUtils:SaveTableToFile(filepath, content)
	local jsonSuccess, response = pcall(function()
		return Ext.Json.Stringify(content, {
			Beautify = false,
			IterateUserdata = true,
			StringifyInternalTypes = true
		})
	end)

	if not jsonSuccess then
		Logger:BasicError("Failed to convert content %s for file %s to JSON due to error \n\t%s",
			content,
			filepath,
			response)

		return false
	end

	return FileUtils:SaveStringContentToFile(filepath, response)
end

--- Convenience for saving a file under the AIM mod directory, logging and swallowing any errors encountered
---@tparam string filepath relative to the mod dir (e.g. filters/weapons.json)
---@tparam any content will be stringified using Ext.Json.Stringify
---@treturn boolean true if the operation succeeded, false otherwise
function FileUtils:SaveStringContentToFile(filepath, content)
	local success, error = pcall(function()
		return Ext.IO.SaveFile(FileUtils:BuildAbsoluteFileTargetPath(filepath), content)
	end)

	if not success then
		Logger:BasicError("Failed to save file %s due to error \n\t%s", FileUtils:BuildAbsoluteFileTargetPath(filepath), error)

		return false
	end

	return true
end

function FileUtils:LoadTableFile(filepath, addlArg)
	local success, result = pcall(function()
		local fileContent = FileUtils:LoadFile(filepath, addlArg)
		if fileContent then
			return Ext.Json.Parse(fileContent)
		end
	end)

	if not success then
		if result then
			Logger:BasicError("Failed to parse contents of file %s due to error \n\t%s",
				FileUtils:BuildAbsoluteFileTargetPath(filepath),
				result)
		end
	else
		return result
	end
end

--- Convenience for loading a file under the AIM mod directory
---@param filepath string relative to the mod directory
---@return string|nil
function FileUtils:LoadFile(filepath, addlArg)
	local success, result = pcall(function()
		return Ext.IO.LoadFile(addlArg and filepath or FileUtils:BuildAbsoluteFileTargetPath(filepath), addlArg)
	end)

	if not success then
		if result then
			Logger:BasicError("Failed to load %s due to error\n\t%s",
				FileUtils:BuildAbsoluteFileTargetPath(filepath),
				result)
		end
	else
		return result
	end
end
