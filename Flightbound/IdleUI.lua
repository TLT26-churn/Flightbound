local _,F=...
local G,A=F.Idle,F.IdleAudio
local U={tab="upgrades",pool={text={},tex={},button={}},used={},petPage=1,worldPage=1,attacks={},floats={},coins={},fx={}};F.IdleUI=U
local gold={1,.82,.30,1};local white={.96,.92,.81,1};local dim={.67,.68,.64,1};local green={.43,.90,.62,1};local blue={.43,.72,1,1}
local dark={.045,.045,.052,1};local edge={.41,.33,.20,1}
local function place(o,parent,x,y,w,h) o:ClearAllPoints();o:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y);o:SetSize(w,h) end
local function texture(parent,x,y,w,h,color,layer,sub)
 local t=parent:CreateTexture(nil,layer or "ARTWORK",nil,sub or 0);place(t,parent,x,y,w,h)
 if color then t:SetColorTexture(unpack(color)) end;return t
end
local function label(parent,x,y,w,h,value,size,color,align)
 local t=parent:CreateFontString(nil,"OVERLAY");place(t,parent,x,y,w,h);t:SetFont("Fonts\\FRIZQT__.TTF",size or 12,"")
 t:SetJustifyH(align or "LEFT");t:SetJustifyV("TOP");t:SetTextColor(unpack(color or white));t:SetText(value);return t
end
local function art(t,file,flip) t:SetTexture(F.path.."Art\\"..file..".tga");t:SetTexCoord(flip and 1 or 0,flip and 0 or 1,0,1) end
function U.Number(value)
 if value>=1e9 then return string.format("%.1fB",value/1e9) elseif value>=1e6 then return string.format("%.1fM",value/1e6) elseif value>=10000 then return string.format("%.1fk",value/1000) end
 return tostring(math.floor(value+.00001))
end
local function get(kind)
 U.used[kind]=(U.used[kind] or 0)+1;local index=U.used[kind];local o=U.pool[kind][index]
 if not o then
  if kind=="text" then o=label(U.frame,0,0,1,1,"",12)
  elseif kind=="tex" then o=texture(U.frame,0,0,1,1)
  else
   o=CreateFrame("Button",nil,U.frame)
   o.border=texture(o,0,0,1,1,edge,"BACKGROUND")
   o.fill=texture(o,1,1,1,1,nil,"BORDER")
   o.shine=texture(o,2,2,1,1,{.55,.44,.19,.18},"BORDER",1)
   o.label=label(o,0,0,1,1,"",12,gold,"CENTER")
   o:SetScript("OnClick",function(self) if self.action then self.action() end end)
   o:SetScript("OnEnter",function(self) if self:IsEnabled() then self.fill:SetColorTexture(.30,.22,.10,1) end end)
   o:SetScript("OnLeave",function() U.Render() end)
  end
  U.pool[kind][index]=o
 end
 o:Show();return o
end
local function text(x,y,w,h,value,size,color,align)
 local o=get("text");place(o,U.frame,x,y,w,h);o:SetFont("Fonts\\FRIZQT__.TTF",size or 12,"");o:SetJustifyH(align or "LEFT");o:SetTextColor(unpack(color or white));o:SetText(value);return o
end
local function rect(x,y,w,h,color,sub)
 local o=get("tex");place(o,U.frame,x,y,w,h);o:SetColorTexture(unpack(color));o:SetDrawLayer("BACKGROUND",sub or 0);o:SetAlpha(1);return o
end
local function image(x,y,w,h,file,coords)
 local o=get("tex");place(o,U.frame,x,y,w,h);art(o,file);o:SetDrawLayer("ARTWORK",0);o:SetAlpha(1)
 if coords then o:SetTexCoord(unpack(coords)) end;return o
end
local function button(x,y,w,h,value,fn,enabled,accent)
 local b=get("button");place(b,U.frame,x,y,w,h);place(b.border,b,0,0,w,h);place(b.fill,b,1,1,w-2,h-2);place(b.shine,b,2,2,w-4,2)
 b.fill:SetColorTexture(unpack(accent and {.08,.23,.15,1} or {.20,.055,.035,1}))
 place(b.label,b,6,math.floor((h-14)/2),w-12,18);b.label:SetText(value);b.label:SetTextColor(unpack(enabled==false and dim or accent and green or gold))
 b:SetEnabled(enabled~=false);b.action=fn;return b
