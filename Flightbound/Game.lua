local _,F=...
local G={};F.Game=G
-- Ephemeral presentation trace; never stored in SavedVariables or used by AI.
local actionVisual
function G.Clamp(n,a,b) return math.max(a,math.min(b,n)) end
function G.Number(v,fallback,a,b)
    if type(v)~="number" or v~=v or v==math.huge or v==-math.huge then return fallback end
    return G.Clamp(math.floor(v),a,b)
end
local number,clamp=G.Number,G.Clamp
function G.Tier(p) return p.level>=14 and 3 or p.level>=6 and 2 or 1 end
function G.Spec(p,tier)
    tier=tier or G.Tier(p);return tier==1 and F.species[p.id] or F.evolutions[p.id][tier-1]
end
function G.FormName(p,tier) return G.Spec(p,tier).name end
function G.Art(p,tier) tier=tier or G.Tier(p);return p.id..(tier>1 and "_"..tier or "") end
function G.ApplyRequestedReset(db,backup)
    if not F.resetRequest or type(db)=="table" and db.resetToken==F.resetRequest then return db,backup end
    local fresh={settings=type(db)=="table" and db.settings or nil,resetToken=F.resetRequest}
    -- The old table and its settings must remain independent of the fresh save.
    if fresh.settings then
        local settings={};for k,v in pairs(fresh.settings) do settings[k]=v end;fresh.settings=settings
    end
    fresh.settings=fresh.settings or {};fresh.settings.difficulty="adventure"
    return fresh,type(db)=="table" and db or backup
end
function G.MaxHP(p)
    if p.enemy and p.maxHP then return p.maxHP end
    return 36+p.level*6+G.Spec(p).hp
