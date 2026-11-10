local _,F=...
local G=F.Game
local n=G.Number
function G.InitAdventure(oldVersion)
    local d=G.db
    d.coins=n(d.coins,50,0,9999999);d.arenaBest=n(d.arenaBest,0,0,9999)
    d.upgrades=type(d.upgrades)=="table" and d.upgrades or {}
    for _,v in ipairs(F.upgrades) do d.upgrades[v.id]=n(d.upgrades[v.id],0,0,v.max) end
    d.routes=type(d.routes)=="table" and d.routes or {}
    for z=1,#F.zones do
        local r=type(d.routes[z])=="table" and d.routes[z] or {}
        for _,key in ipairs({"treasures","trainers","shrines","claimed"}) do
            r[key]=type(r[key])=="table" and r[key] or {}
            for k,v in pairs(r[key]) do if v~=true then r[key][k]=nil end end
        end
        r.introduced=r.introduced==true or oldVersion<3 and (d.badges[z] or d.wins[z]>0)
        d.routes[z]=r
    end
    d.achievements=type(d.achievements)=="table" and d.achievements or {}
    d.seen=type(d.seen)=="table" and d.seen or {}
    for _,p in ipairs(d.pets) do d.seen[p.id]=true end
    d.ending=d.ending==true;d.showEnding=d.ending and d.showEnding==true;d.pendingEnding=d.ending and d.pendingEnding==true
    if type(d.run)=="table" and (d.run.kind=="finale" or d.run.kind=="arena") then
        d.run.wave=n(d.run.wave,1,1,d.run.kind=="finale" and 3 or 9999)
    else d.run=nil end
    if oldVersion<2 then d.showEnding=false end
    d.showChapter=d.showChapter==true or oldVersion<3 and #d.pets>0 and not d.ending
end
function G.Count(t) local total=0;for _,v in pairs(t) do if v==true then total=total+1 end end;return total end
function G.Route() return G.db.routes[G.db.zone] end
function G.PointKey(x,y) return x..":"..y end
function G.Points(zone,tile)
    local result={}
    for y,row in ipairs(F.zones[zone or G.db.zone].map) do
        for x=1,#row do if row:sub(x,x)==tile then result[#result+1]={x=x,y=y,key=G.PointKey(x,y)} end end
    end
    return result
end
function G.PointUsed(tile,x,y)
    local r,key=G.Route(),G.PointKey(x,y)
    return tile=="T" and r.treasures[key] or tile=="S" and r.shrines[key]
end
function G.Interact()
    local d=G.db;if d.battle then return false end
    local tile=G.Tile(d.x,d.y);local r,key=G.Route(),G.PointKey(d.x,d.y);local z=F.zones[d.zone]
    if tile=="T" then
        if r.treasures[key] then G.Log("This shipment is safe. Check another chest for lost cargo.");return false end
        r.treasures[key]=true;local gold=20+d.zone*6;d.coins=d.coins+gold;d.charms=math.min(99,d.charms+2)
        G.Sound("treasure")
        G.Log("Recovered cargo! +"..gold.." gold and two charms. Your quest book tracks the delivery.")
    elseif tile=="S" then
        G.HealAll()
        G.Sound("heal")
        if not r.shrines[key] then
            r.shrines[key]=true;local gold=15+d.zone*3;d.coins=d.coins+gold
            G.Log("The wind shrine blesses your team. Fully healed! +"..gold.." gold on your first visit.")
        else G.Log("The quiet wind shrine restores your whole team.") end
    elseif tile=="N" then G.Log(z.keeper..": "..z.story)
    elseif tile=="R" then
        for i,p in ipairs(G.Points(d.zone,"R")) do if p.key==key then return G.StartRival(i) end end
    elseif tile=="G" then return G.Encounter(true)
    elseif tile=="C" then return G.Camp()
    else G.Log("C: camp, !: keeper, $: cargo, R: trainer, +: shrine, G: guardian. Use the route map to find them.");return false end
    return true
end
function G.StartRival(index)
    local z=F.zones[G.db.zone];local rival=z.rivals[index]
    if not rival then return false end
    return G.Encounter(true,{kind="trainer",id=rival.id,level=z.level+index,title=rival.name,rival=index})
end
function G.QuestProgress(zone,index)
    local q=F.zones[zone].quests[index];local r=G.db.routes[zone]
    return q.kind=="wins" and G.db.wins[zone] or q.kind=="treasure" and G.Count(r.treasures) or G.Count(r.trainers)
end
function G.ClaimQuest(zone,index)
    if G.db.battle then return false end
    local z=F.zones[zone];local q=z and z.quests[index];local r=G.db.routes[zone]
    if not q or r.claimed[index] or G.QuestProgress(zone,index)<q.need then return false end
    r.claimed[index]=true;G.db.coins=G.db.coins+q.reward
    G.Sound("treasure")
    local xp=G.Active() and G.PartyXP(15+zone*8) or ""
    G.Log(q.name.." complete! +"..q.reward.." gold."..xp);return true
