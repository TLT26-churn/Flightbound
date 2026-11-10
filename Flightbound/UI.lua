local _, F = ...
local G,P = F.Game,F.palette
local U={page=nil,offset=0,starter=1,clock=0,motion={}}
F.UI=U
local FONT=F.path.."Art\\Silkscreen.ttf"
local casing={.22,.25,.28,1};local rim={.39,.42,.44,1};local ink={.88,.88,.78,1}
local function texture(parent,x,y,w,h,color,layer,sublevel)
    local t=parent:CreateTexture(nil,layer or "BACKGROUND",nil,sublevel or 0)
    t:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y);t:SetSize(w,h)
    t:SetColorTexture(unpack(color));return t
end
local function label(parent,x,y,w,h,text,size,color,align)
    local t=parent:CreateFontString(nil,"OVERLAY")
    t:SetFont(FONT,size or 12,"");t:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y);t:SetSize(w,h)
    t:SetJustifyH(align or "LEFT");t:SetJustifyV("TOP");t:SetTextColor(unpack(color or P.dark))
    t:SetWordWrap(true);t:SetText(text);return t
end
local buttonSymbols={["DUNGEON MAP"]="map",["TEAM / BAG"]="bag",["MENU"]="journal",["SETTINGS"]="settings",["FIELD GUIDE"]="journal",["EVOLUTIONS"]="team"}
local function buttonIcon(b,id,only)
    local w,h=b.buttonWidth,b.buttonHeight
    b.label:ClearAllPoints()
    if id then
        local size=math.min(only and 26 or 20,h-4)
        b.icon:ClearAllPoints();b.icon:SetPoint("TOPLEFT",b,"TOPLEFT",only and (w-size)/2 or 4,-(h-size)/2)
        b.icon:SetSize(size,size);b.icon:SetTexture(F.path.."Art\\Symbols\\"..id..".tga","CLAMP","CLAMP","NEAREST");b.icon:Show()
        local left=only and 3 or size+7
        b.label:SetPoint("TOPLEFT",b,"TOPLEFT",left,-math.floor((h-12)/2));b.label:SetSize(w-left-3,14)
    else
        b.icon:Hide();b.label:SetPoint("TOPLEFT",b,"TOPLEFT",3,-math.floor((h-12)/2));b.label:SetSize(w-6,14)
    end
end
local function button(parent,x,y,w,h,text,callback,shell)
    local b=CreateFrame("Button",nil,parent)
    b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y);b:SetSize(w,h)
    b.edge=texture(b,0,0,w,h,shell and rim or P.dark)
    b.fill=texture(b,2,2,w-4,h-4,shell and casing or P.light,"BORDER")
    b.label=label(b,3,math.floor((h-12)/2),w-6,14,text,11,shell and ink or P.dark,"CENTER")
    b.buttonWidth,b.buttonHeight=w,h;b.icon=texture(b,0,0,1,1,ink,"ARTWORK");b.icon:Hide()
    buttonIcon(b,buttonSymbols[text])
    b:SetScript("OnClick",function(self)
        if F.Audio then F.Audio.Play("menu") end
        if self.callback then self.callback() end
    end)
    b:SetScript("OnEnter",function(self)
        if self:IsEnabled() then self.fill:SetColorTexture(unpack(shell and {.32,.36,.38,1} or P.soft)) end
    end)
    b:SetScript("OnLeave",function(self) self.fill:SetColorTexture(unpack(shell and casing or P.light)) end)
    b:SetScript("OnMouseDown",function(self) if self:IsEnabled() then self.label:SetAlpha(.6);self.icon:SetAlpha(.6) end end)
    b:SetScript("OnMouseUp",function(self) self.label:SetAlpha(1);self.icon:SetAlpha(1) end)
    b.callback=callback;return b
