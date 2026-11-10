-- Flightbound 4.9 gameplay review checks: game modules only, synthetic saves,
-- fixed seeds. Usage: luajit tests/flightbound-gameplay-review.lua
local L=dofile("tests/gameplay-review-lib.lua")
local F,G=L.load()
local function eq(a,b,what) assert(a==b,(what or "value")..": "..tostring(a).." ~= "..tostring(b)) end
local function fresh(id,difficulty,rng) L.fresh(G,id,difficulty,rng) end
local function enter(zone)
 G.db.zone=zone;G.db.dungeon=nil;G.db.dungeonSaves[zone]=nil;assert(G.StartDungeon());return G.db.dungeon
end
local function find(zone,c,cacheWanted)
 local layout=G.DungeonLayout(zone)
 for y,row in ipairs(layout.rows) do for x=1,#row do
  if row:sub(x,x)==c and (cacheWanted==nil or (layout.caches[G.PointKey(x,y)]==true)==cacheWanted) then return x,y end
 end end
end

-- 1. Side areas are carved only from rock and hang off one entrance each.
local O=L.load();O.dungeonSideAreas={}
local entrances={}
for zone=1,8 do
 local old,new=O.Game.DungeonLayout(zone).rows,G.DungeonLayout(zone).rows
 eq(#new,17,"rows");local carved,total={},0
 for y=1,17 do eq(#new[y],21,"columns")
  for x=1,21 do
   local a,b=old[y]:sub(x,x),new[y]:sub(x,x)
   if a~="#" then eq(b,a,"original tile "..zone..":"..x..":"..y)
   elseif b~="#" then carved[G.PointKey(x,y)]={x=x,y=y,c=b};total=total+1;assert(x>1 and x<21 and y>1 and y<17,"Border kept") end
  end
 end
 eq(total,#F.dungeonSideAreas[zone],"every side tile placed in zone "..zone)
 local function original(x,y) local c=old[y] and old[y]:sub(x,x);return c and c~="" and c~="#" end
 local seen,secret,open={},0,0
 for key,t in pairs(carved) do if not seen[key] then
  local queue,head,doors={t},1,{};seen[key]=true
  while queue[head] do
   local a=queue[head];head=head+1;local touches=0
   for _,v in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
    local nx,ny=a.x+v[1],a.y+v[2];local k=G.PointKey(nx,ny)
    if original(nx,ny) then touches=touches+1 end
    if carved[k] and not seen[k] then seen[k]=true;queue[#queue+1]=carved[k] end
   end
   if touches>0 then doors[#doors+1]=a;eq(touches,1,"entrance touches one original tile") end
  end
  eq(#doors,1,"one entrance per side area in zone "..zone)
  if doors[1].c=="?" then secret=secret+1 elseif doors[1].c=="." then open=open+1 end
 end end
 assert(secret>=1 and open>=1,"Each dungeon has one secret and one open side area")
 -- With every cracked wall opened, the boss still needs the door; side rooms are reachable.
 fresh();local r=enter(zone);local layout=G.DungeonLayout(zone)
 for y,row in ipairs(layout.rows) do for x=1,#row do if row:sub(x,x)=="?" then r.used[G.PointKey(x,y)]=true end end end
 local bx,by=find(zone,"B");assert(not L.bfs(G,r,bx,by),"Side areas must not bypass the sealed door")
 for _,t in pairs(carved) do assert(L.bfs(G,r,t.x,t.y) or t.c=="?","Side tile unreachable") end
 for key,t in pairs(carved) do eq(layout.caches[key]==true,t.c=="T","cache marking") end
 entrances[zone]=secret+open
end
-- 2. A synthetic 4.8-era save keeps position, used objects, map and battle.
fresh("wolf");G.db.pets[1].level=12;G.db.pets[1].xp=69
local legacy=G.db;legacy.version=5;legacy.zone=3;legacy.badges={true,true}
local ox,oy=O.Game.DungeonLayout(3).transform(11,8);local kx,ky=O.Game.DungeonLayout(3).transform(18,3)
local ex,ey=O.Game.DungeonLayout(3).transform(7,3)
legacy.dungeon={zone=3,x=ex,y=ey,faceX=1,faceY=0,seed=4242,mapVersion=1,keys=1,steps=40,blessing=0,
 used={[G.PointKey(ox,oy)]=true,[G.PointKey(kx,ky)]=true},explored={[G.PointKey(ex,ey)]=true,[G.PointKey(ox,oy)]=true}}
legacy.battle={enemy={id="wisp",level=8,hp=20,maxHP=40,xp=0},zone=3,kind="wild",dungeonKey=G.PointKey(ex,ey),cooldown=1,defenseCooldown=2,turn=4,intent="strike",charmTries=0,power=1}
G.Init(legacy,L.low)
local r=G.db.dungeon;eq(r.x,ex,"legacy x");eq(r.y,ey,"legacy y");eq(r.keys,1,"legacy key")
eq(G.DungeonTile(ox,oy),".","used camp stays spent");eq(G.DungeonTile(kx,ky),".","picked key stays taken")
assert(G.db.battle and G.db.battle.defenseCooldown==2,"Legacy battle survives");eq(G.Active().level,12,"level kept");eq(G.Active().xp,69,"xp kept")
for level=1,30 do assert(G.NeedXP({level=level})>=10+level*5,"XP requirement never drops below 4.8") end
-- 3. Caches pay out but leave cargo counts (quests, awards, leaderboard) unchanged.
fresh();r=enter(1)
local cx,cy=find(1,"T",true);r.x,r.y=cx,cy;local coins,salves=G.db.coins,G.db.salves
assert(G.InteractDungeon());eq(G.Stats().treasure,0,"cache not cargo");assert(G.db.coins>coins and G.db.salves==salves+1)
assert(G.db.log:find("cache",1,true));assert(not G.InteractDungeon())
local tx,ty=find(1,"T",false);r.x,r.y=tx,ty;assert(G.InteractDungeon());eq(G.Stats().treasure,1,"cargo counts")
local p=G.DungeonProgress();eq(p.cargoTotal,3,"cargo total");eq(p.cacheTotal,2,"cache total");eq(p.cargo,1,"cargo found");eq(p.caches,1,"cache found")
eq(p.secretTotal,2,"secrets");eq(p.campTotal,2,"camps");eq(p.foeTotal,6,"foes");assert(not p.key and not p.doorOpen)
-- 4. Dungeon foes rise toward the strongest companion, within a capped band.
local function foe(zone,c,levels,difficulty)
 fresh("wolf",difficulty);G.db.totalWins=5;G.db.pets={}
 for i,l in ipairs(levels) do G.db.pets[i]=G.NewPet(F.order[i],l) end
 G.db.active=1;local run=enter(zone);local x,y=find(zone,c);return G.DungeonEnemy(x,y),run
end
eq(foe(4,"E",{5}).level,11,"under-levelled team meets authored level");eq(foe(4,"B",{5}).level,13,"guardian authored level")
eq(foe(4,"E",{20}).level,14,"wild rise capped");eq(foe(4,"R",{20}).level,15,"trainer rise capped");eq(foe(4,"B",{20}).level,16,"guardian rise capped")
eq(foe(4,"E",{3,15}).level,13,"low lead cannot drag foes down");eq(foe(4,"B",{15}).level,14,"guardian tracks team")
eq(foe(4,"B",{20},"story").level,14,"story rises one level");eq(foe(1,"B",{3}).level,4,"first guardian unchanged for new team")
eq(foe(1,"B",{9}).power,1,"first guardian has no power bonus");eq(foe(2,"B",{9}).power,F.difficulties.adventure.guardian,"guardian power")
-- 5. Route trainers use their story names; their companions cannot be tamed.
fresh();r=enter(1);local names={}
for y,row in ipairs(G.DungeonLayout(1).rows) do for x=1,#row do if row:sub(x,x)=="R" then names[#names+1]=G.DungeonEnemy(x,y).title end end end
eq(names[1],F.zones[1].rivals[1].name,"first trainer");eq(names[2],F.zones[1].rivals[2].name,"second trainer")
local rx,ry=find(1,"R");r.x,r.y=rx-1,ry;r.faceX,r.faceY=1,0
if not G.DungeonPassable(rx-1,ry) then r.x,r.y=rx+1,ry end
assert(G.StepDungeon(rx-r.x,0));eq(G.db.battle.title,names[1],"battle title");eq(G.db.battle.kind,"trainer","trainer kind")
assert(not G.Action("charm"),"Trainer companion cannot be charmed");assert(G.db.log:find(names[1],1,true))
-- 6. Hidden randomized enemy attacks are covered by flightbound-enemy-ai.lua.
-- 7. Fleeing keeps the expedition; defeat still returns to camp.
fresh("wolf");G.db.totalWins=5;r=enter(1);local sx,sy=r.x,r.y;local foeX,foeY=G.DungeonLayout(1).transform(7,3)
r.x,r.y=foeX-1,foeY;assert(G.StepDungeon(1,0));local hp=G.Active().hp-5;G.Active().hp=hp;salves=G.db.salves
assert(G.Action("flee"));eq(G.ContinueLabel(),"BACK TO MAP","flee label");G.Init(G.db,L.low);assert(G.db.battle,"Fled result survives reload")
assert(G.Continue());assert(G.db.dungeon,"Still exploring");eq(G.db.dungeonSaves[1],nil,"not banked at camp")
eq(r.x,foeX-1,"stepped back x");eq(r.y,foeY,"stepped back y");eq(G.DungeonTile(foeX,foeY),"E","foe remains")
eq(G.Active().hp,hp,"no free heal");eq(G.db.salves,salves,"no free restock")
assert(G.StepDungeon(1,0) and G.db.battle,"Foe can be re-engaged")
G.Active().hp=1;G.db.battle.intent="special";G.db.battle.enemy.hp=999;G.db.battle.enemy.maxHP=999
assert(G.Action("strike"));eq(G.db.battle.result,"lost","defeat");eq(G.ContinueLabel(),"RETURN TO CAMP","defeat label")
assert(G.Continue());assert(not G.db.dungeon and G.db.dungeonSaves[1],"Defeat banks the map at camp");eq(G.db.dungeonSaves[1].x,sx,"entrance")
-- Guardian flee steps off the guardian; it waits for a deliberate INTERACT.
fresh("wolf");G.db.totalWins=5;r=enter(1);local bx,by=find(1,"B");r.x,r.y=bx,by;r.used[G.DungeonLayout(1).doorKey]=true
assert(G.InteractDungeon() and G.db.battle.kind=="guardian");eq(G.ContinueLabel(),nil,"no label mid-battle")
assert(G.Action("flee"));assert(G.Continue());assert(G.db.dungeon and not(r.x==bx and r.y==by),"Off the guardian tile");eq(G.DungeonTile(bx,by),"B","guardian waits")
-- 8. Interact feedback when facing foes/guardian instead of standing on them.
r.faceX,r.faceY=bx-r.x,by-r.y;assert(not G.InteractDungeon());assert(G.db.log:find("Step onto",1,true))
-- 9. Shop packs fill salves to a carry limit; found or existing salves are kept.
fresh();G.db.coins=500;G.db.salves=5;assert(G.BuySupplies());eq(G.db.salves,6,"top up");eq(G.db.charms,9,"charms")
assert(G.BuySupplies());eq(G.db.salves,6,"limit");eq(G.db.charms,12,"charms still sold")
G.db.salves=20;G.db.charms=99;assert(not G.CanBuySupplies());coins=G.db.coins;assert(not G.BuySupplies());eq(G.db.coins,coins,"no charge when full");eq(G.db.salves,20,"existing stock kept")
-- 10. Older cleared dungeons offer a replay from the story button; frontier advances.
fresh();G.db.badges={true,true,true};G.db.zone=2;local goal=G.Objective();eq(goal.kind,"enter","replay kind");assert(goal.replay)
eq(goal.action,"REPLAY DUNGEON","replay action");assert(G.StartDungeon() and G.db.dungeon.zone==2);G.RetreatDungeon()
eq(G.Objective().action,"RESUME DUNGEON","resume replay");G.db.zone=3;eq(G.Objective().kind,"travel","frontier advances")
G.db.badges={true,true,true,true,true,true,true,true};G.db.ending=true;G.db.zone=8;eq(G.Objective().kind,"complete","post-game")
-- 11. Rewards badge counts, team level and finale scaling.
fresh();G.db.wins[1]=50;local quests=G.PendingRewards();eq(quests,1,"claimable quest");assert(G.ClaimQuest(1,1));eq(G.PendingRewards(),0,"claimed")
G.db.pets={G.NewPet("wolf",3),G.NewPet("murloc",30)};eq(G.TeamLevel(),30,"team level")
G.db.badges={true,true,true,true,true,true,true,true};G.db.ending=false;G.db.dungeon=nil;assert(G.StartRun("finale"));eq(G.db.battle.enemy.level,28,"finale scales")
G.db.battle=nil;G.db.run=nil;G.db.pets={G.NewPet("wolf",20)};assert(G.StartRun("finale"));eq(G.db.battle.enemy.level,26,"finale floor")
-- 12. Determinism: identical seeds give identical saves after a thorough dungeon clear.
local function serialize(v,seen)
 if type(v)~="table" then return type(v)=="string" and ("%q"):format(v) or tostring(v) end
 local keys={};for k in pairs(v) do keys[#keys+1]=k end;table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
 local out={};for _,k in ipairs(keys) do out[#out+1]=tostring(k).."="..serialize(v[k]) end;return "{"..table.concat(out,",").."}"
end
local function thorough(starter,seed,zones,difficulty)
 fresh(starter,difficulty or "adventure",L.rng(seed));local stats={recruit=true,fights=0,turns=0,oneShots=0,trivial=0}
 for zone=1,zones do
  assert(G.StartDungeon())
  for _=1,60 do
   local r=G.db.dungeon;local want={E=true,R=true,K=true,T=true,["?"]=true}
   if r.keys>0 then want.D=true end
   local target=L.nearest(G,want) or L.nearest(G,{B=true});assert(target,"No exploration target")
   local res=L.walk(G,F,target.x,target.y,"smart",stats)
   if res==false then L.ack(G);assert(G.StartDungeon())
   else
    r=G.db.dungeon;local c=G.DungeonTile(r.x,r.y)
    if target.crack then r.faceX,r.faceY=target.crack.x-r.x,target.crack.y-r.y;assert(G.InteractDungeon())
    elseif c=="K" or c=="T" then assert(G.InteractDungeon())
    elseif c=="B" then assert(G.InteractDungeon());local won=L.fight(G,F,"smart",stats);G.Continue();L.ack(G);if won then break end;assert(G.StartDungeon()) end
   end
  end
  assert(G.db.badges[zone],"Thorough player clears dungeon "..zone)
  for i=1,3 do G.ClaimQuest(zone,i) end;L.ack(G)
  if zone<zones then assert(G.AdvanceChapter());G.RetreatDungeon() end
 end
 return stats
end
thorough("murloc",11,1);local first=serialize(G.db);thorough("murloc",11,1);eq(serialize(G.db),first,"deterministic replay")
-- 13. Balance guard: thorough players meet real fights, not free wins, early on.
local fights,turns,trivial=0,0,0
for _,starter in ipairs(F.starters) do for seed=1,2 do
 local s=thorough(starter,seed*31,3);fights=fights+s.fights;turns=turns+s.turns;trivial=trivial+s.trivial
end end
assert(turns/fights>=3.5,"Fights should take several decisions");assert(trivial/fights<.25,"Too many no-XP fights: "..trivial.."/"..fights)
print(("Balance guard: %d fights, %.2f turns each, %d no-XP fights in dungeons 1-3."):format(fights,turns/fights,trivial))
print("Flightbound 4.9 gameplay: side areas, save migration, caches, scaling, trainers, flee, supplies, replay, finale and determinism checks passed.")
