require "mom"
local i = require "i"
---------------- i.need ----------------
do
assert( i.need "i" == i)
assert( i.need "nonexistant" == false )
assert( i.need "os" == require "os" )
assert( i.need "os".date == require "os".date )
end

--print( i.need("class") )
--print( require"generic".class )


---------------- i.need.all ----------------
do
local r = i.need.all { "io", "os", "nonexistant" }
assert( r[1] == require "io")
assert( r[2] == require "os")
assert( r[3] == false)
assert( r.ok ==  true)
local io, os, nonexistant = r:unpack()
assert( io == require "io")
assert( os == require "os")
assert( nonexistant == false)
end

---------------- i.need.any ----------------

do
local mod, name = i.need.any { "io", "os", "nonexistant" } 
assert( mod == require "io" )
assert( name == "io" )
end

do
local mod, name = i.need.any { "nonexistant", "io", "os", "nonexistant2" }
assert( mod == require "io" )
assert( name == "io" )
end




--assert( i.really.need == i.want )

--print( i.need.generic("class") )


-- featured API --

-- *load		*env.load
-- *loadstring		*env.loadstring
-- *loadfile		*env.loadfile
-- *bit.*		...
-- *&			*bit.band
-- ...			...
-- *band		*bit.band
-- *class		*common.class
-- *instance		*common.instance

--local bit, name = i.require.any('bit', 'bit32', 'bit.numberlua')

local bit, name = i.need.unified("bit")
-- equal to
local bit, name = i.need.any { 'bit', 'bit32', 'bit.numberlua' }

local load = i.need.featured("load") -- load, loadstring, loadfile
local load, loadstring, loadfile = i.need.featured { "load", "loadstring", "loadfile" }:unpack()




local load = i.need.featured("load") -- load, loadstring, loadfile

local e = {}
if i.can "import" then
	e = i.need "import" ( e, i.need.featured { "load", "loadstring", "loadfile" } )
	-- or
	i.need.featured.import (e, { "load", "loadstring", "loadfile" } )
	i.need.import.featured(e, {...})
	
end

-- i.dont.need("modname") -- call require"preloaded".remove("modname")
-- i.dont.need.featured('bit') -- remove all supported preloaded module for featured.'bit' ?



