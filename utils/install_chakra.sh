#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
PKG_DIR="/app/astra-sim/extern/graph_frontend/chakra"
VENV="/opt/venv/astra-sim"
PY="$VENV/bin/python"
PIP="$PY -m pip"

# Toggle these if you really need to change behavior
USE_BUILD_ISOLATION=1   # 1 = allow build isolation (recommended), 0 = preinstall build tools
INSTALL_WITH_NO_DEPS=1  # 1 = avoid pulling deps (prevents protobuf downgrade), 0 = let pip resolve deps

echo "[chakra] package root: $PKG_DIR"
test -f "$PKG_DIR/pyproject.toml" || { echo "[chakra] pyproject.toml not found at $PKG_DIR"; exit 1; }

# Ensure we're using the venv tools
if ! "$PY" - <<'PY'
import sys
assert sys.prefix and '/opt/venv/astra-sim' in sys.executable
print('[-] using venv:', sys.executable)
PY
then
  echo "[chakra] ERROR: venv python not found at $PY"
  exit 1
fi

echo "[chakra] cleaning stale build metadata"
rm -rf "$PKG_DIR"/{build,dist,*.egg-info,UNKNOWN.egg-info} || true

# Helper: run pip, try as user first then sudo if needed
pip_run() {
  if $PIP "$@"; then
    return 0
  fi
  echo "[chakra] retrying with sudo: pip $*"
  sudo $PIP "$@"
}

echo "[chakra] upgrading build tools (safe)"
pip_run install -q --upgrade pip setuptools wheel

echo "[chakra] ensuring protobuf v6 runtime in venv"
# Remove any v5 first to avoid leftover artifacts
pip_run uninstall -y protobuf || true
pip_run install -q 'protobuf>=6,<7'

echo "[chakra] installing Chakra from source"
cd "$PKG_DIR"

if [[ "$USE_BUILD_ISOLATION" -eq 0 ]]; then
  # Provide build backend tools ourselves if we disable isolation
  pip_run install -q --upgrade build setuptools_scm[toml]
fi

if [[ "$INSTALL_WITH_NO_DEPS" -eq 1 ]]; then
  # Don’t allow pip to fetch deps (avoids protobuf downgrade by dependencies)
  if [[ "$USE_BUILD_ISOLATION" -eq 1 ]]; then
    pip_run install -q --no-deps .
  else
    pip_run install -q --no-deps --no-build-isolation .
  fi
else
  # Let pip resolve deps but *pin protobuf v6* via a constraints file
  tmpc=$(mktemp)
  echo 'protobuf>=6,<7' > "$tmpc"
  if [[ "$USE_BUILD_ISOLATION" -eq 1 ]]; then
    pip_run install -q --constraint "$tmpc" .
  else
    pip_run install -q --constraint "$tmpc" --no-build-isolation .
  fi
  rm -f "$tmpc"
fi

echo "[chakra] verify protobuf runtime==6 and import of stubs succeeds"
"$PY" - <<'PY'
import importlib, pathlib, re, sys
from google.protobuf import __version__ as rt_ver

# 1) runtime must be v6
major = int(rt_ver.split('.')[0])
print(f"[-] protobuf runtime: {rt_ver}")
assert major == 6, f"expected protobuf v6, got {rt_ver}"

# 2) import the generated stubs (this would raise on mismatch)
m = importlib.import_module('chakra.schema.protobuf.et_def_pb2')
p = pathlib.Path(m.__file__)
print(f"[-] et_def_pb2 path: {p}")

# 3) try to infer gencode version robustly (best-effort)
src = p.read_text(encoding='utf-8', errors='ignore')

# pattern A: Version(6, 31, 1)
mA = re.search(r'Version\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)', src)

# pattern B: PROTOBUF_VERSION = (6, 31, 1) or similar
mB = re.search(r'PROTOBUF_VERSION\s*=\s*\(?\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\)?', src)

gencode = None
for m_ in (mA, mB):
    if m_:
        gencode = tuple(map(int, m_.groups()))
        break

if gencode:
    print(f"[-] detected gencode: {gencode[0]}.{gencode[1]}.{gencode[2]}")
    assert gencode[0] == 6, f"generated stubs not v6 (got {gencode[0]})"
else:
    # No literal version found—this is OK; import already proved compatibility.
    print("[-] note: could not parse gencode version literal; import succeeded, so versions are compatible.")

print("[-] verification OK")
PY


# Ensure CLI on PATH and working
export PATH="$VENV/bin:$PATH"
echo "[chakra] CLI:"
which chakra_converter
chakra_converter --help >/dev/null
echo "[chakra] OK"

