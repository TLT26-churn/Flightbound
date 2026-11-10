local _,F=...
local G,U,D=F.Game,F.UI,F.Duel
local H=U.Paint
local text,rect,sprite,button,act,run,page,heading,dialogue=H.text,H.rect,H.sprite,H.button,H.act,H.run,H.page,H.heading,H.dialogue
local function short(s,n) return G.CleanName(s or "",n or 28) or "Unknown" end
local function name(key)
 local S=F.Social;local c=S and S.contacts[key]
 return short((c and c.name or key or ""):match("^(.-)%-") or c and c.name or key,28)
end
local function teamIds()
 local S=F.Social;local ids=S and D.Team(S.saved.team)
 if ids then for _,id in ipairs(ids) do if not G.Owns(id) then ids=nil;break end end end
 if not ids then ids={};for i=1,math.min(3,#G.db.pets) do ids[i]=G.db.pets[i].id end end
 return ids
end
function U.DuelTeamCode() return D.EncodeTeam(teamIds()) end
local function available()
 if F.Social then return true end
 heading("LINK CLUB")
 text(12,58,496,92,F.SocialClient and F.SocialClient.startStatus or "Link setup is waiting for your character to load.",13)
 dialogue("Your campaign is available offline. Use /fb linkstatus to see why link setup is waiting.")
 act(1,"BACK",page("menu"));for i=2,4 do act(i,"",nil,false) end
end
local function refresh()
 local S=F.Social;S:Refresh()
 for _,p in pairs(S.peers) do p.helloAt=0 end
 S.status="Checking online friends and guildmates...";U.Render()
end
function U.pages.social()
 if not available() then return end
 local S=F.Social;heading("LINK CLUB: FRIENDS / GUILD")
 local ids=teamIds();local pending=S.incoming or S.outgoing
 local start,count=78,5
 text(12,37,496,15,"YOUR TEAM: "..#ids.." COMPANIONS / ALL LEVEL 14",11)
 if pending then
  start,count=152,4
  text(12,61,496,27,(S.incoming and "INVITE FROM " or "INVITE SENT TO ")..name(pending.peer).." / "..#D.Team(pending.team).." V "..#D.Team(pending.team),11)
  if S.incoming then
   button(12,102,160,28,pending.ourTeam and "CONNECTING..." or "ACCEPT DUEL",run(function() S:Accept(U.DuelTeamCode()) end),not pending.ourTeam and #ids==#D.Team(pending.team) and S.env.ready(U.DuelTeamCode()))
  else button(12,102,160,28,"WAITING...",nil,false) end
  button(180,102,160,28,"CHOOSE TEAM",page("duelteam"));button(348,102,160,28,"CANCEL",run(function() S:Decline() end))
 end
 local rows={};for key,c in pairs(S.contacts) do rows[#rows+1]={key=key,c=c} end
 table.sort(rows,function(a,b) if a.c.online~=b.c.online then return a.c.online end;return a.key<b.key end)
 U.socialOffset=G.Clamp(U.socialOffset or 0,0,math.max(0,#rows-count))
 for i=1,count do local row=rows[U.socialOffset+i]
  if row then
   local peer,c=row.key,row.c;local p=S.peers[peer];local y=start+(i-1)*49
   text(12,y,344,16,name(peer),12)
   local tag=c.friend and c.guild and "FRIEND + GUILD" or c.friend and "FRIEND" or "GUILD"
   local status=not c.online and "OFFLINE" or S:Compatible(peer) and "READY" or p and p.version and p.version~=F.version and "UPDATE "..short(p.version,10) or "CHECKING ADDON"
   text(12,y+20,344,12,tag.." / "..status,9)
   button(380,y+1,128,31,"DUEL",run(function() S:Invite(peer,U.DuelTeamCode()) end),not pending and S.saved.enabled and S:Compatible(peer) and S.env.ready(U.DuelTeamCode()))
  end
 end
 if #rows==0 then text(12,166,496,55,"No friends or guildmates are loaded yet. Both players need Flightbound to link.",12) end
 button(12,376,86,25,"< PREV",run(function() U.socialOffset=math.max(0,U.socialOffset-count) end),U.socialOffset>0)
 button(104,376,86,25,"NEXT >",run(function() U.socialOffset=U.socialOffset+count end),U.socialOffset+count<#rows)
 button(330,376,178,25,S.saved.enabled and "SYNC: ON" or "SYNC: OFF",run(function() S:SetEnabled(not S.saved.enabled) end))
 dialogue(S.status)
 act(1,"CHOOSE TEAM",page("duelteam"));act(2,"LEADERBOARD",page("leaderboard"));act(3,"SYNC NOW",refresh,S.saved.enabled);act(4,"BACK",page("menu"))
end
function U.pages.duelteam()
 if not available() then return end
 local S=F.Social;if not U.duelDraft then U.duelDraft=teamIds() end
 local draft=U.duelDraft;heading("CHOOSE YOUR LINK TEAM")
 text(12,38,496,27,#draft.." / 3 CHOSEN. MATCH YOUR FRIEND'S TEAM SIZE.\nOWNED COMPANIONS BATTLE AT LEVEL 14.",10)
 U.duelTeamOffset=U.duelTeamOffset or 0
 for i=1,6 do local p=G.db.pets[U.duelTeamOffset+i]
  if p then
   local slot;for j,id in ipairs(draft) do if id==p.id then slot=j end end
   local x,y=12+(i-1)%2*250,77+math.floor((i-1)/2)*103
   rect(x,y,242,95,F.palette.soft,"BACKGROUND");sprite(G.Art(p,3),x+6,y+24,56,56)
   text(x+68,y+7,166,28,G.FormName(p,3),11)
   text(x+68,y+38,166,13,slot and "SLOT "..slot or F.species[p.id].kind,9)
   button(x+68,y+58,164,26,slot and "REMOVE" or "ADD",run(function()
    if slot then table.remove(draft,slot) elseif #draft<3 then draft[#draft+1]=p.id end
   end),slot~=nil or #draft<3)
  end
 end
 dialogue("Equal levels, full HP, no campaign items. Swapping uses a turn; cooldowns are shared across your team. Duels grant no campaign XP or gold.")
 act(1,"SAVE TEAM",run(function() S.saved.team=D.EncodeTeam(draft);U.duelDraft=nil;U.page="social" end),#draft>0)
 act(2,"< PREV",run(function() U.duelTeamOffset=math.max(0,U.duelTeamOffset-6) end),U.duelTeamOffset>0)
 act(3,"NEXT >",run(function() U.duelTeamOffset=U.duelTeamOffset+6 end),U.duelTeamOffset+6<#G.db.pets)
 act(4,"CANCEL",run(function() U.duelDraft=nil;U.page="social" end))
end
function U.pages.leaderboard()
 if not available() then return end
 local S=F.Social;local lane=U.boardLane or S.ownScore and S.ownScore.lane or "adventure";U.boardLane=lane
 local scope=U.boardScope or "all";heading("CAMPAIGN: "..F.difficulties[lane].name)
 text(12,37,496,16,"BEST PROGRESS / RULES 4.8 / FRIENDS + GUILD ONLY",10)
 text(12,67,220,13,"PLAYER",10);text(234,67,124,13,"PROGRESS",10);text(363,67,65,13,"QUESTS",10);text(439,67,70,13,"SYNC",10)
 local rows={};for _,r in ipairs(S:Rows(lane)) do
  local c=S.contacts[r.owner]
  if scope=="all" or r.owner==S.me or c and c[scope] then rows[#rows+1]=r end
 end
 U.boardOffset=G.Clamp(U.boardOffset or 0,0,math.max(0,#rows-6))
 for i=1,6 do local r=rows[U.boardOffset+i]
  if r then
   local y=92+(i-1)*43;local age=math.max(0,S.env.wall()-r.seen)
   local ago=age<60 and "NOW" or age<3600 and math.floor(age/60).."M" or age<86400 and math.floor(age/3600).."H" or math.floor(age/86400).."D"
   text(12,y,216,29,(U.boardOffset+i)..". "..(r.owner==S.me and "YOU" or name(r.owner))..(r.imported==1 and " *" or ""),11)
   text(234,y,124,29,r.ending==1 and "COMPLETE" or r.badges.."/8 STONES",10)
   text(363,y,65,14,r.quests.."/24",10);text(439,y,70,14,ago,10)
  end
 end
 if #rows==0 then text(12,133,496,50,"No records in this difficulty yet. Scores arrive when online contacts also run Flightbound.",12) end
 button(12,368,86,28,"< PREV",run(function() U.boardOffset=math.max(0,U.boardOffset-6) end),U.boardOffset>0)
 button(104,368,86,28,"NEXT >",run(function() U.boardOffset=U.boardOffset+6 end),U.boardOffset+6<#rows)
 text(210,375,296,16,"CLEARS > STONES > QUESTS > SIDE GOALS",9,"RIGHT")
 dialogue("Cached records stay visible offline. Difficulty uses the easiest setting observed. * Earlier difficulty history is unknown for an existing save.")
 act(1,F.difficulties[lane].name,run(function() U.boardLane=({story="adventure",adventure="veteran",veteran="story"})[lane];U.boardOffset=0 end))
 act(2,({all="ALL CONTACTS",friend="FRIENDS",guild="GUILD"})[scope],run(function() U.boardScope=({all="friend",friend="guild",guild="all"})[scope];U.boardOffset=0 end))
 act(3,"SYNC NOW",refresh,S.saved.enabled);act(4,"LINK CLUB",page("social"))
end
function U.GetDuelView()
 local S=F.Social;local s=S and S.session
 if not s then
  if U.duelSessionID then U.duelSessionID=nil;U.duelQueue={};U.effect=nil;U.ClearDamagePops() end
  return
 end
 if U.duelSessionID~=s.id then U.duelSessionID=s.id;U.duelQueue={};U.effect=nil;U.ClearDamagePops() end
 local v=s.view;v.player=D.Active(s.state,s.side);v.enemy=D.Active(s.state,3-s.side);v.log=s.reason or s.state.log
 local winner=s.state.winner;if s.ended then winner=s.winner end
 v.result=(s.ended or winner~=nil) and (winner==s.side and "win" or winner==3-s.side and "lost" or "draw") or nil
 return v
end
function U.QueueDuelAnimation(event)
 if not U.frame or not U.frame:IsShown() or U.page~="duel" then return end
 U.duelView=U.GetDuelView()
 U.duelQueue=U.duelQueue or {};if #U.duelQueue>=6 then U.duelQueue={};U.effect=nil;return end
 U.duelQueue[#U.duelQueue+1]=event;U.TickDuelAnimations()
end
function U.TickDuelAnimations()
 local S=F.Social;local s=S and S.session
 if not s or U.page~="duel" or U.effect or not U.duelQueue or #U.duelQueue==0 then return end
 U.duelView=U.GetDuelView();local event=table.remove(U.duelQueue,1);local hits={}
 for _,h in ipairs(event.hits) do
  local hit=D.Copy(h);hit.source=h.source=="status" and "status" or h.source==s.side and "player" or "enemy"
  hit.target=h.target==s.side and "player" or "enemy";hits[#hits+1]=hit
 end
 U.effect={duel=true,actor=event.actor==s.side and "player" or "enemy",age=0,phase=0,duration=.98,battle=U.duelView,action=event.action,hits=hits,
  player=event.before[s.side],enemy=event.before[3-s.side],finalLog=event.log,
  result=event.result and (event.result==s.side and "win" or event.result==0 and "draw" or "lost") or nil}
 if F.Audio and (event.actor==s.side or event.action~="strike" and event.action~="special") then F.Audio.Play(({strike="strike",special="special",guard="guard",focus="guard",swap="encounter"})[event.action]) end
 U.Render()
end
local function canMove()
 local S=F.Social;local s=S and S.session
 return s and not s.ended and s.state.winner==nil and s.phase=="active" and not s.pending and s.state.turn==s.side
  and S.env.now()-s.lastHeard<=25 and not U.effect and (not U.duelQueue or #U.duelQueue==0)
end
function U.DuelKey(key)
 local b=U.battleHotkeys and U.battleHotkeys[key]
 if U.effect or not b or not b:IsEnabled() or not b.callback then return false end
 b.callback();return true
end
function U.pages.duel()
 local S=F.Social;local s=S and S.session;if not s then U.pages.social();return end
 U.battleVisible=true;local v=U.duelView;local p,enemy=U.CombatPet("player"),U.CombatPet("enemy")
 local theme=G.BattleTheme({kind="arena"});local t=s.state.teams[s.side]
 rect(0,0,328,272,theme.panel):SetDrawLayer("BACKGROUND",-7)
 sprite("Battles\\"..theme.id,0,32,328,164):SetDrawLayer("BACKGROUND",-6)
 local function panel(x,y,w,h)
  rect(x,y,w,h,theme.edge,"OVERLAY"):SetDrawLayer("OVERLAY",-4)
  rect(x+1,y+1,w-2,h-2,theme.panel,"OVERLAY"):SetDrawLayer("OVERLAY",-3)
 end
 panel(8,34,198,78);panel(126,118,196,76);panel(8,199,312,65)
 local result=v.result and not U.effect and (not U.duelQueue or #U.duelQueue==0)
 local title=result and ({win="DUEL WON!",lost="DUEL LOST",draw="DUEL ENDED"})[v.result]
  or s.phase~="active" and "CONNECTING..." or U.effect and "TURN "..s.state.seq or canMove() and "YOUR TURN" or "OPPONENT'S TURN"
 text(10,9,308,17,title,12,nil,theme.ink);rect(10,28,308,2,theme.edge,"BORDER")
 text(12,38,192,27,G.Name(enemy),11,nil,theme.ink);text(12,66,190,12,"FOE: "..short(name(s.peer),24),9,nil,theme.ink)
 H.hp(12,83,148,enemy,theme);text(12,95,180,13,"L14  "..enemy.hp.."/"..G.MaxHP(enemy).." HP",8,nil,theme.ink)
 sprite(G.Art(enemy),218,34,92,92,true,result and v.result=="win","enemy")
 sprite(G.Art(p),16,100,96,96,false,false,"player")
 text(130,123,188,25,G.Name(p),11,nil,theme.ink)
 local alive=0;for _,pet in ipairs(t.pets) do if pet.hp>0 then alive=alive+1 end end
 text(130,145,188,13,"L14 "..F.species[p.id].kind.."  TEAM "..alive.."/"..#t.pets,9,nil,theme.ink)
 H.hp(130,162,180,p,theme);text(130,175,188,13,"HP "..p.hp.."/"..G.MaxHP(p),9,nil,theme.ink)
 local log=U.CombatLog()
 if result then log=s.pending and "Confirming the result with your opponent..." or (s.reason or (v.result=="win" and "You won the friendly duel!" or "The duel is over.")).." Your campaign is unchanged." end
 text(16,208,296,52,log,#log>145 and 10 or 11,nil,theme.ink)
 if result then
  act(1,"BACK TO CLUB",run(function() S:Leave();U.page="social" end),not s.pending)
  if not s.pending then U.resultAction=U.actions[1].callback end
  for i=2,4 do act(i,"",nil,false) end
 else
  local enabled=canMove();U.battleControls:Show()
  U.battleTip:SetText(s.phase~="active" and "RESUMING THE SHARED TURN LOG..." or S.env.now()-s.lastHeard>25 and "CONNECTION QUIET. RETRYING AUTOMATICALLY..." or "SHARED COOLDOWNS / FULL LEVEL-14 TEAMS / NO CAMPAIGN COST")
  H.battleAct(1,"STRIKE","BASIC ATTACK",run(function() S:Move("strike") end),enabled)
  H.battleAct(2,G.Spec(p).move,t.cooldown>0 and "WAIT "..t.cooldown.." TURNS" or "SPECIAL / READY",run(function() S:Move("special") end),enabled and t.cooldown==0)
  H.battleAct(3,F.defensiveMoves[p.id],t.defense>0 and "WAIT "..t.defense.." TURNS" or "BLOCK NEXT HIT",run(function() S:Move("guard") end),enabled and t.defense==0 and not t.guard)
  H.battleAct(4,"SWAP TEAM","USES YOUR TURN",page("duelswap"),#t.pets>1)
  H.battleExtra(1,"5","DUEL MENU",page("dueloptions"))
  H.battleExtra(2,"6",t.focus and "FOCUSED" or "FOCUS: NEXT SPECIAL +65%",run(function() S:Move("focus") end),enabled and not t.focus)
 end
end
function U.pages.duelswap()
 local S=F.Social;local s=S.session;heading("SWAP YOUR DUEL COMPANION")
 for i,p in ipairs(s.state.teams[s.side].pets) do
  local y=43+(i-1)*49;sprite(G.Art(p),12,y,40,40)
  text(62,y+2,166,18,G.Name(p),10);text(62,y+22,166,14,"HP "..p.hp.."/"..G.MaxHP(p),9)
  button(237,y+8,79,27,"SELECT",run(function() if S:Move("swap",i) then U.page="duel" end end),canMove() and D.Legal(s.state,s.side,"swap",i))
 end
 dialogue("Switching spends your turn. Cooldowns stay with the team. Your campaign companions are unaffected.")
 act(1,"BACK",page("duel"));for i=2,4 do act(i,"",nil,false) end
end
function U.pages.dueloptions()
 heading("FRIENDLY DUEL")
 text(12,50,304,52,"OPPONENT: "..name(F.Social.session.peer),12)
 text(12,118,304,57,"Closing the window keeps the duel open. Two minutes without a move ends it. Forfeit to leave now.",11)
 dialogue("No campaign HP, items, XP, gold or map progress changes during link battles.")
 act(1,"BACK",page("duel"));act(2,"FORFEIT",run(function() F.Social:Leave();U.page="social" end))
 act(3,"RECONNECT",run(function() F.Social:Sync();U.page="duel" end));act(4,"HIDE WINDOW",function() U.frame:Hide() end)
end
