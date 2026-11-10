-- Pure, deterministic link battles. This module never reads or writes G.db.
local _,F=...
local G=F.Game
local D={rules="1",level=14,maxTurns=200};F.Duel=D
function D.Copy(v)
 if type(v)~="table" then return v end
 local out={};for k,x in pairs(v) do out[k]=D.Copy(x) end;return out
end
function D.Integer(v,lo,hi)
 if type(v)~="number" and type(v)~="string" then return end
 local n=tonumber(v);if not n or n~=math.floor(n) or n<lo or n>hi then return end;return n
end
function D.Team(value)
 if type(value)~="string" or #value>12 or not value:match("^%d+[, %d]*$") or value:find(" ") then return end
 local ids,seen={},{}
 for n in value:gmatch("[^,]+") do
  local i=D.Integer(n,1,#F.order)
  if not i or seen[i] then return end
  ids[#ids+1]=F.order[i];seen[i]=true
 end
 if #ids<1 or #ids>3 then return end
 local canonical={};for _,id in ipairs(ids) do for i,s in ipairs(F.order) do if s==id then canonical[#canonical+1]=i end end end
 if table.concat(canonical,",")~=value then return end
 return ids
end
function D.EncodeTeam(ids)
 local out={};for _,id in ipairs(ids or {}) do
  local found;for i,s in ipairs(F.order) do if s==id then found=i;break end end
  if not found then return end;out[#out+1]=found
 end
 local value=table.concat(out,",");return D.Team(value) and value or nil
end
local function pet(id) return G.NewPet(id,D.level) end
function D.New(a,b,seed)
 local ta,tb=D.Team(a),D.Team(b);seed=D.Integer(seed,1,2147483646)
 if not ta or not tb or #ta~=#tb or not seed then return end
 local s={seq=0,rng=seed,turn=seed%2+1,teams={},log="A friendly link battle begins!"}
 for i,ids in ipairs({ta,tb}) do
  local team={pets={},active=1,cooldown=0,defense=0,guard=false,focus=false,weaken=false,burn=0}
  for _,id in ipairs(ids) do team.pets[#team.pets+1]=pet(id) end;s.teams[i]=team
 end
 return s
end
local function nextRoll(s) s.rng=s.rng*48271%2147483647;return 92+s.rng%17 end
local function active(s,i) local t=s.teams[i];return t.pets[t.active] end
D.Active=active
function D.Hash(s)
 local v={s.seq,s.rng,s.turn,s.winner or 0}
 for _,t in ipairs(s.teams) do
  for _,n in ipairs({t.active,t.cooldown,t.defense,t.guard and 1 or 0,t.focus and 1 or 0,t.weaken and 1 or 0,t.burn}) do v[#v+1]=n end
  for _,p in ipairs(t.pets) do v[#v+1]=p.id;v[#v+1]=p.hp end
 end
 local text=table.concat(v,",");local h=7
 for i=1,#text do h=(h*31+text:byte(i))%2147483647 end
 return tostring(h)
end
function D.Legal(s,side,action,index)
 if not s or s.winner or s.turn~=side then return false end
 local t=s.teams[side]
 if action=="strike" then return true
 elseif action=="special" then return t.cooldown==0
 elseif action=="guard" then return t.defense==0 and not t.guard
 elseif action=="focus" then return not t.focus
 elseif action=="swap" then return D.Integer(index,1,#t.pets)~=nil and index~=t.active and t.pets[index].hp>0 end
 return false
end
local function faint(s,side)
 local t=s.teams[side];if active(s,side).hp>0 then return end
 for i,p in ipairs(t.pets) do if p.hp>0 then t.active=i;return end end
 s.winner=3-side
end
function D.Apply(original,side,action,index)
 if not D.Legal(original,side,action,index) then return end
 local s=D.Copy(original);local foe=3-side;local t,enemy=s.teams[side],s.teams[foe]
 local event={actor=side,action=action,hits={},before={D.Copy(active(s,1)),D.Copy(active(s,2))}}
 if action=="swap" then t.active=index;event.before[side]=D.Copy(active(s,side)) end
 local p,q=active(s,side),active(s,foe)
 if action=="strike" or action=="special" then
  local special=action=="special";local sa,sb=G.Spec(p),G.Spec(q)
  local mult=special and G.Multiplier(sa.kind,sb.kind) or 1;local roll=nextRoll(s);local crit=roll>=107
  local modifier=(special and t.focus and 1.65 or 1)*(enemy.guard and .35 or 1)*(t.weaken and .65 or 1)
  local damage=math.max(2,math.floor(((sa.attack+p.level*1.5)*(special and 1.65 or 1)*mult*roll/100-(sb.defense+q.level*.3)*.45)*1.08*modifier))
  if crit then damage=math.floor(damage*1.5) end
  local before=q.hp;q.hp=math.max(0,q.hp-damage)
  event.hits[1]={source=side,target=foe,id=p.id,tier=3,special=special,critical=crit,amount=damage,multiplier=mult,beforeHP=before,afterHP=q.hp,blocked=enemy.guard}
  enemy.guard=false;t.weaken=false
  if special then
   t.cooldown=3;t.focus=false
   if sa.kind=="EMBER" or sa.kind=="SHADOW" then enemy.burn=2
   elseif sa.kind=="TIDE" or sa.kind=="GROVE" then p.hp=math.min(G.MaxHP(p),p.hp+math.ceil(G.MaxHP(p)*.12))
   elseif sa.kind=="ARCANE" then enemy.weaken=true
   elseif sa.kind=="BEAST" then t.guard=true end
  end
  s.log=G.Name(p).." used "..(special and sa.move or "Strike")..": "..damage..(crit and " CRITICAL!" or ".")
 elseif action=="guard" then t.guard=true;t.defense=3;s.log=G.Name(p).." used "..F.defensiveMoves[p.id].."!"
 elseif action=="focus" then t.focus=true;s.log=G.Name(p).." focused its next special."
 else s.log=G.Name(p).." steps into the duel." end
 t.cooldown=math.max(0,t.cooldown-1);t.defense=math.max(0,t.defense-1)
 faint(s,foe)
 -- Burn ticks after the affected side takes its turn; no critical burn damage.
 if not s.winner and t.burn>0 then
  local before=p.hp;local damage=math.max(2,math.floor(G.MaxHP(p)*.06));p.hp=math.max(0,p.hp-damage);t.burn=t.burn-1
  event.hits[#event.hits+1]={source="status",target=side,amount=damage,beforeHP=before,afterHP=p.hp}
  faint(s,side)
 end
 s.seq=s.seq+1;s.turn=foe
 if not s.winner and s.seq>=D.maxTurns then s.winner=0;s.log="Turn limit reached. The duel is a draw." end
 event.result=s.winner;event.log=s.log
 return s,event
end
