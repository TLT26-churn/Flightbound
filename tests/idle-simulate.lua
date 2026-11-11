local F={};for _,name in ipairs({"Data","IdleGame"}) do assert(loadfile("Flightbound/"..name..".lua"))("Flightbound",F) end
local G=F.Idle
local function loadout(d,clickRate)
 if d.enemy and d.enemy.boss then return end
 if d.cleared[1] then G.Style(d,clickRate>0 and "hunter" or "keeper") end
 local options={};for _,id in ipairs(F.petOrder) do if d.pets[id]>0 then options[#options+1]=id end end
 table.sort(options,function(a,b) return F.pets[a].base*d.pets[a]*1.115^(d.pets[a]-1)/F.pets[a].interval>F.pets[b].base*d.pets[b]*1.115^(d.pets[b]-1)/F.pets[b].interval end)
 d.party={};for i=1,math.min(3,#options) do d.party[i]=options[i] end
 if (d.zone==1 or d.zone==4 or d.zone==9) and d.pets.boar>0 and not G.HasPet(d,"boar") then d.party[#d.party]= "boar" end
 if d.zone==3 and d.pets.whelp>0 and not G.HasPet(d,"whelp") then d.party[#d.party]="whelp" end
 if d.zone==6 and G.HasPet(d,"whelp") then for i,id in ipairs(d.party) do if id=="whelp" then d.party[i]=d.pets.wisp>0 and "wisp" or "murloc" end end end
 d.equipped={};for _,id in ipairs(clickRate>0 and {"fang","lens","banner"} or {"banner","hourglass","coin"}) do if d.relics[id] and #d.equipped<(d.cleared[3] and 2 or 1) then d.equipped[#d.equipped+1]=id end end
end
local function policy(d,rate)
 for z=1,9 do for j=1,3 do G.Claim(d,z,j) end end
 for _,id in ipairs(F.petOrder) do local p=F.pets[id];if d.pets[id]==0 and (p.unlock==0 or d.cleared[p.unlock]) and d.gold>=G.PetCost(d,id) then G.Buy(d,"pet",id) end end
 loadout(d,rate)
 for attempt=1,20 do
  local best,score=nil,0
  if rate>0 and d.blade<65 and d.gold>=G.BladeCost(d) then
   local base=G.Stats(d).click;d.blade=d.blade+1;local delta=G.Stats(d).click-base;d.blade=d.blade-1
   best="blade";score=delta*rate/G.BladeCost(d)
  end
  for _,id in ipairs(d.party) do if d.pets[id]<45 and d.gold>=G.PetCost(d,id) then
   local base=G.Stats(d).dps;d.pets[id]=d.pets[id]+1;local delta=G.Stats(d).dps-base;d.pets[id]=d.pets[id]-1
   local value=delta/G.PetCost(d,id);if value>score then score=value;best=id end
  end end
  if not best then break end
  if best=="blade" then G.Buy(d,"blade") else G.Buy(d,"pet",best) end
 end
 loadout(d,rate)
end
local function chooseContract(d)
 -- Once the eight regional guardians are cleared, finish patrol/treasure goals
 -- and two distinct crew trials to earn entry to the final region.
 if not d.cleared[8] or G.ContractCount(d)>=18 then return false end
 if d.enemy and d.enemy.boss then return true end
 for zone=1,8 do
  if not d.claims[zone][1] or not d.claims[zone][2] then
   if d.zone~=zone then G.Travel(d,zone) end
   return true
  end
 end
 for _,zone in ipairs({1,3}) do if not d.claims[zone][3] then
  if d.zone~=zone then G.Travel(d,zone) end
  local need=F.trials[zone].require
  if not G.HasPet(d,need) then d.party[#d.party]=need end
  if d.enemy and not d.enemy.boss then G.Boss(d,true) end
  return true
 end end
 return false
end
for _,mode in ipairs({{name="Active 2 taps/sec",rate=2},{name="Saturated 6 taps/sec",rate=6},{name="Idle crew + boss check-ins",rate=0}}) do
 local d=G.Init(nil,0);local clearAt={};local step=.25;local tapBudget=0;local failed=0
 G.emit=function(kind) if kind=="bossfail" then failed=failed+1 end end
 for tick=1,24*3600/step do
  local t=tick*step;local rate=(t<60 and math.max(2,mode.rate) or mode.rate)
  G.Advance(d,t,true);tapBudget=tapBudget+rate*step
  while tapBudget>=1 do G.Click(d,t);tapBudget=tapBudget-1 end
  if d.focus>=(G.Relic(d,"lens") and 65 or 100) then G.Power(d,t) end
  if tick%20==0 then
   policy(d,rate)
   local doingContracts=chooseContract(d)
   if d.cleared[d.zone] then clearAt[d.zone]=clearAt[d.zone] or t;if not doingContracts and d.zone<9 and G.Charter(d,d.zone) then
    if d.cleared[8] and G.Highest(d)==9 then G.Travel(d,9) else G.Travel(d,d.zone+1) end
   end end
   local stats=G.Stats(d);local damage=stats.dps/(d.zone==7 and 1.6 or 1)+stats.click*rate
   if d.zone==1 or d.zone==4 or d.zone==9 then damage=damage*.85 end
   if not d.cleared[d.zone] and not (d.enemy and d.enemy.boss) and d.kills[d.zone]>=F.zones[d.zone].need and damage>G.ZoneHP(d.zone)*9/(d.zone==5 and 20 or 32) then G.Boss(d,false) end
  end
  assert(d.gold==d.gold and d.gold>=0 and d.gold<1e15)
  if d.cleared[9] then clearAt[9]=clearAt[9] or t;break end
 end
 assert(d.cleared[9],mode.name.." stalled at zone "..d.zone)
 assert(clearAt[9]>900,"All skyways collapsed below 15 minutes")
 print(mode.name.." (boss failures "..failed..", taps "..d.totalTaps..")")
 for i,z in ipairs(F.zones) do print(string.format("  %-19s %6.2fh",z.name,clearAt[i]/3600)) end
 print("  blade="..d.blade..", contracts="..tostring(d.relics.hourglass)..", gold="..math.floor(d.gold))
end
