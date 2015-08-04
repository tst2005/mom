#!/bin/sh

_=[[
	for name in luajit lua5.3 lua-5.3 lua5.2 lua-5.2 lua5.1 lua-5.1 lua; do
		: ${LUA:="$(command -v "$name")"}
	done
	if [ -z "$LUA" ]; then
		echo >&2 "ERROR: lua interpretor not found"
		exit 1
	fi
	LUA_PATH='./?.lua;./?/init.lua;./lib/?.lua;./lib/?/init.lua;;'
	exec "$LUA" "$0" "$@"
	exit $?
]]
_=nil
do local sources = {};sources["preloaded"]=([[-- <pack preloaded> --
local _M = {}

local preload = require "package".preload
local enabled = true

local function erase(name)
	if enabled and preload\[name\] then
		preload\[name\] = nil
		return true
	end
	return false
end
local function disable()
	enabled = false
end
local function exists(name)
	return not not preload\[name\]
end
local function list(sep)
	local r = {}
	for k in pairs(preload) do
		r\[#r+1\] = k
	end
	return setmetatable(r, {__tostring = function() return table.concat(r, sep or " ") end})
end

_M.erase = erase
_M.disable = disable
_M.exists = exists
_M.list = list

return _M
]]):gsub('\\([%]%[])','%1')
sources["gro"]=([[-- <pack gro> --

local _M = {}
local loaded = require"package".loaded

--if getmetatable(_G) == nil then
	local lock = {}
	local lock_mt = {__newindex=function() end, __tostring=function() return "locked" end, __metatable=assert(lock)}
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
		return (#name > 30) and (name:sub(1,20).."... ..."..name:sub(-4,-1)) or name
	end

	local ro_mt = getmetatable(_G) or {}
	ro_mt.__newindex = function(_g_, name, value)
		if name == "_" and write_u_once(_G, name, value) then
			return
		end
		if loaded\[name\]==value then
			io.stderr:write("drop global write of module '"..tostring(name).."'\n")
			return -- just drop
		end
		if name == "arg" then
			if writeargonce(_G, name, value) then
				--print("arg:", #value, table.concat(value, ", "))
				return
			end
		end
		--print(_g_, name, value)
		error( ("Global env is read-only. Write of %q denied"):format(cutname(name)), 2)
	end
	ro_mt.__metatable=lock

	setmetatable(_G, ro_mt)
	if getmetatable(_G) ~= lock then
		error("unable to setup global env to read-only", 2)
	end
--end

return {}
]]):gsub('\\([%]%[])','%1')
sources["strict"]=([[-- <pack strict> --
--\[\[--
 Checks uses of undeclared global variables.

 All global variables must be 'declared' through a regular
 assignment (even assigning `nil` will do) in a top-level
 chunk before being used anywhere or assigned to inside a function.

 To use this module, just require it near the start of your program.

 From Lua distribution (`etc/strict.lua`).

 @module std.strict
\]\]

local getinfo, error, rawset, rawget = debug.getinfo, error, rawset, rawget

local mt = getmetatable (_G)
if mt == nil then
  mt = {}
  setmetatable (_G, mt)
end


-- The set of globally declared variables.
mt.__declared = {}


--- What kind of variable declaration is this?
-- @treturn string "C", "Lua" or "main"
local function what ()
  local d = getinfo (3, "S")
  return d and d.what or "C"
end


--- Detect assignment to undeclared global.
-- @function __newindex
-- @tparam table t `_G`
-- @string n name of the variable being declared
-- @param v initial value of the variable
mt.__newindex = function (t, n, v)
  if not mt.__declared\[n\] then
    local w = what ()
    if w ~= "main" and w ~= "C" then
      error ("assignment to undeclared variable '" .. n .. "'", 2)
    end
    mt.__declared\[n\] = true
  end
  rawset (t, n, v)
end


--- Detect dereference of undeclared global.
-- @function __index
-- @tparam table t `_G`
-- @string n name of the variable being dereferenced
mt.__index = function (t, n)
  if not mt.__declared\[n\] and what () ~= "C" then
    error ("variable '" .. n .. "' is not declared", 2)
  end
  return rawget (t, n)
end
]]):gsub('\\([%]%[])','%1')
sources["i"]=([[-- <pack i> --

local _M = {}

_M._VERSION = "0.1.0"
_M._LICENSE = "MIT"

local table_unpack =
	unpack or    -- lua <= 5.1
	table.unpack -- lua >= 5.2

local all = {} -- \[modname\] = modtable
local available = {} -- n = modname


local function softrequire(name)
	local mod
	pcall(function() mod = require(name) end)
	return mod
end

local generic = softrequire("generic") or {}

local function needone(name)
	assert(name)
	if all\[name\] then
		return all\[name\]
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
		r\[#r+1\] = check(needone(name))
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
		return needone(name) or generic\[name\] or false
	end,
--	__index = function(_, k, ...)
--		local m = needone(k)
--		if not m then
--			m = generic\[k\]
--		end
--		return m or false
--	end,
	__newindex = readonly,
})

-- require "i".need "generic"\["class"\]

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
	available\[#available+1\] = name
	all\[name\] = common

	return common
end
function _M:unregister(name)
	--FIXME: code me
end

function _M:available()
	return available
end

return _M

]]):gsub('\\([%]%[])','%1')
sources["generic"]=([[-- <pack generic> --

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

]]):gsub('\\([%]%[])','%1')
sources["secs"]=([[-- <pack secs> --
--\[\[
Copyright (c) 2009-2011 Bart van Strien

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
\]\]

local class_mt = {}

function class_mt:__index(key)
    return self.__baseclass\[key\]
end

local class = setmetatable({ __baseclass = {} }, class_mt)

function class:new(...)
    local c = {}
    c.__baseclass = self
    setmetatable(c, getmetatable(self))
    if c.init then
        c:init(...)
    end
    return c
end

return class
]]):gsub('\\([%]%[])','%1')
sources["secs-featured"]=([[-- <pack secs-featured> --
local secs = require "secs"

local common = {}
function common.class(name, t, parent)
    parent = parent or secs
    t = t or {}
    t.__baseclass = parent
    return setmetatable(t, getmetatable(parent))
end
function common.instance(class, ...)
    return class:new(...)
    --return secs.new(class, ...)
end
common.__BY = "secs"

pcall(function() require("i"):register("secs", common) end)
local _M = {class = assert(common.class), instance = assert(common.instance), __BY = assert(common.__BY)}
--_M.common = common
return _M
]]):gsub('\\([%]%[])','%1')
sources["middleclass"]=([[-- <pack middleclass> --
local middleclass = {
  _VERSION     = 'middleclass v3.0.1',
  _DESCRIPTION = 'Object Orientation for Lua',
  _URL         = 'https://github.com/kikito/middleclass',
  _LICENSE     = \[\[
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
  \]\]
}

local function _setClassDictionariesMetatables(aClass)
  local dict = aClass.__instanceDict
  dict.__index = dict

  local super = aClass.super
  if super then
    local superStatic = super.static
    setmetatable(dict, super.__instanceDict)
    setmetatable(aClass.static, { __index = function(_,k) return dict\[k\] or superStatic\[k\] end })
  else
    setmetatable(aClass.static, { __index = function(_,k) return dict\[k\] end })
  end
end

local function _setClassMetatable(aClass)
  setmetatable(aClass, {
    __tostring = function() return "class " .. aClass.name end,
    __index    = aClass.static,
    __newindex = aClass.__instanceDict,
    __call     = function(self, ...) return self:new(...) end
  })
end

local function _createClass(name, super)
  local aClass = { name = name, super = super, static = {}, __mixins = {}, __instanceDict={} }
  aClass.subclasses = setmetatable({}, {__mode = "k"})

  _setClassDictionariesMetatables(aClass)
  _setClassMetatable(aClass)

  return aClass
end

local function _createLookupMetamethod(aClass, name)
  return function(...)
    local method = aClass.super\[name\]
    assert( type(method)=='function', tostring(aClass) .. " doesn't implement metamethod '" .. name .. "'" )
    return method(...)
  end
end

local function _setClassMetamethods(aClass)
  for _,m in ipairs(aClass.__metamethods) do
    aClass\[m\]= _createLookupMetamethod(aClass, m)
  end
end

local function _setDefaultInitializeMethod(aClass, super)
  aClass.initialize = function(instance, ...)
    return super.initialize(instance, ...)
  end
end

local function _includeMixin(aClass, mixin)
  assert(type(mixin)=='table', "mixin must be a table")
  for name,method in pairs(mixin) do
    if name ~= "included" and name ~= "static" then aClass\[name\] = method end
  end
  if mixin.static then
    for name,method in pairs(mixin.static) do
      aClass.static\[name\] = method
    end
  end
  if type(mixin.included)=="function" then mixin:included(aClass) end
  aClass.__mixins\[mixin\] = true
end

local Object = _createClass("Object", nil)

Object.static.__metamethods = { '__add', '__call', '__concat', '__div', '__ipairs', '__le',
                                '__len', '__lt', '__mod', '__mul', '__pairs', '__pow', '__sub',
                                '__tostring', '__unm'}

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
  self.subclasses\[subclass\] = true
  self:subclassed(subclass)

  return subclass
end

function Object.static:subclassed(other) end

function Object.static:isSubclassOf(other)
  return type(other)                   == 'table' and
         type(self)                    == 'table' and
         type(self.super)              == 'table' and
         ( self.super == other or
           type(self.super.isSubclassOf) == 'function' and
           self.super:isSubclassOf(other)
         )
end

function Object.static:include( ... )
  assert(type(self) == 'table', "Make sure you that you are using 'Class:include' instead of 'Class.include'")
  for _,mixin in ipairs({...}) do _includeMixin(self, mixin) end
  return self
end

function Object.static:includes(mixin)
  return type(mixin)          == 'table' and
         type(self)           == 'table' and
         type(self.__mixins)  == 'table' and
         ( self.__mixins\[mixin\] or
           type(self.super)           == 'table' and
           type(self.super.includes)  == 'function' and
           self.super:includes(mixin)
         )
end

function Object:initialize() end

function Object:__tostring() return "instance of " .. tostring(self.class) end

function Object:isInstanceOf(aClass)
  return type(self)                == 'table' and
         type(self.class)          == 'table' and
         type(aClass)              == 'table' and
         ( aClass == self.class or
           type(aClass.isSubclassOf) == 'function' and
           self.class:isSubclassOf(aClass)
         )
end



function middleclass.class(name, super, ...)
  super = super or Object
  return super:subclass(name, ...)
end

middleclass.Object = Object

setmetatable(middleclass, { __call = function(_, ...) return middleclass.class(...) end })

return middleclass
]]):gsub('\\([%]%[])','%1')
sources["middleclass-featured"]=([[-- <pack middleclass-featured> --
local middleclass = require "middleclass"
middleclass._LICENSE = "MIT"

local common = {}
if type(middleclass.common) == "table"
and type(middleclass.common.class) == "function"
and type(middleclass.common.instannce) == "function" then
	-- already have a classcommons support: use it!
	common = middleclass.common
else
	-- no classcommons support, implement it!

	function common.class(name, klass, superclass)
		local c = middleclass.class(name, superclass)
		klass = klass or {}
		for i, v in pairs(klass) do
			c\[i\] = v
		end

		if klass.init then
			c.initialize = klass.init
		end
		return c
	end

	function common.instance(c, ...)
		return c:new(...)
	end
end
if common.__BY == nil then
	common.__BY = "middleclass"
end

pcall(function() require("classcommons2"):register("middleclass", common) end)
local _M = {class = assert(common.class), instance = assert(common.instance), __BY = assert(common.__BY)}
--_M.common = common
return _M
]]):gsub('\\([%]%[])','%1')
sources["30log"]=([[-- <pack 30log> --
local assert, pairs, type, tostring, setmetatable = assert, pairs, type, tostring, setmetatable
local baseMt, _instances, _classes, class = {}, setmetatable({},{__mode='k'}), setmetatable({},{__mode='k'})
local function deep_copy(t, dest, aType)
  local t, r = t or {}, dest or {}
  for k,v in pairs(t) do
    if aType and type(v)==aType then r\[k\] = v elseif not aType then
      if type(v) == 'table' and k ~= "__index" then r\[k\] = deep_copy(v) else r\[k\] = v end
    end
  end; return r
end
local function instantiate(self,...)
  assert(_classes\[self\],'new() should be called from a class.')
  local instance = deep_copy(self) ; _instances\[instance\] = tostring(instance); setmetatable(instance,self)
  if self.__init then if type(self.__init) == 'table' then deep_copy(self.__init, instance) else self.__init(instance, ...) end; end; return instance
end
local function extends(self,extra_params)
  local heir = {}; _classes\[heir\] = tostring(heir); deep_copy(extra_params, deep_copy(self, heir));
  heir.__index, heir.super = heir, self; return setmetatable(heir,self)
end
baseMt = { __call = function (self,...) return self:new(...) end, __tostring = function(self,...)
  if _instances\[self\] then return ('object(of %s):<%s>'):format((rawget(getmetatable(self),'__name') or '?'), _instances\[self\]) end
  return _classes\[self\] and ('class(%s):<%s>'):format((rawget(self,'__name') or '?'),_classes\[self\]) or self
end}
local class = function(attr)
  local c = deep_copy(attr) ; _classes\[c\] = tostring(c);
  c.include = function(self,include) assert(_classes\[self\], 'Mixins can only be used on classes.'); return deep_copy(include, self, 'function') end
  c.new, c.extends, c.__index, c.__call, c.__tostring = instantiate, extends, c, baseMt.__call, baseMt.__tostring;
  c.is = function(self, kind) local super; while true do super = getmetatable(super or self) ; if super == kind or super == nil then break end ; end;
  return kind and (super == kind) end; return setmetatable(c,baseMt)
end; return class
]]):gsub('\\([%]%[])','%1')
sources["30log-featured"]=([[-- <pack 30log-featured> --
local class = require "30log"

local common = {}
common.class = function(name, prototype, parent)
        local klass = class():extends(parent):extends(prototype)
        klass.__init = (prototype or {}).init or (parent or {}).init
        klass.__name = name
        return klass
end
common.instance = function(class, ...)
        return class:new(...)
end
common.__BY = "30log"

pcall(function() require("i"):register("30log", common) end)

local _M = {class = assert(common.class), instance = assert(common.instance), __BY = assert(common.__BY)}
--_M.common = common
return _M
]]):gsub('\\([%]%[])','%1')
sources["compat_env"]=([[-- <pack compat_env> --
--\[\[
  compat_env - see README for details.
  (c) 2012 David Manura.  Licensed under Lua 5.1/5.2 terms (MIT license).
--\]\]

local M = {_TYPE='module', _NAME='compat_env', _VERSION='0.2.2.20120406'}

local function check_chunk_type(s, mode)
  local nmode = mode or 'bt' 
  local is_binary = s and #s > 0 and s:byte(1) == 27
  if is_binary and not nmode:match'b' then
    return nil, ("attempt to load a binary chunk (mode is '%s')"):format(mode)
  elseif not is_binary and not nmode:match't' then
    return nil, ("attempt to load a text chunk (mode is '%s')"):format(mode)
  end
  return true
end

local IS_52_LOAD = pcall(load, '')
if IS_52_LOAD then
  M.load     = _G.load
  M.loadfile = _G.loadfile
else
  -- 5.2 style `load` implemented in 5.1
  function M.load(ld, source, mode, env)
    local f
    if type(ld) == 'string' then
      local s = ld
      local ok, err = check_chunk_type(s, mode)
      if not ok then return ok, err end
      local err; f, err = loadstring(s, source)
      if not f then return f, err end
    elseif type(ld) == 'function' then
      local ld2 = ld
      if (mode or 'bt') ~= 'bt' then
        local first = ld()
        local ok, err = check_chunk_type(first, mode)
        if not ok then return ok, err end
        ld2 = function()
          if first then
            local chunk=first; first=nil; return chunk
          else return ld() end
        end
      end
      local err; f, err = load(ld2, source); if not f then return f, err end
    else
      error(("bad argument #1 to 'load' (function expected, got %s)")
            :format(type(ld)), 2)
    end
    if env then setfenv(f, env) end
    return f
  end

  -- 5.2 style `loadfile` implemented in 5.1
  function M.loadfile(filename, mode, env)
    if (mode or 'bt') ~= 'bt' then
      local ioerr
      local fh, err = io.open(filename, 'rb'); if not fh then return fh,err end
      local function ld()
        local chunk; chunk,ioerr = fh:read(4096); return chunk
      end
      local f, err = M.load(ld, filename and '@'..filename, mode, env)
      fh:close()
      if not f then return f, err end
      if ioerr then return nil, ioerr end
      return f
    else
      local f, err = loadfile(filename); if not f then return f, err end
      if env then setfenv(f, env) end
      return f
    end
  end
end

if _G.setfenv then -- Lua 5.1
  M.setfenv = _G.setfenv
  M.getfenv = _G.getfenv
else -- >= Lua 5.2
  local debug = require "debug"
  -- helper function for `getfenv`/`setfenv`
  local function envlookup(f)
    local name, val
    local up = 0
    local unknown
    repeat
      up=up+1; name, val = debug.getupvalue(f, up)
      if name == '' then unknown = true end
    until name == '_ENV' or name == nil
    if name ~= '_ENV' then
      up = nil
      if unknown then
        error("upvalues not readable in Lua 5.2 when debug info missing", 3)
      end
    end
    return (name == '_ENV') and up, val, unknown
  end

  -- helper function for `getfenv`/`setfenv`
  local function envhelper(f, name)
    if type(f) == 'number' then
      if f < 0 then
        error(("bad argument #1 to '%s' (level must be non-negative)")
              :format(name), 3)
      elseif f < 1 then
        error("thread environments unsupported in Lua 5.2", 3) --\[*\]
      end
      f = debug.getinfo(f+2, 'f').func
    elseif type(f) ~= 'function' then
      error(("bad argument #1 to '%s' (number expected, got %s)")
            :format(type(name, f)), 2)
    end
    return f
  end
  -- \[*\] might simulate with table keyed by coroutine.running()
  
  -- 5.1 style `setfenv` implemented in 5.2
  function M.setfenv(f, t)
    local f = envhelper(f, 'setfenv')
    local up, val, unknown = envlookup(f)
    if up then
      debug.upvaluejoin(f, up, function() return up end, 1) --unique upval\[*\]
      debug.setupvalue(f, up, t)
    else
      local what = debug.getinfo(f, 'S').what
      if what ~= 'Lua' and what ~= 'main' then -- not Lua func
        error("'setfenv' cannot change environment of given object", 2)
      end -- else ignore no _ENV upvalue (warning: incompatible with 5.1)
    end
    return f  -- invariant: original f ~= 0
  end
  -- \[*\] http://lua-users.org/lists/lua-l/2010-06/msg00313.html

  -- 5.1 style `getfenv` implemented in 5.2
  function M.getfenv(f)
    if f == 0 or f == nil then return _G end -- simulated behavior
    local f = envhelper(f, 'setfenv')
    local up, val = envlookup(f)
    if not up then return _G end -- simulated behavior \[**\]
    return val
  end
  -- \[**\] possible reasons: no _ENV upvalue, C function
end


return M
]]):gsub('\\([%]%[])','%1')
sources["hump.class"]=([[-- <pack hump.class> --
--\[\[
Copyright (c) 2010-2013 Matthias Richter

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

Except as contained in this notice, the name(s) of the above copyright holders
shall not be used in advertising or otherwise to promote the sale, use or
other dealings in this Software without prior written authorization.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
\]\]--

local function include_helper(to, from, seen)
	if from == nil then
		return to
	elseif type(from) ~= 'table' then
		return from
	elseif seen\[from\] then
		return seen\[from\]
	end

	seen\[from\] = to
	for k,v in pairs(from) do
		k = include_helper({}, k, seen) -- keys might also be tables
		if to\[k\] == nil then
			to\[k\] = include_helper({}, v, seen)
		end
	end
	return to
end

-- deeply copies `other' into `class'. keys in `other' that are already
-- defined in `class' are omitted
local function include(class, other)
	return include_helper(class, other, {})
end

-- returns a deep copy of `other'
local function clone(other)
	return setmetatable(include({}, other), getmetatable(other))
end

local function new(class)
	-- mixins
	local inc = class.__includes or {}
	if getmetatable(inc) then inc = {inc} end

	for _, other in ipairs(inc) do
		if type(other) == "string" then
			other = _G\[other\]
		end
		include(class, other)
	end

	-- class implementation
	class.__index = class
	class.init    = class.init    or class\[1\] or function() end
	class.include = class.include or include
	class.clone   = class.clone   or clone

	-- constructor call
	return setmetatable(class, {__call = function(c, ...)
		local o = setmetatable({}, c)
		o:init(...)
		return o
	end})
end

-- interface for cross class-system compatibility (see https://github.com/bartbes/Class-Commons).
--if class_commons ~= false and not common then
--	local common = {}
--	function common.class(name, prototype, parent)
--		return new{__includes = {prototype, parent}}
--	end
--	function common.instance(class, ...)
--		return class(...)
--	end
--end


-- the module
return setmetatable({new = new, include = include, clone = clone},
	{__call = function(_,...) return new(...) end})
]]):gsub('\\([%]%[])','%1')
sources["hump.class-featured"]=([[-- <pack hump.class-featured> --
--error("hump.class modify the global env ! FIXIT")

-- interface for cross class-system compatibility (see https://github.com/bartbes/Class-Commons).

local _M = {}
local humpclass = require "hump.class"
local new = assert(humpclass.new)

local common = {}
function common.class(name, prototype, parent)
	return new{__includes = {prototype, parent}}
end
function common.instance(class, ...)
        return class(...)
end
common.__BY = "hump.class"
pcall(function() require("i"):register("hump.class", common) end)
return common
]]):gsub('\\([%]%[])','%1')
sources["bit.numberlua"]=([[-- <pack bit.numberlua> --
--\[\[

LUA MODULE

  bit.numberlua - Bitwise operations implemented in pure Lua as numbers,
    with Lua 5.2 'bit32' and (LuaJIT) LuaBitOp 'bit' compatibility interfaces.

SYNOPSIS

  local bit = require 'bit.numberlua'
  print(bit.band(0xff00ff00, 0x00ff00ff)) --> 0xffffffff
  
  -- Interface providing strong Lua 5.2 'bit32' compatibility
  local bit32 = require 'bit.numberlua'.bit32
  assert(bit32.band(-1) == 0xffffffff)
  
  -- Interface providing strong (LuaJIT) LuaBitOp 'bit' compatibility
  local bit = require 'bit.numberlua'.bit
  assert(bit.tobit(0xffffffff) == -1)
  
DESCRIPTION
  
  This library implements bitwise operations entirely in Lua.
  This module is typically intended if for some reasons you don't want
  to or cannot  install a popular C based bit library like BitOp 'bit' \[1\]
  (which comes pre-installed with LuaJIT) or 'bit32' (which comes
  pre-installed with Lua 5.2) but want a similar interface.
  
  This modules represents bit arrays as non-negative Lua numbers. \[1\]
  It can represent 32-bit bit arrays when Lua is compiled
  with lua_Number as double-precision IEEE 754 floating point.

  The module is nearly the most efficient it can be but may be a few times
  slower than the C based bit libraries and is orders or magnitude
  slower than LuaJIT bit operations, which compile to native code.  Therefore,
  this library is inferior in performane to the other modules.

  The `xor` function in this module is based partly on Roberto Ierusalimschy's
  post in http://lua-users.org/lists/lua-l/2002-09/msg00134.html .
  
  The included BIT.bit32 and BIT.bit sublibraries aims to provide 100%
  compatibility with the Lua 5.2 "bit32" and (LuaJIT) LuaBitOp "bit" library.
  This compatbility is at the cost of some efficiency since inputted
  numbers are normalized and more general forms (e.g. multi-argument
  bitwise operators) are supported.
  
STATUS

  WARNING: Not all corner cases have been tested and documented.
  Some attempt was made to make these similar to the Lua 5.2 \[2\]
  and LuaJit BitOp \[3\] libraries, but this is not fully tested and there
  are currently some differences.  Addressing these differences may
  be improved in the future but it is not yet fully determined how to
  resolve these differences.
  
  The BIT.bit32 library passes the Lua 5.2 test suite (bitwise.lua)
  http://www.lua.org/tests/5.2/ .  The BIT.bit library passes the LuaBitOp
  test suite (bittest.lua).  However, these have not been tested on
  platforms with Lua compiled with 32-bit integer numbers.

API

  BIT.tobit(x) --> z
  
    Similar to function in BitOp.
    
  BIT.tohex(x, n)
  
    Similar to function in BitOp.
  
  BIT.band(x, y) --> z
  
    Similar to function in Lua 5.2 and BitOp but requires two arguments.
  
  BIT.bor(x, y) --> z
  
    Similar to function in Lua 5.2 and BitOp but requires two arguments.

  BIT.bxor(x, y) --> z
  
    Similar to function in Lua 5.2 and BitOp but requires two arguments.
  
  BIT.bnot(x) --> z
  
    Similar to function in Lua 5.2 and BitOp.

  BIT.lshift(x, disp) --> z
  
    Similar to function in Lua 5.2 (warning: BitOp uses unsigned lower 5 bits of shift),
  
  BIT.rshift(x, disp) --> z
  
    Similar to function in Lua 5.2 (warning: BitOp uses unsigned lower 5 bits of shift),

  BIT.extract(x, field \[, width\]) --> z
  
    Similar to function in Lua 5.2.
  
  BIT.replace(x, v, field, width) --> z
  
    Similar to function in Lua 5.2.
  
  BIT.bswap(x) --> z
  
    Similar to function in Lua 5.2.

  BIT.rrotate(x, disp) --> z
  BIT.ror(x, disp) --> z
  
    Similar to function in Lua 5.2 and BitOp.

  BIT.lrotate(x, disp) --> z
  BIT.rol(x, disp) --> z

    Similar to function in Lua 5.2 and BitOp.
  
  BIT.arshift
  
    Similar to function in Lua 5.2 and BitOp.
    
  BIT.btest
  
    Similar to function in Lua 5.2 with requires two arguments.

  BIT.bit32
  
    This table contains functions that aim to provide 100% compatibility
    with the Lua 5.2 "bit32" library.
    
    bit32.arshift (x, disp) --> z
    bit32.band (...) --> z
    bit32.bnot (x) --> z
    bit32.bor (...) --> z
    bit32.btest (...) --> true | false
    bit32.bxor (...) --> z
    bit32.extract (x, field \[, width\]) --> z
    bit32.replace (x, v, field \[, width\]) --> z
    bit32.lrotate (x, disp) --> z
    bit32.lshift (x, disp) --> z
    bit32.rrotate (x, disp) --> z
    bit32.rshift (x, disp) --> z

  BIT.bit
  
    This table contains functions that aim to provide 100% compatibility
    with the LuaBitOp "bit" library (from LuaJIT).
    
    bit.tobit(x) --> y
    bit.tohex(x \[,n\]) --> y
    bit.bnot(x) --> y
    bit.bor(x1 \[,x2...\]) --> y
    bit.band(x1 \[,x2...\]) --> y
    bit.bxor(x1 \[,x2...\]) --> y
    bit.lshift(x, n) --> y
    bit.rshift(x, n) --> y
    bit.arshift(x, n) --> y
    bit.rol(x, n) --> y
    bit.ror(x, n) --> y
    bit.bswap(x) --> y
    
DEPENDENCIES

  None (other than Lua 5.1 or 5.2).
    
DOWNLOAD/INSTALLATION

  If using LuaRocks:
    luarocks install lua-bit-numberlua

  Otherwise, download <https://github.com/davidm/lua-bit-numberlua/zipball/master>.
  Alternately, if using git:
    git clone git://github.com/davidm/lua-bit-numberlua.git
    cd lua-bit-numberlua
  Optionally unpack:
    ./util.mk
  or unpack and install in LuaRocks:
    ./util.mk install 

REFERENCES

  \[1\] http://lua-users.org/wiki/FloatingPoint
  \[2\] http://www.lua.org/manual/5.2/
  \[3\] http://bitop.luajit.org/
  
LICENSE

  (c) 2008-2011 David Manura.  Licensed under the same terms as Lua (MIT).

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
  (end license)

--\]\]

local M = {_TYPE='module', _NAME='bit.numberlua', _VERSION='0.3.1.20120131'}

local floor = math.floor

local MOD = 2^32
local MODM = MOD-1

local function memoize(f)
  local mt = {}
  local t = setmetatable({}, mt)
  function mt:__index(k)
    local v = f(k); t\[k\] = v
    return v
  end
  return t
end

local function make_bitop_uncached(t, m)
  local function bitop(a, b)
    local res,p = 0,1
    while a ~= 0 and b ~= 0 do
      local am, bm = a%m, b%m
      res = res + t\[am\]\[bm\]*p
      a = (a - am) / m
      b = (b - bm) / m
      p = p*m
    end
    res = res + (a+b)*p
    return res
  end
  return bitop
end

local function make_bitop(t)
  local op1 = make_bitop_uncached(t,2^1)
  local op2 = memoize(function(a)
    return memoize(function(b)
      return op1(a, b)
    end)
  end)
  return make_bitop_uncached(op2, 2^(t.n or 1))
end

-- ok?  probably not if running on a 32-bit int Lua number type platform
function M.tobit(x)
  return x % 2^32
end

M.bxor = make_bitop {\[0\]={\[0\]=0,\[1\]=1},\[1\]={\[0\]=1,\[1\]=0}, n=4}
local bxor = M.bxor

function M.bnot(a)   return MODM - a end
local bnot = M.bnot

function M.band(a,b) return ((a+b) - bxor(a,b))/2 end
local band = M.band

function M.bor(a,b)  return MODM - band(MODM - a, MODM - b) end
local bor = M.bor

local lshift, rshift -- forward declare

function M.rshift(a,disp) -- Lua5.2 insipred
  if disp < 0 then return lshift(a,-disp) end
  return floor(a % 2^32 / 2^disp)
end
rshift = M.rshift

function M.lshift(a,disp) -- Lua5.2 inspired
  if disp < 0 then return rshift(a,-disp) end 
  return (a * 2^disp) % 2^32
end
lshift = M.lshift

function M.tohex(x, n) -- BitOp style
  n = n or 8
  local up
  if n <= 0 then
    if n == 0 then return '' end
    up = true
    n = - n
  end
  x = band(x, 16^n-1)
  return ('%0'..n..(up and 'X' or 'x')):format(x)
end
local tohex = M.tohex

function M.extract(n, field, width) -- Lua5.2 inspired
  width = width or 1
  return band(rshift(n, field), 2^width-1)
end
local extract = M.extract

function M.replace(n, v, field, width) -- Lua5.2 inspired
  width = width or 1
  local mask1 = 2^width-1
  v = band(v, mask1) -- required by spec?
  local mask = bnot(lshift(mask1, field))
  return band(n, mask) + lshift(v, field)
end
local replace = M.replace

function M.bswap(x)  -- BitOp style
  local a = band(x, 0xff); x = rshift(x, 8)
  local b = band(x, 0xff); x = rshift(x, 8)
  local c = band(x, 0xff); x = rshift(x, 8)
  local d = band(x, 0xff)
  return lshift(lshift(lshift(a, 8) + b, 8) + c, 8) + d
end
local bswap = M.bswap

function M.rrotate(x, disp)  -- Lua5.2 inspired
  disp = disp % 32
  local low = band(x, 2^disp-1)
  return rshift(x, disp) + lshift(low, 32-disp)
end
local rrotate = M.rrotate

function M.lrotate(x, disp)  -- Lua5.2 inspired
  return rrotate(x, -disp)
end
local lrotate = M.lrotate

M.rol = M.lrotate  -- LuaOp inspired
M.ror = M.rrotate  -- LuaOp insipred


function M.arshift(x, disp) -- Lua5.2 inspired
  local z = rshift(x, disp)
  if x >= 0x80000000 then z = z + lshift(2^disp-1, 32-disp) end
  return z
end
local arshift = M.arshift

function M.btest(x, y) -- Lua5.2 inspired
  return band(x, y) ~= 0
end

--
-- Start Lua 5.2 "bit32" compat section.
--

M.bit32 = {} -- Lua 5.2 'bit32' compatibility


local function bit32_bnot(x)
  return (-1 - x) % MOD
end
M.bit32.bnot = bit32_bnot

local function bit32_bxor(a, b, c, ...)
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

local function bit32_band(a, b, c, ...)
  local z
  if b then
    a = a % MOD
    b = b % MOD
    z = ((a+b) - bxor(a,b)) / 2
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

local function bit32_bor(a, b, c, ...)
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

function M.bit32.lshift(x,disp)
  if disp > 31 or disp < -31 then return 0 end
  return lshift(x % MOD, disp)
end

function M.bit32.rshift(x,disp)
  if disp > 31 or disp < -31 then return 0 end
  return rshift(x % MOD, disp)
end

function M.bit32.arshift(x,disp)
  x = x % MOD
  if disp >= 0 then
    if disp > 31 then
      return (x >= 0x80000000) and MODM or 0
    else
      local z = rshift(x, disp)
      if x >= 0x80000000 then z = z + lshift(2^disp-1, 32-disp) end
      return z
    end
  else
    return lshift(x, -disp)
  end
end

function M.bit32.extract(x, field, ...)
  local width = ... or 1
  if field < 0 or field > 31 or width < 0 or field+width > 32 then error 'out of range' end
  x = x % MOD
  return extract(x, field, ...)
end

function M.bit32.replace(x, v, field, ...)
  local width = ... or 1
  if field < 0 or field > 31 or width < 0 or field+width > 32 then error 'out of range' end
  x = x % MOD
  v = v % MOD
  return replace(x, v, field, ...)
end


--
-- Start LuaBitOp "bit" compat section.
--

M.bit = {} -- LuaBitOp "bit" compatibility

function M.bit.tobit(x)
  x = x % MOD
  if x >= 0x80000000 then x = x - MOD end
  return x
end
local bit_tobit = M.bit.tobit

function M.bit.tohex(x, ...)
  return tohex(x % MOD, ...)
end

function M.bit.bnot(x)
  return bit_tobit(bnot(x % MOD))
end

local function bit_bor(a, b, c, ...)
  if c then
    return bit_bor(bit_bor(a, b), c, ...)
  elseif b then
    return bit_tobit(bor(a % MOD, b % MOD))
  else
    return bit_tobit(a)
  end
end
M.bit.bor = bit_bor

local function bit_band(a, b, c, ...)
  if c then
    return bit_band(bit_band(a, b), c, ...)
  elseif b then
    return bit_tobit(band(a % MOD, b % MOD))
  else
    return bit_tobit(a)
  end
end
M.bit.band = bit_band

local function bit_bxor(a, b, c, ...)
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
]]):gsub('\\([%]%[])','%1')
sources["lunajson"]=([[-- <pack lunajson> --
require("package").preload\["lunajson._str_lib"\] = function(...)-- <pack lunajson._str_lib> --
local inf = math.huge
local byte, char, sub = string.byte, string.char, string.sub
local setmetatable = setmetatable
local floor = math.floor

local _ENV = nil

local hextbl = {
	0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9, inf, inf, inf, inf, inf, inf,
	inf, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF, inf, inf, inf, inf, inf, inf, inf, inf, inf,
	inf, inf, inf, inf, inf, inf, inf, inf, inf, inf, inf, inf, inf, inf, inf, inf,
	inf, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF, inf, inf, inf, inf, inf, inf, inf, inf, inf,
}
hextbl.__index = function()
	return inf
end
setmetatable(hextbl, hextbl)

return function(myerror)
	local escapetbl = {
		\['"'\]  = '"',
		\['\\'\] = '\\',
		\['/'\]  = '/',
		\['b'\]  = '\b',
		\['f'\]  = '\f',
		\['n'\]  = '\n',
		\['r'\]  = '\r',
		\['t'\]  = '\t'
	}
	escapetbl.__index = function()
		myerror("invalid escape sequence")
	end
	setmetatable(escapetbl, escapetbl)

	local surrogateprev = 0

	local function subst(ch, rest)
		-- 0.000003814697265625 = 2^-18
		-- 0.000244140625 = 2^-12
		-- 0.015625 = 2^-6
		local u8
		if ch == 'u' then
			local c1, c2, c3, c4 = byte(rest, 1, 4)
			local ucode = hextbl\[c1-47\] * 0x1000 + hextbl\[c2-47\] * 0x100 + hextbl\[c3-47\] * 0x10 + hextbl\[c4-47\]
			if ucode == inf then
				myerror("invalid unicode charcode")
			end
			rest = sub(rest, 5)
			if ucode < 0x80 then -- 1byte
				u8 = char(ucode)
			elseif ucode < 0x800 then -- 2byte
				u8 = char(0xC0 + floor(ucode * 0.015625), 0x80 + ucode % 0x40)
			elseif ucode < 0xD800 or 0xE000 <= ucode then -- 3byte
				u8 = char(0xE0 + floor(ucode * 0.000244140625), 0x80 + floor(ucode * 0.015625) % 0x40, 0x80 + ucode % 0x40)
			elseif 0xD800 <= ucode and ucode < 0xDC00 then -- surrogate pair 1st
				if surrogateprev == 0 then
					surrogateprev = ucode
					if rest == '' then
						return ''
					end
				end
			else -- surrogate pair 2nd
				if surrogateprev == 0 then
					surrogateprev = 1
				else
					ucode = 0x10000 + (surrogateprev - 0xD800) * 0x400 + (ucode - 0xDC00)
					surrogateprev = 0
					u8 = char(0xF0 + floor(ucode * 0.000003814697265625), 0x80 + floor(ucode * 0.000244140625) % 0x40, 0x80 + floor(ucode * 0.015625) % 0x40, 0x80 + ucode % 0x40)
				end
			end
		end
		if surrogateprev ~= 0 then
			myerror("invalid surrogate pair")
		end
		return (u8 or escapetbl\[ch\]) .. rest
	end

	local function surrogateok()
		return surrogateprev == 0
	end

	return {
		subst = subst,
		surrogateok = surrogateok
	}
end
end;
do local loadstring=loadstring;(function(name, rawcode)require"package".preload\[name\]=function(...)return assert(loadstring(rawcode))(...)end;end)("lunajson._str_lib_lua53", (\[\[
-- <pack lunajson._str_lib_lua53> --
local inf = math.huge
local byte, char, sub = string.byte, string.char, string.sub
local setmetatable = setmetatable

local _ENV = nil

local hextbl = {
	0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9, inf, inf, inf, inf, inf, inf,
	inf, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF, inf, inf, inf, inf, inf, inf, inf, inf, inf,
	inf, inf, inf, inf, inf, inf, inf, inf, inf, inf, inf, inf, inf, inf, inf, inf,
	inf, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF, inf, inf, inf, inf, inf, inf, inf, inf, inf,
}
hextbl.__index = function()
	return inf
end
setmetatable(hextbl, hextbl)

return function(myerror)
	local escapetbl = {
		\\['"'\\]  = '"',
		\\['\\'\\] = '\\',
		\\['/'\\]  = '/',
		\\['b'\\]  = '\b',
		\\['f'\\]  = '\f',
		\\['n'\\]  = '\n',
		\\['r'\\]  = '\r',
		\\['t'\\]  = '\t'
	}
	escapetbl.__index = function()
		myerror("invalid escape sequence")
	end
	setmetatable(escapetbl, escapetbl)

	local surrogateprev = 0

	local function subst(ch, rest)
		local u8
		if ch == 'u' then
			local c1, c2, c3, c4 = byte(rest, 1, 4)
			-- multiplications should not be lshift since cn may be inf
			local ucode = hextbl\\[c1-47\\] * 0x1000 + hextbl\\[c2-47\\] * 0x100 + hextbl\\[c3-47\\] * 0x10 + hextbl\\[c4-47\\]
			if ucode == inf then
				myerror("invalid unicode charcode")
			end
			rest = sub(rest, 5)
			if ucode < 0x80 then -- 1byte
				u8 = char(ucode)
			elseif ucode < 0x800 then -- 2byte
				u8 = char(0xC0 + (ucode >> 6), 0x80 + (ucode & 0x3F))
			elseif ucode < 0xD800 or 0xE000 <= ucode then -- 3byte
				u8 = char(0xE0 + (ucode >> 12), 0x80 + (ucode >> 6 & 0x3F), 0x80 + (ucode & 0x3F))
			elseif 0xD800 <= ucode and ucode < 0xDC00 then -- surrogate pair 1st
				if surrogateprev == 0 then
					surrogateprev = ucode
					if rest == '' then
						return ''
					end
				end
			else -- surrogate pair 2nd
				if surrogateprev == 0 then
					surrogateprev = 1
				else
					ucode = 0x10000 + (surrogateprev - 0xD800 << 10) + (ucode - 0xDC00)
					surrogateprev = 0
					u8 = char(0xF0 + (ucode >> 18), 0x80 + (ucode >> 12 & 0x3F), 0x80 + (ucode >> 6 & 0x3F), 0x80 + (ucode & 0x3F))
				end
			end
		end
		if surrogateprev ~= 0 then
			myerror("invalid surrogate pair")
		end
		return (u8 or escapetbl\\[ch\\]) .. rest
	end

	local function surrogateok()
		return surrogateprev == 0
	end

	return {
		subst = subst,
		surrogateok = surrogateok
	}
end
\]\]):gsub('\\(\[%\]%\[\])','%1'))end
require("package").preload\["lunajson.sax"\] = function(...)-- <pack lunajson.sax> --
local error = error
local byte, char, find, gsub, match, sub =
	string.byte, string.char, string.find, string.gsub, string.match, string.sub
local tonumber = tonumber
local tostring, type, unpack = tonumber, type, table.unpack or unpack

local genstrlib
if _VERSION == "Lua 5.3" then
	genstrlib = require 'lunajson._str_lib_lua53'
else
	genstrlib = require 'lunajson._str_lib'
end

local _ENV = nil

local function nop() end

local function newparser(src, saxtbl)
	local json, jsonnxt
	local jsonlen, pos, acc = 0, 1, 0

	local dispatcher
	-- it is temporary for dispatcher\[c\] and
	-- dummy for 1st return value of find
	local f

	-- initialize
	if type(src) == 'string' then
		json = src
		jsonlen = #json
		jsonnxt = function()
			json = ''
			jsonlen = 0
			jsonnxt = nop
		end
	else
		jsonnxt = function()
			acc = acc + jsonlen
			pos = 1
			repeat
				json = src()
				if not json then
					json = ''
					jsonlen = 0
					jsonnxt = nop
					return
				end
				jsonlen = #json
			until jsonlen > 0
		end
		jsonnxt()
	end

	local sax_startobject = saxtbl.startobject or nop
	local sax_key = saxtbl.key or nop
	local sax_endobject = saxtbl.endobject or nop
	local sax_startarray = saxtbl.startarray or nop
	local sax_endarray = saxtbl.endarray or nop
	local sax_string = saxtbl.string or nop
	local sax_number = saxtbl.number or nop
	local sax_boolean = saxtbl.boolean or nop
	local sax_null = saxtbl.null or nop

	-- helper
	local function tryc()
		local c = byte(json, pos)
		if not c then
			jsonnxt()
			c = byte(json, pos)
		end
		return c
	end

	local function parseerror(errmsg)
		error("parse error at " .. acc + pos .. ": " .. errmsg)
	end

	local function tellc()
		return tryc() or parseerror("unexpected termination")
	end

	local function spaces()
		while true do
			f, pos = find(json, '^\[ \n\r\t\]*', pos)
			if pos ~= jsonlen then
				pos = pos+1
				return
			end
			if jsonlen == 0 then
				parseerror("unexpected termination")
			end
			jsonnxt()
		end
	end

	-- parse error
	local function f_err()
		parseerror('invalid value')
	end

	-- parse constants
	local function generic_constant(target, targetlen, ret, sax_f)
		for i = 1, targetlen do
			local c = tellc()
			if byte(target, i) ~= c then
				parseerror("invalid char")
			end
			pos = pos+1
		end
		return sax_f(ret)
	end

	local function f_nul()
		if sub(json, pos, pos+2) == 'ull' then
			pos = pos+3
			return sax_null(nil)
		end
		return generic_constant('ull', 3, nil, sax_null)
	end

	local function f_fls()
		if sub(json, pos, pos+3) == 'alse' then
			pos = pos+4
			return sax_boolean(false)
		end
		return generic_constant('alse', 4, false, sax_boolean)
	end

	local function f_tru()
		if sub(json, pos, pos+2) == 'rue' then
			pos = pos+3
			return sax_boolean(true)
		end
		return generic_constant('rue', 3, true, sax_boolean)
	end

	-- parse numbers
	local radixmark = match(tostring(0.5), '\[^0-9\]')
	local fixedtonumber = tonumber
	if radixmark ~= '.' then
		if find(radixmark, '%W') then
			radixmark = '%' .. radixmark
		end
		fixedtonumber = function(s)
			return tonumber(gsub(s, '.', radixmark))
		end
	end

	local function generic_number(mns)
		local buf = {}
		local i = 1

		local c = byte(json, pos)
		pos = pos+1
		if c == 0x30 then
			buf\[i\] = c
			i = i+1
			c = tryc()
			pos = pos+1
			if c and 0x30 <= c and c < 0x3A then
				parseerror('invalid number')
			end
		else
			repeat
				buf\[i\] = c
				i = i+1
				c = tryc()
				pos = pos+1
			until not (c and 0x30 <= c and c < 0x3A)
		end
		if c == 0x2E then
			local oldi = i
			repeat
				buf\[i\] = c
				i = i+1
				c = tryc()
				pos = pos+1
			until not (c and 0x30 <= c and c < 0x3A)
			if oldi+1 == i then
				parseerror('invalid number')
			end
		end
		if c == 0x45 or c == 0x65 then
			repeat
				buf\[i\] = c
				i = i+1
				c = tryc()
				pos = pos+1
			until not (c and ((0x30 <= c and c < 0x3A) or (c == 0x2B or c == 0x2D)))
		end
		pos = pos-1

		local num = char(unpack(buf))
		num = fixedtonumber(num)
		if num then
			if mns then
				num = -num
			end
			return sax_number(num)
		end
		parseerror('invalid number')
	end

	local function f_zro(mns)
		local c = byte(json, pos)

		if c == 0x2E then
			local num = match(json, '^.\[0-9\]*', pos) -- skip 0
			local pos2 = #num
			if pos2 ~= 1 then
				pos2 = pos + pos2
				c = byte(json, pos2)
				if c == 0x45 or c == 0x65 then
					num = match(json, '^\[^eE\]*\[eE\]\[-+0-9\]*', pos)
					pos2 = pos + #num
				end
				num = fixedtonumber(num)
				if num and pos2 <= jsonlen then
					pos = pos2
					if mns then
						num = 0.0-num
					else
						num = num-0.0
					end
					return sax_number(num)
				end
			end
			pos = pos-1
			return generic_number(mns)
		end

		if c ~= 0x2C and c ~= 0x5D and c ~= 0x7D then -- check e or E when unusual char is detected
			local pos2 = pos
			pos = pos-1
			if not c then
				return generic_number(mns)
			end
			if 0x30 <= c and c < 0x3A then
				parseerror('invalid number')
			end
			local num = match(json, '^.\[eE\]\[-+0-9\]*', pos)
			if num then
				pos2 = pos + #num
				num = fixedtonumber(num)
				if not num or pos2 > jsonlen then
					return generic_number(mns)
				end
			end
			pos = pos2
		end

		if not mns then
			return sax_number(0.0)
		end
		return sax_number(-0.0)
	end

	local function f_num(mns)
		pos = pos-1
		local num = match(json, '^\[0-9\]+%.?\[0-9\]*', pos)
		local c = byte(num, -1)
		if c == 0x2E then -- check that num is not ended by comma
			return generic_number(mns)
		end

		local pos2 = pos + #num
		c = byte(json, pos2)
		if c == 0x45 or c == 0x65 then -- e or E?
			num = match(json, '^\[^eE\]*\[eE\]\[-+0-9\]*', pos)
			pos2 = pos + #num
			num = fixedtonumber(num)
			if not num then
				return generic_number(mns)
			end
		else
			num = fixedtonumber(num)
		end
		if pos2 > jsonlen then
			return generic_number(mns)
		end
		pos = pos2

		if mns then
			num = 0.0-num
		else
			num = num-0.0
		end
		return sax_number(num)
	end

	local function f_mns()
		local c = byte(json, pos) or tellc()
		if c then
			pos = pos+1
			if c > 0x30 then
				if c < 0x3A then
					return f_num(true)
				end
			else
				if c > 0x2F then
					return f_zro(true)
				end
			end
		end
		parseerror("invalid number")
	end

	-- parse strings
	local f_str_lib = genstrlib(parseerror)
	local f_str_surrogateok = f_str_lib.surrogateok
	local f_str_subst = f_str_lib.subst

	local function f_str(iskey)
		local pos2 = pos
		local newpos
		local str = ''
		local bs
		while true do
			while true do
				newpos = find(json, '\[\\"\]', pos2)
				if newpos then
					break
				end
				str = str .. sub(json, pos, jsonlen)
				if pos2 == jsonlen+2 then
					pos2 = 2
				else
					pos2 = 1
				end
				jsonnxt()
			end
			if byte(json, newpos) == 0x22 then
				break
			end
			pos2 = newpos+2
			bs = true
		end
		str = str .. sub(json, pos, newpos-1)
		pos = newpos+1

		if bs then
			str = gsub(str, '\\(.)(\[^\\\]*)', f_str_subst)
			if not f_str_surrogateok() then
				parseerror("invalid surrogate pair")
			end
		end

		if iskey then
			return sax_key(str)
		end
		return sax_string(str)
	end

	-- parse arrays
	local function f_ary()
		sax_startarray()
		spaces()
		if byte(json, pos) ~= 0x5D then
			local newpos
			while true do
				f = dispatcher\[byte(json, pos)\]
				pos = pos+1
				f()
				f, newpos = find(json, '^\[ \n\r\t\]*,\[ \n\r\t\]*', pos)
				if not newpos then
					f, newpos = find(json, '^\[ \n\r\t\]*%\]', pos)
					if newpos then
						pos = newpos
						break
					end
					spaces()
					local c = byte(json, pos)
					if c == 0x2C then
						pos = pos+1
						spaces()
						newpos = pos-1
					elseif c == 0x5D then
						break
					else
						parseerror("no closing bracket of an array")
					end
				end
				pos = newpos+1
				if pos > jsonlen then
					spaces()
				end
			end
		end
		pos = pos+1
		return sax_endarray()
	end

	-- parse objects
	local function f_obj()
		sax_startobject()
		spaces()
		if byte(json, pos) ~= 0x7D then
			local newpos
			while true do
				if byte(json, pos) ~= 0x22 then
					parseerror("not key")
				end
				pos = pos+1
				f_str(true)
				f, newpos = find(json, '^\[ \n\r\t\]*:\[ \n\r\t\]*', pos)
				if not newpos then
					spaces()
					if byte(json, pos) ~= 0x3A then
						parseerror("no colon after a key")
					end
					pos = pos+1
					spaces()
					newpos = pos-1
				end
				pos = newpos+1
				if pos > jsonlen then
					spaces()
				end
				f = dispatcher\[byte(json, pos)\]
				pos = pos+1
				f()
				f, newpos = find(json, '^\[ \n\r\t\]*,\[ \n\r\t\]*', pos)
				if not newpos then
					f, newpos = find(json, '^\[ \n\r\t\]*}', pos)
					if newpos then
						pos = newpos
						break
					end
					spaces()
					local c = byte(json, pos)
					if c == 0x2C then
						pos = pos+1
						spaces()
						newpos = pos-1
					elseif c == 0x7D then
						break
					else
						parseerror("no closing bracket of an object")
					end
				end
				pos = newpos+1
				if pos > jsonlen then
					spaces()
				end
			end
		end
		pos = pos+1
		return sax_endobject()
	end

	-- key should be non-nil
	dispatcher = {
		       f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err,
		f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err,
		f_err, f_err, f_str, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_mns, f_err, f_err,
		f_zro, f_num, f_num, f_num, f_num, f_num, f_num, f_num, f_num, f_num, f_err, f_err, f_err, f_err, f_err, f_err,
		f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err,
		f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_ary, f_err, f_err, f_err, f_err,
		f_err, f_err, f_err, f_err, f_err, f_err, f_fls, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_nul, f_err,
		f_err, f_err, f_err, f_err, f_tru, f_err, f_err, f_err, f_err, f_err, f_err, f_obj, f_err, f_err, f_err, f_err,
	}
	dispatcher\[0\] = f_err

	local function run()
		spaces()
		f = dispatcher\[byte(json, pos)\]
		pos = pos+1
		f()
	end

	local function read(n)
		if n < 0 then
			error("the argument must be non-negative")
		end
		local pos2 = (pos-1) + n
		local str = sub(json, pos, pos2)
		while pos2 > jsonlen and jsonlen ~= 0 do
			jsonnxt()
			pos2 = pos2 - (jsonlen - (pos-1))
			str = str .. sub(json, pos, pos2)
		end
		if jsonlen ~= 0 then
			pos = pos2+1
		end
		return str
	end

	local function tellpos()
		return acc + pos
	end

	return {
		run = run,
		tryc = tryc,
		read = read,
		tellpos = tellpos,
	}
end

local function newfileparser(fn, saxtbl)
	local fp = io.open(fn)
	local function gen()
		local s
		if fp then
			s = fp:read(8192)
			if not s then
				fp:close()
				fp = nil
			end
		end
		return s
	end
	return newparser(gen, saxtbl)
end

return {
	newparser = newparser,
	newfileparser = newfileparser
}
end;
require("package").preload\["lunajson.decoder"\] = function(...)-- <pack lunajson.decoder> --
local error = error
local byte, char, find, gsub, match, sub = string.byte, string.char, string.find, string.gsub, string.match, string.sub
local tonumber = tonumber
local tostring, setmetatable = tostring, setmetatable

local genstrlib
if _VERSION == "Lua 5.3" then
	genstrlib = require 'lunajson._str_lib_lua53'
else
	genstrlib = require 'lunajson._str_lib'
end

local _ENV = nil

local function newdecoder()
	local json, pos, nullv, arraylen

	local dispatcher
	-- it is temporary for dispatcher\[c\] and
	-- dummy for 1st return value of find
	local f

	-- helper
	local function decodeerror(errmsg)
		error("parse error at " .. pos .. ": " .. errmsg)
	end

	-- parse error
	local function f_err()
		decodeerror('invalid value')
	end

	-- parse constants
	local function f_nul()
		if sub(json, pos, pos+2) == 'ull' then
			pos = pos+3
			return nullv
		end
		decodeerror('invalid value')
	end

	local function f_fls()
		if sub(json, pos, pos+3) == 'alse' then
			pos = pos+4
			return false
		end
		decodeerror('invalid value')
	end

	local function f_tru()
		if sub(json, pos, pos+2) == 'rue' then
			pos = pos+3
			return true
		end
		decodeerror('invalid value')
	end

	-- parse numbers
	local radixmark = match(tostring(0.5), '\[^0-9\]')
	local fixedtonumber = tonumber
	if radixmark ~= '.' then
		if find(radixmark, '%W') then
			radixmark = '%' .. radixmark
		end
		fixedtonumber = function(s)
			return tonumber(gsub(s, '.', radixmark))
		end
	end

	local function f_zro(mns)
		local c = byte(json, pos)

		if c == 0x2E then
			local num = match(json, '^.\[0-9\]*', pos) -- skip 0
			local pos2 = #num
			if pos2 ~= 1 then
				pos2 = pos + pos2
				c = byte(json, pos2)
				if c == 0x45 or c == 0x65 then
					num = match(json, '^\[^eE\]*\[eE\]\[-+0-9\]*', pos)
					pos2 = pos + #num
				end
				num = fixedtonumber(num)
				if num then
					pos = pos2
					if mns then
						num = 0.0-num
					else
						num = num-0.0
					end
					return num
				end
			end
			decodeerror('invalid number')
		end

		if c ~= 0x2C and c ~= 0x5D and c ~= 0x7D and c then -- unusual char is detected
			if 0x30 <= c and c < 0x3A then
				decodeerror('invalid number')
			end
			local pos2 = pos-1
			local num = match(json, '^.\[eE\]\[-+0-9\]*', pos2)
			if num then
				pos2 = pos2 + #num
				num = fixedtonumber(num)
				if not num then
					decodeerror('invalid number')
				end
				pos = pos2
			end
		end

		if not mns then
			return 0.0
		end
		return -0.0
	end

	local function f_num(mns)
		pos = pos-1
		local num = match(json, '^\[0-9\]+%.?\[0-9\]*', pos)
		local c = byte(num, -1)
		if c == 0x2E then -- check that num is not ended by comma
			decodeerror('invalid number')
		end

		local pos2 = pos + #num
		c = byte(json, pos2)
		if c == 0x45 or c == 0x65 then -- e or E?
			num = match(json, '^\[^eE\]*\[eE\]\[-+0-9\]*', pos)
			pos2 = pos + #num
			num = fixedtonumber(num)
			if not num then
				decodeerror('invalid number')
			end
		else
			num = fixedtonumber(num)
		end
		pos = pos2

		if mns then
			num = 0.0-num
		else
			num = num-0.0
		end
		return num
	end

	local function f_mns()
		local c = byte(json, pos)
		if c then
			pos = pos+1
			if c > 0x30 then
				if c < 0x3A then
					return f_num(true)
				end
			else
				if c > 0x2F then
					return f_zro(true)
				end
			end
		end
		decodeerror('invalid number')
	end

	-- parse strings
	local f_str_lib = genstrlib(decodeerror)
	local f_str_surrogateok = f_str_lib.surrogateok
	local f_str_subst = f_str_lib.subst

	local f_str_keycache = {}

	local function f_str(iskey)
		local newpos = pos-2
		local pos2 = pos
		local c1, c2
		repeat
			newpos = find(json, '"', pos2, true)
			if not newpos then
				decodeerror("unterminated string")
			end
			pos2 = newpos+1
			while true do
				c1, c2 = byte(json, newpos-2, newpos-1)
				if c2 ~= 0x5C or c1 ~= 0x5C then
					break
				end
				newpos = newpos-2
			end
		until c2 ~= 0x5C

		local str = sub(json, pos, pos2-2)
		pos = pos2

		if iskey then
			local str2 = f_str_keycache\[str\]
			if str2 then
				return str2
			end
		end
		local str2 = str
		if find(str2, '\\', 1, true) then
			str2 = gsub(str2, '\\(.)(\[^\\\]*)', f_str_subst)
			if not f_str_surrogateok() then
				decodeerror("invalid surrogate pair")
			end
		end
		if iskey then
			f_str_keycache\[str\] = str2
		end
		return str2
	end

	-- parse arrays
	local function f_ary()
		local ary = {}

		f, pos = find(json, '^\[ \n\r\t\]*', pos)
		pos = pos+1

		local i = 0
		if byte(json, pos) ~= 0x5D then
			local newpos = pos-1
			repeat
				i = i+1
				f = dispatcher\[byte(json,newpos+1)\]
				pos = newpos+2
				ary\[i\] = f()
				f, newpos = find(json, '^\[ \n\r\t\]*,\[ \n\r\t\]*', pos)
			until not newpos

			f, newpos = find(json, '^\[ \n\r\t\]*%\]', pos)
			if not newpos then
				decodeerror("no closing bracket of an array")
			end
			pos = newpos
		end

		pos = pos+1
		if arraylen then
			ary\[0\] = i
		end
		return ary
	end

	-- parse objects
	local function f_obj()
		local obj = {}

		f, pos = find(json, '^\[ \n\r\t\]*', pos)
		pos = pos+1
		if byte(json, pos) ~= 0x7D then
			local newpos = pos-1

			repeat
				pos = newpos+1
				if byte(json, pos) ~= 0x22 then
					decodeerror("not key")
				end
				pos = pos+1
				local key = f_str(true)

				-- optimized for compact json
				f = f_err
				do
					local c1, c2, c3  = byte(json, pos, pos+3)
					if c1 == 0x3A then
						newpos = pos
						if c2 == 0x20 then
							newpos = newpos+1
							c2 = c3
						end
						f = dispatcher\[c2\]
					end
				end
				if f == f_err then
					f, newpos = find(json, '^\[ \n\r\t\]*:\[ \n\r\t\]*', pos)
					if not newpos then
						decodeerror("no colon after a key")
					end
				end
				f = dispatcher\[byte(json, newpos+1)\]
				pos = newpos+2
				obj\[key\] = f()
				f, newpos = find(json, '^\[ \n\r\t\]*,\[ \n\r\t\]*', pos)
			until not newpos

			f, newpos = find(json, '^\[ \n\r\t\]*}', pos)
			if not newpos then
				decodeerror("no closing bracket of an object")
			end
			pos = newpos
		end

		pos = pos+1
		return obj
	end

	dispatcher = {
		       f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err,
		f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err,
		f_err, f_err, f_str, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_mns, f_err, f_err,
		f_zro, f_num, f_num, f_num, f_num, f_num, f_num, f_num, f_num, f_num, f_err, f_err, f_err, f_err, f_err, f_err,
		f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err,
		f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_ary, f_err, f_err, f_err, f_err,
		f_err, f_err, f_err, f_err, f_err, f_err, f_fls, f_err, f_err, f_err, f_err, f_err, f_err, f_err, f_nul, f_err,
		f_err, f_err, f_err, f_err, f_tru, f_err, f_err, f_err, f_err, f_err, f_err, f_obj, f_err, f_err, f_err, f_err,
	}
	dispatcher\[0\] = f_err
	dispatcher.__index = function() -- byte is nil
		decodeerror("unexpected termination")
	end
	setmetatable(dispatcher, dispatcher)

	-- run decoder
	local function decode(json_, pos_, nullv_, arraylen_)
		json, pos, nullv, arraylen = json_, pos_, nullv_, arraylen_

		pos = pos or 1
		f, pos = find(json, '^\[ \n\r\t\]*', pos)
		pos = pos+1

		f = dispatcher\[byte(json, pos)\]
		pos = pos+1
		local v = f()

		if pos_ then
			return v, pos
		else
			f, pos = find(json, '^\[ \n\r\t\]*', pos)
			if pos ~= #json then
				error('json ended')
			end
			return v
		end
	end

	return decode
end

return newdecoder
end;
require("package").preload\["lunajson.encoder"\] = function(...)-- <pack lunajson.encoder> --
local error = error
local byte, find, format, gsub, match = string.byte, string.find, string.format,  string.gsub, string.match
local concat = table.concat
local tostring = tostring
local pairs, type = pairs, type
local setmetatable = setmetatable
local huge, tiny = 1/0, -1/0

local f_string_pat
if _VERSION == "Lua 5.1" then
	-- use the cluttered pattern because lua 5.1 does not handle \0 in a pattern correctly
	f_string_pat = '\[^ -!#-\[%\]^-\255\]'
else
	f_string_pat = '\[\0-\31"\\\]'
end

local _ENV = nil

local function newencoder()
	local v, nullv
	local i, builder, visited

	local function f_tostring(v)
		builder\[i\] = tostring(v)
		i = i+1
	end

	local radixmark = match(tostring(0.5), '\[^0-9\]')
	local delimmark = match(tostring(12345.12345), '\[^0-9' .. radixmark .. '\]')
	if radixmark == '.' then
		radixmark = nil
	end

	local radixordelim
	if radixmark or delimmark then
		radixordelim = true
		if radixmark and find(radixmark, '%W') then
			radixmark = '%' .. radixmark
		end
		if delimmark and find(delimmark, '%W') then
			delimmark = '%' .. delimmark
		end
	end

	local f_number = function(n)
		if tiny < n and n < huge then
			local s = format("%.17g", n)
			if radixordelim then
				if delimmark then
					s = gsub(s, delimmark, '')
				end
				if radixmark then
					s = gsub(s, radixmark, '.')
				end
			end
			builder\[i\] = s
			i = i+1
			return
		end
		error('invalid number')
	end

	local doencode

	local f_string_subst = {
		\['"'\] = '\\"',
		\['\\'\] = '\\\\',
		\['\b'\] = '\\b',
		\['\f'\] = '\\f',
		\['\n'\] = '\\n',
		\['\r'\] = '\\r',
		\['\t'\] = '\\t',
		__index = function(_, c)
			return format('\\u00%02X', byte(c))
		end
	}
	setmetatable(f_string_subst, f_string_subst)

	local function f_string(s)
		builder\[i\] = '"'
		if find(s, f_string_pat) then
			s = gsub(s, f_string_pat, f_string_subst)
		end
		builder\[i+1\] = s
		builder\[i+2\] = '"'
		i = i+3
	end

	local function f_table(o)
		if visited\[o\] then
			error("loop detected")
		end
		visited\[o\] = true

		local tmp = o\[0\]
		if type(tmp) == 'number' then -- arraylen available
			builder\[i\] = '\['
			i = i+1
			for j = 1, tmp do
				doencode(o\[j\])
				builder\[i\] = ','
				i = i+1
			end
			if tmp > 0 then
				i = i-1
			end
			builder\[i\] = '\]'

		else
			tmp = o\[1\]
			if tmp ~= nil then -- detected as array
				builder\[i\] = '\['
				i = i+1
				local j = 2
				repeat
					doencode(tmp)
					tmp = o\[j\]
					if tmp == nil then
						break
					end
					j = j+1
					builder\[i\] = ','
					i = i+1
				until false
				builder\[i\] = '\]'

			else -- detected as object
				builder\[i\] = '{'
				i = i+1
				local tmp = i
				for k, v in pairs(o) do
					if type(k) ~= 'string' then
						error("non-string key")
					end
					f_string(k)
					builder\[i\] = ':'
					i = i+1
					doencode(v)
					builder\[i\] = ','
					i = i+1
				end
				if i > tmp then
					i = i-1
				end
				builder\[i\] = '}'
			end
		end

		i = i+1
		visited\[o\] = nil
	end

	local dispatcher = {
		boolean = f_tostring,
		number = f_number,
		string = f_string,
		table = f_table,
		__index = function()
			error("invalid type value")
		end
	}
	setmetatable(dispatcher, dispatcher)

	function doencode(v)
		if v == nullv then
			builder\[i\] = 'null'
			i = i+1
			return
		end
		return dispatcher\[type(v)\](v)
	end

	local function encode(v_, nullv_)
		v, nullv = v_, nullv_
		i, builder, visited = 1, {}, {}

		doencode(v)
		return concat(builder)
	end

	return encode
end

return newencoder
end;
local newdecoder = require 'lunajson.decoder'
local newencoder = require 'lunajson.encoder'
local sax = require 'lunajson.sax'
-- If you have need multiple context of decoder encode,
-- you could require lunajson.decoder or lunajson.encoder directly.
return {
	decode = newdecoder(),
	encode = newencoder(),
	newparser = sax.newparser,
	newfileparser = sax.newfileparser,
}
]]):gsub('\\([%]%[])','%1')
sources["utf8"]=([[-- <pack utf8> --
local m = {} -- the module
local ustring = {} -- table to index equivalent string.* functions

-- TsT <tst2005 gmail com> 20121108 (v0.2.1)
-- License: same to the Lua one
-- TODO: copy the LICENSE file

-------------------------------------------------------------------------------
-- begin of the idea : http://lua-users.org/wiki/LuaUnicode
--
-- for uchar in sgmatch(unicode_string, "(\[%z\1-\127\194-\244\]\[\128-\191\]*)") do
--
--local function utf8_strlen(unicode_string)
--	local _, count = string.gsub(unicode_string, "\[^\128-\193\]", "")
--	return count
--end

-- http://www.unicode.org/reports/tr29/#Grapheme_Cluster_Boundaries

-- my custom type for Unicode String
local utf8type = "ustring"

local typeof = assert(type)

local string = require("string")
local sgmatch = assert(string.gmatch or string.gfind) -- lua 5.1+ or 5.0
local string_byte = assert(string.byte)

local table = require("table")
local table_concat = assert(table.concat)

local function table_sub(t, i, j)
	local len = #t
	if not i or i == 0 then
		i = 1
	elseif i < 0 then -- support negative index
		i = len+i+1
	end
	if not j then
		j = i
	elseif j < 0 then
		j = len+j+1
	end
	local r = {}
	for k=i,j,1 do
		r\[#r+1\] = t\[k\]
	end
	return r
end
local function utf8_range(uobj, i, j)
	local t = table_sub(uobj, i, j)
	return setmetatable(t, getmetatable(uobj)) -- or utf8_object() 
end

local function utf8_typeof(obj)
	local mt = getmetatable(obj)
	return mt and mt.__type or typeof(obj)
end

local function utf8_is_object(obj)
	return not not (utf8_typeof(obj) == utf8type)
end

local function utf8_tostring(obj)
	if utf8_is_object(obj) then
		return table_concat(obj, "")
	end
	return tostring(obj)
end

local function utf8_sub(uobj, i, j)
        assert(i, "sub: i must exists")
	return utf8_range(uobj, i, j)
end

local function utf8_op_concat(op1, op2)
	local op1 = utf8_is_object(op1) and utf8_tostring(op1) or op1
	local op2 = utf8_is_object(op2) and utf8_tostring(op2) or op2
	if (typeof(op1) == "string" or typeof(op1) == "number") and
	   (typeof(op2) == "string" or typeof(op2) == "number") then
		return op1 .. op2  -- primitive string concatenation
	end
	local h = getmetatable(op1).__concat or getmetatable(op2).__concat
	if h then
		return h(op1, op2)
	end
	error("concat error")
end

--local function utf8_is_uchar(uchar)
--	return (uchar:len() > 1) -- len() = string.len()
--end



local function utf8_object(uobj)
	local uobj = uobj or {}
-- IDEA: create __index to return function without to be indexe directly as a key
	for k,v in pairs(ustring) do
		uobj\[k\] = v
	end
	local mt = getmetatable(uobj) or {}
	mt.__concat   = utf8_op_concat
	mt.__tostring = utf8_tostring
	mt.__type     = utf8type
	return setmetatable(uobj, mt)
end

--        %z = 0x00 (\0 not allowed)
--        \1 = 0x01
--      \127 = 0x7F
--      \128 = 0x80
--      \191 = 0xBF

-- parse a lua string to split each UTF-8 sequence to separated table item
local function private_string2ustring(unicode_string)
	assert(typeof(unicode_string) == "string", "unicode_string is not a string?!")

	local uobj = utf8_object()
	local cnt = 1
-- FIXME: invalid sequence dropped ?!
	for uchar in sgmatch(unicode_string, "(\[%z\1-\127\194-\244\]\[\128-\191\]*)") do
		uobj\[cnt\] = uchar
		cnt = cnt + 1
	end
	return uobj
end

local function private_contains_unicode(str)
	return not not str:find("\[\128-\193\]+")
end

local function utf8_auto_convert(unicode_string, i, j)
	local obj
	assert(typeof(unicode_string) == "string", "unicode_string is not a string: ", typeof(unicode_string))
	if private_contains_unicode(unicode_string) then
		obj = private_string2ustring(unicode_string)
	else
		obj = unicode_string
	end
	return (i and obj:sub(i,j)) or obj
end

local function utf8_byte(obj, i, j)
	local i = i or 1
	local j = j or i
	local uobj
	assert(utf8_is_object(obj), "ask utf8_byte() for a non utf8 object?!")
--	if not utf8_is_object(obj) then
--		uobj = utf8_auto_convert(obj, i, j)
--	else
	uobj = obj:sub(i, j)
--	end
	return string_byte(tostring(uobj), 1, -1)
end

-- FIXME: what is the lower/upper case of Unicode ?!
local function utf8_lower(uobj) return utf8_auto_convert( tostring(uobj):lower() ) end
local function utf8_upper(uobj) return utf8_auto_convert( tostring(uobj):upper() ) end

local function utf8_reverse(uobj)
	local t = {}
	for i=#uobj,1,-1 do
		t\[#t+1\] = uobj\[i\]
	end
	return utf8_object(t)
end
local function utf8_rep(uobj, n)
	return utf8_auto_convert(tostring(uobj):rep(n)) -- :rep() is the string.rep()
end

---- Standard Lua 5.1 string.* ----
ustring.byte	= assert(utf8_byte)
ustring.char	= assert(string.char)
ustring.dump	= assert(string.dump)
--ustring.find
ustring.format	= assert(string.format)
--ustring.gmatch
--ustring.gsub
ustring.len	= function(uobj) return #uobj end
ustring.lower	= assert(utf8_lower)
--ustring.match
ustring.rep	= assert(utf8_rep)
ustring.reverse	= assert(utf8_reverse)
ustring.sub	= assert(utf8_sub)
ustring.upper	= assert(utf8_upper)

---- custome add-on ----
ustring.type	= assert(utf8_typeof)

-- Add fonctions to the module
for k,v in pairs(ustring) do m\[k\] = v end

-- Allow to use the module directly to convert strings
local mt = {
	__call = function(self, obj, i, j)
		if utf8_is_object(obj) then
			return (i and obj:sub(i,j)) or obj
		end
		local str = obj
		if typeof(str) ~= "string" then
			str = tostring(str)
		end
		return utf8_auto_convert(str, i, j)
	end
}

return setmetatable(m,mt)
]]):gsub('\\([%]%[])','%1')
sources["cliargs"]=([[-- <pack cliargs> --
local cli, _

-- ------- --
-- Helpers --
-- ------- --

local split = function(str, pat)
  local t = {}
  local fpat = "(.-)" .. pat
  local last_end = 1
  local s, e, cap = str:find(fpat, 1)
  while s do
    if s ~= 1 or cap ~= "" then
      table.insert(t,cap)
    end
    last_end = e+1
    s, e, cap = str:find(fpat, last_end)
  end
  if last_end <= #str then
    cap = str:sub(last_end)
    table.insert(t, cap)
  end
  return t
end

local buildline = function(words, size, overflow)
  -- if overflow is set, a word longer than size, will overflow the size
  -- otherwise it will be chopped in line-length pieces
  local line = ""
  if string.len(words\[1\]) > size then
    -- word longer than line
    if overflow then
      line = words\[1\]
      table.remove(words, 1)
    else
      line = words\[1\]:sub(1, size)
      words\[1\] = words\[1\]:sub(size + 1, -1)
    end
  else
    while words\[1\] and (#line + string.len(words\[1\]) + 1 <= size) or (line == "" and #words\[1\] == size) do
      if line == "" then
        line = words\[1\]
      else
        line = line .. " " .. words\[1\]
      end
      table.remove(words, 1)
    end
  end
  return line, words
end

local wordwrap = function(str, size, pad, overflow)
  -- if overflow is set, then words longer than a line will overflow
  -- otherwise, they'll be chopped in pieces
  pad = pad or 0

  local line = ""
  local out = ""
  local padstr = string.rep(" ", pad)
  local words = split(str, ' ')

  while words\[1\] do
    line, words = buildline(words, size, overflow)
    if out == "" then
      out = padstr .. line
    else
        out = out .. "\n" .. padstr .. line
    end
  end

  return out
end

local function disect(key)
  -- characters allowed are a-z, A-Z, 0-9
  -- extended + values also allow; # @ _ + -
  local k, ek, v
  local dummy
  -- if there is no comma, between short and extended, add one
  _, _, dummy = key:find("^%-(\[%a%d\]+)\[%s\]%-%-")
  if dummy then key = key:gsub("^%-\[%a%d\]\[%s\]%-%-", "-"..dummy..", --", 1) end
  -- for a short key + value, replace space by "="
  _, _, dummy = key:find("^%-(\[%a%d\]+)\[%s\]")
  if dummy then key = key:gsub("^%-(\[%a%d\]+)\[ \]", "-"..dummy.."=", 1) end
  -- if there is no "=", then append one
  if not key:find("=") then key = key .. "=" end
  -- get value
  _, _, v = key:find(".-%=(.+)")
  -- get key(s), remove spaces
  key = split(key, "=")\[1\]:gsub(" ", "")
  -- get short key & extended key
  _, _, k = key:find("^%-(\[^-\]\[^%s,\]*)")
  _, _, ek = key:find("%-%-(.+)$")
  if v == "" then v = nil end
  return k,ek,v
end

local function callable(fn)
  return type(fn) == "function" or (getmetatable(fn) or {}).__call
end


function cli_error(msg, noprint)
  local msg = cli.name .. ": error: " .. msg .. '; re-run with --help for usage.'
  if not noprint then print(msg) end
  return nil, msg
end

-- -------- --
-- CLI Main --
-- -------- --

cli = {
  name = "",
  required = {},
  optional = {},
  optargument = {maxcount = 0},
  colsz = { 0, 0 }, -- column width, help text. Set to 0 for auto detect
  maxlabel = 0,
}

--- Assigns the name of the program which will be used for logging.
function cli:set_name(name)
  self.name = name
end

-- Used internally to lookup an entry using either its short or expanded keys
function cli:__lookup(k, ek, t)
  t = t or self.optional
  local _
  for _,entry in ipairs(t) do
    if k  and entry.key == k then return entry end
    if ek and entry.expanded_key == ek then return entry end
    if entry.has_no_flag then
      if ek and ("no-"..entry.expanded_key) == ek then return entry end
    end
  end

  return nil
end

--- Defines a required argument.
--- Required arguments have no special notation and are order-sensitive.
--- *Note:* the value will be stored in `args\[@key\]`.
--- *Aliases: `add_argument`*
---
--- ### Parameters
--- 1. **key**: the argument's "name" that will be displayed to the user
--- 2. **desc**: a description of the argument
--- 3. **callback**: *optional*; specify a function to call when this argument is parsed (the default is nil)
---
--- ### Usage example
--- The following will parse the argument (if specified) and set its value in `args\["root"\]`:
--- `cli:add_arg("root", "path to where root scripts can be found")`
function cli:add_arg(key, desc, callback)
  assert(type(key) == "string" and type(desc) == "string", "Key and description are mandatory arguments (Strings)")
  assert(callable(callback) or callback == nil, "Callback argument: expected a function or nil")

  if self:__lookup(key, nil, self.required) then
    error("Duplicate argument: " .. key .. ", please rename one of them.")
  end

  table.insert(self.required, { key = key, desc = desc, value = nil, callback = callback })
  if #key > self.maxlabel then self.maxlabel = #key end
end

--- Defines an optional argument (or more than one).
--- There can be only 1 optional argument, and it has to be the last one on the argumentlist.
--- *Note:* the value will be stored in `args\[@key\]`. The value will be a 'string' if 'maxcount == 1',
--- or a table if 'maxcount > 1'
---
--- ### Parameters
--- 1. **key**: the argument's "name" that will be displayed to the user
--- 2. **desc**: a description of the argument
--- 3. **default**: *optional*; specify a default value (the default is nil)
--- 4. **maxcount**: *optional*; specify the maximum number of occurences allowed (default is 1)
--- 5. **callback**: *optional*; specify a function to call when this argument is parsed (the default is nil)
---
--- ### Usage example
--- The following will parse the argument (if specified) and set its value in `args\["root"\]`:
--- `cli:add_arg("root", "path to where root scripts can be found", "", 2)`
--- The value returned will be a table with at least 1 entry and a maximum of 2 entries
function cli:optarg(key, desc, default, maxcount, callback)
  assert(type(key) == "string" and type(desc) == "string", "Key and description are mandatory arguments (Strings)")
  assert(type(default) == "string" or default == nil, "Default value must either be omitted or be a string")
  maxcount = maxcount or 1
  maxcount = tonumber(maxcount)
  assert(maxcount and maxcount>0 and maxcount<1000,"Maxcount must be a number from 1 to 999")
  assert(callable(callback) or callback == nil, "Callback argument: expected a function or nil")

  self.optargument = { key = key, desc = desc, default = default, maxcount = maxcount, value = nil, callback = callback }
  if #key > self.maxlabel then self.maxlabel = #key end
end

-- Used internally to add an option
function cli:__add_opt(k, ek, v, label, desc, default, callback)
  local flag = (v == nil) -- no value, so it's a flag
  local has_no_flag = flag and (ek and ek:find('^%\[no%-\]') ~= nil)
  local ek = has_no_flag and ek:sub(6) or ek

  -- guard against duplicates
  if self:__lookup(k, ek) then
    error("Duplicate option: " .. (k or ek) .. ", please rename one of them.")
  end
  if has_no_flag and self:__lookup(nil, "no-"..ek) then
    error("Duplicate option: " .. ("no-"..ek) .. ", please rename one of them.")
  end

  -- below description of full entry record, nils included for reference
  local entry = {
    key = k,
    expanded_key = ek,
    desc = desc,
    default = default,
    label = label,
    flag = flag,
    has_no_flag = has_no_flag,
    value = default,
    callback = callback,
  }

  table.insert(self.optional, entry)
  if #label > self.maxlabel then self.maxlabel = #label end

end

--- Defines an option.
--- Optional arguments can use 3 different notations, and can accept a value.
--- *Aliases: `add_option`*
---
--- ### Parameters
--- 1. **key**: the argument identifier, can be either `-key`, or `-key, --expanded-key`:
--- if the first notation is used then a value can be defined after a space (`'-key VALUE'`),
--- if the 2nd notation is used then a value can be defined after an `=` (`'-key, --expanded-key=VALUE'`).
--- As a final option it is possible to only use the expanded key (eg. `'--expanded-key'`) both with and
--- without a value specified.
--- 2. **desc**: a description for the argument to be shown in --help
--- 3. **default**: *optional*; specify a default value (the default is nil)
--- 4. **callback**: *optional*; specify a function to call when this option is parsed (the default is nil)
---
--- ### Usage example
--- The following option will be stored in `args\["i"\]` and `args\["input"\]` with a default value of `my_file.txt`:
--- `cli:add_option("-i, --input=FILE", "path to the input file", "my_file.txt")`
function cli:add_opt(key, desc, default, callback)
  -- parameterize the key if needed, possible variations:
  -- 1. -key
  -- 2. -key VALUE
  -- 3. -key, --expanded
  -- 4. -key, --expanded=VALUE
  -- 5. -key --expanded
  -- 6. -key --expanded=VALUE
  -- 7. --expanded
  -- 8. --expanded=VALUE

  assert(type(key) == "string" and type(desc) == "string", "Key and description are mandatory arguments (Strings)")
  assert(callable(callback) or callback == nil, "Callback argument: expected a function or nil")
  assert(
    (
      type(default) == "string"
      or default == nil
      or type(default) == "boolean"
      or (type(default) == "table" and next(default) == nil)
    ),
    "Default argument: expected a string, nil, or {}"
  )

  local k, ek, v = disect(key)

  -- set defaults
  if v == nil and type(default) ~= "boolean" then default = nil end

  self:__add_opt(k, ek, v, key, desc, default, callback)
end

--- Define a flag argument (on/off). This is a convenience helper for cli.add_opt().
--- See cli.add_opt() for more information.
---
--- ### Parameters
-- 1. **key**: the argument's key
-- 2. **desc**: a description of the argument to be displayed in the help listing
-- 3. **default**: *optional*; specify a default value (the default is nil)
-- 4. **callback**: *optional*; specify a function to call when this flag is parsed (the default is nil)
function cli:add_flag(key, desc, default, callback)
  if type(default) == "function" then
    callback = default
    default = nil
  end
  assert(default == nil or type(default) == "boolean", "Default argument: expected a boolean, nil")

  local k, ek, v = disect(key)

  if v ~= nil then
    error("A flag type option cannot have a value set: " .. key)
  end

  self:__add_opt(k, ek, nil, key, desc, default, callback)
end

--- Parses the arguments found in #arg and returns a table with the populated values.
--- (NOTE: after succesful parsing, the module will delete itself to free resources)
--- *Aliases: `parse_args`*
---
--- ### Parameters
--- 1. **arguments**: set this to arg
--- 2. **noprint**: set this flag to prevent any information (error or help info) from being printed
--- 3. **dump**: set this flag to dump the parsed variables for debugging purposes, alternatively
--- set the first option to --__DUMP__ (option with 2 trailing and leading underscores) to dump at runtime.
---
--- ### Returns
--- 1. a table containing the keys specified when the arguments were defined along with the parsed values,
--- or nil + error message (--help option is considered an error and returns nil + help message)
function cli:parse(arguments, noprint, dump)
  if type(arguments) ~= "table" then
    -- optional 'arguments' was not provided, so shift remaining arguments
    noprint, dump, arguments = arguments, noprint, nil
  end
  local arguments = arguments or arg or {}
  local args = {}
  for k,v in pairs(arguments) do args\[k\] = v end  -- copy args local

  -- starts with --help? display the help listing and abort!
  if args\[1\] and (args\[1\] == "--help" or args\[1\] == "-h") then
    return nil, self:print_help(noprint)
  end

  -- starts with --__DUMP__; set dump to true to dump the parsed arguments
  if dump == nil then
    if args\[1\] and args\[1\] == "--__DUMP__" then
      dump = true
      table.remove(args, 1)  -- delete it to prevent further parsing
    end
  end

  while args\[1\] do
    local entry = nil
    local opt = args\[1\]
    local _, optpref, optkey, optkey2, optval
    _, _, optpref, optkey = opt:find("^(%-\[%-\]?)(.+)")   -- split PREFIX & NAME+VALUE
    if optkey then
      _, _, optkey2, optval = optkey:find("(.-)\[=\](.+)")       -- split value and key
      if optval then
        optkey = optkey2
      end
    end

    if not optpref then
      break   -- no optional prefix, so options are done
    end

    if opt == "--" then
      table.remove(args, 1)
      break   -- end of options
    end

    if optkey:sub(-1,-1) == "=" then  -- check on a blank value eg. --insert=
      optval = ""
      optkey = optkey:sub(1,-2)
    end

    if optkey then
      entry =
        self:__lookup(optpref == '-' and optkey or nil,
                      optpref == '--' and optkey or nil)
    end

    if not optkey or not entry then
      local option_type = optval and "option" or "flag"
      return cli_error("unknown/bad " .. option_type .. ": " .. opt, noprint)
    end

    table.remove(args,1)
    if optpref == "-" then
      if optval then
        return cli_error("short option does not allow value through '=': "..opt, noprint)
      end
      if entry.flag then
        optval = true
      else
        -- not a flag, value is in the next argument
        optval = args\[1\]
        table.remove(args, 1)
      end
    elseif optpref == "--" then
      -- using the expanded-key notation
      entry = self:__lookup(nil, optkey)
      if entry then
        if entry.flag then
          if optval then
            return cli_error("flag --" .. optkey .. " does not take a value", noprint)
          else
            optval = not entry.has_no_flag or (optkey:sub(1,3) ~= "no-")
          end
        else
          if not optval then
            -- value is in the next argument
            optval = args\[1\]
            table.remove(args, 1)
          end
        end
      else
        return cli_error("unknown/bad flag: " .. opt, noprint)
      end
    end

    if type(entry.value) == 'table' then
      table.insert(entry.value, optval)
    else
      entry.value = optval
    end

    -- invoke the option's parse-callback, if any
    if entry.callback then
      local altkey = entry.key

      if optkey == entry.key then
        altkey = entry.expanded_key
      else
        optkey = entry.expanded_key
      end

      local status, err = entry.callback(optkey, optval, altkey, opt)
      if status == nil and err then
        return cli_error(err, noprint)
      end
    end
  end

  -- missing any required arguments, or too many?
  if #args < #self.required or #args > #self.required + self.optargument.maxcount then
    if self.optargument.maxcount > 0 then
      return cli_error("bad number of arguments: " .. #self.required .."-" .. #self.required + self.optargument.maxcount .. " argument(s) must be specified, not " .. #args, noprint)
    else
      return cli_error("bad number of arguments: " .. #self.required .. " argument(s) must be specified, not " .. #args, noprint)
    end
  end

  -- deal with required args here
  for i, entry in ipairs(self.required) do
    entry.value = args\[1\]
    if entry.callback then
      local status, err = entry.callback(entry.key, entry.value)
      if status == nil and err then
        return cli_error(err, noprint)
      end
    end
    table.remove(args, 1)
  end
  -- deal with the last optional argument
  while args\[1\] do
    if self.optargument.maxcount > 1 then
      self.optargument.value = self.optargument.value or {}
      table.insert(self.optargument.value, args\[1\])
    else
      self.optargument.value = args\[1\]
    end
    if self.optargument.callback then
      local status, err = self.optargument.callback(self.optargument.key, args\[1\])
      if status == nil and err then
        return cli_error(err, noprint)
      end
    end
    table.remove(args,1)
  end
  -- if necessary set the defaults for the last optional argument here
  if self.optargument.maxcount > 0 and not self.optargument.value then
    if self.optargument.maxcount == 1 then
      self.optargument.value = self.optargument.default
    else
      self.optargument.value = { self.optargument.default }
    end
  end

  -- populate the results table
  local results = {}
  if self.optargument.maxcount > 0 then
    results\[self.optargument.key\] = self.optargument.value
  end
  for _, entry in pairs(self.required) do
    results\[entry.key\] = entry.value
  end
  for _, entry in pairs(self.optional) do
    if entry.key then results\[entry.key\] = entry.value end
    if entry.expanded_key then results\[entry.expanded_key\] = entry.value end
  end

  if dump then
    print("\n======= Provided command line =============")
    print("\nNumber of arguments: ", #arg)
    for i,v in ipairs(arg) do -- use gloabl 'arg' not the modified local 'args'
      print(string.format("%3i = '%s'", i, v))
    end

    print("\n======= Parsed command line ===============")
    if #self.required > 0 then print("\nArguments:") end
    for i,v in ipairs(self.required) do
      print("  " .. v.key .. string.rep(" ", self.maxlabel + 2 - #v.key) .. " => '" .. v.value .. "'")
    end

    if self.optargument.maxcount > 0 then
      print("\nOptional arguments:")
      print("  " .. self.optargument.key .. "; allowed are " .. tostring(self.optargument.maxcount) .. " arguments")
      if self.optargument.maxcount == 1 then
          print("  " .. self.optargument.key .. string.rep(" ", self.maxlabel + 2 - #self.optargument.key) .. " => '" .. self.optargument.key .. "'")
      else
        for i = 1, self.optargument.maxcount do
          if self.optargument.value\[i\] then
            print("  " .. tostring(i) .. string.rep(" ", self.maxlabel + 2 - #tostring(i)) .. " => '" .. tostring(self.optargument.value\[i\]) .. "'")
          end
        end
      end
    end

    if #self.optional > 0 then print("\nOptional parameters:") end
    local doubles = {}
    for _, v in pairs(self.optional) do
      if not doubles\[v\] then
        local m = v.value
        if type(m) == "string" then
          m = "'"..m.."'"
        else
          m = tostring(m) .." (" .. type(m) .. ")"
        end
        print("  " .. v.label .. string.rep(" ", self.maxlabel + 2 - #v.label) .. " => " .. m)
        doubles\[v\] = v
      end
    end
    print("\n===========================================\n\n")
    return cli_error("commandline dump created as requested per '--__DUMP__' option", noprint)
  end

  if not _TEST then
    -- cleanup entire module, as it's single use
    -- remove from package.loaded table to enable the module to
    -- garbage collected.
    for k, v in pairs(package.loaded) do
      if v == cli then
        package.loaded\[k\] = nil
        break
      end
    end
    -- clear table in case user holds on to module table
    for k, _ in pairs(cli) do
      cli\[k\] = nil
    end
  end

  return results
end

--- Prints the USAGE heading.
---
--- ### Parameters
 ---1. **noprint**: set this flag to prevent the line from being printed
---
--- ### Returns
--- 1. a string with the USAGE message.
function cli:print_usage(noprint)
  -- print the USAGE heading
  local msg = "Usage: " .. tostring(self.name)
  if #self.optional > 0 then
    msg = msg .. " \[OPTIONS\]"
  end
  if #self.required > 0 or self.optargument.maxcount > 0 then
    msg = msg .. " \[--\]"
  end
  if #self.required > 0 then
    for _,entry in ipairs(self.required) do
      msg = msg .. " " .. entry.key
    end
  end
  if self.optargument.maxcount == 1 then
    msg = msg .. " \[" .. self.optargument.key .. "\]"
  elseif self.optargument.maxcount == 2 then
    msg = msg .. " \[" .. self.optargument.key .. "-1 \[" .. self.optargument.key .. "-2\]\]"
  elseif self.optargument.maxcount > 2 then
    msg = msg .. " \[" .. self.optargument.key .. "-1 \[" .. self.optargument.key .. "-2 \[...\]\]\]"
  end

  if not noprint then print(msg) end
  return msg
end


--- Prints the HELP information.
---
--- ### Parameters
--- 1. **noprint**: set this flag to prevent the information from being printed
---
--- ### Returns
--- 1. a string with the HELP message.
function cli:print_help(noprint)
  local msg = self:print_usage(true) .. "\n"
  local col1 = self.colsz\[1\]
  local col2 = self.colsz\[2\]
  if col1 == 0 then col1 = cli.maxlabel end
  col1 = col1 + 3     --add margins
  if col2 == 0 then col2 = 72 - col1 end
  if col2 <10 then col2 = 10 end

  local append = function(label, desc)
      label = "  " .. label .. string.rep(" ", col1 - (#label + 2))
      desc = wordwrap(desc, col2)   -- word-wrap
      desc = desc:gsub("\n", "\n" .. string.rep(" ", col1)) -- add padding

      msg = msg .. label .. desc .. "\n"
  end

  if self.required\[1\] then
    msg = msg .. "\nARGUMENTS: \n"
    for _,entry in ipairs(self.required) do
      append(entry.key, entry.desc .. " (required)")
    end
  end

  if self.optargument.maxcount > 0 then
    append(self.optargument.key, self.optargument.desc .. " (optional, default: " .. self.optargument.default .. ")")
  end

  if #self.optional > 0 then
    msg = msg .. "\nOPTIONS: \n"

    for _,entry in ipairs(self.optional) do
      local desc = entry.desc
      if not entry.flag and entry.default and #tostring(entry.default) > 0 then
        local readable_default = type(entry.default) == "table" and "\[\]" or tostring(entry.default)
        desc = desc .. " (default: " .. readable_default .. ")"
      elseif entry.flag and entry.has_no_flag then
        local readable_default = entry.default and 'on' or 'off'
        desc = desc .. " (default: " .. readable_default .. ")"
      end
      append(entry.label, desc)
    end
  end

  if not noprint then print(msg) end
  return msg
end

--- Sets the amount of space allocated to the argument keys and descriptions in the help listing.
--- The sizes are used for wrapping long argument keys and descriptions.
--- ### Parameters
--- 1. **key_cols**: the number of columns assigned to the argument keys, set to 0 to auto detect (default: 0)
--- 1. **desc_cols**: the number of columns assigned to the argument descriptions, set to 0 to auto set the total width to 72 (default: 0)
function cli:set_colsz(key_cols, desc_cols)
  self.colsz = { key_cols or self.colsz\[1\], desc_cols or self.colsz\[2\] }
end


-- finalize setup
cli._COPYRIGHT   = "Copyright (C) 2011-2014 Ahmad Amireh"
cli._LICENSE     = "The code is released under the MIT terms. Feel free to use it in both open and closed software as you please."
cli._DESCRIPTION = "Commandline argument parser for Lua"
cli._VERSION     = "cliargs 2.5-1"

-- aliases
cli.add_argument = cli.add_arg
cli.add_option = cli.add_opt
cli.parse_args = cli.parse    -- backward compatibility

-- test aliases for local functions
if _TEST then
  cli.split = split
  cli.wordwrap = wordwrap
end

return cli
]]):gsub('\\([%]%[])','%1')
sources["ser"]=([[-- <pack ser> --
local pairs, ipairs, tostring, type, concat, dump, floor, format = pairs, ipairs, tostring, type, table.concat, string.dump, math.floor, string.format

local function getchr(c)
	return "\\" .. c:byte()
end

local function make_safe(text)
	return ("%q"):format(text):gsub('\n', 'n'):gsub("\[\128-\255\]", getchr)
end

local oddvals = {\[tostring(1/0)\] = '1/0', \[tostring(-1/0)\] = '-1/0', \[tostring(0/0)\] = '0/0'}
local function write(t, memo, rev_memo)
	local ty = type(t)
	if ty == 'number' then
		t = format("%.17g", t)
		return oddvals\[t\] or t
	elseif ty == 'boolean' or ty == 'nil' then
		return tostring(t)
	elseif ty == 'string' then
		return make_safe(t)
	elseif ty == 'table' or ty == 'function' then
		if not memo\[t\] then
			local index = #rev_memo + 1
			memo\[t\] = index
			rev_memo\[index\] = t
		end
		return '_\[' .. memo\[t\] .. '\]'
	else
		error("Trying to serialize unsupported type " .. ty)
	end
end

local kw = {\['and'\] = true, \['break'\] = true, \['do'\] = true, \['else'\] = true,
	\['elseif'\] = true, \['end'\] = true, \['false'\] = true, \['for'\] = true,
	\['function'\] = true, \['goto'\] = true, \['if'\] = true, \['in'\] = true,
	\['local'\] = true, \['nil'\] = true, \['not'\] = true, \['or'\] = true,
	\['repeat'\] = true, \['return'\] = true, \['then'\] = true, \['true'\] = true,
	\['until'\] = true, \['while'\] = true}
local function write_key_value_pair(k, v, memo, rev_memo, name)
	if type(k) == 'string' and k:match '^\[_%a\]\[_%w\]*$' and not kw\[k\] then
		return (name and name .. '.' or '') .. k ..'=' .. write(v, memo, rev_memo)
	else
		return (name or '') .. '\[' .. write(k, memo, rev_memo) .. '\]=' .. write(v, memo, rev_memo)
	end
end

-- fun fact: this function is not perfect
-- it has a few false positives sometimes
-- but no false negatives, so that's good
local function is_cyclic(memo, sub, super)
	local m = memo\[sub\]
	local p = memo\[super\]
	return m and p and m < p
end

local function write_table_ex(t, memo, rev_memo, srefs, name)
	if type(t) == 'function' then
		return '_\[' .. name .. '\]=loadstring' .. make_safe(dump(t))
	end
	local m = {}
	local mi = 1
	for i = 1, #t do -- don't use ipairs here, we need the gaps
		local v = t\[i\]
		if v == t or is_cyclic(memo, v, t) then
			srefs\[#srefs + 1\] = {name, i, v}
			m\[mi\] = 'nil'
			mi = mi + 1
		else
			m\[mi\] = write(v, memo, rev_memo)
			mi = mi + 1
		end
	end
	for k,v in pairs(t) do
		if type(k) ~= 'number' or floor(k) ~= k or k < 1 or k > #t then
			if v == t or k == t or is_cyclic(memo, v, t) or is_cyclic(memo, k, t) then
				srefs\[#srefs + 1\] = {name, k, v}
			else
				m\[mi\] = write_key_value_pair(k, v, memo, rev_memo)
				mi = mi + 1
			end
		end
	end
	return '_\[' .. name .. '\]={' .. concat(m, ',') .. '}'
end

return function(t)
	local memo = {\[t\] = 0}
	local rev_memo = {\[0\] = t}
	local srefs = {}
	local result = {}

	-- phase 1: recursively descend the table structure
	local n = 0
	while rev_memo\[n\] do
		result\[n + 1\] = write_table_ex(rev_memo\[n\], memo, rev_memo, srefs, n)
		n = n + 1
	end

	-- phase 2: reverse order
	for i = 1, n*.5 do
		local j = n - i + 1
		result\[i\], result\[j\] = result\[j\], result\[i\]
	end

	-- phase 3: add all the tricky cyclic stuff
	for i, v in ipairs(srefs) do
		n = n + 1
		result\[n\] = write_key_value_pair(v\[2\], v\[3\], memo, rev_memo, '_\[' .. v\[1\] .. '\]')
	end

	-- phase 4: add something about returning the main table
	if result\[n\]:sub(1, 5) == '_\[0\]=' then
		result\[n\] = 'return ' .. result\[n\]:sub(6)
	else
		result\[n + 1\] = 'return _\[0\]'
	end

	-- phase 5: just concatenate everything
	result = concat(result, '\n')
	return n > 1 and 'local _={}\n' .. result or result
end
]]):gsub('\\([%]%[])','%1')
local loadstring=loadstring; local preload = require"package".preload
for name, rawcode in pairs(sources) do preload[name]=function(...)return loadstring(rawcode)(...)end end
end;