# Variants

## JSON-driven variant model

Variant behavior is defined by:

- `configs/variants.json`
- `configs/profile-variants.json`

`configs/variants.json` describes variant names, feature lists, and AK3 suffixes. `configs/profile-variants.json` controls which variants are enabled on each profile.

## Implemented variants

### KernelSU (tiann/KernelSU)

- `ksu`
- `ksu-bbg`
- `ksu-susfs`
- `ksu-susfs-bbg`

### KOWSU (KOWX712/KernelSU fork)

- `kowsu`
- `kowsu-bbg`
- `kowsu-susfs`
- `kowsu-susfs-bbg`

KOWSU is a kprobe-based KernelSU fork. It hooks into the syscall table at syscall entry
rather than using GKI vendor hooks. This requires a SUSFS integration fixup patch
(`patches/ksu/kowsu/`) that adapts the SUSFS sucompat functions to the kprobe calling
convention (`const char __user *` rather than `struct filename *`).

### KernelSU-Next (pershoot/KernelSU-Next)

- `ksu-next`
- `ksu-next-bbg`
- `ksu-next-susfs`
- `ksu-next-susfs-bbg`

KernelSU-Next SUSFS variants use the `dev-susfs` branch of the KernelSU-Next repository
instead of the default branch. The `KSU_NEXT_SUSFS_REF` env var overrides the branch.

### Base

- `vanilla`
- `bbg`

## Feature integration

- BBG is integrated through the upstream Baseband-guard `setup.sh`.
- KernelSU (`ksu`) is integrated through the upstream tiann/KernelSU `kernel/setup.sh` at `main`.
- KOWSU is integrated through KOWX712/KernelSU `kernel/setup.sh` at `master`, with a local SUSFS fixup patch applied after the upstream SUSFS patch.
- KernelSU-Next is integrated through pershoot/KernelSU-Next `kernel/setup.sh`. SUSFS variants use the `dev-susfs` branch.
- SUSFS is experimental, requires a KernelSU variant, and is integrated from Simonpunk GitLab: `https://gitlab.com/simonpunk/susfs4ksu.git`.
- SUSFS config is generated from the selected Simonpunk patch and resulting Kconfig symbols.
- CoreShift enables every discovered `KSU_SUSFS*` symbol in `common/features.fragment`.
- SUSFS variants are enabled only on profiles that already support the respective KernelSU variant.

Feature application order is:

1. `ksu` / `kowsu` / `ksu-next`
2. `susfs`
3. `bbg`

## 5.4 policy

- BBG is enabled on supported 5.4 profiles.
- KSU, KOWSU, and KSU-Next are disabled by default on 5.4 because current KernelSU `main` includes `linux/pgtable.h`, which is missing on the tested 5.4 ACK common trees.
- SUSFS remains disabled on 5.4 while all KernelSU variants are disabled there.

Users experimenting with 5.4 KSU can edit `configs/profile-variants.json` locally and pin `KSU_REF` to a known-good branch or commit.

## Pinning feature refs

Examples:

```bash
./scripts/build-kernel.sh android13-5.15-lts --variant ksu --build-env KSU_REF=<commit-or-tag>
./scripts/build-kernel.sh android13-5.15-lts --variant kowsu --build-env KOWSU_REPO=<url>
./scripts/build-kernel.sh android13-5.15-lts --variant ksu-next --build-env KSU_NEXT_REPO=<url>
./scripts/build-kernel.sh android13-5.15-lts --variant ksu-next-susfs --build-env KSU_NEXT_SUSFS_REF=<branch>
./scripts/build-kernel.sh android13-5.15-lts --variant bbg --build-env BBG_REF=<commit-or-tag>
./scripts/build-kernel.sh android13-5.15-lts --variant ksu-susfs --build-env SUSFS_REF=<branch-or-commit>
```

If `SUSFS_REF` is unset, CoreShift first checks `configs/susfs-refs.json`, then probes likely official branch names for the selected Android release and kernel version.

SUSFS config is variant-owned. It is written to `common/features.fragment`, not `configs/fragments/coreshift.fragment` or repo-root `private.fragment`.

## Feature Git metadata policy

- KernelSU, SUSFS, and Baseband-guard remain temporary Git checkouts during build.
- Those directories are excluded from the prepared workspace commit.
- `KernelSU/.git`, `SUSFS/.git`, and `Baseband-guard/.git` are kept during build for version metadata.
- Staged gitlinks and submodule-like `160000` entries are refused.
