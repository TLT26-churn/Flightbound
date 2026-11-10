# Release notes

## 4.9.1

- Fix a window-opening error from blank icon/button labels returning nil from WoW FontString:GetText. Both `/fb` and `/flightbound` can build the console again.
- Treat absent captions as empty when styling and hiding unused actions.
- Make the UI test harness reproduce nil empty FontStrings and cover both slash aliases on first open. No save or gameplay changes.

## 4.9.0

- Replace the detached controls with the Adventure Console: classic WoW framing, parchment headings, an attached companion bar, two rows of battle actions, and consistent title/sentence case.
- Hide enemy intent and choose attacks randomly after the player's action. Specials can open or repeat; the third attack is no longer scripted. Guard still blocks 65% and does not affect enemy attack odds.
- Add a secret and an open detour to each dungeon, with caches, encounters, traps and some extra camps. Keep every existing tile and saved position valid. Cache rewards do not inflate cargo leaderboards.
- Slow later leveling, cap enemy scaling around the strongest companion, strengthen later guardians and scale the finale. Keep the opening dungeon gentler and preserve existing levels/XP.
- Flee one safe tile back without healing; retain the expedition. Shop packs fill salves to six, preserving larger existing stocks and found salves.
- Add keyboard team selection, Space continuation through story/evolution/clear screens, accurate result labels, visible quest rewards and map progress. Automatic flight opening no longer focuses a pending nickname field.
- Preserve saves and quiet friend/guild messaging. Both duel players need the same addon version. One portable ZIP supports Windows and Linux (Wine/Proton).

Validated headlessly: 263 rendered screens with no text overflow or layer-order dependence; hidden-AI probability and timing checks; all three difficulties simulated; campaign/save, controls, critical-hit and two-client social regressions. Live-client verification of this UI remains outstanding.

## 4.8.2

- Stop blindly whispering every guild roster member; use a hidden guild-channel hello for discovery. Scores and duels stay private.
- Pause unreachable friend targets for five minutes, remove queued retries, and filter recent failed Flightbound whispers from chat. Preserve ordinary whisper errors and unrelated system messages.
- Show only online friends/guildmates detected running Flightbound in the duel list. Keep cached offline leaderboard scores.
- Add an invitation popup with Accept Duel, Choose Team, Decline, a countdown and a sound that respects the existing toggle. It works with the main window closed and never takes keyboard focus.
- Guard against duplicate/expired acceptance and recheck readiness before starting.
- Preserve campaign saves. Both players need 4.8.2 for duels. The same ZIP works on Windows and Linux (Wine/Proton).

Validated with simulated guild/friend messaging, localized error filtering, two-client duels, campaign regression checks and 263 rendered screens. Live two-player verification remains outstanding.

## 4.8.1

- Fix Forever's first-name/surname API handling, which prevented the link club from initializing.
- Address contacts by their regional full character names, without internal server/shard suffixes.
- Stop using Forever's always-true outgoing-chat flag as a blanket addon-whisper block. Continue respecting chat lockdown and actual send results.
- Retry initialization when character identity is not yet loaded.
- Replace the misleading realm-restriction message with a specific setup status.
- Add `/fb linkstatus` and a self-only `/fb linktest` diagnostic.
- Preserve campaign saves. Both players should update before trying duels or score sync.

Live self-whisper delivery verified on US PvP. Live friend-to-friend multiplayer remains unverified.

## 4.8.0

- Add friendly duels with teams of 1–3 owned species, normalized to level 14.
- Add campaign leaderboards for friends and guildmates only, with difficulty filters and offline cached scores.
- Add background discovery, move validation, retries, duplicate suppression and short-reload recovery.
- Keep duels isolated from campaign health, supplies, experience and progress.

## 4.7.0

- Add larger floating damage, critical hits, pixel bursts, recoil, damage trails and critical sound.
- Support Space to continue from battle results while keyboard focus is active.

## Earlier releases

- Expand the campaign into eight manually explored themed dungeons and a finale.
- Add trainer creation, naming, evolutions, colored sprites, sound, battle backgrounds and attack animations.
- Enlarge the play area and add optional keyboard control with focus and combat safeguards.
