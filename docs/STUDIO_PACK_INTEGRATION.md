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
          |      presentation/runtime clones only
          |
          +--> LegacyAdminEventService
                 explicitly approved executable event packages only
```

`StudioPackageInventory` reports code-bearing and presentation-bearing top-level packages into
`ReplicatedStorage/PocketBuddy/StudioPackageInventory`. It does not modify source content.

`StudioAssetBridge` makes safe runtime copies of weather/VFX/audio/UI presentation assets. Scripts
are removed from **those presentation copies only** because execution remains attached to the
source package's integration path. The original ServerStorage packages are never stripped.

## Single-owner systems

Do not run two independent systems that continuously write the same global state.

Current canonical owners:

- time of day: `PocketBuddy.EnvironmentService`
- weather state: `PocketBuddy.EnvironmentService`
- Lighting Sky/Atmosphere/post effects: `PocketBuddy.EnvironmentService`
- Terrain Clouds: `PocketBuddy.EnvironmentService`
- admin authorization/command validation: `PocketBuddy.AdminService`
- admin event package lifecycle: `PocketBuddy.LegacyAdminEventService`

A weather/time pack can still contribute particles, sounds, palettes, transitions, effects, and
special-event code. Its continuous global loop should be adapted behind `EnvironmentService`
instead of fighting another loop for `Lighting.ClockTime`, `Sky`, `Atmosphere`, or `Clouds`.

## Admin V5 / admin-abuse events

Admin-abuse events are intentional promotional/hype features. They are not treated as ordinary
weather and they are not globally enabled on server boot.

`LegacyAdminEventRegistry.lua` is the executable allowlist. `RainingTacos` is the first registered
event. On an authorized admin request:

1. find the matching package in ServerStorage, preferring a parent named like Admin V5;
2. require that it contains a server Script and stays under a code-count ceiling;
3. clone the entire approved package without deleting LocalScripts or ModuleScripts;
4. temporarily hold server Scripts disabled until the clone is fully parented;
5. enable the package's server Scripts;
6. automatically destroy the runtime clone after the configured maximum duration;
7. never launch another package merely because it happens to contain scripts.

The repo's synthetic taco effect is only a clean-checkout fallback when the real Admin V5 package
is not present. When the real event is available it owns presentation and the fallback is disabled,
preventing duplicate taco systems.

## Malicious-content boundary

One infected free-model script has already been observed in the authored place by its behavior: it
created two unwanted/unselectable PNG-style glitch visuals in the map. Its exact source path/name or
asset fingerprint is not represented in GitHub, so this branch does **not** guess at a signature and
does not delete unrelated scripts to compensate.

Before enabling an unreviewed executable package in production, identify the exact offending source
in Studio and quarantine that source specifically. Do not respond by mass-deleting every script in
the imported packs; that destroys legitimate systems and makes later integration impossible.

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
