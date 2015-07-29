local class = require "secs"

local common = {}
function common.class(name, t, parent)
    parent = parent or class
    t = t or {}
    t.__baseclass = parent
    return setmetatable(t, getmetatable(parent))
end
function common.instance(class, ...)
    return class:new(...)
end
common.__BY = "secs"

--common.common = common
pcall(function() require("i"):register("secs", common) end)
return { common = common }
