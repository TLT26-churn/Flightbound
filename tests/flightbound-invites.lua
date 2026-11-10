local F,G,U,S,snapshot,key,setClock=...
local savedTeam,savedSound=S.saved.team,G.db.settings.sound
local play=PlaySoundFile;local alerts=0
PlaySoundFile=function(...) alerts=alerts+1;return play(...) end
local function click(b) assert(b:IsEnabled());b.scripts.OnClick(b) end
local function invite(n,team)
 S.incoming=nil;S.outgoing=nil;S.cancelledInvite=nil;S.saved.team=team or "1,2,3"
 S.peers.friend.seen=S.env.now()
 S:Receive("friend","1|I|1800000000."..n..".99|4,7,12|99")
end
G.db.settings.sound=true;U.frame:Hide();local focus=GetCurrentKeyBoardFocus()
invite(101);local w=U.invitePopup
assert(w and w:IsShown() and w.parent==UIParent and not U.frame:IsShown())
assert(not rawget(w,"keyboardEnabled") and GetCurrentKeyBoardFocus()==focus and not U.keyboardFocused)
assert(w.accept:IsEnabled() and alerts==1);snapshot("invite-popup-ready",w)
S:Receive("friend","1|I|1800000000.101.99|4,7,12|99");U.UpdateDuelInvite();assert(alerts==1,"Duplicate invite replayed sound")
setClock(12);U.UpdateDuelInvite();assert(w.details:GetText():find("48S LEFT"))
click(w.decline);assert(not S.incoming and not w:IsShown())
invite(102,"1");assert(not w.accept:IsEnabled());snapshot("invite-popup-team",w)
click(w.team);assert(U.frame:IsShown() and U.page=="duelteam" and not w:IsShown())
U.duelDraft={"wolf","murloc","whelp"};U.Render();click(U.actions[1])
assert(S.saved.team=="1,2,3" and w:IsShown() and w.accept:IsEnabled())
G.db.battle={};U.UpdateDuelInvite();assert(not w.accept:IsEnabled());snapshot("invite-popup-busy",w);G.db.battle=nil
U.UpdateDuelInvite();click(w.accept)
assert(S.incoming.ourTeam=="1,2,3" and not w:IsShown() and U.page=="social" and not U.keyboardFocused)
local seed=S.incoming.ourSeed;assert(not S:Accept("1,2,3") and S.incoming.ourSeed==seed,"Double acceptance changed the handshake seed")
S.incoming=nil;U.frame:Hide();invite(103);assert(w:IsShown())
S:Receive("friend","1|N|1800000000.103.99");assert(not w:IsShown())
invite(104);setClock(73);U.UpdateDuelInvite();assert(not w:IsShown(),"Expired popup remained visible")
assert(not S:Accept("1,2,3"));assert(not S.incoming)
G.db.settings.sound=false;local before=alerts;invite(105);assert(w:IsShown() and alerts==before,"Muted invite played sound")
S.contacts.friend.online=false;U.UpdateDuelInvite();assert(not w:IsShown());S.contacts.friend.online=true
S.incoming=nil;S.queue={};S.saved.team=savedTeam;G.db.settings.sound=savedSound;PlaySoundFile=play
setClock(0);S.peers.friend.seen=0;S.cancelledInvite=nil;U.page="social";U.Open(true);U.UpdateDuelInvite()
print("Invites: closed-window notice, one alert/mute, countdown, team selection, acceptance, duplicate guard, busy/expired/cancelled states and no keyboard capture passed.")
