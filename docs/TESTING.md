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

## Studio-managed package inventory
1. Open the canonical authored place, not a fresh Baseplate.
2. Confirm Output prints one `Studio package candidate` line for each useful imported top-level pack.
3. Inspect `ReplicatedStorage/PocketBuddy/StudioPackageInventory` and confirm code-bearing packs are
   represented with Script/LocalScript/ModuleScript counts.
4. Confirm the original ServerStorage packs and their scripts are still present and unchanged.
5. Confirm `RuntimeAssetReport` reports any discovered weather, FX, admin UI, event, and humanoid
   animation assets.

## Environment ownership
1. Confirm exactly one Sky, Atmosphere, BloomEffect, SunRaysEffect, and ColorCorrectionEffect remain
   under Lighting after server start.
2. Confirm exactly one Clouds object remains under Terrain.
3. Confirm `EnvironmentState.TimeOwner == "PocketBuddy.EnvironmentService"` and
   `WeatherOwner == "PocketBuddy.EnvironmentService"`.
4. Cycle Clear, Cloudy, Rain, Storm, Fog, and Snow from the admin UI.
5. Confirm imported rain/snow/fog/lightning presentation assets are used when present.
6. Confirm time/weather changes do not spawn a second sky, second clock loop, or second weather loop.

## Admin V5 / admin-abuse events
1. Confirm a non-admin client cannot execute `AdminCommand`.
2. Press F8 as the creator/group owner and confirm the admin panel opens.
3. Confirm the imported Admin V5 panel is used as the visual skin when present; otherwise the
   fallback panel is shown.
4. Trigger **Raining Tacos**.
5. Confirm `EnvironmentState.TacoRain` changes for every client and the event stops/toggles cleanly.
6. Confirm sanitized imported taco meshes/audio are used when present.
7. Confirm no Script, LocalScript, or ModuleScript was copied into ReplicatedStorage runtime assets.
8. Confirm no vendor Script is enabled or cloned into ServerScriptService by the event.
9. Confirm unrelated imported source packages remain untouched in ServerStorage.
10. Locate and quarantine the previously observed malicious glitch/PNG source in Studio by exact
    path/fingerprint; do not enable that package or delete unrelated pack scripts.

## Advanced avatar / GASP
1. Put one VRoid/Unreal/Prismtek-derived model at
   `ServerStorage/PocketBuddyAssets/Avatars/<Name>`.
2. Confirm `AvatarAssetService` reports its required joint mapping and digit count.
3. Import the source as a Custom Humanoid and run Avatar -> Adaptive Animation -> Create.
4. Verify HumanoidRigDescription and both hand DigitsRigDescription mappings/T-pose in Studio.
5. Place published GASP Animation objects under
   `ServerStorage/PocketBuddyAssets/HumanoidAnimations` with semantic names/attributes.
6. With an incomplete animation set, confirm the stock Roblox `Animate` LocalScript remains enabled.
7. With the full required set, confirm `PocketBuddyGaspReady == true`, provider is `GASP_UEFN`, and
   idle/walk/jog/sprint/start/stop/pivot/jump/fall/land transition without obvious snapping.
8. Verify at least one finger-rich target animates correctly where the source/published animation
   contains finger motion.
9. Do not call a custom body Marketplace-ready until Avatar Setup/validation passes separately.

## Multiplayer
Use Start Server with 2–4 clients:
- each player sees all companions;
- care only modifies the owner’s active pet;
- no player can hatch another player’s egg;
- rapid requests are throttled;
- admin commands remain creator/group-owner only;
- environment state is consistent for all clients;
- reconnect does not duplicate rewards.

Never call runtime verified until actually Play-tested.
