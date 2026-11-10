-- Adventure Console: private classic chrome around the existing game screens.
-- This module changes presentation only; campaign and link state stay in Game.
local _,F=...
local U,G,P=F.UI,F.Game,F.palette
local W,H=U.Widgets,U.Paint
local tex,label,button=W.texture,W.label,W.button
local gold,ink,dim={1,.82,0,1},{.94,.90,.80,1},{.69,.65,.56,1}
local dark,edge,navy={.075,.065,.05,1},{.42,.35,.23,1},{.035,.04,.10,1}
local path=F.path.."Art\\Console\\"
-- The exploration scene and its message strip occupy separate, adjacent areas.
U.mapWidth,U.mapHeight=552,296
local abbreviations={hp="HP",xp="XP",pvp="PvP",us="US",wow="WoW"}
function U.Title(value)
 value=value or "" -- Empty WoW FontStrings can return nil from GetText().
 if value:find("%l") then return value end
 return (value:lower():gsub("%a[%w']*",function(word)
  return abbreviations[word] or word:sub(1,1):upper()..word:sub(2)
 end))
end
function U.Sentence(value)
 value=value or ""
 if value:find("%l") then return value end
 local result=value:lower():gsub("%a[%w']*",function(word) return abbreviations[word] or word end)
 return (result:gsub("%a",string.upper,1))
end
local function at(o,parent,x,y,w,h)
 o:ClearAllPoints();o:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y);o:SetSize(w,h)
end
local function art(parent,name,x,y,w,h,layer,sub)
 local t=tex(parent,x,y,w,h,{1,1,1,1},layer or "ARTWORK",sub or 0)
 t:SetTexture(path..name..".tga","CLAMP","CLAMP","NEAREST")
 if name=="frame" then t:SetTexCoord(0,588/1024,0,650/1024)
 elseif name:find("_portrait",1,true) then t:SetTexCoord(0,44/64,0,44/64)
 elseif name=="wow_button" or name=="wow_button_down" then t:SetTexCoord(0,80/128,0,22/32) end
 return t
end
local function panel(parent,x,y,w,h)
 tex(parent,x,y,w,h,edge,"BACKGROUND",-4)
 tex(parent,x+1,y+1,w-2,h-2,dark,"BACKGROUND",-3)
end
function U.RefreshButtonSkin(b)
 if not b.skin then return end
 local w,h=b.buttonWidth,b.buttonHeight
 b.label:SetText(U.Title(b.label:GetText()))
 b:SetAlpha(1)
 local hidden=(b.label:GetText() or "")=="" and not b.consoleArrow
 local primary=b.consoleStyle~="slot"
 b.edge:SetColorTexture(unpack(edge));b.fill:SetColorTexture(unpack(primary and {.28,.025,.015,1} or {.11,.095,.07,1}))
 local widths,heights={6,math.max(1,w-12),6},{6,math.max(1,h-12),6}
 local xs,ys={0,6,w-6},{0,6,h-6}
 local us,vs={0,7/128,73/128,80/128},{0,7/32,15/32,22/32}
 for i,t in ipairs(b.skin) do
  local col,row=(i-1)%3+1,math.floor((i-1)/3)+1
  at(t,b,xs[col],ys[row],widths[col],heights[row])
  t:SetTexCoord(us[col],us[col+1],vs[row],vs[row+1])
  t:SetAlpha(b:IsEnabled() and 1 or .38)
  if primary and not hidden then t:Show() else t:Hide() end
 end
 b.label:SetTextColor(unpack(b:IsEnabled() and gold or dim))
end
function U.SkinButton(b)
 b.skin={};b.consoleStyle="primary";b.consoleArrow=false
 for i=1,9 do b.skin[i]=art(b,"wow_button",0,0,1,1,"BORDER",1) end
 b:SetScript("OnEnter",function(self)
  if self:IsEnabled() then self.label:SetTextColor(1,1,.9,1);self.fill:SetColorTexture(.20,.17,.11,1) end
 end)
 b:SetScript("OnLeave",function(self) U.RefreshButtonSkin(self) end)
 b:SetScript("OnMouseDown",function(self)
  if self:IsEnabled() then for _,t in ipairs(self.skin) do t:SetTexture(path.."wow_button_down.tga") end end
 end)
 b:SetScript("OnMouseUp",function(self)
  for _,t in ipairs(self.skin) do t:SetTexture(path.."wow_button.tga") end
  U.RefreshButtonSkin(self)
 end)
 U.RefreshButtonSkin(b)
