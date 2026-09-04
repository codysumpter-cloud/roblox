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
src/shared/avatar/      portable humanoid/GASP semantic contracts
src/server/adapters/    DataStore, IDs, runtime model/platform bridges
src/server/assets/      Studio-package inventory/curation policy
src/server/services/    server-authoritative gameplay/admin/event orchestration
src/server/world/       Roblox demo-world construction
src/client/             HUD/input/presentation/animation adapters
```

See `docs/ROBLOX_AVATAR_GASP.md` for the VRoid/Unreal -> Advanced R15/GASP path and
`docs/STUDIO_PACK_INTEGRATION.md` for the non-destructive ServerStorage/Admin V5 integration policy.

## Roblox Studio + Rojo
1. Install Rojo.
2. Clone this repository.
3. Run `rojo serve`.
4. Open the canonical published Pocket Buddy place (Studio B, PlaceId `130948128859629`)
   or a fresh Baseplate for a fallback smoke test.
5. Connect the Rojo Studio plugin.
6. Sync, then press Play.

The runtime builder layers care, egg, hatch, and couch gameplay objects onto the authored world; it
does not replace Terrain or grass. The first runtime template is `Pug`, resolved from the
Studio-managed `ServerStorage/PocketBuddyAssets/Pets/Pug` path and normalized at clone time. A
missing template safely falls back to generated placeholder geometry.

Studio-managed imported packs are intentionally outside Rojo ownership. The server inventories
those packages without mutating them, promotes presentation assets through explicit adapters, and
only executes explicitly approved legacy event packages. Global time/weather/Lighting are owned by
one canonical environment service so imported packs cannot accidentally create competing skies or
clock/weather loops.

## Current status
**Source-backed:** initial product spec, portable schemas/rules, server services/adapters, Pug runtime
asset adapter, care/egg interactions, save schema, HUD, authored-world-safe gameplay builder, and the
initial King of the Couch queue/controller/round foundation are in the repo. The couch foundation
includes server-owned intent validation, physical pet control, elimination, results, and Party Egg
rewards.

The repo now also contains a portable GASP semantic manifest matching the Godot integration,
Advanced R15/Adaptive Animation source-rig preflight, a Roblox GASP locomotion adapter that retains
stock animation as its incomplete-catalog fallback, Studio package inventory/curation, one
canonical weather/time owner, validated creator/group-owner admin commands, and an approved legacy
Admin V5 event path with **Raining Tacos** as the first registered event.

**Unverified:** Roblox Studio runtime. Studio-only imported packages, their script contents, actual
GASP Animation asset IDs, custom-avatar Adaptive Animation mappings, and event execution still need
Play-mode verification in the canonical place. Do not call these runtime verified from GitHub alone.

## License
Source-available, not open source. See `LICENSE`.
