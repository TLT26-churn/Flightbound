local _,F=...
local G,U,P=F.Game,F.UI,F.palette
local H=U.Paint
local text,rect,sprite,button,act,run,page,back,heading,dialogue=H.text,H.rect,H.sprite,H.button,H.act,H.run,H.page,H.back,H.heading,H.dialogue
U.pages={}
function U.TravelTick(dt)
    local t=U.travel
    if not t then return end
    if U.page or G.db.dungeon or G.db.showChapter or G.db.battle or G.db.zone~=t.zone then U.travel=nil;return end
    t.elapsed=t.elapsed+dt
    if t.elapsed<.18 then return end
    t.elapsed=0
    if G.db.x==t.x and G.db.y==t.y then
        local before=G.Objective().kind;G.Interact();G.CheckObjective(before)
        U.travel=nil;U.destination=nil;U.Render();return
    end
    local moved=G.WalkTo(t.x,t.y)
    if not moved or G.db.battle then U.travel=nil end
    if G.db.x==t.x and G.db.y==t.y then U.travel=nil;U.destination=nil end
    U.Render()
end
function U.pages.menu()
    heading("TRAVEL JOURNAL")
    local items={{"QUEST BOOK","quests"},{"CAMP SHOP","shop"},{"ROUTE MAP","map"},{"FIELD GUIDE","journal"},
        {"ACHIEVEMENTS","awards"},{"STORY","story"},{"SKY CITADEL","citadel"},{"ENDLESS ARENA","arena"}}
    for i,v in ipairs(items) do button(10+((i-1)%2)*157,40+math.floor((i-1)/2)*37,151,29,v[1],page(v[2])) end
    local s=G.Stats()
    dialogue("Windstones "..G.Badges().."/8. Quests "..s.quests.."/24. Trainers "..s.rivals.."/16. Cargo "..s.treasure.."/32. Gold "..G.db.coins..".")
    act(1,"BACK",back);act(2,"SCOUT / BATTLE",run(function() U.destination=nil;U.page=nil;G.Encounter(false) end),G.Active()~=nil)
    act(3,"CAMP / HEAL",run(function() G.Camp();U.page=nil end),G.Active()~=nil);act(4,"SETTINGS",page("settings"))
end
function U.pages.quests()
    local d=G.db;local z=F.zones[d.zone];heading("QUESTS: ROUTE "..d.zone)
    for i,q in ipairs(z.quests) do
        local y=39+(i-1)*50;local done=d.routes[d.zone].claimed[i];local count=math.min(q.need,G.QuestProgress(d.zone,i))
        text(12,y,204,15,q.name,11)
        text(12,y+17,204,27,count.."/"..q.need.."  "..q.reward.." GOLD\n"..q.description,9)
        button(230,y+7,86,25,done and "DONE" or count>=q.need and "CLAIM" or "ACTIVE",run(function() G.ClaimQuest(d.zone,i) end),not done and count>=q.need)
    end
    dialogue(d.log)
    act(1,"ROUTE MAP",page("map"));act(2,"STORY",page("story"))
    act(3,"BACK",page("menu"));act(4,"FIELD GUIDE",page("journal"))
end
function U.pages.shop()
    local d=G.db;heading("CAMP SHOP  "..d.coins.."G")
    for i,v in ipairs(F.upgrades) do
        local y=39+(i-1)*49;local rank=d.upgrades[v.id];local maxed=rank>=v.max
        text(12,y,211,15,v.name.." "..rank.."/"..v.max,10)
        text(12,y+17,207,28,v.description,10)
        button(234,y+7,82,25,maxed and "MAX" or G.Cost(i).."G",run(function() G.Buy(i) end),not maxed and d.coins>=G.Cost(i))
    end
    dialogue(d.log)
    text(12,188,304,16,"Packs fill salves to 6; found supplies can exceed 6.",9)
    act(1,"SUPPLIES 20G",run(G.BuySupplies),G.CanBuySupplies())
    act(2,"FREE REST",run(G.Camp),G.Active()~=nil)
    act(3,"BACK",page("menu"));act(4,"QUEST BOOK",page("quests"))