end
local function resize(b,parent,x,y,w,h,style)
 at(b,parent,x,y,w,h);b.buttonWidth,b.buttonHeight=w,h
 at(b.edge,b,0,0,w,h);at(b.fill,b,1,1,w-2,h-2)
 b.consoleStyle=style or "primary"
 at(b.label,b,5,math.floor((h-16)/2),w-10,18)
 b.label:SetFont("Fonts\\FRIZQT__.TTF",14,"")
 if b.icon and b.icon:IsShown() then
  at(b.icon,b,7,(h-20)/2,20,20);at(b.label,b,30,(h-16)/2,w-35,18)
 end
 U.RefreshButtonSkin(b)
end
local function moveButton(x,y,key,id,dx,dy)
 local b=button(U.navigation,x,y,36,36,"",function() G.StepDungeon(dx,dy);U.Render() end,true)
 b.moveKey=key;b.consoleArrow=true;b.consoleStyle="slot"
 at(b.icon,b,7,7,22,22);b.icon:SetTexture(F.path.."Art\\Symbols\\"..id..".tga");b.icon:Show()
 U.RefreshButtonSkin(b);return b
end
function U.Build()
 if U.frame then return end
 local w=CreateFrame("Frame","FlightboundFrame",UIParent);U.frame=w
 w:SetSize(588,650);w:SetFrameStrata("MEDIUM");w:SetClampedToScreen(true);w:SetMovable(true);w:EnableMouse(true)
 tex(w,9,9,570,632,dark,"BACKGROUND",-7)
 art(w,"frame",0,0,588,650,"BACKGROUND",-6)
 U.emblem=art(w,"trainer_dwarf_1_portrait",12,5,44,44,"ARTWORK",1)
 label(w,60,20,235,26,"Flightbound",22,gold)
 local drag=CreateFrame("Frame",nil,w);at(drag,w,12,10,380,40)
 drag:EnableMouse(true);drag:RegisterForDrag("LeftButton")
 drag:SetScript("OnDragStart",function() w:StartMoving() end)
 drag:SetScript("OnDragStop",function() w:StopMovingOrSizing();U.SavePosition() end)
 U.flight=label(w,295,29,94,14,"ON FOOT",10,dim,"RIGHT")
 U.keysToggle=button(w,402,20,87,27,"KEYS: OFF",function() U.SetKeyboard(not G.db.settings.keyboard,true) end,true)
 U.keysToggle.consoleStyle="slot";U.RefreshButtonSkin(U.keysToggle)
 local menu=button(w,497,18,30,30,"",function() U.page=U.page=="menu" and nil or "menu";U.Render() end,true)
 U.menuButton=menu
 menu.consoleArrow=true;menu.consoleStyle="slot";at(menu.icon,menu,4,4,22,22);menu.icon:SetTexture(F.path.."Art\\Symbols\\journal.tga");menu.icon:Show();U.RefreshButtonSkin(menu)
 local close=button(w,537,17,32,32,"",function() w:Hide() end,true)
 close.edge:Hide();close.fill:Hide();art(close,"wow_close",0,0,32,32,"ARTWORK",1)
 U.zone=CreateFrame("Frame",nil,w);at(U.zone,w,18,56,552,48)
 tex(U.zone,0,0,552,48,P.light,"BACKGROUND",-5)
 U.zoneTitle=label(U.zone,12,5,402,20,"",17,P.dark)
 U.objective=label(U.zone,12,27,422,17,"",12,P.dark)
 U.zoneKeyIcon=tex(U.zone,430,12,22,22,ink,"ARTWORK")
 U.zoneKeyIcon:SetTexture(F.path.."Art\\Symbols\\key.tga")
 U.zoneSalveIcon=tex(U.zone,496,12,22,22,ink,"ARTWORK")
 U.zoneSalveIcon:SetTexture(F.path.."Art\\Symbols\\bag.tga")
 U.supplies=label(U.zone,455,16,30,18,"",12,P.dark)
 U.salves=label(U.zone,522,16,25,18,"",12,P.dark)
 U.canvasHost=CreateFrame("Frame",nil,w);at(U.canvasHost,w,18,104,552,464)
 U.canvas=CreateFrame("Frame",nil,U.canvasHost);at(U.canvas,U.canvasHost,0,0,328,272)
 U.pools={text={},sprite={},rect={},button={}};U.used={}
 U.screenBackground=tex(U.canvas,0,0,328,272,P.light,"BACKGROUND",-8)
 U.particles={};for i=1,8 do local t=tex(U.canvas,0,0,4,4,ink,"OVERLAY",1);t:Hide();U.particles[i]=t end
 U.BuildCombatFX()
 U.companion=CreateFrame("Frame",nil,w);at(U.companion,w,18,444,552,54)
 panel(U.companion,0,0,552,54)
 U.portrait=art(U.companion,"murloc_portrait",9,5,44,44)
 U.petName=label(U.companion,65,7,320,19,"",16,gold)
 U.petLevel=label(U.companion,388,9,152,17,"",12,ink,"RIGHT")
 tex(U.companion,65,31,475,15,{.02,.02,.02,1},"BORDER",-1)
 U.petHP=tex(U.companion,66,32,473,13,{.12,.65,.10,1},"BORDER",0)
 U.petHPText=label(U.companion,65,31,475,16,"",12,{1,1,1,1},"CENTER")
 U.mapLog=CreateFrame("Frame",nil,w);at(U.mapLog,w,18,104+U.mapHeight,552,44)
 U.mapLog:EnableMouse(true)
 tex(U.mapLog,0,0,552,44,{.6,.6,.65,1},"BACKGROUND",-2)
 tex(U.mapLog,1,1,550,42,navy,"BACKGROUND",-1)
 U.mapLogText=label(U.mapLog,12,7,528,30,"",12,ink)
 U.dock=CreateFrame("Frame",nil,w);at(U.dock,w,18,498,552,108);panel(U.dock,0,0,552,108)
 U.actions={}
 for i=1,4 do
  local b=button(w,18,530,266,35,"",nil,true);U.actions[i]=b
  b.key=label(b,6,14,20,18,tostring(i),12,gold,"CENTER");b.key:Hide()
  b.detail=label(b,33,26,130,16,"",11,dim);b.detail:Hide()
 end
 U.navigation=CreateFrame("Frame",nil,w);at(U.navigation,w,26,510,124,86)
 U.moveButtons={moveButton(0,40,"<","left",-1,0),moveButton(40,0,"^","up",0,-1),moveButton(40,40,"V","down",0,1),moveButton(80,40,">","right",1,0)}
 U.zoomControls=CreateFrame("Frame",nil,w);at(U.zoomControls,w,366,56,190,28)
 U.zoomOut=button(U.zoomControls,0,0,24,22,"-",function() U.SetMapZoom(-1) end,true)
 U.zoomIn=button(U.zoomControls,0,0,24,22,"+",function() U.SetMapZoom(1) end,true)
 U.zoomLabel=label(U.zoomControls,0,0,45,18,"",10,dim,"CENTER")
 U.battleControls=CreateFrame("Frame",nil,w);at(U.battleControls,w,18,434,552,172)
 panel(U.battleControls,0,0,552,56)
 U.battleTip=label(U.battleControls,12,8,528,42,"",13,ink)
 U.battleExtras={button(w,18,554,176,44,"",nil,true),button(w,394,554,176,44,"",nil,true)}
 for _,b in ipairs(U.battleExtras) do
  b.key=label(b,6,14,20,18,"",12,gold,"CENTER");b.detail=label(b,33,26,130,16,"",11,dim)
 end
 U.keysHint=label(w,18,608,408,23,"",10,dim)
 U.auto=button(w,448,614,122,24,"AUTO: ON",function() G.db.settings.auto=not G.db.settings.auto;U.UpdateStatus();F.CheckFlight() end,true)
 U.auto.consoleStyle="slot";U.RefreshButtonSkin(U.auto)
 label(w,18,631,410,11,"By Whitebeard Tinkerton - US PVP  |  /fb  |  v"..F.version,9,dim)
 U.focusEdges={tex(w,18,606,552,1,gold,"BORDER",1)};U.focusEdges[1]:Hide()
 U.BuildKeyboard()
 w:SetScript("OnHide",function()
  U.ReleaseKeyboard(true);w:StopMovingOrSizing();U.SavePosition();F.autoOpened=false;U.effect=nil;U.travel=nil
  if U.nameBox then U.nameBox:ClearFocus() end;if U.trainerBox then U.trainerBox:ClearFocus() end
  for _,t in ipairs(U.particles) do t:Hide() end
  U.HideCombatFX();U.ClearDamagePops();U.duelQueue={};if F.Audio then F.Audio.Stop() end
 end)
 w:SetScript("OnUpdate",function(_,dt) U.Animate(dt) end)
 tinsert(UISpecialFrames,"FlightboundFrame");w:Hide();U.ApplyPosition()
