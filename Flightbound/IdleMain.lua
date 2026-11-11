local addon,F=...
local G,U=F.Idle,F.IdleUI
local epoch=time()-GetTime()
function F.Now() return epoch+GetTime() end
local events=CreateFrame("Frame");F.events=events
local ready,refresh,taxi=false,0,false
local function say(s) DEFAULT_CHAT_FRAME:AddMessage("|cffead18eFlightbound:|r "..s) end
function F.CheckFlight()
 local current=UnitOnTaxi("player") and true or false
 if current~=taxi then
  taxi=current
  if taxi and G.db.settings.auto and (not U.frame or not U.frame:IsShown()) then U.Open(false);F.autoOpened=true
  elseif not taxi and F.autoOpened and U.frame then U.frame:Hide() end
 end
end
events:RegisterEvent("ADDON_LOADED");events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent",function(_,event,name)
 if event=="ADDON_LOADED" and name==addon then
  local raw=FlightboundIdleDB
  if type(raw)=="table" and raw.schema and raw.schema~=1 then say("A newer idle save was found; it was left untouched.");return end
  -- User-requested fresh start for this redesign, once only. Legacy RPG saves remain declared and untouched.
  if raw and raw.resetToken~=F.freshStart then FlightboundIdleBackupDB=G.Copy(raw);raw=nil end
  local db,err=G.Init(raw,F.Now());if not db then say(err);return end
  FlightboundIdleDB=db;G.db=db;G.emit=U.Event;ready=true;events:UnregisterEvent("ADDON_LOADED")
 elseif event=="PLAYER_LOGOUT" and ready then G.Advance(G.db,F.Now(),false);U.SavePosition() end
end)
events:SetScript("OnUpdate",function(_,dt)
 if not ready then return end
 local visible=U.frame and U.frame:IsShown() and U.tab=="upgrades"
 G.Advance(G.db,F.Now(),visible);U.Animate();refresh=refresh+dt
 if refresh>=.15 then refresh=0;F.CheckFlight();if U.frame and U.frame:IsShown() then U.Render() end end
end)
SLASH_FLIGHTBOUND1="/fb";SLASH_FLIGHTBOUND2="/flightbound";SLASH_FLIGHTBOUND3="/fbcamp"
SlashCmdList.FLIGHTBOUND=function(input)
 if not ready then return end
 local cmd,arg=(input or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
 if cmd=="" or cmd=="show" then if cmd=="" and U.frame and U.frame:IsShown() then U.frame:Hide() else U.Open(true) end
 elseif cmd=="hide" then if U.frame then U.frame:Hide() end
 elseif cmd=="auto" or cmd=="sound" then
  if cmd=="sound" and arg=="test" then if not G.db.settings.sound then say("Sound is off. Use /fb sound on before testing.");return end;U.Open(true);F.IdleAudio.Play("treasure");say("Sound test uses WoW's Master channel. Check Master Volume if muted.");return end
  G.db.settings[cmd]=arg=="on" or arg~="off" and not G.db.settings[cmd]
  if cmd=="sound" and not G.db.settings.sound then F.IdleAudio.Stop() end
  say(cmd.." "..(G.db.settings[cmd] and "on" or "off"));U.Render()
 elseif cmd=="scale" then local value=tonumber(arg)
  if value and value==value then if value>2 then value=value/100 end;G.db.settings.scale=math.max(.65,math.min(1.3,value));U.Build();U.frame:SetScale(G.db.settings.scale);U.Position()
  else say("/fb scale 90 (65-130 percent)") end
 elseif cmd=="position" then G.db.settings.position=nil;U.Build();U.Position();U.Open(true)
 else say("/fb | show | hide | auto on/off | sound on/off/test | scale 90 | position")
  say("Click creatures; gold collects itself. Recruit and train companions, use Focus for Power Strike, then challenge guardians. Crew hunts while hidden/offline (up to 8 hours); guardians wait for you. Sound is on by default.") end
end
