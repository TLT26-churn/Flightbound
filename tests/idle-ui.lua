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
function methods:GetText()
    -- WoW returns nil for an empty FontString; EditBox text remains a string.
    -- Treating every empty label as "" hid the 4.9.0 console startup crash.
    if self.kind=="FontString" and self.text=="" then return nil end
    return self.text
end
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
    assert(channel=="Master");sounds[#sounds+1]=path;return true,#sounds
end
function StopSound(handle) stopped[#stopped+1]=handle end

local clock=1000
function time() return clock end
function GetTime() return clock end
function methods:GetScale() return rawget(self,"scale") or 1 end
function methods:GetCenter()
 if self==UIParent then return 960,540 end
 local a=rawget(self,"anchor")
 return 960/self:GetScale()+(a and a[4] or 0),540/self:GetScale()+(a and a[5] or 0)
end

local F={}
FlightboundDB={legacy="untouched",pets={{id="wolf",level=28}}};FlightboundBackupDB={keep=true};FlightboundSocialDB={keep=true}
FlightboundCampDB={schema=1,resources={wood=999}}
FlightboundIdleDB={schema=1,resetToken="old-build",gold=555}
for _,name in ipairs({"Data","IdleGame","IdleAudio","IdleUI","IdleMain"}) do assert(loadfile("Flightbound/"..name..".lua"))("Flightbound",F) end
local G,U=F.Idle,F.IdleUI
local function event(name,arg)
 for _,f in ipairs(frames) do if f.events[name] then f.scripts.OnEvent(f,name,arg) end end
end
local function tick(dt) clock=clock+dt;F.events.scripts.OnUpdate(F.events,dt) end
local function press(value)
 for _,b in ipairs(U.pool.button) do if b.shown and b.label.text==value then assert(b:IsEnabled(),value);b.scripts.OnClick(b);return end end
 error("Missing button "..value)
end
local function attack() U.target.scripts.OnClick(U.target) end
local raw=rawget
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
    local f=assert(io.open("/tmp/flightbound-idle-"..name..".json","w"));f:write(json({width=root.width,height=root.height,items=scene}));f:close();previewRoot=nil
end

event("ADDON_LOADED","Else");assert(not G.db)
event("ADDON_LOADED","Flightbound");assert(G.db.gold==0 and G.db.totalTaps==0 and G.db.settings.sound)
assert(FlightboundIdleBackupDB.gold==555 and FlightboundDB.legacy=="untouched" and FlightboundCampDB.resources.wood==999)
assert(not U.frame);SlashCmdList.FLIGHTBOUND("");assert(U.frame:IsShown());snapshot("start")
assert(#sounds>0,"Fresh save must play sound on opening")
local hp=G.db.enemy.hp;attack();assert(G.db.enemy.hp<hp and G.db.totalTaps==1)
tick(.08);snapshot("click-impact")
local x=U.enemy.anchor[4];tick(.07);assert(x~=U.enemy.anchor[4],"Hit feedback must move the enemy")
press("Sound: On");local before=#sounds;tick(1);attack();assert(#sounds==before,"Mute must stop click sounds")
press("Sound: Off");assert(#sounds>before)
local d=G.db;d.gold=200;U.Render();press("Recruit Wolf · 20 gold");assert(d.pets.wolf==1 and #d.party==1)
U.Render();press("Sharpen blade · 12 gold");assert(d.blade==1)
local taps=d.totalTaps;local money=d.gold
for i=1,300 do tick(.1) end
assert(d.totalTaps==taps and d.kills[1]>0 and d.gold>money,"Visible crew must hunt and collect gold without clicks")
snapshot("first-companion")
U.frame:Hide();local soundCount=#sounds;money=d.gold;tick(100);assert(d.gold>money and #sounds==soundCount)
SlashCmdList.FLIGHTBOUND("show");assert(U.message:find("While away"));snapshot("welcome-back")
d.kills[1]=8;d.gold=1000;d.focus=100;U.Render();press("Challenge Bramblekeeper");assert(d.enemy.boss)
snapshot("first-boss");local armor=d.enemy.armor;attack();assert(d.enemy.armor<armor)
U.Render();press("Power Strike · 100 / 100 Focus");assert(not d.enemy or d.enemy.hp<d.enemy.max)
-- Fixture mid-game, with every pet role available and different forms.
d.cleared={true,true,true,true,true};d.zone=5;d.blade=12;d.gold=45678;d.focus=100
for _,id in ipairs(F.petOrder) do d.pets[id]=id=="wolf" and 25 or 10 end
d.party={"wolf","whelp","wisp"};d.equipped={"fang","banner"};for _,r in ipairs(F.relics) do d.relics[r.id]=true end
G.Spawn(d,false);U.tab="upgrades";U.message=nil;tick(.5);snapshot("adventure")
for _,page in ipairs({"crew","world","loot"}) do U.tab=page;U.worldPage=5;snapshot(page) end
U.tab="crew";U.petPage=2;snapshot("crew-page2")
U.tab="world";for z=1,9 do U.worldPage=z;snapshot("world-"..z) end
U.tab="upgrades"
for z=1,9 do d.zone=z;d.kills[z]=100;G.Spawn(d,true);snapshot("boss-"..z) end
-- Representative real animation: no synthetic sprite positions are injected.
d.zone=2;d.blade=5;d.party={"wolf","whelp"};d.pets.wolf=6;d.pets.whelp=3;d.focus=100;G.Spawn(d,false);U.message=nil;U.tab="upgrades"
for i=1,90 do
 tick(1/15)
 if i%5==0 then attack() end
 if i==15 then G.Power(d,F.Now()) end
 snapshot(string.format("anim-%03d",i))
end
-- Dedicated menus pause the encounter, earn away income and do not play combat audio.
U.Go("crew");local menuHP=d.enemy and d.enemy.hp;local menuGold=d.gold;local menuSounds=#sounds
assert(not U.scene:IsShown());tick(10);assert(d.gold>menuGold and #sounds==menuSounds)
assert(not d.enemy or d.enemy.hp==menuHP)
press("< Back to adventure");assert(U.tab=="upgrades" and U.scene:IsShown())
d.enemy.hp=1;tick(1);if d.enemy then d.enemy.hp=1;attack();assert(U.message and U.message:find("gold"),"Manual loot messages must survive the click handler") end
SlashCmdList.FLIGHTBOUND("hide");taxi=true;tick(1);assert(not U.frame:IsShown())
SlashCmdList.FLIGHTBOUND("auto on");taxi=false;tick(1);taxi=true;tick(1);assert(U.frame:IsShown() and F.autoOpened)
U.frame:Hide();tick(1);assert(not U.frame:IsShown());taxi=false;tick(1);taxi=true;tick(1);assert(U.frame:IsShown())
taxi=false;tick(1);assert(not U.frame:IsShown());SlashCmdList.FLIGHTBOUND("show");taxi=true;tick(1);taxi=false;tick(1);assert(U.frame:IsShown())
SlashCmdList.FLIGHTBOUND("scale 999");assert(d.settings.scale==1.3);SlashCmdList.FLIGHTBOUND("scale 90")
U.frame:SetPoint("CENTER",UIParent,"CENTER",123,-45);U.SavePosition();assert(d.settings.position.x==123 and d.settings.position.y==-45)
SlashCmdList.FLIGHTBOUND("position");assert(not d.settings.position)
for _,page in ipairs({"upgrades","crew","world","loot"}) do U.tab=page;U.Render() end
local size=#objects
for i=1,100 do for _,page in ipairs({"upgrades","crew","world","loot"}) do U.tab=page;U.Render();U.Animate() end end
assert(size==#objects,"Frames leaked during repeated rendering")
assert(FlightboundDB.legacy=="untouched" and FlightboundBackupDB.keep and FlightboundSocialDB.keep)
print("PASS UI onboarding, sound/mute, hit motion, real automatic attacks, loot, fresh start, save isolation, controls, pooling and flight lifecycle")