end
function U.Action(fn,sound)
 G.Advance(G.db,F.Now(),U.tab=="upgrades")
 local ok,message=fn();if message then U.message=message end
 if ok and sound then A.Play(sound) end;U.Render();return ok
end
local function pop(value,color)
 if not U.scene then return end
 U.floatIndex=(U.floatIndex or 0)%#U.floats+1;local p=U.floats[U.floatIndex]
 p.at=GetTime();p.text:SetText(value);p.text:SetTextColor(unpack(color or gold));p.offset=(U.floatIndex%3-1)*22;p.text:Show()
end
function U.Event(kind,data)
 if not U.frame or not U.frame:IsShown() then return end
 local t=GetTime()
 if U.tab~="upgrades" and (kind=="attack" or kind=="hit" or kind=="loot" or kind=="spawn") then return end
 if kind=="attack" then
  U.attacks[data.id]=t
  U.fxIndex=(U.fxIndex or 0)%#U.fx+1;local fx=U.fx[U.fxIndex];fx.at=t;fx.kind=F.pets[data.id].fx;fx.id=data.id;fx.tex:Show()
 elseif kind=="hit" then
  if data.source=="burn" then return end
  U.hitAt=t;pop(U.Number(data.amount),data.source=="power" and gold or white)
  if data.source=="click" or data.source=="power" then
   U.trainerAt=t;U.fxIndex=(U.fxIndex or 0)%#U.fx+1;local fx=U.fx[U.fxIndex]
   fx.at=t;fx.kind=data.source=="power" and "star" or "slash";fx.id=nil;fx.tex:Show();A.Play(data.source=="power" and "special" or "strike")
  elseif data.source~="burn" then A.Play("hit") end
 elseif kind=="loot" or kind=="bosswin" then
  U.deathAt=t;U.deathFile=U.enemyFile
  for i,p in ipairs(U.coins) do p.at=t+(i-1)*.018;p.tex:Show() end
  U.message="+"..U.Number(data.gold).." gold"..(data.chest and " — treasure chest!" or "")
  if kind=="bosswin" then U.message="Guardian defeated! +"..U.Number(data.gold).." gold. Open World to travel.";A.Play("victory")
  else A.Play(data.chest and "treasure" or "catch") end
 elseif kind=="bossfail" then U.message="Guardian escaped. Keep your gold; upgrade or change crew, then try again.";A.Play("defeat")
 elseif kind=="relic" then U.message="New relic: "..data.name.."! Equip it in Loot & style.";A.Play("treasure")
 elseif kind=="upgrade" then U.upgradeAt=t;U.message=data.id=="blade" and "Blade sharpened. Your clicks deal more damage." or "Companion trained. Your crew is stronger.";A.Play("open")
 elseif kind=="shield" then U.message="A new shell! Click to crack it, or use a boar / Power Strike.";A.Play("guard")
 elseif kind=="contract" then U.message="Contract complete! +"..U.Number(data.gold).." gold.";A.Play("victory")
 elseif kind=="spawn" and data.boss then A.Play("special") end
end
function U.SavePosition()
 if not U.frame then return end
 local x,y=U.frame:GetCenter();local px,py=UIParent:GetCenter()
 if x and px then G.db.settings.position={x=x-px/U.frame:GetScale(),y=y-py/U.frame:GetScale()} end
end
function U.Position()
 local p=G.db.settings.position;U.frame:ClearAllPoints();U.frame:SetPoint("CENTER",UIParent,"CENTER",p and p.x or 0,p and p.y or 0)
