-- Hidden enemy decisions: no fixed cadence, no turn committed on rejected input,
-- and guard never influences the enemy's roll. Synthetic saves only.
local F={}
for _,n in ipairs({"Data","Game","Adventure","Campaign","Trainer","DungeonMap"}) do
 assert(loadfile("Flightbound/"..n..".lua"))("Flightbound",F)
end
local G=F.Game
local function fresh(kind,zone,wins)
 G.Init(nil,function(a,b) return b and a or 1 end)
 G.SetTrainer({name="Tester",race="human",class="WARRIOR",gender=2});G.Start("wolf")
 G.db.zone=zone or 2;G.db.totalWins=wins or 10;G.db.badges[G.db.zone]=true
 assert(G.Encounter(kind~="wild",{id="boar",kind=kind,level=8}))
 local b=G.db.battle;b.enemy.hp=10000;b.enemy.maxHP=10000;G.Active().hp=10000
 return b
end
local samples=0
for _,case in ipairs({{"wild",1,0,1,20},{"wild",2,10,1,35},{"trainer",1,10,1,20},
 {"trainer",2,10,1,35},{"trainer",2,10,.4,50},{"guardian",1,10,.4,20},
 {"guardian",2,10,.4,50},{"finale",8,10,.4,50}}) do
 for _,action in ipairs({"strike","guard"}) do
  local specials=0
  for roll=1,100 do
   local b=fresh(case[1],case[2],case[3]);b.enemy.hp=10000*case[4]
   local decisions=0
   G.random=function(a,z)
    if not z then assert(a==100);decisions=decisions+1;return roll end
    assert(a==92 and z==108);return 100
   end
   local ok,trace=G.Action(action);assert(ok and decisions==1,"One decision per live response")
   local hit=trace.hits[#trace.hits];assert(hit.source=="enemy")
   if hit.special then specials=specials+1 end
   assert(b.intent==nil and trace.enemyIntent==nil,"Never retain a future attack")
   assert(hit.blocked==(action=="guard"),"Defense still blocks the actual hit")
   samples=samples+1
  end
  assert(specials==case[5],"Attack probability must not depend on guard or turn number")
 end
end
local b=fresh("wild");local rolls={1,1,100,1,100,100};local decisions=0;local sequence=""
G.random=function(a,z)
 if z then return 100 end
 decisions=decisions+1;return assert(rolls[decisions])
end
for i=1,#rolls do
 local ok,trace=G.Action("strike");assert(ok)
 sequence=sequence..(trace.hits[2].special and "S" or "-")
end
assert(sequence=="SS-S--","Specials may open, repeat, or skip the third turn")
local draws=0;G.random=function() draws=draws+1;return 100 end
b.cooldown=1;b.defenseCooldown=1
assert(not G.Action("special") and not G.Action("guard") and not G.Action("invalid"))
assert(draws==0,"Rejected input cannot reroll the enemy")
b.intent="special" -- Legacy 4.8 saves carried an announced next move.
G.Init(G.db,G.random);assert(G.db.battle and not G.db.battle.intent and draws==0,"Reload discards legacy intent without rolling")
G.db.battle.enemy.hp=1
local ok,trace=G.Action("strike");assert(ok and #trace.hits==1 and draws==1,"KO uses only player damage RNG")
-- A seeded run must show both moves in every turn-position bucket, rather than
-- merely disguising strike/strike/special behind new UI labels.
b=fresh("wild");local seed=17;local buckets={{0,0},{0,0},{0,0}}
G.random=function(a,z)
 if z then return 100 end
 seed=seed*48271%2147483647;return 1+seed%a
end
for i=1,900 do
 b.enemy.hp=10000;G.Active().hp=10000
 local ok,t=G.Action("strike");assert(ok)
 local bucket=buckets[(i-1)%3+1];local index=t.hits[2].special and 1 or 2
 bucket[index]=bucket[index]+1
end
for _,counts in ipairs(buckets) do assert(counts[1]>70 and counts[1]<140 and counts[2]>150,"No fixed third-turn cadence") end
print("Hidden enemy AI: "..samples.." exact probability/guard cases, irregular sequences, rejected-input/reload/KO checks and 900 seeded responses passed.")