end
function U.pages.map()
    local d=G.db;heading("ROUTE MAP: "..d.zone.."/8")
    local markers={C="C",N="!",T="$",R="R",S="+",G="G"}
    for y,row in ipairs(G.Map()) do
        for x=1,#row do
            local tile=row:sub(x,x);local px,py=38+(x-1)*12,35+(y-1)*12
            if tile=="#" then rect(px+2,py+2,8,8,P.dark)
            elseif tile=="~" then rect(px,py,12,12,P.mid)
            elseif tile=="=" then rect(px,py,12,12,P.soft) end
            local mark=markers[tile]
            if mark and not (x==d.x and y==d.y) then
                local tx,ty=x,y
                local b=button(px,py,12,12,mark,run(function()
                    U.destination={x=tx,y=ty,zone=d.zone};U.page=nil
                    G.Log("Destination set. Press FOLLOW ROUTE to walk there. Walking stops at encounters or when you close the game.")
                end))
                b.label:SetFont(F.path.."Art\\Silkscreen.ttf",9,"")
                b.label:ClearAllPoints();b.label:SetPoint("TOPLEFT",b,"TOPLEFT",0,-1);b.label:SetSize(12,12)
                b.edge:SetAlpha(0);b.fill:SetAlpha(0)
                if G.PointUsed(tile,x,y) then b:SetAlpha(.4) end
            end
            if x==d.x and y==d.y then sprite("player",px,py,12,12) end
        end
    end
    dialogue("Choose a map symbol to set a destination. C camp, ! keeper, $ cargo, R trainer, + shrine, G guardian.")
    act(1,"BACK",back);act(2,"CLEAR ROUTE",run(function() U.destination=nil;U.travel=nil;U.page=nil end))
    act(3,"QUEST BOOK",page("quests"));act(4,"MENU",page("menu"))
