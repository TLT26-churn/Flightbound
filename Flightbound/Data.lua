local _, F = ...
F.version = "4.9.0"
F.path = "Interface\\AddOns\\Flightbound\\"
-- Original little sprites and a self-contained game. No live-unit data is used.
F.species = {
    wolf   = {name="Timber Wolf",  kind="BEAST",  move="Savage Howl", hp=5, attack=6, defense=3},
    murloc = {name="Murloc",       kind="TIDE",   move="Tidal Splash",hp=3, attack=5, defense=4},
    whelp  = {name="Red Whelp",    kind="EMBER",  move="Flame Breath",hp=0, attack=7, defense=2},
    boar   = {name="Crag Boar",    kind="BEAST",  move="Tusk Charge", hp=9, attack=4, defense=5},
    spider = {name="Forest Spider",kind="SHADOW", move="Venom Bite",  hp=1, attack=6, defense=3},
    treant = {name="Young Treant", kind="GROVE",  move="Root Lash",   hp=9, attack=4, defense=5},
    wisp   = {name="Wisp",         kind="ARCANE", move="Star Spark",  hp=0, attack=7, defense=2},
    raptor = {name="Jungle Raptor",kind="BEAST",  move="Raptor Rush", hp=3, attack=7, defense=2},
    ooze   = {name="Jade Ooze",    kind="TIDE",   move="Acid Wave",   hp=8, attack=4, defense=5},
    imp    = {name="Cinder Imp",   kind="EMBER",  move="Firebolt",    hp=0, attack=8, defense=1},
    harpy  = {name="Storm Harpy",  kind="ARCANE", move="Gale Strike", hp=2, attack=6, defense=3},
    ghoul  = {name="Lost Ghoul",   kind="SHADOW", move="Grave Chill", hp=6, attack=5, defense=4},
}
F.order = {"wolf","murloc","whelp","boar","spider","treant","wisp","raptor","ooze","imp","harpy","ghoul"}
F.starters = {"wolf","murloc","whelp"}
-- Each lineage keeps a recognizable defensive move through its evolutions.
F.defensiveMoves={wolf="Evasive Prowl",murloc="Bubble Guard",whelp="Scale Guard",boar="Thick Hide",
    spider="Silk Shield",treant="Barkskin",wisp="Phase Shift",raptor="Tail Guard",
    ooze="Gel Shield",imp="Cinder Veil",harpy="Wind Ward",ghoul="Bone Armor"}
F.strong = {EMBER="GROVE",GROVE="TIDE",TIDE="EMBER",BEAST="ARCANE",ARCANE="SHADOW",SHADOW="BEAST"}
F.zones = {
    {name="Elwynn Forest", level=3, wild={"wolf","murloc","boar","spider"},boss="treant",title="Forest Guardian",terrain="tree"},
    {name="Westfall", level=5, wild={"boar","murloc","harpy","spider"},boss="harpy",title="Westfall Tempest",terrain="rock"},
    {name="Darkshore", level=7, wild={"treant","wisp","ghoul","ooze"},boss="ghoul",title="Darkshore Shade",terrain="tree"},
    {name="Ashenvale", level=9, wild={"treant","wisp","wolf","harpy"},boss="wisp",title="Moonwell Spirit",terrain="tree"},
    {name="Un'Goro Crater",level=11,wild={"raptor","ooze","whelp","treant"},boss="raptor",title="Crater Alpha",terrain="rock"},
    {name="Burning Steppes",level=13,wild={"whelp","imp","ghoul","raptor"},boss="whelp",title="Blackrock Matriarch",terrain="rock"},
}
F.palette = {dark={.13,.21,.16,1}, mid={.34,.45,.29,1}, soft={.57,.66,.40,1}, light={.76,.83,.57,1}}

