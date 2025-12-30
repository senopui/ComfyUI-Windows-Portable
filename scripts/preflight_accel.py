#!/usr/bin/env python3
import importlib
import json
import os
import sys
from pathlib import Path

IMPORT_CHECKS = [
    {
        "name": "flash_attn_3",
        "imports": ["flash_attn_3"],
    },
    {
        "name": "xformers",
        "imports": ["xformers"],
    },
    {
        "name": "nunchaku",
        "imports": ["nunchaku"],
    },
    {
        "name": "spas_sage_attn",
        "imports": ["spas_sage_attn", "sparse_sageattn"],
    },
    {
        "name": "sageattention",
        "imports": ["sageattention", "sageattention2"],
    },
    {
        "name": "natten",
        "imports": ["natten"],
    },
    {
        "name": "bitsandbytes",
        "imports": ["bitsandbytes"],
    },
]

DEPENDENT_NODES = {
    "nunchaku": ["ComfyUI-nunchaku"],
    "spas_sage_attn": ["ComfyUI-RadialAttn"],
}


def try_import(import_names):
    errors = []
    for name in import_names:
        try:
            module = importlib.import_module(name)
            version = getattr(module, "__version__", None)
            return True, version, None
        except Exception as exc:  # noqa: BLE001 - capture import failures for gating
            errors.append(f"{name}: {exc.__class__.__name__}: {exc}")
    return False, None, " | ".join(errors)


def load_existing_manifest(path):
    if not path.exists():
        return []
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        print(f"WARNING: Failed to parse existing manifest at {path}; overwriting.")
        return []
    if isinstance(data, list):
        return data
    return [data]


def write_manifest(path, existing_entries, new_entries):
    combined = list(existing_entries) + list(new_entries)
    path.write_text(json.dumps(combined, indent=2, sort_keys=False), encoding="utf-8")
    print(f"Wrote accelerator preflight results to {path}")


def disable_node(node_dir):
    disabled_dir = node_dir.with_name(f"{node_dir.name}.disabled")
    if node_dir.exists():
        if disabled_dir.exists():
            return "already_disabled", disabled_dir
        node_dir.rename(disabled_dir)
        return "disabled", disabled_dir
    if disabled_dir.exists():
        return "already_disabled", disabled_dir
    return "missing", disabled_dir


def main():
    repo_root = Path(__file__).resolve().parents[1]
    custom_nodes_dir = repo_root / "ComfyUI" / "custom_nodes"
    manifest_path = repo_root / "accel_manifest.json"

    results = []
    failures = {}

    print("=== Accelerator preflight ===")
    for check in IMPORT_CHECKS:
        success, version, error_message = try_import(check["imports"])
        if success:
            print(f"OK: {check['name']} available")
        else:
            print(f"WARNING: {check['name']} unavailable ({error_message})")
            failures[check["name"]] = error_message

        results.append(
            {
                "name": check["name"],
                "version": version,
                "source": "runtime-preflight",
                "success": success,
                "error_if_any": error_message if not success else None,
            }
        )

    existing_entries = load_existing_manifest(manifest_path)
    write_manifest(manifest_path, existing_entries, results)

    if not custom_nodes_dir.exists():
        print(f"WARNING: custom_nodes directory not found at {custom_nodes_dir}")
        return 0

    disabled = []
    unchanged = []

    for backend, error_message in failures.items():
        nodes = DEPENDENT_NODES.get(backend, [])
        if not nodes:
            print(
                f"INFO: No dependent custom nodes mapped for {backend}; nothing to disable."
            )
            continue
        for node in nodes:
            node_dir = custom_nodes_dir / node
            status, disabled_path = disable_node(node_dir)
            if status == "disabled":
                print(
                    f"DISABLED: {node_dir} -> {disabled_path} (missing {backend}: {error_message})"
                )
                disabled.append(disabled_path)
            elif status == "already_disabled":
                print(
                    f"INFO: {node_dir.name} already disabled at {disabled_path} (missing {backend})"
                )
                unchanged.append(disabled_path)
            else:
                print(
                    f"INFO: {node_dir} not found; nothing to disable for missing {backend}"
                )

    if disabled:
        print("=== Preflight changes ===")
        for path in disabled:
            print(f"- Disabled {path}")
        print("To re-enable, rename '<node>.disabled' back to '<node>'.")
    else:
        print("No custom nodes were disabled by preflight.")
        if failures:
            print("To re-enable any nodes, rename '<node>.disabled' back to '<node>'.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
