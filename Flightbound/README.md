# Flightbound 5.0.0

A small animated idle clicker for WoW Forever (interface 16001).
Open it with **/fb**, **/flightbound**, or **/fbcamp**.

## Start here

1. Click the large creature. Its health drops; gold collects automatically when
   it is defeated. You can spend your first gold on a sharper blade or save 20
   gold to recruit your wolf.
2. Recruit the Timber Wolf. It visibly attacks on its own, including when you
   stop clicking. Train companions to improve their damage.
3. Use Power Strike when you have enough Focus. It is a large burst of damage.
4. Follow the objective above the scene. Defeat the guardian, then choose one
   regional contract to open the next skyway.

The main screen contains the fight and immediate upgrades. The buttons along its
bottom open separate Companions, World and Relics screens. Use Back to adventure
to return. Creature battles pause while you manage the party; crew idle earnings
continue. You can change crew, style or relics between boss attempts.

## Choices

Three of six companions can be active. Wolves mark prey for your clicks; boars
break armor; whelps burn and stop regeneration; murlocs increase gold; treants
improve away progress; wisps restore Focus. Companions evolve visually at levels
10 and 25. Look at a guardian's instruction before choosing your crew.

After Elwynn, choose a play style: Balanced, Hunter (stronger clicks / weaker crew),
Keeper (stronger crew / weaker clicks), or Scavenger (more gold / less damage).
Relics add another choice: one equipment slot initially, two after Darkshore.

Each region offers a patrol, treasure contract and a distinct elite crew trial.
A guardian plus any one contract opens the next region. The Sky Citadel requires
18 contracts. First clears do not exhaust the collection: 27 contracts, six relics
and the companion forms provide additional goals. This is a finite game; there is
no infinite arena or prestige reset.

## Sound and controls

Sound defaults **on**. The labeled header button toggles it. Sounds play only while
the window is visible, use WoW's Master channel, and respect the game's master
mute/volume. Attack sounds are throttled and the addon caps its own simultaneous
voices. It never changes WoW volume settings.

- /fb show or /fb hide
- /fb sound on, off, or test
- /fb auto on/off — optional flight-path opening, off initially
- /fb scale 90 — 65–130 percent
- /fb position — center the window
- /fb help

Drag the title bar to move; Escape closes. No keyboard focus is captured.
The crew earns progress while hidden and for up to eight hours per offline absence.
Your next opening summarizes the earnings. Bosses wait for your return.

## Install and saves

Extract the Flightbound folder into _forever_/Interface/AddOns/. Restart WoW to
recognize a newly installed folder, enable it in AddOns, then /fb. The same ZIP
works on Windows and Linux through Wine/Proton. Remove the old FlightboundCamp
prototype folder if present; it is not a dependency.

Version 5 starts a fresh idle adventure in FlightboundIdleDB. The prior RPG and
camp saves are not imported or erased. A one-time fresh-start token preserves any
pre-release idle save in FlightboundIdleBackupDB before starting from the first
creature. Later reloads preserve this new adventure. Clean logout/reload writes
SavedVariables; force-quitting can lose unsaved progress.

Whitebeard Tinkerton - US PVP
