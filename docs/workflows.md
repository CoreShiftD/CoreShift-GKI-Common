# GitHub Actions workflows

## Build workflows

### `Build kernel` (`Build.yml`)

Unified build workflow. All build scenarios flow through a single entry point.

**Inputs:**

| Input | Options | Default |
|---|---|---|
| `source_type` | `lts` · `date` · `custom` | `lts` |
| `kernel_version` | `android15-6.6` … `android11-5.4` · `all` | `android15-6.6` |
| `variant` | `vanilla` · `bbg` · `ksu` · `ksu-bbg` · `ksu-susfs` · `ksu-susfs-bbg` · `kowsu` · `kowsu-bbg` · `ksu-next` · `ksu-next-bbg` · `ksu-next-susfs` · `ksu-next-susfs-bbg` · `all` | `vanilla` |
| `custom_url` | git URL (source_type=custom only) | — |
| `custom_branch` | branch/tag/commit (source_type=custom only) | — |
| `private_fragment` | Kconfig fragment content | — |
| `disable_defconfig_check` | boolean | `true` |
| `disable_kmi_check` | boolean | `false` |
| `build_env` | `KEY=VALUE` lines | — |

**Source types:**

- `lts` — stock upstream ACK at the LTS branch tip
- `date` — latest mirrored monthly date branch (e.g. `android15-6.6-2026-06`)
- `custom` — arbitrary kernel git URL and branch; requires `custom_url` and `custom_branch`

`kernel_version=all` + `variant=all` reproduces the former "build everything" matrix.

A `resolve` job maps inputs to a dynamic matrix via `scripts/resolve-unified-build-matrix.py`,
then a `build` job fans out across the matrix.

---

### `Build variants` (`Build-Variants.yml`)

Builds both the LTS and the latest date branch for the selected kernel version and variant.

**Inputs:**

| Input | Options | Default |
|---|---|---|
| `kernel_version` | `android15-6.6` … `android11-5.4` · `all` | `all` |
| `variant` | `vanilla` · `bbg` · `ksu[‑*]` · `kowsu[‑*]` · `ksu-next[‑*]` · `all` | `all` |

- `kernel_version=all` covers every supported family.
- `variant=all` covers every allowed variant per profile.
- 5.4 families always build LTS only (no date branches for pre-GKI 5.4).
- Uses `scripts/resolve-unified-build-matrix.py` for both LTS and date resolution,
  then merges the two matrices before the build fan-out.

---

## Kernel mirror workflow

### `Sync kernel common branches` (`sync-kernel-source.yml`)

Mirrors upstream ACK branches into this repository.

**Three jobs:**

1. **resolve** — reads `configs/kernel-sync.json`, queries upstream ACK and origin, builds a
   dynamic sync matrix (LTS branches + latest date branch per family, filtered to
   ≤ current UTC month) and a prune list of superseded date branches.

2. **sync** — for each branch: clones upstream (`--depth=1`), rsyncs the tree into the
   checked-out mirror branch, commits as a snapshot, pushes `HEAD --force-with-lease`.
   Transient push failures are logged as warnings and retried on the next run.

3. **prune** — deletes superseded date branches from the mirror (runs only when `prune_count > 0`).

**Date branch behaviour:**
- Google pre-creates `androidXX-X.XX-YYYY-MM` refs before objects are ready; the resolve
  script filters them to `≤ current UTC month` to avoid fetch failures.
- Only the single latest date branch per family is kept; older ones are pruned.
- Families managed: `android12-5.10`, `android13-5.10`, `android13-5.15`,
  `android14-5.15`, `android14-6.1`, `android15-6.6`.

---

## Utility workflows

### `Test-Manifest-Trim.yml`

- Tests manifest init, generated overlay creation, and repo sync only.
- Does not compile kernels or package AK3.
- Uploads manifest log artifacts separately from manifest report and overlay artifacts.
- Has no mode input.
- Accepts `extra_remove_projects` for temporary test runs.
- Stable keep/remove rules should be promoted into `manifests/overlays/<profile>.json`
  after a successful test.

### `validate-manifest-workspace.yml`

- Validates the manifest workspace for a selected profile.
- Does not build.

---

## Artifact behaviour

- Workflows upload AK3 zip artifacts and CoreShift log zip artifacts separately.
- Log artifacts include build command output, manifest reports, generated overlay XML,
  patch logs, generated fragments, and selected profile/variant metadata.
- Workflows do not upload raw workspace trees as normal build artifacts.

## CI build environment

- CI installs host tools with `scripts/install-build-tools.sh`.
- CI configures ccache with `scripts/setup-ccache.sh`.
- CI adds aggressive swap with `scripts/add-swap.sh`.
- All build workflows disable IPv6 before running to avoid connectivity issues.
