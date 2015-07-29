require "featured"; local i = require"i"
local common = i:need "middleclass"

local Thing = common.class("Thing", {init=function(self)
  self.name = "unknown"
end})

local Person = common.class("Person", nil, Thing)
function Person:say_name()
  print( ("Hello, I am %s!"):format(self.name) )
end

local i = common.instance(Person) -- better with Person() or Person:new() ?
  i.name = "MoonScript"
  i:say_name()

