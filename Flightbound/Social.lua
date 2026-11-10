-- Bounded peer protocol. Only the native adapter supplies identities/contacts.
-- All campaign data stays in G.db; this module owns a separate social save.
local _,F=...
local D=F.Duel
local PROTOCOL,RULES,PREFIX="1","48","FLIGHTBOUND"
F.socialPrefix=PREFIX;F.campaignRules=RULES
local function fields(message)
 if type(message)~="string" or #message>240 or message:find("[%c]") then return end
 local out={};for value in (message.."|"):gmatch("(.-)|") do out[#out+1]=value;if #out>14 then return end end
 if out[1]~=PROTOCOL then return end;return out
end
local function packet(op,...)
 local out={PROTOCOL,op};for i=1,select("#",...) do out[#out+1]=tostring(select(i,...)) end
 local s=table.concat(out,"|");assert(#s<=240);return s
end
local function sid(v) return type(v)=="string" and #v<=60 and v:match("^%d+%.%d+%.%d+$") end
local function hash(v) return D.Integer(v,0,2147483646)~=nil end
local function better(a,b)
 if not b then return true end
 for _,k in ipairs({"ending","badges","quests","rivals","treasure","collection"}) do if a[k]~=b[k] then return a[k]>b[k] end end
 return false
end
local function score(lane,ending,badges,quests,rivals,treasure,collection,imported)
 if not F.difficulties[lane] then return end
 local r={lane=lane,rules=RULES}
 local values={ending,badges,quests,rivals,treasure,collection,imported}
 for i=1,7 do
  local v=values[i]
  local k=({"ending","badges","quests","rivals","treasure","collection","imported"})[i]
  r[k]=D.Integer(v,0,({1,8,24,999,999,12,1})[i]);if not r[k] then return end
 end
 if r.ending==1 and r.badges~=8 then return end
 return r
end
local function scoreFields(r) return r.lane,r.ending,r.badges,r.quests,r.rivals,r.treasure,r.collection,r.imported end
function F.NewSocial(env,saved)
 saved=type(saved)=="table" and saved or {};saved.enabled=saved.enabled~=false
 local S={env=env,saved=saved,contacts={},peers={},queue={},time=0,scanAt=0,sendAt=0,helloAt=0,scoreAt=0,counter=0,
  status="Waiting for friends and guild roster.",rate={},records={},lastScore="",unreachable={},guildAt=0}
 local me=env.me();S.me=me
 local function now() return env.now() end
 local function wall() return env.wall() end
 local function changed(event) if env.changed then env.changed(event) end end
 local function notice(text) S.status=text;changed() end
 local function samePeer(name) return S.contacts[name] and S.contacts[name].online and (S.unreachable[name] or 0)<=now() end
 local function guildAvailable() return env.guildHello and env.inGuild and env.inGuild() end
 function S:Unreachable(peer)
  if not self.contacts[peer] then return end
  if (self.unreachable[peer] or 0)>now() then return end
  self.unreachable[peer]=now()+300;self.peers[peer]=nil
  for i=#self.queue,1,-1 do if self.queue[i].peer==peer then table.remove(self.queue,i) end end
  for _,key in ipairs({"incoming","outgoing"}) do if self[key] and self[key].peer==peer then self[key]=nil end end
  if self.session and self.session.peer==peer then self:End("Opponent could not be reached. The duel has ended.")
  else changed() end
 end
 function S:Send(peer,op,...)
  if not self.saved.enabled or not samePeer(peer) then return false end
  local text=packet(op,...)
  for _,q in ipairs(self.queue) do if q.peer==peer and q.text==text then return true end end
  if #self.queue>=128 then return false end
  local q={peer=peer,text=text,tries=0}
  if op=="H" or op=="h" or op=="S" then self.queue[#self.queue+1]=q else table.insert(self.queue,1,q) end
  return true
 end
 function S:Store(peer,r)
  if not r then return end
  local key=peer.."|"..r.lane.."|"..RULES;local old=self.records[key]
  if better(r,old) then r.owner=peer;r.achieved=wall();self.records[key]=r;old=r end
  old.seen=wall();self.saved.records=self.records
 end
 -- Discard malformed saved records; never evaluate serialized Lua or trust names in packets.
 local count=0
 for _,r in pairs(type(saved.records)=="table" and saved.records or {}) do
  if count>=1000 then break end
  if type(r)=="table" and r.rules==RULES and type(r.owner)=="string" and #r.owner<160 then
   local clean=score(r.lane,r.ending,r.badges,r.quests,r.rivals,r.treasure,r.collection,r.imported)
   if clean then
    clean.owner=r.owner;clean.seen=D.Integer(r.seen,0,4102444800) or 0;clean.achieved=D.Integer(r.achieved,0,4102444800) or clean.seen
    S.records[r.owner.."|"..r.lane.."|"..RULES]=clean;count=count+1
   end
  end
 end
 saved.records=S.records
 function S:RefreshScore()
  local r=env.score and env.score()
  if r then r=score(r.lane,r.ending,r.badges,r.quests,r.rivals,r.treasure,r.collection,r.imported) end
  if not r then return end
  self:Store(me,r);local digest=packet("S",RULES,scoreFields(r));self.ownScore=r
  if digest~=self.lastScore then
   self.lastScore=digest
   for peer,p in pairs(self.peers) do if p.version==F.version and p.seen>now()-180 then self:Send(peer,"S",RULES,scoreFields(r)) end end
  end
 end
 function S:Refresh()
  local fresh=env.contacts();if not fresh then self.scanAt=now()+5;return end;self.contacts=fresh
  -- Removal from both trusted lists immediately removes access and cached scores.
  for key,r in pairs(self.records) do if r.owner~=me and not fresh[r.owner] then self.records[key]=nil end end
  for peer in pairs(self.peers) do if not fresh[peer] then self.peers[peer]=nil end end
  if self.session and not fresh[self.session.peer] then self:End("Contact left your friends list and guild.") end
  self:RefreshScore();self.scanAt=now()+30;changed()
 end
 function S:Rows(lane)
  local out={};for _,r in pairs(self.records) do
   if r.lane==lane and (r.owner==me or self.contacts[r.owner]) then out[#out+1]=r end
  end
  table.sort(out,function(a,b) if better(a,b) then return true elseif better(b,a) then return false end;return a.owner<b.owner end)
  return out
 end
 function S:Compatible(peer)
  local p=self.peers[peer]
  return (samePeer(peer) and p and p.version==F.version and p.duelRules==D.rules and p.seen>now()-180) or false
 end
 function S:Detected(peer)
  local p=self.peers[peer]
  return (samePeer(peer) and p and type(p.version)=="string" and p.version~="" and p.seen and p.seen>now()-180) or false
 end
 function S:Persist()
  local s=self.session
  if not s then self.saved.duel=nil;return end
  self.saved.duel={id=s.id,peer=s.peer,owner=me,side=s.side,a=s.a,b=s.b,seed=s.seed,log=D.Copy(s.log),lastTurn=s.lastTurn,
   ended=s.ended,reason=s.reason,winner=s.winner}
 end
 local function createSession(id,peer,side,a,b,seed)
  local state=D.New(a,b,seed);if not state then return end
  return {id=id,peer=peer,side=side,a=a,b=b,seed=seed,state=state,log={},phase="starting",lastHeard=now(),lastTurn=wall(),retryAt=0,pingAt=0,view={duel=true,zone=9}}
 end
 local function append(s,actor,action,index,after)
  local state,event=D.Apply(s.state,actor,action,index);if not state or D.Hash(state)~=after then return end
  local row={seq=state.seq,actor=actor,action=action,index=index,before=D.Hash(s.state),after=after}
  s.log[#s.log+1]=row;s.state=state;s.lastTurn=wall()
  return event
 end
 function S:End(reason,winner)
  if not self.session then return end
  local s=self.session;s.ended=true;s.reason=reason;s.winner=winner;s.pending=nil;s.phase="finished";self:Persist();notice(reason)
 end
 function S:Leave()
  local s=self.session
  if s and s.state.winner~=nil and s.log[#s.log] then self.saved.receipt={peer=s.peer,id=s.id,row=D.Copy(s.log[#s.log]),untilTime=wall()+120} end
  if s and not s.ended and s.state.winner==nil then
   self.termination={id=s.id,peer=s.peer,untilTime=now()+12,retryAt=0};self:Send(s.peer,"Q",s.id)
  end
  self.session=nil;self.saved.duel=nil;self.outgoing=nil;self.incoming=nil;notice("Returned to the link club.")
 end
 function S:Invite(peer,team)
  local ids=D.Team(team)
  if not self.saved.enabled or not self:Compatible(peer) or not ids then notice("Friend must be online with the same Flightbound version.");return false end
  if self.session or self.outgoing or self.incoming or not env.ready(team) then notice("Finish your current battle and choose an owned team first.");return false end
  self.counter=self.counter+1;local seed=(wall()+math.floor(now()*1000)+self.counter*7919)%2147483646+1
  local id=tostring(wall()).."."..self.counter.."."..seed
  self.outgoing={id=id,peer=peer,team=team,seed=seed,expires=now()+60,retryAt=now()+3}
  self:Send(peer,"I",id,team,seed);notice("Duel invitation sent. Waiting for acceptance.");return true
 end
 function S:Decline()
  local p=self.incoming or self.outgoing;if not p then return end
  self.cancelledInvite={peer=p.peer,id=p.id,expires=now()+60}
  self:Send(p.peer,"N",p.id);self.incoming=nil;self.outgoing=nil;notice("Invitation closed.")
 end
 function S:Accept(team)
  local p=self.incoming;local ids=D.Team(team)
  if not p or p.ourTeam or not self.saved.enabled or self.session then return false end
  if p.expires<=now() or not self:Compatible(p.peer) then self:Decline();notice("That invitation expired or the inviter is no longer available.");return false end
  if not ids or #ids~=#D.Team(p.team) or not env.ready(team) then notice("Choose the same number of owned companions and finish your battle first.");return false end
  self.counter=self.counter+1
  p.ourTeam=team;p.ourSeed=(wall()+math.floor(now()*1000)+self.counter*104729)%2147483646+1;p.retryAt=now()+3
  self:Send(p.peer,"A",p.id,team,p.ourSeed);notice("Accepted. Connecting the duel...");return true
 end
 function S:Move(action,index)
  local s=self.session;index=index or 0
  if not s or s.phase~="active" or s.ended or s.pending or now()-s.lastHeard>25 then return false end
  local state,event=D.Apply(s.state,s.side,action,index);if not state then return false end
  local before,after=D.Hash(s.state),D.Hash(state)
  append(s,s.side,action,index,after);s.pending={seq=state.seq,action=action,index=index,before=before,after=after};s.retryAt=now()+2
  self:Send(s.peer,"M",s.id,state.seq,action,index,before,after);self:Persist();changed(event);return true
 end
 function S:Sync()
  local s=self.session;if not s or s.ended then return end
  s.phase="syncing";s.retryAt=now()+3;self:Send(s.peer,"R",s.id,s.state.seq,D.Hash(s.state));changed()
 end
 local function ack(self,s,seq,h) self:Send(s.peer,"K",s.id,seq,h) end
 function S:Receive(sender,message,channel)
  if not self.saved.enabled or env.available and not env.available() or not self.contacts[sender] or sender==me then return end
  local f=fields(message);if not f then return end
  if channel=="GUILD" and (not self.contacts[sender].guild or (f[2]~="H" and f[2]~="h")) then return end
  local rate=self.rate[sender] or {at=now(),n=0};if now()-rate.at>10 then rate={at=now(),n=0} end
  rate.n=rate.n+1;self.rate[sender]=rate;if rate.n>80 then return end
  local op=f[2];local p=self.peers[sender] or {};self.peers[sender]=p
  if (op=="H" or op=="h") and #f==4 and #f[3]<20 and #f[4]<12 then
   -- A received hello is fresher evidence than a delayed roster snapshot.
   self.unreachable[sender]=nil;self.contacts[sender].online=true
   p.version=f[3];p.duelRules=f[4];p.seen=now()
   if op=="H" and (not p.replied or now()-p.replied>15) then p.replied=now();self:Send(sender,"h",F.version,D.rules) end
   if p.version==F.version and self.ownScore then self:Send(sender,"S",RULES,scoreFields(self.ownScore)) end
   changed();return
  end
  if not self:Compatible(sender) then return end
  p.seen=now()
  if op=="S" and #f==11 and f[3]==RULES then self:Store(sender,score(unpack(f,4,11)));changed();return end
  if op=="I" and #f==5 and sid(f[3]) and D.Team(f[4]) and D.Integer(f[5],1,2147483646) then
   local cancelled=self.cancelledInvite
   if cancelled and cancelled.peer==sender and cancelled.id==f[3] and cancelled.expires>now() then self:Send(sender,"N",f[3]);return end
   if self.incoming and self.incoming.id==f[3] and self.incoming.peer==sender then return end
   if self.session or self.outgoing or self.incoming then self:Send(sender,"N",f[3]);return end
   self.incoming={id=f[3],peer=sender,team=f[4],seed=tonumber(f[5]),expires=now()+60}
   notice("Duel invitation received. Accept in the popup or open /fb friends.");if env.invite then env.invite(sender) end;return
  elseif op=="N" and #f==3 then
   local s=self.session
   if s and s.phase=="starting" and s.peer==sender and s.id==f[3] then self:End("Duel cancelled before starting.");return end
   for _,key in ipairs({"incoming","outgoing"}) do local x=self[key];if x and x.id==f[3] and x.peer==sender then self[key]=nil;notice("Duel invitation declined or cancelled.") end end;return
  elseif op=="A" and #f==5 then
   local x=self.outgoing;local team=D.Team(f[4]);local seed=D.Integer(f[5],1,2147483646)
   if x and x.peer==sender and x.id==f[3] and x.expires>now() and team and #team==#D.Team(x.team) and seed then
    if not env.ready(x.team) then self:Decline();notice("Invitation cancelled: finish your campaign battle first.");return end
    self.session=createSession(x.id,sender,1,x.team,f[4],(x.seed+seed)%2147483646+1);self.outgoing=nil
    local s=self.session;self:Send(sender,"B",s.id,s.a,s.b,s.seed);s.retryAt=now()+2;self:Persist();changed()
   end;return
  elseif op=="B" and #f==6 then
   local x=self.incoming
   local cancelled=self.cancelledInvite
   if cancelled and cancelled.peer==sender and cancelled.id==f[3] and cancelled.expires>now() then self:Send(sender,"N",f[3]);return end
   if x and x.peer==sender and x.id==f[3] and x.ourTeam and x.team==f[4] and x.ourTeam==f[5] and tonumber(f[6])==(x.seed+x.ourSeed)%2147483646+1 then
    if not env.ready(x.ourTeam) then self:Decline();notice("Invitation cancelled: finish your campaign battle first.");return end
    self.session=createSession(x.id,sender,2,f[4],f[5],tonumber(f[6]));self.incoming=nil
    self.session.phase="active";self:Persist();ack(self,self.session,0,D.Hash(self.session.state));changed()
   elseif self.session and self.session.peer==sender and self.session.id==f[3] and self.session.a==f[4] and self.session.b==f[5] and self.session.seed==tonumber(f[6]) then
    ack(self,self.session,0,D.Hash(D.New(f[4],f[5],tonumber(f[6]))))
   end;return
  end
  if op=="q" and #f==3 and self.termination and self.termination.peer==sender and self.termination.id==f[3] then self.termination=nil;return end
  local s=self.session
  if not s or s.peer~=sender or s.id~=f[3] then
   local r=self.saved.receipt
   if type(r)=="table" and type(r.row)=="table" and D.Integer(r.untilTime,0,4102444800) and r.untilTime>wall() and r.peer==sender and r.id==f[3]
    and op=="M" and #f==8 and tonumber(f[4])==r.row.seq and f[5]==r.row.action and tonumber(f[6])==r.row.index and f[7]==r.row.before and f[8]==r.row.after then
    self:Send(sender,"K",r.id,r.row.seq,r.row.after)
   end
   return
  end
  if op=="Q" and #f==3 then self:Send(sender,"q",s.id);if not s.ended then self:End("Opponent forfeited. You win the friendly duel!",s.side) end;return end
  if s.ended then return end
  if op=="K" and #f==5 then
   local seq=D.Integer(f[4],0,D.maxTurns)
   if seq==0 and s.phase=="starting" and f[5]==D.Hash(s.state) then s.phase="active";s.lastHeard=now();changed()
   elseif s.pending and seq==s.pending.seq and f[5]==s.pending.after then s.pending=nil;s.lastHeard=now();changed() end
  elseif op=="M" and #f==8 then
   local seq,index=D.Integer(f[4],1,D.maxTurns),D.Integer(f[6],0,3);if not seq or not index or not hash(f[7]) or not hash(f[8]) then return end
   if seq<=s.state.seq then
    local old=s.log[seq];if old and old.actor==3-s.side and old.action==f[5] and old.index==index and old.before==f[7] and old.after==f[8] then ack(self,s,seq,old.after);s.lastHeard=now() end
   elseif seq~=s.state.seq+1 or D.Hash(s.state)~=f[7] then self:Sync()
   else
    local event=append(s,3-s.side,f[5],index,f[8]);if not event then return end
    s.lastHeard=now();s.phase="active";s.pending=nil;ack(self,s,seq,f[8]);self:Persist();changed(event)
   end
  elseif op=="P" and #f==5 then
   local seq=D.Integer(f[4],0,D.maxTurns);if not seq or not hash(f[5]) then return end
   if seq==s.state.seq and f[5]==D.Hash(s.state) then
    s.lastHeard=now();if s.phase=="syncing" then s.phase="active";s.pending=nil;changed() end
   elseif seq>s.state.seq then self:Sync()
   elseif seq==s.state.seq then self:End("Duel states disagree. Reconnect by starting a new duel.") end
  elseif op=="R" and #f==5 then
   local seq=D.Integer(f[4],0,s.state.seq);if not seq then self:Send(sender,"P",s.id,s.state.seq,D.Hash(s.state));return end
   local expected=seq==0 and D.Hash(D.New(s.a,s.b,s.seed)) or s.log[seq].after
   if f[5]~=expected then self:End("Duel states disagree. Start a new duel.");return end
   s.lastHeard=now()
   -- Replace an older replay batch. Deduplication alone would leave its early
   -- rows behind newly prepended later rows, starving the next required turn.
   for i=#self.queue,1,-1 do
    local q=self.queue[i];local queued=fields(q.text)
    if q.peer==sender and queued and queued[3]==s.id and (queued[2]=="T" or queued[2]=="E") then table.remove(self.queue,i) end
   end
   -- Queue in reverse because reliable traffic is prepended; wire order remains forward.
   self:Send(sender,"E",s.id,s.state.seq,D.Hash(s.state))
   -- Bounded chunks leave room for acknowledgments even with a long saved journal.
   for i=math.min(s.state.seq,seq+24),seq+1,-1 do local r=s.log[i];self:Send(sender,"T",s.id,r.seq,r.actor,r.action,r.index,r.before,r.after) end
  elseif op=="T" and #f==9 and s.phase=="syncing" then
   local seq,actor,index=D.Integer(f[4],1,D.maxTurns),D.Integer(f[5],1,2),D.Integer(f[7],0,3)
   if not seq or not actor or not index or seq~=s.state.seq+1 or f[8]~=D.Hash(s.state) then return end
   if append(s,actor,f[6],index,f[9]) then s.lastHeard=now();self:Persist();changed() end
  elseif op=="E" and #f==5 and s.phase=="syncing" then
   local seq=D.Integer(f[4],0,D.maxTurns)
   if seq==s.state.seq and f[5]==D.Hash(s.state) then
    s.phase="active";s.pending=nil;s.lastHeard=now();self:Persist();changed()
   elseif seq and seq>s.state.seq then self:Sync() end
  end
 end
 function S:Tick()
  local t=now();if not self.saved.enabled then return end
  if env.available and not env.available() then
   local reason=env.unavailableReason and env.unavailableReason() or "Link paused by the game's chat restrictions."
   if self.status~=reason then self.status=reason;changed() end
   self.blocked=true;return
  elseif self.blocked then self.blocked=nil;self.status="Link resumed. Checking online contacts...";changed() end
  if t>=self.scanAt then self:Refresh() end
  if t>=self.scoreAt then self:RefreshScore();self.scoreAt=t+30 end
  -- One guild hello replaces individual whispers to every guild roster entry.
  -- Scores, invitations and turns still travel privately to confirmed peers.
  local guild=guildAvailable()
  if guild and t>=self.guildAt and #self.queue<12 then
   self.guildAt=t+60
   local exists=false;for _,q in ipairs(self.queue) do if q.guild then exists=true;break end end
   if not exists then self.queue[#self.queue+1]={guild=true,text=packet("H",F.version,D.rules),tries=0} end
  end
  -- Stagger remaining friend probes; all traffic shares the same throttle.
  if t>=self.helloAt and #self.queue<12 then
   self.helloAt=t+1
   local choice,oldest
   for peer,c in pairs(self.contacts) do if samePeer(peer) and (not guild or not c.guild) then
    local p=self.peers[peer] or {};local due=p.helloAt or -1
    if due<t and (not oldest or due<oldest) then choice=peer;oldest=due end
   end end
   if choice then local p=self.peers[choice] or {};self.peers[choice]=p;p.helloAt=t+120;self:Send(choice,"H",F.version,D.rules) end
  end
  for _,key in ipairs({"outgoing","incoming"}) do
   local x=self[key]
   if x then
    if t>=x.expires then self[key]=nil;notice("Duel invitation expired.")
    elseif x.retryAt and t>=x.retryAt then
     x.retryAt=t+3
     if key=="outgoing" then self:Send(x.peer,"I",x.id,x.team,x.seed)
     elseif x.ourTeam then self:Send(x.peer,"A",x.id,x.ourTeam,x.ourSeed) end
    end
   end
  end
  local s=self.session
  if s and not s.ended then
   local quiet=t-s.lastHeard>25
   if s.quiet~=quiet then s.quiet=quiet;changed() end
   if s.pending and t-s.lastHeard>=120 then self:End("Connection lost. The duel result could not be confirmed.")
   elseif wall()-s.lastTurn>=120 and s.state.winner==nil then self:End("Duel ended after two minutes without a move.")
   else
    if t>=s.pingAt then s.pingAt=t+10;self:Send(s.peer,"P",s.id,s.state.seq,D.Hash(s.state)) end
    if t>=s.retryAt then
     s.retryAt=t+3
     if s.phase=="starting" then self:Send(s.peer,"B",s.id,s.a,s.b,s.seed)
     elseif s.phase=="syncing" then self:Send(s.peer,"R",s.id,s.state.seq,D.Hash(s.state))
     elseif s.pending then local r=s.pending;self:Send(s.peer,"M",s.id,r.seq,r.action,r.index,r.before,r.after) end
    end
   end
  end
  local q=self.termination
  if q then
   if t>q.untilTime then self.termination=nil elseif t>=q.retryAt then q.retryAt=t+3;self:Send(q.peer,"Q",q.id) end
  end
  if t>=self.sendAt and #self.queue>0 then
   self.sendAt=t+.35;local item=table.remove(self.queue,1);local c=self.contacts[item.peer]
   if item.guild and guild or c and samePeer(item.peer) then
    local ok,reason,permanent
    if item.guild then ok,reason,permanent=env.guildHello(item.text)
    else ok,reason,permanent=env.send(c.name,item.text) end
    if not ok then
     self.status="Link message could not be sent: "..tostring(reason or "unavailable")
     item.tries=item.tries+1;if item.tries<3 and not permanent then self.queue[#self.queue+1]=item;self.sendAt=t+1 end;changed()
    end
   end
  end
 end
 function S:SetEnabled(enabled)
  if self.session then return false end
  if not enabled then self:Decline() end
  self.saved.enabled=enabled==true
  if not enabled then self.queue={} end
  notice(enabled and "Friend and guild sync enabled." or "Friend and guild sync paused.");return true
 end
 -- Rebuild from a validated action journal after /reload. Never trust saved HP.
 local r=saved.duel
 if type(r)=="table" and not r.ended and r.owner==me and sid(r.id) and type(r.peer)=="string" and #r.peer<160 and D.Integer(r.side,1,2)
  and D.Integer(r.lastTurn,0,4102444800) and r.lastTurn<=wall()+5 and wall()-r.lastTurn<120 and type(r.log)=="table" and #r.log<=D.maxTurns then
  local s=createSession(r.id,r.peer,r.side,r.a,r.b,r.seed);local valid=s~=nil
  if s then for _,row in ipairs(r.log) do
   if type(row)~="table" or row.seq~=s.state.seq+1 or row.before~=D.Hash(s.state) or not append(s,row.actor,row.action,row.index,row.after) then valid=false;break end
  end end
  if valid then s.lastTurn=r.lastTurn;s.phase="syncing";S.session=s end
 end
 if not S.session then saved.duel=nil end
 return S
end
