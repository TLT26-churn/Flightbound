local _,F=...
local G=F.Game
F.dungeonWidth,F.dungeonHeight=21,17
local mapCache={}
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
 local sx,sy=transform(4,3);local rows={};for y=1,17 do rows[y]=table.concat(grid[y]) end
 local doorX,doorY=transform(15,13)
 local result={rows=rows,start={x=sx,y=sy},doorKey=G.PointKey(doorX,doorY),transform=transform};mapCache[zone]=result;return result
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
 if d.ending then return {kind="complete",label="Story complete! Explore or try Arena",action="POSTGAME"} end
 if d.badges[d.zone] then
  if d.zone<8 then return {kind="travel",label="Next: "..F.dungeons[d.zone+1].name,action="NEXT DUNGEON"} end
  return {kind="finale",label="Face the Hollow Sky",action="SKY CITADEL"}
 end
 return {kind="enter",label="Explore "..F.dungeons[d.zone].name,action=d.dungeonSaves[d.zone] and "RESUME DUNGEON" or "ENTER DUNGEON"}
end
function G.CheckObjective() end
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
function G.DungeonEnemy(x,y)
 local r=G.db.dungeon;local z=F.zones[r.zone];local tile=G.DungeonTile(x,y);local id=z.wild[((r.seed+x*3+y*7)%#z.wild)+1]
 local level=z.level+(tile=="R" and 1 or 0)
 if tile=="B" then id=z.boss;level=z.level+2 end
 if r.zone==1 and G.db.totalWins==0 and tile=="E" then id=G.Active().id=="murloc" and "wolf" or "murloc";level=2 end
 return {id=id,level=level,kind=tile=="B" and "guardian" or tile=="R" and "trainer" or "wild",power=tile=="R" and 1.12 or 1}
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
  r.used[key]=true;d.routes[d.zone].treasures[key]=true;local gold=18+d.zone*5;d.coins=d.coins+gold;d.charms=math.min(99,d.charms+1);d.salves=math.min(99,d.salves+1)
  G.Sound("treasure");G.Log("Chest opened: +"..gold.." gold, 1 charm and 1 salve. Keep exploring.")
 elseif c=="C" then
  r.used[key]=true
  for _,p in ipairs(d.pets) do p.hp=math.min(G.MaxHP(p),p.hp+math.ceil(G.MaxHP(p)*.65)) end
  G.Sound("heal");G.Log("You share a quiet meal. The team recovers 65% HP. This campsite is spent.")
 elseif c=="B" and x==r.x and y==r.y then
  local enemy=G.DungeonEnemy(x,y);enemy.dungeonKey=key;return G.Encounter(true,enemy)
 elseif c=="S" then return G.RetreatDungeon()
 else G.Log("Nothing to use here. Stand on a chest, key or camp, or face a sealed door.");return false end
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
function G.RetreatDungeon()
 local d=G.db;if d.battle and not d.battle.result then return false end
 if d.dungeon then
  local r=d.dungeon;local start=G.DungeonLayout(r.zone).start;r.x,r.y=start.x,start.y
  d.dungeonSaves[r.zone]=r
 end
 d.dungeon=nil;d.battle=nil;d.scene=nil;d.showChapter=true;G.Camp()
 G.Log("Back at camp. Your map, opened chests and cleared encounters are kept.");return true
end
