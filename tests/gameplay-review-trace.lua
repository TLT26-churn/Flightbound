-- Debug helper: trace the existing first-dungeon route for one starter.
-- Usage: luajit tests/gameplay-review-trace.lua [addonDir] [starter] [seeds]
local L=dofile("tests/gameplay-review-lib.lua")
local F,G=L.load(arg[1])
local starter,seeds=arg[2] or "murloc",tonumber(arg[3]) or 6
local wins=0
for seed=1,seeds do
 math.randomseed(seed);L.fresh(G,starter,nil,math.random);G.StartDungeon();local line={}
 for _,t in ipairs({{11,3},{18,3},{11,8},{18,13}}) do
  local x,y=G.DungeonLayout(1).transform(t[1],t[2])
  local r=G.db.dungeon;local path=L.bfs(G,r,x,y,true)
  for _,v in ipairs(path) do r=G.db.dungeon
   if G.DungeonTile(r.x+v[1],r.y+v[2])=="D" then G.InteractDungeon() end
   G.StepDungeon(v[1],v[2])
   if G.db.battle then local b=G.db.battle;local p=G.Active()
    local won=L.fight(G,F,"smart");line[#line+1]=b.enemy.id..b.enemy.level..(won and "+" or "-")
    G.Init(G.db,G.random);G.Continue();L.ack(G);if not won then break end
   end
  end
  if not G.db.dungeon then break end
  local c=G.DungeonTile(G.db.dungeon.x,G.db.dungeon.y);if c=="K" or c=="C" then G.InteractDungeon() end
 end
 if G.db.dungeon then
  G.InteractDungeon();local b=G.db.battle;local p=G.Active();local lvl,xp=p.level,p.xp
  local won,turns=L.fight(G,F,"smart");if won then wins=wins+1 end
  line[#line+1]=("BOSS %s%d vs L%d(%dxp) %s in %d"):format(b.enemy.id,b.enemy.level,lvl,xp,won and "WIN" or "LOSS",turns)
 end
 print(seed,table.concat(line," "))
end
print(starter,"boss wins",wins,"/",seeds)
