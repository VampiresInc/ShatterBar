local _, ns = ...
local S=ns.S
function S:InCombat() return InCombatLockdown and InCombatLockdown() end
function S:Client()
    local build=GetBuildInfo and select(4,GetBuildInfo()) or 0
    if ns.forever or (build>=16000 and build<20000) then return "Forever" end
    return "WoW "..tostring(GetBuildInfo and GetBuildInfo() or "unknown")
end
function S:Spell(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local info=C_Spell.GetSpellInfo(id)
        if info then return info.name,info.iconID end
    elseif GetSpellInfo then
        local name,_,icon=GetSpellInfo(id)
        return name,icon
    end
end
function S:Knows(id)
    if C_SpellBook and C_SpellBook.IsSpellKnown then return C_SpellBook.IsSpellKnown(id) end
    if IsPlayerSpell then return IsPlayerSpell(id) end
    if IsSpellKnown then return IsSpellKnown(id) end
    return false
end
function S:Slots(bag)
    local fn=C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    return fn and fn(bag) or 0
end
function S:BagItem(bag,slot)
    local info
    if C_Container and C_Container.GetContainerItemInfo then
        info=C_Container.GetContainerItemInfo(bag,slot)
    elseif GetContainerItemInfo then
        local icon,count,locked,quality,_,_,link,_,_,id=GetContainerItemInfo(bag,slot)
        if icon then info={iconFileID=icon,stackCount=count,isLocked=locked,quality=quality,hyperlink=link,itemID=id} end
    end
    if not info then return end
    local linkFn=C_Container and C_Container.GetContainerItemLink or GetContainerItemLink
    local link=info.hyperlink or (linkFn and linkFn(bag,slot))
    local id=info.itemID or tonumber((link or ""):match("item:(%d+)"))
    if not id then return end
    return {bag=bag,slot=slot,id=id,link=link,icon=info.iconFileID,count=info.stackCount or 1,locked=info.isLocked,quality=info.quality}
end
function S:ItemDetails(item)
    local fn=C_Item and C_Item.GetItemInfo or GetItemInfo
    if not fn then return end
    local name,link,quality,level,_,_,_,_,equip,icon,_,class,subclass=fn(item.link or item.id)
    if not name then
        if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(item.id) end
        return
    end
    item.name,item.link,item.quality,item.level=name,item.link or link,quality,level
    item.equip,item.icon,item.class,item.subclass=equip,icon or item.icon,class,subclass
    return item
end
function S:Tooltip(item)
    local result={}
    if C_TooltipInfo and C_TooltipInfo.GetBagItem then
        local data=C_TooltipInfo.GetBagItem(item.bag,item.slot)
        if data and TooltipUtil and TooltipUtil.SurfaceArgs then TooltipUtil.SurfaceArgs(data) end
        for _,line in ipairs(data and data.lines or {}) do
            if TooltipUtil and TooltipUtil.SurfaceArgs then TooltipUtil.SurfaceArgs(line) end
            -- Older tooltip data stores text as named arguments until surfaced.
            for _,arg in ipairs(line.args or {}) do
                if (arg.field=="leftText" or arg.field=="rightText") and type(arg.stringVal)=="string" then
                    result[#result+1]=arg.stringVal
                end
            end
            if type(line.leftText)=="string" then result[#result+1]=line.leftText end
            if type(line.rightText)=="string" then result[#result+1]=line.rightText end
        end
    else
        if not self.scanner then
            self.scanner=CreateFrame("GameTooltip","ShatterBarScanTooltip",UIParent,"GameTooltipTemplate")
        end
        self.scanner:SetOwner(UIParent,"ANCHOR_NONE")
        self.scanner:ClearLines()
        self.scanner:SetBagItem(item.bag,item.slot)
        for i=1,self.scanner:NumLines() do
            for _,side in ipairs({"Left","Right"}) do
                local line=_G["ShatterBarScanTooltipText"..side..i]
                local text=line and line:GetText()
                if text then result[#result+1]=text end
            end
        end
        self.scanner:Hide()
    end
    -- A missing/partially loaded tooltip is not evidence of eligibility. Match
    -- its title to this exact item's cached name before interpreting absent lines.
    local title=result[1]
    if type(title)=="string" and type(item.name)=="string" then
        title=title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("^%s*(.-)%s*$")
        result.complete=title==item.name
    end
    if C_TooltipInfo and result.complete and (item.class==2 or item.class==4) then
        -- Read the rendered bag tooltip too. Some client versions materialize
        -- exclusion text only while the GameTooltip processes its data.
        for _,text in ipairs(self:RenderedTooltip(item)) do result[#result+1]=text end
    end
    return result
end
function S:HasLine(lines,text)
    if type(text)~="string" or text=="" then return false end
    for _,line in ipairs(lines) do
        line=line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        if line:find(text,1,true) then return true end
    end
    return false
end
function S:Location(item)
    if ItemLocation and ItemLocation.CreateFromBagAndSlot then return ItemLocation:CreateFromBagAndSlot(item.bag,item.slot) end
end
function S:IsBound(item,lines)
    local loc=self:Location(item)
    if loc and C_Item and C_Item.IsBound then return C_Item.IsBound(loc) end
    return self:HasLine(lines,ITEM_SOULBOUND) or self:HasLine(lines,ITEM_ACCOUNTBOUND) or self:HasLine(lines,ITEM_BNETACCOUNTBOUND)
end
function S:IsWarbound(item,lines)
    local loc=self:Location(item)
    if loc and C_Item and C_Item.IsBoundToAccountUntilEquip then return C_Item.IsBoundToAccountUntilEquip(loc) end
    return self:HasLine(lines,ITEM_ACCOUNTBOUND_UNTIL_EQUIP)
end
function S:InSet(item)
    if C_Container and C_Container.GetContainerItemEquipmentSetInfo then
        return C_Container.GetContainerItemEquipmentSetInfo(item.bag,item.slot)
    end
    if C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs and C_EquipmentSet.GetItemIDs then
        for _,set in ipairs(C_EquipmentSet.GetEquipmentSetIDs()) do
            for _,id in pairs(C_EquipmentSet.GetItemIDs(set) or {}) do if id==item.id then return true end end
        end
    elseif GetNumEquipmentSets and GetEquipmentSetInfo and GetEquipmentSetItemIDs then
        for i=1,GetNumEquipmentSets() do
            local name=GetEquipmentSetInfo(i)
            if name then for _,id in pairs(GetEquipmentSetItemIDs(name) or {}) do if id==item.id then return true end end end
        end
    end
    return false
end
function S:IsBusy()
    return (UnitCastingInfo and UnitCastingInfo("player")) or (UnitChannelInfo and UnitChannelInfo("player"))
end

function S:RenderedTooltip(item)
    if not self.renderScanner then
        self.renderScanner=CreateFrame("GameTooltip","ShatterBarRenderedTooltip",UIParent,"GameTooltipTemplate")
    end
    local tooltip=self.renderScanner
    tooltip:SetOwner(UIParent,"ANCHOR_NONE")
    tooltip:ClearLines()
    tooltip:SetBagItem(item.bag,item.slot)
    local lines={}
    for i=1,tooltip:NumLines() do
        for _,side in ipairs({"Left","Right"}) do
            local font=_G["ShatterBarRenderedTooltipText"..side..i]
            local text=font and font:GetText()
            if type(text)=="string" then lines[#lines+1]=text end
        end
    end
    tooltip:Hide()
    return lines
end

function S:HasExactLine(lines,text)
    if type(text)~="string" or text=="" then return false end
    for _,line in ipairs(lines) do
        local clean=line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("^%s*(.-)%s*$")
        if clean==text then return true end
    end
    return false
end
function S:BoxAction(item,lines)
    if item.class~=15 then return end
    -- Only the standalone lock-state line counts, not a name such as
    -- "Locked Chest" or description mentioning locked items.
    if self:HasExactLine(lines,LOCKED) then return "pick" end
    if lines.complete and ns.lockboxes and ns.lockboxes[item.id] then return "open" end
end
