-- A mouse-only invitation notice, independent of the handheld's visibility.
local _,F=...
local U,G,D=F.UI,F.Game,F.Duel
local W=U.Widgets
local function current()
 local S=F.Social;local p=S and S.incoming
 if not p or not S.saved.enabled or p.expires<=S.env.now() or not S:Compatible(p.peer) or S.session then return end
 return S,p
end
local function openTeam()
 local S,p=current();if not p or p.ourTeam then return end
 U.duelDraft=nil;U.duelTeamOffset=0;U.page="duelteam";U.Open(true);U.UpdateDuelInvite()
end
function U.BuildDuelInvite()
 if U.invitePopup then return end
 local w=CreateFrame("Frame","FlightboundDuelInvite",UIParent);U.invitePopup=w
 w:SetSize(424,232);w:SetPoint("TOP",UIParent,"TOP",0,-135)
 w:SetFrameStrata("DIALOG");w:SetClampedToScreen(true);w:EnableMouse(true)
 -- Never enable keyboard input or focus fields in an unsolicited notification.
 local ink={.88,.88,.78,1};local muted={.68,.74,.64,1}
 W.texture(w,0,0,424,232,{.08,.10,.11,1},"BACKGROUND",0)
 W.texture(w,2,2,420,228,{.53,.61,.47,1},"BACKGROUND",1)
 W.texture(w,4,4,416,224,{.16,.20,.21,1},"BACKGROUND",2)
 W.label(w,16,14,392,18,"FLIGHTBOUND DUEL INVITE",14,{.79,.86,.60,1})
 w.sender=W.label(w,16,43,392,30,"",13,ink)
 w.details=W.label(w,16,81,392,14,"",10,muted)
 w.hint=W.label(w,16,109,392,43,"",11,ink)
 w.accept=W.button(w,16,164,124,30,"ACCEPT DUEL",function()
  local S,p=current();if not p or p.ourTeam then return end
  if S:Accept(U.DuelTeamCode()) then U.page="social";U.Open(true) end
  U.UpdateDuelInvite()
 end,true)
 w.team=W.button(w,150,164,124,30,"CHOOSE TEAM",openTeam,true)
 w.decline=W.button(w,284,164,124,30,"DECLINE",function()
  local S,p=current();if p then S:Decline() end;U.UpdateDuelInvite()
 end,true)
 W.label(w,16,207,392,12,"NO CAMPAIGN ITEMS OR HP ARE SPENT.",9,muted,"CENTER")
 w:Hide()
end
function U.UpdateDuelInvite()
 local S,p=current();local w=U.invitePopup
 if not p or p.ourTeam then if w then w:Hide() end;return end
 local id=p.peer..":"..p.id
 if U.inviteNoticeID~=id then
  U.inviteNoticeID=id
  if F.Audio and F.Audio.Notify then F.Audio.Notify() end
 end
 if U.frame and U.frame:IsShown() and U.page=="duelteam" then if w then w:Hide() end;return end
 U.BuildDuelInvite();w=U.invitePopup
 local row=S.contacts[p.peer];local full=row and row.name or p.peer
 local display=G.CleanName(full:match("^(.-)%-") or full,40) or "Friend"
 local count=#D.Team(p.team);local team=U.DuelTeamCode();local ids=D.Team(team)
 local matching=ids and #ids==count
 local ready=matching and S.env.ready(team)
 w.sender:SetText(display)
 w.details:SetText(count.." V "..count.." / LEVEL 14 / "..math.max(0,math.ceil(p.expires-S.env.now())).."S LEFT")
 local hint=not matching and "Choose "..count.." companions to match this invite, then accept."
  or not ready and "Finish your campaign battle or companion setup before accepting."
  or "Your team is ready. Accept to start the friendly duel, or choose a different team."
 w.hint:SetText(hint)
 w.accept:SetEnabled(ready==true);w.accept:SetAlpha(ready and 1 or .4)
 w:Show()
end
