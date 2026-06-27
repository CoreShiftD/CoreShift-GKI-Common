#!/usr/bin/env bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Links CLANG_PREBUILT_BIN into the workspace at the versioned path expected
# by build.sh (prebuilts/clang/host/linux-x86/clang-<version>/).
# Called by build-kernel.sh when prebuilts/clang/host/linux-x86 is absent
# (removed by aggressive overlay) and CLANG_PREBUILT_BIN is set.

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: link-clang-prebuilt.sh <workspace-dir>" >&2
  exit 1
fi

WORKSPACE_DIR="$1"
CLANG_PREBUILT_BIN="${CLANG_PREBUILT_BIN:-}"

if [ -e "$WORKSPACE_DIR/prebuilts/clang/host/linux-x86" ]; then
  echo "prebuilts/clang/host/linux-x86 already present in workspace, skipping link."
  exit 0
fi

if [ -z "$CLANG_PREBUILT_BIN" ]; then
  echo "CLANG_PREBUILT_BIN not set; cannot link clang prebuilt." >&2
  exit 1
fi

if [ ! -d "$CLANG_PREBUILT_BIN" ]; then
  echo "CLANG_PREBUILT_BIN not found: $CLANG_PREBUILT_BIN" >&2
  exit 1
fi

# Resolve CLANG_VERSION from workspace build.config.constants
CLANG_VERSION=""
for constants_file in \
  "$WORKSPACE_DIR/common/build.config.constants" \
  "$WORKSPACE_DIR/build.config.constants"
do
  if [ -f "$constants_file" ]; then
    CLANG_VERSION=$(grep -E '^CLANG_VERSION=' "$constants_file" | cut -d= -f2 | tr -d '[:space:]')
    break
  fi
done

if [ -z "$CLANG_VERSION" ]; then
  echo "Could not determine CLANG_VERSION from workspace build.config.constants." >&2
  exit 1
fi

# CLANG_PREBUILT_BIN points to the bin/ dir; toolchain root is one level up
TOOLCHAIN_ROOT="$(cd "$CLANG_PREBUILT_BIN/.." && pwd)"
DEST="$WORKSPACE_DIR/prebuilts/clang/host/linux-x86/clang-$CLANG_VERSION"
mkdir -p "$(dirname "$DEST")"
ln -sfn "$TOOLCHAIN_ROOT" "$DEST"

echo "Linked clang $CLANG_VERSION: $TOOLCHAIN_ROOT → $DEST"
