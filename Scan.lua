local _,ns=...
local S=ns.S
-- Eligibility comes from the client's localized tooltip, not guessed ore/herb IDs.
function S:Classify(item,lines,known)
    local db=self.db
    if db.ignore[item.id] or item.locked then return end
    local recipe,batch=self:ProspectRecipe(item)
    if recipe then
        item.recipe,item.batch=recipe,batch
        return "prospect"
    end
    if known.prospect and self:Knows(31252) and self:HasLine(lines,ITEM_PROSPECTABLE)
        and not self:UsesRecipeProspecting() then return "prospect" end
    local millRecipe,millBatch=self:ItemRecipe(item,"mill")
    if millRecipe then
        item.recipe,item.batch=millRecipe,millBatch
        return "mill"
    end
    if known.mill and self:HasLine(lines,ITEM_MILLABLE) and not self:UsesRecipeAction("mill") then return "mill" end
    if known.unlock then
        item.boxAction=self:BoxAction(item,lines)
        if item.boxAction then return "unlock" end
    end
    -- Equipment checks alone do not establish disenchantability. Require
    -- positive evidence from the client tooltip before adding any target.
    if known.de and item.quality and item.quality>=2 and item.quality<=4
        and (item.class==2 or item.class==4) and item.equip and item.equip~=""
        and item.equip~="INVTYPE_BAG" and item.equip~="INVTYPE_BODY"
        and not (item.class==2 and item.subclass==20)
        and not (item.class==4 and item.subclass==5) then
        if db.hideTabards and item.equip=="INVTYPE_TABARD" then return end
        if db.hideSets and self:InSet(item) then return end
        if not db.showWarbound and self:IsWarbound(item,lines) then return end
        if not db.showSoulbound and self:IsBound(item,lines) then return end
        if self:CanDisenchant(item,lines) then return "de" end
    end
end
function S:Scan()
    self.recipeCache={}
    local lists,known,grouped={},{},{}
    for _,kind in ipairs(self.kinds) do
        lists[kind.key]={}
        known[kind.key]=self:CanUseKind(kind)
        grouped[kind.key]={}
    end
    for bag=0,(NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
        for slot=1,self:Slots(bag) do
            local item=self:BagItem(bag,slot)
            if item and not self.db.ignore[item.id] and self:ItemDetails(item) then
                local kind=self:Classify(item,self:Tooltip(item),known)
                if kind then
                    -- Boxes of the same item ID can have different lock states.
                    local key=kind=="unlock" and (item.bag..":"..item.slot) or item.id
                    local group=grouped[kind][key]
                    if not group then group={id=item.id,total=0,carried=0,warband=0,stacks={}}; grouped[kind][key]=group end
                    group.total=group.total+item.count
                    group.carried=group.carried+item.count
                    group.stacks[#group.stacks+1]=item
                end
            end
        end
    end
    local bankItems=self:BankMaterials()
    self.warbandSignature=self:WarbandSignature(bankItems)
    for _,item in ipairs(bankItems) do
        local destination=grouped[item.kindKey or "prospect"]
        local group=destination[item.id]
        if not group then group={id=item.id,total=0,carried=0,warband=0,stacks={}}; destination[item.id]=group end
        group.total=group.total+item.count
        group.warband=group.warband+item.count
        group.stacks[#group.stacks+1]=item
    end
    for _,kind in ipairs(self.kinds) do
        for _,group in pairs(grouped[kind.key]) do
            local target,operations=nil,0
            for _,item in ipairs(group.stacks) do
                local batch=item.batch or kind.batch
                operations=operations+math.floor(item.count/batch)
                if item.count>=batch and not target then target=item end
            end
            -- Never target a short stack just because the bag total is sufficient.
            if target then
                target.total,target.operations=group.total,operations
                target.carriedTotal,target.warbandTotal=group.carried,group.warband
                lists[kind.key][#lists[kind.key]+1]=target
            end
        end
        table.sort(lists[kind.key],function(a,b)
            if kind.key=="unlock" and a.boxAction~=b.boxAction then return a.boxAction=="open" end
            if (a.source=="warband")~=(b.source=="warband") then return a.source~="warband" end
            if a.name~=b.name then return a.name<b.name end
            if a.id~=b.id then return a.id<b.id end
            if a.bag~=b.bag then return a.bag<b.bag end
            return a.slot<b.slot
        end)
    end
    return lists
end