end
U.Widgets={texture=texture,label=label,button=button}
function U.Build()
    if U.frame then return end
    local w=CreateFrame("Frame","FlightboundFrame",UIParent)
    U.frame=w;w:SetSize(552,624);w:SetFrameStrata("MEDIUM")
    w:SetClampedToScreen(true);w:SetMovable(true);w:EnableMouse(true)
    -- Same-layer texture creation order is not a reliable stacking contract.
    -- Give the nested casing/bezel rectangles distinct, explicit priorities.
    texture(w,0,0,552,624,{.08,.10,.11,1},"BACKGROUND",0)
    texture(w,2,2,548,620,rim,"BACKGROUND",1)
    texture(w,4,4,544,616,casing,"BACKGROUND",2)
    texture(w,10,48,532,476,{.10,.13,.14,1},"BACKGROUND",3)
    texture(w,14,52,524,468,P.dark,"BACKGROUND",4)
    label(w,19,13,270,19,"FLIGHTBOUND",16,ink)
    label(w,19,34,265,12,"AZEROTH POCKET ADVENTURE",9,{.62,.67,.65,1})
    local drag=CreateFrame("Frame",nil,w);drag:SetPoint("TOPLEFT",w,"TOPLEFT",0,0);drag:SetSize(487,48)
    drag:EnableMouse(true);drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart",function() w:StartMoving() end)
    drag:SetScript("OnDragStop",function()
        w:StopMovingOrSizing();U.SavePosition()
    end)
    w:SetScript("OnHide",function()
        U.ReleaseKeyboard(true)
        w:StopMovingOrSizing();U.SavePosition();F.autoOpened=false;U.effect=nil;U.travel=nil
        if U.nameBox then U.nameBox:ClearFocus() end
        if U.trainerBox then U.trainerBox:ClearFocus() end
        if U.particles then for _,t in ipairs(U.particles) do t:Hide() end end
        U.HideCombatFX();U.ClearDamagePops();U.duelQueue={}
        if F.Audio then F.Audio.Stop() end
    end)
    w:SetScript("OnUpdate",function(_,dt) U.Animate(dt) end)
    button(w,518,12,22,23,"X",function() w:Hide() end,true)
    button(w,491,12,22,23,"?",function() U.page="help";U.Render() end,true)
    U.flight=label(w,461,38,73,10,"ON FOOT",8,{.66,.78,.52,1},"RIGHT")
    -- An unscaled host keeps screen origins independent of the content scale.
    U.canvasHost=CreateFrame("Frame",nil,w);U.canvasHost:SetSize(520,464)
    U.canvasHost:SetPoint("TOPLEFT",w,"TOPLEFT",16,-54)
    local canvas=CreateFrame("Frame",nil,U.canvasHost);canvas:SetSize(328,272);canvas:SetPoint("TOPLEFT",U.canvasHost,"TOPLEFT",0,0)
    U.canvas=canvas;U.pools={text={},sprite={},rect={},button={}};U.used={}
    -- Own the LCD fill on the content frame, below every pooled screen region.
    -- Its light background is required for all dark text and HP fills to read.
    U.screenBackground=texture(canvas,0,0,328,272,P.light,"BACKGROUND",-8)
    U.particles={}
    for i=1,8 do
        local t=texture(canvas,0,0,4,4,i%2==0 and P.dark or P.light,"OVERLAY",1)
        t:Hide();U.particles[i]=t
    end
    U.BuildCombatFX()
    U.actions={}
    for i=1,4 do
        U.actions[i]=button(w,16+(i-1)*132,564,124,28,"",nil,true)
        local b=U.actions[i]
        b.key=label(b,5,10,14,16,tostring(i),12,ink,"CENTER");b.key:Hide()
        b.detail=label(b,22,22,98,11,"",8,{.66,.78,.72,1},"CENTER");b.detail:Hide()
    end
    U.battleControls=CreateFrame("Frame",nil,w)
    U.battleControls:SetPoint("TOPLEFT",w,"TOPLEFT",0,-494);U.battleControls:SetSize(552,60)
    U.battleTip=label(U.battleControls,16,6,520,20,"",9,ink,"CENTER")
    U.battleExtras={
        button(U.battleControls,16,34,256,26,"",nil,true),
        button(U.battleControls,280,34,256,26,"",nil,true),
    }
    U.battleControls:Hide()
    U.navigation=CreateFrame("Frame",nil,w);U.navigation:SetPoint("TOPLEFT",w,"TOPLEFT",0,-526);U.navigation:SetSize(552,30)
    label(U.navigation,16,8,54,14,"MOVE",10,ink)
    U.moveButtons={}
    for i,v in ipairs({{"<",-1,0},{"^",0,-1},{"V",0,1},{">",1,0}}) do
        local dx,dy=v[2],v[3]
        U.moveButtons[i]=button(U.navigation,74+(i-1)*50,0,44,28,v[1],function() G.StepDungeon(dx,dy);U.Render() end,true)
        U.moveButtons[i].moveKey=v[1];U.moveButtons[i].label:SetText("")
        buttonIcon(U.moveButtons[i],({"left","up","down","right"})[i],true)
    end
    label(U.navigation,306,8,54,14,"ZOOM",10,ink)
    U.zoomOut=button(U.navigation,366,0,30,28,"-",function() U.SetMapZoom(-1) end,true)
    U.zoomIn=button(U.navigation,402,0,30,28,"+",function() U.SetMapZoom(1) end,true)
    U.zoomLabel=label(U.navigation,444,8,80,14,"",10,ink,"RIGHT")
    label(w,18,598,236,10,"/FB  /FLIGHTBOUND  V4.8.2",8,{.61,.67,.64,1})
    label(w,18,611,236,10,"By Whitebeard Tinkerton - US PVP",7,{.56,.61,.59,1})
    U.keysToggle=button(w,262,600,116,19,"KEYS: OFF",function()
        U.SetKeyboard(not G.db.settings.keyboard,true)
    end,true)
    buttonIcon(U.keysToggle,"keyboard")
    U.keysHint=label(w,300,12,181,27,"",10,{.76,.83,.57,1},"RIGHT")
    U.focusEdges={}
    for _,v in ipairs({{10,48,532,2},{10,522,532,2},{10,50,2,472},{540,50,2,472}}) do
        local t=texture(w,v[1],v[2],v[3],v[4],P.light,"BACKGROUND",5)
        t:Hide();U.focusEdges[#U.focusEdges+1]=t
    end
    U.BuildKeyboard()
    U.auto=button(w,386,600,150,19,"AUTO: ON",function()
        G.db.settings.auto=not G.db.settings.auto
        U.UpdateStatus();F.CheckFlight()
    end,true)
    tinsert(UISpecialFrames,"FlightboundFrame")
    w:Hide();U.ApplyPosition()
end
function U.MapZoom()
    local size=G.db.settings.mapZoom
    return (size==32 or size==40 or size==48) and size or 40
end
function U.SetMapZoom(delta)
    G.db.settings.mapZoom=math.max(32,math.min(48,U.MapZoom()+delta*8));U.Render()
end
function U.Layout(wide,exploring)
    U.wide=wide
    U.canvasHost:ClearAllPoints()
    U.canvasHost:SetPoint("TOPLEFT",U.frame,"TOPLEFT",wide and 16 or 30,wide and -54 or -82)
    U.canvas:SetScale(wide and 1 or 1.5)
    U.canvas:SetSize(wide and 520 or 328,wide and 464 or 272)
    U.screenBackground:SetSize(wide and 520 or 328,wide and 464 or 272)
    if exploring then U.navigation:Show() else U.navigation:Hide() end
    local zoom=U.MapZoom()
    U.zoomOut:SetEnabled(zoom>32);U.zoomOut:SetAlpha(zoom>32 and 1 or .4)
    U.zoomIn:SetEnabled(zoom<48);U.zoomIn:SetAlpha(zoom<48 and 1 or .4)
    U.zoomLabel:SetText(math.floor(zoom/40*100).."%")
end
function U.SavePosition()
    if not G.db or not U.frame then return end
    local point,_,relativePoint,x,y=U.frame:GetPoint(1)
    if point then G.db.settings.position={point=point,relativePoint=relativePoint,x=x,y=y} end
end
function U.ApplyPosition()
    local w=U.frame;w:SetScale(G.db.settings.scale);w:ClearAllPoints()
    local p=G.db.settings.position
    local anchors={TOP=true,TOPLEFT=true,TOPRIGHT=true,LEFT=true,RIGHT=true,CENTER=true,BOTTOM=true,BOTTOMLEFT=true,BOTTOMRIGHT=true}
    if type(p)=="table" and anchors[p.point] and anchors[p.relativePoint] and type(p.x)=="number" and type(p.y)=="number"
        and p.x==p.x and p.y==p.y and math.abs(p.x)<100000 and math.abs(p.y)<100000 then
        w:SetPoint(p.point,UIParent,p.relativePoint,p.x,p.y)
    else w:SetPoint("RIGHT",UIParent,"RIGHT",-40,30) end
end
local function pooled(kind,create)
    U.used[kind]=(U.used[kind] or 0)+1;local n=U.used[kind]
    local p=U.pools[kind]
    if not p[n] then p[n]=create() end
    p[n]:Show();return p[n]
end
local function text(x,y,w,h,value,size,align,color)
    local t=pooled("text",function() return label(U.canvas,0,0,1,1,"",12) end)
    t:ClearAllPoints();t:SetPoint("TOPLEFT",U.canvas,"TOPLEFT",x,-y);t:SetSize(w,h)
    t:SetFont(FONT,size or 11,"");t:SetText(value);t:SetJustifyH(align or "LEFT");t:SetTextColor(unpack(color or P.dark));return t
end
local function rect(x,y,w,h,color,layer)
    local t=pooled("rect",function() return U.canvas:CreateTexture(nil,"BACKGROUND") end)
    t:ClearAllPoints();t:SetPoint("TOPLEFT",U.canvas,"TOPLEFT",x,-y);t:SetSize(w,h)
    t:SetDrawLayer(layer or "BACKGROUND");t:SetColorTexture(unpack(color));return t
end
local function sprite(id,x,y,w,h,flip,dim,role)
    local t=pooled("sprite",function() return U.canvas:CreateTexture(nil,"ARTWORK") end)
    t:ClearAllPoints();t:SetPoint("TOPLEFT",U.canvas,"TOPLEFT",x,-y);t:SetSize(w,h)
    t:SetTexture(F.path.."Art\\"..id..".tga","CLAMP","CLAMP","NEAREST")
    -- The player must stay in front of map tiles when this texture is reused.
    t:SetDrawLayer("ARTWORK",id=="player" and 1 or 0)
    if flip then t:SetTexCoord(1,0,0,1) else t:SetTexCoord(0,1,0,1) end
    t:SetAlpha(dim and .25 or 1)
    if role then U.motion[#U.motion+1]={texture=t,id=id,x=x,y=y,w=w,h=h,role=role,alpha=dim and .25 or 1} end
    return t
end
local function smallButton(x,y,w,h,value,fn,enabled)
    local b=pooled("button",function() return button(U.canvas,0,0,1,1,"",nil,false) end)
    b:ClearAllPoints();b:SetPoint("TOPLEFT",U.canvas,"TOPLEFT",x,-y);b:SetSize(w,h)
    b.buttonWidth,b.buttonHeight=w,h
    b.edge:SetSize(w,h);b.fill:SetSize(w-4,h-4);b.fill:SetColorTexture(unpack(P.light))
    b.edge:SetAlpha(1);b.fill:SetAlpha(1)
    b.label:ClearAllPoints();b.label:SetPoint("TOPLEFT",b,"TOPLEFT",3,-math.floor((h-12)/2));b.label:SetSize(w-6,14)
    b.label:SetFont(FONT,11,"");b.label:SetText(value);b:SetEnabled(enabled~=false);b:SetAlpha(enabled==false and .45 or 1)
    b.icon:SetAlpha(1);buttonIcon(b,buttonSymbols[value])
    -- Room cards customize hover; pooled buttons must restore ordinary behavior.
    b:SetScript("OnEnter",function(self) if self:IsEnabled() then self.fill:SetColorTexture(unpack(P.soft));self.fill:SetAlpha(1) end end)
    b:SetScript("OnLeave",function(self) self.fill:SetColorTexture(unpack(P.light));self.fill:SetAlpha(1) end)
    b.callback=fn;return b
end
local function act(i,name,fn,enabled)
    local b=U.actions[i];b.label:SetText(name);b.label:SetAlpha(1);b:SetEnabled(enabled~=false)
    b.label:SetFont(FONT,#name>16 and 9 or #name>14 and 10 or #name>12 and 11 or 12,"")
    if buttonSymbols[name] then b.label:SetFont(FONT,10,"") end
    b.icon:SetAlpha(1);buttonIcon(b,buttonSymbols[name])
    b:SetAlpha(enabled==false and .4 or 1);b.callback=fn
end
-- Battle moves have a separate key badge and status line, leaving the full
-- ability name readable instead of squeezing cooldown text into the name.
local function battleAct(i,name,detail,fn,enabled)
    act(i,name,fn,enabled)
    local b=U.actions[i]
    b:ClearAllPoints();b:SetPoint("TOPLEFT",U.frame,"TOPLEFT",16+(i-1)*132,-558)
    b:SetSize(124,36);b.buttonHeight=36;b.edge:SetSize(124,36);b.fill:SetSize(120,32)
    b.icon:Hide();b.key:Show();b.detail:Show();b.detail:SetText(detail)
    b.label:ClearAllPoints();b.label:SetPoint("TOPLEFT",b,"TOPLEFT",22,-5);b.label:SetSize(98,14)
    b.label:SetFont(FONT,#name>14 and 9 or 10,"")
    U.battleHotkeys[tostring(i)]=b
end
local function battleExtra(index,key,name,fn,enabled)
    local b=U.battleExtras[index];b.label:SetText(key.."  "..name);b.callback=fn
    b:SetEnabled(enabled~=false);b:SetAlpha(enabled==false and .4 or 1);b:Show()
    U.battleHotkeys[key]=b
end
function U.BattleKey(key)
    if U.duelView and U.DuelKey then return U.DuelKey(key) end
    local b=U.battleHotkeys and U.battleHotkeys[key]
    if U.effect or not G.db.battle or G.db.battle.result or G.db.pendingName
        or not b or not b:IsShown() or not b:IsEnabled() or not b.callback then return false end
    b.callback();return true
end
local function run(fn)
    return function() fn();U.Render() end
end
-- Every turn is committed immediately to SavedVariables. These short effects
-- only animate its presentation, so hiding/reloading cannot leave half a turn.
function U.Turn(action,index)
    if U.effect then return false end
    local ok,visual=G.Action(action,index)
    if not ok then return false end
    U.page=nil
    U.effect=visual;visual.age=0;visual.phase=0;visual.duration=action=="charm" and 1.05 or .98
    if F.Audio then
        F.Audio.Play(({strike="strike",special="special",charm="charm",salve="heal",guard="guard",focus="guard",swap="encounter",flee="menu"})[action])
    end
    U.Render();return true
end
function U.Animate(dt)
    U.clock=U.clock+math.min(dt,.1)
    if U.TickDuelAnimations then U.TickDuelAnimations() end
    U.TickDamagePops(dt)
    U.AdvanceCombatEffect(dt)
    local effect=U.effect
    for _,m in ipairs(U.motion) do
        local t=m.texture;local x,y,w,h=m.x,m.y,m.w,m.h;local alpha=m.alpha
        -- Deliberate stepped motion keeps the little LCD sprites pixel-like.
        local beat=math.floor(U.clock*4+(m.role=="enemy" and 1 or 0))%4
        local family=m.id:match("^([^_]+)")
        if family=="wisp" or family=="whelp" or family=="harpy" then
            y=y+({0,-2,-4,-2})[beat+1]
        else
            h=h+({0,1,2,1})[beat+1];y=y-(h-m.h)
        end
        if effect then
            local age=effect.age
            if effect.action=="charm" and m.role=="enemy" then
                if effect.result=="caught" then
                    local scale=math.max(.2,1-age*.72);w,h=m.w*scale,m.h*scale;x=x+(m.w-w)/2;y=y+(m.h-h)/2
                else y=y+({0,-2,0,2})[math.floor(age*12)%4+1] end
            elseif effect.action=="swap" and m.role==(effect.actor or "player") then x=x+(m.role=="enemy" and 1 or -1)*math.max(0,12-math.floor(age*32)) end
        end
        if m.role=="player" or m.role=="enemy" then x,y,w,h,alpha=U.CombatPose(m,x,y,w,h,alpha) end
        if m.role=="evolve" and U.evolving then
            local growth=math.min(1,(U.evolveTime or 0)/1.2);local scale=.65+.35*growth
            x=x+w*(1-scale)/2;y=y+h*(1-scale);w=w*scale;h=h*scale;alpha=.4+.6*growth
        end
        t:ClearAllPoints();t:SetPoint("TOPLEFT",U.canvas,"TOPLEFT",x,-y);t:SetSize(w,h);t:SetAlpha(alpha)
    end
    for i,t in ipairs(U.particles or {}) do
        if effect and effect.action=="charm" and (U.battleVisible or U.renameNew) then
            local age=effect.age
            local radius=U.renameNew and 22-age*8 or 48-age*25
            local cx,cy=U.renameNew and 50 or 261,U.renameNew and 74 or 88
            local angle=i*math.pi/4+age*6
            local x,y=cx+math.floor(math.cos(angle)*radius/2)*2,cy+math.floor(math.sin(angle)*radius/2)*2
            t:SetColorTexture(unpack(i%2==0 and P.dark or P.light))
            t:ClearAllPoints();t:SetPoint("TOPLEFT",U.canvas,"TOPLEFT",x,-y);t:SetAlpha(math.max(0,1-age/effect.duration));t:Show()
        else t:Hide() end
    end
    U.DrawCombatFX()
    if U.TravelTick then U.TravelTick(dt) end
    if U.evolving then U.evolveTime=(U.evolveTime or 0)+dt end
end
local function page(name) return run(function() U.page=name;U.offset=0 end) end
local function back() U.page=nil;U.offset=0;U.Render() end
local function heading(value)
    text(10,9,U.wide and 500 or 274,17,value,U.wide and 14 or 12);rect(10,28,U.wide and 500 or 308,2,P.dark)
end
local function dialogue(value)
    value=value or G.db.log
    if U.wide then
        rect(0,412,520,52,P.dark);rect(2,414,516,48,P.light,"BORDER")
        text(12,421,496,40,value,#value>170 and 10 or 11)
    else
        rect(8,199,312,65,P.dark);rect(10,201,308,61,P.light,"BORDER")
        text(16,208,296,52,value,#value>145 and 10 or 11)
    end
end
local function hp(x,y,w,p,theme)
    if theme then
        rect(x,y,w,7,theme.edge,"OVERLAY"):SetDrawLayer("OVERLAY",-2)
        rect(x+1,y+1,w-2,5,{.07,.08,.09,1},"OVERLAY"):SetDrawLayer("OVERLAY",-1)
        if p.hp>0 then
            local ratio=p.hp/G.MaxHP(p)
            local color=ratio>.5 and {.45,.74,.39,1} or ratio>.2 and {.88,.66,.28,1} or {.88,.33,.28,1}
            rect(x+1,y+1,math.max(1,(w-2)*ratio),5,color,"OVERLAY")
        end
        return
    end
    rect(x,y,w,7,P.dark);rect(x+1,y+1,w-2,5,P.soft,"BORDER")
    if p.hp>0 then rect(x+1,y+1,math.max(1,(w-2)*p.hp/G.MaxHP(p)),5,P.dark,"ARTWORK") end
end
function U.Starter()
    heading("CHOOSE A COMPANION")
    text(12,37,304,25,"A new journey across Azeroth.",10)
    for i,id in ipairs(F.starters) do
        local x=12+(i-1)*104;local s=F.species[id]
        sprite(id,x+10,64,80,80,false,false,"starter"..i)
        text(x,148,96,14,s.kind,10,"CENTER")
        smallButton(x,165,96,23,(i==U.starter and "> " or "")..({"WOLF","MURLOC","WHELP"})[i],run(function() U.starter=i end))
    end
    dialogue(F.story.intro)
    act(1,"LET'S GO",run(function() G.Start(F.starters[U.starter]);U.page=nil end))
    act(2,"NEXT",run(function() U.starter=U.starter%3+1 end))
    act(3,"HOW TO PLAY",page("help"));act(4,"FIELD GUIDE",page("journal"))
end
function U.World()
    local d=G.db;local z=F.zones[d.zone];heading(z.name)
    smallButton(270,5,22,22,"<",run(function() U.travel=nil;U.destination=nil;G.ChangeZone(-1) end),d.zone>1)
    smallButton(296,5,22,22,">",run(function() U.travel=nil;U.destination=nil;G.ChangeZone(1) end),d.zone<math.min(#F.zones,G.Badges()+1))
    text(10,32,308,13,G.Objective().label,9)
    local left=G.Clamp(d.x-7,0,8);local top=G.Clamp(d.y-4,0,6)
    for row=1,7 do
        for col=1,13 do
            local x,y=left+col,top+row;local tile=G.Tile(x,y)
            local px,py=10+(col-1)*16,49+(row-1)*16
            if tile=="=" then rect(px,py,16,16,P.soft)
            else
                local id=tile=="#" and z.terrain or tile=="~" and "water" or tile=="C" and "camp" or "grass"
                sprite(id,px,py,16,16)
            end
            local mark=({N="!",T="$",R="R",S="+",G="G"})[tile]
            if mark and not (x==d.x and y==d.y) and not G.PointUsed(tile,x,y) then text(px,py+2,16,14,mark,12,"CENTER") end
        end
    end
    sprite("player",10+(d.x-left-1)*16,49+(d.y-top-1)*16,16,16)
    text(227,45,87,11,"WALK",10,"CENTER")
    for _,v in ipairs({{246,58,"^",0,-1},{220,84,"<",-1,0},{272,84,">",1,0},{246,110,"V",0,1}}) do
        local dx,dy=v[4],v[5]
        smallButton(v[1],v[2],25,24,v[3],run(function()
            U.travel=nil
            G.Move(dx,dy)
        end))
    end
    text(222,139,94,12,math.min(z.required,d.wins[d.zone]).."/"..z.required.." WINS",9,"CENTER")
    smallButton(222,155,96,24,d.badges[d.zone] and "REMATCH" or "GUARDIAN",run(function() U.travel=nil;G.Encounter(true) end),G.GuardianReady())
    local p=G.Active()
    text(10,171,210,14,G.Name(p).."  L"..p.level,10)
    text(10,187,308,11,"HP "..p.hp.."/"..G.MaxHP(p).."  GOLD "..d.coins.."  STONES "..G.Badges().."/8",9)
    dialogue()
    if U.destination and U.destination.zone==d.zone then
        act(1,U.travel and "STOP WALKING" or "FOLLOW ROUTE",run(function()
            U.travel=not U.travel and {x=U.destination.x,y=U.destination.y,zone=d.zone,elapsed=0} or nil
        end))
    else act(1,d.badges[d.zone] and G.Objective().action or "STORY / QUEST",page("story")) end
    act(2,"TEAM "..#d.pets.."/12",page("team"))
    act(3,"CAMP / HEAL",run(function() U.travel=nil;G.Camp() end));act(4,"MENU",page("menu"))
end
function U.Battle()
    U.battleVisible=true
    local d,b=G.db,G.db.battle;local showing=U.CombatPresentation()
    local p,enemy=U.CombatPet("player"),U.CombatPet("enemy")
    local shownResult=not showing and b.result
    local theme=G.BattleTheme(b)
    rect(0,0,328,272,theme.panel):SetDrawLayer("BACKGROUND",-7)
    sprite("Battles\\"..theme.id,0,32,328,164):SetDrawLayer("BACKGROUND",-6)
    local function panel(x,y,w,h)
        rect(x,y,w,h,theme.edge,"OVERLAY"):SetDrawLayer("OVERLAY",-4)
        rect(x+1,y+1,w-2,h-2,theme.panel,"OVERLAY"):SetDrawLayer("OVERLAY",-3)
    end
    panel(8,34,198,78);panel(126,118,196,76)
    local result={win="VICTORY!",caught="A NEW FRIEND!",lost="BACK TO CAMP",fled="SAFELY AWAY"}
    local title=shownResult and result[shownResult] or ({guardian="ROUTE GUARDIAN",trainer="TRAINER BATTLE",finale="SKY CITADEL",arena="SKYKEEPER ARENA"})[b.kind] or "WILD ENCOUNTER"
    text(10,9,308,17,title,12,nil,theme.ink);rect(10,28,308,2,theme.edge,"BORDER")
    text(12,38,192,27,b.title or F.species[enemy.id].name,11,nil,theme.ink)
    text(12,66,190,12,"L"..enemy.level.." "..F.species[enemy.id].kind..(not shownResult and " NEXT:"..(showing and showing.enemyIntent or b.intent or "strike") or ""),9,nil,theme.ink)
    local noXP=shownResult and b.trivial or not shownResult and G.XPScale(math.max(b.rewardLevel or 1,p.level),enemy.level)==0
    hp(12,83,148,enemy,theme);text(12,95,148,13,enemy.hp.."/"..G.MaxHP(enemy).." HP"..(noXP and " NO XP" or ""),8,nil,theme.ink)
    -- The distant creature stays clear of the player's name panel below it.
    rect(226,115,76,3,{.04,.04,.05,.45},"BORDER")
    sprite(G.Art(enemy),218,34,92,92,true,shownResult=="win","enemy")
    rect(20,191,88,3,{.04,.04,.05,.45},"BORDER")
    sprite(G.Art(p),16,100,96,96,false,false,"player")
    text(130,123,188,25,G.Name(p),11,nil,theme.ink)
    text(130,145,188,13,"L"..p.level.."  "..F.species[p.id].kind,10,nil,theme.ink)
    hp(130,162,180,p,theme)
    text(130,175,188,13,"HP "..p.hp.."/"..G.MaxHP(p).."  XP "..p.xp.."/"..G.NeedXP(p),9,nil,theme.ink)
    panel(8,199,312,65)
    local log=U.CombatLog()
    text(16,208,296,52,log,#log>145 and 10 or 11,nil,theme.ink)
    if shownResult then
        act(1,d.run and b.result=="win" and "NEXT BATTLE" or b.dungeonKey and (b.kind=="guardian" and "FINISH DUNGEON" or "BACK TO MAP") or "CONTINUE",run(function() U.effect=nil;G.Continue();U.page=nil end))
        U.resultAction=U.actions[1].callback
        act(2,d.run and "LEAVE RUN" or "",d.run and run(function() U.effect=nil;G.LeaveRun();U.page=nil end) or nil,d.run~=nil)
        act(3,"",nil,false);act(4,"",nil,false)
    elseif U.page=="bag" then
        battleAct(1,"SALVE ("..d.salves..")","RESTORE 50% HP",function() U.Turn("salve") end,d.salves>0 and p.hp<G.MaxHP(p))
        battleAct(2,"SWAP PET","USES A TURN",page("team"),#d.pets>1)
        battleAct(3,"FLEE","LEAVE BATTLE",function() U.Turn("flee") end)
        battleAct(4,"BACK","BATTLE MOVES",page(nil))
    else
        U.battleControls:Show()
        U.battleTip:SetText("DEFENSE BLOCKS 65% OF ONE HIT; RECOVERS AFTER 2 OTHER TURNS.")
        battleAct(1,"STRIKE","BASIC ATTACK",function() U.Turn("strike") end)
        local mult=G.Multiplier(F.species[p.id].kind,F.species[enemy.id].kind)
        battleAct(2,G.Spec(p).move,b.cooldown>0 and "WAIT "..b.cooldown.." TURN"..(b.cooldown==1 and "" or "S")
            or mult>1 and "STRONG / READY" or mult<1 and "RESISTED / READY" or "SPECIAL / READY",function() U.Turn("special") end,b.cooldown==0)
        local defense=b.defenseCooldown or 0
        battleAct(3,F.defensiveMoves[p.id],defense>0 and "WAIT "..defense.." TURN"..(defense==1 and "" or "S") or "BLOCK 65%",
            function() U.Turn("guard") end,defense==0)
        battleAct(4,"BAG / TEAM","ITEMS / SWAP",page("bag"))
        local owned=G.Owns(enemy.id)
        battleExtra(1,"5",b.boss and "CANNOT TAME" or owned and "ALREADY OWNED" or "TAME: "..d.charms.." CHARMS / "..math.floor(G.CatchChance()*100).."%",
            function() U.Turn("charm") end,not b.boss and not owned and d.charms>0)
        battleExtra(2,"6",b.focus and "FOCUSED" or "FOCUS: NEXT SPECIAL +65%",function() U.Turn("focus") end,not b.focus)
    end
    if showing then
        for _,button in ipairs(U.actions) do button:SetEnabled(false);button:SetAlpha(.4) end
        for _,button in ipairs(U.battleExtras) do button:SetEnabled(false);button:SetAlpha(.4) end
    end
end
function U.Team()
    local d=G.db;heading("YOUR TEAM  "..#d.pets.."/12")
    for row=1,4 do
        local index=U.offset+row;local p=d.pets[index]
        if p then
            local y=36+(row-1)*39;sprite(G.Art(p),10,y,32,32)
            text(48,y+1,186,15,G.Name(p).." L"..p.level,9)
            text(48,y+18,186,12,"HP "..p.hp.."/"..G.MaxHP(p).."  "..F.species[p.id].kind,9)
            smallButton(241,y,77,17,index==d.active and "LEAD" or "SELECT",run(function()
                if d.battle then U.Turn("swap",index) else G.Select(index) end
            end),p.hp>0 and index~=d.active)
            smallButton(241,y+19,77,17,"NAME",function() U.Rename(index) end)
        end
    end
    dialogue(d.battle and "Switching companions uses your turn. A fresh companion has its special ready." or "Select a lead, or use NAME to give any companion a nickname. Leave the name blank to restore its species name.")
    act(1,"< PREV",run(function() U.offset=math.max(0,U.offset-4) end),U.offset>0)
    act(2,"NEXT >",run(function() U.offset=U.offset+4 end),U.offset+4<#d.pets)
    act(3,"BACK",back);act(4,"EVOLUTIONS",page("evolutions"))
end
function U.Journal()
    heading("FIELD GUIDE  "..#G.db.pets.."/12")
    for row=1,4 do
        local id=F.order[U.offset+row]
        if id then
            local s=F.species[id];local y=36+(row-1)*39;local owns=G.Owns(id)
            sprite(id,10,y,32,32,false,not owns)
            text(49,y+1,267,14,s.name..(owns and "  *" or ""),11)
            text(49,y+18,267,12,s.kind.." / "..s.move,9)
        end
    end
    dialogue("* = Befriended. All companions share XP. At level 6, specials gain healing, damage over time, guarding or weakening effects.")
    act(1,"< PREV",run(function() U.offset=math.max(0,U.offset-4) end),U.offset>0)
    act(2,"NEXT >",run(function() U.offset=U.offset+4 end),U.offset+4<#F.order)
    act(3,"BACK",back);act(4,"HOW TO PLAY",page("help"))
end
function U.Help()
    heading("A POCKET ADVENTURE")
    text(12,40,304,38,"Walk the dungeon. Explore side rooms, find keys and open the boss door. Companions evolve at levels 6 and 14.",10)
    text(12,88,304,14,"SPECIAL ATTACK ADVANTAGES",10)
    text(12,111,304,18,"EMBER > GROVE > TIDE > EMBER",10)
    text(12,133,304,18,"BEAST > ARCANE > SHADOW > BEAST",10)
    text(12,162,304,30,"Watch NEXT. Defense blocks 65% of one hit, then needs two other turns to recover.",10)
    dialogue("KEYS: arrows move, Space interacts; battle numbers match buttons. Click inside to focus. Escape or click outside releases. Drag the top to move; close to pause.")
    act(1,"BACK",back);act(2,"SETTINGS",page("settings"))
    act(3,"SMALLER",run(function() U.Scale(G.db.settings.scale-.1) end),G.db.settings.scale>.71)
    act(4,"LARGER",run(function() U.Scale(G.db.settings.scale+.1) end),G.db.settings.scale<1.49)
end
function U.Scale(value)
    U.SavePosition();G.db.settings.scale=math.max(.7,math.min(1.5,value));U.ApplyPosition()
end
function U.UpdateStatus()
    if not U.frame then return end
    U.flight:SetText(F.onTaxi and "IN FLIGHT" or "ON FOOT")
    U.auto.label:SetText("AUTO: "..(G.db.settings.auto and "ON" or "OFF"))
end
function U.Render()
    if not U.frame then return end
    U.duelView=U.GetDuelView and U.GetDuelView() or nil
    if U.duelView and U.page~="duelswap" and U.page~="dueloptions" and U.page~="help" then U.page="duel" end
    if not U.duelView and (U.page=="duel" or U.page=="duelswap" or U.page=="dueloptions") then U.page="social" end
    U.battleVisible=false;U.resultAction=nil;U.HideCombatFX()
    U.motion={}
    U.battleHotkeys={};U.battleControls:Hide()
    for i,b in ipairs(U.actions) do
        b.key:Hide();b.detail:Hide();b.buttonHeight=28
        b:ClearAllPoints();b:SetPoint("TOPLEFT",U.frame,"TOPLEFT",16+(i-1)*132,-564)
        b:SetSize(124,28);b.edge:SetSize(124,28);b.fill:SetSize(120,24)
        b.label:ClearAllPoints();b.label:SetPoint("TOPLEFT",b,"TOPLEFT",3,-8);b.label:SetSize(118,14)
    end
    local newPet,index=G.PendingPet()
    if newPet then
        U.renameIndex=index;U.renameNew=true;U.page="rename"
        if U.pendingNameSeen~=newPet.id then U.pendingNameSeen=newPet.id;U.prepareNameField=true end
    else U.renameNew=false;U.pendingNameSeen=nil end
    if U.page=="world" and G.db.battle then U.page=nil end
    local exploring=G.db.trainer and G.db.dungeon and (U.page=="dungeon" or not U.page and not G.db.battle and #G.db.evolutions==0 and not G.db.scene)
    local chart=G.db.trainer and G.db.dungeon and (U.page=="chart" or U.page=="map")
    U.Layout(exploring or chart or U.page=="social" or U.page=="leaderboard" or U.page=="duelteam",exploring)
    if U.trainerBox and U.page~="trainer" and G.db.trainer then U.trainerBox:ClearFocus();U.trainerBox:Hide() end
    if U.nameBox and U.page~="rename" then U.nameBox:ClearFocus();U.nameBox:Hide() end
    for _,t in ipairs(U.particles) do t:Hide() end
    for kind,pool in pairs(U.pools) do U.used[kind]=0;for _,item in ipairs(pool) do item:Hide() end end
    if not G.db.trainer then U.pages.trainer()
    elseif U.pages and U.pages[U.page] then U.pages[U.page]()
    elseif not U.page and not G.db.battle and #G.db.evolutions>0 then U.pages.evolution()
    elseif not U.page and not G.db.battle and G.db.scene then U.pages.scene()
    elseif not U.page and not G.db.battle and G.db.dungeon then U.pages.dungeon()
    elseif not U.page and G.db.showEnding and not G.db.battle then U.pages.ending()
    elseif not U.page and G.db.showChapter and not G.db.battle and #G.db.pets>0 then U.pages.story()
    elseif U.page=="help" then U.Help()
    elseif U.page=="journal" then U.Journal()
    elseif U.page=="team" then U.Team()
    elseif #G.db.pets==0 then U.Starter()
    elseif G.db.battle then U.Battle()
    else U.pages.story() end
    U.UpdateStatus()
    U.CheckKeyboardFocus()
    U.DrawCombatFX()
    if U.UpdateDuelInvite then U.UpdateDuelInvite() end
end
U.Paint={text=text,rect=rect,sprite=sprite,button=smallButton,act=act,run=run,page=page,back=back,heading=heading,dialogue=dialogue,hp=hp,battleAct=battleAct,battleExtra=battleExtra}
function U.Open(manual)
    U.Build();if manual then F.autoOpened=false end
    U.Render();U.frame:Show()
    if G.PendingPet() and U.nameBox then U.nameBox:SetFocus() end
    U.CheckKeyboardFocus()
    if F.Audio then F.Audio.Play("open") end
end
