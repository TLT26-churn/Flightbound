local F={}
for _,n in ipairs({"Data","Game","Adventure","Campaign","Trainer","DungeonMap"}) do assert(loadfile("Flightbound/"..n..".lua"))("Flightbound",F) end
local G=F.Game
local function low(a,b) return b and a or 1 end
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function fresh(id,difficulty,rng)
 G.Init(nil,rng or low);assert(G.SetTrainer({name="Valette Ashborne",race="human",class="WARRIOR",gender=2}));assert(G.Start(id or "wolf"))
 if difficulty then assert(G.SetDifficulty(difficulty)) end
end
local function ack() G.db.scene=nil;G.db.evolutions={} end
local recruit=false
local function fight(smart)
 local b=G.db.battle;local turns=0
 while not b.result and turns<200 do
  local p=G.Active();local action="strike"
  if smart then
   if p.hp<G.MaxHP(p)*.40 and G.db.salves>0 then action="salve"
   elseif recruit and #G.db.pets<4 and not b.boss and not G.Owns(b.enemy.id) and b.enemy.hp/G.MaxHP(b.enemy)<=.5 and G.db.charms>0 then action="charm"
   elseif b.cooldown>0 and p.hp<G.MaxHP(p)*.65 and (b.defenseCooldown or 0)==0 then action="guard"
   elseif b.cooldown==0 then action="special" end -- Even resisted specials can heal/protect after evolution.
  end
  assert(G.Action(action));turns=turns+1
 end
 assert(turns<200)
 if b.result=="caught" then assert(G.PendingPet());assert(G.ResolvePetName(nil)) end
 return b.result=="win" or b.result=="caught"
end
local function bfs(r,tx,ty,ignoreDoor)
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
local function point(c,zone)
 for y,row in ipairs(G.DungeonLayout(zone or G.db.zone).rows) do for x=1,#row do if row:sub(x,x)==c then return x,y end end end
end
local function walk(tx,ty,smart)
 local r=G.db.dungeon;local path=bfs(r,tx,ty,true);assert(path,"Unreachable test destination")
 for _,v in ipairs(path) do
  if G.DungeonTile(r.x+v[1],r.y+v[2])=="D" then
   assert(not G.StepDungeon(v[1],v[2]));assert(G.InteractDungeon())
  end
  assert(G.StepDungeon(v[1],v[2]))
  if G.db.battle then
   if not fight(smart) then return false end
   G.Init(G.db,G.random);G.Continue();ack()
  end
 end
 return true
end
-- All official combinations, both genders, reject invalid combinations.
local combinations=0
for _,race in ipairs(F.trainerRaces) do for _,class in ipairs(race.classes) do for sex=1,2 do
 assert(G.SanitizeTrainer({race=race.id,class=class,gender=sex,name="Trainer"}));combinations=combinations+1
