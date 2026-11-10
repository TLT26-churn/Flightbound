local F,G,U,snapshot,json,key,mouseDown=...
local D=F.Duel
U.frame:Hide();F.Social=nil;G.Init(nil,function(a,b) return b and a or 1 end)
G.SetTrainer({name="Whitebeard Tinkerton",race="dwarf",class="WARRIOR",gender=1});G.Start("wolf")
G.db.pets={};for _,id in ipairs(F.order) do G.db.pets[#G.db.pets+1]=G.NewPet(id,14) end
G.db.scene=nil;G.db.showChapter=false;G.db.evolutions={};G.StartDungeon();U.page="social";U.Open(true)
snapshot("social-unavailable")
local clock,wire=0,{}
local contacts={
 ["friend"]={name="Aster Ashborne-Realm",online=true,friend=true},
 ["guild"]={name="Whitebeard Tinkerton-Realm",online=true,guild=true},
 ["both"]={name="Rowan Emberfall-Realm",online=true,guild=true,friend=true},
 ["offline"]={name="Mira Sunfall-Realm",online=false,guild=true},
 ["old"]={name="Older Version-Realm",online=true,friend=true},
 ["plain"]={name="No Addon Yet-Realm",online=true,guild=true},
}
local function record(badges,lane) return {lane=lane or "adventure",ending=badges==8 and 1 or 0,badges=badges,quests=badges*3,rivals=badges*2,treasure=badges*4,collection=5,imported=1} end
local env={me=function() return "you" end,now=function() return clock end,wall=function() return 1800000000+math.floor(clock) end,
 contacts=function() return contacts end,score=function() return record(3) end,ready=F.SocialClient.Ready,
 send=function(peer,msg) wire[#wire+1]={to=peer,from="you",msg=msg};return true end,
 changed=function(event) if event then U.QueueDuelAnimation(event) end;if U.frame:IsShown() then U.Render() end end}
local S=F.NewSocial(env,{});F.Social=S;S:Refresh();S.status="Online friends and guildmates are ready. Choose a team to challenge someone."
for _,id in ipairs({"friend","guild","both","offline","old"}) do
 S.peers[id]={version=id=="old" and "4.0.0" or F.version,duelRules=D.rules,seen=0,helloAt=999}
 S:Store(id,record(id=="friend" and 8 or id=="guild" and 6 or 4))
end
snapshot("social-club");U.socialOffset=2;snapshot("social-club-page2");U.socialOffset=0
U.page="leaderboard";snapshot("social-board-all")
U.boardScope="guild";snapshot("social-board-guild");U.boardScope="friend";snapshot("social-board-friends")
U.boardScope="all";U.boardLane="veteran";snapshot("social-board-empty");U.boardLane=nil
U.page="duelteam";U.duelDraft=nil;U.duelTeamOffset=0;snapshot("social-team")
U.duelTeamOffset=6;snapshot("social-team-page2");U.duelTeamOffset=0
U.page="social";S:Receive("friend","1|I|1800000000.1.99|4,7,12|99");snapshot("social-invite")
S.incoming=nil;S.status="Choose your opponent.";S.saved.team="1,2,3";wire={}
-- A real second controller drives the rendered duel. The transport is a test queue.
local peer=F.NewSocial({me=function() return "friend" end,now=env.now,wall=env.wall,contacts=function() return {you={name="you",online=true,friend=true}} end,
 score=function() return record(8) end,ready=function() return true end,
 send=function(to,msg) wire[#wire+1]={to=to,from="friend",msg=msg};return true end},{})
peer:Refresh();peer.peers.you={version=F.version,duelRules=D.rules,seen=0,helloAt=999}
local function tick(seconds)
 for _=1,math.ceil(seconds/.1) do
  clock=clock+.1;S:Tick();peer:Tick()
  local pending=wire;wire={}
  for _,p in ipairs(pending) do
   if p.to=="you" then S:Receive("friend",p.msg)
   elseif p.to==contacts.friend.name then peer:Receive("you",p.msg) end
  end
  U.Animate(.1)
 end
end
U.SetKeyboard(true,true);U.SavePosition();local saved=json(G.db)
assert(S:Invite("friend","1,2,3"));tick(2);assert(peer.incoming);assert(peer:Accept("4,7,12"));tick(3)
assert(S.session and S.session.phase=="active" and U.page=="duel")
snapshot("social-duel-start")
-- Utility effects belong to the acting companion on either side of a duel.
for _,actor in ipairs({S.session.side,3-S.session.side}) do
 for _,action in ipairs({"guard","focus"}) do
  U.QueueDuelAnimation({actor=actor,action=action,hits={},before={D.Copy(D.Active(S.session.state,1)),D.Copy(D.Active(S.session.state,2))},log="Utility effect"})
  U.Animate(.2);local tex=U.fxSprites[5];local size=action=="guard" and 76 or 64
  local cx,cy=actor==S.session.side and 64 or 264,actor==S.session.side and 150 or 80
  assert(tex.shown and tex.anchor[4]==cx-size/2 and tex.anchor[5]==-(cy-size/2),"Utility effect rendered on the wrong companion")
  U.Animate(1)
 end
end
local x,y=G.db.dungeon.x,G.db.dungeon.y
assert(not key("OnKeyDown","RIGHT") and not key("OnKeyUp","RIGHT"));assert(G.db.dungeon.x==x and G.db.dungeon.y==y)
if S.session.state.turn~=S.session.side then assert(peer:Move("guard"));tick(2) end
assert(not key("OnKeyDown","2"));assert(not key("OnKeyUp","2"));U.Animate(.28)
local render=U.Render;U.Render=function() end;snapshot("social-duel-impact");U.Render=render
tick(2);snapshot("social-duel-waiting")
U.page="duelswap";snapshot("social-duel-swap");U.page="dueloptions";snapshot("social-duel-options");U.page="duel"
while S.session.state.winner==nil do
 local who=S.session.state.turn==S.session.side and S or peer;local t=who.session.state.teams[who.session.side]
 assert(who:Move(t.cooldown==0 and "special" or "strike"));tick(2)
end
tick(2);snapshot("social-duel-result");assert(U.BattleResultAvailable())
assert(json(G.db)==saved,"Rendered/keyboard duel altered campaign state")
assert(not key("OnKeyDown","SPACE") and not key("OnKeyUp","SPACE"));assert(not S.session and U.page=="social")
peer:Leave();tick(1)
assert(S:Invite("friend","1"));tick(2);assert(peer:Accept("2"));tick(3)
S.session.lastHeard=clock-30;S:Sync();snapshot("social-duel-reconnecting")
S:End("The connection was lost. Your campaign is unchanged.");snapshot("social-duel-disconnected")
S:Leave();U.page="social";S:SetEnabled(false);snapshot("social-sync-off")
U.frame:Hide();F.Social=nil;U.duelView=nil;U.duelSessionID=nil;U.page=nil;U.Open(true)
print("Social UI: club/team/invite/board/duel states, animation, keyboard return, reconnect and campaign isolation passed.")
