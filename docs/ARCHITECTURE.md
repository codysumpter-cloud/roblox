# Architecture

## Dependency rule
```text
Portable Core
     ↑
Server Services
     ↑
Roblox Adapters / Runtime
```
The portable core never depends on Roblox.

## Portable core
`src/shared/core` owns pet schema, procedural generation, physical traits, needs/care math, egg
definitions/hatching, round-state rules, and save schema/migrations. Keep it deterministic where practical.

## Roblox server
Server services own authoritative profiles, pet ownership/selection, care validation, egg rewards,
hatching, companion spawning, party queues/rounds, and persistence.

Adapters isolate DataStoreService, GUID generation, Roblox Instances/models, avatar switching, and
physics/network ownership.

## Client
Client owns HUD, interaction feedback, animation/VFX/audio presentation, and input intent.
It does not decide rewards, ownership, successful hatches, needs values, or winners.

## Assets
Blender/source art remains canonical. Imported Roblox assets are runtime artifacts.

## Networking
Clients send intents only. The server verifies state, proximity, cooldown/rate limit, ownership, and
round phase. Never accept client-supplied currency, reward amount, pet definition, part IDs, final
position, or winner as authoritative.
