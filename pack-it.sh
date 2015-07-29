#!/bin/sh

cd -- "$(dirname "$0")" || exit 1

# see https://github.com/tst2005/luamodules-all-in-one-file/
# wget https://raw.githubusercontent.com/tst2005/luamodules-all-in-one-file/newtry/pack-them-all.lua
ALLINONE=./thirdparty/git/tst2005/luamodules-all-in-one-file/pack-them-all.lua

headn=$(grep -nh '^_=nil$' bin/featuredlua |head -n 1 |cut -d: -f1)

ICHECK="";TEST=y;
while [ $# -gt 0 ]; do
	o="$1"; shift
	case "$o" in
		-i) ICHECK=y ;;
		-m) TEST="" ;;
	esac
done

"$ALLINONE" \
--shebang			bin/featuredlua \
--codehead $headn		bin/featuredlua \
\
$(if [ -n "$ICHECK" ]; then
	echo "--icheckinit"
fi) \
\
--mod		gro		thirdparty/git/tst2005/lua-gro/gro.lua \
--require	gro									\
--mod strict			thirdparty/local/unknown/strict/strict.lua	\
--require	strict		\
\
--mod i				lib/i.lua \
\
--mod secs			thirdparty/local/bartbes/secs/secs.lua \
--mod secs-featured		lib/secs-featured.lua \
\
--mod middleclass		thirdparty/git/kikito/middleclass/middleclass.lua \
--mod middleclass-featured	lib/middleclass-featured.lua \
\
--mod 30log			thirdparty/git/yonaba/30log/30log.lua \
--mod 30log-featured		lib/30log-featured.lua \
\
--mod compat_env		thirdparty/git/davidm/lua-compat-env/lua/compat_env.lua \
\
--mod hump.class		thirdparty/git/vrld/hump/class.lua \
\
--mod bit.numberlua		thirdparty/git/davidm/lua-bit-numberlua/lmod/bit/numberlua.lua \
\
$(if [ -n "$ICHECK" ]; then
	echo "--icheck"
fi) \
$(if [ -n "$TEST" ]; then
	echo "--code bin/featuredlua"
fi) \
> featured.lua

#--autoaliases
#--code init.lua

#--mod hump.class		thirdparty/git/vrld/hump/class.lua

#"$ALLINONE" --shebang init.lua $( find hate/ -depth -name '*.lua' |while read -r line; do echo "--mod $(echo "$line" | sed 's,\.lua$,,g' | tr / .) ) --code init.lua

