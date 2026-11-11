local F={};for _,name in ipairs({"Data","IdleGame"}) do assert(loadfile("Flightbound/"..name..".lua"))("Flightbound",F) end
local G=F.Idle;local tests=0
local function test(name,fn) fn();tests=tests+1;print("PASS "..name) end
local function near(a,b) assert(math.abs(a-b)<.0001,tostring(a).." ~= "..tostring(b)) end
local function fresh() return G.Init(nil,0) end
local function geared(zone)
 local d=fresh();d.zone=zone or 1;d.blade=10;d.pets.wolf=10;d.pets.boar=10;d.pets.whelp=10;d.party={"wolf","boar","whelp"}
 for i=1,9 do d.cleared[i]=true;d.kills[i]=100;d.claims[i][2]=true end
 G.Spawn(d,false);return d
end
test("onboarding, visible damage, gold and hire gates",function()
 local d=fresh();assert(d.gold==0 and d.settings.sound and #d.party==0)
 assert(G.Objective(d):find("Click"));assert(not G.Buy(d,"pet","wolf"));assert(not G.Buy(d,"pet","whelp"))
 for i=1,11 do G.Click(d,i*.5) end
 assert(d.gold==6 and not d.enemy);G.Advance(d,6,true);assert(d.enemy)
 d.gold=20;assert(G.Buy(d,"pet","wolf"));assert(d.gold==0 and #d.party==1)
 local taps=d.totalTaps
 for i=1,300 do G.Advance(d,6+i*.1,true) end
 assert(d.totalTaps==taps and d.kills[1]>=2 and d.gold>0)
end)
test("six clicks per second cap with no exhausted-click stall",function()
 local d=geared(9);d.blade=0
 for i=1,6 do assert(G.Click(d,0)) end;assert(not G.Click(d,0));assert(G.Click(d,1));assert(d.totalTaps==7)
end)
test("offline cap, exact batching and clock rollback",function()
 local a=geared(4);local b=G.Copy(a)
 G.Advance(a,7200,false);for i=1,7200 do G.Advance(b,i,false) end
 near(a.gold,b.gold);near(a.awayRemainder,b.awayRemainder);assert(a.kills[4]==b.kills[4] and a.chests[4]==b.chests[4])
 local c=geared(4);assert(G.Advance(c,86400,false)==28800);local gold=c.gold
 G.Advance(c,1,false);G.Advance(c,86400,false);near(c.gold,gold)
end)
test("boss armor, ward, burn, fire resistance and swarm counterplay",function()
 local d=geared(1);G.Boss(d,false);local armor=d.enemy.armor;G.Click(d,0);assert(d.enemy.armor<armor)
 G.Damage(d,1,"boar");assert(d.enemy.armor<armor-.1)
 d.zone=2;G.Spawn(d,true);local hp=d.enemy.hp;G.Damage(d,10,"wolf");near(hp-d.enemy.hp,5)
 d.focus=100;G.Power(d,0);assert(not d.enemy or not d.enemy.ward)
 d.zone=6;G.Spawn(d,true);near(G.Damage(d,100,"whelp"),30);near(G.Damage(d,100,"wolf"),100)
 d.zone=8;G.Spawn(d,true);near(G.Damage(d,100,"wisp"),160)
 d.zone=3;G.Spawn(d,true);d.enemy.hp=d.enemy.max/2;d.party={};local hp=d.enemy.hp
 G.Advance(d,.5,true);assert(d.enemy.hp>hp)
 d.enemy.burn=1;d.enemy.burnTime=3;hp=d.enemy.hp;G.Advance(d,1,true);assert(d.enemy.hp<hp)
end)
test("second shell, boss timeout and no lost gold on failure",function()
 local d=geared(4);G.Spawn(d,true);G.Damage(d,d.enemy.max,"power")
 assert(d.enemy and d.enemy.shell and d.enemy.armor==.55)
 d.enemy.time=.1;local gold=d.gold;G.Advance(d,.2,true);assert(not d.enemy.boss);near(d.gold,gold)
end)
test("boss paused away; no automatic first-clear unlock",function()
 local d=geared(2);d.cleared[2]=false;G.Spawn(d,true);local hp=d.enemy.hp;local timer=d.enemy.time
 G.Advance(d,1000,false);near(d.enemy.hp,hp);near(d.enemy.time,timer);assert(not d.cleared[2] and d.gold>0)
end)
test("party and loadout choices have costs and cannot swap mid boss",function()
 local d=geared();local base=G.Stats(d);assert(G.Style(d,"hunter"));assert(G.Stats(d).click>base.click and G.Stats(d).dps<base.dps)
 G.Style(d,"keeper");assert(G.Stats(d).click<base.click and G.Stats(d).dps>base.dps)
 d.pets.murloc=1;assert(not G.Party(d,"murloc"));assert(G.Party(d,"wolf"));assert(G.Party(d,"murloc"));assert(G.Stats(d).gold>base.gold)
 G.Spawn(d,true);assert(not G.Party(d,"boar"));assert(not G.Style(d,"balanced"))
end)
test("contracts and relic awards are one-time; slots enforced",function()
 local d=geared();d.chests[1]=5;G.UnlockRelics(d);assert(d.relics.coin and d.relics.fang)
 assert(G.Equip(d,"fang"));assert(G.Equip(d,"coin"));assert(not G.Equip(d,"banner"))
 assert(G.Claim(d,1,1));local gold=d.gold;assert(not G.Claim(d,1,1));near(d.gold,gold)
 d.elites[1]=true;assert(G.Claim(d,1,3));assert(d.claims[1][3])
end)
test("reload preserves boss health and protects unknown schemas",function()
 local d=geared(4);G.Boss(d,false);d.enemy.hp=d.enemy.max*.4;d.enemy.shell=true;d.enemy.armor=.21;d.enemy.time=12
 local loaded=G.Init(G.Copy(d),0);near(loaded.enemy.hp,d.enemy.hp);near(loaded.enemy.armor,.21);near(loaded.enemy.time,12)
 assert(loaded.enemy.shell)
 local future={schema=9,gold=555};assert(not G.Init(future,100));assert(future.gold==555)
end)
test("corrupt numbers sanitized and no game-world APIs in rules",function()
 local d=G.Init({gold=0/0,blade=math.huge,party={"wolf","wolf","bogus"},pets={wolf=1},settings={scale=-5}},0)
 assert(d.gold==0 and d.blade==0 and #d.party==1 and d.settings.scale==.65)
 local f=assert(io.open("Flightbound/IdleGame.lua"));local s=f:read("*a");f:close()
 for _,token in ipairs({"CastSpell","MoveForward","TargetUnit","SendChatMessage","SendAddonMessage","SetBinding"}) do assert(not s:find(token,1,true)) end
end)
test("regional charter gates travel and trials enforce different plans",function()
 local d=geared(1);d.claims[1]={false,false,false};assert(G.Highest(d)==1 and not G.Travel(d,2))
 assert(G.Claim(d,1,1));assert(G.Travel(d,2));assert(G.Boss(d,true));assert(not G.Click(d,0))
 d.focus=100;assert(G.Power(d,0));G.Spawn(d,false)
 d.zone=4;assert(not G.Boss(d,true));d.party={"wolf"};assert(G.Boss(d,true))
 d.zone=7;G.Spawn(d,true,true);d.focus=100;assert(not G.Power(d,0))
 d.zone=9;G.Spawn(d,false);assert(not G.Boss(d,true));d.party={"wolf","boar","whelp"};assert(G.Boss(d,true))
end)
test("every authored elite trial is completable with a legal crew",function()
 for zone=1,9 do
  local d=geared(zone);d.blade=65;d.focus=100;d.style="keeper"
  for _,id in ipairs(F.petOrder) do d.pets[id]=45 end
  for _,r in ipairs(F.relics) do d.relics[r.id]=true end
  d.equipped={"banner","lens"};d.party={"wolf","boar","wisp"}
  local trial=F.trials[zone]
  if trial.require then d.party[2]=trial.require end
  if trial.maxParty then d.party={"wolf"};d.style="hunter" end
  if trial.forbid then d.party={"wolf","boar","wisp"} end
  assert(G.Boss(d,true),"Trial cannot start: "..zone)
  for tick=1,200 do
   local now=tick*.2;G.Advance(d,now,true)
   if tick%2==0 and not trial.noClicks then G.Click(d,now) end
   if d.focus>=65 and not trial.noPower then G.Power(d,now) end
   if d.elites[zone] then break end
  end
  assert(d.elites[zone],"Impossible trial: "..zone)
 end
end)
print(tests.." rule groups passed")
