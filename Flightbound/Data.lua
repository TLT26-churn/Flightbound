local _,F=...
F.version = "5.0.0"
F.path="Interface\\AddOns\\Flightbound\\"
F.freshStart="idle-hunt-5.0.0-launch"
F.petOrder={"wolf","boar","whelp","murloc","treant","wisp"}
F.pets={
 wolf={name="Timber Wolf",base=2.2,cost=20,unlock=0,interval=1.2,fx="claw",role="Marks prey: your clicks deal +25% damage."},
 boar={name="Crag Boar",base=4.2,cost=90,unlock=1,interval=1.6,fx="tusk",role="Breaks boss armor with every attack."},
 whelp={name="Red Whelp",base=5.4,cost=260,unlock=2,interval=1.8,fx="flame",role="Burns for 60% extra damage; stops regeneration."},
 murloc={name="Murloc Scout",base=6.5,cost=720,unlock=3,interval=1.2,fx="tide",role="Your whole party earns +30% gold."},
 treant={name="Grove Ancient",base=12,cost=1800,unlock=4,interval=2.0,fx="roots",role="Your whole party deals +35% damage while away."},
 wisp={name="Lantern Wisp",base=17,cost=4200,unlock=5,interval=1.5,fx="star",role="Attacks restore Focus for your Power Strike."},
}
F.zones={
 {name="Elwynn Forest",art="elwynn",wild={"wolf","boar","murloc"},boss="treant",title="Bramblekeeper",mechanic="armor",hint="Armor blocks 55%. Clicks and boars break it.",need=8},
 {name="Westfall",art="westfall",wild={"boar","harpy","spider"},boss="harpy",title="Dustfeather",mechanic="ward",hint="Wind ward halves crew damage. Power Strike breaks it.",need=12},
 {name="Darkshore",art="darkshore",wild={"ghoul","ooze","murloc"},boss="ghoul",title="Gloomfang",mechanic="regen",hint="Regenerates health. A whelp's burn stops healing.",need=16},
 {name="Ashenvale",art="ashenvale",wild={"treant","wolf","wisp"},boss="wisp",title="Moonwell Keeper",mechanic="shell",hint="A shell returns at half health. Break it with clicks or a boar.",need=20},
 {name="Un'Goro Crater",art="ungoro",wild={"raptor","ooze","whelp"},boss="raptor",title="Crater Alpha",mechanic="rush",hint="Only 25 seconds. Save Focus for a burst of damage.",need=24},
 {name="Burning Steppes",art="blackrock",wild={"imp","whelp","ghoul"},boss="whelp",title="Blackrock Matriarch",mechanic="fire",hint="Resists 70% of fire damage. Try beasts or arcane allies.",need=28},
 {name="Winterspring",art="winterspring",wild={"wolf","harpy","wisp"},boss="harpy",title="Frostwing",mechanic="frost",hint="Frost slows the crew. Your clicks and Power Strike stay fast.",need=32},
 {name="Silithus",art="silithus",wild={"spider","ooze","imp"},boss="spider",title="The Brood Empress",mechanic="swarm",hint="Swarm absorbs attacks. Fire and arcane deal +60% damage.",need=36},
 {name="Sky Citadel",art="citadel",wild={"ghoul","imp","whelp"},boss="whelp",title="The Hollow Sky",mechanic="shell",hint="Break two shields, then finish the last skyway guardian.",need=40},
}
F.relics={
 {id="fang",name="Moonfang Charm",description="Clicks +35%.",source="Defeat Bramblekeeper."},
 {id="banner",name="Pack Banner",description="Crew damage +25%.",source="Defeat Dustfeather."},
 {id="coin",name="Lucky Doubloon",description="Gold +30%; damage unchanged.",source="Open 5 treasure chests."},
 {id="lens",name="Moonwell Lens",description="Power Strike costs 65 Focus, not 100.",source="Defeat Moonwell Keeper."},
 {id="ember",name="Living Ember",description="Whelp burns deal double damage.",source="Defeat Blackrock Matriarch."},
 {id="hourglass",name="Sands of Rest",description="Away earnings +40%.",source="Complete 6 regional contracts."},
}
F.styles={balanced={name="Balanced",text="Normal click damage, crew damage and gold."},
 hunter={name="Hunter",text="Clicks +60%; crew damage -20%."},
 keeper={name="Keeper",text="Crew damage +40%; click damage -30%."},
 scavenger={name="Scavenger",text="Gold +40%; all damage -20%."}}
F.styleOrder={"balanced","hunter","keeper","scavenger"}
F.enemyNames={wolf="Timber Wolf",boar="Crag Boar",murloc="Murloc Forager",harpy="Storm Harpy",spider="Forest Spider",ghoul="Restless Ghoul",ooze="Jade Ooze",treant="Wild Treant",wisp="Wandering Wisp",raptor="Jungle Raptor",whelp="Red Whelp",imp="Cinder Imp"}
-- Regional trials ask for a different plan, not just a bigger repeated wave.
F.trials={
 {name="Tuskbreaker trial",hint="Bring a boar to break the guardian's armor.",require="boar"},
 {name="Steady crew trial",hint="No manual attacks. Crew and Power Strike must win.",noClicks=true},
 {name="Cleansing flame trial",hint="Bring a whelp to stop the guardian's regeneration.",require="whelp"},
 {name="Lone companion trial",hint="Bring exactly one companion; your clicks can help.",maxParty=1},
 {name="Caravan trial",hint="Bring a murloc; trade some damage for treasure.",require="murloc"},
 {name="Cold steel trial",hint="Leave the whelp resting. Fire is resisted here.",forbid="whelp"},
 {name="Patient hunter trial",hint="No Power Strike. Choose strong clicks or a trained crew.",noPower=true},
 {name="Arcane lantern trial",hint="Bring a wisp to pierce the swarm.",require="wisp"},
 {name="Skykeeper trial",hint="Bring three evolved companions (level 10+).",evolved=3},
}
