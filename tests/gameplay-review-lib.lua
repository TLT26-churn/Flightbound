-- Shared headless helpers for the gameplay review: loads only game modules,
-- uses synthetic saves and caller-provided deterministic RNG.
local L={}
function L.load(path)
 local F={}
 for _,n in ipairs({"Data","Game","Adventure","Campaign","Trainer","DungeonMap"}) do
  assert(loadfile((path or "Flightbound").."/"..n..".lua"))("Flightbound",F)
 end
 return F,F.Game
end
function L.low(a,b) return b and a or 1 end
-- Park-Miller stream; identical across Lua 5.1/LuaJIT and independent of math.random.
function L.rng(seed)
 local state=seed%2147483646+1
 return function(a,b)
  state=(state*48271)%2147483647
  if not b then b=a;a=1 end
  return a+state%(b-a+1)
 end
end
function L.fresh(G,id,difficulty,rng)
 G.Init(nil,rng or L.low)
 assert(G.SetTrainer({name="Review Trainer",race="dwarf",class="SHAMAN",gender=1}))
 assert(G.Start(id or "wolf"))
 if difficulty then assert(G.SetDifficulty(difficulty)) end
end
function L.ack(G) G.db.scene=nil;G.db.evolutions={} end
-- Breadth-first path over passable tiles; doors count only when allowed.
function L.bfs(G,r,tx,ty,ignoreDoor)
 local queue={{x=r.x,y=r.y}};local seen={[G.PointKey(r.x,r.y)]=true};local head=1
 while queue[head] do
  local a=queue[head];head=head+1
  if a.x==tx and a.y==ty then return a.path or {} end
  for _,v in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
   local x,y=a.x+v[1],a.y+v[2];local c=G.DungeonTile(x,y,r);local key=G.PointKey(x,y)
   if not seen[key] and (G.DungeonPassable(x,y,r) or ignoreDoor and c=="D") then
    seen[key]=true;local path={};for _,step in ipairs(a.path or {}) do path[#path+1]=step end;path[#path+1]=v
    queue[#queue+1]={x=x,y=y,path=path}
   end
  end
 end
end
function L.points(G,zone,c)
 local result={}
 for y,row in ipairs(G.DungeonLayout(zone).rows) do for x=1,#row do
  if c==nil or row:sub(x,x)==c then result[#result+1]={x=x,y=y,c=row:sub(x,x)} end
 end end
 return result
end
-- A player limited to visible information: heals low, guards while waiting for
-- their special to recover, uses specials and recruits new species.
function L.fight(G,F,policy,stats)
 local b=G.db.battle;local turns=0;policy=policy or "smart"
 while not b.result and turns<250 do
  local p=G.Active();local action="strike";local index
  if policy=="smart" then
   local mult=G.Multiplier(F.species[p.id].kind,F.species[b.enemy.id].kind)
   if p.hp<G.MaxHP(p)*.40 and G.db.salves>0 then action="salve"
   elseif stats and stats.recruit and #G.db.pets<(stats.maxPets or 6) and not b.boss and not G.Owns(b.enemy.id) and b.enemy.hp/G.MaxHP(b.enemy)<=.5 and G.db.charms>0 then action="charm"
   elseif b.cooldown>0 and p.hp<G.MaxHP(p)*.65 and (b.defenseCooldown or 0)==0 then action="guard"
   elseif b.cooldown==0 then action="special" end
  end
  local ok=G.Action(action,index)
  if not ok then ok=G.Action("strike") end
  assert(ok,"Policy produced no legal action");turns=turns+1
 end
 assert(turns<250,"Battle did not terminate")
 if stats then
  stats.fights=stats.fights+1;stats.turns=stats.turns+turns
  if turns<=1 and b.result=="win" then stats.oneShots=stats.oneShots+1 end
  if b.trivial then stats.trivial=stats.trivial+1 end
 end
 if b.result=="caught" then assert(G.PendingPet());assert(G.ResolvePetName(nil)) end
 return b.result=="win" or b.result=="caught",turns,b
end
-- Walk along a path; doors are opened when the key is held. Encounters fight.
function L.walk(G,F,tx,ty,policy,stats)
 local r=G.db.dungeon;local path=L.bfs(G,r,tx,ty,true);if not path then return nil end
 for _,v in ipairs(path) do
  r=G.db.dungeon
  if G.DungeonTile(r.x+v[1],r.y+v[2])=="D" then
   if r.keys<1 then return nil end
   r.faceX,r.faceY=v[1],v[2];assert(G.InteractDungeon())
  end
  assert(G.StepDungeon(v[1],v[2]))
  if G.db.battle then
   local won=L.fight(G,F,policy,stats)
   G.Init(G.db,G.random);G.Continue();L.ack(G)
   if not won then return false end
  end
 end
 return true
end
-- Nearest unused object of the wanted kinds; cracked walls return the tile
-- beside them plus the wall to face.
function L.nearest(G,want)
 local r=G.db.dungeon;local best,bestLen
 for _,pt in ipairs(L.points(G,r.zone)) do
  local key=G.PointKey(pt.x,pt.y);local c=G.DungeonTile(pt.x,pt.y,r)
  if want[c] and not r.used[key] and not (pt.x==r.x and pt.y==r.y) then
   if c=="?" then
    for _,v in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
     local ax,ay=pt.x+v[1],pt.y+v[2]
     if G.DungeonPassable(ax,ay,r) then
      local p2=L.bfs(G,r,ax,ay,r.keys>0)
      if p2 and (not bestLen or #p2<bestLen) then best,bestLen={x=ax,y=ay,crack={x=pt.x,y=pt.y}},#p2 end
     end
    end
   else
    local path=L.bfs(G,r,pt.x,pt.y,r.keys>0)
    if path and (not bestLen or #path<bestLen) then best,bestLen={x=pt.x,y=pt.y},#path end
   end
  end
 end
 return best
end
return L
