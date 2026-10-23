local _,ns=...
local S=ns.S
local L=ns.L
function S:RecipeMap(kind)
    if kind=="mill" then return ns.millRecipes end
    if kind=="prospect" then return ns.prospectRecipes end
end
function S:UsesRecipeAction(kind)
    return self:RecipeMap(kind) and C_TradeSkillUI and C_TradeSkillUI.CraftSalvage
        and C_TradeSkillUI.GetRecipeInfo and ItemLocation and ItemLocation.CreateFromBagAndSlot
end
function S:UsesRecipeProspecting() return self:UsesRecipeAction("prospect") end
function S:RecipeLearned(id)
    self.recipeCache=self.recipeCache or {}
    if self.recipeCache[id]~=nil then return self.recipeCache[id] end
    local learned=false
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
        local ok,info=pcall(C_TradeSkillUI.GetRecipeInfo,id)
        if ok and info then learned=info.learned==true end
    end
    if not learned then learned=not not self:Knows(id) end
    self.recipeCache[id]=learned
    return learned
end
function S:ItemRecipe(item,kind)
    if not self:UsesRecipeAction(kind) then return end
    local entry=self:RecipeMap(kind)[item.id]
    if entry and self:RecipeLearned(entry[1]) then return entry[1],entry[2] end
end
function S:ProspectRecipe(item) return self:ItemRecipe(item,"prospect") end
function S:CanUseKind(kind)
    if self:UsesRecipeAction(kind.key) then
        for _,entry in pairs(self:RecipeMap(kind.key)) do
            if self:RecipeLearned(entry[1]) then return true end
        end
        return false
    end
    return self:Knows(kind.spell)
end

