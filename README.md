# opencode-flake

A Nix flake that wraps the OpenCode coding-agent binaries, with automatic update
machinery for the v2 line.

## Status

**`opencode2` / `opencode2-avx` (v2) is the maintained line.** It is
`packages.default`, `update-v2.sh` updates it twice daily from the `@opencode`
npm scope, and its CI gates are hard. Only `x86_64-linux` is built.

**`opencode` / `opencode-avx` (v1) are frozen legacy** at 1.18.33. They still
build for `x86_64-linux`, but are not auto-updated and their CI checks are
advisory (`continue-on-error`) so they can never block a v2 update.

Why frozen: upstream publishes v1 and v2 from the same GitHub repo, so the
releases feed `nix-update` reads mixes both lines. Its newest entry is a v2 tag,
which made `nix-update` try to jump the v1 package from `1.18.x` straight to
`2.0.x`, then prefetch a GitHub release asset that does not exist (v2 ships npm
tarballs only) → 404 → non-zero exit → `set -e` aborted `update.sh` before the v2
step ran. Every scheduled run went red from 2026-09-29 onward while v2 silently
stayed pinned. See the comment in `update.sh`. Git history preserves the v1 pins
if you ever want them back.

### On the `-baseline` naming

Both v2 variants are published because upstream publishes both, but **baseline is
not an AVX-free fallback**. At 2.0.21 the two npm tarballs differ by 3,231 bytes
out of 204 MB — JavaScriptCore inline-cache constants — and both carry the same
AVX-512 instruction profile (779,532 vs 779,938 EVEX-prefixed bytes). Bun
dropped genuinely AVX-free baseline builds; nixpkgs' own `bun` package notes the
same. `opencode2-avx` is the one to install. Neither variant will run on a
pre-AVX2 CPU, and there is no Nix-standard way to declare that constraint.

## Features

- **Automatic Updates**: `auto-update.yml` runs twice daily, updates the v2 pin
  from npm, builds and validates it, then pushes to `main`.
- **Build Validation**: updates are verified to build *before* being pushed.
- **Health Checks**: binaries are validated with `--version`.
- **Weekly input bumps**: `flake-update.yml` opens a rolling PR for
  `nix flake update` once the v2 build passes.
- **Flake Integration**: works with NixOS, Home Manager, and standalone Nix.

## GitHub Actions Workflows

1. **Auto Update** (`.github/workflows/auto-update.yml`) — twice daily at 00:00
   and 12:00 UTC. Runs `update.sh` (v2 only); if it commits, builds
   `.#opencode2 .#opencode2-avx`, runs `--version` on both, then pushes to `main`.
   The frozen v1 build is a separate `continue-on-error` step.

2. **Update Flake Packages (Weekly PR)** (`.github/workflows/flake-update.yml`) —
   Sundays at 02:00 UTC. Runs `nix flake update`; if `flake.lock` changed, builds
   v2 and opens a rolling PR (branch `update-flake`, updated in place each week,
   closed automatically when nothing changes).

3. **Build and Test** (`.github/workflows/build-test.yml`) — daily at 06:00 UTC
   and on push/PR. Validates both v2 packages; v1 is advisory.

## Usage

```bash
# v2 (maintained, baseline variant)
nix run github:noblepayne/opencode-flake
# or explicitly
nix run github:noblepayne/opencode-flake#opencode2-avx
```

```nix
{
  inputs.opencode-flake.url = "github:noblepayne/opencode-flake";

  outputs = { nixpkgs, opencode-flake, ... }: {
    # Prefer this to the overlay: it uses this flake's own pinned nixpkgs and
    # guarantees exactly one build of the package, instead of a second one
    # rebuilt against your nixpkgs.
    packages.x86_64-linux.default =
      opencode-flake.packages.x86_64-linux.opencode2-avx;
  };
}
```

An overlay is still exported (`overlays.default`), gated per-system. Using it
alongside `packages.<system>.*` produces two distinct derivations of the same
binary from two different nixpkgs — pick one path.

## Update Script

`update.sh` calls `update-v2.sh`, which:

1. reads the npm `latest` dist-tag from `@opencode/cli-linux-x64`
   (override with `OC_CHANNEL`; `beta` and `dev` also exist upstream),
2. prefetches both the baseline and non-baseline tarballs,
3. rewrites the version and both hashes in `pkgs/opencode2.nix` — asserting
   exactly one match per pattern and writing atomically, so a reformatted file
   fails loudly instead of silently leaving a half-updated pin,
4. verifies the rewritten file evaluates to the intended version,
5. commits (no `|| true` — a swallowed commit failure is a silent no-op).

v1 is intentionally excluded — see **Status** above.

`flake.lock` (the nixpkgs input) is refreshed separately by the weekly workflow.