# Flightbound 4.8.1 — Friendly duels and campaign leaderboards

A small, movable Game Boy-style creature RPG inside WoW Forever. The trainer
now walks an actual dungeon map. The room-card selection flow is replaced by
manual movement, fog of war, side passages, keys and sealed doors.

## Install or update

Extract the ZIP's `Flightbound` folder into `World of Warcraft/_forever_/Interface/AddOns/`.
The result must contain `Interface/AddOns/Flightbound/Flightbound.toc`, without
an extra nested folder. For a first install, restart WoW and enable Flightbound
in the character screen's AddOns list. To update, replace the existing addon
folder, then use `/reload` when convenient. Open with `/fb`.
The footer should read **V4.8.1**. Compatible with WoW Forever (interface 16001),
Windows and Linux through Wine/Proton. No external program is needed.
`/flightbound` and `/fbound` still work; `/fb` also accepts their subcommands.

**4.8.0 preserves your current campaign save.** It adds optional friendly duels
and a campaign leaderboard shared only with your friends and guildmates.

**4.8.1 compatibility fix:** Forever's first name and surname are now joined
correctly, instead of treating the surname as a realm. Contacts use regional
full names without internal server labels. Forever's always-true outgoing-chat
flag no longer blocks addon whispers; actual chat lockdown and send results
still apply. Setup retries when character data is delayed. No save reset.
Use `/fb linktest` for a self-whisper delivery check, and `/fb linkstatus` for
setup and send diagnostics. The test messages only your own character.

## Friendly duels

Both players need **Flightbound 4.8.1**, must be online in WoW Forever,
and must appear in each other's friends list or share a guild. Battle.net
friends count when their Forever character is available; previously
seen characters remain recognizable while that Battle.net friendship exists.

1. Finish your current campaign battle, then open `/fb friends` or
   **Menu → Friends / Guild**. Let discovery find your online contacts.
2. Choose a team of **one to three owned companion species**. Both teams must
   have the same size. All duel companions use their final form at **level 14**,
   with full HP, regardless of their campaign level or health.
3. Select **Duel** beside a ready contact. Your friend opens `/fb friends`,
   selects a matching team size and accepts. Invitations expire after a minute.
4. Take alternating turns using Strike, named Special, Defense, Swap and Focus.
   With keys enabled: **1** Strike, **2** Special, **3** Defense, **4** Swap,
   **5** Duel Menu, **6** Focus. Choose a replacement companion with the mouse.
   Press **Space** after the result to return to the club.

Duels use separate, temporary teams: they never consume campaign HP, items,
gold or XP, and grant no campaign rewards. A swap uses a turn; special and
defensive cooldowns stay with the team. Defeated companions automatically
switch to a surviving teammate. Initiative is chosen from both players'
session seeds. A 200-turn limit prevents endless matches.

The addon retries lost messages and validates each move on both sides.
A short `/reload` can recover through the saved turn journal. Closing the
window leaves the match running; **Duel Menu → Forfeit** leaves immediately.
Two minutes without a move ends the duel. Invitations appear in local chat
without automatically opening a window. No strangers are discovered or admitted.

## Friends and guild campaign leaderboard

Open `/fb leaderboard` or **Menu → Leaderboard**. The board contains only you
and current **friends OR guildmates**, with filters for each group. It removes
a contact's records when they leave both lists; strangers' records are rejected.

Online contacts exchange their own progress in the background. Cached records
remain visible offline with their last sync age. **Sync Now** refreshes discovery;
`/fb sync off` pauses sharing and `/fb sync on` resumes it. The same toggle is
in the club. Chat restrictions imposed by WoW pause the link automatically.

Rankings compare campaign completion, windstones, quests, rival milestones,
treasure and collection, in that order. Story, Adventure and Veteran have
separate boards under campaign rules 4.8. A run is classified by the easiest
difficulty observed since tracking began. Existing saves carry an asterisk
because their earlier difficulty history is unknown. Best progress is retained
per character and difficulty. This is a friendly, self-reported board, not a
tamper-proof competitive service; there is no global server or public ranking.

Social settings, cached records and the duel recovery journal live in
`FlightboundSocialDB`. Campaign progress remains in `FlightboundDB`.
The release has passed simulated two-client messaging and UI tests; actual
friend-to-friend delivery still needs confirmation with two online players.

