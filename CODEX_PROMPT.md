# Codex handoff

Read `AGENTS.md`, `README.md`, and `docs/` before editing.

## Mission
Turn the existing Pocket Buddy scaffold into a robust first playable Roblox vertical slice without
violating the portable-core architecture.

## Required first milestone
A fresh Baseplate synced with Rojo must support:
1. normal Roblox avatar in the backyard hub;
2. exactly one selected pet companion following the player;
3. visible Food / Clean / Happy + Friendship;
4. feed, wash, pet, and play interactions;
5. gentle needs decay with no death/punishment/power penalty;
6. one hidden Backyard Egg claimed only once per profile;
7. hatch station consuming exactly one owned egg and creating one procedural pet from the catalog;
8. newly hatched pet becomes selected and appears immediately;
9. private/published DataStore persistence with Studio session fallback;
10. multiplayer isolation so players cannot mutate one another’s pets, eggs, or care state.

## Then build King of the Couch
- 2–8 player queue and countdown;
- transition from Roblox-avatar hub mode into controlling the selected pet;
- universal controller foundation: move, jump, grab, carry, shove, throw, flop/get-up;
- couch arena elimination;
- server-authoritative round and winner;
- results/rematch;
- Party Egg reward;
- restore Roblox avatar + companion when returning to hub.

## Constraints
- `src/shared/core` remains free of Roblox services/Instances.
- Put platform bridges in adapters.
- Server owns rewards, hatching, ownership, rounds, and meaningful physics outcomes.
- Validate/rate-limit every remote.
- Never accept client-provided rewards, pet definitions, part IDs, final positions, or winners.
- Preserve the source-available license.
- No paid assets, secrets, or breeding yet.
- Prefer reliable simple code over framework sprawl.
- Fix obvious Luau/API issues in the scaffold before expanding it.
- Add pure core tests/fixtures where practical.
- Never claim Studio/runtime success unless actually Play-tested.
