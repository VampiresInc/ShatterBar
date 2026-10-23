local _,ns=...
local S=ns.S
local L=ns.L
BINDING_HEADER_SHATTERBAR="ShatterBar"
local function bindingName(name,text) _G["BINDING_NAME_CLICK "..name..":LeftButton"]=text end
function S:UpdateBindingNames()
    bindingName("ShatterBarFirst",L["Process first item (first nonempty bar)"])
    for _,kind in ipairs(self.kinds) do bindingName("ShatterBarFirst_"..kind.key,string.format(L["%s: process first item"],kind.label)) end
end
local function secureButton(name,parent)
    local b=CreateFrame("Button",name,parent,"SecureActionButtonTemplate,SecureHandlerStateTemplate")
    b:RegisterForClicks("AnyUp")
    b:SetAttribute("useOnKeyDown",false)
    b:SetAttribute("_onstate-combat",[[
        if newstate == "1" then self:SetAttribute("type1",nil)
        else self:SetAttribute("type1",self:GetAttribute("ready-type")) end
    ]])
    if RegisterStateDriver then RegisterStateDriver(b,"combat","[combat] 1; 0") end
    b:SetScript("PreClick",function(self,button,down)
        if button~="LeftButton" or S:InCombat() then return end
        -- Revalidate exact bag positions on every physical activation, even if
        -- a BAG_UPDATE event has not yet reached the periodic refresh.
        local previous=self.item and self.item.id
        S:Refresh()
        if previous and (not self.item or self.item.id~=previous) and self:GetName():find("Item%d+$") then
            self:SetAttribute("type1",nil)
        end
        if S:IsBusy() then self:SetAttribute("type1",nil) end
    end)
    return b
end
function S:SetAction(button,kind,item,profession)
    button.kind,button.item=kind,item
    local name=self:Spell(kind.spell)
    local action,macro
    if item and kind.key=="unlock" and item.boxAction=="open" then
        action="item"
    elseif item and item.recipe and self:UsesRecipeAction(kind.key) then
        action="macro"
        -- Numeric recipe/bag/slot only; prepared outside combat and revalidated
        -- on every physical press. Never uses /use, which could equip an item.
        if item.source=="warband" then
            -- Re-resolve the specific GUID at click time; a bank slot can move.
            macro=string.format('/run local l=C_Item.GetItemLocation(%q);if l then C_TradeSkillUI.CraftSalvage(%d,1,l) end',
                item.guid,item.recipe)
        else
            macro=string.format("/run C_TradeSkillUI.CraftSalvage(%d,1,ItemLocation:CreateFromBagAndSlot(%d,%d))",
                item.recipe,item.bag,item.slot)
        end
    elseif name and (item or profession) then action="spell" end
    if profession and self:UsesRecipeAction(kind.key) then action=nil end
    if self.db.hideBar then action=nil end
    button:SetAttribute("ready-type",action)
    button:SetAttribute("type1",action)
    button:SetAttribute("macrotext",macro)
    button:SetAttribute("item",action=="item" and (item.bag.." "..item.slot) or nil)
    button:SetAttribute("spell",action=="spell" and name or nil)
    button:SetAttribute("target-bag",action=="spell" and item and item.bag or nil)
    button:SetAttribute("target-slot",action=="spell" and item and item.slot or nil)
end
function S:CreateUI()
    self.bars={}
    self.first=secureButton("ShatterBarFirst",UIParent)
    self.first:SetSize(1,1)
    self.first:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",-10,-10)
    self.proxies={}
    for index,kind in ipairs(self.kinds) do
        local bar=CreateFrame("Frame","ShatterBar_"..kind.key,UIParent,"SecureHandlerStateTemplate")
        bar:SetSize(36,36)
        bar:SetMovable(true)
        bar:SetClampedToScreen(true)
        bar.buttons={}
        local head=secureButton("ShatterBarProfession_"..kind.key,bar)
        head:SetSize(36,36)
        head:SetPoint("CENTER",bar,"CENTER")
        head:RegisterForDrag("LeftButton")
        head:SetScript("OnDragStart",function()
            if not S:InCombat() and IsShiftKeyDown() then bar:StartMoving() end
        end)
        head:SetScript("OnDragStop",function()
            if S:InCombat() then return end
            bar:StopMovingOrSizing()
            local p,_,rp,x,y=bar:GetPoint()
            S.db.positions[kind.key]={p=p,rp=rp,x=x,y=y}
        end)
        head:SetScript("OnEnter",function(b)
            if not S.db.professionTooltip then return end
            GameTooltip:SetOwner(b,"ANCHOR_RIGHT")
            GameTooltip:SetText(S:Spell(kind.spell) or kind.label)
            GameTooltip:AddLine(L["Click an item to process it."],1,1,1)
            if S:UsesRecipeAction(kind.key) then
                GameTooltip:AddLine(L[kind.key=="mill" and "Click this icon to open Inscription recipes." or "Click this icon to open Jewelcrafting recipes."],.5,.8,1)
            end
            GameTooltip:AddLine(L["Shift-drag this icon to move the bar."],.5,.8,1)
            GameTooltip:AddLine(L["Right-click this icon for options."],.5,.8,1)
            GameTooltip:Show()
        end)
        head:SetScript("OnLeave",function() GameTooltip:Hide() end)
        head:SetScript("PostClick",function(_,button)
            if button=="RightButton" then S:OpenOptions()
            elseif button=="LeftButton" and S:UsesRecipeAction(kind.key) and not S:InCombat() then
                if C_TradeSkillUI.OpenTradeSkill then C_TradeSkillUI.OpenTradeSkill(kind.key=="mill" and 773 or 755) end
            end
        end)
        head:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
        head.icon=head:CreateTexture(nil,"ARTWORK"); head.icon:SetAllPoints()
        head:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD")
        bar.head=head
        self.bars[kind.key]=bar
        local proxy=secureButton("ShatterBarFirst_"..kind.key,UIParent)
        proxy:SetSize(1,1); proxy:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",-10,-10)
        self.proxies[kind.key]=proxy
    end
