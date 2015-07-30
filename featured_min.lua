_ = [[
	for name in luajit lua5.3 lua-5.3 lua5.2 lua-5.2 lua5.1 lua-5.1 lua; do
		: ${LUA:=$(command -v luajit)}
	done
	LUA_PATH='./?.lua;./?/init.lua;./lib/?.lua;./lib/?/init.lua;;'
	exec "$LUA" "$0" "$@"
	exit $?
]]
_ = nil
require("package").preload["gro"] = function(...)
	local _M = {  }
	local loaded = require "package".loaded
	local lock = {  }
	local lock_mt = { __newindex = function()
	end, __tostring = function()
		return "locked"
	end, __metatable = assert(lock) }
	setmetatable(lock, lock_mt)
	assert(tostring(lock == "locked"))
	local allow_arg = true
	local function writeargonce(...)
		if allow_arg then
			allow_arg = false
			rawset(...)
			return true
		end

		return false
	end

	local allow_u = true
	local shellcode
	local function write_u_once(_, name, value)
		if value == nil then
			return true
		end

				if allow_u and type(value) == "string" then
			allow_u = false
			shellcode = value
			return true
		elseif shellcode == value then
			return true
		end

		return false
	end

	local function cutname(name)
		return (#name > 30) and (name:sub(1, 20) .. "... ..." .. name:sub(-4, -1)) or name
	end

	local ro_mt = getmetatable(_G) or {  }
	ro_mt.__newindex = function(_g_, name, value)
		if name == "_" and write_u_once(_G, name, value) then
			return 
		end

		if loaded[name] == value then
			io.stderr:write("drop global write of module '" .. tostring(name) .. "'\n")
			return 
		end

		if name == "arg" then
			if writeargonce(_G, name, value) then
				return 
			end

		end

		error(("global env is read-only. Write of %q"):format(cutname(name)), 2)
	end
	ro_mt.__metatable = lock
	setmetatable(_G, ro_mt)
	if getmetatable(_G) ~= lock then
		error("unable to setup global env to read-only", 2)
	end

	return {  }
end
require("gro")
require("package").preload["strict"] = function(...)
	local getinfo, error, rawset, rawget = debug.getinfo, error, rawset, rawget
	local mt = getmetatable(_G)
	if mt == nil then
		mt = {  }
		setmetatable(_G, mt)
	end

	mt.__declared = {  }
	local function what()
		local d = getinfo(3, "S")
		return d and d.what or "C"
	end

	mt.__newindex = function(t, n, v)
		if not mt.__declared[n] then
			local w = what()
			if w ~= "main" and w ~= "C" then
				error("assignment to undeclared variable '" .. n .. "'", 2)
			end

			mt.__declared[n] = true
		end

		rawset(t, n, v)
	end
	mt.__index = function(t, n)
		if not mt.__declared[n] and what() ~= "C" then
			error("variable '" .. n .. "' is not declared", 2)
		end

		return rawget(t, n)
	end
end
require("strict")
require("package").preload["i"] = function(...)
	local _M = {  }
	_M._VERSION = "2.0"
	local all = {  }
	local available = {  }
	local function softrequire(name)
		local mod
		pcall(function()
			mod = require(name)
		end)
		return mod
	end

	local function need(name)
		if all[name] then
			return all[name]
		end

		local function validmodule(m)
			if type(m) ~= "table" or type(m.common) ~= "table" or not m.common.class or not m.common.instance then
				assert(type(m) == "table")
				assert(type(m.common) == "table")
				assert(m.common.class)
				assert(m.common.instance)
				return false
			end

			return m.common
		end

		local common = validmodule(softrequire(name .. "-featured")) or validmodule(softrequire(name))
		return common
	end

	function _M:need(name)
		return need(name)
	end

	function _M:requireany(...)
		local packed = type(...) == "table" and ... or { ... }
		for i, name in ipairs(packed) do
			local mod = need(name)
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
		available[#available + 1] = name
		all[name] = common
		return common
	end

	function _M:unregister(name)
	end

	function _M:available()
		return available
	end

	_M._LICENSE = "MIT"
	return _M
end
require("package").preload["secs"] = function(...)
	local class_mt = {  }
	function class_mt:__index(key)
		return self.__baseclass[key]
	end

	local class = setmetatable({ __baseclass = {  } }, class_mt)
	function class:new(...)
		local c = {  }
		c.__baseclass = self
		setmetatable(c, getmetatable(self))
		if c.init then
			c:init(...)
		end

		return c
	end

	return class
end
require("package").preload["secs-featured"] = function(...)
	local class = require "secs"
	local common = {  }
	function common.class(name, t, parent)
		parent = parent or class
		t = t or {  }
		t.__baseclass = parent
		return setmetatable(t, getmetatable(parent))
	end

	function common.instance(class,...)
		return class:new(...)
	end

	common.__BY = "secs"
	pcall(function()
		require("i"):register("secs", common)
	end)
	return { common = common }
end
require("package").preload["middleclass"] = function(...)
	local middleclass = { _VERSION = 'middleclass v3.0.1', _DESCRIPTION = 'Object Orientation for Lua', _URL = 'https://github.com/kikito/middleclass', _LICENSE = [[
    MIT LICENSE

    Copyright (c) 2011 Enrique García Cota

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:

    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
  ]] }
	local function _setClassDictionariesMetatables(aClass)
		local dict = aClass.__instanceDict
		dict.__index = dict
		local super = aClass.super
		if super then
			local superStatic = super.static
			setmetatable(dict, super.__instanceDict)
			setmetatable(aClass.static, { __index = function(_, k)
				return dict[k] or superStatic[k]
			end })
		else
			setmetatable(aClass.static, { __index = function(_, k)
				return dict[k]
			end })
		end

	end

	local function _setClassMetatable(aClass)
		setmetatable(aClass, { __tostring = function()
			return "class " .. aClass.name
		end, __index = aClass.static, __newindex = aClass.__instanceDict, __call = function(self, ...)
			return self:new(...)
		end })
	end

	local function _createClass(name, super)
		local aClass = { name = name, super = super, static = {  }, __mixins = {  }, __instanceDict = {  } }
		aClass.subclasses = setmetatable({  }, { __mode = "k" })
		_setClassDictionariesMetatables(aClass)
		_setClassMetatable(aClass)
		return aClass
	end

	local function _createLookupMetamethod(aClass, name)
		return function(...)
			local method = aClass.super[name]
			assert(type(method) == 'function', tostring(aClass) .. " doesn't implement metamethod '" .. name .. "'")
			return method(...)
		end
	end

	local function _setClassMetamethods(aClass)
		for _, m in ipairs(aClass.__metamethods) do
			aClass[m] = _createLookupMetamethod(aClass, m)
		end

	end

	local function _setDefaultInitializeMethod(aClass, super)
		aClass.initialize = function(instance, ...)
			return super.initialize(instance, ...)
		end
	end

	local function _includeMixin(aClass, mixin)
		assert(type(mixin) == 'table', "mixin must be a table")
		for name, method in pairs(mixin) do
			if name ~= "included" and name ~= "static" then
				aClass[name] = method
			end

		end

		if mixin.static then
			for name, method in pairs(mixin.static) do
				aClass.static[name] = method
			end

		end

		if type(mixin.included) == "function" then
			mixin:included(aClass)
		end

		aClass.__mixins[mixin] = true
	end

	local Object = _createClass("Object", nil)
	Object.static.__metamethods = { '__add', '__call', '__concat', '__div', '__ipairs', '__le', '__len', '__lt', '__mod', '__mul', '__pairs', '__pow', '__sub', '__tostring', '__unm' }
	function Object.static:allocate()
		assert(type(self) == 'table', "Make sure that you are using 'Class:allocate' instead of 'Class.allocate'")
		return setmetatable({ class = self }, self.__instanceDict)
	end

	function Object.static:new(...)
		local instance = self:allocate()
		instance:initialize(...)
		return instance
	end

	function Object.static:subclass(name)
		assert(type(self) == 'table', "Make sure that you are using 'Class:subclass' instead of 'Class.subclass'")
		assert(type(name) == "string", "You must provide a name(string) for your class")
		local subclass = _createClass(name, self)
		_setClassMetamethods(subclass)
		_setDefaultInitializeMethod(subclass, self)
		self.subclasses[subclass] = true
		self:subclassed(subclass)
		return subclass
	end

	function Object.static:subclassed(other)
	end

	function Object.static:isSubclassOf(other)
		return type(other) == 'table' and type(self) == 'table' and type(self.super) == 'table' and (self.super == other or type(self.super.isSubclassOf) == 'function' and self.super:isSubclassOf(other))
	end

	function Object.static:include(...)
		assert(type(self) == 'table', "Make sure you that you are using 'Class:include' instead of 'Class.include'")
		for _, mixin in ipairs({ ... }) do
			_includeMixin(self, mixin)
		end

		return self
	end

	function Object.static:includes(mixin)
		return type(mixin) == 'table' and type(self) == 'table' and type(self.__mixins) == 'table' and (self.__mixins[mixin] or type(self.super) == 'table' and type(self.super.includes) == 'function' and self.super:includes(mixin))
	end

	function Object:initialize()
	end

	function Object:__tostring()
		return "instance of " .. tostring(self.class)
	end

	function Object:isInstanceOf(aClass)
		return type(self) == 'table' and type(self.class) == 'table' and type(aClass) == 'table' and (aClass == self.class or type(aClass.isSubclassOf) == 'function' and self.class:isSubclassOf(aClass))
	end

	function middleclass.class(name, super,...)
		super = super or Object
		return super:subclass(name, ...)
	end

	middleclass.Object = Object
	setmetatable(middleclass, { __call = function(_, ...)
		return middleclass.class(...)
	end })
	return middleclass
end
require("package").preload["middleclass-featured"] = function(...)
	local middleclass = require "middleclass"
	middleclass._LICENSE = "MIT"
	local common = {  }
	if type(middleclass.common) == "table" and type(middleclass.common.class) == "function" and type(middleclass.common.instannce) == "function" then
		common = middleclass.common
	else
		function common.class(name, klass, superclass)
			local c = middleclass.class(name, superclass)
			klass = klass or {  }
			for i, v in pairs(klass) do
				c[i] = v
			end

			if klass.init then
				c.initialize = klass.init
			end

			return c
		end

		function common.instance(c,...)
			return c:new(...)
		end

	end

	if common.__BY == nil then
		common.__BY = "middleclass"
	end

	pcall(function()
		require("classcommons2"):register("middleclass", common)
	end)
	return { common = common }
end
require("package").preload["30log"] = function(...)
	local assert, pairs, type, tostring, setmetatable = assert, pairs, type, tostring, setmetatable
	local baseMt, _instances, _classes, class = {  }, setmetatable({  }, { __mode = 'k' }), setmetatable({  }, { __mode = 'k' })
	local function deep_copy(t, dest, aType)
		local t, r = t or {  }, dest or {  }
		for k, v in pairs(t) do
						if aType and type(v) == aType then
				r[k] = v
			elseif not aType then
				if type(v) == 'table' and k ~= "__index" then
					r[k] = deep_copy(v)
				else
					r[k] = v
				end

			end

		end

		return r
	end

	local function instantiate(self,...)
		assert(_classes[self], 'new() should be called from a class.')
		local instance = deep_copy(self)
		_instances[instance] = tostring(instance)
		setmetatable(instance, self)
		if self.__init then
			if type(self.__init) == 'table' then
				deep_copy(self.__init, instance)
			else
				self.__init(instance, ...)
			end

		end

		return instance
	end

	local function extends(self, extra_params)
		local heir = {  }
		_classes[heir] = tostring(heir)
		deep_copy(extra_params, deep_copy(self, heir))
		heir.__index, heir.super = heir, self
		return setmetatable(heir, self)
	end

	baseMt = { __call = function(self, ...)
		return self:new(...)
	end, __tostring = function(self, ...)
		if _instances[self] then
			return ('object(of %s):<%s>'):format((rawget(getmetatable(self), '__name') or '?'), _instances[self])
		end

		return _classes[self] and ('class(%s):<%s>'):format((rawget(self, '__name') or '?'), _classes[self]) or self
	end }
	local class = function(attr)
		local c = deep_copy(attr)
		_classes[c] = tostring(c)
		c.include = function(self, include)
			assert(_classes[self], 'Mixins can only be used on classes.')
			return deep_copy(include, self, 'function')
		end
		c.new, c.extends, c.__index, c.__call, c.__tostring = instantiate, extends, c, baseMt.__call, baseMt.__tostring
		c.is = function(self, kind)
			local super
			while true do
				super = getmetatable(super or self)
				if super == kind or super == nil then
					break
				end

			end

			return kind and (super == kind)
		end
		return setmetatable(c, baseMt)
	end
	return class
end
require("package").preload["30log-featured"] = function(...)
	local class = require "30log"
	local common = {  }
	common.class = function(name, prototype, parent)
		local klass = class():extends(parent):extends(prototype)
		klass.__init = (prototype or {  }).init or (parent or {  }).init
		klass.__name = name
		return klass
	end
	common.instance = function(class, ...)
		return class:new(...)
	end
	common.__BY = "30log"
	local _M = { common = common }
	pcall(function()
		require("i"):register("30log", common)
	end)
	return _M
end
require("package").preload["compat_env"] = function(...)
	local M = { _TYPE = 'module', _NAME = 'compat_env', _VERSION = '0.2.2.20120406' }
	local function check_chunk_type(s, mode)
		local nmode = mode or 'bt'
		local is_binary = s and #s > 0 and s:byte(1) == 27
				if is_binary and not nmode:match 'b' then
			return nil, ("attempt to load a binary chunk (mode is '%s')"):format(mode)
		elseif not is_binary and not nmode:match 't' then
			return nil, ("attempt to load a text chunk (mode is '%s')"):format(mode)
		end

		return true
	end

	local IS_52_LOAD = pcall(load, '')
	if IS_52_LOAD then
		M.load = _G.load
		M.loadfile = _G.loadfile
	else
		function M.load(ld, source, mode, env)
			local f
						if type(ld) == 'string' then
				local s = ld
				local ok, err = check_chunk_type(s, mode)
				if not ok then
					return ok, err
				end

				local err
				f, err = loadstring(s, source)
				if not f then
					return f, err
				end

			elseif type(ld) == 'function' then
				local ld2 = ld
				if (mode or 'bt') ~= 'bt' then
					local first = ld()
					local ok, err = check_chunk_type(first, mode)
					if not ok then
						return ok, err
					end

					ld2 = function()
						if first then
							local chunk = first
							first = nil
							return chunk
						else
							return ld()
						end

					end
				end

				local err
				f, err = load(ld2, source)
				if not f then
					return f, err
				end

			else
				error(("bad argument #1 to 'load' (function expected, got %s)"):format(type(ld)), 2)
			end

			if env then
				setfenv(f, env)
			end

			return f
		end

		function M.loadfile(filename, mode, env)
			if (mode or 'bt') ~= 'bt' then
				local ioerr
				local fh, err = io.open(filename, 'rb')
				if not fh then
					return fh, err
				end

				local function ld()
					local chunk
					chunk, ioerr = fh:read(4096)
					return chunk
				end

				local f, err = M.load(ld, filename and '@' .. filename, mode, env)
				fh:close()
				if not f then
					return f, err
				end

				if ioerr then
					return nil, ioerr
				end

				return f
			else
				local f, err = loadfile(filename)
				if not f then
					return f, err
				end

				if env then
					setfenv(f, env)
				end

				return f
			end

		end

	end

	if _G.setfenv then
		M.setfenv = _G.setfenv
		M.getfenv = _G.getfenv
	else
		local function envlookup(f)
			local name, val
			local up = 0
			local unknown
			repeat
				up = up + 1
				name, val = debug.getupvalue(f, up)
				if name == '' then
					unknown = true
				end

			until name == '_ENV' or name == nil

			if name ~= '_ENV' then
				up = nil
				if unknown then
					error("upvalues not readable in Lua 5.2 when debug info missing", 3)
				end

			end

			return (name == '_ENV') and up, val, unknown
		end

		local function envhelper(f, name)
						if type(f) == 'number' then
								if f < 0 then
					error(("bad argument #1 to '%s' (level must be non-negative)"):format(name), 3)
				elseif f < 1 then
					error("thread environments unsupported in Lua 5.2", 3)
				end

				f = debug.getinfo(f + 2, 'f').func
			elseif type(f) ~= 'function' then
				error(("bad argument #1 to '%s' (number expected, got %s)"):format(type(name, f)), 2)
			end

			return f
		end

		function M.setfenv(f, t)
			local f = envhelper(f, 'setfenv')
			local up, val, unknown = envlookup(f)
			if up then
				debug.upvaluejoin(f, up, function()
					return up
				end, 1)
				debug.setupvalue(f, up, t)
			else
				local what = debug.getinfo(f, 'S').what
				if what ~= 'Lua' and what ~= 'main' then
					error("'setfenv' cannot change environment of given object", 2)
				end

			end

			return f
		end

		function M.getfenv(f)
			if f == 0 or f == nil then
				return _G
			end

			local f = envhelper(f, 'setfenv')
			local up, val = envlookup(f)
			if not up then
				return _G
			end

			return val
		end

	end

	return M
end
require("package").preload["hump.class"] = function(...)
	local function include_helper(to, from, seen)
						if from == nil then
			return to
		elseif type(from) ~= 'table' then
			return from
		elseif seen[from] then
			return seen[from]
		end

		seen[from] = to
		for k, v in pairs(from) do
			k = include_helper({  }, k, seen)
			if to[k] == nil then
				to[k] = include_helper({  }, v, seen)
			end

		end

		return to
	end

	local function include(class, other)
		return include_helper(class, other, {  })
	end

	local function clone(other)
		return setmetatable(include({  }, other), getmetatable(other))
	end

	local function new(class)
		local inc = class.__includes or {  }
		if getmetatable(inc) then
			inc = { inc }
		end

		for _, other in ipairs(inc) do
			if type(other) == "string" then
				other = _G[other]
			end

			include(class, other)
		end

		class.__index = class
		class.init = class.init or class[1] or function()
		end
		class.include = class.include or include
		class.clone = class.clone or clone
		return setmetatable(class, { __call = function(c, ...)
			local o = setmetatable({  }, c)
			o:init(...)
			return o
		end })
	end

	if class_commons ~= false and not common then
		common = {  }
		function common.class(name, prototype, parent)
			return new { __includes = { prototype, parent } }
		end

		function common.instance(class,...)
			return class(...)
		end

	end

	return setmetatable({ new = new, include = include, clone = clone }, { __call = function(_, ...)
		return new(...)
	end })
end
require("package").preload["bit.numberlua"] = function(...)
	local M = { _TYPE = 'module', _NAME = 'bit.numberlua', _VERSION = '0.3.1.20120131' }
	local floor = math.floor
	local MOD = 2 ^ 32
	local MODM = MOD - 1
	local function memoize(f)
		local mt = {  }
		local t = setmetatable({  }, mt)
		function mt:__index(k)
			local v = f(k)
			t[k] = v
			return v
		end

		return t
	end

	local function make_bitop_uncached(t, m)
		local function bitop(a, b)
			local res, p = 0, 1
			while a ~= 0 and b ~= 0 do
				local am, bm = a % m, b % m
				res = res + t[am][bm] * p
				a = (a - am) / m
				b = (b - bm) / m
				p = p * m
			end

			res = res + (a + b) * p
			return res
		end

		return bitop
	end

	local function make_bitop(t)
		local op1 = make_bitop_uncached(t, 2 ^ 1)
		local op2 = memoize(function(a)
			return memoize(function(b)
				return op1(a, b)
			end)
		end)
		return make_bitop_uncached(op2, 2 ^ (t.n or 1))
	end

	function M.tobit(x)
		return x % 2 ^ 32
	end

	M.bxor = make_bitop { [0] = { [0] = 0, [1] = 1 }, [1] = { [0] = 1, [1] = 0 }, n = 4 }
	local bxor = M.bxor
	function M.bnot(a)
		return MODM - a
	end

	local bnot = M.bnot
	function M.band(a, b)
		return ((a + b) - bxor(a, b)) / 2
	end

	local band = M.band
	function M.bor(a, b)
		return MODM - band(MODM - a, MODM - b)
	end

	local bor = M.bor
	local lshift, rshift
	function M.rshift(a, disp)
		if disp < 0 then
			return lshift(a, -disp)
		end

		return floor(a % 2 ^ 32 / 2 ^ disp)
	end

	rshift = M.rshift
	function M.lshift(a, disp)
		if disp < 0 then
			return rshift(a, -disp)
		end

		return (a * 2 ^ disp) % 2 ^ 32
	end

	lshift = M.lshift
	function M.tohex(x, n)
		n = n or 8
		local up
		if n <= 0 then
			if n == 0 then
				return ''
			end

			up = true
			n = -n
		end

		x = band(x, 16 ^ n - 1)
		return ('%0' .. n .. (up and 'X' or 'x')):format(x)
	end

	local tohex = M.tohex
	function M.extract(n, field, width)
		width = width or 1
		return band(rshift(n, field), 2 ^ width - 1)
	end

	local extract = M.extract
	function M.replace(n, v, field, width)
		width = width or 1
		local mask1 = 2 ^ width - 1
		v = band(v, mask1)
		local mask = bnot(lshift(mask1, field))
		return band(n, mask) + lshift(v, field)
	end

	local replace = M.replace
	function M.bswap(x)
		local a = band(x, 0xff)
		x = rshift(x, 8)
		local b = band(x, 0xff)
		x = rshift(x, 8)
		local c = band(x, 0xff)
		x = rshift(x, 8)
		local d = band(x, 0xff)
		return lshift(lshift(lshift(a, 8) + b, 8) + c, 8) + d
	end

	local bswap = M.bswap
	function M.rrotate(x, disp)
		disp = disp % 32
		local low = band(x, 2 ^ disp - 1)
		return rshift(x, disp) + lshift(low, 32 - disp)
	end

	local rrotate = M.rrotate
	function M.lrotate(x, disp)
		return rrotate(x, -disp)
	end

	local lrotate = M.lrotate
	M.rol = M.lrotate
	M.ror = M.rrotate
	function M.arshift(x, disp)
		local z = rshift(x, disp)
		if x >= 0x80000000 then
			z = z + lshift(2 ^ disp - 1, 32 - disp)
		end

		return z
	end

	local arshift = M.arshift
	function M.btest(x, y)
		return band(x, y) ~= 0
	end

	M.bit32 = {  }
	local function bit32_bnot(x)
		return (-1 - x) % MOD
	end

	M.bit32.bnot = bit32_bnot
	local function bit32_bxor(a, b, c,...)
		local z
				if b then
			a = a % MOD
			b = b % MOD
			z = bxor(a, b)
			if c then
				z = bit32_bxor(z, c, ...)
			end

			return z
		elseif a then
			return a % MOD
		else
			return 0
		end

	end

	M.bit32.bxor = bit32_bxor
	local function bit32_band(a, b, c,...)
		local z
				if b then
			a = a % MOD
			b = b % MOD
			z = ((a + b) - bxor(a, b)) / 2
			if c then
				z = bit32_band(z, c, ...)
			end

			return z
		elseif a then
			return a % MOD
		else
			return MODM
		end

	end

	M.bit32.band = bit32_band
	local function bit32_bor(a, b, c,...)
		local z
				if b then
			a = a % MOD
			b = b % MOD
			z = MODM - band(MODM - a, MODM - b)
			if c then
				z = bit32_bor(z, c, ...)
			end

			return z
		elseif a then
			return a % MOD
		else
			return 0
		end

	end

	M.bit32.bor = bit32_bor
	function M.bit32.btest(...)
		return bit32_band(...) ~= 0
	end

	function M.bit32.lrotate(x, disp)
		return lrotate(x % MOD, disp)
	end

	function M.bit32.rrotate(x, disp)
		return rrotate(x % MOD, disp)
	end

	function M.bit32.lshift(x, disp)
		if disp > 31 or disp < -31 then
			return 0
		end

		return lshift(x % MOD, disp)
	end

	function M.bit32.rshift(x, disp)
		if disp > 31 or disp < -31 then
			return 0
		end

		return rshift(x % MOD, disp)
	end

	function M.bit32.arshift(x, disp)
		x = x % MOD
		if disp >= 0 then
			if disp > 31 then
				return (x >= 0x80000000) and MODM or 0
			else
				local z = rshift(x, disp)
				if x >= 0x80000000 then
					z = z + lshift(2 ^ disp - 1, 32 - disp)
				end

				return z
			end

		else
			return lshift(x, -disp)
		end

	end

	function M.bit32.extract(x, field,...)
		local width = ... or 1
		if field < 0 or field > 31 or width < 0 or field + width > 32 then
			error 'out of range'
		end

		x = x % MOD
		return extract(x, field, ...)
	end

	function M.bit32.replace(x, v, field,...)
		local width = ... or 1
		if field < 0 or field > 31 or width < 0 or field + width > 32 then
			error 'out of range'
		end

		x = x % MOD
		v = v % MOD
		return replace(x, v, field, ...)
	end

	M.bit = {  }
	function M.bit.tobit(x)
		x = x % MOD
		if x >= 0x80000000 then
			x = x - MOD
		end

		return x
	end

	local bit_tobit = M.bit.tobit
	function M.bit.tohex(x,...)
		return tohex(x % MOD, ...)
	end

	function M.bit.bnot(x)
		return bit_tobit(bnot(x % MOD))
	end

	local function bit_bor(a, b, c,...)
				if c then
			return bit_bor(bit_bor(a, b), c, ...)
		elseif b then
			return bit_tobit(bor(a % MOD, b % MOD))
		else
			return bit_tobit(a)
		end

	end

	M.bit.bor = bit_bor
	local function bit_band(a, b, c,...)
				if c then
			return bit_band(bit_band(a, b), c, ...)
		elseif b then
			return bit_tobit(band(a % MOD, b % MOD))
		else
			return bit_tobit(a)
		end

	end

	M.bit.band = bit_band
	local function bit_bxor(a, b, c,...)
				if c then
			return bit_bxor(bit_bxor(a, b), c, ...)
		elseif b then
			return bit_tobit(bxor(a % MOD, b % MOD))
		else
			return bit_tobit(a)
		end

	end

	M.bit.bxor = bit_bxor
	function M.bit.lshift(x, n)
		return bit_tobit(lshift(x % MOD, n % 32))
	end

	function M.bit.rshift(x, n)
		return bit_tobit(rshift(x % MOD, n % 32))
	end

	function M.bit.arshift(x, n)
		return bit_tobit(arshift(x % MOD, n % 32))
	end

	function M.bit.rol(x, n)
		return bit_tobit(lrotate(x % MOD, n % 32))
	end

	function M.bit.ror(x, n)
		return bit_tobit(rrotate(x % MOD, n % 32))
	end

	function M.bit.bswap(x)
		return bit_tobit(bswap(x % MOD))
	end

	return M
end

