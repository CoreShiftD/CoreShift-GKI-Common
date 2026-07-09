#!/usr/bin/env bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/apply-a75-lut-override.sh <workspace-dir>
EOF
}

if [ "$#" -ne 1 ]; then
  usage >&2
  exit 1
fi

WORKSPACE_DIR="$1"
COMMON_DIR="$WORKSPACE_DIR/common"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PATCH_DIR="$REPO_ROOT/patches/a75-lut-override"
FEATURES_FRAGMENT="$COMMON_DIR/features.fragment"

if [ ! -d "$COMMON_DIR" ]; then
  echo "Workspace common directory not found: $COMMON_DIR" >&2
  exit 1
fi

if ! git -C "$COMMON_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Workspace common directory is not a git repo: $COMMON_DIR" >&2
  exit 1
fi

if [ ! -f "$FEATURES_FRAGMENT" ]; then
  echo "Workspace features fragment not found: $FEATURES_FRAGMENT" >&2
  exit 1
fi

echo "[a75-lut] Copying module source to $COMMON_DIR/drivers/cpufreq/"
cp "$PATCH_DIR/a75_lut_override.c" "$COMMON_DIR/drivers/cpufreq/"

echo "[a75-lut] Patching drivers/cpufreq/Makefile"
python3 - "$COMMON_DIR/drivers/cpufreq/Makefile" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
line = "obj-$(CONFIG_A75_LUT_OVERRIDE) += a75_lut_override.o"
if line not in text.splitlines():
    text = text.rstrip("\n") + "\n" + line + "\n"
    path.write_text(text, encoding="utf-8")
    print("added Makefile entry")
else:
    print("already present")
PY

echo "[a75-lut] Patching drivers/cpufreq/Kconfig"
python3 - "$COMMON_DIR/drivers/cpufreq/Kconfig" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
block = r"""

config A75_LUT_OVERRIDE
	tristate "A75 (MT6789) CPUfreq HW LUT override"
	depends on ARM64 && MTK_CPUFRQ_HW
	default n
	help
	  Override the perf-domain SRAM LUT entries on MT6789 A75 before
	  mediatek-cpufreq-hw probes.  Gives full control over CPU freq steps.

	  Env vars at build time:
	    A75_LUT_BIG_TABLE=2600000,2400000,...,725000
	    A75_LUT_LITTLE_TABLE=2200000,2000000,...,500000
"""
if "config A75_LUT_OVERRIDE" not in text:
    text = text.rstrip("\n") + block
    path.write_text(text, encoding="utf-8")
    print("added Kconfig entry")
else:
    print("already present")
PY

echo "[a75-lut] Enabling CONFIG_A75_LUT_OVERRIDE=m in features fragment"
python3 - "$FEATURES_FRAGMENT" "$COMMON_DIR/drivers/cpufreq" <<'PY'
import sys
from pathlib import Path

fragment_path = Path(sys.argv[1])
lines = fragment_path.read_text(encoding="utf-8").splitlines()

# Remove any existing =y line, then add =m
lines = [l for l in lines if l != "CONFIG_A75_LUT_OVERRIDE=y"]
line = "CONFIG_A75_LUT_OVERRIDE=m"
if line not in lines:
    lines.append(line)
    fragment_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("enabled as module")
else:
    print("already enabled as module")
PY

echo "a75-lut override applied successfully"
