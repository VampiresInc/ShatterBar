"""Executable Lua 5.1 regressions. No game installation is modified."""
import os,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
if os.environ.get('SHATTERBAR_LUPA_PATH'): sys.path.insert(0,os.environ['SHATTERBAR_LUPA_PATH'])
from lupa.lua51 import LuaRuntime
FILES=['Localization.lua','Core.lua','API.lua','Eligibility.lua','Recipes.lua','Scan.lua','UI.lua','Options.lua']
count=0
def runtime(legacy=False,forever=False,flavor="Retail",locale="enUS",language=None):
    lua=LuaRuntime(unpack_returned_tuples=True)
    compile=lua.eval('function(code,name) local f,e=loadstring(code,name); assert(f,e); return f end')
    lua.execute((ROOT/'tests/harness.lua').read_text(encoding='utf-8-sig'))
    if legacy: lua.execute('C_Container=nil; C_Item=nil; C_Spell=nil; C_SpellBook=nil; C_TooltipInfo=nil; ItemLocation=nil')
    lua.globals().GetLocale=lambda:locale
    ns=lua.table()
    data='Data/NoDisenchant_'+('Camelot' if forever else flavor)+'.lua'
    compile((ROOT/data).read_text(encoding='utf-8-sig'),'@'+data)('ShatterBar',ns)
    boxes='Data/Lockboxes_'+('Camelot' if forever else flavor)+'.lua'
    compile((ROOT/boxes).read_text(),'@'+boxes)('ShatterBar',ns)
    if flavor=='Retail' and not forever and not legacy:
        compile((ROOT/'Data/Prospecting_Retail.lua').read_text(),'@Data/Prospecting_Retail.lua')('ShatterBar',ns)
        compile((ROOT/'Data/Milling_Retail.lua').read_text(),'@Data/Milling_Retail.lua')('ShatterBar',ns)
    if forever: compile((ROOT/'FlavorForever.lua').read_text(encoding='utf-8-sig'),'@FlavorForever.lua')('ShatterBar',ns)
    for filename in FILES: compile((ROOT/filename).read_text(encoding='utf-8-sig'),'@'+filename)('ShatterBar',ns)
    if language is not None: lua.globals().ShatterBarDB=lua.table_from({"language":language})
    lua.execute("ShatterBar:Initialize(); seed()")
    return lua

def check(title,code,**kw):
    global count
    lua=runtime(**kw); lua.execute(code); count+=1; print('PASS',title)

for client in ['Mainline','Camelot','Vanilla','Mists','TBC']:
    runtime(legacy=client in ['Camelot','Vanilla'],forever=client=='Camelot',flavor='Retail' if client=='Mainline' else client)
    for line in (ROOT/f'ShatterBar_{client}.toc').read_text().splitlines():
        if line and not line.startswith('#'): assert (ROOT/line).is_file()
print('PASS Lua 5.1 loading, initialization, and five manifests')

