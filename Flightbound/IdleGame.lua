-- Deterministic minigame rules. Never acts on the player's WoW character.
local _,F=...
local G={};F.Idle=G
local function finite(x) return type(x)=="number" and x==x and x~=math.huge and x~=-math.huge end
local function n(x,default,lo,hi) if not finite(x) then return default end return math.max(lo,math.min(hi,x)) end
function G.Copy(t) if type(t)~="table" then return t end local r={};for k,v in pairs(t) do r[k]=G.Copy(v) end return r end
local function tab(t) return type(t)=="table" and t or {} end
local function event(d,kind,data) if G.emit then G.emit(kind,data or {}) end end
function G.HasPet(d,id) for _,p in ipairs(d.party) do if p==id then return true end end return false end
function G.Relic(d,id) for _,r in ipairs(d.equipped) do if r==id then return true end end return false end
function G.Charter(d,zone) for j=1,3 do if d.claims[zone][j] then return true end end return false end
function G.ContractCount(d) local count=0;for i=1,9 do for j=1,3 do if d.claims[i][j] then count=count+1 end end end;return count end
function G.Highest(d) local high=1;for i=1,#F.zones-1 do if d.cleared[i] and G.Charter(d,i) and (i<8 or G.ContractCount(d)>=18) then high=i+1 else break end end return high end
function G.Stats(d)
 local click=2+2.5*d.blade*1.11^d.blade
 local crew,gold=1,1
 if d.style=="hunter" then click,crew=click*1.6,.8
 elseif d.style=="keeper" then click,crew=click*.7,1.4
 elseif d.style=="scavenger" then click,crew,gold=click*.8,.8,1.4 end
 if G.Relic(d,"fang") then click=click*1.35 end
 if G.Relic(d,"banner") then crew=crew*1.25 end
 if G.Relic(d,"coin") then gold=gold*1.3 end
 if G.HasPet(d,"murloc") then gold=gold*1.3 end
 local damage={};local dps=0
 for _,id in ipairs(d.party) do
  local p=F.pets[id];local level=d.pets[id]
  damage[id]=p.base*level*1.115^(level-1)*crew
  local effective=damage[id]*(id=="whelp" and (G.Relic(d,"ember") and 2.2 or 1.6) or 1)
  dps=dps+effective/p.interval
 end
 return {click=click,dps=dps,damage=damage,gold=gold}
