local _,F=...
local G=F.Game
F.dungeonWidth,F.dungeonHeight=21,17
local mapCache={}
-- Optional rooms per dungeon, in the template's coordinates (each zone's mirror
-- transform applies). The first tile is the entrance: "?" is a readable cracked
-- wall, "." an open doorway. Mixes of foes, traps, caches and one extra camp
-- make each dungeon's detours different and worth taking.
F.dungeonSideAreas={
 {{6,10,"?"},{7,10,"."},{8,10,"."},{7,11,"."},{8,11,"T"}, {13,10,"."},{14,10,"."},{15,10,"E"},{14,11,"."},{15,11,"T"}},
 {{9,10,"?"},{8,10,"^"},{7,10,"."},{8,11,"."},{7,11,"T"}, {10,15,"."},{10,16,"."},{11,16,"E"},{12,16,"T"}},
 {{6,6,"?"},{7,6,"."},{7,5,"."},{8,6,"."},{8,5,"T"}, {16,10,"."},{15,10,"E"},{15,11,"."},{14,10,"."},{14,11,"T"}},
 {{16,5,"?"},{15,5,"."},{15,6,"."},{14,6,"C"},{14,5,"T"}, {6,11,"."},{7,11,"E"},{7,10,"."},{8,11,"."},{8,10,"T"}},
 {{9,15,"?"},{9,16,"."},{8,16,"E"},{7,16,"T"}, {13,10,"."},{14,10,"^"},{14,11,"."},{15,10,"."},{15,11,"T"}},
 {{6,5,"."},{7,5,"E"},{8,5,"."},{7,6,"."},{8,6,"T"}, {9,11,"?"},{8,11,"."},{8,10,"."},{7,11,"C"},{7,10,"T"}},
 {{13,5,"."},{14,5,"^"},{14,6,"."},{15,6,"E"},{15,5,"T"}, {13,11,"?"},{14,11,"."},{14,10,"."},{15,11,"."},{15,10,"T"}},
 {{6,10,"."},{7,10,"E"},{8,10,"."},{7,11,"^"},{8,11,"T"}, {16,6,"?"},{15,6,"."},{15,5,"."},{14,6,"."},{14,5,"T"}},
}
function G.DungeonLayout(zone)
 if mapCache[zone] then return mapCache[zone] end
 local grid={};for y=1,17 do grid[y]={};for x=1,21 do grid[y][x]="#" end end
 local function transform(x,y) return zone%2==0 and 22-x or x,math.floor((zone-1)/2)%2==1 and 18-y or y end
 local function put(x,y,c) x,y=transform(x,y);grid[y][x]=c end
 local centers={{4,3},{11,3},{18,3},{4,8},{11,8},{18,8},{4,13},{11,13},{18,13}}
 for _,at in ipairs(centers) do for y=at[2]-1,at[2]+1 do for x=at[1]-2,at[1]+2 do put(x,y,".") end end end
 local edges={{1,2},{2,3},{1,4},{4,5},{5,6},{4,7},{7,8},{8,9},{3,6}}
 if zone<=4 then edges[#edges+1]={2,5};edges[#edges+1]={5,8} else edges[#edges+1]={2,5};edges[#edges+1]={6,5} end
 for _,edge in ipairs(edges) do
  local a,b=centers[edge[1]],centers[edge[2]]
  for x=math.min(a[1],b[1]),math.max(a[1],b[1]) do put(x,a[2],".") end
  for y=math.min(a[2],b[2]),math.max(a[2],b[2]) do put(b[1],y,".") end
 end
 local objects={{4,3,"S"},{7,3,"E"},{11,3,"E"},{18,3,"K"},{4,8,"E"},{11,8,"C"},{18,8,"T"},{19,8,"R"},{4,13,"C"},{11,13,"R"},{15,13,"D"},{18,13,"B"},{5,8,"^"},{3,13,"T"},{4,15,"?"},{4,16,"T"}}
 for _,o in ipairs(objects) do put(o[1],o[2],o[3]) end
 -- 4.9 side areas are carved only from solid rock, so every original tile,
 -- route, save key and position keeps its meaning. Each touches the original
 -- map through one entrance tile; their chests are supply caches.
 local caches={}
 for _,o in ipairs(F.dungeonSideAreas[zone] or {}) do
  local x,y=transform(o[1],o[2])
  if grid[y][x]=="#" then grid[y][x]=o[3];if o[3]=="T" then caches[G.PointKey(x,y)]=true end end
 end
 local sx,sy=transform(4,3);local rows={};for y=1,17 do rows[y]=table.concat(grid[y]) end
 local doorX,doorY=transform(15,13)
 local result={rows=rows,start={x=sx,y=sy},doorKey=G.PointKey(doorX,doorY),transform=transform,caches=caches};mapCache[zone]=result;return result
end
function G.DungeonTile(x,y,r)
 r=r or G.db.dungeon;if not r or x<1 or x>21 or y<1 or y>17 then return end
 local tile=G.DungeonLayout(r.zone).rows[y]:sub(x,x);local key=G.PointKey(x,y)
 if r.used[key] and tile~="S" and tile~="B" then return "." end
 return tile
end
function G.DungeonPassable(x,y,r)
 local c=G.DungeonTile(x,y,r);return c and c~="#" and c~="D" and c~="?"
end
function G.RevealDungeon()
 local r=G.db.dungeon;if not r then return end
 for y=math.max(1,r.y-4),math.min(17,r.y+4) do for x=math.max(1,r.x-4),math.min(21,r.x+4) do
  if math.abs(x-r.x)+math.abs(y-r.y)<=4 then
   local steps=math.max(math.abs(x-r.x),math.abs(y-r.y));local visible=true
   for i=1,steps-1 do
    local px=math.floor(r.x+(x-r.x)*i/steps+.5);local py=math.floor(r.y+(y-r.y)*i/steps+.5)
    local c=G.DungeonTile(px,py);if c=="#" or c=="D" or c=="?" then visible=false;break end
   end
   if visible then r.explored[G.PointKey(x,y)]=true end
  end
 end end
end
local function sanitizeRun(r,zone)
 if type(r)~="table" or r.zone~=zone or not F.dungeons[zone] or not r.mapVersion then return end
 local n=G.Number;local start=G.DungeonLayout(zone).start
 r.x=n(r.x,start.x,1,21);r.y=n(r.y,start.y,1,17);r.keys=n(r.keys,0,0,1);r.blessing=n(r.blessing,0,0,2)
 r.seed=n(r.seed,1,1,999999);r.steps=n(r.steps,0,0,999999)
 for _,field in ipairs({"used","explored"}) do
  r[field]=type(r[field])=="table" and r[field] or {}
  for k,v in pairs(r[field]) do if type(k)~="string" or not k:match("^%d+:%d+$") or v~=true then r[field][k]=nil end end
 end
 if not G.DungeonPassable(r.x,r.y,r) then r.x,r.y=start.x,start.y end
 r.faceX,r.faceY=0,1;return r
end
function G.InitDungeon(oldVersion)
 local d=G.db;local q={}
 for _,e in ipairs(type(d.evolutions)=="table" and d.evolutions or {}) do
  if type(e)=="table" and F.species[e.id] and (e.tier==2 or e.tier==3) and #q<24 then q[#q+1]={id=e.id,tier=e.tier} end
 end
 d.evolutions=q
 if type(d.scene)~="table" or type(d.scene.title)~="string" or type(d.scene.text)~="string" then d.scene=nil end
 d.dungeon=sanitizeRun(d.dungeon,d.zone)
 d.dungeonSaves=type(d.dungeonSaves)=="table" and d.dungeonSaves or {}
 for zone=1,8 do d.dungeonSaves[zone]=sanitizeRun(d.dungeonSaves[zone],zone) end
 if oldVersion<5 then d.showChapter=#d.pets>0 and not d.ending end
 G.RevealDungeon()
end
function G.ValidateDungeonBattle()
 local d=G.db;local b=d.battle
 if b and (b.dungeonKey or b.dungeonDepth) and (not d.dungeon or b.zone~=d.dungeon.zone or not b.dungeonKey or b.dungeonKey~=G.PointKey(d.dungeon.x,d.dungeon.y)) then
  d.battle=nil;G.HealAll()
 end
end
function G.Objective()
 local d=G.db
 if d.dungeon then return {kind="explore",label=d.dungeon.used[G.DungeonLayout(d.zone).doorKey] and "The boss passage is open. Find the guardian." or d.dungeon.keys>0 and "Unlock the sealed door. Find the boss." or "Explore. Find the key and the sealed door.",action="BACK TO MAP"} end
 -- An earlier cleared dungeon (the next windstone is already restored) offers a
 -- replay; StartDungeon handles it, so existing "enter" callers need no change.
 if d.badges[d.zone] and d.zone<8 and d.badges[d.zone+1] then
  return {kind="enter",replay=true,label="Replay "..F.dungeons[d.zone].name..". Foes rise to meet your team.",action=d.dungeonSaves[d.zone] and "RESUME DUNGEON" or "REPLAY DUNGEON"}
 end
 if d.ending then return {kind="complete",label="Story complete! Explore or try Arena",action="POSTGAME"} end
 if d.badges[d.zone] then
  if d.zone<8 then return {kind="travel",label="Next: "..F.dungeons[d.zone+1].name,action="NEXT DUNGEON"} end
  return {kind="finale",label="Face the Hollow Sky",action="SKY CITADEL"}
 end
 return {kind="enter",label="Explore "..F.dungeons[d.zone].name,action=d.dungeonSaves[d.zone] and "RESUME DUNGEON" or "ENTER DUNGEON"}
end
function G.CheckObjective() end
-- Read-only exploration summary for the HUD: counts use the current run's
-- used/explored state and never change saves.
function G.DungeonProgress(r)
 r=r or G.db.dungeon;if not r then return end
 local layout=G.DungeonLayout(r.zone);local p={cargo=0,cargoTotal=0,caches=0,cacheTotal=0,foes=0,foeTotal=0,secrets=0,secretTotal=0,camps=0,campTotal=0,explored=0,floor=0}
 for y,row in ipairs(layout.rows) do for x=1,#row do
  local c=row:sub(x,x);local key=G.PointKey(x,y);local used=r.used[key]==true
  if c~="#" then p.floor=p.floor+1;if r.explored[key] then p.explored=p.explored+1 end end
  if c=="T" and layout.caches[key] then p.cacheTotal=p.cacheTotal+1;if used then p.caches=p.caches+1 end
  elseif c=="T" then p.cargoTotal=p.cargoTotal+1;if used then p.cargo=p.cargo+1 end
  elseif c=="E" or c=="R" then p.foeTotal=p.foeTotal+1;if used then p.foes=p.foes+1 end
  elseif c=="?" then p.secretTotal=p.secretTotal+1;if used then p.secrets=p.secrets+1 end
  elseif c=="C" then p.campTotal=p.campTotal+1;if used then p.camps=p.camps+1 end end
 end end
 p.key=r.keys>0;p.doorOpen=r.used[layout.doorKey]==true;p.onGuardian=G.DungeonTile(r.x,r.y,r)=="B"
 return p
end
function G.MissionDone(zone) return G.db.badges[zone or G.db.zone]==true end
function G.GuardianReady()
 local r=G.db.dungeon
 return r and G.DungeonTile(r.x,r.y)=="B" or not r and G.db.badges[G.db.zone] or false
end
function G.StartDungeon()
 local d=G.db;if d.battle or d.dungeon or not G.Active() or not d.trainer then return false end
 local s=G.DungeonLayout(d.zone).start
 d.dungeon=d.dungeonSaves[d.zone] or {zone=d.zone,x=s.x,y=s.y,faceX=0,faceY=1,seed=G.random(1,999999),mapVersion=1,used={},explored={},keys=0,steps=0,blessing=0}
 d.dungeonSaves[d.zone]=nil;d.scene=nil;d.showChapter=false
 G.RevealDungeon();G.Log("Move one tile with the arrows or click beside your trainer. Use INTERACT for chests, keys, camps and doors.");return true
end
G.BeginChapter=G.StartDungeon
function G.AdvanceChapter()
 local d=G.db;if d.battle or d.dungeon or not d.badges[d.zone] or d.zone>=8 then return false end
 d.scene=nil;G.ChangeZone(1);G.Camp();return G.StartDungeon()
end
-- The strongest companion sets the bar, so a low-level lead cannot drag foes down.
function G.TeamLevel()
 local top=1;for _,p in ipairs(G.db.pets) do top=math.max(top,p.level) end;return top
end
-- Dungeon foes rise toward a strong team within a band above their authored
-- level: {offset from team level, maximum rise}. Under-levelled teams meet the
-- authored level; nobody can out-level the current dungeon into free wins.
-- Story difficulty limits the rise to one level.
F.dungeonScaling={E={-2,3},R={-1,3},B={-1,3}}
function G.DungeonRival(zone,x,y)
 local index=0
 for row=1,y do local line=G.DungeonLayout(zone).rows[row]
  for col=1,row==y and x or #line do if line:sub(col,col)=="R" then index=index+1 end end
 end
 return F.zones[zone].rivals[index],index
end
function G.DungeonEnemy(x,y)
 local r=G.db.dungeon;local z=F.zones[r.zone];local tile=G.DungeonTile(x,y);local id=z.wild[((r.seed+x*3+y*7)%#z.wild)+1]
 local base=z.level+(tile=="R" and 1 or tile=="B" and 2 or 0);local band=F.dungeonScaling[tile]
 local level=band and G.Clamp(G.TeamLevel()+band[1],base,base+math.min(band[2],G.Difficulty().rise or band[2])) or base
 local title
 if tile=="B" then id=z.boss end
 -- Route trainers keep their story names; their companion stays the seeded
 -- local species so no starter meets a counter-type rival and guardian in a row.
 if tile=="R" then local rival=G.DungeonRival(r.zone,x,y);title=rival and rival.name end
 if r.zone==1 and G.db.totalWins==0 and tile=="E" then id=G.Active().id=="murloc" and "wolf" or "murloc";level=2 end
 return {id=id,level=level,title=title,kind=tile=="B" and "guardian" or tile=="R" and "trainer" or "wild",power=tile=="R" and 1.12 or tile=="B" and r.zone>1 and G.Difficulty().guardian or 1}
end
function G.StepDungeon(dx,dy)
 local d=G.db;local r=d.dungeon
 if not r or d.battle or d.scene or #d.evolutions>0 or math.abs(dx)+math.abs(dy)~=1 then return false end
 r.faceX,r.faceY=dx,dy;local x,y=r.x+dx,r.y+dy;local tile=G.DungeonTile(x,y)
 if not G.DungeonPassable(x,y) then
  G.Log(tile=="D" and (r.keys>0 and "A sealed door. Press INTERACT to use your key." or "A sealed door. Search the side passages for its key.") or tile=="?" and "The stone here is cracked. Try INTERACT." or "Solid stone blocks the way.")
  return false
 end
 r.x,r.y=x,y;r.steps=r.steps+1;G.Sound("step");G.RevealDungeon()
 if tile=="E" or tile=="R" then
  local enemy=G.DungeonEnemy(x,y);enemy.dungeonKey=G.PointKey(x,y)
  G.Encounter(enemy.kind~="wild",enemy)
 elseif tile=="^" then
  r.used[G.PointKey(x,y)]=true
  for _,p in ipairs(d.pets) do if p.hp>0 then p.hp=math.max(1,p.hp-math.ceil(G.MaxHP(p)*.10)) end end
  G.Log("A pressure plate! Your team loses 10% HP. The trap is now spent.")
 else
  G.Log(({K="A dungeon key. INTERACT to pick it up.",T="An unopened chest. INTERACT to search it.",C="A sheltered camp. INTERACT to rest here once.",B="The guardian waits. Prepare your team, then INTERACT.",S="Stairs back to camp. INTERACT to leave; exploration is kept."})[tile] or "Explore the corridors. Side passages hide supplies and shortcuts.")
 end
 return true
end
function G.InteractDungeon()
 local d=G.db;local r=d.dungeon;if not r or d.battle or d.scene or #d.evolutions>0 then return false end
 local x,y=r.x,r.y;local c=G.DungeonTile(x,y)
 if c=="." then x,y=x+r.faceX,y+r.faceY;c=G.DungeonTile(x,y) end
 local key=G.PointKey(x,y)
 if c=="D" then
  if r.keys<1 then G.Log("This door needs the key hidden elsewhere in the dungeon.");return false end
  r.keys=r.keys-1;r.used[key]=true;G.RevealDungeon();G.Sound("treasure");G.Log("The key turns. The sealed passage is open.")
 elseif c=="?" then r.used[key]=true;G.RevealDungeon();G.Log("Loose stones fall away, revealing a secret passage!")
 elseif c=="K" then r.used[key]=true;r.keys=1;G.Sound("treasure");G.Log("Dungeon key found! Search for the sealed door.")
 elseif c=="T" then
  -- Side-area caches stay out of cargo counts so quests, achievements and
  -- friends' leaderboards compare the same 24 cargo chests as 4.8.
  local cache=G.DungeonLayout(r.zone).caches[key]
  r.used[key]=true;if not cache then d.routes[d.zone].treasures[key]=true end
  local gold=18+d.zone*5;d.coins=d.coins+gold;d.charms=math.min(99,d.charms+1);d.salves=math.min(99,d.salves+1)
  G.Sound("treasure");G.Log((cache and "Hidden supply cache: +" or "Chest opened: +")..gold.." gold, 1 charm and 1 salve. Keep exploring.")
 elseif c=="C" then
  r.used[key]=true
  for _,p in ipairs(d.pets) do p.hp=math.min(G.MaxHP(p),p.hp+math.ceil(G.MaxHP(p)*.65)) end
  G.Sound("heal");G.Log("You share a quiet meal. The team recovers 65% HP. This campsite is spent.")
 elseif c=="B" and x==r.x and y==r.y then
  local enemy=G.DungeonEnemy(x,y);enemy.dungeonKey=key;return G.Encounter(true,enemy)
 elseif c=="S" then return G.RetreatDungeon()
 elseif c=="B" then G.Log("The guardian waits ahead. Step onto its tile, then INTERACT when your team is ready.");return false
 elseif c=="E" or c=="R" then G.Log("A foe blocks the way. Step forward to battle it.");return false
 else G.Log("Nothing to use here. Stand on a chest, key or camp, or face a sealed door or cracked wall.");return false end
 return true
end
function G.FinishDungeonRoom(b)
 local d=G.db;local r=d.dungeon;if not r or b.zone~=r.zone or not b.dungeonKey then return false end
 r.used[b.dungeonKey]=true
 if b.kind=="trainer" then d.routes[b.zone].trainers[b.dungeonKey]=true end
 if b.kind=="guardian" then
  d.dungeon=nil;d.dungeonSaves[d.zone]=nil;d.showChapter=true;G.HealAll()
  d.scene={title="DUNGEON CLEARED!",text=F.dungeons[d.zone].ending,kind="clear"}
 else r.blessing=math.max(0,r.blessing-1);G.Log("The path is clear. Continue exploring from this spot.") end
 return true
end
-- Fleeing a dungeon fight keeps the expedition: the trainer steps back to a
-- safe neighbouring tile (preferably the one they came from) and the foe stays.
-- Only defeat or the stairs/menu return to camp for its full heal and restock.
function G.FleeDungeon(b)
 local d=G.db;local r=d.dungeon;if not r or not b or b.zone~=r.zone or b.dungeonKey~=G.PointKey(r.x,r.y) then return false end
 local options={{-r.faceX,-r.faceY},{0,-1},{-1,0},{1,0},{0,1}}
 for _,v in ipairs(options) do
  local x,y=r.x+v[1],r.y+v[2];local c=G.DungeonTile(x,y)
  if (v[1]~=0 or v[2]~=0) and G.DungeonPassable(x,y) and c~="E" and c~="R" and c~="B" and c~="^" then
   r.x,r.y,r.faceX,r.faceY=x,y,-v[1],-v[2];G.RevealDungeon();break
  end
 end
 G.Log("You slip back along the passage. The foe still blocks that tile; your map and supplies are kept.");return true
end
function G.RetreatDungeon()
 local d=G.db;if d.battle and not d.battle.result then return false end
 if d.dungeon then
  local r=d.dungeon;local start=G.DungeonLayout(r.zone).start;r.x,r.y=start.x,start.y
  d.dungeonSaves[r.zone]=r
 end
 d.dungeon=nil;d.battle=nil;d.scene=nil;d.showChapter=true;G.Camp()
 G.Log("Back at camp. Your map, opened chests and cleared encounters are kept.");return true
end
