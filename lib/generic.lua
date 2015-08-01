
local mt = {}
local _M = {}

local load_class_system = function()
	local common = require "secs-featured"
	_M.common = common
	_M.class = assert(common.class)
	_M.instance = assert(common.instance)
	_M.__BY = common.__BY
end

mt.__index = function(_, k, ...)
	if k == "class" or k == "instance" then
		load_class_system()
		return rawget(_, k)
	end
end

return setmetatable(_M, mt)

