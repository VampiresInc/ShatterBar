-- Minimal executable WoW UI harness. Secure state snippets are executed separately.
frames={}; messages={}; combat=false; busy=false; bagData={}; itemData={}; known={}; bound={}; warbound={}; setItems={}
bindings={}; savedBindings=0; stateRegistrations=0
UIParent={}; SlashCmdList={}; UISpecialFrames={}; STANDARD_TEXT_FONT='font'; NUM_TOTAL_EQUIPPED_BAG_SLOTS=5
ITEM_DISENCHANT_ANY_SKILL='Disenchantable'; ITEM_DISENCHANT_MIN_SKILL='Disenchanting requires %s (%d)'; ITEM_DISENCHANT_NOT_DISENCHANTABLE='Cannot be disenchanted'
ITEM_PROSPECTABLE='Prospectable'; ITEM_MILLABLE='Millable'; LOCKED='Locked'; ITEM_SOULBOUND='Soulbound'; ITEM_ACCOUNTBOUND='Account Bound'; ITEM_BNETACCOUNTBOUND='Account Bound'; ITEM_ACCOUNTBOUND_UNTIL_EQUIP='Warbound until equipped'
local methods={}
local function noop() end
local function region()
 return setmetatable({SetText=function(s,t) s.text=t end,GetText=function(s) return s.text end}, {__index=function() return noop end})
end
function methods:SetScript(k,f) self.scripts[k]=f end
function methods:GetScript(k) return self.scripts[k] end
function methods:SetAttribute(k,v) assert(not combat or secure,'insecure attribute write in combat'); self.attrs[k]=v end
function methods:GetAttribute(k) return self.attrs[k] end
function methods:GetName() return self.name end
function methods:CreateTexture() return region() end
function methods:CreateFontString() return region() end
function methods:SetText(t) self.text=t end
function methods:GetText() return self.text or '' end
function methods:SetChecked(v) self.checked=v end
function methods:GetChecked() return self.checked end
function methods:SetPoint(...) self.point={...} end
function methods:GetPoint() return unpack(self.point or {'CENTER',UIParent,'CENTER',0,0}) end
function methods:Show() self.shown=true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide() self.shown=false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:IsShown() return self.shown end
function methods:NumLines() return #(self.lines or {}) end
function methods:SetBagItem(bag,slot)
 self.lines=(bagData[bag] and bagData[bag][slot] or {}).lines or {}
 for i,line in ipairs(self.lines) do _G[self.name..'TextLeft'..i]=region(); _G[self.name..'TextLeft'..i]:SetText(line) end
