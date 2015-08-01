
local common = require "secs-featured".common or require "secs-featured"
return setmetatable(
	{ common = common, class = common.class, instance = common.class, __BY = common.__BY },
	{__call = function(_, ...) return common.class(...) end}
)

