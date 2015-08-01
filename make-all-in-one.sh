#!/bin/sh

cd -- "$(dirname "$0")" || exit 1

# see https://github.com/tst2005/luamodules-all-in-one-file/
# wget https://raw.githubusercontent.com/tst2005/luamodules-all-in-one-file/newtry/pack-them-all.lua
ALLINONE=./aio.lua
[ -f "aio.lua" ] || ALLINONE=./thirdparty/git/tst2005/lua-aio/aio.lua

headn=$(grep -nh '^_=nil$' bin/featuredlua |head -n 1 |cut -d: -f1)

ICHECK="";
while [ $# -gt 0 ]; do
	o="$1"; shift
	case "$o" in
		-i) ICHECK=y ;;
	esac
done

#--mod 30log			thirdparty/git/yonaba/30log/30logclean.lua

lua -l "aio" -e '
local aio = require "aio"
local mod, rawmod, shebang, codehead = assert(aio.mod), assert(aio.rawmod), assert(aio.shebang), assert(aio.codehead)

aio.mode("raw")

shebang(			"bin/featuredlua")
codehead('"$headn"',		"bin/featuredlua")

--$(if [ -n "$ICHECK" ]; then
--        echo "--icheckinit"
--fi)

mod("preloaded",		"lib/preloaded.lua")
mod("gro",			"thirdparty/git/tst2005/lua-gro/gro.lua")
aio.require "gro"

mod("strict",			"thirdparty/local/unknown/strict/strict.lua")
aio.require	"strict"

mod("i", 			"lib/i.lua")
mod("generic",			"lib/generic.lua")

mod("secs",			"thirdparty/local/bartbes/secs/secs.lua")
mod("secs-featured",		"lib/secs-featured.lua")

mod("middleclass",		"thirdparty/git/kikito/middleclass/middleclass.lua")
mod("middleclass-featured",	"lib/middleclass-featured.lua")

mod("30log",			"lib/30log-old.lua")
mod("30log-featured",		"lib/30log-featured.lua")

mod("compat_env",		"thirdparty/git/davidm/lua-compat-env/lua/compat_env.lua")

mod("hump.class",		"thirdparty/git/vrld/hump/class.lua")
mod("hump.class-featured",	"lib/hump-featured.lua")

mod("bit.numberlua",		"thirdparty/git/davidm/lua-bit-numberlua/lmod/bit/numberlua.lua")

mod("lunajson",			"thirdparty/git/tst2005/lunajson/lunajson.lua")
mod("utf8",			"thirdparty/git/tst2005/lua-utf8/utf8.lua")
rawmod("cliargs",		"thirdparty/git/amireh/lua_cliargs/src/cliargs.lua")

--$(if [ -n "$ICHECK" ]; then
--	echo "--icheck"
--fi)
' > featured.lua

exit

"$ALLINONE" \
--shebang			bin/featuredlua \
--codehead $headn		bin/featuredlua \
\
$(if [ -n "$ICHECK" ]; then
	echo "--icheckinit"
fi) \
\
--mod		preloaded	lib/preloaded.lua \
--mod		gro		thirdparty/git/tst2005/lua-gro/gro.lua \
--require	gro \
--mod strict			thirdparty/local/unknown/strict/strict.lua \
--require	strict \
\
--mod i				lib/i.lua \
--mod generic			lib/generic.lua \
\
--mod secs			thirdparty/local/bartbes/secs/secs.lua \
--mod secs-featured		lib/secs-featured.lua \
$( : # --mod class			lib/class.lua \
) \
\
--mod middleclass		thirdparty/git/kikito/middleclass/middleclass.lua \
--mod middleclass-featured	lib/middleclass-featured.lua \
\
--mod 30log			lib/30log-old.lua \
--mod 30log-featured		lib/30log-featured.lua \
\
--mod compat_env		thirdparty/git/davidm/lua-compat-env/lua/compat_env.lua \
\
--mod hump.class		thirdparty/git/vrld/hump/class.lua \
\
--mod bit.numberlua		thirdparty/git/davidm/lua-bit-numberlua/lmod/bit/numberlua.lua \
\
--mod lunajson			thirdparty/git/tst2005/lunajson/lunajson.lua \
--mod utf8			thirdparty/git/tst2005/lua-utf8/utf8.lua \
--rawmod cliargs		thirdparty/git/amireh/lua_cliargs/src/cliargs.lua \
\
$(if [ -n "$ICHECK" ]; then
	echo "--icheck"
fi) \
> featured.lua

#--ifndefmod

#--autoaliases
#--code init.lua

#"$ALLINONE" --shebang init.lua $( find hate/ -depth -name '*.lua' |while read -r line; do echo "--mod $(echo "$line" | sed 's,\.lua$,,g' | tr / .) ) --code init.lua

