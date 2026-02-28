#!/usr/bin/env bash
set -euo pipefail

echo "Updating opencode (baseline)..."
nix-update opencode --flake --commit

echo "Updating opencode-avx..."
nix-update opencode-avx --flake --commit

echo "All done!"
