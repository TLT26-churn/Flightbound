local _,F=...
local G,U,P=F.Game,F.UI,F.palette
local H=U.Paint
local text,rect,sprite,button,act,run,page,back,heading,dialogue=H.text,H.rect,H.sprite,H.button,H.act,H.run,H.page,H.back,H.heading,H.dialogue
local function hideBox() if U.trainerBox then U.trainerBox:ClearFocus();U.trainerBox:Hide() end end
function U.pages.trainer()
 if not U.trainerDraft then
  local original=G.db.trainer or G.PlayerTrainer()
  U.trainerDraft={name=original.name,race=original.race,class=original.class,gender=original.gender}
 end
 local p=U.trainerDraft;local race=G.TrainerRace(p.race);heading("CREATE YOUR TRAINER")
 sprite(G.TrainerArt(p),12,40,96,96,false,false,"trainer")
 text(12,132,96,15,race.faction,10,"CENTER")
 local function raceStep(delta)
  local index=1;for i,r in ipairs(F.trainerRaces) do if r.id==p.race then index=i end end
  p.race=F.trainerRaces[(index-1+delta)%#F.trainerRaces+1].id
  local allowed=false;for _,c in ipairs(G.TrainerRace(p.race).classes) do if c==p.class then allowed=true end end
  if not allowed then p.class="WARRIOR" end
 end
 button(113,40,24,24,"<",run(function() raceStep(-1) end));button(294,40,24,24,">",run(function() raceStep(1) end))
 text(140,42,150,24,race.name,10,"CENTER")
 button(114,74,98,24,(p.gender==1 and "* " or "").."MALE",run(function() p.gender=1 end))
 button(218,74,98,24,(p.gender==2 and "* " or "").."FEMALE",run(function() p.gender=2 end))
 local function classStep(delta)
  local list=G.TrainerRace(p.race).classes;local index=1;for i,c in ipairs(list) do if c==p.class then index=i end end
  p.class=list[(index-1+delta)%#list+1]
 end
 button(113,110,24,24,"<",run(function() classStep(-1) end));button(294,110,24,24,">",run(function() classStep(1) end))
 text(140,116,150,16,U.Title(p.class),11,"CENTER")
 text(12,154,304,12,"Trainer name",10)
 rect(12,170,304,27,P.dark);rect(14,172,300,23,P.soft,"BORDER")
 if not U.trainerBox then
  local box=CreateFrame("EditBox",nil,U.canvas);U.trainerBox=box
  box:SetPoint("TOPLEFT",U.canvas,"TOPLEFT",20,-176);box:SetSize(288,18)
  box:SetFont("Fonts\\FRIZQT__.TTF",11,"");box:SetTextColor(unpack(P.dark));box:SetAutoFocus(false);box:SetMaxLetters(24);box:SetTextInsets(0,0,0,0)
  box:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
  box:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
  box:SetText(p.name)
 end
 U.trainerBox:Show()
 dialogue(U.trainerError or "Choose your race, class and gender. Only Forever's allowed combinations appear. Your trainer explores the dungeon; your companions battle beside you.")
 act(1,G.Active() and "SAVE TRAINER" or "CHOOSE COMPANION",run(function()
  p.name=U.trainerBox:GetText()
  if G.SetTrainer(p) then U.trainerError=nil;hideBox();U.page=nil else U.trainerError="Enter a trainer name first." end
 end))
 act(2,"USE MY WOW HERO",run(function() U.trainerDraft=G.PlayerTrainer();U.trainerBox:SetText(U.trainerDraft.name) end))
 act(3,"",nil,false);act(4,G.db.trainer and "CANCEL" or "",G.db.trainer and function() hideBox();U.trainerDraft=nil;U.trainerError=nil;U.page=nil;U.Render() end or nil,G.db.trainer~=nil)
end
function U.pages.story()
 local d=G.db;local z=F.dungeons[d.zone];local goal=G.Objective();heading(z.name)
 text(12,38,200,15,"DUNGEON "..d.zone.." / 8",11);button(228,35,88,23,"SELECT",page("dungeons"))
 sprite(G.TrainerArt(),14,62,92,92,false,false,"trainer")
 text(119,70,196,28,d.trainer.name,12);text(119,102,196,27,G.TrainerRace(d.trainer.race).name,10)
 text(119,136,196,16,U.Title(d.trainer.class).." / "..U.Title(G.Difficulty().name),9)
 text(12,167,304,17,"Explore / Find the key / Face the boss",10)
 text(12,186,304,12,"SALVES "..d.salves.."   CHARMS "..d.charms.."   "..d.coins.." GOLD",9)
 dialogue(d.badges[d.zone] and z.ending or z.intro)
 act(1,goal.action,run(U.FollowStory),G.Active()~=nil);act(2,"TEAM / NAMES",page("team"),G.Active()~=nil)
 act(3,"CAMP SHOP",page("shop"));act(4,"MENU",page("menu"))
 U.advanceAction=U.actions[1]
end
local tileArt={T="Symbols\\chest",K="Symbols\\key",C="Symbols\\camp",["?"]="Symbols\\crack"}
local function drawTile(x,y,px,py,size,interactive)
 local r=G.db.dungeon;local theme=G.MapTheme();local key=G.PointKey(x,y);local explored=r.explored[key];local c=G.DungeonTile(x,y)
 if not c or not explored then rect(px,py,size,size,theme.fog);return end
 local floor=sprite(G.MapTileArt(x,y,c,theme),px,py,size,size);floor:SetDrawLayer("BACKGROUND",0)
 if tileArt[c] then sprite(tileArt[c],px,py,size,size)
 elseif c=="E" or c=="R" or c=="B" then local e=G.DungeonEnemy(x,y);sprite(G.Art(e),px,py,size,size) end
 if c=="R" or c=="B" then local mark=sprite("Symbols\\guardian",px+size*.64,py,size*.36,size*.36);mark:SetDrawLayer("ARTWORK",1) end
 if c=="." and r.used[key] and G.DungeonLayout(r.zone).rows[y]:sub(x,x)=="T" then sprite("Symbols\\chest_open",px,py,size,size) end
 if c=="^" then
  -- A pressure plate is an inset in the actual floor, not a bright X icon.
  local a,b,w,h=px+size*.25,py+size*.28,size*.50,size*.44
  rect(a,b,w,1,{.03,.03,.03,.20},"BORDER"):SetDrawLayer("BORDER",0)
  rect(a,b+1,1,h-1,{.03,.03,.03,.16},"BORDER"):SetDrawLayer("BORDER",1)
  rect(a+1,b+h-1,w-1,1,{1,1,1,.13},"BORDER"):SetDrawLayer("BORDER",2)
  rect(a+w-1,b+1,1,h-2,{1,1,1,.10},"BORDER"):SetDrawLayer("BORDER",3)
 end
 if x==r.x and y==r.y then local t=sprite(G.TrainerArt(),px-1,py-2,size+2,size+2);t:SetDrawLayer("ARTWORK",2) end
 if interactive and math.abs(x-r.x)+math.abs(y-r.y)==1 then
  local dx,dy=x-r.x,y-r.y
  local hit=button(px,py,size,size,"",run(function() G.StepDungeon(dx,dy) end));hit.edge:SetAlpha(0);hit.fill:SetAlpha(0)
  hit:SetScript("OnEnter",function(self) self.fill:SetAlpha(.2) end);hit:SetScript("OnLeave",function(self) self.fill:SetAlpha(0) end)
 end
end
function U.pages.dungeon()
 local d=G.db;local r=d.dungeon;if not r then U.pages.story();return end
 local size=U.MapZoom();local columns,rows=math.floor(552/size),math.floor(340/size)
 local left=G.Clamp(r.x-math.ceil(columns/2),0,21-columns);local top=G.Clamp(r.y-math.ceil(rows/2),0,17-rows)
 local ox,oy=math.floor((552-columns*size)/2),math.floor((340-rows*size)/2)
 rect(0,0,552,340,G.MapTheme().fog):SetDrawLayer("BACKGROUND",-1)
 for row=1,rows do for col=1,columns do drawTile(left+col,top+row,ox+(col-1)*size,oy+(row-1)*size,size,true) end end
 act(1,"INTERACT",run(G.InteractDungeon));act(2,"DUNGEON MAP",page("chart"))
 act(3,"TEAM / BAG",page("team"));act(4,"MENU",page("menu"))
end
function U.pages.chart()
 if not G.db.dungeon then back();return end
 heading("DISCOVERED DUNGEON MAP")
 for y=1,17 do for x=1,21 do drawTile(x,y,8+(x-1)*24,36+(y-1)*24,24,false) end end
 local p=G.DungeonProgress()
 text(10,450,500,14,"Cargo "..p.cargo.."/"..p.cargoTotal.." / Caches "..p.caches.."/"..p.cacheTotal.." / Secrets "..p.secrets.."/"..p.secretTotal.." / Foes "..p.foes.."/"..p.foeTotal,10,"CENTER")
 act(1,"BACK TO EXPLORING",back);act(2,"",nil,false);act(3,"",nil,false);act(4,"",nil,false)
end
function U.pages.menu()
 heading("EXPLORER'S JOURNAL")
 local quests,awards=G.PendingRewards()
 local items={{"DUNGEONS","dungeons"},{"TRAINER","trainer"},{"CAMP SHOP","shop"},{"EVOLUTIONS","evolutions"},{"FIELD GUIDE","journal"},{"QUESTS"..(quests>0 and " ("..quests..")" or ""),"quests"},{"ACHIEVEMENTS"..(awards>0 and " ("..awards..")" or ""),"awards"},{"DUNGEON MAP","chart"},{"SETTINGS","settings"},{"FRIENDS / GUILD","social"},{"LEADERBOARD","leaderboard"}}
 for i,v in ipairs(items) do button(10+((i-1)%2)*157,36+math.floor((i-1)/2)*27,151,24,v[1],function()
  if v[2]=="trainer" then U.trainerDraft=nil;if U.trainerBox then U.trainerBox:SetText(G.db.trainer.name) end end
  U.page=v[2];U.offset=0;U.Render()
 end,v[2]~="chart" and (v[2]~="shop" or not G.db.dungeon) or v[2]=="chart" and G.db.dungeon~=nil) end
 dialogue(G.db.dungeon and "Return to camp to rest and resupply. Your discovered map and cleared encounters are kept. Closing this window pauses exactly where you stand."
  or "Explore freely. Find a key, unlock the sealed passage, then defeat the guardian. Adventure difficulty requires careful use of camps and supplies.")
 act(1,"BACK TO GAME",back);act(2,G.db.dungeon and "RETURN TO CAMP" or "REST / RESUPPLY",run(function() if G.db.dungeon then G.RetreatDungeon() else G.Camp() end;U.page=nil end),G.Active()~=nil)
 act(3,"ENDLESS ARENA",page("arena"));act(4,"HOW TO PLAY",page("help"))
end

U.pages.map=function() if G.db.dungeon then U.pages.chart() else U.pages.story() end end