end
function U.Build()
 if U.frame then return end
 local w=CreateFrame("Frame","FlightboundIdleFrame",UIParent);U.frame=w
 w:SetSize(680,592);w:SetFrameStrata("MEDIUM");w:SetMovable(true);w:SetClampedToScreen(true);w:EnableMouse(true);w:SetScale(G.db.settings.scale);U.Position()
 local drag=CreateFrame("Frame",nil,w);place(drag,w,5,4,485,47);drag:EnableMouse(true);drag:RegisterForDrag("LeftButton")
 drag:SetScript("OnDragStart",function() w:StartMoving() end);drag:SetScript("OnDragStop",function() w:StopMovingOrSizing();U.SavePosition() end)
 w:SetScript("OnHide",function() U.SavePosition();F.autoOpened=false;A.Stop() end)
 table.insert(UISpecialFrames,"FlightboundIdleFrame")
 local scene=CreateFrame("Frame",nil,w);U.scene=scene;place(scene,w,16,116,648,250)
 U.backdrop=texture(scene,0,0,648,250,nil,"BACKGROUND",0)
 U.shade=texture(scene,0,0,648,44,{.015,.02,.03,.86},"BACKGROUND",1)
 U.sceneTitle=label(scene,14,10,370,24,"",17,gold)
 U.sceneSub=label(scene,14,33,365,20,"",11,white)
 U.enemyName=label(scene,373,12,260,22,"",15,white,"CENTER")
 U.enemyHint=label(scene,373,36,260,20,"Click to attack",12,gold,"CENTER")
 U.trainer=texture(scene,15,129,84,84,nil,"ARTWORK",0);art(U.trainer,"trainer_dwarf_1")
 U.actors={}
 for i=1,3 do U.actors[i]=texture(scene,100+(i-1)*76,121+(i%2)*17,82,82,nil,"ARTWORK",i) end
 U.enemy=texture(scene,430,55,154,154,nil,"ARTWORK",4)
 U.ghost=texture(scene,430,55,154,154,nil,"ARTWORK",5);U.ghost:Hide()
 U.aura=texture(scene,425,55,164,164,nil,"ARTWORK",3);art(U.aura,"Combat\\shield_1");U.aura:Hide()
 U.hpBG=texture(scene,373,215,260,14,{.03,.02,.02,1},"BORDER",0)
 U.hp=texture(scene,374,216,258,12,{.60,.08,.045,1},"BORDER",1)
 U.hpText=label(scene,373,215,260,18,"",11,white,"CENTER")
 U.timerText=label(scene,373,235,260,15,"",10,gold,"CENTER")
 U.target=CreateFrame("Button",nil,scene);place(U.target,scene,365,50,276,160)
 U.target:SetScript("OnClick",function() U.Action(function() return G.Click(G.db,F.Now()) end) end)
 U.floatHost=CreateFrame("Frame",nil,scene);place(U.floatHost,scene,0,0,648,250)
 for i=1,8 do U.floats[i]={text=label(U.floatHost,390,70,210,26,"",20,gold,"CENTER")};U.floats[i].text:SetDrawLayer("OVERLAY",i-1);U.floats[i].text:Hide() end
 for i=1,18 do U.coins[i]={tex=texture(U.floatHost,0,0,6,6,{1,.75,.13,1},"OVERLAY",6)};U.coins[i].tex:Hide() end
 for i=1,8 do U.fx[i]={tex=texture(scene,420,75,140,140,nil,"OVERLAY",i-1)};U.fx[i].tex:Hide() end
end
function U.Go(page)
 U.tab=page;U.message=nil;A.Stop()
 if page=="world" then U.worldPage=G.db.zone end
 U.Render()
end
local function card(x,y,w,h,accent)
 rect(x,y,w,h,accent and {.23,.39,.27,1} or edge,-4)
 rect(x+1,y+1,w-2,h-2,{.075,.075,.075,1},-3)
