local F={}
for _,name in ipairs({"Data","Game","Adventure","Campaign","Trainer","DungeonMap"}) do
 assert(loadfile("Flightbound/"..name..".lua"))("Flightbound",F)
end
local G=F.Game
local function low(a,b) return b and a or 1 end
G.Init(nil,low);G.SetTrainer({name="Tester",race="human",class="WARRIOR",gender=2});G.Start("wolf")
G.db.totalWins=10;G.db.zone=4;G.Active().level=16;G.Active().hp=G.MaxHP(G.Active())
assert(G.Encounter(false,{id="boar",level=18,kind="wild"}))
local crits,draws=0,0
for _,enemy in ipairs({false,true}) do for _,special in ipairs({false,true}) do for _,guard in ipairs({1,.35}) do
 for roll=92,108 do
  local a,b=enemy and G.db.battle.enemy or G.Active(),enemy and G.Active() or G.db.battle.enemy
  b.hp=10000
  G.random=function(lo,hi) assert(lo==92 and hi==108);draws=draws+1;return roll end
  local sa,sb=G.Spec(a),G.Spec(b);local mult=special and G.Multiplier(sa.kind,sb.kind) or 1
  local raw=math.max(2,math.floor(((sa.attack+a.level*1.5)*(special and (1.45+(G.Tier(a)-1)*.10) or 1)*mult*roll/100
   -(sb.defense+b.level*.3)*.45)*(a.enemy and G.Difficulty().attack or 1.08)*guard))
  local damage,typ,critical=G.Damage(a,b,special,guard)
  assert(critical==(roll>=107));assert(damage==(critical and math.floor(raw*1.5) or raw))
  assert(b.hp==10000-damage and typ==mult)
  if critical then crits=crits+1 end
 end
end end end
assert(draws==136 and crits==16,"Both sides and all direct attacks use exactly two crit rolls out of 17")
print("Critical rules: 136 damage cases, exact 1.5x bonus, symmetric odds, guard reduction and one RNG draw per hit passed.")
