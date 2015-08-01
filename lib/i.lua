
local _M = {}

_M._VERSION = "0.1.0"
_M._LICENSE = "MIT"

local table_unpack =
	unpack or    -- lua <= 5.1
	table.unpack -- lua >= 5.2

local all = {} -- [modname] = modtable
local available = {} -- n = modname


local function softrequire(name)
	local mod
	pcall(function() mod = require(name) end)
	return mod
end

local generic = softrequire("generic") or {}

local function needone(name)
	assert(name)
	if all[name] then
		return all[name]
	end
	local function validmodule(m)
		if type(m) ~= "table" then -- or not m.class or not m.instance then
			--assert( type(m) == "table")
			--assert( m.class )
			--assert( m.instance )
			return false
		end
		return m
	end

	local common = validmodule( softrequire(name.."-featured") ) or validmodule( softrequire(name) )
	return common
end

local function return_wrap(r, ok)
	local o = {
		unpack = function() return table_unpack(r) end,
		ok = ok,
		ok_unpack = function() return ok, table_unpack(r) end,
		unpack_ok = function() return table_unpack(r), ok end,
	}
	return setmetatable(o, { __index = r, })
end

local function needall(t_names)
	local r = {}
	local all_ok = true
	local function check(v)
		if not v then all_ok = false end
		return v
	end
	for i,name in ipairs(t_names) do
		r[#r+1] = check(needone(name))
	end
	return return_wrap(r, all_ok)
end


--function _M:needall(t_names)
--	assert(t_names)
--	return needall(t_names)
--end

local readonly = function(...) error("not allowed", 2) end

local t_need_all = setmetatable({
}, {
	__call = function(_, t_names)
		return needall(t_names)
	end,
	__newindex = readonly,
})

_M.need = setmetatable({
	all = t_need_all,
--	any = function(_, k, ...)
--		return needall()
--	end
}, {
	__call = function(_, name)
		return needone(name) or generic[name] or false
	end,
--	__index = function(_, k, ...)
--		local m = needone(k)
--		if not m then
--			m = generic[k]
--		end
--		return m or false
--	end,
	__newindex = readonly,
})

-- require "i".need "generic"["class"]

function _M:requireany(...)
	local packed = type(...) == "table" and ... or {...}
	for i,name in ipairs(packed) do
		local mod = needone(name)
		if mod then
			return mod
		end
	end
	error("requireany: no implementation found", 2)
	return false
end

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

