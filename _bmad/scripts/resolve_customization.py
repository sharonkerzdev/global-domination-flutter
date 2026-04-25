#!/usr/bin/env python3
"""
Merge skill customization from base → team → user TOML files.
Contract matches BMad/GDS skills: same merge rules as documented in SKILL.md fallbacks.

Usage:
  python3 _bmad/scripts/resolve_customization.py --skill .claude/skills/gds-create-story --key workflow
  python3 _bmad/scripts/resolve_customization.py --skill .claude/skills/gds-code-review --key workflow.on_complete
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import tomllib  # Python 3.11+


def _project_root() -> Path:
    return Path(__file__).resolve().parent.parent.parent


def _load_toml(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {}
    data = tomllib.loads(path.read_text(encoding="utf-8"))
    return data if isinstance(data, dict) else {}


def _list_merge_key(sample: Any) -> str | None:
    if isinstance(sample, dict):
        if "code" in sample:
            return "code"
        if "id" in sample:
            return "id"
    return None


def _merge_lists(base: list[Any], overlay: list[Any]) -> list[Any]:
    if not overlay:
        return list(base)
    if not base:
        return list(overlay)
    key = _list_merge_key(base[0] if base else overlay[0])
    if not key:
        return list(base) + list(overlay)
    merged = list(base)
    for o_item in overlay:
        if not isinstance(o_item, dict) or key not in o_item:
            merged.append(o_item)
            continue
        kval = o_item[key]
        replaced = False
        for i, m in enumerate(merged):
            if isinstance(m, dict) and m.get(key) == kval:
                merged[i] = o_item
                replaced = True
                break
        if not replaced:
            merged.append(o_item)
    return merged


def _merge_tables(base: dict[str, Any], overlay: dict[str, Any]) -> dict[str, Any]:
    out = dict(base)
    for k, v in overlay.items():
        if k not in out:
            out[k] = v
            continue
        cur = out[k]
        if isinstance(cur, list) and isinstance(v, list):
            out[k] = _merge_lists(cur, v)
        elif isinstance(cur, dict) and isinstance(v, dict):
            out[k] = _merge_tables(cur, v)
        else:
            out[k] = v
    return out


def _merge_layers(paths: list[Path]) -> dict[str, Any]:
    merged: dict[str, Any] = {}
    for path in paths:
        doc = _load_toml(path)
        for section, body in doc.items():
            if isinstance(body, dict):
                merged[section] = _merge_tables(merged.get(section, {}), body)
            else:
                merged[section] = body
    return merged


def _get_by_dotted(root: dict[str, Any], dotted: str) -> Any:
    parts = dotted.split(".")
    cur: Any = root
    for p in parts:
        if not isinstance(cur, dict) or p not in cur:
            return None
        cur = cur[p]
    return cur


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except (AttributeError, OSError):
        pass

    parser = argparse.ArgumentParser(description="Resolve BMad skill customize.toml merge chain.")
    parser.add_argument("--skill", required=True, help="Skill root directory (e.g. .claude/skills/gds-create-story)")
    parser.add_argument("--key", required=True, help="Dotted key, e.g. workflow, workflow.on_complete, agent")
    args = parser.parse_args()

    project = _project_root()
    skill_root = (project / args.skill).resolve()
    skill_name = skill_root.name

    chain = [
        skill_root / "customize.toml",
        project / "_bmad" / "custom" / f"{skill_name}.toml",
        project / "_bmad" / "custom" / f"{skill_name}.user.toml",
    ]

    full = _merge_layers(chain)
    first, _, rest = args.key.partition(".")
    if first not in full:
        # Nothing to emit; skills treat empty stdout as "no customization"
        return 0

    if not rest:
        value = full[first]
    else:
        section = full[first]
        value = _get_by_dotted(section, rest) if isinstance(section, dict) else None

    if value is None:
        return 0

    if isinstance(value, (dict, list)):
        sys.stdout.write(json.dumps(value, indent=2, ensure_ascii=False))
    else:
        sys.stdout.write(str(value))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
