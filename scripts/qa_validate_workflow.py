from __future__ import annotations

import json
import sys
from pathlib import Path


def find_portable_root(start: Path) -> Path:
    candidates = [
        start,
        start / "ComfyUI_Windows_portable",
        start / "builder" / "ComfyUI_Windows_portable",
        start / "builder-cu130" / "ComfyUI_Windows_portable",
        start / "builder-cu128" / "ComfyUI_Windows_portable",
    ]
    for c in candidates:
        if (c / "ComfyUI").is_dir():
            return c
    raise SystemExit("Could not locate ComfyUI portable root")


def load_registry(portable_root: Path) -> set[str]:
    sys.path.insert(0, str(portable_root / "ComfyUI"))
    try:
        import nodes  # type: ignore
    except (ImportError, ModuleNotFoundError) as exc:  # pragma: no cover - runtime guard
        raise SystemExit(
            f"Failed to import ComfyUI nodes ({exc.__class__.__name__}: {exc})"
        ) from exc

    registry = set(nodes.NODE_CLASS_MAPPINGS.keys()) | set(
        nodes.NODE_DISPLAY_NAME_MAPPINGS.keys()
    )
    return registry


def main() -> int:
    repo_root = Path(__file__).resolve().parents[1]
    portable_root = find_portable_root(repo_root)
    registry = load_registry(portable_root)

    workflow_path = repo_root / "tests" / "workflows" / "minimal_text2img.json"
    data = json.loads(workflow_path.read_text(encoding="utf-8"))

    missing: list[str] = []
    for node_id, node_data in data.items():
        class_type = node_data.get("class_type")
        if class_type is None:
            missing.append(f"{node_id}: missing class_type")
            continue
        if class_type not in registry:
            missing.append(f"{node_id}: {class_type}")

    if missing:
        print("Missing or unknown nodes:")
        for m in missing:
            print(f" - {m}")
        return 1

    print("Workflow node validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