end
function U.Layout(wide,exploring)
 U.wide=wide;U.exploring=exploring
 U.zone:Hide();U.companion:Hide();U.mapLog:Hide();U.navigation:Hide();U.battleControls:Hide()
 for _,b in ipairs(U.battleExtras) do b:Hide() end
 U.canvas:SetScale(wide and 1 or 1.65)
 at(U.canvasHost,U.frame,wide and 34 or 23.4,wide and 56 or 60,520,464)
 U.canvas:SetSize(wide and 520 or 328,wide and 464 or 272);U.screenBackground:SetSize(wide and 520 or 328,wide and 464 or 272)
 U.screenBackground:SetColorTexture(unpack(P.light))
 if exploring then
  U.zone:Show();U.companion:Show();U.mapLog:Show();U.navigation:Show()
  at(U.canvasHost,U.frame,18,104,U.mapWidth,U.mapHeight);U.canvas:SetSize(U.mapWidth,U.mapHeight);U.screenBackground:SetSize(U.mapWidth,U.mapHeight)
 end
 local zoom=U.MapZoom();U.zoomOut:SetEnabled(zoom>32);U.zoomIn:SetEnabled(zoom<48);U.zoomLabel:SetText(math.floor(zoom/40*100).."%")
 -- Zoom is available on the full-map page; no floating controls over terrain.
 U.zoomControls:Hide();U.zoomOut:Hide();U.zoomIn:Hide();U.zoomLabel:Hide()
