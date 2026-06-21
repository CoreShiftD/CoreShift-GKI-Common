# Build guide

## One-command local build

Install host tools:

```bash
./scripts/install-build-tools.sh
```

Build a profile:

```bash
./scripts/build-kernel.sh android12-5.10-lts
```

Build a profile with a variant:

```bash
# KernelSU (tiann)
./scripts/build-kernel.sh android12-5.10-lts --variant ksu-bbg
./scripts/build-kernel.sh android12-5.10-lts --variant ksu-susfs
./scripts/build-kernel.sh android12-5.10-lts --variant ksu-susfs-bbg

# KOWSU (KOWX712 fork)
./scripts/build-kernel.sh android12-5.10-lts --variant kowsu
./scripts/build-kernel.sh android12-5.10-lts --variant kowsu-susfs-bbg

# KernelSU-Next
./scripts/build-kernel.sh android12-5.10-lts --variant ksu-next
./scripts/build-kernel.sh android12-5.10-lts --variant ksu-next-susfs-bbg
```

## Building from a date branch

Build against the latest monthly ACK snapshot instead of the LTS tip:

```bash
./scripts/build-kernel.sh android15-6.6-lts \
  --build-env KERNEL_SOURCE_BRANCH_OVERRIDE=android15-6.6-2026-06
```

`KERNEL_SOURCE_BRANCH_OVERRIDE` replaces the profile's default `kernel_source_branch`
at workspace setup time. The profile still controls toolchain, build backend, and LTO.

## Building from a custom kernel source

Point the build at a different git repository entirely:

```bash
./scripts/build-kernel.sh android15-6.6-lts \
  --build-env KERNEL_COMMON_URL=https://github.com/your/kernel.git \
  --build-env KERNEL_SOURCE_BRANCH_OVERRIDE=your-branch
```

`KERNEL_COMMON_URL` overrides the upstream ACK URL used during `repo` manifest sync.
Use this with any profile whose toolchain and build backend match the custom source.

## Feature refs

Pin a SUSFS ref:

```bash
./scripts/build-kernel.sh android12-5.10-lts --variant ksu-susfs \
  --build-env SUSFS_REF=<branch-or-commit>
```

Pin KernelSU, KOWSU, KernelSU-Next, or BBG:

```bash
./scripts/build-kernel.sh android13-5.15-lts --variant ksu \
  --build-env KSU_REF=<commit-or-tag>

./scripts/build-kernel.sh android13-5.15-lts --variant kowsu \
  --build-env KOWSU_REPO=https://github.com/KOWX712/KernelSU.git

./scripts/build-kernel.sh android13-5.15-lts --variant ksu-next-susfs \
  --build-env KSU_NEXT_SUSFS_REF=dev-susfs

./scripts/build-kernel.sh android13-5.15-lts --variant bbg \
  --build-env BBG_REF=<commit-or-tag>
```

Enable Droidspaces support on a GKI profile:

```bash
./scripts/build-kernel.sh android15-6.6-lts \
  --build-env DROIDSPACES_ENABLE=1
```

Select a different pre-6.12 SYSVIPC kABI slot if needed:

```bash
./scripts/build-kernel.sh android13-5.15-lts \
  --build-env DROIDSPACES_ENABLE=1 \
  --build-env DROIDSPACES_SYSVIPC_KABI_SLOT=3_4_5
```

## `build-kernel.sh` usage

```
scripts/build-kernel.sh <profile-name>
  [--workspace DIR]
  [--mode auto|google_build_sh|kleaf]
  [--variant VARIANT]
  [--skip-setup]
  [--clean]
  [--skip-ak3]
  [--no-commit-workspace]
  [--disable-defconfig-check on|off]
  [--disable-kmi-check on|off]
  [--build-env KEY=VALUE]
  [-- EXTRA_BUILD_ARGS...]
```

The script resolves the profile, prepares or reuses `.work/<profile>`, sets up the
manifest workspace unless `--skip-setup` is used, applies feature fragments, runs the
selected build backend, collects artifacts into `dist/<profile>/`, and packages an
AnyKernel3 zip unless `--skip-ak3` is used.

## Local `private.fragment`

Copy the example and edit locally:

```bash
cp configs/fragments/private.fragment.example private.fragment
```

`private.fragment` lives at repo root, is gitignored, and is layered into the generated
workspace fragments during setup.

## Installing host tooling

`./scripts/install-build-tools.sh` installs the normal Ubuntu build packages, Arm64
cross-libc headers, `ccache`, and the upstream `repo` launcher in `$HOME/.local/bin/repo`.

## Build environment passthrough

`--build-env KEY=VALUE` passes values through to the build flow. Common examples:

| Key | Purpose |
|---|---|
| `KERNEL_COMMON_URL` | Override upstream ACK git URL (custom kernel source) |
| `KERNEL_SOURCE_BRANCH_OVERRIDE` | Override kernel source branch (date branch or custom) |
| `LTO` | Override LTO mode (`full`, `thin`, `none`) |
| `KSU_REF` | Pin KernelSU (tiann) ref |
| `KOWSU_REPO` | Override KOWSU repo URL |
| `KSU_NEXT_REPO` | Override KernelSU-Next repo URL |
| `KSU_NEXT_SUSFS_REF` | Override KernelSU-Next SUSFS branch (default: `dev-susfs`) |
| `BBG_REF` | Pin Baseband-guard ref |
| `SUSFS_REF` | Pin SUSFS ref |
| `DROIDSPACES_ENABLE` | Enable Droidspaces GKI support (`1`) |
| `DROIDSPACES_SYSVIPC_KABI_SLOT` | SYSVIPC kABI slot (`1_2_3`, `3_4_5`, `6_7_8`) |
| `CORESHIFT_REPO_JOBS` | Parallel repo sync jobs |
| `CORESHIFT_REPO_PARTIAL_CLONE` | Enable partial clone (`0` or `1`) |
| `CORESHIFT_REPO_CLONE_FILTER` | Partial clone filter (e.g. `blob:none`) |
| `USE_CCACHE` | Enable ccache (`1`) |

The `Build kernel` workflow exposes these through the `build_env` input (one `KEY=VALUE` per line).

## Droidspaces GKI support

`DROIDSPACES_ENABLE=1` runs `scripts/apply-droidspaces-gki-support.sh` before normal
feature hooks. Supports GKI kernels only. Selects the upstream patch set by kernel version,
updates `common/arch/arm64/configs/gki_defconfig` idempotently, and adds the required IPC
symbol exports for 6.12+ kernels.

The pre-6.12 `SYSVIPC` patch defaults to `DROIDSPACES_SYSVIPC_KABI_SLOT=6_7_8`. Supported
override values: `1_2_3`, `3_4_5`, `6_7_8`.

## Private-build escape hatches

- `--disable-defconfig-check on|off`
- `--disable-kmi-check on|off`

These do not guarantee ABI stability or device safety.

## 5.4 UAPI sysroot behaviour

For `android*-5.4-lts` profiles, the build flow patches `common/usr/include/Makefile` in
the prepared workspace so UAPI header tests can see target libc headers through
`UAPI_SYSROOT_CFLAGS`.

The default sysroot points at `/usr/aarch64-linux-gnu/include`. Override if needed:

```bash
./scripts/build-kernel.sh android12-5.4-lts \
  --build-env 'UAPI_SYSROOT_CFLAGS=--target=aarch64-linux-gnu -isystem /custom/sysroot/include'
```

## Swap helper

For memory-heavy local builds:

```bash
./scripts/add-swap.sh 24
```
