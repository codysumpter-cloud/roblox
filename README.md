# Pocket Buddy

Roblox-first social creature game by Prismtek.

**Pitch:** collect little animals by playing with your friends, take care of them at home, then bring
them back out to play games together.

The repository is source-available under the Prismtek Source-Available License v1.0. Commercial or
monetized use requires a separate paid license.

## Game loop

```text
PLAY WITH FRIENDS
       ↓
DISCOVER / EARN EGGS
       ↓
      HATCH
       ↓
GET A WEIRD LITTLE ANIMAL
       ↓
FEED / WASH / PET / PLAY
       ↓
BRING IT INTO PARTY GAMES
       ↓
PLAY WITH FRIENDS
```

In the social hub, the player keeps their normal Roblox avatar and the selected pet follows as a
companion. In party games, the selected pet becomes the playable character.

## First playable target
- one backyard/playroom hub;
- one starter pet;
- Food / Clean / Happy needs;
- feed, wash, pet, and toy interactions;
- Backyard Egg, Play Egg, and Party Egg;
- procedural pet parts baked into the save format from day one;
- universal physical pet controller;
- first party mode: **King of the Couch**.

See `docs/GAME_DESIGN.md` and `docs/ROADMAP.md`.

## Architecture

```text
src/shared/core/        portable rules/data; no Roblox services or Instances
src/server/adapters/    DataStore, IDs, runtime model/platform bridges
src/server/services/    server-authoritative gameplay orchestration
src/server/world/       Roblox demo-world construction
src/client/             HUD/input/presentation
```

## Roblox Studio + Rojo
1. Install Rojo.
2. Clone this repository.
3. Run `rojo serve`.
4. Open a fresh Roblox Studio **Baseplate**.
5. Connect the Rojo Studio plugin.
6. Sync, then press Play.

The current scaffold builds a primitive backyard test world at runtime and uses generated placeholder
geometry until final art is supplied.

## Current status
**Source-backed:** initial product spec, portable schemas/rules, server services/adapters, runtime
placeholder pet, care/egg interactions, save schema, HUD, demo-world builder, and the initial
King of the Couch queue/controller/round foundation are in the repo. The couch foundation includes
server-owned intent validation, physical pet control, elimination, results, and Party Egg rewards.

**Unverified:** Roblox Studio runtime. This still needs its first Studio play test.

## License
Source-available, not open source. See `LICENSE`.
