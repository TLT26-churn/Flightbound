local _,F=...
local G=F.Game
-- Official Forever creation table, checked 2026-11-08:
-- https://news.blizzard.com/en-us/article/24304075/create-the-hero-you-want-to-be-in-world-of-warcraft-forever
F.trainerRaces={
 {id="human",name="Human",faction="Alliance",art="human",classes={"WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","MAGE","WARLOCK"}},
 {id="dwarf",name="Dwarf",faction="Alliance",art="dwarf",classes={"WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","SHAMAN"}},
 {id="nightelf",name="Night Elf",faction="Alliance",art="nightelf",classes={"WARRIOR","HUNTER","ROGUE","PRIEST","DRUID"}},
 {id="gnome",name="Gnome",faction="Alliance",art="gnome",classes={"WARRIOR","ROGUE","PRIEST","MAGE","WARLOCK"}},
 {id="skyborne_alliance",name="High Order Skyborne",faction="Alliance",art="skyborne",classes={"WARRIOR","HUNTER","ROGUE","MAGE","DRUID"}},
 {id="orc",name="Orc",faction="Horde",art="orc",classes={"WARRIOR","HUNTER","ROGUE","SHAMAN","MAGE","WARLOCK"}},
 {id="undead",name="Undead",faction="Horde",art="undead",classes={"WARRIOR","PALADIN","ROGUE","PRIEST","MAGE","WARLOCK"}},
 {id="tauren",name="Tauren",faction="Horde",art="tauren",classes={"WARRIOR","HUNTER","SHAMAN","DRUID"}},
 {id="troll",name="Troll",faction="Horde",art="troll",classes={"WARRIOR","HUNTER","ROGUE","PRIEST","SHAMAN","MAGE","WARLOCK"}},
 {id="skyborne_horde",name="Windshaper Skyborne",faction="Horde",art="skyborne",classes={"WARRIOR","HUNTER","ROGUE","SHAMAN","DRUID"}},
}
function G.TrainerRace(id) for _,r in ipairs(F.trainerRaces) do if r.id==id then return r end end end
function G.SanitizeTrainer(p)
 if type(p)~="table" then return end
 local race=G.TrainerRace(p.race);if not race or (p.gender~=1 and p.gender~=2) then return end
 local allowed=false;for _,class in ipairs(race.classes) do if class==p.class then allowed=true end end
 if not allowed then return end
 local name=G.CleanName(p.name,24);if not name then return end
 return {name=name,race=p.race,class=p.class,gender=p.gender}
end
function G.PlayerTrainer()
 local p={name="Adventurer",race="human",class="WARRIOR",gender=2}
 if UnitName then p.name=G.CleanName(UnitName("player"),24) or p.name end
 if UnitClass then local _,class=UnitClass("player");p.class=class or p.class end
 if UnitSex then p.gender=UnitSex("player")==2 and 1 or 2 end
 if UnitRace then
  local name,token=UnitRace("player");token=(token or name or ""):lower():gsub("[%s_%-]","")
  if token=="scourge" then token="undead" end
  if token:find("skyborne") then token=UnitFactionGroup and UnitFactionGroup("player")=="Horde" and "skyborne_horde" or "skyborne_alliance" end
  if G.TrainerRace(token) then p.race=token end
 end
 return G.SanitizeTrainer(p) or {name=p.name,race=p.race,class="WARRIOR",gender=p.gender}
end
function G.SetTrainer(p)
 if G.db.battle then return false end
 p=G.SanitizeTrainer(p);if not p then return false end
 G.db.trainer=p;return true
end
function G.TrainerArt(p)
 p=p or G.db.trainer or G.PlayerTrainer();return "trainer_"..G.TrainerRace(p.race).art.."_"..p.gender
end
