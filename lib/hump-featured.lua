error("hump.class modify the global env ! FIXIT")

-- interface for cross class-system compatibility (see https://github.com/bartbes/Class-Commons).

local _M = {}
local humpclass = require "hump.class"

local common = {}
function common.class(name, prototype, parent)
        return new{__includes = {prototype, parent}}
end
function common.instance(class, ...)
        return class(...)
end
common.__BY = "hump.class"
pcall(function() require("classcommons2"):register("hump.class", common) end)


