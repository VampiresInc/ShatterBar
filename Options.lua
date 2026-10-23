local _,ns=...
local S=ns.S
local L=ns.L
local serial=0
local function label(parent,text,x,y,font)
    local f=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlight")
    f:SetPoint("TOPLEFT",x,y); f:SetWidth(590); f:SetJustifyH("LEFT"); f:SetText(text); return f
end
local function button(parent,text,x,y,width,callback)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetSize(width or 190,24); b:SetPoint("TOPLEFT",x,y); b:SetText(text)
    b:SetScript("OnClick",callback); return b
end
function S:UpdateIgnored()
    if not self.ignoredText then return end
    local rows={}
    local fn=C_Item and C_Item.GetItemInfo or GetItemInfo
    for id in pairs(self.db.ignore) do
        rows[#rows+1]=tostring(id).." - "..tostring(fn and fn(id) or L["Item data not cached"])
    end
    table.sort(rows)
    self.ignoredText:SetText(#rows>0 and table.concat(rows,"\n") or L["No ignored items."])
    self.content:SetHeight((self.optionsBaseHeight or 1100)+math.max(80,self.ignoredText:GetStringHeight() or #rows*16))
end
function S:BindingLabel(button,name,title)
    local key=GetBindingKey and GetBindingKey("CLICK "..name..":LeftButton")
    button:SetText(title..": "..(key or L["Unbound"]))
end
function S:CaptureBinding(button,name,title)
    if self:InCombat() then self:Print(L["Change keybindings outside combat."]); return end
    local capture=self.capture
    if not capture then
        capture=CreateFrame("Frame",nil,UIParent)
        capture:SetFrameStrata("DIALOG"); capture:SetSize(1,1)
        self.capture=capture
    end
    capture:EnableKeyboard(true)
    if capture.SetPropagateKeyboardInput then capture:SetPropagateKeyboardInput(false) end
    button:SetText(L["Press a key (Esc cancels)"])
    capture:SetScript("OnKeyDown",function(frame,key)
        if key=="LSHIFT" or key=="RSHIFT" or key=="LCTRL" or key=="RCTRL" or key=="LALT" or key=="RALT" then return end
        if not S:InCombat() and key~="ESCAPE" then
            if key~="BACKSPACE" and key~="DELETE" then
                if IsShiftKeyDown() then key="SHIFT-"..key end
                if IsControlKeyDown() then key="CTRL-"..key end
                if IsAltKeyDown() then key="ALT-"..key end
            end
            local command="CLICK "..name..":LeftButton"
            local old={GetBindingKey(command)}
            for _,bound in ipairs(old) do SetBinding(bound) end
            if key~="BACKSPACE" and key~="DELETE" then SetBindingClick(key,name,"LeftButton") end
            if SaveBindings then SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1) end
        end
        frame:EnableKeyboard(false); frame:Hide()
        S:BindingLabel(button,name,title)
    end)
    capture:Show()
end
function S:CreateOptions()
    local panel=CreateFrame("Frame","ShatterBarOptions")
    panel.name="ShatterBar"
    label(panel,"ShatterBar "..self.version.." - by Arametheus",16,-16,"GameFontNormalLarge")
    panel:SetScript("OnHide",function()
        if S.capture then S.capture:EnableKeyboard(false); S.capture:Hide() end
        if S.languageMenu then S.languageMenu:Hide() end
    end)
    local scroll=CreateFrame("ScrollFrame","ShatterBarOptionsScroll",panel,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",8,-48); scroll:SetPoint("BOTTOMRIGHT",-30,8)
    local content=CreateFrame("Frame",nil,scroll); content:SetSize(620,1100); scroll:SetScrollChild(content)
    self.options,self.content=panel,content
    local y=-8
    local intro=label(content,L["Profession bars for disenchanting, prospecting, milling, and lockpicking."],10,y)
    intro:SetWidth(590); intro:SetJustifyH("LEFT"); y=y-math.max(30,(intro:GetStringHeight() or 30)+12)
    local function hint(text)
        local f=label(content,text,12,y,"GameFontHighlightSmall")
        y=y-math.max(30,(f:GetStringHeight() or 30)+12)
    end
    local function heading(text) label(content,text,10,y,"GameFontNormalLarge"); y=y-29 end
    heading(L["Language"])
    local languageMenu=CreateFrame("Frame",nil,content)
    languageMenu:SetSize(300,#ns.languages*26+8)
    languageMenu:SetFrameStrata("DIALOG")
    local background=languageMenu:CreateTexture(nil,"BACKGROUND")
    background:SetAllPoints(); background:SetColorTexture(.06,.06,.06,1)
    local language
    local function updateLanguage()
        for _,entry in ipairs(ns.languages) do
            if entry[1]==S.db.language then
                language:SetText(entry[1]=="auto" and L[entry[2]] or entry[2]); return
            end
        end
    end
    language=button(content,"",12,y,300,function()
        if languageMenu:IsShown() then languageMenu:Hide() else languageMenu:Show() end
    end)
    languageMenu:SetPoint("TOPLEFT",language,"BOTTOMLEFT",0,-2)
    self.languageChoices={}
    for index,entry in ipairs(ns.languages) do
        local choice,label=entry[1],entry[2]
        self.languageChoices[index]=button(languageMenu,choice=="auto" and L[label] or label,
            4,-4-(index-1)*26,292,function()
                S.db.language=choice; updateLanguage(); languageMenu:Hide()
            end)
    end
    language:SetScript("OnShow",updateLanguage)
    languageMenu:Hide()
    self.languageMenu=languageMenu
    button(content,L["Reload UI"],330,y,240,function()
        if not S:InCombat() and ReloadUI then ReloadUI() end
    end)
    y=y-36
    hint(L["Language changes take effect after reloading the UI. Item and spell text follows your client."])
    local function check(key,text)
        serial=serial+1
        local b=CreateFrame("CheckButton","ShatterBarOption"..serial,content,"UICheckButtonTemplate")
        b:SetPoint("TOPLEFT",8,y); b:SetSize(26,26)
        local t=b.Text or _G[b:GetName().."Text"]; t:SetText(text); t:SetWidth(550); t:SetJustifyH("LEFT")
        b:SetScript("OnShow",function(self) self:SetChecked(S.db[key]) end)
        b:SetScript("OnClick",function(self) S.db[key]=not not self:GetChecked(); S:Refresh() end)
        y=y-math.max(32,(t:GetStringHeight() or 24)+12)
    end
    heading(L["Visibility"])
    check("hideBar",L["Hide all bars"]); check("hideEmpty",L["Hide empty bars"])
    check("hideCombat",L["Hide during combat"]); check("hidePetBattle",L["Hide during pet battles"])
    check("includeWarbandOre",L["Include Warband Bank ore (experimental)"])
    check("includeWarbandHerbs",L["Include Warband Bank herbs (experimental)"])
    hint(L["Retail recipes only. Carried items first; open the bank or relevant profession."])
    y=y-10; heading(L["Appearance"])
    local function number(key,text,min,max,step)
        local caption=label(content,text,12,y-5); caption:SetWidth(275)
        local e=CreateFrame("EditBox",nil,content,"InputBoxTemplate")
        e:SetSize(65,24); e:SetPoint("TOPLEFT",310,y); e:SetAutoFocus(false)
        e:SetScript("OnShow",function(self) self:SetText(tostring(S.db[key])) end)
        local function apply()
            local value=tonumber((e:GetText():gsub(",",".")))
            if value then S.db[key]=math.max(min,math.min(max,math.floor(value/step+.5)*step)) end
            e:SetText(tostring(S.db[key])); e:ClearFocus(); S:Refresh()
        end
        e:SetScript("OnEnterPressed",apply)
        e:SetScript("OnEscapePressed",function(self) self:SetText(tostring(S.db[key])); self:ClearFocus() end)
        button(content,L["Apply"],390,y,120,apply); y=y-math.max(40,(caption:GetStringHeight() or 28)+12)
    end
    number("maxItems",L["Maximum items per bar (1-50)"],1,50,1)
    number("scale",L["Button scale (0.5-2)"],.5,2,.1)
    number("fontSize",L["Count font size (8-24)"],8,24,1)
    local directionLabel=label(content,L["Bar growth direction"],12,y-5); directionLabel:SetWidth(275)
    local direction
    direction=button(content,"",310,y,200,function()
        local nextDirection={RIGHT="DOWN",DOWN="LEFT",LEFT="UP",UP="RIGHT"}
        S.db.direction=nextDirection[S.db.direction]; direction:SetText(L[S.db.direction]); S:Refresh()
    end)
    direction:SetScript("OnShow",function(b) b:SetText(L[S.db.direction]) end)
    y=y-37
    check("itemTooltip",L["Item tooltips"]); check("professionTooltip",L["Profession tooltips"])
    y=y-10; heading(L["Disenchanting filters"])
    check("showSoulbound",L["Show soulbound items"]); check("showWarbound",L["Show warbound items"])
    check("hideSets",L["Hide equipment set items"]); check("hideTabards",L["Hide tabards"])
    y=y-10; heading(L["Keybindings"])
    hint(L["One press processes one item or batch. Bindings replace any existing use of that key."])
    hint(L["Escape cancels; Backspace or Delete clears. Combat pauses all processing."])
    local bindings={{"ShatterBarFirst",L["First available"]}}
    for _,kind in ipairs(self.kinds) do bindings[#bindings+1]={"ShatterBarFirst_"..kind.key,kind.label} end
    for _,entry in ipairs(bindings) do
        local b
        b=button(content,"",12,y,410,function() S:CaptureBinding(b,entry[1],entry[2]) end)
        b:SetScript("OnShow",function(self) S:BindingLabel(self,entry[1],entry[2]) end)
        y=y-28
    end
    y=y-10; heading(L["Placement"])
    button(content,L["Reset bar positions"],12,y,300,function() S.db.positions={}; S:Refresh() end)
    y=y-38; heading(L["Ignored items"])
    hint(L["Right-click an item on a bar to ignore that item type. Enter its ID below to restore it."])
    local restore=CreateFrame("EditBox",nil,content,"InputBoxTemplate")
    restore:SetSize(100,24); restore:SetPoint("TOPLEFT",17,y); restore:SetAutoFocus(false); restore:SetNumeric(true)
    button(content,L["Restore item ID"],130,y,230,function()
        local id=tonumber(restore:GetText())
        if id then S.db.ignore[id]=nil; S:UpdateIgnored(); S:Refresh() end
        restore:SetText(""); restore:ClearFocus()
    end)
    button(content,L["Restore all"],380,y,200,function() S.db.ignore={}; S:UpdateIgnored(); S:Refresh() end)
    y=y-36
    self.optionsBaseHeight=-y+30
    self.ignoredText=label(content,"",12,y,"GameFontHighlightSmall")
    self.ignoredText:SetWidth(590); self.ignoredText:SetJustifyH("LEFT")
    panel:SetScript("OnShow",function() S:UpdateIgnored() end)
    panel:Hide()
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        self.settingsCategory=Settings.RegisterCanvasLayoutCategory(panel,"ShatterBar")
        Settings.RegisterAddOnCategory(self.settingsCategory)
    elseif InterfaceOptions_AddCategory then InterfaceOptions_AddCategory(panel) end
end
function S:OpenOptions()
    if self:InCombat() then self:Print(L["Open options outside combat."]); return end
    if self.settingsCategory and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(self.settingsCategory:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(self.options)
    else
        self:Print(L["Open the game options and select AddOns > ShatterBar."])
    end
end
