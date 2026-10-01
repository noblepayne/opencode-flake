#!/usr/bin/env bash
set -euo pipefail

# Update the opencode2 (v2 stable) pin in pkgs/opencode2.nix from the npm
# dist-tag. This is the ONLY updater that matters; see update.sh for why v1 is
# excluded.

# Channel: "latest" is the v2 stable line. Upstream also publishes "beta" and
# "dev" dist-tags; override with OC_CHANNEL if you ever want to track one.
CHANNEL="${OC_CHANNEL:-latest}"

REGISTRY="https://registry.npmjs.org"

# `reserved` is an upstream placeholder tag, never a real release.
VERSION=$(curl -sSfL --retry 3 "$REGISTRY/@opencode/cli-linux-x64" \
  | python3 -c "import sys, json; print(json.load(sys.stdin)['dist-tags']['$CHANNEL'])")

if [ -z "$VERSION" ] || [ "$VERSION" = "0.0.0-reserved" ]; then
  echo "update-v2: refusing to pin placeholder version '$VERSION'" >&2
  exit 1
fi

echo "Updating opencode2 to $VERSION..."

CURRENT_VERSION=$(python3 -c '
import re
with open("pkgs/opencode2.nix") as f:
    m = re.search(r"version = \"([^\"]+)\"", f.read())
    print(m.group(1) if m else "")
')

if [ "$VERSION" = "$CURRENT_VERSION" ]; then
    echo "opencode2 is already at $VERSION."
    exit 0
fi

URL_AVX="$REGISTRY/@opencode/cli-linux-x64/-/cli-linux-x64-$VERSION.tgz"
URL_BASE="$REGISTRY/@opencode/cli-linux-x64-baseline/-/cli-linux-x64-baseline-$VERSION.tgz"

HASH_AVX=$(nix store prefetch-file --unpack --json "$URL_AVX" | python3 -c "import sys, json; print(json.load(sys.stdin)['hash'])")
HASH_BASE=$(nix store prefetch-file --unpack --json "$URL_BASE" | python3 -c "import sys, json; print(json.load(sys.stdin)['hash'])")

# Rewrite via argv (not shell interpolation into Python source), assert exactly
# one match per pattern, and write atomically.
#
# The assertions matter: these patterns depend on exact formatting, so a
# reformatted pkgs/opencode2.nix would otherwise make re.sub silently match
# nothing. The version would update while both hashes stayed stale, `git commit`
# would succeed, and CI would report a clean update of a broken pin. That is the
# same "green run that did nothing" failure this repo already hit once.
python3 - "$VERSION" "$HASH_BASE" "$HASH_AVX" <<'PY'
import pathlib
import re
import sys

version, h_base, h_avx = sys.argv[1:4]

path = pathlib.Path("pkgs/opencode2.nix")
original = path.read_text()


def sub_once(pattern, repl, text, label):
    new, n = re.subn(pattern, repl, text, count=1)
    if n != 1:
        sys.exit(
            f"update-v2: expected exactly 1 {label} match in {path}, got {n}.\n"
            f"           The file's formatting changed; update the patterns in update-v2.sh."
        )
    return new


text = sub_once(r'version = "[^"]+";', f'version = "{version}";', original, "version")
text = sub_once(r'then "sha256-[^"]+"', f'then "{h_base}"', text, "baseline hash")
text = sub_once(r'else "sha256-[^"]+";', f'else "{h_avx}";', text, "avx hash")

if text == original:
    sys.exit("update-v2: rewrite was a no-op — refusing to commit")

tmp = path.with_suffix(".nix.tmp")
tmp.write_text(text)
tmp.replace(path)
PY

# Never publish a pin that does not evaluate to the version we intended.
for attr in opencode2 opencode2-avx; do
  got=$(nix eval --raw ".#$attr.version")
  if [ "$got" != "$VERSION" ]; then
    echo "update-v2: .#$attr.version evaluated to '$got', expected '$VERSION'" >&2
    exit 1
  fi
done

git add pkgs/opencode2.nix
# No `|| true`: a swallowed commit failure here is a silent no-op.
git commit -m "opencode2: $CURRENT_VERSION -> $VERSION"
echo "opencode2 updated to $VERSION"