scenario='''
item(10,'Ore',7); stack(0,1,10,3,ITEM_PROSPECTABLE); stack(0,2,10,12,ITEM_PROSPECTABLE)
item(20,'Herb',7); stack(0,3,20,5,ITEM_MILLABLE)
item(30,'Armor',4,'INVTYPE_CHEST'); stack(0,4,30,1)
ShatterBar:Refresh()
local p=ShatterBar.lists.prospect[1]
assert(p.slot==2 and p.total==15 and p.operations==2)
assert(#ShatterBar.lists.mill==1 and #ShatterBar.lists.de==1)
assert(ShatterBar.first:GetAttribute('target-slot')==4)
assert(ShatterBar.proxies.prospect:GetAttribute('target-slot')==2)
'''
check('modern APIs, mixed bars, stack selection and batch counts',scenario)
check('legacy APIs and tooltip fallback',scenario,legacy=True)
check('Forever explicit flavor',"assert(ShatterBar:Client()=='Forever')",forever=True)
check('short stacks, locked stacks, absent skill and uncached items are skipped','''
item(10,'Ore',7); stack(0,1,10,3,ITEM_PROSPECTABLE); stack(0,2,10,4,ITEM_PROSPECTABLE)
ShatterBar:Refresh(); assert(#ShatterBar.lists.prospect==0)
stack(0,3,10,5,ITEM_PROSPECTABLE,true); ShatterBar:Refresh(); assert(#ShatterBar.lists.prospect==0)
stack(0,3,10,5,ITEM_PROSPECTABLE); known[31252]=false
ShatterBar:Refresh(); assert(#ShatterBar.lists.prospect==0)
known[31252]=true; itemData[10]=nil; ShatterBar:Refresh(); assert(#ShatterBar.lists.prospect==0)
''')
check('soulbound, warbound, equipment-set and tabard filters','''
item(30,'Armor',4,'INVTYPE_CHEST'); stack(0,1,30,1)
bound['0:1']=true; ShatterBar:Refresh(); assert(#ShatterBar.lists.de==0)
ShatterBar.db.showSoulbound=true; ShatterBar:Refresh(); assert(#ShatterBar.lists.de==1)
warbound['0:1']=true; ShatterBar:Refresh(); assert(#ShatterBar.lists.de==0)
ShatterBar.db.showWarbound=true; ShatterBar:Refresh(); assert(#ShatterBar.lists.de==1)
setItems['0:1']=true; ShatterBar:Refresh(); assert(#ShatterBar.lists.de==0)
setItems['0:1']=false; itemData[30].equip='INVTYPE_TABARD'; ShatterBar:Refresh(); assert(#ShatterBar.lists.de==0)
''')
check('ignore, unlearned skills and hidden bars clear all first-item actions','''
item(10,'Ore',7); stack(0,1,10,5,ITEM_PROSPECTABLE); ShatterBar:Refresh()
assert(ShatterBar.first:GetAttribute('type1')=='spell')
ShatterBar.db.ignore[10]=true; ShatterBar:Refresh(); assert(ShatterBar.first:GetAttribute('type1')==nil)
ShatterBar.db.ignore={}; known[31252]=false; ShatterBar:Refresh()
assert(ShatterBar.proxies.prospect:GetAttribute('type1')==nil)
known[31252]=true; ShatterBar.db.hideBar=true; ShatterBar:Refresh()
assert(ShatterBar.first:GetAttribute('type1')==nil)
''')
check('first-item key revalidates moved slots and exhausted inventory','''
item(10,'Ore',7); stack(0,1,10,5,ITEM_PROSPECTABLE); ShatterBar:Refresh()
stack(0,1,99,1); item(99,'Unrelated item',7); stack(0,2,10,5,ITEM_PROSPECTABLE)
activate(ShatterBar.first); assert(ShatterBar.first:GetAttribute('target-slot')==2)
bagData={}; activate(ShatterBar.first); assert(ShatterBar.first:GetAttribute('type1')==nil)
''')
check('visible button does not process a different item after list replacement','''
item(10,'A ore',7); item(11,'B ore',7); stack(0,1,10,5,ITEM_PROSPECTABLE)
ShatterBar:Refresh(); local b=ShatterBar.bars.prospect.buttons[1]
stack(0,1,11,5,ITEM_PROSPECTABLE); activate(b); assert(b:GetAttribute('type1')==nil)
''')
check('casting guard and independent secure combat state snippets','''
item(10,'Ore',7); stack(0,1,10,5,ITEM_PROSPECTABLE); ShatterBar:Refresh()
busy=true; activate(ShatterBar.first); assert(ShatterBar.first:GetAttribute('type1')==nil)
busy=false; activate(ShatterBar.first); assert(ShatterBar.first:GetAttribute('type1')=='spell')
combat=true; local n=stateRegistrations; ShatterBar:Refresh(); activate(ShatterBar.first)
assert(ShatterBar.dirty and n==stateRegistrations)
for _,b in ipairs(frames) do
 local code=b:GetAttribute('_onstate-combat')
 if code then
  local f=assert(loadstring('return function(self,newstate) '..code..' end'))()
  secure=true; f(b,'1'); assert(b:GetAttribute('type1')==nil); f(b,'0'); secure=false
  assert(b:GetAttribute('type1')==b:GetAttribute('ready-type'))
 end
end
combat=false
''')
check('right-click ignore removes action and restores through db refresh','''
item(10,'Ore',7); stack(0,1,10,5,ITEM_PROSPECTABLE); ShatterBar:Refresh()
local b=ShatterBar.bars.prospect.buttons[1]; assert(b:GetAttribute('type2')==nil)
b.scripts.PostClick(b,'RightButton'); assert(ShatterBar.db.ignore[10])
assert(ShatterBar.first:GetAttribute('type1')==nil)
ShatterBar.db.ignore[10]=nil; ShatterBar:Refresh(); assert(ShatterBar.first:GetAttribute('type1')=='spell')
''')
check('key capture saves modified key, cancels, clears both prior bindings','''
local b=CreateFrame('Button'); bindings.Q='CLICK ShatterBarFirst:LeftButton'; bindings.W='CLICK ShatterBarFirst:LeftButton'
ShatterBar:CaptureBinding(b,'ShatterBarFirst','First'); shift=true
ShatterBar.capture.scripts.OnKeyDown(ShatterBar.capture,'K'); shift=false
assert(bindings['SHIFT-K']=='CLICK ShatterBarFirst:LeftButton' and not bindings.Q and not bindings.W and savedBindings==1)
ShatterBar:CaptureBinding(b,'ShatterBarFirst','First'); ShatterBar.capture.scripts.OnKeyDown(ShatterBar.capture,'ESCAPE')
assert(bindings['SHIFT-K'] and savedBindings==1)
ShatterBar:CaptureBinding(b,'ShatterBarFirst','First'); ShatterBar.capture.scripts.OnKeyDown(ShatterBar.capture,'BACKSPACE')
assert(not bindings['SHIFT-K'] and savedBindings==2)
''')
check('localized tooltip detection and reagent bag scan','''
ITEM_PROSPECTABLE='Prospectable localise'; item(10,'Minerai',7)
stack(5,1,10,5,'|cff00ff00Prospectable localise|r'); ShatterBar:Refresh()
assert(ShatterBar.lists.prospect[1].bag==5)
''')
check('offhands allowed and cosmetic armor/fishing poles excluded','''
item(10,'Offhand',4,'INVTYPE_HOLDABLE'); stack(0,1,10,1)
item(11,'Cosmetic',4,'INVTYPE_HEAD',2,5); stack(0,2,11,1)
item(12,'Fishing',2,'INVTYPE_2HWEAPON',2,20); stack(0,3,12,1)
ShatterBar:Refresh(); assert(#ShatterBar.lists.de==1 and ShatterBar.lists.de[1].id==10)
''')
check('locked box requires lockpick ability','''
item(10,'Box',15); stack(0,1,10,1,LOCKED); ShatterBar:Refresh(); assert(#ShatterBar.lists.unlock==1)
known[1804]=false; ShatterBar:Refresh(); assert(#ShatterBar.lists.unlock==0)
''')
check('empty tooltip response and missing optional client APIs do not crash',r'''
C_TooltipInfo.GetBagItem=function() return nil end
C_Container.GetContainerItemEquipmentSetInfo=nil
C_Item.IsBound=nil; C_Item.IsBoundToAccountUntilEquip=nil
item(30,'Armor',4,'INVTYPE_CHEST'); stack(0,1,30,1)
ShatterBar:Refresh(); assert(#ShatterBar.lists.de==0)
''')
check('pet battle hiding disables proxy actions',r'''
item(10,'Ore',7); stack(0,1,10,5,ITEM_PROSPECTABLE)
C_PetBattles={IsInBattle=function() return true end}
ShatterBar:Refresh(); assert(ShatterBar.first:GetAttribute('type1')==nil)
ShatterBar.db.hidePetBattle=false; ShatterBar:Refresh()
assert(ShatterBar.first:GetAttribute('type1')=='spell')
''')
check('persisted settings survive reinitialization in the same saved-data table',r'''
ShatterBar.db.ignore[42]=true; ShatterBar.db.scale=1.4
ShatterBar.db.positions.de={p='CENTER',rp='CENTER',x=3,y=7}
local saved=ShatterBarDB; ShatterBar.db=nil; ShatterBar:Initialize()
assert(ShatterBar.db==saved and ShatterBar.db.ignore[42] and ShatterBar.db.scale==1.4)
ShatterBar:Refresh(); local p,_,rp,x,y=ShatterBar.bars.de:GetPoint(); assert(x==3 and y==7)
''')
check('non-disenchantable and unknown equipment is never listed',r'''
item(10,'Unknown armor',4,'INVTYPE_CHEST'); stack(0,1,10,1,false)
local tooltip=C_TooltipInfo.GetBagItem
C_TooltipInfo.GetBagItem=function(bag,slot) if slot==1 then return nil end; return tooltip(bag,slot) end
item(11,'Ineligible armor',4,'INVTYPE_CHEST'); stack(0,2,11,1,ITEM_DISENCHANT_NOT_DISENCHANTABLE)
item(12,'Confirmed armor',4,'INVTYPE_CHEST'); stack(0,3,12,1,ITEM_DISENCHANT_ANY_SKILL)
ShatterBar:Refresh(); assert(#ShatterBar.lists.de==1 and ShatterBar.lists.de[1].id==12)
assert(ShatterBar.first:GetAttribute('target-slot')==3)
bagData[0][3].lines={ITEM_DISENCHANT_NOT_DISENCHANTABLE}; activate(ShatterBar.first)
assert(ShatterBar.first:GetAttribute('type1')==nil)
''')
check('negative tooltip marker overrides positive text',r'''
item(10,'Armor',4,'INVTYPE_CHEST'); stack(0,1,10,1)
bagData[0][1].lines={ITEM_DISENCHANT_ANY_SKILL,ITEM_DISENCHANT_NOT_DISENCHANTABLE}
ShatterBar:Refresh(); assert(#ShatterBar.lists.de==0)
''')
check('requirements hide insufficient and unknown skill ranks',r'''
item(10,'Armor',4,'INVTYPE_CHEST'); stack(0,1,10,1,'Disenchanting requires Enchanting (100)')
ShatterBar:Refresh(); assert(#ShatterBar.lists.de==0)
GetProfessions=function() return nil,2 end
local rank=99
GetProfessionInfo=function() return 'Enchanting',0,rank,300,0,0,333 end
ShatterBar:Refresh(); assert(#ShatterBar.lists.de==0)
rank=100; ShatterBar:Refresh(); assert(#ShatterBar.lists.de==1)
''')
check('legacy skill-line rank and localized positional requirement format',r'''
ITEM_DISENCHANT_MIN_SKILL='Requis : %2$d points en %1$s.'
item(10,'Armure',4,'INVTYPE_CHEST'); stack(0,1,10,1,'|cff00ff00Requis : 75 points en Enchantement.|r')
GetNumSkillLines=function() return 1 end
GetSkillLineInfo=function() return 'Enchantement',false,false,75 end
ShatterBar:Refresh(); assert(#ShatterBar.lists.de==1)
GetSkillLineInfo=function() return 'Enchantement',false,false,74 end
ShatterBar:Refresh(); assert(#ShatterBar.lists.de==0)
''',legacy=True)
check('missing localized eligibility markers fail closed',r'''
item(10,'Armor',4,'INVTYPE_CHEST'); stack(0,1,10,1)
ITEM_DISENCHANT_ANY_SKILL=nil; ITEM_DISENCHANT_MIN_SKILL=nil; ITEM_DISENCHANT_NOT_DISENCHANTABLE=nil
ShatterBar:Refresh(); assert(#ShatterBar.lists.de==0)
''')
check('Retail: only shoulders survive five explicit non-disenchantable exclusions',r'''
for slot=1,6 do
 item(100+slot,slot==3 and 'Shoulders' or ('Non-disenchantable '..slot),4,'INVTYPE_SHOULDER')
 stack(0,slot,100+slot,1,slot==3 and false or ITEM_DISENCHANT_NOT_DISENCHANTABLE)
end
bagData[0][3].lines={} -- Retail shoulders have no positive marker.
ShatterBar:Refresh()
assert(#ShatterBar.lists.de==1 and ShatterBar.lists.de[1].id==103)
assert(ShatterBar.first:GetAttribute('target-slot')==3)
''')
check('Retail: absent positive marker requires exact populated tooltip title',r'''
item(10,'Shoulders',4,'INVTYPE_SHOULDER'); stack(0,1,10,1,false)
ShatterBar:Refresh(); assert(#ShatterBar.lists.de==1)
C_TooltipInfo.GetBagItem=function() return {lines={{leftText='Retrieving item information'}}} end
ShatterBar:Refresh(); assert(#ShatterBar.lists.de==0)
C_TooltipInfo.GetBagItem=function() return {lines={}} end
ShatterBar:Refresh(); assert(#ShatterBar.lists.de==0)
''')
check('Classic: absence of positive eligibility evidence remains hidden',r'''
GetBuildInfo=function() return '1.15.9','1','date',11509 end
item(10,'Shoulders',4,'INVTYPE_SHOULDER'); stack(0,1,10,1,false)
ShatterBar:Refresh(); assert(#ShatterBar.lists.de==0)
''')
check('rendered tooltip exclusion overrides raw tooltip without exclusion text',r'''
item(10,'Brooch',4,'INVTYPE_NECK'); stack(0,1,10,1,ITEM_DISENCHANT_NOT_DISENCHANTABLE)
C_TooltipInfo.GetBagItem=function() return {lines={{leftText='Brooch'}}} end
ShatterBar:Refresh(); assert(#ShatterBar.lists.de==0)
''')
check('named tooltip arguments expose non-disenchantable text',r'''
item(10,'Brooch',4,'INVTYPE_NECK'); stack(0,1,10,1,false)
C_TooltipInfo.GetBagItem=function() return {lines={{leftText='Brooch'},
 {args={{field='leftText',stringVal=ITEM_DISENCHANT_NOT_DISENCHANTABLE}}}}} end
ShatterBar:Refresh(); assert(#ShatterBar.lists.de==0)
''')
check('eligibility report records actual markers and rendered text',r'''
item(10,'Brooch',4,'INVTYPE_NECK'); stack(0,1,10,1,ITEM_DISENCHANT_NOT_DISENCHANTABLE)
ShatterBar:DebugEligibility(); local r=ShatterBar.db.diagnostics
assert(r.negative==ITEM_DISENCHANT_NOT_DISENCHANTABLE and #r.items==1)
assert(r.items[1].negative and not r.items[1].allowed and #r.items[1].rendered>0)
''')
check('recorded Retail items: No Disenchant flags exclude all four rejected items',r'''
local ids={143909,117391,117357,235940,243038}
for slot,id in ipairs(ids) do
 item(id,'Equipment '..id,id==235940 and 2 or 4,id==243038 and 'INVTYPE_SHOULDER' or 'INVTYPE_NECK')
 stack(0,slot,id,1,false)
end
ShatterBar:Refresh()
assert(#ShatterBar.lists.de==1 and ShatterBar.lists.de[1].id==243038)
assert(ShatterBar.first:GetAttribute('target-slot')==5)
''')
check('No Disenchant data overrides even a misleading positive tooltip marker',r'''
item(143909,'Sweet Perfume Brooch',4,'INVTYPE_NECK'); stack(0,1,143909,1,ITEM_DISENCHANT_ANY_SKILL)
ShatterBar:Refresh(); assert(#ShatterBar.lists.de==0)
assert(ShatterBar.first:GetAttribute('type1')==nil)
''')
check('client cosmetic-item API excludes cosmetic equipment',r'''
item(243038,'Shoulders',4,'INVTYPE_SHOULDER'); stack(0,1,243038,1)
C_Item.IsCosmeticItem=function() return true end
ShatterBar:Refresh(); assert(#ShatterBar.lists.de==0)
''')
recipe_setup=r'''
known[31252]=false; local learned={[1231127]=true,[434018]=true}
craftCalls={}
C_TradeSkillUI={
 GetRecipeInfo=function(id) return {learned=learned[id] or false,name='Prospecting recipe'} end,
 CraftSalvage=function(recipe,casts,loc) craftCalls[#craftCalls+1]={recipe=recipe,casts=casts,bag=loc.bag,slot=loc.slot} end,
 OpenTradeSkill=function(id) openedProfession=id end}
'''
check('Retail prospecting works with learned recipe but no legacy spell or tooltip marker',recipe_setup+r'''
item(237359,'Refulgent Copper Ore',7); stack(0,1,237359,10,false)
ShatterBar:Refresh(); assert(#ShatterBar.lists.prospect==1)
local ore=ShatterBar.lists.prospect[1]; assert(ore.recipe==1231127 and ore.operations==2)
local p=ShatterBar.proxies.prospect
assert(p:GetAttribute('type1')=='macro' and p:GetAttribute('target-slot')==nil)
local code=p:GetAttribute('macrotext'); assert(not code:find('/use',1,true))
assert(loadstring(code:sub(6)))()
assert(#craftCalls==1 and craftCalls[1].recipe==1231127 and craftCalls[1].casts==1 and craftCalls[1].slot==1)
assert(ShatterBar.bars.prospect:IsShown())
ShatterBar.bars.prospect.head.scripts.PostClick(ShatterBar.bars.prospect.head,'LeftButton')
assert(openedProfession==755)
''')
check('recipe prospecting skips unlearned recipes, short stacks and unknown ore',recipe_setup+r'''
item(2770,'Copper Ore',7); stack(0,1,2770,10,false) -- classic recipe not learned
item(237359,'Refulgent Copper Ore',7); stack(0,2,237359,4,false)
item(999999,'Unmapped ore',7); stack(0,3,999999,10,ITEM_PROSPECTABLE)
ShatterBar:Refresh(); assert(#ShatterBar.lists.prospect==0)
stack(0,2,237359,5,false); ShatterBar:Refresh(); assert(#ShatterBar.lists.prospect==1)
C_TradeSkillUI.GetRecipeInfo=function() return {learned=false} end
ShatterBar:Refresh(); assert(#ShatterBar.lists.prospect==0)
assert(ShatterBar.proxies.prospect:GetAttribute('type1')==nil)
''')
check('recipe keybind retargets moved ore and clears exhausted target',recipe_setup+r'''
item(237359,'Refulgent Copper Ore',7); stack(0,1,237359,5,false)
ShatterBar:Refresh(); bagData[0][1]={}; stack(0,2,237359,5,false)
activate(ShatterBar.first)
local code=ShatterBar.first:GetAttribute('macrotext'); assert(loadstring(code:sub(6)))()
assert(craftCalls[1].bag==0 and craftCalls[1].slot==2)
bagData={}; activate(ShatterBar.first)
assert(ShatterBar.first:GetAttribute('type1')==nil and ShatterBar.first:GetAttribute('macrotext')==nil)
''')
check('combat and casting disable recipe macro actions',recipe_setup+r'''
item(237359,'Refulgent Copper Ore',7); stack(0,1,237359,5,false)
ShatterBar:Refresh(); busy=true; activate(ShatterBar.first)
assert(ShatterBar.first:GetAttribute('type1')==nil)
busy=false; activate(ShatterBar.first); assert(ShatterBar.first:GetAttribute('type1')=='macro')
combat=true; secure=true
local b=ShatterBar.first; local f=assert(loadstring('return function(self,newstate) '..b:GetAttribute('_onstate-combat')..' end'))()
f(b,'1'); assert(b:GetAttribute('type1')==nil)
f(b,'0'); assert(b:GetAttribute('type1')=='macro'); secure=false; combat=false
assert(#craftCalls==0)
''')
check('opening recipes refreshes previously unavailable learned-recipe data',recipe_setup+r'''
item(237359,'Refulgent Copper Ore',7); stack(0,1,237359,5,false)
local ready=false
C_TradeSkillUI.GetRecipeInfo=function(id) if ready then return {learned=id==1231127} end end
ShatterBar:Refresh(); assert(#ShatterBar.lists.prospect==0)
ready=true; ShatterBar.scripts.OnEvent(ShatterBar,'TRADE_SKILL_LIST_UPDATE')
ShatterBar:Refresh(); assert(#ShatterBar.lists.prospect==1)
''')
bank_setup=recipe_setup+r'''
Enum={BagIndex={AccountBankTab_1=13,AccountBankTab_2=14,CharacterBankTab_1=6}}
local loc={bagID=13,slotIndex=3,bag=13,slot=3}
bankAccessible=true; bankGUID='Item-1234-ABCDEF'
item(237359,'Refulgent Copper Ore',7)
bankTargets={{itemID=237359,itemGUID=bankGUID,quantity=10,hyperlink='item:237359'}}
bankQueries=0
C_TradeSkillUI.GetCraftingTargetItems=function(ids) bankQueries=bankQueries+1; return bankTargets end
C_Item.GetItemLocation=function(guid) if bankAccessible and guid==bankGUID then return loc end end
C_Item.GetItemGUID=function(location) if bankAccessible and location==loc then return bankGUID end end
'''
check('Warband option defaults off and never queries bank targets',bank_setup+r'''
assert(ShatterBar.db.includeWarbandOre==false)
ShatterBar:Refresh(); assert(#ShatterBar.lists.prospect==0 and bankQueries==0)
''')
check('enabled Warband source creates labelled GUID-targeted single-batch action',bank_setup+r'''
ShatterBar.db.includeWarbandOre=true; ShatterBar:Refresh()
local ore=ShatterBar.lists.prospect[1]
assert(ore.source=='warband' and ore.total==10 and ore.operations==2 and ore.warbandTotal==10)
assert(ShatterBar.bars.prospect.buttons[1].source.text=='W')
local macro=ShatterBar.first:GetAttribute('macrotext')
assert(macro:find('GetItemLocation',1,true) and not macro:find('CreateFromBagAndSlot',1,true))
assert(loadstring(macro:sub(6)))()
assert(#craftCalls==1 and craftCalls[1].casts==1 and craftCalls[1].bag==13)
''')
check('carried ore is preferred and totals do not double-count crafting targets',bank_setup+r'''
ShatterBar.db.includeWarbandOre=true
stack(0,1,237359,5,false)
bankTargets[2]={itemID=237359,itemGUID='Item-carried-111',quantity=5}
ShatterBar:Refresh(); local ore=ShatterBar.lists.prospect[1]
assert(ore.source~='warband' and ore.bag==0 and ore.total==15 and ore.operations==3)
assert(ore.carriedTotal==5 and ore.warbandTotal==10)
''')
check('bank disappearance, short stacks and ignored IDs cannot be processed',bank_setup+r'''
ShatterBar.db.includeWarbandOre=true; ShatterBar:Refresh()
local old=ShatterBar.first:GetAttribute('macrotext')
bankAccessible=false; assert(loadstring(old:sub(6)))(); assert(#craftCalls==0)
activate(ShatterBar.first); assert(ShatterBar.first:GetAttribute('type1')==nil)
bankAccessible=true; bankTargets[1].quantity=4; ShatterBar:Refresh(); assert(#ShatterBar.lists.prospect==0)
bankTargets[1].quantity=10; ShatterBar.db.ignore[237359]=true
ShatterBar:Refresh(); assert(#ShatterBar.lists.prospect==0)
''')
check('turning bank option off removes prepared keybind action immediately',bank_setup+r'''
ShatterBar.db.includeWarbandOre=true; ShatterBar:Refresh()
assert(ShatterBar.first:GetAttribute('type1')=='macro')
ShatterBar.db.includeWarbandOre=false; ShatterBar:Refresh()
assert(#ShatterBar.lists.prospect==0 and ShatterBar.first:GetAttribute('type1')==nil)
''')
check('unsupported bank APIs and query failure leave carried prospecting working',bank_setup+r'''
ShatterBar.db.includeWarbandOre=true; stack(0,1,237359,5,false)
C_TradeSkillUI.GetCraftingTargetItems=function() error('unavailable') end
ShatterBar:Refresh(); assert(#ShatterBar.lists.prospect==1 and not ShatterBar.lists.prospect[1].source)
C_Item.GetItemLocation=nil; ShatterBar:Refresh(); assert(#ShatterBar.lists.prospect==1)
''')
check('short carried and bank stacks are not combined into an imaginary batch',bank_setup+r'''
ShatterBar.db.includeWarbandOre=true; stack(0,1,237359,3,false)
bankTargets[1].quantity=3; ShatterBar:Refresh(); assert(#ShatterBar.lists.prospect==0)
''')
check('bank prospecting diagnostics retain accessible targets and query status',bank_setup+r'''
ShatterBar.db.includeWarbandOre=true; ShatterBar:DebugProspecting()
local r=ShatterBar.db.prospectDiagnostics
assert(r.warbandStatus.enabled and r.warbandStatus.targets==1 and r.warbandStatus.resolved==1)
assert(r.warbandItems[1].guid==bankGUID)
''')
check('remote crafting target does not require reverse bank-slot GUID access',bank_setup+r'''
ShatterBar.db.includeWarbandOre=true
C_Item.GetItemGUID=function() return nil end
ShatterBar:Refresh(); assert(#ShatterBar.lists.prospect==1)
local macro=ShatterBar.first:GetAttribute('macrotext')
assert(not macro:find('GetItemGUID',1,true)); assert(loadstring(macro:sub(6)))()
assert(#craftCalls==1 and craftCalls[1].bag==13 and craftCalls[1].casts==1)
C_Item.GetItemGUID=nil; ShatterBar:Refresh(); assert(#ShatterBar.lists.prospect==1)
''')
check('remote support still excludes personal bank locations',bank_setup+r'''
ShatterBar.db.includeWarbandOre=true
C_Item.GetItemLocation=function() return {bagID=6,slotIndex=1} end
ShatterBar:Refresh(); assert(#ShatterBar.lists.prospect==0)
assert(ShatterBar.first:GetAttribute('type1')==nil)
''')
check('diagnostics capture unresolved remote location details',bank_setup+r'''
ShatterBar.db.includeWarbandOre=true; bankAccessible=false
ShatterBar:DebugProspecting(); local r=ShatterBar.db.prospectDiagnostics
assert(r.warbandStatus.targets==1 and r.warbandStatus.resolved==0)
assert(r.warbandStatus.samples[1].id==237359 and not r.warbandStatus.samples[1].locationResolved)
''')
check('late remote targets appear without any bank or bag update event',bank_setup+r'''
ShatterBar.db.includeWarbandOre=true
local ready=false
C_TradeSkillUI.GetCraftingTargetItems=function() if ready then return bankTargets else return {} end end
ShatterBar:Refresh(); assert(#ShatterBar.lists.prospect==0)
ready=true; ShatterBar.scripts.OnUpdate(ShatterBar,1.1)
assert(#ShatterBar.lists.prospect==1 and ShatterBar.first:GetAttribute('type1')=='macro')
local macro=ShatterBar.first:GetAttribute('macrotext'); assert(loadstring(macro:sub(6)))()
assert(craftCalls[1].recipe==1231127 and craftCalls[1].casts==1)
''')
check('remote target polling refreshes counts and clears unavailable targets',bank_setup+r'''
ShatterBar.db.includeWarbandOre=true; ShatterBar:Refresh()
bankTargets[1].quantity=5; ShatterBar.scripts.OnUpdate(ShatterBar,1.1)
assert(ShatterBar.lists.prospect[1].operations==1)
bankTargets={}; ShatterBar.scripts.OnUpdate(ShatterBar,1.1)
assert(#ShatterBar.lists.prospect==0 and ShatterBar.first:GetAttribute('type1')==nil)
''')
check('unchanged remote targets avoid a full rescan and polling stops in combat',bank_setup+r'''
ShatterBar.db.includeWarbandOre=true; ShatterBar:Refresh(); ShatterBar.dirty=false
local list=ShatterBar.lists
ShatterBar.scripts.OnUpdate(ShatterBar,1.1); assert(ShatterBar.lists==list)
combat=true; local before=bankQueries
ShatterBar.scripts.OnUpdate(ShatterBar,2); assert(bankQueries==before)
combat=false; ShatterBar.db.includeWarbandOre=false
ShatterBar.scripts.OnUpdate(ShatterBar,2); assert(bankQueries==before)
''')
mill_setup=recipe_setup+r'''
known[51005]=false
C_TradeSkillUI.GetRecipeInfo=function(id) return {learned=id==382994 or id==1269575} end
'''
check('Retail milling uses learned recipes without the old spell or tooltip marker',mill_setup+r'''
item(765,'Silverleaf',7); stack(0,1,765,15,false)
ShatterBar:Refresh(); local herb=ShatterBar.lists.mill[1]
assert(herb.recipe==382994 and herb.batch==5 and herb.operations==3)
local b=ShatterBar.proxies.mill; assert(b:GetAttribute('type1')=='macro')
assert(loadstring(b:GetAttribute('macrotext'):sub(6)))()
assert(#craftCalls==1 and craftCalls[1].recipe==382994 and craftCalls[1].casts==1)
ShatterBar.bars.mill.head.scripts.PostClick(ShatterBar.bars.mill.head,'LeftButton')
assert(openedProfession==773)
''')
check('new milling recipes require ten herbs rather than five',mill_setup+r'''
item(236761,'Tranquility Bloom',7); stack(0,1,236761,9,false)
ShatterBar:Refresh(); assert(#ShatterBar.lists.mill==0)
stack(0,1,236761,25,false); ShatterBar:Refresh()
local herb=ShatterBar.lists.mill[1]; assert(herb.batch==10 and herb.operations==2)
C_TradeSkillUI.GetRecipeInfo=function() return {learned=false} end
ShatterBar:Refresh(); assert(#ShatterBar.lists.mill==0)
''')
check('milling first-item binding follows moved and exhausted herb stacks',mill_setup+r'''
item(765,'Silverleaf',7); stack(0,1,765,5,false); ShatterBar:Refresh()
bagData[0][1]={}; stack(0,2,765,5,false); activate(ShatterBar.proxies.mill)
local macro=ShatterBar.proxies.mill:GetAttribute('macrotext'); assert(loadstring(macro:sub(6)))()
assert(craftCalls[1].slot==2 and craftCalls[1].recipe==382994)
bagData={}; activate(ShatterBar.proxies.mill); assert(ShatterBar.proxies.mill:GetAttribute('type1')==nil)
''')
mill_bank_setup=bank_setup+r'''
known[51005]=false
C_TradeSkillUI.GetRecipeInfo=function(id) return {learned=id==382994 or id==1269575} end

item(236761,'Tranquility Bloom',7)
bankTargets={{itemID=236761,itemGUID=bankGUID,quantity=25,hyperlink='item:236761'}}
'''
check('Warband herbs have an independent opt-in and route to the milling bar',mill_bank_setup+r'''
assert(not ShatterBar.db.includeWarbandHerbs and not ShatterBar.db.includeWarbandOre)
ShatterBar.db.includeWarbandHerbs=true; ShatterBar:Refresh()
assert(#ShatterBar.lists.prospect==0 and #ShatterBar.lists.mill==1)
local herb=ShatterBar.lists.mill[1]; assert(herb.source=='warband' and herb.operations==2 and herb.batch==10)
local macro=ShatterBar.proxies.mill:GetAttribute('macrotext'); assert(loadstring(macro:sub(6)))()
assert(craftCalls[1].recipe==1269575 and craftCalls[1].bag==13)
ShatterBar.db.includeWarbandHerbs=false; ShatterBar:Refresh()
assert(#ShatterBar.lists.mill==0 and ShatterBar.proxies.mill:GetAttribute('type1')==nil)
''')
check('herbs arriving after Inscription opens refresh without bank events',mill_bank_setup+r'''
ShatterBar.db.includeWarbandHerbs=true; local ready=false
C_TradeSkillUI.GetCraftingTargetItems=function() return ready and bankTargets or {} end
ShatterBar:Refresh(); assert(#ShatterBar.lists.mill==0)
ready=true; ShatterBar.scripts.OnUpdate(ShatterBar,1.1)
assert(#ShatterBar.lists.mill==1 and ShatterBar.bars.mill.buttons[1].source.text=='W')
ShatterBar:DebugProspecting('mill'); local r=ShatterBar.db.millDiagnostics
assert(r.recipeMode and r.warbandItems[1].recipe==1269575 and r.warbandStatus.resolved==1)
''')
check('carried herbs are preferred and short herb stacks are not combined',mill_bank_setup+r'''
ShatterBar.db.includeWarbandHerbs=true
stack(0,1,236761,10,false); ShatterBar:Refresh()
local herb=ShatterBar.lists.mill[1]
assert(not herb.source and herb.total==35 and herb.operations==3)
stack(0,1,236761,6,false); bankTargets[1].quantity=6
ShatterBar:Refresh(); assert(#ShatterBar.lists.mill==0)
''')
check('lockbox transitions from pick spell to opening item, then disappears after looting',r'''
item(4632,'Ornate Bronze Lockbox',15); stack(0,1,4632,1,LOCKED)
ShatterBar:Refresh(); local b=ShatterBar.proxies.unlock
assert(b:GetAttribute('type1')=='spell' and b:GetAttribute('target-slot')==1)
bagData[0][1].lines={}; activate(b)
assert(b:GetAttribute('type1')=='item' and b:GetAttribute('item')=='0 1')
assert(b:GetAttribute('spell')==nil and b:GetAttribute('target-slot')==nil)
assert(ShatterBar.bars.unlock.buttons[1].source.text=='Open')
bagData={}; activate(b); assert(b:GetAttribute('type1')==nil and b:GetAttribute('item')==nil)
''')
check('same-ID lockboxes keep separate lock states and opened boxes are first',r'''
item(4632,'Ornate Bronze Lockbox',15)
stack(0,1,4632,1,LOCKED); stack(0,2,4632,1,false)
ShatterBar:Refresh(); assert(#ShatterBar.lists.unlock==2)
assert(ShatterBar.lists.unlock[1].slot==2 and ShatterBar.lists.unlock[1].boxAction=='open')
assert(ShatterBar.lists.unlock[2].slot==1 and ShatterBar.lists.unlock[2].boxAction=='pick')
assert(ShatterBar.proxies.unlock:GetAttribute('item')=='0 2')
''')
check('locked words in box names do not override its unlocked state',r'''
item(4632,'Locked Supply Chest',15); stack(0,1,4632,1,false)
ShatterBar:Refresh(); assert(ShatterBar.lists.unlock[1].boxAction=='open')
assert(ShatterBar.proxies.unlock:GetAttribute('type1')=='item')
''')
check('unknown containers and incomplete box tooltips are not opened',r'''
item(999999,'Unrelated Gift',15); stack(0,1,999999,1,false)
item(4632,'Ornate Bronze Lockbox',15); stack(0,2,4632,1,false)
C_TooltipInfo.GetBagItem=function(bag,slot) if slot==1 then return {lines={{leftText='Unrelated Gift'}}} end end
ShatterBar:Refresh(); assert(#ShatterBar.lists.unlock==0)
''')
check('moving an unlocked box revalidates the exact opening target',r'''
item(4632,'Ornate Bronze Lockbox',15); stack(0,1,4632,1,false)
ShatterBar:Refresh(); bagData[0][1]={}; stack(0,2,4632,1,false)
activate(ShatterBar.proxies.unlock); assert(ShatterBar.proxies.unlock:GetAttribute('item')=='0 2')
ShatterBar.db.ignore[4632]=true; ShatterBar:Refresh()
assert(ShatterBar.proxies.unlock:GetAttribute('type1')==nil)
''')
check('legacy box opening uses the same secure item action',r'''
item(4632,'Ornate Bronze Lockbox',15); stack(0,1,4632,1,false)
local tooltip=ShatterBar.Tooltip
ShatterBar.Tooltip=function(self,item) local lines=tooltip(self,item); lines.complete=true; return lines end
ShatterBar:Refresh(); assert(ShatterBar.proxies.unlock:GetAttribute('type1')=='item')
''',legacy=True)
# Every shipped locale must cover the English catalog and preserve format arguments.
import re
for locale in ['enUS','enGB','deDE','frFR','esES','esMX','itIT','ptBR','ruRU','koKR','zhCN','zhTW','xxXX']:
    lua=runtime(locale=locale)
    compile=lua.eval('function(c) return assert(loadstring(c)) end')
    ns=lua.table()
    compile((ROOT/'Localization.lua').read_text(encoding='utf-8'))('ShatterBar',ns)
    expected='enUS' if locale in ['enGB','xxXX'] else locale
    assert ns.locale==expected
    for key,value in ns.translations.enUS.items():
        translated=ns.translations[expected][key]
        assert isinstance(translated,str) and translated.strip(), (locale,key)
        assert re.findall(r'%[sd]',value)==re.findall(r'%[sd]',translated),(locale,key)
    assert ns.L['future English fallback']=='future English fallback'
    if expected!='enUS':
        ns.translations[expected]['Visibility']=None
        assert ns.L['Visibility']=='Visibility'
    assert ns.L['RIGHT']!=''
    assert lua.globals().ShatterBar.kinds[1].label==ns.L['Disenchant']
    assert lua.globals()['BINDING_NAME_CLICK ShatterBarFirst:LeftButton']==ns.L['Process first item (first nonempty bar)']
    lua.execute('SlashCmdList.SHATTERBAR("status"); ShatterBar:UpdateIgnored()')
    count+=1
    print('PASS client language, catalog, format strings and fallback',locale)