## Battle presentation

The 4.7 effects remain. Damage numbers pop larger at impact,
rise and linger, with dark shadows for readability. Critical hits show gold
numbers, a CRITICAL label, pixel sparks, stronger recoil and a new short
chiptune sound. HP bars show a brief trailing damage chip. Knockouts, strong
type matchups, blocked hits and burn ticks have distinct feedback. Lingering
numbers never delay the next turn and clear when leaving the battle screen.

Critical hits are real: the top two of the 17 existing damage rolls deal
**1.5× damage**, about **11.8%** of direct attacks. The same rule applies to
your companions and enemies, including strikes and specials. Defense still
reduces damage; healing, burn ticks and taming cannot crit. No extra random
draw is added. Ordinary hit calculations and campaign rewards are unchanged.
Sound continues to respect the existing sound toggle. No save reset is needed.

The animated battles from 4.6 remain: strikes lunge,
flash on impact and show floating damage. Each of the 12 creature lineages
has its own four-frame pixel special: howls, tides, flames, tusks, venom,
roots, stars, claws, acid, firebolts, gusts and grave frost. Evolved forms
use larger effects, with a charge flash for their final form. Enemy attacks
use the same animations. Defense, focus and salves have shield, charge and
healing effects. HP updates at each impact; the enemy responds afterward.
Moves briefly lock while the turn plays, then return automatically.
Turns save immediately, so closing or reloading cannot undo an action.

Dungeon backdrops, colored creatures, numbered moves, cooldowns, immediate
naming and keyboard controls remain. A small footer credits the game:
**By Whitebeard Tinkerton - US PVP**.

The **KEYS: OFF / ON** button enables optional keyboard controls. Its preference
is saved, while focus starts released after closing or reloading the window.
After a battle, press **Space** to activate **Back to Map**, **Continue**,
**Finish Dungeon** or **Next Battle**. The focused window shows the current
Space action in its header. A fresh press is required; a held key cannot skip
the result or immediately interact with the map. Escape releases keyboard focus.
The addon and its bundled TGA textures work with WoW Forever on Windows and
Linux (Wine/Proton); no external runtime is required.

The window is 552×624 UI units, with
a full-width 520×360 exploration viewport. The default 40-unit tiles are 2.5×
larger than before; the map has 6.25× the display area. Movement and zoom
controls sit below the map, and the message panel takes less of the playfield.
Zoom **− / +** switches between 80%, 100% and 120% (32/40/48-unit tiles), saved
with your preferences. The map follows your trainer at every zoom. The full
dungeon chart uses 24-unit tiles; battles, menus and trainer creation display
at 1.5× their previous size. Window position, scale and progress carry over.

Version 4.0 included the user's requested one-time fresh start. It applies on
the next addon load, backs up the prior in-memory game in `FlightboundBackupDB`,
and resets companions, levels, gold, dungeon progress and trainer selection.
Window, sound and flight-opening preferences carry over; the new game starts
on the tougher **Adventure** setting. The reset token prevents another reset
on subsequent reloads. Live SavedVariables files are not edited outside WoW.

## Create your trainer

Choose a name, race, class and male/female gender before choosing your starter.
The class selector only offers combinations available to the selected race.
**Use My WoW Hero** reads your current character's name, race, class and gender
through normal WoW APIs and fills the form. You can then customize it. No live
WoW character data is modified. Your trainer uses a matching pixel avatar for
race and gender; class is shown in the profile and exploration HUD. This is a
pixel interpretation, not a copy of the live character's face or equipment.

