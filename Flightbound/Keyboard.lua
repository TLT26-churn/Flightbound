local _,F=...
local G,U=F.Game,F.UI
local directions={UP={0,-1},DOWN={0,1},LEFT={-1,0},RIGHT={1,0}}
local captured={UP=true,DOWN=true,LEFT=true,RIGHT=true,SPACE=true}
local numbers={}
for i=0,9 do
    local key=tostring(i);numbers[key]=key;numbers["NUMPAD"..key]=key
    captured[key]=true;captured["NUMPAD"..key]=true
end
local held={}
local function inCombat() return InCombatLockdown() end
local function typing() return GetCurrentKeyBoardFocus() end
local function isInside(frame)
    for _=1,40 do
        if not frame or frame.IsForbidden and frame:IsForbidden() then return false end
        if frame==U.frame then return true end
        frame=frame.GetParent and frame:GetParent()
    end
    return false
end
local function outsideKeyHeld()
    for key in pairs(captured) do if IsKeyDown(key) and not held[key] then return true end end
    return false
end
function U.CanFocusKeyboard()
    return G.db and G.db.settings.keyboard==true and U.frame and U.frame:IsShown()
        and not inCombat() and not typing()
end
function U.DungeonKeysAvailable()
    local d=G.db
    if U.duelView then return false end
    return d.trainer and d.dungeon and not d.battle and not d.scene and not d.pendingName
        and #d.evolutions==0 and (not U.page or U.page=="dungeon")
end
function U.BattleResultAvailable()
    if U.duelView then return U.resultAction and not U.effect and U.battleVisible and U.actions[1]:IsEnabled() end
    local b=G.db.battle
    return b and b.result and not U.effect and not G.db.pendingName and U.battleVisible
        and U.resultAction and U.actions[1]:IsEnabled()
end
function U.PageContinueAvailable()
    local b=U.advanceAction
    return b and not U.effect and b:IsShown() and b:IsEnabled() and b.callback
end
function U.UpdateKeyboardIndicator()
    if not U.keysToggle then return end
    local enabled=G.db.settings.keyboard==true
    local label="Keys: "..(enabled and "On" or "Off")
    if U.keysLabel~=label then U.keysToggle.label:SetText(label);U.keysLabel=label end
    local hint="Click Keys to enable keyboard controls"
    if enabled then
        if inCombat() then hint="Keys paused: combat"
        elseif typing() then hint="Keys paused: typing"
        elseif U.keyboardFocused then
            hint=(U.BattleResultAvailable() or U.PageContinueAvailable()) and "Space: "..U.actions[1].label:GetText().."\nEsc: release keys"
                or U.DungeonKeysAvailable() and "Arrows: move / Esc: release\nSpace: interact"
                or U.rowHotkeys and next(U.rowHotkeys) and (U.duelView and "1–3: swap / 0: back\nEsc: release keys" or "1–4: select / 0: back / Esc: release\n5: previous / 6: next")
                or U.battleHotkeys and next(U.battleHotkeys) and "Battle: number keys\nEsc: release keys"
                or "Keys active / Esc: release\nDungeon keys paused"
        elseif outsideKeyHeld() then hint="Release held keys"
        else hint="Click window to focus" end
    end
    if U.keysHintText~=hint then U.keysHint:SetText(U.Sentence(hint));U.keysHintText=hint end
    if U.keysOutline~=U.keyboardFocused then
        U.keysOutline=U.keyboardFocused
        for _,edge in ipairs(U.focusEdges) do if U.keyboardFocused then edge:Show() else edge:Hide() end end
    end
end
function U.ReleaseKeyboard(immediate)
    U.windowFocused=false;U.keyboardFocused=false
    -- Drain captured presses through transitions, so repeats cannot reach WoW.
    if immediate and next(held) then held={} end
    if U.keyboard and not next(held) then U.keyboard:Hide() end
    U.UpdateKeyboardIndicator()
end
local function suspendForField()
    U.keyboardFocused=false;held={};U.keyboard:Hide();U.UpdateKeyboardIndicator()
