What is MOM ?
=============

It was a minimal Lua Framework.
Now it growing...
The featured approch is mainly usefull to embedding lot of usefull dependencies inside only one file.
This file should be also use as a script for command line use (like shell script but in lua).

At the beginning
----------------

I see [moonscript](http://moonscript.org/) and the first [sample that uses class](http://moonscript.org/#overview) :

```
class Thing
  name: "unknown"

class Person extends Thing
  say_name: => print "Hello, I am #{@name}!"

with Person!
  .name = "MoonScript"
  \say_name!
```

I can do the same sort of code in lua with (almost) the same number of lines, but only with a separated class module.

```
local class = require "class"

local Thing = class("Thing", {init=function(self)
  self.name = "unknown"
end})

local Person = class("Person", nil, Thing)
function Person:say_name()
  print( ("Hello, I am %s!"):format(self.name) )
end

local i = class.instance(Person) -- better with Person() or Person:new() ?
  i.name = "MoonScript"
  i:say_name()
```

And it print `Hello, I am MoonScript!` even it's not the case.


Why this name ?
---------------

Lua is basic, like a child.
I think we need something more adult like a parent (mother or father).
I think to `mom` or `dad`.
moonscript start by `mo*` I choose `mom`.

It's short, easy to remember, easy to call (`require "mom"`)
Search resulsts with `mom.lua` or `lua mom` on github and google show me that nothing seems exists.

What is the plan to conquer the world ?
=======================================

Mainly :
 * a default class system
 * many different other class system
 * a system to manage different implementation for a common API
 * env compat
 * bit module compat
 * strict module

After :
 * json module
 * ... and more ...
 * minifing the result...


License
=======

 * Code released under [MIT License][MIT].

[MIT]: http://opensource.org/licenses/MIT

