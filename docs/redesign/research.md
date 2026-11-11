# Research behind the 5.0 redesign

The camp prototype made the player interpret several resource counters before
anything interesting happened. Click effects were minimal and sound defaulted
off. Feedback from its first test was explicit: unclear play, little animation,
no sound, and later a cluttered combined combat/equipment screen.

Three primary product descriptions informed the redesign:

- [Clicker Heroes](https://clickerheroes.com/) describes a direct loop of clicking
  monsters, collecting gold, hiring/upgrading heroes and progressing through
  bosses, with heroes earning while the player is away. Applied here: one visible
  enemy, immediate damage and gold feedback, a first companion purchase, automatic
  attacks and a persistent next objective. We did not adopt its unlimited numeric
  escalation as a substitute for authored goals.
- [(the) Gnorp Apologue](https://store.steampowered.com/app/1473350/the_Gnorp_Apologue/)
  emphasizes visible resource generation/collection and different units, upgrades,
  talents and status effects that support builds. Applied here: companion attacks
  are visible, loot travels to the gold counter, and crew composition changes
  mechanics. Boars, whelps, wisps and support creatures have distinct functions.
- [Mr. Mine](https://store.steampowered.com/app/1397920/MrMine/) emphasizes discovery,
  hidden encounters, relics and newly unlocked mechanics. Applied here: regions
  introduce boss counterplay, new companions, relics and regional crew trials.

These are design inferences from the official descriptions, not a claim that
we played or benchmarked those products. Their artwork, audio and code were not
copied. Flightbound's established assets were reused.

## Interface revision after the second screenshot review

The player identified clutter in the screen that combined combat, four tabs,
upgrades, play style and six relics. Management now uses dedicated screens.
The adventure shows one objective, one click target, Power Strike, the next
progression action and two upgrades. Companions, World and Relics have their own
layout and an explicit Back button. Redundant attack controls and repeated scene
instructions were removed.

## Progression limits and evidence

Tests found both an initial minutes-long rush and a later steep final-region
cost cliff. Prices/rewards were adjusted, and progression now includes a choice of
regional contracts rather than only chained first-clear bosses. The final region
requires 18 contracts. Nine elite trials impose different party/skill constraints.
No reset or endless arena is presented as the remaining game.

Current deterministic controllers clear the skyways in about 58 minutes at two
taps/sec, 17 minutes at sustained six taps/sec, or 94 minutes with crew-led combat
and active upgrade/skill decisions. Those are optimized synthetic policies, not
human playtime promises. The fastest policy remains deliberately much faster than
occasional attention. It does not complete all contracts, trials, relics or forms.
A finite game can still be finished; these results do not establish weeks of
content. All nine elite trials are separately checked for legal completion.

Offline progress has an eight-hour absence cap, finite resource limits and a
clock high-water mark. Tests compare bulk away time with many short intervals,
check reload and fresh-start behavior, and verify no live-world control APIs are
called. Visual tests render actual Lua UI calls and animation frames. Sound files
were decoded and checked for non-silent peaks. Live WoW playtesting remains a
separate validation step; development and installation did not drive the client.
