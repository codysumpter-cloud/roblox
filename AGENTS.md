# Pocket Buddy repository instructions

## Product
Pocket Buddy is a Roblox-first social creature game:
- play with friends;
- discover/earn eggs through activities;
- hatch procedurally assembled little animals;
- care for them in a home/backyard hub;
- enter party games where the pet becomes the playable character.

The target feeling is simple, physical, funny, social, and immediately readable.
Do not turn this into a stat-heavy battler, MMO, or egg-machine simulator.

## Architecture contract
`src/shared/core` is portable game logic. It MUST NOT call Roblox services or construct Roblox Instances.
Prefer plain tables, numbers, strings, booleans, and pure functions.

Roblox-specific work belongs in adapters/services under `src/server` or controllers under `src/client`.
Models, textures, animations, and audio remain externally authored source assets; Roblox is a
runtime/distribution target, not the source of truth for the IP.

## Gameplay rules
- The normal Roblox avatar is used in the social hub.
- The pet is a companion in the hub.
- In party games, the player controls their selected pet.
- Care never provides competitive power and never kills/punishes a pet.
- Rare pets are not inherently stronger than common pets.
- Body-part traits should be small, legible physical differences.
- Eggs should primarily be earned through play/discovery, not purchased RNG.
- Keep controls universal: move, jump, grab, carry, shove, throw, flop/get-up.

## Engineering
- Server-authoritative networking for rewards, care, inventory, hatching, rounds, and meaningful physics.
- Validate and rate-limit every client request.
- Never trust client-provided rewards, ownership, pet parts, stats, target IDs, or final positions.
- Keep save migrations versioned and backward-compatible.
- Do not add external packages unless they clearly reduce complexity and are documented.
- No secrets, API keys, private endpoints, or paid asset IDs in the repository.
- Prefer a small number of cohesive services over framework sprawl.

## Verification
Never claim Roblox runtime success without a Studio play test. Static review, formatting, and
pure-module tests may be called locally verified; Studio behavior remains unverified until run.
