local TypeUtils = {}

function TypeUtils.isImplementation(template, target)
	assert(type(template) == "table", "Bad template")

	return type(target) == "table"
		and (getmetatable(target) == template or TypeUtils._checkInterface(template, target))
end

function TypeUtils._checkInterface(template, target)
	local targetMetatable = getmetatable(target)
	local templateMetatable = getmetatable(template)
	if targetMetatable and type(targetMetatable.__index) == "function" then
		-- Indexing into this target could cause an error. Treat it differently and fast-fail
		if templateMetatable then
			return targetMetatable.__index == templateMetatable.__index
		end

		return false
	end

	for key, value in pairs(template) do
		if type(value) == "function" and type(target[key]) ~= "function" then
			return false
		end
	end

	-- TODO: Prevent infinite recursion potential
	if templateMetatable and type(templateMetatable.__index) == "table" then
		return TypeUtils._checkInterface(templateMetatable.__index, target)
	end

	return true
end


return TypeUtils