end
function U.FocusKeyboard()
    if not G.db.settings.keyboard or not U.frame:IsShown() or inCombat() then return end
    if typing() then
        -- An addon text field temporarily owns input; keep the window's focus
        -- so Save/Skip resumes controls without a second click on the map.
        if isInside(typing()) then U.windowFocused=true;suspendForField() end
        return
    end
    -- Never steal a movement/jump/action press which started outside Flightbound.
    if outsideKeyHeld() then U.UpdateKeyboardIndicator();return end
    U.windowFocused=true;U.keyboardFocused=true
    U.keyboard:SetPropagateKeyboardInput(true);U.keyboard:EnableKeyboard(true);U.keyboard:Show()
    U.UpdateKeyboardIndicator()
end
function U.SetKeyboard(enabled,focus)
    G.db.settings.keyboard=enabled==true
    if not enabled then U.ReleaseKeyboard()
    elseif focus then U.FocusKeyboard() end
    U.UpdateKeyboardIndicator()
end
function U.CheckKeyboardFocus()
    if not U.keyboard then return end
    for key in pairs(held) do if not IsKeyDown(key) then held[key]=nil end end
    if not U.keyboardFocused and not next(held) then U.keyboard:Hide() end
    if inCombat() or not U.frame:IsShown() then U.ReleaseKeyboard(true)
    elseif not G.db.settings.keyboard then U.ReleaseKeyboard()
    elseif typing() then
        if isInside(typing()) then suspendForField() else U.ReleaseKeyboard(true) end
    elseif U.windowFocused and not U.keyboardFocused then U.FocusKeyboard() end
    U.UpdateKeyboardIndicator()
end
function U.BuildKeyboard()
    local keys=CreateFrame("Frame",nil,U.frame);U.keyboard=keys
    keys:SetSize(1,1);keys:SetPoint("TOPLEFT",U.frame,"TOPLEFT",0,0);keys:Hide()
    keys:SetScript("OnKeyDown",function(self,key)
        -- Never call restricted propagation APIs during WoW combat.
        if inCombat() then U.ReleaseKeyboard(true);return end
        if typing() then
            self:SetPropagateKeyboardInput(true)
            if isInside(typing()) then suspendForField() else U.ReleaseKeyboard(true) end
            return
        end
        if held[key] then self:SetPropagateKeyboardInput(false);return end
        if not U.keyboardFocused or not U.CanFocusKeyboard() then
            self:SetPropagateKeyboardInput(true);U.ReleaseKeyboard();return
        end
        self:SetPropagateKeyboardInput(not captured[key] and key~="ESCAPE")
        if key=="ESCAPE" then U.ReleaseKeyboard()
        elseif captured[key] then
            held[key]=true
            if numbers[key] then U.BattleKey(numbers[key])
            elseif key=="SPACE" and U.BattleResultAvailable() then U.resultAction()
            elseif key=="SPACE" and U.PageContinueAvailable() then U.advanceAction.callback()
            elseif U.DungeonKeysAvailable() then
                if key=="SPACE" then G.InteractDungeon()
                else local v=directions[key];G.StepDungeon(v[1],v[2]) end
                U.Render()
            end
        end
    end)
    keys:SetScript("OnKeyUp",function(self,key)
        if inCombat() then U.ReleaseKeyboard(true);return end
        self:SetPropagateKeyboardInput(not held[key]);held[key]=nil
        if not U.keyboardFocused and not next(held) then self:Hide() end
    end)
    local watch=CreateFrame("Frame",nil,U.frame);U.keyboardWatch=watch
    watch:RegisterEvent("GLOBAL_MOUSE_DOWN");watch:RegisterEvent("PLAYER_REGEN_DISABLED")
    watch:RegisterEvent("PLAYER_REGEN_ENABLED");watch:RegisterEvent("PLAYER_LEAVING_WORLD")
    watch:SetScript("OnEvent",function(_,event)
        if event=="GLOBAL_MOUSE_DOWN" then
            local mouse=GetMouseFoci()
            if isInside(mouse and mouse[1]) then U.FocusKeyboard() else U.ReleaseKeyboard() end
        elseif event=="PLAYER_REGEN_ENABLED" then U.UpdateKeyboardIndicator()
        else U.ReleaseKeyboard(true) end
    end)
    watch:SetScript("OnUpdate",function() U.CheckKeyboardFocus() end)
end
