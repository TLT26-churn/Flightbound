-- Deterministic demo saves only. Runs inside the headless UI harness; no WoW
-- process, live SavedVariables, desktop input, or addon files are modified.
local F,G,U,snapshot,json,setTaxi=...
local FPS,DURATION=12,55
local now=0
local audio,markers={},{}
function PlaySoundFile(path,channel)
    audio[#audio+1]={time=now,path=path,channel=channel};return true,100000+#audio
end
function StopSound(handle)
    local event=audio[handle-100000]
    if event then event.stop=now end
end
local function marker(kind,label) markers[#markers+1]={time=now,kind=kind,label=label} end
local function low(a,b) return b and a or 1 end
local function reset(id,level,zone)
    U.ReleaseKeyboard(true);U.page=nil;U.effect=nil;U.travel=nil;U.destination=nil
    U.evolving=nil;U.trainerDraft=nil;U.pendingNameSeen=nil
    if U.nameBox then U.nameBox:ClearFocus();U.nameBox:Hide() end
    if U.trainerBox then U.trainerBox:ClearFocus();U.trainerBox:Hide() end
    G.Init(nil,low);G.SetTrainer({name="Skykeeper",race="human",class="WARRIOR",gender=2})
    G.Start(id or "murloc");G.Active().level=level or 3;G.Active().hp=G.MaxHP(G.Active())
    G.db.scene=nil;G.db.showChapter=false;G.db.evolutions={};G.db.zone=zone or 1
    G.db.totalWins=10;G.db.settings.scale=1;G.db.settings.auto=true
    for i=1,(zone or 1)-1 do G.db.badges[i]=true end
    setTaxi(false);U.Open(true)
end
local function draw() U.Render() end
local function mapAt(zone,x,y)
    reset("murloc",8,zone);assert(G.StartDungeon())
    local r=G.db.dungeon;r.x,r.y=G.DungeonLayout(zone).transform(x,y)
    -- Fixture represents a partially explored save, rather than removing fog.
    local px,py=r.x,r.y
    for _,at in ipairs({{4,3},{11,3},{18,3},{11,8},{18,8},{4,13},{11,13}}) do
        r.x,r.y=G.DungeonLayout(zone).transform(at[1],at[2]);G.RevealDungeon()
    end
    r.x,r.y=px,py;G.RevealDungeon();draw()
end
local function turn(action)
    assert(U.Turn(action),"Rejected demo action: "..action);marker("move",action)
end
local events={}
local function at(t,fn) events[math.floor(t*FPS+.5)]=fn end
at(0,function() mapAt(1,4,3);G.Log("Explore the corridors. Discover companions, treasure and the next windstone.");draw() end)
at(1.5,function() assert(G.StepDungeon(1,0));draw() end)
at(2.25,function() assert(G.StepDungeon(1,0));draw() end)
at(4,function()
    reset();G.db.trainer=nil;G.db.pets={};U.trainerDraft={name="Skykeeper",race="human",class="WARRIOR",gender=2}
    U.page="trainer";draw();U.trainerBox:SetText("Skykeeper");marker("cut","trainer")
end)
at(5.5,function() U.trainerDraft.race="orc";U.trainerDraft.class="SHAMAN";U.trainerDraft.gender=1;draw();F.Audio.Play("menu") end)
at(7,function() U.trainerDraft.race="nightelf";U.trainerDraft.class="DRUID";U.trainerDraft.gender=2;draw();F.Audio.Play("menu") end)
at(8,function() assert(G.SetTrainer(U.trainerDraft));U.page=nil;draw();F.Audio.Play("menu") end)
at(9,function() mapAt(1,4,9);G.db.dungeon.used["4:8"]=true;U.SetKeyboard(true,true);draw();marker("cut","explore") end)
for i=1,4 do at(9.25+i*.4,function() assert(G.StepDungeon(0,1));draw();marker("key","DOWN") end) end
at(11.25,function() assert(G.StepDungeon(-1,0));draw();marker("key","LEFT") end)
at(11.75,function() assert(G.InteractDungeon());draw();marker("key","SPACE") end)
at(12.75,function()
    local r=G.db.dungeon;r.x,r.y=17,3;G.RevealDungeon();draw();marker("cut","key")
end)
at(13,function() assert(G.StepDungeon(1,0));draw();marker("key","RIGHT") end)
at(13.5,function() assert(G.InteractDungeon());draw();marker("key","SPACE") end)
at(14.5,function()
    local r=G.db.dungeon;r.x,r.y=14,13;r.faceX,r.faceY=1,0;G.RevealDungeon();draw();marker("cut","door")
end)
at(15,function() assert(G.InteractDungeon());draw();marker("key","SPACE") end)
at(15.5,function() assert(G.StepDungeon(1,0));draw();marker("key","RIGHT") end)
at(16.25,function() U.page="chart";draw();F.Audio.Play("menu") end)
at(17,function()
    reset("murloc",8,1);assert(G.Encounter(false,{id="wolf",level=10,kind="wild"}));draw();U.SetKeyboard(true,true);marker("cut","battle")
end)
at(17.75,function() turn("strike") end)
at(19.25,function() turn("special") end)
at(20.75,function() turn("guard") end)
at(22.25,function() turn("focus") end)
at(23.75,function() turn("special") end)
at(25,function()
    reset("murloc",3,1);assert(G.Encounter(false,{id="wolf",level=2,kind="wild"}))
    G.db.battle.enemy.hp=20;G.Log("The wolf is weakened. Try a Charm to welcome it to your team.")
    draw();marker("cut","tame")
end)
at(25.75,function() turn("charm");assert(G.PendingPet().id=="wolf") end)
for i=1,6 do at(27+(i-1)*.2,function() U.nameBox:SetText(("Nibble"):sub(1,i));F.Audio.Play("menu") end) end
at(28.75,function() U.EndRename(true);F.Audio.Play("catch") end)
at(29.75,function() assert(G.Continue());U.page="team";U.offset=0;draw();F.Audio.Play("menu") end)
at(32,function() reset("whelp",5,1);G.Rename(1,"Ember");U.page="team";draw();marker("cut","evolve") end)
at(33,function()
    local p=G.Active();p.xp=G.NeedXP(p)-1;G.GainXP(p,1);U.page=nil;draw()
end)
at(35.5,function()
    U.actions[1].callback();local p=G.Active();p.level=13;p.hp=G.MaxHP(p);p.xp=G.NeedXP(p)-1
    G.GainXP(p,1);draw()
end)
at(38,function() U.actions[1].callback();U.page="evolutions";U.evoIndex=3;draw() end)
for n=1,7 do
    local zone=n+1
    at(39+(n-1)*1.5,function()
        if zone==2 or zone==4 or zone==5 then
            mapAt(zone,18,7)
        else
            reset("murloc",math.min(28,F.zones[zone].level+1),zone)
            assert(G.Encounter(false,{id=F.zones[zone].boss,level=F.zones[zone].level+2,kind="wild"}));draw()
        end
        marker("cut",F.dungeons[zone].name)
    end)
end
at(49.5,function()
    mapAt(4,11,8);U.frame:Hide();setTaxi(true)
    assert(U.frame:IsShown() and F.autoOpened and F.onTaxi)
    marker("cut","flight");draw()
end)
for i=0,DURATION*FPS-1 do
    now=i/FPS
    if events[i] then events[i]() end
    U.Animate(1/FPS)
    -- Preserve the animated draw positions; snapshot normally re-renders.
    local render=U.Render;U.Render=function() end
    snapshot(string.format("showcase/ui-%04d",i));U.Render=render
end
local manifest={fps=FPS,duration=DURATION,version=F.version,audio=audio,markers=markers,
    provenance="Rendered from the actual addon Lua UI with staged, isolated demo saves; not live WoW screen capture."}
local out=assert(io.open("/tmp/flightbound-showcase/manifest.json","w"));out:write(json(manifest));out:close()
print("Exported "..DURATION*FPS.." actual-UI frames and "..#audio.." timed sound events for the showcase.")