function S:DebugProspecting(kind)
    kind=kind or "prospect"
    local map=self:RecipeMap(kind) or {}
    if self:InCombat() then self:Print(L["Run this outside combat."]); return end
    self.recipeCache={}
    local report={version=self.version,client=self:Client(),legacySpell=not not self:Knows(kind=="mill" and 51005 or 31252),
        recipeMode=not not self:UsesRecipeAction(kind),items={}}
    for bag=0,(NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
        for slot=1,self:Slots(bag) do
            local item=self:BagItem(bag,slot)
            if item and self:ItemDetails(item) then
                local entry=map[item.id]
                if entry or (item.class==7 and item.subclass==(kind=="mill" and 9 or 7)) then
                    report.items[#report.items+1]={id=item.id,name=item.name,count=item.count,bag=bag,slot=slot,
                        recipe=entry and entry[1],batch=entry and entry[2],
                        learned=entry and self:RecipeLearned(entry[1]) or false}
                end
            end
        end
    end
    report.nativeSelection=self:NativeProspectingSelection()
    report.nativeCraftTrace=self.db.nativeCraftTrace
    report.nativeTargetQueryIDs=self.db.nativeTargetQueryIDs
    if self.db.nativeTargetQueryIDs and C_TradeSkillUI and C_TradeSkillUI.GetCraftingTargetItems then
        self.bankQueryRunning=true
        local ok,targets=pcall(C_TradeSkillUI.GetCraftingTargetItems,self.db.nativeTargetQueryIDs)
        self.bankQueryRunning=false
        if ok then report.nativeQueryTargets=targets end
    end
    report.warbandItems=self:WarbandMaterials(kind)
    report.warbandStatus=kind=="mill" and self.warbandHerbStatus or self.warbandStatus
    self.db[kind=="mill" and "millDiagnostics" or "prospectDiagnostics"]=report
    self:Print(string.format(L["Saved %s report for %d carried stacks. /reload writes it to disk."],L[kind=="mill" and "Mill" or "Prospect"],#report.items))
end

function S:IsWarbandBag(bag)
    if type(bag)~="number" or not Enum or not Enum.BagIndex then return false end
    for name,id in pairs(Enum.BagIndex) do
        if type(name)=="string" and name:match("^AccountBankTab_") and id==bag then return true end
    end
    return false
end
function S:WarbandMaterials(kind)
    local flag=kind=="mill" and "includeWarbandHerbs" or "includeWarbandOre"
    local status={enabled=not not self.db[flag],targets=0,resolved=0,samples={}}
    if kind=="mill" then self.warbandHerbStatus=status else self.warbandStatus=status end
    if not self.db[flag] or not self:UsesRecipeAction(kind) then return {} end
    local map=self:RecipeMap(kind)
    if not C_TradeSkillUI.GetCraftingTargetItems or not C_Item or not C_Item.GetItemLocation
        or not Enum or not Enum.BagIndex then
        status.reason="Client target/location APIs unavailable"
        return {}
    end
    local ids={}
    for id,entry in pairs(map) do
        if not self.db.ignore[id] and self:RecipeLearned(entry[1]) then ids[#ids+1]=id end
    end
    if #ids==0 then status.reason="No learned recipes"; return {} end
    table.sort(ids)
    self.bankQueryRunning=true
    local ok,targets=pcall(C_TradeSkillUI.GetCraftingTargetItems,ids)
    self.bankQueryRunning=false
    if not ok or type(targets)~="table" then
        status.reason="Crafting target query unavailable"
        return {}
    end
    local found,seen={},{}
    for _,target in ipairs(targets) do
        status.targets=status.targets+1
        local guid=target.itemGUID
        local entry=map[target.itemID]
        if entry and not self.db.ignore[target.itemID] and self:RecipeLearned(entry[1])
            and type(guid)=="string" and guid:match("^Item%-[%w%-]+$") and not seen[guid] then
            seen[guid]=true
            local resolved,loc=pcall(C_Item.GetItemLocation,guid)
            if #status.samples<20 then
                local sample={id=target.itemID,guid=guid,quantity=target.quantity,locationResolved=resolved and loc~=nil,fields={}}
                if resolved and type(loc)=="table" then
                    for key,value in pairs(loc) do
                        if type(key)=="string" and (type(value)=="number" or type(value)=="string" or type(value)=="boolean") then
                            sample.fields[key]=value
                        end
                    end
                end
                status.samples[#status.samples+1]=sample
            end
            if resolved and loc then
                local bag,slot=loc.bagID,loc.slotIndex
                if loc.GetBagAndSlot then bag,slot=loc:GetBagAndSlot() end
                if self:IsWarbandBag(bag) and type(slot)=="number" and slot>=1 then
                    -- Match Blizzard's native salvage transaction: resolve the
                    -- crafting target GUID without requiring a reverse slot lookup.
                    local item={id=target.itemID,link=target.hyperlink,count=target.quantity or 0,
                        bag=bag,slot=slot,guid=guid,source="warband",kindKey=kind,recipe=entry[1],batch=entry[2]}
                    local slotItem=self:BagItem(bag,slot)
                    if not (slotItem and slotItem.locked) and self:ItemDetails(item) then
                        found[#found+1]=item
                        status.resolved=status.resolved+1
                    end
                end
            end
        end
    end
    table.sort(found,function(a,b) if a.bag~=b.bag then return a.bag<b.bag end; return a.slot<b.slot end)
    if #found==0 then status.reason="No accessible Warband Bank targets" end
    return found
end

function S:WarbandOre() return self:WarbandMaterials("prospect") end
function S:BankMaterials()
    local items=self:WarbandOre()
    for _,item in ipairs(self:WarbandMaterials("mill")) do items[#items+1]=item end
    return items
end

local function fields(location)
    local out={}
    if type(location)=="table" then
        for key,value in pairs(location) do
            if type(key)=="string" and (type(value)=="string" or type(value)=="number" or type(value)=="boolean") then out[key]=value end
        end
    end
    return out
end
function S:NativeProspectingSelection()
    local page=ProfessionsFrame and ProfessionsFrame.CraftingPage
    local form=page and page.SchematicForm
    if not form or not form.GetTransaction then return {available=false} end
    local transaction=form:GetTransaction()
    if not transaction then return {available=false} end
    local item=transaction.GetSalvageAllocation and transaction:GetSalvageAllocation()
    local report={available=true,recipe=transaction.recipeID,selected=item~=nil}
    if item then
        if item.GetItemGUID then report.guid=item:GetItemGUID() end
        if item.GetItemID then report.id=item:GetItemID() end
        if item.GetStackCount then local ok,count=pcall(item.GetStackCount,item); if ok then report.quantity=count end end
        if report.guid and C_Item and C_Item.GetItemLocation then
            local ok,location=pcall(C_Item.GetItemLocation,report.guid)
            report.locationResolved=ok and location~=nil
            if ok then report.location=fields(location) end
        end
    end
    return report
end
function S:InstallProspectingTrace()
    if self.prospectingTraceInstalled or not hooksecurefunc or not C_TradeSkillUI then return end
    self.prospectingTraceInstalled=true
    if C_TradeSkillUI.GetCraftingTargetItems then
        hooksecurefunc(C_TradeSkillUI,"GetCraftingTargetItems",function(ids)
            if not S.db or not (S.db.includeWarbandOre or S.db.includeWarbandHerbs) or S.bankQueryRunning or type(ids)~="table" then return end
            local copy={}
            for _,id in ipairs(ids) do if type(id)=="number" then copy[#copy+1]=id end end
            S.db.nativeTargetQueryIDs=copy
            S.dirty=true -- Native picker may have just made remote targets available.
        end)
    end
    if C_TradeSkillUI.CraftSalvage then
        hooksecurefunc(C_TradeSkillUI,"CraftSalvage",function(recipe,count,location,reagents,concentration)
            if not S.db or not (S.db.includeWarbandOre or S.db.includeWarbandHerbs) then return end
            S.db.nativeCraftTrace={recipe=recipe,count=count,locationType=type(location),location=fields(location),
                concentration=not not concentration,reagentCount=type(reagents)=="table" and #reagents or 0,
                selection=S:NativeProspectingSelection()}
        end)
    end
end

function S:WarbandSignature(items)
    local rows={}
    for _,item in ipairs(items) do
        rows[#rows+1]=table.concat({item.guid,item.id,item.count,item.bag,item.slot,item.recipe},":")
    end
    table.sort(rows)
    return table.concat(rows,";")
end
function S:PollWarbandAvailability(dt)
    if not self.db or self:InCombat() or not (
        (self.db.includeWarbandOre and self:UsesRecipeAction("prospect"))
        or (self.db.includeWarbandHerbs and self:UsesRecipeAction("mill"))) then
        self.warbandPollElapsed=0
        return
    end
    self.warbandPollElapsed=(self.warbandPollElapsed or 0)+dt
    if self.warbandPollElapsed<1 then return end
    self.warbandPollElapsed=0
    -- Account inventory can arrive asynchronously after professions open,
    -- without a bank-slot event. Only rebuild the UI when live targets change.
    local signature=self:WarbandSignature(self:BankMaterials())
    if signature~=self.warbandSignature then self.dirty=true end
end