end
function G.Stats()
    local d=G.db;local treasure,rivals,quests=0,0,0
    for _,r in ipairs(d.routes) do treasure=treasure+G.Count(r.treasures);rivals=rivals+G.Count(r.trainers);quests=quests+G.Count(r.claimed) end
    return {collection=#d.pets,treasure=treasure,rivals=rivals,quests=quests,ending=d.ending and 1 or 0}
end
function G.ClaimAchievement(index)
    local a=F.achievements[index];local d=G.db
    if d.battle or not a or d.achievements[a.id] or G.Stats()[a.kind]<a.need then return false end
    d.achievements[a.id]=true;d.coins=d.coins+a.reward;G.Log(a.name.." earned! +"..a.reward.." gold.");return true
end
function G.Cost(index)
    local u=F.upgrades[index];return u.base+G.db.upgrades[u.id]*u.step
end
function G.Buy(index)
    local d,u=G.db,F.upgrades[index]
    if d.battle or not u or d.upgrades[u.id]>=u.max or d.coins<G.Cost(index) then return false end
    local cost=G.Cost(index);d.coins=d.coins-cost;d.upgrades[u.id]=d.upgrades[u.id]+1
    G.Log(u.name.." upgraded! "..u.description);return true
end
function G.BuySupplies()
    local d=G.db;if d.battle or d.coins<20 then return false end
    if d.salves>=99 and d.charms>=99 then return false end
    d.coins=d.coins-20;d.salves=math.min(99,d.salves+3);d.charms=math.min(99,d.charms+3)
    G.Log("Travel pack: three extra salves and three charms. Camp still restocks basic supplies for free.");return true
end
function G.CompleteBattle(b)
    local d=G.db;local gold=b.trivial and 0 or 8+b.enemy.level*2
    if b.dungeonKey and b.kind=="trainer" and not b.trivial then gold=gold+20+b.zone*5 end
    if b.kind=="guardian" then
        if not d.badges[b.zone] then gold=gold+50+b.zone*10 end
        d.badges[b.zone]=true
    elseif b.kind=="trainer" and b.rival then
        if not d.routes[b.zone].trainers[b.rival] then gold=gold+30+b.zone*8 end
        d.routes[b.zone].trainers[b.rival]=true
    elseif b.kind=="finale" and d.run then
        if d.run.wave==#F.finale then
            if not d.ending then gold=gold+200 end
            d.ending=true;d.pendingEnding=true;d.run=nil
        else d.run.wave=d.run.wave+1 end
    elseif b.kind=="arena" and d.run then
        d.arenaBest=math.max(d.arenaBest,d.run.wave);gold=gold+d.run.wave*5;d.run.wave=d.run.wave+1
    end
    d.coins=math.min(9999999,d.coins+gold);return gold
end
function G.StartRun(kind)
    local d=G.db
    if d.battle or d.dungeon or not G.Active() or (kind~="finale" and kind~="arena") then return false end
    if G.Badges()<#F.zones then G.Log("Restore all eight windstones first.");return false end
    if kind=="arena" and not d.ending then G.Log("Finish the Sky Citadel finale to unlock the endless arena.");return false end
    G.HealAll();d.salves=math.max(4,d.salves);d.run={kind=kind,wave=1};return G.NextRunBattle()
end
function G.NextRunBattle()
    local d=G.db;if not d.run or d.battle then return false end
    if d.run.kind=="finale" then
        local boss=F.finale[d.run.wave]
        return G.Encounter(true,{kind="finale",id=boss.id,level=boss.level,title=boss.name})
    end
    local wave=d.run.wave
    return G.Encounter(true,{kind="arena",id=F.order[(wave-1)%#F.order+1],level=math.min(30,25+wave),title="Arena Wave "..wave,power=1+math.max(0,wave-4)*.08})
end
function G.LeaveRun()
    local d=G.db;if d.battle and not d.battle.result then return false end
    d.run=nil;d.battle=nil;G.Camp();return true
end
-- Breadth-first route assistance moves ONE tile per click inside the minigame.
function G.WalkTo(x,y)
    local d=G.db;if d.battle or not G.Walkable(x,y) then return false end
    if x==d.x and y==d.y then return G.Interact() end
    local queue={{x=d.x,y=d.y}};local head=1;local seen={[G.PointKey(d.x,d.y)]=true}
    while head<=#queue do
        local at=queue[head];head=head+1
        for _,v in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
            local nx,ny=at.x+v[1],at.y+v[2];local key=G.PointKey(nx,ny)
            if not seen[key] and G.Walkable(nx,ny) then
                seen[key]=true;local nextStep={x=nx,y=ny,dx=at.dx or v[1],dy=at.dy or v[2]}
                if nx==x and ny==y then return G.Move(nextStep.dx,nextStep.dy) end
                queue[#queue+1]=nextStep
            end
        end
    end
    G.Log("No path to that spot.");return false
end
