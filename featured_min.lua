
_=[[
	for name in luajit lua5.3 lua-5.3 lua5.2 lua-5.2 lua5.1 lua-5.1 lua; do
		: ${LUA:=$(command -v luajit)}
	done
	LUA_PATH='./?.lua;./?/init.lua;./lib/?.lua;./lib/?/init.lua;;'
	exec "$LUA" "$0" "$@"
	exit $?
]]_=nil
require("package").preload["gro"]=function(...)local abn5={}
local AvK=require"package".loaded;local rhVu={}
local ngzOjWHO={__newindex=function()end,__tostring=function()return"locked"end,__metatable=assert(rhVu)}setmetatable(rhVu,ngzOjWHO)
assert(tostring(rhVu=="locked"))local dM=true
local function U(...)if dM then dM=false;rawset(...)return true end;return false end;local _u=true;local aLgiy
local function mvi(L,WRH9,cJoBcud)if cJoBcud==nil then return true end
if _u and
type(cJoBcud)=="string"then _u=false;aLgiy=cJoBcud;return true elseif aLgiy==cJoBcud then return true end;return false end;local function g4KV(e)
return(#e>30)and
(e:sub(1,20).."... ..."..e:sub(-4,-1))or e end
local dT7iYDf4=getmetatable(_G)or{}
dT7iYDf4.__newindex=function(B6zKxgVs,O3_X,DVs8kf2w)
if O3_X=="_"and mvi(_G,O3_X,DVs8kf2w)then return end;if AvK[O3_X]==DVs8kf2w then
io.stderr:write("drop global write of module '"..
tostring(O3_X).."'\n")return end;if O3_X=="arg"then if
U(_G,O3_X,DVs8kf2w)then return end end
error(("global env is read-only. Write of %q"):format(g4KV(O3_X)),2)end;dT7iYDf4.__metatable=rhVu;setmetatable(_G,dT7iYDf4)if
getmetatable(_G)~=rhVu then
error("unable to setup global env to read-only",2)end;return{}end;require("gro")
require("package").preload["strict"]=function(...)
local vms5,M7,v3,ihKb=debug.getinfo,error,rawset,rawget;local JGSK=getmetatable(_G)
if JGSK==nil then JGSK={}setmetatable(_G,JGSK)end;JGSK.__declared={}local function rA5U()local Uc06=vms5(3,"S")
return Uc06 and Uc06.what or"C"end
JGSK.__newindex=function(lcBL,DHPxI,dx)
if
not JGSK.__declared[DHPxI]then local RRuSHnxf=rA5U()if RRuSHnxf~="main"and RRuSHnxf~="C"then
M7(
"assignment to undeclared variable '"..DHPxI.."'",2)end
JGSK.__declared[DHPxI]=true end;v3(lcBL,DHPxI,dx)end
JGSK.__index=function(mcYOuT,Rr)if not JGSK.__declared[Rr]and rA5U()~="C"then
M7(
"variable '"..Rr.."' is not declared",2)end;return ihKb(mcYOuT,Rr)end end;require("strict")
require("package").preload["i"]=function(...)
local scRP0={}scRP0._VERSION="2.0"local AI0R2TQ6={}local yA={}local function XmVolesU(W_63_9)local h9dyA_4T;pcall(function()
h9dyA_4T=require(W_63_9)end)
return h9dyA_4T end
local function eZ0l3ch(oh)if AI0R2TQ6[oh]then return
AI0R2TQ6[oh]end
local function DZXGTh(Uk7e)
if

type(Uk7e)~="table"or
type(Uk7e.common)~="table"or not Uk7e.common.class or not Uk7e.common.instance then assert(type(Uk7e)=="table")assert(type(Uk7e.common)==
"table")
assert(Uk7e.common.class)assert(Uk7e.common.instance)return false end;return Uk7e.common end
local Su9Koz=DZXGTh(XmVolesU(oh.."-featured"))or DZXGTh(XmVolesU(oh))return Su9Koz end;function scRP0:need(KwQCk_G)return eZ0l3ch(KwQCk_G)end
function scRP0:requireany(...)local ptZa=
type(...)=="table"and...or{...}
for PEqsd,iSj in
ipairs(ptZa)do local iXxD6s=eZ0l3ch(iSj)if iXxD6s then return iXxD6s end end;error("requireany: no implementation found",2)
return false end
function scRP0:register(oiY,FsYIVlkf)
assert(FsYIVlkf,"register: argument #2 is invalid")assert(FsYIVlkf.class)
assert(FsYIVlkf.instance)yA[#yA+1]=oiY;AI0R2TQ6[oiY]=FsYIVlkf;return FsYIVlkf end;function scRP0:unregister(HLXS0Q_)end;function scRP0:available()return yA end;return scRP0 end
require("package").preload["secs"]=function(...)local Kw={}function Kw:__index(vDnoL55)return
self.__baseclass[vDnoL55]end
local nvaIsNv7=setmetatable({__baseclass={}},Kw)
function nvaIsNv7:new(...)local xlAK={}xlAK.__baseclass=self
setmetatable(xlAK,getmetatable(self))if xlAK.init then xlAK:init(...)end;return xlAK end;return nvaIsNv7 end
require("package").preload["secs-featured"]=function(...)
local zr1y=require"secs"local Hs={}
function Hs.class(jk,qzSFyIO,Z65)Z65=Z65 or zr1y;qzSFyIO=qzSFyIO or{}
qzSFyIO.__baseclass=Z65;return setmetatable(qzSFyIO,getmetatable(Z65))end;function Hs.instance(zr1y,...)return zr1y:new(...)end;Hs.__BY="secs"
pcall(function()
require("i"):register("secs",Hs)end)return{common=Hs}end
require("package").preload["middleclass"]=function(...)
local umyCNfj={_VERSION='middleclass v3.0.1',_DESCRIPTION='Object Orientation for Lua',_URL='https://github.com/kikito/middleclass',_LICENSE=[[
    MIT LICENSE

    Copyright (c) 2011 Enrique García Cota

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:

    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
  ]]}
local function FT(_Fr2YU)local Xfn=_Fr2YU.__instanceDict;Xfn.__index=Xfn;local U=_Fr2YU.super
if U then
local Ebsw=U.static;setmetatable(Xfn,U.__instanceDict)
setmetatable(_Fr2YU.static,{__index=function(UlikV,JtAjijkG)return
Xfn[JtAjijkG]or Ebsw[JtAjijkG]end})else
setmetatable(_Fr2YU.static,{__index=function(s,YAtG_LV3)return Xfn[YAtG_LV3]end})end end
local function YVLXYq(LfEJbh_)
setmetatable(LfEJbh_,{__tostring=function()return"class "..LfEJbh_.name end,__index=LfEJbh_.static,__newindex=LfEJbh_.__instanceDict,__call=function(JD,...)return
JD:new(...)end})end
local function bJfct(u,pzDMZwG)local XPoQB={name=u,super=pzDMZwG,static={},__mixins={},__instanceDict={}}
XPoQB.subclasses=setmetatable({},{__mode="k"})FT(XPoQB)YVLXYq(XPoQB)return XPoQB end
local function OhuFpq_N(XxJ,o5sms)
return
function(...)local JQi1jg=XxJ.super[o5sms]
assert(type(JQi1jg)=='function',tostring(XxJ)..
" doesn't implement metamethod '"..o5sms.."'")return JQi1jg(...)end end;local function Dzg(wVzn)
for pE,RSjapQ in ipairs(wVzn.__metamethods)do wVzn[RSjapQ]=OhuFpq_N(wVzn,RSjapQ)end end;local function _4O(QJf,zC)
QJf.initialize=function(pfZ3SPy_,...)return
zC.initialize(pfZ3SPy_,...)end end
local function C(pDNa2ox6,Do6yo7nm)
assert(type(Do6yo7nm)=='table',"mixin must be a table")
for y06X3k,ivnJjrA in pairs(Do6yo7nm)do if y06X3k~="included"and y06X3k~="static"then
pDNa2ox6[y06X3k]=ivnJjrA end end
if Do6yo7nm.static then for d3fMjkg,el in pairs(Do6yo7nm.static)do
pDNa2ox6.static[d3fMjkg]=el end end;if type(Do6yo7nm.included)=="function"then
Do6yo7nm:included(pDNa2ox6)end
pDNa2ox6.__mixins[Do6yo7nm]=true end;local fLI2zRe=bJfct("Object",nil)
fLI2zRe.static.__metamethods={'__add','__call','__concat','__div','__ipairs','__le','__len','__lt','__mod','__mul','__pairs','__pow','__sub','__tostring','__unm'}
function fLI2zRe.static:allocate()
assert(type(self)=='table',"Make sure that you are using 'Class:allocate' instead of 'Class.allocate'")return setmetatable({class=self},self.__instanceDict)end;function fLI2zRe.static:new(...)local Wu_uIt=self:allocate()
Wu_uIt:initialize(...)return Wu_uIt end
function fLI2zRe.static:subclass(w)
assert(
type(self)=='table',"Make sure that you are using 'Class:subclass' instead of 'Class.subclass'")
assert(type(w)=="string","You must provide a name(string) for your class")local sgeP=bJfct(w,self)Dzg(sgeP)_4O(sgeP,self)
self.subclasses[sgeP]=true;self:subclassed(sgeP)return sgeP end;function fLI2zRe.static:subclassed(CM)end
function fLI2zRe.static:isSubclassOf(Qlmlet)
return

type(Qlmlet)=='table'and type(self)=='table'and
type(self.super)=='table'and
(self.super==Qlmlet or

type(self.super.isSubclassOf)=='function'and self.super:isSubclassOf(Qlmlet))end
function fLI2zRe.static:include(...)
assert(type(self)=='table',"Make sure you that you are using 'Class:include' instead of 'Class.include'")for _RkGFh6,hw18 in ipairs({...})do C(self,hw18)end;return self end
function fLI2zRe.static:includes(nvCiFt7r)
return


type(nvCiFt7r)=='table'and type(self)=='table'and type(self.__mixins)=='table'and
(self.__mixins[nvCiFt7r]or type(self.super)=='table'and
type(self.super.includes)=='function'and
self.super:includes(nvCiFt7r))end;function fLI2zRe:initialize()end;function fLI2zRe:__tostring()return
"instance of "..tostring(self.class)end
function fLI2zRe:isInstanceOf(xSebv5Jc)
return

type(self)=='table'and type(self.class)=='table'and
type(xSebv5Jc)=='table'and
(xSebv5Jc==self.class or

type(xSebv5Jc.isSubclassOf)=='function'and self.class:isSubclassOf(xSebv5Jc))end;function umyCNfj.class(mMp,rDtVf,...)rDtVf=rDtVf or fLI2zRe
return rDtVf:subclass(mMp,...)end;umyCNfj.Object=fLI2zRe
setmetatable(umyCNfj,{__call=function(vj,...)return
umyCNfj.class(...)end})return umyCNfj end
require("package").preload["middleclass-featured"]=function(...)
local z={_VERSION='middleclass v3.0.0',_DESCRIPTION='Object Orientation for Lua',_LICENSE=[[
    MIT LICENSE

    Copyright (c) 2011 Enrique García Cota

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:

    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
  ]]}
local function Zg(O)local N5UjTN=O.__instanceDict;N5UjTN.__index=N5UjTN;local qLH5=O.super
if qLH5 then
local tE=qLH5.static;setmetatable(N5UjTN,qLH5.__instanceDict)
setmetatable(O.static,{__index=function(VcV0EuD,pX4gCR)return
N5UjTN[pX4gCR]or tE[pX4gCR]end})else
setmetatable(O.static,{__index=function(gad4ZcL,dk)return N5UjTN[dk]end})end end
local function ykRppH(E)
setmetatable(E,{__tostring=function()return"class "..E.name end,__index=E.static,__newindex=E.__instanceDict,__call=function(OO,...)
return OO:new(...)end})end
local function WQ6(y,cR6rJlAl)
local M6ilzGJ={name=y,super=cR6rJlAl,static={},__mixins={},__instanceDict={}}M6ilzGJ.subclasses=setmetatable({},{__mode="k"})
Zg(M6ilzGJ)ykRppH(M6ilzGJ)return M6ilzGJ end
local function y36Aetn(iW6CD,wZdg)
return
function(...)local BaX=iW6CD.super[wZdg]
assert(type(BaX)=='function',tostring(iW6CD)..
" doesn't implement metamethod '"..wZdg.."'")return BaX(...)end end
local function iPL3B4cr(SJsW11k)for Ki1HJT,wjim8xCV in ipairs(SJsW11k.__metamethods)do
SJsW11k[wjim8xCV]=y36Aetn(SJsW11k,wjim8xCV)end end;local function GI2hz6SK(E,QLam)
E.initialize=function(qTDt,...)return QLam.initialize(qTDt,...)end end
local function Oh(v,Ta)
assert(type(Ta)=='table',"mixin must be a table")for u,nArcvQl in pairs(Ta)do
if u~="included"and u~="static"then v[u]=nArcvQl end end;if Ta.static then for h6Ub7U,Gm in pairs(Ta.static)do
v.static[h6Ub7U]=Gm end end;if
type(Ta.included)=="function"then Ta:included(v)end
v.__mixins[Ta]=true end;local PG=WQ6("Object",nil)
PG.static.__metamethods={'__add','__call','__concat','__div','__le','__lt','__mod','__mul','__pow','__sub','__tostring','__unm'}
function PG.static:allocate()
assert(type(self)=='table',"Make sure that you are using 'Class:allocate' instead of 'Class.allocate'")return setmetatable({class=self},self.__instanceDict)end;function PG.static:new(...)local YKA7cU=self:allocate()
YKA7cU:initialize(...)return YKA7cU end
function PG.static:subclass(mCsewfX)
assert(
type(self)=='table',"Make sure that you are using 'Class:subclass' instead of 'Class.subclass'")
assert(type(mCsewfX)=="string","You must provide a name(string) for your class")local yY=WQ6(mCsewfX,self)iPL3B4cr(yY)GI2hz6SK(yY,self)
self.subclasses[yY]=true;self:subclassed(yY)return yY end;function PG.static:subclassed(Xf)end
function PG.static:isSubclassOf(UlFdiZ7v)
return

type(UlFdiZ7v)=='table'and type(self)=='table'and
type(self.super)=='table'and
(self.super==UlFdiZ7v or

type(self.super.isSubclassOf)=='function'and self.super:isSubclassOf(UlFdiZ7v))end
function PG.static:include(...)
assert(type(self)=='table',"Make sure you that you are using 'Class:include' instead of 'Class.include'")for U,wFeA in ipairs({...})do Oh(self,wFeA)end;return self end
function PG.static:includes(JQgI)
return

type(JQgI)=='table'and type(self)=='table'and type(self.__mixins)=='table'and
(
self.__mixins[JQgI]or
type(self.super)=='table'and
type(self.super.includes)=='function'and self.super:includes(JQgI))end;function PG:initialize()end;function PG:__tostring()
return"instance of "..tostring(self.class)end
function PG:isInstanceOf(N)
return

type(self)=='table'and
type(self.class)=='table'and type(N)=='table'and
(N==self.class or type(N.isSubclassOf)=='function'and
self.class:isSubclassOf(N))end;function z.class(fs52REi,PUNkgaiM,...)PUNkgaiM=PUNkgaiM or PG
return PUNkgaiM:subclass(fs52REi,...)end;z.Object=PG
setmetatable(z,{__call=function(s6FbB,...)return
z.class(...)end})local n={}
if type(z.common)=="table"and
type(z.common.class)=="function"and
type(z.common.instannce)=="function"then n=z.common else
function n.class(X,dc61,aguhyl)
local p=z.class(X,aguhyl)dc61=dc61 or{}for gOPDv,aSdZU3 in pairs(dc61)do p[gOPDv]=aSdZU3 end;if
dc61.init then p.initialize=dc61.init end;return p end;function n.instance(YKDL,...)return YKDL:new(...)end end;if n.__BY==nil then n.__BY="middleclass"end
pcall(function()
require("classcommons2"):register("middleclass",n)end)return{common=n}end
require("package").preload["30log"]=function(...)
local oFyb6OLp,oGdh_mv,WjvvK,TASVwBgU,KjUncMB=assert,pairs,type,tostring,setmetatable
local XkT,c3dr,NGH,tIc={},KjUncMB({},{__mode='k'}),KjUncMB({},{__mode='k'})local function MD2O(N4aMD_P,pCi)
oFyb6OLp(NGH[N4aMD_P],('Wrong method call. Expected class:%s.'):format(pCi))end
local function HQ(NzeoQJ,AwGfFV,wCRY)
NzeoQJ=NzeoQJ or{}local d0uKSVw1=AwGfFV or{}
for lNOqUk8,YAnZNei in oGdh_mv(NzeoQJ)do
if
wCRY and WjvvK(YAnZNei)==wCRY then d0uKSVw1[lNOqUk8]=YAnZNei elseif not wCRY then if WjvvK(YAnZNei)=='table'and
lNOqUk8 ~="__index"then d0uKSVw1[lNOqUk8]=HQ(YAnZNei)else
d0uKSVw1[lNOqUk8]=YAnZNei end end end;return d0uKSVw1 end
local function cng(h8YWR44E,...)MD2O(h8YWR44E,'new(...) or class(...)')
local VF={class=h8YWR44E}c3dr[VF]=TASVwBgU(VF)KjUncMB(VF,h8YWR44E)
if h8YWR44E.init then if
WjvvK(h8YWR44E.init)=='table'then HQ(h8YWR44E.init,VF)else
h8YWR44E.init(VF,...)end end;return VF end
local function lE(fTrMe,ypDndT8,MV65)MD2O(fTrMe,'extend(...)')local Y3D66Ym9={}
NGH[Y3D66Ym9]=TASVwBgU(Y3D66Ym9)HQ(MV65,HQ(fTrMe,Y3D66Ym9))
Y3D66Ym9.name,Y3D66Ym9.__index,Y3D66Ym9.super=
MV65 and MV65.name or ypDndT8,Y3D66Ym9,fTrMe;return KjUncMB(Y3D66Ym9,fTrMe)end
XkT={__call=function(q,...)return q:new(...)end,__tostring=function(PhJ,...)if c3dr[PhJ]then
return("instance of '%s' (%s)"):format(
rawget(PhJ.class,'name')or'?',c3dr[PhJ])end
return
NGH[PhJ]and("class '%s' (%s)"):format(
rawget(PhJ,'name')or'?',NGH[PhJ])or PhJ end}NGH[XkT]=TASVwBgU(XkT)
KjUncMB(XkT,{__tostring=XkT.__tostring})
local nI2F0id={isClass=function(h,j2K)local r8hgwQ=not not NGH[h]if j2K then
return r8hgwQ and(h.super==j2K)end;return r8hgwQ end,isInstance=function(_6U,GLSzBQs)local c=
not not c3dr[_6U]if GLSzBQs then return
c and(_6U.class==GLSzBQs)end;return c end}
tIc=function(xg,Id2KoP_G)local Y2or=HQ(Id2KoP_G)Y2or.mixins=KjUncMB({},{__mode='k'})
NGH[Y2or]=TASVwBgU(Y2or)
Y2or.name,Y2or.__tostring,Y2or.__call=xg or Y2or.name,XkT.__tostring,XkT.__call
Y2or.include=function(zN8ASHV5,iju)MD2O(zN8ASHV5,'include(mixin)')
zN8ASHV5.mixins[iju]=true;return HQ(iju,zN8ASHV5,'function')end
Y2or.new,Y2or.extend,Y2or.__index,Y2or.includes=cng,lE,Y2or,function(XsWgh,l4Hdz)
MD2O(XsWgh,'includes(mixin)')
return not
not(XsWgh.mixins[l4Hdz]or
(XsWgh.super and XsWgh.super:includes(l4Hdz)))end
Y2or.extends=function(NSXCgSH,nI2F0id)MD2O(NSXCgSH,'extends(class)')local Wq=NSXCgSH;repeat Wq=Wq.super until(
Wq==nI2F0id or Wq==nil)return nI2F0id and
(Wq==nI2F0id)end;return KjUncMB(Y2or,XkT)end;nI2F0id._DESCRIPTION='30 lines library for object orientation in Lua'
nI2F0id._VERSION='30log v1.0.0'nI2F0id._URL='http://github.com/Yonaba/30log'
nI2F0id._LICENSE='MIT LICENSE <http://www.opensource.org/licenses/mit-license.php>'return
KjUncMB(nI2F0id,{__call=function(SbOQ,...)return tIc(...)end})end
require("package").preload["30log-featured"]=function(...)
local IiuHGo=require"30log"local cGqxtYr={}
cGqxtYr.class=function(yu9fg0nN,wgx,zlU7X)
local t=IiuHGo():extends(zlU7X):extends(wgx)t.__init=wgx.init or(zlU7X or{}).init
t.__name=yu9fg0nN;return t end
cGqxtYr.instance=function(IiuHGo,...)return IiuHGo:new(...)end;cGqxtYr.__BY="30log"local bgJFKeeZ={common=cGqxtYr}
pcall(function()
require("i"):register("30log",cGqxtYr)end)return bgJFKeeZ end
require("package").preload["compat_env"]=function(...)
local f6qbO={_TYPE='module',_NAME='compat_env',_VERSION='0.2.2.20120406'}
local function kk(bLHDW,YjFd7b)local jZgPYb=YjFd7b or'bt'
local zN2=bLHDW and#bLHDW>0 and bLHDW:byte(1)==27
if zN2 and not jZgPYb:match'b'then return nil,
("attempt to load a binary chunk (mode is '%s')"):format(YjFd7b)elseif
not zN2 and not jZgPYb:match't'then return nil,
("attempt to load a text chunk (mode is '%s')"):format(YjFd7b)end;return true end;local QrubIAv=pcall(load,'')
if QrubIAv then f6qbO.load=_G.load
f6qbO.loadfile=_G.loadfile else
function f6qbO.load(IN69pa5,U,OWJ,WtalJw)local JYrf2
if type(IN69pa5)=='string'then local KHDOUlRY=IN69pa5
local I0JvPpn,Ce4ZE=kk(KHDOUlRY,OWJ)if not I0JvPpn then return I0JvPpn,Ce4ZE end;local Ce4ZE
JYrf2,Ce4ZE=loadstring(KHDOUlRY,U)if not JYrf2 then return JYrf2,Ce4ZE end elseif type(IN69pa5)=='function'then
local OVx_mN=IN69pa5
if(OWJ or'bt')~='bt'then local byE=IN69pa5()local bITCI,K=kk(byE,OWJ)if not bITCI then
return bITCI,K end
OVx_mN=function()
if byE then local F5dtVpnN=byE;byE=nil;return F5dtVpnN else return IN69pa5()end end end;local lB;JYrf2,lB=load(OVx_mN,U)if not JYrf2 then return JYrf2,lB end else
error(("bad argument #1 to 'load' (function expected, got %s)"):format(type(IN69pa5)),2)end;if WtalJw then setfenv(JYrf2,WtalJw)end;return JYrf2 end
function f6qbO.loadfile(kxeBp,a,kQ)
if(a or'bt')~='bt'then local EE9LAE;local iVx,eg=io.open(kxeBp,'rb')if
not iVx then return iVx,eg end;local function AQviNt()local NviN0i;NviN0i,EE9LAE=iVx:read(4096)
return NviN0i end
local T6,eg=f6qbO.load(AQviNt,kxeBp and'@'..kxeBp,a,kQ)iVx:close()if not T6 then return T6,eg end
if EE9LAE then return nil,EE9LAE end;return T6 else local BlMQce,o=loadfile(kxeBp)if not BlMQce then return BlMQce,o end;if kQ then
setfenv(BlMQce,kQ)end;return BlMQce end end end
if _G.setfenv then f6qbO.setfenv=_G.setfenv;f6qbO.getfenv=_G.getfenv else
local function dpRE(r3JzMga6)local Tuyw,FYLcr2nu
local ioS69=0;local AiP
repeat ioS69=ioS69+1
Tuyw,FYLcr2nu=debug.getupvalue(r3JzMga6,ioS69)if Tuyw==''then AiP=true end until Tuyw=='_ENV'or Tuyw==nil
if Tuyw~='_ENV'then ioS69=nil;if AiP then
error("upvalues not readable in Lua 5.2 when debug info missing",3)end end;return(Tuyw=='_ENV')and ioS69,FYLcr2nu,AiP end
local function fEiXwWq(S2jwpoi,_WX9u)
if type(S2jwpoi)=='number'then
if S2jwpoi<0 then
error(("bad argument #1 to '%s' (level must be non-negative)"):format(_WX9u),3)elseif S2jwpoi<1 then
error("thread environments unsupported in Lua 5.2",3)end;S2jwpoi=debug.getinfo(S2jwpoi+2,'f').func elseif
type(S2jwpoi)~='function'then
error(("bad argument #1 to '%s' (number expected, got %s)"):format(type(_WX9u,S2jwpoi)),2)end;return S2jwpoi end
function f6qbO.setfenv(u0riyU,U)local u0riyU=fEiXwWq(u0riyU,'setfenv')
local H,WNph,ytF=dpRE(u0riyU)
if H then
debug.upvaluejoin(u0riyU,H,function()return H end,1)debug.setupvalue(u0riyU,H,U)else
local d=debug.getinfo(u0riyU,'S').what;if d~='Lua'and d~='main'then
error("'setfenv' cannot change environment of given object",2)end end;return u0riyU end
function f6qbO.getfenv(gRm)if gRm==0 or gRm==nil then return _G end
local gRm=fEiXwWq(gRm,'setfenv')local LPX0,g=dpRE(gRm)if not LPX0 then return _G end;return g end end;return f6qbO end
require("package").preload["hump.class"]=function(...)
local function _l(Gzk,J7nsK,dXbd)
if J7nsK==nil then return Gzk elseif
type(J7nsK)~='table'then return J7nsK elseif dXbd[J7nsK]then return dXbd[J7nsK]end;dXbd[J7nsK]=Gzk
for vQj,sVBxyy in pairs(J7nsK)do vQj=_l({},vQj,dXbd)if Gzk[vQj]==nil then
Gzk[vQj]=_l({},sVBxyy,dXbd)end end;return Gzk end;local function qao(N9d,S7)return _l(N9d,S7,{})end;local function ipUPIzc(bJtvRSR)return
setmetatable(qao({},bJtvRSR),getmetatable(bJtvRSR))end
local function N8(aBhZK5)local Jz8JUscj=
aBhZK5.__includes or{}
if getmetatable(Jz8JUscj)then Jz8JUscj={Jz8JUscj}end
for O,tGmbAgE in ipairs(Jz8JUscj)do
if type(tGmbAgE)=="string"then tGmbAgE=_G[tGmbAgE]end;qao(aBhZK5,tGmbAgE)end;aBhZK5.__index=aBhZK5
aBhZK5.init=aBhZK5.init or aBhZK5[1]or function()end;aBhZK5.include=aBhZK5.include or qao
aBhZK5.clone=aBhZK5.clone or ipUPIzc;return
setmetatable(aBhZK5,{__call=function(oU_r,...)local n_lv=setmetatable({},oU_r)n_lv:init(...)return n_lv end})end
if class_commons~=false and not common then common={}function common.class(UYQF,WXx,W4EuxJXi)return
N8{__includes={WXx,W4EuxJXi}}end;function common.instance(BlYNd61h,...)return
BlYNd61h(...)end end;return
setmetatable({new=N8,include=qao,clone=ipUPIzc},{__call=function(XDPndG,...)return N8(...)end})end
require("package").preload["bit.numberlua"]=function(...)
local sJYFQIP4={_TYPE='module',_NAME='bit.numberlua',_VERSION='0.3.1.20120131'}local Ogq0S2=math.floor;local n8Cw3SR=2^32;local GJqd7gt=n8Cw3SR-1
local function slE5aDm2(ichL)local NOK={}
local Alv=setmetatable({},NOK)
function NOK:__index(YeLO2)local CkrmO=ichL(YeLO2)Alv[YeLO2]=CkrmO;return CkrmO end;return Alv end
local function aL_g(ooovsSJe,s5IsD)
local function KvYEVoXt(VWWD_P,zsMuNkv)local aXxi,Q18a7QTy=0,1
while VWWD_P~=0 and zsMuNkv~=0 do
local K5Rp6,GTIA=VWWD_P%s5IsD,zsMuNkv%s5IsD
aXxi=aXxi+ooovsSJe[K5Rp6][GTIA]*Q18a7QTy;VWWD_P=(VWWD_P-K5Rp6)/s5IsD
zsMuNkv=(zsMuNkv-GTIA)/s5IsD;Q18a7QTy=Q18a7QTy*s5IsD end
aXxi=aXxi+ (VWWD_P+zsMuNkv)*Q18a7QTy;return aXxi end;return KvYEVoXt end
local function IMUI10L(gdPUe)local _bxEn=aL_g(gdPUe,2^1)
local pcN_ceXY=slE5aDm2(function(_P)return
slE5aDm2(function(rq)return _bxEn(_P,rq)end)end)return aL_g(pcN_ceXY,2^ (gdPUe.n or 1))end;function sJYFQIP4.tobit(mo)return mo%2^32 end
sJYFQIP4.bxor=IMUI10L{[0]={[0]=0,[1]=1},[1]={[0]=1,[1]=0},n=4}local vPA=sJYFQIP4.bxor;function sJYFQIP4.bnot(I)return GJqd7gt-I end
local pUXZ6G4=sJYFQIP4.bnot
function sJYFQIP4.band(RAAJAsR,c1pjj7)return
((RAAJAsR+c1pjj7)-vPA(RAAJAsR,c1pjj7))/2 end;local mk=sJYFQIP4.band;function sJYFQIP4.bor(BMv,NQh8)return
GJqd7gt-mk(GJqd7gt-BMv,GJqd7gt-NQh8)end
local OeQex1U4=sJYFQIP4.bor;local i0cV9,EGD
function sJYFQIP4.rshift(P,bkTe)if bkTe<0 then return i0cV9(P,-bkTe)end;return Ogq0S2(P%
2^32/2^bkTe)end;EGD=sJYFQIP4.rshift
function sJYFQIP4.lshift(ohmPbyDd,D)
if D<0 then return EGD(ohmPbyDd,-D)end;return(ohmPbyDd*2^D)%2^32 end;i0cV9=sJYFQIP4.lshift
function sJYFQIP4.tohex(DfDLWkT,MTU8HP4d)MTU8HP4d=MTU8HP4d or 8;local hIM_cG0i
if
MTU8HP4d<=0 then if MTU8HP4d==0 then return''end;hIM_cG0i=true;MTU8HP4d=-MTU8HP4d end;DfDLWkT=mk(DfDLWkT,16^MTU8HP4d-1)return
('%0'..MTU8HP4d..
(hIM_cG0i and'X'or'x')):format(DfDLWkT)end;local VWiGCreH=sJYFQIP4.tohex
function sJYFQIP4.extract(jD,me,sgU5HAMG)sgU5HAMG=sgU5HAMG or 1;return mk(EGD(jD,me),2^
sgU5HAMG-1)end;local B_kkL=sJYFQIP4.extract
function sJYFQIP4.replace(FDydY,PEZ_,c,ElbTbcZG)ElbTbcZG=ElbTbcZG or 1
local r3=2^ElbTbcZG-1;PEZ_=mk(PEZ_,r3)local p=pUXZ6G4(i0cV9(r3,c))return mk(FDydY,p)+
i0cV9(PEZ_,c)end;local u=sJYFQIP4.replace
function sJYFQIP4.bswap(UiVYRok)local jvPsY9=mk(UiVYRok,0xff)
UiVYRok=EGD(UiVYRok,8)local tE=mk(UiVYRok,0xff)UiVYRok=EGD(UiVYRok,8)
local Bmuypm=mk(UiVYRok,0xff)UiVYRok=EGD(UiVYRok,8)local hW=mk(UiVYRok,0xff)
return i0cV9(
i0cV9(i0cV9(jvPsY9,8)+tE,8)+Bmuypm,8)+hW end;local EO6Y=sJYFQIP4.bswap;function sJYFQIP4.rrotate(iOcgdUx,kCwLIk)kCwLIk=kCwLIk%32
local _l=mk(iOcgdUx,2^kCwLIk-1)
return EGD(iOcgdUx,kCwLIk)+i0cV9(_l,32-kCwLIk)end
local i_053JPY=sJYFQIP4.rrotate
function sJYFQIP4.lrotate(rjQ,Euo0)return i_053JPY(rjQ,-Euo0)end;local l=sJYFQIP4.lrotate;sJYFQIP4.rol=sJYFQIP4.lrotate
sJYFQIP4.ror=sJYFQIP4.rrotate
function sJYFQIP4.arshift(LIV,vydlAbZ3)local BXxv5z=EGD(LIV,vydlAbZ3)
if LIV>=0x80000000 then BXxv5z=BXxv5z+i0cV9(2^vydlAbZ3-1,
32-vydlAbZ3)end;return BXxv5z end;local UK=sJYFQIP4.arshift
function sJYFQIP4.btest(mKLU,Him)return mk(mKLU,Him)~=0 end;sJYFQIP4.bit32={}
local function NzaICo(cPDhu)return(-1-cPDhu)%n8Cw3SR end;sJYFQIP4.bit32.bnot=NzaICo
local function k1X83nYm(UQnOS,tRWU,X2Zy_nb,...)local ITtw3N7E
if tRWU then UQnOS=UQnOS%n8Cw3SR;tRWU=tRWU%
n8Cw3SR;ITtw3N7E=vPA(UQnOS,tRWU)if X2Zy_nb then
ITtw3N7E=k1X83nYm(ITtw3N7E,X2Zy_nb,...)end;return ITtw3N7E elseif UQnOS then return UQnOS%n8Cw3SR else return 0 end end;sJYFQIP4.bit32.bxor=k1X83nYm
local function xxzxfj(yozOp,wxU,kOmS5sy,...)local CLSdD
if wxU then yozOp=yozOp%n8Cw3SR;wxU=wxU%
n8Cw3SR
CLSdD=((yozOp+wxU)-vPA(yozOp,wxU))/2;if kOmS5sy then CLSdD=xxzxfj(CLSdD,kOmS5sy,...)end
return CLSdD elseif yozOp then return yozOp%n8Cw3SR else return GJqd7gt end end;sJYFQIP4.bit32.band=xxzxfj
local function _ad1m4I(Fh,IlAPA,jLKMpQuK,...)local sUQpby
if IlAPA then Fh=Fh%n8Cw3SR
IlAPA=IlAPA%n8Cw3SR
sUQpby=GJqd7gt-mk(GJqd7gt-Fh,GJqd7gt-IlAPA)
if jLKMpQuK then sUQpby=_ad1m4I(sUQpby,jLKMpQuK,...)end;return sUQpby elseif Fh then return Fh%n8Cw3SR else return 0 end end;sJYFQIP4.bit32.bor=_ad1m4I;function sJYFQIP4.bit32.btest(...)
return xxzxfj(...)~=0 end;function sJYFQIP4.bit32.lrotate(mbA,_qPhpaFx)return
l(mbA%n8Cw3SR,_qPhpaFx)end
function sJYFQIP4.bit32.rrotate(zex,pPGcdu)return i_053JPY(
zex%n8Cw3SR,pPGcdu)end
function sJYFQIP4.bit32.lshift(rjp,cT2z)if cT2z>31 or cT2z<-31 then return 0 end;return i0cV9(rjp%
n8Cw3SR,cT2z)end
function sJYFQIP4.bit32.rshift(z,ke1tWps)
if ke1tWps>31 or ke1tWps<-31 then return 0 end;return EGD(z%n8Cw3SR,ke1tWps)end
function sJYFQIP4.bit32.arshift(gRFA,jX9a0tJX)gRFA=gRFA%n8Cw3SR
if jX9a0tJX>=0 then
if jX9a0tJX>31 then return
(gRFA>=0x80000000)and GJqd7gt or 0 else
local YFy4TGc=EGD(gRFA,jX9a0tJX)if gRFA>=0x80000000 then
YFy4TGc=YFy4TGc+i0cV9(2^jX9a0tJX-1,32-jX9a0tJX)end;return YFy4TGc end else return i0cV9(gRFA,-jX9a0tJX)end end
function sJYFQIP4.bit32.extract(YjpbYkCb,L1p7luJ,...)local eH=...or 1
if
L1p7luJ<0 or L1p7luJ>31 or eH<0 or L1p7luJ+eH>32 then error'out of range'end;YjpbYkCb=YjpbYkCb%n8Cw3SR;return B_kkL(YjpbYkCb,L1p7luJ,...)end
function sJYFQIP4.bit32.replace(WpOZ,fD2289,folfO,...)local vtsK=...or 1
if
folfO<0 or folfO>31 or vtsK<0 or folfO+vtsK>32 then error'out of range'end;WpOZ=WpOZ%n8Cw3SR;fD2289=fD2289%n8Cw3SR
return u(WpOZ,fD2289,folfO,...)end;sJYFQIP4.bit={}
function sJYFQIP4.bit.tobit(E1p4Mv)E1p4Mv=E1p4Mv%n8Cw3SR;if
E1p4Mv>=0x80000000 then E1p4Mv=E1p4Mv-n8Cw3SR end;return E1p4Mv end;local H1QsS=sJYFQIP4.bit.tobit;function sJYFQIP4.bit.tohex(IHap,...)return
VWiGCreH(IHap%n8Cw3SR,...)end
function sJYFQIP4.bit.bnot(rDvV)return H1QsS(pUXZ6G4(
rDvV%n8Cw3SR))end
local function rIMx(RX1L2q,bCBtWguf,q,...)
if q then return rIMx(rIMx(RX1L2q,bCBtWguf),q,...)elseif bCBtWguf then
return H1QsS(OeQex1U4(RX1L2q%
n8Cw3SR,bCBtWguf%n8Cw3SR))else return H1QsS(RX1L2q)end end;sJYFQIP4.bit.bor=rIMx
local function TiA(e1sXUN4f,x,VP,...)
if VP then
return TiA(TiA(e1sXUN4f,x),VP,...)elseif x then
return H1QsS(mk(e1sXUN4f%n8Cw3SR,x%n8Cw3SR))else return H1QsS(e1sXUN4f)end end;sJYFQIP4.bit.band=TiA
local function Y51P(IQwqq,Xcc4,fqw5,...)
if fqw5 then
return Y51P(Y51P(IQwqq,Xcc4),fqw5,...)elseif Xcc4 then
return H1QsS(vPA(IQwqq%n8Cw3SR,Xcc4%n8Cw3SR))else return H1QsS(IQwqq)end end;sJYFQIP4.bit.bxor=Y51P
function sJYFQIP4.bit.lshift(qnVfOeRE,YIiSKsxK)return H1QsS(i0cV9(qnVfOeRE%n8Cw3SR,
YIiSKsxK%32))end;function sJYFQIP4.bit.rshift(Ua,qeJtG)
return H1QsS(EGD(Ua%n8Cw3SR,qeJtG%32))end
function sJYFQIP4.bit.arshift(pdpNgBcZ,wV)return H1QsS(UK(pdpNgBcZ%n8Cw3SR,
wV%32))end;function sJYFQIP4.bit.rol(rLd,z8oF)
return H1QsS(l(rLd%n8Cw3SR,z8oF%32))end
function sJYFQIP4.bit.ror(DB6A7N,VhYX)return H1QsS(i_053JPY(DB6A7N%n8Cw3SR,
VhYX%32))end;function sJYFQIP4.bit.bswap(Ha7ErH)
return H1QsS(EO6Y(Ha7ErH%n8Cw3SR))end;return sJYFQIP4 end
