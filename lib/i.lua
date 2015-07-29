-- mom.lua

local _M = {}

_M._VERSION = "2.0"


local all = {} -- [modname] = modtable
local available = {} -- n = modname


local function softrequire(name)
	local mod
	pcall(function() mod = require(name) end)
	return mod
end

local function need(name)
	if all[name] then
		return all[name]
	end
	local function validmodule(m)
		if type(m) ~= "table" or type(m.common) ~= "table" or not m.common.class or not m.common.instance then
			assert( type(m) == "table")
			assert( type(m.common) == "table")
			assert( m.common.class )
			assert( m.common.instance )
			return false
		end
		return m.common
	end

	local common = validmodule( softrequire(name.."-featured") )or validmodule( softrequire(name) )
	return common
end
function _M:need(name)
	return need(name)
end

function _M:requireany(...)
	local packed = type(...) == "table" and ... or {...}
	for i,name in ipairs(packed) do
		local mod = need(name)
		if mod then
			return mod
		end
	end
	error("requireany: no implementation found", 2)
	return false
end

--function _M:default(name)
--	local d = require name or "secs"
--end

-- the default implementation
--_M.common = <here a table index to the default implementation>
--_M.common = {class = class, instance = instance} -- it's a 



function _M:register(name, common)
	assert(common, "register: argument #2 is invalid")
	assert(common.class)
	assert(common.instance)

	-- FIXME: check if already exists
	available[#available+1] = name
	all[name] = common

	return common
end
function _M:unregister(name)
	--FIXME: code me
end

function _M:available()
	return available
end

return _M