end end end
eq(combinations,112)
assert(not G.SanitizeTrainer({race="human",class="DRUID",gender=1,name="No"}))
assert(not G.SanitizeTrainer({race="skyborne_alliance",class="SHAMAN",gender=2,name="No"}))
assert(not G.SanitizeTrainer({race="skyborne_horde",class="MAGE",gender=1,name="No"}))
assert(not G.SanitizeTrainer({race="human",class="WARRIOR",gender=3,name="No"}))
UnitRace=function() return "Undead","Scourge" end;UnitClass=function() return "Paladin","PALADIN" end
UnitSex=function() return 3 end;UnitName=function() return "Valette Ashborne" end
local hero=G.PlayerTrainer();eq(hero.race,"undead");eq(hero.class,"PALADIN");eq(hero.gender,2)
UnitRace=nil;UnitClass=nil;UnitSex=nil;UnitName=nil
G.Init(nil);assert(not G.Start("wolf"));fresh();eq(G.db.version,5);eq(G.db.settings.difficulty,"adventure")
-- A successful tame prompts immediately; nickname/skip and pending state persist.
fresh("murloc");assert(G.Encounter(false,{id="wolf",level=2}));G.db.battle.enemy.hp=1
assert(G.Action("charm"));eq(G.db.pendingName,"wolf");assert(not G.Continue())
local captureLog=G.db.log;G.Init(G.db,low);eq(G.PendingPet().id,"wolf")
assert(G.ResolvePetName("  Moon  Fang  "));eq(G.FindPet("wolf").nickname,"Moon Fang");eq(G.db.log,captureLog)
assert(G.Continue());G.Init(G.db,low);eq(G.Name(G.FindPet("wolf")),"Moon Fang")
assert(G.Encounter(false,{id="boar",level=2}));G.db.battle.enemy.hp=1;assert(G.Action("charm"))
assert(G.ResolvePetName(nil));assert(not G.FindPet("boar").nickname);eq(G.Name(G.FindPet("boar")),G.FormName(G.FindPet("boar")))
assert(G.Continue());G.db.pendingName="missing";G.Init(G.db,low);assert(not G.db.pendingName)
-- All authored maps are distinct; key is reachable before door; boss is not.
local layouts={}
for zone=1,8 do
 fresh();G.db.zone=zone;G.StartDungeon();local r=G.db.dungeon;local layout=G.DungeonLayout(zone)
 local signature=table.concat(layout.rows,"\n");assert(not layouts[signature]);layouts[signature]=true
 eq(#layout.rows,17);for _,row in ipairs(layout.rows) do eq(#row,21) end
 local kx,ky=point("K");local bx,by=point("B");assert(bfs(r,kx,ky));assert(not bfs(r,bx,by));assert(bfs(r,bx,by,true))
 assert(not r.explored[G.PointKey(bx,by)]);assert(not G.StepDungeon(1,1));assert(not G.Camp())
end
-- One tile per action; standing still/initialization never moves or completes an encounter.
fresh();G.StartDungeon();local r=G.db.dungeon;local x,y=r.x,r.y
G.Init(G.db);eq(r.x,x);eq(r.y,y);assert(G.StepDungeon(1,0));eq(r.x,x+1);eq(r.y,y)
local seen=G.Count(r.explored);G.Init(G.db);eq(G.Count(r.explored),seen)
-- Loot and camp uses persist through reload and leaving/re-entering the dungeon.
local tx,ty=point("T");r.x,r.y=tx,ty;G.RevealDungeon();local gold=G.db.coins
assert(G.InteractDungeon());assert(G.db.routes[1].treasures[G.PointKey(tx,ty)]);assert(G.db.coins>gold);gold=G.db.coins;assert(not G.InteractDungeon());eq(G.db.coins,gold)
local cx,cy=point("C");r.x,r.y=cx,cy;G.Active().hp=1;assert(G.InteractDungeon());assert(G.Active().hp>1)
G.Active().hp=1;assert(not G.InteractDungeon());eq(G.Active().hp,1)
local kx,ky=point("K");r.x,r.y=kx,ky;G.InteractDungeon();eq(r.keys,1)
G.RetreatDungeon();assert(not G.db.dungeon);assert(G.StartDungeon());r=G.db.dungeon
assert(r.used[G.PointKey(tx,ty)] and r.used[G.PointKey(cx,cy)]);eq(r.keys,1);eq(G.db.coins,gold)
-- Key consumption, door persistence and secret passage.
local dx,dy=point("D");r.x,r.y=dx-1,dy;r.faceX,r.faceY=1,0
assert(G.InteractDungeon());eq(r.keys,0);assert(G.DungeonPassable(dx,dy))
local sx,sy=point("?");r.x,r.y=sx,sy-1;r.faceX,r.faceY=0,1
assert(G.InteractDungeon());assert(G.DungeonPassable(sx,sy))
G.Init(G.db);assert(G.DungeonPassable(dx,dy));assert(G.DungeonPassable(sx,sy))
-- Reset once, preserve the old game, keep only preferences and force harder default.
local old={pets={{id="wolf",level=20}},coins=999,settings={scale=.85,auto=false,difficulty="story"}}
local new,backup=G.ApplyRequestedReset(old);assert(backup==old);new=G.Init(new)
eq(#new.pets,0);assert(not new.trainer);eq(new.settings.scale,.85);eq(new.settings.difficulty,"adventure")
assert(G.ApplyRequestedReset(new,backup)==new);new.settings.scale=1;eq(old.settings.scale,.85)
-- Evolution and nickname persistence for every lineage.
for _,id in ipairs(F.order) do
 fresh();G.db.pets={G.NewPet(id,5)};G.Rename(1,"Buddy");local p=G.Active();p.hp=1;p.xp=G.NeedXP(p)-1
 G.GainXP(p,1);eq(G.Tier(p),2);eq(G.Name(p),"Buddy");assert(p.hp<G.MaxHP(p));eq(#G.db.evolutions,1)
 G.Init(G.db);p=G.Active();p.level=13;p.xp=G.NeedXP(p)-1;G.GainXP(p,1);eq(G.Tier(p),3);eq(#G.db.evolutions,2)
end
-- Difficulty, guards, salves, trivial XP and finite quest rewards.
fresh();G.db.totalWins=10;G.db.pets={G.NewPet("wolf",10),G.NewPet("boar",1)}
G.Encounter(false,{id="murloc",level=1});G.db.battle.enemy.hp=1;G.Action("strike");eq(G.Active().xp,0);eq(G.db.pets[2].xp,0)
G.Continue();G.db.pets={G.NewPet("wolf",5)};G.Encounter(false,{id="boar",level=8})
G.Active().hp=30;G.Action("guard");assert(G.Active().hp<30)
G.db.battle=nil;G.db.wins[1]=100;assert(G.ClaimQuest(1,1));assert(not G.ClaimQuest(1,1))
-- Balance comparison: same four-fight excursion, rested at an actual campsite.
-- Defensive cooldowns are real turns, survive reload, and cannot be reset by
-- swapping. Invalid actions, menu navigation and waiting never advance them.
fresh("murloc");G.db.totalWins=10;G.db.pets={G.NewPet("murloc",20),G.NewPet("wolf",20)}
assert(G.Encounter(false,{id="boar",level=10}))
local b=G.db.battle;local p=G.Active();local before=p.hp
local fullDamage=G.Damage(b.enemy,p,true,1);p.hp=before
local expected=G.Damage(b.enemy,p,true,.35);p.hp=before -- low RNG picks a special.
assert(G.Action("guard"));eq(before-p.hp,expected);assert(expected<fullDamage)
eq(b.defenseCooldown,2);eq(b.turn,1);assert(G.db.log:find("Bubble Guard",1,true))
local hp=p.hp;local log=G.db.log
assert(not G.Action("guard"));eq(b.turn,1);eq(p.hp,hp);eq(G.db.log,log);eq(b.defenseCooldown,2)
assert(not G.Action("invalid"));assert(not G.Action("swap",1));eq(b.defenseCooldown,2)
G.Init(G.db,low);b=G.db.battle;eq(b.defenseCooldown,2);eq(G.db.version,5)
assert(G.Action("swap",2));eq(b.defenseCooldown,1);assert(not G.Action("guard"))
assert(G.Action("focus"));eq(b.defenseCooldown,0)
assert(G.Action("guard"));eq(b.defenseCooldown,2);assert(G.db.log:find("Evasive Prowl",1,true))
-- Upgrading an existing battle defaults only the new field, preserving progress.
b.defenseCooldown=nil;local turns=b.turn;G.Init(G.db,low);eq(G.db.battle.defenseCooldown,0);eq(G.db.battle.turn,turns)
G.db.battle.defenseCooldown="bad";G.Init(G.db,low);eq(G.db.battle.defenseCooldown,0)
G.db.battle.defenseCooldown=999;G.Init(G.db,low);eq(G.db.battle.defenseCooldown,2)
G.db.battle=nil;assert(G.Encounter(false,{id="boar",level=10}));eq(G.db.battle.defenseCooldown,0)
-- Every displayed evolved special has the actual move name used by combat.
for _,id in ipairs(F.order) do for _,level in ipairs({1,6,14}) do
 fresh();G.db.pets={G.NewPet(id,level)};assert(G.Encounter(false,{id="boar",level=1}))
 G.db.battle.enemy.hp=1000;G.db.battle.enemy.maxHP=1000
 assert(F.defensiveMoves[id]);assert(G.Action("special"));assert(G.db.log:find(G.Spec(G.Active()).move,1,true))
end end
local totals={smart=0,blind=0};local report={}
for _,starter in ipairs(F.starters) do
 local wins={smart=0,blind=0}
 for seed=1,60 do for _,strategy in ipairs({"smart","blind"}) do
  math.randomseed(seed);fresh(starter,nil,math.random);G.StartDungeon()
  local ok=true
  for _,target in ipairs({{11,3},{18,3},{11,8},{18,13}}) do
   local x,y=G.DungeonLayout(1).transform(target[1],target[2])
   if not walk(x,y,strategy=="smart") then ok=false;break end
   local tile=G.DungeonTile(x,y)
   if tile=="K" or tile=="C" then G.InteractDungeon() end
  end
  if ok then assert(G.InteractDungeon());ok=fight(strategy=="smart") end
  if ok then wins[strategy]=wins[strategy]+1;totals[strategy]=totals[strategy]+1 end
 end end
 report[#report+1]=starter..": tactical "..wins.smart.."/60, Strike-only "..wins.blind.."/60 first-dungeon clears"
 assert(wins.smart>=45,"Opening too punishing for "..starter)
end
assert(totals.smart>totals.blind,"Tactics should improve success")
print("Flightbound 4.7: defense timing, recovery/save migration, move names, naming, maps, saves, evolution and economy checks passed.")
for _,line in ipairs(report) do print(line) end

-- Walk complete campaigns through real corridors, picking up the key, supplies and camps.
recruit=true;local completed,losses=0,{}
for _,starter in ipairs(F.starters) do for seed=1,8 do
 math.randomseed(seed);fresh(starter,nil,math.random);G.StartDungeon();local success=true
 for zone=1,8 do
  local transform=G.DungeonLayout(zone).transform
  for _,target in ipairs({{11,3},{18,3},{18,8},{11,8},{18,13}}) do
   local x,y=transform(target[1],target[2])
   if not walk(x,y,true) then success=false;losses[zone]=(losses[zone] or 0)+1;break end
   local tile=G.DungeonTile(x,y)
   if tile=="K" or tile=="C" or tile=="T" then G.InteractDungeon() end
  end
  if not success then break end
  assert(G.InteractDungeon());if not fight(true) then success=false;losses[zone]=(losses[zone] or 0)+1;break end
  G.Continue();ack();assert(G.db.badges[zone])
  if zone<8 then assert(G.AdvanceChapter()) end
 end
 if success then
  assert(G.StartRun("finale"))
  while G.db.battle do
   if not fight(true) then success=false;losses[9]=(losses[9] or 0)+1;break end
   G.Continue();ack()
  end
 end
 if success then completed=completed+1 end
end end
print("Manual-map tactical campaign + finale completions: "..completed.."/24")
for zone,n in pairs(losses) do print("Losses in dungeon/finale "..zone..": "..n) end
assert(completed>=18,"Later campaign needs balancing")
