#!/usr/bin/env bash
set -euo pipefail

# v2 only. v1 (opencode / opencode-avx) is intentionally NOT auto-updated.
#
# Why: upstream ships v1 and v2 from the same GitHub repo, so the releases.atom
# feed nix-update reads mixes both lines. Its newest entry is a v2 tag
# (e.g. "v2.0.21"), so `nix-update opencode --flake` tries to jump the v1
# package straight from 1.18.x to 2.0.x, then prefetches
#   https://github.com/anomalyco/opencode/releases/download/v2.0.21/opencode-linux-x64-baseline.tar.gz
# which 404s — v2 publishes no GitHub release assets, only npm packages under
# the @opencode scope. nix-update exits non-zero and, under `set -e`, took the
# whole script down with it — including the v2 update below. That is why every
# scheduled run went red from 2026-09-29 onward while v2 silently went stale.
#
# v1 stays in the flake, frozen at its last good pin, for anyone still on it.
# See pkgs/opencode.nix.
echo "Updating opencode2 (v2 stable)..."
./update-v2.sh

echo "All done!"
