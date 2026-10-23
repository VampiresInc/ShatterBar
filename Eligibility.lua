local _,ns=...
local S=ns.S
local L=ns.L
local function plain(text)
    return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("^%s*(.-)%s*$")
end
local function escape(text)
    return (text:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end
-- Build an anchored pattern from the client's localized format, including
-- positional tokens such as %2$d. Only the client-owned requirement line counts.
function S:DisenchantRequirement(line)
    local format=ITEM_DISENCHANT_MIN_SKILL
    if type(format)~="string" or format=="" then return end
    local parts,types,cursor={},{},1
    while true do
        local first,last,token=format:find("(%%[%d%$]*[sd])",cursor)
        if not first then parts[#parts+1]=escape(format:sub(cursor)); break end
        parts[#parts+1]=escape(format:sub(cursor,first-1))
        local kind=token:sub(-1)
        parts[#parts+1]=kind=="d" and "(%d+)" or "(.-)"
        types[#types+1]=kind
        cursor=last+1
    end
    if #types==0 then return end
    local values={plain(line):match("^"..table.concat(parts).."$")}
    if #values==0 then return end
    local rank,skill
    for i,kind in ipairs(types) do
        if kind=="d" then rank=tonumber(values[i]) else skill=values[i] end
    end
    return rank,skill
end
function S:EnchantingRank(skillName)
    if GetProfessions and GetProfessionInfo then
        for _,index in pairs({GetProfessions()}) do
            local name,_,rank,_,_,_,id=GetProfessionInfo(index)
            if name==skillName or (id==333 and not skillName) then return tonumber(rank) end
        end
    end
    if GetNumSkillLines and GetSkillLineInfo then
        for i=1,GetNumSkillLines() do
            local name,header,_,rank=GetSkillLineInfo(i)
            if not header and name==skillName then return tonumber(rank) end
        end
    end
end
function S:CanDisenchant(item,lines)
    if ns.noDisenchant and ns.noDisenchant[item.id] then return false end
    if C_Item and C_Item.IsCosmeticItem and C_Item.IsCosmeticItem(item.id) then return false end
    -- A negative marker always wins, even if a tooltip contains other markers.
    if self:HasLine(lines,ITEM_DISENCHANT_NOT_DISENCHANTABLE) then return false end
    local confirmed=false
    for _,line in ipairs(lines) do
        if type(ITEM_DISENCHANT_ANY_SKILL)=="string" and ITEM_DISENCHANT_ANY_SKILL~=""
            and plain(line)==plain(ITEM_DISENCHANT_ANY_SKILL) then confirmed=true end
        local minimum,skill=self:DisenchantRequirement(line)
        if minimum then
            local rank=self:EnchantingRank(skill)
            if not rank or rank<minimum then return false end
            confirmed=true
        end
    end
    if confirmed then return true end
    -- Retail/Forever do not consistently print a positive "Disenchantable"
    -- line. For their ordinary equipment, use the populated client tooltip's
    -- explicit exclusion line; never interpret missing tooltip data as consent.
    local build=GetBuildInfo and select(4,GetBuildInfo()) or 0
    local modern=ns.forever or build>=80000 or (build>=16000 and build<20000)
    return not not (modern and lines.complete and type(ITEM_DISENCHANT_NOT_DISENCHANTABLE)=="string"
        and ITEM_DISENCHANT_NOT_DISENCHANTABLE~="")
end

function S:DebugEligibility()
    if self:InCombat() then self:Print(L["Run this outside combat."]); return end
    local report={version=self.version,client=self:Client(),
        negative=tostring(ITEM_DISENCHANT_NOT_DISENCHANTABLE),
        positive=tostring(ITEM_DISENCHANT_ANY_SKILL),items={}}
    for bag=0,(NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
        for slot=1,self:Slots(bag) do
            local item=self:BagItem(bag,slot)
            if item and self:ItemDetails(item) and (item.class==2 or item.class==4) then
                local lines=self:Tooltip(item)
                report.items[#report.items+1]={id=item.id,name=item.name,bag=bag,slot=slot,
                    complete=not not lines.complete,allowed=self:CanDisenchant(item,lines),
                    negative=self:HasLine(lines,ITEM_DISENCHANT_NOT_DISENCHANTABLE),lines=lines,
                    rendered=self:RenderedTooltip(item)}
            end
        end
    end
    self.db.diagnostics=report
    self:Print(string.format(L["Saved eligibility report for %d equipment items. Type /reload to write it to disk."],#report.items))
end