The creation table follows [Blizzard's Forever character guide](https://news.blizzard.com/en-us/article/24304075/create-the-hero-you-want-to-be-in-world-of-warcraft-forever),
checked November 8, 2026. It includes Human, Dwarf, Night Elf, Gnome, Orc,
Undead, Tauren, Troll and both Skyborne faction choices: 56 race/class pairs,
each available to both genders. High Order Skyborne have Mage; Windshapers
have Shaman. New combinations such as Human Hunter, Dwarf Shaman, Gnome Priest,
Orc Mage, Troll Warlock and Undead Paladin are included.

Trainer identity is cosmetic; companions remain the combatants. **Menu →
Trainer** can edit your profile later. Cancel discards profile edits. The trainer
name field does not grab keyboard focus automatically and releases it when hidden.

## Manual dungeon exploration

Enter a dungeon and move with the on-screen arrows or click a tile immediately
beside your trainer. Each click moves **one tile**. Nothing walks automatically.
Optional keyboard controls work as described below. Walls block
movement. The view scrolls with the trainer; fog reveals nearby visible tiles.
**Dungeon Map** shows only places you have discovered.

### Zone themes and symbols

Each zone uses its own floors, walls, decorated wall variants, gates, stairs
and fog color, in both the scrolling playfield and the discovered-map screen:

| Dungeon | Environment |
| --- | --- |
| Goldshire Cellars | Sandstone, timber beams, barrels and lanterns |
| Westfall Mines | Dusty earth, rough rock, mining supports and ore |
| Drowned Ruins | Blue-grey ruins, broken columns, seaweed and teal accents |
| Moonwell Hollow | Mossy paths, purple stone, roots and crescent carvings |
| Lost Crater Temple | Ochre temple blocks, ferns, vines and eggs |
| Blackrock Warrens | Basalt, iron, chains, banners and lava fissures |
| Frostwing Hollow | Ice, snow, blue rock and crystals |
| The Silithid Nest | Sand, chitin, amber eggs and resin |

Proper filled-arrow sprites replace the old text arrows. Gold keys, closed and
opened chests, campfires, cracked walls and guardian badges are distinct pixel
symbols; the main map/team/menu controls also have icons. Looted chests remain
visibly open. Pressure plates have only a faint seam in the existing floor;
there is no bright X or warning marker. Appearance never changes collision,
map layout, discoveries or object interaction rules.

### Arrow keys and focus

- Click **KEYS: OFF** to turn it on, or click anywhere inside the window when
  ready. The bright border confirms focus. Moving the pointer away, clicking
  bottom buttons and navigating through menus or battles all retain it.
- Tap **Up / Down / Left / Right** to move one tile. These arrow presses are
  consumed by Flightbound instead of triggering WoW character movement.
- Tap **Space** to interact. **SPACE: INTERACT** is shown in the header when
  dungeon controls are active. Holding a captured key does not repeat its action.
- In battle, **1** = Strike, **2** = the creature's special, **3** = its defensive
  move, **4** = Bag / Team, **5** = Tame, and **6** = Focus. Top-row and numpad
  digits work. In the bag, numbers match its visible buttons: **1** Salve,
  **2** Swap Pet, **3** Flee, **4** Back. Select the pet to swap with the mouse.
  Disabled moves and inputs during an attack animation do not spend turns.
  All digits are captured while focused, including unused ones, so they cannot
  trigger WoW action buttons. Other keys keep their usual behavior.
- On a battle result, **Space** activates the main continuation button (including
  **Back to Map**); the header names the action. Arrows and Space remain captured
  on menus and during battle, without operating the dungeon or triggering WoW
  movement/jumping. After returning to the map, release Space before interacting.
- **Escape**, clicking outside, or closing the window releases focus. Already
  captured presses are consumed until release to avoid leaking repeats to WoW.
- Addon name fields temporarily take input; **Save**, **Skip** or finishing an
  edit resumes window controls automatically. External chat releases capture.
  WoW combat pauses capture; click the window afterward. No restricted input
  APIs are called during combat.
- If an arrow, Space or digit is already held before focusing, release it and
  click again; the addon does not take over a press that started in WoW.
- Click **KEYS: ON** to disable the feature, or use `/fb keys on|off`.
  The slash command changes the preference; click the window to take focus.

This uses an ordinary keyboard-enabled addon frame, with selective event
propagation and click focus. It never changes saved or override keybindings.
The implementation was checked against the Forever branch's
[frame API definitions](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua)
and the client's installed addons' use of these input APIs.

Explore the corridors and rooms to find:

- **Creatures and champions:** stepping onto them starts combat. Cleared
  encounters stay cleared, including after a reload or trip back to camp.
- **Chests:** stand on or next to one and press **Interact** for gold, a charm
  and a salve. Each chest is usable once per expedition.
- **A key:** pick it up with **Interact**, then find the sealed door.
- **The sealed door:** face it and press **Interact** to consume the key and
  open the passage. The door stays open.
- **Campsites:** **Interact** to restore 65% party HP. Each campsite is used once.
- **Cracked walls:** face one and **Interact** to find a secret passage.
- **Traps:** pressure plates cost 10% party HP once, without killing anyone.
- **The guardian:** stand on its tile and **Interact** when ready to fight.
- **Entrance stairs:** **Interact** to return to camp.

You can also use **Menu → Return to Camp**. Your discovered map, used chests,
keys, open doors and cleared encounters persist. Resume from the entrance with
those discoveries intact. At camp the team heals and basic supplies refill to
at least six charms and two salves. Closing the game simply pauses at your
current tile. Reloading restores that exact position and unfinished battle.

The boss's windstone opens the next dungeon. There is no required wild-win
counter, room-choice screen or automatic route. Earlier dungeons can be replayed
after completion. Eight windstones lead to the three-battle Sky Citadel finale;
finishing it unlocks the ending and endless arena.

## A more demanding game

**Adventure** is now the default: normal enemy attack power, 108% enemy HP and
only 4% party recovery after victory. Story remains a gentler option; Veteran
raises attack/HP further and has no normal victory healing. Only the very first
wild encounter receives reduced opening damage; bosses do not inherit that
protection. Enemy levels progress from 2 in the first dungeon to 23 in the last,
with bosses two levels above their area's creatures. The finale is level 26–28.

Level-ups restore the gained maximum HP plus 10%, rather than fully healing.
The defensive move blocks 65% of the next hit but gives no free healing. It
uses a turn, then needs two other completed turns before it is ready again.
The countdown is shared by the team for that battle, survives reloads, and
does not reset on a swap or faint. A new encounter starts it ready.
Salves restore 50% HP;
Tide/Grove specials restore 12%. Bedroll upgrades add 2% victory recovery per
rank. Camps and supplies matter, and fainted bench creatures do not revive from
ordinary post-battle recovery. Defeat returns you safely to camp without
removing your companions or exploration progress.

Strike is neutral damage. Specials display their actual ability names, update
on evolution, use type advantages, and have two intervening turns of cooldown.
Their second button line shows readiness, remaining turns and type advantage.
Defensive names match each lineage (Bubble Guard, Barkskin, Bone Armor, etc.);
all share the same blocking strength. A blue pulse and sound mark their use.
Watch the enemy's **NEXT** move: defense can soften specials, and Focus spends
a turn to strengthen your next special by 65%. Swapping takes a turn. Weaken wild
creatures and use Charm to recruit them; your first catch is guaranteed below
half HP. All companions share earned XP, with 65% for benched creatures.
Trivial enemies still stop awarding XP and ordinary battle gold. The level cap
is 30. Strongest-participant reward tracking prevents late-swap XP exploits.

## Evolution and names

Every lineage evolves at **level 6** and **level 14**. Evolution changes the
sprite, default name, special move name and combat stats. The first evolution
adds 8 HP, 2 attack and 1 defense; the final adds another 12 HP, 2 attack and
2 defense. These are in addition to ordinary level growth. Evolved specials
also have a higher damage multiplier. Enemies use the form for their level too.

| Base | Level 6 | Level 14 |
| --- | --- | --- |
| Timber Wolf | Dire Wolf | Moonfang |
| Murloc | Murloc Scout | Tidecaller |
| Red Whelp | Red Drake | Crimson Dragon |
| Crag Boar | Bristletusk | Ironhide |
| Forest Spider | Venom Stalker | Brood Queen |
| Young Treant | Barkguard | Grove Ancient |
| Wisp | Lantern Wisp | Astral Wisp |
| Jungle Raptor | Razorclaw | Devilsaur |
| Jade Ooze | Surging Ooze | Tidal Colossus |
| Cinder Imp | Flame Imp | Infernal Imp |
| Storm Harpy | Wind Harpy | Tempest Matriarch |
| Lost Ghoul | Gravewalker | Crypt Guardian |

Evolution is automatic. A short animated celebration appears after the battle;
queued celebrations survive reloading. **Menu → Evolutions** previews all three
forms. Each lineage occupies one collection slot; evolution does not duplicate
it or remove its identity.

**Team → Name** edits a companion's nickname (up to 16 characters). Enter saves;
Escape cancels. Clear the name to use its current form's name. Nicknames survive
both evolutions. The editor releases keyboard focus when closed.

Every successful new tame immediately opens **New Companion!**, before the
battle's Continue button. Type a name and press Enter/**Save Name**, or use
Escape/**Skip** to keep the normal species name. Saving a blank field also
keeps the species name. Existing companions are not prompted retroactively.
An unanswered prompt survives reloads and closing/reopening the game. Naming
does not repeat capture rewards or discard the battle result.

## Window, saves, assets and verification

Drag the title bar to move. `/fb scale 85` changes size, `/fb position` restores
its default location, `/fb sound on|off` controls chiptune effects, and
`/fb auto on|off` controls flight opening. `/fb difficulty story|adventure|veteran`
works outside combat. Optional arrow capture uses the **KEYS** toggle; WoW's
keybindings remain unchanged.
Sound uses WoW's Effects/SFX volume. A manually opened window stays open after
landing; an automatically opened one closes on landing. Hiding stops sounds
and animations. The window is 552×624 UI units; the existing scale setting
changes the whole window independently of the exploration zoom buttons.

Progress is account-wide in `FlightboundDB`; WoW writes it on clean logout or
`/reload`. Backup data is separate in `FlightboundBackupDB`. A client crash may
lose changes since its last disk save. No process memory or injection is used.

Headless checks cover all 112 trainer combinations, invalid combinations,
copying the live character profile, reset-once behavior, cancel/focus handling,
all eight maps, reachable keys, doors blocking the boss, fog, one-tile movement,
secret passages, loot/camp idempotency, saved map state, evolution and naming.
Combat tests compare tactical and Strike-only play. Twenty-four tactical
campaigns traverse the real corridors and complete the finale. One hundred eighty UI
layouts render with the actual font and assets, no text overflow, and stable
texture order. The 4.1 UI checks also cover zoom persistence, viewport edges,
tile click areas and transitions between the map and enlarged battle/menu
screens. The 4.2 checks simulate captured and propagated key events, all four
directions, repeat suppression, click focus, overlapping dialogs, Escape,
chat/text focus, combat entry/exit, held-key battle transitions, toggle-off,
missed key-up recovery and preference persistence. The 4.3 checks cover themed
objects in all eight zones, open chests, faint/spent plates, Space interactions,
whole-window focus through menus and battles, and capture naming/skip/reload.
The 4.4 checks cover all 36 named specials, defensive cooldown timing and save
migration, swapping, numbered/numpad actions, disabled moves, animation and
repeat suppression, numeric naming, and digit capture with chat/combat guards.
The 4.5 checks cover all nine battle backdrops, encounter-origin persistence,
victory/bag/menu transitions, low HP, and text/texture ordering over scenery.
The 4.6 checks exercise all 36 special presentations, enemy responses, impact
HP/damage timing, shields/focus/healing, knockouts, burn, forced swaps, fixed
effect pools and closing or changing screens mid-turn. Space continuation is
checked for focus, result visibility and held-key transitions. The renderer
checks 236 screens for text overflow and deterministic layer ordering.
The 4.7 checks cover exact critical damage/odds for both sides, guard reduction,
peak number size, HP chips, sound/mute, lingering numbers and cleanup. Another
1,440 noncritical actions match the previous release's save state and RNG use.
All 241 rendered screens pass text-overflow and layer-order checks.
The 4.8 checks add deterministic duels, two-client packet loss/duplication,
reload recovery, long journal replay, final-result acknowledgment, forfeit,
timeouts, contact removal, offline cache and native API adapter checks.
All 260 current UI screens pass overflow and layer-order checks, including
duel animations, keyboard continuation and campaign-save isolation.
The 4.8.1 adapter tests reproduce Forever's first/surname returns and a true
outgoing-chat flag, verify full-name whisper recipients and contact admission,
and exercise delayed login, actual chat lockdown, rejected sends and self echoes.
The complete campaign still clears in 24/24 tactical simulation runs.
These checks do not replace live-client testing.

The bundled creature, evolution, trainer, terrain, symbol, battle-background
and combat-effect textures were created with an image generator, then sliced
and resized with nearest-neighbor sampling into portable TGA files. Existing
sprite motion and chiptune sound are handled by the addon. Previews are rendered
from actual UI draw calls and isolated demo saves. The Silkscreen pixel font is
licensed under SIL Open Font License 1.1; see `Art/Silkscreen-OFL.txt`.
