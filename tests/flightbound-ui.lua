-- Headless WoW UI stand-in: checks lifecycle and exports actual UI draw calls.
local objects,frames={},{}
local combat,keyboardFocus,mouseFoci=false,nil,{}
local physicalKeys={}
function InCombatLockdown() return combat end
function GetCurrentKeyBoardFocus() return keyboardFocus end
function GetMouseFoci() return mouseFoci end
function IsKeyDown(key) return physicalKeys[key]==true end
local methods={}
local function noop() end
for n in ("SetMovable SetClampedToScreen EnableMouse RegisterForDrag SetJustifyV SetWordWrap StartMoving StopMovingOrSizing"):gmatch("%S+") do methods[n]=noop end
function methods:SetSize(w,h) self.width,self.height=w,h end
function methods:SetPoint(point,relative,relativePoint,x,y) self.anchor={point,relative,relativePoint,x,y} end
function methods:GetPoint() if rawget(self,"anchor") then return unpack(self.anchor) end end
function methods:ClearAllPoints() self.anchor=nil end
function methods:SetFrameStrata(s) self.strata=s end
function methods:SetScale(v) self.scale=v end
function methods:SetFont(file,size) self.font,self.fontSize=file,size end
function methods:SetText(v) self.text=tostring(v) end
function methods:GetText() return self.text end
function methods:SetAutoFocus(value) self.autoFocus=value end
function methods:SetMaxLetters(value) self.maxLetters=value end
function methods:SetTextInsets() end
function methods:SetFocus() self.focused=true;keyboardFocus=self end
function methods:ClearFocus() self.focused=false;if keyboardFocus==self then keyboardFocus=nil end end
function methods:GetParent() return rawget(self,"parent") end
function methods:IsForbidden() return rawget(self,"forbidden")==true end
function methods:EnableKeyboard(value) assert(not combat,"Keyboard enable called in combat");self.keyboardEnabled=value end
function methods:SetPropagateKeyboardInput(value) assert(not combat,"Propagation called in combat");self.propagate=value end
function methods:HighlightText() end
function methods:SetTextColor(...) self.color={...} end
function methods:SetColorTexture(...) self.color={...};self.file=nil end
function methods:SetTexture(file) self.file=file;self.color=nil end
function methods:SetDrawLayer(layer,sublevel) self.layer=layer;self.sublevel=sublevel or 0 end
function methods:SetTexCoord(...) self.coords={...} end
function methods:SetAlpha(alpha) self.alpha=alpha end
function methods:SetJustifyH(align) self.align=align end
function methods:SetEnabled(value) self.enabled=value end
function methods:IsEnabled() return rawget(self,"enabled")~=false end
function methods:SetScript(name,fn) self.scripts[name]=fn end
function methods:RegisterEvent(name) self.events[name]=true end
function methods:UnregisterEvent(name) self.events[name]=nil end
function methods:Hide()
    if not self.shown then return end;self.shown=false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:Show() self.shown=true end
