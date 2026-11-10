local _,F=...
local G,U,P=F.Game,F.UI,F.palette
local H=U.Paint
local text,rect,sprite,button,act,run,page,back,heading,dialogue=H.text,H.rect,H.sprite,H.button,H.act,H.run,H.page,H.back,H.heading,H.dialogue
local titles={wild="CREATURE",elite="ELITE",treasure="TREASURE",spring="SPRING",camp="CAMPFIRE",blessing="SHRINE",boss="BOSS"}
local hints={wild="Catch or battle",elite="Harder / more gold",treasure="Gold + 2 charms",spring="Heal 35% + salve",camp="Full heal + salve",blessing="Guard next 2 fights",boss="Unlock next dungeon"}
local art={treasure="camp",spring="water",camp="camp",blessing="wisp"}
function U.FollowStory()
    local goal=G.Objective();U.travel=nil;U.destination=nil;U.page=nil
    if goal.kind=="travel" then G.AdvanceChapter()
    elseif goal.kind=="enter" then G.StartDungeon()
    elseif goal.kind=="finale" then U.page="citadel"
    elseif goal.kind=="complete" then U.page="menu" end
end
function U.pages.story()
    local d=G.db;local z=F.dungeons[d.zone];local goal=G.Objective()
    heading(z.name)
    text(12,38,200,15,"DUNGEON "..d.zone.." / 8",11)
    button(228,35,88,23,"SELECT",page("dungeons"))
    local boss={id=F.zones[d.zone].boss,level=F.zones[d.zone].level+2}
    sprite(G.Art(boss),16,65,94,94,false,false,"keeper")
    text(126,72,184,22,z.rooms.." ROOMS",13)
    text(126,100,184,51,"Creatures, treasure, rest and a final boss.",10)
    local p=G.Active()
    text(12,170,304,17,d.badges[d.zone] and "Windstone restored" or "Your next expedition",11)
    text(12,187,304,11,(p and G.Name(p).." L"..p.level.." / " or "")..d.coins.." GOLD",9)
    dialogue(d.badges[d.zone] and z.ending or z.intro)
    act(1,goal.action,run(U.FollowStory),p~=nil)
    act(2,"TEAM / NAMES",page("team"),p~=nil)
    act(3,"CAMP SHOP",page("shop"));act(4,"MENU",page("menu"))
