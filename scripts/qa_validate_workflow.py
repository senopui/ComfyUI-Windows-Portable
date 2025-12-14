#!/usr/bin/env python
import argparse
import json
import sys
from pathlib import Path
from typing import Iterable, List, Set, Tuple


def load_workflow(path: Path) -> dict:
    try:
        with path.open("r", encoding="utf-8") as fh:
            return json.load(fh)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON in {path}: {exc}") from exc
    except FileNotFoundError:
        raise SystemExit(f"Workflow file not found: {path}")


def validate_structure(data: dict) -> Tuple[List[str], Set[int]]:
    errors: List[str] = []
    nodes = data.get("nodes", [])
    links = data.get("links", [])

    if not isinstance(nodes, list) or not nodes:
        errors.append("Workflow has no nodes.")
        return errors, set()

    node_ids: Set[int] = set()
    for node in nodes:
        if not isinstance(node, dict):
            continue
        node_id = node.get("id")
        if not isinstance(node_id, int):
            errors.append("At least one node is missing an integer 'id' field.")
            continue
        node_ids.add(node_id)

    if not isinstance(links, list):
        errors.append("Links section is missing or invalid.")
        links = []

    for link in links:
        # ComfyUI links: first five entries are [link_id, from_node, from_slot, to_node, to_slot]
        if not isinstance(link, list) or len(link) < 5:
            errors.append(f"Malformed link entry: {link}")
            continue
        link_id, from_node, from_slot, to_node, to_slot = link[:5]
        if from_node not in node_ids:
            errors.append(f"Link references unknown source node id {from_node}")
        if to_node not in node_ids:
            errors.append(f"Link references unknown target node id {to_node}")

    return errors, node_ids


def validate_nodes_exist(workflow_nodes: Iterable[dict], node_registry: dict) -> List[str]:
    registry_keys = set(node_registry.keys())
    missing: List[str] = []
    for node in workflow_nodes:
        node_type = node.get("type")
        if node_type and node_type not in registry_keys:
            missing.append(node_type)
    return missing


def main() -> int:
    repo_root = Path(__file__).resolve().parents[1]
    default_workflow = repo_root / "tests" / "workflows" / "minimal_text2img.json"

    parser = argparse.ArgumentParser(description="Validate ComfyUI workflow fixture.")
    parser.add_argument(
        "--workflow",
        default=default_workflow,
        type=Path,
        help="Path to workflow JSON (default: tests/workflows/minimal_text2img.json)",
    )
    parser.add_argument(
        "--comfyui-root",
        default=repo_root / "ComfyUI",
        type=Path,
        help="Path to ComfyUI root (folder containing nodes.py).",
    )
    parser.add_argument(
        "--structure-only",
        action="store_true",
        help="Skip node registry import and only validate JSON structure.",
    )
    args = parser.parse_args()

    workflow = load_workflow(args.workflow)
    structure_errors, _ = validate_structure(workflow)
    if structure_errors:
        for err in structure_errors:
            print(f"ERROR: {err}", file=sys.stderr)
        return 1

    if args.structure_only:
        print("Structure validation passed (node registry check skipped).")
        return 0

    comfy_root = args.comfyui_root
    nodes_py = comfy_root / "nodes.py"
    if not nodes_py.exists():
        print(
            f"ERROR: nodes.py not found under {comfy_root}. "
            "Run after assembling the portable package or pass --structure-only.",
            file=sys.stderr,
        )
        return 1

    sys.path.insert(0, str(comfy_root))
    try:
        from nodes import NODE_CLASS_MAPPINGS  # type: ignore
    except (ImportError, ModuleNotFoundError, AttributeError) as exc:
        print(f"ERROR: Failed to import ComfyUI nodes from {comfy_root}: {exc}", file=sys.stderr)
        return 1

    missing = validate_nodes_exist(workflow.get("nodes", []), NODE_CLASS_MAPPINGS)
    if missing:
        print(
            "ERROR: Workflow references node types not present in ComfyUI: "
            + ", ".join(sorted(set(missing))),
            file=sys.stderr,
        )
        return 1

    print("Workflow validation succeeded: all referenced nodes are available.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
