#!/usr/bin/env bash
set -euo pipefail

PKG_DIR="/app/astra-sim/extern/graph_frontend/chakra"
PROTO_DIR="$PKG_DIR/schema/protobuf"

echo "[chakra] checking package at $PKG_DIR"
test -f "$PKG_DIR/pyproject.toml" || { echo "[chakra] pyproject.toml not found"; exit 1; }

# Clean stale build metadata that can cause “UNKNOWN-0.0.0”
rm -rf "$PKG_DIR"/{build,dist,*.egg-info} "$PKG_DIR"/{*.egg-info,UNKNOWN.egg-info} || true

# Ensure protoc 28.3 (gencode major 5) is reachable
which protoc >/dev/null
protoc --version

echo "[chakra] regenerating python stubs (v5)"
cd "$PROTO_DIR"
protoc -I . --python_out=. et_def.proto

echo "[chakra] installing (protobuf v5, no deps to avoid upgrades)"
/opt/venv/astra-sim/bin/pip install -q --upgrade "protobuf>=5,<6"
/opt/venv/astra-sim/bin/pip install -q --no-build-isolation --no-deps "$PKG_DIR"

echo "[chakra] verifying"
which chakra_converter
chakra_converter --help >/dev/null 2>&1 && echo "[chakra] OK"

