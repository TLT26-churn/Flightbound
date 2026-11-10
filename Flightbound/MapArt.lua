local _,F=...
local G=F.Game
-- Presentation-only: these themes never change the collision map or save data.
F.mapThemes={
 {id="elwynn",fog={.105,.080,.065,1}},
 {id="westfall",fog={.110,.085,.055,1}},
 {id="darkshore",fog={.045,.085,.105,1}},
 {id="ashenvale",fog={.045,.085,.080,1}},
 {id="ungoro",fog={.055,.080,.045,1}},
 {id="blackrock",fog={.075,.055,.080,1}},
 {id="winterspring",fog={.065,.090,.145,1}},
 {id="silithus",fog={.100,.055,.085,1}},
}
function G.MapTheme(zone) return F.mapThemes[zone or G.db.dungeon and G.db.dungeon.zone or G.db.zone] or F.mapThemes[1] end
function G.MapTileArt(x,y,c,theme)
 local variant=(x*17+y*31)%13;local role
 if c=="#" or c=="?" then
  role=c=="?" and "wall1" or variant==0 and "decor1" or variant==4 and "decor2" or variant%3==0 and "wall2" or "wall1"
 elseif c=="D" then role="door"
 elseif c=="S" then role="stairs"
 else role=variant%5==0 and "floor2" or "floor1" end
 return "Themes\\"..(theme or G.MapTheme()).id.."_"..role
end

-- Battle presentation follows the encounter's saved origin, even when the
-- currently selected zone differs. Finale/arena encounters have their own sky.
F.battleThemes={
 {id="elwynn",panel={.14,.105,.075,1},edge={.69,.49,.28,1}},
 {id="westfall",panel={.14,.11,.08,1},edge={.65,.47,.26,1}},
 {id="darkshore",panel={.07,.12,.17,1},edge={.32,.55,.65,1}},
 {id="ashenvale",panel={.10,.09,.16,1},edge={.50,.43,.66,1}},
 {id="ungoro",panel={.12,.12,.065,1},edge={.57,.53,.27,1}},
 {id="blackrock",panel={.13,.085,.12,1},edge={.67,.36,.26,1}},
 {id="winterspring",panel={.07,.12,.20,1},edge={.45,.67,.82,1}},
 {id="silithus",panel={.15,.085,.12,1},edge={.67,.43,.37,1}},
 {id="citadel",panel={.09,.12,.22,1},edge={.66,.59,.37,1}},
}
for _,theme in ipairs(F.battleThemes) do theme.ink={.94,.93,.84,1} end
function G.BattleTheme(battle)
 local b=battle or G.db.battle
 if b and (b.kind=="finale" or b.kind=="arena") then return F.battleThemes[9] end
 return F.battleThemes[b and b.zone or G.db.zone] or F.battleThemes[1]
end