end
local function home(d)
 local stats=G.Stats(d);local title,body=G.Objective(d)
 rect(16,63,648,45,{.115,.10,.062,1},-5)
 text(26,69,628,19,title,13,gold);text(26,91,628,17,body,10,white)
 local e=d.enemy;local powerCost=G.Relic(d,"lens") and 65 or 100
 button(16,377,315,36,"Power Strike · "..math.floor(d.focus).." / "..powerCost.." Focus",function() U.Action(function() return G.Power(d,F.Now()) end) end,e~=nil and d.focus>=powerCost and not (e.elite and F.trials[d.zone].noPower),d.focus>=powerCost)
 local bossLabel
 if e and e.boss then bossLabel="Retreat · keep your gold"
 elseif d.cleared[d.zone] and d.zone<9 then bossLabel=G.Charter(d,d.zone) and (d.zone==8 and G.Highest(d)<9 and "Finish regional contracts" or "Travel to next region") or "Choose a regional contract"
 else bossLabel=d.kills[d.zone]>=F.zones[d.zone].need and "Challenge "..F.zones[d.zone].title or "Guardian · "..d.kills[d.zone].." / "..F.zones[d.zone].need.." creatures" end
 button(345,377,319,36,bossLabel,function()
  U.Action(function()
   if d.enemy and d.enemy.boss then G.Spawn(d,false);return true end
   if d.cleared[d.zone] and d.zone<9 then
    if not G.Charter(d,d.zone) or d.zone==8 and G.Highest(d)<9 then U.Go("world");return true end
    return G.Travel(d,d.zone+1)
   end
   return G.Boss(d,false)
  end,"menu")
 end,d.kills[d.zone]>=F.zones[d.zone].need)
 card(16,429,315,69);card(345,429,319,69)
 button(26,437,295,31,"Sharpen blade · "..U.Number(G.BladeCost(d)).." gold",function() U.Action(function() return G.Buy(d,"blade") end) end,d.gold>=G.BladeCost(d) and d.blade<65)
 local nextBlade=G.Copy(d);nextBlade.blade=math.min(65,d.blade+1)
 text(26,477,295,18,"Damage per click: "..U.Number(stats.click).." -> "..U.Number(G.Stats(nextBlade).click),11,dim,"CENTER")
 local id=d.party[1] or "wolf";local cost=G.PetCost(d,id);local name=d.pets[id]==0 and "Recruit Wolf" or "Train "..F.pets[id].name
 button(355,437,299,31,name.." · "..U.Number(cost).." gold",function() U.Action(function() return G.Buy(d,"pet",id) end) end,d.gold>=cost and d.pets[id]<45)
 text(355,477,299,18,d.pets[id]>0 and "Companion level "..d.pets[id].." · automatic attacks" or "Your first companion attacks automatically",11,dim,"CENTER")
 local newPet=false;for _,pid in ipairs(F.petOrder) do local p=F.pets[pid];if d.pets[pid]==0 and (p.unlock==0 or d.cleared[p.unlock]) and pid~="wolf" then newPet=true end end
 button(16,514,208,29,newPet and "Companions · new" or "Companions",function() U.Go("crew") end)
 button(236,514,208,29,"World",function() U.Go("world") end)
 button(456,514,208,29,"Relics",function() U.Go("loot") end)
end
local function pageHeader(title,description)
 button(16,66,160,31,"< Back to adventure",function() U.Go("upgrades") end)
 text(194,71,470,27,title,20,gold)
 text(18,110,646,25,description,12,dim)
