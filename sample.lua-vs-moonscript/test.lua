local class = require "class" -- classcommons2

local Thing = class("Thing", {init=function(self)
  self.name = "unknown"
end})

local Person = class("Person", nil, Thing)
function Person:say_name()
  print( ("Hello, I am %s!"):format(self.name) )
end

local p = Person:new() -- or class(Person)
  p.name = "MoonScript"
  p:say_name()