end
function U.BattleScene(p,enemy,title,subtitle,log,defeated,enemyDetail,playerDetail)
 U.zone:Show();U.battleControls:Show();U.battleTip:SetText(log)
 at(U.canvasHost,U.frame,18,104,552,330);U.canvas:SetScale(552/328);U.canvas:SetSize(328,196)
 U.screenBackground:SetSize(328,196);U.screenBackground:SetColorTexture(unpack(navy))
 U.zoneTitle:SetText(U.Title(title));U.objective:SetText(subtitle);U.supplies:SetText("");U.salves:SetText("")
 U.zoneKeyIcon:Hide();U.zoneSalveIcon:Hide()
 local theme=G.BattleTheme(U.duelView and {kind="arena"} or G.db.battle)
 H.sprite("Battles\\"..theme.id,0,0,328,196):SetDrawLayer("BACKGROUND",-6)
 local function stat(x,y,width,pet,name,detail,role)
  H.rect(x,y,width,45,{.62,.62,.67,1},"OVERLAY"):SetDrawLayer("OVERLAY",-4)
  H.rect(x+1,y+1,width-2,43,navy,"OVERLAY"):SetDrawLayer("OVERLAY",-3)
  H.text(x+5,y+4,width-32,15,name,10,nil,gold);H.text(x+width-29,y+5,25,11,"L"..pet.level,8,"RIGHT",gold)
  H.hp(x+5,y+21,width-10,pet,theme)
  H.text(x+5,y+21,width-10,10,pet.hp.." / "..G.MaxHP(pet),7,"CENTER",ink)
  H.text(x+5,y+33,width-10,11,U.Sentence(detail),8,nil,ink)
  U.hpPositions=U.hpPositions or {};U.hpPositions[role]={x=x+6,y=y+22,w=width-12}
 end
 stat(6,7,142,enemy,enemy.title or G.Name(enemy),enemyDetail,"enemy")
 stat(184,146,138,p,G.Name(p),playerDetail,"player")
 H.sprite(G.Art(enemy),218,34,92,92,true,defeated,"enemy")
 H.sprite(G.Art(p),16,100,96,96,false,false,"player")
end
local function moveLayout(b,key,x,y,w,h,style)
 resize(b,U.frame,x,y,w,h,style);b.icon:Hide();b.key:SetText(key);b.key:Show();b.detail:Show()
 at(b.key,b,6,15,20,18);at(b.label,b,31,7,w-38,19);at(b.detail,b,31,27,w-38,15)
 b.label:SetFont("Fonts\\FRIZQT__.TTF",14,"");b.detail:SetFont("Fonts\\FRIZQT__.TTF",11,"")
 b.detail:SetText(U.Sentence(b.detail:GetText()))
 b.detail:SetTextColor(unpack(b:IsEnabled() and dim or ink));b.detail:SetJustifyH("LEFT")
