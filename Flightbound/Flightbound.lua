local addonName,F=...
local G,U=F.Game,F.UI
local events=CreateFrame("Frame")
F.events=events
local ready,elapsed=false,0
local function say(s) DEFAULT_CHAT_FRAME:AddMessage("|cffc2d491Flightbound:|r "..s) end
-- Only the supported taxi-state API is queried. A low-frequency poll catches
-- delayed taxi transitions and reloads in flight without hooking flight controls.
function F.CheckFlight()
    if not ready then return end
    local flying=UnitOnTaxi("player") and true or false
    if flying~=F.onTaxi then
        F.onTaxi=flying
        if flying then
            if G.db.settings.auto and (not U.frame or not U.frame:IsShown()) then
                U.Open(false);F.autoOpened=true
            end
        elseif F.autoOpened and U.frame then
            U.frame:Hide()
        end
        U.UpdateStatus()
    end
end
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_CONTROL_LOST")
events:RegisterEvent("PLAYER_CONTROL_GAINED")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent",function(_,event,name)
    if event=="ADDON_LOADED" and name==addonName then
        FlightboundDB,FlightboundBackupDB=G.ApplyRequestedReset(FlightboundDB,FlightboundBackupDB)
        FlightboundDB=G.Init(FlightboundDB);ready=true
        events:UnregisterEvent("ADDON_LOADED")
    elseif ready then
        if event=="PLAYER_LOGOUT" then U.SavePosition()
        else F.CheckFlight() end
    end
end)
events:SetScript("OnUpdate",function(_,dt)
    if not ready then return end
    elapsed=elapsed+dt
    if elapsed>=.75 then elapsed=0;F.CheckFlight() end
end)
SLASH_FLIGHTBOUND1="/flightbound"
SLASH_FLIGHTBOUND2="/fbound"
SLASH_FLIGHTBOUND3="/fb"
SlashCmdList.FLIGHTBOUND=function(input)
    if not ready then return end
    local command,arg=(input or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if command=="auto" then
        if arg=="on" then G.db.settings.auto=true
        elseif arg=="off" then G.db.settings.auto=false
        else G.db.settings.auto=not G.db.settings.auto end
        U.UpdateStatus();say("Automatic flight opening "..(G.db.settings.auto and "enabled." or "disabled."))
    elseif command=="keys" then
        local enabled=arg=="on" or arg~="off" and not G.db.settings.keyboard
        U.SetKeyboard(enabled,false)
        say(enabled and "Arrows move; Space interacts. Click anywhere inside Flightbound to focus; Escape or click outside releases." or "Keyboard controls disabled.")
    elseif command=="sound" then
        if arg=="on" then G.db.settings.sound=true
        elseif arg=="off" then G.db.settings.sound=false
        else G.db.settings.sound=G.db.settings.sound==false end
        if not G.db.settings.sound then F.Audio.Stop() end
        say("Sound "..(G.db.settings.sound and "enabled." or "disabled."))
    elseif command=="difficulty" then
        if not G.SetDifficulty(arg) then say("Outside battle, use: /flightbound difficulty story, adventure, or veteran.")
        else U.Render();say(G.Difficulty().name.." difficulty selected.") end
    elseif command=="scale" then
        local n=tonumber(arg)
        if not n or n~=n then say("Use /flightbound scale 85 (70-150 percent).");return end
        if n>2 then n=n/100 end
        U.Build();U.Scale(n);U.Render()
    elseif command=="position" then
        G.db.settings.position=nil;U.Build();U.ApplyPosition();U.Open(true)
    elseif command=="help" then
        U.page="help";U.Open(true)
    elseif command=="friends" or command=="guild" or command=="duel" then
        F.SocialClient.Start()
        U.page="social";U.Open(true)
    elseif command=="leaderboard" or command=="board" then
        F.SocialClient.Start()
        U.page="leaderboard";U.Open(true)
    elseif command=="linkstatus" then
        F.SocialClient.Start();say(F.SocialClient.Status())
    elseif command=="linktest" then
        say(F.SocialClient.Test())
    elseif command=="sync" then
        F.SocialClient.Start()
        if not F.Social then say("Link services are unavailable on this character.")
        elseif arg=="off" or arg=="on" then
            if not F.Social:SetEnabled(arg=="on") then say("Finish or leave the current duel before changing sync.") end
        else F.Social:Refresh();F.Social.guildAt=0;for _,p in pairs(F.Social.peers) do p.helloAt=0 end;say("Checking online friends and guildmates for Flightbound.") end
    elseif command=="show" then U.Open(true)
    elseif command=="hide" then if U.frame then U.frame:Hide() end
    elseif command=="" then
        if U.frame and U.frame:IsShown() then U.frame:Hide() else U.Open(true) end
    else say("/fb | friends | leaderboard | sync on/off | show | hide | keys on/off | auto on/off | sound on/off | difficulty story/adventure/veteran | scale 85 | position | help") end
end
