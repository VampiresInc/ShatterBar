local addon, ns = ...
local L=ns.L
local S = CreateFrame("Frame")
ns.S = S
S.L = L
_G.ShatterBar = S
S.version = "0.1.14"
S.defaults = {language="auto", hideBar=false, hideEmpty=true, hideCombat=true, hidePetBattle=true,
    maxItems=8, scale=1, fontSize=11, direction="RIGHT", itemTooltip=true,
    professionTooltip=true, showSoulbound=false, showWarbound=false, hideSets=true,
    hideTabards=true, includeWarbandOre=false, includeWarbandHerbs=false, positions={}, ignore={}}
S.kinds = {
    {key="de", label=L["Disenchant"], spell=13262, batch=1},
    {key="prospect", label=L["Prospect"], spell=31252, batch=5},
    {key="mill", label=L["Mill"], spell=51005, batch=5},
    {key="unlock", label=L["Pick Lock"], spell=1804, batch=1},
}
function S:Print(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff71d5ffShatterBar:|r "..tostring(text)) end
end
local function defaults(target, source)
    for k,v in pairs(source) do
        if type(v)=="table" then
            if type(target[k])~="table" then target[k]={} end
            defaults(target[k],v)
        elseif type(target[k])~=type(v) then target[k]=v end
    end
end
function S:Initialize()
    if self.db then return end
    if type(ShatterBarDB)~="table" then ShatterBarDB={} end
    self.db=ShatterBarDB
    defaults(self.db,self.defaults)
    if self.db.language~="auto" and not ns.translations[self.db.language] then self.db.language="auto" end
    ns.SetLocale(self.db.language)
    for index,key in ipairs({"Disenchant","Prospect","Mill","Pick Lock"}) do
        self.kinds[index].label=L[key]
    end
    self:UpdateBindingNames()
    self.db.enabled=nil -- Profession bars now follow learned skills/recipes automatically.
    self.db.maxItems=math.max(1,math.min(50,self.db.maxItems))
    self.db.scale=math.max(.5,math.min(2,self.db.scale))
    self.db.fontSize=math.max(8,math.min(24,self.db.fontSize))
    if not ({RIGHT=true,LEFT=true,UP=true,DOWN=true})[self.db.direction] then self.db.direction="RIGHT" end
    self:CreateUI()
    self:CreateOptions()
    self:InstallProspectingTrace()
    self.dirty=true
end
function S:Refresh()
    if not self.db or self:InCombat() then self.dirty=true; return end
    self.dirty=false
    self.lists=self:Scan()
    self:Render()
end
S:SetScript("OnEvent",function(self,event,...)
    if event=="ADDON_LOADED" then
        if (...)==addon then self:Initialize() end
    elseif event=="PLAYER_REGEN_ENABLED" then self:Refresh()
    else self.dirty=true end
end)
for _,event in ipairs({"ADDON_LOADED","PLAYER_LOGIN","BAG_UPDATE","BAG_UPDATE_DELAYED",
    "BANKFRAME_OPENED","BANKFRAME_CLOSED","PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED","PLAYERBANKSLOTS_CHANGED",
    "TRADE_SKILL_LIST_UPDATE","TRADE_SKILL_DATA_SOURCE_CHANGED","TRADE_SKILL_SHOW","NEW_RECIPE_LEARNED",
    "LOOT_CLOSED","LOOT_OPENED","ITEM_LOCK_CHANGED","GET_ITEM_INFO_RECEIVED","SPELLS_CHANGED","SKILL_LINES_CHANGED",
    "PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","PLAYER_EQUIPMENT_CHANGED",
    "EQUIPMENT_SETS_CHANGED","PET_BATTLE_OPENING_START","PET_BATTLE_CLOSE",
    "UNIT_SPELLCAST_SUCCEEDED","UNIT_SPELLCAST_STOP","UNIT_SPELLCAST_INTERRUPTED"}) do
    pcall(S.RegisterEvent,S,event)
end
local elapsed=0
S:SetScript("OnUpdate",function(self,dt)
    self:PollWarbandAvailability(dt)
    elapsed=elapsed+dt
    if elapsed<.2 then return end
    elapsed=0
    if self.dirty and not self:InCombat() then self:Refresh() end
end)
SLASH_SHATTERBAR1="/shatterbar"
SLASH_SHATTERBAR2="/shatter"
SLASH_SHATTERBAR3="/sb"
SlashCmdList.SHATTERBAR=function(message)
    if not S.db then return end
    message=(message or ""):lower()
    if message=="milldebug" then S:DebugProspecting("mill")
    elseif message=="prospectdebug" then S:DebugProspecting()
    elseif message=="debug" then S:DebugEligibility()
    elseif message=="status" then
        S:Print("v"..S.version.." / "..S:Client().." / "..(S:InCombat() and L["combat: paused"] or L["ready"]))
        for _,kind in ipairs(S.kinds) do S:Print(string.format(L["%s: %d listed"],kind.label,#((S.lists or {})[kind.key] or {}))) end
    elseif message=="reset" then S.db.positions={}; S:Refresh()
    else S:OpenOptions() end
end
