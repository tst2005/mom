local _M = {}

local preload = require "package".preload
local enabled = true

local function erase(name)
	if enabled and preload[name] then
		preload[name] = nil
		return true
	end
	return false
end
local function disable()
	enabled = false
end
local function exists(name)
	return not not preload[name]
end
local function list(sep)
	local r = {}
	for k in pairs(preload) do
		r[#r+1] = k
	end
	return setmetatable(r, {__tostring = function() return table.concat(r, sep or " ") end})
end

_M.erase = erase
_M.remove = erase
_M.disable = disable
_M.exists = exists
_M.list = list

return _M
