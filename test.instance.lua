local class = require("class")

do local foo, baz
	foo = class("foo", {init = function(self, bar) self.bar = bar end})
	baz = class.instance(foo, 'baz')
	assert(baz.bar=='baz')
end
--do local foo, baz
--	foo = class("foo", {init = function(self, bar) self.bar = bar end})
--	baz = foo('baz')
--	assert(baz.bar=='baz')
--end

do local foo, baz
	foo = class("foo", {init = function(self, bar) self.bar = bar end})
	baz = class(foo, 'baz')
end
