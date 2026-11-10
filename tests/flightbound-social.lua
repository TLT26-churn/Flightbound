local function load()
 local F={}
 for _,n in ipairs({"Data","Game","Adventure","Campaign","Trainer","DungeonMap","Duel","Social"}) do assert(loadfile("Flightbound/"..n..".lua"))("Flightbound",F) end
 return F
end
local F=load();local D=F.Duel;local G=F.Game
G.Init(nil,function(a,b) return b and a or 1 end);G.SetTrainer({name="Tester",race="human",class="WARRIOR",gender=2});G.Start("wolf")
local function encode(t)
 if type(t)~="table" then return tostring(t) end
 local keys={};for k in pairs(t) do keys[#keys+1]=k end;table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
 local out={};for _,k in ipairs(keys) do out[#out+1]=tostring(k)..":"..encode(t[k]) end;return "{"..table.concat(out,",").."}"
end
local untouched=encode(G.db)
for _,bad in ipairs({"",",1","1,","1,,2","0","13","1,1","1,2,3,4","1 2","01","1,02"}) do assert(not D.Team(bad),bad) end
for seed=1,40 do
 local state=D.New("1,2,3","4,7,12",seed);local twin=D.Copy(state)
 while state.winner==nil do
  local side=state.turn;local t=state.teams[side]
  local action=t.cooldown==0 and "special" or "strike"
  local nextState,event=D.Apply(state,side,action,0);local other=D.Apply(twin,side,action,0)
  assert(nextState and event and D.Hash(nextState)==D.Hash(other));state,twin=nextState,other
 end
 assert(state.seq<=200 and state.winner~=0)
 assert(not D.Apply(state,state.turn,"strike",0))
end
assert(encode(G.db)==untouched,"Duel engine changed campaign data")
local clock,wire,clients,configs=0,{},{},{}
local function config(name)
 return {name=name,contacts={},score={lane="adventure",ending=0,badges=2,quests=3,rivals=2,treasure=4,collection=3,imported=0},events={}}
end
for _,n in ipairs({"alice","bob","guildmate","stranger"}) do configs[n]=config(n) end
configs.alice.contacts={bob={name="bob",online=true,friend=true},guildmate={name="guildmate",online=true,guild=true}}
configs.bob.contacts={alice={name="alice",online=true,friend=true}}
configs.guildmate.contacts={alice={name="alice",online=true,guild=true}}
local function make(name,saved)
 local c=configs[name]
 local env={me=function() return name end,now=function() return clock end,wall=function() return 1800000000+math.floor(clock) end,
  contacts=function() return c.contacts end,score=function() return c.score end,
  ready=function(team) return D.Team(team)~=nil and not c.busy end,
  changed=function(event) if event then c.events[#c.events+1]=event end end,
  send=function(peer,msg) assert(#msg<=240);wire[#wire+1]={from=name,to=peer,msg=msg};return true end}
 clients[name]=F.NewSocial(env,saved or {});clients[name]:Refresh();return clients[name]
end
for name in pairs(configs) do make(name) end
local drop,duplicate
local function tick(seconds)
 for _=1,math.ceil(seconds/.1) do
  clock=clock+.1;for _,s in pairs(clients) do s:Tick() end
  local pending=wire;wire={}
  for _,p in ipairs(pending) do
   if not drop or not drop(p) then
    if clients[p.to] then clients[p.to]:Receive(p.from,p.msg);if duplicate then clients[p.to]:Receive(p.from,p.msg) end end
   end
  end
 end
end
tick(12)
local a,b=clients.alice,clients.bob
assert(a:Compatible("bob") and a:Compatible("guildmate"));assert(#a:Rows("adventure")==3)
assert(a:Compatible("stranger")==false,"Unknown addon peers must explicitly disable their duel button")
a:Receive("stranger","1|H|"..F.version.."|1");a:Receive("stranger","1|S|48|adventure|1|8|24|16|32|12|0")
assert(not a.peers.stranger and #a:Rows("adventure")==3,"Stranger reached the board")
configs.guildmate.score.badges=4;clients.guildmate:RefreshScore();tick(3);assert(a:Rows("adventure")[1].owner=="guildmate")
configs.guildmate.contacts.alice.online=false;configs.alice.contacts.guildmate.online=false;tick(1)
assert(#a:Rows("adventure")==3,"Offline trusted scores should remain cached")
configs.alice.contacts.guildmate=nil;a:Refresh();assert(#a:Rows("adventure")==2,"Leaving both trusted lists must remove the row")
-- Dropped invite/start/ACK and duplicated moves recover without applying twice.
local dropped={}
drop=function(p)
 local op=p.msg:match("^1|([^|]+)")
 if (op=="I" or op=="B" or op=="K") and not dropped[op] then dropped[op]=true;return true end
end
assert(a:Invite("bob","1,2,3"));tick(6);assert(b.incoming)
assert(not b:Accept("1"));assert(b:Accept("4,7,12"));tick(12)
assert(a.session and b.session and a.session.phase=="active" and b.session.phase=="active")
assert(D.Hash(a.session.state)==D.Hash(b.session.state))
drop=nil;duplicate=true
for _=1,6 do
 local mover=a.session.state.turn==a.session.side and a or b
 assert(mover:Move(mover.session.state.teams[mover.session.side].cooldown==0 and "special" or "strike"));tick(2)
 assert(D.Hash(a.session.state)==D.Hash(b.session.state))
end
assert(a.session.state.seq==6 and #a.session.log==6 and #b.session.log==6)
-- /reload resumes from a validated journal, including a lost unacknowledged move.
duplicate=false
local mover=a.session.state.turn==a.session.side and a or b
drop=function(p) return p.msg:match("^1|M|")~=nil end
assert(mover:Move("strike"));tick(.5)
local saved=D.Copy(mover.saved);local name=mover==a and "alice" or "bob"
make(name,saved);a,b=clients.alice,clients.bob;drop=nil;tick(15)
assert(a.session.phase=="active" and b.session.phase=="active")
assert(D.Hash(a.session.state)==D.Hash(b.session.state) and a.session.state.seq==7,"Reload did not reconcile the pending move")
-- Out-of-order and forged state cannot mutate an established turn.
local before=D.Hash(a.session.state)
a:Receive("stranger","1|M|"..a.session.id.."|8|strike|0|"..before.."|1")
assert(D.Hash(a.session.state)==before)
a:Receive("bob","1|M|"..a.session.id.."|8|nonsense|0|"..before.."|1")
assert(D.Hash(a.session.state)==before)
-- Finished games remain isolated; no XP or inventory changes, even after resync.
while a.session.state.winner==nil do
 local mover=a.session.state.turn==a.session.side and a or b;local t=mover.session.state.teams[mover.session.side]
 assert(mover:Move(t.cooldown==0 and "special" or "strike"))
 local final=mover.session.state.winner~=nil
 if final then drop=function(p) return p.msg:match("^1|K|")~=nil end end
 tick(2)
 assert(D.Hash(a.session.state)==D.Hash(b.session.state))
 if final then
  local receiver=mover==a and b or a
  assert(mover.session.pending);receiver:Leave();drop=nil;tick(6)
  assert(not mover.session.pending,"Closed result did not acknowledge the retried final move")
  break
 end
end
assert(encode(G.db)==untouched);a:Leave();b:Leave();tick(2)
assert(not a.session and not b.session)
assert(a:Invite("bob","1"));tick(2);assert(b:Accept("2"));tick(3)
a:Leave();tick(4);assert(b.session.ended and b.session.winner==2);b:Leave()
-- malformed saves/packets, incompatible versions, disabled sharing, inactivity.
local malformed=make("stranger",{records={{owner="x",rules="48",lane="adventure",ending={}}},duel={owner="stranger",id="1.1.1",peer="alice",side={},lastTurn=0,log={}}})
assert(not malformed.session);for _,r in pairs(malformed.records) do assert(r.owner=="stranger") end
local beforeRecords=encode(a.records)
a:Receive("bob","1|S|48|adventure|1||24|16|32|12|0")
assert(encode(a.records)==beforeRecords,"Missing score field was accepted")
a:Receive("bob","1|H|0.0.0|1");assert(not a:Invite("bob","1"));a:Receive("bob","1|H|"..F.version.."|1")
assert(a:SetEnabled(false));a:Receive("bob","1|I|1.2.3|1|1");assert(not a.incoming);assert(a:SetEnabled(true))
assert(a:Invite("bob","1"));tick(2);assert(b:Accept("2"));tick(3);tick(122)
assert(a.session.ended and b.session.ended)
a:Leave();b:Leave();tick(2)
-- Readiness is rechecked if the host enters a campaign battle while waiting.
assert(a:Invite("bob","1"));tick(2);configs.alice.busy=true
assert(b:Accept("2"));tick(3);assert(not a.session and not b.incoming)
configs.alice.busy=false
assert(a:Invite("bob","1"));tick(2);assert(b:Accept("2"));configs.bob.busy=true
tick(5);assert(not b.session and a.session.ended and not a.session.winner)
configs.bob.busy=false;a:Leave();tick(2)
-- A retried invitation cannot reopen a declined prompt.
assert(a:Invite("bob","1"));tick(2);local cancelled=D.Copy(b.incoming);b:Decline()
b:Receive("alice","1|I|"..cancelled.id.."|"..cancelled.team.."|"..cancelled.seed)
assert(not b.incoming);tick(2);assert(not a.outgoing)
-- Resume a long valid journal in bounded chunks without overflowing the queue.
assert(a:Invite("bob","1,2,3"));tick(2);assert(b:Accept("4,7,12"));tick(3)
for _=1,156 do
 local s=a.session;local side=s.state.turn;local index=s.state.teams[side].active%3+1
 local state=D.Apply(s.state,side,"swap",index)
 s.log[#s.log+1]={seq=state.seq,actor=side,action="swap",index=index,before=D.Hash(s.state),after=D.Hash(state)};s.state=state
end
a.session.lastTurn=1800000000+math.floor(clock);a:Persist();b:Sync()
local replayLoss={}
drop=function(p)
 local seq=tonumber(p.msg:match("^1|T|[^|]+|(%d+)|"))
 if (seq==25 or seq==53 or seq==99 or seq==111) and not replayLoss[seq] then replayLoss[seq]=true;return true end
end
duplicate=true
tick(90)
assert(a.session and b.session and not a.session.ended and not b.session.ended)
assert(b.session.phase=="active" and b.session.state.seq==156 and D.Hash(a.session.state)==D.Hash(b.session.state),"Long journal did not converge")
assert(#a.queue<=128 and #b.queue<=128)
print("Social: 40 deterministic duels; friend/guild scope; offline cache/removal; loss, duplication, reload/resync, closed-result ACK, long journals, validation, forfeit and timeouts passed.")