end
function U.FinishConsole()
 if G.db.trainer then U.emblem:SetTexture(path..G.TrainerArt().."_portrait.tga") end
 for i,b in ipairs(U.actions) do
  if (b.label:GetText() or "")=="" then b:Hide() else b:Show();resize(b,U.frame,18+(i-1)%2*280,526+math.floor((i-1)/2)*40,272,35,i==1 and "primary" or "slot") end
 end
 if U.exploring then
  local d,r,p=G.db,G.db.dungeon,G.Active()
  U.zoneTitle:SetText(F.dungeons[r.zone].name);U.objective:SetText(G.Objective().label)
  U.supplies:SetText(r.keys);U.salves:SetText(d.salves);U.zoneKeyIcon:Show();U.zoneSalveIcon:Show()
  U.portrait:SetTexture(path..G.Art(p).."_portrait.tga");U.petName:SetText(G.Name(p));U.petLevel:SetText(U.Title(F.species[p.id].kind).."  /  L"..p.level)
  U.petHP:SetSize(math.max(1,473*p.hp/G.MaxHP(p)),13);U.petHP:SetAlpha(p.hp>0 and 1 or 0);U.petHPText:SetText(p.hp.." / "..G.MaxHP(p))
  U.mapLogText:SetText(d.log)
  resize(U.actions[1],U.frame,158,506,404,44,"primary")
  U.actions[1].label:SetText((d.settings.keyboard and "Space  " or "").."Interact")
  U.actions[1].detail:Show();at(U.actions[1].label,U.actions[1],8,5,388,18);at(U.actions[1].detail,U.actions[1],8,25,388,15)
  local c=G.DungeonTile(r.x,r.y);if c=="." then c=G.DungeonTile(r.x+(r.faceX or 0),r.y+(r.faceY or 1)) end
  U.actions[1].detail:SetText(({C="Rest at camp",T="Open chest",K="Pick up the key",D="Use dungeon key",["?"]="Search cracked wall",B="Challenge guardian",S="Return to camp"})[c] or "Use the tile you face")
  U.actions[1].detail:SetJustifyH("CENTER");U.actions[1].detail:SetTextColor(unpack(ink))
  resize(U.actions[2],U.frame,158,558,198,36,"slot");resize(U.actions[3],U.frame,364,558,198,36,"slot")
  U.actions[4]:Hide() -- Journal is always accessible in the title bar.
 elseif U.battleVisible then
  if next(U.battleHotkeys) then
   for i=1,4 do
    local col,row=(i-1)%3,math.floor((i-1)/3)
    if U.actions[i]:IsShown() then moveLayout(U.actions[i],tostring(i),26+col*180,498+row*51,176,46,i<=3 and "primary" or "slot") end
   end
   for i,b in ipairs(U.battleExtras) do if b:IsShown() then
    local full=b.label:GetText();local title,detail
    if i==1 then title=U.duelView and "DUEL MENU" or "TAME";detail=full:gsub("^5%s+","")
    else title="FOCUS";detail=full:find("FOCUSED",1,true) and "Already focused" or "Next special +65%" end
    b.label:SetText(title);b.detail:SetText(detail);moveLayout(b,tostring(i+4),206+(i-1)*180,549,176,46,"slot")
    b.detail:SetFont("Fonts\\FRIZQT__.TTF",10,"")
   end end
  else
   for i,b in ipairs(U.actions) do if b:IsShown() then resize(b,U.frame,26+(i-1)%2*270,506+math.floor((i-1)/2)*44,262,38,i==1 and "primary" or "slot") end end
  end
 end
 if U.page=="chart" or U.page=="map" and G.db.dungeon then
  U.zoomControls:Show();U.zoomOut:Show();U.zoomIn:Show();U.zoomLabel:Show()
  resize(U.zoomOut,U.zoomControls,8,1,28,24,"slot");resize(U.zoomIn,U.zoomControls,152,1,28,24,"slot");at(U.zoomLabel,U.zoomControls,40,6,108,17)
 end
 U.RefreshButtonSkin(U.keysToggle);U.RefreshButtonSkin(U.auto)
end
