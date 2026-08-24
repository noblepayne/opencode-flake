#!/usr/bin/env bash
set -euo pipefail

# Fetch current "beta" version from npm (v2 line moved off the stale "next" tag)
VERSION=$(curl -sL https://registry.npmjs.org/@opencode-ai/cli-linux-x64 | python3 -c "import sys, json; print(json.load(sys.stdin)['dist-tags']['beta'])")
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

URL_AVX="https://registry.npmjs.org/@opencode-ai/cli-linux-x64/-/cli-linux-x64-${VERSION}.tgz"
URL_BASE="https://registry.npmjs.org/@opencode-ai/cli-linux-x64-baseline/-/cli-linux-x64-baseline-${VERSION}.tgz"

HASH_AVX=$(nix store prefetch-file --unpack --json "$URL_AVX" | python3 -c "import sys, json; print(json.load(sys.stdin)['hash'])")
HASH_BASE=$(nix store prefetch-file --unpack --json "$URL_BASE" | python3 -c "import sys, json; print(json.load(sys.stdin)['hash'])")

python3 -c "
import re

with open('pkgs/opencode2.nix', 'r') as f:
    content = f.read()

content = re.sub(r'version = \"[^\"]+\";', f'version = \"$VERSION\";', content)
content = re.sub(r'then \"sha256-[^\"]+\"', f'then \"$HASH_BASE\"', content)
content = re.sub(r'else \"sha256-[^\"]+\";', f'else \"$HASH_AVX\";', content)

with open('pkgs/opencode2.nix', 'w') as f:
    f.write(content)
"

git add pkgs/opencode2.nix
git commit -m "opencode2: $CURRENT_VERSION -> $VERSION" || true
echo "opencode2 updated to $VERSION"