end
for _,name in ipairs({'RegisterEvent','RegisterForClicks','RegisterForDrag','SetSize','SetHeight','SetWidth','SetMovable','SetClampedToScreen','SetScale','ClearAllPoints','SetNormalTexture','SetHighlightTexture','SetFrameStrata','EnableMouse','EnableKeyboard','SetPropagateKeyboardInput','SetAutoFocus','SetNumeric','ClearFocus','SetScrollChild','Raise','StartMoving','StopMovingOrSizing','SetOwner','ClearLines','AddLine'}) do methods[name]=noop end
function CreateFrame(kind,name,parent,template)
 local f=setmetatable({name=name,scripts={},attrs={},Text=region(),TitleText=region()}, {__index=methods})
 frames[#frames+1]=f; if name then _G[name]=f end; return f
end
GameTooltip=CreateFrame('GameTooltip')
DEFAULT_CHAT_FRAME={AddMessage=function(_,s) messages[#messages+1]=s end}
function InCombatLockdown() return combat end
function GetBuildInfo() return '12.1.5','1','date',120105 end
function GetSpellInfo(id) return 'Spell '..id,nil,id end
function IsPlayerSpell(id) return known[id] or false end
function UnitCastingInfo() return busy and 'Casting' or nil end
function IsShiftKeyDown() return shift or false end
function IsControlKeyDown() return ctrl or false end
function IsAltKeyDown() return alt or false end
function RegisterStateDriver(f,state,condition) stateRegistrations=stateRegistrations+1; f.drivers=f.drivers or {}; f.drivers[state]=condition end
function UnregisterStateDriver(f,state) if f.drivers then f.drivers[state]=nil end end
function InterfaceOptions_AddCategory(c) category=c end
function GetBindingKey(command)
 local keys={}; for k,v in pairs(bindings) do if v==command then keys[#keys+1]=k end end; table.sort(keys); return unpack(keys)
end
function SetBinding(key,command) bindings[key]=command; return true end
function SetBindingClick(key,name,mouse) bindings[key]='CLICK '..name..':'..mouse; return true end
function SaveBindings() savedBindings=savedBindings+1 end
function GetCurrentBindingSet() return 2 end
function GetContainerNumSlots(bag) return #(bagData[bag] or {}) end
function GetContainerItemInfo(bag,slot)
 local x=bagData[bag] and bagData[bag][slot]; if not x or not x.id then return end
 return x.id,x.count or 1,x.locked,x.quality,false,false,'item:'..x.id,false,false,x.id
end
function GetContainerItemLink(bag,slot) local x=bagData[bag] and bagData[bag][slot]; return x and x.id and 'item:'..x.id end
function GetItemInfo(id)
 id=tonumber(tostring(id):match('item:(%d+)')) or id
 local x=itemData[id]; if not x then return end
 return x.name,'item:'..id,x.quality or 2,20,1,'type','subtype',20,x.equip or '',id,1,x.class or 7,x.subclass or 0
end
ItemLocation={CreateFromBagAndSlot=function(_,bag,slot) return {bag=bag,slot=slot} end}
C_Item={GetItemInfo=GetItemInfo,IsBound=function(loc) return bound[loc.bag..':'..loc.slot] end,
 IsBoundToAccountUntilEquip=function(loc) return warbound[loc.bag..':'..loc.slot] end}
C_Container={GetContainerNumSlots=GetContainerNumSlots,
 GetContainerItemLink=GetContainerItemLink,
 GetContainerItemInfo=function(bag,slot)
  local icon,count,locked,quality,_,_,link,_,_,id=GetContainerItemInfo(bag,slot)
  if icon then return {iconFileID=icon,stackCount=count,isLocked=locked,quality=quality,hyperlink=link,itemID=id} end
 end,
 GetContainerItemEquipmentSetInfo=function(bag,slot) return setItems[bag..':'..slot] or false end}
C_TooltipInfo={GetBagItem=function(bag,slot)
 local record=bagData[bag][slot] or {}; local data=itemData[record.id]
 local lines=data and {{leftText=data.name}} or {}; for _,s in ipairs(record.lines or {}) do lines[#lines+1]={leftText=s} end; return {lines=lines}
end}
C_Spell={GetSpellInfo=function(id) return {name='Spell '..id,iconID=id} end}
C_SpellBook={IsSpellKnown=IsPlayerSpell}
function seed()
 combat=false; busy=false; bagData={}; itemData={}; known={}; bound={}; warbound={}; setItems={}
 for _,k in ipairs(ShatterBar.kinds) do known[k.spell]=true end
 ShatterBar.db.ignore={}; ShatterBar.db.hideBar=false; ShatterBar.db.hideEmpty=true
 ShatterBar.db.showSoulbound=false; ShatterBar.db.showWarbound=false
 ShatterBar.db.hideSets=true; ShatterBar.db.hideTabards=true
end
function item(id,name,class,equip,quality,subclass) itemData[id]={name=name,class=class,equip=equip,quality=quality,subclass=subclass} end
function stack(bag,slot,id,count,marker,locked)
 local data=itemData[id]
 if marker==nil and data and (data.class==2 or data.class==4) then marker=ITEM_DISENCHANT_ANY_SKILL end
 bagData[bag]=bagData[bag] or {}; bagData[bag][slot]={id=id,count=count,lines=marker and {marker} or {},locked=locked}
end
function activate(b) b.scripts.PreClick(b,'LeftButton',false) end
