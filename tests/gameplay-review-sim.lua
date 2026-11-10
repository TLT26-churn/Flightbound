-- Gameplay review simulation (report only): a thorough player explores every
-- dungeon object, buys upgrades, claims quests and achievements, then clears
-- the finale. Usage: luajit tests/gameplay-review-sim.lua [addonDir] [difficulty] [seeds]
local L=dofile("tests/gameplay-review-lib.lua")
local dir,difficulty,seeds=arg[1] or "Flightbound",arg[2] or "adventure",tonumber(arg[3]) or 8
local F,G=L.load(dir)
local function partyRatio()
 local hp,max=0,0;for _,p in ipairs(G.db.pets) do hp=hp+p.hp;max=max+G.MaxHP(p) end;return hp/max
end
local function nearest(want) return L.nearest(G,want) end
local function claimAll()
 for zone=1,#F.zones do for i=1,3 do G.ClaimQuest(zone,i) end end
 for i=1,#F.achievements do G.ClaimAchievement(i) end
 for _,i in ipairs({3,1,2,3,1,2,3,1,2}) do G.Buy(i) end
 L.ack(G)
end
local report={}
local function zoneStats(z) report[z]=report[z] or {fights=0,turns=0,oneShots=0,trivial=0,defeats=0,levels=0,bossLevel=0,bossGap=0,runs=0,recruit=true,clears=0,minHP=1,steps=0,coins=0,salves=0,bossTurns=0,bossFights=0,bossLosses=0};return report[z] end
local completions=0
for _,starter in ipairs(F.starters) do for seed=1,seeds do
 local rng=L.rng(seed*7919+#starter);L.fresh(G,starter,difficulty,rng);local ok=true
 for zone=1,8 do
  local s=zoneStats(zone);s.runs=s.runs+1;s.levels=s.levels+G.Active().level;s.coins=s.coins+G.db.coins;s.salves=s.salves+G.db.salves
  assert(G.StartDungeon());local attempts=0;local done=false
  while not done and attempts<6 do
   local want={E=true,R=true,K=true,T=true,["?"]=true}
   if G.db.dungeon.keys>0 then want.D=true end
   if partyRatio()<.6 then want.C=true end
   local target=nearest(want)
   if not target then target=nearest({B=true}) end
   if not target then error("No target in zone "..zone) end
   local res=L.walk(G,F,target.x,target.y,os.getenv("POLICY") or "smart",s)
   s.minHP=math.min(s.minHP,partyRatio())
   if res==false then
    s.defeats=s.defeats+1;attempts=attempts+1;L.ack(G);claimAll();assert(G.StartDungeon())
   elseif res==nil then error("Unreachable target") else
    local r=G.db.dungeon;local c=G.DungeonTile(r.x,r.y)
    if target.crack then r.faceX,r.faceY=target.crack.x-r.x,target.crack.y-r.y;G.InteractDungeon()
    elseif c=="K" or c=="T" or c=="C" then G.InteractDungeon()
    elseif c=="B" then
     s.bossLevel=s.bossLevel+G.DungeonEnemy(r.x,r.y).level;s.bossGap=s.bossGap+G.Active().level-G.DungeonEnemy(r.x,r.y).level
     s.steps=s.steps+r.steps
     assert(G.InteractDungeon());local won,bt=L.fight(G,F,os.getenv("POLICY") or "smart",s);G.Continue();L.ack(G)
     s.bossFights=s.bossFights+1;s.bossTurns=s.bossTurns+bt;if not won then s.bossLosses=s.bossLosses+1 end
     if won then done=true;s.clears=s.clears+1 else s.defeats=s.defeats+1;attempts=attempts+1;claimAll();assert(G.StartDungeon()) end
    end
   end
  end
  if not done then ok=false;break end
  claimAll()
  if zone<8 then assert(G.AdvanceChapter());G.RetreatDungeon() end
 end
 if ok then
  local s=zoneStats(9);s.runs=s.runs+1;s.levels=s.levels+G.Active().level
  assert(G.StartRun("finale"))
  while G.db.battle do
   local won=L.fight(G,F,os.getenv("POLICY") or "smart",s);G.Continue();L.ack(G)
   if not won then ok=false;s.defeats=s.defeats+1;break end
  end
  if ok then s.clears=s.clears+1;completions=completions+1 end
 end
end end
print(("Simulated %s, thorough exploration, %d runs: %d full completions"):format(difficulty,#F.starters*seeds,completions))
print("zone  entryL  bossL  gap  fights  turns/fight  1-action  trivial  defeats  minHP  steps  coins  salves  bossT  bossLoss")
for z=1,9 do local s=report[z]
 if s and s.runs>0 then
  print(("%4d  %6.1f  %5.1f  %4.1f  %6d  %11.2f  %8d  %7d  %7d  %5.2f  %5.1f"):format(z,s.levels/s.runs,s.bossLevel/math.max(1,s.clears+s.defeats),s.bossGap/math.max(1,s.runs),s.fights,s.turns/math.max(1,s.fights),s.oneShots,s.trivial,s.defeats,s.minHP,s.steps/math.max(1,s.runs))..("  %5d  %6.1f  %5.1f  %d/%d"):format(s.coins/s.runs,s.salves/s.runs,s.bossTurns/math.max(1,s.bossFights),s.bossLosses,s.bossFights))
 end
end