end
local function crew(d)
 pageHeader("Companions",#d.party.." of 3 active · Crew damage: "..U.Number(G.Stats(d).dps).." / second · Evolve at levels 10 and 25")
 for i,id in ipairs(F.petOrder) do
  local p=F.pets[id];local x=16+((i-1)%2)*330;local y=145+math.floor((i-1)/2)*132;local active=G.HasPet(d,id);local unlocked=p.unlock==0 or d.cleared[p.unlock]
  card(x,y,318,119,active)
  image(x+10,y+9,44,44,"Console\\"..G.PetArt(d,id).."_portrait",{0,44/64,0,44/64})
  text(x+64,y+11,244,23,p.name,16,unlocked and gold or dim)
  text(x+64,y+36,244,17,d.pets[id]>0 and "Level "..d.pets[id]..(active and " · active" or " · resting") or unlocked and "Ready to recruit" or "Locked",11,dim)
  text(x+12,y+58,294,29,unlocked and p.role or "Defeat "..F.zones[p.unlock].title.." to recruit.",11,white)
  local pet=id;local cost=G.PetCost(d,id)
  button(x+10,y+90,95,23,active and "Rest" or "Use",function() U.Action(function() return G.Party(d,pet) end,"menu") end,d.pets[id]>0,active)
  button(x+115,y+90,193,23,(d.pets[id]>0 and "Train · " or "Recruit · ")..U.Number(cost).." gold",function() U.Action(function() return G.Buy(d,"pet",pet) end) end,unlocked and d.gold>=cost and d.pets[id]<45)
 end
end
local function world(d)
 local zone=U.worldPage;local z=F.zones[zone]
 pageHeader("World", "Choose a region. Defeat its guardian, then complete any contract to open the next skyway.")
 for i,region in ipairs(F.zones) do local index=i
  button(16,145+(i-1)*43,225,34,i..". "..region.name,function() U.worldPage=index;U.Render() end,true,i==zone)
 end
 image(257,145,407,129,"Battles\\"..z.art)
 text(270,153,380,23,z.name,17,gold)
 local status=zone>G.Highest(d) and (zone==9 and "Locked · needs 18 regional contracts" or "Locked · finish the previous region") or d.cleared[zone] and "Guardian defeated" or "Guardian: "..z.title
 text(257,287,407,22,status,12,white)
 button(257,316,407,31,zone==d.zone and "You are here" or "Travel here",function() U.Action(function() return G.Travel(d,zone) end,"open");if d.zone==zone then U.Go("upgrades") end end,zone<=G.Highest(d) and zone~=d.zone)
 for i=1,3 do
  local value,need,name=G.Contract(d,zone,i);local y=359+(i-1)*63;local index=i
  text(257,y,407,20,name.." · "..math.min(value,need).." / "..need,13,d.claims[zone][i] and green or gold)
  text(257,y+23,223,29,i==3 and F.trials[zone].hint or "Reward: "..U.Number(G.ZoneGold(zone)*100).." gold",10,dim)
  button(494,y+21,170,29,d.claims[zone][i] and "Completed" or i==3 and value<need and "Start trial" or "Claim reward",function()
   local ok=U.Action(function()
    if index==3 and value<need then if d.zone~=zone then local traveled,message=G.Travel(d,zone);if not traveled then return false,message end end;return G.Boss(d,true) end
    return G.Claim(d,zone,index)
   end,"menu")
   if ok and index==3 and value<need then U.Go("upgrades") end
  end,not d.claims[zone][i] and (value>=need or i==3 and d.cleared[zone]))
 end
end
local function loot(d)
 pageHeader("Relics & play style", d.cleared[3] and "Choose one play style. Equip up to two relics." or "Choose one play style. One relic slot; a second unlocks in Darkshore.")
 for i,id in ipairs(F.styleOrder) do local style=id
  button(16+(i-1)*165,145,153,32,F.styles[id].name,function() U.Action(function() return G.Style(d,style) end,"menu") end,d.cleared[1],d.style==id)
 end
 text(18,189,646,20,d.cleared[1] and F.styles[d.style].text or "Defeat Bramblekeeper to choose a play style.",13,white)
 for i,r in ipairs(F.relics) do
  local x=16+((i-1)%2)*330;local y=225+math.floor((i-1)/2)*105;local id=r.id;local equipped=G.Relic(d,id)
  card(x,y,318,94,equipped)
  text(x+12,y+9,294,23,r.name,16,d.relics[id] and gold or dim)
  text(x+12,y+35,294,25,r.description,12,white)
  text(x+12,y+65,189,23,d.relics[id] and (equipped and "Equipped" or "Available") or r.source,10,dim)
  button(x+208,y+63,98,25,equipped and "Unequip" or "Equip",function() U.Action(function() return G.Equip(d,id) end,"menu") end,d.relics[id],equipped)
 end
end
function U.Render()
 if not U.frame or not G.db then return end
 local d=G.db;U.used={}
 rect(0,0,680,592,edge,-8);rect(3,3,674,586,dark,-7)
 image(4,4,672,45,"Console\\wow_stone"):SetDrawLayer("BACKGROUND",-6)
 image(13,5,42,42,"Console\\trainer_dwarf_1_portrait",{0,44/64,0,44/64})
 text(63,11,259,28,"Flightbound",23,gold)
 text(330,17,165,25,U.Number(d.gold).." gold",19,gold,"RIGHT")
 button(507,13,113,29,d.settings.sound and "Sound: On" or "Sound: Off",function()
  d.settings.sound=not d.settings.sound;if not d.settings.sound then A.Stop() else A.Play("treasure") end;U.Render()
 end)
 button(631,13,32,29,"X",function() U.frame:Hide() end)
 if U.tab=="upgrades" then
  U.scene:Show();art(U.backdrop,"Battles\\"..F.zones[d.zone].art)
  U.sceneTitle:SetText(F.zones[d.zone].name);U.sceneSub:SetText("")
  for i,t in ipairs(U.actors) do local id=d.party[i];if id then art(t,G.PetArt(d,id));t:Show() else t:Hide() end end
  local e=d.enemy
  if e then
   U.enemyFile=e.chest and "Symbols\\chest" or e.id;art(U.enemy,U.enemyFile,not e.chest);U.enemy:Show()
   U.enemyName:SetText((e.elite and "Elite " or "")..e.name)
   U.enemyHint:SetText(e.elite and F.trials[d.zone].noClicks and "Crew-only trial" or d.totalTaps<1 and "Click to attack" or "")
   U.hp:SetSize(math.max(1,258*e.hp/e.max),12);U.hpText:SetText(math.ceil(e.hp/e.max*100).."%")
   U.timerText:SetText(e.boss and string.format("%.1fs left%s",e.time,e.armor>0 and " · Armor "..math.floor(e.armor*100).."%" or e.ward and " · Wind ward" or "") or "")
   if e.armor>0 or e.ward then U.aura:Show() else U.aura:Hide() end
  else U.enemy:Hide();U.aura:Hide();U.enemyName:SetText("Loot collected!");U.hp:SetSize(1,12);U.hpText:SetText("");U.timerText:SetText("") end
  home(d)
 else
  U.scene:Hide()
  if U.tab=="crew" then crew(d) elseif U.tab=="world" then world(d) else loot(d) end
 end
 text(17,555,646,23,U.message or "",11,dim)
 text(17,579,646,12,"Whitebeard Tinkerton - US PVP",9,dim,"CENTER")
 for kind,pool in pairs(U.pool) do for i=(U.used[kind] or 0)+1,#pool do pool[i]:Hide() end end
end
function U.Animate()
 if not U.frame or not U.frame:IsShown() or U.tab~="upgrades" then return end
 local t=GetTime();local d=G.db
 local trainerAge=t-(U.trainerAt or -100);local lunge=trainerAge<.35 and math.sin(trainerAge/.35*math.pi)*32 or 0
 place(U.trainer,U.scene,15+lunge,129-math.abs(math.sin(t*2))*2,84,84)
 for i,actor in ipairs(U.actors) do
  local id=d.party[i];local age=t-(U.attacks[id] or -100);local move=age<.5 and math.sin(age/.5*math.pi)*48 or 0
  local bob=math.sin(t*(id=="wisp" and 3 or 4)+i)*3
  place(actor,U.scene,100+(i-1)*76+move,121+(i%2)*17+bob-(move>0 and math.sin(age/.5*math.pi)*7 or 0),82,82)
 end
 local breathe=math.sin(t*2.6)*3;local hitAge=t-(U.hitAt or -100);local shake=hitAge<.22 and math.sin(hitAge*75)*(1-hitAge/.22)*8 or 0
 place(U.enemy,U.scene,430+shake,55-breathe,154,154+breathe)
 U.aura:SetAlpha(.35+.15*math.sin(t*5))
 if U.deathAt and t-U.deathAt<.43 and U.deathFile then
  local age=(t-U.deathAt)/.43;art(U.ghost,U.deathFile,true);place(U.ghost,U.scene,430+age*20,55-age*20,154*(1-age*.2),154*(1-age*.2));U.ghost:SetAlpha(1-age);U.ghost:Show()
 else U.ghost:Hide() end
 for _,p in ipairs(U.floats) do
  if p.at and t-p.at<.8 then local age=(t-p.at)/.8;place(p.text,U.floatHost,400+p.offset,92-age*50,210,26);p.text:SetAlpha(1-age);p.text:Show() else p.text:Hide() end
 end
 for i,p in ipairs(U.coins) do
  if p.at and t>=p.at and t-p.at<.7 then
   local age=(t-p.at)/.7;local scatter=(i%5-2)*16
   place(p.tex,U.floatHost,499+(370-499)*age+scatter*math.sin(age*math.pi),135+(-88-135)*age-55*math.sin(age*math.pi),4+math.abs(math.sin(age*16+i))*4,7)
   p.tex:SetAlpha(1-age*.3);p.tex:Show()
  else p.tex:Hide() end
 end
 for _,fx in ipairs(U.fx) do
  if fx.at and t-fx.at<.45 then
   local age=(t-fx.at)/.45;local frame=math.min(4,1+math.floor(age*4));art(fx.tex,"Combat\\"..fx.kind.."_"..frame)
   local ranged=fx.id=="whelp" or fx.id=="wisp" or fx.id=="murloc"
   local x=ranged and (240+210*math.min(1,age*2)) or 420
   place(fx.tex,U.scene,x,78,135,135);fx.tex:SetAlpha(math.min(1,(1-age)*2));fx.tex:Show()
  else fx.tex:Hide() end
 end
end
function U.Open(manual)
 U.Build();if manual then F.autoOpened=false end
 local d=G.db;G.Advance(d,F.Now(),false);U.tab="upgrades"
 if d.away and (d.away.seconds or 0)>=30 then U.message="While away: +"..U.Number(d.away.gold).." gold, "..d.away.kills.." creatures. Your crew kept hunting." end
 d.away=nil;U.frame:Show();U.Render();U.Animate();A.Play("open")
end
