#!/usr/bin/env python3
"""
Resolve the kernel sync matrix for sync-kernel-source.yml.

Reads configs/kernel-sync.json, then outputs JSON to stdout:

  {
    "sync_matrix": {"include": [{"ack_branch": "..."}]},
    "sync_count":  N
  }

Environment variables:
  MIRROR_REMOTE  mirror git remote name or URL (default: origin)
"""

import json
import os
import sys
from pathlib import Path

MIRROR_REMOTE = os.environ.get("MIRROR_REMOTE", "origin")


def main() -> None:
    config_path = Path(__file__).parent.parent / "configs" / "kernel-sync.json"
    config = json.loads(config_path.read_text(encoding="utf-8"))

    lts_branches: list = config["lts_branches"]

    result = {
        "sync_matrix": {"include": [{"ack_branch": b} for b in lts_branches]},
        "sync_count":  len(lts_branches),
    }
    print(json.dumps(result))


if __name__ == "__main__":
    main()
