# Verification checklist

## Studio smoke test
1. Sync a fresh Baseplate with Rojo.
2. Start one player and confirm no red Output errors.
3. Confirm normal Roblox avatar remains visible.
4. Confirm exactly one starter pet follows.
5. Confirm HUD matches active pet and needs.
6. Feed/wash/pet/play and confirm server state changes.
7. Find Backyard Egg and verify it cannot be claimed twice.
8. Hatch and verify egg count decreases once and pet count increases once.
9. Studio session fallback must not pretend to persist.
10. Publish a private test place and verify DataStore persistence.

## Multiplayer
Use Start Server with 2–4 clients:
- each player sees all companions;
- care only modifies the owner’s active pet;
- no player can hatch another player’s egg;
- rapid requests are throttled;
- reconnect does not duplicate rewards.

Never call runtime verified until actually Play-tested.
