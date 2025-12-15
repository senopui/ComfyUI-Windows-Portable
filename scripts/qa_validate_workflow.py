#!/usr/bin/env python
import argparse
import json
import sys
from pathlib import Path


def resolve_portable_root(base: Path) -> Path:
    """Return the portable root containing ComfyUI_Windows_portable."""
    direct = base / "ComfyUI_Windows_portable"
    nested = base / "builder" / "ComfyUI_Windows_portable"
    if direct.is_dir():
        return direct
    if nested.is_dir():
        return nested
    raise SystemExit(f"ComfyUI_Windows_portable not found under {base}")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Validate minimal workflow fixture")
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parent.parent,
        help="Repository root or extracted package root",
    )
    parser.add_argument(
        "--workflow",
        type=Path,
        default=None,
        help="Path to workflow JSON (defaults to tests/workflows/minimal_text2img.json)",
    )
    args = parser.parse_args(argv)

    repo_root = args.root.resolve()
    portable_root = resolve_portable_root(repo_root)

    workflow_path = (
        args.workflow
        if args.workflow
        else repo_root / "tests" / "workflows" / "minimal_text2img.json"
    )
    workflow_path = workflow_path.resolve()
    if not workflow_path.is_file():
        raise SystemExit(f"Workflow file not found: {workflow_path}")

    try:
        data = json.loads(workflow_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON in workflow: {exc}") from exc

    nodes = data.get("nodes") or []
    if not nodes:
        raise SystemExit("Workflow has no nodes")

    node_types = {node.get("type") for node in nodes}
    required = {
        "CheckpointLoaderSimple",
        "CLIPTextEncode",
        "EmptyLatentImage",
        "KSampler",
        "VAEDecode",
    }

    missing = sorted(required - node_types)
    if missing:
        raise SystemExit(f"Missing required node types: {', '.join(missing)}")

    comfy_path = portable_root / "ComfyUI"
    if not comfy_path.is_dir():
        raise SystemExit(f"ComfyUI directory missing under {portable_root}")

    print("✓ Workflow JSON is readable")
    print(f"✓ Workflow path: {workflow_path}")
    print(f"✓ Portable root: {portable_root}")
    print(f"✓ Required nodes present: {', '.join(sorted(required))}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
