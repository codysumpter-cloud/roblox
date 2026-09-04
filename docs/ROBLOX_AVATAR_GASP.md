# Roblox Advanced R15 + Prismtek GASP pipeline

## Goal

Roblox is a runtime/distribution target for the same humanoid source assets used by the Prismtek
Godot stack. Do not create a second character canon or a second animation naming system.

```text
VRoid / Unreal / Prismtek source character
                |
                v
       canonical humanoid source
                |
      +---------+----------+
      |                    |
      v                    v
    Godot                Roblox
One Rig runtime      Custom Humanoid import
GASP retargeting     Adaptive Animation mapping
```

## Shared GASP contract

`src/shared/avatar/GaspManifest.lua` mirrors the promoted Godot GASP semantics:

- idle
- walk
- jog / run
- sprint
- start / stop
- pivot_left / pivot_right
- jump / fall / land
- hurdle
- vault_low / vault_high
- mantle

The source clip names remain the original UEFN/GASP names. Roblox-specific asset IDs are runtime
artifacts and must never replace the semantic/source names as the canonical contract.

## Advanced R15 preflight

`src/shared/avatar/HumanoidRigContract.lua` describes aliases for Prismtek/Godot-humanoid and
UEFN-style bone names. `AdvancedAvatarAdapter` inspects Studio-managed avatar models without
changing the source rig and records how much of the Roblox humanoid/digit contract can be mapped.

For local source files, run:

```bash
python3 tools/validate_roblox_avatar_glb.py Character.glb
```

A PASS means the source contains enough recognizable joints to continue through Roblox Adaptive
Animation setup. It does **not** mean Marketplace-ready.

## Studio import

1. Import the rigged FBX/glTF through Studio's 3D Importer as a **Custom** rig.
2. Use **Avatar -> Adaptive Animation -> Create**. Roblox generates a `HumanoidRigDescription`
   plus one `DigitsRigDescription` for each articulated hand.
3. Verify the required body joints, optional Spine/Chest/Clavicle/HeadBase/ToeBase joints, and
   finger joints against the source rig.
4. Set/verify the baseline T-pose in Studio.
5. For a platform avatar body, run Avatar Setup and Roblox validation for body partitioning,
   attachments, cages, face requirements, and Marketplace constraints.

Do not programmatically fake Marketplace readiness. Roblox's Studio tooling owns the final rig
mapping/T-pose and avatar validation.

## Studio asset catalog

Imported custom avatars should live under:

```text
ServerStorage/PocketBuddyAssets/Avatars/<CharacterName>
```

`AvatarAssetService` scans this catalog and reports whether each model has enough mapped source
joints for the Adaptive Animation path. The source model stays untouched.

## GASP animation assets

Roblox cannot execute Unreal PoseSearch/Animation Blueprint state. We reuse the animation corpus
and semantic behavior boundary instead.

Published Animation instances go under:

```text
ServerStorage/PocketBuddyAssets/HumanoidAnimations/
```

Name each `Animation` with either the semantic (`idle`, `walk`, `sprint`, etc.) or the untouched
GASP source clip name. Prefer setting a string attribute named `Semantic` to the portable semantic.
`StudioAssetBridge` promotes only published `Animation` instances into the replicated runtime
catalog.

`GaspHumanoidController` does **not** disable Roblox's stock `Animate` script unless every required
locomotion asset is present and can be loaded. A clean checkout therefore continues to use normal
Roblox animation instead of breaking the avatar.

When the full set is available, the controller owns:

```text
movement context
  -> start/stop/pivot transitions
  -> idle/walk/jog/sprint loops
  -> jump/fall/land
  -> Roblox Animator
```

Player physics remains authoritative. The promoted GASP subset used by the Godot project is
in-place, so animation must not drive authoritative character position.

## Marketplace/avatar-body boundary

A game-local Custom Humanoid and a Marketplace avatar body are related but not identical targets.
Marketplace publication additionally requires Roblox body/avatar validation and moderation. Never
label a Studio-imported model Marketplace-ready based only on bone mapping.

## Definition of success

Roblox-side integration is runtime verified only after a Studio test proves:

- a VRoid/Unreal-derived custom character imports and moves as a Custom Humanoid;
- Adaptive Animation remaps the rig without exploding/deforming it;
- finger articulation works where the source has fingers;
- the published GASP subset plays on the target character;
- stock `Animate` remains the fallback if the GASP catalog is incomplete;
- hub gameplay still uses the player's normal Roblox avatar unless the product explicitly chooses
  a custom StarterCharacter/avatar body.
