-- Animation reel, rendered from the real UI using isolated demonstration saves.
local F,G,U,snapshot,json,mode=...
local FPS,CLIP=24,mode=="impact" and 2.25 or 1.75
local clips,events={},{}
for i,id in ipairs(F.order) do
 clips[#clips+1]={id=id,level=16,zone=(i-1)%8+1,action="special",label=F.species[id].name}
end
for _,level in ipairs({3,8,16}) do
 clips[#clips+1]={id="whelp",level=level,zone=6,action="special",label="Evolution "..(level==3 and "I" or level==8 and "II" or "III")}
end
for _,action in ipairs({"strike","guard","focus","salve"}) do
 clips[#clips+1]={id="murloc",level=8,zone=3,action=action,label=({strike="Basic attack",guard="Defensive cooldown",focus="Focus",salve="Healing salve"})[action]}
end
if mode=="impact" then
 clips={
  {id="wolf",level=16,zone=1,enemy="boar",action="strike",label="Normal hit",art="slash"},
  {id="murloc",level=16,zone=3,enemy="whelp",action="special",label="Super effective",art="tide"},
  {id="wolf",level=16,zone=4,enemy="boar",action="strike",label="Critical strike",playerCrit=true,art="focus"},
  {id="whelp",level=16,zone=6,enemy="boar",action="special",label="Critical special",playerCrit=true,art="flame"},
  {id="murloc",level=16,zone=7,enemy="ghoul",action="guard",label="Block a critical",enemyCrit=true,art="shield"},
  {id="whelp",level=16,zone=8,enemy="ghoul",action="special",label="Critical knockout",playerCrit=true,knockout=true,art="focus"},
 }
end
local now=0
function PlaySoundFile(path,channel)
 events[#events+1]={time=now,path=path,channel=channel};return true,100000+#events
end
function StopSound(handle)
 local event=events[handle-100000];if event then event.stop=now end
end
local function low(a,b) return b and a or 1 end
for c,clip in ipairs(clips) do
 now=(c-1)*CLIP
 U.frame:Hide();U.page=nil;U.trainerDraft=nil;U.evolving=nil;U.pendingNameSeen=nil
 G.Init(nil,low);G.SetTrainer({name="Whitebeard Tinkerton",race="dwarf",class="WARRIOR",gender=1});G.Start(clip.id)
 G.Active().level=clip.level;G.Active().hp=G.MaxHP(G.Active())
 G.db.totalWins=10;G.db.scene=nil;G.db.evolutions={};G.db.showChapter=false;G.db.zone=clip.zone
 G.db.settings.scale=1
 local enemy=clip.enemy or F.order[c%#F.order+1]
 assert(G.Encounter(false,{id=enemy,level=clip.level+2,kind="wild"}))
 G.db.battle.intent="special"
 if clip.knockout then G.db.battle.enemy.hp=1 end
 if mode=="impact" then
  local draws=0
  G.random=function(a,b)
   if a==92 and b==108 then
    draws=draws+1
    local isPlayer=(clip.action=="strike" or clip.action=="special") and draws==1
    return (isPlayer and clip.playerCrit or not isPlayer and clip.enemyCrit) and 108 or 100
   end
   return low(a,b)
  end
 end
 if clip.action=="salve" then G.Active().hp=20 end
 U.Open(true)
 clip.move=clip.action=="special" and G.Spec(G.Active()).move or clip.action=="guard" and F.defensiveMoves[clip.id] or clip.label
 clip.form=G.Name(G.Active());clip.tier=G.Tier(G.Active());clip.start=now;clip.theme=G.BattleTheme().id
 for frame=0,CLIP*FPS-1 do
  now=(c-1)*CLIP+frame/FPS
  if frame==8 then assert(U.Turn(clip.action)) end
  U.Animate(1/FPS)
  local render=U.Render;U.Render=function() end
  snapshot(string.format("combat-preview/ui-%04d",(c-1)*CLIP*FPS+frame));U.Render=render
 end
end
local manifest={fps=FPS,duration=#clips*CLIP,clipDuration=CLIP,version=F.version,mode=mode,clips=clips,audio=events,
 provenance="Actual addon Lua UI rendered headlessly with isolated demo saves; not a live WoW screen recording."}
local f=assert(io.open("/tmp/flightbound-combat-preview/manifest.json","w"));f:write(json(manifest));f:close()
print("Exported "..#clips.." clips / "..#clips*CLIP*FPS.." actual-UI frames for the combat preview.")
