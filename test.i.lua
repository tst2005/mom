require "featured"
local i = require "i"
--print( i)
--print( i.need("i") )
--print( i.need.i )
--print( i.need.love )
--print( i.need.os.date('%Y') )
print( i.need("class") )
print( require"generic".class )

local r = i.need.all { "io", "os", "nonexistant" }
print(type(r), r.ok and "ok" or "not ok")
print(r:unpack())
--assert( i.really.need == i.want )

--print( i.need.generic("class") )