end
function U.pages.dungeon()
    local d=G.db;local r=d.dungeon;if not r then U.pages.story();return end
    local z=F.dungeons[r.zone];heading(z.name)
    local p=G.Active()
    text(12,36,304,14,"ROOM "..r.depth.."/"..z.rooms.."  HP "..p.hp.."/"..G.MaxHP(p).."  "..d.coins.."G",10)
    for i=1,z.rooms do
        local x=14+(i-1)*51
        rect(x,57,29,21,P.dark)
        rect(x+2,59,25,17,i==r.depth and P.soft or P.light,"BORDER")
        text(x+2,60,25,14,i<r.depth and "X" or i==z.rooms and "B" or tostring(i),11,"CENTER")
        if i<z.rooms then rect(x+33,66,12,2,P.dark) end
    end
    local choices=G.RoomChoices()
    for i,c in ipairs(choices) do
        local x=#choices==1 and 91 or 12+(i-1)*158
        rect(x,91,146,103,P.soft)
        text(x+4,95,138,13,titles[c.kind],10,"CENTER")
        sprite(c.id and G.Art(c) or art[c.kind],x+46,111,54,54,false,false,"room"..i)
        text(x+3,164,140,20,c.id and G.FormName(c).." L"..c.level or hints[c.kind],9,"CENTER")
        if c.id then text(x+3,183,140,10,hints[c.kind],8,"CENTER") end
        local choice=i
        local hit=button(x,91,146,103,"",run(function() G.ChooseDungeonRoom(choice);U.page=nil end))
        hit.edge:SetAlpha(0);hit.fill:SetAlpha(0)
        hit:SetScript("OnEnter",function(self) self.fill:SetAlpha(.15) end)
        hit:SetScript("OnLeave",function(self) self.fill:SetAlpha(0) end)
    end
    dialogue(r.depth==1 and z.intro or r.depth==z.rooms and "The boss guards the windstone. Check your team and salves before opening this door. Specials and Guard can turn the fight."
        or r.blessing>0 and "The wind shields your team for "..r.blessing.." more battles. Choose your next room; progress saves after every choice."
        or "Choose a room below. Treasure builds your supplies; creatures can join your team. Campfires heal everyone. You can close the game and return anytime.")
    for i=1,2 do
        local c=choices[i]
        act(i,c and (#choices==1 and "FACE BOSS" or (i==1 and "LEFT: " or "RIGHT: ")..titles[c.kind]) or "",
            c and run(function() G.ChooseDungeonRoom(i);U.page=nil end) or nil,c~=nil)
    end
    act(3,"TEAM / NAMES",page("team"));act(4,"MENU / RETREAT",page("menu"))
end
function U.pages.scene()
    local d=G.db;local s=d.scene;if not s then back();return end
    heading(s.title)
    local p=G.Active()
    sprite(s.kind=="clear" and G.Art(p) or art[s.kind] or "camp",112,45,104,104,false,false,"scene")
    text(12,157,304,16,s.kind=="clear" and "WINDSTONES "..G.Badges().." / 8" or "Room complete",12,"CENTER")
    text(12,180,304,13,"TEAM "..#d.pets.." / 12   GOLD "..d.coins,10,"CENTER")
    dialogue(s.text)
    act(1,s.kind=="clear" and G.Objective().action or "BACK TO MAP",run(function()
        d.scene=nil
        if s.kind=="clear" then U.FollowStory() end
        U.page=U.page=="scene" and nil or U.page
    end))
    act(2,"TEAM / NAMES",page("team"));act(3,"",nil,false);act(4,"MENU",page("menu"))
    U.advanceAction=U.actions[1]
end
function U.pages.menu()
    heading("EXPEDITION JOURNAL")
    local items={{"DUNGEONS","dungeons"},{"EVOLUTIONS","evolutions"},{"CAMP SHOP","shop"},{"FIELD GUIDE","journal"},
        {"SIDE QUESTS","quests"},{"ACHIEVEMENTS","awards"},{"FREE ROAM","world"},{"SETTINGS","settings"}}
    for i,v in ipairs(items) do
        button(10+((i-1)%2)*157,40+math.floor((i-1)/2)*37,151,29,v[1],page(v[2]),v[2]~="world" or not G.db.dungeon)
    end
    dialogue(G.db.dungeon and "RETREAT returns to the entrance and restarts this dungeon. Your companions, levels, items and gold are kept. Closing the window simply pauses."
        or "Choose a dungeon to continue your campaign. Free Roam, side quests and the field guide are optional. Eight windstones unlock the Sky Citadel.")
    act(1,"BACK TO GAME",back)
    act(2,G.db.dungeon and "RETREAT" or "FREE REST",run(function()
        if G.db.dungeon then G.RetreatDungeon() else G.Camp() end
        U.page=nil
    end),G.Active()~=nil and not G.db.battle)
    act(3,"ENDLESS ARENA",page("arena"));act(4,"HOW TO PLAY",page("help"))
end
function U.pages.dungeons()
    local d=G.db;heading("DUNGEON SELECT")
    for row=1,4 do
        local index=U.offset+row;local z=F.dungeons[index]
        if z then
            local y=37+(row-1)*39
            text(12,y,213,17,index..". "..z.name,10)
            text(12,y+18,213,12,d.badges[index] and "Cleared / Replay available" or index>G.Badges()+1 and "LOCKED" or "Next windstone",9)
            button(235,y+3,80,25,"GO",run(function()
                G.ChangeZone(index-d.zone);d.scene=nil;U.page=nil;d.showChapter=true
            end),not d.dungeon and index<=G.Badges()+1)
        end
    end
    dialogue(d.dungeon and "Your expedition is in progress. Return to camp before choosing another dungeon. Your exploration is kept." or "Earlier dungeons can be replayed. Weak enemies stop giving XP. Defeat the next boss to open a new dungeon.")
    act(1,"< PREV",run(function() U.offset=0 end),U.offset>0)
    act(2,"NEXT >",run(function() U.offset=4 end),U.offset==0)
    act(3,"BACK",back);act(4,"REPLAY HERE",run(function() G.StartDungeon();U.page=nil end),not d.dungeon and d.badges[d.zone])
end
function U.pages.world() U.World() end
function U.pages.evolutions()
    U.evoIndex=G.Clamp(U.evoIndex or 1,1,#F.order)
    local id=F.order[U.evoIndex];local owned=G.FindPet(id);local p=owned or {id=id,level=1}
    heading("EVOLUTION GUIDE")
    text(12,37,304,17,F.species[id].name..(owned and " / YOUR LEVEL "..owned.level or " / NOT FOUND"),10)
    for tier=1,3 do
        local x=10+(tier-1)*106
        sprite(G.Art(p,tier),x+9,65,84,84,false,not owned or G.Tier(p)<tier,"form"..tier)
        text(x,151,102,29,G.FormName(p,tier),9,"CENTER")
        text(x,181,102,12,tier==1 and "Base form" or "LEVEL "..F.evolutionLevels[tier-1],10,"CENTER")
    end
    dialogue("All 12 lineages evolve at levels 6 and 14. Evolutions change their appearance, improve HP, attack and defense, and strengthen their special. Nicknames stay.")
    act(1,"< PREV",run(function() U.evoIndex=math.max(1,U.evoIndex-1) end),U.evoIndex>1)
    act(2,"NEXT >",run(function() U.evoIndex=math.min(#F.order,U.evoIndex+1) end),U.evoIndex<#F.order)
    act(3,"BACK",back);act(4,"TEAM / NAMES",page("team"))
end
function U.pages.evolution()
    local e=G.db.evolutions[1];if not e then back();return end
    local p=G.FindPet(e.id) or {id=e.id,level=F.evolutionLevels[e.tier-1]}
    if U.evolving~=e then U.evolving=e;U.evolveTime=0;G.Sound("victory") end
    heading("A NEW EVOLUTION!")
    text(12,37,304,27,(p.nickname or G.FormName(p,e.tier-1)).." is evolving!",11,"CENTER")
    sprite(G.Art(p,e.tier-1),21,74,94,94,false,true)
    text(139,105,50,20,">>",18,"CENTER")
    sprite(G.Art(p,e.tier),214,74,94,94,false,false,"evolve")
    text(12,172,304,18,G.FormName(p,e.tier),12,"CENTER")
    local old,new=G.Spec(p,e.tier-1),G.Spec(p,e.tier)
    dialogue("HP +"..(new.hp-old.hp)..", attack +"..(new.attack-old.attack)..", defense +"..(new.defense-old.defense)..". Special upgraded: "..new.move..". Your nickname and collection stay with this companion.")
    act(1,"CONTINUE",run(function() table.remove(G.db.evolutions,1);U.evolving=nil;U.page=nil end))
    U.advanceAction=U.actions[1]
    act(2,"",nil,false);act(3,"",nil,false);act(4,"",nil,false)
end
