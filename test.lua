local class = require "class"

local Thing = class("Thing", {init=function(self)
  self.name = "unknown"
end})

local Person = class("Person", nil, Thing)
function Person:say_name()
  print( ("Hello, I am %s!"):format(self.name) )
end

local i = Person:new()
  i.name = "MoonScript"
  i:say_name()
