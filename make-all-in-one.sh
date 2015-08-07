#!/bin/sh

cd -- "$(dirname "$0")" || exit 1

# see https://github.com/tst2005/lua-aio
# wget https://raw.githubusercontent.com/tst2005/lua-aio/aio.lua

headn=$(grep -nh '^_=nil$' bin/featuredlua |head -n 1 |cut -d: -f1)

ICHECK="";
while [ $# -gt 0 ]; do
	o="$1"; shift
	case "$o" in
		-i) ICHECK=y ;;
	esac
done

LUA_PATH="?.lua;thirdparty/git/tst2005/lua-?/?.lua;;" \
lua -e 'require "gro"
local aio = require "aio"
local mod, rawmod = aio.mod, aio.rawmod
assert( mod and rawmod )

aio.mode("raw2")

aio.shebang(			"bin/featuredlua")
aio.codehead('"$headn"',	"bin/featuredlua")

--$(if [ -n "$ICHECK" ]; then
--        echo "--icheckinit"
--fi)

mod("preloaded",		"lib/preloaded.lua")
mod("gro",			"thirdparty/git/tst2005/lua-gro/gro.lua")
mod("aio",			"aio.lua") -- thirdparty/git/tst2005/lua-aio/aio.lua

mod("strict",			"thirdparty/local/unknown/strict/strict.lua")

mod("i", 			"lib/i.lua")
mod("generic",			"lib/generic.lua") -- rename to featured !

mod("secs",			"thirdparty/local/bartbes/secs/secs.lua")
mod("secs-featured",		"lib/secs-featured.lua")

mod("middleclass",		"thirdparty/git/kikito/middleclass/middleclass.lua")
mod("middleclass-featured",	"lib/middleclass-featured.lua")

mod("30log",			"thirdparty/git/yonaba/30log/30logclean.lua")
--mod("30log",			"thirdparty/git/yonaba/30log/30log.lua")
mod("30log-featured",		"lib/30log-featured.lua")

mod("compat_env",		"thirdparty/git/davidm/lua-compat-env/lua/compat_env.lua")

mod("hump.class",		"thirdparty/local/vrld/hump/class.lua")
mod("hump.class-featured",	"lib/hump-featured.lua")

mod("bit.numberlua",		"thirdparty/git/davidm/lua-bit-numberlua/lmod/bit/numberlua.lua")

mod("lunajson",			"thirdparty/git/tst2005/lunajson/lunajson.lua")
mod("utf8",			"thirdparty/git/tst2005/lua-utf8/utf8.lua")
rawmod("cliargs",		"thirdparty/git/amireh/lua_cliargs/src/cliargs.lua")
mod("ser",			"thirdparty/git/gvx/ser/ser.lua")

mod("isolation",		"thirdparty/git/tst2005/lua-isolation/isolation.lua")

--$(if [ -n "$ICHECK" ]; then
--	echo "--icheck"
--fi)
aio.finish()
' > mom.lua


