--- @module "Utils._TableUtils"

TableUtils = {}

---@generic K
---@param tarTable table<K, number>? will be created if it doesn't exist
---@param key K 
---@param amount number
---@return table<K, number> table optionally created if one was not provided, with the amount specified added to the key (or just assigned to the key, if missing)
function TableUtils:AddItemToTable_AddingToExistingAmount(tarTable, key, amount)
	if not tarTable then
		tarTable = {}
	end
	if not tarTable[key] then
		tarTable[key] = amount
	else
		tarTable[key] = tarTable[key] + amount
	end

	return tarTable
end

-- stolen from https://stackoverflow.com/questions/640642/how-do-you-copy-a-lua-table-by-value
local function copy(obj, seen, makeImmutable)
	if type(obj) ~= 'table' then return obj end
	if seen and seen[obj] then return seen[obj] end
	local s = seen or {}
	local res = setmetatable({}, getmetatable(obj))
	s[obj] = res
	for k, v in pairs(obj) do res[copy(k, s, makeImmutable)] = copy(v, s, makeImmutable) end

	if makeImmutable then
		res = setmetatable(res, {
			getmetatable(res) and table.unpack(getmetatable(res)),
			__newindex = function(...) error("Attempted to modify immutable table") end
		})
	end

	return res
end

--- If obj is a table, returns a deep clone of that table, otherwise return obj
---@generic T
---@param obj T
---@return T
function TableUtils:DeeplyCopyTable(obj)
	return copy(obj, nil, false)
end

---Compare two lists
---@param first table
---@param second table
---@return boolean doesMatch true if the lists are equal
function TableUtils:CompareLists(first, second)
	if (first and not second) or (not first and second) then
		return false
	end

	for property, value in pairs(first) do
		if value ~= second[property] then
			return false
		end
	end

	for property, value in pairs(second) do
		if value ~= first[property] then
			return false
		end
	end

	return true
end

--- Deeply compare two tables for equality
---@param first table
---@param second table
---@return boolean isEqual true if the tables are deeply equal
function TableUtils:TablesAreEqual(first, second)
	if first == second then
		return true
	end

	if type(first) ~= "table" or type(second) ~= "table" then
		return false
	end

	local seenKeys = {}

	for key, value in pairs(first) do
		if not self:TablesAreEqual(value, second[key]) then
			return false
		end
		seenKeys[key] = true
	end

	for key, value in pairs(second) do
		if not seenKeys[key] then
			return false
		end
	end

	return true
end

--- Custom pairs function that iterates over a table with alphanumeric indexes in alphabetical order
--- Optionally accepts a function to transform the key for sorting and returning
--- If keys are inequal types, will convert both to strings just for comparison
---@generic K
---@generic V
---@param t table<K,V>
---@param keyTransformFunc (fun(key: K, value: V):any)?
---@return fun(table: table<K, V>, index?: K):K,V
function TableUtils:OrderedPairs(t, keyTransformFunc)
	local keys = {}
	for k in pairs(t) do
		table.insert(keys, k)
	end
	table.sort(keys, function(a, b)
		local keyA = keyTransformFunc and keyTransformFunc(a, t[a]) or a
		local keyB = keyTransformFunc and keyTransformFunc(b, t[b]) or b
		if type(keyA) ~= type(keyB) then
			keyA = tostring(keyA)
			keyB = tostring(keyB)
		end
		return keyA < keyB
	end)

	local i = 0

	return function()
		i = i + 1
		if keys[i] then
			local key = keys[i]
			return key, t[key]
		end
	end
end

---@generic K, V
---@param list (table<K, V>)?
---@param valueToFind (V|fun(value: V): boolean)?
---@return K? index if element is found in the list, this is the key it's under
function TableUtils:IndexOf(list, valueToFind)
	if not list then
		return
	end
	for i, value in pairs(list) do
		if type(valueToFind) == "function" then
			if valueToFind(value) then
				return i
			end
		elseif value == valueToFind then
			return i
		end
	end
end

--- Reindexes a table with numeric keys so they increment sequentially from 1, modifying the input table in-place
---@generic T:table
---@param tbl T
---@return T
function TableUtils:ReindexNumericTable(tbl)
	local values = {}
	for k, value in pairs(tbl) do
		table.insert(values, value)
		tbl[k] = nil
	end
	-- Reinsert values with sequential numeric keys
	for i, value in ipairs(values) do
		tbl[i] = value
	end
	return tbl
end

--- Returns a pairs()-like iterator that iterates over multiple tables sequentially
---@generic K, V
---@param ... table<K, V> A variable number of tables to iterate over
---@return fun():K, V
function TableUtils:CombinedPairs(...)
	local tables = { ... }
	local keys = {}
	local tableSizes = {}
	local totalSize = 0

	for _, tbl in ipairs(tables) do
		local tblKeys = {}
		for k in pairs(tbl) do
			table.insert(tblKeys, k)
		end
		table.insert(keys, tblKeys)
		tableSizes[#tableSizes + 1] = #tblKeys
		totalSize = totalSize + #tblKeys
	end

	local i = 0
	local currentTableIndex = 1

	return function()
		while currentTableIndex <= #tables do
			i = i + 1
			if i <= tableSizes[currentTableIndex] then
				local key = keys[currentTableIndex][i]
				return key, tables[currentTableIndex][key]
			else
				i = 0
				currentTableIndex = currentTableIndex + 1
			end
		end
	end
end

--- Convenience method for counting the number of elements in a non-numerically indexed table
---@param tbl table
---@return number
function TableUtils:CountElements(tbl)
	local count = 0
	for _, _ in pairs(tbl) do
		count = count + 1
	end
	return count
end

--- Converts all stringified number indexes in-place to their numerical equivalents
---@param tbl table
function TableUtils:ConvertStringifiedNumberIndexes(tbl)
	for key, value in TableUtils:OrderedPairs(tbl) do
		local numericKey = type(key) ~= "number" and tonumber(key) or nil
		if numericKey then
			tbl[key] = nil
			tbl[numericKey] = value
		end

		if type(value) == "table" then
			self:ConvertStringifiedNumberIndexes(value)
		end
	end
end