end
function S:ItemButton(bar,index)
    if bar.buttons[index] then return bar.buttons[index] end
    local b=secureButton(bar:GetName().."Item"..index,bar)
    b:SetSize(36,36)
    b:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
    b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetAllPoints()
    b.count=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    b.count:SetPoint("BOTTOMRIGHT",-1,2)
    b.source=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    b.source:SetPoint("TOPLEFT",1,-1)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD")
    b:SetScript("OnEnter",function(self)
        if not S.db.itemTooltip or not self.item then return end
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        if self.item.source=="warband" and self.item.link then GameTooltip:SetHyperlink(self.item.link)
        else GameTooltip:SetBagItem(self.item.bag,self.item.slot) end
        if self.item.source=="warband" then GameTooltip:AddLine(L["Source: Warband Bank (experimental)"],.4,.85,1) end
        if self.item.warbandTotal and self.item.warbandTotal>0 then
            GameTooltip:AddLine(string.format(L["Bags: %d / Warband Bank: %d"],self.item.carriedTotal,self.item.warbandTotal),1,1,1)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format(L["Left-click: %s"],self.item.boxAction=="open" and L["Open lockbox"] or self.kind.label),.4,.85,1)
        GameTooltip:AddLine(L["Right-click: ignore this item type"],.4,.85,1)
        if self.kind.batch>1 then
            GameTooltip:AddLine(string.format(L["%d items / %d usable batches"],self.item.total,self.item.operations),1,1,1)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave",function() GameTooltip:Hide() end)
    b:SetScript("PostClick",function(self,button)
        if button=="RightButton" and self.item and not S:InCombat() then
            S.db.ignore[self.item.id]=true
            S:Print(string.format(L["Ignoring %s. Restore it in options."],self.item.link or self.item.name))
            GameTooltip:Hide()
            S:Refresh()
            if S.UpdateIgnored then S:UpdateIgnored() end
        end
    end)
    bar.buttons[index]=b
    return b
end
function S:Render()
    if self:InCombat() then self.dirty=true; return end
    local firstKind,firstItem
    local pet=C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle()
    local vectors={RIGHT={1,0},LEFT={-1,0},UP={0,1},DOWN={0,-1}}
    local vector=vectors[self.db.direction]
    for index,kind in ipairs(self.kinds) do
        local bar=self.bars[kind.key]
        local list=self.lists[kind.key]
        local visible=not self.db.hideBar and self:CanUseKind(kind)
            and not (self.db.hidePetBattle and pet) and (not self.db.hideEmpty or #list>0)
        bar:ClearAllPoints()
        local pos=self.db.positions[kind.key]
        if type(pos)=="table" and type(pos.p)=="string" and type(pos.x)=="number" and type(pos.y)=="number" then
            bar:SetPoint(pos.p,UIParent,pos.rp or pos.p,pos.x,pos.y)
        else bar:SetPoint("CENTER",UIParent,"CENTER",-200,100-(index-1)*52) end
        bar:SetScale(self.db.scale)
        self:SetAction(bar.head,kind,nil,true)
        local _,icon=self:Spell(kind.spell)
        bar.head.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        local count=math.min(#list,self.db.maxItems)
        for i=1,count do
            local button=self:ItemButton(bar,i)
            local item=list[i]
            button:ClearAllPoints()
            button:SetPoint("CENTER",bar.head,"CENTER",vector[1]*i*39,vector[2]*i*39)
            self:SetAction(button,kind,item)
            button.icon:SetTexture(item.icon)
            button.source:SetText(item.source=="warband" and "W" or (item.boxAction=="open" and L["Open"] or ""))
            button.count:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",self.db.fontSize,"OUTLINE")
            button.count:SetText(kind.batch>1 and (item.total.." ("..item.operations..")") or (item.total>1 and item.total or ""))
            button:Show()
        end
        for i=count+1,#bar.buttons do
            self:SetAction(bar.buttons[i],kind,nil)
            bar.buttons[i]:Hide()
        end
        self:SetAction(self.proxies[kind.key],kind,visible and list[1] or nil)
        if visible and list[1] and not firstItem then firstKind,firstItem=kind,list[1] end
        if RegisterStateDriver then
            -- The action buttons also independently disable their spell in combat.
            RegisterStateDriver(bar,"visibility",self.db.hideCombat and "[combat] hide; show" or "show")
        end
        if visible then bar:Show() else
            if UnregisterStateDriver then UnregisterStateDriver(bar,"visibility") end
            bar:Hide()
        end
    end
    self:SetAction(self.first,firstKind or self.kinds[1],firstItem)
end