F.difficulties={
    story={name="STORY",attack=.75,health=.90,recovery=.15,guardian=1,rise=1},
    adventure={name="ADVENTURE",attack=1,health=1.08,recovery=.04,guardian=1.2},
    veteran={name="VETERAN",attack=1.2,health=1.2,recovery=0,guardian=1.25},
}
F.zones[7]={name="Winterspring",level=16,wild={"wolf","harpy","wisp","treant"},boss="harpy",title="Frostwing",terrain="tree"}
F.zones[8]={name="Silithus",level=19,wild={"spider","ooze","imp","ghoul"},boss="spider",title="The Brood Empress",terrain="rock"}
-- Enemy levels are intentionally below the starter in the opening area.
F.zones[1].level=1;F.zones[2].level=3;F.zones[3].level=5;F.zones[4].level=7
F.zones[5].level=10;F.zones[6].level=13
F.story={
    title="THE BROKEN SKYWAYS",
    intro="Gryphon keeper Pip needs help! Eight windstones have gone silent. Befriend a companion and restore the skyways.",
    ending="The last shadow breaks. Gryphons return to the skies, and Pip names you Skykeeper! Azeroth's routes are safe again.",
}
local chapters={
    {"Pip's First Delivery","Pip","Wolves guard a lost mailbag near Goldshire. Recover the cargo and calm the Forest Guardian.","Mara the Scout","wolf","Bramblekeeper","treant"},
    {"Winds over Westfall","Salma","The farms are quiet, but storm harpies circle the road. Find the windstone hidden among the old shipments.","Farmer Joren","boar","Dustfeather","harpy"},
    {"A Light on the Coast","Cerelle","The lighthouse has gone dark. Follow the wisps through the ruins and bring its stolen light home.","Moonwatcher","wisp","Gloomfang","ghoul"},
    {"The Sleeping Grove","Orendil","A moonwell dreams of storms. The forest will lend you its strength if you protect its young spirits.","Grove Warden","treant","Silvercall","wolf"},
    {"Tracks in the Crater","Nessa","A supply balloon fell into the jungle. Raptors found it first. Follow the tracks and salvage the sky charts.","Ranger Talon","raptor","Miremaw","ooze"},
    {"Embers of Blackrock","Durgan","Blackrock's smoke hides the sixth windstone. The broodmother guards it fiercely. Bring a balanced team.","Cinderkeeper","imp","Ashscale","whelp"},
    {"The Frozen Signal","Luma","The northern beacon is frozen shut. A harpy called Frostwing has claimed the summit and its windstone.","Snowstrider","wolf","Starfrost","wisp"},
    {"Whispers below Sand","Ralo","The final windstone hums below the dunes. Recover it, then face the shadow waiting above the clouds.","Dune Seeker","spider","Hollowheart","ghoul"},
}
-- Every route has a distinct 21x13 map. Trails are safe; grass has encounters.
-- C camp, N keeper, T treasure, R rival, S shrine, G guardian. Points of interest
-- are real walkable map locations, not menu-only counters.
local baseMaps={
    {"#####################","#....T....#....T....#","#....=....#....=....#","#....=........=..R..#","#..=====..~.=====...#","#.....=...~...=.....#","#N====C=======S====G#","#.....=...~...=.....#","#..=====..~.=====...#","#..R.=........=.....#","#....=....#...=.....#","#....T....#...T.....#","#####################"},
    {"#####################","#T....=......=....T.#","#.....=......=.....R#","#..=========..====..#","#..=...=....=...=...#","#..=...=....=...=...#","#N====C=======S====G#","#..=...=....=...=...#","#..=====~~~~====...#","#R.....=......=....#","#......=......=....#","#T.....=......=...T#","#####################"},
    {"#####################","#~~T....#......T....#","#~~.....#......=....#","#~~..======....=..R.#","#~~..=....=....=....#","#....=....=....=....#","#N====C=======S====G#","#....=....=....=....#","#~~..=....======...#","#~~R.=.........=...#","#~~..=.........=...#","#~~T.=.........=..T#","#####################"},
    {"#####################","#T..#....=....#...T.#","#...#....=....#....R#","#...=====S=====....#","#...=....=....=....#","#...=....=....=....#","#N====C=======S====G#","#...=....=....=....#","#...=====S=====....#","#R..=....=....=....#","#...#....=....#....#","#T..#....=....#...T#","#####################"},
    {"#####################","#T.....=..~..=....T.#","#......=..~..=.....R#","#..=====..~..=====..#","#..=......~......=.#","#..=.............=.#","#N====C=======S====G#","#..=.............=.#","#..=====..~..=====.#","#R.....=..~..=.....#","#......=..~..=.....#","#T.....=..~..=....T#","#####################"},
    {"#####################","#T..=...#...=.....T.#","#...=...#...=......R#","#...=========......#","#...=...#...=......#","#...=...#...=......#","#N====C=======S====G#","#...=...#...=......#","#...=========......#","#R..=...#...=......#","#...=...#...=......#","#T..=...#...=.....T#","#####################"},
    {"#####################","#T.....=...=.....T.#","#......=...=......R#","#...========S===...#","#...=..=...=...=...#","#...=..=...=...=...#","#N====C=======S====G#","#...=..=...=...=...#","#...============...#","#R.....=...=.......#","#......=...=.......#","#T.....=...=.....T.#","#####################"},
    {"#####################","#T...=...#...=...T.#","#....=...#...=....R#","#....=========....#","#....=.......=....#","#....=.......=....#","#N====C=======S====G#","#....=.......=....#","#....=========....#","#R...=...#...=....##","#....=...#...=....##","#T...=...#...=...T##","#####################"},
}
for i,z in ipairs(F.zones) do
    local c=chapters[i];z.chapter,z.keeper,z.story=c[1],c[2],c[3]
    z.rivals={{name=c[4],id=c[5]},{name=c[6],id=c[7]}}
    z.map={}
    for y,row in ipairs(baseMaps[i]) do
        -- Keep the right-hand wall at column 21 in every authored row.
        z.map[y]=row:sub(1,-2)..string.rep(".",math.max(0,21-#row)).."#"
    end
    z.camp={x=7,y=7};z.required=i==1 and 2 or 3
    z.quests={
        {name="Safe Passage",kind="wins",need=z.required,reward=30+i*8,description="Win wild encounters on this route."},
        {name="Lost Cargo",kind="treasure",need=2,reward=35+i*8,description="Recover two cargo chests."},
        {name="Friendly Rivalry",kind="rivals",need=2,reward=45+i*10,description="Defeat both route trainers."},
    }
end
F.upgrades={
    {id="bedroll",name="Cozy Bedroll",description="Recover more HP after each win.",base=60,step=55,max=3},
    {id="charm",name="Charm Kit",description="Better catch chance and camp stock.",base=70,step=60,max=3},
    {id="journal",name="Training Notes",description="More XP for the whole collection.",base=75,step=65,max=3},
}
F.achievements={
    {id="first",name="First Friend",kind="collection",need=2,reward=25},
    {id="six",name="Full Caravan",kind="collection",need=6,reward=70},
    {id="all",name="Creature Keeper",kind="collection",need=12,reward=150},
    {id="cargo",name="Treasure Hunter",kind="treasure",need=12,reward=100},
    {id="trainers",name="Trail Champion",kind="rivals",need=16,reward=180},
    {id="skies",name="Skykeeper",kind="ending",need=1,reward=200},
}
F.finale={{id="ghoul",name="The Cloudbound",level=20},{id="imp",name="Stormkindler",level=21},{id="whelp",name="The Hollow Sky",level=22}}

-- Two visual and mechanical evolutions per lineage.
F.evolutionLevels={6,14}
F.evolutions={
    wolf={{name="Dire Wolf",move="Pack Howl"},{name="Moonfang",move="Moonfang Rush"}},
    murloc={{name="Murloc Scout",move="Tidal Spear"},{name="Tidecaller",move="Tidal Surge"}},
    whelp={{name="Red Drake",move="Dragon Breath"},{name="Crimson Dragon",move="Crimson Inferno"}},
    boar={{name="Bristletusk",move="Tusk Rampage"},{name="Ironhide",move="Iron Stampede"}},
    spider={{name="Venom Stalker",move="Venom Snare"},{name="Brood Queen",move="Brood Venom"}},
    treant={{name="Barkguard",move="Bark Lash"},{name="Grove Ancient",move="Ancient Roots"}},
    wisp={{name="Lantern Wisp",move="Moon Spark"},{name="Astral Wisp",move="Starfall"}},
    raptor={{name="Razorclaw",move="Razor Rush"},{name="Devilsaur",move="Primal Roar"}},
    ooze={{name="Surging Ooze",move="Acid Torrent"},{name="Tidal Colossus",move="Tidal Crush"}},
    imp={{name="Flame Imp",move="Flame Volley"},{name="Infernal Imp",move="Infernal Blast"}},
    harpy={{name="Wind Harpy",move="Gale Talons"},{name="Tempest Matriarch",move="Tempest Wing"}},
    ghoul={{name="Gravewalker",move="Grave Grasp"},{name="Crypt Guardian",move="Crypt Chill"}},
}
for id,forms in pairs(F.evolutions) do
    local base=F.species[id]
    for i,form in ipairs(forms) do
        form.kind=base.kind;form.hp=base.hp+(i==1 and 8 or 20)
        form.attack=base.attack+i*2;form.defense=base.defense+(i==1 and 1 or 3)
    end
end
-- One specifically requested fresh start. The token is saved after applying it.
F.resetRequest="flightbound-explorer-reset-2026-11-08-v4"

for i,z in ipairs(F.zones) do z.level=2+(i-1)*3 end
F.finale={{id="ghoul",level=26,name="The Cloudbound"},{id="imp",level=27,name="Stormkindler"},{id="whelp",level=28,name="The Hollow Sky"}}