function methods:IsShown() return self.shown end
local function object(kind,name,parent,layer)
    local o=setmetatable({kind=kind,name=name,parent=parent,layer=layer,shown=true,scripts={},events={},alpha=1,
        id=#objects+1,frameLevel=parent and (parent.frameLevel or 0)+1 or 0}, {__index=function(_,key)
        assert(methods[key],"Unmocked UI method: "..key);return methods[key]
    end})
    objects[#objects+1]=o;if name then _G[name]=o end;return o
end
function CreateFrame(kind,name,parent) local o=object(kind,name,parent);frames[#frames+1]=o;return o end
function methods:CreateTexture(_,layer,template,sublevel)
    local t=object("Texture",nil,self,layer);t.frameLevel=self.frameLevel;t.sublevel=sublevel or 0;return t
end
function methods:CreateFontString(_,layer) local t=object("FontString",nil,self,layer);t.frameLevel=self.frameLevel;return t end
UIParent=object("Frame","UIParent");UIParent:SetSize(1920,1080)
UISpecialFrames={};SlashCmdList={};tinsert=table.insert
local taxi=false;function UnitOnTaxi(unit) assert(unit=="player");return taxi end
local chat={};DEFAULT_CHAT_FRAME={AddMessage=function(_,s) chat[#chat+1]=s end}
local sounds,stopped={},{}
function PlaySoundFile(path,channel)
    assert(channel=="SFX");sounds[#sounds+1]=path;return true,#sounds
end
function StopSound(handle) stopped[#stopped+1]=handle end
local F={}
for _,n in ipairs({"Data","Game","Adventure","Campaign","Trainer","DungeonMap","Duel","Social","MapArt","Audio","UI","Console","CombatFX","AdventureUI","DungeonUI","ExplorerUI","Keyboard","SocialClient","SocialUI","InviteUI","Flightbound"}) do assert(loadfile("Flightbound/"..n..".lua"))("Flightbound",F) end
local G,U=F.Game,F.UI
local function fixtureBattle(id,level)
    G.db.battle=nil;G.db.totalWins=math.max(1,G.db.totalWins)
    assert(G.Encounter(false,{id=id,level=level,kind="wild"}))
end
local function event(name,arg)
    for _,f in ipairs(frames) do if f.events[name] then f.scripts.OnEvent(f,name,arg) end end
end
local function poll() F.events.scripts.OnUpdate(F.events,.8) end
local function click(b) assert(b:IsShown(),"Cannot click a hidden control");assert(b:IsEnabled());assert(b.scripts.OnClick);b.scripts.OnClick(b) end
local function press(value)
    for _,b in ipairs(U.pools.button) do if b.shown and b.label.text==U.Title(value) then click(b);return end end
    if U.navigation.shown then
        for _,b in ipairs(U.moveButtons) do if b.moveKey==value then click(b);return end end
    end
    error("Missing visible button: "..value)
end
event("ADDON_LOADED","OtherAddon");assert(not FlightboundDB)
event("ADDON_LOADED","Flightbound");event("PLAYER_LOGIN");assert(not U.frame)
-- Fear/other control loss does not open the minigame.
event("PLAYER_CONTROL_LOST");assert(not U.frame)
-- Delayed taxi state is detected by the poll; closing during a flight stays closed.
taxi=true;poll();assert(U.frame:IsShown() and F.autoOpened)
U.frame:Hide();poll();assert(not U.frame:IsShown());taxi=false;poll();taxi=true;poll()
assert(U.frame:IsShown());taxi=false;poll();assert(not U.frame:IsShown())
-- A manually opened game remains visible when the flight ends.
SlashCmdList.FLIGHTBOUND("");assert(U.frame:IsShown() and not F.autoOpened)
taxi=true;poll();taxi=false;poll();assert(U.frame:IsShown())
SlashCmdList.FLIGHTBOUND("hide");SlashCmdList.FLIGHTBOUND("auto off");taxi=true;poll();assert(not U.frame:IsShown())
taxi=false;poll();SlashCmdList.FLIGHTBOUND("auto on");taxi=true;poll();assert(U.frame:IsShown());taxi=false;poll()
-- Scale/position parsing and navigation.
SlashCmdList.FLIGHTBOUND("scale 85");assert(G.db.settings.scale==.85)
SlashCmdList.FLIGHTBOUND("scale 999");assert(G.db.settings.scale==1.5)
SlashCmdList.FLIGHTBOUND("scale junk");assert(#chat>0)
SlashCmdList.FLIGHTBOUND("scale 100");SlashCmdList.FLIGHTBOUND("position");assert(U.frame:IsShown())
assert(SLASH_FLIGHTBOUND3=="/fb")
assert(not G.db.trainer);assert(U.trainerBox and not U.trainerBox.focused)
U.trainerBox:SetText("Valette Ashborne");click(U.actions[1]);assert(G.db.trainer and #G.db.pets==0)
click(U.actions[1]);assert(#G.db.pets==1);click(U.actions[1]);assert(G.db.dungeon)
assert(U.wide and U.canvas.scale==1 and U.navigation.shown)
assert(U.MapZoom()==40)
local savedRun=G.db.dungeon
click(U.actions[2]);assert(U.page=="chart")
click(U.zoomIn);assert(U.MapZoom()==48 and not U.zoomIn:IsEnabled())
click(U.zoomOut);click(U.zoomOut);assert(U.MapZoom()==32 and not U.zoomOut:IsEnabled())
G.Init(G.db);U.Render();assert(U.MapZoom()==32 and G.db.dungeon==savedRun,"Zoom preserves and reloads with progress")
click(U.zoomIn);assert(U.MapZoom()==40)
click(U.actions[1]);assert(U.page==nil)
local r=G.db.dungeon;local x,y=r.x,r.y
for i=1,30 do U.Animate(.2) end
assert(r.x==x and r.y==y,"Map must not walk automatically")
press(">");assert(r.x==x+1 and r.y==y)
-- The tile hit areas stay registered to the enlarged sprites.
local trainer
for _,t in ipairs(U.pools.sprite) do
    if t.shown and t.file==F.path.."Art\\"..G.TrainerArt()..".tga" then trainer=t end
end
assert(trainer and trainer.width==42,"Map avatar must be larger than the old 18-unit sprite")
local clicked=false
for _,b in ipairs(U.pools.button) do
    if b.shown and b.label.text=="" and b.anchor[4]==trainer.anchor[4]+1-40 and b.anchor[5]==trainer.anchor[5]-2 then
        click(b);clicked=true;break
    end
end
assert(clicked and r.x==x and r.y==y,"Clicking the tile beside the trainer moves to that tile")
-- Keyboard capture is an opt-in focus lease, never a rewritten WoW binding.
local function mouseDown(frame,underneath)
    mouseFoci={frame,underneath};event("GLOBAL_MOUSE_DOWN","LeftButton")
end
local function key(phase,value)
    physicalKeys[value]=phase=="OnKeyDown"
    if not U.frame.shown or not U.keyboard.shown or not U.keyboard.keyboardEnabled then return true end
    U.keyboard.scripts[phase](U.keyboard,value)
    return U.keyboard.propagate -- true means this event would reach WoW.
end
assert(not G.db.settings.keyboard);mouseDown(U.frame);assert(not U.keyboardFocused)
click(U.keysToggle);assert(U.keyboardFocused and G.db.settings.keyboard)
for _,move in ipairs({{"UP",0,-1},{"DOWN",0,1},{"LEFT",-1,0},{"RIGHT",1,0}}) do
    local beforeX,beforeY=r.x,r.y
    assert(not key("OnKeyDown",move[1]),"Arrow leaked to WoW")
    assert(r.x==beforeX+move[2] and r.y==beforeY+move[3])
    assert(not key("OnKeyDown",move[1]) and r.x==beforeX+move[2] and r.y==beforeY+move[3],"Repeat leaked or took another step")
    assert(not key("OnKeyUp",move[1]),"Owned arrow release leaked")
end
assert(key("OnKeyDown","W") and key("OnKeyDown","ENTER"),"Unrelated WoW controls must propagate")
mouseFoci={UIParent};U.CheckKeyboardFocus();assert(U.keyboardFocused,"Hovering away must not steal click focus")
mouseDown(UIParent);assert(not U.keyboardFocused and not U.keyboard.shown)
physicalKeys.UP=true;mouseDown(U.frame);assert(not U.keyboardFocused,"Do not steal a WoW movement key already being held")
physicalKeys.UP=nil
mouseDown(U.moveButtons[1]);assert(U.keyboardFocused,"Child controls should focus the minigame")
local overlay=CreateFrame("Frame",nil,UIParent)
mouseDown(overlay,U.frame);assert(not U.keyboardFocused,"An overlapping dialog must win mouse focus")
mouseDown(U.frame);assert(not key("OnKeyDown","ESCAPE") and not U.keyboardFocused and U.frame.shown)
local edit=CreateFrame("EditBox",nil,UIParent)
mouseDown(U.frame);edit:SetFocus();assert(key("OnKeyDown","UP") and not U.keyboardFocused,"Chat arrows must not move the dungeon")
assert(key("OnKeyUp","UP"))
edit:ClearFocus();U.CheckKeyboardFocus();assert(not U.keyboardFocused,"Finishing chat must not silently recapture keys")
mouseDown(U.frame);edit:SetFocus();U.keyboardWatch.scripts.OnUpdate();assert(not U.keyboard.shown);edit:ClearFocus()
mouseDown(U.frame);combat=true;event("PLAYER_REGEN_DISABLED")
assert(not U.keyboard.shown and not U.keyboardFocused);mouseDown(U.frame);assert(not U.keyboardFocused)
combat=false;event("PLAYER_REGEN_ENABLED");assert(not U.keyboardFocused)
mouseDown(U.frame);assert(U.keyboardFocused);U.frame:Hide();assert(not U.keyboard.shown)
U.Open(true);assert(not U.keyboardFocused);mouseDown(U.frame)
SlashCmdList.FLIGHTBOUND("keys off");assert(not U.keyboardFocused and not U.keyboard.shown)
SlashCmdList.FLIGHTBOUND("keys on");assert(G.db.settings.keyboard and not U.keyboardFocused)
G.Init(G.db);assert(G.db.settings.keyboard);mouseDown(U.frame);assert(U.keyboardFocused)
assert(not key("OnKeyDown","RIGHT"));local heldX=r.x
SlashCmdList.FLIGHTBOUND("keys off");assert(not U.keyboardFocused and U.keyboard.shown)
assert(not key("OnKeyDown","RIGHT") and r.x==heldX,"Toggle-off must drain the held press")
physicalKeys.RIGHT=nil;U.CheckKeyboardFocus();assert(not U.keyboard.shown,"Recover from a missed key-up")
SlashCmdList.FLIGHTBOUND("keys on");mouseDown(U.frame)
assert(not key("OnKeyDown","LEFT") and not key("OnKeyUp","LEFT"));assert(r.x==x and r.y==y)
click(U.actions[2]);assert(U.page=="chart" and U.wide and not U.navigation.shown);click(U.actions[1]);assert(U.page==nil)
assert(U.keyboardFocused and U.keyboard.shown,"Bottom controls and chart navigation must retain window focus")
assert(U.keysHint.text:upper():find("SPACE: INTERACT",1,true))
-- Space interacts once, never leaks a jump or repeats the chest reward.
r.x,r.y=3,13;G.RevealDungeon();U.Render();local gold=G.db.coins
assert(not key("OnKeyDown","SPACE") and r.used["3:13"] and G.db.coins>gold)
gold=G.db.coins;assert(not key("OnKeyDown","SPACE") and G.db.coins==gold)
assert(not key("OnKeyUp","SPACE"));r.x,r.y=x,y;U.Render()
mouseDown(U.menuButton);click(U.menuButton);assert(U.page=="menu" and U.keyboardFocused)
local menuX,menuY=r.x,r.y
assert(not key("OnKeyDown","RIGHT") and not key("OnKeyUp","RIGHT"))
assert(not key("OnKeyDown","SPACE") and not key("OnKeyUp","SPACE"))
assert(r.x==menuX and r.y==menuY and G.db.dungeon==r,"Menus capture movement without operating the dungeon")
click(U.actions[1]);assert(U.page==nil and U.keyboardFocused)
click(U.actions[3]);assert(U.page=="team" and not U.wide and U.canvas.scale==1.65 and not U.navigation.shown);press("NAME");assert(U.nameBox.focused)
U.nameBox:SetText("Pebbles");U.nameBox.scripts.OnEnterPressed(U.nameBox)
assert(G.Active().nickname=="Pebbles" and not U.nameBox.focused)
click(U.actions[3]);x,y=r.x,r.y;SlashCmdList.FLIGHTBOUND("hide");SlashCmdList.FLIGHTBOUND("show")
assert(r.x==x and r.y==y)
G.Init(G.db);assert(G.db.dungeon.x==x and G.db.dungeon.y==y)
-- Contact an enemy and verify returning from combat stays at that map coordinate.
r=G.db.dungeon;r.x,r.y=6,3;U.Render();mouseDown(U.frame)
assert(not key("OnKeyDown","RIGHT"));assert(G.db.battle and not U.wide and not U.navigation.shown)
assert(U.keyboardFocused and U.keyboard.shown,"Battle transition must retain window focus")
assert(not key("OnKeyDown","RIGHT"),"Held arrow leaked on battle transition")
assert(not key("OnKeyUp","RIGHT") and U.keyboard.shown)
G.db.battle.enemy.hp=1;assert(U.Turn("charm"));U.Animate(.2);assert(U.particles[1]:IsShown())
local caughtId=G.db.pendingName;assert(caughtId and U.renameNew and U.nameBox.focused)
assert(not G.Continue(),"Naming choice must come before continuing the battle")
U.frame:Hide();assert(not U.effect);G.Init(G.db);U.Open(true)
assert(G.db.pendingName==caughtId and U.nameBox.focused,"Unanswered naming prompt survives reload/reopen")
U.nameBox:SetText("Nibble");mouseDown(U.actions[1]);click(U.actions[1])
assert(G.FindPet(caughtId).nickname=="Nibble" and not G.db.pendingName and U.keyboardFocused)
click(U.actions[1]);assert(not G.db.battle)
assert(r.x==7 and r.y==3 and r.used["7:3"])
-- Camp departure/resume preserves exploration; name fields release focus on hide.
U.page="menu";U.Render();press("TRAINER");local originalRace=G.db.trainer.race
U.trainerDraft.race="orc";U.trainerDraft.class="WARRIOR";click(U.actions[4]);assert(G.db.trainer.race==originalRace)
U.page="menu";U.Render();press("TRAINER");U.trainerBox:SetFocus();U.frame:Hide();assert(not U.trainerBox.focused)
U.Open(true);click(U.actions[1]);assert(G.db.trainer.name=="Valette Ashborne")
U.page="menu";U.Render();click(U.actions[2]);assert(not G.db.dungeon)
click(U.actions[1]);assert(G.db.dungeon.used["7:3"])
U.page="settings";U.Render();local reused=U.pools.button[1];reused.scripts.OnEnter(reused);reused.scripts.OnLeave(reused);assert(reused.fill.alpha==1)
press("SOUND: ON");local count=#sounds;F.Audio.Play("victory");assert(#sounds==count)
press("SOUND: OFF");assert(G.db.settings.sound==true)
U.frame:Hide();count=#sounds;F.Audio.Play("victory");assert(#sounds==count);U.Open(true);assert(#stopped>0)
event("PLAYER_LOGOUT");assert(G.db.settings.position)
U.page=nil;U.destination=nil;U.effect=nil

-- Battle numbers invoke the visible buttons, never a WoW action or an old
-- callback from another screen. Holding a key cannot take extra turns.
G.Init(nil,function(a,b) return b and a or 1 end)
G.SetTrainer({name="Valette Ashborne",race="human",class="WARRIOR",gender=2});G.Start("murloc")
G.db.scene=nil;G.db.evolutions={};G.db.totalWins=10;G.Active().level=20;G.Active().hp=G.MaxHP(G.Active())
fixtureBattle("boar",1);G.db.battle.enemy.hp=1000;G.db.battle.enemy.maxHP=1000
U.Render();U.SetKeyboard(true,true);mouseDown(U.actions[1])
local b=G.db.battle
assert(U.actions[2].label.text==G.Spec(G.Active()).move)
assert(U.actions[3].label.text==F.defensiveMoves.murloc and U.keysHint.text:upper():find("NUMBER KEYS",1,true))
local function tap(number)
    assert(not key("OnKeyDown",number),"Battle key leaked to WoW: "..number)
    assert(not key("OnKeyUp",number),"Battle key release leaked: "..number)
    U.Animate(1)
end
assert(not key("OnKeyDown","1") and b.turn==1);U.Animate(1)
assert(not key("OnKeyDown","1") and b.turn==1,"Held number repeated after animation")
assert(not key("OnKeyUp","1"));tap("2");assert(b.turn==2 and b.cooldown==2)
tap("2");assert(b.turn==2 and b.cooldown==2,"Cooldown key must not spend a turn")
tap("3");assert(b.turn==3 and b.defenseCooldown==2 and not U.actions[3]:IsEnabled())
tap("3");assert(b.turn==3 and b.defenseCooldown==2)
tap("4");assert(U.page=="bag" and U.actions[1].label.text:lower():find("salve",1,true))
tap("4");assert(U.page==nil and b.turn==3,"Browsing bag must not tick cooldowns")
mouseDown(U.actions[4]);click(U.actions[4]);assert(U.page=="bag" and U.keyboardFocused)
G.Active().hp=50;local salves=G.db.salves;tap("1")
assert(G.db.salves==salves-1 and b.turn==4 and b.defenseCooldown==1 and U.page==nil)
tap("6");assert(b.focus and b.turn==5 and b.defenseCooldown==0)
tap("6");assert(b.turn==5,"Disabled Focus must not take a turn")
assert(not key("OnKeyDown","NUMPAD3") and b.defenseCooldown==2 and b.turn==6)
assert(not key("OnKeyUp","NUMPAD3"));assert(not key("OnKeyDown","1") and b.turn==6,"Animation must reject rapid input")
assert(not key("OnKeyUp","1"));U.Animate(.2);assert(U.fxSprites[5].shown,"Defense has a visible effect")
U.Animate(1);tap("NUMPAD1");assert(b.turn==7)
for _,number in ipairs({"0","7","8","9"}) do tap(number);assert(b.turn==7,"Unassigned numbers must not activate a move") end
-- Modal menus, text entry, combat lockout and presses begun in WoW still win.
U.page="help";U.Render();tap("2");assert(b.turn==7 and not next(U.battleHotkeys))
U.page=nil;U.Render();mouseDown(UIParent);assert(key("OnKeyDown","1"));mouseDown(U.frame)
assert(not U.keyboardFocused,"Do not steal an already-held WoW action key")
assert(key("OnKeyUp","1"));mouseDown(U.frame);assert(U.keyboardFocused)
edit:SetFocus();U.CheckKeyboardFocus();assert(key("OnKeyDown","2") and key("OnKeyUp","2") and b.turn==7)
edit:ClearFocus();mouseDown(U.frame);combat=true;event("PLAYER_REGEN_DISABLED")
assert(key("OnKeyDown","3") and key("OnKeyUp","3") and b.turn==7)
combat=false;event("PLAYER_REGEN_ENABLED");mouseDown(U.frame)
G.db.battle.enemy.hp=1;U.Render();assert(not key("OnKeyDown","5"))
assert(G.db.pendingName=="boar" and U.nameBox.focused,"Number-key tame opens name prompt")
key("OnKeyUp","5");assert(key("OnKeyDown","1") and key("OnKeyUp","1"),"Names must accept digits")
U.nameBox:SetText("Buddy12");mouseDown(U.actions[1]);click(U.actions[1]);U.Animate(2)
assert(G.Name(G.FindPet("boar"))=="Buddy12" and U.keyboardFocused)
tap("1");assert(G.db.battle and G.db.battle.result=="caught","Old Strike key must not dismiss results")
tap("SPACE");assert(not G.db.battle,"Space must continue a completed tame after naming")
U.ReleaseKeyboard(true);U.effect=nil;U.page=nil

-- Inspect the exact layout recorded from UI.lua, with the bundled font/sprites.
local function raw(o,k) return rawget(o,k) end
local function json(v)
    if type(v)=="string" then return '"'..v:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n')..'"' end
    if type(v)=="number" or type(v)=="boolean" then return tostring(v) end
    if type(v)=="table" then
        local t={};if #v>0 then for _,x in ipairs(v) do t[#t+1]=json(x) end;return '['..table.concat(t,',')..']' end
        for k,x in pairs(v) do t[#t+1]=json(k)..':'..json(x) end;return '{'..table.concat(t,',')..'}'
    end
    return 'null'
end
local previewRoot
local function visible(o)
    if o==(previewRoot or U.frame) then return o.shown end
    return o.shown and raw(o,"parent") and visible(o.parent)
end
local function scale(o)
    if o==(previewRoot or U.frame) then return 1 end -- Exports use addon UI units, independent of WoW's global scale.
    return (raw(o,"scale") or 1)*scale(o.parent)
end
local function bounds(o)
    if o==(previewRoot or U.frame) then return 0,0,o.width,o.height end
    local a=raw(o,"anchor");local x,y=bounds(o.parent)
    assert(a and a[1]=="TOPLEFT" and a[3]=="TOPLEFT","Unexpected preview anchor")
    local s=scale(o)
    return x+a[4]*s,y-a[5]*s,raw(o,"width")*s,raw(o,"height")*s
end
local function opacity(o)
    if o==(previewRoot or U.frame) then return o.alpha end
    return o.alpha*opacity(o.parent)
end
local function snapshot(name,root)
    if not root then U.Render() end;previewRoot=root;root=root or U.frame;local scene={}
    for _,o in ipairs(objects) do
        if (o.kind=="Texture" or o.kind=="FontString" or o.kind=="EditBox") and visible(o) then
            local x,y,w,h=bounds(o)
            assert(x>=0 and y>=0 and x+w<=root.width+.1 and y+h<=root.height+.1,"Element outside preview frame")
            scene[#scene+1]={id=o.id,kind=o.kind,x=x,y=y,width=w,height=h,layer=o.kind=="EditBox" and "OVERLAY" or o.layer,frameLevel=o.frameLevel,sublevel=raw(o,"sublevel") or 0,
                text=raw(o,"text"),color=raw(o,"color"),file=raw(o,"file"),font=raw(o,"font"),fontSize=raw(o,"fontSize") and o.fontSize*scale(o),scale=scale(o),
                align=raw(o,"align"),coords=raw(o,"coords"),alpha=opacity(o)}
        end
    end
    local f=assert(io.open("/tmp/flightbound-"..name..".json","w"));f:write(json({width=root.width,height=root.height,items=scene}));f:close();previewRoot=nil
end
if arg[1]=="--showcase" then
    assert(loadfile("tools/export_flightbound_showcase.lua"))(F,G,U,snapshot,json,function(value) taxi=value;F.CheckFlight() end)
    return
end
if arg[1]=="--combat-preview" or arg[1]=="--impact-preview" then
    assert(loadfile("tools/export_flightbound_combat.lua"))(F,G,U,snapshot,json,arg[1]=="--impact-preview" and "impact" or "combat")
    return
end
G.Init(nil);U.page=nil;U.trainerDraft=nil;U.trainerBox:SetText("Valette Ashborne");snapshot("creator")
for i,race in ipairs(F.trainerRaces) do
 for gender=1,2 do
  U.trainerDraft={name="Valette Ashborne",race=race.id,class=race.classes[#race.classes],gender=gender}
  U.trainerBox:SetText("Valette Ashborne");snapshot("trainer-"..i.."-"..gender)
 end
end
G.SetTrainer({name="Valette Ashborne",race="human",class="WARRIOR",gender=2});U.page=nil;snapshot("starter")
G.Start("murloc");snapshot("entrance");G.StartDungeon();snapshot("dungeon")
U.SetKeyboard(true,true);snapshot("keys-active")
mouseDown(UIParent);snapshot("keys-ready")
combat=true;event("PLAYER_REGEN_DISABLED");snapshot("keys-combat");combat=false;event("PLAYER_REGEN_ENABLED")
edit:SetFocus();snapshot("keys-typing");edit:ClearFocus()
physicalKeys.UP=true;snapshot("keys-held");physicalKeys.UP=nil
U.page="menu";snapshot("keys-menu");U.page=nil;U.SetKeyboard(false)
local r=G.db.dungeon
for _,v in ipairs({{1,0},{1,0}}) do G.StepDungeon(v[1],v[2]) end;snapshot("corridor")
G.StepDungeon(1,0);snapshot("battle");G.db.battle.enemy.hp=1;U.Turn("charm");snapshot("tame-name")
assert(U.renameNew and U.nameBox.focused);U.nameBox:SetText("WWWWWWWWWWWWWWWW");snapshot("tame-name-long")
U.nameBox.scripts.OnEscapePressed(U.nameBox);assert(not G.db.pendingName and G.FindPet("wolf").nickname==nil)
G.Continue();G.db.evolutions={}
snapshot("cleared-path")
G.RetreatDungeon();for _,id in ipairs(F.order) do if not G.Owns(id) then G.db.pets[#G.db.pets+1]=G.NewPet(id,8) end end
U.page="team";U.offset=0;snapshot("team");press("NAME");U.nameBox:SetText("Sir Chomps");snapshot("rename")
U.nameBox.scripts.OnEnterPressed(U.nameBox);assert(G.Active().nickname=="Sir Chomps")
G.Rename(1,"WWWWWWWWWWWWWWWW");snapshot("team-long-name");G.Rename(1,"Sir Chomps")
for _,name in ipairs({"journal","help","menu","shop","awards","story","citadel","arena","settings","ending","dungeons"}) do
 U.page=name;U.offset=0;snapshot(name)
end
for i,id in ipairs(F.order) do U.evoIndex=i;U.page="evolutions";snapshot("forms-"..id) end
U.page=nil
for tier=2,3 do
 G.Active().level=tier==2 and 6 or 14;G.Active().hp=G.MaxHP(G.Active());G.db.evolutions={{id=G.Active().id,tier=tier}}
 snapshot("evolution-"..tier);local m=U.motion[#U.motion];U.Animate(.1);local small=m.texture.width
 U.Animate(1.5);U.Animate(.1);assert(m.texture.width>small);click(U.actions[1]);assert(#G.db.evolutions==0)
end
fixtureBattle("whelp",18);U.page=nil;snapshot("battle-evolved");G.db.battle=nil
-- All 36 special names and 12 defense names fit, including cooldown states.
local savedPets,savedActive=G.db.pets,G.db.active
for _,id in ipairs(F.order) do for tier,level in ipairs({1,6,14}) do
 G.db.pets={G.NewPet(id,level)};G.db.active=1;fixtureBattle("boar",20)
 U.page=nil;snapshot("moves-"..id.."-"..tier)
 assert(U.actions[2].label.text==G.Spec(G.Active()).move and U.actions[3].label.text==F.defensiveMoves[id])
end end
G.db.battle.cooldown=2;G.db.battle.defenseCooldown=1;U.SetKeyboard(true,true);snapshot("battle-cooldowns")
U.page="bag";snapshot("battle-bag");U.page=nil;G.db.battle.defenseCooldown=0
G.Active().hp=G.MaxHP(G.Active());assert(U.Turn("guard"));U.Animate(.2)
local render=U.Render;U.Render=function() end;snapshot("battle-defense");U.Render=render
U.effect=nil;G.db.battle=nil;G.db.pets=savedPets;G.db.active=savedActive;U.SetKeyboard(false)
for zone=1,8 do
 G.db.zone=zone;G.db.dungeon=nil;G.db.dungeonSaves[zone]=nil;G.db.scene=nil;G.db.showChapter=true;U.page=nil
 snapshot("entrance-"..zone);G.StartDungeon();snapshot("map-"..zone)
 r=G.db.dungeon
 for y,row in ipairs(G.DungeonLayout(zone).rows) do for x=1,#row do r.explored[G.PointKey(x,y)]=true end end
 U.page="chart";snapshot("chart-"..zone);U.page=nil
 r.x,r.y=G.DungeonLayout(zone).transform(18,7);snapshot("theme-objects-"..zone)
 local cx,cy=G.DungeonLayout(zone).transform(18,8);r.used[G.PointKey(cx,cy)]=true
 snapshot("theme-looted-"..zone)
 G.db.dungeon=nil;G.db.badges[zone]=true;G.db.scene={title="DUNGEON CLEARED!",text=F.dungeons[zone].ending,kind="clear"};snapshot("complete-"..zone)
end
G.db.scene=nil;G.db.zone=1;G.db.dungeonSaves[1]=nil;G.StartDungeon();r=G.db.dungeon
r.x,r.y=14,13;r.keys=1;r.faceX,r.faceY=1,0;G.RevealDungeon();U.page=nil;snapshot("locked-door")
G.InteractDungeon();G.StepDungeon(1,0);snapshot("unlocked-door")
r.x,r.y=4,8;G.RevealDungeon();snapshot("plate-detail")
local plateCount=0
for _,t in ipairs(U.pools.rect) do if t.shown and t.layer=="BORDER" and t.color[4]<.3 then plateCount=plateCount+1 end end
assert(plateCount==4,"Plate should be just four faint seams")
for _,t in ipairs(U.pools.sprite) do if t.shown then assert(not t.file:find("d_trap",1,true),"No bright trap icon") end end
r.used["5:8"]=true;snapshot("plate-spent")
-- Keep the avatar visible and clickable near all four map corners at every zoom.
for _,size in ipairs({32,40,48}) do
 G.db.settings.mapZoom=size
 for i,pos in ipairs({{4,3},{18,3},{4,13},{18,13}}) do
  r.x,r.y=pos[1],pos[2];G.RevealDungeon();U.Render()
  local found=false
  for _,t in ipairs(U.pools.sprite) do
   if t.shown and t.file==F.path.."Art\\"..G.TrainerArt()..".tga" then
    local x,y=t.anchor[4],-t.anchor[5]
    assert(x>=-1 and x+t.width<=521 and y>=42 and y+t.height<=405,"Avatar left the map viewport")
    assert(t.width==size+2);found=true
   end
  end
  assert(found,"Avatar missing after camera/zoom change")
  if i==1 and size~=40 then snapshot("zoom-"..size) end
  if size==40 and i>2 then snapshot("map-edge-"..i) end
 end
end
G.db.settings.mapZoom=40
-- Each battle keeps its encounter's theme through reload, results and menus;
-- the active zone selector must not redirect an already-running encounter.
local themeIds={"elwynn","westfall","darkshore","ashenvale","ungoro","blackrock","winterspring","silithus"}
local function battleBackdrop(expected)
    local found=0
    for _,t in ipairs(U.pools.sprite) do
        if t.shown and t.file:find("Art\\Battles\\",1,true) then
            assert(t.file==F.path.."Art\\Battles\\"..expected..".tga")
            assert(t.layer=="BACKGROUND" and t.sublevel==-6);found=found+1
        end
    end
    assert(found==1,"Exactly one correctly layered backdrop per battle")
end
G.db.dungeon=nil;G.db.scene=nil;G.db.evolutions={};U.page=nil
for zone,id in ipairs(themeIds) do
 G.db.zone=zone;G.Active().hp=G.MaxHP(G.Active());fixtureBattle(F.zones[zone].boss,F.zones[zone].level+2)
 snapshot("battle-theme-"..zone);battleBackdrop(id)
 G.db.zone=zone==1 and 8 or 1;G.Init(G.db)
 assert(G.BattleTheme().id==id,"Reload must preserve the battle's origin")
 G.db.battle.enemy.hp=0;G.db.battle.result="win"
 snapshot("battle-theme-win-"..zone);battleBackdrop(id)
end
for _,kind in ipairs({"finale","arena"}) do
 fixtureBattle("whelp",28);G.db.battle.kind=kind;G.db.battle.boss=true
 snapshot("battle-theme-"..kind);battleBackdrop("citadel")
end
G.db.zone=7;fixtureBattle("whelp",23);G.Active().hp=1
snapshot("battle-theme-lowhp");battleBackdrop("winterspring")
U.page="help";snapshot("battle-theme-help")
for _,t in ipairs(U.pools.sprite) do assert(not t.shown or not t.file:find("Art\\Battles\\",1,true),"Backdrop leaked onto menu") end
U.page="bag";snapshot("battle-theme-return");battleBackdrop("winterspring")
assert(G.BattleTheme({zone=999}).id=="elwynn")
U.page=nil;G.db.battle=nil
assert(loadfile("tests/flightbound-combat.lua"))(F,G,U,snapshot,json)
-- Space returns to the map without jumping in WoW, repeating or skipping a result.
U.frame:Hide();G.Init(nil,function(a,b) return b and a or 1 end)
G.SetTrainer(G.PlayerTrainer());G.Start("wolf");G.StartDungeon();G.db.scene=nil;G.db.evolutions={};U.page=nil
G.Encounter(false,{id="murloc",level=3,kind="wild",dungeonKey="7:3"});G.db.battle.enemy.hp=1
U.Open(true);U.SetKeyboard(true,true);assert(U.Turn("strike"))
assert(not key("OnKeyDown","SPACE") and G.db.battle,"Space during impact must not skip the result")
U.Animate(1);assert(U.actions[1].label.text=="Back To Map")
assert(U.keysHint.text:upper():find("SPACE: BACK TO MAP",1,true));snapshot("battle-result-keys")
assert(not key("OnKeyDown","SPACE") and G.db.battle,"Holding Space across the result must not continue")
assert(not key("OnKeyUp","SPACE"))
U.page="help";U.Render();tap("SPACE");assert(G.db.battle,"Space on help must not dismiss a hidden result")
U.page=nil;U.Render();mouseDown(UIParent);assert(key("OnKeyDown","SPACE") and G.db.battle)
assert(key("OnKeyUp","SPACE"));mouseDown(U.frame)
local interact=G.InteractDungeon;local interactions=0;G.InteractDungeon=function() interactions=interactions+1;return false end
assert(not key("OnKeyDown","SPACE") and not G.db.battle and G.db.dungeon.used["7:3"])
assert(not key("OnKeyDown","SPACE") and interactions==0,"Result press must not interact again on the map")
assert(not key("OnKeyUp","SPACE"));G.InteractDungeon=interact;U.ReleaseKeyboard(true)
print("Result keyboard: Space continues only the visible result, requires a fresh press and respects focus.")
-- Continued keyboard flow through story/evolution/clear screens and team swaps.
U.frame:Hide();G.Init(nil,function(a,b) return b and a or 1 end)
G.SetTrainer(G.PlayerTrainer());G.Start("wolf");U.page=nil;U.Open(true);U.SetKeyboard(true,true)
assert(U.PageContinueAvailable());tap("SPACE");assert(G.db.dungeon)
G.db.evolutions={{id="wolf",tier=2}};U.page=nil;U.Render()
assert(U.PageContinueAvailable());assert(not key("OnKeyDown","SPACE"));assert(#G.db.evolutions==0)
local moves=G.db.dungeon.steps;assert(not key("OnKeyDown","SPACE") and G.db.dungeon.steps==moves)
assert(not key("OnKeyUp","SPACE"))
G.db.scene={kind="camp",title="Rested",text="Ready to explore."};U.Render();tap("SPACE");assert(not G.db.scene)
G.db.pets[2]=G.NewPet("murloc",8);G.Active().hp=G.MaxHP(G.Active())
fixtureBattle("boar",3);G.db.battle.enemy.hp=500;G.db.battle.enemy.maxHP=500;U.page="team";U.Render()
assert(U.rowHotkeys["2"] and U.rowHotkeys["2"]:IsEnabled());tap("2")
assert(G.db.active==2 and G.db.battle.turn==1 and U.keyboardFocused,"Number key swaps and spends one turn")
U.Animate(2);U.page="team";U.Render();tap("0");assert(U.page==nil and G.db.battle.turn==1)
assert(not U.objective:GetText():find("Next:",1,true),"Battle header must not announce the enemy's next move")
-- Taxi auto-open with a pending nickname must never steal the chat edit focus.
U.frame:Hide();G.db.battle=nil;G.db.pendingName="murloc";U.pendingNameSeen=nil;U.page=nil
edit:SetFocus();U.Open(false);assert(GetCurrentKeyBoardFocus()==edit and not U.nameBox.focused)
U.frame:Hide();edit:ClearFocus();U.Open(true);assert(U.nameBox.focused)
U.EndRename(false);U.ReleaseKeyboard(true)
print("Console controls: Space advances story/evolution/scenes, keyboard swaps, hidden enemy moves and quiet automatic open passed.")
assert(loadfile("tests/flightbound-social-ui.lua"))(F,G,U,snapshot,json,key,mouseDown)
if arg[1]=="--animation" then
 G.Init(nil,function(a,b) return b and a or 1 end);G.SetTrainer(G.PlayerTrainer());G.Start("murloc")
 fixtureBattle("whelp",4);U.page=nil;U.clock=0;U.Render()
 for i=1,60 do
  if i==10 then U.Turn("strike") end
  if i==25 then U.Turn("special") end
  if i==40 then U.Turn("charm") end
  U.Animate(1/12);local render=U.Render;U.Render=function() end
  snapshot(string.format("anim-%02d",i));U.Render=render
 end
end
print("Flightbound 4.9 UI: Adventure Console, social screens, friendly duels, critical feedback, animated battles, nine themes, menus, input guards and lifecycle checks passed.")
