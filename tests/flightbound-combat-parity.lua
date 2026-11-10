-- Damage formulas remain compatible with 4.8.2. Entire battles intentionally
-- differ in 4.9: enemy choices draw new RNG, XP and progression were rebalanced.
-- Usage: luajit tests/flightbound-combat-parity.lua <previousAddonDir>
local baseline=assert(arg[1],"Pass the previous addon directory")
local function load(path)
 local F={}
 for _,name in ipairs({"Data","Game","Adventure","Campaign","Trainer","DungeonMap"}) do
  assert(loadfile(path.."/"..name..".lua"))("Flightbound",F)
 end
 F.Game.Init(nil);F.Game.db.totalWins=10;F.Game.db.zone=2
 return F
end
local old,new=load(baseline),load("Flightbound");local cases=0
for _,id in ipairs(new.order) do for _,target in ipairs(new.order) do
 for _,level in ipairs({3,8,16}) do for _,enemy in ipairs({false,true}) do
  for _,special in ipairs({false,true}) do for _,modifier in ipairs({1,.35}) do
   for _,roll in ipairs({92,100,106}) do
    local results={}
    for i,F in ipairs({old,new}) do
     local G=F.Game;local a,b=G.NewPet(id,level),G.NewPet(target,level+2)
     a.enemy=enemy;b.hp=10000
     local draws=0
     G.random=function(lo,hi) assert(lo==92 and hi==108);draws=draws+1;return roll end
     local amount,mult,critical=G.Damage(a,b,special,modifier)
     assert(draws==1 and not critical and b.hp==10000-amount)
     results[i]={amount,mult}
    end
    assert(results[1][1]==results[2][1] and results[1][2]==results[2][2],id.." vs "..target.." formula changed")
    cases=cases+1
   end
  end end
 end end
end end
print("Noncritical damage parity: "..cases.." cases match the previous release across species, tiers, both sides, specials and guards.")
