# Studio-managed pack integration

## Rule

Imported pack scripts are **candidate systems**, not disposable junk.

The repository must preserve Studio-managed source packages intact, inventory what they contain,
and integrate useful behavior behind explicit runtime owners. Only content with specific evidence of
being malicious should be quarantined or removed.

This matters because `default.project.json` intentionally does not own `ServerStorage`: Rojo code
must not erase manually imported models, animation packs, admin packs, weather packs, or effects.

## Runtime layout

```text
ServerStorage
  imported/source packages (untouched)
          |
          +--> StudioPackageInventory (read-only report)
          |
          +--> StudioAssetBridge
                 sanitized presentation/runtime clones only
```

`StudioPackageInventory` reports code-bearing and presentation-bearing top-level packages into
`ReplicatedStorage/PocketBuddy/StudioPackageInventory`. It does not modify source content.

`StudioAssetBridge` makes safe runtime copies of weather/VFX/audio/UI presentation assets. Scripts
are removed from **those presentation copies only**; useful behavior is reimplemented behind the
repository-owned service/controller boundary. The original ServerStorage packages are never stripped.

Imported `Sound` instances are also inert by default. An exact source Sound must carry the boolean
attribute `PocketBuddyApprovedAudio = true` before the bridge will promote it. Name matching alone
must never start global audio; this prevents noisy loops or replacement music from free-model packs
while leaving their source assets intact for review.

## Single-owner systems

Do not run two independent systems that continuously write the same global state.

Current canonical owners:

- time of day: `PocketBuddy.EnvironmentService`
- weather state: `PocketBuddy.EnvironmentService`
- Lighting Sky/Atmosphere/post effects: `PocketBuddy.EnvironmentService`
- Terrain Clouds: `PocketBuddy.EnvironmentService`
- admin authorization/command validation: `PocketBuddy.AdminService`
- admin event state/lifecycle: `PocketBuddy.WorldEventService`

A weather/time pack can still contribute particles, sounds, palettes, transitions, effects, and
special-event code. Its continuous global loop should be adapted behind `EnvironmentService`
instead of fighting another loop for `Lighting.ClockTime`, `Sky`, `Atmosphere`, or `Clouds`.

## Admin V5 / admin-abuse events

Admin-abuse events are intentional promotional/hype features. They are not treated as ordinary
weather and they are not globally enabled on server boot.

The imported Admin V5 panel and Raining Tacos assets are treated as presentation sources. Runtime
clones have Script, LocalScript, and ModuleScript descendants removed. The repository-owned
`AdminService` validates authorization and commands, while `WorldEventService` owns the replicated
event state. `WorldEventController` may use sanitized imported meshes and sounds without executing
unknown vendor code.

## Malicious-content boundary

One infected free-model script has already been observed in the authored place by its behavior: it
created two unwanted/unselectable PNG-style glitch visuals in the map. Its exact source path/name or
asset fingerprint is not represented in GitHub, so this branch does **not** guess at a signature and
does not delete unrelated scripts to compensate.

Unreviewed executable packages are never enabled by name or folder location. Identify the exact
offending source in Studio and quarantine that source specifically. Preserve unrelated source packs
for inspection, then port useful behavior behind a repository-owned, validated service rather than
mass-enabling or mass-deleting vendor scripts.

## Current Studio paths

Preferred organization for manually imported content:

```text
ServerStorage/PocketBuddyAssets/
  Pets/
  Avatars/
  HumanoidAnimations/
  WeatherAssets/   (or Weather/)
  FXLibrary/
  AdminV5/         (recommended; discovery also tolerates common Admin V5 names elsewhere)
```

These paths are conventions for discoverability, not Rojo-owned folders.

## Definition of runtime verification

GitHub/source review can establish that discovery, ownership, authorization, and fallback logic are
wired. It cannot prove what Studio-only packages contain or whether their bundled scripts work.
Runtime verification requires opening the canonical place and confirming the inventory/output plus
each approved package's behavior in Play mode.