for selected in ['enUS','deDE','frFR','esES','esMX','itIT','ptBR','ruRU','koKR','zhCN','zhTW']:
    lua=runtime(locale='deDE' if selected=='enUS' else 'enUS',language=selected)
    assert lua.globals().ShatterBar.db.language==selected
    # Compare against a client that naturally selects the same language.
    native=runtime(locale=selected)
    assert lua.globals().ShatterBar.kinds[1].label==native.globals().ShatterBar.kinds[1].label
    assert lua.globals()['BINDING_NAME_CLICK ShatterBarFirst:LeftButton']==native.globals()['BINDING_NAME_CLICK ShatterBarFirst:LeftButton']
    count+=1
    print('PASS saved language override and binding labels',selected)
check('automatic default, saved selector choice, and selecting client language again','''
assert(ShatterBar.db.language=='auto')
ShatterBar.languageChoices[3].scripts.OnClick()
assert(ShatterBar.db.language=='deDE')
assert(ShatterBar.kinds[1].label=='Disenchant') -- Applied only on next reload.
ShatterBar.languageChoices[1].scripts.OnClick()
assert(ShatterBar.db.language=='auto')
''')
check('invalid saved language falls back to the client','''
assert(ShatterBar.db.language=='auto')
assert(ShatterBar.kinds[1].label=='Entzaubern')
''',locale='deDE',language='invalid')
# Naming must match packager conventions used by Wago and Mailwright.
import importlib.util
spec=importlib.util.spec_from_file_location('shatter_package',ROOT/'tools/package.py')
package=importlib.util.module_from_spec(spec);spec.loader.exec_module(package)
for flavor,suffix in [('retail',''),('forever','-forever'),('classic','-classic'),('mists','-mists'),('bcc','-bcc')]:
    assert package.artifact_name(flavor)==f'ShatterBar-{package.VERSION}{suffix}.zip'
count+=1
print('PASS client archive names follow packager conventions')
print(f'{count} regression scenarios passed. In-game testing remains required.')
