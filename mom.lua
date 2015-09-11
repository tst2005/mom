#!/usr/bin/env lua
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
]] and nil
do local sources, priorities = {}, {};assert(not sources["preloaded"])sources["preloaded"]=([===[-- <pack preloaded> --
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
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["gro"])sources["gro"]=([===[-- <pack gro> --

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
		if loaded[name]==value then
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
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["aio"])sources["aio"]=([===[-- <pack aio> --
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
]] and nil
--[[--------------------------------------------------------------------------
	-- Dragoon Framework - A Framework for Lua/LOVE --
	-- Copyright (c) 2014-2015 TsT worldmaster.fr <tst2005@gmail.com> --
--]]--------------------------------------------------------------------------

-- $0 --mod <modname1 pathtofile1> [--mod <modname2> <pathtofile2>] [-- <file> [files...]]
-- $0 {--mod ...|--code ...} [-- files...]
-- $0 --autoaliases

-- TODO: support -h|--help and help/usage text

local deny_package_access = false
local module_with_integrity_check = false
local modcount = 0
local mode = "lua"

--local argv = arg and (#arg -1) or 0
local io = require"io"
local result = {}
local function output(data)
	result[#result+1] = data
end


local function cat(dirfile)
	assert(dirfile)
	local fd = assert(io.open(dirfile, "r"))
	local data = fd:read('*a')
	fd:close()
	return data
end

local function head(dirfile, n)
	assert(dirfile)
	if not n or n < 1 then return "" end
	local fd = assert(io.open(dirfile, "r"))
	local data = nil
	for _i = 1,n,1 do
		local line = fd:read('*l')
		if not line then break end
		data = ( (data and data .. "\n") or ("") ) .. line
	end
	fd:close()
	return data
end



local function headgrep(dirfile, patn)
	assert(dirfile)
	patn = patn or "^(.+\n_=%[%[\n.*\n%]%] and nil\n)"

	local fd = assert(io.open(dirfile, "r"))

	local function search_begin_in_line(line)
		--if line == "_=[[" then -- usual simple case
		--	return line, "\n", 0
		--end
		local a,b,c,d = line:match( "^(%s*_%s*=%s*%[)(=*)(%[)(.*)$" ) -- <space> '_' <space> '=[' <=> '[' <code>
		if not a then
			return nil, nil, nil
		end
		return a..b..c, d.."\n", #b
	end
	local function search_2_first_line(fd)
		local count = 0
		while true do -- search in the 2 first non-empty lines
--print("cout=", count)
			local line = fd:read("*l")
			if not line then break end
			if count > 2 then break end
			if not (line == "" or line:find("^%s+$")) then -- ignore empty line
				count = count +1
				local b, code, size = search_begin_in_line(line)
				if b then
					return b, code, size
--else print("no match search_begin_in_line in", line)
				end
--else print("empty line")
			end
		end
--print("after while -> nil")
		return nil
	end
	local function search_end(fd, code, size)
		local data = code
--print(data)
		local patn = "^(.*%]"..("="):rep(size).."%][^\n]*\n)"
		local match
		while true do
			match = data:match(patn)
			if match then return match end
			local line = fd:read("*l")
			if not line then break end
			data = data..line.."\n"
		end
		return match
	end

	local b, code, size = search_2_first_line(fd)
--	print(">>", b, code, size)

	local hdata
	if b then
		local match = search_end(fd, code, size)
		if match then
--			print("found ...", b, match)
			hdata = b..match -- shellcode found
		else print("no match search_end")
		end
		-- openshell code found, but not the end
	else
--		print("hdata empty")
		hdata = "" -- no shellcode
	end
	fd:close()
	return hdata -- result: string or nil(error)
end


local function extractshebang(data)
	if data:sub(1,1) ~= "#" then
		return data, nil
	end
	local _b, e, shebang = data:find("^([^\n]+)\n")
	return data:sub(e+1), shebang
end

local function dropshebang(data)
	local data2, _shebang = extractshebang(data)
	return data2
end

local function get_shebang(data)
	local _data2, shebang = extractshebang(data)
	return shebang or false
end

assert( get_shebang("abc") == false )
assert( get_shebang("#!/bin/cool\n#blah\n") == "#!/bin/cool" )
assert( get_shebang("#!/bin/cool\n#blah") == "#!/bin/cool" )
assert( get_shebang("#!/bin/cool\n") == "#!/bin/cool" )
--assert( get_shebang("#!/bin/cool") == "#!/bin/cool" )
assert( get_shebang("# !/bin/cool\n") == "# !/bin/cool" )


do -- selftest
	do
	local data, shebang = extractshebang(
[[#!/bin/sh
test
]]
)
	assert(shebang=="#!/bin/sh")
	assert(data=="test\n")
	end

	do
	local data, shebang = extractshebang(
[[blah blah
test
]]
)
	assert(shebang==nil)
	assert(data=="blah blah\ntest\n")
	end

end -- end of selftests

local function print_no_nl(data)
	output(data)
	return data
end

-- this is a workaround needed when the last character of the module content is end of line and the last line is a comment.
local function autoeol(data)
	local lastchar = data:sub(-1, -1)
	if lastchar ~= "\n" then
		return data .. "\n"
	end
	return data
end

-- TODO: embedding with rawdata (string) and eval the lua code at runtime with loadstring
local function rawpack_module(modname, modpath)
	assert(modname)
	assert(modpath)

-- quoting solution 1 : prefix all '[', ']' with '\'
	local quote       = function(s) return s:gsub('([%]%[])','\\%1') end
	local unquotecode = [[:gsub('\\([%]%[])','%1')]]

-- quoting solution 2 : prefix the pattern of '\[===\[', '\]===\]' with '\' ; FIXME: for now it quote \]===\] or \[===\] or \]===\[ or \[===\[
--	local quote       = function(s) return s:gsub('([%]%[\]===\[%]%[])','\\%1') end
--	local unquotecode = [[:gsub('\\([%]%[\]===\[%]%[])','%1')]]

	local b = [[do local loadstring=_G.loadstring or _G.load;(function(name, rawcode)require"package".preload[name]=function(...)return assert(loadstring(rawcode), "loadstring: "..name.." failed")(...)end;end)("]] .. modname .. [[", (]].."[["
	local e = "]])".. unquotecode .. ")end"

--	if deny_package_access then
--		b = [[do require("package").preload["]] .. modname .. [["] = (function() local package;return function(...)]]
--		e = [[end end)()end;]]
--	end

	if module_with_integrity_check then
		e = e .. [[__ICHECK__[#__ICHECK__+1] = ]].."'"..modname.."'"..[[;__ICHECKCOUNT__=(__ICHECKCOUNT__+1);]]
	end

	-- TODO: improve: include in function code a comment with the name of original file (it will be shown in the trace error message) ?
	local d = "-- <pack "..modname.."> --" -- error message keep the first 45 chars max
	print_no_nl(
		b .. d .."\n"
		.. quote(autoeol(extractshebang(cat(modpath)))) --:gsub('([%]%[])','\\%1')
		.. e .."\n"
	)
	modcount = modcount + 1 -- for integrity check
end

local rawpack2_init_done = false
local rawpack2_finish_done = false


local function rawpack2_init()
	print_no_nl([[do local sources, priorities = {}, {};]])
end

local function rawpack2_module(modname, modpath)
	assert(modname)
	assert(modpath)

-- quoting solution 1 : prefix all '[', ']' with '\'
--	local quote       = function(s) return s:gsub('([%]%[])','\\%1') end
--	local unquotecode = [[:gsub('\\([%]%[])','%1')]]

-- quoting solution 2 : prefix the pattern of '\[===\[', '\]===\]' with '\' ; FIXME: for now it quote \]===\] or \[===\] or \]===\[ or \[===\[
	local quote       = function(s) return s:gsub('([%]%[]===)([%]%[])','\\%1\\%2') end
	local unquotecode = [[:gsub('\\([%]%[]===)\\([%]%[])','%1%2')]]

	if not rawpack2_init_done then
		rawpack2_init_done = not rawpack2_init_done
		if rawpack2_finish_done then rawpack2_finish_done = false end
		rawpack2_init()
	end
	local b = [[assert(not sources["]] .. modname .. [["])]]..[[sources["]] .. modname .. [["]=(]].."\[===\["
	local e = "\]===\])".. unquotecode

	local d = "-- <pack "..modname.."> --" -- error message keep the first 45 chars max
	print_no_nl(
		b .. d .."\n"
		.. quote(autoeol(extractshebang(cat(modpath))))
		.. e .."\n"
	)
	--modcount = modcount + 1 -- for integrity check
end

--local function rawpack2_finish()
--	print_no_nl(
--[[
--local loadstring=_G.loadstring or _G.load; local preload = require"package".preload
--for name, rawcode in pairs(sources) do preload[name]=function(...)return loadstring(rawcode)(...)end end
--end;
--]]
--)
--end

local function rawpack2_finish()
	print_no_nl(
[[
local add
if not pcall(function() add = require"aioruntime".add end) then
        local loadstring=_G.loadstring or _G.load; local preload = require"package".preload
        add = function(name, rawcode)
		if not preload[name] then
		        preload[name] = function(...) return assert(loadstring(rawcode), "loadstring: "..name.." failed")(...) end
		else
			print("WARNING: overwrite "..name)
		end
        end
end
for name, rawcode in pairs(sources) do add(name, rawcode, priorities[name]) end
end;
]]
)
end

local function finish()
	if rawpack2_init_done and not rawpack2_finish_done then
		rawpack2_finish_done = not rawpack2_finish_done
		rawpack2_finish()
	end
end

local function pack_module(modname, modpath)
	assert(modname)
	assert(modpath)

	local b = [[require("package").preload["]] .. modname .. [["] = function(...)]]
	local e = [[end;]]

	if deny_package_access then
		b = [[do require("package").preload["]] .. modname .. [["] = (function() local package;return function(...)]]
		e = [[end end)()end;]]
	end

	if module_with_integrity_check then
		e = e .. [[__ICHECK__[#__ICHECK__+1] = ]].."'"..modname.."'"..[[;__ICHECKCOUNT__=(__ICHECKCOUNT__+1);]]
	end

	-- TODO: improve: include in function code a comment with the name of original file (it will be shown in the trace error message) ?
	-- like [[...-- <pack ]]..modname..[[> --
	print_no_nl(
		b
		.. "-- <pack "..modname.."> --".."\n"
		.. autoeol(extractshebang(cat(modpath)))
		.. e .."\n"
	)
	modcount = modcount + 1 -- for integrity check
end

local function datapack(data, tagsep)
	tagsep = tagsep or ''
	local c = data:sub(1,1)
	if c == "\n" or c == "\r" then
		return "["..tagsep.."["..c..data.."]"..tagsep.."]"
	end
	return "["..tagsep.."["..data.."]"..tagsep.."]"
end

local function datapack_with_unpackcode(data, tagsep)
	return "(" .. datapack(data:gsub("%]", "\\]"), tagsep) .. ")" .. [[:gsub( "\\%]", "]" )]]
end

local function pack_vfile(filename, filepath)
	local data = cat(filepath)
	data = "--fakefs ".. filename .. "\n" .. data
	local code = "do local p=require'package';p.fakefs=(p.fakefs or {});p.fakefs[\"" .. filename .. "\"]=" .. datapack_with_unpackcode(data, '==') .. ";end\n"
--	local code = "local x = " .. datapack_with_unpackcode(data) .. ";io.write(x)"
	output(code)
end

local function autoaliases_code()
	print_no_nl[[
do -- preload auto aliasing...
	local p = require("package").preload
	for k,v in pairs(p) do
		if k:find("%.init$") then
			local short = k:gsub("%.init$", "")
			if not p[short] then
				p[short] = v
			end
		end
	end
end
]]
end

local function integrity_check_code()
	assert(modcount)
	print_no_nl([[
-- integrity check
--print( (__ICHECKCOUNT__ or "").." module(s) embedded.")
assert(__ICHECKCOUNT__==]].. modcount ..[[)
if not __ICHECK__ then
	error("Intergity check failed: no such __ICHECK__", 1)
end
--do for i,v in ipairs(__ICHECK__) do print(i, v) end end
if #__ICHECK__ ~= ]] .. modcount .. [[ then
	error("Intergity check failed: expect ]] .. modcount .. [[, got "..#__ICHECK__.." modules", 1)
end
-- end of integrity check
]])
end

local function cmd_shebang(file)
	local shebang = get_shebang(head(file, 1).."\n")
	print_no_nl( shebang and shebang.."\n" or "")
end

local function cmd_luamod(name, file)
	pack_module(name, file)
end
local function cmd_rawmod(name, file)
	if mode == "raw2" then
		rawpack2_module(name, file)
	else
		rawpack_module(name, file)
	end
end
local function cmd_mod(name, file)
	if mode == "lua" then
		pack_module(name, file)
	elseif mode == "raw" then
		rawpack_module(name, file)
	elseif mode == "raw2" then
		rawpack2_module(name, file)
	else
		error("invalid mode when using --mod", 2)
	end
end
local function cmd_code(file)
	print_no_nl(dropshebang(cat(file)))
end
local function cmd_codehead(n, file)
	print_no_nl( dropshebang( head(file, n).."\n" ) )
end
local function cmd_shellcode(file, patn)
	print_no_nl( headgrep(file, patn) )
	--print_no_nl( dropshebang( headgrep(file, patn).."\n" ) )
end

local function cmd_mode(newmode)
	local modes = {lua=true, raw=true, raw2=true}
	if modes[newmode] then
		mode = newmode
	else
		error("invalid mode", 2)
	end
end
local function cmd_vfile(filename, filepath)
	pack_vfile(filename, filepath)
end
local function cmd_autoaliases()
	autoaliases_code()
end
local function cmd_icheck()
	integrity_check_code()
end
local function cmd_icheckinit()
	print_no_nl("local __ICHECK__ = {};__ICHECKCOUNT__=0;\n")
	module_with_integrity_check = true
end
local function cmd_require(modname)
	assert(modname:find('^[a-zA-Z0-9%._-]+$'), "error: invalid modname")
	local code = [[require("]]..modname..[[")]] -- FIXME: quote
	print_no_nl( code.."\n" )
end
local function cmd_luacode(data)
	local code = data -- FIXME: quote
	print_no_nl( code.."\n" )
end
local function cmd_finish()
	finish()
	io.write(table.concat(result or {}, ""))
	result = {}
end

local _M = {}
_M._VERSION = "lua-aio 0.5"
_M._LICENSE = "MIT"

_M.shebang	= cmd_shebang
_M.luamod	= cmd_luamod
_M.rawmod	= cmd_rawmod
_M.mod		= cmd_mod
_M.code		= cmd_code
_M.codehead	= cmd_codehead -- obsolete
_M.shellcode	= cmd_shellcode
_M.mode		= cmd_mode
_M.vfile	= cmd_vfile
_M.autoaliases	= cmd_autoaliases
_M.icheck	= cmd_icheck
_M.ichechinit	= cmd_icheckinit
_M.require	= cmd_require
_M.luacode	= cmd_luacode
_M.finish	= cmd_finish

local function wrap(f)
	return function(...)
		f(...)
		return _M
	end
end

for k,v in pairs(_M) do
	if type(v) == "function" then
		_M[k] = wrap(v)
	end
end

return _M
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["strict"])sources["strict"]=([===[-- <pack strict> --
--[[--
 Checks uses of undeclared global variables.

 All global variables must be 'declared' through a regular
 assignment (even assigning `nil` will do) in a top-level
 chunk before being used anywhere or assigned to inside a function.

 To use this module, just require it near the start of your program.

 From Lua distribution (`etc/strict.lua`).

 @module std.strict
]]

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
  if not mt.__declared[n] then
    local w = what ()
    if w ~= "main" and w ~= "C" then
      error ("assignment to undeclared variable '" .. n .. "'", 2)
    end
    mt.__declared[n] = true
  end
  rawset (t, n, v)
end


--- Detect dereference of undeclared global.
-- @function __index
-- @tparam table t `_G`
-- @string n name of the variable being dereferenced
mt.__index = function (t, n)
  if not mt.__declared[n] and what () ~= "C" then
    error ("variable '" .. n .. "' is not declared", 2)
  end
  return rawget (t, n)
end
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["i"])sources["i"]=([===[-- <pack i> --

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

local function needany(t_names)
	for i,name in ipairs(t_names) do
		local v = needone(name)
		if v then
			return v
		end
	end
	return false
end


local readonly = function() error("not allowed", 2) end

local t_need_all = setmetatable({
}, {
	__call = function(_, t_names)
		return needall(t_names)
	end,
	__newindex = readonly,
})

local t_need_any = setmetatable({
}, {
	__call = function(_, t_names)
		return needany(t_names)
	end,
	__newindex = readonly,
--	metatable = false,
})


_M.need = setmetatable({
	all = t_need_all,
	any = t_need_any,
}, {
	__call = function(_, name, name2)
		if name == _M then
			name = name2
		end
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

]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["featured"])sources["featured"]=([===[-- <pack featured> --
local _M = {}

local featured_keys = {
	["class-system"] = {"30log-featured", "secs-featured", "middleclass-featured", "hump.class-featured", },
	["lpeg"] = {"lpeg", "lulpeg", "lpeglj", },
	["json"] = {"lunajson-featured", },
}

featured_keys.class = function()
	return (require "i".need.any(featured_keys["class-system"]) or {}).class
end

featured_keys.instance = function()
	return require "i".need.any(featured_keys["class-system"]).instance
end

setmetatable(_M, {
	__call = function(_, name, ...)
		assert(name)
		local found = featured_keys[name]
		assert(found)
		if type(found) == "function" then
			return found(name, ...)
		else
			return require "i".need.any(found)
		end
	end,
})

return _M
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["secs"])sources["secs"]=([===[-- <pack secs> --
--[[
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
]]

local class_mt = {}

function class_mt:__index(key)
    return self.__baseclass[key]
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
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["secs-featured"])sources["secs-featured"]=([===[-- <pack secs-featured> --
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

local _M = setmetatable({}, {
	__call = function(_, ...)
		return common.class(...)
	end,
	__index = common,
	__newindex = function() error("read-only", 2) end,
	__metatable = false,
})

--pcall(function() require("i"):register("secs", _M) end)
return _M
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["middleclass"])sources["middleclass"]=([===[-- <pack middleclass> --
local middleclass = {
  _VERSION     = 'middleclass v3.0.1',
  _DESCRIPTION = 'Object Orientation for Lua',
  _URL         = 'https://github.com/kikito/middleclass',
  _LICENSE     = [[
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
  ]]
}

local function _setClassDictionariesMetatables(aClass)
  local dict = aClass.__instanceDict
  dict.__index = dict

  local super = aClass.super
  if super then
    local superStatic = super.static
    setmetatable(dict, super.__instanceDict)
    setmetatable(aClass.static, { __index = function(_,k) return dict[k] or superStatic[k] end })
  else
    setmetatable(aClass.static, { __index = function(_,k) return dict[k] end })
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
    local method = aClass.super[name]
    assert( type(method)=='function', tostring(aClass) .. " doesn't implement metamethod '" .. name .. "'" )
    return method(...)
  end
end

local function _setClassMetamethods(aClass)
  for _,m in ipairs(aClass.__metamethods) do
    aClass[m]= _createLookupMetamethod(aClass, m)
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
    if name ~= "included" and name ~= "static" then aClass[name] = method end
  end
  if mixin.static then
    for name,method in pairs(mixin.static) do
      aClass.static[name] = method
    end
  end
  if type(mixin.included)=="function" then mixin:included(aClass) end
  aClass.__mixins[mixin] = true
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
  self.subclasses[subclass] = true
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
         ( self.__mixins[mixin] or
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
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["middleclass-featured"])sources["middleclass-featured"]=([===[-- <pack middleclass-featured> --
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
			c[i] = v
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

local _M = setmetatable({}, {
	__call = function(_, ...)
		return common.class(...)
	end,
	__index = common,
	__newindex = function() error("read-only", 2) end,
	__metatable = false,
})

--pcall(function() require("i"):register("middleclass", _M) end)
return _M
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["30log"])sources["30log"]=([===[-- <pack 30log> --
local assert       = assert
local pairs        = pairs
local type         = type
local tostring     = tostring
local setmetatable = setmetatable

local baseMt     = {}
local _instances = setmetatable({},{__mode='k'})
local _classes   = setmetatable({},{__mode='k'})
local _class

local function assert_class(class, method) 
  assert(_classes[class], ('Wrong method call. Expected class:%s.'):format(method)) 
end

local function deep_copy(t, dest, aType)
  t = t or {}; local r = dest or {}
  for k,v in pairs(t) do
    if aType and type(v)==aType then 
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
  assert_class(self, 'new(...) or class(...)')
  local instance = {class = self}
  _instances[instance] = tostring(instance)
  setmetatable(instance,self)
  
  if self.init then
    if type(self.init) == 'table' then 
      deep_copy(self.init, instance)
    else 
      self.init(instance, ...) 
    end
  end
  return instance
end

local function extend(self, name, extra_params)
  assert_class(self, 'extend(...)')
  local heir = {}
  _classes[heir] = tostring(heir)
  deep_copy(extra_params, deep_copy(self, heir))
  heir.name = extra_params and extra_params.name or name
  heir.__index = heir
  heir.super = self
  return setmetatable(heir,self)
end

baseMt = {
  __call = function (self,...) return self:new(...) end,
  __tostring = function(self,...)
    if _instances[self] then
      return 
      ("instance of '%s' (%s)")
        :format(rawget(self.class,'name') or '?', _instances[self])
    end
    return _classes[self] and 
      ("class '%s' (%s)")
        :format(rawget(self,'name') or '?',_classes[self]) or self
end}

_classes[baseMt] = tostring(baseMt)
setmetatable(baseMt, {__tostring = baseMt.__tostring})

local class = {
  isClass = function(class, ofsuper)
    local isclass = not not _classes[class]
    if ofsuper then
      return isclass and (class.super == ofsuper)
    end
    return isclass 
  end,
  isInstance = function(instance, ofclass) 
    local isinstance = not not _instances[instance]
    if ofclass then
      return isinstance and (instance.class == ofclass)
    end
    return isinstance 
  end
}
  
_class = function(name, attr)
  local c = deep_copy(attr)
  c.mixins = setmetatable({},{__mode='k'})
  _classes[c] = tostring(c)
  c.name       = name
  c.__tostring = baseMt.__tostring
  c.__call     = baseMt.__call
  
  c.include = function(self,mixin)
    assert_class(self, 'include(mixin)')
    self.mixins[mixin] = true
    return deep_copy(mixin, self, 'function') 
  end
  
  c.new = instantiate
  c.extend = extend
  c.__index = c
  
  c.includes = function(self,mixin) 
    assert_class(self,'includes(mixin)')
    return not not (self.mixins[mixin] or (self.super and self.super:includes(mixin)))
  end
  
  c.extends = function(self, class)
    assert_class(self, 'extends(class)')
    local super = self
    repeat 
      super = super.super
    until (super == class or super == nil)
    return class and (super == class) 
  end
  
  return setmetatable(c, baseMt) 
end

class._DESCRIPTION = '30 lines library for object orientation in Lua'
class._VERSION     = '30log v1.0.0'
class._URL         = 'http://github.com/Yonaba/30log'
class._LICENSE     = 'MIT LICENSE <http://www.opensource.org/licenses/mit-license.php>'

return setmetatable(class,{__call = function(_,...) return _class(...) end })
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["30log-featured"])sources["30log-featured"]=([===[-- <pack 30log-featured> --
local class = require "30log"

local common = {}
common.class = function(name, prototype, parent)
	local klass = class():extend(nil,parent):extend(nil,prototype)
	klass.init = (prototype or {}).init or (parent or {}).init
	klass.name = name
	return klass
end
common.instance = function(class, ...)
        return class:new(...)
end
common.__BY = "30log"

local _M = setmetatable({}, {
	__call = function(_, ...)
		return common.class(...)
	end,
	__index = common,
	__newindex = function() error("read-only", 2) end,
	__metatable = false,
})

--pcall(function() require("i"):register("30log", _M) end)
return _M
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["hump.class"])sources["hump.class"]=([===[-- <pack hump.class> --
--[[
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
]]--

local function include_helper(to, from, seen)
	if from == nil then
		return to
	elseif type(from) ~= 'table' then
		return from
	elseif seen[from] then
		return seen[from]
	end

	seen[from] = to
	for k,v in pairs(from) do
		k = include_helper({}, k, seen) -- keys might also be tables
		if to[k] == nil then
			to[k] = include_helper({}, v, seen)
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
			other = _G[other]
		end
		include(class, other)
	end

	-- class implementation
	class.__index = class
	class.init    = class.init    or class[1] or function() end
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
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["hump.class-featured"])sources["hump.class-featured"]=([===[-- <pack hump.class-featured> --

-- interface for cross class-system compatibility (see https://github.com/bartbes/Class-Commons).

local humpclass = require "hump.class"
local new = assert(humpclass.new)

local common = {}
function common.class(name, prototype, parent)
	local c = new{__includes = {prototype, parent}}
	assert(c.new==nil)
	function c:new(...) -- implement the class:new => new instance
		return c(...)
	end
	return c
end
function common.instance(class, ...)
        return class(...)
end
common.__BY = "hump.class"



local _M = setmetatable({}, {
	__call = function(_, ...)
		return common.class(...)
	end,
	__index = common,
	__newindex = function() error("read-only", 2) end,
	__metatable = false,
})

--pcall(function() require("i"):register("hump.class", _M) end)
return _M
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["compat_env"])sources["compat_env"]=([===[-- <pack compat_env> --
--[[
  compat_env - see README for details.
  (c) 2012 David Manura.  Licensed under Lua 5.1/5.2 terms (MIT license).
--]]

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
  local setfenv = _G.setfenv
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
        error("thread environments unsupported in Lua 5.2", 3) --[*]
      end
      f = debug.getinfo(f+2, 'f').func
    elseif type(f) ~= 'function' then
      error(("bad argument #1 to '%s' (number expected, got %s)")
            :format(type(name, f)), 2)
    end
    return f
  end
  -- [*] might simulate with table keyed by coroutine.running()
  
  -- 5.1 style `setfenv` implemented in 5.2
  function M.setfenv(f, t)
    local f = envhelper(f, 'setfenv')
    local up, val, unknown = envlookup(f)
    if up then
      debug.upvaluejoin(f, up, function() return up end, 1) --unique upval[*]
      debug.setupvalue(f, up, t)
    else
      local what = debug.getinfo(f, 'S').what
      if what ~= 'Lua' and what ~= 'main' then -- not Lua func
        error("'setfenv' cannot change environment of given object", 2)
      end -- else ignore no _ENV upvalue (warning: incompatible with 5.1)
    end
    return f  -- invariant: original f ~= 0
  end
  -- [*] http://lua-users.org/lists/lua-l/2010-06/msg00313.html

  -- 5.1 style `getfenv` implemented in 5.2
  function M.getfenv(f)
    if f == 0 or f == nil then return _G end -- simulated behavior
    local f = envhelper(f, 'setfenv')
    local up, val = envlookup(f)
    if not up then return _G end -- simulated behavior [**]
    return val
  end
  -- [**] possible reasons: no _ENV upvalue, C function
end


return M
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["bit.numberlua"])sources["bit.numberlua"]=([===[-- <pack bit.numberlua> --
--[[

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
  to or cannot  install a popular C based bit library like BitOp 'bit' [1]
  (which comes pre-installed with LuaJIT) or 'bit32' (which comes
  pre-installed with Lua 5.2) but want a similar interface.
  
  This modules represents bit arrays as non-negative Lua numbers. [1]
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
  Some attempt was made to make these similar to the Lua 5.2 [2]
  and LuaJit BitOp [3] libraries, but this is not fully tested and there
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

  BIT.extract(x, field [, width]) --> z
  
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
    bit32.extract (x, field [, width]) --> z
    bit32.replace (x, v, field [, width]) --> z
    bit32.lrotate (x, disp) --> z
    bit32.lshift (x, disp) --> z
    bit32.rrotate (x, disp) --> z
    bit32.rshift (x, disp) --> z

  BIT.bit
  
    This table contains functions that aim to provide 100% compatibility
    with the LuaBitOp "bit" library (from LuaJIT).
    
    bit.tobit(x) --> y
    bit.tohex(x [,n]) --> y
    bit.bnot(x) --> y
    bit.bor(x1 [,x2...]) --> y
    bit.band(x1 [,x2...]) --> y
    bit.bxor(x1 [,x2...]) --> y
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

  [1] http://lua-users.org/wiki/FloatingPoint
  [2] http://www.lua.org/manual/5.2/
  [3] http://bitop.luajit.org/
  
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

--]]

local M = {_TYPE='module', _NAME='bit.numberlua', _VERSION='0.3.1.20120131'}

local floor = math.floor

local MOD = 2^32
local MODM = MOD-1

local function memoize(f)
  local mt = {}
  local t = setmetatable({}, mt)
  function mt:__index(k)
    local v = f(k); t[k] = v
    return v
  end
  return t
end

local function make_bitop_uncached(t, m)
  local function bitop(a, b)
    local res,p = 0,1
    while a ~= 0 and b ~= 0 do
      local am, bm = a%m, b%m
      res = res + t[am][bm]*p
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

M.bxor = make_bitop {[0]={[0]=0,[1]=1},[1]={[0]=1,[1]=0}, n=4}
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
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["isolation"])sources["isolation"]=([===[-- <pack isolation> --
do local sources, priorities = {}, {};assert(not sources["newpackage"])sources["newpackage"]=(\[===\[-- <pack newpackage> --

-- ----------------------------------------------------------

--local loadlib = loadlib
--local setmetatable = setmetatable
--local setfenv = setfenv

local assert, error, ipairs, type = assert, error, ipairs, type
local find, format, gmatch, gsub, sub = string.find, string.format, string.gmatch or string.gfind, string.gsub, string.sub
local loadfile = loadfile

local function lassert(cond, msg, lvl)
	if not cond then
		error(msg, lvl+1)
	end
	return cond
end

-- this function is used to get the n-th line of the str, should be improved !!
local function string_line(str, n)
	if not str then return end
	local f = string.gmatch(str, "(.-)\n")
	local r
	for i = 1,n+1 do
		local v = f()
		if not v then break end
		r = v
	end
	return r
end

local function bigfunction_new(with_loaded, with_preloaded)

--
local _PACKAGE = {}
local _LOADED = with_loaded or {}
local _PRELOAD = with_preloaded or {}
local _SEARCHERS  = {}

--
-- looks for a file `name' in given path
--
local function _searchpath(name, path, sep, rep)
	sep = sep or '.'
	rep = rep or string_line(_PACKAGE.config, 1) or '/'
	local LUA_PATH_MARK = '?'
	local LUA_DIRSEP = '/'
	name = gsub(name, "%.", LUA_DIRSEP)
	lassert(type(path) == "string", format("path must be a string, got %s", type(pname)), 2)
	for c in gmatch(path, "[^;]+") do
		c = gsub(c, "%"..LUA_PATH_MARK, name)
		local f = io.open(c) -- FIXME: use virtual FS here ???
		if f then
			f:close()
			return c
		end
	end
	return nil -- not found
end

--
-- check whether library is already loaded
--
local function searcher_preload(name)
	lassert(type(name) == "string", format("bad argument #1 to `require' (string expected, got %s)", type(name)), 2)
	lassert(type(_PRELOAD) == "table", "`package.preload' must be a table", 2)
	return _PRELOAD[name]
end

--
-- Lua library searcher
--
local function searcher_Lua(name)
	lassert(type(name) == "string", format("bad argument #1 to `require' (string expected, got %s)", type(name)), 2)
	local filename = _searchpath(name, _PACKAGE.path)
	if not filename then
		return false
	end
	local f, err = loadfile(filename)
	if not f then
		error(format("error loading module `%s' (%s)", name, err))
	end
	return f
end

--
-- iterate over available searchers
--
local function iload(modname, searchers)
	lassert(type(searchers) == "table", "`package.searchers' must be a table", 2)
	local msg = ""
	for _, searcher in ipairs(searchers) do
		local loader, param = searcher(modname)
		if type(loader) == "function" then
			return loader, param -- success
		end
		if type(loader) == "string" then
			-- `loader` is actually an error message
			msg = msg .. loader
		end
	end
	error("module `" .. modname .. "' not found: "..msg, 2)
end

--
-- new require
--
local function _require(modname)

	local function checkmodname(s)
		local t = type(s)
		if t == "string" then
		        return s
		elseif t == "number" then
			return tostring(s)
		else
			error("bad argument #1 to `require' (string expected, got "..t..")", 3)
		end
	end

	modname = checkmodname(modname)
	local p = _LOADED[modname]
	if p then -- is it there?
		return p -- package is already loaded
	end

	local loader, param = iload(modname, _SEARCHERS)

	local res = loader(modname, param)
	if res ~= nil then
		p = res
	elseif not _LOADED[modname] then
		p = true
	end

	_LOADED[modname] = p
	return p
end


_SEARCHERS[#_SEARCHERS+1] = searcher_preload
_SEARCHERS[#_SEARCHERS+1] = searcher_Lua
--_SEARCHERS[#_SEARCHERS+1] = searcher_C
--_SEARCHERS[#_SEARCHERS+1] = searcher_Croot,

_LOADED.package = _PACKAGE
do
	local package = _PACKAGE

	--package.config	= nil -- setup by parent
	--package.cpath		= "" -- setup by parent
	package.loaded		= _LOADED
	--package.loadlib
	--package.path		= "./?.lua;./?/init.lua" -- setup by parent
	package.preload		= _PRELOAD
	package.searchers	= _SEARCHERS
	package.searchpath	= _searchpath
end
return _require, _PACKAGE
end -- big function

return {new = bigfunction_new}

-- ----------------------------------------------------------

-- make the list of currently loaded modules (without restricted.*)
--local package = require("package")
--local loadlist = {}
--for modname in pairs(package.loaded) do
--	if not modname:find("^restricted%.") then
--		loadlist[#loadlist+1] = modname
--	end
--end

--[[ lua 5.1
cpath   ./?.so;/usr/local/lib/lua/5.1/?.so;/usr/lib/x86_64-linux-gnu/lua/5.1/?.so;/usr/lib/lua/5.1/?.so;/usr/local/lib/lua/5.1/loadall.so
path    ./?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?/init.lua;/usr/local/lib/lua/5.1/?.lua;/usr/local/lib/lua/5.1/?/init.lua;/usr/share/lua/5.1/?.lua;/usr/share/lua/5.1/?/init.lua
config  "/\n;\n?\n!\n-\n"
preload table: 0x3865c40
loaded  table: 0x3863bd0
loaders table: 0x38656b0
loadlib function: 0x38655f0
seeall  function: 0x3865650
]]--
--[[ lua 5.2
cpath   /usr/local/lib/lua/5.2/?.so;/usr/lib/x86_64-linux-gnu/lua/5.2/?.so;/usr/lib/lua/5.2/?.so;/usr/local/lib/lua/5.2/loadall.so;./?.so
path    /usr/local/share/lua/5.2/?.lua;/usr/local/share/lua/5.2/?/init.lua;/usr/local/lib/lua/5.2/?.lua;/usr/local/lib/lua/5.2/?/init.lua;./?.lua;/usr/share/lua/5.2/?.lua;/usr/share/lua/5.2/?/init.lua;./?.lua
config  "/\n;\n?\n!\n-\n"
preload table: 0x3059560
loaded  table: 0x3058840
loaders table: 0x3059330 <- compat stuff ??? == searchers
loadlib function: 0x4217d0
seeall  function: 0x4213c0

searchpath      function: 0x421b10
searchers       table: 0x3059330
]]--

--
-- new package.seeall function
--
--function _package_seeall(module)
--	local t = type(module)
--	assert(t == "table", "bad argument #1 to package.seeall (table expected, got "..t..")")
--	local meta = getmetatable(module)
--	if not meta then
--		meta = {}
--		setmetatable(module, meta)
--	end
--	meta.__index = _G
--end

--
-- new module function
--
--local function _module(modname, ...)
--	local ns = _LOADED[modname]
--	if type(ns) ~= "table" then
--		-- findtable
--		local function findtable(t, f)
--			assert(type(f)=="string", "not a valid field name ("..tostring(f)..")")
--			local ff = f.."."
--			local ok, e, w = find(ff, '(.-)%.', 1)
--			while ok do
--				local nt = rawget(t, w)
--				if not nt then
--					nt = {}
--					t[w] = nt
--				elseif type(t) ~= "table" then
--					return sub(f, e+1)
--				end
--				t = nt
--				ok, e, w = find(ff, '(.-)%.', e+1)
--			end
--			return t
--		end
--		ns = findtable(_G, modname)
--		if not ns then
--			error(format("name conflict for module '%s'", modname), 2)
--		end
--		_LOADED[modname] = ns
--	end
--	if not ns._NAME then
--		ns._NAME = modname
--		ns._M = ns
--		ns._PACKAGE = gsub(modname, "[^.]*$", "")
--	end
--	setfenv(2, ns)
--	for i, f in ipairs(arg) do
--		f(ns)
--	end
--end


--local POF = 'luaopen_'
--local LUA_IGMARK = ':'
--
--local function mkfuncname(name)
--	local LUA_OFSEP = '_'
--	name = gsub(name, "^.*%"..LUA_IGMARK, "")
--	name = gsub(name, "%.", LUA_OFSEP)
--	return POF..name
--end
--
--local function old_mkfuncname(name)
--	local OLD_LUA_OFSEP = ''
--	--name = gsub(name, "^.*%"..LUA_IGMARK, "")
--	name = gsub(name, "%.", OLD_LUA_OFSEP)
--	return POF..name
--end
--
----
---- C library searcher
----
--local function searcher_C(name)
--	lassert(type(name) == "string", format(
--		"bad argument #1 to `require' (string expected, got %s)", type(name)), 2)
--	local filename = _searchpath(name, _PACKAGE.cpath)
--	if not filename then
--		return false
--	end
--	local funcname = mkfuncname(name)
--	local f, err = loadlib(filename, funcname)
--	if not f then
--		funcname = old_mkfuncname(name)
--		f, err = loadlib(filename, funcname)
--		if not f then
--			error(format("error loading module `%s' (%s)", name, err))
--		end
--	end
--	return f
--end
--
--local function searcher_Croot(name)
--	local p = gsub(name, "^([^.]*).-$", "%1")
--	if p == "" then
--		return
--	end
--	local filename = _searchpath(p, "cpath")
--	if not filename then
--		return
--	end
--	local funcname = mkfuncname(name)
--	local f, err, where = loadlib(filename, funcname)
--	if f then
--		return f
--	elseif where ~= "init" then
--		error(format("error loading module `%s' (%s)", name, err))
--	end
--end


\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["isolation.defaults"])sources["isolation.defaults"]=(\[===\[-- <pack isolation.defaults> --
local defaultconfig = {}
defaultconfig.package_wanted = {
	"bit32", "coroutine", "debug", "io", "math", "os", "string", "table",
}
defaultconfig.g_content = {
	"table", "string",
}

defaultconfig.package = "all"

local _M = {
	defaultconfig = defaultconfig,
}
return _M
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["restricted.debug"])sources["restricted.debug"]=(\[===\[-- <pack restricted.debug> --

local _debug = {}
return _debug
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["restricted.bit32"])sources["restricted.bit32"]=(\[===\[-- <pack restricted.bit32> --
return {}
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["restricted.io"])sources["restricted.io"]=(\[===\[-- <pack restricted.io> --
local io = require("io")

local _M = {}
--io.close
--io.flush
--io.input
--io.lines
--io.open
--io.output
--io.popen
--io.read
--io.stderr
--io.stdin
--io.stdout
--io.tmpfile
--io.type
--io.write
return _M
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["restricted.os"])sources["restricted.os"]=(\[===\[-- <pack restricted.os> --
local os = require("os")

local _M = {}

for i,k in ipairs{
	"clock",
--	"date", -- See [date_unsafe] FIXME: On non-POSIX systems, this function may be not thread safe
	"difftime",
--execute
--exit
--getenv
--remove
--rename
--setlocale
	"time",
--tmpname
} do
	_M[k]=os[k]
end

-- os.date is unsafe : The Lua 5.3 manuals say "On non-POSIX systems, this function may be not thread safe"
-- See also : https://github.com/APItools/sandbox.lua/issues/7#issuecomment-129259145
-- > I believe it was intentional. See the comment. https://github.com/APItools/sandbox.lua/blob/a4c0a9ad3d3e8b5326b53188b640d69de2539313/sandbox.lua#L48
-- > Probably based on http://lua-users.org/wiki/SandBoxes
-- >     os.date - UNSAFE - This can crash on some platforms (undocumented). For example, os.date'%v'. It is reported that this will be fixed in 5.2 or 5.1.3.

return _M
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["restricted.table"])sources["restricted.table"]=(\[===\[-- <pack restricted.table> --
local table = require "table"

local _M = {}
_M.insert = table.insert
_M.maxn = table.maxn
_M.remove = table.remove
_M.sort = table.sort
_M.unpack = table.unpack
_M.pack = table.pack

return _M
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["restricted._file"])sources["restricted._file"]=(\[===\[-- <pack restricted._file> --
local file = require("file")

local _file = {}
--file:close
--file:flush
--file:lines
--file:read
--file:seek
--file:setvbuf
--file:write
return _file
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["restricted.string"])sources["restricted.string"]=(\[===\[-- <pack restricted.string> --

local string = require "string"
local _M = {}
for i,k in pairs{
	"byte",
	"char",
	"find",
	"format",
	"gmatch",
	"gsub",
	"len",
	"lower",
	"match",
	"reverse",
	"sub",
	"upper",
} do
	_M[k]=string[k]
end

return setmetatable({}, {
	__index=_M,
	__newindex=function() error("readonly", 2) end,
	__metatable=false,
})
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["restricted.coroutine"])sources["restricted.coroutine"]=(\[===\[-- <pack restricted.coroutine> --
local coroutine = require "coroutine"
local _M = {
	create = coroutine.create,
	resume = coroutine.resume,
	running = coroutine.running,
	status = coroutine.status,
	wrap = coroutine.wrap,
	yield = coroutine.yield,
}

return _M
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["restricted.math"])sources["restricted.math"]=(\[===\[-- <pack restricted.math> --
local math = require("math")
local _M = {}

for i,k in ipairs({
	"abs", "acos", "asin", "atan", "atan2", "ceil", "cos", "cosh",
	"deg", "exp", "floor", "fmod", "frexp", "huge", "ldexp", "log",
	"log10", "max", "min", "modf", "pi", "pow", "rad", "random",
	--"randomseed",
	"sin", "sinh", "sqrt", "tan", "tanh",
}) do
	_M[k] = math[k]
end

-- lock metatable ?
return _M
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
local add
if not pcall(function() add = require"aioruntime".add end) then
        local loadstring=_G.loadstring or _G.load; local preload = require"package".preload
        add = function(name, rawcode)
		if not preload[name] then
		        preload[name] = function(...) return assert(loadstring(rawcode), "loadstring: "..name.." failed")(...) end
		else
			print("WARNING: overwrite "..name)
		end
        end
end
for name, rawcode in pairs(sources) do add(name, rawcode, priorities[name]) end
end;
local _M = {}

local function merge(dest, source)
	for k,v in pairs(source) do
		dest[k] = dest[k] or v
	end
	return dest
end
local function keysfrom(source, keys)
	assert(type(source)=="table")
	assert(type(keys)=="table")
	local t = {}
	for i,k in ipairs(keys) do
		t[k] = source[k]
	end
	return t
end

local function populate_package(loaded, modnames)
	for i,modname in ipairs(modnames) do
		loaded[modname] = require("restricted."..modname)
	end
end


-- getmetatable - UNSAFE
-- - Note that getmetatable"" returns the metatable of strings.
--   Modification of the contents of that metatable can break code outside the sandbox that relies on this string behavior.
--   Similar cases may exist unless objects are protected appropriately via __metatable. Ideally __metatable should be immutable.
-- UNSAFE : http://lua-users.org/wiki/SandBoxes
local function make_safe_getsetmetatable(unsafe_getmetatable, unsafe_setmetatable)
	local safe_getmetatable, safe_setmetatable
	do
		local mt_string = unsafe_getmetatable("")
		safe_getmetatable = function(t)
			local mt = unsafe_getmetatable(t)
			if mt_string == mt then
				return false
			end
			return mt
		end
		safe_setmetatable = function(t, mt)
			if mt_string == t or mt_string == mt then
				return t
			end
			return unsafe_setmetatable(t, mt)
		end
	end
	return safe_getmetatable, safe_setmetatable
end

local function setup_g(g, master, config)
	assert(type(g)=="table")
	assert(type(master)=="table")
	assert(type(config)=="table")

	for i,k in ipairs{
		"_VERSION", "assert", "error", "ipairs", "next", "pairs",
		"pcall", "select", "tonumber", "tostring", "type", "unpack","xpcall",
	} do
		g[k]=master[k]
	end

	local safe_getmetatable, safe_setmetatable = make_safe_getsetmetatable(master.getmetatable,master.setmetatable)
	g.getmetatable = assert(safe_getmetatable)
	g.setmetatable = assert(safe_setmetatable)
	g.print = function() end
	g["_G"] = g -- self
end
local function setup_package(package, config)
	package.config	= require"package".config or "/\n;\n?\n!\n-\n"
	package.cpath	= "" -- nil?
	package.path	= "./?.lua;./?/init.lua"
	package.loaders	= package.searchers -- compat
	package.loadlib	= nil
end
local function cross_setup_g_package(g, package, config)
	local loaded = package.loaded
	loaded["_G"]	= g		-- add _G as loaded modules

	-- global register all modules
	--for k,v in pairs(loaded) do g[k] = v end
	--g.debug = nil -- except debug

	if config.package == "minimal" then
		populate_package(loaded, {"table", "string"})
	elseif config.package == "all" then
		populate_package(loaded, config.package_wanted)
	end
	for i,k in ipairs(config.g_content) do
		if loaded[k] then
			g[k] = loaded[k]
		end
	end
end


local function new_env(master, conf)
	assert(master) -- the real _G
	local config = {}
	for k,v in pairs(_M.defaultconfig) do config[k]=v end
	if type(conf) == "table" then
		for k,v in pairs(conf) do config[k]=v end
	end
	assert( config.package )
	assert( config.package_wanted )
	assert( config.g_content )

	local g = {}

	local req, package = require("newpackage").new()
	assert(req("package") == package)
	assert(package.loaded.package == package)

	setup_g(g, master, config)
	setup_package(package, config)
	cross_setup_g_package(g, package, config)

	g.require = req

	return g
end

local ce_load = require("compat_env").load
--local function run(f, env)
--	return ce_load(f, nil, nil, env)
--end

local funcs = {
	dostring = function(self, str, ...)
		return pcall(function(...) return ce_load(str, str, 't', self.env)(...) end, ...)
	end,
	run = function(self, str, ...)
		local function filter(ok, ...)
			self.lastok = ok
			if not ok then
				self.lasterr = ...
				return nil
			end
			self.lasterr = nil
			return ...
		end
		if type(str) == "function" then
			print("STR = function here", #{...}, ...)
			return require"compat_env".setfenv(f, self.env)(...)
			--return filter(pcall(function(...)
			--	return assert(ce_load(string.dump(str), nil, 'b', self.env))(...)
			--end))
		end
		return filter( pcall( function(...)
			return assert(ce_load(str, str, 't', self.env))(...)
		end) )
	end,
	dofunction = function(self, func, ...)
		assert( type(func) == "function")
		return pcall(function(...) return func(...) end, ...)
	end,
	runf = function(self, func, ...)
		assert( type(func) == "function")
		local ok, t_ret = pcall(function(...) return {func(...)} end, ...)
		if ok then
			return t_ret
		else
			return nil
		end
	end,
}
local new_mt = { __index = funcs, }

local function new(master, conf)
	local e = new_env(master or _G, conf)
	local o = setmetatable( {env = e}, new_mt)
	assert(o.env)
	return o
end

local defaultconfig = require "isolation.defaults".defaultconfig

--_M.new_env = new_env
_M.new = new
_M.run = run
_M.defaultconfig = defaultconfig

return _M
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lulpeg"])sources["lulpeg"]=([===[-- <pack lulpeg> --
do local sources, priorities = {}, {};assert(not sources["util"])sources["util"]=(\[===\[-- <pack util> --

-- A collection of general purpose helpers.

--[[DGB]] local debug = require"debug"

local getmetatable, setmetatable, load, loadstring, next
    , pairs, pcall, print, rawget, rawset, select, tostring
    , type, unpack
    = getmetatable, setmetatable, load, loadstring, next
    , pairs, pcall, print, rawget, rawset, select, tostring
    , type, unpack

local m, s, t = require"math", require"string", require"table"

local m_max, s_match, s_gsub, t_concat, t_insert
    = m.max, s.match, s.gsub, t.concat, t.insert

local compat = require"compat"


-- No globals definition:

local
function nop () end

local noglobals, getglobal, setglobal if pcall and not compat.lua52 and not release then
    local function errR (_,i)
        error("illegal global read: " .. tostring(i), 2)
    end
    local function errW (_,i, v)
        error("illegal global write: " .. tostring(i)..": "..tostring(v), 2)
    end
    local env = setmetatable({}, { __index=errR, __newindex=errW })
    noglobals = function()
        pcall(setfenv, 3, env)
    end
    function getglobal(k) rawget(env, k) end
    function setglobal(k, v) rawset(env, k, v) end
else
    noglobals = nop
end



local _ENV = noglobals() ------------------------------------------------------



local util = {
    nop = nop,
    noglobals = noglobals,
    getglobal = getglobal,
    setglobal = setglobal
}

util.unpack = t.unpack or unpack
util.pack = t.pack or function(...) return { n = select('#', ...), ... } end


if compat.lua51 then
    local old_load = load

   function util.load (ld, source, mode, env)
     -- We ignore mode. Both source and bytecode can be loaded.
     local fun
     if type (ld) == 'string' then
       fun = loadstring (ld)
     else
       fun = old_load (ld, source)
     end
     if env then
       setfenv (fun, env)
     end
     return fun
   end
else
    util.load = load
end

if compat.luajit and compat.jit then
    function util.max (ary)
        local max = 0
        for i = 1, #ary do
            max = m_max(max,ary[i])
        end
        return max
    end
elseif compat.luajit then
    local t_unpack = util.unpack
    function util.max (ary)
     local len = #ary
        if len <=30 or len > 10240 then
            local max = 0
            for i = 1, #ary do
                local j = ary[i]
                if j > max then max = j end
            end
            return max
        else
            return m_max(t_unpack(ary))
        end
    end
else
    local t_unpack = util.unpack
    local safe_len = 1000
    function util.max(array)
        -- Thanks to Robert G. Jakabosky for this implementation.
        local len = #array
        if len == 0 then return -1 end -- FIXME: shouldn't this be `return -1`?
        local off = 1
        local off_end = safe_len
        local max = array[1] -- seed max.
        repeat
            if off_end > len then off_end = len end
            local seg_max = m_max(t_unpack(array, off, off_end))
            if seg_max > max then
                max = seg_max
            end
            off = off + safe_len
            off_end = off_end + safe_len
        until off >= len
        return max
    end
end


local
function setmode(t,mode)
    local mt = getmetatable(t) or {}
    if mt.__mode then
        error("The mode has already been set on table "..tostring(t)..".")
    end
    mt.__mode = mode
    return setmetatable(t, mt)
end

util.setmode = setmode

function util.weakboth (t)
    return setmode(t,"kv")
end

function util.weakkey (t)
    return setmode(t,"k")
end

function util.weakval (t)
    return setmode(t,"v")
end

function util.strip_mt (t)
    return setmetatable(t, nil)
end

local getuniqueid
do
    local N, index = 0, {}
    function getuniqueid(v)
        if not index[v] then
            N = N + 1
            index[v] = N
        end
        return index[v]
    end
end
util.getuniqueid = getuniqueid

do
    local counter = 0
    function util.gensym ()
        counter = counter + 1
        return "___SYM_"..counter
    end
end

function util.passprint (...) print(...) return ... end

local val_to_str_, key_to_str, table_tostring, cdata_to_str, t_cache
local multiplier = 2

local
function val_to_string (v, indent)
    indent = indent or 0
    t_cache = {} -- upvalue.
    local acc = {}
    val_to_str_(v, acc, indent, indent)
    local res = t_concat(acc, "")
    return res
end
util.val_to_str = val_to_string

function val_to_str_ ( v, acc, indent, str_indent )
    str_indent = str_indent or 1
    if "string" == type( v ) then
        v = s_gsub( v, "\n",  "\n" .. (" "):rep( indent * multiplier + str_indent ) )
        if s_match( s_gsub( v,"[^'\"]",""), '^"+$' ) then
            acc[#acc+1] = t_concat{ "'", "", v, "'" }
        else
            acc[#acc+1] = t_concat{'"', s_gsub(v,'"', '\\"' ), '"' }
        end
    elseif "cdata" == type( v ) then
            cdata_to_str( v, acc, indent )
    elseif "table" == type(v) then
        if t_cache[v] then
            acc[#acc+1] = t_cache[v]
        else
            t_cache[v] = tostring( v )
            table_tostring( v, acc, indent )
        end
    else
        acc[#acc+1] = tostring( v )
    end
end

function key_to_str ( k, acc, indent )
    if "string" == type( k ) and s_match( k, "^[_%a][_%a%d]*$" ) then
        acc[#acc+1] = s_gsub( k, "\n", (" "):rep( indent * multiplier + 1 ) .. "\n" )
    else
        acc[#acc+1] = "[ "
        val_to_str_( k, acc, indent )
        acc[#acc+1] = " ]"
    end
end

function cdata_to_str(v, acc, indent)
    acc[#acc+1] = ( " " ):rep( indent * multiplier )
    acc[#acc+1] = "["
    print(#acc)
    for i = 0, #v do
        if i % 16 == 0 and i ~= 0 then
            acc[#acc+1] = "\n"
            acc[#acc+1] = (" "):rep(indent * multiplier + 2)
        end
        acc[#acc+1] = v[i] and 1 or 0
        acc[#acc+1] = i ~= #v and  ", " or ""
    end
    print(#acc, acc[1], acc[2])
    acc[#acc+1] = "]"
end

function table_tostring ( tbl, acc, indent )
    -- acc[#acc+1] = ( " " ):rep( indent * multiplier )
    acc[#acc+1] = t_cache[tbl]
    acc[#acc+1] = "{\n"
    for k, v in pairs( tbl ) do
        local str_indent = 1
        acc[#acc+1] = (" "):rep((indent + 1) * multiplier)
        key_to_str( k, acc, indent + 1)

        if acc[#acc] == " ]"
        and acc[#acc - 2] == "[ "
        then str_indent = 8 + #acc[#acc - 1]
        end

        acc[#acc+1] = " = "
        val_to_str_( v, acc, indent + 1, str_indent)
        acc[#acc+1] = "\n"
    end
    acc[#acc+1] = ( " " ):rep( indent * multiplier )
    acc[#acc+1] = "}"
end

function util.expose(v) print(val_to_string(v)) return v end
-------------------------------------------------------------------------------
--- Functional helpers
--

function util.map (ary, func, ...)
    if type(ary) == "function" then ary, func = func, ary end
    local res = {}
    for i = 1,#ary do
        res[i] = func(ary[i], ...)
    end
    return res
end

function util.selfmap (ary, func, ...)
    if type(ary) == "function" then ary, func = func, ary end
    for i = 1,#ary do
        ary[i] = func(ary[i], ...)
    end
    return ary
end

local
function map_all (tbl, func, ...)
    if type(tbl) == "function" then tbl, func = func, tbl end
    local res = {}
    for k, v in next, tbl do
        res[k]=func(v, ...)
    end
    return res
end

util.map_all = map_all

local
function fold (ary, func, acc)
    local i0 = 1
    if not acc then
        acc = ary[1]
        i0 = 2
    end
    for i = i0, #ary do
        acc = func(acc,ary[i])
    end
    return acc
end
util.fold = fold

local
function foldr (ary, func, acc)
    local offset = 0
    if not acc then
        acc = ary[#ary]
        offset = 1
    end
    for i = #ary - offset, 1 , -1 do
        acc = func(ary[i], acc)
    end
    return acc
end
util.foldr = foldr

local
function map_fold(ary, mfunc, ffunc, acc)
    local i0 = 1
    if not acc then
        acc = mfunc(ary[1])
        i0 = 2
    end
    for i = i0, #ary do
        acc = ffunc(acc,mfunc(ary[i]))
    end
    return acc
end
util.map_fold = map_fold

local
function map_foldr(ary, mfunc, ffunc, acc)
    local offset = 0
    if not acc then
        acc = mfunc(ary[#acc])
        offset = 1
    end
    for i = #ary - offset, 1 , -1 do
        acc = ffunc(mfunc(ary[i], acc))
    end
    return acc
end
util.map_foldr = map_fold

function util.zip(a1, a2)
    local res, len = {}, m_max(#a1,#a2)
    for i = 1,len do
        res[i] = {a1[i], a2[i]}
    end
    return res
end

function util.zip_all(t1, t2)
    local res = {}
    for k,v in pairs(t1) do
        res[k] = {v, t2[k]}
    end
    for k,v in pairs(t2) do
        if res[k] == nil then
            res[k] = {t1[k], v}
        end
    end
    return res
end

function util.filter(ary,func)
    local res = {}
    for i = 1,#ary do
        if func(ary[i]) then
            t_insert(res, ary[i])
        end
    end

end

local
function id (...) return ... end
util.id = id



local function AND (a,b) return a and b end
local function OR  (a,b) return a or b  end

function util.copy (tbl) return map_all(tbl, id) end

function util.all (ary, mfunc)
    if mfunc then
        return map_fold(ary, mfunc, AND)
    else
        return fold(ary, AND)
    end
end

function util.any (ary, mfunc)
    if mfunc then
        return map_fold(ary, mfunc, OR)
    else
        return fold(ary, OR)
    end
end

function util.get(field)
    return function(tbl) return tbl[field] end
end

function util.lt(ref)
    return function(val) return val < ref end
end

-- function util.lte(ref)
--     return function(val) return val <= ref end
-- end

-- function util.gt(ref)
--     return function(val) return val > ref end
-- end

-- function util.gte(ref)
--     return function(val) return val >= ref end
-- end

function util.compose(f,g)
    return function(...) return f(g(...)) end
end

function util.extend (destination, ...)
    for i = 1, select('#', ...) do
        for k,v in pairs((select(i, ...))) do
            destination[k] = v
        end
    end
    return destination
end

function util.setify (t)
    local set = {}
    for i = 1, #t do
        set[t[i]]=true
    end
    return set
end

function util.arrayify (...) return {...} end


local
function _checkstrhelper(s)
    return s..""
end

function util.checkstring(s, func)
    local success, str = pcall(_checkstrhelper, s)
    if not success then 
        if func == nil then func = "?" end
        error("bad argument to '"
            ..tostring(func)
            .."' (string expected, got "
            ..type(s)
            ..")",
        2)
    end
    return str
end



return util

--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The PureLPeg library
--
--                                             \
--                                              '.,__
--                                           \  /
--                                            '/,__
--                                            /
--                                           /
--                                          /
--                       has been          / released
--                  ~ ~ ~ ~ ~ ~ ~ ~       ~ ~ ~ ~ ~ ~ ~ ~
--                under  the  Romantic   WTF Public License.
--               ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~`,´ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--               I hereby grant you an irrevocable license to
--                ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                  do what the gentle caress you want to
--                       ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                           with   this   lovely
--                              ~ ~ ~ ~ ~ ~ ~ ~
--                               / thing...
--                              /  ~ ~ ~ ~
--                             /    Love,
--                        #   /      '.'
--                        #######      ·
--                        #####
--                        ###
--                        #
--
--            -- Pierre-Yves
--
--
--            P.S.: Even though I poured my heart into this work,
--                  I _cannot_ provide any warranty regarding
--                  its fitness for _any_ purpose. You
--                  acknowledge that I will not be held liable
--                  for any damage its use could incur.
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["compiler"])sources["compiler"]=(\[===\[-- <pack compiler> --
local assert, error, pairs, print, rawset, select, setmetatable, tostring, type
    = assert, error, pairs, print, rawset, select, setmetatable, tostring, type

--[[DBG]] local debug, print = debug, print

local s, t, u = require"string", require"table", require"util"



local _ENV = u.noglobals() ----------------------------------------------------



local s_byte, s_sub, t_concat, t_insert, t_remove, t_unpack
    = s.byte, s.sub, t.concat, t.insert, t.remove, u.unpack

local   load,   map,   map_all, t_pack
    = u.load, u.map, u.map_all, u.pack

local expose = u.expose

return function(Builder, LL)
local evaluate, LL_ispattern =  LL.evaluate, LL.ispattern
local charset = Builder.charset



local compilers = {}


local
function compile(pt, ccache)
    -- print("Compile", pt.pkind)
    if not LL_ispattern(pt) then
        --[[DBG]] expose(pt)
        error("pattern expected")
    end
    local typ = pt.pkind
    if typ == "grammar" then
        ccache = {}
    elseif typ == "ref" or typ == "choice" or typ == "sequence" then
        if not ccache[pt] then
            ccache[pt] = compilers[typ](pt, ccache)
        end
        return ccache[pt]
    end
    if not pt.compiled then
        -- [[DBG]] print("Not compiled:")
        -- [[DBG]] LL.pprint(pt)
        pt.compiled = compilers[pt.pkind](pt, ccache)
    end

    return pt.compiled
end
LL.compile = compile


local
function clear_captures(ary, ci)
    -- [[DBG]] print("clear caps, ci = ", ci)
    -- [[DBG]] print("TRACE: ", debug.traceback(1))
    -- [[DBG]] expose(ary)
    for i = ci, #ary do ary[i] = nil end
    -- [[DBG]] expose(ary)
    -- [[DBG]] print("/clear caps --------------------------------")
end


local LL_compile, LL_evaluate, LL_P
    = LL.compile, LL.evaluate, LL.P

local function computeidex(i, len)
    if i == 0 or i == 1 or i == nil then return 1
    elseif type(i) ~= "number" then error"number or nil expected for the stating index"
    elseif i > 0 then return i > len and len + 1 or i
    else return len + i < 0 and 1 or len + i + 1
    end
end


------------------------------------------------------------------------------
--- Match

--[[DBG]] local dbgcapsmt = {__newindex = function(self, k,v) 
--[[DBG]]     if k ~= #self + 1 then 
--[[DBG]]         print("Bad new cap", k, v)
--[[DBG]]         expose(self)
--[[DBG]]         error""
--[[DBG]]     else
--[[DBG]]         rawset(self,k,v)
--[[DBG]]     end
--[[DBG]] end}

--[[DBG]] local
--[[DBG]] function dbgcaps(t) return setmetatable(t, dbgcapsmt) end
local function newcaps()
    return {
        kind = {}, 
        bounds = {},
        openclose = {},
        aux = -- [[DBG]] dbgcaps
            {}
    }
end

local
function _match(dbg, pt, sbj, si, ...)
        if dbg then -------------
            print("@!!! Match !!!@", pt)
        end ---------------------

    pt = LL_P(pt)

    assert(type(sbj) == "string", "string expected for the match subject")
    si = computeidex(si, #sbj)

        if dbg then -------------
            print(("-"):rep(30))
            print(pt.pkind)
            LL.pprint(pt)
        end ---------------------

    local matcher = compile(pt, {})
    -- capture accumulator
    local caps = newcaps()
    local matcher_state = {grammars = {}, args = {n = select('#',...),...}, tags = {}} 

    local  success, final_si, ci = matcher(sbj, si, caps, 1, matcher_state)

        if dbg then -------------
            print("!!! Done Matching !!! success: ", success, 
                "final position", final_si, "final cap index", ci,
                "#caps", #caps.openclose)
        end----------------------

    if success then
            -- if dbg then -------------
                -- print"Pre-clear-caps"
                -- expose(caps)
            -- end ---------------------

        clear_captures(caps.kind, ci)
        clear_captures(caps.aux, ci)

            if dbg then -------------
            print("trimmed cap index = ", #caps + 1)
            -- expose(caps)
            LL.cprint(caps, sbj, 1)
            end ---------------------

        local values, _, vi = LL_evaluate(caps, sbj, 1, 1)

            if dbg then -------------
                print("#values", vi)
                expose(values)
            end ---------------------

        if vi == 0
        then return final_si
        else return t_unpack(values, 1, vi) end
    else
        if dbg then print("Failed") end
        return nil
    end
end

function LL.match(...)
    return _match(false, ...) 
end

-- With some debug info.
function LL.dmatch(...)
    return _match(true, ...) 
end

------------------------------------------------------------------------------
----------------------------------  ,--. ,--. ,--. |_  ,  , ,--. ,--. ,--.  --
--- Captures                        |    .--| |__' |   |  | |    |--' '--,
--                                  `--' `--' |    `-- `--' '    `--' `--'


-- These are all alike:


for _, v in pairs{ 
    "C", "Cf", "Cg", "Cs", "Ct", "Clb",
    "div_string", "div_table", "div_number", "div_function"
} do
    compilers[v] = load(([=[
    local compile, expose, type, LL = ...
    return function (pt, ccache)
        -- [[DBG]] print("Compiling", "XXXX")
        -- [[DBG]] expose(LL.getdirect(pt))
        -- [[DBG]] LL.pprint(pt)
        local matcher, this_aux = compile(pt.pattern, ccache), pt.aux
        return function (sbj, si, caps, ci, state)
            -- [[DBG]] print("XXXX: ci = ", ci, "             ", "", ", si = ", si, ", type(this_aux) = ", type(this_aux), this_aux)
            -- [[DBG]] expose(caps)

            local ref_ci = ci

            local kind, bounds, openclose, aux 
                = caps.kind, caps.bounds, caps.openclose, caps.aux

            kind      [ci] = "XXXX"
            bounds    [ci] = si
            -- openclose = 0 ==> bound is lower bound of the capture.
            openclose [ci] = 0
            caps.aux       [ci] = (this_aux or false)

            local success

            success, si, ci
                = matcher(sbj, si, caps, ci + 1, state)
            if success then
                -- [[DBG]] print("/XXXX: ci = ", ci, ", ref_ci = ", ref_ci, ", si = ", si)
                if ci == ref_ci + 1 then
                    -- [[DBG]] print("full", si)
                    -- a full capture, ==> openclose > 0 == the closing bound.
                    caps.openclose[ref_ci] = si
                else
                    -- [[DBG]] print("closing", si)
                    kind      [ci] = "XXXX"
                    bounds    [ci] = si
                    -- a closing bound. openclose < 0 
                    -- (offset in the capture stack between open and close)
                    openclose [ci] = ref_ci - ci
                    aux       [ci] = this_aux or false
                    ci = ci + 1
                end
                -- [[DBG]] expose(caps)
            else
                ci = ci - 1
                -- [[DBG]] print("///XXXX: ci = ", ci, ", ref_ci = ", ref_ci, ", si = ", si)
                -- [[DBG]] expose(caps)
            end
            return success, si, ci
        end
    end]=]):gsub("XXXX", v), v.." compiler")(compile, expose, type, LL)
end




compilers["Carg"] = function (pt, ccache)
    local n = pt.aux
    return function (sbj, si, caps, ci, state)
        if state.args.n < n then error("reference to absent argument #"..n) end
        caps.kind      [ci] = "value"
        caps.bounds    [ci] = si
        -- trick to keep the aux a proper sequence, so that #aux behaves.
        -- if the value is nil, we set both openclose and aux to
        -- +infinity, and handle it appropriately when it is eventually evaluated.
        -- openclose holds a positive value ==> full capture.
        if state.args[n] == nil then
            caps.openclose [ci] = 1/0
            caps.aux       [ci] = 1/0
        else
            caps.openclose [ci] = si
            caps.aux       [ci] = state.args[n]
        end
        return true, si, ci + 1
    end
end

for _, v in pairs{ 
    "Cb", "Cc", "Cp"
} do
    compilers[v] = load(([=[
    -- [[DBG]]local expose = ...
    return function (pt, ccache)
        local this_aux = pt.aux
        return function (sbj, si, caps, ci, state)
            -- [[DBG]] print("XXXX: ci = ", ci, ", aux = ", this_aux, ", si = ", si)

            caps.kind      [ci] = "XXXX"
            caps.bounds    [ci] = si
            caps.openclose [ci] = si
            caps.aux       [ci] = this_aux or false

            -- [[DBG]] expose(caps)
            return true, si, ci + 1
        end
    end]=]):gsub("XXXX", v), v.." compiler")(expose)
end


compilers["/zero"] = function (pt, ccache)
    local matcher = compile(pt.pattern, ccache)
    return function (sbj, si, caps, ci, state)
        local success, nsi = matcher(sbj, si, caps, ci, state)

        clear_captures(caps.aux, ci)

        return success, nsi, ci
    end
end


local function pack_Cmt_caps(i,...) return i, t_pack(...) end

-- [[DBG]] local MT = 0
compilers["Cmt"] = function (pt, ccache)
    local matcher, func = compile(pt.pattern, ccache), pt.aux
    -- [[DBG]] local mt, n = MT, 0
    -- [[DBG]] MT = MT + 1
    return function (sbj, si, caps, ci, state)
        -- [[DBG]] n = n + 1
        -- [[DBG]] print("\nCmt start, si = ", si, ", ci = ", ci, ".....",  (" <"..mt.."> "..n):rep(8))
        -- [[DBG]] expose(caps)

        local success, Cmt_si, Cmt_ci = matcher(sbj, si, caps, ci, state)
        if not success then 
            -- [[DBG]] print("/Cmt No match", ".....",  (" -"..mt.."- "..n):rep(12))
            -- [[DBG]] n = n - 1
            clear_captures(caps.aux, ci)
            -- [[DBG]] expose(caps)

            return false, si, ci
        end
        -- [[DBG]] print("Cmt match! ci = ", ci, ", Cmt_ci = ", Cmt_ci)
        -- [[DBG]] expose(caps)

        local final_si, values 

        if Cmt_ci == ci then
            -- [[DBG]] print("Cmt: simple capture: ", si, Cmt_si, s_sub(sbj, si, Cmt_si - 1))
            final_si, values = pack_Cmt_caps(
                func(sbj, Cmt_si, s_sub(sbj, si, Cmt_si - 1))
            )
        else
            -- [[DBG]] print("Cmt: EVAL: ", ci, Cmt_ci)
            clear_captures(caps.aux, Cmt_ci)
            clear_captures(caps.kind, Cmt_ci)
            local cps, _, nn = evaluate(caps, sbj, ci)
            -- [[DBG]] print("POST EVAL ncaps = ", nn)
            -- [[DBG]] expose(cps)
            -- [[DBG]] print("----------------------------------------------------------------")
                        final_si, values = pack_Cmt_caps(
                func(sbj, Cmt_si, t_unpack(cps, 1, nn))
            )
        end
        -- [[DBG]] print("Cmt values ..."); expose(values)
        -- [[DBG]] print("Cmt, final_si = ", final_si, ", Cmt_si = ", Cmt_si)
        -- [[DBG]] print("SOURCE\n",sbj:sub(Cmt_si-20, Cmt_si+20),"\n/SOURCE")
        if not final_si then 
            -- [[DBG]] print("/Cmt No return", ".....",  (" +"..mt.."- "..n):rep(12))
            -- [[DBG]] n = n - 1
            -- clear_captures(caps.aux, ci)
            -- [[DBG]] expose(caps)
            return false, si, ci
        end

        if final_si == true then final_si = Cmt_si end

        if type(final_si) == "number"
        and si <= final_si 
        and final_si <= #sbj + 1 
        then
            -- [[DBG]] print("Cmt Success", values, values and values.n, ci)
            local kind, bounds, openclose, aux 
                = caps.kind, caps.bounds, caps.openclose, caps.aux
            for i = 1, values.n do
                kind      [ci] = "value"
                bounds    [ci] = si
                -- See Carg for the rationale of 1/0.
                if values[i] == nil then
                    caps.openclose [ci] = 1/0
                    caps.aux       [ci] = 1/0
                else
                    caps.openclose [ci] = final_si
                    caps.aux       [ci] = values[i]
                end

                ci = ci + 1
            end
        elseif type(final_si) == "number" then
            error"Index out of bounds returned by match-time capture."
        else
            error("Match time capture must return a number, a boolean or nil"
                .." as first argument, or nothing at all.")
        end
            -- [[DBG]] print("/Cmt success - si = ", si,  ", ci = ", ci, ".....",  (" +"..mt.."+ "..n):rep(8))
            -- [[DBG]] n = n - 1
            -- [[DBG]] expose(caps)
        return true, final_si, ci
    end
end


------------------------------------------------------------------------------
------------------------------------  ,-.  ,--. ,-.     ,--. ,--. ,--. ,--. --
--- Other Patterns                    |  | |  | |  | -- |    ,--| |__' `--.
--                                    '  ' `--' '  '    `--' `--' |    `--'


compilers["string"] = function (pt, ccache)
    local S = pt.aux
    local N = #S
    return function(sbj, si, caps, ci, state)
         -- [[DBG]] print("String    ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sbj)
        local in_1 = si - 1
        for i = 1, N do
            local c
            c = s_byte(sbj,in_1 + i)
            if c ~= S[i] then
         -- [[DBG]] print("%FString    ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sbj)
                return false, si, ci
            end
        end
         -- [[DBG]] print("%SString    ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sbj)
        return true, si + N, ci
    end
end


compilers["char"] = function (pt, ccache)
    return load(([=[
        local s_byte, s_char = ...
        return function(sbj, si, caps, ci, state)
            -- [[DBG]] print("Char "..s_char(__C0__).." ", caps.kind[ci - 1], ", si = "..si, ", ci = "..ci, sbj:sub(1, si - 1))
            local c, nsi = s_byte(sbj, si), si + 1
            if c ~= __C0__ then
                return false, si, ci
            end
            return true, nsi, ci
        end]=]):gsub("__C0__", tostring(pt.aux)))(s_byte, ("").char)
end


local
function truecompiled (sbj, si, caps, ci, state)
     -- [[DBG]] print("True    ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sbj)
    return true, si, ci
end
compilers["true"] = function (pt)
    return truecompiled
end


local
function falsecompiled (sbj, si, caps, ci, state)
     -- [[DBG]] print("False   ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sbj)
    return false, si, ci
end
compilers["false"] = function (pt)
    return falsecompiled
end


local
function eoscompiled (sbj, si, caps, ci, state)
     -- [[DBG]] print("EOS     ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sbj)
    return si > #sbj, si, ci
end
compilers["eos"] = function (pt)
    return eoscompiled
end


local
function onecompiled (sbj, si, caps, ci, state)
    -- [[DBG]] print("One", caps.kind[ci - 1], ", si = "..si, ", ci = "..ci, sbj:sub(1, si - 1))
    local char, _ = s_byte(sbj, si), si + 1
    if char
    then return true, si + 1, ci
    else return false, si, ci end
end

compilers["one"] = function (pt)
    return onecompiled
end


compilers["any"] = function (pt)
    local N = pt.aux
    if N == 1 then
        return onecompiled
    else
        N = pt.aux - 1
        return function (sbj, si, caps, ci, state)
            -- [[DBG]] print("Any", caps.kind[ci - 1], ", si = "..si, ", ci = "..ci, sbj:sub(1, si - 1))
            local n = si + N
            if n <= #sbj then
                -- [[DBG]] print("/Any success", caps.kind[ci - 1], ", si = "..si, ", ci = "..ci, sbj:sub(1, si - 1))
                return true, n + 1, ci
            else
                -- [[DBG]] print("/Any fail", caps.kind[ci - 1], ", si = "..si, ", ci = "..ci, sbj:sub(1, si - 1))
                return false, si, ci
            end
        end
    end
end


do
    local function checkpatterns(g)
        for k,v in pairs(g.aux) do
            if not LL_ispattern(v) then
                error(("rule 'A' is not a pattern"):gsub("A", tostring(k)))
            end
        end
    end

    compilers["grammar"] = function (pt, ccache)
        checkpatterns(pt)
        local gram = map_all(pt.aux, compile, ccache)
        local start = gram[1]
        return function (sbj, si, caps, ci, state)
             -- [[DBG]] print("Grammar ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sbj)
            t_insert(state.grammars, gram)
            local success, nsi, ci = start(sbj, si, caps, ci, state)
            t_remove(state.grammars)
             -- [[DBG]] print("%Grammar ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sbj)
            return success, nsi, ci
        end
    end
end

local dummy_acc = {kind={}, bounds={}, openclose={}, aux={}}
compilers["behind"] = function (pt, ccache)
    local matcher, N = compile(pt.pattern, ccache), pt.aux
    return function (sbj, si, caps, ci, state)
         -- [[DBG]] print("Behind  ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sbj)
        if si <= N then return false, si, ci end

        local success = matcher(sbj, si - N, dummy_acc, ci, state)
        -- note that behid patterns cannot hold captures.
        dummy_acc.aux = {}
        return success, si, ci
    end
end

compilers["range"] = function (pt)
    local ranges = pt.aux
    return function (sbj, si, caps, ci, state)
         -- [[DBG]] print("Range   ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sbj)
        local char, nsi = s_byte(sbj, si), si + 1
        for i = 1, #ranges do
            local r = ranges[i]
            if char and r[char]
            then return true, nsi, ci end
        end
        return false, si, ci
    end
end

compilers["set"] = function (pt)
    local s = pt.aux
    return function (sbj, si, caps, ci, state)
        -- [[DBG]] print("Set, Set!, si = ",si, ", ci = ", ci)
        -- [[DBG]] expose(s)
        local char, nsi = s_byte(sbj, si), si + 1
        -- [[DBG]] print("Set, Set!, nsi = ",nsi, ", ci = ", ci, "char = ", char, ", success = ", (not not s[char]))
        if s[char]
        then return true, nsi, ci
        else return false, si, ci end
    end
end

-- hack, for now.
compilers["range"] = compilers.set

compilers["ref"] = function (pt, ccache)
    local name = pt.aux
    local ref
    return function (sbj, si, caps, ci, state)
         -- [[DBG]] print("Reference",caps, caps and caps.kind or "'nil'", ci, si, state) --, sbj)
        if not ref then
            if #state.grammars == 0 then
                error(("rule 'XXXX' used outside a grammar"):gsub("XXXX", tostring(name)))
            elseif not state.grammars[#state.grammars][name] then
                error(("rule 'XXXX' undefined in given grammar"):gsub("XXXX", tostring(name)))
            end
            ref = state.grammars[#state.grammars][name]
        end
        -- [[DBG]] print("Ref - <"..tostring(name)..">, si = ", si, ", ci = ", ci)
        -- [[DBG]] LL.cprint(caps, 1, sbj)
            local success, nsi, nci = ref(sbj, si, caps, ci, state)
        -- [[DBG]] print("/ref - <"..tostring(name)..">, si = ", si, ", ci = ", ci)
        -- [[DBG]] LL.cprint(caps, 1, sbj)
        return success, nsi, nci
    end
end



-- Unroll the loop using a template:
local choice_tpl = [=[
             -- [[DBG]] print(" Choice XXXX, si = ", si, ", ci = ", ci)
            success, si, ci = XXXX(sbj, si, caps, ci, state)
             -- [[DBG]] print(" /Choice XXXX, si = ", si, ", ci = ", ci, ", success = ", success)
            if success then
                return true, si, ci
            else
                --clear_captures(aux, ci)
            end]=]

local function flatten(kind, pt, ccache)
    if pt[2].pkind == kind then
        return compile(pt[1], ccache), flatten(kind, pt[2], ccache)
    else
        return compile(pt[1], ccache), compile(pt[2], ccache)
    end
end

compilers["choice"] = function (pt, ccache)
    local choices = {flatten("choice", pt, ccache)}
    local names, chunks = {}, {}
    for i = 1, #choices do
        local m = "ch"..i
        names[#names + 1] = m
        chunks[ #names  ] = choice_tpl:gsub("XXXX", m)
    end
    names[#names + 1] = "clear_captures"
    choices[ #names ] = clear_captures
    local compiled = t_concat{
        "local ", t_concat(names, ", "), [=[ = ...
        return function (sbj, si, caps, ci, state)
             -- [[DBG]] print("Choice ", ", si = "..si, ", ci = "..ci, sbj:sub(1, si-1)) --, sbj)
            local aux, success = caps.aux, false
            ]=],
            t_concat(chunks,"\n"),[=[--
             -- [[DBG]] print("/Choice ", ", si = "..si, ", ci = "..ci, sbj:sub(1, si-1)) --, sbj)
            return false, si, ci
        end]=]
    }
    -- print(compiled)
    return load(compiled, "Choice")(t_unpack(choices))
end



local sequence_tpl = [=[
            -- [[DBG]] print(" Seq XXXX , si = ",si, ", ci = ", ci)
            success, si, ci = XXXX(sbj, si, caps, ci, state)
            -- [[DBG]] print(" /Seq XXXX , si = ",si, ", ci = ", ci, ", success = ", success)
            if not success then
                -- clear_captures(caps.aux, ref_ci)
                return false, ref_si, ref_ci
            end]=]
compilers["sequence"] = function (pt, ccache)
    local sequence = {flatten("sequence", pt, ccache)}
    local names, chunks = {}, {}
    -- print(n)
    -- for k,v in pairs(pt.aux) do print(k,v) end
    for i = 1, #sequence do
        local m = "seq"..i
        names[#names + 1] = m
        chunks[ #names  ] = sequence_tpl:gsub("XXXX", m)
    end
    names[#names + 1] = "clear_captures"
    sequence[ #names ] = clear_captures
    local compiled = t_concat{
        "local ", t_concat(names, ", "), [=[ = ...
        return function (sbj, si, caps, ci, state)
            local ref_si, ref_ci, success = si, ci
             -- [[DBG]] print("Sequence ", ", si = "..si, ", ci = "..ci, sbj:sub(1, si-1)) --, sbj)
            ]=],
            t_concat(chunks,"\n"),[=[
             -- [[DBG]] print("/Sequence ", ", si = "..si, ", ci = "..ci, sbj:sub(1, si-1)) --, sbj)
            return true, si, ci
        end]=]
    }
    -- print(compiled)
   return load(compiled, "Sequence")(t_unpack(sequence))
end


compilers["at most"] = function (pt, ccache)
    local matcher, n = compile(pt.pattern, ccache), pt.aux
    n = -n
    return function (sbj, si, caps, ci, state)
         -- [[DBG]] print("At most   ",caps, caps and caps.kind or "'nil'", si) --, sbj)
        local success = true
        for i = 1, n do
            success, si, ci = matcher(sbj, si, caps, ci, state)
            if not success then 
                -- clear_captures(caps.aux, ci)
                break
            end
        end
        return true, si, ci
    end
end

compilers["at least"] = function (pt, ccache)
    local matcher, n = compile(pt.pattern, ccache), pt.aux
    if n == 0 then
        return function (sbj, si, caps, ci, state)
            -- [[DBG]] print("Rep  0", caps.kind[ci - 1], ", si = "..si, ", ci = "..ci, sbj:sub(1, si - 1))
            local last_si, last_ci
            while true do
                local success
                -- [[DBG]] print(" rep  0", caps.kind[ci - 1], ", si = "..si, ", ci = "..ci, sbj:sub(1, si - 1))
                -- [[DBG]] N=N+1
                last_si, last_ci = si, ci
                success, si, ci = matcher(sbj, si, caps, ci, state)
                if not success then                     
                    si, ci = last_si, last_ci
                    break
                end
            end
            -- [[DBG]] print("/rep  0", caps.kind[ci - 1], ", si = "..si, ", ci = "..ci, sbj:sub(1, si - 1))
            -- clear_captures(caps.aux, ci)
            return true, si, ci
        end
    elseif n == 1 then
        return function (sbj, si, caps, ci, state)
            -- [[DBG]] print("At least 1 ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sbj)
            local last_si, last_ci
            local success = true
            -- [[DBG]] print("Rep  1", caps.kind[ci - 1], ", si = "..si, ", ci = "..ci)
            success, si, ci = matcher(sbj, si, caps, ci, state)
            if not success then
            -- [[DBG]] print("/Rep  1 Fail")
                -- clear_captures(caps.aux, ci)
                return false, si, ci
            end
            while true do
                local success
                -- [[DBG]] print(" rep  1", caps.kind[ci - 1], ", si = "..si, ", ci = "..ci, sbj:sub(1, si - 1))
                -- [[DBG]] N=N+1
                last_si, last_ci = si, ci
                success, si, ci = matcher(sbj, si, caps, ci, state)
                if not success then                     
                    si, ci = last_si, last_ci
                    break
                end
            end
            -- [[DBG]] print("/rep  1", caps.kind[ci - 1], ", si = "..si, ", ci = "..ci, sbj:sub(1, si - 1))
             -- clear_captures(caps.aux, ci)
            return true, si, ci
        end
    else
        return function (sbj, si, caps, ci, state)
            -- [[DBG]] print("At least "..n.." ", caps and caps.kind or "'nil'", ci, si, state) --, sbj)
            local last_si, last_ci
            local success = true
            for _ = 1, n do
                success, si, ci = matcher(sbj, si, caps, ci, state)
                if not success then
                    -- clear_captures(caps.aux, ci)
                    return false, si, ci
                end
            end
            while true do
                local success
                -- [[DBG]] print(" rep  "..n, caps.kind[ci - 1], ", si = "..si, ", ci = "..ci, sbj:sub(1, si - 1))
                last_si, last_ci = si, ci
                success, si, ci = matcher(sbj, si, caps, ci, state)
                if not success then                     
                    si, ci = last_si, last_ci
                    break
                end
            end
            -- [[DBG]] print("/rep  "..n, caps.kind[ci - 1], ", si = "..si, ", ci = "..ci, sbj:sub(1, si - 1))
            -- clear_captures(caps.aux, ci)
            return true, si, ci
        end
    end
end

compilers["unm"] = function (pt, ccache)
    -- P(-1)
    if pt.pkind == "any" and pt.aux == 1 then
        return eoscompiled
    end
    local matcher = compile(pt.pattern, ccache)
    return function (sbj, si, caps, ci, state)
         -- [[DBG]] print("Unm     ", caps, caps and caps.kind or "'nil'", ci, si, state)
        -- Throw captures away
        local success, _, _ = matcher(sbj, si, caps, ci, state)
        -- clear_captures(caps.aux, ci)
        return not success, si, ci
    end
end

compilers["lookahead"] = function (pt, ccache)
    local matcher = compile(pt.pattern, ccache)
    return function (sbj, si, caps, ci, state)
        -- [[DBG]] print("Look ", caps.kind[ci - 1], ", si = "..si, ", ci = "..ci, sbj:sub(1, si - 1))
        -- Throw captures away
        local success, _, _ = matcher(sbj, si, caps, ci, state)
         -- [[DBG]] print("Look, success = ", success, sbj:sub(1, si - 1))
         -- clear_captures(caps.aux, ci)
        return success, si, ci
    end
end

end

--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The LuLPeg library
--
--                                             \
--                                              '.,__
--                                           \  /
--                                            '/,__
--                                            /
--                                           /
--                                          /
--                       has been          / released
--                  ~ ~ ~ ~ ~ ~ ~ ~       ~ ~ ~ ~ ~ ~ ~ ~
--                under  the  Romantic   WTF Public License.
--               ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~`,´ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--               I hereby grant you an irrevocable license to
--                ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                  do what the gentle caress you want to
--                       ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                           with   this   lovely
--                              ~ ~ ~ ~ ~ ~ ~ ~
--                               / thing...
--                              /  ~ ~ ~ ~
--                             /    Love,
--                        #   /      '.'
--                        #######      ·
--                        #####
--                        ###
--                        #
--
--            -- Pierre-Yves
--
--
--            P.S.: Even though I poured my heart into this work,
--                  I _cannot_ provide any warranty regarding
--                  its fitness for _any_ purpose. You
--                  acknowledge that I will not be held liable
--                  for any damage its use could incur.
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["datastructures"])sources["datastructures"]=(\[===\[-- <pack datastructures> --
local getmetatable, pairs, setmetatable, type
    = getmetatable, pairs, setmetatable, type

--[[DBG]] local debug, print = debug, print

local m, t , u = require"math", require"table", require"util"


local compat = require"compat"
local ffi if compat.luajit then
    ffi = require"ffi"
end



local _ENV = u.noglobals() ----------------------------------------------------



local   extend,   load, u_max
    = u.extend, u.load, u.max

--[[DBG]] local expose = u.expose

local m_max, t_concat, t_insert, t_sort
    = m.max, t.concat, t.insert, t.sort

local structfor = {}

--------------------------------------------------------------------------------
--- Byte sets
--

-- Byte sets are sets whose elements are comprised between 0 and 255.
-- We provide two implemetations. One based on Lua tables, and the
-- other based on a FFI bool array.

local byteset_new, isboolset, isbyteset

local byteset_mt = {}

local
function byteset_constructor (upper)
-- FIXME: unknown fix from https://github.com/StarChasers/LuLPeg/commit/b1095cf2db79bf74e34c6384fce2a75d0bb86f46
if upper < 0 then upper = 0 end
-- /FIXME
    local set = setmetatable(load(t_concat{
        "return{ [0]=false",
        (", false"):rep(upper),
        " }"
    })(),
    byteset_mt)
    return set
end

if compat.jit then
    local struct, boolset_constructor = {v={}}

    function byteset_mt.__index(s,i)
        -- [[DBG]] print("GI", s,i)
        -- [[DBG]] print(debug.traceback())
        -- [[DBG]] if i == "v" then error("FOOO") end
        if i == nil or i > s.upper then return nil end
        return s.v[i]
    end
    function byteset_mt.__len(s)
        return s.upper
    end
    function byteset_mt.__newindex(s,i,v)
        -- [[DBG]] print("NI", i, v)
        s.v[i] = v
    end

    boolset_constructor = ffi.metatype('struct { int upper; bool v[?]; }', byteset_mt)

    function byteset_new (t)
        -- [[DBG]] print ("Konstructor", type(t), t)
        if type(t) == "number" then
            local res = boolset_constructor(t+1)
            res.upper = t
            --[[DBG]] for i = 0, res.upper do if res[i] then print("K", i, res[i]) end end
            return res
        end
        local upper = u_max(t)

        struct.upper = upper
        if upper > 255 then error"bool_set overflow" end
        local set = boolset_constructor(upper+1)
        set.upper = upper
        for i = 1, #t do set[t[i]] = true end

        return set
    end

    function isboolset(s) return type(s)=="cdata" and ffi.istype(s, boolset_constructor) end
    isbyteset = isboolset
else
    function byteset_new (t)
        -- [[DBG]] print("Set", t)
        if type(t) == "number" then return byteset_constructor(t) end
        local set = byteset_constructor(u_max(t))
        for i = 1, #t do set[t[i]] = true end
        return set
    end

    function isboolset(s) return false end
    function isbyteset (s)
        return getmetatable(s) == byteset_mt
    end
end

local
function byterange_new (low, high)
    -- [[DBG]] print("Range", low,high)
    high = ( low <= high ) and high or -1
    local set = byteset_new(high)
    for i = low, high do
        set[i] = true
    end
    return set
end


local tmpa, tmpb ={}, {}

local
function set_if_not_yet (s, dest)
    if type(s) == "number" then
        dest[s] = true
        return dest
    else
        return s
    end
end

local
function clean_ab (a,b)
    tmpa[a] = nil
    tmpb[b] = nil
end

local
function byteset_union (a ,b)
    local upper = m_max(
        type(a) == "number" and a or #a,
        type(b) == "number" and b or #b
    )
    local A, B
        = set_if_not_yet(a, tmpa)
        , set_if_not_yet(b, tmpb)

    local res = byteset_new(upper)
    for i = 0, upper do
        res[i] = A[i] or B[i] or false
        -- [[DBG]] print(i, res[i])
    end
    -- [[DBG]] print("BS Un ==========================")
    -- [[DBG]] print"/// A ///////////////////////  "
    -- [[DBG]] expose(a)
    -- [[DBG]] expose(A)
    -- [[DBG]] print"*** B ***********************  "
    -- [[DBG]] expose(b)
    -- [[DBG]] expose(B)
    -- [[DBG]] print"   RES   "
    -- [[DBG]] expose(res)
    clean_ab(a,b)
    return res
end

local
function byteset_difference (a, b)
    local res = {}
    for i = 0, 255 do
        res[i] = a[i] and not b[i]
    end
    return res
end

local
function byteset_tostring (s)
    local list = {}
    for i = 0, 255 do
        -- [[DBG]] print(s[i] == true and i)
        list[#list+1] = (s[i] == true) and i or nil
    end
    -- [[DBG]] print("BS TOS", t_concat(list,", "))
    return t_concat(list,", ")
end



structfor.binary = {
    set ={
        new = byteset_new,
        union = byteset_union,
        difference = byteset_difference,
        tostring = byteset_tostring
    },
    Range = byterange_new,
    isboolset = isboolset,
    isbyteset = isbyteset,
    isset = isbyteset
}

--------------------------------------------------------------------------------
--- Bit sets: TODO? to try, at least.
--

-- From Mike Pall's suggestion found at
-- http://lua-users.org/lists/lua-l/2011-08/msg00382.html

-- local bit = require("bit")
-- local band, bor = bit.band, bit.bor
-- local lshift, rshift, rol = bit.lshift, bit.rshift, bit.rol

-- local function bitnew(n)
--   return ffi.new("int32_t[?]", rshift(n+31, 5))
-- end

-- -- Note: the index 'i' is zero-based!
-- local function bittest(b, i)
--   return band(rshift(b[rshift(i, 5)], i), 1) ~= 0
-- end

-- local function bitset(b, i)
--   local x = rshift(i, 5); b[x] = bor(b[x], lshift(1, i))
-- end

-- local function bitclear(b, i)
--   local x = rshift(i, 5); b[x] = band(b[x], rol(-2, i))
-- end



-------------------------------------------------------------------------------
--- General case:
--

-- Set
--

local set_mt = {}

local
function set_new (t)
    -- optimization for byte sets.
    -- [[BS]] if all(map_all(t, function(e)return type(e) == "number" end))
    -- and u_max(t) <= 255
    -- or #t == 0
    -- then
    --     return byteset_new(t)
    -- end
    local set = setmetatable({}, set_mt)
    for i = 1, #t do set[t[i]] = true end
    return set
end

local -- helper for the union code.
function add_elements(a, res)
    -- [[BS]] if isbyteset(a) then
    --     for i = 0, 255 do
    --         if a[i] then res[i] = true end
    --     end
    -- else
    for k in pairs(a) do res[k] = true end
    return res
end

local
function set_union (a, b)
    -- [[BS]] if isbyteset(a) and isbyteset(b) then
    --     return byteset_union(a,b)
    -- end
    a, b = (type(a) == "number") and set_new{a} or a
         , (type(b) == "number") and set_new{b} or b
    local res = set_new{}
    add_elements(a, res)
    add_elements(b, res)
    return res
end

local
function set_difference(a, b)
    local list = {}
    -- [[BS]] if isbyteset(a) and isbyteset(b) then
    --     return byteset_difference(a,b)
    -- end
    a, b = (type(a) == "number") and set_new{a} or a
         , (type(b) == "number") and set_new{b} or b

    -- [[BS]] if isbyteset(a) then
    --     for i = 0, 255 do
    --         if a[i] and not b[i] then
    --             list[#list+1] = i
    --         end
    --     end
    -- elseif isbyteset(b) then
    --     for el in pairs(a) do
    --         if not byteset_has(b, el) then
    --             list[#list + 1] = i
    --         end
    --     end
    -- else
    for el in pairs(a) do
        if a[el] and not b[el] then
            list[#list+1] = el
        end
    end
    -- [[BS]] end
    return set_new(list)
end

local
function set_tostring (s)
    -- [[BS]] if isbyteset(s) then return byteset_tostring(s) end
    local list = {}
    for el in pairs(s) do
        t_insert(list,el)
    end
    t_sort(list)
    return t_concat(list, ",")
end

local
function isset (s)
    return (getmetatable(s) == set_mt)
        -- [[BS]] or isbyteset(s)
end


-- Range
--

-- For now emulated using sets.

local
function range_new (start, finish)
    local list = {}
    for i = start, finish do
        list[#list + 1] = i
    end
    return set_new(list)
end

-- local
-- function range_overlap (r1, r2)
--     return r1[1] <= r2[2] and r2[1] <= r1[2]
-- end

-- local
-- function range_merge (r1, r2)
--     if not range_overlap(r1, r2) then return nil end
--     local v1, v2 =
--         r1[1] < r2[1] and r1[1] or r2[1],
--         r1[2] > r2[2] and r1[2] or r2[2]
--     return newrange(v1,v2)
-- end

-- local
-- function range_isrange (r)
--     return getmetatable(r) == range_mt
-- end

structfor.other = {
    set = {
        new = set_new,
        union = set_union,
        tostring = set_tostring,
        difference = set_difference,
    },
    Range = range_new,
    isboolset = isboolset,
    isbyteset = isbyteset,
    isset = isset,
    isrange = function(a) return false end
}



return function(Builder, LL)
    local cs = (Builder.options or {}).charset or "binary"
    if type(cs) == "string" then
        cs = (cs == "binary") and "binary" or "other"
    else
        cs = cs.binary and "binary" or "other"
    end
    return extend(Builder, structfor[cs])
end


--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The LuLPeg library
--
--                                             \
--                                              '.,__
--                                           \  /
--                                            '/,__
--                                            /
--                                           /
--                                          /
--                       has been          / released
--                  ~ ~ ~ ~ ~ ~ ~ ~       ~ ~ ~ ~ ~ ~ ~ ~
--                under  the  Romantic   WTF Public License.
--               ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~`,´ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--               I hereby grant you an irrevocable license to
--                ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                  do what the gentle caress you want to
--                       ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                           with   this   lovely
--                              ~ ~ ~ ~ ~ ~ ~ ~
--                               / thing...
--                              /  ~ ~ ~ ~
--                             /    Love,
--                        #   /      '.'
--                        #######      ·
--                        #####
--                        ###
--                        #
--
--            -- Pierre-Yves
--
--
--            P.S.: Even though I poured my heart into this work,
--                  I _cannot_ provide any warranty regarding
--                  its fitness for _any_ purpose. You
--                  acknowledge that I will not be held liable
--                  for any damage its use could incur.
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["re"])sources["re"]=(\[===\[-- <pack re> --

-- re.lua by Roberto Ierusalimschy. see LICENSE in the root folder.

return function(Builder, LL)

-- $Id: re.lua,v 1.44 2013/03/26 20:11:40 roberto Exp $

-- imported functions and modules
local tonumber, type, print, error = tonumber, type, print, error
local setmetatable = setmetatable
local m = LL

-- 'm' will be used to parse expressions, and 'mm' will be used to
-- create expressions; that is, 're' runs on 'm', creating patterns
-- on 'mm'
local mm = m

-- pattern's metatable
local mt = getmetatable(mm.P(0))



-- No more global accesses after this point
local version = _VERSION
if version == "Lua 5.2" then _ENV = nil end


local any = m.P(1)


-- Pre-defined names
local Predef = { nl = m.P"\n" }


local mem
local fmem
local gmem


local function updatelocale ()
  mm.locale(Predef)
  Predef.a = Predef.alpha
  Predef.c = Predef.cntrl
  Predef.d = Predef.digit
  Predef.g = Predef.graph
  Predef.l = Predef.lower
  Predef.p = Predef.punct
  Predef.s = Predef.space
  Predef.u = Predef.upper
  Predef.w = Predef.alnum
  Predef.x = Predef.xdigit
  Predef.A = any - Predef.a
  Predef.C = any - Predef.c
  Predef.D = any - Predef.d
  Predef.G = any - Predef.g
  Predef.L = any - Predef.l
  Predef.P = any - Predef.p
  Predef.S = any - Predef.s
  Predef.U = any - Predef.u
  Predef.W = any - Predef.w
  Predef.X = any - Predef.x
  mem = {}    -- restart memoization
  fmem = {}
  gmem = {}
  local mt = {__mode = "v"}
  setmetatable(mem, mt)
  setmetatable(fmem, mt)
  setmetatable(gmem, mt)
end


updatelocale()



--[[DBG]] local I = m.P(function (s,i) print(i, s:sub(1, i-1)); return i end)


local function getdef (id, defs)
  local c = defs and defs[id]
  if not c then error("undefined name: " .. id) end
  return c
end


local function patt_error (s, i)
  local msg = (#s < i + 20) and s:sub(i)
                             or s:sub(i,i+20) .. "..."
  msg = ("pattern error near '%s'"):format(msg)
  error(msg, 2)
end

local function mult (p, n)
  local np = mm.P(true)
  while n >= 1 do
    if n%2 >= 1 then np = np * p end
    p = p * p
    n = n/2
  end
  return np
end

local function equalcap (s, i, c)
  if type(c) ~= "string" then return nil end
  local e = #c + i
  if s:sub(i, e - 1) == c then return e else return nil end
end


local S = (Predef.space + "--" * (any - Predef.nl)^0)^0

local name = m.R("AZ", "az", "__") * m.R("AZ", "az", "__", "09")^0

local arrow = S * "<-"

local seq_follow = m.P"/" + ")" + "}" + ":}" + "~}" + "|}" + (name * arrow) + -1

name = m.C(name)


-- a defined name only have meaning in a given environment
local Def = name * m.Carg(1)

local num = m.C(m.R"09"^1) * S / tonumber

local String = "'" * m.C((any - "'")^0) * "'" +
               '"' * m.C((any - '"')^0) * '"'


local defined = "%" * Def / function (c,Defs)
  local cat =  Defs and Defs[c] or Predef[c]
  if not cat then error ("name '" .. c .. "' undefined") end
  return cat
end

local Range = m.Cs(any * (m.P"-"/"") * (any - "]")) / mm.R

local item = defined + Range + m.C(any)

local Class =
    "["
  * (m.C(m.P"^"^-1))    -- optional complement symbol
  * m.Cf(item * (item - "]")^0, mt.__add) /
                          function (c, p) return c == "^" and any - p or p end
  * "]"

local function adddef (t, k, exp)
  if t[k] then
    error("'"..k.."' already defined as a rule")
  else
    t[k] = exp
  end
  return t
end

local function firstdef (n, r) return adddef({n}, n, r) end


local function NT (n, b)
  if not b then
    error("rule '"..n.."' used outside a grammar")
  else return mm.V(n)
  end
end


local exp = m.P{ "Exp",
  Exp = S * ( m.V"Grammar"
            + m.Cf(m.V"Seq" * ("/" * S * m.V"Seq")^0, mt.__add) );
  Seq = m.Cf(m.Cc(m.P"") * m.V"Prefix"^0 , mt.__mul)
        * (m.L(seq_follow) + patt_error);
  Prefix = "&" * S * m.V"Prefix" / mt.__len
         + "!" * S * m.V"Prefix" / mt.__unm
         + m.V"Suffix";
  Suffix = m.Cf(m.V"Primary" * S *
          ( ( m.P"+" * m.Cc(1, mt.__pow)
            + m.P"*" * m.Cc(0, mt.__pow)
            + m.P"?" * m.Cc(-1, mt.__pow)
            + "^" * ( m.Cg(num * m.Cc(mult))
                    + m.Cg(m.C(m.S"+-" * m.R"09"^1) * m.Cc(mt.__pow))
                    )
            + "->" * S * ( m.Cg((String + num) * m.Cc(mt.__div))
                         + m.P"{}" * m.Cc(nil, m.Ct)
                         + m.Cg(Def / getdef * m.Cc(mt.__div))
                         )
            + "=>" * S * m.Cg(Def / getdef * m.Cc(m.Cmt))
            ) * S
          )^0, function (a,b,f) return f(a,b) end );
  Primary = "(" * m.V"Exp" * ")"
            + String / mm.P
            + Class
            + defined
            + "{:" * (name * ":" + m.Cc(nil)) * m.V"Exp" * ":}" /
                     function (n, p) return mm.Cg(p, n) end
            + "=" * name / function (n) return mm.Cmt(mm.Cb(n), equalcap) end
            + m.P"{}" / mm.Cp
            + "{~" * m.V"Exp" * "~}" / mm.Cs
            + "{|" * m.V"Exp" * "|}" / mm.Ct
            + "{" * m.V"Exp" * "}" / mm.C
            + m.P"." * m.Cc(any)
            + (name * -arrow + "<" * name * ">") * m.Cb("G") / NT;
  Definition = name * arrow * m.V"Exp";
  Grammar = m.Cg(m.Cc(true), "G") *
            m.Cf(m.V"Definition" / firstdef * m.Cg(m.V"Definition")^0,
              adddef) / mm.P
}

local pattern = S * m.Cg(m.Cc(false), "G") * exp / mm.P * (-any + patt_error)


local function compile (p, defs)
  if mm.type(p) == "pattern" then return p end   -- already compiled
  local cp = pattern:match(p, 1, defs)
  if not cp then error("incorrect pattern", 3) end
  return cp
end

local function match (s, p, i)
  local cp = mem[p]
  if not cp then
    cp = compile(p)
    mem[p] = cp
  end
  return cp:match(s, i or 1)
end

local function find (s, p, i)
  local cp = fmem[p]
  if not cp then
    cp = compile(p) / 0
    cp = mm.P{ mm.Cp() * cp * mm.Cp() + 1 * mm.V(1) }
    fmem[p] = cp
  end
  local i, e = cp:match(s, i or 1)
  if i then return i, e - 1
  else return i
  end
end

local function gsub (s, p, rep)
  local g = gmem[p] or {}   -- ensure gmem[p] is not collected while here
  gmem[p] = g
  local cp = g[rep]
  if not cp then
    cp = compile(p)
    cp = mm.Cs((cp / rep + 1)^0)
    g[rep] = cp
  end
  return cp:match(s)
end


-- exported names
local re = {
  compile = compile,
  match = match,
  find = find,
  gsub = gsub,
  updatelocale = updatelocale,
}

-- if compat.lua51 or compat.luajit then _G.re = re end

return re

end
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["charsets"])sources["charsets"]=(\[===\[-- <pack charsets> --

-- Charset handling


-- FIXME:
-- Currently, only
-- * `binary_get_int()`,
-- * `binary_split_int()` and
-- * `binary_validate()`
-- are effectively used by the client code.

-- *_next_int, *_split_, *_get_ and *_next_char should probably be disposed of.



-- We provide:
-- * utf8_validate(subject, start, finish) -- validator
-- * utf8_split_int(subject)               --> table{int}
-- * utf8_split_char(subject)              --> table{char}
-- * utf8_next_int(subject, index)         -- iterator
-- * utf8_next_char(subject, index)        -- iterator
-- * utf8_get_int(subject, index)          -- Julia-style iterator
--                                            returns int, next_index
-- * utf8_get_char(subject, index)         -- Julia-style iterator
--                                            returns char, next_index
--
-- See each function for usage.


local s, t, u = require"string", require"table", require"util"



local _ENV = u.noglobals() ----------------------------------------------------



local copy = u.copy

local s_char, s_sub, s_byte, t_concat, t_insert
    = s.char, s.sub, s.byte, t.concat, t.insert

-------------------------------------------------------------------------------
--- UTF-8
--

-- Utility function.
-- Modified from code by Kein Hong Man <khman@users.sf.net>,
-- found at http://lua-users.org/wiki/SciteUsingUnicode.

local
function utf8_offset (byte)
    if byte < 128 then return 0, byte
    elseif byte < 192 then
        error("Byte values between 0x80 to 0xBF cannot start a multibyte sequence")
    elseif byte < 224 then return 1, byte - 192
    elseif byte < 240 then return 2, byte - 224
    elseif byte < 248 then return 3, byte - 240
    elseif byte < 252 then return 4, byte - 248
    elseif byte < 254 then return 5, byte - 252
    else
        error("Byte values between 0xFE and OxFF cannot start a multibyte sequence")
    end
end


-- validate a given (sub)string.
-- returns two values:
-- * The first is either true, false or nil, respectively on success, error, or
--   incomplete subject.
-- * The second is the index of the last byte of the last valid char.
local
function utf8_validate (subject, start, finish)
    start = start or 1
    finish = finish or #subject

    local offset, char
        = 0
    for i = start,finish do
        local b = s_byte(subject,i)
        if offset == 0 then
            char = i
            success, offset = pcall(utf8_offset, b)
            if not success then return false, char - 1 end
        else
            if not (127 < b and b < 192) then
                return false, char - 1
            end
            offset = offset -1
        end
    end
    if offset ~= 0 then return nil, char - 1 end -- Incomplete input.
    return true, finish
end

-- Usage:
--     for finish, start, cpt in utf8_next_int, "˙†ƒ˙©√" do
--         print(cpt)
--     end
-- `start` and `finish` being the bounds of the character, and `cpt` being the UTF-8 code point.
-- It produces:
--     729
--     8224
--     402
--     729
--     169
--     8730
local
function utf8_next_int (subject, i)
    i = i and i+1 or 1
    if i > #subject then return end
    local c = s_byte(subject, i)
    local offset, val = utf8_offset(c)
    for i = i+1, i+offset do
        c = s_byte(subject, i)
        val = val * 64 + (c-128)
    end
  return i + offset, i, val
end


-- Usage:
--     for finish, start, cpt in utf8_next_char, "˙†ƒ˙©√" do
--         print(cpt)
--     end
-- `start` and `finish` being the bounds of the character, and `cpt` being the UTF-8 code point.
-- It produces:
--     ˙
--     †
--     ƒ
--     ˙
--     ©
--     √
local
function utf8_next_char (subject, i)
    i = i and i+1 or 1
    if i > #subject then return end
    local offset = utf8_offset(s_byte(subject,i))
    return i + offset, i, s_sub(subject, i, i + offset)
end


-- Takes a string, returns an array of code points.
local
function utf8_split_int (subject)
    local chars = {}
    for _, _, c in utf8_next_int, subject do
        t_insert(chars,c)
    end
    return chars
end

-- Takes a string, returns an array of characters.
local
function utf8_split_char (subject)
    local chars = {}
    for _, _, c in utf8_next_char, subject do
        t_insert(chars,c)
    end
    return chars
end

local
function utf8_get_int(subject, i)
    if i > #subject then return end
    local c = s_byte(subject, i)
    local offset, val = utf8_offset(c)
    for i = i+1, i+offset do
        c = s_byte(subject, i)
        val = val * 64 + ( c - 128 )
    end
    return val, i + offset + 1
end

local
function split_generator (get)
    if not get then return end
    return function(subject)
        local res = {}
        local o, i = true
        while o do
            o,i = get(subject, i)
            res[#res] = o
        end
        return res
    end
end

local
function merge_generator (char)
    if not char then return end
    return function(ary)
        local res = {}
        for i = 1, #ary do
            t_insert(res,char(ary[i]))
        end
        return t_concat(res)
    end
end


local
function utf8_get_int2 (subject, i)
    local byte, b5, b4, b3, b2, b1 = s_byte(subject, i)
    if byte < 128 then return byte, i + 1
    elseif byte < 192 then
        error("Byte values between 0x80 to 0xBF cannot start a multibyte sequence")
    elseif byte < 224 then
        return (byte - 192)*64 + s_byte(subject, i+1), i+2
    elseif byte < 240 then
            b2, b1 = s_byte(subject, i+1, i+2)
        return (byte-224)*4096 + b2%64*64 + b1%64, i+3
    elseif byte < 248 then
        b3, b2, b1 = s_byte(subject, i+1, i+2, 1+3)
        return (byte-240)*262144 + b3%64*4096 + b2%64*64 + b1%64, i+4
    elseif byte < 252 then
        b4, b3, b2, b1 = s_byte(subject, i+1, i+2, 1+3, i+4)
        return (byte-248)*16777216 + b4%64*262144 + b3%64*4096 + b2%64*64 + b1%64, i+5
    elseif byte < 254 then
        b5, b4, b3, b2, b1 = s_byte(subject, i+1, i+2, 1+3, i+4, i+5)
        return (byte-252)*1073741824 + b5%64*16777216 + b4%64*262144 + b3%64*4096 + b2%64*64 + b1%64, i+6
    else
        error("Byte values between 0xFE and OxFF cannot start a multibyte sequence")
    end
end


local
function utf8_get_char(subject, i)
    if i > #subject then return end
    local offset = utf8_offset(s_byte(subject,i))
    return s_sub(subject, i, i + offset), i + offset + 1
end

local
function utf8_char(c)
    if     c < 128 then
        return                                                                               s_char(c)
    elseif c < 2048 then
        return                                                          s_char(192 + c/64, 128 + c%64)
    elseif c < 55296 or 57343 < c and c < 65536 then
        return                                         s_char(224 + c/4096, 128 + c/64%64, 128 + c%64)
    elseif c < 2097152 then
        return                      s_char(240 + c/262144, 128 + c/4096%64, 128 + c/64%64, 128 + c%64)
    elseif c < 67108864 then
        return s_char(248 + c/16777216, 128 + c/262144%64, 128 + c/4096%64, 128 + c/64%64, 128 + c%64)
    elseif c < 2147483648 then
        return s_char( 252 + c/1073741824,
                   128 + c/16777216%64, 128 + c/262144%64, 128 + c/4096%64, 128 + c/64%64, 128 + c%64)
    end
    error("Bad Unicode code point: "..c..".")
end

-------------------------------------------------------------------------------
--- ASCII and binary.
--

-- See UTF-8 above for the API docs.

local
function binary_validate (subject, start, finish)
    start = start or 1
    finish = finish or #subject
    return true, finish
end

local
function binary_next_int (subject, i)
    i = i and i+1 or 1
    if i >= #subject then return end
    return i, i, s_sub(subject, i, i)
end

local
function binary_next_char (subject, i)
    i = i and i+1 or 1
    if i > #subject then return end
    return i, i, s_byte(subject,i)
end

local
function binary_split_int (subject)
    local chars = {}
    for i = 1, #subject do
        t_insert(chars, s_byte(subject,i))
    end
    return chars
end

local
function binary_split_char (subject)
    local chars = {}
    for i = 1, #subject do
        t_insert(chars, s_sub(subject,i,i))
    end
    return chars
end

local
function binary_get_int(subject, i)
    return s_byte(subject, i), i + 1
end

local
function binary_get_char(subject, i)
    return s_sub(subject, i, i), i + 1
end


-------------------------------------------------------------------------------
--- The table
--

local charsets = {
    binary = {
        name = "binary",
        binary = true,
        validate   = binary_validate,
        split_char = binary_split_char,
        split_int  = binary_split_int,
        next_char  = binary_next_char,
        next_int   = binary_next_int,
        get_char   = binary_get_char,
        get_int    = binary_get_int,
        tochar    = s_char
    },
    ["UTF-8"] = {
        name = "UTF-8",
        validate   = utf8_validate,
        split_char = utf8_split_char,
        split_int  = utf8_split_int,
        next_char  = utf8_next_char,
        next_int   = utf8_next_int,
        get_char   = utf8_get_char,
        get_int    = utf8_get_int
    }
}

return function (Builder)
    local cs = Builder.options.charset or "binary"
    if charsets[cs] then
        Builder.charset = copy(charsets[cs])
        Builder.binary_split_int = binary_split_int
    else
        error("NYI: custom charsets")
    end
end


--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The LuLPeg library
--
--                                             \
--                                              '.,__
--                                           \  /
--                                            '/,__
--                                            /
--                                           /
--                                          /
--                       has been          / released
--                  ~ ~ ~ ~ ~ ~ ~ ~       ~ ~ ~ ~ ~ ~ ~ ~
--                under  the  Romantic   WTF Public License.
--               ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~`,´ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--               I hereby grant you an irrevocable license to
--                ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                  do what the gentle caress you want to
--                       ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                           with   this   lovely
--                              ~ ~ ~ ~ ~ ~ ~ ~
--                               / thing...
--                              /  ~ ~ ~ ~
--                             /    Love,
--                        #   /      '.'
--                        #######      ·
--                        #####
--                        ###
--                        #
--
--            -- Pierre-Yves
--
--
--            P.S.: Even though I poured my heart into this work,
--                  I _cannot_ provide any warranty regarding
--                  its fitness for _any_ purpose. You
--                  acknowledge that I will not be held liable
--                  for any damage its use could incur.
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["evaluator"])sources["evaluator"]=(\[===\[-- <pack evaluator> --

-- Capture eval

local select, tonumber, tostring, type
    = select, tonumber, tostring, type

local s, t, u = require"string", require"table", require"util"
local s_sub, t_concat
    = s.sub, t.concat

local t_unpack
    = u.unpack

--[[DBG]] local debug, rawset, setmetatable, error, print, expose 
--[[DBG]]     = debug, rawset, setmetatable, error, print, u.expose


local _ENV = u.noglobals() ----------------------------------------------------



return function(Builder, LL) -- Decorator wrapper

--[[DBG]] local cprint = LL.cprint

-- The evaluators and the `insert()` helper take as parameters:
-- * caps: the capture array
-- * sbj:  the subject string
-- * vals: the value accumulator, whose unpacked values will be returned
--         by `pattern:match()`
-- * ci:   the current position in capture array.
-- * vi:   the position of the next value to be inserted in the value accumulator.

local eval = {}

local
function insert (caps, sbj, vals, ci, vi)
    local openclose, kind = caps.openclose, caps.kind
    -- [[DBG]] print("Insert - kind = ", kind[ci])
    while kind[ci] and openclose[ci] >= 0 do
        -- [[DBG]] print("Eval, Pre Insert, kind:", kind[ci], ci)
        ci, vi = eval[kind[ci]](caps, sbj, vals, ci, vi)
        -- [[DBG]] print("Eval, Post Insert, kind:", kind[ci], ci)
    end

    return ci, vi
end

function eval.C (caps, sbj, vals, ci, vi)
    if caps.openclose[ci] > 0 then
        vals[vi] = s_sub(sbj, caps.bounds[ci], caps.openclose[ci] - 1)
        return ci + 1, vi + 1
    end

    vals[vi] = false -- pad it for now
    local cj, vj = insert(caps, sbj, vals, ci + 1, vi + 1)
    vals[vi] = s_sub(sbj, caps.bounds[ci], caps.bounds[cj] - 1)
    return cj + 1, vj
end


local
function lookback (caps, label, ci)
    -- [[DBG]] print("lookback( "..tostring(label).." ), ci = "..ci) --.." ..."); --expose(caps)
    -- [[DBG]] if ci == 9 then error() end
    local aux, openclose, kind= caps.aux, caps.openclose, caps.kind

    repeat
        -- [[DBG]] print("Lookback kind: ", kind[ci], ", ci = "..ci, "oc[ci] = ", openclose[ci], "aux[ci] = ", aux[ci])
        ci = ci - 1
        local auxv, oc = aux[ci], openclose[ci]
        if oc < 0 then ci = ci + oc end
        if oc ~= 0 and kind[ci] == "Clb" and label == auxv then
            -- found.
            return ci
        end
    until ci == 1

    -- not found.
    label = type(label) == "string" and "'"..label.."'" or tostring(label)
    error("back reference "..label.." not found")
end

function eval.Cb (caps, sbj, vals, ci, vi)
    -- [[DBG]] print("Eval Cb, ci = "..ci)
    local Cb_ci = lookback(caps, caps.aux[ci], ci)
    -- [[DBG]] print(" Eval Cb, Cb_ci = "..Cb_ci)
    Cb_ci, vi = eval.Cg(caps, sbj, vals, Cb_ci, vi)
    -- [[DBG]] print("/Eval Cb next kind, ", caps.kind[ci + 1], "Values = ..."); expose(vals)

    return ci + 1, vi
end


function eval.Cc (caps, sbj, vals, ci, vi)
    local these_values = caps.aux[ci]
    -- [[DBG]] print"Eval Cc"; expose(these_values)
    for i = 1, these_values.n do
        vi, vals[vi] = vi + 1, these_values[i]
    end
    return ci + 1, vi
end



eval["Cf"] = function() error("NYI: Cf") end

function eval.Cf (caps, sbj, vals, ci, vi)
    if caps.openclose[ci] > 0 then
        error"No First Value"
    end

    local func, Cf_vals, Cf_vi = caps.aux[ci], {}
    ci = ci + 1
    ci, Cf_vi = eval[caps.kind[ci]](caps, sbj, Cf_vals, ci, 1)

    if Cf_vi == 1 then
        error"No first value"
    end

    local result = Cf_vals[1]

    while caps.kind[ci] and caps.openclose[ci] >= 0 do
        ci, Cf_vi = eval[caps.kind[ci]](caps, sbj, Cf_vals, ci, 1)
        result = func(result, t_unpack(Cf_vals, 1, Cf_vi - 1))
    end
    vals[vi] = result
    return ci +1, vi + 1
end



function eval.Cg (caps, sbj, vals, ci, vi)
    -- [[DBG]] print("Gc - caps", ci, caps.openclose[ci]) expose(caps)
    if caps.openclose[ci] > 0 then
        -- [[DBG]] print("Cg - closed")
        vals[vi] = s_sub(sbj, caps.bounds[ci], caps.openclose[ci] - 1)
        return ci + 1, vi + 1
    end
        -- [[DBG]] print("Cg - open ci = ", ci)

    local cj, vj = insert(caps, sbj, vals, ci + 1, vi)
    if vj == vi then 
        -- [[DBG]] print("Cg - no inner values")        
        vals[vj] = s_sub(sbj, caps.bounds[ci], caps.bounds[cj] - 1)
        vj = vj + 1
    end
    return cj + 1, vj
end


function eval.Clb (caps, sbj, vals, ci, vi)
    local oc = caps.openclose
    if oc[ci] > 0 then
        return ci + 1, vi 
    end

    local depth = 0
    repeat
        if oc[ci] == 0 then depth = depth + 1
        elseif oc[ci] < 0 then depth = depth - 1
        end
        ci = ci + 1
    until depth == 0
    return ci, vi
end


function eval.Cp (caps, sbj, vals, ci, vi)
    vals[vi] = caps.bounds[ci]
    return ci + 1, vi + 1
end


function eval.Ct (caps, sbj, vals, ci, vi)
    local aux, openclose, kind = caps. aux, caps.openclose, caps.kind
    local tbl_vals = {}
    vals[vi] = tbl_vals

    if openclose[ci] > 0 then
        return ci + 1, vi + 1
    end

    local tbl_vi, Clb_vals = 1, {}
    ci = ci + 1

    while kind[ci] and openclose[ci] >= 0 do
        if kind[ci] == "Clb" then
            local label, Clb_vi = aux[ci], 1
            ci, Clb_vi = eval.Cg(caps, sbj, Clb_vals, ci, 1)
            if Clb_vi ~= 1 then tbl_vals[label] = Clb_vals[1] end
        else
            ci, tbl_vi =  eval[kind[ci]](caps, sbj, tbl_vals, ci, tbl_vi)
        end
    end
    return ci + 1, vi + 1
end

local inf = 1/0

function eval.value (caps, sbj, vals, ci, vi)
    local val 
    -- nils are encoded as inf in both aux and openclose.
    if caps.aux[ci] ~= inf or caps.openclose[ci] ~= inf
        then val = caps.aux[ci]
        -- [[DBG]] print("Eval value = ", val)
    end

    vals[vi] = val
    return ci + 1, vi + 1
end


function eval.Cs (caps, sbj, vals, ci, vi)
    -- [[DBG]] print("Eval Cs - ci = "..ci..", vi = "..vi)
    if caps.openclose[ci] > 0 then
        vals[vi] = s_sub(sbj, caps.bounds[ci], caps.openclose[ci] - 1)
    else
        local bounds, kind, openclose = caps.bounds, caps.kind, caps.openclose
        local start, buffer, Cs_vals, bi, Cs_vi = bounds[ci], {}, {}, 1, 1
        local last
        ci = ci + 1
        -- [[DBG]] print"eval.CS, openclose: "; expose(openclose)
        -- [[DBG]] print("eval.CS, ci =", ci)
        while openclose[ci] >= 0 do
            -- [[DBG]] print(" eval Cs - ci = "..ci..", bi = "..bi.." - LOOP - Buffer = ...")
            -- [[DBG]] u.expose(buffer)
            -- [[DBG]] print(" eval - Cs kind = "..kind[ci])

            last = bounds[ci]
            buffer[bi] = s_sub(sbj, start, last - 1)
            bi = bi + 1

            ci, Cs_vi = eval[kind[ci]](caps, sbj, Cs_vals, ci, 1)
            -- [[DBG]] print("  Cs post eval ci = "..ci..", Cs_vi = "..Cs_vi)
            if Cs_vi > 1 then
                buffer[bi] = Cs_vals[1]
                bi = bi + 1
                start = openclose[ci-1] > 0 and openclose[ci-1] or bounds[ci-1]
            else
                start = last
            end

        -- [[DBG]] print("eval.CS while, ci =", ci)
        end
        buffer[bi] = s_sub(sbj, start, bounds[ci] - 1)

        vals[vi] = t_concat(buffer)
    end
    -- [[DBG]] print("/Eval Cs - ci = "..ci..", vi = "..vi)

    return ci + 1, vi + 1
end


local
function insert_divfunc_results(acc, val_i, ...)
    local n = select('#', ...)
    for i = 1, n do
        val_i, acc[val_i] = val_i + 1, select(i, ...)
    end
    return val_i
end

function eval.div_function (caps, sbj, vals, ci, vi)
    local func = caps.aux[ci]
    local params, divF_vi

    if caps.openclose[ci] > 0 then
        params, divF_vi = {s_sub(sbj, caps.bounds[ci], caps.openclose[ci] - 1)}, 2
    else
        params = {}
        ci, divF_vi = insert(caps, sbj, params, ci + 1, 1)
    end

    ci = ci + 1 -- skip the closed or closing node.
    vi = insert_divfunc_results(vals, vi, func(t_unpack(params, 1, divF_vi - 1)))
    return ci, vi
end


function eval.div_number (caps, sbj, vals, ci, vi)
    local this_aux = caps.aux[ci]
    local divN_vals, divN_vi

    if caps.openclose[ci] > 0 then
        divN_vals, divN_vi = {s_sub(sbj, caps.bounds[ci], caps.openclose[ci] - 1)}, 2
    else
        divN_vals = {}
        ci, divN_vi = insert(caps, sbj, divN_vals, ci + 1, 1)
    end
    ci = ci + 1 -- skip the closed or closing node.

    if this_aux >= divN_vi then error("no capture '"..this_aux.."' in /number capture.") end
    vals[vi] = divN_vals[this_aux]
    return ci, vi + 1
end


local function div_str_cap_refs (caps, ci)
    local opcl = caps.openclose
    local refs = {open=caps.bounds[ci]}

    if opcl[ci] > 0 then
        refs.close = opcl[ci]
        return ci + 1, refs, 0
    end

    local first_ci = ci
    local depth = 1
    ci = ci + 1
    repeat
        local oc = opcl[ci]
        -- [[DBG]] print("/''refs", caps.kind[ci], ci, oc, depth)
        if depth == 1  and oc >= 0 then refs[#refs+1] = ci end
        if oc == 0 then 
            depth = depth + 1
        elseif oc < 0 then
            depth = depth - 1
        end
        ci = ci + 1
    until depth == 0
    -- [[DBG]] print("//''refs", ci, ci - first_ci)
    -- [[DBG]] expose(refs)
    -- [[DBG]] print"caps"
    -- [[DBG]] expose(caps)
    refs.close = caps.bounds[ci - 1]
    return ci, refs, #refs
end

function eval.div_string (caps, sbj, vals, ci, vi)
    -- [[DBG]] print("div_string ci = "..ci..", vi = "..vi )
    local n, refs
    local cached
    local cached, divS_vals = {}, {}
    local the_string = caps.aux[ci]

    ci, refs, n = div_str_cap_refs(caps, ci)
    -- [[DBG]] print("  REFS div_string ci = "..ci..", n = ", n, ", refs = ...")
    -- [[DBG]] expose(refs)
    vals[vi] = the_string:gsub("%%([%d%%])", function (d)
        if d == "%" then return "%" end
        d = tonumber(d)
        if not cached[d] then
            if d > n then
                error("no capture at index "..d.." in /string capture.")
            end
            if d == 0 then
                cached[d] = s_sub(sbj, refs.open, refs.close - 1)
            else
                local _, vi = eval[caps.kind[refs[d]]](caps, sbj, divS_vals, refs[d], 1)
                if vi == 1 then error("no values in capture at index"..d.." in /string capture.") end
                cached[d] = divS_vals[1]
            end
        end
        return cached[d]
    end)
    -- [[DBG]] u.expose(vals)
    -- [[DBG]] print("/div_string ci = "..ci..", vi = "..vi )
    return ci, vi + 1
end


function eval.div_table (caps, sbj, vals, ci, vi)
    -- [[DBG]] print("Div_table ci = "..ci..", vi = "..vi )
    local this_aux = caps.aux[ci]
    local key

    if caps.openclose[ci] > 0 then
        key =  s_sub(sbj, caps.bounds[ci], caps.openclose[ci] - 1)
    else
        local divT_vals, _ = {}
        ci, _ = insert(caps, sbj, divT_vals, ci + 1, 1)
        key = divT_vals[1]
    end

    ci = ci + 1
    -- [[DBG]] print("/div_table ci = "..ci..", vi = "..vi )
    -- [[DBG]] print(type(key), key, "...")
    -- [[DBG]] expose(this_aux)
    if this_aux[key] then
        -- [[DBG]] print("/{} success")
        vals[vi] = this_aux[key]
        return ci, vi + 1
    else
        return ci, vi
    end
end



function LL.evaluate (caps, sbj, ci)
    -- [[DBG]] print("*** Eval", caps, sbj, ci)
    -- [[DBG]] expose(caps)
    -- [[DBG]] cprint(caps, sbj, ci)
    local vals = {}
    -- [[DBG]] vals = setmetatable({}, {__newindex = function(self, k,v) 
    -- [[DBG]]     print("set Val, ", k, v, debug.traceback(1)) rawset(self, k, v) 
    -- [[DBG]] end})
    local _,  vi = insert(caps, sbj, vals, ci, 1)
    return vals, 1, vi - 1
end


end  -- Decorator wrapper


--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The LuLPeg library
--
--                                             \
--                                              '.,__
--                                           \  /
--                                            '/,__
--                                            /
--                                           /
--                                          /
--                       has been          / released
--                  ~ ~ ~ ~ ~ ~ ~ ~       ~ ~ ~ ~ ~ ~ ~ ~
--                under  the  Romantic   WTF Public License.
--               ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~`,´ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--               I hereby grant you an irrevocable license to
--                ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                  do what the gentle caress you want to
--                       ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                           with   this   lovely
--                              ~ ~ ~ ~ ~ ~ ~ ~
--                               / thing...
--                              /  ~ ~ ~ ~
--                             /    Love,
--                        #   /      '.'
--                        #######      ·
--                        #####
--                        ###
--                        #
--
--            -- Pierre-Yves
--
--
--            P.S.: Even though I poured my heart into this work,
--                  I _cannot_ provide any warranty regarding
--                  its fitness for _any_ purpose. You
--                  acknowledge that I will not be held liable
--                  for any damage its use could incur.
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["printers"])sources["printers"]=(\[===\[-- <pack printers> --
return function(Builder, LL)

-- Print

local ipairs, pairs, print, tostring, type
    = ipairs, pairs, print, tostring, type

local s, t, u = require"string", require"table", require"util"
local S_tostring = Builder.set.tostring


local _ENV = u.noglobals() ----------------------------------------------------



local s_char, s_sub, t_concat
    = s.char, s.sub, t.concat

local   expose,   load,   map
    = u.expose, u.load, u.map

local escape_index = {
    ["\f"] = "\\f",
    ["\n"] = "\\n",
    ["\r"] = "\\r",
    ["\t"] = "\\t",
    ["\v"] = "\\v",
    ["\127"] = "\\ESC"
}

local function flatten(kind, list)
    if list[2].pkind == kind then
        return list[1], flatten(kind, list[2])
    else
        return list[1], list[2]
    end
end

for i = 0, 8 do escape_index[s_char(i)] = "\\"..i end
for i = 14, 31 do escape_index[s_char(i)] = "\\"..i end

local
function escape( str )
    return str:gsub("%c", escape_index)
end

local
function set_repr (set) 
    return s_char(load("return "..S_tostring(set))())
end


local printers = {}

local
function LL_pprint (pt, offset, prefix)
    -- [[DBG]] print("PRINT -", pt)
    -- [[DBG]] print("PRINT +", pt.pkind)
    -- [[DBG]] expose(pt)
    -- [[DBG]] expose(LL.proxycache[pt])
    return printers[pt.pkind](pt, offset, prefix)
end

function LL.pprint (pt0)
    local pt = LL.P(pt0)
    print"\nPrint pattern"
    LL_pprint(pt, "", "")
    print"--- /pprint\n"
    return pt0
end

for k, v in pairs{
    string       = [[ "P( \""..escape(pt.as_is).."\" )"       ]],
    char         = [[ "P( \""..escape(to_char(pt.aux)).."\" )"]],
    ["true"]     = [[ "P( true )"                     ]],
    ["false"]    = [[ "P( false )"                    ]],
    eos          = [[ "~EOS~"                         ]],
    one          = [[ "P( one )"                      ]],
    any          = [[ "P( "..pt.aux.." )"             ]],
    set          = [[ "S( "..'"'..escape(set_repr(pt.aux))..'"'.." )" ]],
    ["function"] = [[ "P( "..pt.aux.." )"             ]],
    ref = [[
        "V( ",
            (type(pt.aux) == "string" and "\""..pt.aux.."\"")
                          or tostring(pt.aux)
        , " )"
        ]],
    range = [[
        "R( ",
            escape(t_concat(map(
                pt.as_is,
                function(e) return '"'..e..'"' end)
            , ", "))
        ," )"
        ]]
} do
    printers[k] = load(([==[
        local k, map, t_concat, to_char, escape, set_repr = ...
        return function (pt, offset, prefix)
            print(t_concat{offset,prefix,XXXX})
        end
    ]==]):gsub("XXXX", v), k.." printer")(k, map, t_concat, s_char, escape, set_repr)
end


for k, v in pairs{
    ["behind"] = [[ LL_pprint(pt.pattern, offset, "B ") ]],
    ["at least"] = [[ LL_pprint(pt.pattern, offset, pt.aux.." ^ ") ]],
    ["at most"] = [[ LL_pprint(pt.pattern, offset, pt.aux.." ^ ") ]],
    unm        = [[LL_pprint(pt.pattern, offset, "- ")]],
    lookahead  = [[LL_pprint(pt.pattern, offset, "# ")]],
    choice = [[
        print(offset..prefix.."+")
        -- dprint"Printer for choice"
        local ch, i = {}, 1
        while pt.pkind == "choice" do
            ch[i], pt, i = pt[1], pt[2], i + 1
        end
        ch[i] = pt

        map(ch, LL_pprint, offset.." :", "")
        ]],
    sequence = [=[
        -- print("Seq printer", s, u)
        -- u.expose(pt)
        print(offset..prefix.."*")
        local acc, p2 = {}
        offset = offset .. " |"
        while true do
            if pt.pkind ~= "sequence" then -- last element
                if pt.pkind == "char" then
                    acc[#acc + 1] = pt.aux
                    print(offset..'P( "'..s.char(u.unpack(acc))..'" )')
                else
                    if #acc ~= 0 then
                        print(offset..'P( "'..s.char(u.unpack(acc))..'" )')
                    end
                    LL_pprint(pt, offset, "")
                end
                break
            elseif pt[1].pkind == "char" then
                acc[#acc + 1] = pt[1].aux
            elseif #acc ~= 0 then
                print(offset..'P( "'..s.char(u.unpack(acc))..'" )')
                acc = {}
                LL_pprint(pt[1], offset, "")
            else
                LL_pprint(pt[1], offset, "")
            end
            pt = pt[2]
        end
        ]=],
    grammar   = [[
        print(offset..prefix.."Grammar")
        -- dprint"Printer for Grammar"
        for k, pt in pairs(pt.aux) do
            local prefix = ( type(k)~="string"
                             and tostring(k)
                             or "\""..k.."\"" )
            LL_pprint(pt, offset.."  ", prefix .. " = ")
        end
    ]]
} do
    printers[k] = load(([[
        local map, LL_pprint, pkind, s, u, flatten = ...
        return function (pt, offset, prefix)
            XXXX
        end
    ]]):gsub("XXXX", v), k.." printer")(map, LL_pprint, type, s, u, flatten)
end

-------------------------------------------------------------------------------
--- Captures patterns
--

-- for _, cap in pairs{"C", "Cs", "Ct"} do
-- for _, cap in pairs{"Carg", "Cb", "Cp"} do
-- function LL_Cc (...)
-- for _, cap in pairs{"Cf", "Cmt"} do
-- function LL_Cg (pt, tag)
-- local valid_slash_type = newset{"string", "number", "table", "function"}


for _, cap in pairs{"C", "Cs", "Ct"} do
    printers[cap] = function (pt, offset, prefix)
        print(offset..prefix..cap)
        LL_pprint(pt.pattern, offset.."  ", "")
    end
end

for _, cap in pairs{"Cg", "Clb", "Cf", "Cmt", "div_number", "/zero", "div_function", "div_table"} do
    printers[cap] = function (pt, offset, prefix)
        print(offset..prefix..cap.." "..tostring(pt.aux or ""))
        LL_pprint(pt.pattern, offset.."  ", "")
    end
end

printers["div_string"] = function (pt, offset, prefix)
    print(offset..prefix..'/string "'..tostring(pt.aux or "")..'"')
    LL_pprint(pt.pattern, offset.."  ", "")
end

for _, cap in pairs{"Carg", "Cp"} do
    printers[cap] = function (pt, offset, prefix)
        print(offset..prefix..cap.."( "..tostring(pt.aux).." )")
    end
end

printers["Cb"] = function (pt, offset, prefix)
    print(offset..prefix.."Cb( \""..pt.aux.."\" )")
end

printers["Cc"] = function (pt, offset, prefix)
    print(offset..prefix.."Cc(" ..t_concat(map(pt.aux, tostring),", ").." )")
end


-------------------------------------------------------------------------------
--- Capture objects
--

local cprinters = {}

local padding = "   "
local function padnum(n)
    n = tostring(n)
    n = n .."."..((" "):rep(4 - #n))
    return n
end

local function _cprint(caps, ci, indent, sbj, n)
    local openclose, kind = caps.openclose, caps.kind
    indent = indent or 0
    while kind[ci] and openclose[ci] >= 0 do
        if caps.openclose[ci] > 0 then 
            print(t_concat({
                            padnum(n),
                            padding:rep(indent),
                            caps.kind[ci],
                            ": start = ", tostring(caps.bounds[ci]),
                            " finish = ", tostring(caps.openclose[ci]),
                            caps.aux[ci] and " aux = " or "",
                            caps.aux[ci] and (
                                type(caps.aux[ci]) == "string" 
                                    and '"'..tostring(caps.aux[ci])..'"'
                                or tostring(caps.aux[ci])
                            ) or "",
                            " \t", s_sub(sbj, caps.bounds[ci], caps.openclose[ci] - 1)
                        }))
            if type(caps.aux[ci]) == "table" then expose(caps.aux[ci]) end
        else
            local kind = caps.kind[ci]
            local start = caps.bounds[ci]
            print(t_concat({
                            padnum(n),
                            padding:rep(indent), kind,
                            ": start = ", start,
                            caps.aux[ci] and " aux = " or "",
                            caps.aux[ci] and (
                                type(caps.aux[ci]) == "string" 
                                    and '"'..tostring(caps.aux[ci])..'"'
                                or tostring(caps.aux[ci])
                            ) or ""
                        }))
            ci, n = _cprint(caps, ci + 1, indent + 1, sbj, n + 1)
            print(t_concat({
                            padnum(n),
                            padding:rep(indent),
                            "/", kind,
                            " finish = ", tostring(caps.bounds[ci]),
                            " \t", s_sub(sbj, start, (caps.bounds[ci] or 1) - 1)
                        }))
        end
        n = n + 1
        ci = ci + 1
    end

    return ci, n
end

function LL.cprint (caps, ci, sbj)
    ci = ci or 1
    print"\nCapture Printer:\n================"
    -- print(capture)
    -- [[DBG]] expose(caps)
    _cprint(caps, ci, 0, sbj, 1)
    print"================\n/Cprinter\n"
end




return { pprint = LL.pprint,cprint = LL.cprint }

end -- module wrapper ---------------------------------------------------------


--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The LuLPeg library
--
--                                             \
--                                              '.,__
--                                           \  /
--                                            '/,__
--                                            /
--                                           /
--                                          /
--                       has been          / released
--                  ~ ~ ~ ~ ~ ~ ~ ~       ~ ~ ~ ~ ~ ~ ~ ~
--                under  the  Romantic   WTF Public License.
--               ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~`,´ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--               I hereby grant you an irrevocable license to
--                ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                  do what the gentle caress you want to
--                       ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                           with   this   lovely
--                              ~ ~ ~ ~ ~ ~ ~ ~
--                               / thing...
--                              /  ~ ~ ~ ~
--                             /    Love,
--                        #   /      '.'
--                        #######      ·
--                        #####
--                        ###
--                        #
--
--            -- Pierre-Yves
--
--
--            P.S.: Even though I poured my heart into this work,
--                  I _cannot_ provide any warranty regarding
--                  its fitness for _any_ purpose. You
--                  acknowledge that I will not be held liable
--                  for any damage its use could incur.
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["analizer"])sources["analizer"]=(\[===\[-- <pack analizer> --

-- A stub at the moment.

local u = require"util"
local nop, weakkey = u.nop, u.weakkey

local hasVcache, hasCmtcache , lengthcache
    = weakkey{}, weakkey{},    weakkey{}

return {
    hasV = nop,
    hasCmt = nop,
    length = nop,
    hasCapture = nop
}


--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The PureLPeg library
--
--                                             \
--                                              '.,__
--                                           \  /
--                                            '/,__
--                                            /
--                                           /
--                                          /
--                       has been          / released
--                  ~ ~ ~ ~ ~ ~ ~ ~       ~ ~ ~ ~ ~ ~ ~ ~
--                under  the  Romantic   WTF Public License.
--               ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~`,´ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--               I hereby grant you an irrevocable license to
--                ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                  do what the gentle caress you want to
--                       ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                           with   this   lovely
--                              ~ ~ ~ ~ ~ ~ ~ ~
--                               / thing...
--                              /  ~ ~ ~ ~
--                             /    Love,
--                        #   /      '.'
--                        #######      ·
--                        #####
--                        ###
--                        #
--
--            -- Pierre-Yves
--
--
--            P.S.: Even though I poured my heart into this work,
--                  I _cannot_ provide any warranty regarding
--                  its fitness for _any_ purpose. You
--                  acknowledge that I will not be held liable
--                  for any damage its use could incur.
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["locale"])sources["locale"]=(\[===\[-- <pack locale> --

-- Locale definition.

local extend = require"util".extend



local _ENV = require"util".noglobals() ----------------------------------------



-- We'll limit ourselves to the standard C locale for now.
-- see http://wayback.archive.org/web/20120310215042/http://www.utas.edu.au...
-- .../infosys/info/documentation/C/CStdLib.html#ctype.h

return function(Builder, LL) -- Module wrapper {-------------------------------

local R, S = LL.R, LL.S

local locale = {}
locale["cntrl"] = R"\0\31" + "\127"
locale["digit"] = R"09"
locale["lower"] = R"az"
locale["print"] = R" ~" -- 0x20 to 0xee
locale["space"] = S" \f\n\r\t\v" -- \f == form feed (for a printer), \v == vtab
locale["upper"] = R"AZ"

locale["alpha"]  = locale["lower"] + locale["upper"]
locale["alnum"]  = locale["alpha"] + locale["digit"]
locale["graph"]  = locale["print"] - locale["space"]
locale["punct"]  = locale["graph"] - locale["alnum"]
locale["xdigit"] = locale["digit"] + R"af" + R"AF"


function LL.locale (t)
    return extend(t or {}, locale)
end

end -- Module wrapper --------------------------------------------------------}


--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The LuLPeg library
--
--                                             \
--                                              '.,__
--                                           \  /
--                                            '/,__
--                                            /
--                                           /
--                                          /
--                       has been          / released
--                  ~ ~ ~ ~ ~ ~ ~ ~       ~ ~ ~ ~ ~ ~ ~ ~
--                under  the  Romantic   WTF Public License.
--               ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~`,´ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--               I hereby grant you an irrevocable license to
--                ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                  do what the gentle caress you want to
--                       ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                           with   this   lovely
--                              ~ ~ ~ ~ ~ ~ ~ ~
--                               / thing...
--                              /  ~ ~ ~ ~
--                             /    Love,
--                        #   /      '.'
--                        #######      ·
--                        #####
--                        ###
--                        #
--
--            -- Pierre-Yves
--
--
--            P.S.: Even though I poured my heart into this work,
--                  I _cannot_ provide any warranty regarding
--                  its fitness for _any_ purpose. You
--                  acknowledge that I will not be held liable
--                  for any damage its use could incur.
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["match"])sources["match"]=(\[===\[-- <pack match> --

\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["factorizer"])sources["factorizer"]=(\[===\[-- <pack factorizer> --
local ipairs, pairs, print, setmetatable
    = ipairs, pairs, print, setmetatable

--[[DBG]] local debug = require "debug"
local u = require"util"

local   id,   nop,   setify,   weakkey
    = u.id, u.nop, u.setify, u.weakkey

local _ENV = u.noglobals() ----------------------------------------------------



---- helpers
--

-- handle the identity or break properties of P(true) and P(false) in
-- sequences/arrays.
local
function process_booleans(a, b, opts)
    local id, brk = opts.id, opts.brk
    if a == id then return true, b
    elseif b == id then return true, a
    elseif a == brk then return true, brk
    else return false end
end

-- patterns where `C(x) + C(y) => C(x + y)` apply.
local unary = setify{
    "unm", "lookahead", "C", "Cf",
    "Cg", "Cs", "Ct", "/zero"
}

local unary_aux = setify{
    "behind", "at least", "at most", "Clb", "Cmt",
    "div_string", "div_number", "div_table", "div_function"
}

-- patterns where p1 + p2 == p1 U p2
local unifiable = setify{"char", "set", "range"}


local hasCmt; hasCmt = setmetatable({}, {__mode = "k", __index = function(self, pt)
    local kind, res = pt.pkind, false
    if kind == "Cmt"
    or kind == "ref"
    then
        res = true
    elseif unary[kind] or unary_aux[kind] then
        res = hasCmt[pt.pattern]
    elseif kind == "choice" or kind == "sequence" then
        res = hasCmt[pt[1]] or hasCmt[pt[2]]
    end
    hasCmt[pt] = res
    return res
end})



return function (Builder, LL) --------------------------------------------------

if Builder.options.factorize == false then
    return {
        choice = nop,
        sequence = nop,
        lookahead = nop,
        unm = nop
    }
end

local constructors, LL_P =  Builder.constructors, LL.P
local truept, falsept
    = constructors.constant.truept
    , constructors.constant.falsept

local --Range, Set,
    S_union
    = --Builder.Range, Builder.set.new,
    Builder.set.union

local mergeable = setify{"char", "set"}


local type2cons = {
    ["/zero"] = "__div",
    ["div_number"] = "__div",
    ["div_string"] = "__div",
    ["div_table"] = "__div",
    ["div_function"] = "__div",
    ["at least"] = "__exp",
    ["at most"] = "__exp",
    ["Clb"] = "Cg",
}

local
function choice (a, b)
    do  -- handle the identity/break properties of true and false.
        local hasbool, res = process_booleans(a, b, { id = falsept, brk = truept })
        if hasbool then return res end
    end
    local ka, kb = a.pkind, b.pkind
    if a == b and not hasCmt[a] then
        return a
    elseif ka == "choice" then -- correct associativity without blowing up the stack
        local acc, i = {}, 1
        while a.pkind == "choice" do
            acc[i], a, i = a[1], a[2], i + 1
        end
        acc[i] = a
        for j = i, 1, -1 do
            b = acc[j] + b
        end
        return b
    elseif mergeable[ka] and mergeable[kb] then
        return constructors.aux("set", S_union(a.aux, b.aux))
    elseif mergeable[ka] and kb == "any" and b.aux == 1
    or     mergeable[kb] and ka == "any" and a.aux == 1 then
        -- [[DBG]] print("=== Folding "..ka.." and "..kb..".")
        return ka == "any" and a or b
    elseif ka == kb then
        -- C(a) + C(b) => C(a + b)
        if (unary[ka] or unary_aux[ka]) and ( a.aux == b.aux ) then
            return LL[type2cons[ka] or ka](a.pattern + b.pattern, a.aux)
        elseif ( ka == kb ) and ka == "sequence" then
            -- "ab" + "ac" => "a" * ( "b" + "c" )
            if a[1] == b[1]  and not hasCmt[a[1]] then
                return a[1] * (a[2] + b[2])
            end
        end
    end
    return false
end



local
function lookahead (pt)
    return pt
end


local
function sequence(a, b)
    -- [[DBG]] print("Factorize Sequence")
    -- A few optimizations:
    -- 1. handle P(true) and P(false)
    do
        local hasbool, res = process_booleans(a, b, { id = truept, brk = falsept })
        if hasbool then return res end
    end
    -- 2. Fix associativity
    local ka, kb = a.pkind, b.pkind
    if ka == "sequence" then -- correct associativity without blowing up the stack
        local acc, i = {}, 1
        while a.pkind == "sequence" do
            acc[i], a, i = a[1], a[2], i + 1
        end
        acc[i] = a
        for j = i, 1, -1 do
            b = acc[j] * b
        end
        return b
    elseif (ka == "one" or ka == "any") and (kb == "one" or kb == "any") then
        return LL_P(a.aux + b.aux)
    end
    return false
end

local
function unm (pt)
    -- [[DP]] print("Factorize Unm")
    if     pt == truept            then return falsept
    elseif pt == falsept           then return truept
    elseif pt.pkind == "unm"       then return #pt.pattern
    elseif pt.pkind == "lookahead" then return -pt.pattern
    end
end

return {
    choice = choice,
    lookahead = lookahead,
    sequence = sequence,
    unm = unm
}
end

--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The LuLPeg library
--
--                                             \
--                                              '.,__
--                                           \  /
--                                            '/,__
--                                            /
--                                           /
--                                          /
--                       has been          / released
--                  ~ ~ ~ ~ ~ ~ ~ ~       ~ ~ ~ ~ ~ ~ ~ ~
--                under  the  Romantic   WTF Public License.
--               ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~`,´ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--               I hereby grant you an irrevocable license to
--                ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                  do what the gentle caress you want to
--                       ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                           with   this   lovely
--                              ~ ~ ~ ~ ~ ~ ~ ~
--                               / thing...
--                              /  ~ ~ ~ ~
--                             /    Love,
--                        #   /      '.'
--                        #######      ·
--                        #####
--                        ###
--                        #
--
--            -- Pierre-Yves
--
--
--            P.S.: Even though I poured my heart into this work,
--                  I _cannot_ provide any warranty regarding
--                  its fitness for _any_ purpose. You
--                  acknowledge that I will not be held liable
--                  for any damage its use could incur.
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["API"])sources["API"]=(\[===\[-- <pack API> --

-- API.lua

-- What follows is the core LPeg functions, the public API to create patterns.
-- Think P(), R(), pt1 + pt2, etc.
local assert, error, ipairs, pairs, pcall, print
    , require, select, tonumber, tostring, type
    = assert, error, ipairs, pairs, pcall, print
    , require, select, tonumber, tostring, type

local t, u = require"table", require"util"

--[[DBG]] local debug = require"debug"



local _ENV = u.noglobals() ---------------------------------------------------



local t_concat = t.concat

local   checkstring,   copy,   fold,   load,   map_fold,   map_foldr,   setify, t_pack, t_unpack
    = u.checkstring, u.copy, u.fold, u.load, u.map_fold, u.map_foldr, u.setify, u.pack, u.unpack

--[[DBG]] local expose = u.expose

local
function charset_error(index, charset)
    error("Character at position ".. index + 1
            .." is not a valid "..charset.." one.",
        2)
end


------------------------------------------------------------------------------
return function(Builder, LL) -- module wrapper -------------------------------
------------------------------------------------------------------------------


local cs = Builder.charset

local constructors, LL_ispattern
    = Builder.constructors, LL.ispattern

local truept, falsept, Cppt
    = constructors.constant.truept
    , constructors.constant.falsept
    , constructors.constant.Cppt

local    split_int,    validate
    = cs.split_int, cs.validate

local Range, Set, S_union, S_tostring
    = Builder.Range, Builder.set.new
    , Builder.set.union, Builder.set.tostring

-- factorizers, defined at the end of the file.
local factorize_choice, factorize_lookahead, factorize_sequence, factorize_unm


local
function makechar(c)
    return constructors.aux("char", c)
end

local
function LL_P (...)
    local v, n = (...), select('#', ...)
    if n == 0 then error"bad argument #1 to 'P' (value expected)" end
    local typ = type(v)
    if LL_ispattern(v) then
        return v
    elseif typ == "function" then
        return 
            --[[DBG]] true and 
            LL.Cmt("", v)
    elseif typ == "string" then
        local success, index = validate(v)
        if not success then
            charset_error(index, cs.name)
        end
        if v == "" then return truept end
        return 
            --[[DBG]] true and 
            map_foldr(split_int(v), makechar, Builder.sequence)
    elseif typ == "table" then
        -- private copy because tables are mutable.
        local g = copy(v)
        if g[1] == nil then error("grammar has no initial rule") end
        if not LL_ispattern(g[1]) then g[1] = LL.V(g[1]) end
        return
            --[[DBG]] true and
            constructors.none("grammar", g)
    elseif typ == "boolean" then
        return v and truept or falsept
    elseif typ == "number" then
        if v == 0 then
            return truept
        elseif v > 0 then
            return
                --[[DBG]] true and
                constructors.aux("any", v)
        else
            return
                --[[DBG]] true and
                - constructors.aux("any", -v)
        end
    else
        error("bad argument #1 to 'P' (lpeg-pattern expected, got "..typ..")")
    end
end
LL.P = LL_P

local
function LL_S (set)
    if set == "" then
        return
            --[[DBG]] true and
            falsept
    else
        local success
        set = checkstring(set, "S")
        return
            --[[DBG]] true and
            constructors.aux("set", Set(split_int(set)), set)
    end
end
LL.S = LL_S

local
function LL_R (...)
    if select('#', ...) == 0 then
        return LL_P(false)
    else
        local range = Range(1,0)--Set("")
        -- [[DBG]]expose(range)
        for _, r in ipairs{...} do
            r = checkstring(r, "R")
            assert(#r == 2, "bad argument #1 to 'R' (range must have two characters)")
            range = S_union ( range, Range(t_unpack(split_int(r))) )
        end
        -- [[DBG]] local p = constructors.aux("set", range, representation)
        return
            --[[DBG]] true and
            constructors.aux("set", range)
    end
end
LL.R = LL_R

local
function LL_V (name)
    assert(name ~= nil)
    return
        --[[DBG]] true and
        constructors.aux("ref",  name)
end
LL.V = LL_V



do
    local one = setify{"set", "range", "one", "char"}
    local zero = setify{"true", "false", "lookahead", "unm"}
    local forbidden = setify{
        "Carg", "Cb", "C", "Cf",
        "Cg", "Cs", "Ct", "/zero",
        "Clb", "Cmt", "Cc", "Cp",
        "div_string", "div_number", "div_table", "div_function",
        "at least", "at most", "behind"
    }
    local function fixedlen(pt, gram, cycle)
        -- [[DP]] print("Fixed Len",pt.pkind)
        local typ = pt.pkind
        if forbidden[typ] then return false
        elseif one[typ]  then return 1
        elseif zero[typ] then return 0
        elseif typ == "string" then return #pt.as_is
        elseif typ == "any" then return pt.aux
        elseif typ == "choice" then
            local l1, l2 = fixedlen(pt[1], gram, cycle), fixedlen(pt[2], gram, cycle)
            return (l1 == l2) and l1
        elseif typ == "sequence" then
            local l1, l2 = fixedlen(pt[1], gram, cycle), fixedlen(pt[2], gram, cycle)
            return l1 and l2 and l1 + l2
        elseif typ == "grammar" then
            if pt.aux[1].pkind == "ref" then
                return fixedlen(pt.aux[pt.aux[1].aux], pt.aux, {})
            else
                return fixedlen(pt.aux[1], pt.aux, {})
            end
        elseif typ == "ref" then
            if cycle[pt] then return false end
            cycle[pt] = true
            return fixedlen(gram[pt.aux], gram, cycle)
        else
            print(typ,"is not handled by fixedlen()")
        end
    end

    function LL.B (pt)
        pt = LL_P(pt)
        -- [[DP]] print("LL.B")
        -- [[DP]] LL.pprint(pt)
        local len = fixedlen(pt)
        assert(len, "A 'behind' pattern takes a fixed length pattern as argument.")
        if len >= 260 then error("Subpattern too long in 'behind' pattern constructor.") end
        return
            --[[DBG]] true and
            constructors.both("behind", pt, len)
    end
end


local function nameify(a, b)
    return tostring(a)..tostring(b)
end

-- pt*pt
local
function choice (a, b)
    local name = tostring(a)..tostring(b)
    local ch = Builder.ptcache.choice[name]
    if not ch then
        ch = factorize_choice(a, b) or constructors.binary("choice", a, b)
        Builder.ptcache.choice[name] = ch
    end
    return ch
end
function LL.__add (a, b)
    return 
        --[[DBG]] true and
        choice(LL_P(a), LL_P(b))
end


 -- pt+pt,

local
function sequence (a, b)
    local name = tostring(a)..tostring(b)
    local seq = Builder.ptcache.sequence[name]
    if not seq then
        seq = factorize_sequence(a, b) or constructors.binary("sequence", a, b)
        Builder.ptcache.sequence[name] = seq
    end
    return seq
end

Builder.sequence = sequence

function LL.__mul (a, b)
    -- [[DBG]] print("mul", a, b)
    return 
        --[[DBG]] true and
        sequence(LL_P(a), LL_P(b))
end


local
function LL_lookahead (pt)
    -- Simplifications
    if pt == truept
    or pt == falsept
    or pt.pkind == "unm"
    or pt.pkind == "lookahead"
    then
        return pt
    end
    -- -- The general case
    -- [[DB]] print("LL_lookahead", constructors.subpt("lookahead", pt))
    return
        --[[DBG]] true and
        constructors.subpt("lookahead", pt)
end
LL.__len = LL_lookahead
LL.L = LL_lookahead

local
function LL_unm(pt)
    -- Simplifications
    return
        --[[DBG]] true and
        factorize_unm(pt)
        or constructors.subpt("unm", pt)
end
LL.__unm = LL_unm

local
function LL_sub (a, b)
    a, b = LL_P(a), LL_P(b)
    return LL_unm(b) * a
end
LL.__sub = LL_sub

local
function LL_repeat (pt, n)
    local success
    success, n = pcall(tonumber, n)
    assert(success and type(n) == "number",
        "Invalid type encountered at right side of '^'.")
    return constructors.both(( n < 0 and "at most" or "at least" ), pt, n)
end
LL.__pow = LL_repeat

-------------------------------------------------------------------------------
--- Captures
--
for _, cap in pairs{"C", "Cs", "Ct"} do
    LL[cap] = function(pt)
        pt = LL_P(pt)
        return
            --[[DBG]] true and
            constructors.subpt(cap, pt)
    end
end


LL["Cb"] = function(aux)
    return
        --[[DBG]] true and
        constructors.aux("Cb", aux)
end


LL["Carg"] = function(aux)
    assert(type(aux)=="number", "Number expected as parameter to Carg capture.")
    assert( 0 < aux and aux <= 200, "Argument out of bounds in Carg capture.")
    return
        --[[DBG]] true and
        constructors.aux("Carg", aux)
end


local
function LL_Cp ()
    return Cppt
end
LL.Cp = LL_Cp

local
function LL_Cc (...)
    return
        --[[DBG]] true and
        constructors.none("Cc", t_pack(...))
end
LL.Cc = LL_Cc

for _, cap in pairs{"Cf", "Cmt"} do
    local msg = "Function expected in "..cap.." capture"
    LL[cap] = function(pt, aux)
    assert(type(aux) == "function", msg)
    pt = LL_P(pt)
    return
        --[[DBG]] true and
        constructors.both(cap, pt, aux)
    end
end


local
function LL_Cg (pt, tag)
    pt = LL_P(pt)
    if tag ~= nil then
        return
            --[[DBG]] true and
            constructors.both("Clb", pt, tag)
    else
        return
            --[[DBG]] true and
            constructors.subpt("Cg", pt)
    end
end
LL.Cg = LL_Cg


local valid_slash_type = setify{"string", "number", "table", "function"}
local
function LL_slash (pt, aux)
    if LL_ispattern(aux) then
        error"The right side of a '/' capture cannot be a pattern."
    elseif not valid_slash_type[type(aux)] then
        error("The right side of a '/' capture must be of type "
            .."string, number, table or function.")
    end
    local name
    if aux == 0 then
        name = "/zero"
    else
        name = "div_"..type(aux)
    end
    return
        --[[DBG]] true and
        constructors.both(name, pt, aux)
end
LL.__div = LL_slash

if Builder.proxymt then
    for k, v in pairs(LL) do
        if k:match"^__" then
            Builder.proxymt[k] = v
        end
    end
else
    LL.__index = LL
end

local factorizer
    = Builder.factorizer(Builder, LL)

-- These are declared as locals at the top of the wrapper.
factorize_choice,  factorize_lookahead,  factorize_sequence,  factorize_unm =
factorizer.choice, factorizer.lookahead, factorizer.sequence, factorizer.unm

end -- module wrapper --------------------------------------------------------


--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The LuLPeg library
--
--                                             \
--                                              '.,__
--                                           \  /
--                                            '/,__
--                                            /
--                                           /
--                                          /
--                       has been          / released
--                  ~ ~ ~ ~ ~ ~ ~ ~       ~ ~ ~ ~ ~ ~ ~ ~
--                under  the  Romantic   WTF Public License.
--               ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~`,´ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--               I hereby grant you an irrevocable license to
--                ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                  do what the gentle caress you want to
--                       ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                           with   this   lovely
--                              ~ ~ ~ ~ ~ ~ ~ ~
--                               / thing...
--                              /  ~ ~ ~ ~
--                             /    Love,
--                        #   /      '.'
--                        #######      ·
--                        #####
--                        ###
--                        #
--
--            -- Pierre-Yves
--
--
--            P.S.: Even though I poured my heart into this work,
--                  I _cannot_ provide any warranty regarding
--                  its fitness for _any_ purpose. You
--                  acknowledge that I will not be held liable
--                  for any damage its use could incur.
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["constructors"])sources["constructors"]=(\[===\[-- <pack constructors> --

-- Constructors

-- Patterns have the following, optional fields:
--
-- - type: the pattern type. ~1 to 1 correspondance with the pattern constructors
--     described in the LPeg documentation.
-- - pattern: the one subpattern held by the pattern, like most captures, or
--     `#pt`, `-pt` and `pt^n`.
-- - aux: any other type of data associated to the pattern. Like the string of a
--     `P"string"`, the range of an `R`, or the list of subpatterns of a `+` or
--     `*` pattern. In some cases, the data is pre-processed. in that case,
--     the `as_is` field holds the data as passed to the constructor.
-- - as_is: see aux.
-- - meta: A table holding meta information about patterns, like their
--     minimal and maximal width, the form they can take when compiled,
--     whether they are terminal or not (no V patterns), and so on.


local getmetatable, ipairs, newproxy, print, setmetatable
    = getmetatable, ipairs, newproxy, print, setmetatable

local t, u, compat
    = require"table", require"util", require"compat"

--[[DBG]] local debug = require"debug"

local t_concat = t.concat

local   copy,   getuniqueid,   id,   map
    ,   weakkey,   weakval
    = u.copy, u.getuniqueid, u.id, u.map
    , u.weakkey, u.weakval



local _ENV = u.noglobals() ----------------------------------------------------



--- The type of cache for each kind of pattern:
--
-- Patterns are memoized using different strategies, depending on what kind of
-- data is associated with them.


local patternwith = {
    constant = {
        "Cp", "true", "false"
    },
    -- only aux
    aux = {
        "string", "any",
        "char", "range", "set",
        "ref", "sequence", "choice",
        "Carg", "Cb"
    },
    -- only sub pattern
    subpt = {
        "unm", "lookahead", "C", "Cf",
        "Cg", "Cs", "Ct", "/zero"
    },
    -- both
    both = {
        "behind", "at least", "at most", "Clb", "Cmt",
        "div_string", "div_number", "div_table", "div_function"
    },
    none = "grammar", "Cc"
}



-------------------------------------------------------------------------------
return function(Builder, LL) --- module wrapper.
--


local S_tostring = Builder.set.tostring


-------------------------------------------------------------------------------
--- Base pattern constructor
--

local newpattern, pattmt
-- This deals with the Lua 5.1/5.2 compatibility, and restricted
-- environements without access to newproxy and/or debug.setmetatable.

if compat.proxies and not compat.lua52_len then 
    -- Lua 5.1 / LuaJIT without compat.
    local proxycache = weakkey{}
    local __index_LL = {__index = LL}

    local baseproxy = newproxy(true)
    pattmt = getmetatable(baseproxy)
    Builder.proxymt = pattmt

    function pattmt:__index(k)
        return proxycache[self][k]
    end

    function pattmt:__newindex(k, v)
        proxycache[self][k] = v
    end

    function LL.getdirect(p) return proxycache[p] end

    function newpattern(cons)
        local pt = newproxy(baseproxy)
        setmetatable(cons, __index_LL)
        proxycache[pt]=cons
        return pt
    end
else
    -- Fallback if neither __len(table) nor newproxy work
    -- for example in restricted sandboxes.
    if LL.warnings and not compat.lua52_len then
        print("Warning: The `__len` metatethod won't work with patterns, "
            .."use `LL.L(pattern)` for lookaheads.")
    end
    pattmt = LL
    function LL.getdirect (p) return p end

    function newpattern(pt)
        return setmetatable(pt,LL)
    end
end

Builder.newpattern = newpattern

local
function LL_ispattern(pt) return getmetatable(pt) == pattmt end
LL.ispattern = LL_ispattern

function LL.type(pt)
    if LL_ispattern(pt) then
        return "pattern"
    else
        return nil
    end
end


-------------------------------------------------------------------------------
--- The caches
--

local ptcache, meta
local
function resetcache()
    ptcache, meta = {}, weakkey{}
    Builder.ptcache = ptcache
    -- Patterns with aux only.
    for _, p in ipairs(patternwith.aux) do
        ptcache[p] = weakval{}
    end

    -- Patterns with only one sub-pattern.
    for _, p in ipairs(patternwith.subpt) do
        ptcache[p] = weakval{}
    end

    -- Patterns with both
    for _, p in ipairs(patternwith.both) do
        ptcache[p] = {}
    end

    return ptcache
end
LL.resetptcache = resetcache

resetcache()


-------------------------------------------------------------------------------
--- Individual pattern constructor
--

local constructors = {}
Builder.constructors = constructors

constructors["constant"] = {
    truept  = newpattern{ pkind = "true" },
    falsept = newpattern{ pkind = "false" },
    Cppt    = newpattern{ pkind = "Cp" }
}

-- data manglers that produce cache keys for each aux type.
-- `id()` for unspecified cases.
local getauxkey = {
    string = function(aux, as_is) return as_is end,
    table = copy,
    set = function(aux, as_is)
        return S_tostring(aux)
    end,
    range = function(aux, as_is)
        return t_concat(as_is, "|")
    end,
    sequence = function(aux, as_is)
        return t_concat(map(getuniqueid, aux),"|")
    end
}

getauxkey.choice = getauxkey.sequence

constructors["aux"] = function(typ, aux, as_is)
     -- dprint("CONS: ", typ, pt, aux, as_is)
    local cache = ptcache[typ]
    local key = (getauxkey[typ] or id)(aux, as_is)
    if not cache[key] then
        cache[key] = newpattern{
            pkind = typ,
            aux = aux,
            as_is = as_is
        }
    end
    return cache[key]
end

-- no cache for grammars
constructors["none"] = function(typ, aux)
    -- [[DBG]] print("CONS: ", typ, _, aux)
    -- [[DBG]] print(debug.traceback(1))
    return newpattern{
        pkind = typ,
        aux = aux
    }
end

constructors["subpt"] = function(typ, pt)
    -- [[DP]]print("CONS: ", typ, pt, aux)
    local cache = ptcache[typ]
    if not cache[pt] then
        cache[pt] = newpattern{
            pkind = typ,
            pattern = pt
        }
    end
    return cache[pt]
end

constructors["both"] = function(typ, pt, aux)
    -- [[DBG]] print("CONS: ", typ, pt, aux)
    local cache = ptcache[typ][aux]
    if not cache then
        ptcache[typ][aux] = weakval{}
        cache = ptcache[typ][aux]
    end
    if not cache[pt] then
        cache[pt] = newpattern{
            pkind = typ,
            pattern = pt,
            aux = aux,
            cache = cache -- needed to keep the cache as long as the pattern exists.
        }
    end
    return cache[pt]
end

constructors["binary"] = function(typ, a, b)
    -- [[DBG]] print("CONS: ", typ, pt, aux)
    return newpattern{
        a, b;
        pkind = typ,
    }
end

end -- module wrapper

--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The LuLPeg library
--
--                                             \
--                                              '.,__
--                                           \  /
--                                            '/,__
--                                            /
--                                           /
--                                          /
--                       has been          / released
--                  ~ ~ ~ ~ ~ ~ ~ ~       ~ ~ ~ ~ ~ ~ ~ ~
--                under  the  Romantic   WTF Public License.
--               ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~`,´ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--               I hereby grant you an irrevocable license to
--                ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                  do what the gentle caress you want to
--                       ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                           with   this   lovely
--                              ~ ~ ~ ~ ~ ~ ~ ~
--                               / thing...
--                              /  ~ ~ ~ ~
--                             /    Love,
--                        #   /      '.'
--                        #######      ·
--                        #####
--                        ###
--                        #
--
--            -- Pierre-Yves
--
--
--            P.S.: Even though I poured my heart into this work,
--                  I _cannot_ provide any warranty regarding
--                  its fitness for _any_ purpose. You
--                  acknowledge that I will not be held liable
--                  for any damage its use could incur.
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["compat"])sources["compat"]=(\[===\[-- <pack compat> --

-- compat.lua

local _, debug, jit

_, debug = pcall(require, "debug")

_, jit = pcall(require, "jit")
jit = _ and jit

local compat = {
    debug = debug,

    lua51 = (_VERSION == "Lua 5.1") and not jit,
    lua52 = _VERSION == "Lua 5.2",
    luajit = jit and true or false,
    jit = jit and jit.status(),

    -- LuaJIT can optionally support __len on tables.
    lua52_len = not #setmetatable({},{__len = function()end}),

    proxies = pcall(function()
        local prox = newproxy(true)
        local prox2 = newproxy(prox)
        assert (type(getmetatable(prox)) == "table" 
                and (getmetatable(prox)) == (getmetatable(prox2)))
    end),
    _goto = not not(loadstring or load)"::R::"
}


return compat

--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The LuLPeg library
--
--                                             \
--                                              '.,__
--                                           \  /
--                                            '/,__
--                                            /
--                                           /
--                                          /
--                       has been          / released
--                  ~ ~ ~ ~ ~ ~ ~ ~       ~ ~ ~ ~ ~ ~ ~ ~
--                under  the  Romantic   WTF Public License.
--               ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~`,´ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--               I hereby grant you an irrevocable license to
--                ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                  do what the gentle caress you want to
--                       ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                           with   this   lovely
--                              ~ ~ ~ ~ ~ ~ ~ ~
--                               / thing...
--                              /  ~ ~ ~ ~
--                             /    Love,
--                        #   /      '.'
--                        #######      ·
--                        #####
--                        ###
--                        #
--
--            -- Pierre-Yves
--
--
--            P.S.: Even though I poured my heart into this work,
--                  I _cannot_ provide any warranty regarding
--                  its fitness for _any_ purpose. You
--                  acknowledge that I will not be held liable
--                  for any damage its use could incur.
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["optimizer"])sources["optimizer"]=(\[===\[-- <pack optimizer> --
-- Nothing for now.
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
local add
if not pcall(function() add = require"aioruntime".add end) then
        local loadstring=loadstring; local preload = require"package".preload
        add = function(name, rawcode)
		if not preload[name] then
		        preload[name] = function(...) return loadstring(rawcode)(...) end
		else
			print("WARNING: overwrite "..name)
		end
        end
end
for name, rawcode in pairs(sources) do add(name, rawcode, priorities[name]) end
end;

-- LuLPeg.lua


-- a WIP LPeg implementation in pure Lua, by Pierre-Yves Gérardy
-- released under the Romantic WTF Public License (see the end of the file).

-- remove the global tables from the environment
-- they are restored at the end of the file.
-- standard libraries must be require()d.

--[[DBG]] local debug, print_ = require"debug", print
--[[DBG]] local print = function(...)
--[[DBG]]    print_(debug.traceback(2))
--[[DBG]]    print_("RE print", ...)
--[[DBG]]    return ...
--[[DBG]] end

--[[DBG]] local tmp_globals, globalenv = {}, _ENV or _G
--[[DBG]] if false and not release then
--[[DBG]] for lib, tbl in pairs(globalenv) do
--[[DBG]]     if type(tbl) == "table" then
--[[DBG]]         tmp_globals[lib], globalenv[lib] = globalenv[lib], nil
--[[DBG]]     end
--[[DBG]] end
--[[DBG]] end

--[[DBG]] local pairs = pairs

local getmetatable, setmetatable, pcall
    = getmetatable, setmetatable, pcall

local u = require"util"
local   copy,   map,   nop, t_unpack
    = u.copy, u.map, u.nop, u.unpack

-- The module decorators.
local API, charsets, compiler, constructors
    , datastructures, evaluator, factorizer
    , locale, printers, re
    = t_unpack(map(require,
    { "API", "charsets", "compiler", "constructors"
    , "datastructures", "evaluator", "factorizer"
    , "locale", "printers", "re" }))

local _, package = pcall(require, "package")



local _ENV = u.noglobals() ----------------------------------------------------



-- The LPeg version we emulate.
local VERSION = "0.12"

-- The LuLPeg version.
local LuVERSION = "0.1.0"

local function global(self, env) setmetatable(env,{__index = self}) end
local function register(self, env)
    pcall(function()
        package.loaded.lpeg = self
        package.loaded.re = self.re
    end)
--    if env then
--        env.lpeg, env.re = self, self.re
--    end
    return self
end

local
function LuLPeg(options)
    options = options and copy(options) or {}

    -- LL is the module
    -- Builder keeps the state during the module decoration.
    local Builder, LL
        = { options = options, factorizer = factorizer }
        , { new = LuLPeg
          , version = function () return VERSION end
          , luversion = function () return LuVERSION end
          , setmaxstack = nop --Just a stub, for compatibility.
          }

    LL.util = u
    LL.global = global
    LL.register = register
    ;-- Decorate the LuLPeg object.
    charsets(Builder, LL)
    datastructures(Builder, LL)
    printers(Builder, LL)
    constructors(Builder, LL)
    API(Builder, LL)
    evaluator(Builder, LL)
    ;(options.compiler or compiler)(Builder, LL)
    locale(Builder, LL)
    LL.re = re(Builder, LL)

    return LL
end -- LuLPeg

local LL = LuLPeg()

-- restore the global libraries
--[[DBG]] for lib, tbl in pairs(tmp_globals) do
--[[DBG]]     globalenv[lib] = tmp_globals[lib]
--[[DBG]] end


return LL

--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The LuLPeg library
--
--                                             \
--                                              '.,__
--                                           \  /
--                                            '/,__
--                                            /
--                                           /
--                                          /
--                       has been          / released
--                  ~ ~ ~ ~ ~ ~ ~ ~       ~ ~ ~ ~ ~ ~ ~ ~
--                under  the  Romantic   WTF Public License.
--               ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~`,´ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--               I hereby grant you an irrevocable license to
--                ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                  do what the gentle caress you want to
--                       ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                           with   this   lovely
--                              ~ ~ ~ ~ ~ ~ ~ ~
--                               / thing...
--                              /  ~ ~ ~ ~
--                             /    Love,
--                        #   /      '.'
--                        #######      ·
--                        #####
--                        ###
--                        #
--
--            -- Pierre-Yves
--
--
--            P.S.: Even though I poured my heart into this work,
--                  I _cannot_ provide any warranty regarding
--                  its fitness for _any_ purpose. You
--                  acknowledge that I will not be held liable
--                  for any damage its use could incur.
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["cwtest"])sources["cwtest"]=([===[-- <pack cwtest> --
local has_strict = pcall(require, "pl.strict")
local has_pretty, pretty = pcall(require, "pl.pretty")
if not has_strict then
  print("WARNING: pl.strict not found, strictness not enforced.")
end
if not has_pretty then
  pretty = nil
  print("WARNING: pl.pretty not found, using alternate formatter.")
end

--- logic borrowed to Penlight

local deepcompare
deepcompare = function(t1, t2)
  local ty1 = type(t1)
  local ty2 = type(t2)
  if ty1 ~= ty2 then return false end
  -- non-table types can be directly compared
  if ty1 ~= "table" then return t1 == t2 end
  -- as well as tables which have the metamethod __eq
  local mt = getmetatable(t1)
  if mt and mt.__eq then return t1 == t2 end
  for k1 in pairs(t1) do
    if t2[k1] == nil then return false end
  end
  for k2 in pairs(t2) do
    if t1[k2] == nil then return false end
  end
  for k1,v1 in pairs(t1) do
    local v2 = t2[k1]
    if not deepcompare(v1, v2) then return false end
  end
  return true
end

local compare_no_order = function(t1, t2, cmp)
  cmp = cmp or deepcompare
  -- non-table types are considered *never* equal here
  if (type(t1) ~= "table") or (type(t2) ~= "table") then return false end
  if #t1 ~= #t2 then return false end
  local visited = {}
  for i = 1,#t1 do
    local val = t1[i]
    local gotcha
    for j = 1,#t2 do if not visited[j] then
      if cmp(val, t2[j]) then
        gotcha = j
        break
      end
    end end
    if not gotcha then return false end
    visited[gotcha] = true
  end
  return true
end

--- basic pretty.write fallback

local less_pretty_write
less_pretty_write = function(t)
  local quote = function(s)
    if type(s) == "string" then
      return string.format("%q", tostring(s))
    else return tostring(s) end
  end
  if type(t) == "table" then
    local r = {"{"}
    for k,v in pairs(t) do
      if type(k) ~= "number" then k = quote(k) end
      r[#r+1] = "["
      r[#r+1] = k
      r[#r+1] = "]="
      r[#r+1] = less_pretty_write(v)
      r[#r+1] = ","
    end
    r[#r+1] = "}"
    return table.concat(r)
  else return quote(t) end
end

--- end of Penlight fallbacks

local pretty_write
if pretty then
  pretty_write = function(x) return pretty.write(x, "") end
else
  pretty_write = less_pretty_write
end

local printf = function(p, ...)
  io.stdout:write(string.format(p, ...)); io.stdout:flush()
end

local eprintf = function(p, ...)
  io.stderr:write(string.format(p, ...))
end

local log_success = function(self, tpl, ...)
  assert(type(tpl) == "string")
  local s = (select('#', ...) == 0) and tpl or string.format(tpl, ...)
  self.successes[#self.successes+1] = s
  if self.verbosity == 2 then
    self.printf("\n%s\n", s)
  else
    self.printf(".")
  end
  return true
end

local log_failure = function(self, tpl, ...)
  assert(type(tpl) == "string")
  local s = (select('#', ...) == 0) and tpl or string.format(tpl, ...)
  self.failures[#self.failures+1] = s
  if self.verbosity > 0 then
    self.eprintf("\n%s\n", s)
  else
    self.printf("x")
  end
  return true
end

local pass_tpl = function(self, tpl, ...)
  assert(type(tpl) == "string")
  local info = debug.getinfo(3)
  self:log_success(
    "[OK] %s line %d%s",
    info.short_src,
    info.currentline,
    (select('#', ...) == 0) and tpl or string.format(tpl, ...)
  )
  return true
end

local fail_tpl = function(self, tpl, ...)
  assert(type(tpl) == "string")
  local info = debug.getinfo(3)
  self:log_failure(
    "[KO] %s line %d%s",
    info.short_src,
    info.currentline,
    (select('#', ...) == 0) and tpl or string.format(tpl, ...)
  )
  return false
end

local pass_assertion = function(self)
  local info = debug.getinfo(3)
  self:log_success(
    "[OK] %s line %d (assertion)",
    info.short_src,
    info.currentline
  )
  return true
end

local fail_assertion = function(self)
  local info = debug.getinfo(3)
  self:log_failure(
    "[KO] %s line %d (assertion)",
    info.short_src,
    info.currentline
  )
  return false
end

local pass_eq = function(self, x, y)
  local info = debug.getinfo(3)
  self:log_success(
    "[OK] %s line %d\n  expected: %s\n       got: %s",
    info.short_src,
    info.currentline,
    pretty_write(y),
    pretty_write(x)
  )
  return true
end

local fail_eq = function(self, x, y)
  local info = debug.getinfo(3)
  self:log_failure(
    "[KO] %s line %d\n  expected: %s\n       got: %s",
    info.short_src,
    info.currentline,
    pretty_write(y),
    pretty_write(x)
  )
  return false
end

local start = function(self, s)
  assert((not (self.failures or self.successes)), "test already started")
  self.failures, self.successes = {}, {}
  if self.verbosity > 0 then
    self.printf("\n=== %s ===\n", s)
  else
    self.printf("%s ", s)
  end
end

local done = function(self)
  local f, s = self.failures, self.successes
  assert((f and s), "call start before done")
  local failed = (#f > 0)
  if failed then
    if self.verbosity > 0 then
      self.printf("\n=== FAILED ===\n")
    else
      self.printf(" FAILED\n")
      for i=1,#f do self.eprintf("\n%s\n", f[i]) end
      self.printf("\n")
    end
  else
    if self.verbosity > 0 then
      self.printf("\n=== OK ===\n")
    else
      self.printf(" OK\n")
    end
  end
  self.failures, self.successes = nil, nil
  if failed then self.tainted = true end
  return (not failed)
end

local eq = function(self, x, y)
  local ok = (x == y) or deepcompare(x, y)
  local r = (ok and pass_eq or fail_eq)(self, x, y)
  return r
end

local neq = function(self, x, y)
  local sx, sy = pretty_write(x), pretty_write(y)
  local r
  if deepcompare(x, y) then
    r = fail_tpl(self, " (%s == %s)", sx, sy)
  else
    r = pass_tpl(self, " (%s != %s)", sx, sy)
  end
  return r
end

local seq = function(self, x, y) -- list-sets
  local ok = compare_no_order(x, y)
  local r = (ok and pass_eq or fail_eq)(self, x, y)
  return r
end

local _assert_fun = function(x, ...)
  if (select('#', ...) == 0) then
    return (x and pass_assertion or fail_assertion)
  else
    return (x and pass_tpl or fail_tpl)
  end
end

local is_true = function(self, x, ...)
  local r = _assert_fun(x, ...)(self, ...)
  return r
end

local is_false = function(self, x, ...)
  local r = _assert_fun((not x), ...)(self, ...)
  return r
end

local err = function(self, f, e)
  local r = { pcall(f) }
  if e then
    if type(e) == "string" then
      if r[1] then
        table.remove(r, 1)
        r = fail_tpl(
          self,
          "\n  expected error: %s\n             got: %s",
          e, pretty_write(r, "")
        )
      elseif r[2] ~= e then
        r = fail_tpl(
          self,
          "\n  expected error: %s\n       got error: %s",
          e, r[2]
        )
      else
        r = pass_tpl(self, ": error [[%s]] caught", e)
      end
    elseif type(e) == "table" and type(e.matching) == "string" then
      local pattern = e.matching
      if r[1] then
        table.remove(r, 1)
        r = fail_tpl(
          self,
          "\n  expected error, got: %s",
          e, pretty_write(r, "")
        )
      elseif not r[2]:match(pattern) then
        r = fail_tpl(
          self,
          "\n  expected error matching: %q\n       got error: %s",
          pattern, r[2]
        )
      else
        r = pass_tpl(self, ": error [[%s]] caught", e)
      end
    end
  else
    if r[1] then
      table.remove(r, 1)
      r = fail_tpl(
        self,
        ": expected error, got %s",
        pretty_write(r, "")
      )
    else
      r = pass_tpl(self, ": error caught")
    end
  end
  return r
end

local exit = function(self)
  os.exit(self.tainted and 1 or 0)
end

local methods = {
  start = start,
  done = done,
  eq = eq,
  neq = neq,
  seq = seq,
  yes = is_true,
  no = is_false,
  err = err,
  exit = exit,
  -- below: only to build custom tests
  log_success = log_success,
  log_failure = log_failure,
  pass_eq = pass_eq,
  fail_eq = fail_eq,
  pass_assertion = pass_assertion,
  fail_assertion = fail_assertion,
  pass_tpl = pass_tpl,
  fail_tpl = fail_tpl,
}

local new = function(verbosity)
  if not verbosity then
    verbosity = 0
  elseif type(verbosity) ~= "number" then
    verbosity = 1
  end
  assert(
    (math.floor(verbosity) == verbosity) and
    (verbosity >= 0) and (verbosity < 3)
  )
  local r = {
    verbosity = verbosity,
    printf = printf,
    eprintf = eprintf,
    tainted = false,
  }
  return setmetatable(r, {__index = methods})
end

return {
  new = new,
  pretty_write = pretty_write,
  deepcompare = deepcompare,
  compare_no_order = compare_no_order,
}
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["pl.pretty"])sources["pl.pretty"]=([===[-- <pack pl.pretty> --
--- Pretty-printing Lua tables.
-- Also provides a sandboxed Lua table reader and
-- a function to present large numbers in human-friendly format.
--
-- Dependencies: `pl.utils`, `pl.lexer`
-- @module pl.pretty

local append = table.insert
local concat = table.concat
local utils = require 'pl.utils'
local lexer = require 'pl.lexer'
local assert_arg = utils.assert_arg

local pretty = {}

local function save_string_index ()
    local SMT = getmetatable ''
    if SMT then
        SMT.old__index = SMT.__index
        SMT.__index = nil
    end
    return SMT
end

local function restore_string_index (SMT)
    if SMT then
        SMT.__index = SMT.old__index
    end
end

--- read a string representation of a Lua table.
-- Uses load(), but tries to be cautious about loading arbitrary code!
-- It is expecting a string of the form '{...}', with perhaps some whitespace
-- before or after the curly braces. A comment may occur beforehand.
-- An empty environment is used, and
-- any occurance of the keyword 'function' will be considered a problem.
-- in the given environment - the return value may be `nil`.
-- @param s {string} string of the form '{...}', with perhaps some whitespace
-- before or after the curly braces.
-- @return a table
function pretty.read(s)
    assert_arg(1,s,'string')
    if s:find '^%s*%-%-' then -- may start with a comment..
        s = s:gsub('%-%-.-\n','')
    end
    if not s:find '^%s*%b{}%s*$' then return nil,"not a Lua table" end
    if s:find '[^\'"%w_]function[^\'"%w_]' then
        local tok = lexer.lua(s)
        for t,v in tok do
            if t == 'keyword' then
                return nil,"cannot have functions in table definition"
            end
        end
    end
    s = 'return '..s
    local chunk,err = utils.load(s,'tbl','t',{})
    if not chunk then return nil,err end
    local SMT = save_string_index()
    local ok,ret = pcall(chunk)
    restore_string_index(SMT)
    if ok then return ret
    else
        return nil,ret
    end
end

--- read a Lua chunk.
-- @param s Lua code
-- @param env optional environment
-- @param paranoid prevent any looping constructs and disable string methods
-- @return the environment
function pretty.load (s, env, paranoid)
    env = env or {}
    if paranoid then
        local tok = lexer.lua(s)
        for t,v in tok do
            if t == 'keyword'
                and (v == 'for' or v == 'repeat' or v == 'function' or v == 'goto')
            then
                return nil,"looping not allowed"
            end
        end
    end
    local chunk,err = utils.load(s,'tbl','t',env)
    if not chunk then return nil,err end
    local SMT = paranoid and save_string_index()
    local ok,err = pcall(chunk)
    restore_string_index(SMT)
    if not ok then return nil,err end
    return env
end

local function quote_if_necessary (v)
    if not v then return ''
    else
        if v:find ' ' then v = '"'..v..'"' end
    end
    return v
end

local keywords

local function is_identifier (s)
    return type(s) == 'string' and s:find('^[%a_][%w_]*$') and not keywords[s]
end

local function quote (s)
    if type(s) == 'table' then
        return pretty.write(s,'')
    else
        return ('%q'):format(tostring(s))
    end
end

local function index (numkey,key)
    if not numkey then key = quote(key) end
    return '['..key..']'
end


---	Create a string representation of a Lua table.
--  This function never fails, but may complain by returning an
--  extra value. Normally puts out one item per line, using
--  the provided indent; set the second parameter to '' if
--  you want output on one line.
--	@param tbl {table} Table to serialize to a string.
--	@param space {string} (optional) The indent to use.
--	Defaults to two spaces; make it the empty string for no indentation
--	@param not_clever {bool} (optional) Use for plain output, e.g {['key']=1}.
--	Defaults to false.
--  @return a string
--  @return a possible error message
function pretty.write (tbl,space,not_clever)
    if type(tbl) ~= 'table' then
        local res = tostring(tbl)
        if type(tbl) == 'string' then return quote(tbl) end
        return res, 'not a table'
    end
    if not keywords then
        keywords = lexer.get_keywords()
    end
    local set = ' = '
    if space == '' then set = '=' end
    space = space or '  '
    local lines = {}
    local line = ''
    local tables = {}


    local function put(s)
        if #s > 0 then
            line = line..s
        end
    end

    local function putln (s)
        if #line > 0 then
            line = line..s
            append(lines,line)
            line = ''
        else
            append(lines,s)
        end
    end

    local function eat_last_comma ()
        local n,lastch = #lines
        local lastch = lines[n]:sub(-1,-1)
        if lastch == ',' then
            lines[n] = lines[n]:sub(1,-2)
        end
    end


    local writeit
    writeit = function (t,oldindent,indent)
        local tp = type(t)
        if tp ~= 'string' and  tp ~= 'table' then
            putln(quote_if_necessary(tostring(t))..',')
        elseif tp == 'string' then
            if t:find('\n') then
                putln('[[\n'..t..']],')
            else
                putln(quote(t)..',')
            end
        elseif tp == 'table' then
            if tables[t] then
                putln('<cycle>,')
                return
            end
            tables[t] = true
            local newindent = indent..space
            putln('{')
            local used = {}
            if not not_clever then
                for i,val in ipairs(t) do
                    put(indent)
                    writeit(val,indent,newindent)
                    used[i] = true
                end
            end
            for key,val in pairs(t) do
                local numkey = type(key) == 'number'
                if not_clever then
                    key = tostring(key)
                    put(indent..index(numkey,key)..set)
                    writeit(val,indent,newindent)
                else
                    if not numkey or not used[key] then -- non-array indices
                        if numkey or not is_identifier(key) then
                            key = index(numkey,key)
                        end
                        put(indent..key..set)
                        writeit(val,indent,newindent)
                    end
                end
            end
            tables[t] = nil
            eat_last_comma()
            putln(oldindent..'},')
        else
            putln(tostring(t)..',')
        end
    end
    writeit(tbl,'',space)
    eat_last_comma()
    return concat(lines,#space > 0 and '\n' or '')
end

---	Dump a Lua table out to a file or stdout.
--	@param t {table} The table to write to a file or stdout.
--	@param ... {string} (optional) File name to write too. Defaults to writing
--	to stdout.
function pretty.dump (t,...)
    if select('#',...)==0 then
        print(pretty.write(t))
        return true
    else
        return utils.writefile(...,pretty.write(t))
    end
end

local memp,nump = {'B','KiB','MiB','GiB'},{'','K','M','B'}

local comma
function comma (val)
    local thou = math.floor(val/1000)
    if thou > 0 then return comma(thou)..','..(val % 1000)
    else return tostring(val) end
end

--- format large numbers nicely for human consumption.
-- @param num a number
-- @param kind one of 'M' (memory in KiB etc), 'N' (postfixes are 'K','M' and 'B')
-- and 'T' (use commas as thousands separator)
-- @param prec number of digits to use for 'M' and 'N' (default 1)
function pretty.number (num,kind,prec)
    local fmt = '%.'..(prec or 1)..'f%s'
    if kind == 'T' then
        return comma(num)
    else
        local postfixes, fact
        if kind == 'M' then
            fact = 1024
            postfixes = memp
        else
            fact = 1000
            postfixes = nump
        end
        local div = fact
        local k = 1
        while num >= div and k <= #postfixes do
            div = div * fact
            k = k + 1
        end
        div = div / fact
        if k > #postfixes then k = k - 1; div = div/fact end
        if k > 1 then
            return fmt:format(num/div,postfixes[k] or 'duh')
        else
            return num..postfixes[1]
        end
    end
end

return pretty
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["pl.utils"])sources["pl.utils"]=([===[-- <pack pl.utils> --
--- Generally useful routines.
-- See  @{01-introduction.md.Generally_useful_functions|the Guide}.
-- @module pl.utils
local format,gsub,byte = string.format,string.gsub,string.byte
local compat = require 'pl.compat'
local clock = os.clock
local stdout = io.stdout
local append = table.insert
local unpack = rawget(_G,'unpack') or rawget(table,'unpack')

local collisions = {}

local utils = {
    _VERSION = "1.2.1",
    lua51 = compat.lua51,
    setfenv = compat.setfenv,
    getfenv = compat.getfenv,
    load = compat.load,
    execute = compat.execute,
    dir_separator = _G.package.config:sub(1,1),
    unpack = unpack
}

--- end this program gracefully.
-- @param code The exit code or a message to be printed
-- @param ... extra arguments for message's format'
-- @see utils.fprintf
function utils.quit(code,...)
    if type(code) == 'string' then
        utils.fprintf(io.stderr,code,...)
        code = -1
    else
        utils.fprintf(io.stderr,...)
    end
    io.stderr:write('\n')
    os.exit(code)
end

--- print an arbitrary number of arguments using a format.
-- @param fmt The format (see string.format)
-- @param ... Extra arguments for format
function utils.printf(fmt,...)
    utils.assert_string(1,fmt)
    utils.fprintf(stdout,fmt,...)
end

--- write an arbitrary number of arguments to a file using a format.
-- @param f File handle to write to.
-- @param fmt The format (see string.format).
-- @param ... Extra arguments for format
function utils.fprintf(f,fmt,...)
    utils.assert_string(2,fmt)
    f:write(format(fmt,...))
end

local function import_symbol(T,k,v,libname)
    local key = rawget(T,k)
    -- warn about collisions!
    if key and k ~= '_M' and k ~= '_NAME' and k ~= '_PACKAGE' and k ~= '_VERSION' then
        utils.printf("warning: '%s.%s' overrides existing symbol\n",libname,k)
    end
    rawset(T,k,v)
end

local function lookup_lib(T,t)
    for k,v in pairs(T) do
        if v == t then return k end
    end
    return '?'
end

local already_imported = {}

--- take a table and 'inject' it into the local namespace.
-- @param t The Table
-- @param T An optional destination table (defaults to callers environment)
function utils.import(t,T)
    T = T or _G
    t = t or utils
    if type(t) == 'string' then
        t = require (t)
    end
    local libname = lookup_lib(T,t)
    if already_imported[t] then return end
    already_imported[t] = libname
    for k,v in pairs(t) do
        import_symbol(T,k,v,libname)
    end
end

utils.patterns = {
    FLOAT = '[%+%-%d]%d*%.?%d*[eE]?[%+%-]?%d*',
    INTEGER = '[+%-%d]%d*',
    IDEN = '[%a_][%w_]*',
    FILE = '[%a%.\\][:%][%w%._%-\\]*'
}

--- escape any 'magic' characters in a string
-- @param s The input string
function utils.escape(s)
    utils.assert_string(1,s)
    return (s:gsub('[%-%.%+%[%]%(%)%$%^%%%?%*]','%%%1'))
end

--- return either of two values, depending on a condition.
-- @param cond A condition
-- @param value1 Value returned if cond is true
-- @param value2 Value returned if cond is false (can be optional)
function utils.choose(cond,value1,value2)
    if cond then return value1
    else return value2
    end
end

local raise

--- return the contents of a file as a string
-- @param filename The file path
-- @param is_bin open in binary mode
-- @return file contents
function utils.readfile(filename,is_bin)
    local mode = is_bin and 'b' or ''
    utils.assert_string(1,filename)
    local f,err = io.open(filename,'r'..mode)
    if not f then return utils.raise (err) end
    local res,err = f:read('*a')
    f:close()
    if not res then return raise (err) end
    return res
end

--- write a string to a file
-- @param filename The file path
-- @param str The string
-- @return true or nil
-- @return error message
-- @raise error if filename or str aren't strings
function utils.writefile(filename,str)
    utils.assert_string(1,filename)
    utils.assert_string(2,str)
    local f,err = io.open(filename,'w')
    if not f then return raise(err) end
    f:write(str)
    f:close()
    return true
end

--- return the contents of a file as a list of lines
-- @param filename The file path
-- @return file contents as a table
-- @raise errror if filename is not a string
function utils.readlines(filename)
    utils.assert_string(1,filename)
    local f,err = io.open(filename,'r')
    if not f then return raise(err) end
    local res = {}
    for line in f:lines() do
        append(res,line)
    end
    f:close()
    return res
end

--- split a string into a list of strings separated by a delimiter.
-- @param s The input string
-- @param re A Lua string pattern; defaults to '%s+'
-- @param plain don't use Lua patterns
-- @param n optional maximum number of splits
-- @return a list-like table
-- @raise error if s is not a string
function utils.split(s,re,plain,n)
    utils.assert_string(1,s)
    local find,sub,append = string.find, string.sub, table.insert
    local i1,ls = 1,{}
    if not re then re = '%s+' end
    if re == '' then return {s} end
    while true do
        local i2,i3 = find(s,re,i1,plain)
        if not i2 then
            local last = sub(s,i1)
            if last ~= '' then append(ls,last) end
            if #ls == 1 and ls[1] == '' then
                return {}
            else
                return ls
            end
        end
        append(ls,sub(s,i1,i2-1))
        if n and #ls == n then
            ls[#ls] = sub(s,i1)
            return ls
        end
        i1 = i3+1
    end
end

--- split a string into a number of values.
-- @param s the string
-- @param re the delimiter, default space
-- @return n values
-- @usage first,next = splitv('jane:doe',':')
-- @see split
function utils.splitv (s,re)
    return unpack(utils.split(s,re))
end

--- convert an array of values to strings.
-- @param t a list-like table
-- @param temp buffer to use, otherwise allocate
-- @param tostr custom tostring function, called with (value,index).
-- Otherwise use `tostring`
-- @return the converted buffer
function utils.array_tostring (t,temp,tostr)
    temp, tostr = temp or {}, tostr or tostring
    for i = 1,#t do
        temp[i] = tostr(t[i],i)
    end
    return temp
end

--- execute a shell command and return the output.
-- This function redirects the output to tempfiles and returns the content of those files.
-- @param cmd a shell command
-- @param bin boolean, if true, read output as binary file
-- @return true if successful
-- @return actual return code
-- @return stdout output (string)
-- @return errout output (string)
function utils.executeex(cmd, bin)
    local mode
    local outfile = os.tmpname()
    local errfile = os.tmpname()

    if utils.dir_separator == '\\' then
        outfile = os.getenv('TEMP')..outfile
        errfile = os.getenv('TEMP')..errfile
    end
    cmd = cmd .. [[ >"]]..outfile..[[" 2>"]]..errfile..[["]]

    local success, retcode = utils.execute(cmd)
    local outcontent = utils.readfile(outfile, bin)
    local errcontent = utils.readfile(errfile, bin)
    os.remove(outfile)
    os.remove(errfile)
    return success, retcode, (outcontent or ""), (errcontent or "")
end

--- 'memoize' a function (cache returned value for next call).
-- This is useful if you have a function which is relatively expensive,
-- but you don't know in advance what values will be required, so
-- building a table upfront is wasteful/impossible.
-- @param func a function of at least one argument
-- @return a function with at least one argument, which is used as the key.
function utils.memoize(func)
    return setmetatable({}, {
        __index = function(self, k, ...)
            local v = func(k,...)
            self[k] = v
            return v
        end,
        __call = function(self, k) return self[k] end
    })
end


utils.stdmt = {
    List = {_name='List'}, Map = {_name='Map'},
    Set = {_name='Set'}, MultiMap = {_name='MultiMap'}
}

local _function_factories = {}

--- associate a function factory with a type.
-- A function factory takes an object of the given type and
-- returns a function for evaluating it
-- @tab mt metatable
-- @func fun a callable that returns a function
function utils.add_function_factory (mt,fun)
    _function_factories[mt] = fun
end

local function _string_lambda(f)
    local raise = utils.raise
    if f:find '^|' or f:find '_' then
        local args,body = f:match '|([^|]*)|(.+)'
        if f:find '_' then
            args = '_'
            body = f
        else
            if not args then return raise 'bad string lambda' end
        end
        local fstr = 'return function('..args..') return '..body..' end'
        local fn,err = utils.load(fstr)
        if not fn then return raise(err) end
        fn = fn()
        return fn
    else return raise 'not a string lambda'
    end
end

--- an anonymous function as a string. This string is either of the form
-- '|args| expression' or is a function of one argument, '_'
-- @param lf function as a string
-- @return a function
-- @usage string_lambda '|x|x+1' (2) == 3
-- @usage string_lambda '_+1 (2) == 3
-- @function utils.string_lambda
utils.string_lambda = utils.memoize(_string_lambda)

local ops

--- process a function argument.
-- This is used throughout Penlight and defines what is meant by a function:
-- Something that is callable, or an operator string as defined by <code>pl.operator</code>,
-- such as '>' or '#'. If a function factory has been registered for the type, it will
-- be called to get the function.
-- @param idx argument index
-- @param f a function, operator string, or callable object
-- @param msg optional error message
-- @return a callable
-- @raise if idx is not a number or if f is not callable
function utils.function_arg (idx,f,msg)
    utils.assert_arg(1,idx,'number')
    local tp = type(f)
    if tp == 'function' then return f end  -- no worries!
    -- ok, a string can correspond to an operator (like '==')
    if tp == 'string' then
        if not ops then ops = require 'pl.operator'.optable end
        local fn = ops[f]
        if fn then return fn end
        local fn, err = utils.string_lambda(f)
        if not fn then error(err..': '..f) end
        return fn
    elseif tp == 'table' or tp == 'userdata' then
        local mt = getmetatable(f)
        if not mt then error('not a callable object',2) end
        local ff = _function_factories[mt]
        if not ff then
            if not mt.__call then error('not a callable object',2) end
            return f
        else
            return ff(f) -- we have a function factory for this type!
        end
    end
    if not msg then msg = " must be callable" end
    if idx > 0 then
        error("argument "..idx..": "..msg,2)
    else
        error(msg,2)
    end
end

--- bind the first argument of the function to a value.
-- @param fn a function of at least two values (may be an operator string)
-- @param p a value
-- @return a function such that f(x) is fn(p,x)
-- @raise same as @{function_arg}
-- @see func.bind1
function utils.bind1 (fn,p)
    fn = utils.function_arg(1,fn)
    return function(...) return fn(p,...) end
end

--- bind the second argument of the function to a value.
-- @param fn a function of at least two values (may be an operator string)
-- @param p a value
-- @return a function such that f(x) is fn(x,p)
-- @raise same as @{function_arg}
function utils.bind2 (fn,p)
    fn = utils.function_arg(1,fn)
    return function(x,...) return fn(x,p,...) end
end


--- assert that the given argument is in fact of the correct type.
-- @param n argument index
-- @param val the value
-- @param tp the type
-- @param verify an optional verfication function
-- @param msg an optional custom message
-- @param lev optional stack position for trace, default 2
-- @raise if the argument n is not the correct type
-- @usage assert_arg(1,t,'table')
-- @usage assert_arg(n,val,'string',path.isdir,'not a directory')
function utils.assert_arg (n,val,tp,verify,msg,lev)
    if type(val) ~= tp then
        error(("argument %d expected a '%s', got a '%s'"):format(n,tp,type(val)),lev or 2)
    end
    if verify and not verify(val) then
        error(("argument %d: '%s' %s"):format(n,val,msg),lev or 2)
    end
end

--- assert the common case that the argument is a string.
-- @param n argument index
-- @param val a value that must be a string
-- @raise val must be a string
function utils.assert_string (n,val)
    utils.assert_arg(n,val,'string',nil,nil,3)
end

local err_mode = 'default'

--- control the error strategy used by Penlight.
-- Controls how <code>utils.raise</code> works; the default is for it
-- to return nil and the error string, but if the mode is 'error' then
-- it will throw an error. If mode is 'quit' it will immediately terminate
-- the program.
-- @param mode - either 'default', 'quit'  or 'error'
-- @see utils.raise
function utils.on_error (mode)
    if ({['default'] = 1, ['quit'] = 2, ['error'] = 3})[mode] then
      err_mode = mode
    else
      -- fail loudly
      if err_mode == 'default' then err_mode = 'error' end
      utils.raise("Bad argument expected string; 'default', 'quit', or 'error'. Got '"..tostring(mode).."'")
    end
end

--- used by Penlight functions to return errors.  Its global behaviour is controlled
-- by <code>utils.on_error</code>
-- @param err the error string.
-- @see utils.on_error
function utils.raise (err)
    if err_mode == 'default' then return nil,err
    elseif err_mode == 'quit' then utils.quit(err)
    else error(err,2)
    end
end

--- is the object of the specified type?.
-- If the type is a string, then use type, otherwise compare with metatable
-- @param obj An object to check
-- @param tp String of what type it should be
function utils.is_type (obj,tp)
    if type(tp) == 'string' then return type(obj) == tp end
    local mt = getmetatable(obj)
    return tp == mt
end

raise = utils.raise

--- load a code string or bytecode chunk.
-- @param code Lua code as a string or bytecode
-- @param name for source errors
-- @param mode kind of chunk, 't' for text, 'b' for bytecode, 'bt' for all (default)
-- @param env  the environment for the new chunk (default nil)
-- @return compiled chunk
-- @return error message (chunk is nil)
-- @function utils.load

---------------
-- Get environment of a function.
-- With Lua 5.2, may return nil for a function with no global references!
-- Based on code by [Sergey Rozhenko](http://lua-users.org/lists/lua-l/2010-06/msg00313.html)
-- @param f a function or a call stack reference
-- @function utils.setfenv

---------------
-- Set environment of a function
-- @param f a function or a call stack reference
-- @param env a table that becomes the new environment of `f`
-- @function utils.setfenv

--- execute a shell command.
-- This is a compatibility function that returns the same for Lua 5.1 and Lua 5.2
-- @param cmd a shell command
-- @return true if successful
-- @return actual return code
-- @function utils.execute

return utils


]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["pl.lexer"])sources["pl.lexer"]=([===[-- <pack pl.lexer> --
--- Lexical scanner for creating a sequence of tokens from text.
-- `lexer.scan(s)` returns an iterator over all tokens found in the
-- string `s`. This iterator returns two values, a token type string
-- (such as 'string' for quoted string, 'iden' for identifier) and the value of the
-- token.
--
-- Versions specialized for Lua and C are available; these also handle block comments
-- and classify keywords as 'keyword' tokens. For example:
--
--    > s = 'for i=1,n do'
--    > for t,v in lexer.lua(s)  do print(t,v) end
--    keyword for
--    iden    i
--    =       =
--    number  1
--    ,       ,
--    iden    n
--    keyword do
--
-- See the Guide for further @{06-data.md.Lexical_Scanning|discussion}
-- @module pl.lexer

local yield,wrap = coroutine.yield,coroutine.wrap
local strfind = string.find
local strsub = string.sub
local append = table.insert

local function assert_arg(idx,val,tp)
    if type(val) ~= tp then
        error("argument "..idx.." must be "..tp, 2)
    end
end

local lexer = {}

local NUMBER1 = '^[%+%-]?%d+%.?%d*[eE][%+%-]?%d+'
local NUMBER2 = '^[%+%-]?%d+%.?%d*'
local NUMBER3 = '^0x[%da-fA-F]+'
local NUMBER4 = '^%d+%.?%d*[eE][%+%-]?%d+'
local NUMBER5 = '^%d+%.?%d*'
local IDEN = '^[%a_][%w_]*'
local WSPACE = '^%s+'
local STRING0 = [[^(['\"]).-\\%1]]
local STRING1 = [[^(['\"]).-[^\]%1]]
local STRING3 = "^((['\"])%2)" -- empty string
local PREPRO = '^#.-[^\\]\n'

local plain_matches,lua_matches,cpp_matches,lua_keyword,cpp_keyword

local function tdump(tok)
    return yield(tok,tok)
end

local function ndump(tok,options)
    if options and options.number then
        tok = tonumber(tok)
    end
    return yield("number",tok)
end

-- regular strings, single or double quotes; usually we want them
-- without the quotes
local function sdump(tok,options)
    if options and options.string then
        tok = tok:sub(2,-2)
    end
    return yield("string",tok)
end

-- long Lua strings need extra work to get rid of the quotes
local function sdump_l(tok,options,findres)
    if options and options.string then
        local quotelen = 3
        if findres[3] then
            quotelen = quotelen + findres[3]:len()
        end
        tok = tok:sub(quotelen,-1 * quotelen)
    end
    return yield("string",tok)
end

local function chdump(tok,options)
    if options and options.string then
        tok = tok:sub(2,-2)
    end
    return yield("char",tok)
end

local function cdump(tok)
    return yield('comment',tok)
end

local function wsdump (tok)
    return yield("space",tok)
end

local function pdump (tok)
    return yield('prepro',tok)
end

local function plain_vdump(tok)
    return yield("iden",tok)
end

local function lua_vdump(tok)
    if lua_keyword[tok] then
        return yield("keyword",tok)
    else
        return yield("iden",tok)
    end
end

local function cpp_vdump(tok)
    if cpp_keyword[tok] then
        return yield("keyword",tok)
    else
        return yield("iden",tok)
    end
end

--- create a plain token iterator from a string or file-like object.
-- @string s the string
-- @tab matches an optional match table (set of pattern-action pairs)
-- @tab[opt] filter a table of token types to exclude, by default `{space=true}`
-- @tab[opt] options a table of options; by default, `{number=true,string=true}`,
-- which means convert numbers and strip string quotes.
function lexer.scan (s,matches,filter,options)
    --assert_arg(1,s,'string')
    local file = type(s) ~= 'string' and s
    filter = filter or {space=true}
    options = options or {number=true,string=true}
    if filter then
        if filter.space then filter[wsdump] = true end
        if filter.comments then
            filter[cdump] = true
        end
    end
    if not matches then
        if not plain_matches then
            plain_matches = {
                {WSPACE,wsdump},
                {NUMBER3,ndump},
                {IDEN,plain_vdump},
                {NUMBER1,ndump},
                {NUMBER2,ndump},
                {STRING3,sdump},
                {STRING0,sdump},
                {STRING1,sdump},
                {'^.',tdump}
            }
        end
        matches = plain_matches
    end
    local function lex ()
        if type(s)=='string' and s=='' then return end
        local findres,i1,i2,idx,res1,res2,tok,pat,fun,capt
        local line = 1
        if file then s = file:read()..'\n' end
        local sz = #s
        local idx = 1
        --print('sz',sz)
        while true do
            for _,m in ipairs(matches) do
                pat = m[1]
                fun = m[2]
                findres = { strfind(s,pat,idx) }
                i1 = findres[1]
                i2 = findres[2]
                if i1 then
                    tok = strsub(s,i1,i2)
                    idx = i2 + 1
                    if not (filter and filter[fun]) then
                        lexer.finished = idx > sz
                        res1,res2 = fun(tok,options,findres)
                    end
                    if res1 then
                        local tp = type(res1)
                        -- insert a token list
                        if tp=='table' then
                            yield('','')
                            for _,t in ipairs(res1) do
                                yield(t[1],t[2])
                            end
                        elseif tp == 'string' then -- or search up to some special pattern
                            i1,i2 = strfind(s,res1,idx)
                            if i1 then
                                tok = strsub(s,i1,i2)
                                idx = i2 + 1
                                yield('',tok)
                            else
                                yield('','')
                                idx = sz + 1
                            end
                            --if idx > sz then return end
                        else
                            yield(line,idx)
                        end
                    end
                    if idx > sz then
                        if file then
                            --repeat -- next non-empty line
                                line = line + 1
                                s = file:read()
                                if not s then return end
                            --until not s:match '^%s*$'
                            s = s .. '\n'
                            idx ,sz = 1,#s
                            break
                        else
                            return
                        end
                    else break end
                end
            end
        end
    end
    return wrap(lex)
end

local function isstring (s)
    return type(s) == 'string'
end

--- insert tokens into a stream.
-- @param tok a token stream
-- @param a1 a string is the type, a table is a token list and
-- a function is assumed to be a token-like iterator (returns type & value)
-- @string a2 a string is the value
function lexer.insert (tok,a1,a2)
    if not a1 then return end
    local ts
    if isstring(a1) and isstring(a2) then
        ts = {{a1,a2}}
    elseif type(a1) == 'function' then
        ts = {}
        for t,v in a1() do
            append(ts,{t,v})
        end
    else
        ts = a1
    end
    tok(ts)
end

--- get everything in a stream upto a newline.
-- @param tok a token stream
-- @return a string
function lexer.getline (tok)
    local t,v = tok('.-\n')
    return v
end

--- get current line number.
-- Only available if the input source is a file-like object.
-- @param tok a token stream
-- @return the line number and current column
function lexer.lineno (tok)
    return tok(0)
end

--- get the rest of the stream.
-- @param tok a token stream
-- @return a string
function lexer.getrest (tok)
    local t,v = tok('.+')
    return v
end

--- get the Lua keywords as a set-like table.
-- So `res["and"]` etc would be `true`.
-- @return a table
function lexer.get_keywords ()
    if not lua_keyword then
        lua_keyword = {
            ["and"] = true, ["break"] = true,  ["do"] = true,
            ["else"] = true, ["elseif"] = true, ["end"] = true,
            ["false"] = true, ["for"] = true, ["function"] = true,
            ["if"] = true, ["in"] = true,  ["local"] = true, ["nil"] = true,
            ["not"] = true, ["or"] = true, ["repeat"] = true,
            ["return"] = true, ["then"] = true, ["true"] = true,
            ["until"] = true,  ["while"] = true
        }
    end
    return lua_keyword
end

--- create a Lua token iterator from a string or file-like object.
-- Will return the token type and value.
-- @string s the string
-- @tab[opt] filter a table of token types to exclude, by default `{space=true,comments=true}`
-- @tab[opt] options a table of options; by default, `{number=true,string=true}`,
-- which means convert numbers and strip string quotes.
function lexer.lua(s,filter,options)
    filter = filter or {space=true,comments=true}
    lexer.get_keywords()
    if not lua_matches then
        lua_matches = {
            {WSPACE,wsdump},
            {NUMBER3,ndump},
            {IDEN,lua_vdump},
            {NUMBER4,ndump},
            {NUMBER5,ndump},
            {STRING3,sdump},
            {STRING0,sdump},
            {STRING1,sdump},
            {'^%-%-%[(=*)%[.-%]%1%]',cdump},
            {'^%-%-.-\n',cdump},
            {'^%[(=*)%[.-%]%1%]',sdump_l},
            {'^==',tdump},
            {'^~=',tdump},
            {'^<=',tdump},
            {'^>=',tdump},
            {'^%.%.%.',tdump},
            {'^%.%.',tdump},
            {'^.',tdump}
        }
    end
    return lexer.scan(s,lua_matches,filter,options)
end

--- create a C/C++ token iterator from a string or file-like object.
-- Will return the token type type and value.
-- @string s the string
-- @tab[opt] filter a table of token types to exclude, by default `{space=true,comments=true}`
-- @tab[opt] options a table of options; by default, `{number=true,string=true}`,
-- which means convert numbers and strip string quotes.
function lexer.cpp(s,filter,options)
    filter = filter or {comments=true}
    if not cpp_keyword then
        cpp_keyword = {
            ["class"] = true, ["break"] = true,  ["do"] = true, ["sizeof"] = true,
            ["else"] = true, ["continue"] = true, ["struct"] = true,
            ["false"] = true, ["for"] = true, ["public"] = true, ["void"] = true,
            ["private"] = true, ["protected"] = true, ["goto"] = true,
            ["if"] = true, ["static"] = true,  ["const"] = true, ["typedef"] = true,
            ["enum"] = true, ["char"] = true, ["int"] = true, ["bool"] = true,
            ["long"] = true, ["float"] = true, ["true"] = true, ["delete"] = true,
            ["double"] = true,  ["while"] = true, ["new"] = true,
            ["namespace"] = true, ["try"] = true, ["catch"] = true,
            ["switch"] = true, ["case"] = true, ["extern"] = true,
            ["return"] = true,["default"] = true,['unsigned']  = true,['signed'] = true,
            ["union"] =  true, ["volatile"] = true, ["register"] = true,["short"] = true,
        }
    end
    if not cpp_matches then
        cpp_matches = {
            {WSPACE,wsdump},
            {PREPRO,pdump},
            {NUMBER3,ndump},
            {IDEN,cpp_vdump},
            {NUMBER4,ndump},
            {NUMBER5,ndump},
            {STRING3,sdump},
            {STRING1,chdump},
            {'^//.-\n',cdump},
            {'^/%*.-%*/',cdump},
            {'^==',tdump},
            {'^!=',tdump},
            {'^<=',tdump},
            {'^>=',tdump},
            {'^->',tdump},
            {'^&&',tdump},
            {'^||',tdump},
            {'^%+%+',tdump},
            {'^%-%-',tdump},
            {'^%+=',tdump},
            {'^%-=',tdump},
            {'^%*=',tdump},
            {'^/=',tdump},
            {'^|=',tdump},
            {'^%^=',tdump},
            {'^::',tdump},
            {'^.',tdump}
        }
    end
    return lexer.scan(s,cpp_matches,filter,options)
end

--- get a list of parameters separated by a delimiter from a stream.
-- @param tok the token stream
-- @string[opt=')'] endtoken end of list. Can be '\n'
-- @string[opt=','] delim separator
-- @return a list of token lists.
function lexer.get_separated_list(tok,endtoken,delim)
    endtoken = endtoken or ')'
    delim = delim or ','
    local parm_values = {}
    local level = 1 -- used to count ( and )
    local tl = {}
    local function tappend (tl,t,val)
        val = val or t
        append(tl,{t,val})
    end
    local is_end
    if endtoken == '\n' then
        is_end = function(t,val)
            return t == 'space' and val:find '\n'
        end
    else
        is_end = function (t)
            return t == endtoken
        end
    end
    local token,value
    while true do
        token,value=tok()
        if not token then return nil,'EOS' end -- end of stream is an error!
        if is_end(token,value) and level == 1 then
            append(parm_values,tl)
            break
        elseif token == '(' then
            level = level + 1
            tappend(tl,'(')
        elseif token == ')' then
            level = level - 1
            if level == 0 then -- finished with parm list
                append(parm_values,tl)
                break
            else
                tappend(tl,')')
            end
        elseif token == delim and level == 1 then
            append(parm_values,tl) -- a new parm
            tl = {}
        else
            tappend(tl,token,value)
        end
    end
    return parm_values,{token,value}
end

--- get the next non-space token from the stream.
-- @param tok the token stream.
function lexer.skipws (tok)
    local t,v = tok()
    while t == 'space' do
        t,v = tok()
    end
    return t,v
end

local skipws = lexer.skipws

--- get the next token, which must be of the expected type.
-- Throws an error if this type does not match!
-- @param tok the token stream
-- @string expected_type the token type
-- @bool no_skip_ws whether we should skip whitespace
function lexer.expecting (tok,expected_type,no_skip_ws)
    assert_arg(1,tok,'function')
    assert_arg(2,expected_type,'string')
    local t,v
    if no_skip_ws then
        t,v = tok()
    else
        t,v = skipws(tok)
    end
    if t ~= expected_type then error ("expecting "..expected_type,2) end
    return v
end

return lexer
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["pl.compat"])sources["pl.compat"]=([===[-- <pack pl.compat> --
return {}
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lunajson"])sources["lunajson"]=([===[-- <pack lunajson> --
do local sources, priorities = {}, {};assert(not sources["lunajson._str_lib"])sources["lunajson._str_lib"]=(\[===\[-- <pack lunajson._str_lib> --
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
		['"']  = '"',
		['\\'] = '\\',
		['/']  = '/',
		['b']  = '\b',
		['f']  = '\f',
		['n']  = '\n',
		['r']  = '\r',
		['t']  = '\t'
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
			local ucode = hextbl[c1-47] * 0x1000 + hextbl[c2-47] * 0x100 + hextbl[c3-47] * 0x10 + hextbl[c4-47]
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
		return (u8 or escapetbl[ch]) .. rest
	end

	local function surrogateok()
		return surrogateprev == 0
	end

	return {
		subst = subst,
		surrogateok = surrogateok
	}
end
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lunajson._str_lib_lua53"])sources["lunajson._str_lib_lua53"]=(\[===\[-- <pack lunajson._str_lib_lua53> --
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
		['"']  = '"',
		['\\'] = '\\',
		['/']  = '/',
		['b']  = '\b',
		['f']  = '\f',
		['n']  = '\n',
		['r']  = '\r',
		['t']  = '\t'
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
			local ucode = hextbl[c1-47] * 0x1000 + hextbl[c2-47] * 0x100 + hextbl[c3-47] * 0x10 + hextbl[c4-47]
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
		return (u8 or escapetbl[ch]) .. rest
	end

	local function surrogateok()
		return surrogateprev == 0
	end

	return {
		subst = subst,
		surrogateok = surrogateok
	}
end
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lunajson.sax"])sources["lunajson.sax"]=(\[===\[-- <pack lunajson.sax> --
local error = error
local byte, char, find, gsub, match, sub = string.byte, string.char, string.find, string.gsub, string.match, string.sub
local tonumber = tonumber
local tostring, type, unpack = tostring, type, table.unpack or unpack

-- The function that interprets JSON strings is separated into another file so as to
-- use bitwise operation to speedup unicode codepoints processing on Lua 5.3.
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

	-- `f` is the temporary for dispatcher[c] and
	-- the dummy for the first return value of `find`
	local dispatcher, f

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

	--[[
		Helper
	--]]
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

	local function spaces() -- skip spaces and prepare the next char
		while true do
			f, pos = find(json, '^[ \n\r\t]*', pos)
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

	--[[
		Invalid
	--]]
	local function f_err()
		parseerror('invalid value')
	end

	--[[
		Constants
	--]]
	-- fallback slow constants parser
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

	-- null
	local function f_nul()
		if sub(json, pos, pos+2) == 'ull' then
			pos = pos+3
			return sax_null(nil)
		end
		return generic_constant('ull', 3, nil, sax_null)
	end

	-- false
	local function f_fls()
		if sub(json, pos, pos+3) == 'alse' then
			pos = pos+4
			return sax_boolean(false)
		end
		return generic_constant('alse', 4, false, sax_boolean)
	end

	-- true
	local function f_tru()
		if sub(json, pos, pos+2) == 'rue' then
			pos = pos+3
			return sax_boolean(true)
		end
		return generic_constant('rue', 3, true, sax_boolean)
	end

	--[[
		Numbers
		Conceptually, the longest prefix that matches to `(0|[1-9][0-9]*)(\.[0-9]*)?([eE][+-]?[0-9]*)?`
		(in regexp) is captured as a number and its conformance to the JSON spec is checked.
	--]]
	-- deal with non-standard locales
	local radixmark = match(tostring(0.5), '[^0-9]')
	local fixedtonumber = tonumber
	if radixmark ~= '.' then -- deals with non-standard locales
		if find(radixmark, '%W') then
			radixmark = '%' .. radixmark
		end
		fixedtonumber = function(s)
			return tonumber(gsub(s, '.', radixmark))
		end
	end

	-- fallback slow parser
	local function generic_number(mns)
		local buf = {}
		local i = 1

		local c = byte(json, pos)
		pos = pos+1

		local function nxt()
			buf[i] = c
			i = i+1
			c = tryc()
			pos = pos+1
		end

		if c == 0x30 then
			nxt()
		else
			repeat nxt() until not (c and 0x30 <= c and c < 0x3A)
		end
		if c == 0x2E then
			nxt()
			if not (c and 0x30 <= c and c < 0x3A) then
				parseerror('invalid number')
			end
			repeat nxt() until not (c and 0x30 <= c and c < 0x3A)
		end
		if c == 0x45 or c == 0x65 then
			nxt()
			if c == 0x2B or c == 0x2D then
				nxt()
			end
			if not (c and 0x30 <= c and c < 0x3A) then
				parseerror('invalid number')
			end
			repeat nxt() until not (c and 0x30 <= c and c < 0x3A)
		end
		pos = pos-1

		local num = char(unpack(buf))
		num = fixedtonumber(num)-0.0
		if mns then
			num = -num
		end
		return sax_number(num)
	end

	-- `0(\.[0-9]*)?([eE][+-]?[0-9]*)?`
	local function f_zro(mns)
		repeat
			local postmp = pos
			local num
			local c = byte(json, postmp)

			if c == 0x2E then -- is this `.`?
				num = match(json, '^.[0-9]*', pos) -- skipping 0
				local numlen = #num
				if numlen == 1 then
					break
				end
				postmp = pos + numlen
				c = byte(json, postmp)
			end

			if c == 0x45 or c == 0x65 then -- is this e or E?
				local numexp = match(json, '^[^eE]*[eE][-+]?[0-9]+', pos)
				if not numexp then
					break
				end
				if num then -- since `0e.*` is always 0.0, ignore those
					num = numexp
				end
				postmp = pos + #numexp
			end

			if postmp > jsonlen then
				break
			end
			pos = postmp
			if num then
				num = fixedtonumber(num)
			else
				num = 0.0
			end
			if mns then
				num = -num
			end
			return sax_number(num)
		until true

		pos = pos-1
		return generic_number(mns)
	end

	-- `[1-9][0-9]*(\.[0-9]*)?([eE][+-]?[0-9]*)?`
	local function f_num(mns)
		repeat
			pos = pos-1
			local num = match(json, '^.[0-9]*%.?[0-9]*', pos)
			if byte(num, -1) == 0x2E then
				break
			end
			local postmp = pos + #num
			local c = byte(json, postmp)

			if c == 0x45 or c == 0x65 then -- e or E?
				num = match(json, '^[^eE]*[eE][-+]?[0-9]+', pos)
				if not num then
					break
				end
				postmp = pos + #num
			end

			if postmp > jsonlen then
				break
			end
			pos = postmp
			num = fixedtonumber(num)-0.0
			if mns then
				num = -num
			end
			return sax_number(num)
		until true

		return generic_number(mns)
	end

	-- skip minus sign
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

	--[[
		Strings
	--]]
	local f_str_lib = genstrlib(parseerror)
	local f_str_surrogateok = f_str_lib.surrogateok -- whether codepoints for surrogate pair are correctly paired
	local f_str_subst = f_str_lib.subst -- the function passed to gsub that interprets escapes

	local function f_str(iskey)
		local pos2 = pos
		local newpos
		local str = ''
		local bs
		while true do
			while true do -- search '\' or '"'
				newpos = find(json, '[\\"]', pos2)
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
			if byte(json, newpos) == 0x22 then -- break if '"'
				break
			end
			pos2 = newpos+2 -- skip '\<char>'
			bs = true -- remember that backslash occurs
		end
		str = str .. sub(json, pos, newpos-1)
		pos = newpos+1

		if bs then -- check if backslash occurs
			str = gsub(str, '\\(.)([^\\]*)', f_str_subst) -- interpret escapes
			if not f_str_surrogateok() then
				parseerror("invalid surrogate pair")
			end
		end

		if iskey then
			return sax_key(str)
		end
		return sax_string(str)
	end

	--[[
		Arrays, Objects
	--]]
	-- arrays
	local function f_ary()
		sax_startarray()
		spaces()
		if byte(json, pos) ~= 0x5D then -- check the closing bracket ']', that consists an empty array
			local newpos
			while true do
				f = dispatcher[byte(json, pos)] -- parse value
				pos = pos+1
				f()
				f, newpos = find(json, '^[ \n\r\t]*,[ \n\r\t]*', pos) -- check comma
				if not newpos then
					f, newpos = find(json, '^[ \n\r\t]*%]', pos) -- check closing bracket
					if newpos then
						pos = newpos
						break
					end
					spaces() -- since the current chunk can be ended, skip spaces toward following chunks
					local c = byte(json, pos)
					if c == 0x2C then -- check comma again
						pos = pos+1
						spaces()
						newpos = pos-1
					elseif c == 0x5D then -- check closing bracket again
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

	-- objects
	local function f_obj()
		sax_startobject()
		spaces()
		if byte(json, pos) ~= 0x7D then -- check the closing bracket `}`, that consists an empty object
			local newpos
			while true do
				if byte(json, pos) ~= 0x22 then
					parseerror("not key")
				end
				pos = pos+1
				f_str(true)
				f, newpos = find(json, '^[ \n\r\t]*:[ \n\r\t]*', pos) -- check colon
				if not newpos then
					spaces() -- since the current chunk can be ended, skip spaces toward following chunks
					if byte(json, pos) ~= 0x3A then -- check colon again
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
				f = dispatcher[byte(json, pos)] -- parse value
				pos = pos+1
				f()
				f, newpos = find(json, '^[ \n\r\t]*,[ \n\r\t]*', pos) -- check comma
				if not newpos then
					f, newpos = find(json, '^[ \n\r\t]*}', pos) -- check closing bracket
					if newpos then
						pos = newpos
						break
					end
					spaces() -- since the current chunk can be ended, skip spaces toward following chunks
					local c = byte(json, pos)
					if c == 0x2C then -- check comma again
						pos = pos+1
						spaces()
						newpos = pos-1
					elseif c == 0x7D then -- check closing bracket again
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

	--[[
		The jump table to dispatch a parser for a value, indexed by the code of the value's first char.
		Key should be non-nil.
	--]]
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
	dispatcher[0] = f_err

	--[[
		public funcitons
	--]]
	local function run()
		spaces()
		f = dispatcher[byte(json, pos)]
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
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lunajson.decoder"])sources["lunajson.decoder"]=(\[===\[-- <pack lunajson.decoder> --
local error = error
local byte, char, find, gsub, match, sub = string.byte, string.char, string.find, string.gsub, string.match, string.sub
local tonumber = tonumber
local tostring, setmetatable = tostring, setmetatable

-- The function that interprets JSON strings is separated into another file so as to
-- use bitwise operation to speedup unicode codepoints processing on Lua 5.3.
local genstrlib
if _VERSION == "Lua 5.3" then
	genstrlib = require 'lunajson._str_lib_lua53'
else
	genstrlib = require 'lunajson._str_lib'
end

local _ENV = nil

local function newdecoder()
	local json, pos, nullv, arraylen

	-- `f` is the temporary for dispatcher[c] and
	-- the dummy for the first return value of `find`
	local dispatcher, f

	--[[
		Helper
	--]]
	local function decodeerror(errmsg)
		error("parse error at " .. pos .. ": " .. errmsg)
	end

	--[[
		Invalid
	--]]
	local function f_err()
		decodeerror('invalid value')
	end

	--[[
		Constants
	--]]
	-- null
	local function f_nul()
		if sub(json, pos, pos+2) == 'ull' then
			pos = pos+3
			return nullv
		end
		decodeerror('invalid value')
	end

	-- false
	local function f_fls()
		if sub(json, pos, pos+3) == 'alse' then
			pos = pos+4
			return false
		end
		decodeerror('invalid value')
	end

	-- true
	local function f_tru()
		if sub(json, pos, pos+2) == 'rue' then
			pos = pos+3
			return true
		end
		decodeerror('invalid value')
	end

	--[[
		Numbers
		Conceptually, the longest prefix that matches to `-?(0|[1-9][0-9]*)(\.[0-9]*)?([eE][+-]?[0-9]*)?`
		(in regexp) is captured as a number and its conformance to the JSON spec is checked.
	--]]
	-- deal with non-standard locales
	local radixmark = match(tostring(0.5), '[^0-9]')
	local fixedtonumber = tonumber
	if radixmark ~= '.' then
		if find(radixmark, '%W') then
			radixmark = '%' .. radixmark
		end
		fixedtonumber = function(s)
			return tonumber(gsub(s, '.', radixmark))
		end
	end

	-- `0(\.[0-9]*)?([eE][+-]?[0-9]*)?`
	local function f_zro(mns)
		repeat
			local postmp = pos
			local num
			local c = byte(json, postmp)
			if not c then
				break
			end

			if c == 0x2E then -- is this `.`?
				num = match(json, '^.[0-9]*', pos) -- skipping 0
				local numlen = #num
				if numlen == 1 then
					break
				end
				postmp = pos + numlen
				c = byte(json, postmp)
			end

			if c == 0x45 or c == 0x65 then -- is this e or E?
				local numexp = match(json, '^[^eE]*[eE][-+]?[0-9]+', pos)
				if not numexp then
					break
				end
				if num then -- since `0e.*` is always 0.0, ignore those
					num = numexp
				end
				postmp = pos + #numexp
			end

			pos = postmp
			if num then
				num = fixedtonumber(num)
			else
				num = 0.0
			end
			if mns then
				num = -num
			end
			return num
		until true

		decodeerror('invalid number')
	end

	-- `[1-9][0-9]*(\.[0-9]*)?([eE][+-]?[0-9]*)?`
	local function f_num(mns)
		repeat
			pos = pos-1
			local num = match(json, '^.[0-9]*%.?[0-9]*', pos)
			if byte(num, -1) == 0x2E then
				break
			end
			local postmp = pos + #num
			local c = byte(json, postmp)

			if c == 0x45 or c == 0x65 then -- e or E?
				num = match(json, '^[^eE]*[eE][-+]?[0-9]+', pos)
				if not num then
					break
				end
				postmp = pos + #num
			end

			pos = postmp
			num = fixedtonumber(num)-0.0
			if mns then
				num = -num
			end
			return num
		until true

		decodeerror('invalid number')
	end

	-- skip minus sign
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

	--[[
		Strings
	--]]
	local f_str_lib = genstrlib(decodeerror)
	local f_str_surrogateok = f_str_lib.surrogateok -- whether codepoints for surrogate pair are correctly paired
	local f_str_subst = f_str_lib.subst -- the function passed to gsub that interprets escapes

	-- caching interpreted keys for speed
	local f_str_keycache = setmetatable({}, {__mode="v"})

	local function f_str(iskey)
		local newpos = pos-2
		local pos2 = pos
		local c1, c2
		repeat
			newpos = find(json, '"', pos2, true) -- search '"'
			if not newpos then
				decodeerror("unterminated string")
			end
			pos2 = newpos+1
			while true do -- skip preceding '\\'s
				c1, c2 = byte(json, newpos-2, newpos-1)
				if c2 ~= 0x5C or c1 ~= 0x5C then
					break
				end
				newpos = newpos-2
			end
		until c2 ~= 0x5C -- check '"' is not preceded by '\'

		local str = sub(json, pos, pos2-2)
		pos = pos2

		if iskey then -- check key cache
			local str2 = f_str_keycache[str]
			if str2 then
				return str2
			end
		end
		local str2 = str
		if find(str2, '\\', 1, true) then -- check if backslash occurs
			str2 = gsub(str2, '\\(.)([^\\]*)', f_str_subst) -- interpret escapes
			if not f_str_surrogateok() then
				decodeerror("invalid surrogate pair")
			end
		end
		if iskey then -- commit key cache
			f_str_keycache[str] = str2
		end
		return str2
	end

	--[[
		Arrays, Objects
	--]]
	-- array
	local function f_ary()
		local ary = {}

		f, pos = find(json, '^[ \n\r\t]*', pos)
		pos = pos+1

		local i = 0
		if byte(json, pos) ~= 0x5D then -- check closing bracket ']', that consists an empty array
			local newpos = pos-1
			repeat
				i = i+1
				f = dispatcher[byte(json,newpos+1)] -- parse value
				pos = newpos+2
				ary[i] = f()
				f, newpos = find(json, '^[ \n\r\t]*,[ \n\r\t]*', pos) -- check comma
			until not newpos

			f, newpos = find(json, '^[ \n\r\t]*%]', pos) -- check closing bracket
			if not newpos then
				decodeerror("no closing bracket of an array")
			end
			pos = newpos
		end

		pos = pos+1
		if arraylen then -- commit the length of the array if `arraylen` is set
			ary[0] = i
		end
		return ary
	end

	-- objects
	local function f_obj()
		local obj = {}

		f, pos = find(json, '^[ \n\r\t]*', pos)
		pos = pos+1
		if byte(json, pos) ~= 0x7D then -- check the closing bracket '}', that consists an empty object
			local newpos = pos-1

			repeat
				pos = newpos+1
				if byte(json, pos) ~= 0x22 then -- check '"'
					decodeerror("not key")
				end
				pos = pos+1
				local key = f_str(true) -- parse key

				-- optimized for compact json
				-- c1, c2 == ':', <the first char of the value> or
				-- c1, c2, c3 == ':', ' ', <the first char of the value>
				f = f_err
				do
					local c1, c2, c3  = byte(json, pos, pos+3)
					if c1 == 0x3A then
						newpos = pos
						if c2 == 0x20 then
							newpos = newpos+1
							c2 = c3
						end
						f = dispatcher[c2]
					end
				end
				if f == f_err then -- read a colon and arbitrary number of spaces
					f, newpos = find(json, '^[ \n\r\t]*:[ \n\r\t]*', pos)
					if not newpos then
						decodeerror("no colon after a key")
					end
				end
				f = dispatcher[byte(json, newpos+1)] -- parse value
				pos = newpos+2
				obj[key] = f()
				f, newpos = find(json, '^[ \n\r\t]*,[ \n\r\t]*', pos)
			until not newpos

			f, newpos = find(json, '^[ \n\r\t]*}', pos)
			if not newpos then
				decodeerror("no closing bracket of an object")
			end
			pos = newpos
		end

		pos = pos+1
		return obj
	end

	--[[
		The jump table to dispatch a parser for a value, indexed by the code of the value's first char.
		Nil key means the end of json.
	--]]
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
	dispatcher[0] = f_err
	dispatcher.__index = function()
		decodeerror("unexpected termination")
	end
	setmetatable(dispatcher, dispatcher)

	--[[
		run decoder
	--]]
	local function decode(json_, pos_, nullv_, arraylen_)
		json, pos, nullv, arraylen = json_, pos_, nullv_, arraylen_

		pos = pos or 1
		f, pos = find(json, '^[ \n\r\t]*', pos)
		pos = pos+1

		f = dispatcher[byte(json, pos)]
		pos = pos+1
		local v = f()

		if pos_ then
			return v, pos
		else
			f, pos = find(json, '^[ \n\r\t]*', pos)
			if pos ~= #json then
				error('json ended')
			end
			return v
		end
	end

	return decode
end

return newdecoder
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lunajson.encoder"])sources["lunajson.encoder"]=(\[===\[-- <pack lunajson.encoder> --
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
	f_string_pat = '[^ -!#-[%]^-\255]'
else
	f_string_pat = '[\0-\31"\\]'
end

local _ENV = nil

local function newencoder()
	local v, nullv
	local i, builder, visited

	local function f_tostring(v)
		builder[i] = tostring(v)
		i = i+1
	end

	local radixmark = match(tostring(0.5), '[^0-9]')
	local delimmark = match(tostring(12345.12345), '[^0-9' .. radixmark .. ']')
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
			builder[i] = s
			i = i+1
			return
		end
		error('invalid number')
	end

	local doencode

	local f_string_subst = {
		['"'] = '\\"',
		['\\'] = '\\\\',
		['\b'] = '\\b',
		['\f'] = '\\f',
		['\n'] = '\\n',
		['\r'] = '\\r',
		['\t'] = '\\t',
		__index = function(_, c)
			return format('\\u00%02X', byte(c))
		end
	}
	setmetatable(f_string_subst, f_string_subst)

	local function f_string(s)
		builder[i] = '"'
		if find(s, f_string_pat) then
			s = gsub(s, f_string_pat, f_string_subst)
		end
		builder[i+1] = s
		builder[i+2] = '"'
		i = i+3
	end

	local function f_table(o)
		if visited[o] then
			error("loop detected")
		end
		visited[o] = true

		local tmp = o[0]
		if type(tmp) == 'number' then -- arraylen available
			builder[i] = '['
			i = i+1
			for j = 1, tmp do
				doencode(o[j])
				builder[i] = ','
				i = i+1
			end
			if tmp > 0 then
				i = i-1
			end
			builder[i] = ']'

		else
			tmp = o[1]
			if tmp ~= nil then -- detected as array
				builder[i] = '['
				i = i+1
				local j = 2
				repeat
					doencode(tmp)
					tmp = o[j]
					if tmp == nil then
						break
					end
					j = j+1
					builder[i] = ','
					i = i+1
				until false
				builder[i] = ']'

			else -- detected as object
				builder[i] = '{'
				i = i+1
				local tmp = i
				for k, v in pairs(o) do
					if type(k) ~= 'string' then
						error("non-string key")
					end
					f_string(k)
					builder[i] = ':'
					i = i+1
					doencode(v)
					builder[i] = ','
					i = i+1
				end
				if i > tmp then
					i = i-1
				end
				builder[i] = '}'
			end
		end

		i = i+1
		visited[o] = nil
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
			builder[i] = 'null'
			i = i+1
			return
		end
		return dispatcher[type(v)](v)
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
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
local add
if not pcall(function() add = require"aioruntime".add end) then
        local loadstring=_G.loadstring or _G.load; local preload = require"package".preload
        add = function(name, rawcode)
		if not preload[name] then
		        preload[name] = function(...) return assert(loadstring(rawcode), "loadstring: "..name.." failed")(...) end
		else
			print("WARNING: overwrite "..name)
		end
        end
end
for name, rawcode in pairs(sources) do add(name, rawcode, priorities[name]) end
end;
local newdecoder = require 'lunajson.decoder'
local newencoder = require 'lunajson.encoder'
local sax = require 'lunajson.sax'
-- If you need multiple contexts of decoder and/or encoder,
-- you can require lunajson.decoder and/or lunajson.encoder directly.
return {
	decode = newdecoder(),
	encode = newencoder(),
	newparser = sax.newparser,
	newfileparser = sax.newfileparser,
}
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["utf8"])sources["utf8"]=([===[-- <pack utf8> --
local m = {} -- the module
local ustring = {} -- table to index equivalent string.* functions

-- TsT <tst2005 gmail com> 20121108 (v0.2.1)
-- License: same to the Lua one
-- TODO: copy the LICENSE file

-------------------------------------------------------------------------------
-- begin of the idea : http://lua-users.org/wiki/LuaUnicode
--
-- for uchar in sgmatch(unicode_string, "([%z\1-\127\194-\244][\128-\191]*)") do
--
--local function utf8_strlen(unicode_string)
--	local _, count = string.gsub(unicode_string, "[^\128-\193]", "")
--	return count
--end

-- http://www.unicode.org/reports/tr29/#Grapheme_Cluster_Boundaries




-- Provides UTF-8 aware string functions implemented in pure lua (try to follow the lua 5.3 API):
-- * string.utf8len(s)
-- * string.utf8sub(s, i, j)
-- * string.utf8reverse(s)
-- * string.utf8char(unicode)
-- * string.utf8unicode(s, i, j)
-- * string.utf8gensub(s, sub_len)

local function lua53_utf8_char(...)
	for i,v in ipairs({...}) do
		if type(v) ~= "number" then
			error("bad argument #"..i.." to 'char' (number expected, got "..type(v)..")", 2)
		end
	end
	return string.char(...)
end

--local lua53_utf8_charpattern = "[%z\1-\x7F\xC2-\xF4][\x80-\xBF]*"
local lua53_utf8_charpattern = "[%z\1-\127\194-\244][\128-\191]*"

--local function lua53_utf8_next(o, i)
--	i = i or 0
--	i = i + 1
--	assert(type(o) == "string", "argument#1 must be a string")
--	local v = ????
--	if v then
--		return i, v
--	end
--end
local function ustring_utf8_next(o, i)
	assert(type(o) == "table", "argument#1 must be an ustring")
	i = i or 0
	i = i + 1
	local v = o[i]
	if v then
		return i, v
	end
end

		return function(k)
			local v
			k, v = next(s, k)
			if k then return k, strupper(v) end
		end
end

local function lua53_utf8_codes(o)
	if type(o) == "table" then
		-- should be a ustring
		return ustring_utf8_next, o
	elseif type(o) == "string" then
		return string.gmatch(o, "("..lua53_utf8_charpattern..")")
	else
		error("lua53_utf8_codes must be a string (or ustring)", 2)
	end
end

--for p, c in utf8.codes(s) do body end
--for c in string.gmatch(s, "("..lua53_utf8_charpattern..")") do


local function lua53_utf8_codepoint(s [, i [, j]])
end


local function lua53_utf8_len(s [, i [, j]])
end

local function lua53_utf8_offset(s, n [, i])
end









-- ############################# --



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
		r[#r+1] = t[k]
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
		uobj[k] = v
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
	for uchar in sgmatch(unicode_string, "([%z\1-\127\194-\244][\128-\191]*)") do
		uobj[cnt] = uchar
		cnt = cnt + 1
	end
	return uobj
end

local function private_contains_unicode(str)
	return not not str:find("[\128-\193]+")
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
		t[#t+1] = uobj[i]
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
for k,v in pairs(ustring) do m[k] = v end

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
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["cliargs"])sources["cliargs"]=([===[-- <pack cliargs> --
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
  if string.len(words[1]) > size then
    -- word longer than line
    if overflow then
      line = words[1]
      table.remove(words, 1)
    else
      line = words[1]:sub(1, size)
      words[1] = words[1]:sub(size + 1, -1)
    end
  else
    while words[1] and (#line + string.len(words[1]) + 1 <= size) or (line == "" and #words[1] == size) do
      if line == "" then
        line = words[1]
      else
        line = line .. " " .. words[1]
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

  while words[1] do
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
  _, _, dummy = key:find("^%-([%a%d]+)[%s]%-%-")
  if dummy then key = key:gsub("^%-[%a%d][%s]%-%-", "-"..dummy..", --", 1) end
  -- for a short key + value, replace space by "="
  _, _, dummy = key:find("^%-([%a%d]+)[%s]")
  if dummy then key = key:gsub("^%-([%a%d]+)[ ]", "-"..dummy.."=", 1) end
  -- if there is no "=", then append one
  if not key:find("=") then key = key .. "=" end
  -- get value
  _, _, v = key:find(".-%=(.+)")
  -- get key(s), remove spaces
  key = split(key, "=")[1]:gsub(" ", "")
  -- get short key & extended key
  _, _, k = key:find("^%-([^-][^%s,]*)")
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
--- *Note:* the value will be stored in `args[@key]`.
--- *Aliases: `add_argument`*
---
--- ### Parameters
--- 1. **key**: the argument's "name" that will be displayed to the user
--- 2. **desc**: a description of the argument
--- 3. **callback**: *optional*; specify a function to call when this argument is parsed (the default is nil)
---
--- ### Usage example
--- The following will parse the argument (if specified) and set its value in `args["root"]`:
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
--- *Note:* the value will be stored in `args[@key]`. The value will be a 'string' if 'maxcount == 1',
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
--- The following will parse the argument (if specified) and set its value in `args["root"]`:
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
  local has_no_flag = flag and (ek and ek:find('^%[no%-]') ~= nil)
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
--- The following option will be stored in `args["i"]` and `args["input"]` with a default value of `my_file.txt`:
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
  for k,v in pairs(arguments) do args[k] = v end  -- copy args local

  -- starts with --help? display the help listing and abort!
  if args[1] and (args[1] == "--help" or args[1] == "-h") then
    return nil, self:print_help(noprint)
  end

  -- starts with --__DUMP__; set dump to true to dump the parsed arguments
  if dump == nil then
    if args[1] and args[1] == "--__DUMP__" then
      dump = true
      table.remove(args, 1)  -- delete it to prevent further parsing
    end
  end

  while args[1] do
    local entry = nil
    local opt = args[1]
    local _, optpref, optkey, optkey2, optval
    _, _, optpref, optkey = opt:find("^(%-[%-]?)(.+)")   -- split PREFIX & NAME+VALUE
    if optkey then
      _, _, optkey2, optval = optkey:find("(.-)[=](.+)")       -- split value and key
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
        optval = args[1]
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
            optval = args[1]
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
    entry.value = args[1]
    if entry.callback then
      local status, err = entry.callback(entry.key, entry.value)
      if status == nil and err then
        return cli_error(err, noprint)
      end
    end
    table.remove(args, 1)
  end
  -- deal with the last optional argument
  while args[1] do
    if self.optargument.maxcount > 1 then
      self.optargument.value = self.optargument.value or {}
      table.insert(self.optargument.value, args[1])
    else
      self.optargument.value = args[1]
    end
    if self.optargument.callback then
      local status, err = self.optargument.callback(self.optargument.key, args[1])
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
    results[self.optargument.key] = self.optargument.value
  end
  for _, entry in pairs(self.required) do
    results[entry.key] = entry.value
  end
  for _, entry in pairs(self.optional) do
    if entry.key then results[entry.key] = entry.value end
    if entry.expanded_key then results[entry.expanded_key] = entry.value end
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
          if self.optargument.value[i] then
            print("  " .. tostring(i) .. string.rep(" ", self.maxlabel + 2 - #tostring(i)) .. " => '" .. tostring(self.optargument.value[i]) .. "'")
          end
        end
      end
    end

    if #self.optional > 0 then print("\nOptional parameters:") end
    local doubles = {}
    for _, v in pairs(self.optional) do
      if not doubles[v] then
        local m = v.value
        if type(m) == "string" then
          m = "'"..m.."'"
        else
          m = tostring(m) .." (" .. type(m) .. ")"
        end
        print("  " .. v.label .. string.rep(" ", self.maxlabel + 2 - #v.label) .. " => " .. m)
        doubles[v] = v
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
        package.loaded[k] = nil
        break
      end
    end
    -- clear table in case user holds on to module table
    for k, _ in pairs(cli) do
      cli[k] = nil
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
    msg = msg .. " [OPTIONS]"
  end
  if #self.required > 0 or self.optargument.maxcount > 0 then
    msg = msg .. " [--]"
  end
  if #self.required > 0 then
    for _,entry in ipairs(self.required) do
      msg = msg .. " " .. entry.key
    end
  end
  if self.optargument.maxcount == 1 then
    msg = msg .. " [" .. self.optargument.key .. "]"
  elseif self.optargument.maxcount == 2 then
    msg = msg .. " [" .. self.optargument.key .. "-1 [" .. self.optargument.key .. "-2]]"
  elseif self.optargument.maxcount > 2 then
    msg = msg .. " [" .. self.optargument.key .. "-1 [" .. self.optargument.key .. "-2 [...]]]"
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
  local col1 = self.colsz[1]
  local col2 = self.colsz[2]
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

  if self.required[1] then
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
        local readable_default = type(entry.default) == "table" and "[]" or tostring(entry.default)
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
  self.colsz = { key_cols or self.colsz[1], desc_cols or self.colsz[2] }
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
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["alt_getopt"])sources["alt_getopt"]=([===[-- <pack alt_getopt> --
-- Copyright (c) 2009 Aleksey Cheusov <vle@gmx.net>
--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
-- NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
-- LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
-- OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
-- WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

local type, pairs, ipairs, io, os = type, pairs, ipairs, io, os

local alt_getopt = {}

local function convert_short2long (opts)
   local ret = {}

   for short_opt, accept_arg in opts:gmatch("(%w)(:?)") do
      ret[short_opt]=#accept_arg
   end

   return ret
end

local function exit_with_error (msg, exit_status)
   io.stderr:write (msg)
   os.exit (exit_status)
end

local function err_unknown_opt (opt)
   exit_with_error ("Unknown option `-" ..
                   (#opt > 1 and "-" or "") .. opt .. "'\n", 1)
end

local function canonize (options, opt)
   if not options [opt] then
      err_unknown_opt (opt)
   end

   while type (options [opt]) == "string" do
      opt = options [opt]

      if not options [opt] then
         err_unknown_opt (opt)
      end
   end

   return opt
end

local function get_ordered_opts (arg, sh_opts, long_opts)
   local i      = 1
   local count  = 1
   local opts   = {}
   local optarg = {}

   local options = convert_short2long (sh_opts)
   for k,v in pairs (long_opts) do
      options [k] = v
   end

   while i <= #arg do
      local a = arg [i]

      if a == "--" then
         i = i + 1
         break

      elseif a == "-" then
         break

      elseif a:sub (1, 2) == "--" then
         local pos = a:find ("=", 1, true)

      if pos then
         local opt = a:sub (3, pos-1)

         opt = canonize (options, opt)

         if options [opt] == 0 then
            exit_with_error ("Bad usage of option `" .. a .. "'\n", 1)
         end

         optarg [count] = a:sub (pos+1)
         opts [count] = opt
      else
         local opt = a:sub (3)

         opt = canonize (options, opt)

         if options [opt] == 0 then
            opts [count] = opt
         else
            if i == #arg then
               exit_with_error ("Missed value for option `" .. a .. "'\n", 1)
            end

            optarg [count] = arg [i+1]
            opts [count] = opt
            i = i + 1
         end
      end
      count = count + 1

      elseif a:sub (1, 1) == "-" then

         for j=2,a:len () do
            local opt = canonize (options, a:sub (j, j))

            if options [opt] == 0 then
               opts [count] = opt
               count = count + 1
            elseif a:len () == j then
               if i == #arg then
                  exit_with_error ("Missed value for option `-" .. opt .. "'\n", 1)
               end

               optarg [count] = arg [i+1]
               opts [count] = opt
               i = i + 1
               count = count + 1
               break
            else
               optarg [count] = a:sub (j+1)
               opts [count] = opt
               count = count + 1
               break
            end
         end
      else
         break
      end

      i = i + 1
   end

   return opts,i,optarg
end

local function get_opts (arg, sh_opts, long_opts)
   local ret = {}

   local opts,optind,optarg = get_ordered_opts (arg, sh_opts, long_opts)
   for i,v in ipairs (opts) do
      if optarg [i] then
         ret [v] = optarg [i]
      else
         ret [v] = 1
      end
   end

   return ret,optind
end

alt_getopt.get_ordered_opts = get_ordered_opts
alt_getopt.get_opts = get_opts

return alt_getopt
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["ser"])sources["ser"]=([===[-- <pack ser> --
local pairs, ipairs, tostring, type, concat, dump, floor, format = pairs, ipairs, tostring, type, table.concat, string.dump, math.floor, string.format

local function getchr(c)
	return "\\" .. c:byte()
end

local function make_safe(text)
	return ("%q"):format(text):gsub('\n', 'n'):gsub("[\128-\255]", getchr)
end

local oddvals = {[tostring(1/0)] = '1/0', [tostring(-1/0)] = '-1/0', [tostring(0/0)] = '0/0'}
local function write(t, memo, rev_memo)
	local ty = type(t)
	if ty == 'number' then
		t = format("%.17g", t)
		return oddvals[t] or t
	elseif ty == 'boolean' or ty == 'nil' then
		return tostring(t)
	elseif ty == 'string' then
		return make_safe(t)
	elseif ty == 'table' or ty == 'function' then
		if not memo[t] then
			local index = #rev_memo + 1
			memo[t] = index
			rev_memo[index] = t
		end
		return '_[' .. memo[t] .. ']'
	else
		error("Trying to serialize unsupported type " .. ty)
	end
end

local kw = {['and'] = true, ['break'] = true, ['do'] = true, ['else'] = true,
	['elseif'] = true, ['end'] = true, ['false'] = true, ['for'] = true,
	['function'] = true, ['goto'] = true, ['if'] = true, ['in'] = true,
	['local'] = true, ['nil'] = true, ['not'] = true, ['or'] = true,
	['repeat'] = true, ['return'] = true, ['then'] = true, ['true'] = true,
	['until'] = true, ['while'] = true}
local function write_key_value_pair(k, v, memo, rev_memo, name)
	if type(k) == 'string' and k:match '^[_%a][_%w]*$' and not kw[k] then
		return (name and name .. '.' or '') .. k ..'=' .. write(v, memo, rev_memo)
	else
		return (name or '') .. '[' .. write(k, memo, rev_memo) .. ']=' .. write(v, memo, rev_memo)
	end
end

-- fun fact: this function is not perfect
-- it has a few false positives sometimes
-- but no false negatives, so that's good
local function is_cyclic(memo, sub, super)
	local m = memo[sub]
	local p = memo[super]
	return m and p and m < p
end

local function write_table_ex(t, memo, rev_memo, srefs, name)
	if type(t) == 'function' then
		return '_[' .. name .. ']=loadstring' .. make_safe(dump(t))
	end
	local m = {}
	local mi = 1
	for i = 1, #t do -- don't use ipairs here, we need the gaps
		local v = t[i]
		if v == t or is_cyclic(memo, v, t) then
			srefs[#srefs + 1] = {name, i, v}
			m[mi] = 'nil'
			mi = mi + 1
		else
			m[mi] = write(v, memo, rev_memo)
			mi = mi + 1
		end
	end
	for k,v in pairs(t) do
		if type(k) ~= 'number' or floor(k) ~= k or k < 1 or k > #t then
			if v == t or k == t or is_cyclic(memo, v, t) or is_cyclic(memo, k, t) then
				srefs[#srefs + 1] = {name, k, v}
			else
				m[mi] = write_key_value_pair(k, v, memo, rev_memo)
				mi = mi + 1
			end
		end
	end
	return '_[' .. name .. ']={' .. concat(m, ',') .. '}'
end

return function(t)
	local memo = {[t] = 0}
	local rev_memo = {[0] = t}
	local srefs = {}
	local result = {}

	-- phase 1: recursively descend the table structure
	local n = 0
	while rev_memo[n] do
		result[n + 1] = write_table_ex(rev_memo[n], memo, rev_memo, srefs, n)
		n = n + 1
	end

	-- phase 2: reverse order
	for i = 1, n*.5 do
		local j = n - i + 1
		result[i], result[j] = result[j], result[i]
	end

	-- phase 3: add all the tricky cyclic stuff
	for i, v in ipairs(srefs) do
		n = n + 1
		result[n] = write_key_value_pair(v[2], v[3], memo, rev_memo, '_[' .. v[1] .. ']')
	end

	-- phase 4: add something about returning the main table
	if result[n]:sub(1, 5) == '_[0]=' then
		result[n] = 'return ' .. result[n]:sub(6)
	else
		result[n + 1] = 'return _[0]'
	end

	-- phase 5: just concatenate everything
	result = concat(result, '\n')
	return n > 1 and 'local _={}\n' .. result or result
end
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lube"])sources["lube"]=([===[-- <pack lube> --
do local sources, priorities = {}, {};assert(not sources["lube.tcp"])sources["lube.tcp"]=(\[===\[-- <pack lube.tcp> --
local socket = require "socket"

--- CLIENT ---

local tcpClient = {}
tcpClient._implemented = true

function tcpClient:createSocket()
	self.socket = socket.tcp()
	self.socket:settimeout(0)
end

function tcpClient:_connect()
	self.socket:settimeout(5)
	local success, err = self.socket:connect(self.host, self.port)
	self.socket:settimeout(0)
	return success, err
end

function tcpClient:_disconnect()
	self.socket:shutdown()
end

function tcpClient:_send(data)
	return self.socket:send(data)
end

function tcpClient:_receive()
	local packet = ""
	local data, _, partial = self.socket:receive(8192)
	while data do
		packet = packet .. data
		data, _, partial = self.socket:receive(8192)
	end
	if not data and partial then
		packet = packet .. partial
	end
	if packet ~= "" then
		return packet
	end
	return nil, "No messages"
end

function tcpClient:setoption(option, value)
	if option == "broadcast" then
		self.socket:setoption("broadcast", not not value)
	end
end


--- SERVER ---

local tcpServer = {}
tcpServer._implemented = true

function tcpServer:createSocket()
	self._socks = {}
	self.socket = socket.tcp()
	self.socket:settimeout(0)
	self.socket:setoption("reuseaddr", true)
end

function tcpServer:_listen()
	self.socket:bind("*", self.port)
	self.socket:listen(5)
end

function tcpServer:send(data, clientid)
	-- This time, the clientip is the client socket.
	if clientid then
		clientid:send(data)
	else
		for sock, _ in pairs(self.clients) do
			sock:send(data)
		end
	end
end

function tcpServer:receive()
	for sock, _ in pairs(self.clients) do
		local packet = ""
		local data, _, partial = sock:receive(8192)
		while data do
			packet = packet .. data
			data, _, partial = sock:receive(8192)
		end
		if not data and partial then
			packet = packet .. partial
		end
		if packet ~= "" then
			return packet, sock
		end
	end
	for i, sock in pairs(self._socks) do
		local data = sock:receive()
		if data then
			local hs, conn = data:match("^(.+)([%+%-])\n?$")
			if hs == self.handshake and conn ==  "+" then
				self._socks[i] = nil
				return data, sock
			end
		end
	end
	return nil, "No messages."
end

function tcpServer:accept()
	local sock = self.socket:accept()
	while sock do
		sock:settimeout(0)
		self._socks[#self._socks+1] = sock
		sock = self.socket:accept()
	end
end

return {tcpClient, tcpServer}
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lube.udp"])sources["lube.udp"]=(\[===\[-- <pack lube.udp> --
local socket = require "socket"

--- CLIENT ---

local udpClient = {}
udpClient._implemented = true

function udpClient:createSocket()
	self.socket = socket.udp()
	self.socket:settimeout(0)
end

function udpClient:_connect()
	-- We're connectionless,
	-- guaranteed success!
	return true
end

function udpClient:_disconnect()
	-- Well, that's easy.
end

function udpClient:_send(data)
	return self.socket:sendto(data, self.host, self.port)
end

function udpClient:_receive()
	local data, ip, port = self.socket:receivefrom()
	if ip == self.host and port == self.port then
		return data
	end
	return false, data and "Unknown remote sent data." or ip
end

function udpClient:setOption(option, value)
	if option == "broadcast" then
		self.socket:setoption("broadcast", not not value)
	end
end


--- SERVER ---

local udpServer = {}
udpServer._implemented = true

function udpServer:createSocket()
	self.socket = socket.udp()
	self.socket:settimeout(0)
end

function udpServer:_listen()
	self.socket:setsockname("*", self.port)
end

function udpServer:send(data, clientid)
	-- We conviently use ip:port as clientid.
	if clientid then
		local ip, port = clientid:match("^(.-):(%d+)$")
		self.socket:sendto(data, ip, tonumber(port))
	else
		for clientid, _ in pairs(self.clients) do
			local ip, port = clientid:match("^(.-):(%d+)$")
			self.socket:sendto(data, ip, tonumber(port))
		end
	end
end

function udpServer:receive()
	local data, ip, port = self.socket:receivefrom()
	if data then
		local id = ip .. ":" .. port
		return data, id
	end
	return nil, "No message."
end

function udpServer:accept()
end


return {udpClient, udpServer}
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lube.core"])sources["lube.core"]=(\[===\[-- <pack lube.core> --
--- CLIENT ---

local client = {}
-- A generic client class
-- Implementations are required to implement the following functions:
--  * createSocket() --> Put a socket object in self.socket
--  * success, err = _connect() --> Connect the socket to self.host and self.port
--  * _disconnect() --> Disconnect the socket
--  * success, err = _send(data) --> Send data to the server
--  * message, err = _receive() --> Receive a message from the server
--  * setOption(option, value) --> Set a socket option, options being one of the following:
--      - "broadcast" --> Allow broadcast packets.
-- And they also have to set _implemented to evaluate to true.
--
-- Note that all implementations should have a 0 timeout, except for connecting.

function client:init()
	assert(self._implemented, "Can't use a generic client object directly, please provide an implementation.")
	-- 'Initialize' our variables
	self.host = nil
	self.port = nil
	self.connected = false
	self.socket = nil
	self.callbacks = {
		recv = nil
	}
	self.handshake = nil
	self.ping = nil
end

function client:setPing(enabled, time, msg)
	-- If ping is enabled, create a self.ping
	-- and set the time and the message in it,
	-- but most importantly, keep the time.
	-- If disabled, set self.ping to nil.
	if enabled then
		self.ping = {
			time = time,
			msg = msg,
			timer = time
		}
	else
		self.ping = nil
	end
end

function client:connect(host, port, dns)
	-- Verify our inputs.
	if not host or not port then
		return false, "Invalid arguments"
	end
	-- Resolve dns if needed (dns is true by default).
	if dns ~= false then
		local ip = socket.dns.toip(host)
		if not ip then
			return false, "DNS lookup failed for " .. host
		end
		host = ip
	end
	-- Set it up for our new connection.
	self:createSocket()
	self.host = host
	self.port = port
	-- Ask our implementation to actually connect.
	local success, err = self:_connect()
	if not success then
		self.host = nil
		self.port = nil
		return false, err
	end
	self.connected = true
	-- Send our handshake if we have one.
	if self.handshake then
		self:send(self.handshake .. "+\n")
	end
	return true
end

function client:disconnect()
	if self.connected then
		self:send(self.handshake .. "-\n")
		self:_disconnect()
		self.host = nil
		self.port = nil
	end
end

function client:send(data)
	-- Check if we're connected and pass it on.
	if not self.connected then
		return false, "Not connected"
	end
	return self:_send(data)
end

function client:receive()
	-- Check if we're connected and pass it on.
	if not self.connected then
		return false, "Not connected"
	end
	return self:_receive()
end

function client:update(dt)
	if not self.connected then return end
	assert(dt, "Update needs a dt!")
	-- First, let's handle ping messages.
	if self.ping then
		self.ping.timer = self.ping.timer + dt
		if self.ping.timer > self.ping.time then
			self:_send(self.ping.msg)
			self.ping.timer = 0
		end
	end
	-- If a recv callback is set, let's grab
	-- all incoming messages. If not, leave
	-- them in the queue.
	if self.callbacks.recv then
		local data, err = self:_receive()
		while data do
			self.callbacks.recv(data)
			data, err = self:_receive()
		end
	end
end


--- SERVER ---

local server = {}
-- A generic server class
-- Implementations are required to implement the following functions:
--  * createSocket() --> Put a socket object in self.socket.
--  * _listen() --> Listen on self.port. (All interfaces.)
--  * send(data, clientid) --> Send data to clientid, or everyone if clientid is nil.
--  * data, clientid = receive() --> Receive data.
--  * accept() --> Accept all waiting clients.
-- And they also have to set _implemented to evaluate to true.
-- Note that all functions should have a 0 timeout.

function server:init()
	assert(self._implemented, "Can't use a generic server object directly, please provide an implementation.")
	-- 'Initialize' our variables
	-- Some more initialization.
	self.clients = {}
	self.handshake = nil
	self.callbacks = {
		recv = nil,
		connect = nil,
		disconnect = nil,
	}
	self.ping = nil
	self.port = nil
end

function server:setPing(enabled, time, msg)
	-- Set self.ping if enabled with time and msg,
	-- otherwise set it to nil.
	if enabled then
		self.ping = {
			time = time,
			msg = msg
		}
	else
		self.ping = nil
	end
end

function server:listen(port)
	-- Create a socket, set the port and listen.
	self:createSocket()
	self.port = port
	self:_listen()
end

function server:update(dt)
	assert(dt, "Update needs a dt!")
	-- Accept all waiting clients.
	self:accept()
	-- Start handling messages.
	local data, clientid = self:receive()
	while data do
		local hs, conn = data:match("^(.+)([%+%-])\n?$")
		if hs == self.handshake and conn == "+" then
			-- If we already knew the client, ignore.
			if not self.clients[clientid] then
				self.clients[clientid] = {ping = -dt}
				if self.callbacks.connect then
					self.callbacks.connect(clientid)
				end
			end
		elseif hs == self.handshake and conn == "-" then
			-- Ignore unknown clients (perhaps they timed out before?).
			if self.clients[clientid] then
				self.clients[clientid] = nil
				if self.callbacks.disconnect then
					self.callbacks.disconnect(clientid)
				end
			end
		elseif not self.ping or data ~= self.ping.msg then
			-- Filter out ping messages and call the recv callback.
			if self.callbacks.recv then
				self.callbacks.recv(data, clientid)
			end
		end
		-- Mark as 'ping receive', -dt because dt is added after.
		-- (Which means a net result of 0.)
		if self.clients[clientid] then
			self.clients[clientid].ping = -dt
		end
		data, clientid = self:receive()
	end
	if self.ping then
		-- If we ping then up all the counters.
		-- If it exceeds the limit we set, disconnect the client.
		for i, v in pairs(self.clients) do
			v.ping = v.ping + dt
			if v.ping > self.ping.time then
				self.clients[i] = nil
				if self.callbacks.disconnect then
					self.callbacks.disconnect(i)
				end
			end
		end
	end
end

return {client, server}
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["lube.enet"])sources["lube.enet"]=(\[===\[-- <pack lube.enet> --
local enet = require "enet"

--- CLIENT ---

local enetClient = {}
enetClient._implemented = true

function enetClient:createSocket()
	self.socket = enet.host_create()
	self.flag = "reliable"
end

function enetClient:_connect()
	self.socket:connect(self.host .. ":" .. self.port)
	local t = self.socket:service(5000)
	local success, err = t and t.type == "connect"
	if not success then
		err = "Could not connect"
	else
		self.peer = t.peer
	end
	return success, err
end

function enetClient:_disconnect()
	self.peer:disconnect()
	return self.socket:flush()
end

function enetClient:_send(data)
	return self.peer:send(data, 0, self.flag)
end

function enetClient:_receive()
	return (self.peer:receive())
end

function enetClient:setoption(option, value)
	if option == "enetFlag" then
		self.flag = value
	end
end

function enetClient:update(dt)
	if not self.connected then return end
	if self.ping then
		if self.ping.time ~= self.ping.oldtime then
			self.ping.oldtime = self.ping.time
			self.peer:ping_interval(self.ping.time*1000)
		end
	end

	while true do
		local event = self.socket:service()
		if not event then break end

		if event.type == "receive" then
			if self.callbacks.recv then
				self.callbacks.recv(event.data)
			end
		end
	end
end


--- SERVER ---

local enetServer = {}
enetServer._implemented = true

function enetServer:createSocket()
	self.connected = {}
end

function enetServer:_listen()
	self.socket = enet.host_create("*:" .. self.port)
end

function enetServer:send(data, clientid)
	if clientid then
		return self.socket:get_peer(clientid):send(data)
	else
		return self.socket:broadcast(data)
	end
end

function enetServer:receive()
	return (self.peer:receive())
end

function enetServer:accept()
end

function enetServer:update(dt)
	if self.ping then
		if self.ping.time ~= self.ping.oldtime then
			self.ping.oldtime = self.ping.time
			for i = 1, self.socket:peer_count() do
				self.socket:get_peer(i):timeout(5, 0, self.ping.time*1000)
			end
		end
	end

	while true do
		local event = self.socket:service()
		if not event then break end

		if event.type == "receive" then
			local hs, conn = event.data:match("^(.+)([%+%-])\n?$")
			local id = event.peer:index()
			if hs == self.handshake and conn == "+" then
				if self.callbacks.connect then
					self.connected[id] = true
					self.callbacks.connect(id)
				end
			elseif hs == self.handshake and conn == "-" then
				if self.callbacks.disconnect then
					self.connected[id] = false
					self.callbacks.disconnect(id)
				end
			else
				if self.callbacks.recv then
					self.callbacks.recv(event.data, id)
				end
			end
		elseif event.type == "disconnect" then
			local id = event.peer:index()
			if self.connected[id] and self.callbacks.disconnect then
				self.callbacks.disconnect(id)
			end
			self.connected[id] = false
		elseif event.type == "connect" and self.ping then
			event.peer:timeout(5, 0, self.ping.time*1000)
		end
	end
end

return {enetClient, enetServer}
\]===\]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
local add
if not pcall(function() add = require"aioruntime".add end) then
        local loadstring=loadstring; local preload = require"package".preload
        add = function(name, rawcode)
		if not preload[name] then
		        preload[name] = function(...) return loadstring(rawcode)(...) end
		else
			print("WARNING: overwrite "..name)
		end
        end
end
for name, rawcode in pairs(sources) do add(name, rawcode, priorities[name]) end
end;
-- Get our base modulename, to require the submodules
local modulename = ...
--modulename = modulename:match("^(.+)%.init$") or modulename
modulename = "lube"

local function subrequire(sub)
	return unpack(require(modulename .. "." .. sub))
end

-- Common Class fallback
local fallback = {}
function fallback.class(_, table, parent)
	parent = parent or {}

	local mt = {}
	function mt:__index(name)
		return table[name] or parent[name]
	end
	function mt:__call(...)
		local instance = setmetatable({}, mt)
		instance:init(...)
		return instance
	end

	return setmetatable({}, mt)
end

-- Use the fallback only if not other class
-- commons implemenation is defined

--local common = fallback
--if _G.common and _G.common.class then
--	common = _G.common
--end
local common = require "featured" "class"

local lube = {}

-- All the submodules!
local client, server = subrequire "core"
lube.Client = common.class("lube.Client", client)
lube.Server = common.class("lube.Server", server)

local udpClient, udpServer = subrequire "udp"
lube.udpClient = common.class("lube.udpClient", udpClient, lube.Client)
lube.udpServer = common.class("lube.udpServer", udpServer, lube.Server)

local tcpClient, tcpServer = subrequire "tcp"
lube.tcpClient = common.class("lube.tcpClient", tcpClient, lube.Client)
lube.tcpServer = common.class("lube.tcpServer", tcpServer, lube.Server)

-- If enet is found, load that, too
if pcall(require, "enet") then
	local enetClient, enetServer = subrequire "enet"
	lube.enetClient = common.class("lube.enetClient", enetClient, lube.Client)
	lube.enetServer = common.class("lube.enetServer", enetServer, lube.Server)
end

return lube
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
local add
if not pcall(function() add = require"aioruntime".add end) then
        local loadstring=_G.loadstring or _G.load; local preload = require"package".preload
        add = function(name, rawcode)
		if not preload[name] then
		        preload[name] = function(...) return assert(loadstring(rawcode), "loadstring: "..name.." failed")(...) end
		else
			print("WARNING: overwrite "..name)
		end
        end
end
for name, rawcode in pairs(sources) do add(name, rawcode, priorities[name]) end
end;
