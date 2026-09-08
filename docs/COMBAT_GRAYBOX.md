# PvP combat graybox

This branch is an isolated combat-feel prototype. It intentionally disables the normal demo world and builds a small graybox arena so the combat loop can be judged before mutations, progression, bosses, or art are added.

## Controls

| Action | Keyboard / mouse | Controller | Touch |
| --- | --- | --- | --- |
| Light combo | Mouse 1 | RT | HIT |
| Launcher | E | Y | UP |
| Block / perfect block | F | LT | BLOCK |
| Dash | Q | B | DASH |
| Toggle hard lock | Middle mouse | R3 | LOCK |
| Cycle target | Tab | — | — |

## Current combat slice

- Four-hit light combo with per-hit startup, recovery, stun, guard damage, knockback, and a knockback/ragdoll finisher hook.
- Small server-side input buffer so slightly-early M1 presses can still chain instead of being dropped.
- Server-authoritative victim selection. The client never sends a target ID, damage value, hit result, final position, guard result, or stun duration.
- Server overlap query with line-of-sight rejection and target ranking. The hitbox implementation is isolated in `HitboxService` so it can later move to bone-driven shapecasts without changing combo rules.
- Block, directional block validation, 160 ms perfect-block window, guard damage, guard break, and guard regeneration.
- Dash and launcher with server-owned cooldowns and impulses.
- Soft targeting based on camera angle, screen-center distance, world distance, LOS, and current-target stickiness.
- Hard lock, target cycling, target highlight, and gentle facing assistance.
- Desktop, controller, and touch bindings through `ContextActionService`.
- Small local FOV kick and local locomotion suppression during server-confirmed hitstun.

## Architecture

Portable rules live under `src/shared/core/combat` and do not call Roblox services or construct Instances:

- `CombatConfig.lua`
- `ComboRules.lua`
- `TargetingRules.lua`

Roblox adapters live outside the portable core:

- `src/server/services/CombatService.lua`
- `src/server/services/HitboxService.lua`
- `src/client/CombatController.lua`
- `src/server/world/CombatGrayboxBuilder.lua`

## Trust boundary

Combat requests are intents only. The server validates player state, cooldowns, attack timing, overlap results, LOS, block direction, perfect-block timing, guard, damage, stun, and physics impulses. Do not move any of those decisions to the client.

## Studio play-test checklist

Use **Test > Start** with at least two players.

1. Confirm each M1 advances exactly one step and resets after the combo window.
2. Mash slightly before recovery ends and verify the next hit is buffered rather than lost.
3. Stand just off-center and verify the attacker softly faces the intended opponent before M1.
4. Put two defenders close together and verify a normal M1 chooses one target, not both.
5. Put cover between players and verify attacks do not hit through it.
6. Hold F while facing the attacker and verify guard damage instead of health damage.
7. Tap F immediately before impact and verify the attacker is parried/stunned.
8. Drain guard and verify guard break occurs.
9. Verify Q dash respects movement direction and cannot be spammed.
10. Verify E launches the target upward.
11. Verify middle-click / R3 hard lock follows the target and Tab cycles candidates.
12. Verify touch buttons do not overlap Roblox core UI on phone/tablet emulation.
13. Verify controller inputs do not conflict with camera/navigation.
14. Test at realistic latency before tuning frame windows.

## Not yet claimed working

The repository rules require a real Roblox Studio Play test before runtime success can be claimed. This branch has been code-reviewed only in this session; combat feel, replication behavior, touch layout, physics ownership, and animation timing remain **unverified in Studio**.

## Next slice after feel is approved

1. Add authored combat animation hooks (`Light1`…`Light4`, `Launcher`, `Block`, `Dash`) without hard-coded paid asset IDs.
2. Replace box-at-impact melee with bone/attachment-driven sweep casts if the animation tests show tunneling or mismatch.
3. Add true ragdoll handling behind the existing `CombatRagdollUntil` hook.
4. Add mutation attack definitions (Crab Claw first) on top of this combat contract.
5. Add NPC combat targets after PvP feels correct.
