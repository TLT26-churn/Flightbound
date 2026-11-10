-- Verify ordinary (noncritical) combat still matches the previous release.
local baseline=assert(arg[1],"Pass the previous addon directory")
local function load(path)
 local F={}
 for _,name in ipairs({"Data","Game","Adventure","Campaign","Trainer","DungeonMap"}) do
  assert(loadfile(path.."/"..name..".lua"))("Flightbound",F)
 end
 return F
end
local old,new=load(baseline),load("Flightbound")
local function same(a,b,path)
 assert(type(a)==type(b),path..": type changed")
 if type(a)~="table" then assert(a==b,path..": value changed");return end
 for k,v in pairs(a) do same(v,b[k],path.."."..k) end
 for k in pairs(b) do assert(a[k]~=nil,path..": added "..k) end
end
local steps=0
for _,id in ipairs(new.order) do for _,level in ipairs({3,8,16}) do for seed=1,2 do
 local counts={0,0}
 for i,F in ipairs({old,new}) do
  local state=seed
  local function rng(a,b)
   counts[i]=counts[i]+1;state=(state*48271)%2147483647
   if not b then b=a;a=1 end
   local roll=a+state%(b-a+1)
   -- Critical hits intentionally add damage in 4.7; isolate unchanged ordinary rolls.
   if a==92 and b==108 then roll=math.min(roll,106) end
   return roll
  end
  local G=F.Game;G.Init(nil,rng);G.SetTrainer({name="Tester",race="human",class="WARRIOR",gender=2});G.Start(id)
  G.Active().level=level;G.Active().hp=G.MaxHP(G.Active());G.db.totalWins=10
  G.db.pets[2]=G.NewPet(id=="wolf" and "murloc" or "wolf",level)
  assert(G.Encounter(false,{id="boar",level=level+2,kind="wild"}))
  G.db.battle.enemy.hp=350;G.db.battle.enemy.maxHP=350;G.db.battle.intent="special"
 end
 for _,action in ipairs({"special","special","guard","guard","focus","strike","salve","swap","special","strike","focus","special","guard","strike","salve","strike","strike","special","strike","flee"}) do
  local a=old.Game.Action(action,2);local b=new.Game.Action(action,2)
  assert(a==b,"Acceptance changed: "..action);same(old.Game.db,new.Game.db,id.."/"..level.."/"..action)
  assert(counts[1]==counts[2],"Presentation changed the RNG stream");steps=steps+1
 end
end end end
print("Noncritical combat parity: "..steps.." actions match the previous release's save state and RNG use.")