end
function U.pages.awards()
    local stats=G.Stats();heading("ACHIEVEMENTS")
    for row=1,3 do
        local index=U.offset+row;local a=F.achievements[index]
        if a then
            local y=40+(row-1)*50;local done=G.db.achievements[a.id];local count=math.min(a.need,stats[a.kind])
            text(12,y,211,17,a.name,11)
            text(12,y+21,211,14,count.."/"..a.need.."   REWARD "..a.reward.."G",10)
            button(232,y+8,84,25,done and "DONE" or count>=a.need and "CLAIM" or "LOCKED",run(function() G.ClaimAchievement(index) end),not done and count>=a.need)
        end
    end
    dialogue(G.db.log)
    act(1,"< PREV",run(function() U.offset=math.max(0,U.offset-3) end),U.offset>0)
    act(2,"NEXT >",run(function() U.offset=U.offset+3 end),U.offset+3<#F.achievements)
    act(3,"BACK",page("menu"));act(4,"FIELD GUIDE",page("journal"))
end
function U.Rename(index)
    if not G.db.pets[index] then return end
    U.renameIndex=index;U.page="rename";U.travel=nil;U.Render()
    U.nameBox:SetText(G.db.pets[index].nickname or "")
    U.nameBox:SetFocus();U.nameBox:HighlightText()
end
function U.EndRename(save)
    if U.renameNew then
        G.ResolvePetName(save and U.nameBox:GetText() or nil)
        U.renameNew=false;U.pendingNameSeen=nil;U.page=nil
    else
        if save then G.Rename(U.renameIndex,U.nameBox:GetText()) end
        U.page="team"
    end
    U.nameBox:ClearFocus();U.Render()
end
function U.pages.rename()
    local p=G.db.pets[U.renameIndex]
    if not p then U.page="team";U.Team();return end
    heading(U.renameNew and "NEW COMPANION!" or "NAME YOUR COMPANION")
    sprite(G.Art(p),14,38,72,72,false,false,"naming")
    text(98,48,218,30,G.FormName(p),12)
    text(98,84,218,18,"LEVEL "..p.level.." / "..F.species[p.id].kind,10)
    text(14,111,302,14,"Nickname (up to 16 characters)",10)
    rect(12,132,304,32,P.dark)
    rect(14,134,300,28,P.soft,"BORDER")
    if not U.nameBox then
        local box=CreateFrame("EditBox",nil,U.canvas);U.nameBox=box
        box:SetPoint("TOPLEFT",U.canvas,"TOPLEFT",22,-138);box:SetSize(284,22)
        box:SetFont("Fonts\\FRIZQT__.TTF",12,"");box:SetTextColor(unpack(P.dark))
        box:SetAutoFocus(false);box:SetMaxLetters(16);box:SetTextInsets(0,0,0,0)
        box:SetScript("OnEnterPressed",function() U.EndRename(true) end)
        box:SetScript("OnEscapePressed",function() U.EndRename(false) end)
    end
    U.nameBox:Show()
    if U.prepareNameField then
        U.nameBox:SetText("")
        if U.focusNewPet then U.nameBox:SetFocus();U.nameBox:HighlightText() end
        U.prepareNameField=nil;U.focusNewPet=nil
    end
    text(14,176,302,14,U.renameNew and "Enter: save    Esc: skip" or "Enter: save    Esc: cancel",9)
    dialogue(U.renameNew and "Your new companion has joined the team! Choose a nickname, or SKIP to keep their normal species name. You can rename them later in TEAM / BAG."
        or "Give this companion a name of its own. Names appear in the team, battles and travel view. A blank name restores the species name.")
    act(1,"SAVE NAME",function() U.EndRename(true) end)
    act(2,U.renameNew and "SKIP" or "CANCEL",function() U.EndRename(false) end)
    act(3,"CLEAR NAME",function() U.nameBox:SetText("");U.nameBox:SetFocus() end)
    act(4,"",nil,false)
end
function U.pages.citadel()
    heading("THE SKY CITADEL")
    for i,b in ipairs(F.finale) do sprite(b.id,17+(i-1)*104,52,86,86,false,false,"finale"..i) end
    text(12,151,304,39,"Three guardians. One final skyway. Your team starts healed; supplies carry between battles.",11)
    dialogue(G.Badges()==8 and "All windstones are restored. The Hollow Sky waits above the clouds. Prepare your team, then begin the finale." or "Restore all eight windstones to unlock the finale. Progress: "..G.Badges().."/8.")
    act(1,"BEGIN FINALE",run(function() if G.StartRun("finale") then U.page=nil end end),G.Badges()==8)
    act(2,"TEAM",page("team"));act(3,"BACK",page("menu"));act(4,"SHOP",page("shop"))
end
function U.pages.arena()
    heading("SKYKEEPER ARENA")
    sprite("raptor",114,39,100,100,false,false,"arena")
    text(12,147,304,18,"BEST WAVE: "..G.db.arenaBest,12,"CENTER")
    text(12,171,304,20,"An endless challenge after the story.",10,"CENTER")
    dialogue(G.db.ending and "Enemies grow stronger each wave. Wins restore some HP. Leave between rounds to keep your rewards." or "Complete the Sky Citadel finale to unlock the endless arena.")
    act(1,"ENTER ARENA",run(function() if G.StartRun("arena") then U.page=nil end end),G.db.ending)
    act(2,"TEAM",page("team"));act(3,"BACK",page("menu"));act(4,"SHOP",page("shop"))
end
function U.pages.settings()
    heading("OPTIONS")
    text(12,39,304,17,"DIFFICULTY",11)
    for i,id in ipairs({"story","adventure","veteran"}) do
        button(12+(i-1)*103,64,98,25,F.difficulties[id].name,run(function() G.SetDifficulty(id) end),not G.db.battle)
    end
    text(12,102,304,37,"Selected: "..G.Difficulty().name..". Story is gentle. Adventure is balanced. Veteran is tougher.",10)
    button(12,151,146,29,"SOUND: "..(G.db.settings.sound~=false and "ON" or "OFF"),run(function()
        G.db.settings.sound=G.db.settings.sound==false
        if F.Audio then if G.db.settings.sound then F.Audio.Play("menu") else F.Audio.Stop() end end
    end))
    button(168,151,148,29,"AUTO: "..(G.db.settings.auto and "ON" or "OFF"),run(function() G.db.settings.auto=not G.db.settings.auto end))
    dialogue("Sounds use WoW's Effects volume. Difficulty changes are available outside battles. Progress and companions are always kept.")
    act(1,"SMALLER",run(function() U.Scale(G.db.settings.scale-.1) end),G.db.settings.scale>.71)
    act(2,"LARGER",run(function() U.Scale(G.db.settings.scale+.1) end),G.db.settings.scale<1.49)
    act(3,"BACK",back);act(4,"HOW TO PLAY",page("help"))
end
function U.pages.ending()
    heading("SKYKEEPER OF AZEROTH")
    sprite("whelp",111,38,106,106,false,false,"ending")
    text(12,149,304,43,"THE SKYWAYS ARE RESTORED!\n8 WINDSTONES / 3 FINAL GUARDIANS",11,"CENTER")
    dialogue(F.story.ending)
    act(1,"KEEP EXPLORING",run(function() G.db.showEnding=false;U.page=nil end))
    U.advanceAction=U.actions[1]
    act(2,"ENDLESS ARENA",run(function() G.db.showEnding=false;U.page="arena" end))
    act(3,"ACHIEVEMENTS",run(function() G.db.showEnding=false;U.offset=0;U.page="awards" end))
    act(4,"FIELD GUIDE",run(function() G.db.showEnding=false;U.offset=0;U.page="journal" end))
end
