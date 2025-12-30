#!/bin/bash
set -euo pipefail

workdir=$(pwd)
pip_exe_raw="${PIP_EXE:-$workdir/python_standalone/python.exe -s -m pip}"
python_exe="${PYTHON_EXE:-$workdir/python_standalone/python.exe}"

report_root="${PORTABLE_ROOT:-$workdir}"
if [[ ! -d "$report_root" ]]; then
    report_root="$workdir"
fi
report_path="$report_root/accelerators_report.txt"

pip_exe_cmd=($pip_exe_raw)

export PIP_DISABLE_PIP_VERSION_CHECK=1
export PIP_NO_INPUT=1

: > "$report_path"

report_entry() {
    local name="$1"
    local status="$2"
    local source="$3"
    local error="$4"
    {
        echo "name: $name"
        echo "status: $status"
        echo "source: $source"
        if [[ -n "$error" ]]; then
            echo "error: $error"
        fi
        echo "---"
    } >> "$report_path"
}

check_import() {
    local module="$1"
    "$python_exe" - <<PY
import importlib
importlib.import_module("$module")
print("$module ok")
PY
}

pip_install() {
    local log_file="$1"
    shift
    set +e
    "${pip_exe_cmd[@]}" install --timeout 60 --retries 2 "$@" >"$log_file" 2>&1
    local status=$?
    set -e
    return $status
}

pip_uninstall() {
    local package="$1"
    set +e
    "${pip_exe_cmd[@]}" uninstall -y "$package" >/dev/null 2>&1
    set -e
}

attempt_install_with_fallback() {
    local name="$1"
    local module="$2"
    local primary_source="$3"
    local fallback_source="$4"
    shift 4
    local -a primary_args=()
    while [[ "$#" -gt 0 && "$1" != "--" ]]; do
        primary_args+=("$1")
        shift
    done
    shift
    local -a fallback_args=("$@")

    if check_import "$module" >/dev/null 2>&1; then
        report_entry "$name" "installed" "preinstalled" ""
        return 0
    fi

    local log_file
    log_file=$(mktemp)
    if pip_install "$log_file" "${primary_args[@]}"; then
        if check_import "$module" >/dev/null 2>&1; then
            report_entry "$name" "installed" "$primary_source" ""
            rm -f "$log_file"
            return 0
        fi
        pip_uninstall "$name"
    fi
    rm -f "$log_file"

    log_file=$(mktemp)
    if pip_install "$log_file" "${fallback_args[@]}"; then
        if check_import "$module" >/dev/null 2>&1; then
            report_entry "$name" "installed" "$fallback_source" ""
            rm -f "$log_file"
            return 0
        fi
        pip_uninstall "$name"
        report_entry "$name" "failed" "$fallback_source" "import failed"
        rm -f "$log_file"
        return 0
    fi

    local error_tail
    error_tail=$(tail -n 5 "$log_file" | tr '\n' ' ')
    rm -f "$log_file"
    report_entry "$name" "failed" "$fallback_source" "$error_tail"
    return 0
}

echo "=== Optional accelerators install (best effort) ==="

attempt_install_with_fallback \
    "flash-attn" \
    "flash_attn" \
    "pypi" \
    "ai-windows-whl" \
    "flash-attn" "--only-binary" ":all:" -- \
    "flash-attn" "--only-binary" ":all:" "--extra-index-url" "https://ai-windows-whl.github.io/whl/"

attempt_install_with_fallback \
    "sageattention" \
    "sageattention" \
    "pypi" \
    "ai-windows-whl" \
    "sageattention" -- \
    "sageattention" "--extra-index-url" "https://ai-windows-whl.github.io/whl/"

attempt_install_with_fallback \
    "sageattention2" \
    "sageattention2" \
    "pypi" \
    "ai-windows-whl" \
    "sageattention2" -- \
    "sageattention2" "--extra-index-url" "https://ai-windows-whl.github.io/whl/"

attempt_install_with_fallback \
    "bitsandbytes" \
    "bitsandbytes" \
    "pypi" \
    "ai-windows-whl" \
    "bitsandbytes" -- \
    "bitsandbytes" "--extra-index-url" "https://ai-windows-whl.github.io/whl/"

attempt_install_with_fallback \
    "natten" \
    "natten" \
    "whl.natten.org" \
    "ai-windows-whl" \
    "natten" "-f" "https://whl.natten.org" -- \
    "natten" "--extra-index-url" "https://ai-windows-whl.github.io/whl/"

echo "=== Ensuring ONNXRuntime prerequisites (best effort) ==="
"${pip_exe_cmd[@]}" install --timeout 60 --retries 2 flatbuffers numpy protobuf sympy packaging || echo "WARNING: ONNXRuntime prerequisites install failed"

attempt_install_with_fallback \
    "onnxruntime-gpu" \
    "onnxruntime" \
    "onnxruntime-cuda13-nightly" \
    "pypi" \
    "--pre" "--index-url" "https://aiinfra.pkgs.visualstudio.com/PublicPackages/_packaging/onnxruntime-cuda-13-nightly/pypi/simple" "onnxruntime-gpu" -- \
    "onnxruntime-gpu"

echo "Optional accelerators report written to $report_path"
