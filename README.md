# opencode-flake

A Nix Flake that wraps OpenCode binaries with automatic update capabilities.

## Overview

This flake provides a convenient way to install and maintain up-to-date OpenCode binaries through Nix. It automatically tracks upstream releases and provides both standard and AVX-optimized versions.

## Status

**`opencode2` (v2) is the maintained line.** `update.sh` updates it twice daily from the
`@opencode` npm scope and its CI gates are hard.

**`opencode` / `opencode-avx` (v1) are frozen legacy.** They still build, but are no longer
auto-updated and their CI checks are advisory (`continue-on-error`) so they can never block a
v2 update again.

Why frozen: upstream publishes v1 and v2 from the same GitHub repo, so the releases feed that
`nix-update` reads mixes both lines. Its newest entry is a v2 tag, which made `nix-update` try
to jump the v1 package from `1.18.x` straight to `2.0.x`, then prefetch a GitHub release asset
that doesn't exist (v2 ships npm tarballs only) → 404 → non-zero exit → `set -e` aborted
`update.sh` before the v2 step ran. Every scheduled run went red from 2026-09-29 onward while
v2 silently stayed pinned. See the comment in `update.sh`.

## Features

- **Automatic Updates**: GitHub Actions workflows automatically check for and update to new opencode2 releases using the `update.sh` script.
- **Build Validation**: All updates are verified to build correctly *before* being committed or pushed.
- **Health Checks**: Binaries are validated with a `--version` check to ensure functional integrity.
- **Dual Variants**: Provides both standard (`opencode2`) and AVX-optimized (`opencode2-avx`) binaries, plus the frozen v1 pair.
- **Flake Integration**: Compatible with NixOS, Home Manager, and standalone Nix usage.

## GitHub Actions Workflows

The repository includes automated workflows that prioritize running the update script first to check for new releases:

1. **Auto Update** (`.github/workflows/auto-update.yml`)
   - Runs twice daily (00:00 and 12:00 UTC).
   - Runs `update.sh` (v2 only) to fetch and commit new releases from npm.
   - If updates are found, it validates the v2 builds (`nix build .#opencode2 .#opencode2-avx`) and runs `--version` on both.
   - Pushes to `main` only if validation succeeds. The frozen v1 build runs separately as an advisory step.

2. **Update Flake Packages (Weekly PR)** (`.github/workflows/flake-update.yml`)
   - Runs weekly on Sundays at 02:00 UTC.
   - Runs `nix flake update` on a temporary branch.
   - If inputs changed, it validates the v2 builds and binary version strings.
   - Creates a pull request with the updates only after successful validation.

3. **Build and Test** (`.github/workflows/build-test.yml`)
   - Runs daily at 06:00 UTC and on push/PR to main branch.
   - Validates that both opencode2 packages build successfully; v1 is an advisory step.
   - Runs version checks to ensure the binaries are functional.

## Usage

### As a Nix Package

```bash
nix run github:noblepayne/opencode-flake
```

### In a Flake

```nix
{
  inputs.opencode-flake.url = "github:noblepayne/opencode-flake";
  
  outputs = { self, nixpkgs, opencode-flake }: {
    devShells.default = pkgs.mkShell {
      packages = [ opencode-flake.packages.${system}.default ];
    };
  };
}
```

## Maintenance

The flake is designed to be low-maintenance:
- Upstream OpenCode versions are tracked automatically.
- Build validation ensures updates don't break functionality.
- Changes only push after passing build tests.
- All scheduled updates are verified to work correctly.

## Update Script

`update.sh` calls `update-v2.sh`, which reads the npm `latest` dist-tag from
`@opencode/cli-linux-x64` (`-baseline` for the AVX-safe variant), prefetches both tarballs, rewrites
the version + hashes in `pkgs/opencode2.nix`, and commits. v1 is intentionally excluded — see
**Status** above and the comments in `update.sh` / `pkgs/opencode.nix`.

`flake.lock` (nixpkgs input) is refreshed separately by the weekly *Update Flake Packages* workflow,
which opens a PR after validating v2 builds.