end
function G.ZoneHP(zone) return 22*3.15^(zone-1) end
function G.ZoneGold(zone) return ({6,16,44,125,360,1100,3500,12000,42000})[zone] end
function G.BladeCost(d) return math.ceil(12*1.35^d.blade) end
function G.PetCost(d,id) return math.ceil(F.pets[id].cost*1.28^d.pets[id]) end
function G.Form(d,id) local level=d.pets[id] or 0;return level>=25 and 3 or level>=10 and 2 or 1 end
function G.PetArt(d,id) local form=G.Form(d,id);return id..(form>1 and "_"..form or "") end
function G.Spawn(d,boss,elite)
 local z=F.zones[d.zone];local count=d.kills[d.zone]
 local chest=not boss and count>0 and count%11==5
 local id=chest and "chest" or boss and z.boss or z.wild[count%#z.wild+1]
 local max=G.ZoneHP(d.zone)*(boss and (elite and 18 or 9) or chest and .35 or 1)
 d.enemy={id=id,name=chest and "Lost Supply Chest" or boss and z.title or F.enemyNames[id],hp=max,max=max,boss=boss==true,elite=elite==true,
  armor=boss and (z.mechanic=="armor" or z.mechanic=="shell") and .55 or 0,ward=boss and z.mechanic=="ward" or false,
  time=boss and (z.mechanic=="rush" and 25 or 40) or 0,shell=false,burn=0,burnTime=0,mark=0,chest=chest}
 d.spawnWait=0;event(d,"spawn",{id=id,boss=boss,chest=chest});return d.enemy
end
function G.Init(raw,now)
 now=n(now,0,0,1e12)
 if type(raw)=="table" and raw.schema and raw.schema~=1 then return nil,"Unknown future idle save; left untouched." end
 local d=tab(raw);d.schema=1;d.resetToken=F.freshStart
 d.gold=n(d.gold,0,0,1e15);d.blade=math.floor(n(d.blade,0,0,65));d.focus=n(d.focus,0,0,100)
 d.pets=tab(d.pets);for _,id in ipairs(F.petOrder) do d.pets[id]=math.floor(n(d.pets[id],0,0,45)) end
 d.cleared=tab(d.cleared);d.kills=tab(d.kills);d.chests=tab(d.chests);d.elites=tab(d.elites);d.claims=tab(d.claims)
 for i in ipairs(F.zones) do
  d.cleared[i]=d.cleared[i]==true;d.elites[i]=d.elites[i]==true
  d.kills[i]=math.floor(n(d.kills[i],0,0,1e9));d.chests[i]=math.floor(n(d.chests[i],0,0,1e8));d.claims[i]=tab(d.claims[i])
  for j=1,3 do d.claims[i][j]=d.claims[i][j]==true end
 end
 d.zone=math.floor(n(d.zone,1,1,G.Highest(d)));d.style=F.styles[d.style] and d.style or "balanced"
 if not d.cleared[1] then d.style="balanced" end
 local party,seen={},{}
 for _,id in ipairs(tab(d.party)) do if F.pets[id] and d.pets[id]>0 and not seen[id] and #party<3 then party[#party+1]=id;seen[id]=true end end;d.party=party
 d.relics=tab(d.relics);local valid={};for _,r in ipairs(F.relics) do valid[r.id]=true;d.relics[r.id]=d.relics[r.id]==true end
 local equipped,owned={},{};for _,id in ipairs(tab(d.equipped)) do if valid[id] and d.relics[id] and not owned[id] and #equipped<(d.cleared[3] and 2 or 1) then equipped[#equipped+1]=id;owned[id]=true end end;d.equipped=equipped
 d.totalTaps=math.floor(n(d.totalTaps,0,0,1e12));d.seconds=n(d.seconds,0,0,1e12);d.awayRemainder=n(d.awayRemainder,0,0,1)
 d.last=n(d.last,now,0,1e12);d.lastTap=-1;d.tapCount=0;d.timers={};d.spawnWait=0
 d.settings=tab(d.settings);d.settings.sound=d.settings.sound~=false;d.settings.auto=d.settings.auto==true;d.settings.scale=n(d.settings.scale,.9,.65,1.3)
 local pos=tab(d.settings.position);d.settings.position=finite(pos.x) and finite(pos.y) and {x=n(pos.x,0,-10000,10000),y=n(pos.y,0,-10000,10000)} or nil
 local enemy=d.enemy;d.enemy=nil
 -- Reloads preserve in-progress boss health/timer, but validate every transient value.
 if type(enemy)=="table" and enemy.boss==true and d.kills[d.zone]>=F.zones[d.zone].need then
  G.Spawn(d,true,enemy.elite==true and d.cleared[d.zone])
  d.enemy.hp=n(enemy.hp,d.enemy.max,1,d.enemy.max);d.enemy.time=n(enemy.time,d.enemy.time,.1,40)
  d.enemy.armor=n(enemy.armor,d.enemy.armor,0,.55);d.enemy.shell=enemy.shell==true;d.enemy.ward=enemy.ward==true
 else G.Spawn(d,false) end
 G.Advance(d,now,false);return d
end
function G.UnlockRelics(d)
 local totalChests,contracts=0,0;for i in ipairs(F.zones) do totalChests=totalChests+d.chests[i];for j=1,3 do if d.claims[i][j] then contracts=contracts+1 end end end
 local unlock={fang=d.cleared[1],banner=d.cleared[2],coin=totalChests>=5,lens=d.cleared[4],ember=d.cleared[6],hourglass=contracts>=6}
 for _,r in ipairs(F.relics) do if unlock[r.id] and not d.relics[r.id] then d.relics[r.id]=true;event(d,"relic",{name=r.name}) end end
end
function G.Defeat(d)
 local e=d.enemy;if not e then return end
 local reward=math.floor(G.ZoneGold(d.zone)*G.Stats(d).gold*(e.boss and (e.elite and 30 or 15) or e.chest and 6 or 1))
 d.gold=math.min(1e15,d.gold+reward)
 if e.boss then
  if e.elite then d.elites[d.zone]=true else d.cleared[d.zone]=true end
  event(d,"bosswin",{gold=reward,elite=e.elite,zone=d.zone})
 else
  d.kills[d.zone]=d.kills[d.zone]+1
  if e.chest then d.chests[d.zone]=d.chests[d.zone]+1 end
  event(d,"loot",{gold=reward,chest=e.chest,id=e.id})
 end
 G.UnlockRelics(d);d.enemy=nil;d.spawnWait=.45
end
function G.Damage(d,amount,source)
 local e=d.enemy;if not e then return 0 end
 local z=F.zones[d.zone]
 if source=="click" then if e.mark>0 then amount=amount*1.25 end;e.armor=math.max(0,e.armor-.07) end
 if source=="boar" then e.armor=math.max(0,e.armor-.12) end
 if source=="power" then e.armor=math.max(0,e.armor-.35);e.ward=false end
 if e.boss then
  if z.mechanic=="fire" and (source=="whelp" or source=="burn") then amount=amount*.3 end
  if z.mechanic=="swarm" and (source=="whelp" or source=="wisp" or source=="burn") then amount=amount*1.6 end
  if e.ward and source~="click" and source~="power" then amount=amount*.5 end
 end
 amount=amount*(1-e.armor);e.hp=math.max(0,e.hp-amount)
 event(d,"hit",{amount=amount,source=source})
 if e.boss and z.mechanic=="shell" and not e.shell and e.hp>0 and e.hp<=e.max*.5 then e.shell=true;e.armor=.55;event(d,"shield",{}) end
 if e.hp<=0 then G.Defeat(d) end
 return amount
end
function G.Idle(d,dt)
 local stats=G.Stats(d);if stats.dps<=0 then return end
 local multiplier=G.HasPet(d,"treant") and 1.35 or 1
 if G.Relic(d,"hourglass") then multiplier=multiplier*1.4 end
 local kills=dt*stats.dps/(G.ZoneHP(d.zone)+stats.dps*.45)*multiplier
 local total=d.awayRemainder+kills;local whole=math.floor(total);d.awayRemainder=total-whole
 local gold=kills*G.ZoneGold(d.zone)*stats.gold
 d.gold=math.min(1e15,d.gold+gold);d.kills[d.zone]=math.min(1e9,d.kills[d.zone]+whole)
 -- Away treasure is periodic and capped by earned kills, never random reload rolls.
 local chestBefore=math.floor((d.kills[d.zone]-whole)/22);local chestAfter=math.floor(d.kills[d.zone]/22)
 local chests=chestAfter-chestBefore;d.chests[d.zone]=d.chests[d.zone]+chests
 local bonus=chests*G.ZoneGold(d.zone)*stats.gold*3;d.gold=math.min(1e15,d.gold+bonus)
 d.away=tab(d.away);d.away.gold=(d.away.gold or 0)+gold+bonus;d.away.seconds=(d.away.seconds or 0)+dt;d.away.kills=(d.away.kills or 0)+whole
 G.UnlockRelics(d)
end
function G.Advance(d,now,visible)
 if not finite(now) or now<=d.last then return 0 end
 local dt=math.min(8*3600,now-d.last);d.last=now;d.seconds=d.seconds+dt
 d.focus=math.min(100,d.focus+dt*2.5)
 if not visible or dt>3 then G.Idle(d,dt);return dt end
 if not d.enemy then d.spawnWait=d.spawnWait-dt;if d.spawnWait<=0 then G.Spawn(d,false) end;return dt end
 local e=d.enemy;local z=F.zones[d.zone]
 e.mark=math.max(0,e.mark-dt)
 if e.boss then
  e.time=e.time-dt
  if e.time<=0 then event(d,"bossfail",{});G.Spawn(d,false);return dt end
  if z.mechanic=="regen" and e.burnTime<=0 then e.hp=math.min(e.max,e.hp+e.max*.006*dt) end
 end
 if e.burnTime>0 then local elapsed=math.min(dt,e.burnTime);e.burnTime=math.max(0,e.burnTime-dt);G.Damage(d,e.burn*elapsed,"burn") end
 local stats=G.Stats(d)
 for _,id in ipairs(d.party) do
  if not d.enemy then break end
  local p=F.pets[id];local interval=p.interval*(d.enemy.boss and z.mechanic=="frost" and 1.6 or 1)
  d.timers[id]=(d.timers[id] or 0)+dt
  if d.timers[id]>=interval then
   d.timers[id]=d.timers[id]-interval
   if id=="wolf" then d.enemy.mark=3 end
   if id=="wisp" then d.focus=math.min(100,d.focus+3) end
   if id=="whelp" then d.enemy.burn=stats.damage[id]*(G.Relic(d,"ember") and 1.2 or .6)/p.interval;d.enemy.burnTime=3 end
   event(d,"attack",{id=id});G.Damage(d,stats.damage[id],id)
  end
 end
 return dt
end
function G.CanClick(d) return d.enemy and not (d.enemy.elite and F.trials[d.zone].noClicks) end
function G.Click(d,now)
 G.Advance(d,now,true)
 if not d.enemy then return false end
 if not G.CanClick(d) then return false,"This trial uses crew attacks and Power Strike only." end
 local second=math.floor(now);if d.lastTap~=second then d.lastTap=second;d.tapCount=0 end
 if d.tapCount>=6 or not d.enemy then return false end
 d.tapCount=d.tapCount+1;d.totalTaps=d.totalTaps+1;d.focus=math.min(100,d.focus+3)
 G.Damage(d,G.Stats(d).click,"click");return true
end
function G.Power(d,now)
 G.Advance(d,now,true)
 if d.enemy and d.enemy.elite and F.trials[d.zone].noPower then return false,"This trial disables Power Strike." end
 local cost=G.Relic(d,"lens") and 65 or 100
 if not d.enemy or d.focus<cost then return false,"Power Strike needs "..cost.." Focus." end
 d.focus=d.focus-cost;G.Damage(d,G.Stats(d).click*12+G.Stats(d).dps*2,"power");return true
end
function G.Buy(d,kind,id)
 local cost
 if kind=="blade" then if d.blade>=65 then return false,"Blade fully upgraded." end;cost=G.BladeCost(d)
 else
  local p=F.pets[id];if not p or d.pets[id]>=45 or p.unlock>0 and not d.cleared[p.unlock] then return false,"Defeat the guardian to recruit this companion." end
  cost=G.PetCost(d,id)
 end
 if d.gold+1e-7<cost then return false,"Need "..cost.." gold." end
 d.gold=math.max(0,d.gold-cost)
 if kind=="blade" then d.blade=d.blade+1
 else d.pets[id]=d.pets[id]+1;if not G.HasPet(d,id) and #d.party<3 then d.party[#d.party+1]=id end end
 event(d,"upgrade",{id=id or "blade"});return true
end
function G.Party(d,id)
 if not F.pets[id] or d.pets[id]<=0 then return false,"Recruit this companion first." end
 if d.enemy and d.enemy.boss then return false,"Change your crew between boss attempts." end
 for i,p in ipairs(d.party) do if p==id then table.remove(d.party,i);return true end end
 if #d.party>=3 then return false,"Rest one companion to make room (three active)." end
 d.party[#d.party+1]=id;d.timers[id]=0;return true
end
function G.Style(d,id)
 if not d.cleared[1] or not F.styles[id] then return false end
 if d.enemy and d.enemy.boss then return false,"Choose your style before a boss attempt." end
 d.style=id;return true
end
function G.Equip(d,id)
 if not d.relics[id] then return false,"Discover this relic first." end
 if d.enemy and d.enemy.boss then return false,"Equip relics between boss attempts." end
 for i,r in ipairs(d.equipped) do if r==id then table.remove(d.equipped,i);return true end end
 if #d.equipped>=(d.cleared[3] and 2 or 1) then return false,"Unequip a relic to make room." end
 d.equipped[#d.equipped+1]=id;return true
end
function G.Travel(d,zone)
 if zone==9 and G.ContractCount(d)<18 then return false,"The Sky Citadel needs 18 regional contracts. Choose patrols, treasure and crew trials." end
 if not F.zones[zone] or zone>G.Highest(d) then return false,"Defeat the previous guardian and complete one of its contracts." end
 d.zone=zone;G.Spawn(d,false);return true
end
function G.Boss(d,elite)
 if d.kills[d.zone]<F.zones[d.zone].need then return false,"Hunt more creatures to reveal the guardian." end
 if elite then
  if not d.cleared[d.zone] then return false end
  local trial=F.trials[d.zone]
  if trial.require and not G.HasPet(d,trial.require) or trial.forbid and G.HasPet(d,trial.forbid) or trial.maxParty and #d.party~=trial.maxParty then return false,trial.hint end
  if trial.evolved then local count=0;for _,id in ipairs(d.party) do if G.Form(d,id)>1 then count=count+1 end end;if count<trial.evolved then return false,trial.hint end end
 end
 G.Spawn(d,true,elite);return true
end
function G.Contract(d,zone,index)
 local value,need,description
 if index==1 then value,need,description=d.kills[zone],60+zone*20,"Trail patrol"
 elseif index==2 then value,need,description=d.chests[zone],5,"Treasure seeker"
 else value,need,description=d.elites[zone] and 1 or 0,1,F.trials[zone].name end
 return value,need,description
end
function G.Claim(d,zone,index)
 if not F.zones[zone] or index<1 or index>3 then return false end
 local value,need=G.Contract(d,zone,index)
 if value<need or d.claims[zone][index] then return false end
 d.claims[zone][index]=true;local reward=math.floor(G.ZoneGold(zone)*100)
 d.gold=math.min(1e15,d.gold+reward);G.UnlockRelics(d);event(d,"contract",{gold=reward});return true
end
function G.Objective(d)
 if d.totalTaps<1 then return "Click the creature to attack!","Each hit deals damage. Defeated creatures drop gold automatically." end
 if d.pets.wolf==0 then return "Recruit your first companion: Timber Wolf (20 gold)","Click creatures, collect gold, then press Recruit Wolf below." end
 if d.blade==0 then return "Sharpen your blade (12 gold)","Your wolf attacks by itself. Upgrade your clicks to help it." end
 local z=F.zones[d.zone]
 if d.enemy and d.enemy.boss then return (d.enemy.elite and F.trials[d.zone].name or "Guardian: "..z.title),d.enemy.elite and F.trials[d.zone].hint or z.hint end
 if not d.cleared[d.zone] then
  if d.kills[d.zone]>=z.need then return "Guardian ready! Challenge "..z.title,z.hint end
  return "Hunt "..z.need.." creatures: "..math.min(d.kills[d.zone],z.need).." / "..z.need,"Upgrade your blade and companions. Power Strike spends Focus for a huge hit."
 end
 if d.cleared[8] and G.ContractCount(d)<18 then return "Final skyway: "..G.ContractCount(d).." / 18 contracts","Return to earlier regions for patrols, treasure and crew trials. Each completed contract counts." end
 if d.zone<#F.zones and not G.Charter(d,d.zone) then return "Choose a contract to open the next skyway","World & contracts: patrol creatures, find treasure, or beat an elite with special crew rules." end
 if d.zone<#F.zones then return "Skyway restored! Travel to "..F.zones[d.zone+1].name,"Or stay for contracts, treasure and an elite guardian. Your next companion is unlocked." end
 local done=0;for i in ipairs(F.zones) do for j=1,3 do if d.claims[i][j] then done=done+1 end end end
 return "All skyways restored! Regional contracts: "..done.." / 27","Collect relics, evolve your crew, and defeat elite guardians across Azeroth."
end
