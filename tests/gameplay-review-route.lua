-- Debug helper: replays the existing campaign test's direct route (no quests,
-- upgrades or optional rooms) and reports levels per dungeon.
-- Usage: luajit tests/gameplay-review-route.lua [addonDir] [runsPerStarter]
local L=dofile("tests/gameplay-review-lib.lua")
local F,G=L.load(arg[1])
local runs=tonumber(arg[2]) or 8
local done,where=0,{}
local levelSum,enemySum,count={}, {}, {}
for _,starter in ipairs(F.starters) do for seed=1,runs do
 math.randomseed(seed);L.fresh(G,starter,nil,math.random);G.StartDungeon();local ok=true
 local stats={recruit=true,maxPets=tonumber(arg[3]) or 4,fights=0,turns=0,oneShots=0,trivial=0}
 for zone=1,8 do
  local transform=G.DungeonLayout(zone).transform
  local top=1;for _,p in ipairs(G.db.pets) do top=math.max(top,p.level) end;levelSum[zone]=(levelSum[zone] or 0)+top;count[zone]=(count[zone] or 0)+1
  for _,t in ipairs({{11,3},{18,3},{18,8},{11,8},{18,13}}) do
   local x,y=transform(t[1],t[2])
   if not L.walk(G,F,x,y,"smart",stats) then ok=false;break end
   local c=G.DungeonTile(x,y);if c=="K" or c=="C" or c=="T" then G.InteractDungeon() end
  end
  if not ok then where[zone]=(where[zone] or 0)+1;break end
  assert(G.InteractDungeon());enemySum[zone]=(enemySum[zone] or 0)+G.db.battle.enemy.level
  if not L.fight(G,F,"smart",stats) then ok=false;where[zone]=(where[zone] or 0)+1;break end
  G.Continue();L.ack(G);if zone<8 then assert(G.AdvanceChapter()) end
 end
 if ok then assert(G.StartRun("finale"))
  while G.db.battle do if not L.fight(G,F,"smart",stats) then ok=false;where[9]=(where[9] or 0)+1;break end;G.Continue();L.ack(G) end
 end
 if ok then done=done+1 end
end end
print("Direct-route campaigns: "..done.."/"..(#F.starters*runs))
for z=1,8 do if count[z] then print(("zone %d: team L%.1f at entry, boss L%.1f, losses %d"):format(z,levelSum[z]/count[z],(enemySum[z] or 0)/count[z],where[z] or 0)) end end
if where[9] then print("finale losses "..where[9]) end
