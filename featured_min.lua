#!/bin/sh
_=[[
	for name in luajit lua5.3 lua-5.3 lua5.2 lua-5.2 lua5.1 lua-5.1 lua; do
		: ${LUA:=$(command -v luajit)}
	done
	LUA_PATH='./?.lua;./?/init.lua;./lib/?.lua;./lib/?/init.lua;;'
	exec "$LUA" "$0" "$@"
	exit $?
]]_=nil
require("package").preload["gro"]=function(...)local mvi={}
local g4KV=require"package".loaded;local dT7iYDf4={}
local L={__newindex=function()end,__tostring=function()return"locked"end,__metatable=assert(dT7iYDf4)}setmetatable(dT7iYDf4,L)
assert(tostring(dT7iYDf4 =="locked"))local WRH9=true;local function cJoBcud(...)if WRH9 then WRH9=false;rawset(...)return true end
return false end;local e=true;local B6zKxgVs
local function O3_X(M7,v3,ihKb)if ihKb==nil then
return true end
if e and type(ihKb)=="string"then e=false;B6zKxgVs=ihKb
return true elseif B6zKxgVs==ihKb then return true end;return false end;local function DVs8kf2w(JGSK)
return(#JGSK>30)and
(JGSK:sub(1,20).."... ..."..JGSK:sub(-4,-1))or JGSK end
local vms5=getmetatable(_G)or{}
vms5.__newindex=function(rA5U,Uc06,lcBL)
if Uc06 =="_"and O3_X(_G,Uc06,lcBL)then return end;if g4KV[Uc06]==lcBL then
io.stderr:write("drop global write of module '"..tostring(Uc06).."'\n")return end;if Uc06 =="arg"then if
cJoBcud(_G,Uc06,lcBL)then return end end
error(("global env is read-only. Write of %q"):format(DVs8kf2w(Uc06)),2)end;vms5.__metatable=dT7iYDf4;setmetatable(_G,vms5)if getmetatable(_G)~=
dT7iYDf4 then
error("unable to setup global env to read-only",2)end;return{}end;require("gro")
require("package").preload["strict"]=function(...)
local DHPxI,dx,RRuSHnxf,mcYOuT=debug.getinfo,error,rawset,rawget;local Rr=getmetatable(_G)
if Rr==nil then Rr={}setmetatable(_G,Rr)end;Rr.__declared={}local function scRP0()local AI0R2TQ6=DHPxI(3,"S")return
AI0R2TQ6 and AI0R2TQ6.what or"C"end
Rr.__newindex=function(yA,XmVolesU,eZ0l3ch)
if not
Rr.__declared[XmVolesU]then local W_63_9=scRP0()if W_63_9 ~="main"and W_63_9 ~="C"then
dx(
"assignment to undeclared variable '"..XmVolesU.."'",2)end
Rr.__declared[XmVolesU]=true end;RRuSHnxf(yA,XmVolesU,eZ0l3ch)end
Rr.__index=function(h9dyA_4T,oh)if not Rr.__declared[oh]and scRP0()~="C"then
dx("variable '"..oh..
"' is not declared",2)end
return mcYOuT(h9dyA_4T,oh)end end;require("strict")
require("package").preload["i"]=function(...)
local DZXGTh={}DZXGTh._VERSION="2.0"local Su9Koz={}local Uk7e={}local function KwQCk_G(PEqsd)local iSj
pcall(function()iSj=require(PEqsd)end)return iSj end
local function ptZa(iXxD6s)if Su9Koz[iXxD6s]then return
Su9Koz[iXxD6s]end
local function oiY(HLXS0Q_)
if type(HLXS0Q_)~="table"or
type(HLXS0Q_.common)~="table"or
not HLXS0Q_.common.class or
not HLXS0Q_.common.instance then
assert(type(HLXS0Q_)=="table")
assert(type(HLXS0Q_.common)=="table")assert(HLXS0Q_.common.class)
assert(HLXS0Q_.common.instance)return false end;return HLXS0Q_.common end;local FsYIVlkf=oiY(KwQCk_G(iXxD6s.."-featured"))or
oiY(KwQCk_G(iXxD6s))return FsYIVlkf end;function DZXGTh:need(Kw)return ptZa(Kw)end
function DZXGTh:requireany(...)local nvaIsNv7=
type(...)=="table"and...or{...}for vDnoL55,xlAK in ipairs(nvaIsNv7)do
local zr1y=ptZa(xlAK)if zr1y then return zr1y end end
error("requireany: no implementation found",2)return false end
function DZXGTh:register(Hs,jk)
assert(jk,"register: argument #2 is invalid")assert(jk.class)assert(jk.instance)
Uk7e[#Uk7e+1]=Hs;Su9Koz[Hs]=jk;return jk end;function DZXGTh:unregister(qzSFyIO)end;function DZXGTh:available()return Uk7e end
return DZXGTh end
require("package").preload["secs"]=function(...)local Z65={}function Z65:__index(FT)return
self.__baseclass[FT]end
local umyCNfj=setmetatable({__baseclass={}},Z65)
function umyCNfj:new(...)local YVLXYq={}YVLXYq.__baseclass=self
setmetatable(YVLXYq,getmetatable(self))if YVLXYq.init then YVLXYq:init(...)end;return YVLXYq end;return umyCNfj end
require("package").preload["secs-featured"]=function(...)
local bJfct=require"secs"local OhuFpq_N={}
function OhuFpq_N.class(Dzg,_4O,C)C=C or bJfct;_4O=_4O or{}_4O.__baseclass=C;return
setmetatable(_4O,getmetatable(C))end;function OhuFpq_N.instance(bJfct,...)return bJfct:new(...)end
OhuFpq_N.__BY="secs"
pcall(function()require("i"):register("secs",OhuFpq_N)end)return{common=OhuFpq_N}end
require("package").preload["middleclass"]=function(...)
local fLI2zRe={_VERSION='middleclass v3.0.1',_DESCRIPTION='Object Orientation for Lua',_URL='https://github.com/kikito/middleclass',_LICENSE=[[
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
local function _Fr2YU(JD)local u=JD.__instanceDict;u.__index=u;local pzDMZwG=JD.super
if pzDMZwG then
local XPoQB=pzDMZwG.static;setmetatable(u,pzDMZwG.__instanceDict)
setmetatable(JD.static,{__index=function(XxJ,o5sms)return
u[o5sms]or XPoQB[o5sms]end})else
setmetatable(JD.static,{__index=function(JQi1jg,wVzn)return u[wVzn]end})end end
local function Xfn(pE)
setmetatable(pE,{__tostring=function()return"class "..pE.name end,__index=pE.static,__newindex=pE.__instanceDict,__call=function(RSjapQ,...)return
RSjapQ:new(...)end})end
local function UEbsw(QJf,zC)local pfZ3SPy_={name=QJf,super=zC,static={},__mixins={},__instanceDict={}}
pfZ3SPy_.subclasses=setmetatable({},{__mode="k"})_Fr2YU(pfZ3SPy_)Xfn(pfZ3SPy_)return pfZ3SPy_ end
local function UlikV(pDNa2ox6,Do6yo7nm)
return
function(...)local y06X3k=pDNa2ox6.super[Do6yo7nm]
assert(type(y06X3k)=='function',
tostring(pDNa2ox6).." doesn't implement metamethod '"..Do6yo7nm.."'")return y06X3k(...)end end;local function JtAjijkG(ivnJjrA)
for d3fMjkg,el in ipairs(ivnJjrA.__metamethods)do ivnJjrA[el]=UlikV(ivnJjrA,el)end end
local function s(Wu_uIt,w)Wu_uIt.initialize=function(sgeP,...)return
w.initialize(sgeP,...)end end
local function YAtG_LV3(CM,Qlmlet)
assert(type(Qlmlet)=='table',"mixin must be a table")
for _RkGFh6,hw18 in pairs(Qlmlet)do if _RkGFh6 ~="included"and _RkGFh6 ~="static"then
CM[_RkGFh6]=hw18 end end;if Qlmlet.static then
for nvCiFt7r,xSebv5Jc in pairs(Qlmlet.static)do CM.static[nvCiFt7r]=xSebv5Jc end end
if
type(Qlmlet.included)=="function"then Qlmlet:included(CM)end;CM.__mixins[Qlmlet]=true end;local LfEJbh_=UEbsw("Object",nil)
LfEJbh_.static.__metamethods={'__add','__call','__concat','__div','__ipairs','__le','__len','__lt','__mod','__mul','__pairs','__pow','__sub','__tostring','__unm'}
function LfEJbh_.static:allocate()
assert(type(self)=='table',"Make sure that you are using 'Class:allocate' instead of 'Class.allocate'")return setmetatable({class=self},self.__instanceDict)end;function LfEJbh_.static:new(...)local mMp=self:allocate()
mMp:initialize(...)return mMp end
function LfEJbh_.static:subclass(rDtVf)
assert(
type(self)=='table',"Make sure that you are using 'Class:subclass' instead of 'Class.subclass'")
assert(type(rDtVf)=="string","You must provide a name(string) for your class")local vj=UEbsw(rDtVf,self)JtAjijkG(vj)s(vj,self)
self.subclasses[vj]=true;self:subclassed(vj)return vj end;function LfEJbh_.static:subclassed(z)end
function LfEJbh_.static:isSubclassOf(Zg)
return
type(Zg)==
'table'and type(self)=='table'and
type(self.super)=='table'and
(self.super==Zg or

type(self.super.isSubclassOf)=='function'and self.super:isSubclassOf(Zg))end
function LfEJbh_.static:include(...)
assert(type(self)=='table',"Make sure you that you are using 'Class:include' instead of 'Class.include'")for ykRppH,WQ6 in ipairs({...})do YAtG_LV3(self,WQ6)end;return self end
function LfEJbh_.static:includes(y36Aetn)
return


type(y36Aetn)=='table'and type(self)=='table'and type(self.__mixins)=='table'and
(self.__mixins[y36Aetn]or type(self.super)=='table'and
type(self.super.includes)=='function'and
self.super:includes(y36Aetn))end;function LfEJbh_:initialize()end;function LfEJbh_:__tostring()return
"instance of "..tostring(self.class)end
function LfEJbh_:isInstanceOf(iPL3B4cr)
return

type(self)=='table'and type(self.class)=='table'and
type(iPL3B4cr)=='table'and
(iPL3B4cr==self.class or

type(iPL3B4cr.isSubclassOf)=='function'and self.class:isSubclassOf(iPL3B4cr))end
function fLI2zRe.class(GI2hz6SK,Oh,...)Oh=Oh or LfEJbh_;return Oh:subclass(GI2hz6SK,...)end;fLI2zRe.Object=LfEJbh_
setmetatable(fLI2zRe,{__call=function(PG,...)return fLI2zRe.class(...)end})return fLI2zRe end
require("package").preload["middleclass-featured"]=function(...)
local n={_VERSION='middleclass v3.0.0',_DESCRIPTION='Object Orientation for Lua',_LICENSE=[[
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
local function O(OO)local y=OO.__instanceDict;y.__index=y;local cR6rJlAl=OO.super
if cR6rJlAl then
local M6ilzGJ=cR6rJlAl.static;setmetatable(y,cR6rJlAl.__instanceDict)
setmetatable(OO.static,{__index=function(iW6CD,wZdg)return
y[wZdg]or M6ilzGJ[wZdg]end})else
setmetatable(OO.static,{__index=function(BaX,SJsW11k)return y[SJsW11k]end})end end
local function N5UjTN(Ki1HJT)
setmetatable(Ki1HJT,{__tostring=function()return"class "..Ki1HJT.name end,__index=Ki1HJT.static,__newindex=Ki1HJT.__instanceDict,__call=function(wjim8xCV,...)return
wjim8xCV:new(...)end})end
local function qLH5(EQLam,qTDt)local v={name=EQLam,super=qTDt,static={},__mixins={},__instanceDict={}}
v.subclasses=setmetatable({},{__mode="k"})O(v)N5UjTN(v)return v end
local function tE(Ta,u)
return
function(...)local nArcvQl=Ta.super[u]
assert(type(nArcvQl)=='function',tostring(Ta)..
" doesn't implement metamethod '"..u.."'")return nArcvQl(...)end end;local function VcV0EuD(h6Ub7U)
for Gm,YKA7cU in ipairs(h6Ub7U.__metamethods)do h6Ub7U[YKA7cU]=tE(h6Ub7U,YKA7cU)end end
local function pX4gCR(mCsewfX,yY)mCsewfX.initialize=function(Xf,...)return
yY.initialize(Xf,...)end end
local function gad4ZcL(UlFdiZ7v,UwFeA)
assert(type(UwFeA)=='table',"mixin must be a table")
for JQgI,N in pairs(UwFeA)do if JQgI~="included"and JQgI~="static"then
UlFdiZ7v[JQgI]=N end end
if UwFeA.static then for fs52REi,PUNkgaiM in pairs(UwFeA.static)do
UlFdiZ7v.static[fs52REi]=PUNkgaiM end end;if type(UwFeA.included)=="function"then
UwFeA:included(UlFdiZ7v)end
UlFdiZ7v.__mixins[UwFeA]=true end;local dk=qLH5("Object",nil)
dk.static.__metamethods={'__add','__call','__concat','__div','__le','__lt','__mod','__mul','__pow','__sub','__tostring','__unm'}
function dk.static:allocate()
assert(type(self)=='table',"Make sure that you are using 'Class:allocate' instead of 'Class.allocate'")return setmetatable({class=self},self.__instanceDict)end;function dk.static:new(...)local s6FbB=self:allocate()s6FbB:initialize(...)return
s6FbB end
function dk.static:subclass(X)
assert(
type(self)=='table',"Make sure that you are using 'Class:subclass' instead of 'Class.subclass'")
assert(type(X)=="string","You must provide a name(string) for your class")local dc61=qLH5(X,self)VcV0EuD(dc61)pX4gCR(dc61,self)
self.subclasses[dc61]=true;self:subclassed(dc61)return dc61 end;function dk.static:subclassed(aguhyl)end
function dk.static:isSubclassOf(p)
return

type(p)=='table'and
type(self)=='table'and type(self.super)=='table'and
(self.super==p or type(self.super.isSubclassOf)=='function'and
self.super:isSubclassOf(p))end
function dk.static:include(...)
assert(type(self)=='table',"Make sure you that you are using 'Class:include' instead of 'Class.include'")for gOPDv,aSdZU3 in ipairs({...})do gad4ZcL(self,aSdZU3)end
return self end
function dk.static:includes(YKDL)
return

type(YKDL)=='table'and type(self)=='table'and type(self.__mixins)=='table'and
(
self.__mixins[YKDL]or
type(self.super)=='table'and
type(self.super.includes)=='function'and self.super:includes(YKDL))end;function dk:initialize()end;function dk:__tostring()
return"instance of "..tostring(self.class)end
function dk:isInstanceOf(oFyb6OLp)
return

type(self)=='table'and
type(self.class)=='table'and type(oFyb6OLp)=='table'and
(oFyb6OLp==self.class or

type(oFyb6OLp.isSubclassOf)=='function'and self.class:isSubclassOf(oFyb6OLp))end
function n.class(oGdh_mv,WjvvK,...)WjvvK=WjvvK or dk;return WjvvK:subclass(oGdh_mv,...)end;n.Object=dk
setmetatable(n,{__call=function(TASVwBgU,...)return n.class(...)end})local E={}
if type(n.common)=="table"and
type(n.common.class)=="function"and
type(n.common.instannce)=="function"then E=n.common else
function E.class(KjUncMB,XkT,c3dr)
local NGH=n.class(KjUncMB,c3dr)XkT=XkT or{}for tIc,MD2O in pairs(XkT)do NGH[tIc]=MD2O end;if XkT.init then
NGH.initialize=XkT.init end;return NGH end;function E.instance(HQ,...)return HQ:new(...)end end;if E.__BY==nil then E.__BY="middleclass"end
pcall(function()
require("classcommons2"):register("middleclass",E)end)return{common=E}end
require("package").preload["30log"]=function(...)
local cng,lE,nI2F0id,N4aMD_P,pCi=assert,pairs,type,tostring,setmetatable
local NzeoQJ,AwGfFV,wCRY,d0uKSVw1={},pCi({},{__mode='k'}),pCi({},{__mode='k'})local function lNOqUk8(ypDndT8,MV65)
cng(wCRY[ypDndT8],('Wrong method call. Expected class:%s.'):format(MV65))end
local function YAnZNei(Y3D66Ym9,q,PhJ)
Y3D66Ym9=Y3D66Ym9 or{}local h=q or{}
for j2K,r8hgwQ in lE(Y3D66Ym9)do
if PhJ and nI2F0id(r8hgwQ)==PhJ then
h[j2K]=r8hgwQ elseif not PhJ then if nI2F0id(r8hgwQ)=='table'and j2K~="__index"then
h[j2K]=YAnZNei(r8hgwQ)else h[j2K]=r8hgwQ end end end;return h end
local function h8YWR44E(_6U,...)lNOqUk8(_6U,'new(...) or class(...)')local GLSzBQs={class=_6U}
AwGfFV[GLSzBQs]=N4aMD_P(GLSzBQs)pCi(GLSzBQs,_6U)if _6U.init then
if nI2F0id(_6U.init)=='table'then
YAnZNei(_6U.init,GLSzBQs)else _6U.init(GLSzBQs,...)end end;return GLSzBQs end
local function VF(c,xg,Id2KoP_G)lNOqUk8(c,'extend(...)')local Y2or={}wCRY[Y2or]=N4aMD_P(Y2or)
YAnZNei(Id2KoP_G,YAnZNei(c,Y2or))
Y2or.name,Y2or.__index,Y2or.super=Id2KoP_G and Id2KoP_G.name or xg,Y2or,c;return pCi(Y2or,c)end
NzeoQJ={__call=function(zN8ASHV5,...)return zN8ASHV5:new(...)end,__tostring=function(iju,...)if AwGfFV[iju]then
return("instance of '%s' (%s)"):format(
rawget(iju.class,'name')or'?',AwGfFV[iju])end
return
wCRY[iju]and("class '%s' (%s)"):format(
rawget(iju,'name')or'?',wCRY[iju])or iju end}wCRY[NzeoQJ]=N4aMD_P(NzeoQJ)
pCi(NzeoQJ,{__tostring=NzeoQJ.__tostring})
local fTrMe={isClass=function(XsWgh,l4Hdz)local NSXCgSH=not not wCRY[XsWgh]if l4Hdz then return NSXCgSH and
(XsWgh.super==l4Hdz)end;return NSXCgSH end,isInstance=function(Wq,SbOQ)local IiuHGo=
not not AwGfFV[Wq]if SbOQ then return
IiuHGo and(Wq.class==SbOQ)end;return IiuHGo end}
d0uKSVw1=function(cGqxtYr,bgJFKeeZ)local yu9fg0nN=YAnZNei(bgJFKeeZ)
yu9fg0nN.mixins=pCi({},{__mode='k'})wCRY[yu9fg0nN]=N4aMD_P(yu9fg0nN)
yu9fg0nN.name,yu9fg0nN.__tostring,yu9fg0nN.__call=
cGqxtYr or yu9fg0nN.name,NzeoQJ.__tostring,NzeoQJ.__call
yu9fg0nN.include=function(wgx,zlU7X)lNOqUk8(wgx,'include(mixin)')
wgx.mixins[zlU7X]=true;return YAnZNei(zlU7X,wgx,'function')end
yu9fg0nN.new,yu9fg0nN.extend,yu9fg0nN.__index,yu9fg0nN.includes=h8YWR44E,VF,yu9fg0nN,function(t,f6qbO)
lNOqUk8(t,'includes(mixin)')return not
not(t.mixins[f6qbO]or
(t.super and t.super:includes(f6qbO)))end
yu9fg0nN.extends=function(kk,fTrMe)lNOqUk8(kk,'extends(class)')local QrubIAv=kk
repeat
QrubIAv=QrubIAv.super until(QrubIAv==fTrMe or QrubIAv==nil)return fTrMe and(QrubIAv==fTrMe)end;return pCi(yu9fg0nN,NzeoQJ)end;fTrMe._DESCRIPTION='30 lines library for object orientation in Lua'
fTrMe._VERSION='30log v1.0.0'fTrMe._URL='http://github.com/Yonaba/30log'
fTrMe._LICENSE='MIT LICENSE <http://www.opensource.org/licenses/mit-license.php>'return
pCi(fTrMe,{__call=function(bLHDW,...)return d0uKSVw1(...)end})end
require("package").preload["30log-featured"]=function(...)
local YjFd7b=require"30log"local jZgPYb={}
jZgPYb.class=function(IN69pa5,UOWJ,WtalJw)
local JYrf2=YjFd7b():extends(WtalJw):extends(UOWJ)
JYrf2.__init=UOWJ.init or(WtalJw or{}).init;JYrf2.__name=IN69pa5;return JYrf2 end
jZgPYb.instance=function(YjFd7b,...)return YjFd7b:new(...)end;jZgPYb.__BY="30log"local zN2={common=jZgPYb}
pcall(function()
require("i"):register("30log",jZgPYb)end)return zN2 end
require("package").preload["compat_env"]=function(...)
local KHDOUlRY={_TYPE='module',_NAME='compat_env',_VERSION='0.2.2.20120406'}
local function I0JvPpn(OVx_mN,lB)local byE=lB or'bt'
local bITCI=OVx_mN and#OVx_mN>0 and OVx_mN:byte(1)==27
if bITCI and not byE:match'b'then return nil,
("attempt to load a binary chunk (mode is '%s')"):format(lB)elseif
not bITCI and not byE:match't'then return nil,
("attempt to load a text chunk (mode is '%s')"):format(lB)end;return true end;local Ce4ZE=pcall(load,'')
if Ce4ZE then KHDOUlRY.load=_G.load
KHDOUlRY.loadfile=_G.loadfile else
function KHDOUlRY.load(K,F5dtVpnN,kxeBp,a)local kQ
if type(K)=='string'then local EE9LAE=K
local iVx,eg=I0JvPpn(EE9LAE,kxeBp)if not iVx then return iVx,eg end;local eg
kQ,eg=loadstring(EE9LAE,F5dtVpnN)if not kQ then return kQ,eg end elseif type(K)=='function'then local AQviNt=K
if
(kxeBp or'bt')~='bt'then local NviN0i=K()local BlMQce,o=I0JvPpn(NviN0i,kxeBp)
if not BlMQce then return BlMQce,o end
AQviNt=function()
if NviN0i then local dpRE=NviN0i;NviN0i=nil;return dpRE else return K()end end end;local T6;kQ,T6=load(AQviNt,F5dtVpnN)if not kQ then return kQ,T6 end else
error(("bad argument #1 to 'load' (function expected, got %s)"):format(type(K)),2)end;if a then setfenv(kQ,a)end;return kQ end
function KHDOUlRY.loadfile(fEiXwWq,r3JzMga6,Tuyw)
if(r3JzMga6 or'bt')~='bt'then local FYLcr2nu
local ioS69,AiP=io.open(fEiXwWq,'rb')if not ioS69 then return ioS69,AiP end;local function S2jwpoi()local u0riyU
u0riyU,FYLcr2nu=ioS69:read(4096)return u0riyU end
local _WX9u,AiP=KHDOUlRY.load(S2jwpoi,fEiXwWq and
'@'..fEiXwWq,r3JzMga6,Tuyw)ioS69:close()if not _WX9u then return _WX9u,AiP end;if FYLcr2nu then
return nil,FYLcr2nu end;return _WX9u else local UH,WNph=loadfile(fEiXwWq)
if not UH then return UH,WNph end;if Tuyw then setfenv(UH,Tuyw)end;return UH end end end
if _G.setfenv then KHDOUlRY.setfenv=_G.setfenv;KHDOUlRY.getfenv=_G.getfenv else
local function ytF(gRm)local LPX0,g
local _l=0;local qao
repeat _l=_l+1;LPX0,g=debug.getupvalue(gRm,_l)
if LPX0 ==''then qao=true end until LPX0 =='_ENV'or LPX0 ==nil
if LPX0 ~='_ENV'then _l=nil;if qao then
error("upvalues not readable in Lua 5.2 when debug info missing",3)end end;return(LPX0 =='_ENV')and _l,g,qao end
local function d(ipUPIzc,N8)
if type(ipUPIzc)=='number'then
if ipUPIzc<0 then
error(("bad argument #1 to '%s' (level must be non-negative)"):format(N8),3)elseif ipUPIzc<1 then
error("thread environments unsupported in Lua 5.2",3)end;ipUPIzc=debug.getinfo(ipUPIzc+2,'f').func elseif
type(ipUPIzc)~='function'then
error(("bad argument #1 to '%s' (number expected, got %s)"):format(type(N8,ipUPIzc)),2)end;return ipUPIzc end
function KHDOUlRY.setfenv(Gzk,J7nsK)local Gzk=d(Gzk,'setfenv')local dXbd,vQj,sVBxyy=ytF(Gzk)
if dXbd then debug.upvaluejoin(Gzk,dXbd,function()return
dXbd end,1)
debug.setupvalue(Gzk,dXbd,J7nsK)else local N9d=debug.getinfo(Gzk,'S').what;if
N9d~='Lua'and N9d~='main'then
error("'setfenv' cannot change environment of given object",2)end end;return Gzk end
function KHDOUlRY.getfenv(S7)if S7 ==0 or S7 ==nil then return _G end
local S7=d(S7,'setfenv')local bJtvRSR,aBhZK5=ytF(S7)if not bJtvRSR then return _G end;return aBhZK5 end end;return KHDOUlRY end
require("package").preload["hump.class"]=function(...)
local function Jz8JUscj(n_lv,UYQF,WXx)
if UYQF==nil then return n_lv elseif
type(UYQF)~='table'then return UYQF elseif WXx[UYQF]then return WXx[UYQF]end;WXx[UYQF]=n_lv;for W4EuxJXi,BlYNd61h in pairs(UYQF)do W4EuxJXi=Jz8JUscj({},W4EuxJXi,WXx)
if
n_lv[W4EuxJXi]==nil then n_lv[W4EuxJXi]=Jz8JUscj({},BlYNd61h,WXx)end end;return
n_lv end
local function O(XDPndG,sJYFQIP4)return Jz8JUscj(XDPndG,sJYFQIP4,{})end;local function tGmbAgE(Ogq0S2)
return setmetatable(O({},Ogq0S2),getmetatable(Ogq0S2))end
local function oU_r(n8Cw3SR)
local GJqd7gt=n8Cw3SR.__includes or{}if getmetatable(GJqd7gt)then GJqd7gt={GJqd7gt}end;for slE5aDm2,aL_g in
ipairs(GJqd7gt)do if type(aL_g)=="string"then aL_g=_G[aL_g]end
O(n8Cw3SR,aL_g)end
n8Cw3SR.__index=n8Cw3SR
n8Cw3SR.init=n8Cw3SR.init or n8Cw3SR[1]or function()end;n8Cw3SR.include=n8Cw3SR.include or O
n8Cw3SR.clone=n8Cw3SR.clone or tGmbAgE;return
setmetatable(n8Cw3SR,{__call=function(IMUI10L,...)local vPA=setmetatable({},IMUI10L)vPA:init(...)
return vPA end})end
if class_commons~=false and not common then common={}function common.class(pUXZ6G4,mk,OeQex1U4)return
oU_r{__includes={mk,OeQex1U4}}end;function common.instance(i0cV9,...)return
i0cV9(...)end end;return
setmetatable({new=oU_r,include=O,clone=tGmbAgE},{__call=function(EGD,...)return oU_r(...)end})end
require("package").preload["bit.numberlua"]=function(...)
local VWiGCreH={_TYPE='module',_NAME='bit.numberlua',_VERSION='0.3.1.20120131'}local B_kkL=math.floor;local u=2^32;local EO6Y=u-1
local function i_053JPY(GTIA)local gdPUe={}
local _bxEn=setmetatable({},gdPUe)
function gdPUe:__index(pcN_ceXY)local _P=GTIA(pcN_ceXY)_bxEn[pcN_ceXY]=_P;return _P end;return _bxEn end
local function l(rq,mo)
local function I(RAAJAsR,c1pjj7)local BMv,NQh8=0,1
while RAAJAsR~=0 and c1pjj7 ~=0 do local P,bkTe=RAAJAsR%mo,c1pjj7%mo;BMv=
BMv+rq[P][bkTe]*NQh8
RAAJAsR=(RAAJAsR-P)/mo;c1pjj7=(c1pjj7-bkTe)/mo;NQh8=NQh8*mo end;BMv=BMv+ (RAAJAsR+c1pjj7)*NQh8;return BMv end;return I end
local function UK(ohmPbyDd)local D=l(ohmPbyDd,2^1)
local DfDLWkT=i_053JPY(function(MTU8HP4d)return
i_053JPY(function(hIM_cG0i)return D(MTU8HP4d,hIM_cG0i)end)end)return l(DfDLWkT,2^ (ohmPbyDd.n or 1))end;function VWiGCreH.tobit(jD)return jD%2^32 end
VWiGCreH.bxor=UK{[0]={[0]=0,[1]=1},[1]={[0]=1,[1]=0},n=4}local NzaICo=VWiGCreH.bxor;function VWiGCreH.bnot(me)return EO6Y-me end
local k1X83nYm=VWiGCreH.bnot
function VWiGCreH.band(sgU5HAMG,FDydY)return
((sgU5HAMG+FDydY)-NzaICo(sgU5HAMG,FDydY))/2 end;local xxzxfj=VWiGCreH.band;function VWiGCreH.bor(PEZ_,c)return
EO6Y-xxzxfj(EO6Y-PEZ_,EO6Y-c)end;local _ad1m4I=VWiGCreH.bor
local H1QsS,rIMx
function VWiGCreH.rshift(ElbTbcZG,r3)if r3 <0 then return H1QsS(ElbTbcZG,-r3)end;return B_kkL(ElbTbcZG%
2^32/2^r3)end;rIMx=VWiGCreH.rshift
function VWiGCreH.lshift(p,UiVYRok)
if UiVYRok<0 then return rIMx(p,-UiVYRok)end;return(p*2^UiVYRok)%2^32 end;H1QsS=VWiGCreH.lshift
function VWiGCreH.tohex(jvPsY9,tE)tE=tE or 8;local Bmuypm;if tE<=0 then
if tE==0 then return''end;Bmuypm=true;tE=-tE end
jvPsY9=xxzxfj(jvPsY9,16^tE-1)return
('%0'..tE.. (Bmuypm and'X'or'x')):format(jvPsY9)end;local TiA=VWiGCreH.tohex
function VWiGCreH.extract(hW,iOcgdUx,kCwLIk)kCwLIk=kCwLIk or 1;return xxzxfj(rIMx(hW,iOcgdUx),2^
kCwLIk-1)end;local Y51P=VWiGCreH.extract
function VWiGCreH.replace(_l,rjQ,Euo0,LIV)LIV=LIV or 1;local vydlAbZ3=2^LIV-1
rjQ=xxzxfj(rjQ,vydlAbZ3)local BXxv5z=k1X83nYm(H1QsS(vydlAbZ3,Euo0))return xxzxfj(_l,BXxv5z)+
H1QsS(rjQ,Euo0)end;local ichL=VWiGCreH.replace
function VWiGCreH.bswap(mKLU)local Him=xxzxfj(mKLU,0xff)
mKLU=rIMx(mKLU,8)local cPDhu=xxzxfj(mKLU,0xff)mKLU=rIMx(mKLU,8)
local UQnOS=xxzxfj(mKLU,0xff)mKLU=rIMx(mKLU,8)local tRWU=xxzxfj(mKLU,0xff)
return H1QsS(
H1QsS(H1QsS(Him,8)+cPDhu,8)+UQnOS,8)+tRWU end;local NOK=VWiGCreH.bswap
function VWiGCreH.rrotate(X2Zy_nb,ITtw3N7E)ITtw3N7E=ITtw3N7E%32;local yozOp=xxzxfj(X2Zy_nb,
2^ITtw3N7E-1)return rIMx(X2Zy_nb,ITtw3N7E)+
H1QsS(yozOp,32-ITtw3N7E)end;local Alv=VWiGCreH.rrotate
function VWiGCreH.lrotate(wxU,kOmS5sy)return Alv(wxU,-kOmS5sy)end;local YeLO2=VWiGCreH.lrotate;VWiGCreH.rol=VWiGCreH.lrotate
VWiGCreH.ror=VWiGCreH.rrotate
function VWiGCreH.arshift(CLSdD,Fh)local IlAPA=rIMx(CLSdD,Fh)if CLSdD>=0x80000000 then IlAPA=IlAPA+
H1QsS(2^Fh-1,32-Fh)end;return IlAPA end;local CkrmO=VWiGCreH.arshift;function VWiGCreH.btest(jLKMpQuK,sUQpby)
return xxzxfj(jLKMpQuK,sUQpby)~=0 end;VWiGCreH.bit32={}local function ooovsSJe(mbA)
return(-1-mbA)%u end;VWiGCreH.bit32.bnot=ooovsSJe
local function s5IsD(_qPhpaFx,zex,pPGcdu,...)local rjp
if zex then _qPhpaFx=
_qPhpaFx%u;zex=zex%u;rjp=NzaICo(_qPhpaFx,zex)if pPGcdu then
rjp=s5IsD(rjp,pPGcdu,...)end;return rjp elseif _qPhpaFx then return _qPhpaFx%u else return 0 end end;VWiGCreH.bit32.bxor=s5IsD
local function KvYEVoXt(cT2z,z,ke1tWps,...)local gRFA
if z then cT2z=cT2z%u;z=z%u;gRFA=((cT2z+z)-
NzaICo(cT2z,z))/2;if ke1tWps then
gRFA=KvYEVoXt(gRFA,ke1tWps,...)end;return gRFA elseif cT2z then return cT2z%u else return EO6Y end end;VWiGCreH.bit32.band=KvYEVoXt
local function VWWD_P(jX9a0tJX,YFy4TGc,YjpbYkCb,...)local L1p7luJ
if YFy4TGc then jX9a0tJX=jX9a0tJX%u;YFy4TGc=
YFy4TGc%u
L1p7luJ=EO6Y-xxzxfj(EO6Y-jX9a0tJX,EO6Y-YFy4TGc)
if YjpbYkCb then L1p7luJ=VWWD_P(L1p7luJ,YjpbYkCb,...)end;return L1p7luJ elseif jX9a0tJX then return jX9a0tJX%u else return 0 end end;VWiGCreH.bit32.bor=VWWD_P;function VWiGCreH.bit32.btest(...)return
KvYEVoXt(...)~=0 end;function VWiGCreH.bit32.lrotate(eH,WpOZ)return
YeLO2(eH%u,WpOZ)end;function VWiGCreH.bit32.rrotate(fD2289,folfO)return
Alv(fD2289%u,folfO)end;function VWiGCreH.bit32.lshift(vtsK,E1p4Mv)if E1p4Mv>
31 or E1p4Mv<-31 then return 0 end;return
H1QsS(vtsK%u,E1p4Mv)end;function VWiGCreH.bit32.rshift(IHap,rDvV)if
rDvV>31 or rDvV<-31 then return 0 end
return rIMx(IHap%u,rDvV)end
function VWiGCreH.bit32.arshift(RX1L2q,bCBtWguf)RX1L2q=
RX1L2q%u
if bCBtWguf>=0 then
if bCBtWguf>31 then return
(RX1L2q>=0x80000000)and EO6Y or 0 else local q=rIMx(RX1L2q,bCBtWguf)if RX1L2q>=
0x80000000 then
q=q+H1QsS(2^bCBtWguf-1,32-bCBtWguf)end;return q end else return H1QsS(RX1L2q,-bCBtWguf)end end
function VWiGCreH.bit32.extract(e1sXUN4f,x,...)local VP=...or 1;if
x<0 or x>31 or VP<0 or x+VP>32 then error'out of range'end;e1sXUN4f=e1sXUN4f%u;return
Y51P(e1sXUN4f,x,...)end
function VWiGCreH.bit32.replace(IQwqq,Xcc4,fqw5,...)local qnVfOeRE=...or 1
if
fqw5 <0 or fqw5 >31 or qnVfOeRE<0 or fqw5+qnVfOeRE>32 then error'out of range'end;IQwqq=IQwqq%u;Xcc4=Xcc4%u;return ichL(IQwqq,Xcc4,fqw5,...)end;VWiGCreH.bit={}
function VWiGCreH.bit.tobit(YIiSKsxK)YIiSKsxK=YIiSKsxK%u;if
YIiSKsxK>=0x80000000 then YIiSKsxK=YIiSKsxK-u end;return YIiSKsxK end;local zsMuNkv=VWiGCreH.bit.tobit;function VWiGCreH.bit.tohex(Ua,...)
return TiA(Ua%u,...)end;function VWiGCreH.bit.bnot(qeJtG)return
zsMuNkv(k1X83nYm(qeJtG%u))end
local function aXxi(pdpNgBcZ,wV,rLd,...)
if rLd then return
aXxi(aXxi(pdpNgBcZ,wV),rLd,...)elseif wV then
return zsMuNkv(_ad1m4I(pdpNgBcZ%u,wV%u))else return zsMuNkv(pdpNgBcZ)end end;VWiGCreH.bit.bor=aXxi
local function Q18a7QTy(z8oF,DB6A7N,VhYX,...)
if VhYX then return
Q18a7QTy(Q18a7QTy(z8oF,DB6A7N),VhYX,...)elseif DB6A7N then
return zsMuNkv(xxzxfj(z8oF%u,DB6A7N%u))else return zsMuNkv(z8oF)end end;VWiGCreH.bit.band=Q18a7QTy
local function K5Rp6(Ha7ErH,rjU95v,sxBl,...)
if sxBl then return
K5Rp6(K5Rp6(Ha7ErH,rjU95v),sxBl,...)elseif rjU95v then return
zsMuNkv(NzaICo(Ha7ErH%u,rjU95v%u))else return zsMuNkv(Ha7ErH)end end;VWiGCreH.bit.bxor=K5Rp6;function VWiGCreH.bit.lshift(m,nD4LhX6z)return
zsMuNkv(H1QsS(m%u,nD4LhX6z%32))end
function VWiGCreH.bit.rshift(iN,Lq)return zsMuNkv(rIMx(
iN%u,Lq%32))end;function VWiGCreH.bit.arshift(s9tW,R61K)
return zsMuNkv(CkrmO(s9tW%u,R61K%32))end;function VWiGCreH.bit.rol(Jf4os,a4xc)return
zsMuNkv(YeLO2(Jf4os%u,a4xc%32))end
function VWiGCreH.bit.ror(e,la5)return zsMuNkv(Alv(
e%u,la5%32))end
function VWiGCreH.bit.bswap(i)return zsMuNkv(NOK(i%u))end;return VWiGCreH end
_=[[
	for name in luajit lua5.3 lua-5.3 lua5.2 lua-5.2 lua5.1 lua-5.1 lua; do
		: ${LUA:=$(command -v luajit)}
	done
	LUA_PATH='./?.lua;./?/init.lua;./lib/?.lua;./lib/?/init.lua;;'
	exec "$LUA" "$0" "$@"
	exit $?
]]_=nil;if not pcall(require,"i")then print("nothing found")
os.exit(0)end
print("something seems embeded")require"strict"local dM=require"i"local U=dM:need("secs")
local _u,aLgiy=U.class,U.instance;require"compat_env"