end
function G.NeedXP(p) return 10+p.level*5 end
-- Names are plain text, bounded in Unicode characters, never WoW markup.
function G.CleanName(value,maxChars)
    if type(value)~="string" then return nil end
    value=value:gsub("|", ""):gsub("[%c]", " "):gsub("%s+", " ")
    local chars={}
    for char in value:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        local b=char:byte();local len=b<128 and 1 or b<224 and 2 or b<240 and 3 or 4
        local second=char:byte(2) or 0
        if #char==len and not (b==224 and second<160 or b==237 and second>159 or b==240 and second<144 or b==244 and second>143) then
            chars[#chars+1]=char;if #chars==(maxChars or 16) then break end
        end
    end
    value=table.concat(chars):match("^%s*(.-)%s*$")
    return value~="" and value or nil
end
function G.Name(p) return p.nickname or G.FormName(p) end
function G.Rename(index,value)
    local p=G.db.pets[index];if not p then return false end
    p.nickname=G.CleanName(value);G.Log(G.Name(p).." is ready for the journey!");return true
end
function G.PendingPet()
    for i,p in ipairs(G.db.pets) do if p.id==G.db.pendingName then return p,i end end
end
function G.ResolvePetName(value)
    local p=G.PendingPet();if not p then return false end
    p.nickname=G.CleanName(value);G.db.pendingName=nil;return true
end
function G.NewPet(id,level)
    local p={id=id,level=level,xp=0};p.hp=G.MaxHP(p);return p
end
function G.SanitizePet(p,enemy)
    if type(p)~="table" or not F.species[p.id] then return end
    p.level=number(p.level,3,1,30);p.xp=number(p.xp,0,0,G.NeedXP(p)-1)
    p.enemy=enemy or nil;p.nickname=not enemy and G.CleanName(p.nickname) or nil
    if enemy then p.maxHP=number(p.maxHP,28+p.level*5+G.Spec(p).hp,1,10000) else p.maxHP=nil end
    p.hp=number(p.hp,G.MaxHP(p),0,G.MaxHP(p));return p
end
function G.Init(db,random)
    G.db=type(db)=="table" and db or {};G.random=random or math.random
    local d=G.db;local oldVersion=number(d.version,0,0,999)
    d.settings=type(d.settings)=="table" and d.settings or {}
    if type(d.settings.auto)~="boolean" then d.settings.auto=true end
    if type(d.settings.sound)~="boolean" then d.settings.sound=true end
    if not F.difficulties[d.settings.difficulty] then d.settings.difficulty="adventure" end
    local scale=d.settings.scale
    d.settings.scale=type(scale)=="number" and scale==scale and clamp(scale,.7,1.5) or 1
    local pets,seen={},{}
    for _,p in ipairs(type(d.pets)=="table" and d.pets or {}) do
        p=G.SanitizePet(p)
        if p and not seen[p.id] then pets[#pets+1]=p;seen[p.id]=true end
    end
    d.pets=pets;d.active=number(d.active,1,1,math.max(1,#pets))
    if type(d.pendingName)~="string" or not seen[d.pendingName] then d.pendingName=nil end
    d.badges=type(d.badges)=="table" and d.badges or {};d.wins=type(d.wins)=="table" and d.wins or {}
    for i=1,#F.zones do
        d.badges[i]=d.badges[i]==true and (i==1 or d.badges[i-1]) or false
        d.wins[i]=number(d.wins[i],0,0,999999)
    end
    d.zone=number(d.zone,1,1,math.min(#F.zones,G.Badges()+1))
    d.steps=number(d.steps,0,0,9999999);d.sinceFight=number(d.sinceFight,0,0,100)
    d.charms=number(d.charms,6,0,99);d.salves=number(d.salves,2,0,99)
    d.totalWins=number(d.totalWins,0,0,9999999)
    d.log=type(d.log)=="string" and d.log or F.story.intro
    d.trainer=G.SanitizeTrainer(d.trainer)
    G.InitAdventure(oldVersion)
    G.InitDungeon(oldVersion)
    d.x=number(d.x,7,1,21);d.y=number(d.y,7,1,13)
    if oldVersion<2 or not G.Walkable(d.x,d.y) then d.x,d.y=7,7 end
    local b=d.battle
    if type(b)=="table" and G.SanitizePet(b.enemy,true) and #pets>0 then
        b.zone=number(b.zone,d.zone,1,#F.zones)
        if not ({wild=true,guardian=true,trainer=true,finale=true,arena=true})[b.kind] then b.kind=b.boss and "guardian" or "wild" end
        b.boss=b.kind~="wild";b.cooldown=number(b.cooldown,0,0,2)
        b.defenseCooldown=number(b.defenseCooldown,0,0,2)
        b.turn=number(b.turn,0,0,9999);b.intent=b.intent=="special" and "special" or "strike"
        b.focus=b.focus==true;b.burn=number(b.burn,0,0,2);b.weaken=b.weaken==true
        b.charmTries=number(b.charmTries,0,0,99)
        b.rewardLevel=number(b.rewardLevel,pets[d.active].level,1,30)
        b.rewardLevel=math.max(b.rewardLevel,pets[d.active].level)
        b.power=type(b.power)=="number" and b.power==b.power and clamp(b.power,.5,100) or 1
        b.rival=b.rival and number(b.rival,1,1,2) or nil
        b.dungeonKey=type(b.dungeonKey)=="string" and b.dungeonKey:match("^%d+:%d+$") and b.dungeonKey or nil
        if type(b.title)~="string" then b.title=b.boss and F.zones[b.zone].title or F.species[b.enemy.id].name end
        if not ({win=true,caught=true,lost=true,fled=true})[b.result] then b.result=nil end
        if b.enemy.hp<=0 and not b.result then d.battle=nil end
        if pets[d.active].hp<=0 and not b.result then d.battle=nil end
    else d.battle=nil end
    if d.run and (not d.battle or d.battle.kind~=d.run.kind or d.battle.result=="lost" or d.battle.result=="fled") then d.run=nil end
    if d.battle and (d.battle.kind=="finale" or d.battle.kind=="arena") and not d.run and not d.battle.result then d.battle=nil end
    if oldVersion<2 and #pets>0 then
        G.HealAll();d.charms=math.max(d.charms,8);d.salves=math.max(d.salves,2)
        if d.battle and not d.battle.result then
            d.battle.enemy.maxHP=math.max(1,math.floor(d.battle.enemy.maxHP*.8))
            d.battle.enemy.hp=math.min(d.battle.enemy.hp,d.battle.enemy.maxHP)
        end
        G.Log("The skyways await! Your team is healed. Story difficulty is on; quests, cargo and trainers are now on every route.")
    end
    G.ValidateDungeonBattle()
    d.version=5;return d
end
function G.Badges() local n=0;for i=1,#F.zones do if G.db.badges[i] then n=n+1 end end;return n end
function G.Active() return G.db.pets[G.db.active] end
function G.FindPet(id) for _,p in ipairs(G.db.pets) do if p.id==id then return p end end end
function G.Owns(id) for _,p in ipairs(G.db.pets) do if p.id==id then return true end end;return false end
function G.Log(s) G.db.log=s end
function G.Sound(name) if F.Audio then F.Audio.Play(name) end end
function G.Difficulty() return F.difficulties[G.db.settings.difficulty] end
function G.SetDifficulty(id)
    if G.db.battle or not F.difficulties[id] then return false end
    if F.RecordSocialDifficulty then F.RecordSocialDifficulty(id) end
    G.db.settings.difficulty=id;G.Log(F.difficulties[id].name.." difficulty selected. Your progress is kept.");return true
end
function G.Start(id)
    if #G.db.pets>0 or not G.db.trainer or not F.species[id] then return false end
    G.db.pets={G.NewPet(id,3)};G.db.active=1;G.db.showChapter=true
    G.Log("Pip gives you six charms and two salves. Explore carefully. Your first catch is guaranteed below half HP!")
    return true
end
function G.HealAll() for _,p in ipairs(G.db.pets) do p.hp=G.MaxHP(p) end end
function G.Camp()
    local d=G.db;if d.battle then return false end
    if d.dungeon then G.Log("Rest rooms lie ahead. Use Retreat in the menu to return to the entrance.");return false end
    G.HealAll();d.charms=math.max(d.charms,6+d.upgrades.charm*2);d.salves=math.max(d.salves,2)
    d.x,d.y=7,7;d.sinceFight=0
    G.Sound("heal")
    G.Log("Rested at camp! Team healed and basic supplies refilled. Re-enter the dungeon to continue your map.");return true
end
function G.ChangeZone(delta)
    local d=G.db;if d.battle or d.dungeon or not G.Active() then return false end
    local z=d.zone+delta;if z<1 or z>#F.zones then return false end
    if z>G.Badges()+1 then G.Log("Defeat this route's guardian to reopen the next skyway.");return false end
    d.zone=z;d.x,d.y=7,7;d.sinceFight=0;d.showChapter=not d.badges[z]
    G.Log(F.zones[z].keeper..": "..F.zones[z].story);return true
end
function G.Encounter(boss,options)
    local d=G.db;if d.battle or not G.Active() then return false end
    if G.Active().hp<=0 then G.Log("Your companion needs a rest. Visit Camp.");return false end
    options=options or {};local kind=options.kind or (boss and "guardian" or "wild")
    local z=F.zones[d.zone]
    if kind=="guardian" and not G.GuardianReady() then
        G.Log("Find the guardian beyond the sealed door before starting the fight.");return false
    end
    local id=options.id or (boss and z.boss or z.wild[G.random(#z.wild)])
    local level=options.level or z.level+(boss and 2 or G.random(0,1))
    if kind=="wild" and d.zone==1 and d.totalWins==0 and not options.dungeonKey then id=G.Active().id=="murloc" and "wolf" or "murloc";level=1 end
    local enemy=G.NewPet(id,math.min(30,level));enemy.enemy=true
    enemy.maxHP=math.max(12,math.floor((26+enemy.level*5+G.Spec(enemy).hp)*G.Difficulty().health*(options.power or 1)))
    enemy.hp=enemy.maxHP
    d.battle={enemy=enemy,zone=d.zone,boss=kind~="wild",kind=kind,title=options.title or (boss and z.title or G.FormName(enemy)),
        rewardLevel=G.Active().level,objective=G.Objective().kind,firstGuardian=kind=="guardian" and not d.badges[d.zone],
        dungeonKey=options.dungeonKey,rival=options.rival,cooldown=0,defenseCooldown=0,turn=0,intent="strike",charmTries=0,power=options.power or 1}
    d.sinceFight=0;d.seen[id]=true
    G.Sound("encounter")
    G.Log((boss and d.battle.title or "Wild "..G.FormName(enemy)).." appeared! "..(boss and "Watch its next move. Guard against a special." or "Weaken it, then try a Charm."))
    return true
end
function G.Map() return F.zones[G.db.zone].map end
function G.Tile(x,y)
    local map=G.Map();if x<1 or x>21 or y<1 or y>13 then return nil end
    return map[y]:sub(x,x)
end
function G.Walkable(x,y) local c=G.Tile(x,y);return c~=nil and c~="#" and c~="~" and c~="" end
function G.Move(dx,dy)
    local d=G.db;if d.battle or d.dungeon or not G.Active() or math.abs(dx)+math.abs(dy)~=1 then return false end
    local objective=G.Objective().kind
    local x,y=d.x+dx,d.y+dy
    if not G.Walkable(x,y) then G.Log("The trail bends around the trees, rocks and water.");return false end
    d.x,d.y=x,y;d.steps=d.steps+1;d.sinceFight=d.sinceFight+1
    G.Sound("step")
    local tile=G.Tile(x,y)
    if tile=="C" then G.Camp()
    elseif tile=="T" or tile=="R" or tile=="S" or tile=="N" or tile=="G" then G.Interact()
    elseif tile=="." and d.sinceFight>=3 and (d.sinceFight>=9 or G.random(100)<=22) then G.Encounter(false)
    else G.Log(tile=="=" and "The marked trail is safe. Look for cargo, trainers, shrines and the route keeper." or "Tall grass rustles. Use Scout for a wild encounter, or keep exploring the route.") end
    G.CheckObjective(objective)
    return true
end
function G.Explore() return G.Encounter(false) end
function G.Multiplier(a,b)
    if F.strong[a]==b then return 1.5 elseif F.strong[b]==a then return .7 end;return 1
end
function G.Damage(a,b,special,modifier)
    local sa,sb=G.Spec(a),G.Spec(b)
    local mult=special and G.Multiplier(sa.kind,sb.kind) or 1
    local power=a.enemy and G.Difficulty().attack or 1.08
    if a.enemy and G.db.zone==1 and G.db.totalWins==0 and G.db.battle and G.db.battle.kind=="wild" then power=math.min(power,.80) end
    if a.enemy and G.db.dungeon and (G.db.dungeon.blessing or 0)>0 then power=power*.75 end
    -- The top two of the existing 17 damage rolls crit (2/17, about 12%).
    -- Both sides follow the same rule; no extra RNG draw changes later rolls.
    local roll=G.random(92,108);local critical=roll>=107
    local amount=math.max(2,math.floor(((sa.attack+a.level*1.5)*(special and (1.45+(G.Tier(a)-1)*.10) or 1)*mult*roll/100
        -(sb.defense+b.level*.3)*.45)*power*(modifier or 1)))
    if critical then amount=math.floor(amount*1.5) end
    local before=b.hp;b.hp=math.max(0,b.hp-amount)
    if actionVisual then
        actionVisual.hits[#actionVisual.hits+1]={source=a.enemy and "enemy" or "player",target=b.enemy and "enemy" or "player",
            id=a.id,tier=G.Tier(a),special=special==true,critical=critical,amount=amount,multiplier=mult,beforeHP=before,afterHP=b.hp}
    end
    return amount,mult,critical
end
function G.GainXP(p,xp)
    p.xp=p.xp+xp;local gained=0
    while p.level<30 and p.xp>=G.NeedXP(p) do
        p.xp=p.xp-G.NeedXP(p);local oldTier=G.Tier(p);local oldMax=G.MaxHP(p);p.level=p.level+1;gained=gained+1;p.hp=math.min(G.MaxHP(p),p.hp+G.MaxHP(p)-oldMax+math.ceil(G.MaxHP(p)*.10))
        if G.Tier(p)>oldTier then G.db.evolutions[#G.db.evolutions+1]={id=p.id,tier=G.Tier(p)} end
    end
    if p.level==30 then p.xp=0 end
    return gained>0 and (" Level "..p.level.."!") or (" +"..xp.." XP.")
end
function G.XPScale(level,enemyLevel)
    local gap=level-enemyLevel
    if gap>=4 then return 0 elseif gap==3 then return .5 elseif gap==2 then return .75 end
    return 1
end
function G.PartyXP(xp,enemyLevel,rewardLevel)
    xp=math.floor(xp*(1+G.db.upgrades.journal*.15))
    local challenge=enemyLevel and G.XPScale(rewardLevel,enemyLevel) or 1
    local text
    for i,p in ipairs(G.db.pets) do
        local scale=enemyLevel and math.min(challenge,G.XPScale(p.level,enemyLevel)) or 1
        local award=math.floor(xp*scale*(i==G.db.active and 1 or .65))
        local earned=G.GainXP(p,award)
        if i==G.db.active then text=earned end
    end
    return challenge==0 and " No XP: this foe is outgrown." or text
end
function G.Win(caught)
    local d,b=G.db,G.db.battle;if not b or b.result then return end
    b.result=caught and "caught" or "win";d.totalWins=d.totalWins+1
    local text
    if caught then
        d.pets[#d.pets+1]=G.NewPet(b.enemy.id,b.enemy.level)
        d.pendingName=b.enemy.id
        text=G.FormName(b.enemy).." befriended!"
    else text=(b.kind=="wild" and "Victory!" or b.title.." defeated!") end
    if b.kind=="wild" then d.wins[b.zone]=d.wins[b.zone]+1 end
    b.rewardLevel=math.max(b.rewardLevel or 1,G.Active().level)
    b.trivial=G.XPScale(b.rewardLevel,b.enemy.level)==0
    text=text..G.PartyXP(12+b.enemy.level*4+(b.boss and 16 or 0),b.enemy.level,b.rewardLevel)
    local coin=G.CompleteBattle(b)
    local recovery=G.Difficulty().recovery+d.upgrades.bedroll*.02
    for _,p in ipairs(d.pets) do if p.hp>0 then p.hp=math.min(G.MaxHP(p),p.hp+math.ceil(G.MaxHP(p)*recovery)) end end
    G.Log(text.." +"..coin.." gold."..(recovery>0 and " Limited HP recovered." or ""))
end
function G.PrepareIntent()
    local b=G.db.battle
    if not b or b.result then return end
    b.intent=(b.turn%3==2 and not (b.kind=="wild" and G.db.totalWins<3)) and "special" or "strike"
end
function G.EnemyTurn(prefix,guard)
    local d,b=G.db,G.db.battle;if not b or b.result then return end
    local p=G.Active();b.rewardLevel=math.max(b.rewardLevel or 1,p.level);local special=b.intent=="special"
    local modifier=(guard and .35 or 1)*(b.weaken and .65 or 1)*(b.power or 1);b.weaken=nil
    local damage,_,critical=G.Damage(b.enemy,p,special,modifier)
    if actionVisual then actionVisual.hits[#actionVisual.hits].blocked=guard==true end
    local text=prefix.." Foe "..(special and "special" or "strike")..": "..damage..(critical and " CRITICAL!" or ".")
    b.turn=b.turn+1
    if p.hp==0 then
        local nextPet;for i,v in ipairs(d.pets) do if v.hp>0 then nextPet=i;break end end
        if nextPet then
            d.active=nextPet;b.cooldown=0;b.focus=nil
            text=G.Name(p).." fainted. "..G.Name(G.Active()).." steps in!"
        else
            b.result="lost";d.run=nil;G.HealAll();d.x,d.y=7,7
            text="Your team returns to camp, fully healed. No gold or progress lost. Try Guard, a salve, or another companion."
        end
    end
    if not b.result and (b.burn or 0)>0 then
        local damage=math.max(2,math.floor(b.enemy.maxHP*.06));local before=b.enemy.hp
        b.enemy.hp=math.max(0,b.enemy.hp-damage);b.burn=b.burn-1
        if actionVisual then actionVisual.hits[#actionVisual.hits+1]={source="status",target="enemy",amount=damage,beforeHP=before,afterHP=b.enemy.hp} end
        if b.enemy.hp==0 then G.Win(false);return end
    end
    G.PrepareIntent();G.Log(text)
end
function G.CatchChance()
    local d,b=G.db,G.db.battle;if not b then return 0 end
    local ratio=b.enemy.hp/G.MaxHP(b.enemy)
    if #d.pets==1 and ratio<=.5 then return 1 end
    return clamp(.35+.6*(1-ratio)+(G.Active().level-b.enemy.level)*.02+d.upgrades.charm*.06+(b.charmTries or 0)*.08,.20,.98)
end
local function performAction(action,index)
    local d,b=G.db,G.db.battle;if not b or b.result then return false end
    local p=G.Active();b.rewardLevel=math.max(b.rewardLevel or 1,p.level);local text;local guard=false
    if action=="strike" or action=="special" then
        if action=="special" and b.cooldown>0 then return false end
        local damage,mult,critical=G.Damage(p,b.enemy,action=="special",b.focus and action=="special" and 1.65 or 1)
        text=(action=="special" and G.Spec(p).move or "Strike")..": "..damage..(critical and " CRITICAL!" or ".")
        if mult>1 then text=text.." Strong!" elseif mult<1 then text=text.." Resisted." end
        if action=="special" then
            b.cooldown=3;b.focus=nil
            if p.level>=6 then
                local kind=F.species[p.id].kind
                if kind=="EMBER" or kind=="SHADOW" then b.burn=2
                elseif kind=="TIDE" or kind=="GROVE" then p.hp=math.min(G.MaxHP(p),p.hp+math.ceil(G.MaxHP(p)*.12))
                elseif kind=="ARCANE" then b.weaken=true
                elseif kind=="BEAST" then guard=true end
            end
        end
        if b.enemy.hp==0 then G.Win(false);return true end
    elseif action=="charm" then
        if b.boss or d.charms<1 or G.Owns(b.enemy.id) then return false end
        d.charms=d.charms-1
        if G.random(100)<=G.CatchChance()*100 then G.Win(true);return true end
        b.charmTries=(b.charmTries or 0)+1;text="It resists the charm. Next try is easier!"
    elseif action=="salve" then
        if d.salves<1 or p.hp>=G.MaxHP(p) then return false end
        d.salves=d.salves-1;p.hp=math.min(G.MaxHP(p),p.hp+math.ceil(G.MaxHP(p)*.50));text="Salve restores 50% HP."
    elseif action=="guard" then
        if (b.defenseCooldown or 0)>0 then return false end
        -- Team-wide recovery: swapping cannot reset this defensive cooldown.
        -- This turn resolves immediately; two other turns must pass before reuse.
        b.defenseCooldown=3;guard=true
        text=F.defensiveMoves[p.id]..": block 65% of this hit."
    elseif action=="focus" then
        if b.focus then return false end
        b.focus=true;text="Focused! Your next special hits harder."
    elseif action=="swap" then
        if not d.pets[index] or index==d.active or d.pets[index].hp<=0 then return false end
        d.active=index;b.cooldown=0;b.focus=nil;text="Go, "..G.Name(G.Active()).."!"
    elseif action=="flee" then
        b.result="fled";d.run=nil;G.Log("Safely back on the trail. No gold or progress lost.");return true
    else return false end
    b.cooldown=math.max(0,b.cooldown-1)
    b.defenseCooldown=math.max(0,(b.defenseCooldown or 0)-1)
    G.EnemyTurn(text,guard);return true
end
local function visualPet(p)
    local copy={};for k,v in pairs(p) do if type(v)~="table" then copy[k]=v end end
    return copy
end
function G.Action(action,index)
    local b=G.db.battle
    if not b or b.result or not G.Active() then return false end
    local visual={battle=b,action=action,hits={},enemyIntent=b.intent,focused=b.focus,
        player=visualPet(action=="swap" and G.db.pets[index] or G.Active()),enemy=visualPet(b.enemy)}
    actionVisual=visual
    local ran,ok=pcall(performAction,action,index)
    actionVisual=nil
    if not ran then error(ok,0) end
    if not ok then return false end
    visual.result=b.result;visual.finalLog=G.db.log
    return true,visual
end
function G.Select(index)
    local d=G.db;if d.battle then return G.Action("swap",index) end
    if not d.pets[index] or d.pets[index].hp<=0 then return false end
    d.active=index;G.Log(G.Name(G.Active()).." now leads your team.");return true
end
function G.Continue()
    local d,b=G.db,G.db.battle
    if not b or not b.result or d.pendingName then return false end
    d.battle=nil
    if b.dungeonKey then
        if b.result=="lost" or b.result=="fled" then G.RetreatDungeon()
        elseif b.result=="win" or b.result=="caught" then G.FinishDungeonRoom(b) end
        return true
    end
    if d.run and b.result=="win" then G.NextRunBattle()
    elseif d.pendingEnding then d.pendingEnding=nil;d.showEnding=true;d.showChapter=false;G.Log(F.story.ending)
    elseif b.result=="win" or b.result=="caught" then
        if b.firstGuardian then d.showChapter=true end
        G.CheckObjective(b.objective)
    end
    return true
end

